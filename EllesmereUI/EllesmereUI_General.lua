-- Global Settings > General back end (EllesmereUI.lua, EllesmereUI_UICore.lua,
-- EllesmereUI_Startup.lua and EllesmereUI_Uninstall.lua of EllesmereUI):
-- options theme and UI accent color, game CVars (recorded for Uninstall EUI),
-- the Escape menu and minimap buttons, the combat text font, Spell ID on
-- tooltips, Reset ALL and Uninstall EUI.
-- 5.4.8: no C_CVar, no TooltipDataProcessor, no GameMenuFrame button pool,
-- no file IDs (so no IconID line).

local addonName, ns = ...

local floor, atan2, cos, sin, deg, rad = math.floor, math.atan2, math.cos, math.sin, math.deg, math.rad

local function DB()
	if type(EllesmereUIDB) ~= "table" then
		EllesmereUIDB = {}
	end
	return EllesmereUIDB
end

---------------------------------------------------------------------------
-- Themes and accent color (EllesmereUI THEME_PRESETS / THEME_ORDER)
---------------------------------------------------------------------------
ns.DEFAULT_ACCENT_R, ns.DEFAULT_ACCENT_G, ns.DEFAULT_ACCENT_B = 12 / 255, 210 / 255, 157 / 255

local THEME_PRESETS = {
	["EllesmereUI"] = { r = 12 / 255, g = 210 / 255, b = 157 / 255 },
	["EllesmereUI Original"] = { r = 12 / 255, g = 210 / 255, b = 157 / 255 },
	["EllesmereUI Forever"] = { r = 220 / 255, g = 167 / 255, b = 127 / 255 },
	["Horde"] = { r = 255 / 255, g = 90 / 255, b = 31 / 255 },
	["Alliance"] = { r = 63 / 255, g = 167 / 255, b = 255 / 255 },
	["Midnight"] = { r = 120 / 255, g = 65 / 255, b = 200 / 255 },
	["Dark"] = { r = 1, g = 1, b = 1 },
	["Pixels"] = { r = 1, g = 1, b = 1 },
}
ns.THEME_ORDER = { "EllesmereUI", "EllesmereUI Original", "EllesmereUI Forever", "Horde", "Alliance",
	"Faction (Auto)", "Midnight", "Dark", "Pixels", "Class Colored", "Custom Color" }
ns.DEFAULT_THEME = "EllesmereUI"

-- Window art per theme: media\ui\<folder>window_R_C.tga ("" = the default art).
-- Class Colored and Custom Color tint the Original art (desaturated + color).
ns.THEME_ART = {
	["EllesmereUI"] = "",
	["EllesmereUI Original"] = "themes\\original\\",
	["EllesmereUI Forever"] = "themes\\forever\\",
	["Horde"] = "themes\\horde\\",
	["Alliance"] = "themes\\alliance\\",
	["Midnight"] = "themes\\midnight\\",
	["Dark"] = "themes\\dark\\",
	["Pixels"] = "themes\\pixels\\",
	["Class Colored"] = "themes\\original\\",
	["Custom Color"] = "themes\\original\\",
}

-- EllesmereUI CLASS_COLOR_MAP (the classes of 5.4.8).
ns.CLASS_COLOR_MAP = {
	DEATHKNIGHT = { r = 0.77, g = 0.12, b = 0.23 },
	DRUID = { r = 1.00, g = 0.49, b = 0.04 },
	HUNTER = { r = 0.67, g = 0.83, b = 0.45 },
	MAGE = { r = 0.25, g = 0.78, b = 0.92 },
	MONK = { r = 0.00, g = 1.00, b = 0.60 },
	PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
	PRIEST = { r = 1.00, g = 1.00, b = 1.00 },
	ROGUE = { r = 1.00, g = 0.96, b = 0.41 },
	SHAMAN = { r = 0.00, g = 0.44, b = 0.87 },
	WARLOCK = { r = 0.53, g = 0.53, b = 0.93 },
	WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
}

function ns.GetPlayerClassColor()
	local _, class = UnitClass("player")
	local c = class and ns.CLASS_COLOR_MAP[class]
	if c then
		return c.r, c.g, c.b
	end
	return ns.DEFAULT_ACCENT_R, ns.DEFAULT_ACCENT_G, ns.DEFAULT_ACCENT_B
end

