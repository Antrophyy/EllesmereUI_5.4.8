-------------------------------------------------------------------------------
--  EUI_UnlockMode_Compat.lua (5.4.8 port)
--  The retail EllesmereUI Unlock Mode files (EUI_UnlockMode*.lua, 9.3.8) run on
--  Mists of Pandaria through this file, the same way as the Bags and Data Bars
--  ports. It adds the retail framework pieces those files call to the core
--  table (EllesmereUI.PP pixel math, MakeBorder, styled buttons, the widget
--  tooltip, the combat queue, MakeUnlockElement, ...) and builds a private
--  environment (EllesmereUI._unlockEnv) the Unlock Mode files use as their
--  global table (setfenv on line 1): it holds C_Timer and the few other retail
--  globals they need. Reads fall back to the real _G.
-------------------------------------------------------------------------------
local addonName, ns = ...

local _G = _G
local type, pairs, ipairs, select, tonumber, tostring = type, pairs, ipairs, select, tonumber, tostring
local floor, ceil, max, min, abs, sqrt = math.floor, math.ceil, math.max, math.min, math.abs, math.sqrt
local GetTime = GetTime

local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\media\\"

local env = setmetatable({}, { __index = _G })
ns._unlockEnv = env

-------------------------------------------------------------------------------
--  C_Timer (5.4.8 has none): After, NewTimer, NewTicker on one OnUpdate.
-------------------------------------------------------------------------------
local Timer = {}
do
	local queue = {}
	local driver = CreateFrame("Frame")
	driver:Hide()

	local function Add(t)
		queue[#queue + 1] = t
		driver:Show()
		return t
	end

	local function Cancel(self)
		self._cancelled = true
	end
	local function IsCancelled(self)
		return self._cancelled == true
	end

	driver:SetScript("OnUpdate", function(self)
		local now = GetTime()
		local list = queue
		queue = {}
		for i = 1, #list do
			local t = list[i]
			if not t._cancelled then
				if now >= t.at then
					local ok, err = pcall(t.fn, t)
					if not ok then
						geterrorhandler()(err)
					end
					if t.period and not t._cancelled then
						t.left = t.left and (t.left - 1) or nil
						if t.left == nil or t.left > 0 then
							t.at = now + t.period
							queue[#queue + 1] = t
						end
					end
				else
					queue[#queue + 1] = t
				end
			end
		end
		if #queue == 0 then
			self:Hide()
		end
	end)

	function Timer.After(delay, fn)
		Add({ at = GetTime() + (tonumber(delay) or 0), fn = function() fn() end })
	end

	function Timer.NewTimer(delay, fn)
		return Add({ at = GetTime() + (tonumber(delay) or 0), fn = fn, Cancel = Cancel, IsCancelled = IsCancelled })
	end

	function Timer.NewTicker(period, fn, iterations)
		period = tonumber(period) or 0
		return Add({ at = GetTime() + period, fn = fn, period = period, left = iterations,
			Cancel = Cancel, IsCancelled = IsCancelled })
	end
end
ns.C_Timer = Timer
env.C_Timer = Timer

-------------------------------------------------------------------------------
--  Small retail globals
-------------------------------------------------------------------------------
-- Screen size in physical pixels: the height from the resolution setting
-- (ns.PhysicalHeight), the width from the screen's aspect ratio.
env.GetPhysicalScreenSize = function()
	local h = ns.PhysicalHeight()
	local sw, sh = GetScreenWidth(), GetScreenHeight()
	local w = (sh and sh > 0) and floor(h * sw / sh + 0.5) or floor(h * 16 / 9 + 0.5)
	return w, h
end

-- Retail plays sound kit 201528 on unlock; 5.4.8 takes a sound name.
env.PlaySound = function(sound, channel)
	if type(sound) == "number" then
		sound = "igMainMenuOpen"
	end
	pcall(PlaySound, sound, channel)
end

if type(CopyTable) ~= "function" then
	local function Copy(t)
		local out = {}
		for k, v in pairs(t) do
			out[k] = type(v) == "table" and Copy(v) or v
		end
		return out
	end
	env.CopyTable = Copy
end

-------------------------------------------------------------------------------
--  Locale: the port is English only.
-------------------------------------------------------------------------------
ns.L = ns.L or function(s)
	return s
end
-- "%1$s"-style positional arguments.
ns.Lf = ns.Lf or function(fmt, ...)
	local args = { ... }
	fmt = tostring(ns.L(fmt) or "")
	return (fmt:gsub("%%(%d+)%$s", function(i)
		local v = args[tonumber(i)]
		return v == nil and "" or tostring(v)
	end))
end

-------------------------------------------------------------------------------
--  Accent (EllesmereUI.ELLESMERE_GREEN follows the live accent color)
-------------------------------------------------------------------------------
local GREEN = { r = 12 / 255, g = 210 / 255, b = 157 / 255 }
ns.ELLESMERE_GREEN = GREEN
ns.DEFAULT_ACCENT_R = ns.DEFAULT_ACCENT_R or GREEN.r
ns.DEFAULT_ACCENT_G = ns.DEFAULT_ACCENT_G or GREEN.g
ns.DEFAULT_ACCENT_B = ns.DEFAULT_ACCENT_B or GREEN.b
local function SyncAccent(r, g, b)
	if not r and ns.ResolveAccent then
		local ok, rr, gg, bb = pcall(ns.ResolveAccent)
		if ok then
			r, g, b = rr, gg, bb
		end
	end
	if r then
		GREEN.r, GREEN.g, GREEN.b = r, g, b
	end
end
ns.accentListeners = ns.accentListeners or {}
table.insert(ns.accentListeners, SyncAccent)
ns.GetAccentColor = function()
	return GREEN.r, GREEN.g, GREEN.b
end

ns.COGS_ICON = MEDIA .. "icons\\cogs-3"

-------------------------------------------------------------------------------
--  Pixel perfect (retail EllesmereUI_PixelPerfect.lua, the parts Unlock Mode
--  uses): perfect = 1 physical pixel in 768-based units, mult = 1 physical
--  pixel at the current UIParent scale.
-------------------------------------------------------------------------------
local PP = ns.PP or {}
ns.PP = PP

function PP.RefreshPhysical()
	local h = ns.PhysicalHeight()
	if not h or h <= 0 then
		h = PP.physicalHeight or 1080
	end
	PP.physicalHeight = h
	PP.perfect = 768 / h
end

function PP.UpdateMult()
	PP.RefreshPhysical()
	local scale = UIParent and UIParent:GetScale() or 1
	if not scale or scale <= 0 then
		scale = 1
	end
	PP.mult = PP.perfect / scale
end
PP.UpdateMult()

do
	local huge = math.huge
	function PP.IsNum(n)
		return type(n) == "number" and n == n and n ~= huge and n ~= -huge
	end
end

function PP.Scale(x)
	if x == 0 then return 0 end
	local m = PP.mult
	if m == 1 then return x end
	local pixels = x / m
	pixels = x > 0 and floor(pixels + 0.001) or ceil(pixels - 0.001)
	return pixels * m
end

function PP.Snap(x)
	if x == 0 then return 0 end
	local m = PP.mult
	local result = floor(x / m + 0.5) * m
	local rounded = floor(result + 0.5)
	if abs(result - rounded) < 0.001 then result = rounded end
	return result
end

function PP.ToPixels(coord)
	if coord == 0 then return 0 end
	return floor(coord / PP.mult + 0.5 + 0.001)
end

function PP.FromPixels(px)
	if px == 0 then return 0 end
	return px * PP.mult
end

function PP.SnapForES(x, es)
	if x == 0 or not PP.IsNum(x) then return 0 end
	if not (PP.IsNum(es) and es > 0) then es = 1 end
	local onePixel = PP.perfect / es
	local physPixels = floor(x / onePixel + 0.5 + 0.001)
	local result = physPixels * onePixel
	local rounded = floor(result + 0.5)
	if abs(result - rounded) < 0.001 then result = rounded end
	return result
end

function PP.SnapCenterForDim(value, dim, es)
	if value == nil then return value end
	if not PP.IsNum(value) then return 0 end
	es = es or (UIParent and UIParent:GetEffectiveScale() or 1)
	if not (PP.IsNum(es) and es > 0) then es = 1 end
	if dim and not PP.IsNum(dim) then dim = nil end
	local onePixel = PP.perfect / es
	local valuePx = value / onePixel
	local vClean = floor(valuePx + 0.5)
	if abs(valuePx - vClean) < 0.001 then valuePx = vClean end
	local result
	if dim and dim > 0 then
		local dimPx = floor(dim / onePixel + 0.5 + 0.001)
		if dimPx % 2 == 1 then
			result = (floor(valuePx) + 0.5) * onePixel
			local rounded = floor(result) + 0.5
			if abs(result - rounded) < 0.001 then result = rounded end
			return result
		end
	end
	result = floor(valuePx + 0.5 + 0.001) * onePixel
	local rounded = floor(result + 0.5)
	if abs(result - rounded) < 0.001 then result = rounded end
	return result
end

function PP.CenterToPixels(center, dim, es)
	if center == nil or not PP.IsNum(center) then return nil end
	local v = center / PP.mult
	if dim and PP.IsNum(dim) and dim > 0 then
		es = es or (UIParent and UIParent:GetEffectiveScale() or 1)
		if not (PP.IsNum(es) and es > 0) then es = 1 end
		local onePixel = PP.perfect / es
		local dimPx = floor(dim / onePixel + 0.5 + 0.001)
		if dimPx % 2 == 1 then v = v - 0.5 end
	end
	return floor(v + 0.5 + 0.001)
end

function PP.Point(obj, anchor, p1, p2, p3, p4)
	if not p1 then p1 = obj:GetParent() end
	if type(p1) == "number" then p1 = PP.Scale(p1) end
	if type(p2) == "number" then p2 = PP.Scale(p2) end
	if type(p3) == "number" then p3 = PP.Scale(p3) end
	if type(p4) == "number" then p4 = PP.Scale(p4) end
	obj:SetPoint(anchor, p1, p2, p3, p4)
end

function PP.DisablePixelSnap() end

-- Four 1-pixel strips around a frame (retail PP.CreateBorder), each exactly
-- borderSize physical pixels at the frame's effective scale.
local borderData = setmetatable({}, { __mode = "k" })

local function SnapBorder(container, frame, size)
	local es = frame:GetEffectiveScale()
	if not es or es <= 0 then es = 1 end
	local px = (PP.perfect / es) * (size or 1)
	local t, b, l, r = container._top, container._bottom, container._left, container._right
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
	t:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
	t:SetHeight(px)
	b:ClearAllPoints()
	b:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
	b:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
	b:SetHeight(px)
	l:ClearAllPoints()
	l:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -px)
	l:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, px)
	l:SetWidth(px)
	r:ClearAllPoints()
	r:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, -px)
	r:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, px)
	r:SetWidth(px)
