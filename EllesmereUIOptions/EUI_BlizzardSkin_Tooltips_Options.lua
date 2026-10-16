-- Blizzard Skins > "Tooltips, Menus & Popups" tab (port of retail
-- EUI_BlizzardSkin_Options.lua BuildTooltipsPage). The "Blizzard HUD" section
-- at the end comes from ns.BlizzSkinHUDOptions (HUD skin file).
-- Left out (no 5.4.8 counterpart): border textures (solid borders only) and
-- their offsets, M+ Score, Show Icon ID and the Spell ID modifier (the spell
-- ID lines are EllesmereUI core's Global Settings > Developer option).
local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUIBlizzardSkin") then
	return
end
local BS = ns.BlizzSkin
local TT = BS.Tooltips
if not TT then
	return
end
local U = ns.OptionsUtil
local KeyItems, KeyLabel = U.KeyItems, U.KeyLabel

local function DB()
	return BS.DB()
end
local Get = BS.Get
local function Setter(key)
	return function(v) DB()[key] = v end
end
local function Getter(key)
	return function() return Get(key) end
end
local function CoreDB()
	if type(EllesmereUIDB) ~= "table" then
		EllesmereUIDB = {}
	end
	return EllesmereUIDB
end

local MODIFIERS = {
	{ key = "none", text = "None" },
	{ key = "shift", text = "Shift" },
	{ key = "control", text = "Control" },
	{ key = "alt", text = "Alt" },
}
local BORDER_COLOR_MODES = {
	{ key = "custom", text = "Custom Color" },
	{ key = "accent", text = "Accent Color" },
	{ key = "class", text = "Class Color" },
}
local ELEMENT_MODES = {
	{ key = "native", text = "Native Colors" },
	{ key = "accent", text = "Accent Color" },
	{ key = "custom", text = "Custom Color" },
	{ key = "class", text = "Class Color" },
}
local CURSOR_POSITIONS = {
	{ key = "bottomright", text = "Bottom Right" },
	{ key = "bottomleft", text = "Bottom Left" },
	{ key = "topright", text = "Top Right" },
	{ key = "topleft", text = "Top Left" },
	{ key = "right", text = "Right" },
	{ key = "left", text = "Left" },
	{ key = "top", text = "Top" },
	{ key = "bottom", text = "Bottom" },
	{ key = "center", text = "Center" },
}
local SHOW_MODES = {
	{ key = "always", text = "Always" },
	{ key = "outOfCombat", text = "Out of Combat" },
	{ key = "outOfBossCombat", text = "Out of Boss Combat" },
	{ key = "never", text = "Never" },
}
local GROWTH = {
	{ key = "default", text = "Default" },
	{ key = "up", text = "Expand Up" },
	{ key = "down", text = "Expand Down" },
}
local BUFF_POSITIONS = {
	{ key = "bottom", text = "Bottom" },
	{ key = "top", text = "Top" },
	{ key = "left", text = "Left" },
	{ key = "right", text = "Right" },
}
local EXTRAS = {
	{ key = "tooltipPlayerTitles", text = "Player Titles" },
	{ key = "tooltipItemLevel", text = "Item Level" },
	{ key = "tooltipShowMount", text = "Mount" },
	{ key = "tooltipShowGuildRank", text = "Guild Rank" },
	{ key = "tooltipShowTarget", text = "Unit Target" },
	{ key = "uber", text = "Detailed Tooltips" },
}

-- Border Size slider + "Border Options" cog (color mode, custom color, Show Behind).
local function BorderRows(p, prefix, label, isOff)
	p:Slider(label, "Border thickness in pixels. 0 hides the border.", 0, 4, 1,
		function() return TT.BorderSize(prefix) end,
		function(v) DB()[prefix .. "BorderThicknessPx"] = v end, isOff)
	p:Cog("Border Options", {
		{ type = "dropdown", label = "Color",
		  items = function() return KeyItems(BORDER_COLOR_MODES) end,
		  get = function() return DB()[prefix .. "BorderColorMode"] or "custom" end,
		  set = function(v) DB()[prefix .. "BorderColorMode"] = v end,
		  labelFn = function() return KeyLabel(BORDER_COLOR_MODES, DB()[prefix .. "BorderColorMode"] or "custom") end },
		{ type = "color", label = "Custom Color", alpha = true,
		  get = function()
			  local c = DB()[prefix .. "BorderColor"]
			  local a = DB()[prefix .. "BorderOpacity"]
			  if a == nil then a = BS.RESKIN.BRD_ALPHA end
			  return (c and c.r) or 1, (c and c.g) or 1, (c and c.b) or 1, a
		  end,
		  set = function(r, g, b, a)
			  DB()[prefix .. "BorderColor"] = { r = r, g = g, b = b }
			  DB()[prefix .. "BorderOpacity"] = a
		  end,
		  disabled = function() return (DB()[prefix .. "BorderColorMode"] or "custom") ~= "custom" end },
		{ type = "toggle", label = "Show Behind",
		  get = function() return DB()[prefix .. "BorderBehind"] or false end,
		  set = function(v) DB()[prefix .. "BorderBehind"] = v end },
	}, { icon = "directions", disabled = isOff, disabledTip = "Turn the reskin on first." })
end

local function Build(p)
	local function popupOff()
		return Get("reskinPopupsMenus") == false or TT.ElvUIMiscOn()
	end
	local function ttOff()
		return Get("customTooltips") == false or TT.ElvUITooltipOn()
	end

	-------------------------------------------------------------------------
	p:Section("Blizzard Popups & Game Menu")
	p:Toggle("Reskin Popups and Menus", "Reskins Blizzard's right-click context menus and pop-up dialogs with the EUI dark style. Requires reload to apply. While ElvUI's Misc skin is on, ElvUI skins them.",
		function() return Get("reskinPopupsMenus") ~= false end,
		function(v)
			DB().reskinPopupsMenus = v
			BS.AskReload()
		end)
	p:Toggle("Resurrect Accept Glow", "Adds a glowing, pulsing border around the Accept button of resurrection popups so a pending resurrect is hard to miss. Follows the Element & Text Color setting. Applies instantly.",
		Getter("resurrectAcceptGlow"), Setter("resurrectAcceptGlow"))

	BorderRows(p, "popupMenu", "Border Size", popupOff)
	BorderRows(p, "popupMenuButton", "Button Border Size", popupOff)

	p:ColorRow("Button Background", "Background color of the popup and menu buttons.",
		function()
			local c = DB().popupMenuButtonBackgroundColor or { r = 0.1, g = 0.1, b = 0.1, a = 0.8 }
			return c.r, c.g, c.b, c.a == nil and 0.8 or c.a
		end,
		function(r, g, b, a) DB().popupMenuButtonBackgroundColor = { r = r, g = g, b = b, a = a } end,
		{ alpha = true }, popupOff)
	p:Dropdown("Element & Text Color", "Color of popup button text, the game menu title and spell tooltip titles. Native Colors keeps Blizzard's colors.",
		function() return KeyItems(ELEMENT_MODES) end,
		function() return TT.ElementMode() end,
		function() return KeyLabel(ELEMENT_MODES, TT.ElementMode()) end,
		function(v) DB().popupMenuButtonTextColorMode = v end, nil, popupOff)
	p:Swatch("Custom Color",
		function()
			local c = DB().popupMenuButtonTextColor or { r = 1, g = 1, b = 1 }
			return c.r, c.g, c.b, 1
		end,
		function(r, g, b) DB().popupMenuButtonTextColor = { r = r, g = g, b = b } end,
		{ disabled = function() return TT.ElementMode() ~= "custom" end })

	p:Slider("Font Size Scale %", "Scales the font size of reskinned Blizzard tooltips.", 70, 150, 5,
		function() return math.floor((Get("tooltipFontScale") or 1) * 100 + 0.5) end,
		function(v) DB().tooltipFontScale = v / 100 end, ttOff)
	p:Toggle("Reskin Queue Popup", "Reskins the dungeon queue accept popup, its status panel and the role check popup with the EUI dark style. Requires reload to apply. While ElvUI's LFG skin is on, ElvUI skins them.",
		function() return Get("reskinQueuePopup") ~= false end,
		function(v)
			DB().reskinQueuePopup = v
			BS.AskReload()
		end)

	local function timerOff()
		return Get("showQueueTimer") == false
	end
	local function TimerSet(key)
		return function(v) DB()[key] = v end
	end
	p:Toggle("Show Queue Timer", "Shows a countdown bar on the queue accept popup with the time left to accept. Works with or without the reskin. The swatch and cog set the countdown text color, text size, bar height and text offset.",
		function() return Get("showQueueTimer") ~= false end, Setter("showQueueTimer"))
	p:Swatch("Countdown Text Color",
		function()
			local c = DB().queueTimerTextColor
			local QT = BS.QUEUE_TIMER
			return (c and c.r) or QT.TEXT_R, (c and c.g) or QT.TEXT_G, (c and c.b) or QT.TEXT_B, 1
		end,
		function(r, g, b) DB().queueTimerTextColor = { r = r, g = g, b = b } end,
		{ disabled = timerOff })
	p:Cog("Queue Timer Style", {
		{ type = "slider", label = "Text Size", min = 6, max = 24, step = 1,
		  get = function() return DB().queueTimerTextSize or BS.QUEUE_TIMER.TEXT_SIZE end, set = TimerSet("queueTimerTextSize") },
		{ type = "slider", label = "Bar Height", min = 4, max = 24, step = 1,
		  get = function() return DB().queueTimerBarHeight or BS.QUEUE_TIMER.BAR_HEIGHT end, set = TimerSet("queueTimerBarHeight") },
		{ type = "slider", label = "Text Offset Y", min = -20, max = 20, step = 1,
		  tip = "Moves the countdown number up or down on the bar.",
		  get = function() return DB().queueTimerTextOffsetY or BS.QUEUE_TIMER.TEXT_OFFSET_Y end, set = TimerSet("queueTimerTextOffsetY") },
	}, { disabled = timerOff, disabledTip = "Turn on Show Queue Timer first." })
	p:Toggle("Enable Blizzard Pause Menu", "Reskins the Escape / Game Menu with the EUI dark style, matching fonts and a colored title. Requires reload to apply.",
		function() return Get("reskinGameMenu") ~= false end,
		function(v)
			DB().reskinGameMenu = v
			BS.AskReload()
		end)

	-------------------------------------------------------------------------
	p:Section("Blizzard Tooltip")
	p:Toggle("Reskin Tooltip", "Reskins Blizzard tooltips with a dark, minimal style matching the EUI look. Turns the tooltip options below on or off. Requires reload to apply. While ElvUI's tooltip module is on, ElvUI runs the tooltips.",
		function() return Get("customTooltips") ~= false end,
		function(v)
			DB().customTooltips = v
			BS.AskReload()
		end)
	p:Toggle("Anchor to Cursor", "Makes the game tooltip follow your mouse cursor instead of its screen position (drag the Tooltip box in Unlock Mode to change that). The arrows icon sets the position next to the cursor and the X / Y offset.",
		Getter("tooltipAnchorCursor"), Setter("tooltipAnchorCursor"), ttOff)
	p:Cog("Cursor Tooltip Position", {
		{ type = "dropdown", label = "Position",
		  items = function() return KeyItems(CURSOR_POSITIONS) end,
		  get = Getter("tooltipCursorPosition"), set = Setter("tooltipCursorPosition"),
		  labelFn = function() return KeyLabel(CURSOR_POSITIONS, Get("tooltipCursorPosition")) end },
		{ type = "slider", label = "Offset X", min = -100, max = 100, step = 1,
		  get = Getter("tooltipCursorOffsetX"), set = Setter("tooltipCursorOffsetX") },
		{ type = "slider", label = "Offset Y", min = -100, max = 100, step = 1,
		  get = Getter("tooltipCursorOffsetY"), set = Setter("tooltipCursorOffsetY") },
	}, { icon = "directions", disabled = function() return ttOff() or not Get("tooltipAnchorCursor") end,
		disabledTip = "Turn on Anchor to Cursor first." })

	p:MultiSelect("Tooltip Extras", "Extra lines on tooltips: player titles, item level, mount (only mounts you own can be found in this game version), guild rank, unit target and detailed tooltips. Detailed Tooltips works without the reskin.",
		function() return KeyItems(EXTRAS) end,
		function(key)
			if key == "uber" then
				return GetCVar("UberTooltips") == "1"
			end
			return Get(key) and true or false
		end,
		function(key)
			if key == "uber" then
				TT.SetUberTooltips(GetCVar("UberTooltips") ~= "1")
			else
				DB()[key] = not Get(key)
			end
		end,
		function()
			local names = {}
			for _, e in ipairs(EXTRAS) do
				local on
				if e.key == "uber" then
					on = GetCVar("UberTooltips") == "1"
				else
					on = Get(e.key)
				end
				if on then
					names[#names + 1] = e.text
				end
			end
			return #names == 0 and "None" or table.concat(names, ", ")
		end)
	local function stripOff()
		return Get("tooltipHideHealthStrip") ~= false
	end
	p:Toggle("Show Health Strip", "Shows the health bar along the bottom of unit tooltips. The cog sets its texture and height.",
		function() return not stripOff() end,
		function(v) DB().tooltipHideHealthStrip = not v end,
		function() return TT.ElvUITooltipOn() end)
	p:Cog("Health Strip", {
		{ type = "dropdown", label = "Texture",
		  items = function()
			  local items = { { name = "Blizzard", value = "blizzard" } }
			  if ns.GetBarTextures then
				  for _, it in ipairs(U.MediaItems(ns.GetBarTextures())) do
					  items[#items + 1] = it
				  end
			  end
			  return items
		  end,
		  get = function() return DB().tooltipHealthStripTexture or "blizzard" end,
		  set = function(v) DB().tooltipHealthStripTexture = (v ~= "blizzard") and v or nil end },
		{ type = "slider", label = "Height", min = 1, max = 8, step = 1,
		  get = Getter("tooltipHealthStripHeight"), set = Setter("tooltipHealthStripHeight") },
	}, { disabled = function() return ttOff() or stripOff() end, disabledTip = "Needs Reskin Tooltip and Show Health Strip." })

	p:ColorRow("Background Color", "Background color of Blizzard tooltips.",
		function()
			local r, g, b = TT.GetTooltipBg()
			return r, g, b, 1
		end,
		function(r, g, b) DB().tooltipBgColor = { r = r, g = g, b = b } end, nil, ttOff)
	p:Slider("Background Opacity", "Background opacity of Blizzard tooltips.", 0, 100, 1,
		function()
			local _, _, _, a = TT.GetTooltipBg()
			return math.floor(a * 100 + 0.5)
		end,
		function(v) DB().tooltipBgOpacity = v / 100 end, ttOff)

	p:Dropdown("Show Tooltips", "Controls when game tooltips appear. The cog sets a modifier key that shows a hidden tooltip while held.",
		function() return KeyItems(SHOW_MODES) end,
		Getter("tooltipShowMode"),
		function() return KeyLabel(SHOW_MODES, Get("tooltipShowMode")) end,
		Setter("tooltipShowMode"), nil, ttOff)
	p:Cog("Show Tooltips", {
		{ type = "dropdown", label = "Peek Modifier",
		  items = function() return KeyItems(MODIFIERS) end,
		  get = Getter("tooltipShowModifier"), set = Setter("tooltipShowModifier"),
		  labelFn = function() return KeyLabel(MODIFIERS, Get("tooltipShowModifier")) end },
	}, { disabled = function() return ttOff() or (Get("tooltipShowMode") or "always") == "always" end,
		disabledTip = "Set Show Tooltips to a mode that hides tooltips first." })
	p:Toggle("Show Spell ID on Tooltip", "Adds the spell or item ID to tooltips. The same setting as Global Settings > Developer.",
		function() return CoreDB().showSpellID or false end,
		function(v) CoreDB().showSpellID = v end)
	p:Cog("Spell ID", {
		{ type = "toggle", label = "Show Item ID",
		  get = function() return CoreDB().showItemID ~= false end,
		  set = function(v) CoreDB().showItemID = v end },
	}, { disabled = function() return not CoreDB().showSpellID end, disabledTip = "Turn on Show Spell ID on Tooltip first." })

	BorderRows(p, "tooltip", "Border Size", ttOff)
	p:Toggle("Show Max Stack for Items", "Adds an item's max stack count to its tooltip.",
		Getter("showItemMaxStacks"), Setter("showItemMaxStacks"))
	p:Cog("Item Stacks", {
		{ type = "dropdown", label = "Use Modifier",
		  items = function() return KeyItems(MODIFIERS) end,
		  get = Getter("itemStackModifier"), set = Setter("itemStackModifier"),
		  labelFn = function() return KeyLabel(MODIFIERS, Get("itemStackModifier")) end },
	}, { disabled = function() return not Get("showItemMaxStacks") end, disabledTip = "Turn on Show Max Stack for Items first." })

	p:Dropdown("Growth Direction", "Which way the default screen tooltip grows as lines are added. Default lets Blizzard decide (or, with a position set in Unlock Mode, the side of the screen decides). Not used while Anchor to Cursor is on.",
		function() return KeyItems(GROWTH) end,
		Getter("tooltipGrowthDirection"),
		function() return KeyLabel(GROWTH, Get("tooltipGrowthDirection")) end,
		Setter("tooltipGrowthDirection"), nil,
		function() return ttOff() or Get("tooltipAnchorCursor") end)
	p:Button("Tooltip Position", "Sets the tooltip back to Blizzard's default screen position (the Tooltip box in Unlock Mode moves it).", "Reset Position",
		function() TT.ResetFixedPosition() end)

	p:Toggle("Show Player Buffs", "Shows a player's buffs as icons next to their tooltip.",
		Getter("tooltipShowBuffs"), Setter("tooltipShowBuffs"), ttOff)
	p:Cog("Tooltip Buffs", {
		{ type = "dropdown", label = "Position",
		  items = function() return KeyItems(BUFF_POSITIONS) end,
		  get = Getter("tooltipBuffPosition"), set = Setter("tooltipBuffPosition"),
		  labelFn = function() return KeyLabel(BUFF_POSITIONS, Get("tooltipBuffPosition")) end },
		{ type = "slider", label = "Icon Size", min = 12, max = 40, step = 1,
		  get = Getter("tooltipBuffSize"), set = Setter("tooltipBuffSize") },
		{ type = "slider", label = "Icons Per Row", min = 1, max = 16, step = 1,
		  get = Getter("tooltipBuffsPerRow"), set = Setter("tooltipBuffsPerRow") },
		{ type = "slider", label = "Offset X", min = -100, max = 100, step = 1,
		  get = Getter("tooltipBuffOffsetX"), set = Setter("tooltipBuffOffsetX") },
		{ type = "slider", label = "Offset Y", min = -100, max = 100, step = 1,
		  get = Getter("tooltipBuffOffsetY"), set = Setter("tooltipBuffOffsetY") },
	}, { icon = "directions", disabled = function() return ttOff() or not Get("tooltipShowBuffs") end,
		disabledTip = "Turn on Show Player Buffs first." })
	p:Blank()

	-- "Blizzard HUD" section (HUD skin file).
	if ns.BlizzSkinHUDOptions then
		ns.BlizzSkinHUDOptions(p)
	end
end

ns.BlizzSkinOptionTabs = ns.BlizzSkinOptionTabs or {}
table.insert(ns.BlizzSkinOptionTabs, {
	order = 30,
	tab = {
		key = "tooltips",
		name = "Tooltips, Menus & Popups",
		description = "EllesmereUI style for Blizzard tooltips, right-click menus, pop-up dialogs, the queue popups and the game menu, plus tooltip position and extra tooltip lines.",
		build = Build,
	},
})
