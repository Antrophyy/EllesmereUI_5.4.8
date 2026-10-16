-------------------------------------------------------------------------------
--  EUI_Minimap_Map.lua  (5.4.8 port of the EllesmereUI Minimap)
--
--  The map: taken out of MinimapCluster (which is hidden), its size, shape
--  mask (square / rectangular / circle), border, zoom buttons, hover reveal,
--  text elements (clock, zone, coordinates, FPS/MS, difficulty as text), the
--  Blizzard parts of 5.4.8 (difficulty flags, queue eye, mail, tracking,
--  calendar, voice chat, world map button), Visibility and Opacity, the
--  middle-click micro menu, Unlock Mode and the start-up.
-------------------------------------------------------------------------------
local _, P = ...
local ns = P.ns
local EMM = P.EMM

local floor, max, min, sqrt = math.floor, math.max, math.min, math.sqrt
local GetFFD = P.GetFFD
local DB = P.DB

local ApplyMinimap, ApplyAll

local function QueueApplyAll()
	P.AfterCombat("minimapApply", function() ApplyAll() end)
end
P.QueueApplyAll = QueueApplyAll

-------------------------------------------------------------------------------
--  Utility
-------------------------------------------------------------------------------
local function GetBorderColor(cfg)
	if cfg.useClassColor then
		local r, g, b = P.Accent()
		return r, g, b, 1
	end
	return cfg.borderR or 0, cfg.borderG or 0, cfg.borderB or 0, cfg.borderA or 1
end

-- Border color: class > accent (legacy useClassColor) > custom > legacy RGB.
local function GetBorderStyleColor(cfg)
	if cfg.borderUseClassColor then
		local r, g, b = P.ClassColor()
		return r, g, b, cfg.borderA or 1
	end
	if cfg.useClassColor then
		local r, g, b = P.Accent()
		return r, g, b, cfg.borderA or 1
	end
	local c = cfg.borderColor
	if c then
		return c.r, c.g, c.b, cfg.borderA or 1
	end
	return GetBorderColor(cfg)
end
EMM.GetBorderStyleColor = GetBorderStyleColor

-- Description color (clock AM/PM, FPS/MS suffixes): custom or accent.
local function GetDescColor(mp)
	local r, g, b
	if mp and mp.fpsUseAccent then
		r, g, b = P.Accent()
	else
		local c = mp and mp.fpsColor
		if c then
			r, g, b = c.r or 1, c.g or 1, c.b or 1
		else
			r, g, b = 1, 1, 1
		end
	end
	return r, g, b, P.Hex(r, g, b)
end

local hiddenFrame = CreateFrame("Frame")
hiddenFrame:Hide()
P.hiddenFrame = hiddenFrame

-------------------------------------------------------------------------------
--  Zoom
-------------------------------------------------------------------------------
local function SaveZoomLevel()
	local p = DB()
	if p then
		p.savedZoom = Minimap:GetZoom()
	end
end

-- Auto Zoom Reset: back to zoom 0 after zoomResetSeconds without a change.
local zoomResetTimer
local function RestartZoomResetTimer()
	if zoomResetTimer then
		zoomResetTimer:Cancel()
		zoomResetTimer = nil
	end
	local p = DB()
	local secs = p and p.zoomResetSeconds or 0
	if not secs or secs <= 0 then
		return
	end
	zoomResetTimer = P.NewTimer(secs, function()
		zoomResetTimer = nil
		if Minimap:GetZoom() ~= 0 then
			Minimap:SetZoom(0)
			SaveZoomLevel()
		end
	end)
end

-- Zoom +/- buttons (EllesmereUI look: small black boxes with a white glyph;
-- the 5.4.8 round zoom buttons stay hidden).
local zoomIn, zoomOut

local function UpdateZoomButtons()
	if not zoomIn then
		return
	end
	local z, levels = Minimap:GetZoom(), Minimap:GetZoomLevels()
	zoomIn.enabled = z < levels - 1
	zoomOut.enabled = z > 0
	for _, b in ipairs({ zoomIn, zoomOut }) do
		local a = b.enabled and (b:IsMouseOver() and 1 or 0.8) or 0.3
		for _, t in ipairs(b.glyph) do
			t:SetAlpha(a)
		end
	end
end

local function CreateZoomButton(isIn)
	local b = CreateFrame("Button", nil, Minimap)
	b:SetSize(18, 18)
	b._bg = P.BlackBox(b, 0.8)
	b.glyph = {}
	local h = b:CreateTexture(nil, "ARTWORK")
	h:SetTexture(1, 1, 1, 1)
	h:SetSize(8, 2)
	h:SetPoint("CENTER")
	b.glyph[1] = h
	if isIn then
		local v = b:CreateTexture(nil, "ARTWORK")
		v:SetTexture(1, 1, 1, 1)
		v:SetSize(2, 8)
		v:SetPoint("CENTER")
		b.glyph[2] = v
	end
	b:SetScript("OnClick", function(self)
		if not self.enabled then
			return
		end
		local z = Minimap:GetZoom()
		Minimap:SetZoom(isIn and (z + 1) or (z - 1))
		PlaySound(isIn and "igMiniMapZoomIn" or "igMiniMapZoomOut")
		SaveZoomLevel()
		RestartZoomResetTimer()
		UpdateZoomButtons()
	end)
	b:SetScript("OnEnter", function(self)
		if P.HVRevealMapHover then P.HVRevealMapHover() end
		UpdateZoomButtons()
		P.ShowTip(self, isIn and (ZOOM_IN or "Zoom In") or (ZOOM_OUT or "Zoom Out"), { anchor = "left" })
	end)
	b:SetScript("OnLeave", function()
		UpdateZoomButtons()
		P.HideTip()
	end)
	P.flyoutOwnedFrames[b] = true
	return b
end

-------------------------------------------------------------------------------
--  Text elements
-------------------------------------------------------------------------------
local coordFrame, coordTicker
local clockFrame, clockTicker, clockBg
local locationFrame, locationBg
local fpsBg
local diffTextFrame

local function UpdateClock()
	if not clockFrame then
		return
	end
	local use24h = GetCVar("timeMgrUseMilitaryTime") == "1"
	local h, m
	if GetCVar("timeMgrUseLocalTime") == "1" then
		local t = date("*t")
		h, m = t.hour, t.min
	else
		h, m = GetGameTime()
	end
	if use24h then
		clockFrame:SetText(format("%02d:%02d", h, m))
	else
		local ampm = h >= 12 and "PM" or "AM"
		h = h % 12
		if h == 0 then h = 12 end
		local mp = DB()
		if mp and mp.fpsColorClockAMPM then
			local _, _, _, hex = GetDescColor(mp)
			clockFrame:SetFormattedText("%d:%02d |cff%s%s|r", h, m, hex, ampm)
		else
			clockFrame:SetFormattedText("%d:%02d %s", h, m, ampm)
		end
	end
end

-- Coords mode / position with the legacy coordsBelow fallback.
local function GetCoordsModePos(mp)
	if not mp then
		return "always", "topLeft"
	end
	local mode = mp.coordsMode or (mp.coordsBelow and "always") or "always"
	local pos = mp.coordsPosition or (mp.coordsBelow and "belowMap") or "topLeft"
	return mode, pos
end
EMM.GetCoordsModePos = GetCoordsModePos

