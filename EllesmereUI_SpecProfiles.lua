-- Profile per specialization and profile keybinds (retail
-- EllesmereUI_Profiles.lua: specProfiles, the spec auto-switch handler,
-- Profile Keybinds).
--
-- Saved data (same keys as retail, account wide in EllesmereUIDB):
--   specProfiles    = { [specID] = "profileName" }
--   profileKeybinds = { ["profileName"] = "CTRL-1" }
--
-- Retail switches profile right away on a spec change. In this port a
-- profile switch reloads the UI, so on a spec change (and at login) to a
-- spec that is assigned to another profile EllesmereUI ASKS first: "Switch &
-- Reload" or "Not Now". Never during combat (the question waits for the end
-- of combat), never a reload without the click. "Not Now" is remembered per
-- character until the next spec change.
--
-- A profile keybind is a hardware key press, so it switches and reloads
-- right away (out of combat).

local ns = EllesmereUI

local function DB()
	if type(EllesmereUIDB) ~= "table" then
		EllesmereUIDB = {}
	end
	return EllesmereUIDB
end

local function SpecMap()
	local db = DB()
	if type(db.specProfiles) ~= "table" then
		db.specProfiles = {}
	end
	return db.specProfiles
end

local function Keybinds()
	local db = DB()
	if type(db.profileKeybinds) ~= "table" then
		db.profileKeybinds = {}
	end
	return db.profileKeybinds
end

local function CharKey()
	return (UnitName("player") or "?") .. " - " .. (GetRealmName() or "?")
end

---------------------------------------------------------------------------
-- Spec assignments
---------------------------------------------------------------------------
-- The player's spec ID now, or nil (no spec yet / data not loaded).
function ns.CurrentSpecID()
	local idx = GetSpecialization and GetSpecialization()
	if idx and idx > 0 then
		local id = GetSpecializationInfo(idx)
		if type(id) == "number" and id > 0 then
			return id
		end
	end
	return nil
end

-- Profile assigned to a spec (only if that profile still exists).
function ns.GetSpecProfile(specID)
	local name = specID and SpecMap()[specID]
	if name and ns.ProfileExists(name) then
		return name
	end
	return nil
end