end

function PP.CreateBorder(frame, r, g, b, a, borderSize, drawLayer, subLevel)
	local bd = borderData[frame]
	if bd then
		return bd.container
	end
	local container = CreateFrame("Frame", nil, frame)
	container:SetAllPoints(frame)
	container:SetFrameLevel(frame:GetFrameLevel() + 1)
	local function MakeTex()
		local tx = container:CreateTexture(nil, drawLayer or "OVERLAY", nil, subLevel or 0)
		tx:SetTexture("Interface\\Buttons\\WHITE8X8")
		tx:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
		return tx
	end
	container._top, container._bottom = MakeTex(), MakeTex()
	container._left, container._right = MakeTex(), MakeTex()
	bd = { container = container, borderSize = borderSize or 1 }
	borderData[frame] = bd
	SnapBorder(container, frame, bd.borderSize)
	-- The effective scale is only final once the frame is laid out.
	local ticks = 0
	container:SetScript("OnUpdate", function(self)
		ticks = ticks + 1
		SnapBorder(self, frame, bd.borderSize)
		if ticks >= 2 then
			self:SetScript("OnUpdate", nil)
		end
	end)
	return container
end

function PP.SetBorderSize(frame, borderSize)
	local bd = borderData[frame]
	if not bd then return end
	bd.borderSize = borderSize or 1
	SnapBorder(bd.container, frame, bd.borderSize)
