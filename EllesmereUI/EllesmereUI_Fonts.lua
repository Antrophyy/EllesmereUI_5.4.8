-- Global Settings > Fonts back end (EllesmereUI_Fonts.lua of EllesmereUI):
-- the global font and outline, per-module font / outline overrides, icon
-- text outline, Name Font (UNIT_NAME_FONT), Apply to All Game Text and Game
-- Text Scale. Settings in EllesmereUIDB.fonts, same keys as EllesmereUI.
-- 5.4.8: no SLUG font flag, no GetFonts() (the Font objects are found in _G).

local addonName, ns = ...

local FONT_DIR = ns.MEDIA .. "fonts\\"

-- EllesmereUI FONT_FILES / FONT_ORDER ("---" = separator).
ns.FONT_FILES = {
	["Expressway"] = "Expressway.TTF",
	["Expressway Bold"] = "Expressway Bold.ttf",
	["Expressway CAPS"] = "Expressway CAPS.ttf",
	["Avant Garde"] = "Avant Garde Naowh.ttf",
	["Arial Bold"] = "Arial Bold.TTF",
	["Poppins"] = "Poppins.ttf",
	["Fira Sans Medium"] = "FiraSans Medium.ttf",
	["Arial Narrow"] = "Arial Narrow.ttf",
	["Changa"] = "Changa.ttf",
	["Cinzel Decorative"] = "Cinzel Decorative.ttf",
	["Exo"] = "Exo.otf",
	["Fira Sans Bold"] = "FiraSans Bold.ttf",
	["Fira Sans Light"] = "FiraSans Light.ttf",
	["Future X Black"] = "Future X Black.otf",
	["Gotham Narrow Ultra"] = "Gotham Narrow Ultra.otf",
	["Gotham Narrow"] = "Gotham Narrow.otf",
	["Russo One"] = "Russo One.ttf",
	["Ubuntu"] = "Ubuntu.ttf",
	["Homespun"] = "Homespun.ttf",
	["HWT Artz"] = "HWT Artz.ttf",
	["KMT Kimberley"] = "KMT Kimberley.otf",
	["KMT Ninja Naruto"] = "KMT Ninja Naruto.ttf",
}
ns.FONT_BLIZZARD = {
	["Friz Quadrata"] = "Fonts\\FRIZQT__.TTF",
	["Arial"] = "Fonts\\ARIALN.TTF",
	["Morpheus"] = "Fonts\\MORPHEUS.TTF",
	["Skurri"] = "Fonts\\skurri.ttf",
}
ns.FONT_ORDER = {
	"Expressway", "Expressway Bold", "Expressway CAPS", "Avant Garde", "Arial Bold", "Poppins", "Fira Sans Medium",
	"---",
	"Arial Narrow", "Changa", "Cinzel Decorative", "Exo", "Fira Sans Bold", "Fira Sans Light", "Future X Black",
	"Gotham Narrow Ultra", "Gotham Narrow", "Russo One", "Ubuntu", "Homespun", "HWT Artz", "KMT Kimberley",
	"KMT Ninja Naruto", "Friz Quadrata", "Arial", "Morpheus", "Skurri",
}

ns.BLIZZARD_FONT_KEY = "__blizzard"
ns.SYSTEM_FONT_KEY = "__system"
ns.EXPRESSWAY_FORCED_KEY = "__expressway"

-- Clients whose script the bundled fonts do not cover (EllesmereUI_Locale.lua).
local LOCALE = GetLocale()
local LOCALE_FONT_FALLBACK = ({
	zhCN = "Fonts\\ARKai_T.ttf",
	zhTW = "Fonts\\bLEI00D.ttf",
	koKR = "Fonts\\2002.TTF",
	ruRU = "Fonts\\FRIZQT___CYR.TTF",
})[LOCALE]
ns.LOCALE_FONT_FALLBACK = LOCALE_FONT_FALLBACK
ns.LOCALE_SCRIPT = (LOCALE == "ruRU") and "cyrillic" or (LOCALE_FONT_FALLBACK and "cjk" or nil)
ns.FONT_CYRILLIC = {
	["Expressway"] = true, ["Expressway Bold"] = true, ["Expressway CAPS"] = true, ["Avant Garde"] = true,
	["Arial Bold"] = true, ["Arial Narrow"] = true, ["Fira Sans Medium"] = true, ["Fira Sans Bold"] = true,
	["Fira Sans Light"] = true, ["KMT Kimberley"] = true, ["Russo One"] = true, ["Ubuntu"] = true,
}

