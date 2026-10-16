-------------------------------------------------------------------------------
--  EUI_MythicTimer_TargetFocusBars.lua (5.4.8 port)
--  Target/Focus Bars (Mythic+ Tools): standalone cast bars for the target
--  and focus units, placeable in Unlock Mode, with the nameplate cast
--  colors: interrupt-on-cooldown tint, uninterruptible wash + shield, the
--  kick tick / kick-ready window, and the interrupted flash.
--
--  5.4.8: the bars run on UnitCastingInfo / UnitChannelInfo (start/end in
--  ms) with an OnUpdate fill, the spell target is "<unit>target", and the
--  important-cast flag does not exist (Important Cast Color is skipped).
--  Nothing is registered or built while both bars are off.
-------------------------------------------------------------------------------
local addonName, P = ...
local ns = EllesmereUI

local floor, max, min = math.floor, math.max, math.min
local WHITE = P.WHITE
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

local db

local function TF()
	local p = db and db.profile
	return p and p.tfb
end

local function BarCfg(which)
	local tf = TF()
	return tf and tf[which]
end

local bars = {}
local active = false
local previewOn = { target = false, focus = false }

local DEFAULT_POS = {
	target = { x = 0, y = -240 },
	focus  = { x = 0, y = -310 },
}

local function ApplyBarPosition(bar)
	if not bar then return end
	local cfg = BarCfg(bar.which)
	local pos = cfg and cfg.pos
	bar.frame:ClearAllPoints()
	if pos and pos.centerX and pos.centerY then
		bar.frame:SetPoint("CENTER", UIParent, "CENTER", pos.centerX, pos.centerY)
	else
		local d = DEFAULT_POS[bar.which]
		bar.frame:SetPoint("CENTER", UIParent, "CENTER", d.x, d.y)
	end
end

-------------------------------------------------------------------------------
--  Build
-------------------------------------------------------------------------------
local UpdateFill

local function BuildBar(which)
	local holder = CreateFrame("Frame", nil, UIParent)
	holder:SetFrameStrata("MEDIUM")
	holder:Hide()
	local bar = { which = which, unit = which, frame = holder }

	bar.bg = holder:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetAllPoints(holder)
	bar.bg:SetTexture(0, 0, 0, 0.45)

	bar.iconFrame = CreateFrame("Frame", nil, holder)
	bar.iconFrame:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
	bar.iconFrame:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
	bar.icon = bar.iconFrame:CreateTexture(nil, "ARTWORK")
	bar.icon:SetAllPoints(bar.iconFrame)
	bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	bar.sb = CreateFrame("StatusBar", nil, holder)
	bar.sb:SetStatusBarTexture(WHITE)
	bar.sb:SetPoint("TOPLEFT", bar.iconFrame, "TOPRIGHT", 0, 0)
	bar.sb:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 0)
	bar.sb:SetMinMaxValues(0, 1)
	bar.sb:SetValue(0)

	-- Uninterruptible wash over the fill.
	bar.overlay = bar.sb:CreateTexture(nil, "ARTWORK", nil, 2)
	bar.overlay:SetTexture(WHITE)
	bar.overlay:SetAllPoints(bar.sb:GetStatusBarTexture())
	bar.overlay:SetAlpha(0)

	-- Interrupted flash over the whole bar.
	bar.flash = bar.sb:CreateTexture(nil, "ARTWORK", nil, 3)
	bar.flash:SetAllPoints(bar.sb)
	bar.flash:SetTexture(WHITE)
	bar.flash:Hide()

	bar.spark = bar.sb:CreateTexture(nil, "OVERLAY", nil, 1)
	bar.spark:SetTexture(P.MEDIA .. "cast_spark")
	bar.spark:SetBlendMode("ADD")

	bar.shieldFrame = CreateFrame("Frame", nil, holder)
	bar.shieldFrame:SetPoint("CENTER", holder, "LEFT", 0, 0)
	bar.shieldFrame:SetFrameLevel(holder:GetFrameLevel() + 5)
	bar.shield = bar.shieldFrame:CreateTexture(nil, "OVERLAY")
	bar.shield:SetAllPoints()
	bar.shield:SetTexture(P.MEDIA .. "shield")
	bar.shieldFrame:SetAlpha(0)

	-- Kick tick + kick-ready window (retail kick clip; plain textures here).
	bar.kickReadyFill = bar.sb:CreateTexture(nil, "ARTWORK", nil, 1)
	bar.kickReadyFill:SetTexture(WHITE)
	bar.kickReadyFill:Hide()
	bar.kickTick = bar.sb:CreateTexture(nil, "OVERLAY", nil, 3)
	bar.kickTick:SetTexture(WHITE)
	bar.kickTick:SetWidth(2)
	bar.kickTick:Hide()

	bar.textFrame = CreateFrame("Frame", nil, bar.sb)
	bar.textFrame:SetAllPoints(bar.sb)
	bar.textFrame:SetFrameLevel(bar.sb:GetFrameLevel() + 6)
	bar.name = bar.textFrame:CreateFontString(nil, "OVERLAY")
	P.SetFS(bar.name, 11)
	bar.name:SetJustifyH("LEFT")
	bar.name:SetWordWrap(false)
	bar.target = bar.textFrame:CreateFontString(nil, "OVERLAY")
	P.SetFS(bar.target, 10)
	bar.target:SetJustifyH("RIGHT")
	bar.target:SetWordWrap(false)
	bar.timer = bar.textFrame:CreateFontString(nil, "OVERLAY")
	P.SetFS(bar.timer, 11)
	bar.timer:SetJustifyH("RIGHT")
	bar.timer:SetWordWrap(false)

	holder:SetScript("OnUpdate", function(_, elapsed)
		bar._acc = (bar._acc or 0) + elapsed
		if bar.isCasting then UpdateFill(bar) end
	end)

	bars[which] = bar
	ApplyBarPosition(bar)
	return bar
