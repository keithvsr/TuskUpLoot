-- Characters tab: left-rail character list + gear set detail panel.

local UI = TuskUpLoot.UI
local Util = UI.Util
local C = UI.Constants

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
  if container.buttons then
    for _, b in ipairs(container.buttons) do
      if b then
        b:Hide()
      end
    end
  end
  container:SetHeight(1)
end

function UI.renderCharacterPanel()
  if not UI.charDetailFS then
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

  UI.charDetailFS:Show()
  if UI.charGearContainer then
    UI.charGearContainer:Show()
  end

  local DB = TuskUpLoot.DB
  if not DB then
    UI.charDetailFS:SetText("TuskUpLoot: DB module not loaded.")
    clearCharGearContainer()
    return
  end

  if not TuskUpLoot.dbInitialized then
    DB.init()
  end

  local db = _G.TuskUpLootDB
  if not db or not db.characters then
    UI.charDetailFS:SetText("No saved data yet.")
    clearCharGearContainer()
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

    UI.charDetailFS:SetText(table.concat(lines, "\n"))

    local container = UI.charGearContainer
    if not container then
      UI.detailScrollChild:SetHeight(math.max(1, UI.charDetailFS:GetStringHeight() + 8))
      return
    end

    clearCharGearContainer()
    container.headers = container.headers or {}
    container.buttons = container.buttons or {}

    local headerIndex = 0
    local btnIndex = 0
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
          local hdr = container.headers[headerIndex]
          if not hdr then
            hdr = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            container.headers[headerIndex] = hdr
          end
          hdr:ClearAllPoints()
          hdr:SetPoint("TOPLEFT", container, "TOPLEFT", 4, -y)
          hdr:SetWidth(container:GetWidth() - 8)
          hdr:SetJustifyH("LEFT")
          hdr:SetText(string.format("--- %s (phase %s) ---", gs.name or row.key, tostring(gs.phase or "?")))
          hdr:Show()
          y = y + (hdr:GetStringHeight() or 14) + sectionGap

          for _, id in ipairs(Util.gearSetItemIds(gs.items)) do
            btnIndex = btnIndex + 1
            local btn = Util.getOrCreateListButton(container, container.buttons, btnIndex, btnHeight)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", container, "TOPLEFT", 8, -y)
            btn:SetPoint("RIGHT", container, "RIGHT", 0, 0)

            local meta = db.items and db.items[id]
            local itemLine = Util.formatItemLine(meta or {
              id = id,
              name = TuskUpLoot.Data and TuskUpLoot.Data.getItemDisplayName(id),
            })
            btn.text:SetText(itemLine)

            local idCapture = id
            btn:SetScript("OnClick", function()
              UI.openItemDetail(idCapture, nil)
            end)
            btn:Show()
            y = y + btnHeight
          end
          y = y + sectionGap
        end
      end
    end

    container:SetHeight(math.max(1, y))
    local totalH = (UI.charDetailFS:GetStringHeight() or 0) + 4 + y + 8
    UI.detailScrollChild:SetHeight(math.max(1, totalH))
    return
  end

  clearCharGearContainer()

  local anyChars = false
  for _ in pairs(db.characters) do
    anyChars = true
    break
  end

  if not anyChars then
    UI.charDetailFS:SetText('No character lists imported.\nUse Import JSON at the bottom to paste a sixtyupgrades export.')
  else
    UI.charDetailFS:SetText("Select a character from the list to view their gear sets.")
  end
  UI.detailScrollChild:SetHeight(math.max(1, UI.charDetailFS:GetStringHeight() + 8))
end

function UI.renderSelectedCharacter()
  UI.renderCharacterPanel()
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
  local needle = Util.filterNeedle()
  local y = -6
  local btnHeight = 18
  local i = 0

  for j = 1, #rows do
    local row = rows[j]
    local key = row.key
    local label = row.name or key
    local haystack = string.lower(string.format("%s %s", label, row.class or ""))
    if needle == "" or string.find(haystack, needle, 1, true) then
      i = i + 1
      local btn = Util.getOrCreateListButton(container, container.buttons, i, btnHeight)
      btn:ClearAllPoints()
      btn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, y)
      btn:SetPoint("RIGHT", container, "RIGHT", 0, 0)

      btn:SetScript("OnClick", function()
        UI.setSelectedCharacter(key)
      end)

      local isSelected = (UI.selectedCharacterKey == key)
      btn.text:SetText((isSelected and "|cffffff00" or "") .. label .. (isSelected and "|r" or ""))
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
