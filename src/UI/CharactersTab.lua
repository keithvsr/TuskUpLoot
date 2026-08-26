-- Characters tab: left-rail character list + gear set detail panel.

local _, TUL = ...

local UI = TUL.UI
local Util = UI.Util
local C = UI.Constants

UI.collapsedGearSets = UI.collapsedGearSets or {}

local CHAR_DRAG_THRESHOLD = 5

local function getPopupEditBox(popup)
  if not popup then
    return nil
  end
  if popup.editBox then
    return popup.editBox
  end
  local frameName = popup.GetName and popup:GetName()
  if frameName then
    return _G[frameName .. "EditBox"]
  end
  return nil
end

local function trimDisplayName(name)
  if type(name) ~= "string" then
    return ""
  end
  return name:gsub("^%s+", ""):gsub("%s+$", "")
end

local function applyCharacterRename(popup, data)
  data = data or (popup and popup.data)
  if not data or not data.characterKey then
    return false
  end

  local editBox = getPopupEditBox(popup)
  local newName = trimDisplayName(editBox and editBox:GetText() or "")
  if newName == "" then
    Util.safeChatPrint("Name cannot be empty.")
    return false
  end

  local DB = TUL.DB
  if DB and DB.renameCharacter(data.characterKey, newName) then
    UI.renderCharacterPanel()
    UI.rebuildCharacterList()
    return true
  end
  return false
end

StaticPopupDialogs["TUSKUPLOOT_REMOVE_CHARACTER"] = {
  text = "Remove %s and all gear sets?",
  button1 = YES,
  button2 = NO,
  OnAccept = function(self)
    local data = self.data
    if not data or not data.characterKey then
      return
    end
    local DB = TUL.DB
    if DB and DB.removeCharacter(data.characterKey) then
      if UI.selectedCharacterKey == data.characterKey then
        UI.setSelectedCharacter(nil)
      end
      UI.rebuildCharacterList()
      UI.renderCharacterPanel()
      if UI.rebuildItemList then
        UI.rebuildItemList()
      end
      if UI.activeTab == "raids" and UI.renderEncounterLootPanel then
        UI.renderEncounterLootPanel()
      end
    end
  end,
  timeout = 0,
  whileDead = 1,
  hideOnEscape = 1,
  preferredIndex = 3,
}

StaticPopupDialogs["TUSKUPLOOT_RENAME_CHARACTER"] = {
  text = "Enter display name for %s:",
  button1 = OKAY,
  button2 = CANCEL,
  hasEditBox = 1,
  maxLetters = 32,
  OnAccept = function(self, data)
    applyCharacterRename(self, data)
  end,
  EditBoxOnEnterPressed = function(self, data)
    local parent = self:GetParent()
    if applyCharacterRename(parent, data) then
      parent:Hide()
    end
  end,
  OnShow = function(self, data)
    data = data or self.data
    local editBox = getPopupEditBox(self)
    if editBox and data and data.currentName then
      editBox:SetText(data.currentName)
      editBox:HighlightText()
      editBox:SetFocus()
    end
  end,
  timeout = 0,
  whileDead = 1,
  hideOnEscape = 1,
  preferredIndex = 3,
}

local function isGearSetCollapsed(characterKey, gearSetKey)
  local byChar = UI.collapsedGearSets[characterKey]
  return byChar and byChar[gearSetKey]
end

local function toggleGearSetCollapsed(characterKey, gearSetKey)
  UI.collapsedGearSets[characterKey] = UI.collapsedGearSets[characterKey] or {}
  local byChar = UI.collapsedGearSets[characterKey]
  byChar[gearSetKey] = not byChar[gearSetKey]
end

local function gearSetCollapsePrefix(characterKey, gearSetKey)
  if isGearSetCollapsed(characterKey, gearSetKey) then
    return "[+] "
  end
  return "[-] "
end

local function bindCharacterActionButtons(characterKey, character)
  if UI.charRemoveBtn then
    UI.charRemoveBtn:Show()
    UI.charRemoveBtn:SetScript("OnClick", function()
      StaticPopup_Show("TUSKUPLOOT_REMOVE_CHARACTER",
        character.name or characterKey, nil, { characterKey = characterKey })
    end)
  end
  if UI.charRenameBtn then
    UI.charRenameBtn:Show()
    UI.charRenameBtn:SetScript("OnClick", function()
      StaticPopup_Show("TUSKUPLOOT_RENAME_CHARACTER",
        character.name or characterKey, nil, {
          characterKey = characterKey,
          currentName = character.name or characterKey,
        })
    end)
  end
