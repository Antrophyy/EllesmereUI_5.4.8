-------------------------------------------------------------------------------
--  EUI_RaidFrames_Button.lua  (5.4.8 port of the retail Raid Frames button:
--  EUI_RaidFrames_Style.lua StyleButton, EUI_RaidFrames_Update.lua
--  UpdateButton / _PaintPower / _PaintButtonTail / _UpdateButtonHealth,
--  EUI_RaidFrames_Colors.lua and EUI_RaidFrames_Absorb.lua)
--
--  The look and the live state of ONE unit button: health and power bars,
--  absorbs, heal absorbs, heal prediction, the Absorb Bar strips, the Top
--  Name Bar, texts, borders (base, hover, target, threat), dispel visuals,
--  indicators (role, leader, raid marker, ready check, incoming rez,
--  combat), range alpha and the unit tooltip.
--
--  Retail draws absorbs with clip frames, masks and secret-safe StatusBar
--  fills because 12.x values are secret. 5.4.8 values are plain numbers, so
--  here every overlay is a texture placed by Lua along the health bar axis
--  (Seg below), from the bar's displayed value (smooth bars included).
--
--  Contract (see the port brief): RF.StyleButton, RF.UpdateButton,
--  RF.RelayoutButton, RF.ForEachButton, RF.ButtonsForUnit, RF.UnitOf,
--  RF.UpdateDispelVisuals. Visual parts live in btn.rf (a table).
-------------------------------------------------------------------------------
local addonName, RF = ...
local ns = EllesmereUI
local ERF = RF.ERF

local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local pairs, ipairs, type, next, tostring = pairs, ipairs, type, next, tostring
local format = string.format

-- Internals shared by the functions below (kept on a table: Lua 5.1 local cap).
local B = {}
RF._Btn = B

local WHITE = RF.WHITE
local SPARK = "Interface\\CastingBar\\UI-CastingBar-Spark"
local COMBAT_MEDIA = "Interface\\AddOns\\EllesmereUIUnitFrames\\media\\combat\\"
local RAID_ICONS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local READY_TEX = {
	ready = "Interface\\RaidFrame\\ReadyCheck-Ready",
	notready = "Interface\\RaidFrame\\ReadyCheck-NotReady",
	waiting = "Interface\\RaidFrame\\ReadyCheck-Waiting",
}
local REZ_TEX = "Interface\\RaidFrame\\Raid-Icon-Rez"
-- Retail uses the 12.x RaidFrame-Icon-Debuff* atlases; 5.4.8 has the same art as files.
local DISPEL_ICON_TEX = {
	Magic = "Interface\\RaidFrame\\Raid-Icon-DebuffMagic",
	Curse = "Interface\\RaidFrame\\Raid-Icon-DebuffCurse",
	Disease = "Interface\\RaidFrame\\Raid-Icon-DebuffDisease",
	Poison = "Interface\\RaidFrame\\Raid-Icon-DebuffPoison",
}
-- Class sprite of the Unit Frames "class" combat icon (EllesmereUIUnitFrames media).
local CLASS_SPRITE = {
	WARRIOR = { 0, 0.125, 0, 0.125 }, MAGE = { 0.125, 0.25, 0, 0.125 }, ROGUE = { 0.25, 0.375, 0, 0.125 },
	DRUID = { 0.375, 0.5, 0, 0.125 }, HUNTER = { 0, 0.125, 0.125, 0.25 }, SHAMAN = { 0.125, 0.25, 0.125, 0.25 },
	PRIEST = { 0.25, 0.375, 0.125, 0.25 }, WARLOCK = { 0.375, 0.5, 0.125, 0.25 }, PALADIN = { 0, 0.125, 0.25, 0.375 },
	DEATHKNIGHT = { 0.125, 0.25, 0.25, 0.375 }, MONK = { 0.25, 0.375, 0.25, 0.375 },
}

-- Retail THREAT_ACTIVE: aggro only (status 2 / 3).
local THREAT_ACTIVE = { [2] = true, [3] = true }

-------------------------------------------------------------------------------
--  Registry: styled buttons and the unit -> buttons map
-------------------------------------------------------------------------------
local allButtons = {}   -- [btn] = true
local unitMap = {}      -- [unit] = { [btn] = true }
local btnUnits = {}     -- [btn] = { unit1, alias... } (tokens it is mapped under)
local EMPTY = setmetatable({}, { __newindex = function() end })
B.allButtons, B.unitMap = allButtons, unitMap

local inCombat = false
local inBossCombat = false

local function MapAdd(unit, btn)
	local set = unitMap[unit]
	if not set then
		set = {}
		unitMap[unit] = set
	end
	set[btn] = true
end

