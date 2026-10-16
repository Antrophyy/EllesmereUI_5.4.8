-------------------------------------------------------------------------------
--  EUI_ResourceBars_CastBar.lua  (5.4.8 port of the EllesmereUI Resource Bars)
--
--  The player cast bar (spell icon, spark, spell / duration text, channel
--  tick marks, latency overlay, Gray When Out of Range, Always Show) and the
--  GCD bar, with the retail keys and behavior: a cast that ends, fails or is
--  interrupted goes straight back to idle (no end colors, like retail).
--  5.4.8 events carry (unit, spellName, rank, lineID, spellID); the cast is
--  matched by lineID. Blizzard's player cast bar is hidden while ours is on.
-------------------------------------------------------------------------------
local addonName, P = ...
local ns = P.ns
local ERB = P.ERB

local floor, max, min = math.floor, math.max, math.min
local format = string.format
local GetTime = GetTime

local SPARK_TEX = P.MEDIA .. "cast_spark"
local GCD_SPELL = 61304

local function Profile()
	return P.Profile()
end

-------------------------------------------------------------------------------
--  Channel ticks (5.4.8 spell IDs; channels keep their tick count with haste)
-------------------------------------------------------------------------------
local CHANNEL_TICK_DATA = {
	[15407] = { ticks = 3 },   -- Mind Flay
	[129197] = { ticks = 3 },  -- Mind Flay (Insanity)
	[48045] = { ticks = 5 },   -- Mind Sear
	[47540] = { ticks = 3 },   -- Penance
	[47757] = { ticks = 3 },   -- Penance (heal)
	[47758] = { ticks = 3 },   -- Penance (damage)
	[64843] = { ticks = 4 },   -- Divine Hymn
	[64901] = { ticks = 4 },   -- Hymn of Hope
	[689] = { ticks = 6 },     -- Drain Life
	[1120] = { ticks = 6 },    -- Drain Soul
	[103103] = { ticks = 4 },  -- Malefic Grasp
	[755] = { ticks = 6 },     -- Health Funnel
	[5143] = { ticks = 5 },    -- Arcane Missiles
	[7268] = { ticks = 5 },    -- Arcane Missiles (channel)
	[12051] = { ticks = 3 },   -- Evocation
	[740] = { ticks = 4 },     -- Tranquility
	[16914] = { ticks = 10 },  -- Hurricane
	[113656] = { ticks = 4 },  -- Fists of Fury
	[115175] = { ticks = 8 },  -- Soothing Mist
}
ERB.CHANNEL_TICK_DATA = CHANNEL_TICK_DATA

-------------------------------------------------------------------------------
--  Blizzard's player cast bar
-------------------------------------------------------------------------------
local suppressBlizz = false
local hookedBlizz = false
local function SuppressBlizzardCastBar(on)
	suppressBlizz = on and true or false
	local bar = CastingBarFrame
	if not bar then
		return
	end
	if not hookedBlizz then
		hookedBlizz = true
		bar:HookScript("OnShow", function(self)
			if suppressBlizz then
				self:Hide()
			end
		end)
	end
	if suppressBlizz then
		bar:Hide()
	end
end

-------------------------------------------------------------------------------
--  Cast bar frame
-------------------------------------------------------------------------------
local cb -- the cast bar frame

local function CastCfg()
	return Profile().castBar
end

local function IconFree(c)
	return c.showIcon ~= false and ((c.iconSize or 0) > 0 or (c.iconOffsetX or 0) ~= 0 or (c.iconOffsetY or 0) ~= 0)
end
ERB.CastIconFree = IconFree

local function IconW(c)
	if c.showIcon == false or IconFree(c) then
		return 0
	end
	return c.height or 20
end

