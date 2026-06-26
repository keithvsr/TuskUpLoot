local ADDON_NAME = ...

local addon = TuskUpLoot

addon.addonName = ADDON_NAME
addon.State = addon.State or {}

function addon.chatPrint(msg)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cffffff88" .. ADDON_NAME .. "|r: " .. tostring(msg))
  end
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

local function isCreatureGuid(guidPart)
  return guidPart == "Creature"
end

-- Creature-0-ServerID-InstanceID-ZoneUID-SpawnUID (see UnitGUID wiki)
local function parseRunInstanceIdFromCreatureGuid(guid)
  local parts = guidParts(guid)
  -- first part of the GUID shows type of unit
  if not isCreatureGuid(parts[1]) then return nil end
  local instanceToken = nil
  if parts[2] == "0" and #parts >= 4 then
    instanceToken = parts[5]
    -- FINDME: unclear on when this is used, leaving commented for now
    -- elseif #parts >= 3 then
    --   instanceToken = parts[3]
  end
  if not instanceToken then
    return nil
  end
  local runId = tonumber(instanceToken, 10)
  if runId and runId ~= 0 then
    return runId
  end
  return nil
end

local function getCreatureIdFromGuid(guid)
  if not isCreatureGuid(guid) then
    return nil
  end
  local parts = guidParts(guid)
  local spawnToken = parts[#parts]
  if not spawnToken then
    return nil
  end
  return tonumber(spawnToken, 16) or tonumber(spawnToken, 10)
end

local function runInstanceIdFromUnit(unit)
  if not unit or not UnitExists(unit) then
    return nil
  end
  return parseRunInstanceIdFromCreatureGuid(UnitGUID(unit))
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
local function mergeEncounterDrops(encounterId, itemIds)
  appendDropsToState(encounterId, itemIds)

  local runKey = addon.State.RaidRunKey
  if runKey and addon.DB and addon.DB.appendEncounterDrops then
    addon.DB.appendEncounterDrops(runKey, addon.State.InstanceId, encounterId, itemIds)
  end

  if addon.UI and addon.UI.focusEncounterId == encounterId and addon.UI.renderEncounterLootPanel then
    addon.UI.renderEncounterLootPanel()
  end
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

local function tryCaptureRunInstanceFromCreatureGuid(guid)
  local runId = parseRunInstanceIdFromCreatureGuid(guid)
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
    if tryCaptureRunInstanceFromCreatureGuid(destGuid) then
      -- run id captured from boss death
    end
    local creatureId = getCreatureIdFromGuid(destGuid)
    local creature = creatureId and TuskUpLoot.Data.NPCs and TuskUpLoot.Data.NPCs[creatureId]
    if creature and addon.State.EncounterId then
      addon.State.LastKilledBoss = creatureId
      notifyRaidStateChanged()
    end
  end
end

local function isValidLoot(locked, quality, threshold)
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

local function handleAddonLoaded(...)
  local addonName = ...
  if addonName ~= addon.addonName then
    return
  end

  if addon.DB and addon.DB.init then
    addon.DB.init()
    addon.dbInitialized = true
  end

  local Util = addon.UI and addon.UI.Util
  local itemIds = Util and Util.getAllItemIds and Util.getAllItemIds() or {}
  addon.totalItems = itemIds and #itemIds or 0
  if addon.totalItems > 0 then
    addon.chatPrint("AddOn Initialized. Requesting item data for " .. tostring(addon.totalItems) .. " items.")
    if TuskUpLoot.ItemCache and TuskUpLoot.ItemCache.preloadAll then
      TuskUpLoot.ItemCache.preloadAll(itemIds, function()
        addon.chatPrint("Item cache ready.")
        if addon.UI and addon.UI.rebuildItemList then
          addon.UI.rebuildItemList()
        end
      end)
    end
  else
    addon.chatPrint("AddOn Initialized. No items to request.")
  end

  SLASH_TUSKUPLOOT1 = "/tul"
  SLASH_TUSKUPLOOT2 = "/tuskup"
  SlashCmdList.TUSKUPLOOT = function()
    if addon.UI and addon.UI.toggle then
      addon.UI.toggle()
    end
  end

  eventFrame:UnregisterEvent("ADDON_LOADED")

  local _, instanceType, _, _, _, _, _, instanceId = GetInstanceInfo()
  local instance = TuskUpLoot.Data.Instances[instanceId]
  if instanceType == "raid" and instance then
    enterRaidInstance(instanceId)
  end

  updateLootMasterState()
end

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

local function handleEncounterStart(...)
  local encounterId = ...
  local encounter = TuskUpLoot.Data.Encounters[encounterId]
  if not encounter then return end
  if encounter.instance_id ~= addon.State.InstanceId then return end
  addon.State.EncounterId = encounterId
  tryCaptureRunInstanceFromNearbyNpcs()
end

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

-- PARTY_LOOT_METHOD_CHANGED
-- GROUP_ROSTER_UPDATE
-- PLAYER_ROLES_ASSIGNED

local function handleLootReady(...)
  if not addon.State.IsLootMaster then
    return
  end
  local lootInfo = GetLootInfo()

  -- get loot master threshold
  local lootThreshold = GetLootThreshold()
  local raidKeys = collectRaidMemberKeys()
  local Data = addon.Data

  local encounterId = addon.State.LastEncounter
  local cleared = addon.State.ClearedEncounters
  if encounterId and cleared and cleared[encounterId] then
    local collectedIds = {}
    for itemIdx, _ in ipairs(lootInfo) do
      local itemLink = GetLootSlotLink(itemIdx)
      if itemLink then
        local dropId = C_Item.GetItemIDForItemInfo(itemLink)
        if dropId then
          collectedIds[#collectedIds + 1] = dropId
        end
      end
    end
    if #collectedIds > 0 then
      mergeEncounterDrops(encounterId, collectedIds)
    end
  end

  for itemIdx, itemInfo in ipairs(lootInfo) do
    -- local itemInfo = lootInfo[itemIdx]
    -- local itemInfoAtIdx = lootInfo[itemIdx]
    -- if itemInfoAtIdx then
    addon.chatPrint(itemInfo.item .. " item info at idx (GetLootInfo)")
    -- end
    local itemLink = GetLootSlotLink(itemIdx)
    -- double check item is valid and returned data
    if itemLink and isValidLoot(itemInfo.locked, itemInfo.quality, lootThreshold) then
      -- local _, _, _, _, quality, locked = GetLootSlotInfo(itemIdx)
      -- if item is lootable
      -- addon.chatPrint(itemLink .. " is valid loot")
      -- addon.chatPrint(itemLink)
      -- C_ChatInfo.SendChatMessage(itemLink, "PARTY")
      local itemId = C_Item.GetItemIDForItemInfo(itemLink)
      -- addon.chatPrint(string.format("Item ID: %s", itemId))

      if itemId and Data and Data.getItemNeedInfo then
        local needInfo = Data.getItemNeedInfo(itemId)
        local neededBy = filterNeedInfoToRaid(needInfo, raidKeys)
        if #neededBy > 0 then
          C_ChatInfo.SendChatMessage(
            string.format("%s - needed by %s", itemLink, table.concat(neededBy, ", ")),
            "RAID"
          )
        else
          C_ChatInfo.SendChatMessage(
            string.format("%s - not needed by any raid member", itemLink),
            "RAID"
          )
        end
      end
      -- end
    end
  end
end

local function eventHandler(_, event, ...)
  if event == "ADDON_LOADED" then
    return handleAddonLoaded(...)
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
  elseif event == "LOOT_READY" then
    return handleLootReady(...)
  elseif event == "PARTY_LOOT_METHOD_CHANGED"
      or event == "GROUP_ROSTER_UPDATE"
      or event == "PLAYER_ROLES_ASSIGNED" then
    return handleGroupLootStateChanged()
  end
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("LOOT_READY")
eventFrame:RegisterEvent("PARTY_LOOT_METHOD_CHANGED")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
eventFrame:SetScript("OnEvent", eventHandler)

-- Guild sync disabled; re-enable by loading Sync/*.lua in .toc and uncommenting below.
-- if TuskUpLoot.Sync and TuskUpLoot.Sync.init then
--   TuskUpLoot.Sync.init(eventFrame)
-- end
