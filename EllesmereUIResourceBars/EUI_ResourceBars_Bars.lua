-------------------------------------------------------------------------------
--  EUI_ResourceBars_Bars.lua  (5.4.8 port of the EllesmereUI Resource Bars)
--
--  The health bar, the power bar and the class resource (pips, runes or a
--  bar), with the retail looks: pixel borders, fill opacity, gradients,
--  dark mode, per-spec threshold and multi-band colors, hash lines, text
--  formats, absorb overlays, Fade Out of Combat, the Visibility checklist,
--  Expand Power Bar / Shift Elements, druid per-form hiding and Unlock Mode.
--  5.4.8 has no StatusBar easing: "Smooth Bars" eases the value in Lua.
-------------------------------------------------------------------------------
local addonName, P = ...
local ns = P.ns
local ERB = P.ERB

local floor, ceil, abs, max, min = math.floor, math.ceil, math.abs, math.max, math.min
local format = string.format
local GetTime = GetTime

local mainFrame, healthBar, primaryBar, secondaryFrame, secondaryBar
local cachedSecondary, cachedPrimary
local frames = {}
ERB.frames = frames

local function Profile()
	return P.Profile()
end

local function IsVertical(ori)
	return ori == "VERTICAL_UP" or ori == "VERTICAL_DOWN" or ori == "VERTICAL"
end
P.IsVertical = IsVertical

local function OrientedSize(w, h, ori)
	if IsVertical(ori) then
		return h, w
	end
	return w, h
end
P.OrientedSize = OrientedSize

-------------------------------------------------------------------------------
--  Druid forms (retail barDisabledForms / textDisabledForms buckets)
-------------------------------------------------------------------------------
local playerClass = select(2, UnitClass("player"))

local function FormBucket(isClassResource)
	local f = GetShapeshiftFormID()
	if f == 31 or f == 35 then
		return isClassResource and nil or "moonkin"
	end
	if f == 1 then return "energy" end
	if f == 5 then return "rage" end
	return "mana"
end

function ERB.BarHiddenByForm(cfg, isClassResource)
	if playerClass ~= "DRUID" or not cfg or not cfg.barDisabledForms then
		return false
	end
	local key = FormBucket(isClassResource)
	return key and cfg.barDisabledForms[key] and true or false
end

function ERB.TextHiddenByForm(cfg, isClassResource)
	if playerClass ~= "DRUID" or not cfg or not cfg.textDisabledForms then
		return false
	end
	local key = FormBucket(isClassResource)
	return key and cfg.textDisabledForms[key] and true or false
end

-------------------------------------------------------------------------------
--  Textures, strata, gradients
-------------------------------------------------------------------------------
-- Health / power texture: their own one while "split" is on, else the main.
function ERB.BarTexture(p, key)
	local cfg = p[key]
	if p.splitTex and cfg and cfg.barTexture then
		return cfg.barTexture
	end
	return p.general.barTexture or "none"
end

function ERB.SetBarTexture(p, key, tex)
	p[key].barTexture = tex or nil
	p.splitTex = (p.health.barTexture or p.primary.barTexture) and true or false
end

local function Strata(p, key)
	local cfg = key and p[key]
	if cfg and cfg.frameStrata then
		return cfg.frameStrata
	end
	return p.general.frameStrata or "MEDIUM"
end

local function ApplyFill(tex, cfg, r, g, b, alpha)
	alpha = alpha or 1
	if cfg.gradientEnabled then
		tex:SetVertexColor(1, 1, 1, 1)
		local gr, gg, gb, ga = cfg.gradientR or 0.2, cfg.gradientG or 0.2, cfg.gradientB or 0.8, cfg.gradientA or 1
		if (cfg.gradientDir or "HORIZONTAL") == "VERTICAL" then
			-- SetGradientAlpha VERTICAL goes bottom to top: the base color on top.
			tex:SetGradientAlpha("VERTICAL", gr, gg, gb, ga * alpha, r, g, b, alpha)
		else
			tex:SetGradientAlpha("HORIZONTAL", r, g, b, alpha, gr, gg, gb, ga * alpha)
		end
	else
		tex:SetVertexColor(r, g, b, alpha)
	end
end
P.ApplyFill = ApplyFill

-------------------------------------------------------------------------------
--  Status bar frame (health, power, bar-type class resources)
-------------------------------------------------------------------------------
local function SmoothOnUpdate(self, elapsed)
	local cur, target = self._shown, self._target
	if not cur or not target then
		self:SetScript("OnUpdate", nil)
		return
	end
	local diff = target - cur
	local range = (self._max or 1) - (self._min or 0)
	if abs(diff) <= range * 0.002 then
		self._shown = target
		self.sb:SetValue(target)
		self:SetScript("OnUpdate", nil)
		return
	end
	cur = cur + diff * min(1, elapsed * 12)
	self._shown = cur
	self.sb:SetValue(cur)
end

local function CreateBar(name)
	local bar = CreateFrame("Frame", name, UIParent)
	bar:SetSize(200, 14)
	bar:EnableMouse(false)
	bar.bg = bar:CreateTexture(nil, "BACKGROUND", nil, -6)
	bar.bg:SetAllPoints()
	bar.overlay = bar:CreateTexture(nil, "BACKGROUND", nil, -5)
	bar.overlay:SetAllPoints()
	bar.overlay:Hide()
	local sb = CreateFrame("StatusBar", nil, bar)
	sb:SetAllPoints()
	sb:SetStatusBarTexture(P.WHITE)
	sb:SetMinMaxValues(0, 1)
	sb:SetValue(0)
	bar.sb = sb
	bar.border = P.CreateBorder(bar, 4)
	bar.textFrame = CreateFrame("Frame", nil, bar)
	bar.textFrame:SetAllPoints()
	bar.textFrame:SetFrameLevel(bar:GetFrameLevel() + 8)
	bar.text = P.NewText(bar.textFrame, 11)
	bar.text:SetPoint("CENTER")
	bar.ticks = {}

	function bar:SetRange(lo, hi)
		self._min, self._max = lo, hi
		self.sb:SetMinMaxValues(lo, hi)
	end
	function bar:SetBarValue(v, smooth)
		self._target = v
		if smooth and self._shown and self:GetAlpha() > 0 then
			self:SetScript("OnUpdate", SmoothOnUpdate)
		else
			self._shown = v
			self.sb:SetValue(v)
			self:SetScript("OnUpdate", nil)
		end
	end
	return bar
end

-- Orientation of the inner bar.
local function ApplyOrientation(bar, ori)
	local sb = bar.sb
	if ori == "VERTICAL_UP" then
		sb:SetOrientation("VERTICAL")
		sb:SetRotatesTexture(true)
		sb:SetReverseFill(false)
	elseif ori == "VERTICAL_DOWN" or ori == "VERTICAL" then
		sb:SetOrientation("VERTICAL")
		sb:SetRotatesTexture(true)
		sb:SetReverseFill(true)
	else
		sb:SetOrientation("HORIZONTAL")
		sb:SetRotatesTexture(false)
		sb:SetReverseFill(false)
	end
end

-- Fill Opacity below 100: the background covers only the empty part, so the
-- world shows through the fill (retail AnchorBgToFillEdge).
local function AnchorBgToFill(bar, ori, on)
	local bg, fill = bar.bg, bar.sb:GetStatusBarTexture()
	bg:ClearAllPoints()
	if not on then
		bg:SetAllPoints(bar)
		return
	end
	if ori == "VERTICAL_UP" then
		bg:SetPoint("BOTTOMLEFT", fill, "TOPLEFT")
		bg:SetPoint("TOPRIGHT", bar, "TOPRIGHT")
	elseif ori == "VERTICAL_DOWN" or ori == "VERTICAL" then
		bg:SetPoint("TOPLEFT", fill, "BOTTOMLEFT")
		bg:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
	else
		bg:SetPoint("TOPLEFT", fill, "TOPRIGHT")
		bg:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
	end
end

