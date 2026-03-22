-- Handles UI creation + rendering for the addon.

TuskUpLoot.UI = {}
local UI = TuskUpLoot.UI

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

local function formatItemLine(item)
  if not item or not item.id then
    return "- (invalid item)"
  end

  local itemName, itemLink
  if GetItemInfo then
    itemName, itemLink = GetItemInfo(item.id)
  end

  local display = itemLink or (item.name and ("[" .. item.name .. "]")) or ("[Item " .. tostring(item.id) .. "]")
  local slotPrefix = item.slot and (item.slot .. ": ") or ""
  return string.format("- %s%s", slotPrefix, display)
end

function TuskUpLoot:ApplyImportPanelState()
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

function TuskUpLoot.Frame:RenderSelectedCharacter()
  if not self.text then
    return
  end

  local DB = TuskUpLoot.DB
  if not DB then
    self.text:SetText("TuskUpLoot: DB module not loaded.")
    return
  end

  local imports = _G.TuskUpLootDB and _G.TuskUpLootDB.imports or {}
  local selected = self.selectedCharacterKey and imports[self.selectedCharacterKey]

  if selected then
    local lines = {
      "Imported wishlist:",
      string.format("Character: %s", selected.characterName or self.selectedCharacterKey),
      "",
    }

    if selected.items and #selected.items > 0 then
      for i = 1, #selected.items do
        lines[#lines + 1] = formatItemLine(selected.items[i])
        if i >= 120 then
          lines[#lines + 1] = string.format("... (%d more)", #selected.items - i)
          break
        end
      end
    else
      lines[#lines + 1] = "(No items found in import. Ensure you pasted the sixtyupgrades JSON export.)"
    end

    self.text:SetText(table.concat(lines, "\n"))
    return
  end

  -- Default view (no character selected / no imports yet)
  local anyImports = false
  for _ in pairs(imports) do
    anyImports = true
    break
  end

  if not anyImports then
    self.text:SetText('No character lists imported.\nClick "Import JSON" to paste a sixtyupgrades export.')
  else
    self.text:SetText("Select a character from the imports list to view their wishlist.")
  end
end

function TuskUpLoot.Frame:RebuildCharacterList()
  if not self.charListContainer then
    return
  end

  local DB = TuskUpLoot.DB
  if not DB then
    return
  end

  DB.ensure()

  local container = self.charListContainer
  if container.buttons then
    for _, b in ipairs(container.buttons) do
      b:Hide()
    end
  end
  container.buttons = container.buttons or {}

  local keys = DB.sortedImportKeys()
  local y = -6
  local btnHeight = 18

  for i = 1, #keys do
    local key = keys[i]
    local imp = _G.TuskUpLootDB.imports[key]
    local label = (imp and imp.characterName) or key

    local btn = container.buttons[i]
    if not btn then
      btn = CreateFrame("Button", nil, container)
      btn:SetHeight(btnHeight)
      btn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, y)
      btn:SetPoint("RIGHT", container, "RIGHT", 0, 0)
      btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      btn.text:SetPoint("LEFT", 4, 0)
      btn.text:SetJustifyH("LEFT")
      btn:SetScript("OnClick", function()
        TuskUpLoot:SetSelectedCharacter(key)
      end)
      container.buttons[i] = btn
    else
      btn:ClearAllPoints()
      btn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, y)
      btn:SetPoint("RIGHT", container, "RIGHT", 0, 0)
    end

    local isSelected = (self.selectedCharacterKey == key)
    btn.text:SetText((isSelected and "|cffffff00" or "") .. label .. (isSelected and "|r" or ""))
    btn:Show()

    y = y - btnHeight
  end

  container:SetHeight(math.max(1, (#keys * btnHeight) + 12))
end

function TuskUpLoot.Frame:SetSelectedCharacter(key)
  self.selectedCharacterKey = key
  self:RenderSelectedCharacter()
  self:RebuildCharacterList()
end

function TuskUpLoot.Frame:Refresh()
  self:ApplyImportPanelState()
  self:RenderSelectedCharacter()
end

function TuskUpLoot.Frame:EnsureFrame()
  if self.frame then
    return
  end

  local f = CreateFrame("Frame", "TuskUpLootMainFrame", UIParent, "UIPanelDialogTemplate")
  f:SetSize(560, 420)
  f:SetPoint("CENTER")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)

  -- Drag only from the title bar region so UI elements remain clickable.
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
    TuskUpLoot.Frame:Refresh()
    TuskUpLoot.Frame.updateAccumulator = 0
  end)
  f:SetScript("OnHide", function()
    TuskUpLoot.Frame.updateAccumulator = 0
  end)
  f:SetScript("OnUpdate", function(_, elapsed)
    TuskUpLoot.Frame.updateAccumulator = (TuskUpLoot.Frame.updateAccumulator or 0) + elapsed
    if TuskUpLoot.Frame.updateAccumulator >= (TuskUpLoot.Frame.updateIntervalSeconds or 0.5) then
      TuskUpLoot.Frame.updateAccumulator = 0
      TuskUpLoot.Frame:Refresh()
    end
  end)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:ClearAllPoints()
  title:SetPoint("TOP", f, "TOP", 0, -8)
  title:SetText(TuskUpLoot.addonName or "TuskUpLoot")

  -- Left panel: imported characters list
  local listBg = CreateFrame("Frame", nil, f)
  listBg:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -42)
  listBg:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 18)
  listBg:SetWidth(160)

  local listTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  listTitle:SetPoint("TOPLEFT", listBg, "TOPLEFT", 2, 14)
  listTitle:SetText("Imports")

  local listScroll = CreateFrame("ScrollFrame", nil, listBg, "UIPanelScrollFrameTemplate")
  listScroll:SetPoint("TOPLEFT", listBg, "TOPLEFT", 0, -4)
  listScroll:SetPoint("BOTTOMRIGHT", listBg, "BOTTOMRIGHT", -26, 0)

  local listContainer = CreateFrame("Frame", nil, listScroll)
  listContainer:SetWidth(160)
  listContainer:SetHeight(1)
  listScroll:SetScrollChild(listContainer)

  self.charListContainer = listContainer
  self.charListScroll = listScroll

  -- Right panel
  local toggleImportBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  toggleImportBtn:SetSize(160, 22)
  toggleImportBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 200, -46)
  toggleImportBtn:SetText("Import JSON")
  toggleImportBtn:SetScript("OnClick", function()
    TuskUpLoot.Frame.importPanelOpen = not TuskUpLoot.Frame.importPanelOpen
    TuskUpLoot.Frame:ApplyImportPanelState()
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

    local parsed, err = TuskUpLoot.Importer and TuskUpLoot.Importer.import(txt)
    if not parsed then
      safeChatPrint("Import failed: " .. tostring(err or "unknown"))
      return
    end

    local key, _ = TuskUpLoot.DB and TuskUpLoot.DB.upsertImport(parsed, txt)
    if not key then
      safeChatPrint("Import failed: could not save data.")
      return
    end

    safeChatPrint(string.format("Imported %s.", parsed.characterName or key))
    TuskUpLoot.Frame:SetSelectedCharacter(key)
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

  local close = _G["TuskUpLootMainFrameClose"]
  if close then
    close:ClearAllPoints()
    close:SetPoint("CENTER", f, "TOPRIGHT", -2, -2)
  end

  self.frame = f

  self:ApplyImportPanelState()
  self:RebuildCharacterList()
  self:RenderSelectedCharacter()
  f:Hide()
end

function TuskUpLoot.Frame:Toggle()
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
