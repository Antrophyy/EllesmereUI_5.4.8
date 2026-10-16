-- EllesmereUI Unit Frames for 5.4.8: settings, media and shared helpers.
-- The settings use the same keys as EllesmereUI (EllesmereUIUnitFramesDB
-- profile), stored in EllesmereUIUnitFramesDB (one profile, no profile
-- layer). Only the 5.4.8 API is used:
-- no C_Timer, no SetColorTexture, no masks, no atlases, no secret values.

local addonName = ...
local ns = EllesmereUI

local UF = {}
ns.UF = UF

local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local format, type, pairs = format, type, pairs

UF.MEDIA = "Interface\\AddOns\\" .. addonName .. "\\media\\"
UF.FONT = ns.FONT
UF.FONT_FALLBACK = "Fonts\\ARIALN.TTF"
UF.WHITE = "Interface\\Buttons\\WHITE8X8"

-- Units with a settings table, in EllesmereUI order.
UF.MAIN_UNITS = { "player", "target", "focus" }
UF.MINI_UNITS = { "targettarget", "focustarget", "pet" }
UF.UNIT_LABELS = {
	player = "Player", target = "Target", focus = "Focus",
	targettarget = "Target of Target", focustarget = "Focus Target", pet = "Pet", boss = "Boss",
}
UF.MAX_BOSS = MAX_BOSS_FRAMES or 5

---------------------------------------------------------------------------
-- Defaults (EllesmereUIUnitFrames.lua defaults, the keys this port uses)
---------------------------------------------------------------------------
local function RGB(r, g, b) return { r = r, g = g, b = b } end

-- Settings every main frame (player, target, focus) shares.
local function MainFrameDefaults(width, height, side)
	return {
		frameWidth = width, healthHeight = height,
		powerHeight = 6, powerPosition = "below", powerWidth = 0, powerX = 0, powerY = -4,
		powerPercentText = "none", powerTextFormat = "perpp", powerShowPercent = true,
		powerPercentSize = 9, powerPercentX = 0, powerPercentY = 0,
		powerPercentPowerColor = true, powerBgPowerColored = false, powerPercentTextPowerColor = false,
		powerBarOpacity = 100, powerReverseFill = false,
		healthClassColored = true, customBgColor = RGB(0.067, 0.067, 0.067), bgClassColored = false,
		healthBarOpacity = 90, healthReverseFill = false, healthVerticalFill = false, smoothBars = false,
		showBuffs = false, buffAnchor = "topleft", buffGrowth = "auto", maxBuffs = 4,
		buffSize = 22, buffOffsetX = 0, buffOffsetY = 0,
		buffShowCooldownText = false, buffCooldownTextSize = 10,
		debuffAnchor = "bottomleft", debuffGrowth = "auto", maxDebuffs = 10,
		debuffSize = 22, debuffOffsetX = 0, debuffOffsetY = 0,
		debuffShowCooldownText = false, debuffCooldownTextSize = 10,
		auraBorderSize = 1, auraBorderR = 0, auraBorderG = 0, auraBorderB = 0, auraBorderA = 1,
		leftTextContent = "name", rightTextContent = "both", centerTextContent = "none", extraTextContent = "none",
		leftTextSize = 12, leftTextX = 0, leftTextY = 0, leftTextClassColor = false,
		rightTextSize = 12, rightTextX = 0, rightTextY = 0, rightTextClassColor = false,
		centerTextSize = 12, centerTextX = 0, centerTextY = 0, centerTextClassColor = false,
		extraTextSize = 12, extraTextX = 0, extraTextY = 0, extraTextClassColor = false, extraTextAlign = "left",
		bottomTextBar = false, bottomTextBarHeight = 16, btbPosition = "bottom", btbWidth = 0, btbX = 0, btbY = 0,
		btbBgColor = RGB(0.2, 0.2, 0.2), btbBgOpacity = 1.0,
		btbLeftContent = "none", btbLeftSize = 11, btbLeftX = 0, btbLeftY = 0, btbLeftClassColor = false, btbLeftPowerColor = false,
		btbRightContent = "none", btbRightSize = 11, btbRightX = 0, btbRightY = 0, btbRightClassColor = false, btbRightPowerColor = false,
		btbCenterContent = "none", btbCenterSize = 11, btbCenterX = 0, btbCenterY = 0, btbCenterClassColor = false, btbCenterPowerColor = false,
		btbClassIcon = "none", btbClassIconSize = 14, btbClassIconLocation = "left", btbClassIconX = 0, btbClassIconY = 0,
		showPortrait = true, portraitStyle = "attached", portraitMode = "2d", portraitNonPlayer = "2d",
		classThemeStyle = "modern", portraitSide = side, portraitSize = 0, portraitX = 0, portraitY = 0,
		portraitMirror = false,
		detachedPortraitShape = "portrait", detachedPortraitBorderColor = RGB(0, 0, 0),
		detachedPortraitClassColor = true, detachedPortraitBorderOpacity = 100, detachedPortraitBorderSize = 7,
		showPlayerAbsorb = "none", absorbCleanAlpha = 30,
		absorbBarPosition = "none", absorbBarHeight = 4, absorbBarColor = RGB(1, 1, 1),
		healAbsorbBarPosition = "none", healAbsorbBarHeight = 4, healAbsorbBarColor = RGB(200 / 255, 29 / 255, 29 / 255),
		absorbGlowLine = false,
		castSpellNameSize = 11, castSpellNameColor = RGB(1, 1, 1), castSpellNameX = 0, castSpellNameY = 0,
		castDurationSize = 10, castDurationColor = RGB(1, 1, 1), castDurationX = 0, castDurationY = 0,
		castSpellTargetSize = 11, castSpellTargetColor = RGB(1, 1, 1), castSpellTargetX = 0, castSpellTargetY = 0,
		showCastDuration = true, showCastTarget = true,
		castbarFillColor = RGB(0.863, 0.820, 0.639), castbarClassColored = false,
		castReverseFill = false, castFillOpacity = 100, castbarHideWhenInactive = true,
		castBorderCustom = false, castBorderSize = 1, castBorderColor = RGB(0, 0, 0), castBorderAlpha = 1,
		borderSize = 1, borderColor = RGB(0, 0, 0), borderTexture = "solid", highlightColor = RGB(1, 1, 1),
		textSize = 12,
		showInRaid = true, showInParty = true, showSolo = true, barVisibility = "always",
		showWhenHealthMissing = false, oocFadeEnabled = false, oocAlpha = 0.5,
		raidMarkerEnabled = false, raidMarkerSize = 28, raidMarkerAlign = "right", raidMarkerX = 0, raidMarkerY = 0,
	}
