-------------------------------------------------------------------------------
--  EllesmereUIQuickdraw.lua (5.4.8 port of retail EllesmereUI Quickdraw)
--
--  Hold a key to open a menu of actions around the cursor; point (Arc, Grid)
--  or scroll (Fan) to choose, release to fire. Same saved keys as retail
--  (EllesmereUIQuickdrawDB = retail profile.addons.EllesmereUIQuickdraw).
--
--  This file: settings, action menus ("palettes") and their entries
--  ("slots"), what each entry fires, its icon / name / cooldown, the lists the
--  settings page offers, key bindings and boot.
--  EUI_Quickdraw_View.lua draws the menu, EUI_Quickdraw_Secure.lua makes it
--  fire in combat (secure buttons + restricted snippets).
--
--  5.4.8 changes:
--    * Mounts are companions (GetCompanionInfo("MOUNT")); a mount entry casts
--      its summon spell by name. Random / last mount use CallCompanion.
--    * Battle pets: C_PetJournal.SummonPetByGUID (MoP pet journal).
--    * "Outfits" (retail transmog outfits) -> Equipment Sets (/equipset).
--    * Specializations -> the two talent specs (SetActiveSpecGroup).
--    * World markers: 5 on 5.4.8 (square, triangle, diamond, cross, star).
--    * Raid target markers are set with SetRaidTarget (not protected here).
--    * No toys, pings, interface panels, profession entries.
--    * Nests: Arc keeps nested menus as an outer arc; Grid and Fan show the
--      nested menu's entries in place of the nest entry.
-------------------------------------------------------------------------------
local addonName = ...
local ns = EllesmereUI

local QD = {}
ns.Quickdraw = QD
QD.addonName = addonName

local type, pairs, ipairs, tonumber, tostring = type, pairs, ipairs, tonumber, tostring
local tinsert, tremove = table.insert, table.remove
local min, max, floor = math.min, math.max, math.floor

local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"
QD.QUESTION_MARK = QUESTION_MARK

QD.MAX_PALETTES = 16      -- = <Binding> entries in Bindings.xml
QD.MAX_SLOTS = 20
QD.MAX_CHILDREN = 8
QD.BINDING_PREFIX = "EUI_RADIAL"   -- retail binding name, kept for good
QD.FONT_KEY = "quickdraw"

-- Key binding page texts (retail OnInitialize).
_G.BINDING_HEADER_EUI_RADIAL = "EllesmereUI Quickdraw"
for i = 1, QD.MAX_PALETTES do
	_G["BINDING_NAME_" .. QD.BINDING_PREFIX .. i] = "Open Action Menu " .. i
end

-------------------------------------------------------------------------------
--  Defaults (retail DB_DEFAULTS.profile)
-------------------------------------------------------------------------------
local DEFAULTS = {
	enabled = false,
	centerMode = "CURSOR",      -- CURSOR | SCREEN
	posX = 0,
	posY = 0,
	layout = "ARC",             -- ARC | FAN | GRID
	fanOrientation = "HORIZONTAL",
	gridAutoColumns = true,
	gridColumns = 4,
	arcSpan = 360,
	arcRotation = 0,
	nestBand = 40,
	nestScale = 0.8,
	gridNestStyle = "PERIMETER",
	arcChildOverflow = "NONE",
	arcChildMaxSpan = 90,
	radius = 100,
	iconSize = 40,
	scale = 1.0,
	fanVisible = 2,
	fanGap = 10,
	fanInvert = false,
	fanMouseSelect = true,
	showActionText = false,
	showCooldowns = true,
	showUsability = true,
	hideUnusable = true,
	selectColorCustom = false,
	selectColor = { 0.047, 0.824, 0.624 },
	useClassColor = false,
	toggleMode = false,
	worldMarkerToggle = true,
	worldMarkerPip = true,
	confirmKey = "",
	cancelKey = "",
	paletteCount = 1,
}
QD.DEFAULTS = DEFAULTS

-- Per menu appearance (retail APPEARANCE_KEYS): palette.appearance[key]
-- overrides the profile value.
local APPEARANCE_KEYS = {
	layout = true, fanOrientation = true,
	centerMode = true, posX = true, posY = true, scale = true,
	gridAutoColumns = true, gridColumns = true,
	arcSpan = true, arcRotation = true,
	fanVisible = true, fanGap = true, fanInvert = true, fanMouseSelect = true,
	radius = true, iconSize = true,
	nestBand = true, nestScale = true, gridNestStyle = true,
	arcChildOverflow = true, arcChildMaxSpan = true,
	showCooldowns = true, showUsability = true, showActionText = true,
	hideUnusable = true,
	selectColorCustom = true, selectColor = true, useClassColor = true,
	toggleMode = true, worldMarkerToggle = true, worldMarkerPip = true,
}
QD.APPEARANCE_KEYS = APPEARANCE_KEYS

local function CopyTable(t)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in pairs(t) do out[k] = CopyTable(v) end
	return out
