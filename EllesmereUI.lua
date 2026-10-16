-- EllesmereUI core: the shared framework of the EllesmereUI addon suite
-- (like retail EllesmereUI). Each module is its own addon (EllesmereUIUnitFrames,
-- EllesmereUIQoL, ...) with "## Dependencies: EllesmereUI"; the settings window
-- is the load-on-demand addon EllesmereUIOptions, loaded by /eui.
--
-- All addons of the suite share one table, the global EllesmereUI (this
-- addon's namespace). Modules start with: local ns = EllesmereUI

local addonName, ns = ...

EllesmereUI = ns

ns.ADDON = addonName
ns.MEDIA = "Interface\\AddOns\\" .. addonName .. "\\media\\"
ns.FONT = ns.MEDIA .. "Expressway.ttf"

-- Every module adds its apply function here (run after a settings change,
-- a reset or a UI scale change).
ns.applyHooks = ns.applyHooks or {}
-- Unlock Mode: modules register elements with ns:RegisterUnlockElements
-- (EUI_UnlockMode.lua, retail API). The old list is kept empty for old code.
ns.unlockElements = ns.unlockElements or {}

local OPTIONS_ADDON = "EllesmereUIOptions"

function ns.Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff0cd29fEllesmereUI|r: " .. tostring(msg))
end

-- Fills missing keys of dst from src (deep).
function ns.CopyDefaults(src, dst)
	for key, value in pairs(src) do
		if type(value) == "table" then
			if type(dst[key]) ~= "table" then
				dst[key] = {}
			end
			ns.CopyDefaults(value, dst[key])
		elseif dst[key] == nil then
			dst[key] = value
		end
	end
end

-- Saved table of a module addon. svName: the module's SavedVariables global;
-- subKey (optional): a sub table of it. Before 3.1 every module saved into
-- EllesmereUIDB[legacyKey]; that table is moved over the first time.
-- Call it at the module's own ADDON_LOADED (its SavedVariables exist then).
function ns.ModuleDB(svName, legacyKey, subKey)
	local root = _G[svName]
	if type(root) ~= "table" then
		root = {}
		_G[svName] = root
	end
	local db = root
	if subKey then
		if type(root[subKey]) ~= "table" then
			root[subKey] = {}
		end
		db = root[subKey]
	end
	local old = legacyKey and type(EllesmereUIDB) == "table" and EllesmereUIDB[legacyKey]
	if type(old) == "table" then
		if next(db) == nil then
			for key, value in pairs(old) do
				db[key] = value
			end
		end
		EllesmereUIDB[legacyKey] = nil
	end
	return db
end

-- Screen height in physical pixels (5.4.8 has no GetPhysicalScreenSize).
-- Windowed maximized ("Windowed (Fullscreen)") draws at the monitor's native
-- size, and gxResolution is often not saved then: use the largest mode of the
-- monitor. Otherwise gxResolution, then the current mode, then 1080.
function ns.PhysicalHeight()
	local function H(res)
		return tonumber((res or ""):match("%d+x(%d+)"))
	end
	local list = GetScreenResolutions and { GetScreenResolutions() } or {}
	if GetCVar("gxWindow") == "1" and GetCVar("gxMaximize") == "1" then
		local best
		for i = 1, #list do
			local h = H(list[i])
			if h and (not best or h > best) then
				best = h
			end
		end
		if best then
			return best
		end
	end
	local h = H(GetCVar("gxResolution"))
	if not h and GetCurrentResolution then
		h = H(list[GetCurrentResolution()])
	end
	return (h and h > 0) and h or 1080
end

-- Is a module addon of the suite loaded?
function ns.IsModuleLoaded(name)
	return IsAddOnLoaded(name) and true or false
end

---------------------------------------------------------------------------
-- Settings window (EllesmereUIOptions, load on demand)
---------------------------------------------------------------------------
-- EllesmereUIOptions sets ns.ToggleSettingsWindow, ns.RefreshSettings and
-- ns.RebuildSettingsPage when it loads. Until then they are nil.
function ns.LoadOptions()
	if IsAddOnLoaded(OPTIONS_ADDON) then
		return true
	end
	local loaded, reason = LoadAddOn(OPTIONS_ADDON)
	if not loaded then
		ns.Print("Cannot load the settings (" .. OPTIONS_ADDON .. "): "
			.. tostring(reason and _G["ADDON_" .. reason] or reason or "?")
			.. ". Enable it in the AddOns list, then restart the game.")
		return false
	end
	return true
end

function ns.ToggleSettings()
	if ns.LoadOptions() and ns.ToggleSettingsWindow then
		ns.ToggleSettingsWindow()
	end
end

-- /eui and /au open the settings window (all options live there);
-- "/eui setup" opens the first time setup popup again.
SLASH_ELLESMEREUI1 = "/eui"
SLASH_ELLESMEREUI2 = "/au"
SlashCmdList.ELLESMEREUI = function(msg)
	if strtrim(msg or ""):lower() == "setup" and ns.ShowFirstInstall then
		ns.ShowFirstInstall()
		return
	end
	ns.ToggleSettings()
end

-- Small page in Blizzard Interface Options that opens the real settings window.
local function BuildOptionsPanel()
	local panel = CreateFrame("Frame", "EllesmereUIOptionsPanel", InterfaceOptionsFramePanelContainer)
	panel.name = "EllesmereUI"

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("EllesmereUI")

	local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	button:SetSize(220, 26)
	button:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
	button:SetText("Open settings (/eui)")
	button:SetScript("OnClick", function()
		if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then
			HideUIPanel(InterfaceOptionsFrame)
		end
		ns.ToggleSettings()
	end)

	InterfaceOptions_AddCategory(panel)
end

local driver = CreateFrame("Frame")
driver:RegisterEvent("ADDON_LOADED")
driver:SetScript("OnEvent", function(self, event, arg1)
	if arg1 ~= addonName then
		return
	end
	self:UnregisterEvent("ADDON_LOADED")
	-- New install: no saved data yet (EllesmereUI_FirstInstall.lua shows its popup).
	ns._freshInstall = type(EllesmereUIDB) ~= "table" or next(EllesmereUIDB) == nil
	if type(EllesmereUIDB) ~= "table" then
		EllesmereUIDB = {}
	end
	BuildOptionsPanel()
end)
