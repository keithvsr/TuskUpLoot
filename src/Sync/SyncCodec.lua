-- Compact serialize/deserialize for sync bundles (strings, numbers, booleans, tables).

TuskUpLoot.SyncCodec = TuskUpLoot.SyncCodec or {}
local Codec = TuskUpLoot.SyncCodec

local SEP = "\31"

local function isArrayTable(t)
  local n = #t
  if n == 0 then
    return false
  end
  local count = 0
  for k in pairs(t) do
    count = count + 1
    if type(k) ~= "number" then
      return false
    end
  end
  return count == n
end

local function encodeValue(val)
  local tv = type(val)
  if tv == "nil" then
    return "0"
  elseif tv == "string" then
    return "1" .. tostring(#val) .. SEP .. val
  elseif tv == "number" then
    return "2" .. tostring(val) .. SEP
  elseif tv == "boolean" then
    return (val and "31" or "30") .. SEP
  elseif tv == "table" then
    local parts
    if isArrayTable(val) then
      parts = { "A", tostring(#val) }
      for i = 1, #val do
        parts[#parts + 1] = encodeValue(val[i])
      end
    else
      parts = { "M" }
      for k, v in pairs(val) do
        parts[#parts + 1] = encodeValue(k)
        parts[#parts + 1] = encodeValue(v)
      end
    end
    parts[#parts + 1] = "E"
    return table.concat(parts, SEP)
  end
  return "0"
end

function Codec.encode(val)
  return encodeValue(val)
end

local parseStr
local parsePos

local function peekTag()
  return parseStr:sub(parsePos, parsePos)
end

local function consumeTag(expected)
  local t = peekTag()
  if expected and t ~= expected then
    return false
  end
  parsePos = parsePos + 1
  return true
end

local function readUntilSep()
  local nextSep = string.find(parseStr, SEP, parsePos, true)
  local s
  if nextSep then
    s = parseStr:sub(parsePos, nextSep - 1)
    parsePos = nextSep + 1
  else
    s = parseStr:sub(parsePos)
    parsePos = #parseStr + 1
  end
  return s
end

local function parseValue()
  local tag = peekTag()
  parsePos = parsePos + 1
  if tag == "0" then
    return nil
  elseif tag == "1" then
    local lenStr = readUntilSep()
    local len = tonumber(lenStr) or 0
    local s = parseStr:sub(parsePos, parsePos + len - 1)
    parsePos = parsePos + len
    if parseStr:sub(parsePos, parsePos) == SEP then
      parsePos = parsePos + 1
    end
    return s
  elseif tag == "2" then
    return tonumber(readUntilSep())
  elseif tag == "3" then
    local sub = parseStr:sub(parsePos, parsePos)
    parsePos = parsePos + 1
    return sub == "1"
  elseif tag == "A" then
    parsePos = parsePos - 1
    local countStr = readUntilSep()
    local n = tonumber(countStr) or 0
    local arr = {}
    for i = 1, n do
      arr[i] = parseValue()
    end
    if peekTag() == "E" then
      parsePos = parsePos + 1
    end
    return arr
  elseif tag == "M" then
    local map = {}
    while parsePos <= #parseStr do
      if peekTag() == "E" then
        parsePos = parsePos + 1
        break
      end
      local k = parseValue()
      if peekTag() == "E" then
        parsePos = parsePos + 1
        break
      end
      local v = parseValue()
      if k ~= nil then
        map[k] = v
      end
    end
    return map
  end
  return nil
end

function Codec.decode(str)
  if type(str) ~= "string" or str == "" then
    return nil
  end
  parseStr = str
  parsePos = 1
  return parseValue()
end

function Codec.splitChunks(encoded, chunkSize)
  chunkSize = chunkSize or 220
  local chunks = {}
  local i = 1
  while i <= #encoded do
    chunks[#chunks + 1] = encoded:sub(i, i + chunkSize - 1)
    i = i + chunkSize
  end
  if #chunks == 0 then
    chunks[1] = ""
  end
  return chunks
end

function Codec.joinChunks(chunks)
  return table.concat(chunks or {}, "")
end