-- Keeps unitMap current for one button: its unit attribute plus the
-- "player" / "pet" aliases (5.4.8 fires the player's own events as "player").
function B.Remap(btn)
	local old = btnUnits[btn]
	if old then
		for i = 1, #old do
			local set = unitMap[old[i]]
			if set then
				set[btn] = nil
				if not next(set) then
					unitMap[old[i]] = nil
				end
			end
		end
	end
	local list = nil
	if not btn.rfPreview then
		local unit = btn:GetAttribute("unit")
		if unit and unit ~= "" then
			list = { unit }
			MapAdd(unit, btn)
			if unit ~= "player" and UnitExists(unit) and UnitIsUnit(unit, "player") then
				list[#list + 1] = "player"
				MapAdd("player", btn)
			elseif unit ~= "pet" and UnitExists(unit) and UnitExists("pet") and UnitIsUnit(unit, "pet") then
				list[#list + 1] = "pet"
				MapAdd("pet", btn)
			end
		end
	end
	btnUnits[btn] = list
end

-- { [btn] = true } of the buttons showing unit (never nil; may be empty).
function RF.ButtonsForUnit(unit)
	return (unit and unitMap[unit]) or EMPTY
end

-- The unit a button shows, or nil (no unit, unit gone, preview button).
function RF.UnitOf(btn)
	if not btn or btn.rfPreview then
		return nil
	end
	local unit = btn:GetAttribute("unit")
	if unit and unit ~= "" and UnitExists(unit) then
		return unit
	end
	return nil
end

-- Every styled button (raid, party, extras, preview).
function RF.ForEachButton(fn)
	for btn in pairs(allButtons) do
		fn(btn)
	end
end

-------------------------------------------------------------------------------
--  Small helpers
-------------------------------------------------------------------------------
local function Snap(v, f)
	return RF.Snap(v or 0, f)
end

local function Col(c, r, g, b)
	if type(c) == "table" then
		return c.r or r or 1, c.g or g or 1, c.b or b or 1
	end
	return r or 1, g or 1, b or 1
end

-- 9-point text anchors (retail AnchorRFText: 2px insets from the bar edge).
local TXT = {
	topleft = { "TOPLEFT", 2, -2, "LEFT", "TOP" },
	top = { "TOP", 0, -2, "CENTER", "TOP" },
	topright = { "TOPRIGHT", -2, -2, "RIGHT", "TOP" },
	left = { "LEFT", 2, 0, "LEFT", "MIDDLE" },
	center = { "CENTER", 0, 0, "CENTER", "MIDDLE" },
	right = { "RIGHT", -2, 0, "RIGHT", "MIDDLE" },
	bottomleft = { "BOTTOMLEFT", 2, 2, "LEFT", "BOTTOM" },
	bottom = { "BOTTOM", 0, 2, "CENTER", "BOTTOM" },
	bottomright = { "BOTTOMRIGHT", -2, 2, "RIGHT", "BOTTOM" },
}
RF.RF_TEXT_ANCHORS = TXT

-- Anchor a FontString (or texture with noJustify) on host at a retail position key.
function RF.AnchorRFText(fs, host, pos, ox, oy, width, noJustify)
	if not fs or not host then
		return
	end
	local a = TXT[pos or "center"] or TXT.center
	fs:ClearAllPoints()
	if width then
		fs:SetWidth(max(1, width))
		if not noJustify then
			fs:SetHeight(0)
		end
	end
	fs:SetPoint(a[1], host, a[1], a[2] + (ox or 0), a[3] + (oy or 0))
	if not noJustify then
		fs:SetJustifyH(a[4])
		fs:SetJustifyV(a[5])
		local t = fs:GetText()
		fs:SetText("")
		fs:SetText(t or "")
	end
end

-- Anchor host per Uniform Icon Anchoring (retail RF_AnchorHost).
local function AnchorHost(d, s)
	if s.powerUniformAnchors and d.uniformRef then
		return d.uniformRef
	end
	return d.health
end

-------------------------------------------------------------------------------
--  Retail colour / name helpers (EUI_RaidFrames_Colors.lua)
-------------------------------------------------------------------------------
local DEF_DYN100 = { r = 0, g = 1, b = 0 }
local DEF_DYN50 = { r = 0xEC / 255, g = 0xEC / 255, b = 0x32 / 255 }
local DEF_DYN0 = { r = 0xE3 / 255, g = 0x30 / 255, b = 0x30 / 255 }

-- Custom Dynamic Colors at health pct01 (retail ResolveDynamicColor).
function RF.ResolveDynamicColor(s, pct01)
	local c0 = s.dynamicColor0 or DEF_DYN0
	local c50 = s.dynamicColor50 or DEF_DYN50
	local c100 = s.dynamicColor100 or DEF_DYN100
	if pct01 >= 0.5 then
		local t = (pct01 - 0.5) * 2
		return c50.r + (c100.r - c50.r) * t, c50.g + (c100.g - c50.g) * t, c50.b + (c100.b - c50.b) * t
	end
	local t = pct01 * 2
	return c0.r + (c50.r - c0.r) * t, c0.g + (c50.g - c0.g) * t, c0.b + (c50.b - c0.b) * t
end

-- Class Color Reactive at pct01 (retail ResolveClassReactiveColor).
function RF.ResolveClassReactiveColor(s, class, pct01)
	local cr, cg, cb = 0.5, 0.5, 0.5
	if class then
		cr, cg, cb = RF.ClassColor(class)
	end
	local c0 = s.dynamicColor0 or DEF_DYN0
	local c50 = s.dynamicColor50 or DEF_DYN50
	if pct01 >= 0.4 then
		local w
		if pct01 >= 0.75 then
			w = 0.75 + (pct01 - 0.75)
		else
			w = (pct01 - 0.4) / 0.35 * 0.75
		end
		return c50.r + (cr - c50.r) * w, c50.g + (cg - c50.g) * w, c50.b + (cb - c50.b) * w
	end
	local t = pct01 / 0.4
	return c0.r + (c50.r - c0.r) * t, c0.g + (c50.g - c0.g) * t, c0.b + (c50.b - c0.b) * t
end

-- Health fill colour (retail GetHealthColor) for a class token and a 0-1 percent.
function RF.GetHealthColor(s, class, pct01)
	local mode = s.healthColorMode or "class"
	if mode == "dark" then
		local f = RF.DARK_FILL
		return f[1], f[2], f[3]
	elseif mode == "classic" then
		-- Retail curve: red 0% -> yellow 50% -> green 100%.
		if pct01 >= 0.5 then
			return 1 - (pct01 - 0.5) * 2, 1, 0
		end
		return 1, pct01 * 2, 0
	elseif mode == "customDynamic" then
		return RF.ResolveDynamicColor(s, pct01)
	elseif mode == "classReactive" then
		if not class then
			return 0.5, 0.5, 0.5
		end
		return RF.ResolveClassReactiveColor(s, class, pct01)
	elseif mode == "custom" then
		return Col(s.customFillColor, 37 / 255, 193 / 255, 29 / 255)
	end
	if class then
		return RF.ClassColor(class)
	end
	return 0.5, 0.5, 0.5
end

-- Background colour (retail GetBgColor): class colour or custom, alpha bgDarkness.
function RF.GetBgColor(s, class)
	local a = (s.bgDarkness or 50) / 100
	if s.bgClassColored and class then
		local r, g, b = RF.ClassColor(class)
		return r, g, b, a
	end
	local r, g, b = Col(s.customBgColor, 17 / 255, 17 / 255, 17 / 255)
	return r, g, b, a
end

-- A text colour by mode: "class" / "accent" / "custom" / "power".
local function TextColor(mode, custom, class, defR, defG, defB, pr, pg, pb)
	if mode == "accent" then
		return RF.Accent()
	elseif mode == "class" then
		if class then
			return RF.ClassColor(class)
		end
		return defR, defG, defB
	elseif mode == "power" and pr then
		return pr, pg, pb
	end
	if type(custom) == "table" then
		return custom.r or defR, custom.g or defG, custom.b or defB
	end
	return defR, defG, defB
end
RF.RF_TextColor = TextColor

-- UTF-8 aware name cap (retail CapName); nameMaxLength 0 = off.
function RF.CapName(display, s)
	if type(display) ~= "string" or display == "" then
		return display
	end
	local maxLen = s and s.nameMaxLength or 15
	if not maxLen or maxLen <= 0 then
		return display
	end
	maxLen = floor(maxLen + 0.5)
	local bytes = #display
	local i, chars, endByte = 1, 0, nil
	while i <= bytes do
		local b = display:byte(i)
		local sz = (b < 128 and 1) or (b < 224 and 2) or (b < 240 and 3) or 4
		chars = chars + 1
		if chars == maxLen then
			endByte = i + sz - 1
			break
		end
		i = i + sz
	end
	if endByte and endByte < bytes then
		return display:sub(1, endByte)
	end
	return display
end

-- Display name of a unit (short name; retail nickname providers do not exist
-- on 5.4.8). applyCap = the in-frame name cap.
function RF.ResolveDisplayName(unit, applyCap, s, previewName)
	local name = previewName
	if not name and unit then
		name = UnitName(unit)
		if name and Ambiguate then
			name = Ambiguate(name, "short")
		end
	end
	name = name or ""
	if applyCap then
		name = RF.CapName(name, s)
	end
	return name
end

-- Level Text "Attach to Name" formats (retail RF_LEVEL_ATTACH).
RF.RF_LEVEL_ATTACH = {
	name = { "%d %s", "?? %s" },
	nameDiv = { "%d | %s", "?? | %s" },
}
RF.RF_LEVEL_DEFAULT = "none"

local function NameWithLevel(fs, name, lvl, fmt)
	if not name or name == "" then
		fs:SetText(name or "")
	elseif not lvl or lvl == 0 then
		fs:SetText(name)
	elseif lvl < 0 then
		fs:SetFormattedText(fmt[2], name)
	else
		fs:SetFormattedText(fmt[1], lvl, name)
	end
end

-- Health text (retail RF_HealthTextInto) from plain values.
function RF.RF_HealthTextInto(fs, mode, pct, cur, maxHP)
	if mode == "percent" then
		fs:SetFormattedText("%.0f%%", pct)
	elseif mode == "percentNoSign" then
		fs:SetFormattedText("%.0f", pct)
	elseif mode == "number" then
		fs:SetText(RF.Abbrev(cur or 0))
	elseif mode == "numberPercent" then
		fs:SetFormattedText("%s | %.0f%%", RF.Abbrev(cur or 0), pct)
	elseif mode == "percentNumber" then
		fs:SetFormattedText("%.0f%% | %s", pct, RF.Abbrev(cur or 0))
	elseif mode == "missing" then
		local miss = max(0, (maxHP or 0) - (cur or 0))
		if miss > 0 then
			fs:SetText(RF.Abbrev(miss))
		else
			fs:SetText("")
		end
	else
		fs:SetText("")
		return false
	end
	return true
end

-- Power text (retail RF_PowerTextInto).
function RF.RF_PowerTextInto(fs, mode, pct, cur)
	if mode == "percent" then
		fs:SetFormattedText("%.0f%%", pct)
	elseif mode == "percentNoSign" then
		fs:SetFormattedText("%.0f", pct)
	elseif mode == "number" then
		fs:SetText(RF.Abbrev(cur or 0))
	elseif mode == "numberPercent" then
		fs:SetFormattedText("%s | %.0f%%", RF.Abbrev(cur or 0), pct)
	elseif mode == "percentNumber" then
		fs:SetFormattedText("%.0f%% | %s", pct, RF.Abbrev(cur or 0))
	else
		fs:SetText("")
		return false
	end
	return true
end

-- Heal absorb text (retail FormatHealAbsorbInto): blank at zero.
function RF.FormatHealAbsorbInto(fs, amt, mode)
	if not mode or mode == "none" or not amt or amt <= 0 then
		fs:SetText("")
		return
	end
	if mode == "short" then
		fs:SetText(RF.Abbrev(amt))
	else
		fs:SetText(tostring(floor(amt + 0.5)))
	end
end

-------------------------------------------------------------------------------
--  Tooltip mode (retail ns._ResolveTooltipMode / RaidFrameTooltipAllowed)
-------------------------------------------------------------------------------
function RF._ResolveTooltipMode(s)
	if not s then
		return "outOfCombat"
	end
	local m = s.tooltipMode
	if m ~= nil then
		return m
	end
	if s.showTooltip == false then
		return "never"
	end
	if EllesmereUIDB and EllesmereUIDB.showUnitTooltipsInCombat then
		return "always"
	end
	return "outOfCombat"
end

function RF.RaidFrameTooltipAllowed(btn)
	local s = RF.SettingsFor(btn)
	local mode = RF._ResolveTooltipMode(s)
	if mode == "never" then
		return false
	end
	if mode == "outOfCombat" and inCombat then
		return false
	end
	if mode == "outOfBossCombat" and inBossCombat then
		return false
	end
	return true
end

-- Color Custom Borders gate (retail RF_CustomBorderOn): a non-Solid Border
-- Style with a size. 5.4.8 draws every border Solid, but the saved style
-- still gates the recolor options like retail.
function RF.RF_CustomBorderOn(s)
	local tex = s and s.borderTexture
	if tex == nil or tex == "" or tex == "solid" then
		return false
	end
	return (s.borderSize or 1) > 0
end

-------------------------------------------------------------------------------
--  Data source: the live unit, or btn.rfPreview (settings preview)
-------------------------------------------------------------------------------
local function PowerTokenOf(pType, pToken)
	if type(pToken) == "string" then
		return pToken
	end
	return RF.POWER_TOKENS[pType or 0] or "MANA"
end

-- Fills d.info for the current paint. Returns it, or nil when there is
-- nothing to paint (no unit, no preview).
function B.Gather(btn, d, part)
	local i = d.info
	local p = btn.rfPreview
	if type(p) == "table" then
		i.unit = nil
		i.preview = true
		i.name = p.name or "Member"
		i.class = p.class
		i.role = p.role or "DAMAGER"
		i.hpMax = p.hpMax or 100
		i.hp = min(p.hp or i.hpMax, i.hpMax)
		i.powerMax = p.powerMax or 100
		i.power = p.power or i.powerMax
		i.powerToken = p.powerToken or PowerTokenOf(type(p.powerType) == "number" and p.powerType or nil, p.powerType)
		i.absorb = p.absorb or 0
		i.healAbsorb = p.healAbsorb or 0
		i.incoming = p.incomingHeal or 0
		i.dead = p.dead and true or false
		i.offline = p.offline and true or false
		i.afk = p.afk and true or false
		i.level = p.level or (UnitLevel and UnitLevel("player")) or 90
		i.leader = p.leader and true or false
		i.assist = p.assist and true or false
		i.marker = p.raidMarker
		i.oor = p.outOfRange and true or false
		i.readyCheck = p.readyCheck
		i.inCombat = p.inCombat and true or false
		i.threat = p.threat
		i.isTarget = false
		i.rez = false
		return i
	end
	local unit = RF.UnitOf(btn)
	if not unit then
		return nil
	end
	-- part: nil = everything, "hp" = health side only, "pw" = power side
	-- only (the frequent unit events read just what they paint).
	i.unit = unit
	i.preview = false
	i.name = nil
	local _, class = UnitClass(unit)
	i.class = class
	i.offline = not UnitIsConnected(unit)
	i.dead = UnitIsDeadOrGhost(unit) and true or false
	if part ~= "pw" then
		i.hpMax = UnitHealthMax(unit) or 0
		i.hp = UnitHealth(unit) or 0
		i.absorb = (UnitGetTotalAbsorbs and UnitGetTotalAbsorbs(unit)) or 0
		i.healAbsorb = (UnitGetTotalHealAbsorbs and UnitGetTotalHealAbsorbs(unit)) or 0
		i.incoming = (UnitGetIncomingHeals and UnitGetIncomingHeals(unit)) or 0
		i.afk = UnitIsAFK(unit) and true or false
		i.rez = i.dead and B.RezShown(unit) or false
	end
	if part ~= "hp" then
		i.role = RF.UnitRole(unit)
		local pType, pToken = UnitPowerType(unit)
		i.powerToken = PowerTokenOf(pType, pToken)
		i.powerMax = UnitPowerMax(unit, pType) or 0
		i.power = UnitPower(unit, pType) or 0
	end
	if part == nil then
		i.level = UnitLevel(unit) or 0
		i.leader = UnitIsGroupLeader(unit) and true or false
		i.assist = UnitIsGroupAssistant(unit) and true or false
		i.marker = GetRaidTargetIndex(unit)
		i.oor = false
		i.readyCheck = B.ReadyStatus(unit)
		i.inCombat = UnitAffectingCombat(unit) and true or false
		i.threat = UnitThreatSituation(unit)
		i.isTarget = UnitIsUnit(unit, "target") and true or false
	end
	return i
end

-------------------------------------------------------------------------------
--  Smooth bars (retail StatusBar interpolation ExponentialEaseOut; 5.4.8
--  has none, so one OnUpdate eases every smoothed bar)
-------------------------------------------------------------------------------
local smoothing = {}   -- [btn] = true while a bar of btn eases
local smoothFrame = CreateFrame("Frame")
smoothFrame:Hide()
smoothFrame:SetScript("OnUpdate", function(self, elapsed)
	local k = min(1, (elapsed or 0) * 12)
	for btn in pairs(smoothing) do
		local d = btn.rf
		local busy = false
		if d.hpGoal and d.seam == nil then
			d.seam = d.hpGoal
			B.PushHealthValue(d)
			B.Geometry(btn, d)
		elseif d.hpGoal and d.seam ~= d.hpGoal then
			local diff = d.hpGoal - d.seam
			if abs(diff) < 0.002 then
				d.seam = d.hpGoal
			else
				d.seam = d.seam + diff * k
				busy = true
			end
			B.PushHealthValue(d)
			B.Geometry(btn, d)
		end
		if d.pwGoal and d.pwShown == nil then
			d.pwShown = d.pwGoal
			d.power:SetValue(d.pwShown)
		elseif d.pwGoal and d.pwShown ~= d.pwGoal then
			local diff = d.pwGoal - d.pwShown
			if abs(diff) < 0.002 then
				d.pwShown = d.pwGoal
			else
				d.pwShown = d.pwShown + diff * k
				busy = true
			end
			d.power:SetValue(d.pwShown)
		end
		if not busy then
			smoothing[btn] = nil
		end
	end
	if not next(smoothing) then
		self:Hide()
	end
end)

-- Health bar value from the seam (current health fraction). Inverted Fill
-- paints missing health: the bar holds 1 - seam and fills from the far edge.
function B.PushHealthValue(d)
	local v = d.seam or 1
	if d.inv then
		v = d.deadInv and 1 or (1 - v)
	end
	d.health:SetValue(v)
end

function B.SetHealthGoal(btn, d, pct01, smooth)
	d.hpGoal = pct01
	if not smooth or d.seam == nil then
		d.seam = pct01
		smoothing[btn] = d.pwGoal and d.pwShown ~= d.pwGoal and true or nil
		B.PushHealthValue(d)
		return
	end
	if d.seam ~= pct01 then
		smoothing[btn] = true
		smoothFrame:Show()
	end
end

function B.SetPowerGoal(btn, d, v, smooth)
	d.pwGoal = v
	if not smooth or d.pwShown == nil then
		d.pwShown = v
		d.power:SetValue(v)
		return
	end
	if d.pwShown ~= v then
		smoothing[btn] = true
		smoothFrame:Show()
	end
end

-------------------------------------------------------------------------------
--  Segment textures along the health bar axis (absorbs, heal absorb, heal
--  prediction, alive background, dispel fill). a / b: fractions of the bar
--  from its origin edge (left, or bottom on a vertical bar).
-------------------------------------------------------------------------------
local function Seg(tex, bar, vert, a, b)
	if not a or not b or b - a <= 0.0005 then
		tex:Hide()
		return
	end
	local W, H = bar:GetWidth() or 0, bar:GetHeight() or 0
	tex:ClearAllPoints()
	if vert then
		tex:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, a * H)
		tex:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, b * H)
	else
		tex:SetPoint("TOPLEFT", bar, "TOPLEFT", a * W, 0)
		tex:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", b * W, 0)
	end
	local mode = tex.rfMode
	if mode == "tiled" then
		-- Tiled stripes repeat at native size on both axes (never rotated).
		local len = (b - a) * (vert and H or W)
		if vert then
			tex:SetTexCoord(0, max(0.01, W / 256), 0, max(0.01, len / 128))
		else
			tex:SetTexCoord(0, max(0.01, len / 256), 0, max(0.01, H / 128))
		end
	elseif mode == "stretch" then
		-- One image over the whole bar, showing the slice under the segment.
		if vert then
			tex:SetTexCoord(b, 0, a, 0, b, 1, a, 1)
		else
			tex:SetTexCoord(a, b, 0, 1)
		end
	end
	tex:Show()
end
B.Seg = Seg

-- Texture + tint for an overlay style ("clean" = flat white).
local function StyleOverlay(tex, style, r, g, b, a)
	local tiled = RF.ABSORB_TILED[style] and true or false
	local path = RF.AbsorbTexture(style)
	if tiled then
		tex:SetTexture(path, true)
		tex:SetHorizTile(true)
		tex:SetVertTile(true)
		tex.rfMode = "tiled"
	else
		tex:SetTexture(path)
		tex:SetHorizTile(false)
		tex:SetVertTile(false)
		tex.rfMode = (path == WHITE) and "flat" or "stretch"
		tex:SetTexCoord(0, 1, 0, 1)
	end
	tex:SetVertexColor(r, g, b, a)
end
B.StyleOverlay = StyleOverlay

-- Places every axis-bound piece from the displayed seam (d.seam) and the
-- last absorb values (d.fAbs / d.fHA / d.fInc). Runs on value changes and on
-- every smoothing step.
function B.Geometry(btn, d)
	local bar = d.health
	local vert = d.vert
	local cur = d.seam or 1
	-- Background: the bar's unfilled side while alive, the whole bar while dead/offline.
	if d.bgFull then
		d.bg:ClearAllPoints()
		d.bg:SetAllPoints(bar)
		d.bg:Show()
	elseif d.inv then
		Seg(d.bg, bar, vert, 0, cur)
	else
		Seg(d.bg, bar, vert, cur, 1)
	end
	-- Dispel "fill" wash: the current-health area.
	local dov = d.dispelOverlay
	if dov and dov.rfFill then
		Seg(dov, bar, vert, 0, cur)
	end
	if not d.geoOn then
		return
	end
	local miss = 1 - cur
	-- Heal prediction: from the seam into missing health.
	if d.predOn and d.fInc > 0 then
		Seg(d.healPred, bar, vert, cur, min(1, cur + d.fInc))
	else
		d.healPred:Hide()
	end
	-- Heal absorb (healAbsorbEdgeMode).
	local H = d.fHA
	if d.haOn and H > 0 then
		local a, b
		if d.haMode == "right" then
			a, b = 1 - min(H, 1), 1
		elseif d.haMode == "left" then
			a, b = 0, min(H, 1)
		else
			a, b = max(0, cur - H), cur
		end
		Seg(d.healAbsorb, bar, vert, a, b)
		Seg(d.healAbsorbBg, bar, vert, a, b)
	else
		d.healAbsorb:Hide()
		d.healAbsorbBg:Hide()
	end
	-- Shield absorb (absorbEdgeMode + overshieldMode).
	local A = d.fAbs
	local spark = nil
	if d.absOn and A > 0 then
		local mode = d.absMode
		if mode == "right" then
			d.absFwd:Hide()
			Seg(d.absBack, bar, vert, 1 - min(A, 1), 1)
			if A >= miss then
				spark = 1 - min(A, 1)
			end
		elseif mode == "left" then
			d.absFwd:Hide()
			Seg(d.absBack, bar, vert, 0, min(A, 1))
		elseif mode == "overlayReverse" or mode == "overlayReverseFull" then
			Seg(d.absBack, bar, vert, max(0, cur - A), cur)
			if mode == "overlayReverseFull" and A > cur then
				Seg(d.absFwd, bar, vert, cur, min(1, A))
			else
				d.absFwd:Hide()
			end
			spark = max(0, cur - A)
		else
			-- Overlay: the shield fills missing health from the seam; the
			-- excess (overshield) backfills over current health.
			Seg(d.absFwd, bar, vert, cur, min(1, cur + A))
			local excess = A - miss
			spark = cur
			if excess > 0 and d.osm == "always" then
				Seg(d.absBack, bar, vert, max(0, cur - excess), cur)
				spark = max(0, cur - excess)
			elseif excess > 0 and d.osm == "fromleft" then
				Seg(d.absBack, bar, vert, 0, min(excess, cur))
			else
				d.absBack:Hide()
			end
		end
	else
		d.absFwd:Hide()
		d.absBack:Hide()
	end
	-- Blizzard Glow Line (absorbGlowLine): a soft spark on the shield's edge
	-- next to current health. Horizontal bars only, like retail.
	if spark and d.glowOn and not vert then
		local W = bar:GetWidth() or 0
		d.spark:ClearAllPoints()
		d.spark:SetPoint("CENTER", bar, "LEFT", spark * W, 0)
		d.spark:SetHeight(max(1, (bar:GetHeight() or 0) * 2))
		d.spark:Show()
	else
		d.spark:Hide()
	end
end

-------------------------------------------------------------------------------
--  StyleButton: build every visual once
-------------------------------------------------------------------------------
local function NewCarrier(btn, host)
	local f = CreateFrame("Frame", nil, btn)
	f:SetAllPoints(host or btn)
	return f
end

function RF.StyleButton(btn)
	if not btn or btn.rf then
		return
	end
	local d = { info = {}, btn = btn }
	btn.rf = d
	local s = RF.SettingsFor(btn)

	-- Background behind the health bar (missing health / dead / offline tint).
	d.bg = btn:CreateTexture(nil, "BACKGROUND")
	d.bg:SetTexture(WHITE)
	d.bg:SetAllPoints(btn)

	-- Health bar (0-1; see B.PushHealthValue).
	local health = CreateFrame("StatusBar", nil, btn)
	health:SetMinMaxValues(0, 1)
	health:SetValue(1)
	health:SetStatusBarTexture(RF.TexturePath(s.healthBarTexture))
	health:SetStatusBarColor(0.12, 0.12, 0.12)
	d.health = health
	d.healthTexKey = s.healthBarTexture

	-- Uniform Icon Anchoring reference: where health would sit with no power bar.
	d.uniformRef = CreateFrame("Frame", nil, btn)

	-- Power bar (always built, hidden; the role gate shows it).
	local power = CreateFrame("StatusBar", nil, btn)
	power:SetMinMaxValues(0, 1)
	power:SetValue(1)
	power:SetStatusBarTexture(RF.TexturePath(s.healthBarTexture))
	power:SetStatusBarColor(0.12, 0.12, 0.12)
	d.powerBg = power:CreateTexture(nil, "BACKGROUND")
	d.powerBg:SetTexture(WHITE)
	d.powerBg:SetAllPoints(power)
	power:Hide()
	d.power = power
	d.powerBorderFrame = CreateFrame("Frame", nil, btn)
	d.powerBorderFrame:SetAllPoints(power)
	d.powerEdges = RF.CreateEdges(d.powerBorderFrame, power, "OVERLAY", 7)
	d.powerBorderFrame:Hide()

	-- Top Name Bar (always built, hidden).
	local tnb = CreateFrame("Frame", nil, btn)
	d.tnbBg = tnb:CreateTexture(nil, "BACKGROUND")
	d.tnbBg:SetTexture(WHITE)
	d.tnbBg:SetAllPoints(tnb)
	d.tnbText = RF.NewText(tnb, s.topNameBarTextSize or 11)
	tnb:Hide()
	d.tnb = tnb

	-- Absorb cluster: heal prediction + heal absorb under the shield, the
	-- shield (and its glow line) above, each on its own carrier frame.
	d.lowFrame = NewCarrier(btn, health)
	d.healPred = d.lowFrame:CreateTexture(nil, "ARTWORK", nil, 2)
	d.healPred:SetTexture(WHITE)
	d.healPred.rfMode = "flat"
	d.healPred:Hide()
	d.haFrame = NewCarrier(btn, health)
	d.healAbsorbBg = d.haFrame:CreateTexture(nil, "ARTWORK", nil, 1)
	d.healAbsorbBg:SetTexture(WHITE)
	d.healAbsorbBg.rfMode = "flat"
	d.healAbsorbBg:Hide()
	d.healAbsorb = d.haFrame:CreateTexture(nil, "ARTWORK", nil, 2)
	d.healAbsorb:Hide()
	d.highFrame = NewCarrier(btn, health)
	d.absFwd = d.highFrame:CreateTexture(nil, "ARTWORK", nil, 1)
	d.absFwd:Hide()
	d.absBack = d.highFrame:CreateTexture(nil, "ARTWORK", nil, 1)
	d.absBack:Hide()
	d.spark = d.highFrame:CreateTexture(nil, "OVERLAY")
	d.spark:SetTexture(SPARK)
	d.spark:SetBlendMode("ADD")
	d.spark:SetWidth(16)
	d.spark:Hide()

	-- Absorb Bar / Heal Absorb Bar strips.
	d.absStrip = CreateFrame("StatusBar", nil, btn)
	d.absStrip:SetStatusBarTexture(WHITE)
	d.absStrip:SetMinMaxValues(0, 1)
	d.absStrip:SetValue(0)
	d.absStrip:Hide()
	d.haStrip = CreateFrame("StatusBar", nil, btn)
	d.haStrip:SetStatusBarTexture(WHITE)
	d.haStrip:SetMinMaxValues(0, 1)
	d.haStrip:SetValue(0)
	d.haStrip:Hide()

	-- Dispel visuals: overlay wash, type border around health, type icon.
	d.dispelFrame = NewCarrier(btn, health)
	d.dispelOverlay = d.dispelFrame:CreateTexture(nil, "ARTWORK", nil, 3)
	d.dispelOverlay:SetTexture(WHITE)
	d.dispelOverlay:Hide()
	d.dispelOverlay2 = d.dispelFrame:CreateTexture(nil, "ARTWORK", nil, 3)
	d.dispelOverlay2:SetTexture(WHITE)
	d.dispelOverlay2:Hide()
	d.dispelBorderFrame = NewCarrier(btn, health)
	d.dispelEdges = RF.CreateEdges(d.dispelBorderFrame, health, "OVERLAY", 7)
	RF.LayoutEdges(d.dispelEdges, 0)
	d.dispelIconHost = CreateFrame("Frame", nil, btn)
	d.dispelIcon = d.dispelIconHost:CreateTexture(nil, "ARTWORK")
	d.dispelIcon:SetAllPoints(d.dispelIconHost)
	d.dispelIconHost:Hide()

	-- Base border (recoloured for hover / target / aggro / dispel) and the
	-- inner threat border.
	d.borderFrame = CreateFrame("Frame", nil, btn)
	d.borderFrame:SetAllPoints(btn)
	d.borderEdges = RF.CreateEdges(d.borderFrame, btn, "OVERLAY", 7)
	d.threatFrame = CreateFrame("Frame", nil, btn)
	d.threatFrame:SetAllPoints(btn)
	d.threatEdges = RF.CreateEdges(d.threatFrame, btn, "OVERLAY", 7)
	d.threatFrame:Hide()

	-- Texts (name, health, heal absorb, power, level, status) on the text carrier.
	d.textCarrier = NewCarrier(btn, health)
	d.nameText = RF.NewText(d.textCarrier, s.nameSize or 10)
	d.healthText = RF.NewText(d.textCarrier, s.healthTextSize or 9)
	d.healthText:SetTextColor(1, 1, 1, 0.9)
	d.healAbsorbText = RF.NewText(d.textCarrier, s.healAbsorbTextSize or 9)
	d.powerText = RF.NewText(d.textCarrier, s.powerTextSize or 8)
	d.powerText:Hide()
	d.levelText = RF.NewText(d.textCarrier, s.levelTextSize or 10)
	d.levelText:Hide()
	d.statusText = RF.NewText(d.textCarrier, s.statusTextSize or 12)
	d.statusText:SetJustifyH("CENTER")
	d.statusText:Hide()

	-- Role icon carrier (text band, or just under the border raise with
	-- "Show Behind Border"), leader host, marker carrier above the border.
	d.roleCarrier = NewCarrier(btn, health)
	d.roleIcon = d.roleCarrier:CreateTexture(nil, "OVERLAY")
	d.roleIcon:Hide()
	-- Role Text (retail roleText): Tank / Healer / DPS in place of the icon.
	d.roleText = RF.NewText(d.roleCarrier, s.roleIconSize or 13)
	d.roleText:Hide()
	d.leaderHost = NewCarrier(btn, health)
	d.leaderIcon = d.leaderHost:CreateTexture(nil, "OVERLAY")
	d.leaderIcon:Hide()
	d.markerCarrier = NewCarrier(btn, health)
	d.raidMarker = d.markerCarrier:CreateTexture(nil, "OVERLAY", nil, 2)
	d.raidMarker:SetTexture(RAID_ICONS)
	d.raidMarker:Hide()
	d.readyCheck = d.markerCarrier:CreateTexture(nil, "OVERLAY", nil, 3)
	d.readyCheck:Hide()
	d.combatIcon = d.markerCarrier:CreateTexture(nil, "OVERLAY", nil, 1)
	d.combatIcon:Hide()

	-- Re-place the axis pieces when the bar is resized (layout passes).
	health:SetScript("OnSizeChanged", function()
		if btn.rf then
			B.Geometry(btn, btn.rf)
		end
	end)

	-- Hover border + unit tooltip (HookScript: secure buttons keep their handlers).
	btn:HookScript("OnEnter", B.OnEnter)
	btn:HookScript("OnLeave", B.OnLeave)
	-- Keep the unit map current and repaint when the header (re)assigns the unit.
	btn:HookScript("OnAttributeChanged", B.OnAttributeChanged)
	btn:HookScript("OnShow", B.OnShow)

	allButtons[btn] = true
	B.Remap(btn)

	if RF.AuraInit then
		RF.AuraInit(btn)
	end
	if RF.BM_Init then
		RF.BM_Init(btn)
	end
	if RF.CC_SetupButton and btn.rfKind ~= "preview" and not btn.rfPreview then
		RF.CC_SetupButton(btn)
	end
	if RF.PortraitInit then
		RF.PortraitInit(btn)
	end

	RF.RelayoutButton(btn)
end

-------------------------------------------------------------------------------
--  Script hooks
-------------------------------------------------------------------------------
function B.OnEnter(btn)
	local d = btn.rf
	if not d then
		return
	end
	d.hovered = true
	B.ApplyBorderColor(btn, d)
	if btn.rfPreview or not RF.RaidFrameTooltipAllowed(btn) then
		return
	end
	local unit = RF.UnitOf(btn)
	if unit then
		if GameTooltip_SetDefaultAnchor then
			GameTooltip_SetDefaultAnchor(GameTooltip, btn)
		else
			GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
		end
		GameTooltip:SetUnit(unit)
		GameTooltip:Show()
	end
end

function B.OnLeave(btn)
	local d = btn.rf
	if not d then
		return
	end
	d.hovered = false
	B.ApplyBorderColor(btn, d)
	GameTooltip:Hide()
end

function B.OnAttributeChanged(btn, name)
	if name ~= "unit" or not btn.rf then
		return
	end
	B.Remap(btn)
	local d = btn.rf
	-- A new occupant: forget the painted state so the paint is a full one.
	-- Drop any easing too: the smoother must never see a goal without a seam.
	d.seam, d.pwShown, d.powerOn = nil, nil, nil
	d.hpGoal, d.pwGoal = nil, nil
	smoothing[btn] = nil
	if RF.UnitOf(btn) then
		RF.UpdateButton(btn)
		B.UpdateRange(btn, d)
	end
end

function B.OnShow(btn)
	if btn.rf and (btn.rfPreview or RF.UnitOf(btn)) then
		RF.UpdateButton(btn)
	end
end

-------------------------------------------------------------------------------
--  RelayoutButton: settings / size dependent layout
-------------------------------------------------------------------------------
local function SetLvl(f, lvl)
	f:SetFrameLevel(max(0, min(127, lvl)))
end

-- Bars layout: Top Name Bar (top or bottom), health inset for the power bar
-- (unless Extend Health Behind Power), power bar at the bottom.
function B.LayoutBars(btn, d, s)
	local tnbOn = s.topNameBarEnabled and true or false
	local tnbH = tnbOn and Snap(s.topNameBarHeight or 20, btn) or 0
	local bottomBar = tnbOn and s.topNameBarBottom == true
	local powerH = Snap(s.powerHeight or 4, btn)
	local inset = 0
	if d.powerOn then
		inset = s.extendHealthBehindPower and 0 or powerH
	end
	local baseY = bottomBar and tnbH or 0
	-- An attached party portrait (Extras file) takes a side of the button.
	local pl, pr = 0, 0
	if RF.PortraitBarInsets then
		pl, pr = RF.PortraitBarInsets(btn)
		pl, pr = pl or 0, pr or 0
	end
	local h = d.health
	h:ClearAllPoints()
	h:SetPoint("TOPLEFT", btn, "TOPLEFT", pl, bottomBar and 0 or -tnbH)
	h:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -pr, baseY + inset)
	local p = d.power
	p:ClearAllPoints()
	p:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", pl, baseY)
	p:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -pr, baseY)
	p:SetHeight(powerH)
	local u = d.uniformRef
	u:ClearAllPoints()
	u:SetPoint("TOPLEFT", h, "TOPLEFT", 0, 0)
	u:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -pr, baseY)
	local tnb = d.tnb
	if tnbOn then
		tnb:ClearAllPoints()
		if bottomBar then
			tnb:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", pl, 0)
			tnb:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -pr, 0)
		else
			tnb:SetPoint("TOPLEFT", btn, "TOPLEFT", pl, 0)
			tnb:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -pr, 0)
		end
		tnb:SetHeight(max(1, tnbH))
		local c = s.topNameBarBgColor
		local r, g, b = Col(c, 17 / 255, 17 / 255, 17 / 255)
		d.tnbBg:SetVertexColor(r, g, b, (s.topNameBarBgOpacity or 80) / 100)
		RF.SetFont(d.tnbText, s.topNameBarTextSize or 11)
		local align = s.topNameBarTextAlign or "center"
		local ox, oy = s.topNameBarTextOffsetX or 0, s.topNameBarTextOffsetY or 0
		d.tnbText:ClearAllPoints()
		if align == "left" then
			d.tnbText:SetPoint("LEFT", tnb, "LEFT", 4 + ox, oy)
			d.tnbText:SetJustifyH("LEFT")
		elseif align == "right" then
			d.tnbText:SetPoint("RIGHT", tnb, "RIGHT", -4 + ox, oy)
			d.tnbText:SetJustifyH("RIGHT")
		else
			d.tnbText:SetPoint("CENTER", tnb, "CENTER", ox, oy)
			d.tnbText:SetJustifyH("CENTER")
		end
		d.tnbText:SetWidth(max(1, (btn:GetWidth() or 0) - 4))
		-- Divider (retail topNameBarDivider): a border-size line between the
		-- name bar and the health bar, in the border color.
		local bs = s.borderSize or 1
		if s.topNameBarDivider == true and bs > 0 and tnbH >= 4 then
			local t = d.tnbDivider
			if not t then
				t = tnb:CreateTexture(nil, "OVERLAY")
				t:SetTexture(WHITE)
				d.tnbDivider = t
			end
			local edge = bottomBar and "TOP" or "BOTTOM"
			t:ClearAllPoints()
			t:SetPoint(edge .. "LEFT", tnb, edge .. "LEFT", 0, 0)
			t:SetPoint(edge .. "RIGHT", tnb, edge .. "RIGHT", 0, 0)
			t:SetHeight(max(1, Snap(bs, btn)))
			local dr, dg, db = Col(s.borderColor, 0, 0, 0)
			t:SetVertexColor(dr, dg, db, s.borderAlpha or 1)
			t:Show()
		elseif d.tnbDivider then
			d.tnbDivider:Hide()
		end
		tnb:Show()
	else
		tnb:Hide()
	end
	d.layoutPower = d.powerOn
