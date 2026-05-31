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

function Data.getItemNeedSummary(itemId)
  local needCount = 0
  local hasCount = 0
  local DB = TuskUpLoot.DB
  if not DB or not DB.getItemRollup then
    return needCount, hasCount
  end

  local rollup = DB.getItemRollup(itemId)
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

function Data.sortedInstanceIds()
  local ids = {}
  if not Data.Instances then
    return ids
  end
  for id in pairs(Data.Instances) do
    ids[#ids + 1] = id
  end
  table.sort(ids, function(a, b)
    local instA = Data.Instances[a]
    local instB = Data.Instances[b]
    return (instA and instA.name or "") < (instB and instB.name or "")
  end)
  return ids
end

function Data.requestEncounterItemData(encounterId)
  local itemIds = Data.getEncounterLootIds(encounterId)
  if not itemIds or not C_Item or not C_Item.RequestLoadItemDataByID then
    return
  end
  for _, itemId in ipairs(itemIds) do
    C_Item.RequestLoadItemDataByID(itemId)
  end
end

function Data.requestInstanceItemData(instanceId)
  if not instanceId or not C_Item or not C_Item.RequestLoadItemDataByID then
    return
  end

  local seen = {}
  for _, encounterId in ipairs(Data.getInstanceEncounterIds(instanceId)) do
    for _, itemId in ipairs(Data.getEncounterLootIds(encounterId)) do
      if not seen[itemId] then
        seen[itemId] = true
        C_Item.RequestLoadItemDataByID(itemId)
      end
    end
  end
end
