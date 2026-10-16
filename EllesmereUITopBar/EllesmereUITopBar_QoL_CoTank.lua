-------------------------------------------------------------------------------
--  EllesmereUITopBar_QoL_CoTank.lua (5.4.8 port of retail
--  NaowhUI_QoL_CoTank.lua): health bars for the OTHER tanks. Raid only, tank
--  spec, another tank present. Click a bar to target that tank.
--
--  5.4.8 changes:
--    * Values are plain (no secret values), so the name cap and class colour
--      always work.
--    * Tank spec = GetSpecializationRole (no PlayerUtil), else the assigned
--      group role.
--    * Retail shows only the first other tank. Here every other tank gets a
--      bar (up to MAX_BARS), stacked under (or over) the first one.
--    * A tank = assigned role TANK, or the raid's Main Tank assignment
--      (manually built 5.4.8 raids often have no roles set).
--    * Debuffs: retail renders them through EllesmereUI's AuraKit containers
--      (12.x aura engine). Here our own icon buttons read UnitAura HARMFUL:
--        "Boss & Important" = boss debuffs (isBossDebuff) and debuffs cast
--                             by a boss unit (boss1-5),
--        "All Debuffs"      = every debuff,
--        "Dispellable by You" = HARMFUL|RAID.
--      Time left is our own text (no Blizzard countdown numbers on 5.4.8).
--      The dispel-type border is coloured from the debuff type.
-------------------------------------------------------------------------------
local ns = EllesmereUI
local Q = ns.NaowhQoL
if not Q then return end

local floor, max, min = math.floor, math.max, math.min

local SECTION = "coTank"
local DEFAULTS = Q.DEFAULTS[SECTION]

local function DB() return Q.DB(SECTION) end
Q.CoTankDB = DB

local CT = {}
Q.CoTank = CT

local MAX_BARS = 4
local PREVIEW_BARS = 2

-- bars[i] = { frame, bar, bg, name, watch, unit, class, host, icons, mode }
local bars = {}
local tanks = {}      -- raid unit tokens of the other tanks, raid order
local lastW, lastH

-------------------------------------------------------------------------------
--  Roster
-------------------------------------------------------------------------------
local function IsTankUnit(unit)
	if UnitGroupRolesAssigned(unit) == "TANK" then return true end
	return GetPartyAssignment("MAINTANK", unit) and true or false
end