local function BuildCastFrame()
	if cb then
		return cb
	end
	cb = CreateFrame("Frame", "ERB_CastBarFrame", UIParent)
	cb:SetSize(220, 20)
	cb.bg = cb:CreateTexture(nil, "BACKGROUND")
	cb.bg:SetAllPoints()
	cb.clip = CreateFrame("Frame", nil, cb)
	cb.bar = CreateFrame("StatusBar", "ERB_CastBar", cb.clip)
	cb.bar:SetAllPoints(cb.clip)
	cb.bar:SetMinMaxValues(0, 1)
	cb.bar:SetValue(0)
	cb.bar:SetStatusBarTexture(P.WHITE)
	cb.latency = cb.clip:CreateTexture(nil, "ARTWORK", nil, -1)
	cb.latencyFront = cb.bar:CreateTexture(nil, "OVERLAY", nil, 0)
	cb.latency:Hide()
	cb.latencyFront:Hide()
	cb.sparkFrame = CreateFrame("Frame", nil, cb.clip)
	cb.sparkFrame:SetAllPoints(cb.bar)
	cb.spark = cb.sparkFrame:CreateTexture(nil, "OVERLAY", nil, 1)
	cb.spark:SetTexture(SPARK_TEX)
	cb.spark:SetBlendMode("ADD")
	cb.iconFrame = CreateFrame("Frame", nil, cb)
	cb.icon = cb.iconFrame:CreateTexture(nil, "ARTWORK")
	cb.icon:SetAllPoints()
	cb.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	cb.iconBorder = P.CreateBorder(cb.iconFrame, 2)
	cb.border = P.CreateBorder(cb, 5)
	cb.divider = cb.border:CreateTexture(nil, "OVERLAY", nil, 7)
	cb.textFrame = CreateFrame("Frame", nil, cb)
	cb.textFrame:SetAllPoints(cb.bar)
	cb.nameText = P.NewText(cb.textFrame, 11)
	cb.timerText = P.NewText(cb.textFrame, 11)
	cb.ticks = {}
	cb.casting, cb.channeling = false, false
	ERB.castFrame = cb
	return cb
end

local function HideTicks()
	if not cb then
		return
	end
	for i = 1, #cb.ticks do
		cb.ticks[i]:Hide()
	end
end

local function ShowTicks(spellID)
	local c = CastCfg()
	HideTicks()
	cb.tickSpellID = spellID
	if not c.showChannelTicks then
		return
	end
	local data = spellID and CHANNEL_TICK_DATA[spellID]
	if not data or not (c.showTickMarks or c.showLastTick) then
		return
	end
	local n = data.ticks or 0
	if data.tickInterval then
		n = floor((cb.endTime - cb.startTime) / data.tickInterval)
	end
	if n < 2 then
		return
	end
	local bar = cb.bar
	local px = P.PixelFor(bar)
	local w, h = bar:GetWidth(), bar:GetHeight()
	local count = n - 1
	for i = 1, count do
		local isLast = i == count
		local t = cb.ticks[i]
		if not t then
			t = bar:CreateTexture(nil, "OVERLAY", nil, 3)
			cb.ticks[i] = t
		end
		if not c.showTickMarks and not isLast then
			t:Hide()
		else
			local gold = isLast and c.showLastTick
			if gold then
				t:SetTexture(c.lastTickR or 1, c.lastTickG or 0.82, c.lastTickB or 0, c.lastTickA or 0.95)
			else
				t:SetTexture(c.tickMarksR or 1, c.tickMarksG or 1, c.tickMarksB or 1, c.tickMarksA or 0.7)
			end
			t:ClearAllPoints()
			-- A channel drains right to left: tick i at elapsed i / n.
			local x = P.Snap(w * (1 - i / n), bar)
			t:SetSize((gold and 3 or 2) * px, h)
			t:SetPoint("CENTER", bar, "LEFT", x, 0)
			t:Show()
		end
	end
end

local function HideLatency()
	cb.latency:Hide()
	cb.latencyFront:Hide()
	cb.latencySuffix = nil
end

