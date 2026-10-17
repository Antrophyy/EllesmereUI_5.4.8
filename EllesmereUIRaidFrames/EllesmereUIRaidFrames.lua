-------------------------------------------------------------------------------
--  EllesmereUIRaidFrames.lua  (5.4.8 port of the EllesmereUI Raid Frames,
--  retail 9.3.8)
--
--  Retail builds its frames on SecureGroupHeaderTemplate and draws auras with
--  the 12.1 aura containers, secret values and C_UnitAuras. 5.4.8 has the
--  group headers but none of the rest, so this is a rewrite that keeps the
--  retail saved keys, values, texts and data models (party overrides, raid
--  size tiers, Buff Manager v2, Debuff Manager tiles, click casting).
--
--  This file: the defaults (retail `defaults.profile`, same keys and values),
--  the saved settings (EllesmereUIRaidFramesDB.profile), the settings views
--  (party proxy, indicator scale proxies), and the helpers the other files
--  share (timers, pixel borders, fonts, textures, colors, roles, specs).
--
--  Files (all share the private table RF = the retail `ns`):
--    EllesmereUIRaidFrames.lua        this file
--    EUI_RaidFrames_Seed.lua          retail "Naowh" profile (first run)
--    EUI_RaidFrames_Button.lua        look of one unit button (bars, texts,
--                                     borders, indicators, range, dispels)
--    EUI_RaidFrames_Auras.lua         aura scan, debuffs, defensives, dispel
--    EUI_RaidFrames_BuffManager.lua   Buff Manager v2 indicators
--    EUI_RaidFrames_Headers.lua       secure headers, sort, layout, sizes,
--                                     visibility, Blizzard frames, unlock
--    EUI_RaidFrames_Extras.lua        friendly boss, extra frames, pets,
--                                     party targets, portrait, healer mana
--    EUI_RaidFrames_Preview.lua       fake members while the settings are open
--    EUI_RaidFrames_ClickCast.lua     click casting
--    EUI_RaidFrames_Init.lua          events, start-up, /erf
-------------------------------------------------------------------------------
local addonName, RF = ...
local ns = EllesmereUI

local ERF = {}
ns.ERF = ERF
ERF.RF = RF
RF.ERF = ERF
RF.ns = ns
_G.EllesmereUIRaidFrames = ERF

local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local pairs, ipairs, type = pairs, ipairs, type

RF.MEDIA = "Interface\\AddOns\\" .. addonName .. "\\media\\"
RF.WHITE = "Interface\\Buttons\\WHITE8X8"

-------------------------------------------------------------------------------
--  Frame-level bands (retail ns.LVL_*, offsets above the unit button level).
--  5.4.8 frame levels stop near 128: keep every offset small.
-------------------------------------------------------------------------------
RF.LVL_DISPEL_OVERLAY = 7
RF.LVL_RAISE = 10
RF.LVL_TEXT = 12
RF.LVL_AURA = 13
RF.LVL_MARKER = 26

