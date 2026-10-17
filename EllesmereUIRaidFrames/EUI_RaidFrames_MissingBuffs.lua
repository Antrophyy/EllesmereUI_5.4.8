-------------------------------------------------------------------------------
--  EUI_RaidFrames_MissingBuffs.lua
--  Missing Buffs indicator (retail showMissingBuffs, built for WoW Forever's
--  class buffs) on the Mists of Pandaria raid buffs: on each raid and party
--  button, the icon of every raid buff category the member lacks that the
--  PLAYER can provide. A category counts as present when the member has any
--  buff of it, from any class (Stats: Mark of the Wild, Blessing of Kings,
--  Legacy of the Emperor, Embrace of the Shale Spider).
--  Settings (Indicators section): showMissingBuffs, missingBuffsSize,
--  missingBuffsPosition, missingBuffsOffsetX/Y, missingBuffsGlow,
--  missingBuffsGlowColor, missingBuffsOnlyOutOfCombat.
--  Off = no events, no icons.
-------------------------------------------------------------------------------
local addonName, RF = ...

local ipairs, pairs, max = ipairs, pairs, math.max

-- Category: the spells that give it (any of them on the member = present)
-- and, first, the ones the player can cast to provide it.
local CATEGORIES = {
	{ key = "stats", label = "Stats",
	  give = { 1126, 20217, 115921 },                      -- Mark of the Wild, Blessing of Kings, Legacy of the Emperor
	  has = { 1126, 20217, 115921, 90363 } },               -- + Embrace of the Shale Spider
	{ key = "stamina", label = "Stamina",
	  give = { 21562, 469 },                                -- Power Word: Fortitude, Commanding Shout
	  has = { 21562, 469, 6307, 90364 } },                  -- + Blood Pact, Qiraji Fortitude
	{ key = "ap", label = "Attack Power",
	  give = { 6673, 57330 },                               -- Battle Shout, Horn of Winter
	  has = { 6673, 57330, 19506 } },                       -- + Trueshot Aura
	{ key = "sp", label = "Spell Power",
	  give = { 1459, 61316, 109773 },                       -- Arcane / Dalaran Brilliance, Dark Intent
	  has = { 1459, 61316, 109773, 77747, 126309 } },       -- + Burning Wrath, Still Water
	{ key = "crit", label = "Critical Strike",
	  give = { 116781 },                                    -- Legacy of the White Tiger (Brilliance is above)
	  has = { 116781, 1459, 61316, 24932, 24604, 90309, 126309 } },
	{ key = "mastery", label = "Mastery",
	  give = { 19740 },                                     -- Blessing of Might
	  has = { 19740, 116956, 93435, 128997 } },             -- + Grace of Air, Roar of Courage, Spirit Beast Blessing
}
RF.MISSING_BUFF_CATEGORIES = CATEGORIES

local names = {}   -- category index -> { [spell name] = true }
local function Names(i)
	local t = names[i]
	if t then return t end
	t = {}
	for _, id in ipairs(CATEGORIES[i].has) do
		local n = GetSpellInfo(id)
		if n then t[n] = true end
	end
	names[i] = t
	return t
end

-- The categories the player provides: { index = spellID to show }.
local provided, providedValid = {}, false
local function Provided()
	if providedValid then return provided end
	wipe(provided)
	for i, cat in ipairs(CATEGORIES) do
		for _, id in ipairs(cat.give) do
			if IsSpellKnown(id) then provided[i] = id; break end
		end
	end
	providedValid = true
	return provided
end

local function Settings(btn)
	return RF.SettingsFor and RF.SettingsFor(btn) or {}
end

local function Icons(btn, d)
	local list = d.missingBuffIcons
	if not list then
		list = {}
		d.missingBuffIcons = list
	end
	return list
end

local function Icon(btn, d, k)
	local list = Icons(btn, d)
	local f = list[k]
	if f then return f end
	f = CreateFrame("Frame", nil, d.markerCarrier or btn)
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetTexture(0, 0, 0, 1)
	f.bg:SetPoint("TOPLEFT", -1, 1)
	f.bg:SetPoint("BOTTOMRIGHT", 1, -1)
	f.tex = f:CreateTexture(nil, "ARTWORK")
	f.tex:SetAllPoints()
	f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f:Hide()
	list[k] = f
	return f