local function ShowLatency(kind)
	local c = CastCfg()
	HideLatency()
	if not c.latencyEnabled then
		return
	end
	local _, _, home, world = GetNetStats()
	local ms = (world and world > 0) and world or (home or 0)
	local sec = ms / 1000
	local dur = cb.endTime - cb.startTime
	local barW = cb.bar:GetWidth()
	if sec <= 0 or dur <= 0 or barW <= 0 then
		return
	end
	cb.latencySuffix = c.latencyShowText and (" (" .. floor(ms + 0.5) .. "ms)") or nil
	local tex = kind == "channel" and cb.latencyFront or cb.latency
	tex:ClearAllPoints()
	if kind == "channel" then
		tex:SetPoint("TOPLEFT", cb.clip, "TOPLEFT")
		tex:SetPoint("BOTTOMLEFT", cb.clip, "BOTTOMLEFT")
	else
		tex:SetPoint("TOPRIGHT", cb.clip, "TOPRIGHT")
		tex:SetPoint("BOTTOMRIGHT", cb.clip, "BOTTOMRIGHT")
	end
	tex:SetWidth(min(barW, max(1, barW * sec / dur)))
	tex:Show()
end

local function FillColor(c)
	if c.classColored then
		return ERB.ClassColor()
	end
	return c.fillR or 0.898, c.fillG or 0.729, c.fillB or 0.267
end

local function RestoreFill()
	local c = CastCfg()
	local r, g, b = FillColor(c)
	P.ApplyFill(cb.bar:GetStatusBarTexture(), c, r, g, b, (c.fillOpacity or 100) / 100)
	cb.rangeOut = nil
end

-- Background over the empty part only while casting with Fill Opacity < 100.
local function BgAnchor()
	local c = CastCfg()
	cb.bg:ClearAllPoints()
	if (cb.casting or cb.channeling) and (c.fillOpacity or 100) < 100 then
		cb.bg:SetPoint("TOPLEFT", cb.bar:GetStatusBarTexture(), "TOPRIGHT")
		cb.bg:SetPoint("BOTTOMRIGHT", cb.bar, "BOTTOMRIGHT")
	else
		cb.bg:SetAllPoints(cb)
	end
end

local function SetVisible(on)
	if on then
		cb:Show()
		cb:SetAlpha(1)
	else
		cb:SetAlpha(0)
	end
end

local function ShowIdle()
	if not cb then
		return
	end
	local c = CastCfg()
	cb.casting, cb.channeling = false, false
	cb.bar:SetValue(0)
	if cb.rangeOut then
		RestoreFill()
	end
	cb.nameText:SetText("")
	cb.timerText:SetText("")
	cb.iconFrame:Hide()
	cb.spark:Hide()
	HideTicks()
	HideLatency()
	BgAnchor()
	SetVisible(c.enabled and (c.alwaysShow or ERB.unlockActive))
	cb:SetScript("OnUpdate", nil)
end

local function TimerText(c, now)
	local remaining = cb.endTime - now
	if remaining <= 0 then
		return ""
	end
	if c.showTotalDuration then
		return format("%.1f", now - cb.startTime) .. " / " .. format("%.1f", cb.endTime - cb.startTime)
	end
	return format("%.1f", remaining) .. (cb.latencySuffix or "")
end

local function CastOnUpdate(self, elapsed)
	local c = CastCfg()
	local now = GetTime()
	if now > cb.endTime + 1 then
		ShowIdle()
		return
	end
	local dur = cb.endTime - cb.startTime
	local v
	if dur <= 0 then
		v = 0
	elseif cb.channeling then
		v = (cb.endTime - now) / dur
	else
		v = (now - cb.startTime) / dur
	end
	cb.bar:SetValue(max(0, min(1, v)))
	if c.showTimer ~= false then
		cb.timerText:SetText(TimerText(c, now))
	end
	if c.outOfRangeGray and cb.spellName then
		cb.rangeAt = (cb.rangeAt or 0) + elapsed
		if cb.rangeAt >= 0.2 then
			cb.rangeAt = 0
			local out = UnitExists("target") and IsSpellInRange(cb.spellName, "target") == 0
			if out and not cb.rangeOut then
				cb.rangeOut = true
				cb.bar:GetStatusBarTexture():SetVertexColor(0.4, 0.4, 0.4, (c.fillOpacity or 100) / 100)
			elseif not out and cb.rangeOut then
				RestoreFill()
			end
		end
	end