-------------------------------------------------------------------------------
--  Hash lines / tick marks
-------------------------------------------------------------------------------
local function ParseValues(str)
	if type(str) ~= "string" or str == "" then
		return nil
	end
	local vals = {}
	for s in str:gmatch("[^,]+") do
		local n = tonumber((s:gsub("%s", "")))
		if n and n > 0 then
			vals[#vals + 1] = n
		end
	end
	return #vals > 0 and vals or nil
end
P.ParseValues = ParseValues

-- Lines across `host` at fractions of its length. vals: numbers; maxVal:
-- the value of the full bar; width in physical pixels.
local function LayoutTicks(host, cache, vals, maxVal, isPercent, widthPx, r, g, b, a, ori, insetPx)
	for i = 1, #cache do
		cache[i]:Hide()
	end
	if not vals or not maxVal or maxVal <= 0 then
		return
	end
	if not host._tickLayer then
		local f = CreateFrame("Frame", nil, host)
		f:SetAllPoints()
		f:SetFrameLevel(host:GetFrameLevel() + 6)
		host._tickLayer = f
	end
	local layer = host._tickLayer
	local px = P.PixelFor(host)
	local tw = max(1, widthPx or 1) * px
	local inset = (insetPx or 0) * px
	local w, h = host:GetWidth(), host:GetHeight()
	local vert = IsVertical(ori)
	local rev = ori == "VERTICAL_DOWN" or ori == "VERTICAL"
	for i, v in ipairs(vals) do
		local frac = isPercent and (v / 100) or (v / maxVal)
		if frac > 0 and frac < 1 then
			local t = cache[i]
			if not t then
				t = layer:CreateTexture(nil, "OVERLAY", nil, 7)
				cache[i] = t
			end
			t:SetTexture(r or 1, g or 1, b or 1, a or 0.7)
			t:ClearAllPoints()
			if vert then
				local off = P.Snap(h * frac, host)
				t:SetSize(max(px, w - inset * 2), tw)
				if rev then
					t:SetPoint("TOPLEFT", host, "TOPLEFT", inset, -off)
				else
					t:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", inset, off)
				end
			else
				local off = P.Snap(w * frac, host)
				t:SetSize(tw, max(px, h - inset * 2))
				t:SetPoint("TOPLEFT", host, "TOPLEFT", off - tw / 2, -inset)
			end
			t:Show()
		end
	end
end
P.LayoutTicks = LayoutTicks

-------------------------------------------------------------------------------
--  Positions
-------------------------------------------------------------------------------
local function BuildMainFrame()
	if mainFrame then
		return mainFrame
	end
	local g = Profile().general
	mainFrame = CreateFrame("Frame", "EllesmereUIResourceBarsFrame", UIParent)
	mainFrame:SetPoint("CENTER", UIParent, "CENTER", g.anchorX or 0, g.anchorY or -100)
	mainFrame:SetSize(1, 1)
	return mainFrame
end
P.BuildMainFrame = BuildMainFrame

-- Stored center of a bar (screen units from the UIParent center): unlockPos,
-- else the main frame offsets.
local function StoredCenter(cfg, dx, dy)
	local pos = cfg.unlockPos
	if pos and pos.point then
		return pos.x or 0, pos.y or 0, pos
	end
	local g = Profile().general
	return (g.anchorX or 0) + (cfg.offsetX or dx or 0), (g.anchorY or -100) + (cfg.offsetY or dy or 0)
end
P.StoredCenter = StoredCenter

-- Unlock Mode (EllesmereUI core): while it is open the movers own a bar's
-- spot; an unlock anchor (Anchor in Unlock Mode) owns it afterwards.
-- placeFn does the plain placement; key = the bar's Unlock Mode key.
function P.UnlockPlace(frame, key, placeFn)
	if ns._unlockActive and frame._erbPlaced and frame:GetNumPoints() > 0 then
		return
	end
	frame._erbPlaced = true
	placeFn()
	if not ns._unlockActive and ns.IsUnlockAnchored and ns.IsUnlockAnchored(key) and ns.ReapplyOwnAnchor then
		ns.ReapplyOwnAnchor(key)
	end
end

local function PlaceAt(frame, cfg, dx, dy, shiftY, key)
	local function Place()
		local x, y, pos = StoredCenter(cfg, dx, dy)
		frame:ClearAllPoints()
		if pos and pos.point and pos.point ~= "CENTER" then
			frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, P.Snap(pos.x or 0, frame), P.Snap((pos.y or 0) + (shiftY or 0), frame))
		else
			frame:SetPoint("CENTER", UIParent, "CENTER", P.Snap(x, frame), P.Snap(y + (shiftY or 0), frame))
		end
	end
	if key then
		P.UnlockPlace(frame, key, Place)
	else
		Place()
	end
end
P.PlaceAt = PlaceAt

-------------------------------------------------------------------------------
--  Color helpers
-------------------------------------------------------------------------------
local function DarkFill()
	local c = ERB.DARK_FILL
	return c[1], c[2], c[3]
end

local function HealthBaseColor(hp)
	if hp.darkTheme then
		return DarkFill()
	end
	if hp.customColored then
		return hp.fillR or 1, hp.fillG or 1, hp.fillB or 1
	end
	return ERB.ClassColor()
end

local function PowerBaseColor(pp)
	if pp.darkTheme then
		return DarkFill()
	end
	if pp.customColored then
		return pp.fillR or 1, pp.fillG or 1, pp.fillB or 1
	end
	return ERB.PowerColor(ERB.PowerToken(cachedPrimary))
end

local function TextBaseColor(cfg, kind)
	if cfg.textCustomColored == false then
		if kind == "health" then
			return ERB.ClassColor()
		end
		return ERB.PowerColor(ERB.PowerToken(cachedPrimary))
	end
	return cfg.textFillR or 1, cfg.textFillG or 1, cfg.textFillB or 1, cfg.textFillA or 1
end

-- Active threshold entry of a bar (nil when off).
local function ActiveEntry(cfg)
	local e = ERB.ResolveThresholdSpecEntry(cfg)
	return e, e and (e.thresholdEnabled ~= false) and e or nil
end

-------------------------------------------------------------------------------
--  Health absorbs (retail Health Bar Absorb Style / Heal Absorb Style)
-------------------------------------------------------------------------------
local ABSORBS = {
	{ key = "absorb", style = "absorbStyle", color = "absorbColor", opacity = "absorbOpacity", def = 65,
	  r = 0.3, g = 0.75, b = 1, read = function() return UnitGetTotalAbsorbs and UnitGetTotalAbsorbs("player") or 0 end },
	{ key = "healAbsorb", style = "healAbsorbStyle", color = "healAbsorbColor", opacity = "healAbsorbOpacity", def = 75,
	  r = 0.85, g = 0.15, b = 0.2, read = function() return UnitGetTotalHealAbsorbs and UnitGetTotalHealAbsorbs("player") or 0 end },
}
ERB.HEALTH_INDICATORS = ABSORBS

local function UpdateAbsorbs(hp, cur, mx)
	local bar = healthBar
	if not bar then
		return
	end
	bar.absorbs = bar.absorbs or {}
	local fill = bar.sb:GetStatusBarTexture()
	local ori = hp.orientation or Profile().general.orientation or "HORIZONTAL"
	local vert = IsVertical(ori)
	local w, h = bar:GetWidth(), bar:GetHeight()
	local length = vert and h or w
	for _, k in ipairs(ABSORBS) do
		local style = hp[k.style]
		local tex = bar.absorbs[k.key]
		if style and style ~= "none" and mx > 0 then
			if not tex then
				tex = bar.sb:CreateTexture(nil, "ARTWORK", nil, k.key == "absorb" and 2 or 3)
				bar.absorbs[k.key] = tex
			end
			local amount = k.read() or 0
			local frac = min(1, amount / mx)
			if k.key == "absorb" then
				frac = min(frac, 1 - cur / mx)
			else
				frac = min(frac, cur / mx)
			end
			if frac <= 0 then
				tex:Hide()
			else
				local size = max(1, length * frac)
				local path = ERB.AbsorbTexture(style)
				tex:SetTexture(path)
				tex:SetHorizTile(ERB.ABSORB_TILED[style] and true or false)
				tex:SetVertTile(ERB.ABSORB_TILED[style] and true or false)
				local c = hp[k.color]
				local a = (hp[k.opacity] or k.def) / 100
				if style == "largeOutlinedStripes" or style == "largeOutlinedStripesR" then
					tex:SetVertexColor(1, 1, 1, a)
				else
					tex:SetVertexColor(c and c.r or k.r, c and c.g or k.g, c and c.b or k.b, a)
				end
				tex:ClearAllPoints()
				-- Absorbs grow out of the fill end; heal absorbs eat back into it.
				if vert then
					local up = ori == "VERTICAL_UP"
					if k.key == "absorb" then
						tex:SetPoint(up and "BOTTOMLEFT" or "TOPLEFT", fill, up and "TOPLEFT" or "BOTTOMLEFT")
						tex:SetPoint(up and "BOTTOMRIGHT" or "TOPRIGHT", fill, up and "TOPRIGHT" or "BOTTOMRIGHT")
					else
						tex:SetPoint(up and "TOPLEFT" or "BOTTOMLEFT", fill, up and "TOPLEFT" or "BOTTOMLEFT")
						tex:SetPoint(up and "TOPRIGHT" or "BOTTOMRIGHT", fill, up and "TOPRIGHT" or "BOTTOMRIGHT")
					end
					tex:SetHeight(size)
				else
					if k.key == "absorb" then
						tex:SetPoint("TOPLEFT", fill, "TOPRIGHT")
						tex:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT")
					else
						tex:SetPoint("TOPRIGHT", fill, "TOPRIGHT")
						tex:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
					end
					tex:SetWidth(size)
				end
				tex:Show()
			end
		elseif tex then
			tex:Hide()
		end
	end
end

