-- EllesmereUI Unit Frames for 5.4.8: class resource on the player frame.
-- "Modern" = flat pips (EllesmereUI look) for the MoP resources; "Blizzard"
-- = the stock MoP class bar moved under the player frame.

local addonName = ...
local ns = EllesmereUI
local UF = ns.UF

local floor, min, max = math.floor, math.min, math.max
local GetTime = GetTime

local SPEC = function() return GetSpecialization and GetSpecialization() end

-- Resource of the player right now: kind, max, bar mode, color token.
-- kind: "combo", "power" (UnitPower type), "runes", "aura" (stacks), "embers", "eclipse", "fury"
local function Resource()
	local class = select(2, UnitClass("player"))
	local spec = SPEC()
	if class == "ROGUE" then
		return { kind = "combo", max = 5, token = "ComboPoints" }
	elseif class == "DRUID" then
		local form = GetShapeshiftFormID()
		if form == CAT_FORM then
			return { kind = "combo", max = 5, token = "ComboPoints" }
		end
		if spec == 1 and (form == nil or form == MOONKIN_FORM) then
			return { kind = "eclipse", bar = true }
		end
	elseif class == "PALADIN" then
		return { kind = "power", type = SPELL_POWER_HOLY_POWER, token = "HOLY_POWER" }
	elseif class == "MONK" then
		return { kind = "power", type = SPELL_POWER_CHI, token = "CHI" }
	elseif class == "PRIEST" then
		if spec == 3 then
			return { kind = "power", type = SPELL_POWER_SHADOW_ORBS, token = "SHADOW_ORBS" }
		end
	elseif class == "WARLOCK" then
		if spec == 1 then
			return { kind = "power", type = SPELL_POWER_SOUL_SHARDS, token = "SOUL_SHARDS" }
		elseif spec == 2 then
			return { kind = "fury", bar = true, token = "DEMONIC_FURY" }
		elseif spec == 3 then
			return { kind = "embers", token = "BURNING_EMBERS" }
		end
	elseif class == "DEATHKNIGHT" then
		return { kind = "runes", max = 6 }
	elseif class == "MAGE" then
		if spec == 1 then
			return { kind = "aura", spell = 36032, max = 4, harmful = true }
		end
	elseif class == "SHAMAN" then
		if spec == 2 then
			return { kind = "aura", spell = 53817, max = 5 }
		end
	end
	return nil
end

local function ResourceMax(res)
	if res.max then
		return res.max
	end
	if res.kind == "power" then
		local m = UnitPowerMax("player", res.type)
		return (m and m > 0) and m or 3
	elseif res.kind == "embers" then
		local m = UnitPowerMax("player", SPELL_POWER_BURNING_EMBERS, true)
		return max(1, floor((m or 40) / (MAX_POWER_PER_EMBER or 10)))
	end
	return 5
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
function UF.CreateClassPower(frame)
	local cp = CreateFrame("Frame", nil, frame)
	cp:SetFrameLevel(frame:GetFrameLevel() + 12)
	cp.bg = UF.Solid(cp, "BACKGROUND", 0.082, 0.082, 0.082, 1)
	cp.bg:SetAllPoints()
	cp.pips = {}
	cp.line = UF.Solid(cp, "OVERLAY", 0, 0, 0, 1)
	cp.line:Hide()
	cp:Hide()
	frame.ClassPower = cp
end

local function GetPip(cp, i)
	local pip = cp.pips[i]
	if not pip then
		pip = CreateFrame("StatusBar", nil, cp)
		pip:SetStatusBarTexture(UF.WHITE)
		pip:SetMinMaxValues(0, 1)
		pip.bg = UF.Solid(pip, "BACKGROUND", 0.2, 0.2, 0.2, 1)
		pip.bg:SetAllPoints()
		cp.pips[i] = pip
	end
	return pip
end

-- Blizzard class bars of MoP (children of PlayerFrame, which is hidden).
local BLIZZ_BARS = {
	PALADIN = "PaladinPowerBar", MONK = "MonkHarmonyBar", PRIEST = "PriestBarFrame",
	WARLOCK = "WarlockPowerFrame", DRUID = "EclipseBarFrame", DEATHKNIGHT = "RuneFrame",
}

