-------------------------------------------------------------------------------
--  EllesmereUITopBar_QoL.lua (5.4.8 port of the NaowhUI QoL features,
--  retail NaowhUI_EUI\QoL\NaowhUI_QoLShim.lua + _DeathRelease + _SpellAlerts)
--
--  Shared part: settings (EllesmereUITopBarDB.qol.<section>, same section
--  names and keys as retail NaowhUI profile.qol), first-login seed of the
--  retail Naowh values, timers, refresh registry, spec / zone state, fonts,
--  sounds, colours and Unlock Mode movers. Co-Tank and Stealth live in
--  their own files and use ns.NaowhQoL.
--
--  5.4.8 changes:
--    * No NaowhQOL / ProcGlows conflict guards (neither exists on Mists).
--    * No C_Timer: a small OnUpdate timer (Q.After / Q.NewTicker).
--    * Death Release: the 5.4.8 "DEATH" StaticPopup is found with
--      StaticPopup_Visible (returns name, frame); its release button is
--      <name>Button1. The guard is a plain child button over it (no taint).
--    * Spell Alerts: the same two CVars exist on 5.4.8
--      (displaySpellActivationOverlays, spellActivationOverlayOpacity).
--      The original values are kept in qol._cvarSnap for Reset.
-------------------------------------------------------------------------------
local addonName = ...
local ns = EllesmereUI

local floor, max, min = math.floor, math.max, math.min

local Q = {}
ns.NaowhQoL = Q

Q.FONT_KEY = "topBar"
Q.FONT_DEFAULT = "__default"
Q.SOUND_NONE = "none"
Q.FALLBACK_FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

-------------------------------------------------------------------------------
--  Defaults (retail NaowhUI_QoL_*.lua DEFAULTS, same keys)
-------------------------------------------------------------------------------
Q.DEFAULTS = {
	deathRelease = {
		enabled  = false,
		holdTime = 1.0,
	},
	spellAlerts = {
		hiddenSpecs = {},
	},
	coTank = {
		enabled = false, font = "__default",
		point = "CENTER", x = 200, y = 0,
		width = 150, height = 20,
		tankSpacing = 4, tankGrow = "DOWN",
		preview = false,
		healthColorR = 0, healthColorG = 0.8, healthColorB = 0.2,
		useClassColor = true,
		bgAlpha = 0.6,
		showName = true,
		nameFormat = "full",
		nameLength = 6,
		nameFontSize = 12,
		nameColorR = 1, nameColorG = 1, nameColorB = 1,
		nameColorUseClassColor = true,
		debuffEnabled = true,
		debuffFilter = "important",
		debuffSize = 22,
		debuffCap = 3,
		debuffSpacing = 2,
		debuffPosition = "top",
		debuffGrow = "CENTER",
		debuffOffsetX = 0,
		debuffOffsetY = 3,
		debuffShowDuration = true,
		debuffDurSize = 10,
		debuffShowStacks = true,
		debuffStackSize = 10,
		debuffTooltips = false,
	},
	stealth = {
		enabled = false, font = "__default",
		stealthText = "STEALTH", warningText = "RESTEALTH",
		stealthR = 0, stealthG = 1, stealthB = 0, stealthUseClassColor = false,
		warningR = 1, warningG = 0, warningB = 0, warningUseClassColor = false,
		showStealthed = true, showNotStealthed = true,
		disableWhenRested = false, groupOnly = false,
		point = "CENTER", x = 0, y = 150, width = 200, height = 40,
		textScale = 1,
		enableBalance = false, enableGuardian = false, enableResto = false,
		stanceEnabled = false, stanceFont = "__default",
		stanceWarnText = "",
		stanceWarnR = 1, stanceWarnG = 0.4, stanceWarnB = 0, stanceWarnUseClassColor = false,
		stancePoint = "CENTER", stanceX = 0, stanceY = 100, stanceWidth = 200, stanceHeight = 40,
		stanceTextScale = 1,
		stanceCombatOnly = false, stanceDisableWhenRested = false, stanceInstanceOnly = false,
		stanceSoundEnabled = false, stanceSound = "none", stanceSoundInterval = 3,
	},
}

