-- Options tab: yes/no addon settings.

local UI = TuskUpLoot.UI
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

local function ensureOptionRows(container)
  if container.rows then
    return container.rows
  end

  local rows = {}
  local y = 0
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
  container:SetHeight(math.max(1, y))
  return rows
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
  container:Show()
end
