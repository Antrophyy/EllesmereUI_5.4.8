-- Settings pages of Mythic+ Tools (retail EUI_MythicTimer_Options.lua):
-- Mythic+ Timer, Targeted Spell Bars, Target/Focus Bars, Run Summary.
-- Part of EllesmereUIOptions (load on demand); skipped when
-- EllesmereUIMythicTimer is not loaded. Setters only store: the runtime's
-- ns.applyHooks entry applies every change.
-- 5.4.8: the timer runs on Challenge Modes (Gold / Silver / Bronze are the
-- retail +3 / +2 / +1 thresholds); affixes, key level, M+ score, loot,
-- current pull, border textures and important-cast flags do not exist.

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUIMythicTimer") then
	return
end

local floor = math.floor
local U = ns.OptionsUtil
local EMT = ns.MythicTimer
local P = EMT and EMT.P
if not P then
	return
end

local EYE_ON = "Interface\\AddOns\\EllesmereUIMythicTimer\\media\\eui-visible"
local EYE_OFF = "Interface\\AddOns\\EllesmereUIMythicTimer\\media\\eui-invisible"

local function T()
	return EMT.DB()
end
local function Cfg(key)
	local t = T()
	return t and t[key]
end
local function Set(key, value)
	local t = T()
	if t then t[key] = value end
end
local function Off()
	return Cfg("enabled") == false
end

local function Col(key, dr, dg, db)
	local c = Cfg(key)
	if c then return c.r or dr, c.g or dg, c.b or db, 1 end
	return dr, dg, db, 1
end
local function SetCol(key, r, g, b)
	Set(key, { r = r, g = g, b = b })
end

