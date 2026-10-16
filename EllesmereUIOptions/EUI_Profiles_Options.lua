-- Profiles (retail EUI_Profiles_Options.lua, own sidebar row under Global Settings): active
-- profile, new / rename / delete, Export Profile with an addon checklist,
-- Import Profile (paste, then pick addons). Imports read retail "!EUI_"
-- strings too (converted in the core, EllesmereUI_ProfilesRetail.lua).
--
-- Assign to Spec (retail spec assignment popup, EllesmereUI_Presets.lua):
-- a profile switch reloads the UI in this port, so on a change to an
-- assigned spec EllesmereUI asks before it switches (EllesmereUI_SpecProfiles.lua).
-- Profile Keybinds: one key per profile, switches and reloads.
-- Auto Assign to Specs on import (spec assignments in the string).
-- Profile Sync: the sync icons in the sidebar (EllesmereUI_ProfileSync.lua).
-- Overrides tab (spec / conditional overrides list): added to this module by
-- EUI_SpecOverrides_Options.lua (ns.SpecOverridesPage).
--
-- Left out: Popular Presets (retail website).

local ns = EllesmereUI

if not ns.ExportProfile then
	return
end

local ICONS = ns.MEDIA .. "icons\\"

local state = {
	mode = "main", -- "main" or "import"
	rev = 0,
	exportSel = nil, -- folder -> true
	includeLayout = true,
	includeGlobals = true,
	payload = nil,
	importSel = nil,
	importName = "",
	importLayout = true,
	importGlobals = true,
	importAssign = false, -- "Auto Assign to Specs"
}

local function Rebuild(mode)
	state.mode = mode or state.mode
	state.rev = state.rev + 1
	if ns.RebuildSettingsPage then
		ns.RebuildSettingsPage()
	end
end

local function ExportSelection()
	if not state.exportSel then
		state.exportSel = {}
		for _, entry in ipairs(ns.PROFILE_ADDONS) do
			if ns.IsProfileAddonLoaded(entry.folder) then
				state.exportSel[entry.folder] = true
			end
		end
	end
	return state.exportSel
end

local function Count(set)
	local n = 0
	for _ in pairs(set) do
		n = n + 1
	end
	return n
end

local function LoadedCount()
	local n = 0
	for _, entry in ipairs(ns.PROFILE_ADDONS) do
		if ns.IsProfileAddonLoaded(entry.folder) then
			n = n + 1
		end
	end
	return n
end

local function ReloadPopup(title, message)
	ns.ShowConfirmPopup({
		title = title,
		message = message,
		confirmText = "Reload Now",
		hideCancel = true,
		reload = true,
		onDismiss = function() ReloadUI() end,
	})
end

---------------------------------------------------------------------------
-- Export
---------------------------------------------------------------------------
local function DoExport()
	local sel = ExportSelection()
	if next(sel) == nil then
		ns.ShowInfoPopup({ title = "Export Profile", content = "Choose at least one addon to export." })
		return
	end
	local str = ns.ExportProfile(sel, state.includeLayout, state.includeGlobals)
	if not str then
		ns.ShowInfoPopup({ title = "Export Profile", content = "LibDeflate not available" })
		return
	end
	ns.ShowStringPopup({ title = "Export Profile", subtitle = "Copy the string below and share it", text = str })
end

---------------------------------------------------------------------------
-- Import
---------------------------------------------------------------------------
local function UniqueName(base)
	base = (base and base ~= "") and base or "Imported"
	if not ns.ProfileExists(base) then
		return base
	end
	local i = 2
	while ns.ProfileExists(base .. " " .. i) do
		i = i + 1
	end
	return base .. " " .. i
end

local function CanImport(folder)
	local p = state.payload
	return p and p.data.addons and p.data.addons[folder] ~= nil and ns.IsProfileAddonLoaded(folder)
end