local function ApplyBlizzardBar(frame, on)
	local name = BLIZZ_BARS[select(2, UnitClass("player"))]
	local bar = name and _G[name]
	-- The settings header preview must not take the bar from the real frame.
	if not bar or InCombatLockdown() or frame.headerPreview then
		return
	end
	if on then
		bar:SetParent(frame)
		bar:ClearAllPoints()
		bar:SetPoint("TOP", frame, "BOTTOM", 0, -2)
		bar:SetFrameLevel(frame:GetFrameLevel() + 5)
		frame.blizzBar = bar
	elseif frame.blizzBar then
		bar:SetParent(UF.hiddenParent)
		frame.blizzBar = nil
	end
end

function UF.LayoutClassPower(frame)
	local cp = frame.ClassPower
	local s = UF.db.player
	local style = s.classPowerStyle or "none"
	ApplyBlizzardBar(frame, style == "blizzard")
	local res = style == "modern" and Resource() or nil
	cp.res = res
	cp.active = res ~= nil
	if not res then
		cp:Hide()
		return
	end
	local px = UF.Pixel()
	local size = s.classPowerSize or 8
	local pipW = size
	local pipH = max(3, floor(size * 0.375))
	local gap = (s.classPowerSpacing or 2) * px
	local count = res.bar and 1 or ResourceMax(res)
	local drawCount = res.bar and 5 or count
	local totalW = drawCount * pipW + (drawCount - 1) * gap
	cp.pipHeight = pipH
	cp.count = count
	local position = s.classPowerPosition or "top"
	local free = position ~= "above" and s.lockClassPowerToFrame == false
	if not free then
		cp._eufFree = nil
		cp:ClearAllPoints()
	end
	cp.line:Hide()
	if position == "above" then
		-- Stretched across the health bar, inside the frame (the frame grows).
		totalW = s.frameWidth or 181
		cp:SetPoint("BOTTOMLEFT", frame.bars, "TOPLEFT", 0, 0)
		cp:SetSize(totalW, pipH)
		cp.line:ClearAllPoints()
		cp.line:SetPoint("BOTTOMLEFT", cp, "BOTTOMLEFT")
		cp.line:SetPoint("BOTTOMRIGHT", cp, "BOTTOMRIGHT")
		cp.line:SetHeight(px)
		local c = s.borderColor or {}
		cp.line:SetVertexColor(c.r or 0, c.g or 0, c.b or 0, 1)
		cp.line:Show()
	elseif s.lockClassPowerToFrame == false then
		cp:SetSize(totalW, pipH)
		UF.PlaceFree(cp, "classPower")
		cp:SetSize(totalW, pipH)
	elseif position == "bottom" then
		local below = frame
		if frame.Castbar and frame.Castbar.enabled and s.lockCastbarToFrame ~= false then
			below = frame.Castbar
		end
		cp:SetPoint("TOP", below, "BOTTOM", s.classPowerBarX or 0, -1 + (s.classPowerBarY or 0))
		cp:SetSize(totalW, pipH)
	else
		cp:SetPoint("BOTTOM", frame.Health, "TOP", s.classPowerBarX or 0, 1 + (s.classPowerBarY or 0))
		cp:SetSize(totalW, pipH)
	end
	local bg = s.classPowerBgColor or {}
	cp.bg:SetVertexColor(bg.r or 0.082, bg.g or 0.082, bg.b or 0.082, bg.a or 1)
	local w = res.bar and totalW or (totalW - (count - 1) * gap) / count
	local empty = s.classPowerEmptyColor or {}
	for i = 1, max(count, #cp.pips) do
		local pip = GetPip(cp, i)
		if i <= count then
			pip:ClearAllPoints()
			pip:SetSize(w, pipH)
			pip:SetPoint("LEFT", cp, "LEFT", (i - 1) * (w + gap), 0)
			pip.bg:SetVertexColor(empty.r or 0.2, empty.g or 0.2, empty.b or 0.2, empty.a or 1)
			pip:Show()
		else
			pip:Hide()
		end
	end
	cp:Show()
end

---------------------------------------------------------------------------
-- Update
---------------------------------------------------------------------------
local RUNE_ORDER = { 1, 2, 5, 6, 3, 4 }

local function FillColor(res)
	local s = UF.db.player
	if s.classPowerClassColor == false then
		local c = s.classPowerCustomColor or {}
		return c.r or 1, c.g or 0.82, c.b or 0
	end
	local class = select(2, UnitClass("player"))
	if res.token == "ComboPoints" then
		return 1, 0.9608, 0.4118
	end
	local c = UF.RESOURCE_CLASS_COLORS[class]
	if c then
		return c[1], c[2], c[3]
	end
	return 1, 0.82, 0
end

local function RuneOnUpdate(cp)
	local now = GetTime()
	local busy = false
	for i = 1, 6 do
		local start, duration, ready = GetRuneCooldown(RUNE_ORDER[i])
		local pip = cp.pips[i]
		if pip then
			if ready or not start or duration == 0 then
				pip:SetValue(1)
				pip:SetAlpha(1)
			else
				pip:SetValue(min(1, (now - start) / duration))
				pip:SetAlpha(0.6)
				busy = true
			end
		end
	end
	return busy
end

local function OnUpdate(cp, elapsed)
	cp.t = (cp.t or 0) + elapsed
	if cp.t < 0.05 then
		return
	end
	cp.t = 0
	if not RuneOnUpdate(cp) then
		cp:SetScript("OnUpdate", nil)
	end
end

function UF.UpdateClassPower(frame)
	local cp = frame.ClassPower
	if not cp or not cp.active then
		return
	end
	local res = cp.res
	local r, g, b = FillColor(res)
	local fake = UnitHasVehicleUI("player")
	if fake then
		cp:Hide()
		return
	end
	cp:Show()
	if res.kind == "runes" then
		for i = 1, 6 do
			local pip = cp.pips[i]
			local rtype = GetRuneType(RUNE_ORDER[i])
			local c = UF.db.player.classPowerClassColor ~= false and UF.RUNE_COLORS[rtype or 1] or nil
			if c then
				pip:GetStatusBarTexture():SetVertexColor(c[1], c[2], c[3], 1)
			else
				pip:GetStatusBarTexture():SetVertexColor(r, g, b, 1)
			end
		end
		if RuneOnUpdate(cp) then
			cp:SetScript("OnUpdate", OnUpdate)
		end
		return
	end
	if res.bar then
		local pip = cp.pips[1]
		local value, maxValue = 0, 1
		if res.kind == "eclipse" then
			maxValue = UnitPowerMax("player", SPELL_POWER_ECLIPSE) or 100
			value = (UnitPower("player", SPELL_POWER_ECLIPSE) + maxValue) / 2
			local dir = GetEclipseDirection and GetEclipseDirection()
			if dir == "sun" then
				r, g, b = 0.95, 0.75, 0.25
			elseif dir == "moon" then
				r, g, b = 0.3, 0.52, 0.9
			end
		else
			value = UnitPower("player", SPELL_POWER_DEMONIC_FURY)
			maxValue = UnitPowerMax("player", SPELL_POWER_DEMONIC_FURY)
		end
		pip:SetMinMaxValues(0, max(1, maxValue))
		pip:SetValue(value)
		pip:GetStatusBarTexture():SetVertexColor(r, g, b, 1)
		return
	end
	local cur = 0
	if res.kind == "combo" then
		cur = GetComboPoints(UnitHasVehicleUI("player") and "vehicle" or "player", "target") or 0
	elseif res.kind == "power" then
		cur = UnitPower("player", res.type) or 0
	elseif res.kind == "aura" then
		local name = GetSpellInfo(res.spell)
		if name then
			local _, _, _, count = UnitAura("player", name, nil, res.harmful and "HARMFUL" or "HELPFUL")
			cur = count or 0
		end
	elseif res.kind == "embers" then
		cur = (UnitPower("player", SPELL_POWER_BURNING_EMBERS, true) or 0) / (MAX_POWER_PER_EMBER or 10)
	end
	if ResourceMax(res) ~= cp.count then
		UF.LayoutClassPower(frame)
		UF.ReflowFrame(frame)
	end
	for i = 1, cp.count do
		local pip = cp.pips[i]
		pip:SetMinMaxValues(0, 1)
		local fill = min(1, max(0, cur - (i - 1)))
		pip:SetValue(fill)
		pip:SetAlpha((fill > 0 and fill < 1) and 0.6 or 1)
		pip:GetStatusBarTexture():SetVertexColor(r, g, b, 1)
	end
end
