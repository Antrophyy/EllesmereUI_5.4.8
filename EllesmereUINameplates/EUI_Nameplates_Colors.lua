-------------------------------------------------------------------------------
--  EUI_Nameplates_Colors.lua
--
--  Health bar color of a plate: the retail GetReactionColor priority list
--  (EUI_Nameplates_Colors.lua) step by step, reading the 5.4.8 plate instead
--  of a unit: tapped and neutral from the Blizzard bar color, threat from the
--  Blizzard threat glow, "in combat" from threat / the red name, boss and
--  mini-boss from the skull, the elite dragon and the level, caster from the
--  cache a unit token filled. Quest mobs from the tooltip of a unit token,
--  kept by name.
-------------------------------------------------------------------------------
local addonName, P = ...
local ns, ENP = P.ns, P.ENP
local defaults = P.defaults

local Plate = P.Plate

-------------------------------------------------------------------------------
--  Zone state (retail RefreshThreatCache)
-------------------------------------------------------------------------------
local inThreatContent, inDungeon = false, false
local threatColorsOn = false

function P.RefreshZone()
	local _, instanceType, difficultyID = GetInstanceInfo()
	difficultyID = tonumber(difficultyID) or 0
	inDungeon = (instanceType == "party")
	inThreatContent = difficultyID ~= 0 and (instanceType == "party" or instanceType == "raid")
	P.RefreshThreatFlag()
end

function P.RefreshThreatFlag()
	local mode = P.Get("threatColorMode")
	if mode ~= "never" and mode ~= "instances" and mode ~= "always" then
		mode = defaults.threatColorMode
	end
	threatColorsOn = (mode == "always" or (mode == "instances" and inThreatContent))
end

function P.InThreatContent()
	return inThreatContent
end

local function C(key)
	local c = P.Get(key)
	if type(c) ~= "table" then
		c = defaults[key] or { r = 1, g = 1, b = 1 }
	end
	return c.r or 1, c.g or 1, c.b or 1
end
P.C = C

local function MaybeDarken(r, g, b, inCombat)
	if not P.On("darkenEnemiesOOC") then return r, g, b end
	if inCombat then return r, g, b end
	if P.On("darkenOOCRecolor") then
		return C("darkenOOCColor")
	end
	return r * 0.5, g * 0.5, b * 0.5
end
P.MaybeDarken = MaybeDarken

local function ResolveNeutralColor(plate)
	if plate.inCombat then
		return C("enemyInCombat")
	end
	return C("neutral")
end

-------------------------------------------------------------------------------
--  Quest mobs: the tooltip of a unit token shows a quest objective line
--  ("Name slain: 2/8"); kept by NPC name until the quest log changes.
-------------------------------------------------------------------------------
local questByName = {}
local scanTip

local function ScanQuest(unit, name)
	if not scanTip then
		scanTip = CreateFrame("GameTooltip", "EUINameplatesScanTip", nil, "GameTooltipTemplate")
		scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
	end
	scanTip:ClearLines()
	scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
	scanTip:SetUnit(unit)
	local isQuest, objText = false, nil
	for i = 2, scanTip:NumLines() or 0 do
		local fs = _G["EUINameplatesScanTipTextLeft" .. i]
		local text = fs and fs:GetText()
		if text then
			local cur, total = text:match("(%d+)/(%d+)")
			if cur and total then
				cur, total = tonumber(cur), tonumber(total)
				if cur < total then
					isQuest = true
					objText = tostring(total - cur)
					break
				end
			end
		end
	end
	questByName[name] = { quest = isQuest, text = objText }
end

function P.LearnQuest(unit)
	if not UnitExists(unit) or UnitIsPlayer(unit) then return end
	if not (P.On("questMobColorEnabled") or P.Get("classificationSlot") ~= "none") then return end
	local name = UnitName(unit)
	if not name or questByName[name] then return end
	ScanQuest(unit, name)
end

function P.WipeQuestCache()
	wipe(questByName)
end

function Plate:IsQuestMob()
	if self.isPlayer or self.isFriendly then return false end
	if inThreatContent and not P.On("classificationShowInInstances") then
		return false
	end
	local q = questByName[self.name]
	if not q and self.unit then
		P.LearnQuest(self.unit)
		q = questByName[self.name]
	end
	return q and q.quest or false, q and q.text