-------------------------------------------------------------------------------
--  Health bar
-------------------------------------------------------------------------------
local function HealthText(fmt, cur, mx)
	local pct = mx > 0 and (cur / mx * 100) or 0
	local pctStr = format("%d", pct)
	local curStr = P.Abbrev(cur)
	if fmt == "both" then
		return curStr .. " | " .. pctStr .. "%"
	elseif fmt == "curhpshort" then
		return curStr
	elseif fmt == "perhpnosign" then
		return pctStr
	elseif fmt == "perhpnum" then
		return pctStr .. "% | " .. curStr
	end
	return pctStr .. "%"
end

local function UpdateHealthBar()
	local bar = healthBar
	local p = Profile()
	if not bar or not p or not p.health.enabled then
		return
	end
	local hp = p.health
	local cur, mx = UnitHealth("player") or 0, UnitHealthMax("player") or 0
	if mx <= 0 then
		return
	end
	bar:SetRange(0, mx)
	bar:SetBarValue(cur, hp.smoothBars)
	local pct = cur / mx * 100
	local r, g, b = HealthBaseColor(hp)
	local tr, tg, tb, ta = TextBaseColor(hp, "health")
	local raw, e = ActiveEntry(hp)
	local bandOn, bands, mode, rev = ERB.ResolveBandConfig(hp, raw)
	local cr, cg, cb
	if bandOn then
		local band = ERB.FindBand(bands, mode == "value" and cur or pct, rev)
		if band then
			cr, cg, cb = band.r or 1, band.g or 1, band.b or 1
		end
	elseif e then
		if pct <= (e.thresholdPct or hp.thresholdPct or 30) then
			cr, cg, cb = e.thresholdR or hp.thresholdR or 1, e.thresholdG or hp.thresholdG or 0.2, e.thresholdB or hp.thresholdB or 0.2
		end
	end
	local textInstead = raw and raw.thresholdTextInstead and hp.textFormat ~= "none"
	local fill = bar.sb:GetStatusBarTexture()
	local fillA = (hp.fillOpacity or 100) / 100
	if cr and not textInstead then
		fill:SetVertexColor(cr, cg, cb, fillA)
	else
		ApplyFill(fill, hp, r, g, b, fillA)
	end
	if hp.textFormat and hp.textFormat ~= "none" and not ERB.TextHiddenByForm(hp) then
		bar.text:SetText(HealthText(hp.textFormat, cur, mx))
		if cr and textInstead then
			bar.text:SetTextColor(cr, cg, cb, 1)
		else
			bar.text:SetTextColor(tr, tg, tb, ta or 1)
		end
		bar.text:Show()
	else
		bar.text:Hide()
	end
	UpdateAbsorbs(hp, cur, mx)
end
ERB.UpdateHealthBar = UpdateHealthBar

-------------------------------------------------------------------------------
--  Power bar
-------------------------------------------------------------------------------
local function UpdatePrimaryBar()
	local bar = primaryBar
	local p = Profile()
	if not bar or not p or not cachedPrimary then
		return
	end
	local pp = p.primary
	local cur, mx = UnitPower("player", cachedPrimary) or 0, UnitPowerMax("player", cachedPrimary) or 0
	if mx <= 0 then
		mx = 1
	end
	if cur < 0 then
		cur = 0
	end
	bar:SetRange(0, mx)
	bar:SetBarValue(cur, pp.smoothBars)
	local pct = cur / mx * 100
	local r, g, b = PowerBaseColor(pp)
	local tr, tg, tb, ta = TextBaseColor(pp, "power")
	local raw, e = ActiveEntry(pp)
	local bandOn, bands, mode, rev = ERB.ResolveBandConfig(pp, raw)
	local cr, cg, cb
	if bandOn then
		local band = ERB.FindBand(bands, mode == "value" and cur or pct, rev)
		if band then
			cr, cg, cb = band.r or 1, band.g or 1, band.b or 1
		end
	elseif e then
		local tPct = e.thresholdPct or pp.thresholdPct or 30
		local partial = e.thresholdPartialOnly
		if partial == nil then partial = pp.thresholdPartialOnly end
		local hit
		if partial then
			hit = pct <= tPct
		else
			hit = pct > tPct
		end
		if hit then
			cr, cg, cb = e.thresholdR or pp.thresholdR or 1, e.thresholdG or pp.thresholdG or 0.2, e.thresholdB or pp.thresholdB or 0.2
		end
	end
	local textInstead = raw and raw.thresholdTextInstead and pp.textFormat ~= "none"
	local fill = bar.sb:GetStatusBarTexture()
	local fillA = (pp.fillOpacity or 100) / 100
	if cr and not textInstead then
		fill:SetVertexColor(cr, cg, cb, fillA)
	else
		ApplyFill(fill, pp, r, g, b, fillA)
	end
	local fmt = pp.textFormat
	if fmt and fmt ~= "none" and not ERB.TextHiddenByForm(pp) then
		local pctText = format("%d", pct) .. ((pp.showPercent == false) and "" or "%")
		local txt
		if fmt == "smart" then
			txt = ERB.IsSmartPowerPercent(cachedPrimary) and pctText or P.Abbrev(cur)
		elseif fmt == "both" then
			txt = P.Abbrev(cur) .. " | " .. pctText
		elseif fmt == "perpp" then
			txt = pctText
		else
			txt = P.Abbrev(cur)
		end
		bar.text:SetText(txt)
		if cr and textInstead then
			bar.text:SetTextColor(cr, cg, cb, 1)
		else
			bar.text:SetTextColor(tr, tg, tb, ta or 1)
		end
		bar.text:Show()
	else
		bar.text:Hide()
	end
end
ERB.UpdatePrimaryBar = UpdatePrimaryBar

-------------------------------------------------------------------------------
--  Class resource: pips / runes / bar
-------------------------------------------------------------------------------
local pips = {}

-- Pixel-snapped pip slots: { x0, x1 } along the bar, spacing whole pixels.
local function PipSlots(total, n, spacing, frame)
	local px = P.PixelFor(frame)
	if not n or n < 1 then
		return {}, px
	end
	local spPx = max(0, floor((spacing or 0) + 0.5))
	local totalPx = floor(total / px + 0.5)
	local pipPx = totalPx - spPx * (n - 1)
	local base = floor(pipPx / n)
	local extra = pipPx - base * n
	local slots, cursor = {}, 0
	for i = 1, n do
		local w = base + (i <= extra and 1 or 0)
		slots[i] = { x0 = cursor * px, x1 = (cursor + w) * px }
		cursor = cursor + w + spPx
	end
	return slots, px
end
P.PipSlots = PipSlots

local function CreatePip(parent)
	local pip = CreateFrame("Frame", nil, parent)
	pip.bg = pip:CreateTexture(nil, "BACKGROUND", nil, 1)
	pip.bg:SetAllPoints()
	pip.fill = pip:CreateTexture(nil, "ARTWORK")
	pip.fill:SetPoint("TOPLEFT")
	pip.fill:SetPoint("BOTTOMLEFT")
	pip.recharge = CreateFrame("StatusBar", nil, pip)
	pip.recharge:SetAllPoints()
	pip.recharge:SetMinMaxValues(0, 1)
	pip.recharge:Hide()
	pip.border = P.CreateBorder(pip, 3)
	pip.cd = P.NewText(pip.border, 10)
	pip.cd:SetPoint("CENTER")
	return pip
end

-- Base fill color of the class resource (or of one rune).
local function SecondaryBaseColor(sp, res, runeType)
	if sp.darkTheme then
		return DarkFill()
	end
	local key = res and res.power
	if runeType and sp.runesByType and (sp.resourceColored or sp.classColored ~= false) then
		local c = ERB.RUNE_TYPE_COLORS[runeType]
		if c then
			return c[1], c[2], c[3]
		end
	end
	if sp.resourceColored then
		local r, g, b = ERB.ResolveSecondaryResourceColor(key)
		if r then
			return r, g, b
		end
		return ERB.ClassColor()
	elseif sp.classColored ~= false then
		if key == "FOCUS_BAR" then
			return ERB.PowerColor("FOCUS")
		elseif key == "DEMONIC_FURY" or key == "ECLIPSE" then
			return ERB.PowerColor(key)
		end
		return ERB.ClassColor()
	end
	return sp.fillR or 0.95, sp.fillG or 0.9, sp.fillB or 0.6
end
ERB.SecondaryBaseColor = SecondaryBaseColor

-- Empty slot color: the overlay tint, composited over the bar background
-- while that background is not drawn behind the pips (retail PipBgColor).
local function PipBgColor(sp, force)
	local r, g, b, a = sp.bgR or 1, sp.bgG or 1, sp.bgB or 1, sp.bgA or 0.1
	if sp.darkTheme then
		local d = ERB.DARK_BG
		r, g, b, a = d[1], d[2], d[3], 1
	end
	if not force and (sp.fillOpacity or 100) >= 100 then
		return r, g, b, a
	end
	local br, bg2, bb, ba
	if sp.darkTheme then
		br, bg2, bb, ba = 0, 0, 0, 1
	else
		br, bg2, bb, ba = sp.barBgR or 0, sp.barBgG or 0, sp.barBgB or 0, sp.barBgA or 0.5
	end
	local oa = a + ba * (1 - a)
	if oa <= 0 then
		return br, bg2, bb, 0
	end
	return (r * a + br * ba * (1 - a)) / oa, (g * a + bg2 * ba * (1 - a)) / oa, (b * a + bb * ba * (1 - a)) / oa, oa