local function StartImport(str)
	local payload, err = ns.DecodeProfileString(str)
	if not payload then
		ns.ShowInfoPopup({ title = "Import Failed", content = err or "Invalid import string." })
		return
	end
	state.payload = payload
	state.importSel = {}
	for _, entry in ipairs(ns.PROFILE_ADDONS) do
		if CanImport(entry.folder) then
			state.importSel[entry.folder] = true
		end
	end
	if next(state.importSel) == nil and not payload.data.globals then
		state.payload = nil
		ns.ShowInfoPopup({ title = "Import Failed", content = "This string has no settings for the addons you have loaded." })
		return
	end
	state.importName = UniqueName(payload.profileName or (payload.fromRetail and "Retail" or "Imported"))
	state.importLayout = payload.data.layout ~= nil
	state.importGlobals = payload.data.globals ~= nil
	-- Retail: off for a profile string; a full account string carries its
	-- spec assignments as part of the account.
	state.importAssign = payload.accountSpecProfiles ~= nil
	Rebuild("import")
end

local function ShowPaste()
	ns.ShowStringPopup({
		title = "Import Profile",
		subtitle = "Paste a profile string from EllesmereUI (Mists or retail)",
		editable = true,
		confirmText = "Continue",
		onConfirm = StartImport,
	})
end

-- First time setup "Import Profile": the Profiles page with the paste box.
ns.OpenProfileImport = function()
	if ns.OpenSettingsModule then
		state.payload = nil
		if state.mode ~= "main" then
			state.mode = "main"
			state.rev = state.rev + 1
		end
		ns.OpenSettingsModule("profiles")
	end
	ShowPaste()
end

local function DoImport()
	local name = strtrim(state.importName or "")
	if name == "" then
		ns.ShowInfoPopup({ title = "Import Profile", content = "*Please enter a profile name" })
		return
	end
	if ns.ProfileExists(name) then
		ns.ShowConfirmPopup({
			title = "Name Taken",
			message = format('A profile named "%s" already exists. Choose a different name.', name),
			confirmText = "OK",
			hideCancel = true,
		})
		return
	end
	if InCombatLockdown() then
		ns.ShowInfoPopup({ title = "Import Profile", content = "Importing reloads the UI and cannot run in combat. Leave combat and try again." })
		return
	end
	local ok, err = ns.ImportProfile(state.payload, name, {
		folders = state.importSel,
		includeLayout = state.importLayout,
		includeGlobals = state.importGlobals,
		assignSpecs = state.importAssign and ns.ImportHasSpecAssignments and ns.ImportHasSpecAssignments(state.payload),
	})
	if not ok then
		ns.ShowInfoPopup({ title = "Import Failed", content = err or "Unknown error" })
		return
	end
	state.payload = nil
	state.mode = "main"
	ReloadPopup("Profile Imported", "Reload to finish importing.")
end

---------------------------------------------------------------------------
-- Profile management
---------------------------------------------------------------------------
local function ConfirmSwitch(name)
	if name == ns.GetActiveProfileName() then
		return
	end
	ns.ShowConfirmPopup({
		title = "Switch Profile",
		message = format('Switch to the profile "%s"? Your current settings are kept in "%s". This reloads your UI.', name, ns.GetActiveProfileName()),
		confirmText = "Switch & Reload",
		cancelText = "Cancel",
		onConfirm = function()
			local ok, err = ns.SwitchProfile(name)
			if ok then
				ReloadUI()
			else
				ns.ShowInfoPopup({ title = "Switch Profile", content = err })
			end
		end,
	})
end

local function NewProfile()
	ns.ShowInputPopup({
		title = "Copy Profile",
		message = "Enter a name for the new profile:",
		text = "My Profile",
		confirmText = "Save",
		cancelText = "Cancel",
		onConfirm = function(text)
			text = strtrim(text or "")
			if text == "" then
				return
			end
			local ok, err = ns.CopyProfile(text)
			if not ok then
				ns.ShowConfirmPopup({ title = err == "Name Taken" and "Name Taken" or "Copy Profile",
					message = err == "Name Taken" and format('A profile named "%s" already exists.', text) or err,
					confirmText = "OK", hideCancel = true })
				return
			end
			-- Rebuilt: the keybind rows list every profile.
			Rebuild()
		end,
	})
