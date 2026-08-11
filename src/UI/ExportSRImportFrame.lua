-- Import softres.it export string for Gargul export merge.

local UI = TuskUpLoot.UI
local Util = UI.Util
local C = UI.Constants

local function hideSRImportShowExport()
  if UI.exportSRImportFrame then
    UI.exportSRImportFrame:Hide()
  end
  if UI.exportFrame then
    UI.exportFrame:Show()
  end
end

local function applyImportedSR(text)
  local SR = TuskUpLoot.SR
  if not SR or not SR.import then
    Util.safeChatPrint("SR import module unavailable.")
    return false
  end

  local data, err = SR.import(text)
  if not data then
    Util.safeChatPrint("SR import failed: " .. tostring(err or "unknown"))
    return false
  end

  UI.exportImportedSR = data

  if UI.applyExportInstanceSelection then
    local instanceIds = SR.instanceIdsFromMetadata and SR.instanceIdsFromMetadata(data) or {}
    if #instanceIds > 0 then
      UI.applyExportInstanceSelection(instanceIds)
    end
  end

  if UI.updateExportImportStatus then
    UI.updateExportImportStatus()
  end

  local summary = SR.summarize and SR.summarize(data) or {}
  Util.safeChatPrint(string.format(
    "Imported SR: %d players, %d items across %d raids.",
    summary.playerCount or 0,
    summary.itemCount or 0,
    summary.instanceCount or 0
  ))

  return true
end

