-- Handles SavedVariables persistence for this addon.
-- Loaded via .toc; defines a module table `TuskUpLoot.DB`.

TuskUpLoot.DB = TuskUpLoot.DB or {}
local DB = TuskUpLoot.DB

local RAID_RUN_MAX_AGE_SEC = 14 * 24 * 60 * 60

local function getDefaults()
  return {
    items = {},
    characters = {},
    raidRuns = {},
    manualSort = {},
  }
end

local function ensureSavedVar()
  if not TuskUpLootDB or type(TuskUpLootDB) ~= "table" then
    TuskUpLootDB = getDefaults()
    return -- we've started fresh so no further merge is necessary
  end
  local defaults = getDefaults()
  for k, v in pairs(defaults) do
    if TuskUpLootDB[k] == nil then
      TuskUpLootDB[k] = v
    end
  end
end

local function characterDisplayName(characterKey)
  local chars = TuskUpLootDB and TuskUpLootDB.characters
  local character = chars and chars[characterKey]
  return string.lower(character and character.name or characterKey or "")
end

local function appendToManualSort(characterKey)
  ensureSavedVar()
  if type(characterKey) ~= "string" then
    return
  end
  if type(TuskUpLootDB.manualSort) ~= "table" then
    TuskUpLootDB.manualSort = {}
  end
  for _, key in ipairs(TuskUpLootDB.manualSort) do
    if key == characterKey then
      return
    end
  end
  TuskUpLootDB.manualSort[#TuskUpLootDB.manualSort + 1] = characterKey
end

function DB.ensureManualSortList()
  ensureSavedVar()
  if type(TuskUpLootDB.manualSort) ~= "table" then
    TuskUpLootDB.manualSort = {}
  end

  local chars = TuskUpLootDB.characters or {}
  local present = {}
  for _, key in ipairs(TuskUpLootDB.manualSort) do
    if type(key) == "string" and chars[key] and not present[key] then
      present[key] = true
    end
  end

  local pruned = {}
  for _, key in ipairs(TuskUpLootDB.manualSort) do
    if present[key] then
      pruned[#pruned + 1] = key
    end
  end
  TuskUpLootDB.manualSort = pruned

  local missing = {}
  for characterKey in pairs(chars) do
    if not present[characterKey] then
      missing[#missing + 1] = characterKey
    end
  end
  table.sort(missing, function(a, b)
    return characterDisplayName(a) < characterDisplayName(b)
  end)
  for _, key in ipairs(missing) do
    TuskUpLootDB.manualSort[#TuskUpLootDB.manualSort + 1] = key
  end

  return TuskUpLootDB.manualSort
end

function DB.getManualSortPositionMap()
  local manualSort = DB.ensureManualSortList()
  local positions = {}
  for i, key in ipairs(manualSort) do
    positions[key] = i
  end
  return positions
end

function DB.moveCharacterInManualSort(characterKey, toIndex)
  ensureSavedVar()
  if type(characterKey) ~= "string" or type(toIndex) ~= "number" then
    return
  end

  local manualSort = DB.ensureManualSortList()
  local fromIndex
  for i, key in ipairs(manualSort) do
    if key == characterKey then
      fromIndex = i
      break
    end
  end
  if not fromIndex or fromIndex == toIndex then
    return
  end

  local key = table.remove(manualSort, fromIndex)
  table.insert(manualSort, toIndex, key)
end

local function upsertItem(itemId, item)
  ensureSavedVar()
  assert(itemId, "item ID is required to insert/update item")
  if TuskUpLootDB.items[itemId] == nil then
    -- request data if item is new to DB
    C_Item.RequestLoadItemDataByID(itemId)
    TuskUpLootDB.items[itemId] = item
  else
    local stored = TuskUpLootDB.items[itemId]
    if not stored.characters then
      stored.characters = {}
    end
    if item.slot then
      stored.slot = item.slot
    end
    if item.name and not stored.name then
      stored.name = item.name
    end
    for characterKey, charData in pairs(item.characters) do
      local itemCharTable = stored.characters[characterKey]
      if not itemCharTable then
        stored.characters[characterKey] = charData or {}
      else
        if charData.acquired and not itemCharTable.acquired then
          itemCharTable.acquired = true
        end
        if not itemCharTable.gearSets then
          itemCharTable.gearSets = {}
        end
        for _, gearSetKey in ipairs(charData.gearSets or {}) do
          itemCharTable.gearSets[#itemCharTable.gearSets + 1] = gearSetKey
        end
      end
    end
  end
end

function DB.getRaidRunKey(mapId, runInstanceId)
  if not mapId or not runInstanceId or runInstanceId == 0 then
    return nil
  end
  return string.format("%d:%d", mapId, runInstanceId)
end

function DB.loadRaidRun(runKey)
  ensureSavedVar()
  if not runKey or not TuskUpLootDB.raidRuns then
    return { cleared = {}, lastEncounter = nil }
  end
  local run = TuskUpLootDB.raidRuns[runKey]
  if not run then
    return { cleared = {}, lastEncounter = nil }
  end
  local cleared = {}
  if run.cleared then
    for encId, val in pairs(run.cleared) do
      cleared[encId] = val
    end
  end
  return {
    cleared = cleared,
    lastEncounter = run.lastEncounter,
  }
end

function DB.saveEncounterClear(runKey, mapId, encounterId)
  ensureSavedVar()
  if not runKey or not encounterId then
    return
  end
  if not TuskUpLootDB.raidRuns then
    TuskUpLootDB.raidRuns = {}
  end
  local run = TuskUpLootDB.raidRuns[runKey]
  if not run then
    run = { mapId = mapId, cleared = {}, updatedAt = time() }
    TuskUpLootDB.raidRuns[runKey] = run
  end
  if not run.cleared then
    run.cleared = {}
  end
  run.cleared[encounterId] = true
  run.lastEncounter = encounterId
  run.mapId = mapId or run.mapId
  run.updatedAt = time()
end

function DB.pruneRaidRuns(maxAgeSec)
  ensureSavedVar()
  if not TuskUpLootDB.raidRuns then
    return
  end
  local cutoff = time() - (maxAgeSec or RAID_RUN_MAX_AGE_SEC)
  for runKey, run in pairs(TuskUpLootDB.raidRuns) do
    if not run.updatedAt or run.updatedAt < cutoff then
      TuskUpLootDB.raidRuns[runKey] = nil
    end
  end
end

function DB.init()
  ensureSavedVar()
  DB.pruneRaidRuns()
end

function DB.upsertCharacter(characterKey, character)
  ensureSavedVar()

  if type(characterKey) ~= "string" or type(character) ~= "table" then
    return nil
  end

  local chars = TuskUpLootDB.characters
  local isNew = (chars[characterKey] == nil or chars[characterKey].gearSets == nil)
  if isNew then
    character.gearSets = {}
    chars[characterKey] = character
    appendToManualSort(characterKey)
  else
    local existingCharacter = chars[characterKey]
    for k, v in pairs(character) do
      if character[k] ~= nil and k ~= "gearSets" then
        existingCharacter[k] = v
      end
    end
  end
  return characterKey, chars[characterKey]
end

function DB.upsertItems(items)
  if type(items) ~= "table" then return nil end

  for itemId, item in pairs(items) do
    upsertItem(itemId, item)
  end

  return items
end

function DB.upsertGearSet(characterKey, gearSetKey, gearSet)
  ensureSavedVar()
  if type(characterKey) ~= "string"
      or type(gearSetKey) ~= "string"
      or type(gearSet) ~= "table" then
    return nil, nil, nil
  end
  local character = TuskUpLootDB.characters[characterKey]
  if not character then
    return nil, nil, nil
  end
  if not character.gearSets then
    character.gearSets = {}
  end
  local isAnUpdate = character.gearSets[gearSetKey] ~= nil
  character.gearSets[gearSetKey] = gearSet
  return characterKey, character.gearSets[gearSetKey], isAnUpdate
end

local function gearSetKeyListWithout(list, gearSetKey)
  local out = {}
  for _, key in ipairs(list or {}) do
    if key ~= gearSetKey then
      out[#out + 1] = key
    end
  end
  return out
end

function DB.removeGearSet(characterKey, gearSetKey)
  ensureSavedVar()
  if type(characterKey) ~= "string" or type(gearSetKey) ~= "string" then
    return false
  end

  local character = TuskUpLootDB.characters and TuskUpLootDB.characters[characterKey]
  if not character or not character.gearSets or not character.gearSets[gearSetKey] then
    return false
  end

  local gearSet = character.gearSets[gearSetKey]
  local itemIds = {}
  if type(gearSet.items) == "table" then
    for _, id in ipairs(gearSet.items) do
      itemIds[#itemIds + 1] = id
    end
    if #itemIds == 0 then
      for id in pairs(gearSet.items) do
        itemIds[#itemIds + 1] = id
      end
    end
  end

  character.gearSets[gearSetKey] = nil

  for _, itemId in ipairs(itemIds) do
    local item = TuskUpLootDB.items and TuskUpLootDB.items[itemId]
    if item and item.characters and item.characters[characterKey] then
      local charMeta = item.characters[characterKey]
      local remaining = gearSetKeyListWithout(charMeta.gearSets, gearSetKey)
      if #remaining == 0 then
        item.characters[characterKey] = nil
        if next(item.characters) == nil then
          TuskUpLootDB.items[itemId] = nil
        end
      else
        charMeta.gearSets = remaining
      end
    end
  end

  return true
end

function DB.sortedItemIDs()
  ensureSavedVar()
  local ids = {}
  for k in pairs(TuskUpLootDB.items) do
    ids[#ids + 1] = k
  end
  table.sort(ids, function(a, b)
    return a < b
  end)
  return ids
end

function DB.getItems()
  ensureSavedVar()
  return TuskUpLootDB.items or {}
end

function DB.getItem(itemId)
  ensureSavedVar()
  if TuskUpLootDB.items and TuskUpLootDB.items[itemId] then
    return TuskUpLootDB.items[itemId]
  end
  return nil
end

function DB.getItemAssociatedCharacters(itemId)
  ensureSavedVar()
  if TuskUpLootDB.items and TuskUpLootDB.items[itemId] then
    return TuskUpLootDB.items[itemId].characters or {}
  end
  return {}
end

function DB.setItemAcquired(itemId, characterKey, acquired)
  ensureSavedVar()
  if (TuskUpLootDB.items
        and TuskUpLootDB.items[itemId]
        and TuskUpLootDB.items[itemId].characters
        and TuskUpLootDB.items[itemId].characters[characterKey]) then
    TuskUpLootDB.items[itemId].characters[characterKey].acquired = acquired and true or false
    return true
  end
  return false
end

function DB.markItemAcquired(itemId, characterKey)
  return DB.setItemAcquired(itemId, characterKey, true)
end

function DB.getItemRollup(itemId)
  local item = DB.getItem(itemId)
  if not item then
    return nil
  end

  local chars = item.characters
  if type(chars) ~= "table" then
    return {}
  end

  local rollup = {}
  for characterKey, metadata in pairs(chars) do
    if type(metadata) == "table" then
      local character = TuskUpLootDB.characters[characterKey]
      local displayName = (character and character.name) or characterKey
      local gearRows = {}
      local hasAcquired = metadata.acquired or false

      for _, gsKey in ipairs(metadata.gearSets) do
        local gsName = gsKey
        local phase = nil
        if character and character.gearSets and character.gearSets[gsKey] then
          local gs = character.gearSets[gsKey]
          gsName = gs.name or gsKey
          phase = gs.phase
        end
        gearRows[#gearRows + 1] = {
          key = gsKey,
          name = gsName,
          phase = phase,
        }
      end

      table.sort(gearRows, function(a, b)
        if a.phase ~= b.phase then
          return (a.phase or 0) < (b.phase or 0)
        end
        return (a.name or "") < (b.name or "")
      end)

      rollup[#rollup + 1] = {
        characterKey = characterKey,
        name = displayName,
        gearSets = gearRows,
        hasAcquired = hasAcquired,
      }
    end
  end

  table.sort(rollup, function(a, b)
    return (a.name or "") < (b.name or "")
  end)

  return rollup
end

function DB.characterNamesAndClasses()
  ensureSavedVar()
  local namesAndClasses = {}
  for characterKey, character in pairs(TuskUpLootDB.characters) do
    namesAndClasses[#namesAndClasses + 1] = {
      key = characterKey,
      name = character.name,
      class = character.class,
    }
  end
  return namesAndClasses
end

function DB.characterGearSets(characterKey)
  ensureSavedVar()
  if type(characterKey) ~= "string" then
    return nil
  end
  local character = TuskUpLootDB.characters[characterKey]
  if not character or not character.gearSets then
    return {}
  end

  local gearSets = character.gearSets

  local keys = {}
  for k in pairs(gearSets) do
    keys[#keys + 1] = k
  end

  -- newest import first
  table.sort(keys, function(ka, kb)
    local a = gearSets[ka]
    local b = gearSets[kb]
    if not a or not b then
      return ka < kb
    end
    return (tonumber(a.importedAt) or 0) > (tonumber(b.importedAt) or 0)
  end)

  local ordered = {}
  for i = 1, #keys do
    local k = keys[i]
    ordered[i] = {
      key = k,
      gearSet = gearSets[k],
    }
  end

  return ordered
end

local function copyGearSet(gearSet)
  if type(gearSet) ~= "table" then
    return nil
  end
  local copy = {
    name = gearSet.name,
    phase = gearSet.phase,
    importedAt = gearSet.importedAt,
    items = {},
  }
  if type(gearSet.items) == "table" then
    for i, id in ipairs(gearSet.items) do
      copy.items[i] = id
    end
    if #copy.items == 0 then
      for id in pairs(gearSet.items) do
        copy.items[#copy.items + 1] = id
      end
    end
  end
  return copy
end

function DB.mergeGearSetIfNewer(characterKey, gearSetKey, incomingGearSet)
  ensureSavedVar()
  if type(characterKey) ~= "string"
      or type(gearSetKey) ~= "string"
      or type(incomingGearSet) ~= "table" then
    return false
  end

  local character = TuskUpLootDB.characters[characterKey]
  if not character then
    return false
  end
  if not character.gearSets then
    character.gearSets = {}
  end

  local existing = character.gearSets[gearSetKey]
  local incomingAt = tonumber(incomingGearSet.importedAt) or 0
  local existingAt = existing and tonumber(existing.importedAt) or 0

  if incomingAt > existingAt then
    character.gearSets[gearSetKey] = copyGearSet(incomingGearSet)
    return true
  end
  return false
end

function DB.applySyncBundle(bundle)
  ensureSavedVar()
  if type(bundle) ~= "table" then
    return { updated = 0, skipped = 0 }
  end

  local updated = 0
  local skipped = 0
  local updatedGearSets = {}

  local characters = bundle.characters or {}
  for characterKey, charData in pairs(characters) do
    if type(charData) == "table" then
      local meta = {
        name = charData.name,
        level = charData.level,
        race = charData.race,
        class = charData.class,
      }
      DB.upsertCharacter(characterKey, meta)

      if type(charData.gearSets) == "table" then
        updatedGearSets[characterKey] = updatedGearSets[characterKey] or {}
        for gearSetKey, gearSet in pairs(charData.gearSets) do
          if DB.mergeGearSetIfNewer(characterKey, gearSetKey, gearSet) then
            updated = updated + 1
            updatedGearSets[characterKey][gearSetKey] = true
          else
            skipped = skipped + 1
          end
        end
      end
    end
  end

  local items = bundle.items or {}
  local isFullBundle = bundle.mode == "FULL"
  for itemId, item in pairs(items) do
    local shouldUpsert = isFullBundle
    if not shouldUpsert and type(item) == "table" and type(item.characters) == "table" then
      for characterKey, charMeta in pairs(item.characters) do
        local charUpdated = updatedGearSets[characterKey]
        if charUpdated and type(charMeta) == "table" then
          for _, gsKey in ipairs(charMeta.gearSets or {}) do
            if charUpdated[gsKey] then
              shouldUpsert = true
              break
            end
          end
        end
        if shouldUpsert then
          break
        end
      end
    end
    if shouldUpsert then
      upsertItem(itemId, item)
    end
  end

  return { updated = updated, skipped = skipped }
end

function DB.hasSyncableData()
  ensureSavedVar()
  if TuskUpLootDB.characters then
    for _ in pairs(TuskUpLootDB.characters) do
      return true
    end
  end
  return false
end

-- function TuskUpLoot.DB.upsertImport(importObj, rawJsonText)
--   ensureSavedVar()

--   if type(importObj) ~= "table" then
--     return nil
--   end

--   local characterName = importObj.characterName or (UnitName and UnitName("player")) or "Unknown"
--   local key = TuskUpLoot.DB.normalizeCharacterKey(characterName) or "unknown"

--   TuskUpLootDB.imports[key] = {
--     characterName = characterName,
--     importedAt = time and time() or nil,
--     raw = rawJsonText,
--     items = importObj.items or {},
--   }

--   return key, TuskUpLootDB.imports[key]
-- end
