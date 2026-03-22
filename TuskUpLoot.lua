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

function addon.isInRequiredGuild()
  if not GetGuildInfo then
    return true
  end
  local guildName = GetGuildInfo("player")
  return guildName == REQUIRED_GUILD_NAME
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
eventFrame:SetScript("OnEvent", function()
  if addon.DB and addon.DB.init then
    addon.DB.init()
  end

  if not addon.isInitialized then
    addon.isInitialized = true
    addon.chatPrint("Initialized.")

    SLASH_TUSKUPLOOT1 = "/tul"
    SLASH_TUSKUPLOOT2 = "/tuskup"
    SlashCmdList.TUSKUPLOOT = function()
      if addon.UI and addon.UI.Toggle then
        addon.UI:Toggle()
      end
    end
  end

  if addon.UI and addon.UI.frame and addon.UI.frame:IsShown() and not addon.isInRequiredGuild() then
    addon.UI.frame:Hide()
  end
end)
