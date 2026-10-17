-------------------------------------------------------------------------------
--  EUI_ActionBars_XPBar.lua  (5.4.8 port of the retail XP bar extras)
--
--  On top of the XP bar in EUI_ActionBars_DataBars.lua, with the retail keys
--  on the XP bar's settings:
--    divider          nil | "4" | "5" | "10" | "20": segment lines (20 = the
--                     5% lines), dividerColor, dividerAlpha
--    dividerText      percent labels at the dividers (dividerTextSize,
--                     dividerTextColor, dividerTextOffX / OffY)
--    textSlotLeft / textSlotRight / textSlotCenter: what a text shows, item
--                     ids joined by "," (top group, " - " between them) or
--                     one solo item; nil / "none" = nothing. Center replaces
--                     the classic text when set. textSlot<Stem>Size.
--    showTextBg       a dark band behind the bar texts (textBgColor)
--    fillGradient     nil | "HORIZONTAL" | "VERTICAL" (fillGradStart / End)
--    questOverlay     the XP of quests in the log, drawn after the fill
--                     (questOverlayCompleted: completed only; questOverlayZone:
--                     the current zone's quests only; questOverlayColor /
--                     questOverlayDoneColor)
--  Items: pct, cur, curMax, curMaxRem, restVal, restPct, questVal, questPct,
--  level; solo: xpPerHour, levelingIn, timeSession. Not ported: frame art
--  styles, profession flipbook fill, Smart Ticks, Time This Level.
-------------------------------------------------------------------------------
local addonName, P = ...
local EAB = P.EAB

local floor, max, min = math.floor, math.max, math.min
local format = string.format
local GetTime = GetTime

local XP = {}
P.ns.EAB_XP = XP
P.XP = XP

XP.ITEMS_TOP = {
	{ "pct", "Current %" }, { "cur", "Current XP" }, { "curMax", "Current / Max" },
	{ "curMaxRem", "Current / Max (Remaining)" }, { "restVal", "Rested XP" }, { "restPct", "Rested %" },
	{ "questVal", "Quest XP" }, { "questPct", "Quest XP %" }, { "level", "Level" },
}
XP.ITEMS_SOLO = { { "xpPerHour", "XP per Hour" }, { "levelingIn", "Leveling In" }, { "timeSession", "Time This Session" } }
local SOLO = { xpPerHour = true, levelingIn = true, timeSession = true }
XP.SLOTS = { "Left", "Right", "Center" }

local GRAD_START = { r = 0.60, g = 0.40, b = 0.85, a = 1 }
local GRAD_END = { r = 0.00, g = 0.44, b = 0.87, a = 1 }

local function Num(n)
	n = floor(n or 0)
	if n >= 1e6 then return format("%.1fM", n / 1e6) end
	if n >= 1e4 then return format("%.1fK", n / 1e3) end
	return tostring(n)
end
local function Pct(v)
	if v == floor(v) then return format("%d%%", v) end
	return format("%.1f%%", v)
end
local function Clock(sec)
	sec = floor(sec or 0)
	local h, m = floor(sec / 3600), floor(sec % 3600 / 60)
	if h > 0 then return format("%dh %dm", h, m) end
	return format("%dm", m)
end

-------------------------------------------------------------------------------
--  Trackers: session XP rate, quest XP in the log
-------------------------------------------------------------------------------
local loginAt = GetTime()
local gained, lastXP, lastMax = 0, nil, nil
local function TrackXP()
	local cur, mx = UnitXP("player"), UnitXPMax("player")
	if lastXP then
		if cur >= lastXP then
			gained = gained + (cur - lastXP)
		elseif lastMax then
			gained = gained + (lastMax - lastXP) + cur   -- a level-up
		end
	end
	lastXP, lastMax = cur, mx
end
local function Rate()
	local t = GetTime() - loginAt
	if t < 60 then return 0 end
	return gained / t * 3600
end

-- XP of the log's quests: total, completed only; current zone's when asked.
local questDirty, questAll, questDone, questZone = true, 0, 0, nil
local function ScanQuests(zoneOnly)
	if not questDirty and questZone == (zoneOnly and (GetRealZoneText and GetRealZoneText() or "") or false) then return end
	questDirty = false
	questZone = zoneOnly and (GetRealZoneText and GetRealZoneText() or "") or false
	questAll, questDone = 0, 0
	if not (GetNumQuestLogEntries and GetQuestLogRewardXP and SelectQuestLogEntry) then return end
	local selected = GetQuestLogSelection and GetQuestLogSelection() or 0
	local header
	local n = GetNumQuestLogEntries() or 0
	for i = 1, n do
		local title, _, _, isHeader, _, isComplete = GetQuestLogTitle(i)
		if isHeader then
			header = title
		elseif title and (not zoneOnly or header == questZone) then
			SelectQuestLogEntry(i)
			local xp = GetQuestLogRewardXP() or 0
			questAll = questAll + xp
			if isComplete == 1 or isComplete == true then questDone = questDone + xp end
		end
	end
	SelectQuestLogEntry(selected or 0)
