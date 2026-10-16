-- Settings page of QoL Addons > AuraBuff Reminders (retail
-- EUI_AuraBuffReminders_Options.lua: same sections, labels, tooltips and
-- keys, built with this window's Page API). Two tabs: "Auras, Buffs &
-- Consumables" and "Talent Reminders".
--
-- 5.4.8 differences: no preview header (the live reminders stay on screen
-- while the window is open); the per-buff checkbox grids are two-column
-- toggles; Border Style is Solid only; the class sections list the Mists of
-- Pandaria spells (Paladin Seals instead of Rites, MoP poisons, imbues,
-- stances); the Talent Reminders picker lists your MoP talents.
-- Part of EllesmereUIOptions (load on demand); skipped when the module is not
-- loaded. Setters only store: the runtime's ns.applyHooks entry applies.

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUIAuraBuffReminders") then
	return
end
local EABR = ns.ABR
if not EABR then
	return
end
local D = EABR.DATA
local U = ns.OptionsUtil
local format = string.format

local function Prof() return EABR.Profile() end
local function DDB() return Prof().display end
local function RDB() return Prof().raidBuffs end
local function ADB() return Prof().auras end
local function CDB() return Prof().consumables end

local SPECIAL_WHERE_TIP = "Pick which content the class-special reminders (poisons/seals/imbues/shields) appear in.\nRested areas (cities and inns) always stay hidden."

local function ClassLabel(name, cls)
	local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
	if not c then return name end
	return format("|cff%02x%02x%02x%s|r", math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5), name)
end

local function SpellLabel(id, fallback)
	return EABR.SpellName(id, fallback)
end

local function Items(list)
	local out = {}
	for i = 1, #list do
		out[i] = { value = list[i][1], name = list[i][2] }
	end
	return out
end

local function LabelOf(list, v)
	for i = 1, #list do
		if list[i][1] == v then return list[i][2] end
	end
	return tostring(v or "")
end

---------------------------------------------------------------------------
-- Where to Show / Show When / sounds
---------------------------------------------------------------------------
local WHERE_ITEMS = {
	{ "open_world",        "Open World" },
	{ "raid_heroic",       "Heroic Raid" },
	{ "raid_normal_lfr",   "Normal/LFR Raid" },
	{ "dungeon_mythic",    "Challenge Mode Dungeons" },
	{ "dungeon_nonmythic", "Normal/Heroic Dungeons" },
	{ "scenario",          "Scenario" },
	{ "in_combat",         "In Combat" },
}
local SHOWWHEN_ITEMS = {
	{ "othersMissing", "Others are missing my buff" },
	{ "iAmMissing",    "I am missing others' buffs" },
}

-- Stored explicitly true / false (an absent bucket = shown).
local function WhereRow(p, store, tooltip)
	local function T()
		local t = store()
		return t
	end
	p:MultiSelect("Where to Show", tooltip,
		function() return Items(WHERE_ITEMS) end,
		function(k) return T()[k] ~= false end,
		function(k) local t = T(); t[k] = (t[k] == false) end,
		function()
			local on = 0
			for _, it in ipairs(WHERE_ITEMS) do if T()[it[1]] ~= false then on = on + 1 end end
			if on == #WHERE_ITEMS then return "Everywhere" end
			if on == 0 then return "Nowhere" end
			return on .. " of " .. #WHERE_ITEMS
		end)
end

local function SoundItems()
	local out = {}
	for i, k in ipairs(D.SOUND_ORDER) do
		out[i] = { value = k, name = D.SOUND_NAMES[k] or k }
	end
	return out
end

local function SetSound(sec, field, v)
	local t = sec()
	if v == "none" then t[field] = nil else t[field] = v end
	local path = EABR.SoundPath(v)
	if path then PlaySoundFile(path, "Master") end
end

local function SoundRow(p, sec, field)
	p:Dropdown("Reminder Sound", "Play a sound once when a reminder in this section newly appears.",
		SoundItems,
		function() return sec()[field] or "none" end,
		function() local v = sec()[field] or "none"; return D.SOUND_NAMES[v] or v end,
		function(v) SetSound(sec, field, v) end)
