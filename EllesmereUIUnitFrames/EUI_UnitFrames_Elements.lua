-- EllesmereUI Unit Frames for 5.4.8: element updates (health, power, texts,
-- portrait, cast bar, absorbs, indicators, visibility).

local addonName = ...
local ns = EllesmereUI
local UF = ns.UF

local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local format = format
local GetTime = GetTime

---------------------------------------------------------------------------
-- Preview data (settings open / Unlock Mode, unit does not exist)
---------------------------------------------------------------------------
local PREVIEW_NAMES = { "Doomguard", "Dreadlord", "Infernal", "Sea Giant", "Ogre Mage", "Satyr", "Stone Golem", "Water Elemental" }
local PREVIEW_BOSSES = { "Lei Shen", "Garrosh Hellscream", "Ji-Kun", "Horridon", "Durumu", "Sha of Fear", "Grand Empress Shek'zeer", "Immerseus" }

function UF.PreviewData(frame)
	local data = frame.previewData
	if not data then
		local seed = #frame.unitKey + (tonumber(frame.unitKey:match("%d")) or 0)
		data = {
			health = 0.6 + (seed % 4) * 0.08,
			power = 0.5 + (seed % 5) * 0.09,
			name = frame.isBoss and PREVIEW_BOSSES[(seed % #PREVIEW_BOSSES) + 1] or PREVIEW_NAMES[(seed % #PREVIEW_NAMES) + 1],
			cast = 0.4 + (seed % 5) * 0.1,
		}
		frame.previewData = data
	end
	return data
end

-- True when the frame shows fake data (preview of a unit that does not exist).
local function Fake(frame)
	return frame.preview and not UnitExists(frame.unit)
end
UF.IsFake = Fake

---------------------------------------------------------------------------
-- Smooth bars (own lerp; 5.4.8 has no StatusBar interpolation)
---------------------------------------------------------------------------
local smoothFrame = CreateFrame("Frame")
local smoothing = {}
smoothFrame:Hide()
smoothFrame:SetScript("OnUpdate", function(self, elapsed)
	local any = false
	local k = min(1, elapsed * 12)
	for bar, target in pairs(smoothing) do
		local cur = bar.shown or target
		local new = cur + (target - cur) * k
		if abs(new - target) < 0.002 then
			new = target
			smoothing[bar] = nil
		else
			any = true
		end
		bar.shown = new
		bar:SetValue(new)
		if bar.onSmooth then
			bar.onSmooth(bar, new)
		end
	end
	if not any and next(smoothing) == nil then
		self:Hide()
	end
end)

local function SetBarValue(bar, pct, smooth)
	if smooth and bar.shown and abs(bar.shown - pct) > 0.002 then
		smoothing[bar] = pct
		smoothFrame:Show()
		return
	end
	smoothing[bar] = nil
	bar.shown = pct
	bar:SetValue(pct)
	if bar.onSmooth then
		bar.onSmooth(bar, pct)
	end
end

---------------------------------------------------------------------------
-- Health
---------------------------------------------------------------------------
local function Lerp(a, b, t)
	return a + (b - a) * t
end

-- Dynamic Color: 3 stops by health left (0, 50, 100 %).
local function Dynamic(pct, c0, c50, c100)
	if pct >= 0.5 then
		local t = (pct - 0.5) * 2
		return Lerp(c50[1], c100[1], t), Lerp(c50[2], c100[2], t), Lerp(c50[3], c100[3], t)
	end
	local t = pct * 2
	return Lerp(c0[1], c50[1], t), Lerp(c0[2], c50[2], t), Lerp(c0[3], c50[3], t)
end

local function ColorTriple(c, r, g, b)
	if c and c.r then
		return { c.r, c.g, c.b }
	end
	return { r, g, b }
end

local function HealthColor(frame, s, unit, pct)
	if Fake(frame) then
		if s.healthClassColored ~= false or frame.isMini then
			return UF.PlayerClassColor()
		end
	elseif not UnitIsConnected(unit) then
		return 0.6, 0.6, 0.6
	end
	local mode = s.healthColorMode or "none"
	if mode == "classic" then
		return Dynamic(pct, { 1, 0, 0 }, { 1, 1, 0 }, { 0, 1, 0 })
	elseif mode == "customDynamic" then
		return Dynamic(pct, ColorTriple(s.dynamicColor0, 0xE3 / 255, 0x30 / 255, 0x30 / 255),
			ColorTriple(s.dynamicColor50, 0xEC / 255, 0xEC / 255, 0x32 / 255), ColorTriple(s.dynamicColor100, 0, 1, 0))
	elseif mode == "classReactive" then
		local r, g, b = UF.UnitColor(unit)
		return Dynamic(pct, ColorTriple(s.dynamicColor0, 0xE3 / 255, 0x30 / 255, 0x30 / 255),
			ColorTriple(s.dynamicColor50, 0xEC / 255, 0xEC / 255, 0x32 / 255), { r, g, b })
	end
	if s.healthClassColored ~= false then
		if frame.unitKey == "pet" then
			return UF.PlayerClassColor()
		end
		return UF.UnitColor(unit)
	end
	local c = s.customFillColor
	if c then
		return c.r, c.g, c.b
	end
	return 37 / 255, 193 / 255, 29 / 255
end

-- The background covers only the missing part (EllesmereUI look).
local function PlaceHealthBg(bar, pct)
	local frame = bar.owner
	local s = frame.settings
	local bg = bar.bg
	bg:ClearAllPoints()
	local missing = 1 - pct
	if missing <= 0 then
		bg:Hide()
		return
	end
	bg:Show()
	if s.healthVerticalFill then
		local h = bar:GetHeight() * missing
		if s.healthReverseFill then
			bg:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT")
			bg:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
		else
			bg:SetPoint("TOPLEFT", bar, "TOPLEFT")
			bg:SetPoint("TOPRIGHT", bar, "TOPRIGHT")
		end
		bg:SetHeight(max(0.01, h))
	else
		local w = bar:GetWidth() * missing
		if s.healthReverseFill then
			bg:SetPoint("TOPLEFT", bar, "TOPLEFT")
			bg:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT")
		else
			bg:SetPoint("TOPRIGHT", bar, "TOPRIGHT")
			bg:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
		end
		bg:SetWidth(max(0.01, w))
	end
end

function UF.UpdateHealth(frame)
	local s = frame.settings
	local unit = frame.unit
	local health = frame.Health
	local cur, maxHP
	if Fake(frame) then
		maxHP = 100
		cur = UF.PreviewData(frame).health * 100
	else
		cur, maxHP = UnitHealth(unit), UnitHealthMax(unit)
		if not UnitIsConnected(unit) then
			cur = maxHP
		end
	end
	if not maxHP or maxHP <= 0 then
		maxHP, cur = 1, 0
	end
	local pct = min(1, max(0, cur / maxHP))
	frame.healthPct = pct
	health.owner = frame
	health.onSmooth = PlaceHealthBg
	SetBarValue(health, pct, s.smoothBars)

	local alpha = (s.healthBarOpacity or 90) / 100
	local tex = health:GetStatusBarTexture()
	local r, g, b
	if UF.db.darkTheme then
		r, g, b = 0.067, 0.067, 0.067
		alpha = 0.9
		-- Global Settings > Colors: Dark Mode Fill
		if ns.GetDarkModeFill then r, g, b, alpha = ns.GetDarkModeFill() end
	else
		r, g, b = HealthColor(frame, s, unit, pct)
	end
	if s.gradientEnabled and not UF.db.darkTheme then
		local gc = s.gradientColor or { r = 0.2, g = 0.2, b = 0.8 }
		tex:SetVertexColor(1, 1, 1, 1)
		tex:SetGradientAlpha(s.gradientDir or "HORIZONTAL", r, g, b, alpha, gc.r, gc.g, gc.b, alpha)
	else
		tex:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 1)
		tex:SetVertexColor(r, g, b, alpha)
	end

	-- Background (missing part)
	local bgr, bgg, bgb, bga
	if UF.db.darkTheme then
		bgr, bgg, bgb, bga = 0.31, 0.31, 0.31, 1
		-- Global Settings > Colors: Dark Mode Background
		if ns.GetDarkModeBg then bgr, bgg, bgb, bga = ns.GetDarkModeBg() end
	elseif s.bgClassColored then
		if frame.unitKey == "pet" then
			bgr, bgg, bgb = UF.PlayerClassColor()
		else
			bgr, bgg, bgb = UF.UnitColor(unit)
		end
		bga = (s.customBgAlpha or 100) / 100
	else
		local c = s.customBgColor
		bgr, bgg, bgb = c and c.r or 0.067, c and c.g or 0.067, c and c.b or 0.067
		bga = (s.customBgAlpha or 100) / 100
	end
	health.bg:SetVertexColor(bgr, bgg, bgb, bga)
	PlaceHealthBg(health, health.shown or pct)
end

---------------------------------------------------------------------------
-- Power
---------------------------------------------------------------------------
local function GrayPower(unit)
	-- Attackable NPCs with no real power get a grey background.
	return UnitCanAttack("player", unit) and not UnitIsPlayer(unit)
		and UnitClassification(unit) ~= "worldboss" and UnitPowerMax(unit) == 0
end

function UF.UpdatePower(frame)
	local s = frame.settings
	local power = frame.Power
	if not power:IsShown() then
		return
	end
	local unit = frame.unit
	local cur, maxP, pType, token
	if Fake(frame) then
		pType, token = 0, "MANA"
		if frame.unitKey == "player" or frame.unitKey == "pet" then
			pType, token = UnitPowerType(frame.unitKey == "pet" and "player" or "player")
		end
		maxP, cur = 100, UF.PreviewData(frame).power * 100
	else
		pType, token = UnitPowerType(unit)
		cur, maxP = UnitPower(unit, pType), UnitPowerMax(unit, pType)
	end
	local pct = (maxP and maxP > 0) and min(1, cur / maxP) or 0
	SetBarValue(power, pct, s.smoothBars)
	frame.powerCur, frame.powerMax, frame.powerToken = cur, maxP, token

	local r, g, b = UF.PowerColor(token, pType)
	local alpha = (s.powerBarOpacity or 100) / 100
	local tex = power:GetStatusBarTexture()
	local fr, fg, fb = r, g, b
	if s.powerPercentPowerColor == false then
		local c = s.customPowerFillColor
		fr, fg, fb = c and c.r or 0, c and c.g or 0, c and c.b or 1
	end
	if s.powerGradientEnabled then
		local gc = s.powerGradientColor or { r = 0.2, g = 0.2, b = 0.8 }
		tex:SetVertexColor(1, 1, 1, 1)
		tex:SetGradientAlpha(s.powerGradientDir or "HORIZONTAL", fr, fg, fb, alpha, gc.r, gc.g, gc.b, alpha)
	else
		tex:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 1)
		tex:SetVertexColor(fr, fg, fb, alpha)
	end
	local bga = (s.customPowerBgAlpha or 100) / 100
	if not Fake(frame) and GrayPower(unit) then
		power.bg:SetVertexColor(0.25, 0.25, 0.25, 1)
	elseif s.powerBgPowerColored then
		power.bg:SetVertexColor(r * 0.25, g * 0.25, b * 0.25, bga)
	else
		local c = s.customPowerBgColor
		power.bg:SetVertexColor(c and c.r or 0.067, c and c.g or 0.067, c and c.b or 0.067, bga)
	end

	-- Power text
	local fs = frame.PowerText
	if fs:IsShown() then
		local fmt = s.powerTextFormat or "perpp"
		local sign = s.powerShowPercent ~= false and "%" or ""
		local percent = floor(pct * 100 + 0.5)
		local text
		if fmt == "curpp" then
			text = UF.Abbrev(cur)
		elseif fmt == "both" then
			text = UF.Abbrev(cur) .. " | " .. percent .. sign
		elseif fmt == "smart" then
			text = (token == "MANA") and (percent .. sign) or UF.Abbrev(cur)
		else
			text = percent .. sign
		end
		fs:SetText(text)
		if s.powerPercentTextPowerColor then
			fs:SetTextColor(r, g, b, 1)
		else
			local c = s.powerTextColor
			fs:SetTextColor(c and c.r or 1, c and c.g or 1, c and c.b or 1, 1)
		end
	end
