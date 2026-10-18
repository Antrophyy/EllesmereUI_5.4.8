-- Settings of Quality of Life (retail EUI_QoL_Options.lua): the "QoL" page
-- (GENERAL, EXTRAS, CROSSHAIR, SELF COMBAT TEXT, GROUP FINDER, UI and the
-- Auto Logging part at its end), the tabs of the other QoL files (Raid Tools,
-- Cursor, Shifter, MoveAlert) in retail order, and the 5.4.8 "Battle Res &
-- Lust" tab. Part of EllesmereUIOptions (load on demand); skipped when
-- EllesmereUIQoL is not loaded. Setters only store: the window then runs
-- ns.applyHooks (the runtime applies everything).
-- Rows 5.4.8 cannot do are left out (see the runtime files for the list).

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUIQoL") then
	return
end

local U = ns.OptionsUtil
local Q = ns.QoL

local function DB() return Q.R() end
local function On(k) return Q.On(k) end
local function Set(k) return function(v) DB()[k] = v end end
local function Get(k) return function() return On(k) end end
local XGet, XSet = Q.XGet, Q.XSet

-- { value, name, ... } -> items / label functions
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

local STRATA = {
	"BACKGROUND", "Background", "LOW", "Low", "MEDIUM", "Medium", "HIGH", "High",
	"DIALOG", "Dialog", "FULLSCREEN", "Fullscreen", "FULLSCREEN_DIALOG", "Fullscreen Dialog",
	"TOOLTIP", "Tooltip",
}
local STRATA_ITEMS = Items(STRATA)
local STRATA_TIP = "Controls the order that overlapping elements display in. Set higher to show above other elements."

local function ClassSwatch(tooltip, isActive, onClick, disabled)
	return tooltip, function() return Q.ClassColor() end, function() end,
		{ readonly = true, active = isActive, onClick = onClick, disabled = disabled }
end

local EYE = "Interface\\AddOns\\EllesmereUIQoL\\Media\\eui-visible"