end

function PP.SetBorderColor(frame, r, g, b, a)
	local bd = borderData[frame]
	if not bd then return end
	local c = bd.container
	a = a or 1
	c._top:SetVertexColor(r, g, b, a)
	c._bottom:SetVertexColor(r, g, b, a)
	c._left:SetVertexColor(r, g, b, a)
	c._right:SetVertexColor(r, g, b, a)
end

-- UI scale changes (EllesmereUI_UIScale.lua runs ns.applyHooks): new pixel size.
ns.applyHooks = ns.applyHooks or {}
table.insert(ns.applyHooks, function()
	PP.UpdateMult()
end)

-------------------------------------------------------------------------------
--  Widget helpers (retail EllesmereUI.lua / EllesmereUI_UICore.lua)
-------------------------------------------------------------------------------
local function FontPath()
	return (ns.GetFontPath and ns.GetFontPath("extras")) or (MEDIA .. "fonts\\Expressway.TTF")
end

local function MakeFont(parent, size, flags, r, g, b, a)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont(FontPath(), size, flags or "")
	if r then fs:SetTextColor(r, g, b, a or 1) end
	return fs
end
ns.MakeFont = ns.MakeFont or MakeFont

local function SolidTex(parent, layer, r, g, b, a)
	local tex = parent:CreateTexture(nil, layer or "BACKGROUND")
	tex:SetTexture(r, g, b, a or 1)
	return tex
