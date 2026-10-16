-------------------------------------------------------------------------------
--  EllesmereUIQoL_Bloodlust.lua (5.4.8 port of the retail Bloodlust Tracker)
--
--  Shows the player's Sated / Exhaustion lockout as one icon with the time
--  left, a 40 s overlay of the active lust buff on top of it, and optionally a
--  "Ready" label once the lockout is gone.
--
--  Same keys, look, options and Unlock Mode element ("Lust") as retail. 5.4.8
--  has no secret aura values, so the lockout and the lust buff are read
--  directly with UnitAura (retail has to self-time them):
--    * the countdown uses the debuff's real expiration time;
--    * the overlay is the real lust buff (its icon and time left);
--    * a "fresh" lust = a Sated debuff with almost all of its 10 min left.
--  Appearance keys proxy-read through to the Battle Res icon until changed
--  here (retail "starts identical, can diverge" model). Shapes: None/Cropped.
-------------------------------------------------------------------------------
local addonName = ...
local ns = EllesmereUI

local floor, ceil, max = math.floor, math.ceil, math.max
local GetTime = GetTime

-- Player-castable lust spells, checked in this order for the resting / ready
-- icon (the first one the character knows).
local LUST_SPELLS = {
	2825,    -- Bloodlust (Shaman, Horde)
	32182,   -- Heroism (Shaman, Alliance)
	80353,   -- Time Warp (Mage)
}

-- Lust buffs (5.4.8): shown as the 40 s overlay while active.
local LUST_BUFFS = {
	[2825] = true,    -- Bloodlust
	[32182] = true,   -- Heroism
	[80353] = true,   -- Time Warp
	[90355] = true,   -- Ancient Hysteria (Hunter core hound)
	[146555] = true,  -- Drums of Rage (Leatherworking)
}

