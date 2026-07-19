-- Net/TuskUpLootNet.lua
local TUL               = TuskUpLoot -- alias for brevity
TUL.Net                 = {}
local Net               = TUL.Net

-- ── Constants ────────────────────────────────────────────────────────────────
local PREFIX            = "TuskUpLoot"
local DELIMITER         = "|"
local VERSION           = 1
local PAYLOAD_DELIMITER = ";"
local ITEM_ID_DELIMITER = ","

-- message types
Net.MSG                 = {
    -- handle loot drops
    LOOT_DROP = "LOOT_DROP",
    -- future: (mayb unnecessary)
    -- LOOT_DROP_DATA = "LOOT_DROP_DATA", -- actual loot payload (item, recipient, source, etc.)

    -- handle item acquisition
    ITEM_ACQUIRED = "ITEM_ACQUIRED", -- sent when a player acquires an item
}

-- distribution channels, in priority order for broadcast
local CHANNELS          = {
    raid = "RAID",
    party = "PARTY",
    guild = "GUILD",
}

-- ── Internal Helpers ─────────────────────────────────────────────────────────

-- escapes the delimiter for printing
--- @param message string
--- @return string
local function escapeDelimiter(message)
    local escaped = message:gsub("|", "||")
    return escaped
end

-- returns the best available channel given current group status
local function getChannel()
    if IsInRaid() then return CHANNELS.raid end
    if IsInGroup() then return CHANNELS.party end
    return CHANNELS.guild
end

-- strip realm suffix from player name
--- @param sender string
--- @return string
local function cleanSender(sender)
    return sender:match("^([^%-]+)") or sender
end