-- Clock / zone modes with the legacy clockInside / zoneInside fallback.
local function GetElementModes(mp)
	if not mp then
		return "inside", "inside"
	end
	local clockMode = mp.clockMode
	if clockMode == nil then
		if mp.showClock == false then
			clockMode = "none"
		else
			clockMode = (mp.clockInside == false) and "edge" or "inside"
		end
	end
	local locationMode = mp.locationMode
	if locationMode == nil then
		if mp.hideZoneText == true then
			locationMode = "none"
		else
			locationMode = mp.zoneInside and "inside" or "edge"
		end
	end
	return clockMode, locationMode
end
EMM.GetElementModes = GetElementModes

-- position key -> element point, map relPoint, base X, base Y.
local MAP_POS_ANCHORS = {
	belowMap = { "TOP", "BOTTOM", 0, -5 },
	aboveMap = { "BOTTOM", "TOP", 0, 5 },
	topLeft = { "TOPLEFT", "TOPLEFT", 4, -4 },
	top = { "TOP", "TOP", 0, -4 },
	topRight = { "TOPRIGHT", "TOPRIGHT", -4, -4 },
	left = { "LEFT", "LEFT", 4, 0 },
	right = { "RIGHT", "RIGHT", -4, 0 },
	bottomLeft = { "BOTTOMLEFT", "BOTTOMLEFT", 4, 4 },
	bottom = { "BOTTOM", "BOTTOM", 0, 4 },
	bottomRight = { "BOTTOMRIGHT", "BOTTOMRIGHT", -4, 4 },
}

-- Inside keeps the 4 px inset; edge makes the box straddle the border.
local function ResolveElementAnchor(pos, style, isCircle)
	local a = MAP_POS_ANCHORS[pos] or MAP_POS_ANCHORS.top
	local x, y = a[3], a[4]
	if style == "edge" and pos ~= "belowMap" and pos ~= "aboveMap" then
		if x ~= 0 then x = isCircle and (x > 0 and 3 or -3) or (x > 0 and -7 or 7) end
		if y ~= 0 then y = isCircle and (y > 0 and 3 or -3) or (y > 0 and -7 or 7) end
	end
	return a[1], a[2], x, y
end

-- 5.4.8: the player position on the current zone map. The world map's zone
-- is set to the player's zone on zone changes (not while the map is open).
local function SetMapToPlayerZone()
	if WorldMapFrame and WorldMapFrame:IsShown() then
		return
	end
	if SetMapToCurrentZone then
		SetMapToCurrentZone()
	end
end

local cachedCoordPrec, cachedCoordFmt
local function UpdateCoords()
	if not coordFrame then
		return
	end
	if WorldMapFrame and WorldMapFrame:IsShown() then
		return
	end
	local x, y = GetPlayerMapPosition("player")
	if not x or (x == 0 and y == 0) then
		coordFrame:SetText("")
		return
	end
	local p = DB()
	local prec = p and p.coordPrecision or 1
	if prec ~= cachedCoordPrec then
		cachedCoordPrec = prec
		cachedCoordFmt = format("%%.%df, %%.%df", prec, prec)
	end
	coordFrame:SetText(format(cachedCoordFmt, x * 100, y * 100))
end

-- Reactive zone color by the zone's PvP rules.
local function GetZoneReactionColor()
	local pvpType = GetZonePVPInfo()
	if pvpType == "friendly" then
		return 0.05, 0.85, 0.03
	elseif pvpType == "sanctuary" then
		return 0.035, 0.58, 0.84
	elseif pvpType == "arena" or pvpType == "hostile" or pvpType == "combat" then
		return 0.84, 0.03, 0.03
	end
	return 0.9, 0.85, 0.05
end

local lastLocationText
local function UpdateLocation()
	if not locationFrame then
		return
	end
	local mp = DB()
	if mp and mp.zoneReactiveColor then
		local r, g, b = GetZoneReactionColor()
		locationFrame:SetTextColor(r, g, b, 0.9)
	else
		locationFrame:SetTextColor(1, 1, 1, 0.9)
	end
	local text
	if mp and mp.zoneShowSubZone then
		local sub = GetSubZoneText()
		text = (sub and sub ~= "") and sub or (GetZoneText() or "")
	else
		text = GetZoneText() or ""
	end
	if text == lastLocationText then
		return
	end
	lastLocationText = text
	locationFrame:SetText(text)
	if locationBg then
		locationBg:SetSize((locationFrame:GetStringWidth() or 0) + 20, 18)
	end
end

-------------------------------------------------------------------------------
--  Hover reveal (zoom buttons, hover-mode queue eye and coordinates)
-------------------------------------------------------------------------------
local function GetQueueStatusMode(mp)
	return (mp and mp.queueStatusMode) or "always"
end

function P.HoverStillOver(minimap)
	local f = GetFFD(minimap).layoutFrame or minimap
	if f:IsVisible() and f:IsMouseOver(4, -4, -4, 4) then
		return true
	end
	local q = _G.QueueStatusMinimapButton
	if q and q:IsVisible() and q:GetAlpha() > 0 and q:IsMouseOver(4, -4, -4, 4) then
		return true
	end
	return false
end

-- The queue eye: Blizzard decides when it shows; we only fade it.
local function SetQueueEyeRevealed(on)
	local q = _G.QueueStatusMinimapButton
	if not q then
		return
	end
	q:SetAlpha(on and 1 or 0)
	q:EnableMouse(on and true or false)
end

function P.HVHideNow()
	local minimap = Minimap
	local ffd = GetFFD(minimap)
	if ffd.hvWatcher then
		ffd.hvWatcher:Cancel()
		ffd.hvWatcher = nil
	end
	if zoomIn then zoomIn:Hide() end
	if zoomOut then zoomOut:Hide() end
	local mp = DB()
	if mp then
		if GetQueueStatusMode(mp) == "hover" then
			SetQueueEyeRevealed(false)
		end
		if GetCoordsModePos(mp) == "hover" then
			if coordFrame then coordFrame:Hide() end
			if coordTicker then coordTicker:Cancel(); coordTicker = nil end
		end
	end
	if P.MO_IsActive and P.MO_IsActive() then
		if P.MO_OverAny() then
			P.MO_Evaluate()
		else
			P.MO_CancelHide()
			P.MO_Apply(false)
		end
	end
end

function P.HVRevealMapHover()
	local minimap = Minimap
	local ffd = GetFFD(minimap)
	if not ffd.active then
		return
	end
	if not P.HoverStillOver(minimap) then
		-- OnEnter fires once per hover: retry briefly at the boundary.
		if not ffd.hvRetry then
			local tries = 0
			ffd.hvRetry = P.NewTicker(0.1, function()
				tries = tries + 1
				if P.HoverStillOver(minimap) then
					ffd.hvRetry:Cancel()
					ffd.hvRetry = nil
					P.HVRevealMapHover()
				elseif tries >= 8 then
					ffd.hvRetry:Cancel()
					ffd.hvRetry = nil
				end
			end)
		end
		return
	end
	if ffd.hvRetry then
		ffd.hvRetry:Cancel()
		ffd.hvRetry = nil
	end
	local mp = DB()
	if not mp then
		return
	end
	if not mp.hideZoomButtons then
		if zoomIn then zoomIn:Show() end
		if zoomOut then zoomOut:Show() end
		UpdateZoomButtons()
	end
	if GetQueueStatusMode(mp) == "hover" then
		SetQueueEyeRevealed(true)
	end
	if GetCoordsModePos(mp) == "hover" then
		if coordFrame then coordFrame:Show() end
		if not coordTicker then
			coordTicker = P.NewTicker(0.5, UpdateCoords)
		end
		UpdateCoords()
	end
	if P.MO_Evaluate then P.MO_Evaluate() end
	if ffd.hvWatcher then
		return
	end
	ffd.hvWatcher = P.NewTicker(0.2, function()
		if P.HoverStillOver(minimap) then
			return
		end
		P.HVHideNow()
	end)
