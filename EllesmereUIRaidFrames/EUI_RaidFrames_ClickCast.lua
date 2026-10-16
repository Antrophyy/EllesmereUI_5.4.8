-------------------------------------------------------------------------------
--  EUI_RaidFrames_ClickCast.lua  (5.4.8 port of retail EUI_RaidFrames_ClickCast)
--
--  Click casting: per-spec bindings + global bindings, same data model and
--  keys as retail (EllesmereUIDB.clickCast = { enabled, allFrames, downClick,
--  clearTargeting, globals = { ... }, specs = { [specID] = { ... } } }), so
--  retail profile strings stay compatible. Starts EMPTY (no default bindings).
--
--  Two paths, like retail:
--   (1) Frame bindings: mouse buttons 1-5 are secure attributes on each unit
--       button ("shift-type1", "spell1", "macrotext1" ...). Keyboard keys and
--       the mouse wheel are SetBindingClick'ed while the mouse is over a frame
--       (SecureHandlerWrapScript OnEnter / OnLeave, the way VuhDo and Clique
--       do it on 5.4.8) and click a virtual button "eui_N" of that frame.
--   (2) Hovercast: one hidden secure button; its bindings are set while any
--       unit is under the mouse ([@mouseover,exists] state driver) and cast
--       on @mouseover (nameplates, world units, any frame).
--
--  Every secure write happens out of combat (RF.AfterCombat).
--  Skipped on 5.4.8 (no counterpart): Command (META) clicks, the tooltip
--  modifier "eaters", WoW Forever spell ranks, combat-rez items, base-spell
--  override resolution (C_Spell.GetBaseSpell), "Clear Stuck Spell Targeting"
--  (/stopspelltarget is not a 5.4.8 macro command; the key is kept).
-------------------------------------------------------------------------------
local addonName, RF = ...
local ns = EllesmereUI
local ERF = RF.ERF

local pairs, ipairs, type, tostring, tonumber = pairs, ipairs, type, tostring, tonumber
local tinsert, tremove, tconcat = table.insert, table.remove, table.concat
local format = string.format
local wipe = wipe or function(t)
	for k in pairs(t) do
		t[k] = nil
	end
	return t
end

-- Secure FrameXML helpers (SecureHandlers.lua / SecureStateDriver.lua; all on
-- 5.4.8). Looked up at call time and skipped if missing, so a stripped test
-- environment cannot break the login / apply path.
local function SafeWrapScript(frame, script, hdr, body)
	if SecureHandlerWrapScript then
		SecureHandlerWrapScript(frame, script, hdr, body)
	end
end
local function SafeSetFrameRef(frame, label, ref)
	if SecureHandlerSetFrameRef then
		SecureHandlerSetFrameRef(frame, label, ref)
	end
end
local function SafeExecute(frame, body)
	if SecureHandlerExecute then
		SecureHandlerExecute(frame, body)
	end
end
local function SafeRegAttrDriver(frame, attr, values)
	if RegisterAttributeDriver then
		RegisterAttributeDriver(frame, attr, values)
	else
		frame:SetAttribute(attr, (values:match("; (.+)$")))
	end
end
local function SafeUnregAttrDriver(frame, attr)
	if UnregisterAttributeDriver then
		UnregisterAttributeDriver(frame, attr)
	end
end

-------------------------------------------------------------------------------
--  Constants
-------------------------------------------------------------------------------
local MODIFIER_KEYS = {
	LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
	LALT = true, RALT = true, LMETA = true, RMETA = true,
}

local MOUSE_BUTTON_MAP = {
	LeftButton = "BUTTON1",
	RightButton = "BUTTON2",
	MiddleButton = "BUTTON3",
	Button4 = "BUTTON4",
	Button5 = "BUTTON5",
}

local ACTION_ICONS = {
	target = "Interface\\Icons\\Ability_Hunter_SniperShot",
	menu = "Interface\\Icons\\INV_Misc_Note_01",
	macro = "Interface\\Icons\\INV_Misc_QuestionMark",
	dispel = "Interface\\Icons\\Spell_Holy_DispelMagic",
	external = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
	dynamicrez = "Interface\\Icons\\Spell_Holy_Resurrection",
	trinket1 = "Interface\\Icons\\INV_Misc_QuestionMark",
	trinket2 = "Interface\\Icons\\INV_Misc_QuestionMark",
}
RF.CC_ACTION_ICONS = ACTION_ICONS

-- Friendly dispels by class (5.4.8 spell IDs). Spells the character does not
-- know are dropped before they reach the macro (a /cast of an unknown spell
-- would eat the press).
local DISPEL_SPELLS = {
	{ id = 527, name = "Purify", class = "PRIEST" },
	{ id = 115450, name = "Detox", class = "MONK" },
	{ id = 4987, name = "Cleanse", class = "PALADIN" },
	{ id = 88423, name = "Nature's Cure", class = "DRUID" },
	{ id = 2782, name = "Remove Corruption", class = "DRUID" },
	{ id = 77130, name = "Purify Spirit", class = "SHAMAN" },
	{ id = 51886, name = "Cleanse Spirit", class = "SHAMAN" },
	{ id = 89808, name = "Singe Magic", class = "WARLOCK", pet = true },
	{ id = 475, name = "Remove Curse", class = "MAGE" },
}

-- External defensives by class (5.4.8: Blessing of Sacrifice = Hand of Sacrifice).
local EXTERNAL_SPELLS = {
	{ id = 33206, name = "Pain Suppression", class = "PRIEST" },
	{ id = 47788, name = "Guardian Spirit", class = "PRIEST" },
	{ id = 102342, name = "Ironbark", class = "DRUID" },
	{ id = 6940, name = "Hand of Sacrifice", class = "PALADIN" },
	{ id = 116849, name = "Life Cocoon", class = "MONK" },
}

-- Resurrection kits: single (out of combat) and battle (combat). 5.4.8 has no
-- class mass resurrection (Mass Resurrection is a guild perk) and no battle
-- rez for paladins.
local REZ_BY_CLASS = {
	PRIEST = { single = 2006 },
	PALADIN = { single = 7328 },
	SHAMAN = { single = 2008 },
	DRUID = { single = 50769, battle = 20484 },
	MONK = { single = 115178 },
	DEATHKNIGHT = { battle = 61999 },
	WARLOCK = { battle = 20707 },
}

local REZ_SPELL_IDS = {}
for _, kit in pairs(REZ_BY_CLASS) do
	for _, id in pairs(kit) do
		REZ_SPELL_IDS[id] = true
	end
end

local PRESET_SPELL_IDS = {}
for _, sp in ipairs(DISPEL_SPELLS) do
	PRESET_SPELL_IDS[sp.id] = true
end
for _, sp in ipairs(EXTERNAL_SPELLS) do
	PRESET_SPELL_IDS[sp.id] = true
end
RF.CC_PRESET_SPELL_IDS = PRESET_SPELL_IDS

local KEY_DISPLAY = {
	BUTTON1 = "Left Click", BUTTON2 = "Right Click", BUTTON3 = "Middle Click",
	BUTTON4 = "Mouse 4", BUTTON5 = "Mouse 5",
	MOUSEWHEELUP = "Wheel Up", MOUSEWHEELDOWN = "Wheel Down",
}
RF.CC_KEY_DISPLAY = KEY_DISPLAY

local CC_CTX_ORDER = { "solo", "party", "raid", "pvp" }
RF.CC_CTX_ORDER = CC_CTX_ORDER

-------------------------------------------------------------------------------
--  State
-------------------------------------------------------------------------------
local header = nil -- SecureHandlerStateTemplate (frame key bindings + eui_cc driver)
local bindProxy = nil -- SecureActionButtonTemplate (unnamed frame fallback)
local globalBtn = nil -- SecureActionButtonTemplate (hovercast bindings)
local registeredFrames = {}
local wrappedFrames = {}
local ownedFrames = {} -- our raid / party buttons (RF.CC_SetupButton)
local externalFrames = {} -- frames from the ClickCastFrames table ("All Unit Frames")
local ccInitialized = false
local ccEventFrame = nil
local lastBindingCount = 0
local lastHoverCount = 0
local prevBindings = {}
local lastRosterCtx = nil
local knownSig = ""

