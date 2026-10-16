-------------------------------------------------------------------------------
--  EllesmereUIQoL_BattleRes.lua (5.4.8 port of the retail BattleRes icon)
--
--  Retail polls the shared brez charge pool (GetSpellCharges(20484)). Mists
--  has no pool: a raid boss allows a fixed number of combat resurrections per
--  attempt (10-player 1, 25-player and LFR 3) and every caster has a 10 min
--  cooldown. So the icon is driven by the combat log instead:
--    * Count = brez left this attempt (limit - accepted brez). In a
--      Challenge Mode (no limit) it is the number of brez casters ready now.
--    * Timer = time until the next brez caster in the group is ready, shown
--      only while none is ready and brez are still left.
--  A brez counts when the target is alive again (accepting it), like the
--  server counts it. The combat log misses players in another phase or out
--  of range, so the count comes from group members going dead -> alive
--  during the boss (raid death state reaches us in every phase); the log
--  and EUI addon messages ("EUIBR") only tell who cast it and what was free
--  (Reincarnation). Cooldowns of 5 min+ reset after a raid boss (5.4.8).
--  Same keys, look and Unlock Mode element as retail. No masks in 5.4.8, so
--  the shapes are None and Cropped only.
-------------------------------------------------------------------------------
local addonName = ...
local ns = EllesmereUI

local floor, max, min, format = math.floor, math.max, math.min, string.format
local band = bit.band
local GetTime = GetTime

local BREZ_ICON_SPELL = 20484  -- Rebirth
local BREZ_COOLDOWN = 600

-- Combat resurrection spells (ExRT 5.4.8 cooldown list): every one is a
-- 10 min cooldown that uses one brez of the raid when it is accepted.
local BREZ_SPELLS = {
	[20484] = true,   -- Rebirth (Druid)
	[61999] = true,   -- Raise Ally (Death Knight)
	[20707] = true,   -- Soulstone (Warlock; can be cast on a dead player)
	[126393] = true,  -- Eternal Guardian (Hunter quilen pet)
}
-- Using a Soulstone on yourself (the release prompt button).
local SOULSTONE_SELF_RES = 95750
-- Shaman Reincarnation (the self res itself): does not use a raid brez.
local REINCARNATION = 21169
local COMM_PREFIX = "EUIBR"
-- Eternal Guardian is a pet spell: its cooldown does not reset after a boss.
local NO_ENCOUNTER_RESET = { [126393] = true }
-- Classes that always carry a brez (hunters only after a quilen was seen).
local BREZ_CLASSES = { DRUID = true, DEATHKNIGHT = true, WARLOCK = true }