end

-------------------------------------------------------------------------------
--  Blizzard parts
-------------------------------------------------------------------------------
-- Kept hidden while the module runs (Blizzard re-shows some of them).
local function KeepHidden(frame)
	if not frame then
		return
	end
	frame:Hide()
	local d = GetFFD(frame)
	if not d.keepHidden then
		d.keepHidden = true
		hooksecurefunc(frame, "Show", function(self)
			if GetFFD(Minimap).active then
				self:Hide()
			end
		end)
	end
end

local function HideBlizzardParts()
	-- The cluster (zone text, top border) and the backdrop (ring, north tag,
	-- compass, world map button, stock tracking and zoom buttons).
	if MinimapCluster then
		MinimapCluster:SetAlpha(0)
		MinimapCluster:EnableMouse(false)
	end
	KeepHidden(_G.MinimapBackdrop)
	KeepHidden(_G.MinimapZoneTextButton)
	KeepHidden(_G.MinimapBorderTop)
	KeepHidden(_G.TimeManagerClockButton)
	KeepHidden(_G.MiniMapWorldMapButton)
	-- Voice chat button (child of the map): hidden like the rest.
	local voice = _G.MiniMapVoiceChatFrame
	if voice then
		voice:SetAlpha(0)
		voice:EnableMouse(false)
	end
	for _, name in ipairs({ "MinimapZoomIn", "MinimapZoomOut" }) do
		local b = _G[name]
		if b then
			b:SetParent(hiddenFrame)
			P.flyoutOwnedFrames[b] = true
		end
	end
end

-- Difficulty flags (5.4.8: instance, guild group, challenge mode).
local DIFF_FRAMES = { "MiniMapInstanceDifficulty", "GuildInstanceDifficulty", "MiniMapChallengeMode" }

local function LayoutDifficulty(minimap, p, mapAnchor)
	local suppressed = p.hideRaidDifficulty or p.diffTextEnabled
	for _, name in ipairs(DIFF_FRAMES) do
		local f = _G[name]
		if f then
			f:SetParent(minimap)
			f:SetFrameLevel(minimap:GetFrameLevel() + 12)
			f:ClearAllPoints()
			f:SetPoint("TOPRIGHT", mapAnchor, "TOPRIGHT", 2, 1)
			f:SetAlpha(suppressed and 0 or 1)
			f:EnableMouse(not suppressed and name ~= "MiniMapInstanceDifficulty")
		end
	end
end

-- Queue eye (QueueStatusMinimapButton): out of the hidden backdrop onto the
-- map, pinned to a corner with an X / Y nudge and a scale.
local queueApplying = false
local function PositionQueueEye(btn, p)
	queueApplying = true
	if btn:GetParent() ~= Minimap then
		btn:SetParent(Minimap)
	end
	btn:SetFrameStrata("HIGH")
	btn:SetFrameLevel(Minimap:GetFrameLevel() + 10)
	btn:SetScale(p.queueStatusScale or 0.8)
	btn:ClearAllPoints()
	local corner = p.queueStatusCorner or "BOTTOMLEFT"
	btn:SetPoint(corner, GetFFD(Minimap).layoutFrame or Minimap, corner, p.queueStatusX or 0, p.queueStatusY or 0)
	local border = _G.QueueStatusMinimapButtonBorder
	if border then
		border:Hide()
	end
	queueApplying = false
end

local function ApplyQueueEye(p)
	local btn = _G.QueueStatusMinimapButton
	if not btn then
		return
	end
	P.flyoutOwnedFrames[btn] = true
	local d = GetFFD(btn)
	if not d.hooked then
		d.hooked = true
		local function reassert(self)
			if queueApplying or not GetFFD(Minimap).active then
				return
			end
			local m = DB()
			if m then
				PositionQueueEye(self, m)
			end
		end
		hooksecurefunc(btn, "SetParent", reassert)
		hooksecurefunc(btn, "SetPoint", reassert)
		btn:HookScript("OnEnter", function() P.HVRevealMapHover() end)
		-- The queue list opens away from the map.
		local qf = _G.QueueStatusFrame
		if qf then
			qf:SetClampedToScreen(true)
		end
	end
	PositionQueueEye(btn, p)
	local mode = GetQueueStatusMode(p)
	if mode == "never" then
		SetQueueEyeRevealed(false)
	elseif mode == "hover" then
		SetQueueEyeRevealed(P.HoverStillOver(Minimap))
	else
		SetQueueEyeRevealed(true)
	end
end

-------------------------------------------------------------------------------
--  First install: start from Blizzard's size and place (once per profile).
-------------------------------------------------------------------------------
local function CaptureBlizzardMinimap()
	local minimap = Minimap
	local p = DB()
	if p._capturedOnce then
		return
	end
	local ratio = minimap:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local w, h = minimap:GetWidth(), minimap:GetHeight()
	if w and w > 10 then
		p.mapSize = floor(max(w, h) * ratio + 0.5)
	end
	local cx, cy = minimap:GetCenter()
	if cx and cy then
		local uiW, uiH = UIParent:GetSize()
		p.position = { point = "CENTER", relPoint = "CENTER", x = cx * ratio - uiW / 2, y = cy * ratio - uiH / 2 }
	end
	p._capturedOnce = true
end

-------------------------------------------------------------------------------
--  Visibility and Opacity
-------------------------------------------------------------------------------
local function MapAlpha(p)
	if _G.FarmHud and _G.FarmHud:IsShown() then
		return 1
	end
	local o = p and p.opacity
	if type(o) ~= "number" then
		return 1
	end
	return max(10, min(100, o)) / 100
end

function EMM.ApplyMapAlpha()
	local p = DB()
	if Minimap and p and GetFFD(Minimap).active then
		Minimap:SetAlpha(MapAlpha(p))
	end
end

local function CursorOverMapRect()
	local f = GetFFD(Minimap).layoutFrame or Minimap
	local l, r, t, b = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
	if not l then
		return false
	end
	local s = f:GetEffectiveScale()
	local x, y = GetCursorPosition()
	x, y = x / s, y / s
	return x >= l - 2 and x <= r + 2 and y >= b - 2 and y <= t + 2
end

local mouseoverPoll
local function SetMapShown(shown)
	local p = DB()
	local minimap = Minimap
	if InCombatLockdown() and minimap:IsProtected() then
		-- A protected child makes the map protected: fade instead, fix after combat.
		minimap:SetAlpha(shown and MapAlpha(p) or 0)
		P.AfterCombat("minimapVis", function() EMM.UpdateVisibility() end)
		return
	end
	minimap:SetAlpha(MapAlpha(p))
	if shown then
		minimap:Show()
	else
		minimap:Hide()
	end
end

function EMM.UpdateVisibility()
	local p = DB()
	if not p or not GetFFD(Minimap).active then
		return
	end
	local vis = EMM.EvalVisibility(p)
	if vis == "mouseover" then
		SetMapShown(CursorOverMapRect())
		if not mouseoverPoll then
			mouseoverPoll = P.NewTicker(0.1, function()
				local over = CursorOverMapRect()
				if over ~= Minimap:IsShown() then
					SetMapShown(over)
				end
			end)
		end
	else
		if mouseoverPoll then
			mouseoverPoll:Cancel()
			mouseoverPoll = nil
		end
		SetMapShown(vis and true or false)
	end
