local ADDON_NAME = ...

local addon = TuskUpLoot

addon.addonName = ADDON_NAME
addon.State = addon.State or {}

local REQUIRED_GUILD_NAME = "Tusk Up"
addon.requiredGuildName = REQUIRED_GUILD_NAME

function addon.chatPrint(msg)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cffffff88" .. ADDON_NAME .. "|r: " .. tostring(msg))
  end
end

local function isPlayerInGuild()
  return IsInGuild() and GetGuildInfo("player") ~= nil
end

function addon.isInRequiredGuild()
  if not isPlayerInGuild() then
    return true
  end
  local guildName = GetGuildInfo("player")
  return guildName == REQUIRED_GUILD_NAME
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

local function isCreatureGuid(guid)
  local parts = guidParts(guid)
  return parts[1] == "Creature"
end

-- Creature-0-ServerID-InstanceID-ZoneUID-SpawnUID (see UnitGUID wiki)
local function parseRunInstanceIdFromCreatureGuid(guid)
  if not isCreatureGuid(guid) then
    return nil
  end
  local parts = guidParts(guid)
  local instanceToken
  if parts[2] == "0" and #parts >= 4 then
    instanceToken = parts[4]
  elseif #parts >= 3 then
    instanceToken = parts[3]
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

local function hydrateClearedEncounters()
  local memory = addon.State.ClearedEncounters or {}
  addon.State.ClearedEncounters = {}

  local runKey = addon.State.RaidRunKey
  if runKey and addon.DB and addon.DB.loadRaidRun then
    local loaded = addon.DB.loadRaidRun(runKey)
    for encId, val in pairs(loaded.cleared or {}) do
      addon.State.ClearedEncounters[encId] = val
    end
    if loaded.lastEncounter and not addon.State.LastEncounter then
      addon.State.LastEncounter = loaded.lastEncounter
    end
  end

  for encId, val in pairs(memory) do
    if val then
      addon.State.ClearedEncounters[encId] = true
      if runKey then
        persistMemoryClears(runKey, addon.State.InstanceId, { [encId] = true })
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

  if priorKey and priorKey ~= newKey then
    persistMemoryClears(priorKey, mapId, memory)
    memory = {}
  end

  addon.State.RunInstanceId = runId
  addon.State.RaidRunKey = newKey
  addon.State.ClearedEncounters = memory

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

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
eventFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

local function eventHandler(_, event, ...)
  if event == "ADDON_LOADED" then
    local addonName = ...
    if addonName ~= addon.addonName then
      return
    end

    if addon.DB and addon.DB.init then
      addon.DB.init()
      addon.dbInitialized = true
    end

    local itemIds = addon.DB.sortedItemIDs()
    addon.totalItems = itemIds and #itemIds or 0
    if addon.totalItems > 0 then
      addon.pendingItems = {}
      for _, itemId in ipairs(itemIds) do
        addon.pendingItems[itemId] = true
      end
      addon.chatPrint("AddOn Initialized. Requesting item data for " .. tostring(addon.totalItems) .. " items.")
      for _, itemId in ipairs(itemIds) do
        C_Item.RequestLoadItemDataByID(itemId)
      end
    else
      addon.chatPrint("AddOn Initialized.")
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
  elseif event == "PLAYER_GUILD_UPDATE" then
    if addon.UI
        and addon.UI.frame
        and addon.UI.frame:IsShown()
        and not addon.isInRequiredGuild() then
      if addon.UI.dismissAllFrames then
        addon.UI.dismissAllFrames()
      elseif addon.UI.frame then
        addon.UI.frame:Hide()
      end
    end
  elseif event == "ITEM_DATA_LOAD_RESULT" then
    local itemId, success = ...
    if addon.pendingItems and addon.pendingItems[itemId] then
      addon.pendingItems[itemId] = nil
      if next(addon.pendingItems) == nil then
        addon.pendingItems = nil
        addon.chatPrint("All item data requests completed.")
        eventFrame:UnregisterEvent("ITEM_DATA_LOAD_RESULT")
      end
    end
  elseif event == "PLAYER_TARGET_CHANGED" or event == "UPDATE_MOUSEOVER_UNIT" then
    if addon.State.InstanceId then
      tryCaptureRunInstanceFromNearbyNpcs()
    end
  elseif event == "ZONE_CHANGED_NEW_AREA" then
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
  elseif event == "ENCOUNTER_START" then
    local encounterId = ...
    local encounter = TuskUpLoot.Data.Encounters[encounterId]
    if not encounter then return end
    if encounter.instance_id ~= addon.State.InstanceId then return end
    addon.State.EncounterId = encounterId
    tryCaptureRunInstanceFromNearbyNpcs()
  elseif event == "ENCOUNTER_END" then
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
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    if addon.State.InstanceId then
      handleCombatLog()
    end
  end
end

eventFrame:SetScript("OnEvent", eventHandler)

-- Guild sync disabled; re-enable by loading Sync/*.lua in .toc and uncommenting below.
-- if TuskUpLoot.Sync and TuskUpLoot.Sync.init then
--   TuskUpLoot.Sync.init(eventFrame)
-- end