end

local function hideCharacterActionButtons()
  if UI.charRemoveBtn then
    UI.charRemoveBtn:Hide()
    UI.charRemoveBtn:SetScript("OnClick", nil)
  end
  if UI.charRenameBtn then
    UI.charRenameBtn:Hide()
    UI.charRenameBtn:SetScript("OnClick", nil)
  end
end

local function clearCharListDragState(container)
  if not container then
    return
  end
  if container.charListDragBtn then
    container.charListDragBtn:SetScript("OnUpdate", nil)
    container.charListDragBtn = nil
  end
  Util.clearCharListDragVisuals(container)
end

local function updateCharListDragVisuals(container, dragBtn, dropIndex)
  if not dragBtn then
    Util.clearCharListDragVisuals(container)
    return
  end
  Util.setCharListButtonDragged(dragBtn, true)
  Util.applyCharListDropIndicator(container, dragBtn.sortIndex, dropIndex)
end

local function bindCharacterListButton(btn, container, key, sortIndex, isSelected)
  btn.characterKey = key
  btn.sortIndex = sortIndex

  local manualDragEnabled = (UI.charListSortBy == "manual") and (Util.filterNeedle() == "")

  if not manualDragEnabled then
    btn:SetScript("OnMouseDown", nil)
    btn:SetScript("OnMouseUp", nil)
    btn:SetScript("OnUpdate", nil)
    btn:SetScript("OnClick", function()
      if UI.selectedCharacterKey == key then
        UI.setSelectedCharacter(nil)
      else
        UI.setSelectedCharacter(key)
      end
    end)
    return
  end

  btn:SetScript("OnClick", nil)

  btn:SetScript("OnMouseDown", function(self, button)
    if button ~= "LeftButton" then
      return
    end
    clearCharListDragState(container)
    container.charListDragBtn = self
    self.dragStartY = select(2, GetCursorPosition())
    self.dragActive = false
    self.dragKey = key
    self.wasSelected = isSelected

    self:SetScript("OnUpdate", function(s)
      if not s.dragStartY then
        return
      end
      local _, cy = GetCursorPosition()
      local scale = s:GetEffectiveScale()
      if scale == 0 then
        return
      end

      if not s.dragActive then
        if math.abs(cy - s.dragStartY) <= CHAR_DRAG_THRESHOLD * scale then
          return
        end
        s.dragActive = true
      end

      updateCharListDragVisuals(container, s, Util.getCharListDropIndex(container, cy))
    end)
  end)

  btn:SetScript("OnMouseUp", function(self, button)
    if button ~= "LeftButton" then
      return
    end

    local dragActive = self.dragActive
    local dragKey = self.dragKey
    local wasSelected = self.wasSelected
    local dropIndex = dragActive and Util.getCharListDropIndex(container, select(2, GetCursorPosition()))

    self:SetScript("OnUpdate", nil)
    self.dragStartY = nil
    self.dragActive = nil
    self.dragKey = nil
    self.wasSelected = nil
    container.charListDragBtn = nil
    Util.clearCharListDragVisuals(container)

    if dragActive and dragKey and dropIndex and TUL.DB then
      TUL.DB.moveCharacterInManualSort(dragKey, dropIndex)
      UI.rebuildCharacterList()
      return
    end

    if wasSelected then
      UI.setSelectedCharacter(nil)
    else
      UI.setSelectedCharacter(key)
    end
  end)
end

local function refreshAfterDataChange()
  if UI.rebuildItemList then
    UI.rebuildItemList()
  end
  if UI.activeTab == "raids" and UI.renderEncounterLootPanel then
    UI.renderEncounterLootPanel()
  end
end

local function clearCharGearContainer()
  local container = UI.charGearContainer
  if not container then
    return
  end

  if container.headers then
    for _, h in ipairs(container.headers) do
      if h then
        h:Hide()
      end
    end
  end
  if container.headerRows then
    for _, row in ipairs(container.headerRows) do
      if row then
        row:Hide()
      end
    end
  end
  if container.gearItemRows then
    for _, row in ipairs(container.gearItemRows) do
      if row then
        row:Hide()
      end
    end
  end
  if container.buttons then
    for _, b in ipairs(container.buttons) do
      if b then
        b:Hide()
      end
    end
  end
  container:SetHeight(1)
