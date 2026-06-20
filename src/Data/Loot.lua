TuskUpLoot.Data = TuskUpLoot.Data or {}
local Data = TuskUpLoot.Data

local function appendDropsFromSource(lootIds, seen, sourceType, sourceId)
  if not sourceType or not sourceId then
    return
  end

  local drops
  if sourceType == "npc" then
    local npc = Data.NPCs and Data.NPCs[sourceId]
    drops = npc and npc.drops
  elseif sourceType == "object" then
    local obj = Data.Objects and Data.Objects[sourceId]
    drops = obj and obj.drops
  end

  if not drops then
    return
  end

  for _, itemId in ipairs(drops) do
    if not seen[itemId] then
      seen[itemId] = true
      lootIds[#lootIds + 1] = itemId
    end
  end
end

local function resolveLootSources(encounter, sourceType, sourceId)
  local lootIds = {}
  local seen = {}

  if not encounter or not encounter.loot then
    return lootIds
  end

  for _, source in ipairs(encounter.loot) do
    if sourceType and sourceId then
      local id = sourceType == "npc" and source.npc_id or source.object_id
      if source.type == sourceType and id == sourceId then
        appendDropsFromSource(lootIds, seen, source.type, id)
      end
    else
      local id = source.type == "npc" and source.npc_id or source.object_id
      appendDropsFromSource(lootIds, seen, source.type, id)
    end
  end

  table.sort(lootIds, function(a, b)
    return a < b
  end)

  return lootIds
end

function Data.getInstanceEncounterIds(instanceId)
  local instance = Data.Instances and Data.Instances[instanceId]
  if not instance or not instance.encounters then
    return {}
  end
  return instance.encounters
end

function Data.getEncounterLootIds(encounterId)
  local encounter = Data.Encounters and Data.Encounters[encounterId]
  return resolveLootSources(encounter, nil, nil)
end

function Data.getEncounterLootIdsForSource(encounterId, sourceType, sourceId)
  local encounter = Data.Encounters and Data.Encounters[encounterId]
  return resolveLootSources(encounter, sourceType, sourceId)
end

function Data.getItemDisplayName(itemId)
  if C_Item and C_Item.GetItemInfo then
    local name = select(1, C_Item.GetItemInfo(itemId))
    if name then
      return name
    end
  end
  local catalog = Data.Items and Data.Items[itemId]
  if catalog and catalog.name then
    return catalog.name
  end
  return nil
end

local function mergeGearSetRow(dest, gs)
  local key = gs.key
  for _, existing in ipairs(dest) do
    if existing.key == key then
      return
    end
  end
  dest[#dest + 1] = gs
end

function Data.getAggregatedItemRollup(itemId)
  local DB = TuskUpLoot.DB
  if not DB or not DB.getItemRollup or not Data.getNeedRollupItemIds then
    return nil
  end

  local rollupIds = Data.getNeedRollupItemIds(itemId)
  if #rollupIds == 1 then
    return DB.getItemRollup(rollupIds[1])
  end

  local byChar = {}
  for _, armorId in ipairs(rollupIds) do
    local rollup = DB.getItemRollup(armorId)
    if rollup then
      for _, row in ipairs(rollup) do
        local key = row.characterKey
        local merged = byChar[key]
        if not merged then
          merged = {
            characterKey = key,
            name = row.name,
            gearSets = {},
            hasAcquired = false,
            markItemId = nil,
          }
          byChar[key] = merged
        end

        for _, gs in ipairs(row.gearSets or {}) do
          mergeGearSetRow(merged.gearSets, gs)
        end

        if row.hasAcquired then
          merged.hasAcquired = true
          merged.markItemId = armorId
        elseif not merged.hasAcquired then
          merged.markItemId = merged.markItemId or armorId
        end
      end
    end
  end

  local result = {}
  for _, merged in pairs(byChar) do
    result[#result + 1] = merged
  end

  table.sort(result, function(a, b)
    return (a.name or "") < (b.name or "")
  end)

  return result
end

function Data.getTierTokenNeedsByReward(tokenId)
  local DB = TuskUpLoot.DB
  if not DB or not DB.getItemRollup or not Data.getTierTokenResultIds then
    return nil
  end

  local rewardIds = Data.getTierTokenResultIds(tokenId)
  if not rewardIds or #rewardIds == 0 then
    return nil
  end

  local groups = {}
  for _, armorId in ipairs(rewardIds) do
    local rollup = DB.getItemRollup(armorId)
    if rollup then
      local needs = {}
      local has = {}
      for _, row in ipairs(rollup) do
        local entry = {
          who = row.name or row.characterKey,
          characterKey = row.characterKey,
          gearSets = row.gearSets or {},
          markItemId = armorId,
        }
        if row.hasAcquired then
          has[#has + 1] = entry
        else
          needs[#needs + 1] = entry
        end
      end
      if #needs > 0 then
        groups[#groups + 1] = {
          itemId = armorId,
          name = Data.getItemDisplayName(armorId),
          needs = needs,
          has = has,
        }
      end
    end
  end

  table.sort(groups, function(a, b)
    local nameA = a.name or ""
    local nameB = b.name or ""
    if nameA ~= nameB then
      return nameA < nameB
    end
    return a.itemId < b.itemId
  end)

  if #groups == 0 then
    return nil
  end
  return groups
end

function Data.getItemNeedSummary(itemId)
  local needCount = 0
  local hasCount = 0
  local rollup = Data.getAggregatedItemRollup(itemId)
  if not rollup then
    return needCount, hasCount
  end

  for _, row in ipairs(rollup) do
    if row.hasAcquired then
      hasCount = hasCount + 1
    else
      needCount = needCount + 1
    end
  end

  return needCount, hasCount
end

local function requestItemDataRecursive(itemId, seen)
  if not itemId or seen[itemId] or not C_Item or not C_Item.RequestLoadItemDataByID then
    return
  end
  seen[itemId] = true
  C_Item.RequestLoadItemDataByID(itemId)

  if Data.getNeedRollupItemIds then
    for _, linkedId in ipairs(Data.getNeedRollupItemIds(itemId)) do
      requestItemDataRecursive(linkedId, seen)
    end
  end
end

function Data.orderedInstanceIds()
  -- order raids by phase and general conception of order
  local ids = {
    532, -- karazhan
    565, -- gruul's lair
    544, -- magtheridon's lair
    548, -- serpentshrine cavern
    550, -- tempest keep
    534, -- hyjal summit
    564, -- black temple
    568, -- zul'aman
    580, -- sunwell plateau
  }
  return ids
end

function Data.requestEncounterItemData(encounterId)
  local itemIds = Data.getEncounterLootIds(encounterId)
  if not itemIds then
    return
  end
  local seen = {}
  for _, itemId in ipairs(itemIds) do
    requestItemDataRecursive(itemId, seen)
  end
end

function Data.requestInstanceItemData(instanceId)
  if not instanceId then
    return
  end

  local seen = {}
  for _, encounterId in ipairs(Data.getInstanceEncounterIds(instanceId)) do
    for _, itemId in ipairs(Data.getEncounterLootIds(encounterId)) do
      requestItemDataRecursive(itemId, seen)
    end
  end
end

function Data.getDropItemIds()
  local itemIds = {}
  for k in pairs(Data.Items) do
    itemIds[#itemIds + 1] = k
  end
  table.sort(itemIds, function(a, b)
    return a < b
  end)
  return itemIds
end
