-------------------------------------------------------------------------------
--  EUI_ResourceBars_SwingTimer.lua  (5.4.8 port of the retail Swing Timer)
--
--  One row per weapon that can swing: Main Hand, Off Hand, Ranged. Retail
--  reads the client's C_SwingTimer; 5.4.8 has none, so a swing is timed from
--  the combat log (SWING_DAMAGE / SWING_MISSED by the player, off hand by the
--  isOffHand flag) with UnitAttackSpeed, and ranged from Auto Shot casts with
--  UnitRangedDamage. Parry haste and swing resets are not predicted.
--  Settings (profile.swingTimer): enabled, width, height, spacing,
--  combineHands (one row, main hand), showTime, showLabel, hideWhenIdle,
--  textSize, mhColor / ohColor / rangedColor, bgColor, unlockPos, showSpark,
--  sparkWidth, sparkOverhang, mhSparkColor / ohSparkColor / rangedSparkColor.
-------------------------------------------------------------------------------
local addonName, P = ...
local ns = P.ns
local ERB = P.ERB

local format, max, GetTime = string.format, math.max, GetTime

local ROWS = { "mh", "oh", "ranged" }
local LABELS = { mh = "Main Hand", oh = "Off Hand", ranged = "Ranged" }
local DEFAULT_COLORS = {
	mh = { r = 0.9, g = 0.75, b = 0.3 },
	oh = { r = 0.7, g = 0.55, b = 0.25 },
	ranged = { r = 0.4, g = 0.8, b = 0.4 },
}
local AUTO_SHOT = 75
local SPARK_TEX = P.MEDIA .. "cast_spark"

local holder
local rows = {}
local swing = { mh = {}, oh = {}, ranged = {} }

local function Cfg()
	local p = P.Profile()
	return p and p.swingTimer
end

local function On()
	local c = Cfg()
	return c and c.enabled == true
end
ERB.SwingTimerActive = On

-- Which rows this character has: main hand always, off hand with a one-hand
-- weapon there, ranged for hunters.
local function HasRow(key)
	if key == "mh" then return true end
	local c = Cfg()
	if key == "oh" then
		if c.combineHands then return false end
		local _, oh = UnitAttackSpeed and UnitAttackSpeed("player")
		return oh ~= nil and oh > 0
	end
	return select(2, UnitClass("player")) == "HUNTER"
end

local function Row(key)
	local r = rows[key]
	if r then return r end
	r = CreateFrame("Frame", nil, holder)
	r.bg = r:CreateTexture(nil, "BACKGROUND")
	r.bg:SetAllPoints()
	r.sb = CreateFrame("StatusBar", nil, r)
	r.sb:SetPoint("TOPLEFT", 1, -1)
	r.sb:SetPoint("BOTTOMRIGHT", -1, 1)
	r.sb:SetStatusBarTexture(P.WHITE)
	r.sb:SetMinMaxValues(0, 1)
	r.time = P.NewText(r.sb, 10)
	r.time:SetPoint("RIGHT", r.sb, "RIGHT", -2, 0)
	r.label = P.NewText(r.sb, 10)
	r.label:SetPoint("LEFT", r.sb, "LEFT", 2, 0)
	-- Leading-edge spark (Show Spark), on the fill's moving edge.
	r.sparkFrame = CreateFrame("Frame", nil, r)
	r.sparkFrame:SetAllPoints(r.sb)
	r.sparkFrame:SetFrameLevel(r.sb:GetFrameLevel() + 2)
	r.spark = r.sparkFrame:CreateTexture(nil, "OVERLAY")
	r.spark:SetTexture(SPARK_TEX)
	r.spark:SetBlendMode("ADD")
	r.spark:SetPoint("CENTER", r.sb:GetStatusBarTexture(), "RIGHT", 0, 0)
	r.spark:Hide()
	rows[key] = r
	return r
end

local function Paint()
	if not holder then return end
	local c = Cfg()
	local now = GetTime()
	local anyRunning = false
	for _, key in ipairs(ROWS) do
		local r = rows[key]
		if r and r.active then
			local s = swing[key]
			local left = (s.finish or 0) - now
			if left > 0 and (s.dur or 0) > 0 then
				anyRunning = true
				r.sb:SetValue(1 - left / s.dur)
				r.time:SetText(c.showTime ~= false and format("%.1f", left) or "")
				r.spark:SetShown(c.showSpark == true)
			else
				r.sb:SetValue(ERB.unlockActive and 0.6 or 0)
				r.time:SetText("")
				r.spark:SetShown(c.showSpark == true and ERB.unlockActive)
			end
		end
	end
	local show = ERB.unlockActive or not c.hideWhenIdle or anyRunning
	holder:SetAlpha(show and 1 or 0)
	if not anyRunning and not ERB.unlockActive then
		holder:SetScript("OnUpdate", nil)
	end
