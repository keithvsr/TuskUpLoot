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

local function resetRaidState()
  addon.State.InstanceId = nil
  addon.State.EncounterId = nil
  addon.State.LastEncounter = nil
  addon.State.LastKilledBoss = nil
  addon.State.ClearedEncounters = {}
end

local function notifyRaidStateChanged()
  if addon.UI and addon.UI.onRaidStateChanged then
    addon.UI.onRaidStateChanged()
  end
end

local function enterRaidInstance(instanceId)
  addon.State.InstanceId = instanceId
  if not addon.State.ClearedEncounters then
    addon.State.ClearedEncounters = {}
  end
  eventFrame:RegisterEvent("ENCOUNTER_START")
  eventFrame:RegisterEvent("ENCOUNTER_END")
  notifyRaidStateChanged()
end

local function leaveRaidInstance()
  eventFrame:UnregisterEvent("ENCOUNTER_START")
  eventFrame:UnregisterEvent("ENCOUNTER_END")
  -- eventFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  resetRaidState()
  notifyRaidStateChanged()
end

local function recordEncounterClear(encounterId)
  if not addon.State.ClearedEncounters then
    addon.State.ClearedEncounters = {}
  end
  addon.State.ClearedEncounters[encounterId] = true
  addon.State.LastEncounter = encounterId
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
eventFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

-- local function getCreatureIdFromGuid(guid)
--   return tonumber(select(6, strsplit("-", guid)))
-- end

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
      addon.UI.frame:Hide()
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
  elseif event == "ZONE_CHANGED_NEW_AREA" then
    local _, instanceType, _, _, _, _, _, instanceId = GetInstanceInfo()
    local instance = TuskUpLoot.Data.Instances[instanceId]
    if instanceType ~= "raid" or not instance then
      leaveRaidInstance()
      return
    end
    enterRaidInstance(instanceId)
  elseif event == "ENCOUNTER_START" then
    local encounterId = ...
    local encounter = TuskUpLoot.Data.Encounters[encounterId]
    if not encounter then return end
    if encounter.instance_id ~= addon.State.InstanceId then return end
    addon.State.EncounterId = encounterId
    -- Combat log disabled for now; re-enable to track LastKilledBoss per NPC source.
    -- eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  elseif event == "ENCOUNTER_END" then
    local encounterId, _, _, _, success = ...
    local encounter = TuskUpLoot.Data.Encounters[encounterId]
    if not encounter then return end
    if encounter.instance_id ~= addon.State.InstanceId then return end
    if success then
      recordEncounterClear(encounterId)
      notifyRaidStateChanged()
    end
    addon.State.EncounterId = nil
    -- eventFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    -- elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    --   local encounterId = addon.State.EncounterId or nil
    --   if not encounterId then return end
    --   local ts, subevent, _, s_guid, s_name, _, _, d_guid, d_name = CombatLogGetCurrentEventInfo()
    --   if subevent ~= "UNIT_DIED" then return end
    --   local creaturePattern = "^Creature"
    --   if d_guid:match(creaturePattern) == nil then return end
    --   local creatureId = getCreatureIdFromGuid(d_guid)
    --   local creature = TuskUpLoot.Data.NPCs[creatureId]
    --   if not creature then return end
    --   addon.State.LastKilledBoss = creatureId
    --   notifyRaidStateChanged()
  end
end

eventFrame:SetScript("OnEvent", eventHandler)
