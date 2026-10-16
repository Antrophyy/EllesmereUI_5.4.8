-- Settings for Quality of Life > Raid Tools (retail EUI_QoL_RaidTools_Options.lua).
-- Tab builder only: EUI_QoL_Options.lua adds the tab. Settings live in
-- EllesmereUIQoLDB.raidTools; setters only store, the runtime follows them
-- through ns.applyHooks.

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUIQoL") then
	return
end

local function Cfg() return ns.GetRaidToolsDB and ns.GetRaidToolsDB() or {} end
local function RT() return ns.RaidTools end

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

local MODE_ITEMS, MODE_LABEL = Items({ "never", "Never", "raid", "In Raid Group", "group", "In Any Group", "always", "Always" })
local SHOWAS_ITEMS, SHOWAS_LABEL = Items({
	"compact", "Compact Band", "one", "One Window", "two", "Two Windows",
	"group", "Only Group & Pull", "markers", "Only Markers",
})
local GROW_ITEMS, GROW_LABEL = Items({ "downright", "Down Right", "upright", "Up Right", "downleft", "Down Left", "upleft", "Up Left" })

ns.QoLO_BuildRaidToolsPage = function(p)
	if not ns.GetRaidToolsDB or not RT() then
		return
	end
	local function ShowAs() return RT().ShowAs() end
	local function Disabled() return (Cfg().mode or "never") == "never" end
	local function LegacyDisabled() return Disabled() or ShowAs() == "compact" end
	local function QuickFireDisabled() return Disabled() or Cfg().quickFire ~= true end
	local function RoleCheckDisabled() return Disabled() or ShowAs() == "markers" end
	local function FullPanelDisabled() local m = ShowAs(); return Disabled() or m == "compact" or m == "markers" end
	local function PullDisabled() return Disabled() or ShowAs() == "markers" end

	-- Live preview: the panels stay on screen while this page is shown.
	if type(p.scroll) == "table" and not p.scroll.rtHooked then
		p.scroll.rtHooked = true
		p.scroll:HookScript("OnShow", function() RT().SetPreview(true) end)
		p.scroll:HookScript("OnHide", function() RT().SetPreview(false) end)
	end

	p:Section("General")
	p:Dropdown("Show Raid Tools", "A raid control panel with ready check, pull timer and raid markers. In a raid it only shows while you are the leader or an assistant, since none of its buttons work without that; in a party it always shows.",
		MODE_ITEMS, function() return Cfg().mode or "never" end, function() return MODE_LABEL(Cfg().mode or "never") end,
		function(v) Cfg().mode = v end)
	p:Keybind("Toggle Raid Tools", "Toggles the Raid Tools panels, in or out of combat.\n\nLeft-click to set a keybind.\nRight-click to unbind.",
		function() return Cfg().toggleKey or nil end,
		function(v) Cfg().toggleKey = v or false end, Disabled)
	p:Toggle("Default to Collapsed When Shown", "Full-window modes only. Shows start as a small icon, and the keybind switches between the icon and the full windows.",
		function() return Cfg().collapsedIcon ~= false end, function(v) Cfg().collapsedIcon = v end, LegacyDisabled)
	p:Dropdown("Show as", "Compact Band puts markers, ready check and pull timer in one resizable row. The other choices keep the original window layouts.",
		SHOWAS_ITEMS, function() return ShowAs() end, function() return SHOWAS_LABEL(ShowAs()) end,
		function(v) Cfg().showAs = v end, nil, Disabled)
	p:Slider("Window Scale", "Scale of the Raid Tools windows.", 0.5, 2.0, 0.05,
		function() return Cfg().scale or 1 end, function(v) Cfg().scale = v end, Disabled)
	p:Dropdown("Menu Grow Direction", "Full-window modes only. Which way the windows extend from the collapsed icon when they open.",
		GROW_ITEMS, function() return Cfg().growDir or "downright" end, function() return GROW_LABEL(Cfg().growDir or "downright") end,
		function(v) Cfg().growDir = v end, nil, LegacyDisabled)

	p:Section("Quick Fire")
	p:Toggle("Enable Quick Fire", "Adds three optional world-marker keybinds that remain usable in combat. Place starts the next free world marker in Blue to Yellow order (click the ground to drop it); Undo removes the last marker placed through Quick Fire; Clear removes all world markers. Every binding starts empty. Marker changes made elsewhere during combat are picked up afterward.",
		function() return Cfg().quickFire == true end, function(v) Cfg().quickFire = v end, Disabled)
	p:Keybind("Place World Marker", "Key for Place.",
		function() return Cfg().quickFirePlaceKey or nil end, function(v) Cfg().quickFirePlaceKey = v or false end, QuickFireDisabled)
	p:Keybind("Undo Last Marker", "Key for Undo.",
		function() return Cfg().quickFireUndoKey or nil end, function(v) Cfg().quickFireUndoKey = v or false end, QuickFireDisabled)
	p:Keybind("Clear All Markers", "Key for Clear.",
		function() return Cfg().quickFireClearKey or nil end, function(v) Cfg().quickFireClearKey = v or false end, QuickFireDisabled)

	p:Section("Group Buttons")
	p:Toggle("Show Role Check", "Shows the Role Check button in window layouts and enables Right Click: Role Check on Compact Band.",
		function() return Cfg().showRoleCheck ~= false end, function(v) Cfg().showRoleCheck = v end, RoleCheckDisabled)
	p:Toggle("Show Convert to Raid", "Shows the Convert to Raid button, which reads Convert to Party while you are in a raid.",
		function() return Cfg().showConvert ~= false end, function(v) Cfg().showConvert = v end, FullPanelDisabled)
	p:Toggle("Show Disband", "Shows the Disband button. It always asks before disbanding, but hiding it puts it out of misclick range for good.",
		function() return Cfg().showDisband ~= false end, function(v) Cfg().showDisband = v end, FullPanelDisabled)

	p:Section("Pull Timer")
	local PULL_LABELS = { "First Timer", "Second Timer", "Third Timer" }
	local PULL_TIP = "Countdown length in seconds. Compact Band uses First with Ctrl + Left Click, Second with Shift + Left Click, Third with Left Click, and Right Click stops the timer. Set a timer to 0 to disable that shortcut.\n\nThe timer runs through DBM or BigWigs (Mists has no Blizzard countdown); without either, a DBM pull timer is sent to the group."
	for i = 1, 3 do
		local slot = i
		p:Slider(PULL_LABELS[slot], PULL_TIP, 0, 60, 1,
			function()
				local t = Cfg().pullTimes
				return (t and t[slot]) or RT().PULL_DEFAULTS[slot]
			end,
			function(v)
				local c = Cfg()
				c.pullTimes = c.pullTimes or {}
				c.pullTimes[slot] = v
			end, PullDisabled)
	end
end
