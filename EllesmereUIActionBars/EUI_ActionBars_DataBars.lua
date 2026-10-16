-------------------------------------------------------------------------------
--  EUI_ActionBars_DataBars.lua  (5.4.8 port)
--
--  The XP and Reputation bars (retail EUI_ActionBars_DataBars.lua and the core
--  of EUI_ActionBars_XPBar.lua): a 400 x 18 flat bar with a 1 px black border
--  on a dark background, the EllesmereUI colors (XP purple, rested blue with
--  the rested overlay; reputation by standing), the text in the module font,
--  the Visibility checklist, Click Through and a tooltip.
--  Not ported (retail-only or not in 5.4.8): House Favor bar, renown / paragon,
--  the XP bar art styles, dividers, text slots, quest XP overlay, XP per hour,
--  textured border styles.
-------------------------------------------------------------------------------
local addonName, P = ...
local EAB = P.EAB

local floor, max = math.floor, math.max
local format = string.format

local dataBarFrames = {}
P.dataBarFrames = dataBarFrames
EAB.dataBarFrames = dataBarFrames

EAB.XP_BAR_COLORS = {
	xpRested = { r = 0.00, g = 0.44, b = 0.87 },
	xpNoRest = { r = 0.60, g = 0.40, b = 0.85 },
	xpRestedBG = { r = 0.15, g = 0.30, b = 0.60 },
}
EAB.REP_COLORS = {
	[1] = { r = 0.80, g = 0.20, b = 0.20 },
	[2] = { r = 0.75, g = 0.30, b = 0.15 },
	[3] = { r = 0.75, g = 0.45, b = 0.15 },
	[4] = { r = 0.80, g = 0.70, b = 0.20 },
	[5] = { r = 0.30, g = 0.70, b = 0.25 },
	[6] = { r = 0.25, g = 0.65, b = 0.50 },
	[7] = { r = 0.25, g = 0.50, b = 0.75 },
	[8] = { r = 0.35, g = 0.30, b = 0.80 },
}

-- Bar texture: "none" (flat) or a LibSharedMedia status bar (retail
-- ResolveDataBarTexture; the suite's own bar textures live in the Unit
-- Frames addon on 5.4.8, so SharedMedia and flat are offered here).
function EAB.ResolveDataBarTexture(key)
	if key and key ~= "none" then
		local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
		local path = lsm and lsm:Fetch("statusbar", key, true)
		if path then
			return path
		end
	end
	return P.WHITE
end

-- Color mode: nil = by state, "accent" = UI accent, "custom" = stored color.
local function ResolveColor(s, r, g, b)
	local mode = s and s.colorMode
	if mode == "accent" and P.ns.ResolveAccent then
		local ar, ag, ab = P.ns.ResolveAccent()
		return ar or r, ag or g, ab or b
	elseif mode == "custom" then
		local c = s.customColor
		if c then
			return c.r or 1, c.g or 1, c.b or 1
		end
	end
	return r, g, b
end

local function AbbrevNumber(v)
	v = v or 0
	if v >= 1e6 then
		return format("%.1fM", v / 1e6)
	elseif v >= 1e3 then
		return format("%.1fK", v / 1e3)
	end
	return tostring(floor(v))
end

-------------------------------------------------------------------------------
--  Frame
-------------------------------------------------------------------------------
local function CreateDataBar(key, update)
	local holder = CreateFrame("Frame", "EllesmereEAB_" .. key, UIParent)
	holder:SetSize(400, 18)
	holder:SetFrameStrata("LOW")
	holder:SetClampedToScreen(true)

	local bg = holder:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture(0.06, 0.06, 0.08, 0.85)
	holder._bg = bg

	local bar = CreateFrame("StatusBar", nil, holder)
	bar:SetStatusBarTexture(P.WHITE)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	bar:GetStatusBarTexture():SetDrawLayer("ARTWORK", 4)
	holder._bar = bar

	local rested = CreateFrame("StatusBar", nil, holder)
	rested:SetStatusBarTexture(P.WHITE)
	rested:SetMinMaxValues(0, 1)
	rested:SetValue(0)
	rested:SetFrameLevel(bar:GetFrameLevel() - 1 >= 0 and bar:GetFrameLevel() - 1 or 0)
	rested:Hide()
	holder._restedBar = rested

	local borderHost = CreateFrame("Frame", nil, holder)
	borderHost:SetAllPoints(holder)
	borderHost:SetFrameLevel(bar:GetFrameLevel() + 2)
	holder._edges = P.CreateEdges(borderHost, holder, "OVERLAY", 0)

	local textHost = CreateFrame("Frame", nil, holder)
	textHost:SetAllPoints(holder)
	textHost:SetFrameLevel(bar:GetFrameLevel() + 3)
	local text = textHost:CreateFontString(nil, "OVERLAY")
	text:SetTextColor(1, 1, 1, 1)
	holder._text = text
	holder._textHost = textHost
	holder._update = update
	holder:EnableMouse(true)

	dataBarFrames[key] = holder
	return holder
end

