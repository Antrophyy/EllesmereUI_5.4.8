-------------------------------------------------------------------------------
--  EllesmereUIQoL_RaidTimeline.lua (5.4.8 port of the retail Raid Ability
--  Timeline, Blizzard_EncounterTimeline "Timeline" view)
--
--  Retail fills the timeline from the server (C_EncounterTimeline). Mists has
--  no such data, so the boss mod timers are used instead:
--    * DBM: its timer bars (DBM.Bars) are read every frame, so starts,
--      restarts, updates and cancels all follow DBM without hooks.
--    * BigWigs: the BigWigs_StartBar / BigWigs_StopBar(s) messages.
--  Layout follows retail: from the start of the line a Long track (sorted
--  slots, the soonest next to the line, faded), a short Medium track and the
--  Short track with the line, its breaks every 2 s and the pip at the
--  highlight time. Events slide in from the side, pulse once they pass the
--  pip and pop when they finish. No combattimeline atlases in 5.4.8, so the
--  art is drawn with flat textures in the EUI style.
-------------------------------------------------------------------------------
local addonName = ...
local ns = EllesmereUI

local floor, ceil, max, min, abs, format = math.floor, math.ceil, math.max, math.min, math.abs, string.format
local GetTime = GetTime

local WHITE = "Interface\\Buttons\\WHITE8X8"
local GLOW = "Interface\\Buttons\\UI-ActionButton-Border"

-- Retail EncounterTimelineConstants
local INTRO_DURATION = 0.35
local INTRO_DISTANCE = 25
local OUTRO_DURATION = 0.35
local SORTED_MOVE_DURATION = 0.45
local FINISH_DURATION = 0.2
local FADE_DURATION = 0.2
local LONG_TRACK_ALPHA = 0.6
local PADDING = 20
local MEDIUM_GAP = 10

local function Defaults()
	return {
		enabled         = true,
		useDBM          = true,
		useBigWigs      = true,
		hideBossModBars = false,  -- DBM bars only (BigWigs bars are a BigWigs option)
		combatOnly      = false,  -- only during boss fights (pull timers etc. are left out)
		orientation     = "HORIZONTAL",  -- HORIZONTAL | VERTICAL
		reverse         = false,  -- horizontal: right to left; vertical: bottom to top
		iconSize        = 35,
		shortLength     = 250,    -- px of the Short track (the line)
		mediumLength    = 55,     -- px of the Medium track
		shortDuration   = 12,     -- seconds covered by the Short track
		mediumDuration  = 20,     -- events above this go to the Long track
		longSlots       = 3,      -- icons shown in the Long track
		highlightTime   = 5,
		showPip         = true,
		showPipText     = true,
		showCountdown   = true,
		countdownSize   = 14,
		showNames       = false,
		nameSize        = 11,
		showTrail       = true,
		showBorder      = true,
		lineColor       = { r = 1, g = 0.88, b = 0.62 },
		backgroundAlpha = 0,
		-- pos = { centerX, centerY } after the first move
	}
end
ns.RaidTimelineDefaults = Defaults

-- Lives in EllesmereUIQoLDB.raidTimeline; re-seeded after the QoL reset.
local function P()
	local q = ns.GetQoLDB and ns.GetQoLDB()
	if type(q) ~= "table" then return nil end
	local t = q.raidTimeline
	if type(t) ~= "table" then
		t = {}
		q.raidTimeline = t
	end
	if t._seeded ~= 1 then
		ns.CopyDefaults(Defaults(), t)
		t._seeded = 1
	end
	return t
end
ns.GetRaidTimelineDB = P

local function Snap(v)
	local PP = ns.PP
	if PP and PP.Snap then return PP.Snap(v) end
	return v
end

local function FontPath()
	return (ns.GetFontPath and ns.GetFontPath("qol")) or STANDARD_TEXT_FONT
end

local function SetFont(fs, size)
	fs:SetFont(FontPath(), size, "OUTLINE")
	if not fs:GetFont() then fs:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE") end
	fs:SetShadowOffset(0, 0)
end

-------------------------------------------------------------------------------
--  Layout (retail EncounterTimelineTrackLayoutMixin)
-------------------------------------------------------------------------------
local L = {}  -- offsets along the primary axis, from the start of the timeline