end

-------------------------------------------------------------------------------
--  The priority list (retail steps kept with their numbers)
-------------------------------------------------------------------------------
local function InGroup()
	return (GetNumGroupMembers and GetNumGroupMembers() or 0) > 0
end

function Plate:GetReactionColor()
	self._nearAggro = false
	-- 1. Tapped always highest
	if self.reaction == 1 then
		return C("tapped")
	end
	-- 2. Quest mob second highest
	if P.On("questMobColorEnabled") and self:IsQuestMob() then
		return C("questMobColor")
	end
	local isTank = P.IsTank()
	local isThreatUnit, threatStatus = false, 0
	if threatColorsOn and self.threat ~= nil then
		local status = self.threat
		isThreatUnit, threatStatus = true, status
		if not P.On("threatColorHealth") then
			if not isTank and InGroup() and status == 2 then
				self._nearAggro = true
			end
			isThreatUnit, threatStatus = false, 0
		elseif not isTank then
			if InGroup() then
				if status >= 3 then
					return C("dpsHasAggro")
				elseif status >= 2 then
					self._nearAggro = true
					return C("dpsNearAggro")
				end
			end
		else
			if status == 2 then
				return C("tankLosingAggro")
			elseif status < 2 then
				-- A tank without aggro: off-tank color when another tank holds
				-- it (Plate:UpdateOffTankHeld, read on the slow tick).
				if not self._offTankHeld then
					return C("tankNoAggro")
				end
				if P.On("offTankAggroEnabled") then
					return C("offTankAggro")
				end
			end
			if status >= 3 and P.On("classicTankAggro") then
				return C("tankHasAggro")
			end
		end
	end
	-- 4. Target color (if enabled)
	if self.isTarget and P.On("targetColorEnabled") then
		return C("target")
	end
	-- 5. Focus color (if enabled)
	if self.isFocus and P.On("focusColorEnabled") then
		return C("focus")
	end
	-- 5. Neutral (outside dungeons it keeps its high priority)
	local isNeutral = self.reaction == 4
	if isNeutral and not inDungeon then
		return ResolveNeutralColor(self)
	end
	-- 6. Enemy player class colors
	if self.kind == "ENEMY_PLAYER" then
		local c = self.class and ((EllesmereUI.GetClassColor and RAID_CLASS_COLORS[self.class] and EllesmereUI.GetClassColor(self.class)) or RAID_CLASS_COLORS[self.class])
		if c then
			return c.r, c.g, c.b
		end
	end
	local inCombat = self.inCombat
	local classification = self:Classification()
	local owBasic = (not inDungeon) and P.On("owBasicColoring")
	local miniMPlusOnly = P.On("miniColoringMPlusOnly")
	local miniColorScope = not owBasic and (inDungeon or not miniMPlusOnly)
	local isBoss, isMiniBoss = false, false
	if not owBasic and (classification == "elite" or classification == "worldboss" or classification == "rareelite") then
		local level = self.level
		local playerLevel = UnitLevel("player")
		local isSkull = level == -1
		local aboveOne = level and level >= playerLevel + 1
		if isSkull or aboveOne then
			local aboveTwo = level and level >= playerLevel + 2
			if isSkull or aboveTwo or classification == "worldboss" then
				isBoss = true
			else
				isMiniBoss = true
			end
		end
	end
	local isCaster = not owBasic and not isBoss and self:IsCaster()
	local dpsNoAggroActive = isThreatUnit and not isTank and threatStatus < 2 and InGroup() and P.On("dpsNoAggroEnabled")
	-- 6b. Tank has aggro, "Override Mini-Boss and Caster colors"
	if isThreatUnit and isTank and threatStatus >= 3 and not isBoss then
		if P.On("tankHasAggroEnabled") and P.On("tankHasAggroOverrideMobType") then
			return C("tankHasAggro")
		end
	end
	-- 7. Mini-boss
	if isMiniBoss then
		if dpsNoAggroActive and P.On("dpsNoAggroOverrideMiniBoss") then
			return C("dpsNoAggro")
		end
		local r, g, b = C("miniboss")
		return MaybeDarken(r, g, b, inCombat)
	end
	-- 7b. Mini Enemies above Caster (not for tanks with Tank Has Aggro)
	if miniColorScope and (classification == "normal" or classification == "minus" or classification == "trivial") then
		local thae = P.On("tankHasAggroEnabled")
		local tankAggroPending = isThreatUnit and isTank and threatStatus >= 3 and thae
		if isNeutral and not tankAggroPending then
			return ResolveNeutralColor(self)
		end
		if not (isTank and thae) then
			if isThreatUnit and not isTank and threatStatus < 2 and InGroup() and P.On("dpsNoAggroEnabled") then
				return C("dpsNoAggro")
			end
			local p = P.Profile()
			local r, g, b
			if p.miniEnemy then
				r, g, b = p.miniEnemy.r, p.miniEnemy.g, p.miniEnemy.b
			else
				r, g, b = C("enemyInCombat")
			end
			return MaybeDarken(r, g, b, inCombat)
		end
	end
	-- 8. Caster
	if isCaster then
		if dpsNoAggroActive and P.On("dpsNoAggroOverrideCaster") then
			return C("dpsNoAggro")
		end
		local r, g, b = C("caster")
		return MaybeDarken(r, g, b, inCombat)
	end
	-- 9. Tank has aggro
	if isThreatUnit and isTank and threatStatus >= 3 and P.On("tankHasAggroEnabled") then
		if P.On("tankHasAggroOverrideBoss") or not isBoss then
			return C("tankHasAggro")
		end
	end
	-- 10. Non-tank no aggro
	if isThreatUnit and not isTank and threatStatus < 2 and InGroup() and P.On("dpsNoAggroEnabled") then
		if P.On("dpsNoAggroOverrideBoss") or not isBoss then
			return C("dpsNoAggro")
		end
	end
	-- 10b. Boss
	if isBoss then
		local r, g, b = C("boss")
		return MaybeDarken(r, g, b, inCombat)
	end
	-- 10c. Mini Enemies (tanks with Tank Has Aggro)
	if miniColorScope and (classification == "normal" or classification == "minus" or classification == "trivial") then
		local p = P.Profile()
		local r, g, b
		if p.miniEnemy then
			r, g, b = p.miniEnemy.r, p.miniEnemy.g, p.miniEnemy.b
		else
			r, g, b = C("enemyInCombat")
		end
		return MaybeDarken(r, g, b, inCombat)
	end
	-- 10d. Neutral, deferred (dungeons)
	if isNeutral then
		return ResolveNeutralColor(self)
	end
	-- 11. Fallback: enemy in / out of combat
	local r, g, b = C(owBasic and "owBasicColor" or "enemyInCombat")
	return MaybeDarken(r, g, b, inCombat)
