-- Handles importing SR data from softres.it in order to merge in
-- non-guildy data if ever necessary

TuskUpLoot.SR = TuskUpLoot.SR or {}
local SR = TuskUpLoot.SR

local LibDeflate = LibStub("LibDeflate")
local Data = TuskUpLoot.Data

local gargulNameToInstanceId

local function trimString(value)
  if type(value) ~= "string" then
    return ""
  end
  return (value:match("^%s*(.-)%s*$"))
end

local function buildGargulNameMap()
  if gargulNameToInstanceId then
    return gargulNameToInstanceId
  end

  local map = {}
  if Data and Data.Instances then
    for instanceId, instance in pairs(Data.Instances) do
      if type(instance.gargul_name) == "string" and instance.gargul_name ~= "" then
        map[instance.gargul_name] = instanceId
      end
    end
  end

  gargulNameToInstanceId = map
  return map
end

local function decodeExportString(exportString)
  local compressed = C_EncodingUtil.DecodeBase64(exportString)
  if not compressed then
    return nil, "invalid base64"
  end

  local json = LibDeflate:DecompressZlib(compressed)
  if not json then
    return nil, "invalid or corrupted zlib data"
  end

  local data = C_EncodingUtil.DeserializeJSON(json)
  if type(data) ~= "table" then
    return nil, "invalid JSON payload"
  end

  return data
end

function SR.import(softresString)
  local trimmed = trimString(softresString)
  if trimmed == "" then
    return nil, "paste a softres.it export string"
  end

  local ok, dataOrErr, decodeErr = pcall(decodeExportString, trimmed)
  if not ok then
    return nil, tostring(dataOrErr)
  end
  if not dataOrErr then
    return nil, decodeErr or "decode failed"
  end

  return dataOrErr
end

function SR.instanceIdsFromMetadata(data)
  if type(data) ~= "table" or type(data.metadata) ~= "table" then
    return {}
  end

  local instances = data.metadata.instances
  if type(instances) ~= "table" then
    return {}
  end

  local nameMap = buildGargulNameMap()
  local seen = {}
  local instanceIds = {}

  for _, gargulName in ipairs(instances) do
    if type(gargulName) == "string" then
      local instanceId = nameMap[gargulName]
      if instanceId and not seen[instanceId] then
        seen[instanceId] = true
        instanceIds[#instanceIds + 1] = instanceId
      end
    end
  end

  table.sort(instanceIds)
  return instanceIds
end

function SR.summarize(data)
  if type(data) ~= "table" then
    return { playerCount = 0, itemCount = 0, instanceCount = 0 }
  end

  local playerCount = 0
  local itemCount = 0
  if type(data.softreserves) == "table" then
    playerCount = #data.softreserves
    for _, entry in ipairs(data.softreserves) do
      if type(entry) == "table" and type(entry.items) == "table" then
        itemCount = itemCount + #entry.items
      end
    end
  end

  local instanceCount = 0
  if type(data.metadata) == "table" and type(data.metadata.instances) == "table" then
    instanceCount = #data.metadata.instances
  end

  return {
    playerCount = playerCount,
    itemCount = itemCount,
    instanceCount = instanceCount,
  }
end
