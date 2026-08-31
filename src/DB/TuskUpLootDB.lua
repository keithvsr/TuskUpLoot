-- Handles SavedVariables persistence for this addon.
-- Loaded via .toc; defines a module table `TuskUpLoot.DB`.

local _, TUL = ...

TUL.DB = TUL.DB or {}
local DB = TUL.DB

local RAID_RUN_MAX_AGE_SEC = 14 * 24 * 60 * 60

local function getDefaults()
  return {
    items = {},
    characters = {},
    raidRuns = {},
    manualSort = {},
    opts = {
      sendRaidChat = false,
      debug = false,
    },
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

local function characterClassName(characterKey)
  local chars = TuskUpLootDB and TuskUpLootDB.characters
  local character = chars and chars[characterKey]
  return string.lower(character and character.class or "")
end

local function sortCharacterKeysByClassThenName(keys)
  table.sort(keys, function(a, b)
    local aClass = characterClassName(a)
    local bClass = characterClassName(b)
    if aClass ~= bClass then
      return aClass < bClass
    end
    return characterDisplayName(a) < characterDisplayName(b)
  end)
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
  sortCharacterKeysByClassThenName(missing)
  for _, key in ipairs(missing) do
    TuskUpLootDB.manualSort[#TuskUpLootDB.manualSort + 1] = key
  end

  return TuskUpLootDB.manualSort
end

function DB.resetManualSortToDefault()
  ensureSavedVar()
  local chars = TuskUpLootDB.characters or {}
  local keys = {}
  for characterKey in pairs(chars) do
    keys[#keys + 1] = characterKey
  end
  sortCharacterKeysByClassThenName(keys)
  TuskUpLootDB.manualSort = keys
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

local function dedupeGearSetKeyList(list)
  local seen = {}
  local out = {}
  for _, key in ipairs(list or {}) do
    if type(key) == "string" and not seen[key] then
      seen[key] = true
      out[#out + 1] = key
    end
  end
  return out
end

local function mergeGearSetKeys(existing, incoming)
  local merged = {}
  for _, key in ipairs(existing or {}) do
    merged[#merged + 1] = key
  end
  for _, key in ipairs(incoming or {}) do
    merged[#merged + 1] = key
  end
  return dedupeGearSetKeyList(merged)
end

local function mergeAcquiredFlag(existingAcquired, incomingAcquired)
  return (existingAcquired and true) or (incomingAcquired and true) or false
end

local function copyIncomingCharacterItemMeta(charData)
  return {
    acquired = charData.acquired and true or false,
    gearSets = dedupeGearSetKeyList(charData.gearSets),
  }
end

local function upsertItem(itemId, item)
  ensureSavedVar()
  assert(itemId, "item ID is required to insert/update item")
  if TuskUpLootDB.items[itemId] == nil then
    TuskUpLootDB.items[itemId] = item
    if TUL.ItemCache and TUL.ItemCache.queue then
      TUL.ItemCache.queue(itemId, function()
        if TUL.UI and TUL.UI.rebuildItemList then
          TUL.UI.rebuildItemList()
        end
      end)
    end
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
        stored.characters[characterKey] = copyIncomingCharacterItemMeta(charData or {})
      else
        itemCharTable.acquired = mergeAcquiredFlag(itemCharTable.acquired, charData.acquired)
        if not itemCharTable.gearSets then
          itemCharTable.gearSets = {}
        end
        itemCharTable.gearSets = mergeGearSetKeys(itemCharTable.gearSets, charData.gearSets)
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

local function copyEncounterDropsTable(drops)
  local out = {}
  for encId, list in pairs(drops or {}) do
    local copy = {}
    for i, itemId in ipairs(list) do
      copy[i] = itemId
    end
    out[encId] = copy
  end
  return out
end

function DB.loadRaidRun(runKey)
  ensureSavedVar()
  if not runKey or not TuskUpLootDB.raidRuns then
    return { cleared = {}, lastEncounter = nil, drops = {} }
  end
  local run = TuskUpLootDB.raidRuns[runKey]
  if not run then
    return { cleared = {}, lastEncounter = nil, drops = {} }
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
    drops = copyEncounterDropsTable(run.drops),
  }
end

function DB.appendEncounterDrops(runKey, mapId, encounterId, itemIds)
  ensureSavedVar()
  if not runKey or not encounterId or not itemIds or #itemIds == 0 then
    return
  end
  if not TuskUpLootDB.raidRuns then
    TuskUpLootDB.raidRuns = {}
  end
  local run = TuskUpLootDB.raidRuns[runKey]
  if not run then
    run = { mapId = mapId, cleared = {}, drops = {}, updatedAt = time() }
    TuskUpLootDB.raidRuns[runKey] = run
  end
  if not run.drops then
    run.drops = {}
  end
  if not run.drops[encounterId] then
    run.drops[encounterId] = {}
  end
  local list = run.drops[encounterId]
  for _, itemId in ipairs(itemIds) do
    list[#list + 1] = itemId
  end
  run.mapId = mapId or run.mapId
  run.updatedAt = time()
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
  if gearSet.updatedAt == nil then
    gearSet.updatedAt = gearSet.importedAt or time()
  end
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

local function removeFromManualSort(characterKey)
  ensureSavedVar()
  if type(TuskUpLootDB.manualSort) ~= "table" then
    return
  end
  for i, key in ipairs(TuskUpLootDB.manualSort) do
    if key == characterKey then
      table.remove(TuskUpLootDB.manualSort, i)
      return
    end
  end
end

function DB.removeCharacter(characterKey)
  ensureSavedVar()
  if type(characterKey) ~= "string" then
    return false
  end

  local character = TuskUpLootDB.characters and TuskUpLootDB.characters[characterKey]
  if not character then
    return false
  end

  local gearSetKeys = {}
  if character.gearSets then
    for gsKey in pairs(character.gearSets) do
      gearSetKeys[#gearSetKeys + 1] = gsKey
    end
  end

  for _, gsKey in ipairs(gearSetKeys) do
    DB.removeGearSet(characterKey, gsKey)
  end

  TuskUpLootDB.characters[characterKey] = nil
  removeFromManualSort(characterKey)
  return true
end

function DB.renameCharacter(characterKey, newName)
  ensureSavedVar()
  if type(characterKey) ~= "string" or type(newName) ~= "string" then
    return false
  end

  newName = newName:gsub("^%s+", ""):gsub("%s+$", "")
  if newName == "" then
    return false
  end

  local character = TuskUpLootDB.characters and TuskUpLootDB.characters[characterKey]
  if not character then
    return false
  end

  character.name = newName
  return true
end

local function gearSetActivityAt(gearSet)
  local updated = tonumber(gearSet and gearSet.updatedAt) or 0
  local imported = tonumber(gearSet and gearSet.importedAt) or 0
  return math.max(updated, imported)
end

function DB.characterLatestActivityAt(characterKey)
  ensureSavedVar()
  if type(characterKey) ~= "string" then
    return 0
  end

  local character = TuskUpLootDB.characters and TuskUpLootDB.characters[characterKey]
  if not character or not character.gearSets then
    return 0
  end

  local latest = 0
  for _, gearSet in pairs(character.gearSets) do
    local at = gearSetActivityAt(gearSet)
    if at > latest then
      latest = at
    end
  end
  return latest
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

local function gearSetContainsItem(gearSet, itemId)
  if type(gearSet) ~= "table" or type(gearSet.items) ~= "table" or not itemId then
    return false
  end
  for _, id in ipairs(gearSet.items) do
    if id == itemId then
      return true
    end
  end
  for id in pairs(gearSet.items) do
    if type(id) == "number" and id == itemId then
      return true
    end
  end
  return false
end

function DB.bumpGearSetsForItem(characterKey, itemId)
  ensureSavedVar()
  if type(characterKey) ~= "string" or not itemId then
    return
  end
  local character = TuskUpLootDB.characters and TuskUpLootDB.characters[characterKey]
  if not character or not character.gearSets then
    return
  end
  local now = time()
  for _, gearSet in pairs(character.gearSets) do
    if gearSetContainsItem(gearSet, itemId) then
      gearSet.updatedAt = now
    end
  end
end

function DB.setItemAcquired(itemId, characterKey, acquired)
  ensureSavedVar()
  if (TuskUpLootDB.items
        and TuskUpLootDB.items[itemId]
        and TuskUpLootDB.items[itemId].characters
        and TuskUpLootDB.items[itemId].characters[characterKey]) then
    TuskUpLootDB.items[itemId].characters[characterKey].acquired = acquired and true or false
    DB.bumpGearSetsForItem(characterKey, itemId)
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
    return gearSetActivityAt(a) > gearSetActivityAt(b)
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

local function copyGearSet(gearSet, touchUpdatedAt)
  if type(gearSet) ~= "table" then
    return nil
  end
  local now = time()
  local copy = {
    name = gearSet.name,
    phase = gearSet.phase,
    importedAt = gearSet.importedAt,
    updatedAt = gearSet.updatedAt,
    items = {},
  }
  if touchUpdatedAt then
    copy.updatedAt = now
  elseif copy.updatedAt == nil and copy.importedAt ~= nil then
    copy.updatedAt = copy.importedAt
  end
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
  local incomingAt = gearSetActivityAt(incomingGearSet)
  local existingAt = gearSetActivityAt(existing)

  if incomingAt > existingAt then
    character.gearSets[gearSetKey] = copyGearSet(incomingGearSet, true)
    return true
  end
  return false
end

local function replaceGearSet(characterKey, gearSetKey, incomingGearSet)
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

  character.gearSets[gearSetKey] = copyGearSet(incomingGearSet, true)
  return true
end

local function mergeIncomingItemAcquired(itemId, item)
  local storedItem = TuskUpLootDB.items and TuskUpLootDB.items[itemId]
  if not storedItem or type(item) ~= "table" or type(item.characters) ~= "table" then
    return
  end
  for characterKey, charMeta in pairs(item.characters) do
    if type(charMeta) == "table" then
      local existing = storedItem.characters and storedItem.characters[characterKey]
      if existing then
        charMeta.acquired = mergeAcquiredFlag(existing.acquired, charMeta.acquired)
      end
    end
  end
end

local function upsertBundleItems(bundle, mergeMode)
  local replace = (mergeMode == "replace")
  local isFullBundle = bundle.mode == "FULL"
  for itemId, item in pairs(bundle.items or {}) do
    local shouldUpsert = replace or isFullBundle
    if not shouldUpsert and type(item) == "table" and type(item.characters) == "table" then
      shouldUpsert = next(item.characters) ~= nil
    end
    if shouldUpsert then
      mergeIncomingItemAcquired(itemId, item)
      upsertItem(itemId, item)
    end
  end
end

local function applySyncBundleInternal(bundle, mergeMode)
  ensureSavedVar()
  if type(bundle) ~= "table" then
    return { updated = 0, skipped = 0 }
  end

  local replace = (mergeMode == "replace")
  local updated = 0
  local skipped = 0

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
        for gearSetKey, gearSet in pairs(charData.gearSets) do
          local applied
          if replace then
            applied = replaceGearSet(characterKey, gearSetKey, gearSet)
          else
            applied = DB.mergeGearSetIfNewer(characterKey, gearSetKey, gearSet)
          end
          if applied then
            updated = updated + 1
          else
            skipped = skipped + 1
          end
        end
      end
    end
  end

  upsertBundleItems(bundle, mergeMode)

  return { updated = updated, skipped = skipped }
end

function DB.replaceGearSetFromSyncBundle(bundle, characterKey, gearSetKey)
  ensureSavedVar()
  if type(bundle) ~= "table" or type(characterKey) ~= "string" or type(gearSetKey) ~= "string" then
    return { updated = 0, skipped = 0 }
  end

  local charData = bundle.characters and bundle.characters[characterKey]
  local gearSet = charData and charData.gearSets and charData.gearSets[gearSetKey]
  if not gearSet then
    return { updated = 0, skipped = 0 }
  end

  DB.removeGearSet(characterKey, gearSetKey)

  local meta = {
    name = charData.name,
    level = charData.level,
    race = charData.race,
    class = charData.class,
  }
  DB.upsertCharacter(characterKey, meta)
  replaceGearSet(characterKey, gearSetKey, gearSet)
  upsertBundleItems(bundle, "replace")

  return { updated = 1, skipped = 0 }
end

function DB.replaceCharactersFromSyncBundle(bundle)
  ensureSavedVar()
  if type(bundle) ~= "table" then
    return { updated = 0, skipped = 0 }
  end

  for characterKey in pairs(bundle.characters or {}) do
    DB.removeCharacter(characterKey)
  end

  return applySyncBundleInternal(bundle, "replace")
end

function DB.applySyncBundle(bundle)
  return applySyncBundleInternal(bundle, "merge")
end

function DB.replaceFromSyncBundle(bundle)
  ensureSavedVar()
  TuskUpLootDB.characters = {}
  TuskUpLootDB.items = {}
  TuskUpLootDB.manualSort = {}
  return applySyncBundleInternal(bundle, "replace")
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

function DB.resetToDefaults()
  if not TuskUpLootDB or type(TuskUpLootDB) ~= "table" then
    TuskUpLootDB = getDefaults()
    return true
  end

  for k in pairs(TuskUpLootDB) do
    TuskUpLootDB[k] = nil
  end

  local defaults = getDefaults()
  for k, v in pairs(defaults) do
    TuskUpLootDB[k] = v
  end

  return true
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
