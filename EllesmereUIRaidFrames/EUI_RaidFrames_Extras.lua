-------------------------------------------------------------------------------
--  EUI_RaidFrames_Extras.lua  (5.4.8 port of the retail Raid Frames extras)
--
--  Ports, from retail EUI_RaidFrames_BossFrames / _ExtraFrames / _PetFrames /
--  _PartyTargets / _Portrait / _Extras.lua:
--    Friendly Boss Frames  (RF.FB_*)  boss1-5, friendly bosses only
--    Extra Frames          (RF.XF_*)  duplicates of tanks / chosen players
--    Pet Frames            (RF.PF_*)  pet header + Beside Owner pets
--    Party Targets         (RF.PT_*)  a target frame beside each party frame
--    Party Portrait        (RF.PortraitInit, RF.RF_PtReserve)
--    Healer Mana display   (RF.HM_*)  one text row per group healer
--
--  5.4.8 differences (why):
--    * No SecureHandlerAttributeTemplate slot controller: each boss button
--      shows through its own "[@bossN,help]" state driver (combat safe), so
--      a hostile boss1 leaves its slot empty instead of collapsing.
--    * Beside Owner pets and party targets use the secure "useparent-unit" +
--      "unitsuffix" attributes (SecureButton_GetUnit maps party1pet to
--      partypet1) instead of the retail party header unit snippet.
--    * No masks / SetClipsChildren: portrait shapes draw as squares, the
--      Inside portrait is not clipped.
--    * No secret values, no UnitPowerPercent / curves: plain math.
-------------------------------------------------------------------------------
local addonName, RF = ...
local ns = EllesmereUI
local ERF = RF.ERF

local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local pairs, ipairs, type, tostring, tonumber = pairs, ipairs, type, tostring, tonumber
local format = string.format

local function P()
	return RF.Profile()
end

-- Calls into the other engine files: an error there must not stop ours.
local function SafeCall(fn, ...)
	if not fn then
		return
	end
	local ok, err = pcall(fn, ...)
	if not ok then
		geterrorhandler()(err)
	end
end

-- One physical pixel grid snap in UIParent units (retail PixelSnap).
local function Snap(v)
	if RF.Snap then
		return RF.Snap(v or 0, UIParent)
	end
	return floor((v or 0) + 0.5)
end

local DEF_BG = { r = 17 / 255, g = 17 / 255, b = 17 / 255 }
local DEF_GREEN = { r = 23 / 255, g = 172 / 255, b = 49 / 255 }

-- Unit of a secure button, as SecureButton_GetUnit reads it (own "unit", or
-- the parent's with useparent-unit, plus "unitsuffix"; party1pet -> partypet1).
local function UnitOf(b)
	if not b then
		return nil
	end
	local u = b:GetAttribute("unit")
	if not u and b:GetAttribute("useparent-unit") then
		local p = b:GetParent()
		u = p and p:GetAttribute("unit")
	end
	if not u then
		return nil
	end
	local suffix = b:GetAttribute("unitsuffix")
	if suffix then
		u = u .. suffix
		u = u:gsub("^([^%d]+)([%d]+)[pP][eE][tT]$", "%1pet%2")
		if u == "playerpet" then
			u = "pet"
		end
	end
	return u
end
RF.EX_UnitOf = UnitOf

-- The party / raid mode of the frames on screen (party frames also run in
-- small raids when the headers file says so).
local function PartyMode()
	if IsInRaid() then
		if RF._PartyInRaid then
			return RF._PartyInRaid() and true or false
		end
		return (RF.PartyShown and RF.PartyShown()) and true or false
	end
	return true
end

-- Party growth (retail ns._PartyGrowth): horizontal or stacked, flipped.
local function PartyGrowth(p)
	local flip = p.partyFlipGrowth == true
	if p.partyHorizontal then
		return flip and "LEFT" or "RIGHT"
	end
	return flip and "UP" or "DOWN"
end
RF.EX_PartyGrowth = PartyGrowth

-- Every party unit button of the headers file (not the previews).
local function PartyButtons()
	local list = {}
	local own = RF.GetPartyButtons and RF.GetPartyButtons()
	if own and #own > 0 then
		for i = 1, #own do
			list[i] = own[i]
		end
		return list
	end
	if RF.ForEachButton then
		RF.ForEachButton(function(btn)
			if btn.rfKind == "party" and not btn.rfPreview and not btn.rfSettings then
				list[#list + 1] = btn
			end
		end)
	end
	return list
end

-- Faction bar colors (5.4.8 FrameXML FACTION_BAR_COLORS) and the class
-- circles' coordinates (FrameXML CLASS_ICON_TCOORDS), local copies.
local FACTION = {
	[1] = { 0.8, 0.3, 0.22 }, [2] = { 0.8, 0.3, 0.22 }, [3] = { 0.75, 0.27, 0 }, [4] = { 0.9, 0.7, 0 },
	[5] = { 0, 0.6, 0.1 }, [6] = { 0, 0.6, 0.1 }, [7] = { 0, 0.6, 0.1 }, [8] = { 0, 0.6, 0.1 },
}
local CLASS_TC = {
	WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.49609375, 0, 0.25 },
	ROGUE = { 0.49609375, 0.7421875, 0, 0.25 }, DRUID = { 0.7421875, 0.98828125, 0, 0.25 },
	HUNTER = { 0, 0.25, 0.25, 0.5 }, SHAMAN = { 0.25, 0.49609375, 0.25, 0.5 },
	PRIEST = { 0.49609375, 0.7421875, 0.25, 0.5 }, WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 },
	PALADIN = { 0, 0.25, 0.5, 0.75 }, DEATHKNIGHT = { 0.25, 0.49609375, 0.5, 0.75 },
	MONK = { 0.49609375, 0.7421875, 0.5, 0.75 },
}
local CLASS_CIRCLES = "Interface\\TargetingFrame\\UI-Classes-Circles"

-------------------------------------------------------------------------------
--  Shared visuals (retail FB.BuildVisuals / StyleVisuals / StyleBorder /
--  ApplyBorderColor / PaintHealth / PaintName): background, health bar, name
--  and health text, border with hover and target states. Used by the boss
--  frames, the pets and the party target frames (all kept on btn.ex, so
--  they never collide with the Button file's btn.rf).
-------------------------------------------------------------------------------
local V = { hov = setmetatable({}, { __mode = "k" }), tgt = setmetatable({}, { __mode = "k" }) }
RF._EXV = V

-- Settings view of a button (b.exSource), the raid view by default.
V.Source = function(b)
	local f = b.exSource
	return (f and f()) or RF._scaledProfile
end

V.AnchorText = function(fs, host, pos, ox, oy)
	fs:ClearAllPoints()
	ox, oy = ox or 0, oy or 0
	if pos == "topleft" then
		fs:SetPoint("TOPLEFT", host, "TOPLEFT", 2 + ox, -2 + oy)
		fs:SetJustifyH("LEFT")
	elseif pos == "top" then
		fs:SetPoint("TOP", host, "TOP", ox, -2 + oy)
		fs:SetJustifyH("CENTER")
	elseif pos == "topright" then
		fs:SetPoint("TOPRIGHT", host, "TOPRIGHT", -2 + ox, -2 + oy)
		fs:SetJustifyH("RIGHT")
	elseif pos == "left" then
		fs:SetPoint("LEFT", host, "LEFT", 2 + ox, oy)
		fs:SetJustifyH("LEFT")
	elseif pos == "right" then
		fs:SetPoint("RIGHT", host, "RIGHT", -2 + ox, oy)
		fs:SetJustifyH("RIGHT")
	elseif pos == "bottomleft" then
		fs:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 2 + ox, 2 + oy)
		fs:SetJustifyH("LEFT")
	elseif pos == "bottom" then
		fs:SetPoint("BOTTOM", host, "BOTTOM", ox, 2 + oy)
		fs:SetJustifyH("CENTER")
	elseif pos == "bottomright" then
		fs:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -2 + ox, 2 + oy)
		fs:SetJustifyH("RIGHT")
	else
		fs:SetPoint("CENTER", host, "CENTER", ox, oy)
		fs:SetJustifyH("CENTER")
	end
end

V.Build = function(b)
	local ex = {}
	b.ex = ex
	local bg = b:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(b)
	bg:SetTexture(DEF_BG.r, DEF_BG.g, DEF_BG.b, 0.5)
	ex.bg = bg
	local health = CreateFrame("StatusBar", nil, b)
	health:SetFrameLevel(min(b:GetFrameLevel() + 2, 127))
	health:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	health:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
	health:SetHeight(10)
	health:SetStatusBarTexture(RF.WHITE)
	health:SetMinMaxValues(0, 100)
	health:SetValue(100)
	ex.health = health
	local carrier = CreateFrame("Frame", nil, b)
	carrier:SetAllPoints(health)
	carrier:SetFrameLevel(min(b:GetFrameLevel() + RF.LVL_TEXT, 127))
	ex.carrier = carrier
	ex.name = RF.NewText(carrier, 10)
	ex.htext = RF.NewText(carrier, 9)
	ex.border = RF.CreateBorder(b, 8)
	b:HookScript("OnEnter", function(self)
		V.hov[self] = true
		V.BorderColor(self)
	end)
	b:HookScript("OnLeave", function(self)
		V.hov[self] = nil
		V.BorderColor(self)
	end)
	return ex
end

-- Size-dependent part (health height, text widths).
V.Size = function(b, w, h)
	local ex = b.ex
	ex.health:SetHeight(max(1, h))
	ex.name:SetWidth(max(1, w - 4))
	ex.htext:SetWidth(max(1, w * 0.75))
end

V.Style = function(b, s, w, h)
	local ex = b.ex
	if not ex then
		return
	end
	local bgc = s.customBgColor or DEF_BG
	ex.bg:SetTexture(bgc.r, bgc.g, bgc.b, (s.bgDarkness or 50) / 100)
	ex.health:SetStatusBarTexture(RF.TexturePath(s.healthBarTexture))
	local ft = ex.health:GetStatusBarTexture()
	if ft then
		ft:SetHorizTile(false)
	end
	ex.health:SetOrientation(s.healthVerticalFill and "VERTICAL" or "HORIZONTAL")
	ex.inv = s.healthInvertFill and true or nil
	ex.opacity = (s.healthBarOpacity or 100) / 100
	V.Size(b, w, h)
	RF.SetFont(ex.name, s.nameSize or 10)
	RF.SetFont(ex.htext, s.healthTextSize or 9)
	if not ex.nameFixed then
		local pos = s.namePosition or "center"
		if pos == "none" then
			ex.name:Hide()
		else
			ex.name:Show()
			V.AnchorText(ex.name, ex.health, pos, s.nameOffsetX, s.nameOffsetY)
		end
		V.AnchorText(ex.htext, ex.health, s.healthTextPosition or "center", s.healthTextOffsetX, s.healthTextOffsetY)
	end
	V.BorderColor(b)
end

-- Border: target, else hover, else the frame border (raid border settings).
V.BorderColor = function(b)
	local ex = b.ex
	if not ex then
		return
	end
	local s = V.Source(b)
	local size, c, a
	if V.tgt[b] and s.targetBorderEnabled ~= false then
		size, c, a = s.targetBorderSize or 1, s.targetBorderColor, s.targetBorderAlpha
	elseif V.hov[b] and s.hoverBorderEnabled ~= false then
		size, c, a = s.hoverBorderSize or 1, s.hoverBorderColor, s.hoverBorderAlpha
	else
		size, c, a = s.borderSize or 1, s.borderColor, s.borderAlpha
	end
	ex.border:Apply(size, c and c.r or 0, c and c.g or 0, c and c.b or 0, a or 1)
end

-- True when the button's "is your target" state flipped.
V.ReadTarget = function(b, unit)
	local t = (unit and UnitExists(unit) and UnitIsUnit(unit, "target")) and true or nil
	if V.tgt[b] == t then
		return false
	end
	V.tgt[b] = t
	return true
end

-- UTF-8 safe name cap (nameMaxLength, 0 = off).
V.Cap = function(name, n)
	if not name or not n or n <= 0 then
		return name
	end
	local out, count = "", 0
	for ch in name:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		count = count + 1
		if count > n then
			break
		end
		out = out .. ch
	end
	return out
end

V.ClassRGB = function(unit)
	if unit and UnitIsPlayer(unit) then
		local _, ct = UnitClass(unit)
		if ct then
			return RF.ClassColor(ct)
		end
	end
	return nil
end

V.TextColor = function(mode, custom, unit)
	if mode == "class" then
		local r, g, b = V.ClassRGB(unit)
		if r then
			return r, g, b
		end
		return 1, 1, 1
	elseif mode == "accent" then
		return RF.Accent()
	end
	return custom and custom.r or 1, custom and custom.g or 1, custom and custom.b or 1
end

V.PaintName = function(b, unit, s)
	local ex = b.ex
	local name = UnitName(unit)
	if name and RF.FormatName then
		name = RF.FormatName(name, s)
	end
	ex.name:SetText(V.Cap(name, s.nameMaxLength) or "")
	ex.name:SetTextColor(V.TextColor(s.nameColorMode, s.nameCustomColor, unit))
end

V.HealthPct = function(unit)
	local cur, mx = UnitHealth(unit) or 0, UnitHealthMax(unit) or 0
	if mx <= 0 then
		return 0, cur
	end
	return cur / mx * 100, cur
end

