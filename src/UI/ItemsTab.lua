-- Items tab: filtered imported-item list (detail panel lives in ItemDetail.lua).

local UI = TuskUpLoot.UI
local Util = UI.Util

local function itemMatchesFilter(itemId, item, needle)
  if needle == "" then
    return true
  end
  local name
  if C_Item.GetItemInfo then
    name = select(1, C_Item.GetItemInfo(itemId))
  end
  name = name or (item and item.name) or ""
  if name == "" and TuskUpLoot.Data and TuskUpLoot.Data.getItemDisplayName then
    name = TuskUpLoot.Data.getItemDisplayName(itemId) or ""
  end
  return string.find(string.lower(name), needle, 1, true) ~= nil
end

function UI.rebuildItemList()
  if not UI.itemListContainer then
    return
  end

  if not TuskUpLoot.DB then
    return
  end

  local container = UI.itemListContainer
  if container.buttons then
    for _, b in ipairs(container.buttons) do
      b:Hide()
    end
  end
  container.buttons = container.buttons or {}

  local items = TuskUpLoot.DB.getItems()
  local needle = Util.filterNeedle()
  local sortedIds = TuskUpLoot.DB.sortedItemIDs()
  local y = -6
  local btnHeight = 18
  local i = 0

  for _, itemId in ipairs(sortedIds) do
    local item = items[itemId]
    if item and not Util.isCosmeticItem(itemId) and itemMatchesFilter(itemId, item, needle) then
      i = i + 1
      local itemLine = Util.formatItemLine(item)

      local btn = Util.getOrCreateListButton(container, container.buttons, i, btnHeight)
      btn:ClearAllPoints()
      btn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, y)
      btn:SetPoint("RIGHT", container, "RIGHT", 0, 0)

      local idCapture = itemId
      btn:SetScript("OnClick", function()
        UI.openItemDetail(idCapture, nil)
      end)

      local isSelected = (UI.selectedItemId == itemId)
      btn.text:SetText((isSelected and "|cffffff00" or "") .. itemLine .. (isSelected and "|r" or ""))
      btn:Show()

      y = y - btnHeight
    end
  end

  container:SetHeight(math.max(1, (i * btnHeight) + 12))
end