end

local function setCharacterSummary(text)
  if UI.charSummaryFS then
    UI.charSummaryFS:SetText(text or "")
  end
end

local function setScrollContentHeight(contentHeight)
  if UI.detailScrollChild then
    UI.detailScrollChild:SetHeight(math.max(1, contentHeight + 8))
  end
end

function UI.renderCharacterPanel()
  if not UI.charSummaryFS then
    return
  end

  if UI.encounterLootContainer then
    UI.encounterLootContainer:Hide()
  end
  if UI.needsTitle then UI.needsTitle:Hide() end
  if UI.needsListContainer then UI.needsListContainer:Hide() end
  if UI.hasTitle then UI.hasTitle:Hide() end
  if UI.hasText then UI.hasText:Hide() end
  if UI.detailBackBtn then UI.detailBackBtn:Hide() end
  if UI.itemIconBtn then UI.itemIconBtn:Hide() end

  if UI.charInfoHeader then
    UI.charInfoHeader:Show()
  end
  UI.charSummaryFS:Show()
  if UI.charGearContainer then
    UI.charGearContainer:Show()
  end

  Util.layoutDetailScrollForTab("characters")

  local DB = TUL.DB
  if not DB then
    setCharacterSummary("TuskUpLoot: DB module not loaded.")
    clearCharGearContainer()
    setScrollContentHeight(0)
    return
  end

  if not TUL.dbInitialized then
    DB.init()
  end

  local db = _G.TuskUpLootDB
  if not db or not db.characters then
    setCharacterSummary("No saved data yet.")
    clearCharGearContainer()
    setScrollContentHeight(0)
    return
  end

  local selectedKey = UI.selectedCharacterKey
  local character = selectedKey and db.characters[selectedKey]

  if character then
    setCharacterSummary(Util.formatCharacterSummaryLine(character, selectedKey))
    bindCharacterActionButtons(selectedKey, character)

    local container = UI.charGearContainer
    if not container then
      setScrollContentHeight(0)
      return
    end

    clearCharGearContainer()
    container.headers = container.headers or {}
    container.headerRows = container.headerRows or {}
    container.gearItemRows = container.gearItemRows or {}

    local headerIndex = 0
    local gearRowIndex = 0
    local y = 0
    local btnHeight = C.ROW_HEIGHT
    local sectionGap = 4

    local orderedSets = DB.characterGearSets(selectedKey)
    if not orderedSets or #orderedSets == 0 then
      headerIndex = 1
      local hdr = container.headers[headerIndex]
      if not hdr then
        hdr = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        container.headers[headerIndex] = hdr
      end
      hdr:ClearAllPoints()
      hdr:SetPoint("TOPLEFT", container, "TOPLEFT", 4, -y)
      hdr:SetWidth(container:GetWidth() - 8)
      hdr:SetJustifyH("LEFT")
      hdr:SetText("(No gear sets stored for this character.)")
      hdr:Show()
      y = y + (hdr:GetStringHeight() or 14)
    else
      for _, row in ipairs(orderedSets) do
        local gs = row.gearSet
        if gs then
          headerIndex = headerIndex + 1
          local headerRow = container.headerRows[headerIndex]
          if not headerRow then
            headerRow = CreateFrame("Frame", nil, container)
            headerRow:SetHeight(btnHeight)
            headerRow.label = headerRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            headerRow.label:SetPoint("LEFT", 4, 0)
            headerRow.label:SetJustifyH("LEFT")
            container.headerRows[headerIndex] = headerRow
          end
          if not headerRow.removeBtn then
            headerRow.removeBtn = CreateFrame("Button", nil, headerRow, "UIPanelButtonTemplate")
            headerRow.removeBtn:SetSize(54, 16)
            headerRow.removeBtn:SetText("Remove")
            local removeFont = headerRow.removeBtn.GetFontString and headerRow.removeBtn:GetFontString()
            if removeFont and removeFont.SetFontObject then
              removeFont:SetFontObject(ChatFontSmall)
            end
          end
          if not headerRow.pushBtn then
            headerRow.pushBtn = CreateFrame("Button", nil, headerRow, "UIPanelButtonTemplate")
            headerRow.pushBtn:SetSize(44, 16)
            headerRow.pushBtn:SetText("Push")
            local pushFont = headerRow.pushBtn.GetFontString and headerRow.pushBtn:GetFontString()
            if pushFont and pushFont.SetFontObject then
              pushFont:SetFontObject(ChatFontSmall)
            end
          end
          headerRow.removeBtn:SetPoint("RIGHT", headerRow, "RIGHT", -2, 0)
          headerRow.pushBtn:SetPoint("RIGHT", headerRow.removeBtn, "LEFT", -2, 0)
          headerRow.pushBtn:Show()
          headerRow:ClearAllPoints()
          headerRow:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y)
          headerRow:SetPoint("RIGHT", container, "RIGHT", 0, 0)
          headerRow.label:SetPoint("RIGHT", headerRow.pushBtn, "LEFT", -4, 0)
          local gsKeyCapture = row.key
          local charKeyCapture = selectedKey
          headerRow.label:SetText(gearSetCollapsePrefix(charKeyCapture, gsKeyCapture)
            .. string.format("%s (phase %s)",
              gs.name or row.key, tostring(gs.phase or "?")))
          if not headerRow.toggleBtn then
            headerRow.toggleBtn = CreateFrame("Button", nil, headerRow)
            headerRow.toggleBtn:SetPoint("TOPLEFT", headerRow.label, "TOPLEFT", 0, 0)
            headerRow.toggleBtn:SetPoint("BOTTOMRIGHT", headerRow.label, "BOTTOMRIGHT", 0, 0)
          end
          headerRow.toggleBtn:SetScript("OnClick", function()
            toggleGearSetCollapsed(charKeyCapture, gsKeyCapture)
            UI.renderCharacterPanel()
          end)
          headerRow.removeBtn:SetScript("OnClick", function()
            if DB.removeGearSet(selectedKey, gsKeyCapture) then
              UI.renderCharacterPanel()
              UI.rebuildCharacterList()
              refreshAfterDataChange()
            end
          end)
          headerRow.pushBtn:SetScript("OnClick", function()
            if TUL.Sync and TUL.Sync.openPushGearSetPicker then
              TUL.Sync.openPushGearSetPicker(selectedKey, gsKeyCapture)
            end
          end)
          headerRow:Show()
          y = y + btnHeight + sectionGap

          local collapsed = isGearSetCollapsed(charKeyCapture, gsKeyCapture)
          for _, entry in ipairs(Util.gearSetEntriesInDisplayOrder(gs.items)) do
            local id = entry.itemId
            gearRowIndex = gearRowIndex + 1
            local gearRow = Util.getOrCreateCharGearItemRow(
              container, container.gearItemRows, gearRowIndex, btnHeight)
            gearRow:ClearAllPoints()
            gearRow:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y)
            gearRow:SetPoint("RIGHT", container, "RIGHT", 0, 0)
            gearRow:SetHeight(btnHeight)

            gearRow.slotFS:SetText("|cff888888" .. entry.slotLabel .. "|r")

            local meta = db.items and db.items[id]
            local itemLine = Util.formatItemLine(id, (meta and meta.name) or nil)
            gearRow.itemText:SetText(itemLine)

            local charMeta = meta and meta.characters and meta.characters[selectedKey]
            local acquired = charMeta and charMeta.acquired or false
            gearRow.acquiredCheck:SetChecked(acquired)

            local idCapture = id
            local keyCapture = selectedKey
            gearRow.itemBtn:SetScript("OnClick", function()
              UI.openItemDetail(idCapture, nil)
            end)
            gearRow.acquiredCheck:SetScript("OnClick", function(self)
              DB.setItemAcquired(idCapture, keyCapture, self:GetChecked())
              -- if TuskUpLoot.Net and TuskUpLoot.Net.broadcastItemAcquired then
              --   TuskUpLoot.Net.broadcastItemAcquired(idCapture, keyCapture, self:GetChecked())
              -- end
              UI.renderCharacterPanel()
              refreshAfterDataChange()
            end)

            if collapsed then
              gearRow:Hide()
            else
              gearRow:Show()
              y = y + btnHeight
            end
          end
          if not collapsed then
            y = y + sectionGap
          end
        end
      end
    end

    container:SetHeight(math.max(1, y))
    setScrollContentHeight(y)
    return
  end

  hideCharacterActionButtons()

  clearCharGearContainer()

  local anyChars = false
  for _ in pairs(db.characters) do
    anyChars = true
    break
  end

  if not anyChars then
    setCharacterSummary("No character lists imported.")
  else
    setCharacterSummary("Select a character from the list.")
  end

  local container = UI.charGearContainer
  if container then
    container.headers = container.headers or {}
    local hdr = container.headers[1]
    if not hdr then
      hdr = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      container.headers[1] = hdr
    end
    hdr:ClearAllPoints()
    hdr:SetPoint("TOPLEFT", container, "TOPLEFT", 4, 0)
    hdr:SetWidth(container:GetWidth() - 8)
    hdr:SetJustifyH("LEFT")
    if not anyChars then
      hdr:SetText('Use Import JSON at the bottom to paste a sixtyupgrades export.')
    else
      hdr:SetText("Gear sets for the selected character appear here.")
    end
    hdr:Show()
    local h = hdr:GetStringHeight() or 14
    container:SetHeight(math.max(1, h))
    setScrollContentHeight(h)
  else
    setScrollContentHeight(0)
  end
