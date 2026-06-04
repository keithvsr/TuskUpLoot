-- Handles importing sixtyupgrades JSON exports into the TuskUpLoot database.
-- Loaded via .toc

TuskUpLoot.Importer = TuskUpLoot.Importer or {}
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
    return nil, "invalid payload: missing character"
  end
  local character = payload.character
  local characterKey = normalizeStringKey(character.name)

  local characterData = {
    name = character.name,
    level = character.level,
    race = character.race,                          -- i.e. Troll, Orc, Undead, etc
    class = character.class or character.gameClass, -- i.e. Warrior, Rogue, Priest, etc
  }

  return characterKey, characterData
end

local function extractGearSetFromExport(payload)
  if type(payload) ~= "table"
      or type(payload.name) ~= "string"
      or type(payload.phase) ~= "number"
      or type(payload.items) ~= "table"
  then
    return nil, "invalid or incomplete payload (gear set)"
  end

  local gearSetKey = normalizeStringKey(payload.name)
  local gearSet = {
    name = payload.name,
    phase = payload.phase,
    items = {},
    importedAt = time(),
  }
  local acquiredItems = {}
  for _, item in pairs(payload.items) do
    if type(item) == "table" and item.id ~= nil then
      table.insert(gearSet.items, item.id)
      local acquired = item.acquired ~= nil and item.acquired or false
      if acquired then
        acquiredItems[item.id] = true
      end
    end
  end

  return gearSetKey, gearSet, acquiredItems
end


local function extractItemsFromExport(payload, characterKey, gearSetKey, acquiredItems)
  if type(payload) ~= "table" or type(payload.items) ~= "table" then
    return nil, "invalid payload: items"
  end

  local items = {}
  for _, payloadItem in ipairs(payload.items) do
    if type(payloadItem) == "table" and payloadItem.id ~= nil then
      local acq = acquiredItems[payloadItem.id] ~= nil and acquiredItems[payloadItem.id] or false
      local item = {
        name = payloadItem.name,
        slot = payloadItem.slot,
        id = payloadItem.id,
        characters = {
          [characterKey] = {
            acquired = acq,
            gearSets = { gearSetKey }
          }
        }
      }
      items[payloadItem.id] = item
    end
  end
  return items
end


-- Returns: payload, err, characterKey — on success err is nil and characterKey is set.
function IMP.import(jsonText)
  local payload, err = TuskUpLoot.Parser.Parse(jsonText)
  if not payload then
    return nil, err
  end

  local characterKey, characterData = extractCharacterDataFromExport(payload)
  if not characterKey then
    return nil, characterData or "invalid character data"
  end

  local gearSetKey, gearSet, acquiredItems = extractGearSetFromExport(payload)
  if not gearSetKey or type(gearSet) ~= "table" then
    return nil, type(gearSet) == "string" and gearSet or "invalid gear set"
  end

  local items = extractItemsFromExport(payload, characterKey, gearSetKey, acquiredItems)
  if not items then
    return nil, "invalid items in payload"
  end

  TuskUpLoot.DB.upsertCharacter(characterKey, characterData)
  local _, _, isAnUpdate = TuskUpLoot.DB.upsertGearSet(characterKey, gearSetKey, gearSet)
  TuskUpLoot.DB.upsertItems(items, characterKey, gearSetKey)

  return payload, nil, characterKey, isAnUpdate ~= nil and isAnUpdate or false
end
