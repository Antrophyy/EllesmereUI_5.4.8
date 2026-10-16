-- Settings pages of Blizzard Skins: Window Skins (global look + one style
-- per window), Character Sheet, and the tabs other EUI_BlizzardSkin_*_Options
-- files add (Tooltips, Menus & Popups; Chat Bubbles; ...).
-- Part of EllesmereUIOptions (load on demand); skipped when EllesmereUIBlizzardSkin is not loaded.
--
-- Other option files of this module add tabs with:
--   ns.BlizzSkinOptionTabs = ns.BlizzSkinOptionTabs or {}
--   table.insert(ns.BlizzSkinOptionTabs, { order = 30, tab = { key =, name =, description =, build = fn } })
-- (they load before this file, see EllesmereUIOptions.toc).

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUIBlizzardSkin") then
	return
end

local U = ns.OptionsUtil
local KeyItems, KeyLabel = U.KeyItems, U.KeyLabel
local BS = ns.BlizzSkin
local WSkin = ns.WSkin

local function CS()
	return ns.GetCharSheetDB()
end

---------------------------------------------------------------------------
-- Window Skins
---------------------------------------------------------------------------
local WINDOW_STYLES = {
	{ key = "eui", text = "EllesmereUI" },
	{ key = "modern", text = "Modern" },
	{ key = "off", text = "Off" },
}

-- Look tables (retail EllesmereUIDB.blizzWin*; here in EllesmereUIBlizzardSkinDB).
local function Look(key)
	local c = BS.DB()[key]
	if type(c) ~= "table" then
		c = {}
		BS.DB()[key] = c
	end
	return c
end

local COLOR_MODES = {
	{ key = "accent", text = "Accent Color" },
	{ key = "custom", text = "Custom Color" },
}

local function LookColorRows(p, key, label, description, isDisabled)
	p:Dropdown(label, description,
		function() return KeyItems(COLOR_MODES) end,
		function() return Look(key).useCustom and "custom" or "accent" end,
		function() return Look(key).useCustom and "Custom Color" or "Accent Color" end,
		function(v) Look(key).useCustom = v == "custom" end, nil, isDisabled)
	p:ColorRow(label .. " (Custom)", "The color used when " .. label .. " is Custom Color.",
		function()
			local col = Look(key).color
			if col then return col.r or 1, col.g or 1, col.b or 1, 1 end
			return 1, 1, 1, 1
		end,
		function(r, g, b)
			Look(key).color = { r = r, g = g, b = b }
		end, nil,
		function() return (isDisabled and isDisabled()) or not Look(key).useCustom end)
end

local function StyleChange(winKey, newStyle)
	local old = BS.GetWindowStyle(winKey)
	BS.SetWindowStyle(winKey, newStyle)
	-- eui <-> modern applies live; on <-> off needs a reload (skins install at load).
	if (old == "off") ~= (newStyle == "off") then
		return true
	end
	return false
end

