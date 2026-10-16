-------------------------------------------------------------------------------
--  EUI_MythicTimer_TargetedSpellBars.lua (5.4.8 port)
--  Targeted Spell Bars (Mythic+ Tools): one movable group of cast bars, one
--  per enemy that is casting, with spell name, spell target and timer, the
--  interrupt colors (interrupt on cooldown tint, uninterruptible wash), the
--  out-of-interrupt-range fade and raid target markers.
--
--  5.4.8 has no nameplate unit tokens, so casters are found two ways:
--    * every enemy reachable by a unit token (target, focus, mouseover,
--      boss1-5, the group's targets) is read with UnitCastingInfo /
--      UnitChannelInfo: exact times, interruptible flag, spell target;
--    * any other hostile SPELL_CAST_START in the combat log gets a bar
--      timed from the spell's cast time (no target, no channel).
--  Important-cast tint/glow does not exist on 5.4.8 (no such flag).
--  Nothing is registered or built while the feature is off.
-------------------------------------------------------------------------------
local addonName, P = ...
local ns = EllesmereUI

local floor, max, min = math.floor, math.max, math.min
local band = bit.band
local WHITE = P.WHITE
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

local db

local function Cfg()
	local p = db and db.profile
	return p and p.tsb
end

local RAID_MARKER_TEXCOORDS = {
	[1] = { 0,    0.25, 0,    0.25 },
	[2] = { 0.25, 0.5,  0,    0.25 },
	[3] = { 0.5,  0.75, 0,    0.25 },
	[4] = { 0.75, 1,    0,    0.25 },
	[5] = { 0,    0.25, 0.25, 0.5  },
	[6] = { 0.25, 0.5,  0.25, 0.5  },
	[7] = { 0.5,  0.75, 0.25, 0.5  },
	[8] = { 0.75, 1,    0.25, 0.5  },
}

local container
local bars = {}         -- frame pool
local shown = {}        -- entries in display order
local byGUID = {}       -- guid -> entry
local live = false      -- tracking registered
local previewOn = false
local whereInCombat = false

local DEFAULT_X, DEFAULT_Y = -340, 60

-------------------------------------------------------------------------------
--  Where to Show (retail buckets, 5.4.8 difficulty IDs)
-------------------------------------------------------------------------------
local function CurrentWhereBucket()
	local _, iType, diffID = GetInstanceInfo()
	diffID = tonumber(diffID) or 0
	if iType == "party" then
		if diffID == 8 then return "dungeon_mythic" end   -- Challenge Mode
		return "dungeon_nonmythic"
	elseif iType == "raid" then
		if diffID == 5 or diffID == 6 then return "raid_heroic" end
		return "raid_normal_lfr"
	elseif iType == "scenario" then
		return "scenario"
	end
	if not IsInInstance() then return "open_world" end
	return nil
end

local LOCATION_KEYS = {
	"open_world", "raid_mythic", "raid_heroic", "raid_normal_lfr",
	"dungeon_mythic", "dungeon_nonmythic", "timewalking", "delve", "lair", "scenario",
}

local function WhereShows(whereToShow)
	if not whereToShow or not next(whereToShow) then return true end
	local wantIn = whereToShow.in_combat == true
	local wantOut = whereToShow.out_of_combat == true
	if wantIn ~= wantOut then
		if whereInCombat ~= wantIn then return false end
	end
	local anyLoc = false
	for i = 1, #LOCATION_KEYS do
		if whereToShow[LOCATION_KEYS[i]] == true then anyLoc = true; break end
	end
	if not anyLoc then return true end
	local bucket = CurrentWhereBucket()
	if not bucket then return true end
	return whereToShow[bucket] == true
end

-------------------------------------------------------------------------------
--  Frames
-------------------------------------------------------------------------------
local function ApplyContainerPosition()
	if not container then return end
	local cfg = Cfg()
	local pos = cfg and cfg.pos
	container:ClearAllPoints()
	if pos and pos.centerX and pos.centerY then
		container:SetPoint("CENTER", UIParent, "CENTER", pos.centerX, pos.centerY)
	else
		container:SetPoint("CENTER", UIParent, "CENTER", DEFAULT_X, DEFAULT_Y)
	end
end

local function EnsureContainer()
	if container then return container end
	container = CreateFrame("Frame", nil, UIParent)
	container:SetSize(240, 20)
	ApplyContainerPosition()
	return container
end

local function BuildBar()
	local holder = CreateFrame("Frame", nil, EnsureContainer())
	holder:Hide()
	holder.bg = holder:CreateTexture(nil, "BACKGROUND")
	holder.bg:SetAllPoints(holder)

	holder.iconFrame = CreateFrame("Frame", nil, holder)
	holder.icon = holder.iconFrame:CreateTexture(nil, "ARTWORK")
	holder.icon:SetAllPoints(holder.iconFrame)
	holder.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	holder.overlayFrame = CreateFrame("Frame", nil, holder)
	holder.overlayFrame:SetAllPoints(holder)
	holder.overlayFrame:SetFrameLevel(holder:GetFrameLevel() + 5)
	holder.iconDivider = holder.overlayFrame:CreateTexture(nil, "OVERLAY", nil, 7)
	holder.iconDivider:SetTexture(0, 0, 0, 1)
	holder.iconDivider:Hide()

	holder.sb = CreateFrame("StatusBar", nil, holder)
	holder.sb:SetStatusBarTexture(WHITE)
	holder.sb:SetMinMaxValues(0, 1)
	holder.sb:SetValue(0)

	holder.overlay = holder.sb:CreateTexture(nil, "ARTWORK", nil, 2)
	holder.overlay:SetTexture(WHITE)
	holder.overlay:SetAllPoints(holder.sb:GetStatusBarTexture())
	holder.overlay:SetAlpha(0)

	holder.textFrame = CreateFrame("Frame", nil, holder.sb)
	holder.textFrame:SetAllPoints(holder.sb)
	holder.textFrame:SetFrameLevel(holder.sb:GetFrameLevel() + 6)
	holder.marker = holder.textFrame:CreateTexture(nil, "OVERLAY")
	holder.marker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	holder.marker:Hide()
	holder.name = holder.textFrame:CreateFontString(nil, "OVERLAY")
	P.SetFS(holder.name, 10)
	holder.name:SetJustifyH("LEFT")
	holder.name:SetWordWrap(false)
	holder.target = holder.textFrame:CreateFontString(nil, "OVERLAY")
	P.SetFS(holder.target, 10)
	holder.target:SetJustifyH("RIGHT")
	holder.target:SetWordWrap(false)
	holder.timer = holder.textFrame:CreateFontString(nil, "OVERLAY")
	P.SetFS(holder.timer, 10)
	holder.timer:SetJustifyH("RIGHT")
	holder.timer:SetWordWrap(false)
	return holder
end

local function AcquireBarFrame()
	for i = 1, #bars do
		if not bars[i]._tsbInUse then
			bars[i]._tsbInUse = true
			return bars[i]
		end
	end
	local b = BuildBar()
	bars[#bars + 1] = b
	b._tsbInUse = true
	return b
end

local function AnchorName(holder, cfg, markerShown, hasTarget)
	local w = cfg.width or 240
	local h = cfg.height or 20
	local markerReserve = markerShown and ((cfg.raidMarkerSize or 14) + 2) or 0
	holder.name:ClearAllPoints()
	holder.name:SetPoint("LEFT", holder.sb, "LEFT", 4 + markerReserve + (cfg.nameX or 0), cfg.nameY or 0)
	local shared = (w - h) * 0.48 - markerReserve
	local nameWidth = shared
	if not hasTarget then
		local timerReserve = (cfg.showTimer ~= false) and ((cfg.timerSize or 10) * 2.2) or 0
		nameWidth = max(shared, (w - h) - 8 - markerReserve - timerReserve)
	end
	if nameWidth < 1 then nameWidth = 1 end
	holder.name:SetWidth(nameWidth)
end

local function StyleBar(holder, cfg)
	local w = cfg.width or 240
	local h = cfg.height or 20
	holder:SetSize(w, h)
	local bg = cfg.bgColor
	if bg then holder.bg:SetTexture(bg.r or 0, bg.g or 0, bg.b or 0, bg.a or 0.45)
	else holder.bg:SetTexture(0, 0, 0, 0.45) end

	local showIcon = cfg.showIcon ~= false
	local iconOnRight = showIcon and cfg.iconOnRight
	holder.iconFrame:ClearAllPoints()
	if iconOnRight then
		holder.iconFrame:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
		holder.iconFrame:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
	else
		holder.iconFrame:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
		holder.iconFrame:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
	end
	holder.iconFrame:SetWidth(showIcon and h or 0.001)
	holder.iconFrame:SetShown(showIcon)
	holder.sb:ClearAllPoints()
	if iconOnRight then
		holder.sb:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
		holder.sb:SetPoint("BOTTOMRIGHT", holder.iconFrame, "BOTTOMLEFT", 0, 0)
	else
		holder.sb:SetPoint("TOPLEFT", holder.iconFrame, "TOPRIGHT", 0, 0)
		holder.sb:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
	end
	holder.sb:SetStatusBarTexture(P.TexturePath(cfg.texture) or WHITE)
	local c = cfg.barColor
	if c then holder.sb:SetStatusBarColor(c.r, c.g, c.b) end
	holder.overlay:ClearAllPoints()
	holder.overlay:SetAllPoints(holder.sb:GetStatusBarTexture())
	local un = cfg.uninterruptible
	if un then holder.overlay:SetVertexColor(un.r, un.g, un.b) end

	local bsz = cfg.borderSize
	if bsz == nil then bsz = 1 end
	P.ApplyEdges(holder, "_edges", holder, holder, bsz, 0, 0, 0, 1, true)

	if showIcon and cfg.showIconDivider then
		local px = (ns.PP and ns.PP.mult) or 1
		holder.iconDivider:ClearAllPoints()
		holder.iconDivider:SetWidth(max(px, (bsz > 0 and bsz or 1) * px))
		if iconOnRight then
			holder.iconDivider:SetPoint("TOPRIGHT", holder.iconFrame, "TOPLEFT", 0, 0)
			holder.iconDivider:SetPoint("BOTTOMRIGHT", holder.iconFrame, "BOTTOMLEFT", 0, 0)
		else
			holder.iconDivider:SetPoint("TOPLEFT", holder.iconFrame, "TOPRIGHT", 0, 0)
			holder.iconDivider:SetPoint("BOTTOMLEFT", holder.iconFrame, "BOTTOMRIGHT", 0, 0)
		end
		holder.iconDivider:Show()
	else
		holder.iconDivider:Hide()
	end

	P.SetFS(holder.name, cfg.nameSize or 10)
	P.SetFS(holder.target, cfg.targetSize or 10)
	P.SetFS(holder.timer, cfg.timerSize or 10)
	local showTimer = cfg.showTimer ~= false
	local timerReserve = showTimer and ((cfg.timerSize or 10) * 2.2) or 0
	AnchorName(holder, cfg, holder.marker:IsShown(), holder.target:IsShown())
	holder.timer:ClearAllPoints()
	holder.timer:SetPoint("RIGHT", holder.sb, "RIGHT", -3 + (cfg.timerX or 0), cfg.timerY or 0)
	holder.target:ClearAllPoints()
	holder.target:SetPoint("RIGHT", holder.sb, "RIGHT", -3 - timerReserve + (cfg.targetX or 0), cfg.targetY or 0)
	holder.target:SetWidth((w - h) * 0.40)
	local msz = cfg.raidMarkerSize or 14
	holder.marker:SetSize(msz, msz)
	holder.marker:ClearAllPoints()
	holder.marker:SetPoint("LEFT", holder.sb, "LEFT", 3, 0)
	holder.name:SetShown(cfg.showSpellName ~= false)
	holder.timer:SetShown(showTimer)
end

local function PositionBar(holder, slot, cfg)
	holder:ClearAllPoints()
	local off = (slot - 1) * ((cfg.height or 20) + (cfg.spacing or 4))
	if cfg.growUp then
		holder:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, off)
	else
		holder:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -off)
	end
