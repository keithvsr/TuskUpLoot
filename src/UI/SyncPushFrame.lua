-- Push sync data: select characters to offer.

local _, TUL = ...

local UI = TUL.UI
local Util = UI.Util
local C = UI.Constants
local DB = TUL.DB

local sessionSelectedCharacters = {}

local function hideSyncPushFrameShowMain()
  if UI.syncPushFrame then
    UI.syncPushFrame:Hide()
  end
  if UI.frame then
    UI.frame:Show()
  end
end

local function getSelectedCharacterKeys()
  local selected = {}
  if not UI.syncPushCharChecks then
    return selected
  end
  for characterKey, check in pairs(UI.syncPushCharChecks) do
    if check:GetChecked() then
      selected[#selected + 1] = characterKey
    end
  end
  table.sort(selected)
  return selected
end

local function setAllCharacterChecks(checked)
  if not UI.syncPushCharChecks then
    return
  end
  for characterKey, check in pairs(UI.syncPushCharChecks) do
    check:SetChecked(checked and true or false)
    sessionSelectedCharacters[characterKey] = checked and true or false
  end
end

local function persistCheckboxState(characterKey, checked)
  sessionSelectedCharacters[characterKey] = checked and true or false
end

local function restoreCheckboxState(check, characterKey)
  local checked = sessionSelectedCharacters[characterKey]
  if checked == nil then
    checked = true
    sessionSelectedCharacters[characterKey] = true
  end
  check:SetChecked(checked)
end

local function rebuildCharacterCheckList()
  if not UI.syncPushCharContainer then
    return
  end

  local container = UI.syncPushCharContainer
  if container.rows then
    for _, row in ipairs(container.rows) do
      row:Hide()
    end
  end
  container.rows = container.rows or {}
  UI.syncPushCharChecks = {}

  local characters = DB and DB.characterNamesAndClasses and DB.characterNamesAndClasses() or {}
  table.sort(characters, function(a, b)
    return (a.name or a.key or "") < (b.name or b.key or "")
  end)

  local y = -4
  local rowHeight = 24
  for i, row in ipairs(characters) do
    local characterKey = row.key
    local charRow = container.rows[i]
    if not charRow then
      charRow = CreateFrame("Frame", nil, container)
      charRow.check = CreateFrame("CheckButton", nil, charRow, "ChatConfigCheckButtonTemplate")
      charRow.check:SetPoint("LEFT", charRow, "LEFT", 0, 0)
      charRow.check:SetHitRectInsets(0, -320, 0, 0)
      container.rows[i] = charRow
    end

    charRow:SetHeight(rowHeight)
    charRow:ClearAllPoints()
    charRow:SetPoint("TOPLEFT", container, "TOPLEFT", 0, y)
    charRow:SetPoint("RIGHT", container, "RIGHT", 0, 0)

    local class = row.class or "PRIEST"
    local classColor = C_ClassColor.GetClassColor(class)
    local hex = classColor and classColor:GenerateHexColor() or "ffffffff"
    local label = string.format("|c%s%s|r", hex, row.name or characterKey)

    if charRow.check.Text then
      charRow.check.Text:SetText(label)
    end

    local captureKey = characterKey
    charRow.check:SetScript("OnClick", function(self)
      persistCheckboxState(captureKey, self:GetChecked())
    end)
    restoreCheckboxState(charRow.check, characterKey)

    UI.syncPushCharChecks[characterKey] = charRow.check
    charRow:Show()
    y = y - rowHeight
  end

  container:SetHeight(math.max(1, math.abs(y)))
end

function UI.ensureSyncPushFrame()
  if UI.syncPushFrame then
    return
  end

  local f = CreateFrame("Frame", "TuskUpLootSyncPushFrame", UIParent, "UIPanelDialogTemplate")
  f:SetSize(C.SYNC_PUSH_FRAME_WIDTH, C.SYNC_PUSH_FRAME_HEIGHT)
  f:SetPoint("CENTER")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  f:Hide()

  local dragRegion = CreateFrame("Frame", nil, f)
  dragRegion:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
  dragRegion:SetPoint("TOPRIGHT", f, "TOPRIGHT", -44, -10)
  dragRegion:SetHeight(26)
  dragRegion:EnableMouse(true)
  dragRegion:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" then
      f:StartMoving()
    end
  end)
  dragRegion:SetScript("OnMouseUp", function()
    f:StopMovingOrSizing()
  end)

  f:SetScript("OnHide", function()
    if UI.frame and not UI.frame:IsShown() then
      UI.frame:Show()
    end
  end)

  f:SetScript("OnShow", function()
    Util.bringUISpecialFrameToFront("TuskUpLootSyncPushFrame")
    rebuildCharacterCheckList()
  end)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", f, "TOP", 0, -8)
  title:SetText("Push sync data")

  local charLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  charLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -40)
  charLabel:SetText("Select characters to push:")

  local bulkRow = CreateFrame("Frame", nil, f)
  bulkRow:SetPoint("TOPRIGHT", f, "TOPRIGHT", -20, -38)
  bulkRow:SetSize(200, 22)

  local selectAllBtn = CreateFrame("Button", nil, bulkRow, "UIPanelButtonTemplate")
  selectAllBtn:SetSize(80, 22)
  selectAllBtn:SetPoint("RIGHT", bulkRow, "RIGHT", 0, 0)
  selectAllBtn:SetText("Select All")
  selectAllBtn:SetScript("OnClick", function()
    setAllCharacterChecks(true)
  end)
  UI.syncPushSelectAllBtn = selectAllBtn

  local clearBtn = CreateFrame("Button", nil, bulkRow, "UIPanelButtonTemplate")
  clearBtn:SetSize(80, 22)
  clearBtn:SetPoint("RIGHT", selectAllBtn, "LEFT", -8, 0)
  clearBtn:SetText("Clear")
  clearBtn:SetScript("OnClick", function()
    setAllCharacterChecks(false)
  end)
  UI.syncPushClearBtn = clearBtn

  local charScroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  charScroll:SetPoint("TOPLEFT", charLabel, "BOTTOMLEFT", 0, -6)
  charScroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -32, 52)
  charScroll:SetHeight(C.SYNC_PUSH_CHAR_LIST_HEIGHT)

  local charContainer = CreateFrame("Frame", nil, charScroll)
  charContainer:SetWidth(C.SYNC_PUSH_EDIT_WIDTH)
  charContainer:SetHeight(1)
  charScroll:SetScrollChild(charContainer)
  UI.syncPushCharContainer = charContainer

  local pushBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  pushBtn:SetSize(90, 22)
  pushBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 18)
  pushBtn:SetText("Push")
  pushBtn:SetScript("OnClick", function()
    local Sync = TUL.Sync
    if not Sync then
      Util.safeChatPrint("Sync module unavailable.")
      return
    end

    local keys = getSelectedCharacterKeys()
    if #keys == 0 then
      Util.safeChatPrint("Select at least one character to push.")
      return
    end

    hideSyncPushFrameShowMain()

    UI.showSyncPicker(function(targetName)
      Sync.pushSelected(targetName, keys)
    end)
  end)

  local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  cancelBtn:SetSize(90, 22)
  cancelBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 120, 18)
  cancelBtn:SetText("Cancel")
  cancelBtn:SetScript("OnClick", function()
    hideSyncPushFrameShowMain()
  end)

  Util.setCloseButtonPlacement(f)
  Util.ensureUISpecialFrame("TuskUpLootSyncPushFrame")

  UI.syncPushFrame = f
end