end

do
	local f = CreateFrame("Frame")
	for _, ev in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE",
		"ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_UPDATE_RESTING",
		"COMPANION_UPDATE", "UNIT_FACTION" }) do
		pcall(f.RegisterEvent, f, ev)
	end
	if f.RegisterUnitEvent then
		pcall(f.RegisterUnitEvent, f, "UNIT_AURA", "player")
	end
	f:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_DISABLED" and P.CloseMicroMenu then
			P.CloseMicroMenu()
		end
		EMM.UpdateVisibility()
	end)
end

-------------------------------------------------------------------------------
--  Position (Unlock Mode stores a CENTER offset from the screen center)
-------------------------------------------------------------------------------
local function PlaceMinimap()
	local p = DB()
	local minimap = Minimap
	-- Unlock Mode (EllesmereUI core) owns the spot while it is open.
	if ns._unlockActive and GetFFD(minimap).placed and minimap:GetNumPoints() > 0 then
		return
	end
	GetFFD(minimap).placed = true
	minimap:ClearAllPoints()
	if p.position then
		local px, py = p.position.x or 0, p.position.y or 0
		minimap:SetPoint(p.position.point or "CENTER", UIParent, p.position.relPoint or "CENTER",
			P.Snap(px, minimap), P.Snap(py, minimap))
	else
		minimap:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -10, -10)
	end
end