end

-- Power border styles: "eui" (1px white 20% divider), "divider", "border".
function B.UpdatePowerBorder(btn, d, s)
	if not d.power:IsShown() then
		d.powerBorderFrame:Hide()
		return
	end
	local e = d.powerEdges
	local style = s.powerBorderStyle or "eui"
	if style == "eui" then
		RF.LayoutEdges(e, 1, 1, 1, 1, 0.2)
		e[2]:Hide()
		e[3]:Hide()
		e[4]:Hide()
		d.powerBorderFrame:Show()
		return
	end
	local bs = s.powerBorderSize or 1
	if bs <= 0 then
		d.powerBorderFrame:Hide()
		return
	end
	local r, g, b = Col(s.powerBorderColor, 0, 0, 0)
	RF.LayoutEdges(e, bs, r, g, b, s.powerBorderAlpha or 1)
	if style == "divider" then
		e[2]:Hide()
		e[3]:Hide()
		e[4]:Hide()
	end
	d.powerBorderFrame:Show()
end

-- Health fill direction (retail RF_ApplyHealthOrientation).
function B.ApplyOrientation(d, s)
	local vert = s.healthVerticalFill and true or false
	local inv = s.healthInvertFill and true or false
	d.vert, d.inv = vert, inv
	d.health:SetOrientation(vert and "VERTICAL" or "HORIZONTAL")
	d.health:SetReverseFill(inv)
	d.health:SetRotatesTexture(vert)
	d.power:SetOrientation("HORIZONTAL")