local function FindOtherTanks()
	wipe(tanks)
	if not IsInRaid() then return end
	for i = 1, GetNumGroupMembers() do
		local unit = "raid" .. i
		if UnitExists(unit) and not UnitIsUnit(unit, "player") and IsTankUnit(unit) then
			tanks[#tanks + 1] = unit
			if #tanks >= MAX_BARS then return end
		end
	end
end

local function IsPlayerTankSpec()
	local role = Q.SpecRole()
	if role then return role == "TANK" end
	return IsTankUnit("player")
end

-- How many bars to show, and whether they are stand-ins.
local function WantedBars(t)
	if not t.enabled then return 0, false end
	-- Both override the gating: a raid-only bar has to be placeable anywhere.
	local forced = Q.unlockActive or t.preview
	if #tanks > 0 and (forced or (IsInRaid() and IsPlayerTankSpec())) then
		return #tanks, false
	end
	if forced then return PREVIEW_BARS, true end
	return 0, false
end

-------------------------------------------------------------------------------
--  Health
-------------------------------------------------------------------------------
local function RefreshHealthValue(B)
	local unit = B.unit
	if not unit or not UnitExists(unit) then return end
	B.bar:SetMinMaxValues(0, max(1, UnitHealthMax(unit) or 1))
	B.bar:SetValue(UnitHealth(unit) or 0)
end

local UpdateDebuffs   -- forward: below

local function WatchUnit(B, unit)
	if B.unit == unit then return end
	B.unit = unit
	B.watch:UnregisterAllEvents()
	if unit then
		B.watch:RegisterUnitEvent("UNIT_HEALTH", unit)
		B.watch:RegisterUnitEvent("UNIT_MAXHEALTH", unit)
		B.watch:RegisterUnitEvent("UNIT_AURA", unit)
	end
end

local function RepushBars()
	for i = 1, #bars do
		local B = bars[i]
		if B.unit then
			RefreshHealthValue(B)
		else
			B.bar:SetMinMaxValues(0, 100)
			B.bar:SetValue(75)
		end
	end
end

-------------------------------------------------------------------------------
--  Frames (secure unit buttons: built out of combat only)
-------------------------------------------------------------------------------
local function BuildBar(i)
	if bars[i] then return true end
	if not DB().enabled then return false end
	if InCombatLockdown() then return false end
	-- Bars are built in order so each one can anchor to the one before it.
	if i > 1 and not bars[i - 1] then return false end

	local B = {}
	local frame = CreateFrame("Button", i == 1 and "NaowhUICoTankFrame" or ("NaowhUICoTankFrame" .. i),
		UIParent, "SecureUnitButtonTemplate")
	B.frame = frame
	frame:SetSize(lastW or DEFAULTS.width, lastH or DEFAULTS.height)
	frame:SetPoint("CENTER", UIParent, "CENTER", DEFAULTS.x, DEFAULTS.y)
	frame:RegisterForClicks("AnyUp")
	frame:SetAttribute("type1", "target")
	frame:Hide()

	local border = CreateFrame("Frame", nil, frame)
	border:SetPoint("TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", 1, -1)
	border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
	border:SetBackdropBorderColor(0, 0, 0, 1)

	B.bg = frame:CreateTexture(nil, "BACKGROUND")
	B.bg:SetAllPoints()
	B.bg:SetTexture(0.1, 0.1, 0.1, 0.8)

	B.bar = CreateFrame("StatusBar", nil, frame)
	B.bar:SetAllPoints()
	B.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
	B.bar:SetStatusBarColor(0, 0.8, 0.2)
	B.bar:SetMinMaxValues(0, 100)
	B.bar:SetValue(100)

	B.name = B.bar:CreateFontString(nil, "OVERLAY")
	Q.SetFont(B.name, Q.FontPath(), 12, "OUTLINE")
	B.name:SetPoint("CENTER", B.bar, "CENTER", 0, 0)

	B.watch = CreateFrame("Frame")
	B.watch:SetScript("OnEvent", function(_, event)
		if event == "UNIT_AURA" then
			UpdateDebuffs(B)
		else
			RefreshHealthValue(B)
		end
	end)

	bars[i] = B
	return true
end

-------------------------------------------------------------------------------
--  Paint
-------------------------------------------------------------------------------
local function ClassColorOr(B, r, g, b)
	if B.class then
		local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[B.class]
		if c then return c.r, c.g, c.b end
	end
	return r, g, b
end

local function PaintName(B, name, t, allowClassColor)
	local nameText = B.name
	if not t.showName or not name then
		nameText:Hide()
		return
	end
	if t.nameFormat == "abbreviated" and t.nameLength then
		name = string.sub(name, 1, t.nameLength)
	end
	Q.SetFont(nameText, Q.FontPath(t.font), t.nameFontSize or 12, "OUTLINE")
	nameText:SetText(name)
	if allowClassColor and t.nameColorUseClassColor then
		nameText:SetTextColor(ClassColorOr(B, t.nameColorR or 1, t.nameColorG or 1, t.nameColorB or 1))
	else
		nameText:SetTextColor(t.nameColorR or 1, t.nameColorG or 1, t.nameColorB or 1)
	end
	nameText:Show()
end

local function PaintBar(B, t)
	if t.useClassColor then
		B.bar:SetStatusBarColor(ClassColorOr(B, t.healthColorR or 0, t.healthColorG or 0.8, t.healthColorB or 0.2))
	else
		B.bar:SetStatusBarColor(t.healthColorR or 0, t.healthColorG or 0.8, t.healthColorB or 0.2)
	end
	if B.unit then PaintName(B, UnitName(B.unit), t, true) else B.name:Hide() end
end

-------------------------------------------------------------------------------
--  Debuffs
-------------------------------------------------------------------------------
-- Sated / Exhaustion and similar long lockouts (retail list).
local HIDDEN_DEBUFFS = {
	[57723] = true, [57724] = true, [80354] = true, [95809] = true,
	[160455] = true, [264689] = true, [390435] = true,
}

local DEBUFF_CORNERS = {
	topleft = "TOPLEFT", top = "TOP", topright = "TOPRIGHT",
	left = "LEFT", center = "CENTER", right = "RIGHT",
	bottomleft = "BOTTOMLEFT", bottom = "BOTTOM", bottomright = "BOTTOMRIGHT",
}

-- The row's edge that meets the bar is the mirror of the bar corner.
local DEBUFF_MIRROR = {
	TOP = "BOTTOM", BOTTOM = "TOP", LEFT = "RIGHT", RIGHT = "LEFT",
	TOPLEFT = "BOTTOMLEFT", TOPRIGHT = "BOTTOMRIGHT",
	BOTTOMLEFT = "TOPLEFT", BOTTOMRIGHT = "TOPRIGHT",
	CENTER = "CENTER",
}

-- Debuff type border colours (Blizzard's DebuffTypeColor values).
local TYPE_COLOR = {
	Magic   = { 0.2, 0.6, 1 },
	Curse   = { 0.6, 0, 1 },
	Disease = { 0.6, 0.4, 0 },
	Poison  = { 0, 0.6, 0 },
}

local function DebuffFlow(t)
	local corner  = DEBUFF_CORNERS[t.debuffPosition or "top"] or "TOP"
	local grow    = t.debuffGrow or "CENTER"
	local myPoint = DEBUFF_MIRROR[corner] or "BOTTOM"
	local gH, gV = grow, "UP"
	if grow == "CENTER" then
		gH, gV = "RIGHT", myPoint:find("TOP", 1, true) and "DOWN" or "UP"
	elseif grow == "UP" or grow == "DOWN" then
		gH, gV = "RIGHT", grow
	end
	return corner, myPoint, gH, gV, grow
end

local PREVIEW_TEX = {
	"Interface\\Icons\\Spell_Shadow_ShadowWordPain",
	"Interface\\Icons\\Spell_Fire_Immolation",
	"Interface\\Icons\\Spell_Frost_FrostNova",
	"Interface\\Icons\\Spell_Nature_Earthbind",
	"Interface\\Icons\\Spell_Shadow_CurseOfSargeras",
	"Interface\\Icons\\Spell_Holy_Silence",
	"Interface\\Icons\\Ability_Poisons",
	"Interface\\Icons\\Spell_Shadow_UnholyFrenzy",
}

local MAX_ICONS = 8

local function FormatTime(left)
	if left >= 3600 then return ("%dh"):format(floor(left / 3600 + 0.5)) end
	if left >= 60 then return ("%dm"):format(floor(left / 60 + 0.5)) end
	if left >= 10 then return tostring(floor(left + 0.5)) end
	return ("%.1f"):format(left)
end

local function IconOnUpdate(self, elapsed)
	self._acc = (self._acc or 0) + elapsed
	if self._acc < 0.1 then return end
	self._acc = 0
	if not self._expires or self._expires <= 0 then
		self.dur:SetText("")
		return
	end
	local left = self._expires - GetTime()
	if left <= 0 then
		self.dur:SetText("")
	else
		self.dur:SetText(FormatTime(left))
	end
end

local function IconOnEnter(self)
	local unit = self._owner and self._owner.unit
	if not self._index or not unit then return end
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
	GameTooltip:SetUnitAura(unit, self._index, self._filter or "HARMFUL")
	GameTooltip:Show()
end

local function IconOnLeave()
	GameTooltip:Hide()
end

local function BuildIcons(B)
	if B.host then return end
	local host = CreateFrame("Frame", nil, B.frame)
	host:SetFrameLevel(B.bar:GetFrameLevel() + 5)
	host:SetSize(1, 1)
	local icons = {}
	for i = 1, MAX_ICONS do
		local b = CreateFrame("Frame", nil, host)
		b._owner = B
		b:SetFrameLevel(host:GetFrameLevel() + 1)
		b.edge = b:CreateTexture(nil, "BACKGROUND")
		b.edge:SetPoint("TOPLEFT", -1, 1)
		b.edge:SetPoint("BOTTOMRIGHT", 1, -1)
		b.edge:SetTexture(0, 0, 0, 1)
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetAllPoints()
		b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		b.cd = CreateFrame("Cooldown", nil, b)
		b.cd:SetAllPoints()
		b.cd:SetReverse(true)
		local text = CreateFrame("Frame", nil, b)
		text:SetAllPoints()
		text:SetFrameLevel(b.cd:GetFrameLevel() + 2)
		b.dur = text:CreateFontString(nil, "OVERLAY")
		Q.SetFont(b.dur, Q.FontPath(), 10, "OUTLINE")
		b.dur:SetPoint("CENTER", 0, 0)
		b.stack = text:CreateFontString(nil, "OVERLAY")
		Q.SetFont(b.stack, Q.FontPath(), 10, "OUTLINE")
		b.stack:SetPoint("BOTTOMRIGHT", 1, 1)
		b:SetScript("OnUpdate", IconOnUpdate)
		b:SetScript("OnEnter", IconOnEnter)
		b:SetScript("OnLeave", IconOnLeave)
		b:EnableMouse(false)
		b:Hide()
		icons[i] = b
	end
	host:Hide()
	B.host, B.icons = host, icons
end

-- Lays the first n icons out from the DebuffFlow answer (shared by the live
-- and the preview row).
local function LayoutIcons(B, t, n)
	local host, icons = B.host, B.icons
	local corner, myPoint, gH, gV, grow = DebuffFlow(t)
	local size, spacing = t.debuffSize or 22, t.debuffSpacing or 2
	local vertical = (grow == "UP" or grow == "DOWN")
	local run = max(1, n * size + max(0, n - 1) * spacing)
	host:ClearAllPoints()
	host:SetPoint(myPoint, B.frame, corner, t.debuffOffsetX or 0, t.debuffOffsetY or 0)
	host:SetSize(vertical and size or run, vertical and run or size)
	local path = Q.FontPath(t.font)
	for i = 1, #icons do
		local b = icons[i]
		if i > n then
			b:Hide()
		else
			local off = (i - 1) * (size + spacing)
			b:ClearAllPoints()
			b:SetSize(size, size)
			if vertical then
				local from = (gV == "DOWN") and "TOP" or "BOTTOM"
				b:SetPoint(from, host, from, 0, (gV == "DOWN") and -off or off)
			else
				local from = (gH == "LEFT") and "RIGHT" or "LEFT"
				b:SetPoint(from, host, from, (gH == "LEFT") and -off or off, 0)
			end
			Q.SetFont(b.dur, path, t.debuffDurSize or 10, "OUTLINE")
			Q.SetFont(b.stack, path, t.debuffStackSize or 10, "OUTLINE")
			b.dur:SetShown(t.debuffShowDuration ~= false)
			b:EnableMouse(t.debuffTooltips and true or false)
			b:Show()
		end
	end
end

local function Wanted(t, name, count, dispelType, caster, spellId, isBoss)
	if not name or HIDDEN_DEBUFFS[spellId or 0] then return false end
	local filter = t.debuffFilter or "important"
	if filter == "important" then
		if isBoss then return true end
		-- The caster token may be "target" / "focus" etc.: compare units.
		if type(caster) ~= "string" then return false end
		for b = 1, 5 do
			local u = "boss" .. b
			if UnitExists(u) and UnitIsUnit(caster, u) then return true end
		end
		return false
	end
	return true
end

local scratch = {}

local function CollectDebuffs(unit, t)
	wipe(scratch)
	local filter = (t.debuffFilter == "dispellable") and "HARMFUL|RAID" or "HARMFUL"
	local cap = min(MAX_ICONS, t.debuffCap or 3)
	for i = 1, 40 do
		local name, _, icon, count, dispelType, duration, expires, caster, _, _, spellId, _, isBoss = UnitAura(unit, i, filter)
		if not name then break end
		if Wanted(t, name, count, dispelType, caster, spellId, isBoss) then
			scratch[#scratch + 1] = {
				index = i, filter = filter, icon = icon, count = count or 0,
				dispelType = dispelType, duration = duration or 0, expires = expires or 0,
			}
			if #scratch >= cap then break end
		end
	end
	return scratch
end

function UpdateDebuffs(B)
	local host, icons = B.host, B.icons
	if not host then return end
	local t = DB()
	if B.mode == "preview" then
		local n = min(t.debuffCap or 3, MAX_ICONS)
		LayoutIcons(B, t, n)
		for i = 1, n do
			local b = icons[i]
			b._index, b._expires = nil, nil
			b.icon:SetTexture(PREVIEW_TEX[i])
			b.edge:SetTexture(0, 0, 0, 1)
			b.cd:Hide()
			b.dur:SetText("")
			b.stack:SetText("")
		end
		host:Show()
		return
	end
	if B.mode ~= "live" or not B.unit then
		host:Hide()
		return
	end
	local list = CollectDebuffs(B.unit, t)
	local n = #list
	LayoutIcons(B, t, n)
	for i = 1, n do
		local d, b = list[i], icons[i]
		b._index, b._filter, b._expires = d.index, d.filter, d.expires
		b.icon:SetTexture(d.icon)
		local c = d.dispelType and TYPE_COLOR[d.dispelType]
		if c then
			b.edge:SetTexture(c[1], c[2], c[3], 1)
		else
			b.edge:SetTexture(0, 0, 0, 1)
		end
		if d.duration > 0 and d.expires > 0 then
			b.cd:SetCooldown(d.expires - d.duration, d.duration)
			b.cd:Show()
		else
			b.cd:Hide()
		end
		b.stack:SetText((t.debuffShowStacks ~= false and d.count > 1) and tostring(d.count) or "")
		b._acc = 1
		IconOnUpdate(b, 0)
	end
	host:SetShown(n > 0)
end

local function SetDebuffMode(B, mode)
	B.mode = mode
	if mode then BuildIcons(B) end
	if B.host then
		if mode then UpdateDebuffs(B) else B.host:Hide() end
	end
end

-------------------------------------------------------------------------------
--  Stacking
-------------------------------------------------------------------------------
-- Space between two bars: the spacing setting, plus room for a debuff row
-- that sits on the top or bottom edge (it would cover the next bar).
local function BarGap(t)
	local gap = t.tankSpacing or 4
	if t.debuffEnabled then
		local corner = DEBUFF_CORNERS[t.debuffPosition or "top"] or "TOP"
		if corner:find("TOP", 1, true) or corner:find("BOTTOM", 1, true) then
			local size, spacing = t.debuffSize or 22, t.debuffSpacing or 2
			local grow = t.debuffGrow or "CENTER"
			local extent = size
			if grow == "UP" or grow == "DOWN" then
				local n = min(t.debuffCap or 3, MAX_ICONS)
				extent = n * size + max(0, n - 1) * spacing
			end
			gap = gap + extent + math.abs(t.debuffOffsetY or 0)
		end
	end
	return gap
end

-- Bar 1 sits at the saved position; every other bar hangs off the one
-- before it. Out of combat only (secure frames).
local function ChainBars(t)
	local gap = BarGap(t)
	local up = (t.tankGrow == "UP")
	for i = 2, #bars do
		local f, prev = bars[i].frame, bars[i - 1].frame
		f:ClearAllPoints()
		if up then
			f:SetPoint("BOTTOM", prev, "TOP", 0, gap)
		else
			f:SetPoint("TOP", prev, "BOTTOM", 0, -gap)
		end
	end
end

-------------------------------------------------------------------------------
--  Events
-------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")

-- Registered only while the feature is on (GROUP_ROSTER_UPDATE is noisy).
local ACTIVE_EVENTS = {
	"GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "ROLE_CHANGED_INFORM",
	"PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
}
local eventsOn = false

local function SyncEvents(want)
	if want == eventsOn then return end
	eventsOn = want
	for i = 1, #ACTIVE_EVENTS do
		if want then ev:RegisterEvent(ACTIVE_EVENTS[i]) else ev:UnregisterEvent(ACTIVE_EVENTS[i]) end
	end
end

-------------------------------------------------------------------------------
--  Display
-------------------------------------------------------------------------------
local function HideBar(B, combat)
	WatchUnit(B, nil)
	B.class = nil
	SetDebuffMode(B, nil)
	if not combat then
		B.frame:SetAttribute("unit", nil)
		B.frame:Hide()
	end
end

local function UpdateDisplay()
	local t = DB()
	local live = t.enabled and true or false
	local combat = InCombatLockdown()
	SyncEvents(live)
	-- The unit attribute and Show/Hide are locked in combat, so the tank list
	-- only changes out of combat (PLAYER_REGEN_ENABLED catches up).
	if live and not combat then FindOtherTanks() end

	if not BuildBar(1) then return end

	local count, standIn = WantedBars(t)
	if not combat then
		for i = 2, count do BuildBar(i) end

		local w, h = t.width or 150, t.height or 20
		local resized = (w ~= lastW or h ~= lastH)
		lastW, lastH = w, h
		for i = 1, #bars do
			local f = bars[i].frame
			f:EnableMouse(true)
			if resized then f:SetSize(w, h) end
		end
		if resized then Q.After(0, RepushBars) end

		-- Moving a secure frame is protected: PLAYER_REGEN_ENABLED finishes it.
		local first = bars[1].frame
		if not first.posInitialized then
			first:ClearAllPoints()
			local point = t.point or "CENTER"
			first:SetPoint(point, UIParent, point, t.x or 200, t.y or 0)
			first.posInitialized = true
		end
		ChainBars(t)
	end

	for i = 1, #bars do
		local B = bars[i]
		B.bg:SetAlpha(t.bgAlpha or 0.6)
		if i > count then
			HideBar(B, combat)
		elseif standIn then
			-- Nobody to show: stand-in bars at 75%.
			WatchUnit(B, nil)
			B.class = nil
			if not combat then B.frame:SetAttribute("unit", nil) end
			B.bar:SetMinMaxValues(0, 100)
			B.bar:SetValue(75)
			B.bar:SetStatusBarColor(t.healthColorR or 0, t.healthColorG or 0.8, t.healthColorB or 0.2)
			PaintName(B, i == 1 and "TankName" or ("TankName" .. i), t, false)
			SetDebuffMode(B, t.debuffEnabled and "preview" or nil)
			if not combat then B.frame:Show() end
		else
			local unit = tanks[i]
			if not combat then B.frame:SetAttribute("unit", unit) end
			local _, cls = UnitClass(unit)
			B.class = cls
			WatchUnit(B, unit)
			PaintBar(B, t)
			RefreshHealthValue(B)
			SetDebuffMode(B, t.debuffEnabled and "live" or nil)
			if not combat then B.frame:Show() end
		end
	end
end
CT.Update = UpdateDisplay

-- Re-reads the position from the settings.
function CT.Reposition()
	if bars[1] then bars[1].frame.posInitialized = false end
	UpdateDisplay()
end

local function Teardown()
	SyncEvents(false)
	local combat = InCombatLockdown()
	for i = 1, #bars do HideBar(bars[i], combat) end
end

Q.RegisterRefresh(SECTION, CT.Reposition)
Q.RegisterReset(SECTION, function()
	Teardown()
	Q.ClearDB(SECTION)
end)
Q.OnSpecChanged(UpdateDisplay)
Q.OnUnlockModeChanged(function() UpdateDisplay() end)

ev:SetScript("OnEvent", function()
	UpdateDisplay()
end)

Q.RegisterMover({
	key      = "NaowhUI_CoTank",
	label    = "Co-Tank Frame",
	order    = 100,
	section  = SECTION,
	db       = DB,
	apply    = CT.Reposition,
	getFrame = function() BuildBar(1); return bars[1] and bars[1].frame end,
	pointKey = "point", xKey = "x", yKey = "y",
	widthKey = "width", heightKey = "height",
	minW = 50, minH = 10,
	isHidden = function() return not DB().enabled end,
})