-------------------------------------------------------------------------------
--  Map shape masks (5.4.8 textures; the rectangular crop is retail's art)
-------------------------------------------------------------------------------
local MASK_SQUARE = "Interface\\ChatFrame\\ChatFrameBackground"
local MASK_CIRCLE = "Textures\\MinimapMask"
local MASK_RECT = P.MEDIA .. "minimap_rectangular-crop-mask"
local CIRCLE_TEX = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

-------------------------------------------------------------------------------
--  Apply
-------------------------------------------------------------------------------
local function OnMinimapMouseUp(self, button)
	if button == "MiddleButton" then
		local mp = DB()
		if mp and mp.openMicroMenuOnMiddleClick == false then
			return
		end
		if P.ToggleMicroMenu then
			P.ToggleMicroMenu()
		end
		return
	end
	-- Ping anywhere on the visible map (the stock handler only pings inside
	-- a circle).
	local x, y = GetCursorPosition()
	local s = self:GetEffectiveScale()
	x, y = x / s, y / s
	local cx, cy = self:GetCenter()
	x, y = x - cx, y - cy
	local mp = DB()
	local shape = mp and mp.shape or "square"
	if shape == "circle" and sqrt(x * x + y * y) >= self:GetWidth() / 2 then
		return
	end
	self:PingLocation(x, y)
end

local function OnMinimapWheel(_, delta)
	local mp = DB()
	if not mp or not mp.scrollZoom then
		return
	end
	local zoom = Minimap:GetZoom()
	if delta > 0 then
		zoom = min(zoom + 1, Minimap:GetZoomLevels() - 1)
	else
		zoom = max(zoom - 1, 0)
	end
	Minimap:SetZoom(zoom)
	SaveZoomLevel()
	RestartZoomResetTimer()
	UpdateZoomButtons()
end

ApplyMinimap = function()
	if not P.started then
		return
	end
	if InCombatLockdown() then
		QueueApplyAll()
		return
	end
	local p = DB()
	p.enabled = true
	local minimap = Minimap

	-- Rotate Minimap: the CVar follows the setting.
	local want = p.rotateMinimap and "1" or "0"
	if GetCVar("rotateMinimap") ~= want then
		if ns.SetCVarSafe then
			ns.SetCVarSafe("rotateMinimap", want)
		else
			SetCVar("rotateMinimap", want)
		end
	end

	CaptureBlizzardMinimap()

	-- Out of MinimapCluster: its layout cannot touch our size, and it is hidden.
	if minimap:GetParent() ~= UIParent then
		minimap:SetParent(UIParent)
	end
	minimap:SetFrameStrata("LOW")
	if not GetFFD(minimap).parentGuard then
		GetFFD(minimap).parentGuard = true
		hooksecurefunc(minimap, "SetParent", function(self, parent)
			if parent ~= UIParent and not (_G.FarmHud and parent == _G.FarmHud) and GetFFD(self).active then
				if InCombatLockdown() then
					QueueApplyAll()
				else
					self:SetParent(UIParent)
				end
			end
		end)
		if Minimap_UpdateRotationSetting then
			hooksecurefunc("Minimap_UpdateRotationSetting", function()
				if GetFFD(Minimap).active then
					if MinimapCompassTexture then MinimapCompassTexture:Hide() end
					if MinimapNorthTag then MinimapNorthTag:Hide() end
				end
			end)
		end
	end
	HideBlizzardParts()

	-- Mouse: middle-click micro menu, ping, wheel zoom.
	if not GetFFD(minimap).mouseHooked then
		GetFFD(minimap).mouseHooked = true
		minimap:SetScript("OnMouseUp", OnMinimapMouseUp)
		minimap:SetScript("OnMouseWheel", OnMinimapWheel)
		minimap:HookScript("OnEnter", function() P.HVRevealMapHover() end)
		minimap:HookScript("OnLeave", function(self)
			if P.HoverStillOver(self) then
				P.HVRevealMapHover()
			else
				P.HVHideNow()
			end
		end)
	end
	minimap:EnableMouseWheel(p.scrollZoom and true or false)

	local shape = p.shape or "square"
	if shape == "textured_circle" then
		shape = "circle"
	end
	local isCircle = shape == "circle"
	local isRectangular = shape == "rectangular"
	P.isCircle = isCircle

	-- Addons ask the shape for their minimap pins and buttons.
	GetMinimapShape = function()
		local m = DB()
		local s = m and m.shape or "square"
		return (s == "circle" or s == "textured_circle") and "ROUND" or "SQUARE"
	end

	if minimap.SetArchBlobRingScalar then
		minimap:SetArchBlobRingScalar(isCircle and 1 or 0)
	end
	if minimap.SetQuestBlobRingScalar then
		minimap:SetQuestBlobRingScalar(isCircle and 1 or 0)
	end

	minimap:SetScale(1.0)
	local mapSize = p.mapSize or 140
	-- The map canvas stays square; rectangular crops it with a 4:3 mask.
	minimap:SetSize(mapSize, mapSize)
	minimap:SetMaskTexture(isCircle and MASK_CIRCLE or (isRectangular and MASK_RECT) or MASK_SQUARE)
	local cropInset = isRectangular and (mapSize * 32 / 256) or 0
	minimap:SetHitRectInsets(0, 0, cropInset, cropInset)

	-- Layout frame: the visible 4:3 rectangle (rectangular shape only).
	if isRectangular and not GetFFD(minimap).layoutFrame then
		local layout = CreateFrame("Frame", nil, UIParent)
		layout:EnableMouse(false)
		GetFFD(minimap).layoutFrame = layout
	end
	local layout = GetFFD(minimap).layoutFrame
	if layout then
		if isRectangular then
			layout:ClearAllPoints()
			layout:SetPoint("CENTER", minimap, "CENTER")
			layout:SetSize(mapSize, mapSize * 192 / 256)
		else
			GetFFD(minimap).layoutFrame = nil
			layout:Hide()
		end
	end
	local mapAnchor = GetFFD(minimap).layoutFrame or minimap

	-- Border: solid pixel edges (square / rectangular) or a disc behind the
	-- round map.
	local r, g, b, borderA = GetBorderStyleColor(p)
	local bs = p.borderSize or 1
	if not isCircle then
		local host = GetFFD(minimap).borderHost
		if not host then
			host = CreateFrame("Frame", nil, minimap)
			host:EnableMouse(false)
			host.edges = P.CreateEdges(host, host, "OVERLAY", 7)
			GetFFD(minimap).borderHost = host
		end
		host:ClearAllPoints()
		host:SetAllPoints(mapAnchor)
		host:SetFrameLevel(minimap:GetFrameLevel() + 1)
		P.LayoutEdges(host.edges, bs * P.PixelFor(minimap), r, g, b, borderA)
		host:Show()
		if GetFFD(minimap).circBorder then GetFFD(minimap).circBorder:Hide() end
	else
		if GetFFD(minimap).borderHost then GetFFD(minimap).borderHost:Hide() end
		local disc = GetFFD(minimap).circBorder
		if not disc then
			disc = CreateFrame("Frame", nil, minimap)
			local tex = disc:CreateTexture(nil, "BACKGROUND")
			tex:SetAllPoints(disc)
			tex:SetTexture(CIRCLE_TEX)
			disc._tex = tex
			GetFFD(minimap).circBorder = disc
		end
		disc:SetFrameLevel(max(0, minimap:GetFrameLevel() - 1))
		disc:ClearAllPoints()
		disc:SetPoint("TOPLEFT", minimap, "TOPLEFT", -bs, bs)
		disc:SetPoint("BOTTOMRIGHT", minimap, "BOTTOMRIGHT", bs, -bs)
		disc._tex:SetVertexColor(r, g, b, 1)
		disc:SetShown(bs > 0)
	end

	-- Clamp to the visible shape.
	minimap:SetClampedToScreen(true)
	if isRectangular then
		minimap:SetClampRectInsets(0, 0, -cropInset, cropInset)
	else
		local bInset = isCircle and bs or 0
		minimap:SetClampRectInsets(-bInset, bInset, bInset, -bInset)
	end
	-- Re-render at the new size: nudge the zoom and back.
	local curZoom = minimap:GetZoom()
	minimap:SetZoom(curZoom > 0 and 0 or 1)
	minimap:SetZoom(curZoom)

	-- Zoom +/- buttons at the bottom-right corner, shown while hovered.
	if not zoomIn then
		zoomIn = CreateZoomButton(true)
		zoomOut = CreateZoomButton(false)
		local zf = CreateFrame("Frame")
		zf:RegisterEvent("MINIMAP_UPDATE_ZOOM")
		zf:SetScript("OnEvent", UpdateZoomButtons)
	end
	for i, btn in ipairs({ zoomIn, zoomOut }) do
		btn:SetParent(p.hideZoomButtons and hiddenFrame or minimap)
		btn:SetFrameLevel(minimap:GetFrameLevel() + 10)
		btn:ClearAllPoints()
		btn:SetPoint("BOTTOMRIGHT", mapAnchor, "BOTTOMRIGHT", -2, i == 1 and 22 or 2)
		btn._bg:SetShown(p.btnBackgrounds ~= false)
		btn:SetShown(P.HoverStillOver(minimap))
	end
	UpdateZoomButtons()

	-- Group toggle (bottom-left) before the children are hidden.
	P.CreateFlyoutToggle()
	P.HideAllMinimapButtons()
	local mp2 = DB()
	local hideGroupBtn = mp2 and mp2.hideExtraBtns and mp2.hideExtraBtns.groupButton
	if #P.CollectFlyoutButtons() > 0 and not hideGroupBtn then
		P.flyoutToggle:Show()
	else
		P.flyoutToggle:Hide()
	end

	-- Late addons attach buttons after ADDON_LOADED: gather again.
	if not GetFFD(minimap).addonPoll then
		local poll = CreateFrame("Frame")
		poll:RegisterEvent("ADDON_LOADED")
		local pending = false
		poll:SetScript("OnEvent", function()
			if pending then
				return
			end
			pending = true
			P.After(0.1, function()
				pending = false
				if InCombatLockdown() then
					QueueApplyAll()
					return
				end
				P.HideAllMinimapButtons()
				P.InvalidateFlyout()
				if P.flyoutPanel and P.flyoutPanel:IsShown() then
					P.BuildFlyoutContents()
				end
			end)
		end)
		GetFFD(minimap).addonPoll = poll
	end
	P.InvalidateFlyout()
	P.HideFlyoutPanel()

	-- Clock: none, inside the map, or boxed on the map edge.
	local clockMode, locationMode = GetElementModes(p)
	if clockMode ~= "none" then
		if not clockBg then
			clockBg = CreateFrame("Button", nil, minimap)
			clockBg:SetSize(80, 16)
			clockBg.tex = clockBg:CreateTexture(nil, "BACKGROUND")
			clockBg.tex:SetAllPoints()
			clockBg:SetFrameLevel(minimap:GetFrameLevel() + 5)
			clockBg:RegisterForClicks("AnyUp")
			clockBg:SetScript("OnClick", function()
				if not ToggleTimeManager and LoadAddOn then
					LoadAddOn("Blizzard_TimeManager")
				end
				if ToggleTimeManager then
					ToggleTimeManager()
				end
			end)
			clockBg:SetScript("OnEnter", function(self)
				P.HVRevealMapHover()
				local mp = DB()
				if mp and mp.clockHoverTooltip == "lockouts" then
					local entries = P.GetCalendarLockoutEntries()
					if entries then
						P.ShowCalendarTooltip(self, entries)
					end
				end
			end)
			clockBg:SetScript("OnLeave", function()
				P.HideCalendarTooltip()
			end)
			clockFrame = P.NewText(clockBg)
			clockFrame:SetTextColor(1, 1, 1, 0.9)
			P.clockBg = clockBg
		end
		P.SetFont(clockFrame, 10)
		if clockMode == "inside" then
			clockBg.tex:SetTexture(0, 0, 0, 0)
		else
			local ar, ag, ab = GetBorderStyleColor(p)
			clockBg.tex:SetTexture(ar, ag, ab, 1)
		end
		local cpt, crel, cbx, cby = ResolveElementAnchor(p.clockPosition or "top", clockMode, isCircle)
		clockBg:ClearAllPoints()
		clockBg:SetPoint(cpt, mapAnchor, crel, cbx + (p.clockOffsetX or 0), cby + (p.clockOffsetY or 0))
		clockFrame:ClearAllPoints()
		if clockMode == "inside" then
			clockFrame:SetPoint(cpt, clockBg, cpt, 0, 0)
		else
			clockFrame:SetPoint("CENTER", clockBg, "CENTER", 0, 0)
		end
		clockBg:SetScale(p.clockScale or 1.15)
		clockBg:Show()
		clockFrame:Show()
		if not clockTicker then
			clockTicker = P.NewTicker(10, UpdateClock)
		end
		UpdateClock()
	else
		if clockBg then clockBg:Hide() end
		if clockTicker then clockTicker:Cancel(); clockTicker = nil end
	end

	P.LayoutIndicatorFrames(minimap, p, isCircle)
	LayoutDifficulty(minimap, p, mapAnchor)

	-- Blizzard's mail frame shows / hides with new mail: follow it.
	local mailFrame = _G.MiniMapMailFrame
	if mailFrame and not GetFFD(mailFrame).visHooked then
		GetFFD(mailFrame).visHooked = true
		local function onMailChange()
			local mp = DB()
			if not mp or not GetFFD(Minimap).active then
				return
			end
			if InCombatLockdown() then
				P.SyncIndicatorVisibility()
				return
			end
			P.LayoutIndicatorFrames(Minimap, mp, P.isCircle)
		end
		hooksecurefunc(mailFrame, "Show", onMailChange)
		hooksecurefunc(mailFrame, "Hide", onMailChange)
	end

	-- Zone text: none, inside the map, or boxed on the map edge.
	if locationMode ~= "none" then
		if not locationBg then
			locationBg = CreateFrame("Frame", nil, minimap)
			locationBg:SetSize(120, 18)
			locationBg.tex = locationBg:CreateTexture(nil, "BACKGROUND")
			locationBg.tex:SetAllPoints()
			locationBg:SetFrameLevel(minimap:GetFrameLevel() + 5)
			for _, ev in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do
				locationBg:RegisterEvent(ev)
			end
			locationBg:SetScript("OnEvent", function() UpdateLocation() end)
			locationFrame = P.NewText(locationBg)
			locationFrame:SetTextColor(1, 1, 1, 0.9)
		end
		P.SetFont(locationFrame, 10)
		lastLocationText = nil
		if locationMode == "inside" then
			locationBg.tex:SetTexture(0, 0, 0, 0)
		else
			local ar, ag, ab = GetBorderStyleColor(p)
			locationBg.tex:SetTexture(ar, ag, ab, 1)
		end
		local lpt, lrel, lbx, lby = ResolveElementAnchor(p.locationPosition or "bottom", locationMode, isCircle)
		locationBg:ClearAllPoints()
		locationBg:SetPoint(lpt, mapAnchor, lrel, lbx + (p.locationOffsetX or 0), lby + (p.locationOffsetY or 0))
		locationFrame:ClearAllPoints()
		if locationMode == "inside" then
			locationFrame:SetPoint(lpt, locationBg, lpt, 0, 0)
		else
			locationFrame:SetPoint("CENTER", locationBg, "CENTER", 0, 0)
		end
		locationBg:SetScale(p.locationScale or 1.15)
		locationBg:Show()
		UpdateLocation()
	elseif locationBg then
		locationBg:Hide()
	end

	-- Coordinates: never / hover / always, anchored around the map.
	if not coordFrame then
		coordFrame = P.NewText(minimap)
		coordFrame:SetTextColor(1, 1, 1, 0.9)
		local zf = CreateFrame("Frame")
		for _, ev in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do
			zf:RegisterEvent(ev)
		end
		zf:SetScript("OnEvent", SetMapToPlayerZone)
		if WorldMapFrame then
			WorldMapFrame:HookScript("OnHide", SetMapToPlayerZone)
		end
		SetMapToPlayerZone()
	end
	-- 5.4.8 FontStrings have no SetScale: the scale goes into the font size.
	P.SetFont(coordFrame, floor(11 * (p.coordsScale or 1.0) + 0.5))
	local coordsMode, coordsPos = GetCoordsModePos(p)
	local cpAnchor = MAP_POS_ANCHORS[coordsPos] or MAP_POS_ANCHORS.topLeft
	coordFrame:ClearAllPoints()
	coordFrame:SetPoint(cpAnchor[1], mapAnchor, cpAnchor[2], cpAnchor[3] + (p.coordsBelowOffsetX or 0), cpAnchor[4] + (p.coordsBelowOffsetY or 0))
	if coordsMode == "always" then
		coordFrame:Show()
		if not coordTicker then
			coordTicker = P.NewTicker(0.5, UpdateCoords)
		end
		UpdateCoords()
	else
		coordFrame:Hide()
		if coordTicker then
			coordTicker:Cancel()
			coordTicker = nil
		end
	end

	-- FPS / MS readout (same format and options as the QoL FPS counter).
	if p.showFPS then
		if not fpsBg then
			fpsBg = CreateFrame("Frame", nil, minimap)
			fpsBg:SetSize(60, 20)
			fpsBg:SetFrameLevel(minimap:GetFrameLevel() + 5)
			fpsBg:EnableMouse(false)
			local function MakeFS()
				local fs = P.NewText(fpsBg)
				fs:SetTextColor(1, 1, 1, 1)
				return fs
			end
			local DIV_H, DIV_PAD = 10, 6
			local function MakeDivider()
				local d = fpsBg:CreateTexture(nil, "OVERLAY")
				d:SetTexture(1, 1, 1, 1)
				return d
			end
			local fsFps, fsWorld, fsLocal = MakeFS(), MakeFS(), MakeFS()
			fpsBg._fsAll = { fsFps, fsWorld, fsLocal }
			local divWorld, divLocal = MakeDivider(), MakeDivider()
			local function UpdateFPS(self)
				local mp = DB()
				local divW = P.PixelFor(self)
				divWorld:SetSize(divW, DIV_H)
				divLocal:SetSize(divW, DIV_H)
				local hex = "ffffff"
				if (mp and mp.fpsColorSuffix) ~= false then
					local _, _, _, h = GetDescColor(mp)
					hex = h
				end
				local fps = floor(GetFramerate() + 0.5)
				local showWorld = mp and mp.fpsShowWorldMS
				local showLocal = not mp or mp.fpsShowLocalMS ~= false
				local _, _, latHome, latWorld = GetNetStats()
				fsFps:ClearAllPoints()
				fsFps:SetPoint("LEFT", self, "LEFT", 0, 0)
				fsFps:SetFormattedText("%d |cff%sFPS|r", fps, hex)
				local totalW = fsFps:GetStringWidth() or 0
				local anchor = fsFps
				if showWorld then
					divWorld:ClearAllPoints()
					divWorld:SetPoint("LEFT", anchor, "RIGHT", DIV_PAD, 0)
					divWorld:Show()
					fsWorld:ClearAllPoints()
					fsWorld:SetPoint("LEFT", divWorld, "RIGHT", DIV_PAD, 0)
					fsWorld:SetFormattedText("%d |cff%sMS|r", latWorld or 0, hex)
					fsWorld:Show()
					totalW = totalW + DIV_PAD * 2 + divW + (fsWorld:GetStringWidth() or 0)
					anchor = fsWorld
				else
					divWorld:Hide()
					fsWorld:Hide()
				end
				if showLocal then
					divLocal:ClearAllPoints()
					divLocal:SetPoint("LEFT", anchor, "RIGHT", DIV_PAD, 0)
					divLocal:Show()
					fsLocal:ClearAllPoints()
					fsLocal:SetPoint("LEFT", divLocal, "RIGHT", DIV_PAD, 0)
					fsLocal:SetFormattedText("%d |cff%sMS|r", latHome or 0, hex)
					fsLocal:Show()
					totalW = totalW + DIV_PAD * 2 + divW + (fsLocal:GetStringWidth() or 0)
				else
					divLocal:Hide()
					fsLocal:Hide()
				end
				self:SetSize(totalW + 4, 20)
			end
			local elapsed = 0
			fpsBg:SetScript("OnUpdate", function(self, dt)
				elapsed = elapsed + dt
				if elapsed < (self._interval or 3) then
					return
				end
				elapsed = 0
				UpdateFPS(self)
			end)
			fpsBg._updateNow = function()
				elapsed = 0
				UpdateFPS(fpsBg)
			end
			fpsBg:SetScript("OnEnter", function(self)
				P.HVRevealMapHover()
				local mp = DB()
				if mp and mp.fpsHoverTooltip == "lockouts" then
					local entries = P.GetCalendarLockoutEntries()
					if entries then
						P.ShowCalendarTooltip(self, entries)
					end
				end
			end)
			fpsBg:SetScript("OnLeave", function()
				P.HideCalendarTooltip()
			end)
		end
		for _, fs in ipairs(fpsBg._fsAll) do
			P.SetFont(fs, p.fpsTextSize or 12)
		end
		fpsBg._interval = p.fpsUpdateInterval or 3
		local fAnchor = MAP_POS_ANCHORS[p.fpsPosition or "bottomLeft"] or MAP_POS_ANCHORS.bottomLeft
		fpsBg:ClearAllPoints()
		fpsBg:SetPoint(fAnchor[1], mapAnchor, fAnchor[2], fAnchor[3] + (p.fpsOffsetX or 0), fAnchor[4] + (p.fpsOffsetY or 0))
		fpsBg:SetScale(p.fpsScale or 1.0)
		-- Mouse only while a hover tooltip is set, so it never blocks map clicks.
		fpsBg:EnableMouse((p.fpsHoverTooltip or "none") ~= "none")
		fpsBg:Show()
		fpsBg._updateNow()
	elseif fpsBg then
		fpsBg:Hide()
	end

	-- Instance Difficulty as Text ("25H"): replaces the Blizzard flag.
	if p.diffTextEnabled then
		if not diffTextFrame then
			diffTextFrame = CreateFrame("Frame", nil, minimap)
			local fs = P.NewText(minimap)
			fs:SetTextColor(1, 1, 1, 1)
			diffTextFrame._text = fs
			-- 5.4.8 difficulty IDs -> letter (count rules alongside).
			local SUFFIX = {
				[1] = "N", [2] = "H",                       -- dungeons
				[3] = "N", [4] = "N", [5] = "H", [6] = "H", -- 10 / 25 raids
				[7] = "LFR", [9] = "N", [14] = "F",         -- LFR, 40 player, Flexible
			}
			local FLEX = { [14] = true }
			local SCEN = { [12] = "S", [11] = "HS" }
			local REACTIVE_HEX = {
				N = "c69b6d", H = "0070dd", LFR = "9d9d9d", F = "c69b6d",
				S = "c69b6d", HS = "0070dd", CM = "ff8000",
			}
			diffTextFrame._update = function(self)
				local out = self._text
				local mp = DB()
				if not (mp and mp.diffTextEnabled) then
					out:SetText("")
					return
				end
				local _, instanceType, diffID, _, maxPlayers, _, _, _, groupSize = GetInstanceInfo()
				if not diffID or diffID == 0 or instanceType == "none" then
					out:SetText("")
					return
				end
				local reactive = mp.diffTextReactive
				local hex = "ffffff"
				if not reactive and mp.diffTextAccent then
					local _, _, _, h = GetDescColor(mp)
					hex = h
				end
				if diffID == 8 then
					-- Challenge Mode (5.4.8 has no keystone level).
					if reactive then hex = REACTIVE_HEX.CM end
					out:SetFormattedText("|cff%sCM|r", hex)
					return
				end
				local letter = SCEN[diffID] or SUFFIX[diffID]
				if not letter then
					out:SetText("")
					return
				end
				if reactive then
					hex = REACTIVE_HEX[letter] or "ffffff"
				end
				local count
				if SUFFIX[diffID] then
					count = FLEX[diffID] and groupSize or maxPlayers
				end
				out:SetFormattedText("%s|cff%s%s|r", (count and count > 0) and count or "", hex, letter)
			end
			diffTextFrame:SetScript("OnEvent", function(self) self._update(self) end)
		end
		local fs = diffTextFrame._text
		P.SetFont(fs, p.diffTextSize or 12)
		local a = MAP_POS_ANCHORS[p.diffTextPosition or "topLeft"] or MAP_POS_ANCHORS.topLeft
		fs:ClearAllPoints()
		fs:SetPoint(a[1], mapAnchor, a[2], a[3] + (p.diffTextOffsetX or 0), a[4] + (p.diffTextOffsetY or 0))
		fs:Show()
		for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_DIFFICULTY_CHANGED",
			"GROUP_ROSTER_UPDATE", "INSTANCE_GROUP_SIZE_CHANGED", "UPDATE_INSTANCE_INFO" }) do
			pcall(diffTextFrame.RegisterEvent, diffTextFrame, ev)
		end
		diffTextFrame._update(diffTextFrame)
	elseif diffTextFrame then
		diffTextFrame:UnregisterAllEvents()
		diffTextFrame._text:Hide()
	end

	-- Saved zoom on the first apply of the session.
	if not GetFFD(minimap).active then
		local saved = p.savedZoom or 0
		if saved >= 0 and saved < minimap:GetZoomLevels() then
			minimap:SetZoom(saved)
		end
	end
	RestartZoomResetTimer()

	if not (_G.FarmHud and _G.FarmHud:IsShown()) then
		PlaceMinimap()
	end
	GetFFD(minimap).active = true
	minimap:SetAlpha(MapAlpha(p))

	ApplyQueueEye(p)