end
ns.SolidTex = ns.SolidTex or SolidTex

function ns.MakeBorder(parent, r, g, b, a)
	r = r or 0; g = g or 0; b = b or 0
	local bf = CreateFrame("Frame", nil, parent)
	bf:SetAllPoints(parent)
	bf:SetFrameLevel(parent:GetFrameLevel() + 1)
	bf:EnableMouse(false)
	local brd = PP.CreateBorder(bf, r, g, b, a or 1, 1, "BORDER", 7)
	return {
		_frame = bf,
		edges = brd,
		SetColor = function(self, cr, cg, cb, ca)
			PP.SetBorderColor(bf, cr, cg, cb, ca or 1)
		end,
	}
end

function ns.MakeDropdownArrow(parent, xPad)
	local arrow = parent:CreateTexture(nil, "ARTWORK")
	arrow:SetTexture(MEDIA .. "icons\\eui-arrow")
	local pad = (xPad or 12) + 5
	local sz = 26
	PP.Point(arrow, "TOPRIGHT", parent, "RIGHT", -(pad - sz / 2), sz / 2)
	PP.Point(arrow, "BOTTOMLEFT", parent, "RIGHT", -(pad + sz / 2), -sz / 2)
	return arrow
end

ns.lerp = ns.lerp or function(a, b, t)
	return a + (b - a) * t
end

-- Button style (retail STYLE.BTN_*).
local BTN_BG_R, BTN_BG_G, BTN_BG_B, BTN_BG_A, BTN_BG_HA = 0.089, 0.080, 0.072, 0.6, 0.65
local BTN_BRD_A, BTN_BRD_HA, BTN_TXT_A, BTN_TXT_HA = 0.3, 0.45, 0.55, 0.70
ns.RB_COLOURS = {
	BTN_BG_R, BTN_BG_G, BTN_BG_B, BTN_BG_A, BTN_BG_R, BTN_BG_G, BTN_BG_B, BTN_BG_HA,
	1, 1, 1, BTN_BRD_A, 1, 1, 1, BTN_BRD_HA,
	1, 1, 1, BTN_TXT_A, 1, 1, 1, BTN_TXT_HA,
}
ns.WB_COLOURS = ns.RB_COLOURS