-- Difficulties whose long cooldowns reset when the boss ends (ExRT list).
local RESET_DIFFICULTY = { [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [14] = true }
local CHALLENGE_DIFFICULTY = 8

local GROUP_AFFILIATION = 0x00000007  -- COMBATLOG_OBJECT_AFFILIATION_MINE / PARTY / RAID

local function Defaults()
	return {
		enabled        = true,
		visibility     = "MPLUS_AND_RAID",  -- MPLUS_AND_RAID | MPLUS | RAID | NEVER (MPLUS = Challenge Mode)
		displayMode    = "icon",  -- icon | text ("2 | 4:14" line)
		iconSize       = 40,
		iconZoom       = 11,   -- percent
		shape          = "none",  -- none | cropped
		borderSize     = "thin",  -- none / thin / normal / heavy / strong
		borderColor    = { r = 0, g = 0, b = 0, a = 1 },
		borderUseClass = false,
		durationSize   = 12,
		durationOffsetX = 0,
		durationOffsetY = 0,
		countSize      = 11,
		countOffsetX   = 0,
		countOffsetY   = 0,
		desaturateNoCharges = true,
		textSize       = 14,
		textCountColor = { r = 1, g = 1, b = 1 },
		textTimerColor = { r = 1, g = 1, b = 1 },
		font           = "__global",
		outlineMode    = "__global",  -- __global | none (shadow) | outline | thick
		-- pos = { centerX, centerY } after the first move
	}
end
ns.BattleResDefaults = Defaults

-- Lives in EllesmereUIQoLDB.battleRes (retail: EllesmereUIQoLDB.profile.battleRes).
-- Re-seeded after the QoL reset wipes the table.
local function P()
	local q = ns.GetQoLDB and ns.GetQoLDB()
	if type(q) ~= "table" then return nil end
	local t = q.battleRes
	if type(t) ~= "table" then
		t = {}
		q.battleRes = t
	end
	if t._seeded ~= 1 then
		ns.CopyDefaults(Defaults(), t)
		t._seeded = 1
	end
	return t
end
ns.GetBattleResDB = P

local frame, iconTex, durationFS, countFS, cooldownFrame, textFS, border

-- Settings page preview: forces the icon on screen while the page is shown.
local previewOwner
local function PreviewActive()
	return previewOwner ~= nil and previewOwner:IsVisible() and true or false
end

local function IsTextMode()
	local p = P()
	return (p and p.displayMode) == "text"
end

-------------------------------------------------------------------------------
--  Fonts: the text display follows Font / Font Outline; the icon texts keep
--  the module font with a crisp outline (retail house style).
-------------------------------------------------------------------------------
local FONT_KEY = "qol"

local function GetBrezFont()
	local p = P()
	local key = (p and p.font) or "__global"
	if key ~= "__global" and ns.ResolveFontName then
		local path = ns.ResolveFontName(key)
		if path then return path end
	end
	return (ns.GetFontPath and ns.GetFontPath(FONT_KEY)) or STANDARD_TEXT_FONT
end

local function GetBrezOutline()
	local p = P()
	local mode = (p and p.outlineMode) or "__global"
	if mode == "outline" then return "OUTLINE" end
	if mode == "thick" then return "THICKOUTLINE" end
	if mode == "none" then return "" end
	return (ns.GetFontOutlineFlag and ns.GetFontOutlineFlag(FONT_KEY)) or "OUTLINE"
end

local function SetFontSafe(fs, path, size, flags)
	fs:SetFont(path, size, flags)
	if not fs:GetFont() then
		fs:SetFont(STANDARD_TEXT_FONT, size, flags)
	end
	if flags == "" then
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 1)
	else
		fs:SetShadowOffset(0, 0)
	end
end

local function SetBrezFont(fs, size)
	if fs then SetFontSafe(fs, GetBrezFont(), size, GetBrezOutline()) end
end

local function SetBrezIconFont(fs, size)
	if fs then
		SetFontSafe(fs, (ns.GetFontPath and ns.GetFontPath(FONT_KEY)) or STANDARD_TEXT_FONT, size, "OUTLINE")
	end
end

-------------------------------------------------------------------------------
--  Icon look
-------------------------------------------------------------------------------
local BORDER_PX = { none = 0, thin = 1, normal = 2, heavy = 3, strong = 4 }
ns.BATTLERES_BORDER_PX = BORDER_PX

local function Snap(v)
	local PP = ns.PP
	if PP and PP.Snap then return PP.Snap(v) end
	return v
end

local function ResolveBorderColor(p)
	if p.borderUseClass then
		local _, ct = UnitClass("player")
		local cc = ct and RAID_CLASS_COLORS[ct]
		if cc then return cc.r, cc.g, cc.b, 1 end
	end
	local c = p.borderColor
	if c then return c.r or 0, c.g or 0, c.b or 0, c.a or 1 end
	return 0, 0, 0, 1
end