end
P.ApplyMinimap = function()
	ApplyMinimap()
end
EMM.ApplyMinimap = P.ApplyMinimap

ApplyAll = function()
	if not P.started then
		return
	end
	ApplyMinimap()
	EMM.UpdateVisibility()
end
EMM.ApplyAll = function()
	ApplyAll()
end

-- Full rebuild: forget the saved button art, then apply (Button
-- Backgrounds, ungrouping).
function EMM.FullRebuild()
	wipe(P.flyoutSavedRegions)
	ApplyAll()
end

-------------------------------------------------------------------------------
--  Micro menu (middle-click on the map). Panels whose micro button opens on
--  click go through secure "/click" buttons (no taint); the rest are plain.
-------------------------------------------------------------------------------
do
	local menuFrame
	local MENU_WIDTH, BUTTON_H, PADDING, DIVIDER_H = 160, 20, 6, 9

	local menuItems = {
		{ text = "Character", fn = function() ToggleCharacter("PaperDollFrame") end },
		{ text = "Spellbook", microButton = "SpellbookMicroButton" },
		{ text = "Talents", microButton = "TalentMicroButton" },
		{ divider = true },
		{ text = "Group Finder", microButton = "LFDMicroButton" },
		{ text = "Player vs. Player", fn = function() if TogglePVPUI then TogglePVPUI() end end },
		{ text = "Dungeon Journal", microButton = "EJMicroButton" },
		{ text = "Achievements", microButton = "AchievementMicroButton" },
		{ text = "Mounts & Pets", microButton = "CompanionsMicroButton" },
		{ text = "Quest Log", microButton = "QuestLogMicroButton" },
		{ divider = true },
		{ text = "Friends", fn = function() ToggleFriendsFrame(1) end },
		{ text = "Guild", microButton = "GuildMicroButton" },
		{ text = "Calendar", fn = function()
			if ToggleCalendar then
				ToggleCalendar()
			elseif Calendar_Toggle then
				Calendar_Toggle()
			end
		end },
		{ divider = true },
		{ text = "Game Menu", fn = function()
			if GameMenuFrame:IsShown() then
				HideUIPanel(GameMenuFrame)
			else
				ShowUIPanel(GameMenuFrame)
			end
		end },
		{ text = "Shop", microButton = "StoreMicroButton" },
		{ text = "Support", microButton = "HelpMicroButton" },
	}

	local function SetMenuVisible(visible)
		if not menuFrame or InCombatLockdown() then
			return
		end
		if visible then
			menuFrame:ClearAllPoints()
			local anchor = GetFFD(Minimap).layoutFrame or Minimap
			menuFrame:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -4, 0)
			menuFrame:Show()
		else
			menuFrame:Hide()
		end
	end

	local function Label(btn, text)
		local label = P.NewText(btn)
		P.SetPlainFont(label, 11)
		label:SetShadowOffset(1, -1)
		label:SetShadowColor(0, 0, 0, 1)
		label:SetPoint("LEFT", btn, "LEFT", 10, 0)
		label:SetTextColor(0.9, 0.9, 0.9)
		label:SetText(text)
		local hl = btn:CreateTexture(nil, "HIGHLIGHT")
		hl:SetAllPoints()
		hl:SetTexture(1, 1, 1, 0.08)
	end

	local function CreateMenuFrame()
		menuFrame = CreateFrame("Frame", "EllesmereUIMicroMenu", UIParent)
		menuFrame:SetFrameStrata("TOOLTIP")
		menuFrame:SetClampedToScreen(true)
		menuFrame:EnableMouse(true)
		P.Panel(menuFrame, 0.05, 0.05, 0.05, 0.97, 0.3, 0.3, 0.3, 1)
		menuFrame:Hide()
		-- Close on a click anywhere else.
		menuFrame:SetScript("OnUpdate", function(self)
			if (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")) and not self:IsMouseOver() then
				SetMenuVisible(false)
			end
		end)

		local y = -PADDING
		for _, item in ipairs(menuItems) do
			if item.divider then
				local div = menuFrame:CreateTexture(nil, "ARTWORK")
				div:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", 8, y - 4)
				div:SetPoint("TOPRIGHT", menuFrame, "TOPRIGHT", -8, y - 4)
				div:SetHeight(1)
				div:SetTexture(0.3, 0.3, 0.3, 0.6)
				y = y - DIVIDER_H
			else
				local btn
				if item.fn then
					btn = CreateFrame("Button", nil, menuFrame)
					local itemFn = item.fn
					btn:SetScript("OnClick", function()
						SetMenuVisible(false)
						itemFn()
					end)
				else
					btn = CreateFrame("Button", "EUI_MicroMenu_" .. item.text:gsub("[^%w]", ""), menuFrame, "SecureActionButtonTemplate")
					btn:SetAttribute("*type1", "macro")
					btn:SetAttribute("*macrotext1", "/click " .. item.microButton)
					btn:RegisterForClicks("AnyUp")
					btn:HookScript("OnClick", function() P.After(0, function() SetMenuVisible(false) end) end)
				end
				btn:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", 1, y)
				btn:SetPoint("TOPRIGHT", menuFrame, "TOPRIGHT", -1, y)
				btn:SetHeight(BUTTON_H)
				Label(btn, item.text)
				y = y - BUTTON_H
			end
		end
		menuFrame:SetSize(MENU_WIDTH, -y + PADDING)
	end

	function P.ToggleMicroMenu()
		if InCombatLockdown() then
			UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1.0, 0.3, 0.3, 1.0)
			return
		end
		if not menuFrame then
			CreateMenuFrame()
		end
		SetMenuVisible(not menuFrame:IsShown())
	end

	-- Combat starts: close it while that is still allowed.
	function P.CloseMicroMenu()
		if menuFrame and menuFrame:IsShown() then
			menuFrame:Hide()
		end
	end
