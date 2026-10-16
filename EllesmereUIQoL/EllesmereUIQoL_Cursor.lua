-------------------------------------------------------------------------------
--  EllesmereUIQoL_Cursor.lua (5.4.8 port of the retail Cursor tab)
--
--  A ring (or the Ellesmere logo) that follows the mouse, an optional dot
--  trail and center reticle, a GCD ring and a cast bar ring with a spark.
--  Settings: EllesmereUIQoLDB.cursor (retail: EllesmereUIQoLDB profile.cursor),
--  same keys and defaults as retail.
--
--  5.4.8 differences:
--    * Retail draws the GCD / cast progress with a Cooldown swipe using the
--      ring texture (SetSwipeTexture is not in 5.4.8). Here the ring is two
--      half-ring textures (Media\ring_<k>_half) turned with an 8-value
--      SetTexCoord: same look, the ring fills clockwise from 12 o'clock.
--    * The center reticle uses a round texture (no mask textures in 5.4.8).
--    * The "Hide in Housing" visibility key has nothing to match in Mists.
-------------------------------------------------------------------------------
local addonName = ...
local ns = EllesmereUI

local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local sin, cos, rad = math.sin, math.cos, math.rad
local strupper, strsub, strgsub, strmatch = string.upper, string.sub, string.gsub, string.match
local GetTime, GetCursorPosition = GetTime, GetCursorPosition

local MEDIA = "Interface\\AddOns\\EllesmereUIQoL\\Media\\"
local TEX_CUSTOM = MEDIA .. "logo-full-thin-2"
local RING_KEYS = { thin = true, light = true, normal = true, heavy = true, thick = true }
local function RingPath(key) return MEDIA .. "ring_" .. (RING_KEYS[key] and key or "normal") end
local function HalfPath(key) return MEDIA .. "ring_" .. (RING_KEYS[key] and key or "normal") .. "_half" end

local GCD_SPELL = 61304  -- the global cooldown spell
local DEF_BASESIZE = 28
local DEF_HEX = "0CD29D"

local C = {}  -- module table (keeps the local count low)

-------------------------------------------------------------------------------
--  Settings
-------------------------------------------------------------------------------
local function Defaults()
	return {
		enabled = true,
		instanceOnly = false,
		onlyWhenHidden = false,
		combatOnly = false,
		useClassColor = true,
		hex = "0CD29D",
		texture = "ring_normal",
		scale = 1,
		alpha = 100,
		gcd = {
			enabled = false, attached = true, radius = 21, ringTex = "light", scale = 100,
			hex = "FFFFFF", alpha = 80, useClassColor = false, instanceOnly = false, combatOnly = false,
		},
		castCircle = {
			enabled = false, attached = true, radius = 30, ringTex = "normal", scale = 100,
			hex = "3FA7FF", alpha = 80, sparkEnabled = true, useClassColor = true,
			instanceOnly = false, combatOnly = false,
		},
		trail = false,
		reticle = false,
		visibility = "always",
		visOnlyInstances = false,
		visHideHousing = false,
		visHideMounted = false,
		visHideNoTarget = false,
		visHideNoEnemy = false,
	}
end
ns.CursorDefaults = Defaults

-- First login: the user's retail values (profile "Naowh").
local function SeedRetail(t)
	t.enabled = false
	t.useAccentColor = true
	t.useClassColor = false
	t.texture = "ring_light"
	t.scale = 0.5
	t.trail = true
	t.gcd.useClassColor = false
	t.castCircle.useClassColor = true
end

-- Only a cursor table missing at the first look this session gets the
-- retail values (a later reset gives the plain defaults).
local firstLook = true

local function P()
	local q = ns.GetQoLDB and ns.GetQoLDB()
	if type(q) ~= "table" then return nil end
	local t = q.cursor
	if type(t) ~= "table" then
		t = {}
		q.cursor = t
	end
	if t._seeded ~= 1 then
		-- (crosshair* keys of the same table belong to EllesmereUIQoL_Extras.lua)
		local fresh = firstLook and t.enabled == nil and t.texture == nil and t.gcd == nil
		ns.CopyDefaults(Defaults(), t)
		if fresh then SeedRetail(t) end
		t._seeded = 1
	end
	firstLook = false
	if type(t.gcd) ~= "table" then t.gcd = Defaults().gcd end
	if type(t.castCircle) ~= "table" then t.castCircle = Defaults().castCircle end
	return t
end
ns.GetCursorDB = P

local function GCD_DB() local p = P(); return p and p.gcd or {} end
local function Cast_DB() local p = P(); return p and p.castCircle or {} end

