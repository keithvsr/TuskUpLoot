-- Manual raid-chat need broadcasts from item view.

local _, TUL = ...

TUL.NeedBroadcast = TUL.NeedBroadcast or {}
local NeedBroadcast = TUL.NeedBroadcast

local PREAMBLE_PREFIX = "TuskUpLoot: Item "
local SEND_DELAY_SEC = 0.15

local queueFrame = CreateFrame("Frame")
local pendingLines = {}
local nextSendAt = 0

local function collectRaidMemberKeys()
  local keys = {}
  if not IsInRaid() then
    return keys
  end
  for i = 1, GetNumGroupMembers() do
    local name = GetRaidRosterInfo(i)
    if name then
      keys[name:lower()] = name
    end
  end
  local player = UnitName("player")
  if player then
    keys[player:lower()] = player
  end
  return keys
end

local function formatGearSetLabel(gs)
  local name = gs.name or gs.key or "?"
  if gs.phase ~= nil then
    return string.format("%s P%s", name, tostring(gs.phase))
  end
  return name
end

local function appendUnique(list, seen, value)
  if not value or value == "" or seen[value] then
    return
  end
  seen[value] = true
  list[#list + 1] = value
end

local function mergeGearSetLabels(dest, seen, gearSets)
  for _, gs in ipairs(gearSets or {}) do
    appendUnique(dest, seen, formatGearSetLabel(gs))
  end
end

local function resolveItemLink(itemId)
  local itemLink = select(2, C_Item.GetItemInfo(itemId))
  if itemLink and itemLink ~= "" then
    return itemLink
  end
  local item = TUL.DB and TUL.DB.getItem and TUL.DB.getItem(itemId)
  local name = (item and item.name) or ("Item " .. tostring(itemId))
  return string.format("|cff0070dd|Hitem:%d::::::::|h[%s]|h|r", itemId, name)
end

local function hasGlobalNeeders(needInfo)
  if not needInfo then
    return false
  end
  if needInfo.hasRewardNeeds and needInfo.rewardGroups then
    for _, group in ipairs(needInfo.rewardGroups) do
      if #(group.needs or {}) > 0 then
        return true
      end
    end
    return false
  end
  return #(needInfo.needs or {}) > 0
end

local function appendUniqueItemId(list, seen, itemId)
  if not itemId or seen[itemId] then
    return
  end
  seen[itemId] = true
  list[#list + 1] = itemId
end

local function formatNeedLine(who, gearSetLabels, rewardItemIds)
  local parts = { who }

  local gearPart = table.concat(gearSetLabels, ", ")
  if gearPart ~= "" then
    parts[#parts + 1] = gearPart
  end

  if rewardItemIds then
    local rewardLinks = {}
    for _, rewardItemId in ipairs(rewardItemIds) do
      rewardLinks[#rewardLinks + 1] = resolveItemLink(rewardItemId)
    end
    local rewardPart = table.concat(rewardLinks, ", ")
    if rewardPart ~= "" then
      parts[#parts + 1] = rewardPart
    end
  end

  return table.concat(parts, " - ")
end

local function buildDirectLines(needInfo, raidKeys)
  local byChar = {}
  for _, row in ipairs(needInfo.needs or {}) do
    local key = row.characterKey
    if key and raidKeys[key] then
      local entry = byChar[key]
      if not entry then
        entry = {
          who = row.who or raidKeys[key],
          gearSetLabels = {},
          gearSeen = {},
        }
        byChar[key] = entry
      end
      mergeGearSetLabels(entry.gearSetLabels, entry.gearSeen, row.gearSets)
    end
  end

  local lines = {}
  for _, entry in pairs(byChar) do
    lines[#lines + 1] = formatNeedLine(entry.who, entry.gearSetLabels, nil)
  end
  table.sort(lines)
  return lines
end

local function buildRewardLines(needInfo, raidKeys)
  local byChar = {}
  for _, group in ipairs(needInfo.rewardGroups or {}) do
    for _, row in ipairs(group.needs or {}) do
      local key = row.characterKey
      if key and raidKeys[key] then
        local entry = byChar[key]
        if not entry then
          entry = {
            who = row.who or raidKeys[key],
            rewardItemIds = {},
            rewardSeen = {},
            gearSetLabels = {},
            gearSeen = {},
          }
          byChar[key] = entry
        end
        appendUniqueItemId(entry.rewardItemIds, entry.rewardSeen, group.itemId)
        mergeGearSetLabels(entry.gearSetLabels, entry.gearSeen, row.gearSets)
      end
    end
  end

  local lines = {}
  for _, entry in pairs(byChar) do
    lines[#lines + 1] = formatNeedLine(entry.who, entry.gearSetLabels, entry.rewardItemIds)
  end
  table.sort(lines)
  return lines
end

function NeedBroadcast.buildLines(itemId)
  if not itemId then
    return nil, "missing item id"
  end

  local Data = TUL.Data
  if not Data or not Data.getItemNeedInfo then
    return nil, "need info unavailable"
  end

  local preamble = PREAMBLE_PREFIX .. resolveItemLink(itemId)
  local needInfo = Data.getItemNeedInfo(itemId)

  if not hasGlobalNeeders(needInfo) then
    return {
      preamble = preamble,
      lines = { "no bis lists with this item" },
    }
  end

  local raidKeys = collectRaidMemberKeys()
  local characterLines
  if needInfo.hasRewardNeeds then
    characterLines = buildRewardLines(needInfo, raidKeys)
  else
    characterLines = buildDirectLines(needInfo, raidKeys)
  end

  if #characterLines == 0 then
    return {
      preamble = preamble,
      lines = { "no raid members need this item" },
    }
  end

  return {
    preamble = preamble,
    lines = characterLines,
  }
end

local function drainQueue(_, elapsed)
  if #pendingLines == 0 then
    queueFrame:SetScript("OnUpdate", nil)
    return
  end

  nextSendAt = nextSendAt - elapsed
  if nextSendAt > 0 then
    return
  end

  local line = table.remove(pendingLines, 1)
  C_ChatInfo.SendChatMessage(line, "RAID")
  nextSendAt = SEND_DELAY_SEC
end

local function queueRaidMessages(lines)
  for _, line in ipairs(lines or {}) do
    pendingLines[#pendingLines + 1] = line
  end
  if #pendingLines == 0 then
    return
  end
  nextSendAt = 0
  queueFrame:SetScript("OnUpdate", drainQueue)
end

function NeedBroadcast.send(itemId)
  if not IsInRaid() then
    TUL.chatPrint("Must be in a raid to broadcast item needs.")
    return false
  end

  local Opts = TUL.Opts
  if Opts and Opts.sendRaidChatEnabled and not Opts.sendRaidChatEnabled() then
    TUL.chatPrint("Raid chat broadcasts are disabled in options.")
    return false
  end

  local built, err = NeedBroadcast.buildLines(itemId)
  if not built then
    TUL.chatPrint(err or "Could not build broadcast for that item.")
    return false
  end

  C_ChatInfo.SendChatMessage(built.preamble, "RAID")
  queueRaidMessages(built.lines)

  local count = #(built.lines or {})
  if count == 1 and (built.lines[1] == "no bis lists with this item"
      or built.lines[1] == "no raid members need this item") then
    TUL.chatPrint("Broadcast sent to raid chat.")
  else
    TUL.chatPrint(string.format("Broadcasting %d need line(s) to raid chat.", count))
  end
  return true
end
