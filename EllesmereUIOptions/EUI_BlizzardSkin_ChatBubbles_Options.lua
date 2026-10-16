-- Blizzard Skins: "Chat Bubbles" tab, and the "Blizzard HUD" settings
-- (ns.BlizzSkinHUDOptions, built at the end of the Tooltips page).
-- Part of EllesmereUIOptions (load on demand); skipped when EllesmereUIBlizzardSkin is not loaded.
local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUIBlizzardSkin") then
	return
end
local BS = ns.BlizzSkin
local U = ns.OptionsUtil
local KeyItems, KeyLabel = U.KeyItems, U.KeyLabel

---------------------------------------------------------------------------
-- Blizzard HUD (retail "BLIZZARD HUD" section). Called by the Tooltips page.
---------------------------------------------------------------------------
ns.BlizzSkinHUDOptions = function(p)
	p:Section("Blizzard HUD")
	p:Toggle("Reskin Widget Bars",
		"Restyles Blizzard's on-screen progress bars (breath and fatigue timers, PvP capture bars) and the progress bars in tooltips to the EUI look. Requires reload to apply.",
		function() return BS.Get("reskinWidgetBars") ~= false end,
		function(v)
			BS.Set("reskinWidgetBars", v and true or false)
			BS.AskReload()
		end)
	p:Toggle("Reskin Extra Action Buttons",
		"Squares the extra action button and gives it a thin black border.\n\nOff by default.",
		function() return BS.Get("reskinExtraActionButton") == true end,
		function(v) BS.Set("reskinExtraActionButton", v and true or false) end)
end

---------------------------------------------------------------------------
-- Chat Bubbles
---------------------------------------------------------------------------
local function CBM()
	return ns.ChatBubbles
end

-- Reads never create the settings table; writes do.
local function Val(key)
	local db = CBM().DB(false)
	local v = db and db[key]
	if v ~= nil then
		return v
	end
	return CBM().Defaults()[key]
end

local function Set(key, v)
	local db = CBM().DB(true)
	db[key] = v
end

local function ColorOf(key)
	local c = Val(key)
	if type(c) ~= "table" then
		return 1, 1, 1, 1
	end
	return c.r or 1, c.g or 1, c.b or 1, c.a or 1
end

local function ElvOwns()
	return CBM().ElvUIOwns()
end

local function Off()
	return Val("enabled") ~= true or ElvOwns()
end

local CHANNELS = {
	{ key = "say", text = "Say" },
	{ key = "yell", text = "Yell" },
	{ key = "party", text = "Party" },
	{ key = "raid", text = "Raid" },
	{ key = "npc", text = "NPCs" },
	{ key = "emote", text = "Emotes" },
}

local OUTLINES = {
	{ key = "__global", text = "EUI Global Outline" },
	{ key = "none", text = "Drop Shadow" },
	{ key = "outline", text = "Outline" },
	{ key = "thick", text = "Thick Outline" },
}

local ANCHORS = {
	{ key = "TOPLEFT", text = "Top Left" },
	{ key = "TOP", text = "Top" },
	{ key = "TOPRIGHT", text = "Top Right" },
	{ key = "BOTTOMLEFT", text = "Bottom Left" },
	{ key = "BOTTOM", text = "Bottom" },
	{ key = "BOTTOMRIGHT", text = "Bottom Right" },
}