local function ApplyShape()
	local p = P()
	if not frame or not p then return end
	local shape = (p.shape == "cropped") and "cropped" or "none"
	local size = p.iconSize or 40
	local fw, fh = size, size
	if shape == "cropped" then fh = floor(size * 0.80 + 0.5) end
	frame:SetSize(Snap(fw), Snap(fh))

	SetBrezIconFont(durationFS, p.durationSize or 12)
	durationFS:ClearAllPoints()
	durationFS:SetPoint("CENTER", frame, "CENTER", Snap(p.durationOffsetX or 0), Snap(p.durationOffsetY or 0))
	SetBrezIconFont(countFS, p.countSize or 11)
	countFS:ClearAllPoints()
	countFS:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", Snap(-2 + (p.countOffsetX or 0)), Snap(2 + (p.countOffsetY or 0)))

	local z = (p.iconZoom or 11) / 100
	if shape == "cropped" then
		iconTex:SetTexCoord(z, 1 - z, z + 0.10, 1 - z - 0.10)
	else
		iconTex:SetTexCoord(z, 1 - z, z, 1 - z)
	end

	local PP = ns.PP
	local bs = BORDER_PX[p.borderSize or "thin"] or 1
	if PP and PP.CreateBorder then
		if not border then
			border = PP.CreateBorder(frame, 0, 0, 0, 1, 1, "OVERLAY", 2)
			border:SetFrameLevel(cooldownFrame:GetFrameLevel() + 1)
		end
		if bs > 0 then
			PP.SetBorderSize(frame, bs)
			PP.SetBorderColor(frame, ResolveBorderColor(p))
			border:Show()
		else
			border:Hide()
		end
	end
end

-------------------------------------------------------------------------------
--  Text display "2 | 4:14"
-------------------------------------------------------------------------------
local function HexColor(c)
	return format("|cff%02x%02x%02x", floor(((c and c.r) or 1) * 255 + 0.5),
		floor(((c and c.g) or 1) * 255 + 0.5), floor(((c and c.b) or 1) * 255 + 0.5))
end

local cntPfx, timPfx = "|cffffffff", "|cffffffff"
local txtCount, txtTime, txtZero

local function SetTextDisplay(countStr, timeStr, isZero)
	if not textFS then return end
	if countStr == txtCount and timeStr == txtTime and isZero == txtZero then return end
	txtCount, txtTime, txtZero = countStr, timeStr, isZero
	local cpfx = isZero and "|cffff3333" or cntPfx
	if timeStr ~= "" then
		textFS:SetFormattedText("%s%s|r |cffa6a6a6|||r %s%s|r", cpfx, countStr, timPfx, timeStr)
	else
		textFS:SetFormattedText("%s%s|r", cpfx, countStr)
	end
end

local function ApplyText()
	local p = P()
	if not p or not textFS then return end
	cntPfx = HexColor(p.textCountColor)
	timPfx = HexColor(p.textTimerColor)
	SetBrezFont(textFS, p.textSize or 14)
	txtCount, txtTime, txtZero = nil, nil, nil
	if not frame:IsShown() then
		SetTextDisplay("2", "4:14", false)
	end
	local w = textFS:GetStringWidth() or 0
	local h = textFS:GetStringHeight() or 0
	if w < 1 then w = (p.textSize or 14) * 4 end
	if h < 1 then h = p.textSize or 14 end
	frame:SetSize(Snap(math.ceil(w) + 4), Snap(math.ceil(h) + 2))
end

-------------------------------------------------------------------------------
--  Position
-------------------------------------------------------------------------------
local function ApplyPosition()
	if not frame then return end
	-- While Unlock Mode is open its mover owns the spot; an unlock anchor after.
	if ns._unlockActive and frame:GetNumPoints() > 0 then return end
	local p = P()
	if not p then return end
	frame:ClearAllPoints()
	local pos = p.pos
	local cx = (pos and pos.centerX) or 0
	local cy = (pos and pos.centerY) or 200
	local PP = ns.PP
	if PP and PP.SnapCenterForDim then
		cx = PP.SnapCenterForDim(cx, frame:GetWidth())
		cy = PP.SnapCenterForDim(cy, frame:GetHeight())
	end
	frame:SetPoint("CENTER", UIParent, "CENTER", cx, cy)
	if not ns._unlockActive and ns.IsUnlockAnchored and ns.IsUnlockAnchored("EUI_BattleRes") and ns.ReapplyOwnAnchor then
		ns.ReapplyOwnAnchor("EUI_BattleRes")
	end
end

