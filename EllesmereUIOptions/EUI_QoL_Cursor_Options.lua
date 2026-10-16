-- Settings for Quality of Life > Cursor (retail EUI_QoL_Cursor_Options.lua).
-- Tab builder only: EUI_QoL_Options.lua adds the tab. Settings live in
-- EllesmereUIQoLDB.cursor; setters only store, the runtime follows them
-- through ns.applyHooks.

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUIQoL") then
	return
end

local floor = math.floor

local function DB()
	return ns.GetCursorDB and ns.GetCursorDB() or {}
end
local function GCD_DB()
	local p = DB()
	p.gcd = p.gcd or {}
	return p.gcd
end
local function Cast_DB()
	local p = DB()
	p.castCircle = p.castCircle or {}
	return p.castCircle
end

local function HexToRGB(hex)
	local C = ns.CursorModule
	if C and C.ParseHex then return C.ParseHex(hex or "0CD29D") end
	return 12 / 255, 210 / 255, 157 / 255
end
local function RGBToHex(r, g, b)
	return string.format("%02X%02X%02X", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

local function Items(list)
	local items = {}
	for i = 1, #list, 2 do
		items[#items + 1] = { value = list[i], name = list[i + 1] }
	end
	return function() return items end, function(v)
		for i = 1, #list, 2 do
			if list[i] == v then return list[i + 1] end
		end
		return tostring(v)
	end
end

local CURSOR_TEX, CURSOR_TEX_LABEL = Items({
	"ring_normal", "Ring Normal",
	"ring_light", "Ring Light",
	"custom", "Ellesmere Logo",
	"ring_thin", "Ring Thin",
	"ring_heavy", "Ring Heavy",
	"ring_thick", "Ring Thick",
})
local RING_TEX, RING_TEX_LABEL = Items({
	"normal", "Ring Normal",
	"light", "Ring Light",
	"thin", "Ring Thin",
	"heavy", "Ring Heavy",
	"thick", "Ring Thick",
})

-- Color row: Custom / Class Colored / Accent Color swatches (retail multiSwatch).
local function ColorSwatches(p, cfgFn, isOff)
	p:Label("Color", "Custom color, the class color of your character or the UI accent color.", isOff)
	p:Swatch("Accent Color",
		function() return ns.ResolveAccent() end,
		function() end,
		{ readonly = true, active = function() return cfgFn().useAccentColor and true or false end,
		  onClick = function()
			  local c = cfgFn()
			  c.useAccentColor, c.useClassColor = true, false
			  return true
		  end })
	p:Swatch("Class Colored",
		function()
			local _, classFile = UnitClass("player")
			local cc = classFile and RAID_CLASS_COLORS[classFile]
			if cc then return cc.r, cc.g, cc.b end
			return 12 / 255, 210 / 255, 157 / 255
		end,
		function() end,
		{ readonly = true, active = function() return cfgFn().useClassColor and true or false end,
		  onClick = function()
			  local c = cfgFn()
			  c.useClassColor, c.useAccentColor = true, false
			  return true
		  end })
	p:Swatch("Custom Color",
		function() return HexToRGB(cfgFn().hex) end,
		function(r, g, b) cfgFn().hex = RGBToHex(r, g, b) end,
		{ active = function()
			  local c = cfgFn()
			  return not (c.useClassColor or c.useAccentColor)
		  end,
		  onClick = function()
			  local c = cfgFn()
			  if c.useClassColor or c.useAccentColor then
				  c.useClassColor, c.useAccentColor = false, false
				  return true
			  end
		  end })
end

ns.QoLO_BuildCursorPage = function(p)
	if not ns.GetCursorDB then
		return
	end

	-- CURSOR ---------------------------------------------------------------
	local function cursorOff() return DB().enabled == false end
	p:Section("Cursor")
	p:Toggle("Enable Cursor Circle", "Shows a ring that follows your mouse cursor.",
		function() return DB().enabled ~= false end,
		function(v) DB().enabled = v end)
	ColorSwatches(p, DB, cursorOff)

	-- Rows below are hidden while the circle is off (toggles rebuild the page).
	if DB().enabled ~= false then
		p:Dropdown("Texture", "Look of the cursor circle.",
			CURSOR_TEX, function() return DB().texture or "ring_normal" end,
			function() return CURSOR_TEX_LABEL(DB().texture or "ring_normal") end,
			function(v) DB().texture = v end)
		p:Slider("Scale", "Size of the cursor circle.", 0.5, 2.0, 0.1,
			function() return DB().scale or 1 end, function(v) DB().scale = v end)
		p:Slider("Circle Opacity", "Opacity of the cursor circle.", 0, 100, 1,
			function() return DB().alpha or 100 end, function(v) DB().alpha = v end)
		p:Toggle("Cursor Trail", "Leaves a short trail of fading dots behind the cursor.",
			function() return DB().trail and true or false end, function(v) DB().trail = v end)
		p:Toggle("Only Show in Instances", "Only shows the cursor circle inside dungeons and raids.",
			function() return DB().instanceOnly and true or false end, function(v) DB().instanceOnly = v end)
		p:Toggle("Only Show When Hidden", "Only shows the cursor circle while the mouse is hidden -- that is, while you hold the left and/or right mouse button to pan the camera or move your character.",
			function() return DB().onlyWhenHidden and true or false end, function(v) DB().onlyWhenHidden = v end)
		p:Toggle("Combat Only", "Only shows the cursor circle while you are in combat.",
			function() return DB().combatOnly and true or false end, function(v) DB().combatOnly = v end)
		p:Toggle("Center Reticle", "Adds a small filled dot at the center of the cursor circle. Uses the same color and opacity as the circle.",
			function() return DB().reticle and true or false end, function(v) DB().reticle = v end)
	end

	-- GLOBAL COOLDOWN ------------------------------------------------------
	local function gcdOff() return not GCD_DB().enabled end
	p:Section("Global Cooldown")
	p:Toggle("Enable GCD Circle", "Shows a ring that fills while your global cooldown runs.",
		function() return GCD_DB().enabled and true or false end,
		function(v) GCD_DB().enabled = v end)
	ColorSwatches(p, GCD_DB, gcdOff)
	if GCD_DB().enabled then
		p:Dropdown("Ring Texture", "Thickness of the ring.",
			RING_TEX, function() return GCD_DB().ringTex or "light" end,
			function() return RING_TEX_LABEL(GCD_DB().ringTex or "light") end,
			function(v) GCD_DB().ringTex = v end)
		p:Slider("Scale", "Radius of the ring.", 10, 100, 1,
			function() return GCD_DB().radius or 21 end, function(v) GCD_DB().radius = v end)
		p:Slider("Circle Opacity", "Opacity of the ring.", 0, 100, 1,
			function() return GCD_DB().alpha or 80 end, function(v) GCD_DB().alpha = v end)
		p:Toggle("Attach to Cursor", "The ring follows the mouse cursor. Off: place it in Unlock Mode.",
			function() return GCD_DB().attached ~= false end, function(v) GCD_DB().attached = v end)
		p:Toggle("Only Show in Instances", "Only shows the GCD circle inside dungeons and raids.",
			function() return GCD_DB().instanceOnly and true or false end, function(v) GCD_DB().instanceOnly = v end)
		p:Toggle("Combat Only", "Only shows the GCD circle while you are in combat.",
			function() return GCD_DB().combatOnly and true or false end, function(v) GCD_DB().combatOnly = v end)
	end

	-- CAST BAR -------------------------------------------------------------
	local function castOff() return not Cast_DB().enabled end
	p:Section("Cast Bar")
	p:Toggle("Enable Cast Bar Circle", "Shows a ring that fills while you cast or channel a spell.",
		function() return Cast_DB().enabled and true or false end,
		function(v) Cast_DB().enabled = v end)
	p:Cog("Cast Bar Settings", {
		{ type = "toggle", label = "Show Spark",
		  get = function() return Cast_DB().sparkEnabled ~= false end,
		  set = function(v) Cast_DB().sparkEnabled = v end },
	}, { disabled = castOff, disabledTip = "Enable Cast Bar Circle first." })
	ColorSwatches(p, Cast_DB, castOff)
	if Cast_DB().enabled then
		p:Dropdown("Ring Texture", "Thickness of the ring.",
			RING_TEX, function() return Cast_DB().ringTex or "normal" end,
			function() return RING_TEX_LABEL(Cast_DB().ringTex or "normal") end,
			function(v) Cast_DB().ringTex = v end)
		p:Slider("Scale", "Radius of the ring.", 10, 100, 1,
			function() return Cast_DB().radius or 30 end, function(v) Cast_DB().radius = v end)
		p:Slider("Circle Opacity", "Opacity of the ring.", 0, 100, 1,
			function() return Cast_DB().alpha or 80 end, function(v) Cast_DB().alpha = v end)
		p:Toggle("Attach to Cursor", "The ring follows the mouse cursor. Off: place it in Unlock Mode.",
			function() return Cast_DB().attached ~= false end, function(v) Cast_DB().attached = v end)
		p:Toggle("Only Show in Instances", "Only shows the cast bar circle inside dungeons and raids.",
			function() return Cast_DB().instanceOnly and true or false end, function(v) Cast_DB().instanceOnly = v end)
		p:Toggle("Combat Only", "Only shows the cast bar circle while you are in combat.",
			function() return Cast_DB().combatOnly and true or false end, function(v) Cast_DB().combatOnly = v end)
	end
end
