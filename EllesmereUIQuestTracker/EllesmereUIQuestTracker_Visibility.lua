-------------------------------------------------------------------------------
-- EllesmereUIQuestTracker_Visibility.lua (5.4.8 port)
--
-- Retail: visibility checklist (Never / Always / Mouseover, Show / Hide
-- conditions), arena auto-hide, Hide When In Raid (Always / Boss Combat), our
-- own background behind the tracker with a 1px accent top line, and Force
-- Quest Tracker on Screen. Here for the WatchFrame.
--
-- Position: retail moves the tracker in Blizzard Edit Mode; 5.4.8 has none,
-- so the tracker gets an Unlock Mode mover. Like ElvUI MoP (WatchFrameHolder):
-- a holder frame of ours, the WatchFrame anchored to it and a SetPoint hook
-- that puts it back when UIParent_ManageFramePositions moves it. Nothing is
-- moved in combat (queued for PLAYER_REGEN_ENABLED). Only after the player
-- moved it once; until then Blizzard keeps placing it.
--
-- Challenge Mode: EllesmereUIChallengeTimer hides the WatchFrame during a run
-- (Show hook, alpha 0 in combat). While it does, this file leaves the
-- WatchFrame alone (no Show / Hide / alpha) and only hides its background.
-------------------------------------------------------------------------------
local addonName, P = ...
local ns = EllesmereUI
local EQT = P.EQT

local function WF() return _G.WatchFrame end

-------------------------------------------------------------------------------
-- Visibility checklist (retail EvalVisibility on the "visibility" key; same
-- lane keys as the other 5.4.8 ports). Dragonriding and Housing lanes skipped.
-------------------------------------------------------------------------------
local function InCombat()
	return (InCombatLockdown() or UnitAffectingCombat("player")) and true or false
end

EQT.VIS_AXES = {
	{ key = "in_combat", label = "In Combat", show = "in_combat", hide = "hide_in_combat", test = InCombat },
	{ key = "out_of_combat", label = "Out of Combat", show = "out_of_combat", hide = "hide_out_of_combat",
		test = function() return not InCombat() end },
	{ key = "in_raid", label = "In Raid Group", show = "in_raid", hide = "hide_in_raid",
		test = function() return IsInRaid() and true or false end },
	{ key = "in_party", label = "In Party", show = "in_party", hide = "hide_in_party",
		test = function() return (IsInGroup() and not IsInRaid()) and true or false end },
	{ key = "solo", label = "Solo", show = "solo", hide = "hide_solo",
		test = function() return not IsInGroup() end },
	{ key = "instances", label = "Instances", show = "visOnlyInstances", hide = "visHideInstances",
		test = function() local inside = IsInInstance() return inside and true or false end },
	{ key = "mounted", label = "Mounted", show = "visOnlyMounted", hide = "visHideMounted",
		test = function() return IsMounted() and true or false end },
	{ key = "target", label = "Target", show = "visHideNoTarget", hide = "visHideWithTarget",
		test = function() return UnitExists("target") and true or false end },
	{ key = "enemy", label = "Enemy Target", show = "visHideNoEnemy", hide = "visHideWithEnemy",
		test = function() return (UnitExists("target") and UnitCanAttack("player", "target")) and true or false end },
	{ key = "resting", label = "Resting", show = "visOnlyResting", hide = "visHideResting",
		test = function() return IsResting() and true or false end },
}

function EQT.VisFlag(s, key)
	if key:match("^vis") then
		return s[key] and true or false
	end
	local modes = s.visibilityModes
	if type(modes) == "table" and modes[key] then
		return true
	end
	-- Legacy scalar modes (visibility = "in_combat" ...) read as their Show lane.
	local vis = s.visibility
	if vis and vis ~= "always" and vis ~= "never" and vis ~= "mouseover" and vis == key then
		return true
	end
	return false
end

function EQT.SetVisFlag(s, key, on)
	if key:match("^vis") then
		s[key] = on and true or nil
		return
	end
	if type(s.visibilityModes) ~= "table" then s.visibilityModes = {} end
	s.visibilityModes[key] = on and true or nil
end

function EQT.VisBase(s)
	local vis = s and s.visibility or "always"
	if vis == "never" then
		return "never"
	elseif vis == "mouseover" then
		return "mouseover"
	end
	return "always"
end

function EQT.SetVisBase(s, mode)
	local old = s.visibility
	if old and old ~= "always" and old ~= "never" and old ~= "mouseover" then
		EQT.SetVisFlag(s, old, true)
	end
	s.visibility = mode
end

