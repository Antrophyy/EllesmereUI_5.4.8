-- EllesmereUI Quality of Life for 5.4.8: Self Combat Text (retail
-- EllesmereUIQoL_SelfCombatText.lua). Damage taken, healing received, avoids
-- and combat enter/leave scroll above the player frame instead of Blizzard's
-- combat text (hidden while this is on).
-- 5.4.8: the numbers come from the combat log (retail reads secret values
-- from C_CombatText); messages move on an OnUpdate (5.4.8 Path animations
-- have no SetCurveType and Alpha has no SetFromAlpha).
-- Settings: EllesmereUIQoLDB.selfCombatText (retail profile key), defaults below.

local addonName = ...
local ns = EllesmereUI
local Q = ns.QoL

local POOL_SIZE = 12
local FADE_FRAC = 0.3
local UNLOCK_KEY = "EUI_SelfCombatText"
local BOX_W, BOX_H = 200, 30
local LINE_H, LINE_GAP = 1.15, 2

local DEFAULTS = {
	enabled = false,
	size = 16, critScale = 1.5, rise = 80, duration = 1.9,
	stagger = true,
	anim = "straight",     -- straight | fountain | static
	direction = "up",      -- up | down
	font = "__combat",     -- __combat (combat text font), __global (QoL font) or a font name
	outline = "OUTLINE",   -- NONE | OUTLINE | THICKOUTLINE
	shadow = false,
	abbreviate = false,
	damage = true, heal = true, avoid = true, combat = true,
	damageColor = { r = 1, g = 0.1, b = 0.1 },
	healColor = { r = 0.1, g = 1, b = 0.1 },
	avoidColor = { r = 1, g = 1, b = 1 },
	combatColor = { r = 1, g = 0.1, b = 0.1 },
}

-- Fountain arc: quarter circle, x toward the side, y along the scroll.
local ARC = { { 0.134, 0.5 }, { 0.5, 0.866 }, { 1, 1 } }

local anchor, ev
local pool = {}
local nextIdx = 0
local enabled = false
local xDir = 1
local S = { fontVer = 0 }

local function Get(k)
	local t = Q.DB().selfCombatText
	local v = nil
	if type(t) == "table" then v = t[k] end
	if v == nil then return DEFAULTS[k] end
	return v
end
local function Settings()
	local q = Q.DB()
	if type(q.selfCombatText) ~= "table" then q.selfCombatText = {} end
	return q.selfCombatText
end

local function ReadSettings()
	local key = Get("font")
	if key == "__global" then
		S.font = Q.Font()
	elseif type(key) == "string" and key:find("[\\/]") then
		S.font = key
	elseif key ~= "__combat" and ns.ResolveFontName then
		S.font = ns.ResolveFontName(key)
	else
		local f = _G.CombatTextFont
		S.font = (f and f:GetFont()) or DAMAGE_TEXT_FONT or STANDARD_TEXT_FONT
	end
	local outline = Get("outline")
	S.flags = (outline == "OUTLINE" or outline == "THICKOUTLINE") and outline or ""
	S.shadow = Get("shadow") == true
	S.size = Get("size")
	S.critSize = S.size * Get("critScale")
	S.fontVer = S.fontVer + 1
	S.anim, S.rise, S.duration = Get("anim"), Get("rise"), Get("duration")
	S.dy = Get("direction") == "down" and -S.rise or S.rise
	S.stagger, S.abbreviate = Get("stagger"), Get("abbreviate")
	S.damage, S.heal, S.avoid, S.combat = Get("damage"), Get("heal"), Get("avoid"), Get("combat")
	S.damageColor, S.healColor = Get("damageColor"), Get("healColor")
	S.avoidColor, S.combatColor = Get("avoidColor"), Get("combatColor")
end

---------------------------------------------------------------------------
-- Position (Unlock Mode once saved, else above the player frame)
---------------------------------------------------------------------------
local function ApplyPos()
	if not anchor then return end
	local pos = Get("pos")
	anchor:ClearAllPoints()
	if type(pos) == "table" and pos.point then
		anchor:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
		return
	end
	local pf = _G.EllesmereUIUnitFrames_Player
	if pf then
		anchor:SetPoint("BOTTOM", pf, "TOP", 0, 10)
	else
		anchor:SetPoint("BOTTOM", UIParent, "CENTER", 0, -140)
	end
end