-------------------------------------------------------------------------------
--  Brez tracking (combat log)
-------------------------------------------------------------------------------
local state = {
	inEncounter = false,
	limit = nil,       -- brez allowed this attempt (nil = no limit)
	used = 0,          -- accepted brez this attempt
	inChallenge = false,
}
local pending = {}     -- [targetGUID] = time a brez was seen on the dead player
local selfRes = {}     -- [guid] = time of a Reincarnation (free self res)
local deadState = {}   -- [guid] = "dead" | "ghost": group members dead this attempt
local readyAt = {}     -- [casterGUID] = time the caster's brez is ready again
local resetOnEnd = {}  -- [casterGUID] = true if that cooldown resets after a boss
local knownCasters = {} -- [casterGUID] = true: seen casting a brez (quilen hunters)

local function InstanceInfo()
	local _, instanceType, difficulty, _, maxPlayers = GetInstanceInfo()
	return instanceType, difficulty or 0, maxPlayers or 0
end

local function LimitFor(groupSize)
	local instanceType, difficulty, maxPlayers = InstanceInfo()
	if instanceType ~= "raid" then return nil end
	local size = (groupSize and groupSize > 0) and groupSize or maxPlayers
	if difficulty == 3 or difficulty == 5 then return 1 end
	if difficulty == 4 or difficulty == 6 or difficulty == 7 then return 3 end
	-- Flex and anything else: by group size.
	if size > 0 and size <= 10 then return 1 end
	return 3
end

local function RefreshInstanceState()
	local instanceType, difficulty = InstanceInfo()
	state.inChallenge = (instanceType == "party" and difficulty == CHALLENGE_DIFFICULTY)
	local busy = IsEncounterInProgress and IsEncounterInProgress() or false
	if busy and not state.inEncounter then
		-- Reload or join mid fight: earlier brez of this attempt are unknown.
		state.inEncounter = true
		state.limit = LimitFor()
		state.used = 0
	elseif not busy and state.inEncounter then
		state.inEncounter = false
		state.encounterID = nil
	end
end

local function StartEncounter(encounterID, groupSize)
	-- Some bosses send extra ENCOUNTER_START (id 0) mid fight, e.g. at each
	-- new Spirit King. Same attempt: keep the brez already used.
	if state.inEncounter and (encounterID == 0 or encounterID == state.encounterID) then
		return
	end
	state.inEncounter = true
	state.encounterID = encounterID
	state.limit = LimitFor(groupSize)
	state.used = 0
	wipe(pending); wipe(selfRes); wipe(deadState)
end

local function EndEncounter()
	state.inEncounter = false
	state.encounterID = nil
	state.used = 0
	wipe(pending); wipe(selfRes); wipe(deadState)
	local _, difficulty = InstanceInfo()
	if RESET_DIFFICULTY[difficulty] then
		for guid in pairs(readyAt) do
			if resetOnEnd[guid] then
				readyAt[guid] = nil
			end
		end
	end
end

local function ForEachGroupUnit(fn)
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do fn("raid" .. i) end
	else
		fn("player")
		for i = 1, GetNumSubgroupMembers() do fn("party" .. i) end
	end
end

-- Dead -> alive during the boss = one brez used, except:
--   * Reincarnation (seen in the log or sent by the shaman),
--   * a shaman with no brez seen on them (may be an unseen Reincarnation),
--   * a released ghost with no brez seen (spirit healer / corpse run).
-- Works in other phases: raid death state does not need the combat log.
local scanNow
local function ScanDeathUnit(unit)
	local guid = UnitGUID(unit)
	if not guid or not UnitIsConnected(unit) then return end
	if UnitIsDeadOrGhost(unit) and not (UnitIsFeignDeath and UnitIsFeignDeath(unit)) then
		deadState[guid] = UnitIsGhost(unit) and "ghost" or "dead"
		return
	end
	local was = deadState[guid]
	if not was then return end
	deadState[guid] = nil
	local brezAt, freeAt = pending[guid], selfRes[guid]
	pending[guid], selfRes[guid] = nil, nil
	if freeAt and scanNow - freeAt <= 10 then return end
	local brez = brezAt and scanNow - brezAt <= 65
	if not brez then
		if was == "ghost" then return end
		local _, class = UnitClass(unit)
		if class == "SHAMAN" then return end
	end
	state.used = state.used + 1
