-------------------------------------------------------------------------------
--  EllesmereUIActionBars.lua  (5.4.8 port of the EllesmereUI Action Bars)
--
--  The bar list, the defaults (same keys and values as EllesmereUI 9.3.8), the
--  saved settings (EllesmereUIActionBarsDB.profile), the first-run seed with the
--  retail "Naowh" profile, and the helpers the other files share.
--
--  Retail builds on the 12.x action bar API (Edit Mode, C_ActionBar, secret
--  values, mixins); none of it exists on 5.4.8. The bars here are rebuilt on
--  the 5.4.8 API with the same look, keys and behavior:
--    * our own secure buttons (SecureActionButtonTemplate + ActionButtonTemplate,
--      the LibActionButton pattern) with our own update code, so nothing of
--      Blizzard's action bar code runs on them (no taint);
--    * paging and visibility by secure state drivers, so they work in combat;
--    * keys by SetOverrideBindingClick on the standard binding commands.
--  Files: this one, EUI_ActionBars_ButtonArt.lua (look), EUI_ActionBars_Buttons.lua
--  (buttons, updates, keys), EUI_ActionBars_Bars.lua (bars, layout, visibility,
--  Blizzard bars, movers), EUI_ActionBars_DataBars.lua (XP / Reputation).
-------------------------------------------------------------------------------
local addonName, P = ...
local ns = EllesmereUI

local EAB = {}
ns.EAB = EAB
P.EAB = EAB
P.ns = ns

local floor, ceil, abs, min, max = math.floor, math.ceil, math.abs, math.min, math.max
local pairs, ipairs, type, next = pairs, ipairs, type, next

-------------------------------------------------------------------------------
--  Media
-------------------------------------------------------------------------------
P.MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"
P.WHITE = "Interface\\Buttons\\WHITE8X8"
-- Square glow borders of the EllesmereUI button art (highlight / pushed / flash).
P.HIGHLIGHT_TEXTURES = {
	P.MEDIA .. "highlight-2",
	P.MEDIA .. "highlight-3",
	P.MEDIA .. "highlight-4",
}
EAB.HIGHLIGHT_TEXTURES = P.HIGHLIGHT_TEXTURES

-------------------------------------------------------------------------------
--  Bar configuration
--  5.4.8 has action pages 1-6 (bars), 7-10 (stance / form bars), 11 (possess),
--  12 (vehicle), 13 (temp shapeshift) and 14 (override). Retail Action Bars
--  6-8 live on pages 13-15, which 5.4.8 does not have for player bars, so they
--  are left out. Action Bar 9 is page 2 and Action Bar 10 page 10, like retail.
-------------------------------------------------------------------------------
local BAR_CONFIG = {
	{ key = "MainBar", label = "Action Bar 1 (Main)", count = 12, page = 1, bind = "ACTIONBUTTON", isMain = true },
	{ key = "Bar2", label = "Action Bar 2", count = 12, page = 6, bind = "MULTIACTIONBAR1BUTTON" },
	{ key = "Bar3", label = "Action Bar 3", count = 12, page = 5, bind = "MULTIACTIONBAR2BUTTON" },
	{ key = "Bar4", label = "Action Bar 4", count = 12, page = 3, bind = "MULTIACTIONBAR3BUTTON" },
	{ key = "Bar5", label = "Action Bar 5", count = 12, page = 4, bind = "MULTIACTIONBAR4BUTTON" },
	{ key = "Bar9", label = "Action Bar 9", count = 12, page = 2, bind = "EUI_BAR9_BUTTON" },
	{ key = "Bar10", label = "Action Bar 10", count = 12, page = 10, bind = "EUI_BAR10_BUTTON" },
	{ key = "StanceBar", label = "Stance Bar", count = 10, isStance = true, bind = "SHAPESHIFTBUTTON" },
	{ key = "PetBar", label = "Pet Bar", count = 10, isPetBar = true, bind = "BONUSACTIONBUTTON" },
}

local EXTRA_BARS = {
	{ key = "MicroBar", label = "Micro Menu Bar", visibilityOnly = true },
	{ key = "BagBar", label = "Bag Bar", visibilityOnly = true },
	{ key = "XPBar", label = "XP Bar", visibilityOnly = true, isDataBar = true },
	{ key = "RepBar", label = "Reputation Bar", visibilityOnly = true, isDataBar = true },
	{ key = "ExtraActionButton", label = "Extra Action Button", visibilityOnly = true, isBlizzardMovable = true },
}

