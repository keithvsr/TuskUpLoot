local UI = TuskUpLoot.UI
local Util = {}
UI.Util = Util

function Util.safeChatPrint(msg)
  if TuskUpLoot.chatPrint then
    TuskUpLoot.chatPrint(msg)
    return
  end
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(tostring(msg))
  end
end

function Util.isInRequiredGuild()
  if TuskUpLoot.isInRequiredGuild then
    return TuskUpLoot.isInRequiredGuild()
  end
  return true
end

function Util.getRaidState()
  return TuskUpLoot.State or {}
end

function Util.isDetailReady()
  return UI.detailLinkFS and UI.needsTitle and UI.detailScrollChild
end

function Util.formatCharacterSummaryLine(character, characterKey)
  if not character then
    return nil
  end
  local name = character.name or characterKey or "?"
  local class = character.class or "PRIEST"
  local classColor = C_ClassColor.GetClassColor(class)
  local hex = classColor and classColor:GenerateHexColor() or "ffffffff"
  local namePart = "|c" .. hex .. name .. "|r"
  local race = character.race
  if race and race ~= "" then
    return namePart .. " · " .. race
  end
  return namePart
end

function Util.layoutDetailScrollForTab(tab)
  if not UI.detailScroll or not UI.detailHeader or not UI.frame then
    return
  end
  local C = UI.Constants
  local scroll = UI.detailScroll
  local scrollBarWidth = 0
  if scroll.ScrollBar then
    scrollBarWidth = scroll.ScrollBar:GetWidth()
  end
  scroll:ClearAllPoints()
  if tab == "characters" and UI.charInfoHeader then
    scroll:SetPoint("TOPLEFT", UI.charInfoHeader, "BOTTOMLEFT", 0, -6)
  else
    scroll:SetPoint("TOPLEFT", UI.detailHeader, "BOTTOMLEFT", 0, -8)
  end
  if scroll.ScrollBar then
    scroll:SetPoint("BOTTOMRIGHT", UI.frame, "BOTTOMRIGHT", -(C.MARGIN_R + scrollBarWidth), C.DETAIL_BOTTOM_CLOSED)
    scroll.ScrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", -2, 0)
  else
    scroll:SetPoint("BOTTOMRIGHT", UI.frame, "BOTTOMRIGHT", -C.MARGIN_R, C.DETAIL_BOTTOM_CLOSED)
  end
end

function Util.updateFrameTitle()
  if not UI.frameTitle then
    return
  end
  local state = Util.getRaidState()
  if state.InstanceId and TuskUpLoot.Data and TuskUpLoot.Data.Instances then
    local instance = TuskUpLoot.Data.Instances[state.InstanceId]
    if instance then
      UI.frameTitle:SetText("TuskUpLoot — " .. (instance.name or "Raid"))
      return
    end
  end
  UI.frameTitle:SetText("TuskUpLoot — Guild")
end

function UI.dismissAllFrames()
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
  if UI.frame then
    UI.frame:Hide()
  end
end

function Util.insertItemLinkIntoChat(itemId)
  if not itemId or not C_Item or not C_Item.GetItemInfo then
    return false
  end
  local _, itemLink = C_Item.GetItemInfo(itemId)
  if not itemLink or itemLink == "" then
    return false
  end
  local editBox = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
  if not editBox then
    return false
  end
  if ChatEdit_InsertLink then
    ChatEdit_InsertLink(itemLink, editBox)
    return true
  end
  return false
end

function Util.bindItemDetailShiftLinks(itemId)
  if UI.itemIconBtn and itemId then
    Util.bindItemShiftClick(UI.itemIconBtn, function()
      return UI.itemIconBtn.itemId
    end)
  end
  if UI.detailLinkHitBtn and itemId then
    UI.detailLinkHitBtn:Show()
    Util.bindItemShiftClick(UI.detailLinkHitBtn, function()
      return itemId
    end)
  elseif UI.detailLinkHitBtn then
    UI.detailLinkHitBtn:Hide()
  end
end

