-- Net/TuskUpLootNet.lua
TuskUpLoot.Net          = {}
local Net               = TuskUpLoot.Net

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
        parts[#parts + 1] = payload
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
    local encounterId, itemsPayload = payload:split(PAYLOAD_DELIMITER)
    ---@type number|string
    local dropBucket = encounterId
    if encounterId ~= TuskUpLoot.Data.TRASH_DROP_BUCKET then
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
    C_ChatInfo.SendAddonMessage(PREFIX, message, channel)
end

-- notify peers of a loot drop
function Net.broadcastLootDrop(dropBucket, itemIds)
    local payload = formLootDropPayload(dropBucket, itemIds)
    broadcast(Net.MSG.LOOT_DROP, payload)
end

-- notify peers when marking an item as acquired
function Net.broadcastItemAcquired(itemId, characterKey)
    local payload = tostring(itemId) .. PAYLOAD_DELIMITER .. characterKey
    broadcast(Net.MSG.ITEM_ACQUIRED, payload)
end

-- ── Incoming ─────────────────────────────────────────────────────────────────

-- handler table: MSG_TYPE -> function(sender, payload)
local handlers = {}

handlers[Net.MSG.LOOT_DROP] = function(sender, lootDropPayload)
    local payload = parseLootDropPayload(lootDropPayload)
    TuskUpLoot.chatPrint(sender .. " reported loot drops for encounter " .. payload.dropBucket)
    TuskUpLoot.mergeDrops(payload.dropBucket, payload.itemIds)
end

handlers[Net.MSG.ITEM_ACQUIRED] = function(sender, itemAcquiredPayload)
    local itemIdStr, characterKey = itemAcquiredPayload:split(PAYLOAD_DELIMITER)
    local itemId = tonumber(itemIdStr)
    TuskUpLoot.chatPrint(sender .. " marked item " .. itemId .. " as acquired for character " .. characterKey)
    TuskUpLoot.DB.markItemAcquired(itemId, characterKey)
end

function Net.handleMessage(prefix, raw, _, sender)
    if prefix ~= PREFIX then return end -- ignore other addon messages

    local msg = decode(raw)
    if not msg then return end -- malformed or wrong version

    local handler = handlers[msg.msgType]
    if not handler then return end -- unknown message type, ignore

    handler(cleanSender(sender), msg.payload)
end

-- ── Init ─────────────────────────────────────────────────────────────────────

function Net.init()
    local ok = C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    if not ok then
        TuskUpLoot.chatPrint("Warning: could not register addon message prefix.")
    end
end
