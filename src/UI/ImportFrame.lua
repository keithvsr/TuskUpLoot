-- Import JSON dialog (sixtyupgrades export).

local UI = TuskUpLoot.UI
local Util = UI.Util
local C = UI.Constants

local function hideImportFrameShowMain()
  if UI.importFrame then
    UI.importFrame:Hide()
  end
  if UI.frame then
    UI.frame:Show()
  end
end

function UI.ensureImportFrame()
  if UI.importFrame then
    return
  end

  local imp = CreateFrame("Frame", "TuskUpLootImportFrame", UIParent, "UIPanelDialogTemplate")
  imp:SetSize(C.IMPORT_FRAME_WIDTH, C.IMPORT_FRAME_HEIGHT)
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

  imp:SetScript("OnHide", function()
    if UI.frame and not UI.frame:IsShown() then
      UI.frame:Show()
    end
  end)

  local title = imp:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", imp, "TOP", 0, -8)
  title:SetText("Import sixtyupgrades JSON")

  local label = imp:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("TOPLEFT", imp, "TOPLEFT", 20, -44)
  label:SetText("Paste sixtyupgrades export (one gear set). Click anywhere in the box to paste.")

  local editBg = CreateFrame("Frame", nil, imp)
  editBg:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
  editBg:SetPoint("BOTTOMRIGHT", imp, "BOTTOMRIGHT", -32, 70)
  editBg:SetWidth(C.IMPORT_EDIT_WIDTH)

  local editScroll = CreateFrame("ScrollFrame", nil, editBg, "UIPanelScrollFrameTemplate")
  editScroll:SetPoint("TOPLEFT", editBg, "TOPLEFT", 4, -4)
  editScroll:SetPoint("BOTTOMRIGHT", editBg, "BOTTOMRIGHT", -4, 4)

  local editChild = CreateFrame("Frame", nil, editScroll)
  editChild:SetWidth(C.IMPORT_EDIT_WIDTH - 16)
  editChild:SetHeight(math.max(C.IMPORT_EDIT_HEIGHT, 200))

  local editBoxBg = CreateFrame("Frame", nil, editChild, "BackdropTemplate")
  editBoxBg:SetPoint("TOPLEFT", editChild, "TOPLEFT", 6, -6)
  editBoxBg:SetSize(C.IMPORT_EDIT_WIDTH - 32, math.max(C.IMPORT_EDIT_HEIGHT - 8, 192))
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
  editBox:SetWidth(C.IMPORT_EDIT_WIDTH - 32)
  editBox:SetHeight(math.max(C.IMPORT_EDIT_HEIGHT - 8, 192))
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

  UI.importEditBox = editBox

  local clearBtn = CreateFrame("Button", nil, imp, "UIPanelButtonTemplate")
  clearBtn:SetSize(90, 22)
  clearBtn:SetPoint("BOTTOMLEFT", imp, "BOTTOMLEFT", 20, 18)
  clearBtn:SetText("Clear")
  clearBtn:SetScript("OnClick", function()
    if editBox then
      editBox:SetText("")
      editBox:ClearFocus()
    end
  end)

  local importBtn = CreateFrame("Button", nil, imp, "UIPanelButtonTemplate")
  importBtn:SetSize(90, 22)
  importBtn:SetPoint("BOTTOMLEFT", imp, "BOTTOMLEFT", 120, 18)
  importBtn:SetText("Import")
  importBtn:SetScript("OnClick", function()
    local txt = (editBox and editBox:GetText()) or ""
    txt = txt:gsub("^%s+", ""):gsub("%s+$", "")
    if txt == "" then
      Util.safeChatPrint("Paste a JSON export first.")
      return
    end

    local payload, err
    if TuskUpLoot.Importer then
      payload, err = TuskUpLoot.Importer.import(txt)
    end
    if not payload then
      Util.safeChatPrint("Import failed: " .. tostring(err or "unknown"))
      return
    end

    local name = payload.character and payload.character.name
    local gearSetName = payload.name or ""
    Util.safeChatPrint(string.format("Imported %s gear set %s", tostring(name or "character"), tostring(gearSetName)))
    if editBox then
      editBox:SetText("")
    end
    hideImportFrameShowMain()
    UI.refreshAfterImport()
  end)

  local cancelBtn = CreateFrame("Button", nil, imp, "UIPanelButtonTemplate")
  cancelBtn:SetSize(90, 22)
  cancelBtn:SetPoint("BOTTOMLEFT", imp, "BOTTOMLEFT", 220, 18)
  cancelBtn:SetText("Cancel")
  cancelBtn:SetScript("OnClick", function()
    hideImportFrameShowMain()
  end)

  local closeBtn = _G["TuskUpLootImportFrameCloseButton"] or _G["TuskUpLootImportFrameClose"]
  if closeBtn then
    closeBtn:ClearAllPoints()
    closeBtn:SetPoint("TOPRIGHT", imp, "TOPRIGHT", 2, 1)
  end

  UI.importFrame = imp
end