local WINDOW_SKINS_PAGE = {
	key = "windowSkins",
	name = "Window Skins",
	description = "EllesmereUI skins for Blizzard windows. EllesmereUI: the EllesmereUI art background. Modern: a flat background color. Off: Blizzard's window. Turning a window on or off needs a UI reload.",
	build = function(p)
		p:Section("Set All Windows")
		p:Dropdown("All Windows", "Sets every window below (not the Character Sheet) to one style.",
			function() return KeyItems(WINDOW_STYLES) end,
			function() return nil end,
			function() return "Choose..." end,
			function(v)
				local reload = false
				for _, e in ipairs(WSkin.WindowList()) do
					if e.key ~= "charsheet" and e.key ~= "inspect" then
						if StyleChange(e.key, v) then
							reload = true
						end
					end
				end
				if reload then
					BS.AskReload()
				end
			end)

		p:Section("Global Options")
		p:ColorRow("Modern Background", "Background color and opacity of every window on the Modern style.",
			function() return WSkin.GetModernBG() end,
			function(r, g, b, a)
				BS.DB().blizzWindowModernDefault = { r = r, g = g, b = b, a = a or 0.97 }
			end, { alpha = true })
		p:Toggle("Show Accent Bar", "Accent bar on the active tab of reskinned windows.",
			function() return Look("blizzWinAccentBar").enabled ~= false end,
			function(v) Look("blizzWinAccentBar").enabled = v and true or false end)
		LookColorRows(p, "blizzWinAccentBar", "Accent Bar Color", "Color of the accent bar under the active tab.",
			function() return Look("blizzWinAccentBar").enabled == false end)
		LookColorRows(p, "blizzWinBarFill", "Bar Fill Color", "Fill color of the progress bars in reskinned windows (reputation, achievements, ...).")
		p:Slider("Bar Fill Opacity", "Opacity of the progress bar fill.", 10, 100, 1,
			function() return math.floor(((Look("blizzWinBarFill").alpha) or 0.95) * 100 + 0.5) end,
			function(v) Look("blizzWinBarFill").alpha = v / 100 end)
		LookColorRows(p, "blizzWinLinks", "Link Color", "Color of links and highlighted names in reskinned windows.")

		p:Section("Windows")
		local list = WSkin.WindowList()
		for _, e in ipairs(list) do
			if e.key ~= "charsheet" and e.key ~= "inspect" then
				local winKey = e.key
				local desc = e.description or ""
				if e.elvui then
					desc = desc .. " While ElvUI's own skin for this window is on (ElvUI > Skins), ElvUI's skin is used."
				end
				p:Dropdown(e.label, desc,
					function() return KeyItems(WINDOW_STYLES) end,
					function() return BS.GetWindowStyle(winKey) end,
					function()
						local label = KeyLabel(WINDOW_STYLES, BS.GetWindowStyle(winKey))
						if WSkin.ElvUIOwns(winKey) then
							label = label .. " (ElvUI)"
						end
						return label
					end,
					function(v)
						if StyleChange(winKey, v) then
							BS.AskReload()
						end
					end)
				-- A window's own extra settings (merchant list, loot toast strip, ...):
				-- RegisterWindow{ options = function(p, U) ... end } in the skin file.
				for _, w in ipairs(WSkin.windows) do
					if w.key == winKey and w.options then
						w.options(p, U)
					end
				end
			end
		end
	end,
}

