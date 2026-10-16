-- Spec Overrides + Conditional Overrides (retail EllesmereUI_SpecOverrides.lua,
-- the value engine; the condition resolver is EllesmereUI_Conditions.lua and
-- the settings window parts are EllesmereUIOptions\EUI_SpecOverrides_Options.lua).
--
-- Some settings of ONE profile get their own value per spec group or per
-- condition (Dungeon, Raid, Arena, Battleground, Solo, Keybind):
--   * spec groups ("cards"): named sets of specs with an icon;
--   * an entry = one captured setting slot: values.default = the shared value,
--     values[specID] = that spec's value (spec store), values[groupId] = the
--     conditional group's value (conditional store);
--   * on login, spec change and condition change the right values are written
--     into the module SavedVariables and the modules re-apply (ns.applyHooks);
--   * spec values win over conditional values for the same setting;
--   * nothing changes in combat: the change waits for PLAYER_REGEN_ENABLED.
--
-- Storage (this port): the active profile's store is EllesmereUIDB.overrides =
-- { specOverrideGroups, specOverrides, specOverrideNextId, condOverrideGroups,
-- condOverrides, condOverrideNextId, condAppliedGid } (retail key names).
-- Stored profiles carry the same table as profile.overrides, and so do
-- export strings; the profile functions of EllesmereUI_Profiles.lua are
-- wrapped at the end of this file (no edits there).
--
-- fkey = module folder .. "\31" .. path in the module's SavedVariables table
-- (segments joined by "\30"). "__SPECOV_NIL__" = "key not present".
--
-- Left out (retail-only systems): per-group Unlock Mode layouts, Buff /
-- Debuff Manager forks, WoW Forever, Dark Mode condition, Druid Form.

local ns = EllesmereUI
if not ns or not ns.SnapshotProfile or not ns.ProfileDeepCopy then
	return
end

local DeepCopy = ns.ProfileDeepCopy
local FS, PS = "\31", "\30"
local NIL_SENT = "__SPECOV_NIL__"
ns.SPECOV_FS, ns.SPECOV_PS, ns.SPECOV_NIL = FS, PS, NIL_SENT

local SO = {}
ns.SO = SO
local Cond = {}
ns._CondOv = Cond
SO.Cond = Cond
SO.NIL = NIL_SENT

---------------------------------------------------------------------------
-- Specs of Mists of Pandaria (spec IDs are the retail numbers).
-- [specID] = { class token, role }
---------------------------------------------------------------------------
local SPECS = {
	[71] = { "WARRIOR", "DAMAGER" }, [72] = { "WARRIOR", "DAMAGER" }, [73] = { "WARRIOR", "TANK" },
	[65] = { "PALADIN", "HEALER" }, [66] = { "PALADIN", "TANK" }, [70] = { "PALADIN", "DAMAGER" },
	[253] = { "HUNTER", "DAMAGER" }, [254] = { "HUNTER", "DAMAGER" }, [255] = { "HUNTER", "DAMAGER" },
	[259] = { "ROGUE", "DAMAGER" }, [260] = { "ROGUE", "DAMAGER" }, [261] = { "ROGUE", "DAMAGER" },
	[256] = { "PRIEST", "HEALER" }, [257] = { "PRIEST", "HEALER" }, [258] = { "PRIEST", "DAMAGER" },
	[250] = { "DEATHKNIGHT", "TANK" }, [251] = { "DEATHKNIGHT", "DAMAGER" }, [252] = { "DEATHKNIGHT", "DAMAGER" },
	[262] = { "SHAMAN", "DAMAGER" }, [263] = { "SHAMAN", "DAMAGER" }, [264] = { "SHAMAN", "HEALER" },
	[62] = { "MAGE", "DAMAGER" }, [63] = { "MAGE", "DAMAGER" }, [64] = { "MAGE", "DAMAGER" },
	[265] = { "WARLOCK", "DAMAGER" }, [266] = { "WARLOCK", "DAMAGER" }, [267] = { "WARLOCK", "DAMAGER" },
	[268] = { "MONK", "TANK" }, [270] = { "MONK", "HEALER" }, [269] = { "MONK", "DAMAGER" },
	[102] = { "DRUID", "DAMAGER" }, [103] = { "DRUID", "DAMAGER" }, [104] = { "DRUID", "TANK" }, [105] = { "DRUID", "HEALER" },
}
-- Spec order inside each class (the in-game spec index order).
local CLASS_SPECS = {
	WARRIOR = { 71, 72, 73 }, PALADIN = { 65, 66, 70 }, HUNTER = { 253, 254, 255 },
	ROGUE = { 259, 260, 261 }, PRIEST = { 256, 257, 258 }, DEATHKNIGHT = { 250, 251, 252 },
	SHAMAN = { 262, 263, 264 }, MAGE = { 62, 63, 64 }, WARLOCK = { 265, 266, 267 },
	MONK = { 268, 270, 269 }, DRUID = { 102, 103, 104, 105 },
}
SO.SPECS = SPECS
SO.CLASS_SPECS = CLASS_SPECS

function SO.IsMistsSpec(id)
	return SPECS[tonumber(id) or -1] ~= nil
end

local function CurrentSpecID()
	local idx = GetSpecialization and GetSpecialization()
	if not idx or idx == 0 then
		return nil
	end
	local id = GetSpecializationInfo(idx)
	if not id or id == 0 then
		return nil
	end
	return id
end
SO.CurrentSpecID = CurrentSpecID
ns.SpecOverrides_CurrentSpecID = CurrentSpecID

local function ClassName(token)
	local n = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]
	if n then
		return n
	end
	if token == "DEATHKNIGHT" then
		return "Death Knight"
	end
	return token and (token:sub(1, 1) .. token:sub(2):lower()) or "?"
end
SO.ClassName = ClassName

-- "Holy - Paladin"
function SO.SpecName(id)
	local name
	if GetSpecializationInfoByID then
		local _, n = GetSpecializationInfoByID(id)
		name = n
	end
	local cls = SPECS[id] and SPECS[id][1]
	if name and cls then
		return name .. " - " .. ClassName(cls)
	end
	return name or ("Spec " .. tostring(id))
end

function SO.SpecShortName(id)
	if GetSpecializationInfoByID then
		local _, n = GetSpecializationInfoByID(id)
		if n then
			return n
		end
	end
	return "Spec " .. tostring(id)
end

---------------------------------------------------------------------------
-- Storage
---------------------------------------------------------------------------
local function Root(create)
	local db = EllesmereUIDB
	if type(db) ~= "table" then
		if not create then
			return nil
		end
		EllesmereUIDB = {}
		db = EllesmereUIDB
	end
	local r = db.overrides
	if type(r) ~= "table" then
		if not create then
			return nil
		end
		r = {}
		db.overrides = r
	end
	return r
end
SO.Root = Root
ns.SpecOverrides_Root = Root

local function GetStore(create)
	local r = Root(create)
	if not r then
		return nil
	end
	if type(r.specOverrides) ~= "table" and create then
		r.specOverrides = {}
	end
	return r.specOverrides
end
SO.GetStore = GetStore

local function GetGroups(create)
	local r = Root(create)
	if not r then
		return nil
	end
	if type(r.specOverrideGroups) ~= "table" and create then
		r.specOverrideGroups = {}
	end
	return r.specOverrideGroups
