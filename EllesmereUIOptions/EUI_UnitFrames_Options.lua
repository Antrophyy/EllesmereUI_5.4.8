-- Settings pages of Unit Frames (EllesmereUI Core Addons > Unit Frames):
-- Main Frames (player / target / focus), Boss Frames, Mini Frames
-- (target of target / focus target / pet). Same sections, labels and keys as
-- EllesmereUI; retail-only rows are left out.
-- Part of EllesmereUIOptions (load on demand); skipped when
-- EllesmereUIUnitFrames is not loaded.

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUIUnitFrames") then
	return
end
local UF = ns.UF

local floor = math.floor

local sel = { main = "player", mini = "targettarget" }
-- Unlock Mode cog "Element Options" picks the unit first (retail setters).
ns._setUnitFrameUnit = function(unit) sel.main = unit end
ns._setMiniUnit = function(unit) sel.mini = unit end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function DB()
	return UF.db
end

local function S(unit)
	return UF.db[unit]
end

-- Value lists are arrays of { value, label }.
local function Items(list)
	local items = {}
	for i = 1, #list do
		items[i] = { value = list[i][1], name = list[i][2] }
	end
	return items
end

local function LabelOf(list, value)
	for i = 1, #list do
		if list[i][1] == value then
			return list[i][2]
		end
	end
	return tostring(value or "")
end

local function Get(unit, key, default)
	return function()
		local v = UF.db[unit][key]
		if v == nil then
			return default
		end
		return v
	end
end

local function Set(unit, key, after)
	return function(v)
		UF.db[unit][key] = v
		if after then
			after(v)
		end
	end
end

local function Toggle(p, label, desc, unit, key, default, isDisabled, after)
	p:Toggle(label, desc, Get(unit, key, default), Set(unit, key, after), isDisabled)
end

local function Slider(p, label, desc, minV, maxV, step, unit, key, default, isDisabled)
	p:Slider(label, desc, minV, maxV, step, Get(unit, key, default), Set(unit, key), isDisabled)
end

local function Dropdown(p, label, desc, list, unit, key, default, isDisabled, after, options)
	local get = Get(unit, key, default)
	p:Dropdown(label, desc, function() return Items(list) end, get,
		function() return LabelOf(list, get()) end, Set(unit, key, after), options, isDisabled)
end

-- Cog rows ---------------------------------------------------------------
local function CT(label, unit, key, default, disabled, tip, after)
	return { type = "toggle", label = label, tip = tip, get = Get(unit, key, default), set = Set(unit, key, after), disabled = disabled }
end

local function CS(label, minV, maxV, step, unit, key, default, disabled, tip)
	return { type = "slider", label = label, tip = tip, min = minV, max = maxV, step = step,
		get = Get(unit, key, default), set = Set(unit, key), disabled = disabled }
end

local function CD(label, list, unit, key, default, disabled, tip, after)
	return { type = "dropdown", label = label, tip = tip, items = function() return Items(list) end,
		get = Get(unit, key, default), set = Set(unit, key, after), disabled = disabled }
end

-- Colors stored as { r, g, b [, a] } tables ---------------------------------
local function ColorGet(unit, key, dr, dg, db, da)
	return function()
		local c = UF.db[unit][key]
		if type(c) ~= "table" then
			return dr, dg, db, da or 1
		end
		return c.r or dr, c.g or dg, c.b or db, c.a or da or 1
	end
end

local function ColorSet(unit, key, alpha)
	return function(r, g, b, a)
		local c = UF.db[unit][key]
		if type(c) ~= "table" then
			c = {}
			UF.db[unit][key] = c
		end
		c.r, c.g, c.b = r, g, b
		if alpha and a then
			c.a = a
		end
	end
end

-- Inline color swatch on the last cell for a { r, g, b } key.
local function Swatch(p, tip, unit, key, defaults, opts)
	defaults = defaults or { 1, 1, 1 }
	opts = opts or {}
	p:Swatch(tip, ColorGet(unit, key, defaults[1], defaults[2], defaults[3], defaults[4]), ColorSet(unit, key, opts.alpha), opts)
end

-- Swatch for three number keys (prefix .. "R" / "G" / "B").
local function SwatchRGB(p, tip, unit, prefix, opts)
	p:Swatch(tip,
		function()
			local s = UF.db[unit]
			return s[prefix .. "R"] or 1, s[prefix .. "G"] or 1, s[prefix .. "B"] or 1
		end,
		function(r, g, b)
			local s = UF.db[unit]
			s[prefix .. "R"], s[prefix .. "G"], s[prefix .. "B"] = r, g, b
		end, opts)
end

-- Read-only swatch showing a fixed color function; clicking selects a mode.
local function ModeSwatch(p, tip, colorFn, isActive, select, disabled)
	p:Swatch(tip, colorFn, function() end, {
		readonly = true, active = isActive, disabled = disabled,
		onClick = function() select() return true end,
	})
end