end

local function Reflow()
	local cfg = Cfg()
	if not cfg then return end
	for i = 1, #shown do PositionBar(shown[i].bar, i, cfg) end
end

-------------------------------------------------------------------------------
--  Per entry visuals
-------------------------------------------------------------------------------
local function ApplyCastColor(e, cfg)
	local holder = e.bar
	holder.overlay:SetAlpha(e.notInterruptible and 1 or 0)
	local base = cfg.barColor or { r = 0.70, g = 0.40, b = 0.90 }
	local r, g, b = base.r, base.g, base.b
	local left = P.KickRemaining()
	if left and left > 0 then
		local ready = cfg.interruptReady or { r = 0.92, g = 0.35, b = 0.20 }
		r, g, b = ready.r, ready.g, ready.b
	end
	holder.sb:SetStatusBarColor(r, g, b)
end

local function ApplyRaidMarker(e, cfg)
	local holder = e.bar
	local idx = e.marker
	if e.unit and UnitGUID(e.unit) == e.guid then
		idx = GetRaidTargetIndex(e.unit)
	end
	local tc = cfg.showRaidMarker and idx and RAID_MARKER_TEXCOORDS[idx]
	if not tc then
		if holder.marker:IsShown() then
			holder.marker:Hide()
			AnchorName(holder, cfg, false, holder.target:IsShown())
		end
		return
	end
	holder.marker:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
	if not holder.marker:IsShown() then
		holder.marker:Show()
		AnchorName(holder, cfg, true, holder.target:IsShown())
	end
