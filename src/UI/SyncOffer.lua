-- Static popup for incoming sync offers.

local _, TUL = ...

local UI = TUL.UI

StaticPopupDialogs["TUSKUPLOOT_SYNC_OFFER"] = {
  text = "",
  button1 = "Merge",
  button2 = DECLINE,
  button3 = "Replace all",
  OnAccept = function(self)
    local syncId = self.data and self.data.syncId
    if syncId and TUL.Sync and TUL.Sync.acceptOffer then
      TUL.Sync.acceptOffer(syncId, false)
    end
  end,
  OnAlt = function(self)
    local syncId = self.data and self.data.syncId
    if syncId and TUL.Sync and TUL.Sync.acceptOffer then
      TUL.Sync.acceptOffer(syncId, true)
    end
  end,
  OnCancel = function(self)
    local syncId = self.data and self.data.syncId
    if syncId and TUL.Sync and TUL.Sync.declineOffer then
      TUL.Sync.declineOffer(syncId)
    end
  end,
  timeout = 0,
  whileDead = 1,
  hideOnEscape = 1,
  preferredIndex = 3,
}

local function syncOfferCopy(mode)
  if mode == "GEAR" then
    return {
      mergeHint = "Merge adds or updates this gear set and syncs acquired flags for its items.",
      replaceHint = "Replace gear set removes this gear set's item links first, then applies the incoming gear set.",
      replaceButton = "Replace gear set",
    }
  end
  if mode == "PARTIAL" then
    return {
      mergeHint = "Merge adds or updates matching data for the listed character(s) only.",
      replaceHint = "Replace selected removes those character(s) and their gear sets first, then applies the incoming data.",
      replaceButton = "Replace selected",
    }
  end
  return {
    mergeHint = "Merge adds or updates matching data.",
    replaceHint = "Replace all clears your saved characters and items first.",
    replaceButton = "Replace all",
  }
end

function UI.showSyncOffer(syncId, sender, mode, label)
  if not syncId or not sender then
    return
  end
  local desc = label or "data"
  if mode == "FULL" then
    desc = label or "all saved data"
  end

  local copy = syncOfferCopy(mode)
  local dialog = StaticPopupDialogs["TUSKUPLOOT_SYNC_OFFER"]
  dialog.text = string.format(
    "%%s wants to sync:\n|cffffff00%%s|r\n\n|cffffff88Merge|r %s\n|cffff2020%s|r %s",
    copy.mergeHint,
    copy.replaceButton,
    copy.replaceHint)
  dialog.button3 = copy.replaceButton

  StaticPopup_Show("TUSKUPLOOT_SYNC_OFFER", sender, desc, { syncId = syncId, mode = mode })
end
