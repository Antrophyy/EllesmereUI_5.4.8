-------------------------------------------------------------------------------
--  EllesmereUIChallengeTimer.lua (5.4.8 port of retail EllesmereUI Mythic+ Tools, EllesmereUIMythicTimer)
--
--  The retail Mythic+ timer mapped onto Mists of Pandaria Challenge Modes:
--    * timer      = GetWorldElapsedTime of the challenge mode world timer
--    * thresholds = the medal times (GetChallengeModeMapTimes): Gold = the
--      retail "+3" line, Silver = "+2", Bronze = the time limit ("+1")
--    * objectives = C_Scenario criteria (bosses); a criteria with a count
--      (e.g. "Enemies 25/50") is drawn as the retail enemy forces bar
--    * deaths     = counted from the combat log (5.4.8 has no death counter
--      and no death time penalty)
--    * key level / affixes / score do not exist: the key level spot shows
--      the current medal instead, affixes are skipped.
--  Same saved keys as retail (retail EllesmereUIMythicTimerDB, here EllesmereUIChallengeTimerDB).
--  The cast bar features live in the other files of this addon.
-------------------------------------------------------------------------------
local addonName, P = ...
local ns = EllesmereUI
P.ns = ns

local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local format = string.format
local wipe = wipe

local EMT = {}
ns.ChallengeTimer = EMT
P.EMT = EMT
EMT.P = P  -- the options file reads the cast bar / run summary functions here

local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\media\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local FALLBACK_FONT = "Fonts\\FRIZQT__.TTF"
P.MEDIA, P.WHITE = MEDIA, WHITE

local COMPARE_NONE = "NONE"
local COMPARE_DUNGEON = "DUNGEON"
local COMPARE_LEVEL = "LEVEL"
local COMPARE_LEVEL_AFFIX = "LEVEL_AFFIX"

-- Medal icons (FrameXML CHALLENGE_MEDAL_TEXTURES_SMALL; 1 bronze .. 3 gold).
local MEDAL_ICONS = {
	[1] = "Interface\\Challenges\\challenges-bronze-sm",
	[2] = "Interface\\Challenges\\challenges-silver-sm",
	[3] = "Interface\\Challenges\\challenges-gold-sm",
}
local MEDAL_NAMES = { [0] = "No Medal", [1] = "Bronze", [2] = "Silver", [3] = "Gold" }
P.MEDAL_ICONS, P.MEDAL_NAMES = MEDAL_ICONS, MEDAL_NAMES

