-------------------------------------------------------------------------------
--  EllesmereUIAuraBuffReminders.lua (5.4.8 port of retail AuraBuff Reminders)
--
--  Raid Buffs, Auras, Class Specials and Consumables reminders: a row of
--  clickable icons (secure, out of combat) plus a visual-only row in combat.
--  Same saved keys, labels and look as retail; the data is Mists of Pandaria
--  (EllesmereUIABR_Data.lua).
--
--  5.4.8 changes:
--    * Raid buffs are the 8 MoP categories: a reminder fills a category, any
--      provider of the category satisfies it (Kings / Mark / Legacy ...).
--      Blessings and shouts show one reminder per caster (the one the group
--      needs most).
--    * Auras are the MoP class self-buffs (stances, presences, seals, armors,
--      Inner Fire, aspects, Shadowform, Moonkin Form, Righteous Fury, Beacon).
--    * Aura reads work in combat on 5.4.8 (no secret values), so the combat
--      row is fed by the same collectors.
--    * Weapon imbues: GetWeaponEnchantInfo has no enchant id on 5.4.8, so a
--      slot only knows "has a temporary enchant".
--    * The secure row is hidden in combat by a state driver (protected
--      frames can't be hidden by addon code there); the combat row is plain.
--    * Borders: Solid only (no border texture registry on 5.4.8). Glows:
--      GCD and Modern WoW Glow (retail atlases) draw the Classic ants.
--    * No item quality overlay (crafted quality is retail only), no Mythic+,
--      Delves, Lairs: "Mythic Dungeons" = Challenge Mode, "Pre-Key" = a
--      Challenge Mode dungeon before the timer starts.
-------------------------------------------------------------------------------
local addonName, P = ...
local ns = EllesmereUI
local D = P.DATA

local EABR = {}
ns.ABR = EABR
EABR.DATA = D

local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local format = string.format

local ICON_SIZE = 40
local FONT_KEY = "auraBuff"
local SOUND_DIR = "Interface\\AddOns\\" .. addonName .. "\\Sounds\\"
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local DEFAULT_GLOW_COLOR = { r = 1, g = 0.776, b = 0.376 }
local DEFAULT_TEXT_COLOR = { r = 1, g = 1, b = 1 }
EABR.ICON_SIZE = ICON_SIZE
EABR.DEFAULT_GLOW_COLOR = DEFAULT_GLOW_COLOR

-------------------------------------------------------------------------------
--  Defaults (retail defaults.profile, MoP keys for the class data)
-------------------------------------------------------------------------------
local DEFAULTS = {
	display = {
		remindersEnabled = true,
		glowType = 0,
		scale = 1.0,
		xOffset = 0,
		yOffset = 200,
		showText = true,
		showTooltips = true,
		textColor = { r = 1, g = 1, b = 1 },
		textSize = 12,
		textXOffset = 0,
		textYOffset = -5,
		textAnchor = "BOTTOM",
		showCount = true,
		countSize = 16,
		countXOffset = 0,
		countYOffset = 0,
		iconSpacing = 14,
		growDirection = "CENTER",
		opacity = 1.0,
		frameStrata = "MEDIUM",
		cursorAttach = false,
		cursorAttachCombatOnly = false,
		borderTexture = "solid",
		borderSize = 1,
		borderR = 0, borderG = 0, borderB = 0, borderA = 1,
		borderBehind = false,
		showUnder = 5,
		showUnderMPlus = 40,
	},
	raidBuffs = {
		enabled = {
			motw = true, bok = true, bom = true, loe = true, lowt = true, fort = true,
			ai = true, di = true, bshout = true, cshout = true, how = true,
		},
		whereToShow = { open_world = false },
		showWhen = { othersMissing = true, iAmMissing = false },
	},
	auras = {
		enabled = {
			battle_stance = true, def_stance = true, shadowform = true, inner_fire = true,
			righteous_fury = true, bol = true, moonkin = true, symbiotic = true,
			blood_presence = true, frost_presence = true, unholy_presence = true,
			ox_stance = true, tiger_stance = true, serpent_stance = true,
			aspect = true, mage_armor = true,
			soulstone = false,
		},
		whereToShow = {},
	},
	consumables = {
		showWithoutItem = true,
		enabled = {
			deadly = true, wound = true, crippling = true, numbing = true, leeching = true, paralytic = true,
			seal_truth = true, seal_righteousness = true, seal_insight = true, seal_justice = true,
			windfury = true, flametongue = true, earthliving = true, frostbrand = true, rockbiter = true,
			shield_basic = true,
			es_ally = false,
			flask = true,
			food = true,
		},
		whereToShow = { open_world = false },
		specialsWhereToShow = {},
		warlockWhereToShow = {},
		wrongPetAllowed = { felguard = true },
		preferredFlask = "last_used",
		preferredFood = "last_used",
	},
	talentReminders = {},
	talentReminderYOffset = -50,
}
EABR.DEFAULTS = DEFAULTS

-- The user's retail profile ("Naowh"), seeded once on the first login.
local NAOWH = {
	raidBuffs = { whereToShow = { open_world = true } },
	unlockPos = { y = 380.99981689453, relPoint = "CENTER", point = "CENTER", x = 0.000244140625 },
	display = {
		scale = 1.3, glowType = 4, textYOffset = 8, countYOffset = 42, showUnder = 12, textSize = 14,
		showUnderMPlus = 32, glowColor = { r = 0.80680113339718, g = 1, b = 0.65499860048295 },
		iconSpacing = 6, glowColorMode = "default", countXOffset = -2, countSize = 12,
	},
	consumables = {
		enabled = { ls_ws_orbit = true, es_orbit = true },
		whereToShow = { in_combat = false, timewalking = false, dungeon_nonmythic = false, raid_normal_lfr = false, delve = false },
		rcManaWarnSize = 28,
	},
}

local function DeepMerge(src, dst)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			DeepMerge(v, dst[k])
		else
			dst[k] = v
		end
	end
end

local svRoot, db
local function DB()
	if not svRoot then
		svRoot = ns.ModuleDB("EllesmereUIAuraBuffRemindersDB")
		if type(svRoot.profile) ~= "table" then svRoot.profile = {} end
		if svRoot._seeded ~= 1 then
			DeepMerge(NAOWH, svRoot.profile)
			svRoot._seeded = 1
		end
		ns.CopyDefaults(DEFAULTS, svRoot.profile)
		db = svRoot
	end
	return svRoot
end
EABR.DB = DB
function EABR.Profile()
	return DB().profile
end

-- Scale outside the UI range is corruption -> 1.0; glowColorMode one-time migration.
local function EnsureGlowModeMigrated(p)
	if not p then return end
	local s = p.scale
	if type(s) == "number" and (s < 0.5 or s > 3.0) then p.scale = 1.0 end
	if p.glowColorMode then return end
	local c = p.glowColor
	if c and not (c.r == 1 and c.g == 0.776 and c.b == 0.376) then
		p.glowColorMode = "custom"
	else
		p.glowColorMode = "default"
	end
end
EABR.EnsureGlowModeMigrated = EnsureGlowModeMigrated

local function ResolveGlowTint(p)
	EnsureGlowModeMigrated(p)
	if p.glowColorMode == "class" then
		local _, cls = UnitClass("player")
		local cc = ns.GetClassColor and ns.GetClassColor(cls) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls])
		if cc then return cc.r, cc.g, cc.b end
	elseif p.glowColorMode == "custom" and p.glowColor then
		local c = p.glowColor
		return c.r or 1, c.g or 0.776, c.b or 0.376
	end
	-- Default = nil: the glow engine draws the style's own untinted art (retail).
	return nil
end

local TEXT_ANCHOR_POINTS = {
	BOTTOM = { "TOP", "BOTTOM" },
	TOP    = { "BOTTOM", "TOP" },
	CENTER = { "CENTER", "CENTER" },
	LEFT   = { "RIGHT", "LEFT" },
	RIGHT  = { "LEFT", "RIGHT" },
}
EABR.TEXT_ANCHOR_POINTS = TEXT_ANCHOR_POINTS
local function GetTextAnchorPoints(p)
	local m = TEXT_ANCHOR_POINTS[(p and p.textAnchor) or "BOTTOM"] or TEXT_ANCHOR_POINTS.BOTTOM
	return m[1], m[2]
end

-------------------------------------------------------------------------------
--  Small helpers
-------------------------------------------------------------------------------
local function Known(id)
	if not id then return false end
	if IsPlayerSpell and IsPlayerSpell(id) then return true end
	return IsSpellKnown(id) and true or false
end
EABR.Known = Known

local function SpellName(id)
	return id and GetSpellInfo(id) or nil
end
EABR.SpellName = function(id, fallback)
	return SpellName(id) or fallback
end

local function Tex(id)
	if not id then return nil end
	local _, _, icon = GetSpellInfo(id)
	return icon or (GetSpellTexture and GetSpellTexture(id)) or nil
end
EABR.Tex = Tex

local function ItemIcon(id)
	local icon = GetItemIcon and GetItemIcon(id)
	if not icon then icon = select(10, GetItemInfo(id)) end
	return icon
end

local function PlayerClass()
	local _, cls = UnitClass("player")
	return cls
end

local function GetSpecID()
	local s = GetSpecialization and GetSpecialization()
	if not s then return nil end
	return (GetSpecializationInfo(s))
end
EABR.GetSpecID = GetSpecID

local function InCombat()
	return InCombatLockdown() or EABR._inCombat == true
end

local function InGroup()
	return IsInGroup() or IsInRaid()
end

local function SpecIn(list, specID)
	if not list then return true end
	for i = 1, #list do
		if list[i] == specID then return true end
	end
	return false
end

