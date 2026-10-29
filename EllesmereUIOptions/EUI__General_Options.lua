-- Global Settings > General (EllesmereUI EUI__General_Options.lua,
-- BuildGeneralPage): the fixed row under Unlock Mode. Uses the core addon
-- only (EllesmereUI_General.lua, EllesmereUI_UIScale.lua).
--
-- Left out (no 5.4.8 support, no workaround): EUI Options Language (no
-- translations in this port), Disable Sync Icons (no profiles, so no sidebar
-- sync icons), Increase Game Image Quality (no ResampleAlwaysSharpen), the
-- Combat Text Size cog (no WorldTextScale), Prevent Swiftmend Icon Dim (retail
-- mechanic). 5.4.8 CVars stand in for the retail ones (Lag Tolerance =
-- maxSpellStartRecoveryOffset, Combat Text = CombatDamage and co.).

local ns = EllesmereUI

local floor = math.floor

local function DB()
	if type(EllesmereUIDB) ~= "table" then
		EllesmereUIDB = {}
	end
	return EllesmereUIDB
end

local ICONS = ns.MEDIA .. "icons\\"
-- Red for stop (Reset ALL, Uninstall, Restore), EllesmereUI's own green for
-- go (Optimize and its link): fixed, never the accent.
local WARN = { r = 0.9, g = 0.3, b = 0.3 }
local GO = { r = 0x0c / 255, g = 0xd2 / 255, b = 0x9d / 255 }

---------------------------------------------------------------------------
-- Optimize My FPS and Graphics (5.4.8 CVars in place of the retail ones)
---------------------------------------------------------------------------
local OPTIMIZED_CVARS = {
	{ "shadowMode", "1" },
	{ "waterDetail", "0" },
	{ "rippleDetail", "0" },
	{ "particleDensity", "100" },
	{ "SSAO", "0" },
	{ "sunShafts", "0" },
	{ "terrainMipLevel", "0" },
	{ "componentTextureLevel", "0" },
	{ "projectedTextures", "1" },
	{ "farclip", "600" },
	{ "environmentDetail", "75" },
	{ "groundEffectDensity", "16" },
	{ "groundEffectDist", "70" },
	{ "Sound_EnableReverb", "0" },
}

local GFX_CHANGES = "What we change:\n\n"
	.. "Shadow Quality - Fair (balanced quality/FPS)\n"
	.. "Liquid Detail - Low\n"
	.. "Ripple Detail - Disabled\n"
	.. "Particle Density - Set to Ultra (keeps important spell effects)\n"
	.. "SSAO (Ambient Occlusion) - Disabled\n"
	.. "Sunshafts - Disabled\n"
	.. "Texture Resolution - Set to High\n"
	.. "Projected Textures - Enabled (needed for ground effects)\n"
	.. "View Distance - Reduced\n"
	.. "Environment Detail - Reduced\n"
	.. "Ground Clutter - Reduced to Low\n"
	.. "Enable Reverb - Disabled (spell and interrupt audio cues stay crisp)\n\n"
	.. "These settings prioritize frame rate and visual clarity over environmental detail. Textures stay high quality so your character and the world still look perfect."

local function HasGfxBackup()
	return DB().gfxBackup ~= nil
end

local function ApplyOptimizedGfx()
	if InCombatLockdown() then
		return
	end
	local db = DB()
	if not db.gfxBackup then
		local backup = {}
		for _, entry in ipairs(OPTIMIZED_CVARS) do
			backup[entry[1]] = GetCVar(entry[1])
		end
		db.gfxBackup = backup
	else
		for _, entry in ipairs(OPTIMIZED_CVARS) do
			if db.gfxBackup[entry[1]] == nil then
				db.gfxBackup[entry[1]] = GetCVar(entry[1])
			end
		end
	end
	for _, entry in ipairs(OPTIMIZED_CVARS) do
		if GetCVar(entry[1]) ~= nil then
			pcall(SetCVar, entry[1], entry[2])
		end
	end
end

local function RestoreGfxSettings()
	local db = DB()
	if not db.gfxBackup or InCombatLockdown() then
		return
	end
	for _, entry in ipairs(OPTIMIZED_CVARS) do
		local saved = db.gfxBackup[entry[1]]
		if saved then
			pcall(SetCVar, entry[1], saved)
		end
	end
	db.gfxBackup = nil
end

---------------------------------------------------------------------------
-- Reset ALL and Uninstall EUI
---------------------------------------------------------------------------
local function ConfirmResetAll()
	ns.ShowConfirmPopup({
		title = "Reset ALL Settings",
		message = "Are you sure you want to reset ALL EUI addon settings to their defaults? This deletes ALL of your profiles, not just the current one, and reloads your UI.",
		disclaimer = "Every profile on this account is deleted. Export any profile you want to keep first. Your UI scale is kept.",
		typeToConfirm = "Confirm",
		confirmText = "Reset All & Reload",
		cancelText = "Cancel",
		onConfirm = ns.ResetAll,
		reload = true,
	})
end

