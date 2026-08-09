local UI = TuskUpLoot.UI

UI.Constants = {
  RAIL_WIDTH = 200,
  FRAME_WIDTH = 640,
  FRAME_HEIGHT = 440,
  MARGIN_L = 18,
  MARGIN_R = 22,
  CONTENT_X = 18 + 200 + 12,
  DETAIL_BOTTOM_CLOSED = 52,
  IMPORT_FRAME_WIDTH = 480,
  IMPORT_FRAME_HEIGHT = 400,
  IMPORT_EDIT_WIDTH = 440,
  IMPORT_EDIT_HEIGHT = 260,
  EXPORT_FRAME_WIDTH = 480,
  EXPORT_FRAME_HEIGHT = 480,
  EXPORT_EDIT_WIDTH = 440,
  EXPORT_EDIT_HEIGHT = 140,
  EXPORT_RAID_LIST_HEIGHT = 168,
  SYNC_PUSH_FRAME_WIDTH = 400,
  SYNC_PUSH_FRAME_HEIGHT = 420,
  SYNC_PUSH_EDIT_WIDTH = 360,
  SYNC_PUSH_CHAR_LIST_HEIGHT = 220,
  TEXT_INSET = 16,
  TAB_HEIGHT = 22,
  ROW_HEIGHT = 18,
  CHAR_SLOT_COL_W = 88,
  CHAR_ACQUIRED_W = 24,
  CHAR_ITEM_COL_GAP = 6,
  INDENT_ENCOUNTER = 14,
  INDENT_LOOT = 28,
}

UI.updateAccumulator = UI.updateAccumulator or 0
UI.updateIntervalSeconds = UI.updateIntervalSeconds or 0.5

UI.activeTab = UI.activeTab or "characters"
UI.expandedInstances = UI.expandedInstances or {}
UI.focusInstanceId = UI.focusInstanceId or nil
UI.returnContext = UI.returnContext or nil
UI.focusEncounterId = UI.focusEncounterId or nil
UI.encounterLootView = UI.encounterLootView or "actual"
UI.charListSortBy = UI.charListSortBy or "recent"
UI.charListSortNameDescending = UI.charListSortNameDescending or false
UI.charListSortClassDescending = UI.charListSortClassDescending or false