end

local function Activate()
	local c = CastCfg()
	cb.spark:SetShown(c.showSpark and true or false)
	BgAnchor()
	SetVisible(true)
	cb:SetScript("OnUpdate", CastOnUpdate)
end

local function SetIcon(texture)
	local c = CastCfg()
	if texture and c.showIcon ~= false then
		cb.icon:SetTexture(texture)
		cb.iconFrame:Show()
	else
		cb.iconFrame:Hide()
	end
end

local function OnCastStart()
	local c = CastCfg()
	if not c.enabled or not cb then
		return
	end
	local name, _, text, texture, startMS, endMS, _, castID = UnitCastingInfo("player")
	if not name then
		return
	end
	cb.casting, cb.channeling = true, false
	cb.castID = castID
	cb.startTime, cb.endTime = startMS / 1000, endMS / 1000
	cb.spellName = name
	cb.nameText:SetText(text or name)
	HideTicks()
	SetIcon(texture)
	ShowLatency("cast")
	cb.rangeAt = 1
	Activate()
	CastOnUpdate(cb, 0)
end

local function OnChannelStart(spellID)
	local c = CastCfg()
	if not c.enabled or not cb then
		return
	end
	local name, _, text, texture, startMS, endMS = UnitChannelInfo("player")
	if not name then
		return
	end
	cb.casting, cb.channeling = false, true
	cb.castID = nil
	cb.startTime, cb.endTime = startMS / 1000, endMS / 1000
	cb.spellName = name
	cb.nameText:SetText(text or name)
	SetIcon(texture)
	ShowTicks(spellID)
	ShowLatency("channel")
	cb.rangeAt = 1
	Activate()
	CastOnUpdate(cb, 0)
end