-------------------------------------------------------------------------------
--  Data access
-------------------------------------------------------------------------------
local function GetClickCastDB()
	if type(EllesmereUIDB) ~= "table" then
		return nil
	end
	local cc = EllesmereUIDB.clickCast
	if type(cc) ~= "table" then
		-- Retail defaults, but with no bindings (the user starts from empty).
		cc = {
			enabled = false,
			allFrames = true,
			downClick = true,
			specs = {},
			globals = {},
		}
		EllesmereUIDB.clickCast = cc
	end
	if type(cc.specs) ~= "table" then
		cc.specs = {}
	end
	if type(cc.globals) ~= "table" then
		cc.globals = {}
	end
	return cc
end

local function GetCurrentSpecID()
	local idx = GetSpecialization and GetSpecialization()
	local id = idx and GetSpecializationInfo(idx)
	return (id and id ~= 0) and id or nil
end
local function GetCurrentSpecName()
	local idx = GetSpecialization and GetSpecialization()
	if not idx then
		return "No Spec"
	end
	local _, n = GetSpecializationInfo(idx)
	return n or "No Spec"
end
local function GetCurrentSpecIcon()
	local idx = GetSpecialization and GetSpecialization()
	if not idx then
		return nil
	end
	local _, _, _, ic = GetSpecializationInfo(idx)
	return ic
end

-- Retail profile strings may carry the spec keys as strings.
local function SpecList(cc, specID, create)
	if not specID then
		return nil
	end
	local list = cc.specs[specID] or cc.specs[tostring(specID)]
	if not list and create then
		list = {}
		cc.specs[specID] = list
	end
	return list
end

local function GetSpecBindings(specID)
	local cc = GetClickCastDB()
	if not cc then
		return {}
	end
	return SpecList(cc, specID or GetCurrentSpecID()) or {}
end

local function GetGlobalBindings()
	local cc = GetClickCastDB()
	return cc and cc.globals or {}
end

-------------------------------------------------------------------------------
--  Binding predicates (retail)
-------------------------------------------------------------------------------
local function CtxEnabled(binding, ctx)
	local set = binding.groupCtx
	if type(set) ~= "table" then
		return true
	end
	return set[ctx] == true
end
RF.CC_CtxEnabled = CtxEnabled

local function CurrentCtx()
	local _, instType = IsInInstance()
	if instType == "pvp" or instType == "arena" then
		return "pvp"
	end
	if IsInRaid() then
		return "raid"
	end
	if IsInGroup() then
		return "party"
	end
	return "solo"
end

local function MatchesGroupCtx(binding)
	return CtxEnabled(binding, CurrentCtx())
end

-- binding.hovercast: false/nil = frames only, true = mouseover only, "both".
local function IsHoverBinding(binding)
	return binding.hovercast and true or false
end
local function IsFrameBinding(binding)
	return (not binding.hovercast) or binding.hovercast == "both"
end

function RF.CC_GetBindingUnitType(binding)
	local friendly, enemy = binding.hoverFriendly, binding.hoverEnemy
	if friendly == false and enemy == false then
		return "none"
	end
	friendly = friendly ~= false
	enemy = enemy == true
	if friendly and not enemy then
		return "friendly"
	end
	if enemy and not friendly then
		return "harmful"
	end
	return "both"
end

local function IsReactionBinding(binding)
	return binding and (binding.type == "spell" or binding.type == "item"
		or (binding.type == "macro" and binding.hovercast))
end

local function IsBindingActive(binding)
	return binding.enabled ~= false
		and (not IsReactionBinding(binding) or RF.CC_GetBindingUnitType(binding) ~= "none")
end

-- A spell the character cannot cast right now stays saved, but cannot own a
-- key against a spell they do have. Bindings without an id count as known.
local function IsSpellIDKnown(id, name)
	if type(id) ~= "number" or id <= 0 then
		return true
	end
	for _, sp in ipairs(DISPEL_SPELLS) do
		if sp.pet and sp.id == id then
			return true
		end
	end
	if IsSpellKnown(id) then
		return true
	end
	-- 5.4.8: GetSpellInfo(name) answers only for spells in the spellbook.
	if type(name) == "string" and name ~= "" and GetSpellInfo(name) then
		return true
	end
	return false
end

local function IsBindingKnown(binding)
	if not binding then
		return false
	end
	if binding.type == "spell" then
		if IsSpellIDKnown(binding.spellID, binding.spell) then
			return true
		end
		return binding.harmfulSpellID ~= nil and IsSpellIDKnown(binding.harmfulSpellID, binding.harmfulSpell)
	elseif binding.type == "reaction" then
		return IsBindingKnown(binding.friendlyAction) or IsBindingKnown(binding.harmfulAction)
	end
	return true
end
RF.CC_IsBindingKnown = IsBindingKnown

function RF.CC_AreComplementaryReactionBindings(a, b)
	if not IsReactionBinding(a) or not IsReactionBinding(b)
		or a.key ~= b.key or a.harmfulSpell or b.harmfulSpell then
		return false
	end
	if not ((a.type == "spell" and (b.type == "spell" or b.type == "item"))
		or (a.type == "item" and b.type == "spell")) then
		return false
	end
	if not ((IsFrameBinding(a) and IsFrameBinding(b))
		or (IsHoverBinding(a) and IsHoverBinding(b)))
		or (a.oocOnly or false) ~= (b.oocOnly or false) then
		return false
	end
	local ar, br = RF.CC_GetBindingUnitType(a), RF.CC_GetBindingUnitType(b)
	return (ar == "friendly" and br == "harmful") or (ar == "harmful" and br == "friendly")
end

local function AreComplementarySpellBindings(a, b)
	if not a or not b or a.type ~= "spell" or b.type ~= "spell" then
		return false
	end
	return RF.CC_AreComplementaryReactionBindings(a, b)
end