end

local function ScanDeaths(now)
	if not state.inEncounter then return end
	scanNow = now
	ForEachGroupUnit(ScanDeathUnit)
end

-- Ready brez casters now, and the time until the next one is ready.
local readyCount, nextReady, nextStart
local function ScanCasters(unit)
	local guid = UnitGUID(unit)
	if not guid then return end
	local _, class = UnitClass(unit)
	local hasBrez = BREZ_CLASSES[class] or knownCasters[guid]
	if not hasBrez then return end
	local t = readyAt[guid]
	local now = GetTime()
	if t and t > now then
		if not nextReady or t < nextReady then
			nextReady, nextStart = t, t - BREZ_COOLDOWN
		end
	elseif UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) then
		readyCount = readyCount + 1
	end
end

local function CasterStatus()
	readyCount, nextReady, nextStart = 0, nil, nil
	ForEachGroupUnit(ScanCasters)
	return readyCount, nextReady, nextStart
end

-- One brez event, from the combat log or an EUI addon message. Only notes
-- who cast what; ScanDeaths does the counting.
local function NoteBrez(spellId, srcGUID, dstGUID, isCast)
	if not srcGUID then return end
	local now = GetTime()
	if spellId == REINCARNATION then
		selfRes[srcGUID] = now
		return
	end
	if spellId == SOULSTONE_SELF_RES then
		pending[srcGUID] = now
		return
	end
	if not BREZ_SPELLS[spellId] then return end
	if isCast or not readyAt[srcGUID] or readyAt[srcGUID] < now then
		readyAt[srcGUID] = now + BREZ_COOLDOWN
		resetOnEnd[srcGUID] = not NO_ENCOUNTER_RESET[spellId]
		knownCasters[srcGUID] = true
	end
	if dstGUID and state.inEncounter then
		pending[dstGUID] = now
	end
end

local function CommChannel()
	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and IsInInstance() then return "INSTANCE_CHAT" end
	if IsInRaid() then return "RAID" end
	if IsInGroup() then return "PARTY" end
	return nil
end

-- Brez events we are part of go to the group, so EUI users in another
-- phase still learn the caster's cooldown and who was brezzed.
local function SendBrez(spellId, srcGUID, dstGUID, isCast)
	local channel = CommChannel()
	if not channel then return end
	SendAddonMessage(COMM_PREFIX, format("%d:%s:%s:%d", spellId, srcGUID, dstGUID or "", isCast and 1 or 0), channel)
end

local function OnComm(prefix, msg, _, sender)
	if prefix ~= COMM_PREFIX or not msg then return end
	if sender and sender:match("^[^%-]+") == UnitName("player") then return end
	local spellId, srcGUID, dstGUID, isCast = msg:match("^(%d+):([^:]+):([^:]*):(%d)$")
	spellId = tonumber(spellId)
	if not spellId then return end
	NoteBrez(spellId, srcGUID, dstGUID ~= "" and dstGUID or nil, isCast == "1")
end

local function OnCombatLog(...)
	local _, subEvent, _, srcGUID, _, srcFlags, _, dstGUID, _, _, _, spellId = ...
	if subEvent ~= "SPELL_CAST_SUCCESS" and subEvent ~= "SPELL_RESURRECT" then return end
	if not srcFlags or band(srcFlags, GROUP_AFFILIATION) == 0 then return end
	if not (BREZ_SPELLS[spellId] or spellId == SOULSTONE_SELF_RES or spellId == REINCARNATION) then return end
	if dstGUID == "" or dstGUID == "0x0000000000000000" then dstGUID = nil end
	local isCast = subEvent == "SPELL_CAST_SUCCESS"
	NoteBrez(spellId, srcGUID, dstGUID, isCast)
	local me = UnitGUID("player")
	if srcGUID == me or dstGUID == me then
		SendBrez(spellId, srcGUID, dstGUID, isCast)
	end