-------------------------------------------------------------------------------
--  Timers (5.4.8 has no C_Timer; the core ships one on an OnUpdate)
-------------------------------------------------------------------------------
local Timer = ns.C_Timer
if not Timer then
	Timer = {}
	local list = {}
	local driver = CreateFrame("Frame")
	driver:SetScript("OnUpdate", function()
		local now = GetTime()
		local i = 1
		while i <= #list do
			local t = list[i]
			if t.cancelled then
				table.remove(list, i)
			elseif now >= t.at then
				if t.period then
					t.at = now + t.period
					i = i + 1
				else
					table.remove(list, i)
				end
				local ok, err = pcall(t.fn, t)
				if not ok then geterrorhandler()(err) end
			else
				i = i + 1
			end
		end
	end)
	local function Cancel(self) self.cancelled = true end
	function Timer.After(delay, fn)
		list[#list + 1] = { at = GetTime() + (delay or 0), fn = function() fn() end }
	end
	function Timer.NewTimer(delay, fn)
		local t = { at = GetTime() + (delay or 0), fn = fn, Cancel = Cancel }
		list[#list + 1] = t
		return t
	end
	function Timer.NewTicker(period, fn)
		local t = { at = GetTime() + period, period = period, fn = fn, Cancel = Cancel }
		list[#list + 1] = t
		return t
	end
end
P.Timer = Timer

-------------------------------------------------------------------------------
--  Combat queue (secure Blizzard frames are only hidden out of combat)
-------------------------------------------------------------------------------
local combatQueue = {}
local combatFrame = CreateFrame("Frame")
combatFrame:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	local q = combatQueue
	combatQueue = {}
	for _, fn in pairs(q) do
		local ok, err = pcall(fn)
		if not ok then geterrorhandler()(err) end
	end
end)
function P.Defer(key, fn)
	combatQueue[key] = fn
	combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
end

-------------------------------------------------------------------------------
--  Bar textures ("none" = flat, a retail EllesmereUI texture key, or
--  "sm:<name>" = a LibSharedMedia status bar)
-------------------------------------------------------------------------------
P.BAR_TEXTURE_ORDER = {
	"none", "melli", "atrocity", "fade", "fade-right", "thin-line-top", "thin-line-bottom",
	"beautiful", "plating", "divide", "glass", "gradient-lr", "gradient-rl", "gradient-bt", "gradient-tb",
	"matte", "sheer", "pixels-fill", "pixels-dark", "pixels-bg", "blinkii-diamonds", "kringel-window",
}
P.BAR_TEXTURE_NAMES = {
	none = "None", melli = "Melli (ElvUI)", beautiful = "Beautiful", plating = "Plating", atrocity = "Atrocity",
	divide = "Divide", glass = "Glass", ["fade-right"] = "Fade Right", ["thin-line-top"] = "Thin Line Top",
	["thin-line-bottom"] = "Thin Line Bottom", fade = "Fade", ["gradient-lr"] = "Gradient Right",
	["gradient-rl"] = "Gradient Left", ["gradient-bt"] = "Gradient Up", ["gradient-tb"] = "Gradient Down",
	matte = "Matte", sheer = "Sheer", ["pixels-fill"] = "Pixels Fill", ["pixels-dark"] = "Pixels Dark",
	["pixels-bg"] = "Pixels Background", ["blinkii-diamonds"] = "Blinkii Diamonds", ["kringel-window"] = "Kringel Window",
}

local function LSM()
	return ns.GetLSM and ns.GetLSM() or nil
end

-- nil = flat color (retail SetColorTexture path).
function P.TexturePath(key)
	if not key or key == "none" or key == "" then
		return nil
	end
	if key:sub(1, 3) == "sm:" then
		local lsm = LSM()
		return lsm and lsm:Fetch("statusbar", key:sub(4), true) or nil
	end
	if P.BAR_TEXTURE_NAMES[key] then
		return MEDIA .. "textures\\" .. key
	end
	return nil
end

function P.TextureLabel(key)
	if key and key:sub(1, 3) == "sm:" then
		return key:sub(4)
	end
	return P.BAR_TEXTURE_NAMES[key or "none"] or "None"
end

function P.TextureItems()
	local items = {}
	for _, key in ipairs(P.BAR_TEXTURE_ORDER) do
		items[#items + 1] = { name = P.BAR_TEXTURE_NAMES[key], value = key }
	end
	local lsm = LSM()
	if lsm then
		local list = lsm:List("statusbar")
		for i = 1, #list do
			items[#items + 1] = { name = list[i], value = "sm:" .. list[i] }
		end
	end
	return items
end

-- Texture or flat color fill (retail ApplyBarTexture).
local function ApplyBarTexture(tex, texKey, r, g, b, a)
	if not tex then return end
	local path = P.TexturePath(texKey)
	if path then
		tex:SetTexture(path)
		tex:SetVertexColor(r, g, b, a)
	else
		tex:SetTexture(r, g, b, a)
		tex:SetVertexColor(1, 1, 1, 1)
	end
end
P.ApplyBarTexture = ApplyBarTexture

-------------------------------------------------------------------------------
--  Fonts (module key "mythicTimer")
-------------------------------------------------------------------------------
local function SFont()
	local p = ns.GetFontPath and ns.GetFontPath("mythicTimer")
	if p and p ~= "" then return p end
	return FALLBACK_FONT
end
local function SOutline()
	if ns.GetFontOutlineFlag then return ns.GetFontOutlineFlag("mythicTimer") or "" end
	return ""
end
local function SetFontPath(fs, path, size, flags)
	if not fs then return end
	flags = flags or SOutline()
	fs:SetFont(path, size, flags)
	if not fs:GetFont() then fs:SetFont(FALLBACK_FONT, size, flags) end
	-- No outline = drop shadow (EllesmereUI font shadow rule).
	if flags == "" then
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 1)
	else
		fs:SetShadowOffset(0, 0)
	end
end
local function SetFS(fs, size, flags)
	SetFontPath(fs, SFont(), size, flags)
end
P.SetFS = SetFS

local function Hex(r, g, b)
	return format("|cff%02x%02x%02x", floor((r or 1) * 255 + 0.5), floor((g or 1) * 255 + 0.5), floor((b or 1) * 255 + 0.5))
end
P.Hex = Hex

local function GetAccentColor()
	if ns.ResolveAccent then
		local r, g, b = ns.ResolveAccent()
		if r then return r, g, b end
	end
	return 0.05, 0.83, 0.62
end
P.GetAccentColor = GetAccentColor

-------------------------------------------------------------------------------
--  Player interrupt (shared by the cast bar files; retail EllesmereUI_Kick
--  with the Mists spells, same table as the Nameplates port)
-------------------------------------------------------------------------------
local KICKS = {
	DEATHKNIGHT = { 47528 }, WARRIOR = { 6552 }, SHAMAN = { 57994 }, ROGUE = { 1766 },
	PRIEST = { 15487 }, PALADIN = { 96231 }, MONK = { 116705 }, MAGE = { 2139 },
	HUNTER = { 147362, 34490 }, DRUID = { 80964, 80965, 106839, 78675 },
	WARLOCK = { 19647, 119910, 103135, 132409, 115781 },
}
local kickSpell
function P.RefreshKick()
	kickSpell = nil
	local _, class = UnitClass("player")
	local list = class and KICKS[class]
	if not list then return end
	local petKick
	for _, id in ipairs(list) do
		if IsSpellKnown(id, true) then
			petKick = id
		elseif IsSpellKnown(id) and not kickSpell then
			kickSpell = id
		end
	end
	kickSpell = kickSpell or petKick
end
function P.KickSpell()
	return kickSpell
end
-- Seconds until the interrupt is ready (0 = ready, nil = no interrupt).
function P.KickRemaining()
	if not kickSpell then return nil end
	local start, duration, enabled = GetSpellCooldown(kickSpell)
	if not start or enabled == 0 then return nil end
	if start == 0 or duration <= 1.5 then return 0 end
	local left = start + duration - GetTime()
	return left > 0 and left or 0
end
do
	local kf = CreateFrame("Frame")
	kf:RegisterEvent("PLAYER_LOGIN")
	kf:RegisterEvent("SPELLS_CHANGED")
	kf:RegisterEvent("PLAYER_TALENT_UPDATE")
	kf:SetScript("OnEvent", function() P.RefreshKick() end)
end

-- Class color of a class token (retail C_ClassColor).
function P.ClassColor(class)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

-------------------------------------------------------------------------------
--  Defaults (retail DB_DEFAULTS.profile)
-------------------------------------------------------------------------------
local DEFAULTS = {
	enabled           = true,
	borderTexture     = "solid",
	borderSize        = 0,
	borderR = 0, borderG = 0, borderB = 0, borderA = 1,
	showTitle         = true,
	showDungeonName   = true,
	showKeyLevelOnTimer = false,
	keyLevelTimerSpacing = 8,
	showAffixes       = true,
	showPlusTwoTimer  = true,
	showPlusThreeTimer = true,
	showThreshRemaining = false,
	showDeaths        = true,
	showObjectives    = true,
	showObjectiveTimes = true,
	objectiveTimePosition = "RIGHT",
	objectiveTextOffsetX = 0,
	objectiveTextOffsetY = 0,
	showEnemyBar      = true,
	showEnemyText     = true,
	scale             = 1.0,
	standaloneAlpha   = 0,
	showAccent        = false,
	showPreview       = false,
	enemyForcesPos    = "BOTTOM",
	enemyForcesPctPos = "LABEL",
	enemyForcesTextOffsetX = 0,
	enemyForcesTextOffsetY = 0,
	deathsInTitle     = false,
	deathTimeInTitle  = false,
	timerInBar        = false,
	showTimerBar      = true,
	showTimerBreakdown = false,
	titleAffixPosition = "ABOVE_TIMER",
	titleAffixSandwichGap = 6,
	titleAffixTimerGap = 6,
	titleAffixBarGap = 6,
	alignAllText      = "RIGHT",
	titleUseAccent    = true,
	titleColor        = { r = 1, g = 1, b = 1 },
	titleSize         = 16,
	affixSize         = 12,
	thresholdSize     = 12,
	tickAlpha         = 1,
	timerBarStyle     = "TICKS",
	timerBarSegmentGap = 2,
	thresholdTextOffsetX = 0,
	thresholdTextOffsetY = 0,
	thresholdPlusThreeTextOffsetX = 0,
	thresholdPlusThreeTextOffsetY = 0,
	thresholdPlusTwoTextOffsetX = 0,
	thresholdPlusTwoTextOffsetY = 0,
	thresholdPlusOneTextOffsetX = 0,
	thresholdPlusOneTextOffsetY = 0,
	objectivesSize    = 12,
	timerExpiredColor = { r = 0.9, g = 0.2, b = 0.2 },
	enemyForcesTextFormat = "PERCENT",
	showCompletedMilliseconds = true,
	objectiveCompareMode = "NONE",
	objectiveCompareDeltaOnly = false,
	objectiveCompareStrict = false,
	showUpcomingSplitTargets = false,
	showFastestRunSplits = false,
	frameWidth        = 260,
	barWidth          = 210,
	barHeight         = 8,
	barHeightExpanded = 22,
	barTexture        = "none",
	barBgTexture      = "none",
	enemyBarTexture   = "none",
	enemyBarBgTexture = "none",
	customBorderStyle = false,
	borderApplyToForces = true,
	rowGap            = 6,
	objectiveGap      = 4,
	timerPlusTwoColor = { r = 0.3, g = 0.8, b = 1 },
	timerPlusThreeColor = { r = 0.4, g = 1, b = 0.4 },
	timerBarUseCustomColor = false,
	timerBarColor = { r = 0.4, g = 1, b = 0.4 },
	timerSegment1Color = { r = 0.4, g = 1, b = 0.4 },
	timerSegment2Color = { r = 0.3, g = 0.8, b = 1 },
	timerSegment3Color = { r = 0xB0 / 255, g = 0x59 / 255, b = 0xCC / 255 },
	timerSegment1TextColor = { r = 0.4, g = 1, b = 0.4 },
	timerSegment2TextColor = { r = 0.3, g = 0.8, b = 1 },
	timerSegment3TextColor = { r = 1, g = 1, b = 1 },
	thresholdPlusThreeTextWhite = false,
	thresholdPlusTwoTextWhite = false,
	thresholdPlusOneTextWhite = false,
	affixTextColor    = { r = 1, g = 1, b = 1 },
	objectiveTextColor = { r = 0.9, g = 0.9, b = 0.9 },
	objectiveCompletedColor = { r = 0.3, g = 0.8, b = 0.3 },
	splitFasterColor  = { r = 0.4, g = 1, b = 0.4 },
	splitSlowerColor  = { r = 1, g = 0.45, b = 0.45 },
	deathTextColor    = { r = 0.93, g = 0.33, b = 0.33 },
	enemyBarUseAccent = true,
	enemyBarColor     = { r = 0.35, g = 0.55, b = 0.8 },
	showPullBar        = false,
	pullBarUseBarColor = true,
	pullBarColor       = { r = 1, g = 0.55, b = 0.1 },
	pullBarAlpha       = 0.35,
	tsb = {
		enabled          = false,
		growUp           = false,
		width            = 240,
		height           = 20,
		spacing          = 4,
		maxBars          = 5,
		texture          = "none",
		barColor         = { r = 0.70, g = 0.40, b = 0.90 },
		bgColor          = { r = 0, g = 0, b = 0, a = 0.45 },
		borderSize       = 1,
		showIcon         = true,
		iconOnRight      = false,
		showIconDivider  = false,
		showSpellName    = true,
		nameSize         = 10,
		nameX            = 0,
		nameY            = 0,
		showTarget       = true,
		targetSize       = 10,
		targetX          = 0,
		targetY          = 0,
		targetClassColor = true,
		targetColor      = { r = 1, g = 1, b = 1 },
		showTimer        = true,
		timerSize        = 10,
		timerX           = 0,
		timerY           = 0,
		interruptReady    = { r = 0.92, g = 0.35, b = 0.20 },
		uninterruptible   = { r = 0.45, g = 0.45, b = 0.45 },
		importantEnabled  = false,
		importantColor    = { r = 1, g = 0.2, b = 0.2 },
		importantGlow     = false,
		importantGlowStyle = 1,
		importantGlowColor = { r = 1, g = 0.2, b = 0.2 },
		importantGlowLines = 8,
		importantGlowThickness = 2,
		importantGlowSpeed = 4,
		oorEnabled       = false,
		oorAlpha         = 0.45,
		showRaidMarker   = false,
		raidMarkerSize   = 14,
		whereToShow      = {},
	},
	tfb = {
		castColor        = { r = 0.70, g = 0.40, b = 0.90 },
		interruptReady   = { r = 0.92, g = 0.35, b = 0.20 },
		uninterruptible  = { r = 0.45, g = 0.45, b = 0.45 },
		importantColor   = { r = 1, g = 0.2, b = 0.2 },
		importantEnabled = false,
		midCastColor     = { r = 0.318, g = 0.820, b = 0.357 },
		kickTickColor    = { r = 1, g = 1, b = 1 },
		kickTickEnabled  = true,
		midCastEnabled   = false,
		showShield       = true,
		showSpark        = true,
		interruptedFlash = true,
		interruptedColor = { r = 0.8, g = 0, b = 0 },
		showTarget       = true,
		targetClassColor = true,
		targetColor      = { r = 1, g = 1, b = 1 },
		target = {
			enabled = false,
			width = 260, height = 22,
			texture = "none",
			showIcon = true,
			showSpellName = true, nameSize = 11,
			showTimer = true, timerSize = 11,
			targetSize = 10,
		},
		focus = {
			enabled = false,
			width = 260, height = 22,
			texture = "none",
			showIcon = true,
			showSpellName = true, nameSize = 11,
			showTimer = true, timerSize = 11,
			targetSize = 10,
		},
	},
	runSummary = {
		enabled          = false,
		showAfterLoot    = true,
		historySize      = 20,
		scale            = 1,
		textSize         = 14,
		sortKey          = "dps",
		sortAsc          = false,
		showSpecIcons    = true,
		colItemLevel     = true,
		colScore         = true,
		colLoot          = true,
		colDps           = true,
		colDamageTaken   = true,
		colInterrupts    = true,
		colDeaths        = true,
	},
}
EMT.DEFAULTS = DEFAULTS

-- The user's retail "Naowh" profile (retail_sv), seeded on first login.
-- Split history from retail (retail map IDs) is not carried over.
local SEED = {
	barHeight = 10,
	tfb = {
		showSpark = false,
		focus = {
			enabled = true, timerSize = 14, width = 380, texture = "sm:NaowhGradient",
			targetSize = 14, height = 32, nameSize = 14,
			pos = { centerX = 0, centerY = 89.5 },
		},
		importantEnabled = true,
		interruptReady = { r = 1, g = 0.31372549019608, b = 0.34117647058824 },
		uninterruptible = { r = 0.70588235294118, g = 0.73333333333333, b = 0.69411764705882 },
		importantColor = { r = 0.9921568627451, g = 0.30196078431373, b = 1 },
		castColor = { r = 0, g = 0.70196078431373, b = 1 },
		showShield = false,
	},
	thresholdSize = 14,
	enemyBarColor = { r = 0.98823529411765, g = 0.60392156862745, b = 0 },
	titleUseAccent = false,
	objectivesSize = 14,
	timerSegment3Color = { r = 0.85026088153798, g = 0.38500004917383, b = 1 },
	enemyForcesTextOffsetY = 10,
	hideEnemyForcesLabel = true,
	enemyForcesTextOffsetX = -2,
	timerBarStyle = "SEGMENTS",
	barHeightExpanded = 13,
	standalonePos = { centerX = 1150, centerY = 311 },
	barFillAlphaExpanded = 1,
	enemyBarTexture = "sm:NaowhGradient",
	timerInBarLeftText = true,
	showDungeonName = false,
	barTexture = "sm:NaowhGradient",
	timerFont = "GothamNarrowUltra",
	tsb = {
		maxBars = 6,
		enabled = true,
		uninterruptible = { r = 0.7058823529411765, g = 0.7333333333333333, b = 0.6941176470588235 },
		whereToShow = { dungeon_mythic = true, dungeon_nonmythic = true },
		height = 26,
		pos = { centerX = -440, centerY = 60 },
		raidMarkerSize = 18,
		barColor = { r = 1, g = 0.9333333333333333, b = 0.4313725490196079 },
		showRaidMarker = true,
		importantEnabled = true,
		targetSize = 14,
		importantColor = { r = 0.9921568627451, g = 0.30196078431373, b = 1 },
		importantGlowColor = { b = 0.2800000138208, g = 0.2800000138208 },
		spacing = 1,
		timerSize = 14,
		importantGlow = true,
		texture = "sm:NaowhGradient",
		importantGlowSpeed = 5,
		nameSize = 14,
		interruptReady = { r = 1, g = 0.9333333333333333, b = 0.4313725490196079 },
		growUp = true,
		importantGlowThickness = 1,
	},
	showKeyLevelOnTimer = true,
	timerTextSize = 24,
	showAffixes = false,
	titleAffixDeathGap = 10,
	titleAffixTimerGap = -10,
	objectiveCompareMode = "LEVEL",
	enemyBarUseAccent = false,
	barBgTexture = "sm:NaowhLeft",
	thresholdPlusOneTextOffsetY = -8,
	tickWhite = true,
	thresholdPlusTwoTextOffsetY = -9,
	enemyForcesPos = "UNDER_BAR",
	borderSize = 1,
	showTitle = false,
	keyLevelTimerSpacing = 0,
	objectiveTextOffsetY = 12,
	enemyForcesTextFormat = "COUNT_REMAINING",
	titleAffixBarGap = 10,
	customBorderStyle = true,
	affixSize = 14,
	timerBarSegmentGap = 4,
	thresholdPlusThreeTextOffsetY = -9,
	titleAffixPosition = "BELOW_TIMER",
	enemyBarBgTexture = "sm:NaowhLeft",
	objectiveTimePosition = "LEFT",
	barWidth = 230,
}

local function DeepCopy(v)
	if type(v) ~= "table" then return v end
	local t = {}
	for k, x in pairs(v) do t[k] = DeepCopy(x) end
	return t
end
P.DeepCopy = DeepCopy

-- Missing keys from defaults (sub tables merged too, like retail Lite DB).
local function FillDefaults(dst, src)
	for k, v in pairs(src) do
		if dst[k] == nil then
			dst[k] = DeepCopy(v)
		elseif type(v) == "table" and type(dst[k]) == "table" and k ~= "whereToShow" then
			FillDefaults(dst[k], v)
		end
	end
end

local function Overlay(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" and type(dst[k]) == "table" and k ~= "whereToShow" then
			Overlay(dst[k], v)
		else
			dst[k] = DeepCopy(v)
		end
	end
end

local root  -- EllesmereUIChallengeTimerDB (the profile)
local db    -- { profile = root }, the retail Lite DB shape the ported code reads

function EMT.DB()
	return root
end
P.DB = function() return db end

local function Seed(t)
	FillDefaults(t, DEFAULTS)
	Overlay(t, SEED)
	t._seeded = 1
end

-- Retail profile import (Profiles > Import a retail string): retail keys
-- are kept as they are; split history (retail map IDs) is dropped.
if ns.ProfileRetail and ns.ProfileRetail.CONVERT then
	ns.ProfileRetail.CONVERT[addonName] = function(blob, notes)
		local out = DeepCopy(blob) or {}
		out.bestObjectiveSplits = nil
		out.fastestRunSplits = nil
		out._activeRunSplits = nil
		out.showPreview = nil
		out._seeded = 1
		if notes and type(notes) == "table" then
			notes[#notes + 1] = "Challenge Mode Tools: affixes, key level, M+ score, loot, current pull and important-cast flags have no 5.4.8 counterpart."
		end
		return out
	end
end

-------------------------------------------------------------------------------
--  State
-------------------------------------------------------------------------------
local currentRun = {
	active        = false,
	mapID         = nil,
	mapName       = "",
	level         = 0,
	affixes       = {},
	maxTime       = 0,
	plusTwoT      = 0,
	plusThreeT    = 0,
	elapsed       = 0,
	completed     = false,
	deaths        = 0,
	deathTimeLost = 0,
	objectives    = {},
	medal         = nil,
}
EMT.currentRun = currentRun
local playerDeaths = {}
EMT.playerDeaths = playerDeaths

local standaloneFrame
local standaloneCreated = false
local unlockLayoutActive = false

-------------------------------------------------------------------------------
--  Helpers (retail)
-------------------------------------------------------------------------------
local function FormatTime(seconds, withMilliseconds)
	if not seconds or seconds < 0 then seconds = 0 end
	local whole = floor(seconds)
	local m = floor(whole / 60)
	local s = floor(whole % 60)
	if withMilliseconds then
		local ms = floor(((seconds - whole) * 1000) + 0.5)
		if ms >= 1000 then
			whole = whole + 1
			m = floor(whole / 60)
			s = floor(whole % 60)
			ms = 0
		end
		return format("%02d:%02d.%03d", m, s, ms)
	end
	return format("%02d:%02d", m, s)
end
P.FormatTime = FormatTime

local function FormatRemaining(remaining)
	if remaining and remaining < 0 then
		return "-" .. FormatTime(-remaining)
	end
	return FormatTime(remaining)
end

local function RoundToInt(value)
	if not value then return 0 end
	return floor(value + 0.5)
end

local function GetColor(tbl, fallbackR, fallbackG, fallbackB)
	if tbl then
		return tbl.r or fallbackR, tbl.g or fallbackG, tbl.b or fallbackB
	end
	return fallbackR, fallbackG, fallbackB
end
P.GetColor = GetColor

local function GetTimerBarFillColor(profile, elapsed, plusThreeTime, plusTwoTime, maxTime)
	if profile and profile.timerBarUseCustomColor == true then
		return GetColor(profile.timerBarColor, 0.4, 1, 0.4)
	end
	if maxTime and maxTime > 0 and elapsed > plusTwoTime then
		return 0xB0 / 255, 0x59 / 255, 0xCC / 255
	elseif maxTime and maxTime > 0 and elapsed > plusThreeTime then
		return GetColor(profile and profile.timerPlusTwoColor, 0.3, 0.8, 1)
	end
	return GetColor(profile and profile.timerPlusThreeColor, 0.4, 1, 0.4)
end

local function GetTimerSegmentFillColor(profile, elapsed, plusThreeTime, plusTwoTime)
	if elapsed > plusTwoTime then
		return GetColor(profile and profile.timerSegment3Color, 0xB0 / 255, 0x59 / 255, 0xCC / 255)
	elseif elapsed > plusThreeTime then
		return GetColor(profile and profile.timerSegment2Color, 0.3, 0.8, 1)
	end
	return GetColor(profile and profile.timerSegment1Color, 0.4, 1, 0.4)
end

local function GetTimerSegmentTextColor(profile, index)
	if index == 3 then
		if profile and profile.thresholdPlusOneTextWhite == true then return 1, 1, 1 end
		return GetColor(profile and profile.timerSegment3Color, 0xB0 / 255, 0x59 / 255, 0xCC / 255)
	elseif index == 2 then
		if profile and profile.thresholdPlusTwoTextWhite == true then return 1, 1, 1 end
		return GetColor(profile and profile.timerSegment2Color, 0.3, 0.8, 1)
	end
	if profile and profile.thresholdPlusThreeTextWhite == true then return 1, 1, 1 end
	return GetColor(profile and profile.timerSegment1Color, 0.4, 1, 0.4)
end

-- Medal still reachable at this time (3 gold .. 1 bronze, 0 none).
local function MedalFor(run, elapsed)
	if not run or (run.maxTime or 0) <= 0 then return nil end
	if run.completed and run.medal then return run.medal end
	elapsed = elapsed or run.elapsed or 0
	if elapsed < (run.plusThreeT or 0) then return 3 end
	if elapsed < (run.plusTwoT or 0) then return 2 end
	if elapsed < run.maxTime then return 1 end
	return 0
end
EMT.MedalFor = MedalFor

local function MedalIcon(medal, size)
	local tex = medal and MEDAL_ICONS[medal]
	if not tex then return "" end
	return format("|T%s:%d:%d:0:0|t", tex, size, size)
end

-------------------------------------------------------------------------------
--  Split compare (retail; level = 0 and no affixes on 5.4.8, so the level
--  scopes behave like the dungeon scope)
-------------------------------------------------------------------------------
local function NormalizeAffixKey(affixes)
	local ids = {}
	for _, affixID in ipairs(affixes or {}) do
		ids[#ids + 1] = affixID
	end
	table.sort(ids)
	return table.concat(ids, "-")
end

local function GetScopeKey(run, mode)
	if not run or not run.mapID then return nil end
	if mode == COMPARE_DUNGEON then
		return tostring(run.mapID)
	elseif mode == COMPARE_LEVEL then
		return format("%s:%d", run.mapID, run.level or 0)
	elseif mode == COMPARE_LEVEL_AFFIX then
		return format("%s:%d:%s", run.mapID, run.level or 0, NormalizeAffixKey(run.affixes))
	end
	return nil
end

local function EnsureProfileStore(key)
	if not root then return nil end
	if type(root[key]) ~= "table" then root[key] = {} end
	return root[key]
end

local function GetReferenceObjectiveTime(run, objectiveIndex, mode)
	if mode == COMPARE_NONE then return nil end
	local store = (root.showFastestRunSplits and EnsureProfileStore("fastestRunSplits")) or EnsureProfileStore("bestObjectiveSplits")
	if not store then return nil end
	local tryOrder
	if root.objectiveCompareStrict == true then
		tryOrder = { mode }
	elseif mode == COMPARE_LEVEL_AFFIX then
		tryOrder = { COMPARE_LEVEL_AFFIX, COMPARE_LEVEL, COMPARE_DUNGEON }
	elseif mode == COMPARE_LEVEL then
		tryOrder = { COMPARE_LEVEL, COMPARE_DUNGEON }
	else
		tryOrder = { mode }
	end
	for _, tryMode in ipairs(tryOrder) do
		local scopeKey = GetScopeKey(run, tryMode)
		local scope = scopeKey and store[scopeKey]
		if scope and scope[objectiveIndex] then
			return scope[objectiveIndex]
		end
	end
	return nil
end

local function UpdateBestObjectiveSplits(run, objectiveIndex, elapsed)
	local store = EnsureProfileStore("bestObjectiveSplits")
	if not store then return end
	for _, mode in ipairs({ COMPARE_DUNGEON, COMPARE_LEVEL, COMPARE_LEVEL_AFFIX }) do
		local scopeKey = GetScopeKey(run, mode)
		if scopeKey then
			if not store[scopeKey] then store[scopeKey] = {} end
			local previous = store[scopeKey][objectiveIndex]
			if not previous or elapsed < previous then
				store[scopeKey][objectiveIndex] = elapsed
			end
		end
	end
end

local function UpdateObjectiveCompletion(obj, objectiveIndex)
	if not root or not obj or not obj.elapsed or obj.elapsed <= 0 then return end
	local compareMode = root.objectiveCompareMode or COMPARE_NONE
	local reference = GetReferenceObjectiveTime(currentRun, objectiveIndex, compareMode)
	obj.referenceElapsed = reference
	obj.compareDelta = reference and (obj.elapsed - reference) or nil
	obj.isNewBest = reference == nil or obj.elapsed < reference
	UpdateBestObjectiveSplits(currentRun, objectiveIndex, obj.elapsed)
end

local function SaveFastestRunSplits()
	local store = EnsureProfileStore("fastestRunSplits")
	if not store then return end
	local run = currentRun
	local elapsed = run.elapsed
	if type(elapsed) ~= "number" then return end
	for _, mode in ipairs({ COMPARE_DUNGEON, COMPARE_LEVEL, COMPARE_LEVEL_AFFIX }) do
		local scopeKey = GetScopeKey(run, mode)
		if scopeKey then
			if not store[scopeKey] then store[scopeKey] = {} end
			local previousRunTime = store[scopeKey].overallRunTime
			if not previousRunTime or elapsed < previousRunTime then
				store[scopeKey].overallRunTime = elapsed
				for objectiveIndex, objective in ipairs(run.objectives) do
					store[scopeKey][objectiveIndex] = objective.elapsed
				end
			end
		end
	end
end

local function BuildSplitCompareText(referenceTime, currentTime, deltaOnly, fasterColor, slowerColor)
	if not referenceTime then return "" end
	if not currentTime then
		return format("  |cff888888(%s)|r", FormatTime(referenceTime))
	end
	local diff = currentTime - referenceTime
	local color = diff <= 0 and fasterColor or slowerColor
	local cR, cG, cB = GetColor(color, 0.4, 1, 0.4)
	local diffPrefix = diff < 0 and "-" or "+"
	local diffText = diff == 0 and "0:00" or FormatTime(abs(diff))
	local colorHex = Hex(cR, cG, cB)
	if deltaOnly then
		return format("  %s(%s%s)|r", colorHex, diffPrefix, diffText)
	end
	return format("  |cff888888(%s, %s%s%s)|r", FormatTime(referenceTime), colorHex, diffPrefix, diffText)
end

local function FormatEnemyForcesText(enemyObj, formatId, compact)
	local rawCurrent = enemyObj.rawQuantity or enemyObj.quantity or 0
	local rawTotal = enemyObj.rawTotalQuantity or enemyObj.totalQuantity or 100
	local percent = enemyObj.percent or enemyObj.quantity or 0
	local remaining = max(0, rawTotal - rawCurrent)
	local suffix = compact and "" or " Enemy Forces"
	if formatId == "COUNT" then
		return format("%d/%d%s", RoundToInt(rawCurrent), RoundToInt(rawTotal), suffix)
	elseif formatId == "COUNT_PERCENT" then
		return format("%d/%d - %.2f%%%s", RoundToInt(rawCurrent), RoundToInt(rawTotal), percent, suffix)
	elseif formatId == "COUNT_REMAINING" then
		return format("%d/%d (%d left)%s", RoundToInt(rawCurrent), RoundToInt(rawTotal), RoundToInt(remaining), suffix)
	elseif formatId == "PERCENT_COUNT_REMAINING" then
		-- NaowhUI extra format: "78.42% | 188/240 | 52 left"
		return format("%.2f%% || %d/%d || %d left%s", percent, RoundToInt(rawCurrent), RoundToInt(rawTotal), RoundToInt(remaining), suffix)
	elseif formatId == "REMAINING" then
		if compact then
			return format("%d left", RoundToInt(remaining))
		end
		return format("%d remaining%s", RoundToInt(remaining), suffix)
	end
	return format("%.2f%%%s", percent, suffix)
end

-------------------------------------------------------------------------------
--  Objectives: C_Scenario criteria of the current step.
--  C_Scenario.GetCriteriaInfo(i) -> criteriaString, criteriaType, completed,
--  quantity, totalQuantity, flags, assetID, quantityString, criteriaID
-------------------------------------------------------------------------------
local function UpdateObjectives()
	local _, _, numCriteria = C_Scenario.GetStepInfo()
	numCriteria = numCriteria or 0
	local elapsed = currentRun.elapsed
	currentRun._weightedObj = nil
	for i = 1, numCriteria do
		local desc, _, completed, quantity, totalQuantity = C_Scenario.GetCriteriaInfo(i)
		if desc then
			local obj = currentRun.objectives[i]
			if not obj then
				obj = {
					name = "", completed = false, elapsed = 0, quantity = 0, totalQuantity = 0,
					rawQuantity = 0, rawTotalQuantity = 0, percent = 0, isWeighted = false,
				}
				currentRun.objectives[i] = obj
			end
			local rawName = desc ~= "" and desc or ("Objective " .. i)
			rawName = rawName:gsub("^%-%s*", "")
			obj.name = rawName
			local wasCompleted = obj.completed
			obj.completed = completed and true or false
			if obj.completed and not wasCompleted then
				local saved = root and root._activeRunSplits and root._activeRunSplits[i]
				if saved and saved > 0 then
					obj.elapsed = saved
				else
					obj.elapsed = elapsed
					if root then
						if type(root._activeRunSplits) ~= "table" then root._activeRunSplits = {} end
						root._activeRunSplits[i] = elapsed
					end
				end
				UpdateObjectiveCompletion(obj, i)
			end
			quantity = quantity or 0
			totalQuantity = totalQuantity or 0
			obj.quantity = quantity
			obj.totalQuantity = totalQuantity
			obj.rawQuantity = quantity
			obj.rawTotalQuantity = totalQuantity
			-- A counted criteria (the enemy count of a Challenge Mode) takes the
			-- retail enemy forces bar.
			if totalQuantity > 1 then
				obj.isWeighted = true
				currentRun._weightedObj = currentRun._weightedObj or obj
				local percent = quantity / totalQuantity * 100
				obj.quantity = floor(percent * 100 + 0.5) / 100
				obj.percent = obj.quantity
				if obj.completed then
					obj.quantity = 100
					obj.percent = 100
					obj.rawQuantity = totalQuantity
				end
			else
				obj.isWeighted = false
				obj.percent = 0
				if obj.totalQuantity == 0 then
					obj.quantity = obj.completed and 1 or 0
					obj.totalQuantity = 1
				end
			end
		end
	end
	if currentRun.completed then
		SaveFastestRunSplits()
	end
	for i = numCriteria + 1, #currentRun.objectives do
		currentRun.objectives[i] = nil
	end
end

local function IsDungeonComplete()
	local _, _, numCriteria = C_Scenario.GetStepInfo()
	numCriteria = numCriteria or 0
	if numCriteria == 0 then return false end
	local seenAny = false
	for i = 1, numCriteria do
		local desc, _, completed = C_Scenario.GetCriteriaInfo(i)
		if desc then
			seenAny = true
			if not completed then return false end
		end
	end
	return seenAny
end

-------------------------------------------------------------------------------
--  Coalesced refresh
-------------------------------------------------------------------------------
local refreshPending = false
local function NotifyRefresh()
	if refreshPending then return end
	refreshPending = true
	Timer.After(0.05, function()
		refreshPending = false
		if EMT.Render then EMT.Render() end
	end)
end
EMT.NotifyRefresh = NotifyRefresh

-------------------------------------------------------------------------------
--  Challenge Mode world timer
-------------------------------------------------------------------------------
local CM_TIMER_TYPE = LE_WORLD_ELAPSED_TIMER_TYPE_CHALLENGE_MODE or 1

-- timerID, elapsed of the running challenge mode timer (nil = none).
local function FindChallengeTimer()
	local ids = { GetWorldElapsedTimers() }
	for i = 1, #ids do
		local id = ids[i]
		if id then
			local _, elapsed, kind = GetWorldElapsedTime(id)
			if kind == CM_TIMER_TYPE then
				return id, elapsed or 0
			end
		end
	end
	return nil
end

local function InChallengeMode()
	if C_Scenario.IsChallengeMode and C_Scenario.IsChallengeMode() then
		return true
	end
	local _, instanceType, difficulty = GetInstanceInfo()
	return instanceType == "party" and difficulty == 8
end
EMT.InChallengeMode = InChallengeMode

local lastTickedSec = -1
local function OnTimerTick()
	if not currentRun.active then return end
	if not currentRun.timerID then
		currentRun.timerID = FindChallengeTimer()
	end
	local elapsed
	if currentRun.timerID then
		local _, e = GetWorldElapsedTime(currentRun.timerID)
		elapsed = e
	end
	if not (elapsed and elapsed >= 0) then elapsed = currentRun.elapsed or 0 end
	local sec = floor(elapsed)
	if sec == lastTickedSec then return end
	lastTickedSec = sec
	currentRun.elapsed = elapsed
	UpdateObjectives()
	NotifyRefresh()
end

local tickFrame = CreateFrame("Frame")
local tickAccum = 0
local function OnUpdateTick(_, dt)
	tickAccum = tickAccum + dt
	if tickAccum < 0.2 then return end
	tickAccum = 0
	OnTimerTick()
end
local function StartTimerLoop()
	tickAccum = 0
	tickFrame:SetScript("OnUpdate", OnUpdateTick)
end
local function StopTimerLoop()
	tickFrame:SetScript("OnUpdate", nil)
end

-------------------------------------------------------------------------------
--  Deaths: UNIT_DIED of group members from the combat log (retail reads the
--  death count of C_ChallengeMode; 5.4.8 has none and no time penalty).
-------------------------------------------------------------------------------
local GROUP_UNITS = { "player", "party1", "party2", "party3", "party4" }
local function GroupUnitByGUID(guid)
	if not guid then return nil end
	for i = 1, #GROUP_UNITS do
		local u = GROUP_UNITS[i]
		if UnitGUID(u) == guid then return u end
	end
	return nil
end
P.GroupUnitByGUID = GroupUnitByGUID
P.GROUP_UNITS = GROUP_UNITS

local deathFrame = CreateFrame("Frame")
deathFrame:SetScript("OnEvent", function(_, _, _, subEvent, _, _, _, _, _, destGUID, destName)
	if subEvent ~= "UNIT_DIED" or not currentRun.active then return end
	local unit = GroupUnitByGUID(destGUID)
	if not unit then return end
	if UnitIsFeignDeath(unit) then return end
	local name = UnitName(unit) or destName or "?"
	playerDeaths[name] = (playerDeaths[name] or 0) + 1
	currentRun.deaths = (currentRun.deaths or 0) + 1
	NotifyRefresh()
end)

-------------------------------------------------------------------------------
--  Blizzard tracker: hide the WatchFrame (it holds the Challenge Mode timer
--  and the scenario objectives) while our timer runs. Hide out of combat
--  only (quest item buttons in it are secure); alpha 0 until then.
-------------------------------------------------------------------------------
local function TrackerShouldBeHidden()
	if not (root and root.enabled) then return false end
	if currentRun.active then return true end
	if currentRun.completed then
		local _, iType = GetInstanceInfo()
		return iType == "party"
	end
	return false
end

local function FinishTrackerHide()
	local f = _G.WatchFrame
	if not f then return end
	f:SetAlpha(1)
	if TrackerShouldBeHidden() then f:Hide() end
end

local function HideTracker(f)
	if InCombatLockdown() then
		f:SetAlpha(0)
		P.Defer("TrackerHide", FinishTrackerHide)
	else
		f:SetAlpha(1)
		f:Hide()
	end
end

local trackerHooked = false
local trackerHiddenByUs = false
local function ApplyTrackerVisibility()
	local f = _G.WatchFrame
	if not f then return end
	if not trackerHooked then
		trackerHooked = true
		hooksecurefunc(f, "Show", function(self)
			if TrackerShouldBeHidden() then HideTracker(self) end
		end)
	end
	if TrackerShouldBeHidden() then
		trackerHiddenByUs = true
		HideTracker(f)
	elseif trackerHiddenByUs then
		trackerHiddenByUs = false
		local function Restore()
			f:SetAlpha(1)
			f:Show()
		end
		if InCombatLockdown() then
			P.Defer("TrackerHide", Restore)
		else
			Restore()
		end
	end
end
EMT.ApplyTrackerVisibility = ApplyTrackerVisibility

-------------------------------------------------------------------------------
--  Run lifecycle
-------------------------------------------------------------------------------
local function MapTimes(mapID)
	if not mapID then return nil end
	local bronze, silver, gold = GetChallengeModeMapTimes(mapID)
	return bronze, silver, gold
end

local function StartRun()
	local name, _, _, _, _, _, _, mapID = GetInstanceInfo()
	if not mapID then return end
	lastTickedSec = -1
	local bronze, silver, gold = MapTimes(mapID)
	currentRun.active        = true
	currentRun.completed     = false
	currentRun.mapID         = mapID
	currentRun.mapName       = name or "Challenge Mode"
	currentRun.level         = 0
	currentRun.maxTime       = bronze or 0
	currentRun.plusTwoT      = silver or (currentRun.maxTime * 0.8)
	currentRun.plusThreeT    = gold or (currentRun.maxTime * 0.6)
	currentRun.medal         = nil
	currentRun.deaths        = 0
	currentRun.deathTimeLost = 0
	currentRun.timerID, currentRun.elapsed = FindChallengeTimer()
	currentRun.elapsed = currentRun.elapsed or 0
	wipe(playerDeaths)
	wipe(currentRun.affixes)
	currentRun.preciseCompletedElapsed = nil
	wipe(currentRun.objectives)
	deathFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	StartTimerLoop()
	OnTimerTick()
	ApplyTrackerVisibility()
	NotifyRefresh()
	if P.RS_RunStarted then P.RS_RunStarted() end
end

-- The exact time and medal once the server sends them (CHALLENGE_MODE_COMPLETED).
-- GetChallengeModeCompletionInfo: mapID, medal, completionTime (ms), money, numRewards
function EMT.ApplyCompletionInfo()
	local _, medal, completionTime = GetChallengeModeCompletionInfo()
	if completionTime and completionTime > 0 then
		currentRun.elapsed = completionTime / 1000
		currentRun.preciseCompletedElapsed = currentRun.elapsed
		if medal and medal >= 0 then currentRun.medal = medal end
	end
end

local function CompleteRun()
	if currentRun.completed then return end
	currentRun.completed = true
	currentRun.active = false
	StopTimerLoop()
	deathFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	if currentRun.timerID then
		local _, e = GetWorldElapsedTime(currentRun.timerID)
		currentRun.elapsed = e or currentRun.elapsed
	end
	currentRun.medal = MedalFor({ maxTime = currentRun.maxTime, plusTwoT = currentRun.plusTwoT,
		plusThreeT = currentRun.plusThreeT }, currentRun.elapsed)
	EMT.ApplyCompletionInfo()
	UpdateObjectives()
	if root then root._activeRunSplits = nil end
	NotifyRefresh()
	if P.RS_RunCompleted then P.RS_RunCompleted(currentRun) end
end

local function ResetRun()
	lastTickedSec = -1
	currentRun.active    = false
	currentRun.completed = false
	currentRun.mapID     = nil
	currentRun.mapName   = ""
	currentRun.level     = 0
	currentRun.maxTime   = 0
	currentRun.plusTwoT  = 0
	currentRun.plusThreeT = 0
	currentRun.elapsed   = 0
	currentRun.deaths    = 0
	currentRun.deathTimeLost = 0
	currentRun.timerID   = nil
	currentRun.medal     = nil
	currentRun.preciseCompletedElapsed = nil
	wipe(playerDeaths)
	wipe(currentRun.affixes)
	wipe(currentRun.objectives)
	if root then root._activeRunSplits = nil end
	StopTimerLoop()
	deathFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	ApplyTrackerVisibility()
	NotifyRefresh()
	if P.RS_RunReset then P.RS_RunReset() end
end

-------------------------------------------------------------------------------
--  Preview data (a Mists Challenge Mode)
-------------------------------------------------------------------------------
local PREVIEW_RUN = {
	active        = true,
	completed     = false,
	mapID         = 960,
	mapName       = "Temple of the Jade Serpent",
	level         = 0,
	maxTime       = 1800,
	plusTwoT      = 1200,
	plusThreeT    = 900,
	elapsed       = 1010,
	deaths        = 2,
	deathTimeLost = 0,
	affixes       = {},
	preciseCompletedElapsed = nil,
	objectives    = {
		{ name = "Wise Mari",              completed = true,  elapsed = 290,  quantity = 1, totalQuantity = 1, rawQuantity = 1, rawTotalQuantity = 1, percent = 0, isWeighted = false, previewSplit = 305 },
		{ name = "Lorewalker Stonestep",   completed = true,  elapsed = 560,  quantity = 1, totalQuantity = 1, rawQuantity = 1, rawTotalQuantity = 1, percent = 0, isWeighted = false, previewSplit = 540 },
		{ name = "Liu Flameheart",         completed = false, elapsed = 0,    quantity = 0, totalQuantity = 1, rawQuantity = 0, rawTotalQuantity = 1, percent = 0, isWeighted = false, previewSplit = 780 },
		{ name = "Sha of Doubt",           completed = false, elapsed = 0,    quantity = 0, totalQuantity = 1, rawQuantity = 0, rawTotalQuantity = 1, percent = 0, isWeighted = false, previewSplit = 1050 },
		{ name = "Enemies",                completed = false, elapsed = 0,    quantity = 78.42, totalQuantity = 100, rawQuantity = 40, rawTotalQuantity = 51, percent = 78.42, isWeighted = true },
	},
}

-------------------------------------------------------------------------------
--  Text helpers (retail)
-------------------------------------------------------------------------------
local function TimerFont()
	local key = root and root.timerFont
	if key and key ~= "__global" and ns.ResolveFontName then
		local path = ns.ResolveFontName(key)
		if path and path ~= "" then return path end
	end
	return SFont()
end
local function SetTimerFS(fs, size, flags)
	SetFontPath(fs, TimerFont(), size, flags)
end

local function SetTextDiff(fs, text)
	if not fs then return end
	text = text or ""
	if fs._lastText == text then return end
	fs:SetText(text)
	fs._lastText = text
end

local function SetFittedText(fs, text, maxWidth, preferredSize, minSize)
	if not fs then return end
	text = text or ""
	preferredSize = preferredSize or 10
	minSize = minSize or 8
	for size = preferredSize, minSize, -1 do
		SetFS(fs, size)
		fs:SetText(text)
		if not maxWidth or fs:GetStringWidth() <= maxWidth then
			return
		end
	end
end

local function WidestDigitChar(fs)
	fs:SetWidth(0)
	local widest, widestW = "9", 0
	for d = 0, 9 do
		local ch = tostring(d)
		fs:SetText(ch)
		local w = fs:GetStringWidth() or 0
		if w > widestW then widestW = w; widest = ch end
	end
	return widest
end

local function SetThreshText(fs, text)
	local visible = (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
	fs:SetText((visible:gsub("%d", WidestDigitChar(fs))))
	local w = (fs:GetStringWidth() or 0) + 1
	fs:SetWidth(w)
	fs:SetText(text)
	return w
end

-------------------------------------------------------------------------------
--  Solid border around a bar (retail PP border; 5.4.8 port: solid only)
-------------------------------------------------------------------------------
local function EnsureEdges(owner, key, parent)
	local e = owner[key]
	if e then return e end
	local holder = CreateFrame("Frame", nil, parent)
	holder:EnableMouse(false)
	e = { holder = holder }
	for i = 1, 4 do
		e[i] = holder:CreateTexture(nil, "OVERLAY", nil, 7)
		e[i]:SetTexture(WHITE)
	end
	owner[key] = e
	return e
end

local function ApplyEdges(owner, key, parent, anchor, size, r, g, b, a, force)
	if not anchor then return end
	if size <= 0 or not (force or anchor:IsShown()) then
		if owner[key] then owner[key].holder:Hide() end
		return
	end
	local e = EnsureEdges(owner, key, parent)
	local h = e.holder
	h:ClearAllPoints()
	h:SetAllPoints(anchor)
	h:SetFrameLevel(max(parent:GetFrameLevel() + 10, anchor:GetFrameLevel() + 5))
	local px = (ns.PP and ns.PP.mult or 1) * size
	for i = 1, 4 do
		e[i]:SetVertexColor(r, g, b, a)
		e[i]:ClearAllPoints()
	end
	e[1]:SetPoint("TOPLEFT", h, "TOPLEFT", 0, 0); e[1]:SetPoint("TOPRIGHT", h, "TOPRIGHT", 0, 0); e[1]:SetHeight(px)
	e[2]:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 0, 0); e[2]:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 0, 0); e[2]:SetHeight(px)
	e[3]:SetPoint("TOPLEFT", h, "TOPLEFT", 0, 0); e[3]:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 0, 0); e[3]:SetWidth(px)
	e[4]:SetPoint("TOPRIGHT", h, "TOPRIGHT", 0, 0); e[4]:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 0, 0); e[4]:SetWidth(px)
	h:Show()
end
P.ApplyEdges = ApplyEdges

function EMT.ApplyBorder()
	local f = standaloneFrame
	if not f or not root then return end
	local p = root
	local size = p.borderSize or 0
	if not p.customBorderStyle then size = 0 end
	local r, g, b, a = p.borderR or 0, p.borderG or 0, p.borderB or 0, p.borderA or 1
	local isSegmented = (p.timerBarStyle == "SEGMENTS")
	ApplyEdges(f, "_emtBarBorder", f, f._barHost, isSegmented and 0 or size, r, g, b, a)
	local forcesSize = size
	if p.borderApplyToForces == false then forcesSize = 0 end
	ApplyEdges(f, "_emtEnemyBorder", f, f._enemyBarHost, forcesSize, r, g, b, a)
	if f._timerSegHosts then
		for i, host in ipairs(f._timerSegHosts) do
			ApplyEdges(f, "_emtSegBorder" .. i, f, host, isSegmented and size or 0, r, g, b, a)
		end
	end
end

-------------------------------------------------------------------------------
--  Standalone frame
-------------------------------------------------------------------------------
local function NewFS(parent)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	SetFS(fs, 12)
	fs:SetWordWrap(false)
	return fs
end

local function NewBarHost(parent)
	local host = CreateFrame("Frame", nil, parent)
	host:EnableMouse(false)
	host._bg = host:CreateTexture(nil, "BACKGROUND", nil, 1)
	host._bg:SetAllPoints(host)
	host._fill = host:CreateTexture(nil, "ARTWORK")
	host:Hide()
	return host
end

local objRows = {}
local function GetObjRow(parent, idx)
	if objRows[idx] then return objRows[idx] end
	local entry = { name = NewFS(parent), time = NewFS(parent) }
	entry.name:SetNonSpaceWrap(false)
	entry.time:SetNonSpaceWrap(false)
	objRows[idx] = entry
	return entry
end

local function CreateStandaloneFrame()
	if standaloneCreated then return standaloneFrame end
	standaloneCreated = true

	local f = CreateFrame("Frame", "EllesmereUIChallengeTimerStandalone", UIParent)
	f:SetSize(260, 200)
	f:SetPoint("RIGHT", UIParent, "RIGHT", -100, 0)
	f:SetFrameStrata("MEDIUM")
	f:SetFrameLevel(10)
	f:SetClampedToScreen(true)
	f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
	f:SetBackdropColor(0.05, 0.04, 0.08, 0.85)
	f:SetBackdropBorderColor(0.15, 0.15, 0.15, 0.6)

	f._emtTextLayer = CreateFrame("Frame", nil, f)
	f._emtTextLayer:SetAllPoints(f)
	f._emtTextLayer:SetFrameLevel(f:GetFrameLevel() + 30)
	f._emtTextLayer:EnableMouse(false)

	f._accent = f:CreateTexture(nil, "BORDER")
	f._accent:SetWidth(2)
	f._accent:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
	f._accent:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)

	f._titleFS = NewFS(f)
	f._titleFS:SetJustifyV("MIDDLE")
	f._affixFS = NewFS(f)
	f._timerFS = NewFS(f)
	f._timerFS:SetJustifyH("CENTER")
	f._timerFS:SetNonSpaceWrap(false)
	f._keyLevelFS = NewFS(f)
	f._timerDetailFS = NewFS(f)

	f._barHost = NewBarHost(f)
	f._barBg, f._barFill = f._barHost._bg, f._barHost._fill
	f._barTickLayer = CreateFrame("Frame", nil, f._barHost)
	f._barTickLayer:SetAllPoints(f._barHost)
	f._barTickLayer:EnableMouse(false)
	f._barTickLayer:SetFrameLevel(f._barHost:GetFrameLevel() + 2)
	f._seg3 = f._barTickLayer:CreateTexture(nil, "OVERLAY")
	f._seg2 = f._barTickLayer:CreateTexture(nil, "OVERLAY")

	f._threshFS = NewFS(f._emtTextLayer)
	f._threshFS2 = NewFS(f._emtTextLayer)
	f._threshRemFS = NewFS(f._emtTextLayer)
	f._deathFS = NewFS(f)
	f._deathHit = CreateFrame("Frame", nil, f)
	f._deathHit:SetFrameLevel(f:GetFrameLevel() + 5)
	f._deathHit:EnableMouse(true)

	-- Deaths tooltip: one row per player (retail custom tooltip).
	local deathTT = CreateFrame("Frame", nil, UIParent)
	deathTT:SetFrameStrata("TOOLTIP")
	deathTT:Hide()
	local ttBg = deathTT:CreateTexture(nil, "BACKGROUND")
	ttBg:SetAllPoints()
	ttBg:SetTexture(0.067, 0.067, 0.067, 0.90)
	ApplyEdges(deathTT, "_edges", deathTT, deathTT, 1, 1, 1, 1, 0.15, true)
	deathTT._rows = {}
	local TT_PAD, TT_ROW_H, TT_GAP = 8, 14, 3
	f._deathHit:SetScript("OnEnter", function(self)
		local deaths = playerDeaths
		if not next(deaths) and (EMT.renderRun and EMT.renderRun.deaths or 0) > 0 then
			deaths = { [UnitName("player") or "You"] = EMT.renderRun.deaths }
		end
		if not next(deaths) then return end
		local list = {}
		for name, count in pairs(deaths) do
			list[#list + 1] = { name = name, count = count }
		end
		table.sort(list, function(a, b)
			if a.count ~= b.count then return a.count > b.count end
			return a.name < b.name
		end)
		for i = #deathTT._rows + 1, #list do
			local nameFS = deathTT:CreateFontString(nil, "OVERLAY")
			SetFS(nameFS, 10, "")
			nameFS:SetJustifyH("LEFT")
			local countFS = deathTT:CreateFontString(nil, "OVERLAY")
			SetFS(countFS, 10, "")
			countFS:SetJustifyH("RIGHT")
			deathTT._rows[i] = { name = nameFS, count = countFS }
		end
		for i = 1, #deathTT._rows do
			deathTT._rows[i].name:Hide()
			deathTT._rows[i].count:Hide()
		end
		local maxNameW, maxCountW = 0, 0
		for i, entry in ipairs(list) do
			local row = deathTT._rows[i]
			local _, classFile = UnitClass(entry.name)
			local r, g, b = P.ClassColor(classFile)
			local short = entry.name:match("^([^%-]+)") or entry.name
			row.name:SetText(Hex(r, g, b) .. short .. "|r")
			row.name:SetTextColor(1, 1, 1, 0.80)
			row.count:SetText(tostring(entry.count))
			row.count:SetTextColor(1, 1, 1, 0.80)
			maxNameW = max(maxNameW, row.name:GetStringWidth() or 0)
			maxCountW = max(maxCountW, row.count:GetStringWidth() or 0)
		end
		deathTT:SetSize(TT_PAD + maxNameW + 12 + maxCountW + TT_PAD,
			TT_PAD + #list * TT_ROW_H + (#list - 1) * TT_GAP + TT_PAD)
		for i = 1, #list do
			local row = deathTT._rows[i]
			local yOff = -TT_PAD - (i - 1) * (TT_ROW_H + TT_GAP)
			row.name:ClearAllPoints()
			row.name:SetPoint("TOPLEFT", deathTT, "TOPLEFT", TT_PAD, yOff)
			row.count:ClearAllPoints()
			row.count:SetPoint("TOPRIGHT", deathTT, "TOPRIGHT", -TT_PAD, yOff)
			row.name:Show()
			row.count:Show()
		end
		deathTT:ClearAllPoints()
		if (self._align or "LEFT") == "RIGHT" then
			deathTT:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 0, 4)
		else
			deathTT:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 4)
		end
		deathTT:Show()
	end)
	f._deathHit:SetScript("OnLeave", function() deathTT:Hide() end)

	f._enemyFS = NewFS(f._emtTextLayer)
	f._enemyBarHost = NewBarHost(f)
	f._enemyBarBg, f._enemyBarFill = f._enemyBarHost._bg, f._enemyBarHost._fill
	f._previewFS = NewFS(f)

	f:Hide()
	standaloneFrame = f
	EMT.ApplyPosition()
	return f
end
EMT.GetFrame = CreateStandaloneFrame

-------------------------------------------------------------------------------
--  Position (retail: saved as the center offset from UIParent's center)
-------------------------------------------------------------------------------
local function CenterFromSaved(pos)
	if not pos or pos.centerX == nil or pos.centerY == nil then return nil end
	local scale = (root and root.scale) or 1.0
	if scale == 0 then scale = 1.0 end
	return pos.centerX / scale, pos.centerY / scale
end

function EMT.ApplyPosition()
	if not root or not standaloneFrame then return end
	local scale = root.scale or 1.0
	if scale == 0 then scale = 1.0 end
	standaloneFrame:SetScale(scale)
	local sx, sy = CenterFromSaved(root.standalonePos)
	if sx ~= nil then
		standaloneFrame:ClearAllPoints()
		standaloneFrame:SetPoint("CENTER", UIParent, "CENTER", sx, sy)
	end
end

-------------------------------------------------------------------------------
--  Render (retail RenderStandalone, same layout rules)
-------------------------------------------------------------------------------
local R = {}  -- render scratch: keeps the chunk under the local limit

function R.TitleText(p, run, tR, tG, tB, size)
	local medalTex = MedalIcon(MedalFor(run), size)
	if p.showDungeonName == false then
		if medalTex == "" then return nil end
		return medalTex
	end
	local name = run.mapName or "Challenge Mode"
	if medalTex ~= "" then
		return format("%s %s%s|r", medalTex, Hex(tR, tG, tB), name)
	end
	return format("%s%s|r", Hex(tR, tG, tB), name)
end

function EMT.Render()
	if not root or not root.enabled then
		if standaloneFrame then standaloneFrame:Hide() end
		return
	end
	local p = root
	local isPreview = false
	local run = currentRun
	if not run.active and not run.completed then
		if p.showPreview or unlockLayoutActive then
			run = PREVIEW_RUN
			isPreview = true
		else
			if standaloneFrame then standaloneFrame:Hide() end
			return
		end
	end
	EMT.renderRun = run

	local f = CreateStandaloneFrame()
	local PAD = 12
	local ALIGN_PAD = 0
	local TBAR_PAD = 0
	local configuredTimerBarH = p.barHeight or 8
	local expandedH = p.barHeightExpanded or 22
	local timerInBar = p.timerInBar and p.showTimerBar ~= false
	local TBAR_H = timerInBar and max(configuredTimerBarH, expandedH) or configuredTimerBarH
	local ENEMY_BAR_H = p.enemyBarHeight or p.barHeight or 8
	local ROW_GAP = p.rowGap or 6
	local OBJ_GAP = p.objectiveGap or 4

	f:SetWidth(p.frameWidth or 260)
	local alpha = p.standaloneAlpha or 0.85
	f:SetBackdropColor(0.05, 0.04, 0.08, alpha)
	f:SetBackdropBorderColor(0.15, 0.15, 0.15, min(alpha, 0.6))

	local aR, aG, aB = GetAccentColor()
	if p.showAccent then
		f._accent:SetTexture(aR, aG, aB, 0.9)
		f._accent:Show()
	else
		f._accent:Hide()
	end

	local frameW = f:GetWidth()
	local innerW = frameW - PAD * 2
	local y = -PAD

	-- The key level spot (retail "+21 |" left of the clock) shows the medal.
	local keyLevelOnTimer = (p.showKeyLevelOnTimer == true) and (p.showDungeonName == false)

	local function ContentPad(align)
		if align == "LEFT" or align == "RIGHT" then return PAD + ALIGN_PAD end
		return PAD
	end
	local gAlign = (p.alignAllText == "LEFT") and "LEFT" or "RIGHT"

	local function TitleColor()
		if p.titleUseAccent ~= false then return aR, aG, aB end
		if p.titleColor then return p.titleColor.r or 1, p.titleColor.g or 1, p.titleColor.b or 1 end
		return 1, 1, 1
	end

	-- Title (affixes do not exist on 5.4.8).
	local function RenderTitleAffixes()
		local tR, tG, tB = TitleColor()
		local titleMax = p.titleSize or 13
		local titleText = (p.showTitle ~= false and not keyLevelOnTimer) and R.TitleText(p, run, tR, tG, tB, titleMax) or nil
		if titleText then
			f._titleFS:SetJustifyH(gAlign)
			f._titleFS:SetTextColor(1, 1, 1)
			SetFittedText(f._titleFS, titleText, innerW, titleMax, max(8, titleMax - 3))
			f._titleFS:ClearAllPoints()
			f._titleFS:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
			f._titleFS:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, y)
			f._titleFS:Show()
			y = y - (f._titleFS:GetStringHeight() or titleMax) - 2 - ROW_GAP
		else
			f._titleFS:Hide()
		end
		f._affixFS:Hide()
	end

	local titleAffixBelowTimer = (p.titleAffixPosition == "BELOW_TIMER")
	local defaultTitleDeathGap = ROW_GAP + 5
	local defaultSandwichGap = ROW_GAP
	if not titleAffixBelowTimer then
		RenderTitleAffixes()
		y = y - ((p.titleAffixDeathGap or defaultTitleDeathGap) - defaultTitleDeathGap)
	end

	-- Deaths row
	if (run.deaths or 0) > 0 and not p.deathsInTitle and p.showDeaths ~= false then
		local deathAlign = gAlign
		local dPad = ContentPad(deathAlign)
		SetFS(f._deathFS, 12)
		f._deathFS:SetTextColor(GetColor(p.deathTextColor, 0.93, 0.33, 0.33))
		f._deathFS:SetText(run.deaths == 1 and "1 Death" or format("%d Deaths", run.deaths))
		f._deathFS:ClearAllPoints()
		f._deathFS:SetPoint("TOPLEFT", f, "TOPLEFT", dPad, y - 5)
		f._deathFS:SetPoint("TOPRIGHT", f, "TOPRIGHT", -dPad, y - 5)
		f._deathFS:SetJustifyH(deathAlign)
		f._deathFS:Show()
		f._deathHit:ClearAllPoints()
		f._deathHit:SetSize(f._deathFS:GetStringWidth() or 0, f._deathFS:GetStringHeight() or 12)
		if deathAlign == "RIGHT" then
			f._deathHit:SetPoint("TOPRIGHT", f._deathFS, "TOPRIGHT", 0, 0)
		else
			f._deathHit:SetPoint("TOPLEFT", f._deathFS, "TOPLEFT", 0, 0)
		end
		f._deathHit._align = deathAlign
		f._deathHit:Show()
		y = y - (f._deathFS:GetStringHeight() or 12) - ROW_GAP - 5
	else
		f._deathFS:Hide()
		f._deathHit:Hide()
		if titleAffixBelowTimer and not p.deathsInTitle then
			y = y - 12 - ROW_GAP - 5
		end
	end

	local elapsed = run.elapsed or 0
	local maxTime = run.maxTime or 0
	local timeLeft = max(0, maxTime - elapsed)
	local plusTwoT, plusThreeT = run.plusTwoT or (maxTime * 0.8), run.plusThreeT or (maxTime * 0.6)
	local completedElapsed = run.preciseCompletedElapsed or elapsed
	local colorElapsed = run.completed and completedElapsed or elapsed
	local timerBarR, timerBarG, timerBarB
	if p.timerBarStyle == "SEGMENTS" then
		timerBarR, timerBarG, timerBarB = GetTimerSegmentFillColor(p, colorElapsed, plusThreeT, plusTwoT)
	else
		timerBarR, timerBarG, timerBarB = GetTimerBarFillColor(p, colorElapsed, plusThreeT, plusTwoT, maxTime)
	end

	local timerText, timerDetailText
	local mode = p.timerDisplayMode or "REMAINING_TOTAL"
	if run.completed then
		local elaStr = FormatTime(run.elapsed or completedElapsed or 0)
		local maxStr = FormatTime(maxTime)
		if mode == "REMAINING_TOTAL" then
			timerText = elaStr .. " / " .. maxStr
		elseif mode == "ELAPSED_DETAIL" then
			timerText = elaStr
			timerDetailText = " (" .. elaStr .. " / " .. maxStr .. ")"
		else
			timerText = elaStr
		end
	else
		local elaStr = FormatTime(elapsed)
		local maxStr = FormatTime(maxTime)
		local remStr = FormatRemaining(maxTime - elapsed)
		if mode == "REMAINING_TOTAL" then
			timerText = elaStr .. " / " .. maxStr
		elseif mode == "ELAPSED" then
			timerText = remStr
		elseif mode == "ELAPSED_DETAIL" then
			timerText = remStr
			timerDetailText = " (" .. elaStr .. " / " .. maxStr .. ")"
		else
			timerText = elaStr
		end
	end

	local tR, tG, tB = 1, 1, 1
	local depleted = (run.completed and completedElapsed > maxTime)
		or ((not run.completed) and timeLeft <= 0 and maxTime > 0)
	if depleted then
		tR, tG, tB = GetColor(p.timerExpiredColor, 0.9, 0.2, 0.2)
	end

	local underBarMode = (p.enemyForcesPos == "UNDER_BAR")
	local barWForThresh = min(p.barWidth or 210, innerW - TBAR_PAD * 2)
	if barWForThresh < 60 then barWForThresh = 60 end

	-- Threshold texts: Gold (+3), Silver (+2), Bronze/remaining (+1).
	local function RenderThresholdText()
		if p.showTimerBar == false and p.showEnemyBar == false then
			f._threshFS:Hide(); f._threshFS2:Hide(); f._threshRemFS:Hide()
			return
		end
		local showRem = p.showThreshRemaining == true
		if not ((p.showPlusTwoTimer or p.showPlusThreeTimer or showRem) and maxTime > 0) then
			f._threshFS:Hide(); f._threshFS2:Hide(); f._threshRemFS:Hide()
			return
		end
		local plusThreeSize = p.thresholdPlusThreeSize or p.thresholdSize or 12
		local plusTwoSize = p.thresholdPlusTwoSize or p.thresholdSize or 12
		local plusOneSize = p.thresholdPlusOneSize or p.thresholdSize or 12
		local thresholdRowSize = max(
			p.showPlusThreeTimer and plusThreeSize or 0,
			p.showPlusTwoTimer and plusTwoSize or 0,
			showRem and plusOneSize or 0,
			12)
		local function buildLabel(threshTime, color)
			local diff = threshTime - elapsed
			if diff >= 0 then
				local cR, cG, cB = GetColor(color, 0.3, 0.8, 1)
				return format("%s%s|r", Hex(cR, cG, cB), FormatTime(diff))
			end
			return format("|cff999999%s|r", FormatTime(threshTime))
		end
		local segmented = (p.timerBarStyle == "SEGMENTS")
		local segmentGap = segmented and max(0, p.timerBarSegmentGap or 2) or 0
		local plusThreeLabelX = max(0, min(barWForThresh, barWForThresh * (plusThreeT / maxTime) - segmentGap / 2))
		local plusTwoLabelX = max(0, min(barWForThresh, barWForThresh * (plusTwoT / maxTime) - segmentGap / 2))
		local anchorBar = f._barHost
		if underBarMode and p.showTimerBar == false and p.showEnemyBar ~= false then
			anchorBar = f._enemyBarHost
		end
		local function placeAt(fs, cx, rightJustified, offsetX, offsetY)
			local offX = offsetX
			local offY = offsetY
			if offX == nil then offX = p.thresholdTextOffsetX or 0 end
			if offY == nil then offY = p.thresholdTextOffsetY or 0 end
			local aboveBar = underBarMode or segmented
			local point
			if rightJustified then
				point = aboveBar and "BOTTOMRIGHT" or "TOPRIGHT"
			else
				point = aboveBar and "BOTTOM" or "TOP"
			end
			fs:SetJustifyH(rightJustified and "RIGHT" or "LEFT")
			fs:ClearAllPoints()
			if aboveBar then
				fs:SetPoint(point, anchorBar, "TOPLEFT", cx + offX, 2 + offY)
			else
				fs:SetPoint(point, anchorBar, "BOTTOMLEFT", cx + offX, -2 + offY)
			end
		end
		local threshW3, threshW2, threshWr = 0, 0, 0
		if p.showPlusThreeTimer then
			SetFS(f._threshFS, plusThreeSize)
			f._threshFS:SetTextColor(1, 1, 1)
			local c1r, c1g, c1b = GetTimerSegmentTextColor(p, 1)
			threshW3 = SetThreshText(f._threshFS, buildLabel(plusThreeT, { r = c1r, g = c1g, b = c1b }))
		end
		if p.showPlusTwoTimer then
			SetFS(f._threshFS2, plusTwoSize)
			f._threshFS2:SetTextColor(1, 1, 1)
			local c2r, c2g, c2b = GetTimerSegmentTextColor(p, 2)
			threshW2 = SetThreshText(f._threshFS2, buildLabel(plusTwoT, { r = c2r, g = c2g, b = c2b }))
		end
		if showRem then
			SetFS(f._threshRemFS, plusOneSize)
			if segmented then
				f._threshRemFS:SetTextColor(GetTimerSegmentTextColor(p, 3))
			elseif p.thresholdPlusOneTextWhite == true then
				f._threshRemFS:SetTextColor(1, 1, 1)
			else
				f._threshRemFS:SetTextColor(tR, tG, tB)
			end
			threshWr = SetThreshText(f._threshRemFS, FormatRemaining(maxTime - elapsed))
		end
		if not showRem then
			if p.showPlusThreeTimer then
				placeAt(f._threshFS, segmented and plusThreeLabelX or (barWForThresh * (plusThreeT / maxTime)), segmented, p.thresholdPlusThreeTextOffsetX, p.thresholdPlusThreeTextOffsetY)
				f._threshFS:Show()
			else
				f._threshFS:Hide()
			end
			if p.showPlusTwoTimer then
				placeAt(f._threshFS2, segmented and plusTwoLabelX or (barWForThresh * (plusTwoT / maxTime)), segmented, p.thresholdPlusTwoTextOffsetX, p.thresholdPlusTwoTextOffsetY)
				f._threshFS2:Show()
			else
				f._threshFS2:Hide()
			end
			f._threshRemFS:Hide()
		elseif segmented then
			if p.showPlusThreeTimer then
				placeAt(f._threshFS, plusThreeLabelX, true, p.thresholdPlusThreeTextOffsetX, p.thresholdPlusThreeTextOffsetY)
				f._threshFS:Show()
			else
				f._threshFS:Hide()
			end
			if p.showPlusTwoTimer then
				placeAt(f._threshFS2, plusTwoLabelX, true, p.thresholdPlusTwoTextOffsetX, p.thresholdPlusTwoTextOffsetY)
				f._threshFS2:Show()
			else
				f._threshFS2:Hide()
			end
			placeAt(f._threshRemFS, barWForThresh, true, p.thresholdPlusOneTextOffsetX, p.thresholdPlusOneTextOffsetY)
			f._threshRemFS:Show()
		else
			-- Ticks with the remaining time: pack right to left so they never overlap.
			local barW = barWForThresh
			local entries = {}
			if p.showPlusThreeTimer then
				entries[#entries + 1] = { fs = f._threshFS, w = threshW3, center = barW * (plusThreeT / maxTime),
					ox = p.thresholdPlusThreeTextOffsetX, oy = p.thresholdPlusThreeTextOffsetY }
			else
				f._threshFS:Hide()
			end
			if p.showPlusTwoTimer then
				entries[#entries + 1] = { fs = f._threshFS2, w = threshW2, center = barW * (plusTwoT / maxTime),
					ox = p.thresholdPlusTwoTextOffsetX, oy = p.thresholdPlusTwoTextOffsetY }
			else
				f._threshFS2:Hide()
			end
			entries[#entries + 1] = { fs = f._threshRemFS, w = threshWr, center = barW - threshWr / 2, pinRight = true,
				ox = p.thresholdPlusOneTextOffsetX, oy = p.thresholdPlusOneTextOffsetY }
			local limit
			for i = #entries, 1, -1 do
				local e = entries[i]
				local half = e.w / 2
				if (not e.pinRight) and limit then
					if e.center + half > limit then e.center = limit - half end
				end
				if e.center - half < 0 then e.center = half end
				limit = e.center - half
			end
			for _, e in ipairs(entries) do
				local rightJustified = e.pinRight
				local anchorX = rightJustified and (e.center + e.w / 2) or e.center
				placeAt(e.fs, anchorX, rightJustified, e.ox, e.oy)
				e.fs:Show()
			end
		end
		y = y - thresholdRowSize - ROW_GAP
	end

	-- Enemy forces (a counted criteria)
	local function HideEnemy()
		f._enemyFS:Hide()
		f._enemyBarHost:Hide()
		if f._enemyBarText then f._enemyBarText:Hide() end
	end
	local function RenderEnemyForces()
		if p.showEnemyBar == false then HideEnemy() return end
		local enemyObj = run._weightedObj
		if not enemyObj then
			for _, obj in ipairs(run.objectives) do
				if obj.isWeighted then enemyObj = obj; break end
			end
		end
		if not enemyObj then HideEnemy() return end

		local objAlign = gAlign
		local ePad = ContentPad(objAlign)
		local pctRaw = min(100, max(0, enemyObj.quantity))
		local pctPos = p.enemyForcesPctPos or "LABEL"
		local showEnemyText = p.showEnemyText ~= false
		local enemyTextFormat = p.enemyForcesTextFormat or "PERCENT"
		local hideLabel = p.hideEnemyForcesLabel == true
		local label
		if pctPos == "LABEL" then
			label = FormatEnemyForcesText(enemyObj, enemyTextFormat, hideLabel)
		elseif hideLabel then
			label = ""
		else
			label = "Enemy Forces"
		end
		local enemyTextSize = p.enemyForcesTextSize or p.objectivesSize or 12
		SetFS(f._enemyFS, enemyTextSize)
		if enemyObj.completed then
			f._enemyFS:SetTextColor(GetColor(p.objectiveCompletedColor, 0.3, 0.8, 0.3))
		else
			f._enemyFS:SetTextColor(GetColor(p.objectiveTextColor, 0.9, 0.9, 0.9))
		end
		f._enemyFS:SetText(label)
		if hideLabel and pctPos ~= "LABEL" then f._enemyFS:Hide() else f._enemyFS:Show() end

		local function RenderEnemyBar()
			local besideRoom = (not enemyObj.completed and pctPos == "BESIDE") and 62 or 0
			local barW = min(p.barWidth or 210, innerW - TBAR_PAD * 2) - besideRoom
			if barW < 60 then barW = 60 end
			local host = f._enemyBarHost
			host:ClearAllPoints()
			if objAlign == "RIGHT" then
				host:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(PAD + TBAR_PAD), y)
			else
				host:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + TBAR_PAD, y)
			end
			host:SetSize(barW, ENEMY_BAR_H)
			host:Show()
			ApplyBarTexture(f._enemyBarBg, p.enemyBarBgTexture, 0.12, 0.12, 0.12, 0.9)
			local eR, eG, eB
			if enemyObj.completed then
				eR, eG, eB = GetColor(p.objectiveCompletedColor, 0.3, 0.8, 0.3)
			elseif p.enemyBarUseAccent ~= false then
				eR, eG, eB = GetAccentColor()
			else
				eR, eG, eB = GetColor(p.enemyBarColor, 0.35, 0.55, 0.8)
			end
			local epct = enemyObj.completed and 1 or min(1, max(0, pctRaw / 100))
			f._enemyBarFill:ClearAllPoints()
			f._enemyBarFill:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
			f._enemyBarFill:SetSize(max(1, barW * epct), ENEMY_BAR_H)
			ApplyBarTexture(f._enemyBarFill, p.enemyBarTexture, eR, eG, eB, 0.8)
			f._enemyBarFill:Show()

			if not f._enemyBarText then
				f._enemyBarText = NewFS(f._emtTextLayer)
			end
			if pctPos == "BAR" or pctPos == "BESIDE" then
				SetFS(f._enemyBarText, enemyTextSize)
				if pctPos == "BAR" then
					f._enemyBarText:SetTextColor(1, 1, 1)
				elseif enemyObj.completed then
					f._enemyBarText:SetTextColor(GetColor(p.objectiveCompletedColor, 0.3, 0.8, 0.3))
				else
					f._enemyBarText:SetTextColor(GetColor(p.objectiveTextColor, 0.9, 0.9, 0.9))
				end
				f._enemyBarText:SetText(FormatEnemyForcesText(enemyObj, enemyTextFormat, true))
				f._enemyBarText:ClearAllPoints()
				if pctPos == "BAR" then
					f._enemyBarText:SetPoint("CENTER", host, "CENTER", 0, 0)
				elseif objAlign == "RIGHT" then
					f._enemyBarText:SetPoint("RIGHT", host, "LEFT", -4, 0)
				else
					f._enemyBarText:SetPoint("LEFT", host, "RIGHT", 4, 0)
				end
				f._enemyBarText:Show()
			else
				f._enemyBarText:Hide()
			end
			y = y - ENEMY_BAR_H - ROW_GAP
		end

		local function RenderEnemyLabel()
			if not showEnemyText then
				f._enemyFS:Hide()
				return
			end
			local labelX = p.enemyForcesTextOffsetX or 0
			local labelY = (underBarMode and (y + 2) or y) + (p.enemyForcesTextOffsetY or 0)
			f._enemyFS:ClearAllPoints()
			f._enemyFS:SetPoint("TOPLEFT", f, "TOPLEFT", ePad + labelX, labelY)
			f._enemyFS:SetPoint("TOPRIGHT", f, "TOPRIGHT", -ePad + labelX, labelY)
			f._enemyFS:SetJustifyH(objAlign)
			f._enemyFS:Show()
			local trailingGap = underBarMode and (4 - 2 + 5) or 4
			y = y - (f._enemyFS:GetStringHeight() or 12) - trailingGap
		end

		if underBarMode then
			RenderEnemyBar()
			RenderEnemyLabel()
		else
			RenderEnemyLabel()
			RenderEnemyBar()
		end
	end

	-- Timer clock
	if not timerInBar then
		local timerAlign = gAlign
		local timerSz = p.timerTextSize or 20
		SetTimerFS(f._timerFS, timerSz)
		f._timerFS:SetTextColor(tR, tG, tB)
		f._timerFS:SetJustifyH(timerAlign == "RIGHT" and "RIGHT" or "LEFT")
		f._timerFS:ClearAllPoints()
		-- Width pinned on a widest-digit template so the clock does not jitter.
		local fPath, _, fFlags = f._timerFS:GetFont()
		local mainKey = #(timerText or "") .. "|" .. timerSz .. "|" .. format("%.3f", f:GetEffectiveScale() or 1)
			.. "|" .. (fPath or "") .. "|" .. (fFlags or "")
		if f._timerFS._lastLen ~= mainKey then
			f._timerFS._lastLen = mainKey
			local templ = (timerText or ""):gsub("%d", WidestDigitChar(f._timerFS))
			f._timerFS:SetText(templ)
			f._timerFS._lastText = templ
			f._timerFS:SetWidth(0)
			f._timerFS:SetWidth((f._timerFS:GetStringWidth() or 0) + 3)
		end
		SetTextDiff(f._timerFS, timerText)

		local keyExtra, keySpacing = 0, 0
		local medalText = keyLevelOnTimer and MedalIcon(MedalFor(run), timerSz) or ""
		local showMedal = medalText ~= ""
		if showMedal then
			SetTimerFS(f._keyLevelFS, timerSz)
			f._keyLevelFS:SetTextColor(TitleColor())
			f._keyLevelFS:SetJustifyH("LEFT")
			f._keyLevelFS:SetWidth(0)
			SetTextDiff(f._keyLevelFS, medalText .. "  ||")
			keySpacing = p.keyLevelTimerSpacing or 8
			keyExtra = (f._keyLevelFS:GetStringWidth() or 0) + keySpacing
		end

		if timerDetailText then
			local detailSize = (not run.completed and mode == "REMAINING_TOTAL") and 20 or 12
			SetTimerFS(f._timerDetailFS, detailSize)
			f._timerDetailFS:SetTextColor(1, 1, 1)
			f._timerDetailFS:SetText(timerDetailText)
			f._timerDetailFS:SetJustifyH(timerAlign == "RIGHT" and "RIGHT" or "LEFT")
			f._timerDetailFS:ClearAllPoints()
			local detPath, _, detFlags = f._timerDetailFS:GetFont()
			local detKey = #timerDetailText .. "|" .. detailSize .. "|" .. format("%.3f", f:GetEffectiveScale() or 1)
				.. "|" .. (detPath or "") .. "|" .. (detFlags or "")
			if f._timerDetailFS._lastKey ~= detKey then
				f._timerDetailFS._lastKey = detKey
				local templ = timerDetailText:gsub("%d", WidestDigitChar(f._timerDetailFS))
				f._timerDetailFS:SetText(templ)
				f._timerDetailFS:SetWidth(0)
				f._timerDetailFS:SetWidth((f._timerDetailFS:GetStringWidth() or 0) + 3)
				f._timerDetailFS:SetText(timerDetailText)
			end
			local gap = 4
			if timerAlign == "RIGHT" then
				f._timerFS:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(PAD + ALIGN_PAD), y)
				f._timerDetailFS:SetPoint("BOTTOMRIGHT", f._timerFS, "BOTTOMLEFT", -gap, 4)
			else
				f._timerFS:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + ALIGN_PAD + keyExtra, y)
				f._timerDetailFS:SetPoint("BOTTOMLEFT", f._timerFS, "BOTTOMRIGHT", gap, 4)
			end
			f._timerDetailFS:Show()
			if showMedal then
				local leftmost = (timerAlign == "RIGHT") and f._timerDetailFS or f._timerFS
				f._keyLevelFS:ClearAllPoints()
				f._keyLevelFS:SetPoint("BOTTOMRIGHT", leftmost, "BOTTOMLEFT", -keySpacing, 0)
				f._keyLevelFS:Show()
			else
				f._keyLevelFS:Hide()
			end
		else
			if timerAlign == "RIGHT" then
				f._timerFS:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(PAD + ALIGN_PAD), y)
			else
				f._timerFS:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + ALIGN_PAD + keyExtra, y)
			end
			f._timerDetailFS:Hide()
			if showMedal then
				f._keyLevelFS:ClearAllPoints()
				f._keyLevelFS:SetPoint("BOTTOMRIGHT", f._timerFS, "BOTTOMLEFT", -keySpacing, 0)
				f._keyLevelFS:Show()
			else
				f._keyLevelFS:Hide()
			end
		end
		f._timerFS:Show()
		local timerH = f._timerFS:GetStringHeight() or 20
		if timerH < 20 then timerH = 20 end
		y = y - timerH - ROW_GAP
	else
		f._timerFS:Hide()
		f._timerDetailFS:Hide()
		f._keyLevelFS:Hide()
	end

	if titleAffixBelowTimer then
		local timerGap = p.titleAffixTimerGap or p.titleAffixSandwichGap or defaultSandwichGap
		local barGap = p.titleAffixBarGap or p.titleAffixSandwichGap or defaultSandwichGap
		if timerInBar then
			y = y - timerGap
		else
			y = y - (timerGap - defaultSandwichGap)
		end
		RenderTitleAffixes()
		y = y - (barGap - defaultSandwichGap)
	end

	if underBarMode or p.timerBarStyle == "SEGMENTS" then
		RenderThresholdText()
	end

	-- Timer bar
	local function HideTimerSegments()
		if f._timerSegHosts then
			for _, host in ipairs(f._timerSegHosts) do host:Hide() end
		end
	end
	if maxTime > 0 and p.showTimerBar ~= false then
		local barW = min(p.barWidth or 210, innerW - TBAR_PAD * 2)
		if barW < 60 then barW = 60 end
		local barHost = f._barHost
		barHost:ClearAllPoints()
		if gAlign == "RIGHT" then
			barHost:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(PAD + TBAR_PAD), y)
		else
			barHost:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + TBAR_PAD, y)
		end
		barHost:SetSize(barW, TBAR_H)
		barHost:Show()
		ApplyBarTexture(f._barBg, p.barBgTexture, 0.12, 0.12, 0.12, 0.9)
		f._barBg:SetAlpha(1)
		f._barBg:Show()
		local fillPct = min(1, elapsed / maxTime)
		f._barFill:ClearAllPoints()
		f._barFill:SetPoint("TOPLEFT", barHost, "TOPLEFT", 0, 0)
		f._barFill:SetSize(max(1, barW * fillPct), TBAR_H)
		local fillA = timerInBar and (p.barFillAlphaExpanded or 0.85) or 0.85
		ApplyBarTexture(f._barFill, p.barTexture, timerBarR, timerBarG, timerBarB, fillA)
		f._barFill:Show()

		local PP = ns.PP
		local es = f:GetEffectiveScale()
		local function snap(v) return (PP and PP.SnapForES) and PP.SnapForES(v, es) or v end
		local tickW = snap(2)
		if tickW <= 0 then tickW = 2 end

		local barStyle = p.timerBarStyle or "TICKS"
		if barStyle == "SEGMENTS" then
			f._timerSegHosts = f._timerSegHosts or {}
			for i = 1, 3 do
				if not f._timerSegHosts[i] then f._timerSegHosts[i] = NewBarHost(f) end
			end
			f._barBg:SetAlpha(0)
			f._barFill:Hide()
			f._seg3:Hide()
			f._seg2:Hide()
			local gapW = snap(max(0, p.timerBarSegmentGap or 2))
			local b3 = snap(barW * (plusThreeT / maxTime))
			local b2 = snap(barW * (plusTwoT / maxTime))
			local g3L = snap(b3 - gapW / 2); local g3R = g3L + gapW
			local g2L = snap(b2 - gapW / 2); local g2R = g2L + gapW
			local segs = {
				{ x1 = 0,   x2 = g3L,  t1 = 0,          t2 = plusThreeT },
				{ x1 = g3R, x2 = g2L,  t1 = plusThreeT, t2 = plusTwoT },
				{ x1 = g2R, x2 = barW, t1 = plusTwoT,   t2 = maxTime },
			}
			for i, seg in ipairs(segs) do
				local x1 = max(0, min(barW, seg.x1))
				local x2v = max(0, min(barW, seg.x2))
				local w = x2v - x1
				if w < 1 then w = 1 end
				local host = f._timerSegHosts[i]
				host:ClearAllPoints()
				host:SetPoint("TOPLEFT", barHost, "TOPLEFT", x1, 0)
				host:SetSize(w, TBAR_H)
				host:SetFrameLevel(barHost:GetFrameLevel() + 1)
				host:Show()
				ApplyBarTexture(host._bg, p.barBgTexture, 0.12, 0.12, 0.12, 0.9)
				local segDur = max(1, seg.t2 - seg.t1)
				local segPct = min(1, max(0, (elapsed - seg.t1) / segDur))
				host._fill:ClearAllPoints()
				host._fill:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
				host._fill:SetSize(max(1, w * segPct), TBAR_H)
				ApplyBarTexture(host._fill, p.barTexture, timerBarR, timerBarG, timerBarB, fillA)
				if segPct > 0 then host._fill:Show() else host._fill:Hide() end
			end
		else
			HideTimerSegments()
			local tickA = p.tickAlpha or 1
			local whiteTicks = p.tickWhite == true
			local tickR, tickG, tickB = GetColor(p.timerTickColor, 1, 1, 1)
			f._barTickLayer:SetFrameLevel(barHost:GetFrameLevel() + 2)
			f._seg3:ClearAllPoints()
			f._seg3:SetSize(tickW, TBAR_H)
			f._seg3:SetPoint("TOPLEFT", barHost, "TOPLEFT", snap(barW * (plusThreeT / maxTime)) - tickW / 2, 0)
			if p.timerTickColor or whiteTicks or elapsed > plusThreeT then
				f._seg3:SetTexture(tickR, tickG, tickB, tickA)
			else
				f._seg3:SetTexture(0.4, 1, 0.4, tickA)
			end
			f._seg3:Show()
			f._seg2:ClearAllPoints()
			f._seg2:SetSize(tickW, TBAR_H)
			f._seg2:SetPoint("TOPLEFT", barHost, "TOPLEFT", snap(barW * (plusTwoT / maxTime)) - tickW / 2, 0)
			if p.timerTickColor or whiteTicks or elapsed > plusTwoT then
				f._seg2:SetTexture(tickR, tickG, tickB, tickA)
			else
				f._seg2:SetTexture(0.3, 0.8, 1, tickA)
			end
			f._seg2:Show()
		end

		if timerInBar then
			if not f._barTimerFS then
				f._barTimerFS = NewFS(f._emtTextLayer)
			end
			SetTimerFS(f._barTimerFS, 12)
			local btc = p.timerBarTextColor
			if btc then
				f._barTimerFS:SetTextColor(btc.r or 1, btc.g or 1, btc.b or 1)
			else
				f._barTimerFS:SetTextColor(tR, tG, tB)
			end
			local barTimerText = timerText
			if timerDetailText then barTimerText = timerText .. timerDetailText end
			if keyLevelOnTimer then
				local medalText = MedalIcon(MedalFor(run), 12)
				if medalText ~= "" then barTimerText = medalText .. "  ||  " .. barTimerText end
			end
			SetTextDiff(f._barTimerFS, barTimerText)
			f._barTimerFS:ClearAllPoints()
			if p.timerInBarLeftText then
				f._barTimerFS:SetPoint("LEFT", barHost, "LEFT", 5, 0)
			else
				f._barTimerFS:SetPoint("CENTER", barHost, "CENTER", 0, 0)
			end
			f._barTimerFS:Show()
		elseif f._barTimerFS then
			f._barTimerFS:Hide()
		end
		y = y - TBAR_H - ROW_GAP - 2
	else
		f._barHost:Hide()
		f._seg3:Hide(); f._seg2:Hide()
		HideTimerSegments()
		if f._barTimerFS then f._barTimerFS:Hide() end
	end

	if underBarMode then
		RenderEnemyForces()
	end
	if not (underBarMode or p.timerBarStyle == "SEGMENTS") then
		RenderThresholdText()
	end

	-- Boss objectives
	local objIdx = 0
	if p.showObjectives then
		local objAlign = gAlign
		local oPad = ContentPad(objAlign)
		for i, obj in ipairs(run.objectives) do
			if not obj.isWeighted then
				objIdx = objIdx + 1
				local entry = GetObjRow(f, objIdx)
				local nameFS, timeFS = entry.name, entry.time
				local objSize = p.objectivesSize or 12
				SetFS(nameFS, objSize)
				SetFS(timeFS, objSize)
				local displayName = obj.name or ("Objective " .. i)
				if obj.completed then
					nameFS:SetTextColor(GetColor(p.objectiveCompletedColor, 0.3, 0.8, 0.3))
				else
					nameFS:SetTextColor(GetColor(p.objectiveTextColor, 0.9, 0.9, 0.9))
				end
				local timeStr = ""
				if p.showObjectiveTimes ~= false and obj.completed and obj.elapsed and obj.elapsed > 0 then
					local cR, cG, cB = GetColor(p.objectiveCompletedColor, 0.3, 0.8, 0.3)
					timeStr = format("%s%s|r", Hex(cR, cG, cB), FormatTime(obj.elapsed))
				end
				local compareMode = p.objectiveCompareMode or COMPARE_NONE
				local compareSuffix = ""
				if obj.completed then
					local reference = obj.referenceElapsed
					if isPreview then
						reference = (compareMode ~= COMPARE_NONE) and obj.previewSplit or nil
					end
					if reference then
						compareSuffix = BuildSplitCompareText(reference, obj.elapsed, p.objectiveCompareDeltaOnly, p.splitFasterColor, p.splitSlowerColor)
					end
				elseif p.showUpcomingSplitTargets and compareMode ~= COMPARE_NONE then
					local target
					if isPreview then
						target = obj.previewSplit
					else
						target = GetReferenceObjectiveTime(run, i, compareMode)
					end
					compareSuffix = BuildSplitCompareText(target)
				end
				local splitText = timeStr
				if splitText ~= "" and compareSuffix ~= "" then
					splitText = splitText .. compareSuffix
				elseif compareSuffix ~= "" then
					splitText = compareSuffix:gsub("^%s+", "")
				end
				local oInnerW = frameW - oPad * 2
				local timeOnLeft = (p.objectiveTimePosition == "LEFT")
				local splitGap = 4
				local objTextX = p.objectiveTextOffsetX or 0
				local objY = y + (p.objectiveTextOffsetY or 0)
				nameFS:ClearAllPoints()
				timeFS:ClearAllPoints()
				nameFS:SetText(displayName)
				if splitText ~= "" then
					timeFS:SetText(splitText)
					timeFS:SetTextColor(1, 1, 1, 1)
					timeFS:SetWidth(0)
					local timeW = timeFS:GetStringWidth() or 0
					local nameMaxW = oInnerW - timeW - splitGap
					if nameMaxW < 20 then nameMaxW = 20 end
					nameFS:SetWidth(0)
					local nameW = nameFS:GetStringWidth() or 0
					if nameW > nameMaxW then nameW = nameMaxW end
					if nameW < 20 then nameW = 20 end
					nameFS:SetWidth(nameW)
					if timeOnLeft then
						if objAlign == "RIGHT" then
							nameFS:SetPoint("TOPRIGHT", f, "TOPRIGHT", -oPad + objTextX, objY)
							timeFS:SetPoint("TOPRIGHT", nameFS, "TOPLEFT", -splitGap, 0)
						else
							timeFS:SetPoint("TOPLEFT", f, "TOPLEFT", oPad + objTextX, objY)
							nameFS:SetPoint("TOPLEFT", timeFS, "TOPRIGHT", splitGap, 0)
						end
					else
						if objAlign == "RIGHT" then
							timeFS:SetPoint("TOPRIGHT", f, "TOPRIGHT", -oPad + objTextX, objY)
							nameFS:SetPoint("TOPRIGHT", timeFS, "TOPLEFT", -splitGap, 0)
						else
							nameFS:SetPoint("TOPLEFT", f, "TOPLEFT", oPad + objTextX, objY)
							timeFS:SetPoint("TOPLEFT", nameFS, "TOPRIGHT", splitGap, 0)
						end
					end
					timeFS:Show()
				else
					timeFS:Hide()
					if objAlign == "RIGHT" then
						nameFS:SetPoint("TOPRIGHT", f, "TOPRIGHT", -oPad + objTextX, objY)
					else
						nameFS:SetPoint("TOPLEFT", f, "TOPLEFT", oPad + objTextX, objY)
					end
					nameFS:SetWidth(oInnerW)
				end
				nameFS:SetJustifyH(objAlign)
				nameFS:Show()
				y = y - (nameFS:GetStringHeight() or 12) - OBJ_GAP
			end
		end
	end
	for i = objIdx + 1, #objRows do
		local e = objRows[i]
		if e then e.name:Hide(); e.time:Hide() end
	end

	if not underBarMode then
		if objIdx > 0 then y = y - 5 end
		RenderEnemyForces()
	end

	f:SetHeight(abs(y) + PAD)

	if isPreview and p.showPreview then
		SetFS(f._previewFS, 8)
		f._previewFS:SetTextColor(0.5, 0.5, 0.5, 0.6)
		f._previewFS:SetText("PREVIEW")
		f._previewFS:ClearAllPoints()
		f._previewFS:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, 4)
		f._previewFS:Show()
	else
		f._previewFS:Hide()
	end

	EMT.ApplyBorder()
	f:Show()