V.PaintHealth = function(b, unit, s)
	local ex = b.ex
	local pct, cur = V.HealthPct(unit)
	ex.health:SetValue(ex.inv and (100 - pct) or pct)
	if ex.nameFixed then
		return
	end
	local mode = s.healthTextMode or "none"
	if mode == "none" or UnitIsDeadOrGhost(unit) then
		ex.htext:SetText("")
		return
	end
	if mode == "percent" then
		ex.htext:SetText(format("%d%%", floor(pct + 0.5)))
	else
		ex.htext:SetText(RF.Abbrev(cur))
	end
	local r, g, bb = V.TextColor(s.healthTextColorMode, s.healthTextCustomColor, unit)
	ex.htext:SetTextColor(r, g, bb, 0.9)
end

-- Fixed health color (Friendly Boss / Pet Health Color).
V.PaintFixed = function(b, c)
	local ex = b.ex
	c = c or DEF_GREEN
	ex.health:SetStatusBarColor(c.r, c.g, c.b, ex.opacity or 1)
end

-- Full paint of a fixed-color button (boss, pets).
V.Update = function(b)
	local ex = b.ex
	if not ex then
		return
	end
	local unit = UnitOf(b)
	local flipped = V.ReadTarget(b, unit)
	if not (unit and UnitExists(unit)) then
		if flipped then
			V.BorderColor(b)
		end
		return
	end
	local s = V.Source(b)
	V.PaintFixed(b, b.exColor and b.exColor())
	V.PaintName(b, unit, s)
	V.PaintHealth(b, unit, s)
	V.BorderColor(b)
end

-- Secure click setup shared by our own buttons (Click Casting overrides).
V.Secure = function(b)
	b:RegisterForClicks("AnyUp")
	b:SetAttribute("*type1", "target")
	b:SetAttribute("*type2", "togglemenu")
end

-- One anchor point, left alone when it already sits exactly there.
V.Pin = function(c, point, rel, relPoint, x, y)
	if c:GetNumPoints() == 1 then
		local p, r, rp, px, py = c:GetPoint(1)
		if p == point and r == rel and rp == relPoint and px == x and py == y then
			return
		end
	end
	c:ClearAllPoints()
	c:SetPoint(point, rel, relPoint, x, y)
end

-- Free Move corner (retail FB.CornerPin): the corner a grid grows from and,
-- with a saved rect r, that corner's offset from UIParent's center.
V.CornerPin = function(hDir, vDir, r)
	local corner
	if vDir == "UP" then
		corner = (hDir == "LEFT") and "BOTTOMRIGHT" or "BOTTOMLEFT"
	else
		corner = (hDir == "LEFT") and "TOPRIGHT" or "TOPLEFT"
	end
	if not r then
		return corner
	end
	return corner, (hDir == "LEFT") and r.right or r.left, (vDir == "UP") and r.bottom or r.top
end

V.SaveMoverRect = function(mover, set)
	if not set then
		return
	end
	local ux, uy = UIParent:GetCenter()
	local l, bt, mw, mh = mover:GetRect()
	if not (ux and l) then
		return
	end
	set.freeRect = { left = l - ux, right = l + mw - ux, bottom = bt - uy, top = bt + mh - uy }
end

-------------------------------------------------------------------------------
--  Friendly Boss Frames (retail EUI_RaidFrames_BossFrames.lua)
-------------------------------------------------------------------------------
local FB = { buttons = {} }
RF._FB = FB

FB.Settings = function()
	local p = P()
	return p and p.friendlyBoss
end

FB.ShouldBeActive = function()
	local fb = FB.Settings()
	if not fb then
		return false
	end
	if fb.display == "always" then
		return true
	end
	if fb.display == "healers" then
		return RF.PlayerSpecRole() == "HEALER"
	end
	return false
end

-- Range: a known heal per healer class (boss units are not group members,
-- so UnitInRange does not work on them). 5.4.8 spells; IsSpellInRange
-- takes the spell name here.
FB.RANGE_HEAL = {
	PRIEST = 2061,   -- Flash Heal
	PALADIN = 19750, -- Flash of Light
	SHAMAN = 8004,   -- Healing Surge
	DRUID = 8936,    -- Regrowth
	MONK = 115175,   -- Soothing Mist (no Vivify on 5.4.8)
}

FB.ApplyRange = function(b)
	if not FB.rangeName then
		b:SetAlpha(1)
		return
	end
	local unit = UnitOf(b)
	local r = unit and UnitExists(unit) and IsSpellInRange(FB.rangeName, unit)
	if r == 0 then
		local s = RF._scaledProfile
		b:SetAlpha(s.oorAlpha or 0.4)
	else
		b:SetAlpha(1)
	end
end

FB.RangeTick = function()
	for _, b in ipairs(FB.buttons) do
		if b:IsVisible() then
			FB.ApplyRange(b)
		end
	end
end

FB.UpdateRangeTicker = function()
	local any = false
	for _, b in ipairs(FB.buttons) do
		if b:IsShown() then
			any = true
			break
		end
	end
	local want = FB.rangeName and any
	if want and not FB.rangeTicker then
		FB.rangeTicker = RF.NewTicker(0.4, FB.RangeTick)
	elseif not want and FB.rangeTicker then
		FB.rangeTicker:Cancel()
		FB.rangeTicker = nil
	end
end

FB.Update = function(b)
	V.Update(b)
end

FB.EnsureBuilt = function()
	if FB.built then
		return
	end
	FB.built = true
	local container = CreateFrame("Frame", "ERFFriendlyBossContainer", UIParent)
	container:SetSize(10, 10)
	container:SetPoint("CENTER", UIParent, "CENTER", 100, 0)
	container:Hide()
	FB.container = container
	for i = 1, 5 do
		local b = CreateFrame("Button", "ERFFriendlyBoss" .. i, container, "SecureUnitButtonTemplate")
		b.rfKind = "boss"
		b:SetAttribute("unit", "boss" .. i)
		V.Secure(b)
		b:Hide()
		V.Build(b)
		b.exColor = function()
			local f = FB.Settings()
			return f and f.healthColor
		end
		b:HookScript("OnShow", function(self)
			FB.Update(self)
			FB.ApplyRange(self)
			FB.UpdateRangeTicker()
		end)
		b:HookScript("OnHide", function()
			FB.UpdateRangeTicker()
		end)
		if RF.CC_SetupButton then
			SafeCall(RF.CC_SetupButton, b)
		end
		FB.buttons[i] = b
	end
	local ev = CreateFrame("Frame")
	ev:RegisterEvent("UNIT_HEALTH")
	ev:RegisterEvent("UNIT_MAXHEALTH")
	ev:RegisterEvent("UNIT_NAME_UPDATE")
	ev:SetScript("OnEvent", function(_, _, unit)
		local n = unit and tonumber(unit:match("^boss(%d)$"))
		local b = n and FB.buttons[n]
		if b and b:IsVisible() then
			FB.Update(b)
		end
	end)
	FB.unitEvents = ev
end

-- Size, stacking and look of the five buttons (raid frame size + Extra
-- Width/Height). OOC only.
FB.ApplyStyle = function()
	if not FB.built then
		return
	end
	local s = RF._scaledProfile
	local fb = FB.Settings()
	local w = Snap(max(10, (s.frameWidth or 125) + ((fb and fb.extraWidth) or 0)))
	local h = Snap(max(10, (s.frameHeight or 60) + ((fb and fb.extraHeight) or 0)))
	local sp = s.cellSpacing or -1
	local grow
	if fb and fb.position == "free" then
		grow = fb.freeHorizontal and "RIGHT" or "DOWN"
	else
		grow = s.unitGrowth or "DOWN"
	end
	local stepW, stepH = 0, 0
	if grow == "DOWN" or grow == "UP" then
		FB.container:SetSize(w, h * 5 + sp * 4)
		stepH = h + sp
	else
		FB.container:SetSize(w * 5 + sp * 4, h)
		stepW = w + sp
	end
	for i, b in ipairs(FB.buttons) do
		b:SetSize(w, h)
		b:ClearAllPoints()
		local off = i - 1
		if grow == "UP" then
			b:SetPoint("BOTTOMLEFT", FB.container, "BOTTOMLEFT", 0, off * stepH)
		elseif grow == "LEFT" then
			b:SetPoint("TOPRIGHT", FB.container, "TOPRIGHT", -off * stepW, 0)
		elseif grow == "RIGHT" then
			b:SetPoint("TOPLEFT", FB.container, "TOPLEFT", off * stepW, 0)
		else
			b:SetPoint("TOPLEFT", FB.container, "TOPLEFT", 0, -off * stepH)
		end
		V.Style(b, s, w, h)
	end
end

-- Attach beside the raid container along the group growth axis (as an
-- extra group: before the first / after the last).
local function RaidAttach(c, anchor, s, before, gap)
	local grow = s.groupGrowth or "RIGHT"
	if grow == "RIGHT" or grow == "DOWNRIGHT" then
		if before then
			V.Pin(c, "TOPRIGHT", anchor, "TOPLEFT", -gap, 0)
		else
			V.Pin(c, "TOPLEFT", anchor, "TOPRIGHT", gap, 0)
		end
	elseif grow == "LEFT" then
		if before then
			V.Pin(c, "TOPLEFT", anchor, "TOPRIGHT", gap, 0)
		else
			V.Pin(c, "TOPRIGHT", anchor, "TOPLEFT", -gap, 0)
		end
	elseif grow == "DOWN" then
		if before then
			V.Pin(c, "BOTTOMLEFT", anchor, "TOPLEFT", 0, gap)
		else
			V.Pin(c, "TOPLEFT", anchor, "BOTTOMLEFT", 0, -gap)
		end
	else
		if before then
			V.Pin(c, "TOPLEFT", anchor, "BOTTOMLEFT", 0, -gap)
		else
			V.Pin(c, "BOTTOMLEFT", anchor, "TOPLEFT", 0, gap)
		end
	end
end