end

local function BarBgColor(sp)
	if sp.darkTheme then
		return 0, 0, 0, 1
	end
	return sp.barBgR or 0, sp.barBgG or 0, sp.barBgB or 0, sp.barBgA or 0.5
end

local RUNE_ORDER = { 1, 2, 5, 6, 3, 4 }

-- Threshold decision for a class resource. Returns trigger color or nil and
-- the per-pip "partial only" start index.
local function SecondaryThreshold(sp, res, cur, maxV)
	local raw = ERB.ResolveThresholdSpecEntry(sp)
	local e = raw and (raw.thresholdEnabled ~= false) and raw or nil
	local bandOn, bands, mode, bandRev = ERB.ResolveBandConfig(sp, raw)
	local isBar = res.type == "bar"
	local value = cur
	if bandOn then
		if isBar and mode ~= "value" then
			value = maxV > 0 and (cur / maxV * 100) or 0
		end
		local band = ERB.FindBand(bands, value, bandRev)
		if band then
			return band.r or 1, band.g or 1, band.b or 1, band.a or 1, nil, raw
		end
		return nil, nil, nil, nil, nil, raw
	end
	if not e then
		return nil, nil, nil, nil, nil, raw
	end
	local count = e.thresholdCount or sp.thresholdCount or 3
	local reverse = e.thresholdReverse
	if reverse == nil then reverse = sp.thresholdReverse end
	local partial = e.thresholdPartialOnly
	if partial == nil then partial = sp.thresholdPartialOnly end
	if reverse then partial = false end
	if isBar and (e.thresholdMode or "percent") ~= "value" then
		value = maxV > 0 and (cur / maxV * 100) or 0
	end
	local hit
	if reverse then
		hit = value <= count
	else
		hit = value >= count
	end
	if not hit then
		return nil, nil, nil, nil, nil, raw
	end
	local tr = e.thresholdR or sp.thresholdR or 0x0c / 255
	local tg = e.thresholdG or sp.thresholdG or 0xd2 / 255
	local tb = e.thresholdB or sp.thresholdB or 0x9d / 255
	local ta = e.thresholdA or sp.thresholdA or 1
	return tr, tg, tb, ta, (partial and not isBar) and count or nil, raw
end

local function PlacePip(pip, slot, ori, frame)
	pip:ClearAllPoints()
	local len = slot.x1 - slot.x0
	if ori == "VERTICAL_UP" then
		pip:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, slot.x0)
		pip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, slot.x0)
		pip:SetHeight(len)
	elseif ori == "VERTICAL_DOWN" or ori == "VERTICAL" then
		pip:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -slot.x0)
		pip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -slot.x0)
		pip:SetHeight(len)
	else
		pip:SetPoint("TOPLEFT", frame, "TOPLEFT", slot.x0, 0)
		pip:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", slot.x0, 0)
		pip:SetWidth(len)
	end
	pip._len = len
end

-- Pip fill: fraction 0..1 of the pip, along the bar direction.
local function SetPipFill(pip, frac, ori, r, g, b, a)
	local fill = pip.fill
	if frac <= 0 then
		fill:Hide()
		return
	end
	fill:ClearAllPoints()
	local len = (pip._len or 1) * min(1, frac)
	if ori == "VERTICAL_UP" then
		fill:SetPoint("BOTTOMLEFT")
		fill:SetPoint("BOTTOMRIGHT")
		fill:SetHeight(len)
	elseif ori == "VERTICAL_DOWN" or ori == "VERTICAL" then
		fill:SetPoint("TOPLEFT")
		fill:SetPoint("TOPRIGHT")
		fill:SetHeight(len)
	else
		fill:SetPoint("TOPLEFT")
		fill:SetPoint("BOTTOMLEFT")
		fill:SetWidth(len)
	end
	fill:SetVertexColor(r, g, b, a or 1)
	fill:Show()
end

local function TextColorOr(sp, cr, cg, cb, textInstead)
	if cr and textInstead then
		return cr, cg, cb
	end
	return sp.textR or 1, sp.textG or 1, sp.textB or 1
end

-- Is the power bar hidden right now (retail IsPowerBarHidden)?
local function IsPowerBarHidden()
	local p = Profile()
	local pp = p.primary
	if pp.enabled == false or not cachedPrimary or ERB.BarHiddenByForm(pp) then
		return true
	end
	local sp = p.secondary
	if sp.hidePowerIfResource and sp.enabled ~= false and cachedSecondary then
		return true
	end
	return false
end
ERB.IsPowerBarHidden = IsPowerBarHidden

local function ShowCountText(sp)
	if not sp.showText or ERB.TextHiddenByForm(sp, true) then
		return false
	end
	if sp.showTextOnlyIfNoPower and not IsPowerBarHidden() then
		return false
	end
	return true
end

local runeBusy = false

local function UpdateRunes(sp, res, ori)
	local f = secondaryFrame
	local now = GetTime()
	local readyN = 0
	local info = {}
	for i = 1, 6 do
		local id = RUNE_ORDER[i]
		local start, duration, ready = GetRuneCooldown(id)
		local remaining = 0
		if not ready and start and duration and duration > 0 then
			remaining = max(0, start + duration - now)
		elseif not ready then
			remaining = 999
		end
		info[i] = { id = id, ready = ready and true or false, start = start or 0, dur = duration or 0, rem = remaining,
			type = GetRuneType(id) }
		if ready then
			readyN = readyN + 1
		end
	end
	-- Full mode: ready runes first (left), then by time left (retail).
	local order = info
	if not sp.runesSimple then
		order = {}
		for i = 1, 6 do order[i] = info[i] end
		table.sort(order, function(a, b)
			if a.ready ~= b.ready then
				return a.ready
			end
			if a.rem ~= b.rem then
				return a.rem < b.rem
			end
			return a.id < b.id
		end)
	end
	local tr, tg, tb, ta, partialFrom, raw = SecondaryThreshold(sp, res, readyN, 6)
	local textInstead = raw and raw.thresholdTextInstead and sp.showText
	local fillA = (sp.fillOpacity or 100) / 100
	local showCd = ShowCountText(sp) and not sp.runesSimple
	runeBusy = false
	for pos = 1, 6 do
		local pip = pips[pos]
		local r = order[pos]
		local br, bg, bb = SecondaryBaseColor(sp, res, r.type)
		if sp.runesSimple then
			local lit = pos <= readyN
			local cr, cg, cb = br, bg, bb
			if lit and tr and not textInstead and not (partialFrom and pos < partialFrom) then
				cr, cg, cb = tr, tg, tb
			end
			SetPipFill(pip, lit and 1 or 0, ori, cr, cg, cb, fillA)
			pip.recharge:Hide()
			pip.cd:SetText("")
		elseif r.ready then
			local cr, cg, cb = br, bg, bb
			if tr and not textInstead and not (partialFrom and pos < partialFrom) then
				cr, cg, cb = tr, tg, tb
			end
			SetPipFill(pip, 1, ori, cr, cg, cb, fillA)
			pip.recharge:Hide()
			pip.cd:SetText("")
		else
			SetPipFill(pip, 0, ori)
			local rr, rg, rb, ra
			if sp.runesCustomRecharge then
				rr, rg, rb, ra = sp.runesRechargeR or 0.5, sp.runesRechargeG or 0.5, sp.runesRechargeB or 0.5, sp.runesRechargeA or 1
			else
				rr, rg, rb, ra = br * 0.5, bg * 0.5, bb * 0.5, 1
			end
			pip.recharge:SetStatusBarTexture(P.TexturePath(Profile().general.barTexture))
			pip.recharge:GetStatusBarTexture():SetVertexColor(rr, rg, rb, (ra or 1) * fillA)
			pip.recharge:SetOrientation(IsVertical(ori) and "VERTICAL" or "HORIZONTAL")
			pip.recharge:SetReverseFill(ori == "VERTICAL_DOWN" or ori == "VERTICAL")
			if r.dur > 0 and r.rem < 999 then
				pip.recharge:SetValue(min(1, max(0, (now - r.start) / r.dur)))
				runeBusy = true
				if showCd then
					pip.cd:SetText(format("%d", ceil(r.rem)))
				else
					pip.cd:SetText("")
				end
			else
				pip.recharge:SetValue(0)
				pip.cd:SetText("")
			end
			pip.recharge:Show()
		end
	end
	if f.count then
		if sp.runesSimple and ShowCountText(sp) then
			f.count:SetText(tostring(readyN))
			f.count:SetTextColor(TextColorOr(sp, tr, tg, tb, textInstead))
			f.count:Show()
		else
			f.count:Hide()
		end
	end