local function LayoutCastBar()
	local p = Profile()
	local c = p.castBar
	BuildCastFrame()
	SuppressBlizzardCastBar(c.enabled)
	if not c.enabled then
		cb:SetAlpha(0)
		cb:Hide()
		cb:SetScript("OnUpdate", nil)
		return
	end
	cb:Show()
	cb:SetFrameStrata(c.frameStrata or "MEDIUM")
	cb:SetFrameLevel(15)
	local w, h = c.width or 220, c.height or 20
	local iconW = IconW(c)
	cb:SetSize(w + iconW, h)
	-- Position: unlockPos, else the screen center + anchorX / anchorY.
	P.UnlockPlace(cb, "ERB_CastBar", function()
		cb:ClearAllPoints()
		local pos = c.unlockPos
		local shift = (ERB.shiftAbove or 0)
		if pos and pos.point then
			cb:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, P.Snap(pos.x or 0, cb), P.Snap((pos.y or 0) + shift, cb))
		else
			cb:SetPoint("CENTER", UIParent, "CENTER", c.anchorX or 0, (c.anchorY or -54) + shift)
		end
	end)
	local px = P.PixelFor(cb)
	local bs = c.borderSize or 0
	cb.border:Apply(bs, c.borderR, c.borderG, c.borderB, c.borderA)
	-- Icon.
	cb.iconFrame:ClearAllPoints()
	if c.showIcon == false then
		cb.iconFrame:Hide()
	elseif IconFree(c) then
		local size = ((c.iconSize or 0) > 0) and c.iconSize or h
		cb.iconFrame:SetSize(size, size)
		if c.iconOnRight then
			cb.iconFrame:SetPoint("LEFT", cb, "RIGHT", c.iconOffsetX or 0, c.iconOffsetY or 0)
		else
			cb.iconFrame:SetPoint("RIGHT", cb, "LEFT", c.iconOffsetX or 0, c.iconOffsetY or 0)
		end
		cb.iconBorder:Apply(bs > 0 and 1 or 0, c.borderR, c.borderG, c.borderB, c.borderA)
	else
		cb.iconFrame:SetSize(iconW, iconW)
		cb.iconFrame:SetPoint(c.iconOnRight and "TOPRIGHT" or "TOPLEFT", cb, c.iconOnRight and "TOPRIGHT" or "TOPLEFT")
		cb.iconBorder:Apply(0)
	end
	-- Divider between the icon and the bar.
	cb.divider:ClearAllPoints()
	if iconW > 0 and c.showIconDivider then
		local dw = max(px, floor(bs + 0.5) * px)
		cb.divider:SetTexture(c.borderR or 0, c.borderG or 0, c.borderB or 0, c.borderA or 1)
		if c.iconOnRight then
			cb.divider:SetPoint("TOPRIGHT", cb.iconFrame, "TOPLEFT")
			cb.divider:SetPoint("BOTTOMRIGHT", cb.iconFrame, "BOTTOMLEFT")
		else
			cb.divider:SetPoint("TOPLEFT", cb.iconFrame, "TOPRIGHT")
			cb.divider:SetPoint("BOTTOMLEFT", cb.iconFrame, "BOTTOMRIGHT")
		end
		cb.divider:SetWidth(dw)
		cb.divider:Show()
	else
		cb.divider:Hide()
	end
	-- Bar area (the side next to the icon sits flush).
	local inset = bs > 0 and px or 0
	local left = (iconW > 0 and not c.iconOnRight) and iconW or inset
	local right = (iconW > 0 and c.iconOnRight) and iconW or inset
	cb.clip:ClearAllPoints()
	cb.clip:SetPoint("TOPLEFT", cb, "TOPLEFT", left, -inset)
	cb.clip:SetPoint("BOTTOMRIGHT", cb, "BOTTOMRIGHT", -right, inset)
	cb.clip:SetFrameLevel(cb:GetFrameLevel() + 1)
	cb.bar:SetStatusBarTexture(P.TexturePath(c.texture))
	cb.bg:SetTexture(c.bgR or 0, c.bgG or 0, c.bgB or 0, c.bgA or 0.7)
	RestoreFill()
	-- Spark.
	if c.showSpark then
		cb.spark:SetSize(8, h)
		cb.spark:ClearAllPoints()
		cb.spark:SetPoint("CENTER", cb.bar:GetStatusBarTexture(), "RIGHT", 0, 0)
	end
	cb.spark:SetShown((c.showSpark and (cb.casting or cb.channeling)) and true or false)
	-- Latency colors.
	local lr, lg, lb, la = c.latencyR or 0.835, c.latencyG or 0.29, c.latencyB or 0.29, c.latencyA or 1
	cb.latency:SetTexture(lr, lg, lb, la)
	cb.latencyFront:SetTexture(lr, lg, lb, la)
	-- Text.
	cb.textFrame:SetFrameLevel(cb:GetFrameLevel() + 10)
	local barW = max(10, w - 2 * inset)
	local timerW = (c.timerSize or 11) * 2.2
	local durSide = c.timerSide or "right"
	local spellSide = c.spellTextSide or "left"
	local function Anchor(side, pushed)
		if side == "center" then
			return "CENTER", 0, "CENTER"
		elseif side == "left" then
			return "LEFT", 4 + (pushed and timerW or 0), "LEFT"
		end
		return "RIGHT", -4 - (pushed and timerW or 0), "RIGHT"
	end
	cb.timerText:ClearAllPoints()
	if c.showTimer ~= false then
		P.SetFont(cb.timerText, c.timerSize or 11)
		local pt, xb, j = Anchor(durSide, false)
		cb.timerText:SetPoint(pt, cb.bar, pt, xb + (c.timerX or 0), c.timerY or 0)
		cb.timerText:SetJustifyH(j)
		cb.timerText:SetTextColor(c.timerR or 1, c.timerG or 1, c.timerB or 1, c.timerA or 1)
		cb.timerText:Show()
	else
		cb.timerText:Hide()
	end
	cb.nameText:ClearAllPoints()
	if c.showSpellText ~= false then
		P.SetFont(cb.nameText, c.spellTextSize or 11)
		local pushed = c.showTimer ~= false and durSide == spellSide
		local pt, xb, j = Anchor(spellSide, pushed)
		cb.nameText:SetPoint(pt, cb.bar, pt, xb + (c.spellTextX or 0), c.spellTextY or 0)
		cb.nameText:SetJustifyH(j)
		local tw = barW - 8 - ((c.showTimer ~= false) and timerW * (spellSide == "center" and 2 or 1) or 0)
		cb.nameText:SetWidth(max(10, tw))
		cb.nameText:SetTextColor(c.spellTextR or 1, c.spellTextG or 1, c.spellTextB or 1, c.spellTextA or 1)
		cb.nameText:Show()
	else
		cb.nameText:Hide()
	end
	if cb.channeling then
		ShowTicks(cb.tickSpellID)
	else
		HideTicks()
	end
	if cb.casting or cb.channeling then
		Activate()
	else
		ShowIdle()
	end
