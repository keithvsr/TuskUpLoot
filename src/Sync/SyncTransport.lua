-- Throttled WHISPER addon message send/receive.

TuskUpLoot.SyncTransport = TuskUpLoot.SyncTransport or {}
local Transport = TuskUpLoot.SyncTransport

local PREFIX = TuskUpLoot.SyncProtocol and TuskUpLoot.SyncProtocol.PREFIX or "TuskUpLoot"
local SEND_INTERVAL = 0.12
local MAX_MESSAGE_LEN = 220

local sendQueue = {}
local queueFrame
local onMessageCallback

local function sendAddonMessage(target, message)
  if not target or target == "" or not message then
    return false
  end
  if #message > 255 then
    return false
  end
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    local ok = C_ChatInfo.SendAddonMessage(PREFIX, message, "WHISPER", target)
    if type(ok) == "number" then
      return ok == 0
    end
    return ok == true
  end
  if SendAddonMessage then
    SendAddonMessage(PREFIX, message, "WHISPER", target)
    return true
  end
  return false
end

local function flushQueue()
  if #sendQueue == 0 then
    return
  end
  local entry = table.remove(sendQueue, 1)
  if entry then
    sendAddonMessage(entry.target, entry.message)
  end
end

function Transport.enqueue(target, message)
  if not target or not message then
    return
  end
  if #message > 255 then
    return false
  end
  sendQueue[#sendQueue + 1] = { target = target, message = message }
  if not queueFrame then
    queueFrame = CreateFrame("Frame")
    queueFrame:SetScript("OnUpdate", function(self, elapsed)
      self.accum = (self.accum or 0) + elapsed
      if self.accum >= SEND_INTERVAL then
        self.accum = 0
        flushQueue()
        if #sendQueue == 0 then
          self:SetScript("OnUpdate", nil)
        end
      end
    end)
  end
  queueFrame.accum = SEND_INTERVAL
  queueFrame:SetScript("OnUpdate", queueFrame:GetScript("OnUpdate"))
  flushQueue()
end

function Transport.sendNow(target, message)
  return sendAddonMessage(target, message)
end

function Transport.getMaxChunkPayloadSize()
  return MAX_MESSAGE_LEN
end

function Transport.setOnMessage(callback)
  onMessageCallback = callback
end

function Transport.handleAddonMessage(prefix, message, channel, sender)
  if prefix ~= PREFIX then
    return
  end
  if channel ~= "WHISPER" then
    return
  end
  if not sender or sender == "" then
    return
  end
  sender = Ambiguate and Ambiguate(sender, "short") or sender
  if onMessageCallback then
    onMessageCallback(sender, message)
  end
end

function Transport.registerPrefix()
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    return C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
  end
  if RegisterAddonMessagePrefix then
    RegisterAddonMessagePrefix(PREFIX)
    return true
  end
  return false
end

function Transport.attachEvents(eventFrame)
  if not eventFrame then
    return
  end
  eventFrame:RegisterEvent("CHAT_MSG_ADDON")
end

function Transport.onEvent(event, ...)
  if event == "CHAT_MSG_ADDON" then
    local prefix, message, channel, sender = ...
    Transport.handleAddonMessage(prefix, message, channel, sender)
  end
end
