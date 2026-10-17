-------------------------------------------------------------------------------
--  EUI_Nameplates_Init.lua: saved settings at ADDON_LOADED, the plate driver
--  at PLAYER_LOGIN, events, CVars, settings refresh, /enp.
--  ElvUI nameplates on = this module stands down (both would skin the same
--  Blizzard plates).
-------------------------------------------------------------------------------
local addonName, P = ...
local ns, ENP = P.ns, P.ENP

local pairs = pairs

-- ElvUI's own nameplates enabled on this character?
local function ElvUINameplatesOn()
	local E = ElvUI and ElvUI[1]
	return E and E.private and E.private.nameplates and E.private.nameplates.enable == true
end

function ENP:IsActive()
	return self.active == true
end

local function SetCVarSafe(name, value)
	if ns.SetCVarSafe then
		pcall(ns.SetCVarSafe, name, value)
	else
		pcall(SetCVar, name, value)
	end
end

-- CVars the plates need (class colors read from the Blizzard bar, cast bars
-- on every plate) and the ones the settings own (stacking, friendly plates).
function P.ApplyCVars()
	if InCombatLockdown() then
		P.AfterCombat("enpCVars", P.ApplyCVars)
		return
	end
	local p = P.Profile()
	SetCVarSafe("ShowClassColorInNameplate", "1")
	SetCVarSafe("showVKeyCastbar", "1")
	SetCVarSafe("showVKeyCastbarSpellName", "1")
	SetCVarSafe("showVKeyCastbarOnlyOnTarget", "0")
	SetCVarSafe("nameplateMotion", p.stackingEnabled ~= false and "1" or "0")
	SetCVarSafe("nameplateShowEnemyPets", p.showEnemyPets and "1" or "0")
	SetCVarSafe("nameplateShowEnemyGuardians", p.showEnemyPets and "1" or "0")
	SetCVarSafe("nameplateShowEnemyTotems", p.showEnemyPets and "1" or "0")
end

-------------------------------------------------------------------------------
--  Settings refresh (Options call ns.applyHooks after every change)
-------------------------------------------------------------------------------
function ENP:RefreshAll()
	if not self.active then return end
	P.RefreshThreatFlag()
	P.ApplyCVars()
	P.RefreshHasTarget()
	P.ForEachPlate(function(plate)
		if plate.shown then
			plate:Refresh()
		else
			plate:ApplyLayout()
		end
	end)
end

ns.applyHooks = ns.applyHooks or {}
table.insert(ns.applyHooks, function()
	if ENP.active then
		ENP:RefreshAll()
	end
end)

-------------------------------------------------------------------------------
--  Events
-------------------------------------------------------------------------------
local AURA_UNITS = {
	target = true, mouseover = true, focus = true,
	boss1 = true, boss2 = true, boss3 = true, boss4 = true,
	arena1 = true, arena2 = true, arena3 = true, arena4 = true, arena5 = true,
}

local function PlateForUnit(unit)
	local guid = UnitGUID(unit)
	return guid and ENP.byGUID[guid]
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")