-------------------------------------------------------------------------------
--  Colors: accent > class > custom hex (retail ResolveColor)
-------------------------------------------------------------------------------
local function ParseHex(raw)
	if not raw then return 12 / 255, 210 / 255, 157 / 255 end
	raw = strupper(strgsub(raw, "#", ""))
	if not strmatch(raw, "^[0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F]$") then
		return 1, 1, 1
	end
	return tonumber(strsub(raw, 1, 2), 16) / 255, tonumber(strsub(raw, 3, 4), 16) / 255, tonumber(strsub(raw, 5, 6), 16) / 255
end
C.ParseHex = ParseHex

local function ResolveColor(cfg)
	if not cfg then return 1, 1, 1 end
	if cfg.useAccentColor and ns.ResolveAccent then
		return ns.ResolveAccent()
	end
	if cfg.useClassColor then
		local _, engClass = UnitClass("player")
		local cc = engClass and RAID_CLASS_COLORS and RAID_CLASS_COLORS[engClass]
		if cc then return cc.r, cc.g, cc.b end
	end
	return ParseHex(cfg.hex or DEF_HEX)
end

local function InRealInstancedContent()
	local _, instanceType, difficultyID = GetInstanceInfo()
	if (tonumber(difficultyID) or 0) == 0 then return false end
	return instanceType == "party" or instanceType == "raid"
end

local function InCombat()
	return (InCombatLockdown() or UnitAffectingCombat("player")) and true or false
end

-------------------------------------------------------------------------------
--  Timers (no C_Timer in 5.4.8)
-------------------------------------------------------------------------------
local timerFrame = CreateFrame("Frame")
local timers = {}
timerFrame:Hide()
timerFrame:SetScript("OnUpdate", function(self)
	local now = GetTime()
	for key, t in pairs(timers) do
		if now >= t.at then
			timers[key] = nil
			t.fn()
		end
	end
	if not next(timers) then self:Hide() end
end)
local function After(key, delay, fn)
	timers[key] = { at = GetTime() + delay, fn = fn }
	timerFrame:Show()
end

-------------------------------------------------------------------------------
--  Progress ring: two half-ring textures, each clipped to its half of the
--  box by its own region and turned with an 8-value SetTexCoord.
-------------------------------------------------------------------------------
-- Texture coords that show the image turned counter-clockwise by deg,
-- for a region covering x in [x0, x1] (box units, center = 0, -0.5..0.5).
local function RotatedCoords(tex, deg, x0, x1)
	local a = rad(deg)
	local ca, sa = cos(a), sin(a)
	local function TC(x, y)
		local ix = x * ca + y * sa
		local iy = -x * sa + y * ca
		return 0.5 + ix, 0.5 - iy
	end
	local ulx, uly = TC(x0, 0.5)
	local llx, lly = TC(x0, -0.5)
	local urx, ury = TC(x1, 0.5)
	local lrx, lry = TC(x1, -0.5)
	tex:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
end

local RingMethods = {}

RingMethods.SetRingColor = function(self, r, g, b, a)
	self._r, self._g, self._b, self._a = r, g, b, a
	self._right:SetVertexColor(r, g, b, a)
	self._left:SetVertexColor(r, g, b, a)
end

RingMethods.SetRingRadius = function(self, radius)
	self.radius = radius
	self:SetSize(radius * 2, radius * 2)
end

RingMethods.SetRingTexture = function(self, key)
	local path = HalfPath(key)
	self._right:SetTexture(path)
	self._left:SetTexture(path)
	self:SetProgress(self._pct or 0)
end

-- pct 0..1: the ring is drawn from 12 o'clock clockwise to pct.
RingMethods.SetProgress = function(self, pct)
	if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
	self._pct = pct
	local theta = pct * 360
	if theta <= 0 then
		self._right:Hide()
		self._left:Hide()
		return
	end
	RotatedCoords(self._right, 180 - min(theta, 180), 0, 0.5)
	self._right:Show()
	if theta > 180 then
		RotatedCoords(self._left, 180 - theta, -0.5, 0)
		self._left:Show()
	else
		self._left:Hide()
	end
end

RingMethods.StartRing = function(self, elapsed, maxDur)
	self.dur = max(elapsed, 0)
	self.maxDur = maxDur
	self:SetProgress(maxDur > 0 and self.dur / maxDur or 0)
	self:Show()
end

RingMethods.StopRing = function(self)
	self.dur = 0
	self.maxDur = 0
	self:SetProgress(0)
	self:Hide()
end

