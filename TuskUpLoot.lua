local ADDON_NAME = ...

local addon = TuskUpLoot

-- Public addon state (shared with modules loaded via .toc)
addon.addonName = ADDON_NAME
addon.frame = nil
addon.text = nil
addon.updateAccumulator = 0
addon.updateIntervalSeconds = 0.5
addon.isInitialized = false
addon.selectedCharacterKey = nil
addon.importPanelOpen = false

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
  if addon.DB and addon.DB.ensure then
    addon.DB.ensure()
  end

  if not addon.isInitialized then
    addon.isInitialized = true
    addon.chatPrint("Initialized.")

    SLASH_TUSKUPLOOT1 = "/tul"
    SLASH_TUSKUPLOOT2 = "/tuskup"
    SlashCmdList.TUSKUPLOOT = function()
      addon.Frame:Toggle()
    end
  end

  -- If guild state changes while the window is open, hide it.
  if TuskUpLoot.frame and TuskUpLoot.frame:IsShown() and not TuskUpLoot.isInRequiredGuild() then
    TuskUpLoot.frame:Hide()
  end
end)
