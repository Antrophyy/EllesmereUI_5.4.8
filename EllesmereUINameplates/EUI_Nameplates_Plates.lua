-------------------------------------------------------------------------------
--  EUI_Nameplates_Plates.lua
--
--  Finds the Blizzard nameplates (WorldFrame children "NamePlate<n>"), hides
--  their art, puts one EllesmereUI plate on each and reads the Blizzard plate
--  every frame: name, level, reaction (health bar color), elite / boss icon,
--  threat glow, raid icon, target (the Blizzard plate keeps alpha 1) and
--  mouseover (its highlight). A plate gets a unit token while it is the
--  target, the mouseover, the focus, a boss / arena unit or a group member,
--  and a GUID once one of those was seen (kept until the plate hides).
--  Pattern of the ElvUI Mists nameplates.
-------------------------------------------------------------------------------
local addonName, P = ...
local ns, ENP = P.ns, P.ENP

local floor = math.floor
local select, pairs, next = select, pairs, next
local UnitExists, UnitGUID, UnitName = UnitExists, UnitGUID, UnitName
local WorldFrame = WorldFrame

local plates = {}   -- [Blizzard plate] = our plate
local visible = {}  -- [our plate] = true while shown
local byGUID = {}   -- [guid] = our plate
ENP.plates, ENP.visible, ENP.byGUID = plates, visible, byGUID

local HIDDEN = CreateFrame("Frame")
HIDDEN:Hide()
P.HIDDEN = HIDDEN

local Plate = {}
P.Plate = Plate

-------------------------------------------------------------------------------
--  Name and unit caches
-------------------------------------------------------------------------------
-- Group members and arena enemies by name (player plates have unique names).
local groupByName, arenaByName = {}, {}
-- Class of players by name (seen in the group, as target / mouseover / in
-- the combat log).
local classByName = {}
P.classByName = classByName
-- What a unit token taught about an NPC, by name: caster, classification.
local npcInfo = {}
P.npcInfo = npcInfo

local function StripRealm(name)
	if not name then return nil end
	return (name:gsub("%-.*$", ""))
end
P.StripRealm = StripRealm

function P.RefreshGroup()
	wipe(groupByName)
	local n = GetNumGroupMembers and GetNumGroupMembers() or 0
	local prefix = IsInRaid() and "raid" or "party"
	local count = IsInRaid() and n or (n > 0 and n - 1 or 0)
	for i = 1, count do
		local u = prefix .. i
		local name = UnitName(u)
		if name then
			groupByName[name] = u
			local _, cls = UnitClass(u)
			classByName[name] = cls
		end
		local pu = prefix .. "pet" .. i
		local pname = UnitName(pu)
		if pname then
			groupByName[pname] = groupByName[pname] or pu
		end
	end
	local pet = UnitName("pet")
	if pet then
		groupByName[pet] = "pet"
	end
end

function P.RefreshArena()
	wipe(arenaByName)
	for i = 1, 5 do
		local u = "arena" .. i
		local name = UnitName(u)
		if name then
			arenaByName[name] = u
			local _, cls = UnitClass(u)
			classByName[name] = cls
		end
		local pu = "arenapet" .. i
		local pname = UnitName(pu)
		if pname then
			arenaByName[pname] = pu
		end
	end
end

-- Remember what a unit token shows about its unit (NPC info, player class).
function P.Learn(unit)
	if not UnitExists(unit) then return end
	local name = UnitName(unit)
	if not name then return end
	if UnitIsPlayer(unit) then
		local _, cls = UnitClass(unit)
		classByName[name] = cls
		return
	end
	local info = npcInfo[name]
	if not info then
		info = {}
		npcInfo[name] = info
	end
	local pType = UnitPowerType(unit)
	info.caster = (pType == 0) and (UnitPowerMax(unit, 0) or 0) > 0
	info.classification = UnitClassification(unit)
	info.level = UnitLevel(unit)