local function LayoutDataBar(key)
	local frame = dataBarFrames[key]
	local s = P.BarSettings(key)
	if not frame or not s then
		return
	end
	local w, h = s.width or 400, s.height or 18
	frame:SetSize(w, h)
	P.PlaceFrame(frame, key)
	local px = P.PixelFor(frame)
	frame._bg:ClearAllPoints()
	frame._bg:SetPoint("TOPLEFT", frame, "TOPLEFT", px, -px)
	frame._bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -px, px)
	for _, b in ipairs({ frame._bar, frame._restedBar }) do
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", frame, "TOPLEFT", px, -px)
		b:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -px, px)
		b:SetStatusBarTexture(EAB.ResolveDataBarTexture(s.barTexture))
		b:SetOrientation(s.orientation == "VERTICAL" and "VERTICAL" or "HORIZONTAL")
	end
	frame._bar:GetStatusBarTexture():SetDrawLayer("ARTWORK", 4)
	local c = s.borderColor or { r = 0, g = 0, b = 0, a = 1 }
	local entry = EAB.BORDER_THICKNESS[s.customBorder and s.borderThickness or "thin"] or EAB.BORDER_THICKNESS.thin
	P.LayoutEdges(frame._edges, entry.regular * px, s.customBorder and c.r or 0, s.customBorder and c.g or 0,
		s.customBorder and c.b or 0, s.customBorder and (c.a or 1) or 1)

	P.SetModuleFont(frame._text, s.textSize or 9)
	frame._text:ClearAllPoints()
	local anchor = s.textAnchor
	local ox, oy = s.textOffsetX or 0, s.textOffsetY or 0
	local ap, padX = "CENTER", 0
	if anchor == "top" then ap = "TOP"
	elseif anchor == "bottom" then ap = "BOTTOM"
	elseif anchor == "left" then ap, padX = "LEFT", 4
	elseif anchor == "right" then ap, padX = "RIGHT", -4 end
	frame._text:SetPoint(ap, frame._textHost, ap, ox + padX, oy)
	frame:EnableMouse(not s.clickThrough)
end

-- Shown when the checklist allows it and the bar has something to show.
local function FinishShow(key, frame, s, has)
	local p = P.Profile()
	local ok = has and not p.useBlizzardDataBars and P.VisibilityAllows(s)
	frame:SetShown(ok and true or false)
end

-------------------------------------------------------------------------------
--  XP bar
-------------------------------------------------------------------------------
local function XPText(s, cur, mx, rested, level)
	local t = s.showLevel and format("%s %d - ", LEVEL or "Level", level) or ""
	if s.showRawValues then
		t = t .. format("%s / %s", AbbrevNumber(cur), AbbrevNumber(mx))
		if s.showPercent then
			t = t .. format(" (%.1f%%)", cur / mx * 100)
		end
	else
		t = t .. format("%.1f%%", cur / mx * 100)
	end
	if s.showRested ~= false and rested > 0 then
		t = t .. format(" (Rested: %s)", s.showRawValues and AbbrevNumber(rested) or format("%.1f%%", rested / mx * 100))
	end
	return t
end

local function UpdateXPBar()
	local frame = dataBarFrames.XPBar
	local s = P.BarSettings("XPBar")
	if not frame or not s then
		return
	end
	local level = UnitLevel("player")
	local maxLevel = MAX_PLAYER_LEVEL_TABLE and MAX_PLAYER_LEVEL_TABLE[GetExpansionLevel()] or 90
	local disabled = (IsXPUserDisabled and IsXPUserDisabled()) or level >= maxLevel
	if disabled then
		FinishShow("XPBar", frame, s, false)
		return
	end
	local cur, mx = UnitXP("player"), UnitXPMax("player")
	if not mx or mx <= 0 then mx = 1 end
	local rested = GetXPExhaustion() or 0
	local C = EAB.XP_BAR_COLORS
	local fill = rested > 0 and C.xpRested or C.xpNoRest
	frame._bar:SetMinMaxValues(0, mx)
	frame._bar:SetValue(cur)
	frame._bar:SetStatusBarColor(ResolveColor(s, fill.r, fill.g, fill.b))
	if rested > 0 and s.showRested ~= false then
		local rc = s.restedColor or C.xpRestedBG
		frame._restedBar:SetMinMaxValues(0, mx)
		frame._restedBar:SetValue(math.min(mx, cur + rested))
		frame._restedBar:SetStatusBarColor(rc.r, rc.g, rc.b, rc.a or 1)
		frame._restedBar:Show()
	else
		frame._restedBar:Hide()
	end
	frame._text:SetText(XPText(s, cur, mx, rested, level))
	if frame._text:GetStringWidth() > frame:GetWidth() - 4 then
		frame._text:SetText(format("%.0f%%", cur / mx * 100))
	end
	frame._text:SetShown(s.hideText ~= true)
	FinishShow("XPBar", frame, s, true)
end