local function ConfirmUninstall()
	if InCombatLockdown() then
		ns.ShowConfirmPopup({
			title = "Uninstall EUI",
			message = "Uninstalling reloads the UI and cannot run in combat. Leave combat and try again.",
			confirmText = "OK",
			hideCancel = true,
		})
		return
	end
	local message = "Puts back the game settings EUI changed, such as camera, action button and combat text options, and turns EUI off for this character, then reloads the UI.\n\n"
		.. "Your settings are kept, so you can turn EUI back on later in the AddOns list at character select."
	if HasGfxBackup() then
		message = message .. "\n\nGraphics changed by Optimize My FPS and Graphics stay as they are. To undo them, click Restore My Graphics Settings first."
	end
	ns.ShowConfirmPopup({
		title = "Uninstall EUI",
		message = message,
		disclaimer = (not ns.UninstallKnowsOriginals()) and "EUI was installed before it kept a record of your original settings, so the settings it still manages keep their current values." or nil,
		confirmText = "Uninstall & Reload",
		cancelText = "Cancel",
		onConfirm = function()
			if ns.Uninstall() then
				ReloadUI()
			end
		end,
	})
end

local function ShowGfxInfo()
	ns.ShowInfoPopup({
		title = "FPS & Graphics Optimization",
		content = "This feature optimizes your in-game graphics settings to give you the best combination of high FPS and visual clarity."
			.. "\n\nAfter optimizing, the button changes to 'Restore My Graphics Settings', which reverts every change."
			.. "\n\n\n" .. GFX_CHANGES,
	})
end

---------------------------------------------------------------------------
-- Lists
---------------------------------------------------------------------------
local function ThemeItems()
	local items = {}
	for i, name in ipairs(ns.THEME_ORDER) do
		items[i] = { name = name, value = name }
	end
	return items
end

-- Combat Text Font (EllesmereUI fctFontValues): bundled fonts, the Blizzard
-- fonts, then LibSharedMedia.
local FONT_DIR = ns.MEDIA .. "fonts\\"
local FCT_FONTS = {
	{ "Expressway", FONT_DIR .. "Expressway.TTF" },
	{ "Avant Garde", FONT_DIR .. "Avant Garde Naowh.ttf" },
	{ "Arial Bold", FONT_DIR .. "Arial Bold.TTF" },
	{ "Poppins", FONT_DIR .. "Poppins.ttf" },
	{ "Fira Sans Medium", FONT_DIR .. "FiraSans Medium.ttf" },
	{ "Expressway CAPS", FONT_DIR .. "Expressway CAPS.ttf" },
	"---",
	{ "Arial Narrow", FONT_DIR .. "Arial Narrow.ttf" },
	{ "Changa", FONT_DIR .. "Changa.ttf" },
	{ "Cinzel Decorative", FONT_DIR .. "Cinzel Decorative.ttf" },
	{ "Exo", FONT_DIR .. "Exo.otf" },
	{ "Fira Sans Bold", FONT_DIR .. "FiraSans Bold.ttf" },
	{ "Fira Sans Light", FONT_DIR .. "FiraSans Light.ttf" },
	{ "Future X Black", FONT_DIR .. "Future X Black.otf" },
	{ "Gotham Narrow Ultra", FONT_DIR .. "Gotham Narrow Ultra.otf" },
	{ "Gotham Narrow", FONT_DIR .. "Gotham Narrow.otf" },
	{ "Russo One", FONT_DIR .. "Russo One.ttf" },
	{ "Ubuntu", FONT_DIR .. "Ubuntu.ttf" },
	{ "Homespun", FONT_DIR .. "Homespun.ttf" },
	{ "HWT Artz", FONT_DIR .. "HWT Artz.ttf" },
	{ "Friz Quadrata", "Fonts\\FRIZQT__.TTF" },
	{ "Arial", "Fonts\\ARIALN.TTF" },
	{ "Morpheus", "Fonts\\MORPHEUS.TTF" },
	{ "Skurri", "Fonts\\skurri.ttf" },
}