function ns.MakeStyledButton(btn, text, fontSize, colours, onClick)
	local c = colours or ns.RB_COLOURS
	local bg = SolidTex(btn, "BACKGROUND", c[1], c[2], c[3], c[4])
	bg:SetAllPoints()
	local brd = ns.MakeBorder(btn, c[9], c[10], c[11], c[12])
	local lbl = MakeFont(btn, fontSize, nil, c[17], c[18], c[19])
	lbl:SetAlpha(c[20])
	lbl:SetPoint("CENTER")
	lbl:SetText(ns.L(text))
	btn:SetScript("OnEnter", function()
		lbl:SetTextColor(c[21], c[22], c[23], c[24])
		brd:SetColor(c[13], c[14], c[15], c[16])
		bg:SetTexture(c[5], c[6], c[7], c[8])
	end)
	btn:SetScript("OnLeave", function()
		lbl:SetTextColor(c[17], c[18], c[19], c[20])
		brd:SetColor(c[9], c[10], c[11], c[12])
		bg:SetTexture(c[1], c[2], c[3], c[4])
	end)
	btn:SetScript("OnClick", function()
		if onClick then onClick() end
	end)
	return bg, brd, lbl
end

-- Runtime drop shadow (5.4.8 renders SetShadowOffset on a FontString).
function ns.PrimeFontShadow(fs, useShadow)
	if not (fs and fs.SetShadowOffset) then return end
	if useShadow then
		fs:SetShadowColor(0, 0, 0, 1)
		fs:SetShadowOffset(1, -1)
	else
		fs:SetShadowColor(0, 0, 0, 0)
		fs:SetShadowOffset(0, 0)
	end
end

function ns.ClearFramePoints(frame)
	frame:ClearAllPoints()
end

function ns.SetFramePoint(frame, point, relativeTo, relativePoint, x, y)
	frame:SetPoint(point, relativeTo, relativePoint, x, y)
end

-- Runs fn once combat ends; the same key replaces its queued function.
function ns.NewCombatQueue(frame)
	frame = frame or CreateFrame("Frame")
	local fns, index, count = {}, {}, 0
	local q = {}
	frame:SetScript("OnEvent", function(self)
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
		local runFns, n = fns, count
		fns, index, count = {}, {}, 0
		for i = 1, n do
			local ok, err = pcall(runFns[i])
			if not ok then
				geterrorhandler()(err)
			end
		end
	end)
	function q.Defer(key, fn)
		if not key or type(fn) ~= "function" then return end
		local i = index[key]
		if i then
			fns[i] = fn
			return
		end
		count = count + 1
		fns[count] = fn
		index[key] = count
		if count == 1 then
			frame:RegisterEvent("PLAYER_REGEN_ENABLED")
		end
	end
	function q.Has(key)
		return index[key] ~= nil
	end
	return q
end

