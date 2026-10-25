-------------------------------------------------------------------------------
--  EllesmereUINameplates.lua  (5.4.8 port of the EllesmereUI Nameplates,
--  retail 9.3.8)
--
--  The defaults (the retail keys and values, copied as they are), the saved
--  settings (EllesmereUINameplatesDB.profile, like the retail profile), the
--  first-run seed with the retail "Naowh" profile, and the helpers the other
--  files share: timers (5.4.8 has no C_Timer), pixel borders, fonts, bar and
--  overlay textures, target arrow styles, the interrupt spell and the execute
--  window of the player.
--
--  Files: this one, EUI_Nameplates_Plates.lua (finds the Blizzard plates and
--  reads them), EUI_Nameplates_Colors.lua (health bar colors), _Display.lua
--  (the look of a plate), _Cast.lua (cast bar), _Auras.lua (debuffs, buffs,
--  crowd control), _Init.lua (events, start-up, /enp).
--
--  5.4.8 nameplates have no unit token: a plate is read from the Blizzard
--  plate itself (health bar value and color, name, level, elite and boss
--  icons, threat glow, raid icon, cast bar). Things that need the unit
--  (caster type, quest mob, auras, cast target) are known while the plate is
--  the target, the mouseover or the focus, and are kept by GUID / name after.
-------------------------------------------------------------------------------
local addonName, P = ...
local ns = EllesmereUI

local ENP = {}
ns.ENP = ENP
P.ENP = ENP
P.ns = ns

local floor, max, min = math.floor, math.max, math.min

P.MEDIA = "Interface\\AddOns\\" .. addonName .. "\\media\\"
P.WHITE = "Interface\\Buttons\\WHITE8X8"