-- true = shown, false = hidden, "mouseover" = shown while hovered.
function EQT.EvalVisibility(s)
	if s.enabled == false then return false end
	local base = EQT.VisBase(s)
	if base == "never" then
		return false
	end
	local anyShow, allOk, anyOk = false, true, false
	for _, axis in ipairs(EQT.VIS_AXES) do
		local hideOn = EQT.VisFlag(s, axis.hide)
		local showOn = EQT.VisFlag(s, axis.show)
		if hideOn or showOn then
			local now = axis.test()
			if hideOn and now then
				return false
			end
			if showOn then
				anyShow = true
				if now then anyOk = true else allOk = false end
			end
		end
	end
	if anyShow then
		if s.visibilityMatch == "any" then
			if not anyOk then return false end
		elseif not allOk then
			return false
		end
	end
	if base == "mouseover" then
		return "mouseover"
	end
	return true
end

-------------------------------------------------------------------------------
-- Auto-hide: arenas always; raids per Hide When In Raid ("always" = whole
-- raid, "boss" = during ENCOUNTER_START .. ENCOUNTER_END).
-------------------------------------------------------------------------------
local inEncounter = false
local function ShouldAutoHide()
	local _, instanceType = GetInstanceInfo()
	if instanceType == "arena" then return true end
	if instanceType == "raid" then
		if EQT.Cfg("hideInRaidMode") == "always" then return true end
		return inEncounter
	end
	return false
end
EQT.ShouldAutoHide = ShouldAutoHide

-- Same rule as TrackerShouldBeHidden() in EllesmereUIChallengeTimer.lua.
local function ChallengeTimerOwnsTracker()
	local emt = ns.ChallengeTimer
	if not (emt and emt.DB and emt.currentRun) then return false end
	local root = emt.DB()
	if not (root and root.enabled) then return false end
	local run = emt.currentRun
	if run.active then return true end
	if run.completed then
		local _, iType = GetInstanceInfo()
		return iType == "party"
	end
	return false
end
EQT.ChallengeTimerOwnsTracker = ChallengeTimerOwnsTracker

-------------------------------------------------------------------------------
-- Background (our own UIParent frame, never a child of the WatchFrame)
-------------------------------------------------------------------------------
local bgFrame
local function EnsureBG()
	if bgFrame then return bgFrame end
	local wf = WF()
	if not wf then return nil end
	bgFrame = CreateFrame("Frame", "EllesmereUIQTBackground", UIParent)
	bgFrame:SetFrameStrata(wf:GetFrameStrata() or "LOW")
	bgFrame:SetFrameLevel(math.max(0, wf:GetFrameLevel() - 1))
	bgFrame:EnableMouse(false)
	local tex = bgFrame:CreateTexture(nil, "BACKGROUND")
	tex:SetAllPoints()
	bgFrame.tex = tex
	local line = bgFrame:CreateTexture(nil, "OVERLAY")
	line:SetPoint("TOPLEFT", bgFrame, "TOPLEFT", 0, 0)
	line:SetPoint("TOPRIGHT", bgFrame, "TOPRIGHT", 0, 0)
	bgFrame.line = line
	bgFrame:Hide()
	return bgFrame
end

-- Lowest shown line of the tracker (quests, achievements, timers, scenario).
local function LowestBottom()
	local low
	local function check(f)
		if f and f.IsVisible and f:IsVisible() then
			local b = f:GetBottom()
			if b and (not low or b < low) then low = b end
		end
	end
	for _, list in ipairs({ WATCHFRAME_QUESTLINES, WATCHFRAME_ACHIEVEMENTLINES, WATCHFRAME_TIMERLINES }) do
		if type(list) == "table" then
			for _, line in pairs(list) do check(line) end
		end
	end
	check(_G.WatchFrameScenarioFrame)
	return low
end

local function OnePixel(region)
	local es = region:GetEffectiveScale() or 1
	local perfect = ns.PP and ns.PP.perfect
	if not perfect or perfect <= 0 then perfect = 1 end
	return (es > 0) and (perfect / es) or 1
end

local function ResizeBG()
	local bg = bgFrame
	local wf = WF()
	if not (bg and wf) then return end
	local visible = wf:IsShown() and wf:GetAlpha() > 0 and not ShouldAutoHide() and not ChallengeTimerOwnsTracker()
	local header = _G.WatchFrameHeader
	local hasContent = header and header:IsShown()
	if not visible or not hasContent then
		bg:Hide()
		return
	end
	local top = wf:GetTop()
	local hideHeader = EQT.ShouldHideMasterHeader and EQT.ShouldHideMasterHeader()
	local anchor = hideHeader and _G.WatchFrameLines or wf
	local anchorTop = anchor and anchor:GetTop() or top
	local low = (not wf.collapsed) and LowestBottom() or nil
	if not low then
		low = (header:GetBottom() or (anchorTop or 0) - 20)
	end
	local height = (anchorTop or 0) - low + 6
	if height < 10 then height = 10 end
	bg:ClearAllPoints()
	bg:SetPoint("TOPLEFT", anchor, "TOPLEFT", -6, 0)
	bg:SetPoint("TOPRIGHT", wf, "TOPRIGHT", 11 - 24, 0)
	bg:SetHeight(height)
	bg:SetAlpha(wf:GetAlpha())
	bg:Show()