---------------------------------------------------------------------------
-- Messages
---------------------------------------------------------------------------
-- How far along the scroll a message is (fraction of the distance) and its
-- side offset (fountain).
local function Travel(f)
	local mode = S.anim
	if mode == "static" then return 0, 0 end
	if f > 1 then f = 1 end
	if mode ~= "fountain" then return f, 0 end
	local seg = f * #ARC
	local i = math.floor(seg)
	if i >= #ARC then return ARC[#ARC][2], ARC[#ARC][1] end
	local fromY = i > 0 and ARC[i][2] or 0
	local fromX = i > 0 and ARC[i][1] or 0
	local t = seg - i
	return fromY + (ARC[i + 1][2] - fromY) * t, fromX + (ARC[i + 1][1] - fromX) * t
end

local function OnMessageUpdate(fs)
	local f = (GetTime() - fs.t0) / S.duration
	if f >= 1 then
		fs:Hide()
		fs.live = nil
		fs.driver:Hide()
		return
	end
	local y, x = Travel(f)
	fs:ClearAllPoints()
	fs:SetPoint("BOTTOM", anchor, "BOTTOM", fs.side * x * S.rise, fs.y0 + S.dy * y)
	local fadeStart = 1 - FADE_FRAC
	fs:SetAlpha(f > fadeStart and (1 - (f - fadeStart) / FADE_FRAC) or 1)
end

local function Build()
	anchor = CreateFrame("Frame", nil, UIParent)
	anchor:SetSize(BOX_W, BOX_H)
	anchor:SetFrameStrata("HIGH")
	for i = 1, POOL_SIZE do
		local fs = anchor:CreateFontString(nil, "OVERLAY")
		fs:Hide()
		fs.side = 0
		local driver = CreateFrame("Frame", nil, anchor)
		driver:Hide()
		driver:SetScript("OnUpdate", function() OnMessageUpdate(fs) end)
		fs.driver = driver
		pool[i] = fs
	end
	ev = CreateFrame("Frame")
	ApplyPos()
end

-- Stagger Hits: push the live messages of the lane on until the newest one
-- has room at the anchor.
local function ClearLane(lane, h)
	local now, dy = GetTime(), S.dy
	local s = dy < 0 and -1 or 1
	local nearD
	for i = 1, POOL_SIZE do
		local m = pool[i]
		if m.live and m.lane == lane then
			local d = s * (m.y0 + dy * (Travel((now - m.t0) / S.duration)))
			if not nearD or d < nearD then nearD = d end
		end
	end
	if not nearD then return end
	local need = h + LINE_GAP - nearD
	if need <= 0 then return end
	for i = 1, POOL_SIZE do
		local m = pool[i]
		if m.live and m.lane == lane then
			m.y0 = m.y0 + s * need
		end
	end
end

local function Emit(text, c, crit)
	nextIdx = nextIdx % POOL_SIZE + 1
	local fs = pool[nextIdx]
	fs.live = nil
	local lane = 0
	fs.side = 0
	if S.anim == "fountain" then
		xDir = -xDir
		lane = xDir
		fs.side = xDir
	end
	local h = (crit and S.critSize or S.size) * LINE_H
	if S.stagger then ClearLane(lane, h) end
	fs.t0, fs.y0, fs.lane, fs.live = GetTime(), 0, lane, true
	local kind = crit and 2 or 1
	if fs.fontVer ~= S.fontVer or fs.fontKind ~= kind then
		fs.fontVer, fs.fontKind = S.fontVer, kind
		fs:SetFont(S.font, crit and S.critSize or S.size, S.flags)
		if S.shadow then
			fs:SetShadowColor(0, 0, 0, 1)
			fs:SetShadowOffset(1, -1)
		else
			fs:SetShadowOffset(0, 0)
		end
	end
	fs:SetTextColor(c.r, c.g, c.b)
	fs:SetText(text)
	fs:SetAlpha(1)
	fs:ClearAllPoints()
	fs:SetPoint("BOTTOM", anchor, "BOTTOM", 0, 0)
	fs:Show()
	fs.driver:Show()
end

local function FormatAmount(n)
	if S.abbreviate then
		if n >= 1000000 then return ("%.1fm"):format(n / 1000000) end
		if n >= 1000 then return ("%.0fk"):format(n / 1000) end
		return tostring(n)
	end
	return BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n)
end

-- Combat log: what hits the player (or the vehicle the player drives).
local function MyGUID()
	return UnitGUID(UnitHasVehicleUI("player") and "vehicle" or "player")
end
local DAMAGE_EVENTS = {
	SWING_DAMAGE = 12, RANGE_DAMAGE = 15, SPELL_DAMAGE = 15, SPELL_PERIODIC_DAMAGE = 15,
	ENVIRONMENTAL_DAMAGE = 13, DAMAGE_SHIELD = 15, DAMAGE_SPLIT = 15,
}
local HEAL_EVENTS = { SPELL_HEAL = true, SPELL_PERIODIC_HEAL = true }
local MISS_EVENTS = { SWING_MISSED = 12, RANGE_MISSED = 15, SPELL_MISSED = 15, SPELL_PERIODIC_MISSED = 15 }