-------------------------------------------------------------------------------
--  Defaults (retail EllesmereUINameplates.lua `defaults`, same keys and
--  values; the WoW Forever switches take their retail values)
-------------------------------------------------------------------------------
local defaults = {
    -- EUI_DEBUFF_COLORS: optional player-debuff tinting (Colors page). The
    -- per-class lists ("debuffColors" .. class token) have no defaults: unset
    -- is an empty list (EllesmereUINameplates_DebuffColors.lua).
    debuffColorsEnabled = false,
    debuffColorsPlayerOnly = true,
    -- Debuff Coloring "Color Border": the color goes on the plate's border
    -- instead of its health bar, plus whole pixels added to a Basic or Custom
    -- Solid border while it shows.
    debuffColorsBorder = false,
    debuffColorsBorderExtra = 0,
    -- Blizzard Style (Global Settings > Style): the stock nameplate's bar,
    -- background, selection and cast bar art on our plates with every feature
    -- intact. Default OFF; reload-gated.
    useBlizzardStyle = false,
    -- Classic WoW UI (Global Settings > Style): the flat vanilla plate -- the
    -- user's fill inside a 1px black edge, square icons -- with every feature
    -- intact. Default OFF; reload-gated. Set together with useBlizzardStyle
    -- it wins.
    useClassicStyle = false,
    absorbStyle = "blizzard",
    absorbCleanAlpha = 30,
    absorbColor = { r = 1, g = 1, b = 1 },
    -- Shield placement, the unit frames' set: overlay / overlayReverse / right / left.
    absorbEdgeMode = "overlay",
    hostile = { r = 0.39, g = 0.11, b = 0.09 },
    neutral = { r = 0.81, g = 0.72, b = 0.19 },
    tapped  = { r = 0.50, g = 0.50, b = 0.50 },
    focus = { r = 0.051, g = 0.820, b = 0.620 },
    focusColorEnabled = true,
    focusOverlayTexture = "striped-v2",
    focusOverlayAlpha = 1.0,
    focusOverlayColor = { r = 1.0, g = 1.0, b = 1.0 },
    focusOverlayFullBgAlpha = false,  -- on: empty bar shows focus texture at full opacity (vs dimmed 30% default)
    focusOverlayNoTint = false,  -- on: overlay tints with the bar's health color instead of focusOverlayColor
    focusLetterEnabled = false,
    focusLetterAnchor = "CENTER",
    focusLetterX = 0,
    focusLetterY = 0,
    focusLetterSize = 18,
    target = { r = 0.459, g = 0.890, b = 0.580 },
    targetColorEnabled = false,
    targetOverlayTexture = "none",
    targetOverlayAlpha = 1.0,
    targetOverlayColor = { r = 1.0, g = 1.0, b = 1.0 },
    targetOverlayFullBgAlpha = false,  -- on: empty bar shows target texture at full opacity instead of dimmed 30%
    targetOverlayNoTint = false,  -- mirrors focusOverlayNoTint, for the target overlay
    hoverOverlayTexture = "none",
    caster  = { r = 0.231, g = 0.510, b = 0.965 },
    miniboss = { r = 0.518, g = 0.243, b = 0.984 },
    boss = { r = 0.518, g = 0.243, b = 0.984 },
    enemyInCombat = { r = 0.800, g = 0.137, b = 0.137 },
    -- "Mini Enemies" (non-elite trash) has no static default: unset views enemyInCombat, so it
    -- starts identical to "Enemies" (see GetReactionColor).
    miniColoringMPlusOnly = false,  -- on = Mini Enemies color only in 5-mans; off = everywhere
    -- Simple Coloring When Not In M+ (inline cog on Enemy Types): outside 5-mans, mob-type colors (Mini
    -- Enemies/Casters/Mini-Bosses/Bosses) collapse to owBasicColor; Neutral stays own color.
    owBasicColoring = false,
    owBasicColor = { r = 0.800, g = 0.137, b = 0.137 },
    darkenEnemiesOOC = true,
    darkenOOCRecolor = false,  -- Modify Out of Combat "Change Color": recolor OOC enemies rather than dimming
    darkenOOCColor   = { r = 0.5, g = 0.5, b = 0.5 },
    -- Threat Colors channel multi-check: which surfaces carry the threat color.
    -- Health Bar is the historical single channel (on by default, so existing profiles
    -- keep their exact colors); Border and Text are opt-in SECOND channels that carry
    -- threat independently of the bar, so the bar can keep showing the mob type
    -- (Caster/Mini-Boss/Boss) while the border/name shows aggro -- the two-signal
    -- layout. With Health Bar off, GetReactionColor skips the whole threat arm and
    -- clears isThreatUnit, so the low-priority has-aggro/no-aggro steps stop firing on
    -- the bar as well and it is purely mob-type/reaction colored.
    threatColorHealth = true,
    threatColorBorder = false,
    threatColorName   = false,
    -- Show Threat Colors: where the threat colors apply -- "never", "instances" (party/raid
    -- instances and delves) or "always". Per client: WoW Forever defaults to "always".
    threatColorMode = "instances",
    tankHasAggro = { r = 0.05, g = 0.82, b = 0.62 },
    tankHasAggroEnabled = false,
    tankHasAggroOverrideMobType = false,  -- on: overrides Mini-Boss/Caster (above priority step 7); off = stays low
    tankHasAggroOverrideBoss = true,  -- on (default): overrides Boss color; off = held just below Boss
    classicTankAggro = false,
    tankLosingAggro = { r = 0.81, g = 0.72, b = 0.19 },
    tankNoAggro = { r = 1.00, g = 0.22, b = 0.17 },
    dpsNearAggro = { r = 0.81, g = 0.72, b = 0.19 },
    threatNearAggroGlow = false,  -- Non-Tank Threat cog: red glow while the Near Aggro color is active
    threatPctEnabled = false,  -- Threat % text: WoW Forever only
    threatPctPosition = "CENTER",
    threatPctColorByThreat = true,
    threatPctSize = 10,
    threatPctXOffset = 0,
    threatPctYOffset = 0,
    threatPctMode = "percent",  -- "gap": the target's plate shows the Threat Gap
    threatGapAheadColor = { r = 0.30, g = 0.90, b = 0.30 },
    threatGapBehindColor = { r = 0.35, g = 0.60, b = 1.00 },
    dpsHasAggro = { r = 1.00, g = 0.50, b = 0.00 },
    offTankAggro = { r = 0.188, g = 0.761, b = 0.812 },
    offTankAggroEnabled = true,
    dpsNoAggro = { r = 0.35, g = 0.75, b = 0.35 },
    dpsNoAggroEnabled = false,
    dpsNoAggroOverrideMiniBoss = false,  -- on: overrides Mini-Boss (above priority step 7); off = stays low
    dpsNoAggroOverrideCaster = false,  -- on: overrides Caster (above priority step 8); off = Casters keep own color
    dpsNoAggroOverrideBoss = true,  -- on (default, the pre-toggle behaviour): overrides Boss (step 10b); off = Bosses keep own color
    interruptReady = { r = 0.92, g = 0.35, b = 0.20 },  
    castBar = { r = 0.70, g = 0.40, b = 0.90 },
    interruptMidCastEnabled = false,
    interruptMidCastColor = { r = 0.318, g = 0.820, b = 0.357 },
    castBarUninterruptible = { r = 0.45, g = 0.45, b = 0.45 },
    castBarImportant = { r = 1, g = 0.2, b = 0.2 },
    importantCastColorEnabled = false,
    castBarShieldEnabled = true,
    interruptedFlashEnabled = true,
    interruptedFlashColor = { r = 0.8, g = 0.0, b = 0.0 },
    showCastLockoutAsCrowdControl = false,
    healthBarHeight = 17,
    friendlyNameOnly = true,
    friendlyNameOnlyYOffset = -20,
    friendlyNameSize = 15,
    friendlyPlateYOffset = 0,
    friendlyHealthBarHeight = 17,
    friendlyHealthBarWidth = 150,
    showFriendlyNPCs = false,
    showNPCTitles = true,
    showFriendlyPlayers = true,
    friendlyClickThrough = false,
    friendlyShowDefaultNames = false,
    classColorFriendly = true,
    friendlyNameClassColor = false,
    -- Target Border Effects (Friendly Nameplate Settings cog): the target Border Color
    -- and Border Size effects on friendly plates too.
    friendlyTargetBorderFx = false,
    friendlyBarColor = { r = 0.314, g = 0.800, b = 0.408 },
    friendlyNPCColor = { r = 0, g = 1, b = 0 },
    friendlyNPCNameColor = { r = 0, g = 1, b = 0 },
    friendlyNPCTitleColor = { r = 0, g = 1, b = 0, a = 0.7 },
    friendlyNPCNameSize = 13,
    friendlyNPCTitleSize = 10,
    friendlyNameTextSize = 12,
    friendlyBelowName = "none",
    friendlyBelowNameSize = 12,
    friendlyBelowNameColor = { r = 0.8, g = 0.8, b = 0.8 },
    friendlyBelowNameClassColor = false,
    friendlyBelowNameGuildBrackets = true,
    showEnemyPets = false,
    font = "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Expressway.TTF",
    textSlotTop = "enemyName",
    textSlotRight = "healthPercent",
    -- WoW Forever shows the level by default (retail leaves the slot empty).
    textSlotLeft = "none",
    textSlotCenter = "none",
    textSlotBottomLeft = "none",
    textSlotBottomRight = "none",
    showTargetArrows = false,
    targetArrowDouble = false,
    targetArrowScale = 1.0,
    targetArrowColor = { r = 1, g = 1, b = 1 },
    targetArrowClassColor = false,
    showClassPower = false,
    classPowerPos = "bottom",
    classPowerYOffset = 1,
    classPowerXOffset = 0,
    -- The 8x3 base pip is reported as too small to read on Forever, where this is
    -- the target-side display rather than a second one. The Size slider (0.5 to
    -- 4.0) still overrides it.
    classPowerScale = 1.0,
    classPowerClassColors = true,
    classPowerCustomColor = { r = 1.00, g = 0.84, b = 0.30 },
    classPowerBgColor = { r = 0.082, g = 0.082, b = 0.082, a = 1.0 },
    classPowerEmptyColor = { r = 0.2, g = 0.2, b = 0.2, a = 1.0 },
    classPowerGap = 2,
    classPowerShape = "rectangle",  -- rectangle | square | circle | diamond | hexagon | shield
    classPowerBorder = false,
    classPowerBorderColor = { r = 0, g = 0, b = 0, a = 1.0 },
    classPowerBorderSize = 1,
    healthBarWidth = 6,
    stackSpacingScale = 100,
    stackingEnabled = true,
    stackingFriendly = false,
    hitboxScaleX = 100,
    hitboxScaleY = 100,
    nameplateYOffset = 0,
    enemyNameTextSize = 11,
    enemyNameTextReactionColor = false,
    debuffTimerColor = { r = 1, g = 1, b = 1 },
    auraTextPosition = "topleft",
    debuffTimerPosition = "topleft",
    buffTimerPosition = "topleft",
    ccTimerPosition = "topleft",
    auraDurationTextSize = 11,
    auraDurationTextX = 0,
    auraDurationTextY = 0,
    auraDurationTextColor = { r = 1, g = 1, b = 1 },
    auraStackTextSize = 11,
    auraStackTextColor = { r = 1, g = 1, b = 1 },
    auraStackTextPosition = "bottomright",
    auraStackTextX = 0,
    auraStackTextY = 0,
    debuffSlot = "top",
    buffSlot = "left",
    ccSlot = "right",
    debuffYOffset = 2,
    sideAuraXOffset = 2,
    nameYOffset = 0,
    auraSpacing = 2,
    debuffSpacing = 2,  -- per-element icon gap; all default to the global auraSpacing value
    buffSpacing = 2,
    ccSpacing = 2,
    debuffCropIcons = false,  -- cropped icons: trim top/bottom to rectangular (80% of width), mirrors Unit Frames
    buffCropIcons = false,
    ccCropIcons = false,
    debuffCropPercent = 10,  -- per-side trim % for cropped mode (5-25); 10 == the fixed 80%-of-width crop
    buffCropPercent = 10,
    ccCropPercent = 10,
    hideDebuffIconBorder = false,
    hideBuffIconBorder = false,
    hideCCIconBorder = false,
    debuffIconSize = 26,
    buffIconSize = 24,
    buffTextSize = 12,
    buffTextColor = { r = 1, g = 1, b = 1 },
    ccIconSize = 24,
    ccTextSize = 12,
    ccTextColor = { r = 1, g = 1, b = 1 },
    targetGlowStyle = "ellesmereui",
    -- Target "Border Color" tint for the custom border when Border Color toggle is on.
    -- targetGlowEllesmereUI/targetGlowBorderColor/targetGlowHighlight deliberately have NO
    -- default: they stay nil so getters can live-convert from the targetGlowStyle string.
    targetBorderColor = { r = 1, g = 1, b = 1 },
    targetGlowColor = { r = 0.4117, g = 0.6667, b = 1.0 },  -- "Glow Color" for the EUI background glow (signature blue)
    targetGlowAlpha = 1.0,
    targetHighlightColor = { r = 1, g = 1, b = 1 },  -- Target Highlight wash color/opacity
    targetHighlightAlpha = 0.20,
    nameRaidMarkerEnabled = false,
    nameRaidMarkerSize = 14,
    raidMarkerPos = "topright",
    raidMarkerSize = 24,
    classificationSlot = "topleft",
    classificationShowInInstances = false,  -- Rare/Quest "Show In Instances" (slot cog): lifts the open-world-only gate in UpdateClassification + IsQuestMob
    -- Faction badge (Horde/Alliance), a Core Positions slot element; rules in ns.NP_FactionBadge.
    factionSlot = "none",
    factionStyle = "pvp",  -- Icon Style: a key of EllesmereUI.FACTION_ART
    classificationIncludeFaction = false,  -- "Rare/Quest + Faction": the badge shares the classification slot
    -- The classification element's two halves, each switchable in Core Positions:
    -- the Rare Indicator (elite and rare marks) and the Quest Indicator.
    classificationHideRare = false,
    classificationHideQuest = false,
    factionOppositeOnly = false,
    factionPlayersOnly = false,
    factionPvP = "dim",  -- "dim" greys unflagged units, "only" hides them, "ignore" draws both alike
    rareEliteIconSize = 20,
    castBarHeight = 17,
    castBarOffsetY = 0,
    castBarSparkEnabled = true,
    castOverlayEnabled = false,
    hideEnemyNameWhileCasting = false,
    castNameSize = 10,
    castNameColor = { r = 1, g = 1, b = 1 },
    castNameOffsetX = 0,
    castNameOffsetY = 0,
    castNameSide = "left",  -- cast bar text line side for spell name: left|right|center|none
    -- Spell name truncation: width as a % of cast bar width; wrap off = single line + ellipsis.
    castNameWidthPct = 42,
    castNameWrap = false,
    castCombineNameTarget = false,
    castTargetSize = 10,
    castTargetClassColor = true,
    castTargetColor = { r = 1, g = 1, b = 1 },
    castTargetOffsetX = 0,
    castTargetOffsetY = 0,
    castTargetSide = "right",  -- side the spell target occupies: left|right|center|none
    -- Spell target truncation: % of cast bar width + wrap toggle.
    castTargetWidthPct = 42,
    castTargetWrap = false,
    showCastTimer = true,
    castTimerSide = "right",  -- side when shown; visibility governed by showCastTimer
    castTimerSize = 10,
    castTimerColor = { r = 1, g = 1, b = 1 },
    castTimerOffsetX = 0,
    castTimerOffsetY = 0,
    -- Enemy name truncation: % of the name's computed (bar-derived) width (100 = full width
    -- minus raid-marker/classification reserves). Wrap off = single line + ellipsis, on = 2 lines.
    enemyNameWidthPct = 100,
    enemyNameWrap = false,
    enemyNameShorten = "none",  -- Shorten Enemy Names: none|abbrev|truncate
    enemyNameShortenLen = 20,  -- characters before shortening kicks in / truncation length
    targetScale = 100,
    nonTargetKeepFocus = true,
    outOfRangeAlpha = 50,
    outOfRangeMode = "disabled",
    showAllDebuffs = false,
    rangeTextEnabled = false,  -- Distance to Target Text (range bucket on the target's nameplate)
    rangeTextSize = 11,
    rangeTextOffsetX = 0,
    rangeTextOffsetY = 0,
    rangeTextColor = { r = 0.816, g = 0.357, b = 0.220 },  -- #D05B38
    maxDebuffs = 5,
    showBorder = true,
    borderSize = 1,
    borderColor = { r = 0.067, g = 0.067, b = 0.067 },
    -- "Wrap Border Around Castbar": health border extends down to enclose the cast bar while casting,
    -- forming one unified border. Fully additive: no wrap machinery runs unless enabled.
    wrapBorderCastbar = false,
    -- "Show Seam Line" (Castbar Border cog, Custom border only): a divider along the cast
    -- bar's top edge while the custom border wraps the cast bar. Read only by that wrap.
    wrapBorderSeam = false,
    -- Classic WoW UI: the level and the boss icon seated in the health
    -- border's plate. A size of 0 follows the bar's own height; read only
    -- while that style renders.
    classicLevelSize = 0, classicLevelX = 0, classicLevelY = 0,
    classicSkullSize = 0, classicSkullX = 0, classicSkullY = 0,
    -- Custom border (opt-in): shared EllesmereUI border engine (same as Unit Frames, full
    -- SharedMedia). When false, NONE of these keys are read; the simple border above renders instead.
    customBorderEnabled = false,
    customBorderTexture = "solid",
    customBorderSize = 1,
    customBorderColor = { r = 0.067, g = 0.067, b = 0.067 },
    customBorderAlpha = 1,
    customBorderBehind = false,
    pandemicGlow = false,
    pandemicGlowStyle = 1,
    pandemicGlowColor = { r = 1.0, g = 0.800, b = 0.329 },
    pandemicGlowLines = 8,
    pandemicGlowThickness = 1,
    pandemicGlowSpeed = 4,
    pandemicGlowBackground = false,
    pandemicGlowBackgroundColor = { r = 0, g = 0, b = 0 },
    lowHpGlow = false,  -- Execute Pulse Glow (Extras): red glow around plates below 30% health
    hideBloodPlagueCopies = true,  -- Extras (Blood DK only): collapse the Blood Plague copies to one debuff icon
    showSunderArmor = false,  -- Extras (Forever warriors only): Sunder Armor from any warrior on enemy plates
    dispelGlow = false,
    dispelGlowStyle = 2,
    -- Swatch display only: the getter returns nil while the user has never
    -- customized the color, and the engines render their own default (this
    -- same gold on the ABG halo). Keep the two in step.
    dispelGlowColor = { r = 1.0, g = 0.788, b = 0.137 },
    dispelGlowUseTypeColor = false,
    -- Enemy Buff Filter ("important" | "dispellable" | "showall"): unset reads
    -- as Important; WoW Forever shows every enemy buff by default.
    npEnemyBuffFilter = nil,
    castScale = 100,
    focusCastHeight = 100,
    questMobColorEnabled = false,
    questMobColor = { r = 0.157, g = 0.855, b = 0.475 },
    replaceQuestIconWithObjective = false,
    questObjectiveTextSize = 14,
    showCastIcon = true,
    castIconScale = 1,
    castIconOffsetX = 0,
    castIconOffsetY = 0,
    castbarIconInWidth = false,
    castIconOnRight = false,
    castIconFullSize = false,
    castIconTargetBorder = false,
    hideCastIconBorder = false,
    -- Icon Borders cog (Border = Custom only): the cast spell icon and the aura icons
    -- (debuffs, buffs, crowd control) wear the plate's custom border instead of their
    -- 1px edge. Read only while Border is Custom.
    castIconCustomBorder = false,
    castIconSeparator = false,
    auraIconCustomBorder = false,
    bgAlpha = 1.0,
    bgColor = { r = 0.12, g = 0.12, b = 0.12 },
    hoverColor = { r = 1, g = 1, b = 1 },
    hoverAlpha = 0.3,
    hoverOverlayFullBgAlpha = false,  -- on: empty bar shows hover texture at full opacity instead of dimmed 30%
    castBgAlpha = 0.9,
    castBgColor = { r = 0.1, g = 0.1, b = 0.1 },
    castBorderSize = 0,
    castBorderColor = { r = 0, g = 0, b = 0 },
    hashLineEnabled = false,
    hashLinePercent = 30,
    hashLineColor = { r = 1, g = 1, b = 1 },
    kickTickEnabled = true,
    kickTickColor = { r = 1, g = 1, b = 1 },
    importantCastGlow = true,
    importantCastGlowStyle = 1,
    importantCastGlowColor = { r = 1, g = 0.2, b = 0.2 },
    importantCastGlowLines = 8,
    importantCastGlowThickness = 2,
    importantCastGlowSpeed = 4,
    importantCastGlowBackground = false,
    importantCastGlowBackgroundColor = { r = 0, g = 0, b = 0 },
    -- Core Positions: slot-based size + XY offsets
    topSlotSize = 26,        topSlotXOffset = 0,      topSlotYOffset = 0,      topSlotRaiseStrata = false,
    rightSlotSize = 24,      rightSlotXOffset = 0,    rightSlotYOffset = 0,    rightSlotRaiseStrata = false,
    leftSlotSize = 24,       leftSlotXOffset = 0,     leftSlotYOffset = 0,     leftSlotRaiseStrata = false,
    toprightSlotSize = 24,   toprightSlotXOffset = 0, toprightSlotYOffset = 0, toprightSlotGrowth = "right", toprightSlotRaiseStrata = false,
    topleftSlotSize = 24,    topleftSlotXOffset = 0,  topleftSlotYOffset = 0,  topleftSlotGrowth = "left",   topleftSlotRaiseStrata = false,
    bottomSlotSize = 26,     bottomSlotXOffset = 0,   bottomSlotYOffset = 0,   bottomSlotRaiseStrata = false,
    -- Core Text Positions: slot-based size + XY offsets (WoW Forever: a larger
    -- top text, raised 3px; retail keeps 10 / 0)
    textSlotTopSize = 10,
    textSlotTopXOffset = 0,
    textSlotTopYOffset = 0,
    textSlotRightSize = 10,  textSlotRightXOffset = 0, textSlotRightYOffset = 0,
    textSlotLeftSize = 10,   textSlotLeftXOffset = 0,  textSlotLeftYOffset = 0,
    textSlotCenterSize = 10, textSlotCenterXOffset = 0, textSlotCenterYOffset = 0,
    textSlotBottomLeftSize = 10,  textSlotBottomLeftXOffset = 0,  textSlotBottomLeftYOffset = 0,
    textSlotBottomRightSize = 10, textSlotBottomRightXOffset = 0, textSlotBottomRightYOffset = 0,
    -- Core Text Positions: slot-based strata (MEDIUM = the shared text tier)
    textSlotTopStrata = "MEDIUM",  textSlotRightStrata = "MEDIUM",
    textSlotLeftStrata = "MEDIUM", textSlotCenterStrata = "MEDIUM",
    textSlotBottomLeftStrata = "MEDIUM", textSlotBottomRightStrata = "MEDIUM",
    -- Core Text Positions: slot-based colors
    textSlotTopColor = { r = 1, g = 1, b = 1 },
    textSlotRightColor = { r = 1, g = 1, b = 1 },
    textSlotLeftColor = { r = 1, g = 1, b = 1 },
    textSlotCenterColor = { r = 1, g = 1, b = 1 },
    textSlotBottomLeftColor = { r = 1, g = 1, b = 1 },
    textSlotBottomRightColor = { r = 1, g = 1, b = 1 },
    -- Core Text Positions: per-slot class colour flag, read only by ns.NP_SlotColorMode
    -- while the slot's Text Coloring mode (<slot>ColorMode, no default) is unset.
    textSlotTopClassColor = false, textSlotRightClassColor = false,
    textSlotLeftClassColor = false, textSlotCenterClassColor = false,
    textSlotBottomLeftClassColor = false, textSlotBottomRightClassColor = false,
    healthBarTexture = "none",  -- bar texture overlay
    castBarTexture = "none",
    healthTextureBg = false,  -- Textured Background (Bar Texture cog)
    castTextureBg = false,    -- Textured Background (Cast Bar Texture cog)
}