-- Attach beside the party frames, across the axis they stack on.
local function PartyAttach(c, anchor, s, before, gap)
	local grow = PartyGrowth(s)
	if grow == "UP" then
		if before then
			V.Pin(c, "BOTTOMRIGHT", anchor, "BOTTOMLEFT", -gap, 0)
		else
			V.Pin(c, "BOTTOMLEFT", anchor, "BOTTOMRIGHT", gap, 0)
		end
	elseif grow == "LEFT" then
		if before then
			V.Pin(c, "BOTTOMRIGHT", anchor, "TOPRIGHT", 0, gap)
		else
			V.Pin(c, "TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -gap)
		end
	elseif s.partyHorizontal then
		if before then
			V.Pin(c, "BOTTOMLEFT", anchor, "TOPLEFT", 0, gap)
		else
			V.Pin(c, "TOPLEFT", anchor, "BOTTOMLEFT", 0, -gap)
		end
	else
		if before then
			V.Pin(c, "TOPRIGHT", anchor, "TOPLEFT", -gap, 0)
		else
			V.Pin(c, "TOPLEFT", anchor, "TOPRIGHT", gap, 0)
		end
	end
end

local function Shown(f)
	return f and f:IsShown() and f or nil
end

-- Position a group (FB, XF or PF) per its position setting. OOC only.
FB.Anchor = function(owner)
	owner = owner or FB
	if not owner.built or not owner.container then
		return
	end
	if InCombatLockdown() then
		owner.anchorDirty = true
		return
	end
	local s = P()
	local fb = owner.Settings()
	if not (s and fb) then
		return
	end
	local c = owner.container
	local pos = fb.position
	if pos ~= "free" and pos ~= "owner" then
		local before = pos == "left"
		local gap = s.groupSpacing or -1
		local party = PartyMode()
		local anchor
		-- Chain: raid -> extra -> boss -> pets on the same side.
		if owner == FB and not party then
			local xs = RF._XF.Settings()
			if xs and xs.position == pos and RF._XF.built and Shown(RF._XF.container) then
				anchor = RF._XF.container
			end
		end
		if not anchor and owner.ChainAnchor then
			anchor = owner.ChainAnchor(fb)
		end
		if anchor then
			if party then
				PartyAttach(c, anchor, s, before, gap)
			else
				RaidAttach(c, anchor, s, before, gap)
			end
			return
		end
		if party then
			if (owner == FB and fb.showInDungeons == true) or owner.attachParty then
				local pc = Shown(RF.GetPartyContainer and RF.GetPartyContainer())
				if pc then
					gap = gap + RF.PT_Reserve(s.partyHorizontal, before,
						(owner == FB) and RF.PF_OwnerReserve(s.partyHorizontal, before) or nil)
					PartyAttach(c, pc, s, before, gap)
					return
				end
			end
		else
			local rc = Shown(RF.GetRaidContainer and RF.GetRaidContainer())
			if rc then
				RaidAttach(c, rc, s, before, gap)
				return
			end
		end
	end
	if owner.FreeAnchor and owner.FreeAnchor(c, fb) then
		return
	end
	local p = fb.freePos or {}
	V.Pin(c, "CENTER", UIParent, "CENTER", p.x or 100, p.y or 0)
end

function RF.FB_ReAnchor()
	if RF.PF_ReAnchor then
		RF.PF_ReAnchor()
	end
	if FB.built then
		FB.Anchor()
	end
end

function RF.FB_Apply()
	local fb = FB.Settings()
	if not fb then
		return
	end
	if InCombatLockdown() then
		FB.applyDirty = true
		return
	end
	if not FB.ShouldBeActive() then
		if FB.built then
			for _, b in ipairs(FB.buttons) do
				UnregisterStateDriver(b, "visibility")
				b:Hide()
			end
			FB.drivers = nil
			UnregisterStateDriver(FB.container, "visibility")
			FB.groupCond = nil
			FB.container:Hide()
		end
		if FB.mover then
			FB.mover:Hide()
		end
		FB.rangeName = nil
		FB.UpdateRangeTicker()
		return
	end
	FB.EnsureBuilt()
	FB.ApplyStyle()
	FB.Anchor()
	-- Group gate: raid only, or raid + party with Show in Dungeons on.
	local cond = (fb.showInDungeons == true) and "[@raid1,exists] show; [@party1,exists] show; hide"
		or "[@raid1,exists] show; hide"
	if FB.groupCond ~= cond then
		RegisterStateDriver(FB.container, "visibility", cond)
		FB.groupCond = cond
	end
	if not FB.drivers then
		for i, b in ipairs(FB.buttons) do
			RegisterStateDriver(b, "visibility", "[@boss" .. i .. ",help] show; hide")
		end
		FB.drivers = true
	end
	for _, b in ipairs(FB.buttons) do
		if b:IsVisible() then
			FB.Update(b)
		end
	end
	-- Range dimming: healer specs only.
	local _, pClass = UnitClass("player")
	local id = (RF.PlayerSpecRole() == "HEALER") and FB.RANGE_HEAL[pClass] or nil
	FB.rangeName = id and GetSpellInfo(id) or nil
	FB.RangeTick()
	FB.UpdateRangeTicker()
end

function RF.FB_IsMoverShown()
	return FB.mover and FB.mover:IsShown() or false
end

-- Free Move drag overlay (retail FB.SetMoverShown), shared by FB/XF/PF.
FB.SetMoverShown = function(owner, show, frameName, labelText)
	if not show then
		if owner.mover then
			owner.mover:Hide()
		end
		return
	end
	local moverSettings = owner.MoverSettings or owner.Settings
	local fb = moverSettings()
	if not fb or fb.position ~= "free" then
		return
	end
	if InCombatLockdown() then
		return
	end
	if owner.MoverPrep then
		owner.MoverPrep()
	else
		owner.EnsureBuilt()
		if owner.Layout then
			owner.Layout()
		else
			FB.ApplyStyle()
		end
		FB.Anchor(owner)
	end
	if not owner.mover then
		local m = CreateFrame("Frame", frameName, UIParent)
		m:SetFrameStrata("TOOLTIP")
		m:SetClampedToScreen(true)
		m:SetMovable(true)
		m:EnableMouse(true)
		m:RegisterForDrag("LeftButton")
		local mbg = m:CreateTexture(nil, "BACKGROUND")
		mbg:SetAllPoints()
		mbg:SetTexture(0.103, 0.095, 0.088, 0.95)
		local ar, ag, ab = RF.Accent()
		local bd = RF.CreateBorder(m, 1)
		bd:Apply(1, ar, ag, ab, 0.6)
		local lbl = RF.NewText(m, 11)
		lbl:SetFont(RF.FontPath(), 11, "")
		lbl:SetTextColor(1, 1, 1, 0.75)
		lbl:SetPoint("CENTER", m, "CENTER")
		lbl:SetText(labelText)
		m:SetScript("OnDragStart", function(self)
			self:StartMoving()
		end)
		m:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing()
			local cx, cy = self:GetCenter()
			local ux, uy = UIParent:GetCenter()
			if cx and ux then
				local set = (owner.MoverSettings or owner.Settings)()
				if set then
					set.freePos = { x = floor(cx - ux + 0.5), y = floor(cy - uy + 0.5) }
				end
			end
			if owner.SaveFreeRect then
				owner.SaveFreeRect(self)
			end
			FB.Anchor(owner)
		end)
		owner.mover = m
		if ns._mainFrame then
			ns._mainFrame:HookScript("OnHide", function()
				m:Hide()
			end)
		end
	end
	owner.mover:ClearAllPoints()
	local oset = moverSettings() or {}
	if owner.PlaceMover then
		owner.PlaceMover(owner.mover, oset)
	else
		owner.mover:SetSize(max(owner.container:GetWidth(), 20), max(owner.container:GetHeight(), 20))
		if owner.FreeAnchor and oset.freeRect then
			owner.mover:SetPoint("CENTER", owner.container, "CENTER")
		else
			local p = oset.freePos or {}
			owner.mover:SetPoint("CENTER", UIParent, "CENTER", p.x or 100, p.y or 0)
		end
	end
	owner.mover:Show()
end

function RF.FB_SetMoverShown(show)
	FB.SetMoverShown(FB, show, "ERFFriendlyBossMover", "Friendly Boss Frames")
end

-------------------------------------------------------------------------------
--  Extra Frames (retail EUI_RaidFrames_ExtraFrames.lua): raid-only 1:1
--  duplicates of the tanks (Show Tanks) and hotkey-picked players. Each
--  duplicate is a full unit button (rfKind "extra", the Button file's
--  StyleButton pipeline, read through RF._scaledExtraProxy).
-------------------------------------------------------------------------------
local XF = { buttons = {} }
RF._XF = XF
XF.CAP = 20

XF.Settings = function()
	local p = P()
	return p and p.extraFrames
end

XF.ShouldBeActive = function()
	local set = XF.Settings()
	if not set then
		return false
	end
	return set.showTanks or #(set.players or {}) > 0
end

XF.GrowInfo = function(set, s)
	local grow, wrap
	if set and set.position == "free" then
		grow = set.growDirection or (set.freeHorizontal and "RIGHT" or "DOWN")
		wrap = set.wrapDirection
	else
		grow = (s and s.unitGrowth) or "DOWN"
		wrap = (s and s.groupGrowth) or "RIGHT"
		if wrap == "DOWNRIGHT" then
			wrap = "RIGHT"
		end
		if set and set.position == "left" then
			wrap = (wrap == "RIGHT" and "LEFT") or (wrap == "LEFT" and "RIGHT") or (wrap == "DOWN" and "UP") or "DOWN"
		end
	end
	local horizontal = (grow == "LEFT" or grow == "RIGHT")
	if horizontal then
		if wrap ~= "UP" and wrap ~= "DOWN" then
			wrap = "DOWN"
		end
	else
		if wrap ~= "LEFT" and wrap ~= "RIGHT" then
			wrap = "RIGHT"
		end
	end
	return grow, wrap, horizontal
end

XF.FreeAnchor = function(c, set)
	local r = set and set.freeRect
	if not r then
		return false
	end
	local grow, wrap, horizontal = XF.GrowInfo(set, P())
	local corner, x, y = V.CornerPin(horizontal and grow or wrap, horizontal and wrap or grow, r)
	V.Pin(c, corner, UIParent, "CENTER", x, y)
	return true
end

XF.SaveFreeRect = function(mover)
	V.SaveMoverRect(mover, XF.Settings())
end

