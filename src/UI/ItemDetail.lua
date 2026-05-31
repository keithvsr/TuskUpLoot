-- Shared item detail panel (needs/has lists) used by Items and Raids tabs.

local UI = TuskUpLoot.UI
local Util = UI.Util
local C = UI.Constants

function UI.clearNeedsList()
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

local function clearNeedsList()
  UI.clearNeedsList()
end

local function renderNeedsList(needsRows, selectedItemId)
  local container = UI.needsListContainer
  if not container then
    return
  end

  local frames = UI.needsRowFrames or {}
  UI.needsRowFrames = frames

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

  if UI.activeTab ~= "items" then
    return
  end

  if UI.encounterLootContainer then
    UI.encounterLootContainer:Hide()
  end
  if UI.charDetailFS then
    UI.charDetailFS:Hide()
  end
  if UI.charGearContainer then
    UI.charGearContainer:Hide()
  end

  if UI.detailBackBtn then
    if UI.returnContext then
      UI.detailBackBtn:Show()
    else
      UI.detailBackBtn:Hide()
    end
  end

  local DB = TuskUpLoot.DB
  local selectedItemId = UI.selectedItemId
  local item = selectedItemId and DB and DB.getItem(selectedItemId)

  if not selectedItemId then
    if UI.itemIconBtn then
      UI.itemIconBtn:Hide()
    end
    if UI.detailBackBtn and UI.returnContext then
      UI.detailBackBtn:Show()
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
    UI.needsTitle:Show()
    UI.detailScrollChild:SetHeight(math.max(1, UI.needsTitle:GetStringHeight() + 8))
    return
  end

  if not item then
    if UI.itemIconBtn then
      Util.refreshItemIconButton(UI.itemIconBtn, selectedItemId)
      UI.itemIconBtn:Show()
    end
    local _, itemLink = C_Item.GetItemInfo(selectedItemId)
    if not itemLink and TuskUpLoot.Data and TuskUpLoot.Data.getItemDisplayName then
      local name = TuskUpLoot.Data.getItemDisplayName(selectedItemId)
      if name then
        itemLink = "|cffffffff[" .. name .. "]|r"
      end
    end
    UI.detailLinkFS:SetText(itemLink or ("|cffffffff[Item " .. tostring(selectedItemId) .. "]|r"))
    UI.needsTitle:SetText("No characters linked to this item in saved data.")
    clearNeedsList()
    UI.needsListContainer:Hide()
    UI.hasTitle:Hide()
    UI.hasText:Hide()
    UI.needsTitle:Show()
    UI.detailScrollChild:SetHeight(math.max(1,
      (UI.needsTitle:GetStringHeight() or 0) + (UI.detailLinkFS:GetStringHeight() or 0) + 12))
    return
  end

  UI.needsTitle:SetText("")
  UI.hasTitle:SetText("")
  UI.hasText:SetText("")
  clearNeedsList()
  UI.needsListContainer:Hide()
  UI.needsTitle:Hide()
  UI.hasTitle:Hide()
  UI.hasText:Hide()

  if UI.itemIconBtn then
    UI.itemIconBtn:Show()
    Util.refreshItemIconButton(UI.itemIconBtn, selectedItemId)
    UI.detailLinkFS:ClearAllPoints()
    UI.detailLinkFS:SetPoint("LEFT", UI.itemIconBtn, "RIGHT", 10, 0)
    UI.detailLinkFS:SetPoint("RIGHT", UI.detailHeader, "RIGHT", -60, 0)
  end

  local _, itemLink = C_Item.GetItemInfo(selectedItemId)

  if not itemLink and item.name then
    itemLink = "|cffffffff[" .. item.name .. "]|r"
  elseif not itemLink then
    itemLink = "|cffffffff[Item " .. tostring(selectedItemId) .. "]|r"
  end
  UI.detailLinkFS:SetText(itemLink)

  local rollup = DB.getItemRollup(selectedItemId)
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
    local needs = {}
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
      UI.hasTitle:SetPoint("TOPLEFT", UI.needsListContainer, "BOTTOMLEFT", -C.TEXT_INSET, -8)
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
end
