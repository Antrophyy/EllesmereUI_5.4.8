-- Settings page of UI Reskin Addons > Minimap (EllesmereUI EUI_Minimap_Options.lua:
-- the same sections, labels, tooltips and keys). Rows that need a retail-only
-- API are left out (Border Style textures, Icon Size, Great Vault, M+ Portals,
-- Crafting Order, Omnium Folio, Addon Compartment). Show Queue Status (the
-- 5.4.8 queue eye) takes the Omnium Folio's row.
-- Part of EllesmereUIOptions (load on demand); skipped when EllesmereUIMinimap
-- is not loaded.

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUIMinimap") then
	return
end
local EMM = ns.EMM
if not EMM then
	return
end

local function M()
	return EMM.DB()
end

local function Items(list)
	local out = {}
	for i = 1, #list do
		out[i] = { value = list[i][1], name = list[i][2] }
	end
	return out
end

local function LabelOf(list, value)
	for i = 1, #list do
		if list[i][1] == value then
			return list[i][2]
		end
	end
	return tostring(value or "")
end

-- Dropdown on a profile key.
local function KeyDropdown(p, label, tip, list, key, default, isDisabled, onSet)
	p:Dropdown(label, tip,
		function() return Items(list) end,
		function() local m = M(); return (m and m[key]) or default end,
		function() local m = M(); return LabelOf(list, (m and m[key]) or default) end,
		function(v)
			M()[key] = v
			if onSet then onSet(v) end
		end,
		nil, isDisabled)
end

local function Getter(key, default)
	return function()
		local m = M()
		local v = m and m[key]
		if v == nil then
			return default
		end
		return v
	end
end

local function Setter(key)
	return function(v) M()[key] = v end
end

-- Cog rows on profile keys.
local function SliderRow(label, key, minV, maxV, step, default, tip)
	return { type = "slider", label = label, min = minV, max = maxV, step = step, tip = tip,
		get = Getter(key, default), set = Setter(key) }
end

local function ToggleRow(label, key, tip)
	return { type = "toggle", label = label, tip = tip, get = Getter(key, false), set = Setter(key) }
end

---------------------------------------------------------------------------
-- Value lists (retail labels)
---------------------------------------------------------------------------
local SHAPES = { { "square", "Square" }, { "rectangular", "Rectangular" }, { "circle", "Circle" } }
local ROW_POS = {
	{ "blUp", "Bottom Left, Grow Up" }, { "blRight", "Bottom Left, Grow Right" },
	{ "tlDown", "Top Left, Grow Down" }, { "tlRight", "Top Left, Grow Right" },
	{ "brUp", "Bottom Right, Grow Up" }, { "brLeft", "Bottom Right, Grow Left" },
	{ "trLeft", "Top Right, Grow Left" }, { "trDown", "Top Right, Grow Down" },
}
local GROW = { { "auto", "Auto" }, { "up", "Up" }, { "down", "Down" }, { "left", "Left" }, { "right", "Right" } }
local CORNERS = { { "BOTTOMLEFT", "Bottom Left" }, { "BOTTOMRIGHT", "Bottom Right" }, { "TOPLEFT", "Top Left" }, { "TOPRIGHT", "Top Right" } }
local MODES3 = { { "never", "Never" }, { "hover", "On Hover" }, { "always", "Always" } }
local MAIL_POS = {
	{ "button", "Minimap Button" }, { "TOPRIGHT", "Top Right" }, { "TOPLEFT", "Top Left" },
	{ "BOTTOMRIGHT", "Bottom Right" }, { "BOTTOMLEFT", "Bottom Left" },
}
local TEXT_STYLES = { { "none", "None" }, { "inside", "Inside Map" }, { "edge", "Edge Box" } }
local MAP_POS = {
	{ "belowMap", "Below Map" }, { "aboveMap", "Above Map" }, { "topLeft", "Top Left" }, { "top", "Top" },
	{ "topRight", "Top Right" }, { "left", "Left" }, { "right", "Right" }, { "bottomLeft", "Bottom Left" },
	{ "bottom", "Bottom" }, { "bottomRight", "Bottom Right" },
}
local HOVER_TT = { { "none", "None" }, { "lockouts", "Instance Lockouts" } }