end

-- Full rebuild (retail _EMT_RebuildStandalone): new FontStrings next render.
function EMT.Rebuild()
	if standaloneFrame then
		for _, e in ipairs(objRows) do e.name:Hide(); e.time:Hide() end
		standaloneFrame._timerFS._lastLen = nil
		standaloneFrame._timerFS._lastText = nil
		standaloneFrame._keyLevelFS._lastText = nil
	end
	EMT.Render()
end

function EMT.Apply()
	EMT.Render()
	EMT.ApplyPosition()
	ApplyTrackerVisibility()
end

-- Preview toggle (retail "Show Preview").
function EMT.SetPreview(on)
	if not root then return end
	root.showPreview = on and true or false
	EMT.Render()
	EMT.ApplyPosition()
end

-- Reset to defaults (the settings footer button).
function EMT.Reset()
	if not root then return end
	for k in pairs(root) do
		if k ~= "_seeded" then root[k] = nil end
	end
	FillDefaults(root, DEFAULTS)
	EMT.Rebuild()
	EMT.ApplyPosition()
	if P.TSB_Refresh then P.TSB_Refresh() end
	if P.TFB_Refresh then P.TFB_Refresh() end
	if P.RS_Apply then P.RS_Apply() end
end

-------------------------------------------------------------------------------
--  Runtime events
-------------------------------------------------------------------------------
local function HandleRuntimeEvent(event)
	if not root or not root.enabled then
		if currentRun.active or currentRun.completed then ResetRun() end
		return
	end
	if InChallengeMode() then
		if not currentRun.active and not currentRun.completed then
			StartRun()
			-- A reload after the last boss: the run is already over.
			if currentRun.active and IsDungeonComplete() then CompleteRun() end
		end
		if event == "CHALLENGE_MODE_COMPLETED" and currentRun.completed then
			-- Completed on the last criteria already: take the server's time.
			EMT.ApplyCompletionInfo()
			NotifyRefresh()
			if P.RS_RunCompleted then P.RS_RunCompleted(currentRun, true) end
		end
		if currentRun.active then
			if event == "CHALLENGE_MODE_COMPLETED" then
				CompleteRun()
			elseif event == "SCENARIO_CRITERIA_UPDATE" or event == "SCENARIO_UPDATE" then
				UpdateObjectives()
				if IsDungeonComplete() then CompleteRun() end
				NotifyRefresh()
			elseif event == "WORLD_STATE_TIMER_START" then
				-- A new attempt after a Challenge Mode reset: start over.
				if (currentRun.elapsed or 0) > 5 then
					ResetRun()
					StartRun()
				end
				currentRun.timerID = FindChallengeTimer()
				lastTickedSec = -1
				OnTimerTick()
			elseif event == "WORLD_STATE_TIMER_STOP" then
				if IsDungeonComplete() then CompleteRun() end
			end
		end
	elseif currentRun.active or currentRun.completed then
		if currentRun.active and IsDungeonComplete() then
			CompleteRun()
		end
		ResetRun()
	end