end

-------------------------------------------------------------------------------
--  Reading the Blizzard plate
-------------------------------------------------------------------------------
-- Health bar color -> reaction and plate kind (5.4.8 plate colors; enemy
-- players show their class color with ShowClassColorInNameplate).
local function ReadReaction(r, g, b)
	if r < 0.01 then
		if b < 0.01 and g > 0.99 then
			return 5, "FRIENDLY_NPC"
		elseif b > 0.99 and g < 0.01 then
			return 5, "FRIENDLY_PLAYER"
		end
	elseif r > 0.99 then
		if b < 0.01 and g > 0.99 then
			return 4, "ENEMY_NPC"
		elseif b < 0.01 and g < 0.01 then
			return 2, "ENEMY_NPC"
		end
	elseif r > 0.5 and r < 0.6 then
		if g > 0.5 and g < 0.6 and b > 0.5 and b < 0.6 then
			return 1, "ENEMY_NPC"
		end
	end
	return 3, "ENEMY_PLAYER"
end
P.ReadReaction = ReadReaction

-- Enemy player class from the class color of the Blizzard bar.
local classByBlue = {}
do
	for cls, c in pairs(RAID_CLASS_COLORS) do
		local key = floor((c.b + (cls == "MONK" and 0.01 or 0)) * 100 + 0.5)
		classByBlue[key] = cls
	end
end

-- Threat: nil = no threat data, 0 = in combat (no aggro), 1 = higher threat
-- than the tank, 2 = losing / gaining, 3 = tanking (UnitThreatSituation).
local function ReadThreat(plate)
	local t = plate.bThreat
	if t:IsShown() then
		local r, g, b = t:GetVertexColor()
		if r > 0 then
			if g > 0 then
				if b > 0 then return 1 end
				return 2
			end
			return 3
		end
		return nil
	end
	if plate.kind == "ENEMY_NPC" then
		local r, g = plate.bName:GetTextColor()
		if r > 0.5 and g < 0.5 then
			return 0
		end
	end
	return nil
end

local function RaidIndex(tex)
	if not tex:IsShown() then return nil end
	local ux, uy = tex:GetTexCoord()
	if not ux then return nil end
	local col = floor(ux * 4 + 0.5)
	local row = floor(uy * 4 + 0.5)
	local i = row * 4 + col + 1
	if i < 1 or i > 8 then return nil end
	return i
end

-- Reads everything that can change while the plate shows. Returns true when
-- the look depends on something new (reaction, threat, raid icon, combat).
function Plate:ReadState()
	local r, g, b = self.bHealth:GetStatusBarColor()
	local reaction, kind = ReadReaction(r, g, b)
	local changed = false
	if reaction ~= self.reaction or kind ~= self.kind then
		self.reaction, self.kind = reaction, kind
		self.isFriendly = (kind == "FRIENDLY_NPC" or kind == "FRIENDLY_PLAYER")
		self.isPlayer = (kind == "ENEMY_PLAYER" or kind == "FRIENDLY_PLAYER")
		if self.kind0 and self.kind0 ~= kind then
			self._kindChanged = true
		end
		self.kind0 = kind
		changed = true
	end
	if kind == "ENEMY_PLAYER" then
		local cls = classByBlue[floor(b * 100 + 0.5)]
		if cls and cls ~= self.class then
			self.class = cls
			changed = true
		end
	end
	local threat = ReadThreat(self)
	if threat ~= self.threat then
		self.threat = threat
		changed = true
	end
	local inCombat = threat ~= nil
	if inCombat ~= self.inCombat then
		self.inCombat = inCombat
		changed = true
	end
	local ri = RaidIndex(self.bRaid)
	if ri ~= self.raidIndex then
		self.raidIndex = ri
		self:UpdateRaidIcon()
	end
	return changed
end

