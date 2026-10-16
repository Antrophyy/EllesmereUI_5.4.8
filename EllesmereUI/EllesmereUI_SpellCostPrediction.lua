-- Spell Cost Prediction (retail EllesmereUI_SpellCostPrediction.lua, the
-- WoW Forever engine): while the player casts a spell with a cast time, the
-- mana it will spend is drawn on a power bar in a lighter color, at the fill's
-- leading edge and running back over the fill.
-- 5.4.8: GetSpellInfo returns the cost (4th) and power type (6th); there is
-- no SetClipsChildren, so the segment is a texture sized to the cost (never
-- longer than the current fill) instead of a clipped StatusBar.
-- Hosts ("uf" Unit Frames player power bar, "erb" Resource Bars power bar)
-- Attach their StatusBar while their option is on and Detach it otherwise.
-- cb = { PowerType(bar) -> power type index, Color(bar) -> r, g, b, a }.

local ns = EllesmereUI

local MANA = 0
local EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }

local SCP = {}
ns.SpellCostPrediction = SCP

local hosts = {} -- key -> host record while attached
local built = {} -- bar -> host record
local ev
local listening = false
local castLine, castCost

-- Custom color, else Blizzard's light blue mana prediction tint.
function SCP.Color(s)
	local c = s and s.powerCostColor
	if c then
		return c.r or 0.4, c.g or 0.7, c.b or 1
	end
	return 0.40, 0.70, 1
end

local function Draw(h)
	local bar, cb = h.bar, h.cb
	local seg = h.seg
	local pfill = bar:GetStatusBarTexture()
	local maxP = UnitPowerMax("player", MANA)
	if not (castCost and castCost > 0 and pfill and maxP and maxP > 0 and cb.PowerType(bar) == MANA) then
		if seg then
			seg:Hide()
		end
		return
	end
	if not seg then
		local holder = CreateFrame("Frame", nil, bar)
		holder:SetAllPoints(bar)
		seg = holder:CreateTexture(nil, "ARTWORK")
		h.seg, h.holder = seg, holder
	end
	h.holder:SetFrameLevel(bar:GetFrameLevel() + 1)
	seg:SetTexture(pfill:GetTexture() or "Interface\\Buttons\\WHITE8X8")
	local cur = UnitPower("player", MANA) or 0
	local frac = math.min(castCost, cur) / maxP
	local vert = bar:GetOrientation() == "VERTICAL"
	local rev = bar.GetReverseFill and bar:GetReverseFill() and true or false
	seg:ClearAllPoints()
	if vert then
		local len = bar:GetHeight() * frac
		if rev then
			seg:SetPoint("BOTTOMLEFT", pfill, "BOTTOMLEFT", 0, 0)
			seg:SetPoint("BOTTOMRIGHT", pfill, "BOTTOMRIGHT", 0, 0)
		else
			seg:SetPoint("TOPLEFT", pfill, "TOPLEFT", 0, 0)
			seg:SetPoint("TOPRIGHT", pfill, "TOPRIGHT", 0, 0)
		end
		seg:SetHeight(math.max(0.001, len))
	else
		local len = bar:GetWidth() * frac
		if rev then
			seg:SetPoint("TOPLEFT", pfill, "TOPLEFT", 0, 0)
			seg:SetPoint("BOTTOMLEFT", pfill, "BOTTOMLEFT", 0, 0)
		else
			seg:SetPoint("TOPRIGHT", pfill, "TOPRIGHT", 0, 0)
			seg:SetPoint("BOTTOMRIGHT", pfill, "BOTTOMRIGHT", 0, 0)
		end
		seg:SetWidth(math.max(0.001, len))
	end
	local r, g, b, a = cb.Color(bar)
	seg:SetVertexColor(r, g, b, a or 1)
	seg:SetShown(frac > 0)
end

local function HideAll()
	for _, h in pairs(hosts) do
		if h.seg then
			h.seg:Hide()
		end
	end
end

local function DrawAll()
	for _, h in pairs(hosts) do
		if h.bar:IsVisible() then
			Draw(h)
		end
	end
end

local function OnEvent(_, event, unit, _, _, lineID, spellID)
	if event == "UNIT_SPELLCAST_START" then
		local _, _, _, cost, _, powerType = GetSpellInfo(spellID)
		castLine = lineID
		castCost = (powerType == MANA and type(cost) == "number") and cost or nil
		if castCost then
			ev:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
			ev:RegisterUnitEvent("UNIT_MAXPOWER", "player")
		end
		DrawAll()
		return
	elseif event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER" then
		if castLine then
			DrawAll()
		end
		return
	end
	-- STOP / FAILED / INTERRUPTED of the cast in flight (instants cast during
	-- it have other line IDs).
	if castLine and lineID ~= castLine then
		return
	end
	castLine, castCost = nil, nil
	ev:UnregisterEvent("UNIT_POWER_FREQUENT")
	ev:UnregisterEvent("UNIT_MAXPOWER")
	HideAll()
end

local function Listen()
	local on = false
	for _, h in pairs(hosts) do
		if h.bar:IsVisible() then
			on = true
			break
		end
	end
	if on == listening then
		return
	end
	listening = on
	if on then
		for i = 1, #EVENTS do
			ev:RegisterUnitEvent(EVENTS[i], "player")
		end
	else
		ev:UnregisterAllEvents()
		castLine, castCost = nil, nil
		HideAll()
	end
end

local function OnHostShow(bar)
	local h = built[bar]
	if hosts[h.key] == h then
		Listen()
		if castLine then
			Draw(h)
		end
	end
end

local function OnHostHide(bar)
	local h = built[bar]
	if hosts[h.key] == h then
		Listen()
	end
end

local function OnHostSize(bar)
	local h = built[bar]
	if hosts[h.key] == h and castLine then
		Draw(h)
	end
end

function SCP.Attach(key, bar, cb)
	local h = built[bar]
	if not h then
		if not ev then
			ev = CreateFrame("Frame")
			ev:SetScript("OnEvent", OnEvent)
		end
		h = { bar = bar }
		built[bar] = h
		bar:HookScript("OnShow", OnHostShow)
		bar:HookScript("OnHide", OnHostHide)
		bar:HookScript("OnSizeChanged", OnHostSize)
	end
	local old = hosts[key]
	if old and old ~= h and old.seg then
		old.seg:Hide()
	end
	h.cb, h.key = cb, key
	hosts[key] = h
	Listen()
	if castLine and bar:IsVisible() then
		Draw(h)
	end
end

function SCP.Detach(key)
	local h = hosts[key]
	if not h then
		return
	end
	hosts[key] = nil
	if h.seg then
		h.seg:Hide()
	end
	Listen()
end
