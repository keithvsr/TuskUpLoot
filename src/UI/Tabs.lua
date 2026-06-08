-- Tab strip orchestration: visibility, switching, refresh, selection.

local UI = TuskUpLoot.UI
local Util = UI.Util

function UI.getCharListSortDescending()
  if (UI.charListSortBy or "name") == "manual" then
    return false
  end
  if (UI.charListSortBy or "name") == "class" then
    return UI.charListSortClassDescending or false
  end
  return UI.charListSortNameDescending or false
end

local function styleCharSortButton(btn, sortKey, label)
  if not btn or not btn.text then
    return
  end
  local sortBy = UI.charListSortBy or "name"
  local active = (sortBy == sortKey)
  local descending = false
  if sortKey ~= "manual" then
    descending = (sortKey == "class")
      and (UI.charListSortClassDescending or false)
      or (UI.charListSortNameDescending or false)
  end

  if btn.bg then
    btn.bg:SetShown(active)
  end
  if btn.descIndicator then
    btn.descIndicator:SetShown(active and descending and sortKey ~= "manual")
  end
  if active then
    btn.text:SetText("|cffffff00" .. label .. "|r")
  else
    btn.text:SetText("|cff888888" .. label .. "|r")
  end
end

function UI.updateCharSortButtonStyles()
  styleCharSortButton(UI.charSortNameBtn, "name", "Name")
  styleCharSortButton(UI.charSortClassBtn, "class", "Class")
  styleCharSortButton(UI.charSortManualBtn, "manual", "Manual")
end

local function updateTabButtonStyles()
  local active = UI.activeTab
  local tabs = {
    { key = "characters", btn = UI.tabCharactersBtn },
    { key = "raids",      btn = UI.tabRaidsBtn },
    { key = "items",      btn = UI.tabItemsBtn },
  }
  for _, tab in ipairs(tabs) do
    if tab.btn and tab.btn.text then
      local label = tab.btn.baseLabel or tab.btn.text:GetText() or ""
      tab.btn.baseLabel = label:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
      if tab.btn.bg then
        tab.btn.bg:SetShown(tab.key == active)
      end
      if tab.key == active then
        tab.btn.text:SetText("|cffffff00" .. tab.btn.baseLabel .. "|r")
      else
        tab.btn.text:SetText(tab.btn.baseLabel)
      end
    end
  end
end

local function updateTabVisibility()
  local tab = UI.activeTab

  if UI.charListScroll then
    UI.charListScroll:SetShown(tab == "characters")
  end
  if UI.raidListScroll then
    UI.raidListScroll:SetShown(tab == "raids")
  end
  if UI.itemListScroll then
    UI.itemListScroll:SetShown(tab == "items")
  end
  -- sync disabled
  -- if UI.pushDataBtn then
  --   UI.pushDataBtn:SetShown(tab == "characters")
  -- end

  local showFilter = (tab == "characters" or tab == "items")
  if UI.filterBg then
    UI.filterBg:SetShown(showFilter)
  end
  if UI.filterEdit then
    UI.filterEdit:SetShown(showFilter)
  end
  if UI.charSortBar then
    UI.charSortBar:SetShown(tab == "characters")
  end

  local titles = {
    characters = "Characters",
    raids = "Raids",
    items = "Imported Items",
  }
  if UI.listTitle then
    UI.listTitle:SetText(titles[tab] or "")
  end

  local detailLabels = {
    characters = "Gear sets",
    raids = "Loot",
    items = "Who needs it",
  }
  if UI.detailSectionLabel then
    UI.detailSectionLabel:SetText(detailLabels[tab] or "")
  end

  local showItemDetailHeader = (tab == "items")
  local showRaidHeader = (tab == "raids")

  if UI.detailHeader then
    UI.detailHeader:SetShown(showItemDetailHeader or showRaidHeader)
  end
  if UI.itemIconBtn then
    UI.itemIconBtn:SetShown(tab == "items" and UI.selectedItemId ~= nil)
  end

  if UI.charInfoHeader then
    UI.charInfoHeader:SetShown(tab == "characters")
  end
  if UI.charSummaryFS then
    UI.charSummaryFS:SetShown(tab == "characters")
  end
  if UI.charGearContainer then
    UI.charGearContainer:SetShown(tab == "characters")
  end
  if UI.encounterLootContainer then
    UI.encounterLootContainer:SetShown(tab == "raids")
  end

  if tab == "characters" or tab == "raids" then
    if UI.needsTitle then UI.needsTitle:Hide() end
    if UI.needsListContainer then UI.needsListContainer:Hide() end
    if UI.hasTitle then UI.hasTitle:Hide() end
    if UI.hasText then UI.hasText:Hide() end
    if tab == "characters" and UI.detailBackBtn then
      UI.detailBackBtn:Hide()
    end
  end

  if tab ~= "items" and UI.detailBackBtn then
    UI.detailBackBtn:Hide()
  end

  Util.layoutDetailScrollForTab(tab)

  updateTabButtonStyles()
  UI.updateCharSortButtonStyles()
  Util.updateFrameTitle()
end

function UI.rebuildFilteredList()
  local tab = UI.activeTab
  if tab == "characters" then
    UI.rebuildCharacterList()
  elseif tab == "items" then
    UI.rebuildItemList()
  end
end

function UI.setActiveTab(tab)
  UI.activeTab = tab
  updateTabVisibility()
  Util.clearFilter()

  if tab == "characters" then
    UI.rebuildCharacterList()
    UI.renderCharacterPanel()
  elseif tab == "items" then
    UI.rebuildItemList()
    UI.renderSelectedItem()
  elseif tab == "raids" then
    UI.rebuildRaidList()
    UI.renderEncounterLootPanel()
  end
end

function UI.openItemDetail(itemId, returnContext)
  UI.selectedItemId = itemId
  UI.returnContext = returnContext
  UI.setActiveTab("items")
end

function UI.setSelectedItemId(itemId)
  UI.openItemDetail(itemId, nil)
end

function UI.refresh()
  local tab = UI.activeTab
  if tab == "characters" then
    UI.renderCharacterPanel()
  elseif tab == "items" then
    UI.renderSelectedItem()
  elseif tab == "raids" then
    UI.renderEncounterLootPanel()
  end
end

function UI.refreshAfterImport()
  UI.rebuildCharacterList()
  UI.rebuildItemList()
  if UI.activeTab == "raids" then
    UI.rebuildRaidList()
    UI.renderEncounterLootPanel()
  elseif UI.activeTab == "characters" then
    UI.renderCharacterPanel()
  else
    UI.renderSelectedItem()
  end
end
