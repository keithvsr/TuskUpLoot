-- Static popup for incoming sync offers.

local UI = TuskUpLoot.UI

StaticPopupDialogs["TUSKUPLOOT_SYNC_OFFER"] = {
  text = "%s wants to sync:\n|cffffff00%s|r\n\n|cffffff88Merge|r adds or updates matching data.\n|cffff2020Replace all|r clears your saved characters and items first.",
  button1 = "Merge",
  button2 = DECLINE,
  button3 = "Replace all",
  OnAccept = function(self)
    local syncId = self.data and self.data.syncId
    if syncId and TuskUpLoot.Sync and TuskUpLoot.Sync.acceptOffer then
      TuskUpLoot.Sync.acceptOffer(syncId, false)
    end
  end,
  OnAlt = function(self)
    local syncId = self.data and self.data.syncId
    if syncId and TuskUpLoot.Sync and TuskUpLoot.Sync.acceptOffer then
      TuskUpLoot.Sync.acceptOffer(syncId, true)
    end
  end,
  OnCancel = function(self)
    local syncId = self.data and self.data.syncId
    if syncId and TuskUpLoot.Sync and TuskUpLoot.Sync.declineOffer then
      TuskUpLoot.Sync.declineOffer(syncId)
    end
  end,
  timeout = 0,
  whileDead = 1,
  hideOnEscape = 1,
  preferredIndex = 3,
}

function UI.showSyncOffer(syncId, sender, mode, label)
  if not syncId or not sender then
    return
  end
  local desc = label or "data"
  if mode == "FULL" then
    desc = label or "all saved data"
  end
  StaticPopup_Show("TUSKUPLOOT_SYNC_OFFER", sender, desc, { syncId = syncId })
end