end

local function StyleBar(bar)
	local cfg = BarCfg(bar.which)
	local tf = TF()
	if not (cfg and tf) then return end
	local w = cfg.width or 260
	local h = cfg.height or 22
	bar.frame:SetSize(w, h)

	local showIcon = cfg.showIcon ~= false
	bar.iconFrame:SetWidth(showIcon and h or 0.001)
	bar.iconFrame:SetShown(showIcon)

	bar.sb:SetStatusBarTexture(P.TexturePath(cfg.texture) or WHITE)
	bar.overlay:ClearAllPoints()
	bar.overlay:SetAllPoints(bar.sb:GetStatusBarTexture())
	bar.spark:ClearAllPoints()
	bar.spark:SetPoint("CENTER", bar.sb:GetStatusBarTexture(), "RIGHT", 0, 0)
	bar.spark:SetSize(8, h)
	bar.spark:SetShown(tf.showSpark ~= false)

	local un = tf.uninterruptible or { r = 0.45, g = 0.45, b = 0.45 }
	bar.overlay:SetVertexColor(un.r, un.g, un.b)
	local fl = tf.interruptedColor or { r = 0.8, g = 0, b = 0 }
	bar.flash:SetVertexColor(fl.r, fl.g, fl.b, 0.85)
	local kc = tf.kickTickColor or { r = 1, g = 1, b = 1 }
	bar.kickTick:SetVertexColor(kc.r, kc.g, kc.b, 1)
	bar.kickTick:SetHeight(h)
	local mc = tf.midCastColor or { r = 0.318, g = 0.820, b = 0.357 }
	bar.kickReadyFill:SetVertexColor(mc.r, mc.g, mc.b, 1)

	local shieldH = h * 0.75
	bar.shieldFrame:SetSize(shieldH * (29 / 35), shieldH)
	P.ApplyEdges(bar, "_edges", bar.frame, bar.frame, 1, 0, 0, 0, 1, true)

	P.SetFS(bar.name, cfg.nameSize or 11)
	P.SetFS(bar.target, cfg.targetSize or 10)
	P.SetFS(bar.timer, cfg.timerSize or 11)

	local showTimer = cfg.showTimer ~= false
	local reserve = showTimer and ((cfg.timerSize or 11) * 2.2) or 0
	bar.name:ClearAllPoints()
	bar.name:SetPoint("LEFT", bar.sb, "LEFT", 4, 0)
	bar.name:SetWidth((w - h) * 0.48)
	bar.timer:ClearAllPoints()
	bar.timer:SetPoint("RIGHT", bar.sb, "RIGHT", -3, 0)
	bar.target:ClearAllPoints()
	bar.target:SetPoint("RIGHT", bar.sb, "RIGHT", -3 - reserve, 0)
	bar.target:SetWidth((w - h) * 0.40)
	bar.name:SetShown(cfg.showSpellName ~= false)
	bar.timer:SetShown(showTimer)
