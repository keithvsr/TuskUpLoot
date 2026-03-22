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

local function insertItem(itemKey, item)
  ensureSavedVar()
  assert(itemKey, "item ID key is required")
  if TuskUpLootDB.items[itemKey] == nil then
    TuskUpLootDB.items[itemKey] = item
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

function DB.insertItems(items)
  if type(items) ~= "table" then return nil end

  for itemKey, item in pairs(items) do
    insertItem(itemKey, item)
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