end

local function MiniFrameDefaults()
	return {
		frameWidth = 101, healthHeight = 25,
		healthClassColored = false, customBgColor = RGB(0.067, 0.067, 0.067), bgClassColored = false,
		showPortrait = false, portraitSide = "left", portraitMode = "2d", portraitNonPlayer = "2d",
		healthBarOpacity = 90, textSize = 12,
		leftTextContent = "name", leftTextClassColor = false, leftTextColorR = 1, leftTextColorG = 1, leftTextColorB = 1,
		leftTextX = 0, leftTextY = 0,
		rightTextContent = "none", rightTextClassColor = false, rightTextColorR = 1, rightTextColorG = 1, rightTextColorB = 1,
		rightTextX = 0, rightTextY = 0,
		centerTextContent = "none", centerTextClassColor = false, centerTextColorR = 1, centerTextColorG = 1, centerTextColorB = 1,
		centerTextX = 0, centerTextY = 0,
		borderSize = 1, borderColor = RGB(0, 0, 0), borderTexture = "solid", highlightColor = RGB(1, 1, 1),
		powerPosition = "none", powerHeight = 6, powerWidth = 0, powerX = 0, powerY = -4,
		powerPercentText = "none", powerTextFormat = "perpp", powerShowPercent = true,
		powerPercentSize = 9, powerPercentX = 0, powerPercentY = 0,
		powerPercentPowerColor = true, powerBgPowerColored = false, powerPercentTextPowerColor = false,
		powerBarOpacity = 100, powerReverseFill = false,
		healthReverseFill = false, healthVerticalFill = false, smoothBars = false,
	}
end