end

---------------------------------------------------------------------------
-- Texts
---------------------------------------------------------------------------
local function UnitNameShort(unit)
	local name = UnitName(unit)
	return name or ""
end

-- Name Format (retail <prefix>NameFormat): "first" = first word, "last" =
-- last word, nil = the whole name.
local function FormatName(name, mode)
	if not name or name == "" or not mode then
		return name
	end
	if mode == "first" then
		return name:match("^(%S+)") or name
	elseif mode == "last" then
		return name:match("(%S+)$") or name
	end
	return name
end
UF.FormatName = FormatName

local function LevelText(frame, unit, s)
	local level = Fake(frame) and (frame.isBoss and -1 or UnitLevel("player")) or UnitLevel(unit)
	local text = (level and level > 0) and tostring(level) or "??"
	if s.levelDifficultyColor and level then
		local friendly = not Fake(frame) and not UnitCanAttack("player", unit)
		if not friendly or s.levelDifficultyColorFriendly then
			local c
			if level <= 0 then
				c = { r = 1, g = 0.1, b = 0.1 }
			else
				c = GetQuestDifficultyColor(level)
			end
			text = UF.Hex(c.r, c.g, c.b) .. text .. "|r"
		end
	end
	return text
end

local function Decimals(frame)
	local db = UF.db
	if not db.showDecimalOnText then
		return 0
	end
	if frame.isBoss and db.showDecimalBoss2 ~= false then
		return 2
	end
	return 1