---------------------------------------------------------------------------
-- Character Sheet
---------------------------------------------------------------------------
local CHARACTER_SHEET_PAGE = {
	key = "characterSheet",
	name = "Character Sheet",
	description = "Equipment panel with stat categories, item level, enchants and gems. The inspect sheet follows its style.",
	build = function(p)
		local function off() return CS().style == "off" end
		local function stock() return CS().style == "blizzard" end
		-- Blizz Default keeps Blizzard's own slots: gems, icon zoom and slot
		-- borders are the EllesmereUI sheet's own.
		local function stockOrOff() return off() or stock() end
		local function sectionOff(key) return function() return off() or CS().sections[key] == false end end
		local function blizzColorsOn() return stock() and CS().blizzColors end

		p:Section("Style")
		p:Dropdown("Character Sheet", "EllesmereUI: the EllesmereUI sheet. Modern: the same sheet on a flat background. Blizz Default: Blizzard's sheet with the EllesmereUI stats and slot text. Off: Blizzard's sheet only. Changing between EllesmereUI / Modern and the others needs a UI reload.",
			function() return KeyItems(ns.CHARSHEET_STYLES) end,
			function() return CS().style end,
			function() return KeyLabel(ns.CHARSHEET_STYLES, CS().style) end,
			function(v) ns.SetCharSheetStyle(v) end)
		p:Color("Modern Background", "Background color of the Modern style.", function() return CS().modernColor end,
			function() return CS().style ~= "modern" end)
		p:Slider("Modern Opacity %", "Background opacity of the Modern style.", 0, 100, 1,
			function() return CS().modernAlpha end, function(v) CS().modernAlpha = v end,
			function() return CS().style ~= "modern" end)
		-- Size: EllesmereUI and Modern only (Blizz Default keeps Blizzard's layout).
		local function sizeOff() return off() or stock() end
		p:Slider("Width", "Width of the character sheet, on every tab. EllesmereUI's sheet is 540. The right slot column and the stats move with the right edge; the model gets wider. The Reputation and Currency lists use the full width.", 540, 900, 10,
			function() return CS().width end, function(v) CS().width = v end, sizeOff)
		p:Slider("Height", "Height of the character sheet, on every tab. EllesmereUI's sheet is 424. The slot rows spread out; the model and the stats get taller; the Reputation and Currency lists show more rows.", 424, 720, 4,
			function() return CS().height end, function(v) CS().height = v end, sizeOff)

		p:Section("Core Options")
		local ITEM_DETAILS = {
			{ key = "showItemLevel", text = "Item Level" },
			{ key = "showUpgradeTrack", text = "Upgrade Level" },
			{ key = "charSheetItemStats", text = "Stat Letters" },
			{ key = "showGems", text = "Gems" },
		}
		p:MultiSelect("Item Details", "Choose what shows on each equipped item. Upgrade Level is the item upgrade (for example 1/2). Stat Letters are the item's secondary stats (C Crit, H Haste, M Mastery, Hit, Exp, S Spirit, D Dodge, P Parry). Gems are not shown with Blizz Default.",
			function() return KeyItems(ITEM_DETAILS) end,
			function(key) return CS()[key] end,
			function(key) CS()[key] = not CS()[key] end,
			function()
				local names = {}
				for i = 1, #ITEM_DETAILS do
					if CS()[ITEM_DETAILS[i].key] then
						names[#names + 1] = ITEM_DETAILS[i].text
					end
				end
				return #names == 0 and "None" or table.concat(names, ", ")
			end, off)
		p:Slider("Icon Zoom %", "Crops the border of the equipment slot icons. 0 shows the full icon. Only for the EllesmereUI and Modern styles.", 0, 20, 1,
			function() return CS().iconZoom end, function(v) CS().iconZoom = v end, stockOrOff)
		p:Dropdown("Enchants", "How enchants show beside each item. Text: the enchant name. Colored Text: the name with an outline, in the item level color. A level 90 item without an enchant shows a red 'Missing' and a pulsing red border.",
			function() return KeyItems(ns.CHARSHEET_ENCHANT_MODES) end,
			function()
				if not CS().showEnchants then return "none" end
				return CS().enchantNames and "text" or "icons"
			end,
			function()
				local mode = not CS().showEnchants and "none" or (CS().enchantNames and "text" or "icons")
				return KeyLabel(ns.CHARSHEET_ENCHANT_MODES, mode)
			end,
			function(v)
				CS().showEnchants = v ~= "none"
				if v ~= "none" then
					CS().enchantNames = v == "text"
				end
			end, nil, off)
		p:Slider("Enchant Text Size", "Size of the enchant text.", 6, 20, 1,
			function() return CS().enchantSize end, function(v) CS().enchantSize = v end,
			function() return off() or not CS().showEnchants end)
		local ENCHANT_COLOR_MODES = {
			{ key = "default", text = "Default" },
			{ key = "custom", text = "Custom" },
		}
		p:Dropdown("Enchant Color", "Default: white for Text, the item level color for Colored Text. Custom: the color on the right, for both. 'Missing' stays red.",
			function() return KeyItems(ENCHANT_COLOR_MODES) end,
			function() return CS().enchantUseColor and "custom" or "default" end,
			function() return CS().enchantUseColor and "Custom" or "Default" end,
			function(v) CS().enchantUseColor = v == "custom" end, nil,
			function() return off() or not CS().showEnchants end)
		p:Color("Enchant Text Color", "Enchant text color when Enchant Color is Custom.", function() return CS().enchantColor end,
			function() return off() or not CS().showEnchants or not CS().enchantUseColor end)
		p:Toggle("Gear Flyout Item Levels", "Shows the item level on each item in the gear flyout (the popup of same-slot bag items next to an equipped slot), colored by quality.",
			function() return CS().flyoutItemLevels end, function(v) CS().flyoutItemLevels = v end, off)
		p:Toggle("Gear Flyout Item Stats", "Shows each item's secondary stat letters (C Crit, H Haste, M Mastery, ...) in the gear flyout.",
			function() return CS().flyoutItemStats end, function(v) CS().flyoutItemStats = v end, off)
		p:Toggle("Hide Slot Flyout Arrows", "Hide the arrows beside the equipment slots. The slot flyouts still work (hold Alt over a slot).",
			function() return CS().hideSlotFlyoutArrows end, function(v) CS().hideSlotFlyoutArrows = v end, off)
		p:Toggle("Show Item Durability", "Show the equipped durability (the lowest item), colored from green to red.",
			function() return CS().showDurability end, function(v) CS().showDurability = v end, off)
		p:Dropdown("Durability Location", "Where the durability shows. With Blizz Default, Frame Footer shows in the stats header.",
			function() return KeyItems(ns.CHARSHEET_DURABILITY_LOCATIONS) end,
			function() return CS().durabilityLocation end,
			function() return KeyLabel(ns.CHARSHEET_DURABILITY_LOCATIONS, CS().durabilityLocation) end,
			function(v) CS().durabilityLocation = v end, nil,
			function() return off() or not CS().showDurability end)
		p:Toggle("Durability Label", "Prefix the durability percent with \"Durability:\".",
			function() return CS().durabilityShowLabel end, function(v) CS().durabilityShowLabel = v end,
			function() return off() or not CS().showDurability end)

		p:Section("Stat Display")
		p:MultiSelect("Stat Sections", "The stat sections on the sheet. Click a section title on the sheet to collapse it; the arrows move it up or down.",
			function() return KeyItems(ns.CHARSHEET_SECTIONS) end,
			function(key) return CS().sections[key] ~= false end,
			function(key) CS().sections[key] = CS().sections[key] == false end,
			function()
				local names = {}
				for i = 1, #ns.CHARSHEET_SECTIONS do
					if CS().sections[ns.CHARSHEET_SECTIONS[i].key] ~= false then
						names[#names + 1] = ns.CHARSHEET_SECTIONS[i].text
					end
				end
				if #names == #ns.CHARSHEET_SECTIONS then
					return "All sections"
				end
				return #names == 0 and "None" or table.concat(names, ", ")
			end, off)
		p:Dropdown("Secondary Text", "How Secondary stat values are shown.",
			function() return KeyItems(ns.CHARSHEET_SECONDARY_TEXT) end,
			function() return CS().secondaryText end,
			function() return KeyLabel(ns.CHARSHEET_SECONDARY_TEXT, CS().secondaryText) end,
			function(v) CS().secondaryText = v end, nil, sectionOff("Secondary"))
		p:Toggle("Secondary Highlights", "Hovering a Secondary stat highlights the gear that has it.",
			function() return CS().secondaryHighlights end, function(v) CS().secondaryHighlights = v end, sectionOff("Secondary"))
		p:Toggle("Show Mana", "Adds Mana to the Attributes section.",
			function() return CS().showMana end, function(v) CS().showMana = v end, sectionOff("Attributes"))
		local CURRENCIES = {
			{ key = "showValor", text = "Valor" },
			{ key = "showJustice", text = "Justice" },
		}
		p:MultiSelect("Currencies", "The points shown in the Currencies section (in place of the retail crests).",
			function() return KeyItems(CURRENCIES) end,
			function(key) return CS()[key] end,
			function(key) CS()[key] = not CS()[key] end,
			function()
				local names = {}
				for i = 1, #CURRENCIES do
					if CS()[CURRENCIES[i].key] then
						names[#names + 1] = CURRENCIES[i].text
					end
				end
				return #names == 0 and "None" or table.concat(names, ", ")
			end, sectionOff("Currencies"))
		p:Toggle("Blizzard UI Color", "Blizz Default only: shows the item level and stat titles in Blizzard's yellow.",
			function() return CS().blizzColors end, function(v) CS().blizzColors = v end,
			function() return not stock() end)

		p:Section("Section Colors")
		for i = 1, #ns.CHARSHEET_SECTIONS do
			local s = ns.CHARSHEET_SECTIONS[i]
			p:Color(s.text, "Color of the " .. s.text .. " title, lines and values. Not used while Blizzard UI Color is on.",
				function() return CS().colors[s.key] end,
				function() return off() or CS().sections[s.key] == false or blizzColorsOn() end)
		end
		p:Button("Default colors", "Set all section colors back to the default.", "Reset colors", function()
			ns.ResetCharSheetColors()
		end)

		-- Inspect sheet / socket panel settings (their skin files add these).
		for _, fn in ipairs(ns.BlizzSkinCharSheetOptions or {}) do
			fn(p, U)
		end
	end,
}

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------
local entries = {
	{ order = 10, tab = WINDOW_SKINS_PAGE },
	{ order = 20, tab = CHARACTER_SHEET_PAGE },
}
for _, e in ipairs(ns.BlizzSkinOptionTabs or {}) do
	entries[#entries + 1] = e
end
table.sort(entries, function(a, b) return (a.order or 100) < (b.order or 100) end)
local tabs = {}
for i = 1, #entries do
	tabs[i] = entries[i].tab
end

ns.RegisterSettingsModule({
	-- EllesmereUI: Blizzard Skins (Window Skins, Tooltips, Chat Bubbles, ...).
	key = "blizzardSkins",
	name = "Blizzard Skins",
	group = "UI Reskin Addons",
	tabs = tabs,
	reset = function()
		ns.ResetCharSheetSettings()
		local db = BS.DB()
		local keep = { charSheet = true, blizzWindowSkinStyles = true }
		for k in pairs(db) do
			if not keep[k] then
				db[k] = nil
			end
		end
		BS.ApplyAll()
	end,
	resetTip = "Set all Blizzard Skins settings back to default. The window and Character Sheet styles are kept.",
})
