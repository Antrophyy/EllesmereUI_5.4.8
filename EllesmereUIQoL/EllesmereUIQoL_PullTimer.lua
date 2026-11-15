-------------------------------------------------------------------------------
--  EllesmereUIQoL_PullTimer.lua (on-screen pull timer text)
--
--  When a group leader or assistant starts a pull timer (/pull, /dbm pull,
--  the Raid Tools pull button, BigWigs), a movable countdown text shows on
--  screen (e.g. "Pull in 7"). The time comes from the pull message itself,
--  so it also works with the DBM pull bar turned off:
--    * DBM:     CHAT_MSG_ADDON "D4", "PT\t<seconds>\t<mapID>" (0 = cancel).
--               Solo, DBM whispers the message to the player.
--    * BigWigs: CHAT_MSG_ADDON "BigWigs", a "Pull" message with the seconds.
--  The text stops when you enter combat (the pull happened).
--  Settings: Raid Tools tab, EllesmereUIQoLDB.pullTimer; position in Unlock
--  Mode (Pull Timer).
-------------------------------------------------------------------------------
local ns = EllesmereUI
local Q = ns.QoL

local floor, ceil, format, max, min = math.floor, math.ceil, string.format, math.max, math.min

local FONT_KEY = "qol"
local DEFAULT_POS = { point = "CENTER", relPoint = "CENTER", x = 0, y = 200 }
local DEFAULTS = {
	enabled       = true,
	text          = "Pull in",
	goText        = "Pull!",
	textSize      = 40,
	font          = "__global",
	outlineMode   = "__global",  -- __global | none (shadow) | outline | thick
	color         = { r = 1, g = 1, b = 1 },
	useClassColor = false,
	decimals      = 1,           -- 0, 1 or 2
	decimalsBelow = 5,           -- show decimals only below this many seconds
	warnBelow     = 3,           -- warning color below this many seconds (0 = off)
	warnColor     = { r = 1, g = 0.2, b = 0.2 },
	showGo        = true,        -- show goText for a few seconds at zero
}
ns.PullTimerDefaults = DEFAULTS

local function C()
	local db = ns.GetQoLDB and ns.GetQoLDB()
	if type(db) ~= "table" then return {} end
	if type(db.pullTimer) ~= "table" then db.pullTimer = {} end
	return db.pullTimer
end
local function Get(key)
	local v = C()[key]
	if v == nil then return DEFAULTS[key] end
	return v
end
ns.GetPullTimerDB = C
ns.PullTimerGet = Get

-------------------------------------------------------------------------------
--  Timer state
-------------------------------------------------------------------------------
local endAt          -- GetTime() when the pull timer reaches 0
local goUntil = 0    -- GetTime() until the "Pull!" text shows
local previewUntil

local function Stop()
	endAt = nil
	goUntil = 0
end

local function Start(secs)
	secs = tonumber(secs)
	if not secs or secs <= 0 then Stop(); return end
	if secs > 60 then return end   -- DBM ignores longer pull timers too
	if IsEncounterInProgress and IsEncounterInProgress() then return end
	endAt = GetTime() + secs
	goUntil = 0
end

-- Only a group leader or assistant can start a pull timer (same as DBM).
local function CanPull(name)
	if not IsInGroup() then return name == UnitName("player") end
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do
			local n, rank = GetRaidRosterInfo(i)
			if n and Ambiguate(n, "none") == name then return (rank or 0) > 0 end
		end
		return false
	end
	if name == UnitName("player") then return UnitIsGroupLeader("player") end
	for i = 1, GetNumSubgroupMembers() do
		local unit = "party" .. i
		local n, realm = UnitName(unit)
		if n and (n == name or (realm and realm ~= "" and n .. "-" .. realm == name)) then
			return UnitIsGroupLeader(unit)
		end
	end
	return false
end

local GROUP_CHANNELS = { PARTY = true, RAID = true, INSTANCE_CHAT = true }

local function OnAddonMessage(prefix, msg, channel, sender)
	if type(msg) ~= "string" or not sender then return end
	sender = Ambiguate(sender, "none")
	local fromGroup = GROUP_CHANNELS[channel]
	local fromSelf = channel == "WHISPER" and sender == UnitName("player")
	if not (fromGroup or fromSelf) then return end
	if prefix == "D4" then
		local cmd, secs, mapID = strsplit("\t", msg)
		if cmd ~= "PT" then return end
		if select(2, IsInInstance()) == "pvp" then return end
		mapID = tonumber(mapID)
		if mapID and mapID ~= (select(8, GetInstanceInfo())) then return end
		if not CanPull(sender) then return end
		Start(secs)
	elseif prefix == "BigWigs" then
		if msg:find("Break") then return end
		local secs = msg:match("Pull%D*(%d+)")
		if not secs or not CanPull(sender) then return end
		Start(secs)
	end