local function ShapeUsesRectLayout()
	local m = M()
	local s = m and m.shape or "square"
	return s == "square" or s == "rectangular"
end

---------------------------------------------------------------------------
-- Visibility checklist (retail BuildVisibilityRow)
---------------------------------------------------------------------------
local function Axis(key)
	for _, axis in ipairs(EMM.VIS_AXES) do
		if axis.key == key then
			return axis
		end
	end
end

local function VisibilityItems()
	local items = {
		{ value = "state:never", name = "Never" },
		{ value = "state:always", name = "Always" },
		{ value = "state:mouseover", name = "Mouseover" },
		{ value = "match:all", name = "Match All Conditions" },
		{ value = "match:any", name = "Match Any Condition" },
	}
	for _, axis in ipairs(EMM.VIS_AXES) do
		items[#items + 1] = { value = "show:" .. axis.key, name = "Show: " .. axis.label }
		items[#items + 1] = { value = "hide:" .. axis.key, name = "Hide: " .. axis.label }
	end
	return items
end

local function VisibilityRow(p)
	p:MultiSelect("Visibility", "When the minimap is shown. Never / Always / Mouseover is the base state; the Show conditions must match (all or any), a Hide condition always hides.",
		VisibilityItems,
		function(value)
			local s = M()
			local kind, key = value:match("^(%a+):(.+)$")
			if kind == "state" then
				return EMM.VisBase(s) == key
			elseif kind == "match" then
				return (s.visibilityMatch or "all") == key
			end
			local axis = Axis(key)
			return EMM.VisFlag(s, kind == "show" and axis.show or axis.hide)
		end,
		function(value)
			local s = M()
			local kind, key = value:match("^(%a+):(.+)$")
			if kind == "state" then
				EMM.SetVisBase(s, key)
				return
			elseif kind == "match" then
				s.visibilityMatch = key
				return
			end
			local axis = Axis(key)
			local laneKey = kind == "show" and axis.show or axis.hide
			local otherKey = kind == "show" and axis.hide or axis.show
			local on = not EMM.VisFlag(s, laneKey)
			EMM.SetVisFlag(s, laneKey, on)
			if on then
				EMM.SetVisFlag(s, otherKey, false)
			end
		end,
		function()
			local s = M()
			local base = EMM.VisBase(s)
			local text = base == "never" and "Never" or (base == "mouseover" and "Mouseover" or "Always")
			local n = 0
			for _, axis in ipairs(EMM.VIS_AXES) do
				if EMM.VisFlag(s, axis.show) or EMM.VisFlag(s, axis.hide) then
					n = n + 1
				end
			end
			if n > 0 and base ~= "never" then
				text = text .. " + " .. n .. (n == 1 and " condition" or " conditions")
			end
			return text
		end)
end

-- Multi-select on "hide" keys: checked = shown.
local function HideKeyMulti(p, label, tip, list, isDisabled)
	p:MultiSelect(label, tip,
		function()
			local items = {}
			for _, e in ipairs(list) do
				items[#items + 1] = { value = e.key, name = e.label, locked = e.locked, lockedTip = e.lockedTip }
			end
			return items
		end,
		function(key)
			for _, e in ipairs(list) do
				if e.key == key then
					return not e.get()
				end
			end
		end,
		function(key)
			for _, e in ipairs(list) do
				if e.key == key then
					e.set(not e.get())
				end
			end
		end,
		function()
			local on = {}
			for _, e in ipairs(list) do
				if not e.get() then
					on[#on + 1] = e.label
				end
			end
			return #on == 0 and "None" or table.concat(on, ", ")
		end,
		isDisabled)
end

-- Position size cog (Scale + X / Y offset), on the last cell.
local function SizePosCog(p, title, scaleKey, scaleDefault, xKey, yKey, isOff, offTip, sizeRow)
	local rows = {}
	if sizeRow then
		rows[#rows + 1] = sizeRow
	end
	if scaleKey then
		rows[#rows + 1] = SliderRow("Scale", scaleKey, 0.5, 2.0, 0.05, scaleDefault)
	end
	rows[#rows + 1] = SliderRow("X Offset", xKey, -500, 500, 1, 0)
	rows[#rows + 1] = SliderRow("Y Offset", yKey, -500, 500, 1, 0)
	p:Cog(title, rows, { icon = "resize", disabled = isOff, disabledTip = offTip })
end

---------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------
local function Build(p)
	if EMM:IsDisabledByElvUI() then
		p:Paragraph("|cffff6060ElvUI's minimap is on, so EllesmereUI Minimap is off.|r Turn off ElvUI > Maps > Minimap > Enable and reload to use it.")
	end

	-- DISPLAY -------------------------------------------------------------
	p:Section("Display")
	VisibilityRow(p)
	p:Cog("Minimap Opacity", {
		SliderRow("Opacity", "opacity", 10, 100, 1, 100, "Fades the minimap while it is shown. Visibility still decides when it shows."),
	}, {
		disabled = function() return EMM.VisBase(M()) == "never" end,
		disabledTip = "This option requires a Visibility other than Never",
	})
	KeyDropdown(p, "Shape", nil, SHAPES, "shape", "square")

	p:Slider("Size", nil, 100, 600, 1, Getter("mapSize", 140), Setter("mapSize"))
	p:Slider("Interactable Button Size", "Size of mail, calendar, tracking, and minimap button group toggle", 16, 40, 1,
		Getter("interactableBtnSize", 21), Setter("interactableBtnSize"))

	-- Border Size with accent / class / custom color swatches.
	p:Slider("Border Size", nil, 0, 4, 1, Getter("borderSize", 1), Setter("borderSize"))
	p:Swatch("Accent Color",
		function() local r, g, b = EMM.AccentColor(); return r, g, b, 1 end,
		function() end,
		{ readonly = true,
		  active = function() local m = M(); return m.useClassColor and not m.borderUseClassColor end,
		  onClick = function() local m = M(); m.useClassColor = true; m.borderUseClassColor = false; return true end })
	p:Swatch("Class Color",
		function() return EMM.ClassColor() end,
		function() end,
		{ readonly = true,
		  active = function() return M().borderUseClassColor and true or false end,
		  onClick = function() local m = M(); m.borderUseClassColor = true; m.useClassColor = false; return true end })
	p:Swatch("Custom Color",
		function()
			local m = M()
			local c = m.borderColor
			if c then
				return c.r, c.g, c.b, m.borderA or 1
			end
			return m.borderR or 0, m.borderG or 0, m.borderB or 0, m.borderA or 1
		end,
		function(r, g, b, a)
			local m = M()
			m.borderColor = { r = r, g = g, b = b }
			m.borderA = a or 1
		end,
		{ alpha = true,
		  active = function() local m = M(); return not (m.borderUseClassColor or m.useClassColor) end,
		  onClick = function()
			local m = M()
			if m.borderUseClassColor or m.useClassColor then
				m.borderUseClassColor = false
				m.useClassColor = false
				return true
			end
		  end })
	p:Blank()

	p:Slider("Reset Zoom (seconds)", "Automatically zoom back out to maximum distance after this many seconds of no manual zoom change. 0 disables the reset.",
		0, 15, 1, Getter("zoomResetSeconds", 0), Setter("zoomResetSeconds"))
	p:Toggle("Rotate Minimap", nil, Getter("rotateMinimap", false), Setter("rotateMinimap"))

	-- MINIMAP & QOL BUTTONS ----------------------------------------------
	p:Section("Minimap & QoL Buttons")
	local function TooFewButtons()
		return #EMM.AddonButtonItems() < 2
	end
	p:MultiSelect("Ungroup Minimap Buttons", "Addon buttons picked here stand on the button row by themselves instead of inside the group. The order you pick them in is their order on the row.",
		EMM.AddonButtonItems,
		function(key)
			local ug = M().ungroupedButtons
			return ug and ug[key] and true or false
		end,
		function(key)
			local m = M()
			m.ungroupedButtons = m.ungroupedButtons or {}
			if m.ungroupedButtons[key] then
				m.ungroupedButtons[key] = nil
			else
				local maxOrder = 0
				for _, ord in pairs(m.ungroupedButtons) do
					if type(ord) == "number" and ord > maxOrder then
						maxOrder = ord
					end
				end
				m.ungroupedButtons[key] = maxOrder + 1
			end
			EMM.FullRebuild()
		end,
		function()
			local n = 0
			for _, item in ipairs(EMM.AddonButtonItems()) do
				local ug = M().ungroupedButtons
				if ug and ug[item.value] then
					n = n + 1
				end
			end
			if TooFewButtons() then
				return "..."
			end
			return n == 0 and "None" or (n .. " ungrouped")
		end,
		TooFewButtons)
	p:Slider("In-Group Button Size", "Size of addon minimap buttons in the flyout grid", 14, 40, 1,
		Getter("addonBtnSize", 24), Setter("addonBtnSize"))

	HideKeyMulti(p, "Show Extra Buttons", "Extra buttons on the button row.", {
		{ key = "friendsOnline", label = "Friends Online",
		  get = function() local h = M().hideExtraBtns; return h and h.friendsOnline end,
		  set = function(v) local m = M(); m.hideExtraBtns = m.hideExtraBtns or {}; m.hideExtraBtns.friendsOnline = v end },
		{ key = "groupButton", label = "Group Button",
		  get = function() local h = M().hideExtraBtns; return h and h.groupButton end,
		  set = function(v) local m = M(); m.hideExtraBtns = m.hideExtraBtns or {}; m.hideExtraBtns.groupButton = v end },
	})
	p:Toggle("Mouseover Extra Buttons", "When enabled, the extra buttons (Friends Online, Group Button) and any ungrouped minimap buttons only show while the mouse is over the minimap.",
		Getter("mouseoverExtraBtns", false), Setter("mouseoverExtraBtns"))

	p:Toggle("Open Micro Menu on Middle Click", "Middle-click the minimap to open the EllesmereUI micro menu. When off, middle-click does nothing.",
		function() return M().openMicroMenuOnMiddleClick ~= false end, Setter("openMicroMenuOnMiddleClick"))
	p:Blank()

	p:Slider("Friends Tooltip Cap", "Max rows per section in the Friends Online tooltip (0 = the 30-row max). The cog can show each note under its row.",
		0, 30, 1, Getter("friendsMaxRows", 0), Setter("friendsMaxRows"))
	p:Cog("Friends Tooltip", {
		ToggleRow("Show Notes", "friendsShowNotes", "Shows each guild or friend note on a second line under its row. The tooltip gets taller."),
	})
	p:Slider("Custom Tooltip Size", "Scales the custom tooltips shown by the unique minimap buttons (friends, calendar, mail, tracking).",
		0.5, 2.0, 0.05, Getter("customTooltipScale", 1.0), Setter("customTooltipScale"))

	local function BtnRowPos() return M().btnRowPosition or "blUp" end
	local function ElementRowPos() return M().elementRowPosition or "tlDown" end
	local function RowItems(other)
		local items = Items(ROW_POS)
		for _, item in ipairs(items) do
			local v = item.value
			item.locked = function() return v == other() end
			item.lockedTip = other == ElementRowPos and "Already used by Element Row Position" or "Already used by Button Row Position"
		end
		return items
	end
	p:Dropdown("Button Row Position", "Which minimap corner the button row builds out from and the direction it grows.",
		function() return RowItems(ElementRowPos) end, BtnRowPos,
		function() return LabelOf(ROW_POS, BtnRowPos()) end, Setter("btnRowPosition"))
	p:Cog("Button Row Settings", {
		SliderRow("Icon Spacing", "btnRowSpacing", -20, 40, 1, 0),
		SliderRow("Distance from Map", "btnRowDistance", -20, 60, 1, 0),
		{ type = "dropdown", label = "Grow Tooltip/Popup",
		  items = function() return Items(GROW) end,
		  get = Getter("flyoutGrowDir", "auto"), set = Setter("flyoutGrowDir"),
		  labelFn = function() return LabelOf(GROW, M().flyoutGrowDir or "auto") end },
	}, { icon = "resize" })
	p:Toggle("Free Move Buttons", "When enabled, Shift+Click any minimap button (mail, calendar, tracking, addon buttons) to drag it to a custom position.",
		Getter("freeMoveBtns", false),
		function(v)
			local m = M()
			m.freeMoveBtns = v
			if not v then
				m.btnPositions = {}
			end
		end)
	p:Cog("Button Settings", {
		{ type = "toggle", label = "Button Backgrounds",
		  tip = "Show black backgrounds behind minimap indicator buttons (tracking, calendar, mail, addon buttons, flyout toggle).",
		  get = function() return M().btnBackgrounds ~= false end,
		  set = function(v) M().btnBackgrounds = v; EMM.FullRebuild() end },
	})
	p:Button("Reset Button Positions", "Puts every button moved with Free Move back on its row.", "Reset",
		function() M().btnPositions = {} end)
	p:Blank()

	-- BLIZZARD ELEMENTS ---------------------------------------------------
	p:Section("Blizzard Elements")
	local function QueueOff() return (M().queueStatusMode or "always") == "never" end
	KeyDropdown(p, "Show Queue Status", "Show the queue status eye (dungeon, raid, battleground and scenario queues) on the minimap while you are queued. Use the cog to choose its corner and nudge its position.",
		MODES3, "queueStatusMode", "always")
	p:Cog("Queue Status Position", {
		{ type = "dropdown", label = "Corner",
		  items = function() return Items(CORNERS) end,
		  get = Getter("queueStatusCorner", "BOTTOMLEFT"), set = Setter("queueStatusCorner"),
		  labelFn = function() return LabelOf(CORNERS, M().queueStatusCorner or "BOTTOMLEFT") end },
		SliderRow("X Offset", "queueStatusX", -1000, 1000, 1, 0),
		SliderRow("Y Offset", "queueStatusY", -1000, 1000, 1, 0),
	}, { disabled = QueueOff, disabledTip = "Show Queue Status" })
	p:Slider("Queue Status Scale", nil, 0.5, 1.5, 0.05, Getter("queueStatusScale", 0.8), Setter("queueStatusScale"), QueueOff)

	local function HideKey(key, label, extra)
		local e = { key = key, label = label,
			get = function() return M()[extra.hideKey] and true or false end,
			set = function(v) M()[extra.hideKey] = v end }
		e.locked = extra.locked
		e.lockedTip = extra.lockedTip
		return e
	end
	HideKeyMulti(p, "Show Blizzard Elements", "Blizzard parts shown on the minimap.", {
		HideKey("calendar", "Calendar", { hideKey = "hideGameTime" }),
		HideKey("mail", "Mail", { hideKey = "hideMail" }),
		HideKey("tracking", "Tracking", { hideKey = "hideTrackingButton" }),
		HideKey("difficulty", "Difficulty", { hideKey = "hideRaidDifficulty",
			locked = function() return M().diffTextEnabled and true or false end,
			lockedTip = "Shown as text (Show Instance Difficulty as Text)" }),
		HideKey("zoom", "Zoom +/- Icons", { hideKey = "hideZoomButtons" }),
	})
	p:Toggle("Scroll to Zoom", nil, Getter("scrollZoom", true), Setter("scrollZoom"))

	local function ElOff() return not ShapeUsesRectLayout() end
	p:Dropdown("Element Row Position", "Which minimap corner the Blizzard element row (tracking, calendar, mail) builds out from and the direction it grows.",
		function() return RowItems(BtnRowPos) end, ElementRowPos,
		function() return LabelOf(ROW_POS, ElementRowPos()) end, Setter("elementRowPosition"), nil, ElOff)
	p:Cog("Element Row Spacing", {
		SliderRow("Icon Spacing", "elementRowSpacing", -20, 40, 1, 0),
		SliderRow("Distance from Map", "elementRowDistance", -20, 60, 1, 0),
	}, { icon = "resize", disabled = ElOff, disabledTip = "Square or Rectangular Shape" })
	local function MailHidden() return M().hideMail and true or false end
	KeyDropdown(p, "Mail Position", nil, MAIL_POS, "mailPosition", "button", MailHidden)
	p:Cog("Mail Position", {
		SliderRow("X Offset", "mailOffsetX", -100, 100, 1, 0),
		SliderRow("Y Offset", "mailOffsetY", -500, 500, 1, 0),
	}, { icon = "directions",
	     disabled = function() local m = M(); return m.hideMail or (m.mailPosition or "button") == "button" end,
	     disabledTip = "a Mail Position corner" })

	-- TEXT ------------------------------------------------------------------
	p:Section("Text")
	local function ClockMode() local c = EMM.GetElementModes(M()); return c end
	local function LocationMode() local _, l = EMM.GetElementModes(M()); return l end
	local function ClockOff() return ClockMode() == "none" end
	local function LocOff() return LocationMode() == "none" end

	p:Dropdown("Clock Style", nil, function() return Items(TEXT_STYLES) end, ClockMode,
		function() return LabelOf(TEXT_STYLES, ClockMode()) end, Setter("clockMode"))
	KeyDropdown(p, "Clock Position", nil, MAP_POS, "clockPosition", "top", ClockOff)
	SizePosCog(p, "Clock Size and Position", "clockScale", 1.15, "clockOffsetX", "clockOffsetY", ClockOff, "Clock Style")

	p:Dropdown("Zone Text Style", nil, function() return Items(TEXT_STYLES) end, LocationMode,
		function() return LabelOf(TEXT_STYLES, LocationMode()) end, Setter("locationMode"))
	p:Cog("Zone Text Settings", {
		ToggleRow("Display Sub Zone", "zoneShowSubZone"),
		ToggleRow("Reactive Coloring", "zoneReactiveColor"),
	}, { disabled = LocOff, disabledTip = "Zone Text Style" })
	KeyDropdown(p, "Zone Position", nil, MAP_POS, "locationPosition", "bottom", LocOff)
	SizePosCog(p, "Zone Text Size and Position", "locationScale", 1.15, "locationOffsetX", "locationOffsetY", LocOff, "Zone Text Style")

	local function CoordsMode() local mode = EMM.GetCoordsModePos(M()); return mode end
	local function CoordsPos() local _, pos = EMM.GetCoordsModePos(M()); return pos end
	local function CoordsOff() return CoordsMode() == "never" end
	p:Dropdown("Show Coordinates", nil, function() return Items(MODES3) end, CoordsMode,
		function() return LabelOf(MODES3, CoordsMode()) end, Setter("coordsMode"))
	p:Cog("Coordinate Precision", {
		SliderRow("Decimal Places", "coordPrecision", 0, 2, 1, 0),
	}, { disabled = CoordsOff, disabledTip = "Show Coordinates" })
	p:Dropdown("Coordinates Position", nil, function() return Items(MAP_POS) end, CoordsPos,
		function() return LabelOf(MAP_POS, CoordsPos()) end, Setter("coordsPosition"), nil, CoordsOff)
	SizePosCog(p, "Coordinates Size and Position", "coordsScale", 1.0, "coordsBelowOffsetX", "coordsBelowOffsetY", CoordsOff, "Show Coordinates")

	local function FpsOff() return not M().showFPS end
	p:Toggle("Show FPS/MS", nil, Getter("showFPS", false), Setter("showFPS"))
	p:Cog("FPS/MS Settings", {
		SliderRow("Text Size", "fpsTextSize", 8, 30, 1, 12),
		{ type = "toggle", label = "Show Local MS",
		  get = function() return M().fpsShowLocalMS ~= false end, set = Setter("fpsShowLocalMS") },
		ToggleRow("Show World MS", "fpsShowWorldMS"),
		SliderRow("Update Interval", "fpsUpdateInterval", 1, 5, 1, 3),
	}, { disabled = FpsOff, disabledTip = "Show FPS/MS" })
	KeyDropdown(p, "FPS/MS Position", nil, MAP_POS, "fpsPosition", "bottomLeft", FpsOff)
	SizePosCog(p, "FPS/MS Size and Position", "fpsScale", 1.0, "fpsOffsetX", "fpsOffsetY", FpsOff, "Show FPS/MS")

	KeyDropdown(p, "Show on FPS/MS Hover", nil, HOVER_TT, "fpsHoverTooltip", "none", FpsOff)
	KeyDropdown(p, "Show on Clock Hover", nil, HOVER_TT, "clockHoverTooltip", "none", ClockOff)

	local function DiffOff() return not M().diffTextEnabled end
	p:Toggle("Show Instance Difficulty as Text", nil, Getter("diffTextEnabled", false), Setter("diffTextEnabled"))
	KeyDropdown(p, "Difficulty Position", nil, MAP_POS, "diffTextPosition", "topLeft", DiffOff)
	SizePosCog(p, "Difficulty Text Size and Position", nil, nil, "diffTextOffsetX", "diffTextOffsetY", DiffOff,
		"Show Instance Difficulty as Text", SliderRow("Text Size", "diffTextSize", 8, 24, 1, 12))

	-- Accented Text: which text parts take the accent / custom color.
	local accentItems = {
		{ value = "clock", name = "Clock" },
		{ value = "fpsms", name = "FPS/MS" },
		{ value = "difficulty", name = "Difficulty",
		  locked = function() return M().diffTextReactive and true or false end,
		  lockedTip = "Difficulty (Reactive) is checked" },
		{ value = "difficultyReactive", name = "Difficulty (Reactive)",
		  locked = function() return M().diffTextAccent and true or false end,
		  lockedTip = "Difficulty is checked" },
	}
	local function AccentOn(key)
		local m = M()
		if key == "clock" then return m.fpsColorClockAMPM and true or false end
		if key == "fpsms" then return m.fpsColorSuffix ~= false end
		if key == "difficulty" then return m.diffTextAccent and true or false end
		if key == "difficultyReactive" then return m.diffTextReactive and true or false end
		return false
	end
	p:MultiSelect("Accented Text", "Which text parts (clock AM/PM, the FPS / MS words, the difficulty letter) take the accent or custom color from the swatches. Numbers stay white.",
		function() return accentItems end,
		AccentOn,
		function(key)
			local m = M()
			local v = not AccentOn(key)
			if key == "clock" then
				m.fpsColorClockAMPM = v
			elseif key == "fpsms" then
				m.fpsColorSuffix = v
			elseif key == "difficulty" then
				m.diffTextAccent = v
				if v then m.diffTextReactive = false end
			elseif key == "difficultyReactive" then
				m.diffTextReactive = v
				if v then m.diffTextAccent = false end
			end
		end,
		function()
			local on = {}
			for _, item in ipairs(accentItems) do
				if AccentOn(item.value) then
					on[#on + 1] = item.name
				end
			end
			return #on == 0 and "None" or table.concat(on, ", ")
		end)
	p:Swatch("Accent Color",
		function() local r, g, b = EMM.AccentColor(); return r, g, b, 1 end,
		function() end,
		{ readonly = true,
		  active = function() return M().fpsUseAccent and true or false end,
		  onClick = function() M().fpsUseAccent = true; return true end })
	p:Swatch("Custom Color",
		function()
			local c = M().fpsColor
			if c then
				return c.r or 1, c.g or 1, c.b or 1, 1
			end
			return 1, 1, 1, 1
		end,
		function(r, g, b) M().fpsColor = { r = r, g = g, b = b } end,
		{ active = function() return not M().fpsUseAccent end,
		  onClick = function()
			if M().fpsUseAccent then
				M().fpsUseAccent = false
				return true
			end
		  end })
	p:Blank()
end

ns.RegisterSettingsModule({
	key = "minimap",
	name = "Minimap",
	group = "UI Reskin Addons",
	tabs = {
		{ key = "minimap", name = "Minimap", description = "Custom minimap skin and layout.", build = Build },
	},
	reset = function()
		EMM:Reset()
	end,
	resetTip = "Set all Minimap settings back to the EllesmereUI defaults (size and position too).",
})