end

local function PercentText(frame, pct, withSign)
	local dec = Decimals(frame)
	local value = pct * 100
	local text
	if dec > 0 then
		text = format("%." .. dec .. "f", floor(value * 10 ^ dec) / 10 ^ dec)
		if UF.db.showDecimalTrimZeros then
			text = text:gsub("%.?0+$", "")
		end
	else
		text = format("%d", floor(value + 0.5))
	end
	return withSign and (text .. "%") or text
end

local function HealthValueText(frame, unit, cur)
	if not Fake(frame) then
		if not UnitIsConnected(unit) then
			return "OFFLINE"
		end
		if UnitIsDeadOrGhost(unit) then
			return "DEAD"
		end
	end
	local dec = (UF.db.showDecimalPercentOnly) and 0 or Decimals(frame)
	return UF.Abbrev(cur, dec)
end

local function ClassColorPrefix(unit, frame)
	if Fake(frame) then
		return UF.Hex(UF.PlayerClassColor())
	end
	return UF.Hex(UF.UnitColor(unit))
end

-- Text of one content key ("name", "both", ...). prefix = settings prefix for
-- the Name > Target separator options.
function UF.ContentText(frame, content, prefix)
	local unit = frame.unit
	local s = frame.settings
	local fake = Fake(frame)
	local cur, maxHP
	if fake then
		cur, maxHP = UF.PreviewData(frame).health * 100000, 100000
	else
		cur, maxHP = UnitHealth(unit), UnitHealthMax(unit)
	end
	local pct = (maxHP and maxHP > 0) and cur / maxHP or 0
	if not fake and UnitIsDeadOrGhost(unit) then
		pct = 0
	end
	local name = fake and UF.PreviewData(frame).name or UnitNameShort(unit)
	local nameFormat = prefix and s[prefix .. "NameFormat"]
	name = FormatName(name, nameFormat)
	if content == "name" then
		return name
	elseif content == "level" then
		return LevelText(frame, unit, s)
	elseif content == "levelname" then
		return LevelText(frame, unit, s) .. " | " .. name
	elseif content == "namelevel" then
		return name .. " | " .. LevelText(frame, unit, s)
	elseif content == "perhp" then
		return PercentText(frame, pct, true)
	elseif content == "perhpnosign" then
		return PercentText(frame, pct, false)
	elseif content == "curhpshort" then
		return HealthValueText(frame, unit, cur)
	elseif content == "both" then
		return HealthValueText(frame, unit, cur) .. " | " .. PercentText(frame, pct, true)
	elseif content == "bothdash" then
		return HealthValueText(frame, unit, cur) .. " - " .. PercentText(frame, pct, true)
	elseif content == "perhpnum" then
		return PercentText(frame, pct, true) .. " | " .. HealthValueText(frame, unit, cur)
	elseif content == "perhpnumdash" then
		return PercentText(frame, pct, true) .. " - " .. HealthValueText(frame, unit, cur)
	elseif content == "absorb" or content == "absorbshort" then
		local value = fake and 0 or (UnitGetTotalAbsorbs and UnitGetTotalAbsorbs(unit) or 0)
		if value <= 0 then
			return ""
		end
		return content == "absorb" and tostring(value) or UF.Abbrev(value)
	elseif content == "healabsorb" or content == "healabsorbshort" then
		local value = fake and 0 or (UnitGetTotalHealAbsorbs and UnitGetTotalHealAbsorbs(unit) or 0)
		if value <= 0 then
			return ""
		end
		return content == "healabsorb" and tostring(value) or UF.Abbrev(value)
	elseif content == "group" then
		if not IsInRaid() then
			return ""
		end
		local idx = UnitInRaid(unit)
		if idx then
			local _, _, subgroup = GetRaidRosterInfo(idx)
			return subgroup and tostring(subgroup) or ""
		end
		return ""
	elseif content == "nametotarget" or content == "targetname" then
		local tunit = unit .. "target"
		local tname = (not fake and UnitExists(tunit)) and FormatName(UnitName(tunit), nameFormat) or nil
		local sepColor
		if s[prefix .. "TargetSepClassColor"] and tname then
			sepColor = UF.Hex(UF.UnitColor(tunit))
		else
			local c = s[prefix .. "TargetSepColor"]
			sepColor = c and UF.Hex(c.r or 1, c.g or 1, c.b or 1) or "|cffffffff"
		end
		local targetText = tname and (UF.Hex(UF.UnitColor(tunit)) .. tname .. "|r") or nil
		if content == "targetname" then
			if not targetText then
				return ""
			end
			local p = s[prefix .. "TargetPrefix"]
			if p == nil then
				p = "T:"
			end
			return (p ~= "" and (sepColor .. p .. "|r ") or "") .. targetText
		end
		if not targetText then
			return name
		end
		local sep = s[prefix .. "TargetSep"]
		if type(sep) ~= "string" or sep == "" then
			sep = ">"
		end
		return name .. sepColor .. " " .. sep .. " |r" .. targetText
	end
	-- Text bar power contents
	local pcur, pmax = frame.powerCur, frame.powerMax
	if fake then
		pcur, pmax = UF.PreviewData(frame).power * 100, 100
	elseif not pcur then
		local pType = UnitPowerType(unit)
		pcur, pmax = UnitPower(unit, pType), UnitPowerMax(unit, pType)
	end
	local ppct = (pmax and pmax > 0) and floor(pcur / pmax * 100 + 0.5) or 0
	if content == "perpp" then
		return ppct .. "%"
	elseif content == "curpp" then
		return UF.Abbrev(pcur)
	elseif content == "curhp_curpp" then
		return HealthValueText(frame, unit, cur) .. " | " .. UF.Abbrev(pcur)
	elseif content == "perhp_perpp" then
		return PercentText(frame, pct, true) .. " | " .. ppct .. "%"
	end
	return ""
end

