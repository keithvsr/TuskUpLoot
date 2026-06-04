-- Static popup for incoming sync offers.

local UI = TuskUpLoot.UI

StaticPopupDialogs["TUSKUPLOOT_SYNC_OFFER"] = {
  text = "%s wants to sync:\n|cffffff00%s|r\n\nAccept to merge into your saved data.",
  button1 = ACCEPT,
  button2 = DECLINE,
  OnAccept = function(self)
    local syncId = self.data and self.data.syncId
    if syncId and TuskUpLoot.Sync and TuskUpLoot.Sync.acceptOffer then
      TuskUpLoot.Sync.acceptOffer(syncId)
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
  return -- sync disabled
  --[[
  if not syncId or not sender then
    return
  end
  local desc = label or "data"
  if mode == "FULL" then
    desc = label or "all saved data"
  end
  StaticPopup_Show("TUSKUPLOOT_SYNC_OFFER", sender, desc, { syncId = syncId })
  --]]
end