end
ERB.LayoutCastBar = LayoutCastBar

-------------------------------------------------------------------------------
--  GCD bar
-------------------------------------------------------------------------------
local gb -- GCD bar frame
local gcdStart, gcdDur, gcdActualStart
local sentName, sentAt
local castKind = {}

local function GCfg()
	return Profile().gcdBar
end

local function BuildGCDFrame()
	if gb then
		return gb
	end
	gb = CreateFrame("Frame", "ERB_GCDBarFrame", UIParent)
	gb:SetSize(220, 12)
	gb.bg = gb:CreateTexture(nil, "BACKGROUND")
	gb.bg:SetAllPoints()
	gb.clip = CreateFrame("Frame", nil, gb)
	gb.bar = CreateFrame("StatusBar", "ERB_GCDBar", gb.clip)
	gb.bar:SetAllPoints(gb.clip)
	gb.bar:SetMinMaxValues(0, 1)
	gb.bar:SetValue(0)
	gb.spark = gb.bar:CreateTexture(nil, "OVERLAY", nil, 1)
	gb.spark:SetTexture(SPARK_TEX)
	gb.spark:SetBlendMode("ADD")
	gb.border = P.CreateBorder(gb, 5)
	ERB.gcdFrame = gb
	return gb
end

local function IdleFill()
	local g = GCfg()
	gb.bar:SetValue(g.idleShowFill == true and 1 or 0)
end

local function GCDVisible(on)
	if on then
		gb:Show()
		gb:SetAlpha(1)
	else
		gb:SetAlpha(0)
	end
end

local function UpdateGCDBar()
	local g = GCfg()
	if not gb or not g.enabled then
		return
	end
	if g.instanceOnly and not IsInInstance() and not ERB.unlockActive then
		IdleFill()
		GCDVisible(false)
		gb:SetScript("OnUpdate", nil)
		return
	end
	local now = GetTime()
	if gcdStart then
		local elapsed = now - gcdStart
		if elapsed < 0 or elapsed >= gcdDur then
			gcdStart, gcdDur = nil, nil
		end
	end
	if not gcdStart then
		IdleFill()
		GCDVisible(g.alwaysShow or ERB.unlockActive)
		gb:SetScript("OnUpdate", nil)
		return
	end
	local progress = (now - gcdStart) / gcdDur
	gb.bar:SetValue(g.depleteFill and (1 - progress) or progress)
	GCDVisible(true)
end

local function GCDOnUpdate()
	UpdateGCDBar()
end

local function CaptureGCD()
	local start, duration = GetSpellCooldown(GCD_SPELL)
	if not start or not duration or duration <= 0 or duration > 1.6 or start <= 0 then
		return
	end
	local now = GetTime()
	local elapsed = now - start
	if duration - elapsed <= 0.05 then
		return
	end
	if gcdActualStart and start <= gcdActualStart + 0.05 then
		return
	end
	gcdActualStart = start
	gcdStart = now
	gcdDur = max(duration - elapsed, 0.05)
	gb:SetScript("OnUpdate", GCDOnUpdate)
	UpdateGCDBar()
end

local function GCDActiveNow()
	local start, duration = GetSpellCooldown(GCD_SPELL)
	return start and duration and duration > 0 and duration <= 1.6 and (start + duration - GetTime()) > 0
end

