-- Tab-delimited addon message framing for guild sync.

TuskUpLoot.SyncProtocol = TuskUpLoot.SyncProtocol or {}
local Protocol = TuskUpLoot.SyncProtocol

Protocol.PREFIX = "TuskUpLoot"

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

function Protocol.packChunk(syncId, seq, total, payload)
  payload = payload or ""
  return string.format("C\t%s\t%d\t%d\t%d\t%s",
    escapeField(syncId), seq, total, #payload, payload)
end

function Protocol.packFinish(syncId)
  return Protocol.pack("F", syncId)
end

function Protocol.parse(message)
  if type(message) ~= "string" or message == "" then
    return nil
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
  elseif cmd == "A" or cmd == "D" or cmd == "F" then
    return { cmd = cmd, syncId = fields[2] }
  elseif cmd == "C" then
    local syncId, seq, total, payloadLen, payload = message:match(
      "^C\t([^\t]*)\t(%d+)\t(%d+)\t(%d+)\t(.*)$")
    payloadLen = tonumber(payloadLen) or 0
    if payload and payloadLen > 0 and #payload > payloadLen then
      payload = payload:sub(1, payloadLen)
    end
    return {
      cmd = cmd,
      syncId = syncId,
      seq = tonumber(seq),
      total = tonumber(total),
      payload = payload or "",
    }
  end
  return { cmd = cmd, fields = fields }
end