-- Widget tooltip (retail ShowWidgetTooltip): small dark box with a 1px border,
-- above the widget by default, faded in.
do
	local tt
	local function Frame()
		if not tt then
			tt = CreateFrame("Frame", nil, UIParent)
			tt:SetFrameStrata("TOOLTIP")
			tt:SetFrameLevel(120) -- frame levels stop at 128 in 5.4.8
			tt:SetSize(250, 40)
			tt.bg = SolidTex(tt, "BACKGROUND", 0.067, 0.067, 0.067, 0.94)
			tt.bg:SetAllPoints()
			ns.MakeBorder(tt, 1, 1, 1, 0.15)
			tt.text = MakeFont(tt, 10, nil, 1, 1, 1, 0.80)
			tt.text:SetPoint("TOPLEFT", 8, -8)
			tt.text:SetPoint("TOPRIGHT", -8, -8)
			tt.text:SetWordWrap(true)
			tt.text:SetSpacing(3)
			tt:Hide()
		end
		return tt
	end

	local function Fade(target, dur, onDone)
		local from = tt:GetAlpha()
		local t = 0
		tt:SetScript("OnUpdate", function(self, dt)
			t = t + dt
			local p = min(1, t / dur)
			self:SetAlpha(from + (target - from) * p)
			if p >= 1 then
				self:SetScript("OnUpdate", nil)
				if onDone then onDone() end
			end
		end)
	end

	function ns.ShowWidgetTooltip(label, text, opts)
		if type(text) == "function" then text = text() end
		if not text or text == "" or not label then return end
		local f = Frame()
		local MAX_W, PAD = 250, 8
		f:SetWidth((opts and opts.width) or MAX_W)
		if opts and opts.color then
			f.text:SetTextColor(opts.color[1], opts.color[2], opts.color[3], opts.color[4] or 0.80)
		else
			f.text:SetTextColor(1, 1, 1, 0.80)
		end
		f.text:SetJustifyH((opts and opts.justify) or "CENTER")
		f.text:SetFont(FontPath(), 10, "")
		f.text:SetText(ns.L(text))
		f:SetScale((opts and opts.scale) or 1)
		f:ClearAllPoints()
		if opts and opts.anchorPoint then
			f:SetPoint(opts.anchorPoint, label, opts.anchorTo or opts.anchorPoint, opts.anchorX or 0, opts.anchorY or 0)
		elseif opts and opts.anchor == "cursor" then
			local scale = f:GetEffectiveScale()
			local cx, cy = GetCursorPosition()
			f:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", cx / scale, cy / scale + 4)
		elseif opts and opts.anchor == "below" then
			f:SetPoint("TOP", label, "BOTTOM", 0, -4)
		elseif opts and opts.anchor == "left" then
			f:SetPoint("RIGHT", label, "LEFT", -4, 0)
		elseif opts and opts.anchor == "right" then
			f:SetPoint("LEFT", label, "RIGHT", 4, 0)
		else
			f:SetPoint("BOTTOM", label, "TOP", 0, 4)
		end
		f:SetAlpha(0)
		f:Show()
		if not (opts and opts.width) then
			f:SetWidth(min((f.text:GetStringWidth() or MAX_W) + PAD * 2, MAX_W))
		end
		f:SetHeight((f.text:GetStringHeight() or 10) + 16)
		-- Keep it on the screen.
		local s = f:GetEffectiveScale()
		local uS = UIParent:GetEffectiveScale()
		local l, r = f:GetLeft(), f:GetRight()
		local screenW = UIParent:GetWidth() * uS
		if l and r then
			local pt, rel, relPt, px, py = f:GetPoint(1)
			if l * s < 0 then
				f:SetPoint(pt, rel, relPt, (px or 0) - l, py or 0)
			elseif r * s > screenW then
				f:SetPoint(pt, rel, relPt, (px or 0) - (r * s - screenW) / s, py or 0)
			end
		end
		local t, b = f:GetTop(), f:GetBottom()
		local screenH = UIParent:GetHeight() * uS
		if t and b then
			local pt, rel, relPt, px, py = f:GetPoint(1)
			if b * s < 0 then
				f:SetPoint(pt, rel, relPt, px or 0, (py or 0) - b)
			elseif t * s > screenH then
				f:SetPoint(pt, rel, relPt, px or 0, (py or 0) - (t * s - screenH) / s)
			end
		end
		Fade(1, 0.25)
	end

	function ns.HideWidgetTooltip(instant)
		if not tt or not tt:IsShown() then return end
		if instant then
			tt:SetScript("OnUpdate", nil)
			tt:SetAlpha(0)
			tt:Hide()
			return
		end
		Fade(0, 0.25, function()
			tt:Hide()
			tt:SetScale(1)
		end)
	end