local function ChannelLabel(isOn)
	local parts = {}
	for i = 1, #CHANNELS do
		if isOn(CHANNELS[i].key) then
			parts[#parts + 1] = CHANNELS[i].text
		end
	end
	if #parts == 0 then
		return "None"
	end
	return table.concat(parts, ", ")
end

local function FontItems()
	local items = { { name = "EUI Global Font", value = "__global" } }
	local list = ns.GetFonts and ns.GetFonts() or {}
	for i = 1, #list do
		items[#items + 1] = { name = list[i].name, value = list[i].path }
	end
	return items
end

local function FontLabel()
	local v = Val("font")
	if v == "__global" or not v then
		return "EUI Global Font"
	end
	return ns.GetFontLabel and ns.GetFontLabel(v) or tostring(v)
end

local function ChannelOn(k)
	return Val(k) == true
end

local function NameOn(k)
	local t = Val("showName")
	return type(t) == "table" and t[k] == true
end

local CHAT_BUBBLES_PAGE = {
	key = "chatBubbles",
	name = "Chat Bubbles",
	description = "Restyles the chat bubbles over players' and NPCs' heads.",
	-- Live sample bubble above the settings.
	header = function(page, host, width)
		local function HeightFor(h)
			return math.max(80, math.floor((h or 0) + 40))
		end
		local bubble = CBM().ShowPreview(host, function(h)
			page:SetHeaderHeight(HeightFor(h))
		end)
		page:OnRefresh(function()
			if host:IsShown() then
				CBM().RefreshStyle()
				page:SetHeaderHeight(HeightFor(bubble:GetHeight()))
			end
		end)
		host:HookScript("OnShow", function()
			CBM().ShowPreview(host, function(h)
				page:SetHeaderHeight(HeightFor(h))
			end)
			page:SetHeaderHeight(HeightFor(bubble:GetHeight()))
		end)
		return HeightFor(bubble:GetHeight())
	end,
	build = function(p)
		if ElvOwns() then
			p:Paragraph("ElvUI is styling chat bubbles (ElvUI > General > Chat Bubbles). Set it to Disabled there to use these settings.")
		end

		p:Section("Display")
		p:Toggle("Enable Chat Bubbles Customization",
			"EllesmereUI restyles Blizzard's chat bubbles and turns on the switches it needs. Party and Raid keep your current setting, and everything is put back when you turn this off.",
			function() return Val("enabled") == true end,
			function(v) Set("enabled", v and true or false) end,
			function() return ElvOwns() end)
		p:MultiSelect("Channels", "Choose which channels get a bubble. Party includes instance chat.",
			function() return KeyItems(CHANNELS) end,
			ChannelOn,
			function(k) Set(k, not ChannelOn(k)) end,
			function() return ChannelLabel(ChannelOn) end,
			Off)
		p:Toggle("Hide Chat Bubbles in Instances",
			"Turns all chat bubbles off while you are in a dungeon, raid, battleground or arena.",
			function() return Val("hideInInstances") == true end,
			function(v) Set("hideInInstances", v and true or false) end,
			Off)
		p:Blank()

		p:Section("Appearance")
		p:Slider("Padding", "Space between the text and the edge of the bubble.", 2, 24, 1,
			function() return Val("padding") end,
			function(v) Set("padding", v) end, Off)
		p:Slider("Maximum Width", "Widest a bubble gets before the text wraps.", 120, 500, 10,
			function() return Val("maxWidth") end,
			function(v) Set("maxWidth", v) end, Off)

		p:Dropdown("Font", "Font of the bubble text.",
			FontItems,
			function() return Val("font") end,
			FontLabel,
			function(v) Set("font", v) end, nil, Off)
		p:Swatch("Text Color",
			function() local r, g, b = ColorOf("textColor"); return r, g, b, 1 end,
			function(r, g, b) Set("textColor", { r = r, g = g, b = b }) end,
			{ disabled = function() return Off() or Val("followBlizzardColor") == true end })
		p:Cog("Font", {
			{ type = "slider", label = "Font Size", min = 8, max = 24, step = 1,
				get = function() return Val("fontSize") end,
				set = function(v) Set("fontSize", v) end },
			{ type = "dropdown", label = "Outline",
				items = function() return KeyItems(OUTLINES) end,
				get = function() return Val("outline") end,
				labelFn = function() return KeyLabel(OUTLINES, Val("outline")) end,
				set = function(v) Set("outline", v) end },
			{ type = "toggle", label = "Follow Blizzard Default Color",
				tip = "Use the color Blizzard gives each channel instead of the text color.",
				get = function() return Val("followBlizzardColor") == true end,
				set = function(v) Set("followBlizzardColor", v and true or false) end },
		}, { disabled = Off })

		p:Slider("Border", "Border thickness in pixels (0 = no border).", 0, 4, 1,
			function() return Val("borderSize") end,
			function(v) Set("borderSize", v) end, Off)
		p:Swatch("Border Color",
			function() return ColorOf("borderColor") end,
			function(r, g, b, a) Set("borderColor", { r = r, g = g, b = b, a = a }) end,
			{ alpha = true, disabled = Off })

		p:MultiSelect("Show Speaker Name", "Choose which channels show the speaker.",
			function() return KeyItems(CHANNELS) end,
			NameOn,
			function(k)
				local db = CBM().DB(true)
				if type(db.showName) ~= "table" then
					db.showName = {}
				end
				db.showName[k] = (not NameOn(k)) or nil
			end,
			function() return ChannelLabel(NameOn) end,
			Off)
		p:Cog("Speaker Name", {
			{ type = "dropdown", label = "Anchor",
				items = function() return KeyItems(ANCHORS) end,
				get = function() return Val("nameAnchor") end,
				labelFn = function() return KeyLabel(ANCHORS, Val("nameAnchor")) end,
				set = function(v) Set("nameAnchor", v) end },
			{ type = "slider", label = "Font Size", min = 6, max = 24, step = 1,
				get = function() return Val("nameFontSize") end,
				set = function(v) Set("nameFontSize", v) end },
			{ type = "slider", label = "X Offset", min = -50, max = 50, step = 1,
				get = function() return Val("nameOffsetX") end,
				set = function(v) Set("nameOffsetX", v) end },
			{ type = "slider", label = "Y Offset", min = -50, max = 50, step = 1,
				get = function() return Val("nameOffsetY") end,
				set = function(v) Set("nameOffsetY", v) end },
		}, { disabled = Off })
		p:Slider("Vertical Offset", "Moves the bubble up or down from where Blizzard puts it.", -80, 80, 2,
			function() return Val("offsetY") end,
			function(v) Set("offsetY", v) end, Off)

		p:Toggle("Background", "Draw a background behind the bubble text.",
			function() return Val("background") ~= false end,
			function(v) Set("background", v and true or false) end, Off)
		p:Swatch("Background Color",
			function()
				local r, g, b = ColorOf("bgColor")
				return r, g, b, Val("bgAlpha")
			end,
			function(r, g, b, a)
				local db = CBM().DB(true)
				db.bgColor = { r = r, g = g, b = b }
				db.bgAlpha = a
			end,
			{ alpha = true, disabled = function() return Off() or Val("background") == false end })
	end,
}

ns.BlizzSkinOptionTabs = ns.BlizzSkinOptionTabs or {}
table.insert(ns.BlizzSkinOptionTabs, { order = 40, tab = CHAT_BUBBLES_PAGE })
