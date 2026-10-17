-- EllesmereUI Quality of Life for 5.4.8: the EXTRAS / CROSSHAIR parts of the
-- retail QoL page and the alerts of GENERAL (retail EllesmereUIQoL.lua):
-- FPS Counter, Secondary Stat Display, Low Durability Warning, Disable Right
-- Click, Rested Indicator, Target Distance Text, Character Crosshair, Combat
-- Alert, Announce Group Deaths, Hide Item Transforms.
-- Retail's animation groups use SetFromAlpha/SetToAlpha (not in 5.4.8), so
-- fades run on a small OnUpdate here.

local addonName = ...
local ns = EllesmereUI
local Q = ns.QoL
local R = Q.R

local floor, format, ipairs, pairs, type = math.floor, string.format, ipairs, pairs, type

-- All of these are 5.4.8 API (WoW_5.4.8_API.md); the fallbacks only keep
-- test harnesses without them from erroring every frame.
local function Zero() return 0 end
local GetNetStats = GetNetStats or function() return 0, 0, 0, 0 end
local GetCritChance, GetRangedCritChance, GetSpellCritChance = GetCritChance or Zero, GetRangedCritChance or Zero, GetSpellCritChance or Zero
local GetMeleeHaste, UnitSpellHaste, GetMasteryEffect = GetMeleeHaste or Zero, UnitSpellHaste or Zero, GetMasteryEffect or Zero
local GetCombatRating, GetCombatRatingBonus, GetExpertise = GetCombatRating or Zero, GetCombatRatingBonus or Zero, GetExpertise or Zero
local GetHitModifier, GetSpellHitModifier = GetHitModifier or Zero, GetSpellHitModifier or Zero
local MouselookStart, MouselookStop = MouselookStart or Zero, MouselookStop or Zero
local IsMouselooking = IsMouselooking or function() return false end

---------------------------------------------------------------------------
-- Shared helpers
---------------------------------------------------------------------------
-- Fade in, hold, fade out, then hide (retail alert animation group).
local function Flash(frame, fadeIn, hold, fadeOut)
	local t = 0
	frame:SetAlpha(0)
	frame:Show()
	frame:SetScript("OnUpdate", function(self, dt)
		t = t + dt
		if t < fadeIn then
			self:SetAlpha(t / fadeIn)
		elseif t < fadeIn + hold then
			self:SetAlpha(1)
		elseif t < fadeIn + hold + fadeOut then
			self:SetAlpha(1 - (t - fadeIn - hold) / fadeOut)
		else
			self:SetScript("OnUpdate", nil)
			self:Hide()
		end
	end)
end

-- Unlock Mode position helpers (positions are CENTER/CENTER on UIParent).
local function PlaceFrom(frame, pos, default)
	frame:ClearAllPoints()
	if type(pos) == "table" and pos.point then
		frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
	else
		frame:SetPoint(default.point, UIParent, default.relPoint, default.x, default.y)
	end
end

local function UnlockActive()
	return ns._unlockActive and true or false
end

local unlockElements = {}
local function AddUnlock(def)
	unlockElements[#unlockElements + 1] = def
end

---------------------------------------------------------------------------
-- Range (retail EllesmereUI_Range.lua): item range ladder like
-- LibRangeCheck. IsItemInRange works for items the client has cached.
---------------------------------------------------------------------------
local HARM_ITEMS = {
	{ 5, 37727 }, { 8, 34368 }, { 10, 32321 }, { 15, 33069 }, { 20, 10645 },
	{ 25, 24268 }, { 30, 835 }, { 35, 24269 }, { 40, 28767 }, { 45, 23836 },
	{ 60, 32825 }, { 80, 35278 },
}
local HELP_ITEMS = {
	{ 5, 37727 }, { 8, 34368 }, { 10, 32321 }, { 15, 1251 }, { 20, 21519 },
	{ 25, 31463 }, { 30, 1180 }, { 35, 18904 }, { 40, 34471 }, { 45, 32698 },
	{ 60, 32825 }, { 80, 35278 },
}
local rangePrimed = false
local function PrimeRangeItems()
	if rangePrimed then return end
	rangePrimed = true
	for _, list in ipairs({ HARM_ITEMS, HELP_ITEMS }) do
		for _, e in ipairs(list) do GetItemInfo(e[2]) end
	end
end

-- min, max yards of the unit (max nil = beyond the ladder).
function Q.RangeBracket(unit)
	if not UnitExists(unit) then return nil end
	if UnitIsUnit(unit, "player") then return 0, 5 end
	PrimeRangeItems()
	local list = UnitCanAttack("player", unit) and HARM_ITEMS or HELP_ITEMS
	local lower = 0
	for _, e in ipairs(list) do
		local r = IsItemInRange(e[2], unit)
		if r == 1 or r == true then
			return lower, e[1]
		elseif r == 0 or r == false then
			lower = e[1]
		end
	end
	if lower == 0 then
		-- Nothing cached yet: the interact distances (10 / 28 yards).
		if CheckInteractDistance(unit, 3) then return 0, 10 end
		if CheckInteractDistance(unit, 4) then return 10, 28 end
		return nil
	end
	return lower, nil
end

-- Attack range of the spec: melee 5, else 40 (Holy Paladin melee option).
local MELEE_SPECS = {
	[71] = true, [72] = true, [73] = true, [66] = true, [70] = true,
	[250] = true, [251] = true, [252] = true, [259] = true, [260] = true,
	[261] = true, [103] = true, [104] = true, [263] = true, [268] = true, [269] = true,
}
function Q.AttackCutoff(hpalMelee)
	local index = GetSpecialization()
	local spec = index and GetSpecializationInfo(index)
	if spec and (MELEE_SPECS[spec] or (spec == 65 and hpalMelee)) then
		return 5
	end
	return 40
end

---------------------------------------------------------------------------
-- FPS Counter (QoLExtras: showFPS, fpsColor/Mode, fpsTextSize, fpsShowLocalMS,
-- fpsShowWorldMS, fpsHideLabel, fpsUpdateInterval, fpsAttachToStats, fpsPos;
-- EllesmereUIDB.fpsToggleKey)
---------------------------------------------------------------------------
local XGet, XSet = Q.XGet, Q.XSet
local fpsFrame

function Q.FPSColor()
	if XGet("fpsColorMode") == "class" then
		local r, g, b = Q.ClassColor()
		return r, g, b, 1
	end
	local c = XGet("fpsColor")
	if c then return c.r or 1, c.g or 1, c.b or 1, c.a or 1 end
	return 1, 1, 1, 1
end

local function ShowLocalMS()
	local v = XGet("fpsShowLocalMS")
	if v == nil then return true end
	return v
end

function Q.FPSAttached()
	return (XGet("fpsAttachToStats") and XGet("showSecondaryStats")) and true or false
end

local DIV_PAD = 6
local function UpdateFPS(self)
	local cr, cg, cb, ca = Q.FPSColor()
	local fs = self.fs
	for _, t in ipairs({ fs.fps, fs.worldVal, fs.localVal }) do t:SetTextColor(cr, cg, cb, ca) end
	fs.worldLbl:SetTextColor(cr, cg, cb, ca * 0.6)
	fs.localLbl:SetTextColor(cr, cg, cb, ca * 0.6)
	self.divWorld:SetTexture(cr, cg, cb, ca * 0.35)
	self.divLocal:SetTexture(cr, cg, cb, ca * 0.35)
	fs.fps:SetText(floor(GetFramerate() + 0.5) .. " fps")
	local showWorld, showLocal = XGet("fpsShowWorldMS"), ShowLocalMS()
	local hideLabel = XGet("fpsHideLabel")
	local _, _, latHome, latWorld = GetNetStats()
	latHome, latWorld = latHome or 0, latWorld or 0
	local anchor = fs.fps
	local width = fs.fps:GetStringWidth()
	local function Part(show, div, val, lbl, ms, label)
		if not show then
			div:Hide(); val:Hide(); lbl:Hide()
			return
		end
		val:SetText(ms .. " ms")
		div:ClearAllPoints()
		div:SetPoint("LEFT", anchor, "RIGHT", DIV_PAD, 0)
		div:Show()
		val:ClearAllPoints()
		val:SetPoint("LEFT", div, "RIGHT", DIV_PAD, 0)
		val:Show()
		width = width + DIV_PAD * 2 + 1 + val:GetStringWidth()
		anchor = val
		if hideLabel then
			lbl:Hide()
		else
			lbl:SetText(label)
			lbl:ClearAllPoints()
			lbl:SetPoint("LEFT", val, "RIGHT", 3, 0)
			lbl:Show()
			width = width + 3 + lbl:GetStringWidth()
			anchor = lbl
		end
	end
	Part(showWorld, self.divWorld, fs.worldVal, fs.worldLbl, latWorld, "(world)")
	Part(showLocal, self.divLocal, fs.localVal, fs.localLbl, latHome, "(local)")
	self:SetSize(width + 4, 20)
end

local function CreateFPSCounter()
	if fpsFrame then return end
	fpsFrame = CreateFrame("Frame", "EUI_FPSCounter", UIParent)
	fpsFrame:SetSize(60, 20)
	fpsFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -10)
	fpsFrame:SetFrameStrata("MEDIUM")
	fpsFrame:SetFrameLevel(10)
	fpsFrame:EnableMouse(false)
	local function FS(size)
		local f = fpsFrame:CreateFontString(nil, "OVERLAY")
		f:SetFont(Q.Font(), size, Q.Outline())
		return f
	end
	fpsFrame.fs = {
		fps = FS(12), worldVal = FS(12), worldLbl = FS(10), localVal = FS(12), localLbl = FS(10),
	}
	fpsFrame.fs.fps:SetPoint("LEFT")
	local function Div()
		local d = fpsFrame:CreateTexture(nil, "OVERLAY")
		d:SetTexture(1, 1, 1, 0.25)
		d:SetSize(1, 10)
		return d
	end
	fpsFrame.divWorld, fpsFrame.divLocal = Div(), Div()
	local elapsed = 0
	fpsFrame:SetScript("OnUpdate", function(self, dt)
		elapsed = elapsed + dt
		if elapsed < (self.interval or 3) then return end
		elapsed = 0
		UpdateFPS(self)
	end)
	fpsFrame:Hide()
