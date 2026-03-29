-- Handles UI creation + rendering for the addon.

TuskUpLoot.UI = TuskUpLoot.UI or {}
local UI = TuskUpLoot.UI

UI.updateAccumulator = UI.updateAccumulator or 0
UI.updateIntervalSeconds = UI.updateIntervalSeconds or 0.5

local RAIL_WIDTH = 200
local FRAME_WIDTH = 640
local FRAME_HEIGHT = 440
local MARGIN_L = 18
local MARGIN_R = 22
local CONTENT_X = MARGIN_L + RAIL_WIDTH + 12
local DETAIL_BOTTOM_CLOSED = 52

local IMPORT_FRAME_WIDTH = 480
local IMPORT_FRAME_HEIGHT = 400
local IMPORT_EDIT_WIDTH = 440
local IMPORT_EDIT_HEIGHT = 260

local textInset = 16

local function safeChatPrint(msg)
  if TuskUpLoot.chatPrint then
    TuskUpLoot.chatPrint(msg)
    return
  end
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(tostring(msg))
  end
end

local function isInRequiredGuild()
  if TuskUpLoot.isInRequiredGuild then
    return TuskUpLoot.isInRequiredGuild()
  end
  return true
end

local function createItemIcon(parent)
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

local function refreshItemIconButton(btn, itemId)
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

local function formatItemLine(item)
  if not item or not item.id then
    return "- (invalid item)"
  end

  local _, itemLink
  if C_Item.GetItemInfo then
    _, itemLink = C_Item.GetItemInfo(item.id)
  end

  return itemLink or (item.name and ("[" .. item.name .. "]")) or ("[Item " .. tostring(item.id) .. "]")
end

local function filterNeedle()
  local ed = UI.itemFilterEdit
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

local function itemMatchesFilter(itemId, item, needle)
  if needle == "" then
    return true
  end
  local name
  if C_Item.GetItemInfo then
    name = select(1, C_Item.GetItemInfo(itemId))
  end
  name = name or (item and item.name) or ""
  return string.find(string.lower(name), needle, 1, true) ~= nil
end


-- local function syncDetailBodyHeight()
--   local needsTitle = UI.needsTitle
--   local needsText = UI.needsText
--   local hasTitle = UI.hasTitle
--   local hasText = UI.hasText
--   local child = UI.detailScrollChild
--   if not needsTitle or not needsText or not hasTitle or not hasText or not child or not UI.detailScroll then
--     return
--   end
--   local w = UI.detailScroll:GetWidth() - 8
--   if w < 40 then
--     w = 280
--   end
--   needsTitle:SetWidth(w)
--   needsText:SetWidth(w)
--   hasTitle:SetWidth(w)
--   hasText:SetWidth(w)
--   local nTitleHeight = math.max(needsTitle:GetStringHeight(), 28)
--   local nTextHeight = math.max(needsText:GetStringHeight(), 20)
--   local hTitleHeight = math.max(hasTitle:GetStringHeight(), 28)
--   local hTextHeight = math.max(hasText:GetStringHeight(), 20)
--   local h = nTitleHeight + nTextHeight + hTitleHeight + hTextHeight + 12
--   needsTitle:SetHeight(nTitleHeight)
--   needsText:SetHeight(nTextHeight)
--   hasTitle:SetHeight(hTitleHeight)
--   hasText:SetHeight(hTextHeight)
--   -- text:SetHeight(h)
--   child:SetWidth(w + 4)
--   child:SetHeight(h)
-- end


local function clearNeedsList()
  if not UI.needsListContainer then
    return
  end

  if UI.needsRowFrames then
    for _, fr in ipairs(UI.needsRowFrames) do
      if fr then
        fr:Hide()
      end
    end
  end

  UI.needsListContainer:SetHeight(1)
end