-- Module keys (EllesmereUI _addonKeyToFolder) of the modules this port has.
ns.FONT_MODULES = {
	{ key = "actionBars", folder = "EllesmereUIActionBars", display = "Action Bars" },
	{ key = "unitFrames", folder = "EllesmereUIUnitFrames", display = "Unit Frames" },
	{ key = "raidFrames", folder = "EllesmereUIRaidFrames", display = "Raid Frames" },
	{ key = "nameplates", folder = "EllesmereUINameplates", display = "Nameplates" },
	{ key = "resourceBars", folder = "EllesmereUIResourceBars", display = "Resource Bars" },
	{ key = "blizzardSkin", folder = "EllesmereUIBlizzardSkin", display = "Blizzard Skins+" },
	{ key = "damageMeters", folder = "EllesmereUIDamageMeters", display = "Damage Meters" },
	{ key = "bags", folder = "EllesmereUIBags", display = "Bags" },
	{ key = "minimap", folder = "EllesmereUIMinimap", display = "Minimap" },
	{ key = "chat", folder = "EllesmereUIChat", display = "Chat" },
	{ key = "reforge", folder = "EllesmereUIReforge", display = "Reforge" },
	{ key = "dataBars", folder = "EllesmereUIDataBars", display = "DataBars" },
	{ key = "qol", folder = "EllesmereUIQoL", display = "Quality of Life" },
	{ key = "topBar", folder = "EllesmereUITopBar", display = "Top Bar" },
	{ key = "cdm", folder = "EllesmereUICooldownManager", display = "Cooldown Manager" },
	{ key = "auraBuff", folder = "EllesmereUIAuraBuffReminders", display = "AuraBuff Reminders" },
	{ key = "friends", folder = "EllesmereUIFriends", display = "Friends" },
	{ key = "mythicTimer", folder = "EllesmereUIMythicTimer", display = "Mythic+ Tools" },
	{ key = "quickdraw", folder = "EllesmereUIQuickdraw", display = "Quickdraw" },
	{ key = "questTracker", folder = "EllesmereUIQuestTracker", display = "Quest Tracker" },
}
local KEY_TO_FOLDER = {}
for _, m in ipairs(ns.FONT_MODULES) do
	KEY_TO_FOLDER[m.key] = m.folder
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
local cache = { path = {}, outline = {}, icon = {} }

function ns.InvalidateFontCache()
	wipe(cache.path)
	wipe(cache.outline)
	wipe(cache.icon)
end

function ns.GetFontsDB()
	if type(EllesmereUIDB) ~= "table" then
		EllesmereUIDB = {}
	end
	if type(EllesmereUIDB.fonts) ~= "table" then
		EllesmereUIDB.fonts = {
			global = (ns.LOCALE_SCRIPT == "cyrillic") and ns.SYSTEM_FONT_KEY or "Expressway",
			outlineMode = "shadow",
		}
	end
	return EllesmereUIDB.fonts
end

-- LibSharedMedia font paths by name.
local function LSMFont(name)
	local LSM = ns.GetLSM and ns.GetLSM()
	if LSM and name and LSM:IsValid("font", name) then
		return LSM:Fetch("font", name)
	end
	return nil
end

function ns.ResolveFontName(name)
	if name == ns.BLIZZARD_FONT_KEY then
		return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
	end
	if name == ns.EXPRESSWAY_FORCED_KEY then
		return FONT_DIR .. "Expressway.TTF"
	end
	if LOCALE_FONT_FALLBACK then
		if ns.LOCALE_SCRIPT == "cyrillic" and name and ns.FONT_CYRILLIC[name] then
			return FONT_DIR .. ns.FONT_FILES[name]
		end
		if name and not ns.FONT_FILES[name] and not ns.FONT_BLIZZARD[name] then
			local sm = LSMFont(name)
			if sm then
				return sm
			end
		end
		return LOCALE_FONT_FALLBACK
	end
	if ns.FONT_BLIZZARD[name] then
		return ns.FONT_BLIZZARD[name]
	end
	if ns.FONT_FILES[name] then
		return FONT_DIR .. ns.FONT_FILES[name]
	end
	return LSMFont(name) or (FONT_DIR .. "Expressway.TTF")
end

-- moduleFonts entry of a module key (nil = follows the global font).
function ns.GetModuleFontEntry(key)
	local folder = key and KEY_TO_FOLDER[key]
	local list = ns.GetFontsDB().moduleFonts
	if not folder or type(list) ~= "table" then
		return nil
	end
	for _, entry in ipairs(list) do
		if entry.folder == folder then
			return entry
		end
	end
	return nil
end