end

function RF.RelayoutButton(btn)
	local d = btn and btn.rf
	if not d then
		return
	end
	local s = RF.SettingsFor(btn)
	local pl = btn:GetFrameLevel()

	-- Frame levels (offsets above the button; 5.4.8 caps near 128).
	SetLvl(d.health, pl + 2)
	SetLvl(d.uniformRef, pl + 2)
	SetLvl(d.lowFrame, pl + 3)
	SetLvl(d.haFrame, s.healAbsorbOverDispel and (pl + 5) or (pl + 3))
	SetLvl(d.dispelFrame, pl + 4)
	SetLvl(d.highFrame, pl + 5)
	SetLvl(d.power, pl + 3)
	SetLvl(d.powerBorderFrame, pl + 4)
	SetLvl(d.tnb, pl + 4)
	SetLvl(d.absStrip, pl + 6)
	SetLvl(d.haStrip, pl + 7)
	SetLvl(d.dispelBorderFrame, pl + 9)
	SetLvl(d.threatFrame, pl + RF.LVL_RAISE)
	SetLvl(d.textCarrier, pl + (s.nameTextAboveIcons and (RF.LVL_AURA + 6) or RF.LVL_TEXT))
	SetLvl(d.roleCarrier, pl + (s.roleIconBehindBorder and (RF.LVL_RAISE - 1) or (RF.LVL_AURA - 1)))
	SetLvl(d.leaderHost, pl + RF.LVL_TEXT)
	SetLvl(d.markerCarrier, pl + RF.LVL_MARKER)
	SetLvl(d.dispelIconHost, pl + 20)

	-- Health / power textures and fill direction.
	local tex = RF.TexturePath(s.healthBarTexture)
	d.health:SetStatusBarTexture(tex)
	d.power:SetStatusBarTexture(tex)
	d.healthFill = d.health:GetStatusBarTexture()
	B.ApplyOrientation(d, s)

	-- Power bar background.
	local pr, pg, pb = Col(s.powerBgColor, 107 / 255, 107 / 255, 107 / 255)
	d.powerBg:SetVertexColor(pr, pg, pb, (s.powerBgDarkness or 40) / 100)
	d.pwBgType = nil

	-- Bars (power gate re-evaluated by the paint; keep the last state here).
	B.LayoutBars(btn, d, s)

	-- Absorb overlay styles (style, colour, opacity).
	local absStyle = s.absorbStyle or "striped"
	if absStyle == "blizzardModern" then
		absStyle = "blizzard"
	end
	local ar, ag, ab = Col(s.absorbColor, 1, 1, 1)
	local aa = (s.absorbOpacity or 90) / 100
	StyleOverlay(d.absFwd, absStyle, ar, ag, ab, aa)
	StyleOverlay(d.absBack, absStyle, ar, ag, ab, aa)
	local haStyle = s.healAbsorbStyle or "clean"
	local hr, hg, hb = Col(s.healAbsorbColor, 0.8, 0.15, 0.15)
	if haStyle == "largeOutlinedStripes" or haStyle == "largeOutlinedStripesR" or haStyle == "healBlizzModern" then
		hr, hg, hb = 1, 1, 1
	end
	StyleOverlay(d.healAbsorb, haStyle, hr, hg, hb, (s.healAbsorbOpacity or 75) / 100)
	d.healAbsorbBg:SetVertexColor(0, 0, 0, (s.healAbsorbBgOpacity or 25) / 100)
	local cr, cg, cb = Col(s.healPredColor, 102 / 255, 243 / 255, 102 / 255)
	d.healPred:SetVertexColor(cr, cg, cb, (s.healPredOpacity or 75) / 100)

	-- Strip bars.
	B.LayoutStrips(btn, d, s)

	-- Fonts (sizes are scaled by the settings view).
	RF.SetFont(d.nameText, s.nameSize or 10)
	RF.SetFont(d.healthText, s.healthTextSize or 9)
	RF.SetFont(d.healAbsorbText, s.healAbsorbTextSize or 9)
	RF.SetFont(d.powerText, s.powerTextSize or 8)
	RF.SetFont(d.levelText, s.levelTextSize or 10)
	RF.SetFont(d.statusText, s.statusTextSize or 12)
	d.stSt = nil

	-- Text and icon anchors.
	B.AnchorAll(btn, d, s)

	-- Borders.
	B.UpdateBorder(btn, d, s)
	d.threatOn = nil

	-- Other modules' layout (guarded: they may not exist).
	if RF.AuraRelayout then
		RF.AuraRelayout(btn)
	end
	if RF.BM_Relayout then
		RF.BM_Relayout(btn)
	end

	RF.UpdateButton(btn)
