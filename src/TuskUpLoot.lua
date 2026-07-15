local ADDON_NAME = ...

local addon = TuskUpLoot

addon.addonName = ADDON_NAME
addon.State = addon.State or {}

function addon.chatPrint(msg)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cffffff88" .. ADDON_NAME .. "|r: " .. tostring(msg))
  end
end

function addon.debugPrint(msg)
  local Opts = addon.Opts
  if not (Opts and Opts.debugEnabled and Opts.debugEnabled()) then
    return
  end
  addon.chatPrint(msg)
end

local eventFrame = CreateFrame("Frame", "TuskUpLootEventFrame")

local pendingRunInstanceCapture = false
local npcCaptureEventsRegistered = false

local NPC_CAPTURE_UNITS = {
  "target",
  "mouseover",
  "focus",
  "boss1",
  "boss2",
  "boss3",
  "boss4",
  "boss5",
}

local function getFullPlayerName()
  local playerName, playerRealm = UnitFullName("player")
  if not playerName or not playerRealm then
    return nil
  end
  return playerName .. "-" .. playerRealm
end

local function guidParts(guid)
  local parts = {}
  if not guid then
    return parts
  end
  for token in string.gmatch(guid, "[^-]+") do
    parts[#parts + 1] = token
  end
  return parts
end

local function isUnitGuidWithRunId(unitType)
  return unitType == "Creature" or unitType == "GameObject"
end

-- [unitType]-0-[serverID]-[instanceID]-[zoneUID]-[ID]-[spawnUID]
local function parseRunInstanceIdFromUnitGuid(guid)
  local parts = guidParts(guid)
  if not isUnitGuidWithRunId(parts[1]) then
    return nil
  end
  if parts[2] ~= "0" or #parts < 5 then
    return nil
  end
  local runId = tonumber(parts[5], 10)
  if runId and runId ~= 0 then
    return runId
  end
  return nil
end

local function parseLootSourceFromGuid(guid)
  local parts = guidParts(guid)
  if parts[2] ~= "0" or #parts < 6 then
    return nil
  end
  local unitType = parts[1]
  local sourceId = tonumber(parts[6], 10)
  if not sourceId then
    return nil
  end
  if unitType == "Creature" then
    return { sourceType = "npc", sourceId = sourceId }
  elseif unitType == "GameObject" then
    return { sourceType = "object", sourceId = sourceId }
  end
  return nil
end

local function runInstanceIdFromUnit(unit)
  if not unit or not UnitExists(unit) then
    return nil
  end
  return parseRunInstanceIdFromUnitGuid(UnitGUID(unit))
end

local function persistMemoryClears(runKey, mapId, cleared)
  if not runKey or not addon.DB or not addon.DB.saveEncounterClear then
    return
  end
  for encId, val in pairs(cleared or {}) do
    if val then
      addon.DB.saveEncounterClear(runKey, mapId, encId)
    end
  end
end

local function copyEncounterDrops(drops)
  local out = {}
  for encId, list in pairs(drops or {}) do
    local copy = {}
    for i, itemId in ipairs(list) do
      copy[i] = itemId
    end
    out[encId] = copy
  end
  return out
end

local function persistMemoryDrops(runKey, mapId, drops)
  if not runKey or not addon.DB or not addon.DB.appendEncounterDrops then
    return
  end
  for encId, list in pairs(drops or {}) do
    if list and #list > 0 then
      addon.DB.appendEncounterDrops(runKey, mapId, encId, list)
    end
  end
end

local function appendDropsToState(encounterId, itemIds)
  if not encounterId or not itemIds or #itemIds == 0 then
    return
  end
  if not addon.State.EncounterDrops then
    addon.State.EncounterDrops = {}
  end
  local list = addon.State.EncounterDrops[encounterId]
  if not list then
    list = {}
    addon.State.EncounterDrops[encounterId] = list
  end
  for _, itemId in ipairs(itemIds) do
    list[#list + 1] = itemId
  end
end

-- Shared entry point for local LOOT_READY recording and future raid SendAddonMessage sync.
-- Future: ML broadcasts drops via C_ChatInfo.SendAddonMessage("RAID", payload, "TuskUpLoot");
-- receivers validate runKey and call this same function.
local function mergeEncounterDrops(dropBucket, itemIds)
  appendDropsToState(dropBucket, itemIds)

  local runKey = addon.State.RaidRunKey
  if runKey and addon.DB and addon.DB.appendEncounterDrops then
    addon.DB.appendEncounterDrops(runKey, addon.State.InstanceId, dropBucket, itemIds)
  end

  if addon.UI and addon.UI.focusEncounterId == dropBucket and addon.UI.renderEncounterLootPanel then
    addon.UI.renderEncounterLootPanel()
  end
  if addon.UI and addon.UI.rebuildRaidList
      and addon.Data and dropBucket == addon.Data.TRASH_DROP_BUCKET then
    addon.UI.rebuildRaidList()
  end
end

function addon.mergeDrops(dropBucket, itemIds)
  mergeEncounterDrops(dropBucket, itemIds)
end

local function hydrateClearedEncounters()
  local memory = addon.State.ClearedEncounters or {}
  local memoryDrops = addon.State.EncounterDrops or {}
  addon.State.ClearedEncounters = {}
  addon.State.EncounterDrops = {}

  local runKey = addon.State.RaidRunKey
  if runKey and addon.DB and addon.DB.loadRaidRun then
    local loaded = addon.DB.loadRaidRun(runKey)
    for encId, val in pairs(loaded.cleared or {}) do
      addon.State.ClearedEncounters[encId] = val
    end
    if loaded.lastEncounter and not addon.State.LastEncounter then
      addon.State.LastEncounter = loaded.lastEncounter
    end
    addon.State.EncounterDrops = copyEncounterDrops(loaded.drops)
  end

  for encId, val in pairs(memory) do
    if val then
      addon.State.ClearedEncounters[encId] = true
      if runKey then
        persistMemoryClears(runKey, addon.State.InstanceId, { [encId] = true })
      end
    end
  end

  for encId, list in pairs(memoryDrops) do
    if list and #list > 0 then
      appendDropsToState(encId, list)
      if runKey then
        addon.DB.appendEncounterDrops(runKey, addon.State.InstanceId, encId, list)
      end
    end
  end
end

local function notifyRaidStateChanged()
  if addon.UI and addon.UI.onRaidStateChanged then
    addon.UI.onRaidStateChanged()
  end
end

local function unregisterNpcCaptureEvents()
  pendingRunInstanceCapture = false
  if not npcCaptureEventsRegistered then
    return
  end
  eventFrame:UnregisterEvent("PLAYER_TARGET_CHANGED")
  eventFrame:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
  npcCaptureEventsRegistered = false
end

local function registerNpcCaptureEvents()
  if npcCaptureEventsRegistered then
    return
  end
  pendingRunInstanceCapture = true
  eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
  eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
  npcCaptureEventsRegistered = true
end

local function applyRunInstanceCapture(runId)
  if not runId or runId == 0 or not addon.State.InstanceId then
    return false
  end

  local mapId = addon.State.InstanceId
  local newKey = addon.DB and addon.DB.getRaidRunKey and addon.DB.getRaidRunKey(mapId, runId)
  if not newKey then
    return false
  end

  local priorRunId = addon.State.RunInstanceId
  local priorKey = addon.State.RaidRunKey

  if priorRunId == runId and priorKey == newKey then
    unregisterNpcCaptureEvents()
    return true
  end

  local memory = addon.State.ClearedEncounters or {}
  local memoryDrops = addon.State.EncounterDrops or {}

  if priorKey and priorKey ~= newKey then
    persistMemoryClears(priorKey, mapId, memory)
    persistMemoryDrops(priorKey, mapId, memoryDrops)
    memory = {}
    memoryDrops = {}
    addon.State.AnnouncedLootBySource = {}
  end

  addon.State.RunInstanceId = runId
  addon.State.RaidRunKey = newKey
  addon.State.ClearedEncounters = memory
  addon.State.EncounterDrops = memoryDrops

  hydrateClearedEncounters()
  unregisterNpcCaptureEvents()
  notifyRaidStateChanged()
  return true
end

local function tryCaptureRunInstanceFromUnit(unit)
  local runId = runInstanceIdFromUnit(unit)
  if runId then
    return applyRunInstanceCapture(runId)
  end
  return false
end

local function tryCaptureRunInstanceFromNearbyNpcs()
  for _, unit in ipairs(NPC_CAPTURE_UNITS) do
    if tryCaptureRunInstanceFromUnit(unit) then
      return true
    end
  end
  return false
end

local function tryCaptureRunInstanceFromUnitGuid(guid)
  local runId = parseRunInstanceIdFromUnitGuid(guid)
  if runId then
    return applyRunInstanceCapture(runId)
  end
  return false
end

local function clearSessionRaidState()
  addon.State.InstanceId = nil
  addon.State.RunInstanceId = nil
  addon.State.RaidRunKey = nil
  addon.State.EncounterId = nil
  addon.State.LastEncounter = nil
  addon.State.LastKilledBoss = nil
  addon.State.ClearedEncounters = {}
  addon.State.EncounterDrops = {}
  addon.State.AnnouncedLootBySource = {}
  unregisterNpcCaptureEvents()
  eventFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

local function enterRaidInstance(instanceId)
  local priorMapId = addon.State.InstanceId
  local newMap = priorMapId ~= instanceId

  addon.State.InstanceId = instanceId

  if newMap then
    addon.State.RunInstanceId = nil
    addon.State.RaidRunKey = nil
    addon.State.ClearedEncounters = {}
    addon.State.EncounterDrops = {}
    addon.State.AnnouncedLootBySource = {}
    registerNpcCaptureEvents()
  elseif not addon.State.RaidRunKey then
    registerNpcCaptureEvents()
  end

  if not tryCaptureRunInstanceFromNearbyNpcs() and not addon.State.RaidRunKey then
    hydrateClearedEncounters()
  end

  eventFrame:RegisterEvent("ENCOUNTER_START")
  eventFrame:RegisterEvent("ENCOUNTER_END")
  eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  if TuskUpLoot.Data and TuskUpLoot.Data.requestInstanceItemData then
    TuskUpLoot.Data.requestInstanceItemData(instanceId)
  end
  notifyRaidStateChanged()
end

local function leaveRaidInstance()
  eventFrame:UnregisterEvent("ENCOUNTER_START")
  eventFrame:UnregisterEvent("ENCOUNTER_END")
  clearSessionRaidState()
  notifyRaidStateChanged()
end

local function recordEncounterClear(encounterId)
  if not addon.State.ClearedEncounters then
    addon.State.ClearedEncounters = {}
  end
  addon.State.ClearedEncounters[encounterId] = true
  addon.State.LastEncounter = encounterId

  local runKey = addon.State.RaidRunKey
  if runKey and addon.DB and addon.DB.saveEncounterClear then
    addon.DB.saveEncounterClear(runKey, addon.State.InstanceId, encounterId)
  end
end

local function handleCombatLog()
  ---@diagnostic disable-next-line: undefined-global
  local _, subevent, _, _, _, _, _, destGuid = CombatLogGetCurrentEventInfo()
  if subevent == "UNIT_DIED" and destGuid then
    if tryCaptureRunInstanceFromUnitGuid(destGuid) then
      -- run id captured from unit death
    end
    local parsed = parseLootSourceFromGuid(destGuid)
    local creatureId = parsed and parsed.sourceType == "npc" and parsed.sourceId
    local creature = creatureId and TuskUpLoot.Data.NPCs and TuskUpLoot.Data.NPCs[creatureId]
    if creature and addon.State.EncounterId then
      addon.State.LastKilledBoss = creatureId
      notifyRaidStateChanged()
    end
  end
end

local function isValidLoot(locked, quality, threshold)
  -- if quality and quality <= TuskUpLoot.Quality.Rare then return false end
  return not locked and quality and threshold < quality
end

local function updateLootMasterState()
  addon.State.IsLootMaster = IsInRaid() and IsMasterLooter()
end

local function collectRaidMemberKeys()
  local keys = {}
  if not IsInRaid() then
    return keys
  end
  for i = 1, GetNumGroupMembers() do
    local name = GetRaidRosterInfo(i)
    if name then
      keys[name:lower()] = name
    end
  end
  local player = UnitName("player")
  if player then
    keys[player:lower()] = player
  end
  return keys
end

local function filterNeedInfoToRaid(needInfo, raidKeys)
  local labels = {}
  local seen = {}

  if needInfo.hasRewardNeeds and needInfo.rewardGroups then
    for _, group in ipairs(needInfo.rewardGroups) do
      local pieceName = group.name or ("Item " .. tostring(group.itemId))
      for _, row in ipairs(group.needs or {}) do
        local key = row.characterKey
        if key and raidKeys[key] and not seen[key] then
          seen[key] = true
          local who = row.who or raidKeys[key]
          labels[#labels + 1] = string.format("%s (%s)", who, pieceName)
        end
      end
    end
  else
    for _, row in ipairs(needInfo.needs or {}) do
      local key = row.characterKey
      if key and raidKeys[key] and not seen[key] then
        seen[key] = true
        labels[#labels + 1] = row.who or raidKeys[key]
      end
    end
  end

  table.sort(labels)
  return labels
end

local function handleGroupLootStateChanged()
  updateLootMasterState()
end

local function getPrimaryLootSourceGuid(lootInfo)
  for itemIdx = 1, #(lootInfo or {}) do
    local guid = GetLootSourceInfo(itemIdx)
    if guid and guid ~= "" then
      return guid
    end
  end
  return nil
end

local function getSourceLedger(sourceGuid)
  if not sourceGuid then
    return nil
  end
  if not addon.State.AnnouncedLootBySource then
    addon.State.AnnouncedLootBySource = {}
  end
  local ledger = addon.State.AnnouncedLootBySource[sourceGuid]
  if not ledger then
    ledger = { items = {} }
    addon.State.AnnouncedLootBySource[sourceGuid] = ledger
  end
  return ledger
end

local function sendLootNeedMessage(msg, isLootMaster)
  local Opts = addon.Opts
  local sendRaidChat = not Opts or not Opts.sendRaidChatEnabled or Opts.sendRaidChatEnabled()
  if isLootMaster and sendRaidChat then
    C_ChatInfo.SendChatMessage(msg, "RAID")
  end
  -- addon.debugPrint(msg)  -- uncomment locally to debug without ML/RL
end

-- —— Event Handlers ———————————————————————————————————————————————————————————

-- Begin ADDON_LOADED handler (fires on startup and reload)
local function handleAddonLoaded(...)
  local addonName = ...
  if addonName ~= addon.addonName then
    return
  end

  if addon.DB and addon.DB.init then
    addon.DB.init()
    addon.dbInitialized = true
  end
  if addon.Opts and addon.Opts.init then
    addon.Opts.init()
  end

  eventFrame:UnregisterEvent("ADDON_LOADED")
end
-- End ADDON_LOADED handler

-- Begin PLAYER_LOGIN handler (fires on character login and reload)
local function handlePlayerLogin()
  local networked = false
  if addon.Net and addon.Net.init then
    addon.Net.init()
    networked = true
  end

  local playerName = getFullPlayerName()
  if playerName then
    addon.debugPrint("playerName: " .. playerName)
    addon.PlayerCharacter = playerName
  else
    addon.debugPrint("playerName not found")
    addon.PlayerCharacter = nil
  end

  local Util = addon.UI and addon.UI.Util
  local itemIds = Util and Util.getAllItemIds and Util.getAllItemIds() or {}
  addon.totalItems = itemIds and #itemIds or 0
  if addon.totalItems > 0 then
    if TuskUpLoot.ItemCache and TuskUpLoot.ItemCache.preloadAll then
      TuskUpLoot.ItemCache.preloadAll(itemIds, function()
        addon.debugPrint("Item cache ready.")
        if addon.UI and addon.UI.rebuildItemList then
          addon.UI.rebuildItemList()
        end
      end)
    end
    local suffix = networked and " and Networked." or "."
    addon.chatPrint("AddOn Initialized" .. suffix ..
      " Data for " .. tostring(addon.totalItems) .. " items requested.")
  else
    addon.chatPrint("AddOn Initialized. No items to request.")
  end

  eventFrame:UnregisterEvent("PLAYER_LOGIN")
end
-- End PLAYER_LOGIN handler

-- Begin PLAYER_ENTERING_WORLD handler (fires essentially each loading screen)
local function handlePlayerEnteringWorld()
  local _, instanceType, _, _, _, _, _, instanceId = GetInstanceInfo()
  local instance = TuskUpLoot.Data.Instances[instanceId]
  if instanceType == "raid" and instance then
    enterRaidInstance(instanceId)
  end

  updateLootMasterState()
end
-- End PLAYER_ENTERING_WORLD handler

-- Begin CHAT_MSG_ADDON handler (fires on addon message)
local function handleChatMessageAddon(...)
  local prefix, message, distribution, sender = ...
  addon.debugPrint("addon msg recvd: " .. prefix .. " " .. message .. " " .. distribution .. " " .. sender)
  if addon.Net and addon.Net.handleMessage then
    addon.Net.handleMessage(prefix, message, distribution, sender)
  end
end
-- End CHAT_MSG_ADDON handler

-- Begin ZONE_CHANGED_NEW_AREA handler (fires on zone change)
local function handleZoneChangedNewArea()
  local _, instanceType, _, _, _, _, _, instanceId = GetInstanceInfo()
  local instance = TuskUpLoot.Data.Instances[instanceId]
  if instanceType ~= "raid" or not instance then
    leaveRaidInstance()
    return
  end
  if addon.State.InstanceId == instanceId then
    tryCaptureRunInstanceFromNearbyNpcs()
    return
  end
  enterRaidInstance(instanceId)
end
-- End ZONE_CHANGED_NEW_AREA handler

-- Begin ENCOUNTER_START handler (fires on encounter start)
local function handleEncounterStart(...)
  local encounterId = ...
  local encounter = TuskUpLoot.Data.Encounters[encounterId]
  if not encounter then return end
  if encounter.instance_id ~= addon.State.InstanceId then return end
  addon.State.EncounterId = encounterId
  tryCaptureRunInstanceFromNearbyNpcs()
end
-- End ENCOUNTER_START handler

-- Begin ENCOUNTER_END handler (fires on encounter end)
local function handleEncounterEnd(...)
  local encounterId, _, _, _, success = ...
  local encounter = TuskUpLoot.Data.Encounters[encounterId]
  if not encounter then return end
  if encounter.instance_id ~= addon.State.InstanceId then return end
  if success then
    tryCaptureRunInstanceFromNearbyNpcs()
    recordEncounterClear(encounterId)
    notifyRaidStateChanged()
  end
  addon.State.EncounterId = nil
end
-- End ENCOUNTER_END handler

-- PARTY_LOOT_METHOD_CHANGED
-- GROUP_ROSTER_UPDATE
-- PLAYER_ROLES_ASSIGNED

-- Begin LOOT_OPENED handler (fires when loot dialog opens)
local function handleLootOpened(...)
  -- if not addon.State.InstanceId then
  --   return
  -- end

  local isLootMaster = addon.State.IsLootMaster or false
  local lootInfo = GetLootInfo()
  local lootThreshold = GetLootThreshold()
  local raidKeys = collectRaidMemberKeys()
  local Data = addon.Data

  local sourceGuid = getPrimaryLootSourceGuid(lootInfo)
  if not sourceGuid then
    return
  end

  local ledger = getSourceLedger(sourceGuid)
  if not ledger or ledger.complete then
    -- addon.chatPrint("source already complete: " .. tostring(sourceGuid))
    return
  end

  local parsed = parseLootSourceFromGuid(sourceGuid)
  local dropBucket = Data.TRASH_DROP_BUCKET
  if parsed then
    dropBucket = Data.resolveDropBucket(
      addon.State.InstanceId,
      parsed.sourceType,
      parsed.sourceId,
      addon.State.ClearedEncounters
    )
  end
  -- addon.chatPrint(string.format(
  --   "loot source %s type=%s id=%s bucket=%s",
  --   tostring(sourceGuid),
  --   parsed and parsed.sourceType or "?",
  --   parsed and tostring(parsed.sourceId) or "?",
  --   tostring(dropBucket)
  -- ))

  local collectedSlots = {}
  local collectedIds = {}
  for itemIdx, itemInfo in ipairs(lootInfo) do
    local itemLink = GetLootSlotLink(itemIdx)
    if itemLink then
      local dropId = C_Item.GetItemIDForItemInfo(itemLink)
      if dropId then
        collectedSlots[#collectedSlots + 1] = {
          itemId = dropId,
          itemLink = itemLink,
          locked = itemInfo.locked,
          quality = itemInfo.quality,
        }
        collectedIds[#collectedIds + 1] = dropId
      end
    end
  end

  if #collectedSlots == 0 then
    ledger.complete = true
    return
  end

  local broadcastIds = {}
  for _, slot in ipairs(collectedSlots) do
    local dropId = slot.itemId
    if ledger.items[dropId] then
      -- addon.chatPrint("item already announced: " .. tostring(dropId))
    elseif not Data.isRaidBroadcastExcluded(dropId)
        and isValidLoot(slot.locked, slot.quality, lootThreshold)
        and Data.getItemNeedInfo then
      broadcastIds[#broadcastIds + 1] = dropId
      local needInfo = Data.getItemNeedInfo(dropId)
      local neededBy = filterNeedInfoToRaid(needInfo, raidKeys)
      local msg
      if #neededBy > 0 then
        msg = string.format("%s - needed by %s", slot.itemLink, table.concat(neededBy, ", "))
      else
        msg = string.format("%s - not needed by any raid member", slot.itemLink)
      end
      sendLootNeedMessage(msg, isLootMaster)
      ledger.items[dropId] = true
    end
  end

  if isLootMaster then
    mergeEncounterDrops(dropBucket, collectedIds)
    if addon.Net and addon.Net.broadcastLootDrop then
      addon.Net.broadcastLootDrop(dropBucket, broadcastIds)
    end
  else
    -- if not loot master, wait on loot master broadcast to record
    -- addon.chatPrint("skipped record (not loot master)")
  end

  ledger.complete = true
end
-- End LOOT_OPENED handler

-- Begin eventHandler (fires on all events)
local function eventHandler(_, event, ...)
  if event == "ADDON_LOADED" then
    return handleAddonLoaded(...)
  elseif event == "PLAYER_LOGIN" then
    return handlePlayerLogin()
  elseif event == "PLAYER_ENTERING_WORLD" then
    return handlePlayerEnteringWorld()
  elseif event == "CHAT_MSG_ADDON" then
    return handleChatMessageAddon(...)
  elseif event == "ZONE_CHANGED_NEW_AREA" then
    return handleZoneChangedNewArea()
  elseif event == "ENCOUNTER_START" then
    return handleEncounterStart(...)
  elseif event == "ENCOUNTER_END" then
    return handleEncounterEnd(...)
  elseif event == "PLAYER_TARGET_CHANGED" or event == "UPDATE_MOUSEOVER_UNIT" then
    if addon.State.InstanceId then
      tryCaptureRunInstanceFromNearbyNpcs()
    end
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    if addon.State.InstanceId then
      handleCombatLog()
    end
  elseif event == "LOOT_OPENED" then
    return handleLootOpened(...)
  elseif event == "PARTY_LOOT_METHOD_CHANGED"
      or event == "GROUP_ROSTER_UPDATE"
      or event == "PLAYER_ROLES_ASSIGNED" then
    return handleGroupLootStateChanged()
  end
end
-- End eventHandler

-- Register events on our handler frame
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("LOOT_OPENED")
eventFrame:RegisterEvent("PARTY_LOOT_METHOD_CHANGED")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
eventFrame:SetScript("OnEvent", eventHandler)
-- End event registration

-- Begin slash command definitions
SLASH_TUSKUPLOOT1 = "/tul"
SLASH_TUSKUPLOOT2 = "/tuskup"
SlashCmdList.TUSKUPLOOT = function()
  if addon.UI and addon.UI.toggle then
    addon.UI.toggle()
  end
end
-- End slash command definitions