end
QD.CopyTable = CopyTable

local db

-- The settings root (EllesmereUIQuickdrawDB), defaults filled in.
local function P()
	if not db or db ~= _G.EllesmereUIQuickdrawDB then
		db = ns.ModuleDB("EllesmereUIQuickdrawDB")
	end
	for k, v in pairs(DEFAULTS) do
		if db[k] == nil then db[k] = CopyTable(v) end
	end
	if type(db.palettes) ~= "table" then db.palettes = {} end
	if type(db.palettes[1]) ~= "table" then db.palettes[1] = {} end
	-- retail renames (MigrateNames)
	if db.layout == "FAN_H" or db.layout == "FAN_V" then
		db.fanOrientation = db.layout == "FAN_V" and "VERTICAL" or "HORIZONTAL"
		db.layout = "FAN"
	elseif db.layout == "RADIAL" then
		db.layout = "ARC"
	end
	return db
end
QD.P = P

function QD.AutoPaletteName(index)
	return "Action Menu " .. index
end

-- A palette, created on demand, slots made dense (retail EnsurePalette).
function QD.EnsurePalette(index)
	local p = P()
	if not index or index < 1 or index > QD.MAX_PALETTES then return nil end
	local palette = p.palettes[index]
	if type(palette) ~= "table" then
		palette = {}
		p.palettes[index] = palette
	end
	if type(palette.name) ~= "string" or palette.name == "" then
		palette.name = QD.AutoPaletteName(index)
	end
	if type(palette.slots) ~= "table" then palette.slots = {} end
	local dense, n = {}, 0
	for i = 1, QD.MAX_SLOTS do
		local slot = palette.slots[i]
		if type(slot) == "table" and slot.kind then
			n = n + 1
			dense[n] = slot
		end
	end
	palette.slots = dense
	palette.slotCount = nil
	return palette
end

function QD.PaletteCount()
	local p = P()
	return max(1, min(QD.MAX_PALETTES, tonumber(p.paletteCount) or 1))
end

-- Appearance value of a palette (retail PA / ACfg).
function QD.ACfg(index, key)
	local p = P()
	local palette = index and p.palettes[index]
	if type(palette) == "table" and APPEARANCE_KEYS[key] and type(palette.appearance) == "table" then
		local v = palette.appearance[key]
		if v ~= nil then return v end
	end
	local v = p[key]
	if v == nil then v = DEFAULTS[key] end
	return v
end

function QD.ASet(index, key, value)
	local palette = QD.EnsurePalette(index)
	if not palette then return end
	palette.appearance = palette.appearance or {}
	palette.appearance[key] = value
end

-- A read-only view of one palette's appearance (for the view / secure code).
function QD.PA(index)
	return setmetatable({}, { __index = function(_, key) return QD.ACfg(index, key) end })
end