end

-------------------------------------------------------------------------------
--  Visibility
-------------------------------------------------------------------------------
local function ShouldShow()
	local p = P()
	if not p or not p.enabled then return false end
	local v = p.visibility or "MPLUS_AND_RAID"
	if v == "NEVER" then return false end
	if PreviewActive() then return true end
	local instanceType = InstanceInfo()
	if instanceType ~= "party" and instanceType ~= "raid" then return false end
	local wantChallenge = (v == "MPLUS_AND_RAID" or v == "MPLUS")
	local wantRaid = (v == "MPLUS_AND_RAID" or v == "RAID")
	if wantChallenge and state.inChallenge then return true end
	if wantRaid and state.inEncounter and instanceType == "raid" then return true end
	return false
end

-------------------------------------------------------------------------------
--  Polling (only while shown)
-------------------------------------------------------------------------------
local function FormatTime(s)
	if not s or s <= 0 then return "" end
	return format("%d:%02d", floor(s / 60), floor(s % 60))
end
ns.FormatTime = ns.FormatTime or FormatTime

local lastCountText, lastDurText, lastCountColor
local function SetCount(s, isZero)
	if s ~= lastCountText then
		countFS:SetText(s)
		lastCountText = s
	end
	local key = isZero and "zero" or "ok"
	if key ~= lastCountColor then
		if isZero then countFS:SetTextColor(1, 0.2, 0.2, 1)
		else countFS:SetTextColor(1, 1, 1, 1) end
		lastCountColor = key
	end
end
local function SetDur(s)
	if s ~= lastDurText then
		durationFS:SetText(s)
		lastDurText = s
	end
end
local lastDesat = false
local function SetDesat(want)
	want = want and true or false
	if want ~= lastDesat then
		iconTex:SetDesaturated(want)
		lastDesat = want
	end
end

-- Cooldown swipe: set only when the start changes (re-setting restarts it).
local swipeStart, swipeDur
local function SetSwipe(start, dur)
	if not cooldownFrame then return end
	if start == swipeStart and dur == swipeDur then return end
	swipeStart, swipeDur = start, dur
	if start and dur then
		cooldownFrame:SetCooldown(start, dur)
		cooldownFrame:Show()
	else
		cooldownFrame:SetCooldown(0, 0)
	end
end

-- Preview stand-in outside a raid boss / Challenge Mode (same as retail).
local previewExpiry = 0
local function ShowPreviewCharges()
	local now = GetTime()
	if previewExpiry <= now then
		previewExpiry = now + 90
	end
	local timeText = FormatTime(previewExpiry - now)
	if IsTextMode() then
		SetTextDisplay("2", timeText, false)
		return
	end
	SetSwipe(previewExpiry - 90, 90)
	SetCount("2", false)
	SetDur(timeText)
	SetDesat(false)
end

local function PollCharges()
	if not frame then return end
	local now = GetTime()
	RefreshInstanceState()
	ScanDeaths(now)
	local live = (state.inEncounter and state.limit) or state.inChallenge
	if not live then
		if PreviewActive() then return ShowPreviewCharges() end
		if IsTextMode() then
			SetTextDisplay("", "", false)
		else
			SetCount("", false); SetDur(""); SetDesat(false); SetSwipe(nil)
		end
		return
	end

	local ready, nextAt, start = CasterStatus()
	local charges
	if state.inEncounter and state.limit then
		charges = max(0, state.limit - state.used)
	else
		charges = ready
	end
	-- Timer: no caster ready yet, but brez are still allowed.
	local waiting = ready == 0 and nextAt and (charges > 0 or not state.limit or not state.inEncounter)
	local timeText = waiting and FormatTime(nextAt - now) or ""
	local zero = charges <= 0

	if IsTextMode() then
		SetTextDisplay(tostring(charges), timeText, zero)
		return
	end
	SetCount(tostring(charges), zero)
	SetDur(timeText)
	local p = P()
	SetDesat(p and p.desaturateNoCharges ~= false and zero)
	if waiting then
		SetSwipe(start, BREZ_COOLDOWN)
	else
		SetSwipe(nil)
	end
