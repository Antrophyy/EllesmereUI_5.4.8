-- Settings pages of Damage Meters (same place and options as EllesmereUI):
-- "Damage Meters" (the meter windows; numbers from Details!) and "Spell History".
-- Part of EllesmereUIOptions (load on demand); skipped when EllesmereUIDamageMeters is not loaded.

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUIDamageMeters") then
	return
end

local U = ns.OptionsUtil
local KeyItems, KeyLabel, MediaItems = U.KeyItems, U.KeyLabel, U.MediaItems
local floor = math.floor
local format = format

---------------------------------------------------------------------------
-- Damage Meters page (retail EUI_DamageMeters_Options "Damage Meters")
---------------------------------------------------------------------------
local DM = ns.EDM

local function Cfg(k)
	return DM.DB()[k]
end
local function Set(k, v)
	DM.DB()[k] = v
end
local function Col(k, dr, dg, db)
	return DM.RGB(Cfg(k), dr, dg, db)
end
local function SetCol(k, r, g, b, a)
	local c = Cfg(k)
	if type(c) ~= "table" then
		c = {}
		Set(k, c)
	end
	c.r, c.g, c.b = r, g, b
	if a ~= nil and c.a ~= nil then c.a = a end
end
local function ColA(k)
	local c = Cfg(k) or {}
	return c.r or 0, c.g or 0, c.b or 0, c.a or 1
end
local function SetColA(k, r, g, b, a)
	Set(k, { r = r, g = g, b = b, a = a or 1 })
end

-- Accent / custom swatch pair (retail inline accent swatches). useKey true = accent.
local function AccentSwatches(p, useKey, colorKey, defaultAccent, isDisabled)
	local function UseAccent()
		local v = Cfg(useKey)
		if v == nil then return defaultAccent end
		return v and true or false
	end
	p:Swatch("Accent Color", function() return DM.Accent() end, function() end, {
		active = UseAccent,
		onClick = function() Set(useKey, true); return true end,
		readonly = true,
		disabled = isDisabled,
	})
	p:Swatch("Custom Color", function() return Col(colorKey, 1, 1, 1) end,
		function(r, g, b) SetCol(colorKey, r, g, b) end, {
			active = function() return not UseAccent() end,
			onClick = function()
				if UseAccent() then
					Set(useKey, false)
					return true
				end
				return false
			end,
			disabled = isDisabled,
		})
end

-- Class / custom swatch pair (Left / Right Text). useKey true = class color.
local function ClassSwatches(p, useKey, colorKey)
	p:Swatch("Custom Color", function() return Col(colorKey, 1, 1, 1) end,
		function(r, g, b) SetCol(colorKey, r, g, b) end, {
			active = function() return not Cfg(useKey) end,
			onClick = function()
				if Cfg(useKey) then
					Set(useKey, false)
					return true
				end
				return false
			end,
		})
	p:Swatch("Class Color", function() return ns.GetPlayerClassColor() end, function() end, {
		active = function() return Cfg(useKey) and true or false end,
		onClick = function() Set(useKey, true); return true end,
		readonly = true,
	})
end

local NUMBER_FORMATS = {
	{ key = 0, text = "DPS" },
	{ key = 1, text = "Damage" },
	{ key = 2, text = "Damage (DPS)" },
	{ key = 3, text = "Damage | DPS" },
}
local ANCHORS = {
	{ key = "row", text = "Above Hovered Row" },
	{ key = "center", text = "Center of Screen" },
	{ key = "left", text = "Left of Window" },
	{ key = "right", text = "Right of Window" },
}
local TIMER_ANCHORS = {
	{ key = "free", text = "Free Move" },
	{ key = "topleft", text = "Top Left" },
	{ key = "topright", text = "Top Right" },
	{ key = "bottomleft", text = "Bottom Left" },
	{ key = "bottomright", text = "Bottom Right" },
}
local OUTLINES = {
	{ key = "INHERIT", text = "Default" },
	{ key = "NONE", text = "None" },
	{ key = "OUTLINE", text = "Thin" },
	{ key = "THICKOUTLINE", text = "Thick" },
}
local ALIGNS = {
	{ key = "LEFT", text = "Left" },
	{ key = "CENTER", text = "Center" },
	{ key = "RIGHT", text = "Right" },
}
local STRATAS = {
	{ key = "BACKGROUND", text = "Background" },
	{ key = "LOW", text = "Low" },
	{ key = "MEDIUM", text = "Medium" },
	{ key = "HIGH", text = "High" },
	{ key = "DIALOG", text = "Dialog" },
}