end

local function UpdateSecondaryBar(sp, res)
	local bar = secondaryBar
	local cur = ERB.ReadSecondary(res)
	local mx = res.max or 1
	if res.pt then
		mx = UnitPowerMax("player", res.pt) or mx
		if mx <= 0 then mx = res.max or 1 end
	end
	local r, g, b = SecondaryBaseColor(sp, res)
	local fill = bar.sb:GetStatusBarTexture()
	local fillA = (sp.fillOpacity or 100) / 100
	local tr, tg, tb, ta, _, raw
	if res.power == "ECLIPSE" then
		-- -100 (lunar) .. +100 (solar), drawn from the bar center.
		local value = cur
		local half = abs(value) / 100
		bar:SetRange(0, 1)
		bar:SetBarValue(0)
		local side = value < 0 and "lunar" or "solar"
		local dir = GetEclipseDirection and GetEclipseDirection()
		if not sp.darkTheme and (sp.resourceColored or sp.classColored ~= false) then
			local c = ERB.ECLIPSE_COLORS[side]
			r, g, b = c[1], c[2], c[3]
		end
		tr, tg, tb, ta, _, raw = SecondaryThreshold(sp, res, abs(value), 100)
		local ec = bar.eclipse
		if not ec then
			ec = bar.sb:CreateTexture(nil, "ARTWORK", nil, 1)
			bar.eclipse = ec
			bar.eclipseMark = bar.textFrame:CreateTexture(nil, "OVERLAY")
		end
		ec:SetTexture(P.TexturePath(Profile().general.barTexture))
		local w = bar:GetWidth()
		ec:ClearAllPoints()
		if half > 0 then
			if value < 0 then
				ec:SetPoint("TOPRIGHT", bar, "TOP")
				ec:SetPoint("BOTTOMRIGHT", bar, "BOTTOM")
			else
				ec:SetPoint("TOPLEFT", bar, "TOP")
				ec:SetPoint("BOTTOMLEFT", bar, "BOTTOM")
			end
			ec:SetWidth(max(1, w / 2 * half))
			if tr and not (raw and raw.thresholdTextInstead) then
				ec:SetVertexColor(tr, tg, tb, fillA)
			else
				ApplyFill(ec, sp, r, g, b, fillA)
			end
			ec:Show()
		else
			ec:Hide()
		end
		local m = bar.eclipseMark
		local px = P.PixelFor(bar)
		m:SetTexture(1, 1, 1, 0.5)
		m:ClearAllPoints()
		m:SetPoint("TOP", bar, "TOP")
		m:SetPoint("BOTTOM", bar, "BOTTOM")
		m:SetWidth(px)
		m:Show()
		if ShowCountText(sp) then
			local arrow = (dir == "sun" and " >") or (dir == "moon" and "< ") or ""
			local txt = format("%d", abs(value))
			if dir == "moon" then txt = arrow .. txt elseif dir == "sun" then txt = txt .. arrow end
			bar.text:SetText(txt)
			bar.text:SetTextColor(TextColorOr(sp, tr, tg, tb, raw and raw.thresholdTextInstead))
			bar.text:Show()
		else
			bar.text:Hide()
		end
		return
	end
	if bar.eclipse then
		bar.eclipse:Hide()
		bar.eclipseMark:Hide()
	end
	bar:SetRange(0, mx)
	bar:SetBarValue(cur, sp.smoothBars)
	tr, tg, tb, ta, _, raw = SecondaryThreshold(sp, res, cur, mx)
	local textInstead = raw and raw.thresholdTextInstead and sp.showText
	if tr and not textInstead then
		fill:SetVertexColor(tr, tg, tb, (ta or 1) * fillA)
	else
		ApplyFill(fill, sp, r, g, b, fillA)
	end
	if ShowCountText(sp) then
		if sp.showPercent then
			bar.text:SetText(format("%d%%", mx > 0 and (cur / mx * 100) or 0))
		else
			bar.text:SetText(P.Abbrev(cur))
		end
		bar.text:SetTextColor(TextColorOr(sp, tr, tg, tb, textInstead))
		bar.text:Show()
	else
		bar.text:Hide()
	end
end

local function UpdateSecondaryResource()
	local p = Profile()
	local res = cachedSecondary
	if not p or not res or not secondaryFrame then
		return
	end
	local sp = p.secondary
	local ori = sp.pipOrientation or "HORIZONTAL"
	if res.type == "bar" then
		if secondaryBar then
			UpdateSecondaryBar(sp, res)
		end
		return
	end
	if res.type == "runes" then
		UpdateRunes(sp, res, ori)
		return
	end
	local cur = ERB.ReadSecondary(res)
	local n = secondaryFrame.numPips or res.max
	local tr, tg, tb, ta, partialFrom, raw = SecondaryThreshold(sp, res, cur, n)
	local textInstead = raw and raw.thresholdTextInstead and sp.showText
	local r, g, b = SecondaryBaseColor(sp, res)
	local fillA = (sp.fillOpacity or 100) / 100
	for i = 1, n do
		local pip = pips[i]
		if pip then
			local frac = max(0, min(1, cur - (i - 1)))
			local cr, cg, cb, ca = r, g, b, 1
			if frac > 0 and tr and not textInstead and not (partialFrom and i < partialFrom) then
				cr, cg, cb, ca = tr, tg, tb, ta or 1
			end
			if frac > 0 and frac < 1 and res.frac and sp.darkenPartialPips ~= false then
				cr, cg, cb = cr * 0.55, cg * 0.55, cb * 0.55
			end
			SetPipFill(pip, frac, ori, cr, cg, cb, ca * fillA)
			pip.recharge:Hide()
			pip.cd:SetText("")
			-- Below 100 fill opacity the lit pips show the world, not their bg.
			if fillA < 1 then
				pip.bg:SetAlpha(frac >= 1 and 0 or 1)
			else
				pip.bg:SetAlpha(1)
			end
		end
	end
	if secondaryFrame.count then
		if ShowCountText(sp) then
			local whole = res.frac and floor(cur) or cur
			secondaryFrame.count:SetText(tostring(whole))
			secondaryFrame.count:SetTextColor(TextColorOr(sp, tr, tg, tb, textInstead))
			secondaryFrame.count:Show()
		else
			secondaryFrame.count:Hide()
		end
	end
end
ERB.UpdateSecondaryResource = UpdateSecondaryResource

-------------------------------------------------------------------------------
--  Build (settings pass)
-------------------------------------------------------------------------------
local function StyleBar(bar, cfg, p, texKey, w, h, ori, bgR, bgG, bgB, bgA)
	bar:SetSize(OrientedSize(w, h, ori))
	bar.sb:SetStatusBarTexture(P.TexturePath(texKey))
	ApplyOrientation(bar, ori)
	bar.bg:SetTexture(bgR, bgG, bgB, bgA)
	AnchorBgToFill(bar, ori, (cfg.fillOpacity or 100) < 100)
	bar.border:Apply(cfg.borderSize or 0, cfg.borderR, cfg.borderG, cfg.borderB, cfg.borderA)
	bar.border:SetFrameLevel(bar:GetFrameLevel() + ((cfg.borderBehind and 0) or 4))
	-- Text above the border (child levels do not follow a later parent level change).
	bar.textFrame:SetFrameLevel(bar:GetFrameLevel() + 10)
	if bar._tickLayer then
		bar._tickLayer:SetFrameLevel(bar:GetFrameLevel() + 6)
	end
	bar.text:ClearAllPoints()
	local anchor = cfg.textAnchor or "CENTER"
	bar.text:SetPoint(anchor, bar, anchor, cfg.textXOffset or 0, cfg.textYOffset or 0)
	P.SetFont(bar.text, cfg.textSize or 11)
end

-- User hash lines on the health / power bar (flat keys).
local function ApplyBarHash(bar, cfg, ori, getMax)
	bar.userTicks = bar.userTicks or {}
	if not cfg.hashEnabled then
		LayoutTicks(bar, bar.userTicks, nil)
		return
	end
	local isPercent = (cfg.hashMode or "percent") == "percent"
	local mx = isPercent and 100 or (getMax() or 0)
	LayoutTicks(bar, bar.userTicks, ParseValues(cfg.hashValues), mx, isPercent, cfg.hashWidth or 1,
		cfg.hashColorR, cfg.hashColorG, cfg.hashColorB, cfg.hashColorA, ori, cfg.borderSize or 0)
end

local function BuildHealth(p)
	local hp = p.health
	if not healthBar then
		healthBar = CreateBar("ERB_HealthBar")
		frames.health = healthBar
	end
	local bar = healthBar
	local ori = hp.orientation or p.general.orientation or "HORIZONTAL"
	bar:SetFrameStrata(Strata(p, "health"))
	bar:SetFrameLevel(10)
	StyleBar(bar, hp, p, ERB.BarTexture(p, "health"), hp.width or 214, hp.height or 16, ori,
		hp.darkTheme and ERB.DARK_BG[1] or hp.bgR, hp.darkTheme and ERB.DARK_BG[2] or hp.bgG,
		hp.darkTheme and ERB.DARK_BG[3] or hp.bgB, hp.darkTheme and 1 or hp.bgA)
	PlaceAt(bar, hp, 0, -64, nil, "ERB_Health")
	ApplyBarHash(bar, hp, ori, function() return UnitHealthMax("player") end)
	if bar.absorbs then
		for _, t in pairs(bar.absorbs) do t:Hide() end
	end
