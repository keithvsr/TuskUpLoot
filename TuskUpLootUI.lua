-- Handles UI creation + rendering for the addon.

TuskUpLoot.UI = TuskUpLoot.UI or {}
local UI = TuskUpLoot.UI

UI.importPanelOpen = UI.importPanelOpen or false
UI.updateAccumulator = UI.updateAccumulator or 0
UI.updateIntervalSeconds = UI.updateIntervalSeconds or 0.5

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

local function formatItemLine(item, acquired)
  if not item or not item.id then
    return "- (invalid item)"
  end

  local itemName, itemLink
  if GetItemInfo then
    itemName, itemLink = GetItemInfo(item.id)
  end

  local display = itemLink or (item.name and ("[" .. item.name .. "]")) or ("[Item " .. tostring(item.id) .. "]")
  local slotPrefix = item.slot and (item.slot .. ": ") or ""
  local check = acquired and "[x]" or "[ ]"
  return string.format("- %s %s%s", check, slotPrefix, display)
end

function UI:ApplyImportPanelState()
  if not self.frame then
    return
  end

  local open = self.importPanelOpen

  if self.toggleImportBtn then
    self.toggleImportBtn:SetText(open and "Close Import" or "Import JSON")
  end

  if self.importLabel then
    if open then
      self.importLabel:Show()
    else
      self.importLabel:Hide()
    end
  end

  if self.inputScroll then
    if open then
      self.inputScroll:Show()
    else
      self.inputScroll:Hide()
    end
  end

  if self.importBtn then
    if open then
      self.importBtn:Show()
    else
      self.importBtn:Hide()
    end
  end

  if self.clearBtn then
    if open then
      self.clearBtn:Show()
    else
      self.clearBtn:Hide()
    end
  end

  if self.text then
    self.text:ClearAllPoints()
    if open then
      self.text:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 200, -315)
    else
      self.text:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 200, -92)
    end
    self.text:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", -22, 22)
  end
end