end

-------------------------------------------------------------------------------
--  Colors: kick ready = cast color, kick on cooldown = "Interrupt on CD"
-------------------------------------------------------------------------------
local function ApplyCastColor(bar)
	local tf = TF()
	if not tf then return end
	local base = tf.castColor or { r = 0.70, g = 0.40, b = 0.90 }
	local r, g, b = base.r, base.g, base.b
	local left = P.KickRemaining()
	if left and left > 0 and not bar.notInterruptible then
		local c = tf.interruptReady or { r = 0.92, g = 0.35, b = 0.20 }
		r, g, b = c.r, c.g, c.b
	end
	bar.sb:SetStatusBarColor(r, g, b)
	local un = bar.notInterruptible and 1 or 0
	bar.overlay:SetAlpha(un)
	bar.shieldFrame:SetAlpha((tf.showShield ~= false) and un or 0)
end

-- Kick tick at the moment the interrupt comes back; "Tick + Bar" also
-- colors the window from there to the end of the cast.
local function UpdateKickTick(bar, now)
	local tf = TF()
	local tickOn = tf and tf.kickTickEnabled ~= false
	local midOn = tf and tf.midCastEnabled == true
	local left = P.KickRemaining()
	if not (tickOn or midOn) or bar.notInterruptible or not left or left <= 0
		or not bar.endTime or now + left >= bar.endTime then
		bar.kickTick:Hide()
		bar.kickReadyFill:Hide()
		return
	end
	local dur = bar.endTime - bar.startTime
	if dur <= 0 then return end
	local w = bar.sb:GetWidth()
	local frac
	if bar.isChannel then
		frac = (bar.endTime - (now + left)) / dur
	else
		frac = (now + left - bar.startTime) / dur
	end
	frac = max(0, min(1, frac))
	local x = w * frac
	bar.kickTick:ClearAllPoints()
	bar.kickTick:SetPoint("CENTER", bar.sb, "LEFT", x, 0)
	bar.kickTick:SetShown(tickOn)
	bar.kickReadyFill:ClearAllPoints()
	bar.kickReadyFill:SetPoint("TOP", bar.sb, "TOP", 0, 0)
	bar.kickReadyFill:SetPoint("BOTTOM", bar.sb, "BOTTOM", 0, 0)
	if bar.isChannel then
		bar.kickReadyFill:SetPoint("LEFT", bar.sb, "LEFT", 0, 0)
		bar.kickReadyFill:SetWidth(max(1, x))
	else
		bar.kickReadyFill:SetPoint("LEFT", bar.sb, "LEFT", x, 0)
		bar.kickReadyFill:SetWidth(max(1, w - x))
	end
	bar.kickReadyFill:SetShown(midOn)
end

UpdateFill = function(bar)
	local now = GetTime()
	if not bar.endTime then return end
	if now >= bar.endTime + 0.05 then
		bar.isCasting = false
		bar.timer:SetText("")
		if not bar._interrupted then bar.frame:Hide() end
		return
	end
	local dur = bar.endTime - bar.startTime
	local v
	if bar.isChannel then
		v = (bar.endTime - now) / max(0.001, dur)
	else
		v = (now - bar.startTime) / max(0.001, dur)
	end
	bar.sb:SetValue(max(0, min(1, v)))
	if bar._acc and bar._acc >= 0.1 then
		bar._acc = 0
		local cfg = BarCfg(bar.which)
		if cfg and cfg.showTimer ~= false then
			bar.timer:SetFormattedText("%.1f", max(0, bar.endTime - now))
		end
		ApplyCastColor(bar)
		UpdateKickTick(bar, now)
	end
end

