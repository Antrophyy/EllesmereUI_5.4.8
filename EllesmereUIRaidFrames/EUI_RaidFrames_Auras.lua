-------------------------------------------------------------------------------
--  EUI_RaidFrames_Auras.lua  (5.4.8 port of the retail 12.1 aura containers
--  + Debuff Manager runtime)
--
--  Retail draws debuffs with C-side aura containers fed by secret filter
--  tokens (CROWD_CONTROL, RAID, RAID_IN_COMBAT, RAID_PLAYER_DISPELLABLE) and
--  candidate booleans (isBossAura, isRoleAura, isPriorityAura ...). 5.4.8
--  has none of that, so this file scans UnitAura once per unit per UNIT_AURA
--  and sorts each debuff into the same categories by hand:
--    cc          MoP crowd control spell list (ElvUI MoP CCDebuffs)
--    boss        isBossDebuff
--    role        boss/NPC debuff on a tank with stacks (5.4.8 has no role auras)
--    priority    MoP raid debuff list (ElvUI MoP RaidDebuffs) or isBossDebuff
--    raid        Blizzard raid-frame visibility (SpellGetVisibilityInfo
--                RAID_OUTOFCOMBAT) and not cast by a friendly player
--    raidcombat  same with RAID_INCOMBAT
--    dispel      "you": dispellable by you (UnitAura "HARMFUL|RAID");
--                "typed": any Magic/Curse/Disease/Poison debuff
--    nonplayer   caster not player controlled ("any" flavor: player controlled)
--    castbyme    cast by you / your pet
--    magic curse poison disease  by dispel type (bleed has no type on 5.4.8)
--    canapply    UnitAura canApplyAura
--  The saved model is retail's (profile.dmDebuff: all, show lane, neg lane,
--  match, hasDuration, dispelMode, nonplayerMode, tiles, specTiles, fxList)
--  and the base row uses the retail debuff* keys. Also: Defensives &
--  Externals (def* keys) and btn.rfDispel for the button's dispel visuals.
-------------------------------------------------------------------------------
local addonName, RF = ...
local ns = EllesmereUI
local ERF = RF.ERF

local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min
local pairs, ipairs, type, next = pairs, ipairs, type, next
local UnitAura = UnitAura
local GetTime = GetTime

-------------------------------------------------------------------------------
--  Spell data (5.4.8 IDs)
-------------------------------------------------------------------------------
-- Sated debuffs (retail SATED_DEBUFFS; the 5.4.8 ones): Exhaustion, Sated,
-- Temporal Displacement, Insanity.
RF.AURA_SATED = { [57723] = true, [57724] = true, [80354] = true, [95809] = true }

-- Crowd control (ElvUI MoP CCDebuffs list).
RF.AURA_CC = {}
for _, id in ipairs({
	99, 118, 122, 339, 408, 605, 676, 710, 853, 1330, 1513, 1776, 1833, 2094, 2637, 3355, 4167, 5211, 5484,
	6358, 6770, 6789, 7922, 8122, 9005, 9484, 10326, 15487, 18498, 19386, 19503, 20066, 20511, 20549, 22570,
	24259, 24394, 25046, 30283, 31661, 31935, 33395, 33786, 34490, 44572, 45334, 47476, 50245, 50519, 50541,
	51514, 51722, 54706, 55021, 56626, 63685, 64044, 64695, 64803, 76780, 78675, 82691, 87194, 88611, 88625,
	89766, 90327, 90337, 91644, 91797, 91800, 91807, 96201, 102051, 102359, 102795, 105421, 105593, 105771,
	107079, 107566, 107570, 108194, 113004, 113792, 113953, 114238, 114404, 115001, 115078, 115197, 115268,
	115782, 116706, 116709, 117368, 117405, 118093, 118271, 118345, 118699, 118895, 118905, 119381, 119392,
	120086, 122242, 123407, 127797, 128405, 132168, 137143, 140023,
	-- more MoP crowd control
	5246, 1499, 19185, 132169, 119072, 117526, 115750, 127361, 91802,
}) do
	RF.AURA_CC[id] = true
end

-- Priority raid debuffs: Mogu'shan Vaults .. Siege of Orgrimmar (ElvUI MoP RaidDebuffs list).
RF.AURA_PRIORITY = {}
for _, id in ipairs({
	116161, 116281, 116374, 116417, 116525, 116778, 116784, 116835, 116942, 117436, 117519, 117708, 117723,
	117878, 117949, 118048, 118091, 118135, 118163, 118303, 119086, 119775, 119985, 120629, 120669, 121949,
	122055, 122064, 122151, 122370, 122740, 122752, 122760, 122761, 122777, 122835, 123011, 123036, 123081,
	123121, 123180, 123474, 123705, 123812, 123963, 125206, 129078, 130395, 131788, 131790, 131792, 132222,
	133597, 133767, 133768, 133798, 134256, 134366, 134391, 134691, 135000, 135695, 136050, 136192, 136193,
	136228, 136295, 136478, 136512, 136587, 136654, 136708, 136710, 136719, 136722, 136753, 136767, 136857,
	136903, 136914, 136922, 136992, 137162, 137341, 137359, 137360, 137371, 137408, 137422, 137440, 137633,
	137641, 137731, 137972, 138297, 138329, 138349, 138372, 138569, 138609, 138659, 138732, 139011, 139840,
	139843, 139857, 140092, 140179, 140701, 142315, 142864, 142865, 142913, 142948, 142990, 143198, 143385,
	143431, 143434, 143436, 143480, 143494, 143579, 143638, 143701, 143766, 143767, 143773, 143777, 143780,
	143791, 143800, 143840, 143919, 143974, 143990, 144089, 144215, 144236, 144330, 144351, 144358, 144459,
	144467, 144514, 144774, 144851, 145065, 145171, 145183, 145195, 145218, 146124, 146235, 146589, 146594,
	146902, 147029, 147207, 147383,
}) do
	RF.AURA_PRIORITY[id] = true
end

-- Externals: cast on the unit by someone else.
RF.AURA_EXTERNALS = {
	[33206] = true,  -- Pain Suppression
	[47788] = true,  -- Guardian Spirit
	[102342] = true, -- Ironbark
	[116849] = true, -- Life Cocoon
	[6940] = true,   -- Hand of Sacrifice
	[1022] = true,   -- Hand of Protection
	[114030] = true, -- Vigilance
	[114039] = true, -- Hand of Purity
	[53480] = true,  -- Roar of Sacrifice
	[3411] = true,   -- Intervene
	[114029] = true, -- Safeguard
	[62618] = true,  -- Power Word: Barrier
	[81782] = true,  -- Power Word: Barrier (aura)
	[98007] = true,  -- Spirit Link Totem
	[31821] = true,  -- Devotion Aura
	[97463] = true,  -- Rallying Cry
	[50461] = true,  -- Anti-Magic Zone
	[145629] = true, -- Anti-Magic Zone (aura)
	[76577] = true,  -- Smoke Bomb
}

-- Personal defensives (self cast), per class.
RF.AURA_DEFENSIVES = {
	-- Death Knight
	[48707] = true, [48792] = true, [49039] = true, [55233] = true, [49028] = true, [81256] = true, [114556] = true,
	-- Druid
	[22812] = true, [61336] = true, [106922] = true, [102795] = false, [62606] = true, [102558] = true,
	-- Hunter
	[19263] = true, [5384] = true,
	-- Mage
	[45438] = true, [115610] = true, [110909] = true, [11426] = true, [113862] = true,
	-- Monk
	[115203] = true, [120954] = true, [122783] = true, [122278] = true, [115213] = true, [125174] = true,
	[115176] = true, [131523] = true, [122470] = true,
	-- Paladin
	[498] = true, [642] = true, [86659] = true, [31850] = true, [114917] = true,
	-- Priest
	[47585] = true, [586] = true, [19236] = true, [27827] = true,
	-- Rogue
	[1966] = true, [31224] = true, [5277] = true, [74001] = true, [45182] = true,
	-- Shaman
	[30823] = true, [108271] = true, [108281] = true,
	-- Warlock
	[104773] = true, [110913] = true, [108416] = true, [108359] = true,
	-- Warrior
	[871] = true, [12975] = true, [118038] = true, [55694] = true, [23920] = true, [112048] = true,
	[2565] = true, [114028] = true,
	-- Racial
	[20594] = true,
}