function ns.ResolveFactionTheme(theme)
	if theme == "Faction (Auto)" then
		return UnitFactionGroup("player") == "Horde" and "Horde" or "Alliance"
	end
	return theme
end

function ns.GetActiveTheme()
	local theme = DB().activeTheme
	if not theme or not ns.THEME_ART[ns.ResolveFactionTheme(theme)] then
		return ns.DEFAULT_THEME
	end
	return theme
end

function ns.ResolveThemeColor(theme)
	theme = ns.ResolveFactionTheme(theme)
	if theme == "Class Colored" then
		return ns.GetPlayerClassColor()
	elseif theme == "Custom Color" then
		local sa = DB().accentColor
		return sa and sa.r or ns.DEFAULT_ACCENT_R, sa and sa.g or ns.DEFAULT_ACCENT_G, sa and sa.b or ns.DEFAULT_ACCENT_B
	end
	local preset = THEME_PRESETS[theme]
	if preset then
		return preset.r, preset.g, preset.b
	end
	return ns.DEFAULT_ACCENT_R, ns.DEFAULT_ACCENT_G, ns.DEFAULT_ACCENT_B
end

-- Window art tint (EllesmereUI tbox.TintColor): only Class Colored and Custom
-- Color tint the art; nil = draw it as it is.
function ns.ThemeTint(theme, r, g, b)
	theme = ns.ResolveFactionTheme(theme)
	if theme ~= "Class Colored" and theme ~= "Custom Color" then
		return nil
	end
	local lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
	local bright = 1.10 + (1 - lum) * 0.50
	return math.min(0.08 + r * bright, 1), math.min(0.08 + g * bright, 1), math.min(0.08 + b * bright, 1)
end

-- UI accent: class color, custom color (EllesmereUIDB.useClassAccentColor /
-- customAccentColor; EllesmereUI keeps these per profile, this port has no
-- profiles) or the theme color.
function ns.GetAccentState()
	local db = DB()
	return db.useClassAccentColor and true or false, db.customAccentColor
end

function ns.ResolveAccent()
	local useClass, custom = ns.GetAccentState()
	if useClass then
		return ns.GetPlayerClassColor()
	end
	if custom then
		return custom.r, custom.g, custom.b
	end
	return ns.ResolveThemeColor(ns.GetActiveTheme())
end

-- The settings window sets this (re-colors its accent parts).
ns.accentListeners = ns.accentListeners or {}
function ns.RefreshAccent()
	local r, g, b = ns.ResolveAccent()
	for i = 1, #ns.accentListeners do
		ns.accentListeners[i](r, g, b)
	end
end

---------------------------------------------------------------------------
-- CVars: the first value seen before EllesmereUI changed a CVar is kept in
-- EllesmereUIDB.restoreOnUninstall.cvar, so Uninstall EUI can put it back.
---------------------------------------------------------------------------
local function Record()
	local db = DB()
	if type(db.restoreOnUninstall) ~= "table" then
		db.restoreOnUninstall = {}
	end
	local r = db.restoreOnUninstall
	if type(r.cvar) ~= "table" then
		r.cvar = {}
	end
	return r
end

function ns.SetCVarSafe(name, value)
	local old = GetCVar(name)
	if old == nil then
		return false
	end
	local r = Record()
	if r.cvar[name] == nil then
		r.cvar[name] = old
	end
	return pcall(SetCVar, name, tostring(value))
end

-- EllesmereUI EUI_DEFAULTS (Global Settings reset sets them too).
ns.EUI_DEFAULT_CVARS = {
	{ "cameraDistanceMaxFactor", "2.6" },
	{ "ActionButtonUseKeyDown", "1" },
}

function ns.GetCVarNum(name)
	return tonumber(GetCVar(name) or "") or 0
end

---------------------------------------------------------------------------
-- Escape menu buttons: "EllesmereUI" and (when turned on) "EUI Unlock Mode",
-- after AddOns, like ElvUI does it in 5.4.8.
---------------------------------------------------------------------------
local menuButtons = {}

local function OpenUnlock()
	-- EUI_UnlockMode_Compat.lua: loads the settings addon (popups), then opens.
	if ns.EnterUnlockMode then
		ns.EnterUnlockMode()
	end
end

local function CreateMenuButton(name, text, onClick)
	local button = CreateFrame("Button", name, GameMenuFrame, "GameMenuButtonTemplate")
	button:SetText(text)
	button:SetScript("OnClick", function()
		PlaySound("igMainMenuOption")
		HideUIPanel(GameMenuFrame)
		if not InCombatLockdown() then
			onClick()
		end
	end)
	button:Hide()
	return button