-- Static facts of the unit on a (re)shown plate.
function Plate:ReadIdentity()
	local name = StripRealm(self.bName:GetText())
	self.name = name or ""
	local lvl = self.bLevel:GetObjectType() == "FontString" and tonumber(self.bLevel:GetText()) or nil
	self.boss = self.bBoss:IsShown() and true or false
	self.elite = self.bElite:IsShown() and true or false
	if self.boss or not lvl then
		self.level = -1
		self.levelR, self.levelG, self.levelB = 1, 0, 0
	else
		self.level = lvl
		self.levelR, self.levelG, self.levelB = self.bLevel:GetTextColor()
	end
	self.trivial = (self.bBar:GetScale() or 1) < 1
	self.reaction, self.kind = nil, nil
	self.kind0 = nil
	self:ReadState()
	if self.kind == "FRIENDLY_PLAYER" then
		self.class = classByName[self.name]
	elseif self.kind ~= "ENEMY_PLAYER" then
		self.class = nil
	end
end

-- Mob classification (retail UnitClassification values), from the cache of
-- a unit token or the plate icons.
function Plate:Classification()
	local info = (not self.isPlayer) and npcInfo[self.name]
	if info and info.classification then
		return info.classification
	end
	if self.boss then return "worldboss" end
	if self.elite then return "elite" end
	if self.trivial then return "trivial" end
	return "normal"
end

function Plate:IsCaster()
	local info = (not self.isPlayer) and npcInfo[self.name]
	return info and info.caster or false
end

-------------------------------------------------------------------------------
--  Unit token and GUID
-------------------------------------------------------------------------------
local function SetGUID(plate, guid)
	if plate.guid == guid then return end
	if plate.guid and byGUID[plate.guid] == plate then
		byGUID[plate.guid] = nil
	end
	plate.guid = guid
	if guid then
		local old = byGUID[guid]
		if old and old ~= plate then
			old.guid = nil
		end
		byGUID[guid] = plate
	end
end
P.SetGUID = SetGUID

local BOSS_UNITS = { "boss1", "boss2", "boss3", "boss4" }

-- The best unit token for the plate right now (nil = none).
function Plate:ResolveUnit()
	if self.isTarget then return "target" end
	if self.isMouseover then return "mouseover" end
	local guid = self.guid
	if guid then
		if UnitGUID("focus") == guid then return "focus" end
		for i = 1, 4 do
			if UnitGUID(BOSS_UNITS[i]) == guid then return BOSS_UNITS[i] end
		end
	end
	if self.isPlayer then
		local u = self.isFriendly and groupByName[self.name] or arenaByName[self.name]
		if u then return u end
	elseif self.isFriendly then
		local u = groupByName[self.name]
		if u then return u end
	end
	return nil
end

-- Re-resolves unit + GUID; returns true when the unit token changed.
function Plate:UpdateUnit()
	local unit = self:ResolveUnit()
	if unit and UnitExists(unit) then
		local guid = UnitGUID(unit)
		if guid then
			SetGUID(self, guid)
		end
	else
		unit = nil
	end
	local focus = false
	local fguid = UnitGUID("focus")
	if fguid and self.guid == fguid then
		focus = true
	end
	self.isFocus = focus
	if unit ~= self.unit then
		self.unit = unit
		if unit then
			P.Learn(unit)
		end
		return true
	end
	return false
end

-- Plate for a GUID; a name with exactly one visible plate (or a raid icon
-- from combat log flags) ties the GUID to it.
local RAID_FLAG_TO_INDEX = {}
for i = 1, 8 do
	RAID_FLAG_TO_INDEX[bit.lshift(1, i - 1)] = i
end

