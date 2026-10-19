-- Profiles: named profiles, export and import (retail EllesmereUI_Profiles.lua).
--
-- Retail keeps every module on one Lite DB with switchable profiles. In this
-- port each module addon has its own SavedVariables, read when it loads, so:
--   * a profile = a copy of the module SavedVariables (minus private data
--     such as caches and character lists) + some core settings;
--   * the active profile is the live SavedVariables; the others are stored
--     in EllesmereUIDB.profiles;
--   * switching, importing and deleting write the SavedVariables globals and
--     reload the UI (5.4.8 saves the globals by name at logout).
--
-- Strings: retail "!EUI_" strings (LibDeflate + the retail serializer) are
-- read and converted (ns.ProfileRetail, EllesmereUI_ProfilesRetail.lua).
-- This port writes "!EUIM_" strings: same encoding, but module data in the
-- Mists layout, so retail refuses them instead of reading them wrong.

local ns = EllesmereUI

local LibDeflate = LibStub and LibStub("LibDeflate", true)

local RETAIL_PREFIX = "!EUI_"
local MISTS_PREFIX = "!EUIM_"
local PAYLOAD_VERSION = 3

---------------------------------------------------------------------------
-- Serializer (retail, verbatim): Lua table <-> string
---------------------------------------------------------------------------
local Serializer = {}

