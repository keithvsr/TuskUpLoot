-- Handles exporting needed item data to Gargul addon using reverse-engineered
-- formatting from softres.it style export strings

TuskUpLoot.Export = TuskUpLoot.Export or {}
local GL = {}
TuskUpLoot.Export.GL = GL

local LibDeflate = LibStub("LibDeflate")
local Data = TuskUpLoot.Data
local DB = TuskUpLoot.DB

local itemInstanceMap
local armorToTokenMap

local function getEmptyRaid()
  return {
    hardreserves = {},
    metadata = { id = "tuskuploot", instances = {} },
    softreserves = {},
  }
end

local function addInstanceForItem(map, itemId, instanceId)
  if not itemId or not instanceId then
    return
  end
  if not map[itemId] then
    map[itemId] = {}
  end
  map[itemId][instanceId] = true
end

local function buildItemInstanceMap()
  if itemInstanceMap then
    return itemInstanceMap
  end

  local map = {}
  if not Data or not Data.Instances then
    itemInstanceMap = map
    return map
  end

  for instanceId, instance in pairs(Data.Instances) do
    if instance.encounter_type == "Raid" then
      for _, encounterId in ipairs(Data.getInstanceEncounterIds(instanceId)) do
        for _, itemId in ipairs(Data.getEncounterLootIds(encounterId)) do
          addInstanceForItem(map, itemId, instanceId)
        end
      end
    end
  end

  itemInstanceMap = map
  return map
end

local function buildArmorToTokenMap()
  if armorToTokenMap then
    return armorToTokenMap
  end

  local map = {}
  local tierResults = Data and Data.TierTokenResults
  if tierResults then
    for tokenId, armorIds in pairs(tierResults) do
      for _, armorId in ipairs(armorIds) do
        map[armorId] = tokenId
      end
    end
  end

  armorToTokenMap = map
  return map
end

local function resolveExportItemId(itemId)
  local tokenId = buildArmorToTokenMap()[itemId]
  if tokenId then
    return tokenId
  end
  return itemId
end

local function getInstancesForItem(itemId, instanceMap)
  local instances = instanceMap[itemId]
  if instances then
    return instances
  end
  local tokenId = buildArmorToTokenMap()[itemId]
  if tokenId then
    return instanceMap[tokenId]
  end
  return nil
end

local function itemMatchesSelectedInstances(itemId, selectedSet, instanceMap)
  local instances = getInstancesForItem(itemId, instanceMap)
  if not instances then
    return false
  end
  for instanceId in pairs(instances) do
    if selectedSet[instanceId] then
      return true
    end
  end
  return false
end

local function buildSelectedSet(selectedInstanceIds)
  local selectedSet = {}
  local count = 0
  for _, instanceId in ipairs(selectedInstanceIds or {}) do
    if type(instanceId) == "number" and Data.Instances[instanceId] then
      selectedSet[instanceId] = true
      count = count + 1
    end
  end
  return selectedSet, count
end

function GL.buildSoftResPayload(selectedInstanceIds)
  local selectedSet, selectedCount = buildSelectedSet(selectedInstanceIds)
  if selectedCount == 0 then
    return nil, "select at least one raid"
  end

  local payload = getEmptyRaid()
  local instanceMap = buildItemInstanceMap()

  for _, instanceId in ipairs(Data.orderedInstanceIds()) do
    if selectedSet[instanceId] then
      local instance = Data.Instances[instanceId]
      if instance and instance.gargul_name then
        payload.metadata.instances[#payload.metadata.instances + 1] = instance.gargul_name
      end
    end
  end

  local byCharacter = {}
  local items = DB and DB.getItems and DB.getItems() or {}

  for itemId, item in pairs(items) do
    if type(item) == "table" and type(item.characters) == "table" then
      if itemMatchesSelectedInstances(itemId, selectedSet, instanceMap) then
        for characterKey, metadata in pairs(item.characters) do
          if type(metadata) == "table" and not metadata.acquired then
            local exportId = resolveExportItemId(itemId)
            if itemMatchesSelectedInstances(exportId, selectedSet, instanceMap) then
              local character = TuskUpLootDB.characters and TuskUpLootDB.characters[characterKey]
              if character and character.name then
                local entry = byCharacter[characterKey]
                if not entry then
                  entry = {
                    name = character.name,
                    class = string.lower(character.class or ""),
                    itemsById = {},
                  }
                  byCharacter[characterKey] = entry
                end
                if not entry.itemsById[exportId] then
                  entry.itemsById[exportId] = true
                end
              end
            end
          end
        end
      end
    end
  end

  local softreserves = {}
  for _, entry in pairs(byCharacter) do
    local itemsList = {}
    for exportId in pairs(entry.itemsById) do
      itemsList[#itemsList + 1] = { id = exportId }
    end
    table.sort(itemsList, function(a, b)
      return a.id < b.id
    end)
    if #itemsList > 0 then
      softreserves[#softreserves + 1] = {
        name = entry.name,
        class = entry.class,
        items = itemsList,
      }
    end
  end

  table.sort(softreserves, function(a, b)
    if a.class ~= b.class then
      return a.class < b.class
    end
    return (a.name or "") < (b.name or "")
  end)

  payload.softreserves = softreserves

  local itemCount = 0
  for _, entry in ipairs(softreserves) do
    itemCount = itemCount + #entry.items
  end

  return payload, nil, {
    playerCount = #softreserves,
    itemCount = itemCount,
  }
end

---Encodes formatted lua data into a softres.it-style export string
---@param data table
---@return string
function GL.encodeExportString(data)
  local json = C_EncodingUtil.SerializeJSON(data)
  local compressed = LibDeflate:CompressZlib(json)
  return C_EncodingUtil.EncodeBase64(compressed)
end

function GL.export(selectedInstanceIds)
  local payload, err, summary = GL.buildSoftResPayload(selectedInstanceIds)
  if not payload then
    return nil, err, nil
  end
  return GL.encodeExportString(payload), nil, summary
end
