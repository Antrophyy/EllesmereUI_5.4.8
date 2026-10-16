-------------------------------------------------------------------------------
--  EllesmereUICooldownManager_Spells.lua
--  Default spell lists for a spec with no stored list (retail fills its bars
--  from Blizzard's viewer; 5.4.8 has none, so: a curated per-class list
--  filtered by what this character knows, plus a spellbook scan for spells
--  with a base cooldown, like the viewer does), the spellbook list for the
--  spell picker and the keybind cache (retail EllesmereUICdmKeybindStyle).
-------------------------------------------------------------------------------
local addonName, P = ...
local CDM = P.CDM

local floor = math.floor

-- Rotational cooldowns (Cooldowns bar), defensives / utility (Utility bar) and
-- self buffs (Buffs bar). Only spells the character knows are used.
local CLASS_DEFAULTS = {
	WARRIOR = {
		cooldowns = { 12294, 23881, 85288, 23922, 6572, 6343, 86346, 1719, 107574, 12292, 46924, 118000, 46968, 2565, 112048, 6544, 100 },
		utility   = { 871, 12975, 118038, 97462, 23920, 6552, 5246, 18499, 55694, 114028, 114029, 114030, 3411, 1160, 107570, 102060, 64382 },
		buffs     = { 12880, 1719, 107574, 12292, 132404, 112048, 46916, 131116, 122510, 85739, 871, 12975, 118038 },
	},
	PALADIN = {
		cooldowns = { 35395, 20271, 879, 24275, 53595, 31935, 26573, 119072, 20473, 31884, 86698, 86659, 86669, 105809, 114158, 114165, 114157, 31842, 54428 },
		utility   = { 642, 498, 1022, 6940, 1044, 96231, 853, 633, 31850, 31821, 85499, 105593, 115750, 20066 },
		buffs     = { 31884, 105809, 84963, 90174, 54149, 85416, 132403, 498, 642, 31850, 86700 },
	},
	HUNTER = {
		cooldowns = { 34026, 53209, 53301, 3674, 19574, 3045, 53351, 120679, 131894, 120360, 117050, 109259, 121818, 82692, 34477 },
		utility   = { 19263, 781, 147362, 34490, 5384, 19386, 109248, 53271, 1499, 13813 },
		buffs     = { 19574, 3045, 82692, 34720, 56453, 82925, 19263 },
	},
	ROGUE = {
		cooldowns = { 1856, 13750, 79140, 51690, 51713, 14185, 121471, 137619, 36554, 14183 },
		utility   = { 1766, 31224, 5277, 2983, 1776, 2094, 408, 74001, 76577, 114018, 73981, 57934 },
		buffs     = { 5171, 13750, 51713, 121471, 32645, 31224, 5277, 84745, 84746, 84747 },
	},
	PRIEST = {
		cooldowns = { 8092, 32379, 34433, 123040, 47540, 14914, 33076, 34861, 88625, 10060, 120517, 121135, 110744, 81700, 109964, 724, 15286 },
		utility   = { 47585, 62618, 33206, 47788, 64843, 64901, 8122, 586, 15487, 19236, 73325, 108920, 6346, 32375, 64044 },
		buffs     = { 10060, 47585, 81700, 109964, 81292, 87160, 63735, 124430 },
	},
	DEATHKNIGHT = {
		cooldowns = { 43265, 47568, 51271, 49206, 63560, 49028, 55233, 48982, 77575, 115989, 123693, 45529, 49576 },
		utility   = { 48707, 48792, 47528, 47476, 49039, 51052, 108194, 61999, 96268, 108199, 108200, 108201, 42650, 48743 },
		buffs     = { 51271, 49028, 55233, 48707, 48792, 81141, 59052, 51124, 114851 },
	},
	SHAMAN = {
		cooldowns = { 17364, 60103, 8050, 8056, 8042, 51505, 61295, 73920, 1535, 51533, 114049, 2894, 2062, 16166, 16188, 117014, 73680, 51490, 98008, 108280, 16190, 5394, 120668, 79206 },
		utility   = { 57994, 108271, 30823, 8143, 2484, 51485, 108273, 51514, 58875, 108285, 108270, 108281 },
		buffs     = { 114049, 16166, 16188, 53817, 77762, 53390, 108271, 30823, 79206 },
	},
	MAGE = {
		cooldowns = { 12051, 12042, 12472, 11129, 108853, 44425, 84714, 31687, 44572, 2136, 55342, 12043, 108978, 80353, 112948, 44457, 114923, 116011, 11958 },
		utility   = { 45438, 2139, 1953, 122, 66, 110959, 11426, 113724, 102051, 120, 31661, 108839, 115610 },
		buffs     = { 12042, 12472, 108978, 48108, 44544, 57761, 79683, 116257, 12043 },
	},
	WARLOCK = {
		cooldowns = { 113858, 113860, 113861, 17962, 17877, 105174, 103958, 48181, 1122, 18540, 80240, 120451, 74434, 86121 },
		utility   = { 104773, 108416, 110913, 6789, 5484, 30283, 108482, 48020, 6229, 108359, 119910, 19647 },
		buffs     = { 113858, 113860, 113861, 103958, 104773, 110913, 122355, 117828 },
	},
	MONK = {
		cooldowns = { 107428, 113656, 121253, 115072, 115098, 123986, 124081, 115288, 116740, 115308, 115295, 115080, 123904, 116680, 115310, 116849, 115151, 115294, 115399, 116847 },
		utility   = { 115203, 122470, 119381, 116705, 116841, 109132, 115008, 122278, 122783, 115078, 116844, 119996, 115176, 137562, 115213, 101545 },
		buffs     = { 125359, 116740, 115308, 115295, 115203, 122278, 122783, 116680, 118864, 128939 },
	},
	DRUID = {
		cooldowns = { 5217, 106951, 50334, 33917, 77758, 106830, 78674, 48505, 112071, 33831, 102560, 102543, 102558, 33891, 18562, 48438, 740, 102342, 132158, 29166, 124974, 108292, 108293, 108294 },
		utility   = { 106922, 22842, 62606, 61336, 22812, 106839, 78675, 1850, 77764, 77761, 102280, 102401, 108238, 102351, 99, 5211, 102359, 132469, 102793, 20484 },
		buffs     = { 5217, 106951, 50334, 112071, 102560, 102543, 102558, 33891, 48517, 48518, 69369, 135700, 61336, 22812, 62606 },
	},
}
CDM.CLASS_DEFAULTS = CLASS_DEFAULTS