---------------------------------------------------------------------------
-- GENERAL
---------------------------------------------------------------------------
local function BuildGeneral(p)
	p:Section("General")

	p:Toggle("Hide Blizzard Party Panel", "Hides the collapsed Blizzard party/raid sidebar panel on the side of the screen.",
		Get("hideBlizzardPartyFrame"), Set("hideBlizzardPartyFrame"),
		function() return IsAddOnLoaded("EllesmereUIRaidFrames") end)
	p:Toggle("Skip Cinematics", "When you press Escape or Space during a cinematic, the confirmation prompt is automatically accepted.",
		Get("skipCinematics"), Set("skipCinematics"))
	p:Cog("Cinematic Settings", {
		{ type = "toggle", label = "Automatically Skip If Possible", get = Get("skipCinematicsAuto"), set = Set("skipCinematicsAuto") },
	}, { disabled = function() return not On("skipCinematics") end, disabledTip = "Enable Skip Cinematics first." })

	p:Toggle("Quick Loot", "Enables auto loot and hides the loot window when looting. Hold Shift when looting to show.",
		Get("quickLoot"), Set("quickLoot"))
	p:Toggle("Auto-Fill Delete Confirmation", "Automatically types DELETE when throwing away a valuable item. Also allows you to press enter to accept the deletion.",
		Get("autoFillDelete"), Set("autoFillDelete"))

	p:Toggle("Auto Repair", "Automatically repair all gear when visiting a repair vendor.",
		Get("autoRepair"), Set("autoRepair"))
	p:Cog("Auto Repair Settings", {
		{ type = "toggle", label = "Use Guild Bank Funds", get = Get("autoRepairGuild"), set = Set("autoRepairGuild") },
		{ type = "toggle", label = "Coin Icons", get = Get("repairCoinIcons"), set = Set("repairCoinIcons") },
	}, { disabled = function() return not On("autoRepair") end, disabledTip = "Enable Auto Repair first." })
	p:Toggle("Auto Sell Junk", "Automatically sell all junk items when visiting a vendor.",
		Get("autoSellJunk"), Set("autoSellJunk"))

	p:Toggle("Show Coordinates on Map", "Displays cursor and player coordinates at the bottom of the world map.",
		Get("mapCoords"), Set("mapCoords"))
	p:Cog("Map Coordinates Settings", {
		{ type = "slider", label = "Text Size", min = 8, max = 24, step = 1,
		  get = function() return DB().mapCoordsTextSize or 12 end, set = Set("mapCoordsTextSize") },
	}, { disabled = function() return not On("mapCoords") end, disabledTip = "Enable Show Coordinates on Map first." })
	p:Toggle("Suppress Lua Errors", "Hides the Lua error popup. The same setting as Global Settings > Developer.",
		Get("suppressErrors"), function(v)
			DB().suppressErrors = v
			Q.ApplySuppressErrors()
		end)

	p:Toggle("Hide Error Messages", "Hides most red error messages (such as 'Not enough rage' or 'Ability is not ready yet'). Important errors like a full bag or quest log are still shown.",
		Get("hideErrorMessages"), Set("hideErrorMessages"))
	p:Toggle("Hide Tutorial Pop-ups", "Hides Blizzard's tutorial UI: the tutorial pop-ups and the glowing (i) help-plate buttons on the spellbook, talents and other panels.",
		Get("hideTutorials"), Set("hideTutorials"))

	-- Hide Loot Rolls Window | Combat Alert
	local function lootHistOff() return not On("hideLootHistory") end
	local MODES, MODE_LABEL = Items({ "hide", "Hide Completely", "autoclose", "Close After Delay" })
	p:Toggle("Hide Loot Rolls Window", "Hides Blizzard's \"Loot Rolls\" window -- the running list of dropped items showing who rolled what and who won. Use the cog to let it appear briefly and close itself instead. The Need/Greed roll popups themselves are not affected.",
		Get("hideLootHistory"), Set("hideLootHistory"))
	p:Cog("Loot Rolls Window Settings", {
		{ type = "dropdown", label = "Mode", items = MODES,
		  get = function() return DB().lootHistoryMode or "hide" end,
		  labelFn = function() return MODE_LABEL(DB().lootHistoryMode or "hide") end,
		  set = Set("lootHistoryMode") },
		{ type = "slider", label = "Close After (sec)", min = 1, max = 30, step = 1,
		  get = function() return DB().lootHistoryDelay or 5 end, set = Set("lootHistoryDelay"),
		  disabled = function() return lootHistOff() or DB().lootHistoryMode ~= "autoclose" end },
	}, { disabled = lootHistOff, disabledTip = "Enable Hide Loot Rolls Window first." })

	local function caOff() return not On("combatAlertEnabled") end
	local CA_MODES, CA_LABEL = Items({ "both", "Enter & Leave", "enter", "Enter Only", "leave", "Leave Only" })
	local function CAColorRow(label, which)
		local colorKey = which == "leave" and "combatAlertLeaveColor" or "combatAlertEnterColor"
		local classKey = which == "leave" and "combatAlertLeaveUseClassColor" or "combatAlertEnterUseClassColor"
		return {
			{ type = "color", label = label .. " Color",
			  disabled = function() return DB()[classKey] and true or false end,
			  get = function() local c = DB()[colorKey] or { r = 1, g = 1, b = 1 }; return c.r, c.g, c.b end,
			  set = function(r, g, b)
				  DB()[colorKey] = { r = r, g = g, b = b }
				  Q.CombatAlertPreview(which)
			  end },
			{ type = "toggle", label = label .. " Class Color",
			  get = function() return DB()[classKey] and true or false end,
			  set = function(v)
				  DB()[classKey] = v
				  Q.CombatAlertPreview(which)
			  end },
		}
	end
	local caRows = {
		{ type = "dropdown", label = "Show On", items = CA_MODES,
		  get = function() return DB().combatAlertMode or "both" end,
		  labelFn = function() return CA_LABEL(DB().combatAlertMode or "both") end,
		  set = Set("combatAlertMode") },
		{ type = "slider", label = "Text Size", min = 14, max = 64, step = 1,
		  get = function() return DB().combatAlertTextSize or 22 end,
		  set = function(v)
			  DB().combatAlertTextSize = v
			  Q.CombatAlertPreview("enter")
		  end },
	}
	for _, row in ipairs(CAColorRow("Enter", "enter")) do caRows[#caRows + 1] = row end
	for _, row in ipairs(CAColorRow("Leave", "leave")) do caRows[#caRows + 1] = row end
	p:Toggle("Combat Alert", "Shows a large on-screen text when you enter and/or leave combat (e.g. \"+Combat\" / \"-Combat\"). Use the cog to set the display text, size, colors and which transitions are shown; use Unlock Mode to reposition the alert.",
		Get("combatAlertEnabled"), Set("combatAlertEnabled"))
	p:Cog("Combat Alert Settings", caRows, { disabled = caOff, disabledTip = "Enable Combat Alert first." })

	-- The cog popup has no text field on 5.4.8: the two texts are rows here.
	local enterEdit = p:TextInput("Combat Alert Enter Text", "Text shown when you enter combat.",
		function() return DB().combatAlertEnterText or "+Combat" end,
		function(v) DB().combatAlertEnterText = v end, "+Combat")
	local leaveEdit = p:TextInput("Combat Alert Leave Text", "Text shown when you leave combat.",
		function() return DB().combatAlertLeaveText or "-Combat" end,
		function(v) DB().combatAlertLeaveText = v end, "-Combat")
	-- Potion Ready Alert | Unspent Talents Alert (retail Alerts; they follow the
	-- Combat Alert position: talents above it, potion below it).
	local function AlertRows(prefix, preview)
		local D = Q.ALERT_DEFAULTS[prefix]
		local function Off() return not DB()[prefix .. "Enabled"] end
		return {
			{ type = "input", label = "Text", inputWidth = 160, maxLetters = 40,
			  get = function() return DB()[prefix .. "Text"] or D.text end,
			  set = function(v)
				  v = tostring(v or ""):gsub("|", "")
				  DB()[prefix .. "Text"] = (v ~= "" and v ~= D.text) and v or nil
				  preview()
			  end },
			{ type = "slider", label = "Text Size", min = 14, max = 64, step = 1,
			  get = function() return DB()[prefix .. "TextSize"] or 22 end,
			  set = function(v) DB()[prefix .. "TextSize"] = v; preview() end },
			{ type = "color", label = "Color",
			  disabled = function() return DB()[prefix .. "UseClassColor"] and true or false end,
			  get = function() local c = DB()[prefix .. "Color"] or D.color; return c.r, c.g, c.b end,
			  set = function(r, g, b) DB()[prefix .. "Color"] = { r = r, g = g, b = b }; preview() end },
			{ type = "toggle", label = "Class Color",
			  get = function() return DB()[prefix .. "UseClassColor"] and true or false end,
			  set = function(v) DB()[prefix .. "UseClassColor"] = v; preview() end },
		}, Off
	end
	local potRows, potOff = AlertRows("potionAlert", function() Q.AlertPreview("potionAlert") end)
	p:Toggle("Potion Ready Alert", "Shows a short on-screen text when the potion you drank is off cooldown again. Shares the Combat Alert position (Unlock Mode: Alerts).",
		Get("potionAlertEnabled"), function(v)
			DB().potionAlertEnabled = v
			Q.ApplyPotionAlert()
			if v then Q.AlertPreview("potionAlert") end
		end)
	p:Cog("Potion Ready Alert Settings", potRows, { disabled = potOff, disabledTip = "Enable Potion Ready Alert first." })
	local talRows, talOff = AlertRows("talentAlert", function() Q.TalentAlertPreview() end)
	p:Toggle("Unspent Talents Alert", "Shows an on-screen text while you have unspent talent points. It goes away when you open the talent window and comes back on a level-up.",
		Get("talentAlertEnabled"), function(v)
			DB().talentAlertEnabled = v
			Q.ApplyTalentAlert()
		end)
	p:Cog("Unspent Talents Alert Settings", talRows, { disabled = talOff, disabledTip = "Enable Unspent Talents Alert first." })

	p:OnRefresh(function()
		local a = caOff() and 0.3 or 1
		if enterEdit then enterEdit:GetParent():SetAlpha(a) end
		if leaveEdit then leaveEdit:GetParent():SetAlpha(a) end
	end)

	-- Announce Group Deaths | Hide Item Transforms
	local function deathOff() return not On("announceGroupDeaths") end
	local function SoundItems()
		local items = {}
		for _, k in ipairs(Q.SOUND_ORDER) do
			items[#items + 1] = { value = k, name = Q.SOUND_NAMES[k] or k }
		end
		return items
	end
	p:Toggle("Announce Group Deaths", "Shows a large on-screen alert (e.g. \"Player DIED!\") whenever a party or raid member dies, so you immediately notice deaths during dungeons and raids. Use Unlock Mode to reposition the alert.",
		Get("announceGroupDeaths"), Set("announceGroupDeaths"))
	p:Cog("Group Death Alert Settings", {
		{ type = "slider", label = "Text Size", min = 14, max = 64, step = 1,
		  get = function() return DB().groupDeathTextSize or 34 end,
		  set = function(v)
			  DB().groupDeathTextSize = v
			  Q.GroupDeathPreview()
		  end },
		{ type = "dropdown", label = "Sound", items = SoundItems,
		  get = function() return DB().groupDeathSoundKey or "none" end,
		  labelFn = function() local k = DB().groupDeathSoundKey or "none"; return Q.SOUND_NAMES[k] or k end,
		  set = function(v)
			  DB().groupDeathSoundKey = v
			  Q.GroupDeathPlaySound()
		  end },
	}, { disabled = deathOff, disabledTip = "Enable Announce Group Deaths first." })

	local hitRows = {}
	for _, item in ipairs(Q.TRANSFORMS) do
		local key = item.key
		hitRows[#hitRows + 1] = { type = "toggle", label = item.label,
			get = function() return Q.TransformEnabled(key) end,
			set = function(v)
				local t = DB().hideTransformItems
				if type(t) ~= "table" then t = {}; DB().hideTransformItems = t end
				t[key] = v
			end }
	end
	p:Toggle("Hide Item Transforms (ex: Chef's Hat)", "Automatically removes cosmetic transforms when they are applied to you, such as holiday costumes and consumables. Use the cog to pick exactly which transforms are removed. Transforms applied during combat are removed when combat ends.",
		Get("hideTransforms"), Set("hideTransforms"))
	p:Cog("Hide Item Transforms", hitRows, { disabled = function() return not On("hideTransforms") end,
		tip = "Choose which transforms are removed", disabledTip = "Enable Hide Item Transforms first." })

	-- Auto Select Single Gossip
	local function gossipOff() return not On("autoGossip") end
	p:Toggle("Auto Select Single Gossip", "Picks an NPC's only dialog option for you.",
		Get("autoGossip"), Set("autoGossip"))
	p:Cog("Auto Gossip Settings", {
		{ type = "toggle", label = "Hold Shift to Skip", get = Get("autoGossipShiftSkip"), set = Set("autoGossipShiftSkip") },
		{ type = "toggle", label = "Disable in Instances", get = Get("autoGossipDisableInstance"), set = Set("autoGossipDisableInstance") },
		{ type = "toggle", label = "Ignore Low Level Quests", get = Get("autoGossipIgnoreTrivial"), set = Set("autoGossipIgnoreTrivial") },
	}, { disabled = gossipOff, disabledTip = "Enable Auto Select Single Gossip first." })
	p:Blank()
end

---------------------------------------------------------------------------
-- EXTRAS
---------------------------------------------------------------------------
local function BuildExtras(p)
	p:Section("Extras")

	-- Show FPS Counter (class / custom swatches + cog) | FPS Toggle Keybind
	local function fpsOff() return not XGet("showFPS") end
	local function fpsMode() return XGet("fpsColorMode") or "custom" end
	p:Toggle("Show FPS Counter", nil,
		function() return XGet("showFPS") and true or false end, function(v) XSet("showFPS", v) end)
	p:Swatch("Custom Color",
		function() return Q.FPSColor() end,
		function(r, g, b, a)
			XSet("fpsColor", { r = r, g = g, b = b, a = a or 1 })
			XSet("fpsColorMode", "custom")
		end,
		{ alpha = true, disabled = fpsOff, active = function() return fpsMode() == "custom" end,
		  onClick = function()
			  if fpsMode() ~= "custom" then XSet("fpsColorMode", "custom"); return true end
		  end })
	p:Swatch(ClassSwatch("Class Color", function() return fpsMode() == "class" end,
		function() XSet("fpsColorMode", "class"); return true end, fpsOff))
	p:Cog("FPS Counter Settings", {
		{ type = "toggle", label = "Attach to Secondary Stats",
		  disabled = function() return not XGet("showSecondaryStats") end,
		  get = function() return XGet("fpsAttachToStats") and true or false end,
		  set = function(v) XSet("fpsAttachToStats", v) end },
		{ type = "slider", label = "Text Size", min = 8, max = 30, step = 1,
		  disabled = function() return Q.FPSAttached() end,
		  get = function() return XGet("fpsTextSize") or 12 end, set = function(v) XSet("fpsTextSize", v) end },
		{ type = "toggle", label = "Show Local MS",
		  get = function() local v = XGet("fpsShowLocalMS"); if v == nil then return true end; return v end,
		  set = function(v) XSet("fpsShowLocalMS", v) end },
		{ type = "toggle", label = "Show World MS",
		  get = function() return XGet("fpsShowWorldMS") and true or false end, set = function(v) XSet("fpsShowWorldMS", v) end },
		{ type = "toggle", label = "Hide Local/World Label",
		  get = function() return XGet("fpsHideLabel") and true or false end, set = function(v) XSet("fpsHideLabel", v) end },
		{ type = "slider", label = "Update Interval", min = 1, max = 5, step = 1,
		  get = function() return XGet("fpsUpdateInterval") or 3 end, set = function(v) XSet("fpsUpdateInterval", v) end },
	}, { disabled = fpsOff, disabledTip = "Enable Show FPS Counter first." })
	p:Keybind("FPS Toggle Keybind", "Left-click to set a keybind that shows or hides the FPS counter.\nRight-click to unbind.",
		function() return DB().fpsToggleKey end,
		function(key) DB().fpsToggleKey = key end)

	-- Low Durability Warning (color, cog, preview) | Disable Right Click
	local function durOff() return not On("repairWarning") end
	p:Toggle("Low Durability Warning", "Flashes a warning on screen when any equipped item drops below the configured durability threshold. Only triggers out of combat.",
		Get("repairWarning"), function(v)
			DB().repairWarning = v
			if not v then Q.DurPreview(false) end
		end)
	p:Swatch("Warning Color",
		function() local c = DB().durWarnColor; if c then return c.r, c.g, c.b end; return 1, 0.27, 0.27 end,
		function(r, g, b) DB().durWarnColor = { r = r, g = g, b = b } end,
		{ disabled = durOff })
	p:Cog("Durability Settings", {
		{ type = "slider", label = "Text Size", min = 10, max = 50, step = 1,
		  get = function() return DB().durWarnTextSize or 30 end, set = Set("durWarnTextSize") },
		{ type = "slider", label = "Y-Offset", min = -600, max = 600, step = 1,
		  get = function() return DB().durWarnYOffset or 250 end,
		  set = function(v)
			  DB().durWarnYOffset = v
			  DB().durWarnPos = nil
		  end },
		{ type = "slider", label = "Repair %", min = 5, max = 100, step = 1,
		  get = function() return DB().durWarnThreshold or 40 end, set = Set("durWarnThreshold") },
	}, { icon = "directions", disabled = durOff, disabledTip = "Enable Low Durability Warning first." })
	p:InlineIcon("Preview durability warning", EYE, function()
		if durOff() then return end
		Q.DurPreview(not Q.DurPreviewShown())
	end, 22)

	local RC_ITEMS = { { value = "enemy", name = "Enemies" }, { value = "ally", name = "Allies In Combat" } }
	local function rcKey(v) return v == "enemy" and "disableRightClickTarget" or "disableRightClickTargetAllyCombat" end
	p:MultiSelect("Disable Right Click", "Suppresses right click targeting. Enemies applies everywhere. Allies In Combat only suppresses friendly targets while you are in combat, so you can still right click vendors and NPCs out of combat.\n\nNote: while this is active, holding Left+Right click to move forward won't work if your cursor is over a suppressed nameplate/unit, since this feature has to take over the right mouse button entirely to block targeting.",
		function() return RC_ITEMS end,
		function(v) return DB()[rcKey(v)] and true or false end,
		function(v) DB()[rcKey(v)] = not DB()[rcKey(v)] end,
		function()
			local names = {}
			for _, item in ipairs(RC_ITEMS) do
				if DB()[rcKey(item.value)] then names[#names + 1] = item.name end
			end
			return #names > 0 and table.concat(names, ", ") or "None"
		end)

	-- Secondary Stat Display (multicolor / class / custom swatches + cog)
	local function statsOff() return not XGet("showSecondaryStats") end
	local function ssMode()
		local m = XGet("secondaryStatsColorMode")
		if m then return m end
		return XGet("secondaryStatsColor") and "custom" or "class"
	end
	p:Toggle("Secondary Stat Display", "Displays secondary stat percentages (Crit, Haste, Mastery, Hit, Expertise) at the top left of the screen.",
		function() return XGet("showSecondaryStats") and true or false end, function(v) XSet("showSecondaryStats", v) end)
	p:Swatch("Custom Color",
		function() local c = XGet("secondaryStatsColor"); if c then return c.r, c.g, c.b end; return 1, 1, 1 end,
		function(r, g, b)
			XSet("secondaryStatsColor", { r = r, g = g, b = b })
			XSet("secondaryStatsColorMode", "custom")
		end,
		{ disabled = statsOff, active = function() return ssMode() == "custom" end,
		  onClick = function()
			  if ssMode() ~= "custom" then XSet("secondaryStatsColorMode", "custom"); return true end
		  end })
	p:Swatch(ClassSwatch("Class Color", function() return ssMode() == "class" end,
		function() XSet("secondaryStatsColorMode", "class"); return true end, statsOff))
	p:Swatch("Multicolored", function() return 1, 209 / 255, 0 end, function() end,
		{ readonly = true, disabled = statsOff, active = function() return ssMode() == "palette" end,
		  onClick = function() XSet("secondaryStatsColorMode", "palette"); return true end })
	local function StatItems()
		local items = {}
		for _, key in ipairs(Q.StatOrder()) do
			items[#items + 1] = { value = key, name = Q.STAT_LABELS[key] }
		end
		return items
	end
	local function StatShown(key)
		local hidden = XGet("secondaryStatsHidden")
		return not (type(hidden) == "table" and hidden[key])
	end
	p:Cog("Secondary Stats Settings", {
		{ type = "toggle", label = "Colored Values",
		  get = function() return XGet("coloredPercentages") and true or false end, set = function(v) XSet("coloredPercentages", v) end },
		{ type = "toggle", label = "Abbreviate Stat Labels",
		  get = function() return XGet("secondaryStatsAbbreviateLabels") and true or false end,
		  set = function(v) XSet("secondaryStatsAbbreviateLabels", v) end },
		{ type = "toggle", label = "Show Raw Rating",
		  get = function() return XGet("showSecondaryStatsRaw") and true or false end,
		  set = function(v)
			  XSet("showSecondaryStatsRaw", v)
			  if v then XSet("showSecondaryStatsBoth", false) end
		  end },
		{ type = "toggle", label = "Show % and Raw",
		  get = function() return XGet("showSecondaryStatsBoth") and true or false end,
		  set = function(v)
			  XSet("showSecondaryStatsBoth", v)
			  if v then XSet("showSecondaryStatsRaw", false) end
		  end },
		{ type = "dropdown", label = "Stats to Show", items = StatItems,
		  get = function() return nil end,
		  labelFn = function()
			  local n = 0
			  for _, item in ipairs(StatItems()) do if StatShown(item.value) then n = n + 1 end end
			  return n .. " shown"
		  end,
		  set = function() end,
		  options = { multi = true, isChecked = StatShown,
			  toggle = function(key)
				  local old = XGet("secondaryStatsHidden")
				  local hidden = {}
				  if type(old) == "table" then for k, v in pairs(old) do hidden[k] = v end end
				  if StatShown(key) then hidden[key] = true else hidden[key] = nil end
				  XSet("secondaryStatsHidden", hidden)
			  end } },
		-- Reorder Shown Stats (retail reorder row): the list is the current
		-- order; picking a stat moves it one place up (the first goes last).
		{ type = "dropdown", label = "Reorder Shown Stats", items = function()
			  local items = {}
			  for i, item in ipairs(StatItems()) do
				  items[#items + 1] = { value = item.value, name = i .. ". " .. item.name .. (StatShown(item.value) and "" or " (hidden)") }
			  end
			  return items
		  end,
		  get = function() return nil end,
		  labelFn = function()
			  local names = {}
			  for _, key in ipairs(Q.StatOrder()) do
				  if StatShown(key) then names[#names + 1] = Q.STAT_LABELS[key] end
			  end
			  return #names > 0 and table.concat(names, ", ") or "None"
		  end,
		  set = function(key)
			  local order = Q.StatOrder()
			  for i, k in ipairs(order) do
				  if k == key then
					  table.remove(order, i)
					  if i == 1 then order[#order + 1] = key else table.insert(order, i - 1, key) end
					  break
				  end
			  end
			  XSet("secondaryStatsOrder", order)
		  end },
		{ type = "slider", label = "Scale", min = 50, max = 200, step = 5,
		  get = function()
			  local pos = XGet("secondaryStatsPos")
			  return math.floor(((type(pos) == "table" and pos.scale) or 1) * 100 + 0.5)
		  end,
		  set = function(v)
			  local newPos = {}
			  local prev = XGet("secondaryStatsPos")
			  if type(prev) == "table" then for k, x in pairs(prev) do newPos[k] = x end end
			  newPos.scale = v / 100
			  XSet("secondaryStatsPos", newPos)
		  end },
	}, { disabled = statsOff, disabledTip = "Enable Secondary Stat Display first." })

	-- Rested Indicator | Target Distance (Range) Text
	local function restOff() return DB().showRestedIndicator ~= true end
	p:Toggle("Rested Indicator", "Displays a ZZZ indicator on your player frame when you are in a resting area.",
		function() return DB().showRestedIndicator == true end, Set("showRestedIndicator"),
		function() return not IsAddOnLoaded("EllesmereUIUnitFrames") end)
	p:Cog("Rested Indicator Position", {
		{ type = "slider", label = "X Offset", min = -50, max = 50, step = 1,
		  get = function() return DB().restedIndicatorXOffset or 0 end, set = Set("restedIndicatorXOffset") },
		{ type = "slider", label = "Y Offset", min = -50, max = 50, step = 1,
		  get = function() return DB().restedIndicatorYOffset or 0 end, set = Set("restedIndicatorYOffset") },
	}, { disabled = restOff, disabledTip = "Enable Rested Indicator first." })

	local function tdOff() return not On("targetDistanceEnabled") end
	local TD_FORMATS, TD_FORMAT_LABEL = Items({ "range", "Range (30-35)", "plus", "Lower Bound (30+)", "min", "Minimum (30)" })
	local TD_ALIGNS, TD_ALIGN_LABEL = Items({ "LEFT", "Left", "CENTER", "Center", "RIGHT", "Right" })
	local STRATA_GET, STRATA_LABEL = STRATA_ITEMS, select(2, Items(STRATA))
	p:Toggle("Target Distance (Range) Text", "Shows the approximate distance to your current target as movable on-screen text (default 30-35). Use the cog for format, alignment, and text size; use Unlock Mode to position it.",
		Get("targetDistanceEnabled"), Set("targetDistanceEnabled"))
	p:Cog("Target Distance Settings", {
		{ type = "dropdown", label = "Format", items = TD_FORMATS,
		  get = function() return DB().targetDistanceFormat or "range" end,
		  labelFn = function() return TD_FORMAT_LABEL(DB().targetDistanceFormat or "range") end,
		  set = Set("targetDistanceFormat") },
		{ type = "dropdown", label = "Text Align", items = TD_ALIGNS,
		  get = function() return DB().targetDistanceAlign or "CENTER" end,
		  labelFn = function() return TD_ALIGN_LABEL(DB().targetDistanceAlign or "CENTER") end,
		  set = Set("targetDistanceAlign") },
		{ type = "slider", label = "Text Size", min = 10, max = 48, step = 1,
		  get = function() return DB().targetDistanceTextSize or 18 end, set = Set("targetDistanceTextSize") },
		{ type = "dropdown", label = "Frame Strata", tip = STRATA_TIP, items = STRATA_GET,
		  get = function() return DB().targetDistanceStrata or "HIGH" end,
		  labelFn = function() return STRATA_LABEL(DB().targetDistanceStrata or "HIGH") end,
		  set = Set("targetDistanceStrata") },
	}, { disabled = tdOff, disabledTip = "Enable Target Distance (Range) Text first." })
end

---------------------------------------------------------------------------
-- CROSSHAIR (crosshair* keys of the cursor settings)
---------------------------------------------------------------------------
local function BuildCrosshair(p)
	p:Section("Crosshair")
	local CG, CS = Q.CGet, Q.CSet
	local P = Q.CROSSHAIR_PRESETS
	local function off() return (CG("crosshairSize") or "None") == "None" end
	local function presetWidth()
		local pr = P[CG("crosshairSize")] or P.Normal
		return pr.width
	end
	local function current()
		local size = CG("crosshairSize") or "None"
		if size == "None" then return "None" end
		local hw = CG("crosshairHWidth") or presetWidth()
		local vw = CG("crosshairVWidth") or presetWidth()
		if hw == vw then
			for name, pr in pairs(P) do
				if pr.width == hw then return name end
			end
		end
		return "custom"
	end
	local SIZES, SIZE_LABEL = Items({ "None", "None", "Thin", "Thin", "Normal", "Normal", "Thick", "Thick", "custom", "Custom" })
	p:Dropdown("Character Crosshair", "Displays a crosshair at the center of the screen.",
		SIZES, current, function() return SIZE_LABEL(current()) end,
		function(v)
			if v == "custom" then
				if current() ~= "custom" then return end
				return
			end
			CS("crosshairSize", v)
			local pr = P[v]
			if pr then
				CS("crosshairHWidth", pr.width)
				CS("crosshairVWidth", pr.width)
			end
		end)
	p:Swatch("Crosshair Color",
		function() local c = CG("crosshairColor"); if c then return c.r, c.g, c.b, c.a end; return 1, 1, 1, 0.75 end,
		function(r, g, b, a) CS("crosshairColor", { r = r, g = g, b = b, a = a or 1 }) end,
		{ alpha = true, disabled = off })
	local chRows = {
		{ type = "slider", label = "H Length", min = 1, max = 500, step = 1,
		  get = function() return CG("crosshairHLength") or 40 end, set = function(v) CS("crosshairHLength", v) end },
		{ type = "slider", label = "H Width", min = 1, max = 20, step = 1,
		  get = function() return CG("crosshairHWidth") or presetWidth() end, set = function(v) CS("crosshairHWidth", v) end },
		{ type = "slider", label = "V Length", min = 1, max = 500, step = 1,
		  get = function() return CG("crosshairVLength") or 40 end, set = function(v) CS("crosshairVLength", v) end },
		{ type = "slider", label = "V Width", min = 1, max = 20, step = 1,
		  get = function() return CG("crosshairVWidth") or presetWidth() end, set = function(v) CS("crosshairVWidth", v) end },
		{ type = "slider", label = "Border", min = 0, max = 5, step = 1,
		  get = function() return CG("crosshairBorderSize") or 0 end, set = function(v) CS("crosshairBorderSize", v) end },
		{ type = "color", label = "Border Color", alpha = true,
		  get = function() local c = CG("crosshairBorderColor"); if c then return c.r, c.g, c.b, c.a end; return 0, 0, 0, 1 end,
		  set = function(r, g, b, a) CS("crosshairBorderColor", { r = r, g = g, b = b, a = a or 1 }) end },
		{ type = "slider", label = "X Offset", min = -200, max = 200, step = 1,
		  get = function() return CG("crosshairXOffset") or 0 end, set = function(v) CS("crosshairXOffset", v) end },
		{ type = "slider", label = "Y Offset", min = -200, max = 200, step = 1,
		  get = function() return CG("crosshairYOffset") or 0 end, set = function(v) CS("crosshairYOffset", v) end },
		{ type = "dropdown", label = "Frame Strata", tip = STRATA_TIP, items = STRATA_ITEMS,
		  get = function() return CG("crosshairStrata") or "MEDIUM" end,
		  labelFn = function() return select(2, Items(STRATA))(CG("crosshairStrata") or "MEDIUM") end,
		  set = function(v) CS("crosshairStrata", v) end },
	}
	if select(2, UnitClass("player")) == "PALADIN" then
		chRows[#chRows + 1] = { type = "toggle", label = "Show Melee Range for Hpal",
			get = function() return CG("crosshairHpalMelee") == true end,
			set = function(v) CS("crosshairHpalMelee", v) end }
	end
	p:Cog("Crosshair Options", chRows, { disabled = off, disabledTip = "Enable the crosshair first." })

	-- Visibility: Always / Combat / Instances (Combat + Instances = both).
	local VIS_ITEMS = {
		{ value = "always", name = "Always" }, { value = "combat", name = "Combat" }, { value = "instances", name = "Instances" },
	}
	local function curVis() return CG("crosshairVisibility") or "always" end
	local function visOn(k)
		local v = curVis()
		if k == "always" then return v == "always" end
		if k == "combat" then return v == "combat" or v == "instances_combat" end
		return v == "instances" or v == "instances_combat"
	end
	p:MultiSelect("Visibility", "Choose when the crosshair is shown.\n\nAlways: always show the crosshair.\nCombat: only while in combat.\nInstances: only in a dungeon, raid, arena or battleground. Combine Combat and Instances to show only during instanced combat.",
		function() return VIS_ITEMS end, visOn,
		function(k)
			local combat, instances = visOn("combat"), visOn("instances")
			if k == "always" then
				combat, instances = false, false
			elseif k == "combat" then
				combat = not combat
			else
				instances = not instances
			end
			local nv = "always"
			if combat and instances then nv = "instances_combat"
			elseif combat then nv = "combat"
			elseif instances then nv = "instances" end
			CS("crosshairVisibility", nv)
		end,
		function()
			local names = {}
			for _, item in ipairs(VIS_ITEMS) do
				if visOn(item.value) then names[#names + 1] = item.name end
			end
			return table.concat(names, ", ")
		end, off)

	local function meleeOff() return off() or CG("crosshairMeleeColorEnabled") ~= true end
	p:Toggle("Color Out of Range", "Changes the crosshair color when your current target is out of range. Currently active range cutoff: "
		.. Q.CrosshairCutoff() .. "yd.",
		function() return CG("crosshairMeleeColorEnabled") == true end,
		function(v) CS("crosshairMeleeColorEnabled", v) end, off)
	p:Swatch("Out of Range Color",
		function() local c = CG("crosshairMeleeColor"); if c then return c.r, c.g, c.b, c.a end; return 1, 0, 0, 1 end,
		function(r, g, b, a) CS("crosshairMeleeColor", { r = r, g = g, b = b, a = a or 1 }) end,
		{ alpha = true, disabled = meleeOff })
	p:Blank()
end

---------------------------------------------------------------------------
-- SELF COMBAT TEXT (EllesmereUIQoLDB.selfCombatText)
---------------------------------------------------------------------------
local function BuildSelfCombatText(p)
	p:Section("Self Combat Text")
	local SGet, SSet = Q.SCT_Get, Q.SCT_Set
	local function sctOff() return not SGet("enabled") end
	local function sctToggle(label, key)
		p:Toggle(label, nil, function() return SGet(key) and true or false end, function(v) SSet(key, v) end, sctOff)
	end
	local function sctDropdown(label, key, list)
		local items, labelOf = Items(list)
		p:Dropdown(label, nil, items, function() return SGet(key) end,
			function() return labelOf(SGet(key)) end, function(v) SSet(key, v) end, nil, sctOff)
	end
	local function sctSwatch(key, colorKey, label)
		p:Swatch(label .. " Color",
			function() local c = SGet(colorKey); return c.r, c.g, c.b end,
			function(r, g, b) SSet(colorKey, { r = r, g = g, b = b }) end,
			{ disabled = function() return sctOff() or not SGet(key) end })
	end

	p:Toggle("Self Combat Text", "Shows your damage taken, healing, avoids and combat enter/leave above the player frame instead of Blizzard's combat text, whose other messages are hidden while this is on. Move it in Unlock Mode.",
		function() return not sctOff() end, function(v) SSet("enabled", v) end)
	p:Cog("Self Combat Text", {
		{ type = "slider", label = "Scroll Distance", min = 20, max = 300, step = 5,
		  get = function() return SGet("rise") end, set = function(v) SSet("rise", v) end },
		{ type = "slider", label = "Scroll Duration", min = 0.5, max = 4, step = 0.1,
		  get = function() return SGet("duration") end, set = function(v) SSet("duration", v) end },
		{ type = "slider", label = "Crit Scale", min = 1, max = 3, step = 0.1,
		  get = function() return SGet("critScale") end, set = function(v) SSet("critScale", v) end },
		{ type = "toggle", label = "Stagger Hits", tip = "Spaces out hits that land together so none hides another.",
		  get = function() return SGet("stagger") and true or false end, set = function(v) SSet("stagger", v) end },
	}, { disabled = sctOff, disabledTip = "Enable Self Combat Text first." })
	p:Slider("Combat Text Size", nil, 10, 48, 1,
		function() return SGet("size") end, function(v) SSet("size", v) end, sctOff)

	-- The rows below exist only while Self Combat Text is on (like retail).
	if sctOff() then
		return
	end
	sctDropdown("Animation", "anim", { "straight", "Straight", "fountain", "Fountain", "static", "Static" })
	sctDropdown("Scroll Direction", "direction", { "up", "Up", "down", "Down" })

	local function FontList()
		local items = { { value = "__combat", name = "Combat Text Font" }, { value = "__global", name = "EUI Global Default" } }
		if ns.GetFonts then
			for _, e in ipairs(U.MediaItems(ns.GetFonts())) do items[#items + 1] = e end
		end
		return items
	end
	p:Dropdown("Font", nil, FontList, function() return SGet("font") end,
		function()
			local v = SGet("font")
			for _, item in ipairs(FontList()) do
				if item.value == v then return item.name end
			end
			return ns.GetFontLabel and ns.GetFontLabel(v) or tostring(v)
		end,
		function(v) SSet("font", v) end,
		{ fontPreview = true, fontPath = function(v)
			if v == "__global" then return Q.Font() end
			if v == "__combat" then return (CombatTextFont and CombatTextFont:GetFont()) or STANDARD_TEXT_FONT end
			return v
		end }, sctOff)
	sctDropdown("Outline", "outline", { "NONE", "None", "OUTLINE", "Outline", "THICKOUTLINE", "Thick Outline" })

	sctToggle("Text Shadow", "shadow")
	sctToggle("Abbreviate Numbers", "abbreviate")

	sctToggle("Show Damage Taken", "damage")
	sctSwatch("damage", "damageColor", "Show Damage Taken")
	sctToggle("Show Healing Received", "heal")
	sctSwatch("heal", "healColor", "Show Healing Received")

	sctToggle("Show Avoidance", "avoid")
	sctSwatch("avoid", "avoidColor", "Show Avoidance")
	sctToggle("Show Combat Enter/Leave", "combat")
	sctSwatch("combat", "combatColor", "Show Combat Enter/Leave")
end

---------------------------------------------------------------------------
-- GROUP FINDER / UI
---------------------------------------------------------------------------
local function BuildGroupFinder(p)
	p:Section("Group Finder")
	p:Toggle("Announce Instance Reset", "After a successful instance reset, automatically announces it in party or raid chat so your group knows they can re-enter.",
		Get("instanceResetAnnounce"), Set("instanceResetAnnounce"))
	p:Blank()
end

local function BuildUI(p)
	p:Section("UI")
	p:Toggle("Hide Screenshot Status", "Hides the 'Screenshot saved' notification that appears on screen after taking a screenshot.",
		Get("hideScreenshotStatus"), Set("hideScreenshotStatus"))
	p:Toggle("Train All Button", "Adds a 'Train All' button next to the Train button at profession trainers, allowing you to learn all available skills with one click.",
		Get("trainAllButton"), Set("trainAllButton"))

	p:Toggle("Auto Open Containers", "Automatically opens bags, boxes and parcels in your inventory when they are added to your bags.\n\nContainers received from the mailbox are held until you close the mailbox, so opening them cannot collide with mail still delivering items.",
		Get("autoOpenContainers"), Set("autoOpenContainers"))

	local function bonusConflict() return IsAddOnLoaded("BonusRollConfirm") end
	p:Toggle("Bonus Roll Confirmation", "Asks before spending a bonus roll and shows your loot specialization. Use the cog to also confirm Pass.",
		Get("bonusRollConfirmation"), Set("bonusRollConfirmation"), bonusConflict)
	p:Cog("Bonus Roll Settings", {
		{ type = "toggle", label = "Only Confirm Roll", tip = "Pass immediately without confirmation. Turn off to confirm both Roll and Pass.",
		  get = Get("bonusRollOnly"), set = Set("bonusRollOnly") },
	}, { disabled = function() return bonusConflict() or not On("bonusRollConfirmation") end,
		disabledTip = "Enable Bonus Roll Confirmation first." })
end

local function BuildQoLPage(p)
	-- Retail draws the Macro Factory at the top of this page.
	if ns.QoLO_BuildMacroFactory then
		ns.QoLO_BuildMacroFactory(p)
	end
	BuildGeneral(p)
	BuildExtras(p)
	BuildCrosshair(p)
	BuildSelfCombatText(p)
	BuildGroupFinder(p)
	BuildUI(p)
	-- Retail draws the Auto Logging part at the end of this page.
	if ns.QoLO_BuildAutoLoggingPage then
		ns.QoLO_BuildAutoLoggingPage(p)
	end
end

---------------------------------------------------------------------------
-- Battle Res & Lust (5.4.8 tab; retail draws these at the end of its pages)
---------------------------------------------------------------------------
local function BuildBattleRes(p)
	-- Retail EUI_QoL_BattleRes_Options.lua. Settings apply through
	-- ns.applyHooks (the runtime adds one), so setters only store.
	if not ns.GetBattleResDB then
		return
	end
	local function BR() return ns.GetBattleResDB() end
	local VIS, VIS_LABEL = Items({
		"MPLUS_AND_RAID", "Challenge Mode and Raid",
		"MPLUS", "Challenge Mode",
		"RAID", "Raid",
		"NEVER", "Never",
	})
	local SHAPES, SHAPE_LABEL = Items({ "none", "None", "cropped", "Cropped" })
	local STYLES, STYLE_LABEL = Items({ "icon", "Icon", "text", "Text" })
	local OUTLINES, OUTLINE_LABEL = Items({
		"__global", "EUI Global Default",
		"none", "Drop Shadow",
		"outline", "Outline",
		"thick", "Thick Outline",
	})
	local BORDER_STEPS = { [0] = "none", "thin", "normal", "heavy", "strong" }

	local function never() return BR().visibility == "NEVER" end
	local function textMode() return BR().displayMode == "text" end
	local function iconOff() return never() or textMode() end
	local function textOff() return never() or not textMode() end

	-- Live preview: the icon stays on screen while this page is shown.
	-- (The settings search builds pages with a recorder: no scroll frame.)
	if ns.BattleResSetPreviewOwner and type(p.scroll) == "table" and not p.scroll.brezHooked then
		p.scroll.brezHooked = true
		p.scroll:HookScript("OnShow", function(self) ns.BattleResSetPreviewOwner(self) end)
		p.scroll:HookScript("OnHide", function() ns.BattleResUpdateVisibility() end)
	end

	p:Section("Battle Res")
	p:Dropdown("Enable BattleRes Icon", "Where the icon is shown: during raid boss fights and/or in Challenge Mode dungeons.\n\nRaid: brez left this attempt (10-player 1, 25-player and LFR 3). Challenge Mode has no limit: the count is the brez casters ready now.\n\nThe timer shows when the next Druid, Death Knight, Warlock (or quilen Hunter) brez is ready, while none is.",
		VIS, function() return BR().visibility end, function() return VIS_LABEL(BR().visibility) end,
		function(v) BR().visibility = v end)
	p:Slider("Icon Size", "Size of the icon.", 16, 120, 1,
		function() return BR().iconSize end, function(v) BR().iconSize = v end, iconOff)

	p:Dropdown("Icon Shape", "None: square icon. Cropped: wider than tall.",
		SHAPES, function() return BR().shape end, function() return SHAPE_LABEL(BR().shape) end,
		function(v) BR().shape = v end, nil, iconOff)
	p:Label("Border Color", "Custom color or the class color of your character.", iconOff)
	p:Swatch("Class Colored",
		function() return Q.ClassColor() end,
		function() end,
		{ readonly = true, active = function() return BR().borderUseClass end,
		  onClick = function() BR().borderUseClass = true; return true end })
	p:Swatch("Custom Color",
		function()
			local c = BR().borderColor
			return c.r, c.g, c.b
		end,
		function(r, g, b) BR().borderColor = { r = r, g = g, b = b, a = 1 } end,
		{ active = function() return not BR().borderUseClass end,
		  onClick = function()
			  if BR().borderUseClass then
				  BR().borderUseClass = false
				  return true
			  end
		  end })

	p:Slider("Border Size", "Border thickness in pixels (0 = no border).", 0, 4, 1,
		function()
			local word = BR().borderSize
			for step = 0, 4 do
				if BORDER_STEPS[step] == word then return step end
			end
			return 1
		end,
		function(v) BR().borderSize = BORDER_STEPS[math.floor(v + 0.5)] or "thin" end, iconOff)
	p:Slider("Icon Zoom", "Crops the edge of the icon art (percent).", 0, 20, 0.5,
		function() return BR().iconZoom end, function(v) BR().iconZoom = v end, iconOff)

	local function OffsetCog(title, xKey, yKey)
		p:Cog(title, {
			{ type = "slider", label = "X Offset", min = -50, max = 50, step = 1,
			  get = function() return BR()[xKey] or 0 end, set = function(v) BR()[xKey] = v end },
			{ type = "slider", label = "Y Offset", min = -50, max = 50, step = 1,
			  get = function() return BR()[yKey] or 0 end, set = function(v) BR()[yKey] = v end },
		}, { icon = "resize", disabled = iconOff })
	end
	p:Slider("Duration Size", "Size of the timer in the middle of the icon.", 8, 30, 1,
		function() return BR().durationSize end, function(v) BR().durationSize = v end, iconOff)
	OffsetCog("Duration Position", "durationOffsetX", "durationOffsetY")
	p:Slider("Count Size", "Size of the count in the corner of the icon (red at 0).", 8, 20, 1,
		function() return BR().countSize end, function(v) BR().countSize = v end, iconOff)
	OffsetCog("Count Position", "countOffsetX", "countOffsetY")

	p:Dropdown("Display Style", "Show the tracker as the Rebirth icon or as a compact text line with charges and time until the next one.",
		STYLES, function() return BR().displayMode end, function() return STYLE_LABEL(BR().displayMode) end,
		function(v) BR().displayMode = v end, nil, never)
	p:Cog("Icon Settings", {
		{ type = "toggle", label = "Desaturate when No Charges",
		  get = function() return BR().desaturateNoCharges ~= false end,
		  set = function(v) BR().desaturateNoCharges = v end },
	}, { disabled = iconOff })
	p:Swatch("Timer Color",
		function() local c = BR().textTimerColor; return c.r, c.g, c.b end,
		function(r, g, b) BR().textTimerColor = { r = r, g = g, b = b } end,
		{ disabled = textOff })
	p:Swatch("Count Color",
		function() local c = BR().textCountColor; return c.r, c.g, c.b end,
		function(r, g, b) BR().textCountColor = { r = r, g = g, b = b } end,
		{ disabled = textOff })
	p:Slider("Text Size", "Size of the text display.", 8, 40, 1,
		function() return BR().textSize end, function(v) BR().textSize = v end, textOff)

	local function FontItems()
		local items = { { name = "EUI Global Default", value = "__global" } }
		return items
	end
	p:Dropdown("Font", "Font of the text display.",
		FontItems,
		function() return BR().font end,
		function()
			for _, item in ipairs(FontItems()) do
				if item.value == BR().font then return item.name end
			end
			return tostring(BR().font)
		end,
		function(v) BR().font = v end,
		{ fontPreview = true, fontPath = function(v)
			if v == "__global" then return ns.GetFontPath("qol") end
			return ns.ResolveFontName(v)
		end }, textOff)
	p:Dropdown("Font Outline", "Outline of the text display.",
		OUTLINES, function() return BR().outlineMode end, function() return OUTLINE_LABEL(BR().outlineMode) end,
		function(v) BR().outlineMode = v end, nil, textOff)

	-- Bloodlust Tracker (retail _EUI_BuildBloodlustSection): appearance
	-- reads through to Battle Res until changed here.
	if not ns.GetBloodlustDB then
		return
	end
	local function BL() return ns.GetBloodlustDB() end
	local LGet = ns.BloodlustGet
	local function LSet(key, v) BL()[key] = v end
	local function blNever() return BL().visibility == "NEVER" end
	local function readyOff() return blNever() or BL().showReady ~= true end

	if ns.BloodlustSetPreviewOwner and type(p.scroll) == "table" and not p.scroll.lustHooked then
		p.scroll.lustHooked = true
		p.scroll:HookScript("OnShow", function(self) ns.BloodlustSetPreviewOwner(self) end)
		p.scroll:HookScript("OnHide", function() ns.BloodlustUpdateVisibility() end)
	end

	p:Section("Bloodlust Tracker")
	p:Dropdown("Enable Bloodlust Icon", "Shows your Sated / Exhaustion lockout (time until you can get Bloodlust, Heroism, Time Warp, Ancient Hysteria or Drums of Rage again). While the lust buff is active its own icon and seconds left are shown on top.\n\nSame places as the Battle Res icon: raid boss fights and/or Challenge Mode dungeons.",
		VIS, function() return BL().visibility end, function() return VIS_LABEL(BL().visibility) end,
		function(v)
			local was = BL().visibility
			LSet("visibility", v)
			if was == "NEVER" and v ~= "NEVER" and ns.BloodlustSeedPos then
				ns.BloodlustSeedPos()
			end
		end)
	p:Slider("Icon Size", "Size of the icon.", 16, 120, 1,
		function() return LGet("iconSize") end, function(v) LSet("iconSize", v) end, blNever)

	p:Dropdown("Icon Shape", "None: square icon. Cropped: wider than tall.",
		SHAPES, function() return LGet("shape") end, function() return SHAPE_LABEL(LGet("shape")) end,
		function(v) LSet("shape", v) end, nil, blNever)
	p:Label("Border Color", "Custom color or the class color of your character.", blNever)
	p:Swatch("Class Colored",
		function() return Q.ClassColor() end,
		function() end,
		{ readonly = true, active = function() return LGet("borderUseClass") end,
		  onClick = function() LSet("borderUseClass", true); return true end })
	p:Swatch("Custom Color",
		function()
			local c = LGet("borderColor")
			return c.r, c.g, c.b
		end,
		function(r, g, b) LSet("borderColor", { r = r, g = g, b = b, a = 1 }) end,
		{ active = function() return not LGet("borderUseClass") end,
		  onClick = function()
			  if LGet("borderUseClass") then
				  LSet("borderUseClass", false)
				  return true
			  end
		  end })

	p:Slider("Border Size", "Border thickness in pixels (0 = no border).", 0, 4, 1,
		function()
			local word = LGet("borderSize")
			for step = 0, 4 do
				if BORDER_STEPS[step] == word then return step end
			end
			return 1
		end,
		function(v)
			local word = BORDER_STEPS[math.floor(v + 0.5)] or "thin"
			-- Only a real change stores an override (keeps following Battle Res).
			if word ~= LGet("borderSize") then LSet("borderSize", word) end
		end, blNever)
	p:Slider("Icon Zoom", "Crops the edge of the icon art (percent).", 0, 20, 0.5,
		function() return LGet("iconZoom") end, function(v) LSet("iconZoom", v) end, blNever)

	local function LustCog(title, xKey, yKey, off)
		p:Cog(title, {
			{ type = "slider", label = "X Offset", min = -50, max = 50, step = 1,
			  get = function() return LGet(xKey) or 0 end, set = function(v) LSet(xKey, v) end },
			{ type = "slider", label = "Y Offset", min = -50, max = 50, step = 1,
			  get = function() return LGet(yKey) or 0 end, set = function(v) LSet(yKey, v) end },
		}, { icon = "resize", disabled = off or blNever })
	end
	p:Slider("Duration Size", "Size of the timer in the middle of the icon.", 8, 30, 1,
		function() return LGet("durationSize") end, function(v) LSet("durationSize", v) end, blNever)
	LustCog("Duration Position", "durationOffsetX", "durationOffsetY")
	p:Slider("Count Size", "Size of the count text (kept for the same layout as Battle Res).", 8, 20, 1,
		function() return LGet("countSize") end, function(v) LSet("countSize", v) end, blNever)
	LustCog("Count Position", "countOffsetX", "countOffsetY")

	p:Toggle("Show Icon when Sated", "Show the Sated/Exhaustion lockout countdown on the icon.",
		function() return BL().showSated ~= false end, function(v) LSet("showSated", v) end, blNever)
	p:Cog("Sated Settings", {
		{ type = "toggle", label = "Desaturate when Sated",
		  get = function() return BL().desaturateSated ~= false end,
		  set = function(v) LSet("desaturateSated", v) end },
	}, { disabled = function() return blNever() or BL().showSated == false end })
	p:Toggle("Show Icon with Ready Text", "Once the lockout expires, show a Ready label on the icon in place of the countdown. The visibility rule above still applies.",
		function() return BL().showReady == true end, function(v) LSet("showReady", v) end, blNever)

	p:Slider("Ready Size", "Size of the Ready label.", 8, 30, 1,
		function() return BL().readySize end, function(v) LSet("readySize", v) end, readyOff)
	p:Swatch("Ready Color",
		function() local c = BL().readyColor; return c.r, c.g, c.b end,
		function(r, g, b) LSet("readyColor", { r = r, g = g, b = b }) end,
		{ disabled = readyOff })
	LustCog("Ready Position", "readyOffsetX", "readyOffsetY", readyOff)
	p:Blank()
end

---------------------------------------------------------------------------
-- Raid Timeline (retail Raid Ability Timeline, fed by DBM / BigWigs)
---------------------------------------------------------------------------
local function BuildRaidTimeline(p)
	if not ns.GetRaidTimelineDB then
		return
	end
	local function RT() return ns.GetRaidTimelineDB() end
	local function RGet(k) return function() return RT()[k] end end
	local function RSet(k) return function(v) RT()[k] = v end end
	local function off() return not RT().enabled end
	local ORIENT, ORIENT_LABEL = Items({ "HORIZONTAL", "Horizontal", "VERTICAL", "Vertical" })

	-- Live preview: sample abilities run on the timeline while this page is shown.
	if ns.RaidTimelineSetPreviewOwner and type(p.scroll) == "table" and not p.scroll.rtHooked then
		p.scroll.rtHooked = true
		p.scroll:HookScript("OnShow", function(self) ns.RaidTimelineSetPreviewOwner(self) end)
		p.scroll:HookScript("OnHide", function() ns.RaidTimelineSetPreviewOwner(nil) end)
	end

	p:Section("Raid Timeline")
	p:Toggle("Enable Raid Timeline", "Shows boss ability timers from DBM or BigWigs on a timeline like the retail Raid Ability Timeline: abilities wait in the slots on the left, slide along the line as they come up and pulse once they pass the pip.\n\nMove it in Unlock Mode.",
		RGet("enabled"), RSet("enabled"))
	p:Toggle("Use DBM Timers", "Put DBM timer bars on the timeline.", RGet("useDBM"), RSet("useDBM"), off)
	p:Toggle("Use BigWigs Timers", "Put BigWigs timer bars on the timeline.", RGet("useBigWigs"), RSet("useBigWigs"), off)
	p:Toggle("Hide DBM Timer Bars", "Hide DBM's own timer bars while the timeline shows them. (BigWigs bars are turned off in BigWigs.)",
		RGet("hideBossModBars"), RSet("hideBossModBars"), function() return off() or not RT().useDBM end)
	p:Toggle("Only in Combat", "Only show the timeline during a boss fight or while you are in combat (pull and break timers are left out of combat).",
		RGet("combatOnly"), RSet("combatOnly"), off)

	p:Section("Layout")
	p:Dropdown("Orientation", "Horizontal: abilities travel along a line. Vertical: they travel down a column, with spell names beside them.",
		ORIENT, RGet("orientation"), function() return ORIENT_LABEL(RT().orientation) end, RSet("orientation"), nil, off)
	p:Toggle("Reverse Direction", "Horizontal: travel right to left. Vertical: travel bottom to top.", RGet("reverse"), RSet("reverse"), off)
	p:Slider("Icon Size", "Size of the ability icons.", 20, 64, 1, RGet("iconSize"), RSet("iconSize"), off)
	p:Slider("Line Length", "Length of the line (the Short track) in pixels.", 120, 600, 5, RGet("shortLength"), RSet("shortLength"), off)
	p:Slider("Line Seconds", "Seconds covered by the line. Abilities closer than this travel along it.", 5, 30, 1, RGet("shortDuration"), RSet("shortDuration"), off)
	p:Slider("Approach Length", "Length of the faded part before the line (the Medium track) in pixels.", 0, 200, 5, RGet("mediumLength"), RSet("mediumLength"), off)
	p:Slider("Approach Seconds", "Abilities further away than this wait in the slots at the start.", 5, 60, 1, RGet("mediumDuration"), RSet("mediumDuration"), off)
	p:Slider("Waiting Slots", "How many upcoming abilities wait at the start of the timeline (0 = none).", 0, 8, 1, RGet("longSlots"), RSet("longSlots"), off)
	p:Slider("Highlight Time", "Seconds left at the pip: abilities flash when they pass it and pulse until they happen.", 1, 10, 1, RGet("highlightTime"), RSet("highlightTime"), off)

	p:Section("Look")
	p:Toggle("Show Pip", "Diamond on the line at the highlight time.", RGet("showPip"), RSet("showPip"), off)
	p:Toggle("Show Pip Text", "Highlight time next to the pip.", RGet("showPipText"), RSet("showPipText"), off)
	p:Toggle("Show Countdown", "Seconds left on the icons.", RGet("showCountdown"), RSet("showCountdown"), off)
	p:Slider("Countdown Size", "Size of the seconds on the icons.", 8, 30, 1, RGet("countdownSize"), RSet("countdownSize"),
		function() return off() or RT().showCountdown == false end)
	p:Toggle("Show Spell Names", "Ability names beside the icons (vertical) or above them (horizontal).", RGet("showNames"), RSet("showNames"), off)
	p:Slider("Name Size", "Size of the ability names.", 8, 20, 1, RGet("nameSize"), RSet("nameSize"),
		function() return off() or not RT().showNames end)
	p:Toggle("Show Trail", "Glow trail behind the icons moving along the line.", RGet("showTrail"), RSet("showTrail"), off)
	p:Toggle("Icon Border", "Thin black border around the icons.", RGet("showBorder"), RSet("showBorder"), off)
	p:Swatch("Line Color",
		function() local c = RT().lineColor; return c.r, c.g, c.b end,
		function(r, g, b) RT().lineColor = { r = r, g = g, b = b } end,
		{ disabled = off })
	p:Slider("Background Opacity", "Dark backdrop behind the timeline (percent).", 0, 100, 5,
		function() return math.floor((RT().backgroundAlpha or 0) * 100 + 0.5) end,
		function(v) RT().backgroundAlpha = v / 100 end, off)
	p:Blank()
end

---------------------------------------------------------------------------
-- Tabs (retail order: QoL, Raid Tools, Cursor, Shifter, MoveAlert)
---------------------------------------------------------------------------
-- The other tabs come from their own options files; a missing builder
-- shows a "not available" line.
local function ExternalTab(key, name, description, builderName, prefix)
	return {
		key = key,
		name = name,
		description = description,
		build = function(p)
			local build = ns[builderName]
			if type(build) == "function" then
				build(p)
			else
				p:Section(name)
				p:Label(name .. " is not available.", "Its settings file did not load.")
				p:Blank()
			end
		end,
		pageKey = ns["QoLO_" .. prefix .. "PageKey"],
		header = ns["QoLO_" .. prefix .. "Header"],
	}
end

local QOL_PAGES = {
	{
		key = "qol",
		name = "QoL",
		description = "Quality of life features and custom cursor.",
		build = BuildQoLPage,
	},
	ExternalTab("raidtools", "Raid Tools", "Pull timer, ready check, raid markers and more.", "QoLO_BuildRaidToolsPage", "RaidTools"),
	ExternalTab("cursor", "Cursor", "Custom cursor ring, GCD and cast circles.", "QoLO_BuildCursorPage", "Cursor"),
	ExternalTab("shifter", "Shifter", "Move Blizzard frames and remember where you put them.", "QoLO_BuildShifterPage", "Shifter"),
	ExternalTab("movealert", "MoveAlert", "Alerts for your movement abilities.", "QoLO_BuildMovementAlertPage", "MovementAlert"),
	{
		key = "battleres",
		name = "Battle Res & Lust",
		description = "Battle Res: combat resurrections left and when the next one is ready. Bloodlust Tracker: your Sated lockout and the active lust.",
		build = BuildBattleRes,
	},
	{
		key = "raidtimeline",
		name = "Raid Timeline",
		description = "Boss ability timeline (like the retail Raid Ability Timeline) fed by DBM or BigWigs timers.",
		build = BuildRaidTimeline,
	},
}

ns.RegisterSettingsModule({
	key = "qol",
	name = "Quality of Life",
	group = "QoL Addons",
	tabs = QOL_PAGES,
	reset = function()
		ns.ResetQoLSettings()
		if Q.SCT_Reset then Q.SCT_Reset() end
	end,
	resetTip = "Set all Quality of Life settings back to default.",
	onLeave = function()
		if Q.DurPreview and Q.DurPreviewShown() then Q.DurPreview(false) end
	end,
})