-- Sated / Exhaustion debuffs (every lust variant's lockout).
local SATED_DEBUFFS = {
	[57723] = true,   -- Exhaustion (Heroism, Drums of Rage)
	[57724] = true,   -- Sated (Bloodlust)
	[80354] = true,   -- Temporal Displacement (Time Warp)
	[95809] = true,   -- Insanity (Ancient Hysteria)
}

local LOCKOUT = 600
local CHALLENGE_DIFFICULTY = 8
local BORDER_PX = { none = 0, thin = 1, normal = 2, heavy = 3, strong = 4 }
local FONT_KEY = "qol"

-------------------------------------------------------------------------------
--  DB: EllesmereUIQoLDB.bloodlust (own keys) + battleRes (appearance proxy)
-------------------------------------------------------------------------------
local function Defaults()
	return {
		enabled    = true,
		visibility = "NEVER",  -- MPLUS_AND_RAID | MPLUS | RAID | NEVER (MPLUS = Challenge Mode)
		showSated    = true,
		showReady    = false,
		readySize    = 12,
		readyColor   = { r = 1, g = 1, b = 1 },
		readyOffsetX = 0,
		readyOffsetY = 0,
		desaturateSated = true,
		-- pos = { centerX, centerY } after the first move
	}
end

local function P()
	local q = ns.GetQoLDB and ns.GetQoLDB()
	if type(q) ~= "table" then return nil end
	local t = q.bloodlust
	if type(t) ~= "table" then
		t = {}
		q.bloodlust = t
	end
	if t._seeded ~= 1 then
		ns.CopyDefaults(Defaults(), t)
		t._seeded = 1
	end
	return t
end
ns.GetBloodlustDB = P

local function BR()
	return ns.GetBattleResDB and ns.GetBattleResDB()
end

local APP_DEFAULTS = {
	iconSize        = 40,
	iconZoom        = 11,
	shape           = "none",
	borderSize      = "thin",
	borderUseClass  = false,
	durationSize    = 12,
	durationOffsetX = 0,
	durationOffsetY = 0,
	countSize       = 11,
	countOffsetX    = 0,
	countOffsetY    = 0,
}

-- Keys stored only on the bloodlust table (everything else proxies).
local OWN_KEYS = {
	visibility = true, enabled = true, pos = true,
	showSated = true, showReady = true, readySize = true, readyColor = true,
	readyOffsetX = true, readyOffsetY = true, desaturateSated = true,
}
ns.BLOODLUST_OWN_KEYS = OWN_KEYS

-- Effective value: bloodlust override -> battleRes -> default.
local function EP(key)
	local bl = P()
	if bl and bl[key] ~= nil then return bl[key] end
	if OWN_KEYS[key] then return nil end
	local br = BR()
	if br and br[key] ~= nil then return br[key] end
	if key == "borderColor" then return { r = 0, g = 0, b = 0, a = 1 } end
	return APP_DEFAULTS[key]
end
ns.BloodlustGet = EP

local frame, iconTex, durationFS, countFS, cooldownFrame, readyFS
local textOverlay, border
local buffOverlay, buffTex, buffCooldown, buffDurationFS, buffBorder

local satedActive = false
local satedExpiry = 0
local readyShown = false
local previewOwner
local previewExpiry = 0
local UpdateVisibility

local function PreviewActive()
	return previewOwner ~= nil and previewOwner:IsVisible() and true or false
end

-------------------------------------------------------------------------------
--  Look
-------------------------------------------------------------------------------
local function Snap(v)
	local PP = ns.PP
	if PP and PP.Snap then return PP.Snap(v) end
	return v
end

local function IconFont(fs, size)
	fs:SetFont((ns.GetFontPath and ns.GetFontPath(FONT_KEY)) or STANDARD_TEXT_FONT, size, "OUTLINE")
	if not fs:GetFont() then
		fs:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
	end
	fs:SetShadowOffset(0, 0)
end

local function ResolveBorderColor()
	if EP("borderUseClass") then
		local _, ct = UnitClass("player")
		local cc = ct and RAID_CLASS_COLORS[ct]
		if cc then return cc.r, cc.g, cc.b, 1 end
	end
	local c = EP("borderColor")
	return c.r or 0, c.g or 0, c.b or 0, c.a or 1
end

-- PP edge border on one layer (debuff icon or buff overlay), pinned to level.
local function ApplyBorder(host, current, level)
	local PP = ns.PP
	if not (PP and PP.CreateBorder) then return current end
	local container = current or PP.CreateBorder(host, 0, 0, 0, 1, 1, "OVERLAY", 2)
	container:SetFrameLevel(level)
	local bs = BORDER_PX[EP("borderSize") or "thin"] or 1
	if bs > 0 then
		PP.SetBorderSize(host, bs)
		PP.SetBorderColor(host, ResolveBorderColor())
		container:Show()
	else
		container:Hide()
	end
	return container
end

local function TexCoords(tex)
	local z = (EP("iconZoom") or 11) / 100
	if EP("shape") == "cropped" then
		tex:SetTexCoord(z, 1 - z, z + 0.10, 1 - z - 0.10)
	else
		tex:SetTexCoord(z, 1 - z, z, 1 - z)
	end
end

local function ApplyShape()
	if not frame then return end
	local size = EP("iconSize") or 40
	local fw, fh = size, size
	if EP("shape") == "cropped" then fh = floor(size * 0.80 + 0.5) end
	frame:SetSize(Snap(fw), Snap(fh))
	TexCoords(iconTex)

	IconFont(durationFS, EP("durationSize") or 12)
	durationFS:ClearAllPoints()
	durationFS:SetPoint("CENTER", frame, "CENTER", Snap(EP("durationOffsetX") or 0), Snap(EP("durationOffsetY") or 0))
	IconFont(countFS, EP("countSize") or 11)
	countFS:ClearAllPoints()
	countFS:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", Snap(-2 + (EP("countOffsetX") or 0)), Snap(2 + (EP("countOffsetY") or 0)))

	IconFont(readyFS, EP("readySize") or 12)
	readyFS:ClearAllPoints()
	readyFS:SetPoint("CENTER", frame, "CENTER", Snap(EP("readyOffsetX") or 0), Snap(EP("readyOffsetY") or 0))
	local c = EP("readyColor") or {}
	readyFS:SetTextColor(c.r or 1, c.g or 1, c.b or 1)
	readyFS:Hide()
	readyShown = false

	-- Level stack: +0 icon, +1 swipe, +2 border, +3 debuff texts,
	-- +5 buff overlay, +6 buff swipe, +7 buff border, +8 buff text.
	border = ApplyBorder(frame, border, frame:GetFrameLevel() + 2)

	TexCoords(buffTex)
	buffBorder = ApplyBorder(buffOverlay, buffBorder, buffCooldown:GetFrameLevel() + 1)
	IconFont(buffDurationFS, EP("durationSize") or 12)
	buffDurationFS:ClearAllPoints()
	buffDurationFS:SetPoint("CENTER", frame, "CENTER", Snap(EP("durationOffsetX") or 0), Snap(EP("durationOffsetY") or 0))
end

-------------------------------------------------------------------------------
--  Position (default: just left of the Battle Res icon)
-------------------------------------------------------------------------------
local function DefaultLeftOfBrez()
	local br = BR()
	local cx, cy = 0, 200
	if br and br.pos and br.pos.centerX and br.pos.centerY then
		cx, cy = br.pos.centerX, br.pos.centerY
	end
	local brSize = (br and br.iconSize) or 40
	return cx - (brSize * 0.5 + 6 + (EP("iconSize") or 40) * 0.5), cy
end

local function ApplyPosition()
	if not frame then return end
	if ns._unlockActive and frame:GetNumPoints() > 0 then return end
	local p = P()
	if not p then return end
	local cx, cy
	if p.pos and p.pos.centerX and p.pos.centerY then
		cx, cy = p.pos.centerX, p.pos.centerY
	else
		cx, cy = DefaultLeftOfBrez()
	end
	local PP = ns.PP
	if PP and PP.SnapCenterForDim then
		cx = PP.SnapCenterForDim(cx, frame:GetWidth())
		cy = PP.SnapCenterForDim(cy, frame:GetHeight())
	end
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", cx, cy)
	if not ns._unlockActive and ns.IsUnlockAnchored and ns.IsUnlockAnchored("EUI_Bloodlust") and ns.ReapplyOwnAnchor then
		ns.ReapplyOwnAnchor("EUI_Bloodlust")
	end
end

-- First switch away from "Never": store a concrete spot left of Brez.
function ns.BloodlustSeedPos()
	local p = P()
	if not p or p.pos then return end
	local cx, cy = DefaultLeftOfBrez()
	p.pos = { centerX = cx, centerY = cy }
	ApplyPosition()
end

-------------------------------------------------------------------------------
--  Auras (player only)
-------------------------------------------------------------------------------
-- Returns icon, duration, expirationTime of the first matching player aura.
local function FindAura(filter, ids)
	for i = 1, 40 do
		local name, _, icon, _, _, duration, expirationTime, _, _, _, spellId = UnitAura("player", i, filter)
		if not name then return nil end
		if ids[spellId] then
			return icon, duration, expirationTime
		end
	end
	return nil
end

local lustIcon
local function LustIcon()
	if lustIcon then return lustIcon end
	for i = 1, #LUST_SPELLS do
		local sid = LUST_SPELLS[i]
		if (IsPlayerSpell and IsPlayerSpell(sid)) or (IsSpellKnown and IsSpellKnown(sid)) then
			local _, _, tex = GetSpellInfo(sid)
			if tex then
				lustIcon = tex
				return tex
			end
		end
	end
	local _, _, tex = GetSpellInfo(UnitFactionGroup("player") == "Alliance" and 32182 or 2825)
	lustIcon = tex or "Interface\\Icons\\Spell_Nature_Bloodlust"
	return lustIcon
end

local swipeStart, swipeDur
local function SetSwipe(start, dur)
	if start == swipeStart and dur == swipeDur then return end
	swipeStart, swipeDur = start, dur
	if start and dur then
		cooldownFrame:SetCooldown(start, dur)
		cooldownFrame:Show()
	else
		cooldownFrame:SetCooldown(0, 0)
	end
end

local lastDur
local function SetDur(s)
	if s ~= lastDur then
		durationFS:SetText(s)
		lastDur = s
	end
end

local lastDesat = false
local function SyncDesat()
	local want = (EP("desaturateSated") and not readyShown) and true or false
	if want ~= lastDesat then
		iconTex:SetDesaturated(want)
		lastDesat = want
	end
end

local function FormatTime(s)
	if ns.FormatTime then return ns.FormatTime(s) end
	if not s or s <= 0 then return "" end
	return string.format("%d:%02d", floor(s / 60), floor(s % 60))
end

-- Lockout state from the debuff (icon, swipe, expiry).
local function RefreshSated()
	local icon, duration, expirationTime = FindAura("HARMFUL", SATED_DEBUFFS)
	satedActive = icon ~= nil
	if satedActive then
		satedExpiry = expirationTime or 0
		if frame then
			iconTex:SetTexture(icon)
			if duration and duration > 0 and expirationTime then
				SetSwipe(expirationTime - duration, duration)
			end
		end
	else
		satedExpiry = 0
	end
	return satedActive
end

-------------------------------------------------------------------------------
--  Active lust overlay (the real buff)
-------------------------------------------------------------------------------
local buffExpiry = 0
local lastBuffText
local buffAccum = 0

local function HideBuffOverlay()
	buffExpiry = 0
	if buffOverlay then
		buffOverlay:SetScript("OnUpdate", nil)
		buffOverlay:Hide()
		buffDurationFS:SetText("")
	end
	lastBuffText = nil
end

local function BuffOnUpdate(_, elapsed)
	local rem = buffExpiry - GetTime()
	if rem <= 0 then
		HideBuffOverlay()
		UpdateVisibility()
		return
	end
	buffAccum = buffAccum + (elapsed or 0)
	if buffAccum < 0.1 then return end
	buffAccum = 0
	local s = tostring(ceil(rem))
	if s ~= lastBuffText then
		buffDurationFS:SetText(s)
		lastBuffText = s
	end
end

local function RefreshBuff()
	if not buffOverlay then return end
	local icon, duration, expirationTime = FindAura("HELPFUL", LUST_BUFFS)
	if not icon or not expirationTime or expirationTime <= GetTime() then
		if buffExpiry ~= 0 then HideBuffOverlay() end
		return
	end
	if expirationTime ~= buffExpiry then
		buffExpiry = expirationTime
		buffTex:SetTexture(icon)
		if duration and duration > 0 then
			buffCooldown:SetCooldown(expirationTime - duration, duration)
		end
		buffAccum = 1
		buffOverlay:Show()
		buffOverlay:SetScript("OnUpdate", BuffOnUpdate)
	end
end

-------------------------------------------------------------------------------
--  Ready label
-------------------------------------------------------------------------------
local function ShowReadyState()
	if readyShown or not frame then return end
	iconTex:SetTexture(LustIcon())
	SetSwipe(nil)
	readyFS:SetText("Ready")
	readyFS:Show()
	readyShown = true
end

local function HideReadyState()
	if not readyShown then return end
	readyFS:Hide()
	readyShown = false
end

-------------------------------------------------------------------------------
--  Content state (same meaning as the Battle Res icon)
-------------------------------------------------------------------------------
local state = { inEncounter = false, inChallenge = false }

local function RefreshInstanceState()
	local _, instanceType, difficulty = GetInstanceInfo()
	state.inChallenge = (instanceType == "party" and difficulty == CHALLENGE_DIFFICULTY)
	state.inEncounter = (IsEncounterInProgress and IsEncounterInProgress()) and true or false
end

local function ShouldShow()
	local p = P()
	if not p or not p.enabled then return false end
	local v = p.visibility or "NEVER"
	if v == "NEVER" then return false end
	if PreviewActive() then return true end
	if satedActive then
		if EP("showSated") == false and buffExpiry <= GetTime() then return false end
	elseif not EP("showReady") then
		return false
	end
	local _, instanceType = GetInstanceInfo()
	if instanceType ~= "party" and instanceType ~= "raid" then return false end
	if (v == "MPLUS_AND_RAID" or v == "MPLUS") and state.inChallenge then return true end
	if (v == "MPLUS_AND_RAID" or v == "RAID") and state.inEncounter and instanceType == "raid" then return true end
	return false
end

-------------------------------------------------------------------------------
--  Polling (0.5 s, only while a countdown is shown)
-------------------------------------------------------------------------------
local function ShowPreviewLockout()
	HideReadyState()
	local now = GetTime()
	if previewExpiry <= now then
		previewExpiry = now + LOCKOUT
		iconTex:SetTexture(LustIcon())
	end
	SetSwipe(previewExpiry - LOCKOUT, LOCKOUT)
	SetDur(FormatTime(previewExpiry - now))
end

local ticker = CreateFrame("Frame")
local tickerOn, tickerAcc = false, 0
local PollSated

local function StopTicker()
	if not tickerOn then return end
	tickerOn = false
	ticker:SetScript("OnUpdate", nil)
end
local function StartTicker()
	if tickerOn then return end
	tickerOn, tickerAcc = true, 0
	ticker:SetScript("OnUpdate", function(_, elapsed)
		tickerAcc = tickerAcc + elapsed
		if tickerAcc >= 0.5 then
			tickerAcc = 0
			PollSated()
		end
	end)
end

function PollSated()
	if not frame then return end
	if not RefreshSated() then
		if EP("showReady") then
			StopTicker()
			SetDur("")
			ShowReadyState()
			SyncDesat()
			return
		end
		if PreviewActive() then
			ShowPreviewLockout()
			SyncDesat()
			return
		end
		SetDur("")
		return UpdateVisibility()
	end
	HideReadyState()
	local rem = satedExpiry - GetTime()
	SetDur(rem > 0 and FormatTime(rem) or "")
	SyncDesat()
end

function UpdateVisibility()
	if not frame then return end
	if ShouldShow() then
		if not frame:IsShown() then frame:Show() end
		if satedActive or (PreviewActive() and not EP("showReady")) then
			StartTicker()
		else
			StopTicker()
		end
		PollSated()
	else
		if frame:IsShown() then frame:Hide() end
		StopTicker()
		if previewExpiry ~= 0 and not PreviewActive() then
			previewExpiry = 0
			SetSwipe(nil)
			SetDur("")
		end
	end
end
ns.BloodlustUpdateVisibility = UpdateVisibility

function ns.BloodlustSetPreviewOwner(f)
	previewOwner = f
	previewExpiry = 0
	UpdateVisibility()
end

-------------------------------------------------------------------------------
--  Events (registered only while the tracker can show)
-------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local eventsOn = false

eventFrame:SetScript("OnEvent", function(_, event)
	if event == "UNIT_AURA" then
		RefreshSated()
		RefreshBuff()
	elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
		lustIcon = nil
		HideReadyState()
	elseif event == "PLAYER_ENTERING_WORLD" then
		lustIcon = nil
		RefreshSated()
		RefreshBuff()
		RefreshInstanceState()
	elseif event == "ENCOUNTER_START" then
		state.inEncounter = true
	elseif event == "ENCOUNTER_END" then
		state.inEncounter = false
	else
		RefreshInstanceState()
	end
	UpdateVisibility()
end)

local function SyncEvents(want)
	if want == eventsOn then return end
	eventsOn = want
	if want then
		eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
		eventFrame:RegisterEvent("ENCOUNTER_START")
		eventFrame:RegisterEvent("ENCOUNTER_END")
		eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
		eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
		eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		eventFrame:RegisterEvent("WORLD_STATE_TIMER_START")
		eventFrame:RegisterEvent("WORLD_STATE_TIMER_STOP")
		eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
		eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
	else
		eventFrame:UnregisterAllEvents()
	end
end

-------------------------------------------------------------------------------
--  Frame
-------------------------------------------------------------------------------
local function CreateBloodlustFrame()
	if frame then return frame end
	frame = CreateFrame("Frame", "EllesmereUIBloodlustIcon", UIParent)
	frame:SetFrameStrata("MEDIUM")
	frame:SetSize(40, 40)
	frame:Hide()

	iconTex = frame:CreateTexture(nil, "ARTWORK")
	iconTex:SetAllPoints(frame)
	iconTex:SetTexture(LustIcon())
	iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	cooldownFrame = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
	cooldownFrame:SetAllPoints(frame)
	cooldownFrame.noCooldownCount = true
	cooldownFrame.noOCC = true
	cooldownFrame:SetFrameLevel(frame:GetFrameLevel() + 1)

	textOverlay = CreateFrame("Frame", nil, frame)
	textOverlay:SetAllPoints(frame)
	textOverlay:SetFrameLevel(frame:GetFrameLevel() + 3)
	durationFS = textOverlay:CreateFontString(nil, "OVERLAY")
	IconFont(durationFS, 14)
	durationFS:SetText("")
	readyFS = textOverlay:CreateFontString(nil, "OVERLAY")
	IconFont(readyFS, 12)
	readyFS:SetText("")
	readyFS:Hide()
	countFS = textOverlay:CreateFontString(nil, "OVERLAY")
	IconFont(countFS, 12)
	countFS:SetText("")

	buffOverlay = CreateFrame("Frame", nil, frame)
	buffOverlay:SetAllPoints(frame)
	buffOverlay:SetFrameLevel(frame:GetFrameLevel() + 5)
	buffOverlay:Hide()
	buffTex = buffOverlay:CreateTexture(nil, "ARTWORK")
	buffTex:SetAllPoints(buffOverlay)
	buffCooldown = CreateFrame("Cooldown", nil, buffOverlay, "CooldownFrameTemplate")
	buffCooldown:SetAllPoints(buffOverlay)
	buffCooldown.noCooldownCount = true
	buffCooldown.noOCC = true
	buffCooldown:SetReverse(true)  -- active buff: starts bright, darkens as it runs out
	buffCooldown:SetFrameLevel(buffOverlay:GetFrameLevel() + 1)
	local buffText = CreateFrame("Frame", nil, buffOverlay)
	buffText:SetAllPoints(buffOverlay)
	buffText:SetFrameLevel(buffCooldown:GetFrameLevel() + 2)
	buffDurationFS = buffText:CreateFontString(nil, "OVERLAY")
	IconFont(buffDurationFS, 12)
	buffDurationFS:SetText("")
	return frame
end

-------------------------------------------------------------------------------
--  Apply (every settings change)
-------------------------------------------------------------------------------
local function Apply()
	local p = P()
	if not p then return end
	if not frame then CreateBloodlustFrame() end
	ApplyShape()
	ApplyPosition()
	local enabled = p.enabled and p.visibility ~= "NEVER"
	SyncEvents(enabled and true or false)
	if enabled then
		RefreshSated()
		RefreshBuff()
		RefreshInstanceState()
	end
	UpdateVisibility()
end
ns.BloodlustApply = Apply

ns.applyHooks = ns.applyHooks or {}
tinsert(ns.applyHooks, function()
	if frame then Apply() end
end)

-------------------------------------------------------------------------------
--  Unlock Mode
-------------------------------------------------------------------------------
local function RegisterUnlock()
	if not ns.RegisterUnlockElements or not ns.MakeUnlockElement then return end
	local function Resize(v)
		local p = P()
		if not p then return end
		p.iconSize = max(16, floor(Snap(v) + 0.5))
		Apply()
		if ns._unlockActive and ns.RepositionBarToMover then
			ns.RepositionBarToMover("EUI_Bloodlust")
		end
	end
	ns:RegisterUnlockElements({
		ns.MakeUnlockElement({
			key = "EUI_Bloodlust",
			label = "Lust",
			group = "Quality of Life",
			order = 601,
			noAnchorTarget = true,
			isHidden = function()
				local p = P()
				return not p or not p.enabled or p.visibility == "NEVER"
			end,
			getFrame = function()
				if not frame then CreateBloodlustFrame() end
				return frame
			end,
			getSize = function()
				local s = EP("iconSize") or 40
				return s, s
			end,
			linkedDimensions = true,
			setWidth = function(_, w) Resize(w) end,
			setHeight = function(_, h) Resize(h) end,
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

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
	self:UnregisterAllEvents()
	CreateBloodlustFrame()
	Apply()
end)
