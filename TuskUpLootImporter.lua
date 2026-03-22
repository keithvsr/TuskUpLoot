-- Handles importing sixtyupgrades JSON exports into the TuskUpLoot database.
-- Loaded via .toc

TuskUpLoot.Importer = {}
local IMP = TuskUpLoot.Importer

local function normalizeStringKey(name)
  assert(type(name) == "string", "name must be a string")
  if name == "" then
    return nil
  end
  return name:lower()
end

-- organize character data from export and return a normalized key and the character data
local function extractCharacterDataFromExport(payload)
  if type(payload) ~= "table" or type(payload.character) ~= "table" or payload.character.name == nil then
    return nil, "invalid payload"
  end
  local character = payload.character
  local characterKey = normalizeStringKey(character.name)

  local characterData = {
    name = character.name,
    level = character.level,
    race = character.race,       -- i.e. Troll, Orc, Undead, etc
    class = character.gameClass, -- i.e. Warrior, Rogue, Priest, etc
  }

  return characterKey, characterData
end

local function extractGearSetFromExport(setName, payloadItems)
  if type(setName) ~= "string" or type(payloadItems) ~= "table" then
    return nil, "invalid setName or items"
  end

  local gearSetKey = normalizeStringKey(setName)
  local gearSetItems = {}
  for _, item in pairs(payloadItems) do
    local acquired = item.acquired ~= nil and item.acquired or false
    gearSetItems[item.id] = acquired
  end

  return gearSetKey, gearSetItems
end


local function extractItemsFromExport(payload)
  if type(payload) ~= "table" or type(payload.items) ~= "table" then
    return nil, "invalid payload"
  end

  local items = {}
  for _, payloadItem in pairs(payload.items) do
    local item = {
      name = payloadItem.name,
      slot = payloadItem.slot,
      id = payloadItem.id,
    }
    items[payloadItem.id] = item
  end
  return items
end


function IMP.import(jsonText)
  local ok, result = pcall(TuskUpLoot.Parser.Parse, jsonText)
  if not ok then
    return nil, result
  end
  -- we have a parsed result, now we need to organize it to our desired models
  local characterKey, characterData = extractCharacterDataFromExport(result)
  local items = extractItemsFromExport(result)
  local gearSetKey, gearSetItems = extractGearSetFromExport(result)

  -- insert organized data into database
  TuskUpLoot.DB.upsertCharacter(characterKey, characterData)
  TuskUpLoot.DB.insertItems(items)
  TuskUpLoot.DB.upsertGearSet(characterKey, gearSetKey, gearSetItems)
  return result, nil
end