function UF.UpdateTexts(frame)
	local s = frame.settings
	local unit = frame.unit
	for slot, fs in pairs(frame.Texts) do
		if fs:IsShown() then
			local prefix = slot .. "Text"
			local content = s[prefix .. "Content"] or "none"
			fs:SetText(UF.ContentText(frame, content, prefix))
			if s[prefix .. "ClassColor"] then
				if Fake(frame) or frame.unitKey == "pet" then
					fs:SetTextColor(UF.PlayerClassColor())
				else
					fs:SetTextColor(UF.UnitColor(unit))
				end
			else
				fs:SetTextColor(s[prefix .. "ColorR"] or 1, s[prefix .. "ColorG"] or 1, s[prefix .. "ColorB"] or 1, 1)
			end
		end
	end
	local btb = frame.TextBar
	if btb and btb:IsShown() then
		for prefix, fs in pairs(btb.texts) do
			if fs:IsShown() then
				local content = s[prefix .. "Content"] or "none"
				fs:SetText(UF.ContentText(frame, content, prefix))
				if s[prefix .. "ClassColor"] then
					fs:SetTextColor(Fake(frame) and UF.PlayerClassColor() or UF.UnitColor(unit))
				elseif s[prefix .. "PowerColor"] then
					fs:SetTextColor(UF.PowerColor(frame.powerToken or select(2, UnitPowerType(unit))))
				else
					fs:SetTextColor(s[prefix .. "ColorR"] or 1, s[prefix .. "ColorG"] or 1, s[prefix .. "ColorB"] or 1, 1)
				end
			end
		end
		if btb.classIcon:IsShown() then
			local class = select(2, UnitClass(Fake(frame) and "player" or unit))
			local coords = class and UF.CLASS_SPRITE[class]
			if coords and (Fake(frame) or UnitIsPlayer(unit)) then
				btb.classIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
				btb.classIcon:SetAlpha(1)
			else
				btb.classIcon:SetAlpha(0)
			end
		end
	end
end

---------------------------------------------------------------------------
-- Portrait
---------------------------------------------------------------------------
function UF.UpdatePortrait(frame)
	local p = frame.Portrait
	if not p:IsShown() then
		return
	end
	local s = frame.settings
	local unit = Fake(frame) and "player" or frame.unit
	local mode = s.portraitMode or UF.db.portraitMode or "2d"
	local isPlayer = UnitIsPlayer(unit)
	if mode == "class" and not isPlayer then
		mode = s.portraitNonPlayerOn and (s.portraitNonPlayer or "2d") or "2d"
	end
	local detached = UF.PortraitStyle(frame, s) == "detached"
	local shape = detached and (s.detachedPortraitShape or "portrait") or "square"
	local mirror = s.portraitMirror

	p.tex:Hide()
	p.classTex:Hide()
	if p.model then
		p.model:Hide()
	end
	if mode == "none" then
		return
	end
	if mode == "3d" then
		local model = UF.EnsureModel(p)
		model:Show()
		if not UnitIsVisible(unit) or not UnitIsConnected(unit) then
			model:SetCamDistanceScale(0.25)
			model:SetPortraitZoom(0)
			model:SetPosition(0, 0, 0.5)
			model:ClearModel()
			model:SetModel("Interface\\Buttons\\TalkToMeQuestionMark.m2")
		elseif model.guid ~= UnitGUID(unit) or model.forceUpdate then
			model:ClearModel()
			model:SetUnit(unit)
			model:SetPortraitZoom(1)
			model:SetCamDistanceScale(100 / max(50, s.portrait3dZoom or 100))
			model:SetPosition(0, 0, 0)
			model.guid = UnitGUID(unit)
			model.forceUpdate = nil
		end
		return
	elseif mode == "class" then
		local class = select(2, UnitClass(unit))
		local coords = class and UF.CLASS_SPRITE[class]
		if coords then
			local zoom = (s.portraitClassZoom or 100) / 100
			local inset = floor(p:GetHeight() * 0.08 + 0.5)
			p.classTex:ClearAllPoints()
			p.classTex:SetPoint("TOPLEFT", inset, -inset)
			p.classTex:SetPoint("BOTTOMRIGHT", -inset, inset)
			p.classTex:SetTexture(UF.ClassArtPath(s.classThemeStyle))
			local l, r, t, b = coords[1], coords[2], coords[3], coords[4]
			local cut = (r - l) * (1 - 1 / max(0.5, zoom)) / 2
			if zoom > 1 then
				l, r, t, b = l + cut, r - cut, t + cut, b - cut
			end
			if mirror then
				l, r = r, l
			end
			p.classTex:SetTexCoord(l, r, t, b)
			p.classTex:Show()
		end
		return
	end
	-- 2D: SetPortraitTexture gives a round picture; the 0.15 crop fills a square.
	if UnitExists(unit) and UnitIsConnected(unit) then
		SetPortraitTexture(p.tex, unit)
	else
		p.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
	end
	local crop = 0.15 * (s.portraitArtScale or 100) / 100
	if shape == "circle" then
		crop = 0
	end
	if mirror then
		p.tex:SetTexCoord(1 - crop, crop, crop, 1 - crop)
	else
		p.tex:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
	end
	p.tex:Show()
end

-- Detached portrait border / ring color (class or custom).
function UF.UpdatePortraitBorder(frame)
	local p = frame.Portrait
	if not p:IsShown() then
		return
	end
	local s = frame.settings
	if UF.PortraitStyle(frame, s) ~= "detached" then
		return
	end
	local r, g, b
	if s.detachedPortraitClassColor ~= false then
		r, g, b = Fake(frame) and UF.PlayerClassColor() or UF.UnitColor(frame.unit)
		if UF.db.darkTheme and not s.detachedPortraitUnitColorDark then
			r, g, b = UF.PlayerClassColor()
		end
	else
		local c = s.detachedPortraitBorderColor or {}
		r, g, b = c.r or 0, c.g or 0, c.b or 0
	end
	local a = (s.detachedPortraitBorderOpacity or 100) / 100
	p.border:SetBorderColor(r, g, b, a)
	p.ring:SetVertexColor(r, g, b, a)
end

---------------------------------------------------------------------------
-- Absorbs and heal prediction (horizontal bars)
---------------------------------------------------------------------------
-- Elite/Rare Indicator Pixels Dragon art per classification (+ player targets).
UF.ELITE_DRAGON_ART = {
	worldboss = UF.MEDIA .. "portraits\\pixels_dragon_boss", elite = UF.MEDIA .. "portraits\\pixels_dragon_elite",
	rareelite = UF.MEDIA .. "portraits\\pixels_dragon_rare", rare = UF.MEDIA .. "portraits\\pixels_dragon_rare",
	player = UF.MEDIA .. "portraits\\pixels_dragon_player",
}

-- Absorb Glow Line art (retail ns.UF_GLOW_LINE_ART).
UF.GLOW_LINE_ART = {
	blizzard = { UF.MEDIA .. "icons\\cast_spark", "ADD", 16, 1.6 },
	pixelsGlow = { UF.MEDIA .. "shields\\pixels-glowline", "ADD", 16, 1 },
	pixelsOvershield = { UF.MEDIA .. "shields\\pixels-overshield-line", "BLEND", 2, 1 },
}