end

local function EnabledToggle(p, store, key, label, tooltip, defaultOff)
	p:Toggle(label, tooltip,
		function()
			local v = store().enabled[key]
			if defaultOff then return v == true end
			return v ~= false and v ~= nil
		end,
		function(v) store().enabled[key] = v and true or false end)
end

---------------------------------------------------------------------------
-- Fonts / glows
---------------------------------------------------------------------------
local function FontItems()
	local lead = { { name = "EUI Global Font", value = "__global" } }
	return U.FontItems and U.FontItems(lead) or lead
end
local function FontLabel(v)
	v = v or "__global"
	for _, it in ipairs(FontItems()) do
		if it.value == v then return it.name end
	end
	return tostring(v)
end

local GROW_DIRS = { { "CENTER", "Grow Centered" }, { "LEFT", "Grow Left" }, { "RIGHT", "Grow Right" } }
local STRATAS = { { "BACKGROUND", "Background" }, { "LOW", "Low" }, { "MEDIUM", "Medium" }, { "HIGH", "High" }, { "DIALOG", "Dialog" } }
local ANCHORS = { { "BOTTOM", "Bottom" }, { "TOP", "Top" }, { "CENTER", "Center" }, { "LEFT", "Left" }, { "RIGHT", "Right" } }
local GLOW_MODES = { { "default", "Default" }, { "class", "Class Color" }, { "custom", "Custom" } }

