-- Addon option settings backed by TuskUpLootDB.opts.

TuskUpLoot.Opts = TuskUpLoot.Opts or {}
local Opts = TuskUpLoot.Opts

local DEFAULTS = {
  sendRaidChat = true,
  debug = false,
}

local function copyDefaults()
  return {
    sendRaidChat = DEFAULTS.sendRaidChat,
    debug = DEFAULTS.debug,
  }
end

function Opts.init()
  if not TuskUpLootDB or type(TuskUpLootDB) ~= "table" then
    return
  end
  if type(TuskUpLootDB.opts) ~= "table" then
    TuskUpLootDB.opts = copyDefaults()
    return
  end
  for k, v in pairs(DEFAULTS) do
    if TuskUpLootDB.opts[k] == nil then
      TuskUpLootDB.opts[k] = v
    end
  end
end

function Opts.get(key)
  local opts = TuskUpLootDB and TuskUpLootDB.opts
  if opts and opts[key] ~= nil then
    return opts[key]
  end
  return DEFAULTS[key]
end

function Opts.set(key, value)
  if not TuskUpLootDB or type(TuskUpLootDB) ~= "table" then
    return
  end
  if type(TuskUpLootDB.opts) ~= "table" then
    TuskUpLootDB.opts = copyDefaults()
  end
  TuskUpLootDB.opts[key] = value
end

function Opts.sendRaidChatEnabled()
  return Opts.get("sendRaidChat") and true or false
end

function Opts.debugEnabled()
  return Opts.get("debug") and true or false
end
