-------------------------------------------------------------------------------
--  EllesmereUIBISTracker.lua (BIS Tracker, new module for the 5.4.8 port)
--
--  Pick the items you want from the Mists of Pandaria raid bosses: for each
--  item the difficulties you want it from (LFR / Flex / Normal / Heroic) and,
--  in Throne of Thunder and Siege of Orgrimmar, whether only the Warforged
--  (Thunderforged) version counts. The next time you kill that boss on one of
--  those difficulties, a list pops up with the items you are after.
--
--  Loot data: the game's Encounter Journal (EJ_* API, client data; item names
--  come from the item cache and can arrive a moment later). Picking happens
--  on the settings page (EllesmereUIOptions\EUI_BISTracker_Options.lua).
--  Kill detection: ENCOUNTER_END (success), matched to the saved boss by name.
--
--  Saved data:
--    EllesmereUIBISTrackerDB      popup settings (account)
--    EllesmereUIBISTrackerCharDB  the wanted items (per character)
--      bosses[ejEncounterID] = { name, raid, raidID,
--        items = { [itemName] = { icon, slot, armor, quality,
--          diffs = { [diffKey] = { base = bool, wf = bool, itemID, link } } } } }
--      base = the normal version wanted, wf = the Warforged / Thunderforged
--      version wanted (either one or both).
-------------------------------------------------------------------------------
local addonName = ...
local ns = EllesmereUI

local BIS = {}
ns.BIS = BIS

local floor, max, min = math.floor, math.max, math.min
local pairs, ipairs, type, tostring = pairs, ipairs, type, tostring

-------------------------------------------------------------------------------
--  Difficulties
-------------------------------------------------------------------------------
-- ej = the Encounter Journal difficulty ID used to read the loot (10 and 25
-- player raids share their loot in Mists, so the 10 player IDs are enough).
BIS.DIFFS = {
	{ key = "lfr", text = "LFR", long = "Raid Finder", ej = 7 },
	{ key = "flex", text = "Flex", long = "Flexible", ej = 14 },
	{ key = "normal", text = "Normal", long = "Normal", ej = 3 },
	{ key = "heroic", text = "Heroic", long = "Heroic", ej = 5 },
}
local DIFF_BY_KEY = {}
for _, d in ipairs(BIS.DIFFS) do
	DIFF_BY_KEY[d.key] = d
end
BIS.DIFF_BY_KEY = DIFF_BY_KEY

-- Instance / encounter difficulty IDs -> our keys.
local DIFF_BY_ID = { [3] = "normal", [4] = "normal", [5] = "heroic", [6] = "heroic", [7] = "lfr", [14] = "flex" }

-- Encounter Journal instance IDs of the Mists raids.
local RAID_MSV, RAID_HOF, RAID_TOES, RAID_TOT, RAID_SOO = 317, 330, 320, 362, 369
-- Raids with Warforged (Siege of Orgrimmar) / Thunderforged (Throne of Thunder) items.
-- Release order: Mogu'shan Vaults, Heart of Fear, Terrace of Endless Spring
-- (5.0), Throne of Thunder (5.2), Siege of Orgrimmar (5.4); world bosses last.
local RELEASE = { [RAID_MSV] = 1, [RAID_HOF] = 2, [RAID_TOES] = 3, [RAID_TOT] = 4, [RAID_SOO] = 5, [322] = 50 }
local FORGED = { [RAID_TOT] = "Thunderforged", [RAID_SOO] = "Warforged" }

-------------------------------------------------------------------------------
--  Saved data
-------------------------------------------------------------------------------
local DEFAULTS = {
	popup = true,      -- show the list when you kill a boss
	chat = true,       -- also print it to chat
	lootGlow = true,   -- glow wanted items in the loot roll and loot windows
	autoHide = 0,      -- seconds, 0 = stays until closed
	scale = 1,
	alpha = 1,
	selRaid = nil,     -- settings page: selected raid / boss
	selBoss = nil,
	pos = nil,         -- { point, x, y }
}

local db, cdb

function BIS.DB()
	if not db then
		db = ns.ModuleDB("EllesmereUIBISTrackerDB")
		ns.CopyDefaults(DEFAULTS, db)
	end
	return db
end

function BIS.CharDB()
	if not cdb then
		if type(EllesmereUIBISTrackerCharDB) ~= "table" then
			EllesmereUIBISTrackerCharDB = {}
		end
		cdb = EllesmereUIBISTrackerCharDB
		if type(cdb.bosses) ~= "table" then
			cdb.bosses = {}
		end
	end
	return cdb
end

-- Bumped on every change of the wanted items (settings pages rebuild on it).
local listVersion = 0
function BIS.ListVersion()
	return listVersion
end
local function ListChanged()
	listVersion = listVersion + 1
	if BIS.OnListChanged then
		BIS.OnListChanged()
	end
end

-------------------------------------------------------------------------------
--  Encounter Journal access
-------------------------------------------------------------------------------
local function HasEJ()
	return type(EJ_GetInstanceByIndex) == "function" and type(EJ_SelectInstance) == "function"
		and type(EJ_GetEncounterInfoByIndex) == "function" and type(EJ_GetNumLoot) == "function"
		and type(EJ_GetLootInfoByIndex) == "function"
end
BIS.HasEJ = HasEJ

-- Runs fn with the journal state saved and put back afterwards, so the
-- Blizzard Dungeon Journal opens as it was: tier, instance and encounter it
-- shows (EncounterJournal.instanceID / encounterID), difficulty, class filter.
-- The difficulty must fit the instance: a 5 player difficulty on a raid
-- shows an empty boss list, so a raid gets a raid difficulty.
local RAID_DIFF_FALLBACK = { 3, 4, 5, 6, 7, 14 }

local function RestoreEJ(tier, diff, class, spec)
	if tier and EJ_SelectTier then
		pcall(EJ_SelectTier, tier)
	end
	local ej = EncounterJournal
	if ej and ej.instanceID then
		pcall(EJ_SelectInstance, ej.instanceID)
		if ej.encounterID then
			pcall(EJ_SelectEncounter, ej.encounterID)
		end
	end
	if EJ_SetDifficulty then
		local valid = function(d)
			if not EJ_IsValidInstanceDifficulty then
				return true
			end
			local ok, v = pcall(EJ_IsValidInstanceDifficulty, d)
			return ok and v
		end
		if diff and valid(diff) then
			pcall(EJ_SetDifficulty, diff)
		else
			for _, d in ipairs(RAID_DIFF_FALLBACK) do
				if valid(d) then
					pcall(EJ_SetDifficulty, d)
					break
				end
			end
		end
	end
	if class and EJ_SetLootFilter then
		pcall(EJ_SetLootFilter, class, spec or 0)
	end
