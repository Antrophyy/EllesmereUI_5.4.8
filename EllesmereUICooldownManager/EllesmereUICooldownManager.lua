-------------------------------------------------------------------------------
--  EllesmereUICooldownManager.lua (5.4.8 port of EllesmereUI Cooldown Manager)
--
--  Retail CDM restyles Blizzard's 11.x/12.x Cooldown Viewer (C_CooldownViewer).
--  5.4.8 has no viewer, so this port draws its own icon bars and drives them
--  with GetSpellCooldown / GetSpellCharges / GetItemCooldown / UnitAura.
--  The saved data model is retail's:
--    profile.cdmBars.bars[i]         the bars (cooldowns / utility / buffs / custom)
--    profile.cdmBarPositions[key]    Unlock Mode positions ("CDM_" .. key movers)
--    profile.customActiveStates[id]  preset / item / racial icon settings
--    profile.spec[specKey].mappings  Bar Glows (action button glows)
--    specProfiles[specKey]           per-spec spell lists and per-spell settings
--                                    (retail EllesmereUIDB.spellAssignments
--                                    .profiles[name].specProfiles, kept in this
--                                    module's SavedVariables here so it rides
--                                    with the EllesmereUI profile)
--  Retail spell IDs are kept as stored; an ID this client does not know is
--  hidden (GetSpellInfo returns nil).
--
--  This file: defaults, saved variables, first-login seed, spec key, timers,
--  entry resolving (spells, items, trinket slots, racials) and the retail
--  profile converter.
-------------------------------------------------------------------------------
local addonName, P = ...
local ns = EllesmereUI

local CDM = {}
P.CDM = CDM
ns.CDM = CDM
CDM.addonName = addonName
CDM.FONT_KEY = "cdm"

local floor = math.floor
local type, pairs, ipairs, tonumber, tostring = type, pairs, ipairs, tonumber, tostring

-------------------------------------------------------------------------------
--  Helpers
-------------------------------------------------------------------------------
local function DeepCopy(v)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in pairs(v) do out[k] = DeepCopy(x) end
	return out
end
CDM.DeepCopy = DeepCopy