end
EQT.ResizeBGToContent = ResizeBG

function EQT.ApplyBackground()
	local bg = EnsureBG()
	if not bg then return end
	local c = EQT.DB()
	bg.tex:SetTexture(c.bgR or 0, c.bgG or 0, c.bgB or 0, c.bgAlpha or 0.5)
	if c.showTopLine == false then
		bg.line:Hide()
	else
		local r, g, b = EQT.GetAccent()
		bg.line:SetTexture(r, g, b, 1)
		bg.line:SetHeight(OnePixel(bg))
		bg.line:Show()
	end
	ResizeBG()
end

-------------------------------------------------------------------------------
-- Show / hide
-------------------------------------------------------------------------------
local hiddenByUs = false     -- we Hide() it for the arena / raid auto-hide
local moState = false        -- visibility = mouseover
local moFrame = CreateFrame("Frame")
moFrame:Hide()

local function SetTrackerAlpha(a)
	local wf = WF()
	if not wf then return end
	wf:SetAlpha(a)
	if bgFrame then bgFrame:SetAlpha(a) end
end

-- Mouseover: alpha 1 while the cursor is over the tracker.
local moElapsed = 0
moFrame:SetScript("OnUpdate", function(self, elapsed)
	moElapsed = moElapsed + elapsed
	if moElapsed < 0.1 then return end
	moElapsed = 0
	local wf = WF()
	if not wf or ChallengeTimerOwnsTracker() then return end
	local over = wf:IsShown() and wf:IsMouseOver()
	SetTrackerAlpha(over and 1 or 0)
end)

local function HardHide(wf)
	if InCombatLockdown() then
		wf:SetAlpha(0)
		P.Defer("QTHide", function() EQT.UpdateVisibility() end)
	else
		wf:SetAlpha(1)
		wf:Hide()
	end
end

local function UpdateVisibility()
	local wf = WF()
	if not wf then return end
	if ChallengeTimerOwnsTracker() then
		-- The Challenge Mode timer hides it; never fight that.
		moFrame:Hide()
		hiddenByUs = false
		if bgFrame then bgFrame:Hide() end
		return
	end
	if ShouldAutoHide() then
		moFrame:Hide()
		hiddenByUs = true
		HardHide(wf)
		if bgFrame then bgFrame:Hide() end
		return
	end
	if hiddenByUs then
		if InCombatLockdown() then
			P.Defer("QTHide", function() EQT.UpdateVisibility() end)
		else
			hiddenByUs = false
			wf:Show()
		end
	end
	local vis = EQT.EvalVisibility(EQT.DB())
	if ns._unlockActive then vis = true end
	if vis == "mouseover" then
		moState = true
		moFrame:Show()
		SetTrackerAlpha(wf:IsMouseOver() and 1 or 0)
	else
		moState = false
		moFrame:Hide()
		SetTrackerAlpha(vis and 1 or 0)
	end
	ResizeBG()
end
EQT.UpdateVisibility = UpdateVisibility
EQT.RefreshStateDriver = UpdateVisibility

-- Called after every WatchFrame_Update (see _Skin.lua).
function EQT.OnTrackerUpdate()
	ResizeBG()
end

-------------------------------------------------------------------------------
-- Force Quest Tracker on Screen (retail forceOnScreen)
-------------------------------------------------------------------------------
function EQT.ApplyForceOnScreen()
	local wf = WF()
	if not wf then return end
	local on = EQT.Cfg("forceOnScreen") ~= false
	P.Defer("QTClamp", function() wf:SetClampedToScreen(on) end)
end

-------------------------------------------------------------------------------
-- Position (Unlock Mode mover)
-------------------------------------------------------------------------------
local HOLDER_W, HOLDER_DEFAULT_H = 204, 480
local holder
local takenOver = false

-- ElvUI's own WatchFrame mover takes the same frame: leave it to ElvUI.
local function ElvUIMovesTracker()
	return _G.WatchFrameHolder ~= nil or _G.WatchFrameMover ~= nil
end

local function HolderSize()
	local pos = EQT.Cfg("pos")
	local w = (WATCHFRAME_EXPANDEDWIDTH or HOLDER_W)
	local h = (pos and pos.h) or HOLDER_DEFAULT_H
	return w, h
end

local function EnsureHolder()
	if holder then return holder end
	holder = CreateFrame("Frame", "EllesmereUIQuestTrackerHolder", UIParent)
	holder:SetSize(HolderSize())
	holder:SetClampedToScreen(true)
	return holder