local BAR_W = 150
P.defaults = defaults
ENP.defaults = defaults
P.BAR_W = BAR_W

-------------------------------------------------------------------------------
--  First run: the retail EllesmereUI "Naowh" profile (EllesmereUIDB.profiles.
--  Naowh.addons.EllesmereUINameplates on the retail client). Retail saves
--  only what differs from the defaults, inside color tables too (a missing
--  r / g / b is the default one), so the seed is merged into the defaults.
-------------------------------------------------------------------------------
local NAOWH_SEED = {
	["absorbCleanAlpha"] = 40,
	["absorbStyle"] = "clean",
	["auraDurationTextSize"] = 14,
	["auraStackTextPosition"] = "center",
	["auraStackTextSize"] = 14,
	["auraStackTextY"] = 11,
	["auraTextPosition"] = "center",
	["bgColor"] = {
	  ["b"] = 0.10980392156863,
	  ["g"] = 0.10980392156863,
	  ["r"] = 0.10980392156863,
	},
	["boss"] = {
	  ["b"] = 0.90588235294118,
	  ["g"] = 0.4,
	  ["r"] = 0.47450980392157,
	},
	["bottomSlotRaiseStrata"] = true,
	["bottomSlotSize"] = 46,
	["bottomSlotYOffset"] = 60,
	["buffCropIcons"] = true,
	["buffDurationTextY"] = 0,
	["buffSlot"] = "topleft",
	["buffTimerPosition"] = "center",
	["castBar"] = {
	  ["b"] = 0.4313725490196079,
	  ["g"] = 0.9333333333333333,
	  ["r"] = 1,
	},
	["castBarHeight"] = 14,
	["castbarIconInWidth"] = true,
	["castBarImportant"] = {
	  ["b"] = 0,
	  ["g"] = 0.5400021927057537,
	},
	["castBarOffsetY"] = 1,
	["castBarShieldEnabled"] = false,
	["castBarSparkEnabled"] = false,
	["castBarTexture"] = "sm:NaowhGradient",
	["castBarUninterruptible"] = {
	  ["b"] = 0.6941176470588235,
	  ["g"] = 0.7333333333333333,
	  ["r"] = 0.7058823529411765,
	},
	["castBgAlpha"] = 0.7,
	["castBgColor"] = {
	  ["b"] = 0.10980392156863,
	  ["g"] = 0.10980392156863,
	  ["r"] = 0.10980392156863,
	},
	["castBorderSize"] = 1,
	["castCombineNameTarget"] = true,
	["caster"] = {
	  ["b"] = 1,
	  ["g"] = 0.97647058823529,
	  ["r"] = 0,
	},
	["castIconFullSize"] = true,
	["castIconOffsetX"] = 1,
	["castNameOffsetY"] = -5,
	["castNameSize"] = 13,
	["castNameWidthPct"] = 40,
	["castTargetOffsetY"] = -5,
	["castTargetSize"] = 13,
	["castTargetWidthPct"] = 40,
	["castTimerOffsetY"] = -5,
	["castTimerSize"] = 13,
	["ccCropIcons"] = true,
	["ccDurationTextSize"] = 16,
	["ccSlot"] = "top",
	["ccSpacing"] = 1,
	["ccTimerPosition"] = "center",
	["classificationSlot"] = "none",
	["classPowerShape"] = "circle",
	["darkenEnemiesOOC"] = false,
	["debuffCropIcons"] = true,
	["debuffSlot"] = "topright",
	["debuffSpacing"] = 0,
	["debuffTimerPosition"] = "center",
	["dispelGlowStyle"] = 1,
	["dpsHasAggro"] = {
	  ["b"] = 0.30980392156863,
	  ["g"] = 0.29803921568627,
	  ["r"] = 0.99607843137255,
	},
	["dpsNearAggro"] = {
	  ["b"] = 0.43137254901961,
	  ["g"] = 0.93333333333333,
	  ["r"] = 1,
	},
	["dpsNoAggro"] = {
	  ["b"] = 0.29803921568627,
	  ["g"] = 0.87450980392157,
	  ["r"] = 0.34509803921569,
	},
	["dpsNoAggroEnabled"] = true,
	["enemyInCombat"] = {
	  ["b"] = 0.30980392156863,
	  ["g"] = 0.29803921568627,
	  ["r"] = 0.99607843137255,
	},
	["focusColorEnabled"] = false,
	["focusLetterAnchor"] = "BOTTOMRIGHT",
	["focusLetterSize"] = 15,
	["focusLetterX"] = -2,
	["focusLetterY"] = -6,
	["focusOverlayAlpha"] = 0.5,
	["focusOverlayColor"] = {
	  ["b"] = 0,
	  ["g"] = 0,
	  ["r"] = 0,
	},
	["focusOverlayTexture"] = "striped-wide-v2",
	["healthBarHeight"] = 20,
	["healthBarTexture"] = "sm:NaowhGradient",
	["healthBarWidth"] = 70,
	["hitboxScaleX"] = 110,
	["hitboxScaleY"] = 220,
	["hoverAlpha"] = 0.6,
	["hoverOverlayFullBgAlpha"] = true,
	["hoverOverlayTexture"] = "sm:NaowhMouseover",
	["importantCastColorEnabled"] = true,
	["importantCastGlowColor"] = {
	  ["b"] = 1,
	  ["g"] = 1,
	},
	["importantCastGlowThickness"] = 1,
	["interruptedFlashColor"] = {
	  ["b"] = 0.33500056382266,
	  ["g"] = 0.33500056382266,
	  ["r"] = 1,
	},
	["interruptMidCastColor"] = {
	  ["b"] = 0.41176470588235,
	  ["g"] = 0.87450980392157,
	  ["r"] = 0.34509803921569,
	},
	["interruptReady"] = {
	  ["b"] = 0.36862745098039,
	  ["g"] = 0.36862745098039,
	  ["r"] = 1,
	},
	["lowHpGlow"] = true,
	["maxDebuffs"] = 4,
	["miniboss"] = {
	  ["b"] = 1,
	  ["g"] = 0.69019607843137,
	  ["r"] = 0,
	},
	["nameRaidMarkerEnabled"] = true,
	["nameRaidMarkerSize"] = 24,
	["neutral"] = {
	  ["b"] = 0.43137254901961,
	  ["g"] = 0.93333333333333,
	  ["r"] = 1,
	},
	["nonTargetAlpha"] = 100,
	["npAuraFilters"] = {
	  ["ccExclude"] = {

	  },
	  ["ccInclude"] = {
	    [127797] = true,
	  },
	  ["ccIncludeAnyCaster"] = {
	    [127797] = true,
	  },
	  ["debuffs"] = {
	    ["all"] = false,
	  },
	  ["exclude"] = {

	  },
	  ["fv3"] = true,
	  ["include"] = {
	    [204598] = true,
	    [257284] = true,
	    [426593] = true,
	  },
	  ["includeAnyCaster"] = {

	  },
	},
	["offTankAggro"] = {
	  ["b"] = 1,
	  ["g"] = 0.19607843137255,
	  ["r"] = 0.73333333333333,
	},
	["pandemicGlowColor"] = {
	  ["b"] = 1,
	  ["g"] = 1,
	},
	["pandemicGlowLines"] = 6,
	["pandemicGlowSpeed"] = 3,
	["questMobColor"] = {
	  ["b"] = 0.21500044591723,
	  ["g"] = 0.54469767830135,
	  ["r"] = 1,
	},
	["questMobColorEnabled"] = true,
	["raidMarkerPos"] = "none",
	["rangeTextColor"] = {
	  ["b"] = 0.45999976236371,
	  ["g"] = 0.91360007591845,
	  ["r"] = 1,
	},
	["rangeTextSize"] = 14,
	["replaceQuestIconWithObjective"] = true,
	["showCastLockoutAsCrowdControl"] = true,
	["stackSpacingScale"] = 90,
	["tankHasAggro"] = {
	  ["b"] = 0.29803921568627,
	  ["g"] = 0.87450980392157,
	  ["r"] = 0.34509803921569,
	},
	["tankHasAggroEnabled"] = true,
	["tankHasAggroOverrideBoss"] = false,
	["tankLosingAggro"] = {
	  ["b"] = 0.43137254901961,
	  ["g"] = 0.93333333333333,
	  ["r"] = 1,
	},
	["tankNoAggro"] = {
	  ["b"] = 0.30980392156863,
	  ["g"] = 0.29803921568627,
	  ["r"] = 0.99607843137255,
	},
	["target"] = {
	  ["b"] = 0,
	  ["g"] = 0.47999776996674,
	  ["r"] = 1,
	},
	["targetArrowScale"] = 1.4,
	["targetArrowStyle"] = "feathered",
	["targetGlowAlpha"] = 0.6,
	["targetGlowBorderColor"] = false,
	["targetGlowColor"] = {
	  ["g"] = 1,
	  ["r"] = 1,
	},
	["targetGlowEllesmereUI"] = true,
	["targetGlowHighlight"] = false,
	["targetGlowStyle"] = "vibrant",
	["targetHighlightAlpha"] = 0.32,
	["targetOverlayTexture"] = "sm:NaowhMouseoverArrows",
	["targetScale"] = 120,
	["textSlotLeft"] = "enemyName",
	["textSlotLeftSize"] = 14,
	["textSlotLeftXOffset"] = -1,
	["textSlotLeftYOffset"] = 9,
	["textSlotRightPctDecimal"] = false,
	["textSlotRightSize"] = 14,
	["textSlotRightYOffset"] = 9,
	["textSlotTop"] = "none",
	["topleftSlotGrowth"] = "right",
	["topleftSlotSize"] = 30,
	["topleftSlotYOffset"] = -3,
	["toprightSlotGrowth"] = "left",
	["toprightSlotSize"] = 30,
	["toprightSlotYOffset"] = -3,
	["topSlotRaiseStrata"] = true,
	["topSlotSize"] = 46,
	["topSlotYOffset"] = -16,
}

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