end

-------------------------------------------------------------------------------
--  Display
-------------------------------------------------------------------------------
local MAX_FONT = 32   -- the 5.4.8 client draws no font larger; bigger sizes scale the frame
local MAX_SIZE = 96

local display

local function TextSize()
	return max(10, min(Get("textSize") or 40, MAX_SIZE))
end

local function Size()
	local s = TextSize()
	return s * 7, s + 14
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

local function ApplyDisplay()
	if not display then return end
	local size, flags = TextSize(), Outline()
	local fontSize = min(size, MAX_FONT)
	local fs = display.text
	fs:SetFont(FontPath(), fontSize, flags)
	if not fs:GetFont() then fs:SetFont(STANDARD_TEXT_FONT, fontSize, flags) end
	if flags == "" then
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 1)
	else
		fs:SetShadowOffset(0, 0)
	end
	-- Sizes above 32: draw at 32 and scale the inner frame up.
	local scale = size / fontSize
	display.inner:SetScale(scale)
	local w, h = Size()
	display:SetSize(w, h)
	display.inner:SetSize(w / scale, h / scale)
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
	display.inner = CreateFrame("Frame", nil, display)
	display.inner:SetPoint("CENTER")
	display.text = display.inner:CreateFontString(nil, "OVERLAY")
	display.text:SetPoint("CENTER")
	display:Hide()
	ApplyDisplay()
	return display
end

local function TimeText(left)
	local dec = Get("decimals") or 0
	if dec > 0 and left < (Get("decimalsBelow") or 0) then
		-- Round up so the text never shows 0.0 before the end.
		local m = 10 ^ dec
		return format("%." .. dec .. "f", ceil(left * m) / m)
	end
	return tostring(ceil(left))
end

local function Color(left)
	local warn = Get("warnBelow") or 0
	if left and warn > 0 and left < warn then
		local c = Get("warnColor")
		return c.r or 1, c.g or 0.2, c.b or 0.2
	end
	if Get("useClassColor") and Q and Q.ClassColor then return Q.ClassColor() end
	local c = Get("color")
	return c.r or 1, c.g or 1, c.b or 1
end

local function Label(t)
	local label = Get("text") or ""
	if label == "" then return t end
	return label .. " " .. t
end

local function Show(msg, left)
	CreateDisplay()
	display.text:SetText(msg)
	display.text:SetTextColor(Color(left))
	display:Show()
end

local function Tick()
	local now = GetTime()
	if not Get("enabled") then
		if display and not ns._unlockActive then display:Hide() end
		return
	end
	if endAt then
		local left = endAt - now
		if left > 0 then
			Show(Label(TimeText(left)), left)
			return
		end
		endAt = nil
		if Get("showGo") and (Get("goText") or "") ~= "" then goUntil = now + 2 end
	end
	if now < goUntil then
		Show(Get("goText"), 0)
	elseif ns._unlockActive or (previewUntil and now < previewUntil) then
		-- Sample: 7 seconds, or 2.4 when decimals would show.
		local s = ((Get("decimals") or 0) > 0 and (Get("decimalsBelow") or 0) > 2.4) and 2.4 or 7
		Show(Label(TimeText(s)), s)
	elseif display then
		display:Hide()
	end
end

-- Settings window: show a sample for a few seconds.
function ns.PullTimerPreview()
	previewUntil = GetTime() + 3
	CreateDisplay()
	ApplyDisplay()
	Tick()
end

local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(self, dt)
	-- Fast while a countdown runs (decimals), slow when idle.
	self.t = (self.t or 0) + dt
	if self.t < ((endAt and 0.03) or 0.1) then return end
	self.t = 0
	Tick()
end)

local events = CreateFrame("Frame")
events:RegisterEvent("CHAT_MSG_ADDON")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, event, prefix, msg, channel, sender)
	if event == "CHAT_MSG_ADDON" then
		if prefix == "D4" or prefix == "BigWigs" then OnAddonMessage(prefix, msg, channel, sender) end
	elseif event == "PLAYER_REGEN_DISABLED" then
		-- Pulled (early or on time): the countdown no longer matters.
		if endAt then Stop() end
	else
		Stop()
	end
	Tick()
end)

if RegisterAddonMessagePrefix then
	RegisterAddonMessagePrefix("D4")
	RegisterAddonMessagePrefix("BigWigs")
end

if Q and Q.applies then
	tinsert(Q.applies, function()
		ApplyDisplay()
		Tick()
	end)
end

if Q and Q.RegisterUnlock then
	Q.RegisterUnlock({ {
		key = "EUI_PullTimer", label = "Pull Timer", group = "Quality of Life", order = 726,
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