end

-------------------------------------------------------------------------------
--  Texts
-------------------------------------------------------------------------------
local function QuestXP(s)
	ScanQuests(s.questOverlayZone)
	return s.questOverlayCompleted and questDone or questAll
end

local function Item(id, s, cur, mx, rested, level)
	if id == "pct" then return Pct(floor(cur / mx * 1000 + 0.5) / 10)
	elseif id == "cur" then return Num(cur)
	elseif id == "curMax" then return Num(cur) .. " / " .. Num(mx)
	elseif id == "curMaxRem" then return format("%s / %s (%s)", Num(cur), Num(mx), Num(mx - cur))
	elseif id == "restVal" then return rested > 0 and ("Rested " .. Num(rested)) or nil
	elseif id == "restPct" then return rested > 0 and ("Rested " .. Pct(floor(rested / mx * 1000 + 0.5) / 10)) or nil
	elseif id == "questVal" then local q = QuestXP(s); return q > 0 and ("Quests " .. Num(q)) or nil
	elseif id == "questPct" then local q = QuestXP(s); return q > 0 and ("Quests " .. Pct(floor(q / mx * 1000 + 0.5) / 10)) or nil
	elseif id == "level" then return format("%s %d", LEVEL or "Level", level)
	elseif id == "xpPerHour" then local r = Rate(); return r > 0 and (Num(r) .. " XP/h") or "-- XP/h"
	elseif id == "levelingIn" then
		local r = Rate()
		return r > 0 and ("Level in " .. Clock((mx - cur) / r * 3600)) or "Level in --"
	elseif id == "timeSession" then return "Session " .. Clock(GetTime() - loginAt)
	end
end

function XP.SlotText(v, s, cur, mx, rested, level)
	if type(v) ~= "string" or v == "none" or v == "" then return nil end
	if SOLO[v] then return Item(v, s, cur, mx, rested, level) end
	local parts = {}
	for id in v:gmatch("[^,]+") do
		local t = Item(id, s, cur, mx, rested, level)
		if t then parts[#parts + 1] = t end
	end
	return #parts > 0 and table.concat(parts, " - ") or nil
end

function XP.UsesClock(s)
	for _, stem in ipairs(XP.SLOTS) do
		local v = s["textSlot" .. stem]
		if v == "xpPerHour" or v == "levelingIn" or v == "timeSession" then return true end
	end
	return false
end

-------------------------------------------------------------------------------
--  Layout (from LayoutDataBar) and update (from UpdateXPBar)
-------------------------------------------------------------------------------
function XP.Layout(frame, s)
	local px = P.PixelFor(frame)
	local vertical = s.orientation == "VERTICAL"
	local w, h = s.width or 400, s.height or 18
	-- Dividers
	frame._divs = frame._divs or {}
	frame._divTexts = frame._divTexts or {}
	local n = tonumber(s.divider) or 0
	local dc = s.dividerColor or { r = 0, g = 0, b = 0 }
	if not frame._divHost then
		frame._divHost = CreateFrame("Frame", nil, frame)
		frame._divHost:SetAllPoints(frame)
	end
	frame._divHost:SetFrameLevel(frame._bar:GetFrameLevel() + 1)
	local used = 0
	for i = 1, max(0, n - 1) do
		local t = frame._divs[i]
		if not t then
			t = frame._divHost:CreateTexture(nil, "OVERLAY")
			frame._divs[i] = t
		end
		t:SetTexture(dc.r or 0, dc.g or 0, dc.b or 0, s.dividerAlpha or 0.8)
		t:ClearAllPoints()
		local f = i / n
		if vertical then
			t:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", px, h * f)
			t:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -px, h * f)
			t:SetHeight(px)
		else
			t:SetPoint("TOPLEFT", frame, "TOPLEFT", w * f, -px)
			t:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", w * f, px)
			t:SetWidth(px)
		end
		t:Show()
		-- Divider text: the percent each line stands for.
		local fs = frame._divTexts[i]
		if s.dividerText then
			if not fs then
				fs = frame._divHost:CreateFontString(nil, "OVERLAY")
				frame._divTexts[i] = fs
			end
			P.SetModuleFont(fs, s.dividerTextSize or 8)
			local tc = s.dividerTextColor or { r = 1, g = 1, b = 1 }
			fs:SetTextColor(tc.r or 1, tc.g or 1, tc.b or 1, 1)
			fs:SetText(floor(f * 100 + 0.5) .. "%")
			fs:ClearAllPoints()
			if vertical then
				fs:SetPoint("LEFT", t, "RIGHT", 2 + (s.dividerTextOffX or 0), s.dividerTextOffY or 0)
			else
				fs:SetPoint("TOP", t, "BOTTOM", s.dividerTextOffX or 0, -2 + (s.dividerTextOffY or 0))
			end
			fs:Show()
		elseif fs then
			fs:Hide()
		end
		used = i
	end
	for i = used + 1, #frame._divs do
		frame._divs[i]:Hide()
		if frame._divTexts[i] then frame._divTexts[i]:Hide() end
	end
	-- Text background band
	if s.showTextBg then
		local bg = frame._textBg
		if not bg then
			bg = frame._textHost:CreateTexture(nil, "BACKGROUND")
			frame._textBg = bg
		end
		local c = s.textBgColor or { r = 0, g = 0, b = 0, a = 0.5 }
		bg:SetTexture(c.r or 0, c.g or 0, c.b or 0, c.a or 0.5)
		bg:ClearAllPoints()
		bg:SetPoint("TOPLEFT", frame, "TOPLEFT", px, -px)
		bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -px, px)
		bg:Show()
	elseif frame._textBg then
		frame._textBg:Hide()
	end
	-- Left / Right text slots
	frame._slots = frame._slots or {}
	for _, stem in ipairs({ "Left", "Right" }) do
		local fs = frame._slots[stem]
		if not fs then
			fs = frame._textHost:CreateFontString(nil, "OVERLAY")
			fs:SetTextColor(1, 1, 1, 1)
			frame._slots[stem] = fs
		end
		P.SetModuleFont(fs, s["textSlot" .. stem .. "Size"] or s.textSize or 9)
		fs:ClearAllPoints()
		local pt = stem == "Left" and "LEFT" or "RIGHT"
		fs:SetPoint(pt, frame._textHost, pt, (stem == "Left" and 4 or -4) + (s["textSlot" .. stem .. "XOffset"] or 0),
			s["textSlot" .. stem .. "YOffset"] or 0)
		fs:SetJustifyH(pt)
	end
	if s.textSlotCenterSize then P.SetModuleFont(frame._text, s.textSlotCenterSize) end
	-- Quest XP overlay: a bar under the fill reaching cur + quest XP.
	if s.questOverlay then
		local q = frame._questBar
		if not q then
			q = CreateFrame("StatusBar", nil, frame)
			q:SetStatusBarTexture(P.WHITE)
			frame._questBar = q
		end
		q:ClearAllPoints()
		q:SetPoint("TOPLEFT", frame, "TOPLEFT", px, -px)
		q:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -px, px)
		q:SetStatusBarTexture(EAB.ResolveDataBarTexture(s.barTexture))
		q:SetOrientation(vertical and "VERTICAL" or "HORIZONTAL")
		q:SetFrameLevel(max(0, frame._bar:GetFrameLevel() - 1))
		q:Show()
	elseif frame._questBar then
		frame._questBar:Hide()
	end
	frame._xpGradKey = nil
	-- The minute clock for the time-based texts.
	if XP.UsesClock(s) then
		if not frame._xpClock then
			local acc = 0
			frame._xpClock = CreateFrame("Frame", nil, frame)
			frame._xpClock:SetScript("OnUpdate", function(_, dt)
				acc = acc + dt
				if acc < 30 then return end
				acc = 0
				if P.UpdateDataBars then P.UpdateDataBars() end
			end)
		end
		frame._xpClock:Show()
	elseif frame._xpClock then
		frame._xpClock:Hide()
	end