end

local function RenameProfile()
	local old = ns.GetActiveProfileName()
	ns.ShowInputPopup({
		title = "Rename Profile",
		message = "Enter a new name for this profile:",
		text = old,
		confirmText = "Rename",
		cancelText = "Cancel",
		onConfirm = function(text)
			text = strtrim(text or "")
			if text == "" or text == old then
				return
			end
			local ok, err = ns.RenameProfile(old, text)
			if not ok then
				ns.ShowConfirmPopup({ title = err == "Name Taken" and "Name Taken" or "Rename Profile",
					message = err == "Name Taken" and format('A profile named "%s" already exists.', text) or err,
					confirmText = "OK", hideCancel = true })
				return
			end
			-- Rebuilt: the keybind rows list every profile.
			Rebuild()
		end,
	})
end

local deleteChoice

local function DeleteProfile()
	local name = deleteChoice or ns.GetActiveProfileName()
	if #ns.GetProfileNames() <= 1 then
		ns.ShowInfoPopup({ title = "Delete Profile", content = "You cannot delete your only profile." })
		return
	end
	local active = name == ns.GetActiveProfileName()
	ns.ShowConfirmPopup({
		title = "Delete Profile",
		message = format('Delete the profile "%s"?', name)
			.. (active and "\n\nIt is the active profile: EUI switches to another profile and reloads your UI." or ""),
		disclaimer = "This cannot be undone. Export your own profile as a backup first.",
		confirmText = active and "Delete & Reload" or "Delete",
		cancelText = "Cancel",
		onCancel = function()
			deleteChoice = nil
			if ns.RefreshAllPages then
				ns.RefreshAllPages()
			end
		end,
		onConfirm = function()
			local ok, reload = ns.DeleteProfile(name)
			if not ok then
				ns.ShowInfoPopup({ title = "Delete Profile", content = reload })
				return
			end
			deleteChoice = nil
			if reload then
				ReloadUI()
			else
				Rebuild()
			end
		end,
	})
end

