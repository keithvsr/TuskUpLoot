-- Serialize/compress/encode sync bundles for AceComm transport.

TuskUpLoot.SyncCodec = TuskUpLoot.SyncCodec or {}
local Codec = TuskUpLoot.SyncCodec

local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

local function debug(msg)
  if TuskUpLoot.debugPrint then
    TuskUpLoot.debugPrint(msg)
  end
end

--- Encode a Lua table into an addon-channel-safe string.
--- @param val table
--- @return string|nil
function Codec.encode(val)
  if type(val) ~= "table" then
    debug("SyncCodec.encode: expected table, got " .. type(val))
    return nil
  end
  local serialized = LibSerialize:Serialize(val)
  if not serialized then
    debug("SyncCodec.encode: Serialize failed")
    return nil
  end
  local compressed = LibDeflate:CompressDeflate(serialized)
  if not compressed then
    debug("SyncCodec.encode: CompressDeflate failed (serialized " .. #serialized .. " bytes)")
    return nil
  end
  local encoded = LibDeflate:EncodeForWoWAddonChannel(compressed)
  if not encoded then
    debug("SyncCodec.encode: EncodeForWoWAddonChannel failed")
    return nil
  end
  debug(string.format(
    "SyncCodec.encode: serialized=%d compressed=%d encoded=%d",
    #serialized, #compressed, #encoded))
  return encoded
end

--- Decode an addon-channel string back into a Lua table.
--- @param str string
--- @return table|nil
function Codec.decode(str)
  if type(str) ~= "string" or str == "" then
    debug("SyncCodec.decode: empty or non-string input")
    return nil
  end
  local decoded = LibDeflate:DecodeForWoWAddonChannel(str)
  if not decoded then
    debug("SyncCodec.decode: DecodeForWoWAddonChannel failed (input " .. #str .. " bytes)")
    return nil
  end
  local decompressed = LibDeflate:DecompressDeflate(decoded)
  if not decompressed then
    debug("SyncCodec.decode: DecompressDeflate failed (decoded " .. #decoded .. " bytes)")
    return nil
  end
  local success, data = LibSerialize:Deserialize(decompressed)
  if not success or type(data) ~= "table" then
    debug("SyncCodec.decode: Deserialize failed (decompressed " .. #decompressed .. " bytes)")
    return nil
  end
  debug(string.format(
    "SyncCodec.decode: input=%d decoded=%d decompressed=%d ok",
    #str, #decoded, #decompressed))
  return data
end
