-------------------------------------------------------------------------------
-- EllesmereUIQuestTracker.lua (5.4.8 port)
--
-- Loader and settings. Retail skins Blizzard's ObjectiveTrackerFrame; 5.4.8
-- has the WatchFrame instead, so the skin (_Skin.lua), the show/hide rules and
-- the background (_Visibility.lua) work on the WatchFrame. Auto accept, auto
-- turn in and the quest item hotkey live in _QoL.lua.
-- Saved keys, defaults and labels are the retail ones (profile.questTracker);
-- here they sit at the root of EllesmereUIQuestTrackerDB (as before 3.18).
-------------------------------------------------------------------------------
local addonName, P = ...
local ns = EllesmereUI

local EQT = {}
P.EQT = EQT
-- Retail global: core Unlock Mode calls EllesmereUIQuestTracker.UpdateVisibility().
_G.EllesmereUIQuestTracker = EQT

-------------------------------------------------------------------------------
-- Defaults (retail QT_DEFAULTS.profile.questTracker)
-------------------------------------------------------------------------------
local QT_DEFAULTS = {
	enabled              = true,
	forceOnScreen        = true,
	visibility           = "always",
	visOnlyInstances     = false,
	visHideMounted       = false,
	visHideNoTarget      = false,
	visHideNoEnemy       = false,
	-- "always": hide the whole time you are in a raid; "boss": only in boss fights.
	hideInRaidMode       = "boss",
	skinHeaders          = true,
	titleFontSize        = 12,
	objectiveFontSize    = 10,
	headerFontSize       = 13,
	bgR                  = 0.035,
	bgG                  = 0.035,
	bgB                  = 0.035,
	bgAlpha              = 0.75,
	showTopLine          = true,
	-- "LEFT" / "RIGHT": alignment of the quest titles and objectives (5.4.8 only).
	textAlign            = "LEFT",
	titleR = 1.000, titleG = 0.910, titleB = 0.471,
	completedR = 0.251, completedG = 1.000, completedB = 0.349,
	focusR = 0.871, focusG = 0.251, focusB = 1.000,
	-- QoL
	autoAccept              = false,
	autoAcceptPreventMulti  = true,
	autoAcceptShiftSkip     = true,
	autoAcceptIgnoreTrivial = false,
	autoAcceptIgnoreOldExpansion = false,
	autoTurnIn              = false,
	autoTurnInShiftSkip     = true,
}
EQT.DEFAULTS = QT_DEFAULTS

-- Retail keys a retail profile import carries over (plus the defaults above).
EQT.RETAIL_KEYS = {
	"font", "hideAllObjectivesHeader", "questItemHotkey", "visibilityModes", "visibilityMatch",
	"headerShowClassColor", "headerUseAccent", "headerR", "headerG", "headerB",
	"lineShowClassColor", "lineUseAccent", "lineR", "lineG", "lineB",
	"visOnlyResting", "visHideResting", "visHideInstances", "visOnlyMounted",
	"visHideWithTarget", "visHideWithEnemy",
}

-- The user's retail profile "Naowh" (only its non-default values), set once.
local SEED = {
	autoAccept = true,
	autoTurnIn = true,
	titleFontSize = 14,
	objectiveFontSize = 13,
	headerFontSize = 14,
	bgAlpha = 0,
	showTopLine = false,
	hideAllObjectivesHeader = true,
	font = "__global",
	headerUseAccent = false,
	headerShowClassColor = false,
	lineUseAccent = false,
	lineShowClassColor = false,
}

local db
local function Fill(t)
	for k, v in pairs(QT_DEFAULTS) do
		if t[k] == nil then t[k] = v end
	end
end

function EQT.DB()
	if not db then
		-- Before 3.1 the settings were EllesmereUIDB.questTracker.
		db = ns.ModuleDB("EllesmereUIQuestTrackerDB", "questTracker")
		Fill(db)
	end
	return db
end
function EQT.Cfg(k) return EQT.DB()[k] end
function EQT.Set(k, v) EQT.DB()[k] = v end

local function Seed(t)
	for k, v in pairs(SEED) do t[k] = v end
	t._seeded = 1
end

-- Settings window API (old names kept).
ns.GetQuestTrackerDB = EQT.DB
function EQT.Reset()
	local t = EQT.DB()
	wipe(t)
	Fill(t)
	Seed(t)
	if EQT.ResetQoL then EQT.ResetQoL() end
	EQT.ApplyAll()
end
ns.ResetQuestTrackerSettings = EQT.Reset