local function OnGCDEvent(event, unit, name)
	local g = GCfg()
	if not g.enabled or not gb then
		return
	end
	if event == "SPELL_UPDATE_COOLDOWN" then
		local now = GetTime()
		if gb.stamp == now then
			return
		end
		gb.stamp = now
		if g.instantOnly then
			if not (sentName and castKind[sentName] == "instant" and sentAt and now - sentAt < 1)
				or UnitCastingInfo("player") or UnitChannelInfo("player") then
				return
			end
			sentName = nil
		end
		CaptureGCD()
	elseif event == "UNIT_SPELLCAST_SENT" then
		sentName, sentAt = name, GetTime()
	elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_STOP" then
		if not GCDActiveNow() then
			gcdStart, gcdDur, gcdActualStart = nil, nil, nil
			UpdateGCDBar()
		end
	elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
		if name then
			castKind[name] = "hard"
		end
		if not g.instantOnly then
			CaptureGCD()
		end
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		if g.instantOnly then
			if name and castKind[name] ~= "hard" and not UnitCastingInfo("player") and not UnitChannelInfo("player") then
				castKind[name] = "instant"
				CaptureGCD()
			end
		else
			CaptureGCD()
		end
	end
end

local function LayoutGCDBar()
	local g = GCfg()
	BuildGCDFrame()
	if not g.enabled then
		gb:SetAlpha(0)
		gb:Hide()
		gb:SetScript("OnUpdate", nil)
		gcdStart, gcdDur, gcdActualStart = nil, nil, nil
		return
	end
	gb:Show()
	gb:SetFrameStrata(g.frameStrata or "MEDIUM")
	gb:SetFrameLevel(15)
	local ori = g.orientation or "HORIZONTAL"
	local vert = ori == "VERTICAL_UP" or ori == "VERTICAL_DOWN"
	local w, h = g.width or 220, g.height or 12
	if vert then
		w, h = h, w
	end
	gb:SetSize(w, h)
	P.UnlockPlace(gb, "ERB_GCDBar", function()
		gb:ClearAllPoints()
		local pos = g.unlockPos
		local shift = ERB.shiftAbove or 0
		if pos and pos.point then
			gb:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, P.Snap(pos.x or 0, gb), P.Snap((pos.y or 0) + shift, gb))
		else
			gb:SetPoint("CENTER", UIParent, "CENTER", g.anchorX or 0, (g.anchorY or -78) + shift)
		end
	end)
	local bs = g.borderSize or 0
	gb.border:Apply(bs, g.borderR, g.borderG, g.borderB, g.borderA)
	local inset = bs > 0 and P.PixelFor(gb) or 0
	gb.clip:ClearAllPoints()
	gb.clip:SetPoint("TOPLEFT", gb, "TOPLEFT", inset, -inset)
	gb.clip:SetPoint("BOTTOMRIGHT", gb, "BOTTOMRIGHT", -inset, inset)
	gb.clip:SetFrameLevel(gb:GetFrameLevel() + 1)
	gb.bar:SetStatusBarTexture(P.TexturePath(g.texture))
	gb.bg:SetTexture(g.bgR or 0, g.bgG or 0, g.bgB or 0, g.bgA or 0.7)
	if ori == "VERTICAL_UP" then
		gb.bar:SetOrientation("VERTICAL")
		gb.bar:SetRotatesTexture(true)
		gb.bar:SetReverseFill(false)
	elseif ori == "VERTICAL_DOWN" then
		gb.bar:SetOrientation("VERTICAL")
		gb.bar:SetRotatesTexture(true)
		gb.bar:SetReverseFill(true)
	else
		gb.bar:SetOrientation("HORIZONTAL")
		gb.bar:SetRotatesTexture(false)
		gb.bar:SetReverseFill(ori == "HORIZONTAL_LEFT")
	end
	local r, gg, b = g.fillR or 0.267, g.fillG or 0.729, g.fillB or 0.898
	if g.classColored then
		r, gg, b = ERB.ClassColor()
	end
	P.ApplyFill(gb.bar:GetStatusBarTexture(), g, r, gg, b, g.fillA or 1)
	gb.spark:ClearAllPoints()
	if g.showSpark then
		local fill = gb.bar:GetStatusBarTexture()
		if ori == "VERTICAL_UP" then
			gb.spark:SetSize(w, 8)
			gb.spark:SetPoint("CENTER", fill, "TOP")
		elseif ori == "VERTICAL_DOWN" then
			gb.spark:SetSize(w, 8)
			gb.spark:SetPoint("CENTER", fill, "BOTTOM")
		elseif ori == "HORIZONTAL_LEFT" then
			gb.spark:SetSize(8, h)
			gb.spark:SetPoint("CENTER", fill, "LEFT")
		else
			gb.spark:SetSize(8, h)
			gb.spark:SetPoint("CENTER", fill, "RIGHT")
		end
		gb.spark:Show()
	else
		gb.spark:Hide()
	end
	UpdateGCDBar()