end

local ticker = CreateFrame("Frame")
local tickerOn, tickerAcc = false, 0
local function TickerUpdate(_, elapsed)
	tickerAcc = tickerAcc + elapsed
	if tickerAcc >= 0.5 then
		tickerAcc = 0
		PollCharges()
	end
end
local function StartTicker()
	if tickerOn then return end
	tickerOn, tickerAcc = true, 0
	ticker:SetScript("OnUpdate", TickerUpdate)
end
local function StopTicker()
	if not tickerOn then return end
	tickerOn = false
	ticker:SetScript("OnUpdate", nil)
end

local function UpdateVisibility()
	if not frame then return end
	RefreshInstanceState()
	if ShouldShow() then
		if not frame:IsShown() then frame:Show() end
		StartTicker()
		PollCharges()
	else
		if frame:IsShown() then frame:Hide() end
		StopTicker()
		if previewExpiry ~= 0 and not PreviewActive() then
			previewExpiry = 0
			SetSwipe(nil)
			if IsTextMode() then
				SetTextDisplay("", "", false)
			else
				SetCount("", false); SetDur("")
			end
		end
	end
end
ns.BattleResUpdateVisibility = UpdateVisibility

-- The settings page hands over its frame; the preview runs while it is visible.
function ns.BattleResSetPreviewOwner(f)
	previewOwner = f
	previewExpiry = 0
	UpdateVisibility()
end

-------------------------------------------------------------------------------
--  Frame
-------------------------------------------------------------------------------
local function CreateBrezFrame()
	if frame then return frame end
	frame = CreateFrame("Frame", "EllesmereUIBattleResIcon", UIParent)
	frame:SetFrameStrata("MEDIUM")
	frame:SetSize(40, 40)
	frame:Hide()

	iconTex = frame:CreateTexture(nil, "ARTWORK")
	iconTex:SetAllPoints(frame)
	local _, _, brezIcon = GetSpellInfo(BREZ_ICON_SPELL)
	iconTex:SetTexture(brezIcon or "Interface\\Icons\\Spell_Nature_Reincarnation")
	iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	cooldownFrame = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
	cooldownFrame:SetAllPoints(frame)
	cooldownFrame.noCooldownCount = true  -- OmniCC & co.: we draw our own timer
	cooldownFrame.noOCC = true
	cooldownFrame:SetFrameLevel(frame:GetFrameLevel() + 1)

	-- Texts sit above the swipe (the cooldown frame hides itself when done).
	local textHolder = CreateFrame("Frame", nil, frame)
	textHolder:SetAllPoints(frame)
	textHolder:SetFrameLevel(frame:GetFrameLevel() + 3)
	frame.textHolder = textHolder

	durationFS = textHolder:CreateFontString(nil, "OVERLAY")
	SetBrezIconFont(durationFS, 14)
	durationFS:SetText("")

	countFS = textHolder:CreateFontString(nil, "OVERLAY")
	SetBrezIconFont(countFS, 12)
	countFS:SetText("")

	textFS = frame:CreateFontString(nil, "OVERLAY")
	SetBrezFont(textFS, 14)
	textFS:SetPoint("CENTER", frame, "CENTER", 0, 0)
	textFS:SetText("")
	textFS:Hide()
	return frame
end

-------------------------------------------------------------------------------
--  Events
-------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local eventsRegistered = false