function Util.bindItemShiftClick(frame, getItemId)
  if not frame or not getItemId then
    return
  end
  frame:RegisterForClicks("LeftButtonUp")
  frame:SetScript("OnClick", function(_, button)
    if button == "LeftButton" and IsShiftKeyDown and IsShiftKeyDown() then
      local itemId = getItemId()
      if itemId then
        Util.insertItemLinkIntoChat(itemId)
      end
    end
  end)
end

function Util.createItemIcon(parent)
  local btn = CreateFrame("Button", "ItemIcon", parent)
  btn:SetSize(36, 36)
  btn.itemId = nil

  local icon = btn:CreateTexture(nil, "BACKGROUND")
  icon:SetAllPoints(btn)
  icon:SetTexture("Interface/Icons/INV_Misc_QuestionMark")
  btn.iconTex = icon

  local border = btn:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface/Common/WhiteIconFrame")
  border:SetAllPoints(btn)
  btn.border = border

  btn:SetScript("OnMouseDown", function(self)
    if not self or not self.itemId then
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(self.itemId)
    GameTooltip:Show()
  end)

  btn:SetScript("OnMouseUp", function()
    GameTooltip:Hide()
  end)

  Util.bindItemShiftClick(btn, function()
    return btn.itemId
  end)

  return btn
end

function Util.refreshItemIconButton(btn, itemId)
  if not btn then
    return
  end
  btn.itemId = itemId
  local _, _, itemQuality, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(itemId)
  if btn.iconTex then
    btn.iconTex:SetTexture(itemTexture)
  end
  if btn.border then
    local color = ITEM_QUALITY_COLORS[itemQuality]
    if color then
      btn.border:SetVertexColor(color.r, color.g, color.b)
    end
  end
end

function Util.formatItemLine(item)
  if not item or not item.id then
    return "- (invalid item)"
  end

  local _, itemLink
  if C_Item.GetItemInfo then
    _, itemLink = C_Item.GetItemInfo(item.id)
  end

  local name = item.name
  if not name and TuskUpLoot.Data and TuskUpLoot.Data.getItemDisplayName then
    name = TuskUpLoot.Data.getItemDisplayName(item.id)
  end

  return itemLink or (name and ("[" .. name .. "]")) or ("[Item " .. tostring(item.id) .. "]")
end

local COSMETIC_SLOTS = {
  shirt = true,
  tabard = true,
}

local COSMETIC_EQUIP_LOCS = {
  INVTYPE_BODY = true,
  INVTYPE_TABARD = true,
}

function Util.isCosmeticItem(itemId)
  if not itemId then
    return false
  end

  local DB = TuskUpLoot.DB
  if DB and DB.getItem then
    local item = DB.getItem(itemId)
    if item and item.slot then
      local slot = string.lower(tostring(item.slot))
      if COSMETIC_SLOTS[slot] then
        return true
      end
    end
  end

  if C_Item and C_Item.GetItemInfo then
    local equipLoc = select(9, C_Item.GetItemInfo(itemId))
    if equipLoc and COSMETIC_EQUIP_LOCS[equipLoc] then
      return true
    end
  end

  return false
end

