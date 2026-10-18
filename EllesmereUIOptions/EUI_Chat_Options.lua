-- Settings page of UI Reskin Addons > Chat (EllesmereUI EUI_Chat_Options.lua:
-- the same pages, sections, labels, tooltips and keys). Rows that need a
-- retail-only part are left out: Border Style textures (only Solid in
-- 5.4.8), the Blizzard / Classic styles, M+ Portals, Chat Bubbles. Font and
-- outline changes apply live (retail asks for a reload).
-- Part of EllesmereUIOptions (load on demand); skipped when EllesmereUIChat
-- is not loaded.

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUIChat") then
	return
end
local ECHAT = ns.ECHAT
if not ECHAT then
	return
end
local U = ns.OptionsUtil

local function DB()
	return ECHAT.DB()
end

local function Getter(key, default)
	return function()
		local v = DB()[key]
		if v == nil then
			return default
		end
		return v
	end
end

local function Setter(key, after)
	return function(v)
		DB()[key] = v
		if after then
			after(v)
		end
	end
end

local function Items(list)
	local out = {}
	for i = 1, #list do
		if list[i] == "---" then
			out[i] = { separator = true, name = "", value = "---" }
		else
			out[i] = { value = list[i][1], name = list[i][2] }
		end
	end
	return out
end

local function LabelOf(list, value)
	for i = 1, #list do
		if type(list[i]) == "table" and list[i][1] == value then
			return list[i][2]
		end
	end
	return tostring(value or "")
end

local function KeyDropdown(p, label, tip, list, key, default, isDisabled, onSet, options)
	p:Dropdown(label, tip,
		function() return Items(list) end,
		function() local v = DB()[key]; if v == nil then v = default end; return v end,
		function() local v = DB()[key]; if v == nil then v = default end; return LabelOf(list, v) end,
		function(v)
			DB()[key] = v
			if onSet then onSet(v) end
		end,
		options, isDisabled)
end