local function NameItems()
	local items = {}
	for _, name in ipairs(ns.GetProfileNames()) do
		items[#items + 1] = { name = name, value = name }
	end
	return items
end

---------------------------------------------------------------------------
-- Assign to Spec (retail: a temporary { [profile] = { [specID] = true } }
-- map for the popup, written back on Done)
---------------------------------------------------------------------------
local function SpecSummary(name)
	local specs = ns.GetProfileSpecs and ns.GetProfileSpecs(name) or {}
	if #specs == 0 then
		return "Not assigned to any spec."
	end
	local names = {}
	for i, specID in ipairs(specs) do
		names[i] = ns.SpecName(specID)
	end
	return "Assigned to: " .. table.concat(names, ", ")
end

local function AssignToSpec()
	local temp = { _profileSpecs = {} }
	for _, name in ipairs(ns.GetProfileNames()) do
		temp._profileSpecs[name] = {}
	end
	local map = type(EllesmereUIDB) == "table" and EllesmereUIDB.specProfiles or {}
	for specID, name in pairs(map) do
		if temp._profileSpecs[name] then
			temp._profileSpecs[name][specID] = true
		end
	end
	ns.ShowSpecAssignPopup({
		db = temp,
		dbKey = "_profileSpecs",
		presetKey = ns.GetActiveProfileName(),
		onDone = function()
			ns.SetSpecAssignments(temp._profileSpecs)
			Rebuild()
		end,
	})
end

---------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------
local function BuildMain(p)
	p:ActionCards({
		{ icon = { ICONS .. "import", 1, 1 },
		  title = "Import Profile", desc = "Import a profile from string.",
		  onClick = ShowPaste },
		{ icon = { ICONS .. "export", 1, 1 },
		  title = "Export Profile", desc = "Export the addons checked below.",
		  onClick = DoExport },
	})

	p:Section("Profiles")
	p:Dropdown("Active Profile", "The profile you use now. Choosing another one saves your current settings in this profile, loads the other one and reloads your UI.",
		NameItems,
		function() return ns.GetActiveProfileName() end,
		function() return ns.GetActiveProfileName() end,
		ConfirmSwitch)
	p:Button("New Profile", "Saves a copy of your current settings as a new profile and makes it active. No reload needed.", "Copy Profile", NewProfile)
	p:Button("Rename Profile", "Renames the active profile.", "Rename", RenameProfile)
	p:Dropdown("Delete Profile", "Deletes a profile. Deleting the active profile switches to another one and reloads your UI.",
		NameItems,
		function() return deleteChoice or ns.GetActiveProfileName() end,
		function() return deleteChoice or ns.GetActiveProfileName() end,
		function(v)
			deleteChoice = v
			DeleteProfile()
		end)
	if ns.ShowFirstInstall then
		p:Button("First Time Setup", "Open the welcome popup again: choose which EllesmereUI addons are enabled, or import a profile. Same as /eui setup.", "Open", function() ns.ShowFirstInstall() end)
		p:Blank()
	end

	if ns.ShowSpecAssignPopup and ns.SetSpecAssignments then
		p:Section("Assign to Spec")
		p:Paragraph("Assign the active profile to specializations. When you change to an assigned spec, EllesmereUI asks to switch to its profile (switching reloads your UI). Never during combat.\n\n"
			.. SpecSummary(ns.GetActiveProfileName()))
		p:Button("Assign to Spec", "Choose which specs use the active profile. Specs assigned to another profile are grayed out.", "Assign to Spec", AssignToSpec)
	end

	if ns.SetProfileKeybind then
		p:Section("Profile Keybinds")
		p:Paragraph("Press a key to switch to a profile. Switching reloads your UI and is not available in combat.")
		for _, name in ipairs(ns.GetProfileNames()) do
			p:Keybind(name, "Left-click to set a keybind.\nRight-click to unbind.\nSwitches to this profile and reloads your UI.",
				function() return ns.GetProfileKeybind(name) end,
				function(key) ns.SetProfileKeybind(name, key) end)
		end
	end

	if ns.OpenSyncPopup then
		p:Section("Profile Sync")
		p:Paragraph("Syncing allows you to auto update all profiles whenever you change settings. This can be enabled per module: click the sync icon next to a module in the sidebar. Position and size settings are not synced and keep each profile's own values.")
	end

	p:Section("Export Profile")
	p:Paragraph("Choose which addons to include in your exported profile. Check everything for a full profile export.")
	for _, entry in ipairs(ns.PROFILE_ADDONS) do
		local folder = entry.folder
		local loaded = ns.IsProfileAddonLoaded(folder)
		p:Toggle(entry.display, loaded and ("Include " .. entry.display .. " in the export.") or "Addon not loaded",
			function() return ExportSelection()[folder] and true or false end,
			function(v) ExportSelection()[folder] = v and true or nil end,
			function() return not loaded end)
	end
	p:Button("Select All", "Check every loaded addon.", "Select All", function()
		local sel = ExportSelection()
		for _, entry in ipairs(ns.PROFILE_ADDONS) do
			if ns.IsProfileAddonLoaded(entry.folder) then
				sel[entry.folder] = true
			end
		end
	end)
	p:Button("Deselect All", "Uncheck every addon.", "Deselect All", function()
		wipe(ExportSelection())
	end)

	p:Section("Include")
	p:Toggle("Unlock Mode Layout", "Include the anchor & size-match relationships between elements (Unlock Mode).",
		function() return state.includeLayout end,
		function(v) state.includeLayout = v end)
	p:Toggle("Global Settings", "Include theme, UI accent color, fonts and UI scale.",
		function() return state.includeGlobals end,
		function(v) state.includeGlobals = v end)
	p:WideButton(function()
		return format("Export Profile (%d of %d addons)", Count(ExportSelection()), LoadedCount())
	end, "Make a string of the checked addons to copy and share.", function() return true end, DoExport)
end

local function BuildImport(p)
	local payload = state.payload
	if not payload then
		p:Paragraph("Nothing to import.")
		p:WideButton(function() return "Back" end, nil, function() return false end, function() Rebuild("main") end)
		return
	end

	p:Section("Import Profile")
	if payload.fromRetail then
		local text = "This profile was made with EllesmereUI on retail. It was converted for Mists of Pandaria: settings with a Mists counterpart are kept, retail-only settings are left out."
		if #payload.notes > 0 then
			text = text .. "\n\n" .. table.concat(payload.notes, "\n")
		end
		p:Paragraph(text)
	else
		p:Paragraph("Choose which addons to import. Any addons not included will use your active profile's settings in the new profile.")
	end
	p:TextInput("Profile Name", "The name of the new profile. Your current settings stay in your current profile.",
		function() return state.importName end,
		function(v) state.importName = v end,
		"Profile name...")
	p:Blank()

	p:Section("Import Addons")
	for _, entry in ipairs(ns.PROFILE_ADDONS) do
		local folder = entry.folder
		local inString = payload.data.addons[folder] ~= nil
		local loaded = ns.IsProfileAddonLoaded(folder)
		local tip
		if not inString then
			tip = "Not in this string"
		elseif not loaded then
			tip = "Addon not loaded"
		else
			tip = "Import " .. entry.display .. " from the string."
		end
		p:Toggle(entry.display, tip,
			function() return state.importSel[folder] and true or false end,
			function(v) state.importSel[folder] = v and true or nil end,
			function() return not CanImport(folder) end)
	end
	p:Button("Select All", "Check every addon in the string.", "Select All", function()
		for _, entry in ipairs(ns.PROFILE_ADDONS) do
			if CanImport(entry.folder) then
				state.importSel[entry.folder] = true
			end
		end
	end)
	p:Button("Deselect All", "Uncheck every addon.", "Deselect All", function()
		wipe(state.importSel)
	end)

	p:Section("Include")
	p:Toggle("Unlock Mode Layout", "Import the anchor & size-match relationships from this profile. Off = keep your own layout.",
		function() return state.importLayout end,
		function(v) state.importLayout = v end,
		function() return payload.data.layout == nil end)
	p:Toggle("Global Settings", "Import theme, UI accent color, fonts and UI scale. Off = keep your own look.",
		function() return state.importGlobals end,
		function(v) state.importGlobals = v end,
		function() return payload.data.globals == nil end)
	if ns.ImportHasSpecAssignments and ns.ImportHasSpecAssignments(payload) then
		p:Toggle("Auto Assign to Specs", "Assign this profile to the same specializations it was assigned to on export. Off = your current spec assignments stay as they are.",
			function() return state.importAssign end,
			function(v) state.importAssign = v end)
	end

	p:WideButton(function()
		return format("Import Selected Addons (%d)", Count(state.importSel))
	end, "Create the new profile, make it active and reload your UI.", function() return true end, DoImport)
	p:WideButton(function() return "Back" end, "Cancel this import.", function() return false end, function()
		state.payload = nil
		Rebuild("main")
	end)
end

ns.RegisterSettingsModule({
	-- EllesmereUI "Profiles & Presets": its own fixed sidebar row under
	-- Global Settings (no presets in this port). Nothing to reset.
	key = "profiles",
	name = "Profiles",
	fixed = true,
	icon = "profiles",
	iconOn = "profiles-on",
	tabs = {
		{
			key = "profiles",
			name = "Profiles",
			description = "Import, export, and switch EllesmereUI profiles.",
			pageKey = function() return state.mode .. ":" .. state.rev end,
			build = function(p)
				if state.mode == "import" then
					BuildImport(p)
				else
					BuildMain(p)
				end
			end,
		},
	},
})