function Util.filterVisibleItemIds(itemIds)
  local out = {}
  for _, itemId in ipairs(itemIds or {}) do
    if not Util.isCosmeticItem(itemId) then
      out[#out + 1] = itemId
    end
  end
  return out
end

local SLOT_ALIAS_TO_KEY = {
  head = "head",
  neck = "neck",
  shoulder = "shoulder",
  shoulders = "shoulder",
  back = "back",
  cloak = "back",
  chest = "chest",
  wrist = "wrist",
  wrists = "wrist",
  hands = "hands",
  hand = "hands",
  waist = "waist",
  belt = "waist",
  legs = "legs",
  leg = "legs",
  feet = "feet",
  foot = "feet",
  finger = "finger",
  ring = "finger",
  trinket = "trinket",
  mainhand = "mainhand",
  weapon = "mainhand",
  offhand = "offhand",
  ranged = "ranged",
  ammo = "ammo",
}

local EQUIP_LOC_TO_SLOT_KEY = {
  INVTYPE_HEAD = "head",
  INVTYPE_NECK = "neck",
  INVTYPE_SHOULDER = "shoulder",
  INVTYPE_CLOAK = "back",
  INVTYPE_CHEST = "chest",
  INVTYPE_ROBE = "chest",
  INVTYPE_WRIST = "wrist",
  INVTYPE_HAND = "hands",
  INVTYPE_WAIST = "waist",
  INVTYPE_LEGS = "legs",
  INVTYPE_FEET = "feet",
  INVTYPE_FINGER = "finger",
  INVTYPE_TRINKET = "trinket",
  INVTYPE_WEAPON = "mainhand",
  INVTYPE_WEAPONMAINHAND = "mainhand",
  INVTYPE_2HWEAPON = "mainhand",
  INVTYPE_SHIELD = "offhand",
  INVTYPE_WEAPONOFFHAND = "offhand",
  INVTYPE_HOLDABLE = "offhand",
  INVTYPE_RANGED = "ranged",
  INVTYPE_RANGEDRIGHT = "ranged",
  INVTYPE_AMMO = "ammo",
  INVTYPE_THROWN = "ammo",
}

local SLOT_DISPLAY_ORDER = {
  { key = "head",     label = "Head" },
  { key = "neck",     label = "Neck" },
  { key = "shoulder", label = "Shoulders" },
  { key = "back",     label = "Back" },
  { key = "chest",    label = "Chest" },
  { key = "wrist",    label = "Wrist" },
  { key = "hands",    label = "Hands" },
  { key = "waist",    label = "Belt" },
  { key = "legs",     label = "Legs" },
  { key = "feet",     label = "Feet" },
  { key = "finger",   label = "Ring",     numbered = true },
  { key = "trinket",  label = "Trinket",  numbered = true },
  { key = "mainhand", label = "Main Hand" },
  { key = "offhand",  label = "Off Hand" },
  { key = "ranged",   label = "Ranged" },
  { key = "ammo",     label = "Ammo" },
}

local function collectGearSetItemIds(items)
  local itemIds = {}
  if type(items) ~= "table" then
    return itemIds
  end

  local fromArray = false
  for _, id in ipairs(items) do
    itemIds[#itemIds + 1] = id
    fromArray = true
  end
  if not fromArray then
    for id in pairs(items) do
      itemIds[#itemIds + 1] = id
    end
  end

  return Util.filterVisibleItemIds(itemIds)
end

function Util.resolveSlotKey(itemId)
  if not itemId then
    return "unknown"
  end

  local DB = TuskUpLoot.DB
  if DB and DB.getItem then
    local item = DB.getItem(itemId)
    if item and item.slot then
      local slot = string.lower(tostring(item.slot)):gsub("%s+", "")
      if SLOT_ALIAS_TO_KEY[slot] then
        return SLOT_ALIAS_TO_KEY[slot]
      end
    end
  end

  if C_Item and C_Item.GetItemInfo then
    local equipLoc = select(9, C_Item.GetItemInfo(itemId))
    if equipLoc and EQUIP_LOC_TO_SLOT_KEY[equipLoc] then
      return EQUIP_LOC_TO_SLOT_KEY[equipLoc]
    end
  end

  return "unknown"
end

function Util.gearSetEntriesInDisplayOrder(items)
  local itemIds = collectGearSetItemIds(items)
  local buckets = {}

  for _, itemId in ipairs(itemIds) do
    local slotKey = Util.resolveSlotKey(itemId)
    if not buckets[slotKey] then
      buckets[slotKey] = {}
    end
    buckets[slotKey][#buckets[slotKey] + 1] = itemId
  end

  for _, ids in pairs(buckets) do
    table.sort(ids, function(a, b)
      return (tonumber(a) or 0) < (tonumber(b) or 0)
    end)
  end

  local entries = {}
  for _, slotDef in ipairs(SLOT_DISPLAY_ORDER) do
    local ids = buckets[slotDef.key]
    if ids then
      for i, itemId in ipairs(ids) do
        local label = slotDef.label
        if slotDef.numbered then
          label = string.format("%s %d", slotDef.label, i)
        end
        entries[#entries + 1] = {
          slotLabel = label,
          itemId = itemId,
        }
      end
      buckets[slotDef.key] = nil
    end
  end

  local unknown = buckets.unknown
  if unknown then
    for _, itemId in ipairs(unknown) do
      entries[#entries + 1] = {
        slotLabel = "Other",
        itemId = itemId,
      }
    end
  end

  for slotKey, ids in pairs(buckets) do
    if ids then
      for _, itemId in ipairs(ids) do
        entries[#entries + 1] = {
          slotLabel = "Other",
          itemId = itemId,
        }
      end
    end
  end

  return entries
end

function Util.gearSetItemIds(items)
  local entries = Util.gearSetEntriesInDisplayOrder(items)
  local itemIds = {}
  for _, entry in ipairs(entries) do
    itemIds[#itemIds + 1] = entry.itemId
  end
  return itemIds
end

function Util.getOrCreateLootRow(container, rows, index, rowHeight)
  local row = rows[index]
  if not row then
    row = CreateFrame("Button", nil, container)
    row:SetHeight(rowHeight)
    row.labelFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.labelFS:SetPoint("LEFT", 4, 0)
    row.labelFS:SetPoint("RIGHT", row, "RIGHT", -72, 0)
    row.labelFS:SetJustifyH("LEFT")
    row.countFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.countFS:SetPoint("RIGHT", -4, 0)
    row.countFS:SetJustifyH("RIGHT")
    rows[index] = row
  end
  return row
end

function Util.filterNeedle()
  local ed = UI.filterEdit
  if not ed then
    return ""
  end
  local t = ed:GetText() or ""
  t = t:gsub("^%s+", ""):gsub("%s+$", "")
  if t == "" then
    return ""
  end
  return string.lower(t)
end

function Util.clearFilter()
  local ed = UI.filterEdit
  if not ed then
    return
  end
  ed:SetText("")
  ed:ClearFocus()
end

local function characterRowName(row)
  return string.lower(row.name or row.key or "")
end

local function characterRowClass(row)
  return string.lower(row.class or "")
end

local function buildManualSortPositionMap(manualSortKeys)
  local positions = {}
  if type(manualSortKeys) ~= "table" then
    return positions
  end
  for i, key in ipairs(manualSortKeys) do
    if type(key) == "string" then
      positions[key] = i
    end
  end
  return positions
end

function Util.sortCharacterRows(rows, sortBy, descending, manualSortKeys)
  if type(rows) ~= "table" then
    return
  end
  sortBy = sortBy or "name"
  local manualPositions
  if sortBy == "manual" then
    manualPositions = buildManualSortPositionMap(manualSortKeys)
    descending = false
  end
  table.sort(rows, function(a, b)
    if descending then
      a, b = b, a
    end
    if sortBy == "manual" then
      local aPos = manualPositions[a.key] or 999999
      local bPos = manualPositions[b.key] or 999999
      if aPos ~= bPos then
        return aPos < bPos
      end
      return characterRowName(a) < characterRowName(b)
    end
    if sortBy == "class" then
      local aClass = characterRowClass(a)
      local bClass = characterRowClass(b)
      if aClass ~= bClass then
        return aClass < bClass
      end
      return characterRowName(a) < characterRowName(b)
    end
    return characterRowName(a) < characterRowName(b)
  end)
end

function Util.getCharListDropIndex(container, cursorY)
  if not container or not container.buttons or type(cursorY) ~= "number" then
    return nil
  end

  local scale = container:GetEffectiveScale()
  if scale == 0 then
    return nil
  end
  local y = cursorY / scale

  local bestIndex
  local bestDistance = math.huge
  for _, btn in ipairs(container.buttons) do
    if btn:IsShown() and btn.sortIndex then
      local top = btn:GetTop()
      local bottom = btn:GetBottom()
      if top and bottom then
        if y <= top and y >= bottom then
          return btn.sortIndex
        end
        local mid = (top + bottom) / 2
        local distance = math.abs(y - mid)
        if distance < bestDistance then
          bestDistance = distance
          bestIndex = btn.sortIndex
        end
      end
    end
  end
  return bestIndex
end

function Util.clearCharListDragVisuals(container)
  if not container or not container.buttons then
    return
  end
  for _, btn in ipairs(container.buttons) do
    if btn.text then
      btn.text:SetAlpha(1)
    end
    if btn.dropIndicator then
      btn.dropIndicator:Hide()
    end
    if btn.bg then
      btn.bg:Hide()
    end
  end
end

function Util.setCharListButtonDragged(btn, dragged)
  if not btn or not btn.text then
    return
  end
  if dragged then
    btn.text:SetAlpha(0.45)
  else
    btn.text:SetAlpha(1)
  end
end

function Util.ensureListButtonDropIndicator(btn)
  if not btn then
    return
  end
  if not btn.dropIndicator then
    btn.dropIndicator = btn:CreateTexture(nil, "OVERLAY")
    btn.dropIndicator:SetColorTexture(1, 0.84, 0, 1)
    btn.dropIndicator:SetHeight(2)
    btn.dropIndicator:Hide()
  end
end

function Util.applyCharListDropIndicator(container, dragIndex, dropIndex)
  if not container or not container.buttons then
    return
  end
  for _, btn in ipairs(container.buttons) do
    if btn.dropIndicator then
      btn.dropIndicator:Hide()
    end
  end
  if not dropIndex or not dragIndex or dragIndex == dropIndex then
    return
  end

  for _, btn in ipairs(container.buttons) do
    if btn:IsShown() and btn.sortIndex == dropIndex then
      Util.ensureListButtonDropIndicator(btn)
      local indicator = btn.dropIndicator
      indicator:ClearAllPoints()
      if dragIndex < dropIndex then
        indicator:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 4, 0)
        indicator:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -4, 0)
      else
        indicator:SetPoint("TOPLEFT", btn, "TOPLEFT", 4, 0)
        indicator:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -4, 0)
      end
      indicator:SetHeight(2)
      indicator:Show()
      break
    end
  end
end

function Util.getOrCreateCharGearItemRow(container, rows, index, rowHeight)
  local C = UI.Constants
  local slotCol = C.CHAR_SLOT_COL_W
  local acquiredW = C.CHAR_ACQUIRED_W
  local itemLeft = slotCol + C.CHAR_ITEM_COL_GAP

  local row = rows[index]
  if not row then
    row = CreateFrame("Frame", nil, container)
    row:SetHeight(rowHeight)

    row.slotFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.slotFS:SetWidth(slotCol)
    row.slotFS:SetPoint("LEFT", 4, 0)
    row.slotFS:SetJustifyH("RIGHT")

    row.acquiredCheck = CreateFrame("CheckButton", nil, row, "ChatConfigCheckButtonTemplate")
    row.acquiredCheck:SetSize(acquiredW, acquiredW)
    row.acquiredCheck:SetPoint("RIGHT", row, "RIGHT", -4, 0)

    row.itemBtn = CreateFrame("Button", nil, row)
    row.itemBtn:SetPoint("LEFT", row, "LEFT", itemLeft, 0)
    row.itemBtn:SetPoint("RIGHT", row.acquiredCheck, "LEFT", -4, 0)
    row.itemBtn:SetHeight(rowHeight)
    row.itemText = row.itemBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.itemText:SetPoint("LEFT", 0, 0)
    row.itemText:SetPoint("RIGHT", 0, 0)
    row.itemText:SetJustifyH("LEFT")

    rows[index] = row
  end
  return row
end

function Util.getOrCreateListButton(container, buttons, index, btnHeight)
  local btn = buttons[index]
  if not btn then
    btn = CreateFrame("Button", nil, container)
    btn:SetHeight(btnHeight)
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.text:SetPoint("LEFT", 4, 0)
    btn.text:SetPoint("RIGHT", -4, 0)
    btn.text:SetJustifyH("LEFT")
    buttons[index] = btn
  end
  return btn
end

function Util.setCloseButtonPlacement(parentFrame)
  if not parentFrame or not parentFrame:GetName() then
    return
  end
  local frameName = parentFrame:GetName()
  local closeBtn = _G[frameName .. "Close"]
  if closeBtn then
    closeBtn:ClearAllPoints()
    closeBtn:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", 2, 1)
  end
end

function Util.getOrCreateRaidRow(container, rows, index)
  local C = UI.Constants
  local row = rows[index]
  if not row then
    row = CreateFrame("Button", nil, container)
    row:SetHeight(C.ROW_HEIGHT)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", 4, 0)
    row.text:SetPoint("RIGHT", -4, 0)
    row.text:SetJustifyH("LEFT")
    rows[index] = row
  end
  return row
end
