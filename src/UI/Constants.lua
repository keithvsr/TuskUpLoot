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
  TEXT_INSET = 16,
  TAB_HEIGHT = 22,
  ROW_HEIGHT = 18,
  INDENT_ENCOUNTER = 14,
  INDENT_LOOT = 28,
}

UI.updateAccumulator = UI.updateAccumulator or 0
UI.updateIntervalSeconds = UI.updateIntervalSeconds or 0.5

UI.activeTab = UI.activeTab or "characters"
UI.expandedInstances = UI.expandedInstances or {}
UI.expandedEncounters = UI.expandedEncounters or {}
UI.focusInstanceId = UI.focusInstanceId or nil
UI.focusEncounterId = UI.focusEncounterId or nil
