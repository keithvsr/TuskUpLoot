-- Tab strip orchestration: visibility, switching, refresh, selection.

local UI = TuskUpLoot.UI
local Util = UI.Util

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

  local showFilter = (tab == "characters" or tab == "items")
  if UI.filterBg then
    UI.filterBg:SetShown(showFilter)
  end
  if UI.filterEdit then
    UI.filterEdit:SetShown(showFilter)
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
    raids = "Who needs it",
    items = "Who needs it",
  }
  if UI.detailSectionLabel then
    UI.detailSectionLabel:SetText(detailLabels[tab] or "")
  end

  local showItemDetail = (tab == "items" or tab == "raids")
  if UI.detailHeader then
    UI.detailHeader:SetShown(showItemDetail)
  end
  if UI.charDetailFS then
    UI.charDetailFS:SetShown(tab == "characters")
  end
  if tab == "characters" then
    if UI.needsTitle then UI.needsTitle:Hide() end
    if UI.needsListContainer then UI.needsListContainer:Hide() end
    if UI.hasTitle then UI.hasTitle:Hide() end
    if UI.hasText then UI.hasText:Hide() end
  end

  updateTabButtonStyles()
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
    UI.renderRaidPanel()
  end
end

function UI.setSelectedItemId(itemId)
  UI.selectedItemId = itemId
  if UI.activeTab == "items" then
    UI.renderSelectedItem()
    UI.rebuildItemList()
  elseif UI.activeTab == "raids" then
    UI.renderRaidPanel()
    UI.rebuildRaidList()
  else
    UI.renderSelectedItem()
    UI.rebuildItemList()
  end
end

function UI.refresh()
  local tab = UI.activeTab
  if tab == "characters" then
    UI.renderCharacterPanel()
  elseif tab == "items" then
    UI.renderSelectedItem()
  elseif tab == "raids" then
    UI.renderRaidPanel()
  end
end

function UI.refreshAfterImport()
  UI.rebuildCharacterList()
  UI.rebuildItemList()
  if UI.activeTab == "raids" then
    UI.rebuildRaidList()
    UI.renderRaidPanel()
  elseif UI.activeTab == "characters" then
    UI.renderCharacterPanel()
  else
    UI.renderSelectedItem()
  end
end