end

-- Mana Bar while Shapeshifted (retail ForeverDruidMana; primary.druidMana =
-- { enabled, height, position "below" | "above", showText, textSize }): a
-- thin mana bar on the power bar while a druid is in Bear or Cat Form.
local function DruidManaShown(pp)
	local dm = pp.druidMana
	if not (dm and dm.enabled) or select(2, UnitClass("player")) ~= "DRUID" then return false end
	local form = GetShapeshiftFormID()
	return (form == 1 or form == 5) and cachedPrimary ~= 0
end
function ERB.UpdateDruidMana()
	local bar = primaryBar
	local f = bar and bar.druidMana
	local p = Profile()
	if not f or not p then return end
	local pp = p.primary
	if not DruidManaShown(pp) or not bar:IsShown() then
		f:Hide()
		return
	end
	local cur, mx = UnitPower("player", 0) or 0, UnitPowerMax("player", 0) or 0
	if mx <= 0 then mx = 1 end
	f.sb:SetMinMaxValues(0, mx)
	f.sb:SetValue(cur)
	local r, g, b = ERB.PowerColor("MANA")
	f.sb:SetStatusBarColor(r or 0, g or 0.55, b or 1, 1)
	if pp.druidMana.showText then
		f.text:SetText(format("%d%%", cur / mx * 100))
		f.text:Show()
	else
		f.text:Hide()
	end
	f:Show()
end
function ERB.LayoutDruidMana(bar, pp)
	local dm = pp.druidMana
	if not (dm and dm.enabled) then
		if bar.druidMana then bar.druidMana:Hide() end
		return
	end
	local f = bar.druidMana
	if not f then
		f = CreateFrame("Frame", nil, bar)
		f.bg = f:CreateTexture(nil, "BACKGROUND")
		f.bg:SetAllPoints()
		f.bg:SetTexture(0, 0, 0, 0.6)
		f.sb = CreateFrame("StatusBar", nil, f)
		f.sb:SetPoint("TOPLEFT", 1, -1)
		f.sb:SetPoint("BOTTOMRIGHT", -1, 1)
		f.sb:SetStatusBarTexture(P.WHITE)
		f.text = P.NewText(f.sb, 9)
		f.text:SetPoint("CENTER")
		bar.druidMana = f
	end
	f.sb:SetStatusBarTexture(ERB.BarTexture(Profile(), "primary") or P.WHITE)
	P.SetFont(f.text, dm.textSize or 9)
	f:ClearAllPoints()
	f:SetHeight((dm.height or 4) + 2)
	if dm.position == "above" then
		f:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 1)
		f:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 1)
	else
		f:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -1)
		f:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -1)
	end
	f:SetFrameLevel(bar:GetFrameLevel() + 2)
	ERB.UpdateDruidMana()
end

local function BuildPower(p, expandDelta, expandSign, shiftY)
	local pp = p.primary
	if not primaryBar then
		primaryBar = CreateBar("ERB_PowerBar")
		frames.primary = primaryBar
	end
	local bar = primaryBar
	local ori = pp.orientation or p.general.orientation or "HORIZONTAL"
	bar:SetFrameStrata(Strata(p, "primary"))
	bar:SetFrameLevel(10)
	local h = (pp.height or 14) + (expandDelta or 0)
	StyleBar(bar, pp, p, ERB.BarTexture(p, "primary"), pp.width or 214, h, ori,
		pp.darkTheme and ERB.DARK_BG[1] or pp.bgR, pp.darkTheme and ERB.DARK_BG[2] or pp.bgG,
		pp.darkTheme and ERB.DARK_BG[3] or pp.bgB, pp.darkTheme and 1 or pp.bgA)
	-- Expand grows toward the missing class resource: the far edge stays put.
	PlaceAt(bar, pp, 0, -54, (expandDelta or 0) / 2 * (expandSign or 1) + (shiftY or 0), "ERB_Power")
	ApplyBarHash(bar, pp, ori, function() return cachedPrimary and UnitPowerMax("player", cachedPrimary) end)
	ERB.LayoutDruidMana(bar, pp)
	-- Spell Cost Prediction (retail primary.powerCostPrediction): the mana a
	-- cast will spend, drawn on the power bar's fill (core engine, host "erb").
	local SCP = ns.SpellCostPrediction
	if SCP then
		if pp.powerCostPrediction == true and pp.enabled ~= false then
			ERB.POWER_COST_HOST = ERB.POWER_COST_HOST or {
				PowerType = function() return cachedPrimary end,
				Color = function()
					local r, g, b = SCP.Color(Profile().primary)
					return r, g, b, 1
				end,
			}
			SCP.Attach("erb", bar.sb, ERB.POWER_COST_HOST)
		else
			SCP.Detach("erb")
		end
	end
end