-- The user's retail "Naowh" profile values (retail NaowhUI_EUI qol, only
-- the keys that differ from the defaults), applied once on first login.
-- boilingPoint is retail-only (Blood DK hidden aura) and not ported.
local NAOWH_SEED = {
	deathRelease = { enabled = false, holdTime = 1 },
	spellAlerts = {
		hiddenSpecs = {
			[62] = true, [65] = true, [66] = true, [70] = true, [71] = true, [72] = true,
			[73] = true, [102] = true, [103] = true, [104] = true, [105] = true,
			[250] = true, [251] = true, [252] = true, [253] = true, [254] = true,
			[255] = true, [256] = true, [257] = true, [258] = true, [259] = true,
			[260] = true, [261] = true, [262] = true, [263] = true, [264] = true,
			[265] = true, [266] = true, [267] = true, [268] = true, [269] = true,
			[270] = true,
		},
	},
	stealth = {
		enabled = true, stanceEnabled = true,
		warningR = 1, warningG = 0.3, warningB = 0.3, warningUseClassColor = false,
		stealthR = 0.5954, stealthG = 1, stealthB = 0.405, stealthUseClassColor = false,
		warningText = "RESTEALTH", stealthText = "STEALTH",
		showStealthed = true, showNotStealthed = false,
		disableWhenRested = false, groupOnly = false,
		enableBalance = true, enableGuardian = true, enableResto = true,
		point = "CENTER", x = 0, y = -148, width = 200, height = 40, textScale = 0.8,
		font = "__default", stanceFont = "__default",
		stanceWarnText = "", stanceWarnR = 1, stanceWarnG = 0.4, stanceWarnB = 0,
		stanceWarnUseClassColor = true,
		stancePoint = "CENTER", stanceX = 0, stanceY = -131, stanceWidth = 200, stanceHeight = 40,
		stanceTextScale = 0.8,
		stanceCombatOnly = true, stanceInstanceOnly = true, stanceDisableWhenRested = true,
		stanceSoundEnabled = false, stanceSound = "none", stanceSoundInterval = 3,
	},
	coTank = {
		enabled = true, preview = false, font = "__default",
		point = "CENTER", x = -667, y = -183, width = 160, height = 28,
		useClassColor = true, healthColorR = 0, healthColorG = 0.8, healthColorB = 0.2,
		bgAlpha = 1,
		showName = true, nameFormat = "abbreviated", nameLength = 8, nameFontSize = 14,
		nameColorUseClassColor = false, nameColorR = 1, nameColorG = 1, nameColorB = 1,
		debuffEnabled = true, debuffFilter = "important", debuffCap = 3, debuffSize = 48,
		debuffSpacing = 3, debuffPosition = "topright", debuffGrow = "LEFT",
		debuffOffsetX = 0, debuffOffsetY = 3,
		debuffShowDuration = true, debuffDurSize = 14,
		debuffShowStacks = true, debuffStackSize = 14,
		debuffTooltips = false,
	},
}

-------------------------------------------------------------------------------
--  Settings
-------------------------------------------------------------------------------
local function CopyDefault(v)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, inner in pairs(v) do out[k] = CopyDefault(inner) end
	return out
end
Q.CopyDefault = CopyDefault