-- encode a message: VERSION|MSGTYPE|payload (optional)
--- @param msgType string
--- @param payload string?
--- @return string
local function encode(msgType, payload)
    local parts = { tostring(VERSION), msgType }
    if payload then
        TUL.debugPrint("encoding payload: " .. payload)
        parts[#parts + 1] = payload
    end
    for _, part in ipairs(parts) do
        TUL.debugPrint("    part: " .. part)
    end
    return table.concat(parts, DELIMITER)
end

-- decode a raw message string into components
--- @param raw string
--- @return {version: number, msgType: string, payload: string|nil}|nil
local function decode(raw)
    local parts = {}
    for part in raw:gmatch("([^" .. DELIMITER .. "]+)") do
        parts[#parts + 1] = part
    end
    if #parts < 2 then return nil end

    local msgVersion = tonumber(parts[1])
    if msgVersion ~= VERSION then
        -- future: could handle older versions gracefully here
        return nil
    end

    return {
        version = msgVersion,
        msgType = parts[2],
        payload = parts[3] or nil,
    }
end

-- form a loot drop message payload
--- @param dropBucket number|string
--- @param itemIds number[]
--- @return string
local function formLootDropPayload(dropBucket, itemIds)
    return tostring(dropBucket) .. PAYLOAD_DELIMITER .. table.concat(itemIds, ITEM_ID_DELIMITER)
end

-- parse a loot drop message payload
--- @param payload string
--- @return {dropBucket: number|string, itemIds: number[]}
local function parseLootDropPayload(payload)
    local encounterId, itemsPayload = string.split(PAYLOAD_DELIMITER, payload)
    ---@type number|string
    local dropBucket = encounterId
    if encounterId ~= TUL.Data.TRASH_DROP_BUCKET then
        dropBucket = tonumber(encounterId)
    end

    local itemIds = {}
    for itemId in itemsPayload:gmatch("([^" .. ITEM_ID_DELIMITER .. "]+)") do
        itemIds[#itemIds + 1] = tonumber(itemId)
    end
    return {
        dropBucket = dropBucket,
        itemIds = itemIds,
    }
end

-- ── Outgoing ─────────────────────────────────────────────────────────────────

-- send to a specific player via whisper
local function sendTo(player, msgType, payload)
    local message = encode(msgType, payload)
    C_ChatInfo.SendAddonMessage(PREFIX, message, "WHISPER", player)
end

-- broadcast to the best available group/guild channel
local function broadcast(msgType, payload)
    local channel = getChannel()
    local message = encode(msgType, payload)
    -- TUL.chatPrint(escapeDelimiter(message))
    C_ChatInfo.SendAddonMessage(PREFIX, message, channel)
end

-- notify peers of a loot drop
function Net.broadcastLootDrop(dropBucket, itemIds)
    local payload = formLootDropPayload(dropBucket, itemIds)
    -- TUL.chatPrint("broadcasting loot drop: " .. payload)
    broadcast(Net.MSG.LOOT_DROP, payload)
end

-- notify peers when marking an item as acquired
--- @param itemId number
--- @param characterKey string
--- @param acquired? boolean
function Net.broadcastItemAcquired(itemId, characterKey, acquired)
    local wasAcquired = acquired and acquired == true and true or false
    local payload = tostring(itemId) .. PAYLOAD_DELIMITER .. characterKey .. PAYLOAD_DELIMITER .. tostring(wasAcquired)
    broadcast(Net.MSG.ITEM_ACQUIRED, payload)
end

-- ── Incoming ─────────────────────────────────────────────────────────────────

-- handler table: MSG_TYPE -> function(sender, payload)
local handlers = {}

handlers[Net.MSG.LOOT_DROP] = function(sender, lootDropPayload)
    local payload = parseLootDropPayload(lootDropPayload)
    TUL.debugPrint(sender .. " reported loot drops for encounter " .. payload.dropBucket)
    TuskUpLoot.mergeDrops(payload.dropBucket, payload.itemIds)
end

--- @function handlers[Net.MSG.ITEM_ACQUIRED]
--- @param sender string
--- @param itemAcquiredPayload string
handlers[Net.MSG.ITEM_ACQUIRED] = function(sender, itemAcquiredPayload)
    TUL.debugPrint("ITEM_ACQUIRED: '" .. itemAcquiredPayload .. "'")
    local itemIdStr, characterKey, acq = string.split(PAYLOAD_DELIMITER, itemAcquiredPayload)
    TUL.debugPrint("itemIdStr: " .. itemIdStr .. " characterKey: " .. characterKey .. " acq: " .. acq)
    local itemId = tonumber(itemIdStr)
    TUL.debugPrint("itemId: " .. itemId)
    local wasAcquired = acq == "true" and true or false
    local acquired = wasAcquired and "LOOTED" or "UNLOOTED"
    TUL.debugPrint(sender .. " marked item " .. itemId .. acquired .. " for character " .. characterKey)
    TUL.DB.markItemAcquired(itemId, characterKey)
end

function Net.handleMessage(prefix, raw, distribution, sender)
    -- ignore other addon messages
    if prefix ~= PREFIX then
        -- TUL.debugPrint("Addon msg received from another Addon: " .. prefix .. " " .. distribution .. " " .. sender)
        return
    end

    -- ignore messages from self
    if TUL.PlayerCharacter and sender == TUL.PlayerCharacter then
        TUL.debugPrint("TUL msg recvd from self: " .. prefix .. " '" .. raw .. "' " .. distribution)
        return
    end

    local msg = decode(raw)
    -- malformed or wrong version
    if not msg then return end

    local handler = handlers[msg.msgType]
    -- unknown message type, ignore
    if not handler then
        TUL.debugPrint("Handler not found for TUL message type: " .. msg.msgType)
        return
    end

    handler(cleanSender(sender), msg.payload)
end

-- ── Init ─────────────────────────────────────────────────────────────────────

function Net.init()
    local ok = C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    if not ok then
        TUL.chatPrint("Warning: could not register addon message prefix.")
    end
end

-- ── Util ─────────────────────────────────────────────────────────────────────

--- @return boolean
function Net.isPrefixRegistered()
    return C_ChatInfo.IsAddonMessagePrefixRegistered(PREFIX)
end
