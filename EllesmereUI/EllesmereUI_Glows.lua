-------------------------------------------------------------------------------
--  EllesmereUI_Glows.lua (retail EllesmereUI_Glows.lua, 5.4.8 port)
--  Shared glow rendering engine for the EllesmereUI addon suite.
--  Provides: Pixel Glow (procedural ants), Action Button Glow, Auto-Cast
--  Shine, Shape Glow, sheet glows (GCD, Modern WoW, Classic WoW) and
--  Blackout (solid colour fill with adjustable transparency).
--  Each addon attaches to EllesmereUI.Glows.* instead of duplicating engines.
--
--  5.4.8 differences (same public API, same style indexes):
--  * No atlases and no FlipBook animations: the sheet styles cycle a texture
--    sheet with SetTexCoord from the central driver. The retail GCD and
--    Modern WoW Glow atlases do not exist on this client: GCD uses the
--    IconAlertAnts sheet (faster, tighter), Modern WoW Glow is the IconAlert
--    glow pulsing (the 5.4.8 proc glow art).
--  * No mask textures: ApplyMaskWith and opts.shapeMask / maskWith do nothing.
--  * No 12.1 restricted aura buttons: the "engine" host draws exactly like an
--    "icon" host (StartEngineGlow keeps retail's style remaps so a saved
--    value looks the same as on retail), StartAnimatedAnts is the driver ants.
--  * SetColorTexture -> SetTexture(r, g, b, a); no secret values.
-------------------------------------------------------------------------------
if not EllesmereUI then return end
if EllesmereUI.Glows then return end  -- already loaded

local floor = math.floor
local min   = math.min
local ceil  = math.ceil
local sin   = math.sin

-------------------------------------------------------------------------------
--  Style Definitions (superset of all addons; retail order and names)
--  Sheet entries: texture, rows, columns, frames, duration, frameW, frameH,
--  sheetW, sheetH (pixels), texPadding. pulse = alpha-pulsing glow art.
-------------------------------------------------------------------------------
local ANTS_TEX       = [[Interface\SpellActivationOverlay\IconAlertAnts]]
local ICON_ALERT_TEX = [[Interface\SpellActivationOverlay\IconAlert]]

local GLOW_STYLES = {
	{ name = "Pixel Glow",         procedural = true },
	{ name = "Action Button Glow", buttonGlow = true },
	{ name = "Auto-Cast Shine",    autocast   = true },
	{ name = "Shape Glow",         shapeGlow  = true },
	-- Retail atlas RotationHelper_Ants_Flipbook (not on 5.4.8): the ants
	-- sheet, quicker. 1.33: the ant ring (about 3/4 of the 48px cell) sits
	-- on the icon edge, like the retail atlas.
	{ name = "GCD",
	  texture = ANTS_TEX, sheetAnts = true,
	  rows = 5, columns = 5, frames = 22, duration = 0.25,
	  frameW = 48, frameH = 48, sheetW = 256, sheetH = 256, texPadding = 1.33 },
	-- Retail atlas UI-HUD-ActionBar-Proc-Loop-Flipbook (not on 5.4.8): the
	-- IconAlert glow, pulsing.
	{ name = "Modern WoW Glow",
	  pulse = true, texPadding = 1.4 },
	{ name = "Classic WoW Glow",
	  texture = ANTS_TEX,
	  -- 5x5 grid, only the first 22 cells are real ant frames.
	  rows = 5, columns = 5, frames = 22, duration = 0.3,
	  frameW = 48, frameH = 48, sheetW = 256, sheetH = 256, texPadding = 1.25 },
	{ name = "Blackout",           solidFill = true },
}

-------------------------------------------------------------------------------
--  Texture constants
-------------------------------------------------------------------------------
local BG_GLOW_L, BG_GLOW_R = 0.00781250, 0.50781250
local BG_GLOW_T, BG_GLOW_B = 0.27734375, 0.52734375
-- 5.4.8 AutoCastShine sparkle (retail uses the Legion artifacts sheet).
local SHINE_TEX    = [[Interface\ItemSocketingFrame\UI-ItemSockets]]
local SHINE_COORDS = { 0.3984375, 0.4453125, 0.40234375, 0.44921875 }
local SPARKLE_LAYER_SIZES = { 7, 6, 5, 4 }

-------------------------------------------------------------------------------
--  Central Glow Driver
--  One OnUpdate (on a frame we own) animates every active glow at ~60fps.
--  Hidden when no glow is registered (zero idle cost).
-------------------------------------------------------------------------------
local DRIVER_GATE = 0.016

local _reg      = {}
local _regFn    = {}
local _regIndex = {}
local _regKind  = {}
local _regCount = 0
local _driver
local _driverAccum = 0

-- Unregister a wrapper (no-op when not registered or registered as another kind).
local function _Unregister(wrapper, kind)
	local idx = _regIndex[wrapper]
	if not idx then return end
	if kind and _regKind[wrapper] ~= kind then return end
	local last = _reg[_regCount]
	_reg[idx] = last
	_regFn[idx] = _regFn[_regCount]
	_regIndex[last] = idx
	_reg[_regCount] = nil
	_regFn[_regCount] = nil
	_regCount = _regCount - 1
	_regIndex[wrapper] = nil
	_regKind[wrapper] = nil
	if _regCount == 0 and _driver then _driver:Hide() end
end

local function _DriverOnUpdate(self, elapsed)
	local dt = _driverAccum + elapsed
	if dt < DRIVER_GATE then
		_driverAccum = dt
		return
	end
	_driverAccum = 0
	local i = 1
	while i <= _regCount do
		local wrapper = _reg[i]
		-- Hidden wrappers (or hidden ancestors) skip their tick.
		if wrapper:IsVisible() then
			local fn = _regFn[i]
			if fn then fn(wrapper, dt) end
		end
		if _reg[i] == wrapper then
			i = i + 1
		end
	end
	if _regCount == 0 then
		self:Hide()
	end
end

local function _Arm()
	if not _driver then
		_driver = CreateFrame("Frame")
		_driver:Hide()
		_driver:SetScript("OnUpdate", _DriverOnUpdate)
	end
	_driverAccum = 0
	_driver:Show()
end

