-- EllesmereUI Unit Frames for 5.4.8: Player Aura Bars (retail
-- EllesmereUIUnitFrames_PlayerAuraBars.lua). Retail fills engine aura
-- containers; here one UnitAura scan per change feeds plain icon buttons
-- with the same settings, groups, filters, layout and Unlock Mode keys.
--
-- Settings: UF.db.playerAuraBars (retail db.profile.playerAuraBars, same
-- keys). Bars: the built-in Buffs / Debuffs bars (defaultBuffs /
-- defaultDebuffs) and custom buff / debuff bars (customBuffBars /
-- customDebuffBars, or a spec bucket in pabSpecBars).
--
-- 5.4.8 differences: no aura flags for Crowd Control, Important, Role,
-- Raid In Combat or Bleed (those filters never match and the settings page
-- leaves them out); "Raid" is the 5.4.8 RAID filter (debuffs you can cure);
-- sort "Important" falls back to Default; right-click cancel works out of
-- combat only (CancelUnitBuff is protected in combat and secure buttons
-- cannot show / hide in combat); no icon shapes or textured borders (no
-- masks); Icon Effects glow = the Blizzard action button glow; no Blizzard /
-- Classic style; the settings preview fills the real bars with sample icons.

local addonName = ...
local ns = EllesmereUI
local UF = ns.UF

local floor, ceil, min, max, abs = math.floor, math.ceil, math.min, math.max, math.abs
local format, pairs, ipairs, next, type, tonumber = format, pairs, ipairs, next, type, tonumber
local GetTime, UnitAura, GetSpellInfo = GetTime, UnitAura, GetSpellInfo
local tsort, tinsert, wipe = table.sort, table.insert, wipe

local P = {}       -- file locals that are tables (Lua 5.1 keeps 200 locals per chunk)
UF.PAB = P

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
local function DeepCopy(v)
	if type(v) ~= "table" then
		return v
	end
	local o = {}
	for k, x in pairs(v) do
		o[k] = DeepCopy(x)
	end
	return o
end

-- The settings table (created and seeded on first use).
local function S()
	local db = UF.db
	if not db then
		return nil
	end
	local s = db.playerAuraBars
	if type(s) ~= "table" or not next(s) then
		s = UF.PAB_SeedTable and UF.PAB_SeedTable() or {}
		-- Retail stores "nil = off"; the copied profile had the bars on.
		db.playerAuraBars = s
	end
	if not s.pabFilters then
		s.pabFilters = { nextId = 1, list = {} }
	end
	s.nextBarId = s.nextBarId or 1
	return s
end
P.S = S

function ns.PAB_DefaultBuffsCfg(s)
	s = s or S()
	s.defaultBuffs = s.defaultBuffs or {}
	return s.defaultBuffs
end

function ns.PAB_DefaultDebuffsCfg(s)
	s = s or S()
	s.defaultDebuffs = s.defaultDebuffs or {}
	return s.defaultDebuffs
end

function ns.PAB_DefaultBuffsName()
	return "Buffs"
end

function ns.PAB_Enabled()
	local s = S()
	return s ~= nil and s.enabled == true
end

---------------------------------------------------------------------------
-- Spell helpers
---------------------------------------------------------------------------
local knownCache = {}
-- True when this client has the spell (retail-only ids are hidden).
local function KnownSpell(id)
	local k = knownCache[id]
	if k == nil then
		k = GetSpellInfo(id) ~= nil
		knownCache[id] = k
	end
	return k
end
ns.PAB_KnownSpell = KnownSpell

local function PRESETS()
	return UF.PAB_PRESETS or { BM2_FILTER_SEED = {}, SPELL_CLASS_HINTS = {}, PRESET_ALTS = {}, PAB_SPELL_FAMILY = {} }
end

ns.PAB_SPELL_FAMILY = PRESETS().PAB_SPELL_FAMILY
ns.PAB_SPELL_CLASS_HINTS = PRESETS().SPELL_CLASS_HINTS

---------------------------------------------------------------------------
-- Filter registry (s.pabFilters = { nextId, list = { { id, name, spells, preset } } })
---------------------------------------------------------------------------
local function FilterStore(s)
	s = s or S()
	return s and s.pabFilters
end

function ns.PAB_ImportBM2Filters()
	local store = FilterStore()
	if not store or not PRESETS().ImportPresets then
		return 0
	end
	return PRESETS().ImportPresets(store)
end