-- Apply to All ------------------------------------------------------------
local function Equal(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for k, v in pairs(a) do
		if not Equal(v, b[k]) then
			return false
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function Sync(p, tip, unit, keys, group)
	group = group or UF.MAIN_UNITS
	p:Sync(tip,
		function()
			local src = UF.db[unit]
			for _, other in ipairs(group) do
				if other ~= unit then
					local dst = UF.db[other]
					for _, key in ipairs(keys) do
						dst[key] = UF.DeepCopy(src[key])
					end
				end
			end
		end,
		function()
			local src = UF.db[unit]
			for _, other in ipairs(group) do
				for _, key in ipairs(keys) do
					if not Equal(src[key], UF.db[other][key]) then
						return false
					end
				end
			end
			return true
		end)
end

local function Reload()
	StaticPopup_Show("EUI_UF_RELOAD")
end

StaticPopupDialogs["EUI_UF_RELOAD"] = {
	text = "This change needs a UI reload to take effect.",
	button1 = "Reload Now",
	button2 = "Later",
	OnAccept = function() ReloadUI() end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}

StaticPopupDialogs["EUI_UF_APPLY_ALL"] = {
	text = "Copy all shared settings from %s to %s?\n\nThis overwrites this frame's current settings. Frame position, visibility, and enable state are not changed.",
	button1 = "Apply",
	button2 = "Cancel",
	OnAccept = function(self, data)
		local src, dst = UF.db[data.from], UF.db[data.to]
		local skip = { barVisibility = true, visibilityMatch = true, visibilityModes = true }
		for key, value in pairs(src) do
			if not skip[key] and dst[key] ~= nil then
				dst[key] = UF.DeepCopy(value)
			end
		end
		UF.ReloadFrames()
		if ns.RefreshSettings then
			ns.RefreshSettings()
		end
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}

local function PlayerClassColor()
	return UF.PlayerClassColor()
end

local function PlayerPowerColor()
	return UF.PlayerPowerColor()
end

---------------------------------------------------------------------------
-- Value lists (EllesmereUI labels)
---------------------------------------------------------------------------
local HEALTH_TEXT = {
	{ "none", "None" }, { "name", "Name" }, { "nametotarget", "Name > Target" }, { "targetname", "Target" },
	{ "levelname", "Level | Name" }, { "namelevel", "Name | Level" }, { "level", "Level" },
	{ "perhp", "Health %" }, { "perhpnosign", "Health % (No Sign)" }, { "curhpshort", "Health #" },
	{ "perhpnum", "Health % | #" }, { "both", "Health # | %" }, { "bothdash", "Health # - %" },
	{ "perhpnumdash", "Health % - #" }, { "absorb", "Absorb Amount" }, { "absorbshort", "Absorb Short (230k)" },
	{ "healabsorb", "Heal Absorb Amount" }, { "healabsorbshort", "Heal Absorb Short (80k)" },
}
local HEALTH_TEXT_PLAYER = {}
for i = 1, #HEALTH_TEXT do
	HEALTH_TEXT_PLAYER[i] = HEALTH_TEXT[i]
end
HEALTH_TEXT_PLAYER[#HEALTH_TEXT_PLAYER + 1] = { "group", "Group Number" }
local HEALTH_TEXT_MINI = {
	{ "none", "None" }, { "name", "Name" }, { "levelname", "Level | Name" }, { "namelevel", "Name | Level" },
	{ "level", "Level" }, { "perhp", "Health %" }, { "perhpnosign", "Health % (No Sign)" },
	{ "curhpshort", "Health #" }, { "perhpnum", "Health % | #" }, { "both", "Health # | %" },
}
local BTB_TEXT = {
	{ "none", "None" }, { "name", "Name" }, { "perhp", "Health %" }, { "perhpnosign", "Health % (No Sign)" },
	{ "curhpshort", "Health #" }, { "perhpnum", "Health % | #" }, { "both", "Health # | %" },
	{ "perpp", "Power %" }, { "curpp", "Power Value" }, { "curhp_curpp", "Health | Power Value" },
	{ "perhp_perpp", "Health | Power %" },
}
local ALIGN = { { "left", "Left" }, { "right", "Right" }, { "center", "Center" } }
local STRATA = { { "BACKGROUND", "Background" }, { "LOW", "Low" }, { "MEDIUM", "Medium" }, { "HIGH", "High" }, { "DIALOG", "Dialog" } }
local PORTRAIT_MODE = { { "none", "None" }, { "attached", "Attached" }, { "detached", "Detached" } }
local PORTRAIT_SIDE = { { "left", "Left" }, { "right", "Right" }, { "top", "Top" } }
local PORTRAIT_NONPLAYER = { { "2d", "2D Portrait" }, { "none", "Nothing" }, { "3d", "3D Portrait" } }
local PORTRAIT_SHAPE = { { "portrait", "Portrait" }, { "square", "Square" }, { "circle", "Circle" } }
local POWER_POS = {
	{ "below", "Below Health Bar" }, { "above", "Above Health Bar" }, { "detached_bottom", "Detached Bottom" },
	{ "detached_top", "Detached Top" }, { "none", "None" },
}
local POWER_FMT = { { "none", "None" }, { "smart", "Smart Text" }, { "curpp", "Power Value" }, { "perpp", "Power %" }, { "both", "Value | %" } }
local POWER_TEXT_POS = { { "none", "None" }, { "left", "Left" }, { "right", "Right" }, { "center", "Center" } }
local GRADIENT_DIR = { { "HORIZONTAL", "Horizontal" }, { "VERTICAL", "Vertical" } }
local DYNAMIC_COLOR = { { "none", "Off" }, { "classic", "Classic" }, { "customDynamic", "Custom Colors" }, { "classReactive", "Class Reactive" } }
local TEXT_SIDE = { { "none", "None" }, { "left", "Left" }, { "right", "Right" }, { "center", "Center" } }
local DURATION_SIDE = { { "none", "None" }, { "right", "Right" }, { "left", "Left" } }
local BTB_POS = { { "top", "Top" }, { "bottom", "Bottom" }, { "detached_top", "Detached Top" }, { "detached_bottom", "Detached Bottom" } }
local CLASS_ICON = { { "none", "None" } }
for _, key in ipairs(UF.CLASS_STYLE_ORDER) do
	CLASS_ICON[#CLASS_ICON + 1] = { key, UF.CLASS_STYLE_NAMES[key] }
end
local CP_STYLE = { { "none", "None" }, { "modern", "Modern" }, { "blizzard", "Blizzard" } }
local CP_POS = { { "top", "Top" }, { "bottom", "Bottom" }, { "above", "Above Health Bar" } }
local AURA_ANCHOR = {
	{ "none", "None" }, { "topleft", "Top Left" }, { "topright", "Top Right" }, { "bottomleft", "Bottom Left" },
	{ "bottomright", "Bottom Right" }, { "left", "Left" }, { "right", "Right" },
}
local AURA_GROWTH = { { "auto", "Auto" }, { "up", "Up" }, { "down", "Down" }, { "left", "Left" }, { "right", "Right" } }
local STACK_POS = { { "bottomright", "Bottom Right" }, { "bottomleft", "Bottom Left" }, { "topright", "Top Right" }, { "topleft", "Top Left" }, { "center", "Center" } }
local DEBUFF_MODE = {
	{ "all", "Show All" }, { "tracked", "Only Tracked Auras" }, { "own", "Own Only" }, { "important", "Important Only" },
	{ "importantOwn", "Important and Own" }, { "importantOrOwn", "Important or Own" },
}

-- Tracked Auras popup (retail ns.UFOpt_ShowTrackedAuras): debuffInclude /
-- debuffExclude on the unit's settings; boss includes default to your own
-- casts (any-caster opt-outs in debuffIncludeAnyCaster), target / focus
-- includes default to any caster (MINE opt-ins in debuffIncludeMine).
local TRACKED_UNITS = { { key = "target", label = "Target" }, { key = "focus", label = "Focus" }, { key = "boss", label = "Boss" } }
local function TrackedList(unit, field)
	local s = S(unit)
	s[field] = s[field] or {}
	return s[field]
end

local function ShowTrackedAuras(unit)
	local choices = {}
	for _, u in ipairs(TRACKED_UNITS) do
		if u.key ~= unit then
			choices[#choices + 1] = u
		end
	end
	local Changed = ns.ApplySettingsChange
	local function Clone(t)
		if not t then
			return nil
		end
		local c = {}
		for k, v in pairs(t) do
			c[k] = v
		end
		return c
	end
	ns.ShowTrackedAurasPopup({
		eyebrow = "UNIT FRAME AURA FILTERS",
		title = (UF.UNIT_LABELS[unit] or "Boss") .. " Tracked Auras",
		subtitle = "Included debuffs show in addition to your Debuff Filter selection (unless it is set to Only Tracked Auras).",
		includeGet = function() return TrackedList(unit, "debuffInclude") end,
		excludeGet = function() return TrackedList(unit, "debuffExclude") end,
		includeMine = unit == "boss" and { anyGet = function() return TrackedList(unit, "debuffIncludeAnyCaster") end }
			or { mineGet = function() return TrackedList(unit, "debuffIncludeMine") end },
		includePrompt = "Enter the spell ID to always show on this frame.",
		excludePrompt = "Enter the spell ID to exclude from this frame.",
		onChanged = Changed,
		copyFrom = {
			label = "Copy Included/Excluded Spells From:",
			choices = choices,
			apply = function(srcKey)
				local src, dst = S(srcKey), S(unit)
				if not (src and dst) then
					return
				end
				dst.debuffInclude = Clone(src.debuffInclude)
				dst.debuffExclude = Clone(src.debuffExclude)
				local srcBoss, dstBoss = srcKey == "boss", unit == "boss"
				if srcBoss == dstBoss then
					dst.debuffIncludeAnyCaster = Clone(src.debuffIncludeAnyCaster)
					dst.debuffIncludeMine = Clone(src.debuffIncludeMine)
				else
					-- Opposite polarity per unit kind: invert so every entry keeps its scope.
					local srcMap = srcBoss and src.debuffIncludeAnyCaster or src.debuffIncludeMine
					local inv = {}
					for id in pairs(src.debuffInclude or {}) do
						if not (srcMap and srcMap[id]) then
							inv[id] = true
						end
					end
					if dstBoss then
						dst.debuffIncludeAnyCaster, dst.debuffIncludeMine = inv, nil
					else
						dst.debuffIncludeMine, dst.debuffIncludeAnyCaster = inv, nil
					end
				end
				Changed()
			end,
		},
	})
end

-- Debuff Filter dropdown items: "Edit Tracked Auras" pinned action above the modes.
local function DebuffModeItems(unit)
	local items = { { name = "Edit Tracked Auras", action = function() ShowTrackedAuras(unit) end }, { separator = true } }
	for _, it in ipairs(Items(DEBUFF_MODE)) do
		items[#items + 1] = it
	end
	return items
end

-- Hide Exhaustion (retail HideExhaustionRow): nil = on.
local function HideExhaustionRow(unit)
	return { type = "toggle", label = "Hide Exhaustion",
		tip = "Hides Sated, Exhaustion, Temporal Displacement and the other Bloodlust lockout debuffs.",
		get = function() return S(unit).debuffHideExhaustion ~= false end,
		set = function(v) S(unit).debuffHideExhaustion = (not v) and false or nil end }
end
local DISPEL_OVERLAY = { { "none", "None" }, { "fill", "Fill Overlay" }, { "full", "Full Overlay" }, { "gradient", "Gradient Overlay" }, { "gradient_sharp", "Gradient Sharp" } }
local ABSORB_PLACEMENT = { { "overlay", "Overlay" }, { "right", "From Right Edge" }, { "left", "From Left Edge" } }
local OVERSHIELD = { { "never", "Never" }, { "always", "Always" }, { "fromleft", "From Left" } }
local ABSORB_BAR = {
	{ "none", "None" }, { "aboveRight", "Above Frame Right" }, { "aboveLeft", "Above Frame Left" }, { "topRight", "Top Right" },
	{ "topLeft", "Top Left" }, { "bottomRight", "Bottom Right" }, { "bottomLeft", "Bottom Left" },
}
local HEAL_ABSORB_BAR = {
	{ "none", "None" }, { "aboveAbsorb", "Above Absorb Bar" }, { "belowAbsorb", "Below Absorb Bar" },
	{ "aboveRight", "Above Frame Right" }, { "aboveLeft", "Above Frame Left" }, { "topRight", "Top Right" },
	{ "topLeft", "Top Left" }, { "bottomRight", "Bottom Right" }, { "bottomLeft", "Bottom Left" },
}
local COMBAT_STYLE = {
	{ "none", "None" }, { "standard", "Standard" }, { "class", "Class Theme" }, { "combat0", "Arcade" },
	{ "combat1", "Dungeoneer" }, { "combat2", "Classic" }, { "combat3", "Cross" }, { "combat4", "Circle" }, { "combat5", "Square" },
}
local INDICATOR_POS = { { "topleft", "Top Left" }, { "topright", "Top Right" }, { "bottomleft", "Bottom Left" }, { "bottomright", "Bottom Right" }, { "portrait", "Portrait" } }
local COMBAT_POS = {
	{ "topleft", "Top Left" }, { "topright", "Top Right" }, { "healthbar", "Center" }, { "bottomleft", "Bottom Left" },
	{ "bottomright", "Bottom Right" }, { "textbar", "Text Bar" }, { "portrait", "Portrait" },
}
local LEADER_STYLE = { { "blizzard", "Blizzard" }, { "pixels", "Pixels" } }
local FACTION_STYLE = { { "classic", "Classic Banner" }, { "banner", "Banner Icon" }, { "honoricon", "Honor Icon" }, { "friends", "Friends Crest" } }
local FACTION_PVP = { { "dim", "Dim Unflagged" }, { "only", "Flagged Only" }, { "ignore", "Ignore" } }
local THREAT_POS = { { "RIGHT", "Inside Right" }, { "LEFT", "Inside Left" }, { "CENTER", "Inside Center" }, { "OUTRIGHT", "Outside Right" }, { "OUTLEFT", "Outside Left" } }
local SIMPLE_DISPLAY = { { "none", "None" }, { "left", "Left" }, { "right", "Right" } }

---------------------------------------------------------------------------
-- Shared rows
---------------------------------------------------------------------------
local function NotNone(unit, key)
	return function()
		local v = UF.db[unit][key]
		return v == nil or v == "none"
	end
end

local function Dark()
	return UF.db.darkTheme
end

-- Visibility checklist (Never / Always / Mouseover, match mode, Show / Hide lanes).
local function VisibilityRow(p, unit)
	local function Items_()
		local items = {
			{ value = "state:never", name = "Never" }, { value = "state:always", name = "Always" },
			{ value = "state:mouseover", name = "Mouseover" },
			{ value = "match:all", name = "Match All Conditions" }, { value = "match:any", name = "Match Any Condition" },
		}
		for _, axis in ipairs(UF.VIS_AXES) do
			items[#items + 1] = { value = "show:" .. axis.key, name = "Show: " .. axis.label }
			items[#items + 1] = { value = "hide:" .. axis.key, name = "Hide: " .. axis.label }
		end
		return items
	end
	local function Axis(key)
		for _, axis in ipairs(UF.VIS_AXES) do
			if axis.key == key then
				return axis
			end
		end
	end
	local function IsChecked(value)
		local s = S(unit)
		local kind, key = value:match("^(%a+):(.+)$")
		if kind == "state" then
			return (s.barVisibility or "always") == key
		elseif kind == "match" then
			return (s.visibilityMatch or "all") == key
		end
		local axis = Axis(key)
		return UF.VisFlag(s, kind == "show" and axis.show or axis.hide)
	end
	local function Toggle_(value)
		local s = S(unit)
		local kind, key = value:match("^(%a+):(.+)$")
		if kind == "state" then
			s.barVisibility = key
			return
		elseif kind == "match" then
			s.visibilityMatch = key
			return
		end
		local axis = Axis(key)
		local laneKey = kind == "show" and axis.show or axis.hide
		local otherKey = kind == "show" and axis.hide or axis.show
		local on = not UF.VisFlag(s, laneKey)
		UF.SetVisFlag(s, laneKey, on)
		if on then
			UF.SetVisFlag(s, otherKey, false)
		end
	end
	local function Summary()
		local s = S(unit)
		local vis = s.barVisibility or "always"
		local text = vis == "never" and "Never" or (vis == "mouseover" and "Mouseover" or "Always")
		local n = 0
		for _, axis in ipairs(UF.VIS_AXES) do
			if UF.VisFlag(s, axis.show) or UF.VisFlag(s, axis.hide) then
				n = n + 1
			end
		end
		if n > 0 and vis ~= "never" then
			text = text .. " + " .. n .. (n == 1 and " condition" or " conditions")
		end
		return text
	end
	p:MultiSelect("Visibility", "When this frame is shown. Never / Always / Mouseover is the base state; the Show conditions must match (all or any), a Hide condition always hides. Hidden frames fade out but stay clickable while in combat (5.4.8 secure frames).",
		Items_, IsChecked, Toggle_, Summary)
	local keys = { "barVisibility", "visibilityModes", "visibilityMatch", "showInRaid", "showInParty", "showSolo" }
	for _, axis in ipairs(UF.VIS_AXES) do
		if axis.show:match("^vis") then
			keys[#keys + 1] = axis.show
			keys[#keys + 1] = axis.hide
		end
	end
	local group = UF.MAIN_UNITS
	if unit == "targettarget" or unit == "focustarget" or unit == "pet" then
		group = UF.MINI_UNITS
	end
	Sync(p, "Apply Visibility to all Frames", unit, keys, group)
	p:Cog("Frame Source & Visibility", {
		{ type = "dropdown", label = "Frame Source", tip = "EllesmereUI frame, or keep Blizzard's default frame. Needs a UI reload.",
			items = function() return Items({ { "eui", "EllesmereUI" }, { "blizzard", "Blizzard Default" } }) end,
			get = function() return UF.FrameSource(unit) end,
			set = function(v) UF.db.frameSource[unit] = v ~= "eui" and v or nil Reload() end },
		CT("Show When Health Missing", unit, "showWhenHealthMissing", false, nil,
			"Shows the frame while this unit is below full health; while enabled, a frame hidden by its visibility setting can still be clicked."),
		CT("Fade Out of Combat", unit, "oocFadeEnabled", false, nil, "Fades the entire frame (portrait, health and power bars, text) while out of combat."),
		{ type = "slider", label = "Out of Combat Alpha", min = 0, max = 100, step = 1,
			get = function() return floor((S(unit).oocAlpha or 0.5) * 100 + 0.5) end,
			set = function(v) S(unit).oocAlpha = v / 100 end,
			disabled = function() return not S(unit).oocFadeEnabled end },
	})
end

local function BarTextureRow(p, unit, withInherit, sync)
	p:Dropdown("Bar Texture", "Texture of the health, power and cast bars. Textures from LibSharedMedia are listed too.",
		function() return UF.BarTextureItems(withInherit) end,
		function() return S(unit).healthBarTexture or (withInherit and "inherit" or UF.db.healthBarTexture or "none") end,
		function()
			local key = S(unit).healthBarTexture or (withInherit and "inherit" or UF.db.healthBarTexture or "none")
			if key == "inherit" then
				return "Inherit (Main Frames)"
			end
			return UF.BarTextureLabel(key)
		end,
		function(v) S(unit).healthBarTexture = (v ~= "inherit") and v or nil end,
		{ texturePreview = true, previewPath = function(v)
			if v == "inherit" then
				return UF.BarTexturePath(UF.Donor(unit).healthBarTexture or UF.db.healthBarTexture)
			end
			return UF.BarTexturePath(v)
		end })
	p:Cog("Texture Settings", {
		{ type = "toggle", label = "Textured Background",
		  tip = withInherit and "The power bar background uses the bar texture, tinted by its background color. While Bar Texture is Inherit, this follows the main frame."
			or "The power bar background uses the bar texture, tinted by its background color (while the power bar's opacity is 100). The health background already draws the bar texture.",
		  get = function() return S(unit).textureBg == true end,
		  set = function(v) S(unit).textureBg = v end,
		  disabled = withInherit and function() local k = S(unit).healthBarTexture; return k == nil or k == "inherit" end or nil },
		{ type = "toggle", label = "Cast Bar Textured Background",
		  tip = "Every unit frame cast bar background uses the bar texture, tinted by the Cast Background color (while Fill Opacity is 100).",
		  get = function() return UF.db.castTextureBg == true end,
		  set = function(v) UF.db.castTextureBg = v end },
	})
	if sync then
		Sync(p, "Apply Bar Texture to all Frames", unit, { "healthBarTexture", "textureBg" })
	end
end

-- Name Format cog row (retail ns.UF_NameFormatRows): first word, last word
-- or the whole name (nil). Only for contents that show a name.
local NAME_FORMAT = { { "first", "First Name" }, { "last", "Last Name" }, { "full", "First and Last" } }
local HAS_NAME = { name = true, levelname = true, namelevel = true, nametotarget = true, targetname = true }
local function NameFormatRow(unit, prefix)
	return { type = "dropdown", label = "Name Format", tip = "Shorten names to their first or last word.",
		items = function() return Items(NAME_FORMAT) end,
		get = function() return S(unit)[prefix .. "NameFormat"] or "full" end,
		set = function(v) S(unit)[prefix .. "NameFormat"] = (v ~= "full") and v or nil end,
		disabled = function() return not HAS_NAME[S(unit)[prefix .. "Content"] or "none"] end }
end

-- One health bar text slot: dropdown + swatches + cog (+ sync).
local function TextSlot(p, unit, slot, label, list, sync)
	local prefix = slot .. "Text"
	local contentKey = prefix .. "Content"
	Dropdown(p, label, "What this text shows.", list, unit, contentKey, "none", nil, function(v)
		-- Left / Right / Center never show the same thing twice.
		if v ~= "none" and slot ~= "extra" then
			local s = S(unit)
			for _, other in ipairs({ "left", "right", "center" }) do
				if other ~= slot and s[other .. "TextContent"] == v then
					s[other .. "TextContent"] = "none"
				end
			end
		end
	end)
	local none = NotNone(unit, contentKey)
	if sync then
		Sync(p, "Apply " .. label .. " to all Frames", unit,
			{ contentKey, prefix .. "ClassColor", prefix .. "ColorR", prefix .. "ColorG", prefix .. "ColorB",
				prefix .. "Size", prefix .. "X", prefix .. "Y", prefix .. "WidthPct", slot == "extra" and "extraTextAlign" or nil })
	end
	SwatchRGB(p, "Custom Colored", unit, prefix .. "Color", {
		active = function() return not S(unit)[prefix .. "ClassColor"] end,
		disabled = none,
		onClick = function()
			if S(unit)[prefix .. "ClassColor"] then
				S(unit)[prefix .. "ClassColor"] = false
				return true
			end
		end,
	})
	ModeSwatch(p, "Class Colored", PlayerClassColor, function() return S(unit)[prefix .. "ClassColor"] end,
		function() S(unit)[prefix .. "ClassColor"] = true end, none)
	local rows = { NameFormatRow(unit, prefix) }
	if slot == "extra" then
		rows[#rows + 1] = CD("Alignment", ALIGN, unit, "extraTextAlign", "left")
	end
	rows[#rows + 1] = { type = "slider", label = "Size", min = 8, max = 100, step = 1,
		get = function() return S(unit)[prefix .. "Size"] or S(unit).textSize or 12 end,
		set = function(v) S(unit)[prefix .. "Size"] = v end }
	rows[#rows + 1] = CS("X Offset", -150, 150, 1, unit, prefix .. "X", 0)
	rows[#rows + 1] = CS("Y Offset", -150, 150, 1, unit, prefix .. "Y", 0)
	rows[#rows + 1] = CS("Width %", 20, 200, 5, unit, prefix .. "WidthPct", 100)
	rows[#rows + 1] = { type = "color", label = "Indicator Color", tip = "Color of the separator (Name > Target) or prefix (Target).",
		get = ColorGet(unit, prefix .. "TargetSepColor", 1, 1, 1), set = ColorSet(unit, prefix .. "TargetSepColor"),
		disabled = function() local c = S(unit)[contentKey] return c ~= "nametotarget" and c ~= "targetname" end }
	rows[#rows + 1] = CT("Indicator Class Colored", unit, prefix .. "TargetSepClassColor", false,
		function() local c = S(unit)[contentKey] return c ~= "nametotarget" and c ~= "targetname" end)
	-- Separator (Name > Target) and Prefix (Target) text (retail type="input" rows).
	rows[#rows + 1] = { type = "input", label = "Separator", inputWidth = 60, maxLetters = 6,
		tip = "Text between the name and the target's name.",
		get = function() return S(unit)[prefix .. "TargetSep"] or ">" end,
		set = function(v)
			v = tostring(v or ""):gsub("|", ""):gsub("^%s+", ""):gsub("%s+$", "")
			S(unit)[prefix .. "TargetSep"] = (v ~= "" and v ~= ">") and v or nil
		end,
		disabled = function() return S(unit)[contentKey] ~= "nametotarget" end }
	rows[#rows + 1] = { type = "input", label = "Prefix", inputWidth = 60, maxLetters = 6,
		tip = "Text before the target's name. Empty shows no prefix.",
		get = function() local v = S(unit)[prefix .. "TargetPrefix"] if v == nil then v = "T:" end return v end,
		set = function(v)
			v = tostring(v or ""):gsub("|", ""):gsub("^%s+", ""):gsub("%s+$", "")
			S(unit)[prefix .. "TargetPrefix"] = (v ~= "T:") and v or nil
		end,
		disabled = function() return S(unit)[contentKey] ~= "targetname" end }
	p:Cog(label .. " Settings", rows, { disabled = none, disabledTip = "This option requires a text selection other than none." })
end

local function FillColorRow(p, unit, sync)
	p:Label("Fill Color", "Color of the health fill: your own color or the unit's class (players) / reaction (NPCs) color.", Dark)
	local function classOn() return S(unit).healthClassColored ~= false end
	local function dynamicOn() return (S(unit).healthColorMode or "none") ~= "none" end
	if sync then
		Sync(p, "Apply Bar Color to all Frames", unit, { "healthClassColored", "customFillColor", "gradientEnabled", "gradientDir",
			"gradientColor", "healthColorMode", "dynamicColor100", "dynamicColor50", "dynamicColor0" })
		p:Cog("Fill Color Settings", {
			CD("Dynamic Color", DYNAMIC_COLOR, unit, "healthColorMode", "none", nil,
				"Color the bar by health left. Classic = green, yellow, red. Custom Colors = a blend of the 3 stop colors (100 / 50 / 0 %). Class Reactive = class color at full, bleeding into the 50 % / 0 % colors."),
			CT("Enable Gradient", unit, "gradientEnabled", false),
			CD("Gradient Direction", GRADIENT_DIR, unit, "gradientDir", "HORIZONTAL"),
			{ type = "color", label = "Color at 100%", get = ColorGet(unit, "dynamicColor100", 0, 1, 0), set = ColorSet(unit, "dynamicColor100"),
				disabled = function() return S(unit).healthColorMode ~= "customDynamic" end },
			{ type = "color", label = "Color at 50%", get = ColorGet(unit, "dynamicColor50", 0xEC / 255, 0xEC / 255, 0x32 / 255), set = ColorSet(unit, "dynamicColor50"),
				disabled = function() local m = S(unit).healthColorMode return m ~= "customDynamic" and m ~= "classReactive" end },
			{ type = "color", label = "Color at 0%", get = ColorGet(unit, "dynamicColor0", 0xE3 / 255, 0x30 / 255, 0x30 / 255), set = ColorSet(unit, "dynamicColor0"),
				disabled = function() local m = S(unit).healthColorMode return m ~= "customDynamic" and m ~= "classReactive" end },
		})
		Swatch(p, "Gradient End Color", unit, "gradientColor", { 0.2, 0.2, 0.8 }, { disabled = function() return not S(unit).gradientEnabled end })
	end
	Swatch(p, "Custom Colored Fill", unit, "customFillColor", { 37 / 255, 193 / 255, 29 / 255 }, {
		active = function() return not classOn() end, disabled = dynamicOn,
		onClick = function()
			if classOn() then
				S(unit).healthClassColored = false
				return true
			end
		end,
	})
	ModeSwatch(p, "Class Colored Fill", PlayerClassColor, classOn, function() S(unit).healthClassColored = true end, dynamicOn)
end

local function BackgroundRow(p, unit, sync)
	p:Slider("Bar Background", "Opacity of the background behind the missing health.", 0, 100, 1,
		Get(unit, "customBgAlpha", 100), Set(unit, "customBgAlpha"), Dark)
	if sync then
		Sync(p, "Apply Bar Background to all Frames", unit, { "customBgColor", "customBgAlpha", "bgClassColored" })
	end
	Swatch(p, "Custom Background Color", unit, "customBgColor", { 0.067, 0.067, 0.067 }, {
		active = function() return not S(unit).bgClassColored end,
		onClick = function()
			if S(unit).bgClassColored then
				S(unit).bgClassColored = false
				return true
			end
		end,
	})
	ModeSwatch(p, "Class Colored Background", PlayerClassColor, function() return S(unit).bgClassColored end,
		function() S(unit).bgClassColored = true end)
end

-- Power bar rows (main frames, pet, boss).
local function PowerRows(p, unit, full, sync)
	p:Slider("Power Bar Height", "Height of the power bar. 0 hides it.", 0, 100, 1, Get(unit, "powerHeight", 6), Set(unit, "powerHeight"))
	if sync then
		Sync(p, "Apply Power Bar Height to all Frames", unit, { "powerHeight" })
	end
	p:Cog("Power Bar Fill", { CT("Reverse Fill", unit, "powerReverseFill", false) })
	if full then
		Dropdown(p, "Bar Position", "Where the power bar is. Detached bars can be moved with the cog offsets.", POWER_POS, unit, "powerPosition", "below")
		if sync then
			Sync(p, "Apply Bar Position to all Frames", unit, { "powerPosition" })
		end
		local function notDetached()
			local v = S(unit).powerPosition
			return v ~= "detached_top" and v ~= "detached_bottom"
		end
		p:Cog("Position Settings", {
			CS("Width", 0, 400, 1, unit, "powerWidth", 0, nil, "0 = the frame width."),
			CS("X Offset", -200, 200, 1, unit, "powerX", 0),
			CS("Y Offset", -200, 200, 1, unit, "powerY", 0),
		}, { icon = "resize", disabled = notDetached, disabledTip = "This option requires a detached position to be active." })
	else
		p:Toggle("Above Health Bar", "Show the power bar above the health bar instead of below it.",
			function() return S(unit).powerPosition == "above" end,
			function(v) S(unit).powerPosition = v and "above" or "below" end)
	end

	Dropdown(p, "Power Text", "Format of the power text.", POWER_FMT, unit, "powerTextFormat", "perpp", nil, function(v)
		local s = S(unit)
		if v == "none" then
			s.powerPercentText = "none"
		elseif (s.powerPercentText or "none") == "none" then
			s.powerPercentText = "center"
		end
	end)
	if sync then
		Sync(p, "Apply Power Text Format to all Frames", unit, { "powerTextFormat", "powerPercentText", "powerShowPercent" })
	end
	p:Cog("Power Text", { CT("Show %", unit, "powerShowPercent", true) }, {
		disabled = function() local f = S(unit).powerTextFormat return f == "none" or f == "curpp" end,
		disabledTip = "This option is only available for formats that display a percentage." })
	Slider(p, "Fill Opacity", "Opacity of the power fill.", 0, 100, 1, unit, "powerBarOpacity", 100)
	if sync then
		Sync(p, "Apply Bar Opacity to all Frames", unit, { "powerBarOpacity" })
	end

	p:Label("Fill Color", "Power color (by power type) or your own color.")
	local function powerOn() return S(unit).powerPercentPowerColor ~= false end
	if sync then
		Sync(p, "Apply Bar Color to all Frames", unit, { "powerPercentPowerColor", "customPowerFillColor", "powerGradientEnabled", "powerGradientDir", "powerGradientColor" })
	end
	p:Cog("Gradient Settings", {
		CT("Enable Gradient", unit, "powerGradientEnabled", false),
		CD("Gradient Direction", GRADIENT_DIR, unit, "powerGradientDir", "HORIZONTAL"),
	})
	Swatch(p, "Gradient End Color", unit, "powerGradientColor", { 0.2, 0.2, 0.8 }, { disabled = function() return not S(unit).powerGradientEnabled end })
	Swatch(p, "Custom Colored Fill", unit, "customPowerFillColor", { 0, 0, 1 }, {
		active = function() return not powerOn() end,
		onClick = function()
			if powerOn() then
				S(unit).powerPercentPowerColor = false
				return true
			end
		end,
	})
	ModeSwatch(p, "Power Colored Fill", PlayerPowerColor, powerOn, function() S(unit).powerPercentPowerColor = true end)

	p:Slider("Bar Background", "Opacity of the power bar background.", 0, 100, 1, Get(unit, "customPowerBgAlpha", 100), Set(unit, "customPowerBgAlpha"))
	if sync then
		Sync(p, "Apply Bar Background to all Frames", unit, { "customPowerBgColor", "customPowerBgAlpha", "powerBgPowerColored" })
	end
	Swatch(p, "Custom Background Color", unit, "customPowerBgColor", { 0.067, 0.067, 0.067 }, {
		active = function() return not S(unit).powerBgPowerColored end,
		onClick = function()
			if S(unit).powerBgPowerColored then
				S(unit).powerBgPowerColored = false
				return true
			end
		end,
	})
	ModeSwatch(p, "Power Colored Background", function()
		local r, g, b = UF.PlayerPowerColor()
		return r * 0.25, g * 0.25, b * 0.25
	end, function() return S(unit).powerBgPowerColored end, function() S(unit).powerBgPowerColored = true end)

	Dropdown(p, "Text Position", "Where the power text is on the bar.", POWER_TEXT_POS, unit, "powerPercentText", "none")
	if sync then
		Sync(p, "Apply Power Text Position to all Frames", unit, { "powerPercentText", "powerPercentSize", "powerPercentX", "powerPercentY" })
	end
	p:Cog("Text Position", {
		CS("Size", 6, 100, 1, unit, "powerPercentSize", 9),
		CS("X Offset", -50, 50, 1, unit, "powerPercentX", 0),
		CS("Y Offset", -50, 50, 1, unit, "powerPercentY", 0),
	}, { icon = "resize", disabled = NotNone(unit, "powerPercentText"), disabledTip = "This option requires a text position other than none." })
	p:Label("Text Color", "Color of the power text.")
	local function textPower() return S(unit).powerPercentTextPowerColor end
	if sync then
		Sync(p, "Apply Text Color to all Frames", unit, { "powerPercentTextPowerColor", "powerTextColor" })
	end
	Swatch(p, "Custom Text Color", unit, "powerTextColor", { 1, 1, 1 }, {
		active = function() return not textPower() end,
		onClick = function()
			if textPower() then
				S(unit).powerPercentTextPowerColor = false
				return true
			end
		end,
	})
	ModeSwatch(p, "Power Colored Text", PlayerPowerColor, textPower, function() S(unit).powerPercentTextPowerColor = true end)

	p:Slider("Border Size", "Border of a detached power bar, in pixels.", 0, 8, 1, Get(unit, "powerBorderSize", 0), Set(unit, "powerBorderSize"),
		full and function() local v = S(unit).powerPosition return v ~= "detached_top" and v ~= "detached_bottom" end or nil)
	Swatch(p, "Border Color", unit, "powerBorderColor", { 0, 0, 0, 1 }, { alpha = true })
	if unit == "player" and ns.SpellCostPrediction then
		-- Spell Cost Prediction (retail SharedBars_Options.lua): mana bars only.
		Toggle(p, "Spell Cost Prediction", "While you cast, shows on the bar the mana the spell will cost.", unit, "powerCostPrediction", false)
		p:Swatch("Spell Cost Color", function() return ns.SpellCostPrediction.Color(S(unit)) end,
			function(r, g, b) S(unit).powerCostColor = { r = r, g = g, b = b } end,
			{ disabled = function() return S(unit).powerCostPrediction ~= true end })
	else
		p:Blank()
	end
end

-- Cast bar rows. kick = target / focus / boss colors and options.
local function CastRows(p, unit)
	local isPlayer = unit == "player"
	local kick = not isPlayer
	local enabledKey = isPlayer and "showPlayerCastbar" or "showCastbar"
	local function off()
		local v = S(unit)[enabledKey]
		if isPlayer then
			return not v
		end
		return v == false
	end
	if isPlayer then
		p:Paragraph("For the player frame this is a small cast bar below the frame. Blizzard's own cast bar stays as it is.")
	end
	p:Toggle("Show Cast Bar", "Show the cast bar of this frame.", Get(unit, enabledKey, not isPlayer), Set(unit, enabledKey))
	if unit ~= "boss" then
		Sync(p, isPlayer and "Apply Show Cast Bar and Fill Color to all Frames" or "Apply Show Cast Bar and Cast Color to Target and Focus", unit,
			{ "castbarFillColor", "castbarInterruptReadyColor", "castbarUninterruptibleColor" }, isPlayer and UF.MAIN_UNITS or { "target", "focus" })
	end
	local rows = {
		CT("Hide When Idle", unit, "castbarHideWhenInactive", true, nil, "Only show the cast bar while a cast is in progress; hide it the rest of the time."),
		CS("Fill Opacity", 0, 100, 1, unit, "castFillOpacity", 100, nil, "Opacity of the cast bar fill; below 100 the world shows through the fill instead of the background."),
		{ type = "toggle", label = "Raise Cast Bar Strata (All)", tip = "Lifts player, target, focus, and boss cast bars above other frames so they are never hidden behind them.",
			get = function() return UF.db.raiseCastbarStrata ~= false end, set = function(v) UF.db.raiseCastbarStrata = v end },
	}
	if kick then
		rows[#rows + 1] = CT("Show Kick Ready Mid-Cast Tick", unit, "castbarKickTickEnabled", true, nil,
			"Shows a small white tick mark on the cast bar at the point where the cast will be when your interrupt comes off cooldown.")
		rows[#rows + 1] = CT("Show Kick Ready Mid-Cast Bar", unit, "castbarInterruptMidCastEnabled", false, nil,
			"When your interrupt is on cooldown now but will be ready before the enemy cast finishes, color the part of the cast bar during which your interrupt will be available.")
	end
	if unit == "boss" then
		rows[#rows + 1] = CS("Offset X", -500, 500, 1, unit, "castbarOffsetX", 0)
		rows[#rows + 1] = CS("Offset Y", -200, 200, 1, unit, "castbarOffsetY", 0)
	end
	if isPlayer then
		rows[#rows + 1] = { type = "toggle", label = "Lock to Player Frame", tip = "Off: the cast bar is moved on its own in Unlock Mode.",
			get = function() return S(unit).lockCastbarToFrame ~= false end, set = function(v) S(unit).lockCastbarToFrame = v end }
	end
	rows[#rows + 1] = CT("Custom Border Style", unit, "castBorderCustom", false, nil, "Show the border size and color controls for the cast bar.")
	p:Cog("Cast Bar", rows, { disabled = off })
	if kick then
		Swatch(p, "Interrupt Ready Mid-Cast", unit, "castbarInterruptMidCastColor", { 0.318, 0.820, 0.357 },
			{ disabled = function() return off() or not S(unit).castbarInterruptMidCastEnabled end })
		Swatch(p, "Interrupt on CD", unit, "castbarInterruptReadyColor", { 0.92, 0.35, 0.20 }, { disabled = off })
		Swatch(p, "Uninterruptible Cast", unit, "castbarUninterruptibleColor", { 0.5, 0.5, 0.5 }, { disabled = off })
		Swatch(p, "Interruptible Cast", unit, "castbarFillColor", { 0.863, 0.820, 0.639 }, { disabled = off })
	else
		Swatch(p, "Fill Color", unit, "castbarFillColor", { 0.863, 0.820, 0.639 }, { disabled = off })
	end

	local heightKey = isPlayer and "playerCastbarHeight" or "castbarHeight"
	p:Slider("Height", "Height of the cast bar.", 1, 40, 1, Get(unit, heightKey, 14), Set(unit, heightKey), off)
	if unit ~= "boss" then
		p:Sync("Apply Cast Bar Height to all Frames", function()
			local v = S(unit)[heightKey] or 14
			S("player").playerCastbarHeight = v
			S("target").castbarHeight = v
			S("focus").castbarHeight = v
		end, function()
			local v = S(unit)[heightKey] or 14
			return (S("player").playerCastbarHeight or 14) == v and (S("target").castbarHeight or 14) == v and (S("focus").castbarHeight or 14) == v
		end)
	end

	local iconKey = isPlayer and "showPlayerCastIcon" or "showCastIcon"
	local inWidthKey = isPlayer and "playerCastbarIconInWidth" or "castbarIconInWidth"
	local rightKey = isPlayer and "playerCastbarIconRight" or "castbarIconRight"
	local portraitKey = isPlayer and "playerCastbarIconOnPortrait" or "castbarIconOnPortrait"
	local oxKey = isPlayer and "playerCastIconOffsetX" or "castIconOffsetX"
	local oyKey = isPlayer and "playerCastIconOffsetY" or "castIconOffsetY"
	p:Toggle("Show Icon", "Show the spell icon.", Get(unit, iconKey, true), Set(unit, iconKey), off)
	local iconRows = {
		CT("Make Icon Part of the Bar", unit, inWidthKey, true, nil,
			"The width of the cast bar includes the icon, rather than placing it to the left of the cast bar's width."),
		CT("Show Icon on Right", unit, rightKey, false, nil, "Place the cast icon on the right side of the bar instead of the left."),
		CT("Icon Border", unit, "castIconBorder", false, nil, "Use the cast bar's border size and color around the icon."),
		CT("Vertical Separator", unit, "castIconSeparator", false, function() return S(unit)[inWidthKey] == false end,
			"Draw a divider between the integrated icon and the bar, in the cast bar's border color. Requires Make Icon Part of the Bar."),
	}
	if unit ~= "boss" then
		iconRows[#iconRows + 1] = CT("Show Icon on Portrait", unit, portraitKey, false, nil,
			"Shows the spell icon over the portrait while casting and lets the bar use the full width.")
	end
	iconRows[#iconRows + 1] = CS("Offset X", -50, 50, 1, unit, oxKey, 0)
	iconRows[#iconRows + 1] = CS("Offset Y", -50, 50, 1, unit, oyKey, 0)
	p:Cog("Cast Icon", iconRows, { disabled = function() return off() or S(unit)[iconKey] == false end })

	p:Slider("Bar Background", "Opacity of the cast bar background.", 0, 100, 1,
		function() return floor((S(unit).castBgAlpha or 0.5) * 100 + 0.5) end,
		function(v) S(unit).castBgAlpha = v / 100 end, off)
	Swatch(p, "Cast Background", unit, "castBgColor", { 0, 0, 0 })

	Dropdown(p, "Spell Name", "Where the spell name is.", TEXT_SIDE, unit, "castSpellNameSide", "left", off, function(v)
		local s = S(unit)
		if v ~= "none" and s.showCastTarget ~= false and (s.castSpellTargetSide or "right") == v then
			s.showCastTarget = false
		end
	end)
	Swatch(p, "Spell Name Color", unit, "castSpellNameColor", { 1, 1, 1 })
	local nameRows = {
		CS("Size", 6, 20, 1, unit, "castSpellNameSize", 11),
		CS("X Offset", -50, 50, 1, unit, "castSpellNameX", 0),
		CS("Y Offset", -50, 50, 1, unit, "castSpellNameY", 0),
	}
	if unit == "target" or unit == "focus" then
		nameRows[#nameRows + 1] = CT("Combine Spell Name and Target", unit, "castCombineNameTarget", false, nil,
			"Appends the cast target to the spell name (Spell Name - Target), class colored, and disables the separate Spell Target display.")
	end
	p:Cog("Spell Name", nameRows)

	p:Dropdown("Duration", "Where the time left is.", function() return Items(DURATION_SIDE) end,
		function() return S(unit).showCastDuration == false and "none" or (S(unit).castDurationSide or "right") end,
		function() return LabelOf(DURATION_SIDE, S(unit).showCastDuration == false and "none" or (S(unit).castDurationSide or "right")) end,
		function(v)
			if v == "none" then
				S(unit).showCastDuration = false
			else
				S(unit).showCastDuration = true
				S(unit).castDurationSide = v
			end
		end, nil, off)
	Swatch(p, "Duration Color", unit, "castDurationColor", { 1, 1, 1 })
	p:Cog("Duration", {
		CS("Size", 6, 20, 1, unit, "castDurationSize", 10),
		CS("X Offset", -50, 50, 1, unit, "castDurationX", 0),
		CS("Y Offset", -50, 50, 1, unit, "castDurationY", 0),
	})

	if unit ~= "boss" then
		p:Dropdown("Spell Target", "Where the name of the cast's target is (5.4.8: the caster's target when the cast starts).",
			function() return Items(TEXT_SIDE) end,
			function() return S(unit).showCastTarget == false and "none" or (S(unit).castSpellTargetSide or "right") end,
			function() return LabelOf(TEXT_SIDE, S(unit).showCastTarget == false and "none" or (S(unit).castSpellTargetSide or "right")) end,
			function(v)
				local s = S(unit)
				if v == "none" then
					s.showCastTarget = false
				else
					s.showCastTarget = true
					s.castSpellTargetSide = v
					if (s.castSpellNameSide or "left") == v then
						s.castSpellNameSide = "none"
					end
				end
			end, nil, function() return off() or S(unit).castCombineNameTarget end)
		Swatch(p, "Spell Target Color", unit, "castSpellTargetColor", { 1, 1, 1 })
		p:Cog("Spell Target", {
			CS("Size", 6, 20, 1, unit, "castSpellTargetSize", 11),
			CS("X Offset", -50, 50, 1, unit, "castSpellTargetX", 0),
			CS("Y Offset", -50, 50, 1, unit, "castSpellTargetY", 0),
		})
	end
	Toggle(p, "Reverse Fill", "The bar fills from right to left.", unit, "castReverseFill", false, off)

	local widthKey = isPlayer and "playerCastbarWidth" or "castbarWidth"
	p:Slider("Cast Bar Width", "Width of the cast bar. 0 = the frame width.", 0, 500, 1, Get(unit, widthKey, unit == "boss" and 0 or 181), Set(unit, widthKey), off)
	p:Slider("Border Size", "Cast bar border in pixels (Custom Border Style).", 0, 8, 1, Get(unit, "castBorderSize", 1), Set(unit, "castBorderSize"),
		function() return off() or not S(unit).castBorderCustom end)
	Swatch(p, "Border", unit, "castBorderColor", { 0, 0, 0 }, {
		disabled = function() return off() or not S(unit).castBorderCustom end })
end

local function DebuffBehaviorRows(p, unit, isDisabled)
	Dropdown(p, "Debuff Growth Direction", "Direction the debuff icons extend. Auto follows their anchor; on Simple Boss Display it grows away from the frame. Choose Right to put the first icons on the left.",
		AURA_GROWTH, unit, "debuffGrowth", "auto", isDisabled)
	if unit == "target" or unit == "focus" or unit == "boss" then
		Slider(p, "My Debuff Size (%)", "Size of your debuff icons relative to the normal icons, including your pet and vehicle. 100% keeps the normal size; try 125% for a modest increase. Simple Boss Display uses the frame height as its base size. Other casters, buffs, and text sizes are unchanged.",
			100, 200, 5, unit, "debuffMineScale", 100, isDisabled)
		Toggle(p, "My Debuffs First", "Group your debuffs (including your pet and vehicle) before other casters, keeping the client order within each group. Your debuffs get priority when Max Count is reached. Choose Debuff Growth Direction: Right to put yours on the left.",
			unit, "debuffMineFirst", false, isDisabled)
	end
end

-- Buff / debuff rows of main frames.
local function AuraRows(p, unit)
	local function buffOff() return S(unit).showBuffs == false end
	local function debuffOff() return (S(unit).debuffAnchor or "bottomleft") == "none" end
	local function Swap(key, value)
		-- Buffs and debuffs never use the same anchor: the other one takes the old spot.
		local s = S(unit)
		local otherKey = key == "buffAnchor" and "debuffAnchor" or "buffAnchor"
		local old = s[key] or (key == "buffAnchor" and "topleft" or "bottomleft")
		if value ~= "none" and s[otherKey] == value then
			s[otherKey] = old
		end
		s[key] = value
	end
	p:Dropdown("Buff Display", "Where the buffs are.", function() return Items(AURA_ANCHOR) end,
		function() return S(unit).showBuffs == false and "none" or (S(unit).buffAnchor or "topleft") end,
		function() return LabelOf(AURA_ANCHOR, S(unit).showBuffs == false and "none" or (S(unit).buffAnchor or "topleft")) end,
		function(v)
			if v == "none" then
				S(unit).showBuffs = false
			else
				S(unit).showBuffs = true
				Swap("buffAnchor", v)
			end
		end)
	Sync(p, "Apply Buffs Location to all Frames", unit, { "showBuffs", "buffAnchor" })
	local buffRows = {
		CD("Growth Direction", AURA_GROWTH, unit, "buffGrowth", "auto"),
		CS("Max Count", 1, 40, 1, unit, "maxBuffs", 4),
		{ type = "slider", label = "Max Per Row", min = 1, max = 40, step = 1,
			get = function() return S(unit).buffMaxPerRow or S(unit).maxBuffs or 4 end, set = function(v) S(unit).buffMaxPerRow = v end },
		CT("Cropped Icons", unit, "buffCropIcons", false),
		CS("Icon Zoom", 0, 0.2, 0.01, unit, "buffIconZoom", 0.07),
	}
	if unit ~= "player" then
		buffRows[#buffRows + 1] = CT("Dispel Type Borders", unit, "buffDispelBorder", false)
	end
	p:Cog("Buff Settings", buffRows, { disabled = buffOff })
	Slider(p, "Buff Size", "Size of the buff icons.", 10, 70, 1, unit, "buffSize", 22, buffOff)
	p:Cog("Buff Position", {
		CS("Offset X", -500, 500, 1, unit, "buffOffsetX", 0),
		CS("Offset Y", -500, 500, 1, unit, "buffOffsetY", 0),
		CS("Spacing X", -1, 10, 1, unit, "buffSpacingX", 1),
		CS("Spacing Y", -1, 10, 1, unit, "buffSpacingY", 1),
	}, { icon = "directions", disabled = buffOff })

	Toggle(p, "Show Buff Duration", "Show the time left on the buff icons.", unit, "buffShowCooldownText", false, buffOff)
	p:Cog("Duration Text", {
		CS("Size", 6, 100, 1, unit, "buffCooldownTextSize", 10),
		CS("Offset X", -100, 100, 1, unit, "buffCooldownTextOffsetX", 0),
		CS("Offset Y", -100, 100, 1, unit, "buffCooldownTextOffsetY", 0),
		{ type = "slider", label = "Precise Below (sec)", min = 0, max = 60, step = 1, tip = "Below this many seconds the time shows one decimal. 0 = off.",
			get = function() return S(unit).buffCooldownTextPrecision or 0 end, set = function(v) S(unit).buffCooldownTextPrecision = v > 0 and v or nil end },
	}, { icon = "directions", disabled = function() return buffOff() or not S(unit).buffShowCooldownText end })
	Slider(p, "Buff Stack Size", "Size of the stack number.", 6, 100, 1, unit, "buffStackTextSize", 14, buffOff)
	p:Cog("Stack Position", {
		CD("Position", STACK_POS, unit, "buffStackTextPosition", "bottomright"),
		CS("Offset X", -100, 100, 1, unit, "buffStackTextOffsetX", 0),
		CS("Offset Y", -100, 100, 1, unit, "buffStackTextOffsetY", 0),
	}, { icon = "directions", disabled = buffOff })

	p:Dropdown("Debuff Display", "Where the debuffs are.", function() return Items(AURA_ANCHOR) end,
		function() return S(unit).debuffAnchor or "bottomleft" end,
		function() return LabelOf(AURA_ANCHOR, S(unit).debuffAnchor or "bottomleft") end,
		function(v) Swap("debuffAnchor", v) end)
	local debuffRows = {
		CS("Max Count", 1, 40, 1, unit, "maxDebuffs", 20),
		{ type = "slider", label = "Max Per Row", min = 1, max = 40, step = 1,
			get = function() return S(unit).debuffMaxPerRow or S(unit).maxDebuffs or 20 end, set = function(v) S(unit).debuffMaxPerRow = v end },
		CT("Cropped Icons", unit, "debuffCropIcons", false),
		CS("Icon Zoom", 0, 0.2, 0.01, unit, "debuffIconZoom", 0.07),
		CT("Dispel Type Borders", unit, "debuffDispelBorder", false),
	}
	if unit == "player" then
		debuffRows[#debuffRows + 1] = CT("Use Dispel Colors", unit, "debuffDispelUsePalette", false,
			function() return not S(unit).debuffDispelBorder end, "Colors the dispel type borders with your Dispel Colors instead of Blizzard's.")
	end
	p:Cog("Debuff Settings", debuffRows, { disabled = debuffOff })
	Slider(p, "Debuff Size", "Size of the debuff icons.", 10, 70, 1, unit, "debuffSize", 22, debuffOff)
	p:Cog("Debuff Position", {
		CS("Offset X", -500, 500, 1, unit, "debuffOffsetX", 0),
		CS("Offset Y", -500, 500, 1, unit, "debuffOffsetY", 0),
		CS("Spacing X", -1, 10, 1, unit, "debuffSpacingX", 1),
		CS("Spacing Y", -1, 10, 1, unit, "debuffSpacingY", 1),
	}, { icon = "directions", disabled = debuffOff })
	DebuffBehaviorRows(p, unit, debuffOff)

	Toggle(p, "Show Debuff Duration", "Show the time left on the debuff icons.", unit, "debuffShowCooldownText", false, debuffOff)
	p:Cog("Duration Text", {
		CS("Size", 6, 100, 1, unit, "debuffCooldownTextSize", 10),
		CS("Offset X", -100, 100, 1, unit, "debuffCooldownTextOffsetX", 0),
		CS("Offset Y", -100, 100, 1, unit, "debuffCooldownTextOffsetY", 0),
		{ type = "slider", label = "Precise Below (sec)", min = 0, max = 60, step = 1,
			get = function() return S(unit).debuffCooldownTextPrecision or 0 end, set = function(v) S(unit).debuffCooldownTextPrecision = v > 0 and v or nil end },
	}, { icon = "directions", disabled = function() return debuffOff() or not S(unit).debuffShowCooldownText end })
	Slider(p, "Debuff Stack Size", "Size of the stack number.", 6, 100, 1, unit, "debuffStackTextSize", 14, debuffOff)
	p:Cog("Stack Position", {
		CD("Position", STACK_POS, unit, "debuffStackTextPosition", "bottomright"),
		CS("Offset X", -100, 100, 1, unit, "debuffStackTextOffsetX", 0),
		CS("Offset Y", -100, 100, 1, unit, "debuffStackTextOffsetY", 0),
	}, { icon = "directions", disabled = debuffOff })

	-- Filters
	local label = UF.UNIT_LABELS[unit]
	if unit == "player" then
		local buffItems = { { value = "all", name = "All Buffs" }, { value = "duration", name = "Has Duration" } }
		p:MultiSelect(label .. " Buff Filter", "All Buffs shows every buff. Has Duration shows every buff that has a duration (hides permanent buffs).",
			function() return buffItems end,
			function(v)
				local s = S(unit)
				if v == "all" then
					return s.buffShowAll ~= false and not s.buffHasDuration
				end
				return s.buffHasDuration
			end,
			function(v)
				local s = S(unit)
				if v == "all" then
					s.buffShowAll = not (s.buffShowAll ~= false and not s.buffHasDuration) and true or false
					s.buffHasDuration = nil
				else
					s.buffHasDuration = not s.buffHasDuration or nil
					if s.buffHasDuration then
						s.buffShowAll = false
					end
				end
			end,
			function()
				local s = S(unit)
				if s.buffHasDuration then
					return "Has Duration"
				end
				return s.buffShowAll ~= false and "All Buffs" or "None"
			end, buffOff)
		local debuffClasses = {
			{ "ShowAll", "All Debuffs" }, { "HasDuration", "Has Duration" }, { "CastByMe", "Cast By You" },
			{ "BossAura", "Boss Debuffs" }, { "Dispellable", "Dispellable By You" }, { "DispelTyped", "Dispels" },
			{ "NonPlayer", "Non-Player Auras" }, { "AnyPlayer", "From Any Player" },
			{ "DispelMagic", "Magic" }, { "DispelCurse", "Curse" }, { "DispelPoison", "Poison" }, { "DispelDisease", "Disease" },
			{ "MatchAll", "Match All Filters" }, { "HideExhaustion", "Hide Exhaustion" },
		}
		p:MultiSelect(label .. " Debuff Filter", "All Debuffs shows every debuff. Otherwise only debuffs that match the checked filters (any of them, or all with Match All Filters). Hide Exhaustion hides Sated and the other Bloodlust lockouts.",
			function()
				local items = {}
				for i, c in ipairs(debuffClasses) do
					items[i] = { value = c[1], name = c[2] }
				end
				return items
			end,
			function(v)
				local s = S(unit)
				if v == "ShowAll" then
					return s.debuffShowAll ~= false
				elseif v == "HideExhaustion" then
					return s.debuffHideExhaustion ~= false
				elseif v == "HasDuration" then
					return s.debuffHasDuration
				elseif v == "MatchAll" then
					return s.debuffFilterMatch == "all"
				end
				return s["debuff" .. v]
			end,
			function(v)
				local s = S(unit)
				if v == "ShowAll" then
					s.debuffShowAll = s.debuffShowAll == false
				elseif v == "HasDuration" then
					s.debuffHasDuration = not s.debuffHasDuration or nil
				elseif v == "MatchAll" then
					s.debuffFilterMatch = s.debuffFilterMatch ~= "all" and "all" or nil
				elseif v == "HideExhaustion" then
					s.debuffHideExhaustion = (s.debuffHideExhaustion ~= false) and false or nil
				else
					s["debuff" .. v] = not s["debuff" .. v] or nil
				end
			end,
			function()
				local s = S(unit)
				if s.debuffShowAll ~= false then
					return "All Debuffs"
				end
				local names = {}
				for _, c in ipairs(debuffClasses) do
					if c[1] ~= "ShowAll" and c[1] ~= "MatchAll" and (s["debuff" .. c[1]]) then
						names[#names + 1] = c[2]
					end
				end
				return #names > 0 and table.concat(names, s.debuffFilterMatch == "all" and " & " or ", ") or "None"
			end, debuffOff)
	else
		local buffClasses = { { "DurOnly", "Has Duration" }, { "Stealable", "Stealable" }, { "Dispellable", "Dispellable" } }
		p:MultiSelect(label .. " Buff Filter", "Nothing checked shows every buff. Stealable = buffs you can spellsteal or purge. Dispellable = buffs with a dispel type. Has Duration hides permanent buffs.",
			function()
				local items = {}
				for i, c in ipairs(buffClasses) do
					items[i] = { value = c[1], name = c[2] }
				end
				return items
			end,
			function(v) return S(unit)["buff" .. v] end,
			function(v) S(unit)["buff" .. v] = not S(unit)["buff" .. v] or nil end,
			function()
				local names = {}
				for _, c in ipairs(buffClasses) do
					if S(unit)["buff" .. c[1]] then
						names[#names + 1] = c[2]
					end
				end
				return #names > 0 and table.concat(names, ", ") or "All Buffs"
			end, buffOff)
		p:Cog("Purgeable Buffs", {
			{ type = "dropdown", label = "Glow Style", tip = "Glows the buffs you can purge or spellsteal. Glowing buffs lead the row.",
				items = function() return Items({ { 0, "None" }, { 99, "Blizzard Border" } }) end,
				get = function() return S(unit).buffPurgeGlow or 0 end,
				set = function(v) S(unit).buffPurgeGlow = v ~= 0 and v or nil end },
		}, { disabled = buffOff })
		p:Dropdown(label .. " Debuff Filter", "Which debuffs are shown. Tracked Auras always show in addition (Edit Tracked Auras at the top). 5.4.8 has no 'important' flag: Important means debuffs flagged as boss debuffs.",
			function() return DebuffModeItems(unit) end,
			function() return UF.DebuffFilterMode(S(unit)) end,
			function() return LabelOf(DEBUFF_MODE, UF.DebuffFilterMode(S(unit))) end,
			function(v) S(unit).debuffFilterMode = v end, nil, debuffOff)
		p:Cog("Debuff Filter", {
			CT("Has Duration", unit, "debuffHasDuration", false, nil, "Only show debuffs that have a duration, excluding permanent ones."),
			HideExhaustionRow(unit),
		}, { disabled = debuffOff })
	end

	if unit == "player" then
		p:Dropdown("Dispel Overlay", "Tints the health bar while you have a debuff with a dispel type.", function() return Items(DISPEL_OVERLAY) end,
			function() return UF.db.dispelOverlay or "none" end,
			function() return LabelOf(DISPEL_OVERLAY, UF.db.dispelOverlay or "none") end,
			function(v) UF.db.dispelOverlay = v end)
		p:Cog("Dispel Overlay", {
			{ type = "slider", label = "Overlay Opacity", min = 5, max = 100, step = 1,
				get = function() return UF.db.dispelOverlayOpacity or 100 end, set = function(v) UF.db.dispelOverlayOpacity = v end },
			{ type = "toggle", label = "Only Dispellable by You", tip = "Shows the overlay only for debuffs you can dispel.",
				get = function() return UF.db.dispelOverlayByMe end, set = function(v) UF.db.dispelOverlayByMe = v end },
		})
		p:Label("Dispel Colors", "Colors of the dispel overlay and of Use Dispel Colors.")
		for _, kind in ipairs({ "Poison", "Disease", "Curse", "Magic" }) do
			local key = UF.DISPEL_KEYS[kind]
			p:Swatch(kind, function() local c = UF.db[key] return c.r, c.g, c.b end,
				function(r, g, b) local c = UF.db[key] c.r, c.g, c.b = r, g, b end)
		end
	end

	p:Slider("Aura Border Size", "Border of the aura icons, in pixels.", 0, 8, 1, Get(unit, "auraBorderSize", 1), Set(unit, "auraBorderSize"))
	p:Swatch("Aura Border Color",
		function() local s = S(unit) return s.auraBorderR or 0, s.auraBorderG or 0, s.auraBorderB or 0, s.auraBorderA or 1 end,
		function(r, g, b, a) local s = S(unit) s.auraBorderR, s.auraBorderG, s.auraBorderB = r, g, b if a then s.auraBorderA = a end end,
		{ alpha = true })
	p:Toggle("Aura Tooltips", "Show the aura tooltip when you hover a buff or debuff icon.",
		function() return S(unit).showAuraTooltips ~= false end, function(v) S(unit).showAuraTooltips = v end)
end

---------------------------------------------------------------------------
-- Main Frames (player / target / focus)
---------------------------------------------------------------------------
local MAIN_LIST = { { "player", "Player" }, { "target", "Target" }, { "focus", "Focus" } }
local MINI_LIST = { { "targettarget", "Target of Target" }, { "focustarget", "Focus Target" }, { "pet", "Pet" } }

-- "Edit Frame" (which frame the page changes) is the header dropdown above
-- the preview (PreviewHeader).
local function UnitSelector(p, list, which)
	p:Dropdown("Apply All Settings From", "Copy every shared setting from another frame in this group to this frame.",
		function()
			local items = {}
			for _, entry in ipairs(list) do
				if entry[1] ~= sel[which] then
					items[#items + 1] = { value = entry[1], name = entry[2] }
				end
			end
			return items
		end,
		function() return nil end, function() return "Choose Frame..." end,
		function(v)
			local dialog = StaticPopup_Show("EUI_UF_APPLY_ALL", UF.UNIT_LABELS[v], UF.UNIT_LABELS[sel[which]])
			if dialog then
				dialog.data = { from = v, to = sel[which] }
			end
		end)
end

local function BuildDisplay(p, unit)
	p:Section("Display")
	VisibilityRow(p, unit)
	p:Toggle("Enable " .. UF.UNIT_LABELS[unit] .. " Frame", "Turn this EllesmereUI frame on or off. Turning on a frame that was off may need a UI reload to hide Blizzard's frame.",
		function() return UF.db.enabledFrames[unit] ~= false end,
		function(v) UF.db.enabledFrames[unit] = v end)
	BarTextureRow(p, unit, false, true)
	p:Toggle("Dark Mode", "Dark health fill (#111111) with a light grey background for the missing health. Applies to all frames.",
		function() return UF.db.darkTheme end, function(v) UF.db.darkTheme = v end)
	p:Slider("Border Size", "Border around the whole frame, in pixels.", 0, 8, 1, Get(unit, "borderSize", 1), Set(unit, "borderSize"))
	Sync(p, "Apply Border to all Frames", unit, { "borderSize", "borderColor", "borderAlpha" })
	p:Swatch("Border",
		function() local c = S(unit).borderColor or {} return c.r or 0, c.g or 0, c.b or 0, S(unit).borderAlpha or 1 end,
		function(r, g, b, a)
			local s = S(unit)
			s.borderColor = s.borderColor or {}
			s.borderColor.r, s.borderColor.g, s.borderColor.b = r, g, b
			if a then s.borderAlpha = a end
		end, { alpha = true })
	local tipItems = {
		{ value = "unit", name = "Unit Frame" }, { value = "auras", name = "Main Frames Auras" }, { value = "boss", name = "Boss Frames Auras" },
	}
	p:MultiSelect("Show Tooltip For", "Choose which tooltips appear on hover. Affects all unit frames, including boss frames.",
		function() return tipItems end,
		function(v)
			if v == "unit" then
				return S(unit).showUnitTooltip ~= false
			elseif v == "auras" then
				return S(unit).showAuraTooltips ~= false
			end
			return UF.db.boss.showAuraTooltips ~= false
		end,
		function(v)
			if v == "unit" then
				local on = S(unit).showUnitTooltip == false
				for _, key in ipairs({ "player", "target", "focus", "targettarget", "focustarget", "pet", "boss" }) do
					UF.db[key].showUnitTooltip = on
				end
			elseif v == "auras" then
				local on = S(unit).showAuraTooltips == false
				for _, key in ipairs({ "player", "target", "focus", "targettarget", "focustarget", "pet" }) do
					UF.db[key].showAuraTooltips = on
				end
			else
				UF.db.boss.showAuraTooltips = UF.db.boss.showAuraTooltips == false
			end
		end,
		function()
			local names = {}
			if S(unit).showUnitTooltip ~= false then names[#names + 1] = "Unit Frame" end
			if S(unit).showAuraTooltips ~= false then names[#names + 1] = "Auras" end
			if UF.db.boss.showAuraTooltips ~= false then names[#names + 1] = "Boss Auras" end
			return #names > 0 and table.concat(names, ", ") or "None"
		end)
	Dropdown(p, "Frame Strata", "Controls the order that overlapping elements display in. Set higher to show above other elements.",
		STRATA, unit, "frameStrata", "MEDIUM")
	Sync(p, "Apply Frame Strata to all Frames", unit, { "frameStrata" })
	p:Cog("Detached Bar Stratas", {
		{ type = "toggle", label = "Custom Bar Stratas", get = function() return UF.db.enableCustomBarStratas end, set = function(v) UF.db.enableCustomBarStratas = v end },
		{ type = "dropdown", label = "Detached Power Bar", items = function() return Items(STRATA) end,
			get = function() return UF.db.detachedPowerStrata or "HIGH" end, set = function(v) UF.db.detachedPowerStrata = v end },
		{ type = "dropdown", label = "Detached Text Bar", items = function() return Items(STRATA) end,
			get = function() return UF.db.detachedTextBarStrata or "DIALOG" end, set = function(v) UF.db.detachedTextBarStrata = v end },
	})
	p:Toggle("Show Decimal on Health Text", "Show one decimal place on health text: health values like 240.5k and health percent like 77.3%. Power text is unaffected. Applies to all units.",
		function() return UF.db.showDecimalOnText end, function(v) UF.db.showDecimalOnText = v end)
	p:Cog("Health Text Decimals", {
		{ type = "toggle", label = "Only Show for % Health", get = function() return UF.db.showDecimalPercentOnly end, set = function(v) UF.db.showDecimalPercentOnly = v end },
		{ type = "toggle", label = "Show 2 for Boss", get = function() return UF.db.showDecimalBoss2 ~= false end, set = function(v) UF.db.showDecimalBoss2 = v end },
		{ type = "toggle", label = "Hide Trailing Zeros", get = function() return UF.db.showDecimalTrimZeros end, set = function(v) UF.db.showDecimalTrimZeros = v end },
	}, { disabled = function() return not UF.db.showDecimalOnText end })

	local hoverItems = { { value = "highlight", name = "Highlight" } }
	if unit == "player" then
		hoverItems[2] = { value = "threat", name = "Player Threat (Non-Tank)" }
	end
	p:MultiSelect("Hover Borders", "Highlight: the frame border changes color on mouseover. Player Threat: a border on your player frame when you pull or hold threat as a non-tank, in dungeons and raids.",
		function() return hoverItems end,
		function(v)
			if v == "threat" then
				return UF.db.playerThreatBorderEnabled
			end
			return UF.db.player.highlightEnabled ~= false
		end,
		function(v)
			if v == "threat" then
				UF.db.playerThreatBorderEnabled = not UF.db.playerThreatBorderEnabled
			else
				local on = UF.db.player.highlightEnabled == false
				for _, key in ipairs(UF.MAIN_UNITS) do
					UF.db[key].highlightEnabled = on
				end
			end
		end,
		function()
			local names = {}
			if UF.db.player.highlightEnabled ~= false then names[#names + 1] = "Highlight" end
			if unit == "player" and UF.db.playerThreatBorderEnabled then names[#names + 1] = "Threat" end
			return #names > 0 and table.concat(names, ", ") or "None"
		end)
	if unit == "player" then
		p:Swatch("Close to Aggro", function() local c = UF.db.playerThreatNearAggroColor return c.r, c.g, c.b end,
			function(r, g, b) local c = UF.db.playerThreatNearAggroColor c.r, c.g, c.b = r, g, b end,
			{ active = function() return UF.db.playerThreatBorderEnabled end })
		p:Swatch("Has Aggro", function() local c = UF.db.playerThreatHasAggroColor return c.r, c.g, c.b end,
			function(r, g, b) local c = UF.db.playerThreatHasAggroColor c.r, c.g, c.b = r, g, b end,
			{ active = function() return UF.db.playerThreatBorderEnabled end })
	end
	p:Swatch("Highlight",
		function() local c = UF.db.player.highlightColor or {} return c.r or 1, c.g or 1, c.b or 1, UF.db.player.highlightAlpha or 1 end,
		function(r, g, b, a)
			for _, key in ipairs(UF.MAIN_UNITS) do
				UF.db[key].highlightColor = { r = r, g = g, b = b }
				if a then UF.db[key].highlightAlpha = a end
			end
		end, { alpha = true, active = function() return UF.db.player.highlightEnabled ~= false end })

	if unit == "target" or unit == "focus" then
		p:Toggle("Show Threat % on Target", "Shows your threat percentage on the target frame while you are in combat with it. The cog adds the focus frame.",
			function() return UF.db.threatPctEnabled end, function(v) UF.db.threatPctEnabled = v end)
		p:Cog("Threat % Units", {
			{ type = "toggle", label = "Show on Focus", get = function() return UF.db.threatPctFocus end, set = function(v) UF.db.threatPctFocus = v end },
		}, { disabled = function() return not UF.db.threatPctEnabled end })
		p:Dropdown("Threat % Position", "Where the threat number is.", function() return Items(THREAT_POS) end,
			function() return UF.db.threatPctPosition or "CENTER" end,
			function() return LabelOf(THREAT_POS, UF.db.threatPctPosition or "CENTER") end,
			function(v) UF.db.threatPctPosition = v end, nil, function() return not UF.db.threatPctEnabled end)
		p:Cog("Threat %", {
			{ type = "toggle", label = "Color by Threat", tip = "Colors the number by threat status. Off shows it in white.",
				get = function() return UF.db.threatPctColorByThreat ~= false end, set = function(v) UF.db.threatPctColorByThreat = v end },
			{ type = "slider", label = "Size", min = 6, max = 20, step = 1, get = function() return UF.db.threatPctSize or 12 end, set = function(v) UF.db.threatPctSize = v end },
			{ type = "slider", label = "X Offset", min = -100, max = 100, step = 1, get = function() return UF.db.threatPctXOffset or 0 end, set = function(v) UF.db.threatPctXOffset = v end },
			{ type = "slider", label = "Y Offset", min = -100, max = 100, step = 1, get = function() return UF.db.threatPctYOffset or 0 end, set = function(v) UF.db.threatPctYOffset = v end },
		}, { disabled = function() return not UF.db.threatPctEnabled end })
	end
end

local function BuildPortrait(p, unit)
	p:Section("Portrait")
	local function modeNone() return S(unit).showPortrait == false or (S(unit).portraitStyle or "attached") == "none" end
	local function notDetached() return modeNone() or S(unit).portraitStyle ~= "detached" end
	local function RoundPortrait()
		return not notDetached() and S(unit).detachedPortraitShape == "circle" and (S(unit).portraitMode or "2d") ~= "3d"
	end
	p:Dropdown("Portrait Mode", "None, attached to the bars, or detached next to the frame.", function() return Items(PORTRAIT_MODE) end,
		function() return S(unit).showPortrait == false and "none" or (S(unit).portraitStyle or "attached") end,
		function() return LabelOf(PORTRAIT_MODE, S(unit).showPortrait == false and "none" or (S(unit).portraitStyle or "attached")) end,
		function(v)
			local s = S(unit)
			s.portraitStyle = v
			s.showPortrait = v ~= "none"
			if v ~= "detached" then
				s.portraitSize = 0
				if s.portraitSide == "top" then
					s.portraitSide = unit == "player" and "left" or "right"
				end
			end
		end)
	Sync(p, "Apply Portrait Mode to all Frames", unit, { "portraitStyle", "showPortrait" })
	p:Cog("Portrait Settings", {
		CT("Custom Non-Player Portrait", unit, "portraitNonPlayerOn", false, nil, "Pick what NPCs show in Class art instead of their 2D portrait."),
	}, { disabled = modeNone, disabledTip = "Portrait Mode is set to None" })

	local ART = { { "3d", "3D Portrait" }, { "2d", "2D Portrait" } }
	for _, key in ipairs(UF.CLASS_STYLE_ORDER) do
		ART[#ART + 1] = { "class:" .. key, "Class: " .. UF.CLASS_STYLE_NAMES[key] }
	end
	local function ArtValue()
		local s = S(unit)
		if s.portraitMode == "class" then
			return "class:" .. (s.classThemeStyle or "modern")
		end
		return s.portraitMode or "2d"
	end
	p:Dropdown("Art Style", "3D model, 2D portrait or EllesmereUI class art.", function() return Items(ART) end, ArtValue,
		function() return LabelOf(ART, ArtValue()) end,
		function(v)
			local s = S(unit)
			local style = v:match("^class:(.+)$")
			if style then
				s.portraitMode = "class"
				s.classThemeStyle = style
			else
				s.portraitMode = v
			end
			s.showPortrait = true
			if v == "3d" and s.detachedPortraitShape == "circle" then
				s.detachedPortraitShape = "portrait"
			end
		end, nil, modeNone)
	Sync(p, "Apply Art Style to all Frames", unit, { "portraitMode", "classThemeStyle" })

	Dropdown(p, "Non-Player Portrait", "What NPCs show while Art Style is Class.", PORTRAIT_NONPLAYER, unit, "portraitNonPlayer", "2d",
		function() return modeNone() or S(unit).portraitMode ~= "class" or not S(unit).portraitNonPlayerOn end)
	p:Blank()

	Slider(p, "Size", "Size change of a detached portrait.", -50, 100, 1, unit, "portraitSize", 0, notDetached)
	Sync(p, "Apply Portrait Size to all Frames", unit, { "portraitSize" })
	p:Cog("Portrait Zoom", {
		CS("2D Zoom", 50, 100, 1, unit, "portraitArtScale", 100),
		CS("3D Zoom", 100, 300, 1, unit, "portrait3dZoom", 100),
		CS("Class Zoom", 50, 200, 1, unit, "portraitClassZoom", 100, function() return S(unit).portraitMode ~= "class" end),
		CT("Mirror Portrait", unit, "portraitMirror", false, nil, "Mirrors 2D portraits and class art."),
	}, { disabled = modeNone })
	Dropdown(p, "Position", "Side of the portrait. Top needs Detached mode.", PORTRAIT_SIDE, unit, "portraitSide", unit == "player" and "left" or "right", modeNone,
		function(v)
			if v == "top" and S(unit).portraitStyle ~= "detached" then
				S(unit).portraitSide = unit == "player" and "left" or "right"
			end
		end)
	Sync(p, "Apply Portrait Position to all Frames", unit, { "portraitSide" })
	p:Cog("Portrait Position Offsets", {
		CS("X Offset", -100, 100, 1, unit, "portraitX", 0),
		CS("Y Offset", -100, 100, 1, unit, "portraitY", 0),
	}, { icon = "directions", disabled = notDetached, disabledTip = "This option requires Portrait Mode to be set to Detached." })

	Dropdown(p, "Shape", "Shape of a detached portrait. 5.4.8 has no texture masks: Circle works with 2D portraits.", PORTRAIT_SHAPE, unit,
		"detachedPortraitShape", "portrait", notDetached)
	Sync(p, "Apply Portrait Shape to all Frames", unit, { "detachedPortraitShape" })
	p:Label("Shape Border", "Border of a detached portrait: your color or the unit's class / reaction color.", notDetached)
	Sync(p, "Apply Shape Border to all Frames", unit, { "detachedPortraitBorderColor", "detachedPortraitClassColor", "detachedPortraitBorderSize",
		"detachedPortraitBorderOpacity", "detachedPortraitUnitColorDark" })
	p:Cog("Shape Border Settings", {
		CS("Size", 1, 7, 1, unit, "detachedPortraitBorderSize", 7),
		CS("Opacity", 0, 100, 1, unit, "detachedPortraitBorderOpacity", 100),
		CT("Unit Color in Dark Mode", unit, "detachedPortraitUnitColorDark", false,
			function() return not (S(unit).detachedPortraitClassColor ~= false and UF.db.darkTheme) end,
			"Keeps the unit's class or reaction color on the ring in Dark Mode instead of your own class color."),
		CD("Outer Ring", { { "none", "None" }, { "pixels", "Pixels Ring" }, { "pixels-textured", "Pixels Textured Ring" },
			{ "pixels-shadow", "Pixels Ring Shadow" }, { "pixels-textured-shadow", "Pixels Textured Ring Shadow" }, { "thin-border", "Naowh Thin Circle" } },
			unit, "detachedPortraitOuterRing", "none", function() return not RoundPortrait() end,
			"Adds a second ring around a round portrait, in the frame border color. Requires the Circle shape."),
		CS("Outer Ring Size", 100, 140, 1, unit, "detachedPortraitOuterRingScale", 118,
			function() return not RoundPortrait() or (S(unit).detachedPortraitOuterRing or "none") == "none" end,
			"Size of the outer ring relative to the portrait."),
		CT("Inner Shadow", unit, "detachedPortraitInnerShadow", false, function() return not RoundPortrait() end,
			"Adds a soft shadow inside a round portrait (Circle shape, 2D or class art)."),
	}, { disabled = notDetached })
	Swatch(p, "Custom Color", unit, "detachedPortraitBorderColor", { 0, 0, 0 }, {
		active = function() return S(unit).detachedPortraitClassColor == false end,
		onClick = function()
			if S(unit).detachedPortraitClassColor ~= false then
				S(unit).detachedPortraitClassColor = false
				return true
			end
		end,
	})
	ModeSwatch(p, "Class Colored", PlayerClassColor, function() return S(unit).detachedPortraitClassColor ~= false end,
		function() S(unit).detachedPortraitClassColor = true end)
end

local function BuildHealth(p, unit, mini)
	p:Section("Health Bar")
	local list = unit == "player" and HEALTH_TEXT_PLAYER or (mini and HEALTH_TEXT_MINI or HEALTH_TEXT)
	local sync = not mini
	Slider(p, "Health Bar Height", "Height of the health bar.", mini and 10 or 15, 100, 1, unit, "healthHeight", mini and 25 or 46)
	if sync then
		Sync(p, "Apply Health Bar Height to all Frames", unit, { "healthHeight" })
	end
	p:Cog("Health Bar Fill", {
		CT("Reverse Fill", unit, "healthReverseFill", false),
		CT("Vertical Fill", unit, "healthVerticalFill", false, nil, "Fill the health bar bottom-to-top instead of left-to-right. Reverse Fill flips it to top-to-bottom."),
	})
	Slider(p, "Bar Width", "Width of the health and power bars.", mini and 60 or 80, mini and 300 or 400, 1, unit, "frameWidth", mini and 101 or 181)
	if sync then
		Sync(p, "Apply Bar Width to all Frames", unit, { "frameWidth" })
	end
	FillColorRow(p, unit, sync)
	BackgroundRow(p, unit, sync)
	Toggle(p, "Smooth Health Bars", "Health changes slide instead of jumping.", unit, "smoothBars", false)
	Slider(p, "Fill Opacity", "Opacity of the health fill.", 0, 100, 1, unit, "healthBarOpacity", 90, Dark)
	if sync then
		Sync(p, "Apply Bar Opacity to all Frames", unit, { "healthBarOpacity" })
	end
	TextSlot(p, unit, "left", "Left Text", list, sync)
	TextSlot(p, unit, "right", "Right Text", list, sync)
	TextSlot(p, unit, "center", "Center Text", list, sync)
	if not mini or unit == "boss" then
		TextSlot(p, unit, "extra", "Extra Text (full length)", list, sync)
	else
		p:Blank()
	end
	Toggle(p, "Level Text: Difficulty Color", "Colors level text by difficulty, from grey (trivial) through green, yellow and orange to red (5+ levels above you).",
		unit, "levelDifficultyColor", false)
	Toggle(p, "Level Text: Include Friendly", "Friendly units get their level's color too, instead of white.",
		unit, "levelDifficultyColorFriendly", false, function() return not S(unit).levelDifficultyColor end)
end

local function BuildPower(p, unit)
	p:Section("Power Bar")
	PowerRows(p, unit, true, true)
end

local function BuildCast(p, unit)
	p:Section("Cast Bar")
	CastRows(p, unit)
end

local function BuildTextBar(p, unit)
	p:Section("Text Bar")
	local function off() return not S(unit).bottomTextBar end
	Toggle(p, "Enable Text Bar", "An extra bar with its own texts, at the top or bottom of the frame or detached.", unit, "bottomTextBar", false)
	Sync(p, "Apply Enable Text Bar to all Frames", unit, { "bottomTextBar" })
	p:Swatch("Text Bar Background",
		function() local c = S(unit).btbBgColor or {} return c.r or 0.2, c.g or 0.2, c.b or 0.2, S(unit).btbBgOpacity or 1 end,
		function(r, g, b, a)
			local s = S(unit)
			s.btbBgColor = { r = r, g = g, b = b }
			if a then s.btbBgOpacity = a end
		end, { alpha = true, disabled = off })
	Dropdown(p, "Position", "Where the text bar is.", BTB_POS, unit, "btbPosition", "bottom", off)
	Sync(p, "Apply Text Bar Position to all Frames", unit, { "btbPosition" })
	local function notDetached() local v = S(unit).btbPosition return off() or (v ~= "detached_top" and v ~= "detached_bottom") end
	p:Cog("Detached Position Offsets", {
		CS("X Offset", -200, 200, 1, unit, "btbX", 0),
		CS("Y Offset", -200, 200, 1, unit, "btbY", 0),
	}, { icon = "directions", disabled = notDetached, disabledTip = "This option requires a detached position to be active." })
	Slider(p, "Height", "Height of the text bar.", 0, 100, 1, unit, "bottomTextBarHeight", 16, off)
	Sync(p, "Apply Text Bar Height to all Frames", unit, { "bottomTextBarHeight" })
	Slider(p, "Width", "Width of a detached text bar. 0 = the frame width.", 0, 400, 1, unit, "btbWidth", 0, notDetached)
	Sync(p, "Apply Text Bar Width to all Frames", unit, { "btbWidth" })

	local function Slot(prefix, label)
		local contentKey = prefix .. "Content"
		Dropdown(p, label, "What this text shows.", BTB_TEXT, unit, contentKey, "none", off, function(v)
			if v ~= "none" then
				local s = S(unit)
				for _, other in ipairs({ "btbLeft", "btbRight", "btbCenter" }) do
					if other ~= prefix and s[other .. "Content"] == v then
						s[other .. "Content"] = "none"
					end
				end
			end
		end)
		Sync(p, "Apply Text Bar " .. label .. " to all Frames", unit, { contentKey, prefix .. "ClassColor", prefix .. "PowerColor",
			prefix .. "ColorR", prefix .. "ColorG", prefix .. "ColorB", prefix .. "Size", prefix .. "X", prefix .. "Y" })
		local function none() return off() or (S(unit)[contentKey] or "none") == "none" end
		p:Cog("BTB " .. label .. " Settings", {
			NameFormatRow(unit, prefix),
			CS("Size", 8, 100, 1, unit, prefix .. "Size", 11),
			CS("X Offset", -50, 50, 1, unit, prefix .. "X", 0),
			CS("Y Offset", -30, 30, 1, unit, prefix .. "Y", 0),
			CS("Width %", 20, 200, 5, unit, prefix .. "WidthPct", 100),
		}, { disabled = none, disabledTip = "This option requires a text selection other than none." })
		ModeSwatch(p, "Power Colored", PlayerPowerColor, function() return S(unit)[prefix .. "PowerColor"] end,
			function() S(unit)[prefix .. "PowerColor"] = true S(unit)[prefix .. "ClassColor"] = false end, none)
		SwatchRGB(p, "Custom Colored", unit, prefix .. "Color", {
			active = function() return not S(unit)[prefix .. "ClassColor"] and not S(unit)[prefix .. "PowerColor"] end,
			disabled = none,
			onClick = function()
				local s = S(unit)
				if s[prefix .. "ClassColor"] or s[prefix .. "PowerColor"] then
					s[prefix .. "ClassColor"], s[prefix .. "PowerColor"] = false, false
					return true
				end
			end,
		})
		ModeSwatch(p, "Class Colored", PlayerClassColor, function() return S(unit)[prefix .. "ClassColor"] end,
			function() S(unit)[prefix .. "ClassColor"] = true S(unit)[prefix .. "PowerColor"] = false end, none)
	end
	Slot("btbLeft", "Left Text")
	Slot("btbRight", "Right Text")
	Slot("btbCenter", "Center Text")
	Dropdown(p, "Class Icon", "EllesmereUI class art on the text bar.", CLASS_ICON, unit, "btbClassIcon", "none", off)
	Sync(p, "Apply Text Bar Class Icon to all Frames", unit, { "btbClassIcon" })
	p:Cog("Class Icon Settings", {
		CS("Size", 8, 60, 1, unit, "btbClassIconSize", 14),
		CD("Location", ALIGN, unit, "btbClassIconLocation", "left"),
		CS("X Offset", -50, 50, 1, unit, "btbClassIconX", 0),
		CS("Y Offset", -50, 50, 1, unit, "btbClassIconY", 0),
	}, { disabled = function() return off() or (S(unit).btbClassIcon or "none") == "none" end,
		disabledTip = "This option requires a Class Icon other than None." })
end

local function BuildClassResource(p, unit)
	if unit ~= "player" then
		return
	end
	p:Section("Class Resource")
	local function notModern() return S(unit).classPowerStyle ~= "modern" end
	Dropdown(p, "Enable Class Resource", "Modern: EllesmereUI pips for combo points, holy power, chi, shadow orbs, soul shards, burning embers, runes, arcane charges and maelstrom weapon; bars for demonic fury and eclipse. Blizzard: the stock MoP class bar under the frame.",
		CP_STYLE, unit, "classPowerStyle", "none", nil, function(v) S(unit).showClassPowerBar = v ~= "none" end)
	p:Label("Fill Color", "Class color, or your own color.", notModern)
	local function classOn() return S(unit).classPowerClassColor ~= false end
	Swatch(p, "Empty Bar Color", unit, "classPowerEmptyColor", { 0.2, 0.2, 0.2, 1 }, { alpha = true })
	Swatch(p, "Custom Colored", unit, "classPowerCustomColor", { 1, 0.82, 0 }, {
		active = function() return not classOn() end,
		onClick = function()
			if classOn() then
				S(unit).classPowerClassColor = false
				return true
			end
		end,
	})
	ModeSwatch(p, "Dynamic Colored", function()
		local c = UF.RESOURCE_CLASS_COLORS[select(2, UnitClass("player"))]
		if c then return c[1], c[2], c[3] end
		return 1, 0.82, 0
	end, classOn, function() S(unit).classPowerClassColor = true end)
	Dropdown(p, "Position", "Top: above the health bar. Bottom: below the frame. Above Health Bar: inside the frame, as wide as the bar.",
		CP_POS, unit, "classPowerPosition", "top", notModern)
	p:Cog("Class Resource Position", {
		CS("X Offset", -100, 100, 1, unit, "classPowerBarX", 0),
		CS("Y Offset", -100, 100, 1, unit, "classPowerBarY", 0),
		{ type = "toggle", label = "Lock to Player Frame", tip = "Off: the class resource is moved on its own in Unlock Mode.",
			get = function() return S(unit).lockClassPowerToFrame ~= false end, set = function(v) S(unit).lockClassPowerToFrame = v end },
	}, { icon = "directions", disabled = function() return notModern() or S(unit).classPowerPosition == "above" end })
	Slider(p, "Size", "Width of one pip (the height follows).", 4, 100, 1, unit, "classPowerSize", 8, notModern)
	Slider(p, "Bar Spacing", "Gap between the pips, in pixels.", 0, 10, 1, unit, "classPowerSpacing", 2, notModern)
	p:ColorRow("Background Color", "Background behind the pips.",
		ColorGet(unit, "classPowerBgColor", 0.082, 0.082, 0.082, 1), ColorSet(unit, "classPowerBgColor", true), { alpha = true }, notModern)
end

local function BuildAbsorbs(p, unit)
	p:Section("Absorbs and Heals")
	local function shieldNone() return (S(unit).showPlayerAbsorb or "none") == "none" end
	p:Dropdown("Absorb Style", "How damage absorb shields (UnitGetTotalAbsorbs) are drawn on the health bar.",
		function() return UF.AbsorbItems(UF.ABSORB_STYLE_ORDER) end,
		function() return S(unit).showPlayerAbsorb or "none" end,
		function() local v = S(unit).showPlayerAbsorb or "none" return UF.ABSORB_STYLE_NAMES[v] or v:gsub("^sm:", "") end,
		function(v)
			local s = S(unit)
			s.showPlayerAbsorb = v
			s.absorbOpacity = v == "clean" and 30 or 90
		end, { texturePreview = true, previewPath = function(v) return UF.AbsorbTexture(v) end })
	Sync(p, "Apply Absorb Style, color and rendering to all Frames", unit, { "showPlayerAbsorb", "absorbColor", "absorbEdgeMode", "showOvershield", "overshieldMode", "absorbGlowLine", "absorbGlowLineTexture" })
	p:Cog("Absorb Rendering", {
		CD("Placement", ABSORB_PLACEMENT, unit, "absorbEdgeMode", "overlay"),
		{ type = "dropdown", label = "Show Overshield", tip = "Overshield is the part of an absorb exceeding your empty health. Always backfills it over current health from the shield's edge; From Left grows it from the opposite end of the bar; Never hides it.",
			items = function() return Items(OVERSHIELD) end,
			get = function() local s = S(unit) return s.overshieldMode or (s.showOvershield == false and "never" or "always") end,
			set = function(v) S(unit).overshieldMode = v S(unit).showOvershield = v ~= "never" end },
		CT("Blizzard Glow Line", unit, "absorbGlowLine", false, nil, "Adds a glow line where the overshield meets current health."),
		CD("Glow Line Texture", { { "blizzard", "Blizzard" }, { "pixelsGlow", "Pixels Glow Line" }, { "pixelsOvershield", "Pixels Overshield Line" } },
			unit, "absorbGlowLineTexture", "blizzard", function() return not S(unit).absorbGlowLine end, "Art used for the glow line and the overshield edge."),
		{ type = "toggle", label = "Show on Boss Frames", tip = "Render absorbs on Boss Frames using the Target frame's absorb styling.",
			get = function() return UF.db.boss.showAbsorbs ~= false end, set = function(v) UF.db.boss.showAbsorbs = v end },
	})
	Swatch(p, "Absorb Color", unit, "absorbColor", { 1, 1, 1 }, { disabled = shieldNone })
	Slider(p, "Absorb Opacity", "Opacity of the absorb shield.", 5, 100, 1, unit, "absorbOpacity", 80, shieldNone)

	local function healNone() return (S(unit).healAbsorbStyle or "clean") == "none" end
	p:Dropdown("Heal Absorb Style", "How heal absorbs (UnitGetTotalHealAbsorbs) are drawn over current health.",
		function() return UF.AbsorbItems(UF.HEAL_ABSORB_STYLE_ORDER) end,
		function() return S(unit).healAbsorbStyle or "clean" end,
		function() local v = S(unit).healAbsorbStyle or "clean" return UF.ABSORB_STYLE_NAMES[v] or v:gsub("^sm:", "") end,
		function(v)
			S(unit).healAbsorbStyle = v
			S(unit).healAbsorbOpacity = v == "clean" and 50 or 75
		end, { texturePreview = true, previewPath = function(v) return UF.AbsorbTexture(v) end })
	Sync(p, "Apply Heal Absorb Style, color and rendering to all Frames", unit, { "healAbsorbStyle", "healAbsorbColor", "healAbsorbEdgeMode", "healAbsorbBgOpacity" })
	p:Cog("Heal Absorb Rendering", {
		CD("Placement", ABSORB_PLACEMENT, unit, "healAbsorbEdgeMode", "overlay"),
		CS("Backing Opacity", 0, 100, 1, unit, "healAbsorbBgOpacity", 15),
	})
	Swatch(p, "Heal Absorb Color", unit, "healAbsorbColor", { 0.8, 0.15, 0.15 }, {
		disabled = function() return healNone() or UF.ABSORB_PRECOLORED[S(unit).healAbsorbStyle or ""] end })
	Slider(p, "Heal Absorb Opacity", "Opacity of the heal absorb.", 5, 100, 1, unit, "healAbsorbOpacity", 65, healNone)

	Dropdown(p, "Absorb Bar", "A thin strip that shows the absorb amount.", ABSORB_BAR, unit, "absorbBarPosition", "none")
	Slider(p, "Bar Height", "Height of the absorb strip.", 1, 20, 1, unit, "absorbBarHeight", 4, NotNone(unit, "absorbBarPosition"))
	Swatch(p, "Absorb Bar Color", unit, "absorbBarColor", { 1, 1, 1, 1 }, { alpha = true, disabled = NotNone(unit, "absorbBarPosition") })
	Dropdown(p, "Heal Absorb Bar", "A thin strip that shows the heal absorb amount.", HEAL_ABSORB_BAR, unit, "healAbsorbBarPosition", "none")
	Slider(p, "Bar Height", "Height of the heal absorb strip.", 1, 20, 1, unit, "healAbsorbBarHeight", 4, NotNone(unit, "healAbsorbBarPosition"))
	Swatch(p, "Heal Absorb Bar Color", unit, "healAbsorbBarColor", { 200 / 255, 29 / 255, 29 / 255, 1 }, { alpha = true, disabled = NotNone(unit, "healAbsorbBarPosition") })

	local function predOff() return not S(unit).healPrediction end
	Toggle(p, "Heal Prediction", "Shows incoming heals past the health bar: yours, then other players'.", unit, "healPrediction", false)
	Swatch(p, "Other players' heals", unit, "healPredOtherColor", { 40 / 255, 170 / 255, 40 / 255 }, { disabled = predOff })
	Swatch(p, "Your heals", unit, "healPredColor", { 102 / 255, 243 / 255, 102 / 255 }, { disabled = predOff })
	Slider(p, "Prediction Opacity", "Opacity of the incoming heals.", 5, 100, 1, unit, "healPredOpacity", 60, predOff)
	Slider(p, "Overheal", "How far incoming heals can extend past the end of the health bar, as a percent of its length. 0 keeps them inside the bar.",
		0, 50, 1, unit, "healPredOverheal", 0, predOff)
	p:Dropdown("Heal Prediction Texture", "Texture of the incoming heals.",
		function()
			local items = { { value = "health", name = "Health Bar" }, { value = "flat", name = "Flat" } }
			for _, item in ipairs(UF.BarTextureItems(false)) do
				if item.value ~= "none" then
					items[#items + 1] = item
				end
			end
			return items
		end,
		function() return S(unit).healPredTexture or "health" end,
		function()
			local v = S(unit).healPredTexture or "health"
			return v == "health" and "Health Bar" or (v == "flat" and "Flat" or UF.BarTextureLabel(v))
		end,
		function(v) S(unit).healPredTexture = v end, nil, predOff)
end

local function BuildExtras(p, unit)
	p:Section("Extras")
	if unit == "player" or unit == "target" then
		local function off() return (S(unit).combatIndicatorStyle or "none") == "none" end
		Dropdown(p, "Combat Indicator", "An icon on the frame while the unit is in combat.", COMBAT_STYLE, unit, "combatIndicatorStyle", unit == "player" and "class" or "none")
		Sync(p, "Apply Combat Indicator Style to all Frames", unit, { "combatIndicatorStyle" }, { "player", "target" })
		p:Cog("Combat Indicator Settings", {
			{ type = "toggle", label = "Class Colored", get = function() return S(unit).combatIndicatorColor == "classcolor" end,
				set = function(v) S(unit).combatIndicatorColor = v and "classcolor" or "custom" end,
				disabled = function() return (S(unit).combatIndicatorStyle or ""):match("^combat%d$") ~= nil end },
			CD("Position", COMBAT_POS, unit, "combatIndicatorPosition", "healthbar"),
			CS("Size", 8, 64, 1, unit, "combatIndicatorSize", 22),
			CS("X Offset", -200, 200, 1, unit, "combatIndicatorX", 0),
			CS("Y Offset", -200, 200, 1, unit, "combatIndicatorY", 0),
		}, { disabled = off })
		Swatch(p, "Combat Indicator Color", unit, "combatIndicatorCustomColor", { 1, 1, 1 }, {
			disabled = function()
				local style = S(unit).combatIndicatorStyle or "none"
				return style == "none" or style:match("^combat%d$") ~= nil or S(unit).combatIndicatorColor == "classcolor"
			end })
	else
		p:Label("Combat Indicator", "The Combat Indicator is not available for the Focus frame.", function() return true end)
	end
	p:Label("Enemy Colors", "Health and name colors of NPCs by reaction, and of tapped units. Shared by all frames.")
	for _, entry in ipairs({ { "tapped", "Tapped" }, { "friendly", "Friendly NPC" }, { "neutral", "Neutral" }, { "hostile", "Hostile" } }) do
		local key = entry[1]
		p:Swatch(entry[2], function() return UF.EnemyColor(key) end,
			function(r, g, b) UF.db.enemyColors[key] = { r = r, g = g, b = b } end)
	end

	Toggle(p, "Raid Marker", "Show the raid target icon on the frame.", unit, "raidMarkerEnabled", false)
	Sync(p, "Apply Raid Marker to all Frames", unit, { "raidMarkerEnabled" })
	local function markerOff() return not S(unit).raidMarkerEnabled end
	Slider(p, "Marker Size", "Size of the raid target icon.", 12, 64, 1, unit, "raidMarkerSize", 28, markerOff)
	Sync(p, "Apply Marker Size to all Frames", unit, { "raidMarkerSize" })
	p:Cog("Raid Marker Settings", {
		CD("Position", ALIGN, unit, "raidMarkerAlign", "right"),
		CS("X Offset", -200, 200, 1, unit, "raidMarkerX", 0),
		CS("Y Offset", -200, 200, 1, unit, "raidMarkerY", 0),
	}, { icon = "directions", disabled = markerOff })

	if unit == "player" or unit == "target" then
		Toggle(p, "Leader Indicator", "Show the group leader crown and the assistant icon.", unit, "leaderIndicatorEnabled", true)
		Sync(p, "Apply Leader Indicator to all Frames", unit, { "leaderIndicatorEnabled" }, { "player", "target" })
		local function leaderOff() return S(unit).leaderIndicatorEnabled == false end
		Slider(p, "Leader Icon Size", "Size of the leader icon.", 8, 48, 1, unit, "leaderIndicatorSize", 16, leaderOff)
		p:Cog("Leader Indicator Settings", {
			CD("Icon Style", LEADER_STYLE, unit, "leaderIndicatorStyle", "blizzard", nil, "Art used for the leader crown and the assistant icon."),
			CD("Position", INDICATOR_POS, unit, "leaderIndicatorPosition", "topleft"),
			CS("X Offset", -200, 200, 1, unit, "leaderIndicatorX", 0),
			CS("Y Offset", -200, 200, 1, unit, "leaderIndicatorY", 0),
		}, { disabled = leaderOff })
	end
	if unit == "target" then
		Toggle(p, "Elite/Rare Indicator", "Marks elite, rare elite and rare targets; the Pixels Dragon style also marks players.", unit, "eliteIndicatorEnabled", false)
		local function eliteOff() return not S(unit).eliteIndicatorEnabled end
		local function eliteDragon() return eliteOff() or S(unit).eliteIndicatorStyle == "pixelsDragon" end
		p:Cog("Elite/Rare Indicator", {
			CT("Show in Instances", unit, "eliteIndicatorShowInInstances", false, nil, "Also show the badge in dungeons and raids, where most enemies are elite."),
		}, { disabled = eliteOff })
		Slider(p, "Elite Icon Size", "Size of the badge.", 8, 48, 1, unit, "eliteIndicatorSize", 16, eliteDragon)
		p:Cog("Elite/Rare Indicator Settings", {
			CD("Style", { { "badge", "Badge" }, { "pixelsDragon", "Pixels Dragon" } }, unit, "eliteIndicatorStyle", "badge", nil,
				"Badge shows a small icon; Pixels Dragon wraps the portrait in classification art (needs a shown portrait)."),
			CD("Position", INDICATOR_POS, unit, "eliteIndicatorPosition", "topleft", eliteDragon, "This option only applies to the Badge style."),
			CS("X Offset", -200, 200, 1, unit, "eliteIndicatorX", 0, eliteDragon),
			CS("Y Offset", -200, 200, 1, unit, "eliteIndicatorY", 0, eliteDragon),
		}, { disabled = eliteOff })
	end
	if unit == "player" or unit == "target" then
		local modes = unit == "target" and { { "off", "Off" }, { "always", "Always" }, { "opposite", "Opposite Faction" } } or { { "off", "Off" }, { "always", "On" } }
		Dropdown(p, "Faction Indicator", "A Horde / Alliance badge on the frame.", modes, unit, "factionIndicatorMode", "off")
		local function factionOff() return (S(unit).factionIndicatorMode or "off") == "off" end
		local rows = { CD("PvP Flag", FACTION_PVP, unit, "factionIndicatorPvP", unit == "player" and "only" or "dim") }
		if unit == "target" then
			rows[2] = CT("Players Only", unit, "factionIndicatorPlayersOnly", false, nil, "Hide the faction badge on faction NPCs such as guards.")
		end
		p:Cog("Faction Indicator", rows, { disabled = factionOff })
		Slider(p, "Faction Icon Size", "Size of the faction badge.", 8, 48, 1, unit, "factionIndicatorSize", 18, factionOff)
		Sync(p, "Apply Faction Icon Size to all Frames", unit, { "factionIndicatorSize" }, { "player", "target" })
		p:Cog("Faction Indicator Settings", {
			CD("Icon Style", FACTION_STYLE, unit, "factionIndicatorStyle", "classic"),
			CD("Position", INDICATOR_POS, unit, "factionIndicatorPosition", "topright"),
			CS("X Offset", -200, 200, 1, unit, "factionIndicatorX", 0),
			CS("Y Offset", -200, 200, 1, unit, "factionIndicatorY", 0),
		}, { disabled = factionOff })
	end
end

local function BuildMain(p)
	local unit = sel.main
	p:Section("Frame")
	UnitSelector(p, MAIN_LIST, "main")
	p:Blank()
	BuildDisplay(p, unit)
	BuildPortrait(p, unit)
	BuildHealth(p, unit, false)
	BuildPower(p, unit)
	BuildCast(p, unit)
	BuildTextBar(p, unit)
	BuildClassResource(p, unit)
	p:Section("Buffs and Debuffs")
	AuraRows(p, unit)
	BuildAbsorbs(p, unit)
	BuildExtras(p, unit)
end

---------------------------------------------------------------------------
-- Mini Frames (target of target / focus target / pet)
---------------------------------------------------------------------------
local function BuildMini(p)
	local unit = sel.mini
	p:Section("Frame")
	UnitSelector(p, MINI_LIST, "mini")
	local LOOK = { { "target", "Target" }, { "focus", "Focus" }, { "player", "Player" } }
	p:Dropdown("Copy Look From", "The main frame this frame copies its border, bar texture and hover highlight from.",
		function() return Items(LOOK) end,
		function() return S(unit).lookSource or "focus" end,
		function() return LabelOf(LOOK, S(unit).lookSource or "focus") end,
		function(v) S(unit).lookSource = v ~= "focus" and v or nil end)

	p:Section("Display")
	local labels = { targettarget = "Enable Target of Target", focustarget = "Enable Focus Target", pet = "Enable Pet Frame" }
	p:Toggle(labels[unit], "Turn this EllesmereUI frame on or off. Turning on a frame that was off may need a UI reload to hide Blizzard's frame.",
		function() return UF.db.enabledFrames[unit] ~= false end, function(v) UF.db.enabledFrames[unit] = v end)
	local sourceRows = {
		{ type = "dropdown", label = "Frame Source", tip = "EllesmereUI frame, or keep Blizzard's default frame. Needs a UI reload.",
			items = function() return Items({ { "eui", "EllesmereUI" }, { "blizzard", "Blizzard Default" } }) end,
			get = function() return UF.FrameSource(unit) end,
			set = function(v) UF.db.frameSource[unit] = v ~= "eui" and v or nil Reload() end },
	}
	if unit == "pet" then
		sourceRows[2] = { type = "toggle", label = "Always Show Pet Frame", tip = "Show the pet frame whenever you have a pet, ignoring its visibility settings.",
			get = function() return UF.db.pet.alwaysShow end, set = function(v) UF.db.pet.alwaysShow = v or nil end }
	end
	p:Cog("Frame Source", sourceRows)
	Toggle(p, "Show Portrait", "Show a portrait next to the bars.", unit, "showPortrait", false)
	local portraitRows = {
		{ type = "toggle", label = "Portrait on Right", get = function() return S(unit).portraitSide == "right" end,
			set = function(v) S(unit).portraitSide = v and "right" or "left" end },
	}
	if unit ~= "pet" then
		portraitRows[#portraitRows + 1] = { type = "dropdown", label = "Art Style", items = function() return Items({ { "2d", "2D Portrait" }, { "class", "Class" } }) end,
			get = function() return S(unit).portraitMode == "class" and "class" or "2d" end, set = function(v) S(unit).portraitMode = v end }
		portraitRows[#portraitRows + 1] = CD("Class Style", (function()
			local list = {}
			for _, key in ipairs(UF.CLASS_STYLE_ORDER) do
				list[#list + 1] = { key, UF.CLASS_STYLE_NAMES[key] }
			end
			return list
		end)(), unit, "classThemeStyle", "modern", function() return S(unit).portraitMode ~= "class" end)
		portraitRows[#portraitRows + 1] = CT("Custom Non-Player Portrait", unit, "portraitNonPlayerOn", false)
		portraitRows[#portraitRows + 1] = CD("Non-Player Portrait", { { "2d", "2D Portrait" }, { "none", "Nothing" } }, unit, "portraitNonPlayer", "2d",
			function() return S(unit).portraitMode ~= "class" or not S(unit).portraitNonPlayerOn end)
	end
	portraitRows[#portraitRows + 1] = CT("Mirror Portrait", unit, "portraitMirror", false)
	p:Cog("Portrait Settings", portraitRows, { disabled = function() return not S(unit).showPortrait end })
	BarTextureRow(p, unit, true, false)
	Dropdown(p, "Strata", "Overrides the Frame Strata set in the main frames for this frame only.", STRATA, unit, "frameStrata", "MEDIUM")
	p:Slider("Border Size", "Overrides the border size from the main frames for this frame only. Border color and texture still follow the main frames.",
		0, 4, 1, function() return S(unit).borderSizeOverride or UF.Donor(unit).borderSize or 1 end,
		function(v) S(unit).borderSizeOverride = v end)
	p:Toggle("Show Highlight Border", "Show the main frames' hover highlight border on this frame.",
		function() return S(unit).showHighlightBorder ~= false end, function(v) S(unit).showHighlightBorder = v end)
	VisibilityRow(p, unit)
	p:Blank()

	BuildHealth(p, unit, true)
	if unit == "pet" then
		p:Section("Power Bar")
		PowerRows(p, unit, false, false)
	end
end

---------------------------------------------------------------------------
-- Boss Frames
---------------------------------------------------------------------------
local function BuildBoss(p)
	local unit = "boss"
	p:WideButton(function() return UF.IsBossPreview() and "Deactivate Boss Preview" or "Activate Boss Preview" end,
		"Shows 5 sample boss frames so you can see your settings. Turns off in combat.",
		function() return UF.IsBossPreview() end,
		function() UF.SetBossPreview(not UF.IsBossPreview()) end)

	p:Section("Display")
	p:Toggle("Enable Boss Frames", "Turn the EllesmereUI boss frames on or off.",
		function() return UF.db.enabledFrames.boss ~= false end, function(v) UF.db.enabledFrames.boss = v end)
	p:Cog("Frame Source", {
		{ type = "dropdown", label = "Frame Source", tip = "EllesmereUI frames, or keep Blizzard's boss frames. Needs a UI reload.",
			items = function() return Items({ { "eui", "EllesmereUI" }, { "blizzard", "Blizzard Default" } }) end,
			get = function() return UF.FrameSource("boss") end,
			set = function(v) UF.db.frameSource.boss = v ~= "eui" and v or nil Reload() end },
	})
	Toggle(p, "Show Portrait", "Show a portrait next to the bars.", unit, "showPortrait", false)
	p:Cog("Portrait Settings", {
		{ type = "toggle", label = "Portrait on Right", get = function() return S(unit).portraitSide ~= "left" end,
			set = function(v) S(unit).portraitSide = v and "right" or "left" end },
		CT("Mirror Portrait", unit, "portraitMirror", false),
	}, { disabled = function() return not S(unit).showPortrait end })
	Dropdown(p, "Stack Direction", "Boss 2 to 5 go down or up from boss 1.", { { "up", "Up" }, { "down", "Down" } }, unit, "bossStackDirection", "down")
	p:Slider("Vertical Spacing", "Distance between the tops of two boss frames.", 0, 200, 1,
		function() return math.abs(UF.db.bossSpacing or 80) end, function(v) UF.db.bossSpacing = v end)
	BarTextureRow(p, unit, true, false)
	local hoverItems = { { value = "hover", name = "Hover Border" }, { value = "target", name = "Target Border" } }
	p:MultiSelect("Hover Borders", "Hover Border recolors the border on mouseover; Target Border recolors the border of the boss you target.",
		function() return hoverItems end,
		function(v) return S(unit)[v == "hover" and "bossHoverBorderEnabled" or "bossTargetBorderEnabled"] end,
		function(v)
			local key = v == "hover" and "bossHoverBorderEnabled" or "bossTargetBorderEnabled"
			S(unit)[key] = not S(unit)[key]
		end,
		function()
			local names = {}
			if S(unit).bossHoverBorderEnabled then names[#names + 1] = "Hover" end
			if S(unit).bossTargetBorderEnabled then names[#names + 1] = "Target" end
			return #names > 0 and table.concat(names, ", ") or "None"
		end)
	p:Swatch("Target", ColorGet(unit, "bossTargetBorderColor", 1, 1, 1), ColorSet(unit, "bossTargetBorderColor"),
		{ active = function() return S(unit).bossTargetBorderEnabled end })
	p:Swatch("Hover", ColorGet(unit, "bossHoverBorderColor", 1, 1, 1), ColorSet(unit, "bossHoverBorderColor"),
		{ active = function() return S(unit).bossHoverBorderEnabled end })
	local BORDER = { { "inherit", "Inherit (Main Frames)" }, { "solid", "Solid" } }
	p:Dropdown("Border Style", "Border drawn around the boss frames. Inherit (Main Frames) uses the main frames' border.",
		function() return Items(BORDER) end,
		function() return S(unit).borderCustom and "solid" or "inherit" end,
		function() return S(unit).borderCustom and "Solid" or "Inherit (Main Frames)" end,
		function(v) S(unit).borderCustom = v == "solid" end)
	local function inherit() return not S(unit).borderCustom end
	Slider(p, "Border Size", "Border size in pixels.", 0, 8, 1, unit, "borderSize", 1, inherit)
	p:Swatch("Border",
		function() local c = S(unit).borderColor or {} return c.r or 0, c.g or 0, c.b or 0, S(unit).borderAlpha or 1 end,
		function(r, g, b, a)
			local s = S(unit)
			s.borderColor = { r = r, g = g, b = b }
			if a then s.borderAlpha = a end
		end, { alpha = true, disabled = inherit })
	Dropdown(p, "Strata", "Overrides the Frame Strata set in the main frames for this frame only.", STRATA, unit, "frameStrata", "MEDIUM")
	p:Blank()

	p:Section("Buffs and Debuffs")
	local function simpleBuff() return UF.BossSimpleMode(S(unit).simpleBuffs, false) end
	local function simpleDebuff() return UF.BossSimpleMode(S(unit).simpleDebuffs, true) end
	p:Dropdown("Simple Buff Display", "Force boss buffs into a single large row matched to the frame height.",
		function() return Items(SIMPLE_DISPLAY) end, simpleBuff, function() return LabelOf(SIMPLE_DISPLAY, simpleBuff()) end,
		function(v)
			local s = S(unit)
			s.simpleBuffs = v
			if v ~= "none" then
				s.showBuffs = false
				if simpleDebuff() == v then
					s.simpleDebuffs = "none"
				end
			end
		end)
	p:Cog("Simple Buff Position", {
		CS("Max Count", 1, 20, 1, unit, "maxBuffs", 4),
		CS("Offset X", -200, 200, 1, unit, "simpleBuffOffsetX", 0),
		CS("Offset Y", -200, 200, 1, unit, "simpleBuffOffsetY", 0),
		CS("Spacing", -1, 10, 1, unit, "simpleBuffSpacing", 1),
		CT("Show Duration", unit, "simpleBuffShowCooldownText", false),
		CS("Duration Size", 6, 100, 1, unit, "simpleBuffCooldownTextSize", 14),
		CS("Duration X", -100, 100, 1, unit, "simpleBuffCooldownTextOffsetX", 0),
		CS("Duration Y", -100, 100, 1, unit, "simpleBuffCooldownTextOffsetY", 0),
		CS("Stack X", -100, 100, 1, unit, "buffStackTextOffsetX", 0),
		CS("Stack Y", -100, 100, 1, unit, "buffStackTextOffsetY", 0),
		CS("Zoom", 0, 0.2, 0.01, unit, "buffIconZoom", 0.07),
	}, { icon = "directions", disabled = function() return simpleBuff() == "none" end })
	p:Dropdown("Simple Debuff Display", "Anchor boss debuffs beside the frame, with the base icon size matched to its height. Debuff Growth Direction controls how the icons extend.",
		function() return Items(SIMPLE_DISPLAY) end, simpleDebuff, function() return LabelOf(SIMPLE_DISPLAY, simpleDebuff()) end,
		function(v)
			local s = S(unit)
			s.simpleDebuffs = v
			if v ~= "none" then
				s.debuffAnchor = "none"
				if simpleBuff() == v then
					s.simpleBuffs = "none"
				end
			end
		end)
	p:Cog("Simple Debuff Position", {
		CS("Max Count", 1, 20, 1, unit, "maxDebuffs", 10),
		CS("Offset X", -200, 200, 1, unit, "simpleDebuffOffsetX", 0),
		CS("Offset Y", -200, 200, 1, unit, "simpleDebuffOffsetY", 0),
		CS("Spacing", -1, 10, 1, unit, "simpleDebuffSpacing", 1),
		CT("Show Duration", unit, "simpleDebuffShowCooldownText", false),
		CS("Duration Size", 6, 100, 1, unit, "simpleDebuffCooldownTextSize", 14),
		CS("Duration X", -100, 100, 1, unit, "simpleDebuffCooldownTextOffsetX", 0),
		CS("Duration Y", -100, 100, 1, unit, "simpleDebuffCooldownTextOffsetY", 0),
		CS("Stack X", -100, 100, 1, unit, "debuffStackTextOffsetX", 0),
		CS("Stack Y", -100, 100, 1, unit, "debuffStackTextOffsetY", 0),
		CS("Zoom", 0, 0.2, 0.01, unit, "debuffIconZoom", 0.07),
	}, { icon = "directions", disabled = function() return simpleDebuff() == "none" end })

	local function buffOff() return simpleBuff() ~= "none" or S(unit).showBuffs == false end
	local function debuffOff() return simpleDebuff() ~= "none" or (S(unit).debuffAnchor or "bottomleft") == "none" end
	p:Dropdown("Buffs Location", "Where the buffs are (when Simple Buff Display is None).", function() return Items(AURA_ANCHOR) end,
		function() return S(unit).showBuffs == false and "none" or (S(unit).buffAnchor or "topleft") end,
		function() return LabelOf(AURA_ANCHOR, S(unit).showBuffs == false and "none" or (S(unit).buffAnchor or "topleft")) end,
		function(v)
			if v == "none" then
				S(unit).showBuffs = false
			else
				S(unit).showBuffs = true
				S(unit).buffAnchor = v
			end
		end, nil, function() return simpleBuff() ~= "none" end)
	p:Cog("Buff Settings", {
		CD("Growth Direction", AURA_GROWTH, unit, "buffGrowth", "auto"),
		CS("Max Count", 1, 20, 1, unit, "maxBuffs", 4),
		{ type = "slider", label = "Max Per Row", min = 1, max = 20, step = 1,
			get = function() return S(unit).buffMaxPerRow or S(unit).maxBuffs or 4 end, set = function(v) S(unit).buffMaxPerRow = v end },
		CT("Dispel Type Borders", unit, "buffDispelBorder", false),
		CS("Size", 10, 70, 1, unit, "buffSize", 22),
		CS("Offset X", -200, 200, 1, unit, "buffOffsetX", 0),
		CS("Offset Y", -200, 200, 1, unit, "buffOffsetY", 0),
		CS("Spacing", -1, 10, 1, unit, "buffSpacing", 1),
		CT("Show Duration", unit, "buffShowCooldownText", false),
		CS("Duration Size", 6, 100, 1, unit, "buffCooldownTextSize", 10),
		CS("Stack X", -100, 100, 1, unit, "buffStackTextOffsetX", 0),
		CS("Stack Y", -100, 100, 1, unit, "buffStackTextOffsetY", 0),
		CS("Zoom", 0, 0.2, 0.01, unit, "buffIconZoom", 0.07),
	}, { disabled = buffOff })
	p:Dropdown("Debuffs Location", "Where the debuffs are (when Simple Debuff Display is None).", function() return Items(AURA_ANCHOR) end,
		function() return S(unit).debuffAnchor or "bottomleft" end,
		function() return LabelOf(AURA_ANCHOR, S(unit).debuffAnchor or "bottomleft") end,
		function(v) S(unit).debuffAnchor = v end, nil, function() return simpleDebuff() ~= "none" end)
	p:Cog("Debuff Settings", {
		CS("Max Count", 1, 20, 1, unit, "maxDebuffs", 10),
		{ type = "slider", label = "Max Per Row", min = 1, max = 20, step = 1,
			get = function() return S(unit).debuffMaxPerRow or S(unit).maxDebuffs or 10 end, set = function(v) S(unit).debuffMaxPerRow = v end },
		CT("Dispel Type Borders", unit, "debuffDispelBorder", false),
		CS("Size", 10, 70, 1, unit, "debuffSize", 22),
		CS("Offset X", -200, 200, 1, unit, "debuffOffsetX", 0),
		CS("Offset Y", -200, 200, 1, unit, "debuffOffsetY", 0),
		CS("Spacing", -1, 10, 1, unit, "debuffSpacing", 1),
		CT("Show Duration", unit, "debuffShowCooldownText", false),
		CS("Duration Size", 6, 100, 1, unit, "debuffCooldownTextSize", 10),
		CS("Stack X", -100, 100, 1, unit, "debuffStackTextOffsetX", 0),
		CS("Stack Y", -100, 100, 1, unit, "debuffStackTextOffsetY", 0),
		CS("Zoom", 0, 0.2, 0.01, unit, "debuffIconZoom", 0.07),
	}, { disabled = debuffOff })
	DebuffBehaviorRows(p, unit, function()
		return simpleDebuff() == "none" and (S(unit).debuffAnchor or "bottomleft") == "none"
	end)
	p:Slider("Stack Size", "Size of the stack number on buffs and debuffs.", 6, 100, 1,
		function() return S(unit).debuffStackTextSize or 14 end,
		function(v) S(unit).debuffStackTextSize = v S(unit).buffStackTextSize = v end)
	p:Cog("Stack Position", {
		{ type = "dropdown", label = "Position", items = function() return Items(STACK_POS) end,
			get = function() return S(unit).debuffStackTextPosition or "bottomright" end,
			set = function(v) S(unit).debuffStackTextPosition = v S(unit).buffStackTextPosition = v end },
	}, { icon = "directions" })
	p:Slider("Aura Border Size", "Border of the aura icons, in pixels.", 0, 8, 1, Get(unit, "auraBorderSize", 1), Set(unit, "auraBorderSize"))
	p:Swatch("Aura Border Color",
		function() local s = S(unit) return s.auraBorderR or 0, s.auraBorderG or 0, s.auraBorderB or 0, s.auraBorderA or 1 end,
		function(r, g, b, a) local s = S(unit) s.auraBorderR, s.auraBorderG, s.auraBorderB = r, g, b if a then s.auraBorderA = a end end,
		{ alpha = true })
	p:Dropdown("Boss Debuff Filter", "Which debuffs are shown. 5.4.8 has no 'important' flag: Important means debuffs flagged as boss debuffs.",
		function() return DebuffModeItems(unit) end,
		function() return UF.DebuffFilterMode(S(unit)) end,
		function() return LabelOf(DEBUFF_MODE, UF.DebuffFilterMode(S(unit))) end,
		function(v) S(unit).debuffFilterMode = v end)
	p:Cog("Debuff Filter", { CT("Has Duration", unit, "debuffHasDuration", false), HideExhaustionRow(unit) })
	local buffClasses = { { "DurOnly", "Has Duration" }, { "Stealable", "Stealable" }, { "Dispellable", "Dispellable" } }
	p:MultiSelect("Boss Buff Filter", "Nothing checked shows every buff.",
		function()
			local items = {}
			for i, c in ipairs(buffClasses) do
				items[i] = { value = c[1], name = c[2] }
			end
			return items
		end,
		function(v) return S(unit)["buff" .. v] end,
		function(v) S(unit)["buff" .. v] = not S(unit)["buff" .. v] or nil end,
		function()
			local names = {}
			for _, c in ipairs(buffClasses) do
				if S(unit)["buff" .. c[1]] then
					names[#names + 1] = c[2]
				end
			end
			return #names > 0 and table.concat(names, ", ") or "All Buffs"
		end)

	BuildHealth(p, unit, true)
	p:Section("Power Bar")
	PowerRows(p, unit, false, false)
	p:Section("Cast Bar")
	CastRows(p, unit)

	p:Section("Indicators")
	p:Slider("Out of Range Alpha", "Fades boss frames that are out of your spell range. 100 turns it off.", 10, 100, 1,
		function() return floor((S(unit).oorAlpha or 0.4) * 100 + 0.5) end, function(v) S(unit).oorAlpha = v / 100 end)
	Toggle(p, "Spell Target", "Show the name of who the boss is casting on (5.4.8: the boss's target when the cast starts).", unit, "showCastTarget", false)
	p:Cog("Spell Target", {
		CS("X Offset", -300, 300, 1, unit, "castSpellTargetX", 0),
		CS("Y Offset", -300, 300, 1, unit, "castSpellTargetY", 0),
	})
	Toggle(p, "Show Raid Marker", "Show the raid target icon next to the boss frame.", unit, "raidMarkerEnabled", true)
	p:Cog("Raid Marker Position", {
		CS("X Offset", -50, 50, 1, unit, "raidMarkerX", 0),
		CS("Y Offset", -50, 50, 1, unit, "raidMarkerY", 0),
		CD("Alignment", ALIGN, unit, "raidMarkerAlign", "left"),
	}, { icon = "directions" })
	Slider(p, "Raid Marker Size", "Size of the raid target icon.", 12, 48, 1, unit, "raidMarkerSize", 28, function() return not S(unit).raidMarkerEnabled end)
end

---------------------------------------------------------------------------
-- Content header (retail): "Edit Frame" dropdown and a live preview of the
-- selected frame, built by the unit frame code itself with sample data.
---------------------------------------------------------------------------
local headerPreviews = {}   -- unit key -> preview frame (reused across rebuilds)

local function PreviewHeader(list, which, fixedUnit)
	return function(page, host, width)
		local DD_H, DD_W, MAX_H = 34, 350, 260
		local top = 20
		local unit = fixedUnit or sel[which]
		if list then
			local dd = page:HeaderDropdown(host, DD_W, DD_H, function() return Items(list) end,
				function() return sel[which] end, function() return LabelOf(list, sel[which]) end,
				function(v)
					sel[which] = v
					if ns.RebuildSettingsPage then
						ns.RebuildSettingsPage()
					end
				end)
			dd:SetPoint("TOP", host, "TOP", 0, -top)
			top = top + DD_H + 20
		end
		local pv = headerPreviews[unit]
		if not pv then
			if InCombatLockdown() then
				return top
			end
			pv = UF.CreateHeaderPreview(unit, host)
			headerPreviews[unit] = pv
		end
		pv:SetParent(host)
		pv:Show()
		local function Relayout()
			if InCombatLockdown() then return end
			pv:SetScale(1)
			pv:ClearAllPoints()
			pv:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -top)
			UF.LayoutHeaderPreview(pv)
			local fw, fh = pv:GetSize()
			local bl, bt, bw, bh = UF.HeaderPreviewBounds(pv)
			if not bl then bl, bt, bw, bh = 0, 0, fw, fh end
			local scale = math.min(1, (width - 40) / math.max(1, bw), MAX_H / math.max(1, bh))
			pv:SetScale(scale)
			pv:ClearAllPoints()
			pv:SetPoint("TOPLEFT", host, "TOPLEFT",
				(width - bw * scale) / 2 / scale - bl, -top / scale - bt)
			return top + bh * scale + 20
		end
		page:OnRefresh(function()
			if host:IsVisible() and pv:GetParent() == host then
				local h = Relayout()
				if h then page:SetHeaderHeight(h) end
			end
		end)
		-- Sizes are known once the window shows: measure again then.
		host:HookScript("OnShow", function()
			if pv:GetParent() == host then
				local h = Relayout()
				if h then page:SetHeaderHeight(h) end
			end
		end)
		return Relayout() or top
	end
end

local UF_PAGES = {
	{
		key = "mainFrames",
		name = "Main Frames",
		description = "Configure unit frame appearance and behavior.",
		pageKey = function() return sel.main end,
		build = BuildMain,
		header = PreviewHeader(MAIN_LIST, "main"),
	},
	{
		key = "bossFrames",
		name = "Boss Frames",
		description = "Configure unit frame appearance and behavior.",
		build = BuildBoss,
		header = PreviewHeader(nil, nil, "boss"),
	},
	{
		key = "miniFrames",
		name = "Mini Frames",
		description = "Configure unit frame appearance and behavior.",
		pageKey = function() return sel.mini end,
		build = BuildMini,
		header = PreviewHeader(MINI_LIST, "mini"),
	},
}
-- Player Aura Bars (EUI_PlayerAuraBars_Options.lua), the retail fourth tab.
if ns.PAB_OptionsTab then
	UF_PAGES[#UF_PAGES + 1] = ns.PAB_OptionsTab
end

ns.RegisterSettingsModule({
	-- EllesmereUI: Core Addons > Unit Frames.
	key = "unitFrames",
	name = "Unit Frames",
	group = "Core Addons",
	tabs = UF_PAGES,
	reset = function() ns.ResetUnitFrameSettings() end,
	resetTip = "Set all Unit Frames settings back to default. Frame positions are kept.",
	onEnter = function() if UF.db then UF.SetPreview(true) end end,
	onLeave = function()
		if UF.db then
			UF.SetPreview(false)
			UF.SetBossPreview(false)
		end
	end,
})
