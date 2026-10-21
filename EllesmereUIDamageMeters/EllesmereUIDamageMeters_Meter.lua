-- Damage Meters (EllesmereUI "EllesmereUIDamageMeters" meter windows, made for 5.4.8).
-- Retail reads Blizzard's built-in meter (C_DamageMeter, 12.x). 5.4.8 has no
-- such meter, so the numbers come from EllesmereUI's own combat log engine
-- (EllesmereUIDamageMeters_Engine.lua, ns.EDMEngine).
-- Look, saved keys (EllesmereUIDamageMetersDB.dm) and settings follow retail.

local addonName = ...
local ns = EllesmereUI

local DM = {}
ns.EDM = DM

local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local format, tinsert, tremove, tsort = format, table.insert, table.remove, table.sort
-- (ipairs / pairs / type stay globals: CreateDMWindow is near Lua 5.1's 60-upvalue limit.)

local MEDIA = "Interface\\AddOns\\EllesmereUIDamageMeters\\Media\\"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local ARROW_ICON = "Interface\\AddOns\\EllesmereUI\\media\\icons\\eui-arrow"
local FRIENDS_CLASS = "Interface\\AddOns\\EllesmereUI\\media\\class\\"
local BAR_POOL_SIZE = 40
local MIN_W, MIN_H = 150, 50
local MAX_WINDOWS = 5
local ICON_ALPHA, ICON_HOVER_ALPHA = 0.4, 0.9
local REFRESH_FLOOR = 0.5
DM.MAX_WINDOWS = MAX_WINDOWS

local RANK_STRINGS = {}
for i = 1, BAR_POOL_SIZE do RANK_STRINGS[i] = i .. "." end

---------------------------------------------------------------------------
-- Meter types and sessions. Numbers are retail's Enum.DamageMeterType /
-- Enum.DamageMeterSessionType values, so saved settings (curDMType,
-- bookmarks, curSession) carry over unchanged.
---------------------------------------------------------------------------
local T = {
	DamageDone = 0, HealingDone = 2, Interrupts = 5, Dispels = 6, DamageTaken = 7,
	AvoidableDamageTaken = 8, Deaths = 9, EnemyDamageTaken = 10,
}
local S = { Overall = 0, Current = 1 }
DM.T, DM.S = T, S

-- Types the 5.4.8 engine records. Avoidable Damage Taken has no counterpart:
-- not offered (a saved bookmark of it stays saved, like retail does for types
-- a client does not offer).
local TYPE_NAMES = {
	[T.DamageDone] = "Damage Done",
	[T.HealingDone] = "Healing Done",
	[T.DamageTaken] = "Damage Taken",
	[T.EnemyDamageTaken] = "Enemy Damage Taken",
	[T.Interrupts] = "Interrupts",
	[T.Dispels] = "Dispels",
	[T.Deaths] = "Deaths",
}
local TYPE_ICONS = {
	[T.DamageDone] = MEDIA .. "dm_home_damage",
	[T.HealingDone] = MEDIA .. "dm_home_healing",
	[T.DamageTaken] = MEDIA .. "dm_home_taken",
	[T.AvoidableDamageTaken] = MEDIA .. "dm_home_avoidable",
	[T.EnemyDamageTaken] = MEDIA .. "dm_home_enemytaken",
	[T.Interrupts] = MEDIA .. "dm_home_interrupt",
	[T.Dispels] = MEDIA .. "dm_home_dispel",
	[T.Deaths] = MEDIA .. "dm_home_deaths",
}
local HOME_DEFAULTS = { T.DamageDone, T.HealingDone, T.Interrupts, T.Deaths }
DM.TYPE_NAMES, DM.TYPE_ICONS = TYPE_NAMES, TYPE_ICONS

---------------------------------------------------------------------------
-- Settings (retail DM_DEFAULTS, profile.dm)
---------------------------------------------------------------------------
local function C3(r, g, b) return { r = r, g = g, b = b } end
local function C4(r, g, b, a) return { r = r, g = g, b = b, a = a } end

local function CreateDefaults()
	return {
		visibility = "always",
		barTexture = "atrocity",
		fontSize = 11,
		barHeight = 18,
		barSpacing = 2,
		numberFormat = 2,
		iconStyle = "spec",
		classIconZoom = 0.06,
		iconColorUseAccent = false,
		iconColor = C3(1, 1, 1),
		customIconBorder = false,
		iconBorderSize = 0,
		iconBorderR = 0, iconBorderG = 0, iconBorderB = 0, iconBorderA = 1,
		showClassColor = true,
		showPinnedSelf = false,
		showHoverTooltip = true,
		showSpellTooltips = true,
		showAllBreakdownSpells = true,
		breakdownAnchorPoint = "row",
		breakdownBarTexture = "match",
		hoverTooltipScale = 100,
		barColorUseAccent = true,
		barColor = C3(0.35, 0.55, 0.8),
		barFillAlpha = 1,
		leftFontSize = 11,
		leftTextUseClassColor = false,
		leftTextColor = C3(1, 1, 1),
		rightFontSize = 11,
		rightTextUseClassColor = false,
		rightTextColor = C3(1, 1, 1),
		leftTextOffsetX = 0, leftTextOffsetY = 0,
		rightTextOffsetX = 0, rightTextOffsetY = 0,
		hideNumbers = false,
		bgR = 0, bgG = 0, bgB = 0, bgAlpha = 0.75,
		windowBorderSize = 0,
		windowBorderColor = C4(0, 0, 0, 1),
		windowBorderIncludeHeader = true,
		windowBorderBehind = false,
		barBgR = 0, barBgG = 0, barBgB = 0, barBgAlpha = 0,
		barBgUseClassColor = false,
		standaloneTimer = false,
		standaloneTimerSize = 26,
		standaloneTimerDecimal = false,
		standaloneTimerUseAccent = false,
		standaloneTimerColor = C3(1, 1, 1),
		standaloneTimerAnchor = "free",
		standaloneTimerStrata = "HIGH",
		standaloneTimerShowOOC = false,
		standaloneTimerDesatOOC = false,
		standaloneTimerLocked = false,
		standaloneTimerOutline = "INHERIT",
		standaloneTimerWidth = 70,
		standaloneTimerHeight = 32,
		standaloneTimerBackgroundColor = C4(0, 0, 0, 0),
		standaloneTimerBorderColor = C4(0, 0, 0, 1),
		standaloneTimerBorderSize = 0,
		refreshRate = 1,
		hideResetButton = false,
		toggleIncludeTimer = false,
		toggleIncludeSpellHistory = false,
		hdrBgColor = C3(0x1B / 255, 0x1B / 255, 0x1B / 255),
		hdrBgAlpha = 1,
		hdrBottomBorderSize = 0,
		hdrBottomBorderColor = C4(0, 0, 0, 1),
		hdrHeight = 22,
		hdrFontSize = 11,
		hdrTextOffX = 0, hdrTextOffY = 0,
		hdrIconSize = 22,
		hdrMouseoverIcons = false,
		hdrTextUseAccent = true,
		hdrTextColor = C3(1, 1, 1),
		borderSize = 0,
		borderR = 0, borderG = 0, borderB = 0, borderA = 1,
		windowCount = 1,
		-- 5.4.8 only: combat engine settings (EllesmereUIDamageMeters_Engine.lua).
		segmentsToKeep = 18,
		timeType = "effective", -- "effective" (fight duration) | "activity" (each player's active time)
		overallClearNewBoss = true,
		overallClearNewChallenge = true,
	}
end
DM.CreateDefaults = CreateDefaults

function DM.ApplyModernStyle()
	local c = DM.DB()
	local style = {
		barTexture = "none", breakdownBarTexture = "match",
		barHeight = 20, barSpacing = 1, barFillAlpha = 1, showClassColor = true,
		fontSize = 12, leftFontSize = 12, rightFontSize = 12, numberFormat = 2,
		hideNumbers = false, showPinnedSelf = true, iconStyle = "spec", classIconZoom = 0.08,
		customIconBorder = false, borderSize = 0,
		leftTextUseClassColor = false, rightTextUseClassColor = false,
		leftTextColor = C3(1, 1, 1), rightTextColor = C3(1, 1, 1),
		leftTextOffsetX = 0, leftTextOffsetY = 0, rightTextOffsetX = 0, rightTextOffsetY = 0,
		bgR = 0, bgG = 0, bgB = 0, bgAlpha = 0.5,
		barBgR = 0, barBgG = 0, barBgB = 0, barBgAlpha = 0.35, barBgUseClassColor = false,
		windowBorderSize = 1, windowBorderColor = C4(0, 0, 0, 1),
		windowBorderIncludeHeader = true, windowBorderBehind = false,
		hdrHeight = 22, hdrFontSize = 12, hdrIconSize = 20, hdrMouseoverIcons = true,
		hdrBgColor = C3(0.08, 0.08, 0.08), hdrBgAlpha = 0.95,
		hdrTextUseAccent = false, hdrTextColor = C3(1, 1, 1), hdrTextOffX = 0, hdrTextOffY = 0,
		hdrBottomBorderSize = 0, hoverTooltipScale = 100, breakdownAnchorPoint = "row",
	}
	for key, value in pairs(style) do c[key] = value end
	DM.Apply()
end

-- The user's retail "Naowh" profile values (first login only, marker dm._seeded).
local NAOWH_SEED = {
	hideNumbers = true,
	bookmarks = { 0, 2, 5, 9, 8, 7, 10 },
	barHeight = 25,
	rightFontSize = 14,
	leftFontSize = 14,
	hdrBgAlpha = 0,
	barTexture = "sm:NaowhGradient",
	barSpacing = -1,
	hdrIconSize = 28,
	numberFormat = 3,
	showPinnedSelf = true,
	breakdownAnchorPoint = "left",
	hoverTooltipScale = 120,
	barBgAlpha = 0.7,
	barColorUseAccent = false,
	customIconBorder = true,
	classIconZoom = 0.05,
	hdrFontSize = 15,
	standaloneTimerAlignLeft = false,
	hdrHeight = 23,
	bgAlpha = 0,
	hdrTextUseAccent = false,
	borderSize = 1,
	iconBorderSize = 1,
	hdrMouseoverIcons = true,
	windowCount = 3,
	hdrBgColor = { r = 0, g = 0, b = 0 },
	windows = {
		{ curSession = 0, curDMType = 2, mythicStartDMType = 2, hideInDelve = false, hideInPvP = false,
			width = 300, autoCurrentOnCombat = true, hideTimer = false, autoSwapMythic = true,
			hideOutOfInstance = false, height = 96, hideInRaid = false, locked = true,
			position = { y = 101, relPoint = "BOTTOMLEFT", point = "TOPLEFT", x = 2260 } },
		{ curSession = 0, curDMType = 0, mythicStartDMType = 8, width = 300, autoSwapMythic = false,
			position = { y = 415, x = 2260 }, locked = true, autoCurrentOnCombat = false,
			hideTimer = true, height = 144 },
		{ curSession = 0, curDMType = 0, mythicStartDMType = 0, hideInDelve = false, hideInPvP = false,
			width = 300, autoCurrentOnCombat = true, hideTimer = true, autoSwapMythic = true,
			position = { y = 258, x = 2260 }, locked = true, hideOutOfInstance = false,
			hideInRaid = false, height = 144 },
	},
}

local function DeepCopy(v)
	if type(v) ~= "table" then return v end
	local t = {}
	for k, x in pairs(v) do t[k] = DeepCopy(x) end
	return t
end
DM.DeepCopy = DeepCopy

local function CopyDefaults(src, dst)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			CopyDefaults(v, dst[k])
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

local root, dm
local function DB()
	if not dm then
		root = ns.ModuleDB("EllesmereUIDamageMetersDB")
		if type(root.dm) ~= "table" then root.dm = {} end
		dm = root.dm
		if dm._seeded ~= 1 then
			for k, v in pairs(NAOWH_SEED) do
				if dm[k] == nil then dm[k] = DeepCopy(v) end
			end
			dm._seeded = 1
		end
		CopyDefaults(CreateDefaults(), dm)
	end
	return dm
end
DM.DB = DB

local function WinDB(idx)
	local c = DB()
	if type(c.windows) ~= "table" then c.windows = {} end
	if type(c.windows[idx]) ~= "table" then
		c.windows[idx] = { width = 375, height = 150 }
	end
	return c.windows[idx]
end
DM.WinDB = WinDB

local function GetBookmarks()
	local c = DB()
	if type(c.bookmarks) ~= "table" then
		c.bookmarks = {}
		for _, t in ipairs(HOME_DEFAULTS) do c.bookmarks[#c.bookmarks + 1] = t end
	end
	return c.bookmarks
end
DM.GetBookmarks = GetBookmarks

---------------------------------------------------------------------------
-- Small helpers: timers (no C_Timer on 5.4.8), fonts, colors, textures
---------------------------------------------------------------------------
local timers = {}
local timerFrame = CreateFrame("Frame")
timerFrame:Hide()
timerFrame:SetScript("OnUpdate", function(self)
	local now = GetTime()
	local i = 1
	while i <= #timers do
		local t = timers[i]
		if now >= t.at then
			tremove(timers, i)
			local ok, err = pcall(t.fn)
			if not ok then geterrorhandler()(err) end
		else
			i = i + 1
		end
	end
	if #timers == 0 then self:Hide() end
end)
local function After(delay, fn)
	timers[#timers + 1] = { at = GetTime() + (delay or 0), fn = fn }
	timerFrame:Show()
end
DM.After = After

local function SetDMFont(fs, size, flags)
	ns.ApplyModuleFont(fs, size or 11, "damageMeters", flags)
end
DM.SetFont = SetDMFont

local function Accent()
	if ns.GetAccentColor then return ns.GetAccentColor() end
	if ns.ResolveAccent then return ns.ResolveAccent() end
	return 12 / 255, 210 / 255, 157 / 255
end
DM.Accent = Accent

-- Player classes of 5.4.8.
local CLASSES = {
	WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true, DEATHKNIGHT = true,
	SHAMAN = true, MAGE = true, WARLOCK = true, MONK = true, DRUID = true,
}
local function ClassColor(token)
	if not token or not CLASSES[token] then return nil end
	local c = ns.GetClassColor and ns.GetClassColor(token)
	if not c and RAID_CLASS_COLORS then c = RAID_CLASS_COLORS[token] end
	if c and c.r then return c.r, c.g, c.b end
	return nil
end
DM.ClassColor = ClassColor

local function Solid(tex, r, g, b, a)
	tex:SetTexture(r or 0, g or 0, b or 0, a or 1)
end

local function RGB(t, dr, dg, db)
	if type(t) ~= "table" then return dr, dg, db end
	return t.r or t[1] or dr, t.g or t[2] or dg, t.b or t[3] or db
end
DM.RGB = RGB

-- Bar textures: retail keys ("none" = flat, a retail EllesmereUI texture key,
-- "blizzard" = the game's bar, "sm:<name>" = a LibSharedMedia status bar).
DM.BAR_TEXTURE_ORDER = {
	"none", "blizzard", "melli", "atrocity", "fade", "fade-right", "thin-line-top", "thin-line-bottom",
	"beautiful", "plating", "divide", "glass", "gradient-lr", "gradient-rl", "gradient-bt", "gradient-tb",
	"matte", "sheer", "pixels-fill", "pixels-dark", "pixels-bg", "blinkii-diamonds", "kringel-window",
}
DM.BAR_TEXTURE_NAMES = {
	none = "None", blizzard = "Blizzard", melli = "Melli (ElvUI)", beautiful = "Beautiful", plating = "Plating",
	atrocity = "Atrocity", divide = "Divide", glass = "Glass", ["fade-right"] = "Fade Right",
	["thin-line-top"] = "Thin Line Top", ["thin-line-bottom"] = "Thin Line Bottom", fade = "Fade",
	["gradient-lr"] = "Gradient Right", ["gradient-rl"] = "Gradient Left", ["gradient-bt"] = "Gradient Up",
	["gradient-tb"] = "Gradient Down", matte = "Matte", sheer = "Sheer", ["pixels-fill"] = "Pixels Fill",
	["pixels-dark"] = "Pixels Dark", ["pixels-bg"] = "Pixels Background", ["blinkii-diamonds"] = "Blinkii Diamonds",
	["kringel-window"] = "Kringel Window",
}

local function LSM()
	return ns.GetLSM and ns.GetLSM() or nil
end

function DM.TexturePath(key)
	if not key or key == "none" or key == "" then return WHITE end
	if key == "blizzard" then return "Interface\\TargetingFrame\\UI-StatusBar" end
	if type(key) == "string" and key:sub(1, 3) == "sm:" then
		local lsm = LSM()
		return lsm and lsm:Fetch("statusbar", key:sub(4), true) or "Interface\\TargetingFrame\\UI-StatusBar"
	end
	if DM.BAR_TEXTURE_NAMES[key] then return MEDIA .. "textures\\" .. key end
	return WHITE
end

function DM.TextureLabel(key)
	if type(key) == "string" and key:sub(1, 3) == "sm:" then return key:sub(4) end
	return DM.BAR_TEXTURE_NAMES[key or "none"] or "None"
end

function DM.TextureItems(withMatch)
	local items = {}
	if withMatch then items[#items + 1] = { name = "Match Damage Meters", value = "match" } end
	for _, key in ipairs(DM.BAR_TEXTURE_ORDER) do
		items[#items + 1] = { name = DM.BAR_TEXTURE_NAMES[key], value = key }
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

-- Icon styles (retail ICON_STYLE_VALUES). Sprite sheets are the EllesmereUI
-- class-full sheets (shared in EllesmereUI\media\class on 5.4.8).
DM.ICON_STYLE_ORDER = { "none", "spec", "blizzard", "modern", "pixel", "pixelsComic", "glyph", "arcade", "legend", "midnight", "runic" }
DM.ICON_STYLE_NAMES = {
	none = "None", spec = "Default Spec Icons", blizzard = "Blizzard", modern = "Modern", pixel = "Pixel",
	pixelsComic = "Pixels Comic", glyph = "Glyph", arcade = "Arcade", legend = "Legend", midnight = "Midnight", runic = "Runic",
}
local SPRITE = {
	WARRIOR = { 0, 0.125, 0, 0.125 }, MAGE = { 0.125, 0.25, 0, 0.125 }, ROGUE = { 0.25, 0.375, 0, 0.125 },
	DRUID = { 0.375, 0.5, 0, 0.125 }, HUNTER = { 0, 0.125, 0.125, 0.25 }, SHAMAN = { 0.125, 0.25, 0.125, 0.25 },
	PRIEST = { 0.25, 0.375, 0.125, 0.25 }, WARLOCK = { 0.375, 0.5, 0.125, 0.25 }, PALADIN = { 0, 0.125, 0.25, 0.375 },
	DEATHKNIGHT = { 0.125, 0.25, 0.25, 0.375 }, MONK = { 0.25, 0.375, 0.25, 0.375 },
}
local BLIZZ_CLASS_TEX = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local BLIZZ_COORDS = {
	WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.49609375, 0, 0.25 },
	ROGUE = { 0.49609375, 0.7421875, 0, 0.25 }, DRUID = { 0.7421875, 0.98828125, 0, 0.25 },
	HUNTER = { 0, 0.25, 0.25, 0.5 }, SHAMAN = { 0.25, 0.49609375, 0.25, 0.5 },
	PRIEST = { 0.49609375, 0.7421875, 0.25, 0.5 }, WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 },
	PALADIN = { 0, 0.25, 0.5, 0.75 }, DEATHKNIGHT = { 0.25, 0.49609375, 0.5, 0.75 },
	MONK = { 0.49609375, 0.7421875, 0.5, 0.75 },
}

local function ZoomCoords(c, z)
	local du, dv = (c[2] - c[1]) * z, (c[4] - c[3]) * z
	return c[1] + du, c[2] - du, c[3] + dv, c[4] - dv
end

-- Paints a class / spec icon. Returns the width it takes (0 = hidden).
local function ResolveIcon(src, tex, barH)
	local c = DB()
	local style = c.iconStyle or "spec"
	local zoom = c.classIconZoom or 0.06
	local cls = src and src.class
	if style == "none" or not cls or not BLIZZ_COORDS[cls] then
		tex:Hide()
		return 0
	end
	if style == "spec" or style == "blizzard" then
		local specIcon = nil
		if style == "spec" and src.spec and GetSpecializationInfoByID then
			local _, _, _, icon = GetSpecializationInfoByID(src.spec)
			specIcon = icon
		end
		if specIcon then
			tex:SetTexture(specIcon)
			tex:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
		else
			tex:SetTexture(BLIZZ_CLASS_TEX)
			tex:SetTexCoord(ZoomCoords(BLIZZ_COORDS[cls], zoom))
		end
	else
		local coords = SPRITE[cls]
		tex:SetTexture(FRIENDS_CLASS .. style)
		tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
	end
	tex:SetSize(barH, barH)
	tex:SetVertexColor(1, 1, 1, 1)
	tex:Show()
	return barH
end
DM.ResolveIcon = ResolveIcon

-- Number format (retail AbbreviateNumbers breakpoints: B and M two decimals,
-- K one decimal, cut not rounded).
local function Abbrev(n)
	n = tonumber(n) or 0
	local a = abs(n)
	local function Cut(v, sigDiv, fracDiv, suffix)
		local s = floor(v / sigDiv) / fracDiv
		return tostring(s) .. suffix
	end
	if a >= 1e9 then return Cut(n, 1e7, 100, "B") end
	if a >= 1e6 then return Cut(n, 1e4, 100, "M") end
	if a >= 1e3 then return Cut(n, 100, 10, "K") end
	return tostring(floor(n))
end
DM.Abbrev = Abbrev

local function FormatBarValue(amt, perSec, fmt)
	if fmt == 0 then return Abbrev(perSec) end
	if fmt == 2 and perSec then return format("%s (%s)", Abbrev(amt), Abbrev(perSec)) end
	if fmt == 3 and perSec then return format("%s | %s", Abbrev(amt), Abbrev(perSec)) end
	return Abbrev(amt)
end
DM.FormatBarValue = FormatBarValue

local function FormatTimer(sec)
	sec = floor(sec or 0)
	return format("%d:%02d", floor(sec / 60), sec % 60)
end
DM.FormatTimer = FormatTimer

-- Name without realm ("Name-Realm" -> "Name").
local function ShortName(name)
	if type(name) ~= "string" then return "Unknown" end
	return (name:gsub("%-.*$", ""))
end

---------------------------------------------------------------------------
-- Engine adapter (EllesmereUIDamageMeters_Engine.lua). Each retail meter type
-- reads one actor field of a fight:
--   Damage Done        -> group actors, actor.damage  (breakdown: dmgSpells)
--   Healing Done       -> group actors, actor.healing (breakdown: healSpells)
--   Damage Taken       -> group actors, actor.taken   (breakdown: takenFrom)
--   Enemy Damage Taken -> enemy actors, actor.taken   (breakdown: takenFrom)
--   Interrupts         -> group actors, actor.interrupts (intSpells)
--   Dispels            -> group actors, actor.dispels (dispSpells)
--   Deaths             -> fight.deaths (death recaps)
---------------------------------------------------------------------------
local function Engine()
	return ns.EDMEngine
end
DM.Engine = Engine

-- The fight a window shows: a past segment, Current or Overall.
local function GetCombat(W)
	local e = Engine()
	if W.curSessionID then return W.curSessionID end
	if W.curSession == S.Overall then return e.GetOverall() end
	return e.GetCurrent()
end
DM.GetCombat = GetCombat

local function CombatTime(combat)
	return combat and Engine().Duration(combat) or 0
end
DM.CombatTime = CombatTime

local ACTIVE_FIELD = { [T.DamageDone] = "dmgActive", [T.HealingDone] = "healActive" }
local AMOUNT_FIELD = {
	[T.DamageDone] = "damage", [T.HealingDone] = "healing", [T.DamageTaken] = "taken",
	[T.EnemyDamageTaken] = "taken", [T.Interrupts] = "interrupts", [T.Dispels] = "dispels",
}

-- Returns a sorted list of rows: { name, class, spec, total, perSec, isLocalPlayer, actor, death }.
local function GetSources(combat, dmType)
	local out = {}
	if not combat then return out, 0 end
	local me = UnitGUID("player")
	local dur = CombatTime(combat)
	if dmType == T.Deaths then
		for i = 1, #combat.deaths do
			local t = combat.deaths[i]
			out[#out + 1] = {
				name = t.name, class = t.class, total = 1, isLocalPlayer = t.name == UnitName("player"),
				death = t, deathTime = t.time,
			}
		end
		return out, dur
	end
	local field = AMOUNT_FIELD[dmType]
	if not field then return out, dur end
	local enemies = dmType == T.EnemyDamageTaken
	local activity = ACTIVE_FIELD[dmType] and DB().timeType == "activity"
	for _, a in pairs(combat.actors) do
		local amount = a[field]
		if amount and amount >= 1 and ((enemies and a.enemy) or (not enemies and a.group)) then
			amount = floor(amount)
			local seconds = dur
			if activity then seconds = max(1, a[ACTIVE_FIELD[dmType]] or 0) end
			out[#out + 1] = {
				name = a.name, class = a.class, spec = a.spec, total = amount,
				perSec = seconds > 0 and amount / seconds or nil, isLocalPlayer = a.guid == me, actor = a,
			}
		end
	end
	tsort(out, function(a, b)
		if a.total == b.total then return a.name < b.name end
		return a.total > b.total
	end)
	return out, dur
end
DM.GetSources = GetSources

local function SpellName(id)
	if id == 1 then return "Melee", "Interface\\Icons\\INV_Sword_04" end
	if type(id) ~= "number" or id <= 0 then
		return tostring(id or "?"), "Interface\\Icons\\INV_Misc_QuestionMark"
	end
	local name, _, icon = GetSpellInfo(id)
	return name or tostring(id), icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end
DM.SpellName = SpellName

local SPELL_LIST = {
	[T.DamageDone] = "dmgSpells", [T.HealingDone] = "healSpells",
	[T.Interrupts] = "intSpells", [T.Dispels] = "dispSpells",
}

-- Breakdown of one row: { label, icon, amount, spellID, class }, sorted.
local function GetBreakdown(combat, dmType, src)
	local out = {}
	if not combat or not src then return out end
	local actor = src.actor
	if SPELL_LIST[dmType] then
		local list = actor and actor[SPELL_LIST[dmType]]
		if type(list) == "table" then
			for _, s in pairs(list) do
				if s.amount >= 1 then
					local name, icon = SpellName(s.id)
					if s.pet then name = name .. " (" .. ShortName(s.pet) .. ")" end
					out[#out + 1] = { label = name, icon = icon, amount = floor(s.amount), spellID = s.id }
				end
			end
		end
	elseif dmType == T.DamageTaken or dmType == T.EnemyDamageTaken then
		if actor and type(actor.takenFrom) == "table" then
			for _, t in pairs(actor.takenFrom) do
				if t.amount >= 1 then
					out[#out + 1] = { label = ShortName(t.name), amount = floor(t.amount), class = t.class }
				end
			end
		end
	elseif dmType == T.Deaths then
		-- Death recap (last events before the death, newest first).
		local t = src.death
		local events = t and t.events
		if type(events) == "table" then
			for i = #events, 1, -1 do
				local ev = events[i]
				local name, icon = SpellName(ev.id)
				out[#out + 1] = {
					label = name, icon = icon, amount = floor(ev.amount), spellID = ev.id,
					heal = ev.heal, source = ev.source, ago = ev.at - t.at,
				}
			end
		end
		return out
	end
	tsort(out, function(a, b) return a.amount > b.amount end)
	return out
end
DM.GetBreakdown = GetBreakdown

-- Stored segments for the segment menu, newest first:
-- { combat, name, time, boss, try, result, bossHP }.
function DM.GetSegments()
	local out = {}
	local segs = Engine().GetSegments()
	for i = 1, #segs do
		local c = segs[i]
		out[#out + 1] = {
			combat = c, name = c.name or "Combat", time = CombatTime(c),
			boss = c.boss, try = c.try, result = c.result, bossHP = c.bossHP,
		}
	end
	return out
end

-- Segment menu label (Details style): "Boss #3  Wipe 34%" / "Boss #4  Kill".
local KILL_COLOR, WIPE_COLOR = "|cff5fd35f", "|cffff5f5f"
function DM.SegmentLabel(s)
	local text = s.name
	if not s.boss then return text end
	if s.try then text = text .. " #" .. s.try end
	if s.result == "kill" then
		text = text .. "  " .. KILL_COLOR .. "Kill|r"
	elseif s.result == "wipe" then
		local hp = s.bossHP and (" " .. floor(s.bossHP + 0.5) .. "%") or ""
		text = text .. "  " .. WIPE_COLOR .. "Wipe" .. hp .. "|r"
	end
	return text
end

function DM.InCombat()
	if Engine().InCombat() then return true end
	return InCombatLockdown() or UnitAffectingCombat("player") and true or false
end

-- Segment menu items of a window: past fights (oldest first), Current, Overall.
function DM.SegmentMenuItems(W)
	local items = {}
	local segs = DM.GetSegments()
	local function entry(s)
		return {
			text = DM.SegmentLabel(s), timerText = FormatTimer(s.time), compact = true,
			isActive = W.curSessionID == s.combat,
			onClick = function() DM.ApplySegmentSelection(W, nil, s.combat) end,
		}
	end
	-- Oldest first; two or more trash fights in a row fold into a Trash submenu.
	local i = #segs
	while i >= 1 do
		local j = i
		while j > 1 and not segs[i].boss and not segs[j - 1].boss do j = j - 1 end
		if segs[i].boss or i == j then
			items[#items + 1] = entry(segs[i])
		else
			local group = { text = "Trash (" .. (i - j + 1) .. ")", compact = true, children = {} }
			for k = i, j, -1 do
				local e = entry(segs[k])
				group.children[#group.children + 1] = e
				if e.isActive then group.isActive = true end
			end
			items[#items + 1] = group
		end
		i = j - 1
	end
	items[#items + 1] = "---"
	items[#items + 1] = { text = "Current", isActive = not W.curSessionID and W.curSession == S.Current,
		onClick = function() DM.ApplySegmentSelection(W, S.Current, nil) end }
	items[#items + 1] = { text = "Overall", isActive = not W.curSessionID and W.curSession == S.Overall,
		onClick = function() DM.ApplySegmentSelection(W, S.Overall, nil) end }
	return items
end

---------------------------------------------------------------------------
-- Popup menu (retail ShowEDMMenu): dark list, active item in accent, one
-- level of submenus, "---" separators, optional timer text on the right.
---------------------------------------------------------------------------
local CTX_ITEM_H, CTX_SEP_H, CTX_MIN_W, CTX_FONT_SZ = 22, 7, 100, 11
local menus = {}
local menuCatcher

local function HideMenus()
	for _, m in ipairs(menus) do m:Hide() end
	if menuCatcher then menuCatcher:Hide() end
end
DM.HideMenus = HideMenus

local function MakeMenuPanel(level)
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetFrameStrata("FULLSCREEN_DIALOG")
	f:SetFrameLevel(20 + level * 5)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	Solid(bg, 0.067, 0.067, 0.067, 0.95)
	local edges = {}
	for i = 1, 4 do
		edges[i] = f:CreateTexture(nil, "BORDER")
		Solid(edges[i], 1, 1, 1, 0.18)
	end
	edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT"); edges[1]:SetHeight(1)
	edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT"); edges[2]:SetHeight(1)
	edges[3]:SetPoint("TOPLEFT"); edges[3]:SetPoint("BOTTOMLEFT"); edges[3]:SetWidth(1)
	edges[4]:SetPoint("TOPRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT"); edges[4]:SetWidth(1)
	f.pool = {}
	f:Hide()
	f:RegisterEvent("PLAYER_REGEN_DISABLED")
	f:SetScript("OnEvent", function(self) self:Hide() end)
	return f
end

local function MenuRow(menu, idx)
	local row = menu.pool[idx]
	if row then return row end
	row = CreateFrame("Button", nil, menu)
	row:RegisterForClicks("AnyUp")
	row.hl = row:CreateTexture(nil, "BACKGROUND")
	row.hl:SetAllPoints()
	row.lbl = row:CreateFontString(nil, "OVERLAY")
	SetDMFont(row.lbl, CTX_FONT_SZ)
	row.lbl:SetPoint("LEFT", row, "LEFT", 8, 0)
	row.lbl:SetJustifyH("LEFT")
	row.timer = row:CreateFontString(nil, "OVERLAY")
	SetDMFont(row.timer, CTX_FONT_SZ)
	row.timer:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	row.timer:SetJustifyH("RIGHT")
	row.arrow = row:CreateTexture(nil, "ARTWORK")
	row.arrow:SetTexture(ARROW_ICON)
	row.arrow:SetSize(14, 14)
	row.arrow:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	row.arrow:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1) -- the down arrow turned to point right (retail SetRotation(pi / 2))
	row.arrow:SetVertexColor(1, 1, 1, 0.75)
	row.sep = row:CreateTexture(nil, "ARTWORK")
	row.sep:SetHeight(1)
	row.sep:SetPoint("LEFT", row, "LEFT", 6, 0)
	row.sep:SetPoint("RIGHT", row, "RIGHT", -6, 0)
	Solid(row.sep, 1, 1, 1, 0.12)
	menu.pool[idx] = row
	return row
end

local LayoutMenu
LayoutMenu = function(level, items, anchor, side)
	local menu = menus[level]
	if not menu then
		menu = MakeMenuPanel(level)
		menus[level] = menu
	end
	for _, r in ipairs(menu.pool) do r:Hide() end
	for l = level + 1, #menus do menus[l]:Hide() end
	if not menu.measure then
		menu.measure = menu:CreateFontString(nil, "OVERLAY")
		SetDMFont(menu.measure, CTX_FONT_SZ)
	end
	local maxW = 0
	for _, item in ipairs(items) do
		if type(item) == "table" and item.text then
			menu.measure:SetText(item.text .. (item.timerText and ("  " .. item.timerText) or ""))
			maxW = max(maxW, menu.measure:GetStringWidth() or 0)
		end
	end
	menu.measure:SetText("")
	local w = max(CTX_MIN_W, maxW + 50)
	local ar, ag, ab = Accent()
	local y = 0
	for idx, item in ipairs(items) do
		local row = MenuRow(menu, idx)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", menu, "TOPLEFT", 0, y)
		row.sep:Hide()
		row.arrow:Hide()
		row.timer:SetText("")
		Solid(row.hl, 1, 1, 1, 0)
		row:SetScript("OnEnter", nil)
		row:SetScript("OnLeave", nil)
		row:SetScript("OnClick", nil)
		if item == "---" then
			row:SetSize(w, CTX_SEP_H)
			row.lbl:SetText("")
			row.sep:Show()
			row:EnableMouse(false)
			y = y - CTX_SEP_H
		else
			local h = item.compact and (CTX_ITEM_H - 2) or CTX_ITEM_H
			row:SetSize(w, h)
			row:EnableMouse(true)
			row.lbl:SetText(item.text or "")
			if item.isActive then
				row.lbl:SetTextColor(ar, ag, ab, 1)
			else
				row.lbl:SetTextColor(1, 1, 1, 0.8)
			end
			if item.timerText then
				row.timer:SetText(item.timerText)
				row.timer:SetTextColor(1, 1, 1, 0.45)
			end
			if item.children then row.arrow:Show() end
			row:SetScript("OnEnter", function(self)
				Solid(self.hl, 1, 1, 1, 0.08)
				if item.children then
					LayoutMenu(level + 1, item.children, self, "RIGHT")
				elseif menus[level + 1] then
					for l = level + 1, #menus do menus[l]:Hide() end
				end
				if item.tooltip and ns.ShowWidgetTooltip then ns.ShowWidgetTooltip(self, item.tooltip) end
			end)
			row:SetScript("OnLeave", function(self)
				Solid(self.hl, 1, 1, 1, 0)
				if ns.HideWidgetTooltip then ns.HideWidgetTooltip() end
			end)
			row:SetScript("OnClick", function()
				if item.children then return end
				if item.keepOpen then
					if item.onClick then item.onClick() end
					return
				end
				HideMenus()
				if ns.HideWidgetTooltip then ns.HideWidgetTooltip() end
				if item.onClick then item.onClick() end
			end)
			row:Show()
			y = y - h
		end
		row:Show()
	end
	menu:SetSize(w, -y)
	menu:ClearAllPoints()
	if side == "RIGHT" then
		menu:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 2, 0)
	elseif anchor then
		local bottom = anchor:GetBottom() or 0
		if bottom - (-y) < 20 then
			menu:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, 2)
		else
			menu:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
		end
	else
		local x, cy = GetCursorPosition()
		local s = UIParent:GetEffectiveScale()
		menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s, cy / s)
	end
	menu:Show()
	return menu
end

local function ShowMenu(items, anchor)
	if not menuCatcher then
		menuCatcher = CreateFrame("Button", nil, UIParent)
		menuCatcher:SetAllPoints(UIParent)
		menuCatcher:SetFrameStrata("FULLSCREEN")
		menuCatcher:RegisterForClicks("AnyUp")
		menuCatcher:SetScript("OnClick", HideMenus)
	end
	menuCatcher:Show()
	LayoutMenu(1, items, anchor)
end
DM.ShowMenu = ShowMenu

---------------------------------------------------------------------------
-- State shared by the windows
---------------------------------------------------------------------------
local windows = {}
DM.windows = windows
local previewOn = false      -- the settings page is open: windows always shown
local unlockOn = false       -- Unlock Mode is open
local toggleHidden = false   -- the Show/Hide Windows keybind (not saved, like retail)
local loaded = false

-- Pixel size (retail PhysicalPixels): user values are physical pixels.
local function Px(v)
	local mult = ns.PP and ns.PP.mult or 1
	return (v or 0) * mult
end

local function HeaderH()
	return DB().hdrHeight or 22
end

-- 4 edge textures on a frame (solid border; 5.4.8 draws a solid border only).
local function MakeEdges(frame, layer)
	local e = {}
	for i = 1, 4 do e[i] = frame:CreateTexture(nil, layer or "OVERLAY") end
	return e
end
local function PaintEdges(e, target, size, r, g, b, a)
	if not size or size <= 0 then
		for i = 1, 4 do e[i]:Hide() end
		return
	end
	local s = Px(size)
	for i = 1, 4 do
		e[i]:ClearAllPoints()
		Solid(e[i], r, g, b, a)
		e[i]:Show()
	end
	e[1]:SetPoint("TOPLEFT", target, "TOPLEFT", 0, 0); e[1]:SetPoint("TOPRIGHT", target, "TOPRIGHT", 0, 0); e[1]:SetHeight(s)
	e[2]:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", 0, 0); e[2]:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 0, 0); e[2]:SetHeight(s)
	e[3]:SetPoint("TOPLEFT", target, "TOPLEFT", 0, -s); e[3]:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", 0, s); e[3]:SetWidth(s)
	e[4]:SetPoint("TOPRIGHT", target, "TOPRIGHT", 0, -s); e[4]:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 0, s); e[4]:SetWidth(s)
end
DM.MakeEdges, DM.PaintEdges = MakeEdges, PaintEdges

local function IconColor()
	local c = DB()
	if c.iconColorUseAccent then return Accent() end
	return RGB(c.iconColor, 1, 1, 1)
end

---------------------------------------------------------------------------
-- Hover breakdown (retail "Show Breakdown on Hover"): a small window of
-- bars with the row's spells (or sources), next to the row or the screen.
---------------------------------------------------------------------------
local TT_W, TT_HDR_H, TT_BAR_H = 275, 20, 18
local tt

local function EnsureTooltip()
	if tt then return tt end
	tt = CreateFrame("Frame", "EllesmereUIDMBreakdownTip", UIParent)
	tt:SetFrameStrata("TOOLTIP")
	tt:SetClampedToScreen(true)
	tt:Hide()
	tt.bg = tt:CreateTexture(nil, "BACKGROUND")
	tt.bg:SetAllPoints()
	Solid(tt.bg, 0.05, 0.05, 0.05, 0.92)
	tt.edges = MakeEdges(tt, "BORDER")
	tt.title = tt:CreateFontString(nil, "OVERLAY")
	SetDMFont(tt.title, 12)
	tt.title:SetPoint("TOPLEFT", tt, "TOPLEFT", 6, -4)
	tt.title:SetJustifyH("LEFT")
	tt.sub = tt:CreateFontString(nil, "OVERLAY")
	SetDMFont(tt.sub, 11)
	tt.sub:SetPoint("TOPRIGHT", tt, "TOPRIGHT", -6, -5)
	tt.sub:SetTextColor(1, 1, 1, 0.5)
	tt.bars = {}
	return tt
end

local function TTBar(i)
	local b = tt.bars[i]
	if b then return b end
	b = CreateFrame("StatusBar", nil, tt)
	b:SetMinMaxValues(0, 1)
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints()
	Solid(b.bg, 0, 0, 0, 0.35)
	b.icon = b:CreateTexture(nil, "OVERLAY")
	b.icon:SetPoint("RIGHT", b, "LEFT", 0, 0)
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.name = b:CreateFontString(nil, "OVERLAY")
	b.name:SetPoint("LEFT", b, "LEFT", 4, 0)
	b.name:SetPoint("RIGHT", b, "RIGHT", -90, 0)
	b.name:SetJustifyH("LEFT")
	b.name:SetWordWrap(false)
	b.amount = b:CreateFontString(nil, "OVERLAY")
	b.amount:SetPoint("RIGHT", b, "RIGHT", -4, 0)
	b.amount:SetJustifyH("RIGHT")
	tt.bars[i] = b
	return b
end

local function HideBreakdownTip()
	if tt then tt:Hide() end
end
DM.HideBreakdownTip = HideBreakdownTip

local function ShowBreakdownTip(W, bar)
	local c = DB()
	if c.showHoverTooltip == false or not bar.src then return end
	local combat = GetCombat(W)
	if not combat then return end
	EnsureTooltip()
	local list = GetBreakdown(combat, W.curDMType, bar.src)
	local maxN = c.showAllBreakdownSpells ~= false and 15 or 8
	local n = min(#list, maxN)
	local scale = (c.hoverTooltipScale or 100) / 100
	tt:SetScale(scale)
	tt:SetWidth(TT_W)
	local r, g, b = ClassColor(bar.src.class)
	tt.title:SetText(ShortName(bar.src.name))
	tt.title:SetTextColor(r or 1, g or 1, b or 1, 1)
	tt.sub:SetText(W.curDMType == T.Deaths and "Death Recap" or (TYPE_NAMES[W.curDMType] or ""))
	local texKey = c.breakdownBarTexture
	if not texKey or texKey == "match" then texKey = c.barTexture end
	local tex = DM.TexturePath(texKey)
	local top = list[1] and list[1].amount or 1
	local total = 0
	for i = 1, #list do total = total + list[i].amount end
	local hasIcon = false
	for i = 1, n do if list[i].icon then hasIcon = true break end end
	local inset = hasIcon and (TT_BAR_H + 6) or 6
	for i = 1, n do
		local e = list[i]
		local bb = TTBar(i)
		SetDMFont(bb.name, 11)
		SetDMFont(bb.amount, 11)
		bb:SetStatusBarTexture(tex)
		bb:ClearAllPoints()
		bb:SetPoint("TOPLEFT", tt, "TOPLEFT", inset, -(TT_HDR_H + 4 + (i - 1) * (TT_BAR_H + 1)))
		bb:SetPoint("TOPRIGHT", tt, "TOPRIGHT", -6, -(TT_HDR_H + 4 + (i - 1) * (TT_BAR_H + 1)))
		bb:SetHeight(TT_BAR_H)
		bb:SetMinMaxValues(0, top > 0 and top or 1)
		bb:SetValue(e.amount)
		local cr, cg, cb = ClassColor(e.class)
		if e.heal then
			bb:SetStatusBarColor(0.3, 0.8, 0.3, 0.8)
		elseif cr then
			bb:SetStatusBarColor(cr, cg, cb, 0.8)
		else
			local ar, ag, ab = Accent()
			bb:SetStatusBarColor(ar, ag, ab, 0.8)
		end
		if e.icon then
			bb.icon:SetTexture(e.icon)
			bb.icon:SetSize(TT_BAR_H, TT_BAR_H)
			bb.icon:Show()
		else
			bb.icon:Hide()
		end
		local label = e.label
		if W.curDMType == T.Deaths then
			if e.source then label = label .. " |cff999999(" .. ShortName(e.source) .. ")|r" end
			bb.name:SetText(label)
			local ago = e.ago and format("%.1fs ", e.ago) or ""
			bb.amount:SetText(ago .. (e.heal and "+" or "-") .. Abbrev(e.amount))
		else
			bb.name:SetText(label)
			local pct = total > 0 and (e.amount / total * 100) or 0
			bb.amount:SetText(format("%s (%.1f%%)", Abbrev(e.amount), pct))
		end
		bb:Show()
	end
	for i = n + 1, #tt.bars do tt.bars[i]:Hide() end
	if n == 0 then
		local bb = TTBar(1)
		bb:Hide()
	end
	tt:SetHeight(TT_HDR_H + 8 + max(n, 0) * (TT_BAR_H + 1))
	PaintEdges(tt.edges, tt, 1, 0, 0, 0, 1)
	tt:ClearAllPoints()
	local where = c.breakdownAnchorPoint or "row"
	if where == "center" then
		tt:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	elseif where == "left" then
		tt:SetPoint("TOPRIGHT", W.frame, "TOPLEFT", -4, 0)
	elseif where == "right" then
		tt:SetPoint("TOPLEFT", W.frame, "TOPRIGHT", 4, 0)
	else
		tt:SetPoint("BOTTOMLEFT", bar.row, "TOPLEFT", 0, 4)
	end
	if n == 0 then return end
	tt:Show()
end

---------------------------------------------------------------------------
-- Window visibility (retail Visibility + per-window instance rules)
---------------------------------------------------------------------------
local function GlobalVisible()
	local mode = DB().visibility or "always"
	if mode == "never" then return false end
	if mode == "in_combat" then return DM.InCombat() end
	if mode == "out_of_combat" then return not DM.InCombat() end
	local inRaid, inGroup = IsInRaid(), IsInGroup()
	if mode == "in_raid" then return inRaid end
	if mode == "in_party" then return inGroup and not inRaid end
	if mode == "solo" then return not inGroup end
	return true
end
DM.VISIBILITY = {
	{ key = "always", text = "Always" },
	{ key = "never", text = "Never" },
	{ key = "mouseover", text = "Mouseover" },
	{ key = "in_combat", text = "In Combat" },
	{ key = "out_of_combat", text = "Out of Combat" },
	{ key = "in_raid", text = "In Raid Group" },
	{ key = "in_party", text = "In Party" },
	{ key = "solo", text = "Solo" },
}

local function WindowHiddenByRules(W)
	if previewOn or unlockOn then return false end
	if toggleHidden then return true end
	if not GlobalVisible() then return true end
	local wdb = WinDB(W.idx)
	local _, iType = IsInInstance()
	if wdb.hideInDungeon and iType == "party" then return true end
	if wdb.hideInRaid and iType == "raid" then return true end
	if wdb.hideInPvP and (iType == "pvp" or iType == "arena") then return true end
	if wdb.hideOutOfInstance and (iType == "none" or iType == nil) then return true end
	return false
end

function DM.UpdateVisibility()
	for _, W in ipairs(windows) do
		if WindowHiddenByRules(W) then
			W.frame:Hide()
		else
			W.frame:Show()
		end
	end
	if DM.UpdateTimerFrame then DM.UpdateTimerFrame() end
end

---------------------------------------------------------------------------
-- Window positions (retail ApplyWinPosition): unlock format
-- { point, relPoint, x, y } or legacy { x = left, y = top } from UIParent's
-- BOTTOMLEFT (header drags).
---------------------------------------------------------------------------
local function ApplyWinPosition(frame, wdb, idx)
	frame:ClearAllPoints()
	local pos = wdb.position
	if type(pos) == "table" and pos.point then
		frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
	elseif type(pos) == "table" and pos.x and pos.y then
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos.x, pos.y)
	else
		local uiW = UIParent:GetWidth()
		local fw, fh = frame:GetWidth(), frame:GetHeight()
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", uiW - fw - 20 + (idx - 1) * 20, fh + 20 - (idx - 1) * 20)
	end
end
DM.ApplyWinPosition = ApplyWinPosition

---------------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------------
local function MakeRow(W, parent)
	local bar = {}
	bar.row = CreateFrame("Button", nil, parent)
	bar.row:SetHeight(18)
	bar.row:RegisterForClicks("AnyUp")
	bar.bg = bar.row:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetAllPoints(bar.row)
	bar.fill = CreateFrame("StatusBar", nil, bar.row)
	bar.fill:SetMinMaxValues(0, 1)
	bar.fill:SetValue(0)
	bar.fill:SetStatusBarTexture(WHITE)
	bar.icon = bar.row:CreateTexture(nil, "OVERLAY")
	bar.icon:SetPoint("LEFT", bar.row, "LEFT", 0, 0)
	bar.icon:Hide()
	bar.iconEdges = MakeEdges(bar.row, "OVERLAY")
	local tf = CreateFrame("Frame", nil, bar.row)
	tf:SetAllPoints(bar.fill)
	tf:SetFrameLevel(bar.fill:GetFrameLevel() + 2)
	bar.edgeFrame = CreateFrame("Frame", nil, bar.row)
	bar.edgeFrame:SetAllPoints(bar.row)
	bar.edgeFrame:SetFrameLevel(bar.fill:GetFrameLevel() + 1)
	bar.edges = MakeEdges(bar.edgeFrame, "OVERLAY")
	bar.textFrame = tf
	bar.pos = tf:CreateFontString(nil, "OVERLAY")
	bar.label = tf:CreateFontString(nil, "OVERLAY")
	bar.amount = tf:CreateFontString(nil, "OVERLAY")
	SetDMFont(bar.pos, 11)
	SetDMFont(bar.label, 11)
	SetDMFont(bar.amount, 11)
	bar.label:SetJustifyH("LEFT")
	bar.label:SetWordWrap(false)
	bar.amount:SetJustifyH("RIGHT")
	bar.hl = bar.row:CreateTexture(nil, "HIGHLIGHT")
	bar.hl:SetAllPoints(bar.row)
	Solid(bar.hl, 1, 1, 1, 0.06)
	bar.row:SetScript("OnClick", function(_, button)
		if button == "RightButton" then
			W.ShowHome()
		elseif bar.src and W.curDMType ~= nil then
			W.OpenSource(bar.src)
		end
	end)
	bar.row:SetScript("OnEnter", function() ShowBreakdownTip(W, bar) end)
	bar.row:SetScript("OnLeave", HideBreakdownTip)
	bar.row:EnableMouseWheel(true)
	bar.row:SetScript("OnMouseWheel", function(_, delta) W.Scroll(delta) end)
	bar.row:Hide()
	return bar
end

-- Style pass of one row (fonts, texture, sizes, borders, text anchors).
local function StyleRow(bar, barH)
	local c = DB()
	bar.row:SetHeight(barH)
	bar.fill:SetStatusBarTexture(DM.TexturePath(c.barTexture))
	bar.fill:SetAlpha(c.barFillAlpha or 1)
	SetDMFont(bar.pos, c.leftFontSize or c.fontSize or 11)
	SetDMFont(bar.label, c.leftFontSize or c.fontSize or 11)
	SetDMFont(bar.amount, c.rightFontSize or c.fontSize or 11)
	local lx, ly = c.leftTextOffsetX or 0, c.leftTextOffsetY or 0
	local rx, ry = c.rightTextOffsetX or 0, c.rightTextOffsetY or 0
	bar.pos:ClearAllPoints()
	bar.pos:SetPoint("LEFT", bar.textFrame, "LEFT", 3 + lx, ly)
	bar.label:ClearAllPoints()
	bar.label:SetPoint("LEFT", bar.pos, "RIGHT", 2, 0)
	bar.label:SetPoint("RIGHT", bar.textFrame, "RIGHT", -70, ly)
	bar.amount:ClearAllPoints()
	bar.amount:SetPoint("RIGHT", bar.textFrame, "RIGHT", -3 + rx, ry)
	PaintEdges(bar.edges, bar.row, c.borderSize or 0, c.borderR, c.borderG, c.borderB, c.borderA)
end

-- Fills one row from a source.
local function FillRow(W, bar, src, rank, maxAmt, barH)
	local c = DB()
	bar.src = src
	local iconW = ResolveIcon(src, bar.icon, barH)
	bar.fill:ClearAllPoints()
	bar.fill:SetPoint("TOPLEFT", bar.row, "TOPLEFT", iconW, 0)
	bar.fill:SetPoint("BOTTOMRIGHT", bar.row, "BOTTOMRIGHT", 0, 0)
	if c.customIconBorder and (c.iconBorderSize or 0) > 0 and iconW > 0 then
		PaintEdges(bar.iconEdges, bar.icon, c.iconBorderSize, c.iconBorderR, c.iconBorderG, c.iconBorderB, c.iconBorderA)
	else
		PaintEdges(bar.iconEdges, bar.icon, 0)
	end
	local cr, cg, cb = ClassColor(src.class)
	if c.showClassColor ~= false then
		if cr then
			bar.fill:SetStatusBarColor(cr, cg, cb)
		elseif W.curDMType == T.EnemyDamageTaken then
			bar.fill:SetStatusBarColor(0xDD / 255, 0x31 / 255, 0x31 / 255)
		else
			bar.fill:SetStatusBarColor(0.5, 0.5, 0.5)
		end
	elseif c.barColorUseAccent ~= false then
		bar.fill:SetStatusBarColor(Accent())
	else
		bar.fill:SetStatusBarColor(RGB(c.barColor, 0.35, 0.55, 0.8))
	end
	local a = c.barBgAlpha or 0
	if c.barBgUseClassColor and cr then
		Solid(bar.bg, cr, cg, cb, a)
	else
		Solid(bar.bg, c.barBgR, c.barBgG, c.barBgB, a)
	end
	if W.curDMType == T.Deaths then
		bar.fill:SetMinMaxValues(0, 1)
		bar.fill:SetValue(1)
	else
		bar.fill:SetMinMaxValues(0, maxAmt > 0 and maxAmt or 1)
		bar.fill:SetValue(src.total or 0)
	end
	bar.pos:SetText(c.hideNumbers and "" or (RANK_STRINGS[rank] or (rank .. ".")))
	bar.label:SetText(ShortName(src.name))
	if c.leftTextUseClassColor and cr then
		bar.label:SetTextColor(cr, cg, cb, 1)
		bar.pos:SetTextColor(cr, cg, cb, 1)
	else
		local r, g, b = RGB(c.leftTextColor, 1, 1, 1)
		bar.label:SetTextColor(r, g, b, 1)
		bar.pos:SetTextColor(r, g, b, 1)
	end
	if c.rightTextUseClassColor and cr then
		bar.amount:SetTextColor(cr, cg, cb, 1)
	else
		bar.amount:SetTextColor(RGB(c.rightTextColor, 1, 1, 1))
	end
	if W.curDMType == T.Deaths then
		bar.amount:SetText(W.curSession == S.Overall and not W.curSessionID and "" or FormatTimer(src.deathTime or 0))
	elseif W.curDMType == T.Interrupts or W.curDMType == T.Dispels then
		bar.amount:SetText(Abbrev(src.total))
	else
		bar.amount:SetText(FormatBarValue(src.total, src.perSec, c.numberFormat or 2))
	end
	bar.row:Show()
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local CreateDMWindow -- forward

local function HeaderButton(W, texFile, tooltip, onClick)
	local btn = CreateFrame("Button", nil, W.header)
	btn:SetFrameLevel(W.header:GetFrameLevel() + 2)
	btn:RegisterForClicks("AnyUp")
	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexture(texFile)
	icon:SetDesaturated(true)
	btn.icon = icon
	local function Paint(hover)
		local r, g, b = IconColor()
		local a = hover and ICON_HOVER_ALPHA or ICON_ALPHA
		if btn.dim then a = a * 0.5 end
		icon:SetVertexColor(r, g, b, a)
	end
	btn.Paint = Paint
	Paint(false)
	btn:SetScript("OnEnter", function(self)
		Paint(true)
		local tip = type(tooltip) == "function" and tooltip() or tooltip
		if ns.ShowWidgetTooltip and tip then ns.ShowWidgetTooltip(self, tip) end
	end)
	btn:SetScript("OnLeave", function()
		Paint(false)
		if ns.HideWidgetTooltip then ns.HideWidgetTooltip() end
	end)
	btn:SetScript("OnClick", function(self, button)
		if ns.HideWidgetTooltip then ns.HideWidgetTooltip() end
		onClick(self, button)
	end)
	W.hdrBtns[#W.hdrBtns + 1] = btn
	return btn
end

-- Header buttons laid out from the right: settings, segment, mode, reset, window.
local function LayoutHeader(W)
	local c = DB()
	local sz = c.hdrIconSize or 22
	local hh = HeaderH()
	sz = min(sz, hh + 8)
	local pad = 2
	local n = 0
	for _, btn in ipairs(W.hdrBtns) do
		if btn == W.resetBtn and c.hideResetButton then
			btn:Hide()
		else
			n = n + 1
			btn:SetSize(sz, sz)
			btn:ClearAllPoints()
			btn:SetPoint("RIGHT", W.header, "RIGHT", -(sz * (n - 1) + pad * n + 2), 0)
			btn:Show()
		end
	end
	W.hdrBtnCount = n
	W.hdrBtnSize = sz
end

local function SetHeaderButtonsShown(W, shown)
	for _, btn in ipairs(W.hdrBtns) do
		if btn:IsShown() then
			btn:SetAlpha(shown and 1 or 0)
			btn:EnableMouse(shown)
		end
	end
	W.hdrIconsShown = shown
	W.FitTitle()
end

CreateDMWindow = function(idx)
	local wdb = WinDB(idx)
	local W = { idx = idx, hdrBtns = {}, rows = {} }
	W.curDMType = wdb.curDMType
	if W.curDMType ~= nil and not TYPE_NAMES[W.curDMType] then W.curDMType = T.DamageDone end
	W.curSession = wdb.curSession or S.Current
	W.curSessionID = nil
	W.windowLocked = wdb.locked or false

	local frame = CreateFrame("Frame", "EllesmereUIDMFrame" .. idx, UIParent)
	frame:SetSize(max(MIN_W, wdb.width or 300), max(MIN_H, wdb.height or 200))
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:SetFrameStrata("MEDIUM")
	W.frame = frame
	ApplyWinPosition(frame, wdb, idx)
	W.ApplyPosition = function() ApplyWinPosition(frame, WinDB(W.idx), W.idx) end

	frame.bg = frame:CreateTexture(nil, "BACKGROUND")

	local header = CreateFrame("Frame", nil, frame)
	header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	header:SetFrameLevel(frame:GetFrameLevel() + 5)
	header:EnableMouse(true)
	W.header = header
	header.bg = header:CreateTexture(nil, "BACKGROUND")
	header.bg:SetAllPoints()
	header.bottom = header:CreateTexture(nil, "OVERLAY")
	header.bottom:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
	header.bottom:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
	W.title = header:CreateFontString(nil, "OVERLAY")
	W.title:SetJustifyH("LEFT")
	W.title:SetWordWrap(false)
	W.timerText = header:CreateFontString(nil, "OVERLAY")
	W.timerText:SetPoint("LEFT", W.title, "RIGHT", 4, 0)
	W.timerText:SetTextColor(1, 1, 1, 0.7)
	SetDMFont(W.title, 11)
	SetDMFont(W.timerText, 11)
	W.fullTitle = "Damage Done"

	-- Window border (overlay so it can include or skip the header).
	W.borderFrame = CreateFrame("Frame", nil, frame)
	W.borderFrame:EnableMouse(false)
	W.borderEdges = MakeEdges(W.borderFrame, "OVERLAY")

	-- Header buttons.
	W.settingsBtn = HeaderButton(W, MEDIA .. "dm_settings", "Settings", function(self) W.ShowSettingsMenu(self) end)
	W.segmentBtn = HeaderButton(W, MEDIA .. "dm_sheet", "Select Segment", function(self) W.ShowSegmentMenu(self) end)
	W.modeBtn = HeaderButton(W, TYPE_ICONS[W.curDMType or T.DamageDone], "Switch Meter Type", function(self) W.ShowModeMenu(self) end)
	W.resetBtn = HeaderButton(W, MEDIA .. "dm_undo", "Reset Data", function() DM.ResetData() end)
	if idx == 1 then
		W.winBtn = HeaderButton(W, MEDIA .. "dm_open", function()
			if #windows >= MAX_WINDOWS then return format("You may only have %d windows active", MAX_WINDOWS) end
			return "New Window"
		end, function() DM.AddWindow(W) end)
	else
		W.winBtn = HeaderButton(W, MEDIA .. "dm_close", function()
			return W.windowLocked and "Unlock Window to Close" or "Close Window"
		end, function()
			if not W.windowLocked then DM.RemoveWindow(W.idx) end
		end)
	end

	-- Title fit: never runs under the header icons (cut with "...").
	function W.FitTitle()
		local c = DB()
		local n = W.hdrIconsShown == false and 0 or (W.hdrBtnCount or 0)
		local sz = W.hdrBtnSize or (c.hdrIconSize or 22)
		local avail = (frame:GetWidth() or 300) - n * (sz + 2) - 2 - (6 + (c.hdrTextOffX or 0)) - 6
		if W.timerText:IsShown() then avail = avail - (W.timerText:GetStringWidth() or 0) - 4 end
		if avail < 1 then avail = 1 end
		local full = W.fullTitle or ""
		W.title:SetText(full)
		if (W.title:GetStringWidth() or 0) <= avail then return end
		local s = full
		while #s > 1 do
			local i = #s
			while i > 1 do
				local byte = s:byte(i)
				if byte < 0x80 or byte >= 0xC0 then break end
				i = i - 1
			end
			s = s:sub(1, i - 1)
			W.title:SetText(s .. "...")
			if (W.title:GetStringWidth() or 0) <= avail then return end
		end
	end

	-- Drag by the header (unlocked windows), left-click on a locked window =
	-- segment menu, right-click = home screen, mouse wheel = older / newer fight.
	header:EnableMouseWheel(true)
	header:SetScript("OnMouseWheel", function(_, delta) W.StepSegment(delta) end)
	header:SetScript("OnMouseDown", function(_, button)
		if button == "LeftButton" and not W.windowLocked and not unlockOn then
			W.dragging = true
			frame:StartMoving()
		end
	end)
	header:SetScript("OnMouseUp", function(_, button)
		if button == "RightButton" then
			if not W.dragging then W.ToggleHome() end
			return
		end
		if not W.dragging then
			if button == "LeftButton" and header:IsMouseOver() then W.ShowSegmentMenu(W.segmentBtn) end
			return
		end
		W.dragging = false
		frame:StopMovingOrSizing()
		local left, top = frame:GetLeft(), frame:GetTop()
		if left and top then
			left, top = floor(left + 0.5), floor(top + 0.5)
			WinDB(W.idx).position = { x = left, y = top }
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
		end
	end)

	-- Right-click on the empty area under the header opens the home screen.
	local catcher = CreateFrame("Button", nil, frame)
	catcher:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
	catcher:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	catcher:SetFrameLevel(frame:GetFrameLevel() + 1)
	catcher:RegisterForClicks("RightButtonUp")
	catcher:SetScript("OnClick", function() W.ShowHome() end)

	-- Viewport + rows.
	local viewport = CreateFrame("ScrollFrame", nil, frame)
	viewport:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
	viewport:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	viewport:SetFrameLevel(frame:GetFrameLevel() + 2)
	viewport:EnableMouseWheel(true)
	W.viewport = viewport
	local content = CreateFrame("Frame", nil, viewport)
	content:SetSize(1, 1)
	viewport:SetScrollChild(content)
	W.content = content
	viewport:SetScript("OnMouseWheel", function(_, delta) W.Scroll(delta) end)

	W.msg = frame:CreateFontString(nil, "OVERLAY")
	W.msg:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 6, -6)
	W.msg:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -6, -6)
	W.msg:SetJustifyH("LEFT")
	SetDMFont(W.msg, 11)
	W.msg:SetTextColor(1, 1, 1, 0.6)
	W.msg:Hide()

	for i = 1, BAR_POOL_SIZE do
		W.rows[i] = MakeRow(W, content)
	end
	-- Pinned own row (retail "Always Show Player").
	W.sticky = MakeRow(W, frame)
	W.sticky.row:SetFrameLevel(viewport:GetFrameLevel() + 6)
	W.stickySep = W.sticky.row:CreateTexture(nil, "OVERLAY")
	Solid(W.stickySep, 1, 1, 1, 0.25)

	W.scroll = 0
	function W.Scroll(delta)
		local c = DB()
		local stride = (c.barHeight or 18) + (c.barSpacing or 2)
		local maxScroll = max(0, (W.count or 0) * stride - (viewport:GetHeight() or 0))
		W.scroll = min(maxScroll, max(0, W.scroll - delta * stride))
		viewport:SetVerticalScroll(W.scroll)
		W.UpdateSticky()
	end

	-- Breakdown view inside the window (retail OpenSource / CloseSource).
	W.sourceFrame = CreateFrame("Button", nil, frame)
	W.sourceFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
	W.sourceFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	W.sourceFrame:SetFrameLevel(frame:GetFrameLevel() + 20)
	W.sourceFrame:RegisterForClicks("AnyUp")
	W.sourceFrame:EnableMouseWheel(true)
	W.sourceFrame.bg = W.sourceFrame:CreateTexture(nil, "BACKGROUND")
	W.sourceFrame.bg:SetAllPoints()
	W.sourceFrame:Hide()
	W.sourceFrame:SetScript("OnClick", function() W.CloseSource() end)
	W.spellRows = {}
	W.srcScroll = 0
	W.sourceFrame:SetScript("OnMouseWheel", function(_, delta)
		local c = DB()
		local stride = (c.barHeight or 18) + (c.barSpacing or 2)
		local maxScroll = max(0, (W.srcCount or 0) - floor((W.sourceFrame:GetHeight() or 0) / stride))
		W.srcScroll = min(maxScroll, max(0, W.srcScroll - delta))
		W.RefreshBreakdown()
	end)

	function W.OpenSource(src)
		W.source = src
		W.srcScroll = 0
		W.sourceFrame:Show()
		HideBreakdownTip()
		W.RefreshBreakdown()
		W.Refresh()
	end
	function W.CloseSource()
		W.source = nil
		W.sourceFrame:Hide()
		if GameTooltip:IsOwned(W.sourceFrame) then GameTooltip:Hide() end
		W.Refresh()
	end

	function W.RefreshBreakdown()
		if not W.source then return end
		local c = DB()
		local combat = GetCombat(W)
		local list = GetBreakdown(combat, W.curDMType, W.source)
		local barH, sp = c.barHeight or 18, c.barSpacing or 2
		local stride = barH + sp
		Solid(W.sourceFrame.bg, c.bgR, c.bgG, c.bgB, max(c.bgAlpha or 0, 0.85))
		local fits = max(1, floor((W.sourceFrame:GetHeight() or stride) / stride))
		W.srcCount = #list
		local top = list[1] and list[1].amount or 1
		local total = 0
		for i = 1, #list do total = total + list[i].amount end
		for i = 1, fits do
			local e = list[i + W.srcScroll]
			local r = W.spellRows[i]
			if not r and e then
				r = MakeRow(W, W.sourceFrame)
				r.row:SetFrameLevel(W.sourceFrame:GetFrameLevel() + 2)
				r.row:SetScript("OnClick", function() W.CloseSource() end)
				r.row:SetScript("OnMouseWheel", function(_, delta)
					local f = W.sourceFrame:GetScript("OnMouseWheel")
					f(W.sourceFrame, delta)
				end)
				W.spellRows[i] = r
			end
			if r then
				if e then
					StyleRow(r, barH)
					r.row:ClearAllPoints()
					r.row:SetPoint("TOPLEFT", W.sourceFrame, "TOPLEFT", 0, -(i - 1) * stride)
					r.row:SetPoint("TOPRIGHT", W.sourceFrame, "TOPRIGHT", 0, -(i - 1) * stride)
					local iconW = 0
					if e.icon then
						r.icon:SetTexture(e.icon)
						r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
						r.icon:SetSize(barH, barH)
						r.icon:Show()
						iconW = barH
					elseif e.class then
						iconW = ResolveIcon({ class = e.class, spec = e.spec }, r.icon, barH)
					else
						r.icon:Hide()
					end
					PaintEdges(r.iconEdges, r.icon, 0)
					r.fill:ClearAllPoints()
					r.fill:SetPoint("TOPLEFT", r.row, "TOPLEFT", iconW, 0)
					r.fill:SetPoint("BOTTOMRIGHT", r.row, "BOTTOMRIGHT", 0, 0)
					r.fill:SetMinMaxValues(0, top > 0 and top or 1)
					r.fill:SetValue(e.amount)
					local cr, cg, cb = ClassColor(e.class or W.source.class)
					if e.heal then
						r.fill:SetStatusBarColor(0.3, 0.75, 0.3)
					elseif cr then
						r.fill:SetStatusBarColor(cr, cg, cb)
					else
						r.fill:SetStatusBarColor(Accent())
					end
					Solid(r.bg, c.barBgR, c.barBgG, c.barBgB, c.barBgAlpha or 0)
					r.pos:SetText("")
					r.label:SetText(e.label)
					r.label:SetTextColor(1, 1, 1, 1)
					r.amount:SetTextColor(1, 1, 1, 1)
					if W.curDMType == T.Deaths then
						r.amount:SetText((e.heal and "+" or "-") .. Abbrev(e.amount))
					else
						r.amount:SetText(format("%s (%.1f%%)", Abbrev(e.amount), total > 0 and e.amount / total * 100 or 0))
					end
					r.src = nil
					r.spellID = e.spellID
					r.row:SetScript("OnEnter", function(self)
						if DB().showSpellTooltips == false or type(r.spellID) ~= "number" or r.spellID <= 1 then return end
						GameTooltip:SetOwner(self, "ANCHOR_NONE")
						GameTooltip:ClearAllPoints()
						GameTooltip:SetPoint("TOPRIGHT", self, "TOPLEFT", -6, 0)
						GameTooltip:SetHyperlink("spell:" .. r.spellID)
						GameTooltip:Show()
					end)
					r.row:SetScript("OnLeave", function() GameTooltip:Hide() end)
					r.row:Show()
				else
					r.row:Hide()
				end
			end
		end
		for i = fits + 1, #W.spellRows do W.spellRows[i].row:Hide() end
		W.fullTitle = ShortName(W.source.name) .. " - " .. (TYPE_NAMES[W.curDMType] or "")
		W.FitTitle()
	end

	-- Resize grip + lock icon (bottom right, shown while hovered).
	W.grip = CreateFrame("Button", nil, frame)
	W.grip:SetSize(18, 18)
	W.grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
	W.grip:SetFrameLevel(frame:GetFrameLevel() + 30)
	local gripTex = W.grip:CreateTexture(nil, "ARTWORK")
	gripTex:SetAllPoints()
	gripTex:SetTexture(MEDIA .. "resize_element")
	gripTex:SetDesaturated(true)
	W.grip:SetAlpha(0)
	W.grip:SetScript("OnEnter", function(self) if not W.windowLocked then self:SetAlpha(0.7) end end)
	W.grip:SetScript("OnLeave", function(self) self:SetAlpha((W.isHovered and not W.windowLocked) and 0.3 or 0) end)
	W.grip:SetScript("OnMouseDown", function(_, button)
		if button ~= "LeftButton" or W.windowLocked or unlockOn then return end
		local x, y = GetCursorPosition()
		local s = frame:GetEffectiveScale()
		W.resizing = { x = x / s, y = y / s, w = frame:GetWidth(), h = frame:GetHeight(),
			left = frame:GetLeft(), top = frame:GetTop() }
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", W.resizing.left, W.resizing.top)
	end)
	W.grip:SetScript("OnMouseUp", function()
		if not W.resizing then return end
		local r = W.resizing
		W.resizing = nil
		local wdb2 = WinDB(W.idx)
		wdb2.width = floor(frame:GetWidth() + 0.5)
		wdb2.height = floor(frame:GetHeight() + 0.5)
		wdb2.position = { x = floor(r.left + 0.5), y = floor(r.top + 0.5) }
		W.Layout()
		W.Refresh()
	end)
	W.grip:SetScript("OnUpdate", function()
		local r = W.resizing
		if not r then return end
		local x, y = GetCursorPosition()
		local s = frame:GetEffectiveScale()
		frame:SetWidth(max(MIN_W, r.w + x / s - r.x))
		frame:SetHeight(max(MIN_H, r.h + r.y - y / s))
		W.FitTitle()
	end)

	W.lockBtn = CreateFrame("Button", nil, frame)
	W.lockBtn:SetSize(13, 17)
	W.lockBtn:SetFrameLevel(frame:GetFrameLevel() + 31)
	W.lockBtn:SetAlpha(0)
	local lockTex = W.lockBtn:CreateTexture(nil, "ARTWORK")
	lockTex:SetAllPoints()
	lockTex:SetDesaturated(true)
	local function UpdateLockIcon()
		W.lockBtn:ClearAllPoints()
		if W.windowLocked then
			lockTex:SetTexture(MEDIA .. "dm_locked")
			W.lockBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
		else
			lockTex:SetTexture(MEDIA .. "dm_unlocked")
			W.lockBtn:SetPoint("RIGHT", W.grip, "LEFT", -2, 0)
		end
		if idx ~= 1 then
			W.winBtn.dim = W.windowLocked
			W.winBtn.Paint(false)
		end
	end
	W.UpdateLockIcon = UpdateLockIcon
	UpdateLockIcon()
	W.lockBtn:SetScript("OnEnter", function(self)
		self:SetAlpha(0.7)
		if ns.ShowWidgetTooltip then ns.ShowWidgetTooltip(self, W.windowLocked and "Locked" or "Unlocked") end
	end)
	W.lockBtn:SetScript("OnLeave", function(self)
		self:SetAlpha(W.isHovered and 0.3 or 0)
		if ns.HideWidgetTooltip then ns.HideWidgetTooltip() end
	end)
	W.lockBtn:SetScript("OnClick", function()
		W.windowLocked = not W.windowLocked
		WinDB(W.idx).locked = W.windowLocked
		UpdateLockIcon()
		W.grip:SetAlpha((W.isHovered and not W.windowLocked) and 0.3 or 0)
	end)

	-- Hover poll: grip / lock alpha, mouseover header icons, mouseover visibility.
	local pollT = 0
	frame:SetScript("OnUpdate", function(_, elapsed)
		pollT = pollT + elapsed
		if pollT < 0.1 then return end
		pollT = 0
		local hovered = frame:IsMouseOver() and true or false
		local c = DB()
		if hovered ~= W.isHovered then
			W.isHovered = hovered
			if not W.grip:IsMouseOver() then W.grip:SetAlpha((hovered and not W.windowLocked) and 0.3 or 0) end
			if not W.lockBtn:IsMouseOver() then W.lockBtn:SetAlpha(hovered and 0.3 or 0) end
		end
		if c.hdrMouseoverIcons then
			local over = header:IsMouseOver() and true or false
			if over ~= W.hdrIconsShown then SetHeaderButtonsShown(W, over) end
		elseif W.hdrIconsShown ~= true then
			SetHeaderButtonsShown(W, true)
		end
		if c.visibility == "mouseover" and not previewOn and not unlockOn then
			frame:SetAlpha(hovered and 1 or 0)
		elseif frame:GetAlpha() ~= 1 then
			frame:SetAlpha(1)
		end
	end)

	-- Style pass: header, background, border, rows.
	function W.Layout()
		local c = DB()
		local hh = HeaderH()
		header:SetHeight(hh)
		frame.bg:ClearAllPoints()
		frame.bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -hh)
		frame.bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
		Solid(frame.bg, c.bgR, c.bgG, c.bgB, c.bgAlpha or 0.75)
		local hr, hg, hb = RGB(c.hdrBgColor, 0x1B / 255, 0x1B / 255, 0x1B / 255)
		Solid(header.bg, hr, hg, hb, c.hdrBgAlpha or 1)
		local bsz = c.hdrBottomBorderSize or 0
		if bsz > 0 then
			local bc = c.hdrBottomBorderColor or {}
			header.bottom:SetHeight(Px(bsz))
			Solid(header.bottom, bc.r, bc.g, bc.b, bc.a or 1)
			header.bottom:Show()
		else
			header.bottom:Hide()
		end
		SetDMFont(W.title, c.hdrFontSize or 11)
		SetDMFont(W.timerText, c.hdrFontSize or 11)
		W.title:ClearAllPoints()
		W.title:SetPoint("LEFT", header, "LEFT", 6 + (c.hdrTextOffX or 0), c.hdrTextOffY or 0)
		if c.hdrTextUseAccent ~= false then
			W.title:SetTextColor(Accent())
		else
			W.title:SetTextColor(RGB(c.hdrTextColor, 1, 1, 1))
		end
		W.timerText:SetShown(not WinDB(W.idx).hideTimer)
		W.modeBtn.icon:SetTexture(TYPE_ICONS[W.curDMType or T.DamageDone])
		LayoutHeader(W)
		for _, btn in ipairs(W.hdrBtns) do btn.Paint(false) end
		W.hdrIconsShown = nil
		-- Window border.
		W.borderFrame:ClearAllPoints()
		if c.windowBorderIncludeHeader ~= false then
			W.borderFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
		else
			W.borderFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -hh)
		end
		W.borderFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
		if c.windowBorderBehind then
			W.borderFrame:SetFrameLevel(max(0, frame:GetFrameLevel()))
			local bc = c.windowBorderColor or {}
			local s = Px(c.windowBorderSize or 0)
			-- Behind: the border sits outside the window edge.
			W.borderFrame:ClearAllPoints()
			W.borderFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", -s, c.windowBorderIncludeHeader ~= false and s or -hh + s)
			W.borderFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", s, -s)
			PaintEdges(W.borderEdges, W.borderFrame, c.windowBorderSize or 0, bc.r, bc.g, bc.b, bc.a or 1)
		else
			W.borderFrame:SetFrameLevel(frame:GetFrameLevel() + 40)
			local bc = c.windowBorderColor or {}
			PaintEdges(W.borderEdges, W.borderFrame, c.windowBorderSize or 0, bc.r, bc.g, bc.b, bc.a or 1)
		end
		-- Rows.
		local barH = c.barHeight or 18
		local stride = barH + (c.barSpacing or 2)
		for i, bar in ipairs(W.rows) do
			StyleRow(bar, barH)
			bar.row:ClearAllPoints()
			bar.row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * stride)
			bar.row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -(i - 1) * stride)
		end
		StyleRow(W.sticky, barH)
		content:SetWidth(max(1, frame:GetWidth()))
		W.UpdateLockIcon()
		W.FitTitle()
		if W.home and W.home:IsShown() then W.RefreshHome() end
	end

	-- Viewport anchors; inset shrinks it at the top or bottom so the pinned
	-- row never covers list rows (retail ResetScrollAnchors / pinnedH).
	local function SetViewportInset(top, bottom)
		viewport:ClearAllPoints()
		viewport:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -top)
		viewport:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, bottom)
	end

	-- Clamps the scroll after the viewport height changed.
	local function ClampScroll(stride)
		local maxScroll = max(0, (W.count or 0) * stride - (viewport:GetHeight() or 0))
		if W.scroll > maxScroll then
			W.scroll = maxScroll
			viewport:SetVerticalScroll(W.scroll)
		end
	end

	function W.UpdateSticky()
		local c = DB()
		local bar = W.sticky
		local idxMe = W.meIndex
		local barH = c.barHeight or 18
		local stride = barH + (c.barSpacing or 2)
		if not c.showPinnedSelf or not idxMe or W.source then
			bar.row:Hide()
			W.stickySep:Hide()
			SetViewportInset(0, 0)
			ClampScroll(stride)
			return
		end
		-- Full list height (without any pinned inset).
		local viewH = (frame:GetHeight() or 0) - (header:GetHeight() or 0)
		local barTop = (idxMe - 1) * stride
		if barTop >= W.scroll - 1 and barTop + barH <= W.scroll + viewH + 1 then
			bar.row:Hide()
			W.stickySep:Hide()
			SetViewportInset(0, 0)
			ClampScroll(stride)
			return
		end
		bar.row:ClearAllPoints()
		W.stickySep:ClearAllPoints()
		W.stickySep:SetHeight(Px(1))
		local pinnedH = barH + Px(1)
		if barTop < W.scroll then
			bar.row:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
			bar.row:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)
			W.stickySep:SetPoint("TOPLEFT", bar.row, "BOTTOMLEFT", 0, 0)
			W.stickySep:SetPoint("TOPRIGHT", bar.row, "BOTTOMRIGHT", 0, 0)
			SetViewportInset(pinnedH, 0)
		else
			bar.row:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
			bar.row:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
			W.stickySep:SetPoint("BOTTOMLEFT", bar.row, "TOPLEFT", 0, 0)
			W.stickySep:SetPoint("BOTTOMRIGHT", bar.row, "TOPRIGHT", 0, 0)
			SetViewportInset(0, pinnedH)
		end
		ClampScroll(stride)
		local src = W.sources and W.sources[idxMe]
		if not src then bar.row:Hide(); W.stickySep:Hide(); return end
		FillRow(W, bar, src, idxMe, W.maxAmt or 1, barH)
		W.stickySep:Show()
	end

	function W.UpdateTimerText()
		if not W.timerText:IsShown() then return end
		local isOverall = not W.curSessionID and W.curSession == S.Overall
		local combat = GetCombat(W)
		local dur = combat and CombatTime(combat) or 0
		if isOverall or not combat or (W.count or 0) == 0 or dur <= 0.1 then
			W.timerText:SetText("")
		else
			W.timerText:SetText("(" .. FormatTimer(dur) .. ")")
		end
	end

	function W.Refresh()
		if not frame:IsVisible() then
			W.pending = true
			return
		end
		W.pending = nil
		local c = DB()
		local barH = c.barHeight or 18
		local stride = barH + (c.barSpacing or 2)
		local count = 0
		W.meIndex = nil
		if W.curDMType == nil then
			W.msg:Hide()
			W.sources = nil
		else
			W.msg:Hide()
			local combat = GetCombat(W)
			local sources = GetSources(combat, W.curDMType)
			W.sources = sources
			count = min(#sources, BAR_POOL_SIZE)
			local maxAmt = W.curDMType == T.Deaths and 1 or (sources[1] and sources[1].total or 1)
			W.maxAmt = maxAmt
			for i = 1, count do
				FillRow(W, W.rows[i], sources[i], i, maxAmt, barH)
				if sources[i].isLocalPlayer and not W.meIndex then W.meIndex = i end
			end
			if count == 0 then
				W.msg:SetText("No combat data")
				W.msg:Show()
			end
		end
		for i = count + 1, BAR_POOL_SIZE do
			W.rows[i].row:Hide()
			W.rows[i].src = nil
		end
		W.count = count
		content:SetHeight(max(1, count * stride))
		local maxScroll = max(0, count * stride - (viewport:GetHeight() or 0))
		if W.scroll > maxScroll then
			W.scroll = maxScroll
			viewport:SetVerticalScroll(W.scroll)
		end
		W.UpdateSticky()
		local typeName = TYPE_NAMES[W.curDMType] or "Damage Done"
		if W.source then
			W.RefreshBreakdown()
		else
			local isOverall = not W.curSessionID and W.curSession == S.Overall
			W.fullTitle = isOverall and ("Overall " .. typeName) or typeName
			local seg = W.curSessionID
			if seg then
				W.fullTitle = (seg.name or "Combat") .. (seg.try and (" #" .. seg.try) or "") .. " - " .. typeName
			end
		end
		W.UpdateTimerText()
		W.FitTitle()
		if idx == 1 and DM.UpdateTimerText then DM.UpdateTimerText() end
	end

	frame:SetScript("OnShow", function()
		if W.pending then W.Refresh() end
	end)
	frame:SetScript("OnSizeChanged", function(self, w)
		content:SetWidth(max(1, w or self:GetWidth()))
		W.FitTitle()
		W.UpdateSticky()
		if W.home and W.home:IsShown() then W.RefreshHome() end
	end)

	function W.SetDMType(dmType)
		W.curDMType = dmType
		WinDB(W.idx).curDMType = dmType
		if W.source then W.CloseSource() end
		W.scroll = 0
		viewport:SetVerticalScroll(0)
		W.modeBtn.icon:SetTexture(TYPE_ICONS[dmType] or TYPE_ICONS[T.DamageDone])
		W.Refresh()
	end

	-- Menus ------------------------------------------------------------
	function W.ShowModeMenu(anchor)
		local function entry(label, dmType)
			return { text = label, isActive = dmType == W.curDMType, onClick = function() W.HideHome(); W.SetDMType(dmType) end }
		end
		local cur = W.curDMType
		local items = {
			{ text = "Damage", isActive = cur == T.DamageDone or cur == T.DamageTaken or cur == T.EnemyDamageTaken, children = {
				entry("Damage Done", T.DamageDone), entry("Damage Taken", T.DamageTaken),
				entry("Enemy Damage Taken", T.EnemyDamageTaken),
			} },
			entry("Healing", T.HealingDone),
			{ text = "Actions", isActive = cur == T.Interrupts or cur == T.Dispels or cur == T.Deaths, children = {
				entry("Interrupts", T.Interrupts), entry("Dispels", T.Dispels), entry("Deaths", T.Deaths),
			} },
		}
		ShowMenu(items, anchor)
	end

	function W.ShowSegmentMenu(anchor)
		ShowMenu(DM.SegmentMenuItems(W), anchor)
	end

	-- Mouse wheel on the header: up = an older fight, down = a newer one,
	-- past the newest = Current.
	function W.StepSegment(delta)
		local segs = Engine().GetSegments()
		-- Out of combat Current shows the newest fight, so it counts as that one.
		local pos = (not W.curSessionID and W.curSession == S.Current and not Engine().InCombat()) and 1 or 0
		for i = 1, #segs do
			if segs[i] == W.curSessionID then pos = i end
		end
		pos = max(0, min(#segs, pos + (delta > 0 and 1 or -1)))
		if pos == 0 then
			DM.ApplySegmentSelection(W, S.Current, nil)
		else
			DM.ApplySegmentSelection(W, nil, segs[pos])
		end
	end

	function W.ShowSettingsMenu(anchor)
		local w2 = WinDB(W.idx)
		local function toggle(text, key, after, tip)
			return { text = text, isActive = w2[key] and true or false, tooltip = tip, onClick = function()
				w2[key] = not w2[key]
				if after then after() end
			end }
		end
		local function mStart(label, dmType)
			return { text = label, isActive = w2.mythicStartDMType == dmType, onClick = function() w2.mythicStartDMType = dmType end }
		end
		local items = {
			toggle("Hide in Dungeons", "hideInDungeon", DM.UpdateVisibility),
			toggle("Hide in Raids", "hideInRaid", DM.UpdateVisibility),
			toggle("Hide in PvP", "hideInPvP", DM.UpdateVisibility),
			toggle("Hide out of Instances", "hideOutOfInstance", DM.UpdateVisibility),
			"---",
			toggle("Hide Timer", "hideTimer", function() W.Layout(); W.Refresh() end),
			toggle("Auto Swap Current/Overall", "autoSwapMythic", nil,
				"Auto switch your window to overall at the end of a Challenge Mode run, and current at the start"),
			toggle("Auto Current on Combat", "autoCurrentOnCombat", nil,
				"Entering combat switches this window back to Current if viewing a past segment"),
			toggle("Sync Segment Selection", "syncSegments", nil, "Selecting a segment switches all synced windows to it"),
			{ text = "Default on Challenge Mode Start", tooltip = "Set your window to this Meter Type on dungeon start", children = {
				{ text = "Off", isActive = not w2.mythicStartDMType, onClick = function() w2.mythicStartDMType = false end },
				"---",
				mStart("Damage Done", T.DamageDone), mStart("Healing", T.HealingDone), mStart("Damage Taken", T.DamageTaken),
				mStart("Enemy Damage Taken", T.EnemyDamageTaken), mStart("Interrupts", T.Interrupts),
				mStart("Dispels", T.Dispels), mStart("Deaths", T.Deaths),
			} },
			{ text = "Settings", onClick = function()
				if ns.LoadOptions and ns.LoadOptions() and ns.OpenSettingsModule then ns.OpenSettingsModule("damageMeters") end
			end },
		}
		ShowMenu(items, anchor)
	end

	-- Home screen (retail bookmarks: a card per meter type) ------------
	local CARD_H, CARD_GAP, CARD_COL_GAP, CARD_PAD_X, CARD_PAD_TOP = 26, 4, 4, 8, 6
	local cards = {}
	local addBtn

	local function MakeCard(parent)
		local card = CreateFrame("Button", nil, parent)
		card:SetHeight(CARD_H)
		card:RegisterForClicks("AnyUp")
		card.bg = card:CreateTexture(nil, "BACKGROUND")
		card.bg:SetAllPoints()
		card.accent = card:CreateTexture(nil, "ARTWORK")
		card.accent:SetWidth(2)
		card.accent:SetPoint("TOPLEFT")
		card.accent:SetPoint("BOTTOMLEFT")
		card.icon = card:CreateTexture(nil, "OVERLAY")
		card.icon:SetSize(CARD_H - 2, CARD_H - 2)
		card.icon:SetPoint("LEFT", card, "LEFT", 6, 0)
		card.icon:SetDesaturated(true)
		card.lbl = card:CreateFontString(nil, "OVERLAY")
		SetDMFont(card.lbl, CTX_FONT_SZ)
		card.lbl:SetPoint("LEFT", card.icon, "RIGHT", 5, 0)
		card.lbl:SetPoint("RIGHT", card, "RIGHT", -24, 0)
		card.lbl:SetJustifyH("LEFT")
		card.lbl:SetWordWrap(false)
		card.arrow = card:CreateTexture(nil, "ARTWORK")
		card.arrow:SetTexture(ARROW_ICON)
		card.arrow:SetSize(14, 14)
		card.arrow:SetPoint("RIGHT", card, "RIGHT", -6, 0)
		card.arrow:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
		return card
	end

	function W.RefreshHome()
		local home = W.home
		if not home then return end
		local list = GetBookmarks()
		local totalW = home:GetWidth() or 0
		if totalW < 1 then totalW = frame:GetWidth() end
		local colW = (totalW - CARD_PAD_X * 2 - CARD_COL_GAP) / 2
		for _, cd in ipairs(cards) do cd:Hide() end
		local ar, ag, ab = Accent()
		local row, col, shown = 0, 0, 0
		for bi = 1, #list do
			local dmType = list[bi]
			if TYPE_NAMES[dmType] then
				shown = shown + 1
				local card = cards[shown]
				if not card then
					card = MakeCard(home)
					cards[shown] = card
				end
				local isActive = dmType == W.curDMType
				card:ClearAllPoints()
				card:SetPoint("TOPLEFT", home, "TOPLEFT", CARD_PAD_X + col * (colW + CARD_COL_GAP), -CARD_PAD_TOP - row * (CARD_H + CARD_GAP))
				card:SetWidth(colW)
				Solid(card.bg, 0.12, 0.12, 0.12, 0.8)
				SetDMFont(card.lbl, CTX_FONT_SZ)
				card.lbl:SetText(TYPE_NAMES[dmType])
				card.icon:SetTexture(TYPE_ICONS[dmType])
				if isActive then
					Solid(card.accent, ar, ag, ab, 1)
					card.accent:Show()
					card.icon:SetVertexColor(ar, ag, ab, 1)
					card.lbl:SetTextColor(1, 1, 1, 1)
				else
					card.accent:Hide()
					card.icon:SetVertexColor(ar, ag, ab, 0.6)
					card.lbl:SetTextColor(1, 1, 1, 0.8)
				end
				card:SetScript("OnEnter", function(self)
					Solid(self.bg, 0.18, 0.18, 0.18, 0.98)
					self.lbl:SetTextColor(1, 1, 1, 1)
				end)
				card:SetScript("OnLeave", function(self)
					Solid(self.bg, 0.12, 0.12, 0.12, 0.8)
					self.lbl:SetTextColor(1, 1, 1, isActive and 1 or 0.8)
				end)
				local bookmarkIndex = bi
				card:SetScript("OnClick", function(_, button)
					if button == "MiddleButton" then
						tremove(list, bookmarkIndex)
						W.RefreshHome()
					elseif button == "LeftButton" then
						W.HideHome()
						W.SetDMType(dmType)
					end
				end)
				card:Show()
				col = col + 1
				if col >= 2 then col = 0; row = row + 1 end
			end
		end
		local addRow = col > 0 and (row + 1) or row
		local offered = 0
		for _ in pairs(TYPE_NAMES) do offered = offered + 1 end
		if shown < offered then
			if not addBtn then
				addBtn = CreateFrame("Button", nil, home)
				addBtn:SetHeight(CARD_H)
				addBtn.bg = addBtn:CreateTexture(nil, "BACKGROUND")
				addBtn.bg:SetAllPoints()
				addBtn.lbl = addBtn:CreateFontString(nil, "OVERLAY")
				SetDMFont(addBtn.lbl, CTX_FONT_SZ)
				addBtn.lbl:SetPoint("CENTER")
				addBtn.hint = addBtn:CreateFontString(nil, "OVERLAY")
				SetDMFont(addBtn.hint, 9)
				addBtn.hint:SetPoint("LEFT", addBtn.lbl, "RIGHT", 6, 0)
				addBtn:SetScript("OnEnter", function(self)
					Solid(self.bg, 0.16, 0.16, 0.16, 0.56)
					self.lbl:SetTextColor(1, 1, 1, 0.5)
				end)
				addBtn:SetScript("OnLeave", function(self)
					Solid(self.bg, 0.12, 0.12, 0.12, 0.4)
					self.lbl:SetTextColor(1, 1, 1, 0.3)
				end)
				addBtn:SetScript("OnClick", function(self)
					local items = {}
					for dt, n in pairs(TYPE_NAMES) do
						local pinned = false
						for _, b in ipairs(list) do if b == dt then pinned = true break end end
						if not pinned then
							items[#items + 1] = { text = n, onClick = function()
								list[#list + 1] = dt
								W.RefreshHome()
							end }
						end
					end
					tsort(items, function(a, b) return a.text < b.text end)
					ShowMenu(items, self)
				end)
			end
			Solid(addBtn.bg, 0.12, 0.12, 0.12, 0.4)
			addBtn.lbl:SetText("+  ADD NEW")
			addBtn.lbl:SetTextColor(1, 1, 1, 0.3)
			addBtn.hint:SetText("(middle click to remove)")
			addBtn.hint:SetTextColor(1, 1, 1, 0.3)
			addBtn:ClearAllPoints()
			addBtn:SetPoint("TOPLEFT", home, "TOPLEFT", CARD_PAD_X, -CARD_PAD_TOP - addRow * (CARD_H + CARD_GAP))
			addBtn:SetPoint("TOPRIGHT", home, "TOPRIGHT", -CARD_PAD_X, -CARD_PAD_TOP - addRow * (CARD_H + CARD_GAP))
			addBtn:Show()
		elseif addBtn then
			addBtn:Hide()
		end
	end

	function W.ShowHome()
		if not W.home then
			local home = CreateFrame("Frame", nil, frame)
			home:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
			home:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
			home:SetFrameLevel(frame:GetFrameLevel() + 25)
			home:EnableMouse(true)
			home.bg = home:CreateTexture(nil, "BACKGROUND")
			home.bg:SetAllPoints()
			Solid(home.bg, 0.03, 0.03, 0.03, 0.95)
			home:SetScript("OnMouseUp", function(_, button)
				if button == "RightButton" and W.curDMType ~= nil then W.HideHome() end
			end)
			W.home = home
		end
		if W.source then W.CloseSource() end
		HideBreakdownTip()
		W.home:Show()
		W.RefreshHome()
	end
	function W.HideHome()
		if W.home then W.home:Hide() end
	end
	function W.ToggleHome()
		if W.home and W.home:IsShown() then W.HideHome() else W.ShowHome() end
	end

	function W.Destroy()
		frame:Hide()
		frame:SetScript("OnUpdate", nil)
		frame:ClearAllPoints()
	end

	W.Layout()
	if W.curDMType == nil then W.ShowHome() end
	return W
end

---------------------------------------------------------------------------
-- Segment selection, data reset, add / remove windows
---------------------------------------------------------------------------
function DM.ApplySegmentSelection(W, sessionType, combat)
	local targets = { W }
	if WinDB(W.idx).syncSegments then
		targets = {}
		for _, w in ipairs(windows) do
			if WinDB(w.idx).syncSegments then targets[#targets + 1] = w end
		end
	end
	for _, w in ipairs(targets) do
		if combat then
			w.curSessionID = combat
		else
			w.curSession = sessionType
			WinDB(w.idx).curSession = sessionType
			w.curSessionID = nil
		end
		if w.source then w.CloseSource() end
		w.Refresh()
	end
end

function DM.ResetData()
	if not Engine().Reset() then
		ns.Print("Damage Meters: combat data cannot be reset during combat.")
		return false
	end
	for _, w in ipairs(windows) do
		w.curSessionID = nil
		if w.source then w.CloseSource() end
	end
	DM.RefreshAll()
	return true
end

function DM.AddWindow(src)
	if #windows >= MAX_WINDOWS then return end
	local newIdx = #windows + 1
	local f = src.frame
	local w, h = f:GetWidth(), f:GetHeight()
	local highestTop, lowestBot = f:GetTop() or 0, f:GetBottom() or 0
	for _, x in ipairs(windows) do
		local t, b = x.frame:GetTop(), x.frame:GetBottom()
		if t and t > highestTop then highestTop = t end
		if b and b < lowestBot then lowestBot = b end
	end
	local newTop = highestTop + h + 10
	if newTop > (UIParent:GetTop() or 0) then newTop = lowestBot - 10 end
	local nw = WinDB(newIdx)
	for k in pairs(nw) do nw[k] = nil end
	nw.width, nw.height = floor(w + 0.5), floor(h + 0.5)
	nw.position = { x = floor((f:GetLeft() or 0) + 0.5), y = floor(newTop + 0.5) }
	local W = CreateDMWindow(newIdx)
	windows[newIdx] = W
	DB().windowCount = newIdx
	DM.RegisterUnlock()
	W.ShowHome()
	W.Refresh()
end

function DM.RemoveWindow(idx)
	local W = windows[idx]
	if not W or idx == 1 then return end
	local c = DB()
	W.Destroy()
	tremove(windows, idx)
	if type(c.windows) == "table" then tremove(c.windows, idx) end
	-- Re-key the windows after it (frames keep their own state).
	for i = idx, #windows do
		windows[i].idx = i
	end
	c.windowCount = #windows
	if ns.ShiftIndexedAnchorKeys then pcall(ns.ShiftIndexedAnchorKeys, "EDM_Win", idx, #windows + 1) end
	DM.RegisterUnlock()
	-- Rebuild so frame names and header buttons match the new order.
	DM.Rebuild()
end

---------------------------------------------------------------------------
-- Standalone combat timer (retail "Standalone Combat Timer")
---------------------------------------------------------------------------
local timerFrameSA

local function TimerDuration()
	return CombatTime(Engine().GetCurrent())
end

function DM.UpdateTimerText()
	if not timerFrameSA or not timerFrameSA:IsShown() then return end
	local c = DB()
	local dur = TimerDuration()
	if dur <= 0.1 and not previewOn and not unlockOn then dur = 0 end
	if previewOn and dur <= 0.1 then dur = 83.4 end
	local text
	if c.standaloneTimerDecimal then
		text = format("%d:%04.1f", floor(dur / 60), dur % 60)
	else
		text = FormatTimer(dur)
	end
	timerFrameSA.text:SetText(text)
	local r, g, b
	if c.standaloneTimerUseAccent then r, g, b = Accent() else r, g, b = RGB(c.standaloneTimerColor, 1, 1, 1) end
	if c.standaloneTimerDesatOOC and not DM.InCombat() and not previewOn then
		local v = (r + g + b) / 3
		r, g, b = v * 0.6, v * 0.6, v * 0.6
	end
	timerFrameSA.text:SetTextColor(r, g, b, 1)
end

local function TimerAlign(c)
	local a = c.standaloneTimerTextAlign
	if a then return a end
	local anchor = c.standaloneTimerAnchor or "free"
	if anchor == "free" then return "CENTER" end
	return c.standaloneTimerAlignLeft and "LEFT" or "RIGHT"
end

function DM.LayoutTimerFrame()
	local c = DB()
	if not c.standaloneTimer then
		if timerFrameSA then timerFrameSA:Hide() end
		return
	end
	if not timerFrameSA then
		local f = CreateFrame("Frame", "EllesmereUIDMCombatTimer", UIParent)
		f:SetClampedToScreen(true)
		f:SetMovable(true)
		f:EnableMouse(true)
		f.bg = f:CreateTexture(nil, "BACKGROUND")
		f.bg:SetAllPoints()
		f.edges = MakeEdges(f, "BORDER")
		f.text = f:CreateFontString(nil, "OVERLAY")
		f:SetScript("OnMouseDown", function(self, button)
			local cc = DB()
			if button == "LeftButton" and IsShiftKeyDown() and not cc.standaloneTimerLocked
				and (cc.standaloneTimerAnchor or "free") == "free" then
				self.moving = true
				self:StartMoving()
			end
		end)
		f:SetScript("OnMouseUp", function(self)
			if not self.moving then return end
			self.moving = false
			self:StopMovingOrSizing()
			local x, y = self:GetCenter()
			local ux, uy = UIParent:GetCenter()
			DB().standaloneTimerPos = { point = "CENTER", relPoint = "CENTER", x = floor(x - ux + 0.5), y = floor(y - uy + 0.5) }
			DM.LayoutTimerFrame()
		end)
		timerFrameSA = f
	end
	local f = timerFrameSA
	f:SetFrameStrata(c.standaloneTimerStrata or "HIGH")
	f:SetSize(c.standaloneTimerWidth or 70, c.standaloneTimerHeight or 32)
	local bgc = c.standaloneTimerBackgroundColor or {}
	Solid(f.bg, bgc.r, bgc.g, bgc.b, bgc.a or 0)
	local bc = c.standaloneTimerBorderColor or {}
	PaintEdges(f.edges, f, c.standaloneTimerBorderSize or 0, bc.r, bc.g, bc.b, bc.a or 1)
	local outline = c.standaloneTimerOutline
	local flags = nil
	if outline == "NONE" then flags = "" elseif outline == "OUTLINE" or outline == "THICKOUTLINE" then flags = outline end
	SetDMFont(f.text, c.standaloneTimerSize or 26, flags)
	local align = TimerAlign(c)
	f.text:ClearAllPoints()
	f.text:SetPoint(align, f, align, 0, 0)
	f.text:SetJustifyH(align)
	f:EnableMouse(not c.standaloneTimerLocked)
	f:ClearAllPoints()
	local anchor = c.standaloneTimerAnchor or "free"
	local w1 = windows[1]
	if anchor ~= "free" and w1 then
		local map = {
			topleft = { "BOTTOMLEFT", "TOPLEFT" }, topright = { "BOTTOMRIGHT", "TOPRIGHT" },
			bottomleft = { "TOPLEFT", "BOTTOMLEFT" }, bottomright = { "TOPRIGHT", "BOTTOMRIGHT" },
		}
		local m = map[anchor] or map.topright
		f:SetPoint(m[1], w1.frame, m[2], 0, 0)
	else
		local p = c.standaloneTimerPos
		if type(p) == "table" and p.point then
			f:SetPoint(p.point, UIParent, p.relPoint or p.point, p.x or 0, p.y or 0)
		else
			f:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
		end
	end
	DM.UpdateTimerFrame()
end

function DM.UpdateTimerFrame()
	if not timerFrameSA then return end
	local c = DB()
	local show = c.standaloneTimer and true or false
	if show and not previewOn and not unlockOn then
		if toggleHidden and c.toggleIncludeTimer then
			show = false
		elseif not DM.InCombat() and not c.standaloneTimerShowOOC then
			show = false
		end
	end
	if show then timerFrameSA:Show() else timerFrameSA:Hide() end
	DM.UpdateTimerText()
end

---------------------------------------------------------------------------
-- Keybinds (retail Reset Data Keybind, Show/Hide Windows Keybind)
---------------------------------------------------------------------------
local bindOwner = CreateFrame("Frame")
local resetKeyBtn = CreateFrame("Button", "EllesmereUIDMResetKeyButton", UIParent)
resetKeyBtn:SetScript("OnClick", function() DM.ResetData() end)
local toggleKeyBtn = CreateFrame("Button", "EllesmereUIDMToggleKeyButton", UIParent)
toggleKeyBtn:SetScript("OnClick", function() DM.ToggleWindows() end)
local bindPending = false
local bindWait = CreateFrame("Frame")
bindWait:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	bindPending = false
	DM.ApplyKeybinds()
end)

function DM.ApplyKeybinds()
	if InCombatLockdown() then
		if not bindPending then
			bindPending = true
			bindWait:RegisterEvent("PLAYER_REGEN_ENABLED")
		end
		return
	end
	local c = DB()
	ClearOverrideBindings(bindOwner)
	if type(c.resetDataKey) == "string" and c.resetDataKey ~= "" then
		SetOverrideBindingClick(bindOwner, false, c.resetDataKey, "EllesmereUIDMResetKeyButton")
	end
	if type(c.toggleWindowsKey) == "string" and c.toggleWindowsKey ~= "" then
		SetOverrideBindingClick(bindOwner, false, c.toggleWindowsKey, "EllesmereUIDMToggleKeyButton")
	end
end

function DM.ToggleWindows()
	toggleHidden = not toggleHidden
	DM.UpdateVisibility()
	if DB().toggleIncludeSpellHistory and ns.SetSpellHistoryHidden then
		ns.SetSpellHistoryHidden(toggleHidden)
	end
end

---------------------------------------------------------------------------
-- Refresh driver: every refreshRate seconds in combat, on engine events
-- and on demand out of combat.
---------------------------------------------------------------------------
local driver = CreateFrame("Frame")
local acc, timerAcc = 0, 0
local dirty = false

function DM.RefreshAll()
	for _, W in ipairs(windows) do W.Refresh() end
	DM.UpdateTimerText()
end

function DM.MarkDirty()
	dirty = true
end

driver:SetScript("OnUpdate", function(_, elapsed)
	if not loaded then return end
	acc = acc + elapsed
	timerAcc = timerAcc + elapsed
	local rate = max(REFRESH_FLOOR, DB().refreshRate or 1)
	local inCombat = DM.InCombat()
	if (inCombat and acc >= rate) or (dirty and acc >= 0.1) then
		acc = 0
		dirty = false
		DM.RefreshAll()
	end
	if timerAcc >= 0.1 then
		timerAcc = 0
		if inCombat or previewOn then DM.UpdateTimerText() end
		if inCombat then
			for _, W in ipairs(windows) do W.UpdateTimerText() end
		end
	end
end)

local function OnCombatStart()
	for _, w in ipairs(windows) do
		if WinDB(w.idx).autoCurrentOnCombat then
			w.curSessionID = nil
			w.curSession = S.Current
			WinDB(w.idx).curSession = S.Current
		end
		if not w.curSessionID and w.source then w.CloseSource() end
	end
	DM.UpdateVisibility()
	DM.MarkDirty()
end

-- Engine notifications: fight start / end, data reset, old fights dropped.
ns.EDMEngine.Listen(function(what)
	if not loaded then return end
	if what == "start" then
		OnCombatStart()
	elseif what == "stop" then
		DM.UpdateVisibility()
		DM.MarkDirty()
	elseif what == "reset" then
		for _, w in ipairs(windows) do
			w.curSessionID = nil
			if w.source then w.CloseSource() end
		end
		DM.MarkDirty()
	elseif what == "removed" then
		-- A removed segment that a window shows falls back to Current.
		local keep = {}
		for _, seg in ipairs(Engine().GetSegments()) do keep[seg] = true end
		for _, w in ipairs(windows) do
			if w.curSessionID and not keep[w.curSessionID] then
				w.curSessionID = nil
				if w.source then w.CloseSource() end
			end
		end
		DM.MarkDirty()
	else
		DM.MarkDirty()
	end
end)

-- Challenge Mode start / end (retail M+ keystone start / completion).
local function IsChallengeMode()
	local _, _, difficulty = GetInstanceInfo()
	return difficulty == 8
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("WORLD_STATE_TIMER_START")
events:RegisterEvent("CHALLENGE_MODE_COMPLETED")
events:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == addonName then
			DB()
		end
		return
	elseif event == "PLAYER_LOGIN" then
		DM.Build()
		DM.ApplyKeybinds()
		return
	end
	if not loaded then return end
	if event == "PLAYER_REGEN_DISABLED" then
		OnCombatStart()
	elseif event == "PLAYER_REGEN_ENABLED" then
		DM.UpdateVisibility()
		DM.MarkDirty()
	elseif event == "WORLD_STATE_TIMER_START" then
		if IsChallengeMode() then
			for _, w in ipairs(windows) do
				local w2 = WinDB(w.idx)
				if w2.autoSwapMythic and w.curSession == S.Overall then
					w.curSession = S.Current
					w2.curSession = S.Current
					w.curSessionID = nil
				end
				if w2.mythicStartDMType and TYPE_NAMES[w2.mythicStartDMType] then
					w.HideHome()
					w.SetDMType(w2.mythicStartDMType)
				end
			end
			DM.MarkDirty()
		end
	elseif event == "CHALLENGE_MODE_COMPLETED" then
		for _, w in ipairs(windows) do
			local w2 = WinDB(w.idx)
			if w2.autoSwapMythic and not w.curSessionID and w.curSession == S.Current then
				w.curSession = S.Overall
				w2.curSession = S.Overall
			end
		end
		DM.MarkDirty()
	else
		DM.UpdateVisibility()
		DM.MarkDirty()
	end
end)

---------------------------------------------------------------------------
-- Build / apply
---------------------------------------------------------------------------
function DM.Build()
	local c = DB()
	local n = max(1, min(MAX_WINDOWS, c.windowCount or 1))
	for i = 1, n do
		if not windows[i] then windows[i] = CreateDMWindow(i) end
	end
	loaded = true
	DM.RegisterUnlock()
	DM.LayoutTimerFrame()
	DM.UpdateVisibility()
	DM.RefreshAll()
end

-- Rebuilds every window (window removed, profile change, settings reset).
function DM.Rebuild()
	for i = #windows, 1, -1 do
		windows[i].Destroy()
		windows[i] = nil
	end
	DM.Build()
end

function DM.Apply()
	if not loaded then return end
	local c = DB()
	local n = max(1, min(MAX_WINDOWS, c.windowCount or 1))
	if n ~= #windows then
		DM.Rebuild()
		return
	end
	for _, W in ipairs(windows) do
		local wdb = WinDB(W.idx)
		W.frame:SetSize(max(MIN_W, wdb.width or 300), max(MIN_H, wdb.height or 200))
		W.Layout()
	end
	DM.LayoutTimerFrame()
	DM.UpdateVisibility()
	DM.ApplyKeybinds()
	DM.RegisterUnlock()
	DM.RefreshAll()
end

ns.applyHooks = ns.applyHooks or {}
tinsert(ns.applyHooks, function() DM.Apply() end)

ns.accentListeners = ns.accentListeners or {}
tinsert(ns.accentListeners, function()
	if loaded then DM.Apply() end
end)

-- Settings page open: show every window (retail options preview).
function DM.SetPreview(on)
	on = on and true or false
	if previewOn == on then return end
	previewOn = on
	DM.UpdateVisibility()
	DM.UpdateTimerFrame()
	DM.RefreshAll()
end

-- Module reset (positions, sizes and bookmarks of the windows are kept).
function DM.Reset()
	local c = DB()
	local keep = {
		windows = c.windows, windowCount = c.windowCount, bookmarks = c.bookmarks,
		standaloneTimerPos = c.standaloneTimerPos, _seeded = c._seeded,
	}
	for k in pairs(c) do c[k] = nil end
	for k, v in pairs(keep) do c[k] = v end
	CopyDefaults(CreateDefaults(), c)
	DM.Apply()
end

---------------------------------------------------------------------------
-- Unlock Mode: EDM_Win1..N (retail keys) and EDM_CombatTimer.
---------------------------------------------------------------------------
local function WinOf(key)
	local i = tonumber((key or ""):match("(%d+)$"))
	return i and windows[i], i
end

function DM.RegisterUnlock()
	if not (ns.RegisterUnlockElements and ns.MakeUnlockElement) then return end
	local MK = ns.MakeUnlockElement
	local list = {}
	for i = 1, #windows do
		list[#list + 1] = MK({
			key = "EDM_Win" .. i,
			label = "Damage Meter " .. i,
			group = "Damage Meters",
			order = 650 + i,
			getFrame = function(key) local w = WinOf(key); return w and w.frame end,
			getSize = function(key)
				local w, idx = WinOf(key)
				if w then return w.frame:GetWidth(), w.frame:GetHeight() end
				local wdb = idx and WinDB(idx)
				return wdb and wdb.width or 375, wdb and wdb.height or 150
			end,
			setWidth = function(key, v)
				local w, idx = WinOf(key)
				if not w then return end
				v = max(MIN_W, floor((v or MIN_W) + 0.5))
				w.frame:SetWidth(v)
				WinDB(idx).width = v
				w.Layout()
			end,
			setHeight = function(key, v)
				local w, idx = WinOf(key)
				if not w then return end
				v = max(MIN_H, floor((v or MIN_H) + 0.5))
				w.frame:SetHeight(v)
				WinDB(idx).height = v
			end,
			savePos = function(key, point, relPoint, x, y)
				local w, idx = WinOf(key)
				if not idx then return end
				WinDB(idx).position = { point = point, relPoint = relPoint or point, x = x, y = y }
				if w and not ns._unlockActive then w.ApplyPosition() end
			end,
			loadPos = function(key)
				local _, idx = WinOf(key)
				local pos = idx and WinDB(idx).position
				if type(pos) ~= "table" then return nil end
				if pos.point then return { point = pos.point, relPoint = pos.relPoint, x = pos.x, y = pos.y } end
				if pos.x and pos.y then return { point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = pos.x, y = pos.y } end
				return nil
			end,
			clearPos = function(key)
				local _, idx = WinOf(key)
				if idx then WinDB(idx).position = nil end
			end,
			applyPos = function(key)
				local w = WinOf(key)
				if w then w.ApplyPosition() end
			end,
		})
	end
	local c = DB()
	if c.standaloneTimer and (c.standaloneTimerAnchor or "free") == "free" then
		list[#list + 1] = MK({
			key = "EDM_CombatTimer",
			label = "Combat Timer",
			group = "Damage Meters",
			order = 660,
			noResize = true,
			getFrame = function()
				if not timerFrameSA then DM.LayoutTimerFrame() end
				return timerFrameSA
			end,
			getSize = function()
				local cc = DB()
				return cc.standaloneTimerWidth or 70, cc.standaloneTimerHeight or 32
			end,
			savePos = function(_, point, relPoint, x, y)
				DB().standaloneTimerPos = { point = point, relPoint = relPoint or point, x = x, y = y }
				if not ns._unlockActive then DM.LayoutTimerFrame() end
			end,
			loadPos = function()
				local p = DB().standaloneTimerPos
				if type(p) ~= "table" or not p.point then return nil end
				return { point = p.point, relPoint = p.relPoint, x = p.x, y = p.y }
			end,
			clearPos = function() DB().standaloneTimerPos = nil end,
			applyPos = function() DM.LayoutTimerFrame() end,
		})
	end
	ns:RegisterUnlockElements(list, "EllesmereUIDamageMeters")
	if ns.UnregisterUnlockElement then
		for i = #windows + 1, MAX_WINDOWS do ns:UnregisterUnlockElement("EDM_Win" .. i) end
		if not (c.standaloneTimer and (c.standaloneTimerAnchor or "free") == "free") then
			ns:UnregisterUnlockElement("EDM_CombatTimer")
		end
	end
end

if ns.RegisterUnlockModeListener then
	ns:RegisterUnlockModeListener("EllesmereUIDamageMeters_Meter", function(on)
		unlockOn = on and true or false
		DM.UpdateVisibility()
		DM.UpdateTimerFrame()
	end)
end

---------------------------------------------------------------------------
-- Retail profile import: the retail converter (EllesmereUI_ProfilesRetail)
-- carries only the spell history. Wrapped here so it also brings the meter
-- settings (profile.addons.EllesmereUIDamageMeters.dm, minus spellHistory).
---------------------------------------------------------------------------
do
	local R = ns.ProfileRetail
	if R and R.CONVERT then
		local orig = R.CONVERT.EllesmereUIDamageMeters
		R.CONVERT.EllesmereUIDamageMeters = function(blob, notes, ...)
			local out = orig and orig(blob, notes, ...) or nil
			local src = type(blob) == "table" and blob.dm
			if type(src) ~= "table" then return out end
			if type(out) ~= "table" then
				out = DeepCopy(_G.EllesmereUIDamageMetersDB or {})
			end
			local copy = DeepCopy(src)
			copy.spellHistory = nil
			copy._seeded = 1
			out.dm = copy
			if notes then
				notes[#notes + 1] = "Damage Meters: meter windows and settings come from the retail profile."
			end
			return out
		end
	end
end
