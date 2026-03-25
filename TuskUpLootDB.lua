-- Handles SavedVariables persistence for this addon.
-- Loaded via .toc; defines a module table `TuskUpLoot.DB`.

TuskUpLoot.DB = TuskUpLoot.DB or {}
local DB = TuskUpLoot.DB

local function getDefaults()
  return {
    items = {},
    characters = {},
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
    for characterKey, charData in pairs(item.characters) do
      local itemCharTable = stored.characters[characterKey]
      if not itemCharTable then
        stored.characters[characterKey] = charData or {}
      else
        if charData.acquired and not itemCharTable.acquired then
          itemCharTable.acquired = true
        end
        for _, gearSetKey in ipairs(charData.gearSets) do
          itemCharTable.gearSets[#itemCharTable.gearSets + 1] = gearSetKey
        end
      end
    end
  end
end

function DB.init()
  ensureSavedVar()
end

function DB.upsertCharacter(characterKey, character)
  ensureSavedVar()

  if type(characterKey) ~= "string" or type(character) ~= "table" then
    return nil
  end

  local chars = TuskUpLootDB.characters
  if chars[characterKey] == nil or chars[characterKey].gearSets == nil then
    character.gearSets = {}
    chars[characterKey] = character
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
    return nil
  end
  local character = TuskUpLootDB.characters[characterKey]
  if not character then
    return nil
  end
  if not character.gearSets then
    character.gearSets = {}
  end
  character.gearSets[gearSetKey] = gearSet
  return characterKey, character.gearSets[gearSetKey]
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

function DB.markItemAcquired(itemId, characterKey)
  ensureSavedVar()
  if (TuskUpLootDB.items
        and TuskUpLootDB.items[itemId]
        and TuskUpLootDB.items[itemId].characters
        and TuskUpLootDB.items[itemId].characters[characterKey]) then
    TuskUpLootDB.items[itemId].characters[characterKey].acquired = true
  end
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
  -- sort by name alphabetically
  table.sort(namesAndClasses, function(a, b)
    return a.name < b.name
  end)
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

  -- sort by phase, name alphabetically
  table.sort(keys, function(ka, kb)
    local a = gearSets[ka]
    local b = gearSets[kb]
    if not a or not b then
      return ka < kb
    end
    if a.phase ~= b.phase then
      return a.phase < b.phase
    end
    return (a.name or ka) < (b.name or kb)
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