function UI.ensureExportSRImportFrame()
  if UI.exportSRImportFrame then
    return
  end

  local imp = CreateFrame("Frame", "TuskUpLootExportSRImportFrame", UIParent, "UIPanelDialogTemplate")
  imp:SetSize(C.EXPORT_SR_IMPORT_FRAME_WIDTH, C.EXPORT_SR_IMPORT_FRAME_HEIGHT)
  imp:SetFrameStrata("FULLSCREEN_DIALOG")
  imp:SetFrameLevel(200)
  imp:SetPoint("CENTER")
  imp:SetMovable(true)
  imp:EnableMouse(true)
  imp:SetClampedToScreen(true)
  imp:Hide()

  local dragRegion = CreateFrame("Frame", nil, imp)
  dragRegion:SetPoint("TOPLEFT", imp, "TOPLEFT", 10, -10)
  dragRegion:SetPoint("TOPRIGHT", imp, "TOPRIGHT", -44, -10)
  dragRegion:SetHeight(26)
  dragRegion:EnableMouse(true)
  dragRegion:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" then
      imp:StartMoving()
    end
  end)
  dragRegion:SetScript("OnMouseUp", function()
    imp:StopMovingOrSizing()
  end)

  imp:SetScript("OnShow", function()
    Util.bringUISpecialFrameToFront("TuskUpLootExportSRImportFrame")
    if UI.exportFrame then
      imp:SetFrameLevel(UI.exportFrame:GetFrameLevel() + 50)
    end
    if UI.frame then
      UI.frame:Hide()
    end
  end)

  imp:SetScript("OnHide", function()
    if UI.exportSRImportEditBox then
      UI.exportSRImportEditBox:ClearFocus()
    end
    if UI.exportTransitionToSRImport then
      return
    end
    if UI.exportFrame and not UI.exportFrame:IsShown() then
      UI.exportFrame:Show()
    end
  end)

  Util.bindFrameEscapeDismiss(imp, function(frame)
    if UI.exportSRImportEditBox then
      UI.exportSRImportEditBox:ClearFocus()
    end
    frame:Hide()
  end)

  local title = imp:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", imp, "TOP", 0, -8)
  title:SetText("Import softres.it SR")

  local label = imp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("TOPLEFT", imp, "TOPLEFT", 20, -44)
  label:SetText("Paste a softres.it export string. Click anywhere in the box to paste.")

  local editBg = CreateFrame("Frame", nil, imp)
  editBg:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
  editBg:SetPoint("BOTTOMRIGHT", imp, "BOTTOMRIGHT", -32, 70)
  editBg:SetWidth(C.EXPORT_SR_IMPORT_EDIT_WIDTH)

  local editScroll = CreateFrame("ScrollFrame", nil, editBg, "UIPanelScrollFrameTemplate")
  editScroll:SetPoint("TOPLEFT", editBg, "TOPLEFT", 4, -4)
  editScroll:SetPoint("BOTTOMRIGHT", editBg, "BOTTOMRIGHT", -4, 4)

  local editInnerHeight = C.EXPORT_SR_IMPORT_EDIT_HEIGHT

  local editChild = CreateFrame("Frame", nil, editScroll)
  editChild:SetWidth(C.EXPORT_SR_IMPORT_EDIT_WIDTH - 16)
  editChild:SetHeight(editInnerHeight)

  local editBoxBg = CreateFrame("Frame", nil, editChild, "BackdropTemplate")
  editBoxBg:SetPoint("TOPLEFT", editChild, "TOPLEFT", 6, -6)
  editBoxBg:SetSize(C.EXPORT_SR_IMPORT_EDIT_WIDTH - 32, editInnerHeight - 8)
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
  editBox:SetWidth(C.EXPORT_SR_IMPORT_EDIT_WIDTH - 32)
  editBox:SetHeight(editInnerHeight - 8)
  editBox:SetPoint("TOPLEFT", editChild, "TOPLEFT", 6, -6)
  editBox:SetScript("OnEscapePressed", function(selfEd)
    selfEd:ClearFocus()
  end)
  editBox:SetTextInsets(4, 4, 4, 4)
  editBox:EnableMouse(true)
  editChild:SetScript("OnMouseDown", function()
    editBox:SetFocus()
  end)
  editScroll:SetScrollChild(editChild)

  editBg:SetScript("OnMouseDown", function()
    editBox:SetFocus()
  end)
  editBox:SetFrameLevel(editBoxBg:GetFrameLevel() + 2)

  UI.exportSRImportEditBox = editBox

  local clearBtn = CreateFrame("Button", nil, imp, "UIPanelButtonTemplate")
  clearBtn:SetSize(90, 22)
  clearBtn:SetPoint("BOTTOMLEFT", imp, "BOTTOMLEFT", 20, 18)
  clearBtn:SetText("Clear")
  clearBtn:SetScript("OnClick", function()
    if UI.exportSRImportEditBox then
      UI.exportSRImportEditBox:SetText("")
      UI.exportSRImportEditBox:ClearFocus()
    end
  end)

  local loadBtn = CreateFrame("Button", nil, imp, "UIPanelButtonTemplate")
  loadBtn:SetSize(90, 22)
  loadBtn:SetPoint("BOTTOMLEFT", imp, "BOTTOMLEFT", 120, 18)
  loadBtn:SetText("Load")
  loadBtn:SetScript("OnClick", function()
    local txt = (UI.exportSRImportEditBox and UI.exportSRImportEditBox:GetText()) or ""
    if applyImportedSR(txt) then
      if UI.exportSRImportEditBox then
        UI.exportSRImportEditBox:SetText("")
      end
      hideSRImportShowExport()
    end
  end)

  local cancelBtn = CreateFrame("Button", nil, imp, "UIPanelButtonTemplate")
  cancelBtn:SetSize(90, 22)
  cancelBtn:SetPoint("BOTTOMLEFT", imp, "BOTTOMLEFT", 220, 18)
  cancelBtn:SetText("Cancel")
  cancelBtn:SetScript("OnClick", function()
    hideSRImportShowExport()
  end)

  Util.setCloseButtonPlacement(imp)
  Util.ensureUISpecialFrame("TuskUpLootExportSRImportFrame")

  UI.exportSRImportFrame = imp
end

function UI.openExportSRImportFrame()
  UI.ensureExportFrame()
  UI.ensureExportSRImportFrame()
  if UI.frame then
    UI.frame:Hide()
  end
  UI.exportTransitionToSRImport = true
  if UI.exportFrame then
    UI.exportFrame:Hide()
  end
  UI.exportTransitionToSRImport = nil
  if UI.exportSRImportFrame then
    if UI.exportSRImportEditBox then
      UI.exportSRImportEditBox:SetText("")
    end
    UI.exportSRImportFrame:Show()
    if UI.exportSRImportEditBox then
      UI.exportSRImportEditBox:SetFocus()
    end
  end
end