-- Timers (5.4.8 has no C_Timer): one OnUpdate frame runs every pending timer.
do
	local timers = {}
	local tf = CreateFrame("Frame")
	tf:Hide()
	tf:SetScript("OnUpdate", function(self)
		local now = GetTime()
		local i = 1
		while i <= #timers do
			local t = timers[i]
			if t.cancelled then
				table.remove(timers, i)
			elseif now >= t.at then
				if t.every then
					t.at = now + t.every
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
	function CDM.After(sec, fn)
		local t = { at = GetTime() + (sec or 0), fn = fn }
		timers[#timers + 1] = t
		tf:Show()
		return t
	end
	function CDM.NewTicker(sec, fn)
		local t = { at = GetTime() + sec, every = sec, fn = fn }
		timers[#timers + 1] = t
		tf:Show()
		return t
	end
	function CDM.Cancel(t)
		if t then t.cancelled = true end
	end
end

-- Run-once-after-combat queue, keyed per purpose (retail ns.CombatQueue).
do
	local queue, order = {}, {}
	local qf = CreateFrame("Frame")
	qf:SetScript("OnEvent", function(self)
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
		local list = order
		order = {}
		local fns = queue
		queue = {}
		for _, key in ipairs(list) do
			local ok, err = pcall(fns[key])
			if not ok then geterrorhandler()(err) end
		end
	end)
	function CDM.OutOfCombat(key, fn)
		if not InCombatLockdown() then
			fn()
			return
		end
		if not queue[key] then order[#order + 1] = key end
		queue[key] = fn
		qf:RegisterEvent("PLAYER_REGEN_ENABLED")
	end
end

-------------------------------------------------------------------------------
--  Defaults (retail DEFAULTS.profile; 5.4.8 drops the Blizzard / Classic style
--  flags and the Rotation Assist icon: no C_AssistedCombat)
-------------------------------------------------------------------------------
local function BaseBar(key, name, barType, iconSize)
	return {
		key = key, name = name, enabled = true,
		barType = barType,
		iconSize = iconSize, numRows = 1, spacing = 2,
		borderSize = 1, borderR = 0, borderG = 0, borderB = 0, borderA = 1,
		borderClassColor = false, borderTexture = "solid",
		bgR = 0.08, bgG = 0.08, bgB = 0.08, bgA = 0.6,
		iconZoom = 0.08, iconShape = "none",
		verticalOrientation = false, barBgEnabled = false, barBgR = 0, barBgG = 0, barBgB = 0,
		borderThickness = "thin",
		anchorTo = "none", anchorPosition = "left",
		anchorOffsetX = 0, anchorOffsetY = 0,
		barVisibility = "always", housingHideEnabled = true,
		visHideHousing = true, visOnlyInstances = false,
		visHideMounted = false, visHideNoTarget = false, visHideNoEnemy = false,
		showCooldownText = true, cooldownTextPosition = "center",
		showItemCount = true, showTooltip = false, showKeybind = false,
		keybindSize = 10, keybindOffsetX = 2, keybindOffsetY = -2, keybindAlign = "left",
		keybindR = 1, keybindG = 1, keybindB = 1, keybindA = 0.9,
	}
end

local DEFAULTS = {
	profile = {
		spec = {},
		activeSpecKey = "0",
		cdmBars = {
			enabled = true,
			hideBuffsWhenInactive = true,
			showInactiveBuffIcons = false,
			desaturateInactiveBuffs = true,
			stableKeybinds = true,
			glowsOnlyInCombat = false,
			-- NaowhUI Gameplay "Hide CDM Tooltips in Combat" (user value: on).
			hideTooltipsInCombat = true,
			bars = {
				BaseBar("cooldowns", "Cooldowns", "cooldowns", 42),
				BaseBar("utility", "Utility", "utility", 36),
				BaseBar("buffs", "Buffs", "buffs", 32),
			},
		},
		cdmBarPositions = {},
		customActiveStates = {},
	},
}
DEFAULTS.profile.cdmBars.bars[3].showInactiveBuffIcons = false
DEFAULTS.profile.cdmBars.bars[3].desaturateInactiveBuffs = true
DEFAULTS.profile.cdmBars.bars[3].hidePlaceholderIcon = false
CDM.DEFAULTS = DEFAULTS
CDM.NewBarTemplate = BaseBar

-- Fallbacks for keys retail resolves in code ("x or default").
CDM.BAR_FALLBACK = {
	iconSize = 36, numRows = 1, spacing = 2, growDirection = "CENTER",
	cooldownFontSize = 12, cooldownTextX = 0, cooldownTextY = 0,
	cooldownTextR = 1, cooldownTextG = 1, cooldownTextB = 1,
	stackCountSize = 11, stackCountX = 0, stackCountY = 0, stackCountPosition = "bottomright",
	stackCountR = 1, stackCountG = 1, stackCountB = 1,
	chargeFontSize = 11, swipeAlpha = 0.7, barStrata = "MEDIUM", barOpacity = 1,
	oocFadeAlpha = 0.5, iconZoom = 0.08, iconShape = "none",
	pandemicGlowStyle = 1, buffGlowType = 0, keybindSize = 10,
	keybindOffsetX = 2, keybindOffsetY = -2, keybindAlign = "left",
	borderSize = 1, bgA = 0.6,
}
function CDM.BV(bd, key)
	local v = bd and bd[key]
	if v == nil then return CDM.BAR_FALLBACK[key] end
	return v
end

-------------------------------------------------------------------------------
--  Saved variables
--  EllesmereUICooldownManagerDB = { profile = {...}, specProfiles = {...}, _seeded = 1 }
-------------------------------------------------------------------------------
local root

function CDM.Root()
	if not root then
		root = ns.ModuleDB("EllesmereUICooldownManagerDB")
	end
	if type(root.profile) ~= "table" then root.profile = {} end
	if type(root.specProfiles) ~= "table" then root.specProfiles = {} end
	return root
end

function CDM.DB()
	return CDM.Root().profile
end

-- Fills the retail defaults (bars merge by index, like retail's DB merge).
local function FillDefaults(p)
	ns.CopyDefaults(DEFAULTS.profile, p)
	for _, bd in ipairs(p.cdmBars.bars) do
		if bd.enabled == nil then bd.enabled = true end
		if not bd.name then bd.name = bd.key or "Bar" end
		if not bd.barType then bd.barType = "cooldowns" end
	end
end
CDM.FillDefaults = FillDefaults

-- First login: the retail Naowh profile and its per-spec spell lists.
local function Seed(r)
	if next(r.profile) == nil and P.SEED_PROFILE then
		r.profile = DeepCopy(P.SEED_PROFILE)
	end
	if P.SEED_SPECS then
		for specKey, sp in pairs(P.SEED_SPECS) do
			if r.specProfiles[specKey] == nil then
				r.specProfiles[specKey] = DeepCopy(sp)
			end
		end
	end
	r._seeded = 1
end

function CDM.InitDB()
	local r = CDM.Root()
	if r._seeded ~= 1 then Seed(r) end
	FillDefaults(r.profile)
	root = r
	return r
end

function CDM.Reset()
	local r = CDM.Root()
	wipe(r.profile)
	wipe(r.specProfiles)
	Seed(r)
	FillDefaults(r.profile)
	if CDM.ready and CDM.SeedSpecDefaults then CDM.SeedSpecDefaults() end
end

-- Bars in order; "focuskick" and the ghost bar are retail-only (focus
-- nameplate kick tracker / hidden-spell holder) and never shown here.
function CDM.Bars()
	return CDM.DB().cdmBars.bars
end

function CDM.IsPortedBar(bd)
	return bd and not bd.isGhostBar and bd.key ~= "__ghost_cd"
end

function CDM.BarByKey(key)
	for _, bd in ipairs(CDM.Bars()) do
		if bd.key == key then return bd end
	end
end

-- "buffs" family bars track auras; the rest track cooldowns.
function CDM.IsBuffBar(bd)
	return bd and (bd.barType == "buffs" or bd.barType == "custom_buff")
end

-------------------------------------------------------------------------------
--  Spec key (retail: the specialization ID as a string)
-------------------------------------------------------------------------------
function CDM.SpecKey()
	local idx = GetSpecialization and GetSpecialization()
	if idx then
		local id = GetSpecializationInfo(idx)
		if id then return tostring(id) end
	end
	return "0"
end

function CDM.SpecProfile(specKey)
	local r = CDM.Root()
	specKey = specKey or CDM.SpecKey()
	local sp = r.specProfiles[specKey]
	if type(sp) ~= "table" then
		sp = {}
		r.specProfiles[specKey] = sp
	end
	if type(sp.barSpells) ~= "table" then sp.barSpells = {} end
	return sp
end

function CDM.BarSpellData(barKey, specKey)
	local sp = CDM.SpecProfile(specKey)
	local sd = sp.barSpells[barKey]
	if type(sd) ~= "table" then
		sd = { assignedSpells = {} }
		sp.barSpells[barKey] = sd
	end
	if type(sd.assignedSpells) ~= "table" then sd.assignedSpells = {} end
	return sd
end

-- Per-spell settings: the bar's barSettings tier, then the spell's own entry
-- (spellSettingsCD / spellSettingsBuff), then customActiveStates for items,
-- slots and presets (retail ResolveSpellSettings order, simplified).
function CDM.SpellSettings(bd, id)
	local sp = CDM.SpecProfile()
	local sd = sp.barSpells[bd.key]
	local store = CDM.IsBuffBar(bd) and sp.spellSettingsBuff or sp.spellSettingsCD
	local own = store and store[id]
	local cas = CDM.DB().customActiveStates[id]
	local barTier = sd and sd.barSettings
	local profTier = bd.barSpellSettings
	if not (own or cas or barTier or profTier) then return nil end
	-- Not ipairs: it stops at the first missing tier, so a bar without
	-- barSpellSettings dropped the spell's own settings.
	local out, tiers = {}, { profTier, barTier, cas, own }
	for i = 1, 4 do
		local t = tiers[i]
		if type(t) == "table" then
			for k, v in pairs(t) do out[k] = v end
		end
	end
	return out
end

function CDM.SpellSettingsStore(bd, create)
	local sp = CDM.SpecProfile()
	local k = CDM.IsBuffBar(bd) and "spellSettingsBuff" or "spellSettingsCD"
	if create and type(sp[k]) ~= "table" then sp[k] = {} end
	return sp[k]
end

-------------------------------------------------------------------------------
--  Racials (retail RACE_RACIALS, Mists of Pandaria IDs)
-------------------------------------------------------------------------------
CDM.RACE_RACIALS = {
	Scourge  = { 7744 },
	Tauren   = { 20549 },
	Orc      = { 20572, 33697, 33702 },
	BloodElf = { 28730, 25046, 50613, 69179, 80483, 129597 },
	Dwarf    = { 20594 },
	Troll    = { 26297 },
	Draenei  = { 28880, 59542, 59543, 59544, 59545, 59547, 59548, 121093 },
	NightElf = { 58984 },
	Human    = { 59752 },
	Gnome    = { 20589 },
	Worgen   = { 68992 },
	Goblin   = { 69070 },
	Pandaren = { 107079 },
}
-- Every racial ID retail may have stored (other races and retail-only races);
-- a stored racial follows this character's race (retail NormalizeRacialAssignments).
CDM.ALL_RACIALS = {}
do
	local retail = {
		7744, 20549, 20572, 33697, 33702, 202719, 50613, 25046, 69179, 80483, 155145, 129597,
		232633, 28730, 20594, 26297, 28880, 59543, 59545, 121093, 59544, 370626, 59547, 59548,
		59542, 416250, 58984, 59752, 265221, 20589, 255654, 68992, 69070, 107079, 274738,
		255647, 256948, 287712, 291944, 312411, 312924, 260364, 357214, 436344, 1237885,
	}
	for _, id in ipairs(retail) do CDM.ALL_RACIALS[id] = true end
	for _, list in pairs(CDM.RACE_RACIALS) do
		for _, id in ipairs(list) do CDM.ALL_RACIALS[id] = true end
	end
end

function CDM.MyRacial()
	if CDM._myRacial ~= nil then return CDM._myRacial or nil end
	local _, race = UnitRace("player")
	local list = race and CDM.RACE_RACIALS[race]
	local pick = false
	if list then
		-- Exact ID first: every Arcane Torrent variant has the same name, so the
		-- name check in IsKnownSpell would pick the first ID for any class and
		-- GetSpellCooldown on that unknown ID never shows a cooldown.
		for _, id in ipairs(list) do
			if (IsPlayerSpell and IsPlayerSpell(id)) or IsSpellKnown(id) then pick = id; break end
		end
		if not pick then
			for _, id in ipairs(list) do
				if CDM.IsKnownSpell(id) then pick = id; break end
			end
		end
		if not pick then pick = list[1] end
	end
	CDM._myRacial = pick
	return pick or nil
end

-------------------------------------------------------------------------------
--  Items: retail's current-season potions map to the Mists of Pandaria ones
--  (retail CDM_ITEM_PRESETS). Primary-stat potions follow the class.
-------------------------------------------------------------------------------
local STAT_POTION = { str = 76095, agi = 76089, int = 76093 }   -- Mogu Power, Virmen's Bite, Jade Serpent
local CLASS_STAT = {
	WARRIOR = "str", PALADIN = "str", DEATHKNIGHT = "str",
	HUNTER = "agi", ROGUE = "agi", MONK = "agi", DRUID = "agi", SHAMAN = "agi",
	MAGE = "int", PRIEST = "int", WARLOCK = "int",
}
-- Healers / casters of hybrid classes use intellect.
local INT_SPECS = { [65] = true, [102] = true, [105] = true, [262] = true, [264] = true, [270] = true }

local function StatPotion()
	local _, class = UnitClass("player")
	local stat = CLASS_STAT[class] or "int"
	local spec = tonumber(CDM.SpecKey())
	if spec and INT_SPECS[spec] then stat = "int" end
	return STAT_POTION[stat]
end

-- retail itemID -> function returning the Mists item (nil = no counterpart)
CDM.ITEM_REMAP = {
	[241308] = StatPotion, [245898] = StatPotion, [245897] = StatPotion, [241309] = StatPotion,   -- Light's Potential
	[241304] = function() return 76097 end, [241305] = function() return 76097 end,            -- health potion -> Master Healing Potion
	[271884] = function() return 76097 end, [271883] = function() return 76097 end,
	[241300] = function() return 76098 end, [241301] = function() return 76098 end,            -- mana potion -> Master Mana Potion
	[245917] = function() return 76098 end, [245916] = function() return 76098 end,
	[224464] = function() return 5512 end,                                                     -- Demonic Healthstone
}
-- retail items with no Mists counterpart (the second dps potion, Liquid Luster, ...)
CDM.ITEM_DROP = {
	[241288] = true, [241289] = true, [245902] = true, [245903] = true,
	[271887] = true, [271886] = true, [274764] = true, [274763] = true, [271890] = true,
	[241302] = true, [241303] = true,
}

-- Mists item presets for the spell picker (retail CDM_ITEM_PRESETS).
CDM.ITEM_PRESETS = {
	{ key = "stat_potion", name = "Primary Stat Potion", resolve = StatPotion },
	{ key = "healing_potion", name = "Master Healing Potion", itemID = 76097 },
	{ key = "mana_potion", name = "Master Mana Potion", itemID = 76098 },
	{ key = "healthstone", name = "Healthstone", itemID = 5512 },
}

-- Combat potions by kind (Swap Combat Potions When Missing): Mists, then
-- Cataclysm potions of the same kind.
do
	local groups = {
		{ 76095, 76089, 76093, 58146, 58145, 58091 },   -- stat: Mogu Power, Virmen's Bite, Jade Serpent, Golemblood, Tol'vir, Volcanic
		{ 76097, 57191, 33447 },                        -- healing: Master, Mythical, Runic
		{ 76098, 57192, 33448 },                        -- mana: Master, Mythical, Runic
	}
	CDM.POTION_GROUP = {}
	for _, g in ipairs(groups) do
		for _, id in ipairs(g) do CDM.POTION_GROUP[id] = g end
	end
end

-- Bloodlust family: any of these buffs lights a lust entry.
CDM.LUST_IDS = { 2825, 32182, 80353, 90355 }
CDM.LUST_SET = { [2825] = true, [32182] = true, [80353] = true, [90355] = true }
CDM.SATED_IDS = { 57724, 57723, 80354, 95809 }

-------------------------------------------------------------------------------
--  Spell knowledge
-------------------------------------------------------------------------------
function CDM.IsKnownSpell(id)
	if not id or id <= 0 then return false end
	if IsPlayerSpell and IsPlayerSpell(id) then return true end
	if IsSpellKnown(id) or IsSpellKnown(id, true) then return true end
	-- Override / rank variants: the spellbook knows the spell by name.
	local name = GetSpellInfo(id)
	if name and GetSpellInfo(name) then return true end
	return false
end

-- Hosted buff marker (retail: a buff shown on a cooldown bar).
local HOSTED_BASE = 2000000000

-- Resolves one stored entry for display.
-- Returns nil (hidden) or { id, kind = "spell"|"item"|"slot"|"buff"|"timed",
-- spellID, itemID, slot, name, icon }.
function CDM.ResolveEntry(bd, id, sd)
	if type(id) ~= "number" or id == 0 then return nil end
	local isBuffBar = CDM.IsBuffBar(bd)
	local e = { id = id }
	if id <= -HOSTED_BASE then
		local sid = -id - HOSTED_BASE
		if sid >= 1000000000 then return nil end   -- retail cooldown-claim marker
		local name, _, icon = GetSpellInfo(sid)
		if not name then return nil end
		e.kind, e.spellID, e.name, e.icon = "buff", sid, name, icon
		return e
	end
	if id < 0 then
		local n = -id
		if n <= 19 then
			e.kind, e.slot = "slot", n
			local itemID = GetInventoryItemID("player", n)
			if not itemID then return nil end
			e.itemID = itemID
			e.icon = GetInventoryItemTexture("player", n)
			e.name = GetItemInfo(itemID)
			-- "Show Non-On Use Trinkets" off: a passive trinket is hidden.
			if bd.showPassiveTrinkets == false and not GetItemSpell(itemID) then return nil end
			return e
		end
		if CDM.ITEM_DROP[n] then return nil end
		local remap = CDM.ITEM_REMAP[n]
		if remap then n = remap() end
		if not n then return nil end
		-- Swap Combat Potions When Missing (retail cdmBars.swapPotionsWhenMissing):
		-- with none of this potion in the bags, track another of its kind you own.
		if CDM.DB().cdmBars.swapPotionsWhenMissing and (GetItemCount(n) or 0) == 0 then
			local group = CDM.POTION_GROUP[n]
			if group then
				for _, alt in ipairs(group) do
					if alt ~= n and (GetItemCount(alt) or 0) > 0 then n = alt; break end
				end
			end
		end
		e.kind, e.itemID = "item", n
		e.name = GetItemInfo(n)
		e.icon = GetItemIcon(n)
		if not e.icon then return nil end
		if bd.hideItemsIfMissing and (GetItemCount(n) or 0) == 0 then return nil end
		return e
	end
	-- Positive: a spell.
	local sid = id
	if CDM.ALL_RACIALS[sid] and not isBuffBar then
		sid = CDM.MyRacial() or sid
	end
	local name, _, icon = GetSpellInfo(sid)
	if not name then return nil end
	e.spellID, e.name, e.icon = sid, name, icon
	local dur = sd and sd.spellDurations and sd.spellDurations[id]
	if dur and dur > 0 and not CDM.LUST_SET[sid] then
		e.kind, e.duration = "timed", dur
		return e
	end
	if isBuffBar then
		e.kind = "buff"
		return e
	end
	if not CDM.IsKnownSpell(sid) then return nil end
	e.kind = "spell"
	return e
end

-------------------------------------------------------------------------------
--  Retail profile import (EllesmereUI_ProfilesRetail.lua)
--  blob = retail profile.addons.EllesmereUICooldownManager. The retail string
--  carries the spell lists separately (data.cdmSpells); the wrapper below
--  keeps them for the converter.
-------------------------------------------------------------------------------
do
	local R = ns.ProfileRetail
	if R and R.CONVERT then
		local pendingSpells
		if R.Convert and not R._cdmWrapped then
			local orig = R.Convert
			R._cdmWrapped = true
			R.Convert = function(data, ...)
				pendingSpells = type(data) == "table" and type(data.cdmSpells) == "table" and data.cdmSpells or nil
				local a, b = orig(data, ...)
				pendingSpells = nil
				return a, b
			end
		end
		R.CONVERT[addonName] = function(blob, notes)
			local profile = DeepCopy(blob)
			profile._tbbPresetIconTotal = nil
			local specs
			if pendingSpells then
				specs = {}
				for specKey, sp in pairs(pendingSpells) do
					if type(sp) == "table" then
						local copy = DeepCopy(sp)
						-- Bar Glows: CDM icon glows are keyed by retail cooldownIDs
						-- ("cdm_<id>", no counterpart here) and retail bars 6-8 do
						-- not exist; action bar 1-5 glows are kept.
						local bgl = copy.barGlows
						if type(bgl) == "table" and type(bgl.assignments) == "table" then
							for key in pairs(bgl.assignments) do
								local b = tonumber(tostring(key):match("^(%d+)_%d+$") or "")
								if not (b and b >= 1 and b <= 5) then bgl.assignments[key] = nil end
							end
							bgl.selectedBar = nil
						else
							copy.barGlows = nil
						end
						copy._migrations = nil
						specs[tostring(specKey)] = copy
					end
				end
			else
				local cur = _G.EllesmereUICooldownManagerDB
				specs = type(cur) == "table" and DeepCopy(cur.specProfiles) or {}
				if notes then
					notes[#notes + 1] = "Cooldown Manager: this string has no spell lists; your current spell lists are kept."
				end
			end
			return { profile = profile, specProfiles = specs, _seeded = 1 }
		end
	end
end