function P.PlateForGUID(guid, name, raidFlags)
	local plate = byGUID[guid]
	if plate then
		return plate
	end
	if raidFlags and raidFlags ~= 0 then
		local ri = RAID_FLAG_TO_INDEX[bit.band(raidFlags, 0xFF)]
		if ri then
			for pl in pairs(visible) do
				if pl.raidIndex == ri then
					SetGUID(pl, guid)
					return pl
				end
			end
		end
	end
	name = StripRealm(name)
	if not name then return nil end
	local found
	for pl in pairs(visible) do
		if pl.name == name and not pl.guid then
			if found then
				return nil -- two plates with the same name
			end
			found = pl
		end
	end
	if found then
		-- A unique player name is safe; an NPC name only when no other plate
		-- of that name exists at all (with or without a GUID).
		if not found.isPlayer then
			for pl in pairs(visible) do
				if pl ~= found and pl.name == name then
					return nil
				end
			end
		end
		SetGUID(found, guid)
	end
	return found
end

-------------------------------------------------------------------------------
--  Mobs held by another tank (off-tank color). A plate without a unit token
--  cannot tell whom its mob targets, so the targets of the group members are
--  read instead: a hostile "<member>target" whose own target is a tank other
--  than the player. Matched to plates by GUID, raid icon or name + health.
-------------------------------------------------------------------------------
local offTankHeld = {}  -- list of { guid, name, ri, hp, hpMax }
local offTankCount = 0

local function OtherTank(u)
	return UnitExists(u) and UnitGroupRolesAssigned(u) == "TANK" and not UnitIsUnit(u, "player")
end
P.OtherTank = OtherTank

local function ScanOffTankHeld()
	offTankCount = 0
	local n = GetNumGroupMembers and GetNumGroupMembers() or 0
	if n == 0 then return end
	local prefix = IsInRaid() and "raid" or "party"
	local count = IsInRaid() and n or (n - 1)
	for i = 1, count do
		local t = prefix .. i .. "target"
		if UnitExists(t) and not UnitIsPlayer(t) and UnitCanAttack("player", t) and OtherTank(t .. "target") then
			local guid = UnitGUID(t)
			local dup = false
			for j = 1, offTankCount do
				if offTankHeld[j].guid == guid then dup = true break end
			end
			if not dup then
				offTankCount = offTankCount + 1
				local e = offTankHeld[offTankCount]
				if not e then
					e = {}
					offTankHeld[offTankCount] = e
				end
				e.guid = guid
				e.name = UnitName(t)
				e.ri = GetRaidTargetIndex(t)
				e.hp = UnitHealth(t)
				e.hpMax = UnitHealthMax(t)
			end
		end
	end
end

-- One visible plate of this name whose health equals hp / hpMax (nil when
-- none or several: same-name mobs at full health look alike).
local function UniqueHealthMatch(name, hp, hpMax)
	local found
	for pl in pairs(visible) do
		if pl.name == name then
			local _, mx = pl.bHealth:GetMinMaxValues()
			if mx == hpMax and pl.bHealth:GetValue() == hp then
				if found then return nil end
				found = pl
			end
		end
	end
	return found
end

-- True when another tank holds the mob of this plate (read on the slow tick;
-- a name + health match ties the GUID to the plate so later scans match by
-- GUID, as the health of the plate and of the unit token can differ a frame).
function Plate:HeldByOtherTank()
	if self.unit then
		return OtherTank(self.unit .. "target")
	end
	if offTankCount == 0 then return false end
	local guid, ri = self.guid, self.raidIndex
	for j = 1, offTankCount do
		local e = offTankHeld[j]
		if guid then
			if e.guid == guid then return true end
		elseif byGUID[e.guid] == nil then
			if ri and e.ri == ri then
				SetGUID(self, e.guid)
				return true
			end
			if e.name == self.name and UniqueHealthMatch(e.name, e.hp, e.hpMax) == self then
				SetGUID(self, e.guid)
				return true
			end
		end
	end
	return false
end