local function Defaults()
	local player = MainFrameDefaults(181, 46, "left")
	player.showBuffs = false
	player.debuffAnchor = "none"
	player.debuffDispelUsePalette = false
	player.showPlayerCastbar = false
	player.showPlayerCastIcon = true
	player.playerCastbarIconInWidth = true
	player.lockCastbarToFrame = true
	player.playerCastbarX = 0
	player.playerCastbarY = 0
	player.playerCastbarWidth = 181
	player.playerCastbarHeight = 14
	player.showCastTarget = false
	player.playerCastbarIconOnPortrait = false
	player.showClassPowerBar = false
	player.lockClassPowerToFrame = true
	player.classPowerStyle = "none"
	player.classPowerPosition = "top"
	player.classPowerBarX = 0
	player.classPowerBarY = 0
	player.classPowerSize = 8
	player.classPowerSpacing = 2
	player.classPowerClassColor = true
	player.classPowerCustomColor = RGB(1, 0.82, 0)
	player.classPowerBgColor = { r = 0.082, g = 0.082, b = 0.082, a = 1 }
	player.classPowerEmptyColor = { r = 0.2, g = 0.2, b = 0.2, a = 1 }
	player.combatIndicatorStyle = "class"
	player.combatIndicatorColor = "custom"
	player.combatIndicatorCustomColor = RGB(1, 1, 1)
	player.combatIndicatorPosition = "healthbar"
	player.combatIndicatorSize = 22
	player.combatIndicatorX = 0
	player.combatIndicatorY = 0
	player.leaderIndicatorEnabled = true
	player.leaderIndicatorSize = 16
	player.leaderIndicatorPosition = "topleft"
	player.leaderIndicatorX = 0
	player.leaderIndicatorY = 0
	player.leaderIndicatorStyle = "blizzard"
	player.factionIndicatorMode = "off"
	player.factionIndicatorStyle = "classic"
	player.factionIndicatorPvP = "only"
	player.factionIndicatorSize = 18
	player.factionIndicatorPosition = "topright"
	player.factionIndicatorX = 0
	player.factionIndicatorY = 0

	local target = MainFrameDefaults(181, 46, "right")
	target.showBuffs = true
	target.onlyPlayerDebuffs = false
	target.maxDebuffs = 20
	target.castbarHeight = 14
	target.castbarWidth = 181
	target.showCastbar = true
	target.showCastIcon = true
	target.castbarIconInWidth = true
	target.castCombineNameTarget = false
	target.castbarInterruptReadyColor = RGB(0.92, 0.35, 0.20)
	target.castbarKickTickEnabled = true
	target.castbarInterruptMidCastEnabled = false
	target.castbarInterruptMidCastColor = RGB(0.318, 0.820, 0.357)
	target.castbarUninterruptibleColor = RGB(0.5, 0.5, 0.5)
	target.castbarIconOnPortrait = false
	target.combatIndicatorStyle = "none"
	target.combatIndicatorColor = "custom"
	target.combatIndicatorCustomColor = RGB(1, 1, 1)
	target.combatIndicatorPosition = "healthbar"
	target.combatIndicatorSize = 22
	target.combatIndicatorX = 0
	target.combatIndicatorY = 0
	target.leaderIndicatorEnabled = true
	target.leaderIndicatorSize = 16
	target.leaderIndicatorPosition = "topleft"
	target.leaderIndicatorX = 0
	target.leaderIndicatorY = 0
	target.leaderIndicatorStyle = "blizzard"
	target.eliteIndicatorEnabled = false
	target.eliteIndicatorSize = 16
	target.eliteIndicatorPosition = "topleft"
	target.eliteIndicatorX = 0
	target.eliteIndicatorY = 0
	target.eliteIndicatorShowInInstances = false
	target.factionIndicatorMode = "off"
	target.factionIndicatorStyle = "classic"
	target.factionIndicatorPlayersOnly = false
	target.factionIndicatorPvP = "dim"
	target.factionIndicatorSize = 18
	target.factionIndicatorPosition = "topright"
	target.factionIndicatorX = 0
	target.factionIndicatorY = 0

	local focus = MainFrameDefaults(160, 34, "right")
	focus.rightTextContent = "perhp"
	focus.onlyPlayerDebuffs = true
	focus.castbarHeight = 14
	focus.castbarWidth = 160
	focus.showCastbar = true
	focus.showCastIcon = true
	focus.castbarIconInWidth = true
	focus.castCombineNameTarget = false
	focus.castbarInterruptReadyColor = RGB(0.92, 0.35, 0.20)
	focus.castbarKickTickEnabled = true
	focus.castbarInterruptMidCastEnabled = false
	focus.castbarInterruptMidCastColor = RGB(0.318, 0.820, 0.357)
	focus.castbarUninterruptibleColor = RGB(0.5, 0.5, 0.5)
	focus.castbarIconOnPortrait = false

	local pet = MiniFrameDefaults()
	-- MoP pets have power (hunter focus, warlock demon energy / mana).
	pet.powerPosition = "below"

	local boss = MiniFrameDefaults()
	boss.frameWidth = 160
	boss.healthHeight = 34
	boss.oorAlpha = 0.4
	boss.powerPosition = "below"
	boss.healthClassColored = true
	boss.portraitSide = "right"
	boss.castbarHeight = 14
	boss.castbarWidth = 0
	boss.castbarOffsetX = 0
	boss.castbarOffsetY = 0
	boss.showCastbar = true
	boss.showCastIcon = true
	boss.castbarIconInWidth = true
	boss.castReverseFill = false
	boss.castFillOpacity = 100
	boss.castbarHideWhenInactive = true
	boss.castSpellNameSize = 11
	boss.castSpellNameColor = RGB(1, 1, 1)
	boss.castDurationSize = 10
	boss.castDurationColor = RGB(1, 1, 1)
	boss.castSpellNameX = 0
	boss.castSpellNameY = 0
	boss.castSpellTargetSize = 11
	boss.castSpellTargetColor = RGB(1, 1, 1)
	boss.castSpellTargetX = 0
	boss.castSpellTargetY = 0
	boss.castDurationX = 0
	boss.castDurationY = 0
	boss.showCastDuration = true
	boss.showCastTarget = false
	boss.castbarFillColor = RGB(0.863, 0.820, 0.639)
	boss.castbarInterruptReadyColor = RGB(0.92, 0.35, 0.20)
	boss.castbarKickTickEnabled = true
	boss.castbarInterruptMidCastEnabled = false
	boss.castbarInterruptMidCastColor = RGB(0.318, 0.820, 0.357)
	boss.castbarUninterruptibleColor = RGB(0.5, 0.5, 0.5)
	boss.castBorderCustom = false
	boss.castBorderSize = 1
	boss.castBorderColor = RGB(0, 0, 0)
	boss.castBorderAlpha = 1
	boss.onlyPlayerDebuffs = true
	boss.debuffAnchor = "bottomleft"
	boss.debuffGrowth = "auto"
	boss.maxDebuffs = 10
	boss.showBuffs = false
	boss.buffAnchor = "topleft"
	boss.buffGrowth = "auto"
	boss.maxBuffs = 4
	boss.buffSize = 22
	boss.buffOffsetX = 0
	boss.buffOffsetY = 0
	boss.debuffSize = 22
	boss.debuffOffsetX = 0
	boss.debuffOffsetY = 0
	boss.buffShowCooldownText = false
	boss.buffCooldownTextSize = 10
	boss.buffCooldownTextColor = RGB(1, 1, 1)
	boss.buffStackTextColor = RGB(1, 1, 1)
	boss.debuffShowCooldownText = false
	boss.debuffCooldownTextSize = 10
	boss.debuffCooldownTextColor = RGB(1, 1, 1)
	boss.debuffStackTextColor = RGB(1, 1, 1)
	boss.simpleDebuffShowCooldownText = false
	boss.simpleDebuffCooldownTextSize = 14
	boss.simpleDebuffs = "left"
	boss.simpleBuffs = "none"
	boss.simpleBuffShowCooldownText = false
	boss.simpleBuffCooldownTextSize = 14
	boss.buffSpacing = 1
	boss.debuffSpacing = 1
	boss.simpleBuffSpacing = 1
	boss.simpleDebuffSpacing = 1
	boss.auraBorderSize = 1
	boss.auraBorderR, boss.auraBorderG, boss.auraBorderB, boss.auraBorderA = 0, 0, 0, 1
	boss.extraTextContent = "none"
	boss.extraTextSize = 12
	boss.extraTextClassColor = false
	boss.extraTextColorR, boss.extraTextColorG, boss.extraTextColorB = 1, 1, 1
	boss.extraTextX, boss.extraTextY = 0, 0
	boss.extraTextAlign = "left"
	boss.rightTextContent = "perhp"
	boss.borderCustom = false
	boss.bossHoverBorderEnabled = false
	boss.bossHoverBorderColor = RGB(1, 1, 1)
	boss.bossHoverBorderAlpha = 1
	boss.bossTargetBorderEnabled = false
	boss.bossTargetBorderColor = RGB(1, 1, 1)
	boss.bossTargetBorderAlpha = 1
	boss.raidMarkerEnabled = true
	boss.raidMarkerSize = 28
	boss.raidMarkerAlign = "left"
	boss.raidMarkerX = 0
	boss.raidMarkerY = 0
	boss.bossStackDirection = "down"

	return {
		castbarColor = RGB(0.114, 0.655, 0.514),
		healthBarTexture = "none",
		darkTheme = false,
		showDecimalOnText = false,
		showDecimalBoss2 = true,
		showDecimalPercentOnly = false,
		showDecimalTrimZeros = false,
		playerThreatBorderEnabled = false,
		playerThreatHasAggroColor = RGB(1.00, 0.50, 0.00),
		playerThreatNearAggroColor = RGB(0.81, 0.72, 0.19),
		threatPctEnabled = false,
		threatPctFocus = false,
		threatPctPosition = "CENTER",
		threatPctColorByThreat = true,
		threatPctSize = 12,
		threatPctXOffset = 0,
		threatPctYOffset = 0,
		enemyColors = {},
		player = player,
		target = target,
		focus = focus,
		targettarget = MiniFrameDefaults(),
		focustarget = MiniFrameDefaults(),
		pet = pet,
		boss = boss,
		enabledFrames = {
			player = true, target = true, focus = true, pet = true,
			targettarget = true, focustarget = false, boss = true,
		},
		frameSource = {},
		positions = {
			player = { point = "CENTER", relPoint = "CENTER", x = -317, y = -193.5 },
			target = { point = "CENTER", relPoint = "CENTER", x = 317, y = -201 },
			focus = { point = "CENTER", relPoint = "CENTER", x = 0, y = -285 },
			pet = { point = "CENTER", relPoint = "CENTER", x = -300, y = -260 },
			targettarget = { point = "CENTER", relPoint = "CENTER", x = 383, y = -152.5 },
			focustarget = { point = "CENTER", relPoint = "CENTER", x = 50, y = -261 },
			boss = { point = "CENTER", relPoint = "CENTER", x = 661, y = 251 },
			classPower = { point = "CENTER", relPoint = "CENTER", x = 0, y = -220 },
			playerCastbar = { point = "CENTER", relPoint = "CENTER", x = -317, y = -250 },
		},
		bossSpacing = 80,
		dispelOverlay = "none",
		dispelOverlayOpacity = 100,
		dispelOverlayByMe = false,
		dispelColorMagic = RGB(0.349, 0.475, 1.0),
		dispelColorCurse = RGB(0.636, 0.0, 0.64),
		dispelColorDisease = RGB(0.671, 0.384, 0.098),
		dispelColorPoison = RGB(0.0, 0.706, 0.286),
	}