end

-- Text / icon anchors (retail Anchor* closures, resolved live per view).
function B.AnchorAll(btn, d, s)
	local health = d.health
	local host = AnchorHost(d, s)
	local w = s.frameWidth or btn:GetWidth() or 72

	-- Name (hidden by "none" or the Top Name Bar).
	local pos = s.namePosition or "center"
	if pos == "none" or s.topNameBarEnabled then
		d.nameText:Hide()
		d.nameHidden = true
	else
		d.nameText:Show()
		d.nameHidden = false
		RF.AnchorRFText(d.nameText, host, pos, s.nameOffsetX, s.nameOffsetY, w)
	end
	RF.AnchorRFText(d.healthText, host, s.healthTextPosition or "center", s.healthTextOffsetX, s.healthTextOffsetY, w * 0.75)
	RF.AnchorRFText(d.healAbsorbText, host, s.healAbsorbTextPosition or "center", s.healAbsorbTextOffsetX,
		s.healAbsorbTextOffsetY, w * 0.75)
	RF.AnchorRFText(d.powerText, host, s.powerTextPosition or "bottom", s.powerTextOffsetX, s.powerTextOffsetY, w * 0.75)
	local lpos = s.levelTextPosition or RF.RF_LEVEL_DEFAULT
	if lpos ~= "none" and not RF.RF_LEVEL_ATTACH[lpos] then
		RF.AnchorRFText(d.levelText, host, lpos, s.levelTextOffsetX, s.levelTextOffsetY)
	end
	-- Status text: own spot (no justify width).
	local sp = TXT[s.statusTextPosition or "center"] or TXT.center
	d.statusText:ClearAllPoints()
	d.statusText:SetPoint(sp[1], host, sp[1], sp[2] + (s.statusTextOffsetX or 0), sp[3] + (s.statusTextOffsetY or 0))

	-- Role icon: plain 9-point anchor (no insets).
	local rs = Snap(s.roleIconSize or 13, btn)
	d.roleIcon:SetSize(max(1, rs), max(1, rs))
	local rpos = (s.roleIconPosition or "bottomleft"):upper()
	d.roleIcon:ClearAllPoints()
	d.roleIcon:SetPoint(rpos, host, rpos, s.roleIconOffsetX or 0, s.roleIconOffsetY or 0)
	if d.roleText then
		RF.SetFont(d.roleText, s.roleIconSize or 13)
		d.roleText:ClearAllPoints()
		d.roleText:SetPoint(rpos, d.roleIcon, rpos, 0, 0)
	end

	-- Leader icon.
	local ls = Snap(s.leaderIconSize or 14, btn)
	d.leaderIcon:SetSize(max(1, ls), max(1, ls))
	local lp = (s.leaderIconPosition or "top"):upper()
	d.leaderIcon:ClearAllPoints()
	d.leaderIcon:SetPoint(lp, host, lp, s.leaderIconOffsetX or 0, s.leaderIconOffsetY or 0)

	-- Raid marker / ready check (2px insets, like retail).
	local ms = Snap(s.raidMarkerSize or 16, btn)
	d.raidMarker:SetSize(max(1, ms), max(1, ms))
	RF.AnchorRFText(d.raidMarker, host, s.raidMarkerPosition or "center", s.raidMarkerOffsetX, s.raidMarkerOffsetY, nil, true)
	local rc = Snap(s.readyCheckSize or 20, btn)
	d.readyCheck:SetSize(max(1, rc), max(1, rc))
	RF.AnchorRFText(d.readyCheck, host, s.readyCheckPosition or "center", s.readyCheckOffsetX, s.readyCheckOffsetY, nil, true)

	-- Combat icon.
	local cs = Snap(s.combatIndicatorSize or 16, btn)
	d.combatIcon:SetSize(max(1, cs), max(1, cs))
	local cp = (s.combatIndicatorPosition or "right"):upper()
	d.combatIcon:ClearAllPoints()
	d.combatIcon:SetPoint(cp, host, cp, s.combatIndicatorOffsetX or 0, s.combatIndicatorOffsetY or 0)

	-- Dispel type icon.
	local ds = s.dispelIconSize or 16
	d.dispelIconHost:SetSize(max(1, ds), max(1, ds))
	local dp = RF.PosPoint(s.dispelIconPosition or "right")
	d.dispelIconHost:ClearAllPoints()
	d.dispelIconHost:SetPoint(dp, host, dp, s.dispelIconOffsetX or 0, s.dispelIconOffsetY or 0)
end

-------------------------------------------------------------------------------
--  Absorb Bar / Heal Absorb Bar strips (retail ApplyStripBarLayout).
--  Positions: none / aboveRight / aboveLeft / topRight / topLeft /
--  rightVertical / leftVertical, plus belowAbsorb for the heal strip.
-------------------------------------------------------------------------------
function RF.GetAbsorbBarPosition(s)
	local p = s and s.absorbBarPosition
	if p then
		return p
	end
	return (s and s.absorbBarEnabled) and "aboveRight" or "none"
end

function RF.GetHealAbsorbBarPosition(s)
	return (s and s.healAbsorbBarPosition) or "none"
end

local function StripLayout(bar, btn, hp, position, height, absorbPos, absorbHeight, growDir)
	bar:ClearAllPoints()
	if position == "rightVertical" or position == "leftVertical" then
		bar:SetOrientation("VERTICAL")
		bar:SetReverseFill(growDir == "down")
		bar:SetWidth(max(1, Snap(height or 4, btn)))
		local pt = position == "rightVertical" and "RIGHT" or "LEFT"
		bar:SetPoint("TOP" .. pt, hp, "TOP" .. pt, 0, 0)
		bar:SetPoint("BOTTOM" .. pt, hp, "BOTTOM" .. pt, 0, 0)
		return
	end
	bar:SetOrientation("HORIZONTAL")
	bar:SetHeight(max(1, Snap(height or 4, btn)))
	if position == "belowAbsorb" then
		absorbPos = absorbPos or "none"
		local yOff = 0
		if absorbPos == "topRight" or absorbPos == "topLeft" then
			yOff = -Snap(absorbHeight or 4, btn)
		end
		bar:SetReverseFill(absorbPos ~= "aboveLeft" and absorbPos ~= "topLeft")
		bar:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, yOff)
		bar:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, yOff)
	elseif position == "topRight" or position == "topLeft" then
		bar:SetReverseFill(position == "topRight")
		bar:SetPoint("TOPLEFT", hp, "TOPLEFT", 0, 0)
		bar:SetPoint("TOPRIGHT", hp, "TOPRIGHT", 0, 0)
	else
		bar:SetReverseFill(position == "aboveRight")
		bar:SetPoint("BOTTOMLEFT", btn, "TOPLEFT", 0, 0)
		bar:SetPoint("BOTTOMRIGHT", btn, "TOPRIGHT", 0, 0)
	end
end

function B.LayoutStrips(btn, d, s)
	local barPos = RF.GetAbsorbBarPosition(s)
	d.absStripPos = barPos
	if barPos ~= "none" then
		StripLayout(d.absStrip, btn, d.health, barPos, s.absorbBarHeight or 4, nil, nil, s.absorbBarGrowDir or "up")
		local r, g, b = Col(s.absorbBarColor, 1, 1, 1)
		d.absStrip:SetStatusBarColor(r, g, b, (type(s.absorbBarColor) == "table" and s.absorbBarColor.a) or 1)
	end
	local hpos = RF.GetHealAbsorbBarPosition(s)
	d.haStripPos = hpos
	if hpos ~= "none" then
		StripLayout(d.haStrip, btn, d.health, hpos, s.healAbsorbBarHeight or 4, barPos, s.absorbBarHeight or 4,
			s.healAbsorbBarGrowDir or "up")
		local r, g, b = Col(s.healAbsorbBarColor, 200 / 255, 29 / 255, 29 / 255)
		d.haStrip:SetStatusBarColor(r, g, b, (type(s.healAbsorbBarColor) == "table" and s.healAbsorbBarColor.a) or 1)
	end
end

-------------------------------------------------------------------------------
--  Borders (retail UpdateBorder / ApplyBorderColor / RF_PaintThreat).
--  5.4.8: every Border Style draws the EllesmereUI Solid pixel border.
-------------------------------------------------------------------------------
local function BorderPx(sizePx, size)
	if type(sizePx) == "number" then
		return sizePx
	end
	return size
end

function B.UpdateBorder(btn, d, s)
	local pl = btn:GetFrameLevel()
	SetLvl(d.borderFrame, s.borderBehind and max(0, pl - 1) or (pl + 8))
	d.hlSize = nil
	d.baseBorderPx = BorderPx(s.borderSizePx, s.borderSize or 1)
	RF.LayoutEdges(d.borderEdges, d.baseBorderPx, 0, 0, 0, 1)
	B.ApplyBorderColor(btn, d)
end

-- Hover > target > aggro (Color Custom Borders) > dispel (Color Custom
-- Borders) > normal. A borderless frame draws the highlight at its own size.
function B.ApplyBorderColor(btn, d)
	local s = RF.SettingsFor(btn)
	local r, g, b, a
	local raised, hlSize = false, nil
	if d.hovered and s.hoverBorderEnabled ~= false then
		r, g, b = Col(s.hoverBorderColor, 1, 1, 1)
		a = s.hoverBorderAlpha or 1
		raised, hlSize = true, BorderPx(s.hoverBorderSizePx, s.hoverBorderSize or 1)
	elseif d.isTarget and s.targetBorderEnabled ~= false then
		r, g, b = Col(s.targetBorderColor, 1, 1, 1)
		a = s.targetBorderAlpha or 1
		raised, hlSize = true, BorderPx(s.targetBorderSizePx, s.targetBorderSize or 1)
	elseif d.aggroBdr and s.threatCustomBorder == true and RF.RF_CustomBorderOn(s) then
		r, g, b, a = 1, 0, 0, 1
		raised = true
	elseif d.dispelBdr and s.dispelCustomBorder == true and RF.RF_CustomBorderOn(s) then
		r, g, b, a = d.dispelBdr[1], d.dispelBdr[2], d.dispelBdr[3], 1
		raised = true
	else
		r, g, b = Col(s.borderColor, 0, 0, 0)
		a = s.borderAlpha or 1
	end
	local pl = btn:GetFrameLevel()
	local lvl
	if s.borderBehind then
		-- Retail: Show Behind keeps the border under the frame in every state.
		lvl = max(0, pl - 1)
	else
		lvl = pl + (raised and RF.LVL_RAISE or 8)
	end
	SetLvl(d.borderFrame, lvl)
	local base = d.baseBorderPx or (s.borderSize or 1)
	if base <= 0 then
		-- Borderless: the highlight draws its own border at the hover/target size.
		if hlSize and hlSize > 0 then
			RF.LayoutEdges(d.borderEdges, hlSize, r, g, b, a)
			d.hlSize = hlSize
		elseif d.hlSize ~= 0 then
			RF.LayoutEdges(d.borderEdges, 0)
			d.hlSize = 0
		end
		return
	end
	if d.hlSize and d.hlSize ~= base then
		RF.LayoutEdges(d.borderEdges, base, r, g, b, a)
		d.hlSize = nil
	end
	if hlSize then
		r, g, b = RF.RF_VisibleHighlight(s, r, g, b)
	end
	RF.SetEdgesColor(d.borderEdges, r, g, b, a)
	-- Top Name Bar Divider, Match Highlight Colors: the divider follows the
	-- hover / target color.
	if d.tnbDivider and d.tnbDivider:IsShown() and s.topNameBarDividerMatchColor == true then
		d.tnbDivider:SetVertexColor(r, g, b, a)
	end
end