end

-- Returns the text for the center (nil = keep the classic text).
function XP.Update(frame, s, cur, mx, rested, level)
	-- Fill gradient
	local dir = s.fillGradient
	local tex = frame._bar:GetStatusBarTexture()
	if (dir == "HORIZONTAL" or dir == "VERTICAL") and tex then
		local a, b = s.fillGradStart or GRAD_START, s.fillGradEnd or GRAD_END
		frame._bar:SetStatusBarColor(1, 1, 1, 1)
		tex:SetGradientAlpha(dir, a.r or 1, a.g or 1, a.b or 1, a.a or 1, b.r or 1, b.g or 1, b.b or 1, b.a or 1)
	end
	-- Quest overlay
	local q = frame._questBar
	if q and s.questOverlay then
		local qxp = QuestXP(s)
		local c = (s.questOverlayCompleted and (s.questOverlayDoneColor or { r = 1, g = 0.82, b = 0, a = 0.6 }))
			or (s.questOverlayColor or { r = 1, g = 0.82, b = 0, a = 0.45 })
		q:SetMinMaxValues(0, mx)
		q:SetValue(min(mx, cur + qxp))
		q:SetStatusBarColor(c.r or 1, c.g or 0.82, c.b or 0, c.a or 0.45)
		q:SetShown(qxp > 0)
	end
	-- Left / Right slots
	if frame._slots then
		for _, stem in ipairs({ "Left", "Right" }) do
			local fs = frame._slots[stem]
			local t = XP.SlotText(s["textSlot" .. stem], s, cur, mx, rested, level)
			fs:SetText(t or "")
			fs:SetShown(t ~= nil and s.hideText ~= true)
		end
	end
	return XP.SlotText(s.textSlotCenter, s, cur, mx, rested, level)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_XP_UPDATE")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("QUEST_LOG_UPDATE")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:SetScript("OnEvent", function(_, event)
	if event == "QUEST_LOG_UPDATE" or event == "ZONE_CHANGED_NEW_AREA" then
		questDirty = true
	else
		TrackXP()
	end
end)