local function Items(list)
	local items = {}
	for i = 1, #list, 2 do
		items[#items + 1] = { value = list[i], name = list[i + 1] }
	end
	return items
end
local function LabelOf(list, value)
	for i = 1, #list, 2 do
		if list[i] == value then return list[i + 1] end
	end
	return tostring(value or "")
end
-- Dropdown on a flat { value, name, value, name, ... } list.
local function ListDropdown(p, label, desc, list, get, set, isDisabled, labelFn)
	p:Dropdown(label, desc, function() return Items(list) end, get,
		labelFn or function() return LabelOf(list, get()) end, set, nil, isDisabled)
end

local TEX_OPTS = { texturePreview = true, previewPath = function(v) return P.TexturePath(v) or P.WHITE end }
local function TexItems() return P.TextureItems() end
local function TexDropdown(p, label, desc, get, set, isDisabled)
	p:Dropdown(label, desc, TexItems, get, function() return P.TextureLabel(get()) end, set, TEX_OPTS, isDisabled)
end
local function TexCogRow(label, get, set)
	return { type = "dropdown", label = label, items = TexItems, get = get, set = set,
		labelFn = function() return P.TextureLabel(get()) end, options = TEX_OPTS }
end

-- Accent / custom swatch pair (retail _AttachInlineAccentSwatches).
local function AccentSwatches(p, useKey, colorKey, dr, dg, db, isDisabled, followTip, followColor)
	p:Swatch("Custom Color", function() return Col(colorKey, dr, dg, db) end,
		function(r, g, b) SetCol(colorKey, r, g, b) end,
		{
			active = function() return Cfg(useKey) == false end,
			onClick = function()
				if Cfg(useKey) ~= false then
					Set(useKey, false)
					return true
				end
				return false
			end,
			disabled = isDisabled,
		})
	p:Swatch(followTip or "Accent Color", function()
			if followColor then return followColor() end
			return P.GetAccentColor()
		end, function() end,
		{
			active = function() return Cfg(useKey) ~= false end,
			onClick = function()
				Set(useKey, true)
				return true
			end,
			readonly = true,
			disabled = isDisabled,
		})
end

-------------------------------------------------------------------------------
--  Page: Mythic+ Timer
-------------------------------------------------------------------------------
local TIMER_FORMATS = {
	"REMAINING", "11:37",
	"REMAINING_TOTAL", "11:37 / 33:00",
	"ELAPSED", "21:23",
	"ELAPSED_DETAIL", "21:23 (11:37 / 33:00)",
}
local FORCES_FORMATS = {
	"PERCENT", "Percent",
	"COUNT", "Count / Total",
	"COUNT_PERCENT", "Count / Total + %",
	"COUNT_REMAINING", "Count / Total + Remaining",
	"REMAINING", "Remaining Count",
	"PERCENT_COUNT_REMAINING", "% || Count / Total || Remaining",  -- NaowhUI extra format
}

local function BuildTimerPage(p)
	-- DISPLAY
	p:Section("DISPLAY")
	p:Toggle("Show Preview", "Shows a sample Challenge Mode run so you can set the timer up outside a dungeon.",
		function() return Cfg("showPreview") == true end,
		function(v) EMT.SetPreview(v) end)
	ListDropdown(p, "Text Align", nil, { "LEFT", "Left", "RIGHT", "Right" },
		function() return Cfg("alignAllText") or "RIGHT" end,
		function(v) Set("alignAllText", v); EMT.Rebuild() end, Off)
	p:Slider("Scale", nil, 0.5, 2.0, 0.01,
		function() return Cfg("scale") or 1.0 end,
		function(v) Set("scale", v) end, Off)
	p:Cog("Frame Width", {
		{ type = "slider", label = "Width", min = 180, max = 420, step = 1,
			get = function() return Cfg("frameWidth") or 260 end,
			set = function(v) Set("frameWidth", v) end },
	}, { icon = "resize", disabled = Off })
	p:Slider("Background Opacity", nil, 0, 100, 5,
		function() return floor((Cfg("standaloneAlpha") or 0) * 100 + 0.5) end,
		function(v) Set("standaloneAlpha", v / 100) end, Off)

	local function barsOff()
		return Off() or (Cfg("showTimerBar") == false and Cfg("showEnemyBar") == false)
	end
	p:Slider("Bar Width", nil, 120, 420, 1,
		function() return Cfg("barWidth") or 210 end,
		function(v) Set("barWidth", v) end, barsOff)
	p:Toggle("Custom Border Style", "Show the border size and color controls for the timer bars.",
		function() return Cfg("customBorderStyle") == true end,
		function(v) Set("customBorderStyle", v) end, barsOff)
	if Cfg("customBorderStyle") then
		local function borderOff()
			if barsOff() then return true end
			return Cfg("showTimerBar") == false and Cfg("borderApplyToForces") == false
		end
		p:Slider("Border Size", "Width of the solid border in pixels. 5.4.8 draws a solid border only.", 0, 4, 1,
			function() return Cfg("borderSize") or 0 end,
			function(v) Set("borderSize", v) end, borderOff)
		p:Swatch("Border Color",
			function() return Cfg("borderR") or 0, Cfg("borderG") or 0, Cfg("borderB") or 0, Cfg("borderA") or 1 end,
			function(r, g, b, a) Set("borderR", r); Set("borderG", g); Set("borderB", b); Set("borderA", a or 1) end,
			{ alpha = true, disabled = borderOff })
		p:Cog("Border Options", {
			{ type = "toggle", label = "Apply to Forces Bar",
				get = function() return Cfg("borderApplyToForces") ~= false end,
				set = function(v) Set("borderApplyToForces", v) end },
		}, { disabled = barsOff })
	end

	-- TITLE (retail "TITLE AND AFFIXES"; 5.4.8 has no affixes)
	p:Section("TITLE")
	local function titleOff() return Off() or Cfg("showTitle") == false end
	p:Toggle("Show Title", "Shows the dungeon name and the medal you are on for.",
		function() return Cfg("showTitle") ~= false end,
		function(v) Set("showTitle", v) end, Off)
	AccentSwatches(p, "titleUseAccent", "titleColor", 1, 1, 1, titleOff)
	p:Cog("Title", {
		{ type = "toggle", label = "Show Dungeon Name",
			get = function() return Cfg("showDungeonName") ~= false end,
			set = function(v) Set("showDungeonName", v) end },
		{ type = "toggle", label = "Show Medal on Timer",
			tip = "Retail Show Key Level on Timer: the medal you are on for, left of the clock. Needs Show Dungeon Name off.",
			disabled = function() return Cfg("showDungeonName") ~= false end,
			get = function() return Cfg("showKeyLevelOnTimer") == true end,
			set = function(v) Set("showKeyLevelOnTimer", v) end },
		{ type = "slider", label = "Spacing", min = 0, max = 40, step = 1,
			disabled = function() return Cfg("showKeyLevelOnTimer") ~= true end,
			get = function() return Cfg("keyLevelTimerSpacing") or 8 end,
			set = function(v) Set("keyLevelTimerSpacing", v) end },
	}, { disabled = titleOff })
	p:Slider("Title Size", nil, 8, 24, 1,
		function() return Cfg("titleSize") or 16 end,
		function(v) Set("titleSize", v) end, titleOff)
	ListDropdown(p, "Title Position", nil, { "ABOVE_TIMER", "Above Timer", "BELOW_TIMER", "Below Timer" },
		function() return Cfg("titleAffixPosition") or "ABOVE_TIMER" end,
		function(v) Set("titleAffixPosition", v) end, Off)
	p:Cog("Title Spacing", {
		{ type = "slider", label = "Death Gap", min = -10, max = 30, step = 1,
			disabled = function() return (Cfg("titleAffixPosition") or "ABOVE_TIMER") == "BELOW_TIMER" end,
			get = function() return Cfg("titleAffixDeathGap") or 11 end,
			set = function(v) Set("titleAffixDeathGap", v) end },
		{ type = "slider", label = "Timer Gap", min = -10, max = 30, step = 1,
			disabled = function() return (Cfg("titleAffixPosition") or "ABOVE_TIMER") ~= "BELOW_TIMER" end,
			get = function() return Cfg("titleAffixTimerGap") or Cfg("titleAffixSandwichGap") or 6 end,
			set = function(v) Set("titleAffixTimerGap", v) end },
		{ type = "slider", label = "Bar Gap", min = -10, max = 30, step = 1,
			disabled = function() return (Cfg("titleAffixPosition") or "ABOVE_TIMER") ~= "BELOW_TIMER" end,
			get = function() return Cfg("titleAffixBarGap") or Cfg("titleAffixSandwichGap") or 6 end,
			set = function(v) Set("titleAffixBarGap", v) end },
	}, { icon = "resize", disabled = Off })
	p:Toggle("Show Deaths", "Shows the group's deaths of the run (hover for the list). 5.4.8 has no death time penalty.",
		function() return Cfg("showDeaths") ~= false end,
		function(v) Set("showDeaths", v) end, Off)
	p:Swatch("Death Text Color", function() return Col("deathTextColor", 0.93, 0.33, 0.33) end,
		function(r, g, b) SetCol("deathTextColor", r, g, b) end,
		{ disabled = function() return Off() or Cfg("showDeaths") == false end })

	-- TIMER
	p:Section("TIMER")
	p:Slider("Timer Size", nil, 10, 32, 1,
		function() return Cfg("timerTextSize") or 20 end,
		function(v) Set("timerTextSize", v) end,
		function() return Off() or (Cfg("timerInBar") == true and Cfg("showTimerBar") ~= false) end)
	ListDropdown(p, "Timer Format", nil, TIMER_FORMATS,
		function() return Cfg("timerDisplayMode") or "REMAINING_TOTAL" end,
		function(v) Set("timerDisplayMode", v) end, Off)
	local function FontItems()
		local lead = { { name = "EUI Global Default", value = "__global" } }
		return U.FontItems and U.FontItems(lead) or lead
	end
	p:Dropdown("Timer Font", "Font of the timer clock. EUI Global Default follows the Mythic+ Tools module font.",
		FontItems,
		function() return Cfg("timerFont") or "__global" end,
		function()
			local v = Cfg("timerFont") or "__global"
			for _, item in ipairs(FontItems()) do
				if item.value == v then return item.name end
			end
			return tostring(v)
		end,
		function(v) Set("timerFont", v) end,
		{ fontPreview = true, fontPath = function(v)
			if v == "__global" then return ns.GetFontPath("mythicTimer") end
			return ns.ResolveFontName(v)
		end }, Off)
	p:Swatch("Timer Expired Color", function() return Col("timerExpiredColor", 0.9, 0.2, 0.2) end,
		function(r, g, b) SetCol("timerExpiredColor", r, g, b) end, { disabled = Off })
	p:Blank()

	-- TIMER BAR
	p:Section("TIMER BAR")
	local function timerBarOff() return Off() or Cfg("showTimerBar") == false end
	p:Toggle("Show Timer Bar", nil,
		function() return Cfg("showTimerBar") ~= false end,
		function(v) Set("showTimerBar", v) end, Off)
	p:Toggle("Move Timer Inside Bar", nil,
		function() return Cfg("timerInBar") == true end,
		function(v) Set("timerInBar", v) end, timerBarOff)
	p:Cog("In-Bar Timer", {
		{ type = "slider", label = "In-Bar Height", min = 8, max = 40, step = 1,
			tip = "Minimum height of the timer bar while the timer is inside it. The larger of this and Timer Bar Height is used.",
			get = function() return Cfg("barHeightExpanded") or 22 end,
			set = function(v) Set("barHeightExpanded", v) end },
		{ type = "slider", label = "Fill Opacity", min = 0, max = 1, step = 0.05,
			tip = "Opacity of the bar fill while the timer is inside it.",
			get = function() return Cfg("barFillAlphaExpanded") or 0.85 end,
			set = function(v) Set("barFillAlphaExpanded", v) end },
		{ type = "toggle", label = "Left Text",
			tip = "Align the timer text to the left edge of the bar instead of centering it.",
			get = function() return Cfg("timerInBarLeftText") == true end,
			set = function(v) Set("timerInBarLeftText", v) end },
	}, { disabled = function() return timerBarOff() or Cfg("timerInBar") ~= true end })
	p:Slider("Timer Bar Height", "Height of the timer bar. While the timer is inside the bar, In-Bar Height sets the minimum.", 4, 30, 1,
		function() return Cfg("barHeight") or 8 end,
		function(v)
			if Cfg("enemyBarHeight") == nil then Set("enemyBarHeight", Cfg("barHeight") or 8) end
			Set("barHeight", v)
		end, timerBarOff)
	TexDropdown(p, "Timer Bar Texture", nil,
		function() return Cfg("barTexture") or "none" end,
		function(v) Set("barTexture", v) end, timerBarOff)
	p:Cog("Bar Texture", {
		TexCogRow("Background Texture", function() return Cfg("barBgTexture") or "none" end,
			function(v) Set("barBgTexture", v) end),
	}, { disabled = timerBarOff })

	-- THRESHOLDS: Gold / Silver / Bronze (retail +3 / +2 / +1)
	p:Section("THRESHOLDS")
	ListDropdown(p, "Ticks / Gaps", nil, { "TICKS", "Ticks", "SEGMENTS", "Gaps" },
		function() return Cfg("timerBarStyle") or "TICKS" end,
		function(v) Set("timerBarStyle", v) end, timerBarOff)
	p:Swatch("Tick Color", function() return Col("timerTickColor", 1, 1, 1) end,
		function(r, g, b) SetCol("timerTickColor", r, g, b) end,
		{ disabled = function() return timerBarOff() or (Cfg("timerBarStyle") or "TICKS") ~= "TICKS" end })
	p:Cog("Ticks / Gaps", {
		{ type = "slider", label = "Tick Opacity", min = 0, max = 1, step = 0.05,
			disabled = function() return (Cfg("timerBarStyle") or "TICKS") ~= "TICKS" end,
			get = function() return Cfg("tickAlpha") or 1 end,
			set = function(v) Set("tickAlpha", v) end },
		{ type = "slider", label = "Gap Size", min = 0, max = 12, step = 1,
			disabled = function() return (Cfg("timerBarStyle") or "TICKS") ~= "SEGMENTS" end,
			get = function() return Cfg("timerBarSegmentGap") or 2 end,
			set = function(v) Set("timerBarSegmentGap", v) end },
	}, { disabled = timerBarOff })

	local function Threshold(label, tip, colorKey, showKey, sizeKey, oxKey, oyKey, whiteKey, dr, dg, db, alsoKey)
		local function shown()
			if showKey == "showThreshRemaining" then return Cfg(showKey) == true end
			return Cfg(showKey) ~= false
		end
		p:Toggle("Show " .. label .. " Timer Text", tip, shown, function(v) Set(showKey, v) end, Off)
		p:Swatch(label .. " Color", function() return Col(colorKey, dr, dg, db) end,
			function(r, g, b)
				SetCol(colorKey, r, g, b)
				if alsoKey then SetCol(alsoKey, r, g, b) end
			end, { disabled = Off })
		p:Cog(label .. " Timer Text", {
			{ type = "toggle", label = "White Text",
				get = function() return Cfg(whiteKey) == true end,
				set = function(v) Set(whiteKey, v) end },
			{ type = "slider", label = "Text Size", min = 6, max = 20, step = 1,
				get = function() return Cfg(sizeKey) or Cfg("thresholdSize") or 12 end,
				set = function(v) Set(sizeKey, v) end },
			{ type = "slider", label = "Text X", min = -80, max = 80, step = 1,
				get = function() return Cfg(oxKey) or Cfg("thresholdTextOffsetX") or 0 end,
				set = function(v) Set(oxKey, v) end },
			{ type = "slider", label = "Text Y", min = -40, max = 40, step = 1,
				get = function() return Cfg(oyKey) or Cfg("thresholdTextOffsetY") or 0 end,
				set = function(v) Set(oyKey, v) end },
		}, { icon = "resize", disabled = function() return Off() or not shown() end })
	end
	Threshold("Gold", "Time left for the Gold medal (retail +3 threshold).",
		"timerSegment1Color", "showPlusThreeTimer", "thresholdPlusThreeSize",
		"thresholdPlusThreeTextOffsetX", "thresholdPlusThreeTextOffsetY", "thresholdPlusThreeTextWhite",
		0.4, 1, 0.4, "timerPlusThreeColor")
	Threshold("Silver", "Time left for the Silver medal (retail +2 threshold).",
		"timerSegment2Color", "showPlusTwoTimer", "thresholdPlusTwoSize",
		"thresholdPlusTwoTextOffsetX", "thresholdPlusTwoTextOffsetY", "thresholdPlusTwoTextWhite",
		0.3, 0.8, 1, "timerPlusTwoColor")
	Threshold("Bronze", "Time left for the Bronze medal, the time limit (retail +1 threshold). Goes negative once over time.",
		"timerSegment3Color", "showThreshRemaining", "thresholdPlusOneSize",
		"thresholdPlusOneTextOffsetX", "thresholdPlusOneTextOffsetY", "thresholdPlusOneTextWhite",
		0.69, 0.35, 0.8)
	p:Blank()

	-- FORCES (the enemy count criteria of a Challenge Mode)
	p:Section("FORCES")
	local function forcesOff() return Off() or Cfg("showEnemyBar") == false end
	p:Toggle("Show Enemy Forces", "Shows the enemy count objective of the Challenge Mode as a bar.",
		function() return Cfg("showEnemyBar") ~= false end,
		function(v) Set("showEnemyBar", v) end, Off)
	p:Slider("Forces Bar Height", nil, 4, 30, 1,
		function() return Cfg("enemyBarHeight") or Cfg("barHeight") or 8 end,
		function(v) Set("enemyBarHeight", v) end, forcesOff)
	ListDropdown(p, "Enemy Text Format", nil, FORCES_FORMATS,
		function() return Cfg("enemyForcesTextFormat") or "PERCENT" end,
		function(v) Set("enemyForcesTextFormat", v) end, forcesOff)
	p:Cog("Enemy Forces Text", {
		{ type = "toggle", label = "Hide Label",
			get = function() return Cfg("hideEnemyForcesLabel") == true end,
			set = function(v) Set("hideEnemyForcesLabel", v) end },
		{ type = "slider", label = "Text Size", min = 8, max = 24, step = 1,
			get = function() return Cfg("enemyForcesTextSize") or Cfg("objectivesSize") or 12 end,
			set = function(v) Set("enemyForcesTextSize", v) end },
		{ type = "slider", label = "Text X", min = -80, max = 80, step = 1,
			get = function() return Cfg("enemyForcesTextOffsetX") or 0 end,
			set = function(v) Set("enemyForcesTextOffsetX", v) end },
		{ type = "slider", label = "Text Y", min = -40, max = 40, step = 1,
			get = function() return Cfg("enemyForcesTextOffsetY") or 0 end,
			set = function(v) Set("enemyForcesTextOffsetY", v) end },
	}, { icon = "resize", disabled = forcesOff })
	ListDropdown(p, "Percent Position", "Where the enemy forces percentage is shown: in the label text, in the bar or beside it.",
		{ "LABEL", "In Label Text", "BAR", "In Bar", "BESIDE", "Beside Bar" },
		function() return Cfg("enemyForcesPctPos") or "LABEL" end,
		function(v) Set("enemyForcesPctPos", v) end, forcesOff)
	ListDropdown(p, "Enemy Forces Position", nil, { "BOTTOM", "Bottom", "UNDER_BAR", "Under Timer Bar" },
		function() return Cfg("enemyForcesPos") or "BOTTOM" end,
		function(v) Set("enemyForcesPos", v) end, forcesOff)
	TexDropdown(p, "Forces Bar Texture", "Texture of the enemy forces bar. The swatches next to it set the Enemy Bar Color (theme accent or a custom color).",
		function() return Cfg("enemyBarTexture") or "none" end,
		function(v) Set("enemyBarTexture", v) end, forcesOff)
	p:Cog("Bar Texture", {
		TexCogRow("Background Texture", function() return Cfg("enemyBarBgTexture") or "none" end,
			function(v) Set("enemyBarBgTexture", v) end),
	}, { disabled = forcesOff })
	AccentSwatches(p, "enemyBarUseAccent", "enemyBarColor", 0.35, 0.55, 0.8, forcesOff)

	-- BOSS OBJECTIVES
	p:Section("BOSS OBJECTIVES")
	local function objOff() return Off() or Cfg("showObjectives") == false end
	p:Toggle("Show Boss Objectives", nil,
		function() return Cfg("showObjectives") ~= false end,
		function(v) Set("showObjectives", v) end, Off)
	p:Cog("Boss Position", {
		{ type = "slider", label = "Boss X", min = -80, max = 80, step = 1,
			get = function() return Cfg("objectiveTextOffsetX") or 0 end,
			set = function(v) Set("objectiveTextOffsetX", v) end },
		{ type = "slider", label = "Boss Y", min = -40, max = 40, step = 1,
			get = function() return Cfg("objectiveTextOffsetY") or 0 end,
			set = function(v) Set("objectiveTextOffsetY", v) end },
	}, { icon = "resize", disabled = objOff })
	p:Slider("Objectives Size", nil, 8, 20, 1,
		function() return Cfg("objectivesSize") or 12 end,
		function(v) Set("objectivesSize", v) end, objOff)
	p:Toggle("Show Objective Times", nil,
		function() return Cfg("showObjectiveTimes") ~= false end,
		function(v) Set("showObjectiveTimes", v) end, objOff)
	ListDropdown(p, "Time Position", "Which side of each boss objective shows its split times and Split Compare text.",
		{ "RIGHT", "Right", "LEFT", "Left" },
		function() return Cfg("objectiveTimePosition") or "RIGHT" end,
		function(v) Set("objectiveTimePosition", v) end,
		function()
			return objOff() or (Cfg("showObjectiveTimes") == false and (Cfg("objectiveCompareMode") or "NONE") == "NONE")
		end)
	p:Slider("Objective Spacing", nil, 0, 12, 1,
		function() return Cfg("objectiveGap") or 4 end,
		function(v) Set("objectiveGap", v) end, objOff)
	-- 5.4.8 has no key level / affixes: only the per dungeon scope remains
	-- (a retail "Per Dungeon + Level" value reads the same splits).
	local COMPARE = { "NONE", "None", "DUNGEON", "Per Dungeon" }
	ListDropdown(p, "Split Compare", "Compares each boss kill with your best time for that boss in this dungeon.", COMPARE,
		function() return Cfg("objectiveCompareMode") or "NONE" end,
		function(v) Set("objectiveCompareMode", v) end, objOff,
		function()
			local v = Cfg("objectiveCompareMode") or "NONE"
			return v == "NONE" and "None" or "Per Dungeon"
		end)
	p:Cog("Split Compare", {
		{ type = "toggle", label = "Always Show Split Times",
			tip = "Shows your best split on upcoming bosses instead of only killed ones.",
			disabled = function() return (Cfg("objectiveCompareMode") or "NONE") == "NONE" end,
			get = function() return Cfg("showUpcomingSplitTargets") == true end,
			set = function(v) Set("showUpcomingSplitTargets", v) end },
		{ type = "toggle", label = "Delta Only",
			tip = "Show only the difference to the reference split.",
			disabled = function() return (Cfg("objectiveCompareMode") or "NONE") == "NONE" end,
			get = function() return Cfg("objectiveCompareDeltaOnly") == true end,
			set = function(v) Set("objectiveCompareDeltaOnly", v) end },
		{ type = "toggle", label = "Fastest Run Splits",
			tip = "Compare against the splits of your fastest completed run instead of your best individual splits.",
			disabled = function() return (Cfg("objectiveCompareMode") or "NONE") == "NONE" end,
			get = function() return Cfg("showFastestRunSplits") == true end,
			set = function(v) Set("showFastestRunSplits", v) end },
	}, { disabled = objOff })
end

-------------------------------------------------------------------------------
--  Page: Targeted Spell Bars
-------------------------------------------------------------------------------
local function TSB()
	local t = T()
	return t and t.tsb
end
local function TSBGet(key, default)
	local c = TSB()
	local v = c and c[key]
	if v == nil then return default end
	return v
end
local function TSBSet(key, value)
	local c = TSB()
	if c then c[key] = value end
end
local function TSBCol(key, dr, dg, db)
	local c = TSBGet(key)
	if c then return c.r or dr, c.g or dg, c.b or db, c.a or 1 end
	return dr, dg, db, 1
end

local TSB_WHERE = {
	"open_world", "Open World",
	"raid_heroic", "Heroic Raid",
	"raid_normal_lfr", "Normal/LFR/Flex Raid",
	"dungeon_mythic", "Challenge Mode Dungeons",
	"dungeon_nonmythic", "Normal/Heroic Dungeons",
	"scenario", "Scenario",
	"in_combat", "In Combat",
	"out_of_combat", "Out of Combat",
}

local function OffsetCog(p, title, sizeKey, sizeDefault, xKey, yKey, extra, disabled)
	local rows = {
		{ type = "slider", label = "Text Size", min = 6, max = 20, step = 1,
			get = function() return TSBGet(sizeKey, sizeDefault) end,
			set = function(v) TSBSet(sizeKey, v) end },
		{ type = "slider", label = "X Offset", min = -100, max = 100, step = 1,
			get = function() return TSBGet(xKey, 0) end,
			set = function(v) TSBSet(xKey, v) end },
		{ type = "slider", label = "Y Offset", min = -100, max = 100, step = 1,
			get = function() return TSBGet(yKey, 0) end,
			set = function(v) TSBSet(yKey, v) end },
	}
	for _, r in ipairs(extra or {}) do rows[#rows + 1] = r end
	p:Cog(title, rows, { disabled = disabled })
end

local function BuildTSBPage(p)
	local function TOff() return TSBGet("enabled") ~= true end
	p:Section("TARGETED SPELL BARS")
	p:Toggle("Enable Targeted Spell Bars",
		"Show one plain cast bar per enemy that is casting, gathered into a single movable group with the spell name, its target, and the cast timer. 5.4.8: enemies you or your group can target are exact; other casters from the combat log are timed from the spell's cast time.",
		function() return TSBGet("enabled") == true end,
		function(v) TSBSet("enabled", v and true or false) end)
	local eye = p:InlineIcon("Preview the bars at their position", EYE_ON, function()
		if TOff() then return end
		P.TSB_SetPreview(not P.TSB_IsPreview())
	end, 22)
	p:OnRefresh(function()
		eye.texture = eye.texture or select(1, eye:GetRegions())
		if eye.texture then eye.texture:SetTexture(P.TSB_IsPreview() and EYE_OFF or EYE_ON) end
	end)
	p:MultiSelect("Where to Show", "Limit the bars to the selected content and combat states; nothing selected shows them everywhere.",
		function() return Items(TSB_WHERE) end,
		function(v) local w = TSBGet("whereToShow"); return w and w[v] == true end,
		function(v)
			local c = TSB()
			if not c then return end
			c.whereToShow = c.whereToShow or {}
			c.whereToShow[v] = (not c.whereToShow[v]) and true or nil
		end,
		function()
			local w = TSBGet("whereToShow") or {}
			local n = 0
			for i = 1, #TSB_WHERE, 2 do
				if w[TSB_WHERE[i]] then n = n + 1 end
			end
			if n == 0 then return "Everywhere" end
			return n .. " selected"
		end, TOff)

	ListDropdown(p, "Grow Direction", "Which way new bars stack as more enemies start casting.",
		{ "DOWN", "Down", "UP", "Up" },
		function() return TSBGet("growUp") and "UP" or "DOWN" end,
		function(v) TSBSet("growUp", v == "UP") end, TOff)
	p:Slider("Width", nil, 80, 600, 1, function() return TSBGet("width", 240) end,
		function(v) TSBSet("width", v) end, TOff)
	p:Slider("Height", nil, 6, 60, 1, function() return TSBGet("height", 20) end,
		function(v) TSBSet("height", v) end, TOff)
	p:Slider("Bar Spacing", nil, 0, 20, 1, function() return TSBGet("spacing", 4) end,
		function(v) TSBSet("spacing", v) end, TOff)
	p:Slider("Max Bars", "The most cast bars shown at once. Extra casters take a bar as soon as one frees up.", 1, 10, 1,
		function() return TSBGet("maxBars", 5) end, function(v) TSBSet("maxBars", v) end, TOff)
	TexDropdown(p, "Bar Texture", nil, function() return TSBGet("texture", "none") end,
		function(v) TSBSet("texture", v) end, TOff)
	p:ColorRow("Background Color", nil,
		function() return TSBCol("bgColor", 0, 0, 0) end,
		function(r, g, b, a) TSBSet("bgColor", { r = r, g = g, b = b, a = a or 0.45 }) end,
		{ alpha = true }, TOff)
	p:Slider("Border Size", nil, 0, 5, 1, function() return TSBGet("borderSize", 1) end,
		function(v) TSBSet("borderSize", v) end, TOff)

	p:Toggle("Show Icon", nil, function() return TSBGet("showIcon") ~= false end,
		function(v) TSBSet("showIcon", v and true or false) end, TOff)
	p:Cog("Spell Icon Settings", {
		{ type = "toggle", label = "Icon on Right", tip = "Attach the spell icon to the right of the cast bar instead of the left.",
			get = function() return TSBGet("iconOnRight") == true end,
			set = function(v) TSBSet("iconOnRight", v) end },
		{ type = "toggle", label = "Show Icon Divider", tip = "Draw a 1px divider between the spell icon and the cast bar, matching the border color.",
			get = function() return TSBGet("showIconDivider") == true end,
			set = function(v) TSBSet("showIconDivider", v) end },
	}, { disabled = TOff })
	p:Toggle("Show Spell Name", nil, function() return TSBGet("showSpellName") ~= false end,
		function(v) TSBSet("showSpellName", v and true or false) end, TOff)
	OffsetCog(p, "Spell Name", "nameSize", 10, "nameX", "nameY", nil, TOff)
	p:Toggle("Show Cast Timer", nil, function() return TSBGet("showTimer") ~= false end,
		function(v) TSBSet("showTimer", v and true or false) end, TOff)
	OffsetCog(p, "Cast Timer", "timerSize", 10, "timerX", "timerY", nil, TOff)
	p:Toggle("Show Spell Target", "Show who each spell is being cast on (the caster's target), like the nameplate cast bars.",
		function() return TSBGet("showTarget") ~= false end,
		function(v) TSBSet("showTarget", v and true or false) end, TOff)
	OffsetCog(p, "Spell Target", "targetSize", 10, "targetX", "targetY", {
		{ type = "toggle", label = "Class Colored Names",
			get = function() return TSBGet("targetClassColor") ~= false end,
			set = function(v) TSBSet("targetClassColor", v and true or false) end },
		{ type = "color", label = "Custom Color",
			disabled = function() return TSBGet("targetClassColor") ~= false end,
			get = function() return TSBCol("targetColor", 1, 1, 1) end,
			set = function(r, g, b) TSBSet("targetColor", { r = r, g = g, b = b }) end },
	}, TOff)

	p:Section("INTERRUPT AND VISIBILITY")
	p:Label("Cast Colors", "Interruptible cast, your interrupt on cooldown, uninterruptible cast.", TOff)
	p:Swatch("Uninterruptible Cast", function() return TSBCol("uninterruptible", 0.45, 0.45, 0.45) end,
		function(r, g, b) TSBSet("uninterruptible", { r = r, g = g, b = b }) end, { disabled = TOff })
	p:Swatch("Interrupt on CD", function() return TSBCol("interruptReady", 0.92, 0.35, 0.20) end,
		function(r, g, b) TSBSet("interruptReady", { r = r, g = g, b = b }) end, { disabled = TOff })
	p:Swatch("Interruptible Cast", function() return TSBCol("barColor", 0.70, 0.40, 0.90) end,
		function(r, g, b) TSBSet("barColor", { r = r, g = g, b = b }) end, { disabled = TOff })
	p:Blank()
	p:Toggle("Fade Out of Interrupt Range", "Fade a bar when the enemy is beyond your interrupt spell's range. Has no effect for specs without an interrupt, or for casters only seen in the combat log.",
		function() return TSBGet("oorEnabled") == true end,
		function(v) TSBSet("oorEnabled", v and true or false) end, TOff)
	p:Cog("Fade Out of Interrupt Range", {
		{ type = "slider", label = "Opacity", min = 0, max = 100, step = 5,
			get = function() return floor((TSBGet("oorAlpha", 0.45)) * 100 + 0.5) end,
			set = function(v) TSBSet("oorAlpha", v / 100) end },
	}, { disabled = TOff })
	p:Toggle("Show Raid Target Marker", "Show the enemy's raid target marker to the left of the spell name.",
		function() return TSBGet("showRaidMarker") == true end,
		function(v) TSBSet("showRaidMarker", v and true or false) end, TOff)
	p:Cog("Raid Target Marker", {
		{ type = "slider", label = "Marker Size", min = 6, max = 30, step = 1,
			get = function() return TSBGet("raidMarkerSize", 14) end,
			set = function(v) TSBSet("raidMarkerSize", v) end },
	}, { disabled = TOff })
end

-------------------------------------------------------------------------------
--  Page: Target/Focus Bars
-------------------------------------------------------------------------------
local function TFB()
	local t = T()
	return t and t.tfb
end
local function TFBBar(which)
	local t = TFB()
	return t and t[which]
end
local function TFBCol(key, dr, dg, db)
	local t = TFB()
	local c = t and t[key]
	if c then return c.r or dr, c.g or dg, c.b or db, 1 end
	return dr, dg, db, 1
end
local function TFBSetCol(key, r, g, b)
	local t = TFB()
	if t then t[key] = { r = r, g = g, b = b } end
end

local function BuildTFBPage(p)
	local function BarSection(which, header, enableLabel)
		local function bGet(key, default)
			local c = TFBBar(which)
			local v = c and c[key]
			if v == nil then return default end
			return v
		end
		local function bSet(key, v)
			local c = TFBBar(which)
			if c then c[key] = v end
		end
		local function bOff() return bGet("enabled") ~= true end
		p:Section(header)
		p:Toggle(enableLabel, "A standalone cast bar for this unit, placeable anywhere in Unlock Mode. Runs alongside the Unit Frames cast bars.",
			function() return bGet("enabled") == true end,
			function(v) bSet("enabled", v and true or false) end)
		local eye = p:InlineIcon("Preview the bar at its position", EYE_ON, function()
			if bOff() then return end
			P.TFB_SetPreview(which, not P.TFB_IsPreview(which))
		end, 22)
		p:OnRefresh(function()
			eye.texture = eye.texture or select(1, eye:GetRegions())
			if eye.texture then eye.texture:SetTexture(P.TFB_IsPreview(which) and EYE_OFF or EYE_ON) end
		end)
		TexDropdown(p, "Bar Texture", nil, function() return bGet("texture", "none") end,
			function(v) bSet("texture", v) end, bOff)
		p:Slider("Width", nil, 80, 600, 1, function() return bGet("width", 260) end,
			function(v) bSet("width", v) end, bOff)
		p:Slider("Height", nil, 6, 60, 1, function() return bGet("height", 22) end,
			function(v) bSet("height", v) end, bOff)
		p:Toggle("Show Spell Name", nil, function() return bGet("showSpellName") ~= false end,
			function(v) bSet("showSpellName", v and true or false) end, bOff)
		p:Cog("Spell Name", {
			{ type = "slider", label = "Text Size", min = 6, max = 22, step = 1,
				get = function() return bGet("nameSize", 11) end, set = function(v) bSet("nameSize", v) end },
		}, { disabled = bOff })
		p:Toggle("Show Cast Timer", nil, function() return bGet("showTimer") ~= false end,
			function(v) bSet("showTimer", v and true or false) end, bOff)
		p:Cog("Cast Timer", {
			{ type = "slider", label = "Text Size", min = 6, max = 22, step = 1,
				get = function() return bGet("timerSize", 11) end, set = function(v) bSet("timerSize", v) end },
		}, { disabled = bOff })
		p:Toggle("Show Icon", nil, function() return bGet("showIcon") ~= false end,
			function(v) bSet("showIcon", v and true or false) end, bOff)
		p:Toggle("Show Spell Target", "Show who the spell is being cast on (the unit's target), like the nameplate cast bars.",
			function()
				local v = bGet("showTarget")
				if v == nil then v = TFB() and TFB().showTarget end
				return v ~= false
			end,
			function(v) bSet("showTarget", v and true or false) end, bOff)
		p:Cog("Spell Target", {
			{ type = "toggle", label = "Class Colored Names",
				get = function() return TFB().targetClassColor ~= false end,
				set = function(v) TFB().targetClassColor = v and true or false end },
			{ type = "color", label = "Custom Color",
				disabled = function() return TFB().targetClassColor ~= false end,
				get = function() return TFBCol("targetColor", 1, 1, 1) end,
				set = function(r, g, b) TFBSetCol("targetColor", r, g, b) end },
			{ type = "slider", label = (which == "target") and "Text Size (Target)" or "Text Size (Focus)", min = 6, max = 20, step = 1,
				get = function() return bGet("targetSize", 10) end, set = function(v) bSet("targetSize", v) end },
		}, { disabled = bOff })
	end
	BarSection("target", "TARGET CAST BAR", "Enable Target Cast Bar")
	BarSection("focus", "FOCUS CAST BAR", "Enable Focus Cast Bar")

	p:Section("CAST COLORS AND EFFECTS")
	local function sharedOff()
		local t, f = TFBBar("target"), TFBBar("focus")
		return not ((t and t.enabled) or (f and f.enabled))
	end
	p:Label("Cast Color", "Interruptible cast, your interrupt on cooldown, uninterruptible cast.", sharedOff)
	p:Swatch("Uninterruptible Cast", function() return TFBCol("uninterruptible", 0.45, 0.45, 0.45) end,
		function(r, g, b) TFBSetCol("uninterruptible", r, g, b) end, { disabled = sharedOff })
	p:Swatch("Interrupt on CD", function() return TFBCol("interruptReady", 0.92, 0.35, 0.20) end,
		function(r, g, b) TFBSetCol("interruptReady", r, g, b) end, { disabled = sharedOff })
	p:Swatch("Interruptible Cast", function() return TFBCol("castColor", 0.70, 0.40, 0.90) end,
		function(r, g, b) TFBSetCol("castColor", r, g, b) end, { disabled = sharedOff })
	p:Cog("Cast Color", {
		{ type = "toggle", label = "Show Shield Icon", tip = "Show a shield icon on the cast bar when the cast cannot be interrupted.",
			get = function() return TFB().showShield ~= false end,
			set = function(v) TFB().showShield = v and true or false end },
		{ type = "toggle", label = "Show Spark", tip = "Show the bright spark at the leading edge of the cast bar fill.",
			get = function() return TFB().showSpark ~= false end,
			set = function(v) TFB().showSpark = v and true or false end },
	}, { disabled = sharedOff })
	local HINTS = { "none", "None", "tick", "Tick", "tickbar", "Tick + Bar" }
	ListDropdown(p, "Kick Ready Mid-Cast Hint",
		"Shows where your interrupt will be ready during a cast. \"Tick\" marks the exact spot on the cast bar; \"Tick + Bar\" also colours the window during which your interrupt will be available.",
		HINTS,
		function()
			local t = TFB()
			if not t then return "tick" end
			if t.kickTickEnabled == false then return "none" end
			if t.midCastEnabled == true then return "tickbar" end
			return "tick"
		end,
		function(v)
			local t = TFB()
			if not t then return end
			t.kickTickEnabled = v ~= "none"
			t.midCastEnabled = v == "tickbar"
		end, sharedOff)
	p:Cog("Kick Ready Mid-Cast Hint", {
		{ type = "color", label = "Mid-Cast Bar Color",
			get = function() return TFBCol("midCastColor", 0.318, 0.820, 0.357) end,
			set = function(r, g, b) TFBSetCol("midCastColor", r, g, b) end },
		{ type = "color", label = "Tick Color",
			get = function() return TFBCol("kickTickColor", 1, 1, 1) end,
			set = function(r, g, b) TFBSetCol("kickTickColor", r, g, b) end },
	}, { disabled = sharedOff })
	p:Toggle("Show Interrupted Flash Effect", "Flash the cast bar and show \"Interrupted\" for a moment when the cast is interrupted.",
		function() return TFB().interruptedFlash ~= false end,
		function(v) TFB().interruptedFlash = v and true or false end, sharedOff)
	p:Cog("Interrupted Flash", {
		{ type = "color", label = "Flash Color",
			get = function() return TFBCol("interruptedColor", 0.8, 0, 0) end,
			set = function(r, g, b) TFBSetCol("interruptedColor", r, g, b) end },
	}, { disabled = sharedOff })
	p:Blank()
end

-------------------------------------------------------------------------------
--  Page: Run Summary
-------------------------------------------------------------------------------
local function RS()
	local t = T()
	return t and t.runSummary
end
local function RSGet(key, default)
	local c = RS()
	local v = c and c[key]
	if v == nil then return default end
	return v
end
local function RSSet(key, v)
	local c = RS()
	if c then c[key] = v end
end

local function BuildRSPage(p)
	local function RSOff() return RSGet("enabled") ~= true end
	p:Section("RUN SUMMARY")
	p:Button("Preview", "Shows the overview with a sample group.", "Show Preview", function() P.RS_ShowPreview() end)
	p:Button("Run History", "Deletes every recorded Challenge Mode run of this character.", "Clear Run History", function()
		ns.ShowConfirmPopup({
			title = "Clear Run History",
			message = "Delete every recorded Challenge Mode run for this character?",
			confirmText = "Delete",
			cancelText = "Cancel",
			onConfirm = function() P.RS_ClearHistory() end,
		})
	end)
	p:Toggle("Enable Run Summary",
		"Records every finished Challenge Mode and shows an overview of the group when the run ends. /ov reopens it at any time. Nothing is registered or created while this is off.",
		function() return RSGet("enabled") == true end,
		function(v) RSSet("enabled", v and true or false) end)
	p:Slider("History Size", nil, 5, 50, 1, function() return RSGet("historySize", 20) end,
		function(v) RSSet("historySize", v) end, RSOff)
	p:Slider("Panel Scale", nil, 0.5, 2, 0.05, function() return RSGet("scale", 1) end,
		function(v) RSSet("scale", v) end, RSOff)
	p:Slider("Text Size", "Size of the player rows. The title and column headers keep their own size.", 10, 20, 1,
		function() return RSGet("textSize", 14) end, function(v) RSSet("textSize", v) end, RSOff)

	p:Section("COLUMNS")
	local function Col(label, key, tip)
		p:Toggle(label, tip, function() return RSGet(key, true) == true end,
			function(v) RSSet(key, v and true or false) end, RSOff)
	end
	Col("Show Spec Icons", "showSpecIcons")
	Col("Item Level", "colItemLevel", "Shown in grey next to each name. Item levels are read by inspecting party members during the run, so a member who stayed out of range shows none.")
	Col("DPS", "colDps", "Damage done over the run time, from the combat log. Pets count for their owner.")
	Col("Damage Taken", "colDamageTaken")
	Col("Interrupts", "colInterrupts")
	Col("Deaths", "colDeaths")
end

-------------------------------------------------------------------------------
--  Register
-------------------------------------------------------------------------------
local function PreviewsOff()
	local t = T()
	if t and t.showPreview then EMT.SetPreview(false) end
	if P.TSB_IsPreview and P.TSB_IsPreview() then P.TSB_SetPreview(false) end
	if P.TFB_IsPreview then
		if P.TFB_IsPreview("target") then P.TFB_SetPreview("target", false) end
		if P.TFB_IsPreview("focus") then P.TFB_SetPreview("focus", false) end
	end
end

ns.RegisterSettingsModule({
	key = "EllesmereUIMythicTimer",
	name = "Mythic+ Tools",
	group = "UI Reskin Addons",
	tabs = {
		{ key = "timer", name = "Mythic+ Timer", description = "Challenge Mode timer: medal thresholds, boss splits, enemy count and deaths.", build = BuildTimerPage },
		{ key = "tsb", name = "Targeted Spell Bars", description = "One cast bar per casting enemy, in one movable group.", build = BuildTSBPage },
		{ key = "tfb", name = "Target/Focus Bars", description = "Standalone target and focus cast bars with interrupt colors.", build = BuildTFBPage },
		{ key = "rs", name = "Run Summary", description = "End of run overview and a per character run history (/ov).", build = BuildRSPage },
	},
	reset = function() EMT.Reset() end,
	resetTip = "Set all Mythic+ Tools settings back to default.",
	onLeave = PreviewsOff,
})
