-- Raids tab: instance/encounter loot tree + loot-master focus panel.

local UI = TuskUpLoot.UI
local Util = UI.Util
local C = UI.Constants

-- WoW fonts omit most Unicode (▼ ▶ ✓ ○); use ASCII + |cff color codes instead.
local function treePrefix(expanded)
  return expanded and "‹ " or "› "
end

local function clearPrefix(cleared)
  if cleared then
    return "|cff00ff00√|r "
  end
  return "• "
end

local function pickBestLootItem(encounterId)
  local Data = TuskUpLoot.Data
  if not Data then
    return nil
  end

  local state = Util.getRaidState()
  local lootIds
  if state.LastKilledBoss then
    lootIds = Data.getEncounterLootIdsForSource(encounterId, "npc", state.LastKilledBoss)
    if not lootIds or #lootIds == 0 then
      lootIds = Data.getEncounterLootIds(encounterId)
    end
  else
    lootIds = Data.getEncounterLootIds(encounterId)
  end

  local bestId
  local bestNeed = 0
  for _, itemId in ipairs(lootIds or {}) do
    local needCount = select(1, Data.getItemNeedSummary(itemId))
    if needCount > bestNeed then
      bestNeed = needCount
      bestId = itemId
    end
  end

  if bestId then
    return bestId
  end
  if lootIds and lootIds[1] then
    return lootIds[1]
  end
  return nil
end

local function focusEncounterLoot(encounterId)
  if not encounterId then
    return
  end

  UI.focusEncounterId = encounterId
  if TuskUpLoot.Data and TuskUpLoot.Data.requestEncounterItemData then
    TuskUpLoot.Data.requestEncounterItemData(encounterId)
  end

  local itemId = pickBestLootItem(encounterId)
  UI.selectedItemId = itemId
  if UI.activeTab == "raids" and UI.frame then
    UI.rebuildRaidList()
    UI.renderRaidPanel()
  end
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

  for _, instanceId in ipairs(Data.sortedInstanceIds()) do
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
        UI.expandedInstances[instCapture] = not UI.expandedInstances[instCapture]
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
            local encExpanded = UI.expandedEncounters[encounterId]
            local cleared = state.ClearedEncounters and state.ClearedEncounters[encounterId]
            local encLabel = "  " .. treePrefix(encExpanded) .. clearPrefix(cleared)
                .. (encounter.name or tostring(encounterId))
            if encounterId == state.LastEncounter then
              encLabel = "|cffffff00" .. encLabel .. "|r"
            end

            encRow:ClearAllPoints()
            encRow:SetPoint("TOPLEFT", container, "TOPLEFT", C.INDENT_ENCOUNTER, y)
            encRow:SetPoint("RIGHT", container, "RIGHT", 0, 0)
            encRow.text:SetPoint("LEFT", C.INDENT_ENCOUNTER + 4, 0)

            local encCapture = encounterId
            encRow:SetScript("OnClick", function()
              UI.expandedEncounters[encCapture] = not UI.expandedEncounters[encCapture]
              UI.focusEncounterId = encCapture
              UI.rebuildRaidList()
              if UI.activeTab == "raids" then
                UI.renderRaidPanel()
              end
            end)
            encRow.text:SetText(encLabel)
            encRow:Show()
            y = y - C.ROW_HEIGHT

            if encExpanded then
              local lootIds = Data.getEncounterLootIds(encounterId)
              for _, itemId in ipairs(lootIds) do
                rowIndex = rowIndex + 1
                local lootRow = Util.getOrCreateRaidRow(container, rows, rowIndex)
                local needCount, hasCount = Data.getItemNeedSummary(itemId)
                local itemLabel = Util.formatItemLine({
                  id = itemId,
                  name = Data.getItemDisplayName(itemId),
                })
                if needCount > 0 then
                  itemLabel = itemLabel .. string.format(" |cff00ff00(%d need)|r", needCount)
                elseif hasCount > 0 then
                  itemLabel = itemLabel .. string.format(" (%d has)", hasCount)
                end
                if UI.selectedItemId == itemId then
                  itemLabel = "|cffffff00" .. itemLabel .. "|r"
                end

                lootRow:ClearAllPoints()
                lootRow:SetPoint("TOPLEFT", container, "TOPLEFT", C.INDENT_LOOT, y)
                lootRow:SetPoint("RIGHT", container, "RIGHT", 0, 0)
                lootRow.text:SetPoint("LEFT", C.INDENT_LOOT + 4, 0)

                local itemCapture = itemId
                lootRow:SetScript("OnClick", function()
                  UI.selectedItemId = itemCapture
                  UI.focusEncounterId = encCapture
                  UI.rebuildRaidList()
                  UI.renderRaidPanel()
                end)
                lootRow.text:SetText("    " .. itemLabel)
                lootRow:Show()
                y = y - C.ROW_HEIGHT
              end
            end
          end
        end
      end
    end
  end

  container:SetHeight(math.max(1, math.abs(y) + 12))
end

function UI.renderRaidPanel()
  if UI.activeTab ~= "raids" then
    return
  end
  if not Util.isDetailReady() then
    return
  end

  local focusEnc = UI.focusEncounterId
  if not focusEnc then
    if UI.itemIconBtn then
      UI.itemIconBtn:Hide()
    end
    UI.detailLinkFS:SetText("")
    UI.needsTitle:SetText("Select an encounter or wait for a boss kill.")
    UI.needsTitle:Show()
    UI.clearNeedsList()
    UI.needsListContainer:Hide()
    UI.hasTitle:Hide()
    UI.hasText:Hide()
    UI.detailScrollChild:SetHeight(math.max(1, UI.needsTitle:GetStringHeight() + 8))
    return
  end

  local encounter = TuskUpLoot.Data and TuskUpLoot.Data.Encounters and TuskUpLoot.Data.Encounters[focusEnc]
  if encounter and not UI.selectedItemId then
    if UI.itemIconBtn then
      UI.itemIconBtn:Hide()
    end
    UI.detailLinkFS:SetText(encounter.name or ("Encounter " .. tostring(focusEnc)))
    UI.needsTitle:SetText("Select a loot item below to see guild needs.")
    UI.needsTitle:Show()
    UI.clearNeedsList()
    UI.needsListContainer:Hide()
    UI.hasTitle:Hide()
    UI.hasText:Hide()
    UI.detailScrollChild:SetHeight(math.max(1,
      (UI.needsTitle:GetStringHeight() or 0) + (UI.detailLinkFS:GetStringHeight() or 0) + 12))
    return
  end

  UI.renderSelectedItem()
end

function UI.onRaidStateChanged()
  local state = Util.getRaidState()

  if state.InstanceId then
    UI.focusInstanceId = state.InstanceId
    UI.expandedInstances[state.InstanceId] = true
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
    UI.expandedEncounters[state.LastEncounter] = true
    focusEncounterLoot(state.LastEncounter)
  elseif UI.activeTab == "raids" and UI.frame then
    UI.rebuildRaidList()
    UI.renderRaidPanel()
  end

  Util.updateFrameTitle()
end