local function ClassToken()
	local _, class = UnitClass("player")
	return class
end

-- Spellbook spells of the General + current spec tabs (tab 1 = General).
-- MoP also lists the other specs' spells in greyed-out tabs (offSpecID ~= 0)
-- and has a guild tab: both are skipped.
-- Returns { { spellID, name, icon, baseCD } } of active (non-passive) spells.
function CDM.SpellbookSpells()
	local out, seen = {}, {}
	local numTabs = GetNumSpellTabs() or 0
	for tab = 1, numTabs do
		local _, _, offset, numSpells, isGuild, offSpecID = GetSpellTabInfo(tab)
		offset, numSpells = offset or 0, numSpells or 0
		if isGuild or (offSpecID and offSpecID ~= 0) then numSpells = 0 end
		for i = offset + 1, offset + numSpells do
			local kind, sid = GetSpellBookItemInfo(i, BOOKTYPE_SPELL or "spell")
			if kind == "SPELL" and sid and not seen[sid] and not IsPassiveSpell(i, BOOKTYPE_SPELL or "spell") then
				seen[sid] = true
				local name, _, icon = GetSpellInfo(sid)
				if name then
					local cd = GetSpellBaseCooldown(sid) or 0
					out[#out + 1] = { spellID = sid, name = name, icon = icon, baseCD = cd / 1000, tab = tab }
				end
			end
		end
	end
	return out
end

-- Talent spell IDs in GetTalentInfo order (tier 1 col 1..3, tier 2 ...);
-- 5.4.8 GetTalentInfo has no spell ID. From ExRT ExCD2 spell_talentsList.
-- A table entry = spec variants keyed by specialization ID ([0] = default).
local TALENT_SPELLS = {
	WARRIOR = { 103826, 103827, 103828, 55694, 29838, 103840, 107566, 12323, 102060, 46924, 46968, 118000, 114028, 114029, 114030, 107574, 12292, 107570 },
	PALADIN = { 85499, 87172, 26023, 105593, 20066, 110301, 85804, 114163, { [0] = 20925, [65] = 148039 }, 114039, 114154, 105622, 105809, 53376, 86172, 114165, 114158, 114157 },
	HUNTER = { 109215, 109298, 118675, 109248, 19386, 19577, 109304, 109260, 109212, 82726, 120679, 109306, 131894, 130392, 120697, 117050, 109259, 120360 },
	ROGUE = { 14062, 108208, 108209, 26679, 108210, 74001, 31230, 108211, 79008, 138106, 36554, 108212, 131511, 108215, 108216, 114014, 137619, 114015 },
	PRIEST = { 108920, 108921, 605, 64129, 121536, 108942, 109186, 123040, 139139, 19236, 112833, 108945, 109142, 10060, 109175,
		{ [0] = 121135, [258] = 127632 }, { [0] = 110744, [258] = 122121 }, { [0] = 120517, [258] = 120644 } },
	DEATHKNIGHT = { 108170, 123693, 115989, 49039, 51052, 114556, 96268, 50041, 108194, 48743, 108196, 119975, 45529, 81229, 51462, 108199, 108200, 108201 },
	SHAMAN = { 30884, 108270, 108271, 63374, 51485, 108273, 108285, 108284, 108287, 16166, 16188, 108283, 147074, 108281, 108282, 117012, 117013, 117014 },
	MAGE = { 12043, 108843, 108839, 115610, 140468, 11426, 113724, 111264, 102051, 110959, 86949, 11958, 114923, 44457, 112948, 114003, 116011, 1463 },
	WARLOCK = { 108359, 108370, 108371, 47897, 6789, 30283, 108415, 108416, 110913, 111397, 111400, 108482, 108499, 108501, 108503, 108505, 137587, 108508 },
	MONK = { 115173, 116841, 115174, 115098, 124081, 123986, 121817, 115396, 115399, 116844, 119392, 119381, 122280, 122278, 122783, 116847, 123904, 115008 },
	DRUID = { 131768, 102280, 132302, 145108, 108238, 102351, 106707, 102359, 132469, 114107,
		{ [0] = 106731, [102] = 102560, [103] = 102543, [104] = 102558, [105] = 33891 },
		{ [0] = 106737, [102] = 33831, [103] = 102703, [104] = 102706, [105] = 102693 },
		99, 102793, 5211,
		{ [0] = 108288, [102] = 108291, [103] = 108292, [104] = 108293, [105] = 108294 },
		108373, 124974 },
}
CDM.TALENT_SPELLS = TALENT_SPELLS

-- Active talents of the current spec's version that are NOT selected (MoP
-- talents are class-wide; spec variants resolved above). Same row shape as
-- SpellbookSpells plus talent = true.
function CDM.UnselectedTalentSpells()
	local out = {}
	local list = TALENT_SPELLS[ClassToken() or ""]
	if not list or not GetTalentInfo then return out end
	local specID = tonumber(CDM.SpecKey()) or 0
	for i, entry in ipairs(list) do
		local sid = entry
		if type(entry) == "table" then sid = entry[specID] or entry[0] end
		local _, _, _, _, selected = GetTalentInfo(i)
		if sid and not selected and not IsPassiveSpell(sid) then
			local name, _, icon = GetSpellInfo(sid)
			if name then
				local cd = GetSpellBaseCooldown(sid) or 0
				out[#out + 1] = { spellID = sid, name = name, icon = icon, baseCD = cd / 1000, tab = 0, talent = true }
			end
		end
	end
	return out
end

-- Default lists for the current spec (first run with an empty stored list).
function CDM.DefaultSpellList(barType)
	local class = ClassToken()
	local d = class and CLASS_DEFAULTS[class]
	local out, seen = {}, {}
	local function Add(id)
		if not seen[id] then
			seen[id] = true
			out[#out + 1] = id
		end
	end
	if d and d[barType] then
		for _, id in ipairs(d[barType]) do
			if barType == "buffs" then
				if CDM.IsKnownSpell(id) or GetSpellInfo(id) then
					-- Buffs are auras: keep those whose spell (or same-named spell) is known.
					local name = GetSpellInfo(id)
					if name and (CDM.IsKnownSpell(id) or GetSpellInfo(name)) then Add(id) end
				end
			elseif CDM.IsKnownSpell(id) then
				Add(id)
			end
		end
	end
	-- Spellbook scan: spells with a real cooldown that the curated list missed
	-- go to the Cooldowns bar (spec tabs only, max 12 icons).
	if barType == "cooldowns" then
		local util = {}
		for _, id in ipairs(d and d.utility or {}) do util[id] = true end
		for _, s in ipairs(CDM.SpellbookSpells()) do
			if #out >= 12 then break end
			if s.tab > 1 and s.baseCD >= 6 and s.baseCD <= 180 and not util[s.spellID] then
				Add(s.spellID)
			end
		end
	end
	return out
end

-- Fills the empty default bars of the current spec once (retail: the
-- viewer's own spell list on first login of a spec).
function CDM.SeedSpecDefaults()
	local specKey = CDM.SpecKey()
	if specKey == "0" then return end
	local sp = CDM.SpecProfile(specKey)
	if sp._euiDefaultsSeeded then return end
	local any = false
	for _, key in ipairs({ "cooldowns", "utility", "buffs" }) do
		local bd = CDM.BarByKey(key)
		if bd then
			local sd = CDM.BarSpellData(key, specKey)
			-- "Empty" = no entry this client can show.
			local visible = 0
			for _, id in ipairs(sd.assignedSpells) do
				if CDM.ResolveEntry(bd, id, sd) then visible = visible + 1 end
			end
			if visible == 0 then
				local list = CDM.DefaultSpellList(key)
				for _, id in ipairs(list) do
					sd.assignedSpells[#sd.assignedSpells + 1] = id
				end
				if #list > 0 then any = true end
			end
		end
	end
	-- The spellbook can be empty this early; try again later if nothing came.
	if any or #CDM.SpellbookSpells() > 0 then
		sp._euiDefaultsSeeded = true
	end
end

-------------------------------------------------------------------------------
--  Keybinds (retail keybind cache: built out of combat, read per update)
-------------------------------------------------------------------------------
-- Binding command of an action slot (standard bars, which EllesmereUI Action
-- Bars also binds through).
local function SlotCommand(slot, mainPageFirst, mainPage)
	if slot >= 1 and slot <= 12 then
		return "ACTIONBUTTON" .. slot
	elseif slot >= 25 and slot <= 36 then
		return "MULTIACTIONBAR3BUTTON" .. (slot - 24)
	elseif slot >= 37 and slot <= 48 then
		return "MULTIACTIONBAR4BUTTON" .. (slot - 36)
	elseif slot >= 49 and slot <= 60 then
		return "MULTIACTIONBAR2BUTTON" .. (slot - 48)
	elseif slot >= 61 and slot <= 72 then
		return "MULTIACTIONBAR1BUTTON" .. (slot - 60)
	elseif mainPageFirst and slot >= mainPageFirst and slot < mainPageFirst + 12 then
		return "ACTIONBUTTON" .. (slot - mainPageFirst + 1)
	end
end

-- Short key text (retail style: S-, C-, A-, M4, N1, ...).
function CDM.FormatKey(key)
	if not key or key == "" then return "" end
	key = key:upper()
	key = key:gsub("SHIFT%-", "S"):gsub("CTRL%-", "C"):gsub("ALT%-", "A"):gsub("META%-", "M")
	key = key:gsub("MOUSEWHEELUP", "MWU"):gsub("MOUSEWHEELDOWN", "MWD")
	key = key:gsub("BUTTON", "M"):gsub("MIDDLEM", "M3")
	key = key:gsub("NUMPADPLUS", "N+"):gsub("NUMPADMINUS", "N-"):gsub("NUMPADMULTIPLY", "N*")
	key = key:gsub("NUMPADDIVIDE", "N/"):gsub("NUMPADDECIMAL", "N."):gsub("NUMPAD", "N")
	key = key:gsub("CAPSLOCK", "CL"):gsub("SPACE", "SP"):gsub("BACKSPACE", "BS")
	key = key:gsub("PAGEUP", "PU"):gsub("PAGEDOWN", "PD"):gsub("INSERT", "INS"):gsub("DELETE", "DEL")
	key = key:gsub("HOME", "HM"):gsub("END", "EN")
	return key
end

local keyCache = {}      -- [spellID] = text, ["i" .. itemID] = text
local keyCacheByName = {}
CDM.keyCache = keyCache

function CDM.RebuildKeybinds()
	wipe(keyCache)
	wipe(keyCacheByName)
	-- The page bar 1 shows now (stance / form bars use slots 73-120).
	local mainPage = GetActionBarPage and GetActionBarPage() or 1
	local offset = GetBonusBarOffset and GetBonusBarOffset() or 0
	local first = (offset > 0) and ((6 + offset - 1) * 12 + 1) or ((mainPage - 1) * 12 + 1)
	local stable = CDM.DB().cdmBars.stableKeybinds ~= false
	-- Live bar 1 page first (higher priority), then every other slot.
	local order = {}
	for i = first, first + 11 do order[#order + 1] = i end
	for i = 1, 120 do
		if i < first or i > first + 11 then order[#order + 1] = i end
	end
	for _, slot in ipairs(order) do
		if HasAction(slot) then
			local cmd = SlotCommand(slot, first, mainPage)
			-- Stable keybinds: slots of the other forms keep bar 1's key.
			if not cmd and stable and slot >= 73 then
				cmd = "ACTIONBUTTON" .. ((slot - 1) % 12 + 1)
			end
			local key = cmd and GetBindingKey(cmd)
			if key then
				local text = CDM.FormatKey(key)
				local kind, id = GetActionInfo(slot)
				if kind == "spell" and id then
					if not keyCache[id] then keyCache[id] = text end
					local name = GetSpellInfo(id)
					if name and not keyCacheByName[name] then keyCacheByName[name] = text end
				elseif kind == "item" and id then
					if not keyCache["i" .. id] then keyCache["i" .. id] = text end
				elseif kind == "macro" and id then
					local mname = GetMacroSpell(id)
					if mname and not keyCacheByName[mname] then keyCacheByName[mname] = text end
					local _, ilink = GetMacroItem(id)
					local iid = ilink and tonumber(ilink:match("item:(%d+)"))
					if iid and not keyCache["i" .. iid] then keyCache["i" .. iid] = text end
				end
			end
		end
	end
	CDM._keysDirty = false
end

function CDM.KeyFor(e)
	if not e then return "" end
	if e.itemID then
		return keyCache["i" .. e.itemID] or ""
	end
	if e.spellID then
		return keyCache[e.spellID] or (e.name and keyCacheByName[e.name]) or ""
	end
	return ""
end