local function StyleTexture(tex, style, width, height)
	tex:SetTexture(UF.AbsorbTexture(style), UF.ABSORB_TILED[style] and true or nil)
	if UF.ABSORB_TILED[style] then
		tex:SetHorizTile(true)
		tex:SetVertTile(true)
		tex:SetTexCoord(0, max(0.01, width / 256), 0, max(0.01, height / 128))
	else
		tex:SetHorizTile(false)
		tex:SetVertTile(false)
		tex:SetTexCoord(0, 1, 0, 1)
	end
end

local function AbsorbValues(frame)
	local unit = frame.unit
	if Fake(frame) then
		local opt = UF.previewAbsorbs
		if opt then
			return 100, UF.PreviewData(frame).health * 100, 25, 10, 8, 6
		end
		return 100, UF.PreviewData(frame).health * 100, 0, 0, 0, 0
	end
	local maxHP = UnitHealthMax(unit)
	local cur = UnitHealth(unit)
	local absorb = UnitGetTotalAbsorbs and UnitGetTotalAbsorbs(unit) or 0
	local healAbsorb = UnitGetTotalHealAbsorbs and UnitGetTotalHealAbsorbs(unit) or 0
	local all = UnitGetIncomingHeals(unit) or 0
	local mine = UnitGetIncomingHeals(unit, "player") or 0
	return maxHP, cur, absorb or 0, healAbsorb or 0, mine, max(0, all - mine)
end

-- Places a texture along the health bar from x (pixels from the left) with width w.
local function Span(tex, bar, x, w)
	if w <= 0.5 then
		tex:Hide()
		return
	end
	tex:ClearAllPoints()
	tex:SetPoint("TOPLEFT", bar, "TOPLEFT", x, 0)
	tex:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x, 0)
	tex:SetWidth(w)
	tex:Show()
end

function UF.UpdateAbsorbs(frame)
	local s = frame.settings
	local bar = frame.Health
	local shieldStyle = s.showPlayerAbsorb or "none"
	local healAbsorbStyle = s.healAbsorbStyle or "clean"
	local hasHealAbsorbApi = UnitGetTotalHealAbsorbs ~= nil
	local healPred = s.healPrediction
	local supported = frame.isMain or (frame.isBoss and UF.db.boss.showAbsorbs ~= false)
	if frame.isBoss then
		local t = UF.db.target
		shieldStyle = t.showPlayerAbsorb or "none"
		healPred = false
		s = setmetatable({}, { __index = function(_, k) return t[k] end })
	end
	for _, key in ipairs({ "HealPredMine", "HealPredOther", "Shield", "OverShield", "HealAbsorb", "HealAbsorbBg", "GlowLine" }) do
		frame[key]:Hide()
	end
	frame.AbsorbStrip:Hide()
	frame.HealAbsorbStrip:Hide()
	if not supported or frame.settings.healthVerticalFill then
		return
	end
	local maxHP, cur, absorb, healAbsorb, mine, other = AbsorbValues(frame)
	if not maxHP or maxHP <= 0 then
		return
	end
	local W = bar:GetWidth()
	local H = bar:GetHeight()
	if W <= 0 then
		return
	end
	local reverse = frame.settings.healthReverseFill
	local healthW = W * min(1, cur / maxHP)
	-- x position of a span that starts at "from" (from the fill origin) with width w.
	local function X(from, w)
		if reverse then
			return W - from - w
		end
		return from
	end

	-- Heal prediction: mine, then others, past the health edge.
	if healPred and (mine + other) > 0 then
		local limit = W * (1 + (s.healPredOverheal or 0) / 100)
		local a = (s.healPredOpacity or 60) / 100
		local texKey = s.healPredTexture or "health"
		local path = texKey == "flat" and UF.WHITE or (texKey == "health" and frame.barTexture or UF.BarTexturePath(texKey))
		local mw = min(W * mine / maxHP, max(0, limit - healthW))
		local c = s.healPredColor or { r = 102 / 255, g = 243 / 255, b = 102 / 255 }
		frame.HealPredMine:SetTexture(path)
		frame.HealPredMine:SetVertexColor(c.r, c.g, c.b, a)
		Span(frame.HealPredMine, bar, X(healthW, mw), mw)
		local ow = min(W * other / maxHP, max(0, limit - healthW - mw))
		local oc = s.healPredOtherColor or { r = 40 / 255, g = 170 / 255, b = 40 / 255 }
		frame.HealPredOther:SetTexture(path)
		frame.HealPredOther:SetVertexColor(oc.r, oc.g, oc.b, a)
		Span(frame.HealPredOther, bar, X(healthW + mw, ow), ow)
	end

	-- Shield absorb
	if shieldStyle ~= "none" and absorb > 0 then
		local aw = W * absorb / maxHP
		local opacity = s.absorbOpacity or (shieldStyle == "clean" and (s.absorbCleanAlpha or 30) or 80)
		local c = s.absorbColor or { r = 1, g = 1, b = 1 }
		local mode = s.absorbEdgeMode or "overlay"
		local missingW = W - healthW
		local fwd, over
		if mode == "right" then
			fwd = min(aw, W)
			Span(frame.Shield, bar, reverse and 0 or (W - fwd), fwd)
		elseif mode == "left" then
			fwd = min(aw, W)
			Span(frame.Shield, bar, reverse and (W - fwd) or 0, fwd)
		else
			fwd = min(aw, missingW)
			over = aw - fwd
			Span(frame.Shield, bar, X(healthW, fwd), fwd)
			local overMode = s.overshieldMode or (s.showOvershield == false and "never" or "always")
			if over > 0.5 and overMode ~= "never" then
				over = min(over, healthW)
				if overMode == "fromleft" then
					Span(frame.OverShield, bar, X(0, over), over)
				else
					Span(frame.OverShield, bar, X(healthW - over, over), over)
				end
				if s.absorbGlowLine then
					-- Glow Line Texture (retail absorbGlowLineTexture): { file, blend, width, height factor }.
					local art = UF.GLOW_LINE_ART[s.absorbGlowLineTexture] or UF.GLOW_LINE_ART.blizzard
					frame.GlowLine:SetTexture(art[1])
					frame.GlowLine:SetBlendMode(art[2])
					frame.GlowLine:ClearAllPoints()
					frame.GlowLine:SetSize(art[3], H * art[4])
					frame.GlowLine:SetPoint("CENTER", bar, reverse and "RIGHT" or "LEFT", reverse and -(W - over) or (W - over), 0)
					frame.GlowLine:Show()
				end
			end
		end
		for _, tex in ipairs({ frame.Shield, frame.OverShield }) do
			if tex:IsShown() then
				StyleTexture(tex, shieldStyle, tex:GetWidth(), H)
				tex:SetVertexColor(c.r, c.g, c.b, opacity / 100)
			end
		end
	end

	-- Heal absorb: from the health edge back over current health.
	if hasHealAbsorbApi and healAbsorbStyle ~= "none" and healAbsorb > 0 then
		local hw = min(healthW, W * healAbsorb / maxHP)
		local mode = s.healAbsorbEdgeMode or "overlay"
		local x
		if mode == "left" then
			x = reverse and (W - hw) or 0
		elseif mode == "right" then
			x = reverse and 0 or (W - hw)
		else
			x = X(healthW - hw, hw)
		end
		Span(frame.HealAbsorb, bar, x, hw)
		Span(frame.HealAbsorbBg, bar, x, hw)
		StyleTexture(frame.HealAbsorb, healAbsorbStyle, hw, H)
		local c = s.healAbsorbColor or { r = 0.8, g = 0.15, b = 0.15 }
		if UF.ABSORB_PRECOLORED[healAbsorbStyle] then
			frame.HealAbsorb:SetVertexColor(1, 1, 1, (s.healAbsorbOpacity or 65) / 100)
		else
			frame.HealAbsorb:SetVertexColor(c.r, c.g, c.b, (s.healAbsorbOpacity or 65) / 100)
		end
		frame.HealAbsorbBg:SetTexture(UF.WHITE)
		frame.HealAbsorbBg:SetVertexColor(0, 0, 0, (s.healAbsorbBgOpacity or 15) / 100)
	end

	-- Thin strips over the frame
	local function Strip(tex, position, height, color, value, belowOf)
		if position == "none" or value <= 0 then
			return
		end
		local w = max(1, W * min(1, value / maxHP))
		tex:ClearAllPoints()
		tex:SetSize(w, height)
		if position == "aboveAbsorb" or position == "belowAbsorb" then
			local ref = frame.AbsorbStrip
			if not ref:IsShown() then
				position = "topLeft"
			else
				tex:SetPoint(position == "aboveAbsorb" and "BOTTOMLEFT" or "TOPLEFT", ref,
					position == "aboveAbsorb" and "TOPLEFT" or "BOTTOMLEFT", 0, 0)
			end
		end
		if position == "aboveRight" then
			tex:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 1)
		elseif position == "aboveLeft" then
			tex:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 1)
		elseif position == "topRight" then
			tex:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
		elseif position == "topLeft" then
			tex:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
		elseif position == "bottomRight" then
			tex:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
		elseif position == "bottomLeft" then
			tex:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
		end
		tex:SetVertexColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)
		tex:Show()
	end
	if frame.isMain then
		Strip(frame.AbsorbStrip, s.absorbBarPosition or "none", s.absorbBarHeight or 4, s.absorbBarColor or {}, absorb)
		if hasHealAbsorbApi then
			Strip(frame.HealAbsorbStrip, s.healAbsorbBarPosition or "none", s.healAbsorbBarHeight or 4,
				s.healAbsorbBarColor or { r = 200 / 255, g = 29 / 255, b = 29 / 255 }, healAbsorb)
		end
	end