end

local GROW = { TOP = "RIGHT", BOTTOM = "RIGHT", CENTER = "RIGHT", LEFT = "RIGHT", RIGHT = "LEFT",
	TOPLEFT = "RIGHT", BOTTOMLEFT = "RIGHT", TOPRIGHT = "LEFT", BOTTOMRIGHT = "LEFT" }

local function HideAll(d)
	for _, f in ipairs(d.missingBuffIcons or {}) do
		if RF.AuraShowGlow then RF.AuraShowGlow(f, false) end
		f:Hide()
	end
end

function RF.MissingBuffsUpdate(btn)
	local d = btn and btn.rf
	if not d then return end
	local s = Settings(btn)
	if not s.showMissingBuffs or (s.missingBuffsOnlyOutOfCombat ~= false and InCombatLockdown() and not btn.rfPreview) then
		if d.missingBuffIcons then HideAll(d) end
		return
	end
	local unit = RF.UnitOf(btn)
	local prov = Provided()
	local show = {}
	if btn.rfPreview then
		for i in ipairs(CATEGORIES) do
			if prov[i] then show[#show + 1] = prov[i] end
		end
		if #show == 0 then show[1] = CATEGORIES[1].give[1] end
	elseif unit and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit) and UnitIsVisible(unit) then
		local present = {}
		for j = 1, 40 do
			local n = UnitBuff(unit, j)
			if not n then break end
			present[n] = true
		end
		for i in ipairs(CATEGORIES) do
			if prov[i] then
				local have = false
				for n in pairs(Names(i)) do
					if present[n] then have = true; break end
				end
				if not have then show[#show + 1] = prov[i] end
			end
		end
	end
	local size = max(6, s.missingBuffsSize or 16)
	local pos = (s.missingBuffsPosition or "top"):upper()
	local grow = GROW[pos] or "RIGHT"
	local host = d.health or btn
	local total = #show
	local gc = s.missingBuffsGlowColor or { r = 1, g = 0.82, b = 0 }
	for k, id in ipairs(show) do
		local f = Icon(btn, d, k)
		f:SetSize(size, size)
		local _, _, icon = GetSpellInfo(id)
		f.tex:SetTexture(icon)
		local step = (k - 1) * (size + 2)
		if pos == "TOP" or pos == "BOTTOM" or pos == "CENTER" then
			step = step - (total - 1) * (size + 2) / 2
		end
		f:ClearAllPoints()
		f:SetPoint(pos, host, pos, (s.missingBuffsOffsetX or 0) + (grow == "LEFT" and -step or step), s.missingBuffsOffsetY or 0)
		f:Show()
		if RF.AuraShowGlow then RF.AuraShowGlow(f, s.missingBuffsGlow == true, gc.r, gc.g, gc.b, 2) end
	end
	local list = d.missingBuffIcons
	if list then
		for k = total + 1, #list do
			if RF.AuraShowGlow then RF.AuraShowGlow(list[k], false) end
			list[k]:Hide()
		end
	end
end

local function UpdateAll()
	if RF.ForEachButton then RF.ForEachButton(RF.MissingBuffsUpdate) end
end
RF.MissingBuffsUpdateAll = UpdateAll

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event, unit)
	if event == "UNIT_AURA" then
		if unit and RF.ButtonsForUnit then
			for btn in pairs(RF.ButtonsForUnit(unit)) do RF.MissingBuffsUpdate(btn) end
		end
		return
	end
	if event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
		providedValid = false
		wipe(names)
	end
	UpdateAll()
end)

-- Events only while some settings table has it on.
local function Apply()
	local p = RF.Profile and RF.Profile()
	local on = p and (p.showMissingBuffs or p.party_showMissingBuffs) and true or false
	ev:UnregisterAllEvents()
	if on then
		for _, e in ipairs({ "UNIT_AURA", "GROUP_ROSTER_UPDATE", "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE",
			"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UNIT_CONNECTION", "PLAYER_ENTERING_WORLD" }) do
			ev:RegisterEvent(e)
		end
	end
	providedValid = false
	UpdateAll()
end
RF.MissingBuffsApply = Apply

if RF.OnApply then
	RF.OnApply(Apply, 40)
end
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
	self:UnregisterAllEvents()
	Apply()
end)
