-- Raids tab: instance/encounter tree + encounter loot in right panel.

local UI = TuskUpLoot.UI
local Util = UI.Util
local C = UI.Constants

local function treePrefix(expanded)
  return expanded and "‹ " or "› "
end

local function clearPrefix(cleared)
  if cleared then
    return "|cff00ff00√|r "
  end
  return "• "
end

function UI.expandOnlyInstance(instanceId)
  for id in pairs(UI.expandedInstances) do
    UI.expandedInstances[id] = false
  end
  UI.expandedInstances[instanceId] = true
  UI.focusInstanceId = instanceId
end

local function raidReturnContext()
  if not UI.focusEncounterId then
    return nil
  end
  return {
    tab = "raids",
    focusEncounterId = UI.focusEncounterId,
  }
end

local function selectEncounter(encounterId)
  UI.focusEncounterId = encounterId
  if TuskUpLoot.Data and TuskUpLoot.Data.requestEncounterItemData then
    TuskUpLoot.Data.requestEncounterItemData(encounterId)
  end
  UI.rebuildRaidList()
  if UI.activeTab == "raids" then
    UI.renderEncounterLootPanel()
  end
end

local function focusEncounterLoot(encounterId)
  if not encounterId then
    return
  end
  selectEncounter(encounterId)
end

function UI.renderEncounterLootPanel()
  if UI.activeTab ~= "raids" then
    return
  end
  if not Util.isDetailReady() then
    return
  end

  if UI.itemIconBtn then
    UI.itemIconBtn:Hide()
  end
  if UI.detailLinkFS and UI.detailHeader then
    UI.detailLinkFS:ClearAllPoints()
    UI.detailLinkFS:SetPoint("LEFT", UI.detailHeader, "LEFT", 0, 0)
    UI.detailLinkFS:SetPoint("RIGHT", UI.detailHeader, "RIGHT", -4, 0)
  end
  if UI.needsTitle then UI.needsTitle:Hide() end
  if UI.needsListContainer then UI.needsListContainer:Hide() end
  if UI.hasTitle then UI.hasTitle:Hide() end
  if UI.hasText then UI.hasText:Hide() end
  if UI.charInfoHeader then UI.charInfoHeader:Hide() end
  if UI.charSummaryFS then UI.charSummaryFS:Hide() end
  if UI.charGearContainer then UI.charGearContainer:Hide() end
  if UI.detailBackBtn then UI.detailBackBtn:Hide() end

  local container = UI.encounterLootContainer
  if not container then
    return
  end

  local focusEnc = UI.focusEncounterId
  local Data = TuskUpLoot.Data

  if not focusEnc then
    if UI.detailLinkFS then
      UI.detailLinkFS:SetText("Select an encounter")
    end
    container:Hide()
    UI.detailScrollChild:SetHeight(8)
    return
  end

  local encounter = Data and Data.Encounters and Data.Encounters[focusEnc]
  if UI.detailLinkFS then
    UI.detailLinkFS:SetText(encounter and (encounter.name or ("Encounter " .. tostring(focusEnc))) or "")
  end

  local lootIds = {}
  if Data then
    local state = Util.getRaidState()
    if state.LastKilledBoss then
      lootIds = Data.getEncounterLootIdsForSource(focusEnc, "npc", state.LastKilledBoss)
      if not lootIds or #lootIds == 0 then
        lootIds = Data.getEncounterLootIds(focusEnc)
      end
    else
      lootIds = Data.getEncounterLootIds(focusEnc)
    end
  end
  lootIds = Util.filterVisibleItemIds(lootIds or {})

  local rows = container.rows or {}
  container.rows = rows
  for _, row in ipairs(rows) do
    row:Hide()
  end

  if #lootIds == 0 then
    container:Show()
    container:SetHeight(20)
    if not container.emptyFS then
      container.emptyFS = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      container.emptyFS:SetPoint("TOPLEFT", container, "TOPLEFT", 4, 0)
    end
    container.emptyFS:SetText("No loot for this encounter.")
    container.emptyFS:Show()
    UI.detailScrollChild:SetHeight(math.max(1, 28))
    return
  end

  if container.emptyFS then
    container.emptyFS:Hide()
  end

  local rowHeight = C.ROW_HEIGHT
  local y = 0
  local rowIndex = 0
  local returnContext = raidReturnContext()

  for _, itemId in ipairs(lootIds) do
    rowIndex = rowIndex + 1
    local row = Util.getOrCreateLootRow(container, rows, rowIndex, rowHeight)
    local needCount = 0
    if Data and Data.getItemNeedSummary then
      needCount = select(1, Data.getItemNeedSummary(itemId))
    end

    local itemLabel = Util.formatItemLine({
      id = itemId,
      name = Data and Data.getItemDisplayName(itemId),
    })
    local countLabel = ""
    if needCount > 0 then
      countLabel = string.format("|cff00ff00(%d need)|r", needCount)
    end

    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y)
    row:SetPoint("RIGHT", container, "RIGHT", 0, 0)
    row.labelFS:SetText(itemLabel)
    row.countFS:SetText(countLabel)

    local itemCapture = itemId
    row:SetScript("OnClick", function()
      UI.openItemDetail(itemCapture, returnContext)
    end)
    row:Show()
    y = y + rowHeight
  end

  for j = rowIndex + 1, #rows do
    if rows[j] and rows[j].labelFS then
      rows[j]:Hide()
    end
  end

  container:SetHeight(math.max(1, y))
  container:Show()
  UI.detailScrollChild:SetHeight(math.max(1, y + 8))