end

---------------------------------------------------------------------------
-- Indicators
---------------------------------------------------------------------------
local COMBAT_TEXTURES = {
	standard = "combat-indicator-custom", class = "combat-indicator-class-custom",
	combat0 = "combat0", combat1 = "combat1", combat2 = "combat2", combat3 = "combat3", combat4 = "combat4", combat5 = "combat5",
}

local FACTION_FILES = {
	classic = { "Interface\\TargetingFrame\\UI-PVP-%s", 0, 0.65625, 0, 0.65625 },
	banner = { "Interface\\Icons\\INV_BannerPVP_0%s" },
	honoricon = { "Interface\\Icons\\PVPCurrency-Honor-%s" },
	friends = { "Interface\\FriendsFrame\\PlusManz-%s" },
}

function UF.UpdateIndicators(frame)
	local s = frame.settings
	local unit = frame.unit
	local fake = Fake(frame)
	local preview = frame.preview and UF.previewIndicators

	-- Raid marker
	local index = (not fake) and GetRaidTargetIndex(unit) or nil
	if preview and not index then
		index = 8
	end
	if s.raidMarkerEnabled and index then
		SetRaidTargetIconTexture(frame.RaidIcon, index)
		frame.RaidIcon:Show()
	else
		frame.RaidIcon:Hide()
	end

	-- Leader / assist (player, target)
	local leader = frame.Leader
	leader:Hide()
	if (frame.unitKey == "player" or frame.unitKey == "target") and s.leaderIndicatorEnabled ~= false then
		local isLeader, isAssist
		if fake then
			isLeader = preview
		else
			isLeader = (UnitInParty(unit) or UnitInRaid(unit)) and UnitIsGroupLeader(unit)
			isAssist = not isLeader and UnitInRaid(unit) and UnitIsGroupAssistant(unit)
		end
		if isLeader or isAssist then
			if (s.leaderIndicatorStyle or "blizzard") == "pixels" then
				leader:SetTexture(UF.MEDIA .. "icons\\" .. (isLeader and "pixels-leader" or "pixels-assist"))
			else
				leader:SetTexture(isLeader and "Interface\\GroupFrame\\UI-Group-LeaderIcon" or "Interface\\GroupFrame\\UI-Group-AssistantIcon")
			end
			leader:Show()
		end
	end

	-- Combat indicator (player, target)
	local combat = frame.Combat
	local style = s.combatIndicatorStyle or "none"
	combat:Hide()
	if (frame.unitKey == "player" or frame.unitKey == "target") and style ~= "none" and COMBAT_TEXTURES[style] then
		local inCombat = fake and preview or (not fake and UnitAffectingCombat(unit))
		if inCombat then
			combat:SetTexture(UF.MEDIA .. "combat\\" .. COMBAT_TEXTURES[style])
			if style == "class" then
				local class = select(2, UnitClass(fake and "player" or unit))
				local coords = class and UF.CLASS_SPRITE[class] or UF.CLASS_SPRITE.WARRIOR
				combat:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
			else
				combat:SetTexCoord(0, 1, 0, 1)
			end
			if style:match("^combat%d$") then
				combat:SetVertexColor(1, 1, 1, 1)
			elseif s.combatIndicatorColor == "classcolor" then
				combat:SetVertexColor(UF.PlayerClassColor())
			else
				local c = s.combatIndicatorCustomColor or {}
				combat:SetVertexColor(c.r or 1, c.g or 1, c.b or 1, 1)
			end
			combat:Show()
		end
	end

	-- Elite / rare badge (target)
	local elite = frame.Elite
	elite:Hide()
	local dragon = frame.eliteDragon
	if dragon then
		dragon:Hide()
	end
	if frame.unitKey == "target" and s.eliteIndicatorEnabled then
		local class = fake and (preview and "elite") or (not fake and UnitClassification(unit))
		local inInstance = IsInInstance()
		local portrait = frame.Portrait
		if s.eliteIndicatorStyle == "pixelsDragon" and portrait and portrait:IsShown() then
			-- Pixels Dragon (retail ns.UF_ELITE_DRAGON_ART): classification art
			-- wrapped round the portrait (art circle 120 of 512 texels); players too.
			local key = (not fake and UnitIsPlayer(unit)) and "player" or class
			local art = UF.ELITE_DRAGON_ART[key or ""]
			if art and (key == "player" or not inInstance or s.eliteIndicatorShowInInstances) then
				if not dragon then
					local holder = CreateFrame("Frame", nil, portrait)
					holder:SetAllPoints(portrait)
					dragon = holder:CreateTexture(nil, "OVERLAY")
					dragon:SetPoint("CENTER", portrait, "CENTER", 0, 0)
					frame.eliteDragon = dragon
				end
				dragon:GetParent():SetFrameLevel(portrait:GetFrameLevel() + 2)
				local d = portrait:GetHeight() * 512 / 120
				dragon:SetSize(d, d)
				dragon:SetTexture(art)
				dragon:Show()
			end
		elseif class and class ~= "normal" and class ~= "minus" and class ~= "trivial" and (not inInstance or s.eliteIndicatorShowInInstances) then
			elite:SetDesaturated(class == "rare")
			elite:SetVertexColor(1, 1, 1, 1)
			elite:Show()
		end
	end

	-- Faction (player, target)
	local faction = frame.Faction
	faction:Hide()
	local mode = s.factionIndicatorMode or "off"
	if (frame.unitKey == "player" or frame.unitKey == "target") and mode ~= "off" then
		local u = fake and "player" or unit
		local group = UnitFactionGroup(u)
		local show = group == "Horde" or group == "Alliance"
		if show and mode == "opposite" and frame.unitKey == "target" then
			show = group ~= UnitFactionGroup("player")
		end
		if show and s.factionIndicatorPlayersOnly and not UnitIsPlayer(u) then
			show = false
		end
		local pvp = s.factionIndicatorPvP or "dim"
		local flagged = UnitIsPVP(u) or UnitIsPVPFreeForAll(u)
		if show and pvp == "only" and not flagged then
			show = false
		end
		if show then
			local art = FACTION_FILES[s.factionIndicatorStyle or "classic"] or FACTION_FILES.classic
			local name = group
			if art == FACTION_FILES.banner then
				name = group == "Horde" and "1" or "2"
			end
			faction:SetTexture(format(art[1], name))
			if art[2] then
				faction:SetTexCoord(art[2], art[3], art[4], art[5])
			else
				faction:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			end
			faction:SetAlpha((pvp == "dim" and not flagged) and 0.4 or 1)
			faction:Show()
		end
	end
