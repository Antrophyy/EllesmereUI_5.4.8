-------------------------------------------------------------------------------
--  EllesmereUIQoL_RaidTools.lua (5.4.8 port of retail Raid Tools)
--
--  Raid control panels: ready check, role check, pull timer, convert,
--  disband, target markers and world markers. Show as One Window, Two
--  Windows, Only Group & Pull, Only Markers or a Compact Band. Optional
--  collapsed icon, a Toggle Raid Tools keybind and Quick Fire world-marker
--  keybinds. Settings: EllesmereUIQoLDB.raidTools (retail profile.raidTools),
--  same keys and defaults as retail.
--
--  Same combat model as retail: window shells are SecureHandlerState frames
--  shown by a state driver ([group:raid] / [group]) and by secure snippets
--  (keybind, collapse, expand); Lua changes them only out of combat
--  (deferred to PLAYER_REGEN_ENABLED).
--
--  5.4.8 differences:
--    * Mists has 5 world markers (1 Blue, 2 Green, 3 Purple, 4 Red, 5 Yellow),
--      shown as colored squares. On the Compact Band a symbol gets the world
--      marker of the same look in later clients (Square Blue, Triangle Green,
--      Diamond Purple, Cross Red, Star Yellow); Circle, Moon and Skull have
--      none in Mists.
--    * A world marker cannot be dropped at the cursor in Mists: Place (and
--      the world marker buttons) start the ground targeting circle, click
--      the ground to drop it.
--    * No Blizzard countdown (C_PartyInfo.DoCountdown): the pull timer runs
--      through DBM / BigWigs; without one, a DBM pull sync is sent so raid
--      members with DBM still get the timer.
--    * Target markers are plain Lua (SetRaidTarget is not protected in Mists).
-------------------------------------------------------------------------------
local addonName = ...
local ns = EllesmereUI

local floor, max = math.floor, math.max

local R = {}  -- module table (keeps the local count low)
ns.RaidTools = R

local MEDIA = "Interface\\AddOns\\EllesmereUIQoL\\Media\\"
local SKIN_BG_TEX = MEDIA .. "modern_blizz"
local COLLAPSED_ICON_TEX = MEDIA .. "raid-tools"
local MARKER_SHEET = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"

local PANEL_W, PAD, TOPBAR_H = 236, 10, 25
local CONTENT_TOP = TOPBAR_H + 6
local ROW_H, ROW_GAP = 22, 4
local MARKER_SZ, MARKER_LBL_H, ICON_SZ = 23, 10, 30
local COMPACT_H, COMPACT_W, COMPACT_MIN_W, COMPACT_MIN_H = 40, 400, 365, 28
local COMPACT_PAD, COMPACT_ICON, COMPACT_GAP, COMPACT_DIVIDER_OFFSET = 6, 28, 4, 5
local PULL_SLOTS = 3
local PULL_DEFAULTS = { 3, 5, 10 }

local BG_ASPECT = 561 / 433
local BASE_L, BASE_R, BASE_T, BASE_B = 0.25, 1, 0, 0.75
local BASE_U, BASE_V = BASE_R - BASE_L, BASE_B - BASE_T

