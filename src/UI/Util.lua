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
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    GameTooltip:SetItemByID(self.itemId)
    GameTooltip:Show()
  end)

  btn:SetScript("OnMouseUp", function()
    GameTooltip:Hide()
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

function Util.gearSetItemIds(items)
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

  table.sort(itemIds, function(a, b)
    return (tonumber(a) or 0) < (tonumber(b) or 0)
  end)
  return itemIds
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