-- What each class can dispel on friends (spec index -> extra types).
-- Used when the "HARMFUL|RAID" scan is not available (preview).
local CLASS_DISPEL = {
	PALADIN = { Poison = true, Disease = true, spec = { [1] = { Magic = true } } },
	PRIEST = { spec = { [1] = { Magic = true, Disease = true }, [2] = { Magic = true, Disease = true } } },
	SHAMAN = { Curse = true, spec = { [3] = { Magic = true } } },
	DRUID = { Curse = true, Poison = true, spec = { [4] = { Magic = true } } },
	MONK = { Poison = true, Disease = true, spec = { [2] = { Magic = true } } },
	MAGE = { Curse = true },
	WARLOCK = { Magic = true },
}

local TYPED = { Magic = true, Curse = true, Disease = true, Poison = true }
local TYPE_OF_CAT = { magic = "Magic", curse = "Curse", poison = "Poison", disease = "Disease", bleed = "Bleed" }

-- Category vocabulary (retail CATS). Ownership order: an aura that matches
-- several shown categories renders in the first one (cc leads the row).
RF.DM_CATS = {
	"boss", "role", "priority", "cc", "raid", "raidcombat", "dispel", "nonplayer",
	"castbyme", "magic", "curse", "poison", "disease", "bleed", "canapply",
}
local OWN_ORDER = {
	"cc", "dispel", "raid", "raidcombat", "castbyme", "magic", "curse", "poison", "disease", "bleed",
	"priority", "boss", "role", "canapply", "nonplayer",
}
local OWN_RANK = {}
for i, c in ipairs(OWN_ORDER) do
	OWN_RANK[c] = i
end

-------------------------------------------------------------------------------
--  Player dispel ability
-------------------------------------------------------------------------------
local playerClass = select(2, UnitClass("player"))
local canDispelType = {}

local function RefreshDispelTypes()
	for k in pairs(canDispelType) do
		canDispelType[k] = nil
	end
	local c = CLASS_DISPEL[playerClass]
	if not c then
		return
	end
	for k, v in pairs(c) do
		if k ~= "spec" and v then
			canDispelType[k] = true
		end
	end
	local idx = GetSpecialization and GetSpecialization()
	local extra = idx and c.spec and c.spec[idx]
	if extra then
		for k in pairs(extra) do
			canDispelType[k] = true
		end
	end
end
RF.AuraRefreshDispelTypes = RefreshDispelTypes

function RF.PlayerCanDispel(dtype)
	return dtype and canDispelType[dtype] == true or false
end

-------------------------------------------------------------------------------
--  Debuff Manager model (retail profile.dmDebuff)
-------------------------------------------------------------------------------
local function EnsureFilterV2(dm)
	if dm.filtersV2 then
		return
	end
	dm.filtersV2 = true
	if dm.all ~= false then
		dm.boss, dm.role, dm.priority, dm.raid = nil, nil, nil, nil
		dm.raidcombat, dm.nonplayer, dm.dispel, dm.cc = nil, nil, nil, nil
	else
		dm.cc = (dm.cc ~= false) and true or nil
	end
end

local function EnsureFilterLanes(dm)
	if dm.lanesV1 then
		return
	end
	dm.lanesV1 = true
	if dm.all ~= false then
		local neg = nil
		for _, cat in ipairs({ "boss", "role", "priority", "cc", "raid", "raidcombat", "dispel", "nonplayer" }) do
			if dm[cat] == true then
				neg = neg or {}
				neg[cat] = true
				dm[cat] = nil
			end
		end
		if neg then
			dm.neg = neg
		end
	end
end

-- Retail EnsureMigrated: maps the retired debuffFilter preset (and the
-- dispellable location split) onto a new dmDebuff, once.
function RF.DM_Get()
	local p = RF.Profile()
	if not p then
		return nil
	end
	local dm = p.dmDebuff
	if dm then
		EnsureFilterV2(dm)
		EnsureFilterLanes(dm)
		return dm
	end
	local preset = p.debuffFilter
	dm = { _fromPreset = preset or "default" }
	if preset == "raid" then
		dm.all = false
		dm.raid = true
		dm.raidcombat = true
	elseif preset == "dispellable" then
		dm.all = false
		dm.dispel = true
		dm.dispelMode = "you"
	elseif preset == "none" then
		dm.all = false
		dm.cc = false
	end
	if preset ~= "none" and (p.dispellableDebuffLocation or "same") ~= "same" then
		local size = p.dispellableDebuffSize
		if not size or size <= 0 then
			size = p.debuffSize or 18
		end
		dm.dispelMode = "typed"
		dm.tiles = { {
			id = 1, enabled = true, type = "icons",
			claim = { dispel = true },
			position = p.dispellableDebuffLocation,
			growDirection = p.dispellableDebuffGrowDirection or "CENTER",
			offsetX = p.dispellableDebuffOffsetX or 0,
			offsetY = p.dispellableDebuffOffsetY or 0,
			size = size,
			spacing = p.debuffSpacing or 1,
			cap = p.debuffCap or 3,
		} }
		dm.nextTileId = 2
	end
	p.dmDebuff = dm
	EnsureFilterV2(dm)
	EnsureFilterLanes(dm)
	return dm
end

-- Old tile shapes (retail HealTiles).
local function HealTiles(arr)
	for i = 1, #arr do
		local t = arr[i]
		if t.type == "square" and not t.claim then
			t.claim = {}
			if t.cat then
				t.claim[t.cat] = true
				t.cat = nil
			end
			local sz = t.width or t.height
			if sz and sz > 0 then
				t.size = sz
			end
			t.width, t.height = nil, nil
			t.growDirection = t.growDirection or "CENTER"
			t.spacing = t.spacing or 1
			t.cap = t.cap or 3
		end
		if (t.type == "glow" or t.type == "healthcolor" or t.type == "bar") and not t.claim then
			t.claim = {}
			if t.cat then
				t.claim[t.cat] = true
				t.cat = nil
			end
		end
		if t.type == "healthcolor" and t.opacity == nil and t.color and t.color.a then
			t.opacity = floor((t.color.a * 100) + 0.5)
		end
	end
end
RF.DM_HealTiles = HealTiles

-- Spec buckets: the player's spec ID and its group bucket keys
-- ("healers" / "tanks" / "dps", plus "nonhealer" for non healers).
function RF.DM_SpecID()
	return RF.SpecID and RF.SpecID() or nil
end

function RF.DM_RoleBucketForSpecID(sid)
	if not sid or not GetSpecializationRoleByID then
		return nil
	end
	local role = GetSpecializationRoleByID(sid)
	if not role and GetSpecializationInfoByID then
		role = select(6, GetSpecializationInfoByID(sid))
	end
	if role == "HEALER" then
		return "healers"
	elseif role == "TANK" then
		return "tanks"
	elseif role == "DAMAGER" then
		return "dps"
	end
	return nil
end