-------------------------------------------------------------------------------
-- Timers and combat queue (5.4.8 has no C_Timer)
-------------------------------------------------------------------------------
local timerFrame = CreateFrame("Frame")
local timers = {}
timerFrame:Hide()
timerFrame:SetScript("OnUpdate", function(self, elapsed)
	local now = GetTime()
	local i = 1
	while i <= #timers do
		local t = timers[i]
		if now >= t.at then
			table.remove(timers, i)
			t.fn()
		else
			i = i + 1
		end
	end
	if #timers == 0 then self:Hide() end
end)
function P.After(sec, fn)
	timers[#timers + 1] = { at = GetTime() + (sec or 0), fn = fn }
	timerFrame:Show()
end

local deferred, deferOrder = {}, {}
local deferFrame = CreateFrame("Frame")
deferFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
deferFrame:SetScript("OnEvent", function()
	local list = deferOrder
	deferOrder = {}
	for _, key in ipairs(list) do
		local fn = deferred[key]
		deferred[key] = nil
		if fn then fn() end
	end
end)
-- Runs fn now out of combat, else once after combat (one entry per key).
function P.Defer(key, fn)
	if not InCombatLockdown() then
		fn()
		return
	end
	if not deferred[key] then deferOrder[#deferOrder + 1] = key end
	deferred[key] = fn
end

-------------------------------------------------------------------------------
-- Apply everything (settings window, profile change)
-------------------------------------------------------------------------------
function EQT.ApplyAll()
	if not db then return end
	if EQT.RefreshFonts then EQT.RefreshFonts() end
	if EQT.RestyleAll then EQT.RestyleAll() end
	if EQT.ApplyTextAlign then EQT.ApplyTextAlign() end
	if EQT.ApplyMasterHeaderVisibility then EQT.ApplyMasterHeaderVisibility() end
	if EQT.ApplyBackground then EQT.ApplyBackground() end
	if EQT.ApplyForceOnScreen then EQT.ApplyForceOnScreen() end
	if EQT.ApplyPosition then EQT.ApplyPosition() end
	if EQT.UpdateVisibility then EQT.UpdateVisibility() end
	if EQT.ApplyQuestItemHotkey then EQT.ApplyQuestItemHotkey() end
end
_G._EQT_RefreshAll = EQT.ApplyAll

ns.applyHooks = ns.applyHooks or {}
tinsert(ns.applyHooks, function() EQT.ApplyAll() end)

-------------------------------------------------------------------------------
-- Retail profile import: keep the core converter (QoL keys), then carry the
-- skin / visibility keys this port has too.
-------------------------------------------------------------------------------
local function DeepCopy(v)
	if type(v) ~= "table" then return v end
	local t = {}
	for k, x in pairs(v) do t[k] = DeepCopy(x) end
	return t
end

local function WrapConverter()
	local R = ns.ProfileRetail
	if not (R and R.CONVERT) then return end
	local orig = R.CONVERT.EllesmereUIQuestTracker
	R.CONVERT.EllesmereUIQuestTracker = function(blob, notes)
		local root = orig and orig(blob, notes)
		local qt = type(blob) == "table" and (type(blob.questTracker) == "table" and blob.questTracker or blob) or {}
		if not root then
			-- _seeded stays as on this client (private path), so no re-seed after import.
			root = DeepCopy(_G.EllesmereUIQuestTrackerDB or {})
		end
		local any = false
		local function carry(k)
			if qt[k] ~= nil then
				root[k] = DeepCopy(qt[k])
				any = true
			end
		end
		for k in pairs(QT_DEFAULTS) do carry(k) end
		for _, k in ipairs(EQT.RETAIL_KEYS) do carry(k) end
		if not any and not orig then return nil end
		return root
	end
end
WrapConverter()

-------------------------------------------------------------------------------
-- Slash commands (retail /eqt show | hide | toggle, else the settings)
-------------------------------------------------------------------------------
SLASH_EQT1 = "/eqt"
SlashCmdList.EQT = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "show" then
		EQT.Set("enabled", true)
	elseif msg == "hide" then
		EQT.Set("enabled", false)
	elseif msg == "toggle" then
		EQT.Set("enabled", not EQT.Cfg("enabled"))
	else
		if InCombatLockdown() then return end
		if ns.LoadOptions and ns.LoadOptions() then
			if ns.ToggleSettingsWindow then ns.ToggleSettingsWindow() end
			if ns.SelectModule then ns:SelectModule("questTracker") end
		end
		return
	end
	if EQT.UpdateVisibility then EQT.UpdateVisibility() end
end

-------------------------------------------------------------------------------
-- Loader
-------------------------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= addonName then return end
		self:UnregisterEvent("ADDON_LOADED")
		local t = EQT.DB()
		if t._seeded ~= 1 then Seed(t) end
		if EQT.InitQoL then EQT.InitQoL() end
		return
	end
	-- PLAYER_LOGIN: the WatchFrame exists (FrameXML), our settings are loaded.
	self:UnregisterEvent("PLAYER_LOGIN")
	EQT.DB()
	if EQT.InitSkin then EQT.InitSkin() end
	if EQT.InitVisibility then EQT.InitVisibility() end
	EQT.ApplyAll()
end)