-- EllesmereUITopBarDB (TopBar's ns.GetTopBarDB fills the bar keys only).
local function Root()
	local root = ns.GetTopBarDB and ns.GetTopBarDB() or ns.ModuleDB("EllesmereUITopBarDB")
	if type(root.qol) ~= "table" then root.qol = {} end
	return root.qol
end
Q.Root = Root

local function Seed(all)
	for section, vals in pairs(NAOWH_SEED) do
		if type(all[section]) ~= "table" then all[section] = {} end
		local t = all[section]
		for k, v in pairs(vals) do t[k] = CopyDefault(v) end
	end
	all._seeded = 1
end

-- Never cached: a profile switch or import replaces the saved table.
function Q.DB(section)
	local all = Root()
	if all._seeded ~= 1 then Seed(all) end
	local t = all[section]
	if type(t) ~= "table" then
		t = {}
		all[section] = t
	end
	local defaults = Q.DEFAULTS[section]
	if defaults then
		for k, v in pairs(defaults) do
			if t[k] == nil then t[k] = CopyDefault(v) end
		end
	end
	return t
end

-- Reset drops the table; the next DB() call rebuilds it from defaults.
function Q.ClearDB(section)
	local all = Root()
	all[section] = nil
end

-------------------------------------------------------------------------------
--  Timers (5.4.8 has no C_Timer)
-------------------------------------------------------------------------------
local timers = {}
local timerFrame = CreateFrame("Frame")
timerFrame:Hide()
timerFrame:SetScript("OnUpdate", function(self)
	local now = GetTime()
	local i = 1
	while i <= #timers do
		local t = timers[i]
		if t.cancelled then
			table.remove(timers, i)
		elseif now >= t.at then
			if t.interval then
				t.at = now + t.interval
				i = i + 1
			else
				table.remove(timers, i)
			end
			local ok, err = pcall(t.fn)
			if not ok then geterrorhandler()(err) end
		else
			i = i + 1
		end
	end
	if #timers == 0 then self:Hide() end
end)

local function AddTimer(delay, fn, interval)
	local t = { at = GetTime() + (delay or 0), fn = fn, interval = interval }
	t.Cancel = function(self) self.cancelled = true end
	timers[#timers + 1] = t
	timerFrame:Show()
	return t
end

function Q.After(delay, fn)
	return AddTimer(delay, fn)
end

function Q.NewTicker(interval, fn)
	return AddTimer(interval, fn, interval)
end

-------------------------------------------------------------------------------
--  Refresh registry (options and events call Refresh(section))
-------------------------------------------------------------------------------
local refreshers, refreshOrder = {}, {}
function Q.RegisterRefresh(section, fn)
	if type(section) ~= "string" or type(fn) ~= "function" then return end
	local list = refreshers[section]
	if not list then
		list = {}
		refreshers[section] = list
		refreshOrder[#refreshOrder + 1] = section
	end
	list[#list + 1] = fn
end

function Q.Refresh(section)
	local list = refreshers[section]
	if not list then return end
	for i = 1, #list do
		local ok, err = pcall(list[i])
		if not ok then geterrorhandler()(err) end
	end
end

function Q.RefreshAll()
	for i = 1, #refreshOrder do Q.Refresh(refreshOrder[i]) end
end

-- Reset callbacks per section (the settings page Reset button).
local resetters = {}
function Q.RegisterReset(section, fn)
	resetters[#resetters + 1] = fn
end

function Q.ResetAll()
	for i = 1, #resetters do
		local ok, err = pcall(resetters[i])
		if not ok then geterrorhandler()(err) end
	end
	Q.RefreshAll()
end

-------------------------------------------------------------------------------
--  Spec
-------------------------------------------------------------------------------
local classFile, specIndex, specID

function Q.ClassFile()
	if not classFile then
		local _, cf = UnitClass("player")
		classFile = cf or ""
	end
	return classFile
end

function Q.SpecIndex()
	if specIndex then return specIndex end
	local idx = (GetSpecialization and GetSpecialization()) or 0
	idx = idx or 0
	-- nil / 0 is "not known yet" for a moment at login: not cached.
	if idx > 0 then specIndex = idx end
	return idx
end

function Q.SpecID()
	if specID then return specID end
	local idx = Q.SpecIndex()
	if idx == 0 then return nil end
	specID = (GetSpecializationInfo(idx))
	return specID
end

function Q.SpecRole()
	local idx = Q.SpecIndex()
	if idx == 0 or not GetSpecializationRole then return nil end
	return GetSpecializationRole(idx)
end

local specCallbacks, zoneCallbacks = {}, {}
function Q.OnSpecChanged(fn)
	if type(fn) == "function" then specCallbacks[#specCallbacks + 1] = fn end
end
function Q.OnZoneChanged(fn)
	if type(fn) == "function" then zoneCallbacks[#zoneCallbacks + 1] = fn end
end

function Q.InDungeonOrRaid()
	local _, instanceType = GetInstanceInfo()
	return instanceType == "party" or instanceType == "raid"
end

local function Fire(list)
	for i = 1, #list do
		local ok, err = pcall(list[i])
		if not ok then geterrorhandler()(err) end
	end
end

local watcher = CreateFrame("Frame")
watcher:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
watcher:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_ENTERING_WORLD" then
		specIndex, specID = nil, nil
		Fire(zoneCallbacks)
		Fire(specCallbacks)
	else
		specIndex, specID = nil, nil
		Fire(specCallbacks)
	end
end)

-------------------------------------------------------------------------------
--  Fonts ("__default" = the Top Bar module font, like retail's EUI default)
-------------------------------------------------------------------------------
function Q.FontPath(name)
	if name and name ~= Q.FONT_DEFAULT and ns.ResolveFontName then
		local path = ns.ResolveFontName(name)
		if path then return path end
	end
	return (ns.GetFontPath and ns.GetFontPath(Q.FONT_KEY)) or Q.FALLBACK_FONT
end

function Q.OutlineFlag()
	local f = ns.GetFontOutlineFlag and ns.GetFontOutlineFlag(Q.FONT_KEY)
	if f == nil or f == "" then return "OUTLINE" end
	return f
end

-- A FontString needs a valid font before SetText.
function Q.SetFont(fs, path, size, flags)
	if not fs:SetFont(path or Q.FALLBACK_FONT, size, flags or "OUTLINE") then
		fs:SetFont(Q.FALLBACK_FONT, size, flags or "OUTLINE")
	end
end

-- Dropdown items: { name, value } (retail QoL.FontValues).
function Q.FontItems()
	local items = { { name = "Default (EllesmereUI)", value = Q.FONT_DEFAULT } }
	local seen = {}
	for _, name in ipairs(ns.FONT_ORDER or {}) do
		if name ~= "---" and not seen[name] then
			seen[name] = true
			items[#items + 1] = { name = name, value = name }
		end
	end
	local LSM = ns.GetLSM and ns.GetLSM()
	if LSM and LSM.List then
		local ok, list = pcall(LSM.List, LSM, "font")
		if ok and type(list) == "table" then
			for _, name in ipairs(list) do
				if not seen[name] then
					seen[name] = true
					items[#items + 1] = { name = name, value = name }
				end
			end
		end
	end
	return items
end

-------------------------------------------------------------------------------
--  Sounds (retail EllesmereUI alert sound catalogue: same keys; the files
--  ship with EllesmereUIChat on Mists, plus LibSharedMedia "sm:<name>")
-------------------------------------------------------------------------------
local SOUND_DIR = "Interface\\AddOns\\EllesmereUIChat\\Media\\sounds\\"
local SOUND_FILES = {
	airhorn = "AirHorn.ogg", banana = "BananaPeelSlip.ogg", bikehorn = "BikeHorn.ogg",
	bite = "Bite.ogg", boxing = "BoxingArenaSound.ogg", catmeow = "CatMeow.ogg",
	catmeow2 = "CatMeow2.ogg", gunshot = "FrontalsGunshot.wav", glass = "Glass.mp3",
	kaching = "Kaching.ogg", phone = "Phone.ogg", robotblip = "RobotBlip.ogg",
	sonar = "Sonar.ogg", siren = "WarningSiren.ogg", water = "WaterDrop.ogg",
	wilhelm = "Wilhelm.ogg",
}
local SOUND_NAMES = {
	none = "None", airhorn = "Air Horn", banana = "Banana Peel Slip",
	bikehorn = "Bike Horn", bite = "Bite", boxing = "Boxing Arena",
	catmeow = "Cat Meow", catmeow2 = "Cat Meow 2", gunshot = "Frontals Gunshot",
	glass = "Glass", kaching = "Kaching", phone = "Phone", robotblip = "Robot Blip",
	sonar = "Sonar", siren = "Warning Siren", water = "Water Drop", wilhelm = "Wilhelm",
}
local SOUND_ORDER = {
	"none", "airhorn", "banana", "bikehorn", "bite", "boxing", "catmeow",
	"catmeow2", "gunshot", "glass", "kaching", "phone", "robotblip", "sonar",
	"siren", "water", "wilhelm",
}

local function SoundTables()
	local paths, names, order = {}, {}, {}
	for i, k in ipairs(SOUND_ORDER) do
		order[i] = k
		names[k] = SOUND_NAMES[k]
		if SOUND_FILES[k] then paths[k] = SOUND_DIR .. SOUND_FILES[k] end
	end
	local LSM = ns.GetLSM and ns.GetLSM()
	if LSM and LSM.HashTable then
		local ok, hash = pcall(LSM.HashTable, LSM, "sound")
		if ok and type(hash) == "table" then
			local extra = {}
			for name, path in pairs(hash) do
				if type(path) == "string" and path ~= "" and name ~= "None" then
					extra[#extra + 1] = name
					paths["sm:" .. name] = path
					names["sm:" .. name] = name
				end
			end
			table.sort(extra, function(a, b) return a:lower() < b:lower() end)
			for _, name in ipairs(extra) do order[#order + 1] = "sm:" .. name end
		end
	end
	return paths, names, order
end

function Q.SoundItems()
	local _, names, order = SoundTables()
	local items = {}
	for i, k in ipairs(order) do items[i] = { name = names[k] or k, value = k } end
	return items
end

-- Returns ok, path. Raid Warning plays when the file does not.
function Q.PlaySound(key)
	if not key or key == Q.SOUND_NONE then return true end
	local paths = SoundTables()
	local path = paths[key]
	if not path then return false end
	if PlaySoundFile(path, "Master") then return true, path end
	PlaySound("RaidWarning", "Master")
	return false, path
end

-------------------------------------------------------------------------------
--  Colours
-------------------------------------------------------------------------------
function Q.PlayerClassColor()
	local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[Q.ClassFile()]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

function Q.EffectiveColor(db, rKey, gKey, bKey, classColorKey)
	if classColorKey and db[classColorKey] then return Q.PlayerClassColor() end
	return db[rKey] or 1, db[gKey] or 1, db[bKey] or 1
end

-------------------------------------------------------------------------------
--  Unlock Mode (retail QoL.RegisterMover; same element keys, so a retail
--  layout lands on the same movers). Position stays in our settings table.
-------------------------------------------------------------------------------
local movers = {}
local pendingMovers = {}
local unlockReady = false

local function MakeMover(spec)
	local resizable = spec.widthKey and spec.heightKey
	local function DB() return spec.db() end
	local elem = {
		key      = spec.key,
		label    = spec.label,
		group    = "NaowhUI",
		order    = spec.order,
		getFrame = spec.getFrame,
		isHidden = spec.isHidden,
		noResize = not resizable,
		getSize  = function()
			local f = spec.getFrame()
			if f then return f:GetWidth(), f:GetHeight() end
			local t = DB()
			return (resizable and t[spec.widthKey]) or 200, (resizable and t[spec.heightKey]) or 40
		end,
		savePos = function(_, point, relPoint, x, y)
			if not point then return end
			local t = DB()
			t[spec.pointKey] = point
			t[spec.xKey] = floor((x or 0) + 0.5)
			t[spec.yKey] = floor((y or 0) + 0.5)
		end,
		loadPos = function()
			local t = DB()
			if not t[spec.pointKey] then return nil end
			return { point = t[spec.pointKey], relPoint = t[spec.pointKey], x = t[spec.xKey] or 0, y = t[spec.yKey] or 0 }
		end,
		clearPos = function()
			local d = Q.DEFAULTS[spec.section]
			local t = DB()
			t[spec.pointKey], t[spec.xKey], t[spec.yKey] = d[spec.pointKey], d[spec.xKey], d[spec.yKey]
			if spec.apply then spec.apply() end
		end,
		applyPos = spec.apply,
	}
	if resizable then
		elem.setWidth = function(_, w)
			DB()[spec.widthKey] = max(spec.minW or 60, floor(w + 0.5))
			if spec.apply then spec.apply() end
		end
		elem.setHeight = function(_, h)
			DB()[spec.heightKey] = max(spec.minH or 20, floor(h + 0.5))
			if spec.apply then spec.apply() end
		end
	end
	return ns.MakeUnlockElement(elem)
end

function Q.RegisterMover(spec)
	if movers[spec.key] then return end
	movers[spec.key] = spec
	if not unlockReady then
		pendingMovers[#pendingMovers + 1] = spec
		return
	end
	if ns.RegisterUnlockElements and ns.MakeUnlockElement then
		ns:RegisterUnlockElements({ MakeMover(spec) }, addonName)
	end
end

local function FlushMovers()
	unlockReady = true
	if not (ns.RegisterUnlockElements and ns.MakeUnlockElement) then return end
	local list = {}
	for i = 1, #pendingMovers do list[i] = MakeMover(pendingMovers[i]) end
	wipe(pendingMovers)
	if #list > 0 then ns:RegisterUnlockElements(list, addonName) end
end

-- Frames show regardless of their gating while Unlock Mode is open.
local unlockWatchers = {}
Q.unlockActive = false
function Q.OnUnlockModeChanged(fn)
	if type(fn) == "function" then unlockWatchers[#unlockWatchers + 1] = fn end
end

if ns.RegisterUnlockModeListener then
	ns:RegisterUnlockModeListener("NaowhUI_QoL", function(active)
		Q.unlockActive = active and true or false
		for i = 1, #unlockWatchers do
			local ok, err = pcall(unlockWatchers[i], Q.unlockActive)
			if not ok then geterrorhandler()(err) end
		end
	end)
end

-------------------------------------------------------------------------------
--  Death Release Protection (retail NaowhUI_QoL_DeathRelease.lua)
-------------------------------------------------------------------------------
do
	local SECTION = "deathRelease"
	local function DB() return Q.DB(SECTION) end
	Q.DeathReleaseDB = DB

	local blocker, timerLabel
	local pressStart, isReady = 0, false
	local armedHold = 1.0
	local shownTenth
	local OnModifier

	local function Label(seconds)
		return ("Hold ALT %.1fs to release"):format(seconds)
	end

	local function BuildBlocker(releaseBtn)
		if blocker then
			-- StaticPopup buttons are reused, so the release button can move.
			if blocker:GetParent() ~= releaseBtn then
				blocker:SetParent(releaseBtn)
				blocker:ClearAllPoints()
				blocker:SetAllPoints()
			end
			blocker:SetFrameLevel(releaseBtn:GetFrameLevel() + 5)
			return blocker
		end
		blocker = CreateFrame("Button", nil, releaseBtn)
		blocker:SetAllPoints()
		blocker:SetFrameStrata("DIALOG")
		blocker:SetFrameLevel(releaseBtn:GetFrameLevel() + 5)
		blocker:EnableMouse(true)
		blocker:RegisterForClicks("AnyUp", "AnyDown")
		local bg = blocker:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetTexture(0.1, 0.1, 0.1, 0.85)
		timerLabel = blocker:CreateFontString(nil, "OVERLAY")
		Q.SetFont(timerLabel, Q.FontPath(), 12, "OUTLINE")
		timerLabel:SetPoint("CENTER", 0, 0)
		timerLabel:SetTextColor(1, 0.65, 0)
		-- Swallows the click: without it the button underneath still fires.
		blocker:SetScript("OnClick", function() end)
		blocker:SetScript("OnEvent", function(_, event, key, down) OnModifier(event, key, down) end)
		return blocker
	end

	local function StopTick()
		if blocker then blocker:SetScript("OnUpdate", nil) end
	end

	-- Letting go restarts the hold.
	local function ResetHold()
		StopTick()
		pressStart = 0
		shownTenth = nil
		if timerLabel then timerLabel:SetText(Label(armedHold)) end
	end

	local function TickTimer()
		if isReady then
			blocker:Hide()
			return
		end
		-- Alt-tab takes the keyboard without a key-up.
		if not IsAltKeyDown() then
			ResetHold()
			return
		end
		local left = armedHold - (GetTime() - pressStart)
		if left <= 0 then
			isReady = true
			StopTick()
			blocker:Hide()
			return
		end
		local tenth = floor(left * 10)
		if tenth ~= shownTenth then
			shownTenth = tenth
			timerLabel:SetText(Label(tenth / 10))
		end
	end

	local function StartTick()
		if pressStart ~= 0 then return end
		pressStart = GetTime()
		blocker:SetScript("OnUpdate", TickTimer)
	end

	OnModifier = function(event, key, down)
		if event ~= "MODIFIER_STATE_CHANGED" then return end
		if key ~= "LALT" and key ~= "RALT" then return end
		if down == 1 then
			StartTick()
		elseif not IsAltKeyDown() then
			ResetHold()
		end
	end

	local function ClearState()
		pressStart, isReady = 0, false
		shownTenth = nil
		if blocker then
			blocker:SetScript("OnUpdate", nil)
			blocker:UnregisterEvent("MODIFIER_STATE_CHANGED")
			blocker:Hide()
		end
	end

	local hookedDialogs = {}

	local function ActivateProtection()
		local t = DB()
		if not t.enabled then return end
		-- Dungeons and raids only: releasing in the open world costs nothing.
		if not Q.InDungeonOrRaid() then return end
		local name, popup = StaticPopup_Visible("DEATH")
		if not name then return end
		popup = popup or _G[name]
		local btn = _G[name .. "Button1"]
		if not btn then return end
		if popup and not hookedDialogs[popup] then
			hookedDialogs[popup] = true
			popup:HookScript("OnHide", ClearState)
		end
		BuildBlocker(btn)
		ClearState()
		armedHold = t.holdTime or 1.0
		Q.SetFont(timerLabel, Q.FontPath(), 12, "OUTLINE")
		timerLabel:SetText(Label(armedHold))
		blocker:Show()
		blocker:RegisterEvent("MODIFIER_STATE_CHANGED")
		-- Already holding ALT when you died: no key-down is coming.
		if IsAltKeyDown() then StartTick() end
	end

	local function Apply()
		if DB().enabled then
			if UnitIsDeadOrGhost("player") and not isReady and not (blocker and blocker:IsShown()) then
				ActivateProtection()
			end
		else
			ClearState()
		end
	end

	Q.RegisterRefresh(SECTION, Apply)
	Q.RegisterReset(SECTION, function()
		ClearState()
		Q.ClearDB(SECTION)
	end)

	-- The popup is built during PLAYER_DEAD; the button is there a moment later.
	local ev = CreateFrame("Frame")
	ev:RegisterEvent("PLAYER_DEAD")
	ev:RegisterEvent("PLAYER_ALIVE")
	ev:RegisterEvent("PLAYER_UNGHOST")
	ev:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_DEAD" then
			Q.After(0.05, ActivateProtection)
		else
			ClearState()
		end
	end)
	-- Also when the DEATH popup is shown again later (e.g. after a /reload).
	hooksecurefunc("StaticPopup_Show", function(which)
		if which == "DEATH" then Q.After(0.05, ActivateProtection) end
	end)
end

-------------------------------------------------------------------------------
--  Spell Alerts (retail NaowhUI_QoL_SpellAlerts.lua): proc overlay opacity
--  and hiding the overlays per spec, both CVars.
-------------------------------------------------------------------------------
do
	local SECTION      = "spellAlerts"
	local CVAR_OPACITY = "spellActivationOverlayOpacity"
	local CVAR_DISPLAY = "displaySpellActivationOverlays"
	local DEFAULT_OPACITY = 0.65

	local function DB()
		local t = Q.DB(SECTION)
		if type(t.hiddenSpecs) ~= "table" then t.hiddenSpecs = {} end
		return t
	end

	local function GetCVarSafe(name)
		local ok, v = pcall(GetCVar, name)
		if ok and v ~= nil then return tostring(v) end
		return nil
	end

	local function SetCVarSafe(name, value)
		if ns.SetCVarSafe then
			ns.SetCVarSafe(name, value)
		else
			pcall(SetCVar, name, value)
		end
	end

	-- First value seen is kept, so Reset can hand it back.
	local function SnapCVar(name)
		local all = Root()
		if type(all._cvarSnap) ~= "table" then all._cvarSnap = {} end
		if all._cvarSnap[name] == nil then
			all._cvarSnap[name] = GetCVarSafe(name) or false
		end
	end

	local function RestoreCVar(name)
		local snap = Root()._cvarSnap
		if type(snap) ~= "table" then return end
		local prev = snap[name]
		if type(prev) == "string" then SetCVarSafe(name, prev) end
		snap[name] = nil
	end

	-- Stateless: the CVar is the storage.
	function Q.GetAlertOpacity()
		return tonumber(GetCVarSafe(CVAR_OPACITY) or "") or DEFAULT_OPACITY
	end

	function Q.SetAlertOpacity(fraction)
		SnapCVar(CVAR_OPACITY)
		SetCVarSafe(CVAR_OPACITY, tostring(fraction))
	end

	local lastApplied

	local function ApplyDisplay()
		local t = DB()
		-- Never asked to manage the display CVar: leave it alone.
		if not next(t.hiddenSpecs) then return end
		local desired = "1"
		local id = Q.SpecID()
		if id and t.hiddenSpecs[id] then desired = "0" end
		local live = GetCVarSafe(CVAR_DISPLAY)
		if live == desired then
			lastApplied = desired
			return
		end
		-- Changed by hand since our last write: only a spec change or an
		-- edit here takes it back.
		if lastApplied and live and live ~= lastApplied then return end
		SnapCVar(CVAR_DISPLAY)
		SetCVarSafe(CVAR_DISPLAY, desired)
		lastApplied = desired
	end

	function Q.IsSpecHidden(id)
		if not id then return false end
		return DB().hiddenSpecs[id] == true
	end

	-- Every spec of every Mists class (classes 1-11, the picker list).
	function Q.SpecList()
		local out = {}
		local n = (GetNumClasses and GetNumClasses()) or 11
		for classID = 1, n do
			local className, file = GetClassInfo(classID)
			if className then
				local specs = {}
				for i = 1, (GetNumSpecializationsForClassID(classID) or 0) do
					local id, name = GetSpecializationInfoForClassID(classID, i)
					if id then specs[#specs + 1] = { id = id, name = name or ("Spec " .. i) } end
				end
				if #specs > 0 then
					out[#out + 1] = { name = className, file = file, specs = specs }
				end
			end
		end
		return out
	end

	local function Changed()
		lastApplied = nil   -- an edit here overrides the "changed by hand" guard
		if not next(DB().hiddenSpecs) then
			RestoreCVar(CVAR_DISPLAY)
			return
		end
		ApplyDisplay()
	end

	function Q.ToggleHiddenSpec(id)
		local t = DB()
		t.hiddenSpecs[id] = (not t.hiddenSpecs[id]) or nil
		Changed()
	end

	-- Whole set (Check All / Uncheck All).
	function Q.SetHiddenSpecSet(set)
		local t = DB()
		wipe(t.hiddenSpecs)
		for k in pairs(set or {}) do
			local id = tonumber(k)
			if id then t.hiddenSpecs[id] = true end
		end
		Changed()
	end

	Q.RegisterRefresh(SECTION, ApplyDisplay)
	Q.RegisterReset(SECTION, function()
		RestoreCVar(CVAR_OPACITY)
		RestoreCVar(CVAR_DISPLAY)
		lastApplied = nil
		Q.ClearDB(SECTION)
	end)
	Q.OnSpecChanged(function()
		lastApplied = nil   -- a new spec is a new decision
		ApplyDisplay()
	end)

	local ev = CreateFrame("Frame")
	ev:RegisterEvent("PLAYER_LOGIN")
	ev:RegisterEvent("PLAYER_TALENT_UPDATE")
	ev:SetScript("OnEvent", function()
		Q.After(0, ApplyDisplay)
	end)
end

-------------------------------------------------------------------------------
--  Retail profile import: retail NaowhUI_EUI.qol rides into
--  EllesmereUITopBarDB.qol (the core converts the topBar part only).
-------------------------------------------------------------------------------
local function ConvertQoL(qol)
	local out = {}
	for section in pairs(Q.DEFAULTS) do
		if type(qol[section]) == "table" then
			out[section] = CopyDefault(qol[section])
		end
	end
	out._seeded = 1
	return out
end
Q.ConvertQoL = ConvertQoL

do
	local R = ns.ProfileRetail
	if R and type(R.Convert) == "function" and not R._naowhQoLWrapped then
		R._naowhQoLWrapped = true
		local orig = R.Convert
		R.Convert = function(data, ...)
			local out, notes = orig(data, ...)
			local nui = type(data) == "table" and type(data.addons) == "table" and data.addons.NaowhUI_EUI
			local qol = type(nui) == "table" and nui.qol
			if type(out) == "table" and type(out.addons) == "table" and type(qol) == "table" then
				local tb = out.addons.EllesmereUITopBar
				if type(tb) == "table" then
					-- The CVar snapshot is this client's, not the profile's.
					local live = _G.EllesmereUITopBarDB
					local keep = type(live) == "table" and type(live.qol) == "table" and live.qol._cvarSnap or nil
					tb.qol = ConvertQoL(qol)
					tb.qol._cvarSnap = keep and CopyDefault(keep) or nil
				end
			end
			return out, notes
		end
	end
end

-------------------------------------------------------------------------------
--  Settings window and boot
-------------------------------------------------------------------------------
-- Every settings change (the settings window runs ns.applyHooks).
ns.applyHooks = ns.applyHooks or {}
tinsert(ns.applyHooks, function()
	if not Q.loaded then return end
	Q.RefreshAll()
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= addonName then return end
		self:UnregisterEvent("ADDON_LOADED")
		Q.loaded = true
		local all = Root()
		if all._seeded ~= 1 then Seed(all) end
		FlushMovers()
		return
	end
	self:UnregisterEvent("PLAYER_LOGIN")
	Q.RefreshAll()
end)