-- Tiles a spec renders (retail UnionFor): all specs, nonhealer, role group,
-- own spec; group tiles the spec disabled drop out.
function RF.DM_UnionFor(dm, sid)
	local out = {}
	if not dm then
		return out
	end
	local st = dm.specTiles
	local con = st and sid and st["spec" .. sid] or nil
	local dis = con and con.inhDis or nil
	if dm.tiles then
		HealTiles(dm.tiles)
		for i = 1, #dm.tiles do
			local t = dm.tiles[i]
			if not (dis and dis[t.id]) then
				out[#out + 1] = t
			end
		end
	end
	if st and sid then
		local function Add(key, filtered)
			local b = st[key]
			local tl = b and b.tiles
			if not tl then
				return
			end
			HealTiles(tl)
			for i = 1, #tl do
				local t = tl[i]
				if not (filtered and dis and dis[t.id]) then
					out[#out + 1] = t
				end
			end
		end
		local roleKey = RF.DM_RoleBucketForSpecID(sid)
		if roleKey ~= "healers" then
			Add("nonhealer", true)
		end
		if roleKey then
			Add(roleKey, true)
		end
		Add("spec" .. sid, false)
	end
	return out
end

function RF.DM_ActiveTiles()
	return RF.DM_UnionFor(RF.DM_Get(), RF.DM_SpecID())
end

-- Base Icons switched off for the current spec (b.baseOff).
local BASE_OFF_VIEW = { all = false }
function RF.DM_BaseView(dm)
	local st = dm and dm.specTiles
	local sid = RF.DM_SpecID()
	local b = st and sid and st["spec" .. sid]
	if b and b.baseOff then
		return BASE_OFF_VIEW
	end
	return dm
end

-- Bucket tile array ("allspecs"/nil = dm.tiles), created on demand.
function RF.DM_BucketTiles(key, create)
	local dm = RF.DM_Get()
	if not dm then
		return nil
	end
	if not key or key == "allspecs" then
		if not dm.tiles and create then
			dm.tiles = {}
		end
		if dm.tiles then
			HealTiles(dm.tiles)
		end
		return dm.tiles
	end
	local st = dm.specTiles
	if not st then
		if not create then
			return nil
		end
		st = {}
		dm.specTiles = st
	end
	local b = st[key]
	if not b then
		if not create then
			return nil
		end
		b = { tiles = {}, inhDis = {} }
		st[key] = b
	end
	b.tiles = b.tiles or {}
	b.inhDis = b.inhDis or {}
	HealTiles(b.tiles)
	return b.tiles, b
end

-- Retail DM_AddTile: a new indicator with the retail defaults; ids are
-- unique across every bucket (per-spec disables key on the bare id).
function RF.DM_AddTile(tileType, bucketKey)
	local dm = RF.DM_Get()
	if not dm then
		return nil
	end
	local id = dm.nextTileId or 1
	local maxId = 0
	local function Scan(tl)
		for i = 1, #(tl or {}) do
			local tid = tonumber(tl[i].id) or 0
			if tid > maxId then
				maxId = tid
			end
		end
	end
	Scan(dm.tiles)
	for _, b in pairs(dm.specTiles or {}) do
		Scan(b.tiles)
	end
	if id <= maxId then
		id = maxId + 1
	end
	dm.nextTileId = id + 1
	local t = { id = id, enabled = true, type = tileType or "icons", claim = {} }
	if t.type == "icons" or t.type == "square" then
		t.position = "top"
		t.growDirection = "CENTER"
		t.size = 18
		t.spacing = 1
		t.cap = 3
		if t.type == "square" then
			t.color = { r = 1, g = 0.35, b = 0.35, a = 1 }
		end
	elseif t.type == "bar" then
		t.position = "bottom"
		t.width = 60
		t.height = 5
		t.orientation = "HORIZONTAL"
		t.color = { r = 0.25, g = 0.8, b = 0.45 }
		t.barColorOpacity = 100
		t.barBgColor = { r = 0, g = 0, b = 0 }
		t.barBgOpacity = 50
		t.frameLevel = "behindBorders"
	elseif t.type == "healthcolor" then
		t.color = { r = 1, g = 0.25, b = 0.25 }
		t.opacity = 45
	else
		t.glowType = 1
		t.color = { r = 1, g = 0.78, b = 0.38, a = 1 }
	end
	local list = RF.DM_BucketTiles(bucketKey, true)
	list[#list + 1] = t
	return t
end

function RF.DM_DeleteTile(id)
	local dm = RF.DM_Get()
	if not dm then
		return
	end
	local function Drop(tl)
		for i = #(tl or {}), 1, -1 do
			if tl[i].id == id then
				table.remove(tl, i)
			end
		end
	end
	Drop(dm.tiles)
	for _, b in pairs(dm.specTiles or {}) do
		Drop(b.tiles)
		if b.inhDis then
			b.inhDis[id] = nil
		end
	end
end

-- Effects list entries that do something (retail FxEntryActive).
function RF.DM_FxActive(e)
	return e and e.filters ~= nil and next(e.filters) ~= nil
		and (((e.glowType or 0) > 0) or ((e.borderSize or 0) > 0) or ((tonumber(e.size) or 0) > 0))
end

-------------------------------------------------------------------------------
--  Config cache: rebuilt on ApplyAll / spec change, read by every scan.
-------------------------------------------------------------------------------
local cfg = nil

local function Picks(lane)
	local n = 0
	if lane then
		for _, c in ipairs(RF.DM_CATS) do
			if lane[c] == true then
				n = n + 1
			end
		end
	end
	return n
end

local function BuildCfg()
	local p = RF.Profile()
	local dm = RF.DM_Get() or {}
	local bv = RF.DM_BaseView(dm)
	local c = {}
	c.dm = dm
	c.allOn = bv.all ~= false
	c.show = {}
	if not c.allOn then
		for _, cat in ipairs(RF.DM_CATS) do
			if bv[cat] == true then
				c.show[cat] = true
			end
		end
	end
	c.neg = {}
	if bv.neg then
		for k, v in pairs(bv.neg) do
			if v == true then
				c.neg[k] = true
			end
		end
	end
	c.hasDuration = bv.hasDuration == true
	c.maxDur = tonumber(dm.maxDurSec)
	c.matchAll = (not c.allOn) and bv.match == "all" and Picks(bv) >= 2
	c.anyShow = next(c.show) ~= nil
	c.dispelMode = (dm.dispelMode == "typed") and "typed" or "you"
	c.npAny = dm.nonplayerMode == "any"
	c.hideLust = not p or p.hideLustDebuff ~= false
	-- Tiles: grid tiles (icons / square) claim categories; effect tiles
	-- (glow / healthcolor / bar) fire on their categories.
	c.grid, c.fx = {}, {}
	c.claims = {}
	local tiles = RF.DM_UnionFor(dm, RF.DM_SpecID())
	for i = 1, #tiles do
		local t = tiles[i]
		if t.enabled ~= false then
			if t.type == "icons" or t.type == "square" then
				c.grid[#c.grid + 1] = t
				if t.claim and not (t.match == "all" and Picks(t.claim) >= 2) then
					for _, cat in ipairs(RF.DM_CATS) do
						if t.claim[cat] and not c.claims[cat] then
							c.claims[cat] = t
						end
					end
				end
			elseif t.type == "glow" or t.type == "healthcolor" or t.type == "bar" then
				c.fx[#c.fx + 1] = t
			end
		end
	end
	-- Per-filter icon effects of the base row.
	c.fxList = {}
	if bv.fxList then
		for i = 1, #bv.fxList do
			if RF.DM_FxActive(bv.fxList[i]) then
				c.fxList[#c.fxList + 1] = bv.fxList[i]
			end
		end
	end
	-- Legacy defensives only while the Buff Manager has no Defensives filter
	-- (retail renders defensives through the Buff Manager preset).
	c.bmOwnsDef = false
	if RF.BM_OwnsDefensives then
		c.bmOwnsDef = RF.BM_OwnsDefensives() and true or false
	elseif p and type(p.bm2) == "table" and type(p.bm2.filters) == "table" and type(p.bm2.filters.list) == "table" then
		for _, f in ipairs(p.bm2.filters.list) do
			if type(f) == "table" and f.preset == "defensives" then
				c.bmOwnsDef = true
			end
		end
	end
	cfg = c
	return c
end
RF.DM_BuildCfg = BuildCfg

local function Cfg()
	return cfg or BuildCfg()
end

-------------------------------------------------------------------------------
--  Aura categories
-------------------------------------------------------------------------------
local function IsMine(caster)
	return caster == "player" or caster == "pet" or caster == "vehicle"
end

-- Blizzard 5.4.8 raid-frame debuff visibility (CompactUnitFrame_UtilShouldDisplayDebuff).
local function BlizzShows(spellId, caster, visType)
	if not SpellGetVisibilityInfo or not spellId then
		return true
	end
	local hasCustom, alwaysShowMine, showForMySpec = SpellGetVisibilityInfo(spellId, visType)
	if hasCustom then
		return (showForMySpec or (alwaysShowMine and IsMine(caster))) and true or false
	end
	return true
end

local function FriendlyPlayerCaster(caster)
	if not caster then
		return false
	end
	return UnitPlayerControlled(caster) and UnitIsFriend("player", caster) and true or false
end

-- Fills a.cats (category -> true) for one harmful aura record.
local function Categorize(a, unit, c)
	local cats = a.cats
	for k in pairs(cats) do
		cats[k] = nil
	end
	if a.preview then
		for k, v in pairs(a.preview) do
			cats[k] = v
		end
		if a.dtype and TYPED[a.dtype] then
			cats[a.dtype:lower()] = true
		end
		return
	end
	local id = a.spellId
	if id and RF.AURA_CC[id] then
		cats.cc = true
	end
	if a.isBoss then
		cats.boss = true
		cats.priority = true
	end
	if id and RF.AURA_PRIORITY[id] then
		cats.priority = true
	end
	local friendly = FriendlyPlayerCaster(a.caster)
	if not friendly or a.isBoss then
		if BlizzShows(id, a.caster, "RAID_OUTOFCOMBAT") then
			cats.raid = true
		end
		if BlizzShows(id, a.caster, "RAID_INCOMBAT") then
			cats.raidcombat = true
		end
	end
	if c.dispelMode == "typed" then
		if a.dtype and TYPED[a.dtype] then
			cats.dispel = true
		end
	elseif a.mine then
		cats.dispel = true
	end
	local pc = a.caster and UnitPlayerControlled(a.caster) and true or false
	if c.npAny then
		if pc then
			cats.nonplayer = true
		end
	elseif not pc then
		cats.nonplayer = true
	end
	if IsMine(a.caster) then
		cats.castbyme = true
	end
	if a.dtype and TYPED[a.dtype] then
		cats[a.dtype:lower()] = true
	end
	if a.canApply then
		cats.canapply = true
	end
	if (a.isBoss or not pc) and (a.count or 0) > 1 and RF.UnitRole(unit) == "TANK" then
		cats.role = true
	end
end

local function AnyCat(cats, set)
	for k in pairs(set) do
		if cats[k] then
			return true
		end
	end
	return false
end

local function AllCats(cats, set)
	for k in pairs(set) do
		if not cats[k] then
			return false
		end
	end
	return true
end

-- Owner category of an aura among `set` (first in ownership order).
local function OwnerIn(cats, set)
	for i = 1, #OWN_ORDER do
		local k = OWN_ORDER[i]
		if set[k] and cats[k] then
			return k
		end
	end
	return nil
end

-- Does a tile (claim / neg / all / match / hasDuration) take this aura?
local function TileTakes(t, a)
	local cats = a.cats
	if t.neg and AnyCat(cats, t.neg) then
		return false
	end
	if t.hasDuration == true and (a.duration or 0) <= 0 then
		return false
	end
	local md = tonumber(t.maxDurSec)
	if md and (a.duration or 0) > md then
		return false
	end
	if t.all == true then
		return true
	end
	local claim = t.claim
	if not claim or not next(claim) then
		return t.hasDuration == true
	end
	local on = {}
	for k, v in pairs(claim) do
		if v == true then
			on[k] = true
		end
	end
	if not next(on) then
		return t.hasDuration == true
	end
	if t.match == "all" and Picks(claim) >= 2 then
		return AllCats(cats, on)
	end
	return AnyCat(cats, on)
end

-- Base row: returns the owner category ("all" when shown by Show All), or nil.
local function BaseTakes(a, c)
	local cats = a.cats
	if AnyCat(cats, c.neg) then
		return nil
	end
	if c.hasDuration and not cats.cc and (a.duration or 0) <= 0 then
		return nil
	end
	if c.maxDur and (a.duration or 0) > c.maxDur then
		return nil
	end
	if c.allOn then
		return cats.cc and "cc" or "all"
	end
	if c.matchAll then
		if AllCats(cats, c.show) then
			return OwnerIn(cats, c.show) or "all"
		end
		return nil
	end
	if not c.anyShow then
		return c.hasDuration and "all" or nil
	end
	return OwnerIn(cats, c.show)
end

-------------------------------------------------------------------------------
--  Icon widgets
-------------------------------------------------------------------------------
local durTexts = {}   -- [fontString] = icon (live duration texts)
local durTicker = nil

local function FormatDur(rem)
	if rem >= 3600 then
		return format("%dh", ceil(rem / 3600))
	elseif rem >= 60 then
		return format("%dm", ceil(rem / 60))
	end
	return format("%d", ceil(rem))
end

local function TickDurations()
	local now = GetTime()
	local any = false
	for fs, icon in pairs(durTexts) do
		any = true
		if not icon:IsShown() or not icon.expires or icon.expires <= 0 then
			fs:SetText("")
			durTexts[fs] = nil
		else
			local rem = icon.expires - now
			if rem > 0 then
				fs:SetText(FormatDur(rem))
			else
				fs:SetText("")
			end
		end
	end
	if not any and durTicker then
		durTicker:Cancel()
		durTicker = nil
	end
end

local function WatchDuration(icon)
	durTexts[icon.dur] = icon
	if not durTicker then
		durTicker = RF.NewTicker(0.2, TickDurations)
	end
end

-- Tooltip on an aura icon. mode: true/nil hidden, false shown,
-- "combat" hidden in combat, "cursor" at the cursor, "modifier" while a
-- modifier key is held.
local function IconOnEnter(self)
	local mode = self.tipMode
	if mode == true or mode == nil then
		return
	end
	if mode == "combat" and InCombatLockdown() then
		return
	end
	if mode == "modifier" then
		-- Use Modifier key (debuffTooltipModifier); None = always shown.
		local key = self.tipKey or "none"
		if (key == "shift" and not IsShiftKeyDown()) or (key == "control" and not IsControlKeyDown())
			or (key == "alt" and not IsAltKeyDown()) then
			return
		end
	end
	if mode == "cursor" then
		GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
	else
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	end
	if self.unit and self.auraIndex then
		GameTooltip:SetUnitAura(self.unit, self.auraIndex, self.auraFilter or "HARMFUL")
	elseif self.spellId then
		GameTooltip:SetSpellByID(self.spellId)
	end
	GameTooltip:Show()
end

local function IconOnLeave(self)
	if GameTooltip:IsOwned(self) then
		GameTooltip:Hide()
	end
end

local function NewIcon(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(18, 18)
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetAllPoints(f)
	f.bg:SetTexture(0, 0, 0, 1)
	f.tex = f:CreateTexture(nil, "ARTWORK")
	f.tex:SetAllPoints(f)
	f.cd = CreateFrame("Cooldown", nil, f)
	f.cd:SetAllPoints(f.tex)
	f.cd:SetReverse(true)
	f.cd.noCooldownCount = true
	f.cd.noOCC = true
	-- Texts ride a frame above the swipe.
	f.textHost = CreateFrame("Frame", nil, f)
	f.textHost:SetAllPoints(f)
	f.dur = RF.NewText(f.textHost, 8, "OVERLAY")
	f.stack = RF.NewText(f.textHost, 8, "OVERLAY")
	f.edges = RF.CreateEdges(f.textHost, f, "OVERLAY", 1)
	f.glow = nil
	f:EnableMouse(false)
	f:SetScript("OnEnter", IconOnEnter)
	f:SetScript("OnLeave", IconOnLeave)
	f:Hide()
	return f
end

-- Pixel glow around a frame (DM Icon Effects glow / glow tiles): a colored
-- outer border with a pulsing alpha (5.4.8 has no engine glows).
local function EnsureGlow(f)
	local g = f.glow
	if g then
		return g
	end
	g = CreateFrame("Frame", nil, f)
	g:SetAllPoints(f)
	g:SetFrameLevel(min(f:GetFrameLevel() + 3, 127))
	g.edges = RF.CreateEdges(g, f, "OVERLAY", 7)
	local ag = g:CreateAnimationGroup()
	local a1 = ag:CreateAnimation("Alpha")
	a1:SetChange(-0.6)
	a1:SetDuration(0.5)
	a1:SetOrder(1)
	local a2 = ag:CreateAnimation("Alpha")
	a2:SetChange(0.6)
	a2:SetDuration(0.5)
	a2:SetOrder(2)
	ag:SetLooping("REPEAT")
	g.anim = ag
	g:Hide()
	f.glow = g
	return g
end

local function ShowGlow(f, on, r, gg, b, sizePx)
	if not on then
		if f.glow then
			f.glow.anim:Stop()
			f.glow:Hide()
		end
		return
	end
	local g = EnsureGlow(f)
	RF.LayoutEdges(g.edges, sizePx or 2, r or 1, gg or 0.776, b or 0.376, 1, true)
	if not g:IsShown() then
		g:Show()
		g.anim:Play()
	end
end
RF.AuraShowGlow = ShowGlow

local function ColorOf(c, dr, dg, db)
	if type(c) == "table" then
		return c.r or dr, c.g or dg, c.b or db
	end
	return dr, dg, db
end

-- Style view of a tile: the tile's own style keys shadow the debuff keys
-- (retail TILE_STYLE_KEYS).
local TILE_STYLE_KEYS = {
	iconZoom = "debuffIconZoom",
	borderSize = "debuffBorderSize", borderColor = "debuffBorderColor",
	showSwipe = "debuffShowSwipe", showDurText = "debuffShowDurText",
	durTextColor = "debuffDurTextColor", durTextSize = "debuffDurTextSize",
	durTextOffsetX = "debuffDurTextOffsetX", durTextOffsetY = "debuffDurTextOffsetY",
	showStacks = "debuffShowStacks", stacksTextColor = "debuffStacksTextColor",
	stacksTextSize = "debuffStacksTextSize",
	stacksOffsetX = "debuffStacksOffsetX", stacksOffsetY = "debuffStacksOffsetY",
	hideTooltips = "debuffHideTooltips",
}
RF.DM_TILE_STYLE_KEYS = TILE_STYLE_KEYS

function RF.DM_TileStyleView(s, t)
	local o = nil
	for tk, bk in pairs(TILE_STYLE_KEYS) do
		if t[tk] ~= nil then
			o = o or {}
			o[bk] = t[tk]
		end
	end
	if not o then
		return s
	end
	return setmetatable(o, { __index = s })
end

-- Style for the debuff icons of a settings view (prefix "debuff" or "def").
local function DebuffStyle(s)
	return {
		zoom = s.debuffIconZoom or 0.08,
		borderSize = s.debuffBorderSize or 1,
		borderColor = s.debuffBorderColor,
		swipe = s.debuffShowSwipe ~= false,
		durText = s.debuffShowDurText == true,
		durSize = s.debuffDurTextSize or 8,
		durColor = s.debuffDurTextColor,
		durX = s.debuffDurTextOffsetX or 0,
		durY = s.debuffDurTextOffsetY or 0,
		stacks = s.debuffShowStacks ~= false,
		stackSize = s.debuffStacksTextSize or 8,
		stackColor = s.debuffStacksTextColor,
		stackX = s.debuffStacksOffsetX or 0,
		stackY = s.debuffStacksOffsetY or 0,
		tips = s.debuffHideTooltips,
		tipKey = s.debuffTooltipModifier,
		dispelPx = s.dispelIconBorderSize,
		s = s,
	}
end
RF.AuraDebuffStyle = DebuffStyle

local function DefStyle(s)
	return {
		zoom = 0.08,
		borderSize = s.defBorderSize or 1,
		borderColor = s.defBorderColor,
		swipe = s.defShowSwipe ~= false,
		durText = s.defShowDurText == true,
		durSize = s.defDurTextSize or 8,
		durColor = s.defDurTextColor,
		durX = s.defDurTextOffsetX or 0,
		durY = s.defDurTextOffsetY or 0,
		stacks = false,
		tips = s.buffHideTooltips,
		s = s,
	}
end

-- Paints one icon from aura record a with style st at size.
local function PaintIcon(f, a, st, size, unit)
	f:SetSize(size, size)
	local z = st.zoom or 0.08
	f.tex:SetTexture(a.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
	f.tex:SetTexCoord(z, 1 - z, z, 1 - z)
	-- Border (physical px). A dispellable debuff recolors it in its type
	-- color at Dispel Icon Border thickness (-1 = the border's own, 0 = off).
	local bpx = st.borderSize or 1
	local r, g, b = ColorOf(st.borderColor, 0, 0, 0)
	local dpx = st.dispelPx
	if dpx == -1 then
		dpx = bpx
	end
	if a.dtype and TYPED[a.dtype] and dpx and dpx > 0 and a.harmful then
		bpx = dpx
		r, g, b = RF.GetDispelColor(a.dtype, st.s)
	end
	if a.fxBorder then
		bpx = a.fxBorder.size
		r, g, b = a.fxBorder.r, a.fxBorder.g, a.fxBorder.b
	end
	RF.LayoutEdges(f.edges, bpx, r, g, b, 1, false)
	local inset = (f.edges.size or 0)
	f.tex:ClearAllPoints()
	f.tex:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset)
	f.tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset)
	-- Swipe
	if st.swipe and a.duration and a.duration > 0 and a.expires and a.expires > 0 then
		f.cd:SetCooldown(a.expires - a.duration, a.duration)
		f.cd:Show()
	else
		f.cd:Hide()
	end
	-- Duration text
	f.expires = a.expires
	if st.durText and a.expires and a.expires > 0 then
		RF.SetIconFont(f.dur, st.durSize)
		f.dur:ClearAllPoints()
		f.dur:SetPoint("CENTER", f, "CENTER", st.durX, st.durY)
		f.dur:SetTextColor(ColorOf(st.durColor, 1, 1, 1))
		f.dur:Show()
		local rem = a.expires - GetTime()
		f.dur:SetText(rem > 0 and FormatDur(rem) or "")
		WatchDuration(f)
	else
		f.dur:SetText("")
		f.dur:Hide()
		durTexts[f.dur] = nil
	end
	-- Stacks
	if st.stacks and (a.count or 0) > 1 then
		RF.SetIconFont(f.stack, st.stackSize)
		f.stack:ClearAllPoints()
		f.stack:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", st.stackX, st.stackY)
		f.stack:SetTextColor(ColorOf(st.stackColor, 1, 1, 1))
		f.stack:SetText(a.count)
		f.stack:Show()
	else
		f.stack:SetText("")
		f.stack:Hide()
	end
	-- Glow (per-filter Icon Effects)
	if a.fxGlow then
		ShowGlow(f, true, a.fxGlow.r, a.fxGlow.g, a.fxGlow.b, 2)
	else
		ShowGlow(f, false)
	end
	-- Tooltip
	f.unit = unit
	f.auraIndex = a.index
	f.auraFilter = a.filter
	f.spellId = a.spellId
	f.tipMode = st.tips
	f.tipKey = st.tipKey
	local tipOn = not (st.tips == true or st.tips == nil)
	if tipOn and st.tips == "combat" and InCombatLockdown() then
		tipOn = false
	end
	f:EnableMouse(tipOn)
	f:Show()
end

-------------------------------------------------------------------------------
--  Flow layout (retail container flow: start corner pinned to the same
--  corner of the health area; CENTER growth centers each row)
-------------------------------------------------------------------------------
local CORNERS = RF.POS_POINT

-- Places n icons of `group` (a frame list) inside container g.box.
--   pos, grow, wrap, perRow, size, spacing, offX, offY
local function FlowLayout(box, host, icons, n, pos, grow, wrap, perRow, size, spacing, offX, offY)
	if n <= 0 then
		box:Hide()
		return
	end
	pos = pos or "bottomright"
	local corner = CORNERS[pos] or "BOTTOMRIGHT"
	grow = grow or "RIGHT"
	local step = size + spacing
	local vertical = (grow == "UP" or grow == "DOWN")
	local per = (perRow and perRow >= 2) and perRow or n
	local lines = ceil(n / per)
	local lineLen = min(n, per)
	local W, H
	if vertical then
		W = lines * size + (lines - 1) * spacing
		H = lineLen * size + (lineLen - 1) * spacing
	else
		W = lineLen * size + (lineLen - 1) * spacing
		H = lines * size + (lines - 1) * spacing
	end
	box:ClearAllPoints()
	box:SetSize(max(W, 1), max(H, 1))
	box:SetPoint(corner, host, corner, offX or 0, offY or 0)
	box:Show()
	-- Line advance direction (away from the anchored edge).
	local up
	if vertical then
		up = nil
	elseif grow == "CENTER" then
		if pos:find("top", 1, true) then
			up = false
		elseif pos:find("bottom", 1, true) then
			up = true
		else
			up = wrap ~= "DOWN"
		end
	else
		up = (wrap or "UP") ~= "DOWN"
	end
	for i = 1, n do
		local f = icons[i]
		local k = i - 1
		local line = floor(k / per)
		local cell = k % per
		f:ClearAllPoints()
		if vertical then
			-- Columns of `per` cells; columns advance sideways.
			local left = wrap ~= "LEFT"
			local x = line * step
			local y = cell * step
			local px = left and "LEFT" or "RIGHT"
			local py = (grow == "UP") and "BOTTOM" or "TOP"
			f:SetPoint(py .. px, box, py .. px, left and x or -x, (grow == "UP") and y or -y)
		elseif grow == "CENTER" then
			local inLine = min(per, n - line * per)
			local lw = inLine * size + (inLine - 1) * spacing
			local x0 = (W - lw) / 2
			local py = up and "BOTTOM" or "TOP"
			local y = line * step
			f:SetPoint(py .. "LEFT", box, py .. "LEFT", x0 + cell * step, up and y or -y)
		else
			local right = grow ~= "LEFT"
			local px = right and "LEFT" or "RIGHT"
			local py = up and "BOTTOM" or "TOP"
			local x = cell * step
			local y = line * step
			f:SetPoint(py .. px, box, py .. px, right and x or -x, up and y or -y)
		end
	end
end
RF.AuraFlowLayout = FlowLayout

-------------------------------------------------------------------------------
--  Per-button state
-------------------------------------------------------------------------------
-- Anchor host: the health area (button file's btn.rf.health), or the
-- uniform reference under Uniform Icon Anchoring (retail RF_AnchorHost).
local function HostOf(btn, s)
	if RF.AuraAnchorHost then
		local h = RF.AuraAnchorHost(btn, s)
		if h then
			return h
		end
	end
	local rf = btn.rf
	if rf and s and s.powerUniformAnchors and rf.uniformRef then
		return rf.uniformRef
	end
	return (rf and rf.health) or btn
end

local function NewGroup(btn, levelOffset)
	local g = { icons = {}, n = 0 }
	g.box = CreateFrame("Frame", nil, btn)
	g.box:SetFrameLevel(min(btn:GetFrameLevel() + (levelOffset or RF.LVL_AURA), 127))
	g.box:EnableMouse(false)
	g.box:Hide()
	return g
end

local function GroupIcon(g, i)
	local f = g.icons[i]
	if not f then
		f = NewIcon(g.box)
		f:SetFrameLevel(g.box:GetFrameLevel())
		f.textHost:SetFrameLevel(min(g.box:GetFrameLevel() + 2, 127))
		g.icons[i] = f
	end
	return f
end

local function HideFrom(g, from)
	for i = from, #g.icons do
		local f = g.icons[i]
		if f:IsShown() then
			f:Hide()
			durTexts[f.dur] = nil
			if f.glow then
				f.glow.anim:Stop()
				f.glow:Hide()
			end
		end
	end
	if from <= 1 then
		g.box:Hide()
	end
end

function RF.AuraInit(btn)
	if not btn or btn.rfAura then
		return
	end
	local d = {}
	btn.rfAura = d
	d.base = NewGroup(btn)
	d.def = NewGroup(btn)
	d.tiles = {}   -- [tileId] = group
	d.fx = {}      -- [tileId] = effect widgets
	d.scratch = {} -- reusable aura records
	d.buffs = {}
end

-- Aura record pool per button.
local function Rec(d, i)
	local a = d.scratch[i]
	if not a then
		a = { cats = {} }
		d.scratch[i] = a
	end
	a.preview = nil
	a.fxGlow = nil
	a.fxBorder = nil
	a.mine = nil
	return a
end

-------------------------------------------------------------------------------
--  Preview samples (btn.rfPreview)
-------------------------------------------------------------------------------
local PREVIEW_DEBUFFS = {
	{ name = "Polymorph", icon = "Interface\\Icons\\Spell_Nature_Polymorph", spellId = 118, duration = 8,
		cats = { cc = true, nonplayer = true } },
	{ name = "Shadow Word: Pain", icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", spellId = 589, dtype = "Magic",
		duration = 18, count = 1, cats = { raid = true, raidcombat = true, dispel = true, nonplayer = true } },
	{ name = "Boss Debuff", icon = "Interface\\Icons\\Ability_Creature_Disease_02", spellId = 143436, duration = 30,
		count = 3, cats = { boss = true, priority = true, raid = true, raidcombat = true, nonplayer = true, role = true } },
	{ name = "Curse of Elements", icon = "Interface\\Icons\\Spell_Shadow_ChillTouch", spellId = 1490, dtype = "Curse",
		duration = 20, cats = { raid = true, raidcombat = true, dispel = true, nonplayer = true } },
	{ name = "Rend", icon = "Interface\\Icons\\Ability_Gouge", spellId = 772, duration = 15,
		cats = { raid = true, raidcombat = true, nonplayer = true } },
}
local PREVIEW_DEFS = {
	{ name = "Pain Suppression", icon = "Interface\\Icons\\Spell_Holy_PainSupression", spellId = 33206, duration = 8, ext = true },
	{ name = "Barkskin", icon = "Interface\\Icons\\Spell_Nature_StoneClawTotem", spellId = 22812, duration = 12 },
}

-------------------------------------------------------------------------------
--  Scan + paint
-------------------------------------------------------------------------------
local raidSet = {}

-- One harmful scan: fills d.scratch[1..n] and returns n.
local function ScanHarmful(btn, d, unit, c)
	local n = 0
	local now = GetTime()
	local pv = btn.rfPreview
	if type(pv) == "table" then
		for i, sdef in ipairs(PREVIEW_DEBUFFS) do
			n = n + 1
			local a = Rec(d, n)
			a.index, a.filter, a.harmful = nil, "HARMFUL", true
			a.name, a.icon, a.spellId = sdef.name, sdef.icon, sdef.spellId
			a.count = sdef.count or 0
			a.dtype = sdef.dtype
			if i == 2 and pv.dispelType then
				a.dtype = pv.dispelType
			end
			a.duration = sdef.duration
			a.expires = now + sdef.duration * 0.6
			a.caster, a.isBoss, a.canApply = nil, sdef.cats.boss, false
			a.preview = sdef.cats
			a.mine = a.dtype and canDispelType[a.dtype] or false
			Categorize(a, unit, c)
		end
		return n
	end
	if not unit or not UnitExists(unit) then
		return 0
	end
	-- Dispellable-by-you set (5.4.8 "RAID" on HARMFUL).
	for k in pairs(raidSet) do
		raidSet[k] = nil
	end
	for i = 1, 40 do
		local name, _, _, _, _, _, _, _, _, _, spellId = UnitAura(unit, i, "HARMFUL|RAID")
		if not name then
			break
		end
		raidSet[spellId or name] = true
	end
	for i = 1, 40 do
		local name, _, icon, count, dtype, duration, expires, caster, _, _, spellId, canApply, isBoss = UnitAura(unit, i, "HARMFUL")
		if not name then
			break
		end
		local sated = spellId and RF.AURA_SATED[spellId]
		if not (sated and c.hideLust) then
			n = n + 1
			local a = Rec(d, n)
			a.index, a.filter, a.harmful = i, "HARMFUL", true
			a.name, a.icon, a.count, a.dtype = name, icon, count, (dtype ~= "" and dtype or nil)
			a.duration, a.expires, a.caster, a.spellId = duration, expires, caster, spellId
			a.canApply, a.isBoss = canApply, isBoss
			a.mine = raidSet[spellId or name] and true or false
			Categorize(a, unit, c)
		end
	end
	return n
end

-- First active Icon Effects block of `list` for a category, or (cats
-- table) for any category the aura has.
local function FxFor(list, cat)
	if not cat or not list then
		return nil
	end
	for i = 1, #list do
		local e = list[i]
		if RF.DM_FxActive(e) then
			if type(cat) == "table" then
				for k, on in pairs(e.filters) do
					if on and cat[k] then
						return e
					end
				end
			elseif e.filters[cat] then
				return e
			end
		end
	end
	return nil
end

-- Puts an Icon Effects block on aura a; returns the icon size.
local function ResolveSize(btn, s, raw)
	local scale = 1
	local kind = btn.rfKind
	if kind == "party" or kind == "partyPet" or kind == "partyTarget" then
		scale = RF._partyIndicatorScale or 1
	else
		scale = RF._indicatorScale or 1
		if kind == "extra" then
			scale = scale * (RF._xfExtraRatio or 1)
		end
	end
	return (tonumber(raw) or 18) * scale
end

local function FxApply(a, e, btn, s, size)
	if not e then
		return size
	end
	if (e.glowType or 0) > 0 then
		local r, g, b = e.glowR or 1, e.glowG or 0.776, e.glowB or 0.376
		if e.glowClassColor or e.glowColorMode == "class" then
			r, g, b = RF.ClassColor(playerClass)
		end
		a.fxGlow = { r = r, g = g, b = b }
	end
	if (e.borderSize or 0) > 0 then
		local bc = e.borderColor or {}
		a.fxBorder = { size = e.borderSize, r = bc.r or 0, g = bc.g or 0, b = bc.b or 0 }
	end
	if (tonumber(e.size) or 0) > 0 then
		return RF.Snap(ResolveSize(btn, s, e.size), btn)
	end
	return size
end

-- Effect tiles (glow / healthcolor / bar): additive signals.
local function PaintFx(btn, d, c, s, list, n)
	local seen = {}
	local host = HostOf(btn, s)
	for _, t in ipairs(c.fx) do
		seen[t.id] = true
		local w = d.fx[t.id]
		local hit = nil
		for i = 1, n do
			if TileTakes(t, list[i]) then
				hit = list[i]
				break
			end
		end
		if t.type == "glow" then
			if not w then
				w = { f = CreateFrame("Frame", nil, btn) }
				w.f:SetAllPoints(btn)
				w.f:SetFrameLevel(min(btn:GetFrameLevel() + 15, 127))
				w.f:EnableMouse(false)
				d.fx[t.id] = w
			end
			local cr, cg, cb = ColorOf(t.color, 1, 0.78, 0.38)
			ShowGlow(w.f, hit ~= nil and (t.glowType or 1) > 0, cr, cg, cb, 2)
		elseif t.type == "healthcolor" then
			if not w then
				w = { f = CreateFrame("Frame", nil, btn) }
				w.f:SetFrameLevel(min(btn:GetFrameLevel() + 2, 127))
				w.tex = w.f:CreateTexture(nil, "ARTWORK", nil, 2)
				w.tex:SetAllPoints(w.f)
				w.f:EnableMouse(false)
				d.fx[t.id] = w
			end
			w.f:ClearAllPoints()
			w.f:SetAllPoints(host)
			local cr, cg, cb = ColorOf(t.color, 1, 0.25, 0.25)
			w.tex:SetTexture(cr, cg, cb, (t.opacity or 45) / 100)
			if hit then
				w.f:Show()
			else
				w.f:Hide()
			end
		elseif t.type == "bar" then
			if not w then
				local sb = CreateFrame("StatusBar", nil, btn)
				sb:SetStatusBarTexture(RF.WHITE)
				sb:SetMinMaxValues(0, 1)
				sb.bg = sb:CreateTexture(nil, "BACKGROUND")
				sb.bg:SetAllPoints(sb)
				sb:SetScript("OnUpdate", function(self)
					local a = self.aura
					if a and a.duration and a.duration > 0 then
						self:SetValue(max(0, (a.expires - GetTime()) / a.duration))
					else
						self:SetValue(1)
					end
				end)
				sb:EnableMouse(false)
				w = { f = sb }
				d.fx[t.id] = w
			end
			local sb = w.f
			local lvl = { behindBorders = 7, behindText = 11, medium = 13, high = 14, highest = 15 }
			sb:SetFrameLevel(min(btn:GetFrameLevel() + (lvl[t.frameLevel or "behindBorders"] or 7), 127))
			sb:SetOrientation(t.orientation == "VERTICAL" and "VERTICAL" or "HORIZONTAL")
			local vert = t.orientation == "VERTICAL"
			local len, thick = t.width or 60, t.height or 5
			if t.barFullWidth then
				len = vert and host:GetHeight() or host:GetWidth()
			end
			if t.barFullHeight then
				thick = vert and host:GetWidth() or host:GetHeight()
			end
			if vert then
				sb:SetSize(thick, len)
			else
				sb:SetSize(len, thick)
			end
			sb:SetReverseFill(t.reverseFill and true or false)
			local corner = CORNERS[t.position or "bottom"] or "BOTTOM"
			sb:ClearAllPoints()
			sb:SetPoint(corner, host, corner, t.offsetX or 0, t.offsetY or 0)
			local cr, cg, cb = ColorOf(t.color, 0.25, 0.8, 0.45)
			sb:SetStatusBarColor(cr, cg, cb, (t.barColorOpacity or 100) / 100)
			local br, bg, bb = ColorOf(t.barBgColor, 0, 0, 0)
			sb.bg:SetTexture(br, bg, bb, (t.barBgOpacity or 50) / 100)
			if hit then
				sb.aura = { duration = hit.duration, expires = hit.expires }
				sb:Show()
			else
				sb.aura = nil
				sb:Hide()
			end
		end
	end
	for id, w in pairs(d.fx) do
		if not seen[id] then
			if w.f.glow then
				ShowGlow(w.f, false)
			end
			w.f:Hide()
		end
	end
end

-- Debuffs: base row + grid tiles + effects. Returns the dispel candidate.
local function PaintDebuffs(btn, d, unit, s, c)
	local n = ScanHarmful(btn, d, unit, c)
	local list
	list, n = ns.FilterDuplicateDiseases(d.scratch, n)
	local host = HostOf(btn, s)
	local cap = s.debuffCap or 3
	-- Assign each aura: tile claim first, else the base row.
	local tileOf = {}
	local baseList, baseOwner = {}, {}
	for i = 1, n do
		local a = list[i]
		local taken = nil
		for _, t in ipairs(c.grid) do
			if TileTakes(t, a) then
				-- A claimed category (or a match-all/catch-all tile) owns the aura.
				taken = t
				break
			end
		end
		if taken then
			local l = tileOf[taken.id]
			if not l then
				l = {}
				tileOf[taken.id] = l
			end
			l[#l + 1] = a
		else
			local own = BaseTakes(a, c)
			if own then
				baseList[#baseList + 1] = a
				baseOwner[a] = own
			end
		end
	end
	-- Base row: owner groups in ownership order, each up to the cap (retail
	-- one group per record, cap per group; crowd control leads).
	local order = {}
	local perOwner = {}
	for _, a in ipairs(baseList) do
		local own = baseOwner[a]
		local k = perOwner[own] or 0
		if k < cap then
			perOwner[own] = k + 1
			order[#order + 1] = a
		end
	end
	table.sort(order, function(x, y)
		local rx = OWN_RANK[baseOwner[x]] or 99
		local ry = OWN_RANK[baseOwner[y]] or 99
		if rx ~= ry then
			return rx < ry
		end
		return (x.index or 0) < (y.index or 0)
	end)
	local st = DebuffStyle(s)
	local baseSize = RF.Snap(s.debuffSize or 18, btn)
	local g = d.base
	local shown = 0
	for i = 1, #order do
		local a = order[i]
		local own = baseOwner[a]
		local e = (own ~= "all") and FxFor(c.fxList, own) or nil
		local size = FxApply(a, e, btn, s, baseSize)
		shown = shown + 1
		PaintIcon(GroupIcon(g, shown), a, st, size, unit)
	end
	HideFrom(g, shown + 1)
	FlowLayout(g.box, host, g.icons, shown, s.debuffPosition or "bottomright", s.debuffGrowDirection or "LEFT",
		s.debuffWrapDirection or "UP", s.debuffPerRow or 5, baseSize, s.debuffSpacing or 1,
		s.debuffOffsetX or 0, s.debuffOffsetY or 0)
	-- Grid tiles.
	local seen = {}
	for _, t in ipairs(c.grid) do
		seen[t.id] = true
		local tg = d.tiles[t.id]
		if not tg then
			tg = NewGroup(btn)
			d.tiles[t.id] = tg
		end
		local l = tileOf[t.id] or {}
		local tcap = t.cap or 3
		local tsize = RF.Snap(ResolveSize(btn, s, t.size or 18), btn)
		local tst = DebuffStyle(RF.DM_TileStyleView(s, t))
		local k = 0
		for i = 1, min(#l, tcap) do
			k = k + 1
			local f = GroupIcon(tg, k)
			local a = l[i]
			local isz = FxApply(a, FxFor(t.fxList, a.cats), btn, s, tsize)
			PaintIcon(f, a, tst, isz, unit)
			if t.type == "square" then
				local cr, cg, cb = ColorOf(t.color, 1, 0.35, 0.35)
				f.tex:SetTexture(cr, cg, cb, (t.color and t.color.a) or 1)
				f.tex:SetTexCoord(0, 1, 0, 1)
				f.cd:Hide()
				f.dur:Hide()
				f.stack:Hide()
			end
		end
		HideFrom(tg, k + 1)
		local per = tonumber(t.iconsPerRow) or 0
		local pos = t.position or "top"
		local grow = t.growDirection or "CENTER"
		local wrap
		if grow == "UP" or grow == "DOWN" then
			wrap = pos:find("right", 1, true) and "LEFT" or "RIGHT"
		else
			wrap = (per >= 2 and pos:find("bottom", 1, true)) and "UP" or "DOWN"
		end
		FlowLayout(tg.box, host, tg.icons, k, pos, grow, wrap, per, tsize, t.spacing or 1, t.offsetX or 0, t.offsetY or 0)
	end
	for id, tg in pairs(d.tiles) do
		if not seen[id] then
			HideFrom(tg, 1)
		end
	end
	PaintFx(btn, d, c, s, list, n)
	-- Dispel candidate: first debuff with a dispel type.
	local pick = nil
	for i = 1, n do
		local a = list[i]
		if a.dtype and TYPED[a.dtype] then
			local can = a.mine or canDispelType[a.dtype] or false
			if can or s.dispelShowAll ~= false then
				if not pick or (can and not pick.can) then
					pick = pick or {}
					pick.type, pick.can, pick.icon, pick.spellId = a.dtype, can, a.icon, a.spellId
					if can then
						break
					end
				end
			end
		end
	end
	return pick
end

-- Defensives & Externals (retail legacy def* keys).
local function PaintDefensives(btn, d, unit, s, c)
	local g = d.def
	local wantDef = s.showDefensives ~= false
	local wantExt = s.showExternals ~= false
	if (not wantDef and not wantExt) or c.bmOwnsDef then
		HideFrom(g, 1)
		return
	end
	local list = d.buffs
	local n = 0
	local now = GetTime()
	if type(btn.rfPreview) == "table" then
		for _, sdef in ipairs(PREVIEW_DEFS) do
			if (sdef.ext and wantExt) or (not sdef.ext and wantDef) then
				n = n + 1
				local a = list[n] or { cats = {} }
				list[n] = a
				a.name, a.icon, a.spellId, a.count = sdef.name, sdef.icon, sdef.spellId, 0
				a.duration, a.expires = sdef.duration, now + sdef.duration * 0.6
				a.index, a.filter, a.dtype, a.harmful = nil, "HELPFUL", nil, false
			end
		end
	elseif unit and UnitExists(unit) then
		for i = 1, 40 do
			local name, _, icon, count, _, duration, expires, caster, _, _, spellId = UnitAura(unit, i, "HELPFUL")
			if not name then
				break
			end
			local ok = false
			if spellId and RF.AURA_EXTERNALS[spellId] and wantExt then
				ok = true
			elseif spellId and RF.AURA_DEFENSIVES[spellId] and wantDef then
				ok = true
			end
			if ok then
				n = n + 1
				local a = list[n] or { cats = {} }
				list[n] = a
				a.name, a.icon, a.spellId, a.count = name, icon, spellId, count
				a.duration, a.expires = duration, expires
				a.index, a.filter, a.dtype, a.harmful = i, "HELPFUL", nil, false
				a.fxGlow, a.fxBorder = nil, nil
				if n >= 4 then
					break
				end
			end
		end
	end
	local size = RF.Snap(s.defSize or 22, btn)
	local st = DefStyle(s)
	for i = 1, n do
		PaintIcon(GroupIcon(g, i), list[i], st, size, unit)
	end
	HideFrom(g, n + 1)
	FlowLayout(g.box, HostOf(btn, s), g.icons, n, s.defPosition or "center", s.defGrowDirection or "CENTER",
		"UP", 0, size, s.defSpacing or 1, s.defOffsetX or 0, s.defOffsetY or 0)
end

local function SameDispel(a, b)
	if a == nil or b == nil then
		return a == b
	end
	return a.type == b.type and a.canDispel == b.canDispel and a.spellId == b.spellId and a.icon == b.icon
end

function RF.AuraUpdate(btn)
	if not btn then
		return
	end
	if not btn.rfAura then
		RF.AuraInit(btn)
	end
	local d = btn.rfAura
	local unit = RF.UnitOf and RF.UnitOf(btn) or btn.unit or (btn.GetAttribute and btn:GetAttribute("unit"))
	local s = RF.SettingsFor(btn)
	if not s or not RF.Profile() then
		return
	end
	local c = Cfg()
	local hasUnit = type(btn.rfPreview) == "table" or (unit and UnitExists(unit))
	local pick = nil
	if hasUnit then
		pick = PaintDebuffs(btn, d, unit, s, c)
		PaintDefensives(btn, d, unit, s, c)
	else
		HideFrom(d.base, 1)
		HideFrom(d.def, 1)
		for _, tg in pairs(d.tiles) do
			HideFrom(tg, 1)
		end
		for _, w in pairs(d.fx) do
			if w.f.glow then
				ShowGlow(w.f, false)
			end
			w.f:Hide()
		end
	end
	-- btn.rfDispel (contract with the button file).
	local nd = nil
	if pick then
		nd = { type = pick.type, canDispel = pick.can and true or false, icon = pick.icon, spellId = pick.spellId }
	elseif type(btn.rfPreview) == "table" and btn.rfPreview.dispelType then
		local t = btn.rfPreview.dispelType
		nd = { type = t, canDispel = canDispelType[t] or false, icon = nil, spellId = nil }
	end
	if not SameDispel(btn.rfDispel, nd) then
		btn.rfDispel = nd
		if RF.UpdateDispelVisuals then
			RF.UpdateDispelVisuals(btn)
		end
	end
end

function RF.AuraRelayout(btn)
	RF.AuraUpdate(btn)
end

-------------------------------------------------------------------------------
--  Events
-------------------------------------------------------------------------------
local function UpdateAll()
	if RF.ForEachButton then
		RF.ForEachButton(function(btn)
			RF.AuraUpdate(btn)
		end)
	end
end
RF.AuraUpdateAll = UpdateAll

local ev = CreateFrame("Frame")
ev:RegisterEvent("UNIT_AURA")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ev:RegisterEvent("PLAYER_TALENT_UPDATE")
ev:RegisterEvent("SPELLS_CHANGED")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
local pendingAll = false
local function QueueAll()
	if pendingAll then
		return
	end
	pendingAll = true
	RF.After(0.1, function()
		pendingAll = false
		BuildCfg()
		UpdateAll()
	end)
end
ev:SetScript("OnEvent", function(_, event, unit)
	if not ERF.started then
		if event ~= "UNIT_AURA" then
			RefreshDispelTypes()
		end
		return
	end
	if event == "UNIT_AURA" then
		if not unit or not RF.ButtonsForUnit then
			return
		end
		for btn in pairs(RF.ButtonsForUnit(unit)) do
			RF.AuraUpdate(btn)
		end
	elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
		-- Tooltips hidden in combat + raid / raid-in-combat visibility.
		QueueAll()
	else
		if event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then
			return
		end
		RefreshDispelTypes()
		QueueAll()
	end
end)

RefreshDispelTypes()

-- Settings changes: rebuild the config, repaint every button.
RF.OnApply(function()
	BuildCfg()
	UpdateAll()
end, 30)