-------------------------------------------------------------------------------
--  Defaults (retail EllesmereUIRaidFrames.lua `defaults`, same keys and
--  values; WoW Forever only keys left out, Level Text default = none)
-------------------------------------------------------------------------------
local DEFAULTS = {
	profile = {
		-- Size & layout
		frameWidth       = 125,
		frameHeight      = 60,
		cellSpacing      = -1,
		groupSpacing     = -1,
		groupGrowth      = "RIGHT",  -- "DOWN", "UP", "RIGHT", "LEFT", "DOWNRIGHT" (grid: ns._RF_GRID_ROWS per column)
		unitGrowth       = "DOWN",   -- any direction; same-axis as groupGrowth = one continuous line
		sortMode         = "ROLE",   -- "INDEX" (by group) or "ROLE" (by assigned role)
		roleOrder        = { "TANK", "HEALER", "DAMAGER" },
		prioritizeClass  = false,    -- sort by class within the main sort (raid)
		classOrder       = nil,      -- nil = all classes alphabetical by name
		showSelfFirst    = true,
		showSelfLast     = false,
		mergeGroups      = false,
		customGroupOrder = false,
		visibleGroups    = { true, true, true, true, true, true, false, false },
		hideEmptyGroups  = true,     -- collapse subgroups with no members (raid only, real frames)
		excludeHiddenGroupsFromSize = true, -- hidden Show Groups don't count toward the raid-size breakpoint
		mythicRaidHideGroups = false, -- Hide Groups 5-8 in Mythic Raid (on top of Show Groups)

		-- Visibility
		showWhenSolo     = false,
		showWhenGroup    = false,
		showWhenRaid     = true,
		frameStrata      = "LOW",

		-- Friendly Boss Frames (boss1-5 healable NPC frames; raid, plus party
		-- via the opt-in showInDungeons key -- absent = raid only, no default
		-- on purpose so existing users keep the raid-only behavior)
		friendlyBoss = {
			display  = "never",   -- "never" | "healers" | "always"
			position = "right",   -- "left" | "right" | "free"
			freePos  = { x = 100, y = 0 },
			freeHorizontal = false,
			healthColor = { r = 23/255, g = 172/255, b = 49/255 },
			extraWidth  = 0,      -- size offset on top of the raid frame size
			extraHeight = 0,
		},

		-- Extra Frames (duplicates of chosen raid members, raid only)
		extraFrames = {
			showTanks = false,    -- auto-include the raid's tanks
			position  = "right",  -- "left" | "right" | "free"
			freePos   = { x = 100, y = -120 },
			freeHorizontal = false,
			players   = {},       -- manually added names (hotkey toggle)
			extraWidth  = 0,      -- size offset on top of the raid frame size
			extraHeight = 0,
			wrapAfter = 0,        -- Free Move frames per row/column; 0 = single line
			-- growDirection / wrapDirection / freeRect: optional, no defaults.
			-- Unset, growth derives from freeHorizontal, wrap from the perpendicular
			-- default, anchoring from freePos. See XF.GrowInfo / XF.FreeAnchor.
		},

		-- Pet Frames (party and raid pets, beside the groups). Each tab reads the placement
		-- (position, freePos, freeRect) and extra size here until it sets its own party_/raid_
		-- key (PF.View).
		petFrames = {
			party = false,
			raid  = false,
			position = "right",   -- "left" | "right" | "free" | "owner" (Beside Owner, Party tab)
			freePos  = { x = 100, y = -200 },
			healthColor = { r = 23/255, g = 172/255, b = 49/255 },
			extraWidth  = 0,      -- size offset on top of the party or raid frame size
			extraHeight = 0,
		},

		-- Healer Mana Text Display (Extras): one text row per group healer.
		healerMana = {
			mode       = "none",   -- "none" | "party" | "raid" | "both"
			textSize   = 12,
			spacing    = 2,        -- vertical space between rows
			showNames  = true,     -- raid only; party shows the number alone
			classNames = true,     -- class colored names
			align      = "LEFT",   -- "LEFT" | "CENTER" | "RIGHT"
			growth     = "DOWN",   -- "DOWN" | "UP" (row stacking direction)
			colorMode  = "custom", -- "custom" | "power" (value text color)
			color      = { r = 1, g = 1, b = 1 },
			-- unlockPos: saved by unlock mode (RF_HealerMana element)
		},

		-- Position (saved by unlock mode)
		unlockPos        = nil,

		-- Health bar
		healthBarTexture = "atrocity",
		healthBarOpacity = 100,
		healthColorMode  = "class",  -- "class", "dark", "classic", "custom", "customDynamic", "classReactive"
		customFillColor  = { r = 37/255, g = 193/255, b = 29/255 },
		-- Custom Dynamic Colors: health-percent gradient stops; defaults match
		-- the Classic curve so switching from Classic looks identical at first.
		dynamicColor100  = { r = 0, g = 1, b = 0 },   -- full health
		dynamicColor50   = { r = 1, g = 1, b = 0 },   -- half health
		dynamicColor0    = { r = 1, g = 0, b = 0 },   -- empty health
		customBgColor    = { r = 17/255, g = 17/255, b = 17/255 },
		bgClassColored   = false,
		bgDarkness       = 50,
		-- Fill axis: off = left-to-right, on = bottom-to-top. Party can hold its own (key is in the healthBar override section).
		healthVerticalFill = false,
		-- Invert health fill: when true the bar is full at low health and empty at high health.
		healthInvertFill = false,

		-- Power bar (on when any powerShowFor* role is true)
		showPowerBar     = true,
		powerHeight      = 4,
		powerBgDarkness  = 40,
		powerBgColor     = { r = 107/255, g = 107/255, b = 107/255 },
		powerBgPowerColored = false,
		powerBorderStyle = "eui",      -- "eui", "divider", "border"
		powerBorderSize  = 1,
		powerBorderColor = { r = 0, g = 0, b = 0 },
		powerBorderAlpha = 1,
		powerShowForHealer = true,
		powerShowForTank   = true,
		powerShowForDPS    = false,
		-- Uniform Icon Anchoring: icons/text anchor as if no power bar existed, so per-role power bars never shift them.
		powerUniformAnchors = false,
		extendHealthBehindPower = false,  -- health spans full frame; power bar overlays it

		-- Top Name Bar: reserves height from the frame TOP (as the power bar does from the bottom); suppresses the in-frame Name.
		topNameBarEnabled       = false,
		topNameBarHeight        = 20,
		topNameBarBgColor       = { r = 17/255, g = 17/255, b = 17/255 },
		topNameBarBgOpacity     = 80,
		topNameBarTextSize      = 11,
		topNameBarTextColorMode = "class",  -- "class" or "custom"
		topNameBarTextColor     = { r = 1, g = 1, b = 1 },
		topNameBarTextOffsetX   = 0,
		topNameBarTextOffsetY   = 0,
		topNameBarTextAlign     = "center", -- "center", "left", "right"
		topNameBarBottom        = false,    -- Show on Bottom: the bar takes the frame's bottom edge
		topNameBarDivider       = false,
		topNameBarDividerMatchColor = false,

		-- Text
		nameSize         = 10,
		nameMaxLength    = 15,  -- max characters shown for unit names (0 = off / no cap)
		nameColorMode    = "custom",  -- "class", "accent", "custom"
		nameCustomColor  = { r = 1, g = 1, b = 1 },
		namePosition     = "topleft", -- "topleft", "top", "topright", "left", "center", "right", "bottomleft", "bottom"
		nameOffsetX      = 0,
		nameOffsetY      = 0,
		-- Level Text: the unit's level in front of the name, or on its own spot in the name's colour
		-- (Health Text's host). None = nothing built.
		levelTextSize      = 10,
		levelTextPosition  = "none",  -- "name" ("60 Name"), "nameDiv" ("60 | Name"), "none" or a 9-point spot
		levelTextOffsetX   = 0,
		levelTextOffsetY   = 0,
		healthTextMode   = "none",   -- "none", "percent", "number"
		healthTextColorMode   = "custom",  -- "class", "accent", "custom"
		healthTextCustomColor = { r = 1, g = 1, b = 1 },
		healthTextSize   = 9,
		healthTextPosition = "center",
		healthTextOffsetX  = 0,
		healthTextOffsetY  = 0,
		-- Power Text (Health Text's controls, on the same health bar host): shown only where the power bar shows. None = nothing built.
		powerTextMode   = "none",   -- "none", "percent", "percentNoSign", "number", "numberPercent", "percentNumber"
		powerTextColorMode   = "custom",  -- "custom", "class", "accent", "power"
		powerTextCustomColor = { r = 1, g = 1, b = 1 },
		powerTextSize   = 8,
		powerTextPosition = "bottom",
		powerTextOffsetX  = 0,
		powerTextOffsetY  = 0,
		-- Heal Absorb Text (1:1 with Health Text): amount in short/full format, hidden at zero. Red default = healer-UI convention.
		healAbsorbTextMode   = "none",   -- "none", "amount", "short"
		healAbsorbTextColorMode   = "custom",  -- "class", "accent", "custom"
		healAbsorbTextCustomColor = { r = 1, g = 0.3, b = 0.3 },
		healAbsorbTextSize   = 9,
		healAbsorbTextPosition = "center",
		healAbsorbTextOffsetX  = 0,
		healAbsorbTextOffsetY  = 0,

		-- Border (unified style/size, recolored by state -- matches Unit Frames)
		borderSize       = 1,
		borderColor      = { r = 0, g = 0, b = 0 },
		borderAlpha      = 1,
		borderTexture    = "solid",
		borderBehind     = false,
		-- borderTextureOffset/OffsetY/ShiftX/ShiftY default via GetBorderDefaults

		-- Smooth bars
		smoothBars       = true,
		smoothPowerBars  = true,

		-- Absorb shields (must match UF options)
		absorbStyle      = "striped",   -- "none", "striped", "clean", "blizzard"
		absorbOpacity    = 90,
		absorbColor      = { r = 1, g = 1, b = 1 },
		-- Overshield = absorb exceeding empty health, backfilling over current health.
		-- Off: absorbs fill only the empty part (and on Default Blizz Frames the glow line stays pinned right).
		showOvershield   = true,
		-- Blizzard Glow Line (absorbGlowLine) has NO default on purpose: unset follows the
		-- style (on for Default Blizz Frames only); a default would switch the line off for
		-- every profile already on that style.
		healAbsorbStyle  = "clean",
		healAbsorbOpacity = 75,
		healAbsorbColor  = { r = 0.8, g = 0.15, b = 0.15 },
		healPrediction   = false,
		healPredOpacity  = 75,
		healPredColor    = { r = 102/255, g = 243/255, b = 102/255 },
		-- Absorb / heal absorb placement, independent per bar: "overlay" (over
		-- the health fill, default), "right" / "left" (from that frame edge).
		absorbEdgeMode     = "overlay",
		healAbsorbEdgeMode = "overlay",
		-- Lift the heal-absorb overlay above the dispel gradient (off = below dispel).
		healAbsorbOverDispel = false,
		-- Black backing behind the heal-absorb texture (all styles); 0 = off.
		healAbsorbBgOpacity = 25,
		-- Reduced max-health overlay: always right-anchored, styled like Heal
		-- Absorb but with a dedicated "Max Health Stripes" texture, no placement option.
		maxHealthStyle      = "maxHealthStripes",
		maxHealthColor      = { r = 0.7, g = 0.1, b = 0.1 },
		maxHealthOpacity    = 100,
		maxHealthBgOpacity  = 100,
		-- Absorb Bar: solid bar above the frame, fills from the right edge
		absorbBarEnabled = false,
		absorbBarHeight  = 4,
		absorbBarColor   = { r = 1, g = 1, b = 1 },
		-- Fill direction for the vertical (Right/Left Edge) positions.
		absorbBarGrowDir = "up",
		-- Heal Absorb Bar: separate strip showing the heal-absorb amount
		healAbsorbBarPosition = "none",
		healAbsorbBarHeight   = 4,
		healAbsorbBarColor    = { r = 200/255, g = 29/255, b = 29/255 },
		healAbsorbBarGrowDir  = "up",

		-- Indicators
		roleIconStyle    = "modern",  -- none/modern/modernCircle/styled/classicCircle/classic/blizzDefault/blizzLight/pixels
		roleIconSize     = 13,
		roleIconPosition = "bottomleft",  -- topleft/top/topright/left/center/right/bottomleft/bottom/bottomright
		roleIconOffsetX  = 0,
		roleIconOffsetY  = 0,
		roleIconHideInCombat = false,
		roleText         = false,
		roleTextTankColor   = { r = 59/255, g = 130/255, b = 246/255 },
		roleTextHealerColor = { r = 32/255, g = 201/255, b = 151/255 },
		roleTextDPSColor    = { r = 240/255, g = 100/255, b = 54/255 },
		roleIconBehindBorder = false,  -- drop the carrier below the hover/target raise so borders draw over the icon
		showRoleForTank    = true,
		showRoleForHealer  = true,
		showRoleForDPS     = false,
		showRaidMarker   = true,
		raidMarkerSize   = 16,
		raidMarkerPosition = "center",  -- "topleft", "top", "topright", "left", "center", "right", "bottomleft", "bottom"
		raidMarkerOffsetX  = 0,
		raidMarkerOffsetY  = 0,
		-- Ping marker: the mark a group member's ping puts on the pinged unit's frame (Blizzard art, 30 = native size)
		showPingMarker     = true,
		pingMarkerSize     = 30,
		pingMarkerPosition = "center",
		pingMarkerOffsetX  = 0,
		pingMarkerOffsetY  = 0,
		-- WoW Forever: Missing Buffs (EUI_RaidFrames_ForeverMissingBuffs.lua).
		-- Forever-only defaults, absent on every other client.
		-- Its icons' glow (shared prefix schema; 2 = Action Button Glow).
		showReadyCheck   = true,
		showSummonPending = true,
		showIncomingRez  = true,
		readyCheckSize   = 20,
		readyCheckPosition = "center",  -- "topleft", "top", "topright", "left", "center", "right", "bottomleft", "bottom"
		readyCheckOffsetX  = 0,
		readyCheckOffsetY  = 0,
		threatBorderSize = 2,    -- aggro warning border thickness; 0 = off
		threatCustomBorder = false,  -- Color Custom Borders: the frame border recolored for aggro instead of the inner border
		showLeaderIcon   = false,
		showLeaderIconInCombat = true,  -- "Show In Combat" cog; off = hide in combat
		leaderIconPosition = "top",
		leaderIconSize   = 14,
		leaderIconOffsetX  = 0,
		leaderIconOffsetY  = 0,
		-- Combat icon: shown on members who are in combat (M+ skip awareness)
		showCombatIndicator = false,
		combatIndicatorStyle = "standard",   -- standard/class/combat0..5 (none handled by showCombatIndicator)
		combatIndicatorColor = "custom",      -- custom/classcolor (standard/class styles only)
		combatIndicatorCustomColor = { r = 1, g = 0.2, b = 0.2 },
		combatIndicatorSize  = 16,
		combatIndicatorPosition = "right",
		combatIndicatorOffsetX = 0,
		combatIndicatorOffsetY = 0,
		statusTextPosition = "center",
		statusTextOffsetX  = 0,
		statusTextOffsetY  = 0,
		statusTextSize     = 12,
		statusTextColor    = { r = 1, g = 1, b = 1 },
		statusShowAFK      = false,
		-- Group numbers (raid only). Size/color shared with the preview; the toggle gates only real frames (preview always shows them).
		showGroupNumbers   = false,
		groupNumberSize    = 10,
		groupNumberColor   = { r = 1, g = 1, b = 1, a = 0.75 },
		groupNumberOffsetX = 0,
		groupNumberOffsetY = 0,
		hoverBorderEnabled = true,
		hoverBorderSize  = 1,
		hoverBorderColor = { r = 1, g = 1, b = 1 },
		hoverBorderAlpha = 1,
		targetBorderEnabled = true,
		targetBorderSize = 1,
		targetBorderColor = { r = 1, g = 1, b = 1 },
		targetBorderAlpha = 1,

		-- Dispels
		dispelBorderSize = 0,
		dispelOverlay    = "fill",   -- "none", "fill", "full", "gradient", "gradient_sharp"
		dispelOverlayOpacity = 100,
		dispelShowAll             = true,   -- true = highlight any dispellable debuff; false = only player-dispellable
		dispelOverlayPosition     = 0,      -- 0=Top, 1=Bottom, 2=Left (aura-organization-type for private aura dispel container)
		showDispelIcons       = false,
		dispelIconPosition = "right",
		dispelIconOffsetX  = 0,
		dispelIconOffsetY  = 0,
		dispelIconSize     = 16,
		-- 12.1 dispel ring thickness in physical pixels (-1 follows the icon's own
		-- Border, 0 hides it). Stored explicitly rather than left to the `or 2`
		-- read fallback: ReloadPartyFrames temp-swaps party values onto db.profile
		-- and restores from a table keyed by the raid value, so a key with no
		-- default is absent from that table and its party value would stick.
		dispelIconBorderSize = 2,
		dispelCustomBorder = false,  -- Color Custom Borders: the frame border copied in the dispel type color
		dispelClockBorder  = false,  -- animated clock-style dispel border (erases clockwise) on dispellable debuff icons
		dispelClockExtraBorder = 0,  -- extra physical pixels added to the clock border thickness (on top of debuffBorderSize)
		dispellableDebuffLocation = "same",      -- "same" = use the main debuff layout; else a separate anchor for dispellable debuffs
		dispellableDebuffGrowDirection = "RIGHT",
		dispellableDebuffOffsetX = 0,
		dispellableDebuffOffsetY = 0,
		dispellableDebuffSize = 0,               -- icon size at the separate anchor (0 = match Debuff Size)
		-- Per-dispel-type colors (defaults mirror DISPEL_COLORS). "Bleed" is the
		-- no-dispelName/physical type (stored under the "" key in DISPEL_COLORS).
		dispelColorMagic   = { r = 0.349, g = 0.475, b = 1.0 },
		dispelColorCurse   = { r = 0.636, g = 0.0,   b = 0.64 },
		dispelColorDisease = { r = 0.671, g = 0.384, b = 0.098 },
		dispelColorPoison  = { r = 0.0,   g = 0.706, b = 0.286 },
		dispelColorBleed   = { r = 0.75,  g = 0.15,  b = 0.15 },
		-- Health background status tint (Status Colors swatch in Extras).
		statusColorOffline = { r = 0x66/255, g = 0x66/255, b = 0x66/255 },  -- #666666
		statusColorDead    = { r = 0x24/255, g = 0x17/255, b = 0x17/255 },  -- #241717

		-- Buff Manager (indicator-centric model)
		bmIndicators      = {},  -- { [specKey] = { indicator1, indicator2, ... } }

		-- Debuffs
		debuffFilter     = "all",  -- "none", "all", "raid", "dispellable"
		hideLustDebuff   = true,
		-- Defensives & Externals
		showDefensives   = true,
		showExternals    = true,
		defPosition      = "center",
		defOffsetX       = 0,
		defOffsetY       = 0,
		defGrowDirection = "CENTER",
		defSize          = 22,
		defBorderSize    = 1,
		defBorderColor   = { r = 0, g = 0, b = 0 },
		defSpacing       = 1,
		defShowSwipe     = true,
		defShowDurText   = false,
		defDurTextColor  = { r = 1, g = 1, b = 1 },
		defDurTextSize   = 8,
		defDurTextOffsetX = 0,
		defDurTextOffsetY = 0,

		-- Buff Manager "Simple Setup" (retired display): kept only as legacy
		-- input for the v2 conversion and spec-override banking; nothing renders it.
		bmSimple = {
			showBuffs       = true,
			ownOnly         = true,
			maxBuffs        = 8,
			iconsPerRow     = 4,
			position        = "topright",
			offsetX         = 0,
			offsetY         = 0,
			growDirection   = "LEFT",   -- sensible default for the Top Right anchor
			size            = 18,
			spacing         = 1,
			borderSize      = 1,
			borderColor     = { r = 0, g = 0, b = 0 },
			showSwipe       = true,
			showDurText     = false,
			durTextColor    = { r = 1, g = 1, b = 1 },
			durTextSize     = 8,
			durTextOffsetX  = 0,
			durTextOffsetY  = 0,
			showStacks      = true,
			stacksTextColor = { r = 1, g = 1, b = 1 },
			stacksTextSize  = 8,
			stacksOffsetX   = -1,
			stacksOffsetY   = 2,
		},

		buffHideTooltips = true,
		debuffSize       = 18,
		debuffCap        = 3,
		debuffHideTooltips = true,
		debuffPosition   = "bottomright",
		debuffOffsetX    = 0,
		debuffOffsetY    = 0,
		debuffGrowDirection = "LEFT",
		debuffPerRow     = 5,   -- icons per row (1 = single line, no wrap; >= 2 wraps)
		debuffWrapDirection = "UP",
		debuffSpacing    = 1,
		debuffBorderSize = 1,
		debuffBorderColor = { r = 0, g = 0, b = 0 },
		debuffShowStacks = true,
		debuffStacksTextColor = { r = 1, g = 1, b = 1 },
		debuffStacksTextSize = 8,
		debuffStacksOffsetX = 0,
		debuffStacksOffsetY = 0,
		debuffShowSwipe  = true,
		debuffShowDurText = false,
		debuffDurTextColor = { r = 1, g = 1, b = 1 },
		debuffDurTextSize = 8,
		debuffDurTextOffsetX = 0,
		debuffDurTextOffsetY = 0,

		-- Range & misc
		oorAlpha         = 0.4,
		-- showTooltip is the on/off fallback the "Show Raid Frames Tooltip"
		-- dropdown derives from (ns._ResolveTooltipMode); picking an option writes
		-- tooltipMode = always|outOfCombat|outOfBossCombat|never. Raid/party only.
		showTooltip      = true,
		freeRightClickCamera = false,  -- right-click + drag over a raid/party frame turns the camera (mouselook)

		-- Preview mode: "real", "overlay", "none"
		previewMode       = "overlay",

		-- Raid size overrides: { [10] = { width=X, height=Y }, ... }
		raidSizeOverrides = nil,
		autoResizeIndicators = false,
		-- Tracked Buffs (Buff Manager) auto-resize ("Auto Resize Icons" dropdown); nil = on.
		autoResizeTrackedBuffs = true,

		-- Party frame overrides (sparse -- falls back to raid settings)
		partyFrameWidth   = 125,
		partyFrameHeight  = 60,
		partyShowWhenSolo = false,
		partySmallRaid    = false,  -- raid under 10 players: group 1 as party frames, others hidden
		partyShowTargets  = false,  -- opt-in secure target buttons beside party frames
		-- Party target frames (Party tab PARTY TARGETS section): party only, one value under
		-- every style. partyTargetPosition nil = beside stacked frames, below horizontal ones.
		partyTargetIncludeSelf     = false,     -- your own target beside your frame too
		partyTargetHealthColorMode = "class",   -- "class" | "dark" | "classic" | "custom"
		partyTargetCustomFillColor = { r = 37/255, g = 193/255, b = 29/255 },
		partyTargetBgClassColored  = false,
		partyTargetCustomBgColor   = { r = 17/255, g = 17/255, b = 17/255 },
		partyTargetBgDarkness      = 50,
		partyTargetOffsetX         = 0,         -- -100..100
		partyTargetOffsetY         = 0,
		partyTargetWidth           = 70,
		partyTargetHeight          = 33,
		partyCenterWhenSolo = false,  -- center the lone player frame in the container when solo
		partySyncSections = nil,  -- nil = all synced; { healthBar=false } = healthBar custom
		partySortMode     = "ROLE",
		partyPrioritizeClass = false, -- sort by class within the main sort (party only)
		partyClassOrder    = nil,  -- nil = all 13 classes alphabetical by name
		partyShowSelfFirst = true,
		partySelfLast      = false,
		partyHorizontal   = false,
		partyFlipGrowth   = false,  -- false=default growth, true=DOWN->UP / RIGHT->LEFT flip, "centered"=stack centered in the 5-slot container
		partyHideSelf     = false,
		partyUnlockPos    = nil,
		-- Party mirror of autoResizeTrackedBuffs ("Auto Resize Icons", Party tab); nil = on.
		partyAutoResizeTrackedBuffs = true,
		-- Party portrait (Party tab PORTRAIT section, EUI_RaidFrames_Portrait.lua):
		-- party only, one value under every style. Off by default.
		partyPortraitStyle       = "none",      -- "none" | "attached" | "detached"
		partyPortraitMode        = "2d",        -- Art Style: "2d" | "3d" | "class"
		partyPortraitClassStyle  = "modern",    -- class art set
		partyPortraitSide        = "left",      -- left|right|top|insideleft|insideright|insidecenter
		partyPortraitSize        = 0,           -- -50..100 (detached / inside)
		partyPortraitX           = 0,           -- -100..100 (detached)
		partyPortraitY           = 0,
		partyPortraitShape       = "portrait",  -- none|portrait|circle|square|csquare|diamond|hexagon|shield
		partyPortraitBorderColor = { r = 0, g = 0, b = 0 },
		partyPortraitBorderClassColor = true,
		partyPortraitBorderOpacity = 100,       -- 0..100
		partyPortraitBorderSize  = 7,           -- 1..7
		partyPortraitArtScale    = 100,         -- 2D Zoom 50..100
		partyPortrait3dZoom      = 100,         -- 3D Zoom 100..500 (above 300: whole character)
		partyPortraitCharScale   = 100,         -- Character Size % 50..200 (Inside, 3D)
	},
}
RF.defaults = DEFAULTS
ERF.defaults = DEFAULTS

-------------------------------------------------------------------------------
--  Saved settings: EllesmereUIRaidFramesDB.profile (the retail profile).
--  First run = the retail "Naowh" profile (EUI_RaidFrames_Seed.lua) over
--  the defaults; later runs fill new default keys.
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
RF.DeepCopy = DeepCopy

local function NewProfile(seed)
	local p = seed and DeepCopy(seed) or {}
	ns.CopyDefaults(DEFAULTS.profile, p)
	return p
end

function ERF:InitDB()
	if self.db then
		return
	end
	if type(EllesmereUIRaidFramesDB) ~= "table" then
		EllesmereUIRaidFramesDB = {}
	end
	local sv = EllesmereUIRaidFramesDB
	if type(sv.profile) ~= "table" then
		sv.profile = NewProfile(RF.NAOWH_SEED)
	else
		ns.CopyDefaults(DEFAULTS.profile, sv.profile)
	end
	sv.version = 1
	self.db = { sv = sv, profile = sv.profile }
	RF.db = self.db
	RF._NormalizePartySyncSections()
end

-- Live profile table (re-read after a reset or a profile switch).
function RF.Profile()
	return ERF.db and ERF.db.profile
end

-- Reset to the EllesmereUI defaults (retail Reset).
function ERF:ResetProfile()
	if not self.db then
		return
	end
	self.db.sv.profile = NewProfile(nil)
	self.db.profile = self.db.sv.profile
	RF._NormalizePartySyncSections()
	self:ApplyAll()
end

-- Load the retail "Naowh" profile.
function ERF:ApplyNaowhProfile()
	if not self.db then
		return
	end
	self.db.sv.profile = NewProfile(RF.NAOWH_SEED)
	self.db.profile = self.db.sv.profile
	RF._NormalizePartySyncSections()
	self:ApplyAll()
end

do
	local f = CreateFrame("Frame")
	f:RegisterEvent("ADDON_LOADED")
	f:SetScript("OnEvent", function(self, _, name)
		if name == addonName then
			self:UnregisterEvent("ADDON_LOADED")
			ERF:InitDB()
		end
	end)
end

-------------------------------------------------------------------------------
--  Party settings proxy (retail, verbatim key lists). Per-section sync:
--  partySyncSections[section] = false -> party buttons read "party_<key>"
--  for that section's keys, else the raid value.
-------------------------------------------------------------------------------
RF._PARTY_KEY_SECTION = {}

RF._PARTY_SECTION_ORDER = {
	"healthBar", "absorbs", "powerBar", "textDisplay", "indicators", "dispels", "topNameBar",
	"rangeTooltip",
}
RF._PARTY_SECTION_LABELS = {
	healthBar = "Health Bar",
	absorbs = "Absorbs",
	powerBar = "Power Bar",
	textDisplay = "Text Display",
	indicators = "Indicators",
	dispels = "Dispels",
	topNameBar = "Top Name Bar",
	rangeTooltip = "Range & Tooltip",
}

do
	local map = {
		healthBar = {
			"healthBarTexture", "healthBarOpacity", "healthColorMode",
			"customFillColor", "dynamicColor100", "dynamicColor50", "dynamicColor0",
			"customBgColor", "bgClassColored", "bgDarkness", "smoothBars",
			"healPrediction", "healPredOpacity", "healPredColor",
			"healthVerticalFill", "healthInvertFill",
			"threatBorderSize", "threatCustomBorder",
		},
		absorbs = {
			"absorbStyle", "absorbOpacity", "absorbColor", "absorbEdgeMode", "showOvershield",
			"overshieldMode", "absorbGlowLine",
			"absorbBarEnabled", "absorbBarPosition", "absorbBarHeight", "absorbBarColor",
			"absorbBarGrowDir",
			"healAbsorbBarPosition", "healAbsorbBarHeight", "healAbsorbBarColor",
			"healAbsorbBarGrowDir",
			"healAbsorbStyle", "healAbsorbOpacity", "healAbsorbColor", "healAbsorbEdgeMode",
			"healAbsorbBgOpacity",
			"maxHealthStyle", "maxHealthOpacity", "maxHealthColor", "maxHealthBgOpacity",
		},
		powerBar = {
			"showPowerBar", "powerHeight", "powerBgDarkness", "powerBgColor", "powerBgPowerColored",
			"powerBorderStyle", "powerBorderSize", "powerBorderColor", "powerBorderAlpha",
			"powerShowForHealer", "powerShowForTank", "powerShowForDPS", "smoothPowerBars",
			"powerUniformAnchors", "extendHealthBehindPower",
		},
		textDisplay = {
			"nameSize", "nameMaxLength", "nameFormat", "nameColorMode", "nameCustomColor",
			"namePosition", "nameOffsetX", "nameOffsetY",
			"levelTextSize", "levelTextPosition", "levelTextOffsetX", "levelTextOffsetY",
			"healthTextMode", "healthTextColorMode", "healthTextCustomColor",
			"healthTextSize", "healthTextPosition", "healthTextOffsetX", "healthTextOffsetY",
			"healAbsorbTextMode", "healAbsorbTextColorMode", "healAbsorbTextCustomColor",
			"healAbsorbTextSize", "healAbsorbTextPosition", "healAbsorbTextOffsetX", "healAbsorbTextOffsetY",
			"powerTextMode", "powerTextColorMode", "powerTextCustomColor",
			"powerTextSize", "powerTextPosition", "powerTextOffsetX", "powerTextOffsetY",
		},
		indicators = {
			"roleIconStyle", "roleIconSize", "roleIconPosition", "roleIconOffsetX", "roleIconOffsetY", "roleIconHideInCombat",
			"roleIconBehindBorder", "roleText", "roleTextTankColor", "roleTextHealerColor", "roleTextDPSColor",
			"showRoleForTank", "showRoleForHealer", "showRoleForDPS",
			"showRaidMarker", "raidMarkerSize", "raidMarkerPosition", "raidMarkerOffsetX", "raidMarkerOffsetY",
			"showPingMarker", "pingMarkerSize", "pingMarkerPosition", "pingMarkerOffsetX", "pingMarkerOffsetY",
			"showReadyCheck", "showSummonPending", "showIncomingRez",
			"readyCheckSize", "readyCheckPosition", "readyCheckOffsetX", "readyCheckOffsetY",
			"statusTextPosition", "statusTextOffsetX", "statusTextOffsetY", "statusTextSize", "statusTextColor",
			"statusShowAFK",
			"showLeaderIcon", "showLeaderIconInCombat", "leaderIconPosition", "leaderIconSize", "leaderIconOffsetX", "leaderIconOffsetY",
			"showCombatIndicator", "combatIndicatorStyle", "combatIndicatorColor", "combatIndicatorCustomColor",
			"combatIndicatorSize", "combatIndicatorPosition", "combatIndicatorOffsetX", "combatIndicatorOffsetY",
			"borderSize", "borderColor", "borderAlpha", "borderTexture",
			"borderBehind", "borderTextureOffset", "borderTextureOffsetY",
			"borderTextureShiftX", "borderTextureShiftY",
			"hoverBorderEnabled", "hoverBorderSize", "hoverBorderColor", "hoverBorderAlpha",
			"targetBorderEnabled", "targetBorderSize", "targetBorderColor", "targetBorderAlpha",
			"borderSizePx", "hoverBorderSizePx", "targetBorderSizePx",
		},
		dispels = {
			"dispelBorderSize", "dispelOverlay", "dispelOverlayOpacity", "dispelShowAll",
			"showDispelIcons", "dispelIconPosition", "dispelIconOffsetX", "dispelIconOffsetY", "dispelIconSize",
			"dispelColorMagic", "dispelColorCurse", "dispelColorDisease",
			"dispelColorPoison", "dispelColorBleed",
			"dispelIconBorderSize", "dispelOverlayPosition", "dispelCustomBorder",
			"dispelClockBorder", "dispelClockExtraBorder",
			"dispellableDebuffLocation", "dispellableDebuffGrowDirection",
			"dispellableDebuffOffsetX", "dispellableDebuffOffsetY", "dispellableDebuffSize",
		},
		topNameBar = {
			"topNameBarEnabled", "topNameBarHeight",
			"topNameBarBgColor", "topNameBarBgOpacity",
			"topNameBarTextSize", "topNameBarTextColorMode", "topNameBarTextColor",
			"topNameBarTextOffsetX", "topNameBarTextOffsetY", "topNameBarTextAlign",
			"topNameBarBottom", "topNameBarDivider", "topNameBarDividerMatchColor",
		},
		rangeTooltip = {
			"oorAlpha", "showTooltip", "tooltipMode", "frameStrata",
		},
	}
	for section, keys in pairs(map) do
		for _, k in ipairs(keys) do
			RF._PARTY_KEY_SECTION[k] = section
		end
	end
end

-- A border's exact-size companion follows its party sibling (retail rule).
RF._PARTY_PX_SIBLING = {
	borderSizePx = "borderSize",
	hoverBorderSizePx = "hoverBorderSize",
	targetBorderSizePx = "targetBorderSize",
	absorbGlowLine = "absorbStyle",
}

function RF._IsPartySectionCustom(section)
	local p = RF.Profile()
	local ss = p and p.partySyncSections
	if not ss then
		return false
	end
	return ss[section] == false
end

function RF._IsPartyAllSynced()
	local p = RF.Profile()
	local ss = p and p.partySyncSections
	if not ss then
		return true
	end
	for _, sec in ipairs(RF._PARTY_SECTION_ORDER) do
		if ss[sec] == false then
			return false
		end
	end
	return true
end

-- Profiles saved before Absorbs left Health Bar inherit its sync state.
function RF._NormalizePartySyncSections()
	local p = RF.Profile()
	local ss = p and p.partySyncSections
	if ss and ss.absorbs == nil and ss.healthBar == false then
		ss.absorbs = false
	end
end

-- Party view: base profile + party_ overrides of unsynced sections.
RF._partyProxy = setmetatable({}, {
	__index = function(_, key)
		local p = RF.Profile()
		if not p then
			return nil
		end
		local section = RF._PARTY_KEY_SECTION[key]
		if section and RF._IsPartySectionCustom(section) then
			local sib = RF._PARTY_PX_SIBLING[key]
			if sib and rawget(p, "party_" .. sib) ~= nil then
				return rawget(p, "party_" .. key)
			end
			local pv = rawget(p, "party_" .. key)
			if pv ~= nil then
				return pv
			end
		end
		return p[key]
	end,
})

-- Party frame box: width (incl. an attached portrait's share), height,
-- spacing, portrait share. EUI_RaidFrames_Extras.lua sets RF.RF_PtReserve.
function RF.RF_PartyDims(s)
	local w = s.partyFrameWidth or s.frameWidth or 125
	local h = s.partyFrameHeight or s.frameHeight or 60
	local res = RF.RF_PtReserve and RF.RF_PtReserve(s, h) or 0
	return w + res, h, s.partyCellSpacing or s.cellSpacing or 2, res
end

-------------------------------------------------------------------------------
--  Auto-resize scales (retail): sizes and offsets of texts, icons and auras
--  follow the raid size tier / party size. The headers file sets the scales
--  (RF._indicatorScale, RF._partyIndicatorScale, RF._bmScale,
--  RF._partyBmScale, RF._xfExtraRatio, RF._xfBmScale) and the active tier
--  size (RF._activeSizeW / RF._activeSizeH).
-------------------------------------------------------------------------------
RF._indicatorScale = 1
RF._partyIndicatorScale = 1
RF._bmScale = 1
RF._partyBmScale = 1
RF._xfExtraRatio = 1
RF._xfBmScale = 1

local INDICATOR_SCALE_KEYS = {}
for _, k in ipairs({
	"nameSize", "healthTextSize", "healAbsorbTextSize", "statusTextSize", "powerTextSize", "levelTextSize",
	"debuffStacksTextSize", "debuffDurTextSize", "defDurTextSize",
	"roleIconSize", "leaderIconSize", "raidMarkerSize", "combatIndicatorSize", "pingMarkerSize",
	"missingBuffsSize",
	"debuffSize", "defSize", "dispellableDebuffSize",
	"nameOffsetX", "nameOffsetY",
	"healthTextOffsetX", "healthTextOffsetY",
	"healAbsorbTextOffsetX", "healAbsorbTextOffsetY",
	"powerTextOffsetX", "powerTextOffsetY",
	"levelTextOffsetX", "levelTextOffsetY",
	"statusTextOffsetX", "statusTextOffsetY",
	"roleIconOffsetX", "roleIconOffsetY",
	"leaderIconOffsetX", "leaderIconOffsetY",
	"raidMarkerOffsetX", "raidMarkerOffsetY",
	"missingBuffsOffsetX", "missingBuffsOffsetY",
	"combatIndicatorOffsetX", "combatIndicatorOffsetY",
	"debuffOffsetX", "debuffOffsetY",
	"dispellableDebuffOffsetX", "dispellableDebuffOffsetY",
	"debuffStacksOffsetX", "debuffStacksOffsetY",
	"debuffDurTextOffsetX", "debuffDurTextOffsetY",
	"defOffsetX", "defOffsetY",
	"defDurTextOffsetX", "defDurTextOffsetY",
	"dispelIconOffsetX", "dispelIconOffsetY",
}) do
	INDICATOR_SCALE_KEYS[k] = true
end
RF.INDICATOR_SCALE_KEYS = INDICATOR_SCALE_KEYS

-- Raid view: active tier size + indicator scale.
RF._scaledProfile = setmetatable({}, {
	__index = function(_, key)
		if key == "frameWidth" and RF._activeSizeW then
			return RF._activeSizeW
		end
		if key == "frameHeight" and RF._activeSizeH then
			return RF._activeSizeH
		end
		local p = RF.Profile()
		local val = p and p[key]
		if INDICATOR_SCALE_KEYS[key] and type(val) == "number" and RF._indicatorScale ~= 1 then
			return val * RF._indicatorScale
		end
		return val
	end,
})

-- Party view: party proxy + party size + party scale.
RF._scaledPartyProxy = setmetatable({}, {
	__index = function(_, key)
		if key == "frameWidth" or key == "frameHeight" then
			local p = RF.Profile()
			if not p then
				return nil
			end
			local w, h, _, res = RF.RF_PartyDims(p)
			if key == "frameWidth" then
				return w - (res or 0)
			end
			return h
		end
		local val = RF._partyProxy[key]
		if INDICATOR_SCALE_KEYS[key] and type(val) == "number" and RF._partyIndicatorScale ~= 1 then
			return val * RF._partyIndicatorScale
		end
		return val
	end,
})

-- Extra Frames view: raid view times the Extra Width/Height ratio.
RF._scaledExtraProxy = setmetatable({}, {
	__index = function(_, key)
		local val = RF._scaledProfile[key]
		if INDICATOR_SCALE_KEYS[key] and type(val) == "number" and RF._xfExtraRatio ~= 1 then
			return val * RF._xfExtraRatio
		end
		return val
	end,
})

-- Settings view of a button by its kind (btn.rfKind): "party" (and the
-- party pets / party targets) read the party view, "extra" the extra view,
-- everything else (raid, boss, raid pets, preview raid) the raid view.
-- A preview button may carry its own view in btn.rfSettings.
function RF.SettingsFor(btn)
	if btn then
		if btn.rfSettings then
			return btn.rfSettings
		end
		local kind = btn.rfKind
		if kind == "party" or kind == "partyPet" or kind == "partyTarget" then
			return RF._scaledPartyProxy
		elseif kind == "extra" then
			return RF._scaledExtraProxy
		end
	end
	return RF._scaledProfile
end

-- Buff Manager scale of a button (not gated on Auto Resize Icons like retail).
function RF.BmScaleFor(btn)
	local kind = btn and btn.rfKind
	if kind == "party" or kind == "partyPet" then
		return RF._partyBmScale or 1
	elseif kind == "extra" then
		return (RF._bmScale or 1) * (RF._xfBmScale or 1)
	end
	return RF._bmScale or 1
end

-------------------------------------------------------------------------------
--  Timers (5.4.8 has no C_Timer): After / NewTimer / NewTicker return
--  handles with :Cancel(); all ride one OnUpdate.
-------------------------------------------------------------------------------
do
	local tasks = {}
	local driver = CreateFrame("Frame")
	driver:Hide()
	local handle = {}
	handle.__index = handle
	handle.Cancel = function(self)
		self.cancelled = true
	end
	handle.IsCancelled = function(self)
		return self.cancelled == true
	end
	driver:SetScript("OnUpdate", function(self)
		local now = GetTime()
		local i = 1
		while i <= #tasks do
			local t = tasks[i]
			if t.cancelled then
				table.remove(tasks, i)
			elseif now >= t.at then
				if t.interval then
					t.at = now + t.interval
					i = i + 1
				else
					table.remove(tasks, i)
				end
				local ok, err = pcall(t.fn, t)
				if not ok then
					geterrorhandler()(err)
				end
			else
				i = i + 1
			end
		end
		if #tasks == 0 then
			self:Hide()
		end
	end)
	local function Add(t)
		setmetatable(t, handle)
		tasks[#tasks + 1] = t
		driver:Show()
		return t
	end
	function RF.After(delay, fn)
		return Add({ at = GetTime() + (delay or 0), fn = fn })
	end
	RF.NewTimer = RF.After
	function RF.NewTicker(interval, fn)
		return Add({ at = GetTime() + interval, interval = interval, fn = fn })
	end
end

-- Run once after combat (protected work asked for in combat), keyed.
do
	local pending, order = {}, {}
	local f = CreateFrame("Frame")
	f:RegisterEvent("PLAYER_REGEN_ENABLED")
	f:SetScript("OnEvent", function()
		local list, keys = pending, order
		pending, order = {}, {}
		for i = 1, #keys do
			local fn = list[keys[i]]
			if fn then
				local ok, err = pcall(fn)
				if not ok then
					geterrorhandler()(err)
				end
			end
		end
	end)
	-- Runs fn now when out of combat, else once after combat.
	function RF.AfterCombat(key, fn)
		if not InCombatLockdown() then
			fn()
			return true
		end
		if not pending[key] then
			order[#order + 1] = key
		end
		pending[key] = fn
		return false
	end
end

-------------------------------------------------------------------------------
--  Pixels and borders (EllesmereUI "solid" pixel border)
-------------------------------------------------------------------------------
-- One physical pixel in the units of `frame`.
function RF.PixelFor(frame)
	local h = ns.PhysicalHeight and ns.PhysicalHeight() or 1080
	return 768 / h / ((frame and frame:GetEffectiveScale()) or UIParent:GetEffectiveScale())
end

function RF.Snap(v, frame)
	local px = RF.PixelFor(frame)
	return floor(v / px + 0.5) * px
end

-- Four edge textures drawn inside host (or outside with `outside`).
function RF.CreateEdges(parent, host, layer, sub)
	local e = { host = host or parent }
	for i = 1, 4 do
		e[i] = parent:CreateTexture(nil, layer or "OVERLAY", nil, sub or 2)
		e[i]:SetTexture(1, 1, 1, 1)
	end
	return e
end

-- sizePx: thickness in physical pixels. outside: grow out of the host.
function RF.LayoutEdges(e, sizePx, r, g, b, a, outside)
	local host = e.host
	if not sizePx or sizePx <= 0 then
		for i = 1, 4 do
			e[i]:Hide()
		end
		e.size = 0
		return
	end
	local size = sizePx * RF.PixelFor(host)
	local o = outside and size or 0
	e.size = size
	e[1]:ClearAllPoints()
	e[1]:SetPoint("TOPLEFT", host, "TOPLEFT", -o, o)
	e[1]:SetPoint("TOPRIGHT", host, "TOPRIGHT", o, o)
	e[1]:SetHeight(size)
	e[2]:ClearAllPoints()
	e[2]:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", -o, -o)
	e[2]:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", o, -o)
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
		e[i]:Show()
	end
end

function RF.SetEdgesColor(e, r, g, b, a)
	for i = 1, 4 do
		e[i]:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
	end
end

-- Border frame over host at host level + levelOffset; :Apply(sizePx, r,g,b,a).
function RF.CreateBorder(host, levelOffset, outside)
	local f = CreateFrame("Frame", nil, host)
	f:SetAllPoints(host)
	f:SetFrameLevel(min(host:GetFrameLevel() + (levelOffset or 2), 127))
	f.edges = RF.CreateEdges(f, host, "OVERLAY", 7)
	f.Apply = function(self, sizePx, r, g, b, a)
		RF.LayoutEdges(self.edges, sizePx, r, g, b, a, outside)
	end
	f.SetColor = function(self, r, g, b, a)
		RF.SetEdgesColor(self.edges, r, g, b, a)
	end
	return f
end

-------------------------------------------------------------------------------
--  Fonts (Global Settings > Fonts, module key "raidFrames")
-------------------------------------------------------------------------------
function RF.FontPath()
	return (ns.GetFontPath and ns.GetFontPath("raidFrames")) or ns.FONT or "Fonts\\FRIZQT__.TTF"
end

function RF.SetFont(fs, size, flags)
	size = max(1, floor((size or 11) + 0.5))
	if ns.ApplyModuleFont then
		ns.ApplyModuleFont(fs, size, "raidFrames", flags)
	else
		fs:SetFont(RF.FontPath(), size, flags or "OUTLINE")
	end
end

-- Icon texts (stacks, durations): the icon text outline of the font settings.
function RF.SetIconFont(fs, size)
	local flags = ns.GetIconTextOutlineFlag and ns.GetIconTextOutlineFlag("raidFrames") or "OUTLINE"
	RF.SetFont(fs, size, flags)
end

-- New FontString with a font set (5.4.8 errors on SetText without one).
function RF.NewText(parent, size, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	RF.SetFont(fs, size or 11)
	fs:SetWordWrap(false)
	return fs
end

-------------------------------------------------------------------------------
--  Bar textures ("none" = flat, a retail EllesmereUI texture key, or
--  "sm:<name>" = a LibSharedMedia status bar)
-------------------------------------------------------------------------------
RF.BAR_TEXTURE_ORDER = {
	"none", "melli", "atrocity", "fade", "fade-right", "thin-line-top", "thin-line-bottom",
	"beautiful", "plating", "divide", "glass", "gradient-lr", "gradient-rl", "gradient-bt", "gradient-tb",
	"matte", "sheer", "pixels-fill", "pixels-dark", "pixels-bg", "blinkii-diamonds", "kringel-window",
}
RF.BAR_TEXTURE_NAMES = {
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
RF.LSM = LSM

function RF.TexturePath(key)
	if not key or key == "none" or key == "" then
		return RF.WHITE
	end
	if key:sub(1, 3) == "sm:" then
		local lsm = LSM()
		return (lsm and lsm:Fetch("statusbar", key:sub(4), true)) or RF.WHITE
	end
	if RF.BAR_TEXTURE_NAMES[key] then
		return RF.MEDIA .. "textures\\" .. key
	end
	return RF.WHITE
end
ERF.TexturePath = RF.TexturePath

function ERF.TextureLabel(key)
	if key and key:sub(1, 3) == "sm:" then
		return key:sub(4)
	end
	return RF.BAR_TEXTURE_NAMES[key or "none"] or "None"
end

-- { {name=, value=}, ... } for the settings dropdowns.
function ERF.TextureItems()
	local items = {}
	for _, key in ipairs(RF.BAR_TEXTURE_ORDER) do
		items[#items + 1] = { name = RF.BAR_TEXTURE_NAMES[key], value = key }
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

-- Absorb overlay styles (retail ABSORB_STYLE_TEX).
RF.ABSORB_STYLE_ORDER = {
	"none", "striped", "stripedReversed", "stripedThick", "stripedThickR", "clean", "blizzard",
	"largeStripes", "largeStripesR", "pixelsShield", "pixelsShieldEdge", "pixelsShieldFill",
}
RF.HEAL_ABSORB_STYLE_ORDER = {
	"none", "striped", "stripedReversed", "stripedThick", "stripedThickR", "clean", "blizzard",
	"largeOutlinedStripes", "largeOutlinedStripesR", "largeStripes", "largeStripesR", "pixelsShield",
}
RF.ABSORB_STYLE_NAMES = {
	none = "None", striped = "Striped", stripedReversed = "Striped Reversed", stripedThick = "Striped Thick",
	stripedThickR = "Striped Thick Reversed", clean = "Clean (Flat)", blizzard = "Blizzard",
	largeOutlinedStripes = "Large Outlined Stripes", largeOutlinedStripesR = "Large Outlined Stripes R",
	largeStripes = "Large Stripes", largeStripesR = "Large Stripes R", pixelsShield = "Pixels Shield",
	pixelsShieldEdge = "Pixels Shield Edge", pixelsShieldFill = "Pixels Shield Fill",
	maxHealthStripes = "Max Health Stripes",
}
local ABSORB_FILES = {
	striped = "striped3", stripedReversed = "striped-5-reversed", stripedThick = "striped-thick",
	stripedThickR = "striped-thick-r", blizzard = "blizzard", largeOutlinedStripes = "large-habsorb-left",
	largeOutlinedStripesR = "large-habsorb-right", largeStripes = "large-absorb-left",
	largeStripesR = "large-absorb-right", pixelsShield = "pixels-shield", pixelsShieldEdge = "pixels-shield-edge",
	pixelsShieldFill = "pixels-shield-fill",
}
-- Styles drawn tiled (SetHorizTile) instead of stretched.
RF.ABSORB_TILED = {
	stripedReversed = true, stripedThick = true, stripedThickR = true, largeStripes = true, largeStripesR = true,
	largeOutlinedStripes = true, largeOutlinedStripesR = true, pixelsShieldFill = true, maxHealthStripes = true,
}
-- Retail per-style alpha (ABSORB_STYLE_ALPHA).
RF.ABSORB_STYLE_ALPHA = { striped = 0.8, stripedReversed = 0.8, clean = 0.3, blizzard = 0.8 }

function RF.AbsorbTexture(style)
	if style == "clean" then
		return RF.WHITE
	end
	if style == "maxHealthStripes" then
		return RF.MEDIA .. "striped-maxhp"
	end
	local file = style and ABSORB_FILES[style]
	if file then
		return RF.MEDIA .. "shields\\" .. file
	end
	return RF.TexturePath(style)
end

-------------------------------------------------------------------------------
--  Colors
-------------------------------------------------------------------------------
local DEFAULT_ACCENT = { 12 / 255, 210 / 255, 157 / 255 }

function RF.Accent()
	if ns.ResolveAccent then
		local r, g, b = ns.ResolveAccent()
		if r then
			return r, g, b
		end
	end
	return DEFAULT_ACCENT[1], DEFAULT_ACCENT[2], DEFAULT_ACCENT[3]
end

-- EllesmereUI class palette (retail EllesmereUI.GetClassColor defaults).
RF.CLASS_COLORS = {
	DEATHKNIGHT = { 0.77, 0.12, 0.23 }, DRUID = { 1.00, 0.49, 0.04 }, HUNTER = { 0.67, 0.83, 0.45 },
	MAGE = { 0.25, 0.78, 0.92 }, MONK = { 0.00, 1.00, 0.60 }, PALADIN = { 0.96, 0.55, 0.73 },
	PRIEST = { 1, 1, 1 }, ROGUE = { 1.00, 0.96, 0.41 }, SHAMAN = { 0.00, 0.44, 0.87 },
	WARLOCK = { 0.53, 0.53, 0.93 }, WARRIOR = { 0.78, 0.61, 0.43 },
}

function RF.ClassColor(class)
	local c = class and RF.CLASS_COLORS[class]
	if c then
		return c[1], c[2], c[3]
	end
	local b = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if b then
		return b.r, b.g, b.b
	end
	return 1, 1, 1
end

-- Power colors by power token (retail DEFAULT_POWER_COLORS + Mists powers).
RF.POWER_COLORS = {
	MANA = { 0, 0.55, 1 }, RAGE = { 0.9, 0.15, 0.15 }, FOCUS = { 0xDD / 255, 0x92 / 255, 0x37 / 255 },
	ENERGY = { 1, 0.96, 0.41 }, RUNIC_POWER = { 0xC4 / 255, 0x1F / 255, 0x3B / 255 },
	DEMONIC_FURY = { 0xA3 / 255, 0x30 / 255, 0xC9 / 255 }, ECLIPSE = { 0xFF / 255, 0x7D / 255, 0x0A / 255 },
}
RF.POWER_TOKENS = { [0] = "MANA", [1] = "RAGE", [2] = "FOCUS", [3] = "ENERGY", [6] = "RUNIC_POWER" }

function RF.PowerColor(token)
	local c = token and RF.POWER_COLORS[token]
	if c then
		return c[1], c[2], c[3]
	end
	local blizz = token and PowerBarColor and PowerBarColor[token]
	if blizz and blizz.r then
		return blizz.r, blizz.g, blizz.b
	end
	return 0, 0.55, 1
end

-- Dark Mode fill / background (retail Dark Mode palette defaults).
RF.DARK_FILL = { 0x11 / 255, 0x11 / 255, 0x11 / 255 }
RF.DARK_BG = { 0x4f / 255, 0x4f / 255, 0x4f / 255 }

-- Retail DISPEL_COLORS ("" = bleed / no dispel type) and the settings keys.
RF.DISPEL_COLORS = {
	Magic = { r = 0.349, g = 0.475, b = 1.0 },
	Curse = { r = 0.636, g = 0.0, b = 0.64 },
	Disease = { r = 0.671, g = 0.384, b = 0.098 },
	Poison = { r = 0.0, g = 0.706, b = 0.286 },
	[""] = { r = 0.75, g = 0.15, b = 0.15 },
}
local DISPEL_KEYS = {
	Magic = "dispelColorMagic", Curse = "dispelColorCurse", Disease = "dispelColorDisease",
	Poison = "dispelColorPoison", [""] = "dispelColorBleed",
}
RF.DISPEL_COLOR_KEYS = DISPEL_KEYS

-- Color of a dispel type from settings view s (falls back to the defaults).
function RF.GetDispelColor(dtype, s)
	dtype = dtype or ""
	local key = DISPEL_KEYS[dtype]
	local c = (key and s and s[key]) or RF.DISPEL_COLORS[dtype] or RF.DISPEL_COLORS[""]
	return c.r, c.g, c.b
end

-------------------------------------------------------------------------------
--  Roles and role icons. Retail atlases do not exist on 5.4.8: the atlas
--  styles use the LFG role art of this client.
-------------------------------------------------------------------------------
local LFG_ROLES = "Interface\\LFGFrame\\UI-LFG-ICON-ROLES"
local LFG_PORTRAIT_ROLES = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
local ROLE_COORDS = {
	TANK = { 0, 19 / 64, 22 / 64, 41 / 64 },
	HEALER = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 },
	DAMAGER = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 },
}
RF.ROLE_ICON_STYLES = {
	modern = { file = true, TANK = RF.MEDIA .. "tank-modern", HEALER = RF.MEDIA .. "healer-modern", DAMAGER = RF.MEDIA .. "dps-modern" },
	modernCircle = { sheet = LFG_PORTRAIT_ROLES },
	styled = { sheet = LFG_ROLES },
	classicCircle = { sheet = LFG_PORTRAIT_ROLES },
	classic = { sheet = LFG_PORTRAIT_ROLES },
	blizzDefault = { sheet = LFG_ROLES },
	blizzLight = { file = true, TANK = RF.MEDIA .. "tank", HEALER = RF.MEDIA .. "healer", DAMAGER = RF.MEDIA .. "dps" },
	pixels = { file = true, TANK = RF.MEDIA .. "pixels-tank", HEALER = RF.MEDIA .. "pixels-healer", DAMAGER = RF.MEDIA .. "pixels-dps" },
}
RF.ROLE_ICON_STYLE_ORDER = { "none", "modern", "modernCircle", "styled", "classicCircle", "classic", "blizzDefault", "blizzLight", "pixels" }

-- Puts the icon of role (TANK/HEALER/DAMAGER) in style on texture. false = none.
function RF.ApplyRoleIcon(texture, role, style)
	local map = RF.ROLE_ICON_STYLES[style or "modern"]
	if not map or not ROLE_COORDS[role] then
		return false
	end
	if map.file then
		texture:SetTexture(map[role])
		texture:SetTexCoord(0, 1, 0, 1)
	else
		texture:SetTexture(map.sheet)
		local c = ROLE_COORDS[role]
		texture:SetTexCoord(c[1], c[2], c[3], c[4])
	end
	return true
end

-- Role of the player by spec (5.4.8: GetSpecializationRole).
function RF.PlayerSpecRole()
	local idx = GetSpecialization and GetSpecialization()
	if idx and GetSpecializationRole then
		return GetSpecializationRole(idx)
	end
	return nil
end

-- Group role of a unit: assigned role, else the player's spec role, else
-- DAMAGER (retail EllesmereUI.UnitEffectiveRole).
function RF.UnitRole(unit)
	if not unit then
		return "DAMAGER"
	end
	local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
	if role and role ~= "NONE" then
		return role
	end
	if UnitIsUnit(unit, "player") then
		return RF.PlayerSpecRole() or "DAMAGER"
	end
	return "DAMAGER"
end

-------------------------------------------------------------------------------
--  Specializations (5.4.8 has the retail spec IDs)
-------------------------------------------------------------------------------
function RF.SpecID()
	local idx = GetSpecialization and GetSpecialization()
	if not idx then
		return nil
	end
	return (GetSpecializationInfo(idx))
end

-------------------------------------------------------------------------------
--  Numbers (Blizzard AbbreviateNumbers look: 950, 9.5K, 95K, 9.5M)
-------------------------------------------------------------------------------
function RF.Abbrev(v)
	v = v or 0
	local a = abs(v)
	local s
	if a >= 1e9 then
		s = format("%.1fB", v / 1e9)
	elseif a >= 1e7 then
		s = format("%dM", floor(v / 1e6))
	elseif a >= 1e6 then
		s = format("%.1fM", v / 1e6)
	elseif a >= 1e4 then
		s = format("%dK", floor(v / 1e3))
	elseif a >= 1e3 then
		s = format("%.1fK", v / 1e3)
	else
		s = tostring(floor(v + 0.5))
	end
	return (s:gsub("%.0([KMB])", "%1"))
end

function RF.Hex(r, g, b)
	return format("%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

-------------------------------------------------------------------------------
--  9-point anchors (retail position keys: topleft, top, ..., bottomright)
-------------------------------------------------------------------------------
RF.POS_POINT = {
	topleft = "TOPLEFT", top = "TOP", topright = "TOPRIGHT",
	left = "LEFT", center = "CENTER", right = "RIGHT",
	bottomleft = "BOTTOMLEFT", bottom = "BOTTOM", bottomright = "BOTTOMRIGHT",
}
function RF.PosPoint(pos)
	return RF.POS_POINT[pos or "center"] or (type(pos) == "string" and pos:upper()) or "CENTER"
end

-------------------------------------------------------------------------------
--  Apply: the settings call ns.applyHooks after every change. Files register
--  their refresh with RF.OnApply(fn, order) (lower order runs first:
--  10 headers / layout, 20 buttons, 30 auras, 40 extras, 50 others).
-------------------------------------------------------------------------------
RF.applyFns = {}
function RF.OnApply(fn, order)
	RF.applyFns[#RF.applyFns + 1] = { fn = fn, order = order or 50, n = #RF.applyFns }
	table.sort(RF.applyFns, function(a, b)
		if a.order ~= b.order then
			return a.order < b.order
		end
		return a.n < b.n
	end)
end

function ERF:ApplyAll()
	if not self.db or not self.started then
		return
	end
	RF._NormalizePartySyncSections()
	for i = 1, #RF.applyFns do
		local ok, err = pcall(RF.applyFns[i].fn)
		if not ok then
			geterrorhandler()(err)
		end
	end
end

ns.applyHooks = ns.applyHooks or {}
table.insert(ns.applyHooks, function()
	ERF:ApplyAll()
end)