-- Raid units to duplicate: tanks in roster order (Show Tanks), then the
-- manually added names that are in the raid (GetRaidRosterInfo format).
XF.ResolveUnits = function()
	local set = XF.Settings()
	local units = {}
	if not set or not IsInRaid() then
		return units
	end
	local seen = {}
	local n = GetNumGroupMembers() or 0
	if set.showTanks then
		for i = 1, n do
			if #units >= XF.CAP then
				break
			end
			local u = "raid" .. i
			local name = GetRaidRosterInfo(i)
			if name and not seen[name] and RF.UnitRole(u) == "TANK"
				and not (set.excludeSelfTank and UnitIsUnit(u, "player")) then
				seen[name] = true
				units[#units + 1] = u
			end
		end
	end
	for _, mname in ipairs(set.players or {}) do
		if #units >= XF.CAP then
			break
		end
		if not seen[mname] then
			for i = 1, n do
				if (GetRaidRosterInfo(i)) == mname then
					seen[mname] = true
					units[#units + 1] = "raid" .. i
					break
				end
			end
		end
	end
	return units
end

-- Geometry: size (raid size + Extra Width/Height), the extra ratio the
-- extra settings view scales indicators by, and the grid. OOC only.
XF.Layout = function()
	if not XF.built then
		return
	end
	local s = RF._scaledProfile
	local set = XF.Settings()
	local aw = Snap(RF._activeSizeW or s.frameWidth or 72)
	local ah = Snap(RF._activeSizeH or s.frameHeight or 46)
	local w = Snap(max(10, aw + ((set and set.extraWidth) or 0)))
	local h = Snap(max(10, ah + ((set and set.extraHeight) or 0)))
	local ratio = 1
	if aw > 0 and ah > 0 and (not set or set.autoResizeIndicators ~= false) then
		ratio = max(min(min(w / aw, h / ah), 1.3), 0.7)
	end
	RF._xfExtraRatio = ratio
	RF._xfBmScale = ratio
	local sp = s.cellSpacing or 2
	local grow, wrap, horizontal = XF.GrowInfo(set, s)
	local count = XF.activeCount or 0
	if count < 1 then
		count = ((set and set.showTanks) and 2 or 0) + ((set and set.players) and #set.players or 0)
		if count < 1 then
			count = 1
		end
		if count > XF.CAP then
			count = XF.CAP
		end
	end
	local per
	if set and set.position == "free" then
		local wa = tonumber(set.wrapAfter) or 0
		per = (wa > 0) and wa or count
		if per > count then
			per = count
		end
	else
		per = 5
	end
	local lines = math.ceil(count / per)
	local runW, runH = w * per + sp * (per - 1), h * per + sp * (per - 1)
	if horizontal then
		XF.container:SetSize(runW, h * lines + sp * (lines - 1))
	else
		XF.container:SetSize(w * lines + sp * (lines - 1), runH)
	end
	local stepW, stepH = w + sp, h + sp
	for i, b in ipairs(XF.buttons) do
		b:SetSize(w, h)
		b:ClearAllPoints()
		local off = i - 1
		local line = floor(off / per)
		local pos = off - line * per
		local hUnits, vUnits, hDir, vDir
		if horizontal then
			hUnits, vUnits, hDir, vDir = pos, line, grow, wrap
		else
			hUnits, vUnits, hDir, vDir = line, pos, wrap, grow
		end
		local corner = (vDir == "UP" and "BOTTOM" or "TOP") .. (hDir == "LEFT" and "RIGHT" or "LEFT")
		b:SetPoint(corner, XF.container, corner, (hDir == "LEFT" and -hUnits or hUnits) * stepW,
			(vDir == "UP" and vUnits or -vUnits) * stepH)
		if RF.RelayoutButton then
			SafeCall(RF.RelayoutButton, b)
		elseif b.ex then
			V.Style(b, RF._scaledExtraProxy, w, h)
		end
	end
end

-- Grow-on-demand construction (5 first, more as the selection needs). OOC.
XF.EnsureBuilt = function(count)
	if not XF.built then
		XF.built = true
		local container = CreateFrame("Frame", "ERFExtraFramesContainer", UIParent)
		container:SetSize(10, 10)
		container:SetPoint("CENTER", UIParent, "CENTER", 100, -120)
		container:Hide()
		XF.container = container
	end
	local want = max(count or 5, 5)
	for i = #XF.buttons + 1, want do
		local b = CreateFrame("Button", "ERFExtraFrame" .. i, XF.container, "SecureUnitButtonTemplate")
		b.rfKind = "extra"
		V.Secure(b)
		b:Hide()
		if RF.StyleButton then
			SafeCall(RF.StyleButton, b)
		else
			-- Button file missing: plain visuals so the duplicate still shows.
			V.Build(b)
			b.exSource = function()
				return RF._scaledExtraProxy
			end
			b:HookScript("OnShow", V.Update)
			b:HookScript("OnAttributeChanged", function(self, name)
				if name == "unit" and self:IsVisible() then
					V.Update(self)
				end
			end)
			if RF.CC_SetupButton then
				SafeCall(RF.CC_SetupButton, b)
			end
		end
		XF.buttons[i] = b
	end
end

function RF.XF_Apply()
	local set = XF.Settings()
	if not set then
		return
	end
	if InCombatLockdown() then
		XF.applyDirty = true
		return
	end
	local units = XF.ShouldBeActive() and XF.ResolveUnits() or {}
	XF.activeCount = #units
	if #units == 0 then
		if XF.built then
			for _, b in ipairs(XF.buttons) do
				b:SetAttribute("unit", nil)
				b:Hide()
			end
			XF.container:Hide()
		end
		if XF.mover then
			XF.mover:Hide()
		end
		RF._xfExtraRatio = 1
		RF._xfBmScale = 1
		FB.Anchor()
		return
	end
	XF.EnsureBuilt(#units)
	XF.Layout()
	XF.container:Show()
	FB.Anchor(XF)
	for i = 1, #XF.buttons do
		local b = XF.buttons[i]
		local unit = units[i]
		if unit then
			if b:GetAttribute("unit") ~= unit then
				b:SetAttribute("unit", unit)
			elseif RF.UpdateButton then
				SafeCall(RF.UpdateButton, b)
			end
			b:Show()
		else
			b:SetAttribute("unit", nil)
			b:Hide()
		end
	end
	FB.Anchor()
end

function RF.XF_IsMoverShown()
	return XF.mover and XF.mover:IsShown() or false
end

function RF.XF_SetMoverShown(show)
	FB.SetMoverShown(XF, show, "ERFExtraFramesMover", "Extra Frames")
end

-- Hotkey toggle (retail: a pure Lua override binding on a hidden button, no
-- Bindings.xml). The key is EllesmereUIDB.extraFramesKey (set by the
-- options, RF.XF_SetKey). The click toggles the hovered raid member.
local xfBind = CreateFrame("Button", "ERFExtraFramesBindBtn", UIParent)
xfBind:Hide()

XF.HoveredUnit = function()
	local unit
	if RF.ForEachButton then
		RF.ForEachButton(function(btn)
			if not unit and (btn.rfKind == "raid" or btn.rfKind == "extra") and btn:IsVisible() and btn:IsMouseOver() then
				unit = btn:GetAttribute("unit")
			end
		end)
	end
	if not unit then
		for _, b in ipairs(XF.buttons) do
			if b:IsVisible() and b:IsMouseOver() then
				unit = b:GetAttribute("unit")
				break
			end
		end
	end
	return unit
end

function RF.XF_ToggleHovered()
	if not P() or not IsInRaid() then
		return
	end
	local set = XF.Settings()
	if not set then
		return
	end
	local unit = XF.HoveredUnit()
	if not unit then
		return
	end
	local idx = tonumber(unit:match("^raid(%d+)$"))
	local name = idx and GetRaidRosterInfo(idx)
	if not name then
		return
	end
	local players = set.players or {}
	set.players = players
	for k, v in ipairs(players) do
		if v == name then
			table.remove(players, k)
			RF.XF_Apply()
			return
		end
	end
	if set.showTanks and RF.UnitRole(unit) == "TANK" and not (set.excludeSelfTank and UnitIsUnit(unit, "player")) then
		return
	end
	if #XF.ResolveUnits() >= XF.CAP then
		return
	end
	players[#players + 1] = name
	RF.XF_Apply()
end

xfBind:SetScript("OnClick", function()
	RF.XF_ToggleHovered()
end)

-- Bind (or clear with nil) the toggle key. OOC only (override bindings).
function RF.XF_SetKey(key)
	if EllesmereUIDB then
		EllesmereUIDB.extraFramesKey = key
	end
	if InCombatLockdown() then
		XF.keyDirty = true
		return
	end
	ClearOverrideBindings(xfBind)
	if key and key ~= "" then
		SetOverrideBindingClick(xfBind, true, key, "ERFExtraFramesBindBtn")
	end
end

-------------------------------------------------------------------------------
--  Pet Frames (retail EUI_RaidFrames_PetFrames.lua): party and raid pets in
--  one SecureGroupPetHeaderTemplate header beside the groups, or (Party
--  tab, Beside Owner) one pet button beside each party frame. Health, name,
--  range, hover/target borders and click casting on the shared visuals.
-------------------------------------------------------------------------------
local PF = { buttons = {}, ownerButtons = {}, ownerOf = setmetatable({}, { __mode = "k" }), attachParty = true }
RF._PF = PF
PF.MAX = 40

PF.Raw = function()
	local p = P()
	return p and p.petFrames
end

-- Party / Raid tab views: position, extra size, Free Move spot per tab
-- (party_/raid_ keys), falling back to the shared key until set.
PF.TAB_KEY = {
	party = { position = "party_position", extraWidth = "party_extraWidth", extraHeight = "party_extraHeight",
		freePos = "party_freePos", freeRect = "party_freeRect" },
	raid = { position = "raid_position", extraWidth = "raid_extraWidth", extraHeight = "raid_extraHeight",
		freePos = "raid_freePos", freeRect = "raid_freeRect" },
}
PF.views = {}
PF.View = function(ctx)
	local v = PF.views[ctx]
	if v then
		return v
	end
	local keys = PF.TAB_KEY[ctx]
	v = setmetatable({}, {
		__index = function(_, k)
			local raw = PF.Raw()
			if not raw then
				return nil
			end
			local tk = keys[k]
			if tk then
				local val = raw[tk]
				if val ~= nil then
					return val
				end
			end
			return raw[k]
		end,
		__newindex = function(_, k, val)
			local raw = PF.Raw()
			if raw then
				raw[keys[k] or k] = val
			end
		end,
	})
	PF.views[ctx] = v
	return v
end
RF.PF_View = PF.View

PF.Ctx = function()
	return PartyMode() and "party" or "raid"
end

PF.Settings = function()
	return PF.Raw() and PF.View(PF.Ctx())
end

PF.OwnerChosen = function()
	local raw = PF.Raw()
	return (raw and raw.party == true and PartyMode() and PF.View("party").position == "owner") or false
end

PF.Wanted = function()
	local raw = PF.Raw()
	if not raw then
		return false
	end
	if PartyMode() then
		return raw.party == true and PF.View("party").position ~= "owner"
	end
	return raw.raid == true
end

PF.StyleSource = function()
	if PF.styleCtx == "party" then
		return RF._scaledPartyProxy
	end
	return RF._scaledProfile
end

PF.ColorOf = function()
	local raw = PF.Raw()
	return raw and raw.healthColor
end

PF.Refresh = function(b)
	V.Update(b)
	PF.ApplyRange(b)
end

-- Range: UnitInRange covers group pets; your own pet stays at full alpha.
PF.ApplyRange = function(b)
	local unit = UnitOf(b)
	if not unit or not UnitExists(unit) or UnitIsUnit(unit, "pet") then
		b:SetAlpha(1)
		return
	end
	local s = V.Source(b)
	b:SetAlpha(UnitInRange(unit) and 1 or (s.oorAlpha or 0.4))
end

PF.EachShown = function(fn)
	for _, b in ipairs(PF.buttons) do
		if b:IsVisible() then
			fn(b)
		end
	end
	for _, b in ipairs(PF.ownerButtons) do
		if b:IsVisible() then
			fn(b)
		end
	end
end

-- Our side of one pet button (header child or Beside Owner pet).
PF.StyleButton = function(b, source)
	b.rfKind = PF.kindFor or "raidPet"
	V.Secure(b)
	V.Build(b)
	b.exColor = PF.ColorOf
	b.exSource = source
	b:HookScript("OnShow", function(self)
		PF.Refresh(self)
	end)
	b:HookScript("OnAttributeChanged", function(self, name)
		if (name == "unit" or name == "useparent-unit" or name == "unitsuffix") and self:IsVisible() then
			PF.Refresh(self)
		end
	end)
	if RF.CC_SetupButton then
		SafeCall(RF.CC_SetupButton, b)
	end
end

-- Size, spacing and growth of a tab's pets.
PF.Geometry = function(ctx)
	local p = P()
	local s = RF._scaledProfile
	local w, h, sp, unitGrowth, groupGrowth
	if ctx == "party" then
		w, h, sp = RF.RF_PartyDims(p)
		unitGrowth = PartyGrowth(p)
		groupGrowth = (unitGrowth == "RIGHT" or unitGrowth == "LEFT") and "DOWN" or "RIGHT"
	else
		w, h, sp = s.frameWidth or 125, s.frameHeight or 60, s.cellSpacing or -1
		unitGrowth, groupGrowth = s.unitGrowth or "DOWN", s.groupGrowth or "RIGHT"
		if groupGrowth == "DOWNRIGHT" then
			groupGrowth = "RIGHT"
		end
		local uh = unitGrowth == "LEFT" or unitGrowth == "RIGHT"
		local gh = groupGrowth == "LEFT" or groupGrowth == "RIGHT"
		if uh == gh then
			groupGrowth = uh and "DOWN" or "RIGHT"
		end
	end
	local v = PF.View(ctx)
	w = Snap(max(10, w + (v.extraWidth or 0)))
	h = Snap(max(10, h + (v.extraHeight or 0)))
	return w, h, sp, unitGrowth, groupGrowth
end

-- Header child creation: the startingIndex pass (made while shown, then
-- hidden again). Children are SecureUnitButtonTemplate buttons. OOC.
PF.Capacity = function()
	local raw = PF.Raw()
	return (raw and raw.raid == true) and PF.MAX or 5
end

PF.Child = function(hdr, i)
	return hdr:GetAttribute("child" .. i) or hdr[i]
end

PF.EnsureBuilt = function()
	local cap = PF.Capacity()
	local have = #PF.buttons
	if have >= cap then
		return true
	end
	local hdr = PF.container
	if not hdr then
		local hider = CreateFrame("Frame", nil, UIParent)
		hider:SetAllPoints(UIParent)
		PF.hider = hider
		hdr = CreateFrame("Frame", "ERFPetHeader", hider, "SecureGroupPetHeaderTemplate")
		hdr:SetAttribute("template", "SecureUnitButtonTemplate")
		hdr:SetAttribute("templateType", "Button")
		hdr:SetAttribute("showRaid", true)
		hdr:SetAttribute("showParty", true)
		hdr:SetAttribute("showPlayer", true)
		hdr:SetAttribute("sortMethod", "INDEX")
		hdr:SetAttribute("unitsPerColumn", 5)
		hdr:SetAttribute("columnAnchorPoint", "LEFT")
		hdr:SetPoint("CENTER", UIParent, "CENTER", 100, -200)
		PF.container = hdr
		PF.built = true
	end
	if not PF.Child(hdr, cap) then
		local hid = not PF.hider:IsShown()
		hdr:Hide()
		if hid then
			PF.hider:Show()
		end
		hdr:SetAttribute("maxColumns", cap > 5 and 8 or 1)
		hdr:SetAttribute("startingIndex", 1 - cap)
		hdr:Show()
		hdr:SetAttribute("startingIndex", 1)
		hdr:Hide()
		if hid then
			PF.hider:Hide()
		end
	end
	for i = have + 1, cap do
		local b = PF.Child(hdr, i)
		if not b then
			break
		end
		PF.StyleButton(b, PF.StyleSource)
		PF.buttons[i] = b
	end
	PF.w = nil
	return #PF.buttons > 0
end

-- Header attributes from the growth: point/offsets along the unit growth,
-- the column anchor across.
local function HeaderPoint(unitGrowth, sp)
	if unitGrowth == "UP" then
		return "BOTTOM", 0, sp
	elseif unitGrowth == "RIGHT" then
		return "LEFT", sp, 0
	elseif unitGrowth == "LEFT" then
		return "RIGHT", -sp, 0
	end
	return "TOP", 0, -sp
end
local function ColAnchor(unitGrowth, groupGrowth)
	if unitGrowth == "LEFT" or unitGrowth == "RIGHT" then
		return groupGrowth == "UP" and "BOTTOM" or "TOP"
	end
	return groupGrowth == "LEFT" and "RIGHT" or "LEFT"
end

local function SetAttr(hdr, key, value)
	if hdr:GetAttribute(key) ~= value then
		hdr:SetAttribute(key, value)
		return true
	end
	return false
end

-- Show Groups as a groupFilter (nil = every group).
PF.RaidGroupFilter = function()
	local vg = P().visibleGroups
	if not vg then
		return nil
	end
	local str, all = "", true
	for gi = 1, 8 do
		if vg[gi] ~= false then
			str = (str == "") and tostring(gi) or (str .. "," .. gi)
		else
			all = false
		end
	end
	if all then
		return nil
	end
	return str
end

PF.Layout = function()
	local ctx = PF.Ctx()
	local party = ctx == "party"
	local w, h, sp, unitGrowth, groupGrowth = PF.Geometry(ctx)
	PF.w, PF.h, PF.sp, PF.unitGrowth, PF.groupGrowth = w, h, sp, unitGrowth, groupGrowth
	PF.styleCtx = ctx
	PF.kindFor = party and "partyPet" or "raidPet"
	local hdr = PF.container
	local ss = PF.StyleSource()
	for _, b in ipairs(PF.buttons) do
		b.rfKind = PF.kindFor
		b:SetSize(w, h)
		V.Style(b, ss, w, h)
	end
	local pitch = sp
	if party and PF.View("party").position ~= "free" then
		pitch = sp + RF.PT_AlongPitch(P())
	end
	local point, xOff, yOff = HeaderPoint(unitGrowth, pitch)
	local s = RF._scaledProfile
	local solo = (party and P().partyShowWhenSolo) and true or nil
	local changed = false
	changed = SetAttr(hdr, "showRaid", not party) or changed
	changed = SetAttr(hdr, "showParty", party) or changed
	changed = SetAttr(hdr, "showPlayer", party) or changed
	changed = SetAttr(hdr, "showSolo", solo) or changed
	changed = SetAttr(hdr, "groupFilter", (not party) and PF.RaidGroupFilter() or nil) or changed
	changed = SetAttr(hdr, "point", point) or changed
	changed = SetAttr(hdr, "xOffset", xOff) or changed
	changed = SetAttr(hdr, "yOffset", yOff) or changed
	changed = SetAttr(hdr, "columnSpacing", Snap(s.groupSpacing or 8)) or changed
	changed = SetAttr(hdr, "columnAnchorPoint", ColAnchor(unitGrowth, groupGrowth)) or changed
	changed = SetAttr(hdr, "maxColumns", #PF.buttons >= PF.MAX and 8 or 1) or changed
	if changed then
		for _, b in ipairs(PF.buttons) do
			b:ClearAllPoints()
		end
	end
	-- Five slots on the growth axis: the header box for the attach pass.
	local vertical = unitGrowth ~= "RIGHT" and unitGrowth ~= "LEFT"
	if vertical then
		hdr:SetSize(w, 5 * h + 4 * pitch)
	else
		hdr:SetSize(5 * w + 4 * pitch, h)
	end
	local m = solo and "[petbattle] hide; show" or "[petbattle] hide; [@raid1,exists] show; [@party1,exists] show; hide"
	if PF.hiderMacro ~= m then
		RegisterStateDriver(PF.hider, "visibility", m)
		PF.hiderMacro = m
	end
end

-- Pets follow Friendly Boss and Extra Frames on the same side.
PF.ChainAnchor = function(pset)
	if pset.position == "free" or pset.position == "owner" then
		return nil
	end
	local party = PartyMode()
	local fs = FB.Settings()
	if fs and FB.built and FB.container:IsShown() then
		if party then
			if fs.position ~= "free" and fs.showInDungeons == true and fs.position == pset.position then
				return FB.container
			end
		elseif fs.position == pset.position then
			return FB.container
		end
	end
	if party then
		return nil
	end
	local xs = XF.Settings()
	if xs and xs.position == pset.position and XF.built and XF.container:IsShown() then
		return XF.container
	end
	return nil
end

-- Free Move: pinned at the corner the pets grow from.
PF.FreeCorner = function(set, ctx)
	local w, h, sp, unitGrowth, groupGrowth = PF.Geometry(ctx)
	local vertical = unitGrowth ~= "RIGHT" and unitGrowth ~= "LEFT"
	local hDir = vertical and groupGrowth or unitGrowth
	local vDir = vertical and unitGrowth or groupGrowth
	if vertical then
		h = 5 * h + 4 * sp
	else
		w = 5 * w + 4 * sp
	end
	local r = set.freeRect
	local corner, x, y = V.CornerPin(hDir, vDir, r)
	if not r then
		local p = set.freePos
		local cx, cy = p and p.x or 100, p and p.y or 0
		x = (hDir == "LEFT") and (cx + w / 2) or (cx - w / 2)
		y = (vDir == "UP") and (cy - h / 2) or (cy + h / 2)
	end
	return corner, x, y, w, h
end

PF.FreeAnchor = function(c, set)
	local corner, x, y = PF.FreeCorner(set, PF.Ctx())
	V.Pin(c, corner, UIParent, "CENTER", x, y)
	return true
end

PF.MoverSettings = function()
	return PF.Raw() and PF.View(PF.moverCtx or PF.Ctx())
end

PF.MoverPrep = function()
	if PF.active and not InCombatLockdown() then
		PF.Layout()
		FB.Anchor(PF)
	end
end

PF.PlaceMover = function(m, set)
	local corner, x, y, w, h = PF.FreeCorner(set, PF.moverCtx or PF.Ctx())
	m:SetSize(w, h)
	m:SetPoint(corner, UIParent, "CENTER", x, y)
end

PF.SaveFreeRect = function(mover)
	V.SaveMoverRect(mover, PF.MoverSettings())
end

function RF.PF_SetMoverShown(show, ctx)
	if show then
		PF.moverCtx = ctx or PF.Ctx()
	end
	FB.SetMoverShown(PF, show, "ERFPetFramesMover", "Pet Frames")
end

function RF.PF_IsMoverShown(ctx)
	return (PF.mover and PF.mover:IsShown() and (ctx == nil or PF.moverCtx == ctx)) or false
end

-- A size change on the tab whose overlay is up: the overlay takes the size.
function RF.PF_PlaceMover(ctx)
	local m = PF.mover
	if not (m and m:IsShown() and PF.moverCtx == ctx) then
		return
	end
	local set = PF.MoverSettings()
	if not set then
		return
	end
	m:ClearAllPoints()
	PF.PlaceMover(m, set)
end

-- The real-frame previews dim the live frames: the pet header (its own
-- parent, not the party container) follows. Beside Owner pets and party
-- targets are children of the party frames and follow them already.
function RF.PF_SetPreviewAlpha(a)
	PF.previewAlpha = a
	if PF.hider then
		PF.hider:SetAlpha(a or 1)
	end
end

-- Beside Owner: Pet Side fitted to the party frames' orientation.
PF.OwnerSide = function(s)
	local raw = PF.Raw()
	local side = raw and raw.ownerSide
	if s.partyHorizontal then
		if side ~= "above" and side ~= "below" then
			side = "below"
		end
	elseif side ~= "left" and side ~= "right" then
		side = "right"
	end
	return side
end
function RF.PF_OwnerSide()
	return PF.OwnerSide(P())
end

PF.OwnerPoint = function(b, owner, side, gap)
	b:ClearAllPoints()
	if side == "left" then
		b:SetPoint("TOPRIGHT", owner, "TOPLEFT", -gap, 0)
	elseif side == "below" then
		b:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -gap)
	elseif side == "above" then
		b:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, gap)
	else
		b:SetPoint("TOPLEFT", owner, "TOPRIGHT", gap, 0)
	end
end

-- One pet button per party frame, made the first time Beside Owner is on.
-- Its unit is the owner's unit + "pet" (useparent-unit / unitsuffix, so the
-- party header's re-sorts in combat carry it). The frame holding you gets
-- "pet" itself, out of combat.
PF.OwnerPetFor = function(owner)
	for _, b in ipairs(PF.ownerButtons) do
		if PF.ownerOf[b] == owner then
			return b
		end
	end
	local b = CreateFrame("Button", nil, owner, "SecureUnitButtonTemplate")
	b:SetAttribute("useparent-unit", true)
	b:SetAttribute("unitsuffix", "pet")
	b:Hide()
	PF.kindFor = "partyPet"
	PF.StyleButton(b, function()
		return RF._scaledPartyProxy
	end)
	b.rfKind = "partyPet"
	PF.ownerOf[b] = owner
	PF.ownerButtons[#PF.ownerButtons + 1] = b
	return b
end

-- Point the pet of the frame holding you at "pet" (OOC).
PF.FixSelf = function(b)
	local owner = PF.ownerOf[b]
	local ou = owner and owner:GetAttribute("unit")
	local isSelf = ou and (ou == "player" or UnitIsUnit(ou, "player"))
	if isSelf then
		if b:GetAttribute("unit") ~= "pet" then
			b:SetAttribute("unitsuffix", nil)
			b:SetAttribute("unit", "pet")
		end
	elseif b:GetAttribute("unit") then
		b:SetAttribute("unit", nil)
		b:SetAttribute("unitsuffix", "pet")
	end
end

PF.OwnerApply = function()
	local chosen = PF.OwnerChosen()
	if not chosen then
		if PF.ownerActive then
			for _, b in ipairs(PF.ownerButtons) do
				UnregisterUnitWatch(b)
				b:Hide()
			end
			PF.ownerActive = nil
			PF.NotifyReserve()
		end
		return
	end
	local w, h, sp = PF.Geometry("party")
	local p = P()
	local side = PF.OwnerSide(p)
	local gap = Snap(sp)
	local s = RF._scaledPartyProxy
	local changed = not PF.ownerActive or w ~= PF.ownerW or h ~= PF.ownerH or side ~= PF.ownerSideCur
	PF.ownerW, PF.ownerH, PF.ownerSideCur, PF.ownerGap, PF.ownerBaseGap = w, h, side, gap, gap
	PF.ownerActive = true
	for _, owner in ipairs(PartyButtons()) do
		local b = PF.OwnerPetFor(owner)
		b:SetSize(w, h)
		V.Style(b, s, w, h)
		PF.OwnerPoint(b, owner, side, gap)
		PF.FixSelf(b)
		RegisterUnitWatch(b)
	end
	if changed then
		PF.NotifyReserve()
	end
end

PF.NotifyReserve = function()
	if RF.PT_Layout then
		RF.PT_Layout()
	end
	local fs = FB.Settings()
	if FB.built and fs and fs.showInDungeons == true then
		FB.Anchor()
	end
end

-- The room Beside Owner pets take on a side of the party frames.
function RF.PF_OwnerReserve(horizontal, before)
	local side = PF.ownerActive and PF.ownerSideCur
	if not side then
		return 0
	end
	if horizontal then
		if (before and side == "above") or (not before and side == "below") then
			return PF.ownerH + PF.ownerBaseGap
		end
	elseif (before and side == "left") or (not before and side == "right") then
		return PF.ownerW + PF.ownerBaseGap
	end
	return 0
end

PF.RangeTick = function()
	PF.EachShown(PF.ApplyRange)
end

function RF.PF_Apply()
	local raw = PF.Raw()
	if not raw then
		return
	end
	if InCombatLockdown() then
		PF.applyDirty = true
		return
	end
	local wanted = PF.Wanted()
	if wanted and PF.EnsureBuilt() then
		PF.Layout()
		FB.Anchor(PF)
		PF.container:Show()
		PF.active = true
	else
		if PF.container then
			PF.container:Hide()
		end
		if PF.mover then
			PF.mover:Hide()
		end
		PF.active = nil
	end
	PF.OwnerApply()
	PF.EachShown(PF.Refresh)
	local want = PF.active or PF.ownerActive
	if want and not PF.ticker then
		PF.ticker = RF.NewTicker(0.5, PF.RangeTick)
	elseif not want and PF.ticker then
		PF.ticker:Cancel()
		PF.ticker = nil
	end
end

function RF.PF_ReAnchor()
	if PF.active and not InCombatLockdown() then
		FB.Anchor(PF)
	end
end
RF.PF_PartyRelayout = RF.PF_ReAnchor

-------------------------------------------------------------------------------
--  Party Targets (retail EUI_RaidFrames_PartyTargets.lua): a secure button
--  beside each party frame showing that member's target (useparent-unit +
--  unitsuffix "target", shown by a unit watch). A party member's target has
--  no events: one 0.5 s ticker repaints while any is shown; your own target
--  is evented. Include Own Target off drops the unit of the frame that
--  holds you (out of combat).
-------------------------------------------------------------------------------
local PT = { frames = {}, frameOf = setmetatable({}, { __mode = "k" }) }
RF._PT = PT

PT.Side = function(s, auto)
	local pos = (not auto and s.partyTargetPosition) or (s.partyHorizontal and "bottom" or "right")
	local side = (pos == "top" and "above") or (pos == "bottom" and "below") or (pos == "left" and "left") or "right"
	local vert = side == "above" or side == "below"
	if (vert and not s.partyHorizontal) or (not vert and s.partyHorizontal) then
		return side, 0, false
	end
	return side, 0, true
end

PT.Gap = function(s)
	local _, _, sp = RF.RF_PartyDims(s)
	return sp
end

PT.ReserveOf = function(st, horizontal, before)
	local side, r = st.side, 0
	if st.across then
		if horizontal then
			if before and side == "above" then
				r = st.h + st.gap + st.y
			elseif not before and side == "below" then
				r = st.h + st.gap - st.y
			end
		elseif before and side == "left" then
			r = st.w + st.gap - st.x
		elseif not before and side == "right" then
			r = st.w + st.gap + st.x
		end
	elseif horizontal then
		r = (st.h - st.ph) / 2 + (before and st.y or -st.y)
	else
		r = (st.w - st.pw) / 2 + (before and -st.x or st.x)
	end
	return r > 0 and Snap(r) or 0
end

-- Room the target frames take past the party frames on a side (horizontal:
-- the party frames' orientation; before: left / above). pets: the Beside
-- Owner pets' room there.
function RF.PT_Reserve(horizontal, before, pets)
	pets = pets or 0
	if not (PT.enabled and PT.w) then
		return pets
	end
	local r = PT.ReserveOf(PT, horizontal, before)
	if PT.across then
		return r + pets
	end
	return (r > pets) and r or pets
end

function RF.PT_ShownSide(auto)
	local side = PT.Side(P(), auto)
	return (side == "above" and "top") or (side == "below" and "bottom") or side
end

-- Room target frames along the stack add to the party frames' pitch (the
-- headers file adds it to the party spacing).
function RF.PT_AlongPitch(s, on)
	if on == nil then
		on = PT.enabled
	end
	if not on or not s then
		return 0
	end
	local _, _, across = PT.Side(s)
	if across then
		return 0
	end
	return Snap(s.partyHorizontal and (s.partyTargetWidth or 70) or (s.partyTargetHeight or 33)) + Snap(PT.Gap(s))
end

PT.Classify = function(frame)
	local ou = frame.ptOwner:GetAttribute("unit")
	local own = ou ~= nil and (ou == "player" or UnitIsUnit(ou, "player"))
	frame.ptOwn = own or nil
	frame.ptOwnerUnit = (not own) and ou or nil
	frame.ptUnit = (own and "target") or (ou and (ou .. "target")) or nil
end

local function ClassicRGB(pct)
	pct = pct / 100
	if pct > 0.5 then
		return (1 - pct) * 2, 1, 0
	end
	return 1, pct * 2, 0
end

PT.ClassRGB = function(u, frame)
	if UnitIsPlayer(u) then
		local r, g, b = V.ClassRGB(u)
		if r then
			return true, r, g, b
		end
		return false
	end
	local tap = UnitIsTapped(u) and not UnitIsTappedByPlayer(u)
	local re = UnitReaction(u, "player")
	if frame then
		frame.ptNpc, frame.ptTap, frame.ptRe = true, tap, re
	end
	if tap then
		return true, 0.6, 0.6, 0.6
	end
	local c = re and FACTION[re]
	if c then
		return true, c[1], c[2], c[3]
	end
	return false
end

PT.Paint = function(frame)
	local u = frame.ptUnit
	frame.ptNpc = nil
	if not (u and UnitExists(u)) then
		return
	end
	local ex = frame.ex
	ex.name:SetText(V.Cap(UnitName(u), 12) or "")
	local health, bg, mode = ex.health, ex.bg, PT.mode
	local pct = V.HealthPct(u)
	if mode == "dark" then
		health:SetStatusBarColor(RF.DARK_FILL[1], RF.DARK_FILL[2], RF.DARK_FILL[3], 1)
		bg:SetTexture(RF.DARK_BG[1], RF.DARK_BG[2], RF.DARK_BG[3], 1)
	else
		local ok, r, g, b = false, nil, nil, nil
		if (mode ~= "classic" and mode ~= "custom") or PT.bgClass then
			ok, r, g, b = PT.ClassRGB(u, frame)
		end
		if mode == "classic" then
			health:SetStatusBarColor(ClassicRGB(pct))
		elseif mode == "custom" then
			health:SetStatusBarColor(PT.fr, PT.fg, PT.fb, 1)
		elseif ok then
			health:SetStatusBarColor(r, g, b, 1)
		else
			health:SetStatusBarColor(0.5, 0.5, 0.5, 1)
		end
		if ok and PT.bgClass then
			bg:SetTexture(r, g, b, PT.bgA)
		else
			bg:SetTexture(PT.br, PT.bgg, PT.bb, PT.bgA)
		end
	end
	health:SetValue(pct)
	V.ReadTarget(frame, u)
	V.BorderColor(frame)
end

PT.PaintValue = function(frame, u)
	local pct = V.HealthPct(u)
	frame.ex.health:SetValue(pct)
	if PT.mode == "classic" then
		frame.ex.health:SetStatusBarColor(ClassicRGB(pct))
	end
end

PT.RepaintVisible = function()
	if not PT.enabled then
		return
	end
	for _, f in ipairs(PT.frames) do
		if f:IsVisible() then
			PT.Classify(f)
			PT.Paint(f)
		end
	end
end

PT.Tick = function()
	for _, f in ipairs(PT.frames) do
		local u = f.ptUnit
		if u and not f.ptOwn and f:IsVisible() and UnitExists(u) then
			PT.PaintValue(f, u)
			if f.ptNpc then
				local tap = UnitIsTapped(u) and not UnitIsTappedByPlayer(u)
				if tap ~= f.ptTap or UnitReaction(u, "player") ~= f.ptRe then
					PT.Paint(f)
				end
			end
		end
	end
end

PT.Place = function(frame, o, side, off, x, y)
	frame:ClearAllPoints()
	if side == "left" then
		frame:SetPoint("RIGHT", o, "LEFT", x - off, y)
	elseif side == "below" then
		frame:SetPoint("TOP", o, "BOTTOM", x, y - off)
	elseif side == "above" then
		frame:SetPoint("BOTTOM", o, "TOP", x, y + off)
	else
		frame:SetPoint("LEFT", o, "RIGHT", x + off, y)
	end
end

-- Size and placement; tells the attached groups / the party layout when
-- the reserved room changed. OOC only.
function RF.PT_Layout()
	if not PT.enabled then
		return
	end
	if InCombatLockdown() then
		PT.layoutDirty = true
		return
	end
	PT.layoutDirty = nil
	local s = P()
	local w = Snap(s.partyTargetWidth or 70)
	local h = Snap(s.partyTargetHeight or 33)
	local x = Snap(s.partyTargetOffsetX or 0)
	local y = Snap(s.partyTargetOffsetY or 0)
	local pw, ph = RF.RF_PartyDims(s)
	pw, ph = Snap(pw), Snap(ph)
	local gap = Snap(PT.Gap(s))
	local side, _, across = PT.Side(s)
	local off = gap
	if across and PF.ownerActive and PF.ownerSideCur == side then
		off = PF.ownerGap + ((side == "above" or side == "below") and PF.ownerH or PF.ownerW) + gap
	end
	local reserve = PT.w ~= w or PT.h ~= h or PT.side ~= side or PT.across ~= across or PT.gap ~= gap
		or PT.x ~= x or PT.y ~= y or PT.pw ~= pw or PT.ph ~= ph
	PT.w, PT.h, PT.side, PT.gap, PT.off, PT.across, PT.x, PT.y, PT.pw, PT.ph = w, h, side, gap, off, across, x, y, pw, ph
	for _, frame in ipairs(PT.frames) do
		frame:SetSize(w, h)
		V.Size(frame, w, h)
		PT.Place(frame, frame.ptOwner, side, off, x, y)
	end
	if reserve then
		local pitch = RF.PT_AlongPitch(s)
		if pitch ~= (PT.pitchSent or 0) then
			PT.pitchSent = pitch
			if RF.RequestLayout then
				RF.RequestLayout()
			end
		end
		local fs = FB.Settings()
		if FB.built and fs and fs.showInDungeons == true then
			FB.Anchor()
		end
		RF.PF_ReAnchor()
	end
end

-- Colors, texture, font and border from the party settings.
PT.Restyle = function()
	local p = P()
	local s = RF._scaledPartyProxy
	local fc = p.partyTargetCustomFillColor or { r = 37 / 255, g = 193 / 255, b = 29 / 255 }
	local bc = p.partyTargetCustomBgColor or DEF_BG
	PT.mode = p.partyTargetHealthColorMode or "class"
	PT.fr, PT.fg, PT.fb = fc.r, fc.g, fc.b
	PT.bgClass = p.partyTargetBgClassColored and true or nil
	PT.br, PT.bgg, PT.bb = bc.r, bc.g, bc.b
	PT.bgA = (p.partyTargetBgDarkness or 50) / 100
	local tex = RF.TexturePath(s.healthBarTexture)
	for _, frame in ipairs(PT.frames) do
		local ex = frame.ex
		ex.health:SetStatusBarTexture(tex)
		local t = ex.health:GetStatusBarTexture()
		if t then
			t:SetHorizTile(false)
		end
		RF.SetFont(ex.name, s.nameSize or 10)
		V.BorderColor(frame)
	end
	PT.RepaintVisible()
end

PT.Build = function(owner)
	local frame = CreateFrame("Button", nil, owner, "SecureUnitButtonTemplate")
	frame:SetAttribute("useparent-unit", true)
	frame:SetAttribute("unitsuffix", "target")
	frame.rfKind = "partyTarget"
	V.Secure(frame)
	frame:Hide()
	local ex = V.Build(frame)
	ex.nameFixed = true
	ex.name:SetPoint("CENTER", ex.health, "CENTER", 0, 0)
	ex.name:SetJustifyH("CENTER")
	ex.name:SetTextColor(1, 1, 1, 1)
	ex.htext:Hide()
	frame.exSource = function()
		return RF._scaledPartyProxy
	end
	frame.ptOwner = owner
	frame:HookScript("OnShow", function(self)
		if not PT.enabled then
			return
		end
		PT.Classify(self)
		PT.Paint(self)
	end)
	owner:HookScript("OnAttributeChanged", function(o, name)
		if name ~= "unit" or not PT.enabled then
			return
		end
		local f = PT.frameOf[o]
		if f then
			PT.Classify(f)
			if f:IsVisible() then
				PT.Paint(f)
			end
		end
	end)
	if RF.CC_SetupButton then
		SafeCall(RF.CC_SetupButton, frame)
	end
	PT.frameOf[owner] = frame
	PT.frames[#PT.frames + 1] = frame
	return frame
end

-- Include Own Target off: the frame whose owner holds you drops its unit.
PT.SeedAttrs = function()
	local noself = PT.enabled and not PT.include
	for _, frame in ipairs(PT.frames) do
		local u = frame.ptOwner:GetAttribute("unit")
		local show = not (noself and u ~= nil and (u == "player" or UnitIsUnit(u, "player")))
		if frame:GetAttribute("useparent-unit") ~= show then
			frame:SetAttribute("useparent-unit", show)
		end
	end
end

PT.OnEvent = function(_, event, unit)
	if not PT.enabled then
		return
	end
	if event == "UNIT_TARGET" then
		for _, f in ipairs(PT.frames) do
			if f.ptOwnerUnit == unit and f:IsVisible() then
				PT.Paint(f)
			end
		end
	elseif event == "PLAYER_TARGET_CHANGED" or event == "UNIT_FACTION" then
		for _, f in ipairs(PT.frames) do
			if f.ptOwn and f:IsVisible() then
				PT.Paint(f)
			end
		end
	elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
		if unit == "target" then
			for _, f in ipairs(PT.frames) do
				if f.ptOwn and f:IsVisible() then
					PT.PaintValue(f, "target")
				end
			end
		end
	else
		-- Roster / zoning: re-read every frame after the header re-sorted.
		RF.After(0, function()
			RF.AfterCombat("PT_Seed", PT.SeedAttrs)
			PT.RepaintVisible()
		end)
	end
end

PT.events = CreateFrame("Frame")
PT.events:SetScript("OnEvent", PT.OnEvent)

-- Enable / disable from the settings (partyShowTargets,
-- partyTargetIncludeSelf). OOC only.
function RF.PT_Apply()
	local p = P()
	if not p then
		return
	end
	if InCombatLockdown() then
		PT.applyDirty = true
		return
	end
	local want = p.partyShowTargets == true
	PT.include = p.partyTargetIncludeSelf == true
	if want then
		for _, owner in ipairs(PartyButtons()) do
			if not PT.frameOf[owner] then
				PT.Build(owner)
				PT.w = nil
			end
		end
		local ev = PT.events
		ev:RegisterEvent("UNIT_TARGET")
		ev:RegisterEvent("PLAYER_TARGET_CHANGED")
		ev:RegisterEvent("GROUP_ROSTER_UPDATE")
		ev:RegisterEvent("PLAYER_ENTERING_WORLD")
		ev:RegisterUnitEvent("UNIT_HEALTH", "target")
		ev:RegisterUnitEvent("UNIT_MAXHEALTH", "target")
		ev:RegisterUnitEvent("UNIT_FACTION", "target")
		local was = PT.enabled
		PT.enabled = true
		if not was then
			PT.w = nil
		end
		RF.PT_Layout()
		PT.Restyle()
		PT.SeedAttrs()
		for _, frame in ipairs(PT.frames) do
			PT.Classify(frame)
			RegisterUnitWatch(frame)
		end
		if not PT.ticker then
			PT.ticker = RF.NewTicker(0.5, PT.Tick)
		end
		PT.RepaintVisible()
	elseif PT.enabled then
		PT.enabled = false
		PT.events:UnregisterAllEvents()
		for _, frame in ipairs(PT.frames) do
			UnregisterUnitWatch(frame)
			frame:Hide()
		end
		if PT.ticker then
			PT.ticker:Cancel()
			PT.ticker = nil
		end
		PT.w = nil
		if (PT.pitchSent or 0) ~= 0 then
			PT.pitchSent = 0
			if RF.RequestLayout then
				RF.RequestLayout()
			end
		end
		local fs = FB.Settings()
		if FB.built and fs and fs.showInDungeons == true then
			FB.Anchor()
		end
		RF.PF_ReAnchor()
	end
end

function RF.PT_SetEnabled(on)
	local p = P()
	if p then
		p.partyShowTargets = on and true or false
	end
	RF.PT_Apply()
end

function RF.PT_SetIncludeSelf(on)
	local p = P()
	if p then
		p.partyTargetIncludeSelf = on and true or false
	end
	RF.PT_Apply()
end

function RF.PT_Refresh()
	if PT.enabled then
		PT.Restyle()
	end
end

-------------------------------------------------------------------------------
--  Party Portrait (retail EUI_RaidFrames_Portrait.lua): Attached (a square
--  the frame's height beside the bars; the party box widens through
--  RF.RF_PtReserve), Detached (off the health bar's edge) or Inside (over
--  the bar). Art Style: 2D portrait, 3D model, class art. 5.4.8 has no mask
--  textures: every shape draws as a square with a border ("none" = no
--  border), and the Inside box does not clip a large 3D model.
-------------------------------------------------------------------------------
local PO = { list = {} }
RF._PO = PO
RF.RF_PT_ZOOM3D_MAX = 500

-- 3D Zoom 100..500 -> portrait zoom, camera distance (retail Zoom3DOf).
PO.Zoom3D = function(z)
	z = z or 100
	if z <= 300 then
		return 1, z / 100
	end
	if z > 500 then
		z = 500
	end
	local t = (z - 300) / 200
	return 1 - t, 3 - 2 * t
end

-- The attached portrait's width in the party box: a square the frame's height.
function RF.RF_PtReserve(s, h)
	if not s or (s.partyPortraitStyle or "none") ~= "attached" then
		return 0
	end
	return h or 0
end

PO.Settings = function(btn)
	return btn.rfSettings or RF._scaledPartyProxy
end

PO.SideOf = function(s, style)
	local side = s.partyPortraitSide or "left"
	local inside = side == "insideleft" or side == "insideright" or side == "insidecenter"
	if style == "attached" then
		if side ~= "right" then
			side = "left"
		end
		return side, false
	end
	return side, inside
end

-- The bars' insets an attached portrait asks for (the Button file lays its
-- bars inside these): left, right.
function RF.PortraitBarInsets(btn)
	local bd = btn and btn.exPt
	if not (bd and bd.on and bd.style == "attached") then
		return 0, 0
	end
	if bd.side == "right" then
		return 0, bd.w or 0
	end
	return bd.w or 0, 0
end

PO.Ensure = function(btn)
	local bd = btn.exPt
	if bd then
		return bd
	end
	bd = CreateFrame("Frame", nil, btn)
	bd:EnableMouse(false)
	bd.bg = bd:CreateTexture(nil, "BACKGROUND")
	bd.bg:SetAllPoints()
	bd.bg:SetTexture(0.1, 0.1, 0.1, 1)
	bd.t2 = bd:CreateTexture(nil, "ARTWORK")
	bd.t2:SetAllPoints()
	bd.t2:SetTexCoord(0.15, 0.85, 0.15, 0.85)
	bd.t2:Hide()
	bd.tc = bd:CreateTexture(nil, "ARTWORK")
	bd.tc:SetAlpha(0.8)
	bd.tc:Hide()
	bd.border = RF.CreateBorder(bd, 2)
	bd.owner = btn
	bd:Hide()
	btn.exPt = bd
	return bd
end

PO.Ensure3D = function(bd)
	if bd.m then
		return bd.m
	end
	local m = CreateFrame("PlayerModel", nil, bd)
	m:SetAllPoints(bd)
	m:SetCamera(0)
	m:EnableMouse(false)
	m:SetScript("OnShow", function()
		local u = PO.Unit(bd.owner)
		if u then
			PO.Paint(bd.owner, u, true)
		end
	end)
	m:Hide()
	bd.m = m
	return m
end

PO.Unit = function(btn)
	if btn.rfPreview then
		return nil
	end
	local u = btn:GetAttribute("unit")
	if u and UnitExists(u) then
		return u
	end
	return nil
end

-- Seat the backdrop for style / side (out of combat: the button is secure,
-- but the backdrop is our own plain frame, so this is combat legal).
PO.Seat = function(btn, bd, s, style, side, inside, bh)
	local host = (btn.rf and btn.rf.health) or btn
	local size = s.partyPortraitSize or 0
	local px, py = s.partyPortraitX or 0, s.partyPortraitY or 0
	bd:ClearAllPoints()
	local w, h
	if style == "attached" then
		w, h = bh, bh
		bd:SetSize(w, h)
		if side == "right" then
			bd:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
		else
			bd:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
		end
		bd.lvl = 1
	elseif inside then
		w = max(8, bh + size)
		h = bh
		bd:SetSize(w, h)
		local pt = (side == "insideleft" and "LEFT") or (side == "insideright" and "RIGHT") or "CENTER"
		bd:SetPoint(pt, btn, pt, px, py)
		bd.lvl = 6
	else
		w = max(8, bh + size + 10)
		h = w
		bd:SetSize(w, h)
		local y = py + 5
		if side == "top" then
			bd:SetPoint("BOTTOM", host, "TOP", px, 15 + y)
		elseif side == "right" then
			bd:SetPoint("TOPLEFT", host, "TOPRIGHT", 15 + px, y)
		else
			bd:SetPoint("TOPRIGHT", host, "TOPLEFT", -15 + px, y)
		end
		bd.lvl = 11
	end
	bd.w, bd.h = w, h
	local ci = floor(h * 0.08)
	bd.tc:ClearAllPoints()
	bd.tc:SetPoint("TOPLEFT", bd, "TOPLEFT", ci, -ci)
	bd.tc:SetPoint("BOTTOMRIGHT", bd, "BOTTOMRIGHT", -ci, ci)
end

PO.BorderRGB = function(s, unit, ct)
	if s.partyPortraitBorderClassColor ~= false then
		if ct then
			return RF.ClassColor(ct)
		end
		if unit and UnitIsPlayer(unit) then
			local r, g, b = V.ClassRGB(unit)
			if r then
				return r, g, b
			end
		elseif unit then
			local c = FACTION[UnitReaction(unit, "player") or 0]
			if c then
				return c[1], c[2], c[3]
			end
		end
		local _, pc = UnitClass("player")
		return RF.ClassColor(pc)
	end
	local c = s.partyPortraitBorderColor
	return c and c.r or 0, c and c.g or 0, c and c.b or 0
end

-- Paint the art for unit (force: reload the 3D model).
PO.Paint = function(btn, unit, force, ct)
	local bd = btn.exPt
	if not (bd and bd.on) then
		return
	end
	local s = PO.Settings(btn)
	local mode = bd.mode
	local guid = unit and UnitGUID(unit)
	local changed = force or guid ~= bd.guid
	if mode == "class" then
		if not ct and unit then
			local _
			_, ct = UnitClass(unit)
		end
		local c = CLASS_TC[ct or "WARRIOR"] or CLASS_TC.WARRIOR
		bd.tc:SetTexture(CLASS_CIRCLES)
		bd.tc:SetTexCoord(c[1], c[2], c[3], c[4])
	elseif mode == "3d" then
		local m = bd.m
		if m and unit and changed then
			if UnitIsConnected(unit) and UnitIsVisible(unit) then
				m:ClearModel()
				m:SetUnit(unit)
				m:SetPortraitZoom(bd.pz or 1)
				m:SetPosition(0, 0, 0)
				m:SetCamDistanceScale(bd.cz or 1)
			else
				m:ClearModel()
				m:SetModel("Interface\\Buttons\\TalkToMeQuestionMark.m2")
				m:SetCamDistanceScale(0.25)
				m:SetPortraitZoom(0)
				m:SetPosition(0, 0, 0.25)
			end
		end
	elseif unit then
		if changed then
			SetPortraitTexture(bd.t2, unit)
			bd.t2:SetTexCoord(0.15, 0.85, 0.15, 0.85)
		end
		bd.t2:SetDesaturated(not UnitIsConnected(unit))
	elseif btn.rfPreview then
		bd.t2:SetTexture("Interface\\CharacterFrame\\TempPortrait")
	end
	bd.guid = guid
	if bd.bordered then
		local r, g, b = PO.BorderRGB(s, unit, ct)
		bd.border:SetColor(r, g, b, (s.partyPortraitBorderOpacity or 100) / 100)
	end
end

-- Whole pass for one party button (settings change or init).
-- A preview frame of the party preview (the Preview file's list).
PO.IsPartyPreview = function(btn)
	local list = RF._partyPreviewButtons
	if btn.rfPartyPreview then
		return true
	end
	if list then
		for i = 1, #list do
			if list[i] == btn then
				return true
			end
		end
	end
	return false
end

-- Attached portrait: the Button file lays the bars from the button edges,
-- so the bars' horizontal anchors are moved off the portrait here (after
-- every RelayoutButton; idempotent: A's layout uses 0 x offsets).
PO.FixBars = function(btn)
	local d = btn.rf
	if not d then
		return
	end
	local l, r = RF.PortraitBarInsets(btn)
	local regions = { d.health, d.power, d.uniformRef, d.tnb }
	for i = 1, 4 do
		local reg = regions[i]
		if reg and reg:GetNumPoints() > 0 then
			local pts = {}
			for k = 1, reg:GetNumPoints() do
				local pt, rel, rp, x, y = reg:GetPoint(k)
				pts[k] = { pt, rel, rp, x, y }
			end
			reg:ClearAllPoints()
			for k = 1, #pts do
				local q = pts[k]
				local x = q[4] or 0
				if q[2] == btn then
					if q[1]:find("LEFT") then
						x = l
					elseif q[1]:find("RIGHT") then
						x = -r
					end
				end
				reg:SetPoint(q[1], q[2], q[3], x, q[5] or 0)
			end
		end
	end
end

PO.Apply = function(btn)
	local s = PO.Settings(btn)
	local style = s.partyPortraitStyle or "none"
	if btn.rfKind == "preview" and not PO.IsPartyPreview(btn) then
		style = "none"
	end
	local bd = btn.exPt
	if style == "none" then
		if bd and bd.on and bd.style == "attached" then
			bd.style = nil
			bd.on = nil
			PO.FixBars(btn)
		end
		if bd and bd.on then
			bd.on = nil
			bd:Hide()
			if bd.m then
				bd.m:ClearModel()
				bd.m:Hide()
			end
		end
		return
	end
	bd = PO.Ensure(btn)
	local side, inside = PO.SideOf(s, style)
	local bh = s.frameHeight or btn:GetHeight() or 40
	bd.style, bd.side = style, side
	PO.Seat(btn, bd, s, style, side, inside, bh)
	bd:SetFrameLevel(min(btn:GetFrameLevel() + (bd.lvl or 1), 127))
	local mode = s.partyPortraitMode or "2d"
	bd.mode = mode
	bd.pz, bd.cz = PO.Zoom3D(s.partyPortrait3dZoom)
	local art = (s.partyPortraitArtScale or 100) / 100
	local cut = 0.15 + (1 - art) * 0.35
	bd.t2:SetTexCoord(cut, 1 - cut, cut, 1 - cut)
	bd.t2:SetShown(mode == "2d")
	bd.tc:SetShown(mode == "class")
	if mode == "3d" then
		PO.Ensure3D(bd):Show()
		if inside then
			local k = (s.partyPortraitCharScale or 100) / 100
			bd.m:ClearAllPoints()
			if k == 1 then
				bd.m:SetAllPoints(bd)
			else
				bd.m:SetSize(bd.w * k, bd.h * k)
				bd.m:SetPoint("BOTTOM", bd, "BOTTOM", 0, 0)
			end
		else
			bd.m:ClearAllPoints()
			bd.m:SetAllPoints(bd)
		end
	elseif bd.m then
		bd.m:ClearModel()
		bd.m:Hide()
	end
	-- Background under square art; none under a bare model inside the bar.
	local shape = s.partyPortraitShape or "portrait"
	bd.bg:SetShown(not inside and (style == "attached" or shape ~= "none"))
	bd.bordered = style == "detached" and shape ~= "none" and not inside
	if bd.bordered then
		bd.border:Apply(s.partyPortraitBorderSize or 7, 0, 0, 0, (s.partyPortraitBorderOpacity or 100) / 100)
	else
		bd.border:Apply(0)
	end
	bd.on = true
	bd.guid = nil
	bd:Show()
	PO.FixBars(btn)
	local pv = btn.rfPreview
	PO.Paint(btn, PO.Unit(btn), true, type(pv) == "table" and pv.class or nil)
end

-- The Button file calls this once per party button (and preview frame).
function RF.PortraitInit(btn)
	if not btn or PO.list[btn] then
		return
	end
	-- Party buttons and preview frames (a preview frame shows a portrait
	-- only while it is in the party preview list, see PO.IsPartyPreview).
	local kind = btn.rfKind
	if kind ~= "party" and kind ~= "preview" then
		return
	end
	PO.list[btn] = true
	btn:HookScript("OnAttributeChanged", function(self, name)
		if name == "unit" and self.exPt and self.exPt.on then
			local u = PO.Unit(self)
			if u then
				PO.Paint(self, u, false)
			end
		end
	end)
	PO.Apply(btn)
end

-- Repaint (preview data changed, or a unit's art changed).
function RF.PortraitUpdate(btn)
	if btn and btn.exPt and btn.exPt.on then
		local pv = btn.rfPreview
		PO.Paint(btn, PO.Unit(btn), true, type(pv) == "table" and pv.class or nil)
	end
end

function RF.PortraitRefreshAll()
	local style = (P() and P().partyPortraitStyle) or "none"
	if style ~= PO.lastStyle then
		local first = PO.lastStyle == nil
		PO.lastStyle = style
		-- An attached portrait changes the party box width.
		if not first and RF.RequestLayout then
			RF.RequestLayout()
		end
	end
	for btn in pairs(PO.list) do
		PO.Apply(btn)
	end
	PO.SyncEvents()
end
RF.RF_PtRefreshAll = RF.PortraitRefreshAll

-- After the Button file re-lays a button: keep the bars off an attached
-- portrait, and repaint a preview frame's portrait (its fake member and its
-- view change on every preview paint). Wrapped here because the Button file
-- has no portrait hook in its layout.
do
	local relayout = RF.RelayoutButton
	if relayout then
		RF.RelayoutButton = function(btn, ...)
			relayout(btn, ...)
			if btn and PO.list[btn] then
				if btn.rfKind == "preview" then
					PO.Apply(btn)
				elseif btn.exPt and btn.exPt.on then
					PO.FixBars(btn)
				end
			end
		end
	end
end

PO.events = CreateFrame("Frame")
PO.events:SetScript("OnEvent", function(_, event, unit)
	for btn in pairs(PO.list) do
		local bd = btn.exPt
		if bd and bd.on then
			local u = PO.Unit(btn)
			if u and (event == "PLAYER_ENTERING_WORLD" or UnitIsUnit(u, unit)) then
				PO.Paint(btn, u, true)
			end
		end
	end
end)

PO.SyncEvents = function()
	local p = P()
	local on = p and (p.partyPortraitStyle or "none") ~= "none" and (p.partyPortraitMode or "2d") ~= "class"
	local ev = PO.events
	if on and not PO.evOn then
		ev:RegisterEvent("UNIT_PORTRAIT_UPDATE")
		ev:RegisterEvent("UNIT_MODEL_CHANGED")
		ev:RegisterEvent("PLAYER_ENTERING_WORLD")
		ev:RegisterEvent("UNIT_CONNECTION")
		PO.evOn = true
	elseif not on and PO.evOn then
		ev:UnregisterAllEvents()
		PO.evOn = nil
	end
end

-------------------------------------------------------------------------------
--  Healer Mana Text Display (retail EUI_RaidFrames_Extras.lua): one text
--  row per group healer (mana %), its own unlock element RF_HealerMana.
-------------------------------------------------------------------------------
local HM = { rows = {} }
RF._HM = HM

HM.Set = function()
	local p = P()
	if not p then
		return { mode = "none" }
	end
	local hm = p.healerMana
	if not hm then
		hm = { mode = "none" }
		p.healerMana = hm
	end
	return hm
end
RF._HMSet = HM.Set

function RF._HMActive()
	local mode = HM.Set().mode or "none"
	if mode == "none" then
		return false
	end
	if IsInRaid() then
		return mode == "raid" or mode == "both"
	end
	if IsInGroup() then
		return mode == "party" or mode == "both"
	end
	return false
end

HM.Place = function(c)
	local pos = HM.Set().unlockPos
	c:ClearAllPoints()
	if pos and pos.point then
		c:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
	else
		c:SetPoint("CENTER", UIParent, "CENTER", 320, 0)
	end
end

HM.Ensure = function()
	if HM.container then
		return HM.container
	end
	local c = CreateFrame("Frame", "ERF_HealerMana", UIParent)
	c:SetSize(50, 25)
	c:Hide()
	HM.container = c
	HM.Place(c)
	return c
end
RF._HMEnsureContainer = HM.Ensure

HM.Value = function(unit)
	local mx = UnitPowerMax(unit, 0) or 0
	if mx <= 0 then
		return 0
	end
	return floor((UnitPower(unit, 0) or 0) / mx * 100 + 0.5)
end

function RF._HMUpdateValue(unit)
	local r = HM.unitRows and HM.unitRows[unit]
	if r then
		r.valFS:SetFormattedText("%d", HM.Value(unit))
	end
end

function RF.HM_Rebuild()
	local hm = HM.Set()
	local preview = HM.preview
	if not RF._HMActive() and not preview then
		if HM.container then
			HM.container:Hide()
		end
		HM.unitRows = nil
		HM.SyncEvents()
		return
	end
	local container = HM.Ensure()
	local size = hm.textSize or 12
	local spacing = hm.spacing or 2
	local alignR = hm.align == "RIGHT"
	local alignC = hm.align == "CENTER"
	local growUp = hm.growth == "UP"
	local inRaid = IsInRaid()
	local showNames = (hm.showNames ~= false) and (inRaid or preview)
	local classNames = hm.classNames ~= false
	local powerMode = hm.colorMode == "power"
	local cc = hm.color
	local cr, cg, cb = (cc and cc.r) or 1, (cc and cc.g) or 1, (cc and cc.b) or 1
	local rowH = size + spacing
	local map = {}
	local count, widest = 0, 40
	local rows = HM.rows

	local function addRow(unit, fakeName, fakeClass, fakeVal)
		count = count + 1
		local r = rows[count]
		if not r then
			r = { nameFS = container:CreateFontString(nil, "OVERLAY"), valFS = container:CreateFontString(nil, "OVERLAY") }
			r.nameFS:SetWordWrap(false)
			r.valFS:SetWordWrap(false)
			rows[count] = r
		end
		r.unit = unit
		local nameFS, valFS = r.nameFS, r.valFS
		RF.SetFont(nameFS, size)
		RF.SetFont(valFS, size)
		if powerMode then
			local pr, pg, pb = RF.PowerColor("MANA")
			valFS:SetTextColor(pr, pg, pb, 1)
		else
			valFS:SetTextColor(cr, cg, cb, 1)
		end
		local nameW = 0
		if showNames then
			local nr, ng, nb = cr, cg, cb
			if classNames then
				local token = fakeClass
				if not token and unit then
					local _
					_, token = UnitClass(unit)
				end
				if token then
					nr, ng, nb = RF.ClassColor(token)
				end
			elseif powerMode then
				nr, ng, nb = 1, 1, 1
			end
			nameFS:SetTextColor(nr, ng, nb, 1)
			if fakeName then
				nameFS:SetText(fakeName)
			else
				local nm = unit and UnitName(unit)
				if nm and RF.FormatName then
					nm = RF.FormatName(nm, P())
				end
				nameFS:SetText(nm or "")
			end
			nameFS:Show()
			nameW = nameFS:GetStringWidth() or size * 5
		else
			nameFS:SetText("")
			nameFS:Hide()
		end
		local valEst = size * 2.2
		local rowW = (showNames and (nameW + 4) or 0) + valEst
		if rowW > widest then
			widest = rowW
		end
		local yOff = (growUp and 1 or -1) * (count - 1) * rowH
		local pCorner = growUp and "BOTTOMLEFT" or "TOPLEFT"
		local pCornerR = growUp and "BOTTOMRIGHT" or "TOPRIGHT"
		local pEdge = growUp and "BOTTOM" or "TOP"
		nameFS:ClearAllPoints()
		valFS:ClearAllPoints()
		if alignC then
			if showNames then
				nameFS:SetPoint(pCorner, container, pEdge, -rowW / 2, yOff)
				valFS:SetPoint("LEFT", nameFS, "RIGHT", 4, 0)
				valFS:SetJustifyH("LEFT")
			else
				valFS:SetPoint(pEdge, container, pEdge, 0, yOff)
				valFS:SetJustifyH("CENTER")
			end
		elseif alignR then
			valFS:SetPoint(pCornerR, container, pCornerR, 0, yOff)
			valFS:SetJustifyH("RIGHT")
			if showNames then
				nameFS:SetPoint("RIGHT", valFS, "LEFT", -4, 0)
			end
		else
			if showNames then
				nameFS:SetPoint(pCorner, container, pCorner, 0, yOff)
				valFS:SetPoint("LEFT", nameFS, "RIGHT", 4, 0)
			else
				valFS:SetPoint(pCorner, container, pCorner, 0, yOff)
			end
			valFS:SetJustifyH("LEFT")
		end
		if fakeVal then
			valFS:SetFormattedText("%d", fakeVal)
		end
		valFS:Show()
		if unit then
			map[unit] = r
		end
	end

	if preview then
		addRow(nil, "Thaldris", "PRIEST", 84)
		addRow(nil, "Kaelyra", "SHAMAN", 67)
		addRow(nil, "Morwenn", "DRUID", 92)
	elseif inRaid then
		for i = 1, 40 do
			local unit = "raid" .. i
			if UnitExists(unit) and RF.UnitRole(unit) == "HEALER" then
				addRow(unit)
			end
		end
	else
		if RF.UnitRole("player") == "HEALER" then
			addRow("player")
		end
		for i = 1, 4 do
			local unit = "party" .. i
			if UnitExists(unit) and RF.UnitRole(unit) == "HEALER" then
				addRow(unit)
			end
		end
	end
	for i = count + 1, #rows do
		rows[i].nameFS:Hide()
		rows[i].valFS:Hide()
		rows[i].unit = nil
	end
	HM.unitRows = (not preview and count > 0) and map or nil
	if count > 0 then
		container:SetSize(max(widest, 50), max(count * rowH - spacing, 25))
		container:Show()
		if not preview then
			for unit in pairs(map) do
				RF._HMUpdateValue(unit)
			end
		end
	else
		container:Hide()
	end
	HM.SyncEvents()
end

function RF.HM_SetPreview(on)
	HM.preview = on and true or nil
	RF.HM_Rebuild()
end

-- Mana events only while rows exist; roster / role edges rebuild.
HM.events = CreateFrame("Frame")
HM.events:SetScript("OnEvent", function(_, event, unit)
	if event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER" then
		RF._HMUpdateValue(unit)
	else
		RF.HM_Rebuild()
	end
end)
HM.roster = CreateFrame("Frame")
HM.roster:RegisterEvent("GROUP_ROSTER_UPDATE")
HM.roster:RegisterEvent("PLAYER_ROLES_ASSIGNED")
HM.roster:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
HM.roster:RegisterEvent("PLAYER_ENTERING_WORLD")
HM.roster:SetScript("OnEvent", function()
	if ERF.started and P() then
		RF.HM_Rebuild()
	end
end)

HM.SyncEvents = function()
	local on = HM.unitRows ~= nil
	if on and not HM.evOn then
		HM.events:RegisterEvent("UNIT_POWER_FREQUENT")
		HM.events:RegisterEvent("UNIT_MAXPOWER")
		HM.evOn = true
	elseif not on and HM.evOn then
		HM.events:UnregisterAllEvents()
		HM.evOn = nil
	end
end

-- Unlock Mode element (retail RF_HealerMana).
HM.RegisterUnlock = function()
	if not (ns.RegisterUnlockElements and ns.MakeUnlockElement) then
		return
	end
	ns:RegisterUnlockElements({
		ns.MakeUnlockElement({
			key = "RF_HealerMana",
			label = "Healer Mana Display",
			group = "Raid Frames",
			order = 502,
			noResize = true,
			isHidden = function()
				local hm = HM.Set()
				return (hm.mode or "none") == "none"
			end,
			getFrame = function()
				return HM.container or HM.Ensure()
			end,
			getSize = function()
				local c = HM.container
				if c then
					return c:GetWidth(), c:GetHeight()
				end
				return 50, 25
			end,
			savePos = function(_, point, relPoint, x, y)
				if not point then
					return
				end
				HM.Set().unlockPos = { point = point, relPoint = relPoint or point, x = Snap(x), y = Snap(y) }
			end,
			loadPos = function()
				return HM.Set().unlockPos
			end,
			clearPos = function()
				HM.Set().unlockPos = nil
			end,
			applyPos = function()
				if HM.container then
					HM.Place(HM.container)
				end
			end,
		}),
	}, addonName)
end
RF._RFRegisterHMUnlock = HM.RegisterUnlock

-------------------------------------------------------------------------------
--  Apply (settings change, profile swap) and the standing events
-------------------------------------------------------------------------------
function RF.Extras_ReAnchor()
	if InCombatLockdown() then
		RF.AfterCombat("EX_ReAnchor", RF.Extras_ReAnchor)
		return
	end
	if XF.built and XF.container:IsShown() then
		FB.Anchor(XF)
	end
	if FB.built then
		FB.Anchor()
	end
	RF.PF_ReAnchor()
end

function RF.Extras_ApplyAll()
	if not P() then
		return
	end
	SafeCall(RF.XF_Apply)
	SafeCall(RF.FB_Apply)
	SafeCall(RF.PT_Apply)
	SafeCall(RF.PF_Apply)
	SafeCall(RF.PortraitRefreshAll)
	SafeCall(RF.HM_Rebuild)
	if HM.container and not ns._unlockActive then
		HM.Place(HM.container)
	end
end

RF.OnApply(function()
	RF.Extras_ApplyAll()
end, 40)

-- The headers file re-laid its raid or party frames (out of combat): the
-- groups attached beside them follow; a new raid tier size re-sizes the
-- extra frames, a new party layout the party target frames.
if RF.OnLayout then
	RF.OnLayout(function(kind)
		if not (ERF.started and P()) or InCombatLockdown() then
			return
		end
		if kind == "raid" and XF.built and XF.container:IsShown() then
			XF.Layout()
		end
		if kind == "party" then
			if PT.enabled then
				RF.PT_Layout()
			end
			if PF.ownerActive or PF.OwnerChosen() then
				PF.OwnerApply()
			end
		end
		RF.Extras_ReAnchor()
	end)
end

do
	local ev = CreateFrame("Frame")
	ev:RegisterEvent("PLAYER_LOGIN")
	ev:RegisterEvent("GROUP_ROSTER_UPDATE")
	ev:RegisterEvent("PLAYER_ROLES_ASSIGNED")
	ev:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
	ev:RegisterEvent("PLAYER_REGEN_ENABLED")
	ev:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
	ev:RegisterEvent("PLAYER_TARGET_CHANGED")
	ev:RegisterEvent("UNIT_PET")
	local pending = false
	local function Roster()
		pending = false
		if not (ERF.started and P()) then
			return
		end
		if InCombatLockdown() then
			XF.applyDirty, FB.applyDirty, PF.applyDirty, PT.applyDirty = true, true, true, true
			return
		end
		RF.XF_Apply()
		RF.FB_Apply()
		RF.PT_Apply()
		RF.PF_Apply()
	end
	ev:SetScript("OnEvent", function(_, event, unit)
		if event == "PLAYER_LOGIN" then
			HM.RegisterUnlock()
			local key = EllesmereUIDB and EllesmereUIDB.extraFramesKey
			if key then
				RF.XF_SetKey(key)
			end
			return
		end
		if not (ERF.started and P()) then
			return
		end
		if event == "PLAYER_REGEN_ENABLED" then
			if XF.keyDirty then
				XF.keyDirty = nil
				RF.XF_SetKey(EllesmereUIDB and EllesmereUIDB.extraFramesKey)
			end
			if XF.applyDirty then
				XF.applyDirty = nil
				RF.XF_Apply()
			end
			if FB.applyDirty then
				FB.applyDirty = nil
				RF.FB_Apply()
			end
			if PT.applyDirty then
				PT.applyDirty = nil
				RF.PT_Apply()
			end
			if PT.layoutDirty then
				RF.PT_Layout()
			end
			if PF.applyDirty then
				PF.applyDirty = nil
				RF.PF_Apply()
			end
			if FB.anchorDirty then
				FB.anchorDirty = nil
				FB.Anchor()
			end
			if XF.anchorDirty then
				XF.anchorDirty = nil
				FB.Anchor(XF)
			end
			if PF.anchorDirty then
				PF.anchorDirty = nil
				FB.Anchor(PF)
			end
		elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
			RF.FB_Apply()
		elseif event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
			if FB.built then
				for _, b in ipairs(FB.buttons) do
					if b:IsVisible() then
						FB.Update(b)
					end
				end
			end
		elseif event == "PLAYER_TARGET_CHANGED" then
			for _, b in ipairs(FB.buttons) do
				if b:IsVisible() and V.ReadTarget(b, UnitOf(b)) then
					V.BorderColor(b)
				end
			end
			PF.EachShown(function(b)
				if V.ReadTarget(b, UnitOf(b)) then
					V.BorderColor(b)
				end
			end)
		elseif event == "UNIT_PET" then
			PF.EachShown(PF.Refresh)
			if PF.ownerActive then
				RF.AfterCombat("PF_FixSelf", function()
					for _, b in ipairs(PF.ownerButtons) do
						PF.FixSelf(b)
					end
				end)
			end
		elseif not pending then
			-- Roster / roles: one pass on the next frame, after the headers
			-- re-assigned their buttons.
			pending = true
			RF.After(0.05, Roster)
		end
	end)
end

-- Pet unit events: health / name of the pet tokens on our pet buttons.
do
	local ev = CreateFrame("Frame")
	ev:RegisterEvent("UNIT_HEALTH")
	ev:RegisterEvent("UNIT_MAXHEALTH")
	ev:RegisterEvent("UNIT_NAME_UPDATE")
	ev:SetScript("OnEvent", function(_, _, unit)
		if not (PF.active or PF.ownerActive) or not unit or not unit:find("pet", 1, true) then
			return
		end
		PF.EachShown(function(b)
			if UnitOf(b) == unit then
				V.Update(b)
			end
		end)
	end)
end