local function OnCombatLog(...)
	local event = select(2, ...)
	local dst = select(8, ...)
	if dst ~= MyGUID() then return end
	local idx = DAMAGE_EVENTS[event]
	if idx then
		if not S.damage then return end
		-- amount, overkill, school, resisted, blocked, absorbed, critical
		local amount = select(idx, ...)
		local crit = select(idx + 6, ...)
		if amount and amount > 0 then
			Emit("-" .. FormatAmount(amount), S.damageColor, crit and true or false)
		end
		return
	end
	if HEAL_EVENTS[event] then
		if not S.heal then return end
		-- spellId, spellName, school, amount, overhealing, absorbed, critical
		local amount, over = select(15, ...), select(16, ...)
		local crit = select(18, ...)
		if amount and amount - (over or 0) > 0 then
			Emit("+" .. FormatAmount(amount - (over or 0)), S.healColor, crit and true or false)
		end
		return
	end
	idx = MISS_EVENTS[event]
	if idx and S.avoid then
		local missType = select(idx, ...)
		local label = missType and _G["COMBAT_TEXT_" .. missType]
		if label then Emit(label, S.avoidColor, false) end
	end
end

local function OnEvent(_, event, ...)
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		OnCombatLog(...)
	elseif event == "PLAYER_REGEN_DISABLED" then
		Emit(ENTERING_COMBAT or "+Combat", S.combatColor, false)
	elseif event == "PLAYER_REGEN_ENABLED" then
		Emit(LEAVING_COMBAT or "-Combat", S.combatColor, false)
	elseif event == "ADDON_LOADED" then
		if ... == "Blizzard_CombatText" and _G.CombatText then
			_G.CombatText:Hide()
			ev:UnregisterEvent("ADDON_LOADED")
		end
	end
end

local function UpdateEvents()
	if S.damage or S.heal or S.avoid then
		ev:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	else
		ev:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	end
	if S.combat then
		ev:RegisterEvent("PLAYER_REGEN_DISABLED")
		ev:RegisterEvent("PLAYER_REGEN_ENABLED")
	else
		ev:UnregisterEvent("PLAYER_REGEN_DISABLED")
		ev:UnregisterEvent("PLAYER_REGEN_ENABLED")
	end
end

local function Refresh()
	local want = Get("enabled") == true
	if want == enabled then
		if want then
			ReadSettings()
			UpdateEvents()
			ApplyPos()
		end
		return
	end
	enabled = want
	if want then
		if not anchor then Build() end
		ReadSettings()
		anchor:Show()
		ev:SetScript("OnEvent", OnEvent)
		UpdateEvents()
		ApplyPos()
		if _G.CombatText then
			_G.CombatText:Hide()
		else
			ev:RegisterEvent("ADDON_LOADED")
		end
	else
		ev:UnregisterAllEvents()
		anchor:Hide()
		if _G.CombatText then _G.CombatText:Show() end
	end
end

Q.SCT_Refresh = Refresh
Q.SCT_Get = Get
Q.SCT_DEFAULTS = DEFAULTS
function Q.SCT_Set(k, v)
	Settings()[k] = v
	Refresh()
end
function Q.SCT_Reset()
	Q.DB().selfCombatText = nil
	local root = Q.R()
	if type(root.unlockAnchors) == "table" then root.unlockAnchors[UNLOCK_KEY] = nil end
	Refresh()
	ApplyPos()
end

tinsert(Q.applies, Refresh)

Q.RegisterUnlock({ {
	key = UNLOCK_KEY, label = "Self Combat Text", group = "Quality of Life", order = 730,
	noResize = true, noAnchorTarget = true,
	isHidden = function() return Get("enabled") ~= true end,
	getFrame = function()
		if not anchor then Build() end
		return anchor
	end,
	getSize = function() return BOX_W, BOX_H end,
	savePos = function(_, point, relPoint, x, y)
		if not point then return end
		Settings().pos = { point = point, relPoint = relPoint or point, x = x, y = y }
		if not ns._unlockActive then ApplyPos() end
	end,
	loadPos = function()
		local pos = Get("pos")
		if type(pos) ~= "table" or not pos.point then return nil end
		return { point = pos.point, relPoint = pos.relPoint or pos.point, x = pos.x, y = pos.y }
	end,
	clearPos = function()
		local t = Q.DB().selfCombatText
		if type(t) == "table" then t.pos = nil end
		ApplyPos()
	end,
	applyPos = ApplyPos,
} })
