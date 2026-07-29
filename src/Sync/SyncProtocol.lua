-- Tab-delimited addon message framing for guild sync.

TuskUpLoot.SyncProtocol = TuskUpLoot.SyncProtocol or {}
local Protocol = TuskUpLoot.SyncProtocol

Protocol.PREFIX = "TULSync"

local function escapeField(s)
  s = tostring(s or "")
  s = s:gsub("\t", " ")
  s = s:gsub("\n", " ")
  return s
end

local function splitFields(message)
  local fields = {}
  for field in string.gmatch(message or "", "[^\t]+") do
    fields[#fields + 1] = field
  end
  return fields
end

function Protocol.pack(cmd, ...)
  local parts = { cmd }
  for i = 1, select("#", ...) do
    parts[#parts + 1] = escapeField(select(i, ...))
  end
  return table.concat(parts, "\t")
end

function Protocol.unpack(message)
  local fields = splitFields(message)
  if #fields == 0 then
    return nil
  end
  return fields[1], fields
end

function Protocol.packOffer(syncId, target, mode, charKey, gearSetKey, label)
  label = label or ""
  if #label > 48 then
    label = label:sub(1, 48)
  end
  return Protocol.pack("O", syncId, target, mode, charKey or "", gearSetKey or "", label)
end

function Protocol.packAccept(syncId)
  return Protocol.pack("A", syncId)
end

function Protocol.packDecline(syncId)
  return Protocol.pack("D", syncId)
end

function Protocol.packBundle(syncId, encoded)
  return string.format("B\t%s\t%s", escapeField(syncId), encoded or "")
end

function Protocol.parse(message)
  if type(message) ~= "string" or message == "" then
    return nil
  end

  -- Bundle: B\t<syncId>\t<encoded...> (encoded may contain tabs after first two fields)
  local bundleId, encoded = message:match("^B\t([^\t]*)\t(.*)$")
  if bundleId then
    return {
      cmd = "B",
      syncId = bundleId,
      encoded = encoded or "",
    }
  end

  local cmd, fields = Protocol.unpack(message)
  if not cmd then
    return nil
  end
  if cmd == "O" then
    return {
      cmd = cmd,
      syncId = fields[2],
      target = fields[3],
      mode = fields[4],
      charKey = fields[5],
      gearSetKey = fields[6],
      label = fields[7],
    }
  elseif cmd == "A" or cmd == "D" then
    return { cmd = cmd, syncId = fields[2] }
  end
  return { cmd = cmd, fields = fields }
end