local ALL_BARS, BAR_LOOKUP = {}, {}
for _, info in ipairs(BAR_CONFIG) do
	ALL_BARS[#ALL_BARS + 1] = info
	BAR_LOOKUP[info.key] = info
end
for _, info in ipairs(EXTRA_BARS) do
	ALL_BARS[#ALL_BARS + 1] = info
	BAR_LOOKUP[info.key] = info
end

local VISIBILITY_ONLY, DATA_BAR = {}, {}
for _, info in ipairs(EXTRA_BARS) do
	VISIBILITY_ONLY[info.key] = true
	if info.isDataBar then
		DATA_BAR[info.key] = true
	end
end

EAB.BAR_CONFIG = BAR_CONFIG
EAB.EXTRA_BARS = EXTRA_BARS
EAB.ALL_BARS = ALL_BARS
EAB.BAR_LOOKUP = BAR_LOOKUP
EAB.VISIBILITY_ONLY = VISIBILITY_ONLY
EAB.DATA_BAR = DATA_BAR
P.BAR_CONFIG, P.EXTRA_BARS, P.ALL_BARS, P.BAR_LOOKUP = BAR_CONFIG, EXTRA_BARS, ALL_BARS, BAR_LOOKUP

-- Short labels (retail SHORT_LABELS, used by the Apply to All links).
EAB.SHORT_LABELS = {
	MainBar = "Bar 1", Bar2 = "Bar 2", Bar3 = "Bar 3", Bar4 = "Bar 4", Bar5 = "Bar 5",
	Bar9 = "Bar 9", Bar10 = "Bar 10", StanceBar = "Stance", PetBar = "Pet",
	MicroBar = "Micro", BagBar = "Bags", XPBar = "XP", RepBar = "Rep",
}

-- Border thickness steps (retail ns.BORDER_THICKNESS, "regular" column).
EAB.BORDER_THICKNESS = {
	none = { regular = 0, shape = 0 },
	thin = { regular = 1, shape = 0 },
	normal = { regular = 2, shape = 0 },
	heavy = { regular = 3, shape = 0 },
	strong = { regular = 4, shape = 7 },
}
EAB.BORDER_THICKNESS_ORDER = { "none", "thin", "normal", "heavy", "strong" }
EAB.BORDER_THICKNESS_LABELS = { none = "None", thin = "Thin", normal = "Normal", heavy = "Heavy", strong = "Strong" }
EAB.BORDER_LABEL_OF_STEP = { [0] = "none", [1] = "thin", [2] = "normal", [3] = "heavy", [4] = "strong" }

-- Icon zoom defaults by shape (retail SHAPE_ZOOM_DEFAULTS; 5.4.8 has no mask
-- textures, so only None and Cropped exist here).
EAB.SHAPE_ZOOM_DEFAULTS = { none = 5.5, cropped = 2 }

-------------------------------------------------------------------------------
--  Paging (retail EAB_VTABLE.BAR_KEY_TO_PAGE / PAGING_STATES, 5.4.8 forms)
-------------------------------------------------------------------------------
EAB.NUM_PAGES = 6
EAB.BAR_KEY_TO_PAGE = { MainBar = 1, Bar2 = 6, Bar3 = 5, Bar4 = 3, Bar5 = 4, Bar9 = 2, Bar10 = 10 }
EAB.PAGING_STATES = {
	modifier = {
		{ id = "alt", macro = "[mod:alt]", label = "Alt" },
		{ id = "shift", macro = "[mod:shift]", label = "Shift" },
		{ id = "ctrl", macro = "[mod:ctrl]", label = "Ctrl" },
	},
	target = {
		{ id = "help", macro = "[help]", label = "Friendly Target" },
		{ id = "harm", macro = "[harm]", label = "Hostile Target" },
	},
	class = {
		DRUID = {
			{ id = "prowl", macro = "[bonusbar:1,stealth]", label = "Prowl" },
			{ id = "cat", macro = "[bonusbar:1]", label = "Cat Form" },
			{ id = "tree", macro = "[bonusbar:2]", label = "Tree of Life" },
			{ id = "bear", macro = "[bonusbar:3]", label = "Bear Form" },
			{ id = "moonkin", macro = "[bonusbar:4]", label = "Moonkin Form" },
		},
		ROGUE = {
			{ id = "stealth", macro = "[bonusbar:1]", label = "Stealth" },
			{ id = "shadowdance", macro = "[bonusbar:2]", label = "Shadow Dance" },
		},
		WARRIOR = {
			{ id = "battle", macro = "[bonusbar:1]", label = "Battle Stance" },
			{ id = "defensive", macro = "[bonusbar:2]", label = "Defensive Stance" },
			{ id = "berserker", macro = "[bonusbar:3]", label = "Berserker Stance" },
		},
	},
}
EAB.MOD_TARGET_PAGING = { shift = true, ctrl = true, alt = true, help = true, harm = true }

-------------------------------------------------------------------------------
--  Defaults (EllesmereUI 9.3.8 defaults, same keys)
-------------------------------------------------------------------------------
local function RGB(r, g, b, a)
	return { r = r, g = g, b = b, a = a }
end

local defaults = {
	profile = {
		squareIcons = true,
		iconZoom = 5.5,
		selectedBar = "MainBar",
		cooldownEdgeSize = 2.1,
		cooldownEdgeColor = RGB(0.973, 0.839, 0.604, 1),
		cooldownEdgeUseClassColor = false,
		pushedTextureType = 2,
		pushedUseClassColor = false,
		pushedCustomColor = RGB(0.973, 0.839, 0.604, 1),
		pushedBorderSize = 4,
		highlightTextureType = 2,
		highlightUseClassColor = false,
		highlightCustomColor = RGB(0.973, 0.839, 0.604, 1),
		highlightBorderSize = 4,
		pushedBorderMatchBar = false,
		highlightBorderMatchBar = false,
		castHighlightBorder = false,
		showCastHighlight = true,
		showChargeRechargeNumbers = true,
		desaturateOnCooldown = false,
		alphaWhenOnCD = 100,
		cdSwipeColor = RGB(0, 0, 0),
		cdSwipeAlpha = 80,
		procGlowType = 1,
		procGlowColor = RGB(1, 0.776, 0.376),
		procGlowUseClassColor = false,
		procGlowEnabled = false,
		useBlizzardStyle = false,
		useClassicStyle = false,
		showBlizzIconBg = false,
		blizzIconBgAlpha = 1,
		slotBgColor = RGB(0.15, 0.15, 0.15),
		slotBgOpacity = 50,
		hideCastingAnimations = true,
		mouseoverShowAll = false,
		-- Retail "Cooldown Numbers" is Blizzard's countdownForCooldowns CVar.
		-- 5.4.8 has no countdown numbers, so this port draws its own and keeps
		-- the switch here (on: the retail CVar was on).
		cooldownNumbers = true,
		useBlizzardDataBars = false,
		showEquippedBorder = false,
		hideBlizzardVehicleBar = false,
		barPositions = {},
		bars = {},
	},
}

for _, info in ipairs(BAR_CONFIG) do
	defaults.profile.bars[info.key] = {
		enabled = true,
		borderEnabled = true,
		borderColor = RGB(0, 0, 0, 1),
		borderSize = 1,
		borderClassColor = false,
		borderTexture = "solid",
		borderThickness = "thin",
		borderBehind = false,
		borderAboveEffects = false,
		buttonPadding = 2,
		buttonWidth = 0,
		buttonHeight = 0,
		mouseoverEnabled = false,
		mouseoverAlpha = 1,
		combatShowEnabled = false,
		combatHideEnabled = false,
		housingHideEnabled = false,
		barVisibility = "always",
		dragShow = false,
		gamepadHideBar = false,
		visHideHousing = false,
		visOnlyInstances = false,
		visHideMounted = false,
		visHideNoTarget = false,
		visHideNoEnemy = false,
		hideKeybind = false,
		keybindFontSize = 12,
		keybindFontColor = RGB(1, 1, 1),
		hideMacroText = false,
		macroFontSize = 12,
		macroFontColor = RGB(1, 1, 1),
		countFontSize = 12,
		countFontColor = RGB(1, 1, 1),
		alwaysHidden = false,
		mouseoverSpeed = 0.15,
		clickThrough = false,
		growDirection = "up",
		reverseIconOrder = false,
		alwaysShowButtons = true,
		showPagingArrows = false,
		pagingArrowsRight = false,
		paging = {},
		disableFormPaging = false,
		disableSkyridingPaging = false,
		bgEnabled = false,
		bgColor = RGB(0, 0, 0, 0.5),
		bgBorderColor = RGB(0, 0, 0, 1),
		bgBorderTexture = "solid",
		bgBorderBehind = false,
		bgBorderSize = 1,
		bgBorderThickness = "none",
		bgMultiplierX = 1,
		bgMultiplierY = 1,
		bgExpandDirectionX = "right",
		bgExpandDirectionY = "up",
		outOfRangeColoring = false,
		outOfRangeColor = RGB(0.8, 0.1, 0.1),
		buttonShape = "none",
		shapeBorderEnabled = true,
		shapeBorderColor = RGB(0, 0, 0, 1),
		shapeBorderSize = 7,
		keybindOffsetX = 0,
		keybindOffsetY = 0,
		macroOffsetX = 0,
		macroOffsetY = 0,
		countOffsetX = 0,
		countOffsetY = 0,
		cooldownFontSize = 12,
		cooldownTextXOffset = 0,
		cooldownTextYOffset = 0,
		cooldownTextColor = RGB(1, 1, 1),
		disableTooltips = false,
		showRankIcon = false,
		orientation = "horizontal",
		numIcons = 12,
		numRows = 1,
		targetWidth = 0,
		targetHeight = 0,
	}
end

-- Bar9 / Bar10 default to Hidden (retail: they never show until picked).
for _, k in ipairs({ "Bar9", "Bar10" }) do
	defaults.profile.bars[k].barVisibility = "never"
	defaults.profile.bars[k].alwaysHidden = true
end

for _, info in ipairs(EXTRA_BARS) do
	local d = {
		mouseoverEnabled = false,
		mouseoverAlpha = 1,
		combatShowEnabled = false,
		combatHideEnabled = false,
		housingHideEnabled = false,
		alwaysHidden = false,
		mouseoverSpeed = 0.15,
		clickThrough = false,
	}
	if info.isDataBar then
		d.width = 400
		d.height = 18
		d.orientation = "HORIZONTAL"
		d.clickThrough = true
		d.customBorder = false
		d.borderTexture = "solid"
		d.borderThickness = "thin"
		d.borderColor = RGB(0, 0, 0, 1)
		d.borderBehind = false
	end
	defaults.profile.bars[info.key] = d
end

-- Default positions for a fresh profile (retail reads Blizzard's Edit Mode at
-- the first install; 5.4.8 has none, so these follow Blizzard's 5.4.8 layout).
local DEFAULT_POSITIONS = {
	MainBar = { point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = 24 },
	Bar2 = { point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = 72 },
	Bar3 = { point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = 120 },
	Bar4 = { point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = 168 },
	Bar5 = { point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = 216 },
	Bar9 = { point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = 264 },
	Bar10 = { point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = 312 },
	StanceBar = { point = "BOTTOM", relPoint = "BOTTOM", x = -220, y = 264 },
	PetBar = { point = "BOTTOM", relPoint = "BOTTOM", x = 220, y = 264 },
	MicroBar = { point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -4, y = 44 },
	BagBar = { point = "BOTTOMRIGHT", relPoint = "BOTTOMRIGHT", x = -4, y = 4 },
	XPBar = { point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = 4 },
	RepBar = { point = "TOP", relPoint = "TOP", x = 0, y = -84 },
	ExtraActionButton = { point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = 300 },
}
P.DEFAULT_POSITIONS = DEFAULT_POSITIONS
EAB.defaults = defaults

-------------------------------------------------------------------------------
--  First run: the retail EllesmereUI "Naowh" profile (EllesmereUIDB.profiles.
--  Naowh.addons.EllesmereUIActionBars on the retail client). Bars 6-8 and the
--  retail-only bars (House Favor, Queue Status) are left out.
-------------------------------------------------------------------------------
local function NaowhBar(extra)
	local t = {
		_savedBarAlpha = 1, barVisibility = "mouseover", mouseoverAlpha = 0, mouseoverEnabled = true,
		buttonHeight = 36.00000000225, buttonWidth = 36.00000000225, buttonPadding = 1,
		countOffsetX = 1, countOffsetY = -2, keybindOffsetX = 1, keybindOffsetY = 1, macroOffsetY = -2,
		growDirection = "center", iconZoom = 5, overrideNumIcons = 12, overrideNumRows = 1, spellbookShow = true,
	}
	for k, v in pairs(extra or {}) do
		t[k] = v
	end
	return t
end

local NAOWH_SEED = {
	hideZeroCount = true,
	slotBgColor = RGB(0, 0, 0),
	slotBgOpacity = 70,
	barPositions = {
		MainBar = { point = "CENTER", relPoint = "CENTER", x = -0.5, y = -693.00045490265 },
		Bar2 = { point = "CENTER", relPoint = "CENTER", x = -0.50000005215406, y = -656 },
		Bar3 = { point = "LEFT", relPoint = "CENTER", x = -1279.999997138977, y = 250.4999389648438 },
		Bar4 = { point = "CENTER", relPoint = "CENTER", x = -337.4999694824219, y = -674.5001773834229 },
		Bar5 = { point = "CENTER", relPoint = "CENTER", x = 337.5, y = -675.0004439353943 },
		PetBar = { point = "CENTER", relPoint = "CENTER", x = -492.4999389648438, y = -606.0001564025879 },
		StanceBar = { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 },
		ExtraActionButton = { point = "CENTER", relPoint = "CENTER", x = -462.0000610351563, y = -475.0001754760742 },
	},
	bars = {
		MainBar = NaowhBar(),
		Bar2 = NaowhBar(),
		Bar3 = NaowhBar({ growDirection = "right", orientation = "vertical" }),
		Bar4 = NaowhBar({ iconOrder = "BOTTOMLEFT", overrideNumRows = 2 }),
		Bar5 = NaowhBar({ overrideNumRows = 2 }),
		Bar9 = {
			buttonHeight = 45.0000000028125, buttonWidth = 45.0000000028125,
			countOffsetX = 1, countOffsetY = -2, keybindOffsetX = 1, keybindOffsetY = 1, macroOffsetY = -2,
		},
		Bar10 = {
			buttonHeight = 45.0000000028125, buttonWidth = 45.0000000028125,
			countOffsetX = 1, countOffsetY = -2, keybindOffsetX = 1, keybindOffsetY = 1, macroOffsetY = -2,
		},
		PetBar = {
			_savedBarAlpha = 1, barVisibility = "mouseover", mouseoverAlpha = 0, mouseoverEnabled = true,
			buttonHeight = 36.00000000225, buttonWidth = 36.00000000225, buttonPadding = 1,
			growDirection = "center", iconZoom = 5.5, macroOffsetY = -2,
			overrideNumIcons = 10, overrideNumRows = 1, spellbookShow = true,
		},
		StanceBar = {
			_matchExtraPixels = 2, alwaysHidden = true, barVisibility = "never",
			buttonHeight = 36.00000000225, buttonWidth = 36.00000000225, buttonPadding = 1,
			countOffsetX = 1, countOffsetY = -2, keybindOffsetX = 1, keybindOffsetY = 1, macroOffsetY = -2,
			growDirection = "center", iconZoom = 5, overrideNumIcons = 4, overrideNumRows = 1,
		},
		MicroBar = { alwaysHidden = true, barVisibility = "never", growDirection = "center" },
		BagBar = { alwaysHidden = true, barVisibility = "never", growDirection = "center" },
		XPBar = { alwaysHidden = true, barVisibility = "never", growDirection = "center" },
		RepBar = { barVisibility = "always", growDirection = "center" },
		ExtraActionButton = { barVisibility = "always", growDirection = "center" },
	},
}
P.NAOWH_SEED = NAOWH_SEED

-------------------------------------------------------------------------------
--  Saved settings
-------------------------------------------------------------------------------
local function DeepCopy(v)
	if type(v) ~= "table" then
		return v
	end
	local t = {}
	for k, x in pairs(v) do
		t[k] = DeepCopy(x)
	end
	return t
end
P.DeepCopy = DeepCopy
EAB.DeepCopy = DeepCopy

-- Seed values win over the defaults (deep, table by table).
local function Overlay(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" and type(dst[k]) == "table" and not v.r then
			Overlay(dst[k], v)
		else
			dst[k] = DeepCopy(v)
		end
	end
end

local function NewProfile(seed)
	local profile = DeepCopy(defaults.profile)
	if seed then
		Overlay(profile, seed)
		profile.seeded = "Naowh"
	end
	return profile
end

function EAB:InitDB()
	if type(EllesmereUIActionBarsDB) ~= "table" then
		EllesmereUIActionBarsDB = {}
	end
	local sv = EllesmereUIActionBarsDB
	if type(sv.profile) ~= "table" then
		sv.profile = NewProfile(NAOWH_SEED)
	else
		ns.CopyDefaults(defaults.profile, sv.profile)
	end
	sv.version = 1
	self.db = {
		sv = sv,
		profile = sv.profile,
		ResetProfile = function(db)
			db.sv.profile = NewProfile(nil)
			db.profile = db.sv.profile
		end,
	}
end

-- Reset to the EllesmereUI defaults (the footer "Reset Action Bars").
function EAB:ResetProfile()
	self.db:ResetProfile()
end

-- Back to the retail "Naowh" profile (the settings window offers it).
function EAB:LoadNaowhProfile()
	self.db.sv.profile = NewProfile(NAOWH_SEED)
	self.db.profile = self.db.sv.profile
end

-------------------------------------------------------------------------------
--  Visibility helpers (retail EAB.VisibilityCompat: the legacy booleans
--  follow the Visibility mode)
-------------------------------------------------------------------------------
EAB.VisibilityCompat = {}

function EAB.VisibilityCompat.ApplyMode(s, mode)
	if not s then
		return "always"
	end
	mode = mode or "always"
	s.barVisibility = mode
	s.alwaysHidden = (mode == "never")
	local wasMouseover = s.mouseoverEnabled
	s.mouseoverEnabled = (mode == "mouseover")
	if mode == "mouseover" then
		if not s._savedBarAlpha then
			s._savedBarAlpha = s.mouseoverAlpha or 1
		end
		s.mouseoverAlpha = 0
	elseif wasMouseover and s._savedBarAlpha then
		s.mouseoverAlpha = s._savedBarAlpha
		s._savedBarAlpha = nil
	end
	s.combatHideEnabled = (mode == "out_of_combat")
	s.combatShowEnabled = (mode == "in_combat")
	return mode
end

function EAB.VisibilityCompat.Normalize(s)
	if not s then
		return "always"
	end
	if s.barVisibility then
		return s.barVisibility
	end
	if s.alwaysHidden then
		return EAB.VisibilityCompat.ApplyMode(s, "never")
	elseif s.mouseoverEnabled then
		return EAB.VisibilityCompat.ApplyMode(s, "mouseover")
	elseif s.combatShowEnabled then
		return EAB.VisibilityCompat.ApplyMode(s, "in_combat")
	elseif s.combatHideEnabled then
		return EAB.VisibilityCompat.ApplyMode(s, "out_of_combat")
	end
	return EAB.VisibilityCompat.ApplyMode(s, "always")
end

-- Visibility checklist axes: the same keys as the Unit Frames port
-- (EllesmereUI VIS_OPT_KEYS and visibilityModes lanes). "macro" = the
-- conditional the secure driver uses; Lua-only lanes are resolved when the
-- driver is built and rebuilt on their events.
EAB.VIS_AXES = {
	{ key = "in_combat", label = "In Combat", show = "in_combat", hide = "hide_in_combat", on = "combat", off = "nocombat" },
	{ key = "out_of_combat", label = "Out of Combat", show = "out_of_combat", hide = "hide_out_of_combat", on = "nocombat", off = "combat" },
	{ key = "in_raid", label = "In Raid Group", show = "in_raid", hide = "hide_in_raid", on = "group:raid", off = "nogroup:raid" },
	{ key = "in_party", label = "In Party", show = "in_party", hide = "hide_in_party", on = "group:party,nogroup:raid" },
	{ key = "solo", label = "Solo", show = "solo", hide = "hide_solo", on = "nogroup", off = "group" },
	{ key = "instances", label = "Instances", show = "visOnlyInstances", hide = "visHideInstances",
		lua = function() local inside = IsInInstance() return inside and true or false end },
	{ key = "mounted", label = "Mounted", show = "visOnlyMounted", hide = "visHideMounted", on = "mounted", off = "nomounted" },
	{ key = "target", label = "Target", show = "visHideNoTarget", hide = "visHideWithTarget", on = "exists", off = "noexists" },
	{ key = "enemy", label = "Enemy Target", show = "visHideNoEnemy", hide = "visHideWithEnemy", on = "harm", off = "noharm" },
	{ key = "resting", label = "Resting", show = "visOnlyResting", hide = "visHideResting",
		lua = function() return IsResting() and true or false end },
}

function EAB.VisFlag(s, key)
	if key:match("^vis") then
		return s[key] and true or false
	end
	local modes = s.visibilityModes
	if modes and modes[key] then
		return true
	end
	if key == "hide_in_raid" then
		return s.showInRaid == false
	elseif key == "hide_in_party" then
		return s.showInParty == false
	elseif key == "hide_solo" then
		return s.showSolo == false
	end
	-- Legacy scalar modes (retail barVisibility = "in_combat" etc.) read as
	-- their Show lane.
	local vis = s.barVisibility
	if vis and vis ~= "always" and vis ~= "never" and vis ~= "mouseover" and vis == key then
		return true
	end
	return false
end

function EAB.SetVisFlag(s, key, on)
	if key:match("^vis") then
		s[key] = on and true or nil
		return
	end
	s.visibilityModes = s.visibilityModes or {}
	s.visibilityModes[key] = on and true or nil
	if key == "hide_in_raid" then
		s.showInRaid = (not on) and nil or false
	elseif key == "hide_in_party" then
		s.showInParty = (not on) and nil or false
	elseif key == "hide_solo" then
		s.showSolo = (not on) and nil or false
	end
end

-- Base state of the Visibility checklist (Never / Always / Mouseover).
function EAB.VisBase(s)
	local vis = s and s.barVisibility or "always"
	if vis == "never" or (s and s.alwaysHidden and vis ~= "mouseover" and vis ~= "always") then
		return "never"
	elseif vis == "mouseover" then
		return "mouseover"
	end
	return "always"
end

-------------------------------------------------------------------------------
--  Helpers
-------------------------------------------------------------------------------
-- Timers (5.4.8 has no C_Timer).
do
	local timerFrame = CreateFrame("Frame")
	local timers = {}
	timerFrame:Hide()
	timerFrame:SetScript("OnUpdate", function(self)
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
		if #timers == 0 then
			self:Hide()
		end
	end)
	function P.After(delay, fn)
		timers[#timers + 1] = { at = GetTime() + (delay or 0), fn = fn }
		timerFrame:Show()
	end
end

-- One physical pixel in UIParent units.
function P.Pixel()
	local h = ns.PhysicalHeight and ns.PhysicalHeight() or 1080
	return 768 / h / UIParent:GetEffectiveScale()
end

-- One physical pixel in the units of `frame`.
function P.PixelFor(frame)
	local h = ns.PhysicalHeight and ns.PhysicalHeight() or 1080
	return 768 / h / ((frame and frame:GetEffectiveScale()) or UIParent:GetEffectiveScale())
end

function P.Snap(v, frame)
	local px = P.PixelFor(frame)
	return floor(v / px + 0.5) * px
end

function P.Solid(parent, layer, sub, r, g, b, a)
	local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub)
	t:SetTexture(r or 1, g or 1, b or 1, a or 1)
	return t
end

-- Four edge textures inside a frame (the EllesmereUI "solid" pixel border).
function P.CreateEdges(parent, host, layer, sub)
	local e = { host = host or parent }
	for i = 1, 4 do
		e[i] = parent:CreateTexture(nil, layer or "OVERLAY", nil, sub or 2)
		e[i]:SetTexture(1, 1, 1, 1)
	end
	return e
end

function P.LayoutEdges(e, size, r, g, b, a, outside)
	local host = e.host
	if not size or size <= 0 then
		for i = 1, 4 do e[i]:Hide() end
		e.size = 0
		return
	end
	e.size = size
	local o = outside and -size or 0
	e[1]:ClearAllPoints()
	e[1]:SetPoint("TOPLEFT", host, "TOPLEFT", o, -o)
	e[1]:SetPoint("TOPRIGHT", host, "TOPRIGHT", -o, -o)
	e[1]:SetHeight(size)
	e[2]:ClearAllPoints()
	e[2]:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", o, o)
	e[2]:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -o, o)
	e[2]:SetHeight(size)
	e[3]:ClearAllPoints()
	e[3]:SetPoint("TOPLEFT", e[1], "BOTTOMLEFT")
	e[3]:SetPoint("BOTTOMLEFT", e[2], "TOPLEFT")
	e[3]:SetWidth(size)
	e[4]:ClearAllPoints()
	e[4]:SetPoint("TOPRIGHT", e[1], "BOTTOMRIGHT")
	e[4]:SetPoint("BOTTOMRIGHT", e[2], "TOPRIGHT")
	e[4]:SetWidth(size)
	for i = 1, 4 do
		e[i]:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
		if e.visible ~= false then
			e[i]:Show()
		end
	end
end

function P.ShowEdges(e, on)
	e.visible = on and true or false
	local show = on and (e.size or 0) > 0
	for i = 1, 4 do
		e[i]:SetShown(show)
	end
end

-- Player class color (EllesmereUI values, like the Unit Frames port).
local CLASS_COLORS = {
	DEATHKNIGHT = { 0.77, 0.12, 0.23 }, DRUID = { 1.00, 0.49, 0.04 }, HUNTER = { 0.67, 0.83, 0.45 },
	MAGE = { 0.25, 0.78, 0.92 }, MONK = { 0.00, 1.00, 0.60 }, PALADIN = { 0.96, 0.55, 0.73 },
	PRIEST = { 1, 1, 1 }, ROGUE = { 1.00, 0.96, 0.41 }, SHAMAN = { 0.00, 0.44, 0.87 },
	WARLOCK = { 0.53, 0.53, 0.93 }, WARRIOR = { 0.78, 0.61, 0.43 },
}
function P.ClassColor()
	local _, class = UnitClass("player")
	local c = class and CLASS_COLORS[class]
	if c then
		return c[1], c[2], c[3]
	end
	local rc = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if rc then
		return rc.r, rc.g, rc.b
	end
	return 1, 1, 1
end
EAB.ClassColor = P.ClassColor

-- Font face of the module (Global Settings > Fonts, module key "actionBars").
function P.FontPath()
	return (ns.GetFontPath and ns.GetFontPath("actionBars")) or (ns.MEDIA .. "Expressway.ttf")
end

-- Icon text (keybind, count, cooldown numbers): the crisp icon text outline.
function P.SetIconFont(fs, size)
	local flags = ns.GetIconTextOutlineFlag and ns.GetIconTextOutlineFlag("actionBars") or "OUTLINE"
	fs:SetFont(P.FontPath(), size, flags)
	if not fs:GetFont() then
		fs:SetFont("Fonts\\ARIALN.TTF", size, flags)
	end
	if flags == "" then
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 1)
	else
		fs:SetShadowOffset(0, 0)
	end
end

-- Module text (data bar text): the module outline (or a drop shadow).
function P.SetModuleFont(fs, size)
	if ns.ApplyModuleFont then
		ns.ApplyModuleFont(fs, size, "actionBars")
	else
		fs:SetFont(P.FontPath(), size, "")
	end
end

-- Condensed keybind text (retail FormatHotkeyText).
function P.FormatHotkey(text)
	if not text or text == "" then
		return ""
	end
	text = text:gsub("CTRL%-", "C")
	text = text:gsub("ALT%-", "A")
	text = text:gsub("SHIFT%-", "S")
	text = text:gsub("META%-", "M")
	text = text:gsub("Mouse Button ", "M")
	text = text:gsub("MOUSEWHEELUP", "MwU")
	text = text:gsub("MOUSEWHEELDOWN", "MwD")
	text = text:gsub("CAPSLOCK", "Caps")
	text = text:gsub("NUMPADDECIMAL", "N.")
	text = text:gsub("NUMPADPLUS", "N+")
	text = text:gsub("NUMPADMINUS", "N-")
	text = text:gsub("NUMPADMULTIPLY", "N*")
	text = text:gsub("NUMPADDIVIDE", "N/")
	text = text:gsub("NUMPAD", "N")
	text = text:gsub("BUTTON", "M")
	return text
end

-- Shared fader (retail FadeTo / StopFade: one OnUpdate queue, smooth easing).
do
	local queue, fadeAlpha = {}, setmetatable({}, { __mode = "k" })
	local driver = CreateFrame("Frame")
	local function OnUpdate(_, elapsed)
		local active = false
		for frame, info in pairs(queue) do
			info.elapsed = info.elapsed + elapsed
			local t = info.elapsed / info.duration
			local a
			if t >= 1 then
				a = info.to
				queue[frame] = nil
			else
				local e = t < 0.5 and (2 * t * t) or (1 - (-2 * t + 2) ^ 2 / 2)
				a = info.from + (info.to - info.from) * e
				active = true
			end
			frame:SetAlpha(a)
			fadeAlpha[frame] = a
		end
		if not active then
			driver:SetScript("OnUpdate", nil)
		end
	end
	function P.FadeTo(frame, to, duration)
		duration = duration or 0.1
		local cur = fadeAlpha[frame] or frame:GetAlpha() or 1
		if abs(cur - to) < 0.01 or duration <= 0 then
			queue[frame] = nil
			frame:SetAlpha(to)
			fadeAlpha[frame] = to
			return
		end
		local q = queue[frame]
		if q and q.to == to then
			return
		end
		queue[frame] = { from = cur, to = to, duration = duration, elapsed = 0 }
		driver:SetScript("OnUpdate", OnUpdate)
	end
	function P.StopFade(frame, alpha)
		queue[frame] = nil
		if alpha then
			frame:SetAlpha(alpha)
			fadeAlpha[frame] = alpha
		end
	end
end

-- Run after combat (protected work requested in combat).
do
	local pending = {}
	local f = CreateFrame("Frame")
	f:RegisterEvent("PLAYER_REGEN_ENABLED")
	f:SetScript("OnEvent", function()
		local list = pending
		pending = {}
		for _, fn in pairs(list) do
			fn()
		end
	end)
	function P.AfterCombat(key, fn)
		pending[key] = fn
	end
end

-- Profile shortcut.
function P.Profile()
	return EAB.db and EAB.db.profile
end

function P.BarSettings(key)
	local p = EAB.db and EAB.db.profile
	return p and p.bars[key]
end
