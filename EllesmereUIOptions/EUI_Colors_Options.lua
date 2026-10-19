-- Global Settings > Colors (EllesmereUI EUI_Colors_Options.lua). Registers
-- nothing: EUI__General_Options.lua adds the tab and calls
-- ns.GSO_BuildColorsPage(p). The store and getters are in the core
-- (EllesmereUI_Colors.lua).
--
-- Left out: "Apply to All Profiles" / "Pull Colors From" per section (the
-- Mists profiles keep colours per profile, see EllesmereUI_Colors.lua), the
-- retail-only classes (Demon Hunter, Evoker), powers (Astral Power,
-- Insanity, Maelstrom, Fury, Ebon Might) and resources (Essence, Soul
-- Fragments, Icicles, Tip of the Spear, Whirlwind, Sweeping Strikes). Their
-- saved values stay in the store (a retail import keeps them).

local ns = EllesmereUI
if not ns or not ns.GetCustomColorsDB then
	return
end

local floor = math.floor
local UNDO = ns.MEDIA .. "icons\\undo"

local CLASS_LABELS = {
	WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter",
	ROGUE = "Rogue", PRIEST = "Priest", DEATHKNIGHT = "Death Knight",
	SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock",
	MONK = "Monk", DRUID = "Druid",
}
local POWER_LABELS = {
	MANA = "Mana", RAGE = "Rage", FOCUS = "Focus", ENERGY = "Energy",
	RUNIC_POWER = "Runic Power",
}
-- Retail POWER_ORDER, the powers 5.4.8 has.
local POWER_ORDER = { "MANA", "RAGE", "FOCUS", "ENERGY", "RUNIC_POWER" }
-- Retail CLASS RESOURCE COLORS rows (5.4.8 resources), then the Mists ones.
local RESOURCE_ITEMS = {
	{ key = "ComboPoints",     label = "Combo Points"     },
	{ key = "Runes",           label = "Runes"            },
	{ key = "SoulShards",      label = "Soul Shards"      },
	{ key = "HolyPower",       label = "Holy Power"       },
	{ key = "ArcaneCharges",   label = "Arcane Charges"   },
	{ key = "Chi",             label = "Chi"              },
	{ key = "MaelstromWeapon", label = "Maelstrom Weapon" },
	{ key = "ShadowOrbs",      label = "Shadow Orbs"      },
	{ key = "BurningEmbers",   label = "Burning Embers"   },
	{ key = "LightningShield", label = "Lightning Shield" },
}

-- Retail Dark Mode rows: Unit Frames, Raid Frames, Class Resource Bar (a
-- module that is off registers no provider: no row for it).
local DM_ITEMS = {
	{ key = "unitFrames",   label = "Unit Frames" },
	{ key = "raidFrames",   label = "Raid & Party Frames" },
	{ key = "resourceBars", label = "Class Resource Bar" },
}

local function DMProvider(id)
	for _, p in ipairs(ns._darkModeToggles or {}) do
		if p.id == id then return p end
	end
end

local function Changed()
	ns.ApplyColorsToOUF()
end

-- One colour cell: label (class coloured for classes), swatch, reset icon.
local function ColorCell(p, label, getColor, saveColor, resetFn)
	p:ColorRow(label, nil,
		function()
			local c = getColor()
			return c.r, c.g, c.b, 1
		end,
		function(r, g, b)
			saveColor({ r = r, g = g, b = b })
			Changed()
		end)
	p:InlineIcon("Reset to default", UNDO, function()
		resetFn()
		Changed()
	end, 16)
end

local function SaveColorEntry(category, key, data)
	local db = ns.GetCustomColorsDB()
	db[category][key] = data
	ns.InvalidateColorCache()
end

