-------------------------------------------------------------------------------
--  EUI_RaidFrames_BuffManager.lua  (5.4.8 port of the retail Buff Manager v2,
--  EUI_RaidFrames_BuffManager2.lua + the BM renderer of
--  EUI_RaidFrames_AuraContainers.lua)
--
--  Retail model (kept 1:1, same saved keys): profile.bm2 =
--    { filters = { nextId, list = { {id, name, preset, spells = {[id]=bool},
--      custom = {[id]=true}} } }, specs = { [bucket] = { nextId, inds,
--      inhDis } }, seeded = { [bucket] = true } }
--  An indicator shows the UNION of its direct spells and the enabled spells
--  of its assigned filters (minus the hidden filters, ind.negFilters).
--  Buckets that render for the player: the healer spec key (or the shared
--  "nonhealer" bucket), the spec's own "spec<ID>" bucket (non-healers),
--  "allspecs" and the role group ("healers" / "tanks" / "dps").
--  Retail 9.x reads ONLY bm2 (the legacy bmIndicators / bmDisplayMode keys
--  are left untouched and ignored), so this port does the same.
--
--  5.4.8 differences:
--  * No aura containers: a plain HELPFUL UnitAura scan per UNIT_AURA paints
--    our own icon / square / bar / tint frames (retail draws engine slots).
--  * Spells match by spell ID and by spell NAME, so a retail ID whose MoP
--    aura has another ID (Enveloping Mist 124682 -> aura 132120) still shows.
--    Retail IDs that do not exist on 5.4.8 (GetSpellInfo = nil) are inert.
--  * The preset filters get MoP spell lists (same preset keys, so the
--    profile's filter ids and assignments keep working).
--  * Effects show while a tracked buff is present (retail 12.1 behavior; the
--    other Show When modes render as "present" there too).
--  * Frame Border: solid only (no glow / dashed engines on 5.4.8).
--  * No aura tooltips on the indicators (they would block clicks on the
--    secure unit button; 5.4.8 has no mouse-motion-only frames).
--  * Frame Alpha indicators render nothing (removed in retail 12.1 too).
-------------------------------------------------------------------------------
local addonName, RF = ...
local ns = EllesmereUI
local ERF = RF.ERF

local floor, max, min, ceil = math.floor, math.max, math.min, math.ceil
local pairs, ipairs, type, tonumber, tostring = pairs, ipairs, type, tonumber, tostring
local format = string.format
local GetTime = GetTime

-------------------------------------------------------------------------------
--  Preset filters (retail EllesmereUI_BuffPresets.lua RETAIL_PRESETS: same
--  keys, names and order, so new profiles get the same filter ids 1..11).
--  Spell lists: Mists of Pandaria spells. disabled = unchecked by default.
-------------------------------------------------------------------------------
local PRESET_FILTERS = {
	{ key = "defensives", name = "Defensives" },
	{ key = "activemitigation", name = "Active Mitigation" },
	{ key = "raidcds", name = "Raid CDs" },
	{ key = "externals", name = "Externals" },
	{ key = "coreheals", name = "Core Healing Buffs" },
	{ key = "lesserheals", name = "Lesser Healing Buffs" },
	{ key = "support", name = "Support" },
	{ key = "offensive", name = "Offensive CDs" },
	{ key = "movement", name = "Movement" },
	{ key = "utility", name = "Utility" },
	{ key = "consumables", name = "Consumables" },
}
RF.BM2_PRESET_FILTERS = PRESET_FILTERS

local DK, DR, HU, MA, MO, PA, PR, RO, SH, WL, WA =
	"DEATHKNIGHT", "DRUID", "HUNTER", "MAGE", "MONK", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR"

local DEFAULT_FILTER_SPELLS = {
	defensives = {
		[48707] = { class = DK },                -- Anti-Magic Shell
		[48792] = { class = DK },                -- Icebound Fortitude
		[55233] = { class = DK },                -- Vampiric Blood
		[49039] = { class = DK, disabled = true }, -- Lichborne
		[22812] = { class = DR },                -- Barkskin
		[22842] = { class = DR },                -- Frenzied Regeneration
		[61336] = { class = DR },                -- Survival Instincts
		[19263] = { class = HU },                -- Deterrence
		[45438] = { class = MA },                -- Ice Block
		[11426] = { class = MA, disabled = true }, -- Ice Barrier
		[110909] = { class = MA, disabled = true }, -- Alter Time
		[122783] = { class = MO },               -- Diffuse Magic
		[115203] = { class = MO, alts = { 120954 } }, -- Fortifying Brew
		[122278] = { class = MO },               -- Dampen Harm
		[125174] = { class = MO },               -- Touch of Karma
		[115176] = { class = MO },               -- Zen Meditation
		[498] = { class = PA },                  -- Divine Protection
		[642] = { class = PA },                  -- Divine Shield
		[31850] = { class = PA },                -- Ardent Defender
		[86659] = { class = PA },                -- Guardian of Ancient Kings
		[47585] = { class = PR },                -- Dispersion
		[586] = { class = PR },                  -- Fade
		[27827] = { class = PR },                -- Spirit of Redemption
		[31224] = { class = RO },                -- Cloak of Shadows
		[5277] = { class = RO },                 -- Evasion
		[1966] = { class = RO },                 -- Feint
		[108271] = { class = SH },               -- Astral Shift
		[30823] = { class = SH },                -- Shamanistic Rage
		[104773] = { class = WL },               -- Unending Resolve
		[108416] = { class = WL },               -- Sacrificial Pact
		[110913] = { class = WL },               -- Dark Bargain
		[871] = { class = WA },                  -- Shield Wall
		[12975] = { class = WA },                -- Last Stand
		[118038] = { class = WA },               -- Die by the Sword
		[55694] = { class = WA },                -- Enraged Regeneration
		[23920] = { class = WA, disabled = true }, -- Spell Reflection
	},
	activemitigation = {
		[77535] = { class = DK },                -- Blood Shield
		[132402] = { class = DR },               -- Savage Defense
		[115307] = { class = MO },               -- Shuffle
		[132403] = { class = PA },               -- Shield of the Righteous
		[132404] = { class = WA },               -- Shield Block
	},
	raidcds = {
		[145629] = { class = DK, alts = { 51052 } }, -- Anti-Magic Zone
		[740] = { class = DR, alts = { 157982 }, disabled = true }, -- Tranquility
		[31821] = { class = PA },                -- Devotion Aura
		[81782] = { class = PR, alts = { 62618 } }, -- Power Word: Barrier
		[64843] = { class = PR, alts = { 64844 }, disabled = true }, -- Divine Hymn
		[98007] = { class = SH, alts = { 98008 } }, -- Spirit Link Totem
		[97463] = { class = WA, alts = { 97462 } }, -- Rallying Cry
		[114192] = { class = WA, disabled = true }, -- Mocking Banner
	},
	externals = {
		[102342] = { class = DR },               -- Ironbark
		[53480] = { class = HU },                -- Roar of Sacrifice
		[116849] = { class = MO },               -- Life Cocoon
		[1022] = { class = PA },                 -- Hand of Protection
		[6940] = { class = PA },                 -- Hand of Sacrifice
		[1038] = { class = PA, disabled = true }, -- Hand of Salvation
		[47788] = { class = PR },                -- Guardian Spirit
		[33206] = { class = PR },                -- Pain Suppression
		[114030] = { class = WA },               -- Vigilance
		[3411] = { class = WA, disabled = true }, -- Intervene
	},
	coreheals = {
		[33763] = { class = DR },                -- Lifebloom
		[774] = { class = DR, disabled = true }, -- Rejuvenation
		[8936] = { class = DR, disabled = true }, -- Regrowth
		[48438] = { class = DR, disabled = true }, -- Wild Growth
		[119611] = { class = MO },               -- Renewing Mist
		[124682] = { class = MO, alts = { 132120 }, disabled = true }, -- Enveloping Mist
		[115175] = { class = MO, disabled = true }, -- Soothing Mist
		[53563] = { class = PA },                -- Beacon of Light
		[114163] = { class = PA },               -- Eternal Flame
		[20925] = { class = PA, alts = { 65148 } }, -- Sacred Shield
		[17] = { class = PR, disabled = true },  -- Power Word: Shield
		[139] = { class = PR, disabled = true }, -- Renew
		[41635] = { class = PR, disabled = true }, -- Prayer of Mending
		[6788] = { class = PR, disabled = true }, -- Weakened Soul
		[974] = { class = SH },                  -- Earth Shield
		[61295] = { class = SH, disabled = true }, -- Riptide
	},
	lesserheals = {
		[33763] = { class = DR, disabled = true }, -- Lifebloom
		[774] = { class = DR },                  -- Rejuvenation
		[8936] = { class = DR },                 -- Regrowth
		[48438] = { class = DR },                -- Wild Growth
		[119611] = { class = MO, disabled = true }, -- Renewing Mist
		[124682] = { class = MO, alts = { 132120 } }, -- Enveloping Mist
		[115175] = { class = MO },               -- Soothing Mist
		[53563] = { class = PA, disabled = true }, -- Beacon of Light
		[114163] = { class = PA, disabled = true }, -- Eternal Flame
		[20925] = { class = PA, alts = { 65148 }, disabled = true }, -- Sacred Shield
		[17] = { class = PR },                   -- Power Word: Shield
		[139] = { class = PR },                  -- Renew
		[41635] = { class = PR },                -- Prayer of Mending
		[974] = { class = SH, disabled = true }, -- Earth Shield
		[61295] = { class = SH },                -- Riptide
	},
	support = {},
	offensive = {
		[51271] = { class = DK },                -- Pillar of Frost
		[49016] = { class = DK },                -- Unholy Frenzy
		[106951] = { class = DR },               -- Berserk
		[102560] = { class = DR },               -- Incarnation: Chosen of Elune
		[112071] = { class = DR },               -- Celestial Alignment
		[19574] = { class = HU },                -- Bestial Wrath
		[3045] = { class = HU },                 -- Rapid Fire
		[12472] = { class = MA },                -- Icy Veins
		[12042] = { class = MA },                -- Arcane Power
		[31884] = { class = PA },                -- Avenging Wrath
		[10060] = { class = PR },                -- Power Infusion
		[13750] = { class = RO },                -- Adrenaline Rush
		[121471] = { class = RO },               -- Shadow Blades
		[114050] = { class = SH, alts = { 114051, 114052 } }, -- Ascendance
		[113858] = { class = WL, alts = { 113860, 113861 } }, -- Dark Soul
		[1719] = { class = WA },                 -- Recklessness
		[107574] = { class = WA },               -- Avatar
	},
	movement = {
		[96268] = { class = DK },                -- Death's Advance
		[1850] = { class = DR },                 -- Dash
		[77761] = { class = DR, alts = { 77764 } }, -- Stampeding Roar
		[5215] = { class = DR },                 -- Prowl
		[118922] = { class = HU },               -- Posthaste
		[5384] = { class = HU },                 -- Feign Death
		[130] = { class = MA },                  -- Slow Fall
		[108843] = { class = MA },               -- Blazing Speed
		[116841] = { class = MO },               -- Tiger's Lust
		[1044] = { class = PA },                 -- Hand of Freedom
		[85499] = { class = PA },                -- Speed of Light
		[121557] = { class = PR },               -- Angelic Feather
		[65081] = { class = PR },                -- Body and Soul
		[2983] = { class = RO },                 -- Sprint
		[1784] = { class = RO },                 -- Stealth
		[36554] = { class = RO },                -- Shadowstep
		[58875] = { class = SH },                -- Spirit Walk
		[2645] = { class = SH },                 -- Ghost Wolf
		[79206] = { class = SH },                -- Spiritwalker's Grace
		[111400] = { class = WL },               -- Burning Rush
	},
	utility = {
		[3714] = { class = DK },                 -- Path of Frost
		[29166] = { class = DR },                -- Innervate
		[80353] = { class = MA, disabled = true }, -- Time Warp
		[116841] = { class = MO },               -- Tiger's Lust
		[1044] = { class = PA },                 -- Hand of Freedom
		[2825] = { class = SH, disabled = true }, -- Bloodlust
		[32182] = { class = SH, disabled = true }, -- Heroism
		[16191] = { class = SH, disabled = true }, -- Mana Tide Totem
		[64901] = { class = PR, disabled = true }, -- Hymn of Hope
	},
	consumables = {
		[105702] = { class = "ALL" },            -- Potion of the Jade Serpent
		[105697] = { class = "ALL" },            -- Virmen's Bite
		[105706] = { class = "ALL" },            -- Potion of Mogu Power
	},
}
RF.BM2_DEFAULT_FILTER_SPELLS = DEFAULT_FILTER_SPELLS

-- Primary -> alternates (same buff under another aura id), class per spell.
local PRESET_ALTS, SPELL_CLASS = {}, {}
for _, spells in pairs(DEFAULT_FILTER_SPELLS) do
	for id, info in pairs(spells) do
		if info.alts then
			PRESET_ALTS[id] = info.alts
		end
		SPELL_CLASS[id] = info.class
		for i = 1, #(info.alts or {}) do
			SPELL_CLASS[info.alts[i]] = info.class
		end
	end
end
RF.BM2_PresetAlts = PRESET_ALTS
RF.BM2_SpellClass = SPELL_CLASS

-- Sorted array of every curated spell id (Search Spells universe).
function RF.BM2_AllPresetSpells()
	local set, out = {}, {}
	for _, spells in pairs(DEFAULT_FILTER_SPELLS) do
		for id in pairs(spells) do
			set[id] = true
		end
	end
	for id in pairs(set) do
		out[#out + 1] = id
	end
	table.sort(out)
	return out
end

-------------------------------------------------------------------------------
--  Healer specs (retail HEALER_SPECS without the Evokers; 5.4.8 has the same
--  spec IDs). Every other spec renders the shared "nonhealer" bucket.
-------------------------------------------------------------------------------
local HEALER_SPECS = {
	{ key = "DRUID_RESTORATION", specID = 105, name = "Restoration Druid", classToken = "DRUID" },
	{ key = "MONK_MISTWEAVER", specID = 270, name = "Mistweaver Monk", classToken = "MONK" },
	{ key = "PALADIN_HOLY", specID = 65, name = "Holy Paladin", classToken = "PALADIN" },
	{ key = "PRIEST_DISCIPLINE", specID = 256, name = "Discipline Priest", classToken = "PRIEST" },
	{ key = "PRIEST_HOLY", specID = 257, name = "Holy Priest", classToken = "PRIEST" },
	{ key = "SHAMAN_RESTORATION", specID = 264, name = "Restoration Shaman", classToken = "SHAMAN" },
}
RF.BM_HEALER_SPECS = HEALER_SPECS
local SPEC_BY_ID, SPEC_BY_KEY = {}, {}
for _, s in ipairs(HEALER_SPECS) do
	SPEC_BY_ID[s.specID] = s
	SPEC_BY_KEY[s.key] = s
end
RF.BM_SPEC_BY_KEY = SPEC_BY_KEY

-- Retail group buckets (labels of EllesmereUI.SPEC_GROUP_BUCKET_INFO).
RF.BM_GROUP_BUCKETS = {
	{ key = "allspecs", name = "All Specs" },
	{ key = "nonhealer", name = "All Non Healers" },
	{ key = "healers", name = "All Healers" },
	{ key = "tanks", name = "All Tanks" },
	{ key = "dps", name = "All DPS" },
}

function RF.BM_SpecKeyForSpecID(specID)
	local s = specID and SPEC_BY_ID[specID]
	return s and s.key or nil
end

-- Role of a spec ID. 5.4.8 GetSpecializationInfoByID returns
-- id, name, description, icon, background, role (role is the 6th value).
local function SpecRole(specID)
	if not (specID and GetSpecializationInfoByID) then
		return nil
	end
	local _, _, _, _, e5, e6 = GetSpecializationInfoByID(specID)
	for _, v in ipairs({ e6 or false, e5 or false }) do
		if v == "TANK" or v == "HEALER" or v == "DAMAGER" then
			return v
		end
	end
	return nil
end

function RF.BM_RoleBucketForSpecID(specID)
	if not specID then
		return nil
	end
	if SPEC_BY_ID[specID] then
		return "healers"
	end
	local role = SpecRole(specID)
	if role == "TANK" then
		return "tanks"
	elseif role then
		return "dps"
	end
	return nil
end

local function PlayerSpecID()
	local idx = GetSpecialization and GetSpecialization()
	if not idx then
		return nil
	end
	return (GetSpecializationInfo(idx))
end

-- Active config key: the healer spec key, else the shared "nonhealer" bucket.
function RF.BM2_SpecKey()
	return RF.BM_SpecKeyForSpecID(PlayerSpecID()) or "nonhealer"
end

-------------------------------------------------------------------------------
--  Storage (profile.bm2)
-------------------------------------------------------------------------------
local function P()
	return RF.Profile and RF.Profile()
end

local gen = 1
function RF.BM2_Invalidate()
	gen = gen + 1
end

local function Copy(v)
	return RF.DeepCopy(v)
end

-- One-shot legacy import (retail ImportLegacyProfile): only while the
-- profile has no bm2 store. Legacy indicators carry over as direct-spell
-- indicators; Frame Alpha is dropped like retail.
local function ImportLegacy(p, b)
	if type(p.bmIndicators) ~= "table" or p.bmDisplayMode == "simple" then
		return
	end
	for specKey, list in pairs(p.bmIndicators) do
		if type(list) == "table" and #list > 0 then
			local inds, maxId = {}, 0
			for i = 1, #list do
				local ind = list[i]
				if type(ind) == "table" and (ind.type or "icon") ~= "framealpha" then
					local v = Copy(ind)
					v.filters = {}
					v.ownOnly = ind.ownOnly ~= false
					v.ownOnlySpells = nil
					v.sizeOffsets = nil
					inds[#inds + 1] = v
					local id = tonumber(v.id) or 0
					if id > maxId then
						maxId = id
					end
				end
			end
			b.specs[specKey] = { nextId = max(1000001, maxId + 1), inds = inds }
			b.seeded[specKey] = true
		end
	end
end

local function Store()
	local p = P()
	if not p then
		return nil
	end
	local b = p.bm2
	if type(b) ~= "table" then
		b = { filters = { nextId = 1, list = {} }, specs = {}, seeded = {} }
		p.bm2 = b
		ImportLegacy(p, b)
	end
	b.filters = b.filters or { nextId = 1, list = {} }
	b.filters.list = b.filters.list or {}
	b.filters.nextId = b.filters.nextId or (#b.filters.list + 1)
	b.specs = b.specs or {}
	b.seeded = b.seeded or {}
	return b
end
RF.BM2_Store = Store

local function FindPreset(b, key)
	for i = 1, #b.filters.list do
		if b.filters.list[i].preset == key then
			return b.filters.list[i]
		end
	end
end

-- Seeds missing preset filters and merges NEW curated (MoP) ids: an id the
-- filter has already seen keeps the user's checkbox state. Retail-only ids
-- already in the profile stay (inert here: no such spell on 5.4.8).
local ensuredGen
local function EnsureFilters()
	local b = Store()
	if not b then
		return nil
	end
	if ensuredGen == b then
		return b
	end
	for i = 1, #PRESET_FILTERS do
		local def = PRESET_FILTERS[i]
		local f = FindPreset(b, def.key)
		if not f then
			f = { id = b.filters.nextId, name = def.name, preset = def.key, spells = {}, custom = {} }
			b.filters.nextId = b.filters.nextId + 1
			b.filters.list[#b.filters.list + 1] = f
		end
		f.spells = f.spells or {}
		f.custom = f.custom or {}
		local curated = DEFAULT_FILTER_SPELLS[def.key]
		if curated then
			for id, info in pairs(curated) do
				if f.spells[id] == nil and not f.custom[id] then
					f.spells[id] = not info.disabled
				end
			end
		end
	end
	ensuredGen = b
	return b
end

function RF.BM2_Filters()
	local b = EnsureFilters()
	return b and b.filters.list or {}
end

function RF.BM2_GetFilter(id)
	local b = EnsureFilters()
	if not b then
		return nil
	end
	for i = 1, #b.filters.list do
		local f = b.filters.list[i]
		if f.id == id then
			return f
		end
	end
end

function RF.BM2_AddFilter(name)
	local b = EnsureFilters()
	if not b then
		return nil
	end
	local f = { id = b.filters.nextId, name = name or "New Filter", spells = {}, custom = {} }
	b.filters.nextId = b.filters.nextId + 1
	b.filters.list[#b.filters.list + 1] = f
	RF.BM2_Invalidate()
	return f
end

function RF.BM2_RenameFilter(id, name)
	local f = RF.BM2_GetFilter(id)
	if f and not f.preset and name and name ~= "" then
		f.name = name
	end
end

-- Presets cannot be deleted; deleting a custom filter strips its
-- assignments from every indicator of every bucket.
function RF.BM2_DeleteFilter(id)
	local b = EnsureFilters()
	if not b then
		return
	end
	for i = #b.filters.list, 1, -1 do
		local f = b.filters.list[i]
		if f.id == id and not f.preset then
			table.remove(b.filters.list, i)
		end
	end
	for _, spec in pairs(b.specs) do
		for j = 1, #(spec.inds or {}) do
			local ind = spec.inds[j]
			if ind.filters then
				ind.filters[id] = nil
			end
			if ind.negFilters then
				ind.negFilters[id] = nil
			end
		end
	end
	RF.BM2_Invalidate()
end

-- Checkbox state: true/false; nil on a CUSTOM spell removes it.
function RF.BM2_SetSpellState(filterId, spellID, state)
	local f = RF.BM2_GetFilter(filterId)
	if not f then
		return
	end
	if state == nil and f.custom[spellID] then
		f.custom[spellID] = nil
		f.spells[spellID] = nil
	else
		f.spells[spellID] = state and true or false
	end
	RF.BM2_Invalidate()
end

function RF.BM2_AddCustomSpell(filterId, spellID)
	local f = RF.BM2_GetFilter(filterId)
	if not (f and spellID and spellID > 0) then
		return false
	end
	if f.spells[spellID] ~= nil then
		return false
	end
	f.custom[spellID] = true
	f.spells[spellID] = true
	RF.BM2_Invalidate()
	return true
end

-------------------------------------------------------------------------------
--  Spec indicators (retail SeedSpec / BM2_SpecInds / BM2_AddIndicator)
-------------------------------------------------------------------------------
local function PresetIdsByKey(b)
	local map = {}
	for i = 1, #b.filters.list do
		local f = b.filters.list[i]
		if f.preset then
			map[f.preset] = f.id
		end
	end
	return map
end

-- Starter groups: "Defensives & Utility" center (every seeded bucket),
-- "Core Healing Buffs" top left and "Lesser Healing Buffs" top right (healer
-- keys). Additive group buckets start empty.
local function SeedSpec(b, specKey)
	if b.seeded[specKey] then
		if not b.specs[specKey] then
			b.specs[specKey] = { nextId = 1000001, inds = {} }
		end
		return
	end
	b.seeded[specKey] = true
	local spec = b.specs[specKey]
	if not spec then
		spec = { nextId = 1000001, inds = {} }
		b.specs[specKey] = spec
	end
	if specKey == "allspecs" or specKey == "tanks" or specKey == "dps" or specKey == "healers"
		or specKey:match("^spec%d") then
		return
	end
	local pf = PresetIdsByKey(b)
	local g1 = {
		id = spec.nextId, enabled = true, type = "icon", name = "Defensives & Utility",
		ownOnly = false, filters = {}, spells = {},
		position = "CENTER", growDirection = "CENTER", size = 18,
	}
	for _, k in ipairs({ "defensives", "raidcds", "utility", "externals" }) do
		if pf[k] then
			g1.filters[pf[k]] = true
		end
	end
	spec.nextId = spec.nextId + 1
	spec.inds[#spec.inds + 1] = g1
	if specKey ~= "nonhealer" then
		local g2 = { id = spec.nextId, enabled = true, type = "icon", name = "Core Healing Buffs", ownOnly = true,
			filters = {}, spells = {}, position = "TOPLEFT", growDirection = "RIGHT", size = 18 }
		if pf.coreheals then
			g2.filters[pf.coreheals] = true
		end
		spec.nextId = spec.nextId + 1
		spec.inds[#spec.inds + 1] = g2
		local g3 = { id = spec.nextId, enabled = true, type = "icon", name = "Lesser Healing Buffs", ownOnly = true,
			filters = {}, spells = {}, position = "TOPRIGHT", growDirection = "LEFT", size = 18 }
		if pf.lesserheals then
			g3.filters[pf.lesserheals] = true
		end
		spec.nextId = spec.nextId + 1
		spec.inds[#spec.inds + 1] = g3
	end
end

-- key = a bucket key; nil = the player's active key. Returns inds, key.
function RF.BM2_SpecInds(key)
	local b = EnsureFilters()
	if not b then
		return nil, nil
	end
	local specKey = key or RF.BM2_SpecKey()
	SeedSpec(b, specKey)
	local spec = b.specs[specKey]
	spec.inds = spec.inds or {}
	spec.nextId = spec.nextId or 1000001
	for i = 1, #spec.inds do
		local ind = spec.inds[i]
		-- Retail token heal: uppercase position / growth tokens.
		if type(ind.position) == "string" then
			ind.position = ind.position:upper()
		end
		if type(ind.growDirection) == "string" then
			ind.growDirection = ind.growDirection:upper()
		end
		ind.sizeOffsets = nil
		if ind.ownOnly == nil then
			ind.ownOnly = false
		end
		if ind.name == "Defensive & Support CDs" then
			ind.name = "Defensives & Utility"
		end
	end
	return spec.inds, specKey
end

function RF.BM2_AddIndicator(indType, key)
	local b = EnsureFilters()
	if not b then
		return nil
	end
	local specKey = key or RF.BM2_SpecKey()
	SeedSpec(b, specKey)
	local spec = b.specs[specKey]
	local ind = { id = spec.nextId, enabled = true, type = indType or "icon", name = "New Indicator",
		filters = {}, spells = {}, ownOnly = false, position = "TOPLEFT", growDirection = "RIGHT", size = 18 }
	if indType == "bar" then
		ind.barWidth, ind.barHeight, ind.position = 30, 4, "BOTTOM"
		ind.color = { r = 0x0C / 255, g = 0xD2 / 255, b = 0x9D / 255 }
	elseif indType == "square" then
		ind.size = 8
		ind.color = { r = 0x0C / 255, g = 0xD2 / 255, b = 0x9D / 255 }
	elseif indType == "healthcolor" or indType == "bgcolor" then
		ind.color = { r = 0, g = 1, b = 0 }
		ind.opacity, ind.showWhen = 100, "present"
	elseif indType == "border" then
		local r, g, bl = RF.Accent()
		ind.color = { r = r, g = g, b = bl }
		ind.borderStyle, ind.borderWidth, ind.borderOpacity, ind.showWhen = "solid", 2, 100, "present"
	end
	spec.nextId = spec.nextId + 1
	spec.inds[#spec.inds + 1] = ind
	RF.BM2_Invalidate()
	return ind
end

function RF.BM2_DeleteIndicator(ind, key)
	local inds = RF.BM2_SpecInds(key)
	if not inds then
		return
	end
	for i = #inds, 1, -1 do
		if inds[i] == ind then
			table.remove(inds, i)
		elseif inds[i].anchorTo == ind.id then
			inds[i].anchorTo = nil
		end
	end
	local b = Store()
	for _, spec in pairs(b and b.specs or {}) do
		if spec.inhDis then
			spec.inhDis[tostring(key) .. ":" .. tostring(ind.id)] = nil
		end
	end
	RF.BM2_Invalidate()
end

-- Copy an indicator into another bucket (retail right-click "Add To").
function RF.BM2_CopyIndicator(src, targetKey)
	local b = EnsureFilters()
	if not (b and src and targetKey) then
		return nil
	end
	SeedSpec(b, targetKey)
	local spec = b.specs[targetKey]
	local v = Copy(src)
	v.id = spec.nextId
	spec.nextId = spec.nextId + 1
	v.anchorTo = nil
	spec.inds[#spec.inds + 1] = v
	RF.BM2_Invalidate()
	return v
end

-- Per-spec disables of group-bucket indicators (inhDis on the concrete bucket).
function RF.BM2_InhDisabled(concreteKey, groupKey, id)
	local b = Store()
	local spec = b and concreteKey and b.specs[concreteKey]
	local dis = spec and spec.inhDis
	return (dis and dis[groupKey .. ":" .. id]) and true or false
end

function RF.BM2_SetInhDisabled(concreteKey, groupKey, id, disabled)
	local b = EnsureFilters()
	if not (b and concreteKey and groupKey and id) then
		return
	end
	SeedSpec(b, concreteKey)
	local spec = b.specs[concreteKey]
	spec.inhDis = spec.inhDis or {}
	spec.inhDis[groupKey .. ":" .. id] = disabled and true or nil
	RF.BM2_Invalidate()
end

-------------------------------------------------------------------------------
--  Resolution: indicator -> spell union (retail BM2_ResolveSpellsOwn)
-------------------------------------------------------------------------------
function RF.BM2_ResolveSpells(ind)
	local set = {}
	for i = 1, #(ind.spells or {}) do
		set[ind.spells[i]] = true
	end
	if ind.filters then
		for fid, on in pairs(ind.filters) do
			local f = on and RF.BM2_GetFilter(fid)
			if f then
				for id, enabled in pairs(f.spells) do
					if enabled then
						set[id] = true
					end
				end
			end
		end
	end
	if ind.negFilters then
		local direct = {}
		for i = 1, #(ind.spells or {}) do
			direct[ind.spells[i]] = true
		end
		for fid in pairs(ind.negFilters) do
			local f = RF.BM2_GetFilter(fid)
			if f then
				for id, enabled in pairs(f.spells) do
					if enabled and not direct[id] then
						set[id] = nil
					end
				end
			end
		end
	end
	local out = {}
	for id in pairs(set) do
		out[#out + 1] = id
	end
	table.sort(out)
	return out
end

-- Show In as rendered: an Anchor To member follows its root's value.
local function EffectiveShowIn(ind, list)
	local src = ind
	for _ = 1, #list do
		local tid = src.anchorTo
		if tid == nil then
			break
		end
		local nxt
		for j = 1, #list do
			if list[j].id == tid then
				nxt = list[j]
				break
			end
		end
		if not nxt or nxt == ind then
			break
		end
		src = nxt
	end
	return src.showIn
end

-- Matcher of one indicator: ids (with alternates) and names of the spells
-- that exist on this client. nil = nothing on 5.4.8 to match.
local function BuildMatcher(spells)
	local ids, names, any, known = {}, {}, false, {}
	for i = 1, #spells do
		local id = spells[i]
		local name = GetSpellInfo(id)
		if name then
			any = true
			ids[id] = true
			names[name] = true
			known[#known + 1] = id
		end
		local alts = PRESET_ALTS[id]
		for k = 1, #(alts or {}) do
			local an = GetSpellInfo(alts[k])
			if an then
				any = true
				ids[alts[k]] = true
				names[an] = true
			end
		end
	end
	if not any then
		return nil
	end
	return { ids = ids, names = names, known = known }
end

-- Indicator views for a frame kind ("raid" / "party"); bucketKey = render
-- one bucket only (the settings preview of the edited spec). Views are
-- cached per generation; ApplyAll bumps the generation.
local viewCache = {}
local function SpecIndicators(frameKind, bucketKey)
	local ck = tostring(frameKind) .. "|" .. tostring(bucketKey)
	local c = viewCache[ck]
	if c and c.gen == gen then
		return c.list
	end
	local out = {}
	local function Append(list, idOffset, groupKey, inhDis)
		if not list then
			return
		end
		for i = 1, #list do
			local ind = list[i]
			local drop = groupKey and inhDis and inhDis[groupKey .. ":" .. tostring(ind.id)]
			if not drop and frameKind then
				local showIn = EffectiveShowIn(ind, list)
				if showIn == "raid" then
					drop = frameKind == "party"
				elseif showIn == "party" then
					drop = frameKind ~= "party"
				end
			end
			if not drop and ind.enabled and ind.type ~= "framealpha" then
				local spells = RF.BM2_ResolveSpells(ind)
				local m = #spells > 0 and BuildMatcher(spells)
				if m then
					out[#out + 1] = {
						ind = ind, spells = spells, m = m,
						id = (tonumber(ind.id) or i) + (idOffset or 0),
						anchorTo = type(ind.anchorTo) == "number" and (ind.anchorTo + (idOffset or 0)) or nil,
					}
				end
			end
		end
	end
	if bucketKey then
		Append((RF.BM2_SpecInds(bucketKey)), nil, nil, nil)
	else
		local inds, specKey = RF.BM2_SpecInds()
		local specID = PlayerSpecID()
		local tracked = RF.BM_SpecKeyForSpecID(specID)
		local concreteKey = tracked and specKey or (specID and ("spec" .. specID)) or nil
		local b = Store()
		local cSpec = b and concreteKey and b.specs[concreteKey]
		local inhDis = cSpec and cSpec.inhDis or nil
		Append(inds, nil, (not tracked) and "nonhealer" or nil, inhDis)
		if specID and not tracked then
			Append((RF.BM2_SpecInds("spec" .. specID)), 1000000, nil, nil)
		end
		Append((RF.BM2_SpecInds("allspecs")), 2000000, "allspecs", inhDis)
		local roleKey = RF.BM_RoleBucketForSpecID(specID)
		if roleKey then
			Append((RF.BM2_SpecInds(roleKey)), 3000000, roleKey, inhDis)
		end
	end
	viewCache[ck] = { gen = gen, list = out }
	return out
end
RF.BM2_SpecIndicators = SpecIndicators

-------------------------------------------------------------------------------
--  Rendering helpers
-------------------------------------------------------------------------------
-- Retail BM_FRAMELVL (offsets above the unit button level).
local FRAMELVL = { behindBorders = 7, behindText = 11, medium = RF.LVL_AURA or 13, high = 14, highest = 15 }
local FRAMELVL_TEXT = 18

local function Col(c, dr, dg, db)
	if type(c) ~= "table" then
		return dr, dg, db
	end
	return c.r or c[1] or dr, c.g or c[2] or dg, c.b or c[3] or db
end

local function Lvl(base, off)
	return min(127, base + off)
end

-- The bar indicators and icons hug the health bar (retail `health`).
local function HealthOf(btn)
	local rf = btn.rf
	return (rf and (rf.health or rf.healthBar or rf.hp)) or btn
end

-- Anchor host of placed indicators (retail RF_AnchorHost): the Uniform Icon
-- Anchoring reference when that option is on, else the health bar.
local function AnchorOf(btn)
	local rf = btn.rf
	local s = RF.SettingsFor and RF.SettingsFor(btn)
	if rf and rf.uniformRef and s and s.powerUniformAnchors then
		return rf.uniformRef
	end
	return HealthOf(btn)
end

local function IconZoom()
	local p = P()
	local z = p and p.bmIconZoom
	if type(z) ~= "number" then
		z = 0.08
	end
	return z
end

-- Duration text (EllesmereUI AuraKit look: 1h, 5m, 12, 3).
local function DurText(left)
	if left >= 3600 then
		return format("%dh", ceil(left / 3600))
	elseif left >= 60 then
		return format("%dm", ceil(left / 60))
	end
	return format("%d", ceil(left))
end

-------------------------------------------------------------------------------
--  Timer: one shared OnUpdate drives duration texts and bar fills.
-------------------------------------------------------------------------------
local timed = {}
local ticker = CreateFrame("Frame")
ticker:Hide()
local acc = 0
local function TickElement(e, now)
	if e.kind == "bar" then
		local dur, exp = e.dur or 0, e.exp or 0
		if dur > 0 and exp > 0 then
			local left = max(0, exp - now)
			e.frame:SetValue(left)
		end
	else
		local fs = e.durText
		if fs and e.showDurText and (e.exp or 0) > 0 then
			local left = e.exp - now
			if left > 0 then
				fs:SetText(DurText(left))
				local ind = e.ind
				if ind and ind.thresholdEnabled and left <= (ind.threshold or 3) then
					fs:SetTextColor(Col(ind.thresholdColor, 1, 0.25, 0.25))
				else
					fs:SetTextColor(Col(ind and ind.durationTextColor, 1, 1, 1))
				end
			else
				fs:SetText("")
			end
		end
	end
end
ticker:SetScript("OnUpdate", function(self, elapsed)
	acc = acc + (elapsed or 0)
	if acc < 0.1 then
		return
	end
	acc = 0
	local now = GetTime()
	local any = false
	for e in pairs(timed) do
		any = true
		TickElement(e, now)
	end
	if not any then
		self:Hide()
	end
end)
local function SetTimed(e, on)
	if on then
		timed[e] = true
		ticker:Show()
		TickElement(e, GetTime())
	else
		timed[e] = nil
	end
end

-------------------------------------------------------------------------------
--  Element factories (one set per button, reused)
-------------------------------------------------------------------------------
local function NewIcon(btn)
	local f = CreateFrame("Frame", nil, btn)
	f:EnableMouse(false)
	f:Hide()
	local e = { kind = "icon", frame = f }
	e.tex = f:CreateTexture(nil, "ARTWORK")
	e.tex:SetAllPoints(f)
	-- Square indicators draw a flat color instead of the spell icon.
	e.sq = f:CreateTexture(nil, "ARTWORK", nil, 1)
	e.sq:SetAllPoints(f)
	e.sq:SetTexture(RF.WHITE)
	e.sq:Hide()
	local cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
	cd:SetAllPoints(f)
	cd:SetReverse(true)
	cd.noCooldownCount = true -- OmniCC & co: we draw our own duration text
	cd.noOCC = true
	e.cd = cd
	e.bdrFrame = CreateFrame("Frame", nil, f)
	e.bdrFrame:SetAllPoints(f)
	e.edges = RF.CreateEdges(e.bdrFrame, f, "OVERLAY", 7)
	e.carrier = CreateFrame("Frame", nil, f)
	e.carrier:SetAllPoints(f)
	e.stack = RF.NewText(e.carrier, 8, "OVERLAY")
	e.durText = RF.NewText(e.carrier, 8, "OVERLAY")
	return e
end

local function NewBar(btn)
	local bar = CreateFrame("StatusBar", nil, btn)
	bar:EnableMouse(false)
	bar:SetStatusBarTexture(RF.WHITE)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(1)
	bar:Hide()
	local e = { kind = "bar", frame = bar }
	e.bg = bar:CreateTexture(nil, "BACKGROUND")
	e.bg:SetAllPoints(bar)
	e.bg:SetTexture(RF.WHITE)
	return e
end

-- Effects: healthcolor (tint over the current-health fill), bgcolor (health
-- background), border (solid frame border).
local function NewEffect(btn, kind)
	local e = { kind = kind }
	local health = HealthOf(btn)
	if kind == "healthcolor" then
		-- On the health bar itself, ARTWORK 2 = over its fill (sublevel 0),
		-- below the absorb / prediction frames that sit above the bar
		-- (retail: level-tied with health, sublevel 2).
		e.tex = health:CreateTexture(nil, "ARTWORK", nil, 2)
		e.frame = e.tex
		e.health = health
	elseif kind == "bgcolor" then
		-- On the unit button, BACKGROUND 7: above the button background,
		-- below the health bar (a child frame) -- reads as the bar background.
		e.tex = btn:CreateTexture(nil, "BACKGROUND", nil, 7)
		e.tex:SetAllPoints(health)
		e.tex:SetTexture(RF.WHITE)
		e.frame = e.tex
	else
		e.frame = RF.CreateBorder(btn, 11)
		e.frame:EnableMouse(false)
	end
	e.frame:Hide()
	return e
end

-------------------------------------------------------------------------------
--  Per-button state: btn.rfBM = { views, els = { [viewIndex] = {...} } }
-------------------------------------------------------------------------------
local function FrameKind(btn)
	local k = btn.rfKind
	if k == "party" or k == "partyPet" or k == "partyTarget" then
		return "party"
	end
	return "raid"
end

local function Kind(ind)
	local t = ind.type or "icon"
	if t == "icon" or t == "square" or t == "bar" or t == "healthcolor" or t == "bgcolor" or t == "border" then
		return t
	end
	return nil
end

local function HideState(st)
	for _, set in pairs(st.els) do
		for _, e in ipairs(set) do
			e.frame:Hide()
			SetTimed(e, false)
		end
	end
end

-- Count of icon slots of an indicator (retail: one per resolved spell; a
-- cap keeps big filter unions sane).
local function SlotCount(v)
	local n = v.ind.maxIcons or #v.m.known
	return max(1, min(n, 10))
end

-- Style an icon/square element for its indicator.
local function StyleIcon(btn, e, v, iscale, base)
	local ind = v.ind
	local square = ind.type == "square"
	local size = floor((ind.size or 18) * iscale + 0.5)
	if size < 1 then
		size = 1
	end
	local f = e.frame
	f:SetSize(size, size)
	f:SetFrameLevel(Lvl(base, FRAMELVL[ind.frameLevel or "medium"] or 13))
	e.cd:SetFrameLevel(Lvl(base, (FRAMELVL[ind.frameLevel or "medium"] or 13) + 1))
	e.bdrFrame:SetFrameLevel(Lvl(base, (FRAMELVL[ind.frameLevel or "medium"] or 13) + 1))
	e.carrier:SetFrameLevel(Lvl(base, FRAMELVL_TEXT))
	e.square = square
	e.ind = ind
	if square then
		e.tex:Hide()
		e.sq:Show()
	else
		e.sq:Hide()
		local hide = ind.hideIcon == true
		e.tex:SetShown(not hide)
		local z = IconZoom()
		e.tex:SetTexCoord(z, 1 - z, z, 1 - z)
	end
	f:SetAlpha(square and 1 or ((ind.iconOpacity or 100) / 100))
	local bsz = ind.indBorderSize or 1
	if (not square and ind.hideIcon == true) then
		bsz = 0
	end
	local br, bg, bb = Col(ind.indBorderColor, 0, 0, 0)
	RF.LayoutEdges(e.edges, bsz, br, bg, bb, 1)
	e.showSwipe = ind.showDuration ~= false and not (not square and ind.hideIcon == true)
	e.showStacks = ind.showStacks ~= false
	e.showDurText = ind.showDurationText == true
	RF.SetIconFont(e.stack, ind.stacksTextSize or 8)
	e.stack:SetTextColor(Col(ind.stacksTextColor, 1, 1, 1))
	e.stack:ClearAllPoints()
	e.stack:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", ind.stacksOffsetX or -1, ind.stacksOffsetY or 2)
	RF.SetIconFont(e.durText, ind.durationTextSize or 8)
	e.durText:SetTextColor(Col(ind.durationTextColor, 1, 1, 1))
	e.durText:ClearAllPoints()
	e.durText:SetPoint("CENTER", f, "CENTER", ind.durationTextOffsetX or 0, ind.durationTextOffsetY or 0)
	e.size = size
end

-- Bar geometry (retail BmAnchorOneSlot "bar" branch / BM_PlaceBar).
local function PlaceBar(e, ind, anchor, health, iscale, base)
	local bar = e.frame
	local w = (ind.barWidth or 30) * iscale
	local h = (ind.barHeight or 4) * iscale
	local isVert = (ind.orientation or "HORIZONTAL") == "VERTICAL"
	bar:SetOrientation(isVert and "VERTICAL" or "HORIZONTAL")
	if bar.SetReverseFill then
		bar:SetReverseFill(ind.reverseFill == true)
	end
	local fullW, fullH
	if isVert then
		fullW, fullH = ind.barFullHeight, ind.barFullWidth
	else
		fullW, fullH = ind.barFullWidth, ind.barFullHeight
	end
	local pos = ind.position or "TOPLEFT"
	bar:ClearAllPoints()
	if fullW and fullH then
		bar:SetAllPoints(health)
	elseif fullW then
		local vEdge = (pos:find("BOTTOM", 1, true) and "BOTTOM") or (pos:find("TOP", 1, true) and "TOP") or ""
		local oy = (ind.offsetY or 0) * iscale
		bar:SetPoint(vEdge .. "LEFT", anchor, vEdge .. "LEFT", 0, oy)
		bar:SetPoint(vEdge .. "RIGHT", anchor, vEdge .. "RIGHT", 0, oy)
		bar:SetHeight(isVert and w or h)
	elseif fullH then
		local hEdge = (pos:find("RIGHT", 1, true) and "RIGHT") or (pos:find("LEFT", 1, true) and "LEFT") or ""
		local ox = (ind.offsetX or 0) * iscale
		bar:SetPoint("TOP" .. hEdge, health, "TOP" .. hEdge, ox, 0)
		bar:SetPoint("BOTTOM" .. hEdge, health, "BOTTOM" .. hEdge, ox, 0)
		bar:SetWidth(isVert and h or w)
	else
		if isVert then
			bar:SetSize(h, w)
		else
			bar:SetSize(w, h)
		end
		bar:SetPoint(pos, anchor, pos, (ind.offsetX or 0) * iscale, (ind.offsetY or 0) * iscale)
	end
	local r, g, b = Col(ind.color, 12 / 255, 210 / 255, 157 / 255)
	bar:SetStatusBarColor(r, g, b, (ind.barColorOpacity or 100) / 100)
	local br, bg, bb = Col(ind.barBgColor, 0, 0, 0)
	e.bg:SetVertexColor(br, bg, bb, (ind.barBgOpacity or 50) / 100)
	bar:SetFrameLevel(Lvl(base, FRAMELVL[ind.frameLevel or "behindBorders"] or 7))
	e.ind = ind
end

local function StyleEffect(btn, e, ind, base)
	local r, g, b = Col(ind.color, 0, 1, 0)
	if e.kind == "healthcolor" then
		local health = e.health
		local fill = health.GetStatusBarTexture and health:GetStatusBarTexture()
		e.tex:ClearAllPoints()
		if fill then
			e.tex:SetAllPoints(fill)
			local path = fill:GetTexture()
			e.tex:SetTexture(path or RF.WHITE)
		else
			e.tex:SetAllPoints(health)
			e.tex:SetTexture(RF.WHITE)
		end
		e.tex:SetVertexColor(r, g, b, (ind.opacity or 100) / 100)
	elseif e.kind == "bgcolor" then
		e.tex:SetVertexColor(r, g, b, (ind.opacity or 100) / 100)
	else
		r, g, b = Col(ind.color, 0.05, 0.82, 0.62)
		e.frame:SetFrameLevel(Lvl(base, 11))
		e.frame:Apply(ind.borderWidth or 2, r, g, b, (ind.borderOpacity or 100) / 100)
	end
	e.ind = ind
end

-- Which views this button renders (the preview may show the edited bucket).
local function ViewsFor(btn)
	local bucket = btn.rfPreview and RF.BM_PreviewKey or nil
	return SpecIndicators(FrameKind(btn), bucket)
end

-- Build / restyle the elements of a button for the current views.
function RF.BM_Relayout(btn)
	if not btn then
		return
	end
	local st = btn.rfBM
	if not st then
		RF.BM_Init(btn)
		st = btn.rfBM
	end
	HideState(st)
	local views = ViewsFor(btn)
	st.views = views
	local iscale = RF.BmScaleFor and RF.BmScaleFor(btn) or 1
	st.iscale = iscale
	local base = btn:GetFrameLevel()
	local health = HealthOf(btn)
	st.health = health
	local anchor = AnchorOf(btn)
	st.anchor = anchor
	-- Element pools by kind, handed out in view order (reused across relayouts).
	local used = { icon = 0, bar = 0, healthcolor = 0, bgcolor = 0, border = 0 }
	local pools = st.pools
	local function Take(kind)
		used[kind] = used[kind] + 1
		local pool = pools[kind]
		local e = pool[used[kind]]
		if not e then
			if kind == "icon" then
				e = NewIcon(btn)
			elseif kind == "bar" then
				e = NewBar(btn)
			else
				e = NewEffect(btn, kind)
			end
			pool[used[kind]] = e
		end
		return e
	end
	wipe(st.els)
	for i, v in ipairs(views) do
		local kind = Kind(v.ind)
		local set = {}
		if kind == "icon" or kind == "square" then
			for _ = 1, SlotCount(v) do
				local e = Take("icon")
				StyleIcon(btn, e, v, iscale, base)
				set[#set + 1] = e
			end
		elseif kind == "bar" then
			local e = Take("bar")
			PlaceBar(e, v.ind, anchor, health, iscale, base)
			set[1] = e
		elseif kind then
			local e = Take(kind)
			StyleEffect(btn, e, v.ind, base)
			set[1] = e
		end
		st.els[i] = set
	end
	-- Hide pooled elements no view uses anymore.
	for kind, pool in pairs(pools) do
		for k = used[kind] + 1, #pool do
			pool[k].frame:Hide()
			SetTimed(pool[k], false)
		end
	end
	st.gen = gen
end

function RF.BM_Init(btn)
	if not btn or btn.rfBM then
		return
	end
	btn.rfBM = { els = {}, views = {}, pools = { icon = {}, bar = {}, healthcolor = {}, bgcolor = {}, border = {} } }
end

-------------------------------------------------------------------------------
--  Aura scan + paint
-------------------------------------------------------------------------------
local function IsOwn(caster)
	if not caster then
		return false
	end
	if caster == "player" or caster == "pet" or caster == "vehicle" then
		return true
	end
	return UnitIsUnit(caster, "player") or UnitIsUnit(caster, "pet")
end

-- Scratch aura list of the current scan: { name, icon, count, dur, exp, own, id, index }.
local auras = {}
local nAuras = 0
local function ScanUnit(unit)
	nAuras = 0
	for i = 1, 40 do
		local name, _, icon, count, _, duration, expires, caster, _, _, spellId = UnitAura(unit, i, "HELPFUL")
		if not name then
			break
		end
		nAuras = nAuras + 1
		local a = auras[nAuras]
		if not a then
			a = {}
			auras[nAuras] = a
		end
		a.name, a.icon, a.count, a.dur, a.exp, a.own, a.id, a.index =
			name, icon, count or 0, duration or 0, expires or 0, IsOwn(caster), spellId, i
	end
end

-- Preview samples (retail BM_ApplyPreviewIndicators): a few known spells of
-- each indicator with seeded durations.
local seeds = {}
local function Seed(key)
	local s = seeds[key]
	if not s then
		s = 0.2 + math.random() * 0.7
		seeds[key] = s
	end
	return s
end

local function PreviewAuras(btn)
	nAuras = 0
	local st = btn.rfBM
	local now = GetTime()
	local tag = tostring(btn.rfPreviewIndex or btn:GetName() or btn)
	for _, v in ipairs(st.views or {}) do
		local kind = Kind(v.ind)
		local n = (kind == "icon" or kind == "square") and min(#v.m.known, 3) or 1
		for k = 1, n do
			local id = v.m.known[k]
			if not id then
				break
			end
			local name, _, icon = GetSpellInfo(id)
			local show = true
			if kind ~= "icon" and kind ~= "square" and kind ~= "bar" then
				show = Seed(tag .. ":fx" .. id) > 0.55
			end
			if name and show then
				nAuras = nAuras + 1
				local a = auras[nAuras]
				if not a then
					a = {}
					auras[nAuras] = a
				end
				local frac = Seed(tag .. ":" .. id)
				a.name, a.icon, a.count, a.dur, a.exp, a.own, a.id, a.index =
					name, icon, (k == 1 and 2 or 0), 15, now + 15 * frac, true, id, k
			end
		end
	end
end

local function Matches(v, a)
	if v.ind.ownOnly == true and not a.own then
		return false
	end
	return (a.id and v.m.ids[a.id]) or v.m.names[a.name] or false
end

local function ShowIcon(e, a)
	if not e.square then
		e.tex:SetTexture(a.icon)
	else
		local ind = e.ind
		local c = (ind.spellColors and a.id and ind.spellColors[a.id]) or ind.color
		local r, g, b = Col(c, 12 / 255, 210 / 255, 157 / 255)
		e.sq:SetVertexColor(r, g, b, 1)
	end
	if e.showSwipe and a.dur > 0 and a.exp > 0 then
		e.cd:SetCooldown(a.exp - a.dur, a.dur)
		e.cd:Show()
	else
		e.cd:Hide()
	end
	if e.showStacks and (a.count or 0) > 1 then
		e.stack:SetText(a.count)
	else
		e.stack:SetText("")
	end
	e.exp, e.dur = a.exp, a.dur
	if e.showDurText and a.exp > 0 and a.dur > 0 then
		SetTimed(e, true)
	else
		e.durText:SetText("")
		SetTimed(e, false)
	end
	e.frame:Show()
end

-- Positions a run of icons from an anchor (retail chain flow: active icons
-- compact into the first positions; CENTER growth centers the run).
local function PlaceRun(list, ind, health, iscale, startK, total)
	local grow = ind.growDirection or "RIGHT"
	local pos = ind.position or "TOPLEFT"
	for k = 1, #list do
		local e = list[k]
		local step = e.size + (ind.spacing or 0) * iscale
		local cursor = (startK + k - 2) * step
		if grow == "CENTER" then
			cursor = cursor - ((total - 1) * step) / 2
		end
		local gx, gy = 0, 0
		if grow == "LEFT" then
			gx = -cursor
		elseif grow == "DOWN" then
			gy = -cursor
		elseif grow == "UP" then
			gy = cursor
		else
			gx = cursor
		end
		e.frame:ClearAllPoints()
		e.frame:SetPoint(pos, health, pos, (ind.offsetX or 0) * iscale + gx, (ind.offsetY or 0) * iscale + gy)
	end
end

function RF.BM_Update(btn)
	if not btn then
		return
	end
	local st = btn.rfBM
	if not st then
		RF.BM_Init(btn)
		st = btn.rfBM
	end
	if st.gen ~= gen or (btn.rfPreview and st.pvKey ~= RF.BM_PreviewKey) or (not btn.rfPreview and st.pvKey) then
		st.pvKey = btn.rfPreview and RF.BM_PreviewKey or nil
		RF.BM_Relayout(btn)
	end
	local unit = RF.UnitOf and RF.UnitOf(btn) or btn:GetAttribute("unit")
	if btn.rfPreview then
		PreviewAuras(btn)
	elseif unit and UnitExists(unit) then
		ScanUnit(unit)
	else
		nAuras = 0
	end
	local anchor = st.anchor or HealthOf(btn)
	local iscale = st.iscale or 1
	-- Shown icons per view (for Anchor To runs).
	local runs = {}
	for i, v in ipairs(st.views) do
		local set = st.els[i]
		local kind = Kind(v.ind)
		if set and kind then
			if kind == "icon" or kind == "square" then
				local shown = {}
				for j = 1, nAuras do
					local a = auras[j]
					if #shown >= #set then
						break
					end
					if Matches(v, a) then
						local e = set[#shown + 1]
						shown[#shown + 1] = e
						ShowIcon(e, a)
					end
				end
				for k = #shown + 1, #set do
					set[k].frame:Hide()
					SetTimed(set[k], false)
				end
				runs[v.id] = { list = shown, v = v }
			elseif kind == "bar" then
				local e = set[1]
				local hit = nil
				for j = 1, nAuras do
					if Matches(v, auras[j]) then
						hit = auras[j]
						break
					end
				end
				if hit then
					e.dur, e.exp = hit.dur, hit.exp
					if hit.dur > 0 and hit.exp > 0 then
						e.frame:SetMinMaxValues(0, hit.dur)
						SetTimed(e, true)
					else
						e.frame:SetMinMaxValues(0, 1)
						e.frame:SetValue(1)
						SetTimed(e, false)
					end
					e.frame:Show()
				else
					e.frame:Hide()
					SetTimed(e, false)
				end
			else
				local e = set[1]
				local hit = false
				for j = 1, nAuras do
					if Matches(v, auras[j]) then
						hit = true
						break
					end
				end
				if hit and kind == "healthcolor" then
					-- Follow the health texture (it may change with settings).
					local fill = e.health.GetStatusBarTexture and e.health:GetStatusBarTexture()
					local path = fill and fill:GetTexture()
					if path then
						e.tex:SetTexture(path)
					end
				end
				e.frame:SetShown(hit)
			end
		end
	end
	-- Place icon runs; Anchor To members continue their root's run.
	local function RootOf(v)
		local cur, guard = v, 0
		while cur.anchorTo and runs[cur.anchorTo] and guard < 10 do
			cur = runs[cur.anchorTo].v
			guard = guard + 1
		end
		return cur
	end
	local chains = {}
	for _, v in ipairs(st.views) do
		local r = runs[v.id]
		if r then
			local root = RootOf(v)
			local c = chains[root.id]
			if not c then
				c = { root = root, members = {} }
				chains[root.id] = c
				chains[#chains + 1] = c
			end
			c.members[#c.members + 1] = r
		end
	end
	for _, c in ipairs(chains) do
		local total = 0
		for _, r in ipairs(c.members) do
			total = total + #r.list
		end
		local k = 1
		for _, r in ipairs(c.members) do
			if #r.list > 0 then
				PlaceRun(r.list, c.root.ind, anchor, iscale, k, total)
				k = k + #r.list
			end
		end
	end
end

-------------------------------------------------------------------------------
--  Events: own HELPFUL scan per UNIT_AURA, spec changes, settings apply.
-------------------------------------------------------------------------------
local function UpdateAll()
	if RF.ForEachButton then
		RF.ForEachButton(function(btn)
			RF.BM_Relayout(btn)
			RF.BM_Update(btn)
		end)
	end
end
RF.BM_UpdateAll = UpdateAll

do
	local f = CreateFrame("Frame")
	f:RegisterEvent("UNIT_AURA")
	f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
	f:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
	f:RegisterEvent("PLAYER_ENTERING_WORLD")
	f:SetScript("OnEvent", function(_, event, unit)
		if event == "UNIT_AURA" then
			if not (ERF.started and RF.ButtonsForUnit) then
				return
			end
			for btn in pairs(RF.ButtonsForUnit(unit)) do
				if not btn.rfPreview then
					RF.BM_Update(btn)
				end
			end
		elseif event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then
			return
		else
			RF.BM2_Invalidate()
			if ERF.started then
				UpdateAll()
			end
		end
	end)
end

RF.OnApply(function()
	ensuredGen = nil
	RF.BM2_Invalidate()
	UpdateAll()
end, 35)
