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
--
--  Break Timer text: while the DBM break bar runs, a movable "Break 4:32"
--  text shows on screen (in or out of combat). Settings: Raid Tools tab,
--  EllesmereUIQoLDB.breakTimer; position in Unlock Mode.
-------------------------------------------------------------------------------
local addonName = ...
local ns = EllesmereUI
local Q = ns.QoL

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
	local left = s.endAt - time()
	if left < 2 then return end
	ShowBreak(left, s.total)
	if Q and Q.Print then
		Q.Print(("Break timer restored (%d:%02d left)."):format(math.floor(left / 60), math.floor(left % 60)))
	end
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

-------------------------------------------------------------------------------
--  Break Timer text
-------------------------------------------------------------------------------
local floor, format = math.floor, string.format

local FONT_KEY = "qol"
local DEFAULT_POS = { point = "CENTER", relPoint = "CENTER", x = 0, y = 150 }
local DEFAULTS = {
	enabled        = true,
	text           = "Break",
	textSize       = 28,
	font           = "__global",
	outlineMode    = "__global",  -- __global | none (shadow) | outline | thick
	color          = { r = 1, g = 0.82, b = 0 },
	useClassColor  = false,
	warnLastMinute = true,        -- red for the last 60 seconds
	showOver       = true,        -- "Break is over" for a few seconds at the end
}
ns.BreakTimerDefaults = DEFAULTS

local function C()
	local db = ns.GetQoLDB and ns.GetQoLDB()
	if type(db) ~= "table" then return {} end
	if type(db.breakTimer) ~= "table" then db.breakTimer = {} end
	return db.breakTimer
end
local function Get(key)
	local v = C()[key]
	if v == nil then return DEFAULTS[key] end
	return v
end
ns.GetBreakTimerDB = C
ns.BreakTimerGet = Get

local display, previewUntil, lastLeft
local overUntil = 0

local function Clock(left)
	left = math.max(0, floor(left + 0.5))
	return format("%d:%02d", floor(left / 60), left % 60)
end

local function Color(left)
	if left and left <= 60 and Get("warnLastMinute") then return 1, 0.2, 0.2 end
	if Get("useClassColor") and Q and Q.ClassColor then return Q.ClassColor() end
	local c = Get("color")
	return c.r or 1, c.g or 1, c.b or 1
end

local function FontPath()
	local key = Get("font")
	if key ~= "__global" and ns.ResolveFontName then
		local path = ns.ResolveFontName(key)
		if path then return path end
	end
	return (ns.GetFontPath and ns.GetFontPath(FONT_KEY)) or STANDARD_TEXT_FONT
end

local function Outline()
	local mode = Get("outlineMode")
	if mode == "outline" then return "OUTLINE" end
	if mode == "thick" then return "THICKOUTLINE" end
	if mode == "none" then return "" end
	return (ns.GetFontOutlineFlag and ns.GetFontOutlineFlag(FONT_KEY)) or "OUTLINE"
end

local function Size()
	local s = Get("textSize")
	return s * 8, s + 14
end

local function ApplyDisplay()
	if not display then return end
	local size, flags = Get("textSize"), Outline()
	local fs = display.text
	fs:SetFont(FontPath(), size, flags)
	if not fs:GetFont() then fs:SetFont(STANDARD_TEXT_FONT, size, flags) end
	if flags == "" then
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 1)
	else
		fs:SetShadowOffset(0, 0)
	end
	display:SetSize(Size())
	if not ns._unlockActive then
		local pos = C().pos
		if type(pos) ~= "table" or not pos.point then pos = DEFAULT_POS end
		display:ClearAllPoints()
		display:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
	end
end

local function CreateDisplay()
	if display then return display end
	display = CreateFrame("Frame", nil, UIParent)
	display:SetFrameStrata("HIGH")
	display:SetFrameLevel(60)
	display:EnableMouse(false)
	display.text = display:CreateFontString(nil, "OVERLAY")
	display.text:SetPoint("CENTER")
	display:Hide()
	ApplyDisplay()
	return display
end

local function Show(msg, left)
	CreateDisplay()
	display.text:SetText(msg)
	display.text:SetTextColor(Color(left))
	display:Show()
end

local function Sample()
	return format("%s %s", Get("text"), Clock(300))
end

local function Tick()
	local now = GetTime()
	local id = BreakId()
	local bar = id and DBM.Bars:GetBar(id)
	local left = bar and bar.timer
	if not Get("enabled") then
		if display and not ns._unlockActive then display:Hide() end
		lastLeft = nil
		return
	end
	if left and left > 0 then
		Show(format("%s %s", Get("text"), Clock(left)), left)
		lastLeft = left
		return
	end
	-- Ran out (not cancelled early): say so for a few seconds.
	if lastLeft and lastLeft < 1.5 and Get("showOver") then overUntil = now + 4 end
	lastLeft = nil
	if now < overUntil then
		Show(format("%s is over", Get("text")))
	elseif ns._unlockActive then
		Show(Sample())
	elseif previewUntil and now < previewUntil then
		Show(Sample())
	elseif display then
		display:Hide()
	end
end

-- Settings window: show a sample for a few seconds.
function ns.BreakTimerPreview()
	previewUntil = GetTime() + 3
	CreateDisplay()
	ApplyDisplay()
	Tick()
end

local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(self, dt)
	self.t = (self.t or 0) + dt
	if self.t < 0.1 then return end
	self.t = 0
	Tick()
end)

if Q and Q.applies then
	tinsert(Q.applies, function()
		ApplyDisplay()
		Tick()
	end)
end

if Q and Q.RegisterUnlock then
	Q.RegisterUnlock({ {
		key = "EUI_BreakTimer", label = "Break Timer", group = "Quality of Life", order = 725,
		noResize = true, noAnchorTarget = true,
		isHidden = function() return not Get("enabled") end,
		getFrame = function() return CreateDisplay() end,
		getSize = Size,
		savePos = function(_, point, relPoint, x, y)
			if not point then return end
			C().pos = { point = point, relPoint = relPoint, x = x, y = y }
			if not ns._unlockActive then ApplyDisplay() end
		end,
		loadPos = function()
			local pos = C().pos
			if type(pos) == "table" and pos.point then return pos end
			return DEFAULT_POS
		end,
		clearPos = function()
			C().pos = nil
			ApplyDisplay()
		end,
		applyPos = ApplyDisplay,
	} })
end
