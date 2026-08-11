-- Export Gargul soft reserve dialog.

local UI = TuskUpLoot.UI
local Util = UI.Util
local C = UI.Constants
local Data = TuskUpLoot.Data

local sessionSelectedInstances = {}

UI.exportImportedSR = UI.exportImportedSR or nil

local function hideExportFrameShowMain()
  UI.exportImportedSR = nil
  if UI.exportFrame then
    UI.exportFrame:Hide()
  end
  if UI.frame then
    UI.frame:Show()
  end
end

local function getSelectedInstanceIds()
  local selected = {}
  if not UI.exportRaidChecks then
    return selected
  end
  for instanceId, check in pairs(UI.exportRaidChecks) do
    if check:GetChecked() then
      selected[#selected + 1] = instanceId
    end
  end
  table.sort(selected)
  return selected
end

local function setAllRaidChecks(checked)
  if not UI.exportRaidChecks then
    return
  end
  for instanceId, check in pairs(UI.exportRaidChecks) do
    check:SetChecked(checked and true or false)
    sessionSelectedInstances[instanceId] = checked and true or false
  end
end

local function persistCheckboxState(instanceId, checked)
  sessionSelectedInstances[instanceId] = checked and true or false
end

local function restoreCheckboxState(check, instanceId)
  local checked = sessionSelectedInstances[instanceId]
  if checked == nil then
    checked = true
    sessionSelectedInstances[instanceId] = true
  end
  check:SetChecked(checked)
end

local function applyInstanceSelection(instanceIds)
  local selectedSet = {}
  for _, instanceId in ipairs(instanceIds or {}) do
    selectedSet[instanceId] = true
  end

  if not UI.exportRaidChecks then
    return
  end

  for instanceId, check in pairs(UI.exportRaidChecks) do
    local checked = selectedSet[instanceId] and true or false
    check:SetChecked(checked)
    sessionSelectedInstances[instanceId] = checked
  end
end

UI.applyExportInstanceSelection = applyInstanceSelection

local function updateImportStatus()
  if not UI.exportImportStatus then
    return
  end

  if UI.exportImportedSR then
    local SR = TuskUpLoot.SR
    local summary = SR and SR.summarize(UI.exportImportedSR) or {}
    UI.exportImportStatus:SetText(string.format(
      "External SR loaded (%d players)",
      summary.playerCount or 0
    ))
    UI.exportImportStatus:Show()
  else
    UI.exportImportStatus:Hide()
  end

  if UI.exportGenerateBtn then
    local topAnchor = UI.exportRaidScroll
    if UI.exportImportStatus:IsShown() then
      topAnchor = UI.exportImportStatus
    end
    UI.exportGenerateBtn:ClearAllPoints()
    UI.exportGenerateBtn:SetPoint("TOPLEFT", topAnchor, "BOTTOMLEFT", 0, -8)
  end
end

UI.updateExportImportStatus = updateImportStatus

function UI.ensureExportFrame()
  if UI.exportFrame then
    return
  end

  local exp = CreateFrame("Frame", "TuskUpLootExportFrame", UIParent, "UIPanelDialogTemplate")
  exp:SetSize(C.EXPORT_FRAME_WIDTH, C.EXPORT_FRAME_HEIGHT)
  exp:SetPoint("CENTER")
  exp:SetMovable(true)
  exp:EnableMouse(true)
  exp:SetClampedToScreen(true)
  exp:Hide()

  local dragRegion = CreateFrame("Frame", nil, exp)
  dragRegion:SetPoint("TOPLEFT", exp, "TOPLEFT", 10, -10)
  dragRegion:SetPoint("TOPRIGHT", exp, "TOPRIGHT", -44, -10)
  dragRegion:SetHeight(26)
  dragRegion:EnableMouse(true)
  dragRegion:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" then
      exp:StartMoving()
    end
  end)
  dragRegion:SetScript("OnMouseUp", function()
    exp:StopMovingOrSizing()
  end)

  exp:SetScript("OnShow", function()
    Util.bringUISpecialFrameToFront("TuskUpLootExportFrame")
    updateImportStatus()
  end)

  exp:SetScript("OnHide", function()
    if UI.exportTransitionToSRImport then
      return
    end
    if UI.exportSRImportFrame and UI.exportSRImportFrame:IsShown() then
      return
    end

    UI.exportImportedSR = nil

    if UI.exportEditBox then
      UI.exportEditBox:ClearFocus()
      UI.exportEditBox:HighlightText(0, 0)
    end
    if UI.frame and not UI.frame:IsShown() then
      UI.frame:Show()
    end
  end)

  Util.bindFrameEscapeDismiss(exp, function(frame)
    if UI.exportEditBox then
      UI.exportEditBox:ClearFocus()
      UI.exportEditBox:HighlightText(0, 0)
    end
    frame:Hide()
  end)

  local title = exp:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", exp, "TOP", 0, -8)
  title:SetText("Export Gargul Soft Reserves")

  local raidLabel = exp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  raidLabel:SetPoint("TOPLEFT", exp, "TOPLEFT", 20, -40)
  raidLabel:SetText("Select raids to include:")

  local bulkRow = CreateFrame("Frame", nil, exp)
  bulkRow:SetPoint("TOPRIGHT", exp, "TOPRIGHT", -20, -38)
  bulkRow:SetSize(280, 22)

  local selectAllBtn = CreateFrame("Button", nil, bulkRow, "UIPanelButtonTemplate")
  selectAllBtn:SetSize(80, 22)
  selectAllBtn:SetPoint("RIGHT", bulkRow, "RIGHT", 0, 0)
  selectAllBtn:SetText("Select All")
  selectAllBtn:SetScript("OnClick", function()
    setAllRaidChecks(true)
  end)

  local clearBtn = CreateFrame("Button", nil, bulkRow, "UIPanelButtonTemplate")
  clearBtn:SetSize(80, 22)
  clearBtn:SetPoint("RIGHT", selectAllBtn, "LEFT", -8, 0)
  clearBtn:SetText("Clear")
  clearBtn:SetScript("OnClick", function()
    setAllRaidChecks(false)
  end)

  local importSRBtn = CreateFrame("Button", nil, bulkRow, "UIPanelButtonTemplate")
  importSRBtn:SetSize(80, 22)
  importSRBtn:SetPoint("RIGHT", clearBtn, "LEFT", -8, 0)
  importSRBtn:SetText("Import SR")
  importSRBtn:SetScript("OnClick", function()
    UI.openExportSRImportFrame()
  end)

  local raidScroll = CreateFrame("ScrollFrame", nil, exp, "UIPanelScrollFrameTemplate")
  raidScroll:SetPoint("TOPLEFT", raidLabel, "BOTTOMLEFT", 0, -6)
  raidScroll:SetPoint("TOPRIGHT", exp, "TOPRIGHT", -32, -66)
  raidScroll:SetHeight(C.EXPORT_RAID_LIST_HEIGHT)
  UI.exportRaidScroll = raidScroll

  local raidContainer = CreateFrame("Frame", nil, raidScroll)
  raidContainer:SetWidth(C.EXPORT_EDIT_WIDTH)
  raidContainer:SetHeight(1)
  raidScroll:SetScrollChild(raidContainer)

  UI.exportRaidChecks = {}
  local y = -4
  local rowHeight = 24
  for _, instanceId in ipairs(Data.orderedInstanceIds()) do
    local instance = Data.Instances[instanceId]
    if instance then
      local row = CreateFrame("Frame", nil, raidContainer)
      row:SetHeight(rowHeight)
      row:SetPoint("TOPLEFT", raidContainer, "TOPLEFT", 0, y)
      row:SetPoint("RIGHT", raidContainer, "RIGHT", 0, 0)

      local check = CreateFrame("CheckButton", nil, row, "ChatConfigCheckButtonTemplate")
      check:SetPoint("LEFT", row, "LEFT", 0, 0)
      check:SetHitRectInsets(0, -320, 0, 0)
      if check.Text then
        check.Text:SetText(instance.name or tostring(instanceId))
      end

      local captureId = instanceId
      check:SetScript("OnClick", function(self)
        persistCheckboxState(captureId, self:GetChecked())
      end)
      restoreCheckboxState(check, instanceId)

      UI.exportRaidChecks[instanceId] = check
      y = y - rowHeight
    end
  end
  raidContainer:SetHeight(math.max(1, math.abs(y)))

  local importStatus = exp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  importStatus:SetPoint("TOPLEFT", raidScroll, "BOTTOMLEFT", 0, -4)
  importStatus:Hide()
  UI.exportImportStatus = importStatus

  local generateBtn = CreateFrame("Button", nil, exp, "UIPanelButtonTemplate")
  generateBtn:SetSize(90, 22)
  generateBtn:SetPoint("TOPLEFT", raidScroll, "BOTTOMLEFT", 0, -8)
  generateBtn:SetText("Generate")
  UI.exportGenerateBtn = generateBtn
  generateBtn:SetScript("OnClick", function()
    local selected = getSelectedInstanceIds()
    if #selected == 0 then
      Util.safeChatPrint("Select at least one raid to export.")
      return
    end

    local GL = TuskUpLoot.Export and TuskUpLoot.Export.GL
    if not GL or not GL.export then
      Util.safeChatPrint("Export module unavailable.")
      return
    end

    local exportString, err, summary = GL.export(selected, UI.exportImportedSR)
    if not exportString then
      Util.safeChatPrint("Export failed: " .. tostring(err or "unknown"))
      return
    end

    local outEdit = UI.exportEditBox
    if not outEdit then
      return
    end
    outEdit:SetText(exportString)
    outEdit:SetFocus()
    outEdit:HighlightText()

    if summary then
      Util.safeChatPrint(string.format(
        "Gargul export ready: %d players, %d items.",
        summary.playerCount or 0,
        summary.itemCount or 0
      ))
    end
  end)

  local outputEditHeight = C.EXPORT_EDIT_HEIGHT

  local closeBtn = CreateFrame("Button", nil, exp, "UIPanelButtonTemplate")
  closeBtn:SetSize(90, 22)
  closeBtn:SetPoint("BOTTOMLEFT", exp, "BOTTOMLEFT", 20, 18)
  closeBtn:SetText("Close")
  closeBtn:SetScript("OnClick", function()
    hideExportFrameShowMain()
  end)

  local editBg = CreateFrame("Frame", nil, exp)
  editBg:SetPoint("BOTTOMLEFT", closeBtn, "TOPLEFT", 0, 10)
  editBg:SetPoint("RIGHT", exp, "RIGHT", -32, 0)
  editBg:SetHeight(outputEditHeight + 8)

  local editScroll = CreateFrame("ScrollFrame", nil, editBg, "UIPanelScrollFrameTemplate")
  editScroll:SetPoint("TOPLEFT", editBg, "TOPLEFT", 4, -4)
  editScroll:SetPoint("BOTTOMRIGHT", editBg, "BOTTOMRIGHT", -4, 4)

  local editChild = CreateFrame("Frame", nil, editScroll)
  editChild:SetWidth(C.EXPORT_EDIT_WIDTH - 16)
  editChild:SetHeight(outputEditHeight)

  local editBoxBg = CreateFrame("Frame", nil, editChild, "BackdropTemplate")
  editBoxBg:SetPoint("TOPLEFT", editChild, "TOPLEFT", 6, -6)
  editBoxBg:SetSize(C.EXPORT_EDIT_WIDTH - 32, outputEditHeight - 8)
  editBoxBg:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  editBoxBg:SetBackdropColor(0, 0, 0, 0.9)
  editBoxBg:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

  local editBox = CreateFrame("EditBox", nil, editChild)
  editBox:SetMultiLine(true)
  editBox:SetAutoFocus(false)
  editBox:SetFontObject(ChatFontSmall)
  editBox:SetWidth(C.EXPORT_EDIT_WIDTH - 32)
  editBox:SetHeight(outputEditHeight - 8)
  editBox:SetPoint("TOPLEFT", editChild, "TOPLEFT", 6, -6)
  editBox:SetScript("OnEscapePressed", function(selfEd)
    selfEd:ClearFocus()
    selfEd:HighlightText(0, 0)
    if UI.exportFrame then
      UI.exportFrame:Hide()
    end
  end)
  editBox:SetTextInsets(4, 4, 4, 4)
  editBox:EnableMouse(true)
  editChild:SetScript("OnMouseDown", function()
    editBox:SetFocus()
    editBox:HighlightText()
  end)
  editScroll:SetScrollChild(editChild)

  editBg:SetScript("OnMouseDown", function()
    editBox:SetFocus()
    editBox:HighlightText()
  end)
  editBox:SetFrameLevel(editBoxBg:GetFrameLevel() + 2)

  UI.exportEditBox = editBox

  local outputLabel = exp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  outputLabel:SetPoint("BOTTOMLEFT", editBg, "TOPLEFT", 0, 6)
  outputLabel:SetText("Copy the string below and paste into Gargul with /gl sr")
  UI.exportOutputLabel = outputLabel

  generateBtn:ClearAllPoints()
  generateBtn:SetPoint("TOPLEFT", raidScroll, "BOTTOMLEFT", 0, -8)

  Util.setCloseButtonPlacement(exp)
  Util.ensureUISpecialFrame("TuskUpLootExportFrame")

  UI.exportFrame = exp
  updateImportStatus()
end