end

-- Threat color for the Border / Text channels (retail ns.ResolveThreatColor):
-- what threat alone says, nil when it says nothing.
function Plate:ResolveThreatColor()
	if not threatColorsOn or self.threat == nil or self.isFriendly then return nil end
	local status = self.threat
	if P.IsTank() then
		if status >= 3 then
			if P.On("tankHasAggroEnabled") then return C("tankHasAggro") end
			return nil
		elseif status == 2 then
			return C("tankLosingAggro")
		end
		return C("tankNoAggro")
	end
	if not InGroup() then return nil end
	if status >= 3 then
		return C("dpsHasAggro")
	elseif status == 2 then
		return C("dpsNearAggro")
	end
	if P.On("dpsNoAggroEnabled") then
		return C("dpsNoAggro")
	end
	return nil
end

-------------------------------------------------------------------------------
--  Friendly plates (retail EllesmereUINameplatesFriendly.lua colors)
-------------------------------------------------------------------------------
function Plate:GetFriendlyColor()
	if self.kind == "FRIENDLY_PLAYER" then
		if P.On("classColorFriendly") and self.class then
			local c = ((EllesmereUI.GetClassColor and RAID_CLASS_COLORS[self.class] and EllesmereUI.GetClassColor(self.class)) or RAID_CLASS_COLORS[self.class])
			if c then return c.r, c.g, c.b end
		end
		return C("friendlyBarColor")
	end
	return C("friendlyNPCColor")
end