-- Cached off-tank state with a short grace before it drops, so a mob that
-- turns to a healer for one cast or a missed scan does not flicker the color.
local OFFTANK_GRACE = 0.8
function Plate:UpdateOffTankHeld(watch, now)
	local held = false
	if watch then
		if self:HeldByOtherTank() then
			self._offTankSeen = now
			held = true
		elseif self._offTankHeld and self._offTankSeen and now - self._offTankSeen < OFFTANK_GRACE then
			held = true
		end
	end
	if held ~= (self._offTankHeld or false) then
		self._offTankHeld = held
		return true
	end
	return false
end

-------------------------------------------------------------------------------
--  Hiding the Blizzard art
-------------------------------------------------------------------------------
local function Clear(object)
	local t = object:GetObjectType()
	if t == "Texture" then
		object:SetTexture("")
		object:SetTexCoord(0, 0, 0, 0)
	elseif t == "FontString" then
		object:SetWidth(0.001)
	elseif t == "StatusBar" then
		object:SetStatusBarTexture("")
	end
	object:Hide()
end

-------------------------------------------------------------------------------
--  Plate creation
-------------------------------------------------------------------------------
local function OnBlizzShow(blizz)
	local plate = plates[blizz]
	if plate then
		plate:OnShown()
	end
end

local function OnBlizzHide(blizz)
	local plate = plates[blizz]
	if plate then
		plate:OnHidden()
	end
end

local function OnHealthChanged(bar)
	local plate = bar.__euiPlate
	if plate and plate.shown then
		plate:UpdateHealth()
	end
end

local function CreatePlate(blizz)
	local barFrame, nameFrame = blizz:GetChildren()
	if not barFrame or not nameFrame then return end
	local health, cast = barFrame:GetChildren()
	if not health or not cast then return end
	local threat, border, highlight, level, bossIcon, raidIcon, eliteIcon = barFrame:GetRegions()
	local name = nameFrame:GetRegions()
	local _, castBorder, castShield, castIcon, castName, castShadow = cast:GetRegions()

	local plate = CreateFrame("Frame", nil, blizz)
	for k, v in pairs(Plate) do
		plate[k] = v
	end
	plate.blizz = blizz
	plate.bBar = barFrame
	plate.bHealth = health
	plate.bCast = cast
	plate.bThreat = threat
	plate.bHighlight = highlight
	plate.bLevel = level
	plate.bBoss = bossIcon
	plate.bRaid = raidIcon
	plate.bElite = eliteIcon
	plate.bName = name
	plate.bCastShield = castShield
	plate.bCastIcon = castIcon
	plate.bCastName = castName
	health.__euiPlate = plate
	cast.__euiPlate = plate

	plate:SetPoint("CENTER", blizz, "CENTER", 0, 0)
	plate:SetSize(1, 1)

	plate:Build()
	plates[blizz] = plate
	P.HideBlizzard(plate)

	blizz:HookScript("OnShow", OnBlizzShow)
	blizz:HookScript("OnHide", OnBlizzHide)
	health:HookScript("OnValueChanged", OnHealthChanged)
	health:HookScript("OnMinMaxChanged", OnHealthChanged)
	if plate.HookCastBar then
		plate:HookCastBar()
	end
	if blizz:IsShown() then
		plate:OnShown()
	else
		plate:Hide()
	end
	return plate
end

-- Blizzard art off (or back on when the module is disabled at runtime is not
-- supported: a reload brings it back).
function P.HideBlizzard(plate)
	Clear(plate.bHealth)
	Clear(plate.bCast)
	Clear(plate.bLevel)
	Clear(plate.bName)
	Clear(plate.bThreat)
	local _, castBorder, castShield, _, castName, castShadow = plate.bCast:GetRegions()
	Clear(castBorder)
	Clear(castShield)
	Clear(castName)
	if castShadow then Clear(castShadow) end
	local border = select(2, plate.bBar:GetRegions())
	if border then Clear(border) end
	Clear(plate.bHighlight)
	plate.bCastIcon:SetParent(HIDDEN)
	plate.bBoss:SetAlpha(0)
	plate.bElite:SetAlpha(0)
	plate.bRaid:SetAlpha(0)