local function BuildSecondary(p, shiftY)
	local sp = p.secondary
	local res = cachedSecondary
	if not secondaryFrame then
		secondaryFrame = CreateFrame("Frame", "ERB_ClassResource", UIParent)
		secondaryFrame.barBg = secondaryFrame:CreateTexture(nil, "BACKGROUND", nil, -7)
		secondaryFrame.barBg:SetAllPoints()
		secondaryFrame.gaps = {}
		secondaryFrame.border = P.CreateBorder(secondaryFrame, 8)
		secondaryFrame.textFrame = CreateFrame("Frame", nil, secondaryFrame)
		secondaryFrame.textFrame:SetAllPoints()
		secondaryFrame.count = P.NewText(secondaryFrame.textFrame, 11)
		secondaryFrame.ticks = {}
		frames.secondary = secondaryFrame
	end
	local f = secondaryFrame
	local ori = sp.pipOrientation or "HORIZONTAL"
	local w, h = sp.pipWidth or 214, sp.pipHeight or 20
	f:SetFrameStrata(Strata(p, nil))
	f:SetFrameLevel(sp.raiseLevel and 30 or 12)
	f.textFrame:SetFrameLevel(f:GetFrameLevel() + 12)
	f.border:SetFrameLevel(f:GetFrameLevel() + 8)
	if f._tickLayer then
		f._tickLayer:SetFrameLevel(f:GetFrameLevel() + 9)
	end
	f:SetSize(OrientedSize(w, h, ori))
	PlaceAt(f, sp, 0, -38, shiftY, "ERB_ClassResource")
	f.count:ClearAllPoints()
	local anchor = sp.textAnchor or "CENTER"
	f.count:SetPoint(anchor, f, anchor, sp.textXOffset or 0, sp.textYOffset or 0)
	P.SetFont(f.count, sp.textSize or 11)
	for i = 1, #pips do pips[i]:Hide() end
	for i = 1, #f.gaps do f.gaps[i]:Hide() end
	LayoutTicks(f, f.ticks, nil)
	if secondaryBar then
		secondaryBar:Hide()
	end
	if not res then
		f.numPips = 0
		f.barBg:Hide()
		f.border:Apply(0)
		f.count:Hide()
		return
	end
	local raw = ERB.ResolveThresholdSpecEntry(sp)
	if res.type == "bar" then
		f.barBg:Hide()
		f.border:Apply(0)
		f.count:Hide()
		if not secondaryBar then
			secondaryBar = CreateBar("ERB_ClassResourceBar")
			secondaryBar:SetParent(f)
			secondaryBar:SetAllPoints(f)
		end
		local bar = secondaryBar
		bar:SetFrameLevel(f:GetFrameLevel() + 1)
		bar.border:SetFrameLevel(f:GetFrameLevel() + 5)
		if bar._tickLayer then
			bar._tickLayer:SetFrameLevel(f:GetFrameLevel() + 7)
		end
		bar.textFrame:SetFrameLevel(f:GetFrameLevel() + 12)
		local br, bg, bb, ba = BarBgColor(sp)
		bar:SetSize(OrientedSize(w, h, ori))
		bar.sb:SetStatusBarTexture(P.TexturePath(p.general.barTexture))
		ApplyOrientation(bar, res.power == "ECLIPSE" and "HORIZONTAL" or ori)
		bar.bg:SetTexture(br, bg, bb, ba)
		local or_, og, ob, oa = PipBgColor(sp)
		bar.overlay:SetTexture(or_, og, ob, oa)
		bar.overlay:Show()
		AnchorBgToFill(bar, ori, (sp.fillOpacity or 100) < 100)
		bar.border:Apply(sp.borderSize or 0, sp.borderR, sp.borderG, sp.borderB, sp.borderA)
		bar.text:ClearAllPoints()
		bar.text:SetPoint(anchor, bar, anchor, sp.textXOffset or 0, sp.textYOffset or 0)
		P.SetFont(bar.text, sp.textSize or 11)
		bar:Show()
		-- Hash lines: the entry's values (percent or value) or the bar's tickValues.
		bar.userTicks = bar.userTicks or {}
		local hv = raw and raw.hashValues
		local isPercent = raw and (raw.hashMode or "value") == "percent"
		local mx = res.pt and UnitPowerMax("player", res.pt) or res.max
		if not hv or hv == "" then
			hv, isPercent = sp.tickValues, false
		end
		LayoutTicks(bar, bar.userTicks, ParseValues(hv), isPercent and 100 or mx, isPercent,
			raw and raw.hashWidth or 1, raw and raw.hashColorR, raw and raw.hashColorG, raw and raw.hashColorB,
			raw and raw.hashColorA, ori, sp.borderSize or 0)
		return
	end
	-- Pips / runes.
	local n = res.max or 5
	f.numPips = n
	local pipBg = sp.pipBgOnPips and sp.borderOnPips
	local br, bg, bb, ba = BarBgColor(sp)
	f.barBg:SetTexture(br, bg, bb, ba)
	f.barBg:SetShown(not pipBg and (sp.fillOpacity or 100) >= 100)
	if sp.borderOnPips then
		f.border:Apply(0)
	else
		f.border:Apply(sp.borderSize or 0, sp.borderR, sp.borderG, sp.borderB, sp.borderA)
	end
	local slots = PipSlots(w, n, sp.pipSpacing or 1, f)
	local er, eg, eb, ea = PipBgColor(sp, pipBg)
	local tex = P.TexturePath(p.general.barTexture)
	for i = 1, n do
		local pip = pips[i]
		if not pip then
			pip = CreatePip(f)
			pips[i] = pip
		end
		pip:SetParent(f)
		pip:SetFrameLevel(f:GetFrameLevel() + 1)
		pip.border:SetFrameLevel(pip:GetFrameLevel() + 3)
		PlacePip(pip, slots[i], ori, f)
		pip.bg:SetTexture(er, eg, eb, ea)
		pip.fill:SetTexture(tex)
		pip.recharge:SetStatusBarTexture(tex)
		if sp.borderOnPips then
			pip.border:Apply(sp.borderSize or 0, sp.borderR, sp.borderG, sp.borderB, sp.borderA)
		else
			pip.border:Apply(0)
		end
		P.SetFont(pip.cd, max(8, floor((sp.textSize or 11) * 0.9)))
		pip:Show()
	end
	-- Gap color (or the bar background while fill opacity hides it).
	local fillOp = not pipBg and (sp.fillOpacity or 100) < 100
	if (sp.gapColorEnabled or fillOp) and n > 1 then
		local gr, gg, gb, ga
		if sp.gapColorEnabled then
			gr, gg, gb, ga = sp.gapR or 0, sp.gapG or 0, sp.gapB or 0, sp.gapA or 1
		else
			gr, gg, gb, ga = br, bg, bb, ba
		end
		for i = 1, n - 1 do
			local len = slots[i + 1].x0 - slots[i].x1
			if len > 0 then
				local t = f.gaps[i]
				if not t then
					t = f:CreateTexture(nil, "BACKGROUND", nil, 0)
					f.gaps[i] = t
				end
				t:SetTexture(gr, gg, gb, ga)
				t:ClearAllPoints()
				local s = { x0 = slots[i].x1, x1 = slots[i + 1].x0 }
				if ori == "VERTICAL_UP" then
					t:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, s.x0)
					t:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, s.x0)
					t:SetHeight(len)
				elseif IsVertical(ori) then
					t:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -s.x0)
					t:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -s.x0)
					t:SetHeight(len)
				else
					t:SetPoint("TOPLEFT", f, "TOPLEFT", s.x0, 0)
					t:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", s.x0, 0)
					t:SetWidth(len)
				end
				t:Show()
			end
		end
	end
	-- Hash lines on pips: after the given counts.
	if raw and raw.hashValues and raw.hashValues ~= "" then
		LayoutTicks(f, f.ticks, ParseValues(raw.hashValues), n, false, raw.hashWidth or 1,
			raw.hashColorR, raw.hashColorG, raw.hashColorB, raw.hashColorA, ori, sp.borderSize or 0)
	end
end

-- Effective vertical position used to decide which way Expand grows.
local function EffY(cfg, dy)
	local _, y = StoredCenter(cfg, 0, dy)
	return y
end

function ERB.BuildBars()
	local p = Profile()
	if not p then
		return
	end
	BuildMainFrame()
	cachedPrimary = ERB.GetPrimaryPowerType()
	cachedSecondary = ERB.GetSecondaryResource()
	ERB.cachedSecondary = cachedSecondary
	ERB.cachedPrimary = cachedPrimary
	local pp, sp = p.primary, p.secondary
	local resourceMissing = sp.enabled == false or not cachedSecondary or ERB.BarHiddenByForm(sp, true)
	local powerMissing = pp.enabled == false or not cachedPrimary or ERB.BarHiddenByForm(pp)
		or (sp.hidePowerIfResource and sp.enabled ~= false and cachedSecondary)

	-- Expand Power Bar if No Resource.
	local expand, sign = 0, 1
	if pp.expandIfNoResource and resourceMissing and not ERB.unlockActive then
		expand = max(0, (sp.pipHeight or 20) + (pp.expandIfNoResourceExtraY or 0))
		sign = (EffY(sp, -38) >= EffY(pp, -54)) and 1 or -1
	end
	-- Shift Elements if No Resource / No Power: the elements stacked on the
	-- missing bar (the class resource on the power bar, the cast and GCD bars
	-- on both) move into its slot.
	local shiftRes, shiftPow = 0, 0
	if resourceMissing and (sp.shiftElementsIfNoResource or "None") ~= "None" then
		local d = (sp.pipHeight or 20) - 1 + (sp.shiftElementsIfNoResourceExtraY or 0)
		shiftRes = (sp.shiftElementsIfNoResource == "Up") and d or -d
	end
	if powerMissing and (pp.shiftElementsIfNoPower or "None") ~= "None" then
		local d = (pp.height or 14) - 1 + (pp.shiftElementsIfNoPowerExtraY or 0)
		shiftPow = (pp.shiftElementsIfNoPower == "Up") and d or -d
	end
	if ERB.unlockActive then
		shiftRes, shiftPow = 0, 0
	end
	ERB.shiftAbove = shiftRes + shiftPow

	BuildHealth(p)
	BuildPower(p, expand, sign, 0)
	BuildSecondary(p, shiftPow)
	ERB.UpdateVisibility()
	UpdateHealthBar()
	UpdatePrimaryBar()
	UpdateSecondaryResource()
end

-------------------------------------------------------------------------------
--  Visibility, fades, mouseover
-------------------------------------------------------------------------------
local moEligible = {}

local function SetVisible(frame, cfg, vis)
	if vis == true then
		frame:Show()
		frame:SetAlpha(ERB.ResolveBarAlpha(cfg))
	elseif vis == "mouseover" then
		frame:Show()
		frame:SetAlpha(frame:IsMouseOver() and ERB.ResolveBarAlpha(cfg) or 0)
	else
		frame:SetAlpha(0)
		frame:Hide()
	end
end

function ERB.UpdateVisibility()
	local p = Profile()
	if not p then
		return
	end
	local inVehicle = UnitHasVehicleUI("player")
	local unlock = ERB.unlockActive
	if healthBar then
		local hp = p.health
		local vis = hp.enabled and not inVehicle and not ERB.BarHiddenByForm(hp) and ERB.EvalVisibility(hp)
		if unlock and hp.enabled then vis = true end
		moEligible.health = vis == "mouseover"
		SetVisible(healthBar, hp, vis)
	end
	if primaryBar then
		local pp, sp = p.primary, p.secondary
		local hidePower = sp.hidePowerIfResource and sp.enabled ~= false and cachedSecondary
		local vis = not hidePower and pp.enabled ~= false and cachedPrimary and not inVehicle
			and not ERB.BarHiddenByForm(pp) and ERB.EvalVisibility(pp)
		if unlock and pp.enabled ~= false then vis = true end
		moEligible.primary = vis == "mouseover"
		SetVisible(primaryBar, pp, vis)
		ERB.UpdateDruidMana()
	end
	if secondaryFrame then
		local sp = p.secondary
		local vis = sp.enabled ~= false and cachedSecondary and not inVehicle
			and not ERB.BarHiddenByForm(sp, true) and ERB.EvalVisibility(sp)
		if unlock and sp.enabled ~= false then vis = true end
		moEligible.secondary = vis == "mouseover"
		SetVisible(secondaryFrame, sp, vis)
	end
	if ERB.UpdateCastVisibility then
		ERB.UpdateCastVisibility()
	end
end

