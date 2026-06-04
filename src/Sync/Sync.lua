-- Guild sync orchestration: offer, accept, decline, chunked transfer, merge.

TuskUpLoot.Sync = TuskUpLoot.Sync or {}
local Sync = TuskUpLoot.Sync

local Protocol = TuskUpLoot.SyncProtocol
local Transport = TuskUpLoot.SyncTransport
local Codec = TuskUpLoot.SyncCodec
local Payload = TuskUpLoot.SyncPayload

local OFFER_TIMEOUT = 60
local CHUNK_PAYLOAD_SIZE = 180

local outbound = {}
local inbound = {}
local syncCounter = 0

local function chat(msg)
  if TuskUpLoot.chatPrint then
    TuskUpLoot.chatPrint(msg)
  end
end

local function after(delay, fn)
  if C_Timer and C_Timer.After then
    C_Timer.After(delay, fn)
  else
    fn()
  end
end

local function playerName()
  return UnitName and UnitName("player") or ""
end

local function normalizeName(name)
  if Ambiguate then
    return Ambiguate(name, "short")
  end
  return name
end

local function guildAllowed()
  if TuskUpLoot.isInRequiredGuild then
    return TuskUpLoot.isInRequiredGuild()
  end
  return true
end

local function nextSyncId()
  syncCounter = syncCounter + 1
  return string.format("%d-%d", time() % 1000000, syncCounter)
end

local function clearOutbound(syncId)
  outbound[syncId] = nil
end

local function clearInbound(syncId)
  inbound[syncId] = nil
end

local function sendTo(target, message)
  Transport.enqueue(target, message)
end

function Sync.sendOffer(target, mode, bundle, label)
  if not guildAllowed() then
    chat("Sync requires guild membership.")
    return false
  end
  if not target or target == "" then
    return false
  end
  if not bundle then
    chat("Nothing to sync.")
    return false
  end

  local CodecEnc = Codec.encode(bundle)
  if not CodecEnc then
    chat("Failed to encode sync data.")
    return false
  end

  local syncId = nextSyncId()
  local charKey = ""
  local gearSetKey = ""
  if mode == "GEAR" then
    for ck, _ in pairs(bundle.characters or {}) do
      charKey = ck
      break
    end
    if bundle.characters and bundle.characters[charKey] and bundle.characters[charKey].gearSets then
      for gk, _ in pairs(bundle.characters[charKey].gearSets) do
        gearSetKey = gk
        break
      end
    end
  end

  outbound[syncId] = {
    target = target,
    mode = mode,
    encoded = CodecEnc,
    chunks = Codec.splitChunks(CodecEnc, CHUNK_PAYLOAD_SIZE),
    label = label,
    createdAt = time(),
    state = "offered",
  }

  sendTo(target, Protocol.packOffer(syncId, target, mode, charKey, gearSetKey, label or ""))
  chat(string.format("Sync offer sent to %s.", target))

  after(OFFER_TIMEOUT, function()
    local ob = outbound[syncId]
    if ob and ob.state == "offered" then
      clearOutbound(syncId)
      chat(string.format("Sync to %s timed out (no response).", target))
    end
  end)

  return true
end

local function transmitChunks(syncId, ob)
  local chunks = ob.chunks or {}
  local total = #chunks
  ob.state = "sending"
  for seq = 1, total do
    sendTo(ob.target, Protocol.packChunk(syncId, seq, total, chunks[seq]))
  end
  sendTo(ob.target, Protocol.packFinish(syncId))
  ob.state = "done"
  chat(string.format("Sync data sent to %s.", ob.target))
end

function Sync.pushFull(targetPlayerName)
  if not TuskUpLoot.DB or not TuskUpLoot.DB.hasSyncableData() then
    chat("No character data to push.")
    return false
  end
  local bundle = Payload.buildFullBundle()
  return Sync.sendOffer(targetPlayerName, "FULL", bundle, "all saved data")
end

function Sync.pushGearSet(targetPlayerName, characterKey, gearSetKey)
  local bundle = Payload.buildGearSetBundle(characterKey, gearSetKey)
  if not bundle then
    chat("Gear set not found.")
    return false
  end
  local gs = bundle.characters[characterKey].gearSets[gearSetKey]
  local label = string.format("%s — %s", bundle.characters[characterKey].name or characterKey,
    gs and (gs.name or gearSetKey) or gearSetKey)
  return Sync.sendOffer(targetPlayerName, "GEAR", bundle, label)
end

function Sync.acceptOffer(syncId)
  local ib = inbound[syncId]
  if not ib or ib.state ~= "offered" then
    return
  end
  ib.state = "accepted"
  sendTo(ib.sender, Protocol.packAccept(syncId))
end

function Sync.declineOffer(syncId)
  local ib = inbound[syncId]
  if not ib or ib.state ~= "offered" then
    return
  end
  clearInbound(syncId)
  sendTo(ib.sender, Protocol.packDecline(syncId))
end