end

local function AnchorTracker()
	local wf = WF()
	if not (wf and holder and takenOver) then return end
	if InCombatLockdown() then
		P.Defer("QTAnchor", AnchorTracker)
		return
	end
	local _, h = HolderSize()
	wf:ClearAllPoints()
	wf:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
	wf:SetHeight(h)
end

local hookDone = false
local function InstallSetPointHook()
	if hookDone then return end
	hookDone = true
	hooksecurefunc(WF(), "SetPoint", function(_, _, rel)
		if not takenOver or rel == holder then return end
		AnchorTracker()
	end)
end

function EQT.ApplyPosition()
	local wf = WF()
	if not wf or ElvUIMovesTracker() then return end
	local pos = EQT.Cfg("pos")
	EnsureHolder()
	holder:SetSize(HolderSize())
	if pos and pos.point then
		holder:ClearAllPoints()
		holder:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
		takenOver = true
		InstallSetPointHook()
		AnchorTracker()
		return
	end
	if takenOver then
		-- Position reset: give the tracker back first (it hangs on the holder).
		if InCombatLockdown() then
			P.Defer("QTPos", EQT.ApplyPosition)
			return
		end
		takenOver = false
		wf:ClearAllPoints()
		-- Blizzard's default spot (UIParent_ManageFramePositions refines it later).
		wf:SetPoint("TOPRIGHT", _G.MinimapCluster or UIParent, "BOTTOMRIGHT", -(CONTAINER_OFFSET_X or 0), 0)
		wf:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -(CONTAINER_OFFSET_X or 0), CONTAINER_OFFSET_Y or 70)
	end
	-- Not moved: the holder sits where Blizzard put the tracker.
	holder:ClearAllPoints()
	holder:SetPoint("TOPRIGHT", wf, "TOPRIGHT", 0, 0)
end

local function RegisterUnlock()
	if not (ns.RegisterUnlockElements and ns.MakeUnlockElement) then return end
	ns:RegisterUnlockElements({
		ns.MakeUnlockElement({
			key   = "EUI_QuestTracker",
			label = "Quest Tracker",
			group = "Quest Tracker",
			order = 1,
			noResize = true,
			isHidden = function() return ElvUIMovesTracker() end,
			getFrame = function() return EnsureHolder() end,
			getSize  = function() return HolderSize() end,
			savePos = function(_, point, relPoint, x, y)
				local _, h = HolderSize()
				EQT.Set("pos", { point = point, relPoint = relPoint, x = x, y = y, h = h })
			end,
			loadPos = function()
				local p = EQT.Cfg("pos")
				if not p then return nil end
				return { point = p.point, relPoint = p.relPoint, x = p.x, y = p.y }
			end,
			clearPos = function() EQT.Set("pos", nil) end,
			applyPos = function() EQT.ApplyPosition() end,
		}),
	}, addonName)
end

-------------------------------------------------------------------------------
-- Entry point
-------------------------------------------------------------------------------
local inited = false
function EQT.InitVisibility()
	local wf = WF()
	if inited or not wf then return end
	inited = true
	EnsureBG()
	-- Blizzard shows it again (zone change, scenario): re-check the auto-hide.
	hooksecurefunc(wf, "Show", function(self)
		if ChallengeTimerOwnsTracker() then return end
		if ShouldAutoHide() then HardHide(self) end
	end)
	wf:HookScript("OnHide", function() if bgFrame then bgFrame:Hide() end end)
	wf:HookScript("OnShow", function() ResizeBG() end)

	local evt = CreateFrame("Frame")
	for _, e in ipairs({
		"PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
		"GROUP_ROSTER_UPDATE", "PLAYER_TARGET_CHANGED", "PLAYER_UPDATE_RESTING", "COMPANION_UPDATE",
		"ENCOUNTER_START", "ENCOUNTER_END", "CHALLENGE_MODE_COMPLETED", "WORLD_STATE_TIMER_START",
		"WORLD_STATE_TIMER_STOP",
	}) do
		evt:RegisterEvent(e)
	end
	evt:SetScript("OnEvent", function(_, event)
		if event == "ENCOUNTER_START" then
			inEncounter = true
		elseif event == "ENCOUNTER_END" or event == "PLAYER_ENTERING_WORLD" then
			inEncounter = false
		end
		UpdateVisibility()
		if event == "CHALLENGE_MODE_COMPLETED" or event == "WORLD_STATE_TIMER_START" or event == "WORLD_STATE_TIMER_STOP"
			or event == "PLAYER_ENTERING_WORLD" then
			-- Again once the Challenge Mode timer has its run state (it checks 3s after a load).
			P.After(0.5, UpdateVisibility)
			P.After(3.5, UpdateVisibility)
		end
	end)
	RegisterUnlock()
end