local function _Register(wrapper, fn, kind)
	local i = _regIndex[wrapper]
	if i then
		_regFn[i] = fn
		_regKind[wrapper] = kind
		return
	end
	_regCount = _regCount + 1
	_reg[_regCount] = wrapper
	_regFn[_regCount] = fn
	_regIndex[wrapper] = _regCount
	_regKind[wrapper] = kind
	if _regCount == 1 then _Arm() end
end

-------------------------------------------------------------------------------
--  Procedural Ants Engine (dash segments)
--  Retail scrolls a tileable dash strip with SetTexCoord past 1. The 5.4.8
--  client clamps texcoords instead of repeating them, so that shows a single
--  dash. Here every dash is its own solid texture placed along the perimeter
--  (clockwise, same phase math and 50% duty cycle as the retail strip); a dash
--  that crosses a corner is split into two pieces.
-------------------------------------------------------------------------------
local function _AntsResolveSize(self, d)
	local w, h = self:GetSize()
	w = tonumber(w) or 0
	h = tonumber(h) or 0
	if w * h == 0 and d.fallbackW and d.fallbackW > 0 then
		w = d.fallbackW; h = d.fallbackH or d.fallbackW
	end
	if w * h == 0 then return false end
	-- Snap size and thickness to physical pixels.
	local PP = EllesmereUI.PP
	local es = self:GetEffectiveScale()
	if not es or es < 0.1 then return false end
	local onePixel = ((PP and PP.perfect) or 1) / es
	w = floor(w / onePixel + 0.5) * onePixel
	h = floor(h / onePixel + 0.5) * onePixel
	if w < onePixel then w = onePixel end
	if h < onePixel then h = onePixel end
	if not (w > 0 and h > 0 and w + h < math.huge) then return false end
	local sTh = floor(d.th / onePixel + 0.5) * onePixel
	if sTh < onePixel then sTh = onePixel end
	d.sTh = sTh
	d.w = w; d.h = h
	d.perim = 2 * (w + h)
	-- Half of one dash period (retail strip duty cycle), never longer than the
	-- shorter edge so a dash spans at most one corner.
	local len = d.perim / d.N * 0.5
	local maxLen = min(w, h)
	if len > maxLen then len = maxLen end
	d.len = len
	return true
end

local function _AntsSeg(self, d, idx)
	local t = d.segs[idx]
	if not t then
		t = self:CreateTexture(nil, "OVERLAY", nil, 7)
		t:SetTexture(1, 1, 1, 1)
		t:SetVertexColor(d.r, d.g, d.b, d.a)
		d.segs[idx] = t
	end
	return t
end

-- Draw one straight piece [a, b) of the perimeter (both on the same edge).
local function _AntsPiece(self, d, idx, a, b)
	local t = _AntsSeg(self, d, idx)
	local w, h, th = d.w, d.h, d.sTh
	local len = b - a
	t:ClearAllPoints()
	if a < w then
		t:SetPoint("TOPLEFT", self, "TOPLEFT", a, 0)
		t:SetSize(len, th)
	elseif a < w + h then
		t:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -(a - w))
		t:SetSize(th, len)
	elseif a < 2 * w + h then
		t:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -(a - w - h), 0)
		t:SetSize(len, th)
	else
		t:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, a - 2 * w - h)
		t:SetSize(th, len)
	end
	t:Show()
end

local function _AntsDraw(self, d, phase)
	local w, h, P, N, len = d.w, d.h, d.perim, d.N, d.len
	local step = P / N
	local used = 0
	for i = 0, N - 1 do
		local cur = (i * step + phase * step) % P
		local remain = len
		while remain > 0.01 do
			local edgeEnd
			if cur < w then edgeEnd = w
			elseif cur < w + h then edgeEnd = w + h
			elseif cur < 2 * w + h then edgeEnd = 2 * w + h
			else edgeEnd = P end
			local piece = edgeEnd - cur
			if piece > remain then piece = remain end
			if piece > 0.01 then
				used = used + 1
				_AntsPiece(self, d, used, cur, cur + piece)
			end
			remain = remain - piece
			cur = edgeEnd
			if cur >= P then cur = 0 end
		end
	end
	for i = used + 1, #d.segs do d.segs[i]:Hide() end
end

local function _AntsOnUpdate(self, elapsed)
	local d = self._euiScrollData
	if not d then return end
	d.timer = d.timer + elapsed
	if d.timer >= d.period then d.timer = d.timer - d.period end
	if not (d.w > 0 and d.h > 0) then
		if not _AntsResolveSize(self, d) then return end
	end
	-- Phase in dash periods: N periods per loop, like the retail scroll.
	_AntsDraw(self, d, (d.timer / d.period) * d.N)
end

-- Static (non-marching) dashes at the base phase.
local function _AntsDrawStatic(self, d)
	_AntsDraw(self, d, 0)
end

local function _AntsStaticSettle(self, elapsed)
	local d = self._euiScrollData
	if not d then _Unregister(self, "ants"); return end
	if not (d.w > 0 and d.h > 0) then
		if not _AntsResolveSize(self, d) then return end
	end
	_AntsDrawStatic(self, d)
	_Unregister(self, "ants")
end

