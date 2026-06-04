-- Guild member picker for sync push target.

local UI = TuskUpLoot.UI
local Util = UI.Util
local C = UI.Constants

local pendingCallback

local function normalizePlayerName(name)
  if Ambiguate then
    return Ambiguate(name, "short")
  end
  return name
end

local function requestGuildRoster()
  if C_GuildInfo and C_GuildInfo.GuildRoster then
    C_GuildInfo.GuildRoster()
    -- elseif GuildRoster then
    --   GuildRoster()
  end
end

local function isMemberOnline(status)
  if not status then
    return false
  end
  if status == 0 or status == 1 then
    return true
  end
  return false
end

local function collectOnlineGuildMembers()
  local members = {}
  if not IsInGuild or not IsInGuild() then
    return members
  end

  requestGuildRoster()
  local n = GetNumGuildMembers and GetNumGuildMembers() or 0
  local selfName = normalizePlayerName(UnitName("player") or "")

  for i = 1, n do
    local name, _, _, _, _, _, _, _, isOnline, status = GetGuildRosterInfo(i)
    if name then
      local short = normalizePlayerName(name)
      local online = isOnline
      if online == nil and status ~= nil then
        online = isMemberOnline(status)
      end
      if online and short ~= selfName then
        members[#members + 1] = { name = short, fullName = name }
      end
    end
  end

  table.sort(members, function(a, b)
    return (a.name or "") < (b.name or "")
  end)

  return members
end

function UI.rebuildSyncPickerList()
  if not UI.syncPickerContainer then
    return
  end

  local container = UI.syncPickerContainer
  if container.buttons then
    for _, b in ipairs(container.buttons) do
      b:Hide()
    end
  end
  container.buttons = container.buttons or {}

  local members = collectOnlineGuildMembers()
  local y = -6
  local btnHeight = 20
  local i = 0

  if #members == 0 then
    if not container.emptyFS then
      container.emptyFS = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      container.emptyFS:SetPoint("TOPLEFT", container, "TOPLEFT", 6, -6)
      container.emptyFS:SetWidth(container:GetWidth() - 12)
      container.emptyFS:SetJustifyH("LEFT")
    end
    container.emptyFS:SetText("No online guild members found.")
    container.emptyFS:Show()
    container:SetHeight(30)
    return
  end

  if container.emptyFS then
    container.emptyFS:Hide()
  end

  for _, row in ipairs(members) do
    i = i + 1
    local btn = Util.getOrCreateListButton(container, container.buttons, i, btnHeight)
    btn:ClearAllPoints()
    btn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, y)
    btn:SetPoint("RIGHT", container, "RIGHT", 0, 0)
    btn.text:SetText(row.name)

    local capture = row.name
    btn:SetScript("OnClick", function()
      if pendingCallback then
        pendingCallback(capture)
      end
      if UI.syncPickerFrame then
        UI.syncPickerFrame:Hide()
      end
      pendingCallback = nil
    end)
    btn:Show()
    y = y - btnHeight
  end

  container:SetHeight(math.max(1, (i * btnHeight) + 12))
end

function UI.ensureSyncPickerFrame()
  if UI.syncPickerFrame then
    return
  end

  local f = CreateFrame("Frame", "TuskUpLootSyncPickerFrame", UIParent, "UIPanelDialogTemplate")
  f:SetSize(320, 360)
  f:SetPoint("CENTER")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetFrameLevel(200)
  f:Hide()

  if UISpecialFrames then
    local found = false
    for _, name in ipairs(UISpecialFrames) do
      if name == "TuskUpLootSyncPickerFrame" then
        found = true
        break
      end
    end
    if not found then
      table.insert(UISpecialFrames, "TuskUpLootSyncPickerFrame")
    end
  end

  Util.setCloseButtonPlacement(f)
  -- local close = _G["TuskUpLootSyncPickerFrameCloseButton"] or _G["TuskUpLootSyncPickerFrameClose"]
  -- if close then
  --   close:ClearAllPoints()
  --   close:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 1)
  -- end

  local dragRegion = CreateFrame("Frame", nil, f)
  dragRegion:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
  dragRegion:SetPoint("TOPRIGHT", f, "TOPRIGHT", -44, -10)
  dragRegion:SetHeight(26)
  dragRegion:EnableMouse(true)
  dragRegion:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" then
      f:StartMoving()
    end
  end)
  dragRegion:SetScript("OnMouseUp", function()
    f:StopMovingOrSizing()
  end)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", f, "TOP", 0, -8)
  title:SetText("Push to guild member")

  local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hint:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -40)
  hint:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -40)
  hint:SetJustifyH("LEFT")
  hint:SetText("Select an online guild member to receive your data.")

  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -8)
  scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -32, 16)

  local container = CreateFrame("Frame", nil, scroll)
  container:SetWidth(260)
  container:SetHeight(1)
  scroll:SetScrollChild(container)

  UI.syncPickerFrame = f
  UI.syncPickerScroll = scroll
  UI.syncPickerContainer = container

  f:SetScript("OnShow", function()
    requestGuildRoster()
    UI.rebuildSyncPickerList()
  end)

  f:SetScript("OnHide", function()
    f:UnregisterEvent("GUILD_ROSTER_UPDATE")
    pendingCallback = nil
  end)
end

function UI.showSyncPicker(onSelect)
  return -- sync disabled
  --[[
  if not TuskUpLoot.isInRequiredGuild or not TuskUpLoot.isInRequiredGuild() then
    Util.safeChatPrint("Sync is only available to members of the required guild.")
    return
  end

  pendingCallback = onSelect
  UI.ensureSyncPickerFrame()
  if UI.syncPickerFrame then
    UI.syncPickerFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
    UI.syncPickerFrame:SetScript("OnEvent", function(_, event)
      if event == "GUILD_ROSTER_UPDATE" then
        UI.rebuildSyncPickerList()
      end
    end)
    if UI.frame and UI.frame:IsShown() then
      UI.syncPickerFrame:SetFrameLevel(UI.frame:GetFrameLevel() + 50)
    end
    UI.syncPickerFrame:Raise()
    UI.syncPickerFrame:Show()
  end
  --]]
end
