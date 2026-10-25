-------------------------------------------------------------------------------
--  EUI_Nameplates_Display.lua
--
--  The look of a plate (retail Plate / PlatePool / Health / Name / Overlays
--  files): health bar with background, texture, border, absorb and hash
--  line; the six text slots (Core Text Positions) with their elements and
--  Text Coloring; raid marker; Rare / Quest indicator; target effects
--  (EllesmereUI glow, border color / size, highlight wash, overlay texture,
--  arrows, scale); focus overlay and letter; hover effects; non-target
--  opacity; Execute Pulse and Near Aggro glows; friendly plates (name only
--  or a bar).
--  5.4.8: no SetClipsChildren, so the overlay "clip" frames are drawn with
--  texture coordinates that follow the health fill.
-------------------------------------------------------------------------------
local addonName, P = ...
local ns, ENP = P.ns, P.ENP
local defaults = P.defaults
local Plate = P.Plate

local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local format = string.format
local WHITE = P.WHITE

local GLOW_TEX = P.MEDIA .. "background"
local EXEC_TEX = P.MEDIA .. "execute-glow"
local GLOW_MARGIN = 0.48
local GLOW_CORNER = 12
local GLOW_EXTEND = 6

local TEXT_SLOTS = {
	{ key = "textSlotTop", point = "BOTTOM", rel = "TOP", x = 0, y = 4 },
	{ key = "textSlotRight", point = "RIGHT", rel = "RIGHT", x = -2, y = 0 },
	{ key = "textSlotLeft", point = "LEFT", rel = "LEFT", x = 4, y = 0 },
	{ key = "textSlotCenter", point = "CENTER", rel = "CENTER", x = 0, y = 0 },
	{ key = "textSlotBottomLeft", point = "TOPLEFT", rel = "BOTTOMLEFT", x = 0, y = -2, bottom = true },
	{ key = "textSlotBottomRight", point = "TOPRIGHT", rel = "BOTTOMRIGHT", x = 0, y = -2, bottom = true },
}
P.TEXT_SLOTS = TEXT_SLOTS

local NAME_FAMILY = { enemyName = true, levelName = true, nameLevel = true }
local HEALTH_ELEMENTS = {
	healthPercent = true, healthPercentNoSign = true, healthNumber = true,
	healthPctNum = true, healthNumPct = true, healthPctNumDash = true, healthNumPctDash = true,
}
P.NAME_FAMILY, P.HEALTH_ELEMENTS = NAME_FAMILY, HEALTH_ELEMENTS