end

-- Player threat glow (non-tank, in instances) and threat % text.
function UF.UpdateThreat(frame)
	local db = UF.db
	if frame.unitKey == "player" then
		local show = false
		if db.playerThreatBorderEnabled and IsInInstance() and IsInGroup() then
			local spec = GetSpecialization()
			local role = spec and GetSpecializationRole(spec)
			if role ~= "TANK" then
				local status = UnitThreatSituation("player")
				if status and status >= 2 then
					local c = db.playerThreatHasAggroColor
					frame.ThreatBorder:SetBorderColor(c.r, c.g, c.b, 0.9)
					show = true
				elseif status == 1 then
					local c = db.playerThreatNearAggroColor
					frame.ThreatBorder:SetBorderColor(c.r, c.g, c.b, 0.9)
					show = true
				end
			end
		end
		frame.ThreatBorder:SetShown(show)
	end
	local fs = frame.ThreatPct
	if frame.unitKey == "target" or frame.unitKey == "focus" then
		local enabled = db.threatPctEnabled and (frame.unitKey == "target" or db.threatPctFocus)
		local unit = frame.unit
		if enabled and UnitExists(unit) and UnitAffectingCombat("player") and UnitCanAttack("player", unit) then
			local _, status, pct = UnitDetailedThreatSituation("player", unit)
			if pct then
				fs:SetText(format("%d%%", floor(pct + 0.5)))
				if db.threatPctColorByThreat ~= false and status then
					fs:SetTextColor(GetThreatStatusColor(status))
				else
					fs:SetTextColor(1, 1, 1)
				end
				fs:Show()
				return
			end
		end
		fs:Hide()
	end
end

-- Player dispel overlay: tint by the first debuff type you can see (or dispel).
local DISPEL_BY_CLASS = {
	PRIEST = { Magic = true, Disease = true }, PALADIN = { Magic = true, Poison = true, Disease = true },
	DRUID = { Magic = true, Curse = true, Poison = true }, SHAMAN = { Magic = true, Curse = true },
	MONK = { Magic = true, Poison = true, Disease = true }, MAGE = { Curse = true },
}
UF.DISPEL_BY_CLASS = DISPEL_BY_CLASS

function UF.UpdateDispelOverlay(frame)
	local db = UF.db
	local tex = frame.DispelOverlay
	local mode = db.dispelOverlay or "none"
	if frame.unitKey ~= "player" or mode == "none" then
		tex:Hide()
		return
	end
	local found
	if Fake(frame) or (frame.preview and UF.previewDispel) then
		found = "Magic"
	else
		local mine = DISPEL_BY_CLASS[select(2, UnitClass("player"))] or {}
		for i = 1, 40 do
			local name, _, _, _, dtype = UnitAura("player", i, "HARMFUL")
			if not name then
				break
			end
			if dtype and UF.DISPEL_KEYS[dtype] and (not db.dispelOverlayByMe or mine[dtype]) then
				found = dtype
				break
			end
		end
	end
	if not found then
		tex:Hide()
		return
	end
	local c = db[UF.DISPEL_KEYS[found]]
	local a = (db.dispelOverlayOpacity or 100) / 100
	tex:ClearAllPoints()
	if mode == "fill" then
		tex:SetAllPoints(frame.Health:GetStatusBarTexture())
		tex:SetGradientAlpha("HORIZONTAL", c.r, c.g, c.b, 0.5 * a, c.r, c.g, c.b, 0.5 * a)
	elseif mode == "full" then
		tex:SetAllPoints(frame.Health)
		tex:SetGradientAlpha("HORIZONTAL", c.r, c.g, c.b, 0.5 * a, c.r, c.g, c.b, 0.5 * a)
	elseif mode == "gradient_sharp" then
		tex:SetAllPoints(frame.Health)
		tex:SetGradientAlpha("VERTICAL", c.r, c.g, c.b, 0, c.r, c.g, c.b, 0.9 * a)
	else
		tex:SetAllPoints(frame.Health)
		tex:SetGradientAlpha("VERTICAL", c.r, c.g, c.b, 0, c.r, c.g, c.b, 0.6 * a)
	end
	tex:SetVertexColor(1, 1, 1, 1)
	tex:Show()
end