-- lineLen is accepted for call-signature compatibility but unused.
local function StartProceduralAnts(wrapper, N, th, period, lineLen, cr, cg, cb, szOrW, szH, bgR, bgG, bgB, bgA, static)
	if not wrapper._euiScrollData then
		wrapper._euiScrollData = { segs = {}, timer = 0, w = 0, h = 0 }
	end
	local d = wrapper._euiScrollData
	d.N = (N and N > 0) and N or 8
	d.period = period or 4
	d.w = 0; d.h = 0
	d.fallbackW = szOrW or 0; d.fallbackH = szH or szOrW or 0
	th = th or 2
	d.th = th
	d.r, d.g, d.b, d.a = cr, cg, cb, 1
	for i = 1, #d.segs do
		d.segs[i]:SetVertexColor(cr, cg, cb, 1)
		d.segs[i]:Hide()
	end
	-- bgR non-nil = background on (r = 0 is a valid black).
	if bgR then
		if not d.bgTop then
			local function mkBg(p1, p1f, p2, p2f)
				local t = wrapper:CreateTexture(nil, "OVERLAY", nil, 6)
				t:SetPoint(p1, wrapper, p1f)
				t:SetPoint(p2, wrapper, p2f)
				return t
			end
			d.bgTop    = mkBg("TOPLEFT", "TOPLEFT", "TOPRIGHT", "TOPRIGHT")
			d.bgBottom = mkBg("BOTTOMLEFT", "BOTTOMLEFT", "BOTTOMRIGHT", "BOTTOMRIGHT")
			d.bgLeft   = mkBg("TOPLEFT", "TOPLEFT", "BOTTOMLEFT", "BOTTOMLEFT")
			d.bgRight  = mkBg("TOPRIGHT", "TOPRIGHT", "BOTTOMRIGHT", "BOTTOMRIGHT")
		end
		bgA = bgA or 1
		d.bgTop:SetHeight(th); d.bgBottom:SetHeight(th)
		d.bgLeft:SetWidth(th); d.bgRight:SetWidth(th)
		d.bgTop:SetTexture(bgR, bgG or 0, bgB or 0, bgA);    d.bgTop:Show()
		d.bgBottom:SetTexture(bgR, bgG or 0, bgB or 0, bgA); d.bgBottom:Show()
		d.bgLeft:SetTexture(bgR, bgG or 0, bgB or 0, bgA);   d.bgLeft:Show()
		d.bgRight:SetTexture(bgR, bgG or 0, bgB or 0, bgA);  d.bgRight:Show()
	elseif d.bgTop then
		d.bgTop:Hide(); d.bgBottom:Hide(); d.bgLeft:Hide(); d.bgRight:Hide()
	end
	if static then
		if _AntsResolveSize(wrapper, d) then
			_AntsDrawStatic(wrapper, d)
			_Unregister(wrapper, "ants")
		else
			_Register(wrapper, _AntsStaticSettle, "ants")
		end
	else
		_Register(wrapper, _AntsOnUpdate, "ants")
	end
end

local function StopProceduralAnts(wrapper)
	_Unregister(wrapper, "ants")
	local d = wrapper._euiScrollData
	if d then
		for i = 1, #d.segs do d.segs[i]:Hide() end
		if d.bgTop then d.bgTop:Hide(); d.bgBottom:Hide(); d.bgLeft:Hide(); d.bgRight:Hide() end
	end
end

-- Recolor active dashes in place.
local function SetProceduralAntsColor(wrapper, r, g, b, a)
	local d = wrapper._euiScrollData
	if not d then return end
	a = a or 1
	d.r, d.g, d.b, d.a = r, g, b, a
	for i = 1, #d.segs do d.segs[i]:SetVertexColor(r, g, b, a) end
end

-------------------------------------------------------------------------------
--  Action Button Glow Engine
--  Outer glow (soft border from IconAlert) + animated marching ants.
-------------------------------------------------------------------------------
local ANTS_FRAME_TIME = 0.017  -- ~0.37s per 22-frame loop
local function _AnimateTexCoords(tex, sheetW, sheetH, cellW, cellH, numFrames, elapsed, frameTime)
	frameTime = frameTime or ANTS_FRAME_TIME
	if not tex._euiAnimCols then
		tex._euiAnimCols  = floor(sheetW / cellW)
		tex._euiAnimColW  = cellW / sheetW
		tex._euiAnimRowH  = cellH / sheetH
		tex._euiAnimFrame = 0
		tex._euiAnimAccum = 0
	end
	tex._euiAnimAccum = tex._euiAnimAccum + elapsed
	if tex._euiAnimAccum < frameTime then return end

	local advance = floor(tex._euiAnimAccum / frameTime)
	tex._euiAnimAccum = tex._euiAnimAccum - advance * frameTime
	local frame = (tex._euiAnimFrame + advance) % numFrames
	tex._euiAnimFrame = frame

	local cols = tex._euiAnimCols
	local colW = tex._euiAnimColW
	local rowH = tex._euiAnimRowH
	local left = (frame % cols) * colW
	local top  = floor(frame / cols) * rowH
	tex:SetTexCoord(left, left + colW, top, top + rowH)
end

local function _ButtonGlowOnUpdate(self, elapsed)
	local d = self._euiBgData
	if not d then return end
	_AnimateTexCoords(d.ants, 256, 256, 48, 48, 22, elapsed)
end

local function StartButtonGlow(wrapper, szOrW, cr, cg, cb, scale, szH)
	scale = scale or 1.0
	local w = szOrW or 36
	local h = szH or w
	if not wrapper._euiBgData then
		local glow = wrapper:CreateTexture(nil, "OVERLAY", nil, 7)
		glow:SetTexture(ICON_ALERT_TEX)
		glow:SetTexCoord(BG_GLOW_L, BG_GLOW_R, BG_GLOW_T, BG_GLOW_B)
		glow:SetBlendMode("ADD")
		glow:SetPoint("CENTER")
		local ants = wrapper:CreateTexture(nil, "OVERLAY", nil, 7)
		ants:SetTexture(ANTS_TEX)
		ants:SetBlendMode("ADD")
		ants:SetPoint("CENTER")
		wrapper._euiBgData = { glow = glow, ants = ants }
	end
	local d = wrapper._euiBgData
	-- The ants frames carry transparent padding: scale up to meet the edge.
	local antsW, antsH = w * 1.35, h * 1.35
	local glowW, glowH = antsW * 1.3, antsH * 1.3
	d.glow:SetSize(glowW, glowH)
	d.glow:SetDesaturated(true); d.glow:SetVertexColor(cr, cg, cb, 1)
	d.glow:SetAlpha(1); d.glow:Show()
	d.ants:SetSize(antsW, antsH)
	d.ants:SetDesaturated(true); d.ants:SetVertexColor(cr, cg, cb, 1)
	d.ants:SetAlpha(1); d.ants:Show()
	_Register(wrapper, _ButtonGlowOnUpdate, "button")
end

local function StopButtonGlow(wrapper)
	_Unregister(wrapper, "button")
	if wrapper._euiBgData then
		wrapper._euiBgData.ants:Hide()
		wrapper._euiBgData.glow:Hide()
	end
end

-------------------------------------------------------------------------------
--  Auto-Cast Shine Engine
--  4 layers of sparkle dots orbit the perimeter at staggered speeds.
-------------------------------------------------------------------------------
local function _OrbitXY(dist, w, h)
	if dist < w then
		return dist, 0
	end
	dist = dist - w
	if dist < h then
		return w, -dist
	end
	dist = dist - h
	if dist < w then
		return w - dist, -h
	end
	return 0, -(h - (dist - w))
end