end
SO.GetGroups = GetGroups

-- Persisted counter (a reused id would inherit a deleted group's values).
local function NextGroupId()
	local r = Root(true)
	local maxId = 0
	for _, g in ipairs(GetGroups() or {}) do
		if type(g.id) == "number" and g.id > maxId then
			maxId = g.id
		end
	end
	local id = r.specOverrideNextId or 0
	if id < maxId then
		id = maxId
	end
	id = id + 1
	r.specOverrideNextId = id
	return id
end

local function GroupById(id)
	for _, g in ipairs(GetGroups() or {}) do
		if g.id == id then
			return g
		end
	end
	return nil
end
SO.GroupById = GroupById
ns.SpecOverrides_GroupById = GroupById

local function SpecInGroup(g, specID)
	for _, sid in ipairs(g.specs or {}) do
		if sid == specID then
			return true
		end
	end
	return false
end
SO.SpecInGroup = SpecInGroup

local function SpecInAnyGroup(specID)
	if not specID then
		return false
	end
	for _, g in ipairs(GetGroups() or {}) do
		if SpecInGroup(g, specID) then
			return true
		end
	end
	return false
end
SO.SpecInAnyGroup = SpecInAnyGroup

function Cond.GetStore(create)
	local r = Root(create)
	if not r then
		return nil
	end
	if type(r.condOverrides) ~= "table" and create then
		r.condOverrides = {}
	end
	return r.condOverrides
end

---------------------------------------------------------------------------
-- Which settings can be overridden
---------------------------------------------------------------------------
-- Modules with per-spec values (retail list; account level modules such as
-- Bags, QoL, Friends, Damage Meters and the Mists-only modules are left out).
local ELIGIBLE = {
	EllesmereUIActionBars = true,
	EllesmereUINameplates = true,
	EllesmereUIUnitFrames = true,
	EllesmereUIRaidFrames = true,
	EllesmereUIResourceBars = true,
	EllesmereUIMinimap = true,
	EllesmereUIChat = true,
	EllesmereUIDataBars = true,
	EllesmereUICooldownManager = true,
}
SO.ELIGIBLE = ELIGIBLE

-- Single settings that never take an override (matched against every path
-- segment of the fkey).
local SETTING_BLACKLIST = {
	EllesmereUIChat = {
		showFriends = true, showDurability = true, showCopy = true,
		showPortals = true, showVoice = true, showSettings = true,
		showScroll = true, sidebarIconOrder = true,
	},
	EllesmereUICooldownManager = {
		barSpellSettings = true, customActiveStates = true,
		cdmBarPositions = true, growDirection = true,
		specProfiles = true, spells = true,
	},
	EllesmereUIRaidFrames = {
		bmIndicators = true, bmSimple = true, bmDisplayMode = true,
		bmIconZoom = true, bm2 = true, dmDebuff = true, partyFrameStyle = true,
		clickCast = true,
	},
	EllesmereUIUnitFrames = {
		playerAuraBars = true,
	},
}
for _, folder in ipairs({ "EllesmereUIActionBars", "EllesmereUIChat", "EllesmereUICooldownManager",
	"EllesmereUIDataBars", "EllesmereUIMinimap", "EllesmereUIResourceBars", "EllesmereUIUnitFrames" }) do
	SETTING_BLACKLIST[folder] = SETTING_BLACKLIST[folder] or {}
	SETTING_BLACKLIST[folder].visibilityModes = true
	SETTING_BLACKLIST[folder].visibilityMatch = true
end

local function SplitFKey(fkey)
	if type(fkey) ~= "string" then
		return nil
	end
	return fkey:match("^([^\31]+)\31(.*)$")
end
SO.SplitFKey = SplitFKey

local function Segs(path)
	local out = {}
	for seg in (path .. PS):gmatch("(.-)" .. PS) do
		out[#out + 1] = seg
	end
	return out
end

local function BlacklistedFKey(fkey)
	local folder, path = SplitFKey(fkey)
	if not folder then
		return true
	end
	if not ELIGIBLE[folder] then
		return true
	end
	local set = SETTING_BLACKLIST[folder]
	if set and path then
		for _, seg in ipairs(Segs(path)) do
			if set[seg] then
				return true
			end
		end
	end
	return false
end
SO.BlacklistedFKey = BlacklistedFKey

-- Size keys owned by an Unlock Mode width / height match: the match engine
-- writes them, an override value would fight it (retail MatchOwnedFKey).
local MATCH_OWNED = {
	["EllesmereUIResourceBars\31profile\30health\30width"] = { "ERB_Health", "w" },
	["EllesmereUIResourceBars\31profile\30health\30height"] = { "ERB_Health", "h" },
	["EllesmereUIResourceBars\31profile\30primary\30width"] = { "ERB_Power", "w" },
	["EllesmereUIResourceBars\31profile\30primary\30height"] = { "ERB_Power", "h" },
	["EllesmereUIResourceBars\31profile\30secondary\30pipWidth"] = { "ERB_ClassResource", "w" },
	["EllesmereUIResourceBars\31profile\30secondary\30pipHeight"] = { "ERB_ClassResource", "h" },
	["EllesmereUIResourceBars\31profile\30castBar\30width"] = { "ERB_CastBar", "w" },
	["EllesmereUIResourceBars\31profile\30castBar\30height"] = { "ERB_CastBar", "h" },
	["EllesmereUIResourceBars\31profile\30gcdBar\30width"] = { "ERB_GCDBar", "both" },
	["EllesmereUIResourceBars\31profile\30gcdBar\30height"] = { "ERB_GCDBar", "both" },
}

local function MatchOwnedFKey(fkey)
	local info = MATCH_OWNED[fkey]
	if not info or type(EllesmereUIDB) ~= "table" then
		return false
	end
	if info[2] ~= "h" then
		local wm = EllesmereUIDB.unlockWidthMatch
		if type(wm) == "table" and wm[info[1]] ~= nil then
			return true
		end
	end
	if info[2] ~= "w" then
		local hm = EllesmereUIDB.unlockHeightMatch
		if type(hm) == "table" and hm[info[1]] ~= nil then
			return true
		end
	end
	return false
end
SO.MatchOwnedFKey = MatchOwnedFKey

-- Array-indexed paths are refused (a deleted entry would shift the others),
-- except the CDM bar list and the raid size tiers (retail NumAllowedFKey).
function SO.NumAllowedFKey(fkey)
	return (fkey:find("cdmBars\30bars\30", 1, true) or fkey:find("raidSizeOverrides\30", 1, true)) and true or false
end

---------------------------------------------------------------------------
-- Live settings by fkey
---------------------------------------------------------------------------
local function DBFor(folder)
	local entry = ns.ProfileAddonEntry and ns.ProfileAddonEntry(folder)
	if not entry or not IsAddOnLoaded(folder) then
		return nil
	end
	local t = _G[entry.svName]
	return type(t) == "table" and t or nil
end
SO.DBFor = DBFor

local function FKeyLoaded(fkey)
	local folder = SplitFKey(fkey)
	return folder ~= nil and DBFor(folder) ~= nil
end
SO.FKeyLoaded = FKeyLoaded

-- Numeric table keys are stored as strings in the path.
local function SegKey(t, seg)
	if t[seg] ~= nil then
		return seg
	end
	local n = tonumber(seg)
	if n ~= nil and t[n] ~= nil then
		return n
	end
	return seg
end

local function ReadIn(t, path)
	if type(t) ~= "table" then
		return nil
	end
	local segs = Segs(path)
	for i = 1, #segs - 1 do
		t = t[SegKey(t, segs[i])]
		if type(t) ~= "table" then
			return nil
		end
	end
	return t[SegKey(t, segs[#segs])]
end

local function ReadLive(fkey)
	local folder, path = SplitFKey(fkey)
	if not folder then
		return nil
	end
	return ReadIn(DBFor(folder), path)
end
SO.ReadLive = ReadLive

local function WriteLive(fkey, v)
	local folder, path = SplitFKey(fkey)
	local t = folder and DBFor(folder)
	if type(t) ~= "table" then
		return false
	end
	local allowNumNew = path:find("raidSizeOverrides", 1, true) ~= nil
	local segs = Segs(path)
	for i = 1, #segs - 1 do
		local k = SegKey(t, segs[i])
		local nxt = t[k]
		if type(nxt) ~= "table" then
			if v == nil then
				return false
			end
			-- Never build a missing array entry (a deleted bar).
			if tonumber(segs[i]) ~= nil and not allowNumNew then
				return false
			end
			nxt = {}
			local n = tonumber(k)
			if type(k) == "string" and n ~= nil then
				k = n
			end
			t[k] = nxt
		end
		t = nxt
	end
	local k = SegKey(t, segs[#segs])
	if t[k] == nil and v ~= nil then
		local n = tonumber(k)
		if type(k) == "string" and n ~= nil then
			k = n
		end
	end
	t[k] = v
	return true
end
SO.WriteLive = WriteLive

local function SnapValue(snap, fkey)
	local folder, path = SplitFKey(fkey)
	if not snap or not folder then
		return nil
	end
	return ReadIn(snap[folder], path)
end
SO.SnapValue = SnapValue

-- Module defaults: ns.CopyDefaults(defaults, live) calls are recorded, so a
-- "key not present" value can be written as the module's default (writing
-- nil would leave a key the module reads without a fallback).
local _defaultsOf = setmetatable({}, { __mode = "k" })
do
	local origCopyDefaults = ns.CopyDefaults
	if origCopyDefaults then
		ns.CopyDefaults = function(src, dst)
			if type(src) == "table" and type(dst) == "table" then
				_defaultsOf[dst] = src
			end
			return origCopyDefaults(src, dst)
		end
	end
end

-- Modules that merge defaults with their own function.
local DEFAULT_PROVIDERS = {
	EllesmereUIUnitFrames = function()
		return ns.UF and ns.UF.Defaults and ns.UF.Defaults()
	end,
}

local function DefaultFor(fkey)
	local folder, path = SplitFKey(fkey)
	local root = folder and DBFor(folder)
	if not root then
		return nil
	end
	local prov = DEFAULT_PROVIDERS[folder]
	if prov then
		local ok, d = pcall(prov)
		if ok and type(d) == "table" then
			local v = ReadIn(d, path)
			if v ~= nil then
				return v
			end
		end
	end
	local segs = Segs(path)
	local t, src = root, _defaultsOf[root]
	for i = 1, #segs do
		if i == #segs then
			if type(src) ~= "table" then
				return nil
			end
			return src[SegKey(src, segs[i])]
		end
		local nt = type(t) == "table" and t[SegKey(t, segs[i])] or nil
		src = type(src) == "table" and src[SegKey(src, segs[i])] or nil
		if type(nt) == "table" and _defaultsOf[nt] then
			src = _defaultsOf[nt]
		end
		t = nt
	end
	return nil
end
SO.DefaultFor = DefaultFor

-- Is a live value the same as a stored one? "Not present" matches nil and
-- the module default.
local function Same(fkey, live, stored)
	if stored == NIL_SENT then
		if live == nil then
			return true
		end
		local d = DefaultFor(fkey)
		return d ~= nil and live == d
	end
	return live == stored
end
SO.Same = Same

---------------------------------------------------------------------------
-- fkey -> entry indexes
---------------------------------------------------------------------------
local _idx, _cidx
local function Invalidate()
	_idx, _cidx = nil, nil
end
SO.Invalidate = Invalidate

local function BuildIndex(store)
	local idx = {}
	for _, e in ipairs(store or {}) do
		local def = type(e) == "table" and type(e.values) == "table" and e.values.default
		if type(def) == "table" then
			for fkey in pairs(def) do
				idx[fkey] = e
			end
		end
	end
	return idx
end

local function EntryOwning(fkey)
	if not _idx then
		_idx = BuildIndex(GetStore())
	end
	return _idx[fkey]
end
SO.EntryOwning = EntryOwning

function Cond.EntryOwning(fkey)
	if not _cidx then
		_cidx = BuildIndex(Cond.GetStore())
	end
	return _cidx[fkey]
end

---------------------------------------------------------------------------
-- Session state
---------------------------------------------------------------------------
local _activeSpec       -- spec whose values are live
local _editGroup        -- "Editing as <group>" (spec group)
local _defaultView = false -- settings window open: live holds the shared defaults
local _enterSnap        -- module settings when the session started
local _loginDone = false
local _specPending = false
local _refreshPending = false
local _storeSwapped = false -- a profile was applied, a reload follows
local _inTransition = false
Cond._edit = nil        -- "Editing as <conditional group>"

SO.watchSnap = nil      -- rolling snapshot for auto-capture (options window)

function SO.ActiveSpec()
	return _activeSpec
end

function SO.EditGroup()
	return _editGroup
end

function SO.DefaultViewActive()
	return _defaultView
end

function SO.EditSessionActive()
	return _editGroup ~= nil or Cond._edit ~= nil
end
ns.SpecOverrides_EditSessionActive = SO.EditSessionActive

function SO.EditSessionName()
	local g = _editGroup or Cond._edit
	return g and g.name or nil
end

function SO.PanelShown()
	local w = _G.EllesmereUISettings
	return w and w:IsShown() and true or false
end

local function AppliedGid()
	return ns.Conditions_AppliedGid and ns.Conditions_AppliedGid() or nil
end

-- Listeners (the settings window): fn(what), what = "session", "values", "store"
SO.listeners = {}
function SO.Notify(what)
	for _, fn in ipairs(SO.listeners) do
		local ok, err = pcall(fn, what)
		if not ok then
			geterrorhandler()(err)
		end
	end
end

---------------------------------------------------------------------------
-- Module refresh: every module re-applies (the settings window does the same
-- after a change). Waits for the end of combat.
---------------------------------------------------------------------------
local function RunRefresh()
	if InCombatLockdown() then
		_refreshPending = true
		return
	end
	_refreshPending = false
	SO.applying = true
	for _, fn in ipairs(ns.applyHooks or {}) do
		local ok, err = pcall(fn)
		if not ok then
			geterrorhandler()(err)
		end
	end
	SO.applying = false
	if ns.RefreshAllPages then
		pcall(ns.RefreshAllPages)
	end
	SO.Notify("values")
end
SO.RunRefresh = RunRefresh

-- During PLAYER_LOGIN the values are written before the modules build their
-- frames (this core file registered the event first); their re-apply runs on
-- the next frame, after every PLAYER_LOGIN handler.
local _inLogin = false
local deferFrame = CreateFrame("Frame")
deferFrame:Hide()
deferFrame:SetScript("OnUpdate", function(self)
	self:Hide()
	RunRefresh()
end)

local function RunRefreshers(touched)
	if touched and next(touched) then
		if _inLogin then
			deferFrame:Show()
		else
			RunRefresh()
		end
	end
end
---------------------------------------------------------------------------
-- Writers
---------------------------------------------------------------------------
local function WriteValue(fkey, v, touched)
	if BlacklistedFKey(fkey) or MatchOwnedFKey(fkey) or not FKeyLoaded(fkey) then
		return
	end
	if type(v) == "table" then
		return
	end
	local cur = ReadLive(fkey)
	if type(cur) == "table" then
		return
	end
	if v == NIL_SENT then
		local d = DefaultFor(fkey)
		if d ~= nil and type(d) ~= "table" then
			v = d
		elseif cur == nil or type(cur) == "boolean" then
			v = nil
		else
			-- Unknown default for a number / text: leave the key alone
			-- (writing nil could break the module).
			return
		end
	end
	if cur == v then
		return
	end
	if WriteLive(fkey, v) then
		touched[SplitFKey(fkey)] = true
	end
end

-- The spec's values (per setting: its own value, else the shared default).
local function WriteSpecValues(specID, touched)
	for _, entry in ipairs(GetStore() or {}) do
		local vals = type(entry) == "table" and entry.values
		local def = type(vals) == "table" and vals.default
		if type(def) == "table" then
			local m = specID and vals[specID]
			if type(m) ~= "table" then
				m = nil
			end
			for fkey, dv in pairs(def) do
				local v = m and m[fkey]
				if v == nil then
					v = dv
				end
				WriteValue(fkey, v, touched)
			end
		end
	end
end

local function WriteDefaultValues(touched)
	for _, entry in ipairs(GetStore() or {}) do
		local def = type(entry) == "table" and type(entry.values) == "table" and entry.values.default
		if type(def) == "table" then
			for fkey, dv in pairs(def) do
				WriteValue(fkey, dv, touched)
			end
		end
	end
end

-- Conditional values for the active group (nil = no condition: defaults).
-- Spec-owned settings are skipped (spec wins), except while editing that
-- conditional (forSession).
function Cond.WriteValues(gid, forSession, touched)
	for _, entry in ipairs(Cond.GetStore() or {}) do
		local vals = type(entry) == "table" and entry.values
		local def = type(vals) == "table" and vals.default
		if type(def) == "table" then
			local map = gid and vals[gid]
			if type(map) ~= "table" then
				map = nil
			end
			for fkey, dv in pairs(def) do
				if forSession or not EntryOwning(fkey) then
					local v = map and map[fkey]
					if v == nil then
						v = dv
					end
					WriteValue(fkey, v, touched)
				end
			end
		end
	end
end

-- Normal state: the spec's values, then the applied conditional's.
local function WriteCanonical(touched)
	WriteSpecValues(_activeSpec, touched)
	Cond.WriteValues(AppliedGid(), false, touched)
end

---------------------------------------------------------------------------
-- Harvest (live -> store)
---------------------------------------------------------------------------
local function Skip(fkey)
	return BlacklistedFKey(fkey) or MatchOwnedFKey(fkey) or not FKeyLoaded(fkey)
end

local function Stored(live)
	if live == nil then
		return NIL_SENT
	end
	return live
end

-- Drops settings no spec holds a value for, and empty entries. Never by
-- equality with the default alone (the default moves).
local function PruneRedundantValues()
	local store = GetStore()
	if not store then
		return
	end
	local changed = false
	for i = #store, 1, -1 do
		local e = store[i]
		local def = type(e) == "table" and type(e.values) == "table" and e.values.default
		if type(def) ~= "table" then
			table.remove(store, i)
			changed = true
		else
			for fkey, dv in pairs(def) do
				local held = false
				for k, m in pairs(e.values) do
					if k ~= "default" and type(m) == "table" and m[fkey] ~= nil then
						held = true
						break
					end
				end
				if not held then
					local canGC = BlacklistedFKey(fkey)
					if not canGC and FKeyLoaded(fkey) then
						local cur = ReadLive(fkey)
						if type(cur) == "table" or Same(fkey, cur, dv) then
							canGC = true
						end
					end
					if canGC then
						def[fkey] = nil
						changed = true
					end
				end
			end
			if not next(def) then
				table.remove(store, i)
				changed = true
			end
		end
	end
	if changed then
		Invalidate()
	end
end
SO.PruneRedundantValues = PruneRedundantValues

-- Live values of the spec (outside an editing session): only for specs in a
-- group; equal to the default keeps the stored value (not a revert).
local function Harvest(specID)
	if not specID or not SpecInAnyGroup(specID) then
		return
	end
	for _, entry in ipairs(GetStore() or {}) do
		local vals = entry.values
		local def = type(vals) == "table" and vals.default
		if type(def) == "table" then
			local prev = type(vals[specID]) == "table" and vals[specID] or nil
			local m, has = {}, false
			for fkey, dv in pairs(def) do
				local v
				if Skip(fkey) then
					v = prev and prev[fkey]
				else
					local live = ReadLive(fkey)
					if type(live) == "table" or Same(fkey, live, dv) then
						v = prev and prev[fkey]
					else
						v = Stored(live)
					end
				end
				if v ~= nil then
					m[fkey] = v
					has = true
				end
			end
			vals[specID] = has and m or nil
		end
	end
end

-- Live values -> every member spec of the group (end of "Editing as").
-- A value moved back onto the default during the session clears the
-- override; settings the session did not touch keep each member's value.
local function ConflictSpec(entry, group)
	group = group or _editGroup
	if not group or not entry.group or entry.group == group.id then
		return nil
	end
	local og = GroupById(entry.group)
	if not og then
		return nil
	end
	for _, sid in ipairs(group.specs or {}) do
		if SpecInGroup(og, sid) then
			return sid
		end
	end
	return nil
end
SO.ConflictSpec = ConflictSpec

local function HarvestGroup(group)
	if not group then
		return
	end
	for _, entry in ipairs(GetStore() or {}) do
		local vals = entry.values
		local def = type(vals) == "table" and vals.default
		if type(def) == "table" and not ConflictSpec(entry, group) then
			local m, preserve = {}, nil
			for fkey, dv in pairs(def) do
				local live = (not Skip(fkey)) and ReadLive(fkey) or nil
				if Skip(fkey) or type(live) == "table" then
					preserve = preserve or {}
					preserve[fkey] = true
				elseif Same(fkey, live, dv) then
					local s = _enterSnap and SnapValue(_enterSnap, fkey)
					if type(s) == "table" then
						s = nil
					end
					if not _enterSnap or s == live then
						preserve = preserve or {}
						preserve[fkey] = true
					end
				else
					m[fkey] = Stored(live)
				end
			end
			for _, sid in ipairs(group.specs or {}) do
				local prev = type(vals[sid]) == "table" and vals[sid] or nil
				local out = next(m) and DeepCopy(m) or nil
				if preserve and prev then
					for fkey in pairs(preserve) do
						if prev[fkey] ~= nil then
							out = out or {}
							out[fkey] = prev[fkey]
						end
					end
				end
				vals[sid] = out
			end
		end
	end
	PruneRedundantValues()
end

function Cond.PruneRedundant()
	local store = Cond.GetStore()
	if not store then
		return
	end
	local changed = false
	for i = #store, 1, -1 do
		local e = store[i]
		local def = type(e) == "table" and type(e.values) == "table" and e.values.default
		if type(def) ~= "table" then
			table.remove(store, i)
			changed = true
		else
			for fkey in pairs(def) do
				local held = false
				for k, m in pairs(e.values) do
					if k ~= "default" and type(m) == "table" and m[fkey] ~= nil then
						held = true
						break
					end
				end
				if not held then
					def[fkey] = nil
					changed = true
				end
			end
			if not next(def) then
				table.remove(store, i)
				changed = true
			end
		end
	end
	if changed then
		Invalidate()
	end
end

-- Default view edits are edits to the shared values (both stores; a
-- conditional default only where no spec entry owns the setting).
local function HarvestDefaults()
	for _, entry in ipairs(GetStore() or {}) do
		local def = type(entry.values) == "table" and entry.values.default
		if type(def) == "table" then
			for fkey, dv in pairs(def) do
				if not Skip(fkey) then
					local live = ReadLive(fkey)
					if type(live) ~= "table" and not Same(fkey, live, dv) then
						def[fkey] = Stored(live)
					end
				end
			end
		end
	end
	for _, entry in ipairs(Cond.GetStore() or {}) do
		local def = type(entry.values) == "table" and entry.values.default
		if type(def) == "table" then
			for fkey, dv in pairs(def) do
				if not Skip(fkey) and not EntryOwning(fkey) then
					local live = ReadLive(fkey)
					if type(live) ~= "table" and not Same(fkey, live, dv) then
						def[fkey] = Stored(live)
					end
				end
			end
		end
	end
	PruneRedundantValues()
	Cond.PruneRedundant()
end

-- Outside a session: live -> the applied group's map (diff semantics, never
-- cleared on equality) or, with no condition, the default maps.
function Cond.Harvest(gid)
	for _, entry in ipairs(Cond.GetStore() or {}) do
		local vals = entry.values
		local def = type(vals) == "table" and vals.default
		if type(def) == "table" then
			if gid then
				local map = type(vals[gid]) == "table" and vals[gid] or nil
				for fkey, dv in pairs(def) do
					if not EntryOwning(fkey) and not Skip(fkey) then
						local live = ReadLive(fkey)
						if type(live) ~= "table" and not Same(fkey, live, dv) then
							map = map or {}
							vals[gid] = map
							map[fkey] = Stored(live)
						end
					end
				end
				if map and not next(map) then
					vals[gid] = nil
				end
			elseif not (_defaultView or _editGroup or Cond._edit) then
				for fkey, dv in pairs(def) do
					if not EntryOwning(fkey) and not Skip(fkey) then
						local live = ReadLive(fkey)
						if type(live) ~= "table" and not Same(fkey, live, dv) then
							def[fkey] = Stored(live)
						end
					end
				end
			end
		end
	end
	Cond.PruneRedundant()
end

-- End of "Editing as <conditional>": live -> the group's map; a value moved
-- back onto the default during the session clears it.
function Cond.HarvestEdit(g)
	for _, entry in ipairs(Cond.GetStore() or {}) do
		local vals = entry.values
		local def = type(vals) == "table" and vals.default
		if type(def) == "table" then
			local map = type(vals[g.id]) == "table" and vals[g.id] or nil
			for fkey, dv in pairs(def) do
				if not Skip(fkey) then
					local live = ReadLive(fkey)
					if type(live) ~= "table" then
						if Same(fkey, live, dv) then
							local s = _enterSnap and SnapValue(_enterSnap, fkey)
							if type(s) == "table" then
								s = nil
							end
							if map and _enterSnap and s ~= live then
								map[fkey] = nil
							end
						else
							map = map or {}
							vals[g.id] = map
							map[fkey] = Stored(live)
						end
					end
				end
			end
			if map and not next(map) then
				vals[g.id] = nil
			end
		end
	end
	Cond.PruneRedundant()
end

-- Every module's settings (eligible + loaded) as one copy.
local function SnapshotLive()
	local snap = {}
	for folder in pairs(ELIGIBLE) do
		local t = DBFor(folder)
		if t then
			snap[folder] = DeepCopy(t)
		end
	end
	return snap
end
SO.SnapshotLive = SnapshotLive

local function HasAnyEntries()
	local s, c = GetStore(), Cond.GetStore()
	return (s and #s > 0) or (c and #c > 0) or false
end

---------------------------------------------------------------------------
-- Views and editing sessions
---------------------------------------------------------------------------
local function EndSessionState()
	_enterSnap = nil
	SO.watchSnap = nil
end

local function StartSessionState()
	_enterSnap = SnapshotLive()
	SO.watchSnap = SnapshotLive()
end

-- Banks what is live into the store without changing live (profile
-- snapshot / export).
local function Bank()
	if _editGroup then
		HarvestGroup(_editGroup)
	elseif Cond._edit then
		Cond.HarvestEdit(Cond._edit)
	elseif _defaultView then
		HarvestDefaults()
	else
		Harvest(_activeSpec)
		Cond.Harvest(AppliedGid())
	end
end
SO.Bank = Bank

-- Ends every session and the Default view (banking them), restores the
-- normal values and banks those. Logout, profile switch.
function SO.HarvestCurrent()
	if _inTransition or _storeSwapped then
		return
	end
	local touched = {}
	local ended = false
	if Cond._edit then
		local g = Cond._edit
		Cond._edit = nil
		Cond.HarvestEdit(g)
		ended = true
	end
	if _editGroup then
		local g = _editGroup
		_editGroup = nil
		HarvestGroup(g)
		ended = true
	end
	if _defaultView then
		_defaultView = false
		HarvestDefaults()
		ended = true
	end
	if ended then
		EndSessionState()
		WriteCanonical(touched)
	end
	Harvest(_activeSpec)
	Cond.Harvest(AppliedGid())
	RunRefreshers(touched)
	if ended then
		SO.Notify("session")
	end
end
ns.SpecOverrides_HarvestCurrent = SO.HarvestCurrent

-- Default Editing Mode: the settings window shows and edits the shared
-- values while no "Editing as" session is open.
function SO.EnterDefaultView()
	if _defaultView or _editGroup or Cond._edit or _inTransition or _storeSwapped then
		return
	end
	if InCombatLockdown() or not HasAnyEntries() then
		return
	end
	SO.HarvestCurrent()
	_defaultView = true
	local touched = {}
	WriteDefaultValues(touched)
	Cond.WriteValues(nil, false, touched)
	RunRefreshers(touched)
	SO.Notify("session")
end

function SO.ExitDefaultView(restore)
	if not _defaultView then
		return
	end
	_defaultView = false
	HarvestDefaults()
	if restore ~= false then
		local touched = {}
		WriteCanonical(touched)
		RunRefreshers(touched)
	end
	SO.Notify("session")
end

function SO.EnterGroupEdit(g)
	if _editGroup == g or not g or not g.specs or #g.specs == 0 then
		return false
	end
	if InCombatLockdown() then
		ns.Print("Overrides cannot be edited in combat.")
		return false
	end
	if _editGroup then
		SO.ExitGroupEdit(true)
	end
	if Cond._edit then
		Cond.ExitEdit(nil, true)
	end
	SO.ExitDefaultView()
	SO.HarvestCurrent()
	_editGroup = g
	local touched = {}
	WriteSpecValues(g.specs[1], touched)
	RunRefresh()
	StartSessionState()
	SO.Notify("session")
	return true
end

function SO.ExitGroupEdit(noRecheck)
	if not _editGroup then
		return
	end
	local g = _editGroup
	_editGroup = nil
	HarvestGroup(g)
	EndSessionState()
	local touched = {}
	WriteCanonical(touched)
	RunRefresh()
	SO.Notify("session")
	if SO.PanelShown() then
		SO.EnterDefaultView()
	end
	if not noRecheck and ns.Conditions_Recheck then
		ns.Conditions_Recheck()
	end
end

function Cond.EnterEdit(g)
	if Cond._edit == g or not g then
		return false
	end
	if InCombatLockdown() then
		ns.Print("Overrides cannot be edited in combat.")
		return false
	end
	if Cond._edit then
		Cond.ExitEdit(nil, true)
	end
	if _editGroup then
		SO.ExitGroupEdit(true)
	end
	local touched = {}
	if _defaultView then
		-- The window already shows the shared values: that is the baseline.
		SO.ExitDefaultView(false)
	else
		SO.HarvestCurrent()
		WriteDefaultValues(touched)
		Cond.WriteValues(nil, false, touched)
	end
	Cond._edit = g
	Cond.WriteValues(g.id, true, touched)
	RunRefresh()
	StartSessionState()
	SO.Notify("session")
	return true
end

function Cond.ExitEdit(noRestore, noRecheck)
	if not Cond._edit then
		return
	end
	local g = Cond._edit
	Cond._edit = nil
	Cond.HarvestEdit(g)
	EndSessionState()
	local touched = {}
	WriteCanonical(touched)
	RunRefresh()
	SO.Notify("session")
	if not noRestore then
		if SO.PanelShown() then
			SO.EnterDefaultView()
		end
		if not noRecheck and ns.Conditions_Recheck then
			ns.Conditions_Recheck()
		end
	end
end

function SO.CloseEditSessions()
	if _editGroup then
		SO.ExitGroupEdit(true)
	end
	if Cond._edit then
		Cond.ExitEdit(nil, true)
	end
	SO.ExitDefaultView()
end
ns.SpecOverrides_CloseEditSessions = SO.CloseEditSessions

-- Settings window shown / hidden (EUI_SpecOverrides_Options.lua).
function SO.OnPanelShown()
	SO.EnterDefaultView()
end

function SO.OnPanelHidden()
	if _editGroup then
		SO.ExitGroupEdit(true)
	end
	if Cond._edit then
		Cond.ExitEdit(true, true)
	end
	SO.ExitDefaultView()
	if ns.Conditions_Recheck then
		ns.Conditions_Recheck()
	end
end

---------------------------------------------------------------------------
-- Spec changes
---------------------------------------------------------------------------
local function SpecTransition(newSpec)
	_inTransition = true
	local wasSession = _editGroup ~= nil or Cond._edit ~= nil or _defaultView
	if Cond._edit then
		local g = Cond._edit
		Cond._edit = nil
		Cond.HarvestEdit(g)
	elseif _editGroup then
		local g = _editGroup
		_editGroup = nil
		HarvestGroup(g)
	elseif _defaultView then
		_defaultView = false
		HarvestDefaults()
	else
		Harvest(_activeSpec)
		Cond.Harvest(AppliedGid())
	end
	EndSessionState()
	_activeSpec = newSpec
	_inTransition = false
	local touched = {}
	WriteCanonical(touched)
	RunRefreshers(touched)
	if wasSession then
		SO.Notify("session")
	end
	-- The settings window goes back to the shared values.
	if SO.PanelShown() then
		SO.EnterDefaultView()
	end
	if ns.Conditions_Recheck then
		ns.Conditions_Recheck()
	end
end

-- Login, spec change, end of combat. Settings never change in combat.
function SO.CheckSpec()
	if _storeSwapped then
		return
	end
	local spec = CurrentSpecID()
	if not spec then
		return
	end
	if _loginDone and spec == _activeSpec then
		return
	end
	if InCombatLockdown() then
		_specPending = true
		return
	end
	_specPending = false
	if not _loginDone then
		-- First apply of the session: live holds what was saved at logout;
		-- every captured setting is written, so nothing is banked here.
		_loginDone = true
		_activeSpec = spec
		local touched = {}
		WriteSpecValues(spec, touched)
		RunRefreshers(touched)
		if ns.Conditions_Recheck then
			ns.Conditions_Recheck(true)
		end
		return
	end
	SpecTransition(spec)
end

-- Writes the current spec's values + conditional again and refreshes
-- (after group / membership edits).
function SO.Apply()
	if _storeSwapped then
		return
	end
	if InCombatLockdown() then
		SO.applyPending = true
		return
	end
	SO.applyPending = false
	local touched = {}
	if _editGroup then
		WriteSpecValues(_editGroup.specs[1], touched)
	elseif Cond._edit then
		WriteDefaultValues(touched)
		Cond.WriteValues(Cond._edit.id, true, touched)
	elseif _defaultView then
		WriteDefaultValues(touched)
		Cond.WriteValues(nil, false, touched)
	else
		WriteCanonical(touched)
	end
	RunRefreshers(touched)
end
ns.SpecOverrides_Apply = SO.Apply

-- Conditional transition (EllesmereUI_Conditions.lua). Returns false when it
-- cannot run now (combat, editing session); the resolver retries.
function ns.SpecOverrides_CondTransition(oldGid, newGid, establish)
	if _storeSwapped or _inTransition or _editGroup or Cond._edit then
		return false
	end
	if InCombatLockdown() then
		return false
	end
	if _defaultView then
		-- The window shows the shared values; the new conditional is written
		-- when it closes.
		SO.Notify("values")
		return true
	end
	_inTransition = true
	if not establish then
		Cond.Harvest(oldGid)
	end
	_inTransition = false
	local touched = {}
	Cond.WriteValues(newGid, false, touched)
	RunRefreshers(touched)
	SO.Notify("values")
	return true
end

---------------------------------------------------------------------------
-- Auto-capture (options window, while "Editing as"): changes = list of
-- fkeys written by one settings slot; meta = { label, module (folder),
-- page, section, crumb }. Returns a status line and its color.
---------------------------------------------------------------------------
function SO.Capture(changes, meta)
	local condSession = Cond._edit
	if not (_editGroup or condSession) or not meta then
		return nil
	end
	local paths, skippedBlack, skippedNum = {}, nil, nil
	for _, fkey in ipairs(changes) do
		local folder, path = SplitFKey(fkey)
		local numeric = false
		for _, seg in ipairs(Segs(path or "")) do
			if tonumber(seg) then
				numeric = true
				break
			end
		end
		if BlacklistedFKey(fkey) then
			skippedBlack = folder
		elseif numeric and not SO.NumAllowedFKey(fkey) then
			skippedNum = true
		elseif not MatchOwnedFKey(fkey) then
			paths[#paths + 1] = fkey
		end
	end
	if #paths == 0 then
		if skippedBlack then
			if skippedBlack == "EllesmereUICooldownManager" then
				return "Cooldown Manager has its own per-spec system and can't be overridden here.", 1, 0.55, 0.35
			elseif not ELIGIBLE[skippedBlack] then
				return "This module is excluded from Spec Overrides.", 1, 0.55, 0.35
			end
			return "This setting can't be overridden.", 1, 0.55, 0.35
		elseif skippedNum then
			return "That setting is stored by list position and can't be safely overridden.", 1, 0.55, 0.35
		end
		return nil
	end
	if #paths > 12 then
		return nil
	end
	local store = condSession and Cond.GetStore(true) or GetStore(true)
	local owning = condSession and Cond.EntryOwning or EntryOwning
	local entry
	-- A setting already captured keeps its entry.
	for _, fkey in ipairs(paths) do
		local e = owning(fkey)
		if e then
			entry = e
			break
		end
	end
	if not entry then
		for _, e in ipairs(store) do
			if e.slotLabel == meta.label and e.module == meta.module
				and (e.page or "") == (meta.page or "")
				and (e.section or ""):lower() == (meta.section or ""):lower() then
				entry = e
				break
			end
		end
	end
	local isNew = false
	if not entry then
		isNew = true
		entry = {
			label = meta.label,
			slotLabel = meta.label,
			crumb = meta.crumb,
			module = meta.module,
			page = meta.page,
			section = meta.section,
			group = condSession and condSession.id or _editGroup.id,
			values = { default = {} },
		}
		store[#store + 1] = entry
	end
	-- The value before the change is the shared default; live values bank
	-- when the session ends.
	for _, fkey in ipairs(paths) do
		if entry.values.default[fkey] == nil then
			local orig = SnapValue(SO.watchSnap, fkey)
			local ce = Cond.EntryOwning(fkey)
			if ce and ce ~= entry then
				orig = ce.values.default[fkey]
				if orig == NIL_SENT then
					orig = nil
				end
			end
			if type(orig) == "table" then
				orig = nil
			end
			entry.values.default[fkey] = Stored(orig)
			if condSession then
				local gm = entry.values[condSession.id]
				if type(gm) ~= "table" then
					gm = {}
					entry.values[condSession.id] = gm
				end
				gm[fkey] = entry.values.default[fkey]
			end
		end
	end
	Invalidate()
	SO.Notify("store")
	if isNew then
		local name = (condSession or _editGroup).name or "?"
		return format("'%s' is now customized for %s.", meta.label or "?", name), 0.35, 1, 0.35
	end
	return nil
end

---------------------------------------------------------------------------
-- Groups (cards popup)
---------------------------------------------------------------------------
function SO.CreateGroup(specs, name, icon)
	local groups = GetGroups(true)
	local id = NextGroupId()
	if not name or name == "" then
		name = "Group " .. id
	end
	local g = { id = id, name = name, icon = icon or { kind = "role", key = "DAMAGER" }, specs = specs }
	groups[#groups + 1] = g
	SO.Notify("store")
	SO.EnterGroupEdit(g)
	return g
end

-- New membership: added specs take the group's values (from its first
-- member), removed specs lose them when they are in no group any more.
function SO.SetGroupSpecs(g, newSpecs)
	if _editGroup == g then
		SO.ExitGroupEdit(true)
	end
	local oldSet, newSet = {}, {}
	for _, id in ipairs(g.specs or {}) do
		oldSet[id] = true
	end
	for _, id in ipairs(newSpecs) do
		newSet[id] = true
	end
	local seed = g.specs and g.specs[1]
	local store = GetStore() or {}
	g.specs = newSpecs
	for _, entry in ipairs(store) do
		local vals = entry.values
		if type(vals) == "table" and (entry.group == g.id or not ConflictSpec(entry, g)) then
			local seedMap = seed and vals[seed]
			for _, id in ipairs(newSpecs) do
				if not oldSet[id] and type(seedMap) == "table" and next(seedMap) then
					vals[id] = DeepCopy(seedMap)
				end
			end
		end
	end
	for id in pairs(oldSet) do
		if not newSet[id] and not SpecInAnyGroup(id) then
			for _, entry in ipairs(store) do
				if type(entry.values) == "table" and entry.group ~= nil then
					entry.values[id] = nil
				end
			end
		end
	end
	PruneRedundantValues()
	SO.Apply()
	SO.Notify("store")
end

function SO.DeleteGroup(g)
	if _editGroup == g then
		SO.ExitGroupEdit(true)
	end
	local groups = GetGroups()
	if groups then
		for i, gg in ipairs(groups) do
			if gg == g then
				table.remove(groups, i)
				break
			end
		end
	end
	local st = GetStore()
	if st then
		for i = #st, 1, -1 do
			local e = st[i]
			if e.group == g.id then
				-- Retag to another group holding values on the entry, else drop.
				local holder
				for _, og in ipairs(GetGroups() or {}) do
					for _, sid in ipairs(og.specs or {}) do
						local mv = e.values and e.values[sid]
						if type(mv) == "table" and next(mv) then
							holder = og
							break
						end
					end
					if holder then
						break
					end
				end
				if holder then
					e.group = holder.id
				else
					table.remove(st, i)
				end
			end
		end
		for _, sid in ipairs(g.specs or {}) do
			if not SpecInAnyGroup(sid) then
				for _, e in ipairs(st) do
					if e.values and e.group ~= nil then
						e.values[sid] = nil
					end
				end
			end
		end
	end
	Invalidate()
	PruneRedundantValues()
	SO.Apply()
	SO.Notify("store")
end

-- Removes one captured setting (management list). The setting keeps its
-- current live value.
function SO.RemoveEntry(entry, isCond)
	local st = isCond and Cond.GetStore() or GetStore()
	if not st then
		return
	end
	if isCond then
		-- An applied conditional's value is live: put the default back.
		local touched = {}
		local def = entry.values and entry.values.default
		for fkey, dv in pairs(def or {}) do
			if not EntryOwning(fkey) then
				WriteValue(fkey, dv, touched)
			end
		end
		RunRefreshers(touched)
	end
	for i, e in ipairs(st) do
		if e == entry then
			table.remove(st, i)
			break
		end
	end
	Invalidate()
	SO.Notify("store")
end

function Cond.SaveGroup(existing, conds, key, name, icon)
	local g = existing
	if g then
		if name and name ~= "" then
			g.name = name
		end
		if icon then
			g.icon = icon
		end
		g.conds = conds
		g.key = conds.keybind and key or nil
		if not conds.keybind then
			g.keyOn = nil
		end
	else
		local groups = ns.Conditions_GetGroups(true)
		local id = ns.Conditions_NewGroupId()
		if not name or name == "" then
			name = "Conditional " .. id
		end
		g = { id = id, name = name, icon = icon or { kind = "cond", key = "dungeon" }, conds = conds, key = conds.keybind and key or nil }
		groups[#groups + 1] = g
	end
	if ns.Conditions_RebuildKeyBindings then
		ns.Conditions_RebuildKeyBindings()
	end
	if ns.Conditions_Recheck then
		ns.Conditions_Recheck()
	end
	SO.Notify("store")
	return g, existing == nil
end

function Cond.DeleteGroup(g)
	if Cond._edit == g then
		Cond.ExitEdit(nil, true)
	end
	local groups = ns.Conditions_GetGroups and ns.Conditions_GetGroups()
	if groups then
		for i, gg in ipairs(groups) do
			if gg == g then
				table.remove(groups, i)
				break
			end
		end
	end
	local st = Cond.GetStore()
	if st then
		local touched = {}
		for i = #st, 1, -1 do
			local e = st[i]
			if e.group == g.id then
				for fkey, dv in pairs(e.values and e.values.default or {}) do
					if not EntryOwning(fkey) then
						WriteValue(fkey, dv, touched)
					end
				end
				table.remove(st, i)
			elseif e.values then
				e.values[g.id] = nil
			end
		end
		RunRefreshers(touched)
	end
	Invalidate()
	Cond.PruneRedundant()
	if ns.Conditions_RebuildKeyBindings then
		ns.Conditions_RebuildKeyBindings()
	end
	if ns.Conditions_Recheck then
		ns.Conditions_Recheck()
	end
	SO.Notify("store")
end

---------------------------------------------------------------------------
-- Slot status for the gold borders: fkeys read by a settings slot ->
-- "gold" (overridden) with the tooltip, "red" (owned by a group that shares
-- specs with the edited one), or nil.
---------------------------------------------------------------------------
function SO.SlotStatus(fkeys)
	local entry, condEntry
	for fkey in pairs(fkeys) do
		entry = entry or EntryOwning(fkey)
		condEntry = condEntry or Cond.EntryOwning(fkey)
	end
	if not entry and not condEntry then
		return nil
	end
	if entry and _editGroup then
		local conflict = ConflictSpec(entry, _editGroup)
		if conflict then
			return "red", format("This setting already has an override for %s", SO.SpecName(conflict))
		end
	end
	-- "Overridden by:" names (groups holding a value, conditionals).
	local names, seen = {}, {}
	local function Add(n)
		if n and not seen[n] then
			seen[n] = true
			names[#names + 1] = n
		end
	end
	for fkey in pairs(fkeys) do
		local e = EntryOwning(fkey)
		if e and e.values then
			local held = false
			for k, m in pairs(e.values) do
				if type(k) == "number" and type(m) == "table" and m[fkey] ~= nil then
					held = true
					local grouped = false
					for _, g in ipairs(GetGroups() or {}) do
						if SpecInGroup(g, k) then
							Add(g.name or "?")
							grouped = true
						end
					end
					if not grouped then
						Add(SO.SpecName(k))
					end
				end
			end
			if not held and e.group then
				local g = GroupById(e.group)
				if g then
					Add(g.name or "?")
				end
			end
		end
		local ce = Cond.EntryOwning(fkey)
		if ce and ce.values then
			local heldBy
			if e and e.group then
				local og = GroupById(e.group)
				heldBy = og and og.name
			end
			for k, m in pairs(ce.values) do
				if type(k) == "number" and type(m) == "table" and m[fkey] ~= nil then
					local cg = ns.Conditions_GroupById and ns.Conditions_GroupById(k)
					if cg then
						local tag = "conditional"
						if heldBy then
							tag = tag .. ", " .. format("held by '%s'", heldBy)
						end
						Add((cg.name or "?") .. " |cff909090(" .. tag .. ")|r")
					end
				end
			end
		end
	end
	if #names == 0 then
		return "gold", nil
	end
	local tip = "|cffc7a65aOverridden by:|r " .. table.concat(names, ", ")
	if not _editGroup and not Cond._edit then
		tip = tip .. "\n|cff909090Changes here edit the shared default; overrides keep their own values.|r"
	end
	return "gold", tip
end

-- Every captured fkey of both stores (set).
function SO.AllFKeys()
	local out = {}
	for _, st in ipairs({ GetStore() or {}, Cond.GetStore() or {} }) do
		for _, e in ipairs(st) do
			for fkey in pairs(e.values and e.values.default or {}) do
				out[fkey] = true
			end
		end
	end
	return out
end

---------------------------------------------------------------------------
-- Profiles: the store rides with each profile, export and import
-- (wraps EllesmereUI_Profiles.lua functions; no edits there).
---------------------------------------------------------------------------
local _pendingImport

do
	local origSnapshot = ns.SnapshotProfile
	ns.SnapshotProfile = function(...)
		if not _storeSwapped then
			local ok, err = pcall(Bank)
			if not ok then
				geterrorhandler()(err)
			end
		end
		local data = origSnapshot(...)
		local r = Root()
		if type(data) == "table" and r and next(r) then
			data.overrides = DeepCopy(r)
		end
		return data
	end

	local origApply = ns.ApplyProfileData
	ns.ApplyProfileData = function(data, ...)
		origApply(data, ...)
		if type(data) ~= "table" or type(EllesmereUIDB) ~= "table" then
			return
		end
		local ov
		if _pendingImport then
			ov = _pendingImport.v
		else
			ov = data.overrides
		end
		EllesmereUIDB.overrides = type(ov) == "table" and DeepCopy(ov) or nil
		-- A reload follows: nothing may bank the old live values into the
		-- new store any more.
		_storeSwapped = true
		_editGroup, Cond._edit, _defaultView = nil, nil, false
		EndSessionState()
		Invalidate()
	end

	local origImport = ns.ImportProfile
	ns.ImportProfile = function(payload, name, opts)
		local ov = type(payload) == "table" and type(payload.data) == "table" and payload.data.overrides or nil
		_pendingImport = { v = ov }
		local ok, a, b = pcall(origImport, payload, name, opts)
		_pendingImport = nil
		if not ok then
			error(a, 0)
		end
		return a, b
	end
end

-- Profile Sync (EllesmereUI_ProfileSync.lua): override-owned settings never
-- sync. Returns the spec and conditional stores of a profile.
function ns.SyncOverrideStores(profileName)
	local r
	if profileName == nil or (ns.GetActiveProfileName and profileName == ns.GetActiveProfileName()) then
		r = Root()
	else
		local profiles = type(EllesmereUIDB) == "table" and EllesmereUIDB.profiles
		local prof = type(profiles) == "table" and profiles[profileName]
		r = type(prof) == "table" and prof.overrides
	end
	if type(r) ~= "table" then
		return {}
	end
	return { r.specOverrides, r.condOverrides }
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ev:RegisterEvent("PLAYER_TALENT_UPDATE")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:SetScript("OnEvent", function(_, event, arg1)
	if event == "PLAYER_LOGOUT" then
		-- Bank sessions and the current spec; the saved module settings hold
		-- the normal (canonical) values.
		local ok, err = pcall(SO.HarvestCurrent)
		if not ok then
			geterrorhandler()(err)
		end
		return
	end
	if event == "PLAYER_SPECIALIZATION_CHANGED" and arg1 and arg1 ~= "player" then
		return
	end
	if event == "PLAYER_REGEN_ENABLED" then
		if _specPending then
			SO.CheckSpec()
		end
		if SO.applyPending then
			SO.Apply()
		end
		if _refreshPending then
			RunRefresh()
		end
		return
	end
	_inLogin = event == "PLAYER_LOGIN"
	local ok, err = pcall(SO.CheckSpec)
	_inLogin = false
	if not ok then
		geterrorhandler()(err)
	end
end)