local function SyncEventRegistration()
	local p = P()
	local want = (p and p.enabled and (p.visibility or "MPLUS_AND_RAID") ~= "NEVER") and true or false
	if want == eventsRegistered then return end
	eventsRegistered = want
	if want then
		eventFrame:RegisterEvent("ENCOUNTER_START")
		eventFrame:RegisterEvent("ENCOUNTER_END")
		eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
		eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
		eventFrame:RegisterEvent("WORLD_STATE_TIMER_START")
		eventFrame:RegisterEvent("WORLD_STATE_TIMER_STOP")
		eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
		eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		eventFrame:RegisterEvent("CHAT_MSG_ADDON")
		if RegisterAddonMessagePrefix then RegisterAddonMessagePrefix(COMM_PREFIX) end
		RefreshInstanceState()
	else
		eventFrame:UnregisterAllEvents()
		state.inEncounter = false
		state.encounterID = nil
		wipe(pending); wipe(selfRes); wipe(deadState)
	end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		OnCombatLog(...)
		return
	elseif event == "CHAT_MSG_ADDON" then
		OnComm(...)
		return
	elseif event == "ENCOUNTER_START" then
		local encounterID, _, _, groupSize = ...
		StartEncounter(encounterID or 0, groupSize)
	elseif event == "ENCOUNTER_END" then
		-- A stray ENCOUNTER_END (id 0) can come next to the real one; only
		-- the real one ends the attempt.
		local encounterID = ... or 0
		if encounterID ~= 0 or not state.encounterID or state.encounterID == 0 then
			EndEncounter()
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		-- Fallback for a missed ENCOUNTER_END (wipe while out of range, etc.).
		if state.inEncounter and not (IsEncounterInProgress and IsEncounterInProgress()) then
			EndEncounter()
		end
	end
	UpdateVisibility()
end)

-------------------------------------------------------------------------------
--  Apply (every settings change)
-------------------------------------------------------------------------------
local function Apply()
	if not P() then return end
	if not frame then CreateBrezFrame() end
	if IsTextMode() then
		iconTex:Hide()
		cooldownFrame:Hide()
		frame.textHolder:Hide()
		if border then border:Hide() end
		swipeStart, swipeDur = nil, nil
		textFS:Show()
		ApplyText()
	else
		textFS:Hide()
		iconTex:Show()
		frame.textHolder:Show()
		ApplyShape()
	end
	ApplyPosition()
	SyncEventRegistration()
	UpdateVisibility()
end
ns.BattleResApply = Apply

ns.applyHooks = ns.applyHooks or {}
tinsert(ns.applyHooks, function()
	if frame then Apply() end
end)

-------------------------------------------------------------------------------
--  Unlock Mode
-------------------------------------------------------------------------------
local function RegisterUnlock()
	if not ns.RegisterUnlockElements or not ns.MakeUnlockElement then return end
	local function Resized()
		Apply()
		if ns._unlockActive and ns.RepositionBarToMover then
			ns.RepositionBarToMover("EUI_BattleRes")
		end
	end
	ns:RegisterUnlockElements({
		ns.MakeUnlockElement({
			key = "EUI_BattleRes",
			label = "Brez",
			group = "Quality of Life",
			order = 600,
			noAnchorTarget = true,
			isHidden = function()
				local p = P()
				return not p or not p.enabled or p.visibility == "NEVER"
			end,
			getFrame = function()
				if not frame then CreateBrezFrame() end
				return frame
			end,
			getSize = function()
				local p = P()
				if p and p.displayMode == "text" and frame then
					local w, h = frame:GetWidth(), frame:GetHeight()
					if w and w > 0 then return w, h end
				end
				local s = (p and p.iconSize) or 40
				return s, s
			end,
			linkedDimensions = true,
			setWidth = function(_, w)
				local p = P()
				if not p or p.displayMode == "text" then return end
				p.iconSize = max(16, floor(Snap(w) + 0.5))
				Resized()
			end,
			setHeight = function(_, h)
				local p = P()
				if not p then return end
				if p.displayMode == "text" then
					if frame and math.abs(h - frame:GetHeight()) < 0.5 then return end
					p.textSize = max(8, min(40, floor(h + 0.5) - 2))
				else
					p.iconSize = max(16, floor(Snap(h) + 0.5))
				end
				Resized()
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
boot:SetScript("OnEvent", function(self)
	self:UnregisterAllEvents()
	CreateBrezFrame()
	Apply()
end)
