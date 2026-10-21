-- Settings page of Quest Tracker (retail EUI_QuestTracker_Options.lua: same
-- sections, labels, tooltips and keys). Part of EllesmereUIOptions (load on
-- demand); skipped when EllesmereUIQuestTracker is not loaded.
-- Not on 5.4.8: Show Quest Icons (no quest type icons on the WatchFrame),
-- Ignore Older Expansion Quests, the Edit Mode link (Unlock Mode moves it).

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUIQuestTracker") then
	return
end

local EQT = _G.EllesmereUIQuestTracker
if not EQT or not EQT.DB then
	return
end

local U = ns.OptionsUtil

local function DB() return EQT.DB() end
local function Cfg(k) return DB()[k] end
local function Set(k, v) DB()[k] = v end

---------------------------------------------------------------------------
-- Visibility checklist (retail BuildVisibilityRow)
---------------------------------------------------------------------------
local function Axis(key)
	for _, axis in ipairs(EQT.VIS_AXES) do
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
	for _, axis in ipairs(EQT.VIS_AXES) do
		items[#items + 1] = { value = "show:" .. axis.key, name = "Show: " .. axis.label }
		items[#items + 1] = { value = "hide:" .. axis.key, name = "Hide: " .. axis.label }
	end
	return items
end

local function VisibilityRow(p)
	p:MultiSelect("Visibility", "When the quest tracker is shown. Never / Always / Mouseover is the base state; the Show conditions must match (all or any), a Hide condition always hides.",
		VisibilityItems,
		function(value)
			local s = DB()
			local kind, key = value:match("^(%a+):(.+)$")
			if kind == "state" then
				return EQT.VisBase(s) == key
			elseif kind == "match" then
				return (s.visibilityMatch or "all") == key
			end
			local axis = Axis(key)
			return EQT.VisFlag(s, kind == "show" and axis.show or axis.hide)
		end,
		function(value)
			local s = DB()
			local kind, key = value:match("^(%a+):(.+)$")
			if kind == "state" then
				EQT.SetVisBase(s, key)
				return
			elseif kind == "match" then
				s.visibilityMatch = key
				return
			end
			local axis = Axis(key)
			local laneKey = kind == "show" and axis.show or axis.hide
			local otherKey = kind == "show" and axis.hide or axis.show
			local on = not EQT.VisFlag(s, laneKey)
			EQT.SetVisFlag(s, laneKey, on)
			if on then
				EQT.SetVisFlag(s, otherKey, false)
			end
		end,
		function()
			local s = DB()
			local base = EQT.VisBase(s)
			local text = base == "never" and "Never" or (base == "mouseover" and "Mouseover" or "Always")
			local n = 0
			for _, axis in ipairs(EQT.VIS_AXES) do
				if EQT.VisFlag(s, axis.show) or EQT.VisFlag(s, axis.hide) then
					n = n + 1
				end
			end
			if n > 0 and base ~= "never" then
				text = text .. " + " .. n .. (n == 1 and " condition" or " conditions")
			end
			return text
		end)
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function ListLabel(list, value)
	for _, item in ipairs(list) do
		if item.value == value then
			return item.name
		end
	end
	return tostring(value or "")
end

local RAID_ITEMS = {
	{ value = "always", name = "Always" },
	{ value = "boss", name = "Boss Combat" },
}

local ALIGN_ITEMS = {
	{ value = "LEFT", name = "Left" },
	{ value = "RIGHT", name = "Right" },
}

local function FontItems()
	local lead = { { name = "EUI Global Font", value = "__global" } }
	return U and U.FontItems and U.FontItems(lead) or lead
end

local function FontPreview(value)
	if value == "__global" then
		return ns.GetFontPath and ns.GetFontPath("questTracker")
	end
	return ns.ResolveFontName and ns.ResolveFontName(value)
end

-- r, g, b keys with a fallback (the retail Get*RGB fallbacks).
local function RGBGetter(rk, gk, bk, d)
	return function()
		return Cfg(rk) or d[1], Cfg(gk) or d[2], Cfg(bk) or d[3], 1
	end
end
local function RGBSetter(rk, gk, bk)
	return function(r, g, b)
		Set(rk, r)
		Set(gk, g)
		Set(bk, b)
	end
end

local function ClassRGBA()
	local r, g, b = EQT.GetClassColorRGB()
	return r, g, b, 1
end
local function AccentRGBA()
	local r, g, b = EQT.GetAccent()
	return r, g, b, 1
end

-- Header Color / Line Color: Class Color, Custom Color, Accent Color
-- (prefix .. "ShowClassColor", prefix .. "UseAccent"; accent until set false).
local function ModeSwatches(p, prefix)
	local classKey, accentKey = prefix .. "ShowClassColor", prefix .. "UseAccent"
	local function isClass() return Cfg(classKey) == true end
	local function isAccent() return not isClass() and Cfg(accentKey) ~= false end
	-- Added nearest the control first: Accent, Custom, then Class (shows Class, Custom, Accent).
	p:Swatch("Accent Color", AccentRGBA, function() end,
		{ readonly = true, active = isAccent,
		  onClick = function() Set(classKey, false); Set(accentKey, true); return true end })
	p:Swatch("Custom Color", RGBGetter(prefix .. "R", prefix .. "G", prefix .. "B", { 1, 1, 1 }),
		function(r, g, b)
			RGBSetter(prefix .. "R", prefix .. "G", prefix .. "B")(r, g, b)
			Set(classKey, false)
			Set(accentKey, false)
		end,
		{ active = function() return not isClass() and not isAccent() end,
		  onClick = function()
			if isClass() or isAccent() then
				Set(classKey, false)
				Set(accentKey, false)
				return true
			end
		  end })
	p:Swatch("Class Color", ClassRGBA, function() end,
		{ readonly = true, active = isClass,
		  onClick = function() Set(classKey, true); Set(accentKey, false); return true end })
end

---------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------
local function Build(p)
	p:Paragraph("Move the quest tracker in Unlock Mode.")
	-- Retail: toggles forceOnScreen (keeps the tracker clamped to the screen).
	p:WideButton(function()
			return Cfg("forceOnScreen") ~= false and "Allow Quest Tracker to be Moved Offscreen" or "Force Quest Tracker on Screen"
		end,
		"Force Quest Tracker on Screen keeps the tracker inside the screen; click again to let it be moved off screen.",
		function() return false end,
		function()
			if InCombatLockdown() then return end
			Set("forceOnScreen", not (Cfg("forceOnScreen") ~= false))
		end)

	-- DISPLAY
	p:Section("Display")
	VisibilityRow(p)
	p:Dropdown("Hide When In Raid",
		"Always: hide the tracker the whole time you are in a raid.\nBoss Combat: keep it visible and only hide during boss encounters.",
		function() return RAID_ITEMS end,
		function() return Cfg("hideInRaidMode") or "boss" end,
		function() return ListLabel(RAID_ITEMS, Cfg("hideInRaidMode") or "boss") end,
		function(v) Set("hideInRaidMode", v) end)

	p:Slider("Background Opacity", nil, 0, 1, 0.05,
		function() return Cfg("bgAlpha") or 0.5 end,
		function(v) Set("bgAlpha", v) end)
	p:Swatch("Background Color", RGBGetter("bgR", "bgG", "bgB", { 0, 0, 0 }), RGBSetter("bgR", "bgG", "bgB"))
	p:Toggle("Show Top Line", "Draws a 1px accent line above the background at the top of the tracker.",
		function() return Cfg("showTopLine") ~= false end,
		function(v) Set("showTopLine", v) end)

	p:Slider("Header Font Size", nil, 8, 24, 1,
		function() return Cfg("headerFontSize") or 13 end,
		function(v) Set("headerFontSize", v) end)
	p:Slider("Title Font Size", nil, 8, 24, 1,
		function() return Cfg("titleFontSize") or 12 end,
		function(v) Set("titleFontSize", v) end)

	p:Slider("Objective Font Size", nil, 8, 24, 1,
		function() return Cfg("objectiveFontSize") or 10 end,
		function(v) Set("objectiveFontSize", v) end)
	p:Dropdown("Font", nil, FontItems,
		function() return Cfg("font") or "__global" end,
		function() return ListLabel(FontItems(), Cfg("font") or "__global") end,
		function(v) Set("font", v) end,
		{ fontPreview = true, fontPath = FontPreview })
	p:Dropdown("Text Alignment", "Aligns the quest titles and objectives to the left or right edge of the tracker. Right hides the objective dashes.",
		function() return ALIGN_ITEMS end,
		function() return Cfg("textAlign") or "LEFT" end,
		function() return ListLabel(ALIGN_ITEMS, Cfg("textAlign") or "LEFT") end,
		function(v) Set("textAlign", v) end)

	p:Toggle("Hide All Objectives",
		"Hides the master header and its minimize button at the top of the tracker. When shown, it's skinned to match the section headers below it (Quests, Achievements, ...).",
		function() return EQT.ShouldHideMasterHeader() end,
		function(v) Set("hideAllObjectivesHeader", v) end)
	-- Show Quest Icons (retail showQuestIcons): on 5.4.8 the tracker's quest
	-- icons are the numbered quest POI buttons, owned by the questPOI CVar.
	p:Toggle("Show Quest Icons", "Shows the numbered quest POI icons next to tracked quests (and the quest areas on the map).",
		function() return GetCVarBool("questPOI") and true or false end,
		function(v)
			SetCVar("questPOI", v and "1" or "0")
			if WatchFrame_Update then pcall(WatchFrame_Update, WatchFrame) end
		end)

	-- COLORS
	p:Section("Colors")
	p:Label("Title Color")
	p:Swatch("Title Color", RGBGetter("titleR", "titleG", "titleB", { 1.0, 0.910, 0.471 }), RGBSetter("titleR", "titleG", "titleB"))
	p:Label("Completed Color")
	p:Swatch("Completed Color", RGBGetter("completedR", "completedG", "completedB", { 0.251, 1.0, 0.349 }),
		RGBSetter("completedR", "completedG", "completedB"))
	p:Label("Focused Color")
	p:Swatch("Focused Color", RGBGetter("focusR", "focusG", "focusB", { 0.871, 0.251, 1.0 }), RGBSetter("focusR", "focusG", "focusB"))
	p:Label("Header Color")
	ModeSwatches(p, "header")
	p:Label("Line Color")
	ModeSwatches(p, "line")
	p:Blank()

	-- EXTRAS
	p:Section("Extras")
	local function acceptOff() return not Cfg("autoAccept") end
	local function turnInOff() return not Cfg("autoTurnIn") end
	p:Toggle("Auto Accept Quests", nil,
		function() return Cfg("autoAccept") or false end,
		function(v) Set("autoAccept", v) end)
	p:Cog("Auto Accept Settings", {
		{ type = "toggle", label = "Prevent Multi Quest Accept",
		  get = function() return Cfg("autoAcceptPreventMulti") ~= false end,
		  set = function(v) Set("autoAcceptPreventMulti", v) end },
		{ type = "toggle", label = "Hold Shift to Skip",
		  get = function() return Cfg("autoAcceptShiftSkip") ~= false end,
		  set = function(v) Set("autoAcceptShiftSkip", v) end },
		{ type = "toggle", label = "Ignore Low Level Quests",
		  get = function() return Cfg("autoAcceptIgnoreTrivial") or false end,
		  set = function(v) Set("autoAcceptIgnoreTrivial", v) end },
		{ type = "toggle", label = "Ignore Older Expansion Quests",
		  tip = "At max level, skips quests below Pandaria level (older content). Leveling characters are not affected.",
		  get = function() return Cfg("autoAcceptIgnoreOldExpansion") or false end,
		  set = function(v) Set("autoAcceptIgnoreOldExpansion", v) end },
	}, { disabled = acceptOff })
	p:Toggle("Auto Turn In Quests", nil,
		function() return Cfg("autoTurnIn") or false end,
		function(v) Set("autoTurnIn", v) end)
	p:Cog("Auto Turn In Settings", {
		{ type = "toggle", label = "Hold Shift to Skip",
		  get = function() return Cfg("autoTurnInShiftSkip") ~= false end,
		  set = function(v) Set("autoTurnInShiftSkip", v) end },
	}, { disabled = turnInOff })

	p:Keybind("Quest Item Hotkey", "Uses the item of your tracked quest (the first quest item in your log if no tracked quest has one). Right-click to clear.",
		function() return Cfg("questItemHotkey") end,
		function(v)
			if v == "" then v = nil end
			Set("questItemHotkey", v)
		end)
end

ns.RegisterSettingsModule({
	key = "questTracker",
	name = "Quest Tracker",
	group = "UI Reskin Addons",
	tabs = {
		{ key = "questTracker", name = "Quest Tracker",
		  description = "Blizzard tracker skin, visibility rules, auto-accept/turn-in, quest-item hotkey.", build = Build },
	},
	reset = function() EQT.Reset() end,
	resetTip = "Set all Quest Tracker settings back to default.",
})