-- Mists world markers.
local WORLD_COUNT = 5
local WORLD_COLOR = {
	{ 0.12, 0.45, 1.0 },  -- 1 Blue
	{ 0.15, 0.85, 0.2 },  -- 2 Green
	{ 0.7, 0.25, 1.0 },   -- 3 Purple
	{ 1.0, 0.15, 0.15 },  -- 4 Red
	{ 1.0, 0.9, 0.15 },   -- 5 Yellow
}
local WORLD_NAME = { "Blue", "Green", "Purple", "Red", "Yellow" }
-- Target symbol -> Mists world marker of the same look (nil = none).
local SYMBOL_TO_WORLD = { 5, nil, 3, 2, nil, 1, 4, nil }
local MARKER_NAME = { "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }

local SECTIONS = {
	{ key = "Group", label = "Group & Pull" },
	{ key = "Markers", label = "Markers" },
}
local SECTION_KEYS, SECTION_LABEL = {}, {}
for _, def in ipairs(SECTIONS) do
	SECTION_KEYS[#SECTION_KEYS + 1] = def.key
	SECTION_LABEL[def.key] = def.label
end
local COMBINED_LABEL = "Raid Tools"
local UNLOCK_KEY = "EUI_RaidTools_"
local COMPACT_UNLOCK_KEY = UNLOCK_KEY .. "Compact"

local S = {        -- runtime state
	sections = {}, shellTitle = {}, fontOwners = {},
	groupButtons = {}, markerButtons = {}, pullButtons = {},
	compactMarkerButtons = {}, runtime = {},
}

-------------------------------------------------------------------------------
--  Settings
-------------------------------------------------------------------------------
local function Defaults()
	return {
		mode = "never",
		toggleKey = false,
		quickFire = false,
		quickFirePlaceKey = false,
		quickFireUndoKey = false,
		quickFireClearKey = false,
		collapsedIcon = true,
		showAs = "one",
		compactWidth = COMPACT_W,
		compactHeight = COMPACT_H,
		scale = 1,
		pullTimes = { PULL_DEFAULTS[1], PULL_DEFAULTS[2], PULL_DEFAULTS[3] },
		showRoleCheck = true,
		showConvert = true,
		showDisband = true,
		growDir = "downright",
		pos = {},
	}
end
R.Defaults = Defaults
R.PULL_DEFAULTS = PULL_DEFAULTS

local function SeedRetail(t)
	t.mode = "raid"
	t.showAs = "one"
	t.scale = 1.2
	t.growDir = "upright"
	t.collapsedIcon = true
	t.compactWidth, t.compactHeight = 400, 40
	t.pullTimes = { 10, 15, 20 }
	t.pos = { Group = { point = "CENTER", relPoint = "CENTER", x = -1137.4000032328, y = -251.4002051429771 } }
end

local firstLook = true
local function P()
	local q = ns.GetQoLDB and ns.GetQoLDB()
	if type(q) ~= "table" then return nil end
	local t = q.raidTools
	if type(t) ~= "table" then
		t = {}
		q.raidTools = t
	end
	if t._seeded ~= 1 then
		if firstLook and next(t) == nil then SeedRetail(t) end
		ns.CopyDefaults(Defaults(), t)
		t._seeded = 1
	end
	firstLook = false
	return t
end
ns.GetRaidToolsDB = P

local function Mode()
	local p = P()
	return (p and p.mode) or "never"
end

local function ShowAs()
	local p = P()
	local v = p and p.showAs
	if v ~= "compact" and v ~= "one" and v ~= "two" and v ~= "group" and v ~= "markers" then v = "one" end
	return v
end
R.ShowAs = ShowAs

local function CompactWidth() local p = P(); return max(COMPACT_MIN_W, (p and p.compactWidth) or COMPACT_W) end
local function CompactHeight() local p = P(); return max(COMPACT_MIN_H, (p and p.compactHeight) or COMPACT_H) end
local function WindowScale() local p = P(); return (p and p.scale) or 1 end

-------------------------------------------------------------------------------
--  Look (Window Skins dress, flat 1 px borders: no atlases in 5.4.8)
-------------------------------------------------------------------------------
local function Font()
	return (ns.GetFontPath and ns.GetFontPath("qol")) or STANDARD_TEXT_FONT
end

local function MakeFont(parent, size)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont(Font(), size, "")
	if not fs:GetFont() then fs:SetFont(STANDARD_TEXT_FONT, size, "") end
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetTextColor(1, 1, 1)
	return fs
end

local function TrackFont(owner, fs, size)
	owner.euiFonts = owner.euiFonts or {}
	owner.euiFonts[#owner.euiFonts + 1] = { fs = fs, size = size }
	return fs
end

local function ApplyFonts()
	local path = Font()
	for _, owner in ipairs(S.fontOwners) do
		for _, e in ipairs(owner.euiFonts or {}) do
			e.fs:SetFont(path, e.size, "")
		end
	end
end

local function Border(f, r, g, b, a, level)
	local holder = CreateFrame("Frame", nil, f)
	holder:SetAllPoints(f)
	holder:SetFrameLevel(f:GetFrameLevel() + (level or 1))
	local function Line()
		local t = holder:CreateTexture(nil, "OVERLAY")
		t:SetTexture(r, g, b, a)
		return t
	end
	local top, bottom, left, right = Line(), Line(), Line(), Line()
	top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(1)
	bottom:SetPoint("BOTTOMLEFT"); bottom:SetPoint("BOTTOMRIGHT"); bottom:SetHeight(1)
	left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT"); left:SetWidth(1)
	right:SetPoint("TOPRIGHT"); right:SetPoint("BOTTOMRIGHT"); right:SetWidth(1)
	return holder
end

local function SkinPanel(f)
	local bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
	bg:SetTexture(SKIN_BG_TEX)
	bg:SetAllPoints(f)
	local overlay = f:CreateTexture(nil, "BACKGROUND", nil, -7)
	overlay:SetTexture(0, 0, 0, 0.62)
	overlay:SetAllPoints(f)
	local topBar = f:CreateTexture(nil, "BACKGROUND", nil, -5)
	topBar:SetTexture(0, 0, 0, 0.5)
	topBar:SetPoint("TOPLEFT")
	topBar:SetPoint("TOPRIGHT")
	topBar:SetHeight(TOPBAR_H)
	f.euiBgArt, f.euiTitleBar = bg, topBar
	f.euiBgFit = function()
		local fw, fh = f:GetWidth(), f:GetHeight()
		if not fw or fw == 0 or not fh or fh == 0 then return end
		local fa = fw / fh
		if fa > BG_ASPECT then
			local trim = (BASE_V - BASE_V * (BG_ASPECT / fa)) / 2
			bg:SetTexCoord(BASE_L, BASE_R, BASE_T + trim, BASE_B - trim)
		else
			local trim = (BASE_U - BASE_U * (fa / BG_ASPECT)) / 2
			bg:SetTexCoord(BASE_L + trim, BASE_R - trim, BASE_T, BASE_B)
		end
	end
	f.euiBorder = Border(f, 0.2, 0.2, 0.2, 1, 6)
end

local function SkinButtonChrome(b)
	local fill = b:CreateTexture(nil, "BACKGROUND")
	fill:SetTexture(0.08, 0.08, 0.08, 0.92)
	fill:SetAllPoints(b)
	Border(b, 0.2, 0.2, 0.2, 1, 1)
	local hover = b:CreateTexture(nil, "HIGHLIGHT")
	hover:SetTexture(1, 1, 1, 0.1)
	hover:SetAllPoints(b)
end

-------------------------------------------------------------------------------
--  Permissions
-------------------------------------------------------------------------------
local previewOn = false

local function HasAssist()
	if not IsInGroup() then return true end
	return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end
local function IsLeader()
	if not IsInGroup() then return true end
	return UnitIsGroupLeader("player")
end
-- In a raid every control needs leader or assist: hide it all without.
local function AssistSuppressed()
	if previewOn then return false end
	return IsInRaid() and not HasAssist()
end
local function ButtonShown(key)
	local p = P()
	return not p or p[key] ~= false
end

local function PullTime(slot)
	local times = (P() and P().pullTimes) or {}
	local v = times[slot]
	if v == nil then v = PULL_DEFAULTS[slot] end
	return v and v > 0 and v or nil
end

local function SetButtonEnabled(b, on)
	b:SetAlpha(on and 1 or 0.35)
	b:EnableMouse(on)
end

local lastAssist, lastLeader, lastRaid
R.RefreshPermissions = function(force)
	local assist, leader, raid = HasAssist(), IsLeader(), IsInRaid()
	if not force and assist == lastAssist and leader == lastLeader and raid == lastRaid then return end
	lastAssist, lastLeader, lastRaid = assist, leader, raid
	for _, b in ipairs(S.groupButtons) do
		SetButtonEnabled(b, (b.needsLeader and leader or assist) and true or false)
	end
	for _, b in ipairs(S.markerButtons) do
		b.baseAlpha = assist and 0.8 or 0.4
		b.icon:SetAlpha(b.baseAlpha)
	end
	if S.convertButton then
		S.convertButton.lbl:SetText(raid and "Convert to Party" or "Convert to Raid")
	end
end

-------------------------------------------------------------------------------
--  Pull timer (DBM / BigWigs; DBM pull sync when neither is loaded)
-------------------------------------------------------------------------------
local function SendDBMPull(secs)
	if not IsInGroup() then return end
	local mapID = select(8, GetInstanceInfo()) or 0
	local channel = IsInRaid() and "RAID" or "PARTY"
	SendAddonMessage("D4", "PT\t" .. secs .. "\t" .. mapID, channel)
end

local function RunPull(secs)
	if SlashCmdList.BIGWIGSPULL then
		SlashCmdList.BIGWIGSPULL(tostring(secs))
	elseif SlashCmdList.DEADLYBOSSMODSPULL then
		SlashCmdList.DEADLYBOSSMODSPULL(tostring(secs))
	elseif SlashCmdList.DEADLYBOSSMODS then
		SlashCmdList.DEADLYBOSSMODS("pull " .. secs)
	else
		SendDBMPull(secs)
	end
end
R.StartPull = function(secs) if secs then RunPull(secs) end end
R.StopPull = function() RunPull(0) end

local function DisbandGroup()
	if not IsLeader() then return end
	local me = UnitName("player")
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do
			local name = GetRaidRosterInfo(i)
			if name and name ~= me then UninviteUnit(name) end
		end
	else
		for i = 1, GetNumSubgroupMembers() do
			local name = UnitName("party" .. i)
			if name then UninviteUnit(name) end
		end
	end
	LeaveParty()
end

local function ConfirmDisband()
	-- The settings window's confirm popup lives in the load-on-demand
	-- options addon; StaticPopup is the always-there fallback.
	if ns.ShowConfirmPopup then
		ns.ShowConfirmPopup({ title = "Disband Group", message = "Disband the group?",
			confirmText = "Disband", cancelText = "Cancel", onConfirm = DisbandGroup })
		return
	end
	StaticPopupDialogs.EUI_RAIDTOOLS_DISBAND = StaticPopupDialogs.EUI_RAIDTOOLS_DISBAND or {
		text = "Disband the group?", button1 = "Disband", button2 = CANCEL,
		OnAccept = function() DisbandGroup() end,
		timeout = 0, whileDead = true, hideOnEscape = true,
	}
	StaticPopup_Show("EUI_RAIDTOOLS_DISBAND")
end

-------------------------------------------------------------------------------
--  Compact tooltip (left / right columns)
-------------------------------------------------------------------------------
local function ShowTip(owner, title, rows)
	GameTooltip:SetOwner(owner, "ANCHOR_TOP")
	GameTooltip:ClearLines()
	GameTooltip:AddLine("[" .. title .. "]", 1, 1, 1)
	for _, r in ipairs(rows) do
		GameTooltip:AddDoubleLine(r[1], r[2], 1, 1, 1, 1, 1, 1)
	end
	GameTooltip:Show()
end
local function HideTip() GameTooltip:Hide() end

-------------------------------------------------------------------------------
--  Buttons
-------------------------------------------------------------------------------
local function MakeGroupButton(parent, text, width, onClick, needsLeader)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width, ROW_H)
	SkinButtonChrome(b)
	local lbl = TrackFont(parent, MakeFont(b, 11), 11)
	lbl:SetPoint("CENTER")
	lbl:SetText(text)
	b:SetScript("OnClick", onClick)
	b.lbl = lbl
	b.needsLeader = needsLeader
	S.groupButtons[#S.groupButtons + 1] = b
	return b
end

-- Target marker: plain button (left = toggle on target, right = clear).
local function MakeTargetMarker(parent, index)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(MARKER_SZ, MARKER_SZ)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetAllPoints()
	if index == 0 then
		b.icon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
	else
		b.icon:SetTexture(MARKER_SHEET)
		SetRaidTargetIconTexture(b.icon, index)
	end
	b:SetScript("OnClick", function(_, button)
		if not UnitExists("target") then return end
		if index == 0 or button == "RightButton" then
			SetRaidTarget("target", 0)
		elseif GetRaidTargetIndex("target") == index then
			SetRaidTarget("target", 0)
		else
			SetRaidTarget("target", index)
		end
	end)
	b.icon:SetAlpha(0.8)
	b.baseAlpha = 0.8
	b:SetScript("OnEnter", function(self) if self.baseAlpha >= 0.8 then self.icon:SetAlpha(1) end end)
	b:SetScript("OnLeave", function(self) self.icon:SetAlpha(self.baseAlpha) end)
	S.markerButtons[#S.markerButtons + 1] = b
	return b
end

-- World marker: secure "worldmarker" action (left = place, right = clear;
-- index 0 = clear all).
local function MakeWorldMarker(parent, index)
	local b = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
	b:SetSize(MARKER_SZ, MARKER_SZ)
	b:RegisterForClicks("AnyUp")
	b:SetAttribute("type", "worldmarker")
	b.icon = b:CreateTexture(nil, "ARTWORK")
	if index == 0 then
		b:SetAttribute("action", "clear")
		b.icon:SetAllPoints()
		b.icon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
	else
		b:SetAttribute("marker", tostring(index))
		b:SetAttribute("action1", "set")
		b:SetAttribute("action2", "clear")
		b.icon:SetPoint("TOPLEFT", 4, -4)
		b.icon:SetPoint("BOTTOMRIGHT", -4, 4)
		local c = WORLD_COLOR[index]
		b.icon:SetTexture(c[1], c[2], c[3], 1)
		Border(b, 0, 0, 0, 1, 1)
	end
	b.icon:SetAlpha(0.8)
	b.baseAlpha = 0.8
	b:SetScript("OnEnter", function(self)
		if self.baseAlpha >= 0.8 then self.icon:SetAlpha(1) end
		if index > 0 then
			ShowTip(self, WORLD_NAME[index] .. " World Marker", { { "Left Click", "Place" }, { "Right Click", "Clear" } })
		else
			ShowTip(self, "Clear World Markers", { { "Click", "Clear all world markers" } })
		end
	end)
	b:SetScript("OnLeave", function(self) self.icon:SetAlpha(self.baseAlpha); HideTip() end)
	S.markerButtons[#S.markerButtons + 1] = b
	return b
end

-- Compact symbol: left = toggle target marker, shift-left = clear target
-- marker; right = place the matching world marker, shift-right = clear it.
local function MakeCompactMarker(parent, index)
	local b = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
	b:SetSize(COMPACT_ICON, COMPACT_ICON)
	b:RegisterForClicks("AnyUp")
	local world = index > 0 and SYMBOL_TO_WORLD[index] or nil
	if index == 0 then
		b:SetAttribute("type2", "worldmarker")
		b:SetAttribute("action2", "clear")
	elseif world then
		b:SetAttribute("type2", "worldmarker")
		b:SetAttribute("marker2", tostring(world))
		b:SetAttribute("action2", "set")
		b:SetAttribute("shift-type2", "worldmarker")
		b:SetAttribute("shift-marker2", tostring(world))
		b:SetAttribute("shift-action2", "clear")
	end
	b.worldID = world
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetAllPoints()
	if index == 0 then
		b.icon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
	else
		b.icon:SetTexture(MARKER_SHEET)
		SetRaidTargetIconTexture(b.icon, index)
	end
	if world then
		b.active = b:CreateTexture(nil, "OVERLAY")
		b.active:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 2, -2)
		b.active:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, -2)
		b.active:SetHeight(2)
		local r, g, bl = 0.05, 0.82, 0.62
		if ns.ResolveAccent then r, g, bl = ns.ResolveAccent() end
		b.active:SetTexture(r, g, bl, 0.95)
		b.active:Hide()
	end
	-- Left clicks: target markers in Lua after the secure click.
	b:HookScript("OnClick", function(_, button)
		if button ~= "LeftButton" or not UnitExists("target") then return end
		if index == 0 or IsShiftKeyDown() or GetRaidTargetIndex("target") == index then
			SetRaidTarget("target", 0)
		else
			SetRaidTarget("target", index)
		end
	end)
	b.icon:SetAlpha(0.8)
	b.baseAlpha = 0.8
	b:SetScript("OnEnter", function(self)
		if self.baseAlpha >= 0.8 then self.icon:SetAlpha(1) end
		if index == 0 then
			ShowTip(self, "Clear Markers", { { "Left Click", "Clear target marker" }, { "Right Click", "Clear all world markers" } })
		elseif world then
			ShowTip(self, MARKER_NAME[index], {
				{ "Left Click", "Toggle target marker" }, { "Right Click", "Place " .. WORLD_NAME[world] .. " world marker" },
				{ "Shift + Left Click", "Clear target marker" }, { "Shift + Right Click", "Clear " .. WORLD_NAME[world] .. " world marker" },
			})
		else
			ShowTip(self, MARKER_NAME[index], { { "Left Click", "Toggle target marker" }, { "Shift + Left Click", "Clear target marker" } })
		end
	end)
	b:SetScript("OnLeave", function(self) self.icon:SetAlpha(self.baseAlpha); HideTip() end)
	S.markerButtons[#S.markerButtons + 1] = b
	return b
end

-------------------------------------------------------------------------------
--  Secure snippets (retail, unchanged)
-------------------------------------------------------------------------------
local RUN_APPLY = [[ self:RunAttribute("apply") ]]

local APPLY_SHELL = [[
	if not self:GetAttribute("enabled") then self:Hide() return end
	local ov = self:GetAttribute("override")
	local vis
	if ov == "show" then vis = true elseif ov == "hide" then vis = false else vis = self:GetAttribute("visible") end
	if vis and self:GetAttribute("expanded") then self:Show() else self:Hide() end
]]
local APPLY_ICON = [[
	if not self:GetAttribute("enabled") then self:Hide() return end
	local ov = self:GetAttribute("override")
	local vis
	if ov == "show" then vis = true elseif ov == "hide" then vis = false else vis = self:GetAttribute("visible") end
	if vis and not self:GetAttribute("expanded") then self:Show() else self:Hide() end
]]
local ONSTATE = [[
	local vis = (newstate == "show")
	self:SetAttribute("visible", vis)
	self:SetAttribute("override", "")
	self:SetAttribute("expanded", self:GetAttribute("startexpanded"))
	self:RunAttribute("apply")
	local icon = self:GetFrameRef("icon")
	if icon then
		icon:SetAttribute("visible", vis)
		icon:SetAttribute("override", "")
		icon:SetAttribute("expanded", self:GetAttribute("startexpanded"))
		icon:RunAttribute("apply")
	end
]]
local TOGGLE_SNIPPET = [[
	local n = self:GetAttribute("count") or 0
	local icon = self:GetFrameRef("icon")
	local anyWin, iconShown = false, false
	for i = 1, n do
		local f = self:GetFrameRef("s" .. i)
		if f and f:IsShown() then anyWin = true end
	end
	if icon and icon:IsShown() then iconShown = true end
	local collapseMode = icon and not icon:GetAttribute("startexpanded")
	if collapseMode then
		local expand = not anyWin
		for i = 1, n do
			local f = self:GetFrameRef("s" .. i)
			if f then
				if expand then f:SetAttribute("override", "show") end
				f:SetAttribute("expanded", expand)
				f:RunAttribute("apply")
			end
		end
		if expand then icon:SetAttribute("override", "show") end
		icon:SetAttribute("expanded", expand)
		icon:RunAttribute("apply")
		return
	end
	local ov
	if anyWin or iconShown then ov = "hide" else ov = "show" end
	for i = 1, n do
		local f = self:GetFrameRef("s" .. i)
		if f then
			f:SetAttribute("override", ov)
			if ov == "show" then f:SetAttribute("expanded", f:GetAttribute("startexpanded")) end
			f:RunAttribute("apply")
		end
	end
	if icon then
		icon:SetAttribute("override", ov)
		if ov == "show" then icon:SetAttribute("expanded", icon:GetAttribute("startexpanded")) end
		icon:RunAttribute("apply")
	end
]]
local EXPAND_SNIPPET = [[
	local n = self:GetAttribute("count") or 0
	for i = 1, n do
		local f = self:GetFrameRef("s" .. i)
		if f then
			f:SetAttribute("expanded", true)
			f:RunAttribute("apply")
		end
	end
	self:SetAttribute("expanded", true)
	self:RunAttribute("apply")
]]
local COLLAPSE_SNIPPET = [[
	local n = self:GetAttribute("count") or 0
	for i = 1, n do
		local f = self:GetFrameRef("s" .. i)
		if f then
			f:SetAttribute("expanded", false)
			f:RunAttribute("apply")
		end
	end
	local icon = self:GetFrameRef("icon")
	if icon then
		icon:SetAttribute("expanded", false)
		icon:RunAttribute("apply")
	end
]]

-------------------------------------------------------------------------------
--  Frames (built once, out of combat)
-------------------------------------------------------------------------------
local function MakeShell(key)
	local f = CreateFrame("Frame", "EllesmereUIRaidTools" .. key, UIParent, "SecureHandlerStateTemplate")
	f:SetWidth(PANEL_W)
	f:SetHeight(60)
	f:SetFrameStrata("MEDIUM")
	f:SetClampedToScreen(true)
	f:Hide()
	SkinPanel(f)
	f:SetAttribute("enabled", true)
	f:SetAttribute("visible", false)
	f:SetAttribute("override", "")
	f:SetAttribute("expanded", true)
	f:SetAttribute("startexpanded", true)
	f:SetAttribute("apply", APPLY_SHELL)
	f:SetAttribute("_onstate-euirt_vis", ONSTATE)

	local fs = TrackFont(f, MakeFont(f, 12), 12)
	fs:SetPoint("LEFT", f, "TOPLEFT", PAD, -TOPBAR_H / 2)
	fs:SetText(SECTION_LABEL[key])
	S.shellTitle[key] = fs

	local col = CreateFrame("Button", nil, f, "SecureHandlerClickTemplate")
	col:SetSize(14, 14)
	col:SetPoint("RIGHT", f, "TOPRIGHT", -6, -TOPBAR_H / 2)
	col:RegisterForClicks("AnyUp")
	SkinButtonChrome(col)
	local colFs = TrackFont(f, MakeFont(col, 14), 14)
	colFs:SetPoint("CENTER", col, "CENTER", 0, 1)
	colFs:SetText("-")
	colFs:SetAlpha(0.7)
	col:SetScript("OnEnter", function() colFs:SetAlpha(1) end)
	col:SetScript("OnLeave", function() colFs:SetAlpha(0.7) end)
	col:SetAttribute("_onclick", COLLAPSE_SNIPPET)
	f.euiCollapse = col

	S.sections[key] = f
	S.fontOwners[#S.fontOwners + 1] = f
	return f
end

-- Places the Group & Pull buttons (rows of two, pull row) and sets the height.
R.LayoutGroupContent = function()
	local f = S.groupHolder
	if not f then return end
	local rows, pair = {}, {}
	local function Add(b)
		pair[#pair + 1] = b
		if #pair == 2 then rows[#rows + 1] = pair; pair = {} end
	end
	Add(S.readyButton)
	if ButtonShown("showRoleCheck") then Add(S.roleButton) end
	if ButtonShown("showConvert") then Add(S.convertButton) end
	if ButtonShown("showDisband") then Add(S.disbandButton) end
	if #pair > 0 then rows[#rows + 1] = pair end

	local pull = {}
	for i = 1, PULL_SLOTS do
		local secs = PullTime(i)
		if secs then
			local b = S.pullButtons[#pull + 1]
			b.secs = secs
			b.lbl:SetText(tostring(secs))
			pull[#pull + 1] = b
		end
	end
	if #pull > 0 then
		pull[#pull + 1] = S.stopButton
		rows[#rows + 1] = pull
	end

	for _, b in ipairs(S.groupButtons) do
		if b:GetParent() == f then b:Hide() end
	end
	local y = 0
	for _, row in ipairs(rows) do
		local n = #row
		local w = (PANEL_W - PAD * 2 - ROW_GAP * (n - 1)) / n
		for i, b in ipairs(row) do
			b:SetWidth(w)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + (w + ROW_GAP) * (i - 1), y)
			b:Show()
		end
		y = y - ROW_H - ROW_GAP
	end
	y = y + ROW_GAP
	S.groupContentH = -y
	f:SetHeight(max(1, S.groupContentH))
end

local function BuildGroupContent()
	local f = CreateFrame("Frame", nil, S.sections.Group)
	f:SetWidth(PANEL_W)
	S.groupHolder = f
	S.fontOwners[#S.fontOwners + 1] = f
	local full = PANEL_W - PAD * 2
	S.readyButton = MakeGroupButton(f, "Ready Check", full, function() DoReadyCheck() end)
	S.roleButton = MakeGroupButton(f, "Role Check", full, function() InitiateRolePoll() end)
	S.convertButton = MakeGroupButton(f, "Convert to Raid", full, function()
		if IsInRaid() then ConvertToParty() else ConvertToRaid() end
	end, true)
	S.disbandButton = MakeGroupButton(f, "Disband", full, ConfirmDisband, true)
	for i = 1, PULL_SLOTS do
		local b
		b = MakeGroupButton(f, "", full, function() R.StartPull(b.secs) end)
		S.pullButtons[i] = b
	end
	S.stopButton = MakeGroupButton(f, "Stop", full, R.StopPull)
	R.LayoutGroupContent()
end

local function BuildMarkersContent()
	local f = CreateFrame("Frame", nil, S.sections.Markers)
	f:SetWidth(PANEL_W)
	S.markersHolder = f
	S.fontOwners[#S.fontOwners + 1] = f
	local y = 0
	local step = (PANEL_W - PAD * 2 - MARKER_SZ) / 8

	local lbl = TrackFont(f, MakeFont(f, 9), 9)
	lbl:SetAlpha(0.55)
	lbl:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
	lbl:SetText("Target Markers")
	y = y - MARKER_LBL_H - 2
	for i = 0, 8 do
		local b = MakeTargetMarker(f, i == 8 and 0 or (i + 1))
		b:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + step * i, y)
	end
	y = y - MARKER_SZ - ROW_GAP * 2

	lbl = TrackFont(f, MakeFont(f, 9), 9)
	lbl:SetAlpha(0.55)
	lbl:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
	lbl:SetText("World Markers")
	y = y - MARKER_LBL_H - 2
	for i = 0, WORLD_COUNT do
		local b = MakeWorldMarker(f, i == WORLD_COUNT and 0 or (i + 1))
		b:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + step * i, y)
	end
	y = y - MARKER_SZ
	S.markersContentH = -y
	f:SetHeight(S.markersContentH)
end

local function MakeCompactAction(parent, label, tipFn, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(COMPACT_ICON, COMPACT_ICON)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnClick", onClick)
	local fs = TrackFont(parent, MakeFont(b, 11), 11)
	fs:SetPoint("CENTER")
	fs:SetText(label)
	fs:SetAlpha(0.8)
	b.label = fs
	b:SetScript("OnEnter", function(self)
		self.label:SetAlpha(1)
		local title, rows = tipFn()
		ShowTip(self, title, rows)
	end)
	b:SetScript("OnLeave", function(self) self.label:SetAlpha(0.8); HideTip() end)
	S.groupButtons[#S.groupButtons + 1] = b
	return b
end

R.LayoutCompactMarkers = function()
	local holder, list = S.compactHolder, S.compactMarkerButtons
	if not holder or not S.sections.Group or #list < 2 then return end
	local width = S.sections.Group:GetWidth()
	if not width or width < COMPACT_MIN_W then return end
	local utilityCount = (S.compactPullButton and S.compactPullButton:IsShown()) and 2 or 1
	local utilityWidth = utilityCount * COMPACT_ICON + (utilityCount - 1) * COMPACT_GAP
	local lastLeft = width - COMPACT_PAD - utilityWidth - COMPACT_DIVIDER_OFFSET - COMPACT_GAP - COMPACT_ICON
	local stride = (lastLeft - COMPACT_PAD) / (#list - 1)
	for i, button in ipairs(list) do
		button:ClearAllPoints()
		button:SetPoint("LEFT", holder, "LEFT", floor(COMPACT_PAD + (i - 1) * stride + 0.5), 0)
	end
end

R.RefreshCompactPullState = function()
	local pullBtn, readyBtn = S.compactPullButton, S.compactReadyButton
	if not pullBtn then return end
	local secs = PullTime(3) or PullTime(2) or PullTime(1)
	pullBtn:SetShown(secs ~= nil)
	readyBtn:ClearAllPoints()
	readyBtn:SetPoint("RIGHT", S.compactHolder, "RIGHT", -COMPACT_PAD, 0)
	pullBtn:ClearAllPoints()
	if secs then pullBtn:SetPoint("RIGHT", readyBtn, "LEFT", -COMPACT_GAP, 0) end
	local first = secs and pullBtn or readyBtn
	S.compactDivider:ClearAllPoints()
	S.compactDivider:SetPoint("TOP", first, "TOPLEFT", -COMPACT_DIVIDER_OFFSET, -2)
	S.compactDivider:SetPoint("BOTTOM", first, "BOTTOMLEFT", -COMPACT_DIVIDER_OFFSET, 2)
	R.LayoutCompactMarkers()
end

-- A placed world marker greys nothing out but lights the accent line.
R.RefreshCompactMarkerState = function()
	if ShowAs() ~= "compact" then return end
	for _, b in ipairs(S.compactMarkerButtons) do
		if b.worldID and b.active then
			local active = IsRaidMarkerActive(b.worldID)
			b.active:SetShown(active and true or false)
			b.icon:SetDesaturated(active and true or false)
		end
	end
end

local function BuildCompactContent()
	local h = CreateFrame("Frame", nil, S.sections.Group)
	h:SetHeight(COMPACT_H)
	S.compactHolder = h
	S.fontOwners[#S.fontOwners + 1] = h
	for index = 1, 8 do
		S.compactMarkerButtons[#S.compactMarkerButtons + 1] = MakeCompactMarker(h, index)
	end
	S.compactMarkerButtons[#S.compactMarkerButtons + 1] = MakeCompactMarker(h, 0)

	S.compactReadyButton = MakeCompactAction(h, "RC",
		function()
			if ButtonShown("showRoleCheck") then
				return "Ready Check", { { "Left Click", "Ready Check" }, { "Right Click", "Role Check" } }
			end
			return "Ready Check", { { "Left Click", "Ready Check" } }
		end,
		function(_, button)
			if button == "RightButton" then
				if ButtonShown("showRoleCheck") then InitiateRolePoll() end
			else
				DoReadyCheck()
			end
		end)
	S.compactPullButton = MakeCompactAction(h, "PT",
		function()
			return "Pull Timer", {
				{ "Left Click", "Pull " .. (PullTime(3) or "off") },
				{ "Shift + Left Click", "Pull " .. (PullTime(2) or "off") },
				{ "Ctrl + Left Click", "Pull " .. (PullTime(1) or "off") },
				{ "Right Click", "Stop pull timer" },
			}
		end,
		function(_, button)
			if button == "RightButton" then R.StopPull(); return end
			local secs
			if IsControlKeyDown() then
				secs = PullTime(1)
			elseif IsShiftKeyDown() then
				secs = PullTime(2)
			else
				secs = PullTime(3) or PullTime(2) or PullTime(1)
			end
			R.StartPull(secs)
		end)
	S.compactDivider = h:CreateTexture(nil, "ARTWORK")
	S.compactDivider:SetTexture(1, 1, 1, 0.10)
	S.compactDivider:SetWidth(1)
	R.RefreshCompactPullState()
	R.RefreshCompactMarkerState()
end

local function BuildCollapsedIcon()
	local b = CreateFrame("Button", "EllesmereUIRaidToolsIcon", UIParent, "SecureHandlerClickTemplate")
	b:SetSize(ICON_SZ, ICON_SZ)
	b:SetFrameStrata("MEDIUM")
	b:SetClampedToScreen(true)
	b:RegisterForClicks("AnyUp")
	b:Hide()
	local tex = b:CreateTexture(nil, "ARTWORK")
	tex:SetAllPoints(b)
	tex:SetTexture(COLLAPSED_ICON_TEX)
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints(b)
	hl:SetTexture(COLLAPSED_ICON_TEX)
	hl:SetBlendMode("ADD")
	hl:SetAlpha(0.5)
	b:SetAttribute("enabled", true)
	b:SetAttribute("visible", false)
	b:SetAttribute("override", "")
	b:SetAttribute("expanded", true)
	b:SetAttribute("startexpanded", true)
	b:SetAttribute("apply", APPLY_ICON)
	b:SetAttribute("_onclick", EXPAND_SNIPPET)
	S.iconBtn = b
end

R.BuildAll = function()
	if S.sections.Group then return end
	MakeShell("Group")
	MakeShell("Markers")
	BuildGroupContent()
	BuildMarkersContent()
	BuildCollapsedIcon()
	local icon = S.iconBtn
	icon:SetPoint("TOPLEFT", S.sections.Group, "TOPLEFT", 0, 0)

	local tb = CreateFrame("Button", "EllesmereUIRaidToolsToggle", UIParent, "SecureHandlerClickTemplate")
	tb:SetSize(1, 1)
	tb:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -100, -100)
	tb:SetAlpha(0)
	tb:RegisterForClicks("AnyDown")
	tb:SetAttribute("count", #SECTION_KEYS)
	tb:SetAttribute("_onclick", TOGGLE_SNIPPET)
	S.toggleButton = tb

	for i, key in ipairs(SECTION_KEYS) do
		local shell = S.sections[key]
		SecureHandlerSetFrameRef(tb, "s" .. i, shell)
		SecureHandlerSetFrameRef(shell, "icon", icon)
		shell.euiCollapse:SetAttribute("count", #SECTION_KEYS)
		for j, k2 in ipairs(SECTION_KEYS) do
			SecureHandlerSetFrameRef(shell.euiCollapse, "s" .. j, S.sections[k2])
		end
		SecureHandlerSetFrameRef(shell.euiCollapse, "icon", icon)
		SecureHandlerSetFrameRef(icon, "s" .. i, shell)
	end
	SecureHandlerSetFrameRef(tb, "icon", icon)
	icon:SetAttribute("count", #SECTION_KEYS)
end

-------------------------------------------------------------------------------
--  Layout / position / visibility (out of combat only)
-------------------------------------------------------------------------------
local ICON_CORNER = { downright = "TOPLEFT", upright = "BOTTOMLEFT", downleft = "TOPRIGHT", upleft = "BOTTOMRIGHT" }

local function ApplyShellMaterial(f, compact)
	f.euiBgArt:SetShown(not compact)
	f.euiTitleBar:SetShown(not compact)
	f.euiBorder:SetShown(not compact)
end

R.ApplyLayout = function()
	local p = P()
	local showAs = ShowAs()
	local winGroup, winMarkers = S.sections.Group, S.sections.Markers
	local compact = showAs == "compact"
	local collapseUI = not compact and p.collapsedIcon ~= false
	winGroup.euiCollapse:SetShown(collapseUI)
	winMarkers.euiCollapse:SetShown(collapseUI and showAs ~= "two")
	ApplyShellMaterial(winGroup, compact)
	ApplyShellMaterial(winMarkers, false)
	S.shellTitle.Group:SetShown(not compact)
	if compact and not S.compactHolder then BuildCompactContent() end
	if S.compactHolder then S.compactHolder:SetShown(compact) end
	local gh, mh = S.groupHolder, S.markersHolder

	if compact then
		winGroup:SetWidth(CompactWidth())
		winGroup:SetHeight(CompactHeight())
		S.compactHolder:ClearAllPoints()
		S.compactHolder:SetAllPoints(winGroup)
		gh:Hide()
		mh:Hide()
	elseif showAs == "one" then
		winGroup:SetWidth(PANEL_W)
		S.shellTitle.Group:SetText(COMBINED_LABEL)
		gh:SetParent(winGroup); gh:Show(); gh:ClearAllPoints()
		gh:SetPoint("TOPLEFT", winGroup, "TOPLEFT", 0, -CONTENT_TOP)
		mh:SetParent(winGroup); mh:Show(); mh:ClearAllPoints()
		mh:SetPoint("TOPLEFT", winGroup, "TOPLEFT", 0, -CONTENT_TOP - S.groupContentH - ROW_GAP * 2)
		winGroup:SetHeight(CONTENT_TOP + S.groupContentH + ROW_GAP * 2 + S.markersContentH + PAD)
	else
		winGroup:SetWidth(PANEL_W)
		winMarkers:SetWidth(PANEL_W)
		S.shellTitle.Group:SetText(SECTION_LABEL.Group)
		gh:SetParent(winGroup); gh:Show(); gh:ClearAllPoints()
		gh:SetPoint("TOPLEFT", winGroup, "TOPLEFT", 0, -CONTENT_TOP)
		winGroup:SetHeight(CONTENT_TOP + S.groupContentH + PAD)
		mh:SetParent(winMarkers); mh:Show(); mh:ClearAllPoints()
		mh:SetPoint("TOPLEFT", winMarkers, "TOPLEFT", 0, -CONTENT_TOP)
		winMarkers:SetHeight(CONTENT_TOP + S.markersContentH + PAD)
	end
	-- Parenting changes reset frame levels of the content: keep it above the art.
	gh:SetFrameLevel(gh:GetParent():GetFrameLevel() + 2)
	mh:SetFrameLevel(mh:GetParent():GetFrameLevel() + 2)

	local corner = ICON_CORNER[p.growDir] or "TOPLEFT"
	S.iconBtn:ClearAllPoints()
	S.iconBtn:SetPoint(corner, (showAs == "markers") and winMarkers or winGroup, corner, 0, 0)
	winGroup.euiBgFit()
	winMarkers.euiBgFit()
	R.RefreshCompactPullState()
	R.RefreshCompactMarkerState()
end

local function DefaultPos(key)
	local margin, s = 20, WindowScale()
	local top = -margin
	if key == "Markers" then
		top = top - (S.sections.Group:GetHeight() * s + ROW_GAP)
	end
	return { point = "TOPLEFT", relPoint = "TOPLEFT", x = margin / s, y = top / s }
end

R.ApplySectionPosition = function(key, unlockKey, posKey)
	local f = S.sections[key]
	if not f then return end
	if InCombatLockdown() then S.applyPending = true; return end
	unlockKey = unlockKey or (UNLOCK_KEY .. key)
	local pos = (P().pos or {})[posKey or key] or DefaultPos(key)
	if ns.IsUnlockAnchored and ns.IsUnlockAnchored(unlockKey) then return end
	f:ClearAllPoints()
	f:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
end

local function ApplyPositions()
	if ns._unlockActive then return end
	local showAs = ShowAs()
	if showAs == "compact" then
		R.ApplySectionPosition("Group", COMPACT_UNLOCK_KEY, "Compact")
	elseif showAs ~= "markers" then
		R.ApplySectionPosition("Group")
	end
	if showAs == "two" or showAs == "markers" then R.ApplySectionPosition("Markers") end
end

local MODE_DRIVERS = { raid = "[group:raid] show; hide", group = "[group] show; hide" }

local function ApplyVisibility()
	local p = P()
	local mode = Mode()
	local driver = MODE_DRIVERS[mode]
	local visNow = (mode == "raid" and IsInRaid()) or (mode == "group" and IsInGroup()) or mode == "always"
	visNow = visNow and true or false
	local showAs = ShowAs()
	local compact = showAs == "compact"
	local suppressed = AssistSuppressed()
	local shellOn = {
		Group = showAs ~= "markers" and not suppressed,
		Markers = (showAs == "two" or showAs == "markers") and not suppressed,
	}
	local startExpanded = compact or p.collapsedIcon == false
	local expandedNow = startExpanded
	if previewOn then
		driver, visNow, expandedNow = nil, true, true
	end
	for _, key in ipairs(SECTION_KEYS) do
		local f = S.sections[key]
		local on = shellOn[key] and true or false
		f:SetAttribute("enabled", on)
		f:SetAttribute("visible", visNow)
		f:SetAttribute("override", "")
		f:SetAttribute("startexpanded", startExpanded)
		f:SetAttribute("expanded", expandedNow)
		UnregisterStateDriver(f, "euirt_vis")
		if on and driver then RegisterStateDriver(f, "euirt_vis", driver) end
	end
	local icon = S.iconBtn
	icon:SetAttribute("enabled", not compact and not suppressed)
	icon:SetAttribute("visible", visNow)
	icon:SetAttribute("override", "")
	icon:SetAttribute("startexpanded", startExpanded)
	icon:SetAttribute("expanded", expandedNow)
	S.lastSuppressed = suppressed
	for _, key in ipairs(SECTION_KEYS) do SecureHandlerExecute(S.sections[key], RUN_APPLY) end
	SecureHandlerExecute(icon, RUN_APPLY)
end

local function ApplyToggleKeybind()
	local tb = S.toggleButton
	if not tb then return end
	ClearOverrideBindings(tb)
	local k = P().toggleKey
	if k and k ~= "" and Mode() ~= "never" and not AssistSuppressed() then
		SetOverrideBindingClick(tb, false, k, "EllesmereUIRaidToolsToggle")
	end
end

-------------------------------------------------------------------------------
--  Quick Fire: Place (first free world marker, Mists ground targeting),
--  Undo (last placed), Clear (all). Secure, so the keys work in combat.
-------------------------------------------------------------------------------
local QF = S.runtime

R.PrimeQuickFire = function(place)
	if not place or InCombatLockdown() then return end
	local zoned = QF.zonedPending
	local count = 0
	for i = 1, WORLD_COUNT do
		if not IsRaidMarkerActive(i) then
			count = count + 1
			place:SetAttribute("qfAvail" .. count, i)
		end
	end
	for i = count + 1, WORLD_COUNT do place:SetAttribute("qfAvail" .. i, nil) end
	place:SetAttribute("qfAvailCount", count)
	place:SetAttribute("qfAvailPos", 0)
	if zoned then place:SetAttribute("qfDepth", 0) end
	QF.zonedPending = nil
end

local function HiddenSecureButton(name, x)
	local b = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
	b:RegisterForClicks("AnyDown")
	b:EnableMouse(false)
	b:SetSize(1, 1)
	b:SetAlpha(0)
	b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, -120)
	b:Show()
	return b
end

local function BuildQuickFire()
	if QF.place then return end
	QF.header = CreateFrame("Frame", "EllesmereUIRaidToolsQuickFireHeader", UIParent, "SecureHandlerBaseTemplate")

	local place = HiddenSecureButton("EllesmereUIRaidToolsQuickFirePlace", -120)
	place:SetAttribute("qfCount", WORLD_COUNT)
	place:SetAttribute("qfDepth", 0)
	place:SetScript("PreClick", function(self) R.PrimeQuickFire(self) end)
	SecureHandlerWrapScript(place, "OnClick", QF.header, [[
		self:SetAttribute("type", nil)
		self:SetAttribute("marker", nil)
		local n = tonumber(self:GetAttribute("qfCount")) or 5
		local available = tonumber(self:GetAttribute("qfAvailCount")) or 0
		local nextPos = (tonumber(self:GetAttribute("qfAvailPos")) or 0) + 1
		if nextPos > available then return end
		local m = tonumber(self:GetAttribute("qfAvail" .. nextPos))
		if not m then return end
		self:SetAttribute("qfAvailPos", nextPos)
		local depth = tonumber(self:GetAttribute("qfDepth")) or 0
		if depth >= n then
			for i = 1, n - 1 do
				self:SetAttribute("qfStack" .. i, self:GetAttribute("qfStack" .. (i + 1)))
			end
			depth = n - 1
		end
		depth = depth + 1
		self:SetAttribute("qfDepth", depth)
		self:SetAttribute("qfStack" .. depth, m)
		self:SetAttribute("marker", m)
		self:SetAttribute("action", "set")
		self:SetAttribute("type", "worldmarker")
	]], [[
		self:SetAttribute("type", nil)
		self:SetAttribute("marker", nil)
	]])

	local undo = HiddenSecureButton("EllesmereUIRaidToolsQuickFireUndo", -124)
	SecureHandlerSetFrameRef(undo, "place", place)
	SecureHandlerWrapScript(undo, "OnClick", QF.header, [[
		self:SetAttribute("type", nil)
		self:SetAttribute("action", nil)
		self:SetAttribute("marker", nil)
		local place = self:GetFrameRef("place")
		local depth = place and (tonumber(place:GetAttribute("qfDepth")) or 0) or 0
		if depth < 1 then return end
		local m = tonumber(place:GetAttribute("qfStack" .. depth))
		if not m then return end
		place:SetAttribute("qfStack" .. depth, nil)
		place:SetAttribute("qfDepth", depth - 1)
		local ap = tonumber(place:GetAttribute("qfAvailPos")) or 0
		if ap > 0 and tonumber(place:GetAttribute("qfAvail" .. ap)) == m then
			place:SetAttribute("qfAvailPos", ap - 1)
		end
		self:SetAttribute("marker", m)
		self:SetAttribute("action", "clear")
		self:SetAttribute("type", "worldmarker")
	]], [[
		self:SetAttribute("type", nil)
		self:SetAttribute("action", nil)
		self:SetAttribute("marker", nil)
	]])

	local clear = HiddenSecureButton("EllesmereUIRaidToolsQuickFireClear", -128)
	SecureHandlerSetFrameRef(clear, "place", place)
	clear:SetAttribute("type", "worldmarker")
	clear:SetAttribute("action", "clear")
	SecureHandlerWrapScript(clear, "OnClick", QF.header, [[
		local place = self:GetFrameRef("place")
		if place then
			local n = tonumber(place:GetAttribute("qfCount")) or 5
			place:SetAttribute("qfDepth", 0)
			place:SetAttribute("qfAvailCount", n)
			place:SetAttribute("qfAvailPos", 0)
			for i = 1, n do
				place:SetAttribute("qfAvail" .. i, i)
				place:SetAttribute("qfStack" .. i, nil)
			end
		end
	]])

	QF.place, QF.undo, QF.clear = place, undo, clear
	QF.bindingOwner = CreateFrame("Frame")
	R.PrimeQuickFire(place)
end

local function ApplyQuickFireBindings()
	local p = P()
	if QF.bindingOwner then ClearOverrideBindings(QF.bindingOwner) end
	if p.quickFire ~= true or Mode() == "never" or AssistSuppressed() then return end
	BuildQuickFire()
	R.PrimeQuickFire(QF.place)
	local bindings = {
		{ p.quickFirePlaceKey, "EllesmereUIRaidToolsQuickFirePlace" },
		{ p.quickFireUndoKey, "EllesmereUIRaidToolsQuickFireUndo" },
		{ p.quickFireClearKey, "EllesmereUIRaidToolsQuickFireClear" },
	}
	for _, b in ipairs(bindings) do
		if b[1] and b[1] ~= "" then SetOverrideBindingClick(QF.bindingOwner, false, b[1], b[2]) end
	end
end

-------------------------------------------------------------------------------
--  Lifecycle
-------------------------------------------------------------------------------
local ev
local function EnsureEvents()
	if not ev then
		ev = CreateFrame("Frame")
		ev:SetScript("OnEvent", function(_, event)
			if event == "PLAYER_REGEN_ENABLED" and S.applyPending then
				R.Apply()
				return
			end
			if Mode() == "never" then return end
			if (event == "RAID_TARGET_UPDATE" or event == "PLAYER_ENTERING_WORLD") and ShowAs() == "compact" then
				R.RefreshCompactMarkerState()
			end
			if event == "PLAYER_ENTERING_WORLD" then
				local zone = select(8, GetInstanceInfo())
				if zone ~= QF.zone then
					QF.zone = zone
					QF.zonedPending = true
				end
			end
			if (event == "RAID_TARGET_UPDATE" or event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD")
				and P().quickFire == true and QF.place then
				R.PrimeQuickFire(QF.place)
			end
			R.RefreshPermissions()
			if AssistSuppressed() ~= S.lastSuppressed then R.Apply() end
		end)
	end
	ev:RegisterEvent("GROUP_ROSTER_UPDATE")
	ev:RegisterEvent("PARTY_LEADER_CHANGED")
	ev:RegisterEvent("PLAYER_ENTERING_WORLD")
	ev:RegisterEvent("PLAYER_REGEN_ENABLED")
	if Mode() ~= "never" and (ShowAs() == "compact" or P().quickFire == true) then
		ev:RegisterEvent("RAID_TARGET_UPDATE")
	else
		ev:UnregisterEvent("RAID_TARGET_UPDATE")
	end
end

local unlockRegistered
local function RegisterUnlock()
	if unlockRegistered or not ns.MakeUnlockElement or not ns.RegisterUnlockElements then return end
	unlockRegistered = true
	local MK = ns.MakeUnlockElement
	local elements = {}
	for i, key in ipairs(SECTION_KEYS) do
		local unlockKey = UNLOCK_KEY .. key
		elements[#elements + 1] = MK({
			key = unlockKey,
			label = SECTION_LABEL[key],
			group = "Raid Tools",
			order = 540 + i,
			noResize = true,
			isHidden = function()
				if Mode() == "never" or AssistSuppressed() then return true end
				local showAs = ShowAs()
				if key == "Group" then return showAs == "compact" or showAs == "markers" end
				return showAs ~= "two" and showAs ~= "markers"
			end,
			getFrame = function()
				if Mode() == "never" or AssistSuppressed() or InCombatLockdown() then return S.sections[key] end
				R.BuildAll()
				return S.sections[key]
			end,
			getSize = function()
				local s, f = WindowScale(), S.sections[key]
				if f then return f:GetWidth() * s, f:GetHeight() * s end
				return PANEL_W * s, 60 * s
			end,
			savePos = function(_, point, relPoint, x, y)
				if not point then return end
				local p = P()
				p.pos = p.pos or {}
				p.pos[key] = { point = point, relPoint = relPoint, x = x, y = y }
				if not ns._unlockActive then R.ApplySectionPosition(key) end
			end,
			loadPos = function() return (P().pos or {})[key] end,
			clearPos = function() local p = P(); if p.pos then p.pos[key] = nil end end,
			applyPos = function()
				if key == "Group" and ShowAs() == "compact" then return end
				R.ApplySectionPosition(key)
			end,
		})
	end
	elements[#elements + 1] = MK({
		key = COMPACT_UNLOCK_KEY,
		label = "Compact Band",
		group = "Raid Tools",
		order = 540,
		isHidden = function() return Mode() == "never" or AssistSuppressed() or ShowAs() ~= "compact" end,
		getFrame = function()
			if not InCombatLockdown() then R.BuildAll() end
			return S.sections.Group
		end,
		getSize = function()
			local f = S.sections.Group
			if f and ShowAs() == "compact" then return f:GetWidth(), f:GetHeight() end
			return CompactWidth(), CompactHeight()
		end,
		setWidth = function(_, w)
			if not w then return end
			P().compactWidth = max(COMPACT_MIN_W, floor(w + 0.5))
			if S.sections.Group and not InCombatLockdown() then R.ApplyLayout() end
		end,
		setHeight = function(_, h)
			if not h then return end
			P().compactHeight = max(COMPACT_MIN_H, floor(h + 0.5))
			if S.sections.Group and not InCombatLockdown() then R.ApplyLayout() end
		end,
		savePos = function(_, point, relPoint, x, y)
			if not point then return end
			local p = P()
			p.pos = p.pos or {}
			p.pos.Compact = { point = point, relPoint = relPoint, x = x, y = y }
			if not ns._unlockActive then R.ApplySectionPosition("Group", COMPACT_UNLOCK_KEY, "Compact") end
		end,
		loadPos = function() return (P().pos or {}).Compact end,
		clearPos = function() local p = P(); if p.pos then p.pos.Compact = nil end end,
		applyPos = function()
			if ShowAs() == "compact" then R.ApplySectionPosition("Group", COMPACT_UNLOCK_KEY, "Compact") end
		end,
	})
	ns:RegisterUnlockElements(elements, addonName)
end

R.Apply = function()
	if not P() then return end
	if InCombatLockdown() then
		S.applyPending = true
		EnsureEvents()
		return
	end
	S.applyPending = false
	RegisterUnlock()
	if Mode() == "never" and not previewOn then
		if S.sections.Group then
			for _, key in ipairs(SECTION_KEYS) do
				local f = S.sections[key]
				UnregisterStateDriver(f, "euirt_vis")
				f:SetAttribute("enabled", false)
				f:SetAttribute("override", "")
				f:Hide()
			end
			S.iconBtn:SetAttribute("enabled", false)
			S.iconBtn:Hide()
			ClearOverrideBindings(S.toggleButton)
		end
		if QF.bindingOwner then ClearOverrideBindings(QF.bindingOwner) end
		if ev then ev:UnregisterAllEvents() end
		return
	end
	EnsureEvents()
	R.BuildAll()
	R.LayoutGroupContent()
	R.ApplyLayout()
	local scale = WindowScale()
	S.sections.Group:SetScale(scale)
	S.sections.Markers:SetScale(scale)
	S.iconBtn:SetScale(scale)
	ApplyPositions()
	ApplyVisibility()
	ApplyToggleKeybind()
	ApplyQuickFireBindings()
	ApplyFonts()
	R.RefreshPermissions(true)
end
_G._EUI_RaidTools_Apply = R.Apply

-- Settings page preview: the panels stay on screen while the page is shown.
R.SetPreview = function(on)
	on = on and true or false
	if previewOn == on then return end
	previewOn = on
	R.Apply()
end
_G._EUI_RaidTools_Preview = R.SetPreview

SLASH_EUIRAIDTOOLS1 = "/euiraid"
SlashCmdList["EUIRAIDTOOLS"] = function()
	local say = ns.Print or print
	if Mode() == "never" then
		say("Raid Tools is disabled in the EllesmereUI options.")
	elseif InCombatLockdown() then
		say("Raid Tools cannot be toggled by slash command in combat -- use the keybind.")
	elseif AssistSuppressed() then
		say("Raid Tools is hidden in a raid without leader or assist -- none of its buttons work there.")
	else
		R.BuildAll()
		SecureHandlerExecute(S.toggleButton, TOGGLE_SNIPPET)
	end
end

local loggedIn = false
ns.applyHooks = ns.applyHooks or {}
tinsert(ns.applyHooks, function()
	if loggedIn then R.Apply() end
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
	self:UnregisterAllEvents()
	loggedIn = true
	R.Apply()
end)

-------------------------------------------------------------------------------
--  Retail profile import: also take the raidTools table.
-------------------------------------------------------------------------------
do
	local PR = ns.ProfileRetail
	if PR and PR.CONVERT then
		local prev = PR.CONVERT.EllesmereUIQoL
		PR.CONVERT.EllesmereUIQoL = function(blob, notes)
			local root = prev and prev(blob, notes)
			if type(blob) == "table" and type(blob.raidTools) == "table" then
				local copy = ns.ProfileDeepCopy or function(t) return t end
				root = root or copy(EllesmereUIQoLDB or {})
				root.raidTools = copy(blob.raidTools)
				root.raidTools._seeded = nil
			end
			return root
		end
	end
end
