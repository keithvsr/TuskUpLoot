-- Build sync bundles from SavedVariables.

TuskUpLoot.SyncPayload = TuskUpLoot.SyncPayload or {}
local Payload = TuskUpLoot.SyncPayload

local function copyItem(item)
  if type(item) ~= "table" then
    return nil
  end
  local copy = {
    id = item.id,
    name = item.name,
    slot = item.slot,
    characters = {},
  }
  if type(item.characters) == "table" then
    for characterKey, charMeta in pairs(item.characters) do
      if type(charMeta) == "table" then
        local gs = {}
        for _, k in ipairs(charMeta.gearSets or {}) do
          gs[#gs + 1] = k
        end
        copy.characters[characterKey] = {
          acquired = charMeta.acquired,
          gearSets = gs,
        }
      end
    end
  end
  return copy
end

local function copyCharacter(char)
  if type(char) ~= "table" then
    return nil
  end
  local copy = {
    name = char.name,
    level = char.level,
    race = char.race,
    class = char.class,
    gearSets = {},
  }
  if type(char.gearSets) == "table" then
    for gsKey, gs in pairs(char.gearSets) do
      if type(gs) == "table" then
        local gsCopy = {
          name = gs.name,
          phase = gs.phase,
          importedAt = gs.importedAt,
          items = {},
        }
        if type(gs.items) == "table" then
          for i, id in ipairs(gs.items) do
            gsCopy.items[i] = id
          end
          if #gsCopy.items == 0 then
            for id in pairs(gs.items) do
              gsCopy.items[#gsCopy.items + 1] = id
            end
          end
        end
        copy.gearSets[gsKey] = gsCopy
      end
    end
  end
  return copy
end

local function itemReferencesGearSet(item, characterKey, gearSetKey)
  if type(item) ~= "table" or type(item.characters) ~= "table" then
    return false
  end
  local charMeta = item.characters[characterKey]
  if type(charMeta) ~= "table" then
    return false
  end
  for _, gsKey in ipairs(charMeta.gearSets or {}) do
    if gsKey == gearSetKey then
      return true
    end
  end
  return false
end

function Payload.buildFullBundle()
  if not TuskUpLootDB or type(TuskUpLootDB) ~= "table" then
    return nil
  end
  local bundle = {
    mode = "FULL",
    characters = {},
    items = {},
  }
  if TuskUpLootDB.characters then
    for characterKey, char in pairs(TuskUpLootDB.characters) do
      bundle.characters[characterKey] = copyCharacter(char)
    end
  end
  if TuskUpLootDB.items then
    for itemId, item in pairs(TuskUpLootDB.items) do
      bundle.items[itemId] = copyItem(item)
    end
  end
  return bundle
end

function Payload.buildGearSetBundle(characterKey, gearSetKey)
  if not TuskUpLootDB or type(TuskUpLootDB) ~= "table" then
    return nil
  end
  local character = TuskUpLootDB.characters and TuskUpLootDB.characters[characterKey]
  if not character or not character.gearSets or not character.gearSets[gearSetKey] then
    return nil
  end

  local bundle = {
    mode = "GEAR",
    characters = {},
    items = {},
  }

  local fullChar = copyCharacter(character)
  local charCopy = {
    name = fullChar.name,
    level = fullChar.level,
    race = fullChar.race,
    class = fullChar.class,
    gearSets = {},
  }
  charCopy.gearSets[gearSetKey] = fullChar.gearSets[gearSetKey]
  bundle.characters[characterKey] = charCopy

  if TuskUpLootDB.items then
    for itemId, item in pairs(TuskUpLootDB.items) do
      if itemReferencesGearSet(item, characterKey, gearSetKey) then
        bundle.items[itemId] = copyItem(item)
      end
    end
  end

  return bundle
end