end
ERB.LayoutGCDBar = LayoutGCDBar

function ERB.UpdateCastVisibility()
	if cb and not (cb.casting or cb.channeling) then
		ShowIdle()
	end
	if gb then
		UpdateGCDBar()
	end
end

-------------------------------------------------------------------------------
--  Events
-------------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(self, event, unit, name, rank, lineID, spellID)
	if not ERB.db then
		return
	end
	if event == "PLAYER_ENTERING_WORLD" then
		if cb and UnitCastingInfo("player") then
			OnCastStart()
		elseif cb and UnitChannelInfo("player") then
			OnChannelStart(nil)
		elseif cb then
			ShowIdle()
		end
		if gb then UpdateGCDBar() end
		return
	end
	if event ~= "SPELL_UPDATE_COOLDOWN" and unit ~= "player" then
		return
	end
	OnGCDEvent(event, unit, name)
	if not cb or not CastCfg().enabled then
		return
	end
	if event == "UNIT_SPELLCAST_START" then
		OnCastStart()
	elseif event == "UNIT_SPELLCAST_DELAYED" then
		if cb.casting then
			local _, _, _, _, startMS, endMS = UnitCastingInfo("player")
			if startMS then
				cb.startTime, cb.endTime = startMS / 1000, endMS / 1000
			end
		end
	elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
		if cb.casting and (not cb.castID or not lineID or lineID == cb.castID) then
			ShowIdle()
		end
	elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
		OnChannelStart(spellID)
	elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
		if cb.channeling then
			local _, _, _, _, startMS, endMS = UnitChannelInfo("player")
			if startMS then
				cb.startTime, cb.endTime = startMS / 1000, endMS / 1000
				ShowTicks(cb.tickSpellID)
			end
		end
	elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		if cb.channeling and not UnitChannelInfo("player") then
			ShowIdle()
		end
	end
end)

function ERB.RegisterCastEvents()
	for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
		"UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START",
		"UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_SENT",
		"UNIT_SPELLCAST_SUCCEEDED", "SPELL_UPDATE_COOLDOWN", "PLAYER_ENTERING_WORLD" }) do
		pcall(events.RegisterEvent, events, e)
	end
end

P.OnApply(function()
	LayoutCastBar()
	LayoutGCDBar()
end)

function ERB.RegisterCastUnlock()
	if not ns.RegisterUnlockElements then
		return
	end
	local cast = P.UnlockElement("ERB_CastBar", "Cast Bar", 3, function() return cb end,
		function() return Profile().castBar end, function() return Profile().castBar.enabled end,
		function() return "width", "height", "HORIZONTAL" end)
	-- The bar's width setting leaves out the icon.
	cast.setWidth = function(_, w)
		local c = Profile().castBar
		c.width = math.max(floor(w - IconW(c) + 0.5), 20)
		ERB:ApplyAll()
	end
	local gcd = P.UnlockElement("ERB_GCDBar", "GCD Bar", 4, function() return gb end,
		function() return Profile().gcdBar end, function() return Profile().gcdBar.enabled end,
		function(g) return "width", "height", g.orientation end)
	ns:RegisterUnlockElements({ cast, gcd }, "EllesmereUIResourceBars")
end