end

function UI.rebuildRaidList()
  if not UI.raidListContainer then
    return
  end

  local Data = TuskUpLoot.Data
  if not Data then
    return
  end

  local state = Util.getRaidState()
  local container = UI.raidListContainer
  local rows = container.rows or {}
  container.rows = rows

  for _, row in ipairs(rows) do
    row:Hide()
  end

  local rowIndex = 0
  local y = -6

  for _, instanceId in ipairs(Data.orderedInstanceIds()) do
    local instance = Data.Instances[instanceId]
    if instance then
      rowIndex = rowIndex + 1
      local row = Util.getOrCreateRaidRow(container, rows, rowIndex)
      local expanded = UI.expandedInstances[instanceId]
      local label = treePrefix(expanded) .. (instance.name or tostring(instanceId))
      if instanceId == state.InstanceId then
        label = "|cff88ff88" .. label .. "|r"
      end

      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, y)
      row:SetPoint("RIGHT", container, "RIGHT", 0, 0)
      row.text:SetPoint("LEFT", 4, 0)

      local instCapture = instanceId
      row:SetScript("OnClick", function()
        local willExpand = not UI.expandedInstances[instCapture]
        if willExpand then
          UI.expandOnlyInstance(instCapture)
        else
          UI.expandedInstances[instCapture] = false
        end
        UI.rebuildRaidList()
      end)
      row.text:SetText(label)
      row:Show()
      y = y - C.ROW_HEIGHT

      if expanded then
        for _, encounterId in ipairs(instance.encounters or {}) do
          local encounter = Data.Encounters[encounterId]
          if encounter then
            rowIndex = rowIndex + 1
            local encRow = Util.getOrCreateRaidRow(container, rows, rowIndex)
            local cleared = state.ClearedEncounters and state.ClearedEncounters[encounterId]
            local encLabel = "  " .. clearPrefix(cleared)
                .. (encounter.name or tostring(encounterId))
            if encounterId == UI.focusEncounterId then
              encLabel = "|cffffff00" .. encLabel .. "|r"
            elseif encounterId == state.LastEncounter then
              encLabel = "|cffffff00" .. encLabel .. "|r"
            end

            encRow:ClearAllPoints()
            encRow:SetPoint("TOPLEFT", container, "TOPLEFT", C.INDENT_ENCOUNTER, y)
            encRow:SetPoint("RIGHT", container, "RIGHT", 0, 0)
            encRow.text:SetPoint("LEFT", C.INDENT_ENCOUNTER + 4, 0)

            local encCapture = encounterId
            encRow:SetScript("OnClick", function()
              selectEncounter(encCapture)
            end)
            encRow.text:SetText(encLabel)
            encRow:Show()
            y = y - C.ROW_HEIGHT
          end
        end
      end
    end
  end

  container:SetHeight(math.max(1, math.abs(y) + 12))
end

function UI.renderRaidPanel()
  UI.renderEncounterLootPanel()
end

function UI.onRaidStateChanged()
  local state = Util.getRaidState()

  if state.InstanceId then
    UI.expandOnlyInstance(state.InstanceId)
    if UI.frame and UI.frame:IsShown() then
      UI.setActiveTab("raids")
    else
      UI.activeTab = "raids"
    end
  else
    UI.focusInstanceId = nil
    if UI.frame and UI.frame:IsShown() then
      UI.setActiveTab("characters")
    else
      UI.activeTab = "characters"
    end
  end

  if state.LastEncounter then
    focusEncounterLoot(state.LastEncounter)
  elseif UI.activeTab == "raids" and UI.frame then
    UI.rebuildRaidList()
    UI.renderEncounterLootPanel()
  end

  Util.updateFrameTitle()
end
