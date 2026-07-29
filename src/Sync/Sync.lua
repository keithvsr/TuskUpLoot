-- Guild sync orchestration: offer, accept, decline, compressed transfer, merge.

TuskUpLoot.Sync = TuskUpLoot.Sync or {}
local Sync = TuskUpLoot.Sync
LibStub("AceComm-3.0"):Embed(Sync)

local Protocol = TuskUpLoot.SyncProtocol
local Codec = TuskUpLoot.SyncCodec
local Payload = TuskUpLoot.SyncPayload

local PREFIX = Protocol.PREFIX
local OFFER_TIMEOUT = 60

local outbound = {}
local inbound = {}
local syncCounter = 0

local function chat(msg)
  if TuskUpLoot.chatPrint then
    TuskUpLoot.chatPrint(msg)
  end
end

local function debug(msg)
  if TuskUpLoot.debugPrint then
    TuskUpLoot.debugPrint(msg)
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
  debug(string.format("Sync send → %s (%d bytes)", tostring(target), message and #message or 0))
  Sync:SendCommMessage(PREFIX, message, "WHISPER", target)
end

function Sync.sendOffer(target, mode, bundle, label)
  if not target or target == "" then
    debug("Sync.sendOffer: missing target")
    return false
  end
  if not bundle then
    chat("Nothing to sync.")
    return false
  end

  debug(string.format("Sync.sendOffer: target=%s mode=%s label=%s",
    tostring(target), tostring(mode), tostring(label)))

  local encoded = Codec.encode(bundle)
  if not encoded then
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
    encoded = encoded,
    label = label,
    createdAt = time(),
    state = "offered",
  }

  debug(string.format(
    "Sync.offer queued id=%s charKey=%s gearSetKey=%s encoded=%d bytes",
    syncId, charKey ~= "" and charKey or "-", gearSetKey ~= "" and gearSetKey or "-", #encoded))

  sendTo(target, Protocol.packOffer(syncId, target, mode, charKey, gearSetKey, label or ""))
  chat(string.format("Sync offer sent to %s.", target))

  after(OFFER_TIMEOUT, function()
    local ob = outbound[syncId]
    if ob and ob.state == "offered" then
      clearOutbound(syncId)
      chat(string.format("Sync to %s timed out (no response).", target))
      debug("Sync.offer timed out id=" .. syncId)
    end
  end)

  return true
end

local function transmitBundle(syncId, ob)
  ob.state = "sending"
  debug(string.format("Sync.transmitBundle id=%s → %s encoded=%d",
    syncId, tostring(ob.target), ob.encoded and #ob.encoded or 0))
  sendTo(ob.target, Protocol.packBundle(syncId, ob.encoded))
  ob.state = "done"
  chat(string.format("Sync data sent to %s.", ob.target))
end

function Sync.pushFull(targetPlayerName)
  debug("Sync.pushFull → " .. tostring(targetPlayerName))
  if not TuskUpLoot.DB or not TuskUpLoot.DB.hasSyncableData() then
    chat("No character data to push.")
    return false
  end
  local bundle = Payload.buildFullBundle()
  return Sync.sendOffer(targetPlayerName, "FULL", bundle, "all saved data")
end

function Sync.pushGearSet(targetPlayerName, characterKey, gearSetKey)
  debug(string.format("Sync.pushGearSet → %s char=%s set=%s",
    tostring(targetPlayerName), tostring(characterKey), tostring(gearSetKey)))
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
    debug("Sync.acceptOffer: no pending offer id=" .. tostring(syncId))
    return
  end
  ib.state = "accepted"
  debug(string.format("Sync.acceptOffer id=%s sender=%s", syncId, tostring(ib.sender)))
  sendTo(ib.sender, Protocol.packAccept(syncId))
end

function Sync.declineOffer(syncId)
  local ib = inbound[syncId]
  if not ib or ib.state ~= "offered" then
    debug("Sync.declineOffer: no pending offer id=" .. tostring(syncId))
    return
  end
  debug(string.format("Sync.declineOffer id=%s sender=%s", syncId, tostring(ib.sender)))
  clearInbound(syncId)
  sendTo(ib.sender, Protocol.packDecline(syncId))
end

local function applyInbound(syncId, ib, encoded)
  debug(string.format("Sync.applyInbound id=%s from=%s encoded=%d",
    syncId, tostring(ib.sender), encoded and #encoded or 0))
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
  debug(string.format("Sync.applyInbound done updated=%d skipped=%d mode=%s",
    stats and stats.updated or 0,
    stats and stats.skipped or 0,
    tostring(ib.mode)))

  if TuskUpLoot.UI and TuskUpLoot.UI.refreshAfterImport then
    TuskUpLoot.UI.refreshAfterImport()
  end
end

local function handleOffer(sender, msg)
  local target = msg.target
  if normalizeName(target) ~= normalizeName(playerName()) then
    debug(string.format("Sync.offer ignored (target=%s self=%s) from %s",
      tostring(target), playerName(), tostring(sender)))
    return
  end

  local syncId = msg.syncId
  if not syncId then
    debug("Sync.offer missing syncId from " .. tostring(sender))
    return
  end

  inbound[syncId] = {
    sender = sender,
    mode = msg.mode,
    label = msg.label,
    charKey = msg.charKey,
    gearSetKey = msg.gearSetKey,
    state = "offered",
    createdAt = time(),
  }

  debug(string.format(
    "Sync.offer received id=%s from=%s mode=%s label=%s",
    syncId, sender, tostring(msg.mode), tostring(msg.label)))

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
    debug(string.format("Sync.accept ignored id=%s from=%s", tostring(syncId), tostring(sender)))
    return
  end
  if ob.state ~= "offered" then
    debug(string.format("Sync.accept ignored id=%s state=%s", syncId, tostring(ob.state)))
    return
  end
  debug(string.format("Sync.accept from %s id=%s — transmitting", sender, syncId))
  transmitBundle(syncId, ob)
  after(5, function()
    clearOutbound(syncId)
  end)
end

local function handleDecline(sender, msg)
  local syncId = msg.syncId
  local ob = outbound[syncId]
  if not ob or normalizeName(ob.target) ~= normalizeName(sender) then
    debug(string.format("Sync.decline ignored id=%s from=%s", tostring(syncId), tostring(sender)))
    return
  end
  clearOutbound(syncId)
  chat(string.format("%s declined sync. No data was transferred.", sender))
  debug("Sync.decline from " .. sender .. " id=" .. tostring(syncId))
end

local function handleBundle(sender, msg)
  local syncId = msg.syncId
  local ib = inbound[syncId]
  if not ib or normalizeName(ib.sender) ~= normalizeName(sender) then
    debug(string.format("Sync.bundle ignored id=%s from=%s", tostring(syncId), tostring(sender)))
    return
  end
  if ib.state ~= "accepted" then
    debug(string.format("Sync.bundle ignored id=%s state=%s", syncId, tostring(ib.state)))
    return
  end
  debug(string.format("Sync.bundle from %s id=%s encoded=%d",
    sender, syncId, msg.encoded and #msg.encoded or 0))
  applyInbound(syncId, ib, msg.encoded)
end

function Sync:OnCommReceived(prefix, message, distribution, sender)
  if prefix ~= PREFIX then
    return
  end
  if distribution ~= "WHISPER" then
    debug(string.format("Sync.OnCommReceived ignored distribution=%s from=%s",
      tostring(distribution), tostring(sender)))
    return
  end
  if not sender or sender == "" or not message then
    return
  end

  sender = normalizeName(sender)
  local msg = Protocol.parse(message)
  if not msg or not msg.cmd then
    debug(string.format("Sync.OnCommReceived unparsed from %s (%d bytes)",
      sender, #message))
    return
  end

  debug(string.format("Sync.OnCommReceived cmd=%s from=%s (%d bytes)",
    msg.cmd, sender, #message))

  if msg.cmd == "O" then
    handleOffer(sender, msg)
  elseif msg.cmd == "A" then
    handleAccept(sender, msg)
  elseif msg.cmd == "D" then
    handleDecline(sender, msg)
  elseif msg.cmd == "B" then
    handleBundle(sender, msg)
  else
    debug("Sync.OnCommReceived unknown cmd=" .. tostring(msg.cmd))
  end
end

function Sync.init()
  Sync:RegisterComm(PREFIX, "OnCommReceived")
  debug("Sync.init: registered prefix " .. PREFIX)
end

function Sync.openPushFullPicker()
  debug("Sync.openPushFullPicker")
  if TuskUpLoot.UI and TuskUpLoot.UI.showSyncPicker then
    TuskUpLoot.UI.showSyncPicker(function(name)
      Sync.pushFull(name)
    end)
  end
end

function Sync.openPushGearSetPicker(characterKey, gearSetKey)
  debug(string.format("Sync.openPushGearSetPicker char=%s set=%s",
    tostring(characterKey), tostring(gearSetKey)))
  if TuskUpLoot.UI and TuskUpLoot.UI.showSyncPicker then
    TuskUpLoot.UI.showSyncPicker(function(name)
      Sync.pushGearSet(name, characterKey, gearSetKey)
    end)
  end
end