local function _AutoCastOnUpdate(self, elapsed)
	local d = self._euiAcData
	if not d then return end
	local layerPhase = d.layerPhase
	local basePeriod = d.period
	for layer = 1, 4 do
		layerPhase[layer] = layerPhase[layer] + elapsed / (basePeriod * layer)
		if layerPhase[layer] > 1 then layerPhase[layer] = layerPhase[layer] - 1 end
	end
	d._accum = (d._accum or 0) + elapsed
	if d._accum < 0.016 then return end
	d._accum = 0
	local w, h = d.w, d.h
	if w * h == 0 then
		w, h = self:GetSize()
		w = tonumber(w) or 0
		h = tonumber(h) or 0
		if w * h == 0 and d.fallbackW and d.fallbackW > 0 then
			w = d.fallbackW; h = d.fallbackH or d.fallbackW
		end
		if w * h == 0 then return end
		d.w = w; d.h = h
		d.perim = 2 * (w + h)
		d.spacing = d.perim / d.dotsPerLayer
	end
	local perim = d.perim
	local spacing = d.spacing
	local sparkles = d.sparkles
	local dotsPerLayer = d.dotsPerLayer
	local idx = 0
	for layer = 1, 4 do
		local phase = layerPhase[layer] * perim
		for i = 1, dotsPerLayer do
			idx = idx + 1
			local dist = (spacing * i + phase) % perim
			local px, py = _OrbitXY(dist, w, h)
			local dot = sparkles[idx]
			dot:ClearAllPoints()
			dot:SetPoint("CENTER", self, "TOPLEFT", px, py)
		end
	end
end

local function StartAutoCastShine(wrapper, szOrW, cr, cg, cb, scale, szH)
	scale = scale or 1.0
	local dotsPerLayer = 4
	local totalDots = dotsPerLayer * 4
	if not wrapper._euiAcData then
		wrapper._euiAcData = {
			sparkles = {},
			layerPhase = { 0, 0.25, 0.5, 0.75 },
			dotsPerLayer = dotsPerLayer,
			period = 2,
			w = 0, h = 0,
		}
	end
	local d = wrapper._euiAcData
	d.dotsPerLayer = dotsPerLayer
	d.layerPhase[1] = 0; d.layerPhase[2] = 0.25; d.layerPhase[3] = 0.5; d.layerPhase[4] = 0.75
	for idx = 1, totalDots do
		if not d.sparkles[idx] then
			local dot = wrapper:CreateTexture(nil, "OVERLAY", nil, 7)
			dot:SetTexture(SHINE_TEX)
			dot:SetTexCoord(SHINE_COORDS[1], SHINE_COORDS[2], SHINE_COORDS[3], SHINE_COORDS[4])
			dot:SetDesaturated(true); dot:SetBlendMode("ADD")
			d.sparkles[idx] = dot
		end
		local layer = ceil(idx / dotsPerLayer)
		local baseSz = (SPARKLE_LAYER_SIZES[layer] or 4) * scale
		d.sparkles[idx]:SetSize(baseSz, baseSz)
		d.sparkles[idx]:SetVertexColor(cr, cg, cb, 1)
		d.sparkles[idx]:Show()
	end
	for idx = totalDots + 1, #d.sparkles do d.sparkles[idx]:Hide() end
	d.w = 0; d.h = 0; d.fallbackW = szOrW or 0; d.fallbackH = szH or szOrW or 0
	_Register(wrapper, _AutoCastOnUpdate, "autocast")
end

local function StopAutoCastShine(wrapper)
	_Unregister(wrapper, "autocast")
	if wrapper._euiAcData then
		for _, dot in ipairs(wrapper._euiAcData.sparkles) do dot:Hide() end
	end
end

-------------------------------------------------------------------------------
--  Shape Glow Engine
--  Pulsing additive glow using the icon's shape texture.
--  opts.maskPath   - the shape mask texture (drawn as the glow)
--  opts.borderPath - the shape border texture
--  opts.shapeMask  - retail MaskTexture (5.4.8: unused, no masks)
-------------------------------------------------------------------------------
local function _ShapeGlowOnUpdate(self, elapsed)
	local d = self._euiSgData
	if not d then return end
	local timer = d.timer + elapsed * d.speed
	if timer > 6.2832 then timer = timer - 6.2832 end
	d.timer = timer
	d.glow:SetAlpha(0.25 + 0.25 * (0.5 + 0.5 * sin(timer)))
	local bright = d.bright
	if bright then
		local bTimer = (d.bTimer or 0) + elapsed * d.speed * 0.50
		if bTimer > 6.2832 then bTimer = bTimer - 6.2832 end
		d.bTimer = bTimer
		bright:SetAlpha(0.35 + 0.10 * (0.5 + 0.5 * sin(bTimer)))
	end
end

local function StartShapeGlow(wrapper, sz, cr, cg, cb, scale, opts)
	scale = scale or 1.20
	opts = opts or {}
	local btn = opts.anchorFrame or wrapper:GetParent()
	if not btn then return end
	if not wrapper._euiSgData then
		local glow   = btn:CreateTexture(nil, "OVERLAY", nil, 5)
		glow:SetBlendMode("ADD")
		local edge   = btn:CreateTexture(nil, "OVERLAY", nil, 5)
		edge:SetBlendMode("ADD")
		local bright = btn:CreateTexture(nil, "OVERLAY", nil, 7)
		bright:SetBlendMode("ADD")
		wrapper._euiSgData = { glow = glow, edge = edge, bright = bright, timer = 0, speed = 10.0 }
	end
	local d = wrapper._euiSgData
	d.timer = 0

	local extend = (sz or 36) * 0.10
	d.glow:ClearAllPoints()
	d.glow:SetPoint("TOPLEFT",     btn, "TOPLEFT",     -extend,  extend)
	d.glow:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT",  extend, -extend)
	local maskPath   = opts.maskPath
	local borderPath = opts.borderPath
	if maskPath then
		d.glow:SetTexture(maskPath)
	else
		d.glow:SetTexture(1, 1, 1, 1)
	end
	d.glow:SetVertexColor(cr, cg, cb, 1)
	d.glow:SetAlpha(1); d.glow:Show()

	d.edge:Hide()

	d.bright:ClearAllPoints(); d.bright:SetAllPoints(btn)
	if borderPath then
		d.bright:SetTexture(borderPath)
	else
		d.bright:SetTexture(0, 0, 0, 0)
	end
	d.bright:SetVertexColor(cr, cg, cb, 1)
	d.bright:SetAlpha(0.5); d.bright:Show()
	_Register(wrapper, _ShapeGlowOnUpdate, "shape")