end

function UI.renderSelectedCharacter()
  UI.renderCharacterPanel()
end

function UI.resetManualCharacterOrder()
  if TUL.DB then
    TUL.DB.resetManualSortToDefault()
  end
  UI.rebuildCharacterList()
end

function UI.setCharListSortBy(sortBy)
  if sortBy ~= "name" and sortBy ~= "class" and sortBy ~= "manual" and sortBy ~= "recent" then
    return
  end
  if sortBy == "manual" then
    UI.charListSortBy = "manual"
    if TUL.DB then
      TUL.DB.ensureManualSortList()
    end
  elseif UI.charListSortBy == sortBy then
    if sortBy == "name" then
      UI.charListSortNameDescending = not UI.charListSortNameDescending
    else
      UI.charListSortClassDescending = not UI.charListSortClassDescending
    end
  else
    UI.charListSortBy = sortBy
  end
  UI.updateCharSortButtonStyles()
  if UI.updateCharManualOrderControls then
    UI.updateCharManualOrderControls()
  end
  UI.rebuildCharacterList()
end

function UI.rebuildCharacterList()
  if not UI.charListContainer then
    return
  end

  local DB = TUL.DB
  if not DB then
    return
  end

  local container = UI.charListContainer
  clearCharListDragState(container)
  if container.buttons then
    for _, b in ipairs(container.buttons) do
      b:Hide()
    end
  end
  container.buttons = container.buttons or {}

  local rows = DB.characterNamesAndClasses() or {}
  local manualSortKeys
  if (UI.charListSortBy or "recent") == "manual" then
    manualSortKeys = DB.ensureManualSortList()
  end
  Util.sortCharacterRows(rows, UI.charListSortBy or "recent", UI.getCharListSortDescending(), manualSortKeys)
  local needle = Util.filterNeedle()
  local y = -6
  local btnHeight = 18
  local i = 0

  for j = 1, #rows do
    local row = rows[j]
    local key = row.key
    local label = row.name or key
    local class = row.class or "PRIEST"
    local haystack = string.lower(string.format("%s %s", label, row.class or ""))
    if needle == "" or string.find(haystack, needle, 1, true) then
      i = i + 1
      local btn = Util.getOrCreateListButton(container, container.buttons, i, btnHeight)
      btn:ClearAllPoints()
      btn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, y)
      btn:SetPoint("RIGHT", container, "RIGHT", 0, 0)


      local classColor = C_ClassColor.GetClassColor(class)
      local isSelected = (UI.selectedCharacterKey == key)
      bindCharacterListButton(btn, container, key, j, isSelected)

      local prefix = (isSelected and "|c0cffd200» |r|c" or "  |c") .. classColor:GenerateHexColor()
      local suffix = "|r" .. (isSelected and "|c0cffd200  «|r" or "")
      btn.text:SetText(prefix .. label .. suffix)
      btn:Show()

      y = y - btnHeight
    end
  end

  container:SetHeight(math.max(1, (i * btnHeight) + 12))
end

function UI.setSelectedCharacter(key)
  UI.selectedCharacterKey = key
  UI.renderCharacterPanel()
  UI.rebuildCharacterList()
end