end

local function ApplyRangeAlpha(e, cfg)
	local holder = e.bar
	local kick = P.KickSpell()
	local kickName = kick and GetSpellInfo(kick)
	if not (cfg.oorEnabled and kickName and e.unit and UnitGUID(e.unit) == e.guid) then
		holder:SetAlpha(1)
		return
	end
	local inRange = IsSpellInRange(kickName, e.unit)
	if inRange == 0 then
		holder:SetAlpha(cfg.oorAlpha or 0.45)
	else
		holder:SetAlpha(1)
	end
end

local function PaintTarget(e, cfg)
	local holder = e.bar
	local name, cls
	if e.unit and UnitGUID(e.unit) == e.guid then
		local tu = e.unit .. "target"
		if UnitExists(tu) and not UnitIsUnit(tu, e.unit) then
			name = UnitName(tu)
			if UnitIsPlayer(tu) then
				local _
				_, cls = UnitClass(tu)
			end
		end
	end
	if cfg.showTarget == false or not name then
		holder.target:SetText("")
		holder.target:Hide()
		AnchorName(holder, cfg, holder.marker:IsShown(), false)
		return
	end
	if cfg.targetClassColor ~= false and cls then
		holder.target:SetTextColor(P.ClassColor(cls))
	else
		local tc = cfg.targetColor
		if tc then holder.target:SetTextColor(tc.r, tc.g, tc.b, 1) else holder.target:SetTextColor(1, 1, 1, 1) end
	end
	holder.target:SetText(name)
	holder.target:Show()
	AnchorName(holder, cfg, holder.marker:IsShown(), true)