-------------------------------------------------------------------------------
--  Driver: runes, mouseover poll, visibility conditions without events
-------------------------------------------------------------------------------
local driver = CreateFrame("Frame")
local acc, visAcc = 0, 0
driver:SetScript("OnUpdate", function(self, elapsed)
	acc = acc + elapsed
	visAcc = visAcc + elapsed
	if acc >= 0.05 then
		acc = 0
		if runeBusy and cachedSecondary and cachedSecondary.type == "runes" then
			UpdateSecondaryResource()
		end
		local p = Profile()
		if p then
			if moEligible.health and healthBar then
				healthBar:SetAlpha(healthBar:IsMouseOver() and ERB.ResolveBarAlpha(p.health) or 0)
			end
			if moEligible.primary and primaryBar then
				primaryBar:SetAlpha(primaryBar:IsMouseOver() and ERB.ResolveBarAlpha(p.primary) or 0)
			end
			if moEligible.secondary and secondaryFrame then
				secondaryFrame:SetAlpha(secondaryFrame:IsMouseOver() and ERB.ResolveBarAlpha(p.secondary) or 0)
			end
		end
	end
	-- Mounted / resting have no reliable event on 5.4.8: re-check twice a second.
	if visAcc >= 0.5 then
		visAcc = 0
		ERB.UpdateVisibility()
	end
end)
driver:Hide()
ERB.driver = driver

-------------------------------------------------------------------------------
--  Events
-------------------------------------------------------------------------------
local events = CreateFrame("Frame")
ERB.eventFrame = events

local REBUILD = {
	PLAYER_SPECIALIZATION_CHANGED = true, ACTIVE_TALENT_GROUP_CHANGED = true, PLAYER_TALENT_UPDATE = true,
	UPDATE_SHAPESHIFT_FORM = true, UNIT_DISPLAYPOWER = true, UNIT_MAXPOWER = true, PLAYER_ENTERING_WORLD = true,
	UNIT_ENTERED_VEHICLE = true, UNIT_EXITED_VEHICLE = true, RUNE_TYPE_UPDATE = true, UNIT_MAXHEALTH = false,
}

local pendingRebuild = false
local function QueueRebuild()
	if pendingRebuild then
		return
	end
	pendingRebuild = true
	P.After(0, function()
		pendingRebuild = false
		ERB.BuildBars()
	end)
end
ERB.QueueRebuild = QueueRebuild

events:SetScript("OnEvent", function(self, event, unit, arg2)
	if not ERB.db then
		return
	end
	if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_HEALTH_FREQUENT"
		or event == "UNIT_ABSORB_AMOUNT_CHANGED" or event == "UNIT_HEAL_ABSORB_AMOUNT_CHANGED" then
		UpdateHealthBar()
		if cachedSecondary and cachedSecondary.power == "STAGGER" then
			if event == "UNIT_MAXHEALTH" then QueueRebuild() else UpdateSecondaryResource() end
		end
		if event == "UNIT_MAXHEALTH" then
			-- Value hash lines follow the max.
			local p = Profile()
			if p.health.hashEnabled and p.health.hashMode == "value" then
				QueueRebuild()
			end
		end
	elseif event == "UNIT_POWER_FREQUENT" or event == "UNIT_POWER" then
		if arg2 == "MANA" and ERB.UpdateDruidMana then ERB.UpdateDruidMana() end
		if arg2 and cachedPrimary and arg2 == ERB.PowerToken(cachedPrimary) then
			UpdatePrimaryBar()
		end
		UpdateSecondaryResource()
	elseif REBUILD[event] then
		if (event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" or event == "UNIT_ENTERED_VEHICLE"
			or event == "UNIT_EXITED_VEHICLE") and unit ~= "player" then
			return
		end
		QueueRebuild()
	elseif event == "UNIT_AURA" then
		if unit == "player" then
			if cachedSecondary and (cachedSecondary.aura or cachedSecondary.power == "STAGGER") then
				UpdateSecondaryResource()
			end
			ERB.UpdateVisibility()
		end
	elseif event == "UNIT_COMBO_POINTS" or event == "PLAYER_TARGET_CHANGED" then
		UpdateSecondaryResource()
		ERB.UpdateVisibility()
	elseif event == "RUNE_POWER_UPDATE" then
		UpdateSecondaryResource()
	elseif event == "ECLIPSE_DIRECTION_CHANGE" then
		UpdateSecondaryResource()
	elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
		ERB.UpdateVisibility()
	else
		ERB.UpdateVisibility()
	end
end)

function ERB.RegisterBarEvents()
	local unitEvents = {
		"UNIT_HEALTH", "UNIT_HEALTH_FREQUENT", "UNIT_MAXHEALTH", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_HEAL_ABSORB_AMOUNT_CHANGED",
		"UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_AURA", "UNIT_COMBO_POINTS",
		"UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE",
	}
	for _, e in ipairs(unitEvents) do
		if events.RegisterUnitEvent then
			pcall(events.RegisterUnitEvent, events, e, "player", "vehicle")
		else
			pcall(events.RegisterEvent, events, e)
		end
	end
	for _, e in ipairs({ "PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_TALENT_UPDATE",
		"UPDATE_SHAPESHIFT_FORM", "PLAYER_ENTERING_WORLD", "RUNE_POWER_UPDATE", "RUNE_TYPE_UPDATE",
		"PLAYER_TARGET_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE",
		"ZONE_CHANGED_NEW_AREA", "PLAYER_UPDATE_RESTING", "ECLIPSE_DIRECTION_CHANGE" }) do
		pcall(events.RegisterEvent, events, e)
	end
	driver:Show()
end

P.OnApply(function()
	ERB.BuildBars()
end)

-------------------------------------------------------------------------------
--  Unlock Mode elements (EllesmereUI core Unlock Mode, retail ERB
--  RegisterUnlockElements). Positions: cfg.unlockPos, CENTER offsets from the
--  screen center in UIParent units.
-------------------------------------------------------------------------------
-- key: Unlock Mode key; getFrame: the frame; cfgOf: its settings table;
-- isOn: shown at all; sizeOf(cfg) -> width key, height key, orientation (the
-- stored pair is turned for a vertical bar), nil = no resize.
function P.UnlockElement(key, label, order, getFrame, cfgOf, isOn, sizeOf)
	local function Keys(axis)
		local wk, hk, ori = sizeOf(cfgOf())
		if IsVertical(ori) then
			wk, hk = hk, wk
		end
		return axis == "w" and wk or hk
	end
	local function SetSize(axis, v)
		local cfg = cfgOf()
		cfg[Keys(axis)] = math.max(floor(v + 0.5), 2)
		ERB:ApplyAll()
	end
	return ns.MakeUnlockElement({
		key = key,
		label = label,
		group = "Resource Bars",
		order = 500 + order,
		noResize = not sizeOf or nil,
		getFrame = getFrame,
		isHidden = function()
			return not getFrame() or (isOn and not isOn())
		end,
		getSize = function()
			local f = getFrame()
			if f then
				return f:GetWidth(), f:GetHeight()
			end
			return 214, 16
		end,
		setWidth = sizeOf and function(_, w) SetSize("w", w) end or nil,
		setHeight = sizeOf and function(_, h) SetSize("h", h) end or nil,
		savePos = function(_, point, relPoint, x, y)
			if not point then return end
			cfgOf().unlockPos = { point = point, relPoint = relPoint or point, x = x, y = y }
			if not ns._unlockActive then
				ERB:ApplyAll()
			end
		end,
		loadPos = function()
			local pos = cfgOf().unlockPos
			if not pos or not pos.point then
				return nil
			end
			return { point = pos.point, relPoint = pos.relPoint or pos.point, x = pos.x, y = pos.y }
		end,
		clearPos = function()
			cfgOf().unlockPos = nil
		end,
		applyPos = function()
			ERB:ApplyAll()
		end,
	})
end

-- Bars show (sample values) while Unlock Mode is open.
local function SetUnlocked(on)
	ERB.unlockActive = on and true or nil
	if ERB.db then
		ERB:ApplyAll()
	end
end

function ERB.RegisterUnlock()
	if not ns.RegisterUnlockElements then
		return
	end
	local function C(key) return function() return Profile()[key] end end
	local function Sized(cfg) return "width", "height", cfg.orientation or Profile().general.orientation end
	ns:RegisterUnlockElements({
		P.UnlockElement("ERB_Health", "Health Bar", 0, function() return healthBar end, C("health"),
			function() return Profile().health.enabled end, Sized),
		P.UnlockElement("ERB_Power", "Power Bar", 1, function() return primaryBar end, C("primary"),
			function() return Profile().primary.enabled ~= false end, Sized),
		P.UnlockElement("ERB_ClassResource", "Class Resource", 2, function() return secondaryFrame end, C("secondary"),
			function() return Profile().secondary.enabled ~= false and cachedSecondary ~= nil end,
			function(cfg) return "pipWidth", "pipHeight", cfg.pipOrientation end),
	}, "EllesmereUIResourceBars")
	ns:RegisterUnlockModeListener("EllesmereUIResourceBars", SetUnlocked)
end