-- Labels: first word of the spell name, with retail's overrides.
local LABEL_OVERRIDES = {
	["Battle Stance"] = "Stance", ["Defensive Stance"] = "Stance", ["Berserker Stance"] = "Stance",
	["Power Word: Fortitude"] = "Fortitude", ["Arcane Brilliance"] = "Brilliance",
	["Dalaran Brilliance"] = "Brilliance", ["Battle Shout"] = "Shout", ["Commanding Shout"] = "Shout",
	["Blessing of Kings"] = "Kings", ["Blessing of Might"] = "Might",
	["Legacy of the Emperor"] = "Legacy", ["Legacy of the White Tiger"] = "Tiger",
	["Earth Shield (Ally)"] = "Ally",
	["Stance of the Sturdy Ox"] = "Stance", ["Stance of the Fierce Tiger"] = "Stance",
	["Stance of the Wise Serpent"] = "Stance",
}
local LABEL_CLASS_OVERRIDES = { ROGUE = "Poison", SHAMAN_IMBUE = "Weapon", SHAMAN_SHIELD = "Shield", PALADIN_SEAL = "Seal" }
local function ShortLabel(name, classOverride)
	if classOverride and LABEL_CLASS_OVERRIDES[classOverride] then
		return ns.L and ns.L(LABEL_CLASS_OVERRIDES[classOverride]) or LABEL_CLASS_OVERRIDES[classOverride]
	end
	name = name or ""
	if LABEL_OVERRIDES[name] then return LABEL_OVERRIDES[name] end
	return name:match("^(%S+)") or name
end
EABR.ShortLabel = ShortLabel

-------------------------------------------------------------------------------
--  Fonts (module font key "auraBuff")
-------------------------------------------------------------------------------
local function ResolveFontPath(fontName)
	if fontName and fontName ~= "__global" and ns.ResolveFontName then
		local path = ns.ResolveFontName(fontName)
		if path and path ~= "" then return path end
	end
	return (ns.GetFontPath and ns.GetFontPath(FONT_KEY)) or STANDARD_TEXT_FONT
end
EABR.ResolveFontPath = ResolveFontPath

local function SetABRFont(fs, font, size)
	if not (fs and fs.SetFont) then return end
	local outline = (ns.GetFontOutlineFlag and ns.GetFontOutlineFlag(FONT_KEY)) or ""
	fs:SetFont(font, size, outline)
	if not fs:GetFont() then fs:SetFont(STANDARD_TEXT_FONT, size, outline) end
	if outline == "" then
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 1)
	else
		fs:SetShadowOffset(0, 0)
	end
end
EABR.SetABRFont = SetABRFont

-------------------------------------------------------------------------------
--  Timers (5.4.8 has no C_Timer)
-------------------------------------------------------------------------------
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
			local ok, err = pcall(t.fn)
			if not ok then geterrorhandler()(err) end
		else
			i = i + 1
		end
	end
	if #timers == 0 then self:Hide() end