end

-------------------------------------------------------------------------------
--  Unlock Mode (EllesmereUI core Unlock Mode, retail EBS_Minimap element)
-------------------------------------------------------------------------------
local function RegisterUnlock()
	if not ns.RegisterUnlockElements then
		return
	end
	ns:RegisterUnlockElements({
		ns.MakeUnlockElement({
			key = "EBS_Minimap",
			label = "Minimap",
			group = "Minimap",
			order = 500,
			noResize = true,
			noAnchorTo = true,
			getFrame = function() return Minimap end,
			getSize = function()
				local layout = GetFFD(Minimap).layoutFrame
				if layout then return layout:GetWidth(), layout:GetHeight() end
				return Minimap:GetWidth(), Minimap:GetHeight()
			end,
			isHidden = function()
				return not P.started or not GetFFD(Minimap).active
			end,
			savePos = function(_, point, relPoint, x, y)
				local p = DB()
				if not p then return end
				p.position = { point = point, relPoint = relPoint, x = x, y = y }
				if not ns._unlockActive and P.started and not InCombatLockdown() then
					PlaceMinimap()
				end
			end,
			loadPos = function()
				local p = DB()
				if not p or not P.started then return nil end
				return p.position
			end,
			clearPos = function()
				local p = DB()
				if p then p.position = nil end
			end,
			applyPos = function()
				if P.started and not InCombatLockdown() then
					PlaceMinimap()
				end
			end,
		}),
	}, "EllesmereUIMinimap")
