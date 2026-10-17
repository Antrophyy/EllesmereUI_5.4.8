-------------------------------------------------------------------------------
--  EUI_Nameplates_ClassPower.lua
--  Class resource on the target's nameplate (retail showClassPower:
--  classPowerPos top / bottom, X / Y offset, Size (classPowerScale), gap,
--  class or custom fill color, empty and background colors, square or
--  rectangle pips, optional border). Mists of Pandaria point resources:
--  combo points (rogue / cat), holy power, chi, shadow orbs, soul shards,
--  burning embers, arcane charges, Maelstrom Weapon. One pip row follows
--  whichever plate is the target.
-------------------------------------------------------------------------------
local addonName, P = ...
local ns, ENP = P.ns, P.ENP

local floor, max, min = math.floor, math.max, math.min

local CP = {}
ENP.ClassPower = CP

local CLASS_COLORS = {
	COMBO = { 1, 0.96, 0.41 }, HOLY_POWER = { 0.95, 0.9, 0.6 }, CHI = { 0.71, 1, 0.92 },
	SHADOW_ORBS = { 0.5, 0.32, 0.55 }, SOUL_SHARDS = { 0.58, 0.51, 0.79 }, BURNING_EMBERS = { 0.9, 0.39, 0.13 },
	ARCANE_CHARGES = { 0.41, 0.8, 0.94 }, MAELSTROM = { 0.2, 0.6, 1 },
}

local function Resource()
	local _, class = UnitClass("player")
	local spec = GetSpecialization()
	local form = GetShapeshiftFormID()
	if class == "ROGUE" or (class == "DRUID" and form == 1) then
		return "COMBO", GetComboPoints(UnitHasVehicleUI("player") and "vehicle" or "player", "target") or 0, MAX_COMBO_POINTS or 5
	elseif class == "PALADIN" then
		return "HOLY_POWER", UnitPower("player", SPELL_POWER_HOLY_POWER) or 0, max(3, UnitPowerMax("player", SPELL_POWER_HOLY_POWER) or 3)
	elseif class == "MONK" then
		return "CHI", UnitPower("player", SPELL_POWER_CHI) or 0, max(4, UnitPowerMax("player", SPELL_POWER_CHI) or 4)
	elseif class == "PRIEST" and spec == 3 then
		return "SHADOW_ORBS", UnitPower("player", SPELL_POWER_SHADOW_ORBS) or 0, max(3, UnitPowerMax("player", SPELL_POWER_SHADOW_ORBS) or 3)
	elseif class == "WARLOCK" and spec == 1 then
		return "SOUL_SHARDS", UnitPower("player", SPELL_POWER_SOUL_SHARDS) or 0, max(3, UnitPowerMax("player", SPELL_POWER_SOUL_SHARDS) or 3)
	elseif class == "WARLOCK" and spec == 3 then
		local per = MAX_POWER_PER_EMBER or 10
		return "BURNING_EMBERS", floor((UnitPower("player", SPELL_POWER_BURNING_EMBERS, true) or 0) / per),
			max(3, floor((UnitPowerMax("player", SPELL_POWER_BURNING_EMBERS, true) or 30) / per))
	elseif class == "MAGE" and spec == 1 then
		local name = GetSpellInfo(36032)
		local count = name and select(4, UnitAura("player", name, nil, "HARMFUL")) or 0
		return "ARCANE_CHARGES", count or 0, 4
	elseif class == "SHAMAN" and spec == 2 then
		local name = GetSpellInfo(53817)
		local count = name and select(4, UnitAura("player", name, nil, "HELPFUL")) or 0
		return "MAELSTROM", count or 0, 5
	end
end

local holder, pips = nil, {}

local function Pip(i)
	local t = pips[i]
	if t then return t end
	t = CreateFrame("Frame", nil, holder)
	t.bg = t:CreateTexture(nil, "BACKGROUND")
	t.bg:SetAllPoints()
	t.fill = t:CreateTexture(nil, "ARTWORK")
	t.edges = {}
	for e = 1, 4 do t.edges[e] = t:CreateTexture(nil, "OVERLAY") end
	pips[i] = t
	return t
end

local function TargetPlate()
	local guid = UnitGUID("target")
	local plate = guid and ENP.byGUID and ENP.byGUID[guid]
	if plate and plate:IsShown() and plate.isTarget then return plate end
	for p in pairs(ENP.visible or {}) do
		if p.isTarget then return p end
	end
end