local function TexItems() return DM.TextureItems() end
local TEX_OPTS = { texturePreview = true, previewPath = function(v) return DM.TexturePath(v) end }

local function IconStyleItems()
	local items = {}
	for _, k in ipairs(DM.ICON_STYLE_ORDER) do
		items[#items + 1] = { name = DM.ICON_STYLE_NAMES[k], value = k }
	end
	return items
end

local function BuildMeterPage(p)
	-- DISPLAY
	p:Section("DISPLAY")
	if not DM.Details() then
		p:Paragraph("Details! is required: the meter windows take their numbers from the Details! addon. Enable Details! and reload.")
	end
	p:Dropdown("Visibility", "When the meter windows are shown. Per-window rules (dungeons, raids, PvP) are in each window's settings menu.",
		function() return KeyItems(DM.VISIBILITY) end,
		function() return Cfg("visibility") or "always" end,
		function() return KeyLabel(DM.VISIBILITY, Cfg("visibility") or "always") end,
		function(v) Set("visibility", v) end)
	p:Slider("Refresh Rate (seconds)", "Increase to improve performance, Decrease to update meters faster", 0.5, 2, 0.1,
		function() return Cfg("refreshRate") or 1 end,
		function(v) Set("refreshRate", floor(v * 10 + 0.5) / 10) end)

	p:Slider("Border Size", "Width of the window border in pixels. 5.4.8 draws a solid border only.", 0, 4, 1,
		function() return Cfg("windowBorderSize") or 0 end,
		function(v) Set("windowBorderSize", v) end)
	p:Swatch("Border Color", function() return ColA("windowBorderColor") end,
		function(r, g, b, a) SetColA("windowBorderColor", r, g, b, a) end, { alpha = true })
	p:Cog("Border Options", {
		{ type = "toggle", label = "Include Headerbar",
			get = function() return Cfg("windowBorderIncludeHeader") ~= false end,
			set = function(v) Set("windowBorderIncludeHeader", v) end },
		{ type = "toggle", label = "Show Behind",
			get = function() return Cfg("windowBorderBehind") or false end,
			set = function(v) Set("windowBorderBehind", v) end },
	})
	p:Slider("Background Opacity", "Opacity of the window background.", 0, 100, 1,
		function() return floor((Cfg("bgAlpha") or 0.75) * 100 + 0.5) end,
		function(v) Set("bgAlpha", v / 100) end)
	p:Swatch("Background Color", function() return Cfg("bgR") or 0, Cfg("bgG") or 0, Cfg("bgB") or 0 end,
		function(r, g, b) Set("bgR", r); Set("bgG", g); Set("bgB", b) end)

	p:Toggle("Always Show Player", "This will pin your bar to the window when it is not within the visible area",
		function() return Cfg("showPinnedSelf") ~= false end,
		function(v) Set("showPinnedSelf", v) end)
	p:Keybind("Reset Data Keybind", "Left-click to set a keybind.\nRight-click to unbind.\nResets the Details! data.",
		function() return Cfg("resetDataKey") end,
		function(v) Set("resetDataKey", v) end)
	p:Cog("Reset Button", {
		{ type = "toggle", label = "Hide Reset Button",
			get = function() return Cfg("hideResetButton") == true end,
			set = function(v) Set("hideResetButton", v) end },
	})
	p:Toggle("Hide Details! Windows", "The meter windows take their numbers from Details!. Turn this on to hide the Details! windows (turning it off shows them again).",
		function() return Cfg("hideDetailsWindows") == true end,
		function(v) Set("hideDetailsWindows", v) end)

	-- HEADER
	p:Section("HEADER")
	p:Slider("Header Height", nil, 14, 40, 1,
		function() return Cfg("hdrHeight") or 22 end,
		function(v) Set("hdrHeight", v) end)
	p:Slider("Opacity", "Opacity of the header background.", 0, 100, 1,
		function() return floor((Cfg("hdrBgAlpha") or 1) * 100 + 0.5) end,
		function(v) Set("hdrBgAlpha", v / 100) end)
	p:Swatch("Header Color", function() return Col("hdrBgColor", 0x1B / 255, 0x1B / 255, 0x1B / 255) end,
		function(r, g, b) SetCol("hdrBgColor", r, g, b) end)
	p:Slider("Header Bottom Border", nil, 0, 4, 1,
		function() return Cfg("hdrBottomBorderSize") or 0 end,
		function(v) Set("hdrBottomBorderSize", v) end)
	p:Swatch("Border Color", function() return ColA("hdrBottomBorderColor") end,
		function(r, g, b, a) SetColA("hdrBottomBorderColor", r, g, b, a) end,
		{ alpha = true, disabled = function() return (Cfg("hdrBottomBorderSize") or 0) <= 0 end })
	p:Slider("Icon Size", nil, 20, 30, 1,
		function() return Cfg("hdrIconSize") or 22 end,
		function(v) Set("hdrIconSize", v) end)
	AccentSwatches(p, "iconColorUseAccent", "iconColor", false)
	p:Cog("Icon Visibility", {
		{ type = "toggle", label = "Mouseover Icons",
			get = function() return Cfg("hdrMouseoverIcons") or false end,
			set = function(v) Set("hdrMouseoverIcons", v) end },
	})
	p:Slider("Text Size", nil, 8, 18, 1,
		function() return Cfg("hdrFontSize") or 11 end,
		function(v) Set("hdrFontSize", v) end)
	AccentSwatches(p, "hdrTextUseAccent", "hdrTextColor", true)
	p:Cog("Text Position", {
		{ type = "slider", label = "X Offset", min = -20, max = 20, step = 1,
			get = function() return Cfg("hdrTextOffX") or 0 end,
			set = function(v) Set("hdrTextOffX", v) end },
		{ type = "slider", label = "Y Offset", min = -20, max = 20, step = 1,
			get = function() return Cfg("hdrTextOffY") or 0 end,
			set = function(v) Set("hdrTextOffY", v) end },
	})
	p:Blank()

	-- BARS
	p:Section("BARS")
	p:Dropdown("Bar Texture", "Texture of the bars. Textures from LibSharedMedia are listed too.", TexItems,
		function() return Cfg("barTexture") or "none" end,
		function() return DM.TextureLabel(Cfg("barTexture")) end,
		function(v) Set("barTexture", v) end, TEX_OPTS)
	p:Slider("Bar Height", nil, 8, 40, 1,
		function() return Cfg("barHeight") or 18 end,
		function(v) Set("barHeight", v) end)
	p:Label("Color", "Class Color, Custom Color or Accent Color for the bars.")
	p:Swatch("Accent Color", function() return DM.Accent() end, function() end, {
		active = function() return Cfg("showClassColor") == false and Cfg("barColorUseAccent") ~= false end,
		onClick = function() Set("showClassColor", false); Set("barColorUseAccent", true); return true end,
		readonly = true,
	})
	p:Swatch("Custom Color", function() return Col("barColor", 0.35, 0.55, 0.8) end,
		function(r, g, b) SetCol("barColor", r, g, b) end, {
			active = function() return Cfg("showClassColor") == false and Cfg("barColorUseAccent") == false end,
			onClick = function()
				if Cfg("showClassColor") ~= false or Cfg("barColorUseAccent") ~= false then
					Set("showClassColor", false); Set("barColorUseAccent", false)
					return true
				end
				return false
			end,
		})
	p:Swatch("Class Color", function() return ns.GetPlayerClassColor() end, function() end, {
		active = function() return Cfg("showClassColor") ~= false end,
		onClick = function() Set("showClassColor", true); return true end,
		readonly = true,
	})
	p:Slider("Opacity", "Opacity of the bar fill.", 0, 100, 1,
		function() return floor((Cfg("barFillAlpha") or 1) * 100 + 0.5) end,
		function(v) Set("barFillAlpha", v / 100) end)
	p:Slider("Spacing", "Space between the bars in pixels.", -1, 10, 1,
		function() return Cfg("barSpacing") or 2 end,
		function(v) Set("barSpacing", v) end)
	p:Dropdown("Icon Style", "Icon left of each bar.", IconStyleItems,
		function() return Cfg("iconStyle") or "spec" end,
		function() return DM.ICON_STYLE_NAMES[Cfg("iconStyle") or "spec"] or "?" end,
		function(v) Set("iconStyle", v) end)
	p:Cog("Icon", {
		{ type = "slider", label = "Zoom %", min = 0, max = 20, step = 1,
			disabled = function() local s = Cfg("iconStyle") or "spec"; return s ~= "spec" and s ~= "blizzard" end,
			get = function() return floor((Cfg("classIconZoom") or 0.06) * 100 + 0.5) end,
			set = function(v) Set("classIconZoom", v / 100) end },
	})
	p:Slider("Border Size", "Border around each bar in pixels. 5.4.8 draws a solid border only.", 0, 4, 1,
		function() return Cfg("borderSize") or 0 end,
		function(v) Set("borderSize", v) end)
	p:Swatch("Border Color", function() return Cfg("borderR") or 0, Cfg("borderG") or 0, Cfg("borderB") or 0, Cfg("borderA") or 1 end,
		function(r, g, b, a) Set("borderR", r); Set("borderG", g); Set("borderB", b); Set("borderA", a or 1) end,
		{ alpha = true })
	p:Cog("Border Options", {
		{ type = "toggle", label = "Custom Icon Border",
			get = function() return Cfg("customIconBorder") or false end,
			set = function(v) Set("customIconBorder", v) end },
	})
	if Cfg("customIconBorder") then
		p:Slider("Icon Border Size", nil, 0, 4, 1,
			function() return Cfg("iconBorderSize") or 0 end,
			function(v) Set("iconBorderSize", v) end)
		p:Swatch("Icon Border Color", function() return Cfg("iconBorderR") or 0, Cfg("iconBorderG") or 0, Cfg("iconBorderB") or 0, Cfg("iconBorderA") or 1 end,
			function(r, g, b, a) Set("iconBorderR", r); Set("iconBorderG", g); Set("iconBorderB", b); Set("iconBorderA", a or 1) end,
			{ alpha = true })
		p:Blank()
	end
	p:Toggle("Show Breakdown on Hover", "Shows the spells (or sources) of a bar while you hover it. Click a bar to open its breakdown in the window.",
		function() return Cfg("showHoverTooltip") ~= false end,
		function(v) Set("showHoverTooltip", v) end)
	p:Cog("Breakdown", {
		{ type = "dropdown", label = "Bar Texture", items = function() return DM.TextureItems(true) end,
			get = function() return Cfg("breakdownBarTexture") or "match" end,
			labelFn = function()
				local v = Cfg("breakdownBarTexture") or "match"
				return v == "match" and "Match Damage Meters" or DM.TextureLabel(v)
			end,
			set = function(v) Set("breakdownBarTexture", v) end },
		{ type = "slider", label = "Scale", min = 80, max = 150, step = 1,
			get = function() return Cfg("hoverTooltipScale") or 100 end,
			set = function(v) Set("hoverTooltipScale", v) end },
		{ type = "dropdown", label = "Anchor", items = function() return KeyItems(ANCHORS) end,
			get = function() return Cfg("breakdownAnchorPoint") or "row" end,
			labelFn = function() return KeyLabel(ANCHORS, Cfg("breakdownAnchorPoint") or "row") end,
			set = function(v) Set("breakdownAnchorPoint", v) end },
		{ type = "toggle", label = "Show More Spells", tip = "Show top 15 entries instead of 8.",
			get = function() return Cfg("showAllBreakdownSpells") ~= false end,
			set = function(v) Set("showAllBreakdownSpells", v) end },
	}, { disabled = function() return Cfg("showHoverTooltip") == false end })
	p:Slider("Background", "Opacity of the track behind each bar.", 0, 100, 1,
		function() return floor((Cfg("barBgAlpha") or 0) * 100 + 0.5) end,
		function(v) Set("barBgAlpha", v / 100) end)
	p:Swatch("Custom Color", function() return Cfg("barBgR") or 0, Cfg("barBgG") or 0, Cfg("barBgB") or 0 end,
		function(r, g, b) Set("barBgR", r); Set("barBgG", g); Set("barBgB", b) end, {
			active = function() return not Cfg("barBgUseClassColor") end,
			onClick = function()
				if Cfg("barBgUseClassColor") then Set("barBgUseClassColor", false); return true end
				return false
			end,
		})
	p:Swatch("Class Color", function() return ns.GetPlayerClassColor() end, function() end, {
		active = function() return Cfg("barBgUseClassColor") and true or false end,
		onClick = function() Set("barBgUseClassColor", true); return true end,
		readonly = true,
	})

	-- BAR TEXT
	p:Section("BAR TEXT")
	p:Dropdown("Number Format", nil, function() return KeyItems(NUMBER_FORMATS) end,
		function() return Cfg("numberFormat") or 2 end,
		function() return KeyLabel(NUMBER_FORMATS, Cfg("numberFormat") or 2) end,
		function(v) Set("numberFormat", v) end)
	p:Toggle("Hide Rank Numbers", "Hides the rank number (1. 2. 3.) before each player name.",
		function() return Cfg("hideNumbers") or false end,
		function(v) Set("hideNumbers", v) end)
	p:Slider("Left Text Size", nil, 8, 18, 1,
		function() return Cfg("leftFontSize") or Cfg("fontSize") or 11 end,
		function(v) Set("leftFontSize", v) end)
	ClassSwatches(p, "leftTextUseClassColor", "leftTextColor")
	p:Cog("Left Text", {
		{ type = "slider", label = "X Offset", min = -20, max = 20, step = 1,
			get = function() return Cfg("leftTextOffsetX") or 0 end,
			set = function(v) Set("leftTextOffsetX", v) end },
		{ type = "slider", label = "Y Offset", min = -20, max = 20, step = 1,
			get = function() return Cfg("leftTextOffsetY") or 0 end,
			set = function(v) Set("leftTextOffsetY", v) end },
	})
	p:Slider("Right Text Size", nil, 8, 18, 1,
		function() return Cfg("rightFontSize") or Cfg("fontSize") or 11 end,
		function(v) Set("rightFontSize", v) end)
	ClassSwatches(p, "rightTextUseClassColor", "rightTextColor")
	p:Cog("Right Text", {
		{ type = "slider", label = "X Offset", min = -20, max = 20, step = 1,
			get = function() return Cfg("rightTextOffsetX") or 0 end,
			set = function(v) Set("rightTextOffsetX", v) end },
		{ type = "slider", label = "Y Offset", min = -20, max = 20, step = 1,
			get = function() return Cfg("rightTextOffsetY") or 0 end,
			set = function(v) Set("rightTextOffsetY", v) end },
	})

	-- STANDALONE COMBAT TIMER
	p:Section("STANDALONE COMBAT TIMER")
	local function timerOff() return not Cfg("standaloneTimer") end
	p:Toggle("Standalone Combat Timer", "A separate combat timer. Move it in Unlock Mode, or Shift+drag it.",
		function() return Cfg("standaloneTimer") or false end,
		function(v) Set("standaloneTimer", v) end)
	p:Label("Timer Text Color", nil, timerOff)
	AccentSwatches(p, "standaloneTimerUseAccent", "standaloneTimerColor", false, timerOff)
	p:Cog("Timer", {
		{ type = "slider", label = "Font Size", min = 10, max = 40, step = 1,
			get = function() return Cfg("standaloneTimerSize") or 26 end,
			set = function(v) Set("standaloneTimerSize", v) end },
		{ type = "dropdown", label = "Font Outline", items = function() return KeyItems(OUTLINES) end,
			get = function() return Cfg("standaloneTimerOutline") or "INHERIT" end,
			labelFn = function() return KeyLabel(OUTLINES, Cfg("standaloneTimerOutline") or "INHERIT") end,
			set = function(v) Set("standaloneTimerOutline", v) end },
		{ type = "dropdown", label = "Alignment", items = function() return KeyItems(ALIGNS) end,
			get = function()
				local a = Cfg("standaloneTimerTextAlign")
				if a then return a end
				if (Cfg("standaloneTimerAnchor") or "free") == "free" then return "CENTER" end
				return Cfg("standaloneTimerAlignLeft") and "LEFT" or "RIGHT"
			end,
			set = function(v) Set("standaloneTimerTextAlign", v) end },
		{ type = "toggle", label = "Show Decimal",
			get = function() return Cfg("standaloneTimerDecimal") or false end,
			set = function(v) Set("standaloneTimerDecimal", v) end },
		{ type = "slider", label = "Frame Width", min = 40, max = 200, step = 1,
			get = function() return Cfg("standaloneTimerWidth") or 70 end,
			set = function(v) Set("standaloneTimerWidth", v) end },
		{ type = "slider", label = "Frame Height", min = 20, max = 80, step = 1,
			get = function() return Cfg("standaloneTimerHeight") or 32 end,
			set = function(v) Set("standaloneTimerHeight", v) end },
		{ type = "color", label = "Background Color", alpha = true,
			get = function() return ColA("standaloneTimerBackgroundColor") end,
			set = function(r, g, b, a) SetColA("standaloneTimerBackgroundColor", r, g, b, a) end },
		{ type = "color", label = "Border Color", alpha = true,
			get = function() return ColA("standaloneTimerBorderColor") end,
			set = function(r, g, b, a) SetColA("standaloneTimerBorderColor", r, g, b, a) end },
		{ type = "slider", label = "Border Size", min = 0, max = 4, step = 1,
			get = function() return Cfg("standaloneTimerBorderSize") or 0 end,
			set = function(v) Set("standaloneTimerBorderSize", v) end },
		{ type = "dropdown", label = "Frame Strata", items = function() return KeyItems(STRATAS) end,
			get = function() return Cfg("standaloneTimerStrata") or "HIGH" end,
			labelFn = function() return KeyLabel(STRATAS, Cfg("standaloneTimerStrata") or "HIGH") end,
			set = function(v) Set("standaloneTimerStrata", v) end },
	}, { disabled = timerOff })
	if Cfg("standaloneTimer") then
		p:Toggle("Show Out of Combat", "Keep the timer visible out of combat, showing the last fight's duration.",
			function() return Cfg("standaloneTimerShowOOC") or false end,
			function(v) Set("standaloneTimerShowOOC", v) end)
		p:Cog("Out of Combat", {
			{ type = "toggle", label = "Desaturate Out of Combat",
				disabled = function() return not Cfg("standaloneTimerShowOOC") end,
				get = function() return Cfg("standaloneTimerDesatOOC") or false end,
				set = function(v) Set("standaloneTimerDesatOOC", v) end },
		})
		p:Dropdown("Anchor to Windows", "Free Move, or a corner of the first meter window.",
			function() return KeyItems(TIMER_ANCHORS) end,
			function() return Cfg("standaloneTimerAnchor") or "free" end,
			function() return KeyLabel(TIMER_ANCHORS, Cfg("standaloneTimerAnchor") or "free") end,
			function(v) Set("standaloneTimerAnchor", v) end)
		p:Label("Hold Shift+Click to Freely Move Standalone Timer")
		p:Toggle("Lock Position & Disable Click", "Lock the timer in place and make it click-through; no dragging and no mouse interaction until unlocked.",
			function() return Cfg("standaloneTimerLocked") or false end,
			function(v) Set("standaloneTimerLocked", v) end)
	end

	-- EXTRAS
	p:Section("EXTRAS")
	p:Toggle("Show Spell Tooltips on Hover", "Show the game's spell tooltip when you hover a spell in a breakdown window.",
		function() return Cfg("showSpellTooltips") ~= false end,
		function(v) Set("showSpellTooltips", v) end)
	p:Keybind("Show/Hide Windows Keybind", "Left-click to set a keybind.\nRight-click to unbind.\nHides or shows every meter window (not saved: a reload shows them again).",
		function() return Cfg("toggleWindowsKey") end,
		function(v) Set("toggleWindowsKey", v) end)
	p:Cog("Keybind", {
		{ type = "toggle", label = "Include Combat Timer",
			get = function() return Cfg("toggleIncludeTimer") == true end,
			set = function(v) Set("toggleIncludeTimer", v) end },
		{ type = "toggle", label = "Include Spell History",
			get = function() return Cfg("toggleIncludeSpellHistory") == true end,
			set = function(v) Set("toggleIncludeSpellHistory", v) end },
	})
end

---------------------------------------------------------------------------
-- Spell History page
---------------------------------------------------------------------------
local function SH()
	return ns.GetSpellHistoryDB()
end

-- "Visibility Options" multi-select for one display (prefix "icon" or "bar").
local function VisibilityControl(p, prefix, isDisabled)
	local list = ns.SH_VISIBILITY
	p:MultiSelect("Visibility Options", "Hide this display in some places. It is always shown while this page or Unlock Mode is open.",
		function() return KeyItems(list) end,
		function(key) return SH()[prefix .. key] end,
		function(key) SH()[prefix .. key] = not SH()[prefix .. key] end,
		function()
			local names = {}
			for i = 1, #list do
				if SH()[prefix .. list[i].key] then
					names[#names + 1] = list[i].text
				end
			end
			if #names == 0 then
				return "Always shown"
			end
			return table.concat(names, ", ")
		end,
		isDisabled)
end

local function BuildSpellHistoryPage(p)
	local function iconOff() return not SH().iconEnabled end
	local function barOff() return not SH().barEnabled end

	p:Section("Icon History")
	p:Toggle("Enable Icon History", "Shows a movable strip of recent spell icons. Move it in Unlock Mode.",
		function() return SH().iconEnabled end, function(v) SH().iconEnabled = v end)
	p:Slider("Icon Zoom %", "How much of the icon border is cut off. Used by the icon strip and the bars.", 0, 20, 1,
		function() return SH().iconZoom end, function(v) SH().iconZoom = v end,
		function() return iconOff() and barOff() end)
	p:Dropdown("Grow Direction", "Direction the icon strip grows as new spells are cast.",
		function() return KeyItems(ns.SH_GROW_DIRS) end,
		function() return SH().iconGrow end,
		function() return KeyLabel(ns.SH_GROW_DIRS, SH().iconGrow) end,
		function(v) SH().iconGrow = v end, nil, iconOff)
	VisibilityControl(p, "icon", iconOff)
	p:Slider("Icon Size", "Size of each icon.", 20, 60, 1,
		function() return SH().iconSize end, function(v) SH().iconSize = v end, iconOff)
	p:Slider("Max Icons", "Maximum number of spell icons to display.", 1, 10, 1,
		function() return SH().iconMax end, function(v) SH().iconMax = v end, iconOff)
	p:Slider("Icon Spacing", "Space between the icons.", 0, 10, 1,
		function() return SH().iconSpacing end, function(v) SH().iconSpacing = v end, iconOff)
	p:Slider("Opacity %", "Opacity of the icon strip.", 10, 100, 1,
		function() return SH().iconOpacity end, function(v) SH().iconOpacity = v end, iconOff)
	p:Dropdown("Animation Style", "How a new icon appears.",
		function() return KeyItems(ns.SH_ANIMATIONS) end,
		function() return SH().iconAnimation end,
		function() return KeyLabel(ns.SH_ANIMATIONS, SH().iconAnimation) end,
		function(v) SH().iconAnimation = v end, nil, iconOff)
	p:Slider("Fade-Out Time", "Seconds after which history icons fade out. The timer pauses during combat. 0 = never.", 0, 60, 1,
		function() return SH().iconFadeTime end, function(v) SH().iconFadeTime = v end, iconOff)

	p:Section("Bar History")
	p:Toggle("Enable Bar History", "Shows a window with your spell cast history as bars: icon, name, cast time and target. Scroll it with the mouse wheel.",
		function() return SH().barEnabled end, function(v) SH().barEnabled = v end)
	VisibilityControl(p, "bar", barOff)
	p:Slider("Background Opacity %", "Opacity of the window background.", 0, 100, 1,
		function() return SH().bgAlpha end, function(v) SH().bgAlpha = v end, barOff)
	p:Toggle("Hide Top Bar", "Hide the title bar of the window.",
		function() return SH().barHideTopBar end, function(v) SH().barHideTopBar = v end, barOff)
	p:Color("Background Color", "Color of the window background.", function() return SH().bgColor end, barOff)
	p:Slider("Window Width", "Width of the window.", 150, 600, 1,
		function() return SH().barWidth end, function(v) SH().barWidth = v end, barOff)
	p:Slider("Bar Height", "Height of one bar.", 12, 32, 1,
		function() return SH().barHeight end, function(v) SH().barHeight = v end, barOff)
	p:Slider("Max Bars", "Maximum number of bars to display. Window height adjusts automatically.", 1, 10, 1,
		function() return SH().barMax end, function(v) SH().barMax = v end, barOff)
	p:Dropdown("Bar Texture", "Texture of the bars. Textures from LibSharedMedia are listed too.",
		function() return MediaItems(ns.GetBarTextures()) end,
		function() return SH().barTexture end,
		function() return ns.GetBarTextureLabel(SH().barTexture) end,
		function(v) SH().barTexture = v end,
		{ texturePreview = true }, barOff)
	p:Slider("Text Size", "Size of the text.", 8, 16, 1,
		function() return SH().textSize end, function(v) SH().textSize = v end, barOff)
	p:Dropdown("Text Color", "Accent: the green color of this addon. Custom: the color on the right.",
		function() return KeyItems(ns.SH_TEXT_COLOR_MODES) end,
		function() return SH().textColorMode end,
		function() return KeyLabel(ns.SH_TEXT_COLOR_MODES, SH().textColorMode) end,
		function(v) SH().textColorMode = v end, nil, barOff)
	p:Color("Custom Text Color", "Text color when Text Color is Custom.", function() return SH().textColor end,
		function() return barOff() or SH().textColorMode ~= "custom" end)
	p:Dropdown("Bar Color", "Class: your class color. Accent: the green color of this addon. Custom: the color on the right. Failed and interrupted casts are always red.",
		function() return KeyItems(ns.SH_BAR_COLOR_MODES) end,
		function() return SH().barColorMode end,
		function() return KeyLabel(ns.SH_BAR_COLOR_MODES, SH().barColorMode) end,
		function(v) SH().barColorMode = v end, nil, barOff)
	p:Color("Custom Bar Color", "Bar color when Bar Color is Custom.", function() return SH().barColor end,
		function() return barOff() or SH().barColorMode ~= "custom" end)
	p:Slider("Opacity %", "Opacity of the whole window.", 10, 100, 1,
		function() return SH().barOpacity end, function(v) SH().barOpacity = v end, barOff)
end

-- Retail order: Damage Meters, then Spell History.
local PAGES = {}
if DM then
	PAGES[#PAGES + 1] = {
		key = "damageMeters",
		name = "Damage Meters",
		description = "Meter windows with the numbers from Details!. Right-click a window for its home screen, click a bar for its breakdown. Move the windows in Unlock Mode.",
		build = BuildMeterPage,
	}
end
PAGES[#PAGES + 1] = {
	key = "spellHistory",
	name = "Spell History",
	description = "Your recent casts as an icon strip and as bars. Move them in Unlock Mode.",
	build = BuildSpellHistoryPage,
}

ns.RegisterSettingsModule({
	key = "damageMeters",
	name = "Damage Meters",
	group = "UI Reskin Addons",
	tabs = PAGES,
	reset = function()
		ns.ResetSpellHistorySettings()
		if DM then DM.Reset() end
	end,
	resetTip = "Set all Damage Meters and Spell History settings back to default. Positions are kept.",
	onEnter = function()
		ns.SetSpellHistoryPreview(true)
		if DM then DM.SetPreview(true) end
	end,
	onLeave = function()
		ns.SetSpellHistoryPreview(false)
		if DM then DM.SetPreview(false) end
	end,
})