local function OnEvent(self, event, ...)
	if event == "ADDON_LOADED" then
		if ... == addonName then
			ENP:InitDB()
		end
		return
	elseif event == "PLAYER_LOGIN" then
		if ElvUINameplatesOn() then
			ENP.active = false
			ENP.standDownReason = "ElvUI"
			return
		end
		ENP.active = true
		P.RefreshKick()
		P.RefreshExecute()
		P.RefreshRole()
		P.RefreshZone()
		P.RefreshGroup()
		P.RefreshArena()
		P.RefreshHasTarget()
		P.ApplyCVars()
		P.StartDriver()
		for _, e in ipairs({
			"PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
			"UPDATE_MOUSEOVER_UNIT", "RAID_TARGET_UPDATE", "GROUP_ROSTER_UPDATE", "ARENA_OPPONENT_UPDATE",
			"UNIT_PET", "UNIT_AURA", "UNIT_TARGET", "UNIT_ABSORB_AMOUNT_CHANGED", "COMBAT_LOG_EVENT_UNFILTERED",
			"PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "SPELL_UPDATE_COOLDOWN", "SPELLS_CHANGED",
			"PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_TALENT_UPDATE", "QUEST_LOG_UPDATE",
			"INSTANCE_ENCOUNTER_ENGAGE_UNIT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START",
		}) do
			self:RegisterEvent(e)
		end
		return
	end
	if not ENP.active then return end

	if event == "PLAYER_TARGET_CHANGED" then
		P.RefreshTargetInfo()
		P.RefreshHasTarget()
		if UnitExists("target") then
			P.Learn("target")
			P.LearnQuest("target")
		end
		P.ForEachVisible(function(plate) plate:ApplyAlpha() end)
	elseif event == "UPDATE_MOUSEOVER_UNIT" then
		if UnitExists("mouseover") then
			P.Learn("mouseover")
			P.LearnQuest("mouseover")
		end
	elseif event == "PLAYER_FOCUS_CHANGED" then
		P.ForEachVisible(function(plate)
			if plate:UpdateUnit() then
				plate:OnUnitChanged()
			else
				plate:UpdateColor()
				plate:UpdateFocus()
			end
			plate:ApplyAlpha()
		end)
	elseif event == "RAID_TARGET_UPDATE" then
		P.ForEachVisible(function(plate) plate:ReadState() end)
	elseif event == "GROUP_ROSTER_UPDATE" or event == "UNIT_PET" then
		P.RefreshGroup()
	elseif event == "ARENA_OPPONENT_UPDATE" then
		P.RefreshArena()
	elseif event == "UNIT_AURA" then
		local unit = ...
		if AURA_UNITS[unit] then
			local plate = PlateForUnit(unit)
			if plate and plate.shown then
				if plate.unit == unit then
					plate:UpdateAuras()
				else
					P.ScanAuras(unit)
					plate:UpdateAuras()
				end
			end
		end
	elseif event == "UNIT_TARGET" then
		local unit = ...
		local plate = AURA_UNITS[unit] and PlateForUnit(unit)
		if plate and plate.shown then
			plate:UpdateColor()
			plate:UpdateTexts()
			plate:RefreshCastTarget()
		end
	elseif event == "UNIT_ABSORB_AMOUNT_CHANGED" then
		local plate = PlateForUnit((...))
		if plate and plate.shown then plate:UpdateAbsorb() end
	elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
		local plate = PlateForUnit((...))
		if plate and plate.shown and plate.castShown then plate:RefreshCastTarget() end
	elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
		local _, sub, _, srcGUID, srcName, _, _, dstGUID, dstName, _, dstRaidFlags, spellId, spellName, _, auraType = ...
		if sub == "SPELL_INTERRUPT" then
			local plate = P.PlateForGUID(dstGUID, dstName, dstRaidFlags)
			if plate and plate.shown then
				plate:ShowInterrupted(P.StripRealm(srcName))
			end
		elseif sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REMOVED" or sub == "SPELL_AURA_REFRESH"
			or sub == "SPELL_AURA_APPLIED_DOSE" or sub == "UNIT_DIED" or sub == "UNIT_DESTROYED" then
			if P.AuraCombatLog(sub, srcGUID, dstGUID, spellId, spellName, auraType) then
				local plate = ENP.byGUID[dstGUID]
				if plate and plate.shown and not plate.unit then
					plate:UpdateAuras()
				end
			end
		end
	elseif event == "SPELL_UPDATE_COOLDOWN" then
		P.RefreshCastColors()
	elseif event == "SPELLS_CHANGED" then
		P.RefreshKick()
		P.RefreshExecute()
	elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
		P.RefreshRole()
		P.RefreshExecute()
		P.RefreshKick()
		P.ForEachVisible(function(plate) plate:UpdateColor() end)
	elseif event == "QUEST_LOG_UPDATE" then
		P.WipeQuestCache()
		P.ForEachVisible(function(plate) plate:UpdateClassification() end)
	elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
		P.RefreshZone()
		P.RefreshGroup()
		P.RefreshArena()
		P.WipeAuraCache()
		P.ApplyCVars()
	elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
		P._oocCombat = event == "PLAYER_REGEN_DISABLED"
		P.ForEachVisible(function(plate) plate:UpdateColor(); plate:ApplyAlpha() end)
	elseif event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
		P.ForEachVisible(function(plate)
			if plate:UpdateUnit() then plate:OnUnitChanged() end
		end)
	end
end
ev:SetScript("OnEvent", OnEvent)

-------------------------------------------------------------------------------
--  /enp opens the Nameplates settings
-------------------------------------------------------------------------------
SLASH_EUINAMEPLATES1 = "/enp"
SlashCmdList.EUINAMEPLATES = function(msg)
	-- /enp debug: what the plates look like to the stacking code.
	if msg and msg:lower():match("^%s*debug") then
		local p = P.Profile()
		print(("ENP debug: active=%s nameplateMotion=%s stackingEnabled=%s stackingFriendly=%s combat=%s"):format(
			tostring(ENP.active), tostring(GetCVar("nameplateMotion")), tostring(p.stackingEnabled),
			tostring(p.stackingFriendly), tostring(InCombatLockdown())))
		local r0, g0, b0
		P.ForEachVisible(function(plate)
			local w, h = plate.blizz:GetSize()
			local bw, bh = plate.bBar:GetSize()
			r0, g0, b0 = plate.bHealth:GetStatusBarColor()
			print(("  %s kind=%s friendly=%s blizz=%.3fx%.3f barFrame=%.3fx%.3f color=%.2f,%.2f,%.2f"):format(
				tostring(plate.name), tostring(plate.kind), tostring(plate.isFriendly), w or -1, h or -1,
				bw or -1, bh or -1, r0, g0, b0))
		end)
		return
	end
	if InCombatLockdown() then
		return
	end
	if ns.LoadOptions and ns.LoadOptions() and ns.OpenSettingsModule then
		ns.OpenSettingsModule("nameplates")
	end
end
