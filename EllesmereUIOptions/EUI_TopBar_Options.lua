-- Settings page of Top Bar (retail NaowhUI "Top Bar" page, NaowhUI_TopBar.lua
-- BuildTopBarOptions). Part of EllesmereUIOptions (load on demand); skipped
-- when EllesmereUITopBar is not loaded. Setters only store: the runtime's
-- ns.applyHooks entry applies every change.

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUITopBar") then
	return
end

local U = ns.OptionsUtil
local TB = ns.TopBar

local function T()
	return ns.GetTopBarDB()
end

local function FontItems()
	local lead = { { name = "EUI Global Default", value = "__default" } }
	return U.FontItems and U.FontItems(lead) or lead
end

local function FontLabel()
	local v = T().clockFont or "__default"
	for _, item in ipairs(FontItems()) do
		if item.value == v then return item.name end
	end
	return tostring(v)
end

local function HearthItems()
	local items = {}
	local entries = TB.OwnedHearths()
	table.sort(entries, function(a, b) return a.name < b.name end)
	for _, e in ipairs(entries) do
		items[#items + 1] = {
			name = "|T" .. tostring(e.icon) .. ":14:14:0:0:64:64:5:59:5:59|t " .. e.name,
			value = e.key,
		}
	end
	if #items == 0 then
		items[1] = { name = "No hearthstones found", value = "__none" }
	end
	return items
end

local function HearthLabel()
	local entries = TB.OwnedHearths()
	local on = 0
	for _, e in ipairs(entries) do
		if TB.InRotation(e.key) then on = on + 1 end
	end
	if #entries == 0 then return "None" end
	if on == #entries then return "All (" .. on .. ")" end
	return on .. " of " .. #entries
end

local PAGES = {
	{
		key = "topbar",
		name = "Top Bar",
		description = "Friends, guild, clock, hearthstone and Challenge Mode portals at the top of the screen, with a FPS / MS readout under it.",
		build = function(p)
			local function off() return not T().enabled end

			p:Section("Top Bar")
			p:Toggle("Enable Top Bar", "Shows the bar. Move it in Unlock Mode.",
				function() return T().enabled end, function(v) TB.SetEnabled(v) end)
			p:Toggle("24-Hour Clock", nil,
				function() return T().use24h end, function(v) T().use24h = v end, off)
			p:Slider("Bar Opacity (%)", nil, 0, 100, 5,
				function() return math.floor((T().bgAlpha or 0.85) * 100 + 0.5) end,
				function(v) T().bgAlpha = v / 100 end, off)
			p:Slider("Icon Size", "Size of the icons either side of the clock.", 12, 32, 1,
				function() return T().iconSize end, function(v) T().iconSize = v end, off)
			p:Slider("Clock Size", "Size of the clock text.", 10, 36, 1,
				function() return T().clockSize or 20 end, function(v) T().clockSize = v end, off)
			p:Dropdown("Clock Font", "Font of the clock. EUI Global Default follows the Top Bar module font (Global Settings > Fonts).",
				FontItems,
				function() return T().clockFont or "__default" end,
				FontLabel,
				function(v) T().clockFont = v end,
				{ fontPreview = true, fontPath = function(v)
					if v == "__default" then return ns.GetFontPath("topBar") end
					return ns.ResolveFontName(v)
				end }, off)
			p:ColorRow("Icon Colour", "Colour of the icons (they turn to the accent colour on hover).",
				function() local t = T(); return t.iconR or 1, t.iconG or 1, t.iconB or 1, 1 end,
				function(r, g, b)
					local t = T()
					t.iconR, t.iconG, t.iconB = r, g, b
					if TB.ApplyIconColor then TB.ApplyIconColor() end
				end, nil, off)
			p:Toggle("Hide Bar In Combat", "Hides the bar while you are in combat. The FPS / MS readout stays visible.",
				function() return T().hideInCombat end, function(v) T().hideInCombat = v end, off)
			p:Button("Reset Bar Position", "Puts the bar back at the top centre of the screen.", "Reset Position",
				function()
					T().pos = nil
					TB.RunOutOfCombat(TB.ApplyBarPosition)
				end)

			p:Section("Hearthstone")
			local function baseOnly() return off() or T().baseHearthOnly == true end
			p:MultiSelect("Random Rotation",
				"Which of your hearthstones the hearth button rolls between on a left click. Class abilities that hearth for you (Astral Recall) are listed too.\n\nMiddle-click: Wormhole Generator (Pandaria, else Northrend).\nRight-click: your class travel spell (Zen Pilgrimage, Death Gate, Teleport: Moonglade, Teleport: Vale of Eternal Blossoms).",
				HearthItems,
				function(v) return v ~= "__none" and TB.InRotation(v) end,
				function(v) if v ~= "__none" then TB.ToggleHearth(v) end end,
				HearthLabel, baseOnly)
			p:Toggle("Base Hearthstone Only", "Always use the plain Hearthstone, ignoring every other hearth item.",
				function() return T().baseHearthOnly end, function(v) T().baseHearthOnly = v end, off)

			p:Section("FPS / MS")
			local function sysOff() return off() or not T().showSystem end
			p:Toggle("Show FPS / MS", nil,
				function() return T().showSystem end, function(v) T().showSystem = v end, off)
			p:Slider("FPS / MS Size", "Size of the FPS / MS text.", 6, 24, 1,
				function() return T().sysSize or 11 end, function(v) T().sysSize = v end, sysOff)
			p:Toggle("Show FPS / MS Tooltip", "Shows FPS, latency and addon memory details when you hover the FPS / MS readout.",
				function() return T().showSystemTooltip end, function(v) T().showSystemTooltip = v end, sysOff)
			p:Toggle("Hide EllesmereUI FPS / MS Counter", "Hides the Minimap's FPS / MS text so you don't see it twice.",
				function() return T().hideEUIFps end, function(v) T().hideEUIFps = v end, off)
		end,
	},
}

ns.RegisterSettingsModule({
	key = "topBar",
	name = "Top Bar",
	group = "QoL Addons",
	tabs = PAGES,
	reset = function() TB.Reset() end,
	resetTip = "Set all Top Bar settings back to default.",
})
