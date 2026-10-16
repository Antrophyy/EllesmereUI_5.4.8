-------------------------------------------------------------------------------
--  EUI_Nameplates_Cast.lua
--
--  Cast bar (retail EUI_Nameplates_Cast.lua / Layout.lua LayoutCastBar /
--  LayoutCastIcon / Plate.lua UpdateCastText): fed by the Blizzard plate's
--  own (hidden) cast bar, which 5.4.8 runs for every plate: value, spell
--  name, icon and the uninterruptible shield. A unit token adds channel
--  detection and the spell target. Interrupt colors use the player's
--  interrupt (kick ready = Interruptible color, on cooldown = "Interrupt on
--  CD", ready before the cast ends = "Interrupt Ready Mid-Cast"), the kick
--  tick marks where the interrupt comes back, Interrupted Flash comes from
--  the combat log.
-------------------------------------------------------------------------------
local addonName, P = ...
local ns, ENP = P.ns, P.ENP
local defaults = P.defaults
local Plate = P.Plate

local floor, max, min = math.floor, math.max, math.min
local format = string.format
local GetTime = GetTime
local WHITE = P.WHITE
local SPARK_TEX = P.MEDIA .. "cast_spark"
local SHIELD_TEX = P.MEDIA .. "shield"

local castingPlates = {}
ENP.castingPlates = castingPlates

-------------------------------------------------------------------------------
--  Build
-------------------------------------------------------------------------------
function P.BuildCast(plate)
	local cast = CreateFrame("StatusBar", nil, plate)
	plate.cast = cast
	cast:SetStatusBarTexture(WHITE)
	cast:SetMinMaxValues(0, 1)
	cast:Hide()
	plate.castBG = cast:CreateTexture(nil, "BACKGROUND")
	plate.castBG:SetAllPoints()
	plate.castBG:SetTexture(WHITE)
	plate.castBorderFrame = CreateFrame("Frame", nil, cast)
	plate.castBorderFrame:SetAllPoints(cast)
	plate.castBorder = P.CreateEdges(plate.castBorderFrame, cast, "OVERLAY", 7)

	plate.castSpark = cast:CreateTexture(nil, "OVERLAY", nil, 2)
	plate.castSpark:SetTexture(SPARK_TEX)
	plate.castSpark:SetBlendMode("ADD")
	plate.castSpark:SetWidth(8)

	-- Kick tick (where the interrupt comes back during this cast).
	plate.kickTick = cast:CreateTexture(nil, "OVERLAY", nil, 3)
	plate.kickTick:SetTexture(WHITE)
	plate.kickTick:SetWidth(2)
	plate.kickTick:Hide()

	-- Shield (uninterruptible).
	plate.castShield = cast:CreateTexture(nil, "OVERLAY", nil, 4)
	plate.castShield:SetTexture(SHIELD_TEX)
	plate.castShield:Hide()

	-- Icon.
	local iconFrame = CreateFrame("Frame", nil, cast)
	plate.castIconFrame = iconFrame
	plate.castIcon = iconFrame:CreateTexture(nil, "ARTWORK")
	plate.castIcon:SetPoint("TOPLEFT", 1, -1)
	plate.castIcon:SetPoint("BOTTOMRIGHT", -1, 1)
	plate.castIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	plate.castIconBG = iconFrame:CreateTexture(nil, "BACKGROUND")
	plate.castIconBG:SetAllPoints()
	plate.castIconBG:SetTexture(0, 0, 0, 1)

	-- Texts.
	local tf = CreateFrame("Frame", nil, cast)
	tf:SetAllPoints(cast)
	plate.castTextFrame = tf
	plate.castName = P.NewText(tf, 10)
	plate.castTarget = P.NewText(tf, 10)
	plate.castTimer = P.NewText(tf, 10)
end

-------------------------------------------------------------------------------
--  Layout
-------------------------------------------------------------------------------
local function CastTextAnchor(side, pushed, reserve, isTimer)
	if side == "center" then
		return "CENTER", 0, "CENTER"
	elseif side == "left" then
		local base = isTimer and 3 or 5
		if pushed then base = base + reserve end
		return "LEFT", base, "LEFT"
	end
	local base = -3
	if pushed then base = base - reserve end
	return "RIGHT", base, "RIGHT"
end

function Plate:ApplyCastLayout()
	local p = P.Profile()
	local cast = self.cast
	local castH = P.CastH()
	local w = self.barW or P.HealthW()
	local iconW, shiftX = 0, 0
	local showIcon = p.showCastIcon ~= false
	local iconScale = p.castIconScale or 1
	if showIcon and p.castbarIconInWidth and not p.castIconFullSize then
		iconW = castH * iconScale
		if not p.castIconOnRight then shiftX = iconW end
	end
	cast:ClearAllPoints()
	cast:SetSize(max(1, w - iconW), castH)
	-- Cast Bar Y Offset snapped to whole physical pixels at the plate's
	-- scale (retail): unsnapped, the default 1 overlaps the health border by
	-- a fraction of a pixel more than the border, so both lines show.
	local offsetY = p.castBarOffsetY or 0
	if offsetY ~= 0 then
		local onePx = P.PixelFor(self.health)
		offsetY = floor(offsetY / onePx + 0.5) * onePx
	end
	cast:SetPoint("TOPLEFT", self.health, "BOTTOMLEFT", shiftX, offsetY)
	cast:SetStatusBarTexture(P.TexturePath(p.castBarTexture))
	local bg = p.castBgColor or defaults.castBgColor
	self.castBG:SetVertexColor(bg.r, bg.g, bg.b, p.castBgAlpha or 0.9)
	local bc = p.castBorderColor or defaults.castBorderColor
	P.LayoutEdges(self.castBorder, p.castBorderSize or 0, bc.r, bc.g, bc.b, 1)
	self.castSpark:SetHeight(castH * 2)
	self.castShield:SetSize(castH * 0.9, castH * 1.1)
	self.castShield:ClearAllPoints()
	self.castShield:SetPoint("CENTER", cast, "LEFT", 0, 0)
	self.kickTick:SetHeight(castH)
	local kr, kg, kb = P.Color("kickTickColor")
	self.kickTick:SetVertexColor(kr, kg, kb, 1)

	-- Icon (normal: cast bar height off the bar's side; full size: health +
	-- cast height, flush with both bars).
	local icon = self.castIconFrame
	icon:ClearAllPoints()
	local xo, yo = p.castIconOffsetX or 0, p.castIconOffsetY or 0
	local onRight = p.castIconOnRight
	if p.castIconFullSize then
		local side = (self.barH or P.HealthH()) + castH
		icon:SetScale(1)
		icon:SetSize(side, side)
		if onRight then
			icon:SetPoint("TOPLEFT", self.health, "TOPRIGHT", xo, yo)
		else
			icon:SetPoint("TOPRIGHT", self.health, "TOPLEFT", xo, yo)
		end
	else
		icon:SetScale(iconScale)
		icon:SetSize(castH, castH)
		if onRight then
			icon:SetPoint("TOPLEFT", cast, "TOPRIGHT", xo, yo)
		else
			icon:SetPoint("TOPRIGHT", cast, "TOPLEFT", xo, yo)
		end
	end
	if p.hideCastIconBorder then
		self.castIcon:SetPoint("TOPLEFT", 0, 0)
		self.castIcon:SetPoint("BOTTOMRIGHT", 0, 0)
		self.castIconBG:Hide()
	else
		self.castIcon:SetPoint("TOPLEFT", 1, -1)
		self.castIcon:SetPoint("BOTTOMRIGHT", -1, 1)
		self.castIconBG:Show()
	end
	if showIcon then icon:Show() else icon:Hide() end

	-- Texts: spell name, spell target and timer on their sides; a shared
	-- side pushes the text in by the timer width.
	local outline = P.Outline()
	P.SetFont(self.castName, p.castNameSize or 10, outline)
	P.SetFont(self.castTarget, p.castTargetSize or 10, outline)
	P.SetFont(self.castTimer, p.castTimerSize or 10, outline)
	local timerSide = p.castTimerSide or "right"
	local showTimer = p.showCastTimer ~= false
	local reserve = showTimer and ((p.castTimerSize or 10) * 2.2) or 0
	local function Place(fs, side, ox, oy, isTimer)
		fs:ClearAllPoints()
		if side == "none" then
			fs:Hide()
			return
		end
		local pushed = (not isTimer) and showTimer and side == timerSide and side ~= "center"
		local pt, x, jh = CastTextAnchor(side, pushed, reserve, isTimer)
		fs:SetPoint(pt, self.cast, pt, x + (ox or 0), oy or 0)
		fs:SetJustifyH(jh)
	end
	Place(self.castName, p.castNameSide or "left", p.castNameOffsetX, p.castNameOffsetY)
	Place(self.castTarget, p.castTargetSide or "right", p.castTargetOffsetX, p.castTargetOffsetY)
	if showTimer then
		Place(self.castTimer, timerSide, p.castTimerOffsetX, p.castTimerOffsetY, true)
	else
		self.castTimer:ClearAllPoints()
		self.castTimer:SetPoint("RIGHT", self.cast, "RIGHT", -3, 0)
	end
	local cw = max(1, w - iconW)
	local nameW = p.castCombineNameTarget and 80 or (p.castNameWidthPct or 42)
	self.castName:SetWidth(cw * nameW / 100)
	self.castName:SetWordWrap(p.castNameWrap == true)
	self.castTarget:SetWidth(cw * (p.castTargetWidthPct or 42) / 100)
	self.castTarget:SetWordWrap(p.castTargetWrap == true)
	local c = p.castTimerColor or defaults.castTimerColor
	self.castTimer:SetTextColor(c.r, c.g, c.b, 1)
	if self.castShown then
		self:ApplyCastColor()
		self:RefreshCastTarget()
	end
end

-------------------------------------------------------------------------------
--  Colors
-------------------------------------------------------------------------------
function Plate:ApplyCastColor()
	local p = P.Profile()
	local r, g, b
	if self.castInterrupted then
		r, g, b = P.Color("interruptedFlashColor")
	elseif self.castUninterruptible then
		r, g, b = P.Color("castBarUninterruptible")
	else
		r, g, b = P.Color("castBar")
		local left = P.KickRemaining()
		if left and left > 0 then
			local ends = self.castEnd or 0
			if p.interruptMidCastEnabled and GetTime() + left < ends then
				r, g, b = P.Color("interruptMidCastColor")
			else
				r, g, b = P.Color("interruptReady")
			end
		end
	end
	self.cast:SetStatusBarColor(r, g, b)
	if self.castUninterruptible and p.castBarShieldEnabled ~= false and not self.castInterrupted then
		self.castShield:Show()
	else
		self.castShield:Hide()
	end
	self:UpdateKickTick()
end

function Plate:UpdateKickTick()
	local p = P.Profile()
	local tick = self.kickTick
	if p.kickTickEnabled == false or self.castUninterruptible or self.castInterrupted or not self.castEnd then
		tick:Hide()
		return
	end
	local left = P.KickRemaining()
	if not left or left <= 0 then
		tick:Hide()
		return
	end
	local now = GetTime()
	local dur = (self.castEnd - self.castStart)
	if dur <= 0 or now + left >= self.castEnd then
		tick:Hide()
		return
	end
	local frac
	if self.castChannel then
		frac = (self.castEnd - (now + left)) / dur
	else
		frac = (now + left - self.castStart) / dur
	end
	tick:ClearAllPoints()
	tick:SetPoint("CENTER", self.cast, "LEFT", self.cast:GetWidth() * max(0, min(1, frac)), 0)
	tick:Show()
end

-------------------------------------------------------------------------------
--  Spell target text
-------------------------------------------------------------------------------
function Plate:RefreshCastTarget()
	if not self.castShown then return end
	local p = P.Profile()
	local spell = self.castSpell or ""
	local target, cls
	if self.unit and not self.castInterrupted then
		local tu = self.unit .. "target"
		if UnitExists(tu) and not UnitIsUnit(tu, self.unit) then
			target = UnitName(tu)
			if UnitIsPlayer(tu) then
				local _
				_, cls = UnitClass(tu)
			end
		end
	end
	local tr, tg, tb
	if target then
		if p.castTargetClassColor ~= false then
			local c = cls and ((EllesmereUI.GetClassColor and RAID_CLASS_COLORS[cls] and EllesmereUI.GetClassColor(cls)) or RAID_CLASS_COLORS[cls])
			if c then tr, tg, tb = c.r, c.g, c.b else tr, tg, tb = 1, 1, 1 end
		else
			tr, tg, tb = P.Color("castTargetColor")
		end
	end
	local nr, ng, nb = P.Color("castNameColor")
	if p.castCombineNameTarget and target then
		self.castName:SetTextColor(tr, tg, tb, 1)
		self.castName:SetText(format("|cff%02x%02x%02x%s - |r%s", floor(nr * 255), floor(ng * 255), floor(nb * 255), spell, target))
		self.castTarget:SetText("")
		self.castTarget:Hide()
	else
		self.castName:SetTextColor(nr, ng, nb, 1)
		self.castName:SetText(spell)
		if target and (p.castTargetSide or "right") ~= "none" then
			self.castTarget:SetTextColor(tr, tg, tb, 1)
			self.castTarget:SetText(target)
			self.castTarget:Show()
		else
			self.castTarget:SetText("")
			self.castTarget:Hide()
		end
	end
	if (p.castNameSide or "left") == "none" then
		self.castName:Hide()
	else
		self.castName:Show()
	end
end

-------------------------------------------------------------------------------
--  Driven by the Blizzard cast bar
-------------------------------------------------------------------------------
local function ShowCastBar(plate, on)
	if on == plate.castShown then return end
	plate.castShown = on
	if on then
		castingPlates[plate] = true
		plate.cast:Show()
	else
		castingPlates[plate] = nil
		plate.cast:Hide()
		plate.kickTick:Hide()
	end
	-- The bottom text slots and the bottom slot follow the cast bar.
	plate:AnchorBottomTexts()
	plate:UpdateTexts()
	plate:ApplyScale()
	if plate.isTarget and P.Profile().showTargetArrows then
		plate:PlaceArrows()
	end
	if plate.ApplyAuraLayout then plate:LayoutAuras() end
end

function Plate:StartCast()
	if self.nameOnly or self.hiddenPlate then return end
	if self.stopTimer then
		self.stopTimer:Cancel()
		self.stopTimer = nil
	end
	self.castInterrupted = nil
	if self.flashTimer then
		self.flashTimer:Cancel()
		self.flashTimer = nil
	end
	self.castSpell = self.bCastName:GetText() or ""
	self.castUninterruptible = self.bCastShield:IsShown() and true or false
	self.castIcon:SetTexture(self.bCastIcon:GetTexture())
	local mn, mx = self.bCast:GetMinMaxValues()
	local v = self.bCast:GetValue() or 0
	self.castMax = mx or 1
	self.castChannel = nil
	local unit = self.unit
	if unit then
		local name, _, _, _, s, e = UnitCastingInfo(unit)
		if name then
			self.castChannel = false
			self.castStart, self.castEnd = s / 1000, e / 1000
		else
			name, _, _, _, s, e = UnitChannelInfo(unit)
			if name then
				self.castChannel = true
				self.castStart, self.castEnd = s / 1000, e / 1000
			end
		end
	end
	if self.castChannel == nil then
		-- No unit: a cast starts near 0, a channel near its maximum.
		self.castChannel = (mx and mx > 0 and v > mx * 0.5) and true or false
		local now = GetTime()
		if self.castChannel then
			self.castStart, self.castEnd = now - (mx - v), now + v
		else
			self.castStart, self.castEnd = now - v, now + (mx - v)
		end
	end
	ShowCastBar(self, true)
	self:RefreshCastTarget()
	self:ApplyCastColor()
	self:OnCastValue(v)
end

function Plate:OnCastValue(v)
	if not self.castShown or self.castInterrupted then return end
	local mn, mx = self.bCast:GetMinMaxValues()
	mx = mx or 1
	self.cast:SetMinMaxValues(mn or 0, mx)
	self.cast:SetValue(v)
	local now = GetTime()
	if self.castChannel then
		self.castEnd = now + v
		self.castStart = self.castEnd - mx
	else
		self.castStart = now - v
		self.castEnd = self.castStart + mx
	end
	local p = P.Profile()
	if p.showCastTimer ~= false then
		local left = self.castChannel and v or (mx - v)
		self.castTimer:SetText(format("%.1f", max(0, left)))
		self.castTimer:Show()
	else
		self.castTimer:Hide()
	end
	if p.castBarSparkEnabled ~= false then
		local w = self.cast:GetWidth()
		self.castSpark:ClearAllPoints()
		self.castSpark:SetPoint("CENTER", self.cast, "LEFT", w * (mx > 0 and v / mx or 0), 0)
		self.castSpark:Show()
	else
		self.castSpark:Hide()
	end
	-- Shield can flip mid-cast.
	local unint = self.bCastShield:IsShown() and true or false
	if unint ~= self.castUninterruptible then
		self.castUninterruptible = unint
		self:ApplyCastColor()
	end
end

function Plate:StopCast()
	if self.castInterrupted or not self.castShown then return end
	-- The Blizzard bar hides before the combat log names the interrupt: wait a
	-- moment so Interrupted Flash can still take the bar.
	if self.stopTimer then self.stopTimer:Cancel() end
	local plate = self
	self.stopTimer = P.After(0.12, function()
		plate.stopTimer = nil
		if not plate.castInterrupted and not plate.bCast:IsShown() then
			ShowCastBar(plate, false)
		end
	end)
end

-- Interrupted Flash: the bar stays full in the flash color for a moment.
function Plate:ShowInterrupted(byName)
	if self.stopTimer then
		self.stopTimer:Cancel()
		self.stopTimer = nil
	end
	if not self.castShown then return end
	if P.Profile().interruptedFlashEnabled == false then
		ShowCastBar(self, false)
		return
	end
	self.castInterrupted = true
	local _, mx = self.cast:GetMinMaxValues()
	self.cast:SetValue(mx or 1)
	self.castSpark:Hide()
	self.kickTick:Hide()
	self.castShield:Hide()
	self.castTimer:SetText("")
	self.castName:SetTextColor(P.Color("castNameColor"))
	self.castName:SetText(byName and (INTERRUPTED .. " (" .. byName .. ")") or INTERRUPTED)
	self.castTarget:SetText("")
	self:ApplyCastColor()
	local plate = self
	self.flashTimer = P.After(0.8, function()
		plate.flashTimer = nil
		plate.castInterrupted = nil
		if plate.bCast:IsShown() and plate.shown then
			plate:StartCast()
		else
			ShowCastBar(plate, false)
		end
	end)
end

function Plate:RefreshCast()
	if self.bCast:IsShown() and not self.nameOnly and not self.hiddenPlate then
		self:StartCast()
	elseif self.castShown and not self.castInterrupted then
		ShowCastBar(self, false)
	end
end

function Plate:ClearCast()
	if self.stopTimer then
		self.stopTimer:Cancel()
		self.stopTimer = nil
	end
	if self.flashTimer then
		self.flashTimer:Cancel()
		self.flashTimer = nil
	end
	self.castInterrupted = nil
	castingPlates[self] = nil
	self.castShown = false
	self.cast:Hide()
end

local function CastOnShow(bar)
	local plate = bar.__euiPlate
	if plate and plate.shown then plate:StartCast() end
end
local function CastOnHide(bar)
	local plate = bar.__euiPlate
	if plate and plate.shown then plate:StopCast() end
end
local function CastOnValue(bar, v)
	local plate = bar.__euiPlate
	if plate and plate.shown then
		if not plate.castShown and not plate.castInterrupted then
			plate:StartCast()
		else
			plate:OnCastValue(v)
		end
	end
end

function Plate:HookCastBar()
	self.bCast:HookScript("OnShow", CastOnShow)
	self.bCast:HookScript("OnHide", CastOnHide)
	self.bCast:HookScript("OnValueChanged", CastOnValue)
end

-- Kick cooldown changed: recolor casting plates.
function P.RefreshCastColors()
	for plate in pairs(castingPlates) do
		plate:ApplyCastColor()
	end
end