-- Seed values over a profile; tables are merged key by key (see the seed note).
local function MergeSeed(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" and type(dst[k]) == "table" then
			MergeSeed(dst[k], v)
		else
			dst[k] = DeepCopy(v)
		end
	end
end

-- MoP: most elite trash is 1-2 levels above the player, so the level-based
-- Mini-Boss / Boss steps (and Caster) would hide the tank aggro color on
-- nearly every mob. Tank "Has Aggro" overrides them (Has Aggro cog).
local function MopTankOverrides(profile)
	profile.tankHasAggroOverrideMobType = true
	profile.tankHasAggroOverrideBoss = true
end

local function NewProfile(seed)
	local profile = DeepCopy(defaults)
	if seed then
		MergeSeed(profile, seed)
		profile.seeded = "Naowh"
	end
	MopTankOverrides(profile)
	return profile
end

function ENP:InitDB()
	if type(EllesmereUINameplatesDB) ~= "table" then
		EllesmereUINameplatesDB = {}
	end
	local sv = EllesmereUINameplatesDB
	if type(sv.profile) ~= "table" then
		sv.profile = NewProfile(NAOWH_SEED)
	else
		ns.CopyDefaults(defaults, sv.profile)
	end
	if (tonumber(sv.version) or 0) < 2 then
		MopTankOverrides(sv.profile)
	end
	sv.version = 2
	self.db = { sv = sv, profile = sv.profile }
	P.p = sv.profile
end

-- Settings > Reset: the EllesmereUI defaults (like retail's module reset).
function ENP:ResetProfile()
	self.db.sv.profile = NewProfile(nil)
	self.db.profile = self.db.sv.profile
	P.p = self.db.profile
end

-- Settings > "Naowh" button: the retail Naowh profile again.
function ENP:ApplyNaowhProfile()
	self.db.sv.profile = NewProfile(NAOWH_SEED)
	self.db.profile = self.db.sv.profile
	P.p = self.db.profile
end

function P.Profile()
	return P.p or defaults
end

-- Profile value with the default as fallback (nil-default keys stay nil).
function P.Get(key)
	local p = P.p
	local v = p and p[key]
	if v == nil then
		v = defaults[key]
	end
	return v
end

-- Boolean value: nil reads as the default, false stays false.
function P.On(key)
	local p = P.p
	local v = p and p[key]
	if v == nil then
		v = defaults[key]
	end
	return v == true
end

function P.Color(key)
	local c = P.Get(key)
	if type(c) ~= "table" then
		return 1, 1, 1
	end
	return c.r or 1, c.g or 1, c.b or 1
end

-------------------------------------------------------------------------------
--  Timers (5.4.8 has no C_Timer): After and NewTicker (handles with
--  :Cancel()), all on one OnUpdate.
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
	function P.After(delay, fn)
		return Add({ at = GetTime() + (delay or 0), fn = fn })
	end
	function P.NewTicker(interval, fn)
		return Add({ at = GetTime() + interval, interval = interval, fn = fn })
	end
end

-- Run after combat (work that must not run in combat), keyed.
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
		if InCombatLockdown() then
			pending[key] = fn
		else
			fn()
		end
	end
end

-------------------------------------------------------------------------------
--  Pixels and borders
-------------------------------------------------------------------------------
-- One physical pixel in the units of `frame` (nameplates have their own
-- scale: WorldFrame, not UIParent).
function P.PixelFor(frame)
	local h = ns.PhysicalHeight and ns.PhysicalHeight() or 1080
	local es = (frame and frame:GetEffectiveScale()) or UIParent:GetEffectiveScale()
	if not es or es <= 0 then
		es = 1
	end
	return 768 / h / es
end

-- Four edge textures (the EllesmereUI "solid" pixel border), drawn on the
-- inside of the host. Pixel size is set by P.LayoutEdges.
function P.CreateEdges(parent, host, layer, sub)
	local e = { host = host or parent }
	for i = 1, 4 do
		e[i] = parent:CreateTexture(nil, layer or "OVERLAY", nil, sub or 7)
		e[i]:SetTexture(1, 1, 1, 1)
	end
	return e
end

-- sizePx: physical pixels; outside = true grows the border out of the host.
function P.LayoutEdges(e, sizePx, r, g, b, a, outside)
	local host = e.host
	if not sizePx or sizePx <= 0 then
		for i = 1, 4 do e[i]:Hide() end
		e.size = 0
		return
	end
	local size = sizePx * P.PixelFor(host)
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

function P.ColorEdges(e, r, g, b, a)
	for i = 1, 4 do
		e[i]:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
	end
end

-------------------------------------------------------------------------------
--  Fonts (Global Settings > Fonts, module key "nameplates")
-------------------------------------------------------------------------------
function P.FontPath()
	return (ns.GetFontPath and ns.GetFontPath("nameplates")) or "Fonts\\FRIZQT__.TTF"
end

function P.Outline()
	return (ns.GetFontOutlineFlag and ns.GetFontOutlineFlag("nameplates")) or "OUTLINE"
end

-- Icon text (aura timers and stacks): Outline Icon Text of the Fonts page.
function P.IconOutline()
	return (ns.GetIconTextOutlineFlag and ns.GetIconTextOutlineFlag("nameplates")) or "OUTLINE"
end

function P.SetFont(fs, size, flags)
	size = size or 11
	if size < 1 then
		size = 1
	end
	if ns.ApplyModuleFont then
		ns.ApplyModuleFont(fs, size, "nameplates", flags)
	else
		fs:SetFont(P.FontPath(), size, flags or "OUTLINE")
	end
end

-- New FontString with a font set (5.4.8 errors on SetText without one).
function P.NewText(parent, size, layer, sub)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY", nil, sub)
	P.SetFont(fs, size or 11)
	fs:SetWordWrap(false)
	return fs
end

-------------------------------------------------------------------------------
--  Bar textures ("none" = flat, a retail EllesmereUI texture key, or
--  "sm:<name>" = a LibSharedMedia status bar)
-------------------------------------------------------------------------------
ENP.BAR_TEXTURE_ORDER = {
	"none", "melli", "atrocity", "fade", "fade-right", "thin-line-top", "thin-line-bottom",
	"beautiful", "plating", "divide", "glass", "gradient-lr", "gradient-rl", "gradient-bt", "gradient-tb",
	"matte", "sheer", "pixels-fill", "pixels-dark", "pixels-bg", "blinkii-diamonds", "kringel-window",
}
ENP.BAR_TEXTURE_NAMES = {
	none = "None", melli = "Melli (ElvUI)", beautiful = "Beautiful", plating = "Plating", atrocity = "Atrocity",
	divide = "Divide", glass = "Glass", ["fade-right"] = "Fade Right", ["thin-line-top"] = "Thin Line Top",
	["thin-line-bottom"] = "Thin Line Bottom", fade = "Fade", ["gradient-lr"] = "Gradient Right",
	["gradient-rl"] = "Gradient Left", ["gradient-bt"] = "Gradient Up", ["gradient-tb"] = "Gradient Down",
	matte = "Matte", sheer = "Sheer", ["pixels-fill"] = "Pixels Fill", ["pixels-dark"] = "Pixels Dark",
	["pixels-bg"] = "Pixels Background", ["blinkii-diamonds"] = "Blinkii Diamonds", ["kringel-window"] = "Kringel Window",
}

local function LSM()
	return ns.GetLSM and ns.GetLSM() or (LibStub and LibStub("LibSharedMedia-3.0", true))
end

function P.TexturePath(key)
	if not key or key == "none" or key == "" then
		return P.WHITE
	end
	if key:sub(1, 3) == "sm:" then
		local lsm = LSM()
		return (lsm and lsm:Fetch("statusbar", key:sub(4), true)) or P.WHITE
	end
	if ENP.BAR_TEXTURE_NAMES[key] then
		return P.MEDIA .. "textures\\" .. key
	end
	return P.WHITE
end

function ENP.TextureLabel(key)
	if key and key:sub(1, 3) == "sm:" then
		return key:sub(4)
	end
	return ENP.BAR_TEXTURE_NAMES[key or "none"] or ENP.OVERLAY_STRIPE_NAMES[key or ""] or "None"
end

function ENP.TextureItems()
	local items = {}
	for _, key in ipairs(ENP.BAR_TEXTURE_ORDER) do
		items[#items + 1] = { name = ENP.BAR_TEXTURE_NAMES[key], value = key }
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

-- Target / focus / hover overlay textures: the stripe art of the nameplate
-- media, else a bar texture (retail ns.ResolveOverlayTexPath).
ENP.OVERLAY_STRIPE_KEYS = {
	["striped-v2"] = true, ["striped-wide-v2"] = true, ["stripes-medium"] = true,
	["stripes-small-close"] = true, ["stripes-small-spread"] = true, ["striped-tiny"] = true,
}
ENP.OVERLAY_STRIPE_ORDER = {
	"striped-v2", "striped-wide-v2", "stripes-medium", "stripes-small-close", "stripes-small-spread", "striped-tiny",
}
ENP.OVERLAY_STRIPE_NAMES = {
	["striped-v2"] = "Striped", ["striped-wide-v2"] = "Striped Wide", ["stripes-medium"] = "Stripes Medium",
	["stripes-small-close"] = "Stripes Small Close", ["stripes-small-spread"] = "Stripes Small Spread",
	["striped-tiny"] = "Striped Tiny",
}

function P.OverlayTexPath(key)
	if not key or key == "none" then
		return nil
	end
	if ENP.OVERLAY_STRIPE_KEYS[key] then
		return P.MEDIA .. key
	end
	return P.TexturePath(key)
end

function ENP.OverlayTextureItems()
	local items = { { name = "None", value = "none" } }
	for _, key in ipairs(ENP.OVERLAY_STRIPE_ORDER) do
		items[#items + 1] = { name = ENP.OVERLAY_STRIPE_NAMES[key], value = key }
	end
	for _, it in ipairs(ENP.TextureItems()) do
		if it.value ~= "none" then
			items[#items + 1] = it
		end
	end
	return items
end

-- Absorb overlay textures (retail ns.NP_ABSORB_STYLE_TEX / ALPHA).
ENP.ABSORB_STYLE_TEX = {
	blizzard = P.MEDIA .. "shields\\blizzard",
	striped = P.MEDIA .. "shields\\striped3",
	clean = P.WHITE,
	pixelsShield = P.MEDIA .. "shields\\pixels-shield",
	pixelsShieldEdge = P.MEDIA .. "shields\\pixels-shield-edge",
	pixelsShieldFill = P.MEDIA .. "shields\\pixels-shield-fill",
}
ENP.ABSORB_STYLE_ALPHA = { blizzard = 0.8, striped = 0.8, clean = 0.3 }

-------------------------------------------------------------------------------
--  Target arrows (retail ns.TARGET_ARROW_STYLES: w = drawn width at height
--  16, scale 1)
-------------------------------------------------------------------------------
ENP.TARGET_ARROW_DIR = P.MEDIA .. "Arrows\\"
ENP.TARGET_ARROW_STYLES = {
	simple    = { l = "arrow_left",      r = "arrow_right",      w = 11, label = "Simple Arrows" },
	double    = { l = "arrow_leftx2",    r = "arrow_rightx2",    w = 22, label = "Double Arrows" },
	barbed    = { l = "barbed-left",     r = "barbed-right",     w = 28, label = "Barbed" },
	bracket   = { l = "bracket-left",    r = "bracket-right",    w = 22, label = "Bracket" },
	celestial = { l = "celestial-left",  r = "celestial-right",  w = 28, label = "Celestial" },
	classic   = { l = "classic-left",    r = "classic-right",    w = 22, label = "Classic" },
	crystal   = { l = "crystal-left",    r = "crystal-right",    w = 22, label = "Crystal" },
	curved    = { l = "curved-left",     r = "curved-right",     w = 22, label = "Curved" },
	demon     = { l = "demon-left",      r = "demon-right",      w = 28, label = "Demon" },
	diamond   = { l = "diamond-left",    r = "diamond-right",    w = 28, label = "Diamond" },
	feathered = { l = "feathered-left",  r = "feathered-right",  w = 22, label = "Feathered" },
	halo      = { l = "halo-left",       r = "halo-right",       w = 22, label = "Halo" },
	holyspear = { l = "holy-spear-left", r = "holy-spear-right", w = 28, label = "Holy Spear" },
	rune      = { l = "rune-left",       r = "rune-right",       w = 22, label = "Rune" },
	split     = { l = "split-left",      r = "split-right",      w = 22, label = "Split" },
	winged    = { l = "winged-left",     r = "winged-right",     w = 28, label = "Winged" },
}
ENP.TARGET_ARROW_ORDER = {
	"simple", "double", "winged", "feathered", "split", "celestial", "rune", "demon",
	"halo", "curved", "barbed", "holyspear", "bracket", "diamond", "crystal", "classic",
}

function P.ArrowStyle()
	local p = P.Profile()
	local key = p.targetArrowStyle or (p.targetArrowDouble and "double")
	return ENP.TARGET_ARROW_STYLES[key] or ENP.TARGET_ARROW_STYLES.simple
end

local _, PLAYER_CLASS = UnitClass("player")
P.PLAYER_CLASS = PLAYER_CLASS

function P.ArrowColor()
	local p = P.Profile()
	if p.targetArrowClassColor then
		local cc = RAID_CLASS_COLORS and ((EllesmereUI.GetClassColor and RAID_CLASS_COLORS[PLAYER_CLASS] and EllesmereUI.GetClassColor(PLAYER_CLASS)) or RAID_CLASS_COLORS[PLAYER_CLASS])
		if cc then
			return cc.r, cc.g, cc.b
		end
		return 1, 1, 1
	end
	local c = p.targetArrowColor
	if c then
		return c.r or 1, c.g or 1, c.b or 1
	end
	return 1, 1, 1
end

-------------------------------------------------------------------------------
--  Target / hover effect switches (retail Layout.lua getters: each toggle
--  reads its own key, else derives from targetGlowStyle)
-------------------------------------------------------------------------------
function P.TargetGlowEUI()
	local p = P.Profile()
	if p.targetGlowEllesmereUI ~= nil then return p.targetGlowEllesmereUI end
	local style = p.targetGlowStyle or defaults.targetGlowStyle
	return style == "ellesmereui" or style == "vibrant"
end
function P.TargetGlowBorderColor()
	local p = P.Profile()
	if p.targetGlowBorderColor ~= nil then return p.targetGlowBorderColor end
	return (p.targetGlowStyle or defaults.targetGlowStyle) == "vibrant"
end
function P.TargetGlowHighlight()
	return P.Profile().targetGlowHighlight == true
end
function P.TargetGlowBorderSize()
	return P.Profile().targetGlowBorderSize == true
end
function P.HoverGlowEUI() return P.Profile().hoverGlowEllesmereUI == true end
function P.HoverGlowBorderColor() return P.Profile().hoverGlowBorderColor == true end
function P.HoverGlowBorderSize() return P.Profile().hoverGlowBorderSize == true end
function P.HoverGlowHighlight()
	local v = P.Profile().hoverGlowHighlight
	if v ~= nil then return v == true end
	return true
end

-------------------------------------------------------------------------------
--  Sizes (retail Layout.lua getters)
-------------------------------------------------------------------------------
function P.HealthW() return BAR_W + (P.Get("healthBarWidth") or 0) end
function P.HealthH() return P.Get("healthBarHeight") or 17 end
function P.CastH() return P.Get("castBarHeight") or 17 end
function P.FriendlyW() return P.Get("friendlyHealthBarWidth") or 150 end
function P.FriendlyH() return P.Get("friendlyHealthBarHeight") or 17 end

-- Slot size / offsets of a Core Positions slot (top, left, right, topleft,
-- topright, bottom).
function P.SlotSize(slot)
	return P.Get(slot .. "SlotSize") or 24
end
function P.SlotOffsets(slot)
	return P.Get(slot .. "SlotXOffset") or 0, P.Get(slot .. "SlotYOffset") or 0
end

-------------------------------------------------------------------------------
--  Interrupt of the player (retail EllesmereUI_Kick.lua with the Mists
--  spells). Retail colors: kick ready = the normal cast color, kick on
--  cooldown = "interruptReady" (the "Interrupt on CD" swatch).
-------------------------------------------------------------------------------
local KICKS = {
	DEATHKNIGHT = { 47528 }, WARRIOR = { 6552 }, SHAMAN = { 57994 }, ROGUE = { 1766 },
	PRIEST = { 15487 }, PALADIN = { 96231 }, MONK = { 116705 }, MAGE = { 2139 },
	HUNTER = { 147362, 34490 }, DRUID = { 80964, 80965, 106839, 78675 },
	WARLOCK = { 19647, 119910, 103135, 132409, 115781 },
}
local kickSpell, kickIsPet

function P.RefreshKick()
	kickSpell, kickIsPet = nil, nil
	local list = KICKS[PLAYER_CLASS]
	if not list then return end
	for _, id in ipairs(list) do
		if IsSpellKnown(id, true) then
			kickSpell, kickIsPet = id, true
		elseif IsSpellKnown(id) and not kickIsPet then
			kickSpell = id
		end
	end
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

-------------------------------------------------------------------------------
--  Execute window (Execute Pulse Glow): health fraction below which the
--  player's execute works. Mists: Execute, Hammer of Wrath, Kill Shot,
--  Shadow Word: Death, Drain Soul / Shadowburn, Soul Reaper. Specs without an
--  execute switch the glow off (retail rule).
-------------------------------------------------------------------------------
local EXEC = {
	WARRIOR = { 0.20, 0.20, 0.20 },
	PALADIN = { 0.20, 0.20, 0.20 },
	HUNTER = { 0.20, 0.20, 0.20 },
	PRIEST = { 0.20, 0.20, 0.20 },
	WARLOCK = { 0.20, nil, 0.20 },
	DEATHKNIGHT = { 0.35, 0.35, 0.35 },
}
local execThreshold

function P.RefreshExecute()
	local list = EXEC[PLAYER_CLASS]
	local spec = GetSpecialization and GetSpecialization()
	execThreshold = list and spec and list[spec] or nil
end

function P.ExecuteThreshold()
	return execThreshold
end

-------------------------------------------------------------------------------
--  Role (threat colors): tank spec or a raid tank assignment
-------------------------------------------------------------------------------
-- 5.4.8 has no spec yet at PLAYER_LOGIN (talents arrive with
-- PLAYER_TALENT_UPDATE): an unknown spec stays nil and is asked again.
local isTank = nil
function P.RefreshRole()
	local spec = GetSpecialization and GetSpecialization()
	local role = spec and GetSpecializationRole and GetSpecializationRole(spec)
	if role then
		isTank = role == "TANK"
	elseif UnitGroupRolesAssigned and UnitGroupRolesAssigned("player") == "TANK" then
		isTank = true
	else
		isTank = nil
	end
end
function P.IsTank()
	if isTank == nil then P.RefreshRole() end
	return isTank or false
end