end
UF.Defaults = Defaults

local function DeepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = DeepCopy(v)
	end
	return copy
end
UF.DeepCopy = DeepCopy

-- Fills missing keys; never overwrites saved values. Color tables and the
-- empty containers (enemyColors, frameSource) are merged as whole tables.
local function MergeDefaults(src, dst)
	for k, v in pairs(src) do
		if dst[k] == nil then
			dst[k] = DeepCopy(v)
		elseif type(v) == "table" and type(dst[k]) == "table" then
			MergeDefaults(v, dst[k])
		end
	end
end

-- Default saved position of an Unlock Mode key (a copy).
function UF.DefaultPosition(key)
	local p = Defaults().positions[key]
	return p and { point = p.point, relPoint = p.relPoint, x = p.x, y = p.y }
		or { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 }
end

function UF.InitDB()
	-- Before 3.1 the settings were EllesmereUIDB.unitFrames.
	local db = ns.ModuleDB("EllesmereUIUnitFramesDB", "unitFrames")
	MergeDefaults(Defaults(), db)
	UF.db = db
	return UF.db
end

-- Settings table of a unit key ("boss1".."boss5" share "boss").
function UF.Settings(unitKey)
	if unitKey and unitKey:match("^boss%d$") then
		unitKey = "boss"
	end
	return UF.db and UF.db[unitKey]
end

function UF.IsEnabled(unitKey)
	local db = UF.db
	if not db then
		return false
	end
	if db.enabledFrames[unitKey] == false then
		return false
	end
	return UF.FrameSource(unitKey) == "eui"
end

