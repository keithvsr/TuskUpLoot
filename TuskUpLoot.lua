local ADDON_NAME = ...

local addon = TuskUpLoot

addon.addonName = ADDON_NAME

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

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
-- eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
eventFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
eventFrame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    local addonName = ...
    if addonName ~= addon.addonName then
      return
    end

    -- only need to init the DB once on startup
    if addon.DB and addon.DB.init then
      addon.DB.init()
      addon.dbInitialized = true
    end

    -- request to load item data for each item in DB
    local itemIds = addon.DB.sortedItemIDs()
    addon.totalItems = itemIds and #itemIds or 0
    if addon.totalItems > 0 then
      addon.pendingItems = {}
      -- track the items that are pending
      for _, itemId in ipairs(itemIds) do
        addon.pendingItems[itemId] = true
      end
      -- request the item data
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
    -- end ADDON_LOADED event handler
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
        addon.pendingItems = nil -- clean up
        addon.chatPrint("All item data requests completed.")
      end
    end
  end
end)
