-- EllesmereUI Unit Frames for 5.4.8: spawning, events, preview and Unlock Mode.

local addonName = ...
local ns = EllesmereUI
local UF = ns.UF

local floor = math.floor

UF.frames = {}   -- unitKey -> frame
UF.layoutVersion = 0

local FRAME_NAMES = {
	player = "EllesmereUIUnitFrames_Player", target = "EllesmereUIUnitFrames_Target",
	focus = "EllesmereUIUnitFrames_Focus", pet = "EllesmereUIUnitFrames_Pet",
	targettarget = "EllesmereUIUnitFrames_TargetTarget", focustarget = "EllesmereUIUnitFrames_FocusTarget",
}
local SPAWN_ORDER = { "player", "target", "focus", "targettarget", "focustarget", "pet" }
local POLLED = { targettarget = true, focustarget = true }

-- Calls fn(frame); an error is reported but does not stop the caller.
local function Safe(fn, frame)
	xpcall(function() fn(frame) end, geterrorhandler())
end

local UNIT_EVENTS = {
	"UNIT_HEALTH", "UNIT_HEALTH_FREQUENT", "UNIT_MAXHEALTH", "UNIT_CONNECTION", "UNIT_FACTION",
	"UNIT_POWER", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE", "UNIT_LEVEL",
	"UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED", "UNIT_AURA", "UNIT_ABSORB_AMOUNT_CHANGED",
	"UNIT_HEAL_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_PREDICTION", "UNIT_THREAT_SITUATION_UPDATE",
	"UNIT_TARGET", "UNIT_CLASSIFICATION_CHANGED", "UNIT_FLAGS",
	"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
	"UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}

---------------------------------------------------------------------------
-- Events of one frame
---------------------------------------------------------------------------
local function OnUnitEvent(frame, event, unit, ...)
	if not frame:IsShown() then
		return
	end
	if event == "UNIT_HEALTH" or event == "UNIT_HEALTH_FREQUENT" or event == "UNIT_MAXHEALTH" then
		UF.UpdateHealth(frame)
		UF.UpdateTexts(frame)
		UF.UpdateAbsorbs(frame)
	elseif event == "UNIT_POWER" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
		UF.UpdatePower(frame)
		if frame.TextBar and frame.TextBar:IsShown() then
			UF.UpdateTexts(frame)
		end
		if frame.ClassPower and unit == "player" then
			UF.UpdateClassPower(frame)
		end
	elseif event == "UNIT_AURA" then
		if frame.Buffs then
			UF.UpdateAuras(frame)
		end
		if frame.unitKey == "player" then
			UF.UpdateDispelOverlay(frame)
			if frame.ClassPower then
				UF.UpdateClassPower(frame)
			end
		end
	elseif event == "UNIT_ABSORB_AMOUNT_CHANGED" or event == "UNIT_HEAL_ABSORB_AMOUNT_CHANGED" or event == "UNIT_HEAL_PREDICTION" then
		UF.UpdateAbsorbs(frame)
		UF.UpdateTexts(frame)
	elseif event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED" then
		if frame.Portrait.model then
			frame.Portrait.model.forceUpdate = true
		end
		UF.UpdatePortrait(frame)
	elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
		UF.CastStart(frame)
	elseif event == "UNIT_SPELLCAST_STOP" then
		UF.CastStop(frame, select(3, ...))
	elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
		UF.CastStop(frame, select(3, ...))
	elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		UF.CastStop(frame)
	elseif event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
		UF.CastDelayed(frame)
	elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
		UF.CastInterruptible(frame, false)
	elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
		UF.CastInterruptible(frame, true)
	elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
		UF.UpdateThreat(frame)
	elseif event == "UNIT_FLAGS" or event == "UNIT_FACTION" or event == "UNIT_CONNECTION" then
		UF.UpdateIndicators(frame)
		UF.UpdateHealth(frame)
		UF.UpdateTexts(frame)
	else
		UF.UpdateTexts(frame)
		UF.UpdateIndicators(frame)
	end
end

local function RegisterUnitEvents(frame)
	frame:UnregisterAllEvents()
	if POLLED[frame.unitKey] then
		return
	end
	local unit = frame.unit
	for _, event in ipairs(UNIT_EVENTS) do
		pcall(frame.RegisterUnitEvent, frame, event, unit)
	end
end

-- Player (and pet) show the vehicle while you are in one.
local function DisplayUnit(frame)
	if frame.unitKey == "player" and UnitHasVehicleUI("player") then
		return "vehicle"
	elseif frame.unitKey == "pet" and UnitHasVehicleUI("player") then
		return "player"
	end
	return frame.unitKey
end

function UF.RefreshUnit(frame)
	local unit = DisplayUnit(frame)
	if frame.unit ~= unit then
		frame.unit = unit
		RegisterUnitEvents(frame)
	end
	UF.UpdateAll(frame)
end

---------------------------------------------------------------------------
-- Positions
---------------------------------------------------------------------------
local function PositionKey(frame)
	return frame.isBoss and "boss" or frame.unitKey
end

function UF.ApplyPosition(frame)
	if InCombatLockdown() then
		UF.pendingReload = true
		return
	end
	local index = frame.isBoss and tonumber(frame.unitKey:match("%d")) or nil
	if index and index > 1 then
		frame:ClearAllPoints()
		local prev = UF.frames["boss" .. (index - 1)]
		-- EllesmereUI UF_BossSpacing: the size only; Stack Direction sets the sign.
		local spacing = math.abs(UF.db.bossSpacing or 80)
		if UF.db.boss.bossStackDirection == "up" then
			frame:SetPoint("BOTTOMLEFT", prev, "BOTTOMLEFT", 0, spacing)
		else
			frame:SetPoint("TOPLEFT", prev, "TOPLEFT", 0, -spacing)
		end
		return
	end
	-- Unlock Mode / unlock anchors own the spot (see UF.PlaceFree).
	UF.PlaceFree(frame, PositionKey(frame))
end

---------------------------------------------------------------------------
-- Spawning and enabling
---------------------------------------------------------------------------
local function Spawn(unitKey)
	local frame = UF.frames[unitKey]
	if frame then
		return frame
	end
	local name = FRAME_NAMES[unitKey] or ("EllesmereUIUnitFrames_Boss" .. unitKey:match("%d"))
	frame = UF.CreateUnitFrame(unitKey, name)
	frame:SetScript("OnEvent", OnUnitEvent)
	frame:HookScript("OnShow", function(self)
		UF.RefreshUnit(self)
	end)
	UF.frames[unitKey] = frame
	frame.unit = DisplayUnit(frame)
	RegisterUnitEvents(frame)
	return frame
end

-- Unit watch on (normal), off (disabled or "never") or preview (always shown).
local function ApplyWatch(frame)
	if InCombatLockdown() then
		UF.pendingReload = true
		return
	end
	local key = frame.settingsKey
	local s = UF.Settings(key)
	local enabled = UF.IsEnabled(key) and s.barVisibility ~= "never"
	if (frame.preview or frame.unlocked) and UF.IsEnabled(key) then
		if frame.watching then
			UnregisterUnitWatch(frame)
			frame.watching = false
		end
		frame:Show()
	elseif enabled then
		if not frame.watching then
			RegisterUnitWatch(frame)
			frame.watching = true
		end
	else
		if frame.watching then
			UnregisterUnitWatch(frame)
			frame.watching = false
		end
		frame:Hide()
	end
end

local function AllFrameKeys()
	local list = {}
	for _, key in ipairs(SPAWN_ORDER) do
		list[#list + 1] = key
	end
	for i = 1, UF.MAX_BOSS do
		list[#list + 1] = "boss" .. i
	end
	return list
end
UF.AllFrameKeys = AllFrameKeys

-- Creates the enabled frames and hides the matching Blizzard frames.
function UF.SpawnAll()
	if InCombatLockdown() then
		UF.pendingReload = true
		return
	end
	for _, key in ipairs(AllFrameKeys()) do
		local settingsKey = key:match("^boss%d$") and "boss" or key
		if UF.IsEnabled(settingsKey) then
			UF.HideBlizzard(settingsKey)
			Spawn(key)
		end
	end
end

-- Re-applies every setting (called by the settings window).
function UF.ReloadFrames()
	if not UF.db then
		return
	end
	if InCombatLockdown() then
		UF.pendingReload = true
		for _, frame in pairs(UF.frames) do
			UF.UpdateAll(frame)
		end
		return
	end
	UF.pendingReload = nil
	UF.layoutVersion = UF.layoutVersion + 1
	UF.SpawnAll()
	for _, key in ipairs(AllFrameKeys()) do
		local frame = UF.frames[key]
		if frame then
			-- Each step on its own: an error in one frame (or one step) must not
			-- stop the others; the error still goes to the error handler.
			Safe(UF.ApplyPosition, frame)
			Safe(UF.Layout, frame)
			Safe(ApplyWatch, frame)
		end
	end
end

---------------------------------------------------------------------------
-- Preview (settings open on the Unit Frames page / Unlock Mode)
---------------------------------------------------------------------------
local function ApplyPreviewFlags(onlyBoss)
	UF.previewAuras = (UF.previewOn or UF.bossPreview) and true or nil
	UF.previewIndicators = UF.previewOn and true or nil
	for _, frame in pairs(UF.frames) do
		if not onlyBoss or frame.isBoss then
			local wanted = UF.previewOn or (frame.isBoss and UF.bossPreview)
			frame.preview = wanted and UF.IsEnabled(frame.settingsKey) or nil
			ApplyWatch(frame)
			if frame:IsShown() then
				UF.Layout(frame)
			end
		end
	end
end

-- Shows every enabled frame with sample data (Unit Frames settings page).
function UF.SetPreview(on)
	if on and InCombatLockdown() then
		return
	end
	UF.previewOn = on and true or nil
	ApplyPreviewFlags(false)
end

function UF.IsBossPreview()
	return UF.bossPreview and true or false
end

-- "Activate Boss Preview" on the Boss Frames page.
function UF.SetBossPreview(on)
	if on and InCombatLockdown() then
		return
	end
	UF.bossPreview = on and true or nil
	ApplyPreviewFlags(true)
end

-- Settings header preview (retail UnitPreview_Options): one frame made by
-- the normal frame code, inside the settings window. It is not in UF.frames,
-- has no events and no clicks; UF.LayoutHeaderPreview redraws it. It shows
-- the real unit when it exists, else sample data (like the screen preview).
function UF.CreateHeaderPreview(unitKey, parent)
	local frame = UF.CreateUnitFrame(unitKey == "boss" and "boss1" or unitKey, nil)
	ClickCastFrames[frame] = nil
	frame:SetAttribute("unit", nil)
	frame:SetScript("OnEnter", nil)
	frame:SetScript("OnLeave", nil)
	frame:EnableMouse(false)
	frame:SetParent(parent)
	frame.preview = true
	frame.headerPreview = true
	-- Parts this unit has not: false, not nil (the test mock fills nil keys).
	for _, k in ipairs({ "Castbar", "ClassPower", "TextBar", "Buffs", "Debuffs" }) do
		if rawget(frame, k) == nil then
			rawset(frame, k, false)
		end
	end
	if frame.Castbar then
		frame.Castbar.headerOwner = frame
	end
	if frame.ClassPower then
		frame.ClassPower.headerOwner = frame
	end
	return frame
end

-- Frame and all child frames move to the strata of the parent (the settings
-- window), keeping their level order; Layout sets the screen strata.
local function Descendants(f, list)
	local kids = { f:GetChildren() }
	for i = 1, #kids do
		list[#list + 1] = kids[i]
		Descendants(kids[i], list)
	end
	return list
end

function UF.LayoutHeaderPreview(frame)
	frame.preview = true
	UF.Layout(frame)
	local parent = frame:GetParent()
	local strata = parent:GetFrameStrata()
	local base = parent:GetFrameLevel() + 2
	local list = Descendants(frame, {})
	local level0 = frame:GetFrameLevel()
	local offsets = {}
	for i = 1, #list do
		offsets[i] = math.max(1, list[i]:GetFrameLevel() - level0)
	end
	frame:SetFrameStrata(strata)
	frame:SetFrameLevel(base)
	for i = 1, #list do
		list[i]:SetFrameStrata(strata)
		list[i]:SetFrameLevel(base + offsets[i])
	end
	frame:SetAlpha(1)
end

-- Box of the visible preview parts (auras, cast bar, class resource stick out
-- of the frame), relative to the frame's TOPLEFT, in frame units:
-- left, top (up is positive), width, height. nil when not laid out yet.
function UF.HeaderPreviewBounds(frame)
	if not frame.GetRect then
		return nil
	end
	local fl, fb, fw, fh = frame:GetRect()
	if not fl then
		return nil
	end
	local L, B, R, T = fl, fb, fl + fw, fb + fh
	local list = Descendants(frame, {})
	for i = 1, #list do
		local f = list[i]
		if f:IsShown() and f:GetAlpha() > 0 then
			local l, b, w, h = f:GetRect()
			if l and w > 2 and h > 2 then
				L, B = math.min(L, l), math.min(B, b)
				R, T = math.max(R, l + w), math.max(T, b + h)
			end
		end
	end
	return L - fl, T - (fb + fh), R - L, T - B
end

---------------------------------------------------------------------------
-- Unlock Mode (EllesmereUI core, retail EUI_UnitFrames_Unlock.lua): one
-- element per frame, plus the detached player cast bar and class resource.
-- Positions are CENTER offsets from the UIParent center (UF.db.positions).
---------------------------------------------------------------------------
local UNIT_LABELS = {
	player = "Player", target = "Target", focus = "Focus",
	pet = "Pet", targettarget = "Target of Target",
	focustarget = "Focus Target", boss = "Boss Frames",
	classPower = "Class Resource",
	playerCastbar = "Player Cast Bar",
}

local function Snap(v)
	local PP = ns.PP
	return PP and PP.Snap(v) or floor(v + 0.5)
end

local function FrameOf(key)
	if key == "boss" then
		return UF.frames.boss1
	elseif key == "playerCastbar" then
		return UF.frames.player and UF.frames.player.Castbar
	elseif key == "classPower" then
		return UF.frames.player and UF.frames.player.ClassPower
	end
	return UF.frames[key]
end

local function LoadPos(key)
	local p = UF.db.positions[key]
	if not p then
		return nil
	end
	return { point = p.point, relPoint = p.relPoint or p.point, x = p.x, y = p.y }
end

-- Puts one element's frame(s) at the saved spot (no relayout).
local function ApplyPos(key)
	if InCombatLockdown() then
		UF.pendingReload = true
		return
	end
	if key == "playerCastbar" or key == "classPower" then
		local region = FrameOf(key)
		if region and region._eufFree then
			UF.PlaceFree(region, key)
		end
		return
	end
	local frame = FrameOf(key)
	if frame then
		UF.ApplyPosition(frame)
	end
	if key == "boss" then
		for i = 2, UF.MAX_BOSS do
			local f = UF.frames["boss" .. i]
			if f then
				UF.ApplyPosition(f)
			end
		end
	end
end

-- Unlock Mode stores; outside it the frames follow at once.
local function SavePos(key, point, relPoint, x, y)
	local p = UF.db.positions[key]
	if not p then
		p = {}
		UF.db.positions[key] = p
	end
	p.point, p.relPoint, p.x, p.y = point, relPoint or point, x, y
	if not ns._unlockActive then
		ApplyPos(key)
	end
end

local function ClearPos(key)
	UF.db.positions[key] = UF.DefaultPosition(key)
end

local function MakeFrameElement(key, order)
	local settingsKey = key
	return ns.MakeUnlockElement({
		key = key,
		label = UNIT_LABELS[key],
		group = "Unit Frames",
		order = 100 + order,
		-- Visibility "never" keeps the frame built but never on screen.
		isHidden = function()
			local s = UF.Settings(settingsKey)
			return not UF.IsEnabled(settingsKey) or not s or s.barVisibility == "never"
		end,
		getFrame = function() return FrameOf(key) end,
		getSize = function()
			local f = FrameOf(key)
			if f then
				local w, h = UF.FrameSize(f)
				return w, h
			end
			local s = UF.Settings(settingsKey)
			return (s and s.frameWidth) or 181, (s and s.healthHeight) or 46
		end,
		setWidth = function(_, w)
			local f = FrameOf(key)
			local s = UF.Settings(settingsKey)
			if not (f and s and w) then return end
			local _, _, _, portraitW = UF.FrameSize(f)
			s.frameWidth = math.max(Snap(w - (portraitW or 0)), 50)
			UF.ReloadFrames()
		end,
		setHeight = function(_, h)
			local f = FrameOf(key)
			local s = UF.Settings(settingsKey)
			if not (f and s and h) then return end
			local _, total = UF.FrameSize(f)
			local extra = (total or 0) - (s.healthHeight or 46)
			s.healthHeight = math.max(Snap(h - extra), 8)
			UF.ReloadFrames()
		end,
		loadPos = LoadPos,
		savePos = SavePos,
		clearPos = ClearPos,
		applyPos = ApplyPos,
	})
end

-- Detached player cast bar / class resource: shown only while unlocked from
-- the player frame.
local function MakeDetachedElement(key, order, isOn, sizeKeys)
	return ns.MakeUnlockElement({
		key = key,
		label = UNIT_LABELS[key],
		group = "Unit Frames",
		order = 100 + order,
		noResize = not sizeKeys or nil,
		isHidden = function()
			return not UF.IsEnabled("player") or not isOn()
		end,
		getFrame = function() return FrameOf(key) end,
		getSize = function()
			if sizeKeys then
				local s = UF.db.player
				return s[sizeKeys[1]] or 181, s[sizeKeys[2]] or 14
			end
			local f = FrameOf(key)
			if f then
				return math.max(f:GetWidth(), 10), math.max(f:GetHeight(), 5)
			end
			return 120, 14
		end,
		setWidth = sizeKeys and function(_, w)
			UF.db.player[sizeKeys[1]] = math.max(Snap(w), 30)
			UF.ReloadFrames()
		end or nil,
		setHeight = sizeKeys and function(_, h)
			UF.db.player[sizeKeys[2]] = math.max(Snap(h), 5)
			UF.ReloadFrames()
		end or nil,
		loadPos = LoadPos,
		savePos = SavePos,
		clearPos = ClearPos,
		applyPos = ApplyPos,
	})
end

-- Places a frame kept free of its unit frame (player cast bar, class
-- resource) or a unit frame itself at its saved spot. While Unlock Mode is
-- open the movers own the spot; an unlock anchor (Anchor in Unlock Mode) owns
-- it afterwards.
function UF.PlaceFree(region, key)
	-- Settings header preview: detached parts sit under the preview frame.
	local owner = region.headerOwner
	if owner then
		region._eufFree = nil
		region:ClearAllPoints()
		local below = owner
		if key == "classPower" and owner.Castbar and owner.Castbar:IsShown() then
			below = owner.Castbar
		end
		region:SetPoint("TOP", below, "BOTTOM", 0, -6)
		return
	end
	if ns._unlockActive and region._eufFree and region:GetNumPoints() > 0 then
		return
	end
	region._eufFree = true
	local pos = UF.db.positions[key] or UF.DefaultPosition(key)
	region:ClearAllPoints()
	region:SetPoint(pos.point or "CENTER", UIParent, pos.relPoint or pos.point or "CENTER", pos.x or 0, pos.y or 0)
	if not ns._unlockActive and ns.IsUnlockAnchored and ns.IsUnlockAnchored(key) and ns.ReapplyOwnAnchor then
		ns.ReapplyOwnAnchor(key)
	end
end

-- The frames show (with sample data) while Unlock Mode is open.
local function SetUnlocked(on)
	if not UF.db then
		return
	end
	UF.unlockActive = on and true or nil
	if InCombatLockdown() then
		UF.pendingReload = true
		return
	end
	for _, frame in pairs(UF.frames) do
		frame.unlocked = (on and UF.IsEnabled(frame.settingsKey)) and true or nil
	end
	UF.ReloadFrames()
end

local function RegisterUnlock()
	if not ns.RegisterUnlockElements then
		return
	end
	local elements = {}
	local keys = { "player", "target", "focus", "pet", "targettarget", "focustarget" }
	for i, key in ipairs(keys) do
		elements[#elements + 1] = MakeFrameElement(key, i)
	end
	local boss = MakeFrameElement("boss", 7)
	-- A stack of frames: no resize or size matching, nothing anchors to it.
	boss.noResize = true
	boss.noAnchorTarget = true
	boss.setWidth, boss.setHeight = nil, nil
	elements[#elements + 1] = boss
	elements[#elements + 1] = MakeDetachedElement("classPower", 9, function()
		local s = UF.db.player
		return s.classPowerStyle == "modern" and s.lockClassPowerToFrame == false
			and (s.classPowerPosition or "top") ~= "above"
	end)
	elements[#elements + 1] = MakeDetachedElement("playerCastbar", 10, function()
		local s = UF.db.player
		return s.showPlayerCastbar and s.lockCastbarToFrame == false
	end, { "playerCastbarWidth", "playerCastbarHeight" })
	ns:RegisterUnlockElements(elements, "EllesmereUIUnitFrames")
	ns:RegisterUnlockModeListener("EllesmereUIUnitFrames", SetUnlocked)
end
UF.RegisterUnlock = RegisterUnlock

---------------------------------------------------------------------------
-- Global events and the shared ticker
---------------------------------------------------------------------------
local driver = CreateFrame("Frame")

local function Each(fn)
	for _, frame in pairs(UF.frames) do
		if frame:IsShown() then
			fn(frame)
		end
	end
end

local function RefreshKey(key)
	local frame = UF.frames[key]
	if frame and frame:IsShown() then
		UF.RefreshUnit(frame)
	end
end

local ticker = 0
driver:SetScript("OnUpdate", function(self, elapsed)
	ticker = ticker + elapsed
	if ticker < 0.2 then
		return
	end
	ticker = 0
	for key in pairs(POLLED) do
		local frame = UF.frames[key]
		if frame and frame:IsShown() then
			UF.UpdateAll(frame)
		end
	end
	for _, frame in pairs(UF.frames) do
		if frame:IsShown() then
			UF.UpdateAlpha(frame)
			if frame.isBoss then
				UF.UpdateRange(frame)
			elseif frame.unitKey == "target" or frame.unitKey == "focus" then
				UF.UpdateThreat(frame)
			end
		end
	end
end)
driver:Hide()

driver:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= addonName then
			return
		end
		self:UnregisterEvent("ADDON_LOADED")
		UF.InitDB()
		return
	end
	if not UF.db then
		return
	end
	if event == "PLAYER_LOGIN" then
		UF.RefreshKickSpell()
		UF.ReloadFrames()
		RegisterUnlock()
		self:Show()
	elseif event == "PLAYER_ENTERING_WORLD" then
		Each(UF.RefreshUnit)
	elseif event == "PLAYER_TARGET_CHANGED" then
		RefreshKey("target")
		RefreshKey("targettarget")
		local player = UF.frames.player
		if player and player.ClassPower then
			UF.UpdateClassPower(player)
		end
		for i = 1, UF.MAX_BOSS do
			local f = UF.frames["boss" .. i]
			if f and f:IsShown() then
				UF.UpdateBorderColor(f)
			end
		end
		Each(UF.UpdateAlpha)
	elseif event == "PLAYER_FOCUS_CHANGED" then
		RefreshKey("focus")
		RefreshKey("focustarget")
	elseif event == "UNIT_PET" then
		if arg1 == "player" then
			RefreshKey("pet")
		end
	elseif event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
		if arg1 == "player" then
			RefreshKey("player")
			RefreshKey("pet")
		end
	elseif event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" or event == "UNIT_TARGETABLE_CHANGED" then
		for i = 1, UF.MAX_BOSS do
			RefreshKey("boss" .. i)
		end
	elseif event == "RAID_TARGET_UPDATE" or event == "GROUP_ROSTER_UPDATE" or event == "PARTY_LEADER_CHANGED" then
		Each(UF.UpdateIndicators)
		Each(UF.UpdateTexts)
	elseif event == "PLAYER_REGEN_DISABLED" then
		-- Leave preview / unlock before combat lockdown starts.
		if UF.previewOn or UF.bossPreview then
			UF.SetPreview(false)
			UF.SetBossPreview(false)
		end
		Each(UF.UpdateIndicators)
		Each(UF.UpdateAlpha)
	elseif event == "PLAYER_REGEN_ENABLED" then
		if UF.pendingReload then
			UF.ReloadFrames()
		end
		Each(UF.UpdateIndicators)
		Each(UF.UpdateAlpha)
	elseif event == "UNIT_COMBO_POINTS" or event == "RUNE_POWER_UPDATE" or event == "RUNE_TYPE_UPDATE"
		or event == "ECLIPSE_DIRECTION_CHANGE" then
		local player = UF.frames.player
		if player and player.ClassPower then
			UF.UpdateClassPower(player)
		end
	elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_TALENT_UPDATE"
		or event == "UPDATE_SHAPESHIFT_FORM" or event == "SPELLS_CHANGED" then
		UF.RefreshKickSpell()
		local player = UF.frames.player
		if player and not InCombatLockdown() then
			UF.Layout(player)
		elseif player and player.ClassPower then
			UF.UpdateClassPower(player)
		end
	elseif event == "PLAYER_UPDATE_RESTING" or event == "ZONE_CHANGED_NEW_AREA" then
		Each(UF.UpdateAlpha)
		Each(UF.UpdateIndicators)
	end
end)

for _, event in ipairs({
	"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
	"UNIT_PET", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "INSTANCE_ENCOUNTER_ENGAGE_UNIT",
	"UNIT_TARGETABLE_CHANGED", "RAID_TARGET_UPDATE", "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED",
	"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UNIT_COMBO_POINTS", "RUNE_POWER_UPDATE",
	"RUNE_TYPE_UPDATE", "ECLIPSE_DIRECTION_CHANGE", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_TALENT_UPDATE",
	"UPDATE_SHAPESHIFT_FORM", "SPELLS_CHANGED", "PLAYER_UPDATE_RESTING", "ZONE_CHANGED_NEW_AREA",
}) do
	pcall(driver.RegisterEvent, driver, event)
end

---------------------------------------------------------------------------
-- API for the settings window
---------------------------------------------------------------------------
ns.GetUnitFramesDB = function() return UF.db end

ns.ResetUnitFrameSettings = function()
	local keep = UF.DeepCopy(UF.db.positions)
	-- Player Aura Bars keep their own setup (they have no Reset of their own).
	local pab = UF.db.playerAuraBars
	wipe(UF.db)
	UF.InitDB()
	UF.db.positions = keep
	UF.db.playerAuraBars = pab
	UF.ReloadFrames()
end

ns.applyHooks = ns.applyHooks or {}
tinsert(ns.applyHooks, function()
	if UF.db then
		UF.ReloadFrames()
	end
end)
