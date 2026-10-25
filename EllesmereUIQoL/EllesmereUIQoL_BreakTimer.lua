-------------------------------------------------------------------------------
--  EllesmereUIQoL_BreakTimer.lua (keeps the DBM break timer across /reload)
--
--  DBM 5.4.x loses its break bar on a reload and never gets it back:
--    * The bar only lives in memory (nothing is saved).
--    * After a reload DBM asks a raid member for timers ("RT") and they
--      whisper back "BTR\t<seconds left>", but DBM only handles BTR as a
--      group message, so the whispered answer is dropped.
--  Here the bar is saved on logout/reload and put back on login, and the
--  whispered BTR answer is picked up so the time follows the raid.
--  Saved per character in EllesmereUIQoLBreakTimer (not part of profiles).
-------------------------------------------------------------------------------
local ICON = "Interface\\Icons\\Spell_Holy_BorrowedTime"
local RESTORE_DELAY = 1   -- seconds after login (DBM loads its bar options first)
local BTR_WINDOW = 30     -- seconds after login a whispered BTR is accepted

local loginAt

local function BreakId()
	return DBM and DBM.Bars and DBM_CORE_TIMER_BREAK
end

local function InGroup(name)
	if not name then return false end
	name = Ambiguate and Ambiguate(name, "none") or name:match("^[^-]+")
	return UnitInRaid(name) or UnitInParty(name)
end

-- Start the break bar with `left` seconds of `total`, or move the current one.
local function ShowBreak(left, total)
	local id = BreakId()
	if not id or left < 2 then return end
	if IsEncounterInProgress and IsEncounterInProgress() then return end
	total = math.max(total or left, left)
	local bar = DBM.Bars:GetBar(id)
	if bar then
		if math.abs((bar.timer or 0) - left) < 2 then return end
		total = math.max(bar.totalTime or total, left)
	else
		DBM.Bars:CreateBar(total, id, ICON)
	end
	DBM.Bars:UpdateBar(id, total - left, total)
end

local function Save()
	EllesmereUIQoLBreakTimer = nil
	local id = BreakId()
	local bar = id and DBM.Bars:GetBar(id)
	if bar and bar.timer and bar.timer > 0 then
		EllesmereUIQoLBreakTimer = {
			endAt = time() + bar.timer,
			total = bar.totalTime or bar.timer,
		}
	end
end

local function Restore()
	local s = EllesmereUIQoLBreakTimer
	EllesmereUIQoLBreakTimer = nil
	if type(s) ~= "table" or not s.endAt then return end
	if not IsInGroup() then return end
	ShowBreak(s.endAt - time(), s.total)
end

local delay = CreateFrame("Frame")
delay:Hide()
delay:SetScript("OnUpdate", function(self, elapsed)
	self.t = (self.t or 0) + elapsed
	if self.t >= RESTORE_DELAY then
		self:Hide()
		Restore()
	end
end)

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_LOGOUT")
f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent", function(self, event, prefix, msg, channel, sender)
	if event == "PLAYER_LOGIN" then
		loginAt = GetTime()
		delay.t = 0
		delay:Show()
	elseif event == "PLAYER_LOGOUT" then
		Save()
	elseif prefix == "D4" and channel == "WHISPER" and msg and loginAt
		and GetTime() - loginAt < BTR_WINDOW and InGroup(sender) then
		local cmd, left = strsplit("\t", msg)
		left = tonumber(left)
		if cmd == "BTR" and left then ShowBreak(left) end
	end
end)