end

-------------------------------------------------------------------------------
--  Show / hide
-------------------------------------------------------------------------------
function Plate:OnShown()
	self.shown = true
	visible[self] = true
	SetGUID(self, nil)
	self.unit = nil
	self.isTarget, self.isMouseover, self.isFocus = nil, nil, nil
	self._offTankHeld, self._offTankSeen = nil, nil
	self:ReadIdentity()
	self:UpdateUnit()
	self:Show()
	self:Refresh()
end

function Plate:OnHidden()
	self.shown = false
	visible[self] = nil
	SetGUID(self, nil)
	self.unit = nil
	self.isTarget, self.isMouseover, self.isFocus = nil, nil, nil
	self._offTankHeld, self._offTankSeen = nil, nil
	if self.OnCleared then
		self:OnCleared()
	end
	self:Hide()
end

-------------------------------------------------------------------------------
--  Every frame: new plates, target / mouseover, Blizzard alpha, threat
-------------------------------------------------------------------------------
local lastChildren = 0
local function FindNew(...)
	for i = lastChildren + 1, select("#", ...) do
		local f = select(i, ...)
		if not plates[f] then
			local n = f:GetName()
			if n and n:find("^NamePlate%d") then
				CreatePlate(f)
			end
		end
	end
end

local hasTarget = false
local targetName
function P.RefreshTargetInfo()
	hasTarget = UnitExists("target") and true or false
	targetName = hasTarget and UnitName("target") or nil
end

local slowTimer = 0
local driver = CreateFrame("Frame")
P.driver = driver
local function OnUpdate(_, elapsed)
	local n = WorldFrame:GetNumChildren()
	if n ~= lastChildren then
		FindNew(WorldFrame:GetChildren())
		lastChildren = n
	end
	slowTimer = slowTimer + elapsed
	local slow = slowTimer > 0.2
	local offTankWatch, now = false, nil
	if slow then
		slowTimer = 0
		now = GetTime()
		offTankWatch = P.On("offTankAggroEnabled") and P.IsTank()
		if offTankWatch then
			ScanOffTankHeld()
		else
			offTankCount = 0
		end
	end
	for plate in pairs(visible) do
		local blizz = plate.blizz
		local isTarget = false
		if hasTarget then
			isTarget = blizz:GetAlpha() >= 0.99 and plate.name == targetName
			blizz:SetAlpha(1)
		end
		local isMouseover = plate.bHighlight:IsShown() and true or false
		local unitChanged = false
		if isTarget ~= (plate.isTarget or false) or isMouseover ~= (plate.isMouseover or false) then
			local wasTarget = plate.isTarget
			plate.isTarget, plate.isMouseover = isTarget or nil, isMouseover or nil
			unitChanged = plate:UpdateUnit()
			if (wasTarget or false) ~= isTarget then
				plate:UpdateTarget()
			end
			plate:UpdateMouseover()
		elseif slow then
			unitChanged = plate:UpdateUnit()
		end
		local stateChanged = plate:ReadState()
		if slow and plate:UpdateOffTankHeld(offTankWatch, now) then
			stateChanged = true
		end
		if plate._kindChanged then
			plate._kindChanged = nil
			plate:Refresh()
		elseif unitChanged then
			plate:OnUnitChanged()
		elseif stateChanged then
			plate:UpdateColor()
		end
		if slow and plate.SlowUpdate then
			plate:SlowUpdate()
		end
	end
end

function P.StartDriver()
	P.RefreshTargetInfo()
	driver:SetScript("OnUpdate", OnUpdate)
end

function P.StopDriver()
	driver:SetScript("OnUpdate", nil)
end

-- All plates (shown or not), for settings changes.
function P.ForEachPlate(fn)
	for _, plate in pairs(plates) do
		fn(plate)
	end
end

function P.ForEachVisible(fn)
	for plate in pairs(visible) do
		fn(plate)
	end
end