end)
local function After(sec, fn)
	timers[#timers + 1] = { at = GetTime() + (sec or 0), fn = fn }
	timerFrame:Show()
end
EABR.After = After

-------------------------------------------------------------------------------
--  Instance / difficulty (MoP ids)
--    party:    1 Normal, 2 Heroic, 8 Challenge Mode
--    raid:     3/4 Normal 10/25, 5/6 Heroic 10/25, 7 LFR, 14 Flexible, 9 40-player
--    scenario: 11 Heroic, 12 Normal
-------------------------------------------------------------------------------
local _iType, _diffID, _instName = "none", 0, nil
local _dungeonPrePull, _lastInstName = true, nil

local function CacheInstanceInfo()
	local name, iType, diffID = GetInstanceInfo()
	_iType = iType or "none"
	_diffID = tonumber(diffID) or 0
	_instName = name
	if name ~= _lastInstName then
		_dungeonPrePull = true
		_lastInstName = name
	end
end

local function InRealInstancedContent()
	return _iType == "party" or _iType == "raid" or _iType == "scenario" or _iType == "arena" or _iType == "pvp"
end

local function InPvPInstance()
	return _iType == "pvp" or _iType == "arena"
end

-- Challenge Mode timer running (retail: Mythic+ key active).
local function InChallengeRun()
	if not (_iType == "party" and _diffID == 8) then return false end
	if not (GetWorldElapsedTimers and GetWorldElapsedTime) then return false end
	local ids = { GetWorldElapsedTimers() }
	for i = 1, select("#", GetWorldElapsedTimers()) do
		local id = ids[i]
		if id then
			local _, elapsed = GetWorldElapsedTime(id)
			if elapsed and elapsed > 0 then return true end
		end
	end
	return false
end
EABR.InChallengeRun = InChallengeRun

local function InPreKeyDungeon()
	return _iType == "party" and _diffID == 8 and not InChallengeRun()
end

-- Coarse "Where to Show" buckets (retail keys).
function EABR.CurrentWhereBucket(inInstance)
	local it, d = _iType, _diffID
	if it == "party" then
		if d == 8 then return "dungeon_mythic" end
		return "dungeon_nonmythic"
	elseif it == "raid" then
		if d == 5 or d == 6 then return "raid_heroic" end
		return "raid_normal_lfr"
	elseif it == "scenario" then
		return "scenario"
	end
	if not inInstance then return "open_world" end
	return nil
end

function EABR.SectionShows(whereToShow, inInstance)
	if whereToShow and whereToShow.in_combat == false and InCombat() then return false end
	local bucket = EABR.CurrentWhereBucket(inInstance)
	if not bucket then return true end
	if not whereToShow then return true end
	return whereToShow[bucket] ~= false
end

-- Show Below thresholds (minutes). Ignored in combat and in a running
-- Challenge Mode (then only a missing buff reminds).
function EABR.GetShowUnderMinutes()
	local disp = EABR.Profile().display
	if InPreKeyDungeon() and _dungeonPrePull then
		return disp.showUnderMPlus or 40
	end
	return disp.showUnder or 5
end

local function IsUnderDuration(duration, expirationTime)
	if not (duration and expirationTime) or duration <= 0 or expirationTime <= 0 then return false end
	if InCombat() or InChallengeRun() then return false end
	local threshold = EABR.GetShowUnderMinutes() * 60
	-- Strictly longer only: MoP shouts / Horn of Winter last exactly 5 min,
	-- the default threshold, and would always count as "about to expire".
	if threshold > 0 and duration > threshold then
		return (expirationTime - GetTime()) < threshold
	end
	return false
end
EABR.IsUnderDuration = IsUnderDuration

-------------------------------------------------------------------------------
--  Aura reads (UnitAura works everywhere on 5.4.8)
-------------------------------------------------------------------------------
local _playerAuras = {}   -- [spellID] = { duration, expires, caster }
local _playerAuraNames = {}
local function ScanPlayerAuras()
	wipe(_playerAuras)
	wipe(_playerAuraNames)
	for i = 1, 40 do
		local name, _, _, _, _, duration, expires, caster, _, _, spellID = UnitAura("player", i, "HELPFUL")
		if not name then break end
		local rec = { duration = duration or 0, expires = expires or 0, caster = caster }
		if spellID then _playerAuras[spellID] = rec end
		_playerAuraNames[name] = rec
	end
end
EABR.ScanPlayerAuras = ScanPlayerAuras

-- Has any of the IDs, above the Show Below threshold.
local function PlayerHasAura(ids, ignoreDuration)
	for i = 1, #ids do
		local rec = _playerAuras[ids[i]]
		if rec then
			if ignoreDuration or not IsUnderDuration(rec.duration, rec.expires) then return true end
		end
	end
	return false
end
EABR.PlayerHasAura = PlayerHasAura

local function PlayerHasAuraNamed(name)
	return name and _playerAuraNames[name] ~= nil
end

-- names (optional) = set of localized aura names that also count. MoP raid
-- buff auras often carry another spell ID than the cast (pet buffs, auras,
-- group versions), so the category check also matches by name.
local function UnitHasAnyBuff(unit, set, fromPlayer, names)
	for i = 1, 40 do
		local name, _, _, _, _, duration, expires, caster, _, _, spellID = UnitAura(unit, i, "HELPFUL")
		if not name then break end
		if ((spellID and set[spellID]) or (names and names[name])) and (not fromPlayer or caster == "player") then
			return true, duration, expires
		end
	end
	return false
end

local function ToSet(list, out)
	out = out or {}
	for i = 1, #list do out[list[i]] = true end
	return out
end

-- Category sets
local CAT_SETS = {}
for key, cat in pairs(D.CATEGORIES) do
	CAT_SETS[key] = ToSet(cat.buffs)
end

-- Localized names per category (built on first use, GetSpellInfo can miss
-- spells before the client cache is warm, so empty results retry).
local CAT_NAMES = {}
local function CatNames(cat)
	local names = CAT_NAMES[cat]
	if names then return names end
	names = {}
	local any = false
	for id in pairs(CAT_SETS[cat]) do
		local n = GetSpellInfo(id)
		if n then names[n] = true; any = true end
	end
	if any then CAT_NAMES[cat] = names end
	return names
end

-- Group units (excluding nothing), list reused.
local _units = {}
local function GroupUnits()
	wipe(_units)
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do _units[#_units + 1] = "raid" .. i end
	else
		_units[1] = "player"
		if IsInGroup() then
			for i = 1, GetNumSubgroupMembers() do _units[#_units + 1] = "party" .. i end
		end
	end
	return _units
end

local function UnitOk(u)
	return UnitExists(u) and UnitIsConnected(u) and not UnitIsDeadOrGhost(u) and UnitIsPlayer(u)
end

local function UnitNear(u)
	if UnitIsUnit(u, "player") then return true end
	local inRange = UnitInRange(u)
	return inRange and true or false
end

-- Class set of near group members (not the player).
local _groupClasses = {}
local function BuildGroupClassSet()
	wipe(_groupClasses)
	if not InGroup() then return _groupClasses end
	for _, u in ipairs(GroupUnits()) do
		if UnitOk(u) and not UnitIsUnit(u, "player") and UnitNear(u) then
			local _, cls = UnitClass(u)
			if cls then _groupClasses[cls] = true end
		end
	end
	return _groupClasses
end

-- Whether a unit benefits from a stat-filtered buff (class + assigned role).
local function UnitBenefits(u, benefit)
	if not benefit then return true end
	local set = D.BENEFIT_CLASSES[benefit]
	if not set then return true end
	local _, cls = UnitClass(u)
	if not cls or not set[cls] then return false end
	local role
	if UnitIsUnit(u, "player") then
		local s = GetSpecialization and GetSpecialization()
		role = s and GetSpecializationRole(s)
	else
		role = UnitGroupRolesAssigned(u)
	end
	if role and role ~= "NONE" then
		if benefit == "intellect" then
			if (cls == "PALADIN" or cls == "MONK") and (role == "DAMAGER" or role == "TANK") then return false end
			if cls == "DRUID" and role == "TANK" then return false end
		elseif benefit == "attackPower" then
			if role == "HEALER" and (cls == "PALADIN" or cls == "MONK" or cls == "DRUID" or cls == "SHAMAN") then return false end
		end
	end
	return true
end

-- Members (near, alive) that lack any of the categories: have, total.
local function CountCoverage(cats, benefit)
	local have, total = 0, 0
	for _, u in ipairs(GroupUnits()) do
		if UnitOk(u) and UnitNear(u) and UnitBenefits(u, benefit) then
			total = total + 1
			local ok = true
			for c = 1, #cats do
				if not UnitHasAnyBuff(u, CAT_SETS[cats[c]], nil, CatNames(cats[c])) then ok = false; break end
			end
			if ok then have = have + 1 end
		end
	end
	return have, total
end

local function PlayerHasCategory(cat)
	for id in pairs(CAT_SETS[cat]) do
		local rec = _playerAuras[id]
		if rec and not IsUnderDuration(rec.duration, rec.expires) then return true end
	end
	for n in pairs(CatNames(cat)) do
		local rec = _playerAuraNames[n]
		if rec and not IsUnderDuration(rec.duration, rec.expires) then return true end
	end
	return false
end

-- Own cast of an aura on any group member (or self).
local function OwnBuffOnGroup(set, includeSelf)
	if includeSelf and UnitHasAnyBuff("player", set, true) then return true end
	if not InGroup() then return false end
	for _, u in ipairs(GroupUnits()) do
		if UnitExists(u) and not UnitIsUnit(u, "player") and UnitHasAnyBuff(u, set, true) then return true end
	end
	return false
end

local function AnyGroupMemberNear()
	if not InGroup() then return false end
	for _, u in ipairs(GroupUnits()) do
		if not UnitIsUnit(u, "player") and UnitOk(u) and UnitNear(u) then return true end
	end
	return false
end

-- Stance bar: is a form with this spell's name active / available.
local function StanceState(spellIDs)
	local n = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
	local available, active = false, false
	for i = 1, n do
		local _, name, isActive = GetShapeshiftFormInfo(i)
		for k = 1, #spellIDs do
			if name and name == SpellName(spellIDs[k]) then
				available = true
				if isActive then active = true end
			end
		end
	end
	return available, active
end

-------------------------------------------------------------------------------
--  Bags / consumables
-------------------------------------------------------------------------------
local function Count(itemID)
	return GetItemCount(itemID) or 0
end

local function PlayerMainStat()
	local cls = PlayerClass()
	local spec = GetSpecID()
	if cls == "MAGE" or cls == "WARLOCK" or cls == "PRIEST" then return "INT" end
	if cls == "ROGUE" or cls == "HUNTER" then return "AGI" end
	if cls == "WARRIOR" or cls == "DEATHKNIGHT" then return "STR" end
	if cls == "PALADIN" then return spec == 65 and "INT" or "STR" end
	if cls == "SHAMAN" then return spec == 263 and "AGI" or "INT" end
	if cls == "MONK" then return spec == 270 and "INT" or "AGI" end
	if cls == "DRUID" then return (spec == 102 or spec == 105) and "INT" or "AGI" end
	return "STR"
end
EABR.PlayerMainStat = PlayerMainStat

-- Pick an item: preferred key, then last used, then owned with the right
-- stat, then any owned. Returns itemID, hasBags.
local function ResolveItem(list, preferredKey, lastUsed)
	local function ItemsOf(e)
		return e.items or { e.itemID }
	end
	if preferredKey and preferredKey ~= "last_used" then
		for _, e in ipairs(list) do
			if e.key == preferredKey then
				for _, id in ipairs(ItemsOf(e)) do
					if Count(id) > 0 then return id, true end
				end
				return ItemsOf(e)[1], false
			end
		end
	end
	-- Last used may be an item outside the list (any food that gave Well Fed).
	if lastUsed and Count(lastUsed) > 0 then return lastUsed, true end
	local stat = PlayerMainStat()
	local fallback = nil
	for _, e in ipairs(list) do
		for _, id in ipairs(ItemsOf(e)) do
			if Count(id) > 0 then
				if e.stat == stat then return id, true end
				fallback = fallback or id
			end
		end
	end
	if fallback then return fallback, true end
	-- Nothing in the bags: suggest the stat item (dimmed restock prompt).
	for _, e in ipairs(list) do
		if e.stat == stat then return ItemsOf(e)[1], false end
	end
	return ItemsOf(list[1])[1], false
end
EABR.ResolveItem = ResolveItem

local FLASK_SET = {}
for _, f in ipairs(D.FLASK_ITEMS) do FLASK_SET[f.buffID] = true end
ToSet(D.FLASK_EXTRA_BUFFS, FLASK_SET)

local function PlayerHasFlask()
	for id in pairs(FLASK_SET) do
		local rec = _playerAuras[id]
		if rec and not IsUnderDuration(rec.duration, rec.expires) then return true end
	end
	return false
end

local function PlayerHasWellFed()
	local name = SpellName(D.WELL_FED_SPELL) or "Well Fed"
	local rec = _playerAuraNames[name] or _playerAuraNames["Well Fed"]
	return rec and not IsUnderDuration(rec.duration, rec.expires)
end

local function PlayerEating()
	for _, id in ipairs(D.FOOD_SPELLS) do
		local name = SpellName(id)
		local rec = name and _playerAuraNames[name]
		if rec then return true, rec.expires end
	end
	local rec = _playerAuraNames["Food"] or _playerAuraNames["Food & Drink"]
	if rec then return true, rec.expires end
	return false
end

-- 5.4.8 GetWeaponEnchantInfo: hasMH, mhExpire(ms), mhCharges, hasOH, ohExpire, ohCharges.
local function WeaponEnchants()
	local a, b, c, d, e, f, g, h = GetWeaponEnchantInfo()
	if type(d) == "number" then
		-- Newer shape (enchant ids): hasMH, exp, charges, id, hasOH, exp, charges, id
		return a, b, e, f
	end
	return a, b, d, e
end
EABR.WeaponEnchants = WeaponEnchants

local function HasWeapon(slot)
	local id = GetInventoryItemID("player", slot)
	if not id then return false end
	local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(id)
	if equipLoc == "INVTYPE_SHIELD" or equipLoc == "INVTYPE_HOLDABLE" then return false end
	return true
end

-------------------------------------------------------------------------------
--  Dismiss / sounds
-------------------------------------------------------------------------------
local dismissed = {}
EABR.dismissed = dismissed

local SPECIAL_KEYS = {}
for _, t in ipairs({ D.ROGUE_POISONS, D.PALADIN_SEALS, D.SHAMAN_IMBUES, D.SHAMAN_SHIELDS }) do
	for _, it in ipairs(t) do SPECIAL_KEYS[it.key] = true end
end
SPECIAL_KEYS.rogue_lethal, SPECIAL_KEYS.rogue_nonlethal, SPECIAL_KEYS.seal = true, true, true
SPECIAL_KEYS.imbue_mh, SPECIAL_KEYS.imbue_oh = true, true

function EABR.SoundPath(key)
	local f = key and D.SOUND_FILES[key]
	return f and (SOUND_DIR .. f) or nil
end

local function ResolveReminderSound(dk)
	local prefix, key = dk:match("^(%a+):(.+)$")
	if not prefix then return nil end
	local p = EABR.Profile()
	if prefix == "raidbuff" then return p.raidBuffs.sectionSound end
	if prefix == "aura" then return p.auras.sectionSound end
	if prefix == "consumable" then
		if SPECIAL_KEYS[key] then return p.consumables.specialsSound end
		return p.consumables.sectionSound
	end
	return nil
end

local _soundPrev, _soundCur, _soundPrimed = {}, {}, false
local function HandleAppearSounds(missing)
	wipe(_soundCur)
	for i = 1, #missing do
		local dk = missing[i].dismissKey
		if dk and not dismissed[dk] then
			_soundCur[dk] = true
			if _soundPrimed and not _soundPrev[dk] then
				local path = EABR.SoundPath(ResolveReminderSound(dk))
				if path then PlaySoundFile(path, "Master") end
			end
		end
	end
	_soundPrev, _soundCur, _soundPrimed = _soundCur, _soundPrev, true
end

-------------------------------------------------------------------------------
--  Glows (retail glowType numbering: 0 None, 1 Action Button Glow, 2 Pixel
--  Glow, 3 Auto-Cast Shine, 4 GCD, 5 Modern WoW Glow, 6 Classic WoW Glow)
--  Drawn by the shared core engine (EllesmereUI.Glows), like retail.
-------------------------------------------------------------------------------
EABR.GLOW_TYPES = {
	{ 0, "None" }, { 1, "Action Button Glow" }, { 2, "Pixel Glow" }, { 3, "Auto-Cast Shine" },
	{ 4, "GCD" }, { 5, "Modern WoW Glow" }, { 6, "Classic WoW Glow" },
}

-- Saved glowType -> shared style index (retail view; no Shape Glow).
local GLOW_VIEW = EllesmereUI.Glows.MakeView({ 2, 1, 3, 5, 6, 7 })
local StopAllGlows = EllesmereUI.Glows.StopAllGlows

local function StopGlow(btn)
	local w = btn._eabrGlowWrapper
	if w then StopAllGlows(w); w:Hide() end
end
EABR.StopGlow = StopGlow

local GLOW_SPEC = {}
local function GlowSpec(p, out)
	local shared = p and GLOW_VIEW.toShared[p.glowType or 0]
	if not shared then return nil end
	out = out or GLOW_SPEC
	out.style = shared
	out.r, out.g, out.b = ResolveGlowTint(p)
	out.lines, out.thickness, out.speed = p.glowLines, p.glowThickness, p.glowSpeed
	local bgc = p.glowBackgroundColor
	out.bg = (p.glowBackground == true) or nil
	out.bgR, out.bgG, out.bgB = bgc and bgc.r, bgc and bgc.g, bgc and bgc.b
	return out
end
EABR.GlowSpec = GlowSpec

-- Also clears the glow when it is off (no StopGlow first: that would reset
-- StartSpecGlow's signature and restart the animation every refresh).
local function ApplyGlow(btn, p, sz)
	local spec = GlowSpec(p)
	if not spec then StopGlow(btn); return end
	local w = btn._eabrGlowWrapper
	if not w then
		w = CreateFrame("Frame", nil, btn)
		w:SetAllPoints(btn)
		btn._eabrGlowWrapper = w
	end
	w:SetFrameLevel(btn:GetFrameLevel() + 4)
	sz = sz or btn:GetWidth() or ICON_SIZE
	EllesmereUI.Glows.StartSpecGlow(w, spec, sz, sz, "icon")
	w:SetAlpha(1)
	w:Show()
end
EABR.ApplyGlow = ApplyGlow

-------------------------------------------------------------------------------
--  Icon visuals (border, text, count) shared by every pool
-------------------------------------------------------------------------------
function EABR.ApplyIconBorder(f)
	local p = EABR.Profile().display
	local b = f._border
	if not b then
		b = CreateFrame("Frame", nil, f)
		b:SetAllPoints()
		b:EnableMouse(false)
		b.edges = {}
		for i = 1, 4 do
			b.edges[i] = b:CreateTexture(nil, "OVERLAY")
			b.edges[i]:SetTexture(1, 1, 1, 1)
		end
		f._border = b
	end
	b:SetFrameLevel(p.borderBehind and max(0, f:GetFrameLevel() - 1) or (f:GetFrameLevel() + 2))
	local size = p.borderSize or 1
	if size <= 0 then b:Hide(); return end
	local px = ((ns.PP and ns.PP.mult) or 1) * size
	local e = b.edges
	for i = 1, 4 do e[i]:ClearAllPoints(); e[i]:SetVertexColor(p.borderR or 0, p.borderG or 0, p.borderB or 0, p.borderA or 1) end
	e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT"); e[1]:SetHeight(px)
	e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(px)
	e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT"); e[3]:SetWidth(px)
	e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(px)
	b:Show()
end

local function BuildIconVisuals(f)
	local icon = f:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	f._icon = icon
	local hl = f:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints(icon)
	hl:SetTexture(1, 1, 1, 0.2)
	local overlay = CreateFrame("Frame", nil, f)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(f:GetFrameLevel() + 5)
	f._overlay = overlay
	local text = overlay:CreateFontString(nil, "OVERLAY")
	SetABRFont(text, ResolveFontPath(), 11)
	text:SetPoint("TOP", f, "BOTTOM", 0, -2)
	f._text = text
	local count = overlay:CreateFontString(nil, "OVERLAY")
	SetABRFont(count, ResolveFontPath(), 11)
	count:Hide()
	f._bagCount = count
	local big = overlay:CreateFontString(nil, "OVERLAY")
	SetABRFont(big, ResolveFontPath(), 16)
	big:SetPoint("CENTER")
	big:Hide()
	f._count = big
	EABR.ApplyIconBorder(f)
end

local function ShowTooltip(f)
	local d = EABR.Profile().display
	if d.showTooltips == false or f:GetAlpha() == 0 then return end
	if f._tooltipItem or f._tooltipSpell then
		GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
		if f._tooltipItem then
			GameTooltip:SetHyperlink("item:" .. f._tooltipItem)
		else
			GameTooltip:SetHyperlink("spell:" .. f._tooltipSpell)
		end
		if f._outOfStock then
			GameTooltip:AddLine("You don't have this item in your bags", 1, 0.3, 0.3, true)
		end
		GameTooltip:Show()
	elseif f._tooltipLabel and f._tooltipLabel ~= "" then
		GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
		GameTooltip:SetText(f._tooltipLabel, 1, 1, 1)
		GameTooltip:Show()
	end
end

local function HideTooltip()
	GameTooltip:Hide()
end

local function SizeBagCount(f, sz)
	local p = EABR.Profile().display
	local base = p.countSize or 16
	local fsz = max(6, floor(base * (sz / ICON_SIZE) + 0.5))
	SetABRFont(f._bagCount, ResolveFontPath(p.countFont), fsz)
	f._bagCount:ClearAllPoints()
	f._bagCount:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", p.countXOffset or 0, p.countYOffset or 0)
end

local function ApplyCountText(f, m, sz)
	local p = EABR.Profile().display
	local fs = f._bagCount
	f._outOfStock = nil
	local txt, r, g, b = nil, 1, 1, 1
	if m.groupTotal and m.groupTotal > 0 then
		txt = m.groupHave .. "/" .. m.groupTotal
	elseif p.showCount ~= false and not m.isEating then
		if m.itemID and m.desaturated then
			txt, r, g, b = "0", 1, 0.2, 0.2
			f._outOfStock = true
		elseif m.bagCount and m.bagCount > 0 then
			txt = tostring(m.bagCount)
		end
	end
	if txt then
		SizeBagCount(f, sz)
		fs:SetText(txt)
		fs:SetTextColor(r, g, b, 1)
		fs:Show()
	else
		fs:SetText("")
		fs:Hide()
	end
end

local function EatingTick(self, elapsed)
	self._eatAcc = (self._eatAcc or 0) + elapsed
	if self._eatAcc < 0.2 then return end
	self._eatAcc = 0
	local rem = (self._eatExp or 0) - GetTime()
	if rem > 0 then
		local mins = math.ceil(rem / 60)
		self._count:SetText(mins > 1 and (mins .. "m") or (math.ceil(rem) .. "s"))
		self._count:Show()
	else
		self._count:Hide()
		self:SetScript("OnUpdate", nil)
		if EABR.RequestRefresh then EABR.RequestRefresh() end
	end
end

local function ApplyEatingVisual(f, m)
	f:SetScript("OnUpdate", nil)
	f._count:Hide()
	if not m.isEating then return end
	f._icon:SetDesaturated(false)
	f._icon:SetTexture(D.EATING_ICON)
	StopGlow(f)
	if not m.eatingExpires or m.eatingExpires <= 0 then return end
	local p = EABR.Profile().display
	SetABRFont(f._count, ResolveFontPath(), max(14, floor((p.textSize or 11) * 1.15)))
	f._eatExp = m.eatingExpires
	f._eatAcc = 1
	EatingTick(f, 0)
	f:SetScript("OnUpdate", EatingTick)
end

local function ApplyNameText(f, m)
	local p = EABR.Profile().display
	if p.showText and not m.isEating then
		local tc = p.textColor or DEFAULT_TEXT_COLOR
		SetABRFont(f._text, ResolveFontPath(p.nameFont), p.textSize or 11)
		f._text:ClearAllPoints()
		local tp, ip = GetTextAnchorPoints(p)
		f._text:SetPoint(tp, f, ip, p.textXOffset or 0, p.textYOffset or -2)
		f._text:SetTextColor(tc.r or 1, tc.g or 1, tc.b or 1, 1)
		f._text:SetText(m.label or "")
		f._text:Show()
	else
		f._text:SetText("")
		f._text:Hide()
	end
end

local function IconSize()
	return floor(ICON_SIZE * (EABR.Profile().display.scale or 1) + 0.5)
end

-------------------------------------------------------------------------------
--  Anchors and pools
-------------------------------------------------------------------------------
local iconAnchor, combatAnchor, cursorAnchor
local iconPool, activeIcons = {}, {}
local combatPool, combatActive = {}, {}
local cursorPool, cursorActive = {}, {}

local function Strata()
	return EABR.Profile().display.frameStrata or "MEDIUM"
end

-- Same item subclass as the listed foods (locale-safe "Food & Drink" check).
-- Unknown item info counts as food so an uncached item is not rejected.
local function IsFoodItem(itemID)
	local sub = select(7, GetItemInfo(itemID))
	if not sub then return true end
	for _, f in ipairs(D.FOOD_ITEMS) do
		local ref = select(7, GetItemInfo(f.itemID))
		if ref then return sub == ref end
	end
	return true
end
EABR.IsFoodItem = IsFoodItem

local function TrackItemUse(itemID)
	if not itemID then return end
	local p = EABR.Profile()
	for _, f in ipairs(D.FLASK_ITEMS) do
		for _, id in ipairs(f.items) do
			if id == itemID then p.lastUsedFlask = itemID; return end
		end
	end
	for _, f in ipairs(D.FOOD_ITEMS) do
		if f.itemID == itemID then p.lastUsedFood = itemID; return end
	end
	-- Unlisted food: becomes the last used food if Well Fed follows it.
	-- Potions and other items used meanwhile are not food and are ignored.
	if IsFoodItem(itemID) then
		EABR._pendingFood, EABR._pendingFoodAt = itemID, GetTime()
	end
end
EABR.TrackItemUse = TrackItemUse

local function ItemIDFromLink(link)
	return link and tonumber(link:match("item:(%d+)"))
end

local function OnIconPostClick(self, button)
	if button == "MiddleButton" and self._dismissKey then
		dismissed[self._dismissKey] = true
		EABR.RequestRefresh()
	elseif button == "RightButton" and self._petCycleTotal then
		EABR._petCycleIndex = ((EABR._petCycleIndex or 1) % self._petCycleTotal) + 1
		EABR.RequestRefresh()
	elseif button == "LeftButton" and self._itemID then
		TrackItemUse(self._itemID)
	end
end

local function GetSecureIcon(index)
	local btn = iconPool[index]
	if btn then return btn end
	btn = CreateFrame("Button", "EABR_Icon" .. index, iconAnchor, "SecureActionButtonTemplate")
	btn:SetSize(ICON_SIZE, ICON_SIZE)
	btn:RegisterForClicks("LeftButtonUp", "MiddleButtonUp", "RightButtonUp")
	btn:SetFrameStrata(Strata())
	btn:Hide()
	BuildIconVisuals(btn)
	btn:HookScript("PostClick", OnIconPostClick)
	btn:HookScript("OnEnter", ShowTooltip)
	btn:HookScript("OnLeave", HideTooltip)
	iconPool[index] = btn
	return btn
end

local function OnPlainIconMouseUp(self, button)
	if button == "MiddleButton" and self._dismissKey then
		dismissed[self._dismissKey] = true
		EABR.RequestRefresh()
	elseif button == "LeftButton" and InCombat() and UIErrorsFrame then
		UIErrorsFrame:AddMessage("Click-to-use is disabled in combat", 1.0, 0.3, 0.3, 1.0)
	end
end

local function GetPlainIcon(pool, parent, prefix, index)
	local f = pool[index]
	if f then return f end
	f = CreateFrame("Frame", prefix .. index, parent)
	f:SetSize(ICON_SIZE, ICON_SIZE)
	f:SetFrameStrata(Strata())
	f:EnableMouse(true)
	f:Hide()
	BuildIconVisuals(f)
	f:SetScript("OnEnter", ShowTooltip)
	f:SetScript("OnLeave", HideTooltip)
	f:SetScript("OnMouseUp", OnPlainIconMouseUp)
	pool[index] = f
	return f
end

-- Visual part of an entry (all pools).
local function ApplyVisual(f, m, sz)
	f._dismissKey = m.dismissKey
	f._petCycleTotal = m.petCycleTotal
	f._itemID = m.itemID
	f._tooltipItem = m.itemID
	f._tooltipSpell = (not m.itemID) and m.spellID or nil
	f._tooltipLabel = m.label
	f._icon:SetTexture(m.texture or (m.spellID and Tex(m.spellID)) or (m.itemID and ItemIcon(m.itemID)) or QUESTION)
	f._icon:SetDesaturated(m.desaturated and true or false)
	f:SetFrameStrata(Strata())
	ApplyNameText(f, m)
	ApplyCountText(f, m, sz)
	ApplyEatingVisual(f, m)
	if not m.isEating then ApplyGlow(f, EABR.Profile().display, sz) end
end

-- Secure part: left click only (type1 ...), so middle / right never cast.
local function ApplySecure(btn, m)
	btn:SetAttribute("type1", nil)
	btn:SetAttribute("spell1", nil)
	btn:SetAttribute("item1", nil)
	btn:SetAttribute("macrotext1", nil)
	btn:SetAttribute("unit1", nil)
	if m.mode == "spell" and m.spellID then
		btn:SetAttribute("type1", "spell")
		btn:SetAttribute("spell1", SpellName(m.spellID) or m.spellID)
		if m.unit then btn:SetAttribute("unit1", m.unit) end
	elseif m.mode == "item" and m.itemID then
		btn:SetAttribute("type1", "item")
		btn:SetAttribute("item1", "item:" .. m.itemID)
	elseif m.mode == "macro" and m.macro then
		btn:SetAttribute("type1", "macro")
		btn:SetAttribute("macrotext1", m.macro)
	end
end

local function HideSecureIcons()
	if InCombatLockdown() then return end
	for _, btn in pairs(iconPool) do
		StopGlow(btn)
		btn:SetScript("OnUpdate", nil)
		btn._text:SetText("")
		btn:Hide()
	end
	wipe(activeIcons)
end

local function HidePlain(pool, list)
	for _, f in pairs(pool) do
		StopGlow(f)
		f:SetScript("OnUpdate", nil)
		f._text:SetText("")
		f:Hide()
	end
	wipe(list)
end

-- Row layout, retail LayoutIcons: CENTER spreads from the middle, RIGHT /
-- LEFT hang from that edge.
local function LayoutRow(list, anchor, resizeAnchor)
	local count = #list
	if count == 0 then return end
	local p = EABR.Profile().display
	local spacing = p.iconSpacing or 8
	local sz = IconSize()
	local totalW = count * sz + (count - 1) * spacing
	local textH = p.showText and ((p.textSize or 11) + abs(p.textYOffset or -2)) or 0
	local pt, startX, yOff = "CENTER", -(totalW / 2) + (sz / 2), textH / 2
	if p.growDirection == "RIGHT" then
		pt, startX, yOff = "TOPLEFT", 0, 0
	elseif p.growDirection == "LEFT" then
		pt, startX, yOff = "TOPRIGHT", -(count - 1) * (sz + spacing), 0
	end
	for i, f in ipairs(list) do
		f:SetSize(sz, sz)
		f:SetAlpha(p.opacity or 1)
		EABR.ApplyIconBorder(f)
		f:ClearAllPoints()
		f:SetPoint(pt, anchor, pt, startX + (i - 1) * (sz + spacing), yOff)
	end
	if resizeAnchor and not InCombatLockdown() then
		anchor:SetSize(max(1, totalW), sz + textH)
	end
end

-------------------------------------------------------------------------------
--  Entry pool (retail AcquireEntry)
-------------------------------------------------------------------------------
local entryPool, entryInUse = {}, 0
local function AcquireEntry()
	entryInUse = entryInUse + 1
	local e = entryPool[entryInUse]
	if not e then
		e = {}
		entryPool[entryInUse] = e
	end
	wipe(e)
	return e
end

local function AddSpell(missing, cat, key, spellID, label, unit)
	local e = AcquireEntry()
	e.mode, e.spellID, e.label, e.cat, e.unit = "spell", spellID, label, cat, unit
	e.dismissKey = cat .. ":" .. key
	missing[#missing + 1] = e
	return e
end

-------------------------------------------------------------------------------
--  Collectors
-------------------------------------------------------------------------------
-- Raid buffs: provider view (my cast, group coverage) + receiver view.
local function CollectRaidBuffs(missing, playerClass, inInstance)
	local rb = EABR.Profile().raidBuffs
	if not EABR.SectionShows(rb.whereToShow, inInstance) then return end
	local sw = rb.showWhen or {}
	local othersMissing = sw.othersMissing ~= false
	local iAmMissing = sw.iAmMissing == true
	local grouped = InGroup()
	local groupClasses = grouped and BuildGroupClassSet() or nil
	local groupPick = {}   -- group name -> chosen entry (one per caster)

	for _, buff in ipairs(D.RAID_BUFFS) do
		if rb.enabled[buff.key] and buff.class == playerClass and Known(buff.castSpell) then
			local isMissing, have, total = false, nil, nil
			if othersMissing and grouped then
				have, total = CountCoverage(buff.cats, buff.benefit)
				isMissing = total > 0 and have < total
			end
			if not isMissing then
				local mine = true
				for c = 1, #buff.cats do
					if not PlayerHasCategory(buff.cats[c]) then mine = false; break end
				end
				if not mine and UnitBenefits("player", buff.benefit) then isMissing = true; have, total = nil, nil end
			end
			local ownActive = UnitHasAnyBuff("player", ToSet({ buff.castSpell, buff.altCast or 0 }), true)
			if buff.group then
				local gp = groupPick[buff.group]
				if not gp then
					gp = { list = {} }
					groupPick[buff.group] = gp
				end
				if ownActive then gp.own = buff end
				gp.list[#gp.list + 1] = { buff = buff, missing = isMissing, have = have, total = total }
			elseif isMissing then
				local cast = (buff.altCast and Known(buff.altCast)) and buff.altCast or buff.castSpell
				local e = AddSpell(missing, "raidbuff", buff.key, cast, ShortLabel(SpellName(buff.castSpell) or buff.name), "player")
				e.groupHave, e.groupTotal = have, total
				e.data = buff
			end
		end
	end

	-- One blessing / shout per caster: refresh the one already up, else the
	-- missing one nobody else in the group can bring.
	for _, gp in pairs(groupPick) do
		local pick = nil
		for _, it in ipairs(gp.list) do
			if gp.own then
				if it.buff == gp.own and it.missing then pick = it end
			elseif it.missing then
				local otherCan = false
				if groupClasses then
					for cls in pairs(groupClasses) do
						local prov = D.CLASS_PROVIDES[cls]
						for c = 1, #it.buff.cats do
							if prov and prov[it.buff.cats[c]] then otherCan = true end
						end
					end
				end
				if not pick or (pick.otherCan and not otherCan) then
					pick = it
					pick.otherCan = otherCan
				end
			end
		end
		if pick then
			local e = AddSpell(missing, "raidbuff", pick.buff.key, pick.buff.castSpell,
				ShortLabel(SpellName(pick.buff.castSpell) or pick.buff.name), "player")
			e.groupHave, e.groupTotal = pick.have, pick.total
			e.data = pick.buff
		end
	end

	-- Receiver view: I lack a category a groupmate's class can cast.
	if iAmMissing and groupClasses then
		for _, cat in ipairs(D.CATEGORY_ORDER) do
			if not PlayerHasCategory(cat) then
				for _, buff in ipairs(D.RAID_BUFFS) do
					local fills = false
					for c = 1, #buff.cats do if buff.cats[c] == cat then fills = true end end
					if fills and buff.class ~= playerClass and groupClasses[buff.class] and rb.enabled[buff.key]
						and UnitBenefits("player", buff.benefit) then
						local e = AcquireEntry()
						e.mode, e.texture, e.spellID = "texture", Tex(buff.castSpell), buff.castSpell
						e.label = ShortLabel(SpellName(buff.castSpell) or buff.name)
						e.cat, e.dismissKey, e.data = "raidbuff", "raidbuff:" .. buff.key, buff
						missing[#missing + 1] = e
						break
					end
				end
			end
		end
	end
end

local function CastForAura(aura, specID)
	if aura.castFn == "hunterAspect" then
		for _, id in ipairs(D.HUNTER_ASPECTS) do
			if Known(id) then return id end
		end
	elseif aura.castFn == "mageArmor" then
		local id = D.MAGE_ARMOR_BY_SPEC[specID or 0]
		if id and Known(id) then return id end
		for _, a in pairs(D.MAGE_ARMOR_BY_SPEC) do
			if Known(a) then return a end
		end
	end
	return aura.castSpell
end

local function CollectAuras(missing, playerClass, specID, inInstance, inCombat)
	local p = EABR.Profile()
	local au = p.auras
	local auraShows = EABR.SectionShows(au.whereToShow, inInstance)
	local warlockShows = EABR.SectionShows(p.consumables.warlockWhereToShow, inInstance)
	for _, aura in ipairs(D.AURAS) do
		local shows = (aura.key == "soulstone") and warlockShows or auraShows
		if shows and au.enabled[aura.key] and aura.class == playerClass and SpecIn(aura.specs, specID) then
			local cast = CastForAura(aura, specID)
			local usable, isMissing = false, false
			if aura.stance then
				local available, active = StanceState(aura.stance)
				usable = available
				isMissing = not active
			else
				usable = Known(cast)
			end
			if usable and aura.requireGroup and not InGroup() then usable = false end
			if usable and aura.requireInstanceGroup and not (inInstance and InGroup()) then usable = false end
			if usable and not aura.stance then
				if aura.check == "ownOnGroup" then
					isMissing = (not inCombat) and AnyGroupMemberNear() and not OwnBuffOnGroup(ToSet(aura.buffIDs), true)
				elseif aura.check == "ownGroupOrSelf" then
					isMissing = (not inCombat) and not OwnBuffOnGroup(ToSet(aura.buffIDs), true)
					if isMissing then
						local start, duration = GetSpellCooldown(cast)
						if start and duration and duration > 1.5 then isMissing = false end
					end
				else
					local has = PlayerHasAura(aura.buffIDs)
					if not has and aura.nameFallback then has = PlayerHasAuraNamed(SpellName(cast) or aura.name) end
					isMissing = not has
				end
			end
			if usable and isMissing then
				local e = AddSpell(missing, "aura", aura.key, cast, ShortLabel(SpellName(cast) or aura.name),
					(aura.check == nil) and "player" or nil)
				e.data = aura
			end
		end
	end
end

local function CollectSpecials(missing, playerClass, specID, inCombat)
	local co = EABR.Profile().consumables
	if playerClass == "ROGUE" then
		local activeL, activeNL, missL, missNL = false, false, nil, nil
		for _, poison in ipairs(D.ROGUE_POISONS) do
			if Known(poison.castSpell) then
				local active = PlayerHasAura({ poison.castSpell })
				if poison.cat == "lethal" then
					if active then activeL = true elseif co.enabled[poison.key] and not missL then missL = poison end
				else
					if active then activeNL = true elseif co.enabled[poison.key] and not missNL then missNL = poison end
				end
			end
		end
		if missL and not activeL then
			local e = AddSpell(missing, "consumable", "rogue_lethal", missL.castSpell, ShortLabel(missL.name, "ROGUE"))
			e.data = missL
		end
		if missNL and not activeNL then
			local e = AddSpell(missing, "consumable", "rogue_nonlethal", missNL.castSpell, ShortLabel(missNL.name, "ROGUE"))
			e.data = missNL
		end
	elseif playerClass == "PALADIN" then
		local n = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
		if n > 0 and (GetShapeshiftForm() or 0) == 0 then
			local want = D.SEAL_BY_SPEC[specID or 0]
			local pick = nil
			for _, seal in ipairs(D.PALADIN_SEALS) do
				if co.enabled[seal.key] and Known(seal.castSpell) then
					if seal.key == want then pick = seal; break end
					pick = pick or seal
				end
			end
			if pick then
				local e = AddSpell(missing, "consumable", "seal", pick.castSpell, ShortLabel(pick.name, "PALADIN_SEAL"))
				e.data = pick
			end
		end
	elseif playerClass == "SHAMAN" then
		local plan = D.IMBUE_BY_SPEC[specID or 0]
		if plan then
			local hasMH, mhExp, hasOH, ohExp = WeaponEnchants()
			local function Need(has, exp)
				if not has then return true end
				return exp and exp > 0 and IsUnderDuration(3600, exp / 1000 + GetTime())
			end
			for _, slot in ipairs({ "mh", "oh" }) do
				local key = plan[slot]
				local invSlot = (slot == "mh") and 16 or 17
				if key and co.enabled[key] and HasWeapon(invSlot) then
					local imbue = nil
					for _, it in ipairs(D.SHAMAN_IMBUES) do if it.key == key then imbue = it end end
					local need = (slot == "mh") and Need(hasMH, mhExp) or Need(hasOH, ohExp)
					if imbue and Known(imbue.castSpell) and need then
						local e = AddSpell(missing, "consumable", "imbue_" .. slot, imbue.castSpell, ShortLabel(imbue.name, "SHAMAN_IMBUE"))
						e.data = imbue
					end
				end
			end
		end
		if not inCombat then
			local basic, ally = D.SHAMAN_SHIELDS[1], D.SHAMAN_SHIELDS[2]
			local cast = (specID == 264 and Known(D.WATER_SHIELD)) and D.WATER_SHIELD or basic.castSpell
			if co.enabled[basic.key] ~= false and Known(cast) and not PlayerHasAura(basic.buffIDs) then
				local e = AddSpell(missing, "consumable", basic.key, cast, ShortLabel(basic.name, "SHAMAN_SHIELD"), "player")
				e.data = basic
			end
			if co.enabled[ally.key] == true and Known(ally.castSpell) and AnyGroupMemberNear()
				and not OwnBuffOnGroup(ToSet(ally.buffIDs), false) then
				local e = AcquireEntry()
				e.mode, e.texture, e.spellID = "texture", Tex(ally.castSpell), ally.castSpell
				e.label = ShortLabel(ally.name)
				e.cat, e.dismissKey, e.data = "consumable", "consumable:" .. ally.key, ally
				missing[#missing + 1] = e
			end
		end
	end
end

local function CollectConsumables(missing, playerClass, specID, inInstance, inCombat)
	local p = EABR.Profile()
	local co = p.consumables
	-- Drop a saved non-food (a potion saved by the earlier tracking).
	if p.lastUsedFood and not IsFoodItem(p.lastUsedFood) then p.lastUsedFood = nil end
	-- A fresh Well Fed within a minute of using an unlisted food: remember it.
	if EABR._pendingFood then
		local now = GetTime()
		if now - EABR._pendingFoodAt > 60 then
			EABR._pendingFood = nil
		elseif PlayerHasWellFed() then
			local rec = _playerAuraNames[SpellName(D.WELL_FED_SPELL) or "Well Fed"] or _playerAuraNames["Well Fed"]
			if rec and (rec.duration == 0 or rec.expires - now > rec.duration - 60) then
				p.lastUsedFood = EABR._pendingFood
				EABR._pendingFood = nil
			end
		end
	end
	if EABR.SectionShows(co.specialsWhereToShow, inInstance) then
		CollectSpecials(missing, playerClass, specID, inCombat)
	end
	local shows = EABR.SectionShows(co.whereToShow, inInstance)
	if shows and not inCombat and not InChallengeRun() then
		if co.enabled.flask and not PlayerHasFlask() then
			local id, hasBags = ResolveItem(D.FLASK_ITEMS, co.preferredFlask, p.lastUsedFlask)
			if id and (co.showWithoutItem ~= false or hasBags) then
				local e = AcquireEntry()
				e.mode, e.itemID, e.texture = "item", id, ItemIcon(id) or D.FLASK_ICON
				e.label = "Flask"
				e.bagCount, e.desaturated = Count(id), not hasBags
				e.cat, e.dismissKey = "consumable", "consumable:flask"
				missing[#missing + 1] = e
			end
		end
		if co.enabled.food and not PlayerHasWellFed() then
			local id, hasBags = ResolveItem(D.FOOD_ITEMS, co.preferredFood, p.lastUsedFood)
			if id and (co.showWithoutItem ~= false or hasBags) then
				local e = AcquireEntry()
				e.mode, e.itemID, e.texture = "item", id, ItemIcon(id) or D.FOOD_ICON
				e.label = "Food"
				e.bagCount, e.desaturated = Count(id), not hasBags
				e.cat, e.dismissKey = "consumable", "consumable:food"
				local eating, expires = PlayerEating()
				if eating then e.isEating, e.eatingExpires = true, expires end
				missing[#missing + 1] = e
			end
		end
	end
	-- Healthstone: a Warlock is in the group and you carry none.
	if shows and InGroup() and co.enabled.healthstone ~= false and (not inCombat or playerClass == "WARLOCK") then
		local hasWarlock = playerClass == "WARLOCK"
		if not hasWarlock then
			for _, u in ipairs(GroupUnits()) do
				local _, cls = UnitClass(u)
				if cls == "WARLOCK" then hasWarlock = true; break end
			end
		end
		if hasWarlock and Count(D.HEALTHSTONE_ITEM) == 0 then
			local e = AcquireEntry()
			e.mode, e.texture, e.label = "texture", D.HEALTHSTONE_ICON, "HS"
			e.itemID = nil
			e.cat, e.dismissKey = "consumable", "consumable:healthstone"
			missing[#missing + 1] = e
		end
	end
	-- Custom spells (retail Add Custom Spell, f.customIDs): reminded whenever
	-- that buff is missing. Click casts it when the spell is known.
	if shows and not inCombat and type(co.customIDs) == "table" then
		for _, id in ipairs(co.customIDs) do
			local name = SpellName(id)
			if name and not PlayerHasAura({ id }) and not PlayerHasAuraNamed(name) then
				local e
				if Known(id) then
					e = AddSpell(missing, "consumable", "custom" .. id, id, ShortLabel(name))
				else
					e = AcquireEntry()
					e.mode, e.texture, e.label = "texture", Tex(id), ShortLabel(name)
					e.cat, e.dismissKey = "consumable", "consumable:custom" .. id
					missing[#missing + 1] = e
				end
			end
		end
	end
	-- Death Knight runeforge missing on a weapon.
	if not inCombat and playerClass == "DEATHKNIGHT" and co.enabled.runeforge ~= false then
		for _, slot in ipairs({ 16, 17 }) do
			local link = GetInventoryItemLink("player", slot)
			if link and HasWeapon(slot) then
				local ench = tonumber(link:match("item:%d+:(-?%d+)")) or 0
				if ench == 0 then
					local e = AcquireEntry()
					e.mode, e.texture, e.label = "texture", Tex(D.RUNEFORGING) or D.RUNEFORGE_ICON, "Rune"
					e.cat, e.dismissKey = "consumable", "consumable:runeforge"
					missing[#missing + 1] = e
					break
				end
			end
		end
	end
end

-- Warlock demon: points the entry at the pet the shared cycle index selects.
local function SetWarlockPetSpell(e, pets, labelOverride)
	local n = #pets
	local idx = EABR._petCycleIndex or 1
	if idx > n then idx = 1 end
	local pet = pets[idx]
	local cast = (pet.sup and Known(pet.sup)) and pet.sup or pet.castSpell
	e.mode, e.spellID = "spell", cast
	e.texture = Tex(cast) or D.WARLOCK_PET_ICON
	e.label = labelOverride or pet.name
	e.petCycleTotal = n > 1 and n or nil
end

local function CollectPets(missing, playerClass, specID, inInstance)
	local co = EABR.Profile().consumables
	if not D.PET_CLASSES[playerClass] then return end
	if not (co.enabled and co.enabled.pet ~= false and EABR.SectionShows(co.specialsWhereToShow, inInstance)) then return end
	local suppress, petSpell, petLabel = false, nil, "Pet"
	local enforced = nil
	if playerClass == "HUNTER" then
		petSpell = D.CALL_PET
		if UnitExists("pet") and UnitIsDead("pet") and Known(982) then petSpell = 982 end  -- Revive Pet
		if not Known(petSpell) then suppress = true end
	elseif playerClass == "WARLOCK" then
		if Known(D.GRIMOIRE_OF_SACRIFICE) and PlayerHasAura({ D.GRIMOIRE_OF_SACRIFICE }, true) then suppress = true end
		enforced = {}
		local allowed = co.wrongPetAllowed
		if allowed then
			for _, pet in ipairs(D.WARLOCK_PETS) do
				if allowed[pet.key] and (Known(pet.castSpell) or (pet.sup and Known(pet.sup))) then
					enforced[#enforced + 1] = pet
				end
			end
		end
	elseif playerClass == "DEATHKNIGHT" then
		petSpell, petLabel = D.RAISE_DEAD, "Ghoul"
		if specID ~= 252 or not Known(petSpell) then suppress = true end
	elseif playerClass == "MAGE" then
		petSpell, petLabel = D.WATER_ELEMENTAL, "Water Elemental"
		if specID ~= 64 or not Known(petSpell) then suppress = true end
	end
	if suppress then return end
	local petUp = UnitExists("pet") and not UnitIsDead("pet")
	if not IsMounted() and not petUp then
		local e = AcquireEntry()
		e.cat, e.dismissKey = "consumable", "consumable:pet"
		if enforced and #enforced > 0 then
			SetWarlockPetSpell(e, enforced)
		elseif petSpell then
			e.mode, e.spellID, e.texture, e.label = "spell", petSpell, Tex(petSpell) or D.PET_ICON, petLabel
		else
			e.mode, e.texture, e.label = "texture", D.PET_ICON, petLabel
		end
		missing[#missing + 1] = e
	end
	-- Wrong demon (English family names; other clients skip it).
	if playerClass == "WARLOCK" and petUp and co.enabled.wrong_pet ~= false and enforced and #enforced > 0
		and EABR.SectionShows(co.warlockWhereToShow, inInstance) and (GetLocale() == "enUS" or GetLocale() == "enGB") then
		local family = UnitCreatureFamily("pet")
		local ok = family == nil
		for _, pet in ipairs(enforced) do
			if family and pet.families[family] then ok = true end
		end
		if not ok then
			local e = AcquireEntry()
			SetWarlockPetSpell(e, enforced, "Wrong Demon")
			e.cat, e.dismissKey = "consumable", "consumable:wrong_pet"
			missing[#missing + 1] = e
		end
	end
	-- Pet on Passive (5.4.8: name, subtext, texture, isToken, isActive).
	if petUp and co.enabled.pet_passive ~= false and not IsMounted() then
		for i = 1, (NUM_PET_ACTION_SLOTS or 10) do
			local name, _, texture, isToken, isActive = GetPetActionInfo(i)
			if name == "PET_MODE_PASSIVE" then
				if isActive then
					local e = AcquireEntry()
					e.mode = "texture"
					e.texture = (isToken and _G[texture]) or texture or D.PET_ICON
					e.label = PET_MODE_PASSIVE or "Passive"
					e.cat, e.dismissKey = "consumable", "consumable:pet_passive"
					missing[#missing + 1] = e
				end
				break
			end
		end
	end
end

-------------------------------------------------------------------------------
--  Refresh
-------------------------------------------------------------------------------
local _missing = {}
EABR.lastMissing = _missing

local function IsImportant(m)
	return m.cat == "raidbuff" and m.mode == "spell"
end

local function ShowPlainRow(list, pool, active, anchor, prefix, resize)
	local sz = IconSize()
	for _, m in ipairs(list) do
		local f = GetPlainIcon(pool, anchor, prefix, #active + 1)
		f:SetParent(anchor)
		ApplyVisual(f, m, sz)
		f:Show()
		active[#active + 1] = f
	end
	LayoutRow(active, anchor, resize)
end

local function Refresh()
	if not (svRoot and iconAnchor) then return end
	local p = EABR.Profile()
	local inCombat = InCombat()

	HidePlain(combatPool, combatActive)
	HidePlain(cursorPool, cursorActive)

	local hideAll = UnitIsDeadOrGhost("player") or IsResting() or UnitInVehicle("player")
		or (IsMounted() and IsFlying()) or p.display.remindersEnabled == false
	if hideAll then
		HideSecureIcons()
		if cursorAnchor then cursorAnchor:Hide() end
		return
	end

	CacheInstanceInfo()
	ScanPlayerAuras()
	entryInUse = 0
	wipe(_missing)

	local playerClass = PlayerClass()
	local specID = GetSpecID()
	local inInstance = InRealInstancedContent()
	local inPvP = InPvPInstance()

	CollectRaidBuffs(_missing, playerClass, inInstance)
	CollectAuras(_missing, playerClass, specID, inInstance, inCombat)
	if not inPvP then
		CollectConsumables(_missing, playerClass, specID, inInstance, inCombat)
	end
	CollectPets(_missing, playerClass, specID, inInstance)

	HandleAppearSounds(_missing)

	-- Split: cursor (important, cursor attach on; with Only on Cursor in
	-- Combat, only while in combat) / row.
	local useCursor = p.display.cursorAttach and cursorAnchor
		and (not p.display.cursorAttachCombatOnly or inCombat or InCombatLockdown())
	local rowList, curList = {}, {}
	for _, m in ipairs(_missing) do
		if not (m.dismissKey and dismissed[m.dismissKey]) then
			if useCursor and IsImportant(m) then
				curList[#curList + 1] = m
			else
				rowList[#rowList + 1] = m
			end
		end
	end

	if #curList > 0 then
		cursorAnchor:Show()
		ShowPlainRow(curList, cursorPool, cursorActive, cursorAnchor, "EABR_CursorIcon", false)
	elseif cursorAnchor then
		cursorAnchor:Hide()
	end

	if inCombat or InCombatLockdown() then
		-- Combat: the secure row is hidden by its state driver; a plain row
		-- shows the same reminders (visual only).
		ShowPlainRow(rowList, combatPool, combatActive, combatAnchor, "EABR_CombatIcon", false)
		return
	end

	HideSecureIcons()
	local sz = IconSize()
	for _, m in ipairs(rowList) do
		local btn = GetSecureIcon(#activeIcons + 1)
		ApplySecure(btn, m)
		ApplyVisual(btn, m, sz)
		btn:Show()
		activeIcons[#activeIcons + 1] = btn
	end
	LayoutRow(activeIcons, iconAnchor, true)
end
EABR.Refresh = Refresh

local _queued, _lastRefresh = false, 0
local function DoRefresh()
	_queued = false
	_lastRefresh = GetTime()
	local ok, err = pcall(Refresh)
	if not ok then geterrorhandler()(err) end
	if EABR.TalentRefresh then EABR.TalentRefresh() end
end
function EABR.RequestRefresh()
	if _queued then return end
	_queued = true
	local wait = 0.5 - (GetTime() - _lastRefresh)
	After(wait > 0 and wait or 0, DoRefresh)
end

-------------------------------------------------------------------------------
--  Position / Unlock Mode (retail keys: unlockPos, growDirection)
-------------------------------------------------------------------------------
function EABR.NominalRowW(d)
	return 2 * floor(ICON_SIZE * (d.scale or 1.0) + 0.5) + (d.iconSpacing or 8)
end

local function ApplyUnlockPos()
	if not iconAnchor or InCombatLockdown() then return end
	local p = EABR.Profile()
	local pos = p.unlockPos
	iconAnchor:ClearAllPoints()
	if pos and pos.point then
		iconAnchor:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
	else
		local d = p.display
		if d.growDirection == "RIGHT" then
			iconAnchor:SetPoint("LEFT", UIParent, "CENTER", (d.xOffset or 0) - EABR.NominalRowW(d) / 2, d.yOffset or 0)
		elseif d.growDirection == "LEFT" then
			iconAnchor:SetPoint("RIGHT", UIParent, "CENTER", (d.xOffset or 0) + EABR.NominalRowW(d) / 2, d.yOffset or 0)
		else
			iconAnchor:SetPoint("CENTER", UIParent, "CENTER", d.xOffset or 0, d.yOffset or 0)
		end
	end
end
EABR.ApplyUnlockPos = ApplyUnlockPos

-- Keeps the row's screen spot when the grow edge changes.
function EABR.UpdateUnlockPosForGrowDir(newGrowDir)
	local pos = EABR.Profile().unlockPos
	if not pos or not pos.point or (pos.relPoint or pos.point) ~= "CENTER" then return end
	local cur = pos.point
	if cur ~= "CENTER" and cur ~= "LEFT" and cur ~= "RIGHT" then return end
	local target = (newGrowDir == "RIGHT" and "LEFT") or (newGrowDir == "LEFT" and "RIGHT") or "CENTER"
	if cur == target then return end
	local w = iconAnchor and iconAnchor:GetWidth() or 0
	if w <= 1 then w = EABR.NominalRowW(EABR.Profile().display) end
	local cx = pos.x or 0
	if cur == "LEFT" then cx = cx + w / 2 elseif cur == "RIGHT" then cx = cx - w / 2 end
	if target == "LEFT" then pos.x = cx - w / 2 elseif target == "RIGHT" then pos.x = cx + w / 2 else pos.x = cx end
	pos.point, pos.relPoint = target, "CENTER"
end

function ns.GetAuraBuffGrowDir()
	return svRoot and EABR.Profile().display.growDirection or "CENTER"
end

function ns.SetAuraBuffGrowDir(v)
	if not svRoot then return end
	EABR.Profile().display.growDirection = v
	EABR.UpdateUnlockPosForGrowDir(v)
	ApplyUnlockPos()
	LayoutRow(activeIcons, iconAnchor, true)
end

local function RegisterUnlock()
	if not (ns.RegisterUnlockElements and ns.MakeUnlockElement) then return end
	ns:RegisterUnlockElements({
		ns.MakeUnlockElement({
			key = "EABR_Reminders",
			label = "AuraBuff Reminders",
			group = "AuraBuff Reminders",
			order = 600,
			noAnchorTarget = true,
			noResize = true,
			getFrame = function() return iconAnchor end,
			getSize = function()
				local d = EABR.Profile().display
				local sz = IconSize()
				local spacing = d.iconSpacing or 8
				local count = max(2, #activeIcons)
				local w = count * sz + (count - 1) * spacing
				local textH = d.showText and ((d.textSize or 11) + abs(d.textYOffset or -2)) or 0
				return w, sz + textH
			end,
			savePos = function(_, point, relPoint, x, y)
				local grow = EABR.Profile().display.growDirection
				if (grow == "RIGHT" or grow == "LEFT") and point == "CENTER" and relPoint == "CENTER" then
					local halfW = (iconAnchor and iconAnchor:GetWidth() or 0) / 2
					if grow == "RIGHT" then point, x = "LEFT", x - halfW else point, x = "RIGHT", x + halfW end
				end
				EABR.Profile().unlockPos = { point = point, relPoint = relPoint, x = x, y = y }
				if not ns._unlockActive then ApplyUnlockPos() end
			end,
			loadPos = function()
				local pos = EABR.Profile().unlockPos
				if not pos or (pos.point ~= "LEFT" and pos.point ~= "RIGHT") or pos.relPoint ~= "CENTER" then
					return pos
				end
				local halfW = (iconAnchor and iconAnchor:GetWidth() or 0) / 2
				return { point = "CENTER", relPoint = "CENTER",
					x = (pos.x or 0) + ((pos.point == "LEFT") and halfW or -halfW), y = pos.y or 0 }
			end,
			loadRawPos = function() return EABR.Profile().unlockPos end,
			saveRawPos = function(_, pp)
				if not (pp and pp.point) then return end
				EABR.Profile().unlockPos = { point = pp.point, relPoint = pp.relPoint or pp.point, x = pp.x, y = pp.y }
				EABR.UpdateUnlockPosForGrowDir(EABR.Profile().display.growDirection)
			end,
			clearPos = function() EABR.Profile().unlockPos = nil end,
			applyPos = function() ApplyUnlockPos() end,
		}),
	}, addonName)
end

-------------------------------------------------------------------------------
--  Ready Check Mana Warning (healer under 80% mana, raid, out of combat)
-------------------------------------------------------------------------------
local warnFrame, warnFS
local function RCWColor()
	local c = EABR.Profile().consumables
	local col = c.rcManaWarnColor
	if col and col.r then return col.r, col.g, col.b end
	local mc = PowerBarColor and PowerBarColor["MANA"]
	if mc then return min(mc.r * 1.5, 1), min(mc.g * 1.5, 1), min(mc.b * 1.5, 1) end
	return 0, 0.825, 1
end
EABR.RCWColor = RCWColor

function EABR.RCWApplySettings()
	if not warnFrame then return end
	local c = EABR.Profile().consumables
	warnFrame:ClearAllPoints()
	warnFrame:SetPoint("CENTER", UIParent, "CENTER", c.rcManaWarnX or 0, 75 + (c.rcManaWarnY or 0))
	SetABRFont(warnFS, ResolveFontPath(c.rcManaWarnFont), c.rcManaWarnSize or 48)
	warnFS:SetTextColor(RCWColor())
end

local function BuildWarnFrame()
	if warnFrame then return end
	warnFrame = CreateFrame("Frame", nil, UIParent)
	warnFrame:SetSize(600, 60)
	warnFrame:SetFrameStrata("FULLSCREEN")
	warnFrame:Hide()
	warnFS = warnFrame:CreateFontString(nil, "OVERLAY")
	warnFS:SetPoint("CENTER")
	SetABRFont(warnFS, ResolveFontPath(), 48)
	local ag = warnFrame:CreateAnimationGroup()
	local a1 = ag:CreateAnimation("Alpha")
	a1:SetChange(-0.4)
	a1:SetDuration(0.4)
	a1:SetOrder(1)
	local a2 = ag:CreateAnimation("Alpha")
	a2:SetChange(0.4)
	a2:SetDuration(0.4)
	a2:SetOrder(2)
	ag:SetLooping("REPEAT")
	warnFrame._breathe = ag
	EABR.RCWApplySettings()
	warnFS:SetText("LOW MANA")
end

function EABR.RCWHide()
	if warnFrame then
		warnFrame._breathe:Stop()
		warnFrame:Hide()
	end
end

function EABR.RCWShow(duration)
	BuildWarnFrame()
	EABR.RCWApplySettings()
	warnFrame:Show()
	warnFrame._breathe:Play()
	local token = {}
	EABR._rcwToken = token
	if duration then
		After(duration, function() if EABR._rcwToken == token then EABR.RCWHide() end end)
	end
end

local function OnReadyCheck()
	local c = EABR.Profile().consumables
	if c.rcManaWarn == false or InCombatLockdown() or not IsInRaid() then return end
	local s = GetSpecialization and GetSpecialization()
	if not s or GetSpecializationRole(s) ~= "HEALER" then return end
	local maxMana = UnitPowerMax("player", 0)
	if not maxMana or maxMana <= 0 then return end
	if UnitPower("player", 0) / maxMana >= 0.8 then return end
	EABR.RCWShow(10)
end

-------------------------------------------------------------------------------
--  Every settings change
-------------------------------------------------------------------------------
function EABR.Apply()
	if not iconAnchor then return end
	if not InCombatLockdown() then
		for _, f in pairs(iconPool) do
			f:SetFrameStrata(Strata())
			EABR.ApplyIconBorder(f)
		end
		ApplyUnlockPos()
	end
	EABR.RCWApplySettings()
	EABR.RequestRefresh()
end

ns.applyHooks = ns.applyHooks or {}
tinsert(ns.applyHooks, function()
	if svRoot then EABR.Apply() end
end)

function EABR.Reset()
	local root = DB()
	wipe(root.profile)
	root._seeded = nil
	svRoot = nil
	DB()
	wipe(dismissed)
	EABR.Apply()
end

-- Retail profile import: retail profile.addons[folder] is db.profile.
if ns.ProfileRetail and ns.ProfileRetail.CONVERT then
	ns.ProfileRetail.CONVERT[addonName] = function(blob)
		local function Copy(t)
			local out = {}
			for k, v in pairs(t) do out[k] = type(v) == "table" and Copy(v) or v end
			return out
		end
		local prof = Copy(type(blob) == "table" and blob or {})
		-- Retail item ids never match a Mists item.
		prof.lastUsedFlask, prof.lastUsedFood, prof.lastUsedWeaponEnchant = nil, nil, nil
		return { profile = prof, _seeded = 1 }
	end
end

-------------------------------------------------------------------------------
--  Boot / events
-------------------------------------------------------------------------------
local function CreateAnchors()
	iconAnchor = CreateFrame("Frame", "EABR_Anchor", UIParent)
	iconAnchor:SetSize(ICON_SIZE * 2, ICON_SIZE)
	iconAnchor:SetFrameStrata("MEDIUM")
	ApplyUnlockPos()
	-- Secure row: hidden in combat by the secure state driver.
	RegisterStateDriver(iconAnchor, "visibility", "[combat] hide; show")
	combatAnchor = CreateFrame("Frame", "EABR_CombatAnchor", UIParent)
	combatAnchor:SetAllPoints(iconAnchor)
	combatAnchor:SetFrameStrata("MEDIUM")
	cursorAnchor = CreateFrame("Frame", "EABR_CursorAnchor", UIParent)
	cursorAnchor:SetSize(1, 1)
	cursorAnchor:SetFrameStrata("TOOLTIP")
	cursorAnchor:Hide()
	cursorAnchor:SetScript("OnUpdate", function(self)
		local x, y = GetCursorPosition()
		local s = UIParent:GetEffectiveScale()
		self:ClearAllPoints()
		self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / s + 24, y / s - 24)
	end)
	EABR.iconAnchor, EABR.combatAnchor = iconAnchor, combatAnchor
end

local f = CreateFrame("Frame")
EABR.eventFrame = f
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == addonName then
			self:UnregisterEvent("ADDON_LOADED")
			DB()
			RegisterUnlock()
		end
		return
	end
	if event == "PLAYER_LOGIN" then
		self:UnregisterEvent("PLAYER_LOGIN")
		DB()
		CreateAnchors()
		for _, ev in ipairs({
			"PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "GROUP_ROSTER_UPDATE", "UNIT_AURA",
			"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS",
			"PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_TALENT_UPDATE", "SPELLS_CHANGED",
			"UNIT_PET", "PET_BAR_UPDATE", "BAG_UPDATE", "UNIT_INVENTORY_CHANGED", "PLAYER_UPDATE_RESTING",
			"UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
			"READY_CHECK", "SPELL_UPDATE_COOLDOWN", "UNIT_SPELLCAST_SUCCEEDED",
		}) do
			self:RegisterEvent(ev)
		end
		if UseContainerItem then
			hooksecurefunc("UseContainerItem", function(bag, slot)
				TrackItemUse(GetContainerItemID(bag, slot))
			end)
		end
		-- Action bar buttons and /use macros.
		hooksecurefunc("UseAction", function(slot)
			local kind, id = GetActionInfo(slot)
			if kind == "item" then TrackItemUse(id) end
		end)
		if UseItemByName then
			hooksecurefunc("UseItemByName", function(name)
				if not name then return end
				local id = tonumber(name) or ItemIDFromLink(name) or ItemIDFromLink(select(2, GetItemInfo(name)))
				TrackItemUse(id)
			end)
		end
		-- Show Below thresholds and the mount state have no event: re-check.
		local acc = 0
		self:SetScript("OnUpdate", function(_, elapsed)
			acc = acc + elapsed
			if acc >= 5 then
				acc = 0
				EABR.RequestRefresh()
			end
		end)
		EABR.RequestRefresh()
		return
	end
	if event == "PLAYER_ENTERING_WORLD" then
		wipe(dismissed)   -- middle-click dismiss lasts until the next loading screen
		After(1, EABR.RequestRefresh)
	elseif event == "PLAYER_REGEN_DISABLED" then
		EABR._inCombat = true
		if _iType == "party" then _dungeonPrePull = false end   -- pulled: the pre-key window is over
		EABR.RCWHide()
	elseif event == "PLAYER_REGEN_ENABLED" then
		EABR._inCombat = false
	elseif event == "READY_CHECK" then
		OnReadyCheck()
		return
	elseif event == "UNIT_AURA" then
		local u = arg1
		if u ~= "player" and not (u and (u:find("^party") or u:find("^raid") or u == "pet")) then return end
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_INVENTORY_CHANGED" then
		if arg1 ~= "player" then return end
	elseif event == "SPELL_UPDATE_COOLDOWN" then
		if PlayerClass() ~= "WARLOCK" then return end
	end
	EABR.RequestRefresh()
end)