end

local function WithEJ(fn, ...)
	local oldTier = EJ_GetCurrentTier and EJ_GetCurrentTier()
	local oldDiff = EJ_GetDifficulty and EJ_GetDifficulty()
	local oldClass, oldSpec
	if EJ_GetLootFilter then
		oldClass, oldSpec = EJ_GetLootFilter()
	end
	local ok, a, b = pcall(fn, ...)
	RestoreEJ(oldTier, oldDiff, oldClass, oldSpec)
	if not ok then
		BIS.lastError = a
		return nil
	end
	return a, b
end

local function SelectCurrentTier()
	if EJ_GetNumTiers and EJ_SelectTier then
		local n = EJ_GetNumTiers()
		if n and n > 0 then
			EJ_SelectTier(n)
		end
	end
end

local raidCache
-- { { id, name }, ... } of the raids of the current expansion.
function BIS.GetRaids()
	if raidCache then
		return raidCache
	end
	if not HasEJ() then
		return {}
	end
	local list = WithEJ(function()
		SelectCurrentTier()
		local out = {}
		for i = 1, 30 do
			local id, name = EJ_GetInstanceByIndex(i, true)
			if not id then
				break
			end
			out[#out + 1] = { id = id, name = name }
		end
		return out
	end) or {}
	-- Release order (the journal lists them its own way); others go last.
	for i, r in ipairs(list) do
		r.journalIndex = i
	end
	table.sort(list, function(a, b)
		local ra, rb = RELEASE[a.id] or 100, RELEASE[b.id] or 100
		if ra ~= rb then
			return ra < rb
		end
		return a.journalIndex < b.journalIndex
	end)
	if #list > 0 then
		raidCache = list
	end
	return list
end

function BIS.RaidName(raidID)
	for _, r in ipairs(BIS.GetRaids()) do
		if r.id == raidID then
			return r.name
		end
	end
	return nil
end

BIS.RAID_SOO = RAID_SOO

function BIS.ForgedName(raidID)
	return FORGED[raidID]
end

local bossCache = {}
-- { { id, name }, ... } of the bosses of a raid.
function BIS.GetBosses(raidID)
	if not raidID then
		return {}
	end
	if bossCache[raidID] then
		return bossCache[raidID]
	end
	if not HasEJ() then
		return {}
	end
	local list = WithEJ(function()
		SelectCurrentTier()
		EJ_SelectInstance(raidID)
		local out = {}
		for i = 1, 30 do
			local name, _, encID = EJ_GetEncounterInfoByIndex(i, raidID)
			if not encID then
				break
			end
			out[#out + 1] = { id = encID, name = name }
		end
		return out
	end) or {}
	if #list > 0 then
		bossCache[raidID] = list
	end
	return list
end

function BIS.BossName(raidID, bossID)
	for _, b in ipairs(BIS.GetBosses(raidID)) do
		if b.id == bossID then
			return b.name
		end
	end
	return nil
end

local diffCache = {}
-- Difficulty keys a raid has (journal check; fallback: Flex only in Siege).
function BIS.GetDifficulties(raidID)
	if diffCache[raidID] then
		return diffCache[raidID]
	end
	local out = {}
	local checked = HasEJ() and EJ_IsValidInstanceDifficulty and WithEJ(function()
		EJ_SelectInstance(raidID)
		local r = {}
		for _, d in ipairs(BIS.DIFFS) do
			if EJ_IsValidInstanceDifficulty(d.ej) then
				r[#r + 1] = d.key
			end
		end
		return r
	end)
	if checked and #checked > 0 then
		out = checked
	else
		for _, d in ipairs(BIS.DIFFS) do
			if d.key ~= "flex" or raidID == RAID_SOO then
				out[#out + 1] = d.key
			end
		end
	end
	diffCache[raidID] = out
	return out
end

local function QualityOf(link, itemID)
	if itemID and GetItemInfo then
		local _, _, q = GetItemInfo(itemID)
		if q then
			return q
		end
	end
	return 4
end

local lootCache = {}
local emptySince = {} -- bossID -> GetTime() of the first empty answer
local LOOT_WAIT = 8   -- seconds of empty answers before "no loot"

-- Number of loot rows of the selected encounter on a difficulty, with a
-- class filter (0 = all classes). The encounter is selected again after the
-- difficulty and filter, so the list is rebuilt for them.
local function ReadLoot(raidID, bossID, ej, classID, specID)
	-- The filter is set before and after selecting: depending on the client
	-- the loot list is made when the encounter is selected or when the
	-- filter changes, and a list made with the old filter must not be read.
	if EJ_SetLootFilter then
		EJ_SetLootFilter(classID, specID or 0)
	end
	EJ_SelectInstance(raidID)
	if EJ_SetDifficulty then
		EJ_SetDifficulty(ej)
	end
	EJ_SelectEncounter(bossID)
	if EJ_SetLootFilter then
		EJ_SetLootFilter(classID, specID or 0)
	end
	local n = EJ_GetNumLoot() or 0
	if n == 0 then
		EJ_SelectEncounter(bossID)
		n = EJ_GetNumLoot() or 0
	end
	return n
end

local NUM_CLASSES = 11
-- The "all classes" filter gave loot once: no need for the slow per class
-- fallback (an empty answer then only means the data is still loading).
local allClassesWorks = false

-- Weapons each class can use in Mists (journal type names, English client).
-- one = one-handed only, any = one- and two-handed. Ranged weapons: hunters;
-- wands: priests, mages, warlocks.
local WEAPONS = {
	[1] = { Axe = "any", Mace = "any", Sword = "any", Polearm = "any", Staff = "any", Dagger = "any", ["Fist Weapon"] = "any", Shield = "any" },
	[2] = { Axe = "any", Mace = "any", Sword = "any", Polearm = "any", Shield = "any" },
	[3] = { Axe = "any", Sword = "any", Polearm = "any", Staff = "any", Dagger = "any", ["Fist Weapon"] = "any", Bow = "any", Gun = "any", Crossbow = "any" },
	[4] = { Dagger = "any", ["Fist Weapon"] = "any", Axe = "one", Mace = "one", Sword = "one" },
	[5] = { Dagger = "any", Mace = "one", Staff = "any", Wand = "any" },
	[6] = { Axe = "any", Mace = "any", Sword = "any", Polearm = "any" },
	[7] = { Axe = "any", Mace = "any", Dagger = "any", ["Fist Weapon"] = "any", Staff = "any", Shield = "any" },
	[8] = { Dagger = "any", Sword = "one", Staff = "any", Wand = "any" },
	[9] = { Dagger = "any", Sword = "one", Staff = "any", Wand = "any" },
	[10] = { ["Fist Weapon"] = "any", Axe = "one", Mace = "one", Sword = "one", Polearm = "any", Staff = "any" },
	[11] = { Dagger = "any", ["Fist Weapon"] = "any", Mace = "any", Polearm = "any", Staff = "any" },
}
-- Specs that use a shield: Protection Warrior, Holy / Protection Paladin,
-- Elemental / Restoration Shaman.
local SHIELD_SPECS = { [73] = true, [65] = true, [66] = true, [262] = true, [264] = true }
local ALL_WEAPON_TYPES = {
	Axe = true, Mace = true, Sword = true, Polearm = true, Staff = true, Dagger = true,
	["Fist Weapon"] = true, Bow = true, Gun = true, Crossbow = true, Wand = true, Shield = true,
}

local function StripColor(text)
	return (tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- Can a class (and spec, 0 = any) use an item with this journal slot and
-- type text? Only weapons and shields are checked (the journal filter
-- already handles armor); unknown types count as usable.
function BIS.UsableBy(classID, specID, slot, armor)
	local kind = StripColor(armor)
	if not ALL_WEAPON_TYPES[kind] then
		return true
	end
	local allowed = WEAPONS[classID]
	if not allowed then
		return true
	end
	local rule = allowed[kind]
	if not rule then
		return false
	end
	if rule == "one" and StripColor(slot) == "Two-Hand" then
		return false
	end
	if kind == "Shield" and specID and specID > 0 and not SHIELD_SPECS[specID] then
		return false
	end
	return true
end

-- Loot filter of the settings page: class ID (0 = all classes) and spec ID
-- (0 = all specs of the class), like the Dungeon Journal's filter.
function BIS.GetFilter()
	local cfg = BIS.DB()
	return tonumber(cfg.filterClass) or 0, tonumber(cfg.filterSpec) or 0
end

function BIS.SetFilter(classID, specID)
	local cfg = BIS.DB()
	cfg.filterClass, cfg.filterSpec = classID or 0, specID or 0
end

-- { { name, value = "class:spec" } } for the filter dropdown.
function BIS.FilterItems()
	local items = { { name = "All Classes", value = "0:0" } }
	if not GetClassInfo then
		return items
	end
	for classID = 1, NUM_CLASSES do
		local className, classFile = GetClassInfo(classID)
		if className then
			local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
			local hex = c and string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255) or ""
			items[#items + 1] = { name = hex .. className .. (hex ~= "" and "|r" or "") .. "  (all specs)", value = classID .. ":0" }
			local n = GetNumSpecializationsForClassID and GetNumSpecializationsForClassID(classID) or 0
			for i = 1, n do
				local specID, specName = GetSpecializationInfoForClassID(classID, i)
				if specID then
					items[#items + 1] = { name = hex .. className .. (hex ~= "" and "|r" or "") .. ": " .. specName, value = classID .. ":" .. specID }
				end
			end
		end
	end
	return items
end

function BIS.FilterLabel()
	local c, sp = BIS.GetFilter()
	local v = c .. ":" .. sp
	for _, it in ipairs(BIS.FilterItems()) do
		if it.value == v then
			return it.name
		end
	end
	return "All Classes"
end -- Mists: warrior .. druid (monk = 10)

-- Items of a boss, one entry per item name (the item IDs differ by
-- difficulty): { { name, icon, slot, armor, quality,
--   byDiff = { [diffKey] = { itemID, link } } } }, state
-- state: "ok" (all names known), "loading" (still waiting) or "empty".
function BIS.GetLoot(raidID, bossID)
	if not raidID or not bossID then
		return {}, "empty"
	end
	local fClass, fSpec = BIS.GetFilter()
	local cacheKey = bossID .. ":" .. fClass .. ":" .. fSpec
	local cached = lootCache[cacheKey]
	if cached and cached.state == "ok" then
		return cached.items, "ok"
	end
	if not HasEJ() then
		return {}, "empty"
	end
	local diffs = BIS.GetDifficulties(raidID)
	local items, done = WithEJ(function()
		SelectCurrentTier()
		local byName, order, done = {}, {}, true
		local function Collect(key)
			for i = 1, EJ_GetNumLoot() or 0 do
				local name, icon, slot, armor, itemID, link = EJ_GetLootInfoByIndex(i)
				if type(itemID) ~= "number" and type(link) == "string" then
					itemID = tonumber(link:match("item:(%d+)"))
				end
				if not name or name == "" then
					done = false
					if itemID and GetItemInfo then
						GetItemInfo(itemID) -- asks the server; the name arrives later
					end
				else
					local e = byName[name]
					if not e then
						e = { name = name, icon = icon, slot = slot, armor = armor, byDiff = {}, bossID = bossID }
						byName[name] = e
						order[#order + 1] = e
					end
					if not e.byDiff[key] then
						e.byDiff[key] = { itemID = itemID, link = link }
					end
					if not e.quality or e.quality < 4 then
						e.quality = QualityOf(link, itemID)
					end
				end
			end
		end
		for _, key in ipairs(diffs) do
			local d = DIFF_BY_KEY[key]
			if fClass > 0 then
				-- Class / spec filter (as in the Dungeon Journal).
				if ReadLoot(raidID, bossID, d.ej, fClass, fSpec) > 0 then
					Collect(key)
				end
			elseif ReadLoot(raidID, bossID, d.ej, 0) > 0 then
				allClassesWorks = true
				Collect(key)
			elseif not allClassesWorks then
				-- Some clients only list loot for one class at a time:
				-- go through every class.
				for classID = 1, NUM_CLASSES do
					if ReadLoot(raidID, bossID, d.ej, classID) > 0 then
						Collect(key)
					end
				end
			end
		end
		if fClass > 0 then
			-- The journal's filter lets some items through for every class
			-- (Garrosh's Hellscream weapons): drop weapons the class cannot use.
			local kept = {}
			for _, e in ipairs(order) do
				if BIS.UsableBy(fClass, fSpec, e.slot, e.armor) then
					kept[#kept + 1] = e
				end
			end
			order = kept
		end
		return order, done
	end)
	items = items or {}
	local state = "ok"
	if done and #items > 0 then
		emptySince[cacheKey] = nil
	else
		-- Waiting for the journal / item names; give up after LOOT_WAIT.
		local now = GetTime()
		emptySince[cacheKey] = emptySince[cacheKey] or now
		if now - emptySince[cacheKey] < LOOT_WAIT then
			state = "loading"
		elseif #items == 0 then
			state = "empty"
		else
			state = "partial"
		end
	end
	lootCache[cacheKey] = { items = items, state = state }
	return items, state
end

-- State of the last loot read of a boss ("ok", "loading", ...) or nil.
function BIS.LootState(bossID, raidID)
	if bossID == 0 then
		-- All bosses: loading while any boss is.
		local state = "ok"
		for _, b in ipairs(BIS.GetBosses(raidID)) do
			local st = BIS.LootState(b.id)
			if st == nil or st == "loading" then
				return "loading"
			end
		end
		return state
	end
	local fClass, fSpec = BIS.GetFilter()
	local cached = lootCache[bossID .. ":" .. fClass .. ":" .. fSpec]
	return cached and cached.state
end

-- Loot of every boss of a raid, in boss order (items carry bossID).
-- state: "loading" while any boss is, "empty" when none has loot, else "ok".
function BIS.GetRaidLoot(raidID)
	local all, loading = {}, false
	for _, b in ipairs(BIS.GetBosses(raidID)) do
		local items, st = BIS.GetLoot(raidID, b.id)
		if st == "loading" then
			loading = true
		end
		for _, it in ipairs(items) do
			it.bossName = b.name
			all[#all + 1] = it
		end
	end
	if loading then
		return all, "loading"
	end
	return all, #all > 0 and "ok" or "empty"
end

function BIS.ForgetLoot()
	wipe(lootCache)
	wipe(emptySince)
end

-------------------------------------------------------------------------------
--  Wanted items
-------------------------------------------------------------------------------
local function BossEntry(bossID, create, raidID)
	local bosses = BIS.CharDB().bosses
	local b = bosses[bossID]
	if not b and create then
		b = {
			name = BIS.BossName(raidID, bossID) or ("Boss " .. tostring(bossID)),
			raid = BIS.RaidName(raidID) or "",
			raidID = raidID,
			items = {},
		}
		bosses[bossID] = b
	end
	return b
end

-- Saved before "base" existed: wf = true meant "Warforged only".
local function Migrate(d)
	if d and d.base == nil then
		d.base = not d.wf
		d.wf = d.wf and true or false
	end
	return d
end

-- Is the item wanted on that difficulty? Returns the saved diff table
-- ({ base, wf, itemID, link }) or nil.
function BIS.GetWish(bossID, itemName, diffKey)
	local b = BIS.CharDB().bosses[bossID]
	local it = b and b.items[itemName]
	return it and Migrate(it.diffs[diffKey])
end

-- Text for what is wanted: "" (normal version), "Warforged only",
-- "+ Warforged" (both versions).
function BIS.VersionText(base, wf, raidID)
	if not wf then
		return ""
	end
	local forged = FORGED[raidID] or "Warforged"
	return base and ("+ " .. forged) or (forged .. " only")
end

local function Cleanup(bossID)
	local bosses = BIS.CharDB().bosses
	local b = bosses[bossID]
	if not b then
		return
	end
	for name, it in pairs(b.items) do
		if not next(it.diffs) then
			b.items[name] = nil
		end
	end
	if not next(b.items) then
		bosses[bossID] = nil
	end
end

-- item = an entry of BIS.GetLoot. field = "base" (the normal version) or
-- "wf" (the Warforged / Thunderforged version); on = want it or not.
function BIS.SetWant(raidID, bossID, item, diffKey, field, on)
	local b = BossEntry(bossID, on, raidID)
	if not b then
		return
	end
	local it = b.items[item.name]
	if not it and on then
		it = { diffs = {} }
		b.items[item.name] = it
	end
	if it then
		local d = Migrate(it.diffs[diffKey]) or { base = false, wf = false }
		d[field] = on and true or false
		if d.base or d.wf then
			it.icon, it.slot, it.armor, it.quality = item.icon, item.slot, item.armor, item.quality
			local src = item.byDiff[diffKey] or {}
			d.itemID, d.link = src.itemID or d.itemID, src.link or d.link
			it.diffs[diffKey] = d
		else
			it.diffs[diffKey] = nil
		end
	end
	Cleanup(bossID)
	ListChanged()
end

-- An item dropped. forged: it was the Warforged / Thunderforged version.
-- The normal version clears only the normal wants of the item and keeps
-- the Warforged ones; the Warforged version clears the whole item.
-- Returns true when the item is off the list.
function BIS.GotItem(bossID, itemName, forged)
	local b = BIS.CharDB().bosses[bossID]
	local it = b and b.items[itemName]
	if not it then
		return true
	end
	if not forged then
		local keep = false
		for key, d in pairs(it.diffs) do
			Migrate(d)
			d.base = false
			if d.wf then
				keep = true
			else
				it.diffs[key] = nil
			end
		end
		if keep then
			ListChanged()
			return false
		end
	end
	BIS.RemoveItem(bossID, itemName)
	return true
end

function BIS.RemoveItem(bossID, itemName)
	local b = BIS.CharDB().bosses[bossID]
	if b and b.items[itemName] then
		b.items[itemName] = nil
		Cleanup(bossID)
		ListChanged()
	end
end

function BIS.RemoveBoss(bossID)
	if BIS.CharDB().bosses[bossID] then
		BIS.CharDB().bosses[bossID] = nil
		ListChanged()
	end
end

function BIS.ClearAll()
	wipe(BIS.CharDB().bosses)
	ListChanged()
end

local function DiffOrder(key)
	for i, d in ipairs(BIS.DIFFS) do
		if d.key == key then
			return i
		end
	end
	return 99
end

-- All wanted items, for the "My List" page:
-- { { bossID, name, raid, raidID, items = { { name, icon, quality, diffs = { { key, wf, link } } } } } }
function BIS.GetWishList()
	local out = {}
	local raidOrder = {}
	for i, r in ipairs(BIS.GetRaids()) do
		raidOrder[r.id] = i
	end
	for bossID, b in pairs(BIS.CharDB().bosses) do
		local entry = { bossID = bossID, name = b.name, raid = b.raid, raidID = b.raidID, items = {} }
		local bossIndex = 99
		for i, bb in ipairs(bossCache[b.raidID] or {}) do
			if bb.id == bossID then
				bossIndex = i
			end
		end
		entry.sort = (raidOrder[b.raidID] or 99) * 100 + bossIndex
		for name, it in pairs(b.items) do
			local diffs = {}
			for key, d in pairs(it.diffs) do
				Migrate(d)
				diffs[#diffs + 1] = { key = key, base = d.base, wf = d.wf, link = d.link, itemID = d.itemID }
			end
			table.sort(diffs, function(x, y) return DiffOrder(x.key) < DiffOrder(y.key) end)
			entry.items[#entry.items + 1] = { name = name, icon = it.icon, quality = it.quality, slot = it.slot, diffs = diffs }
		end
		table.sort(entry.items, function(x, y) return x.name < y.name end)
		out[#out + 1] = entry
	end
	table.sort(out, function(x, y)
		if x.sort ~= y.sort then
			return x.sort < y.sort
		end
		return (x.name or "") < (y.name or "")
	end)
	return out
end

-------------------------------------------------------------------------------
--  Kill matching
-------------------------------------------------------------------------------
local function Norm(s)
	s = tostring(s or ""):lower()
	s = s:gsub("^the ", "")
	return (s:gsub("[^%w]", ""))
end

local function SameBoss(a, b)
	a, b = Norm(a), Norm(b)
	if a == "" or b == "" then
		return false
	end
	return a == b or (#a >= 5 and b:find(a, 1, true)) or (#b >= 5 and a:find(b, 1, true))
end

-- Wanted items of a killed boss on a difficulty:
-- bossName, { { name, icon, quality, link, base, wf } }
function BIS.FindWanted(encounterName, diffKey)
	local out, bossName = {}, nil
	for _, b in pairs(BIS.CharDB().bosses) do
		if SameBoss(b.name, encounterName) then
			bossName = bossName or b.name
			for name, it in pairs(b.items) do
				local d = Migrate(it.diffs[diffKey])
				if d and (d.base or d.wf) then
					out[#out + 1] = { name = name, icon = it.icon, quality = it.quality, link = d.link, itemID = d.itemID, base = d.base, wf = d.wf, raidID = b.raidID }
				end
			end
		end
	end
	table.sort(out, function(x, y) return x.name < y.name end)
	return bossName or encounterName, out
end

-------------------------------------------------------------------------------
--  Popup
-------------------------------------------------------------------------------
local POP_W, ROW_H, PAD, HEADER_H = 400, 28, 12, 46
local popup, rows = nil, {}
local hideTimer

local function Font(fs, size)
	local path = (ns.GetFontPath and ns.GetFontPath()) or STANDARD_TEXT_FONT
	fs:SetFont(path, size, "")
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 1)
end

local function NewFS(parent, size, r, g, b, a)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	Font(fs, size)
	fs:SetTextColor(r or 1, g or 1, b or 1, a or 1)
	fs:SetWordWrap(false)
	return fs
end

local function Solid(parent, layer, r, g, b, a)
	local t = parent:CreateTexture(nil, layer)
	t:SetTexture(r, g, b, a)
	return t
end

local function QualityColor(q)
	local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q or 4]
	if c then
		return c.r, c.g, c.b
	end
	return 0.64, 0.21, 0.93
end

local function SavePosition()
	local point, _, _, x, y = popup:GetPoint(1)
	BIS.DB().pos = { point = point, x = x, y = y }
end

local function PlacePopup()
	local pos = BIS.DB().pos
	popup:ClearAllPoints()
	if pos and pos.point then
		popup:SetPoint(pos.point, UIParent, pos.point, pos.x or 0, pos.y or 0)
	else
		popup:SetPoint("TOP", UIParent, "TOP", 0, -180)
	end
end

local function BuildPopup()
	popup = CreateFrame("Frame", "EllesmereUIBISTrackerPopup", UIParent)
	popup:SetSize(POP_W, 100)
	popup:SetFrameStrata("HIGH")
	popup:SetClampedToScreen(true)
	popup:SetMovable(true)
	popup:EnableMouse(true)
	popup:RegisterForDrag("LeftButton")
	popup:SetScript("OnDragStart", function(self) self:StartMoving() end)
	popup:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePosition()
	end)
	tinsert(UISpecialFrames, "EllesmereUIBISTrackerPopup")

	local bg = Solid(popup, "BACKGROUND", 0.06, 0.06, 0.07, 0.94)
	bg:SetAllPoints()
	-- 1 px border
	local function Edge(p1, p2, w, h)
		local t = Solid(popup, "BORDER", 1, 1, 1, 0.10)
		t:SetPoint(p1)
		t:SetPoint(p2)
		if w then t:SetWidth(w) end
		if h then t:SetHeight(h) end
	end
	Edge("TOPLEFT", "TOPRIGHT", nil, 1)
	Edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
	Edge("TOPLEFT", "BOTTOMLEFT", 1, nil)
	Edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)

	popup.accent = popup:CreateTexture(nil, "ARTWORK")
	popup.accent:SetPoint("TOPLEFT", 1, -1)
	popup.accent:SetPoint("TOPRIGHT", -1, -1)
	popup.accent:SetHeight(2)

	popup.title = NewFS(popup, 14, 1, 1, 1, 0.95)
	popup.title:SetPoint("TOPLEFT", PAD, -10)
	popup.title:SetPoint("RIGHT", popup, "RIGHT", -34, 0)
	popup.title:SetJustifyH("LEFT")
	popup.sub = NewFS(popup, 11, 1, 1, 1, 0.5)
	popup.sub:SetPoint("TOPLEFT", popup.title, "BOTTOMLEFT", 0, -4)
	popup.sub:SetPoint("RIGHT", popup, "RIGHT", -PAD, 0)
	popup.sub:SetJustifyH("LEFT")

	local close = CreateFrame("Button", nil, popup)
	close:SetSize(22, 22)
	close:SetPoint("TOPRIGHT", -6, -6)
	close.label = NewFS(close, 14, 1, 1, 1, 0.6)
	close.label:SetPoint("CENTER")
	close.label:SetText("x")
	close:SetScript("OnEnter", function() close.label:SetAlpha(1) end)
	close:SetScript("OnLeave", function() close.label:SetAlpha(0.6) end)
	close:SetScript("OnClick", function() popup:Hide() end)

	local sep = Solid(popup, "ARTWORK", 1, 1, 1, 0.08)
	sep:SetHeight(1)
	sep:SetPoint("TOPLEFT", PAD, -HEADER_H)
	sep:SetPoint("TOPRIGHT", -PAD, -HEADER_H)

	popup.hint = NewFS(popup, 10, 1, 1, 1, 0.35)
	popup.hint:SetPoint("BOTTOMLEFT", PAD, 8)
	popup.hint:SetPoint("RIGHT", popup, "RIGHT", -PAD, 0)
	popup.hint:SetJustifyH("LEFT")
	popup.hint:SetText("Got it: takes it off your list  -  Shift-click: link")

	popup:SetScript("OnHide", function()
		if hideTimer then
			hideTimer.cancelled = true
			hideTimer = nil
		end
	end)
	popup:Hide()
end

-------------------------------------------------------------------------------
--  Item tooltips (popup and settings page): Shift (the compare key) shows the
--  equipped item next to it and releasing it hides that again.
-------------------------------------------------------------------------------
local tipOwner

local function HideCompare()
	for i = 1, 3 do
		local t = _G["ShoppingTooltip" .. i]
		if t then
			t:Hide()
		end
	end
end

local function UpdateCompare()
	if not tipOwner or not GameTooltip:IsShown() or GameTooltip:GetOwner() ~= tipOwner then
		return
	end
	local always = false
	if GetCVarBool then
		local ok, v = pcall(GetCVarBool, "alwaysCompareItems")
		always = ok and v and true or false
	end
	if IsModifiedClick("COMPAREITEMS") or always then
		if GameTooltip_ShowCompareItem then
			GameTooltip_ShowCompareItem(GameTooltip)
		end
	else
		HideCompare()
	end
end

local compareWatcher = CreateFrame("Frame")
compareWatcher:RegisterEvent("MODIFIER_STATE_CHANGED")
-- Inside MODIFIER_STATE_CHANGED the game still reports the old key state:
-- look one frame later.
compareWatcher:SetScript("OnEvent", function(self)
	self:SetScript("OnUpdate", function(f)
		f:SetScript("OnUpdate", nil)
		UpdateCompare()
	end)
end)

-- extra(tooltip): adds lines before the tooltip is shown.
function BIS.ShowItemTooltip(owner, link, extra)
	if not link then
		return
	end
	tipOwner = owner
	GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
	GameTooltip:SetHyperlink(link)
	if extra then
		extra(GameTooltip)
	end
	GameTooltip:Show()
	UpdateCompare()
end

function BIS.HideItemTooltip()
	tipOwner = nil
	HideCompare()
	GameTooltip:Hide()
end

local function GetRow(i)
	local row = rows[i]
	if row then
		return row
	end
	row = CreateFrame("Button", nil, popup)
	row:SetHeight(ROW_H)
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	row.hl = Solid(row, "HIGHLIGHT", 1, 1, 1, 0.05)
	row.hl:SetAllPoints()
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(ROW_H - 6, ROW_H - 6)
	row.icon:SetPoint("LEFT", 0, 0)
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	-- "Got it" buttons: the normal version, and the Warforged one when both are wanted.
	local function GotButton(label)
		local b = CreateFrame("Button", nil, row)
		b:SetSize(46, 20)
		b.bg = Solid(b, "BACKGROUND", 1, 1, 1, 0.06)
		b.bg:SetAllPoints()
		b.label = NewFS(b, 10, 1, 1, 1, 0.75)
		b.label:SetPoint("CENTER", 0, 0)
		b.label:SetText(label)
		b:SetScript("OnEnter", function(self)
			local r, g, bl = ns.ResolveAccent()
			self.bg:SetTexture(r, g, bl, 0.35)
			self.label:SetAlpha(1)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.tipTitle or "", 1, 1, 1)
			GameTooltip:AddLine(self.tipText or "", 1, 0.82, 0, true)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function(self)
			self.bg:SetTexture(1, 1, 1, 0.06)
			self.label:SetAlpha(0.75)
			GameTooltip:Hide()
		end)
		return b
	end
	row.got = GotButton("Got it")
	row.got:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	row.gotWF = GotButton("Got WF")
	row.gotWF:SetPoint("RIGHT", row.got, "LEFT", -4, 0)
	local function Got(forged)
		local gone = true
		if row.bossID then
			gone = BIS.GotItem(row.bossID, row.itemName, forged)
		end
		row.got:Hide()
		row.gotWF:Hide()
		row.tag:ClearAllPoints()
		row.tag:SetPoint("RIGHT", row, "RIGHT", 0, 0)
		row.tag:SetText(gone and "removed" or ((row.forgedName or "Warforged") .. " still wanted"))
		row:SetAlpha(gone and 0.35 or 0.7)
		GameTooltip:Hide()
	end
	row.got:SetScript("OnClick", function() Got(row.gotIsForged) end)
	row.gotWF:SetScript("OnClick", function() Got(true) end)
	row.tag = NewFS(row, 11, 1, 0.55, 0.15, 1)
	row.tag:SetPoint("RIGHT", row.got, "LEFT", -6, 0)
	row.name = NewFS(row, 13)
	row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
	row.name:SetPoint("RIGHT", row.tag, "LEFT", -6, 0)
	row.name:SetJustifyH("LEFT")
	row:SetScript("OnEnter", function(self) BIS.ShowItemTooltip(self, self.link) end)
	row:SetScript("OnLeave", function() BIS.HideItemTooltip() end)
	row:SetScript("OnClick", function(self, button)
		if button == "RightButton" then
			if self.bossID then
				BIS.RemoveItem(self.bossID, self.itemName)
			end
			self.got:Hide()
			self.gotWF:Hide()
			self.tag:ClearAllPoints()
			self.tag:SetPoint("RIGHT", self, "RIGHT", 0, 0)
			self.tag:SetText("removed")
			self:SetAlpha(0.35)
			return
		end
		if IsModifiedClick("CHATLINK") and self.link then
			ChatEdit_InsertLink(self.link)
		end
	end)
	rows[i] = row
	return row
end

local function BossIDByName(name)
	for bossID, b in pairs(BIS.CharDB().bosses) do
		if b.name == name then
			return bossID
		end
	end
	return nil
end

-- Shows the list. items = BIS.FindWanted output.
function BIS.ShowPopup(bossName, diffKey, items, isTest)
	if not popup then
		BuildPopup()
	end
	local d = DIFF_BY_KEY[diffKey]
	local ar, ag, ab = ns.ResolveAccent()
	popup.accent:SetTexture(ar, ag, ab, 0.8)
	popup.title:SetText(bossName or "?")
	popup.sub:SetText((isTest and "Test  -  " or "") .. (d and d.long or "") .. "  -  "
		.. #items .. (#items == 1 and " item you want" or " items you want"))
	local bossID = BossIDByName(bossName)
	local y = -HEADER_H - 6
	for i, it in ipairs(items) do
		local row = GetRow(i)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD, y)
		row:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -PAD, y)
		row:SetAlpha(1)
		row.link = it.link
		row.itemName = it.name
		row.bossID = not isTest and bossID or nil
		row.icon:SetTexture(it.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
		row.name:SetText(it.name)
		row.name:SetTextColor(QualityColor(it.quality))
		row.tag:SetText(BIS.VersionText(it.base, it.wf, it.raidID))
		local forgedName = FORGED[it.raidID] or "Warforged"
		row.forgedName = forgedName
		-- Only the Warforged version wanted: "Got it" means you got that one.
		row.gotIsForged = it.wf and not it.base
		row.got:Show()
		row.got.tipTitle = "Got it"
		if it.base and it.wf then
			row.gotWF:Show()
			row.got.tipText = "You got the normal version: it comes off your list, the " .. forgedName .. " version stays on it."
			row.gotWF.tipTitle = "Got the " .. forgedName .. " version"
			row.gotWF.tipText = "Takes this item off your list completely."
			row.gotWF.label:SetText(forgedName == "Thunderforged" and "Got TF" or "Got WF")
		else
			row.gotWF:Hide()
			row.got.tipText = "Takes this item off your list."
		end
		-- The tag sits left of the buttons that are shown.
		row.tag:ClearAllPoints()
		row.tag:SetPoint("RIGHT", row.gotWF:IsShown() and row.gotWF or row.got, "LEFT", -8, 0)
		row:Show()
		y = y - ROW_H
	end
	for i = #items + 1, #rows do
		rows[i]:Hide()
	end
	popup:SetHeight(-y + 30)
	popup:SetScale(BIS.DB().scale or 1)
	popup:SetAlpha(BIS.DB().alpha or 1)
	PlacePopup()
	popup:Show()

	if hideTimer then
		hideTimer.cancelled = true
		hideTimer = nil
	end
	local secs = BIS.DB().autoHide or 0
	if secs > 0 then
		local t = { cancelled = false }
		hideTimer = t
		local left = secs
		local driver = popup.timerDriver or CreateFrame("Frame")
		popup.timerDriver = driver
		driver:SetScript("OnUpdate", function(self, elapsed)
			if t.cancelled then
				self:SetScript("OnUpdate", nil)
				return
			end
			left = left - elapsed
			if left <= 0 then
				if popup:IsMouseOver() then
					-- Keep it while the mouse is over it.
					left = 2
					return
				end
				self:SetScript("OnUpdate", nil)
				popup:Hide()
			end
		end)
	end
end

-- Scale / opacity changed on the settings page.
function BIS.ApplyLook()
	if popup then
		popup:SetScale(BIS.DB().scale or 1)
		popup:SetAlpha(BIS.DB().alpha or 1)
	end
end

function BIS.HidePopup()
	if popup then
		popup:Hide()
	end
end

function BIS.ResetPosition()
	BIS.DB().pos = nil
	if popup then
		PlacePopup()
	end
end

-- Preview: the wanted items of the first boss on the list (or examples).
function BIS.TestPopup()
	local list = BIS.GetWishList()
	local first = list[1]
	if first then
		local diffKey = first.items[1] and first.items[1].diffs[1] and first.items[1].diffs[1].key or "normal"
		local _, items = BIS.FindWanted(first.name, diffKey)
		BIS.ShowPopup(first.name, diffKey, items, true)
	else
		BIS.ShowPopup("Garrosh Hellscream", "heroic", {
			{ name = "Pick some items first", icon = "Interface\\Icons\\INV_Misc_QuestionMark", quality = 4, base = true, wf = true, raidID = RAID_SOO },
		}, true)
	end
end

-------------------------------------------------------------------------------
--  Events
-------------------------------------------------------------------------------
local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff0cd29fBIS Tracker|r: " .. msg)
end
BIS.Print = Print

local function OnKill(encounterName, difficultyID)
	local diffKey = DIFF_BY_ID[difficultyID or 0]
	if not diffKey then
		local _, _, instDiff = GetInstanceInfo()
		diffKey = DIFF_BY_ID[instDiff or 0]
	end
	if not diffKey then
		return
	end
	local bossName, items = BIS.FindWanted(encounterName, diffKey)
	if #items == 0 then
		return
	end
	local cfg = BIS.DB()
	if cfg.chat then
		local parts = {}
		for _, it in ipairs(items) do
			local s = it.link or it.name
			if it.wf then
				s = s .. " (" .. BIS.VersionText(it.base, it.wf, it.raidID) .. ")"
			end
			parts[#parts + 1] = s
		end
		Print(bossName .. " (" .. DIFF_BY_KEY[diffKey].text .. "): " .. table.concat(parts, ", "))
	end
	if cfg.popup then
		BIS.ShowPopup(bossName, diffKey, items)
	end
end

-- Loot data arriving later: the settings page asks again.
local pending = false
local function LootDataArrived()
	if pending then
		return
	end
	pending = true
	local waited = 0
	local f = BIS.pendingFrame or CreateFrame("Frame")
	BIS.pendingFrame = f
	f:SetScript("OnUpdate", function(self, elapsed)
		waited = waited + elapsed
		if waited < 0.4 then
			return
		end
		self:SetScript("OnUpdate", nil)
		pending = false
		if BIS.OnLootData then
			BIS.OnLootData()
		end
	end)
end

-------------------------------------------------------------------------------
--  Loot glow: a wanted item in a loot roll popup (GroupLootFrame1..4) or in
--  the loot window (LootButton1..4) gets a glow around its icon.
-------------------------------------------------------------------------------
local function ItemIDOf(link)
	return link and tonumber(tostring(link):match("item:(%d+)"))
end

-- Is the item (link) on this character's list? Matches the saved item IDs
-- of every difficulty, else the item name.
function BIS.IsWanted(link)
	local id = ItemIDOf(link)
	if not id then
		return false
	end
	local name = GetItemInfo and GetItemInfo(link)
	for _, b in pairs(BIS.CharDB().bosses) do
		for itemName, it in pairs(b.items) do
			for _, d in pairs(it.diffs) do
				Migrate(d)
				if (d.base or d.wf) and d.itemID == id then
					return true
				end
			end
			if name and itemName == name then
				return true
			end
		end
	end
	return false
end

local function SetLootGlow(host, on)
	if not host then
		return
	end
	local G = ns.Glows
	if on and G and G.StartGlow then
		if not host._bisGlow then
			local w = CreateFrame("Frame", nil, host)
			w:SetAllPoints(host)
			w:SetFrameLevel(host:GetFrameLevel() + 5)
			host._bisGlow = w
		end
		local w = host._bisGlow
		if not w._on then
			w._on = true
			w:Show()
			local size = floor((host:GetWidth() or 36) + 0.5)
			-- Action Button Glow, gold (the usual "this one" glow).
			G.StartGlow(w, 2, size, 1, 0.82, 0.2, nil, floor((host:GetHeight() or size) + 0.5))
		end
	elseif host._bisGlow and host._bisGlow._on then
		host._bisGlow._on = false
		if G and G.StopGlow then
			G.StopGlow(host._bisGlow)
		end
		host._bisGlow:Hide()
	end
end

local function UpdateLootGlows()
	local enabled = BIS.DB().lootGlow
	for i = 1, (NUM_GROUP_LOOT_FRAMES or 4) do
		local f = _G["GroupLootFrame" .. i]
		if f then
			local host = f.IconFrame or _G["GroupLootFrame" .. i .. "IconFrame"]
			local want = false
			if enabled and f:IsShown() and f.rollID and GetLootRollItemLink then
				want = BIS.IsWanted(GetLootRollItemLink(f.rollID))
			end
			SetLootGlow(host, want)
		end
	end
	for i = 1, (LOOTFRAME_NUMBUTTONS or 4) do
		local b = _G["LootButton" .. i]
		if b then
			local want = false
			if enabled and b:IsShown() and b.slot and GetLootSlotLink and LootFrame and LootFrame:IsShown() then
				want = BIS.IsWanted(GetLootSlotLink(b.slot))
			end
			SetLootGlow(b, want)
		end
	end
end
BIS.UpdateLootGlows = UpdateLootGlows

-- Popups fill in after the event: look a frame later.
local glowFrame = CreateFrame("Frame")
local function UpdateLootGlowsSoon()
	glowFrame:SetScript("OnUpdate", function(self)
		self:SetScript("OnUpdate", nil)
		UpdateLootGlows()
	end)
end
glowFrame:RegisterEvent("START_LOOT_ROLL")
glowFrame:RegisterEvent("CANCEL_LOOT_ROLL")
glowFrame:RegisterEvent("LOOT_OPENED")
glowFrame:RegisterEvent("LOOT_SLOT_CLEARED")
glowFrame:RegisterEvent("LOOT_CLOSED")
glowFrame:SetScript("OnEvent", UpdateLootGlowsSoon)
if type(LootFrame_Update) == "function" then
	hooksecurefunc("LootFrame_Update", UpdateLootGlowsSoon)
end
for i = 1, (NUM_GROUP_LOOT_FRAMES or 4) do
	local f = _G["GroupLootFrame" .. i]
	if f then
		f:HookScript("OnShow", UpdateLootGlowsSoon)
		f:HookScript("OnHide", UpdateLootGlowsSoon)
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("ENCOUNTER_END")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
pcall(events.RegisterEvent, events, "EJ_LOOT_DATA_RECIEVED")
events:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		if ... == addonName then
			BIS.DB()
			BIS.CharDB()
			events:UnregisterEvent("ADDON_LOADED")
		end
	elseif event == "ENCOUNTER_END" then
		local encounterID, encounterName, difficultyID, _, success = ...
		if success ~= 1 or not encounterName or encounterName == "" then
			return
		end
		-- A short wait: the kill and the loot window come first.
		local waited = 0
		local f = BIS.killFrame or CreateFrame("Frame")
		BIS.killFrame = f
		f:SetScript("OnUpdate", function(self, elapsed)
			waited = waited + elapsed
			if waited >= 1.5 then
				self:SetScript("OnUpdate", nil)
				OnKill(encounterName, difficultyID)
			end
		end)
	else
		-- GET_ITEM_INFO_RECEIVED / EJ_LOOT_DATA_RECIEVED
		LootDataArrived()
	end
end)

-------------------------------------------------------------------------------
--  Settings reset, /bis
-------------------------------------------------------------------------------
function BIS.ResetSettings()
	local cfg = BIS.DB()
	local selRaid, selBoss = cfg.selRaid, cfg.selBoss
	wipe(cfg)
	ns.CopyDefaults(DEFAULTS, cfg)
	cfg.selRaid, cfg.selBoss = selRaid, selBoss
	if popup then
		PlacePopup()
		popup:SetScale(cfg.scale)
		popup:SetAlpha(cfg.alpha)
	end
end

-- Debug: what the Encounter Journal gives for the selected raid / boss.
local function Debug()
	if not HasEJ() then
		Print("No Encounter Journal API on this client.")
		return
	end
	local raids = BIS.GetRaids()
	Print(#raids .. " raids: " .. (function()
		local t = {}
		for _, r in ipairs(raids) do
			t[#t + 1] = r.name .. " (" .. r.id .. ")"
		end
		return table.concat(t, ", ")
	end)())
	local cfg = BIS.DB()
	if cfg.selRaid then
		Print("Difficulties: " .. table.concat(BIS.GetDifficulties(cfg.selRaid), ", "))
		local t = {}
		for _, b in ipairs(BIS.GetBosses(cfg.selRaid)) do
			t[#t + 1] = b.name .. " (" .. tostring(b.id) .. ")"
		end
		Print(#t .. " bosses: " .. table.concat(t, ", "))
	end
	if cfg.selRaid and cfg.selBoss then
		WithEJ(function()
			SelectCurrentTier()
			local fc, fs
			if EJ_GetLootFilter then
				fc, fs = EJ_GetLootFilter()
			end
			Print("Boss " .. tostring(cfg.selBoss) .. ", journal difficulty " .. tostring(EJ_GetDifficulty and EJ_GetDifficulty())
				.. ", filter " .. tostring(fc) .. "/" .. tostring(fs))
			for _, d in ipairs(BIS.DIFFS) do
				local all = ReadLoot(cfg.selRaid, cfg.selBoss, d.ej, 0)
				local raw = all > 0 and { EJ_GetLootInfoByIndex(1) } or {}
				local _, _, classID = UnitClass("player")
				local mine = ReadLoot(cfg.selRaid, cfg.selBoss, d.ej, classID or 1)
				local fc, fs = BIS.GetFilter()
				local filtered = ReadLoot(cfg.selRaid, cfg.selBoss, d.ej, fc, fs)
				Print("  " .. d.text .. " (" .. d.ej .. "): all classes " .. all .. ", my class " .. mine
					.. ", filter " .. fc .. "/" .. fs .. " " .. filtered
					.. (all > 0 and ("; first = " .. tostring(raw[1]) .. ", " .. tostring(raw[5])) or ""))
			end
		end)
		BIS.ForgetLoot()
		local items, state = BIS.GetLoot(cfg.selRaid, cfg.selBoss)
		Print(#items .. " items, " .. state)
		for _, it in ipairs(items) do
			local t = {}
			for key, v in pairs(it.byDiff) do
				t[#t + 1] = key .. "=" .. tostring(v.itemID)
			end
			Print("  " .. it.name .. ": " .. table.concat(t, " "))
		end
	end
	if BIS.lastError then
		Print("Last error: " .. tostring(BIS.lastError))
	end
end

SLASH_EUIBISTRACKER1 = "/bis"
SlashCmdList.EUIBISTRACKER = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "test" then
		BIS.TestPopup()
	elseif msg == "debug" then
		Debug()
	else
		if ns.LoadOptions and ns.LoadOptions() and ns.OpenSettingsModule then
			ns.OpenSettingsModule("bisTracker")
		end
	end
end