function ns.GSO_BuildColorsPage(p)
	if ns.RegisterMistsDarkModeProviders then
		ns.RegisterMistsDarkModeProviders()
	end
	local DM_DEF = ns.DEFAULT_DARK_MODE
	local function DMDB() return ns.GetDarkModeDB() end

	---------------------------------------------------------------------
	-- DARK MODE (per profile)
	---------------------------------------------------------------------
	p:Section("Dark Mode")
	local function DMList()
		local items = {}
		for _, it in ipairs(DM_ITEMS) do
			if DMProvider(it.key) then
				items[#items + 1] = { value = it.key, name = it.label }
			end
		end
		return items
	end
	p:MultiSelect("Dark Mode", "Turns Dark Mode on or off for each module.",
		DMList,
		function(id)
			local pr = DMProvider(id)
			if not pr then return false end
			local ok, on = pcall(pr.isOn)
			return (ok and on) and true or false
		end,
		function(id)
			local pr = DMProvider(id)
			if not pr then return end
			local ok, on = pcall(pr.isOn)
			ns.SetDarkModeAll(not (ok and on), function(x) return x.id == id end)
		end,
		function()
			local on = {}
			for _, it in ipairs(DMList()) do
				local pr = DMProvider(it.value)
				local ok, v = pcall(pr.isOn)
				if ok and v then on[#on + 1] = it.name end
			end
			if #on == 0 then return "None" end
			return table.concat(on, ", ")
		end)
	p:Label("Color Darkening", "Darkens class, resource and power colors.")
	local function Darken(key, label, tip)
		return { type = "slider", label = label, tip = tip, min = 0, max = 100, step = 5,
			get = function() return DMDB()[key] or 0 end,
			set = function(v)
				DMDB()[key] = v
				ns.RefreshDarkMode()
			end }
	end
	p:Cog("Color Darkening", {
		Darken("classDarken", "Class", "Darkens every class color."),
		Darken("resourceDarken", "Resource", "Darkens every class resource color."),
		Darken("powerDarken", "Power", "Darkens every power color."),
		Darken("powerBgDarken", "BG Power", "Darkens power-colored bar backgrounds."),
	})

	p:Slider("Dark Mode Fill", "Fill color and opacity of Dark Mode bars.", 0, 100, 5,
		function() return floor((DMDB().fillA or DM_DEF.fillA) * 100 + 0.5) end,
		function(v)
			DMDB().fillA = v / 100
			ns.RefreshDarkMode()
		end)
	p:Swatch("Fill Color",
		function()
			local d = DMDB()
			return d.fillR or DM_DEF.fillR, d.fillG or DM_DEF.fillG, d.fillB or DM_DEF.fillB, 1
		end,
		function(r, g, b)
			local d = DMDB()
			d.fillR, d.fillG, d.fillB = r, g, b
			ns.RefreshDarkMode()
		end)
	p:Slider("Background", "Color and opacity behind Dark Mode bars.", 0, 100, 5,
		function() return floor((DMDB().bgA or DM_DEF.bgA) * 100 + 0.5) end,
		function(v)
			DMDB().bgA = v / 100
			ns.RefreshDarkMode()
		end)
	p:Swatch("Background Color",
		function()
			local d = DMDB()
			return d.bgR or DM_DEF.bgR, d.bgG or DM_DEF.bgG, d.bgB or DM_DEF.bgB, 1
		end,
		function(r, g, b)
			local d = DMDB()
			d.bgR, d.bgG, d.bgB = r, g, b
			ns.RefreshDarkMode()
		end)

	---------------------------------------------------------------------
	-- CLASS COLORS
	---------------------------------------------------------------------
	p:Section("Class Colors")
	for _, token in ipairs(ns.CLASS_TOKEN_ORDER) do
		local lbl = (type(LOCALIZED_CLASS_NAMES_MALE) == "table" and LOCALIZED_CLASS_NAMES_MALE[token]) or CLASS_LABELS[token]
		local def = ns.CLASS_COLOR_MAP[token] or { r = 1, g = 1, b = 1 }
		local text = format("|cff%02x%02x%02x%s|r", floor(def.r * 255 + 0.5), floor(def.g * 255 + 0.5), floor(def.b * 255 + 0.5), lbl)
		ColorCell(p, text,
			function()
				local db = ns.GetCustomColorsDB()
				return db.class[token] or { r = def.r, g = def.g, b = def.b }
			end,
			function(c) SaveColorEntry("class", token, c) end,
			function() ns.GetCustomColorsDB().class[token] = nil end)
	end

	---------------------------------------------------------------------
	-- POWER COLORS
	---------------------------------------------------------------------
	p:Section("Power Colors")
	for _, pk in ipairs(POWER_ORDER) do
		local lbl = (type(_G[pk]) == "string" and _G[pk]) or POWER_LABELS[pk] or pk
		local def = ns.DEFAULT_POWER_COLORS[pk] or { r = 1, g = 1, b = 1 }
		ColorCell(p, lbl,
			function()
				local db = ns.GetCustomColorsDB()
				return db.power[pk] or { r = def.r, g = def.g, b = def.b }
			end,
			function(c) SaveColorEntry("power", pk, c) end,
			function() ns.ResetPowerColor(pk) end)
	end

	---------------------------------------------------------------------
	-- CLASS RESOURCE COLORS
	---------------------------------------------------------------------
	p:Section("Class Resource Colors")
	for _, it in ipairs(RESOURCE_ITEMS) do
		local key = it.key
		local def = ns.DEFAULT_CLASS_RESOURCE_COLORS[key] or { r = 1, g = 1, b = 1 }
		ColorCell(p, it.label,
			function()
				local db = ns.GetCustomColorsDB()
				return db.classResource[key] or { r = def.r, g = def.g, b = def.b }
			end,
			function(c) SaveColorEntry("classResource", key, c) end,
			function() ns.GetCustomColorsDB().classResource[key] = nil end)
	end
end