end

-------------------------------------------------------------------------------
--  Line drawing (5.4.8 has no Line objects): a texture spanning the line's
--  bounding box with rotated texture coordinates (the Routes / TomTom way).
--  Retail Line API subset: SetThickness, SetTexture, SetStartPoint,
--  SetEndPoint, SetVertexColor, Show, Hide. The texture runs along the line
--  (U) with its height across the thickness (V).
-------------------------------------------------------------------------------
function ns.NewLine(parent, layer, sub)
	local tex = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
	local line = { tex = tex, w = 1 }
	local sx, sy, ex, ey, rel

	local function Draw()
		if not (sx and ex) then return end
		local w = line.w
		local dx, dy = ex - sx, ey - sy
		local cx, cy = (sx + ex) / 2, (sy + ey) / 2
		if dx < 0 then dx, dy = -dx, -dy end
		local l = sqrt(dx * dx + dy * dy)
		tex:ClearAllPoints()
		-- A line shorter than its thickness has no sane rotation: w / l blows
		-- up (a tiny l gave texcoords of ~17000 -> "TexCoord out of range").
		-- This happens when SetStartPoint redraws against last frame's end.
		if l < w then
			tex:SetTexCoord(0, 0, 0, 0, 0, 0, 0, 0)
			tex:SetPoint("BOTTOMLEFT", rel, "BOTTOMLEFT", cx, cy)
			tex:SetPoint("TOPRIGHT", rel, "BOTTOMLEFT", cx, cy)
			return
		end
		local s, c = -dy / l, dx / l
		local sc = s * c
		local Bwid, Bhgt, BLx, BLy, TLx, TLy, TRx, TRy, BRx, BRy
		if dy >= 0 then
			Bwid = ((l * c) - (w * s)) / 2
			Bhgt = ((w * c) - (l * s)) / 2
			BLx, BLy, BRy = (w / l) * sc, s * s, (l / w) * sc
			BRx, TLx, TLy, TRx = 1 - BLy, BLy, 1 - BRy, 1 - BLx
			TRy = BRx
		else
			Bwid = ((l * c) + (w * s)) / 2
			Bhgt = ((w * c) + (l * s)) / 2
			BLx, BLy, BRx = s * s, -(l / w) * sc, 1 + (w / l) * sc
			BRy, TLx, TLy, TRy = BLx, 1 - BRx, 1 - BLx, 1 - BLy
			TRx = TLy
		end
		tex:SetTexCoord(TLx, TLy, BLx, BLy, TRx, TRy, BRx, BRy)
		tex:SetPoint("BOTTOMLEFT", rel, "BOTTOMLEFT", cx - Bwid, cy - Bhgt)
		tex:SetPoint("TOPRIGHT", rel, "BOTTOMLEFT", cx + Bwid, cy + Bhgt)
	end

	function line:SetThickness(w) self.w = w or 1; Draw() end
	function line:SetTexture(path) tex:SetTexture(path) end
	function line:SetStartPoint(_, relTo, x, y) rel = relTo or UIParent; sx, sy = x, y; Draw() end
	function line:SetEndPoint(_, relTo, x, y) rel = relTo or UIParent; ex, ey = x, y; Draw() end
	function line:SetVertexColor(r, g, b, a) tex:SetVertexColor(r, g, b, a) end
	function line:Show() tex:Show() end
	function line:Hide() tex:Hide() end
	function line:IsShown() return tex:IsShown() end
	function line:SetSnapToPixelGrid() end
	function line:SetTexelSnappingBias() end
	return line
end

-------------------------------------------------------------------------------
--  Retail framework stubs: no spec overrides, profiles, gamepad or Edit Mode
--  in this port. The Unlock Mode files check for these and step aside.
-------------------------------------------------------------------------------
ns.PadInUse = function() return false end
ns.PadNative = function() return false end
ns.GetActiveProfileData = function() return nil end
ns._RefreshSpecID = function() end
-- Frame data retail keeps per frame (restoreAlpha of a faded bar).
do
	local ffd = setmetatable({}, { __mode = "k" })
	ns._GetFFD = function(f)
		local d = ffd[f]
		if not d then
			d = {}
			ffd[f] = d
		end
		return d
	end
