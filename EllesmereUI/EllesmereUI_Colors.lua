-------------------------------------------------------------------------------
--  EllesmereUI_Colors.lua (retail EllesmereUI_Colors.lua, 5.4.8 port)
--  Class, power and class resource colour defaults, the custom colour store
--  and getters, Dark Mode palette and toggles. Global Settings > Colors edits
--  them (EUI_Colors_Options.lua).
--
--  Store: EllesmereUIDB.customColors (class / power / classResource /
--  resource) and EllesmereUIDB.darkMode. Both are Global Settings keys of the
--  Mists profile system (they ride with a profile), so they are always the
--  ACTIVE profile's own colours. Retail's per-section "Apply to All Profiles"
--  / "Pull Colors From" (a store over retail's profile tables) is left out.
--  12.1-only parts left out: the restricted-unit class colour recovery
--  (secret values, C_CurveUtil) and the oUF colour objects.
-------------------------------------------------------------------------------
local ns = EllesmereUI
if not ns then return end

local pairs, ipairs, type, pcall, wipe = pairs, ipairs, type, pcall, wipe
local max, abs = math.max, math.abs

-- Retail CLASS_COLOR_MAP (EllesmereUI_General.lua holds the 5.4.8 classes).
local CLASS_COLOR_MAP = ns.CLASS_COLOR_MAP

-- Default power colors (retail values + the Mists power types).
ns.DEFAULT_POWER_COLORS = {
	MANA         = { r = 0.000, g = 0.550, b = 1.000 },
	RAGE         = { r = 0.900, g = 0.150, b = 0.150 },
	FOCUS        = { r = 0xDD / 255, g = 0x92 / 255, b = 0x37 / 255 },
	ENERGY       = { r = 1.000, g = 0.960, b = 0.410 },
	RUNIC_POWER  = { r = 0xC4 / 255, g = 0x1F / 255, b = 0x3B / 255 },
	LUNAR_POWER  = { r = 0xFF / 255, g = 0x7D / 255, b = 0x0A / 255 },
	INSANITY     = { r = 0.400, g = 0.000, b = 0.800 },
	MAELSTROM    = { r = 0x00 / 255, g = 0x70 / 255, b = 0xDE / 255 },
	FURY         = { r = 0xA3 / 255, g = 0x30 / 255, b = 0xC9 / 255 },
	PAIN         = { r = 1.000, g = 0.612, b = 0.000 },
	EBON_MIGHT   = { r = 0xE6 / 255, g = 0x8C / 255, b = 0x4D / 255 },
	-- Mists-only power types (Eclipse, Demonic Fury, ...) are not listed:
	-- the modules keep their own colours for them.
}

-- Default resource colors (class-specific resource pips, by class).
ns.DEFAULT_RESOURCE_COLORS = {
	ROGUE       = { r = 1.00, g = 0.96, b = 0.41 },
	DRUID       = { r = 1.00, g = 0.49, b = 0.04 },
	PALADIN     = { r = 0.96, g = 0.55, b = 0.73 },
	MONK        = { r = 0.00, g = 1.00, b = 0.60 },
	WARLOCK     = { r = 0.58, g = 0.51, b = 0.79 },
	MAGE        = { r = 0.25, g = 0.78, b = 0.92 },
	DEATHKNIGHT = { r = 0.77, g = 0.12, b = 0.23 },
}

-- Default class-resource colors keyed by the RESOURCE (retail values + the
-- Mists resources: Shadow Orbs, Burning Embers, Lightning Shield).
ns.DEFAULT_CLASS_RESOURCE_COLORS = {
	ComboPoints     = { r = 1.0,    g = 0.9608, b = 0.4118 },
	Runes           = { r = 0.0,    g = 0.8196, b = 1.0    },
	SoulShards      = { r = 0.5059, g = 0.3412, b = 0.8431 },
	HolyPower       = { r = 0.949,  g = 0.902,  b = 0.6    },
	ArcaneCharges   = { r = 0.7176, g = 0.4902, b = 0.8118 },
	Chi             = { r = 0.0,    g = 1.0,    b = 0.6    },
	MaelstromWeapon = { r = 0.0,    g = 0.4392, b = 0.8706 },
	ShadowOrbs      = { r = 0.5,    g = 0.2,    b = 0.8    },
	BurningEmbers   = { r = 0.95,   g = 0.45,   b = 0.1    },
	LightningShield = { r = 0.0,    g = 0.4392, b = 0.8706 },
}

-- Mists Resource Bars resource keys -> retail class-resource keys.
ns.MISTS_RESOURCE_KEYS = {
	COMBO = "ComboPoints", RUNES = "Runes", SOUL_SHARDS = "SoulShards",
	HOLY_POWER = "HolyPower", ARCANE_CHARGES = "ArcaneCharges", CHI = "Chi",
	MAELSTROM_WEAPON = "MaelstromWeapon", SHADOW_ORBS = "ShadowOrbs",
	BURNING_EMBERS = "BurningEmbers", LIGHTNING_SHIELD = "LightningShield",
}

-- Class -> primary power type name.
ns.CLASS_POWER_MAP = {
	WARRIOR = "RAGE", PALADIN = "MANA", HUNTER = "FOCUS", ROGUE = "ENERGY",
	PRIEST = "MANA", DEATHKNIGHT = "RUNIC_POWER", SHAMAN = "MANA", MAGE = "MANA",
	WARLOCK = "MANA", MONK = "ENERGY", DRUID = "MANA",
}

-- Class token sequence (role order) for class pickers; the 5.4.8 classes.
ns.CLASS_TOKEN_ORDER = {
	"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT",
	"SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID",
}

-- Class -> resource type (nil = no class resource).
ns.CLASS_RESOURCE_MAP = {
	ROGUE = "ComboPoints", DRUID = "ComboPoints", PALADIN = "HolyPower",
	MONK = "Chi", WARLOCK = "SoulShards", DEATHKNIGHT = "Runes", PRIEST = "ShadowOrbs",
}

function ns.DarkenColor(r, g, b, frac)
	frac = frac or 0.10
	return r * (1 - frac), g * (1 - frac), b * (1 - frac)
end

local function DB()
	if type(EllesmereUIDB) ~= "table" then
		EllesmereUIDB = {}
	end
	return EllesmereUIDB
end

ns.COLOR_CATEGORIES = { "class", "power", "classResource", "resource" }

-- The custom colour palette (always the active profile's: see the header).
function ns.GetCustomColorsDB()
	local db = DB()
	if type(db.customColors) ~= "table" then
		db.customColors = {}
	end
	local cc = db.customColors
	for _, key in ipairs(ns.COLOR_CATEGORIES) do
		if type(cc[key]) ~= "table" then
			cc[key] = {}
		end
	end
	return cc
end

-- Mists colours are per profile: editing is never locked.
function ns.IsColorEditingLocked()
	return false
end

-------------------------------------------------------------------------------
--  Dark Mode (retail: per profile). Defaults: #111111 fill @ 90%,
--  #4f4f4f background @ 100%, zero darken.
-------------------------------------------------------------------------------
ns.DEFAULT_DARK_MODE = {
	fillR = 0x11 / 255, fillG = 0x11 / 255, fillB = 0x11 / 255, fillA = 0.90,
	bgR   = 0x4f / 255, bgG   = 0x4f / 255, bgB   = 0x4f / 255, bgA   = 1.0,
	classDarken = 0, powerDarken = 0, resourceDarken = 0, powerBgDarken = 0,
}

function ns.GetDarkModeDB()
	local db = DB()
	if type(db.darkMode) ~= "table" then
		db.darkMode = {}
	end
	return db.darkMode
end

ns._dmGen = 0
ns._dmCache = { gen = -1 }

function ns._RebuildDarkModeCache()
	local c = ns._dmCache
	local d = ns.GetDarkModeDB()
	local def = ns.DEFAULT_DARK_MODE
	c.fr, c.fg, c.fb, c.fa = d.fillR or def.fillR, d.fillG or def.fillG, d.fillB or def.fillB, d.fillA or def.fillA
	c.br, c.bg, c.bb, c.ba = d.bgR or def.bgR, d.bgG or def.bgG, d.bgB or def.bgB, d.bgA or def.bgA
	c.gen = ns._dmGen
end

-- Dark Mode fill colour (r, g, b, a).
function ns.GetDarkModeFill()
	local c = ns._dmCache
	if c.gen ~= ns._dmGen then ns._RebuildDarkModeCache() end
	return c.fr, c.fg, c.fb, c.fa
end

-- Dark Mode background colour (r, g, b, a).
function ns.GetDarkModeBg()
	local c = ns._dmCache
	if c.gen ~= ns._dmGen then ns._RebuildDarkModeCache() end
	return c.br, c.bg, c.bb, c.ba
end

-------------------------------------------------------------------------------
--  Effective-colour cache (palette + darken), rebuilt lazily.
-------------------------------------------------------------------------------
ns._colorCache = { class = {}, power = {}, classResource = {}, resource = {}, classCustomized = {} }
ns._colorCacheDirty = true
ns._COLOR_WHITE = { r = 1, g = 1, b = 1 }
ns._powerBgDarkenFactor = 1

function ns.InvalidateColorCache()
	ns._colorCacheDirty = true
	ns._dmGen = ns._dmGen + 1
end

function ns._BuildColorPalette(out, defaults, custom, darkenPct)
	wipe(out)
	if defaults then
		for k, def in pairs(defaults) do out[k] = { r = def.r, g = def.g, b = def.b } end
	end
	if custom then
		for k, c in pairs(custom) do
			if type(c) == "table" and c.r then
				out[k] = { r = c.r, g = c.g or 0, b = c.b or 0 }
			end
		end
	end
	if darkenPct and darkenPct > 0 then
		local f = 1 - darkenPct / 100
		if f < 0 then f = 0 end
		for _, col in pairs(out) do
			col.r = col.r * f; col.g = col.g * f; col.b = col.b * f
		end
	end
end

function ns._RebuildColorCache()
	local cc = ns.GetCustomColorsDB()
	local dm = ns.GetDarkModeDB()
	local cache = ns._colorCache
	ns._BuildColorPalette(cache.class, CLASS_COLOR_MAP, cc.class, dm.classDarken)
	ns._BuildColorPalette(cache.power, ns.DEFAULT_POWER_COLORS, cc.power, dm.powerDarken)
	ns._BuildColorPalette(cache.classResource, ns.DEFAULT_CLASS_RESOURCE_COLORS, cc.classResource, dm.resourceDarken)
	ns._BuildColorPalette(cache.resource, ns.DEFAULT_RESOURCE_COLORS, cc.resource, dm.resourceDarken)
	local bgd = dm.powerBgDarken or 0
	ns._powerBgDarkenFactor = bgd > 0 and max(0, 1 - bgd / 100) or 1
	local customized = cache.classCustomized
	wipe(customized)
	for token, def in pairs(CLASS_COLOR_MAP) do
		local col = cache.class[token]
		if col and (abs(col.r - def.r) > 0.004 or abs(col.g - def.g) > 0.004 or abs(col.b - def.b) > 0.004) then
			customized[token] = col
		end
	end
	ns._colorCacheDirty = false
end

-- Class color (custom or default, Class Color Darken baked in). Unknown -> white.
function ns.GetClassColor(classToken)
	if ns._colorCacheDirty then ns._RebuildColorCache() end
	return (classToken and ns._colorCache.class[classToken]) or ns._COLOR_WHITE
end

-- True when the class colour differs from the default (an edit or a darken).
function ns.IsClassColorCustomized(classToken)
	if ns._colorCacheDirty then ns._RebuildColorCache() end
	return classToken and ns._colorCache.classCustomized[classToken] ~= nil
end

-- Power color (cached, darken baked in). nil for unknown keys.
function ns.GetPowerColor(powerKey)
	if ns._colorCacheDirty then ns._RebuildColorCache() end
	return powerKey and ns._colorCache.power[powerKey]
end

-- Multiplier (0-1) for power-colored bar backgrounds (BG Power Color Darken).
function ns.GetPowerBgDarkenFactor()
	if ns._colorCacheDirty then ns._RebuildColorCache() end
	return ns._powerBgDarkenFactor
end

-- Class-resource color by resource key (retail keys or the Mists Resource
-- Bars keys, e.g. HOLY_POWER). nil for unknown keys.
function ns.GetClassResourceColor(key)
	if not key then return nil end
	if ns._colorCacheDirty then ns._RebuildColorCache() end
	local cache = ns._colorCache.classResource
	return cache[key] or cache[ns.MISTS_RESOURCE_KEYS[key] or ""]
end

-- Resource color by class (cached, darken baked in).
function ns.GetResourceColor(classToken)
	if ns._colorCacheDirty then ns._RebuildColorCache() end
	return classToken and ns._colorCache.resource[classToken]
end

function ns.ResetPowerColor(powerKey)
	local db = ns.GetCustomColorsDB()
	db.power[powerKey] = nil
	ns.InvalidateColorCache()
end

-- Power key -> 5.4.8 power type index.
ns.POWER_KEY_TO_ENUM = {
	MANA = 0, RAGE = 1, FOCUS = 2, ENERGY = 3, RUNIC_POWER = 6,
}
ns.POWER_ENUM_TO_KEY = {}
for k, v in pairs(ns.POWER_KEY_TO_ENUM) do
	ns.POWER_ENUM_TO_KEY[v] = k
end

-- EUI power color (r, g, b or nil) for a unit's current power.
function ns.ResolveUnitPowerColor(unit)
	local pType, pToken, altR, altG, altB = UnitPowerType(unit)
	local info = ns.GetPowerColor(pToken)
	if info then return info.r, info.g, info.b end
	if altR then
		if altR > 1 or altG > 1 or altB > 1 then
			return altR / 255, altG / 255, altB / 255
		end
		return altR, altG, altB
	end
	local key = ns.POWER_ENUM_TO_KEY[pType]
	info = key and ns.GetPowerColor(key)
	if info then return info.r, info.g, info.b end
	return nil
end

-------------------------------------------------------------------------------
--  Dark Mode refreshers and per-module toggles (retail API).
-------------------------------------------------------------------------------
ns._darkModeRefreshers = ns._darkModeRefreshers or {}
function ns.RegisterDarkModeRefresh(fn)
	if type(fn) == "function" then
		ns._darkModeRefreshers[#ns._darkModeRefreshers + 1] = fn
	end
end

function ns.RefreshDarkMode()
	ns.InvalidateColorCache()
	for _, fn in ipairs(ns._darkModeRefreshers) do pcall(fn) end
	if ns.ApplyColorsToOUF then ns.ApplyColorsToOUF() end
end

ns._darkModeToggles = ns._darkModeToggles or {}
-- provider = { id, isOn = fn, setOn = fn(on) }
function ns.RegisterDarkModeToggle(provider)
	if type(provider) == "table" and type(provider.isOn) == "function"
		and type(provider.setOn) == "function" then
		for i, p in ipairs(ns._darkModeToggles) do
			if provider.id and p.id == provider.id then
				ns._darkModeToggles[i] = provider
				return
			end
		end
		ns._darkModeToggles[#ns._darkModeToggles + 1] = provider
	end
end

function ns.IsDarkModeAllOn(filter)
	local matched = false
	for _, p in ipairs(ns._darkModeToggles) do
		if not filter or filter(p) then
			matched = true
			local ok, on = pcall(p.isOn)
			if not ok or not on then return false end
		end
	end
	return matched
end

function ns.SetDarkModeAll(on, filter)
	on = on and true or false
	for _, p in ipairs(ns._darkModeToggles) do
		if not filter or filter(p) then
			pcall(p.setOn, on)
		end
	end
	ns.RefreshDarkMode()
end

-- Class token from a localized class name (male and female forms).
function ns.ClassTokenFromLocalized(name)
	if type(name) ~= "string" then return nil end
	local map = ns._classByLocalName
	if not map then
		map = {}
		if type(LOCALIZED_CLASS_NAMES_MALE) == "table" then
			for token, n in pairs(LOCALIZED_CLASS_NAMES_MALE) do map[n] = token end
		end
		if type(LOCALIZED_CLASS_NAMES_FEMALE) == "table" then
			for token, n in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do map[n] = token end
		end
		ns._classByLocalName = map
	end
	return map[name]
end

-- Universal "colours changed" entry point: drops the cache and repaints the
-- modules. 5.4.8: no oUF colour objects; the module getters read the cache,
-- and the settings window runs every module's apply hook after a change.
-- applyNow = true also runs the apply hooks here (callers outside the window).
function ns.ApplyColorsToOUF(applyNow)
	ns.InvalidateColorCache()
	if ns._SyncResourceBarsPalette then ns._SyncResourceBarsPalette() end
	-- Raid Frames (retail ERF:UpdateAllFrames)
	local ERF = _G.EllesmereUIRaidFrames
	if type(ERF) == "table" and ERF.UpdateAllFrames then
		pcall(ERF.UpdateAllFrames, ERF)
	end
	if applyNow then
		local hooks = ns.applyHooks or {}
		for i = 1, #hooks do
			pcall(hooks[i])
		end
	end
end

-------------------------------------------------------------------------------
--  Mists wiring: Dark Mode providers for the modules that have a Dark Mode
--  flag (retail registers them from the modules), and the Resource Bars
--  Dark Mode palette tables (ERB.DARK_FILL / DARK_BG) kept in sync.
-------------------------------------------------------------------------------
local function SyncResourceBarsPalette()
	local ERB = ns.ERB
	if not ERB then return end
	local fr, fg, fb = ns.GetDarkModeFill()
	local br, bg, bb = ns.GetDarkModeBg()
	if type(ERB.DARK_FILL) == "table" then
		ERB.DARK_FILL[1], ERB.DARK_FILL[2], ERB.DARK_FILL[3] = fr, fg, fb
	end
	if type(ERB.DARK_BG) == "table" then
		ERB.DARK_BG[1], ERB.DARK_BG[2], ERB.DARK_BG[3] = br, bg, bb
	end
end
ns.RegisterDarkModeRefresh(SyncResourceBarsPalette)
ns._SyncResourceBarsPalette = SyncResourceBarsPalette

local function RegisterMistsProviders()
	local UF = ns.UF
	if UF and not ns._dmUFRegistered then
		ns._dmUFRegistered = true
		ns.RegisterDarkModeToggle({ id = "unitFrames", label = "Unit Frames",
			isOn = function() return UF.db and UF.db.darkTheme == true end,
			setOn = function(on) if UF.db then UF.db.darkTheme = on end end })
	end
	local ERB = ns.ERB
	if ERB and not ns._dmRBRegistered then
		ns._dmRBRegistered = true
		ns.RegisterDarkModeToggle({ id = "resourceBars", label = "Class Resource Bar",
			isOn = function()
				local p = ERB.db and ERB.db.profile
				return p and p.secondary and p.secondary.darkTheme == true or false
			end,
			setOn = function(on)
				local p = ERB.db and ERB.db.profile
				if p and p.secondary then p.secondary.darkTheme = on end
			end })
	end
end
ns.RegisterMistsDarkModeProviders = RegisterMistsProviders

-- First login: the user's retail Colors values (profile "Naowh": the power
-- colour edits; Dark Mode darken amounts are 0 = default).
local SEED_POWER = {
	MANA = { r = 0, g = 0.63921568627451, b = 1 },
	MAELSTROM = { r = 0, g = 0.57254901960784, b = 1 },
	FOCUS = { r = 1, g = 0.50196078431373, b = 0.25098039215686 },
	RUNIC_POWER = { r = 0, g = 0.81960784313725, b = 1 },
	ENERGY = { r = 1, g = 0.96078431372549, b = 0.41176470588235 },
	LUNAR_POWER = { r = 0.83137254901961, g = 0.57647058823529, b = 1 },
	INSANITY = { r = 0.66666666666667, g = 0.2, b = 1 },
	FURY = { r = 0.78823529411765, g = 0.25882352941176, b = 0.98823529411765 },
	RAGE = { r = 1, g = 0.32156862745098, b = 0.32156862745098 },
}

local function SeedOnce()
	local db = DB()
	if db._colorsSeeded then return end
	db._colorsSeeded = 1
	local cc = ns.GetCustomColorsDB()
	for _, key in ipairs(ns.COLOR_CATEGORIES) do
		if next(cc[key]) then return end
	end
	for k, c in pairs(SEED_POWER) do
		cc.power[k] = { r = c.r, g = c.g, b = c.b }
	end
	ns.InvalidateColorCache()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_LOGIN")
	SeedOnce()
	ns._playerClass = select(2, UnitClass("player"))
	RegisterMistsProviders()
	ns.InvalidateColorCache()
	SyncResourceBarsPalette()
end)
ns._playerClass = select(2, UnitClass("player"))