local function FctFontItems()
	local items = { { name = "Blizzard Default", value = "default" } }
	local seen = {}
	for _, entry in ipairs(FCT_FONTS) do
		if entry == "---" then
			items[#items + 1] = { separator = true, name = "", value = "---" }
		else
			items[#items + 1] = { name = entry[1], value = entry[2] }
			seen[entry[2]:lower()] = true
		end
	end
	local LSM = ns.GetLSM and ns.GetLSM()
	if LSM then
		local extra = {}
		for name, path in pairs(LSM:HashTable("font") or {}) do
			if type(path) == "string" and not seen[path:lower()] then
				extra[#extra + 1] = { name = name, value = path }
			end
		end
		table.sort(extra, function(a, b) return a.name:lower() < b.name:lower() end)
		if #extra > 0 then
			items[#items + 1] = { separator = true, name = "", value = "---" }
			for i = 1, #extra do
				items[#items + 1] = extra[i]
			end
		end
	end
	return items
end

local function FctFontLabel()
	local v = DB().fctFont
	if not v then
		return "Blizzard Default"
	end
	for _, item in ipairs(FctFontItems()) do
		if item.value == v then
			return item.name
		end
	end
	return v:match("[^\\/]+$") or v
end

-- Combat Text (EllesmereUI COMBAT_TEXT, 5.4.8 CVar names).
local function DmgOff()
	return GetCVar("CombatDamage") ~= "1"
end
local COMBAT_TEXT = {
	{ key = "CombatDamage", label = "Damage" },
	{ key = "CombatHealing", label = "Healing" },
	{ key = "CombatLogPeriodicSpells", label = "Periodic Damage", damage = true },
	{ key = "PetMeleeDamage", label = "Pet Melee Damage", damage = true },
	{ key = "PetSpellDamage", label = "Pet Spell Damage", damage = true },
}

local function CheckboxSummary(list, isOn, skip)
	local on = {}
	for _, entry in ipairs(list) do
		if isOn(entry.key) and not (skip and skip(entry)) then
			on[#on + 1] = entry.label
		end
	end
	if #on == 0 then
		return "None"
	elseif #on == #list then
		return "All"
	end
	return table.concat(on, ", ")
end

local EUI_BUTTONS = {
	{ key = "pause", label = "Hide Pause Menu Button", tip = "Hides the EllesmereUI button from the game's Escape/pause menu." },
	{ key = "unlock", label = "Hide Unlock Mode Menu Button", tip = "Hides the Unlock Mode button from the game's Escape/pause menu. You can still toggle Unlock Mode from the EUI options panel." },
	{ key = "minimap", label = "Show Minimap Button" },
}

local function EuiButtonOn(k)
	local db = DB()
	if k == "pause" then
		return db.hideGameMenuButton or false
	elseif k == "unlock" then
		return db.hideUnlockMenuButton ~= false
	elseif k == "minimap" then
		return db.showMinimapButton ~= false
	end
	return false
end

local function SetEuiButton(k, v)
	local db = DB()
	if k == "pause" then
		db.hideGameMenuButton = v
	elseif k == "unlock" then
		db.hideUnlockMenuButton = v
	elseif k == "minimap" then
		db.showMinimapButton = v
		if v then
			ns.ShowMinimapButton()
		else
			ns.HideMinimapButton()
		end
	end
end

---------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------
local function BuildGeneral(p)
	-------------------------------------------------------------------
	-- Top row: Reset ALL | Optimize (Restore while a backup exists) | Uninstall
	-------------------------------------------------------------------
	p:ActionCards({
		{ icon = { ICONS .. "sync", 30 / 32, 30 / 32 }, accent = WARN,
		  title = "Reset ALL EUI Addon Settings", desc = "Return every EUI addon to its defaults.",
		  onClick = ConfirmResetAll },
		{ icon = function()
			if HasGfxBackup() then
				return { ICONS .. "undo", 30 / 32, 30 / 32 }
			end
			return { ICONS .. "optimize", 60 / 64, 60 / 64 }
		  end,
		  title = function() return HasGfxBackup() and "Restore My Graphics Settings" or "Optimize My FPS and Graphics" end,
		  desc = function() return HasGfxBackup() and "Put back your graphics from before optimizing." or "Tune graphics for higher FPS and clarity." end,
		  sizeAlso = { "Restore My Graphics Settings", "Put back your graphics from before optimizing." },
		  hero = function() return not HasGfxBackup() end,
		  accent = function() return HasGfxBackup() and WARN or GO end,
		  link = { text = "What Does This Do?", accent = GO, onClick = ShowGfxInfo },
		  onClick = function()
			if HasGfxBackup() then
				RestoreGfxSettings()
			else
				ApplyOptimizedGfx()
			end
		  end },
		{ icon = { ICONS .. "power", 23 / 32, 23 / 32 }, accent = WARN, iconSize = 22,
		  title = "Uninstall EUI", desc = "Revert EUI's changes and disable.",
		  onClick = ConfirmUninstall },
	})

	-------------------------------------------------------------------
	-- DISPLAY
	-------------------------------------------------------------------
	p:Section("Display")

	-- UI Accent Color: Class Color | Custom Color.
	p:Label("UI Accent Color", "Sets the accent color used across all EllesmereUI elements (tabs, glows, highlights, borders). Defaults to your theme color.")
	p:Swatch("Custom Color",
		function()
			local _, custom = ns.GetAccentState()
			if custom then
				return custom.r, custom.g, custom.b, 1
			end
			return ns.DEFAULT_ACCENT_R, ns.DEFAULT_ACCENT_G, ns.DEFAULT_ACCENT_B, 1
		end,
		function(r, g, b)
			local db = DB()
			db.customAccentColor = { r = r, g = g, b = b }
			db.useClassAccentColor = false
			ns.RefreshAccent()
		end,
		{
			active = function() return not (ns.GetAccentState()) end,
			onClick = function()
				if ns.GetAccentState() then
					-- Class -> custom: just leave the class color.
					DB().useClassAccentColor = false
					ns.RefreshAccent()
					return true
				end
			end,
		})
	p:Swatch("Class Color",
		function()
			local r, g, b = ns.GetPlayerClassColor()
			return r, g, b, 1
		end,
		function() end,
		{
			readonly = true,
			active = function() return (ns.GetAccentState()) end,
			onClick = function()
				DB().useClassAccentColor = true
				ns.RefreshAccent()
				return true
			end,
		})

	-- EUI Options Theme, with the Custom Color theme's swatch inline.
	p:Dropdown("EUI Options Theme", "The look of this settings window.",
		ThemeItems,
		function() return ns.GetActiveTheme() end,
		function() return ns.GetActiveTheme() end,
		function(v)
			DB().activeTheme = v
			if ns.ApplyThemeArt then
				ns.ApplyThemeArt(v)
			end
			ns.RefreshAccent()
		end)
	p:Swatch("Custom Color Theme",
		function()
			local sa = DB().accentColor
			if sa then
				return sa.r, sa.g, sa.b, 1
			end
			return ns.DEFAULT_ACCENT_R, ns.DEFAULT_ACCENT_G, ns.DEFAULT_ACCENT_B, 1
		end,
		function(r, g, b)
			DB().accentColor = { r = r, g = g, b = b }
			-- Only the window background follows; the accent stays.
			if ns.ApplyThemeTint then
				ns.ApplyThemeTint()
			end
			if not DB().customAccentColor and not DB().useClassAccentColor then
				ns.RefreshAccent()
			end
		end,
		{ disabled = function() return ns.GetActiveTheme() ~= "Custom Color" end })

	-- UI Scale | EUI Buttons
	local function scaleBlocked()
		return not ns.SetUIScale or (ns.UIScaleBlocker and ns.UIScaleBlocker() ~= nil)
	end
	p:Slider("UI Scale", "Sets the scale of the whole game UI. 0.53 = 0.5333 and 0.71 = 0.7111\n\nWhile ElvUI is loaded, ElvUI sets the scale (ElvUI > General > UI Scale).",
		0.40, 1.00, 0.01,
		function() return ns.GetUIScale and ns.GetUIScale() or UIParent:GetScale() end,
		function(v)
			if ns.SetUIScale then
				ns.KeepWindowAcrossScale(function() ns.SetUIScale(v) end)
			end
		end,
		scaleBlocked)
	p:MultiSelect("EUI Buttons", "Toggle EllesmereUI's optional buttons: the Escape menu buttons and the minimap button.",
		function()
			local items = {}
			for i, entry in ipairs(EUI_BUTTONS) do
				items[i] = { name = entry.label, value = entry.key, tip = entry.tip }
			end
			return items
		end,
		EuiButtonOn,
		function(k) SetEuiButton(k, not EuiButtonOn(k)) end,
		function() return CheckboxSummary(EUI_BUTTONS, EuiButtonOn) end)

	-------------------------------------------------------------------
	-- COMBAT
	-------------------------------------------------------------------
	p:Section("Combat")

	p:Slider("Max Camera Distance", nil, 1, 2.6, 0.1,
		function() return floor(ns.GetCVarNum("cameraDistanceMaxFactor") * 10 + 0.5) / 10 end,
		function(v) ns.SetCVarSafe("cameraDistanceMaxFactor", floor(v * 10 + 0.5) / 10) end)
	p:Toggle("Cast Actions on Key Down", "Keybinds respond on key down instead of key up. This helps make your abilities feel more responsive.",
		function() return GetCVar("ActionButtonUseKeyDown") == "1" end,
		function(v) ns.SetCVarSafe("ActionButtonUseKeyDown", v and "1" or "0") end)

	p:Slider("Lag Tolerance", "This is the Spell Queue Window, it helps with making sure you can't queue up too many spells at once which makes the game feel laggy. Recommended settings are generally a minimum of 200 + your local ping. If you are unsure of exactly what this setting does, leave it at 400.\n\n(5.4.8: Custom Lag Tolerance, maxSpellStartRecoveryOffset.)",
		0, 400, 1,
		function()
			if GetCVar("reducedLagTolerance") ~= "1" then
				return 400
			end
			return ns.GetCVarNum("maxSpellStartRecoveryOffset")
		end,
		function(v)
			ns.SetCVarSafe("reducedLagTolerance", "1")
			ns.SetCVarSafe("maxSpellStartRecoveryOffset", v)
		end)
	local function ctOn(key) return GetCVar(key) == "1" end
	p:MultiSelect("Combat Text", "Floating combat text over your targets. Periodic and pet damage only show while Damage is on.",
		function()
			local items = {}
			for i, entry in ipairs(COMBAT_TEXT) do
				items[i] = { name = entry.label, value = entry.key }
				if entry.damage then
					items[i].locked = DmgOff
					items[i].lockedTip = "Requires Damage"
				end
			end
			return items
		end,
		ctOn,
		function(key) ns.SetCVarSafe(key, ctOn(key) and "0" or "1") end,
		function()
			return CheckboxSummary(COMBAT_TEXT, ctOn, function(entry) return entry.damage and DmgOff() end)
		end)

	p:Dropdown("Combat Text Font", "|cffff4d4dWARNING: This feature requires you to re-log or restart WoW to take effect.|r",
		FctFontItems,
		function() return DB().fctFont or "default" end,
		FctFontLabel,
		function(v)
			DB().fctFont = (v ~= "default") and v or nil
			ns.ShowConfirmPopup({
				title = "Logout Required",
				message = "Combat text font changes require a logout to character select to take effect. This is a WoW engine limitation.",
				confirmText = "Okay",
				cancelText = "Later",
			})
		end,
		{ fontPreview = true })

	-------------------------------------------------------------------
	-- DEVELOPER
	-------------------------------------------------------------------
	p:Section("Developer")

	p:Toggle("Suppress Lua Errors", nil,
		function() return DB().suppressErrors ~= false end,
		function(v)
			DB().suppressErrors = v
			ns.SetCVarSafe("scriptErrors", v and "0" or "1")
		end)
	p:Toggle("Show Spell ID on Tooltip", nil,
		function() return DB().showSpellID or false end,
		function(v) DB().showSpellID = v end)
end

---------------------------------------------------------------------------
-- Fonts page (EllesmereUI EUI_Fonts_Options.lua, _EUI_BuildFontsPage).
-- Left out: Disable Slug Outline (no SLUG renderer in 5.4.8), the Combat &
-- World Text card (no WorldTextScale; the Combat Text Font is on General),
-- cards of modules this port does not have or that show no text (QoL, Quest
-- Tracker), and the retail size rows of parts this port does not have.
---------------------------------------------------------------------------
local function FontsDB()
	return ns.GetFontsDB()
end

local function FontReload()
	ns.InvalidateFontCache()
	ns.ShowConfirmPopup({
		title = "Reload Required",
		message = "Font changed. A UI reload is needed to apply the new font.",
		confirmText = "Reload Now",
		cancelText = "Later",
		reload = true,
	})
end

-- The reload popup once the slider is let go (EllesmereUI: end of drag).
local releaseWatcher = CreateFrame("Frame")
releaseWatcher:Hide()
releaseWatcher:SetScript("OnUpdate", function(self)
	if not IsMouseButtonDown("LeftButton") then
		self:Hide()
		FontReload()
	end
end)

local function SEP()
	return { separator = true, name = "", value = "---" }
end

-- LibSharedMedia fonts that are not bundled (by name).
local function ExternalFonts()
	local list = {}
	local LSM = ns.GetLSM and ns.GetLSM()
	if LSM then
		for name in pairs(LSM:HashTable("font") or {}) do
			if not ns.FONT_FILES[name] and not ns.FONT_BLIZZARD[name] then
				list[#list + 1] = name
			end
		end
	end
	table.sort(list, function(a, b) return a:lower() < b:lower() end)
	return list
end

-- The font list after the leading entries (EllesmereUI BuildFontDropdownData).
local function AddFontList(items)
	if ns.LOCALE_SCRIPT == "cjk" then
		items[#items + 1] = { name = "Expressway (Latin only)", value = ns.EXPRESSWAY_FORCED_KEY }
	else
		for _, name in ipairs(ns.FONT_ORDER) do
			if name == "---" then
				if ns.LOCALE_SCRIPT ~= "cyrillic" then
					items[#items + 1] = SEP()
				end
			elseif ns.LOCALE_SCRIPT ~= "cyrillic" or ns.FONT_CYRILLIC[name] then
				items[#items + 1] = { name = name, value = name }
			end
		end
	end
	local ext = ExternalFonts()
	if #ext > 0 then
		items[#items + 1] = SEP()
		for _, name in ipairs(ext) do
			items[#items + 1] = { name = name, value = name }
		end
	end
	return items
end

local function GlobalFontItems()
	local items = {}
	if ns.LOCALE_FONT_FALLBACK then
		items[1] = { name = "System Default", value = ns.SYSTEM_FONT_KEY }
	else
		items[1] = { name = "Blizzard Default", value = ns.BLIZZARD_FONT_KEY }
	end
	items[2] = SEP()
	return AddFontList(items)
end

local function ModuleFontItems()
	local items = {
		{ name = "EUI Global Font", value = "__global" },
		{ name = "Blizzard Default", value = ns.BLIZZARD_FONT_KEY },
		SEP(),
	}
	return AddFontList(items)
end

local function NameFontItems()
	local items = { { name = "Blizzard Default", value = "__default" }, SEP() }
	return AddFontList(items)
end

local function FontPreviewPath(value)
	if value == "__global" then
		return ns.GetFontPath()
	elseif value == "__default" or value == ns.SYSTEM_FONT_KEY then
		return ns.LOCALE_FONT_FALLBACK or "Fonts\\FRIZQT__.TTF"
	end
	return ns.ResolveFontName(value)
end

-- For module pages (EllesmereUI BuildFontDropdownData): leading items, then
-- the bundled and SharedMedia fonts by name.
ns.OptionsUtil.FontItems = function(leading)
	local items = {}
	for _, item in ipairs(leading or {}) do
		items[#items + 1] = item
	end
	if #items > 0 then
		items[#items + 1] = SEP()
	end
	return AddFontList(items)
end

local function ItemLabel(itemsFn, value)
	for _, item in ipairs(itemsFn()) do
		if item.value == value then
			return item.name
		end
	end
	return tostring(value or "")
end

local function GlobalFontValue()
	local v = FontsDB().global or "Expressway"
	if ns.LOCALE_SCRIPT == "cyrillic" and v == ns.EXPRESSWAY_FORCED_KEY then
		return "Expressway"
	end
	if ns.LOCALE_FONT_FALLBACK then
		for _, item in ipairs(GlobalFontItems()) do
			if item.value == v then
				return v
			end
		end
		return ns.SYSTEM_FONT_KEY
	end
	return v
end

local OUTLINE_ITEMS = {
	{ name = "Drop Shadow", value = "none" },
	{ name = "Outline", value = "outline" },
	{ name = "Thick Outline", value = "thick" },
}
local MODULE_OUTLINE_ITEMS = {
	{ name = "EUI Global Outline", value = "__global" },
	{ name = "Drop Shadow", value = "none" },
	{ name = "Outline", value = "outline" },
	{ name = "Thick Outline", value = "thick" },
}
local function ListItems(list)
	return function() return list end
end

-- Outline Icon Text: modules with icon text (this port: Unit Frames).
local ICON_TEXT_MODULES = {
	{ key = "actionBars", label = "Action Bars Icons", addon = "EllesmereUIActionBars" },
	{ key = "unitFrames", label = "Unit Frames Icons", addon = "EllesmereUIUnitFrames" },
	{ key = "bags", label = "Bags Icons", addon = "EllesmereUIBags" },
}

-- Module font rows: per module its font override, its outline, then the
-- module's own text size settings (same keys as on its pages).
local MODULE_EXTRAS = {
	blizzardSkin = function(p)
		if not ns.GetCharSheetDB then
			return
		end
		p:Slider("Enchant Text Size", "Size of the enchant text on the Character Sheet.", 6, 20, 1,
			function() return ns.GetCharSheetDB().enchantSize end,
			function(v) ns.GetCharSheetDB().enchantSize = v end)
		p:Blank()
	end,
	damageMeters = function(p)
		if not ns.GetSpellHistoryDB then
			return
		end
		p:Slider("Spell History Text Size", "Size of the Spell History text.", 8, 16, 1,
			function() return ns.GetSpellHistoryDB().textSize end,
			function(v) ns.GetSpellHistoryDB().textSize = v end)
		p:Blank()
	end,
	-- EllesmereUI TileBags: the Bags text sizes (same keys as the Bags page).
	bags = function(p)
		local function db() return ns._bagsDB and ns._bagsDB.profile end
		local function TextSizes()
			if _G.EUI_Bags and _G.EUI_Bags.RefreshTextSizes then _G.EUI_Bags:RefreshTextSizes() end
			if _G.EUI_BankFrame and _G.EUI_BankFrame.RefreshTextSizes then _G.EUI_BankFrame:RefreshTextSizes() end
		end
		local function Refresh()
			if _G.EUI_Bags and _G.EUI_Bags.RefreshInventory then _G.EUI_Bags:RefreshInventory() end
			if _G.EUI_BankFrame and _G.EUI_BankFrame.RefreshBank and _G.EUI_BankFrame:IsVisible() then _G.EUI_BankFrame:RefreshBank() end
		end
		local function Size(label, desc, key, minV, maxV, def, apply)
			p:Slider(label, desc, minV, maxV, 1,
				function() local d = db(); return (d and d[key]) or def end,
				function(v) local d = db(); if d then d[key] = v; apply() end end)
		end
		if not db() then return end
		Size("Category Title Size", "Font size for category titles in the sidebar and content grid.", "bagCatTitleSize", 8, 16, 11, Refresh)
		Size("Item Count Text Size", "Font size for stack counts.", "bagCountFontSize", 8, 16, 11, TextSizes)
		Size("Cooldown Text Size", "Font size for item cooldown labels (enable Show Item Cooldown Text in Bags > Items).", "bagCooldownFontSize", 8, 20, 11, function()
			if _G.EUI_Bags and _G.EUI_Bags.RefreshCooldowns then _G.EUI_Bags:RefreshCooldowns() end
		end)
		Size("Item Level Text Size", "Font size for item level numbers on equipment items.", "itemlevelFontSize", 8, 16, 12, TextSizes)
		Size("Set Name Text Size", "Font size for the equipment set name on gear.", "bagSetNameFontSize", 7, 14, 9, TextSizes)
		Size("BoE / Warbound Text Size", "Font size for the BoE text on gear.", "bagBindTypeFontSize", 8, 16, 11, TextSizes)
		Size("List Text Size", "Text size of the bag and bank lists.", "bagListFontSize", 8, 16, 11, Refresh)
	end,
	-- Chat / Tab / Edit Box fonts and sizes (same keys as the Chat page).
	chat = function(p)
		local EC = ns.ECHAT
		if not (EC and EC.DB) then return end
		local function D() return EC.DB() end
		local function Items(withChat)
			local items = ModuleFontItems()
			if withChat then
				table.insert(items, 1, { value = "__chat", name = "Chat Font" })
			end
			return items
		end
		local function Font(label, key, withChat)
			local def = withChat and "__chat" or "__global"
			p:Dropdown(label, nil, function() return Items(withChat) end,
				function() return D()[key] or def end,
				function() return ItemLabel(function() return Items(withChat) end, D()[key] or def) end,
				function(v) D()[key] = v end,
				{ fontPreview = true, fontPath = FontPreviewPath })
		end
		local function Size(label, key, minV, maxV, def, after)
			p:Slider(label, nil, minV, maxV, 1,
				function()
					local v = D()[key]
					if v then return v end
					local _, size = FCF_GetChatWindowInfo(1)
					return size or def
				end,
				function(v) D()[key] = v; if after then after(v) end end)
		end
		Size("Chat Font Size", "chatFontSize", 8, 27, 14, function(v) if EC.ApplyChatFontSize then EC.ApplyChatFontSize(v) end end)
		Font("Tab Font", "tabFont", false)
		p:Slider("Tab Font Size", nil, 8, 24, 1, function() return D().tabFontSize or 11 end, function(v) D().tabFontSize = v end)
		Font("Edit Box Font", "editBoxFont", true)
		Size("Edit Box Font Size", "editBoxFontSize", 8, 24, 12)
		p:Blank()
	end,
	-- Quest Tracker font and sizes (same keys as the Quest Tracker page).
	questTracker = function(p)
		local EQT = _G.EllesmereUIQuestTracker
		if not (EQT and EQT.DB) then return end
		local function Size(label, key, def)
			p:Slider(label, nil, 8, 24, 1, function() return EQT.DB()[key] or def end, function(v) EQT.DB()[key] = v end)
		end
		p:Dropdown("Quest Tracker Font", "The Quest Tracker's own font (EUI Global Font = the module font above).",
			ModuleFontItems,
			function() return EQT.DB().font or "__global" end,
			function() return ItemLabel(ModuleFontItems, EQT.DB().font or "__global") end,
			function(v) EQT.DB().font = v end,
			{ fontPreview = true, fontPath = FontPreviewPath })
		Size("Title Font Size", "titleFontSize", 12)
		Size("Objective Font Size", "objectiveFontSize", 10)
		Size("Header Font Size", "headerFontSize", 13)
		p:Blank()
	end,
	-- Battle Res text sizes (same keys as the Quality of Life > Battle Res page).
	qol = function(p)
		local Q = ns.QoL
		if Q and Q.SCT_Get then
			p:Slider("Combat Text Size", "Size of the Self Combat Text.", 10, 48, 1,
				function() return Q.SCT_Get("size") end, function(v) Q.SCT_Set("size", v) end)
		end
		if ns.GetMovementAlertDB and ns.GetMovementAlertDB() then
			p:Slider("Movement Alert Text Size", "Size of the Movement Alert text.", 8, 72, 1,
				function() return ns.GetMovementAlertDB().textSize or 24 end,
				function(v) ns.GetMovementAlertDB().textSize = v end)
		end
		if not ns.GetBattleResDB or not ns.GetBattleResDB() then
			p:Blank()
			return
		end
		local function Size(label, desc, key, minV, maxV, def)
			p:Slider(label, desc, minV, maxV, 1,
				function() return ns.GetBattleResDB()[key] or def end,
				function(v) ns.GetBattleResDB()[key] = v end)
		end
		Size("Battle Res Duration Size", "Size of the timer on the Battle Res icon.", "durationSize", 8, 30, 12)
		Size("Battle Res Count Size", "Size of the count on the Battle Res icon.", "countSize", 8, 20, 11)
		Size("Battle Res Text Size", "Size of the Battle Res text display.", "textSize", 8, 40, 14)
		-- Bloodlust writes its own key but reads through the Battle Res value.
		if ns.GetBloodlustDB and ns.BloodlustGet then
			local function LustSize(label, desc, key, minV, maxV)
				p:Slider(label, desc, minV, maxV, 1,
					function() return ns.BloodlustGet(key) end,
					function(v) ns.GetBloodlustDB()[key] = v end)
			end
			LustSize("Bloodlust Duration Size", "Size of the timer on the Bloodlust icon.", "durationSize", 8, 30)
			LustSize("Bloodlust Count Size", "Size of the count on the Bloodlust icon.", "countSize", 8, 20)
		end
		p:Blank()
	end,
	-- Top Bar text sizes (same keys as the Top Bar page).
	topBar = function(p)
		if not ns.GetTopBarDB then
			return
		end
		p:Slider("Clock Size", "Size of the clock text.", 10, 36, 1,
			function() return ns.GetTopBarDB().clockSize or 20 end,
			function(v) ns.GetTopBarDB().clockSize = v end)
		p:Slider("FPS / MS Size", "Size of the FPS / MS text.", 6, 24, 1,
			function() return ns.GetTopBarDB().sysSize or 11 end,
			function(v) ns.GetTopBarDB().sysSize = v end)
	end,
}
local MODULE_DESC = {
	actionBars = "Keybind, charges, macro and cooldown text, XP and Reputation bar text",
	unitFrames = "Health, power, cast bar and aura text (per unit)",
	blizzardSkin = "Character Sheet text and enchant text",
	damageMeters = "Spell History text",
	bags = "Item count, item level, category and label text",
	reforge = "Reforge and Result window text",
	minimap = "Clock, zone, coordinates, FPS/MS and difficulty text",
	qol = "Battle Res text",
	topBar = "Clock, badge and FPS/MS text",
}

local function BuildFonts(p)
	p:Section("Global Font")

	p:Dropdown("Global Font", nil,
		GlobalFontItems, GlobalFontValue,
		function() return ItemLabel(GlobalFontItems, GlobalFontValue()) end,
		function(v)
			FontsDB().global = v
			FontReload()
		end,
		{ fontPreview = true, fontPath = FontPreviewPath })
	p:Cog("Global Font", {
		{ type = "toggle", label = "Apply to All Game Text",
		  tip = "Applies your Global Font to Blizzard's default game text (menus, tooltips, quest log, character panes, and more). Requires a UI reload.",
		  get = function() return FontsDB().applyToAllGameText or false end,
		  set = function(v)
			FontsDB().applyToAllGameText = v
			FontReload()
		  end },
	})
	p:Dropdown("Outline Mode", "Controls the text rendering style used across all UI elements",
		ListItems(OUTLINE_ITEMS),
		function()
			local v = FontsDB().outlineMode or "none"
			return v == "shadow" and "none" or v
		end,
		function()
			local v = FontsDB().outlineMode or "none"
			return ItemLabel(ListItems(OUTLINE_ITEMS), v == "shadow" and "none" or v)
		end,
		function(v)
			FontsDB().outlineMode = v
			FontReload()
		end)

	local iconItems = {}
	for _, m in ipairs(ICON_TEXT_MODULES) do
		if ns.IsModuleLoaded(m.addon) then
			iconItems[#iconItems + 1] = m
		end
	end
	local function iconOn(key)
		local t = FontsDB().outlineIconText
		return not (type(t) == "table" and t[key] == false)
	end
	if #iconItems > 0 then
		p:MultiSelect("Outline Icon Text", "Forces a crisp outline on icon text (stack counts, durations, keybinds). Uncheck a module to make its icon text follow the Outline Mode setting above instead.",
			function()
				local items = {}
				for i, m in ipairs(iconItems) do
					items[i] = { name = m.label, value = m.key }
				end
				return items
			end,
			iconOn,
			function(key)
				local db = FontsDB()
				db.outlineIconText = db.outlineIconText or {}
				db.outlineIconText[key] = not iconOn(key)
				FontReload()
			end,
			function()
				local on = {}
				for _, m in ipairs(iconItems) do
					if iconOn(m.key) then
						on[#on + 1] = m.label
					end
				end
				return #on == 0 and "None" or table.concat(on, ", ")
			end)
		p:Blank()
	end

	p:Dropdown("Name Font", "Sets the font for the names that float above players, NPCs and enemies in the world.\n\nSeparate from Global Font - changing this does not affect the rest of the UI, and Global Font does not affect it.\n\nBlizzard Default leaves the name text completely untouched.\n\n|cffff4d4dRequires a re-log or restart of WoW to take effect.|r",
		NameFontItems,
		function() return FontsDB().unitNameFont or "__default" end,
		function() return ItemLabel(NameFontItems, FontsDB().unitNameFont or "__default") end,
		function(v)
			local db = FontsDB()
			if v == "__default" then
				db.unitNameFont = nil
				db.unitNameFontPath = nil
			else
				db.unitNameFont = v
				db.unitNameFontPath = ns.ResolveFontName(v)
			end
			ns.ShowConfirmPopup({
				title = "Logout Required",
				message = "Name font changes require a logout to character select to take effect. This is a WoW engine limitation.",
				confirmText = "Okay",
				cancelText = "Later",
			})
		end,
		{ fontPreview = true, fontPath = FontPreviewPath })
	p:Slider("Game Text Scale", "Scales the size of Blizzard's default game text (menus, tooltips, quest log, and more). Requires a UI reload.",
		75, 125, 5,
		function() return FontsDB().gameTextScale or 100 end,
		function(v)
			FontsDB().gameTextScale = (v ~= 100) and v or nil
			releaseWatcher:Show()
		end)

	p:Paragraph("A quick view of every font setting in one place.\nThese are the same settings found on each module's own pages, not separate ones.")

	for _, m in ipairs(ns.FONT_MODULES) do
		if ns.IsModuleLoaded(m.folder) then
			local key = m.key
			p:Section("Module Fonts: " .. m.display)
			p:Dropdown(m.display .. " Font", MODULE_DESC[key],
				ModuleFontItems,
				function()
					local e = ns.GetModuleFontEntry(key)
					return e and e.font or "__global"
				end,
				function()
					local e = ns.GetModuleFontEntry(key)
					return ItemLabel(ModuleFontItems, e and e.font or "__global")
				end,
				function(v)
					ns.SetModuleFontValue(key, "font", v)
					FontReload()
				end,
				{ fontPreview = true, fontPath = FontPreviewPath })
			p:Dropdown("Module Outline", "Outline style override for all " .. m.display .. " text. EUI Global Outline follows the global Outline Mode setting above.",
				ListItems(MODULE_OUTLINE_ITEMS),
				function()
					local e = ns.GetModuleFontEntry(key)
					return e and e.outline or "__global"
				end,
				function()
					local e = ns.GetModuleFontEntry(key)
					return ItemLabel(ListItems(MODULE_OUTLINE_ITEMS), e and e.outline or "__global")
				end,
				function(v)
					ns.SetModuleFontValue(key, "outline", v)
					FontReload()
				end)
			if MODULE_EXTRAS[key] then
				MODULE_EXTRAS[key](p)
			end
		end
	end
end

local GLOBAL_PAGES = {
	{
		key = "general",
		name = "General",
		description = "General options for all EllesmereUI addons.",
		build = BuildGeneral,
	},
	{
		key = "fonts",
		name = "Fonts",
		description = "General options for all EllesmereUI addons.",
		build = BuildFonts,
	},
}

-- Retail tab order: General, (Style: retail Blizzard / Classic looks, not in
-- this port), Fonts, Textures, Glows, Colors. The page bodies live in
-- EUI_Textures_Options.lua, EUI_Glows_Options.lua, EUI_Colors_Options.lua.
local EXTRA_PAGES = {
	{ key = "textures", name = "Textures", build = "GSO_BuildTexturesPage" },
	{ key = "glows", name = "Glows", build = "GSO_BuildGlowsPage" },
	{ key = "colors", name = "Colors", build = "GSO_BuildColorsPage" },
}
for _, def in ipairs(EXTRA_PAGES) do
	if ns[def.build] then
		GLOBAL_PAGES[#GLOBAL_PAGES + 1] = {
			key = def.key,
			name = def.name,
			description = "General options for all EllesmereUI addons.",
			build = function(p) return ns[def.build](p) end,
		}
	end
end

ns.RegisterSettingsModule({
	-- EllesmereUI: the fixed "Global Settings" row under Unlock Mode.
	key = "global",
	name = "Global Settings",
	fixed = true,
	tabs = GLOBAL_PAGES,
	-- EllesmereUI onReset: its preferred CVars, theme and accent, Window
	-- Scale 100%, UI scale snapshot, developer defaults.
	reset = function()
		for _, entry in ipairs(ns.EUI_DEFAULT_CVARS) do
			ns.SetCVarSafe(entry[1], entry[2])
		end
		local db = DB()
		db.accentColor = nil
		db.activeTheme = nil
		db.customAccentColor = nil
		db.useClassAccentColor = nil
		-- Fonts back to the defaults (a reload shows them).
		db.fonts = nil
		ns.InvalidateFontCache()
		-- Colors page (class / power / resource colors, Dark Mode colors) and
		-- the Glows page template back to the defaults.
		db.customColors = nil
		db.darkMode = nil
		db.glowTemplate = nil
		if ns.RefreshDarkMode then
			ns.RefreshDarkMode()
		end
		db.showSpellID = false
		db.suppressErrors = true
		ns.SetCVarSafe("scriptErrors", "0")
		if ns.SetPanelScale then
			ns.SetPanelScale(1)
		end
		if ns.ApplyThemeArt then
			ns.ApplyThemeArt(ns.GetActiveTheme())
		end
		ns.RefreshAccent()
		if ns.SetUIScale and ns.UIScalePixelBest then
			ns.KeepWindowAcrossScale(function() ns.SetUIScale(ns.UIScalePixelBest()) end)
		end
	end,
	resetTip = "Set the Global Settings back to their defaults: theme, accent color, Window Scale, UI scale (pixel perfect), camera distance, key down, developer options, colors and the glow template.",
})