end

local function PaintEntry(e, cfg)
	local holder = e.bar
	StyleBar(holder, cfg)
	holder.icon:SetTexture(e.icon or QUESTION)
	if cfg.showSpellName ~= false then holder.name:SetText(e.spell or "") end
	PaintTarget(e, cfg)
	ApplyRaidMarker(e, cfg)
	ApplyCastColor(e, cfg)
	ApplyRangeAlpha(e, cfg)
end

-------------------------------------------------------------------------------
--  Entries
-------------------------------------------------------------------------------
local function Release(e)
	byGUID[e.guid] = nil
	for i = #shown, 1, -1 do
		if shown[i] == e then table.remove(shown, i) end
	end
	local holder = e.bar
	if holder then
		holder:SetAlpha(1)
		holder.overlay:SetAlpha(0)
		holder.marker:Hide()
		holder._tsbInUse = nil
		holder:Hide()
	end
	Reflow()
end

local function ReleaseAll()
	for i = #shown, 1, -1 do
		local e = shown[i]
		byGUID[e.guid or ""] = nil
		local holder = e.bar
		holder:SetAlpha(1)
		holder.overlay:SetAlpha(0)
		holder.marker:Hide()
		holder._tsbInUse = nil
		holder:Hide()
		shown[i] = nil
	end
	wipe(byGUID)
end