end

local function PositionMenuButtons()
	if not GameMenuButtonLogout then
		return
	end
	local db = DB()
	local list = {}
	if not db.hideGameMenuButton then
		list[#list + 1] = menuButtons.eui
	end
	if db.hideUnlockMenuButton == false then
		list[#list + 1] = menuButtons.unlock
	end
	menuButtons.eui:Hide()
	menuButtons.unlock:Hide()
	if #list == 0 then
		return
	end
	-- Chain our buttons between Logout and whatever is above it (AddOns, or
	-- another addon's button), then Logout under them.
	local point, relTo, relPoint, x, y = GameMenuButtonLogout:GetPoint()
	if relTo == list[#list] then
		return
	end
	local w, h = GameMenuButtonLogout:GetWidth(), GameMenuButtonLogout:GetHeight()
	local prev = relTo
	for i = 1, #list do
		local button = list[i]
		button:SetSize(w, h)
		button:ClearAllPoints()
		button:SetPoint("TOP", prev, "BOTTOM", 0, -1)
		button:Show()
		prev = button
	end
	GameMenuButtonLogout:ClearAllPoints()
	GameMenuButtonLogout:SetPoint(point, prev, relPoint, x, y)
	GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + #list * (h + 1))
end

local function SetupGameMenu()
	if not GameMenuFrame or menuButtons.eui then
		return
	end
	menuButtons.eui = CreateMenuButton("GameMenuButtonEllesmereUI", "|cff0cd29fEllesmere|r|cffffffffUI|r", ns.ToggleSettings)
	menuButtons.unlock = CreateMenuButton("GameMenuButtonEllesmereUIUnlock", "|cff0cd29fEUI|r |cffffffffUnlock Mode|r", OpenUnlock)
	if GameMenuFrame_UpdateVisibleButtons then
		hooksecurefunc("GameMenuFrame_UpdateVisibleButtons", PositionMenuButtons)
	end
	GameMenuFrame:HookScript("OnShow", PositionMenuButtons)
end

---------------------------------------------------------------------------
-- Minimap button (EllesmereUI CreateMinimapButton)
---------------------------------------------------------------------------
local minimapButton

local function MinimapAngle()
	return DB().minimapButtonAngle or 225
end

local function UpdateMinimapPosition()
	if not minimapButton then
		return
	end
	local angle = rad(MinimapAngle())
	local radius = (Minimap:GetWidth() / 2) + 5
	minimapButton:ClearAllPoints()
	minimapButton:SetPoint("CENTER", Minimap, "CENTER", cos(angle) * radius, sin(angle) * radius)
end

local function DragOnUpdate()
	local mx, my = Minimap:GetCenter()
	local cx, cy = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	DB().minimapButtonAngle = deg(atan2(cy / scale - my, cx / scale - mx)) % 360
	UpdateMinimapPosition()
end

function ns.CreateMinimapButton()
	if minimapButton or not Minimap then
		return minimapButton
	end
	local button = CreateFrame("Button", "EllesmereUIMinimapButton", Minimap)
	minimapButton = button
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("AnyUp")
	button:RegisterForDrag("LeftButton")

	local bg = button:CreateTexture(nil, "BACKGROUND")
	bg:SetSize(25, 25)
	bg:SetPoint("CENTER")
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetVertexColor(0, 0, 0, 1)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(17, 17)
	icon:SetPoint("CENTER")
	icon:SetTexture(ns.MEDIA .. "eg-logo")
	local overlay = button:CreateTexture(nil, "OVERLAY")
	overlay:SetSize(53, 53)
	overlay:SetPoint("TOPLEFT")
	overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local dragging = false
	button:SetScript("OnClick", function(_, mouse)
		if InCombatLockdown() then
			return
		end
		if mouse == "LeftButton" then
			ns.ToggleSettings()
		elseif mouse == "RightButton" then
			OpenUnlock()
		elseif mouse == "MiddleButton" then
			DB().showMinimapButton = false
			button:Hide()
			if ns.RefreshSettings then
				ns.RefreshSettings()
			end
		end
	end)
	button:SetScript("OnDragStart", function(self)
		if InCombatLockdown() then
			return
		end
		dragging = true
		self:LockHighlight()
		self:SetScript("OnUpdate", DragOnUpdate)
		GameTooltip:Hide()
	end)
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
		self:UnlockHighlight()
		dragging = false
		UpdateMinimapPosition()
	end)
	button:SetScript("OnEnter", function(self)
		if dragging or InCombatLockdown() then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_NONE")
		GameTooltip:SetPoint("TOPRIGHT", self, "TOPLEFT", -2, 0)
		GameTooltip:AddLine("|cff0cd29fEllesmereUI|r")
		GameTooltip:AddLine("|cff0cd29dLeft-click:|r |cffE0E0E0Toggle EllesmereUI|r")
		GameTooltip:AddLine("|cff0cd29dRight-click:|r |cffE0E0E0Enter Unlock Mode|r")
		GameTooltip:AddLine("|cff0cd29dMiddle-click:|r |cffE0E0E0Hide Minimap Button|r")
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	UpdateMinimapPosition()
	button:SetShown(DB().showMinimapButton ~= false)
	return button
end

function ns.ShowMinimapButton()
	local button = ns.CreateMinimapButton()
	if button then
		button:Show()
	end
end

function ns.HideMinimapButton()
	if minimapButton then
		minimapButton:Hide()
	end
end

---------------------------------------------------------------------------
-- Spell ID / Item ID on tooltips (Global Settings > Developer)
---------------------------------------------------------------------------
local function HasLine(tooltip, tag)
	local name = tooltip:GetName()
	if not name then
		return true
	end
	for i = tooltip:NumLines(), 1, -1 do
		local fs = _G[name .. "TextLeft" .. i]
		local text = fs and fs:GetText()
		if text and text:find(tag, 1, true) then
			return true
		end
	end
	return false
end

local function AddID(tooltip, tag, id)
	if not id or not DB().showSpellID or HasLine(tooltip, tag) then
		return
	end
	tooltip:AddDoubleLine(tag, tostring(id), 1, 1, 1, 1, 1, 1)
	tooltip:Show()
end

local function HookTooltip(tooltip)
	if not tooltip or tooltip.euiIDHooked then
		return
	end
	tooltip.euiIDHooked = true
	tooltip:HookScript("OnTooltipSetSpell", function(self)
		AddID(self, "SpellID", select(3, self:GetSpell()))
	end)
	tooltip:HookScript("OnTooltipSetItem", function(self)
		if DB().showItemID == false then
			return
		end
		local _, link = self:GetItem()
		AddID(self, "ItemID", link and tonumber(link:match("item:(%d+)")))
	end)
	hooksecurefunc(tooltip, "SetUnitAura", function(self, unit, index, filter)
		AddID(self, "SpellID", select(11, UnitAura(unit, index, filter)))
	end)
	hooksecurefunc(tooltip, "SetUnitBuff", function(self, unit, index, filter)
		AddID(self, "SpellID", select(11, UnitBuff(unit, index, filter)))
	end)
	hooksecurefunc(tooltip, "SetUnitDebuff", function(self, unit, index, filter)
		AddID(self, "SpellID", select(11, UnitDebuff(unit, index, filter)))
	end)
end

---------------------------------------------------------------------------
-- Combat text font (EllesmereUI_Startup.lua ApplyCombatTextFont): the game
-- reads DAMAGE_TEXT_FONT when it builds the world text, so it is set as soon
-- as the saved settings exist; a change needs a logout.
---------------------------------------------------------------------------
local function ApplyCombatTextFont()
	local path = DB().fctFont
	if type(path) == "string" and path ~= "" then
		DAMAGE_TEXT_FONT = path
	end
end

---------------------------------------------------------------------------
-- Reset ALL and Uninstall EUI
---------------------------------------------------------------------------
-- The SavedVariables of every addon of the suite (also ns.PROFILE_ADDONS).
ns.MODULE_SAVED_VARIABLES = {
	"EllesmereUIActionBarsDB",
	"EllesmereUIAuraBuffRemindersDB",
	"EllesmereUIBagsDB",
	"EllesmereUIBlizzardSkinDB",
	"EllesmereUIChatDB",
	"EllesmereUICooldownManagerDB",
	"EllesmereUIDamageMetersDB",
	"EllesmereUIDataBarsDB",
	"EllesmereUIFriendsDB",
	"EllesmereUIInterruptTrackerDB",
	"EllesmereUIMinimapDB",
	"EllesmereUIMythicTimerDB",
	"EllesmereUINameplatesDB",
	"EllesmereUIQoLDB",
	"EllesmereUIQuestTrackerDB",
	"EllesmereUIQuickdrawDB",
	"EllesmereUIRaidFramesDB",
	"EllesmereUIReforgeDB",
	"EllesmereUIResourceBarsDB",
	"EllesmereUITopBarDB",
	"EllesmereUIUnitFramesDB",
}

-- Every addon back to its defaults, every profile deleted (like EllesmereUI).
-- Kept: the UI scale, the game settings from before EUI (Uninstall EUI),
-- Optimize Graphics' backup, and per-character data that is not a setting
-- (ns.PROFILE_PRIVATE: Reforge weights and caps, caches). The caller reloads.
function ns.ResetAll()
	local private = {}
	if ns.PROFILE_ADDONS and ns.PROFILE_PRIVATE then
		for _, entry in ipairs(ns.PROFILE_ADDONS) do
			local old = _G[entry.svName]
			local paths = ns.PROFILE_PRIVATE[entry.folder]
			if type(old) == "table" and paths then
				private[entry.svName] = {}
				for _, path in ipairs(paths) do
					local t = old
					for part in path:gmatch("[^%.]+") do
						t = type(t) == "table" and t[part] or nil
					end
					private[entry.svName][path] = t
				end
			end
		end
	end
	for _, name in ipairs(ns.MODULE_SAVED_VARIABLES) do
		local root = {}
		for path, value in pairs(private[name] or {}) do
			-- Only top-level private keys are kept (DataBars' profile.characters
			-- is rebuilt by the module); first-login markers go, so the module
			-- starts over like a new install.
			if not path:find("%.") and path ~= "_seeded" then
				root[path] = value
			end
		end
		_G[name] = root
	end
	local old = DB()
	local keep = {}
	for _, key in ipairs({ "ppUIScale", "ppUIScaleAuto", "restoreOnUninstall", "gfxBackup" }) do
		keep[key] = old[key]
	end
	EllesmereUIDB = keep
end

-- Every EllesmereUI addon that is installed.
local function OwnAddOns()
	local list = {}
	for i = 1, GetNumAddOns() do
		local name = GetAddOnInfo(i)
		if name and name:find("^EllesmereUI") then
			list[#list + 1] = name
		end
	end
	return list
end

function ns.UninstallKnowsOriginals()
	local r = DB().restoreOnUninstall
	return type(r) == "table" and r.fresh == true
end

-- Puts back the CVars EllesmereUI changed and turns every EllesmereUI addon
-- off (5.4.8: for this character; the character select AddOns list can turn it
-- off for others). Refused in combat. The caller reloads.
function ns.Uninstall()
	if InCombatLockdown() then
		return false
	end
	local r = Record()
	for name, value in pairs(r.cvar) do
		pcall(SetCVar, name, value)
	end
	r.cvar = nil
	r.fresh = true
	-- UIParent goes back to the Blizzard scale after the reload by itself.
	for _, name in ipairs(OwnAddOns()) do
		DisableAddOn(name)
	end
	return true
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local driver = CreateFrame("Frame")
driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_LOGIN")
driver:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == addonName then
			ApplyCombatTextFont()
			-- A fresh install knows the player's own values from here on.
			local db = DB()
			if db.restoreOnUninstall == nil then
				Record().fresh = true
			end
		end
	elseif event == "PLAYER_LOGIN" then
		self:UnregisterEvent("PLAYER_LOGIN")
		-- EllesmereUI ApplySmartDefaults: its preferred values, only where the
		-- player still has the game default.
		for _, entry in ipairs(ns.EUI_DEFAULT_CVARS) do
			local name, value = entry[1], entry[2]
			local cur, def = GetCVar(name), GetCVarDefault(name)
			if cur and def and tonumber(cur) == tonumber(def) and tonumber(cur) ~= tonumber(value) then
				ns.SetCVarSafe(name, value)
			end
		end
		-- Suppress Lua Errors (default on).
		if DB().suppressErrors ~= false then
			ns.SetCVarSafe("scriptErrors", "0")
		end
		SetupGameMenu()
		if DB().showMinimapButton ~= false then
			ns.CreateMinimapButton()
		end
		HookTooltip(GameTooltip)
		HookTooltip(ItemRefTooltip)
	end
end)
