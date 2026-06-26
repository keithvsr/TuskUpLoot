-- Session-scoped item data cache (name, link, quality, icon, equipLoc).

TuskUpLoot.ItemCache = TuskUpLoot.ItemCache or {}
local ItemCache = TuskUpLoot.ItemCache

ItemCache.entries = ItemCache.entries or {}
ItemCache.pending = ItemCache.pending or {}
ItemCache.waiters = ItemCache.waiters or {}

local function addWaiter(itemId, onLoaded)
  if not onLoaded then
    return
  end
  if not ItemCache.waiters[itemId] then
    ItemCache.waiters[itemId] = {}
  end
  ItemCache.waiters[itemId][#ItemCache.waiters[itemId] + 1] = onLoaded
end

local function fireWaiters(itemId, entry)
  local waiters = ItemCache.waiters[itemId]
  ItemCache.waiters[itemId] = nil
  if not waiters then
    return
  end
  for _, cb in ipairs(waiters) do
    cb(entry)
  end
end

local function captureEntry(itemId)
  if not itemId or not C_Item or not C_Item.GetItemInfo then
    return nil
  end
  local name, link, quality, _, _, _, _, _, equipLoc, icon = C_Item.GetItemInfo(itemId)
  if not name and not link then
    return nil
  end
  local entry = {
    id = itemId,
    name = name,
    link = link,
    quality = quality,
    icon = icon,
    equipLoc = equipLoc,
  }
  ItemCache.entries[itemId] = entry
  return entry
end

function ItemCache.get(itemId)
  return ItemCache.entries[itemId]
end

function ItemCache.loadOne(itemId, onLoaded)
  if not itemId then
    return
  end

  local existing = ItemCache.entries[itemId]
  if existing then
    if onLoaded then
      onLoaded(existing)
    end
    return
  end

  addWaiter(itemId, onLoaded)

  if ItemCache.pending[itemId] then
    return
  end
  ItemCache.pending[itemId] = true

  local function complete()
    ItemCache.pending[itemId] = nil
    local entry = ItemCache.entries[itemId]
    fireWaiters(itemId, entry)
  end

  if Item and Item.CreateFromItemID then
    local item = Item:CreateFromItemID(itemId)
    item:ContinueOnItemLoad(function()
      captureEntry(itemId)
      complete()
    end)
    return
  end

  captureEntry(itemId)
  complete()
end

function ItemCache.preloadAll(itemIds, onComplete)
  local toLoad = {}
  local seen = {}
  for _, itemId in ipairs(itemIds or {}) do
    if itemId and not seen[itemId] then
      seen[itemId] = true
      if not ItemCache.entries[itemId] then
        toLoad[#toLoad + 1] = itemId
      end
    end
  end

  if #toLoad == 0 then
    if onComplete then
      onComplete()
    end
    return
  end

  local remaining = #toLoad
  local function oneDone()
    remaining = remaining - 1
    if remaining <= 0 and onComplete then
      onComplete()
    end
  end

  for _, itemId in ipairs(toLoad) do
    ItemCache.loadOne(itemId, oneDone)
  end
end

function ItemCache.queue(itemId, onLoaded)
  ItemCache.loadOne(itemId, onLoaded)
end