-- Fonts by name, "EUI Global Font" first (retail BuildFontDropdownData).
local function FontItems(withChat)
	local lead = {}
	if withChat then
		lead[#lead + 1] = { name = "Chat Font", value = "__chat" }
	end
	lead[#lead + 1] = { name = "EUI Global Font", value = "__global" }
	if U.FontItems then
		return U.FontItems(lead)
	end
	return lead
end

local function FontLabel(itemsFn, value)
	for _, item in ipairs(itemsFn()) do
		if item.value == value then
			return item.name
		end
	end
	return tostring(value or "")
end

local function FontPreview(value)
	if value == "__chat" then
		return ECHAT.GetFont()
	elseif value == "__global" then
		return ns.GetFontPath and ns.GetFontPath("chat")
	end
	return ns.ResolveFontName and ns.ResolveFontName(value)
end

local function FontDropdown(p, label, tip, key, withChat)
	local function List() return FontItems(withChat) end
	local default = withChat and "__chat" or "__global"
	p:Dropdown(label, tip, List,
		function() return DB()[key] or default end,
		function() return FontLabel(List, DB()[key] or default) end,
		function(v) DB()[key] = v end,
		{ fontPreview = true, fontPath = FontPreview })
end

local function TextureItems()
	local items = { { name = "None", value = "none" } }
	for _, t in ipairs(ns.GetBarTextures and ns.GetBarTextures() or {}) do
		items[#items + 1] = { name = t.name, value = t.path }
	end
	return items
end

local function TextureLabel(value)
	if not value or value == "none" then
		return "None"
	end
	return ns.GetBarTextureLabel and ns.GetBarTextureLabel(value) or value
end

local function TextureDropdown(p, label, tip, key)
	p:Dropdown(label, tip, TextureItems,
		function() return DB()[key] or "none" end,
		function() return TextureLabel(DB()[key]) end,
		function(v) DB()[key] = v end,
		{ texturePreview = true, previewPath = function(v) return (v == "none") and "" or v end })
end

local function AccentRGBA()
	return ECHAT.AccentColor()
end
local function ClassRGBA()
	return ECHAT.ClassColor()
end

-- Custom / Accent / Class swatches on a mode key (retail select-mode trio).
-- Added nearest the control first: Class, Accent, then Custom.
local function ModeSwatches(p, modeKey, colorKey, fallback, opts)
	opts = opts or {}
	local function Mode()
		return DB()[modeKey] or opts.defaultMode or "custom"
	end
	local function SetMode(m)
		DB()[modeKey] = m
		return true
	end
	if not opts.noClass then
		p:Swatch("Class Color", ClassRGBA, function() end,
			{ readonly = true, disabled = opts.disabled,
			  active = function() return Mode() == "class" end,
			  onClick = function() return SetMode("class") end })
	end
	p:Swatch("Accent Color", AccentRGBA, function() end,
		{ readonly = true, disabled = opts.disabled,
		  active = function() return Mode() == "accent" end,
		  onClick = function() return SetMode("accent") end })
	p:Swatch(opts.customTip or "Custom Color",
		function()
			local c = DB()[colorKey] or fallback
			local a = opts.alphaKey and DB()[opts.alphaKey]
			if a == nil then a = c.a end
			if a == nil then a = fallback.a or 1 end
			return c.r or fallback.r or 1, c.g or fallback.g or 1, c.b or fallback.b or 1, a
		end,
		function(r, g, b, a)
			if opts.alphaKey then
				DB()[colorKey] = { r = r, g = g, b = b }
				DB()[opts.alphaKey] = a
			else
				local old = DB()[colorKey] or fallback
				DB()[colorKey] = { r = r, g = g, b = b, a = opts.alpha and a or (old.a == nil and fallback.a or old.a) }
			end
			DB()[modeKey] = "custom"
		end,
		{ alpha = opts.alpha, disabled = opts.disabled,
		  active = function() return Mode() == "custom" end,
		  onClick = function()
			if Mode() ~= "custom" then
				return SetMode("custom")
			end
		  end })
end

-------------------------------------------------------------------------------
--  Visibility checklist (retail BuildVisibilityRow, no Mouseover for chat)
-------------------------------------------------------------------------------
local function Axis(key)
	for _, axis in ipairs(ECHAT.VIS_AXES) do
		if axis.key == key then
			return axis
		end
	end
end

local function VisibilityItems()
	local items = {
		{ value = "state:never", name = "Never" },
		{ value = "state:always", name = "Always" },
		{ value = "match:all", name = "Match All Conditions" },
		{ value = "match:any", name = "Match Any Condition" },
	}
	for _, axis in ipairs(ECHAT.VIS_AXES) do
		items[#items + 1] = { value = "show:" .. axis.key, name = "Show: " .. axis.label }
		items[#items + 1] = { value = "hide:" .. axis.key, name = "Hide: " .. axis.label }
	end
	return items
end

local function VisibilityRow(p)
	p:MultiSelect("Visibility", "When chat is shown. Never / Always is the base state; the Show conditions must match (all or any), a Hide condition always hides.",
		VisibilityItems,
		function(value)
			local s = DB()
			local kind, key = value:match("^(%a+):(.+)$")
			if kind == "state" then
				return ECHAT.VisBase(s) == key
			elseif kind == "match" then
				return (s.visibilityMatch or "all") == key
			end
			local axis = Axis(key)
			return ECHAT.VisFlag(s, kind == "show" and axis.show or axis.hide)
		end,
		function(value)
			local s = DB()
			local kind, key = value:match("^(%a+):(.+)$")
			if kind == "state" then
				ECHAT.SetVisBase(s, key)
			elseif kind == "match" then
				s.visibilityMatch = key
			else
				local axis = Axis(key)
				local lane = kind == "show" and axis.show or axis.hide
				local other = kind == "show" and axis.hide or axis.show
				local on = not ECHAT.VisFlag(s, lane)
				ECHAT.SetVisFlag(s, lane, on)
				if on then
					ECHAT.SetVisFlag(s, other, false)
				end
			end
			ECHAT.ResetIdleTimer()
		end,
		function()
			local s = DB()
			local base = ECHAT.VisBase(s)
			local text = base == "never" and "Never" or "Always"
			local n = 0
			for _, axis in ipairs(ECHAT.VIS_AXES) do
				if ECHAT.VisFlag(s, axis.show) or ECHAT.VisFlag(s, axis.hide) then
					n = n + 1
				end
			end
			if n > 0 and base ~= "never" then
				text = text .. " + " .. n .. (n == 1 and " condition" or " conditions")
			end
			return text
		end)
end

-------------------------------------------------------------------------------
--  Shared rows
-------------------------------------------------------------------------------
local OUTLINES = {
	{ "__global", "EUI Global Default" }, { "none", "Drop Shadow" }, { "outline", "Outline" }, { "thick", "Thick Outline" },
}
local BORDER_STEP_LABELS = { [0] = "None", "Thin", "Normal", "Heavy", "Strong" }

local function BorderSizeSlider(p, label, key, isDisabled, tip)
	p:Slider(label, tip, 0, 4, 1,
		function() return ECHAT.BORDER_STEP and ECHAT.BORDER_STEP(DB()[key]) or 0 end,
		function(v) DB()[key] = ECHAT.BORDER_LABEL(v) end,
		isDisabled)
end

-------------------------------------------------------------------------------
--  Chat page
-------------------------------------------------------------------------------
local function BuildChat(p)
	if ECHAT.IsDisabledByElvUI() then
		p:Paragraph("|cffff6060ElvUI's chat is on, so EllesmereUI Chat is off.|r Turn off ElvUI > Chat > Enable and reload to use it.")
	end

	-- DISPLAY -------------------------------------------------------------
	p:Section("Display")
	VisibilityRow(p)
	p:Toggle("Lock Main Chat Size", "Hides the resize handle on the main chat frame, preventing accidental resizing.",
		Getter("lockChatSize", false), Setter("lockChatSize"))

	p:Slider("Background Opacity", nil, 0, 1, 0.05, Getter("bgAlpha", 0.65), Setter("bgAlpha"))
	p:Swatch("Background Color",
		function() local c = DB(); return c.bgR or 0.03, c.bgG or 0.045, c.bgB or 0.05, 1 end,
		function(r, g, b) local c = DB(); c.bgR, c.bgG, c.bgB = r, g, b end)
	TextureDropdown(p, "Background Texture", "Texture drawn over the chat background color.", "bgTexture")

	FontDropdown(p, "Font", nil, "font", false)
	p:Cog("Font Settings", {
		{ type = "dropdown", label = "Outline Mode",
		  items = function() return Items(OUTLINES) end,
		  get = Getter("outlineMode", "__global"), set = Setter("outlineMode"),
		  labelFn = function() return LabelOf(OUTLINES, DB().outlineMode or "__global") end },
	})
	p:Slider("Font Size", "Applies one text size to every chat window, saved with your profile. Individual windows can still be adjusted from their tab's right-click menu until the next login re-applies the profile size.",
		8, 27, 1,
		function()
			local v = DB().chatFontSize
			if v then return v end
			local _, size = FCF_GetChatWindowInfo(1)
			return size or 14
		end,
		function(v)
			DB().chatFontSize = v
			ECHAT.ApplyChatFontSize(v)
		end)

	BorderSizeSlider(p, "Border Size", "panelBorderThickness")
	ModeSwatches(p, "panelBorderColorMode", "panelBorderColor", { r = 1, g = 1, b = 1, a = 0.18 },
		{ alpha = true, alphaKey = "panelBorderOpacity" })
	p:Cog("Border Options", {
		{ type = "toggle", label = "Show Behind", get = Getter("panelBorderBehind", false), set = Setter("panelBorderBehind") },
	}, { icon = "directions" })
	p:Blank()

	-- IDLE FADE -----------------------------------------------------------
	p:Section("Idle Fade")
	local function FadeOff() return DB().idleFadeEnabled == false end
	p:Toggle("Enable Idle Fade", nil, function() return DB().idleFadeEnabled ~= false end, Setter("idleFadeEnabled"))
	p:Slider("Fade Delay", nil, 5, 30, 1, Getter("idleFadeDelay", 15), Setter("idleFadeDelay"), FadeOff)
	p:Slider("Fade Strength", nil, 0, 100, 1, Getter("idleFadeStrength", 40), Setter("idleFadeStrength"), FadeOff)
	p:Blank()

	-- INPUT FIELD ---------------------------------------------------------
	p:Section("Input Field")
	p:Toggle("Input on Top", nil, Getter("inputOnTop", false), Setter("inputOnTop"))
	p:Slider("Edit Box Height", nil, 10, 60, 1, Getter("editBoxHeight", 23), Setter("editBoxHeight"))
	FontDropdown(p, "Edit Box Font", nil, "editBoxFont", true)
	p:Slider("Edit Box Font Size", nil, 8, 24, 1,
		function()
			local v = DB().editBoxFontSize
			if v then return v end
			local _, size = FCF_GetChatWindowInfo(1)
			return size or 12
		end,
		Setter("editBoxFontSize"))

	-- EXTRAS --------------------------------------------------------------
	p:Section("Extras")
	p:Toggle("Remember Last Chat Lines", "Saves the most recent lines per chat tab (per character), everything the tab shows except channel join / leave notices and Blizzard's combat log window, so they reappear after /reload or relog. Stored separately from layout profiles.",
		function() return DB().persistChatHistory == true end,
		Setter("persistChatHistory", function(v) ECHAT.OnSessionHistoryToggled(v) end))
	p:Cog("Session History", {
		{ type = "slider", label = "Max Lines to Keep", min = 20, max = 300, step = 10,
		  get = Getter("persistChatHistoryMaxLines", 100), set = Setter("persistChatHistoryMaxLines") },
	})
	p:Toggle("Hide Tooltip on Hover", nil, Getter("hideTooltipOnHover", false), Setter("hideTooltipOnHover"))

	p:Toggle("Hide Borders", nil, Getter("hideBorders", false), Setter("hideBorders"))
	local function InnerOff() return DB().hideBorders and true or false end
	p:Swatch("Inner Border Color",
		function() local r, g, b, a = ECHAT.InnerBorderColorCustom(); return r, g, b, a end,
		function(r, g, b, a)
			DB().innerBorderColor = { r = r, g = g, b = b, a = a }
			DB().innerBorderColorMode = "custom"
		end,
		{ alpha = true, disabled = InnerOff,
		  active = function() return (DB().innerBorderColorMode or "custom") == "custom" end,
		  onClick = function()
			if (DB().innerBorderColorMode or "custom") ~= "custom" then
				DB().innerBorderColorMode = "custom"
				return true
			end
		  end })
	p:Swatch("Accent Inner Border Color", AccentRGBA, function() end,
		{ readonly = true, disabled = InnerOff,
		  active = function() return DB().innerBorderColorMode == "accent" end,
		  onClick = function() DB().innerBorderColorMode = "accent"; return true end })
	if ECHAT.AppendSharedMediaSounds then
		ECHAT.AppendSharedMediaSounds()
	end
	p:Dropdown("Whisper Sound", "Blizzard Default keeps the game's whisper sound. Any other sound replaces it, and None plays no sound.",
		function()
			local items = {}
			for _, k in ipairs(ECHAT.WHISPER_SOUND_ORDER) do
				items[#items + 1] = { value = k, name = ECHAT.WHISPER_SOUND_NAMES[k] or k }
			end
			return items
		end,
		function() return DB().whisperSoundKey or "none" end,
		function() local k = DB().whisperSoundKey or "none"; return ECHAT.WHISPER_SOUND_NAMES[k] or k end,
		function(v)
			DB().whisperSoundKey = v
			local path = ECHAT.WHISPER_SOUND_PATHS[v]
			if path then
				PlaySoundFile(path, "Master")
			end
			ECHAT.ApplyWhisperMute()
		end)

	local TIMESTAMPS = {
		{ "__blizzard", "Use Blizzard Setting" }, { "none", "None" }, "---",
		{ "%I:%M ", "03:27" }, { "%I:%M:%S ", "03:27:32" }, { "%I:%M %p ", "03:27 PM" }, { "%I:%M:%S %p ", "03:27:32 PM" }, "---",
		{ "%H:%M ", "15:27" }, { "%H:%M:%S ", "15:27:32" },
	}
	p:Toggle("Timestamp All Messages", "Adds timestamps to system messages, loot, achievements, and addon messages, not just player chat.",
		function() return DB().timestampAll == true end, Setter("timestampAll"),
		function() return (DB().timestampFormat or "%I:%M ") == "none" end)
	KeyDropdown(p, "Timestamps", nil, TIMESTAMPS, "timestampFormat", "%I:%M ")

	p:Toggle("Shortened Channel Names", "Abbreviates channel prefixes, like [Party] to [P] and [Guild] to [G]; world channels show their number.",
		function() return DB().abbreviateChannels == true end, Setter("abbreviateChannels"))
	p:Cog("Shortened Channel Names", {
		{ type = "toggle", label = "Use Letters",
		  tip = "Shows General, Trade, Local Defense, World Defense and LFG as letters instead of their channel numbers.",
		  get = function() return DB().abbreviateChannelLetters == true end, set = Setter("abbreviateChannelLetters") },
	}, { disabled = function() return DB().abbreviateChannels ~= true end, disabledTip = "Shortened Channel Names" })
	p:Toggle("Class Colored Names", "Colors group and raid member names by their class when they appear in the text of Say, Yell, Party, and Raid messages.",
		function() return DB().classColorNames == true end, Setter("classColorNames"))
end

-------------------------------------------------------------------------------
--  Tabs page
-------------------------------------------------------------------------------
local function BuildTabs(p)
	local function Inside() return DB().extendBgBehindTabs == true end

	-- LAYOUT ----------------------------------------------------------------
	p:Section("Layout")
	p:Toggle("Tabs Inside Chat Panel", "Places the tabs inside one continuous chat panel background, including the sidebar when visible.",
		Getter("extendBgBehindTabs", false), Setter("extendBgBehindTabs"))
	p:Slider("Tab Spacing", nil, 0, 10, 1, Getter("tabSpacing", 1), Setter("tabSpacing"), Inside)
	p:Slider("Tab Height", nil, 18, 40, 1, Getter("tabHeight", 24), Setter("tabHeight"))
	p:Slider("Inner Padding X", nil, 0, 30, 1, Getter("tabInnerPaddingX", 12), Setter("tabInnerPaddingX"))

	-- TYPOGRAPHY ------------------------------------------------------------
	p:Section("Typography")
	FontDropdown(p, "Tab Font", nil, "tabFont", false)
	p:Slider("Tab Font Size", nil, 8, 24, 1, Getter("tabFontSize", 11), Setter("tabFontSize"))
	p:Label("Tab Font Color")
	ModeSwatches(p, "tabFontColorMode", "tabFontColor", { r = 1, g = 1, b = 1, a = 0.65 }, { alpha = true })
	p:Label("Tab Font Color Active")
	ModeSwatches(p, "tabFontColorActiveMode", "tabFontColorActive", { r = 1, g = 1, b = 1, a = 1 }, { alpha = true })

	-- APPEARANCE ------------------------------------------------------------
	p:Section("Appearance")
	local function Opacity(key, fallback)
		return { type = "slider", label = "Opacity", min = 0, max = 100, step = 1,
			get = function()
				local c = DB()[key] or fallback
				local a = c.a == nil and fallback.a or c.a
				return math.floor(a * 100 + 0.5)
			end,
			set = function(v)
				local c = DB()[key] or fallback
				DB()[key] = { r = c.r or fallback.r, g = c.g or fallback.g, b = c.b or fallback.b, a = v / 100 }
			end }
	end
	local INACTIVE = { r = 0.03, g = 0.045, b = 0.05, a = 0.44 }
	local ACTIVE = { r = 0.03, g = 0.045, b = 0.05, a = 0.65 }
	p:Label("Tab Background Color")
	p:Cog("Tab Background", { Opacity("tabBackgroundColor", INACTIVE) })
	p:Swatch("Custom Color",
		function() local c = DB().tabBackgroundColor or INACTIVE; return c.r or INACTIVE.r, c.g or INACTIVE.g, c.b or INACTIVE.b, 1 end,
		function(r, g, b)
			local c = DB().tabBackgroundColor or INACTIVE
			DB().tabBackgroundColor = { r = r, g = g, b = b, a = c.a == nil and INACTIVE.a or c.a }
		end)
	p:Label("Tab Background Color Active")
	p:Cog("Active Tab Background", { Opacity("tabBackgroundColorActive", ACTIVE) })
	ModeSwatches(p, "tabBackgroundColorActiveMode", "tabBackgroundColorActive", ACTIVE)

	p:Toggle("Active Underline", nil, function() return DB().activeUnderline ~= false end, Setter("activeUnderline"))
	local function UnderlineMode()
		local m = DB().activeUnderlineColorMode or "accent"
		return m == "border" and "custom" or m
	end
	p:Swatch("Class Color", ClassRGBA, function() end,
		{ readonly = true, active = function() return UnderlineMode() == "class" end,
		  onClick = function() DB().activeUnderlineColorMode = "class"; return true end })
	p:Swatch("Accent Color", AccentRGBA, function() end,
		{ readonly = true, active = function() return UnderlineMode() == "accent" end,
		  onClick = function() DB().activeUnderlineColorMode = "accent"; return true end })
	p:Swatch("Custom Color",
		function() local c = DB().activeUnderlineColor or {}; return c.r or 0.05, c.g or 0.82, c.b or 0.61, c.a == nil and 1 or c.a end,
		function(r, g, b, a)
			DB().activeUnderlineColor = { r = r, g = g, b = b, a = a }
			DB().activeUnderlineColorMode = "custom"
		end,
		{ alpha = true, active = function() return UnderlineMode() == "custom" end,
		  onClick = function()
			if UnderlineMode() ~= "custom" then
				DB().activeUnderlineColorMode = "custom"
				return true
			end
		  end })
	TextureDropdown(p, "Tab Texture", "Texture drawn over the tab background colors.", "tabBackgroundTexture")

	-- BORDER ----------------------------------------------------------------
	p:Section("Border")
	p:Toggle("Sync Border with Chat Panel", "For tabs outside the chat panel, uses the chat panel's border style and color instead of separate tab border settings.",
		function() return DB().syncTabBorder ~= false end, Setter("syncTabBorder"), Inside)
	p:Blank()
	local function TabBordersOff()
		return DB().extendBgBehindTabs == true or DB().syncTabBorder ~= false
	end
	BorderSizeSlider(p, "Border Size", "tabBorderThickness", TabBordersOff)
	ModeSwatches(p, "tabBorderColorMode", "tabBorderColor", { r = 1, g = 1, b = 1, a = 0.18 },
		{ alpha = true, alphaKey = "tabBorderOpacity", disabled = TabBordersOff })
	p:Toggle("Active Tab Border", "Gives the selected tab its own border color.",
		function() return DB().activeTabBorder ~= false end, Setter("activeTabBorder"), TabBordersOff)
	p:Swatch("Active Border Color",
		function() local c = DB().tabBorderColorActive or {}; return c.r or 1, c.g or 1, c.b or 1, c.a == nil and 0.18 or c.a end,
		function(r, g, b, a) DB().tabBorderColorActive = { r = r, g = g, b = b, a = a } end,
		{ alpha = true, disabled = function() return TabBordersOff() or DB().activeTabBorder == false end })
end

-------------------------------------------------------------------------------
--  Sidebar page
-------------------------------------------------------------------------------
local function BuildSidebar(p)
	-- SIDEBAR ---------------------------------------------------------------
	p:Section("Sidebar")
	local VIS = { { "always", "Always" }, { "mouseover", "Mouseover" }, { "never", "Never" } }
	KeyDropdown(p, "Sidebar Visibility", nil, VIS, "sidebarVisibility", "always")
	p:Cog("Sidebar Settings", {
		{ type = "toggle", label = "Show Sidebar on Right", get = Getter("sidebarRight", false), set = Setter("sidebarRight") },
	})
	p:Toggle("Hide Sidebar Background", nil, Getter("hideSidebarBg", false), Setter("hideSidebarBg"))
	p:Slider("Sidebar Width", nil, 30, 100, 1,
		function() return DB().sidebarWidth or ECHAT.SidebarWidthDefault() end, Setter("sidebarWidth"))
	p:Toggle("Separate Sidebar", "Separates the sidebar from the chat panel and gives it its own background and border.",
		Getter("sidebarSeparate", false), Setter("sidebarSeparate"))
	p:Cog("Separate Sidebar", {
		{ type = "slider", label = "Sidebar Spacing", min = 0, max = 30, step = 1,
		  get = Getter("sidebarSeparateSpacing", 8), set = Setter("sidebarSeparateSpacing") },
	}, { disabled = function() return not DB().sidebarSeparate end, disabledTip = "Separate Sidebar" })

	-- ICONS -----------------------------------------------------------------
	p:Section("Icons")
	p:Label("Sidebar Icons Color")
	p:Swatch("Accent Color", AccentRGBA, function() end,
		{ readonly = true, active = function() return DB().iconUseAccent and true or false end,
		  onClick = function() DB().iconUseAccent = true; return true end })
	p:Swatch("Custom Color",
		function() local c = DB(); return c.iconR or 1, c.iconG or 1, c.iconB or 1, 1 end,
		function(r, g, b) local c = DB(); c.iconR, c.iconG, c.iconB = r, g, b end,
		{ active = function() return not DB().iconUseAccent end,
		  onClick = function()
			if DB().iconUseAccent then
				DB().iconUseAccent = false
				return true
			end
		  end })

	-- Which icons show (checked) and their order (cog: one icon per place).
	local function IconItems()
		local items = {}
		for _, k in ipairs(ECHAT.ResolveSidebarIconOrder()) do
			items[#items + 1] = { value = k, name = ECHAT.SIDEBAR_ICON_LABELS[k] }
		end
		items[#items + 1] = { value = "showScroll", name = ECHAT.SIDEBAR_ICON_LABELS.showScroll }
		return items
	end
	p:MultiSelect("Sidebar Icons", "Icons shown on the sidebar, top to bottom. Scroll to Bottom stays at the bottom. The cog sets the order.",
		IconItems,
		function(k) return DB()[k] ~= false end,
		function(k) DB()[k] = DB()[k] == false end,
		function()
			local on = {}
			for _, item in ipairs(IconItems()) do
				if DB()[item.value] ~= false then
					on[#on + 1] = item.name
				end
			end
			return #on == 0 and "None" or table.concat(on, ", ")
		end)
	local orderRows = {}
	local PLACES = { "1st", "2nd", "3rd", "4th", "5th", "6th" }
	for i = 1, #ECHAT.SIDEBAR_CHAIN_KEYS do
		local place = i
		orderRows[#orderRows + 1] = {
			type = "dropdown", label = PLACES[place] or (place .. "th"),
			items = function()
				local items = {}
				for _, k in ipairs(ECHAT.SIDEBAR_CHAIN_KEYS) do
					items[#items + 1] = { value = k, name = ECHAT.SIDEBAR_ICON_LABELS[k] }
				end
				return items
			end,
			get = function() return ECHAT.ResolveSidebarIconOrder()[place] end,
			set = function(k)
				local order = ECHAT.ResolveSidebarIconOrder()
				local from
				for j, key in ipairs(order) do
					if key == k then
						from = j
					end
				end
				if not from or from == place then
					return
				end
				order[from], order[place] = order[place], order[from]
				local map = {}
				for j, key in ipairs(order) do
					map[key] = j
				end
				DB().sidebarIconOrder = map
			end,
			labelFn = function() return ECHAT.SIDEBAR_ICON_LABELS[ECHAT.ResolveSidebarIconOrder()[place]] end,
		}
	end
	p:Cog("Icon Order", orderRows)

	p:Slider("Sidebar Icon Size", nil, 0.5, 2.0, 0.05, Getter("sidebarIconScale", 1.0), Setter("sidebarIconScale"))
	p:Cog("Icon Settings", {
		{ type = "slider", label = "Icon Spacing", min = 0, max = 30, step = 1,
		  get = Getter("sidebarIconSpacing", 10), set = Setter("sidebarIconSpacing") },
	})
	p:Toggle("Free Move Icons", "When enabled, Shift+Click any sidebar icon to drag it to a custom position.",
		Getter("freeMoveIcons", false), Setter("freeMoveIcons"))

	p:Toggle("Scroll Button on Chat Panel", "Anchors the Scroll to Bottom button to the bottom-right corner of the chat panel instead of the sidebar.",
		function() return DB().scrollButtonOnChat == true end, Setter("scrollButtonOnChat"))
	p:Button("Reset Icon Positions", "Puts every icon moved with Free Move Icons back in the column.", "Reset",
		function() DB().iconPositions = {} end)
end

ns.RegisterSettingsModule({
	key = "chat",
	name = "Chat",
	group = "UI Reskin Addons",
	tabs = {
		{ key = "chat", name = "Chat", description = "Chat frame reskin, clickable URLs, copy chat, sidebar icons.", build = BuildChat },
		{ key = "tabs", name = "Tabs", description = "Chat frame reskin, clickable URLs, copy chat, sidebar icons.", build = BuildTabs },
		{ key = "sidebar", name = "Sidebar", description = "Chat frame reskin, clickable URLs, copy chat, sidebar icons.", build = BuildSidebar },
	},
	reset = function()
		ECHAT.Reset()
	end,
	resetTip = "Set all Chat settings back to the EllesmereUI defaults.",
})