-------------------------------------------------------------------------------
--  Spell target: "<unit>target" (5.4.8 has no spell target API)
-------------------------------------------------------------------------------
local function SizeNameForTarget(bar, hasTarget)
	local cfg = BarCfg(bar.which)
	if not cfg then return end
	local w = cfg.width or 260
	local h = cfg.height or 22
	local reserve = (cfg.showTimer ~= false) and ((cfg.timerSize or 11) * 2.2) or 0
	local shared = (w - h) * 0.48
	bar.name:SetWidth(hasTarget and shared or max(shared, (w - h) - 8 - reserve))
end

local function ShowsTarget(tf, which)
	local cfg = BarCfg(which)
	local v = cfg and cfg.showTarget
	if v == nil then v = tf.showTarget end
	return v ~= false
end

local function PaintTarget(bar)
	local tf = TF()
	local fs = bar.target
	local tu = bar.unit .. "target"
	if not tf or not ShowsTarget(tf, bar.which) or not UnitExists(tu) or UnitIsUnit(tu, bar.unit) then
		fs:SetText("")
		fs:Hide()
		SizeNameForTarget(bar, false)
		return
	end
	if tf.targetClassColor ~= false and UnitIsPlayer(tu) then
		local _, cls = UnitClass(tu)
		fs:SetTextColor(P.ClassColor(cls))
	else
		local tc = tf.targetColor
		if tc then fs:SetTextColor(tc.r, tc.g, tc.b, 1) else fs:SetTextColor(1, 1, 1, 1) end
	end
	fs:SetText(UnitName(tu) or "")
	fs:Show()
	SizeNameForTarget(bar, true)
end

-------------------------------------------------------------------------------
--  Cast state
-------------------------------------------------------------------------------
local function TeardownCast(bar)
	if bar.isCasting then bar._stoppedAt = GetTime() end
	bar.isCasting = false
	bar.endTime = nil
	bar.kickTick:Hide()
	bar.kickReadyFill:Hide()
	bar.timer:SetText("")
	if not bar._interrupted then
		bar.frame:Hide()
		bar.flash:Hide()
	end
end

local function UpdateCast(bar)
	if previewOn[bar.which] then return end
	local cfg = BarCfg(bar.which)
	if not (cfg and cfg.enabled == true) then
		TeardownCast(bar)
		bar._interrupted = nil
		bar.frame:Hide()
		return
	end
	if not UnitExists(bar.unit) then
		TeardownCast(bar)
		return
	end
	-- UnitCastingInfo: name, subText, text, texture, startMS, endMS, isTradeSkill, castID, notInterruptible
	-- UnitChannelInfo: name, subText, text, texture, startMS, endMS, isTradeSkill, notInterruptible
	local isChannel = false
	local name, _, _, texture, startMS, endMS, _, _, notInterruptible = UnitCastingInfo(bar.unit)
	if not name then
		name, _, _, texture, startMS, endMS, _, notInterruptible = UnitChannelInfo(bar.unit)
		isChannel = true
	end
	if not name or not startMS or not endMS then
		TeardownCast(bar)
		return
	end
	if bar._interrupted then
		bar._interrupted = nil
		bar.flash:Hide()
		if bar._interruptTimer then bar._interruptTimer:Cancel(); bar._interruptTimer = nil end
	end
	StyleBar(bar)
	bar.isChannel = isChannel
	bar.startTime = startMS / 1000
	bar.endTime = endMS / 1000
	bar.notInterruptible = notInterruptible and true or false
	bar.isCasting = true
	bar._acc = 1
	bar.flash:Hide()
	if cfg.showIcon ~= false then bar.icon:SetTexture(texture or QUESTION) end
	if cfg.showSpellName ~= false then bar.name:SetText(name) end
	PaintTarget(bar)
	ApplyCastColor(bar)
	UpdateFill(bar)
	bar.frame:Show()
end

local function ShowInterruptedFlash(bar)
	local tf = TF()
	if not tf or tf.interruptedFlash == false then return end
	local cfg = BarCfg(bar.which)
	if not (cfg and cfg.enabled == true) then return end
	if bar.notInterruptible then return end
	bar._interrupted = true
	bar.isCasting = false
	bar.kickTick:Hide()
	bar.kickReadyFill:Hide()
	bar.flash:Show()
	bar.name:SetText("Interrupted")
	bar.target:SetText("")
	bar.target:Hide()
	bar.timer:SetText("")
	bar.frame:Show()
	if bar._interruptTimer then bar._interruptTimer:Cancel() end
	bar._interruptTimer = P.Timer.NewTimer(1.0, function()
		bar._interruptTimer = nil
		bar._interrupted = nil
		bar.flash:Hide()
		if not bar.isCasting then bar.frame:Hide() end
	end)