---------------------------------------------------------------------------
-- Page 1: Auras, Buffs & Consumables
---------------------------------------------------------------------------
local function BuildReminders(p)
	local function off() return DDB().remindersEnabled == false end

	p:Section("CORE")
	p:Toggle("Enable AuraBuff Reminders",
		"Master toggle for all aura, buff, and consumable reminders. Talent reminders are not affected.",
		function() return DDB().remindersEnabled ~= false end,
		function(v) DDB().remindersEnabled = v end)
	p:Slider("Scale", nil, 0.5, 3.0, 0.05,
		function() return DDB().scale or 1.0 end,
		function(v) DDB().scale = v end, off)
	p:Dropdown("Grow Direction", "Which part of the row stays in place as reminders appear and disappear.",
		function() return Items(GROW_DIRS) end,
		function() return DDB().growDirection or "CENTER" end,
		function() return LabelOf(GROW_DIRS, DDB().growDirection or "CENTER") end,
		function(v) ns.SetAuraBuffGrowDir(v) end, nil, off)
	p:Blank()

	p:Section("DISPLAY")
	p:Dropdown("Border Style", "5.4.8 has the Solid border only.",
		function() return { { value = "solid", name = "Solid" } } end,
		function() return "solid" end, function() return "Solid" end,
		function(v) DDB().borderTexture = v end, nil, off)
	p:Slider("Border Size", nil, 0, 4, 1,
		function() return DDB().borderSize or 1 end,
		function(v) DDB().borderSize = v end, off)
	p:Swatch("Border Color",
		function() local d = DDB(); return d.borderR or 0, d.borderG or 0, d.borderB or 0, d.borderA or 1 end,
		function(r, g, b, a) local d = DDB(); d.borderR, d.borderG, d.borderB, d.borderA = r, g, b, a or 1 end,
		{ alpha = true })
	p:Cog("Border Options", {
		{ type = "toggle", label = "Show Behind",
			get = function() return DDB().borderBehind == true end,
			set = function(v) DDB().borderBehind = v end },
	})

	p:Toggle("Show Name", nil,
		function() return DDB().showText end,
		function(v) DDB().showText = v end, off)
	p:Swatch("Name Color",
		function() local c = DDB().textColor or { r = 1, g = 1, b = 1 }; return c.r, c.g, c.b, 1 end,
		function(r, g, b) DDB().textColor = { r = r, g = g, b = b } end)
	p:Cog("Name Settings", {
		{ type = "dropdown", label = "Name Font", items = FontItems,
			get = function() return DDB().nameFont or "__global" end,
			labelFn = function() return FontLabel(DDB().nameFont) end,
			set = function(v) DDB().nameFont = (v ~= "__global") and v or nil end,
			options = { fontPreview = true, fontPath = function(v)
				if v == "__global" then return ns.GetFontPath("auraBuff") end
				return ns.ResolveFontName(v)
			end } },
		{ type = "slider", label = "Text Size", min = 6, max = 30, step = 1,
			get = function() return DDB().textSize or 12 end, set = function(v) DDB().textSize = v end },
		{ type = "dropdown", label = "Anchor", items = function() return Items(ANCHORS) end,
			get = function() return DDB().textAnchor or "BOTTOM" end,
			set = function(v) DDB().textAnchor = v end },
		{ type = "slider", label = "X Offset", min = -50, max = 50, step = 1,
			get = function() return DDB().textXOffset or 0 end, set = function(v) DDB().textXOffset = v end },
		{ type = "slider", label = "Y Offset", min = -50, max = 50, step = 1,
			get = function() return DDB().textYOffset or -5 end, set = function(v) DDB().textYOffset = v end },
	}, { disabled = function() return not DDB().showText end })

	p:Toggle("Show Item Count", "Show how many of the consumable you have left in your bags.",
		function() return DDB().showCount ~= false end,
		function(v) DDB().showCount = v end, off)
	p:Cog("Item Count Settings", {
		{ type = "dropdown", label = "Item Count Font", items = FontItems,
			get = function() return DDB().countFont or "__global" end,
			labelFn = function() return FontLabel(DDB().countFont) end,
			set = function(v) DDB().countFont = (v ~= "__global") and v or nil end },
		{ type = "slider", label = "Text Size", min = 6, max = 30, step = 1,
			get = function() return DDB().countSize or 16 end, set = function(v) DDB().countSize = v end },
		{ type = "slider", label = "X Offset", min = -50, max = 50, step = 1,
			get = function() return DDB().countXOffset or 0 end, set = function(v) DDB().countXOffset = v end },
		{ type = "slider", label = "Y Offset", min = -50, max = 50, step = 1,
			get = function() return DDB().countYOffset or 0 end, set = function(v) DDB().countYOffset = v end },
	}, { disabled = function() return DDB().showCount == false end })

	p:Toggle("Attach Important Buffs to Cursor", "This option only affects Raid Buffs.",
		function() return DDB().cursorAttach end,
		function(v) DDB().cursorAttach = v end, off)
	p:Dropdown("Glow", "Glow on the reminder icons.",
		function() local out = {}; for i, g in ipairs(EABR.GLOW_TYPES) do out[i] = { value = g[1], name = g[2] } end; return out end,
		function() return DDB().glowType or 0 end,
		function() return LabelOf(EABR.GLOW_TYPES, DDB().glowType or 0) end,
		function(v) DDB().glowType = v end, nil, off)
	p:Dropdown("Glow Color", nil,
		function() return Items(GLOW_MODES) end,
		function() EABR.EnsureGlowModeMigrated(DDB()); return DDB().glowColorMode or "default" end,
		function() return LabelOf(GLOW_MODES, DDB().glowColorMode or "default") end,
		function(v) DDB().glowColorMode = v end, nil,
		function() return (DDB().glowType or 0) == 0 end)
	p:Swatch("Custom Glow Color",
		function()
			local c = DDB().glowColor or EABR.DEFAULT_GLOW_COLOR
			return c.r, c.g, c.b, 1
		end,
		function(r, g, b) DDB().glowColor = { r = r, g = g, b = b }; DDB().glowColorMode = "custom" end,
		{ active = function() return DDB().glowColorMode == "custom" end })
	p:Blank()

	p:Slider("Icon Spacing", nil, 0, 50, 1,
		function() return DDB().iconSpacing or 8 end,
		function(v) DDB().iconSpacing = v end, off)
	p:Cog("Layout Settings", {
		{ type = "slider", label = "Y Offset", min = -600, max = 600, step = 1,
			get = function() return DDB().yOffset or 200 end, set = function(v) DDB().yOffset = v end },
	})
	p:Dropdown("Frame Strata", nil,
		function() return Items(STRATAS) end,
		function() return DDB().frameStrata or "MEDIUM" end,
		function() return LabelOf(STRATAS, DDB().frameStrata or "MEDIUM") end,
		function(v) DDB().frameStrata = v end, nil, off)
	p:Slider("Show Below (min)", "Show reminders when remaining buff time is below this many minutes.\n0 = only when fully expired.\nIgnored in combat and during a running Challenge Mode (then only when the buff is gone).", 0, 60, 1,
		function() return DDB().showUnder or 5 end,
		function(v) DDB().showUnder = v end, off)
	p:Slider("Show Below Pre-Key (min)", "Reminder threshold while you are in a Challenge Mode dungeon before the timer starts. Set it high enough that you top up buffs and food before pulling.\n0 = only when fully expired.\nIgnored once the timer runs or you are in combat (then only when the buff is fully gone).", 0, 60, 1,
		function() return DDB().showUnderMPlus or 40 end,
		function(v) DDB().showUnderMPlus = v end, off)
	p:Toggle("Show Tooltips", "Show item or spell tooltips when hovering reminder icons.",
		function() return DDB().showTooltips ~= false end,
		function(v) DDB().showTooltips = v end, off)
	p:Slider("Opacity", nil, 0, 1, 0.05,
		function() return DDB().opacity or 1 end,
		function(v) DDB().opacity = v end, off)

	-- RAID BUFFS
	p:Section("RAID BUFFS")
	WhereRow(p, function() local r = RDB(); r.whereToShow = r.whereToShow or {}; return r.whereToShow end,
		"Pick which content this section's reminders appear in.\nRested areas (cities and inns) always stay hidden.")
	p:MultiSelect("Show When",
		"Others are missing my buff: remind when a groupmate is missing a buff you can cast.\nI am missing others' buffs: remind when you are missing a buff a groupmate could give you (only shown when someone who can cast it is present). Off by default.",
		function() return Items(SHOWWHEN_ITEMS) end,
		function(k)
			local t = RDB().showWhen or {}
			if k == "othersMissing" then return t[k] ~= false end
			return t[k] == true
		end,
		function(k)
			local r = RDB()
			r.showWhen = r.showWhen or {}
			local cur = (k == "othersMissing") and (r.showWhen[k] ~= false) or (r.showWhen[k] == true)
			r.showWhen[k] = not cur
		end,
		function()
			local t = RDB().showWhen or {}
			local a, b = t.othersMissing ~= false, t.iAmMissing == true
			if a and b then return "Both" end
			if a then return "Others missing" end
			if b then return "I am missing" end
			return "Never"
		end)
	p:Cog("Reminder Sound", {
		{ type = "dropdown", label = "Sound", items = SoundItems,
			tip = "Play a sound once when a reminder in this section newly appears.",
			get = function() return RDB().sectionSound or "none" end,
			set = function(v) SetSound(RDB, "sectionSound", v) end },
	})
	for _, buff in ipairs(D.RAID_BUFFS) do
		EnabledToggle(p, RDB, buff.key, ClassLabel(SpellLabel(buff.castSpell, buff.name), buff.class))
	end
	p:CloseRow()

	-- AURAS
	p:Section("AURAS")
	WhereRow(p, function() local a = ADB(); a.whereToShow = a.whereToShow or {}; return a.whereToShow end,
		"Pick which content these aura reminders appear in.\nRested areas (cities and inns) always stay hidden.")
	SoundRow(p, ADB, "sectionSound")
	for _, aura in ipairs(D.AURAS) do
		if aura.key ~= "soulstone" then
			EnabledToggle(p, ADB, aura.key, ClassLabel(SpellLabel(aura.castSpell, aura.name), aura.class))
		end
	end
	p:CloseRow()

	local function SpecialWhere()
		local c = CDB(); c.specialsWhereToShow = c.specialsWhereToShow or {}; return c.specialsWhereToShow
	end

	-- ROGUE POISONS
	p:Section("ROGUE POISONS")
	WhereRow(p, SpecialWhere, SPECIAL_WHERE_TIP)
	SoundRow(p, CDB, "specialsSound")
	for _, it in ipairs(D.ROGUE_POISONS) do
		EnabledToggle(p, CDB, it.key, ClassLabel(SpellLabel(it.castSpell, it.name), "ROGUE"))
	end
	p:CloseRow()

	-- PALADIN SEALS (retail: Paladin Rites)
	p:Section("PALADIN SEALS")
	WhereRow(p, SpecialWhere, SPECIAL_WHERE_TIP)
	SoundRow(p, CDB, "specialsSound")
	for _, it in ipairs(D.PALADIN_SEALS) do
		EnabledToggle(p, CDB, it.key, ClassLabel(SpellLabel(it.castSpell, it.name), "PALADIN"),
			"Reminds you when no seal is active. Your spec's usual seal is cast first (Holy / Protection: Seal of Insight, Retribution: Seal of Truth) when it is ticked.")
	end
	p:CloseRow()

	-- SHAMAN IMBUES & SHIELDS
	p:Section("SHAMAN IMBUES & SHIELDS")
	WhereRow(p, SpecialWhere, SPECIAL_WHERE_TIP)
	SoundRow(p, CDB, "specialsSound")
	for _, it in ipairs(D.SHAMAN_IMBUES) do
		EnabledToggle(p, CDB, it.key, ClassLabel(SpellLabel(it.castSpell, it.name), "SHAMAN"),
			"Weapon imbue by spec: Enhancement Windfury (main hand) + Flametongue (off hand), Elemental Flametongue, Restoration Earthliving.")
	end
	EnabledToggle(p, CDB, "shield_basic", ClassLabel("Shield", "SHAMAN"),
		"Lightning Shield (Restoration: Water Shield) on yourself.")
	EnabledToggle(p, CDB, "es_ally", ClassLabel("Earth Shield (Ally)", "SHAMAN"),
		"Out of combat, reminds you when no groupmate has your Earth Shield.", true)
	p:CloseRow()

	-- PETS
	p:Section("PETS")
	p:Toggle("Missing Pet",
		"Show a reminder when you don't have an active pet summoned. Only applies to pet classes (Hunter, Warlock, Death Knight, Mage).",
		function() return CDB().enabled.pet ~= false end,
		function(v) CDB().enabled.pet = v end)
	p:Toggle("Passive Pet",
		"Show a reminder when your active pet is set to Passive stance. Only applies to pet classes (Hunter, Warlock, Death Knight, Mage).",
		function() return CDB().enabled.pet_passive ~= false end,
		function(v) CDB().enabled.pet_passive = v end)

	-- WARLOCK
	p:Section("WARLOCK")
	WhereRow(p, function() local c = CDB(); c.warlockWhereToShow = c.warlockWhereToShow or {}; return c.warlockWhereToShow end,
		"Pick which content these Warlock reminders appear in.\nRested areas (cities and inns) always stay hidden.")
	p:Blank()
	p:Toggle("Wrong Demon",
		"Show a reminder when your Warlock's active pet isn't one of the demons picked in Allowed Demons. A demon only counts while its summon spell is known. (English clients only: 5.4.8 gives the pet family as a name.)",
		function() return CDB().enabled.wrong_pet ~= false end,
		function(v) CDB().enabled.wrong_pet = v end)
	p:MultiSelect("Allowed Demons",
		"Pick which demons count as correct for Wrong Demon. A demon only counts while its summon spell is known; with none picked (or everything picked), the reminder never fires.",
		function()
			local out = {}
			for i, pet in ipairs(D.WARLOCK_PETS) do out[i] = { value = pet.key, name = SpellLabel(pet.castSpell, pet.name) } end
			return out
		end,
		function(k) return (CDB().wrongPetAllowed or {})[k] == true end,
		function(k)
			local c = CDB()
			c.wrongPetAllowed = c.wrongPetAllowed or {}
			c.wrongPetAllowed[k] = not (c.wrongPetAllowed[k] == true)
		end,
		function()
			local n = 0
			for _, v in pairs(CDB().wrongPetAllowed or {}) do if v then n = n + 1 end end
			return n .. " of " .. #D.WARLOCK_PETS
		end)
	p:Toggle(SpellLabel(20707, "Soulstone"),
		"Show a reminder until your own Soulstone is active on you or another group member.",
		function() return ADB().enabled.soulstone == true end,
		function(v) ADB().enabled.soulstone = v end)
	p:Blank()

	-- CONSUMABLES
	p:Section("CONSUMABLES")
	WhereRow(p, function() local c = CDB(); c.whereToShow = c.whereToShow or {}; return c.whereToShow end,
		"Pick which content these consumable reminders appear in.\nRested areas (cities and inns) always stay hidden.")
	SoundRow(p, CDB, "sectionSound")
	local function PrefItems(list, nameOf)
		local out = { { value = "last_used", name = "Last Used" } }
		for _, e in ipairs(list) do out[#out + 1] = { value = e.key, name = nameOf(e) } end
		return out
	end
	local function FlaskName(e) return (GetItemInfo(e.items[1])) or e.name end
	local function FoodName(e) return (GetItemInfo(e.itemID)) or e.name end
	p:Toggle("Flask", nil,
		function() return CDB().enabled.flask ~= false end,
		function(v) CDB().enabled.flask = v end)
	p:Dropdown("Preferred (Click to Buff)", "Which flask the reminder uses. Last Used follows the flask you used last; with none in your bags the one for your main stat is picked.",
		function() return PrefItems(D.FLASK_ITEMS, FlaskName) end,
		function() return CDB().preferredFlask or "last_used" end,
		function()
			for _, it in ipairs(PrefItems(D.FLASK_ITEMS, FlaskName)) do
				if it.value == (CDB().preferredFlask or "last_used") then return it.name end
			end
			return "Last Used"
		end,
		function(v) CDB().preferredFlask = v end, nil,
		function() return CDB().enabled.flask == false end)
	p:Toggle("Food", nil,
		function() return CDB().enabled.food ~= false end,
		function(v) CDB().enabled.food = v end)
	p:Dropdown("Preferred (Click to Buff)", "Which food the reminder uses. Last Used follows the food you ate last; with none in your bags the one for your main stat is picked.",
		function() return PrefItems(D.FOOD_ITEMS, FoodName) end,
		function() return CDB().preferredFood or "last_used" end,
		function()
			for _, it in ipairs(PrefItems(D.FOOD_ITEMS, FoodName)) do
				if it.value == (CDB().preferredFood or "last_used") then return it.name end
			end
			return "Last Used"
		end,
		function(v) CDB().preferredFood = v end, nil,
		function() return CDB().enabled.food == false end)
	p:Toggle("Healthstone", "Remind you to take a Healthstone when a Warlock is in your group and you carry none.",
		function() return CDB().enabled.healthstone ~= false end,
		function(v) CDB().enabled.healthstone = v end)
	p:Toggle("Runeforge", "Death Knight: remind you when a weapon has no rune.",
		function() return CDB().enabled.runeforge ~= false end,
		function(v) CDB().enabled.runeforge = v end)
	p:Toggle("Show Without Item in Bags",
		"When on, flask/food reminders still show (dimmed) when you have no matching item in your bags, as a prompt to restock.\nWhen off, they are hidden entirely if you don't carry the item.",
		function() return CDB().showWithoutItem ~= false end,
		function(v) CDB().showWithoutItem = v end)
	local function rcwOff() return CDB().rcManaWarn == false end
	p:Toggle("Ready Check Mana Warning",
		"Flashes LOW MANA during an out-of-combat raid ready check while you are a healer under 80% mana.",
		function() return CDB().rcManaWarn ~= false end,
		function(v)
			CDB().rcManaWarn = v
			if not v then EABR.RCWHide() end
		end)
	p:Swatch("Mana Warning Color",
		function() local r, g, b = EABR.RCWColor(); return r, g, b, 1 end,
		function(r, g, b) CDB().rcManaWarnColor = { r = r, g = g, b = b }; EABR.RCWApplySettings() end,
		{ disabled = rcwOff })
	p:Cog("Mana Warning Settings", {
		{ type = "toggle", label = "Preview",
			get = function() return EABR._rcwPreview == true end,
			set = function(v)
				EABR._rcwPreview = v and true or nil
				if v then EABR.RCWShow() else EABR.RCWHide() end
			end },
		{ type = "dropdown", label = "Mana Warning Font", items = FontItems,
			get = function() return CDB().rcManaWarnFont or "__global" end,
			labelFn = function() return FontLabel(CDB().rcManaWarnFont) end,
			set = function(v) CDB().rcManaWarnFont = (v ~= "__global") and v or nil; EABR.RCWApplySettings() end },
		{ type = "slider", label = "Text Size", min = 10, max = 72, step = 1,
			get = function() return CDB().rcManaWarnSize or 48 end,
			set = function(v) CDB().rcManaWarnSize = v; EABR.RCWApplySettings() end },
		{ type = "slider", label = "X Offset", min = -600, max = 600, step = 1,
			get = function() return CDB().rcManaWarnX or 0 end,
			set = function(v) CDB().rcManaWarnX = v; EABR.RCWApplySettings() end },
		{ type = "slider", label = "Y Offset", min = -600, max = 600, step = 1,
			get = function() return CDB().rcManaWarnY or 0 end,
			set = function(v) CDB().rcManaWarnY = v; EABR.RCWApplySettings() end },
	}, { disabled = rcwOff })

	-- CUSTOM SPELLS (retail Add Custom Spell, consumables.customIDs): a
	-- reminder whenever that buff is missing (same Where to Show).
	p:Section("CUSTOM SPELLS")
	p:Button("Add Custom Spell", "Type a spell ID to be reminded whenever that buff is missing. Unknown IDs are ignored.", "Add Spell ID", function()
		ns.ShowInputPopup({
			title = "Add Custom Spell",
			message = "Enter the spell ID of the buff to be reminded about.",
			text = "",
			confirmText = "Add",
			cancelText = "Cancel",
			onConfirm = function(text)
				local id = tonumber((text or ""):match("^%s*(%d+)%s*$"))
				if not (id and GetSpellInfo(id)) then return end
				local c = CDB()
				c.customIDs = c.customIDs or {}
				for _, v in ipairs(c.customIDs) do
					if v == id then return end
				end
				c.customIDs[#c.customIDs + 1] = id
				EABR.RequestRefresh()
				ns.RebuildSettingsPage()
			end,
		})
	end)
	for i, id in ipairs(CDB().customIDs or {}) do
		local name, _, icon = GetSpellInfo(id)
		p:Button(format("|T%s:16:16:0:0:64:64:5:59:5:59|t %s |cff808080(%d)|r", icon or "Interface\\Icons\\INV_Misc_QuestionMark", name or "?", id),
			"Remove this custom reminder.", "Remove", function()
				table.remove(CDB().customIDs, i)
				EABR.RequestRefresh()
				ns.RebuildSettingsPage()
			end)
	end
end

---------------------------------------------------------------------------
-- Page 2: Talent Reminders
---------------------------------------------------------------------------
local pickZones, pickTalent = {}, nil

local function ZoneItems()
	local out = {}
	local lastType = nil
	for _, z in ipairs(D.TALENT_ZONES) do
		if z.type ~= lastType then
			lastType = z.type
			out[#out + 1] = { header = true, name = (z.type == "raid" and "Raids") or (z.type == "dungeon" and "Dungeons") or "PvP" }
		end
		out[#out + 1] = { value = z.name, name = z.name }
	end
	return out
end

local function TalentItems()
	local out = {}
	for i = 1, 18 do
		local name, texture, selected, tier = EABR.TalentInfo(i)
		if name then
			out[#out + 1] = { value = i, name = "|T" .. tostring(texture) .. ":14:14:0:0:64:64:5:59:5:59|t " .. name .. " |cff808080(" .. (tier or "?") .. ")|r" }
		end
	end
	if #out == 0 then out[1] = { value = 0, name = "No talents found" } end
	return out
end

local function BuildTalents(p)
	p:Section("ADD REMINDER")
	p:MultiSelect("Select Dungeon/Raid/PvP Zone", "The zones where the talent should be picked.",
		ZoneItems,
		function(v) return pickZones[v] == true end,
		function(v) pickZones[v] = not pickZones[v] or nil end,
		function()
			local n = 0
			for _ in pairs(pickZones) do n = n + 1 end
			if n == 0 then return "Select zones..." end
			return n .. " zone" .. (n > 1 and "s" or "")
		end)
	p:Dropdown("Talent", "Your class talents (the number is the talent row).",
		TalentItems,
		function() return pickTalent end,
		function()
			if not pickTalent then return "Select a talent..." end
			local name = EABR.TalentInfo(pickTalent)
			return name or "Select a talent..."
		end,
		function(v) if v and v > 0 then pickTalent = v end end)
	p:Button("Add Reminder", "Adds a reminder for the picked talent in the picked zones.", "Add Reminder", function()
		if not pickTalent or not next(pickZones) then return end
		local name, texture = EABR.TalentInfo(pickTalent)
		if not name then return end
		local zones = {}
		for z in pairs(pickZones) do zones[#zones + 1] = z end
		table.sort(zones)
		local _, cls = UnitClass("player")
		local list = Prof().talentReminders
		list[#list + 1] = { zoneNames = zones, talentIndex = pickTalent, spellName = name, icon = texture,
			class = cls, showNotNeeded = false }
		wipe(pickZones)
		pickTalent = nil
		if ns.RebuildSettingsPage then ns.RebuildSettingsPage() end
	end)
	p:Slider("Y Offset", "Distance of the talent reminders below the AuraBuff Reminders row.", -300, 300, 1,
		function() return Prof().talentReminderYOffset or -50 end,
		function(v) Prof().talentReminderYOffset = v end)

	p:Section("ACTIVE REMINDERS")
	local list = Prof().talentReminders
	if #list == 0 then
		p:Paragraph("No talent reminders configured")
		return
	end
	for i, r in ipairs(list) do
		local zones = table.concat(r.zoneNames or {}, ", ")
		local label = (r.icon and ("|T" .. tostring(r.icon) .. ":16:16:0:0:64:64:5:59:5:59|t ") or "") .. (r.spellName or "Unknown")
		if r.class then label = label .. " " .. ClassLabel("(" .. r.class:sub(1, 1) .. r.class:sub(2):lower() .. ")", r.class) end
		p:Toggle(label, "Zones: " .. zones .. "\n\nShow 'Not Needed' Reminder: also show the talent outside these zones while it is picked.",
			function() return r.showNotNeeded == true end,
			function(v) r.showNotNeeded = v end)
		p:Button("", "Remove this reminder.", "Remove", function()
			table.remove(list, i)
			if ns.RebuildSettingsPage then ns.RebuildSettingsPage() end
		end)
	end
end

ns.RegisterSettingsModule({
	key = "auraBuff",
	name = "AuraBuff Reminders",
	group = "QoL Addons",
	tabs = {
		{ key = "reminders", name = "Auras, Buffs & Consumables",
			description = "AuraBuff Reminders: Raid Buffs, Auras, and Consumables. Left-click a reminder to cast or use it, middle-click hides it until the next loading screen, right-click cycles the demon of a Warlock pet reminder.",
			build = BuildReminders },
		{ key = "talents", name = "Talent Reminders",
			description = "Reminds you to pick a talent in the zones you choose.",
			build = BuildTalents,
			pageKey = function() return #Prof().talentReminders .. ":" .. tostring(pickTalent) end },
	},
	reset = function() EABR.Reset() end,
	resetTip = "Set all AuraBuff Reminders settings back to default.",
	onLeave = function()
		EABR._rcwPreview = nil
		EABR.RCWHide()
	end,
})