local function UpdateLayout()
	local p = P()
	local icon = p.iconSize or 35
	L.icon = icon
	L.slotExtent = icon + 3
	L.slots = max(0, floor(p.longSlots or 3))
	L.shortMax = max(2, p.shortDuration or 12)
	L.mediumMax = max(L.shortMax, p.mediumDuration or 20)
	L.longStart = PADDING
	L.longEnd = L.longStart + L.slots * L.slotExtent
	L.mediumStart = L.longEnd + (L.slots > 0 and MEDIUM_GAP or 0)
	L.mediumEnd = L.mediumStart + (L.mediumMax > L.shortMax and (p.mediumLength or 55) or 0)
	L.shortStart = L.mediumEnd
	L.shortEnd = L.shortStart + max(40, p.shortLength or 250)
	L.extent = L.shortEnd + PADDING
	L.cross = max(55, icon + 20)
	L.vertical = p.orientation == "VERTICAL"
	L.reverse = p.reverse and true or false
end

local function Lerp(a, b, t) return a + (b - a) * t end

local function LinearOffset(remaining)
	if remaining <= L.shortMax then
		local t = 1 - max(0, remaining) / L.shortMax
		return Lerp(L.shortStart, L.shortEnd, t)
	end
	local t = 1 - (remaining - L.shortMax) / (L.mediumMax - L.shortMax)
	return Lerp(L.mediumStart, L.mediumEnd, max(0, min(1, t)))
end

-- Long track: index 1 is the soonest event and sits next to the Medium track.
local function SortedOffset(sortIndex)
	return L.longStart + (L.slots - sortIndex + 0.5) * L.slotExtent
end

-- primary/cross offsets -> point on the timeline frame
local function Place(region, parent, primary, cross)
	region:ClearAllPoints()
	if L.vertical then
		if L.reverse then
			region:SetPoint("CENTER", parent, "BOTTOM", cross, primary)
		else
			region:SetPoint("CENTER", parent, "TOP", cross, -primary)
		end
	else
		if L.reverse then
			region:SetPoint("CENTER", parent, "RIGHT", -primary, cross)
		else
			region:SetPoint("CENTER", parent, "LEFT", primary, cross)
		end
	end
end

-------------------------------------------------------------------------------
--  Timeline frame and track art
-------------------------------------------------------------------------------
local frame, bg, pip, pipText, divider, mediumLine
local lineSegments = {}
local eventFrames = {}   -- pool of event frames
local events = {}        -- [key] = event table
local displayed = {}     -- events with a frame (sorted list)

local function LineTex()
	local t = frame:CreateTexture(nil, "ARTWORK")
	t:SetTexture(WHITE)
	return t
end

-- A line piece along the primary axis from offset a to b.
local function PlaceLine(tex, a, b, thickness)
	local len = b - a
	if len <= 0.5 then tex:Hide(); return end
	if L.vertical then
		tex:SetSize(thickness, len)
	else
		tex:SetSize(len, thickness)
	end
	Place(tex, frame, (a + b) / 2, 0)
	tex:Show()
end