local STRATA_ORDER = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
local function RaisedStrata(base)
	for i, s in ipairs(STRATA_ORDER) do
		if s == base then
			return STRATA_ORDER[min(i + 1, #STRATA_ORDER)]
		end
	end
	return "MEDIUM"
end
P.RaisedStrata = RaisedStrata

-- Retail ns.AbbreviateNumbers (EllesmereUI short numbers).
function P.Abbrev(v)
	v = v or 0
	if v >= 1e9 then
		return format("%.1fB", v / 1e9)
	elseif v >= 1e6 then
		return format("%.1fM", v / 1e6)
	elseif v >= 1e4 then
		return format("%.0fK", v / 1e3)
	elseif v >= 1e3 then
		return format("%.1fK", v / 1e3)
	end
	return tostring(floor(v))
end

-------------------------------------------------------------------------------
--  9-slice glow (retail EnsureGlow geometry)
-------------------------------------------------------------------------------
local function NineSlice(f, tex, list)
	local function Mk()
		local t = f:CreateTexture(nil, "BACKGROUND")
		t:SetTexture(tex)
		t:SetBlendMode("ADD")
		list[#list + 1] = t
		return t
	end
	local m, c = GLOW_MARGIN, GLOW_CORNER
	local tl = Mk(); tl:SetSize(c, c); tl:SetPoint("TOPLEFT"); tl:SetTexCoord(0, m, 0, m)
	local tr = Mk(); tr:SetSize(c, c); tr:SetPoint("TOPRIGHT"); tr:SetTexCoord(1 - m, 1, 0, m)
	local bl = Mk(); bl:SetSize(c, c); bl:SetPoint("BOTTOMLEFT"); bl:SetTexCoord(0, m, 1 - m, 1)
	local br = Mk(); br:SetSize(c, c); br:SetPoint("BOTTOMRIGHT"); br:SetTexCoord(1 - m, 1, 1 - m, 1)
	local top = Mk(); top:SetHeight(c); top:SetPoint("TOPLEFT", tl, "TOPRIGHT"); top:SetPoint("TOPRIGHT", tr, "TOPLEFT"); top:SetTexCoord(m, 1 - m, 0, m)
	local bot = Mk(); bot:SetHeight(c); bot:SetPoint("BOTTOMLEFT", bl, "BOTTOMRIGHT"); bot:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT"); bot:SetTexCoord(m, 1 - m, 1 - m, 1)
	local lf = Mk(); lf:SetWidth(c); lf:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); lf:SetPoint("BOTTOMLEFT", bl, "TOPLEFT"); lf:SetTexCoord(0, m, m, 1 - m)
	local rt = Mk(); rt:SetWidth(c); rt:SetPoint("TOPRIGHT", tr, "BOTTOMRIGHT"); rt:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT"); rt:SetTexCoord(1 - m, 1, m, 1 - m)
	local ct = Mk(); ct:SetPoint("TOPLEFT", lf, "TOPRIGHT"); ct:SetPoint("BOTTOMRIGHT", rt, "BOTTOMLEFT"); ct:SetTexCoord(m, 1 - m, m, 1 - m)
end

local function MakeGlowFrame(plate, tex)
	local f = CreateFrame("Frame", nil, plate)
	f:SetPoint("TOPLEFT", plate.health, "TOPLEFT", -GLOW_EXTEND, GLOW_EXTEND)
	f:SetPoint("BOTTOMRIGHT", plate.health, "BOTTOMRIGHT", GLOW_EXTEND, -GLOW_EXTEND)
	f.textures = {}
	NineSlice(f, tex, f.textures)
	f.SetColor = function(self, r, g, b, a)
		for _, t in ipairs(self.textures) do
			t:SetVertexColor(r, g, b, a or 1)
		end
	end
	f:Hide()
	return f
end

-------------------------------------------------------------------------------
--  Overlay pair (fill part + empty part of the bar) following the fill
-------------------------------------------------------------------------------
local STRIPE_NATIVE_W = 200

local function MakeOverlay(plate, sub)
	local o = {}
	o.fill = plate.health:CreateTexture(nil, "ARTWORK", nil, sub)
	o.bg = plate.health:CreateTexture(nil, "ARTWORK", nil, sub - 1)
	o.fill:Hide()
	o.bg:Hide()
	return o
end

-- Lays the overlay over the fill fraction `frac` of the bar.
local function LayoutOverlay(o, health, frac, isStripe)
	local w = health:GetWidth()
	if not w or w <= 0 then return end
	local u = 1
	if isStripe then
		u = min(1, w / STRIPE_NATIVE_W)
	end
	frac = max(0, min(1, frac or 1))
	local fw = w * frac
	o.fill:ClearAllPoints()
	o.fill:SetPoint("TOPLEFT", health, "TOPLEFT", 0, 0)
	o.fill:SetPoint("BOTTOMLEFT", health, "BOTTOMLEFT", 0, 0)
	o.fill:SetWidth(max(fw, 0.01))
	o.fill:SetTexCoord(0, u * frac, 0, 1)
	o.bg:ClearAllPoints()
	o.bg:SetPoint("TOPRIGHT", health, "TOPRIGHT", 0, 0)
	o.bg:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", 0, 0)
	o.bg:SetWidth(max(w - fw, 0.01))
	o.bg:SetTexCoord(u * frac, u, 0, 1)
	if frac <= 0 then o.fill:SetAlpha(0) else o.fill:SetAlpha(o.alpha or 1) end
	if frac >= 1 then o.bg:SetAlpha(0) else o.bg:SetAlpha(o.bgAlpha or 0.3) end
end

local function ShowOverlay(o, health, frac, key, r, g, b, alpha, fullBg)
	local path = P.OverlayTexPath(key)
	if not path then
		o.fill:Hide()
		o.bg:Hide()
		o.on = nil
		return
	end
	o.on = true
	o.isStripe = ENP.OVERLAY_STRIPE_KEYS[key] == true
	o.alpha = alpha or 1
	o.bgAlpha = fullBg and o.alpha or o.alpha * 0.3
	o.fill:SetTexture(path)
	o.bg:SetTexture(path)
	o.fill:SetVertexColor(r, g, b)
	o.bg:SetVertexColor(r, g, b)
	LayoutOverlay(o, health, frac, o.isStripe)
	o.fill:Show()
	o.bg:Show()
end

local function HideOverlay(o)
	if o then
		o.on = nil
		o.fill:Hide()
		o.bg:Hide()
	end
end

-------------------------------------------------------------------------------
--  Build (once per Blizzard plate)
-------------------------------------------------------------------------------
function Plate:Build()
	local health = CreateFrame("StatusBar", nil, self)
	self.health = health
	health:SetStatusBarTexture(WHITE)
	health:SetMinMaxValues(0, 1)
	health:SetValue(1)
	self.healthBG = health:CreateTexture(nil, "BACKGROUND")
	self.healthBG:SetAllPoints()
	self.healthBG:SetTexture(WHITE)

	-- Absorb overlay (drawn from the end of the fill, clamped to the bar).
	self.absorb = health:CreateTexture(nil, "ARTWORK", nil, 3)
	self.absorb:Hide()

	self.hashLine = health:CreateTexture(nil, "OVERLAY", nil, 3)
	self.hashLine:SetTexture(1, 1, 1, 0.8)
	self.hashLine:SetWidth(2)
	self.hashLine:Hide()

	-- Border (own frame, over the fill).
	self.borderFrame = CreateFrame("Frame", nil, health)
	self.borderFrame:SetAllPoints(health)
	self.border = P.CreateEdges(self.borderFrame, health, "OVERLAY", 7)

	-- Mouseover wash and target wash.
	self.highlight = health:CreateTexture(nil, "OVERLAY", nil, 6)
	self.highlight:SetAllPoints(health)
	self.highlight:SetTexture(WHITE)
	self.highlight:Hide()
	self.targetHighlight = health:CreateTexture(nil, "OVERLAY", nil, 5)
	self.targetHighlight:SetAllPoints(health)
	self.targetHighlight:SetTexture(WHITE)
	self.targetHighlight:Hide()

	-- Overlay textures (focus, target, hover).
	self.focusOv = MakeOverlay(self, 2)
	self.targetOv = MakeOverlay(self, 4)
	self.hoverOv = MakeOverlay(self, 6)

	-- Text tier.
	self.textFrame = CreateFrame("Frame", nil, self)
	self.textFrame:SetAllPoints(health)
	self.texts = {}
	for i, s in ipairs(TEXT_SLOTS) do
		self.texts[s.key] = P.NewText(self.textFrame, 10)
	end
	self.focusLetter = P.NewText(self.textFrame, 18)
	self.focusLetter:SetText("F")
	self.focusLetter:Hide()

	-- Friendly name-only text.
	self.friendlyName = P.NewText(self.textFrame, 15)
	self.friendlyName:Hide()

	-- Indicator tier: raid markers and Rare / Quest.
	self.indFrame = CreateFrame("Frame", nil, self)
	self.indFrame:SetAllPoints(health)
	self.raid = self.indFrame:CreateTexture(nil, "ARTWORK")
	self.raid:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	self.raid:Hide()
	self.nameRaid = self.textFrame:CreateTexture(nil, "ARTWORK")
	self.nameRaid:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	self.nameRaid:Hide()
	self.classIcon = self.indFrame:CreateTexture(nil, "ARTWORK")
	self.classIcon:Hide()
	self.classText = P.NewText(self.indFrame, 14)
	self.classText:Hide()

	-- Arrows.
	self.leftArrow = self.indFrame:CreateTexture(nil, "OVERLAY")
	self.rightArrow = self.indFrame:CreateTexture(nil, "OVERLAY")
	self.leftArrow:Hide()
	self.rightArrow:Hide()

	-- Glows behind the bar.
	self.glow = MakeGlowFrame(self, GLOW_TEX)
	self.lowHpGlow = MakeGlowFrame(self, EXEC_TEX)
	self.lowHpGlow:SetColor(1, 0, 0, 1)
	local ag = self.lowHpGlow:CreateAnimationGroup()
	ag:SetLooping("BOUNCE")
	local a = ag:CreateAnimation("Alpha")
	a:SetChange(-0.65)
	a:SetDuration(0.55)
	a:SetSmoothing("IN_OUT")
	self.lowHpPulse = ag
	self.naGlow = MakeGlowFrame(self, EXEC_TEX)
	self.naGlow:SetColor(1, 0, 0, 1)

	if P.BuildCast then P.BuildCast(self) end
	if P.BuildAuras then P.BuildAuras(self) end
	self:ApplyLayout()
end

-------------------------------------------------------------------------------
--  Frame levels: everything of one plate in a band, the target plate's band
--  on top (5.4.8 frame levels stop near 128).
-------------------------------------------------------------------------------
function Plate:SetLevels(base)
	self:SetFrameLevel(base)
	self.glow:SetFrameLevel(base)
	self.lowHpGlow:SetFrameLevel(base)
	self.naGlow:SetFrameLevel(base)
	self.health:SetFrameLevel(base + 2)
	self.borderFrame:SetFrameLevel(base + 4)
	if self.cast then
		-- Casts In Front of Nameplates (retail castOverlayEnabled): the cast
		-- pieces draw a strata above every plate.
		local strata = P.Profile().castOverlayEnabled and "HIGH" or self:GetFrameStrata()
		for _, fr in ipairs({ self.cast, self.castBorderFrame, self.castIconFrame, self.castTextFrame }) do
			if fr and fr:GetFrameStrata() ~= strata then fr:SetFrameStrata(strata) end
		end
		self.cast:SetFrameLevel(base + 2)
		if self.castBorderFrame then self.castBorderFrame:SetFrameLevel(base + 4) end
		if self.castIconFrame then self.castIconFrame:SetFrameLevel(base + 3) end
		-- Cast texts over both borders (health bottom edge, cast edges).
		if self.castTextFrame then self.castTextFrame:SetFrameLevel(base + 9) end
	end
	self.indFrame:SetFrameLevel(base + 5)
	if self.auraRows then
		for _, row in pairs(self.auraRows) do
			row:SetFrameLevel(base + 6)
		end
	end
	self.textFrame:SetFrameLevel(base + 9)
end

-------------------------------------------------------------------------------
--  Layout from the settings (sizes, fonts, anchors). Runs on build and after
--  every settings change.
-------------------------------------------------------------------------------
function Plate:ApplyLayout()
	local p = P.Profile()
	local friendlyBar = self.isFriendly and not P.On("friendlyNameOnly")
	local w = friendlyBar and P.FriendlyW() or P.HealthW()
	local h = friendlyBar and P.FriendlyH() or P.HealthH()
	local yOff = (p.nameplateYOffset or 0) + (self.isFriendly and (p.friendlyPlateYOffset or 0) or 0)
	self.barW, self.barH = w, h
	local health = self.health
	health:ClearAllPoints()
	health:SetPoint("CENTER", self, "CENTER", 0, yOff)
	health:SetSize(w, h)
	health:SetStatusBarTexture(P.TexturePath(p.healthBarTexture))
	-- Textured Background (enemy plates): the background takes the bar
	-- texture, tinted by the Background color.
	self.healthBG:SetTexture((p.healthTextureBg and not self.isFriendly) and P.TexturePath(p.healthBarTexture) or WHITE)
	local bg = p.bgColor or defaults.bgColor
	self.healthBG:SetVertexColor(bg.r, bg.g, bg.b, p.bgAlpha or 1)
	self:ApplyBorder()

	-- Texts: font, size, anchor, color per slot.
	local outline = P.Outline()
	local nameSlot
	for _, s in ipairs(TEXT_SLOTS) do
		local fs = self.texts[s.key]
		local el = p[s.key] or defaults[s.key] or "none"
		local size = p[s.key .. "Size"] or 10
		if NAME_FAMILY[el] then
			nameSlot = nameSlot or s.key
			size = p[s.key .. "Size"] or p.enemyNameTextSize or 10
		end
		P.SetFont(fs, size, outline)
		fs:ClearAllPoints()
		local x = s.x + (p[s.key .. "XOffset"] or 0)
		local y = s.y + (p[s.key .. "YOffset"] or 0)
		if s.bottom and self.castShown then
			fs:SetPoint(s.point, self.cast, s.rel, x, y)
		else
			fs:SetPoint(s.point, health, s.rel, x, y)
		end
		if s.point == "LEFT" or s.point == "TOPLEFT" then
			fs:SetJustifyH("LEFT")
		elseif s.point == "RIGHT" or s.point == "TOPRIGHT" then
			fs:SetJustifyH("RIGHT")
		else
			fs:SetJustifyH("CENTER")
		end
		-- Name width: the bar width (top / center) or half of it (sides), in
		-- percent of Enemy Name Width.
		if NAME_FAMILY[el] then
			local pct = (p.enemyNameWidthPct or 100) / 100
			local nw = (s.key == "textSlotTop" or s.key == "textSlotCenter") and w or (w * 0.62)
			if p.nameRaidMarkerEnabled and s.key == "textSlotTop" then
				nw = nw - (p.nameRaidMarkerSize or 14)
			end
			fs:SetWidth(max(20, nw * pct))
			fs:SetWordWrap(p.enemyNameWrap == true)
		else
			fs:SetWidth(0)
			fs:SetWordWrap(false)
		end
		fs.element = el
	end
	self.nameSlot = nameSlot


	-- Focus letter.
	P.SetFont(self.focusLetter, p.focusLetterSize or 18, outline)
	self.focusLetter:ClearAllPoints()
	local fa = p.focusLetterAnchor or "CENTER"
	self.focusLetter:SetPoint(fa, health, fa, p.focusLetterX or 0, p.focusLetterY or 0)

	-- Friendly name-only.
	local fsz = (self.kind == "FRIENDLY_NPC") and (p.friendlyNPCNameSize or 13) or (p.friendlyNameSize or 15)
	P.SetFont(self.friendlyName, fsz, outline)
	self.friendlyName:ClearAllPoints()
	self.friendlyName:SetPoint("CENTER", self, "CENTER", 0, (p.friendlyNameOnlyYOffset or 0) + 20)

	-- Raid marker.
	local rmSize = p.raidMarkerSize or 24
	self.raid:SetSize(rmSize, rmSize)
	self.nameRaid:SetSize(p.nameRaidMarkerSize or 14, p.nameRaidMarkerSize or 14)

	-- Target arrows.
	local st = P.ArrowStyle()
	local sc = p.targetArrowScale or 1
	self.leftArrow:SetTexture(ENP.TARGET_ARROW_DIR .. st.l)
	self.rightArrow:SetTexture(ENP.TARGET_ARROW_DIR .. st.r)
	self.leftArrow:SetSize(floor(st.w * sc + 0.5), floor(16 * sc + 0.5))
	self.rightArrow:SetSize(floor(st.w * sc + 0.5), floor(16 * sc + 0.5))

	-- Hitbox size (Blizzard plate size, out of combat).
	self:ApplyHitbox()

	if self.ApplyCastLayout then self:ApplyCastLayout() end
	if self.ApplyAuraLayout then self:ApplyAuraLayout() end
	self:SetLevels(self.isTarget and 60 or 10)
	local base = self.blizz:GetFrameStrata()
	self.textFrame:SetFrameStrata(base)
	self._layoutDirty = nil
end

function Plate:ApplyHitbox()
	local p = P.Profile()
	local friendlyBar = self.isFriendly and not P.On("friendlyNameOnly")
	local w = friendlyBar and P.FriendlyW() or P.HealthW()
	local h = friendlyBar and P.FriendlyH() or P.HealthH()
	-- The client sizes the NamePlate frame from its bar frame (first child),
	-- so the hitbox / stacking box goes on the bar frame (ElvUI Mists does
	-- the same); its scale is < 1 on trivial units.
	local bar = self.bBar
	local be = bar:GetEffectiveScale()
	local base = (be and be > 0) and UIParent:GetEffectiveScale() / be or P.BaseScale(self)
	local hw = w * base * (p.hitboxScaleX or 100) / 100
	local hh = h * base * (p.hitboxScaleY or 100) / 100
	-- Near-zero boxes break the 5.4.8 stacking code (nameplateMotion 1): plates
	-- next to one keep climbing until they leave the screen. Plate frames are
	-- also reused between friendly and enemy units and the size can only change
	-- out of combat, so an enemy can keep a stale tiny box for a whole fight.
	-- So friendly plates only get the click-through box when stacking is off;
	-- with stacking on they stack with the enemy plates.
	if self.isFriendly and p.friendlyClickThrough and p.stackingEnabled == false then
		hw, hh = 0.001, 0.001
	end
	P.AfterCombat(bar, function()
		bar:SetSize(hw, hh)
	end)
end

function Plate:ApplyBorder(sizeOverride)
	local p = P.Profile()
	local size, r, g, b, a
	if p.customBorderEnabled then
		size = p.customBorderSize or 1
		local c = p.customBorderColor or defaults.customBorderColor
		r, g, b, a = c.r, c.g, c.b, p.customBorderAlpha or 1
	else
		size = p.showBorder ~= false and (p.borderSize or 1) or 0
		local c = p.borderColor or defaults.borderColor
		r, g, b, a = c.r, c.g, c.b, 1
	end
	if sizeOverride then size = sizeOverride end
	self.baseBorderR, self.baseBorderG, self.baseBorderB, self.baseBorderA = r, g, b, a
	if self.threatBorderR then
		r, g, b = self.threatBorderR, self.threatBorderG, self.threatBorderB
	end
	P.LayoutEdges(self.border, size, r, g, b, a)
end

-- Recolors the border: target / hover border color over threat over base.
function Plate:ApplyBorderColor()
	local r, g, b, a = self.baseBorderR or 0, self.baseBorderG or 0, self.baseBorderB or 0, self.baseBorderA or 1
	if self.threatBorderR then
		r, g, b = self.threatBorderR, self.threatBorderG, self.threatBorderB
	end
	if self.isTarget and P.TargetGlowBorderColor() and (not self.isFriendly or P.On("friendlyTargetBorderFx")) then
		r, g, b = P.Color("targetBorderColor")
		a = 1
	elseif self.isMouseover and P.HoverGlowBorderColor() then
		local c = P.Profile().hoverBorderColor or P.Get("targetBorderColor")
		r, g, b, a = c.r, c.g, c.b, 1
	end
	P.ColorEdges(self.border, r, g, b, a)
	-- Cast icon Use Target Border Color (retail castIconTargetBorder): the
	-- target's spell icon border takes the target border color.
	if self.castIconBG then
		if self.isTarget and P.Profile().castIconTargetBorder then
			local tr, tg, tb = P.Color("targetBorderColor")
			self.castIconBG:SetTexture(tr, tg, tb, 1)
		else
			self.castIconBG:SetTexture(0, 0, 0, 1)
		end
	end
end

-------------------------------------------------------------------------------
--  Full refresh of a shown plate
-------------------------------------------------------------------------------
function Plate:Refresh()
	self:ApplyLayout()
	self:ApplyMode()
	self:UpdateHealth()
	self:UpdateColor()
	self:UpdateTexts()
	self:UpdateRaidIcon()
	self:UpdateClassification()
	self:UpdateTarget()
	self:UpdateMouseover()
	if self.RefreshCast then self:RefreshCast() end
	if self.UpdateAuras then self:UpdateAuras() end
end

-- New unit token (target / mouseover / focus came or went).
function Plate:OnUnitChanged()
	self:UpdateColor()
	self:UpdateTexts()
	self:UpdateClassification()
	self:UpdateFocus()
	if self.UpdateAuras then self:UpdateAuras() end
	if self.RefreshCastTarget then self:RefreshCastTarget() end
end

function Plate:SlowUpdate()
	if self.unit then
		self:UpdateAbsorb()
		local tot = false
		for _, s in ipairs(TEXT_SLOTS) do
			if self.texts[s.key].element == "targetOfTarget" then tot = true end
		end
		if tot then self:UpdateTexts() end
	end
	if self.UpdateAuraTimers then self:UpdateAuraTimers() end
end

-- Friendly name-only plates hide the bar; friendly NPCs can be hidden.
function Plate:ApplyMode()
	local p = P.Profile()
	local hidden = false
	if self.isFriendly then
		if self.kind == "FRIENDLY_NPC" and not p.showFriendlyNPCs then
			hidden = true
		elseif self.kind == "FRIENDLY_PLAYER" and p.showFriendlyPlayers == false then
			hidden = true
		end
	end
	self.hiddenPlate = hidden
	local nameOnly = self.isFriendly and P.On("friendlyNameOnly")
	self.nameOnly = nameOnly
	if hidden then
		self:SetAlpha(0)
	else
		self:ApplyAlpha()
	end
	if nameOnly then
		self.health:Hide()
		self.textFrame:Show()
		for _, fs in pairs(self.texts) do fs:Hide() end
		self.friendlyName:Show()
	else
		self.health:Show()
		for _, fs in pairs(self.texts) do fs:Show() end
		self.friendlyName:Hide()
	end
end

-------------------------------------------------------------------------------
--  Health
-------------------------------------------------------------------------------
function Plate:HealthValues()
	local cur = self.bHealth:GetValue() or 0
	local _, mx = self.bHealth:GetMinMaxValues()
	mx = mx or 1
	if mx <= 0 then mx = 1 end
	return cur, mx
end

function Plate:UpdateHealth()
	local cur, mx = self:HealthValues()
	self.health:SetMinMaxValues(0, mx)
	self.health:SetValue(cur)
	local frac = cur / mx
	self.healthFrac = frac
	for _, o in ipairs({ self.focusOv, self.targetOv, self.hoverOv }) do
		if o.on then LayoutOverlay(o, self.health, frac, o.isStripe) end
	end
	self:UpdateHealthTexts(cur, mx)
	self:UpdateAbsorb()
	-- Hash line on the target.
	local p = P.Profile()
	if p.hashLineEnabled and self.isTarget and (p.hashLinePercent or 0) > 0 then
		local x = self.barW * (p.hashLinePercent / 100)
		local c = p.hashLineColor or defaults.hashLineColor
		self.hashLine:ClearAllPoints()
		self.hashLine:SetPoint("TOP", self.health, "TOPLEFT", x, 0)
		self.hashLine:SetPoint("BOTTOM", self.health, "BOTTOMLEFT", x, 0)
		self.hashLine:SetVertexColor(c.r, c.g, c.b, 0.8)
		self.hashLine:Show()
	else
		self.hashLine:Hide()
	end
	self:ApplyLowHpGlow()
end

function Plate:UpdateAbsorb()
	local p = P.Profile()
	local style = p.absorbStyle or "blizzard"
	local amount = 0
	if style ~= "none" and self.unit and UnitGetTotalAbsorbs then
		amount = UnitGetTotalAbsorbs(self.unit) or 0
	end
	if amount <= 0 or self.nameOnly then
		self.absorb:Hide()
		return
	end
	local cur, mx = self:HealthValues()
	local w = self.barW or self.health:GetWidth()
	local fillW = w * cur / mx
	local absW = min(w * amount / mx, w - fillW)
	local overlay = (p.absorbEdgeMode or "overlay") ~= "right" and absW < 1
	if absW < 1 then
		-- Bar full: the shield draws over the end of the fill (overlay mode).
		absW = min(w * amount / mx, w)
		fillW = w - absW
	end
	local tex = ENP.ABSORB_STYLE_TEX[style] or WHITE
	self.absorb:SetTexture(tex)
	local c = p.absorbColor or defaults.absorbColor
	local a = ENP.ABSORB_STYLE_ALPHA[style] or 0.8
	if style == "clean" then a = (p.absorbCleanAlpha or 30) / 100 end
	self.absorb:SetVertexColor(c.r, c.g, c.b, a)
	self.absorb:ClearAllPoints()
	self.absorb:SetPoint("TOPLEFT", self.health, "TOPLEFT", fillW, 0)
	self.absorb:SetPoint("BOTTOMLEFT", self.health, "BOTTOMLEFT", fillW, 0)
	self.absorb:SetWidth(max(absW, 0.01))
	self.absorb:Show()
end

function Plate:ApplyLowHpGlow()
	local th = P.ExecuteThreshold()
	if P.Profile().lowHpGlow and th and not self.isFriendly and not self.nameOnly
		and (self.healthFrac or 1) <= th and (self.healthFrac or 1) > 0 then
		if not self.lowHpGlow:IsShown() then
			self.lowHpGlow:Show()
			self.lowHpPulse:Play()
		end
	elseif self.lowHpGlow:IsShown() then
		self.lowHpPulse:Stop()
		self.lowHpGlow:Hide()
	end
end

-------------------------------------------------------------------------------
--  Color (bar, threat border / text channels, near aggro glow, overlays)
-------------------------------------------------------------------------------
function Plate:UpdateColor()
	local r, g, b
	if self.isFriendly then
		r, g, b = self:GetFriendlyColor()
	else
		r, g, b = self:GetReactionColor()
	end
	local p = P.Profile()
	-- Debuff Based Nameplate Coloring: the bar (Color Nameplate) or the
	-- border (Color Border) takes the matched debuff's color.
	local dcr = self.debuffColorR and p.debuffColorsEnabled and not self.isFriendly
	if dcr and not p.debuffColorsBorder then
		r, g, b = self.debuffColorR, self.debuffColorG, self.debuffColorB
	end
	self.barR, self.barG, self.barB = r, g, b
	self.health:SetStatusBarColor(r, g, b)

	local tr, tg, tb
	if (p.threatColorBorder or p.threatColorName) and not self.isFriendly then
		tr, tg, tb = self:ResolveThreatColor()
	end
	if p.threatColorBorder and tr then
		self.threatBorderR, self.threatBorderG, self.threatBorderB = tr, tg, tb
	else
		self.threatBorderR, self.threatBorderG, self.threatBorderB = nil, nil, nil
	end
	if dcr and p.debuffColorsBorder then
		self.threatBorderR, self.threatBorderG, self.threatBorderB = self.debuffColorR, self.debuffColorG, self.debuffColorB
		local extra = p.debuffColorsBorderExtra or 0
		if extra > 0 and not self._dcThick then
			self._dcThick = true
			self:ApplyBorder(((p.customBorderEnabled and p.customBorderSize) or p.borderSize or 1) + extra)
		end
	elseif self._dcThick then
		self._dcThick = nil
		self:ApplyBorder()
	end
	self:ApplyBorderColor()
	self.threatNameR, self.threatNameG, self.threatNameB = nil, nil, nil
	if p.threatColorName and tr then
		self.threatNameR, self.threatNameG, self.threatNameB = tr, tg, tb
	end
	self:ColorTexts()

	local na = self._nearAggro and p.threatNearAggroGlow == true
	if na then self.naGlow:Show() else self.naGlow:Hide() end
	self:UpdateFocus()
	self:UpdateTargetOverlay()
	if self.isMouseover then self:UpdateMouseover() end
end

-------------------------------------------------------------------------------
--  Texts
-------------------------------------------------------------------------------
local function LevelColorHex(self)
	return format("|cff%02x%02x%02x", floor((self.levelR or 1) * 255), floor((self.levelG or 1) * 255), floor((self.levelB or 1) * 255))
end

local function LevelText(self)
	if (self.level or 0) < 0 then return "??" end
	return tostring(self.level or "")
end

function Plate:ToTName()
	if not self.unit then return "" end
	local tu = self.unit .. "target"
	if not UnitExists(tu) then return "" end
	local name = UnitName(tu) or ""
	if UnitIsPlayer(tu) then
		local _, cls = UnitClass(tu)
		local c = cls and ((EllesmereUI.GetClassColor and RAID_CLASS_COLORS[cls] and EllesmereUI.GetClassColor(cls)) or RAID_CLASS_COLORS[cls])
		if c then
			return format("|cff%02x%02x%02x%s|r", floor(c.r * 255), floor(c.g * 255), floor(c.b * 255), name)
		end
	end
	return name
end

-- Shorten Enemy Names (ElvUI [name:abbrev] / [name:short] style).
-- "abbrev": every word but the last becomes its initial ("Kor'kron Dark
-- Shaman" -> "K. D. Shaman"), only when the name is longer than the limit.
-- "truncate": cut to the limit in characters. UTF-8 safe.
local UTF8_CHAR = "[%z\1-\127\194-\244][\128-\191]*"
local function Utf8Len(s)
	local n = 0
	for _ in s:gmatch(UTF8_CHAR) do n = n + 1 end
	return n
end
local function Utf8Sub(s, len)
	local out, n = {}, 0
	for c in s:gmatch(UTF8_CHAR) do
		n = n + 1
		if n > len then break end
		out[n] = c
	end
	return table.concat(out)
end
local shortCache, shortMode, shortLen = {}, nil, nil
local function ShortName(name, mode, len)
	if mode ~= shortMode or len ~= shortLen then
		wipe(shortCache)
		shortMode, shortLen = mode, len
	end
	local v = shortCache[name]
	if v then return v end
	v = name
	if Utf8Len(name) > len then
		if mode == "abbrev" then
			v = name:gsub("(%S+)%s+", function(w) return Utf8Sub(w, 1) .. ". " end)
		elseif mode == "truncate" then
			v = Utf8Sub(name, len)
		end
	end
	shortCache[name] = v
	return v
end

function Plate:UpdateTexts()
	local p = P.Profile()
	local name = self.name or ""
	local fullName = name
	local sm = p.enemyNameShorten
	if sm == "abbrev" or sm == "truncate" then
		name = ShortName(name, sm, p.enemyNameShortenLen or 20)
	end
	for _, s in ipairs(TEXT_SLOTS) do
		local fs = self.texts[s.key]
		local el = fs.element
		if el == "enemyName" then
			fs:SetText(name)
		elseif el == "levelName" or el == "nameLevel" then
			local lvl = LevelText(self)
			local diff = p[s.key .. "LevelDiffOn"]
			if diff == nil then diff = p.levelDifficultyColor == true end
			-- Custom Name / Level Color (retail <slot>NameColorOn / LevelColorOn).
			local function Hex(c)
				return format("|cff%02x%02x%02x", floor((c.r or 1) * 255), floor((c.g or 1) * 255), floor((c.b or 1) * 255))
			end
			if p[s.key .. "LevelColorOn"] and p[s.key .. "LevelColor"] then
				lvl = Hex(p[s.key .. "LevelColor"]) .. lvl .. "|r"
			elseif diff and P.SlotColorMode(s.key) ~= "level" then
				lvl = LevelColorHex(self) .. lvl .. "|r"
			end
			local nm = name
			if p[s.key .. "NameColorOn"] and p[s.key .. "NameColor"] then
				nm = Hex(p[s.key .. "NameColor"]) .. name .. "|r"
			end
			if el == "levelName" then
				fs:SetText(lvl .. " | " .. nm)
			else
				fs:SetText(nm .. " | " .. lvl)
			end
		elseif el == "level" then
			fs:SetText(LevelText(self))
		elseif el == "targetOfTarget" then
			fs:SetText(self:ToTName())
		elseif not HEALTH_ELEMENTS[el] then
			fs:SetText("")
		end
	end
	-- Hide the name while casting (Hide Enemy Name While Casting).
	if self.nameSlot then
		local fs = self.texts[self.nameSlot]
		if self.castShown and p.hideEnemyNameWhileCasting then
			fs:SetAlpha(0)
		else
			fs:SetAlpha(1)
		end
	end
	-- Friendly name-only text.
	self.friendlyName:SetText(fullName)
	local cur, mx = self:HealthValues()
	self:UpdateHealthTexts(cur, mx)
	self:ColorTexts()
	self:PlaceNameRaid()
end

function Plate:UpdateHealthTexts(cur, mx)
	local pct = mx > 0 and (cur / mx * 100) or 0
	local dead = cur <= 0
	local num = P.Abbrev(cur)
	local p = P.Profile()
	for _, s in ipairs(TEXT_SLOTS) do
		local fs = self.texts[s.key]
		local el = fs.element
		if HEALTH_ELEMENTS[el] then
			local dec = p[s.key .. "PctDecimal"] == true
			local pctText = dead and (dec and "0.0" or "0") or (dec and format("%.1f", pct) or format("%d", floor(pct)))
			if el == "healthPercent" then
				fs:SetText(pctText .. "%")
			elseif el == "healthPercentNoSign" then
				fs:SetText(pctText)
			elseif el == "healthNumber" then
				fs:SetText(dead and "0" or num)
			elseif el == "healthPctNum" then
				fs:SetText(pctText .. "% | " .. num)
			elseif el == "healthNumPct" then
				fs:SetText(num .. " | " .. pctText .. "%")
			elseif el == "healthPctNumDash" then
				fs:SetText(pctText .. "% - " .. num)
			elseif el == "healthNumPctDash" then
				fs:SetText(num .. " - " .. pctText .. "%")
			end
		end
	end
end

-- Core Text Coloring mode of a slot (retail ns.NP_SlotColorMode).
function P.SlotColorMode(slotKey)
	local p = P.Profile()
	local el = p[slotKey] or defaults[slotKey]
	local m = p[slotKey .. "ColorMode"]
	if m == "class" or m == "custom" then return m end
	if m == "level" then return (el ~= "targetOfTarget") and "level" or "custom" end
	if el == "level" and p.levelDifficultyColor == true then return "level" end
	if p[slotKey .. "ClassColor"] == true then return "class" end
	if p.enemyNameTextReactionColor == true and NAME_FAMILY[el] then
		for _, s in ipairs(TEXT_SLOTS) do
			if NAME_FAMILY[p[s.key] or defaults[s.key]] then
				if s.key == slotKey then return "class" end
				break
			end
		end
	end
	return "custom"
end

function Plate:ClassTextColor()
	if self.isPlayer and self.class then
		local c = ((EllesmereUI.GetClassColor and RAID_CLASS_COLORS[self.class] and EllesmereUI.GetClassColor(self.class)) or RAID_CLASS_COLORS[self.class])
		if c then return c.r, c.g, c.b end
	end
	local p = P.Profile()
	if self.reaction == 4 then
		local c = p.enemyNameNeutralColor or defaults.neutral
		return c.r, c.g, c.b
	end
	local c = p.enemyNameHostileColor or defaults.hostile
	return c.r, c.g, c.b
end

function Plate:ColorTexts()
	local p = P.Profile()
	for _, s in ipairs(TEXT_SLOTS) do
		local fs = self.texts[s.key]
		local el = fs.element
		local r, g, b
		if NAME_FAMILY[el] and self.threatNameR then
			r, g, b = self.threatNameR, self.threatNameG, self.threatNameB
		else
			local mode = P.SlotColorMode(s.key)
			if mode == "class" then
				r, g, b = self:ClassTextColor()
			elseif mode == "level" then
				r, g, b = self.levelR or 1, self.levelG or 1, self.levelB or 1
			else
				local c = p[s.key .. "Color"] or defaults[s.key .. "Color"] or defaults.textSlotTopColor
				r, g, b = c.r, c.g, c.b
			end
		end
		fs:SetTextColor(r, g, b, 1)
	end
	-- Friendly names.
	local fr, fg, fb = 1, 1, 1
	if self.kind == "FRIENDLY_PLAYER" then
		if (p.friendlyNameClassColor or p.classColorFriendly) and self.class and RAID_CLASS_COLORS[self.class] then
			local c = ((EllesmereUI.GetClassColor and RAID_CLASS_COLORS[self.class] and EllesmereUI.GetClassColor(self.class)) or RAID_CLASS_COLORS[self.class])
			fr, fg, fb = c.r, c.g, c.b
		end
	elseif self.kind == "FRIENDLY_NPC" then
		fr, fg, fb = P.Color("friendlyNPCNameColor")
	end
	self.friendlyName:SetTextColor(fr, fg, fb, 1)
end

-------------------------------------------------------------------------------
--  Raid marker (raidMarkerPos slot, or next to the name)
-------------------------------------------------------------------------------
function Plate:PlaceNameRaid()
	local p = P.Profile()
	local nr = self.nameRaid
	if not (p.nameRaidMarkerEnabled and self.raidIndex and self.nameSlot) then
		nr:Hide()
		return
	end
	local fs = self.texts[self.nameSlot]
	local tw = min(fs:GetStringWidth() or 0, fs:GetWidth() or 0)
	nr:ClearAllPoints()
	local jh = fs:GetJustifyH()
	if jh == "LEFT" then
		nr:SetPoint("RIGHT", fs, "LEFT", -2, 0)
	elseif jh == "RIGHT" then
		nr:SetPoint("RIGHT", fs, "RIGHT", -tw - 2, 0)
	else
		nr:SetPoint("RIGHT", fs, "CENTER", -tw / 2 - 2, 0)
	end
	nr:Show()
end

function Plate:UpdateRaidIcon()
	local p = P.Profile()
	local idx = self.raidIndex
	if idx then
		local col = (idx - 1) % 4
		local row = floor((idx - 1) / 4)
		self.raid:SetTexCoord(col / 4, (col + 1) / 4, row / 4, (row + 1) / 4)
		self.nameRaid:SetTexCoord(col / 4, (col + 1) / 4, row / 4, (row + 1) / 4)
	end
	local pos = p.raidMarkerPos or "topright"
	if not idx or pos == "none" or self.nameOnly then
		self.raid:Hide()
	else
		self.raid:ClearAllPoints()
		self:AnchorSlotElement(self.raid, pos, "raidMarker")
		self.raid:Show()
	end
	self:PlaceNameRaid()
end

-- Places an indicator in a Core Positions slot (retail UpdateClassification
-- / raid marker anchors).
function Plate:AnchorSlotElement(obj, slot, offKey)
	local p = P.Profile()
	local xo = p[offKey .. "XOffset"] or 0
	local yo = p[offKey .. "YOffset"] or 0
	local health = self.health
	local side = p.sideAuraXOffset or 2
	if slot == "top" then
		obj:SetPoint("BOTTOM", health, "TOP", xo, (p.debuffYOffset or 2) + yo)
	elseif slot == "left" then
		obj:SetPoint("RIGHT", health, "LEFT", -side + xo, yo)
	elseif slot == "right" then
		obj:SetPoint("LEFT", health, "RIGHT", side + xo, yo)
	elseif slot == "topleft" then
		obj:SetPoint("BOTTOMLEFT", health, "TOPLEFT", xo, 2 + yo)
	elseif slot == "topright" then
		obj:SetPoint("BOTTOMRIGHT", health, "TOPRIGHT", xo, 2 + yo)
	elseif slot == "bottom" then
		obj:SetPoint("TOP", (self.castShown and self.cast) or health, "BOTTOM", xo, -2 + yo)
	else
		obj:SetPoint("CENTER", health, "CENTER", xo, yo)
	end
end

-------------------------------------------------------------------------------
--  Rare / Quest indicator (classificationSlot)
-------------------------------------------------------------------------------
local ELITE_TEX = "Interface\\Tooltips\\EliteNameplateIcon"
local QUEST_TEX = "Interface\\GossipFrame\\AvailableQuestIcon"

function Plate:UpdateClassification()
	local p = P.Profile()
	local slot = p.classificationSlot or "topleft"
	self.classIcon:Hide()
	self.classText:Hide()
	if slot == "none" or self.isFriendly or self.isPlayer or self.nameOnly then return end
	local _, iType = GetInstanceInfo()
	local inInstance = (iType == "party" or iType == "raid" or iType == "pvp" or iType == "arena")
	if inInstance and not p.classificationShowInInstances then return end
	local size = p.rareEliteIconSize or 20
	local obj
	local quest, objText = false, nil
	if not p.classificationHideQuest then
		quest, objText = self:IsQuestMob()
	end
	if quest then
		if p.replaceQuestIconWithObjective and objText then
			P.SetFont(self.classText, p.questObjectiveTextSize or 14, P.Outline())
			self.classText:SetText(objText)
			self.classText:SetTextColor(1, 0.82, 0, 1)
			obj = self.classText
		else
			self.classIcon:SetTexture(QUEST_TEX)
			self.classIcon:SetTexCoord(0, 1, 0, 1)
			self.classIcon:SetVertexColor(1, 1, 1)
			obj = self.classIcon
		end
	else
		if p.classificationHideRare then return end
		local c = self:Classification()
		if c == "elite" or c == "worldboss" or c == "rareelite" or c == "rare" then
			self.classIcon:SetTexture(ELITE_TEX)
			self.classIcon:SetTexCoord(0, 1, 0, 1)
			if c == "rareelite" or c == "rare" then
				self.classIcon:SetVertexColor(0.8, 0.85, 1)
			else
				self.classIcon:SetVertexColor(1, 0.82, 0.2)
			end
			obj = self.classIcon
		else
			return
		end
	end
	if obj == self.classIcon then
		self.classIcon:SetSize(size, size)
	end
	obj:ClearAllPoints()
	self:AnchorSlotElement(obj, slot, "classification")
	obj:Show()
end

-------------------------------------------------------------------------------
--  Target effects
-------------------------------------------------------------------------------
function Plate:UpdateTarget()
	local p = P.Profile()
	local isTarget = self.isTarget and not self.hiddenPlate
	-- EllesmereUI glow.
	if isTarget and P.TargetGlowEUI() and not self.nameOnly then
		local c = p.targetGlowColor or defaults.targetGlowColor
		self.glow:SetColor(c.r, c.g, c.b, p.targetGlowAlpha or 1)
		self.glow:Show()
	elseif not (self.isMouseover and P.HoverGlowEUI()) then
		self.glow:Hide()
	end
	-- Border size.
	local friendlyFx = not self.isFriendly or p.friendlyTargetBorderFx
	if isTarget and friendlyFx and P.TargetGlowBorderSize() and p.targetBorderSizeValue then
		self:ApplyBorder(p.targetBorderSizeValue)
		self._targetBorderSized = true
	elseif self._targetBorderSized then
		self._targetBorderSized = nil
		self:ApplyBorder()
	end
	self:ApplyBorderColor()
	-- Highlight wash.
	if isTarget and P.TargetGlowHighlight() and not self.nameOnly then
		local c = p.targetHighlightColor or defaults.targetHighlightColor
		self.targetHighlight:SetVertexColor(c.r, c.g, c.b, p.targetHighlightAlpha or 0.2)
		self.targetHighlight:Show()
	else
		self.targetHighlight:Hide()
	end
	-- Arrows.
	if isTarget and p.showTargetArrows then
		local r, g, b = P.ArrowColor()
		self.leftArrow:SetVertexColor(r, g, b)
		self.rightArrow:SetVertexColor(r, g, b)
		self:PlaceArrows()
		self.leftArrow:Show()
		self.rightArrow:Show()
	else
		self.leftArrow:Hide()
		self.rightArrow:Hide()
	end
	self:UpdateTargetOverlay()
	self:UpdateHealth()
	self:ApplyScale()
	self:ApplyAlphaAll()
	self:SetLevels(isTarget and 60 or 10)
	if self.ApplyCastColor and self.castShown then self:ApplyCastColor() end
end

function Plate:PlaceArrows()
	local gap = 3
	local leftAnchor, rightAnchor = self.health, self.health
	local lx, rx = -gap, gap
	if self.slotRows then
		local lr = self.slotRows.left
		local rr = self.slotRows.right
		if lr and lr:IsShown() and lr.count and lr.count > 0 then leftAnchor = lr.first or lr end
		if rr and rr:IsShown() and rr.count and rr.count > 0 then rightAnchor = rr.last or rr end
	end
	if self.castIconFrame and self.castShown and self.castIconFrame:IsShown() then
		local p = P.Profile()
		if not p.castIconOnRight and leftAnchor == self.health then
			lx = lx - (self.castIconFrame:GetWidth() or 0) * (self.castIconFrame:GetScale() or 1)
		end
	end
	self.leftArrow:ClearAllPoints()
	self.leftArrow:SetPoint("RIGHT", leftAnchor, "LEFT", lx, 0)
	self.rightArrow:ClearAllPoints()
	self.rightArrow:SetPoint("LEFT", rightAnchor, "RIGHT", rx, 0)
	if leftAnchor ~= self.health then
		self.leftArrow:ClearAllPoints()
		self.leftArrow:SetPoint("RIGHT", leftAnchor, "LEFT", lx, 0)
	end
end

function Plate:UpdateTargetOverlay()
	local p = P.Profile()
	local key = p.targetOverlayTexture or "none"
	if self.isTarget and key ~= "none" and not self.nameOnly then
		local r, g, b
		if p.targetOverlayNoTint then
			r, g, b = self.barR or 1, self.barG or 1, self.barB or 1
		else
			local c = p.targetOverlayColor or defaults.targetOverlayColor
			r, g, b = c.r, c.g, c.b
		end
		ShowOverlay(self.targetOv, self.health, self.healthFrac or 1, key, r, g, b, p.targetOverlayAlpha or 1, p.targetOverlayFullBgAlpha)
	else
		HideOverlay(self.targetOv)
	end
end

-------------------------------------------------------------------------------
--  Focus overlay and letter
-------------------------------------------------------------------------------
function Plate:UpdateFocus()
	local p = P.Profile()
	local key = p.focusOverlayTexture or "none"
	if self.isFocus and key ~= "none" and not self.nameOnly then
		local r, g, b
		if p.focusOverlayNoTint then
			r, g, b = self.barR or 1, self.barG or 1, self.barB or 1
		else
			local c = p.focusOverlayColor or defaults.focusOverlayColor
			r, g, b = c.r, c.g, c.b
		end
		ShowOverlay(self.focusOv, self.health, self.healthFrac or 1, key, r, g, b, p.focusOverlayAlpha or 1, p.focusOverlayFullBgAlpha)
	else
		HideOverlay(self.focusOv)
	end
	if self.isFocus and p.focusLetterEnabled and not self.nameOnly then
		self.focusLetter:Show()
	else
		self.focusLetter:Hide()
	end
end

-------------------------------------------------------------------------------
--  Hover effects
-------------------------------------------------------------------------------
function Plate:UpdateMouseover()
	local p = P.Profile()
	local on = self.isMouseover and not self.nameOnly and not self.hiddenPlate
	if on and P.HoverGlowHighlight() then
		local key = p.hoverOverlayTexture or "none"
		local c = p.hoverColor or defaults.hoverColor
		local a = p.hoverAlpha or 0.3
		if key ~= "none" then
			self.highlight:Hide()
			ShowOverlay(self.hoverOv, self.health, self.healthFrac or 1, key, c.r, c.g, c.b, a, p.hoverOverlayFullBgAlpha)
		else
			HideOverlay(self.hoverOv)
			self.highlight:SetVertexColor(c.r, c.g, c.b, a)
			self.highlight:Show()
		end
	else
		self.highlight:Hide()
		HideOverlay(self.hoverOv)
	end
	-- Hover extras: EllesmereUI glow, border size, border color (target wins).
	if on and P.HoverGlowEUI() and not (self.isTarget and P.TargetGlowEUI()) then
		local c = p.hoverGlowColor or p.targetGlowColor or defaults.targetGlowColor
		self.glow:SetColor(c.r, c.g, c.b, p.hoverGlowAlpha or p.targetGlowAlpha or 1)
		self.glow:Show()
	elseif not (self.isTarget and P.TargetGlowEUI()) then
		self.glow:Hide()
	end
	if on and P.HoverGlowBorderSize() and p.hoverBorderSizeValue and not self._targetBorderSized then
		self:ApplyBorder(p.hoverBorderSizeValue)
		self._hoverBorderSized = true
	elseif self._hoverBorderSized then
		self._hoverBorderSized = nil
		self:ApplyBorder()
	end
	self:ApplyBorderColor()
end

-------------------------------------------------------------------------------
--  Scale (Target Scale, Cast Scale) with the retail ease
-------------------------------------------------------------------------------
local scaleAnim = {}
local scaleDriver = CreateFrame("Frame")
scaleDriver:Hide()
scaleDriver:SetScript("OnUpdate", function(self, elapsed)
	local any = false
	local k = min(1, elapsed * 12)
	for plate in pairs(scaleAnim) do
		local cur = plate._curScale or 1
		local dest = plate._destScale or 1
		cur = cur + (dest - cur) * k
		if abs(dest - cur) < 0.004 then
			cur = dest
			scaleAnim[plate] = nil
		else
			any = true
		end
		plate._curScale = cur
		plate:SetScale(cur)
	end
	if not any then self:Hide() end
end)

-- 5.4.8 plates sit under WorldFrame (no UI scale); retail plates follow the
-- UI scale (parented to UIParent), so the UI scale is the base of every plate.
function P.BaseScale(plate)
	local parent = plate and plate.blizz or WorldFrame
	local pe = parent:GetEffectiveScale()
	if not pe or pe <= 0 then return 1 end
	return UIParent:GetEffectiveScale() / pe
end

function Plate:ApplyScale()
	local p = P.Profile()
	local dest = P.BaseScale(self)
	if self.isTarget then
		dest = dest * (p.targetScale or 100) / 100
	end
	if self.castShown and (p.castScale or 100) ~= 100 then
		dest = dest * (p.castScale / 100)
	end
	self._destScale = dest
	local cur = self._curScale
	if not cur or not self:IsVisible() then
		self._curScale = dest
		scaleAnim[self] = nil
		self:SetScale(dest)
	elseif abs(cur - dest) > 0.004 then
		scaleAnim[self] = true
		scaleDriver:Show()
	end
end

-------------------------------------------------------------------------------
--  Non-target opacity (retail ns.NT_Apply)
-------------------------------------------------------------------------------
local hasTargetNow = false
function P.RefreshHasTarget()
	hasTargetNow = UnitExists("target") and true or false
end

function Plate:ApplyAlpha()
	if self.hiddenPlate then
		self:SetAlpha(0)
		return
	end
	local p = P.Profile()
	-- Hide Enemy Nameplates out of Combat (retail hideEnemyPlatesOOC): 5.4.8
	-- keeps the nameplate CVar alone (it may not change in combat) and fades
	-- our enemy plates out instead; they return when combat starts.
	if p.hideEnemyPlatesOOC and not self.isFriendly and not InCombatLockdown() and not P._oocCombat then
		self:SetAlpha(0)
		return
	end
	local nt = (p.nonTargetAlpha or 100) / 100
	local a = 1
	if nt < 1 and hasTargetNow and not self.isTarget
		and not (p.nonTargetKeepFocus ~= false and self.isFocus) then
		a = nt
	end
	self:SetAlpha(a)
end

function Plate:ApplyAlphaAll()
	P.ForEachVisible(function(pl) pl:ApplyAlpha() end)
end

-------------------------------------------------------------------------------
--  Clean-up on hide
-------------------------------------------------------------------------------
function Plate:OnCleared()
	scaleAnim[self] = nil
	self._curScale = nil
	self:SetScale(P.BaseScale(self))
	self.glow:Hide()
	self.lowHpPulse:Stop()
	self.lowHpGlow:Hide()
	self.naGlow:Hide()
	self.highlight:Hide()
	self.targetHighlight:Hide()
	HideOverlay(self.focusOv)
	HideOverlay(self.targetOv)
	HideOverlay(self.hoverOv)
	self.leftArrow:Hide()
	self.rightArrow:Hide()
	self.threatBorderR = nil
	self._targetBorderSized, self._hoverBorderSized = nil, nil
	if self.ClearCast then self:ClearCast() end
	if self.ClearAuras then self:ClearAuras() end
end

-- The bottom text slots hang under the cast bar while it shows.
function Plate:AnchorBottomTexts()
	local p = P.Profile()
	for _, s in ipairs(TEXT_SLOTS) do
		if s.bottom then
			local fs = self.texts[s.key]
			fs:ClearAllPoints()
			local x = s.x + (p[s.key .. "XOffset"] or 0)
			local y = s.y + (p[s.key .. "YOffset"] or 0)
			fs:SetPoint(s.point, self.castShown and self.cast or self.health, s.rel, x, y)
		end
	end
	if self.raid:IsShown() and (p.raidMarkerPos == "bottom") then
		self:UpdateRaidIcon()
	end
	self:UpdateClassification()
end