end
EMT.HandleRuntimeEvent = HandleRuntimeEvent

local runtimeFrame = CreateFrame("Frame")
local RUNTIME_EVENTS = {
	"PLAYER_ENTERING_WORLD", "CHALLENGE_MODE_COMPLETED", "WORLD_STATE_TIMER_START",
	"WORLD_STATE_TIMER_STOP", "SCENARIO_CRITERIA_UPDATE", "SCENARIO_UPDATE", "ZONE_CHANGED_NEW_AREA",
}
runtimeFrame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_ENTERING_WORLD" then
		EMT.ApplyPosition()
		Timer.After(3, function() HandleRuntimeEvent("PLAYER_ENTERING_WORLD_DELAYED") end)
	end
	HandleRuntimeEvent(event)
end)

-------------------------------------------------------------------------------
--  Unlock Mode (retail keys)
-------------------------------------------------------------------------------
local function RegisterUnlock()
	if not (ns.RegisterUnlockElements and ns.MakeUnlockElement) then return end
	if ns.RegisterUnlockModeListener then
		ns:RegisterUnlockModeListener("EMT_MythicTimer", function(active)
			unlockLayoutActive = active == true
			if unlockLayoutActive then
				EMT.Render()
			elseif not root.showPreview and not currentRun.active and not currentRun.completed then
				if standaloneFrame then standaloneFrame:Hide() end
			else
				EMT.Render()
			end
			local anchored = ns.IsUnlockAnchored and ns.IsUnlockAnchored("EMT_MythicTimer")
			if not anchored then EMT.ApplyPosition() end
		end)
	end
	ns:RegisterUnlockElements({
		ns.MakeUnlockElement({
			key   = "EMT_MythicTimer",
			label = "Challenge Timer",
			group = "Challenge Mode",
			order = 520,
			noResize = true,
			isHidden = function() return not (root and root.enabled) end,
			getFrame = function() return CreateStandaloneFrame() end,
			getSize  = function()
				local f = standaloneFrame
				if f then return f:GetWidth(), f:GetHeight() end
				return 260, 200
			end,
			savePos = function(_, point, relPoint, x, y)
				local f = standaloneFrame
				local cur = root.standalonePos
				local isRestore = cur and x ~= nil and cur.centerX == x and cur.centerY == y
				if not isRestore and f and f:GetCenter() then
					local cx, cy = f:GetCenter()
					local upX, upY = UIParent:GetCenter()
					local ratio = (f:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
					root.standalonePos = { centerX = cx * ratio - upX, centerY = cy * ratio - upY }
				end
				if f and not ns._unlockActive then
					local sx, sy = CenterFromSaved(root.standalonePos)
					if sx ~= nil then
						f:ClearAllPoints()
						f:SetPoint("CENTER", UIParent, "CENTER", sx, sy)
					end
				end
			end,
			loadPos = function()
				local pos = root.standalonePos
				if not (pos and pos.centerX and pos.centerY) then return nil end
				return { point = "CENTER", relPoint = "CENTER", x = pos.centerX, y = pos.centerY }
			end,
			clearPos = function() root.standalonePos = nil end,
			applyPos = function() if standaloneFrame then EMT.ApplyPosition() end end,
		}),
	}, addonName)
end

-------------------------------------------------------------------------------
--  Settings changes (the settings window runs ns.applyHooks)
-------------------------------------------------------------------------------
ns.applyHooks = ns.applyHooks or {}
tinsert(ns.applyHooks, function()
	if not root then return end
	EMT.Apply()
	if P.TSB_Refresh then P.TSB_Refresh() end
	if P.TFB_Refresh then P.TFB_Refresh() end
	if P.RS_Apply then P.RS_Apply() end
end)

-------------------------------------------------------------------------------
--  Boot
-------------------------------------------------------------------------------
local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= addonName then return end
		self:UnregisterEvent("ADDON_LOADED")
		root = ns.ModuleDB("EllesmereUIChallengeTimerDB")
		if root._seeded ~= 1 then Seed(root) end
		FillDefaults(root, DEFAULTS)
		root.showPreview = false
		db = { profile = root }
		RegisterUnlock()
		return
	end
	self:UnregisterEvent("PLAYER_LOGIN")
	for _, ev in ipairs(RUNTIME_EVENTS) do runtimeFrame:RegisterEvent(ev) end
	P.RefreshKick()
	if P.TSB_OnEnable then P.TSB_OnEnable(db) end
	if P.TFB_OnEnable then P.TFB_OnEnable(db) end
	if P.RS_OnEnable then P.RS_OnEnable(db) end
	HandleRuntimeEvent("PLAYER_LOGIN")
end)