local function CreateRing(parent, radius, ringTex, r, g, b, a)
	local ring = CreateFrame("Frame", nil, parent)
	ring:SetSize(radius * 2, radius * 2)
	ring:SetPoint("CENTER", parent, "CENTER", 0, 0)
	ring:SetFrameLevel(parent:GetFrameLevel() + 1)
	ring.radius = radius
	ring.dur, ring.maxDur = 0, 0

	ring._right = ring:CreateTexture(nil, "ARTWORK")
	ring._right:SetPoint("TOPLEFT", ring, "TOP")
	ring._right:SetPoint("BOTTOMRIGHT", ring, "BOTTOMRIGHT")
	ring._left = ring:CreateTexture(nil, "ARTWORK")
	ring._left:SetPoint("TOPLEFT", ring, "TOPLEFT")
	ring._left:SetPoint("BOTTOMRIGHT", ring, "BOTTOM")

	for k, fn in pairs(RingMethods) do ring[k] = fn end
	ring:SetRingTexture(ringTex)
	ring:SetRingColor(r, g, b, a)

	ring:SetScript("OnUpdate", function(self, dt)
		if self.maxDur <= 0 then return end
		self.dur = self.dur + dt
		if self.dur >= self.maxDur then
			self:StopRing()
			return
		end
		self:SetProgress(self.dur / self.maxDur)
	end)
	ring:Hide()
	return ring
end

-------------------------------------------------------------------------------
--  Cursor circle
-------------------------------------------------------------------------------
local f, t, reticle
local lastX, lastY
local isVisible = true
local mouselookActive = false

local function CursorSize(p)
	local size = floor(DEF_BASESIZE * (p.scale or 1) + 0.5)
	if size < 8 then return 8 end
	if size > 512 then return 512 end
	return size
end

local function GlueToCursor(frame)
	local s = UIParent:GetEffectiveScale()
	local cx, cy = GetCursorPosition()
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", floor(cx / s + 0.5), floor(cy / s + 0.5))
end

local function CursorOnUpdate(self)
	local s = UIParent:GetEffectiveScale()
	local cx, cy = GetCursorPosition()
	local x, y = floor(cx / s + 0.5), floor(cy / s + 0.5)
	if x ~= lastX or y ~= lastY then
		lastX, lastY = x, y
		self:ClearAllPoints()
		self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
	end
end

local function CreateCursorFrame()
	if f then return end
	f = CreateFrame("Frame", "EllesmereUICursorFrame", UIParent)
	f:SetFrameStrata("TOOLTIP")
	f:SetFrameLevel(100)
	f:EnableMouse(false)
	f:SetPoint("CENTER")
	t = f:CreateTexture(nil, "OVERLAY")
	t:SetAllPoints(f)
	reticle = f:CreateTexture(nil, "OVERLAY", nil, 1)
	reticle:SetPoint("CENTER")
	reticle:SetTexture(MEDIA .. "circle_fill")
	reticle:Hide()
	f:SetScript("OnUpdate", CursorOnUpdate)
end

C.Apply = function()
	local p = P()
	if not p then return end
	CreateCursorFrame()
	local size = CursorSize(p)
	f:SetSize(size, size)
	local a = (p.alpha or 100) / 100
	local r, g, b = ResolveColor(p)
	local tex = p.texture or "ring_normal"
	local ringKey = tex:match("^ring_(.+)$")
	t:SetTexture(ringKey and RingPath(ringKey) or TEX_CUSTOM)
	t:SetVertexColor(r, g, b, a)
	if p.reticle then
		local dot = max(4, floor(size * 0.2 + 0.5))
		reticle:SetSize(dot, dot)
		reticle:SetVertexColor(r, g, b, a)
		reticle:Show()
	else
		reticle:Hide()
	end
	C.UpdateVisibility()
end

-------------------------------------------------------------------------------
--  Trail (simple fading dots)
-------------------------------------------------------------------------------
local trailDots, trailActive, trailEntryPool = {}, {}, {}
local trailTimer, trailLastCX, trailLastCY = 0, 0, 0
local trailEnabled = false
local trailContainer
local TRAIL_POOL_SIZE, TRAIL_DOT_DURATION, TRAIL_DOT_DENSITY, TRAIL_DOT_BASE_SIZE = 150, 0.5, 0.004, 40

local function InitTrailDotPool()
	if not trailContainer then
		trailContainer = CreateFrame("Frame", nil, UIParent)
		trailContainer:SetAllPoints(UIParent)
		trailContainer:SetFrameStrata("TOOLTIP")
		trailContainer:SetFrameLevel(98)
		trailContainer:EnableMouse(false)
	end
	for i = 1, TRAIL_POOL_SIZE do
		local dot = trailContainer:CreateTexture(nil, "ARTWORK")
		dot:SetTexture(RingPath("normal"))
		dot:SetBlendMode("ADD")
		dot:Hide()
		trailDots[i] = dot
	end
end