-------------------------------------------------------------------------------
--  Reputation bar
-------------------------------------------------------------------------------
local function UpdateRepBar()
	local frame = dataBarFrames.RepBar
	local s = P.BarSettings("RepBar")
	if not frame or not s then
		return
	end
	local name, reaction, minV, maxV, value, factionID = GetWatchedFactionInfo()
	if not name then
		FinishShow("RepBar", frame, s, false)
		return
	end
	reaction = reaction or 4
	local standing = _G["FACTION_STANDING_LABEL" .. reaction] or ""
	-- Friendships (5.4.8 GetFriendshipReputation) override the standing.
	if factionID and GetFriendshipReputation then
		local friendID, friendRep, _, _, _, _, friendTextLevel, friendThreshold, nextFriendThreshold = GetFriendshipReputation(factionID)
		if friendID then
			standing = friendTextLevel or standing
			if nextFriendThreshold then
				minV, maxV, value = friendThreshold, nextFriendThreshold, friendRep
			else
				minV, maxV, value = 0, 1, 1
			end
		end
	end
	local maximum = (maxV or 1) - (minV or 0)
	local current = (value or 0) - (minV or 0)
	if maximum <= 0 then
		-- capped (Exalted / max friendship): nothing to show (retail)
		FinishShow("RepBar", frame, s, false)
		return
	end
	local c = EAB.REP_COLORS[reaction] or EAB.REP_COLORS[4]
	frame._bar:SetMinMaxValues(0, maximum)
	frame._bar:SetValue(current)
	frame._bar:SetStatusBarColor(ResolveColor(s, c.r, c.g, c.b))
	local pct = current / maximum * 100
	frame._tipName, frame._tipStanding, frame._tipCurrent, frame._tipMaximum = name, standing, current, maximum
	frame._text:SetText(format("%s: %.0f%% [%s]", name, pct, standing))
	if frame._text:GetStringWidth() > frame:GetWidth() - 4 then
		frame._text:SetText(format("%.0f%%", pct))
	end
	frame._text:SetShown(s.hideText ~= true)
	FinishShow("RepBar", frame, s, true)
end

-------------------------------------------------------------------------------
--  Setup / apply
-------------------------------------------------------------------------------
local function SetupDataBars()
	if dataBarFrames.XPBar then
		return
	end
	local xp = CreateDataBar("XPBar", UpdateXPBar)
	xp:SetScript("OnEnter", function(self)
		local s = P.BarSettings("XPBar")
		if s and s.clickThrough then return end
		local cur, mx = UnitXP("player"), UnitXPMax("player")
		if not mx or mx <= 0 then return end
		local rested = GetXPExhaustion() or 0
		GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
		GameTooltip:ClearLines()
		GameTooltip:AddLine(format("%s %d", LEVEL or "Level", UnitLevel("player")), 1, 1, 1)
		GameTooltip:AddDoubleLine("XP", format("%s / %s (%.1f%%)", AbbrevNumber(cur), AbbrevNumber(mx), cur / mx * 100), 1, 1, 1, 1, 1, 1)
		GameTooltip:AddDoubleLine("Remaining", AbbrevNumber(mx - cur), 1, 1, 1, 1, 1, 1)
		if rested > 0 then
			GameTooltip:AddDoubleLine("Rested", format("%s (%.1f%%)", AbbrevNumber(rested), rested / mx * 100), 1, 1, 1, 0, 0.44, 0.87)
		end
		GameTooltip:Show()
	end)
	xp:SetScript("OnLeave", function() GameTooltip:Hide() end)

	local rep = CreateDataBar("RepBar", UpdateRepBar)
	rep:SetScript("OnEnter", function(self)
		local s = P.BarSettings("RepBar")
		if s and s.clickThrough then return end
		if not self._tipName then return end
		GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
		GameTooltip:ClearLines()
		GameTooltip:AddLine(self._tipName, 1, 1, 1)
		GameTooltip:AddDoubleLine("Standing", self._tipStanding or "", 1, 1, 1, 1, 1, 1)
		local maximum = self._tipMaximum or 1
		GameTooltip:AddDoubleLine("Reputation", format("%s / %s (%.1f%%)", AbbrevNumber(self._tipCurrent or 0), AbbrevNumber(maximum),
			(self._tipCurrent or 0) / maximum * 100), 1, 1, 1, 1, 1, 1)
		GameTooltip:Show()
	end)
	rep:SetScript("OnLeave", function() GameTooltip:Hide() end)

	P.AttachHover("XPBar", xp)
	P.AttachHover("RepBar", rep)

	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION", "PLAYER_ENTERING_WORLD",
		"DISABLE_XP_GAIN", "ENABLE_XP_GAIN", "UPDATE_FACTION", "QUEST_FINISHED" }) do
		ev:RegisterEvent(e)
	end
	ev:SetScript("OnEvent", function()
		UpdateXPBar()
		UpdateRepBar()
	end)
end

function P.UpdateDataBars()
	UpdateXPBar()
	UpdateRepBar()
end

function P.ApplyDataBars()
	SetupDataBars()
	for _, key in ipairs({ "XPBar", "RepBar" }) do
		local s = P.BarSettings(key)
		if s then
			EAB.VisibilityCompat.Normalize(s)
		end
		LayoutDataBar(key)
	end
	P.UpdateDataBars()
end