end

-------------------------------------------------------------------------------
--  Events (RegisterUnitEvent: target and focus only)
-------------------------------------------------------------------------------
local evt = CreateFrame("Frame")
local UNIT_EVENTS = {
	"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_DELAYED",
	"UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
	"UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "UNIT_TARGET",
}

evt:SetScript("OnEvent", function(_, event, unit)
	if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
		local bar = bars[event == "PLAYER_TARGET_CHANGED" and "target" or "focus"]
		if bar then
			bar._interrupted = nil
			bar.flash:Hide()
			UpdateCast(bar)
		end
		return
	end
	if event == "SPELL_UPDATE_COOLDOWN" then
		for _, bar in pairs(bars) do
			if bar.isCasting then ApplyCastColor(bar) end
		end
		return
	end
	local bar = bars[unit]
	if not bar or previewOn[unit] then return end
	if event == "UNIT_SPELLCAST_INTERRUPTED" then
		-- The stop event can come first for channels: allow a short grace.
		if bar.isCasting or (bar._stoppedAt and GetTime() - bar._stoppedAt < 0.3) then
			ShowInterruptedFlash(bar)
		end
		bar.isCasting = false
	elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		if not bar._interrupted then UpdateCast(bar) end
	elseif event == "UNIT_TARGET" then
		if bar.isCasting then PaintTarget(bar) end
	else
		UpdateCast(bar)
	end
end)

local function AnyEnabled()
	local t = BarCfg("target")
	local f = BarCfg("focus")
	return (t and t.enabled == true) or (f and f.enabled == true)
end

local function Activate()
	if active then return end
	active = true
	for i = 1, #UNIT_EVENTS do
		evt:RegisterUnitEvent(UNIT_EVENTS[i], "target", "focus")
	end
	evt:RegisterEvent("PLAYER_TARGET_CHANGED")
	evt:RegisterEvent("PLAYER_FOCUS_CHANGED")
	evt:RegisterEvent("SPELL_UPDATE_COOLDOWN")
end

local function Deactivate()
	if not active then return end
	active = false
	evt:UnregisterAllEvents()
	for _, bar in pairs(bars) do
		TeardownCast(bar)
		bar._interrupted = nil
		bar.frame:Hide()
	end
end

local function ShowPreview(which)
	local bar = bars[which] or BuildBar(which)
	StyleBar(bar)
	local tf = TF()
	bar.isCasting = false
	bar.icon:SetTexture(QUESTION)
	bar.name:SetText(which == "target" and "Crushing Blow" or "Dark Mending")
	if tf and ShowsTarget(tf, which) then
		if tf.targetClassColor ~= false then
			local _, cls = UnitClass("player")
			bar.target:SetTextColor(P.ClassColor(cls))
		elseif tf.targetColor then
			bar.target:SetTextColor(tf.targetColor.r, tf.targetColor.g, tf.targetColor.b, 1)
		end
		bar.target:SetText(UnitName("player") or "Target")
		bar.target:Show()
		SizeNameForTarget(bar, true)
	else
		bar.target:SetText("")
		bar.target:Hide()
		SizeNameForTarget(bar, false)
	end
	bar.timer:SetText("1.4")
	local base = (tf and tf.castColor) or { r = 0.70, g = 0.40, b = 0.90 }
	bar.sb:SetStatusBarColor(base.r, base.g, base.b)
	bar.overlay:SetAlpha(0)
	bar.shieldFrame:SetAlpha(0)
	bar.flash:Hide()
	bar.kickTick:Hide()
	bar.kickReadyFill:Hide()
	bar.sb:SetValue(0.62)
	ApplyBarPosition(bar)
	bar.frame:Show()
end

function P.TFB_SetPreview(which, on)
	previewOn[which] = on == true
	if previewOn[which] then
		ShowPreview(which)
	else
		local bar = bars[which]
		if bar then
			bar.frame:Hide()
			bar.sb:SetValue(0)
			if active then UpdateCast(bar) end
		end
	end