-- A highlight colour equal to the border's own would show no change: draw
-- gold instead (retail RF_VisibleHighlight).
function RF.RF_VisibleHighlight(s, r, g, b)
	local br, bg, bb = Col(s.borderColor, 0, 0, 0)
	if abs(r - br) + abs(g - bg) + abs(b - bb) >= 0.15 then
		return r, g, b
	end
	if abs(1 - br) + abs(0.82 - bg) + abs(bb) >= 0.15 then
		return 1, 0.82, 0
	end
	return 1, 1, 1
end

-- Threat (aggro 2-3): the inner red border, or the Color Custom Borders recolor.
function B.PaintThreat(btn, d, s, status)
	local bs = s.threatBorderSize or 0
	local rc = s.threatCustomBorder == true and RF.RF_CustomBorderOn(s)
	local on = (bs > 0 or rc) and status and THREAT_ACTIVE[status] and true or false
	local agg = (rc and on) or nil
	if d.aggroBdr ~= agg then
		d.aggroBdr = agg
		B.ApplyBorderColor(btn, d)
	end
	if on and not rc then
		if d.threatOn ~= bs then
			RF.LayoutEdges(d.threatEdges, bs, 1, 0, 0, 1)
			d.threatOn = bs
		end
		d.threatFrame:Show()
	else
		d.threatFrame:Hide()
	end
end