end

function Q.ApplyFPSCounter()
	if XGet("showFPS") and not Q.FPSAttached() then
		CreateFPSCounter()
		fpsFrame.interval = XGet("fpsUpdateInterval") or 3
		local sz = XGet("fpsTextSize") or 12
		local fs = fpsFrame.fs
		for _, t in ipairs({ fs.fps, fs.worldVal, fs.localVal }) do t:SetFont(Q.Font(), sz, Q.Outline()) end
		fs.worldLbl:SetFont(Q.Font(), sz - 2, Q.Outline())
		fs.localLbl:SetFont(Q.Font(), sz - 2, Q.Outline())
		if not UnlockActive() then
			PlaceFrom(fpsFrame, XGet("fpsPos"), { point = "TOPLEFT", relPoint = "TOPLEFT", x = 10, y = -10 })
		end
		UpdateFPS(fpsFrame)
		fpsFrame:Show()
	elseif fpsFrame then
		fpsFrame:Hide()
	end
end

-- FPS Toggle Keybind: an override binding clicks this button.
local fpsBind = CreateFrame("Button", "EUI_FPSBindBtn", UIParent)
fpsBind:Hide()
fpsBind:SetScript("OnClick", function()
	XSet("showFPS", not XGet("showFPS"))
	Q.ApplyFPSDisplay()
end)
local boundKey
function Q.ApplyFPSBind()
	local key = R().fpsToggleKey
	if key == boundKey then return end
	Q.AfterCombat("fpsBind", function()
		ClearOverrideBindings(fpsBind)
		if key then
			SetOverrideBindingClick(fpsBind, true, key, "EUI_FPSBindBtn")
		end
		boundKey = key
	end)
end

---------------------------------------------------------------------------
-- Secondary Stat Display (QoLExtras: showSecondaryStats, secondaryStatsColor/Mode,
-- coloredPercentages, secondaryStatsAbbreviateLabels, showSecondaryStatsRaw,
-- showSecondaryStatsBoth, secondaryStatsHidden, secondaryStatsOrder, secondaryStatsPos)
---------------------------------------------------------------------------
-- 5.4.8 secondaries are Crit, Haste, Mastery, Hit and Expertise (retail's
-- Versatility and the tertiaries do not exist; their saved keys are ignored).
local STAT_HEX = {
	crit = "ffd100", haste = "2ecc71", mastery = "55aaff", hit = "ffa94d", expertise = "c77dff",
}
Q.STAT_LABELS = {
	crit = "Crit", haste = "Haste", mastery = "Mastery", hit = "Hit", expertise = "Expertise",
}
local STAT_SHORT = { crit = "C", haste = "H", mastery = "M", hit = "Hi", expertise = "E" }
local DEFAULT_STAT_ORDER = { "crit", "haste", "mastery", "hit", "expertise" }