-- Sorted spec IDs assigned to a profile.
function ns.GetProfileSpecs(name)
	local list = {}
	for specID, pName in pairs(SpecMap()) do
		if pName == name then
			list[#list + 1] = specID
		end
	end
	table.sort(list)
	return list
end

-- Retail CollectAssignedSpecs: the spec IDs of a profile for an export
-- string (nil when none).
function ns.CollectAssignedSpecs(name)
	local list = ns.GetProfileSpecs(name)
	return #list > 0 and list or nil
end

-- Replaces every assignment: map = { [profileName] = { [specID] = true } }.
function ns.SetSpecAssignments(map)
	local sp = SpecMap()
	wipe(sp)
	for pName, set in pairs(map) do
		if type(set) == "table" and ns.ProfileExists(pName) then
			for specID, on in pairs(set) do
				if on then
					sp[specID] = pName
				end
			end
		end
	end
end

-- Import: "Auto Assign to Specs". payload.assignedSpecs = spec IDs of the
-- profile in the string (retail and Mists strings); payload.accountSpecProfiles
-- = the full specProfiles of a retail FULL ACCOUNT string. Entries for the
-- imported profile point at its new name; entries for other profiles are
-- kept only when a profile with that name exists here.
function ns.ApplyImportedSpecAssignments(name, payload)
	if type(payload) ~= "table" then
		return
	end
	local sp = SpecMap()
	if type(payload.assignedSpecs) == "table" then
		for _, specID in ipairs(payload.assignedSpecs) do
			specID = tonumber(specID)
			if specID then
				sp[specID] = name
			end
		end
	end
	if type(payload.accountSpecProfiles) == "table" then
		for specID, pName in pairs(payload.accountSpecProfiles) do
			specID = tonumber(specID)
			if specID and type(pName) == "string" then
				if pName == payload.profileName then
					sp[specID] = name
				elseif ns.ProfileExists(pName) then
					sp[specID] = pName
				end
			end
		end
	end
end

-- Does a decoded import carry spec assignments?
function ns.ImportHasSpecAssignments(payload)
	return type(payload) == "table"
		and ((type(payload.assignedSpecs) == "table" and #payload.assignedSpecs > 0)
			or (type(payload.accountSpecProfiles) == "table" and next(payload.accountSpecProfiles) ~= nil))
end

---------------------------------------------------------------------------
-- Profile keybinds: one hidden button per profile, clicked by an override
-- binding (SetOverrideBindingClick, like the other keybinds of this port).
---------------------------------------------------------------------------
local bindOwner = CreateFrame("Frame")
local bindButtons = {}
local bindCount = 0
local bindPending = false

function ns.SwitchProfileFromKeybind(name)
	if not name or name == ns.GetActiveProfileName() or not ns.ProfileExists(name) then
		return
	end
	if InCombatLockdown() then
		ns.Print("Switching profile reloads your UI and is not available in combat.")
		return
	end
	local ok, err = ns.SwitchProfile(name)
	if ok then
		ReloadUI()
	elseif err then
		ns.Print(err)
	end
end

local function BindButton(name)
	local btn = bindButtons[name]
	if not btn then
		bindCount = bindCount + 1
		btn = CreateFrame("Button", "EllesmereUIProfileBind" .. bindCount, UIParent)
		btn:Hide()
		btn:SetScript("OnClick", function(self)
			ns.SwitchProfileFromKeybind(self.profileName)
		end)
		bindButtons[name] = btn
	end
	btn.profileName = name
	return btn
end

-- (Re)binds every saved profile key. Waits for the end of combat.
function ns.ApplyProfileKeybinds()
	if InCombatLockdown() then
		bindPending = true
		return
	end
	bindPending = false
	ClearOverrideBindings(bindOwner)
	for name, key in pairs(Keybinds()) do
		if type(key) == "string" and key ~= "" and ns.ProfileExists(name) then
			SetOverrideBindingClick(bindOwner, true, key, BindButton(name):GetName())
		end
	end
end

function ns.GetProfileKeybind(name)
	return Keybinds()[name]
end

-- key = nil unbinds. A key is used by one profile only.
function ns.SetProfileKeybind(name, key)
	local kb = Keybinds()
	if key and key ~= "" then
		for other, otherKey in pairs(kb) do
			if otherKey == key then
				kb[other] = nil
			end
		end
		kb[name] = key
	else
		kb[name] = nil
	end
	ns.ApplyProfileKeybinds()
end

---------------------------------------------------------------------------
-- Rename / delete follow-up (hooks run by EllesmereUI_Profiles.lua)
---------------------------------------------------------------------------
if ns.RegisterProfileHook then
	ns.RegisterProfileHook("rename", function(oldName, newName)
		local sp = SpecMap()
		for specID, pName in pairs(sp) do
			if pName == oldName then
				sp[specID] = newName
			end
		end
		local kb = Keybinds()
		if kb[oldName] then
			kb[newName] = kb[oldName]
			kb[oldName] = nil
			if bindButtons[oldName] then
				bindButtons[newName] = bindButtons[oldName]
				bindButtons[oldName] = nil
				bindButtons[newName].profileName = newName
			end
			ns.ApplyProfileKeybinds()
		end
	end)
	ns.RegisterProfileHook("delete", function(name)
		local sp = SpecMap()
		for specID, pName in pairs(sp) do
			if pName == name then
				sp[specID] = nil
			end
		end
		if Keybinds()[name] then
			Keybinds()[name] = nil
			ns.ApplyProfileKeybinds()
		end
	end)
end

---------------------------------------------------------------------------
-- Spec change: ask to switch to the assigned profile
---------------------------------------------------------------------------
local lastSpec
local pending, pendingFromChange = false, false

local function Declined()
	local db = DB()
	if type(db.specSwitchDeclined) ~= "table" then
		db.specSwitchDeclined = {}
	end
	return db.specSwitchDeclined
end

local function Ask(specID, target)
	if not (ns.LoadOptions and ns.LoadOptions()) or not ns.ShowConfirmPopup then
		return
	end
	local key = specID .. ":" .. target
	ns.ShowConfirmPopup({
		title = "Switch Profile",
		message = format('%s is assigned to the profile "%s".\n\nSwitch to "%s"? This reloads your UI.',
			ns.SpecName and ns.SpecName(specID) or tostring(specID), target, target),
		confirmText = "Switch & Reload",
		cancelText = "Not Now",
		onConfirm = function()
			-- The spec may have changed again while the popup was open.
			if ns.GetSpecProfile(ns.CurrentSpecID()) ~= target or target == ns.GetActiveProfileName() then
				return
			end
			Declined()[CharKey()] = nil
			local ok, err = ns.SwitchProfile(target)
			if ok then
				ReloadUI()
			elseif err then
				ns.Print(err)
			end
		end,
		onCancel = function()
			Declined()[CharKey()] = key
		end,
	})
end

-- fromChange = a real spec change (always asks); otherwise (login, reload,
-- end of combat) a "Not Now" for this spec and profile is respected.
local function Check(fromChange)
	local specID = ns.CurrentSpecID()
	if not specID then
		return
	end
	local target = ns.GetSpecProfile(specID)
	if not target or target == ns.GetActiveProfileName() then
		return
	end
	local declined = Declined()
	local char = CharKey()
	if fromChange then
		declined[char] = nil
	elseif declined[char] == specID .. ":" .. target then
		return
	end
	if InCombatLockdown() then
		pending = true
		pendingFromChange = pendingFromChange or fromChange
		return
	end
	Ask(specID, target)
end
ns.CheckSpecProfile = Check

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
events:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
events:RegisterEvent("PLAYER_TALENT_UPDATE")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
local entered = false
events:SetScript("OnEvent", function(_, event, unit)
	if event == "PLAYER_LOGIN" then
		ns.ApplyProfileKeybinds()
	elseif event == "PLAYER_REGEN_ENABLED" then
		if bindPending then
			ns.ApplyProfileKeybinds()
		end
		if pending then
			local fromChange = pendingFromChange
			pending, pendingFromChange = false, false
			Check(fromChange)
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		if not entered then
			entered = true
			lastSpec = ns.CurrentSpecID()
			Check(false)
		end
	else
		if event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then
			return
		end
		local specID = ns.CurrentSpecID()
		if not entered or not specID or specID == lastSpec then
			-- Before the first PLAYER_ENTERING_WORLD: it checks.
			return
		end
		-- The first spec known this session (no spec data at login) is not
		-- a change: login rules.
		local first = lastSpec == nil
		lastSpec = specID
		Check(not first)
	end
end)