end

-------------------------------------------------------------------------------
--  FarmHud: while its HUD owns the map, hide our border.
-------------------------------------------------------------------------------
do
	local f = CreateFrame("Frame")
	f:RegisterEvent("PLAYER_ENTERING_WORLD")
	f:SetScript("OnEvent", function(self)
		local hud = _G.FarmHud
		if not hud or not hud.HookScript then
			return
		end
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
		local function Borders(show)
			local d = GetFFD(Minimap)
			local a = show and 1 or 0
			if d.circBorder then d.circBorder:SetAlpha(a) end
			if d.borderHost then d.borderHost:SetAlpha(a) end
		end
		hud:HookScript("OnShow", function() Borders(false); EMM.ApplyMapAlpha() end)
		hud:HookScript("OnHide", function()
			Borders(true)
			EMM.ApplyMapAlpha()
			if P.started and not InCombatLockdown() then
				PlaceMinimap()
			end
		end)
	end)
end

-------------------------------------------------------------------------------
--  Start
-------------------------------------------------------------------------------
function EMM:IsRunning()
	return P.started and true or false
end

function EMM:IsDisabledByElvUI()
	return P.disabledByElvUI and true or false
end

function EMM:Reset()
	self.db:ResetProfile()
	EMM.FullRebuild()
	if P.RefreshFlyout then
		P.RefreshFlyout()
	end
end

local function Start()
	if P.started then
		return
	end
	if P.ElvUIMinimapActive() then
		ns.Print("ElvUI's minimap is on, so EllesmereUI Minimap stays off. Turn off ElvUI > Maps > Minimap > Enable to use it.")
		P.disabledByElvUI = true
		return
	end
	P.started = true
	P.OnAccent(function()
		if P.started and not InCombatLockdown() then
			ApplyMinimap()
		end
	end)
	ApplyAll()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == "EllesmereUIMinimap" then
			EMM:InitDB()
			ns.applyHooks = ns.applyHooks or {}
			tinsert(ns.applyHooks, function() ApplyAll() end)
			RegisterUnlock()
		elseif arg1 == "Blizzard_TimeManager" and P.started then
			P.After(0, function()
				if not InCombatLockdown() then
					ApplyMinimap()
				end
			end)
		end
	elseif event == "PLAYER_LOGIN" then
		Start()
	elseif event == "PLAYER_ENTERING_WORLD" then
		-- After loading screens Blizzard can re-place the queue eye and flags.
		P.After(0, function()
			if P.started then
				if InCombatLockdown() then
					QueueApplyAll()
				else
					ApplyAll()
				end
			end
		end)
	end
end)