function QD.AddSlot(palette, slot)
	if not palette or not slot then return nil end
	if #palette.slots >= QD.MAX_SLOTS then return nil end
	palette.slots[#palette.slots + 1] = slot
	return #palette.slots
end

function QD.RemoveSlot(palette, index)
	if not palette or not palette.slots[index] then return false end
	tremove(palette.slots, index)
	return true
end

function QD.MoveSlot(palette, from, to)
	if not palette then return false end
	local n = #palette.slots
	if from == to or from < 1 or from > n or to < 1 or to > n then return false end
	tinsert(palette.slots, to, tremove(palette.slots, from))
	return true
end

-- The palette a "palette" (nest) slot opens.
function QD.ChildIndex(slot)
	if type(slot) ~= "table" or slot.kind ~= "palette" then return nil end
	local idx = tonumber(slot.palette)
	if not idx or idx < 1 or idx > QD.MAX_PALETTES then return nil end
	return idx
end

-------------------------------------------------------------------------------
--  Specs (retail "Assign to Spec": palette.specs = { [specID] = true })
-------------------------------------------------------------------------------
function QD.ClassSpecs()
	local out = {}
	local n = GetNumSpecializations and GetNumSpecializations() or 0
	for i = 1, n do
		local id, name, _, icon = GetSpecializationInfo(i)
		if id then out[#out + 1] = { id = id, name = name, icon = icon, index = i } end
	end
	return out
end

local function CurrentSpecID()
	local i = GetSpecialization and GetSpecialization()
	if not i then return nil end
	return (GetSpecializationInfo(i))
end
QD.CurrentSpecID = CurrentSpecID

function QD.PaletteSpecs(index)
	local palette = P().palettes[index]
	local specs = type(palette) == "table" and palette.specs
	if type(specs) ~= "table" or next(specs) == nil then return nil end
	return specs
end

-- Does this palette load for the current spec? A spec set made only of other
-- classes' specs (a shared profile) also loads: none of them can apply here.
function QD.PaletteActive(index)
	local specs = QD.PaletteSpecs(index)
	if not specs then return true end
	local cur = CurrentSpecID()
	if cur and specs[cur] then return true end
	local mine = false
	for _, s in ipairs(QD.ClassSpecs()) do
		if specs[s.id] then mine = true end
	end
	return not mine
end

-------------------------------------------------------------------------------
--  Entries: what each kind fires, shows and needs
-------------------------------------------------------------------------------
-- World markers: retail stores the raid icon position (1 star .. 8 skull).
-- 5.4.8 has five world markers (1 blue square, 2 green triangle,
-- 3 purple diamond, 4 red cross, 5 yellow star).
local WORLD_MARKER_ENGINE = { [1] = 5, [3] = 3, [4] = 2, [6] = 1, [7] = 4 }
QD.WORLD_MARKER_ENGINE = WORLD_MARKER_ENGINE
QD.WORLD_MARKER_ORDER = { 6, 4, 3, 7, 1 }
local MARKER_NAMES = { "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }
QD.MARKER_NAMES = MARKER_NAMES

local function MarkerIcon(id)
	return "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. id
end
local CLEAR_ICON = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"

-- Battle res first (in combat), then the normal resurrection (retail Rez).
local REZ = {
	DRUID = { 20484, 50769 },
	DEATHKNIGHT = { 61999 },
	WARLOCK = { 20707 },
	PALADIN = { nil, 7328 },
	PRIEST = { nil, 2006 },
	SHAMAN = { nil, 2008 },
	MONK = { nil, 115178 },
}

local function SpellName(id)
	id = tonumber(id)
	return id and (GetSpellInfo(id)) or nil
end

local function RezSpells()
	local _, class = UnitClass("player")
	local t = class and REZ[class]
	if not t then return nil end
	local brez = t[1] and IsSpellKnown(t[1]) and SpellName(t[1]) or nil
	local rez = t[2] and SpellName(t[2]) or nil
	if t[2] and not IsSpellKnown(t[2]) then rez = nil end
	return brez, rez, t
end

local function RezMacroText()
	local brez, rez = RezSpells()
	if brez and rez and brez ~= rez then
		return "/cast [combat] " .. brez .. "; " .. rez
	end
	if brez or rez then return "/cast " .. (brez or rez) end
	return nil
end

-- Known mounts by summon spell (GetCompanionInfo("MOUNT", i)).
local function MountIndex(spellID)
	local n = GetNumCompanions and GetNumCompanions("MOUNT") or 0
	for i = 1, n do
		local _, _, sid = GetCompanionInfo("MOUNT", i)
		if sid == spellID then return i end
	end
	return nil
end
QD.MountIndex = MountIndex

local function PetInfo(guid)
	if type(guid) ~= "string" or not (C_PetJournal and C_PetJournal.GetPetInfoByPetID) then return nil end
	local ok, speciesID, customName, _, _, _, _, _, name, icon = pcall(C_PetJournal.GetPetInfoByPetID, guid)
	if not ok or not speciesID then return nil end
	return customName or name, icon
end

local function EquipSetIcon(name)
	if type(name) ~= "string" or not GetEquipmentSetInfoByName then return nil end
	local icon = GetEquipmentSetInfoByName(name)
	if type(icon) == "string" and not icon:find("\\") then
		icon = "Interface\\Icons\\" .. icon
	end
	return icon
end

local function SpecByID(id)
	id = tonumber(id)
	for _, s in ipairs(QD.ClassSpecs()) do
		if s.id == id then return s end
	end
	return nil
end

-- The spec group holding a spec (MoP: two talent specs).
local function SpecGroupFor(slot)
	local id = tonumber(slot.id)
	if not id then return nil end
	local groups = GetNumSpecGroups and GetNumSpecGroups() or 1
	for g = 1, groups do
		local i = GetSpecialization(false, false, g)
		if i and GetSpecializationInfo(i) == id then return g end
	end
	return nil
end

-- Can this character use the entry at all? (retail SlotUsable)
function QD.SlotUsable(slot)
	local k = slot and slot.kind
	if k == "spell" then
		local id = tonumber(slot.id)
		return id and (IsSpellKnown(id) or IsSpellKnown(id, true)) and true or false
	elseif k == "macro" then
		return GetMacroInfo(slot.name or slot.id) ~= nil
	elseif k == "mount" then
		return MountIndex(tonumber(slot.spellID)) ~= nil
	elseif k == "battlepet" then
		return PetInfo(slot.guid) ~= nil
	elseif k == "equipset" or k == "outfit" then
		return EquipSetIcon(slot.name) ~= nil
	elseif k == "spec" or k == "dynamicspec" then
		return SpecGroupFor(slot) ~= nil
	elseif k == "dynamicrez" then
		return RezMacroText() ~= nil
	elseif k == "worldmarker" then
		local id = tonumber(slot.id)
		return id == 0 or WORLD_MARKER_ENGINE[id] ~= nil
	elseif k == "panel" or k == "dynamicprofession" then
		return false   -- retail-only kinds
	elseif k == "macrotext" then
		return type(slot.macrotext) == "string" and not slot.macrotext:find("^/ping")
	end
	return true
end

-- Secure action of an entry: type, attribute key, value, extra.
-- type "insecure" = fired by Lua after the click (QD.FireInsecure).
-- Returns nil for entries that fire nothing (nests, unknown kinds).
function QD.ResolveAction(slot, pa)
	if type(slot) ~= "table" then return nil end
	local k = slot.kind
	if k == "spell" then
		local name = SpellName(slot.id)
		if not name then return nil end
		return "spell", "spell", name
	elseif k == "item" or k == "toy" then
		local id = tonumber(slot.id)
		if not id then return nil end
		return "item", "item", "item:" .. id
	elseif k == "macro" then
		local nameOrIndex = slot.name or slot.id
		if not nameOrIndex then return nil end
		return "macro", "macro", nameOrIndex
	elseif k == "macrotext" then
		if type(slot.macrotext) ~= "string" or slot.macrotext == "" then return nil end
		return "macro", "macrotext", slot.macrotext
	elseif k == "mount" then
		local name = SpellName(slot.spellID) or slot.name
		if type(name) ~= "string" or name == "" then return nil end
		return "spell", "spell", name
	elseif k == "worldmarker" then
		local id = tonumber(slot.id)
		if id == 0 then return "worldmarker", "marker", 0, "clear" end
		local engine = id and WORLD_MARKER_ENGINE[id]
		if not engine then return nil end
		if not pa or pa.worldMarkerToggle ~= false then
			return "worldmarker", "marker", engine, "toggle"
		end
		return "worldmarker", "marker", engine, "set"
	elseif k == "dynamicrez" then
		local text = RezMacroText()
		if not text then return nil end
		return "macro", "macrotext", text
	elseif k == "equipset" or k == "outfit" then
		if type(slot.name) ~= "string" then return nil end
		return "macro", "macrotext", "/equipset " .. slot.name
	elseif k == "cycleworldmarker" then
		return "cycle"
	elseif k == "battlepet" or k == "spec" or k == "dynamicspec" or k == "randommount"
		or k == "lastmount" or k == "raidtarget" or k == "clearmarkers" or k == "cycleraidtarget" then
		return "insecure"
	end
	return nil
end

-- Steps of the cycling world marker (placed one after another).
function QD.CycleWorldSteps()
	local out = {}
	for _, id in ipairs(QD.WORLD_MARKER_ORDER) do
		out[#out + 1] = WORLD_MARKER_ENGINE[id]
	end
	return out
end

local raidCycle = 0
local GROUP_UNITS = { "player", "target", "focus", "pet" }

-- Entries with no secure action (retail FireInsecure).
function QD.FireInsecure(slot)
	if type(slot) ~= "table" then return end
	local k = slot.kind
	if k == "battlepet" then
		if slot.guid and C_PetJournal and C_PetJournal.SummonPetByGUID then
			C_PetJournal.SummonPetByGUID(slot.guid)
		end
	elseif k == "spec" or k == "dynamicspec" then
		local g = SpecGroupFor(slot)
		if g and GetActiveSpecGroup and GetActiveSpecGroup() ~= g then SetActiveSpecGroup(g) end
	elseif k == "randommount" or k == "lastmount" then
		if IsMounted() then Dismount() return end
		local n = GetNumCompanions("MOUNT") or 0
		if n < 1 then return end
		local idx = k == "lastmount" and MountIndex(tonumber(P().lastMountSpell)) or nil
		CallCompanion("MOUNT", idx or random(1, n))
	elseif k == "raidtarget" then
		local id = tonumber(slot.id)
		if id and UnitExists("target") then
			if id ~= 0 and GetRaidTargetIndex("target") == id then id = 0 end
			SetRaidTarget("target", id)
		end
	elseif k == "cycleraidtarget" then
		if UnitExists("target") then
			raidCycle = raidCycle % 8 + 1
			SetRaidTarget("target", raidCycle)
		end
	elseif k == "clearmarkers" then
		local units = {}
		for _, u in ipairs(GROUP_UNITS) do units[#units + 1] = u end
		for i = 1, 4 do units[#units + 1] = "party" .. i end
		for i = 1, 40 do units[#units + 1] = "raid" .. i end
		for _, u in ipairs(units) do
			if UnitExists(u) and GetRaidTargetIndex(u) then SetRaidTarget(u, 0) end
		end
	end
end

-- Icon of an entry.
function QD.SlotIcon(slot)
	if type(slot) ~= "table" then return QUESTION_MARK end
	local k = slot.kind
	local icon
	if k == "spell" then
		icon = GetSpellTexture(tonumber(slot.id) or 0)
	elseif k == "item" or k == "toy" then
		icon = GetItemIcon(tonumber(slot.id) or 0)
	elseif k == "macro" then
		local _, mIcon = GetMacroInfo(slot.name or slot.id or "")
		icon = mIcon
		if icon == QUESTION_MARK or icon == "INTERFACE\\ICONS\\INV_MISC_QUESTIONMARK" then
			local spell = GetMacroSpell(slot.name or slot.id)
			if spell then
				icon = GetSpellTexture(spell) or icon
			else
				local _, link = GetMacroItem(slot.name or slot.id)
				if link then icon = GetItemIcon(link) or icon end
			end
		end
	elseif k == "mount" then
		icon = GetSpellTexture(tonumber(slot.spellID) or 0)
	elseif k == "battlepet" then
		local _, pIcon = PetInfo(slot.guid)
		icon = pIcon
	elseif k == "equipset" or k == "outfit" then
		icon = EquipSetIcon(slot.name)
	elseif k == "spec" or k == "dynamicspec" then
		local s = SpecByID(slot.id)
		icon = s and s.icon
	elseif k == "worldmarker" or k == "raidtarget" then
		local id = tonumber(slot.id) or 0
		icon = id == 0 and CLEAR_ICON or MarkerIcon(id)
	elseif k == "clearmarkers" then
		icon = CLEAR_ICON
	elseif k == "cycleraidtarget" or k == "cycleworldmarker" then
		icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
	elseif k == "dynamicrez" then
		local _, _, t = RezSpells()
		icon = t and (t[1] and IsSpellKnown(t[1]) and GetSpellTexture(t[1]) or (t[2] and GetSpellTexture(t[2])))
		icon = icon or "Interface\\Icons\\Spell_Holy_Resurrection"
	elseif k == "randommount" or k == "lastmount" then
		icon = "Interface\\Icons\\Ability_Mount_RidingHorse"
	elseif k == "macrotext" then
		icon = slot.icon
	elseif k == "palette" then
		local child = QD.ChildIndex(slot)
		local pal = child and P().palettes[child]
		icon = type(pal) == "table" and pal.icon or nil
		if not icon and type(pal) == "table" and type(pal.slots) == "table" then
			local first = pal.slots[1]
			if first and first.kind ~= "palette" then icon = QD.SlotIcon(first) end
		end
		icon = icon or "Interface\\Icons\\INV_Misc_Book_09"
	end
	if type(icon) == "number" or type(icon) == "string" then return icon end
	if type(slot.icon) == "string" or type(slot.icon) == "number" then return slot.icon end
	return QUESTION_MARK
end

-- Name of an entry.
function QD.SlotName(slot)
	if type(slot) ~= "table" then return "" end
	local k = slot.kind
	if k == "spell" then
		return SpellName(slot.id) or ("Spell " .. tostring(slot.id))
	elseif k == "item" or k == "toy" then
		return (GetItemInfo(tonumber(slot.id) or 0)) or slot.name or ("Item " .. tostring(slot.id))
	elseif k == "macro" then
		return (GetMacroInfo(slot.name or slot.id or "")) or slot.name or "Macro"
	elseif k == "mount" then
		return SpellName(slot.spellID) or slot.name or "Mount"
	elseif k == "battlepet" then
		return (PetInfo(slot.guid)) or slot.name or "Battle Pet"
	elseif k == "equipset" or k == "outfit" then
		return slot.name or "Equipment Set"
	elseif k == "spec" or k == "dynamicspec" then
		local s = SpecByID(slot.id)
		return s and s.name or "Specialization"
	elseif k == "worldmarker" then
		local id = tonumber(slot.id) or 0
		if id == 0 then return "Clear World Markers" end
		return (MARKER_NAMES[id] or "?") .. " World Marker"
	elseif k == "raidtarget" then
		local id = tonumber(slot.id) or 0
		if id == 0 then return "Clear Target Marker" end
		return (MARKER_NAMES[id] or "?") .. " Target Marker"
	elseif k == "clearmarkers" then
		return "Clear All Target Markers"
	elseif k == "cycleraidtarget" then
		return "Cycle Target Markers"
	elseif k == "cycleworldmarker" then
		return "Cycle World Markers"
	elseif k == "dynamicrez" then
		return "Resurrect"
	elseif k == "randommount" then
		return "Random Mount"
	elseif k == "lastmount" then
		return "Last Used Mount"
	elseif k == "macrotext" then
		return slot.name or slot.macrotext or "Custom Macro"
	elseif k == "palette" then
		local child = QD.ChildIndex(slot)
		local pal = child and P().palettes[child]
		return (type(pal) == "table" and pal.name) or (child and QD.AutoPaletteName(child)) or "Action Menu"
	end
	return tostring(k)
end

-- Cooldown start, duration of an entry (nil = none).
function QD.SlotCooldown(slot)
	local k = slot and slot.kind
	if k == "spell" or k == "mount" then
		local name = SpellName(k == "spell" and slot.id or slot.spellID)
		if name then return GetSpellCooldown(name) end
	elseif k == "item" or k == "toy" then
		return GetItemCooldown(tonumber(slot.id) or 0)
	end
	return nil
end

-- Usable right now? (Dim Unusable Actions)
function QD.SlotUsableNow(slot)
	local k = slot and slot.kind
	if k == "spell" then
		local name = SpellName(slot.id)
		return not name or (IsUsableSpell(name)) and true or false
	elseif k == "item" or k == "toy" then
		local id = tonumber(slot.id) or 0
		return (IsUsableItem(id)) and true or false
	end
	return true
end

-- Is a world marker placed? (Show Placed-Marker Pips)
function QD.SlotMarkerPlaced(slot)
	if not slot or slot.kind ~= "worldmarker" then return false end
	local engine = WORLD_MARKER_ENGINE[tonumber(slot.id) or -1]
	return engine and IsRaidMarkerActive and IsRaidMarkerActive(engine) and true or false
end

-- The entries this character shows (retail UsableSlots): a view, the saved
-- slots keep everything for other characters.
function QD.UsableSlots(index)
	local palette = QD.EnsurePalette(index)
	if not palette then return {} end
	local hide = QD.ACfg(index, "hideUnusable") ~= false
	local out = {}
	for _, slot in ipairs(palette.slots) do
		local keep
		if slot.kind == "palette" then
			local child = QD.ChildIndex(slot)
			keep = child and child ~= index and child <= QD.PaletteCount() and QD.PaletteActive(child)
		else
			keep = not hide or QD.SlotUsable(slot)
		end
		if keep then out[#out + 1] = slot end
	end
	return out
end

-- Entries of a nested palette (one level, capped at MAX_CHILDREN).
function QD.ChildSlots(child)
	local out = {}
	for _, slot in ipairs(QD.UsableSlots(child)) do
		if slot.kind ~= "palette" then
			out[#out + 1] = slot
			if #out >= QD.MAX_CHILDREN then break end
		end
	end
	return out
end

-- Entry from what is on the cursor (retail SlotFromCursor).
function QD.SlotFromCursor()
	local cursorType, a, b, c = GetCursorInfo()
	if cursorType == "spell" then
		-- a = spellbook slot, b = book type, c = spellID (5.4.8)
		local id = tonumber(c)
		if not id and a and b then
			local _, sid = GetSpellBookItemInfo(a, b)
			id = sid
		end
		if id then return { kind = "spell", id = id } end
	elseif cursorType == "item" then
		return { kind = "item", id = tonumber(a) }
	elseif cursorType == "macro" then
		local name = GetMacroInfo(a)
		if name then return { kind = "macro", id = a, name = name } end
	elseif cursorType == "companion" then
		-- a = index, b = "MOUNT" / "CRITTER"
		if b == "MOUNT" then
			local _, name, spellID = GetCompanionInfo("MOUNT", a)
			if spellID then return { kind = "mount", spellID = spellID, name = name } end
		end
	elseif cursorType == "battlepet" then
		return { kind = "battlepet", guid = a }
	elseif cursorType == "equipmentset" then
		return { kind = "equipset", name = a }
	end
	return nil
end

-------------------------------------------------------------------------------
--  Lists for the settings page ("Add Entry" menus)
-------------------------------------------------------------------------------
local function Entry(slot)
	return { slot = slot, name = QD.SlotName(slot), icon = QD.SlotIcon(slot) }
end

function QD.SpellEntries()
	local out, seen = {}, {}
	local tabs = GetNumSpellTabs() or 0
	for t = 1, tabs do
		local _, _, offset, numSpells = GetSpellTabInfo(t)
		for i = (offset or 0) + 1, (offset or 0) + (numSpells or 0) do
			local kind, id = GetSpellBookItemInfo(i, "spell")
			if kind == "SPELL" and id and not seen[id] and not IsPassiveSpell(i, "spell") then
				seen[id] = true
				out[#out + 1] = Entry({ kind = "spell", id = id })
			end
		end
	end
	return out
end

function QD.MountEntries()
	local out = {}
	out[#out + 1] = Entry({ kind = "randommount" })
	out[#out + 1] = Entry({ kind = "lastmount" })
	local list = {}
	for i = 1, (GetNumCompanions("MOUNT") or 0) do
		local _, name, spellID = GetCompanionInfo("MOUNT", i)
		if spellID then list[#list + 1] = Entry({ kind = "mount", spellID = spellID, name = name }) end
	end
	table.sort(list, function(a, b) return tostring(a.name) < tostring(b.name) end)
	for _, e in ipairs(list) do out[#out + 1] = e end
	return out
end

function QD.ItemEntries()
	local out, seen = {}, {}
	for slotID = 1, 19 do
		local id = GetInventoryItemID("player", slotID)
		if id and not seen[id] and GetItemSpell(id) then
			seen[id] = true
			out[#out + 1] = Entry({ kind = "item", id = id })
		end
	end
	for bag = 0, 4 do
		for s = 1, (GetContainerNumSlots(bag) or 0) do
			local id = GetContainerItemID(bag, s)
			if id and not seen[id] and GetItemSpell(id) then
				seen[id] = true
				out[#out + 1] = Entry({ kind = "item", id = id })
			end
		end
	end
	return out
end

function QD.MacroEntries()
	local out = {}
	local global, perChar = GetNumMacros()
	local function add(i)
		local name = GetMacroInfo(i)
		if name then out[#out + 1] = Entry({ kind = "macro", id = i, name = name }) end
	end
	for i = 1, global or 0 do add(i) end
	local first = (MAX_ACCOUNT_MACROS or 36) + 1
	for i = first, first + (perChar or 0) - 1 do add(i) end
	return out
end

function QD.PetEntries()
	local out = {}
	if not (C_PetJournal and C_PetJournal.GetNumPets and C_PetJournal.GetPetInfoByIndex) then return out end
	local ok, total = pcall(C_PetJournal.GetNumPets, false)
	if not ok then ok, total = pcall(C_PetJournal.GetNumPets) end
	for i = 1, (ok and tonumber(total) or 0) do
		local ok2, petID, _, owned = pcall(C_PetJournal.GetPetInfoByIndex, i, false)
		if ok2 and petID and owned then out[#out + 1] = Entry({ kind = "battlepet", guid = petID }) end
	end
	return out
end

function QD.EquipSetEntries()
	local out = {}
	for i = 1, (GetNumEquipmentSets and GetNumEquipmentSets() or 0) do
		local name = GetEquipmentSetInfo(i)
		if name then out[#out + 1] = Entry({ kind = "equipset", name = name }) end
	end
	return out
end

function QD.SpecEntries()
	local out = {}
	for _, s in ipairs(QD.ClassSpecs()) do
		out[#out + 1] = Entry({ kind = "spec", id = s.id })
	end
	return out
end

function QD.TargetMarkerEntries()
	local out = {}
	for id = 1, 8 do out[#out + 1] = Entry({ kind = "raidtarget", id = id }) end
	out[#out + 1] = Entry({ kind = "raidtarget", id = 0 })
	out[#out + 1] = Entry({ kind = "cycleraidtarget" })
	out[#out + 1] = Entry({ kind = "clearmarkers" })
	return out
end

function QD.WorldMarkerEntries()
	local out = {}
	for _, id in ipairs(QD.WORLD_MARKER_ORDER) do out[#out + 1] = Entry({ kind = "worldmarker", id = id }) end
	out[#out + 1] = Entry({ kind = "worldmarker", id = 0 })
	out[#out + 1] = Entry({ kind = "cycleworldmarker" })
	return out
end

-- Emotes (macro text entries).
local EMOTES = {
	{ "Dance", "/dance", "Interface\\Icons\\INV_Misc_Toy_07" },
	{ "Wave", "/wave", "Interface\\Icons\\Ability_Warrior_RallyingCry" },
	{ "Cheer", "/cheer", "Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend" },
	{ "Laugh", "/lol", "Interface\\Icons\\INV_Misc_Bomb_04" },
	{ "Thank", "/thank", "Interface\\Icons\\INV_ValentinesCard02" },
	{ "Bow", "/bow", "Interface\\Icons\\Ability_Warrior_BattleShout" },
	{ "Sit", "/sit", "Interface\\Icons\\Spell_Nature_Sleep" },
	{ "Sleep", "/sleep", "Interface\\Icons\\Spell_Nature_Sleep" },
	{ "Kneel", "/kneel", "Interface\\Icons\\Spell_Holy_Restoration" },
	{ "Roar", "/roar", "Interface\\Icons\\Ability_Druid_ChallangingRoar" },
	{ "Flex", "/flex", "Interface\\Icons\\Ability_Warrior_Revenge" },
	{ "Train", "/train", "Interface\\Icons\\INV_Misc_Toy_05" },
}
function QD.EmoteEntries()
	local out = {}
	for _, e in ipairs(EMOTES) do
		out[#out + 1] = Entry({ kind = "macrotext", macrotext = e[2], name = e[1], icon = e[3] })
	end
	return out
end

function QD.OtherEntries()
	local out = {}
	if RezMacroText() then out[#out + 1] = Entry({ kind = "dynamicrez" }) end
	return out
end

function QD.PaletteEntries(editing)
	local out = {}
	for i = 1, QD.PaletteCount() do
		if i ~= editing then out[#out + 1] = Entry({ kind = "palette", palette = i }) end
	end
	return out
end

-------------------------------------------------------------------------------
--  Key bindings (retail: WoW binding EUI_RADIAL<n>, routed to the menu's
--  secure button by an override binding)
-------------------------------------------------------------------------------
function QD.GetKey(index)
	return GetBindingKey(QD.BINDING_PREFIX .. index)
end

-- All menu keys as one string (to tell a real key change from our own
-- override bindings firing UPDATE_BINDINGS).
function QD.KeySignature()
	local parts = {}
	for i = 1, QD.MAX_PALETTES do
		local k1, k2 = GetBindingKey(QD.BINDING_PREFIX .. i)
		parts[#parts + 1] = tostring(k1) .. "," .. tostring(k2)
	end
	return table.concat(parts, ";")
end

function QD.SetKey(index, key)
	if InCombatLockdown() then return false end
	local action = QD.BINDING_PREFIX .. index
	local k1, k2 = GetBindingKey(action)
	if k1 then SetBinding(k1) end
	if k2 then SetBinding(k2) end
	if key and key ~= "" then SetBinding(key, action) end
	SaveBindings(GetCurrentBindingSet())
	if QD.Apply then QD.Apply() end
	return true
end

-------------------------------------------------------------------------------
--  Timers / combat queue (5.4.8 has no C_Timer)
-------------------------------------------------------------------------------
local afterCombat = {}
local combatFrame = CreateFrame("Frame")
combatFrame:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	local list = afterCombat
	afterCombat = {}
	for _, fn in pairs(list) do
		local ok, err = pcall(fn)
		if not ok then geterrorhandler()(err) end
	end
end)

-- Runs fn now, or once after combat (one pending call per key).
function QD.AfterCombat(key, fn)
	if not InCombatLockdown() then
		fn()
		return
	end
	afterCombat[key] = fn
	combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
end

-------------------------------------------------------------------------------
--  Retail profile import (EllesmereUI.ProfileRetail.CONVERT)
-------------------------------------------------------------------------------
local function ConvertRetail(blob, notes)
	local out = CopyTable(type(blob) == "table" and blob or {})
	out._seeded = 1
	local dropped = 0
	if type(out.palettes) == "table" then
		for _, palette in pairs(out.palettes) do
			if type(palette) == "table" and type(palette.slots) == "table" then
				local keep = {}
				for _, slot in ipairs(palette.slots) do
					if type(slot) == "table" then
						if slot.kind == "toy" then slot.kind = "item" end
						if slot.kind == "mount" and slot.id and not slot.spellID then
							dropped = dropped + 1
						elseif slot.kind == "panel" or slot.kind == "dynamicprofession" then
							dropped = dropped + 1
						else
							keep[#keep + 1] = slot
						end
					end
				end
				palette.slots = keep
			end
		end
	end
	if dropped > 0 and type(notes) == "table" then
		notes[#notes + 1] = "Quickdraw: " .. dropped .. " entries have no 5.4.8 version and were left out."
	end
	return out
end
if ns.ProfileRetail and ns.ProfileRetail.CONVERT then
	ns.ProfileRetail.CONVERT[addonName] = ConvertRetail
end
QD.ConvertRetail = ConvertRetail

-- First login: the user's retail values (profile "Naowh": one empty action
-- menu, module off = retail defaults).
local function Seed(t)
	t._seeded = 1
end

function QD.Reset()
	local t = P()
	wipe(t)
	P()
	Seed(t)
	if QD.Apply then QD.Apply() end
end

-------------------------------------------------------------------------------
--  Boot and events
-------------------------------------------------------------------------------
ns.applyHooks = ns.applyHooks or {}
tinsert(ns.applyHooks, function()
	if db and QD.Apply then QD.Apply() end
end)

local function TrackLastMount()
	if not IsMounted() then return end
	for i = 1, (GetNumCompanions("MOUNT") or 0) do
		local _, _, spellID, _, summoned = GetCompanionInfo("MOUNT", i)
		if summoned then P().lastMountSpell = spellID return end
	end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == addonName then
			self:UnregisterEvent("ADDON_LOADED")
			local t = P()
			if t._seeded ~= 1 then Seed(t) end
		end
		return
	end
	if event == "PLAYER_LOGIN" then
		for _, e in ipairs({ "UPDATE_BINDINGS", "SPELLS_CHANGED", "UPDATE_MACROS", "COMPANION_LEARNED",
			"PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED", "EQUIPMENT_SETS_CHANGED",
			"BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD", "COMPANION_UPDATE" }) do
			self:RegisterEvent(e)
		end
	end
	if event == "COMPANION_UPDATE" then
		TrackLastMount()
		return
	end
	if not db then return end
	if event == "UPDATE_BINDINGS" then
		-- override bindings (ours too) fire this: only react to a changed key
		if QD.KeySignature() == QD.appliedKeys then return end
	end
	if event == "PLAYER_LOGIN" then
		if QD.Apply then QD.Apply() end
	elseif QD.RequestApply then
		QD.RequestApply()
	end
end)

-- /eqd, /quickdraw (retail): open the Quickdraw settings.
SLASH_EUIQUICKDRAW1 = "/eqd"
SLASH_EUIQUICKDRAW2 = "/quickdraw"
SlashCmdList.EUIQUICKDRAW = function()
	if InCombatLockdown() then
		print("Cannot open options in combat")
		return
	end
	if ns.LoadOptions() and ns.OpenSettingsModule then ns.OpenSettingsModule("quickdraw") end
end
