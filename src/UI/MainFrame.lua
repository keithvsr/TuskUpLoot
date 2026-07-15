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
  f:SetFrameStrata("HIGH")

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
  title:SetText("TuskUpLoot")
  UI.frameTitle = title

  local listBg = CreateFrame("Frame", "TuskUpLootListBg", f)
  listBg:SetPoint("TOPLEFT", f, "TOPLEFT", C.MARGIN_L, -42)
  listBg:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", C.MARGIN_L, C.MARGIN_L)
  listBg:SetWidth(C.RAIL_WIDTH)

  local function createTabButton(parent, label, xOffset, tabKey)
    local btn = CreateFrame("Button", "TuskUpLootTabButton" .. tabKey, parent)
    btn:SetSize(48, C.TAB_HEIGHT)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, 0)

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetColorTexture(0.15, 0.15, 0.15, 0.6)
    btn.bg:Hide()

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
  UI.tabRaidsBtn = createTabButton(tabStrip, "Raids", 50, "raids")
  UI.tabItemsBtn = createTabButton(tabStrip, "Items", 100, "items")
  UI.tabOptionsBtn = createTabButton(tabStrip, "Opts", 150, "options")

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

  local charSortBar = CreateFrame("Frame", nil, listBg)
  charSortBar:SetPoint("TOPLEFT", listBg, "TOPLEFT", 0, -(C.TAB_HEIGHT + 52))
  charSortBar:SetPoint("TOPRIGHT", listBg, "TOPRIGHT", 0, -(C.TAB_HEIGHT + 52))
  charSortBar:SetHeight(20)
  charSortBar:Hide()
  UI.charSortBar = charSortBar

  local function createCharSortButton(parent, label, sortKey, xOffset)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(52, 18)
    btn:SetPoint("LEFT", parent, "LEFT", xOffset, 0)
    btn.sortKey = sortKey
    btn.baseLabel = label

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetColorTexture(0.15, 0.15, 0.15, 0.6)
    btn.bg:Hide()

    btn.descIndicator = btn:CreateTexture(nil, "OVERLAY")
    btn.descIndicator:SetColorTexture(1, 0.53, 0, 1)
    btn.descIndicator:SetHeight(2)
    btn.descIndicator:SetPoint("TOPLEFT", btn, "TOPLEFT", 6, -2)
    btn.descIndicator:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -6, -2)
    btn.descIndicator:Hide()

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(label)

    btn:SetScript("OnClick", function()
      UI.setCharListSortBy(sortKey)
    end)
    btn:SetScript("OnEnter", function()
      if (UI.charListSortBy or "name") ~= sortKey then
        btn.text:SetText("|cffbbbbbb" .. label .. "|r")
      end
    end)
    btn:SetScript("OnLeave", function()
      UI.updateCharSortButtonStyles()
    end)
    return btn
  end

  UI.charSortNameBtn = createCharSortButton(charSortBar, "Name", "name", 0)
  UI.charSortClassBtn = createCharSortButton(charSortBar, "Class", "class", 54)
  UI.charSortManualBtn = createCharSortButton(charSortBar, "Manual", "manual", 108)

  local scrollTop = -(C.TAB_HEIGHT + 72)

  local pushDataBtn = CreateFrame("Button", nil, listBg, "UIPanelButtonTemplate")
  pushDataBtn:SetSize(C.RAIL_WIDTH - 8, 22)
  pushDataBtn:SetPoint("BOTTOMLEFT", listBg, "BOTTOMLEFT", 0, 4)
  pushDataBtn:SetText("Push data")
  pushDataBtn:Hide() -- sync disabled
  -- pushDataBtn:SetScript("OnClick", function()
  --   if TuskUpLoot.Sync and TuskUpLoot.Sync.openPushFullPicker then
  --     TuskUpLoot.Sync.openPushFullPicker()
  --   end
  -- end)
  UI.pushDataBtn = pushDataBtn

  local charManualResetBtn = CreateFrame("Button", nil, listBg, "UIPanelButtonTemplate")
  charManualResetBtn:SetSize(C.RAIL_WIDTH - 8, 22)
  charManualResetBtn:SetPoint("BOTTOMLEFT", listBg, "BOTTOMLEFT", 0, 4)
  charManualResetBtn:SetText("Reset order")
  charManualResetBtn:Hide()
  charManualResetBtn:SetScript("OnClick", function()
    if UI.resetManualCharacterOrder then
      UI.resetManualCharacterOrder()
    end
  end)
  UI.charManualResetBtn = charManualResetBtn

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

  local charInfoHeader = CreateFrame("Frame", nil, f)
  charInfoHeader:SetHeight(20)
  charInfoHeader:SetPoint("TOPLEFT", f, "TOPLEFT", C.CONTENT_X, -58)
  charInfoHeader:SetPoint("TOPRIGHT", f, "TOPRIGHT", -C.MARGIN_R, -58)
  charInfoHeader:Hide()
  UI.charInfoHeader = charInfoHeader

  local charSummaryFS = charInfoHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  charSummaryFS:SetPoint("LEFT", charInfoHeader, "LEFT", 0, 0)
  charSummaryFS:SetPoint("RIGHT", charInfoHeader, "RIGHT", 0, 0)
  charSummaryFS:SetJustifyH("LEFT")
  charSummaryFS:SetJustifyV("MIDDLE")
  charSummaryFS:SetWordWrap(false)
  UI.charSummaryFS = charSummaryFS
  UI.charDetailFS = charSummaryFS

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
  detailLinkFS:SetPoint("RIGHT", detailHeader, "RIGHT", -170, 0)
  detailLinkFS:SetJustifyH("LEFT")
  detailLinkFS:SetJustifyV("MIDDLE")
  detailLinkFS:SetWordWrap(true)
  UI.detailLinkFS = detailLinkFS

  local encounterLootToggleBtn = CreateFrame("Button", nil, detailHeader, "UIPanelButtonTemplate")
  encounterLootToggleBtn:SetSize(108, 22)
  encounterLootToggleBtn:SetPoint("TOPRIGHT", detailHeader, "TOPRIGHT", -56, 0)
  encounterLootToggleBtn:SetText("Full loot table")
  encounterLootToggleBtn:Hide()
  encounterLootToggleBtn:SetScript("OnClick", function()
    if UI.encounterLootView == "actual" then
      UI.encounterLootView = "full"
    else
      UI.encounterLootView = "actual"
    end
    if UI.renderEncounterLootPanel then
      UI.renderEncounterLootPanel()
    end
  end)
  UI.encounterLootToggleBtn = encounterLootToggleBtn

  local detailLinkHitBtn = CreateFrame("Button", nil, detailHeader)
  detailLinkHitBtn:SetPoint("TOPLEFT", detailLinkFS, "TOPLEFT", 0, 0)
  detailLinkHitBtn:SetPoint("BOTTOMRIGHT", detailLinkFS, "BOTTOMRIGHT", 0, 0)
  detailLinkHitBtn:SetFrameLevel(detailHeader:GetFrameLevel() + 2)
  detailLinkHitBtn:Hide()
  UI.detailLinkHitBtn = detailLinkHitBtn

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

  Util.setCloseButtonPlacement(f)
  -- local close = _G["TuskUpLootMainFrameCloseButton"] or _G["TuskUpLootMainFrameClose"]
  -- if close then
  --   close:ClearAllPoints()
  --   close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 1)
  -- end

  ---@diagnostic disable-next-line: undefined-global
  table.insert(UISpecialFrames, "TuskUpLootMainFrame")

  local encounterLootContainer = CreateFrame("Frame", nil, detailScrollChild)
  encounterLootContainer:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 0, 0)
  encounterLootContainer:SetWidth(detailScrollChild:GetWidth())
  encounterLootContainer:SetHeight(1)
  encounterLootContainer:Hide()
  UI.encounterLootContainer = encounterLootContainer

  local charGearContainer = CreateFrame("Frame", nil, detailScrollChild)
  charGearContainer:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 0, 0)
  charGearContainer:SetWidth(detailScrollChild:GetWidth())
  charGearContainer:SetHeight(1)
  charGearContainer:Hide()
  UI.charGearContainer = charGearContainer

  local optionsContainer = CreateFrame("Frame", "TuskUpLootOptionsContainer", f)
  optionsContainer:SetPoint("TOPLEFT", f, "TOPLEFT", C.CONTENT_X, -64)
  optionsContainer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -C.MARGIN_R, C.DETAIL_BOTTOM_CLOSED)
  optionsContainer:Hide()
  UI.optionsContainer = optionsContainer

  local backBtn = CreateFrame("Button", nil, detailHeader, "UIPanelButtonTemplate")
  backBtn:SetSize(52, 22)
  backBtn:SetPoint("TOPRIGHT", detailHeader, "TOPRIGHT", 0, 0)
  backBtn:SetText("Back")
  backBtn:Hide()
  backBtn:SetScript("OnClick", function()
    local ctx = UI.returnContext
    if not ctx then
      return
    end
    UI.returnContext = nil
    if ctx.focusEncounterId then
      UI.focusEncounterId = ctx.focusEncounterId
    end
    UI.setActiveTab("raids")
    if UI.renderEncounterLootPanel then
      UI.renderEncounterLootPanel()
    end
  end)
  UI.detailBackBtn = backBtn

  f:SetScript("OnHide", function()
    -- sync disabled
    -- if UI.syncPickerFrame then
    --   UI.syncPickerFrame:Hide()
    -- end
    if UI.importFrame then
      UI.importFrame:Hide()
    end
    -- if StaticPopup_Hide then
    --   StaticPopup_Hide("TUSKUPLOOT_SYNC_OFFER")
    -- end
  end)

  UI.frame = f
  TuskUpLoot.frame = f

  local state = Util.getRaidState()
  if state.InstanceId then
    if UI.expandOnlyInstance then
      UI.expandOnlyInstance(state.InstanceId)
    else
      UI.focusInstanceId = state.InstanceId
      UI.expandedInstances[state.InstanceId] = true
    end
    UI.activeTab = "raids"
  else
    UI.activeTab = "characters"
  end

  UI.setActiveTab(UI.activeTab)
  f:Hide()
end

function UI.toggle()
  UI.ensureFrame()
  if UI.frame:IsShown() then
    UI.dismissAllFrames()
  else
    UI.frame:Show()
  end
end