end

local function Start(key, dur)
	if not dur or dur <= 0 then return end
	local s = swing[key]
	s.dur, s.finish = dur, GetTime() + dur
	if holder and holder:IsShown() then holder:SetScript("OnUpdate", Paint) end
end

function ERB.LayoutSwingTimer()
	local c = Cfg()
	if not c then return end
	if not On() then
		if holder then holder:Hide() end
		return
	end
	if not holder then
		holder = CreateFrame("Frame", "ERB_SwingTimerFrame", UIParent)
		holder:SetClampedToScreen(true)
		ERB.swingFrame = holder
	end
	local w, h, sp = c.width or 214, c.height or 6, c.spacing or 2
	local n = 0
	for _, key in ipairs(ROWS) do
		local r = Row(key)
		if HasRow(key) then
			r.active = true
			r:ClearAllPoints()
			r:SetSize(w, h + 2)
			r:SetPoint("TOP", holder, "TOP", 0, -n * (h + 2 + sp))
			local col = c[key .. "Color"] or DEFAULT_COLORS[key]
			r.sb:SetStatusBarTexture(ERB.BarTexture(P.Profile(), "primary") or P.WHITE)
			r.sb:SetStatusBarColor(col.r, col.g, col.b, 1)
			local bg = c.bgColor or { r = 0, g = 0, b = 0, a = 0.6 }
			r.bg:SetTexture(bg.r, bg.g, bg.b, bg.a or 0.6)
			P.SetFont(r.time, c.textSize or 10)
			P.SetFont(r.label, c.textSize or 10)
			r.label:SetText(c.showLabel and LABELS[key] or "")
			-- Spark: width, overhang past the bar's top and bottom, and its own
			-- colour per weapon (unset: white).
			local over = c.sparkOverhang or 0
			r.spark:SetSize(c.sparkWidth or 8, h + 2 * over)
			local sc = c[key .. "SparkColor"]
			if sc then
				r.spark:SetVertexColor(sc.r or 1, sc.g or 1, sc.b or 1, sc.a or 1)
			else
				r.spark:SetVertexColor(1, 1, 1, 1)
			end
			r:Show()
			n = n + 1
		else
			r.active = nil
			r:Hide()
		end
	end
	holder:SetSize(w, max(1, n * (h + 2) + max(0, n - 1) * sp))
	holder:SetFrameStrata("MEDIUM")
	P.UnlockPlace(holder, "ERB_SwingTimer", function()
		holder:ClearAllPoints()
		local pos = c.unlockPos
		if pos and pos.point then
			holder:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, P.Snap(pos.x or 0, holder), P.Snap(pos.y or 0, holder))
		else
			holder:SetPoint("CENTER", UIParent, "CENTER", 0, -300)
		end
	end)
	holder:Show()
	if ERB.unlockActive then holder:SetScript("OnUpdate", Paint) end
	Paint()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
events:RegisterEvent("UNIT_INVENTORY_CHANGED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
local playerGUID
events:SetScript("OnEvent", function(_, event, ...)
	if not ERB.db or not On() then return end
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		local _, sub, _, src = ...
		if src ~= (playerGUID or UnitGUID("player")) then return end
		local offHand
		if sub == "SWING_DAMAGE" then
			offHand = select(21, ...)
		elseif sub == "SWING_MISSED" then
			offHand = select(13, ...)
		else
			return
		end
		local mh, oh = UnitAttackSpeed("player")
		if offHand and not Cfg().combineHands then
			Start("oh", oh)
		elseif not offHand then
			Start("mh", mh)
		end
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		local _, _, _, _, spellID = ...
		if spellID == AUTO_SHOT then
			Start("ranged", (UnitRangedDamage("player")))
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		playerGUID = UnitGUID("player")
		ERB.LayoutSwingTimer()
	elseif event == "UNIT_INVENTORY_CHANGED" then
		if (...) == "player" then ERB.LayoutSwingTimer() end
	else
		Paint()
	end
end)

P.OnApply(function() ERB.LayoutSwingTimer() end)

function ERB.RegisterSwingUnlock()
	if not ns.RegisterUnlockElements then return end
	ns:RegisterUnlockElements({
		P.UnlockElement("ERB_SwingTimer", "Swing Timer", 6, function() return holder end,
			function() return Cfg() end, On),
	}, "EllesmereUIResourceBars")
end