function UI:RenderSelectedCharacter()
  if not self.text then
    return
  end

  local DB = TuskUpLoot.DB
  if not DB then
    self.text:SetText("TuskUpLoot: DB module not loaded.")
    return
  end

  DB.init()

  local db = _G.TuskUpLootDB
  if not db or not db.characters then
    self.text:SetText("No saved data yet.")
    return
  end

  local selectedKey = self.selectedCharacterKey
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
      self.text:SetText(table.concat(lines, "\n"))
      return
    end

    local lineBudget = 200
    for _, row in ipairs(orderedSets) do
      local gs = row.gearSet
      if gs then
        lines[#lines + 1] = string.format("--- %s (phase %s) ---", gs.name or row.key, tostring(gs.phase or "?"))
        local itemMap = gs.items or {}
        local itemIds = {}
        for itemId in pairs(itemMap) do
          itemIds[#itemIds + 1] = itemId
        end
        table.sort(itemIds, function(a, b)
          return (tonumber(a) or 0) < (tonumber(b) or 0)
        end)
        for _, itemId in ipairs(itemIds) do
          if #lines >= lineBudget then
            lines[#lines + 1] = "... (truncated)"
            break
          end
          local meta = db.items and db.items[itemId]
          local acquired = itemMap[itemId]
          lines[#lines + 1] = formatItemLine(meta or { id = itemId, name = nil, slot = nil }, acquired)
        end
        lines[#lines + 1] = ""
      end
      if #lines >= lineBudget then
        break
      end
    end

    self.text:SetText(table.concat(lines, "\n"))
    return
  end

  local anyChars = false
  for _ in pairs(db.characters) do
    anyChars = true
    break
  end

  if not anyChars then
    self.text:SetText('No character lists imported.\nClick "Import JSON" to paste a sixtyupgrades export.')
  else
    self.text:SetText("Select a character from the list to view their gear sets.")
  end
end

function UI:RebuildCharacterList()
  if not self.charListContainer then
    return
  end

  local DB = TuskUpLoot.DB
  if not DB then
    return
  end

  DB.init()

  local container = self.charListContainer
  if container.buttons then
    for _, b in ipairs(container.buttons) do
      b:Hide()
    end
  end
  container.buttons = container.buttons or {}

  local rows = DB.characterNamesAndClasses() or {}
  local y = -6
  local btnHeight = 18

  for i = 1, #rows do
    local row = rows[i]
    local key = row.key
    local label = row.name or key

    local btn = container.buttons[i]
    if not btn then
      btn = CreateFrame("Button", nil, container)
      btn:SetHeight(btnHeight)
      btn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, y)
      btn:SetPoint("RIGHT", container, "RIGHT", 0, 0)
      btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      btn.text:SetPoint("LEFT", 4, 0)
      btn.text:SetJustifyH("LEFT")
      container.buttons[i] = btn
    else
      btn:ClearAllPoints()
      btn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, y)
      btn:SetPoint("RIGHT", container, "RIGHT", 0, 0)
    end

    btn:SetScript("OnClick", function()
      UI:SetSelectedCharacter(key)
    end)

    local isSelected = (self.selectedCharacterKey == key)
    btn.text:SetText((isSelected and "|cffffff00" or "") .. label .. (isSelected and "|r" or ""))
    btn:Show()

    y = y - btnHeight
  end

  container:SetHeight(math.max(1, (#rows * btnHeight) + 12))
end

function UI:SetSelectedCharacter(key)
  self.selectedCharacterKey = key
  self:RenderSelectedCharacter()
  self:RebuildCharacterList()
end

function UI:Refresh()
  self:ApplyImportPanelState()
  self:RenderSelectedCharacter()
end

function UI:EnsureFrame()
  if self.frame then
    return
  end

  local f = CreateFrame("Frame", "TuskUpLootMainFrame", UIParent, "UIPanelDialogTemplate")
  f:SetSize(560, 420)
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
    UI:Refresh()
    UI.updateAccumulator = 0
  end)
  f:SetScript("OnHide", function()
    UI.updateAccumulator = 0
  end)
  f:SetScript("OnUpdate", function(_, elapsed)
    UI.updateAccumulator = (UI.updateAccumulator or 0) + elapsed
    if UI.updateAccumulator >= (UI.updateIntervalSeconds or 0.5) then
      UI.updateAccumulator = 0
      UI:Refresh()
    end
  end)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:ClearAllPoints()
  title:SetPoint("TOP", f, "TOP", 0, -8)
  title:SetText(TuskUpLoot.addonName or "TuskUpLoot")

  local listBg = CreateFrame("Frame", nil, f)
  listBg:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -42)
  listBg:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 18)
  listBg:SetWidth(160)

  local listTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  listTitle:SetPoint("TOPLEFT", listBg, "TOPLEFT", 2, 14)
  listTitle:SetText("Characters")

  local listScroll = CreateFrame("ScrollFrame", nil, listBg, "UIPanelScrollFrameTemplate")
  listScroll:SetPoint("TOPLEFT", listBg, "TOPLEFT", 0, -4)
  listScroll:SetPoint("BOTTOMRIGHT", listBg, "BOTTOMRIGHT", -26, 0)

  local listContainer = CreateFrame("Frame", nil, listScroll)
  listContainer:SetWidth(160)
  listContainer:SetHeight(1)
  listScroll:SetScrollChild(listContainer)

  self.charListContainer = listContainer
  self.charListScroll = listScroll

  local toggleImportBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  toggleImportBtn:SetSize(160, 22)
  toggleImportBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 200, -46)
  toggleImportBtn:SetText("Import JSON")
  toggleImportBtn:SetScript("OnClick", function()
    UI.importPanelOpen = not UI.importPanelOpen
    UI:ApplyImportPanelState()
  end)
  self.toggleImportBtn = toggleImportBtn

  local importLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  importLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 200, -74)
  importLabel:SetText("Paste sixtyupgrades JSON export")
  self.importLabel = importLabel

  local inputScroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  inputScroll:SetPoint("TOPLEFT", f, "TOPLEFT", 200, -94)
  inputScroll:SetSize(330, 170)

  local input = CreateFrame("EditBox", nil, inputScroll)
  input:SetMultiLine(true)
  input:SetAutoFocus(false)
  input:SetFontObject(ChatFontNormal)
  input:SetWidth(300)
  input:SetHeight(170)
  input:SetScript("OnEscapePressed", function(selfEdit)
    selfEdit:ClearFocus()
  end)
  inputScroll:SetScrollChild(input)
  self.inputScroll = inputScroll
  self.input = input

  local importBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  importBtn:SetSize(90, 22)
  importBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 200, -278)
  importBtn:SetText("Import")
  importBtn:SetScript("OnClick", function()
    local txt = input:GetText() or ""
    txt = txt:gsub("^%s+", ""):gsub("%s+$", "")
    if txt == "" then
      safeChatPrint("Paste a JSON export first.")
      return
    end

    local payload, err, characterKey
    if TuskUpLoot.Importer then
      payload, err, characterKey = TuskUpLoot.Importer.import(txt)
    end
    if not payload then
      safeChatPrint("Import failed: " .. tostring(err or "unknown"))
      return
    end

    local name = payload.character and payload.character.name or characterKey
    safeChatPrint(string.format("Imported %s.", tostring(name or "character")))
    if characterKey then
      UI:SetSelectedCharacter(characterKey)
    end
    input:SetText("")
  end)
  self.importBtn = importBtn

  local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  clearBtn:SetSize(90, 22)
  clearBtn:SetPoint("LEFT", importBtn, "RIGHT", 8, 0)
  clearBtn:SetText("Clear")
  clearBtn:SetScript("OnClick", function()
    input:SetText("")
    input:ClearFocus()
  end)
  self.clearBtn = clearBtn

  local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  text:ClearAllPoints()
  text:SetPoint("TOPLEFT", f, "TOPLEFT", 200, -92)
  text:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -22, 22)
  text:SetJustifyH("LEFT")
  text:SetJustifyV("TOP")
  self.text = text

  local close = _G["TuskUpLootMainFrameCloseButton"] or _G["TuskUpLootMainFrameClose"]
  if close then
    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
  end

  self.frame = f
  TuskUpLoot.frame = f

  self:ApplyImportPanelState()
  self:RebuildCharacterList()
  self:RenderSelectedCharacter()
  f:Hide()
end

function UI:Toggle()
  if not isInRequiredGuild() then
    safeChatPrint(string.format("Disabled: only available to members of guild '%s'.",
      TuskUpLoot.requiredGuildName or "Tusk Up"))
    return
  end

  self:EnsureFrame()
  if self.frame:IsShown() then
    self.frame:Hide()
  else
    self.frame:Show()
  end
end