end

-- Retail Lite addons the Unlock Mode files look up by name (action bar grow
-- direction / orientation). A module registers itself here:
-- EllesmereUI._liteAddons["EllesmereUIActionBars"] = object with .db.profile.
ns._liteAddons = ns._liteAddons or {}
ns.Lite = ns.Lite or {}
ns.Lite.GetAddon = ns.Lite.GetAddon or function(name)
	return ns._liteAddons[name]
end

-------------------------------------------------------------------------------
--  MakeUnlockElement (retail EllesmereUI.lua): shared factory for unlock
--  mode element tables. See the retail file for every field; this table is
--  a WHITELIST.
-------------------------------------------------------------------------------
function ns.MakeUnlockElement(opts)
	return {
		key           = opts.key,
		label         = opts.label,
		group         = opts.group,
		order         = opts.order,
		getFrame      = opts.getFrame,
		getSize       = opts.getSize,
		savePosition  = opts.savePos,
		loadPosition  = opts.loadPos,
		clearPosition = opts.clearPos,
		applyPosition = opts.applyPos,
		setWidth      = opts.setWidth,
		setHeight     = opts.setHeight,
		isHidden      = opts.isHidden,
		isAnchored    = opts.isAnchored,
		onLiveMove    = opts.onLiveMove,
		ownsPosition  = opts.ownsPosition,
		linkedKeys    = opts.linkedKeys,
		noResize          = opts.noResize,
		linkedDimensions  = opts.linkedDimensions,
		noInitHook        = opts.noInitHook,
		loadRawPosition   = opts.loadRawPos,
		saveRawPosition   = opts.saveRawPos,
		noAnchorTarget    = opts.noAnchorTarget,
		noAnchorTo        = opts.noAnchorTo,
		allowMatchSource  = opts.allowMatchSource,
		noSizeMatchTarget = opts.noSizeMatchTarget,
		sizeFixedByLook   = opts.sizeFixedByLook,
		getSettingSize    = opts.getSettingSize,
		matchUnavailable  = opts.matchUnavailable,
		keepMoverWhenAnchored = opts.keepMoverWhenAnchored,
		moverBg           = opts.moverBg,
		moverTooltip      = opts.moverTooltip,
		subtitle          = opts.subtitle,
		getBottomExtra    = opts.getBottomExtra,
		getInsets         = opts.getInsets,
		getMatchPad       = opts.getMatchPad,
		detachedMover     = opts.detachedMover,
	}
end

-- Deferred Unlock Mode body (EUI_UnlockMode.lua sets _unlockCoreInit): runs
-- once, at PLAYER_LOGIN or when Unlock Mode opens.
function ns:EnsureUnlockCore()
	local fn = self._unlockCoreInit
	if fn then
		self._unlockCoreInit = nil
		fn()
	end
end

-- Opens Unlock Mode from anywhere (Escape menu, minimap button, the settings
-- window): its popups live in the load-on-demand settings addon.
function ns.EnterUnlockMode()
	if InCombatLockdown() then
		ns.Print("Cannot enter Unlock Mode during combat.")
		return
	end
	if ns.LoadOptions and not ns.LoadOptions() then
		return
	end
	ns:EnsureUnlockCore()
	SyncAccent()
	PP.UpdateMult()
	if ns.OpenUnlockMode then
		ns.OpenUnlockMode()
	end
end

-- The accent and pixel size are final once the saved settings are in.
do
	local f = CreateFrame("Frame")
	f:RegisterEvent("PLAYER_LOGIN")
	f:RegisterEvent("UI_SCALE_CHANGED")
	f:SetScript("OnEvent", function()
		SyncAccent()
		PP.UpdateMult()
	end)
end