local function ApplyTrackArt()
	local p = P()
	local c = p.lineColor or Defaults().lineColor
	frame:SetSize(L.vertical and L.cross or L.extent, L.vertical and L.extent or L.cross)

	bg:SetVertexColor(0, 0, 0, p.backgroundAlpha or 0)

	-- Short track line, broken every 2 s (retail line break masks at 1, 3, 5 ...).
	local breaks = {}
	for d = 1, L.shortMax - 0.5, 2 do
		breaks[#breaks + 1] = LinearOffset(d)
	end
	table.sort(breaks)
	local gap = 2
	local from = L.shortStart
	local n = 0
	for i = 1, #breaks + 1 do
		local to = breaks[i] and (breaks[i] - gap) or L.shortEnd
		n = n + 1
		local seg = lineSegments[n]
		if not seg then
			seg = LineTex()
			lineSegments[n] = seg
		end
		seg:SetVertexColor(c.r, c.g, c.b, 0.9)
		PlaceLine(seg, from, to, 2)
		from = breaks[i] and (breaks[i] + gap) or to
	end
	for i = n + 1, #lineSegments do lineSegments[i]:Hide() end

	-- End cap at 0 s.
	n = n + 1
	local cap = lineSegments[n]
	if not cap then
		cap = LineTex()
		lineSegments[n] = cap
	end
	cap:SetVertexColor(c.r, c.g, c.b, 1)
	if L.vertical then cap:SetSize(10, 2) else cap:SetSize(2, 10) end
	Place(cap, frame, L.shortEnd, 0)
	cap:Show()

	-- Medium track: the line fades in toward the Short track.
	if L.mediumEnd > L.mediumStart then
		PlaceLine(mediumLine, L.mediumStart, L.mediumEnd, 2)
		mediumLine:SetVertexColor(1, 1, 1, 1)
		local r, g, b = c.r, c.g, c.b
		local towardEnd = not L.reverse
		if L.vertical then
			-- VERTICAL gradients run bottom (min) to top (max).
			if towardEnd then
				mediumLine:SetGradientAlpha("VERTICAL", r, g, b, 0.6, r, g, b, 0)
			else
				mediumLine:SetGradientAlpha("VERTICAL", r, g, b, 0, r, g, b, 0.6)
			end
		else
			if towardEnd then
				mediumLine:SetGradientAlpha("HORIZONTAL", r, g, b, 0, r, g, b, 0.6)
			else
				mediumLine:SetGradientAlpha("HORIZONTAL", r, g, b, 0.6, r, g, b, 0)
			end
		end
	else
		mediumLine:Hide()
	end

	-- Divider between the Long track and the Medium track.
	if L.slots > 0 then
		divider:SetVertexColor(c.r, c.g, c.b, 0.6)
		if L.vertical then divider:SetSize(L.icon * 0.6, 1) else divider:SetSize(1, L.icon * 0.6) end
		Place(divider, frame, L.longEnd + MEDIUM_GAP / 2, 0)
		divider:Show()
	else
		divider:Hide()
	end

	-- Pip diamond and text at the highlight time.
	local ht = p.highlightTime or 5
	local pipOffset = LinearOffset(ht)
	pip:SetVertexColor(c.r, c.g, c.b, 1)
	Place(pip, frame, pipOffset, 0)
	pip:SetShown(p.showPip ~= false and ht > 0 and ht <= L.mediumMax)
	SetFont(pipText, 13)
	pipText:SetTextColor(c.r, c.g, c.b)
	pipText:SetText(format("%d", ht))
	pipText:ClearAllPoints()
	if L.vertical then
		pipText:SetPoint("LEFT", pip, "RIGHT", 10, 0)
	else
		pipText:SetPoint("TOP", pip, "BOTTOM", 0, -8)
	end
	pipText:SetShown(p.showPipText ~= false and pip:IsShown())
end

local function CreateTimelineFrame()
	if frame then return frame end
	frame = CreateFrame("Frame", "EllesmereUIRaidTimeline", UIParent)
	frame:SetFrameStrata("MEDIUM")
	frame:SetSize(400, 55)
	frame:EnableMouse(false)
	frame:Hide()

	bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(frame)
	bg:SetTexture(WHITE)
	bg:SetVertexColor(0, 0, 0, 0)

	mediumLine = LineTex()
	divider = LineTex()

	pip = frame:CreateTexture(nil, "OVERLAY")
	pip:SetTexture(WHITE)
	pip:SetSize(8, 8)
	if pip.SetRotation then pcall(pip.SetRotation, pip, math.pi / 4) end

	pipText = frame:CreateFontString(nil, "OVERLAY")
	SetFont(pipText, 13)
	return frame
end

-------------------------------------------------------------------------------
--  Event frames (retail EncounterTimelineTrackEvent)
-------------------------------------------------------------------------------
local function CreateEventFrame()
	local f = CreateFrame("Frame", nil, frame)
	f:SetSize(35, 35)
	f:EnableMouse(false)

	-- The icon sits in its own frame so pulse / finish scaling stays centered.
	local icon = CreateFrame("Frame", nil, f)
	icon:SetPoint("CENTER")
	icon:SetSize(35, 35)
	f.icon = icon

	local trail = f:CreateTexture(nil, "BACKGROUND")
	trail:SetTexture(WHITE)
	trail:SetBlendMode("ADD")
	f.trail = trail

	local tex = icon:CreateTexture(nil, "ARTWORK")
	tex:SetAllPoints(icon)
	tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.tex = tex

	local glow = icon:CreateTexture(nil, "OVERLAY", nil, 2)
	glow:SetTexture(GLOW)
	glow:SetBlendMode("ADD")
	glow:SetPoint("CENTER")
	glow:SetAlpha(0)
	f.glow = glow

	local textHolder = CreateFrame("Frame", nil, icon)
	textHolder:SetAllPoints(icon)
	textHolder:SetFrameLevel(icon:GetFrameLevel() + 3)
	f.textHolder = textHolder
	local cd = textHolder:CreateFontString(nil, "OVERLAY")
	cd:SetPoint("CENTER", icon, "CENTER", 0, 0)
	f.cd = cd

	local name = f:CreateFontString(nil, "OVERLAY")
	name:SetWordWrap(false)
	f.name = name

	f:Hide()
	return f
end

local function StyleEventFrame(f)
	local p = P()
	local s = L.icon
	f:SetSize(s, s)
	f.icon:SetSize(s, s)
	f.glow:SetSize(s * 1.9, s * 1.9)
	SetFont(f.cd, p.countdownSize or 14)
	SetFont(f.name, p.nameSize or 11)

	local PP = ns.PP
	if PP and PP.CreateBorder then
		if not f.border then
			f.border = PP.CreateBorder(f.icon, 0, 0, 0, 1, 1, "OVERLAY", 1)
			f.level = nil
		end
		if p.showBorder ~= false then f.border:Show() else f.border:Hide() end
	end

	-- Trail behind the icon (retail combattimeline-line-icontrail).
	local c = p.lineColor or Defaults().lineColor
	local trail = f.trail
	trail:ClearAllPoints()
	local len = 40
	if L.vertical then
		trail:SetSize(3, len)
		if L.reverse then
			trail:SetPoint("TOP", f, "CENTER", 0, 0)
			trail:SetGradientAlpha("VERTICAL", c.r, c.g, c.b, 0, c.r, c.g, c.b, 0.7)
		else
			trail:SetPoint("BOTTOM", f, "CENTER", 0, 0)
			trail:SetGradientAlpha("VERTICAL", c.r, c.g, c.b, 0.7, c.r, c.g, c.b, 0)
		end
	else
		trail:SetSize(len, 3)
		if L.reverse then
			trail:SetPoint("LEFT", f, "CENTER", 0, 0)
			trail:SetGradientAlpha("HORIZONTAL", c.r, c.g, c.b, 0.7, c.r, c.g, c.b, 0)
		else
			trail:SetPoint("RIGHT", f, "CENTER", 0, 0)
			trail:SetGradientAlpha("HORIZONTAL", c.r, c.g, c.b, 0, c.r, c.g, c.b, 0.7)
		end
	end
	trail:SetAlpha(0)

	-- Names: beside the icon when vertical (retail), above it when horizontal.
	local name = f.name
	name:ClearAllPoints()
	if L.vertical then
		name:SetWidth(200)
		if L.reverse then
			name:SetPoint("LEFT", f, "RIGHT", 10, 0)
			name:SetJustifyH("LEFT")
		else
			name:SetPoint("RIGHT", f, "LEFT", -10, 0)
			name:SetJustifyH("RIGHT")
		end
	else
		name:SetWidth(max(60, L.icon * 2.5))
		name:SetPoint("BOTTOM", f, "TOP", 0, 4)
		name:SetJustifyH("CENTER")
	end
	f.styled = true
end

-- Every part of an event gets its own frame level band, so overlapping
-- events (same time left) keep a fixed order: the sooner one on top. A
-- parent's new level does not lower its children in 5.4.8, so all are set.
local LEVEL_STEP = 4
local function SetEventLevel(f, level)
	if f.level == level then return end
	f.level = level
	f:SetFrameLevel(level)
	f.icon:SetFrameLevel(level + 1)
	if f.border then f.border:SetFrameLevel(level + 2) end
	f.textHolder:SetFrameLevel(level + 3)
end

local function AcquireFrame()
	local f = tremove(eventFrames)
	if not f then f = CreateEventFrame() end
	if not f.styled then StyleEventFrame(f) end
	return f
end

local function ReleaseFrame(f)
	f:Hide()
	f.icon:SetScale(1)
	f.glow:SetAlpha(0)
	eventFrames[#eventFrames + 1] = f
end

local function FormatCountdown(rem)
	if rem >= 60 then return format("%dm", ceil(rem / 60)) end
	return format("%d", ceil(rem))
end

-------------------------------------------------------------------------------
--  Event list
-------------------------------------------------------------------------------
-- An event: key, name, icon, expire, total, alive (still reported by the
-- source), state ("active" | "finish" | "cancel"), frame and animation data.
local function SetEvent(key, name, icon, remaining, total)
	local now = GetTime()
	local e = events[key]
	if not e then
		e = { key = key, born = now }
		events[key] = e
	end
	if e.state and e.state ~= "active" then
		-- Restarted while its outro played: start over.
		e.state = nil
		e.born = now
		if e.frame then ReleaseFrame(e.frame); e.frame = nil end
	end
	e.state = "active"
	e.name = name
	e.icon = icon
	e.expire = now + remaining
	e.total = total or remaining
	e.seen = now
	return e
end

local function EndEvent(e, finished)
	if e.state ~= "active" then return end
	e.state = finished and "finish" or "cancel"
	e.outroStart = GetTime()
	if not e.frame then events[e.key] = nil end
end

-------------------------------------------------------------------------------
--  Sources
-------------------------------------------------------------------------------
local hiddenBars = setmetatable({}, { __mode = "k" })
local dbmHooked = false

local function HideDBMBar(bar)
	local f = bar.frame
	if f then
		f:SetAlpha(0)
		f:EnableMouse(false)
		hiddenBars[bar] = true
	end
end

local function HookDBMBars(bar)
	if dbmHooked then return end
	local mt = getmetatable(bar)
	local proto = mt and mt.__index
	if type(proto) ~= "table" or type(proto.Update) ~= "function" then return end
	dbmHooked = true
	local function after(self)
		local p = P()
		if p and p.enabled and p.useDBM and p.hideBossModBars and not self.dummy and not self.dead then
			HideDBMBar(self)
		end
	end
	hooksecurefunc(proto, "Update", after)
	hooksecurefunc(proto, "ApplyStyle", after)
end

local function ShowHiddenDBMBars()
	for bar in pairs(hiddenBars) do
		if not bar.dead and bar.frame then
			bar.frame:SetAlpha(1)
			local opts = bar.owner and bar.owner.options
			bar.frame:EnableMouse(not (opts and opts.ClickThrough))
		end
		hiddenBars[bar] = nil
	end
end

local dbmSeen = {}
local function PollDBM(p, now)
	local bars = DBM and DBM.Bars and DBM.Bars.bars
	if type(bars) ~= "table" then return end
	wipe(dbmSeen)
	for bar in pairs(bars) do
		if type(bar) == "table" and not bar.dummy and not bar.dead and bar.frame and bar.timer and bar.timer > 0 then
			HookDBMBars(bar)
			local fname = bar.frame:GetName()
			local nameFS = fname and _G[fname .. "BarName"]
			local iconTex = fname and _G[fname .. "BarIcon1"]
			local key = "dbm:" .. tostring(bar.id)
			dbmSeen[key] = true
			local e = events[key]
			local name = nameFS and nameFS:GetText() or tostring(bar.id)
			local icon = iconTex and iconTex:GetTexture()
			-- Only touch the expire time when DBM changed it (keeps it smooth).
			local expire = now + bar.timer
			if not e or e.state ~= "active" or abs(e.expire - expire) > 0.15 or e.icon ~= icon or e.name ~= name then
				SetEvent(key, name, icon, bar.timer, bar.totalTime)
			else
				e.seen = now
			end
			if p.hideBossModBars then HideDBMBar(bar) end
		end
	end
	for key, e in pairs(events) do
		if e.state == "active" and key:sub(1, 4) == "dbm:" and not dbmSeen[key] then
			EndEvent(e, (e.expire - now) <= 0.5)
		end
	end
end

-- BigWigs: AceEvent messages (Mists BigWigs) or BigWigsLoader (newer).
local bwHandler, bwRegistered = {}, false

local function BWIcon(icon)
	if type(icon) == "number" then
		local _, _, tex = GetSpellInfo(icon)
		return tex
	end
	return icon
end

local function OnBWStart(_, module, key, text, time, icon)
	local p = P()
	if not (p and p.enabled and p.useBigWigs) or not text or not time then return end
	SetEvent("bw:" .. tostring(text), text, BWIcon(icon), time, time)
end

local function OnBWStop(_, module, text)
	local e = text and events["bw:" .. tostring(text)]
	if e then EndEvent(e, (e.expire - GetTime()) <= 0.5) end
end

local function OnBWStopAll()
	local now = GetTime()
	for key, e in pairs(events) do
		if key:sub(1, 3) == "bw:" then EndEvent(e, (e.expire - now) <= 0.5) end
	end
end

local function RegisterBigWigs()
	if bwRegistered then return end
	if BigWigsLoader and type(BigWigsLoader.RegisterMessage) == "function" then
		bwRegistered = true
		BigWigsLoader.RegisterMessage(bwHandler, "BigWigs_StartBar", OnBWStart)
		BigWigsLoader.RegisterMessage(bwHandler, "BigWigs_StopBar", OnBWStop)
		BigWigsLoader.RegisterMessage(bwHandler, "BigWigs_StopBars", OnBWStopAll)
		BigWigsLoader.RegisterMessage(bwHandler, "BigWigs_OnBossDisable", OnBWStopAll)
		return
	end
	local AceEvent = LibStub and LibStub("AceEvent-3.0", true)
	if AceEvent and (BigWigs or BigWigsLoader) then
		bwRegistered = true
		AceEvent:Embed(bwHandler)
		bwHandler:RegisterMessage("BigWigs_StartBar", OnBWStart)
		bwHandler:RegisterMessage("BigWigs_StopBar", OnBWStop)
		bwHandler:RegisterMessage("BigWigs_StopBars", OnBWStopAll)
		bwHandler:RegisterMessage("BigWigs_OnBossDisable", OnBWStopAll)
	end
end

-- BigWigs events that ran out without a stop message.
local function ExpireBigWigs(now)
	for key, e in pairs(events) do
		if e.state == "active" and key:sub(1, 3) == "bw:" and e.expire <= now then
			EndEvent(e, true)
		end
	end
end

-------------------------------------------------------------------------------
--  Preview (settings page / Unlock Mode)
-------------------------------------------------------------------------------
local previewOwner
local PREVIEW = {
	{ "Breath of Fire", "Interface\\Icons\\Spell_Fire_Fireball02", 9 },
	{ "Shadow Bolt Volley", "Interface\\Icons\\Spell_Shadow_ShadowBolt", 16 },
	{ "Charge", "Interface\\Icons\\Ability_Warrior_Charge", 24 },
	{ "Lightning Storm", "Interface\\Icons\\Spell_Nature_Lightning", 33 },
	{ "Bomb", "Interface\\Icons\\INV_Misc_Bomb_04", 42 },
	{ "Frost Nova", "Interface\\Icons\\Spell_Frost_FrostNova", 55 },
}

-- Only while the settings window itself is open: a page frame can report
-- visible after the window closed, which left the samples running.
local function PreviewActive()
	if ns._unlockActive then return true end
	local win = _G.EllesmereUISettings
	if not (win and win:IsShown() and win:IsVisible()) then return false end
	return previewOwner ~= nil and previewOwner:IsVisible() and true or false
end

local previewOn = false
local function UpdatePreview(now)
	local want = PreviewActive()
	if want then
		previewOn = true
		for i, d in ipairs(PREVIEW) do
			local key = "preview:" .. i
			local e = events[key]
			if not e or e.state ~= "active" then
				if not e or not e.frame then
					SetEvent(key, d[1], d[2], d[3], d[3])
				end
			elseif e.expire <= now then
				EndEvent(e, true)
			end
		end
	elseif previewOn then
		previewOn = false
		for key, e in pairs(events) do
			if key:sub(1, 8) == "preview:" then EndEvent(e, false) end
		end
	end
end

function ns.RaidTimelineSetPreviewOwner(f)
	previewOwner = f
end

-------------------------------------------------------------------------------
--  Update (every frame while anything is on the timeline)
-------------------------------------------------------------------------------
local sortList = {}
-- Timers less than 0.1 s apart count as the same time: then the older one
-- comes first, so their order cannot swap from frame to frame.
local function byExpire(a, b)
	if abs(a.expire - b.expire) >= 0.1 then return a.expire < b.expire end
	if a.born ~= b.born then return a.born < b.born end
	return a.key < b.key
end

local function InCombatWindow()
	if IsEncounterInProgress and IsEncounterInProgress() then return true end
	return UnitAffectingCombat("player") and true or false
end

local function UpdateEvents(p, now, elapsed)
	-- Track assignment of the active events.
	wipe(sortList)
	for _, e in pairs(events) do
		if e.state == "active" then sortList[#sortList + 1] = e end
	end
	table.sort(sortList, byExpire)

	local longIndex = 0
	local ht = p.highlightTime or 5
	local baseLevel = frame:GetFrameLevel() + 2
	local count = #sortList
	for rank, e in ipairs(sortList) do
		local rem = e.expire - now
		local track, target
		if rem <= L.mediumMax then
			track = rem <= L.shortMax and "short" or "medium"
			target = LinearOffset(rem)
		else
			longIndex = longIndex + 1
			if longIndex <= L.slots then
				track = "long"
				target = SortedOffset(longIndex)
			else
				track = "hidden"
			end
		end

		if track == "hidden" then
			if e.frame then
				-- Pushed out of the Long track by sooner events.
				ReleaseFrame(e.frame)
				e.frame = nil
			end
			e.track = nil
		else
			local f = e.frame
			local entering = false
			if not f then
				f = AcquireFrame()
				e.frame = f
				e.offset = target
				e.introStart = now
				e.highlighted = rem <= ht
				entering = true
				f.tex:SetTexture(e.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
				f.name:SetText(e.name or "")
				f.glow:SetAlpha(0)
				f.icon:SetScale(1)
				f:Show()
			end
			if e.track ~= track or (track == "long" and e.sortIndex ~= longIndex) then
				if not entering then e.moveUntil = now + SORTED_MOVE_DURATION end
				e.track = track
				e.sortIndex = longIndex
			end
			SetEventLevel(f, baseLevel + (count - rank) * LEVEL_STEP)
			if f.tex.lastIcon ~= e.icon then
				f.tex:SetTexture(e.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
				f.tex.lastIcon = e.icon
			end

			-- Primary axis: linear tracks follow time, moves between slots /
			-- tracks ease over SORTED_MOVE_DURATION.
			if e.moveUntil and now < e.moveUntil then
				local k = min(1, elapsed * 10)
				e.offset = e.offset + (target - e.offset) * k
			else
				e.moveUntil = nil
				e.offset = target
			end

			-- Cross axis intro slide + fade.
			local cross, alpha = 0, 1
			local it = (now - (e.introStart or 0)) / INTRO_DURATION
			if it < 1 then
				local eased = 1 - (1 - it) * (1 - it)
				cross = INTRO_DISTANCE * (1 - eased)
				alpha = min(1, (now - e.introStart) / FADE_DURATION)
			end
			if track == "long" then alpha = alpha * LONG_TRACK_ALPHA end
			Place(f, frame, e.offset, L.vertical and -cross or cross)
			f:SetAlpha(alpha)

			-- Countdown
			if p.showCountdown ~= false then
				f.cd:SetText(FormatCountdown(max(0, rem)))
			else
				f.cd:SetText("")
			end
			f.name:SetShown(p.showNames and true or false)

			-- Highlight when passing the pip, then pulse until it ends.
			if not e.highlighted and rem <= ht then
				e.highlighted = true
				e.glowStart = now
			end
			if e.glowStart then
				local g = (now - e.glowStart) / 0.4
				if g >= 1 then
					e.glowStart = nil
					f.glow:SetAlpha(0)
				else
					f.glow:SetAlpha(g < 0.5 and (g / 0.5) * 0.7 or (1 - g) / 0.5 * 0.7)
				end
			end
			if track == "short" and rem <= ht then
				local cyc = (now - (e.pulseBase or now)) % 1
				if not e.pulseBase then e.pulseBase = now end
				local s = 1
				if cyc < 0.2 then
					s = 1 + 0.1 * (cyc / 0.2)
				elseif cyc < 0.4 then
					s = 1.1 - 0.1 * ((cyc - 0.2) / 0.2)
				end
				f.icon:SetScale(s)
			else
				e.pulseBase = nil
				f.icon:SetScale(1)
			end

			-- Trail on the linear tracks (fades in as the event moves).
			if p.showTrail ~= false and track ~= "long" then
				f.trail:SetAlpha(min(1, (f.trail:GetAlpha() or 0) + elapsed * 3))
			else
				f.trail:SetAlpha(max(0, (f.trail:GetAlpha() or 0) - elapsed * 3))
			end
		end
	end

	-- Outros (finish: pop and fade; cancel: slide away and fade).
	for key, e in pairs(events) do
		if e.state == "finish" or e.state == "cancel" then
			local f = e.frame
			if not f then
				events[key] = nil
			else
				local t = now - e.outroStart
				if e.state == "finish" then
					local k = t / FINISH_DURATION
					if k >= 1 then
						ReleaseFrame(f)
						events[key] = nil
					else
						f.icon:SetScale(1 + 0.35 * k)
						f:SetAlpha(1 - k)
						f.glow:SetAlpha(0.7 * (1 - k))
						f.trail:SetAlpha(0)
					end
				else
					local k = t / OUTRO_DURATION
					if k >= 1 then
						ReleaseFrame(f)
						events[key] = nil
					else
						local cross = INTRO_DISTANCE * k
						Place(f, frame, e.offset or 0, L.vertical and -cross or cross)
						f:SetAlpha(max(0, 1 - t / FADE_DURATION))
					end
				end
			end
		end
	end
end

-- Drops everything from the timeline (after an error, so it cannot stick).
local function ClearAll()
	for key, e in pairs(events) do
		if e.frame then ReleaseFrame(e.frame); e.frame = nil end
		events[key] = nil
	end
	if frame then frame:Hide() end
end

local driver = CreateFrame("Frame")
local function DriverUpdate(_, elapsed)
	local p = P()
	if not p or not frame then return end
	local now = GetTime()

	if p.enabled then
		if p.useDBM then PollDBM(p, now) end
		if p.useBigWigs then ExpireBigWigs(now) end
	end
	UpdatePreview(now)

	local any = next(events) ~= nil
	local blocked = p.combatOnly and not PreviewActive() and not InCombatWindow()
	if not any or blocked then
		if frame:IsShown() then frame:Hide() end
		if not any then return end
		-- Keep the data current while blocked; frames go when it shows again.
		for _, e in pairs(events) do
			if e.frame then ReleaseFrame(e.frame); e.frame = nil end
			if e.state ~= "active" then events[e.key] = nil end
		end
		return
	end
	-- Timers whose source never reported an end (a missed cancel).
	for _, e in pairs(events) do
		if e.state == "active" and e.expire < now - 1 then EndEvent(e, false) end
	end
	if not frame:IsShown() then frame:Show() end
	UpdateEvents(p, now, elapsed or 0)
end

local reported = false
local function OnDriverUpdate(self, elapsed)
	local ok, err = pcall(DriverUpdate, self, elapsed)
	if not ok then
		ClearAll()
		if not reported then
			reported = true
			local handler = geterrorhandler and geterrorhandler()
			if handler then handler(err) end
		end
	end
end

-------------------------------------------------------------------------------
--  Position
-------------------------------------------------------------------------------
local function ApplyPosition()
	if not frame then return end
	if ns._unlockActive and frame:GetNumPoints() > 0 then return end
	local p = P()
	if not p then return end
	frame:ClearAllPoints()
	local pos = p.pos
	local cx = (pos and pos.centerX) or 0
	local cy = (pos and pos.centerY) or 260
	local PP = ns.PP
	if PP and PP.SnapCenterForDim then
		cx = PP.SnapCenterForDim(cx, frame:GetWidth())
		cy = PP.SnapCenterForDim(cy, frame:GetHeight())
	end
	frame:SetPoint("CENTER", UIParent, "CENTER", cx, cy)
	if not ns._unlockActive and ns.IsUnlockAnchored and ns.IsUnlockAnchored("EUI_RaidTimeline") and ns.ReapplyOwnAnchor then
		ns.ReapplyOwnAnchor("EUI_RaidTimeline")
	end
end

-------------------------------------------------------------------------------
--  Apply (every settings change)
-------------------------------------------------------------------------------
local function Apply()
	local p = P()
	if not p then return end
	CreateTimelineFrame()
	UpdateLayout()
	ApplyTrackArt()
	-- Restyle every event frame (layout or look may have changed).
	for _, f in ipairs(eventFrames) do f.styled = false end
	for _, e in pairs(events) do
		if e.frame then
			StyleEventFrame(e.frame)
			e.moveUntil = nil
		end
	end
	for _, f in ipairs(eventFrames) do StyleEventFrame(f) end
	ApplyPosition()

	if not (p.enabled and p.useDBM and p.hideBossModBars) then ShowHiddenDBMBars() end
	if not p.enabled then
		for key, e in pairs(events) do
			if key:sub(1, 8) ~= "preview:" then EndEvent(e, false) end
		end
	end
	if p.enabled and p.useBigWigs then RegisterBigWigs() end
	driver:SetScript("OnUpdate", OnDriverUpdate)
end
ns.RaidTimelineApply = Apply

ns.applyHooks = ns.applyHooks or {}
tinsert(ns.applyHooks, function()
	if frame then Apply() end
end)

-------------------------------------------------------------------------------
--  Unlock Mode
-------------------------------------------------------------------------------
local function RegisterUnlock()
	if not ns.RegisterUnlockElements or not ns.MakeUnlockElement then return end
	ns:RegisterUnlockElements({
		ns.MakeUnlockElement({
			key = "EUI_RaidTimeline",
			label = "Raid Timeline",
			group = "Quality of Life",
			order = 620,
			noAnchorTarget = true,
			noResize = true,
			isHidden = function()
				local p = P()
				return not p or not p.enabled
			end,
			getFrame = function()
				if not frame then CreateTimelineFrame(); Apply() end
				return frame
			end,
			getSize = function()
				if not L.extent then UpdateLayout() end
				if L.vertical then return L.cross, L.extent end
				return L.extent, L.cross
			end,
			savePos = function(_, point, relPoint, x, y)
				local p = P()
				if p then p.pos = { centerX = x, centerY = y } end
			end,
			loadPos = function()
				local p = P()
				if p and p.pos then
					return { point = "CENTER", relPoint = "CENTER", x = p.pos.centerX, y = p.pos.centerY }
				end
				return nil
			end,
			clearPos = function()
				local p = P()
				if p then p.pos = nil end
			end,
			applyPos = function() ApplyPosition() end,
		}),
	}, addonName)
end
RegisterUnlock()

-------------------------------------------------------------------------------
--  Init (the QoL saved table exists after its ADDON_LOADED)
-------------------------------------------------------------------------------
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(self, event, name)
	if event == "PLAYER_LOGIN" then
		CreateTimelineFrame()
		Apply()
	elseif frame and (name == "BigWigs" or name == "BigWigs_Core") then
		local p = P()
		if p and p.enabled and p.useBigWigs then RegisterBigWigs() end
	end
end)
