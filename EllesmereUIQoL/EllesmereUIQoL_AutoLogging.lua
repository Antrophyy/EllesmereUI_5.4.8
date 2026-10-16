-------------------------------------------------------------------------------
--  EllesmereUIQoL_AutoLogging.lua (5.4.8 port of retail Auto Combat Logging)
--
--  Turns combat logging on when you enter a loggable instance and off when
--  you leave it. Also turns on Advanced Combat Logging when logging starts.
--  Same saved table as retail: EllesmereUIDB.autoLogging (account wide).
--
--  Mists difficulties (GetInstanceInfo 3rd return):
--    3 = 10 Normal, 4 = 25 Normal, 14 = Flexible  -> Normal Raid
--    5 = 10 Heroic, 6 = 25 Heroic                 -> Heroic Raid
--    7 = Raid Finder                              -> LFR
--    8 = Challenge Mode                           -> Mythic+ Dungeons trigger
--    2 = Heroic dungeon                           -> Dungeons (WoW Forever key)
--    11 / 12 = Heroic / Normal scenario           -> Scenarios
--  There is no Mythic raid in Mists: the Mythic Raid trigger never matches.
-------------------------------------------------------------------------------
local addonName = ...
local ns = EllesmereUI

-- Mists content only (old raids and dungeons are skipped, like retail skips
-- legacy content): Terrace of Endless Spring (996) is the lowest Mists raid,
-- Shado-Pan Monastery (959) the lowest Mists dungeon.
local MISTS_RAID_THRESHOLD    = 996
local MISTS_DUNGEON_THRESHOLD = 959

local LFR_DIFFICULTIES = { [7] = true }

local RAID_DIFF_KEYS = {
	[5]  = "logHeroic",
	[6]  = "logHeroic",
	[3]  = "logNormal",
	[4]  = "logNormal",
	[14] = "logNormal",  -- Flexible
}

-- Defaults: everything on except Scenarios (and Dungeons, the WoW Forever key).
local TRIGGER_DEFAULTS = {
	logMythic   = true,
	logHeroic   = true,
	logNormal   = true,
	logLFR      = true,
	log5pp      = true,
	logArena    = true,
	logScenario = false,
	logDungeon  = false,
	delaystop   = true,
}
ns.AutoLoggingDefaults = TRIGGER_DEFAULTS

local function GetTrigger(c, key)
	local v = c[key]
	if v == nil then return TRIGGER_DEFAULTS[key] end
	return v
end

local function Cfg()
	if type(EllesmereUIDB) ~= "table" then return {} end
	if type(EllesmereUIDB.autoLogging) ~= "table" then
		EllesmereUIDB.autoLogging = {}
	end
	return EllesmereUIDB.autoLogging
end
ns.GetAutoLoggingDB = Cfg

local function EnsureAdvancedLogging()
	if GetCVar("advancedCombatLogging") ~= "1" then
		if ns.SetCVarSafe then
			ns.SetCVarSafe("advancedCombatLogging", 1)
		else
			SetCVar("advancedCombatLogging", "1")
		end
	end
end

local function ZoneShouldBeLogged()
	local c = Cfg()
	if not c.enabled then return false end

	local _, zoneType, rawDiff, _, playerCap, _, _, rawMapID = GetInstanceInfo()
	local diff = tonumber(rawDiff)
	local mapID = tonumber(rawMapID) or 0
	if not diff then return false end

	if zoneType == "raid" then
		if LFR_DIFFICULTIES[diff] then
			return GetTrigger(c, "logLFR")
		end
		if mapID < MISTS_RAID_THRESHOLD then return false end
		local key = RAID_DIFF_KEYS[diff]
		if key then return GetTrigger(c, key) end
		return true  -- other raid difficulties
	end

	if zoneType == "party" and mapID >= MISTS_DUNGEON_THRESHOLD then
		if diff == 8 then return GetTrigger(c, "log5pp") end
		if diff == 2 then return GetTrigger(c, "logDungeon") end
		return false
	end

	if zoneType == "scenario" and GetTrigger(c, "logScenario")
		and (tonumber(playerCap) or 0) > 1 then
		return true
	end

	if zoneType == "arena" and GetTrigger(c, "logArena") then
		return true
	end

	return false
end

-------------------------------------------------------------------------------
--  Timers (5.4.8 has no C_Timer)
-------------------------------------------------------------------------------
local STOP_DELAY_SECONDS = 30

local timerFrame = CreateFrame("Frame")
local timers = {}
timerFrame:Hide()
timerFrame:SetScript("OnUpdate", function(self, elapsed)
	local now = GetTime()
	for key, t in pairs(timers) do
		if now >= t.at then
			timers[key] = nil
			t.fn()
		end
	end
	if not next(timers) then self:Hide() end
end)

local function After(key, delay, fn)
	timers[key] = { at = GetTime() + delay, fn = fn }
	timerFrame:Show()
end

local function Cancel(key)
	timers[key] = nil
end

local wasLogging = false

local function ApplyLoggingState()
	local shouldLog = ZoneShouldBeLogged()
	if shouldLog then
		Cancel("stop")
		EnsureAdvancedLogging()
		if not LoggingCombat() then LoggingCombat(true) end
	elseif wasLogging and LoggingCombat() then
		if GetTrigger(Cfg(), "delaystop") then
			if not timers.stop then
				After("stop", STOP_DELAY_SECONDS, function()
					if LoggingCombat() and not ZoneShouldBeLogged() then LoggingCombat(false) end
				end)
			end
		else
			LoggingCombat(false)
		end
	end
	wasLogging = shouldLog
end

local events = {
	ZONE_CHANGED_NEW_AREA = 2,
	PLAYER_ENTERING_WORLD = 2,
	PLAYER_DIFFICULTY_CHANGED = 1,
	WORLD_STATE_TIMER_START = 1,  -- Challenge Mode start (retail CHALLENGE_MODE_START)
}

local logFrame = CreateFrame("Frame")
local eventsRegistered = false
local function SyncEventRegistration()
	local want = Cfg().enabled and true or false
	if want == eventsRegistered then return end
	eventsRegistered = want
	for ev in pairs(events) do
		if want then logFrame:RegisterEvent(ev) else logFrame:UnregisterEvent(ev) end
	end
end

-- Retail global hook name kept (the options page calls it).
local function Check()
	SyncEventRegistration()
	ApplyLoggingState()
end
_G._EUI_AutoLogging_Check = Check
ns.AutoLoggingCheck = Check

ns.applyHooks = ns.applyHooks or {}
tinsert(ns.applyHooks, function()
	-- Turning the feature off inside an instance stops an active log (retail).
	if Cfg().enabled or eventsRegistered then Check() end
end)

logFrame:RegisterEvent("PLAYER_LOGIN")
logFrame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		self:UnregisterEvent("PLAYER_LOGIN")
		SyncEventRegistration()
		After("check", 2, ApplyLoggingState)
	elseif events[event] then
		After("check", events[event], ApplyLoggingState)
	end
end)