function CP.Update()
	local p = P.Profile()
	if not p.showClassPower or not UnitExists("target") or not UnitCanAttack("player", "target") then
		if holder then holder:Hide() end
		return
	end
	local key, cur, mx = Resource()
	local plate = key and TargetPlate()
	if not plate or not plate.health then
		if holder then holder:Hide() end
		return
	end
	if not holder then
		holder = CreateFrame("Frame", nil, UIParent)
	end
	holder:SetParent(plate)
	holder:SetFrameLevel(plate.health:GetFrameLevel() + 6)
	local scale = p.classPowerScale or 1
	local square = p.classPowerShape == "square" or p.classPowerShape == "circle"
	local pw, ph = floor((square and 6 or 8) * scale + 0.5), floor((square and 6 or 3) * scale + 0.5)
	local gap = p.classPowerGap or 2
	local W = mx * pw + (mx - 1) * gap
	holder:SetSize(W, ph)
	holder:ClearAllPoints()
	local x, y = p.classPowerXOffset or 0, p.classPowerYOffset or 1
	if (p.classPowerPos or "bottom") == "top" then
		holder:SetPoint("BOTTOM", plate.health, "TOP", x, y)
	else
		holder:SetPoint("TOP", plate.health, "BOTTOM", x, -y)
	end
	local cr, cg, cb
	if p.classPowerClassColors ~= false then
		local c = CLASS_COLORS[key] or { 1, 1, 1 }
		cr, cg, cb = c[1], c[2], c[3]
	else
		local c = p.classPowerCustomColor or { r = 1, g = 0.84, b = 0.3 }
		cr, cg, cb = c.r, c.g, c.b
	end
	local empty = p.classPowerEmptyColor or { r = 0.2, g = 0.2, b = 0.2, a = 1 }
	local bgc = p.classPowerBgColor or { r = 0.082, g = 0.082, b = 0.082, a = 1 }
	local border = p.classPowerBorder == true
	local bs = p.classPowerBorderSize or 1
	local bc = p.classPowerBorderColor or { r = 0, g = 0, b = 0, a = 1 }
	for i = 1, mx do
		local t = Pip(i)
		t:SetSize(pw, ph)
		t:ClearAllPoints()
		t:SetPoint("LEFT", holder, "LEFT", (i - 1) * (pw + gap), 0)
		t.bg:SetTexture(bgc.r, bgc.g, bgc.b, bgc.a or 1)
		t.fill:ClearAllPoints()
		t.fill:SetAllPoints()
		if i <= cur then
			t.fill:SetTexture(cr, cg, cb, 1)
		else
			t.fill:SetTexture(empty.r, empty.g, empty.b, empty.a or 1)
		end
		local e = t.edges
		for k = 1, 4 do
			e[k]:SetTexture(bc.r, bc.g, bc.b, bc.a or 1)
			e[k]:ClearAllPoints()
			e[k]:SetShown(border)
		end
		if border then
			e[1]:SetPoint("TOPLEFT", -bs, bs); e[1]:SetPoint("TOPRIGHT", bs, bs); e[1]:SetHeight(bs)
			e[2]:SetPoint("BOTTOMLEFT", -bs, -bs); e[2]:SetPoint("BOTTOMRIGHT", bs, -bs); e[2]:SetHeight(bs)
			e[3]:SetPoint("TOPLEFT", -bs, 0); e[3]:SetPoint("BOTTOMLEFT", -bs, 0); e[3]:SetWidth(bs)
			e[4]:SetPoint("TOPRIGHT", bs, 0); e[4]:SetPoint("BOTTOMRIGHT", bs, 0); e[4]:SetWidth(bs)
		end
		t:Show()
	end
	for i = mx + 1, #pips do pips[i]:Hide() end
	holder:Show()
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function() if ENP.db then CP.Update() end end)
for _, e in ipairs({ "PLAYER_TARGET_CHANGED",
	"UPDATE_SHAPESHIFT_FORM", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_ENTERING_WORLD" }) do
	ev:RegisterEvent(e)
end
for _, e in ipairs({ "UNIT_COMBO_POINTS", "UNIT_POWER", "UNIT_AURA" }) do
	ev:RegisterUnitEvent(e, "player")
end
-- The target plate is found a moment after the target changes; a light tick
-- keeps the row on it.
local acc = 0
ev:SetScript("OnUpdate", function(_, elapsed)
	acc = acc + elapsed
	if acc < 0.2 then return end
	acc = 0
	if ENP.db then CP.Update() end
end)