end

local function StopShapeGlow(wrapper)
	_Unregister(wrapper, "shape")
	if wrapper._euiSgData then
		wrapper._euiSgData.glow:Hide()
		wrapper._euiSgData.edge:Hide()
		wrapper._euiSgData.bright:Hide()
	end
end

-------------------------------------------------------------------------------
--  Sheet Glow Engine (retail FlipBook engine)
--  GCD / Classic WoW Glow cycle a texture sheet from the driver; Modern WoW
--  Glow pulses the IconAlert glow. opts.abgHalo adds Action Button Glow's
--  soft outer halo (StartEngineGlow's ABG stand-in).
-------------------------------------------------------------------------------
local function _EnsureFlip(wrapper, ants, halo)
	local d = wrapper._euiFlipData
	if not d then
		local tex = wrapper:CreateTexture(nil, "OVERLAY", nil, 7)
		tex:SetPoint("CENTER")
		tex:Hide()
		d = { tex = tex }
		wrapper._euiFlipData = d
	end
	if ants and not d.ants then
		local aTex = wrapper:CreateTexture(nil, "OVERLAY", nil, 7)
		aTex:SetPoint("CENTER")
		aTex:SetBlendMode("ADD")
		aTex:Hide()
		d.ants = aTex
	end
	if halo and not d.halo then
		local haloTex = wrapper:CreateTexture(nil, "OVERLAY", nil, 6)
		haloTex:SetTexture(ICON_ALERT_TEX)
		haloTex:SetTexCoord(BG_GLOW_L, BG_GLOW_R, BG_GLOW_T, BG_GLOW_B)
		haloTex:SetBlendMode("ADD")
		haloTex:SetPoint("CENTER")
		haloTex:Hide()
		d.halo = haloTex
	end
	return d
end

local function _FlipOnUpdate(self, elapsed)
	local d = self._euiFlipData
	local e = d and d.entry
	if not e then return end
	if e.pulse then
		local t = (d.pulseT or 0) + elapsed
		if t > 1.2 then t = t - 1.2 end
		d.pulseT = t
		local a = 0.55 + 0.45 * (0.5 + 0.5 * sin(t / 1.2 * 6.2832))
		d.tex:SetAlpha(a)
		if d.ants and d.ants:IsShown() then d.ants:SetAlpha(0.35 * a) end
		return
	end
	local ft = (e.duration or 1) / (e.frames or 1)
	_AnimateTexCoords(d.tex, e.sheetW or 256, e.sheetH or 256, e.frameW or 48, e.frameH or 48, e.frames or 1, elapsed, ft)
	if d.ants and d.ants:IsShown() then
		_AnimateTexCoords(d.ants, e.sheetW or 256, e.sheetH or 256, e.frameW or 48, e.frameH or 48, e.frames or 1, elapsed, ft)
	end
end

local function _ResetSheet(tex)
	tex._euiAnimCols = nil
end

local function StartFlipBookGlow(wrapper, szOrW, entry, cr, cg, cb, szH, opts)
	local w = szOrW or 36
	local h = szH or w
	local texW = w * (entry.texPadding or 1)
	local texH = h * (entry.texPadding or 1)

	local d = _EnsureFlip(wrapper, entry.sheetAnts or entry.pulse, opts and opts.abgHalo)
	d.entry = entry
	d.pulseT = 0
	local tex = d.tex
	_ResetSheet(tex)
	if entry.pulse then
		-- IconAlert glow, a bit wider than the ants (the retail proc loop
		-- reaches past the icon edge).
		tex:SetTexture(ICON_ALERT_TEX)
		tex:SetTexCoord(BG_GLOW_L, BG_GLOW_R, BG_GLOW_T, BG_GLOW_B)
		tex:SetBlendMode("ADD")
		tex:SetSize(texW * 1.3, texH * 1.3)
	else
		tex:SetTexture(entry.texture or ANTS_TEX)
		tex:SetBlendMode("ADD")
		tex:SetSize(texW, texH)
		local cw = (entry.frameW or 48) / (entry.sheetW or 256)
		local ch = (entry.frameH or 48) / (entry.sheetH or 256)
		tex:SetTexCoord(0, cw, 0, ch)
	end
	if cr then
		tex:SetDesaturated(true)
		tex:SetVertexColor(cr, cg, cb)
	else
		-- no color requested: the art's own look
		tex:SetDesaturated(false)
		tex:SetVertexColor(1, 1, 1)
	end
	tex:SetAlpha(1)
	tex:Show()

	-- Ants overlay: an untinted duplicate at low alpha (retail atlas styles).
	if entry.sheetAnts or entry.pulse then
		local a = d.ants
		_ResetSheet(a)
		a:SetTexture(ANTS_TEX)
		a:SetTexCoord(0, 48 / 256, 0, 48 / 256)
		a:SetSize(texW, texH)
		a:SetDesaturated(false)
		a:SetVertexColor(1, 1, 1)
		a:SetAlpha(0.35)
		-- The pulse style has no sheet of its own: its ants stay still.
		a:SetShown(entry.sheetAnts and true or false)
	elseif d.ants then
		d.ants:Hide()
	end

	if opts and opts.abgHalo then
		d.halo:SetSize(texW * 1.3, texH * 1.3)
		d.halo:SetDesaturated(true)
		d.halo:SetVertexColor(opts.haloR or 1.0, opts.haloG or 0.788, opts.haloB or 0.137, 1)
		d.halo:Show()
	elseif d.halo then
		d.halo:Hide()
	end

	_Register(wrapper, _FlipOnUpdate, "flip")
end

local function StopFlipBookGlow(wrapper)
	_Unregister(wrapper, "flip")
	local d = wrapper._euiFlipData
	if d then
		d.tex:Hide()
		if d.ants then d.ants:Hide() end
		if d.halo then d.halo:Hide() end
	end
end

-------------------------------------------------------------------------------
--  Solid Fill Engine (Blackout)
--  One colour texture covering the wrapper at a caller-chosen alpha. Static.
-------------------------------------------------------------------------------
local function StartSolidFill(wrapper, cr, cg, cb, opts)
	opts = opts or {}
	if not wrapper._euiFillData then
		local tex = wrapper:CreateTexture(nil, "OVERLAY", nil, 7)
		tex:SetAllPoints(wrapper)
		wrapper._euiFillData = { tex = tex }
	end
	local d = wrapper._euiFillData
	d.tex:SetTexture(cr or 0, cg or 0, cb or 0, opts.alpha or 1)
	d.tex:SetAlpha(1)
	d.tex:Show()
end

local function StopSolidFill(wrapper)
	if wrapper._euiFillData then wrapper._euiFillData.tex:Hide() end
end

-- Retail C-side animated ants: on 5.4.8 the driver ants (same look).
local function StopAnimatedAnts(wrapper)
	StopProceduralAnts(wrapper)
end

-------------------------------------------------------------------------------
--  StopAllGlows - clears any active glow engine on a wrapper frame
-------------------------------------------------------------------------------
local function StopAllGlows(wrapper)
	if not wrapper then return end
	StopProceduralAnts(wrapper)
	StopButtonGlow(wrapper)
	StopAutoCastShine(wrapper)
	StopShapeGlow(wrapper)
	StopFlipBookGlow(wrapper)
	StopSolidFill(wrapper)
	local steal = wrapper._euiStealTex
	if steal then steal:Hide() end
	local sig = wrapper._euiSpecSig
	if sig then sig.idx = nil end
	_Unregister(wrapper)
end

-- Retail: bounds every glow texture with a MaskTexture. 5.4.8 has no masks.
local function ApplyMaskWith(wrapper, mask)
end

-------------------------------------------------------------------------------
--  StartGlow - unified entry point
--  wrapper  : Frame to render the glow on
--  styleIdx : index into GLOW_STYLES (1-based)
--  szOrW, szH : icon/frame size in pixels
--  cr,cg,cb : glow color (0-1)
--  opts     : .N, .th, .period, .bg (pixel glow), .maskPath, .borderPath,
--             .anchorFrame (shape glow), .untinted, .alpha (Blackout), .abgHalo
-------------------------------------------------------------------------------
local function StartGlow(wrapper, styleIdx, szOrW, cr, cg, cb, opts, szH)
	if not wrapper then return end
	styleIdx = tonumber(styleIdx) or 1
	if styleIdx < 1 or styleIdx > #GLOW_STYLES then styleIdx = 1 end
	local entry = GLOW_STYLES[styleIdx]
	opts = opts or {}
	local w = szOrW or 36
	local h = szH or w
	local noColor = (cr == nil)
	local keepUntinted = opts.untinted and cr == nil
	cr = cr or 1; cg = cg or 1; cb = cb or 1

	StopAllGlows(wrapper)

	if entry.procedural then
		local N       = opts.N or 8
		local th      = opts.th or 2
		local period  = opts.period or 4
		local lineLen = floor((w + h) * (2 / N - 0.1))
		lineLen = min(lineLen, min(w, h))
		if lineLen < 1 then lineLen = 1 end
		local bg = opts.bg
		StartProceduralAnts(wrapper, N, th, period, lineLen, cr, cg, cb, w, h,
			bg and (bg.r or 0) or nil, bg and (bg.g or 0) or nil, bg and (bg.b or 0) or nil, bg and (bg.a or 1) or nil)

	elseif entry.buttonGlow then
		StartButtonGlow(wrapper, w, cr, cg, cb, nil, h)

	elseif entry.autocast then
		StartAutoCastShine(wrapper, w, cr, cg, cb, 1.0, h)

	elseif entry.shapeGlow then
		StartShapeGlow(wrapper, w, cr, cg, cb, 1.20, opts)

	elseif entry.solidFill then
		StartSolidFill(wrapper, noColor and 0 or cr, noColor and 0 or cg, noColor and 0 or cb, opts)

	else
		if keepUntinted then
			StartFlipBookGlow(wrapper, w, entry, nil, nil, nil, h, opts)
		else
			StartFlipBookGlow(wrapper, w, entry, cr, cg, cb, h, opts)
		end
	end

	wrapper._euiGlowActive = true
	wrapper:SetAlpha(1)
end

local function StopGlow(wrapper)
	if not wrapper then return end
	StopAllGlows(wrapper)
	wrapper._euiGlowActive = false
	wrapper:SetAlpha(0)
end

-- Retail C-side animated Pixel Glow for engine aura buttons; 5.4.8 draws
-- the driver ants (same signature: ca = dash alpha).
local function StartAnimatedAnts(wrapper, N, th, period, cr, cg, cb, w, h, ca, bgR, bgG, bgB, bgA)
	w = w or 36; h = h or w
	StartProceduralAnts(wrapper, N, th, period, nil, cr or 1, cg or 1, cb or 1, w, h, bgR, bgG, bgB, bgA)
	if ca and ca ~= 1 then SetProceduralAntsColor(wrapper, cr or 1, cg or 1, cb or 1, ca) end
end

-------------------------------------------------------------------------------
--  StartEngineGlow - retail StartGlow for engine aura-button hosts. Kept with
--  the retail remaps (ABG -> Classic sheet + halo, Auto-Cast / Shape ->
--  Modern, Blackout -> Pixel) so a saved value looks as it does on retail.
-------------------------------------------------------------------------------
local ABG_HALO_OPTS = { abgHalo = true }
local function StartEngineGlow(wrapper, styleIdx, szOrW, cr, cg, cb, opts, szH)
	if not wrapper then return end
	styleIdx = tonumber(styleIdx) or 1
	if styleIdx < 1 or styleIdx > #GLOW_STYLES or GLOW_STYLES[styleIdx].solidFill then styleIdx = 1 end
	local entry = GLOW_STYLES[styleIdx]
	if entry.procedural then
		opts = opts or {}
		local w = szOrW or 36
		local bg = opts.bg
		StopAllGlows(wrapper)
		StartAnimatedAnts(wrapper, opts.N or 8, opts.th or 2, opts.period or 4,
			cr or 1, cg or 1, cb or 1, w, szH or w, nil,
			bg and (bg.r or 0) or nil, bg and (bg.g or 0) or nil, bg and (bg.b or 0) or nil, bg and (bg.a or 1) or nil)
		wrapper._euiGlowActive = true
		wrapper:SetAlpha(1)
		return
	end
	if entry.buttonGlow then
		styleIdx = 7
		if opts then opts.abgHalo = true; opts.untinted = nil else opts = ABG_HALO_OPTS end
		opts.haloR, opts.haloG, opts.haloB = cr, cg, cb
		cr, cg, cb = nil, nil, nil
	elseif entry.autocast or entry.shapeGlow then
		styleIdx = 6
	end
	StartGlow(wrapper, styleIdx, szOrW, cr, cg, cb, opts, szH)
end

-------------------------------------------------------------------------------
--  Public API - attached to EllesmereUI.Glows
-------------------------------------------------------------------------------
local SAFE_STYLE_MAP = { [1] = 7, [2] = 6, [3] = 6, [4] = 6 }
local function RestrictionSafeStyle(idx)
	local entry = GLOW_STYLES[idx]
	if entry and (entry.procedural or entry.buttonGlow or entry.autocast or entry.shapeGlow) then
		return SAFE_STYLE_MAP[idx] or 6
	end
	return idx
end

EllesmereUI.Glows = {
	STYLES              = GLOW_STYLES,

	-- High-level API (recommended)
	StartGlow           = StartGlow,
	StartEngineGlow     = StartEngineGlow,
	StopGlow            = StopGlow,
	RestrictionSafeStyle = RestrictionSafeStyle,

	-- Low-level engines
	StartProceduralAnts = StartProceduralAnts,
	StopProceduralAnts  = StopProceduralAnts,
	SetProceduralAntsColor = SetProceduralAntsColor,
	StartButtonGlow     = StartButtonGlow,
	StopButtonGlow      = StopButtonGlow,
	StartAutoCastShine  = StartAutoCastShine,
	StopAutoCastShine   = StopAutoCastShine,
	StartAnimatedAnts   = StartAnimatedAnts,
	StopAnimatedAnts    = StopAnimatedAnts,
	StartShapeGlow      = StartShapeGlow,
	StopShapeGlow       = StopShapeGlow,
	StartFlipBookGlow   = StartFlipBookGlow,
	StopFlipBookGlow    = StopFlipBookGlow,
	StartSolidFill      = StartSolidFill,
	StopSolidFill       = StopSolidFill,
	ApplyMaskWith       = ApplyMaskWith,
	StopAllGlows        = StopAllGlows,
}

-------------------------------------------------------------------------------
--  Blizzard Border: the static art Blizzard's target frame puts on a buff it
--  can steal or purge (5.4.8 has the same texture).
-------------------------------------------------------------------------------
do
	local G = EllesmereUI.Glows
	local TEX = "Interface\\TargetingFrame\\UI-TargetingFrame-Stealable"
	local SCALE = 24 / 21
	G.STEALABLE_BORDER = 99

	function G.EnsureStealableBorder(host)
		local tex = host._euiStealTex
		if not tex then
			tex = host:CreateTexture(nil, "OVERLAY")
			tex:SetTexture(TEX)
			tex:SetBlendMode("ADD")
			tex:SetPoint("CENTER")
			tex:Hide()
			host._euiStealTex = tex
		end
		return tex
	end

	function G.ShowStealableBorder(host, w, h, cr, cg, cb)
		local tex = G.EnsureStealableBorder(host)
		w = w or 24
		h = h or w
		tex:SetSize(w * SCALE, h * SCALE)
		tex:SetDesaturated(cr ~= nil)
		tex:SetVertexColor(cr or 1, cg or 1, cb or 1)
		tex:Show()
	end

	function G.HideStealableBorder(host)
		local tex = host and host._euiStealTex
		if tex then tex:Hide() end
		local s = host and host._euiSpecSig
		if s and s.idx == G.STEALABLE_BORDER then s.idx = nil end
	end
end

-------------------------------------------------------------------------------
--  Unified glow model (retail): module views over the shared style index,
--  host capabilities, and StartSpecGlow rendering a whole glow setting.
-------------------------------------------------------------------------------
do
	local G = EllesmereUI.Glows

	local DEF_R, DEF_G, DEF_B = 1.0, 0.788, 0.137
	G.DEFAULT_COLOR = { r = DEF_R, g = DEF_G, b = DEF_B }

	function G.MakeView(order, overrides)
		local list, toShared, fromShared, ordered = {}, {}, {}, {}
		for i = 1, #order do
			local si = order[i]
			local ov = overrides and overrides[i]
			list[i] = ov and setmetatable(ov, { __index = GLOW_STYLES[si] }) or GLOW_STYLES[si]
			toShared[i] = si
			fromShared[si] = i
		end
		for si = 1, #GLOW_STYLES do
			if fromShared[si] then ordered[#ordered + 1] = fromShared[si] end
		end
		return { list = list, toShared = toShared, fromShared = fromShared, ordered = ordered }
	end

	-- Styles each host can render (retail table; Blackout stays out).
	G.HOSTS = {
		icon   = { true, true, true, true,  true, true, true },
		bar    = { true, true, true, false, true, true, true },
		engine = { true, true, false, false, true, true, true },
	}

	G.RECT_EXCLUDES = { [2] = true, [4] = true, [5] = true, [6] = true, [7] = true }

	local FALLBACK = {
		[1] = { 7, 6, 5 },
		[2] = { 7, 6, 1 },
		[3] = { 6, 5, 1 },
		[4] = { 6, 1, 7 },
		[5] = { 6, 7, 1 },
		[6] = { 5, 7, 1 },
		[7] = { 1, 6, 5 },
		[8] = { 1, 6, 7 },
	}

	function G.ResolveStyle(idx, host, excludes)
		idx = tonumber(idx) or 1
		if idx == G.STEALABLE_BORDER then return idx, false end
		if idx < 1 or idx > #GLOW_STYLES then idx = 1 end
		local caps = G.HOSTS[host or "icon"] or G.HOSTS.icon
		if caps[idx] and not (excludes and excludes[idx]) then return idx, false end
		local alts = FALLBACK[idx]
		for k = 1, #alts do
			local a = alts[k]
			if caps[a] and not (excludes and excludes[a]) then return a, true end
		end
		return 1, true
	end

	function G.ResolveColor(mode, r, g, b, defR, defG, defB)
		if mode == "default" then return nil end
		if mode == "class" then
			local c = EllesmereUI.GetClassColor and EllesmereUI.GetClassColor(EllesmereUI._playerClass)
			if c then return c.r, c.g, c.b end
			return 1, 1, 1
		end
		if r ~= nil then return r, g or 0, b or 0 end
		return defR, defG, defB
	end

	function G.DeriveColorMode(mode, classFlag)
		if mode then return mode end
		return classFlag and "class" or "custom"
	end

	function G.SpeedToUI(period)
		local v = 9 - (period or 4)
		if v < 1 then v = 1 elseif v > 8 then v = 8 end
		return v
	end
	function G.SpeedFromUI(v) return 9 - v end

	local _prefixKeys = {}
	local function PrefixKeys(p)
		local k = _prefixKeys[p]
		if not k then
			k = { type = p .. "Type", mode = p .. "ColorMode", class = p .. "ClassColor",
				  r = p .. "R", g = p .. "G", b = p .. "B", lines = p .. "Lines",
				  th = p .. "Thickness", speed = p .. "Speed", bg = p .. "Background",
				  bgR = p .. "BackgroundR", bgG = p .. "BackgroundG", bgB = p .. "BackgroundB" }
			_prefixKeys[p] = k
		end
		return k
	end
	G.PrefixKeys = PrefixKeys

	function G.SpecFromPrefix(out, t, p, defR, defG, defB)
		local k = PrefixKeys(p)
		local style = t and t[k.type] or 0
		if not style or style == 0 then return nil end
		out.style = style
		out.r, out.g, out.b = G.ResolveColor(G.DeriveColorMode(t[k.mode], t[k.class]),
			t[k.r], t[k.g], t[k.b], defR, defG, defB)
		out.lines, out.thickness, out.speed = t[k.lines], t[k.th], t[k.speed]
		if t[k.bg] then
			out.bg, out.bgR, out.bgG, out.bgB = true, t[k.bgR] or 0, t[k.bgG] or 0, t[k.bgB] or 0
		else
			out.bg, out.bgR, out.bgG, out.bgB = nil, nil, nil, nil
		end
		return out
	end

	-- Options previews: draw the pixel count the live UIParent glow shows.
	G.PANEL_EXTRA = { panel = true }
	function G.PanelThickness(th)
		local PP, PPP = EllesmereUI.PP, EllesmereUI.PanelPP
		local px = floor(th / ((PP and PP.mult) or 1) + 0.5)
		if px < 1 then px = 1 end
		return px * ((PPP and PPP.mult) or 1)
	end

	local _opts, _bg = {}, {}

	-- spec = { style, r, g, b (resolved; nil = default look), lines,
	--          thickness, speed, bg, bgR, bgG, bgB, excludes }
	-- host = "icon" | "bar" | "engine"; extra = { maskWith, maskPath,
	--          borderPath, shapeMask, anchorFrame, panel }
	function G.StartSpecGlow(wrapper, spec, w, h, host, extra)
		if not (wrapper and spec) then return end
		local idx, converted = G.ResolveStyle(spec.style, host, spec.excludes)
		w = w or 36; h = h or w
		local s = wrapper._euiSpecSig
		if idx == G.STEALABLE_BORDER then
			local r, g, b = spec.r, spec.g, spec.b
			wrapper:SetAlpha(1)
			if s and s.idx == idx and s.w == w and s.h == h
			   and s.r == r and s.g == g and s.b == b then
				return idx, false
			end
			if wrapper._euiGlowActive then StopAllGlows(wrapper); wrapper._euiGlowActive = false end
			G.ShowStealableBorder(wrapper, w, h, r, g, b)
			if not s then s = {}; wrapper._euiSpecSig = s end
			s.idx, s.host, s.w, s.h, s.r, s.g, s.b = idx, host, w, h, r, g, b
			return idx, false
		end
		local entry = GLOW_STYLES[idx]
		local r, g, b = spec.r, spec.g, spec.b
		local isFlip = not (entry.procedural or entry.buttonGlow or entry.autocast or entry.shapeGlow or entry.solidFill)
		if r == nil and not isFlip
		   and not (host == "engine" and entry.buttonGlow) then
			r, g, b = DEF_R, DEF_G, DEF_B
		end
		local N, th, period = spec.lines or 8, spec.thickness or 2, spec.speed or 4
		if extra and extra.panel then th = G.PanelThickness(th) end
		local bgOn = spec.bg and true or false
		local bgR, bgG, bgB = 0, 0, 0
		if bgOn then bgR, bgG, bgB = spec.bgR or 0, spec.bgG or 0, spec.bgB or 0 end
		local mask = extra and extra.maskWith or nil
		local maskPath = extra and extra.maskPath or nil
		local shapeMask = extra and extra.shapeMask or nil

		if s and wrapper._euiGlowActive and s.idx == idx and s.host == host
		   and s.w == w and s.h == h and s.r == r and s.g == g and s.b == b
		   and s.N == N and s.th == th and s.period == period
		   and s.bg == bgOn and s.bgR == bgR and s.bgG == bgG and s.bgB == bgB
		   and s.mask == mask and s.maskPath == maskPath and s.shapeMask == shapeMask then
			return idx, converted
		end

		local o = _opts
		o.N, o.th, o.period = N, th, period
		if bgOn then
			_bg.r, _bg.g, _bg.b, _bg.a = bgR, bgG, bgB, 1
			o.bg = _bg
		else
			o.bg = nil
		end
		o.untinted = (r == nil) or nil
		o.abgHalo, o.haloR, o.haloG, o.haloB = nil, nil, nil, nil
		o.maskWith = mask
		o.maskPath    = maskPath
		o.borderPath  = extra and extra.borderPath or nil
		o.shapeMask   = shapeMask
		o.anchorFrame = extra and extra.anchorFrame or nil
		if host == "engine" then
			StartEngineGlow(wrapper, idx, w, r, g, b, o, h)
		else
			StartGlow(wrapper, idx, w, r, g, b, o, h)
		end

		s = wrapper._euiSpecSig
		if not s then s = {}; wrapper._euiSpecSig = s end
		s.idx, s.host, s.w, s.h, s.r, s.g, s.b = idx, host, w, h, r, g, b
		s.N, s.th, s.period = N, th, period
		s.bg, s.bgR, s.bgG, s.bgB, s.mask = bgOn, bgR, bgG, bgB, mask
		s.maskPath, s.shapeMask = maskPath, shapeMask
		return idx, converted
	end

	-- Retail creates engine-host regions inside a creation window. 5.4.8 has
	-- no such window; this only pre-creates the sheet and border regions.
	function G.PrewarmEngineHost(wrapper, w, h, need)
		if not wrapper then return end
		if not need or need.flip then _EnsureFlip(wrapper, true, true) end
		if not need or need.stealable then G.EnsureStealableBorder(wrapper) end
	end
end