-- Presets first (catalogue order), then user filters in creation order.
function ns.PAB_Filters()
	local store = FilterStore()
	if not store then
		return {}
	end
	local order = {}
	for i, seed in ipairs(PRESETS().BM2_FILTER_SEED) do
		order[seed.name] = i
	end
	local out = {}
	for i = 1, #store.list do
		out[#out + 1] = store.list[i]
	end
	tsort(out, function(a, b)
		local pa = a.preset and order[a.name] or nil
		local pb = b.preset and order[b.name] or nil
		if pa and pb then return pa < pb end
		if pa then return true end
		if pb then return false end
		return (a.id or 0) < (b.id or 0)
	end)
	return out
end

function ns.PAB_GetFilter(id)
	local store = FilterStore()
	if not store then
		return nil
	end
	for i = 1, #store.list do
		if store.list[i].id == id then
			return store.list[i]
		end
	end
end

function ns.PAB_AddFilter(name)
	local store = FilterStore()
	local f = { id = store.nextId, name = name or "New Filter", spells = {} }
	store.nextId = store.nextId + 1
	store.list[#store.list + 1] = f
	return f
end

function ns.PAB_RenameFilter(id, name)
	local f = ns.PAB_GetFilter(id)
	if f and not f.preset and name and name ~= "" then
		f.name = name
	end
end

local function EachBuffCfg(fn)
	local s = S()
	fn(ns.PAB_DefaultBuffsCfg(s))
	for _, bar in ipairs(s.customBuffBars or {}) do
		fn(bar)
	end
	for _, bucket in pairs(s.pabSpecBars or {}) do
		for _, bar in ipairs(bucket.buffBars or {}) do
			fn(bar)
		end
	end
end

-- Removes the filter and its use on every buff bar.
function ns.PAB_DeleteFilter(id)
	local store = FilterStore()
	local f = ns.PAB_GetFilter(id)
	if not f or f.preset then
		return
	end
	for i = #store.list, 1, -1 do
		if store.list[i].id == id then
			table.remove(store.list, i)
		end
	end
	EachBuffCfg(function(cfg)
		if cfg.filters then cfg.filters[id] = nil end
		if cfg.negFilters then cfg.negFilters[id] = nil end
		if cfg.filters and not next(cfg.filters) then cfg.filters = nil end
		if cfg.negFilters and not next(cfg.negFilters) then cfg.negFilters = nil end
		if cfg.enabled ~= false and not ns.PAB_BuffBarHasContent(cfg) then
			cfg.showAllBuffs = nil
		end
	end)
end

-- state: true (checked), false (unchecked, row kept), nil (removed).
-- Applies to the whole family and same-named ids in the filter.
function ns.PAB_SetSpellState(filterId, spellID, state)
	local f = ns.PAB_GetFilter(filterId)
	if not f then
		return
	end
	f.spells = f.spells or {}
	local fam = ns.PAB_SPELL_FAMILY[spellID]
	local name = GetSpellInfo(spellID)
	local targets = { spellID }
	if fam then
		for _, id in ipairs(fam) do
			if f.spells[id] ~= nil then targets[#targets + 1] = id end
		end
	end
	if name then
		for id in pairs(f.spells) do
			if GetSpellInfo(id) == name then targets[#targets + 1] = id end
		end
	end
	for _, id in ipairs(targets) do
		f.spells[id] = state
	end
end

function ns.PAB_AddSpellToFilter(filterId, spellID)
	local f = ns.PAB_GetFilter(filterId)
	if not f or not spellID or spellID <= 0 then
		return false
	end
	f.spells = f.spells or {}
	if f.spells[spellID] ~= nil then
		return false
	end
	f.spells[spellID] = true
	return true
end

-- Every preset id (with alts), sorted.
function ns.PAB_AllPresetSpells()
	local seen, out = {}, {}
	for _, seed in ipairs(PRESETS().BM2_FILTER_SEED) do
		for _, list in ipairs({ seed.enabled, seed.disabled }) do
			for _, id in ipairs(list) do
				if not seen[id] then
					seen[id] = true
					out[#out + 1] = id
				end
			end
		end
	end
	tsort(out)
	return out
end

-- Enabled spells of a filter, family-expanded (an explicit false wins).
local function AddFilterSpells(set, f)
	if not f or not f.spells then
		return
	end
	for id, on in pairs(f.spells) do
		if on == true then
			set[id] = true
			local fam = ns.PAB_SPELL_FAMILY[id]
			if fam then
				for _, alt in ipairs(fam) do
					if f.spells[alt] ~= false then set[alt] = true end
				end
			end
		end
	end
end

local function AddFamily(set, id)
	set[id] = true
	local fam = ns.PAB_SPELL_FAMILY[id]
	if fam then
		for _, alt in ipairs(fam) do set[alt] = true end
	end
end

-- Spell sets of a buff bar: shown (add mode), extra spells, hidden.
local function BuffSpellSets(cfg)
	local show, extra, hide = {}, {}, {}
	for _, id in ipairs(cfg.spells or {}) do
		AddFamily(extra, id)
	end
	for fid in pairs(cfg.filters or {}) do
		AddFilterSpells(show, ns.PAB_GetFilter(fid))
	end
	for fid in pairs(cfg.negFilters or {}) do
		AddFilterSpells(hide, ns.PAB_GetFilter(fid))
	end
	return show, extra, hide
end

-- Spells of the "spells" group (add mode: filters + extra minus hidden), sorted.
function ns.PAB_ResolveSpells(cfg)
	local show, extra, hide = BuffSpellSets(cfg)
	local out = {}
	for id in pairs(show) do
		if not hide[id] or extra[id] then out[#out + 1] = id end
	end
	for id in pairs(extra) do
		if not show[id] then out[#out + 1] = id end
	end
	tsort(out)
	return out
end

-- Retail <-> WoW Forever helpers: nothing is hidden on this client.
function ns.PAB_OtherClientSpell() return false end
function ns.PAB_HiddenPresetFilter() return false end

---------------------------------------------------------------------------
-- Debuff categories (retail class vocabulary, 5.4.8 tests)
---------------------------------------------------------------------------
-- skey (saved) <-> engine key, label, tooltip, available on 5.4.8.
P.CLASSES = {
	{ key = "raid", skey = "Raid", label = "Raid", tip = "Shows only debuffs from Blizzard's curated raid-frame debuff set", mop = true },
	{ key = "raidcombat", skey = "RaidInCombat", label = "Raid In Combat", tip = "Shows only the stricter in-combat subset of the raid set" },
	{ key = "dispellable", skey = "Dispellable", label = "Dispellable By You", tip = "Shows only auras with a dispel type you can dispel", mop = true },
	{ key = "cc", skey = "CrowdControl", label = "Crowd Control", tip = "Shows only crowd-control auras" },
	{ key = "bigdef", skey = "BigDefensive", label = "Big Defensive", tip = "Shows only major defensive cooldowns" },
	{ key = "extdef", skey = "ExternalDefensive", label = "External Defensive", tip = "Shows only external defensive cooldowns cast on the unit" },
	{ key = "castbyme", skey = "CastByMe", label = "Cast By You", tip = "Debuffs applied by you or your pet", mop = true },
	{ key = "nonplayer", skey = "NonPlayer", label = "Non-Player Auras", tip = "Shows only debuffs not caused by any player or player pet (this is what shows most pve debuffs, do not check this while All Debuffs is selected!", mop = true },
	{ key = "anyplayer", skey = "AnyPlayer", label = "From Any Player", tip = "Debuffs caused by any player or player pet. The opposite of Non-Player Auras; checking one clears the other", mop = true },
	{ key = "bossaura", skey = "BossAura", label = "Boss Debuffs", tip = "Shows only debuffs applied by bosses", mop = true },
	{ key = "roleaura", skey = "RoleAura", label = "Role Debuffs", tip = "Shows only debuffs flagged for your role" },
	{ key = "canapply", skey = "CanApply", label = "Can Apply Aura", tip = "Debuffs your own class is able to apply", mop = true },
	{ key = "magic", skey = "DispelMagic", label = "Magic", tip = "Debuffs with the Magic dispel type", mop = true, dtype = "Magic" },
	{ key = "curse", skey = "DispelCurse", label = "Curse", tip = "Debuffs with the Curse dispel type", mop = true, dtype = "Curse" },
	{ key = "poison", skey = "DispelPoison", label = "Poison", tip = "Debuffs with the Poison dispel type", mop = true, dtype = "Poison" },
	{ key = "disease", skey = "DispelDisease", label = "Disease", tip = "Debuffs with the Disease dispel type", mop = true, dtype = "Disease" },
	{ key = "bleed", skey = "DispelBleed", label = "Bleed", tip = "Debuffs with the Bleed dispel type", dtype = "Bleed" },
	{ key = "priority", skey = "PriorityAura", label = "Important", tip = "Shows only debuffs Blizzard flags as important" },
	{ key = "dispeltyped", skey = "DispelTyped", label = "Dispels", tip = "Shows any debuff with a dispel type (Magic, Curse, Disease, Poison), even if you cannot remove it", mop = true },
}
P.CLASS_BY_KEY, P.CLASS_BY_SKEY = {}, {}
for _, c in ipairs(P.CLASSES) do
	P.CLASS_BY_KEY[c.key] = c
	P.CLASS_BY_SKEY[c.skey] = c
end
-- Safe to force on from an Icon Effects block while All Debuffs is on.
P.FX_UNSAFE = { bossaura = true, roleaura = true, priority = true, canapply = true }

ns.PAB_ExclusiveSkey = { NonPlayer = "AnyPlayer", AnyPlayer = "NonPlayer" }

-- Settings dropdown order (retail DEBUFF_FILTER_ORDER, 5.4.8 rows only).
P.DEBUFF_FILTER_ORDER = {
	"nonplayer", "bossaura", "raid", "dispellable", "dispeltyped", "__less",
	"castbyme", "anyplayer", "magic", "curse", "poison", "disease", "canapply",
}

function ns.PAB_ClassItems()
	local items = {}
	for _, key in ipairs(P.DEBUFF_FILTER_ORDER) do
		if key == "__less" then
			items[#items + 1] = { isHeader = true, label = "Less Common Filters" }
		else
			local c = P.CLASS_BY_KEY[key]
			items[#items + 1] = { key = c.skey, label = c.label, tooltip = c.tip }
		end
	end
	return items
end

function ns.PAB_FxClassItems()
	local items = {}
	for _, key in ipairs(P.DEBUFF_FILTER_ORDER) do
		if key ~= "__less" then
			local c = P.CLASS_BY_KEY[key]
			items[#items + 1] = { key = c.key, label = c.label, tooltip = c.tip }
		end
	end
	return items
end

local playerClass = select(2, UnitClass("player"))

local function IsMine(caster)
	return caster == "player" or caster == "pet" or caster == "vehicle"
end

-- One debuff (record from the scan) against one engine class key.
local function ClassMatch(key, a)
	if key == "raid" or key == "raidcombat" then
		return a.raid == true
	elseif key == "dispellable" then
		local list = UF.DISPEL_BY_CLASS and UF.DISPEL_BY_CLASS[playerClass]
		return a.dtype ~= nil and list ~= nil and list[a.dtype] == true
	elseif key == "castbyme" then
		return IsMine(a.caster)
	elseif key == "nonplayer" then
		return not UF.DebuffFromPlayer(a.caster, a.spellId)
	elseif key == "anyplayer" then
		return UF.DebuffFromPlayer(a.caster, a.spellId)
	elseif key == "bossaura" then
		return a.isBoss == true
	elseif key == "canapply" then
		return a.canApply == true
	elseif key == "dispeltyped" then
		return a.dtype ~= nil and a.dtype ~= ""
	end
	local c = P.CLASS_BY_KEY[key]
	if c and c.dtype then
		return a.dtype == c.dtype
	end
	return false
end
P.ClassMatch = ClassMatch

-- Group order of a Match Any debuff bar (retail token, then candidate classes).
P.GROUP_ORDER = {
	"raid", "raidcombat", "dispellable", "cc", "bigdef", "extdef", "castbyme",
	"nonplayer", "anyplayer", "bossaura", "roleaura", "canapply",
	"magic", "curse", "poison", "disease", "bleed", "priority", "dispeltyped",
}

---------------------------------------------------------------------------
-- Content tests (settings page warnings)
---------------------------------------------------------------------------
local function HasTrue(map)
	if map then
		for _, v in pairs(map) do
			if v == true then return true end
		end
	end
	return false
end

function ns.PAB_BuffBarHasContent(cfg)
	if cfg.showAllBuffs ~= false or cfg.hasDuration == true then
		return true
	end
	if cfg.spells and #cfg.spells > 0 then
		return true
	end
	return HasTrue(cfg.filters)
end

local function FxList(cfg)
	local out = nil
	for _, e in ipairs(cfg.fxList or {}) do
		if e.filters and next(e.filters) and ((e.glowType or 0) > 0 or (e.borderSize or 0) > 0 or (e.size or 0) > 0) then
			out = out or {}
			out[#out + 1] = e
		end
	end
	return out
end
P.FxList = FxList

local function FxWants(cfg, key)
	local list = FxList(cfg)
	if list then
		for _, e in ipairs(list) do
			if e.filters[key] then return true end
		end
	end
	return false
end

function ns.PAB_DebuffBarHasContent(cfg)
	if cfg.showAllDebuffs ~= false or cfg.hasDuration == true then
		return true
	end
	if HasTrue(cfg.classFilters) then
		return true
	end
	for _, c in ipairs(P.CLASSES) do
		if not P.FX_UNSAFE[c.key] and FxWants(cfg, c.key) then
			return true
		end
	end
	return false
end

-- Match All picks (show lane) of a debuff bar, or nil when Match Any applies.
local function MatchAllPicks(cfg)
	if cfg.debuffMatch ~= "all" or cfg.showAllDebuffs ~= false then
		return nil
	end
	local picks = {}
	for skey, v in pairs(cfg.classFilters or {}) do
		local c = P.CLASS_BY_SKEY[skey]
		if v == true and c then picks[#picks + 1] = c.key end
	end
	if #picks < 2 then
		return nil
	end
	return picks
end

-- True when Match All can never match (opposite picks).
function ns.PAB_DebuffMatchEmpty(cfg)
	local picks = MatchAllPicks(cfg)
	if not picks then
		return false
	end
	local on, hidden = {}, {}
	for _, k in ipairs(picks) do on[k] = true end
	for skey, v in pairs(cfg.negClassFilters or {}) do
		local c = P.CLASS_BY_SKEY[skey]
		if v and c then hidden[c.key] = true end
	end
	if on.nonplayer and (on.castbyme or on.anyplayer) then return true end
	if on.castbyme and hidden.anyplayer then return true end
	if on.anyplayer and hidden.anyplayer then return true end
	for _, k in ipairs({ "magic", "curse", "poison", "disease" }) do
		if on[k] and (hidden[k] or hidden.dispeltyped) then return true end
	end
	if (on.dispellable or on.dispeltyped) and hidden.magic and hidden.curse and hidden.poison and hidden.disease then
		return true
	end
	for k in pairs(on) do
		if hidden[k] then return true end
	end
	return false
end

-- Weapon enchants ride the default Buffs bar in its broad modes.
function ns.PAB_EnchantsOn(cfg)
	if not cfg or (cfg.showAllBuffs == false and cfg.hasDuration ~= true) then
		return false
	end
	local s = S()
	return s ~= nil and s.defaultBuffs == cfg
end

---------------------------------------------------------------------------
-- Spec buckets ("allspecs", "nonhealer", "tanks", "dps", "healers", "spec<ID>")
---------------------------------------------------------------------------
P.GROUP_BUCKETS = {
	{ key = "nonhealer", name = "All Non-Healers" },
	{ key = "tanks", name = "All Tanks" },
	{ key = "dps", name = "All DPS" },
	{ key = "healers", name = "All Healers" },
}

local function RoleOfSpec(specID)
	if not specID or not GetSpecializationInfoByID then
		return nil
	end
	-- 5.4.8: role is the 6th return (retail: 5th).
	local _, _, _, _, _, role = GetSpecializationInfoByID(specID)
	if role == "HEALER" then return "healers" end
	if role == "TANK" then return "tanks" end
	if role then return "dps" end
	return nil
end
ns.PAB_RoleBucketForSpecID = RoleOfSpec

local function CurrentSpecID()
	local i = GetSpecialization and GetSpecialization()
	if not i then
		return nil
	end
	return (GetSpecializationInfo(i))
end
P.CurrentSpecID = CurrentSpecID

local function SpecBucket(s, key, create)
	if key == nil or key == "allspecs" then
		return nil
	end
	s.pabSpecBars = s.pabSpecBars or (create and {}) or nil
	if not s.pabSpecBars then
		return nil
	end
	local b = s.pabSpecBars[key]
	if not b and create then
		b = { buffBars = {}, debuffBars = {} }
		s.pabSpecBars[key] = b
	end
	return b
end

-- Bar array of a bucket (allspecs = the legacy arrays).
function ns.PAB_BucketBars(isBuff, key, create)
	local s = S()
	if key == nil or key == "allspecs" then
		local field = isBuff and "customBuffBars" or "customDebuffBars"
		s[field] = s[field] or {}
		return s[field]
	end
	local b = SpecBucket(s, key, create)
	if not b then
		return {}
	end
	local field = isBuff and "buffBars" or "debuffBars"
	b[field] = b[field] or {}
	return b[field]
end

function ns.PAB_InheritedGroupsFor(key)
	local id = type(key) == "string" and tonumber(key:match("^spec(%d+)$"))
	if not id then
		return {}
	end
	local role = RoleOfSpec(id)
	local out = { "allspecs" }
	if role ~= "healers" then out[#out + 1] = "nonhealer" end
	if role then out[#out + 1] = role end
	return out
end

function ns.PAB_InhDisabled(specKey, id)
	local s = S()
	local b = s.pabSpecBars and s.pabSpecBars[specKey]
	return b and b.inhDis and b.inhDis[id] and true or false
end

function ns.PAB_SetInhDisabled(specKey, id, disabled)
	local b = SpecBucket(S(), specKey, true)
	b.inhDis = b.inhDis or {}
	b.inhDis[id] = disabled and true or nil
end

local function BucketApplies(key, specID)
	if key == nil or key == "allspecs" then
		return true
	end
	local id = tonumber(key:match("^spec(%d+)$"))
	if id then
		return id == specID
	end
	local role = RoleOfSpec(specID)
	if key == "nonhealer" then
		return role ~= "healers"
	end
	return role == key
end

-- Render verdict of a custom bar in its bucket.
function ns.PAB_BarActive(bar, key)
	local s = S()
	if not s or s.enabled ~= true or bar.enabled == false then
		return false
	end
	local spec = CurrentSpecID()
	if not BucketApplies(key, spec) then
		return false
	end
	if spec and not (type(key) == "string" and key:match("^spec%d")) and ns.PAB_InhDisabled("spec" .. spec, bar.id) then
		return false
	end
	return true
end

-- Every custom bar with its bucket key: { bar, isBuff, bucket }.
local function AllCustomBars()
	local s = S()
	local out = {}
	for _, isBuff in ipairs({ true, false }) do
		for _, bar in ipairs(s[isBuff and "customBuffBars" or "customDebuffBars"] or {}) do
			out[#out + 1] = { bar = bar, isBuff = isBuff, bucket = "allspecs" }
		end
		for key, b in pairs(s.pabSpecBars or {}) do
			for _, bar in ipairs(b[isBuff and "buffBars" or "debuffBars"] or {}) do
				out[#out + 1] = { bar = bar, isBuff = isBuff, bucket = key }
			end
		end
	end
	return out
end
P.AllCustomBars = AllCustomBars

function ns.PAB_CustomBuffBars()
	return ns.PAB_BucketBars(true, "allspecs")
end

function ns.PAB_CustomDebuffBars()
	return ns.PAB_BucketBars(false, "allspecs")
end

local function FindCustom(id, isBuff)
	for _, e in ipairs(AllCustomBars()) do
		if e.bar.id == id and e.isBuff == isBuff then
			return e.bar, e.bucket
		end
	end
end

function ns.PAB_GetCustomBuffBar(id) return FindCustom(id, true) end
function ns.PAB_GetCustomDebuffBar(id) return FindCustom(id, false) end

local function NextBarId(s)
	local id = s.nextBarId or 1
	for _, e in ipairs(AllCustomBars()) do
		if (e.bar.id or 0) >= id then id = e.bar.id + 1 end
	end
	s.nextBarId = id + 1
	return id
end

function ns.PAB_AddCustomBuffBar(name, bucket)
	local s = S()
	local bar = { id = NextBarId(s), name = name or "New Buff Bar", enabled = true,
		filters = {}, spells = {}, ownOnlySpells = {},
		growDirection = "LEFT", iconsPerRow = 8, maxRows = 1, maxTotal = 8 }
	tinsert(ns.PAB_BucketBars(true, bucket, true), bar)
	return bar
end

function ns.PAB_AddCustomDebuffBar(name, bucket)
	local s = S()
	local bar = { id = NextBarId(s), name = name or "New Debuff Bar", enabled = true,
		classFilters = {}, growDirection = "LEFT", iconsPerRow = 8, maxRows = 1, maxTotal = 8 }
	tinsert(ns.PAB_BucketBars(false, bucket, true), bar)
	return bar
end

function ns.PAB_CopyCustomBar(isBuff, src, bucket)
	local copy = DeepCopy(src)
	copy.id = NextBarId(S())
	tinsert(ns.PAB_BucketBars(isBuff, bucket, true), copy)
	return copy
end

local function DeleteCustom(id, isBuff)
	local s = S()
	local lists = { s[isBuff and "customBuffBars" or "customDebuffBars"] }
	for _, b in pairs(s.pabSpecBars or {}) do
		lists[#lists + 1] = b[isBuff and "buffBars" or "debuffBars"]
		if b.inhDis then b.inhDis[id] = nil end
	end
	for _, list in ipairs(lists) do
		for i = #(list or {}), 1, -1 do
			if list[i].id == id then table.remove(list, i) end
		end
	end
end

function ns.PAB_DeleteCustomBuffBar(id)
	DeleteCustom(id, true)
	P.ReloadAll()
end

function ns.PAB_DeleteCustomDebuffBar(id)
	DeleteCustom(id, false)
	P.ReloadAll()
end

---------------------------------------------------------------------------
-- Aura scan (one pass per UNIT_AURA, shared by every bar)
---------------------------------------------------------------------------
local rawDebuffs = {}
P.buffs, P.debuffs = {}, rawDebuffs
local pool = {}

local function NewRecord()
	local r = tremove(pool)
	return r or {}
end

local function Scan()
	for _, list in ipairs({ P.buffs, rawDebuffs }) do
		for i = #list, 1, -1 do
			pool[#pool + 1] = wipe(list[i])
			list[i] = nil
		end
	end
	for i = 1, 40 do
		local name, _, icon, count, dtype, duration, expires, caster, stealable, _, spellId, canApply, isBoss = UnitAura("player", i, "HELPFUL")
		if not name then break end
		local r = NewRecord()
		r.index, r.filter, r.name, r.icon, r.count, r.dtype = i, "HELPFUL", name, icon, count or 0, dtype
		r.duration, r.expires, r.caster, r.stealable, r.spellId = duration or 0, expires or 0, caster, stealable, spellId
		r.canApply, r.isBoss = canApply, isBoss
		P.buffs[#P.buffs + 1] = r
	end
	-- "Raid" (5.4.8 RAID filter: debuffs you can cure), matched by spell + expiry.
	local raid = P.raidSet or {}
	wipe(raid)
	P.raidSet = raid
	for i = 1, 40 do
		local name, _, _, _, _, _, expires, _, _, _, spellId = UnitAura("player", i, "HARMFUL|RAID")
		if not name then break end
		raid[(spellId or 0) .. ":" .. (expires or 0)] = true
	end
	for i = 1, 40 do
		local name, _, icon, count, dtype, duration, expires, caster, stealable, _, spellId, canApply, isBoss = UnitAura("player", i, "HARMFUL")
		if not name then break end
		local r = NewRecord()
		r.index, r.filter, r.name, r.icon, r.count, r.dtype = i, "HARMFUL", name, icon, count or 0, dtype
		r.duration, r.expires, r.caster, r.stealable, r.spellId = duration or 0, expires or 0, caster, stealable, spellId
		r.canApply, r.isBoss = canApply, isBoss
		r.raid = raid[(spellId or 0) .. ":" .. (expires or 0)] or nil
		rawDebuffs[#rawDebuffs + 1] = r
	end
	P.debuffs = ns.FilterDuplicateDiseases(rawDebuffs)
end

---------------------------------------------------------------------------
-- Sorting (inside one group)
---------------------------------------------------------------------------
local sortRev
local function ByIndex(a, b)
	if sortRev then return a.index > b.index end
	return a.index < b.index
end
local function ByExpiration(a, b)
	local ea = (a.expires and a.expires > 0) and a.expires or math.huge
	local eb = (b.expires and b.expires > 0) and b.expires or math.huge
	if ea == eb then return ByIndex(a, b) end
	if sortRev then return ea > eb end
	return ea < eb
end
local function ByName(a, b)
	if a.name == b.name then return ByIndex(a, b) end
	if sortRev then return a.name > b.name end
	return a.name < b.name
end

local function SortGroup(list, cfg)
	if #list < 2 and not cfg.sortDirection then
		return
	end
	sortRev = cfg.sortDirection == "Reverse"
	local m = cfg.sortMethod
	if m == "Expiration" then
		tsort(list, ByExpiration)
	elseif m == "Name" then
		tsort(list, ByName)
	else
		tsort(list, ByIndex)
	end
end

---------------------------------------------------------------------------
-- Content of one bar: ordered list of { rec, cat } (cat = group key)
---------------------------------------------------------------------------
P.EXHAUSTION = { [57723] = true, [57724] = true, [80354] = true, [95809] = true }

local function DurationOK(a, cap)
	if not cap then
		return true
	end
	return a.duration > 0 and a.duration <= cap
end

local function BuffContent(cfg, out, limit)
	local broad = cfg.showAllBuffs ~= false or cfg.hasDuration == true
	local show, extra, hide = BuffSpellSets(cfg)
	local black = broad and cfg.blacklist or nil
	local used = {}
	local groupA, groupB = {}, {}
	for _, a in ipairs(P.buffs) do
		local id = a.spellId
		if broad then
			local blocked = (black and id and black[id]) or (cfg.hasDuration == true and a.duration == 0)
			if not blocked then
				if not (id and hide[id] and not extra[id]) then
					groupA[#groupA + 1] = a
					used[a] = true
				elseif id and extra[id] then
					groupB[#groupB + 1] = a
				end
			end
		else
			if id and (extra[id] or (show[id] and not hide[id])) then
				groupB[#groupB + 1] = a
			end
		end
	end
	SortGroup(groupA, cfg)
	SortGroup(groupB, cfg)
	for _, g in ipairs({ groupA, groupB }) do
		for _, a in ipairs(g) do
			if #out >= limit then return end
			out[#out + 1] = a
			out[a] = "all"
		end
	end
end

local function DebuffContent(cfg, out, limit)
	local cap = cfg.maxDurSec or (cfg.hasDuration and math.huge) or nil
	local hidden = {}
	for skey, v in pairs(cfg.negClassFilters or {}) do
		local c = P.CLASS_BY_SKEY[skey]
		if v and c then hidden[#hidden + 1] = c.key end
	end
	-- Hide Exhaustion (retail cfg.hideExhaustion, off by default): Sated,
	-- Exhaustion, Temporal Displacement, Insanity. Debuff Blacklist
	-- (backport addition): spells that never show on this bar, in every mode.
	local hideExh = cfg.hideExhaustion == true
	local black = cfg.blacklist
	local function Hidden(a)
		local id = a.spellId
		if id and ((hideExh and P.EXHAUSTION[id]) or (black and black[id])) then return true end
		for _, k in ipairs(hidden) do
			if ClassMatch(k, a) then return true end
		end
		return false
	end
	local picks = MatchAllPicks(cfg)
	if picks then
		if ns.PAB_DebuffMatchEmpty(cfg) then
			return
		end
		local types, others = {}, {}
		for _, k in ipairs(picks) do
			local c = P.CLASS_BY_KEY[k]
			if c.dtype then
				types[#types + 1] = k
			elseif k ~= "dispeltyped" then
				others[#others + 1] = k
			else
				others[#others + 1] = k
			end
		end
		local g = {}
		for _, a in ipairs(P.debuffs) do
			if DurationOK(a, cap) and not Hidden(a) then
				local ok = true
				for _, k in ipairs(others) do
					if not (k == "dispeltyped" and #types > 0) and not ClassMatch(k, a) then
						ok = false
						break
					end
				end
				if ok and #types > 0 then
					ok = false
					for _, k in ipairs(types) do
						if ClassMatch(k, a) then ok = true break end
					end
				end
				if ok then g[#g + 1] = a end
			end
		end
		SortGroup(g, cfg)
		for _, a in ipairs(g) do
			if #out >= limit then return end
			out[#out + 1] = a
			out[a] = "match"
		end
		return
	end

	local allOn = cfg.showAllDebuffs ~= false
	local active = {}
	for _, key in ipairs(P.GROUP_ORDER) do
		local c = P.CLASS_BY_KEY[key]
		local on = not allOn and cfg.classFilters and cfg.classFilters[c.skey] == true
		if not on and not P.FX_UNSAFE[key] and FxWants(cfg, key) then
			on = true
		end
		if on then active[#active + 1] = key end
	end
	local catchAll = allOn or (cfg.hasDuration == true and not HasTrue(cfg.classFilters))
	local groups, rest = {}, {}
	for i = 1, #active do groups[i] = {} end
	for _, a in ipairs(P.debuffs) do
		if DurationOK(a, cap) and not Hidden(a) then
			local placed = false
			for i, key in ipairs(active) do
				if ClassMatch(key, a) then
					groups[i][#groups[i] + 1] = a
					placed = true
					break
				end
			end
			if not placed and catchAll then
				rest[#rest + 1] = a
			end
		end
	end
	for i, key in ipairs(active) do
		local g = groups[i]
		SortGroup(g, cfg)
		for _, a in ipairs(g) do
			if #out >= limit then return end
			out[#out + 1] = a
			out[a] = key
		end
	end
	SortGroup(rest, cfg)
	for _, a in ipairs(rest) do
		if #out >= limit then return end
		out[#out + 1] = a
		out[a] = "all"
	end
end

---------------------------------------------------------------------------
-- Grid (retail ComputeGrid)
---------------------------------------------------------------------------
local function Snap(v)
	return UF.Snap and UF.Snap(v) or v
end

local function MaxIconSize(isBuff, cfg)
	local size = cfg.iconSize or 32
	if not isBuff then
		for _, e in ipairs(FxList(cfg) or {}) do
			local sz = tonumber(e.size)
			if sz and sz > size then size = sz end
		end
	end
	return Snap(size)
end

local function ComputeGrid(isBuff, cfg)
	local iconSize = MaxIconSize(isBuff, cfg)
	local pad = Snap(cfg.padding or 5)
	local rowGap = Snap(cfg.rowSpacing or 12)
	local cols = max(1, cfg.iconsPerRow or (isBuff and 11 or 8))
	local rows = max(1, cfg.maxRows or (isBuff and 3 or 2))
	local effMax = min(cfg.maxTotal or (isBuff and 32 or 16), rows * cols)
	local usedRows = min(rows, max(1, ceil(effMax / cols)))
	local dir = cfg.growDirection or "LEFT"
	local vertical = dir == "UP" or dir == "DOWN" or dir == "CENTER_VERTICAL"
	local lineExtent = cols * iconSize + (cols - 1) * pad
	local crossExtent = usedRows * iconSize + (usedRows - 1) * rowGap
	return {
		iconSize = iconSize, pad = pad, rowGap = rowGap, cols = cols, effMax = effMax,
		vertical = vertical, dir = dir,
		width = max(1, vertical and crossExtent or lineExtent),
		height = max(1, vertical and lineExtent or crossExtent),
	}
end
P.ComputeGrid = ComputeGrid

-- Fixed start corner of the flow (retail CornerFor).
local function CornerFor(dir, wrap)
	if dir == "CENTER_VERTICAL" then return "TOP" end
	if dir == "UP" or dir == "DOWN" then
		return ((dir == "UP") and "BOTTOM" or "TOP") .. ((wrap == "RIGHT") and "LEFT" or "RIGHT")
	end
	if dir == "LEFT" or dir == "RIGHT" then
		return ((wrap == "UP") and "BOTTOM" or "TOP") .. ((dir == "RIGHT") and "LEFT" or "RIGHT")
	end
	return "TOPLEFT"
end

local FRAC_X = { TOPLEFT = 0, LEFT = 0, BOTTOMLEFT = 0, TOP = 0.5, CENTER = 0.5, BOTTOM = 0.5, TOPRIGHT = 1, RIGHT = 1, BOTTOMRIGHT = 1 }
local FRAC_Y = { BOTTOMLEFT = 0, BOTTOM = 0, BOTTOMRIGHT = 0, LEFT = 0.5, CENTER = 0.5, RIGHT = 0.5, TOPLEFT = 1, TOP = 1, TOPRIGHT = 1 }

-- TOPLEFT offsets of the n-th icon (0-based) of `count` inside the grid box.
local function IconOffset(grid, cfg, n, count)
	local size, pad, gap, cols = grid.iconSize, grid.pad, grid.rowGap, grid.cols
	local line, pos = floor(n / cols), n % cols
	local dir = grid.dir
	local wrap = cfg.iconWrapDirection or "LEFT"
	local W, H = grid.width, grid.height
	if dir == "CENTER_HORIZONTAL" then
		local inLine = min(cols, count - line * cols)
		local runW = inLine * size + (inLine - 1) * pad
		local x = (W - runW) / 2 + pos * (size + pad)
		return x, -(line * (size + gap))
	elseif dir == "CENTER_VERTICAL" then
		local inLine = min(cols, count - line * cols)
		local runH = inLine * size + (inLine - 1) * pad
		local y = (H - runH) / 2 + pos * (size + pad)
		return line * (size + gap), -y
	end
	local along = pos * (size + pad)
	local across = line * (size + gap)
	local x, y
	if grid.vertical then
		y = (dir == "UP") and (H - size - along) or along
		x = (wrap == "RIGHT") and across or (W - size - across)
	else
		x = (dir == "RIGHT") and along or (W - size - along)
		y = (wrap == "UP") and (H - size - across) or across
	end
	return x, -y
end

---------------------------------------------------------------------------
-- Text
---------------------------------------------------------------------------
local OPPOSITE = {
	TOP = "BOTTOM", BOTTOM = "TOP", LEFT = "RIGHT", RIGHT = "LEFT",
	TOPLEFT = "BOTTOMRIGHT", TOPRIGHT = "BOTTOMLEFT", BOTTOMLEFT = "TOPRIGHT", BOTTOMRIGHT = "TOPLEFT",
	CENTER = "CENTER",
}

local function FontFlag(mode)
	if mode == "none" then return "" end
	if mode == "outline" then return "OUTLINE" end
	if mode == "thick" then return "THICKOUTLINE" end
	return ns.GetIconTextOutlineFlag and ns.GetIconTextOutlineFlag("unitFrames") or "OUTLINE"
end

local function SetFont(fs, size, mode)
	local face = ns.GetFontPath and ns.GetFontPath("unitFrames") or UF.FONT
	local flag = FontFlag(mode)
	fs:SetFont(face, size, flag)
	if not fs:GetFont() then
		fs:SetFont(UF.FONT_FALLBACK or "Fonts\\ARIALN.TTF", size, flag)
	end
	if flag == "" then
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 1)
	else
		fs:SetShadowOffset(0, 0)
	end
end

-- Retail AuraKit duration format.
local function DurationText(r, seconds, precise)
	if r < 60 then
		return format(seconds and "%ds" or "%d", ceil(r))
	end
	if precise and precise > 60 and r < min(precise, 3599) then
		local t = ceil(r)
		return format("%d:%02d", floor(t / 60), t % 60)
	end
	if r < 61 then return "1m" end
	if r < 3600 then return format("%dm", floor(r / 60)) end
	if r < 86400 then return format("%dh", floor(r / 3600)) end
	return format("%dd", floor(r / 86400))
end
P.DurationText = DurationText

---------------------------------------------------------------------------
-- Icons
---------------------------------------------------------------------------
P.DISPEL_SLOTS = {
	{ token = "Magic", key = "dispelColorMagic", fallback = { 0.349, 0.475, 1.0 } },
	{ token = "Curse", key = "dispelColorCurse", fallback = { 0.636, 0.0, 0.64 } },
	{ token = "Disease", key = "dispelColorDisease", fallback = { 0.671, 0.384, 0.098 } },
	{ token = "Poison", key = "dispelColorPoison", fallback = { 0.0, 0.706, 0.286 } },
	{ token = "Bleed", key = "dispelColorBleed", fallback = { 0.75, 0.15, 0.15 } },
}
P.DISPEL_ICONS = {
	Magic = "Interface\\RaidFrame\\Raid-Icon-DebuffMagic",
	Curse = "Interface\\RaidFrame\\Raid-Icon-DebuffCurse",
	Disease = "Interface\\RaidFrame\\Raid-Icon-DebuffDisease",
	Poison = "Interface\\RaidFrame\\Raid-Icon-DebuffPoison",
}

local function DispelColor(cfg, dtype)
	for _, d in ipairs(P.DISPEL_SLOTS) do
		if d.token == dtype then
			local c = cfg[d.key]
			if c then return c.r or d.fallback[1], c.g or d.fallback[2], c.b or d.fallback[3] end
			return d.fallback[1], d.fallback[2], d.fallback[3]
		end
	end
end

local function IconOnEnter(self)
	local bar = self.bar
	if not bar or bar.cfg.showTooltips == false then
		return
	end
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
	if self.enchantSlot then
		GameTooltip:SetInventoryItem("player", self.enchantSlot)
	elseif self.rec and self.rec.index and not self.fake then
		GameTooltip:SetUnitAura("player", self.rec.index, self.rec.filter)
	elseif self.spellId then
		GameTooltip:SetSpellByID(self.spellId)
	else
		return
	end
	GameTooltip:Show()
end

local function IconOnLeave()
	GameTooltip:Hide()
end

local function IconOnClick(self, button)
	if button ~= "RightButton" or self.fake then
		return
	end
	local bar = self.bar
	if not bar or not bar.isBuff or bar.cfg.rightClickCancel == false then
		return
	end
	if InCombatLockdown() then
		return
	end
	if self.enchantSlot then
		CancelItemTempEnchantment(self.enchantSlot == 16 and 1 or 2)
	elseif self.rec and self.rec.index then
		CancelUnitBuff("player", self.rec.index, self.rec.filter)
	end
end

local function CreateIcon(bar)
	local b = CreateFrame("Button", nil, bar.frame)
	b.bar = bar
	b:RegisterForClicks("RightButtonUp")
	b.tex = b:CreateTexture(nil, "ARTWORK")
	b.tex:SetAllPoints()
	b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
	b.cd:SetAllPoints()
	if b.cd.SetDrawEdge then b.cd:SetDrawEdge(false) end
	b.cd.noCooldownCount = true
	b.cd.noOCC = true
	b.borderHost = CreateFrame("Frame", nil, b)
	b.borderHost:SetAllPoints()
	b.border = UF.CreateBorder(b.borderHost, b)
	b.fxHost = CreateFrame("Frame", nil, b)
	b.fxHost:SetAllPoints()
	b.fxBorder = UF.CreateBorder(b.fxHost, b, true)
	b.textHost = CreateFrame("Frame", nil, b)
	b.textHost:SetAllPoints()
	b.dispel = b.textHost:CreateTexture(nil, "OVERLAY")
	b.dispel:Hide()
	b.duration = b.textHost:CreateFontString(nil, "OVERLAY")
	b.stack = b.textHost:CreateFontString(nil, "OVERLAY")
	b:SetScript("OnEnter", IconOnEnter)
	b:SetScript("OnLeave", IconOnLeave)
	b:SetScript("OnClick", IconOnClick)
	b:Hide()
	return b
end

-- Look of one icon from its bar settings (on settings changes only).
local function StyleIcon(b, bar, size)
	local cfg = bar.cfg
	local px = UF.Pixel()
	b:SetSize(size, size)
	local lvl = b:GetFrameLevel()
	b.cd:SetFrameLevel(lvl + 1)
	b.borderHost:SetFrameLevel(cfg.borderBehind and lvl or lvl + 2)
	b.fxHost:SetFrameLevel(lvl + 3)
	b.textHost:SetFrameLevel(lvl + 5)
	local z = cfg.iconZoom or 0.055
	b.tex:SetTexCoord(z, 1 - z, z, 1 - z)
	local bsize = (cfg.borderSize or 1) * px
	b.border:SetBorderSize(bsize)
	b.borderSizePx = bsize
	b.baseColor = { cfg.borderR or 0, cfg.borderG or 0, cfg.borderB or 0, cfg.borderA or 1 }
	b.cd:SetReverse(cfg.reverseSwipe ~= false)
	b.showSwipe = cfg.showSwipe ~= false
	-- Duration text
	local dside = string.upper(cfg.durationPosition or "CENTER")
	SetFont(b.duration, cfg.durationTextSize or 11, cfg.fontOutline)
	b.duration:ClearAllPoints()
	b.duration:SetPoint(OPPOSITE[dside] or "CENTER", b, dside, cfg.durationOffsetX or 0, cfg.durationOffsetY or 0)
	b.duration:SetTextColor(cfg.durationColorR or 1, cfg.durationColorG or 1, cfg.durationColorB or 1)
	b.showDuration = cfg.durationShow ~= false
	b.secondsUnit = cfg.durationShowSeconds == true
	b.precise = tonumber(cfg.durationPrecisionThreshold)
	-- Stack text
	local sside = string.upper(cfg.stackPosition or "BOTTOMRIGHT")
	SetFont(b.stack, cfg.stackTextSize or 11, cfg.fontOutline)
	b.stack:ClearAllPoints()
	b.stack:SetPoint(sside, b, sside, cfg.stackOffsetX or 0, cfg.stackOffsetY or 0)
	b.stack:SetTextColor(cfg.stackColorR or 1, cfg.stackColorG or 1, cfg.stackColorB or 1)
	b.showStack = cfg.stackShow ~= false
	-- Dispel type icon (debuffs)
	local dip = cfg.dispelIconPosition
	b.dispelPos = (not bar.isBuff and dip and dip ~= "none") and dip or nil
	if b.dispelPos then
		local pt = string.upper(b.dispelPos)
		b.dispel:ClearAllPoints()
		b.dispel:SetSize(Snap(cfg.dispelIconSize or 16), Snap(cfg.dispelIconSize or 16))
		b.dispel:SetPoint(pt, b, pt, cfg.dispelIconOffsetX or 0, cfg.dispelIconOffsetY or 0)
	end
	-- Mouse: click-through without cancel and tooltips.
	local wantMouse = cfg.showTooltips ~= false or (bar.isBuff and cfg.rightClickCancel ~= false)
	b:EnableMouse(wantMouse)
	b.styled = true
end

-- Icon Effects block for a debuff category (first active block wins).
local function FxFor(bar, cat)
	if bar.isBuff or not cat or cat == "all" or cat == "match" then
		return nil
	end
	for _, e in ipairs(bar.fx or {}) do
		if e.filters[cat] then return e end
	end
end

local function ShowGlow(b, on)
	if on then
		if not b.glowing and ActionButton_ShowOverlayGlow then
			ActionButton_ShowOverlayGlow(b)
			b.glowing = true
		end
	elseif b.glowing then
		if ActionButton_HideOverlayGlow then ActionButton_HideOverlayGlow(b) end
		b.glowing = nil
	end
end

-- Content of one icon (record from the scan, a fake record or an enchant).
local function FillIcon(b, bar, rec, cat)
	b.rec = rec
	b.fake = rec.fake
	b.enchantSlot = rec.enchantSlot
	b.spellId = rec.spellId
	b.tex:SetTexture(rec.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
	-- Swipe
	if b.showSwipe and rec.duration and rec.duration > 0 and rec.expires and rec.expires > 0 then
		b.cd:SetCooldown(rec.expires - rec.duration, rec.duration)
		b.cd:Show()
	else
		b.cd:Hide()
	end
	b.expires = (rec.expires and rec.expires > 0) and rec.expires or nil
	if not b.showDuration or not b.expires then
		b.duration:SetText("")
	end
	-- Stacks
	if b.showStack and rec.count and rec.count > 1 then
		b.stack:SetText(rec.count)
	else
		b.stack:SetText("")
	end
	-- Border: dispel color on debuffs with a type.
	local cfg = bar.cfg
	local r, g, bl, a = unpack(b.baseColor)
	if not bar.isBuff and rec.dtype then
		local dr, dg, db = DispelColor(cfg, rec.dtype)
		if dr then r, g, bl, a = dr, dg, db, 1 end
	end
	b.border:SetBorderColor(r, g, bl, a)
	-- Dispel type icon
	if b.dispelPos and rec.dtype and P.DISPEL_ICONS[rec.dtype] then
		b.dispel:SetTexture(P.DISPEL_ICONS[rec.dtype])
		b.dispel:Show()
	else
		b.dispel:Hide()
	end
	-- Icon Effects
	local fx = FxFor(bar, cat)
	if fx and (fx.borderSize or 0) > 0 then
		local c = fx.borderColor or {}
		b.fxBorder:SetBorderSize(fx.borderSize * UF.Pixel())
		b.fxBorder:SetBorderColor(c.r or 0, c.g or 0, c.b or 0, 1)
		b.fxBorder:SetShown(true)
	else
		b.fxBorder:SetShown(false)
	end
	ShowGlow(b, fx and (fx.glowType or 0) > 0)
	return fx and tonumber(fx.size) and fx.size > 0 and fx.size or nil
end

---------------------------------------------------------------------------
-- Bars
---------------------------------------------------------------------------
P.bars = {}         -- unlock key -> bar record
local previewOn

local function BarKey(isBuff, id)
	if id == "default" then
		return isBuff and "PAB_Buffs" or "PAB_Debuffs"
	end
	return (isBuff and "PAB_CustomBuff_" or "PAB_CustomDebuff_") .. id
end
P.BarKey = BarKey

local DEFAULT_POS = {
	PAB_Buffs = { point = "TOPRIGHT", relPoint = "TOPRIGHT", x = -300, y = -200 },
	PAB_Debuffs = { point = "TOPRIGHT", relPoint = "TOPRIGHT", x = -300, y = -260 },
	custom = { point = "CENTER", relPoint = "CENTER", x = 0, y = 80 },
}

local function StoredPos(bar)
	local s = S()
	if bar.id == "default" then
		return s[bar.isBuff and "buffsPos" or "debuffsPos"]
	end
	return bar.cfg.pos
end

local function SetStoredPos(bar, pos)
	local s = S()
	if bar.id == "default" then
		s[bar.isBuff and "buffsPos" or "debuffsPos"] = pos
	else
		bar.cfg.pos = pos
	end
end

-- A saved spot outside this screen (retail positions on a bigger UI) falls
-- back to the default.
local function OnScreen(pos)
	local w, h = UIParent:GetWidth(), UIParent:GetHeight()
	if not (pos and pos.x and pos.y and w and h) then
		return false
	end
	local fx, fy = FRAC_X[pos.relPoint or pos.point] or 0.5, FRAC_Y[pos.relPoint or pos.point] or 0.5
	local ax, ay = fx * w + pos.x, fy * h + pos.y
	return ax >= -20 and ax <= w + 20 and ay >= -20 and ay <= h + 20
end

local function ApplyPosition(bar)
	local f = bar.frame
	if ns._unlockActive and f:GetNumPoints() > 0 then
		return
	end
	local key = bar.key
	local anchored = ns.IsUnlockAnchored and ns.IsUnlockAnchored(key)
	if anchored and f:GetNumPoints() > 0 and ns.ReapplyOwnAnchor then
		ns.ReapplyOwnAnchor(key)
		return
	end
	local pos = StoredPos(bar)
	if not OnScreen(pos) then
		pos = DEFAULT_POS[key] or DEFAULT_POS.custom
	end
	local grid = bar.grid
	local x, y = pos.x or 0, pos.y or 0
	-- An edge-growing bar keeps its start corner when its size changes.
	local point = pos.point or "CENTER"
	if pos.w and pos.h and not (grid.dir == "CENTER_HORIZONTAL" or grid.dir == "CENTER_VERTICAL") then
		local corner = CornerFor(grid.dir, bar.cfg.iconWrapDirection or "LEFT")
		x = x + ((FRAC_X[corner] or 0.5) - (FRAC_X[point] or 0.5)) * (pos.w - grid.width)
		y = y + ((FRAC_Y[corner] or 0.5) - (FRAC_Y[point] or 0.5)) * (pos.h - grid.height)
	end
	f:ClearAllPoints()
	f:SetPoint(point, UIParent, pos.relPoint or point, Snap(x), Snap(y))
	if anchored and ns.ReapplyOwnAnchor then
		ns.ReapplyOwnAnchor(key)
	end
end
P.ApplyPosition = ApplyPosition

-- Bar visible at all (settings + spec), independent of content.
local function BarWanted(bar)
	local s = S()
	if not s or s.enabled ~= true then
		return false
	end
	if bar.id == "default" then
		return s.useBlizzardBuffs ~= true and bar.cfg.enabled ~= false
	end
	return ns.PAB_BarActive(bar.cfg, bar.bucket)
end
P.BarWanted = BarWanted

-- Enchant cells (default Buffs bar, broad modes).
local enchantRecs = { {}, {} }
local function EnchantCells(out)
	local hasMH, mhExp, mhCharges, hasOH, ohExp, ohCharges = GetWeaponEnchantInfo()
	local now = GetTime()
	-- Off hand at the corner, main hand next to the auras.
	local list = {}
	if hasOH and ohExp then list[#list + 1] = { 17, ohExp, ohCharges } end
	if hasMH and mhExp then list[#list + 1] = { 16, mhExp, mhCharges } end
	for i, e in ipairs(list) do
		local r = enchantRecs[i]
		wipe(r)
		r.enchantSlot = e[1]
		r.icon = GetInventoryItemTexture("player", e[1])
		r.count = e[3] or 0
		r.expires = now + e[2] / 1000
		r.duration = 0
		out[#out + 1] = r
		out[r] = "enchant"
	end
end

-- Sample icons while the settings page is open (retail options preview).
P.PREVIEW_BUFFS = { 1459, 21562, 19740, 20217, 1126, 6673, 109773, 116781, 469, 1706, 53563, 974, 17, 774, 33763, 6346, 31842, 1044, 2825, 79206 }
P.PREVIEW_DEBUFFS = {
	{ 118, "Magic" }, { 980, "Curse" }, { 589, "Magic" }, { 2818, "Poison" }, { 55095, "Disease" }, { 8921, nil },
	{ 122, "Magic" }, { 702, "Curse" }, { 2823, "Poison" }, { 6788, nil }, { 25771, nil }, { 113746, nil },
	{ 15407, "Magic" }, { 1490, "Curse" }, { 3409, "Poison" }, { 77606, nil },
}
P.FAKE_DUR = { 8, 15, 23, 41, 5, 30, 12, 60, 3, 18 }
P.FAKE_STACK = { nil, 3, nil, nil, 2, nil, nil, 5, nil, 1 }
local fakeRecs = {}

local function FakeRec(i, spellId, dtype)
	local r = fakeRecs[i] or {}
	fakeRecs[i] = r
	wipe(r)
	local name, _, icon = GetSpellInfo(spellId)
	r.fake, r.spellId, r.name, r.icon, r.dtype = true, spellId, name or "?", icon, dtype
	local d = P.FAKE_DUR[(i - 1) % 10 + 1] * 60
	r.duration = d * 2
	r.expires = (P.previewStart or GetTime()) + d
	r.count = P.FAKE_STACK[(i - 1) % 10 + 1] or 0
	r.index = i
	return r
end

local function PreviewContent(bar, out, limit)
	local cfg = bar.cfg
	local n = #out
	if bar.isBuff then
		local spells = {}
		if cfg.showAllBuffs == false and cfg.hasDuration ~= true then
			for _, id in ipairs(ns.PAB_ResolveSpells(cfg)) do
				if KnownSpell(id) then spells[#spells + 1] = id end
			end
			if #spells == 0 then
				return
			end
		else
			spells = P.PREVIEW_BUFFS
		end
		for i = 1, limit - n do
			local id = spells[(i - 1) % #spells + 1]
			local r = FakeRec(100 * (bar.slot or 1) + i, id)
			out[#out + 1] = r
			out[r] = "all"
		end
	else
		if not ns.PAB_DebuffBarHasContent(cfg) or ns.PAB_DebuffMatchEmpty(cfg) then
			return
		end
		for i = 1, limit - n do
			local e = P.PREVIEW_DEBUFFS[(i - 1) % #P.PREVIEW_DEBUFFS + 1]
			local r = FakeRec(100 * (bar.slot or 1) + i, e[1], e[2])
			out[#out + 1] = r
			-- Icon Effects demo on the first icons of each targeted category.
			local cat = "all"
			for _, fx in ipairs(bar.fx or {}) do
				for k in pairs(fx.filters) do
					if i <= 2 then cat = k end
				end
			end
			out[r] = cat
		end
	end
end

local content = {}

-- Fills one bar from the last scan.
local function UpdateBar(bar)
	if not bar.shown then
		return
	end
	local grid = bar.grid
	wipe(content)
	local limit = grid.effMax
	if bar.isBuff and bar.enchants then
		EnchantCells(content)
	end
	if bar.isBuff then
		BuffContent(bar.cfg, content, limit)
	else
		DebuffContent(bar.cfg, content, limit)
	end
	-- Settings preview (not while Unlock Mode is open) or Unlock Mode itself.
	if (previewOn and not ns._unlockActive) or P.unlocked then
		PreviewContent(bar, content, limit)
	end
	local count = min(#content, limit)
	for i = 1, count do
		local b = bar.icons[i]
		if not b then
			b = CreateIcon(bar)
			bar.icons[i] = b
		end
		if not b.styled then
			StyleIcon(b, bar, grid.iconSize)
		end
		local rec = content[i]
		local size = FillIcon(b, bar, rec, content[rec]) or bar.cfg.iconSize or 32
		size = Snap(size)
		if b:GetWidth() ~= size then b:SetSize(size, size) end
		local x, y = IconOffset(grid, bar.cfg, i - 1, count)
		local d = (grid.iconSize - size) / 2
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", bar.frame, "TOPLEFT", Snap(x + d), Snap(y - d))
		b:Show()
	end
	for i = count + 1, #bar.icons do
		local b = bar.icons[i]
		b:Hide()
		b.rec, b.expires = nil, nil
		ShowGlow(b, false)
	end
	bar.count = count
end

-- Duration texts (one ticker for every bar).
local ticker = CreateFrame("Frame")
local tickElapsed = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
	tickElapsed = tickElapsed + elapsed
	if tickElapsed < 0.1 then
		return
	end
	tickElapsed = 0
	local now = GetTime()
	for _, bar in pairs(P.bars) do
		if bar.shown then
			for i = 1, bar.count or 0 do
				local b = bar.icons[i]
				if b.expires and b.showDuration then
					local left = b.expires - now
					if b.fake and left <= 0 then
						P.previewStart = now
					end
					b.duration:SetText(left > 0 and DurationText(left, b.secondsUnit, b.precise) or "")
				end
			end
		end
	end
end)

-- Creates or updates a bar record (settings, size, position, shown state).
local function SetupBar(isBuff, id, cfg, bucket, slot)
	local key = BarKey(isBuff, id)
	local bar = P.bars[key]
	if not bar then
		local name = "EllesmereUIPlayerAuraBars_" .. (id == "default" and (isBuff and "Buffs" or "Debuffs")
			or ((isBuff and "CustomBuff" or "CustomDebuff") .. id))
		local f = CreateFrame("Frame", name, UIParent)
		f:SetFrameStrata("MEDIUM")
		f:SetFrameLevel(10)
		bar = { key = key, isBuff = isBuff, id = id, frame = f, icons = {} }
		P.bars[key] = bar
	end
	bar.cfg, bar.bucket, bar.slot = cfg, bucket, slot
	bar.fx = not isBuff and FxList(cfg) or nil
	bar.enchants = isBuff and ns.PAB_EnchantsOn(cfg) or false
	bar.grid = ComputeGrid(isBuff, cfg)
	bar.frame:SetSize(bar.grid.width, bar.grid.height)
	for _, b in ipairs(bar.icons) do
		b.styled = nil
	end
	bar.shown = BarWanted(bar)
	bar.frame:SetShown(bar.shown)
	if bar.shown then
		ApplyPosition(bar)
	end
	return bar
end

---------------------------------------------------------------------------
-- Blizzard buff frame (hidden while the built-in bars own the display)
---------------------------------------------------------------------------
local hooked
local function OwnsNative()
	local s = S()
	return s ~= nil and s.enabled == true and s.useBlizzardBuffs ~= true
end

local function SyncNative()
	local own = OwnsNative()
	local frames = { BuffFrame, TemporaryEnchantFrame, ConsolidatedBuffs }
	if own then
		if not hooked then
			hooked = true
			for _, f in ipairs(frames) do
				if f then
					hooksecurefunc(f, "Show", function(self)
						if OwnsNative() then self:Hide() end
					end)
				end
			end
		end
		if BuffFrame then
			BuffFrame:UnregisterEvent("UNIT_AURA")
		end
		for _, f in ipairs(frames) do
			if f then f:Hide() end
		end
		P.ownsNative = true
	elseif P.ownsNative then
		P.ownsNative = nil
		if BuffFrame then
			BuffFrame:RegisterEvent("UNIT_AURA")
			BuffFrame:Show()
			if BuffFrame_Update then BuffFrame_Update() end
		end
		if TemporaryEnchantFrame then TemporaryEnchantFrame:Show() end
		if ConsolidatedBuffs and ShouldShowConsolidatedBuffFrame and ShouldShowConsolidatedBuffFrame() then
			ConsolidatedBuffs:Show()
		end
	end
end

---------------------------------------------------------------------------
-- Build / refresh
---------------------------------------------------------------------------
local function RefreshAll()
	Scan()
	for _, bar in pairs(P.bars) do
		UpdateBar(bar)
	end
end
P.RefreshAll = RefreshAll

-- (Re)applies every bar from the settings.
function P.ReloadAll()
	local s = S()
	if not s then
		return
	end
	ns.PAB_ImportBM2Filters()
	local seen = {}
	seen[SetupBar(true, "default", ns.PAB_DefaultBuffsCfg(s), nil, 1).key] = true
	seen[SetupBar(false, "default", ns.PAB_DefaultDebuffsCfg(s), nil, 2).key] = true
	for i, e in ipairs(AllCustomBars()) do
		local bar = SetupBar(e.isBuff, e.bar.id, e.bar, e.bucket, i + 2)
		seen[bar.key] = true
	end
	for key, bar in pairs(P.bars) do
		if not seen[key] then
			bar.shown = false
			bar.frame:Hide()
			bar.deleted = true
		else
			bar.deleted = nil
		end
	end
	SyncNative()
	if P.RegisterUnlock then
		P.RegisterUnlock()
	end
	RefreshAll()
	if P.vehicleHidden then
		for _, bar in pairs(P.bars) do bar.frame:SetAlpha(0) end
	end
end

-- Settings window hooks (retail names).
function ns.PAB_Restyle() P.ReloadAll() end
function ns.PAB_ApplyLiveConfig() P.ReloadAll() end
function ns.PAB_ReloadCustomBuffBar() P.ReloadAll() end
function ns.PAB_ReloadCustomDebuffBar() P.ReloadAll() end
function ns.PAB_ReloadAllCustomBars() P.ReloadAll() end
function ns.PAB_RegisterUnlock() if P.RegisterUnlock then P.RegisterUnlock() end end

function ns.PAB_SetEnabled(v)
	local s = S()
	s.enabled = v and true or nil
	P.ReloadAll()
end

function ns.PAB_ApplyUseBlizzard()
	P.ReloadAll()
end

-- Sample icons on the bars while the settings page is open.
function ns.PAB_SetPreview(on)
	on = on and true or nil
	if previewOn == on then
		return
	end
	previewOn = on
	P.previewStart = GetTime()
	if UF.db then
		RefreshAll()
	end
end

---------------------------------------------------------------------------
-- Grow direction bridge for Unlock Mode (retail EllesmereUF:Get/SetGrowDirectionForBar)
---------------------------------------------------------------------------
local function CfgOfKey(key)
	local bar = P.bars[key]
	return bar and bar.cfg
end

function ns.PAB_GetGrowDirection(key)
	local cfg = CfgOfKey(key)
	return cfg and cfg.growDirection or "LEFT"
end

function ns.PAB_SetGrowDirection(key, dir)
	local cfg = CfgOfKey(key)
	if not cfg then
		return
	end
	if (dir == "UP" or dir == "DOWN") and cfg.iconWrapDirection ~= "LEFT" and cfg.iconWrapDirection ~= "RIGHT" then
		cfg.iconWrapDirection = "LEFT"
	elseif (dir == "LEFT" or dir == "RIGHT") and cfg.iconWrapDirection ~= "UP" and cfg.iconWrapDirection ~= "DOWN" then
		cfg.iconWrapDirection = "DOWN"
	end
	cfg.growDirection = dir
	P.ReloadAll()
end

ns._liteAddons = ns._liteAddons or {}
ns._liteAddons["EllesmereUIUnitFrames"] = {
	GetGrowDirectionForBar = function(_, key) return ns.PAB_GetGrowDirection(key) end,
	SetGrowDirectionForBar = function(_, key, dir) ns.PAB_SetGrowDirection(key, dir) end,
}

---------------------------------------------------------------------------
-- Unlock Mode (group "Player Aura Bars", one element per bar)
---------------------------------------------------------------------------
local registered = {}

local function BarLabel(bar)
	if bar.id == "default" then
		return bar.isBuff and ns.PAB_DefaultBuffsName() or "Debuffs"
	end
	return "PAB: " .. (bar.cfg.name or (bar.isBuff and "Buff Bar" or "Debuff Bar"))
end

local function MakeElement(key)
	local function Bar() return P.bars[key] end
	local first = Bar()
	return ns.MakeUnlockElement({
		key = key,
		label = BarLabel(first),
		labelFn = function()
			local bar = Bar()
			return bar and BarLabel(bar) or key
		end,
		group = "Player Aura Bars",
		order = 700 + (first.slot or 1),
		noResize = true,
		noAnchorTarget = true,
		isHidden = function()
			local bar = Bar()
			return not bar or bar.deleted or not BarWanted(bar)
		end,
		getFrame = function()
			local bar = Bar()
			return bar and not bar.deleted and bar.frame or nil
		end,
		getSize = function()
			local bar = Bar()
			if bar then
				return bar.grid.width, bar.grid.height
			end
			return 32, 32
		end,
		loadPos = function()
			local bar = Bar()
			local pos = bar and StoredPos(bar)
			if not (pos and pos.point) then
				return nil
			end
			return { point = pos.point, relPoint = pos.relPoint or pos.point, x = pos.x, y = pos.y }
		end,
		savePos = function(_, point, relPoint, x, y)
			local bar = Bar()
			if not bar then
				return
			end
			SetStoredPos(bar, { point = point, relPoint = relPoint or point, x = x, y = y,
				w = bar.grid.width, h = bar.grid.height })
			if not ns._unlockActive then
				ApplyPosition(bar)
			end
		end,
		clearPos = function()
			local bar = Bar()
			if bar then
				SetStoredPos(bar, nil)
			end
		end,
		applyPos = function()
			local bar = Bar()
			if bar and bar.shown then
				ApplyPosition(bar)
			end
		end,
	})
end

function P.RegisterUnlock()
	if not (ns.RegisterUnlockElements and ns.MakeUnlockElement) then
		return
	end
	local elements = {}
	ns._ELEMENT_SETTINGS_MAP = ns._ELEMENT_SETTINGS_MAP or {}
	for key, bar in pairs(P.bars) do
		if not bar.deleted and not registered[key] then
			registered[key] = true
			elements[#elements + 1] = MakeElement(key)
		end
		local kind, id, bucket = bar.isBuff and "buff" or "debuff", bar.id, bar.bucket
		ns._ELEMENT_SETTINGS_MAP[key] = not bar.deleted and {
			module = "EllesmereUIUnitFrames", page = "Player Aura Bars",
			preSelectFn = function()
				if ns._setPABSelection then ns._setPABSelection(kind, id, bucket) end
			end,
		} or nil
	end
	if #elements > 0 then
		ns:RegisterUnlockElements(elements, "EllesmereUIUnitFrames")
	end
end

-- Unlock Mode shows every wanted bar with its full grid of sample icons.
local function SetUnlocked(on)
	P.unlocked = on and true or nil
	if UF.db then
		RefreshAll()
	end
end
P.SetUnlocked = SetUnlocked

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
local enchantPoll = 0
local lastEnchant

events:SetScript("OnEvent", function(self, event, unit)
	if event == "PLAYER_LOGIN" then
		if not UF.db then
			return
		end
		P.loaded = true
		P.ReloadAll()
		if ns.RegisterUnlockModeListener then
			ns:RegisterUnlockModeListener("EllesmereUIUnitFrames_PAB", SetUnlocked)
		end
		self:RegisterEvent("UNIT_AURA")
		self:RegisterEvent("PLAYER_ENTERING_WORLD")
		self:RegisterEvent("UNIT_INVENTORY_CHANGED")
		self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
		self:RegisterEvent("UNIT_ENTERED_VEHICLE")
		self:RegisterEvent("UNIT_EXITED_VEHICLE")
		self:RegisterEvent("UI_SCALE_CHANGED")
		self:Show()
		return
	end
	if event == "UNIT_AURA" or event == "UNIT_INVENTORY_CHANGED" then
		if unit == "player" then
			RefreshAll()
		end
	elseif event == "PLAYER_ENTERING_WORLD" or event == "UI_SCALE_CHANGED" then
		if P.vehicleHidden and not UnitHasVehicleUI("player") then
			P.vehicleHidden = nil
		end
		P.ReloadAll()
	elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
		if not unit or unit == "player" then
			P.ReloadAll()
		end
	elseif event == "UNIT_ENTERED_VEHICLE" then
		if unit == "player" and UnitHasVehicleUI("player") then
			P.vehicleHidden = true
			for _, bar in pairs(P.bars) do bar.frame:SetAlpha(0) end
		end
	elseif event == "UNIT_EXITED_VEHICLE" then
		if unit == "player" then
			P.vehicleHidden = nil
			for _, bar in pairs(P.bars) do bar.frame:SetAlpha(1) end
			P.ReloadAll()
		end
	end
end)
-- Weapon enchants have no change event: poll once a second.
events:SetScript("OnUpdate", function(_, elapsed)
	enchantPoll = enchantPoll + elapsed
	if enchantPoll < 1 then
		return
	end
	enchantPoll = 0
	local buffs = P.bars.PAB_Buffs
	if not (buffs and buffs.shown and buffs.enchants) then
		return
	end
	local hasMH, _, _, hasOH = GetWeaponEnchantInfo()
	local state = (hasMH and 1 or 0) + (hasOH and 2 or 0)
	if state ~= lastEnchant then
		lastEnchant = state
		RefreshAll()
	end
end)
events:Hide()
events:RegisterEvent("PLAYER_LOGIN")


-- Settings window: every change re-applies the bars.
ns.applyHooks = ns.applyHooks or {}
tinsert(ns.applyHooks, function()
	if UF.db and P.loaded then
		P.ReloadAll()
	end
end)