-- "eui" (EllesmereUI frame) or "blizzard" (keep Blizzard's frame).
function UF.FrameSource(unitKey)
	local source = UF.db and UF.db.frameSource[unitKey]
	if source == "blizzard" then
		return "blizzard"
	end
	return "eui"
end

---------------------------------------------------------------------------
-- Pixel perfect helpers (1 unit = 1 physical pixel at the frame's scale)
---------------------------------------------------------------------------
local physicalHeight
local function PhysicalHeight()
	if not physicalHeight then
		-- Shared with the core (windowed maximized has no gxResolution).
		physicalHeight = ns.PhysicalHeight()
	end
	return physicalHeight
end

-- Size of one physical pixel in UIParent units.
function UF.Pixel()
	local scale = UIParent:GetEffectiveScale()
	return 768 / PhysicalHeight() / scale
end

-- Rounds a UIParent-unit value to whole physical pixels.
function UF.Snap(value)
	local px = UF.Pixel()
	return floor(value / px + 0.5) * px
end

---------------------------------------------------------------------------
-- Fonts
---------------------------------------------------------------------------
-- Font and outline from Global Settings > Fonts (module key "unitFrames");
-- outline = true: icon text (Outline Icon Text).
function UF.SetFont(fs, size, outline)
	local face, flags = UF.FONT, outline and "OUTLINE" or ""
	if ns.GetFontPath then
		face = ns.GetFontPath("unitFrames")
		flags = outline and ns.GetIconTextOutlineFlag("unitFrames") or ns.GetFontOutlineFlag("unitFrames")
	end
	fs:SetFont(face, size, flags)
	if not fs:GetFont() then
		fs:SetFont(UF.FONT_FALLBACK, size, flags)
	end
	if flags ~= "" then
		fs:SetShadowOffset(0, 0)
	else
		-- EllesmereUI default "shadow" font mode.
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 1)
	end
end

function UF.NewText(parent, size, layer, outline)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	UF.SetFont(fs, size, outline)
	fs:SetTextColor(1, 1, 1, 1)
	fs:SetWordWrap(false)
	return fs
end

---------------------------------------------------------------------------
-- Colors (EllesmereUI values; differ a little from MoP RAID_CLASS_COLORS)
---------------------------------------------------------------------------
UF.CLASS_COLORS = {
	DEATHKNIGHT = { 0.77, 0.12, 0.23 }, DRUID = { 1.00, 0.49, 0.04 }, HUNTER = { 0.67, 0.83, 0.45 },
	MAGE = { 0.25, 0.78, 0.92 }, MONK = { 0.00, 1.00, 0.60 }, PALADIN = { 0.96, 0.55, 0.73 },
	PRIEST = { 1, 1, 1 }, ROGUE = { 1.00, 0.96, 0.41 }, SHAMAN = { 0.00, 0.44, 0.87 },
	WARLOCK = { 0.53, 0.53, 0.93 }, WARRIOR = { 0.78, 0.61, 0.43 },
}

UF.POWER_COLORS = {
	MANA = { 0, 0.55, 1 }, RAGE = { 0.9, 0.15, 0.15 }, FOCUS = { 0.867, 0.573, 0.216 },
	ENERGY = { 1, 0.96, 0.41 }, RUNIC_POWER = { 0.769, 0.122, 0.231 },
	CHI = { 0.71, 1, 0.92 }, HOLY_POWER = { 0.95, 0.9, 0.6 }, SOUL_SHARDS = { 0.5, 0.32, 0.55 },
	SHADOW_ORBS = { 0.5, 0.2, 0.8 }, BURNING_EMBERS = { 0.75, 0.31, 0.06 }, DEMONIC_FURY = { 0.6, 0.2, 0.8 },
	ECLIPSE = { 0.3, 0.52, 0.9 }, FUEL = { 0, 0.55, 0.5 },
}

-- Class resource pip colors (DEFAULT_RESOURCE_COLORS by class).
UF.RESOURCE_CLASS_COLORS = {
	ROGUE = { 1, 0.96, 0.41 }, DRUID = { 1, 0.49, 0.04 }, PALADIN = { 0.96, 0.55, 0.73 },
	MONK = { 0, 1, 0.6 }, WARLOCK = { 0.58, 0.51, 0.79 }, MAGE = { 0.25, 0.78, 0.92 },
	DEATHKNIGHT = { 0.77, 0.12, 0.23 }, PRIEST = { 0.5, 0.2, 0.8 }, SHAMAN = { 0, 0.44, 0.87 },
	HUNTER = { 0.67, 0.83, 0.45 }, WARRIOR = { 0.78, 0.61, 0.43 },
}

UF.RUNE_COLORS = {
	{ 1, 0, 0 },        -- blood
	{ 0, 0.5, 0 },      -- unholy
	{ 0, 1, 1 },        -- frost
	{ 0.9, 0.1, 1 },    -- death
}

UF.DISPEL_KEYS = { Magic = "dispelColorMagic", Curse = "dispelColorCurse", Disease = "dispelColorDisease", Poison = "dispelColorPoison" }

function UF.ClassColor(classToken)
	-- Global Settings > Colors (EllesmereUI_Colors.lua): custom + darken.
	if ns.GetClassColor and classToken and UF.CLASS_COLORS[classToken] then
		local cc = ns.GetClassColor(classToken)
		return cc.r, cc.g, cc.b
	end
	local c = classToken and UF.CLASS_COLORS[classToken]
	if c then
		return c[1], c[2], c[3]
	end
	local custom = CUSTOM_CLASS_COLORS and classToken and CUSTOM_CLASS_COLORS[classToken]
	if custom then
		return custom.r, custom.g, custom.b
	end
	return 1, 1, 1
end

function UF.PlayerClassColor()
	return UF.ClassColor(select(2, UnitClass("player")))
end

function UF.PowerColor(token, powerType)
	-- Global Settings > Colors (EllesmereUI_Colors.lua): custom + darken.
	local pc = ns.GetPowerColor and token and ns.GetPowerColor(token)
	if pc then
		return pc.r, pc.g, pc.b
	end
	local c = token and UF.POWER_COLORS[token]
	if c then
		return c[1], c[2], c[3]
	end
	local blizz = (token and PowerBarColor[token]) or (powerType and PowerBarColor[powerType])
	if blizz and blizz.r then
		return blizz.r, blizz.g, blizz.b
	end
	return 0, 0.55, 1
end

function UF.PlayerPowerColor()
	local _, token = UnitPowerType("player")
	return UF.PowerColor(token)
end

local REACTION_KEYS = { "hostile", "hostile", "hostile", "neutral", "friendly", "friendly", "friendly", "friendly" }
local REACTION_FALLBACK = {
	hostile = { 0.78, 0.25, 0.25, 2 }, neutral = { 0.85, 0.77, 0.36, 4 }, friendly = { 0.29, 0.68, 0.30, 5 },
}

-- Enemy Colors (Extras): custom hostile / neutral / friendly / tapped colors.
function UF.EnemyColor(key)
	local custom = UF.db and UF.db.enemyColors[key]
	if custom and custom.r then
		return custom.r, custom.g, custom.b
	end
	if key == "tapped" then
		return 0.6, 0.6, 0.6
	end
	local fb = REACTION_FALLBACK[key]
	local blizz = FACTION_BAR_COLORS and FACTION_BAR_COLORS[fb[4]]
	if blizz then
		return blizz.r, blizz.g, blizz.b
	end
	return fb[1], fb[2], fb[3]
end

function UF.IsTapped(unit)
	return not UnitPlayerControlled(unit) and UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit)
		and not UnitIsTappedByAllThreatList(unit)
