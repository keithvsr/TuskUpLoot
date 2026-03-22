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

local function extractGearSetFromExport(payload)
  if type(payload) ~= "table"
      or type(payload.name) ~= "string"
      or type(payload.phase) ~= "number"
      or type(payload.items) ~= "table"
  then
    return nil, "invalid or incomplete payload"
  end

  local gearSetKey = normalizeStringKey(payload.name)
  local gearSet = {
    name = payload.name,
    phase = payload.phase,
    items = {},
  }
  for _, item in pairs(payload.items) do
    local acquired = item.acquired ~= nil and item.acquired or false
    gearSet.items[item.id] = acquired
  end

  return gearSetKey, gearSet
end


local function extractItemsFromExport(payload)
  if type(payload) ~= "table" or type(payload.items) ~= "table" then
    return nil, "invalid payload"
  end

  local items = {}
  for _, payloadItem in ipairs(payload.items) do
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
  local payload, err = TuskUpLoot.Parser.Parse(jsonText)
  if not payload then
    return nil, err
  end
  -- we have a parsed result, now we need to organize it to our desired models
  local characterKey, characterData = extractCharacterDataFromExport(payload)
  local items = extractItemsFromExport(payload)
  local gearSetKey, gearSet = extractGearSetFromExport(payload)

  -- insert organized data into database
  TuskUpLoot.DB.upsertCharacter(characterKey, characterData)
  TuskUpLoot.DB.insertItems(items)
  TuskUpLoot.DB.upsertGearSet(characterKey, gearSetKey, gearSet)
  return payload, nil
end