function Q.StatOrder()
	local saved = XGet("secondaryStatsOrder")
	local order, added = {}, {}
	if type(saved) == "table" then
		for _, key in ipairs(saved) do
			if STAT_HEX[key] and not added[key] then
				added[key] = true
				order[#order + 1] = key
			end
		end
	end
	for _, key in ipairs(DEFAULT_STAT_ORDER) do
		if not added[key] then order[#order + 1] = key end
	end
	return order
end

-- Casters read the spell figures, the others melee / ranged (by the class
-- power and spec, the way the 5.4.8 character pane picks its main group).
local CASTER_SPECS = {
	[62] = true, [63] = true, [64] = true, [65] = true, [256] = true, [257] = true,
	[258] = true, [262] = true, [264] = true, [265] = true, [266] = true, [267] = true,
	[102] = true, [105] = true, [270] = true,
}
local function StatValues()
	local index = GetSpecialization()
	local spec = index and GetSpecializationInfo(index)
	local _, cls = UnitClass("player")
	local caster = spec and CASTER_SPECS[spec]
	local hunter = cls == "HUNTER"
	local v, raw = {}, {}
	if caster then
		v.crit = GetSpellCritChance(2)
		v.haste = UnitSpellHaste("player")
		v.hit = GetCombatRatingBonus(CR_HIT_SPELL) + (GetSpellHitModifier() or 0)
		raw.crit, raw.haste, raw.hit = GetCombatRating(CR_CRIT_SPELL), GetCombatRating(CR_HASTE_SPELL), GetCombatRating(CR_HIT_SPELL)
	elseif hunter then
		v.crit = GetRangedCritChance()
		v.haste = GetRangedHaste and GetRangedHaste() or GetMeleeHaste()
		v.hit = GetCombatRatingBonus(CR_HIT_RANGED) + (GetHitModifier() or 0)
		raw.crit, raw.haste, raw.hit = GetCombatRating(CR_CRIT_RANGED), GetCombatRating(CR_HASTE_RANGED), GetCombatRating(CR_HIT_RANGED)
	else
		v.crit = GetCritChance()
		v.haste = GetMeleeHaste()
		v.hit = GetCombatRatingBonus(CR_HIT_MELEE) + (GetHitModifier() or 0)
		raw.crit, raw.haste, raw.hit = GetCombatRating(CR_CRIT_MELEE), GetCombatRating(CR_HASTE_MELEE), GetCombatRating(CR_HIT_MELEE)
	end
	v.mastery = GetMasteryEffect()
	raw.mastery = GetCombatRating(CR_MASTERY)
	v.expertise = (GetExpertise())
	raw.expertise = GetCombatRating(CR_EXPERTISE)
	return v, raw
end

local statsFrame, statsText
local function UpdateSecondaryStats()
	if not statsFrame or not statsFrame:IsShown() then return end
	local cr, cg, cb = Q.ClassColor()
	local classHex = format("%02x%02x%02x", cr * 255, cg * 255, cb * 255)
	local c = XGet("secondaryStatsColor")
	local mode = XGet("secondaryStatsColorMode") or (c and "custom" or "class")
	local customHex
	if mode == "custom" and c then
		customHex = format("%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
	elseif mode == "class" then
		customHex = classHex
	end
	local showBoth = XGet("showSecondaryStatsBoth")
	local showRawOnly = not showBoth and XGet("showSecondaryStatsRaw")
	local coloredPct = XGet("coloredPercentages")
	local abbreviate = XGet("secondaryStatsAbbreviateLabels")
	local hidden = XGet("secondaryStatsHidden")
	if type(hidden) ~= "table" then hidden = nil end
	local v, raw = StatValues()
	local rows = {}
	local function Row(hex, label, body)
		rows[#rows + 1] = format("|cff%s%s:|r |cff%s%s|r", hex, label, coloredPct and hex or "ffffff", body)
	end
	for _, key in ipairs(Q.StatOrder()) do
		if not (hidden and hidden[key]) then
			local hex = customHex or STAT_HEX[key]
			local label = abbreviate and STAT_SHORT[key] or Q.STAT_LABELS[key]
			local value, r = v[key] or 0, raw[key] or 0
			local body
			if showRawOnly then
				body = format("%.0f", r)
			elseif showBoth then
				body = format("%.0f (%.2f%%)", r, value)
			else
				body = format("%.2f%%", value)
			end
			Row(hex, label, body)
		end
	end
	-- FPS and latency rows while Attach to Secondary Stats is on.
	if XGet("fpsAttachToStats") and XGet("showFPS") then
		local fr, fg, fb = Q.FPSColor()
		local fpsHex = format("%02x%02x%02x", fr * 255, fg * 255, fb * 255)
		local VAL = "|cff" .. (coloredPct and fpsHex or "ffffff")
		rows[#rows + 1] = format("|cff%sFPS:|r %s%d|r", fpsHex, VAL, floor(GetFramerate() + 0.5))
		local showWorld, showLocal = XGet("fpsShowWorldMS"), ShowLocalMS()
		if showWorld or showLocal then
			local hideLabel = XGet("fpsHideLabel")
			local _, _, latHome, latWorld = GetNetStats()
			local parts = {}
			if showWorld then
				parts[#parts + 1] = VAL .. latWorld .. " ms|r" .. (hideLabel and "" or "|cff9d9d9d (world)|r")
			end
			if showLocal then
				parts[#parts + 1] = VAL .. latHome .. " ms|r" .. (hideLabel and "" or "|cff9d9d9d (local)|r")
			end
			rows[#rows + 1] = format("|cff%sLatency:|r %s", fpsHex, table.concat(parts, " |cff9d9d9d||||r "))
		end
	end
	statsText:SetText(table.concat(rows, "\n"))
	statsFrame:SetSize(statsText:GetStringWidth() + 2, statsText:GetStringHeight() + 2)
end
Q.UpdateSecondaryStats = UpdateSecondaryStats

local function ApplyStatsPosition()
	if not statsFrame or UnlockActive() then return end
	local pos = XGet("secondaryStatsPos")
	PlaceFrom(statsFrame, pos, { point = "TOPLEFT", relPoint = "TOPLEFT", x = 12, y = -12 })
end

local statsTicker
function Q.ApplySecondaryStats()
	if statsTicker then
		statsTicker.Cancel()
		statsTicker = nil
	end
	if not XGet("showSecondaryStats") then
		if statsFrame then
			statsFrame:Hide()
			statsFrame:UnregisterAllEvents()
		end
		return
	end
	if not statsFrame then
		statsFrame = CreateFrame("Frame", "EUI_SecondaryStats", UIParent)
		statsFrame:SetSize(160, 60)
		statsFrame:SetFrameStrata("LOW")
		statsText = statsFrame:CreateFontString(nil, "OVERLAY")
		statsText:SetPoint("TOPLEFT")
		statsText:SetJustifyH("LEFT")
		local pending = false
		statsFrame:SetScript("OnEvent", function()
			if pending then return end
			pending = true
			UpdateSecondaryStats()
			Q.After(0.5, function()
				pending = false
				UpdateSecondaryStats()
			end)
		end)
	end
	local pos = XGet("secondaryStatsPos")
	local scale = (type(pos) == "table" and pos.scale) or 1
	statsText:SetFont(Q.Font(), floor(12 * scale + 0.5), Q.Outline())
	statsText:SetSpacing(floor(3 * scale + 0.5))
	ApplyStatsPosition()
	for _, e in ipairs({ "UNIT_STATS", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER",
		"UNIT_SPELL_HASTE", "UNIT_ATTACK_SPEED", "UNIT_AURA" }) do
		statsFrame:RegisterUnitEvent(e, "player")
	end
	for _, e in ipairs({ "COMBAT_RATING_UPDATE", "PLAYER_EQUIPMENT_CHANGED", "MASTERY_UPDATE",
		"SPELL_POWER_CHANGED", "PLAYER_DAMAGE_DONE_MODS", "PLAYER_SPECIALIZATION_CHANGED",
		"PLAYER_ENTERING_WORLD" }) do
		statsFrame:RegisterEvent(e)
	end
	statsFrame:Show()
	if XGet("fpsAttachToStats") and XGet("showFPS") then
		statsTicker = Q.NewTicker(XGet("fpsUpdateInterval") or 3, UpdateSecondaryStats)
	end
	UpdateSecondaryStats()
end

-- FPS and stats together (the FPS readout can live in the stats block).
function Q.ApplyFPSDisplay()
	Q.ApplyFPSCounter()
	Q.ApplySecondaryStats()
end

---------------------------------------------------------------------------
-- Low Durability Warning (repairWarning (default on), durWarnColor,
-- durWarnTextSize, durWarnYOffset, durWarnPos, durWarnThreshold)
---------------------------------------------------------------------------
local durOverlay, durPreview
local function ApplyDurSettings()
	if not durOverlay then return end
	local root = R()
	durOverlay:ClearAllPoints()
	local pos = root.durWarnPos
	if type(pos) == "table" and pos.point then
		durOverlay:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 250)
	else
		durOverlay:SetPoint("CENTER", UIParent, "CENTER", 0, root.durWarnYOffset or 250)
	end
	durOverlay.text:SetFont(Q.Font(), root.durWarnTextSize or 30, Q.Outline())
	local c = root.durWarnColor
	if c then
		durOverlay.text:SetTextColor(c.r, c.g, c.b, 1)
	else
		durOverlay.text:SetTextColor(1, 0.27, 0.27, 1)
	end
end
local function CreateDurWarning()
	if durOverlay then return end
	durOverlay = CreateFrame("Frame", nil, UIParent)
	durOverlay:SetSize(400, 40)
	durOverlay:SetFrameStrata("HIGH")
	durOverlay:SetFrameLevel(50)
	durOverlay:EnableMouse(false)
	durOverlay.text = durOverlay:CreateFontString(nil, "OVERLAY")
	durOverlay.text:SetFont(Q.Font(), 30, Q.Outline())
	durOverlay.text:SetPoint("CENTER")
	-- Pulses between full and 30% alpha (0.4 s each way).
	local t = 0
	durOverlay:SetScript("OnUpdate", function(self, dt)
		t = (t + dt) % 0.8
		local a = t < 0.4 and (1 - 0.7 * t / 0.4) or (0.3 + 0.7 * (t - 0.4) / 0.4)
		self.text:SetAlpha(a)
	end)
	durOverlay:Hide()
	ApplyDurSettings()
end
local function ShowDurWarning(text)
	CreateDurWarning()
	ApplyDurSettings()
	durOverlay.text:SetText(text)
	durOverlay:Show()
end
function Q.DurPreview(on)
	durPreview = on and true or false
	if on then
		ShowDurWarning("Low Durability (Preview)")
	elseif durOverlay then
		durOverlay:Hide()
		Q.CheckDurability()
	end
end
function Q.DurPreviewShown()
	return durPreview and true or false
end
function Q.CheckDurability()
	if durPreview then
		ShowDurWarning("Low Durability (Preview)")
		return
	end
	if not Q.On("repairWarning") then
		if durOverlay then durOverlay:Hide() end
		return
	end
	if InCombatLockdown() then return end
	local lowest = 100
	for slot = 1, 18 do
		local cur, mx = GetInventoryItemDurability(slot)
		if cur and mx and mx > 0 then
			local pct = cur / mx * 100
			if pct < lowest then lowest = pct end
		end
	end
	if lowest < (R().durWarnThreshold or 40) then
		ShowDurWarning(format("Low Durability (%d%%)", floor(lowest)))
	elseif durOverlay then
		durOverlay:Hide()
	end
end
local durFrame = CreateFrame("Frame")
local durPending = false
durFrame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_DISABLED" then
		if durOverlay and not durPreview then durOverlay:Hide() end
		return
	end
	if durPending then return end
	durPending = true
	Q.After(0, function()
		durPending = false
		Q.CheckDurability()
	end)
end)
function Q.ApplyDurability()
	if Q.On("repairWarning") then
		for _, e in ipairs({ "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_ENTERING_WORLD",
			"UPDATE_INVENTORY_DURABILITY", "UPDATE_INVENTORY_ALERTS" }) do
			durFrame:RegisterEvent(e)
		end
	else
		durFrame:UnregisterAllEvents()
		durPreview = false
	end
	Q.CheckDurability()
end

---------------------------------------------------------------------------
-- Disable Right Click (disableRightClickTarget = Enemies,
-- disableRightClickTargetAllyCombat = Allies In Combat)
---------------------------------------------------------------------------
-- Retail: a state driver binds BUTTON2 to a mouselook button while the
-- mouse is over a matching unit, so the right click turns the camera
-- instead of targeting. 5.4.8 has no GLOBAL_MOUSE_UP: an OnUpdate releases
-- mouselook when the button is no longer down.
local mlookGuard = CreateFrame("Frame")
mlookGuard:Hide()
mlookGuard:SetScript("OnUpdate", function(self)
	if IsMouseButtonDown("RightButton") then return end
	self:Hide()
	if IsMouselooking() then MouselookStop() end
end)
local mlookBtn = CreateFrame("Button", "EUI_MouseLookBtn", UIParent)
mlookBtn:RegisterForClicks("AnyDown", "AnyUp")
mlookBtn:SetScript("OnClick", function(_, _, down)
	if down then
		mlookGuard:Show()
		MouselookStart()
	else
		mlookGuard:Hide()
		MouselookStop()
	end
end)
local rcState = CreateFrame("Frame", "EUI_NoRightClickState", UIParent, "SecureHandlerStateTemplate")
rcState:SetAttribute("_onstate-mov", [[
	if newstate == 1 then
		self:SetBindingClick(1, "BUTTON2", "EUI_MouseLookBtn")
	else
		self:ClearBindings()
	end
]])
local rcDriver = false
function Q.ApplyRightClick()
	Q.AfterCombat("rightClick", function()
		local root = R()
		local enemy, ally = root.disableRightClickTarget, root.disableRightClickTargetAllyCombat
		if enemy or ally then
			local macro = ""
			if enemy then
				-- 5.4.8 state drivers re-check the mouseover by themselves, so
				-- one rule covers in and out of combat (retail needs two lanes).
				macro = macro .. "[@mouseover,harm,nodead]1;"
			end
			if ally then
				macro = macro .. "[@mouseover,help,party,nodead,combat]1;[@mouseover,help,raid,nodead,combat]1;"
			end
			RegisterStateDriver(rcState, "mov", macro .. "0")
			rcDriver = true
		elseif rcDriver then
			UnregisterStateDriver(rcState, "mov")
			rcState:SetAttribute("state-mov", 0)
			ClearOverrideBindings(rcState)
			rcDriver = false
		end
	end)
end

---------------------------------------------------------------------------
-- Rested Indicator (showRestedIndicator, restedIndicatorXOffset / YOffset)
---------------------------------------------------------------------------
-- Retail's "ZZZ" at the top left of the player frame health bar; the 5.4.8
-- Unit Frames do not build it, so it is made here.
local restFrame = CreateFrame("Frame")
local restText
function Q.ApplyRested()
	local pf = _G.EllesmereUIUnitFrames_Player
	local on = R().showRestedIndicator == true
	if not pf or not pf.Health then
		return
	end
	if not restText then
		if not on then return end
		local holder = CreateFrame("Frame", nil, pf.Health)
		holder:SetAllPoints(pf.Health)
		holder:SetFrameLevel(pf.Health:GetFrameLevel() + 5)
		restText = holder:CreateFontString(nil, "OVERLAY")
		restText:SetFont(Q.Font(), 9, Q.Outline())
		restText:SetTextColor(1, 1, 1)
		restText:SetText("ZZZ")
		pf._restIndicator = restText
		restFrame:RegisterEvent("PLAYER_UPDATE_RESTING")
		restFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
		restFrame:SetScript("OnEvent", function() Q.ApplyRested() end)
	end
	restText:ClearAllPoints()
	restText:SetPoint("TOPLEFT", pf.Health, "TOPLEFT", 3 + (R().restedIndicatorXOffset or 0), -2 + (R().restedIndicatorYOffset or 0))
	restText:SetShown(on and IsResting() and true or false)
end

---------------------------------------------------------------------------
-- Target Distance (Range) Text (targetDistanceEnabled, targetDistanceFormat,
-- targetDistanceAlign, targetDistanceTextSize, targetDistanceStrata, targetDistancePos)
---------------------------------------------------------------------------
local TD_DEFAULT_POS = { point = "CENTER", relPoint = "CENTER", x = 0, y = 120 }
local distFrame, distDriver
local function TDFormat()
	local f = R().targetDistanceFormat
	if f == "plus" or f == "min" or f == "range" then return f end
	return "range"
end
local function TDAlign()
	local a = R().targetDistanceAlign
	if a == "LEFT" or a == "CENTER" or a == "RIGHT" then return a end
	return "CENTER"
end
local function ColorForYards(y)
	if y <= 8 then return 0.30, 0.95, 0.40
	elseif y <= 15 then return 0.85, 0.95, 0.25
	elseif y <= 25 then return 1.00, 0.85, 0.20
	elseif y <= 40 then return 1.00, 0.55, 0.15 end
	return 0.95, 0.25, 0.20
end
local function DistanceText(unit)
	local minY, maxY = Q.RangeBracket(unit)
	if minY == nil then return nil end
	local fmt = TDFormat()
	if fmt == "plus" or fmt == "min" then
		if minY <= 0 then return nil end
		return (fmt == "plus") and (minY .. "+") or tostring(minY), minY
	end
	if maxY then
		return ((minY > 0) and minY or 1) .. "-" .. maxY, maxY
	end
	if minY >= 80 then return "80+", minY end
	return minY .. "+", minY
end
local function ApplyDistFrame()
	if not distFrame then return end
	local root = R()
	local size = root.targetDistanceTextSize or 18
	local align = TDAlign()
	distFrame.text:SetFont(Q.Font(), size, Q.OutlineForced())
	distFrame.text:SetJustifyH(align)
	distFrame.text:ClearAllPoints()
	distFrame.text:SetPoint(align, distFrame, align, 0, 0)
	distFrame:SetFrameStrata(root.targetDistanceStrata or "HIGH")
	distFrame:SetSize(size * 5, size + 10)
	if UnlockActive() then return end
	if type(root.unlockAnchors) == "table" and root.unlockAnchors.EUI_TargetDistance then return end
	PlaceFrom(distFrame, root.targetDistancePos, TD_DEFAULT_POS)
end
local function CreateDistFrame()
	if distFrame then return end
	distFrame = CreateFrame("Frame", nil, UIParent)
	distFrame:SetSize(100, 28)
	distFrame:SetFrameLevel(55)
	distFrame:EnableMouse(false)
	distFrame.text = distFrame:CreateFontString(nil, "OVERLAY")
	distFrame.text:SetFont(Q.Font(), 18, Q.OutlineForced())
	distFrame.text:SetPoint("CENTER")
	distFrame:Hide()
	ApplyDistFrame()
end
local function DistTick()
	if not R().targetDistanceEnabled then return end
	if UnlockActive() then
		CreateDistFrame()
		local fmt = TDFormat()
		distFrame.text:SetText(fmt == "plus" and "30+" or fmt == "min" and "30" or "25-30")
		distFrame.text:SetTextColor(ColorForYards(fmt == "range" and 25 or 30))
		distFrame:Show()
		return
	end
	local text, colorY = nil, nil
	if UnitExists("target") then
		text, colorY = DistanceText("target")
	end
	if not text then
		if distFrame then distFrame:Hide() end
		return
	end
	CreateDistFrame()
	distFrame.text:SetText(text)
	distFrame.text:SetTextColor(ColorForYards(colorY))
	distFrame:Show()
end
function Q.ApplyTargetDistance()
	if R().targetDistanceEnabled then
		if not distDriver then
			distDriver = CreateFrame("Frame")
			local acc = 0
			distDriver:SetScript("OnUpdate", function(_, dt)
				acc = acc + dt
				if acc < 0.2 then return end
				acc = 0
				DistTick()
			end)
			distDriver:SetScript("OnEvent", DistTick)
		end
		distDriver:RegisterEvent("PLAYER_TARGET_CHANGED")
		distDriver:Show()
		CreateDistFrame()
		ApplyDistFrame()
		DistTick()
	else
		if distDriver then
			distDriver:UnregisterAllEvents()
			distDriver:Hide()
		end
		if distFrame then distFrame:Hide() end
	end
end

---------------------------------------------------------------------------
-- Character Crosshair (crosshair* keys of the cursor settings,
-- EllesmereUIQoLDB.cursor, like retail's cursor profile)
---------------------------------------------------------------------------
Q.CROSSHAIR_PRESETS = {
	Thin = { width = 1, length = 40 },
	Normal = { width = 2, length = 40 },
	Thick = { width = 3, length = 40 },
}
ns.CROSSHAIR_PRESETS = Q.CROSSHAIR_PRESETS
function Q.CursorDB()
	-- The Cursor file owns the table (and seeds it); crosshair* keys are ours.
	local t = ns.GetCursorDB and ns.GetCursorDB()
	if type(t) == "table" then return t end
	local q = Q.DB()
	if type(q.cursor) ~= "table" then q.cursor = {} end
	return q.cursor
end
function Q.CGet(k)
	local v = Q.CursorDB()[k]
	if v ~= nil then return v end
	return R()[k]
end
function Q.CSet(k, v)
	Q.CursorDB()[k] = v
end
local CG = Q.CGet

local chFrame, chWatch
local function TargetOutOfRange()
	if not (UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target")) then
		return false
	end
	local cutoff = Q.AttackCutoff(CG("crosshairHpalMelee"))
	local minY, maxY = Q.RangeBracket("target")
	if minY == nil then return true end
	return minY >= cutoff and not (maxY and maxY <= cutoff)
end
local function CreateCrosshair()
	if chFrame then return end
	chFrame = CreateFrame("Frame", "EUI_CharacterCrosshair", UIParent)
	chFrame:SetFrameStrata("MEDIUM")
	chFrame:SetFrameLevel(100)
	chFrame:EnableMouse(false)
	chFrame:SetSize(1, 1)
	chFrame.hBorder = chFrame:CreateTexture(nil, "ARTWORK")
	chFrame.vBorder = chFrame:CreateTexture(nil, "ARTWORK")
	chFrame.hBar = chFrame:CreateTexture(nil, "OVERLAY")
	chFrame.vBar = chFrame:CreateTexture(nil, "OVERLAY")
	local acc = 0
	chFrame:SetScript("OnUpdate", function(self, dt)
		acc = acc + dt
		if acc < 0.15 then return end
		acc = 0
		local nc = self.normal
		if not nc then return end
		local out = CG("crosshairMeleeColorEnabled") and TargetOutOfRange() or false
		if out ~= self.outActive then
			self.outActive = out
			local c = out and (CG("crosshairMeleeColor") or { r = 1, g = 0, b = 0, a = 1 }) or nc
			self.hBar:SetTexture(c.r or 1, c.g or 0, c.b or 0, c.a or 1)
			self.vBar:SetTexture(c.r or 1, c.g or 0, c.b or 0, c.a or 1)
		end
	end)
end
function Q.CrosshairCutoff()
	return Q.AttackCutoff(CG("crosshairHpalMelee"))
end
function Q.ApplyCrosshair()
	local size = CG("crosshairSize") or "None"
	if size == "None" then
		if chWatch then chWatch:UnregisterAllEvents() end
		if chFrame then chFrame:Hide() end
		return
	end
	if not chWatch then
		chWatch = CreateFrame("Frame")
		chWatch:SetScript("OnEvent", function() Q.ApplyCrosshair() end)
	end
	chWatch:RegisterEvent("PLAYER_REGEN_DISABLED")
	chWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
	chWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
	CreateCrosshair()
	chFrame:SetFrameStrata(CG("crosshairStrata") or "MEDIUM")
	local c = CG("crosshairColor")
	local cr, cg, cb, ca = c and c.r or 1, c and c.g or 1, c and c.b or 1, c and c.a or 0.75
	local preset = Q.CROSSHAIR_PRESETS[size] or Q.CROSSHAIR_PRESETS.Normal
	local hW, vW = CG("crosshairHWidth") or preset.width, CG("crosshairVWidth") or preset.width
	local hL, vL = CG("crosshairHLength") or preset.length, CG("crosshairVLength") or preset.length
	chFrame:ClearAllPoints()
	chFrame:SetPoint("CENTER", UIParent, "CENTER", CG("crosshairXOffset") or 0, CG("crosshairYOffset") or 0)
	local hBar, vBar = chFrame.hBar, chFrame.vBar
	hBar:ClearAllPoints()
	hBar:SetSize(hL, hW)
	hBar:SetPoint("CENTER")
	hBar:SetTexture(cr, cg, cb, ca)
	vBar:ClearAllPoints()
	vBar:SetSize(vW, vL)
	vBar:SetPoint("CENTER")
	vBar:SetTexture(cr, cg, cb, ca)
	chFrame.normal = { r = cr, g = cg, b = cb, a = ca }
	chFrame.outActive = false
	local bSize = CG("crosshairBorderSize") or 0
	if bSize > 0 then
		local bc = CG("crosshairBorderColor") or { r = 0, g = 0, b = 0, a = 1 }
		for _, e in ipairs({ { chFrame.hBorder, hL, hW }, { chFrame.vBorder, vW, vL } }) do
			local t = e[1]
			t:ClearAllPoints()
			t:SetSize(e[2] + bSize * 2, e[3] + bSize * 2)
			t:SetPoint("CENTER")
			t:SetTexture(bc.r or 0, bc.g or 0, bc.b or 0, bc.a or 1)
			t:Show()
		end
	else
		chFrame.hBorder:Hide()
		chFrame.vBorder:Hide()
	end
	local vis = CG("crosshairVisibility") or "always"
	local inCombat = InCombatLockdown() or UnitAffectingCombat("player")
	local show = true
	if vis == "combat" then
		show = inCombat
	elseif vis == "instances" then
		show = IsInInstance()
	elseif vis == "instances_combat" then
		show = IsInInstance() and inCombat
	end
	chFrame:SetShown(show and true or false)
end

---------------------------------------------------------------------------
-- Combat Alert (combatAlertEnabled, combatAlertMode, combatAlertTextSize,
-- combatAlertPos, combatAlertEnter/LeaveText, ...Color, ...UseClassColor)
---------------------------------------------------------------------------
local CA_DEFAULT_POS = { point = "CENTER", relPoint = "CENTER", x = 0, y = 169 }
local caFrame
local caWatch = CreateFrame("Frame")
local function CAColor(which)
	local root = R()
	if root[which == "leave" and "combatAlertLeaveUseClassColor" or "combatAlertEnterUseClassColor"] then
		return Q.ClassColor()
	end
	local c = root[which == "leave" and "combatAlertLeaveColor" or "combatAlertEnterColor"]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end
local function CAText(which)
	if which == "leave" then
		return R().combatAlertLeaveText or "-Combat"
	end
	return R().combatAlertEnterText or "+Combat"
end
local function ApplyCAFrame()
	if not caFrame then return end
	local size = R().combatAlertTextSize or 22
	caFrame.text:SetFont(Q.Font(), size, Q.OutlineForced())
	caFrame:SetSize(size * 7, size + 14)
	if not UnlockActive() then
		PlaceFrom(caFrame, R().combatAlertPos, CA_DEFAULT_POS)
		if Q.PlaceAlertLines then Q.PlaceAlertLines() end
	end
end
local function CreateCAFrame()
	if caFrame then return end
	caFrame = CreateFrame("Frame", nil, UIParent)
	caFrame:SetSize(240, 50)
	caFrame:SetFrameStrata("HIGH")
	caFrame:SetFrameLevel(60)
	caFrame:EnableMouse(false)
	caFrame.text = caFrame:CreateFontString(nil, "OVERLAY")
	caFrame.text:SetFont(Q.Font(), 22, Q.OutlineForced())
	caFrame.text:SetPoint("CENTER")
	caFrame:Hide()
	ApplyCAFrame()
end
function Q.CombatAlertPreview(which)
	if UnlockActive() then return end
	CreateCAFrame()
	ApplyCAFrame()
	caFrame.text:SetText(CAText(which))
	caFrame.text:SetTextColor(CAColor(which))
	Flash(caFrame, 0.15, 1.2, 0.5)
end
caWatch:SetScript("OnEvent", function(_, event)
	if not R().combatAlertEnabled then return end
	local mode = R().combatAlertMode or "both"
	if event == "PLAYER_REGEN_DISABLED" and mode ~= "leave" then
		Q.CombatAlertPreview("enter")
	elseif event == "PLAYER_REGEN_ENABLED" and mode ~= "enter" then
		Q.CombatAlertPreview("leave")
	end
end)
function Q.ApplyCombatAlert()
	if R().combatAlertEnabled then
		caWatch:RegisterEvent("PLAYER_REGEN_DISABLED")
		caWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
	else
		caWatch:UnregisterAllEvents()
	end
	ApplyCAFrame()
end

---------------------------------------------------------------------------
-- Potion Ready / Unspent Talents (retail Alerts: potionAlert*, talentAlert*)
-- Lines that follow the Combat Alert position: Unspent Talents above it,
-- Potion Ready below it. Potion Ready: the potion drunk is found from its
-- on-use spell name (GetItemSpell), its cooldown read once, one timer at the
-- end. Unspent Talents stays up while GetNumUnspentTalents() > 0, until the
-- talent window opens; it comes back on a level-up.
---------------------------------------------------------------------------
Q.ALERT_DEFAULTS = {
	potionAlert = { text = "Potion Ready", color = { r = 0.1, g = 1, b = 0.1 } },
	talentAlert = { text = "Unspent talent points", color = { r = 1, g = 0.82, b = 0 } },
}
local alertLines = {}
local function AlertColor(prefix)
	local root = R()
	if root[prefix .. "UseClassColor"] then return Q.ClassColor() end
	local c = root[prefix .. "Color"] or Q.ALERT_DEFAULTS[prefix].color
	return c.r, c.g, c.b
end
local function PlaceAlertLine(prefix)
	local f = alertLines[prefix]
	if not f then return end
	local size = R()[prefix .. "TextSize"] or 22
	f.text:SetFont(Q.Font(), size, Q.OutlineForced())
	f:SetSize(size * 7, size + 14)
	local pos = R().combatAlertPos
	if type(pos) ~= "table" or not pos.point then pos = CA_DEFAULT_POS end
	local caH = (R().combatAlertTextSize or 22) + 14
	local dy = prefix == "talentAlert" and (caH / 2 + (size + 14) / 2 + 4) or -(caH / 2 + (size + 14) / 2 + 4)
	f:ClearAllPoints()
	f:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, (pos.y or 0) + dy)
end
local function AlertLine(prefix)
	local f = alertLines[prefix]
	if not f then
		f = CreateFrame("Frame", nil, UIParent)
		f:SetFrameStrata("HIGH")
		f:SetFrameLevel(60)
		f:EnableMouse(false)
		f.text = f:CreateFontString(nil, "OVERLAY")
		f.text:SetPoint("CENTER")
		f:Hide()
		alertLines[prefix] = f
	end
	PlaceAlertLine(prefix)
	f.text:SetText(R()[prefix .. "Text"] or Q.ALERT_DEFAULTS[prefix].text)
	f.text:SetTextColor(AlertColor(prefix))
	return f
end
-- Short flash (also the preview of either alert).
function Q.AlertPreview(prefix)
	if UnlockActive() then return end
	local f = AlertLine(prefix)
	f.persistent = nil
	Flash(f, 0.15, prefix == "potionAlert" and 3 or 1.2, 0.5)
end
local function AlertHide(prefix)
	local f = alertLines[prefix]
	if f then f:SetScript("OnUpdate", nil); f:Hide(); f.persistent = nil end
end

-- Potion Ready
local potWatch = CreateFrame("Frame")
local potionSub
local spellToItem, potSeen = {}, {}
local potTimerGen, potPending = 0, nil
local function PotionSubclass()
	if potionSub then return potionSub end
	-- Consumable is auction class 4 in 5.4.8; Potion its 2nd subclass.
	potionSub = (GetAuctionItemSubClasses and select(2, GetAuctionItemSubClasses(4))) or "Potion"
	return potionSub
end
local function ScanPotionBags()
	for bag = 0, NUM_BAG_SLOTS or 4 do
		for slot = 1, GetContainerNumSlots(bag) or 0 do
			local id = GetContainerItemID(bag, slot)
			if id and potSeen[id] == nil then
				local name, _, _, _, _, _, sub = GetItemInfo(id)
				if name then
					local spell = sub == PotionSubclass() and GetItemSpell(id)
					if spell then spellToItem[spell] = id; potSeen[id] = true else potSeen[id] = false end
				end
			end
		end
	end
end
local function PotionReadyIn(itemID, delay)
	potTimerGen = potTimerGen + 1
	local gen = potTimerGen
	potPending = itemID
	Q.After(math.max(delay, 0), function()
		if gen ~= potTimerGen or not R().potionAlertEnabled then return end
		potPending = nil
		if (GetItemCount(itemID) or 0) <= 0 then return end
		local start, dur = GetItemCooldown(itemID)
		if start and dur and dur > 1.5 then
			local left = start + dur - GetTime()
			if left > 0.5 then PotionReadyIn(itemID, left); return end
		end
		Q.AlertPreview("potionAlert")
	end)
end
potWatch:SetScript("OnEvent", function(_, event, unit, spellName)
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		if unit ~= "player" then return end
		local itemID = spellName and spellToItem[spellName]
		if not itemID then return end
		-- The item cooldown starts a moment after the cast event.
		Q.After(0.3, function()
			local start, dur = GetItemCooldown(itemID)
			if start and dur and dur > 1.5 then
				PotionReadyIn(itemID, start + dur - GetTime())
			end
		end)
	elseif event == "BAG_UPDATE_COOLDOWN" then
		-- A reset (encounter end) makes the potion ready early.
		if potPending then
			local start, dur = GetItemCooldown(potPending)
			if start and dur and dur <= 1.5 then PotionReadyIn(potPending, 0) end
		end
	else
		ScanPotionBags()
	end
end)
function Q.ApplyPotionAlert()
	potWatch:UnregisterAllEvents()
	if R().potionAlertEnabled then
		potWatch:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		potWatch:RegisterEvent("BAG_UPDATE_DELAYED")
		potWatch:RegisterEvent("GET_ITEM_INFO_RECEIVED")
		potWatch:RegisterEvent("BAG_UPDATE_COOLDOWN")
		ScanPotionBags()
	else
		potTimerGen = potTimerGen + 1
		potPending = nil
		AlertHide("potionAlert")
	end
	PlaceAlertLine("potionAlert")
end

-- Unspent Talents
local talWatch = CreateFrame("Frame")
local talDismissed, talHad, talHooked = false, false, false
local function TalentEvaluate()
	if not R().talentAlertEnabled then return end
	if InCombatLockdown() then Q.AfterCombat("talentAlert", TalentEvaluate); return end
	local has = (GetNumUnspentTalents and GetNumUnspentTalents() or 0) > 0
	if has then
		if not talHad then talDismissed = false end
		if not talDismissed and not UnlockActive() then
			local f = AlertLine("talentAlert")
			if not f.persistent then
				f.persistent = true
				f:SetScript("OnUpdate", nil)
				f:SetAlpha(1)
				f:Show()
			end
		end
	else
		talDismissed = false
		AlertHide("talentAlert")
	end
	talHad = has
end
local function HookTalentFrame()
	if talHooked or not PlayerTalentFrame then return end
	talHooked = true
	PlayerTalentFrame:HookScript("OnShow", function()
		if R().talentAlertEnabled then
			talDismissed = true
			AlertHide("talentAlert")
		end
	end)
end
talWatch:SetScript("OnEvent", function(_, event, arg)
	if event == "ADDON_LOADED" then
		if arg == "Blizzard_TalentUI" then HookTalentFrame() end
		return
	end
	if event == "PLAYER_LEVEL_UP" then talDismissed = false end
	Q.After(0, TalentEvaluate)
end)
function Q.ApplyTalentAlert()
	talWatch:UnregisterAllEvents()
	if R().talentAlertEnabled then
		for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_TALENT_UPDATE", "PLAYER_SPECIALIZATION_CHANGED",
			"PLAYER_LEVEL_UP", "ADDON_LOADED" }) do
			talWatch:RegisterEvent(e)
		end
		HookTalentFrame()
		talHad, talDismissed = false, false
		TalentEvaluate()
	else
		AlertHide("talentAlert")
	end
	PlaceAlertLine("talentAlert")
end
function Q.PlaceAlertLines()
	PlaceAlertLine("potionAlert")
	PlaceAlertLine("talentAlert")
end
-- A live talent line gets its text and color refreshed; otherwise a sample.
function Q.TalentAlertPreview()
	local f = alertLines.talentAlert
	if f and f.persistent then AlertLine("talentAlert") else Q.AlertPreview("talentAlert") end
end

---------------------------------------------------------------------------
-- Announce Group Deaths (announceGroupDeaths, groupDeathTextSize,
-- groupDeathSoundKey, groupDeathAlertPos)
---------------------------------------------------------------------------
-- Retail polls the group for alive -> dead changes (Midnight has no combat
-- log); the same polling works on 5.4.8.
local SOUND_DIR = "Interface\\AddOns\\EllesmereUIQoL\\Media\\sounds\\"
local SOUND_FILES = {
	airhorn = "AirHorn.ogg", banana = "BananaPeelSlip.ogg", bikehorn = "BikeHorn.ogg",
	bite = "Bite.ogg", boxing = "BoxingArenaSound.ogg", catmeow = "CatMeow.ogg",
	catmeow2 = "CatMeow2.ogg", gunshot = "FrontalsGunshot.wav", glass = "Glass.mp3",
	kaching = "Kaching.ogg", phone = "Phone.ogg", robotblip = "RobotBlip.ogg",
	sonar = "Sonar.ogg", siren = "WarningSiren.ogg", water = "WaterDrop.ogg",
	wilhelm = "Wilhelm.ogg",
}
Q.SOUND_NAMES = {
	none = "None", airhorn = "Air Horn", banana = "Banana Peel Slip",
	bikehorn = "Bike Horn", bite = "Bite", boxing = "Boxing Arena",
	catmeow = "Cat Meow", catmeow2 = "Cat Meow 2", gunshot = "Frontals Gunshot",
	glass = "Glass", kaching = "Kaching", phone = "Phone", robotblip = "Robot Blip",
	sonar = "Sonar", siren = "Warning Siren", water = "Water Drop", wilhelm = "Wilhelm",
}
Q.SOUND_ORDER = {
	"none", "airhorn", "banana", "bikehorn", "bite", "boxing", "catmeow",
	"catmeow2", "gunshot", "glass", "kaching", "phone", "robotblip", "sonar",
	"siren", "water", "wilhelm",
}
Q.SOUND_PATHS = {}
for k, f in pairs(SOUND_FILES) do Q.SOUND_PATHS[k] = SOUND_DIR .. f end
-- LibSharedMedia sounds are added at login (retail AppendSharedMediaSounds).
local function AppendSharedMediaSounds()
	local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
	if not LSM then return end
	for _, name in ipairs(LSM:List("sound") or {}) do
		local path = LSM:Fetch("sound", name)
		local key = "lsm:" .. name
		if path and name ~= "None" and not Q.SOUND_NAMES[key] then
			Q.SOUND_NAMES[key] = name
			Q.SOUND_PATHS[key] = path
			Q.SOUND_ORDER[#Q.SOUND_ORDER + 1] = key
		end
	end
end

local GD_DEFAULT_POS = { point = "CENTER", relPoint = "CENTER", x = 0, y = 180 }
local gdFrame, gdTicker
local deadState = {}
local gdWatch = CreateFrame("Frame")
local function ApplyGDFrame()
	if not gdFrame then return end
	local size = R().groupDeathTextSize or 34
	gdFrame.text:SetFont(Q.Font(), size, Q.OutlineForced())
	gdFrame:SetSize(size * 7, size + 14)
	if not UnlockActive() then
		PlaceFrom(gdFrame, R().groupDeathAlertPos, GD_DEFAULT_POS)
	end
end
local function CreateGDFrame()
	if gdFrame then return end
	gdFrame = CreateFrame("Frame", nil, UIParent)
	gdFrame:SetSize(240, 50)
	gdFrame:SetFrameStrata("HIGH")
	gdFrame:SetFrameLevel(60)
	gdFrame:EnableMouse(false)
	gdFrame.text = gdFrame:CreateFontString(nil, "OVERLAY")
	gdFrame.text:SetFont(Q.Font(), 34, Q.OutlineForced())
	gdFrame.text:SetPoint("CENTER")
	gdFrame:Hide()
	ApplyGDFrame()
end
local function ShowDeath(name, classToken)
	if not name then return end
	CreateGDFrame()
	ApplyGDFrame()
	local c = classToken and RAID_CLASS_COLORS[classToken]
	local colored = c and ("|c" .. (c.colorStr or "ffffffff") .. name .. "|r") or name
	gdFrame.text:SetText("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0|t " .. colored .. " |cffff2020DIED!|r")
	Flash(gdFrame, 0.15, 1.6, 0.6)
end
function Q.GroupDeathPlaySound()
	local key = R().groupDeathSoundKey
	local path = key and key ~= "none" and Q.SOUND_PATHS[key]
	if path then PlaySoundFile(path, "Master") end
end
function Q.GroupDeathPreview()
	local _, cls = UnitClass("player")
	ShowDeath(UnitName("player"), cls)
end
local lastSound = 0
local function GDPoll()
	if not R().announceGroupDeaths then return end
	local seen, newName, newClass = {}, nil, nil
	local function Check(u)
		local guid = UnitGUID(u)
		if not guid then return end
		seen[guid] = true
		if not UnitIsConnected(u) then return end
		local dead = (UnitIsDeadOrGhost(u) and not UnitIsFeignDeath(u)) and true or false
		if deadState[guid] == false and dead then
			local _, cls = UnitClass(u)
			newName, newClass = UnitName(u), cls
		end
		deadState[guid] = dead
	end
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do
			local u = "raid" .. i
			if UnitExists(u) and not UnitIsUnit(u, "player") then Check(u) end
		end
	elseif IsInGroup() then
		for i = 1, 4 do
			local u = "party" .. i
			if UnitExists(u) then Check(u) end
		end
	end
	for guid in pairs(deadState) do
		if not seen[guid] then deadState[guid] = nil end
	end
	if newName then
		ShowDeath(newName, newClass)
		-- Big groups: one sound per 3 seconds.
		if GetNumGroupMembers() <= 5 or GetTime() - lastSound >= 3 then
			lastSound = GetTime()
			Q.GroupDeathPlaySound()
		end
	end
end
local function GDUpdateActive()
	if R().announceGroupDeaths and IsInGroup() then
		if not gdTicker then
			wipe(deadState)
			GDPoll()
			gdTicker = Q.NewTicker(0.35, GDPoll)
		end
	elseif gdTicker then
		gdTicker.Cancel()
		gdTicker = nil
		wipe(deadState)
	end
end
gdWatch:SetScript("OnEvent", GDUpdateActive)
function Q.ApplyGroupDeaths()
	if R().announceGroupDeaths then
		gdWatch:RegisterEvent("GROUP_ROSTER_UPDATE")
		gdWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
	else
		gdWatch:UnregisterAllEvents()
	end
	GDUpdateActive()
	ApplyGDFrame()
end

---------------------------------------------------------------------------
-- Hide Item Transforms (hideTransforms, hideTransformItems)
---------------------------------------------------------------------------
-- The 5.4.8 part of retail's list: holiday costumes and Noggenfogger.
-- (Profession gear, toys and the newer items do not exist on 5.4.8.)
Q.TRANSFORMS = {
	{ key = "lantern", cat = "holiday", label = "Weighted Jack-o'-Lantern", ids = { 44212 } },
	{ key = "hallowed", cat = "holiday", label = "Hallowed Wand", ids = {
		24732, 24735, 24736, 24712, 24713, 24710, 24711, 24708, 24709, 24723, 24740 } },
	{ key = "noblebunny", cat = "holiday", label = "Noblegarden Bunny", ids = { 61734, 61716 } },
	{ key = "turkey", cat = "holiday", label = "Pilgrim's Turkey", ids = { 61781 } },
	{ key = "noggenfogger", cat = "items", label = "Noggenfogger Elixir", ids = { 16593, 16595 } },
}
function Q.TransformEnabled(key)
	local t = R().hideTransformItems
	local v = nil
	if type(t) == "table" then v = t[key] end
	if v ~= nil then return v end
	return true
end
local cancelIds = {}
local auraFrame = CreateFrame("Frame")
local function CancelTransforms()
	if InCombatLockdown() then return end
	for i = 40, 1, -1 do
		local name, _, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
		if name and spellId and cancelIds[spellId] then
			CancelUnitBuff("player", i)
		end
	end
end
auraFrame:SetScript("OnEvent", function() CancelTransforms() end)
function Q.ApplyTransforms()
	wipe(cancelIds)
	if R().hideTransforms then
		for _, item in ipairs(Q.TRANSFORMS) do
			if Q.TransformEnabled(item.key) then
				for _, id in ipairs(item.ids) do cancelIds[id] = true end
			end
		end
	end
	if next(cancelIds) then
		auraFrame:RegisterUnitEvent("UNIT_AURA", "player")
		auraFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		CancelTransforms()
	else
		auraFrame:UnregisterAllEvents()
	end
end

---------------------------------------------------------------------------
-- Unlock Mode elements (retail keys)
---------------------------------------------------------------------------
local function PosElement(key, label, order, isHidden, getFrame, getSize, posKey, default, apply, isRoot)
	local function store() return isRoot and R() or Q.DB() end
	return {
		key = key, label = label, group = "Quality of Life", order = order,
		noResize = true, noAnchorTarget = true,
		isHidden = isHidden, getFrame = getFrame, getSize = getSize,
		savePos = function(_, point, relPoint, x, y)
			if not point then return end
			local old = store()[posKey]
			store()[posKey] = { point = point, relPoint = relPoint, x = x, y = y,
				scale = type(old) == "table" and old.scale or nil }
			if not UnlockActive() then apply() end
		end,
		loadPos = function()
			local pos = store()[posKey]
			if type(pos) == "table" and pos.point then return pos end
			return default
		end,
		clearPos = function()
			store()[posKey] = nil
			apply()
		end,
		applyPos = apply,
	}
end

AddUnlock(PosElement("EUI_FPS", "FPS Counter", 700,
	function() return not XGet("showFPS") or Q.FPSAttached() end,
	function() CreateFPSCounter(); return fpsFrame end,
	function() if fpsFrame then return fpsFrame:GetWidth(), fpsFrame:GetHeight() end return 80, 20 end,
	"fpsPos", nil, function() Q.ApplyFPSCounter() end, false))
AddUnlock(PosElement("EUI_SecondaryStats", "Secondary Stats", 710,
	function() return not XGet("showSecondaryStats") end,
	function() return statsFrame end,
	function() if statsFrame then return statsFrame:GetWidth(), statsFrame:GetHeight() end return 160, 60 end,
	"secondaryStatsPos", nil, ApplyStatsPosition, false))
AddUnlock(PosElement("EUI_GroupDeathAlert", "Group Death Alert", 720,
	function() return not R().announceGroupDeaths end,
	function() CreateGDFrame(); return gdFrame end,
	function() local s = R().groupDeathTextSize or 34; return s * 7, s + 14 end,
	"groupDeathAlertPos", GD_DEFAULT_POS, ApplyGDFrame, true))
AddUnlock(PosElement("EUI_CombatAlert", "Alerts", 721,
	function() local r = R(); return not (r.combatAlertEnabled or r.potionAlertEnabled or r.talentAlertEnabled) end,
	function() CreateCAFrame(); return caFrame end,
	function() local s = R().combatAlertTextSize or 22; return s * 7, s + 14 end,
	"combatAlertPos", CA_DEFAULT_POS, ApplyCAFrame, true))
AddUnlock(PosElement("EUI_TargetDistance", "Target Distance", 722,
	function() return not R().targetDistanceEnabled end,
	function() CreateDistFrame(); DistTick(); return distFrame end,
	function() local s = R().targetDistanceTextSize or 18; return s * 5, s + 10 end,
	"targetDistancePos", TD_DEFAULT_POS, function() ApplyDistFrame(); DistTick() end, true))

Q.unlockElements = unlockElements
function Q.RegisterUnlock(list)
	if not ns.RegisterUnlockElements or not ns.MakeUnlockElement then return end
	local made = {}
	for _, def in ipairs(list) do made[#made + 1] = ns.MakeUnlockElement(def) end
	ns:RegisterUnlockElements(made, addonName)
end
Q.RegisterUnlock(unlockElements)

---------------------------------------------------------------------------
-- Apply
---------------------------------------------------------------------------
tinsert(Q.applies, function()
	Q.ApplyFPSDisplay()
	Q.ApplyFPSBind()
	Q.ApplyDurability()
	Q.ApplyRightClick()
	Q.ApplyRested()
	Q.ApplyTargetDistance()
	Q.ApplyCrosshair()
	Q.ApplyCombatAlert()
	Q.ApplyPotionAlert()
	Q.ApplyTalentAlert()
	Q.ApplyGroupDeaths()
	Q.ApplyTransforms()
end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
	self:UnregisterAllEvents()
	AppendSharedMediaSounds()
	PrimeRangeItems()
	-- Unit Frames may build the player frame after this login handler.
	Q.After(1, Q.ApplyRested)
end)