end

-- Color of a unit as used for class colored names and fills:
-- players by class, tapped grey, NPCs by reaction.
function UF.UnitColor(unit)
	if not UnitExists(unit) then
		return 1, 1, 1
	end
	if UnitIsPlayer(unit) then
		return UF.ClassColor(select(2, UnitClass(unit)))
	end
	if UF.IsTapped(unit) then
		return UF.EnemyColor("tapped")
	end
	local reaction = UnitReaction(unit, "player")
	if reaction then
		return UF.EnemyColor(REACTION_KEYS[reaction] or "neutral")
	end
	return 0.192, 0.812, 0.145
end

function UF.Hex(r, g, b)
	return format("|cff%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

---------------------------------------------------------------------------
-- Numbers (5.4.8 has no AbbreviateNumbers)
---------------------------------------------------------------------------
local function Trunc(value, decimals)
	local m = 10 ^ decimals
	return floor(value * m) / m
end

-- EllesmereUI rules: 1.2K, 240K, 1.2M, 24M, 1.2B. With decimals on:
-- one decimal and lower case (240.5k); boss frames can use two.
function UF.Abbrev(value, decimals)
	value = value or 0
	local neg = value < 0
	value = abs(value)
	local text
	if decimals and decimals > 0 then
		local fmt = "%." .. decimals .. "f"
		if value >= 1e9 then
			text = format(fmt .. "b", Trunc(value / 1e9, decimals))
		elseif value >= 1e6 then
			text = format(fmt .. "m", Trunc(value / 1e6, decimals))
		elseif value >= 1e3 then
			text = format(fmt .. "k", Trunc(value / 1e3, decimals))
		else
			text = tostring(floor(value))
		end
	elseif value >= 1e10 then
		text = format("%dB", floor(value / 1e9))
	elseif value >= 1e9 then
		text = format("%.1fB", Trunc(value / 1e9, 1))
	elseif value >= 1e7 then
		text = format("%dM", floor(value / 1e6))
	elseif value >= 1e6 then
		text = format("%.1fM", Trunc(value / 1e6, 1))
	elseif value >= 1e4 then
		text = format("%dK", floor(value / 1e3))
	elseif value >= 1e3 then
		text = format("%.1fK", Trunc(value / 1e3, 1))
	else
		text = tostring(floor(value))
	end
	return neg and ("-" .. text) or text
end

---------------------------------------------------------------------------
-- Media lists (bar textures, absorb styles), LibSharedMedia appended
---------------------------------------------------------------------------
UF.BAR_TEXTURE_ORDER = {
	"none", "melli", "atrocity", "fade", "fade-right", "thin-line-top", "thin-line-bottom",
	"beautiful", "plating", "divide", "glass", "gradient-lr", "gradient-rl", "gradient-bt", "gradient-tb",
	"matte", "sheer", "pixels-fill", "pixels-dark", "pixels-bg", "blinkii-diamonds", "kringel-window",
}
UF.BAR_TEXTURE_NAMES = {
	none = "None", melli = "Melli (ElvUI)", beautiful = "Beautiful", plating = "Plating", atrocity = "Atrocity",
	divide = "Divide", glass = "Glass", ["fade-right"] = "Fade Right", ["thin-line-top"] = "Thin Line Top",
	["thin-line-bottom"] = "Thin Line Bottom", fade = "Fade", ["gradient-lr"] = "Gradient Right",
	["gradient-rl"] = "Gradient Left", ["gradient-bt"] = "Gradient Up", ["gradient-tb"] = "Gradient Down",
	matte = "Matte", sheer = "Sheer", ["pixels-fill"] = "Pixels Fill", ["pixels-dark"] = "Pixels Dark",
	["pixels-bg"] = "Pixels Background", ["blinkii-diamonds"] = "Blinkii Diamonds", ["kringel-window"] = "Kringel Window",
}

local function LSM()
	return LibStub and LibStub("LibSharedMedia-3.0", true)
end

-- Path of a bar texture key ("none" = flat, "sm:<name>" = SharedMedia).
function UF.BarTexturePath(key)
	if not key or key == "none" or key == "" then
		return UF.WHITE
	end
	if key:sub(1, 3) == "sm:" then
		local lsm = LSM()
		local path = lsm and lsm:Fetch("statusbar", key:sub(4), true)
		return path or UF.WHITE
	end
	if UF.BAR_TEXTURE_NAMES[key] then
		return UF.MEDIA .. "textures\\" .. key
	end
	return UF.WHITE
end

function UF.BarTextureLabel(key)
	if key and key:sub(1, 3) == "sm:" then
		return key:sub(4)
	end
	return UF.BAR_TEXTURE_NAMES[key or "none"] or "None"
end

-- Dropdown items { name, value } for bar textures (+ SharedMedia).
function UF.BarTextureItems(withInherit)
	local items = {}
	if withInherit then
		items[#items + 1] = { name = "Inherit (Main Frames)", value = "inherit" }
	end
	for _, key in ipairs(UF.BAR_TEXTURE_ORDER) do
		items[#items + 1] = { name = UF.BAR_TEXTURE_NAMES[key], value = key }
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

UF.ABSORB_STYLE_ORDER = {
	"none", "striped", "stripedReversed", "stripedThick", "stripedThickR", "clean", "blizzard",
	"largeStripes", "largeStripesR", "pixelsShield", "pixelsShieldEdge", "pixelsShieldFill",
}
UF.HEAL_ABSORB_STYLE_ORDER = {
	"none", "striped", "stripedReversed", "stripedThick", "stripedThickR", "clean", "blizzard",
	"largeOutlinedStripes", "largeOutlinedStripesR", "largeStripes", "largeStripesR", "pixelsShield",
}
UF.ABSORB_STYLE_NAMES = {
	none = "None", striped = "Striped", stripedReversed = "Striped Reversed", stripedThick = "Striped Thick",
	stripedThickR = "Striped Thick Reversed", clean = "Clean (Flat)", blizzard = "Blizzard",
	largeOutlinedStripes = "Large Outlined Stripes", largeOutlinedStripesR = "Large Outlined Stripes R",
	largeStripes = "Large Stripes", largeStripesR = "Large Stripes R", pixelsShield = "Pixels Shield",
	pixelsShieldEdge = "Pixels Shield Edge", pixelsShieldFill = "Pixels Shield Fill",
}
local ABSORB_FILES = {
	striped = "striped3", stripedReversed = "striped-5-reversed", stripedThick = "striped-thick",
	stripedThickR = "striped-thick-r", blizzard = "blizzard", largeOutlinedStripes = "large-habsorb-left",
	largeOutlinedStripesR = "large-habsorb-right", largeStripes = "large-absorb-left",
	largeStripesR = "large-absorb-right", pixelsShield = "pixels-shield", pixelsShieldEdge = "pixels-shield-edge",
	pixelsShieldFill = "pixels-shield-fill",
}
-- Styles drawn as repeating tiles (the others stretch).
UF.ABSORB_TILED = {
	stripedReversed = true, stripedThick = true, stripedThickR = true, largeStripes = true, largeStripesR = true,
	largeOutlinedStripes = true, largeOutlinedStripesR = true, pixelsShieldFill = true,
}
-- Styles with their own colors (the color swatch does not apply).
UF.ABSORB_PRECOLORED = { largeOutlinedStripes = true, largeOutlinedStripesR = true }

function UF.AbsorbTexture(style)
	if style == "clean" then
		return UF.WHITE
	end
	if style and style:sub(1, 3) == "sm:" then
		local lsm = LSM()
		return lsm and lsm:Fetch("statusbar", style:sub(4), true) or UF.WHITE
	end
	local file = style and ABSORB_FILES[style]
	if file then
		return UF.MEDIA .. "shields\\" .. file
	end
	return UF.WHITE
end

function UF.AbsorbItems(order)
	local items = {}
	for _, key in ipairs(order) do
		items[#items + 1] = { name = UF.ABSORB_STYLE_NAMES[key], value = key }
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

-- Class art (EllesmereUI class-full sprites, 8 x 8 cells).
UF.CLASS_STYLE_ORDER = { "modern", "arcade", "glyph", "legend", "midnight", "pixel", "pixelsComic", "runic" }
UF.CLASS_STYLE_NAMES = {
	modern = "Modern", arcade = "Arcade", glyph = "Glyph", legend = "Legend", midnight = "Midnight",
	pixel = "Pixel", pixelsComic = "Pixels Comic", runic = "Runic",
}
UF.CLASS_SPRITE = {
	WARRIOR = { 0, 0.125, 0, 0.125 }, MAGE = { 0.125, 0.25, 0, 0.125 }, ROGUE = { 0.25, 0.375, 0, 0.125 },
	DRUID = { 0.375, 0.5, 0, 0.125 }, HUNTER = { 0, 0.125, 0.125, 0.25 }, SHAMAN = { 0.125, 0.25, 0.125, 0.25 },
	PRIEST = { 0.25, 0.375, 0.125, 0.25 }, WARLOCK = { 0.375, 0.5, 0.125, 0.25 }, PALADIN = { 0, 0.125, 0.25, 0.375 },
	DEATHKNIGHT = { 0.125, 0.25, 0.25, 0.375 }, MONK = { 0.25, 0.375, 0.25, 0.375 },
}

function UF.ClassArtPath(style)
	if not UF.CLASS_STYLE_NAMES[style or ""] then
		style = "modern"
	end
	return UF.MEDIA .. "class\\" .. style
end

---------------------------------------------------------------------------
-- Timers (5.4.8 has no C_Timer)
---------------------------------------------------------------------------
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
	if #timers == 0 then
		self:Hide()
	end
end)

function UF.After(delay, fn)
	timers[#timers + 1] = { at = GetTime() + (delay or 0), fn = fn }
	timerFrame:Show()
end

---------------------------------------------------------------------------
-- Small widget helpers
---------------------------------------------------------------------------
function UF.Solid(parent, layer, r, g, b, a, sublevel)
	local tex = parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel)
	tex:SetTexture(UF.WHITE)
	tex:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
	return tex
end

-- Border of four textures drawn inside the frame edge (EllesmereUI "solid").
local BorderMethods = {}

function BorderMethods:SetBorderColor(r, g, b, a)
	for i = 1, 4 do
		self.edges[i]:SetVertexColor(r, g, b, a or 1)
	end
end

function BorderMethods:SetBorderSize(size)
	local e = self.edges
	local shown = size and size > 0
	self.size = shown and size or 0
	-- A border hidden with SetShown(false) stays hidden (the non-player
	-- threat border used to show up here, over the text).
	for i = 1, 4 do
		e[i]:SetShown(shown and self.visible ~= false)
	end
	if not shown then
		return
	end
	local host = self.host
	local inset = self.outside and -size or 0
	e[1]:ClearAllPoints()
	e[1]:SetPoint("TOPLEFT", host, "TOPLEFT", inset, -inset)
	e[1]:SetPoint("TOPRIGHT", host, "TOPRIGHT", -inset, -inset)
	e[1]:SetHeight(size)
	e[2]:ClearAllPoints()
	e[2]:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", inset, inset)
	e[2]:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -inset, inset)
	e[2]:SetHeight(size)
	e[3]:ClearAllPoints()
	e[3]:SetPoint("TOPLEFT", e[1], "BOTTOMLEFT")
	e[3]:SetPoint("BOTTOMLEFT", e[2], "TOPLEFT")
	e[3]:SetWidth(size)
	e[4]:ClearAllPoints()
	e[4]:SetPoint("TOPRIGHT", e[1], "BOTTOMRIGHT")
	e[4]:SetPoint("BOTTOMRIGHT", e[2], "TOPRIGHT")
	e[4]:SetWidth(size)
end

function BorderMethods:SetShown(on)
	self.visible = on and true or false
	on = self.visible and self.size ~= 0
	for i = 1, 4 do
		self.edges[i]:SetShown(on)
	end
end

-- host: the frame the border follows; parent: the frame that owns the
-- textures (its frame level decides what the border is drawn over).
function UF.CreateBorder(parent, host, outside)
	local border = { host = host or parent, outside = outside, edges = {} }
	for i = 1, 4 do
		border.edges[i] = UF.Solid(parent, "OVERLAY", 0, 0, 0, 1, 7)
	end
	for k, fn in pairs(BorderMethods) do
		border[k] = fn
	end
	return border
end

---------------------------------------------------------------------------
-- Hiding Blizzard frames (ElvUI / oUF pattern: unregister, hide, reparent)
---------------------------------------------------------------------------
local hiddenParent = CreateFrame("Frame", nil, UIParent)
hiddenParent:SetAllPoints()
hiddenParent:Hide()
UF.hiddenParent = hiddenParent

local function HideFrame(frame)
	if type(frame) == "string" then
		frame = _G[frame]
	end
	if not frame then
		return
	end
	frame:UnregisterAllEvents()
	frame:Hide()
	frame:SetParent(hiddenParent)
	for _, key in ipairs({ "healthbar", "manabar", "spellbar", "powerBarAlt" }) do
		if frame[key] and frame[key].UnregisterAllEvents then
			frame[key]:UnregisterAllEvents()
		end
	end
end
UF.HideFrame = HideFrame

local hiddenUnits = {}

function UF.HideBlizzard(unitKey)
	if hiddenUnits[unitKey] then
		return
	end
	hiddenUnits[unitKey] = true
	if unitKey == "player" then
		HideFrame(PlayerFrame)
		-- The vehicle UI still needs these on PlayerFrame.
		PlayerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
		PlayerFrame:RegisterEvent("UNIT_ENTERING_VEHICLE")
		PlayerFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
		PlayerFrame:RegisterEvent("UNIT_EXITING_VEHICLE")
		PlayerFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
		PlayerFrame:SetMovable(true)
		PlayerFrame:SetUserPlaced(true)
		PlayerFrame:SetDontSavePosition(true)
		if RuneFrame then
			RuneFrame:SetParent(PlayerFrame)
		end
	elseif unitKey == "pet" then
		HideFrame(PetFrame)
	elseif unitKey == "target" then
		HideFrame(TargetFrame)
		HideFrame(ComboFrame)
	elseif unitKey == "targettarget" then
		HideFrame(TargetFrameToT)
	elseif unitKey == "focus" then
		HideFrame(FocusFrame)
	elseif unitKey == "focustarget" then
		HideFrame(FocusFrameToT)
	elseif unitKey == "boss" then
		for i = 1, UF.MAX_BOSS do
			HideFrame("Boss" .. i .. "TargetFrame")
		end
	end
end

-- Blizzard's player (and pet) cast bar, like EllesmereUI ApplyBlizzCastbarState:
-- hidden only while the EUI player cast bar replaces it (EUI frame source and
-- "Show Player Cast Bar" on); otherwise Blizzard's bar stays. Hidden by
-- re-parenting, so its events (and other addons' hooks) are left alone.
local castbarHidden
function UF.ApplyBlizzCastbar()
	if InCombatLockdown() then
		UF.pendingReload = true
		return
	end
	local suppress = UF.db and UF.db.player and UF.db.player.showPlayerCastbar
		and UF.FrameSource("player") == "eui" and UF.db.enabledFrames.player ~= false
	suppress = suppress and true or false
	if suppress == castbarHidden then
		return
	end
	castbarHidden = suppress
	for _, bar in ipairs({ CastingBarFrame, PetCastingBarFrame }) do
		if bar then
			if suppress then
				bar.euiOrigParent = bar.euiOrigParent or bar:GetParent()
				bar:SetParent(hiddenParent)
			elseif bar.euiOrigParent then
				bar:SetParent(bar.euiOrigParent)
			end
		end
	end
end