-------------------------------------------------------------------------------
--  Paint: health
-------------------------------------------------------------------------------
function B.PaintHealth(btn, d, s, i, full)
	local maxHP = i.hpMax or 0
	local pct01 = (maxHP > 0) and min(1, max(0, (i.hp or 0) / maxHP)) or 0
	d.pct = pct01
	local dead, offline = i.dead, i.offline
	local health = d.health
	local smooth = full ~= "snap" and s.smoothBars and not i.preview and d.seam ~= nil

	-- Dead under Inverted Fill: a full missing bar, its fill hidden.
	d.deadInv = dead and d.inv or false
	B.SetHealthGoal(btn, d, pct01, smooth)
	if d.deadInv then
		B.PushHealthValue(d)
	end

	-- Fill colour (dead / offline: the status tint below owns it).
	if not dead and not offline then
		local r, g, b
		-- Fixed colour of a button kind (btn.rfHealthColor table, or the
		-- Extras file's btn.exColor function: pets / friendly bosses).
		local ov = btn.rfHealthColor
		if ov == nil and type(btn.exColor) == "function" then
			ov = btn.exColor()
		end
		if type(ov) == "table" then
			r, g, b = ov.r or 1, ov.g or 1, ov.b or 1
		else
			r, g, b = RF.GetHealthColor(s, i.class, pct01)
		end
		if s.healthColorMode == "dark" then
			health:SetStatusBarColor(r, g, b, 1)
		else
			health:SetStatusBarColor(r, g, b, (s.healthBarOpacity or 100) / 100)
		end
	end

	-- Background + dead / offline status tint (retail _ApplyHealthBg).
	local bg = d.bg
	if offline or dead then
		local r, g, b
		if offline then
			r, g, b = Col(s.statusColorOffline, 0x66 / 255, 0x66 / 255, 0x66 / 255)
		else
			r, g, b = Col(s.statusColorDead, 0x24 / 255, 0x17 / 255, 0x17 / 255)
		end
		bg:SetVertexColor(r, g, b, 1)
		d.bgFull = true
		if d.deadInv then
			health:SetStatusBarColor(0.3, 0.3, 0.3, 0)
		elseif offline then
			health:SetStatusBarColor(0.3, 0.3, 0.3, 0.3)
		else
			health:SetStatusBarColor(0.3, 0.3, 0.3, 0.5)
		end
	else
		d.bgFull = false
		local r, g, b, a
		if s.healthColorMode == "dark" then
			local c = RF.DARK_BG
			r, g, b, a = c[1], c[2], c[3], 1
		else
			r, g, b, a = RF.GetBgColor(s, i.class)
		end
		bg:SetVertexColor(r, g, b, a)
	end
end

-------------------------------------------------------------------------------
--  Paint: power (retail _PaintPower: role gate, layout, value, colour, text)
-------------------------------------------------------------------------------
function B.PaintPower(btn, d, s, i, full)
	local role = i.role or "DAMAGER"
	local showForRole = (role == "HEALER" and s.powerShowForHealer)
		or (role == "TANK" and s.powerShowForTank)
		or ((role == "DAMAGER" or role == "NONE") and s.powerShowForDPS)
	if s.showPowerBar == false then
		showForRole = false
	end
	local on = (showForRole and (i.powerMax or 0) > 0) and true or false
	if d.powerOn ~= on or d.layoutPower ~= on then
		d.powerOn = on
		B.LayoutBars(btn, d, s)
	end
	local power = d.power
	if not on then
		power:Hide()
		d.powerBorderFrame:Hide()
		d.powerText:Hide()
		d.pwGoal = nil
		return
	end
	local wasShown = power:IsShown()
	power:Show()
	B.UpdatePowerBorder(btn, d, s)
	local pr, pg, pb = RF.PowerColor(i.powerToken)
	power:SetStatusBarColor(pr, pg, pb, 1)
	if s.powerBgPowerColored then
		local f = 0.3
		d.powerBg:SetVertexColor(pr * f, pg * f, pb * f, (s.powerBgDarkness or 40) / 100)
		d.pwBgType = i.powerToken
	elseif d.pwBgType then
		local r, g, b = Col(s.powerBgColor, 107 / 255, 107 / 255, 107 / 255)
		d.powerBg:SetVertexColor(r, g, b, (s.powerBgDarkness or 40) / 100)
		d.pwBgType = nil
	end
	local v = (i.powerMax > 0) and min(1, max(0, (i.power or 0) / i.powerMax)) or 0
	local smooth = full ~= "snap" and wasShown and s.smoothPowerBars and not i.preview
	B.SetPowerGoal(btn, d, v, smooth)

	-- Power Text: shown only while the power bar shows (dead / offline blank).
	local mode = s.powerTextMode
	if mode and mode ~= "none" then
		d.powerText:Show()
		if i.dead or i.offline then
			d.powerText:SetText("")
		else
			RF.RF_PowerTextInto(d.powerText, mode, v * 100, i.power)
		end
		local r, g, b = TextColor(s.powerTextColorMode, s.powerTextCustomColor, i.class, 1, 1, 1, pr, pg, pb)
		d.powerText:SetTextColor(r, g, b, 0.9)
	else
		d.powerText:Hide()
	end
end

-------------------------------------------------------------------------------
--  Paint: absorbs, heal absorb, heal prediction, strips
-------------------------------------------------------------------------------
function B.PaintAbsorbs(btn, d, s, i)
	local maxHP = i.hpMax or 0
	local alive = not i.dead and not i.offline and maxHP > 0
	local absorb = alive and (i.absorb or 0) or 0
	local healAbs = alive and (i.healAbsorb or 0) or 0
	local inc = alive and (i.incoming or 0) or 0
	d.fAbs = maxHP > 0 and absorb / maxHP or 0
	d.fHA = maxHP > 0 and healAbs / maxHP or 0
	d.fInc = maxHP > 0 and inc / maxHP or 0

	local absStyle = s.absorbStyle or "striped"
	d.absOn = absStyle ~= "none"
	local em = s.absorbEdgeMode or "overlay"
	if absStyle == "blizzardModern" and em ~= "overlay" then
		em = "overlayReverse"
	end
	d.absMode = em
	local osm = s.overshieldMode
	if osm == nil then
		osm = (s.showOvershield == false) and "never" or "always"
	end
	d.osm = osm
	d.haOn = (s.healAbsorbStyle or "clean") ~= "none"
	d.haMode = s.healAbsorbEdgeMode or "overlay"
	d.predOn = s.healPrediction and true or false
	local gl = s.absorbGlowLine
	d.glowOn = d.absOn and (gl == true or (gl == nil and absStyle == "blizzardModern"))
	d.geoOn = d.absOn or d.haOn or d.predOn
	if not d.geoOn then
		d.absFwd:Hide()
		d.absBack:Hide()
		d.healAbsorb:Hide()
		d.healAbsorbBg:Hide()
		d.healPred:Hide()
		d.spark:Hide()
	end
	B.Geometry(btn, d)

	-- Absorb Bar strip.
	if d.absStripPos and d.absStripPos ~= "none" then
		d.absStrip:SetValue(min(1, d.fAbs))
		d.absStrip:Show()
	else
		d.absStrip:Hide()
	end
	-- Heal Absorb Bar strip.
	if d.haStripPos and d.haStripPos ~= "none" then
		d.haStrip:SetValue(min(1, d.fHA))
		d.haStrip:Show()
	else
		d.haStrip:Hide()
	end
end

-------------------------------------------------------------------------------
--  Paint: names, texts, status, indicators, target, threat (retail
--  _PaintButtonTail)
-------------------------------------------------------------------------------
function B.PaintTexts(btn, d, s, i)
	local unit = i.unit
	local lvlPos = s.levelTextPosition or RF.RF_LEVEL_DEFAULT
	local attach = RF.RF_LEVEL_ATTACH[lvlPos]
	local nr, ng, nb = TextColor(s.nameColorMode or "class", s.nameCustomColor, i.class, 1, 1, 1)

	-- Name.
	if not d.nameHidden then
		local name = RF.ResolveDisplayName(unit, true, s, i.name)
		if attach then
			NameWithLevel(d.nameText, name, i.level, attach)
		else
			d.nameText:SetText(name)
		end
		d.nameText:SetTextColor(nr, ng, nb)
	end

	-- Level Text on its own spot, in the name colour.
	if lvlPos ~= "none" and not attach then
		local lvl = i.level
		if not lvl or lvl == 0 then
			d.levelText:SetText("")
		elseif lvl < 0 then
			d.levelText:SetText("??")
		else
			d.levelText:SetFormattedText("%d", lvl)
		end
		d.levelText:SetTextColor(nr, ng, nb)
		d.levelText:Show()
	else
		d.levelText:Hide()
	end

	-- Top Name Bar text (no cap; class or custom colour).
	if s.topNameBarEnabled then
		local name = RF.ResolveDisplayName(unit, false, s, i.name)
		if attach then
			NameWithLevel(d.tnbText, name, i.level, attach)
		else
			d.tnbText:SetText(name)
		end
		local tr, tg, tb
		if (s.topNameBarTextColorMode or "class") == "custom" then
			tr, tg, tb = Col(s.topNameBarTextColor, 1, 1, 1)
		else
			tr, tg, tb = TextColor("class", nil, i.class, 1, 1, 1)
		end
		d.tnbText:SetTextColor(tr, tg, tb)
	end

	B.PaintValueTexts(btn, d, s, i)
end

-- Health text, heal absorb text, status text (the UNIT_HEALTH share).
function B.PaintValueTexts(btn, d, s, i)
	-- Health text (blank while dead / offline).
	local gone = i.dead or i.offline
	local mode = s.healthTextMode or "none"
	if gone or mode == "none" then
		d.healthText:SetText("")
	else
		RF.RF_HealthTextInto(d.healthText, mode, (d.pct or 0) * 100, i.hp, i.hpMax)
		local r, g, b = TextColor(s.healthTextColorMode or "custom", s.healthTextCustomColor, i.class, 1, 1, 1)
		d.healthText:SetTextColor(r, g, b, 0.9)
	end

	-- Heal absorb text.
	local hm = s.healAbsorbTextMode or "none"
	if gone or hm == "none" then
		d.healAbsorbText:SetText("")
	else
		RF.FormatHealAbsorbInto(d.healAbsorbText, i.healAbsorb, hm)
		local r, g, b = TextColor(s.healAbsorbTextColorMode or "custom", s.healAbsorbTextCustomColor, i.class, 1, 0.3, 0.3)
		d.healAbsorbText:SetTextColor(r, g, b, 0.9)
	end

	B.PaintStatus(btn, d, s, i)
end

-- Status text OFFLINE / DEAD / AFK (retail _PaintStatusText; hidden while an
-- incoming resurrection shows its icon).
function B.PaintStatus(btn, d, s, i)
	local st
	if s.statusTextPosition == "none" then
		st = 0
	elseif i.dead and s.showIncomingRez ~= false and i.rez then
		st = 0
	elseif i.offline then
		st = 1
	elseif i.dead then
		st = 2
	else
		st = (s.statusShowAFK and i.afk) and 3 or 0
	end
	local r, g, b = Col(s.statusTextColor, 1, 1, 1)
	if st == 0 then
		d.statusText:Hide()
	else
		d.statusText:SetText(st == 1 and "OFFLINE" or st == 2 and "DEAD" or "AFK")
		d.statusText:SetTextColor(r, g, b)
		d.statusText:Show()
	end
	d.stSt = st
end

-- Role icon (retail _UpdateRoleIcon); Role Text shows TANK / HEALER / DPS
-- in the role colors instead (retail roleText).
local ROLE_TEXT = { TANK = "Tank", HEALER = "Healer", DAMAGER = "DPS" }
local ROLE_TEXT_KEY = { TANK = "roleTextTankColor", HEALER = "roleTextHealerColor", DAMAGER = "roleTextDPSColor" }
local ROLE_TEXT_DEFAULT = {
	TANK = { r = 59 / 255, g = 130 / 255, b = 246 / 255 },
	HEALER = { r = 32 / 255, g = 201 / 255, b = 151 / 255 },
	DAMAGER = { r = 240 / 255, g = 100 / 255, b = 54 / 255 },
}
function B.PaintRole(btn, d, s, i)
	local icon = d.roleIcon
	local text = d.roleText
	local style = s.roleIconStyle or "modern"
	if text then text:Hide() end
	if (style == "none" and not s.roleText) or (s.roleIconHideInCombat and inCombat) then
		icon:Hide()
		return
	end
	local role = i.role
	local show = (role == "TANK" and s.showRoleForTank)
		or (role == "HEALER" and s.showRoleForHealer)
		or (role == "DAMAGER" and s.showRoleForDPS)
	if show and s.roleText and text and ROLE_TEXT[role] then
		icon:Hide()
		local c = s[ROLE_TEXT_KEY[role]] or ROLE_TEXT_DEFAULT[role]
		text:SetTextColor(c.r or 1, c.g or 1, c.b or 1)
		text:SetText(ROLE_TEXT[role])
		text:Show()
	elseif show and RF.ApplyRoleIcon(icon, role, style) then
		icon:Show()
	else
		icon:Hide()
	end
end

-- Leader / assistant icon (retail _UpdateLeaderIcon).
function B.PaintLeader(btn, d, s, i)
	local icon = d.leaderIcon
	if not s.showLeaderIcon or (s.showLeaderIconInCombat == false and inCombat) then
		icon:Hide()
		return
	end
	if i.leader then
		icon:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
		icon:SetTexCoord(0, 1, 0, 1)
		icon:Show()
	elseif i.assist then
		icon:SetTexture("Interface\\GroupFrame\\UI-Group-AssistantIcon")
		icon:SetTexCoord(0, 1, 0, 1)
		icon:Show()
	else
		icon:Hide()
	end
end

-- Combat icon (retail _UpdateCombatIcon; media from the Unit Frames module).
function B.PaintCombat(btn, d, s, i)
	local icon = d.combatIcon
	if not s.showCombatIndicator or not i.inCombat then
		icon:Hide()
		return
	end
	local style = s.combatIndicatorStyle or "standard"
	if style:find("^combat%d") then
		icon:SetTexture(COMBAT_MEDIA .. style)
		icon:SetTexCoord(0, 1, 0, 1)
		icon:SetVertexColor(1, 1, 1, 1)
	else
		if style == "class" then
			icon:SetTexture(COMBAT_MEDIA .. "combat-indicator-class-custom")
			local c = i.class and CLASS_SPRITE[i.class]
			if c then
				icon:SetTexCoord(c[1], c[2], c[3], c[4])
			else
				icon:SetTexCoord(0, 1, 0, 1)
			end
		else
			icon:SetTexture(COMBAT_MEDIA .. "combat-indicator-custom")
			icon:SetTexCoord(0, 1, 0, 1)
		end
		local r, g, b
		if (s.combatIndicatorColor or "custom") == "classcolor" then
			if i.class then
				r, g, b = RF.ClassColor(i.class)
			else
				r, g, b = 1, 1, 1
			end
		else
			r, g, b = Col(s.combatIndicatorCustomColor, 1, 0.2, 0.2)
		end
		icon:SetVertexColor(r, g, b, 1)
	end
	icon:Show()
end

-- Raid marker (UI-RaidTargetingIcons sheet, 4x4).
function B.PaintMarker(btn, d, s, i)
	local idx = i.marker
	if s.showRaidMarker and idx and idx >= 1 and idx <= 8 then
		local col, row = (idx - 1) % 4, floor((idx - 1) / 4)
		d.raidMarker:SetTexCoord(col * 0.25, (col + 1) * 0.25, row * 0.25, (row + 1) * 0.25)
		d.raidMarker:Show()
	else
		d.raidMarker:Hide()
	end
end

-- Ready check > incoming resurrection (summon pending: no 5.4.8 API).
function B.PaintReady(btn, d, s, i)
	local tex = d.readyCheck
	local st = i.readyCheck
	if s.showReadyCheck and st and READY_TEX[st] then
		tex:SetTexture(READY_TEX[st])
		tex:SetTexCoord(0, 1, 0, 1)
		tex:Show()
		return
	end
	if s.showIncomingRez ~= false and i.dead and i.rez then
		tex:SetTexture(REZ_TEX)
		tex:SetTexCoord(0, 1, 0, 1)
		tex:Show()
		return
	end
	tex:Hide()
end

function B.PaintTail(btn, d, s, i)
	B.PaintTexts(btn, d, s, i)
	B.PaintRole(btn, d, s, i)
	B.PaintLeader(btn, d, s, i)
	B.PaintCombat(btn, d, s, i)
	B.PaintMarker(btn, d, s, i)
	B.PaintReady(btn, d, s, i)
	local isTarget = i.isTarget and true or false
	if isTarget ~= d.isTarget then
		d.isTarget = isTarget
		B.ApplyBorderColor(btn, d)
	end
	B.PaintThreat(btn, d, s, i.threat)
end

-------------------------------------------------------------------------------
--  UpdateButton: full repaint
-------------------------------------------------------------------------------
function RF.UpdateButton(btn)
	local d = btn and btn.rf
	if not d then
		return
	end
	local i = B.Gather(btn, d)
	if not i then
		return
	end
	local s = RF.SettingsFor(btn)
	d.gone = i.dead or i.offline
	B.PaintPower(btn, d, s, i)
	B.PaintHealth(btn, d, s, i)
	B.PaintAbsorbs(btn, d, s, i)
	B.PaintTail(btn, d, s, i)
	RF.UpdateDispelVisuals(btn)
	if i.preview then
		B.ApplyAlpha(btn, d, i.oor and (s.oorAlpha or 0.4) or 1)
	end
	if RF.AuraUpdate then
		RF.AuraUpdate(btn)
	end
	if RF.BM_Update then
		RF.BM_Update(btn)
	end
end

-- Light paths for the frequent unit events.
function B.UpdateHealth(btn)
	local d = btn.rf
	local i = d and B.Gather(btn, d, "hp")
	if not i then
		return
	end
	if (i.dead or i.offline) ~= d.gone then
		-- Death / resurrection / connection edge: everything repaints
		-- (status, rez icon, power text, the range rule).
		RF.UpdateButton(btn)
		B.UpdateRange(btn, d)
		return
	end
	local s = RF.SettingsFor(btn)
	B.PaintHealth(btn, d, s, i)
	B.PaintAbsorbs(btn, d, s, i)
	B.PaintValueTexts(btn, d, s, i)
end

function B.UpdatePower(btn)
	local d = btn.rf
	local i = d and B.Gather(btn, d, "pw")
	if not i then
		return
	end
	B.PaintPower(btn, d, RF.SettingsFor(btn), i)
end

function B.UpdateAbsorbsOnly(btn)
	local d = btn.rf
	local i = d and B.Gather(btn, d, "hp")
	if not i then
		return
	end
	local s = RF.SettingsFor(btn)
	B.PaintAbsorbs(btn, d, s, i)
	local hm = s.healAbsorbTextMode or "none"
	if hm ~= "none" and not i.dead and not i.offline then
		RF.FormatHealAbsorbInto(d.healAbsorbText, i.healAbsorb, hm)
	end
end

-------------------------------------------------------------------------------
--  Dispel visuals (retail ApplyRFDispelSlot) from btn.rfDispel:
--  nil or { type = "Magic"|..|"", canDispel = bool, icon = tex, spellId = n }
-------------------------------------------------------------------------------
function RF.UpdateDispelVisuals(btn)
	local d = btn and btn.rf
	if not d then
		return
	end
	local s = RF.SettingsFor(btn)
	local info = btn.rfDispel
	local p = btn.rfPreview
	if not info and type(p) == "table" and p.dispelType then
		info = d.previewDispel or {}
		d.previewDispel = info
		info.type, info.canDispel, info.icon = p.dispelType, true, nil
	end
	if info and s.dispelShowAll == false and not info.canDispel then
		info = nil
	end
	local ov, ov2 = d.dispelOverlay, d.dispelOverlay2
	if not info then
		ov:Hide()
		ov.rfFill = nil
		ov2:Hide()
		RF.LayoutEdges(d.dispelEdges, 0)
		d.dispelIconHost:Hide()
		if d.dispelBdr then
			d.dispelBdr = nil
			B.ApplyBorderColor(btn, d)
		end
		return
	end
	local dtype = info.type or ""
	local r, g, b = RF.GetDispelColor(dtype, s)
	local alpha = (s.dispelOverlayOpacity or 100) / 100
	local mode = s.dispelOverlay or "fill"
	local health = d.health
	ov:SetTexture(WHITE)
	ov:SetTexCoord(0, 1, 0, 1)
	ov2:Hide()
	ov.rfFill = nil
	if mode == "none" then
		ov:Hide()
	elseif mode == "full" then
		ov:ClearAllPoints()
		ov:SetAllPoints(health)
		ov:SetVertexColor(r, g, b, alpha)
		ov:Show()
	elseif mode == "gradient" or mode == "gradient_sharp" then
		-- Retail gradient textures: a type colour fading down from the top edge.
		-- 5.4.8: SetGradientAlpha on a flat texture (sharp = top half only).
		ov:ClearAllPoints()
		if mode == "gradient_sharp" then
			ov:SetPoint("TOPLEFT", health, "TOPLEFT", 0, 0)
			ov:SetPoint("BOTTOMRIGHT", health, "RIGHT", 0, 0)
		else
			ov:SetAllPoints(health)
		end
		ov:SetVertexColor(1, 1, 1, 1)
		ov:SetGradientAlpha("VERTICAL", r, g, b, 0, r, g, b, alpha)
		ov:Show()
	else
		ov:SetVertexColor(r, g, b, alpha)
		ov.rfFill = true
		Seg(ov, health, d.vert, 0, d.seam or 1)
	end

	-- Type-coloured border around the health bar.
	local bs = s.dispelBorderSize or 0
	if bs > 0 then
		RF.LayoutEdges(d.dispelEdges, bs, r, g, b, 1)
	else
		RF.LayoutEdges(d.dispelEdges, 0)
	end

	-- Type icon (Bleed has no type art: the debuff's own icon).
	if s.showDispelIcons == true then
		local tex = DISPEL_ICON_TEX[dtype] or info.icon
		if tex then
			d.dispelIcon:SetTexture(tex)
			if DISPEL_ICON_TEX[dtype] then
				d.dispelIcon:SetTexCoord(0, 1, 0, 1)
			else
				d.dispelIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			end
			d.dispelIconHost:Show()
		else
			d.dispelIconHost:Hide()
		end
	else
		d.dispelIconHost:Hide()
	end

	-- Color Custom Borders: the frame border in the dispel colour.
	local want = (s.dispelCustomBorder == true and RF.RF_CustomBorderOn(s)) and { r, g, b } or nil
	local cur = d.dispelBdr
	if (want == nil) ~= (cur == nil) or (want and (want[1] ~= cur[1] or want[2] ~= cur[2] or want[3] ~= cur[3])) then
		d.dispelBdr = want
		B.ApplyBorderColor(btn, d)
	end
end

-------------------------------------------------------------------------------
--  Range (retail range ticker: UnitInRange for living members, the class
--  rez spell for dead ones, a short-range class spell for Rogues; MoP IDs)
-------------------------------------------------------------------------------
local _, playerClass = UnitClass("player")
local REZ_SPELL_BY_CLASS = {
	DRUID = 50769,       -- Revive
	PRIEST = 2006,       -- Resurrection
	PALADIN = 7328,      -- Redemption
	SHAMAN = 2008,       -- Ancestral Spirit
	MONK = 115178,       -- Resuscitate
	DEATHKNIGHT = 61999, -- Raise Ally
	WARLOCK = 20707,     -- Soulstone
}
local FRIENDLY_SPELL_BY_CLASS = {
	ROGUE = 36554,       -- Shadowstep
}
-- Units UnitInRange cannot check (bosses, party targets): a friendly heal.
local HEAL_SPELL_BY_CLASS = {
	PRIEST = 2061, PALADIN = 19750, SHAMAN = 8004, DRUID = 5185, MONK = 115175,
}

local function KnownSpellName(id)
	if not id or not IsSpellKnown(id) then
		return nil
	end
	return (GetSpellInfo(id))
end

local function SpellRange(id, unit)
	local name = KnownSpellName(id)
	if not name then
		return nil
	end
	local r = IsSpellInRange(name, unit)
	if r == 1 then
		return true
	elseif r == 0 then
		return false
	end
	return nil
end

local GROUP_TOKEN = { player = true, pet = true }
local function IsGroupToken(unit)
	return GROUP_TOKEN[unit] or unit:find("^raid%d") or unit:find("^party%d") or unit:find("^raidpet%d")
		or unit:find("^partypet%d")
end

function B.InRange(unit)
	if UnitIsUnit(unit, "player") then
		return true
	end
	if not UnitIsConnected(unit) then
		return true
	end
	if UnitIsDeadOrGhost(unit) then
		local r = SpellRange(REZ_SPELL_BY_CLASS[playerClass], unit)
		if r ~= nil then
			return r
		end
	else
		local r = SpellRange(FRIENDLY_SPELL_BY_CLASS[playerClass], unit)
		if r ~= nil then
			return r
		end
	end
	local inR, checked = UnitInRange(unit)
	if checked == nil then
		checked = IsGroupToken(unit) and true or false
	end
	if checked then
		return inR and true or false
	end
	local r = SpellRange(HEAL_SPELL_BY_CLASS[playerClass], unit)
	if r ~= nil then
		return r
	end
	return UnitIsVisible(unit) and true or false
end

function B.ApplyAlpha(btn, d, a)
	if d.rangeAlpha ~= a then
		d.rangeAlpha = a
		btn:SetAlpha((btn._bmSavedAlpha or 1) * a)
	end
end

function B.UpdateRange(btn, d)
	d = d or btn.rf
	if not d or btn.rfPreview then
		return
	end
	local unit = RF.UnitOf(btn)
	if not unit then
		return
	end
	local s = RF.SettingsFor(btn)
	local a = B.InRange(unit) and 1 or (s.oorAlpha or 0.4)
	B.ApplyAlpha(btn, d, a)
end

-------------------------------------------------------------------------------
--  Ready check / incoming resurrection state
-------------------------------------------------------------------------------
local readyActive = false
local readyHideAt = nil

function B.ReadyStatus(unit)
	if not readyActive and not readyHideAt then
		return nil
	end
	local st = GetReadyCheckStatus(unit)
	if readyHideAt and not readyActive and st == "waiting" then
		st = "notready"
	end
	return st
end

-- 5.4.8 has no UnitHasIncomingResurrection: track group members' resurrection
-- casts (UNIT_SPELLCAST_START, the target = the caster's target) and keep the
-- unaccepted offer latched for 60 s after a successful cast (retail latch).
local REZ_SPELLS = {
	[2006] = true, [7328] = true, [2008] = true, [50769] = true, [115178] = true,
	[20484] = true, [61999] = true, [20707] = true, [126393] = true, [83968] = "mass",
}
local rezByCaster = {}  -- [casterGUID] = targetGUID | "mass"
local rezPending = {}   -- [targetGUID] = expiry time (latched offer)

function B.RezShown(unit)
	if not UnitIsDeadOrGhost(unit) then
		return false
	end
	-- Not in the 5.4.8 API list (ElvUI MoP calls it); used only if present.
	if UnitHasIncomingResurrection and UnitHasIncomingResurrection(unit) then
		return true
	end
	local guid = UnitGUID(unit)
	if not guid then
		return false
	end
	for _, tgt in pairs(rezByCaster) do
		if tgt == guid or tgt == "mass" then
			return true
		end
	end
	local exp = rezPending[guid]
	if exp and GetTime() < exp then
		return true
	end
	return false
end

-------------------------------------------------------------------------------
--  Events: one frame, routed through RF.ButtonsForUnit
-------------------------------------------------------------------------------
local function ForUnit(unit, fn)
	local set = unitMap[unit]
	if not set then
		return
	end
	for btn in pairs(set) do
		if btn.rf then
			fn(btn)
		end
	end
end
B.ForUnit = ForUnit

local function ForAll(fn)
	for btn in pairs(allButtons) do
		if btn.rf and (btn.rfPreview or RF.UnitOf(btn)) then
			fn(btn)
		end
	end
end
B.ForAll = ForAll

local function TailOnly(btn)
	local d = btn.rf
	local i = B.Gather(btn, d)
	if i then
		B.PaintTail(btn, d, RF.SettingsFor(btn), i)
	end
end

local function TargetOnly(btn)
	local d = btn.rf
	local unit = RF.UnitOf(btn)
	local isTarget = (unit and UnitIsUnit(unit, "target")) and true or false
	if isTarget ~= d.isTarget then
		d.isTarget = isTarget
		B.ApplyBorderColor(btn, d)
	end
end

local function ThreatOnly(btn)
	local unit = RF.UnitOf(btn)
	if unit then
		B.PaintThreat(btn, btn.rf, RF.SettingsFor(btn), UnitThreatSituation(unit))
	end
end

local function ReadyOnly(btn)
	local d = btn.rf
	local i = B.Gather(btn, d)
	if i then
		local s = RF.SettingsFor(btn)
		B.PaintReady(btn, d, s, i)
		B.PaintStatus(btn, d, s, i)
	end
end

local function RosterAll()
	for btn in pairs(allButtons) do
		B.Remap(btn)
	end
	ForAll(RF.UpdateButton)
	ForAll(B.UpdateRange)
end

-- Coalesce roster bursts into one pass.
local rosterTimer = nil
local function QueueRoster()
	if rosterTimer then
		return
	end
	rosterTimer = RF.After(0.05, function()
		rosterTimer = nil
		RosterAll()
	end)
end
B.QueueRoster = QueueRoster

local UNIT_HANDLERS = {
	UNIT_HEALTH = B.UpdateHealth,
	UNIT_HEALTH_FREQUENT = B.UpdateHealth,
	UNIT_MAXHEALTH = B.UpdateHealth,
	UNIT_CONNECTION = RF.UpdateButton,
	UNIT_POWER = B.UpdatePower,
	UNIT_POWER_FREQUENT = B.UpdatePower,
	UNIT_MAXPOWER = B.UpdatePower,
	UNIT_DISPLAYPOWER = B.UpdatePower,
	UNIT_ABSORB_AMOUNT_CHANGED = B.UpdateAbsorbsOnly,
	UNIT_HEAL_ABSORB_AMOUNT_CHANGED = B.UpdateAbsorbsOnly,
	UNIT_HEAL_PREDICTION = B.UpdateAbsorbsOnly,
	UNIT_NAME_UPDATE = TailOnly,
	UNIT_LEVEL = TailOnly,
	UNIT_FLAGS = TailOnly,
	PLAYER_FLAGS_CHANGED = TailOnly,
	UNIT_THREAT_SITUATION_UPDATE = ThreatOnly,
	UNIT_ENTERED_VEHICLE = RF.UpdateButton,
	UNIT_EXITED_VEHICLE = RF.UpdateButton,
	INCOMING_RESURRECT_CHANGED = ReadyOnly,
}

local ef = CreateFrame("Frame")
B.eventFrame = ef
for e in pairs(UNIT_HANDLERS) do
	ef:RegisterEvent(e)
end
for _, e in ipairs({
	"PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "PLAYER_ROLES_ASSIGNED",
	"PLAYER_SPECIALIZATION_CHANGED", "PLAYER_TARGET_CHANGED", "RAID_TARGET_UPDATE", "PLAYER_REGEN_DISABLED",
	"PLAYER_REGEN_ENABLED", "READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED", "UNIT_TARGET",
	"UNIT_PET", "INSTANCE_ENCOUNTER_ENGAGE_UNIT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP",
	"UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_SUCCEEDED",
}) do
	ef:RegisterEvent(e)
end

local function BossCombat()
	return inCombat and UnitExists("boss1") and true or false
end

ef:SetScript("OnEvent", function(self, event, unit, ...)
	local h = UNIT_HANDLERS[event]
	if h then
		if unit then
			ForUnit(unit, h)
		end
		return
	end
	if event == "UNIT_TARGET" then
		-- partyNtarget style buttons have no unit events of their own.
		if unit then
			ForUnit(unit .. "target", RF.UpdateButton)
		end
	elseif event == "PLAYER_TARGET_CHANGED" then
		ForAll(TargetOnly)
		ForUnit("target", RF.UpdateButton)
		ForUnit("playertarget", RF.UpdateButton)
	elseif event == "RAID_TARGET_UPDATE" then
		ForAll(TailOnly)
	elseif event == "PLAYER_REGEN_DISABLED" then
		inCombat = true
		inBossCombat = BossCombat()
		ForAll(TailOnly)
	elseif event == "PLAYER_REGEN_ENABLED" then
		inCombat = false
		inBossCombat = false
		ForAll(TailOnly)
	elseif event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
		inBossCombat = BossCombat()
		ForUnit("boss1", RF.UpdateButton)
		ForUnit("boss2", RF.UpdateButton)
		ForUnit("boss3", RF.UpdateButton)
		ForUnit("boss4", RF.UpdateButton)
		ForUnit("boss5", RF.UpdateButton)
	elseif event == "READY_CHECK" then
		readyActive, readyHideAt = true, nil
		ForAll(ReadyOnly)
	elseif event == "READY_CHECK_CONFIRM" then
		if unit then
			ForUnit(unit, ReadyOnly)
		end
	elseif event == "READY_CHECK_FINISHED" then
		-- Keep the result visible for a few seconds like Blizzard's frames.
		readyActive = false
		local at = GetTime() + 6
		readyHideAt = at
		ForAll(ReadyOnly)
		RF.After(6, function()
			if readyHideAt == at then
				readyHideAt = nil
				ForAll(ReadyOnly)
			end
		end)
	elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_SUCCEEDED" then
		local spellId = select(4, ...)
		local kind = spellId and REZ_SPELLS[spellId]
		if not kind or not unit then
			return
		end
		local caster = UnitGUID(unit)
		if not caster then
			return
		end
		if event == "UNIT_SPELLCAST_START" then
			local tgt = "mass"
			if kind ~= "mass" then
				tgt = UnitGUID(unit == "player" and "target" or (unit .. "target"))
			end
			if tgt then
				rezByCaster[caster] = tgt
				ForAll(ReadyOnly)
			end
		else
			local tgt = rezByCaster[caster]
			rezByCaster[caster] = nil
			if tgt and tgt ~= "mass" then
				rezPending[tgt] = GetTime() + 60
			end
			ForAll(ReadyOnly)
		end
	elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
		local caster = unit and UnitGUID(unit)
		if caster and rezByCaster[caster] then
			-- STOP also fires right before SUCCEEDED: latch first, then clear.
			local tgt = rezByCaster[caster]
			if event == "UNIT_SPELLCAST_STOP" then
				RF.After(0.2, function()
					if rezByCaster[caster] == tgt then
						rezByCaster[caster] = nil
						ForAll(ReadyOnly)
					end
				end)
			else
				rezByCaster[caster] = nil
				ForAll(ReadyOnly)
			end
		end
	else
		-- PLAYER_ENTERING_WORLD, roster, leader, roles, spec, pets.
		if event == "PLAYER_ENTERING_WORLD" then
			inCombat = InCombatLockdown() and true or false
			wipe(rezByCaster)
		end
		QueueRoster()
	end
end)

-- Range ticker (retail polls at 0.2 s) + units without own events
-- (party targets) repainted every 0.5 s.
local polls = 0
RF.NewTicker(0.2, function()
	polls = polls + 1
	local full = polls % 3 == 0
	for btn in pairs(allButtons) do
		local d = btn.rf
		if d and not btn.rfPreview and btn:IsVisible() then
			local unit = RF.UnitOf(btn)
			if unit then
				B.UpdateRange(btn, d)
				if full and unit:find("target$") then
					RF.UpdateButton(btn)
				end
			end
		end
	end
	-- Latched resurrection offers expire.
	if full then
		local now = GetTime()
		for g, exp in pairs(rezPending) do
			if now >= exp then
				rezPending[g] = nil
			end
		end
	end
end)

-------------------------------------------------------------------------------
--  Apply (order 20: buttons): relayout + repaint every styled button.
-------------------------------------------------------------------------------
RF.OnApply(function()
	for btn in pairs(allButtons) do
		if btn.rf then
			RF.RelayoutButton(btn)
			B.UpdateRange(btn, btn.rf)
		end
	end
end, 20)