local function SerializeValue(v, parts)
	local t = type(v)
	if t == "string" then
		parts[#parts + 1] = "s"
		parts[#parts + 1] = #v
		parts[#parts + 1] = ":"
		parts[#parts + 1] = v
	elseif t == "number" then
		parts[#parts + 1] = "n"
		parts[#parts + 1] = tostring(v)
		parts[#parts + 1] = ";"
	elseif t == "boolean" then
		parts[#parts + 1] = v and "T" or "F"
	elseif t == "nil" then
		parts[#parts + 1] = "N"
	elseif t == "table" then
		parts[#parts + 1] = "{"
		local n = #v
		for i = 1, n do
			SerializeValue(v[i], parts)
		end
		for k, val in pairs(v) do
			local kt = type(k)
			if kt == "number" and k >= 1 and k <= n and k == math.floor(k) then
				-- already written in the array part
			else
				parts[#parts + 1] = "K"
				SerializeValue(k, parts)
				SerializeValue(val, parts)
			end
		end
		parts[#parts + 1] = "}"
	end
end

function Serializer.Serialize(tbl)
	local parts = {}
	SerializeValue(tbl, parts)
	return table.concat(parts)
end

local function DeserializeValue(str, pos)
	local tag = str:sub(pos, pos)
	if tag == "s" then
		local colonPos = str:find(":", pos + 1, true)
		if not colonPos then
			return nil, pos
		end
		local len = tonumber(str:sub(pos + 1, colonPos - 1))
		if not len then
			return nil, pos
		end
		return str:sub(colonPos + 1, colonPos + len), colonPos + len + 1
	elseif tag == "n" then
		local semi = str:find(";", pos + 1, true)
		if not semi then
			return nil, pos
		end
		return tonumber(str:sub(pos + 1, semi - 1)), semi + 1
	elseif tag == "T" then
		return true, pos + 1
	elseif tag == "F" then
		return false, pos + 1
	elseif tag == "N" then
		return nil, pos + 1
	elseif tag == "{" then
		local tbl = {}
		local idx = 1
		local p = pos + 1
		local len = #str
		while p <= len do
			local c = str:sub(p, p)
			if c == "}" then
				return tbl, p + 1
			elseif c == "K" then
				local key, val
				key, p = DeserializeValue(str, p + 1)
				val, p = DeserializeValue(str, p)
				if key ~= nil then
					tbl[key] = val
				end
			else
				local val
				val, p = DeserializeValue(str, p)
				tbl[idx] = val
				idx = idx + 1
			end
		end
		return tbl, p
	end
	return nil, pos + 1
end

function Serializer.Deserialize(str)
	if not str or #str == 0 then
		return nil
	end
	local val = DeserializeValue(str, 1)
	return val
end

ns._Serializer = Serializer

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function DeepCopy(src, seen)
	if type(src) ~= "table" then
		return src
	end
	seen = seen or {}
	if seen[src] then
		return seen[src]
	end
	local out = {}
	seen[src] = out
	for k, v in pairs(src) do
		out[DeepCopy(k, seen)] = DeepCopy(v, seen)
	end
	return out
end
ns.ProfileDeepCopy = DeepCopy

local function DB()
	if type(EllesmereUIDB) ~= "table" then
		EllesmereUIDB = {}
	end
	return EllesmereUIDB
end

-- "a.b.c" path helpers (private data inside a SavedVariables table).
local function GetPath(t, path)
	for part in path:gmatch("[^%.]+") do
		if type(t) ~= "table" then
			return nil
		end
		t = t[part]
	end
	return t
end

local function SetPath(t, path, value)
	local parts = {}
	for part in path:gmatch("[^%.]+") do
		parts[#parts + 1] = part
	end
	for i = 1, #parts - 1 do
		if type(t[parts[i]]) ~= "table" then
			if value == nil then
				return
			end
			t[parts[i]] = {}
		end
		t = t[parts[i]]
	end
	t[parts[#parts]] = value
end

---------------------------------------------------------------------------
-- Module registry (display order = retail ADDON_DB_MAP, then the modules
-- only this port has). private = paths in the SavedVariables table that
-- never travel in a profile (caches, character data, one-time markers);
-- they stay as they are on import and switch.
---------------------------------------------------------------------------
local ADDONS = {
	{ folder = "EllesmereUIActionBars", display = "Action Bars", svName = "EllesmereUIActionBarsDB" },
	{ folder = "EllesmereUINameplates", display = "Nameplates", svName = "EllesmereUINameplatesDB" },
	{ folder = "EllesmereUIUnitFrames", display = "Unit Frames", svName = "EllesmereUIUnitFramesDB" },
	{ folder = "EllesmereUIRaidFrames", display = "Raid Frames", svName = "EllesmereUIRaidFramesDB" },
	{ folder = "EllesmereUIResourceBars", display = "Resource Bars", svName = "EllesmereUIResourceBarsDB" },
	{ folder = "EllesmereUIQoL", display = "Quality of Life", svName = "EllesmereUIQoLDB" },
	{ folder = "EllesmereUIBags", display = "Bags", svName = "EllesmereUIBagsDB" },
	{ folder = "EllesmereUIQuestTracker", display = "Quest Tracker", svName = "EllesmereUIQuestTrackerDB" },
	{ folder = "EllesmereUIMinimap", display = "Minimap", svName = "EllesmereUIMinimapDB" },
	{ folder = "EllesmereUIDamageMeters", display = "Damage Meters", svName = "EllesmereUIDamageMetersDB" },
	{ folder = "EllesmereUIChat", display = "Chat", svName = "EllesmereUIChatDB" },
	{ folder = "EllesmereUIDataBars", display = "DataBars", svName = "EllesmereUIDataBarsDB" },
	{ folder = "EllesmereUIBlizzardSkin", display = "Blizzard Skins+", svName = "EllesmereUIBlizzardSkinDB" },
	{ folder = "EllesmereUITopBar", display = "Top Bar", svName = "EllesmereUITopBarDB" },
	{ folder = "EllesmereUIInterruptTracker", display = "Interrupt Tracker", svName = "EllesmereUIInterruptTrackerDB" },
	{ folder = "EllesmereUIReforge", display = "Reforge", svName = "EllesmereUIReforgeDB" },
	{ folder = "EllesmereUICooldownManager", display = "Cooldown Manager", svName = "EllesmereUICooldownManagerDB" },
	{ folder = "EllesmereUIAuraBuffReminders", display = "AuraBuff Reminders", svName = "EllesmereUIAuraBuffRemindersDB" },
	{ folder = "EllesmereUIFriends", display = "Friends List", svName = "EllesmereUIFriendsDB" },
	{ folder = "EllesmereUIChallengeTimer", display = "Challenge Mode Tools", svName = "EllesmereUIChallengeTimerDB" },
	{ folder = "EllesmereUIQuickdraw", display = "Quickdraw", svName = "EllesmereUIQuickdrawDB" },
}
ns.PROFILE_ADDONS = ADDONS

local BY_FOLDER = {}
for _, entry in ipairs(ADDONS) do
	BY_FOLDER[entry.folder] = entry
end
ns.ProfileAddonEntry = function(folder)
	return BY_FOLDER[folder]
end

-- Private paths per module (filled in below, see PRIVATE).
local PRIVATE = {
	EllesmereUIDataBars = { "profile.characters" }, -- character list (gold tooltip)
	EllesmereUIInterruptTracker = { "save", "specCache" }, -- cooldown and spec caches
	EllesmereUIReforge = { "profiles" }, -- per character weights, caps, methods
	EllesmereUITopBar = { "_seeded", "qol._seeded", "qol._cvarSnap" }, -- first-login markers, original spell alert CVars
	EllesmereUIFriends = { "_seeded" }, -- first-login marker
	EllesmereUIQoL = { "_seeded", "cursor._seeded", "movementAlert._seeded", "raidTools._seeded" }, -- first-login markers
	EllesmereUIAuraBuffReminders = { "_seeded" }, -- first-login marker
	EllesmereUIQuickdraw = { "_seeded", "lastMountSpell" }, -- first-login marker, last mount ridden
	EllesmereUICooldownManager = { "_seeded" }, -- first-login marker
	EllesmereUIChallengeTimer = { "_seeded", "_activeRunSplits", "bestObjectiveSplits", "fastestRunSplits" }, -- marker, run splits (per client)
	EllesmereUIQuestTracker = { "_seeded" }, -- first-login marker
	EllesmereUIDamageMeters = { "dm._seeded" }, -- first-login marker
}
ns.PROFILE_PRIVATE = PRIVATE

-- Core settings (EllesmereUIDB root) that ride with a profile.
-- GLOBAL_KEYS = Global Settings (look: theme, accent, fonts, UI scale),
-- LAYOUT_KEYS = Unlock Mode links between elements.
local GLOBAL_KEYS = {
	"fonts", "activeTheme", "accentColor", "customAccentColor", "useClassAccentColor",
	"ppUIScale", "ppUIScaleAuto",
	-- Global Settings > Colors (EllesmereUI_Colors.lua)
	"customColors", "darkMode",
}
local LAYOUT_KEYS = {
	"unlockAnchors", "unlockWidthMatch", "unlockHeightMatch",
	"unlockWidthMatchExtra", "unlockHeightMatchExtra", "phantomBounds",
}
ns.PROFILE_GLOBAL_KEYS = GLOBAL_KEYS
ns.PROFILE_LAYOUT_KEYS = LAYOUT_KEYS

function ns.IsProfileAddonLoaded(folder)
	return IsAddOnLoaded(folder) and true or false
end

---------------------------------------------------------------------------
-- Snapshot / apply
---------------------------------------------------------------------------
-- Copy of a module's saved settings without its private data.
local function SnapshotAddon(entry)
	local root = _G[entry.svName]
	if type(root) ~= "table" then
		return nil
	end
	local copy = DeepCopy(root)
	for _, path in ipairs(PRIVATE[entry.folder] or {}) do
		SetPath(copy, path, nil)
	end
	return copy
end

local function SnapshotKeys(keys)
	local db = DB()
	local out = {}
	for _, k in ipairs(keys) do
		if db[k] ~= nil then
			out[k] = DeepCopy(db[k])
		end
	end
	return out
end

-- The live settings of every loaded module + core settings.
function ns.SnapshotProfile()
	local data = { addons = {} }
	for _, entry in ipairs(ADDONS) do
		if ns.IsProfileAddonLoaded(entry.folder) then
			data.addons[entry.folder] = SnapshotAddon(entry)
		end
	end
	data.globals = SnapshotKeys(GLOBAL_KEYS)
	data.layout = SnapshotKeys(LAYOUT_KEYS)
	return data
end

-- Writes a profile into the live SavedVariables. Only loaded modules are
-- written (5.4.8 does not save a disabled addon's SavedVariables); the
-- others keep their data in the profile. Private data stays. A reload must
-- follow: the modules read their settings when they load.
local function ApplyKeys(keys, values)
	local db = DB()
	for _, k in ipairs(keys) do
		db[k] = DeepCopy(values[k])
	end
end

function ns.ApplyProfileData(data)
	if type(data) ~= "table" then
		return
	end
	for _, entry in ipairs(ADDONS) do
		local blob = data.addons and data.addons[entry.folder]
		if type(blob) == "table" and ns.IsProfileAddonLoaded(entry.folder) then
			local old = _G[entry.svName]
			local root = DeepCopy(blob)
			if type(old) == "table" then
				for _, path in ipairs(PRIVATE[entry.folder] or {}) do
					SetPath(root, path, DeepCopy(GetPath(old, path)))
				end
			end
			_G[entry.svName] = root
		end
	end
	if type(data.globals) == "table" then
		ApplyKeys(GLOBAL_KEYS, data.globals)
	end
	if type(data.layout) == "table" then
		ApplyKeys(LAYOUT_KEYS, data.layout)
	end
end

---------------------------------------------------------------------------
-- Profile store: EllesmereUIDB.profiles[name] = profile data (inactive
-- profiles), { live = true } for the active one (its data is the live
-- SavedVariables). EllesmereUIDB.activeProfile = name.
---------------------------------------------------------------------------
local function Store()
	local db = DB()
	if type(db.profiles) ~= "table" then
		db.profiles = {}
	end
	if type(db.activeProfile) ~= "string" or db.activeProfile == "" then
		db.activeProfile = "Default"
	end
	if type(db.profiles[db.activeProfile]) ~= "table" then
		db.profiles[db.activeProfile] = { live = true }
	end
	return db.profiles, db
end

function ns.GetActiveProfileName()
	local _, db = Store()
	return db.activeProfile
end

-- Sorted names, "Default" first.
function ns.GetProfileNames()
	local profiles = Store()
	local names = {}
	for name in pairs(profiles) do
		names[#names + 1] = name
	end
	table.sort(names, function(a, b)
		if a == "Default" then
			return b ~= "Default"
		elseif b == "Default" then
			return false
		end
		return a:lower() < b:lower()
	end)
	return names
end

function ns.ProfileExists(name)
	local profiles = Store()
	return profiles[name] ~= nil
end

-- Profile hooks for the other profile files (spec assignments, keybinds,
-- sync groups): ns.RegisterProfileHook(kind, fn).
--   "rename" (oldName, newName), "delete" (name),
--   "leave" (name): the active profile was just stored (a switch or an
--   import follows), "change" (): the list of profiles changed.
local profileHooks = {}
function ns.RegisterProfileHook(kind, fn)
	profileHooks[kind] = profileHooks[kind] or {}
	tinsert(profileHooks[kind], fn)
end
-- (5.4.8 xpcall takes no arguments for the function: a closure.)
local function RunHooks(kind, a, b)
	local handler = geterrorhandler()
	for _, fn in ipairs(profileHooks[kind] or {}) do
		xpcall(function() fn(a, b) end, handler)
	end
end

-- Makes data the live settings under a new active name; the current live
-- settings are stored under the old name first. Caller reloads.
local function Activate(name, data)
	local profiles, db = Store()
	local current = db.activeProfile
	if current ~= name then
		profiles[current] = ns.SnapshotProfile()
		RunHooks("leave", current)
	end
	ns.ApplyProfileData(data)
	profiles[name] = { live = true }
	db.activeProfile = name
end

-- Switch to a stored profile. Returns ok, error.
function ns.SwitchProfile(name)
	local profiles, db = Store()
	if name == db.activeProfile then
		return false, "This profile is already active."
	end
	local data = profiles[name]
	if type(data) ~= "table" then
		return false, "Profile not found."
	end
	Activate(name, data)
	return true
end

-- New profile = copy of the current settings, made active.
function ns.CopyProfile(name)
	if ns.ProfileExists(name) then
		return false, "Name Taken"
	end
	local profiles, db = Store()
	profiles[db.activeProfile] = ns.SnapshotProfile()
	profiles[name] = { live = true }
	db.activeProfile = name
	RunHooks("change")
	return true
end

function ns.RenameProfile(oldName, newName)
	local profiles, db = Store()
	if not profiles[oldName] then
		return false, "Profile not found."
	end
	if profiles[newName] then
		return false, "Name Taken"
	end
	profiles[newName] = profiles[oldName]
	profiles[oldName] = nil
	if db.activeProfile == oldName then
		db.activeProfile = newName
	end
	RunHooks("rename", oldName, newName)
	RunHooks("change")
	return true
end

-- Deleting the active profile switches to another one (reload needed:
-- returns true, true then).
function ns.DeleteProfile(name)
	local profiles, db = Store()
	if not profiles[name] then
		return false, "Profile not found."
	end
	local names = ns.GetProfileNames()
	if #names <= 1 then
		return false, "You cannot delete your only profile."
	end
	if db.activeProfile ~= name then
		profiles[name] = nil
		RunHooks("delete", name)
		RunHooks("change")
		return true, false
	end
	local nextName
	for _, n in ipairs(names) do
		if n ~= name then
			nextName = n
			break
		end
	end
	local data = profiles[nextName]
	profiles[name] = nil
	ns.ApplyProfileData(data)
	profiles[nextName] = { live = true }
	db.activeProfile = nextName
	RunHooks("delete", name)
	RunHooks("change")
	return true, true
end

---------------------------------------------------------------------------
-- Encode / decode
---------------------------------------------------------------------------
local function Encode(prefix, payload)
	if not LibDeflate then
		return nil
	end
	local compressed = LibDeflate:CompressDeflate(Serializer.Serialize(payload))
	return prefix .. LibDeflate:EncodeForPrint(compressed)
end

-- Export the live settings. folders = set of folders to include (nil = all
-- loaded); includeLayout / includeGlobals = core settings.
function ns.ExportProfile(folders, includeLayout, includeGlobals)
	local data = ns.SnapshotProfile()
	for folder in pairs(data.addons) do
		if folders and not folders[folder] then
			data.addons[folder] = nil
		end
	end
	if not includeGlobals then
		data.globals = nil
	end
	if not includeLayout then
		data.layout = nil
	end
	data.profileName = ns.GetActiveProfileName()
	-- Retail "Auto Assign to Specs": the specs this profile is assigned to.
	data.assignedSpecs = ns.CollectAssignedSpecs and ns.CollectAssignedSpecs(data.profileName) or nil
	return Encode(MISTS_PREFIX, { version = PAYLOAD_VERSION, type = "full", client = "mists", data = data })
end

-- Returns payload (data in the Mists layout, retail strings converted) or
-- nil, error. payload.fromRetail = true for a retail string;
-- payload.notes = list of lines about what a retail string lost.
function ns.DecodeProfileString(str)
	if type(str) ~= "string" then
		return nil, "Invalid string"
	end
	str = str:gsub("^%s+", ""):gsub("%s+$", "")
	if #str < 6 then
		return nil, "Invalid string"
	end
	local prefix
	if str:sub(1, #MISTS_PREFIX) == MISTS_PREFIX then
		prefix = MISTS_PREFIX
	elseif str:sub(1, #RETAIL_PREFIX) == RETAIL_PREFIX then
		prefix = RETAIL_PREFIX
	elseif str:sub(1, 8) == "!EUICDM_" then
		return nil, "This is an old CDM Bar Layout string. Cooldown Manager does not exist in Mists of Pandaria."
	else
		return nil, "Not a valid EllesmereUI string. Make sure you copied the entire string."
	end
	if not LibDeflate then
		return nil, "LibDeflate not available"
	end
	local decoded = LibDeflate:DecodeForPrint(str:sub(#prefix + 1))
	if not decoded then
		return nil, "Failed to decode string"
	end
	local decompressed = LibDeflate:DecompressDeflate(decoded)
	if not decompressed then
		return nil, "Failed to decompress data"
	end
	local ok, payload = pcall(Serializer.Deserialize, decompressed)
	if not ok or type(payload) ~= "table" or type(payload.data) ~= "table" then
		return nil, "Failed to deserialize data"
	end
	-- Retail strings and older Mists strings carry the old module folders.
	ns.RenameModuleFolders(payload.data)
	if not payload.version or payload.version < 3 then
		return nil, "This profile was created before the beta wipe and is no longer compatible. Please create a new export."
	end
	if payload.version > PAYLOAD_VERSION then
		return nil, "This profile was created with a newer version of EllesmereUI. Please update your addon."
	end
	-- Spec assignments (import toggle "Auto Assign to Specs"): a profile
	-- string carries a list of spec IDs, a retail full account string the
	-- whole specProfiles map.
	local accountSpecProfiles
	if payload.fullExport or payload.type == "fullaccount" or payload.type == "full_account" then
		if prefix == RETAIL_PREFIX then
			-- Full account string: the account root + profiles[active].
			local acct = payload.data
			local name = acct.activeProfile or payload.profileName
			local inner = type(acct.profiles) == "table" and name and acct.profiles[name]
			if type(inner) ~= "table" then
				return nil, "This retail FULL ACCOUNT export has no profile in it. Export a normal profile on retail instead (Global Settings > Profiles > Export Profile)."
			end
			if type(acct.specProfiles) == "table" and next(acct.specProfiles) then
				accountSpecProfiles = DeepCopy(acct.specProfiles)
			end
			inner = DeepCopy(inner)
			inner.profileName = name
			inner.uiScale = inner.uiScale or acct.ppUIScale
			-- Cooldown Manager spell lists live on the account root here.
			local sa = acct.spellAssignments
			if not inner.cdmSpells and type(sa) == "table" then
				local bucket = type(sa.profiles) == "table" and sa.profiles[name]
				local sp = type(bucket) == "table" and bucket.specProfiles or sa.specProfiles
				if type(sp) == "table" and next(sp) then
					inner.cdmSpells = DeepCopy(sp)
				end
			end
			if not inner.blizzSkinGlobals and ns.ProfileRetail and ns.ProfileRetail.PickBlizzSkinGlobals then
				inner.blizzSkinGlobals = ns.ProfileRetail.PickBlizzSkinGlobals(acct)
			end
			payload.data = inner
		end
	end
	local assignedSpecs = type(payload.data.assignedSpecs) == "table" and DeepCopy(payload.data.assignedSpecs) or nil
	if prefix == RETAIL_PREFIX or payload.client ~= "mists" then
		if not ns.ProfileRetail then
			return nil, "Retail profile conversion is not available."
		end
		local converted, notes = ns.ProfileRetail.Convert(payload.data)
		if not converted then
			return nil, notes or "This retail profile could not be converted."
		end
		return {
			fromRetail = true,
			data = converted,
			notes = notes or {},
			profileName = payload.data.profileName,
			assignedSpecs = assignedSpecs,
			accountSpecProfiles = accountSpecProfiles,
		}
	end
	if type(payload.data.addons) ~= "table" then
		payload.data.addons = {}
	end
	return { fromRetail = false, data = payload.data, notes = {}, profileName = payload.data.profileName,
		assignedSpecs = assignedSpecs }
end

-- Import a decoded payload as a new profile and make it active (caller
-- reloads). opts.folders = set of folders to take from the string (the
-- other modules keep the current settings), opts.includeLayout,
-- opts.includeGlobals, opts.assignSpecs ("Auto Assign to Specs": the
-- spec assignments in the string point at the new profile).
function ns.ImportProfile(payload, name, opts)
	if type(payload) ~= "table" or type(payload.data) ~= "table" then
		return false, "Invalid import string."
	end
	if type(name) ~= "string" or name == "" then
		return false, "*Please enter a profile name"
	end
	if ns.ProfileExists(name) then
		return false, "Name Taken"
	end
	opts = opts or {}
	local incoming = payload.data
	local data = ns.SnapshotProfile()
	for folder, blob in pairs(incoming.addons or {}) do
		if BY_FOLDER[folder] and (not opts.folders or opts.folders[folder]) then
			data.addons[folder] = DeepCopy(blob)
		end
	end
	if opts.includeGlobals and type(incoming.globals) == "table" then
		for k, v in pairs(incoming.globals) do
			data.globals[k] = DeepCopy(v)
		end
	end
	if opts.includeLayout and type(incoming.layout) == "table" then
		data.layout = DeepCopy(incoming.layout)
	end
	Activate(name, data)
	if opts.assignSpecs and ns.ApplyImportedSpecAssignments then
		ns.ApplyImportedSpecAssignments(name, payload)
	end
	RunHooks("change")
	return true
end
