-- Main window frame creation and toggle.

local UI = TuskUpLoot.UI
local Util = UI.Util
local C = UI.Constants

function UI.ensureFrame()
  if UI.frame then
    return
  end

  local f = CreateFrame("Frame", "TuskUpLootMainFrame", UIParent, "UIPanelDialogTemplate")
  f:SetSize(C.FRAME_WIDTH, C.FRAME_HEIGHT)
  f:SetPoint("CENTER")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)

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

  f:SetScript("OnShow", function()
    UI.setActiveTab(UI.activeTab)
    UI.updateAccumulator = 0
  end)
  f:SetScript("OnHide", function()
    UI.updateAccumulator = 0
  end)
  f:SetScript("OnUpdate", function(_, elapsed)
    UI.updateAccumulator = (UI.updateAccumulator or 0) + elapsed
    if UI.updateAccumulator >= (UI.updateIntervalSeconds or 0.5) then
      UI.updateAccumulator = 0
      UI.refresh()
    end
  end)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:ClearAllPoints()
  title:SetPoint("TOP", f, "TOP", 0, -8)
  title:SetText("TuskUpLoot — Guild")
  UI.frameTitle = title

  local listBg = CreateFrame("Frame", "TuskUpLootListBg", f)
  listBg:SetPoint("TOPLEFT", f, "TOPLEFT", C.MARGIN_L, -42)
  listBg:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", C.MARGIN_L, C.MARGIN_L)
  listBg:SetWidth(C.RAIL_WIDTH)

  local function createTabButton(parent, label, xOffset, tabKey)
    local btn = CreateFrame("Button", "TuskUpLootTabButton" .. tabKey, parent)
    btn:SetSize(62, C.TAB_HEIGHT)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, 0)
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(label)
    btn.baseLabel = label
    btn:SetScript("OnClick", function()
      if UI.activeTab ~= tabKey then
        UI.setActiveTab(tabKey)
      end
    end)
    return btn
  end

  local tabStrip = CreateFrame("Frame", nil, listBg)
  tabStrip:SetPoint("TOPLEFT", listBg, "TOPLEFT", 0, 0)
  tabStrip:SetPoint("TOPRIGHT", listBg, "TOPRIGHT", 0, 0)
  tabStrip:SetHeight(C.TAB_HEIGHT)
  UI.tabCharactersBtn = createTabButton(tabStrip, "Chars", 0, "characters")
  UI.tabRaidsBtn = createTabButton(tabStrip, "Raids", 64, "raids")
  UI.tabItemsBtn = createTabButton(tabStrip, "Items", 128, "items")

  local listTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  listTitle:SetPoint("TOPLEFT", listBg, "TOPLEFT", 2, -(C.TAB_HEIGHT + 2))
  listTitle:SetText("Characters")
  UI.listTitle = listTitle

  local filterBg = CreateFrame("Frame", "TuskUpLootFilterBg", listBg, "BackdropTemplate")
  filterBg:SetPoint("TOPLEFT", listBg, "TOPLEFT", 0, -(C.TAB_HEIGHT + 26))
  filterBg:SetPoint("TOPRIGHT", listBg, "TOPRIGHT", -28, -(C.TAB_HEIGHT + 26))
  filterBg:SetHeight(24)
  filterBg:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  filterBg:SetBackdropColor(0, 0, 0, 0.9)
  filterBg:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
  filterBg:Hide()
  UI.filterBg = filterBg

  local filterEdit = CreateFrame("EditBox", "TuskUpLootFilterEdit", listBg)
  filterEdit:SetFontObject(ChatFontSmall)
  filterEdit:SetHeight(20)
  filterEdit:SetAutoFocus(false)
  filterEdit:SetAllPoints(filterBg)
  filterEdit:SetTextInsets(6, 6, 3, 3)
  filterEdit:SetFrameLevel(filterBg:GetFrameLevel() + 2)
  filterEdit:Hide()
  filterEdit:SetScript("OnEscapePressed", function(selfEdit)
    selfEdit:ClearFocus()
  end)
  filterEdit:SetScript("OnTextChanged", function()
    UI.rebuildFilteredList()
  end)
  UI.filterEdit = filterEdit

  local scrollTop = -(C.TAB_HEIGHT + 50)

  local charListScroll = CreateFrame("ScrollFrame", nil, listBg, "UIPanelScrollFrameTemplate")
  charListScroll:SetPoint("TOPLEFT", listBg, "TOPLEFT", 0, scrollTop)
  charListScroll:SetPoint("BOTTOMRIGHT", listBg, "BOTTOMRIGHT", -26, 0)
  local charListContainer = CreateFrame("Frame", nil, charListScroll)
  charListContainer:SetWidth(C.RAIL_WIDTH - 8)
  charListContainer:SetHeight(1)
  charListScroll:SetScrollChild(charListContainer)
  UI.charListContainer = charListContainer
  UI.charListScroll = charListScroll

  local raidListScroll = CreateFrame("ScrollFrame", nil, listBg, "UIPanelScrollFrameTemplate")
  raidListScroll:SetPoint("TOPLEFT", listBg, "TOPLEFT", 0, -(C.TAB_HEIGHT + 26))
  raidListScroll:SetPoint("BOTTOMRIGHT", listBg, "BOTTOMRIGHT", -26, 0)
  local raidListContainer = CreateFrame("Frame", nil, raidListScroll)
  raidListContainer:SetWidth(C.RAIL_WIDTH - 8)
  raidListContainer:SetHeight(1)
  raidListScroll:SetScrollChild(raidListContainer)
  raidListScroll:Hide()
  UI.raidListContainer = raidListContainer
  UI.raidListScroll = raidListScroll

  local listScroll = CreateFrame("ScrollFrame", nil, listBg, "UIPanelScrollFrameTemplate")
  listScroll:SetPoint("TOPLEFT", listBg, "TOPLEFT", 0, scrollTop)
  listScroll:SetPoint("BOTTOMRIGHT", listBg, "BOTTOMRIGHT", -26, 0)
  listScroll:Hide()

  local listContainer = CreateFrame("Frame", nil, listScroll)
  listContainer:SetWidth(C.RAIL_WIDTH - 8)
  listContainer:SetHeight(1)
  listScroll:SetScrollChild(listContainer)

  UI.itemListContainer = listContainer
  UI.itemListScroll = listScroll

  local detailSectionLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  detailSectionLabel:SetPoint("TOPLEFT", f, "TOPLEFT", C.CONTENT_X, -44)
  detailSectionLabel:SetText("Gear sets")
  UI.detailSectionLabel = detailSectionLabel

  local detailHeader = CreateFrame("Frame", nil, f)
  detailHeader:SetHeight(36)
  detailHeader:SetPoint("TOPLEFT", f, "TOPLEFT", C.CONTENT_X, -64)
  detailHeader:SetPoint("TOPRIGHT", f, "TOPRIGHT", -C.MARGIN_R, -64)
  detailHeader:EnableMouse(true)
  UI.detailHeader = detailHeader

  local itemIconBtn = Util.createItemIcon(detailHeader)
  itemIconBtn:SetPoint("LEFT", detailHeader, "LEFT", 0, 0)
  itemIconBtn:Hide()
  UI.itemIconBtn = itemIconBtn

  local detailLinkFS = detailHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  detailLinkFS:SetPoint("LEFT", itemIconBtn, "RIGHT", 10, 0)
  detailLinkFS:SetPoint("RIGHT", detailHeader, "RIGHT", -4, 0)
  detailLinkFS:SetJustifyH("LEFT")
  detailLinkFS:SetJustifyV("MIDDLE")
  detailLinkFS:SetWordWrap(true)
  UI.detailLinkFS = detailLinkFS

  local detailScroll = CreateFrame("ScrollFrame", "ItemDetailScroll", f, "ScrollFrameTemplate")
  detailScroll:SetPoint("TOPLEFT", detailHeader, "BOTTOMLEFT", 0, -8)
  local scrollBarWidth = 0
  if detailScroll.ScrollBar then
    scrollBarWidth = detailScroll.ScrollBar:GetWidth()
    detailScroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(C.MARGIN_R + scrollBarWidth), C.DETAIL_BOTTOM_CLOSED)
    detailScroll.ScrollBar:SetPoint("TOPLEFT", detailScroll, "TOPRIGHT", -2, 0)
  else
    detailScroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -C.MARGIN_R, C.DETAIL_BOTTOM_CLOSED)
  end
  UI.detailScroll = detailScroll

  local detailScrollChild = CreateFrame("Frame", "ScrollChild", detailScroll)
  detailScrollChild:SetWidth(math.max(1, detailScroll:GetWidth() - scrollBarWidth))
  detailScrollChild:SetHeight(1)
  detailScroll:SetScrollChild(detailScrollChild)
  UI.detailScrollChild = detailScrollChild

  local needsTitle = detailScrollChild:CreateFontString("NeedsTitleString", "OVERLAY", "GameFontHighlightLarge")
  needsTitle:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 4, 0)
  needsTitle:SetJustifyH("LEFT")
  needsTitle:SetJustifyV("TOP")
  needsTitle:SetWidth(280 - 4 - C.TEXT_INSET)
  UI.needsTitle = needsTitle

  local needsListContainer = CreateFrame("Frame", "NeedsListFrame", detailScrollChild)
  needsListContainer:SetPoint("TOPLEFT", needsTitle, "BOTTOMLEFT", C.TEXT_INSET, -4)
  needsListContainer:SetWidth(detailScrollChild:GetWidth())
  needsListContainer:SetHeight(1)
  needsListContainer:Hide()
  UI.needsListContainer = needsListContainer

  local hasTitle = detailScrollChild:CreateFontString("HasTitleString", "OVERLAY", "GameFontHighlightLarge")
  hasTitle:SetPoint("TOPLEFT", needsListContainer, "BOTTOMLEFT", -C.TEXT_INSET, -8)
  hasTitle:SetJustifyH("LEFT")
  hasTitle:SetJustifyV("TOP")
  hasTitle:SetWidth(280 - 4 - C.TEXT_INSET)
  UI.hasTitle = hasTitle

  local hasText = detailScrollChild:CreateFontString("HasTitleString", "OVERLAY", "GameFontHighlight")
  hasText:SetPoint("TOPLEFT", hasTitle, "BOTTOMLEFT", C.TEXT_INSET, -4)
  hasText:SetJustifyH("LEFT")
  hasText:SetJustifyV("TOP")
  hasText:SetWidth(280 - 4 - C.TEXT_INSET)
  hasText:SetWordWrap(true)
  UI.hasText = hasText

  local charDetailFS = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  charDetailFS:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 4, 0)
  charDetailFS:SetWidth(detailScrollChild:GetWidth() - 8)
  charDetailFS:SetJustifyH("LEFT")
  charDetailFS:SetJustifyV("TOP")
  charDetailFS:SetWordWrap(true)
  charDetailFS:Hide()
  UI.charDetailFS = charDetailFS

  local toggleImportBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  toggleImportBtn:SetSize(140, 22)
  toggleImportBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", C.CONTENT_X, C.MARGIN_L)
  toggleImportBtn:SetText("Import JSON")
  toggleImportBtn:SetScript("OnClick", function()
    UI.ensureImportFrame()
    if UI.importFrame then
      UI.frame:Hide()
      UI.importFrame:Show()
      if UI.importEditBox then
        UI.importEditBox:SetText("")
        UI.importEditBox:SetFocus()
      end
    end
  end)
  UI.toggleImportBtn = toggleImportBtn

  local legacyText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  legacyText:SetText("")
  legacyText:Hide()
  UI.text = legacyText

  local close = _G["TuskUpLootMainFrameCloseButton"] or _G["TuskUpLootMainFrameClose"]
  if close then
    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 1)
  end

  UI.frame = f
  TuskUpLoot.frame = f

  local state = Util.getRaidState()
  if state.InstanceId then
    UI.focusInstanceId = state.InstanceId
    UI.expandedInstances[state.InstanceId] = true
    UI.activeTab = "raids"
  else
    UI.activeTab = "characters"
  end

  UI.setActiveTab(UI.activeTab)
  f:Hide()
end

function UI.toggle()
  if not Util.isInRequiredGuild() then
    Util.safeChatPrint(string.format("Disabled: only available to members of guild '%s'.",
      TuskUpLoot.requiredGuildName or "Tusk Up"))
    return
  end

  UI.ensureFrame()
  if UI.frame:IsShown() then
    UI.frame:Hide()
  else
    UI.frame:Show()
  end
end
