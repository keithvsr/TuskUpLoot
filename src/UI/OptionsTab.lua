-- Options tab: yes/no addon settings.

local UI = TuskUpLoot.UI
local Util = UI.Util
local Opts = TuskUpLoot.Opts

local OPTION_ROWS = {
  {
    key = "sendRaidChat",
    label = "Send raid chat when loot drops",
    getter = function()
      return Opts and Opts.sendRaidChatEnabled and Opts.sendRaidChatEnabled()
    end,
  },
  {
    key = "debug",
    label = "Enable debug messaging",
    getter = function()
      return Opts and Opts.debugEnabled and Opts.debugEnabled()
    end,
  },
}

StaticPopupDialogs["TUSKUPLOOT_RESET_DB"] = {
  text =
  "|cffff2020Warning:|r This permanently deletes ALL saved characters, gear sets, item needs, raid run data, and settings.\n\nThis cannot be undone.",
  button1 = "Reset everything",
  button2 = CANCEL,
  OnAccept = function()
    local DB = TuskUpLoot.DB
    if DB and DB.resetToDefaults and DB.resetToDefaults() then
      if Opts and Opts.init then
        Opts.init()
      end
      UI.selectedCharacterKey = nil
      UI.selectedItemId = nil
      UI.collapsedGearSets = {}
      if UI.refreshAfterImport then
        UI.refreshAfterImport()
      end
      if UI.renderOptionsPanel then
        UI.renderOptionsPanel()
      end
      Util.safeChatPrint("All saved data has been reset to defaults.")
    end
  end,
  timeout = 0,
  whileDead = 1,
  hideOnEscape = 1,
  preferredIndex = 3,
}

local function ensureOptionRows(container)
  if container.rows then
    return container.rows
  end

  local rows = {}
  local y = 32
  for i, def in ipairs(OPTION_ROWS) do
    local row = CreateFrame("Frame", nil, container)
    row:SetHeight(28)
    row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y)
    row:SetPoint("RIGHT", container, "RIGHT", 0, 0)

    local check = CreateFrame("CheckButton", "TuskUpLootOptCheck" .. def.key, row, "ChatConfigCheckButtonTemplate")
    check:SetPoint("LEFT", row, "LEFT", 0, 0)
    check:SetHitRectInsets(0, -280, 0, 0)
    if check.Text then
      check.Text:SetText(def.label)
    else
      local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      label:SetPoint("LEFT", check, "RIGHT", 4, 1)
      label:SetJustifyH("LEFT")
      label:SetText(def.label)
    end

    check:SetScript("OnClick", function(self)
      if Opts and Opts.set then
        Opts.set(def.key, self:GetChecked() and true or false)
      end
      UI.renderOptionsPanel()
    end)

    row.check = check
    row.def = def
    rows[i] = row
    y = y + 32
  end

  container.rows = rows
  container.optionRowsHeight = y
  return rows
end

local function ensureDangerSection(container)
  if container.dangerSection then
    return container.dangerSection
  end

  local startY = (container.optionRowsHeight or 96) + 24
  local section = CreateFrame("Frame", nil, container)
  section:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -startY)
  section:SetPoint("RIGHT", container, "RIGHT", 0, 0)
  section:SetHeight(96)

  local title = section:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", section, "TOPLEFT", 4, 0)
  title:SetJustifyH("LEFT")
  title:SetText("|cffff2020Danger|r")

  local warning = section:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  warning:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  warning:SetPoint("RIGHT", section, "RIGHT", -4, 0)
  warning:SetJustifyH("LEFT")
  warning:SetWordWrap(true)
  warning:SetText(
    "Permanently delete all imported characters, gear sets, item needs, raid run history, and reset addon settings.")

  local resetBtn = CreateFrame("Button", nil, section, "UIPanelButtonTemplate")
  resetBtn:SetSize(180, 22)
  resetBtn:SetPoint("TOPLEFT", warning, "BOTTOMLEFT", 0, -10)
  resetBtn:SetText("Reset all saved data")
  local resetFont = resetBtn.GetFontString and resetBtn:GetFontString()
  if resetFont and resetFont.SetTextColor then
    resetFont:SetTextColor(1, 0.25, 0.25)
  end
  resetBtn:SetScript("OnClick", function()
    StaticPopup_Show("TUSKUPLOOT_RESET_DB")
  end)

  section.title = title
  section.warning = warning
  section.resetBtn = resetBtn
  container.dangerSection = section
  container.totalHeight = startY + 96
  return section
end

local function ensureHyraxImage(container)
  if container.hyraxFrame then
    return container.hyraxFrame
  end

  local hyr = CreateFrame("Frame", "HyraxFrame", container)
  hyr:SetSize(64, 64)
  hyr:SetPoint("TOPRIGHT", container, "TOPRIGHT", -8, 8)

  local tex = hyr:CreateTexture("HyraxImageTex", "BACKGROUND")
  tex:SetAllPoints(hyr)
  tex:SetTexture("Interface/Addons/TuskUpLoot/Media/hyrax.png")

  local border = hyr:CreateTexture("HyraxBorder", "OVERLAY")
  border:SetTexture("Interface/Common/WhiteIconFrame")
  border:SetAllPoints(hyr)
  local color = ITEM_QUALITY_COLORS[TuskUpLoot.Quality.Heirloom]
  if color then
    border:SetVertexColor(color.r, color.g, color.b)
  end

  container.hyraxFrame = hyr
  return hyr
end

function UI.renderOptionsPanel()
  local container = UI.optionsContainer
  if not container then
    return
  end

  local rows = ensureOptionRows(container)
  for _, row in ipairs(rows) do
    local enabled = row.def.getter() and true or false
    row.check:SetChecked(enabled)
    row:Show()
  end

  local danger = ensureDangerSection(container)
  danger:Show()

  local hyrax = ensureHyraxImage(container)
  hyrax:Show()

  container:SetHeight(math.max(1, container.totalHeight or 192))
  container:Show()
end