-- New or updated cast. info: spell, icon, startTime, endTime, isChannel,
-- notInterruptible, unit, marker, exact.
local function Upsert(guid, info)
	local cfg = Cfg()
	if not cfg or not guid then return end
	local e = byGUID[guid]
	if not e then
		if #shown >= (cfg.maxBars or 5) then return end
		e = { guid = guid, bar = AcquireBarFrame() }
		byGUID[guid] = e
		shown[#shown + 1] = e
		PositionBar(e.bar, #shown, cfg)
	end
	for k, v in pairs(info) do e[k] = v end
	PaintEntry(e, cfg)
	e.bar:Show()
end

-------------------------------------------------------------------------------
--  Unit scan
-------------------------------------------------------------------------------
local UNIT_POOL = { "target", "focus", "mouseover", "boss1", "boss2", "boss3", "boss4", "boss5",
	"party1target", "party2target", "party3target", "party4target", "pettarget" }
local RAID_TARGETS = {}
for i = 1, 40 do RAID_TARGETS[i] = "raid" .. i .. "target" end

local seen = {}
local function ScanUnit(unit, now)
	if not UnitExists(unit) or not UnitCanAttack("player", unit) or UnitIsDead(unit) then return end
	local guid = UnitGUID(unit)
	if not guid or seen[guid] then return end
	seen[guid] = true
	local isChannel = false
	local name, _, _, texture, startMS, endMS, _, _, notInterruptible = UnitCastingInfo(unit)
	if not name then
		name, _, _, texture, startMS, endMS, _, notInterruptible = UnitChannelInfo(unit)
		isChannel = true
	end
	if name and startMS and endMS then
		Upsert(guid, {
			spell = name, icon = texture, startTime = startMS / 1000, endTime = endMS / 1000,
			isChannel = isChannel, notInterruptible = notInterruptible and true or false,
			unit = unit, exact = true, lastSeen = now,
		})
	elseif byGUID[guid] then
		Release(byGUID[guid])
	end
end

local function ScanAll()
	local now = GetTime()
	wipe(seen)
	for i = 1, #UNIT_POOL do ScanUnit(UNIT_POOL[i], now) end
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do ScanUnit(RAID_TARGETS[i], now) end
	end
end

-------------------------------------------------------------------------------
--  Ticker: fill, timer text, expiry, rescan
-------------------------------------------------------------------------------
local ticker = CreateFrame("Frame")
local acc, scanAcc = 0, 0
local function OnTick(_, dt)
	acc = acc + dt
	scanAcc = scanAcc + dt
	if acc < 0.03 then return end
	acc = 0
	if previewOn then return end
	local cfg = Cfg()
	if not cfg then return end
	local doScan = scanAcc >= 0.1
	if doScan then
		scanAcc = 0
		ScanAll()
	end
	local now = GetTime()
	for i = #shown, 1, -1 do
		local e = shown[i]
		if now >= (e.endTime or 0) + 0.1 then
			Release(e)
		else
			local dur = max(0.001, e.endTime - e.startTime)
			local v
			if e.isChannel then v = (e.endTime - now) / dur else v = (now - e.startTime) / dur end
			e.bar.sb:SetValue(max(0, min(1, v)))
			if doScan then
				if cfg.showTimer ~= false then
					e.bar.timer:SetFormattedText("%.1f", max(0, e.endTime - now))
				else
					e.bar.timer:SetText("")
				end
				ApplyCastColor(e, cfg)
				ApplyRaidMarker(e, cfg)
				ApplyRangeAlpha(e, cfg)
				PaintTarget(e, cfg)
			end
		end
	end
end

-------------------------------------------------------------------------------
--  Combat log: hostile casters without a unit token
-------------------------------------------------------------------------------
local HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE or 0x40
local function MarkerFromFlags(flags)
	if not flags or flags == 0 then return nil end
	for i = 1, 8 do
		if band(flags, 2 ^ (i - 1)) > 0 then return i end
	end
	return nil
end

local cleu = CreateFrame("Frame")
cleu:SetScript("OnEvent", function(_, _, _, subEvent, _, srcGUID, _, srcFlags, srcRaidFlags, destGUID, _, _, _, spellID, spellName)
	if subEvent == "SPELL_CAST_START" then
		if not srcGUID or byGUID[srcGUID] or not srcFlags or band(srcFlags, HOSTILE) == 0 then return end
		local name, _, icon, _, _, _, castTime = GetSpellInfo(spellID)
		castTime = tonumber(castTime) or 0
		if castTime <= 0 then return end
		local now = GetTime()
		Upsert(srcGUID, {
			spell = name or spellName, icon = icon, startTime = now, endTime = now + castTime / 1000,
			isChannel = false, notInterruptible = false, unit = nil, exact = false,
			marker = MarkerFromFlags(srcRaidFlags),
		})
	elseif subEvent == "SPELL_CAST_SUCCESS" or subEvent == "SPELL_CAST_FAILED" then
		local e = srcGUID and byGUID[srcGUID]
		if e and not e.exact then Release(e) end
	elseif subEvent == "SPELL_INTERRUPT" or subEvent == "UNIT_DIED" then
		local e = destGUID and byGUID[destGUID]
		if e then Release(e) end
	end
end)

-------------------------------------------------------------------------------
--  Live state (enabled + Where to Show)
-------------------------------------------------------------------------------
local function SetLive(on)
	on = on and true or false
	if on == live then return end
	live = on
	if on then
		EnsureContainer()
		ticker:SetScript("OnUpdate", OnTick)
		cleu:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	else
		ticker:SetScript("OnUpdate", nil)
		cleu:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		if not previewOn then ReleaseAll() end
	end
end

local function SyncWhereActive()
	local cfg = Cfg()
	SetLive(cfg and cfg.enabled == true and WhereShows(cfg.whereToShow))
end

local whereEvt = CreateFrame("Frame")
local WHERE_EVENTS = { "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_DISABLED",
	"PLAYER_REGEN_ENABLED", "PLAYER_DIFFICULTY_CHANGED", "CHALLENGE_MODE_COMPLETED" }
local whereActive = false
whereEvt:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_DISABLED" then
		whereInCombat = true
	elseif event == "PLAYER_REGEN_ENABLED" then
		whereInCombat = false
	elseif event == "PLAYER_ENTERING_WORLD" then
		whereInCombat = InCombatLockdown() and true or false
		P.Timer.After(0.5, SyncWhereActive)
	end
	SyncWhereActive()
end)

local function SetWhereWatcherActive(on)
	on = on and true or false
	if on == whereActive then return end
	whereActive = on
	if on then
		whereInCombat = InCombatLockdown() and true or false
		for i = 1, #WHERE_EVENTS do whereEvt:RegisterEvent(WHERE_EVENTS[i]) end
	else
		whereEvt:UnregisterAllEvents()
	end
end

-------------------------------------------------------------------------------
--  Preview
-------------------------------------------------------------------------------
local PREVIEW_ROWS = {
	{ name = "Shadow Bolt",     timer = "1.8", fill = 0.35, marker = 8 },
	{ name = "Dark Mending",    timer = "0.9", fill = 0.70, marker = 2, uninterruptible = true },
	{ name = "Frostbolt",       timer = "2.4", fill = 0.15 },
	{ name = "Chain Lightning", timer = "1.2", fill = 0.55, marker = 6 },
	{ name = "Fear",            timer = "0.6", fill = 0.85 },
	{ name = "Healing Wave",    timer = "2.0", fill = 0.25 },
	{ name = "Fireball",        timer = "1.5", fill = 0.45 },
	{ name = "Hex",             timer = "1.0", fill = 0.60 },
	{ name = "Mind Flay",       timer = "2.2", fill = 0.20 },
	{ name = "Pyroblast",       timer = "3.1", fill = 0.10 },
}

local function ShowPreview()
	local cfg = Cfg()
	if not cfg then return end
	ReleaseAll()
	EnsureContainer()
	local rows = min(#PREVIEW_ROWS, cfg.maxBars or 5)
	for i = 1, rows do
		local sample = PREVIEW_ROWS[i]
		local e = { guid = "preview" .. i, bar = AcquireBarFrame(), preview = true }
		shown[#shown + 1] = e
		local holder = e.bar
		StyleBar(holder, cfg)
		PositionBar(holder, i, cfg)
		holder:SetAlpha(1)
		holder.icon:SetTexture(QUESTION)
		local hasTarget = cfg.showTarget ~= false
		if hasTarget then
			if cfg.targetClassColor ~= false then
				local _, cls = UnitClass("player")
				holder.target:SetTextColor(P.ClassColor(cls))
			elseif cfg.targetColor then
				holder.target:SetTextColor(cfg.targetColor.r, cfg.targetColor.g, cfg.targetColor.b, 1)
			end
			holder.target:SetText(UnitName("player") or "Target")
			holder.target:Show()
		else
			holder.target:SetText("")
			holder.target:Hide()
		end
		local tc = cfg.showRaidMarker and sample.marker and RAID_MARKER_TEXCOORDS[sample.marker]
		if tc then
			holder.marker:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
			holder.marker:Show()
		else
			holder.marker:Hide()
		end
		AnchorName(holder, cfg, tc and true or false, hasTarget)
		if cfg.showSpellName ~= false then holder.name:SetText(sample.name) end
		holder.timer:SetText(cfg.showTimer ~= false and sample.timer or "")
		holder.sb:SetValue(sample.fill)
		if sample.uninterruptible then
			holder.overlay:SetAlpha(1)
		else
			holder.overlay:SetAlpha(0)
			local c = cfg.barColor
			if c then holder.sb:SetStatusBarColor(c.r, c.g, c.b) end
		end
		holder:Show()
	end
end

function P.TSB_SetPreview(on)
	previewOn = on == true
	if previewOn then
		ShowPreview()
	else
		ReleaseAll()
		SyncWhereActive()
	end
end

function P.TSB_IsPreview()
	return previewOn
end

function P.TSB_Refresh()
	local cfg = Cfg()
	SetWhereWatcherActive(cfg and cfg.enabled == true)
	SyncWhereActive()
	if not cfg then return end
	if container then
		container:SetSize(cfg.width or 240, cfg.height or 20)
		ApplyContainerPosition()
	end
	if cfg.enabled ~= true then
		previewOn = false
		ReleaseAll()
		return
	end
	if previewOn then
		ShowPreview()
		return
	end
	local maxBars = cfg.maxBars or 5
	for i = #shown, maxBars + 1, -1 do Release(shown[i]) end
	for i = 1, #shown do
		PaintEntry(shown[i], cfg)
		PositionBar(shown[i].bar, i, cfg)
	end
end

-------------------------------------------------------------------------------
--  Unlock Mode (retail key EMT_TargetedSpellBars)
-------------------------------------------------------------------------------
local function RegisterUnlock()
	if not (ns.RegisterUnlockElements and ns.MakeUnlockElement) then return end
	ns:RegisterUnlockElements({
		ns.MakeUnlockElement({
			key   = "EMT_TargetedSpellBars",
			label = "Targeted Spell Bars",
			group = "Mythic+",
			order = 521,
			noResize = true,
			allowMatchSource = true,
			isHidden = function()
				local cfg = Cfg()
				return not (cfg and cfg.enabled == true)
			end,
			getFrame = function() return EnsureContainer() end,
			getSize = function()
				local cfg = Cfg()
				return (cfg and cfg.width) or 240, (cfg and cfg.height) or 20
			end,
			setWidth = function(_, w)
				local cfg = Cfg()
				if not cfg then return end
				cfg.width = floor(w + 0.5)
				P.TSB_Refresh()
			end,
			setHeight = function(_, h)
				local cfg = Cfg()
				if not cfg then return end
				cfg.height = floor(h + 0.5)
				P.TSB_Refresh()
			end,
			savePos = function(_, _, _, x, y)
				local cfg = Cfg()
				if not (cfg and x and y) then return end
				cfg.pos = { centerX = x, centerY = y }
				if not ns._unlockActive then ApplyContainerPosition() end
			end,
			loadPos = function()
				local cfg = Cfg()
				local pos = cfg and cfg.pos
				if not (pos and pos.centerX and pos.centerY) then return nil end
				return { point = "CENTER", relPoint = "CENTER", x = pos.centerX, y = pos.centerY }
			end,
			clearPos = function()
				local cfg = Cfg()
				if cfg then cfg.pos = nil end
			end,
			applyPos = function() ApplyContainerPosition() end,
		}),
	}, addonName)
	if ns.RegisterUnlockModeListener then
		ns:RegisterUnlockModeListener("EMT_TargetedSpellBars", function(unlockActive)
			local cfg = Cfg()
			if not (cfg and cfg.enabled == true) then return end
			P.TSB_SetPreview(unlockActive == true)
			local anchored = ns.IsUnlockAnchored and ns.IsUnlockAnchored("EMT_TargetedSpellBars")
			if not anchored then ApplyContainerPosition() end
		end)
	end
end

function P.TSB_OnEnable(database)
	db = database
	if not db then return end
	RegisterUnlock()
	P.TSB_Refresh()
end