local function SpawnTrailDot(cx, cy)
	if #trailDots == 0 then return end
	local dot = trailDots[#trailDots]
	trailDots[#trailDots] = nil
	local s = UIParent:GetEffectiveScale()
	local r, g, b = ResolveColor(P())
	local size = TRAIL_DOT_BASE_SIZE * 0.8
	dot:SetVertexColor(r, g, b, 1)
	dot:SetSize(size, size)
	dot:ClearAllPoints()
	dot:SetPoint("CENTER", trailContainer, "BOTTOMLEFT", cx / s, cy / s)
	dot:SetAlpha(1)
	dot:Show()
	local entry = tremove(trailEntryPool) or {}
	entry.tex, entry.life, entry.maxLife = dot, TRAIL_DOT_DURATION, TRAIL_DOT_DURATION
	trailActive[#trailActive + 1] = entry
end

local function UpdateTrailDots(elapsed)
	for i = #trailActive, 1, -1 do
		local e = trailActive[i]
		e.life = e.life - elapsed
		if e.life <= 0 then
			e.tex:Hide()
			trailDots[#trailDots + 1] = e.tex
			e.tex = nil
			trailEntryPool[#trailEntryPool + 1] = e
			trailActive[i] = trailActive[#trailActive]
			trailActive[#trailActive] = nil
		else
			local pct = e.life / e.maxLife
			local sz = max(2, TRAIL_DOT_BASE_SIZE * 0.8 * pct)
			e.tex:SetSize(sz, sz)
			e.tex:SetAlpha(pct)
		end
	end
end

local function HideTrailDots()
	for i = #trailActive, 1, -1 do
		local e = trailActive[i]
		e.tex:Hide()
		trailDots[#trailDots + 1] = e.tex
		e.tex = nil
		trailEntryPool[#trailEntryPool + 1] = e
		trailActive[i] = nil
	end
end

C.ApplyTrail = function()
	local p = P()
	trailEnabled = p and p.trail or false
	if not trailEnabled then
		HideTrailDots()
		if trailContainer then trailContainer:SetScript("OnUpdate", nil) end
		return
	end
	if #trailDots == 0 and #trailActive == 0 then InitTrailDotPool() end
	if not trailContainer:GetScript("OnUpdate") then
		trailContainer:SetScript("OnUpdate", function(_, elapsed)
			if not trailEnabled then return end
			-- Dots only while the cursor circle itself is shown (all its gates apply).
			if isVisible then
				local cx, cy = GetCursorPosition()
				trailTimer = trailTimer + elapsed
				local dx, dy = cx - trailLastCX, cy - trailLastCY
				if trailTimer >= TRAIL_DOT_DENSITY and (dx * dx + dy * dy) >= 0.25 then
					trailTimer = 0
					SpawnTrailDot(cx, cy)
					trailLastCX, trailLastCY = cx, cy
				end
			end
			UpdateTrailDots(elapsed)
		end)
	end
end

-------------------------------------------------------------------------------
--  GCD and cast rings
-------------------------------------------------------------------------------
local gcdRoot, gcdRing, castRoot, castRing

-- Attached rings follow the cursor frame, or the mouse itself while the
-- cursor circle is hidden. During Unlock Mode the mover owns detached rings.
local function TrackCursor(root, attached)
	if not root then return end
	if attached and not ns._unlockActive then
		if f and f:IsShown() then
			root:SetScript("OnUpdate", nil)
			root:ClearAllPoints()
			root:SetPoint("CENTER", f, "CENTER", 0, 0)
		else
			GlueToCursor(root)
			root:SetScript("OnUpdate", GlueToCursor)
		end
	else
		root:SetScript("OnUpdate", nil)
	end
end

local function ApplySavedPos(root, cfg)
	if not root then return end
	if ns.IsUnlockAnchored and root == gcdRoot and ns.IsUnlockAnchored("ECL_GCD") and root:GetLeft() then return end
	if ns.IsUnlockAnchored and root == castRoot and ns.IsUnlockAnchored("ECL_Cast") and root:GetLeft() then return end
	local pos = cfg.pos
	root:ClearAllPoints()
	if pos and pos.point then
		root:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
	else
		root:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
end
C.ApplyGCDPosition = function() ApplySavedPos(gcdRoot, GCD_DB()) end
C.ApplyCastPosition = function() ApplySavedPos(castRoot, Cast_DB()) end

local function RingGated(cfg)
	return (cfg.instanceOnly and not InRealInstancedContent()) or (cfg.combatOnly and not InCombat())
end

local function ArmGCDRing()
	if not gcdRing then return end
	local start, duration = GetSpellCooldown(GCD_SPELL)
	if start and duration and duration > 0 and duration <= 1.6 and start > 0 then
		gcdRing:StartRing(GetTime() - start, duration)
	end
end

local GCD_EVENTS = { "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_STOP" }
local CAST_EVENTS = {
	"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
	"UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP",
}
local function RegisterPlayerEvents(frame, list)
	for i = 1, #list do frame:RegisterUnitEvent(list[i], "player") end
end

local function CreateGCDCircle()
	if gcdRoot then return end
	local g = GCD_DB()
	local radius = g.radius or 21
	local r, gg, b = ParseHex(g.hex)
	gcdRoot = CreateFrame("Frame", "ECL_GCDRoot", UIParent)
	gcdRoot:SetSize(radius * 2, radius * 2)
	gcdRoot:SetFrameStrata("TOOLTIP")
	gcdRoot:SetFrameLevel(90)
	gcdRoot:EnableMouse(false)
	gcdRoot:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	gcdRing = CreateRing(gcdRoot, radius, g.ringTex or "light", r, gg, b, (g.alpha or 80) / 100)
	gcdRoot:SetScript("OnEvent", function(_, event, unit)
		if unit ~= "player" then return end
		local g2 = GCD_DB()
		if not g2.enabled or RingGated(g2) then return end
		if event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_STOP" then
			local start, duration = GetSpellCooldown(GCD_SPELL)
			if not (start and start > 0 and duration and duration > 0) then
				gcdRing:StopRing()
			end
			return
		end
		ArmGCDRing()
	end)
	gcdRoot:Hide()
end

C.ApplyGCDCircle = function()
	local g = GCD_DB()
	if not g.enabled then
		if gcdRoot then
			gcdRoot:Hide()
			gcdRoot:SetScript("OnUpdate", nil)
			gcdRoot:UnregisterAllEvents()
		end
		return
	end
	CreateGCDCircle()
	RegisterPlayerEvents(gcdRoot, GCD_EVENTS)
	local radius = g.radius or 21
	local r, gg, b = ResolveColor(g)
	gcdRoot:SetScale(max(0.1, (g.scale or 100) / 100))
	gcdRing:SetRingColor(r, gg, b, (g.alpha or 80) / 100)
	gcdRing:SetRingRadius(radius)
	gcdRing:SetRingTexture(g.ringTex or "light")
	gcdRoot:SetSize(radius * 2, radius * 2)
	gcdRoot:SetShown(not RingGated(g))
	local attached = g.attached ~= false
	if attached then
		TrackCursor(gcdRoot, true)
	else
		gcdRoot:SetScript("OnUpdate", nil)
		if not ns._unlockActive then C.ApplyGCDPosition() end
	end
end

local function CreateCastCircle()
	if castRoot then return end
	local c = Cast_DB()
	local radius = c.radius or 30
	local r, g, b = ParseHex(c.hex)
	castRoot = CreateFrame("Frame", "ECL_CastRoot", UIParent)
	castRoot:SetSize(radius * 2, radius * 2)
	castRoot:SetFrameStrata("TOOLTIP")
	castRoot:SetFrameLevel(88)
	castRoot:EnableMouse(false)
	castRoot:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	castRing = CreateRing(castRoot, radius, c.ringTex or "normal", r, g, b, (c.alpha or 80) / 100)

	-- Spark + glow at the leading edge of the ring.
	local sparkOverlay = CreateFrame("Frame", nil, castRoot)
	sparkOverlay:SetAllPoints(castRoot)
	sparkOverlay:SetFrameLevel(castRoot:GetFrameLevel() + 3)
	castRoot._spark = sparkOverlay:CreateTexture(nil, "OVERLAY")
	castRoot._spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
	castRoot._spark:SetBlendMode("ADD")
	castRoot._spark:SetSize(radius * 0.6, radius * 0.6)
	castRoot._spark:Hide()
	castRoot._sparkGlow = sparkOverlay:CreateTexture(nil, "OVERLAY", nil, -1)
	castRoot._sparkGlow:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
	castRoot._sparkGlow:SetBlendMode("ADD")
	castRoot._sparkGlow:SetSize(radius * 0.9, radius * 0.9)
	castRoot._sparkGlow:SetAlpha(0.5)
	castRoot._sparkGlow:Hide()

	local RING_INNER = { thin = 0.92, light = 0.85, normal = 0.78, heavy = 0.68, thick = 0.58 }
	sparkOverlay:SetScript("OnUpdate", function()
		local spark, glow = castRoot._spark, castRoot._sparkGlow
		if not spark:IsShown() then return end
		local dur, maxDur = castRing.dur, castRing.maxDur
		local pct = (maxDur and maxDur > 0) and dur / maxDur or 0
		if pct <= 0 or pct >= 1 then spark:Hide(); glow:Hide(); return end
		local c2 = Cast_DB()
		local orbit = (c2.radius or 30) * (1 + (RING_INNER[c2.ringTex or "normal"] or 0.78)) * 0.5
		local angle = 90 - pct * 360
		local sx, sy = cos(rad(angle)) * orbit, sin(rad(angle)) * orbit
		spark:ClearAllPoints()
		spark:SetPoint("CENTER", castRoot, "CENTER", sx, sy)
		spark:SetRotation(rad(angle - 90))
		glow:ClearAllPoints()
		glow:SetPoint("CENTER", castRoot, "CENTER", sx, sy)
		glow:SetRotation(rad(angle - 90))
	end)

	local function ShowSpark(c2)
		if c2.sparkEnabled then
			castRoot._spark:Show()
			castRoot._sparkGlow:Show()
		end
	end
	local function StopCast()
		castRoot._castID = nil
		castRing:StopRing()
		castRoot._spark:Hide()
		castRoot._sparkGlow:Hide()
	end

	-- 5.4.8 event args: unit, spellName, rank, lineID, spellID.
	castRoot:SetScript("OnEvent", function(self, event, unit, _, _, lineID)
		if unit ~= "player" then return end
		local c2 = Cast_DB()
		if not c2.enabled or RingGated(c2) then return end
		if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_DELAYED" then
			local name, _, _, _, startMS, endMS, _, castID = UnitCastingInfo("player")
			if name then
				self._castID = castID
				castRing:StartRing(GetTime() - startMS * 0.001, (endMS - startMS) * 0.001)
				ShowSpark(c2)
			end
		elseif event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
			local name, _, _, _, startMS, endMS = UnitChannelInfo("player")
			if name then
				self._castID = nil
				castRing:StartRing(GetTime() - startMS * 0.001, (endMS - startMS) * 0.001)
				ShowSpark(c2)
			end
		elseif event == "UNIT_SPELLCAST_STOP" then
			if lineID == self._castID then StopCast() end
		else  -- FAILED, INTERRUPTED, CHANNEL_STOP
			if event == "UNIT_SPELLCAST_CHANNEL_STOP" or not lineID or lineID == self._castID then StopCast() end
		end
	end)
	castRoot:Hide()
end

C.ApplyCastCircle = function()
	local c = Cast_DB()
	if not c.enabled then
		if castRoot then
			castRoot:Hide()
			castRoot:SetScript("OnUpdate", nil)
			castRoot:UnregisterAllEvents()
		end
		return
	end
	CreateCastCircle()
	RegisterPlayerEvents(castRoot, CAST_EVENTS)
	local radius = c.radius or 30
	local r, g, b = ResolveColor(c)
	castRoot:SetScale(max(0.1, (c.scale or 100) / 100))
	castRing:SetRingColor(r, g, b, (c.alpha or 80) / 100)
	castRing:SetRingRadius(radius)
	castRing:SetRingTexture(c.ringTex or "normal")
	castRoot:SetSize(radius * 2, radius * 2)
	castRoot._spark:SetSize(radius * 0.6, radius * 0.6)
	castRoot._sparkGlow:SetSize(radius * 0.9, radius * 0.9)
	if c.sparkEnabled then
		-- Accent / class mode: the spark takes the ring color; custom: sparkHex or the ring hex.
		local sr, sg, sb = r, g, b
		if not (c.useAccentColor or c.useClassColor) then sr, sg, sb = ParseHex(c.sparkHex or c.hex) end
		castRoot._spark:SetVertexColor(sr, sg, sb, 1)
		castRoot._sparkGlow:SetVertexColor(sr, sg, sb, 1)
	else
		castRoot._spark:Hide()
		castRoot._sparkGlow:Hide()
	end
	castRoot:SetShown(not RingGated(c))
	if c.attached ~= false then
		TrackCursor(castRoot, true)
	else
		castRoot:SetScript("OnUpdate", nil)
		if not ns._unlockActive then C.ApplyCastPosition() end
	end
end

-------------------------------------------------------------------------------
--  Visibility
-------------------------------------------------------------------------------
-- Retail CheckVisibilityOptions (true = hide). Housing has no Mists match.
local function VisibilityHides(p)
	if p.visOnlyInstances and not IsInInstance() then return true end
	if p.visHideMounted and IsMounted() then return true end
	if p.visHideNoTarget and not UnitExists("target") then return true end
	if p.visHideNoEnemy and not (UnitExists("target") and UnitCanAttack("player", "target")) then return true end
	return false
end

C.UpdateVisibility = function()
	if not f then return end
	local p = P()
	if not p then return end
	local show = p.enabled ~= false
	if show and p.instanceOnly then show = InRealInstancedContent() end
	if show and p.combatOnly then show = InCombat() end
	if show and VisibilityHides(p) then show = false end
	if show then
		local mode = p.visibility or "always"
		if mode == "never" then
			show = false
		elseif mode == "in_combat" then
			show = InCombat()
		elseif mode == "out_of_combat" then
			show = not InCombat()
		elseif mode == "in_raid" then
			show = IsInRaid()
		elseif mode == "in_party" then
			show = IsInGroup() and not IsInRaid()
		elseif mode == "solo" then
			show = not IsInGroup()
		end
	end
	if show and p.onlyWhenHidden and not mouselookActive then show = false end

	if show and not isVisible then
		isVisible = true
		lastX, lastY = nil, nil
		CursorOnUpdate(f)
		f:Show()
	elseif not show and isVisible then
		isVisible = false
		f:Hide()
	end
	if not show and trailEnabled then HideTrailDots() end

	-- Rings: their own instance / combat gates, then cursor tracking again
	-- (the cursor frame may have been shown or hidden).
	local g = GCD_DB()
	if gcdRoot and g.enabled then
		if RingGated(g) then
			gcdRoot:Hide()
			gcdRoot:SetScript("OnUpdate", nil)
		else
			gcdRoot:Show()
			if g.combatOnly and gcdRing.maxDur <= 0 then ArmGCDRing() end
			if g.attached ~= false then TrackCursor(gcdRoot, true) end
		end
	end
	local c = Cast_DB()
	if castRoot and c.enabled then
		if RingGated(c) then
			castRoot:Hide()
			castRoot:SetScript("OnUpdate", nil)
		else
			castRoot:Show()
			if c.attached ~= false then TrackCursor(castRoot, true) end
		end
	end
end

-------------------------------------------------------------------------------
--  Only Show When Hidden: shown while a world mouse button is held to turn
--  the camera / character (post-hooks on the world mouse handlers).
-------------------------------------------------------------------------------
local mlFeatureOn, mlLeftWorld, mlRight, mlPending = false, false, false, false
local MS_HOLD_DELAY = 0.15

local function ML_Show()
	mlPending = false
	if mlFeatureOn and (mlLeftWorld or mlRight) and not mouselookActive then
		mouselookActive = true
		C.UpdateVisibility()
	end
end
local function ML_ControlStart()
	if not mlFeatureOn or mouselookActive or mlPending then return end
	mlPending = true
	After("mouselook", MS_HOLD_DELAY, ML_Show)
end
local function ML_ControlStop()
	if mlFeatureOn and not (mlLeftWorld or mlRight) and mouselookActive then
		mouselookActive = false
		C.UpdateVisibility()
	end
end

local mlHooked = false
C.ApplyOnlyWhenHidden = function()
	local p = P()
	mlFeatureOn = p and p.onlyWhenHidden or false
	if mlFeatureOn and not mlHooked then
		mlHooked = true
		hooksecurefunc("CameraOrSelectOrMoveStart", function() mlLeftWorld = true; ML_ControlStart() end)
		hooksecurefunc("CameraOrSelectOrMoveStop", function() mlLeftWorld = false; ML_ControlStop() end)
		hooksecurefunc("TurnOrActionStart", function() mlRight = true; ML_ControlStart() end)
		hooksecurefunc("TurnOrActionStop", function() mlRight = false; ML_ControlStop() end)
	end
	if not mlFeatureOn then
		mlLeftWorld, mlRight, mlPending = false, false, false
		mouselookActive = false
	end
	C.UpdateVisibility()
end

-------------------------------------------------------------------------------
--  Events (combat edges only while a Combat Only toggle needs them)
-------------------------------------------------------------------------------
local evFrame = CreateFrame("Frame")
evFrame:SetScript("OnEvent", function() C.UpdateVisibility() end)
local combatEventsOn, visEventsOn = false, false

C.ApplyEvents = function()
	local p = P()
	if not p then return end
	local wantCombat = (p.combatOnly or p.gcd.combatOnly or p.castCircle.combatOnly
		or p.visibility == "in_combat" or p.visibility == "out_of_combat") and true or false
	if wantCombat ~= combatEventsOn then
		combatEventsOn = wantCombat
		if wantCombat then
			evFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
			evFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		else
			evFrame:UnregisterEvent("PLAYER_REGEN_DISABLED")
			evFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
		end
	end
	local wantVis = (p.visHideMounted or p.visHideNoTarget or p.visHideNoEnemy
		or p.visibility == "in_raid" or p.visibility == "in_party" or p.visibility == "solo") and true or false
	if wantVis ~= visEventsOn then
		visEventsOn = wantVis
		if wantVis then
			evFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
			evFrame:RegisterEvent("COMPANION_UPDATE")
			evFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
		else
			evFrame:UnregisterEvent("PLAYER_TARGET_CHANGED")
			evFrame:UnregisterEvent("COMPANION_UPDATE")
			evFrame:UnregisterEvent("GROUP_ROSTER_UPDATE")
		end
	end
end

-------------------------------------------------------------------------------
--  Unlock Mode (detached GCD / Cast rings)
-------------------------------------------------------------------------------
local function GCDDetached() local g = GCD_DB(); return g.enabled and g.attached == false end
local function CastDetached() local c = Cast_DB(); return c.enabled and c.attached == false end

local function RingElement(key, label, order, detached, cfgFn, getRoot, apply, applyPos)
	local function Resize(v)
		local cfg = cfgFn()
		cfg.radius = max(5, floor(v / 2 + 0.5))
		apply()
		if ns._unlockActive and ns.RepositionBarToMover then ns.RepositionBarToMover(key) end
	end
	return ns.MakeUnlockElement({
		key = key,
		label = label,
		group = "Cursor Lite",
		order = order,
		linkedDimensions = true,
		isHidden = function() return not detached() end,
		getFrame = function()
			if not detached() then return nil end
			return getRoot()
		end,
		getSize = function()
			local r = cfgFn().radius or 30
			return r * 2, r * 2
		end,
		setWidth = function(_, w) Resize(w) end,
		setHeight = function(_, h) Resize(h) end,
		savePos = function(_, point, relPoint, x, y)
			cfgFn().pos = { point = point, relPoint = relPoint, x = x, y = y }
			if not ns._unlockActive then apply() end
		end,
		loadPos = function() return cfgFn().pos end,
		clearPos = function() cfgFn().pos = nil end,
		applyPos = applyPos,
	})
end

local unlockRegistered = false
C.RegisterUnlock = function()
	if unlockRegistered or not ns.RegisterUnlockElements or not ns.MakeUnlockElement then return end
	unlockRegistered = true
	ns:RegisterUnlockElements({
		RingElement("ECL_GCD", "GCD Circle", 500, GCDDetached, GCD_DB, function() return gcdRoot end,
			function() C.ApplyGCDCircle() end, function() C.ApplyGCDPosition() end),
		RingElement("ECL_Cast", "Cast Bar Circle", 501, CastDetached, Cast_DB, function() return castRoot end,
			function() C.ApplyCastCircle() end, function() C.ApplyCastPosition() end),
	}, addonName)
	if ns.RegisterUnlockModeListener then
		ns:RegisterUnlockModeListener("EllesmereUIQoL_Cursor", function(active)
			if active then
				-- Attached rings hide; detached rings stop following the mouse.
				if gcdRoot then
					gcdRoot:SetScript("OnUpdate", nil)
					if GCD_DB().attached ~= false then gcdRoot:Hide() end
				end
				if castRoot then
					castRoot:SetScript("OnUpdate", nil)
					if Cast_DB().attached ~= false then castRoot:Hide() end
				end
			else
				C.ApplyGCDCircle()
				C.ApplyCastCircle()
			end
		end)
	end
end

-------------------------------------------------------------------------------
--  Apply all (settings window applyHooks + login)
-------------------------------------------------------------------------------
local loggedIn = false
C.ApplyAll = function()
	if not loggedIn or not P() then return end
	C.Apply()
	C.ApplyGCDCircle()
	C.ApplyCastCircle()
	C.ApplyTrail()
	C.ApplyOnlyWhenHidden()
	C.ApplyEvents()
end
ns.CursorApply = C.ApplyAll
ns.CursorModule = C

ns.applyHooks = ns.applyHooks or {}
tinsert(ns.applyHooks, function() C.ApplyAll() end)

ns.accentListeners = ns.accentListeners or {}
tinsert(ns.accentListeners, function()
	local p = loggedIn and P()
	if not p then return end
	if p.useAccentColor then C.Apply() end
	if p.gcd.useAccentColor then C.ApplyGCDCircle() end
	if p.castCircle.useAccentColor then C.ApplyCastCircle() end
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:RegisterEvent("ZONE_CHANGED_NEW_AREA")
boot:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		loggedIn = true
		C.RegisterUnlock()
		C.ApplyAll()
	else
		C.UpdateVisibility()
	end
end)

-------------------------------------------------------------------------------
--  Retail profile import: also take the cursor table.
-------------------------------------------------------------------------------
do
	local R = ns.ProfileRetail
	if R and R.CONVERT then
		local prev = R.CONVERT.EllesmereUIQoL
		R.CONVERT.EllesmereUIQoL = function(blob, notes)
			local root = prev and prev(blob, notes)
			if type(blob) == "table" and type(blob.cursor) == "table" then
				if not root then
					root = ns.ProfileDeepCopy and ns.ProfileDeepCopy(EllesmereUIQoLDB or {}) or {}
				end
				root.cursor = ns.ProfileDeepCopy and ns.ProfileDeepCopy(blob.cursor) or blob.cursor
				root.cursor._seeded = nil
			end
			return root
		end
	end
end