end

function P.TFB_IsPreview(which)
	return previewOn[which] == true
end

function P.TFB_Refresh()
	local want = AnyEnabled()
	if want and not active then
		Activate()
	elseif not want and active then
		Deactivate()
		previewOn.target = false
		previewOn.focus = false
	end
	for which in pairs(DEFAULT_POS) do
		local cfg = BarCfg(which)
		local enabled = cfg and cfg.enabled == true
		local bar = bars[which]
		if enabled and not bar then bar = BuildBar(which) end
		if bar then
			if enabled then
				StyleBar(bar)
				ApplyBarPosition(bar)
				if previewOn[which] then
					ShowPreview(which)
				elseif active then
					UpdateCast(bar)
				end
			else
				previewOn[which] = false
				TeardownCast(bar)
				bar._interrupted = nil
				bar.frame:Hide()
			end
		end
	end
end

-------------------------------------------------------------------------------
--  Unlock Mode (retail keys EMT_TargetCastBar / EMT_FocusCastBar)
-------------------------------------------------------------------------------
local function MakeBarUnlockElement(which, label, order)
	local key = which == "target" and "EMT_TargetCastBar" or "EMT_FocusCastBar"
	return ns.MakeUnlockElement({
		key   = key,
		label = label,
		group = "Mythic+",
		order = order,
		noResize = true,
		allowMatchSource = true,
		isHidden = function()
			local cfg = BarCfg(which)
			return not (cfg and cfg.enabled == true)
		end,
		getFrame = function()
			local bar = bars[which] or BuildBar(which)
			return bar.frame
		end,
		getSize = function()
			local cfg = BarCfg(which)
			return (cfg and cfg.width) or 260, (cfg and cfg.height) or 22
		end,
		setWidth = function(_, w)
			local cfg = BarCfg(which)
			if not cfg then return end
			cfg.width = floor(w + 0.5)
			P.TFB_Refresh()
		end,
		setHeight = function(_, h)
			local cfg = BarCfg(which)
			if not cfg then return end
			cfg.height = floor(h + 0.5)
			P.TFB_Refresh()
		end,
		savePos = function(_, _, _, x, y)
			local cfg = BarCfg(which)
			if not (cfg and x and y) then return end
			cfg.pos = { centerX = x, centerY = y }
			if not ns._unlockActive then ApplyBarPosition(bars[which]) end
		end,
		loadPos = function()
			local cfg = BarCfg(which)
			local pos = cfg and cfg.pos
			if not (pos and pos.centerX and pos.centerY) then return nil end
			return { point = "CENTER", relPoint = "CENTER", x = pos.centerX, y = pos.centerY }
		end,
		clearPos = function()
			local cfg = BarCfg(which)
			if cfg then cfg.pos = nil end
		end,
		applyPos = function()
			local bar = bars[which]
			if bar then ApplyBarPosition(bar) end
		end,
	})
end

local function RegisterUnlock()
	if not (ns.RegisterUnlockElements and ns.MakeUnlockElement) then return end
	ns:RegisterUnlockElements({
		MakeBarUnlockElement("target", "Target Cast Bar", 522),
		MakeBarUnlockElement("focus", "Focus Cast Bar", 523),
	}, addonName)
	if ns.RegisterUnlockModeListener then
		local function Listener(which, key)
			return function(unlockActive)
				local cfg = BarCfg(which)
				if not (cfg and cfg.enabled == true) then return end
				P.TFB_SetPreview(which, unlockActive == true)
				local anchored = ns.IsUnlockAnchored and ns.IsUnlockAnchored(key)
				if not anchored then
					local bar = bars[which]
					if bar then ApplyBarPosition(bar) end
				end
			end
		end
		ns:RegisterUnlockModeListener("EMT_TargetCastBar", Listener("target", "EMT_TargetCastBar"))
		ns:RegisterUnlockModeListener("EMT_FocusCastBar", Listener("focus", "EMT_FocusCastBar"))
	end
end

function P.TFB_OnEnable(database)
	db = database
	if not db then return end
	RegisterUnlock()
	P.TFB_Refresh()
end