local function applyInbound(syncId, ib)
  local encoded = Codec.joinChunks(ib.receivedChunks)
  local bundle = Codec.decode(encoded)
  if not bundle then
    chat("Sync failed: could not decode data.")
    clearInbound(syncId)
    return
  end
  bundle.mode = ib.mode

  local DB = TuskUpLoot.DB
  if not DB or not DB.applySyncBundle then
    chat("Sync failed: database unavailable.")
    clearInbound(syncId)
    return
  end

  local stats = DB.applySyncBundle(bundle)
  clearInbound(syncId)

  chat(string.format("Sync from %s applied (%d gear set(s) updated, %d skipped).",
    ib.sender or "unknown",
    stats and stats.updated or 0,
    stats and stats.skipped or 0))

  if TuskUpLoot.UI and TuskUpLoot.UI.refreshAfterImport then
    TuskUpLoot.UI.refreshAfterImport()
  end
end

local function handleOffer(sender, msg)
  if not guildAllowed() then
    return
  end

  local target = msg.target
  if normalizeName(target) ~= normalizeName(playerName()) then
    return
  end

  local syncId = msg.syncId
  if not syncId then
    return
  end

  inbound[syncId] = {
    sender = sender,
    mode = msg.mode,
    label = msg.label,
    charKey = msg.charKey,
    gearSetKey = msg.gearSetKey,
    state = "offered",
    receivedChunks = {},
    createdAt = time(),
  }

  if TuskUpLoot.UI and TuskUpLoot.UI.showSyncOffer then
    TuskUpLoot.UI.showSyncOffer(syncId, sender, msg.mode, msg.label)
  else
    chat(string.format("%s wants to sync %s. (UI unavailable)", sender, msg.label or "data"))
  end
end

local function handleAccept(sender, msg)
  local syncId = msg.syncId
  local ob = outbound[syncId]
  if not ob or normalizeName(ob.target) ~= normalizeName(sender) then
    return
  end
  if ob.state ~= "offered" then
    return
  end
  transmitChunks(syncId, ob)
  after(5, function()
    clearOutbound(syncId)
  end)
end

local function handleDecline(sender, msg)
  local syncId = msg.syncId
  local ob = outbound[syncId]
  if not ob or normalizeName(ob.target) ~= normalizeName(sender) then
    return
  end
  clearOutbound(syncId)
  chat(string.format("%s declined sync. No data was transferred.", sender))
end

local function handleChunk(sender, msg)
  local syncId = msg.syncId
  local ib = inbound[syncId]
  if not ib or normalizeName(ib.sender) ~= normalizeName(sender) then
    return
  end
  if ib.state ~= "accepted" and ib.state ~= "receiving" then
    return
  end

  local seq = msg.seq
  local total = msg.total
  if not seq or not total or seq < 1 or seq > total then
    return
  end

  ib.state = "receiving"
  ib.expectedTotal = total
  ib.receivedChunks[seq] = msg.payload or ""

  local count = 0
  for i = 1, total do
    if ib.receivedChunks[i] then
      count = count + 1
    end
  end
  ib.receivedCount = count
end

local function handleFinish(sender, msg)
  local syncId = msg.syncId
  local ib = inbound[syncId]
  if not ib or normalizeName(ib.sender) ~= normalizeName(sender) then
    return
  end

  local total = ib.expectedTotal or 0
  if total > 0 then
    for i = 1, total do
      if not ib.receivedChunks[i] then
        chat(string.format("Sync from %s failed: incomplete transfer.", sender))
        clearInbound(syncId)
        return
      end
    end
  end

  applyInbound(syncId, ib)
end

local function onAddonMessage(sender, message)
  if not sender or not message then
    return
  end
  sender = normalizeName(sender)

  local msg = Protocol.parse(message)
  if not msg or not msg.cmd then
    return
  end

  if msg.cmd == "O" then
    handleOffer(sender, msg)
  elseif msg.cmd == "A" then
    handleAccept(sender, msg)
  elseif msg.cmd == "D" then
    handleDecline(sender, msg)
  elseif msg.cmd == "C" then
    handleChunk(sender, msg)
  elseif msg.cmd == "F" then
    handleFinish(sender, msg)
  end
end

function Sync.init(eventFrame)
  Transport.registerPrefix()
  Transport.setOnMessage(onAddonMessage)
  Transport.attachEvents(eventFrame)

  local origHandler = eventFrame:GetScript("OnEvent")
  eventFrame:SetScript("OnEvent", function(self, event, ...)
    if Transport.onEvent then
      Transport.onEvent(event, ...)
    end
    if origHandler then
      origHandler(self, event, ...)
    end
  end)
end

function Sync.openPushFullPicker()
  if TuskUpLoot.UI and TuskUpLoot.UI.showSyncPicker then
    TuskUpLoot.UI.showSyncPicker(function(name)
      Sync.pushFull(name)
    end)
  end
end

function Sync.openPushGearSetPicker(characterKey, gearSetKey)
  if TuskUpLoot.UI and TuskUpLoot.UI.showSyncPicker then
    TuskUpLoot.UI.showSyncPicker(function(name)
      Sync.pushGearSet(name, characterKey, gearSetKey)
    end)
  end
end