-- field = "font" or "outline"; value "__global" removes the override.
function ns.SetModuleFontValue(key, field, value)
	local db = ns.GetFontsDB()
	db.moduleFonts = db.moduleFonts or {}
	local entry = ns.GetModuleFontEntry(key)
	if not entry then
		if value == "__global" then
			return
		end
		local display
		for _, m in ipairs(ns.FONT_MODULES) do
			if m.key == key then
				display = m.display
			end
		end
		entry = { folder = KEY_TO_FOLDER[key], display = display, font = "__global", outline = "__global" }
		db.moduleFonts[#db.moduleFonts + 1] = entry
	end
	entry[field] = value
	if (entry.font or "__global") == "__global" and (entry.outline or "__global") == "__global" then
		for i, e in ipairs(db.moduleFonts) do
			if e == entry then
				table.remove(db.moduleFonts, i)
				break
			end
		end
	end
	ns.InvalidateFontCache()
end

function ns.GetFontPath(key)
	local k = key or "_global"
	if cache.path[k] then
		return cache.path[k]
	end
	local entry = ns.GetModuleFontEntry(key)
	local path
	if entry and entry.font and entry.font ~= "__global" then
		path = ns.ResolveFontName(entry.font)
	else
		path = ns.ResolveFontName(ns.GetFontsDB().global or "Expressway")
	end
	cache.path[k] = path
	return path
end

function ns.OutlineFlagForMode(mode)
	if mode == "outline" then
		return "OUTLINE"
	elseif mode == "thick" then
		return "THICKOUTLINE"
	end
	return ""
end

function ns.GetFontOutlineFlag(key)
	local k = key or "_global"
	if cache.outline[k] then
		return cache.outline[k]
	end
	local entry = ns.GetModuleFontEntry(key)
	local mode
	if entry and entry.outline and entry.outline ~= "__global" then
		mode = entry.outline
	else
		mode = ns.GetFontsDB().outlineMode or "none"
	end
	local flag = ns.OutlineFlagForMode(mode)
	cache.outline[k] = flag
	return flag
end

-- Icon text (stack counts, durations): a crisp outline unless the module is
-- unchecked in Outline Icon Text, then it follows the module outline.
function ns.GetIconTextOutlineFlag(key)
	local k = key or "_global"
	if cache.icon[k] then
		return cache.icon[k]
	end
	local t = ns.GetFontsDB().outlineIconText
	local flag
	if type(t) == "table" and t[key] == false then
		flag = ns.GetFontOutlineFlag(key)
	else
		flag = "OUTLINE"
	end
	cache.icon[k] = flag
	return flag
end

-- Sets a module font on a FontString: face, flag, and a drop shadow when the
-- flag is "" (EllesmereUI ApplyModuleFont). flags = nil: the module outline.
function ns.ApplyModuleFont(fs, size, key, flags)
	flags = flags or ns.GetFontOutlineFlag(key)
	fs:SetFont(ns.GetFontPath(key), size, flags)
	if not fs:GetFont() then
		fs:SetFont("Fonts\\ARIALN.TTF", size, flags)
	end
	if flags == "" then
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 1)
	else
		fs:SetShadowOffset(0, 0)
	end
end

---------------------------------------------------------------------------
-- Name Font and Apply to All Game Text / Game Text Scale
---------------------------------------------------------------------------
-- The game reads UNIT_NAME_FONT when it builds the world name text, so it is
-- set as soon as the saved settings exist; a change needs a logout.
local function ApplyNameFont()
	local db = EllesmereUIDB and EllesmereUIDB.fonts
	local name = db and db.unitNameFont
	if not name or name == "__default" then
		return
	end
	local path = db.unitNameFontPath or ns.ResolveFontName(name)
	local probe = UIParent:CreateFontString()
	if not pcall(probe.SetFont, probe, path, 12, "") or not probe:GetFont() then
		path = ns.ResolveFontName(name)
	end
	UNIT_NAME_FONT = path
end

-- Blizzard's Font objects (5.4.8 has no GetFonts(): look for them in _G).
local function GameFontObjects()
	local list = {}
	for name, obj in pairs(_G) do
		if type(obj) == "table" and type(name) == "string" and type(obj.GetObjectType) == "function" then
			local ok, kind = pcall(obj.GetObjectType, obj)
			if ok and kind == "Font" then
				list[#list + 1] = obj
			end
		end
	end
	return list
end

-- Once per session at login (the scale would stack on a second run).
function ns.ApplyGlobalFontToGameText()
	local db = ns.GetFontsDB()
	local swap = db.applyToAllGameText and true or false
	local scale = tonumber(db.gameTextScale) or 100
	scale = math.max(75, math.min(125, scale)) / 100
	if not swap and scale == 1 then
		return
	end
	local path = swap and ns.ResolveFontName(db.global or "Expressway") or nil
	if path then
		STANDARD_TEXT_FONT = path
	end
	for _, obj in ipairs(GameFontObjects()) do
		local face, size, flags = obj:GetFont()
		if face and size then
			pcall(obj.SetFont, obj, path or face, size * scale, flags or "")
		end
	end
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
			ApplyNameFont()
		end
	elseif event == "PLAYER_LOGIN" then
		self:UnregisterEvent("PLAYER_LOGIN")
		ns.ApplyGlobalFontToGameText()
		-- The bundled fonts in LibSharedMedia, like EllesmereUI.
		local LSM = ns.GetLSM and ns.GetLSM()
		if LSM and LSM.Register then
			for name, file in pairs(ns.FONT_FILES) do
				pcall(LSM.Register, LSM, "font", name, FONT_DIR .. file)
			end
		end
	end
end)