local function renderNeedsList(needsRows, selectedItemId)
  local container = UI.needsListContainer
  if not container then
    return
  end

  local frames = UI.needsRowFrames or {}
  UI.needsRowFrames = frames

  -- Layout constants
  local MARK_BTN_W = 78
  local MARK_BTN_H = 18
  local GAP_X = 4
  local GAP_Y = 6
  local leftW = math.max(10, container:GetWidth() - MARK_BTN_W - GAP_X)

  clearNeedsList()

  local y = 0
  for i, row in ipairs(needsRows or {}) do
    local fr = frames[i]
    if not fr then
      fr = CreateFrame("Frame", nil, container)
      fr:SetWidth(container:GetWidth())

      local whoFS = fr:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      whoFS:SetJustifyH("LEFT")
      whoFS:SetWidth(leftW)
      whoFS:SetPoint("TOPLEFT", fr, "TOPLEFT", 0, 0)
      fr.whoFS = whoFS

      local gearFS = fr:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      gearFS:SetJustifyH("LEFT")
      gearFS:SetWordWrap(false)
      gearFS:SetWidth(leftW)
      gearFS:SetPoint("TOPLEFT", whoFS, "BOTTOMLEFT", 0, -2)
      fr.gearFS = gearFS

      local markBtn = CreateFrame("Button", nil, fr, "UIPanelButtonTemplate")
      markBtn:SetSize(MARK_BTN_W, MARK_BTN_H)
      markBtn:SetText("Looted")
      markBtn:SetPoint("TOPRIGHT", fr, "TOPRIGHT", 2, 0)
      local fontString = markBtn.GetFontString and markBtn:GetFontString()
      if fontString and fontString.SetFontObject then
        fontString:SetFontObject(ChatFontSmall)
      end
      fr.markBtn = markBtn

      frames[i] = fr
    end

    fr:ClearAllPoints()
    fr:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y)
    fr:SetWidth(container:GetWidth())

    local who = row.who or row.characterKey or "Unknown"
    fr.whoFS:SetText(who)
    fr.whoFS:SetWidth(leftW)

    local gearLines = {}
    for _, gs in ipairs(row.gearSets or {}) do
      local phase = gs.phase ~= nil and string.format(" (Phase %s)", tostring(gs.phase)) or ""
      gearLines[#gearLines + 1] = string.format("    • %s%s", gs.name or gs.key, phase)
    end
    if #gearLines == 0 then
      gearLines[1] = "    • (no gear sets)"
    end
    fr.gearFS:SetText(table.concat(gearLines, "\n"))
    fr.gearFS:SetWidth(leftW)

    if fr.markBtn then
      -- fr.markBtn.characterKey = row.characterKey
      fr.markBtn:SetScript("OnClick", function()
        TuskUpLoot.DB.markItemAcquired(selectedItemId, row.characterKey)
        UI.renderSelectedItem()
      end)
    end

    local whoH = fr.whoFS:GetStringHeight() or 0
    local gearH = fr.gearFS:GetStringHeight() or 0
    local frH = math.max(MARK_BTN_H, whoH + 2 + gearH)
    fr:SetHeight(frH)

    fr:Show()
    y = y + frH + GAP_Y
  end

  for j = (#needsRows or 0) + 1, #frames do
    if frames[j] then
      frames[j]:Hide()
    end
  end

  container:SetHeight(math.max(1, y))
end

function UI.renderSelectedItem()
  if not UI.needsTitle or not UI.needsListContainer or not UI.hasTitle or not UI.hasText or not UI.detailLinkFS or not UI.detailScrollChild then
    return
  end

  local DB = TuskUpLoot.DB
  local selectedItemId = UI.selectedItemId
  local item = selectedItemId and DB and DB.getItem(selectedItemId)

  if not item then
    if UI.itemIconBtn then
      UI.itemIconBtn:Hide()
    end
    UI.detailLinkFS:SetText("")
    UI.needsTitle:SetText(
      "Select an item in Imported Items,\nor use Import JSON (bottom) to add sixtyupgrades exports."
    )
    clearNeedsList()
    UI.needsListContainer:Hide()
    UI.hasTitle:SetText("")
    UI.hasText:SetText("")
    UI.hasTitle:Hide()
    UI.hasText:Hide()
    -- syncDetailBodyHeight()
    return
  else
    UI.needsTitle:SetText("")
    UI.hasTitle:SetText("")
    UI.hasText:SetText("")
    clearNeedsList()
    UI.needsListContainer:Hide()
    UI.needsTitle:Hide()
    UI.hasTitle:Hide()
    UI.hasText:Hide()
    -- syncDetailBodyHeight()
  end

  if UI.itemIconBtn then
    refreshItemIconButton(UI.itemIconBtn, selectedItemId)
    UI.itemIconBtn:Show()
  end

  local _, itemLink = C_Item.GetItemInfo(selectedItemId)

  if not itemLink and item.name then
    itemLink = "|cffffffff[" .. item.name .. "]|r"
  elseif not itemLink then
    itemLink = "|cffffffff[Item " .. tostring(selectedItemId) .. "]|r"
  end
  UI.detailLinkFS:SetText(itemLink)

  local rollup = DB.getItemRollup(selectedItemId)
  -- local lines = {}
  if not rollup or #rollup == 0 then
    UI.needsTitle:SetText("No characters linked to this item in saved data.")
    clearNeedsList()
    UI.needsListContainer:Hide()
    UI.needsTitle:Show()
    UI.hasTitle:SetText("")
    UI.hasText:SetText("")
    UI.hasTitle:Hide()
    UI.hasText:Hide()
  else
    local needs = {} -- array of { who, characterKey, gearSets }
    local has = {}
    for _, row in ipairs(rollup) do
      local who = row.name or row.characterKey
      if row.hasAcquired then
        has[#has + 1] = string.format("%s", who)
        for _, gs in ipairs(row.gearSets or {}) do
          local phase = gs.phase ~= nil and string.format(" (Phase %s)", tostring(gs.phase)) or ""
          has[#has + 1] = string.format("    • %s%s", gs.name or gs.key, phase)
        end
      else
        needs[#needs + 1] = {
          who = who,
          characterKey = row.characterKey,
          gearSets = row.gearSets or {},
        }
      end
    end

    local needsShown = (#needs > 0)
    local hasShown = (#has > 0)

    if needsShown then
      UI.needsTitle:SetText("Needs Item:")
      UI.needsTitle:Show()
      UI.needsListContainer:Show()
      renderNeedsList(needs, selectedItemId)

      UI.hasTitle:ClearAllPoints()
      UI.hasTitle:SetPoint("TOPLEFT", UI.needsListContainer, "BOTTOMLEFT", -textInset, -8)
    else
      clearNeedsList()
      UI.needsListContainer:Hide()
      UI.needsTitle:Hide()

      UI.hasTitle:ClearAllPoints()
      UI.hasTitle:SetPoint("TOPLEFT", UI.detailScrollChild, "TOPLEFT", 4, 0)
    end

    if hasShown then
      UI.hasTitle:SetText("Has Item:")
      UI.hasText:SetText(table.concat(has, "\n"))
      UI.hasTitle:Show()
      UI.hasText:Show()
    else
      UI.hasTitle:SetText("")
      UI.hasText:SetText("")
      UI.hasTitle:Hide()
      UI.hasText:Hide()
    end

    -- Keep scroll child height aligned to content.
    local totalH = 1
    local needsTitleH = UI.needsTitle:GetStringHeight() or 0
    local needsListH = UI.needsListContainer and UI.needsListContainer:GetHeight() or 0
    local hasTitleH = UI.hasTitle:GetStringHeight() or 0
    local hasTextH = UI.hasText:GetStringHeight() or 0

    if needsShown then
      totalH = totalH + needsTitleH + 4 + needsListH
    end
    if hasShown then
      if needsShown then
        totalH = totalH + 8 + hasTitleH + 4 + hasTextH
      else
        totalH = totalH + hasTitleH + 4 + hasTextH
      end
    end
    UI.detailScrollChild:SetHeight(math.max(1, totalH))
    UI.detailScrollChild:SetWidth(UI.detailScroll:GetWidth())
  end

  -- UI.detailText:SetText(table.concat(lines, "\n"))
  -- syncDetailBodyHeight()
end

function UI.renderSelectedCharacter()
  if not UI.text then
    return
  end

  local DB = TuskUpLoot.DB
  if not DB then
    UI.text:SetText("TuskUpLoot: DB module not loaded.")
    return
  end

  if not TuskUpLoot.dbInitialized then
    DB.init()
  end

  local db = _G.TuskUpLootDB
  if not db or not db.characters then
    UI.text:SetText("No saved data yet.")
    return
  end

  local selectedKey = UI.selectedCharacterKey
  local character = selectedKey and db.characters[selectedKey]

  if character then
    local lines = {
      string.format("Character: %s", character.name or selectedKey),
    }
    if character.level then
      lines[#lines + 1] = string.format("Level: %s", tostring(character.level))
    end
    if character.race then
      lines[#lines + 1] = string.format("Race: %s", character.race)
    end
    if character.class then
      lines[#lines + 1] = string.format("Class: %s", character.class)
    end
    lines[#lines + 1] = ""

    local orderedSets = DB.characterGearSets(selectedKey)
    if not orderedSets or #orderedSets == 0 then
      lines[#lines + 1] = "(No gear sets stored for this character.)"
      UI.text:SetText(table.concat(lines, "\n"))
      return
    end

    local lineBudget = 200
    for _, row in ipairs(orderedSets) do
      local gs = row.gearSet
      if gs then
        lines[#lines + 1] = string.format("--- %s (phase %s) ---", gs.name or row.key, tostring(gs.phase or "?"))
        local itemMap = gs.items or {}
        local itemIds = {}
        for id in pairs(itemMap) do
          itemIds[#itemIds + 1] = id
        end
        table.sort(itemIds, function(a, b)
          return (tonumber(a) or 0) < (tonumber(b) or 0)
        end)
        for _, id in ipairs(itemIds) do
          if #lines >= lineBudget then
            lines[#lines + 1] = "... (truncated)"
            break
          end
          local meta = db.items and db.items[id]
          lines[#lines + 1] = formatItemLine(meta or { id = id, name = nil, slot = nil })
        end
        lines[#lines + 1] = ""
      end
      if #lines >= lineBudget then
        break
      end
    end

    UI.text:SetText(table.concat(lines, "\n"))
    return
  end

  local anyChars = false
  for _ in pairs(db.characters) do
    anyChars = true
    break
  end

  if not anyChars then
    UI.text:SetText('No character lists imported.\nUse Import JSON at the bottom to paste a sixtyupgrades export.')
  else
    UI.text:SetText("Select a character from the list to view their gear sets.")
  end
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
  local needle = filterNeedle()
  local sortedIds = TuskUpLoot.DB.sortedItemIDs()
  local y = -6
  local btnHeight = 18
  local i = 0

  for _, itemId in ipairs(sortedIds) do
    local item = items[itemId]
    if item and itemMatchesFilter(itemId, item, needle) then
      i = i + 1
      local itemLine = formatItemLine(item)

      local btn = container.buttons[i]
      if not btn then
        btn = CreateFrame("Button", nil, container)
        btn:SetHeight(btnHeight)
        btn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, y)
        btn:SetPoint("RIGHT", container, "RIGHT", 0, 0)
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btn.text:SetPoint("LEFT", 4, 0)
        btn.text:SetPoint("RIGHT", -4, 0)
        btn.text:SetJustifyH("LEFT")
        container.buttons[i] = btn
      else
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, y)
        btn:SetPoint("RIGHT", container, "RIGHT", 0, 0)
      end

      local idCapture = itemId
      btn:SetScript("OnClick", function()
        UI.setSelectedItemId(idCapture)
      end)

      local isSelected = (UI.selectedItemId == itemId)
      btn.text:SetText((isSelected and "|cffffff00" or "") .. itemLine .. (isSelected and "|r" or ""))
      btn:Show()

      y = y - btnHeight
    end
  end

  container:SetHeight(math.max(1, (i * btnHeight) + 12))
end

function UI.rebuildCharacterList()
  if not UI.charListContainer then
    return
  end

  local DB = TuskUpLoot.DB
  if not DB then
    return
  end

  local container = UI.charListContainer
  if container.buttons then
    for _, b in ipairs(container.buttons) do
      b:Hide()
    end
  end
  container.buttons = container.buttons or {}

  local rows = DB.characterNamesAndClasses() or {}
  local y = -6
  local btnHeight = 18

  for j = 1, #rows do
    local row = rows[j]
    local key = row.key
    local label = row.name or key

    local btn = container.buttons[j]
    if not btn then
      btn = CreateFrame("Button", nil, container)
      btn:SetHeight(btnHeight)
      btn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, y)
      btn:SetPoint("RIGHT", container, "RIGHT", 0, 0)
      btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      btn.text:SetPoint("LEFT", 4, 0)
      btn.text:SetJustifyH("LEFT")
      container.buttons[j] = btn
    else
      btn:ClearAllPoints()
      btn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, y)
      btn:SetPoint("RIGHT", container, "RIGHT", 0, 0)
    end

    btn:SetScript("OnClick", function()
      UI.setSelectedCharacter(key)
    end)

    local isSelected = (UI.selectedCharacterKey == key)
    btn.text:SetText((isSelected and "|cffffff00" or "") .. label .. (isSelected and "|r" or ""))
    btn:Show()

    y = y - btnHeight
  end

  container:SetHeight(math.max(1, (#rows * btnHeight) + 12))
end

function UI.setSelectedItemId(itemId)
  UI.selectedItemId = itemId
  UI.renderSelectedItem()
  UI.rebuildItemList()
end

function UI.setSelectedCharacter(key)
  UI.selectedCharacterKey = key
  UI.renderSelectedCharacter()
  UI.rebuildCharacterList()
end

function UI.refresh()
  UI.renderSelectedItem()
end

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
  imp:SetSize(IMPORT_FRAME_WIDTH, IMPORT_FRAME_HEIGHT)
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
  editBg:SetWidth(IMPORT_EDIT_WIDTH)
  -- editBg:EnableMouse(true)
  -- if editBg.SetBackdrop then
  --   editBg:SetBackdrop({
  --     bgFile = "Interface/ChatFrame/ChatFrameBackground",
  --     edgeFile = "Interface/ChatFrame/ChatFrameBorder",
  --     tile = true,
  --     tileSize = 16,
  --     edgeSize = 12,
  --     insets = { left = 2, right = 2, top = 2, bottom = 2 },
  --   })
  --   editBg:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
  -- end

  local editScroll = CreateFrame("ScrollFrame", nil, editBg, "UIPanelScrollFrameTemplate")
  editScroll:SetPoint("TOPLEFT", editBg, "TOPLEFT", 4, -4)
  editScroll:SetPoint("BOTTOMRIGHT", editBg, "BOTTOMRIGHT", -4, 4)

  local editChild = CreateFrame("Frame", nil, editScroll)
  editChild:SetWidth(IMPORT_EDIT_WIDTH - 16)
  editChild:SetHeight(math.max(IMPORT_EDIT_HEIGHT, 200))

  local editBoxBg = CreateFrame("Frame", nil, editChild, "BackdropTemplate")
  editBoxBg:SetPoint("TOPLEFT", editChild, "TOPLEFT", 6, -6)
  editBoxBg:SetSize(IMPORT_EDIT_WIDTH - 32, math.max(IMPORT_EDIT_HEIGHT - 8, 192))
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
  editBox:SetWidth(IMPORT_EDIT_WIDTH - 32)
  editBox:SetHeight(math.max(IMPORT_EDIT_HEIGHT - 8, 192))
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
      safeChatPrint("Paste a JSON export first.")
      return
    end

    local payload, err
    if TuskUpLoot.Importer then
      payload, err = TuskUpLoot.Importer.import(txt)
    end
    if not payload then
      safeChatPrint("Import failed: " .. tostring(err or "unknown"))
      return
    end

    local name = payload.character and payload.character.name
    local gearSetName = payload.name or ""
    safeChatPrint(string.format("Imported %s gear set %s", tostring(name or "character"), tostring(gearSetName)))
    if editBox then
      editBox:SetText("")
    end
    hideImportFrameShowMain()
    UI.rebuildItemList()
    UI.renderSelectedItem()
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

function UI.ensureFrame()
  if UI.frame then
    return
  end

  local f = CreateFrame("Frame", "TuskUpLootMainFrame", UIParent, "UIPanelDialogTemplate")
  f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
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
    UI.refresh()
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
  title:SetText("TuskUpLoot — BIS List Items")

  local listBg = CreateFrame("Frame", nil, f)
  listBg:SetPoint("TOPLEFT", f, "TOPLEFT", MARGIN_L, -42)
  listBg:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", MARGIN_L, MARGIN_L)
  listBg:SetWidth(RAIL_WIDTH)

  local listTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  listTitle:SetPoint("TOPLEFT", listBg, "TOPLEFT", 2, -2)
  listTitle:SetText("Imported Items")
  UI.listTitle = listTitle

  local filterBg = CreateFrame("Frame", nil, listBg, "BackdropTemplate")
  filterBg:SetPoint("TOPLEFT", listBg, "TOPLEFT", 0, -24)
  filterBg:SetPoint("TOPRIGHT", listBg, "TOPRIGHT", -28, -24)
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

  local filterEdit = CreateFrame("EditBox", nil, listBg)
  filterEdit:SetFontObject(ChatFontSmall)
  filterEdit:SetHeight(20)
  filterEdit:SetAutoFocus(false)
  filterEdit:SetAllPoints(filterBg)
  filterEdit:SetTextInsets(6, 6, 3, 3)
  filterEdit:SetFrameLevel(filterBg:GetFrameLevel() + 2)
  filterEdit:SetScript("OnEscapePressed", function(selfEdit)
    selfEdit:ClearFocus()
  end)
  filterEdit:SetScript("OnTextChanged", function()
    UI.rebuildItemList()
  end)
  UI.itemFilterEdit = filterEdit

  local listScroll = CreateFrame("ScrollFrame", nil, listBg, "UIPanelScrollFrameTemplate")
  listScroll:SetPoint("TOPLEFT", listBg, "TOPLEFT", 0, -48)
  listScroll:SetPoint("BOTTOMRIGHT", listBg, "BOTTOMRIGHT", -26, 0)

  local listContainer = CreateFrame("Frame", nil, listScroll)
  listContainer:SetWidth(RAIL_WIDTH - 8)
  listContainer:SetHeight(1)
  listScroll:SetScrollChild(listContainer)

  UI.itemListContainer = listContainer
  UI.itemListScroll = listScroll

  local detailSectionLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  detailSectionLabel:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_X, -44)
  detailSectionLabel:SetText("Who needs it")

  local detailHeader = CreateFrame("Frame", nil, f)
  detailHeader:SetHeight(36)
  detailHeader:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_X, -64)
  detailHeader:SetPoint("TOPRIGHT", f, "TOPRIGHT", -MARGIN_R, -64)
  detailHeader:EnableMouse(true)
  UI.detailHeader = detailHeader

  local itemIconBtn = createItemIcon(detailHeader)
  itemIconBtn:SetPoint("LEFT", detailHeader, "LEFT", 0, 0)
  itemIconBtn:Hide()
  UI.itemIconBtn = itemIconBtn

  local detailLinkFS = detailHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  detailLinkFS:SetPoint("LEFT", itemIconBtn, "RIGHT", 10, 0)
  detailLinkFS:SetPoint("RIGHT", detailHeader, "RIGHT", -4, 0)
  detailLinkFS:SetJustifyH("LEFT")
  detailLinkFS:SetJustifyV("MIDDLE")
  detailLinkFS:SetWordWrap(true)
  -- if detailLinkFS.SetHyperlinksEnabled then
  --   detailLinkFS:SetHyperlinksEnabled(true)
  -- end
  UI.detailLinkFS = detailLinkFS

  local detailScroll = CreateFrame("ScrollFrame", "ItemDetailScroll", f, "ScrollFrameTemplate")
  detailScroll:SetPoint("TOPLEFT", detailHeader, "BOTTOMLEFT", 0, -8)
  if detailScroll.ScrollBar then
    local scrollBarWidth = detailScroll.ScrollBar:GetWidth()
    detailScroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(MARGIN_R + scrollBarWidth), DETAIL_BOTTOM_CLOSED)
    detailScroll.ScrollBar:SetPoint("TOPLEFT", detailScroll, "TOPRIGHT", -2, 0)
  else
    detailScroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -MARGIN_R, DETAIL_BOTTOM_CLOSED)
  end
  -- detailScroll.ScrollBar:SetHeight(detailScroll:GetHeight())
  UI.detailScroll = detailScroll

  local detailScrollChild = CreateFrame("Frame", "ScrollChild", detailScroll)
  detailScrollChild:SetWidth(detailScroll:GetWidth() - detailScroll.ScrollBar:GetWidth())
  detailScrollChild:SetHeight(1)
  detailScroll:SetScrollChild(detailScrollChild)
  -- detailScroll:SetScript("OnSizeChanged", function()
  --   syncDetailBodyHeight()
  -- end)
  UI.detailScrollChild = detailScrollChild

  local needsTitle = detailScrollChild:CreateFontString("NeedsTitleString", "OVERLAY", "GameFontHighlightLarge")
  needsTitle:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 4, 0)
  needsTitle:SetJustifyH("LEFT")
  needsTitle:SetJustifyV("TOP")
  needsTitle:SetWidth(280 - 4 - textInset)
  UI.needsTitle = needsTitle

  local needsListContainer = CreateFrame("Frame", "NeedsListFrame", detailScrollChild)
  needsListContainer:SetPoint("TOPLEFT", needsTitle, "BOTTOMLEFT", textInset, -4)
  needsListContainer:SetWidth(detailScrollChild:GetWidth())
  needsListContainer:SetHeight(1)
  needsListContainer:Hide()
  UI.needsListContainer = needsListContainer

  local hasTitle = detailScrollChild:CreateFontString("HasTitleString", "OVERLAY", "GameFontHighlightLarge")
  hasTitle:SetPoint("TOPLEFT", needsListContainer, "BOTTOMLEFT", -textInset, -8)
  hasTitle:SetJustifyH("LEFT")
  hasTitle:SetJustifyV("TOP")
  hasTitle:SetWidth(280 - 4 - textInset)
  UI.hasTitle = hasTitle

  local hasText = detailScrollChild:CreateFontString("HasTitleString", "OVERLAY", "GameFontHighlight")
  hasText:SetPoint("TOPLEFT", hasTitle, "BOTTOMLEFT", textInset, -4)
  hasText:SetJustifyH("LEFT")
  hasText:SetJustifyV("TOP")
  hasText:SetWidth(280 - 4 - textInset)
  hasText:SetWordWrap(true)
  UI.hasText = hasText

  local toggleImportBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  toggleImportBtn:SetSize(140, 22)
  toggleImportBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", CONTENT_X, MARGIN_L)
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
  UI.rebuildItemList()
  UI.renderSelectedItem()
  f:Hide()
end

function UI.toggle()
  if not isInRequiredGuild() then
    safeChatPrint(string.format("Disabled: only available to members of guild '%s'.",
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