local function MergeComplementarySpellBindings(bindings)
	local result = {}
	for _, binding in ipairs(bindings) do
		local merged = false
		for i, previous in ipairs(result) do
			if AreComplementarySpellBindings(previous, binding) then
				local friendly = RF.CC_GetBindingUnitType(previous) == "friendly" and previous or binding
				local harmful = friendly == previous and binding or previous
				local combined = {}
				for k, v in pairs(friendly) do
					combined[k] = v
				end
				combined.harmfulSpell = harmful.spell
				combined.harmfulSpellID = harmful.spellID
				combined.harmfulIcon = harmful.icon
				combined.hoverFriendly = true
				combined.hoverEnemy = true
				combined.smartRez = friendly.smartRez or harmful.smartRez
				result[i] = combined
				merged = true
				break
			end
		end
		if not merged then
			result[#result + 1] = binding
		end
	end
	return result
end

local function MergeComplementaryItemSpellBindings(bindings)
	local result = {}
	for _, binding in ipairs(bindings) do
		local merged = false
		for i, previous in ipairs(result) do
			if RF.CC_AreComplementaryReactionBindings(previous, binding) and previous.type ~= binding.type then
				local friendly = RF.CC_GetBindingUnitType(previous) == "friendly" and previous or binding
				local harmful = friendly == previous and binding or previous
				local spell = friendly.type == "spell" and friendly or harmful
				result[i] = {
					type = "reaction",
					key = friendly.key,
					hovercast = friendly.hovercast,
					oocOnly = friendly.oocOnly,
					friendlyAction = friendly,
					harmfulAction = harmful,
					smartRez = friendly.smartRez or harmful.smartRez,
					spell = spell.spell,
					spellID = spell.spellID,
				}
				merged = true
				break
			end
		end
		if not merged then
			result[#result + 1] = binding
		end
	end
	return result
end

-- A "both" binding takes part in each path's merge / conflict pass on its own.
local function ExpandBothPathBindings(bindings)
	local result = {}
	for _, binding in ipairs(bindings) do
		if binding.hovercast == "both" then
			local fb, hb = {}, {}
			for k, v in pairs(binding) do
				fb[k] = v
				hb[k] = v
			end
			fb.hovercast = false
			hb.hovercast = true
			result[#result + 1] = fb
			result[#result + 1] = hb
		else
			result[#result + 1] = binding
		end
	end
	return result
end

-- Only one secure action can own a key on one path: the first wins, except
-- that a known spell takes the key from an unknown one.
local function FilterConflictingBindings(bindings)
	local result = {}
	for _, binding in ipairs(bindings) do
		local conflicts = false
		for i, previous in ipairs(result) do
			if binding.key == previous.key
				and ((IsFrameBinding(binding) and IsFrameBinding(previous))
				or (IsHoverBinding(binding) and IsHoverBinding(previous))) then
				conflicts = true
				if not IsBindingKnown(previous) and IsBindingKnown(binding) then
					result[i] = binding
				end
				break
			end
		end
		if not conflicts then
			result[#result + 1] = binding
		end
	end
	return result
end

-- Globals + current spec (spec wins a key, unless its spell is unknown).
local function GetActiveBindings()
	local cc = GetClickCastDB()
	if not cc or not cc.enabled then
		return {}
	end
	local result, usedKeys, specBindings = {}, {}, {}
	for _, b in ipairs(GetSpecBindings()) do
		if type(b) == "table" and IsBindingActive(b) and b.key and b.key ~= "" and MatchesGroupCtx(b) then
			result[#result + 1] = b
			specBindings[#specBindings + 1] = b
			if IsBindingKnown(b) then
				usedKeys[b.key] = true
			end
		end
	end
	for _, b in ipairs(cc.globals) do
		if type(b) == "table" then
			local keepGlobal = not usedKeys[b.key]
			if not keepGlobal then
				for _, sb in ipairs(specBindings) do
					if RF.CC_AreComplementaryReactionBindings(sb, b) then
						keepGlobal = true
						break
					end
				end
			end
			if IsBindingActive(b) and b.key and b.key ~= "" and keepGlobal and MatchesGroupCtx(b) then
				result[#result + 1] = b
			end
		end
	end
	result = ExpandBothPathBindings(result)
	result = MergeComplementarySpellBindings(result)
	result = MergeComplementaryItemSpellBindings(result)
	return FilterConflictingBindings(result)
end

-- Known / unknown pattern of the enabled spell bindings (SPELLS_CHANGED only
-- re-applies when it changed).
local function ComputeKnownSignature()
	local cc = GetClickCastDB()
	if not cc or not cc.enabled then
		return ""
	end
	local parts = {}
	for _, b in ipairs(GetSpecBindings()) do
		if type(b) == "table" and b.type == "spell" and b.key and IsBindingActive(b) then
			parts[#parts + 1] = IsBindingKnown(b) and "1" or "0"
		end
	end
	for _, b in ipairs(cc.globals) do
		if type(b) == "table" and b.type == "spell" and b.key and IsBindingActive(b) then
			parts[#parts + 1] = IsBindingKnown(b) and "1" or "0"
		end
	end
	return tconcat(parts)
end

-------------------------------------------------------------------------------
--  Key utilities
-------------------------------------------------------------------------------
-- WoW matches modifiers in ALT-CTRL-SHIFT order.
local function GetModifierPrefix()
	local p = ""
	if IsAltKeyDown() then p = p .. "ALT-" end
	if IsControlKeyDown() then p = p .. "CTRL-" end
	if IsShiftKeyDown() then p = p .. "SHIFT-" end
	return p
end
RF.CC_GetModifierPrefix = GetModifierPrefix

function RF.CC_CaptureKey(rawKey)
	if not rawKey or MODIFIER_KEYS[rawKey] or rawKey == "ESCAPE" or rawKey == "UNKNOWN" then
		return nil
	end
	local key = MOUSE_BUTTON_MAP[rawKey] or rawKey:upper()
	return GetModifierPrefix() .. key
end

-- "ALT-CTRL-SHIFT-KEY": modifiers peeled from the front (the key itself can be "-").
local function ParseKeyString(keyStr)
	if not keyStr or keyStr == "" then
		return { modifiers = "", key = "", isMouseButton = false, buttonNum = nil, full = keyStr or "" }
	end
	local rest, mods = keyStr, ""
	while true do
		local pre = (rest:sub(1, 4) == "ALT-" and "ALT-")
			or (rest:sub(1, 5) == "CTRL-" and "CTRL-")
			or (rest:sub(1, 6) == "SHIFT-" and "SHIFT-")
			or (rest:sub(1, 5) == "META-" and "META-")
		if pre and #rest > #pre then
			mods = mods .. pre
			rest = rest:sub(#pre + 1)
		else
			break
		end
	end
	local key = rest
	local isMouse = key:match("^BUTTON%d+$") or key == "MOUSEWHEELUP" or key == "MOUSEWHEELDOWN"
	local btnNum = key:match("^BUTTON(%d+)$")
	return { modifiers = mods, key = key, isMouseButton = isMouse ~= nil,
		buttonNum = btnNum and tonumber(btnNum), full = keyStr }
end
RF.CC_ParseKeyString = ParseKeyString

function RF.CC_FormatKey(keyStr)
	if not keyStr or keyStr == "" then
		return ""
	end
	local parsed = ParseKeyString(keyStr)
	local display = {}
	for m in parsed.modifiers:gmatch("([^-]+)") do
		display[#display + 1] = m == "SHIFT" and "Shift" or m == "CTRL" and "Ctrl" or m == "ALT" and "Alt"
			or m == "META" and "Cmd" or m
	end
	display[#display + 1] = KEY_DISPLAY[parsed.key] or parsed.key
	return tconcat(display, " + ")
end

-- Mouse buttons 1-5 without META are plain click attributes; everything else
-- (keys, wheel) goes through SetBindingClick to a virtual button.
local function UsesDirectClickAttributes(parsed)
	return parsed.isMouseButton and parsed.buttonNum and parsed.buttonNum <= 5
		and not parsed.modifiers:find("META-", 1, true)
end

-- META (Command) does not exist on 5.4.8 Windows clients: such keys are never applied.
local function UsesMeta(parsed)
	return parsed.modifiers:find("META-", 1, true) ~= nil
end

local function CanonKey(key)
	if not key or key == "" then
		return key
	end
	local parsed = ParseKeyString(key)
	if parsed.modifiers == "" then
		return key
	end
	local p = ""
	if parsed.modifiers:find("ALT-", 1, true) then p = p .. "ALT-" end
	if parsed.modifiers:find("CTRL-", 1, true) then p = p .. "CTRL-" end
	if parsed.modifiers:find("SHIFT-", 1, true) then p = p .. "SHIFT-" end
	if parsed.modifiers:find("META-", 1, true) then p = p .. "META-" end
	return p .. parsed.key
end
RF.CC_CanonKey = CanonKey

local function NormalizeSavedBindingKeys()
	local cc = GetClickCastDB()
	if not cc then
		return
	end
	local function canon(b)
		if type(b) == "table" and b.key and b.key ~= "" then
			local k = CanonKey(b.key)
			if k ~= b.key then
				b.key = k
			end
		end
	end
	for _, list in pairs(cc.specs) do
		if type(list) == "table" then
			for _, b in ipairs(list) do
				canon(b)
			end
		end
	end
	for _, b in ipairs(cc.globals) do
		canon(b)
	end
end

-------------------------------------------------------------------------------
--  Macro / spell helpers
-------------------------------------------------------------------------------
local MOUNT_GUARD = ",nomounted,noflying"

-- Localized name of a spell binding (the saved id first, then the saved name).
local function SpellNameOf(id, fallback)
	if type(id) == "number" and id > 0 then
		local n = GetSpellInfo(id)
		if n then
			return n
		end
	end
	return fallback
end

local function ResolveCastSpellName(binding)
	return SpellNameOf(binding.spellID, binding.spell)
end

local function ResolveHarmfulSpellName(binding)
	return SpellNameOf(binding.harmfulSpellID, binding.harmfulSpell)
end

local function IsRezSpellBinding(binding)
	if type(binding.spellID) == "number" and REZ_SPELL_IDS[binding.spellID] then
		return true
	end
	if type(binding.spell) == "string" then
		for id in pairs(REZ_SPELL_IDS) do
			if GetSpellInfo(id) == binding.spell then
				return true
			end
		end
	end
	return false
end

local function SpellCastLine(binding, condStr, harmful)
	local name
	if harmful then
		name = ResolveHarmfulSpellName(binding)
	else
		name = ResolveCastSpellName(binding)
	end
	if not name then
		return nil
	end
	return "/cast " .. condStr .. " " .. name
end

-- This class's preset spells that the character knows (all of them when
-- none reads as known: the spellbook can lag at login).
local function ClassPresetSpells(spellList, class)
	local usable, all = {}, {}
	for _, sp in ipairs(spellList) do
		if sp.class == class then
			all[#all + 1] = sp
			if sp.pet or IsSpellKnown(sp.id) then
				usable[#usable + 1] = sp
			end
		end
	end
	return #usable > 0 and usable or all
end

local function BuildReactionMacroText(binding, guard)
	local lines = {}
	local function AddAction(part, reaction)
		if part.type == "spell" then
			local conds = { "@mouseover", reaction }
			if not IsRezSpellBinding(part) then
				conds[#conds + 1] = "exists"
				conds[#conds + 1] = "nodead"
			end
			if binding.oocOnly then
				conds[#conds + 1] = "nocombat"
			end
			local line = SpellCastLine(part, "[" .. tconcat(conds, ",") .. guard .. "]")
			if line then
				lines[#lines + 1] = line
			end
		elseif part.type == "item" then
			local target = part.itemSlot or part.itemName
			if target then
				local conds = { "@mouseover", reaction, "exists", "nodead" }
				if binding.oocOnly then
					conds[#conds + 1] = "nocombat"
				end
				lines[#lines + 1] = "/use [" .. tconcat(conds, ",") .. guard .. "] " .. target
			end
		end
	end
	AddAction(binding.friendlyAction, "help")
	AddAction(binding.harmfulAction, "harm")
	if #lines == 0 then
		return nil
	end
	return tconcat(lines, "\n")
end

-- Dynamic rez lines: battle rez in combat (when an out-of-combat rez exists),
-- normal rez out of combat. Soulstone also pre-buffs a living ally (standalone).
local function BuildRezLines(binding, guard, standalone)
	local _, pClass = UnitClass("player")
	local kit = REZ_BY_CLASS[pClass]
	if not kit then
		return nil
	end
	local function Known(sid)
		if not sid or not IsSpellKnown(sid) then
			return nil
		end
		return (GetSpellInfo(sid))
	end
	local battleName = Known(kit.battle)
	local singleName = Known(kit.single)
	local lines = {}
	if battleName and not (singleName and binding.oocOnly) then
		local combatCond = ""
		if singleName then
			combatCond = ",combat"
		elseif binding.oocOnly then
			combatCond = ",nocombat"
		end
		lines[#lines + 1] = "/cast [@mouseover,help,dead" .. combatCond .. guard .. "] " .. battleName
	end
	if singleName then
		lines[#lines + 1] = "/cast [@mouseover,help,dead,nocombat" .. guard .. "] " .. singleName
	end
	if standalone and pClass == "WARLOCK" and battleName then
		local oocCond = binding.oocOnly and ",nocombat" or ""
		lines[#lines + 1] = "/cast [@mouseover,help,exists,nodead" .. oocCond .. guard .. "] " .. battleName
	end
	return lines
end

-- Macro body of a user macro: retail macroName (account / character macro),
-- or the 5.4.8 addition binding.macroText (typed in the settings).
local function UserMacroBody(binding)
	if type(binding.macroText) == "string" and binding.macroText ~= "" then
		return binding.macroText
	end
	local macroName = binding.macroName
	if not macroName then
		return nil
	end
	local idx = GetMacroIndexByName(macroName)
	if not idx or idx == 0 then
		return nil
	end
	return GetMacroBody(idx)
end

-- Base macrotext (no Smart Rez). nil = no macro needed (direct spell attribute).
local function BuildBaseMacroText(binding)
	local isHC = binding.hovercast
	local guard = isHC and MOUNT_GUARD or ""
	local t = binding.type

	if t == "reaction" then
		return BuildReactionMacroText(binding, guard)
	elseif t == "spell" then
		local name = ResolveCastSpellName(binding)
		if not name then
			return nil
		end
		local isRez = IsRezSpellBinding(binding)
		local unitType = RF.CC_GetBindingUnitType(binding)
		if binding.harmfulSpell then
			local harmfulName = ResolveHarmfulSpellName(binding)
			if harmfulName then
				local lines = {}
				local function AddReactionLine(reaction, harmful)
					local on = (reaction == "help" and unitType ~= "harmful")
						or (reaction == "harm" and unitType ~= "friendly")
					if not on then
						return
					end
					local rc = { "@mouseover", reaction }
					if not isRez then
						rc[#rc + 1] = "exists"
						rc[#rc + 1] = "nodead"
					end
					if binding.oocOnly then
						rc[#rc + 1] = "nocombat"
					end
					lines[#lines + 1] = SpellCastLine(binding, "[" .. tconcat(rc, ",") .. guard .. "]", harmful)
				end
				AddReactionLine("help", false)
				AddReactionLine("harm", true)
				if #lines == 0 then
					return nil
				end
				return tconcat(lines, "\n")
			end
		end
		local conds = { "@mouseover" }
		if unitType == "friendly" then
			conds[#conds + 1] = "help"
		elseif unitType == "harmful" then
			conds[#conds + 1] = "harm"
		end
		if not isRez then
			conds[#conds + 1] = "exists"
			conds[#conds + 1] = "nodead"
		end
		if binding.oocOnly then
			conds[#conds + 1] = "nocombat"
		end
		if isRez and not isHC and #conds == 1 then
			return nil
		end
		return SpellCastLine(binding, "[" .. tconcat(conds, ",") .. guard .. "]")
	elseif t == "macro" then
		local body = UserMacroBody(binding)
		if not body then
			return nil
		end
		if binding.oocOnly then
			body = "/stopmacro [combat]\n" .. body
		end
		if isHC then
			body = "/stopmacro [mounted][flying]\n" .. body
			local unitType = RF.CC_GetBindingUnitType(binding)
			if unitType == "none" then
				return "/stopmacro"
			end
			if unitType == "friendly" then
				body = "/stopmacro [@mouseover,nohelp]\n" .. body
			elseif unitType == "harmful" then
				body = "/stopmacro [@mouseover,noharm]\n" .. body
			end
		end
		return body
	elseif t == "item" then
		local target = binding.itemSlot or binding.itemName
		if not target then
			return nil
		end
		local unitType = RF.CC_GetBindingUnitType(binding)
		local reaction = unitType == "friendly" and ",help" or unitType == "harmful" and ",harm" or ""
		local cmd = "/use [@mouseover" .. reaction .. ",exists,nodead" .. guard .. "] " .. target
		if binding.oocOnly then
			cmd = "/stopmacro [combat]\n" .. cmd
		end
		return cmd
	elseif t == "trinket1" or t == "trinket2" then
		local slot = t == "trinket1" and 13 or 14
		local cmd = "/use [@mouseover,exists,nodead" .. guard .. "] " .. slot
		if binding.oocOnly then
			cmd = "/stopmacro [combat]\n" .. cmd
		end
		return cmd
	elseif t == "dynamicrez" then
		local lines = BuildRezLines(binding, guard, true)
		if not lines or #lines == 0 then
			return nil
		end
		if binding.oocOnly then
			tinsert(lines, 1, "/stopmacro [combat]")
		end
		return tconcat(lines, "\n")
	elseif t == "dispel" or t == "external" then
		local spellList = t == "dispel" and DISPEL_SPELLS or EXTERNAL_SPELLS
		local _, pClass = UnitClass("player")
		local lines = {}
		if binding.oocOnly then
			lines[#lines + 1] = "/stopmacro [combat]"
		end
		for _, sp in ipairs(ClassPresetSpells(spellList, pClass)) do
			local castName = GetSpellInfo(sp.id) or sp.name
			lines[#lines + 1] = "/cast [@mouseover,exists,nodead" .. guard .. "] " .. castName
		end
		if #lines == 0 or (#lines == 1 and binding.oocOnly) then
			return nil
		end
		return tconcat(lines, "\n")
	end
	return nil
end

-- Secure macrotext is capped at 255 bytes. A hovercast macro over the cap
-- trades the mount guard on every line for one leading /stopmacro.
local MACRO_MAX = 255
local GUARD_STOP = "/stopmacro [mounted][flying]\n"
local function FitMacro(text, hover)
	if not text or #text <= MACRO_MAX then
		return text
	end
	if hover then
		local body = text:gsub("/stopmacro %[mounted%]%[flying%]\n", "")
		body = body:gsub(",nomounted,noflying%]", "]")
		local compact = GUARD_STOP .. body
		if #compact <= MACRO_MAX then
			return compact
		end
	end
	return nil
end

-- Smart Rez ("Enable Dynamic Rez"): rez lines lead, they fail [dead] on a
-- living unit so the binding's own action runs.
local function BuildMacroText(binding)
	local hover = binding.hovercast and true or false
	local plain = BuildBaseMacroText(binding)
	local base = FitMacro(plain, hover) or plain
	if not binding.smartRez then
		return base
	end
	local t = binding.type
	if t == "target" or t == "menu" or t == "dynamicrez" then
		return base
	end
	local guard = hover and MOUNT_GUARD or ""
	local rez = BuildRezLines(binding, guard)
	if not rez or #rez == 0 then
		return base
	end
	if not plain and t == "spell" then
		plain = SpellCastLine(binding, "[@mouseover,exists,nodead" .. guard .. "]")
	end
	local text = tconcat(rez, "\n")
	if plain then
		text = text .. "\n" .. plain
	end
	return FitMacro(text, hover) or base
end
RF.CC_BuildMacroText = BuildMacroText

-------------------------------------------------------------------------------
--  Display helpers (used by the settings page)
-------------------------------------------------------------------------------
function RF.CC_GetBindingIcon(b)
	local t = b.type
	if t == "dispel" or t == "external" then
		local _, pc = UnitClass("player")
		for _, sp in ipairs(ClassPresetSpells(t == "dispel" and DISPEL_SPELLS or EXTERNAL_SPELLS, pc)) do
			local tex = GetSpellTexture(sp.id)
			if tex then
				return tex
			end
		end
		return ACTION_ICONS[t]
	elseif t == "trinket1" then
		return GetInventoryItemTexture("player", 13) or ACTION_ICONS.trinket1
	elseif t == "trinket2" then
		return GetInventoryItemTexture("player", 14) or ACTION_ICONS.trinket2
	elseif t == "dynamicrez" then
		local _, pc = UnitClass("player")
		local kit = REZ_BY_CLASS[pc]
		local sid = kit and (kit.battle or kit.single)
		return (sid and GetSpellTexture(sid)) or ACTION_ICONS.dynamicrez
	end
	-- Retail stores numeric file IDs; 5.4.8 cannot show those, so prefer the live lookup.
	if b.spellID then
		local tex = GetSpellTexture(b.spellID)
		if tex then
			return tex
		end
	end
	if b.spell then
		local _, _, icon = GetSpellInfo(b.spell)
		if icon then
			return icon
		end
	end
	if b.macroName then
		local idx = GetMacroIndexByName(b.macroName)
		if idx and idx > 0 then
			local _, iconTex = GetMacroInfo(idx)
			if iconTex then
				return iconTex
			end
		end
	end
	if b.itemSlot then
		local tex = GetInventoryItemTexture("player", b.itemSlot)
		if tex then
			return tex
		end
	end
	if type(b.icon) == "string" then
		return b.icon
	end
	return ACTION_ICONS[t] or ACTION_ICONS.macro
end

function RF.CC_GetBindingName(b)
	local t = b.type
	if t == "target" then return "Target Unit" end
	if t == "menu" then return "Context Menu" end
	if t == "trinket1" then return "Trinket 1" end
	if t == "trinket2" then return "Trinket 2" end
	if t == "dynamicrez" then return "Dynamic Rez" end
	if t == "dispel" then return "Dispels" end
	if t == "external" then return "Externals" end
	if t == "spell" then
		return SpellNameOf(b.spellID, b.spell) or "Unknown Spell"
	end
	if t == "macro" then
		if b.macroName then
			return b.macroName
		end
		return (b.macroText and b.macroText ~= "") and "Custom Macro" or "Unknown Macro"
	end
	if t == "item" then
		if b.itemSlot then
			local itemID = GetInventoryItemID("player", b.itemSlot)
			local name = itemID and GetItemInfo(itemID)
			if name then
				return name
			end
		end
		return b.itemName or "Unknown Item"
	end
	return "Unknown"
end

-- Class / spec spells from the 5.4.8 spellbook: active (non-passive) spells
-- of every tab except General, the guild perks and the other specs' tabs.
function RF.CC_GetClassSpells()
	local spells, seen = {}, {}
	local numTabs = (GetNumSpellTabs and GetNumSpellTabs()) or 0
	for tab = 2, numTabs do
		local _, _, offset, numSpells, isGuild, offSpecID = GetSpellTabInfo(tab)
		if offset and numSpells and not isGuild and (not offSpecID or offSpecID == 0) then
			for slot = offset + 1, offset + numSpells do
				local skillType, spellID = GetSpellBookItemInfo(slot, "spell")
				if skillType == "SPELL" and spellID and not IsPassiveSpell(slot, "spell") then
					local name = GetSpellBookItemName(slot, "spell")
					if name and not seen[name] then
						seen[name] = true
						spells[#spells + 1] = { id = spellID, name = name, icon = GetSpellTexture(spellID) }
					end
				end
			end
		end
	end
	table.sort(spells, function(a, b)
		return a.name < b.name
	end)
	return spells
end

-- Account (1..36) and character (37..54) macros on 5.4.8.
function RF.CC_GetAllMacros()
	local list = {}
	if not (GetNumMacros and GetMacroInfo) then return list end
	local numAccount, numChar = GetNumMacros()
	local maxAccount = MAX_ACCOUNT_MACROS or 36
	local function Add(i)
		local name, icon = GetMacroInfo(i)
		if name then
			list[#list + 1] = { macroName = name, name = name, icon = icon }
		end
	end
	for i = 1, numAccount or 0 do
		Add(i)
	end
	for i = maxAccount + 1, maxAccount + (numChar or 0) do
		Add(i)
	end
	return list
end

-- Equipped items with a use effect.
local EQUIP_SLOTS = { 13, 14, 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 15, 16, 17 }
function RF.CC_GetEquippedItems()
	local list = {}
	for _, slot in ipairs(EQUIP_SLOTS) do
		local itemID = GetInventoryItemID and GetInventoryItemID("player", slot)
		if itemID and GetItemSpell and GetItemSpell(itemID) then
			local name = GetItemInfo(itemID)
			list[#list + 1] = { itemSlot = slot, name = name or ("Slot " .. slot), icon = GetInventoryItemTexture("player", slot) }
		end
	end
	return list
end

-------------------------------------------------------------------------------
--  Secure attribute helpers
-------------------------------------------------------------------------------
local function ModPrefixForAttr(modsStr)
	if not modsStr or modsStr == "" then
		return ""
	end
	return modsStr:lower()
end

-- menu / target have no macro conditional, so "Only ... Out of Combat" swaps
-- the type itself with an attribute driver.
local function SetGatedType(frame, attrName, value, oocOnly)
	SafeUnregAttrDriver(frame, attrName)
	if oocOnly then
		SafeRegAttrDriver(frame, attrName, "[combat] none; " .. value)
	else
		frame:SetAttribute(attrName, value)
	end
end

local function SetClickAttr(frame, parsed, actionType, spellName, macrotext, oocOnly)
	local prefix = ModPrefixForAttr(parsed.modifiers)
	local suffix = tostring(parsed.buttonNum)
	local gate = oocOnly and (actionType == "togglemenu" or actionType == "target")
	SetGatedType(frame, prefix .. "type" .. suffix, actionType, gate)
	if actionType == "spell" then
		frame:SetAttribute(prefix .. "spell" .. suffix, spellName or "")
	elseif actionType == "macro" then
		frame:SetAttribute(prefix .. "macrotext" .. suffix, macrotext or "")
	end
end

local function ClearClickAttr(frame, parsed)
	local prefix = ModPrefixForAttr(parsed.modifiers)
	local suffix = tostring(parsed.buttonNum)
	SafeUnregAttrDriver(frame, prefix .. "type" .. suffix)
	frame:SetAttribute(prefix .. "type" .. suffix, nil)
	frame:SetAttribute(prefix .. "spell" .. suffix, nil)
	frame:SetAttribute(prefix .. "macrotext" .. suffix, nil)
end

-- Virtual button "eui_N" (a binding click passes "eui_N", the secure code
-- reads "type-eui_N"). The "*" prefix matches it whatever modifier is held.
local function SetKeyAttr(frame, idx, actionType, spellName, macrotext, oocOnly)
	local suffix = "-eui_" .. idx
	local gate = oocOnly and (actionType == "togglemenu" or actionType == "target")
	SetGatedType(frame, "*type" .. suffix, actionType, gate)
	if actionType == "spell" then
		frame:SetAttribute("*spell" .. suffix, spellName or "")
	elseif actionType == "macro" then
		frame:SetAttribute("*macrotext" .. suffix, macrotext or "")
	end
end

local function ClearKeyAttrs(frame, count)
	for i = 1, count do
		local suffix = "-eui_" .. i
		SafeUnregAttrDriver(frame, "*type" .. suffix)
		frame:SetAttribute("*type" .. suffix, nil)
		frame:SetAttribute("*spell" .. suffix, nil)
		frame:SetAttribute("*macrotext" .. suffix, nil)
	end
end

local function ClearHoverAttrs(btn, count)
	for i = 1, count do
		local suffix = "-eui_hc_" .. i
		SafeUnregAttrDriver(btn, "*type" .. suffix)
		btn:SetAttribute("*type" .. suffix, nil)
		btn:SetAttribute("*spell" .. suffix, nil)
		btn:SetAttribute("*macrotext" .. suffix, nil)
		btn:SetAttribute("*unit" .. suffix, nil)
	end
end

-- Binding -> actionType, spellName, macrotext.
local function ResolveBinding(b)
	if b.type == "target" then
		return "target", nil, nil
	end
	if b.type == "menu" then
		return "togglemenu", nil, nil
	end
	local mt = BuildMacroText(b)
	if mt then
		return "macro", nil, mt
	end
	if b.type == "spell" then
		local name = ResolveCastSpellName(b)
		if name then
			return "spell", name, nil
		end
	end
	return nil, nil, nil
end
RF.CC_ResolveBinding = ResolveBinding

-- OnEnter / OnLeave snippets for keyboard and wheel frame bindings.
local function GenerateKeyBindSnippets(bindings)
	local enter, leave, selfClear = {}, {}, {}
	local kb = {}
	for i, b in ipairs(bindings) do
		if IsFrameBinding(b) then
			local parsed = ParseKeyString(b.key)
			if not UsesDirectClickAttributes(parsed) and not UsesMeta(parsed) then
				kb[#kb + 1] = { binding = b, index = i }
			end
		end
	end
	if #kb == 0 then
		return "", "", selfClear
	end
	enter[#enter + 1] = [[local target = self:GetName()]]
	enter[#enter + 1] = [[if not target then]]
	enter[#enter + 1] = [[	local sc = control:GetFrameRef("bindProxy")]]
	enter[#enter + 1] = [[	sc:SetAttribute("unit", self:GetAttribute("unit"))]]
	enter[#enter + 1] = [[	target = "EUIClickCastBindProxy"]]
	enter[#enter + 1] = [[end]]
	for _, k in ipairs(kb) do
		enter[#enter + 1] = format([[control:SetBindingClick(true, %q, target, %q)]], k.binding.key, "eui_" .. k.index)
		leave[#leave + 1] = format([[control:ClearBinding(%q)]], k.binding.key)
		selfClear[#selfClear + 1] = format([[self:ClearBinding(%q)]], k.binding.key)
	end
	return tconcat(enter, "\n"), tconcat(leave, "\n"), selfClear
end

-------------------------------------------------------------------------------
--  Frame registration
-------------------------------------------------------------------------------
local function GetClickDirection()
	local cc = GetClickCastDB()
	-- Down-click only while enabled: a down-stroke togglemenu would open and
	-- close again on the trailing up event of the default right click.
	return (cc and cc.enabled and cc.downClick) and "AnyDown" or "AnyUp"
end

local cachedBindings = nil
local function CurrentBindings()
	if not cachedBindings then
		cachedBindings = GetActiveBindings()
	end
	return cachedBindings
end

local function ApplyFrameBindings(frame, bindings)
	for i, b in ipairs(bindings) do
		if IsFrameBinding(b) and b.key then
			local parsed = ParseKeyString(b.key)
			if not UsesMeta(parsed) then
				local aType, spellName, macrotext = ResolveBinding(b)
				if aType then
					if UsesDirectClickAttributes(parsed) then
						SetClickAttr(frame, parsed, aType, spellName, macrotext, b.oocOnly)
					else
						SetKeyAttr(frame, i, aType, spellName, macrotext, b.oocOnly)
					end
				end
			end
		end
	end
end

local function ClearFrameBindings(frame)
	for _, b in ipairs(prevBindings) do
		if IsFrameBinding(b) and b.key then
			local parsed = ParseKeyString(b.key)
			if UsesDirectClickAttributes(parsed) then
				ClearClickAttr(frame, parsed)
			end
		end
	end
	ClearKeyAttrs(frame, lastBindingCount)
end

-- The base attributes every unit button gets from the headers (left click
-- target, right click menu) stay as the fallback for unbound buttons.
local function RestoreBaseClicks(frame)
	if ownedFrames[frame] then
		if frame:GetAttribute("*type1") == nil then
			frame:SetAttribute("*type1", "target")
		end
		if frame:GetAttribute("*type2") == nil then
			frame:SetAttribute("*type2", "togglemenu")
		end
	end
end

local function DoRegisterFrame(frame)
	if not frame or not frame.RegisterForClicks or not header then
		return
	end
	-- While disabled no frame is touched at all.
	local cc = GetClickCastDB()
	if not (cc and cc.enabled) then
		return
	end
	registeredFrames[frame] = true
	frame:RegisterForClicks(GetClickDirection())
	if frame.EnableMouseWheel then
		frame:EnableMouseWheel(true)
	end
	if not wrappedFrames[frame] then
		wrappedFrames[frame] = true
		SafeWrapScript(frame, "OnEnter", header, [[
			eui_hoverframe = self
			control:RunFor(self, control:GetAttribute("eui_setup_onenter") or "")
			if not eui_hoveractive then
				control:RunAttribute("eui_hover_set")
				eui_hoveractive = true
			end
		]])
		SafeWrapScript(frame, "OnLeave", header, [[
			if eui_hoverframe == self then eui_hoverframe = nil end
			control:RunFor(self, control:GetAttribute("eui_setup_onleave") or "")
		]])
	end
	ApplyFrameBindings(frame, CurrentBindings())
	RestoreBaseClicks(frame)
end

local function DoUnregisterFrame(frame)
	if not registeredFrames[frame] then
		return
	end
	registeredFrames[frame] = nil
	ClearFrameBindings(frame)
	RestoreBaseClicks(frame)
	frame:RegisterForClicks("AnyUp")
	-- The OnEnter / OnLeave wraps stay; their snippets are empty while off.
end

-- "All Unit Frames": frames other addons list in the Clique-style
-- ClickCastFrames table (EllesmereUI unit frames, oUF ...). The table is
-- swapped for a proxy so frames added later are seen too.
local ccHookInstalled = false
local function RegisterExternalFrame(frame)
	if type(frame) ~= "table" or ownedFrames[frame] then
		return
	end
	externalFrames[frame] = true
	local cc = GetClickCastDB()
	if cc and cc.enabled and cc.allFrames then
		RF.AfterCombat("cc_reg_ext", function()
			for f in pairs(externalFrames) do
				if not registeredFrames[f] then
					DoRegisterFrame(f)
				end
			end
		end)
	end
end

local function SetupClickCastFramesHook()
	if ccHookInstalled or IsAddOnLoaded("Clique") then
		return
	end
	ccHookInstalled = true
	local old = ClickCastFrames
	local store = {}
	local proxy = setmetatable({}, {
		__index = store,
		__newindex = function(_, frame, value)
			store[frame] = value
			if value and value ~= false then
				RegisterExternalFrame(frame)
			elseif externalFrames[frame] then
				externalFrames[frame] = nil
				if not ownedFrames[frame] then
					RF.AfterCombat("cc_unreg_ext", function()
						for f in pairs(registeredFrames) do
							if not ownedFrames[f] and not externalFrames[f] then
								DoUnregisterFrame(f)
							end
						end
					end)
				end
			end
		end,
	})
	ClickCastFrames = proxy
	if type(old) == "table" then
		for frame, value in pairs(old) do
			proxy[frame] = value
		end
	end
end

function RF.CC_SetAllFrames(enabled)
	local cc = GetClickCastDB()
	if not cc then
		return
	end
	cc.allFrames = enabled and true or false
	RF.AfterCombat("cc_allframes", function()
		if not cc.enabled then
			return
		end
		if cc.allFrames then
			SetupClickCastFramesHook()
			for f in pairs(externalFrames) do
				if not registeredFrames[f] then
					DoRegisterFrame(f)
				end
			end
		else
			for f in pairs(externalFrames) do
				DoUnregisterFrame(f)
			end
		end
	end)
end

function RF.CC_SetDownClick(enabled)
	local cc = GetClickCastDB()
	if not cc then
		return
	end
	cc.downClick = enabled and true or false
	RF.AfterCombat("cc_downclick", function()
		local dir = GetClickDirection()
		for frame in pairs(registeredFrames) do
			frame:RegisterForClicks(dir)
		end
		if globalBtn then
			globalBtn:RegisterForClicks(dir)
			bindProxy:RegisterForClicks(dir)
		end
	end)
end

-------------------------------------------------------------------------------
--  Init
-------------------------------------------------------------------------------
local OnCCEvent

local function CC_Init()
	if ccInitialized then
		return true
	end
	if not GetClickCastDB() or InCombatLockdown() then
		return false
	end
	header = CreateFrame("Frame", "EUIClickCastHeader", UIParent, "SecureHandlerStateTemplate")
	RF._ccHeader = header

	bindProxy = CreateFrame("Button", "EUIClickCastBindProxy", UIParent, "SecureActionButtonTemplate")
	bindProxy:RegisterForClicks(GetClickDirection())
	bindProxy:SetSize(1, 1)
	bindProxy:SetAlpha(0)
	bindProxy:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -100, 100)
	bindProxy:Show()
	SafeSetFrameRef(header, "bindProxy", bindProxy)

	globalBtn = CreateFrame("Button", "EUIClickCastGlobalBtn", UIParent, "SecureActionButtonTemplate")
	globalBtn:RegisterForClicks(GetClickDirection())
	globalBtn:EnableMouse(false)
	globalBtn:SetSize(1, 1)
	globalBtn:SetAlpha(0)
	globalBtn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -200, 100)
	globalBtn:Show()

	header:SetAttribute("eui_setup_onenter", "")
	header:SetAttribute("eui_setup_onleave", "")
	header:SetAttribute("eui_hover_set", "")
	header:SetAttribute("eui_hover_clear", "")

	ccEventFrame = CreateFrame("Frame")
	ccEventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
	ccEventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
	ccEventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
	ccEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	ccEventFrame:RegisterEvent("UPDATE_MACROS")
	ccEventFrame:SetScript("OnEvent", function(self, event, ...)
		OnCCEvent(self, event, ...)
	end)
	ccInitialized = true
	return true
end

-------------------------------------------------------------------------------
--  Apply
-------------------------------------------------------------------------------
local function ApplyNow()
	if not CC_Init() then
		return
	end
	NormalizeSavedBindingKeys()
	local cc = GetClickCastDB()
	cachedBindings = nil
	local bindings = CurrentBindings()

	knownSig = ComputeKnownSignature()
	if knownSig ~= "" then
		ccEventFrame:RegisterEvent("SPELLS_CHANGED")
	else
		ccEventFrame:UnregisterEvent("SPELLS_CHANGED")
	end

	-- Register / unregister frames to match the enabled state.
	if cc.enabled then
		if cc.allFrames then
			SetupClickCastFramesHook()
		end
		for frame in pairs(ownedFrames) do
			registeredFrames[frame] = registeredFrames[frame] or "new"
		end
		if cc.allFrames then
			for frame in pairs(externalFrames) do
				registeredFrames[frame] = registeredFrames[frame] or "new"
			end
		end
	end

	local hoverBindings = {}
	for i, b in ipairs(bindings) do
		if IsHoverBinding(b) then
			hoverBindings[#hoverBindings + 1] = { b = b, idx = i }
		end
	end

	-- Frame bindings: clear what the last apply wrote, then write the new set.
	local list = {}
	for frame in pairs(registeredFrames) do
		list[#list + 1] = frame
	end
	for _, frame in ipairs(list) do
		if registeredFrames[frame] ~= "new" then
			ClearFrameBindings(frame)
		end
		if cc.enabled and (ownedFrames[frame] or (cc.allFrames and externalFrames[frame])) then
			registeredFrames[frame] = nil
			DoRegisterFrame(frame)
		else
			registeredFrames[frame] = true
			DoUnregisterFrame(frame)
		end
	end
	ClearKeyAttrs(bindProxy, lastBindingCount)
	for i, b in ipairs(bindings) do
		if IsFrameBinding(b) then
			local parsed = ParseKeyString(b.key)
			local aType, spellName, macrotext = ResolveBinding(b)
			if aType and not UsesDirectClickAttributes(parsed) and not UsesMeta(parsed) then
				SetKeyAttr(bindProxy, i, aType, spellName, macrotext, b.oocOnly)
			end
		end
	end

	local enterScript, leaveScript, kbClearLines = GenerateKeyBindSnippets(bindings)
	header:SetAttribute("eui_setup_onenter", enterScript)
	header:SetAttribute("eui_setup_onleave", leaveScript)

	-- Hovercast + keyboard failsafe on one state driver ([@mouseover,exists]).
	UnregisterStateDriver(header, "eui_cc")
	SafeExecute(header, "self:ClearBindings()\neui_hoveractive = false")
	ClearHoverAttrs(globalBtn, lastHoverCount)

	local setLines, clearLines = {}, {}
	local gbName = globalBtn:GetName()
	for hi, hb in ipairs(hoverBindings) do
		local parsed = ParseKeyString(hb.b.key)
		local suffix = "-eui_hc_" .. hi
		local aType, spellName, macrotext = ResolveBinding(hb.b)
		if aType and not UsesMeta(parsed) then
			local mt = nil
			if aType == "spell" then
				mt = BuildMacroText(hb.b) or SpellCastLine(hb.b, "[@mouseover" .. MOUNT_GUARD .. "]")
			elseif aType == "macro" then
				mt = macrotext or ""
			end
			if mt then
				globalBtn:SetAttribute("*type" .. suffix, "macro")
				globalBtn:SetAttribute("*macrotext" .. suffix, mt)
			else
				SetGatedType(globalBtn, "*type" .. suffix, aType,
					hb.b.oocOnly and (aType == "togglemenu" or aType == "target"))
			end
			globalBtn:SetAttribute("*unit" .. suffix, "mouseover")
			setLines[#setLines + 1] = format([[self:SetBindingClick(true, %q, %q, %q)]], hb.b.key, gbName, "eui_hc_" .. hi)
			clearLines[#clearLines + 1] = format([[self:ClearBinding(%q)]], hb.b.key)
		end
	end
	header:SetAttribute("eui_hover_set", tconcat(setLines, "\n"))
	header:SetAttribute("eui_hover_clear", tconcat(clearLines, "\n"))

	if #setLines > 0 or #kbClearLines > 0 then
		header:SetAttribute("_onstate-eui_cc", [[
			if newstate == "on" then
				if not eui_hoveractive then
					self:RunAttribute("eui_hover_set")
					eui_hoveractive = true
				end
			elseif not (eui_hoverframe and eui_hoverframe:IsUnderMouse()) then
				self:RunAttribute("eui_hover_clear")
				eui_hoveractive = false
				]] .. tconcat(kbClearLines, "\n") .. [[

			end
		]])
		RegisterStateDriver(header, "eui_cc", "[@mouseover,exists] on; off")
	end

	lastBindingCount = #bindings
	lastHoverCount = #hoverBindings
	prevBindings = {}
	for i, b in ipairs(bindings) do
		prevBindings[i] = b
	end
end

-- Re-applies every binding to every frame (out of combat; queued in combat).
function RF.CC_ApplyBindings()
	RF.AfterCombat("cc_apply", ApplyNow)
end
RF.CC_ApplyAll = RF.CC_ApplyBindings

-- One new unit button (called by RF.StyleButton). Preview buttons are not secure.
function RF.CC_SetupButton(btn)
	if not btn or btn.rfKind == "preview" or not btn.RegisterForClicks then
		return
	end
	if ownedFrames[btn] then
		return
	end
	ownedFrames[btn] = true
	local cc = GetClickCastDB()
	if not (cc and cc.enabled) then
		return
	end
	RF.AfterCombat("cc_reg_owned", function()
		if not CC_Init() then
			return
		end
		for frame in pairs(ownedFrames) do
			if not registeredFrames[frame] then
				DoRegisterFrame(frame)
			end
		end
	end)
end

function RF.CC_SetEnabled(enabled)
	local cc = GetClickCastDB()
	if not cc then
		return
	end
	cc.enabled = enabled and true or false
	RF.CC_ApplyBindings()
end

-------------------------------------------------------------------------------
--  Binding CRUD (retail CC_AddSpecBinding ...); specID optional (spec selector)
-------------------------------------------------------------------------------
function RF.CC_AddSpecBinding(binding, specID)
	local cc = GetClickCastDB()
	specID = specID or GetCurrentSpecID()
	if not cc or not specID then
		return
	end
	if binding.enabled == nil then
		binding.enabled = true
	end
	tinsert(SpecList(cc, specID, true), binding)
	RF.CC_ApplyBindings()
end

function RF.CC_RemoveSpecBinding(index, specID)
	local cc = GetClickCastDB()
	specID = specID or GetCurrentSpecID()
	local list = cc and SpecList(cc, specID)
	if not list then
		return
	end
	tremove(list, index)
	RF.CC_ApplyBindings()
end

function RF.CC_AddGlobalBinding(binding)
	local cc = GetClickCastDB()
	if not cc then
		return
	end
	if binding.enabled == nil then
		binding.enabled = true
	end
	tinsert(cc.globals, binding)
	RF.CC_ApplyBindings()
end

function RF.CC_RemoveGlobalBinding(index)
	local cc = GetClickCastDB()
	if not cc then
		return
	end
	tremove(cc.globals, index)
	RF.CC_ApplyBindings()
end

RF.CC_GetActiveBindings = GetActiveBindings
RF.CC_GetSpecBindings = GetSpecBindings
RF.CC_GetGlobalBindings = GetGlobalBindings
RF.CC_GetCurrentSpecID = GetCurrentSpecID
RF.CC_GetCurrentSpecName = GetCurrentSpecName
RF.CC_GetCurrentSpecIcon = GetCurrentSpecIcon
RF.CC_GetClickCastDB = GetClickCastDB
RF.CC_SpecList = SpecList
RF.CC_IsFrameBinding = IsFrameBinding
RF.CC_IsHoverBinding = IsHoverBinding

-- Other bindings that use the same key on a shared path (settings warning).
function RF.CC_FindKeyConflicts(keyStr, exclude)
	local out = {}
	if not keyStr or keyStr == "" then
		return out
	end
	local function Check(b)
		if type(b) == "table" and b ~= exclude and b.key == keyStr and b.enabled ~= false then
			if not exclude or (IsFrameBinding(b) and IsFrameBinding(exclude))
				or (IsHoverBinding(b) and IsHoverBinding(exclude)) then
				if not (exclude and RF.CC_AreComplementaryReactionBindings(b, exclude)) then
					out[#out + 1] = b
				end
			end
		end
	end
	for _, b in ipairs(GetGlobalBindings()) do
		Check(b)
	end
	for _, b in ipairs(GetSpecBindings()) do
		Check(b)
	end
	return out
end

-------------------------------------------------------------------------------
--  Events
-------------------------------------------------------------------------------
OnCCEvent = function(self, event)
	if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
		RF.CC_ApplyBindings()
	elseif event == "SPELLS_CHANGED" then
		if ComputeKnownSignature() ~= knownSig then
			RF.CC_ApplyBindings()
		end
	elseif event == "UPDATE_MACROS" then
		-- A bound macro's body may have changed.
		for _, b in ipairs(prevBindings) do
			if b.type == "macro" and b.macroName then
				RF.CC_ApplyBindings()
				break
			end
		end
	elseif event == "GROUP_ROSTER_UPDATE" then
		local ctx = CurrentCtx()
		if ctx ~= lastRosterCtx then
			lastRosterCtx = ctx
			RF.CC_ApplyBindings()
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		-- OnLeave may not fire across a loading screen: re-apply (also clears
		-- stuck keyboard bindings). Spec data can lag the first one a little.
		lastRosterCtx = CurrentCtx()
		RF.CC_ApplyBindings()
		if RF.After then
			RF.After(2, RF.CC_ApplyBindings)
		end
	end
end

-- Start once the core saved variables exist; the settings window calls
-- ERF:ApplyAll after every change (order 45).
if RF.OnApply then
	RF.OnApply(function()
		RF.CC_ApplyBindings()
	end, 45)
end
do
	local login = CreateFrame("Frame")
	login:RegisterEvent("PLAYER_LOGIN")
	login:SetScript("OnEvent", function(self)
		self:UnregisterEvent("PLAYER_LOGIN")
		RF.CC_ApplyBindings()
	end)
end
