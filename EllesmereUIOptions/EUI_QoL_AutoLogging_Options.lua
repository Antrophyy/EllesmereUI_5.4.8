-- Settings for Quality of Life > Auto Logging (retail EUI_QoL_AutoLogging_Options.lua,
-- AUTO COMBAT LOGGING section). The /keys popup and LFG Reminder sections of
-- that retail page are not part of the 5.4.8 port (no keystones, no dungeon
-- teleports). Tab builder only: EUI_QoL_Options.lua adds the tab.

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUIQoL") then
	return
end

-- Mists labels (see the runtime for the difficulty mapping). No Mythic raid
-- in Mists, so that retail row is not shown (its key is kept).
local TRIGGER_ITEMS = {
	{ value = "logHeroic",   name = "Heroic Raid" },
	{ value = "logNormal",   name = "Normal Raid" },
	{ value = "logLFR",      name = "LFR" },
	{ value = "log5pp",      name = "Challenge Mode Dungeons" },
	{ value = "logDungeon",  name = "Heroic Dungeons" },
	{ value = "logArena",    name = "Arena" },
	{ value = "logScenario", name = "Scenarios" },
}

local function Cfg()
	return ns.GetAutoLoggingDB and ns.GetAutoLoggingDB() or {}
end

local function Trigger(k)
	local v = Cfg()[k]
	if v == nil then
		local d = ns.AutoLoggingDefaults
		return d and d[k]
	end
	return v
end

ns.QoLO_BuildAutoLoggingPage = function(p)
	local function off() return Cfg().enabled ~= true end

	p:Section("Auto Combat Logging")
	p:Toggle("Enable Auto Logging", "Automatically starts and stops combat logging when entering or leaving a loggable instance.",
		function() return Cfg().enabled == true end,
		function(v) Cfg().enabled = v or nil end)
	p:MultiSelect("Auto-Log Triggers", "Instance types that start combat logging.\n\nNormal Raid includes Flexible. Only Mists of Pandaria raids and dungeons are logged.",
		function() return TRIGGER_ITEMS end,
		function(k) return Trigger(k) and true or false end,
		function(k) Cfg()[k] = not Trigger(k) end,
		function()
			local n = 0
			for _, item in ipairs(TRIGGER_ITEMS) do
				if Trigger(item.value) then n = n + 1 end
			end
			return n .. " selected"
		end, off)
	-- Retail hides this row while Auto Logging is off (toggles rebuild the page).
	if Cfg().enabled == true then
		p:Toggle("Warcraft Recorder Compatibility", "Delays stopping combat logging by 30 seconds after leaving an instance. Recommended for Warcraft Recorder compatibility.",
			function() return Trigger("delaystop") and true or false end,
			function(v) Cfg().delaystop = v end)
	end
end