---------------------------------------------------------------------------
-- Visibility (EllesmereUI checklist) and alpha
---------------------------------------------------------------------------
local CONDITIONS = {
	in_combat = function() return UnitAffectingCombat("player") end,
	out_of_combat = function() return not UnitAffectingCombat("player") end,
	in_raid = function() return IsInRaid() end,
	in_party = function() return IsInGroup() and not IsInRaid() end,
	solo = function() return not IsInGroup() end,
	instances = function() local inside = IsInInstance() return inside and true or false end,
	mounted = function() return IsMounted() end,
	target = function() return UnitExists("target") end,
	enemy = function() return UnitExists("target") and UnitCanAttack("player", "target") end,
	resting = function() return IsResting() end,
	vehicle = function() return UnitHasVehicleUI("player") end,
}
UF.VIS_CONDITIONS = CONDITIONS
-- Axis -> keys of the Show lane and Hide lane.
UF.VIS_AXES = {
	{ key = "in_combat", label = "In Combat", show = "in_combat", hide = "hide_in_combat" },
	{ key = "out_of_combat", label = "Out of Combat", show = "out_of_combat", hide = "hide_out_of_combat" },
	{ key = "in_raid", label = "In Raid Group", show = "in_raid", hide = "hide_in_raid" },
	{ key = "in_party", label = "In Party", show = "in_party", hide = "hide_in_party" },
	{ key = "solo", label = "Solo", show = "solo", hide = "hide_solo" },
	{ key = "instances", label = "Instances", show = "visOnlyInstances", hide = "visHideInstances" },
	{ key = "mounted", label = "Mounted", show = "visOnlyMounted", hide = "visHideMounted" },
	{ key = "target", label = "Target", show = "visHideNoTarget", hide = "visHideWithTarget" },
	{ key = "enemy", label = "Enemy Target", show = "visHideNoEnemy", hide = "visHideWithEnemy" },
	{ key = "resting", label = "Resting", show = "visOnlyResting", hide = "visHideResting" },
	{ key = "vehicle", label = "In Vehicle", show = "visOnlyVehicle", hide = "visHideVehicle" },
}

-- Reads one lane flag: group/combat axes live in visibilityModes, the
-- others are plain booleans (EllesmereUI keys).
function UF.VisFlag(s, key)
	if key:match("^vis") then
		return s[key] and true or false
	end
	local modes = s.visibilityModes
	if modes and modes[key] then
		return true
	end
	-- Legacy group booleans: showInRaid = false means "hide in raid".
	if key == "hide_in_raid" then
		return s.showInRaid == false
	elseif key == "hide_in_party" then
		return s.showInParty == false
	elseif key == "hide_solo" then
		return s.showSolo == false
	end
	return false
end

function UF.SetVisFlag(s, key, on)
	if key:match("^vis") then
		s[key] = on and true or nil
		return
	end
	s.visibilityModes = s.visibilityModes or {}
	s.visibilityModes[key] = on and true or nil
	if key == "hide_in_raid" then
		s.showInRaid = not on
	elseif key == "hide_in_party" then
		s.showInParty = not on
	elseif key == "hide_solo" then
		s.showSolo = not on
	end
end

-- True when the visibility checklist allows the frame now.
function UF.VisibilityAllows(s)
	local vis = s.barVisibility or "always"
	if vis == "never" then
		return false
	end
	local anyShow, allShow, showCount = false, true, 0
	for _, axis in ipairs(UF.VIS_AXES) do
		local test = CONDITIONS[axis.key]
		if UF.VisFlag(s, axis.hide) and test() then
			return false
		end
		if UF.VisFlag(s, axis.show) then
			showCount = showCount + 1
			if test() then
				anyShow = true
			else
				allShow = false
			end
		end
	end
	if showCount == 0 then
		return true
	end
	if s.visibilityMatch == "any" then
		return anyShow
	end
	return allShow
end

function UF.UpdateAlpha(frame)
	local s = frame.settings
	if not s then
		return
	end
	local alpha = 1
	if frame.preview or frame.unlocked then
		frame:SetAlpha(1)
		return
	end
	local allowed = UF.VisibilityAllows(s)
	if (s.barVisibility or "always") == "mouseover" then
		allowed = allowed and (frame.hovered or frame:IsMouseOver())
	end
	if not allowed and s.showWhenHealthMissing and UnitExists(frame.unit)
		and UnitHealth(frame.unit) < UnitHealthMax(frame.unit) then
		allowed = true
	end
	if frame.unitKey == "pet" and UF.db.pet.alwaysShow then
		allowed = true
	end
	if not allowed then
		alpha = 0
	elseif s.oocFadeEnabled and not UnitAffectingCombat("player") then
		alpha = s.oocAlpha or 0.5
	end
	if alpha > 0 and frame.isBoss and frame.outOfRange then
		alpha = alpha * (s.oorAlpha or 0.4)
	end
	frame:SetAlpha(alpha)
end

-- Boss range: a class spell in range (5.4.8 IsSpellInRange takes names).
local RANGE_SPELLS = {
	DEATHKNIGHT = 49576, DRUID = 5176, HUNTER = 75, MAGE = 44614, MONK = 115546, PALADIN = 20271,
	PRIEST = 589, ROGUE = 2094, SHAMAN = 403, WARLOCK = 686, WARRIOR = 355,
}
function UF.UpdateRange(frame)
	if not frame.isBoss then
		return
	end
	local unit = frame.unit
	local out = false
	if UnitExists(unit) and not frame.preview then
		local id = RANGE_SPELLS[select(2, UnitClass("player"))]
		local name = id and GetSpellInfo(id)
		local inRange = name and IsSpellInRange(name, unit)
		if inRange == 0 then
			out = true
		elseif inRange == nil then
			out = not CheckInteractDistance(unit, 4)
		end
	end
	if frame.outOfRange ~= out then
		frame.outOfRange = out
		UF.UpdateAlpha(frame)
	end
end

---------------------------------------------------------------------------
-- Everything
---------------------------------------------------------------------------
function UF.UpdateAll(frame)
	frame.settings = UF.Settings(frame.settingsKey)
	if not frame.settings then
		return
	end
	UF.UpdateHealth(frame)
	UF.UpdatePower(frame)
	UF.UpdateTexts(frame)
	UF.UpdatePortrait(frame)
	UF.UpdatePortraitBorder(frame)
	UF.UpdateAbsorbs(frame)
	UF.UpdateIndicators(frame)
	UF.UpdateThreat(frame)
	UF.UpdateDispelOverlay(frame)
	UF.UpdateBorderColor(frame)
	if frame.Castbar then
		UF.CastUpdate(frame)
	end
	if frame.Buffs then
		UF.UpdateAuras(frame)
	end
	if frame.ClassPower then
		UF.UpdateClassPower(frame)
	end
	UF.UpdateAlpha(frame)
end
