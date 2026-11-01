-- Run with Lua 5.1 from the repository root. No game installation is accessed.
assert(_VERSION == "Lua 5.1", "These checks must run on Lua 5.1.")

local passed, failures = 0, {}
local function Equal(actual, expected, label)
	assert(actual == expected, (label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function Test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed = passed + 1
		print("PASS " .. name)
	else
		failures[#failures + 1] = name .. ": " .. tostring(err)
		print("FAIL " .. failures[#failures])
	end
end

local frames, messages, locked = {}, {}, false
local playerGUID, partyGUID, petGUID = "0x0000000000000001", "0x0000000000000002", "0xF140000000000003"
local now, inCombat = 100, false
local Frame = {}
Frame.__index = Frame
function CreateFrame(kind, name, parent)
	local f = setmetatable({ scripts = {}, events = {}, shown = true, width = 300, height = 150, parent = parent }, Frame)
	frames[#frames + 1] = f
	if name then _G[name] = f end
	return f
end
function Frame:CreateTexture() return CreateFrame("Texture", nil, self) end
function Frame:CreateFontString() return CreateFrame("FontString", nil, self) end
function Frame:SetScript(event, fn) self.scripts[event] = fn end
function Frame:GetScript(event) return self.scripts[event] end
function Frame:SetPoint(...) self.point = { ... } end
function Frame:ClearAllPoints() self.point = nil end
function Frame:SetEnabled(enabled) self.enabled = enabled end
function Frame:HookScript(event, fn)
	local previous = self.scripts[event]
	self.scripts[event] = function(...)
		if previous then previous(...) end
		fn(...)
	end
end
function Frame:RegisterEvent(event) self.events[event] = true end
function Frame:UnregisterEvent(event) self.events[event] = nil end
function Frame:Hide() self.shown = false end
function Frame:Show() self.shown = true end
function Frame:SetShown(shown) if shown then self:Show() else self:Hide() end end
function Frame:IsShown() return self.shown end
function Frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function Frame:SetSize(w, h) self.width, self.height = w, h end
function Frame:SetWidth(w) self.width = w end
function Frame:SetHeight(h) self.height = h end
function Frame:GetWidth() return self.width end
function Frame:GetHeight() return self.height end
function Frame:SetText(text) self.text = text end
function Frame:GetText() return self.text end
function Frame:GetStringWidth() return #(self.text or "") * 6 end
function Frame:GetStringHeight() return 12 end
function Frame:SetFont(path, size, flags) self.font = { path, size, flags } end
function Frame:GetFont() return unpack(self.font or { "font", 12, "" }) end
function Frame:SetAlpha(alpha) self.alpha = alpha end
function Frame:GetAlpha() return self.alpha or 1 end
function Frame:SetScale(scale) self.scale = scale end
function Frame:GetScale() return self.scale or 1 end
function Frame:GetEffectiveScale() return self:GetScale() end
function Frame:SetFrameLevel(level) self.level = level end
function Frame:GetFrameLevel() return self.level or 1 end
function Frame:SetFrameStrata(strata) self.strata = strata end
function Frame:GetFrameStrata() return self.strata or "MEDIUM" end
function Frame:GetLeft() return 100 end
function Frame:GetRight() return 100 + self.width end
function Frame:GetTop() return 800 end
function Frame:GetBottom() return 800 - self.height end
function Frame:GetCenter() return 500, 500 end
function Frame:SetParent(parent) self.parent = parent end
function Frame:GetParent() return self.parent end
function Frame:SetValue(value) self.value = value end
function Frame:GetValue() return self.value end
function Frame:SetMinMaxValues(low, high) self.low, self.high = low, high end
function Frame:SetVerticalScroll(value) self.scroll = value end
function Frame:GetVerticalScroll() return self.scroll or 0 end
function Frame:SetTexture(...) self.texture = { ... } end
function Frame:SetStatusBarTexture(texture) self.texture = texture end
function Frame:GetStatusBarTexture()
	if not self.statusTexture then self.statusTexture = self:CreateTexture() end
	return self.statusTexture
end
function Frame:IsMouseOver() return false end
function Frame:IsOwned(owner) return self.owner == owner end
function Frame:SetOwner(owner) self.owner = owner end
local noop = function() end
for _, method in ipairs({
	"SetAllPoints", "SetClampedToScreen", "SetMovable", "SetResizable",
	"SetMinResize", "SetMaxResize", "EnableMouse", "EnableMouseWheel", "SetHitRectInsets",
	"SetJustifyH", "SetJustifyV", "SetWordWrap", "SetTextColor", "SetVertexColor", "SetTexCoord",
	"SetStatusBarColor", "SetScrollChild", "RegisterForClicks", "RegisterForDrag",
	"SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetBlendMode",
	"SetHighlightTexture", "SetNormalTexture", "SetShadowColor", "SetShadowOffset",
	"SetDrawLayer", "SetDesaturated", "StartMoving", "StopMovingOrSizing", "StartSizing",
	"SetAutoFocus", "SetMaxLetters", "SetNumeric", "SetTextInsets", "ClearFocus",
}) do
	Frame[method] = noop
end

UIParent = CreateFrame("Frame")
UIParent:SetSize(2560, 1440)
GameTooltip = CreateFrame("GameTooltip")
UISpecialFrames = {}
format = string.format
function GetTime() return now end
function InCombatLockdown() return locked end
function UnitAffectingCombat() return inCombat end
local UNITS = { player = { playerGUID, "Alex", "HUNTER" }, party1 = { partyGUID, "Casey", "MAGE" }, playerpet = { petGUID, "Wolf" } }
function UnitName(unit) local u = UNITS[unit or "player"]; return u and u[2] end
function UnitGUID(unit) local u = UNITS[unit or "player"]; return u and u[1] end
function UnitClass(unit) local u = UNITS[unit or "player"]; return u and u[3], u and u[3] end
function IsInInstance() return true, "party" end
function IsInGroup() return true end
function IsInRaid() return false end
function GetNumGroupMembers() return 2 end
function GetSpecialization() return 1 end
function GetSpecializationInfo() return 253 end
function GetInspectSpecialization() return 0 end
function GetPlayerInfoByGUID() return nil, nil end
function UnitIsFeignDeath() return false end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function GetInstanceInfo() return "Dungeon", "party", 1 end
function GetCursorPosition() return 500, 500 end
function GetSpellInfo(id) return "Spell " .. id, nil, "Icon" .. id end
function GetSpecializationInfoByID(id) return id, "Spec", "", "SpecIcon" end
function IsAddOnLoaded(name) return name == "EllesmereUIDamageMeters" end
function geterrorhandler() return error end
ClearOverrideBindings, SetOverrideBindingClick = noop, noop
RAID_CLASS_COLORS = { HUNTER = { r = 0.67, g = 0.83, b = 0.45 }, MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
local function Bits(a, b, both)
	local result, place = 0, 1
	while a > 0 or b > 0 do
		local x, y = a % 2 == 1, b % 2 == 1
		if (both and x and y) or (not both and (x or y)) then result = result + place end
		a, b, place = math.floor(a / 2), math.floor(b / 2), place * 2
	end
	return result
end
bit = { band = function(a, b) return Bits(a, b, true) end, bor = function(a, b) return Bits(a, b, false) end }

EllesmereUIDamageMetersDB = {}
EllesmereUI = {
	Print = function(message) messages[#messages + 1] = message end,
	ModuleDB = function(name) _G[name] = _G[name] or {}; return _G[name] end,
	ApplyModuleFont = function(fs, size, _, flags) fs:SetFont("font", size, flags or "") end,
	MakeUnlockElement = function(def) return def end,
	RegisterUnlockElements = function(_, list) EllesmereUI.unlockList = list end,
	SetSpellHistoryPreview = noop,
	ResetSpellHistorySettings = noop,
}

local function Fire(event, ...)
	for _, frame in ipairs(frames) do
		if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
	end
end

local ME, PARTY, PET, BOSS, ADD, NPC = 0x511, 0x512, 0x1111, 0xa48, 0xa48, 0xa18
local BOSS_GUID, ADD_GUID = "0xF130000000000010", "0xF130000000000011"

assert(loadfile("EllesmereUIDamageMeters/EllesmereUIDamageMeters_Engine.lua"))("EllesmereUIDamageMeters")
assert(loadfile("EllesmereUIDamageMeters/EllesmereUIDamageMeters_Meter.lua"))("EllesmereUIDamageMeters")
local E, DM = EllesmereUI.EDMEngine, EllesmereUI.EDM
local T = DM.T

local function Log(event, sG, sN, sF, dG, dN, dF, ...)
	E.OnCombatLog(now, event, false, sG, sN, sF, 0, dG, dN, dF, 0, ...)
end
local function Tick(seconds)
	now = now + seconds
	for _, frame in ipairs(frames) do
		if frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, seconds) end
	end
end
local function Sum(list)
	local n = 0
	for _, e in ipairs(list) do n = n + e.amount end
	return n
end

Fire("ADDON_LOADED", "EllesmereUIDamageMeters")
Fire("PLAYER_LOGIN")
Fire("GROUP_ROSTER_UPDATE")

Test("no fight and no data before combat", function()
	Equal(E.InCombat(), false); Equal(E.GetCurrent(), nil)
	Equal(#DM.GetSources(E.GetCurrent(), T.DamageDone), 0)
	-- Friendly-only events never start a fight.
	Log("SPELL_HEAL", playerGUID, "Alex", ME, partyGUID, "Casey", PARTY, 100, "Heal", 2, 500, 0, 0, nil)
	Log("SPELL_DAMAGE", playerGUID, "Alex", ME, partyGUID, "Casey", PARTY, 100, "Hit", 2, 500, 0)
	Equal(E.InCombat(), false)
end)

Test("damage by the group starts a fight and is credited to the owner with pets", function()
	inCombat = true
	Log("SPELL_DAMAGE", playerGUID, "Alex", ME, BOSS_GUID, "Boss", BOSS, 100, "Arcane Shot", 64, 1000, -1, 64, 0, 0, 0)
	Equal(E.InCombat(), true)
	Tick(1)
	Log("SWING_DAMAGE", playerGUID, "Alex", ME, BOSS_GUID, "Boss", BOSS, 400, -1, 1, 0, 0, 0)
	Log("SWING_DAMAGE", petGUID, "Wolf", PET, BOSS_GUID, "Boss", BOSS, 600, -1, 1, 0, 0, 0)
	Log("SPELL_DAMAGE", partyGUID, "Casey", PARTY, ADD_GUID, "Add", ADD, 200, "Frostbolt", 16, 1500, -1, 16, 0, 0, 0)
	-- Damage to a friendly NPC is not damage done.
	Log("SPELL_DAMAGE", partyGUID, "Casey", PARTY, "0xF1", "Guard", NPC, 200, "Frostbolt", 16, 9999, -1, 16, 0, 0, 0)
	Tick(1)
	local rows, duration = DM.GetSources(E.GetCurrent(), T.DamageDone)
	Equal(#rows, 2); Equal(duration, 2)
	Equal(rows[1].name, "Alex"); Equal(rows[1].total, 2000); Equal(rows[1].perSec, 1000)
	Equal(rows[1].isLocalPlayer, true); Equal(rows[1].class, "HUNTER"); Equal(rows[1].spec, 253)
	Equal(rows[2].name, "Casey"); Equal(rows[2].total, 1500); Equal(rows[2].class, "MAGE")
	local spells = DM.GetBreakdown(E.GetCurrent(), T.DamageDone, rows[1])
	Equal(#spells, 3); Equal(Sum(spells), 2000)
	Equal(spells[1].label, "Spell 100"); Equal(spells[2].label, "Melee (Wolf)"); Equal(spells[2].amount, 600)
	Equal(spells[3].label, "Melee"); Equal(spells[3].amount, 400)
end)

Test("enemy damage taken lists enemies with the players who hit them", function()
	local enemies = DM.GetSources(E.GetCurrent(), T.EnemyDamageTaken)
	Equal(#enemies, 2); Equal(enemies[1].name, "Boss"); Equal(enemies[1].total, 2000)
	local attackers = DM.GetBreakdown(E.GetCurrent(), T.EnemyDamageTaken, enemies[1])
	Equal(#attackers, 1); Equal(attackers[1].label, "Alex"); Equal(attackers[1].amount, 2000)
end)

Test("damage taken, healing, overhealing and shield absorbs", function()
	Log("SPELL_DAMAGE", BOSS_GUID, "Boss", BOSS, playerGUID, "Alex", ME, 900, "Smash", 1, 3000, -1, 1, 0, 0, 0)
	Log("SPELL_AURA_APPLIED", partyGUID, "Casey", PARTY, playerGUID, "Alex", ME, 17, "Power Word: Shield", 2, "BUFF", 5000)
	Log("SPELL_DAMAGE", BOSS_GUID, "Boss", BOSS, playerGUID, "Alex", ME, 900, "Smash", 1, 1000, -1, 1, 0, 0, 800)
	Log("SPELL_MISSED", BOSS_GUID, "Boss", BOSS, playerGUID, "Alex", ME, 900, "Smash", 1, "ABSORB", false, 700)
	Log("SPELL_HEAL", partyGUID, "Casey", PARTY, playerGUID, "Alex", ME, 2061, "Flash Heal", 2, 2000, 500, 0, nil)
	local taken = DM.GetSources(E.GetCurrent(), T.DamageTaken)
	Equal(#taken, 1); Equal(taken[1].total, 4000)
	local from = DM.GetBreakdown(E.GetCurrent(), T.DamageTaken, taken[1])
	Equal(from[1].label, "Boss"); Equal(from[1].amount, 4000)
	local heals = DM.GetSources(E.GetCurrent(), T.HealingDone)
	Equal(#heals, 1); Equal(heals[1].name, "Casey"); Equal(heals[1].total, 1500 + 800 + 700)
	local spells = DM.GetBreakdown(E.GetCurrent(), T.HealingDone, heals[1])
	Equal(spells[1].spellID, 17); Equal(spells[1].amount, 1500)
	-- A removed shield still takes the absorb logged right after it, then expires.
	Log("SPELL_AURA_REMOVED", partyGUID, "Casey", PARTY, playerGUID, "Alex", ME, 17, "Power Word: Shield", 2, "BUFF", 0)
	Log("SPELL_MISSED", BOSS_GUID, "Boss", BOSS, playerGUID, "Alex", ME, 900, "Smash", 1, "ABSORB", false, 100)
	Tick(1)
	Log("SPELL_MISSED", BOSS_GUID, "Boss", BOSS, playerGUID, "Alex", ME, 900, "Smash", 1, "ABSORB", false, 100)
	Equal(DM.GetSources(E.GetCurrent(), T.HealingDone)[1].total, 3100)
end)

Test("interrupts and dispels", function()
	Log("SPELL_INTERRUPT", playerGUID, "Alex", ME, BOSS_GUID, "Boss", BOSS, 147362, "Counter Shot", 1, 5000, "Fireball", 4)
	Log("SPELL_INTERRUPT", petGUID, "Wolf", PET, BOSS_GUID, "Boss", BOSS, 50318, "Serenity Dust", 1, 5000, "Fireball", 4)
	Log("SPELL_DISPEL", partyGUID, "Casey", PARTY, playerGUID, "Alex", ME, 475, "Remove Curse", 64, 6000, "Curse", 32, "DEBUFF")
	local ints = DM.GetSources(E.GetCurrent(), T.Interrupts)
	Equal(#ints, 1); Equal(ints[1].total, 2)
	Equal(#DM.GetBreakdown(E.GetCurrent(), T.Interrupts, ints[1]), 2)
	local disp = DM.GetSources(E.GetCurrent(), T.Dispels)
	Equal(disp[1].name, "Casey"); Equal(disp[1].total, 1)
end)

Test("deaths keep a recap, newest event first", function()
	Log("UNIT_DIED", nil, nil, 0, playerGUID, "Alex", ME)
	local deaths = DM.GetSources(E.GetCurrent(), T.Deaths)
	Equal(#deaths, 1); Equal(deaths[1].isLocalPlayer, true); Equal(deaths[1].class, "HUNTER")
	local recap = DM.GetBreakdown(E.GetCurrent(), T.Deaths, deaths[1])
	assert(#recap >= 4, "recap events")
	Equal(recap[1].label, "Spell 17"); Equal(recap[1].heal, true); Equal(recap[1].amount, 100)
	local hit
	for _, e in ipairs(recap) do if not e.heal then hit = hit or e end end
	Equal(hit.label, "Spell 900"); Equal(hit.source, "Boss"); Equal(hit.ago, -1)
end)

Test("activity time option", function()
	DM.DB().timeType = "activity"
	local rows = DM.GetSources(E.GetCurrent(), T.DamageDone)
	Equal(rows[1].perSec, 2000) -- one active second (min 1)
	DM.DB().timeType = "effective"
end)

Test("the fight ends when the group leaves combat and becomes a segment", function()
	Tick(0.5)
	Equal(E.InCombat(), true)
	inCombat = false
	Tick(0.5)
	Equal(E.InCombat(), false)
	local segs = DM.GetSegments()
	Equal(#segs, 1); Equal(segs[1].name, "Boss"); Equal(segs[1].time, 4)
	Equal(E.GetCurrent(), segs[1].combat)
	local overall = DM.GetSources(E.GetOverall(), T.DamageDone)
	Equal(overall[1].total, 2000); Equal(DM.CombatTime(E.GetOverall()), 4)
end)

Test("encounters name the fight and the overall resets for a new boss", function()
	Fire("ENCOUNTER_START", 1, "Immerseus", 3, 10)
	inCombat = true
	Equal(E.InCombat(), true)
	Log("SPELL_DAMAGE", playerGUID, "Alex", ME, BOSS_GUID, "Immerseus", BOSS, 100, "Shot", 1, 500, -1, 1, 0, 0, 0)
	Tick(3)
	inCombat = false
	Tick(1)
	Equal(E.InCombat(), true) -- boss fights wait for ENCOUNTER_END
	Fire("ENCOUNTER_END", 1, "Immerseus", 3, 10, 1)
	Equal(E.InCombat(), false)
	Equal(DM.GetSegments()[1].name, "Immerseus")
	Fire("ENCOUNTER_START", 2, "Fallen Protectors", 3, 10)
	Equal(#DM.GetSources(E.GetOverall(), T.DamageDone), 0)
	Fire("ENCOUNTER_END", 2, "Fallen Protectors", 3, 10, 0)
	Tick(1)
	Equal(#DM.GetSegments(), 2) -- the empty pull is dropped
end)

Test("stored fights are capped and reset clears everything", function()
	DM.DB().segmentsToKeep = 2
	for i = 1, 3 do
		inCombat = true
		Log("SPELL_DAMAGE", playerGUID, "Alex", ME, ADD_GUID, "Add " .. i, ADD, 100, "Shot", 1, 10, -1, 1, 0, 0, 0)
		Tick(3)
		inCombat = false
		Tick(1)
	end
	Equal(#DM.GetSegments(), 2); Equal(DM.GetSegments()[1].name, "Add 3")
	DM.DB().segmentsToKeep = 18
	inCombat = true
	Log("SPELL_DAMAGE", playerGUID, "Alex", ME, ADD_GUID, "Add", ADD, 100, "Shot", 1, 10, -1, 1, 0, 0, 0)
	Equal(DM.ResetData(), false) -- blocked in combat
	inCombat = false
	Tick(1)
	Equal(DM.ResetData(), true)
	Equal(#DM.GetSegments(), 0); Equal(E.GetCurrent(), nil)
	Equal(#DM.GetSources(E.GetOverall(), T.DamageDone), 0)
end)

Test("your death right after the fight ended still joins it", function()
	-- Dying drops you out of combat, so the fight can end before UNIT_DIED.
	inCombat = true
	Log("SPELL_DAMAGE", ADD_GUID, "Add", ADD, playerGUID, "Alex", ME, 900, "Smash", 1, 5000, -1, 1, 0, 0, 0)
	Tick(1)
	inCombat = false
	Fire("PLAYER_REGEN_ENABLED")
	Equal(E.InCombat(), false)
	Equal(#DM.GetSegments(), 0) -- one second: too short to keep on its own
	Log("UNIT_DIED", nil, nil, 0, playerGUID, "Alex", ME)
	Equal(#DM.GetSegments(), 1)
	local deaths = DM.GetSources(E.GetCurrent(), T.Deaths)
	Equal(#deaths, 1); Equal(deaths[1].isLocalPlayer, true)
	-- PLAYER_DEAD for the same death is not counted twice.
	Fire("PLAYER_DEAD")
	Equal(#DM.GetSources(E.GetCurrent(), T.Deaths), 1)
	Equal(#DM.GetSources(E.GetOverall(), T.Deaths), 1)
end)

Test("PLAYER_DEAD records your death when the combat log does not", function()
	Tick(10)
	inCombat = true
	Log("SPELL_DAMAGE", ADD_GUID, "Add", ADD, playerGUID, "Alex", ME, 900, "Smash", 1, 5000, -1, 1, 0, 0, 0)
	Tick(3)
	Fire("PLAYER_DEAD")
	inCombat = false
	Tick(1)
	local deaths = DM.GetSources(E.GetCurrent(), T.Deaths)
	Equal(#deaths, 1); Equal(deaths[1].isLocalPlayer, true)
	Equal(#DM.GetBreakdown(E.GetCurrent(), T.Deaths, deaths[1]), 1)
	Equal(DM.ResetData(), true)
end)

Test("windows render engine data, breakdowns and the empty message", function()
	Equal(#DM.windows, DM.DB().windowCount)
	local window = DM.windows[1]
	window.curSessionID, window.curSession = nil, DM.S.Current
	window.SetDMType(T.DamageDone)
	Equal(window.count, 0); Equal(window.msg:GetText(), "No combat data")
	inCombat = true
	Log("SPELL_DAMAGE", playerGUID, "Alex", ME, BOSS_GUID, "Boss", BOSS, 100, "Shot", 1, 2000, -1, 1, 0, 0, 0)
	Log("SPELL_DAMAGE", partyGUID, "Casey", PARTY, BOSS_GUID, "Boss", BOSS, 101, "Bolt", 1, 1000, -1, 1, 0, 0, 0)
	Tick(20)
	window.Refresh()
	Equal(window.count, 2); Equal(window.rows[1].label:GetText(), "Alex")
	Equal(window.msg:IsShown(), false)
	window.OpenSource(window.sources[1])
	Equal(window.srcCount, 1)
	window.CloseSource()
	inCombat = false
	Tick(1)
	window.curSessionID = DM.GetSegments()[1].combat
	window.Refresh()
	Equal(window.count, 2)
	DM.ResetData()
	Equal(window.curSessionID, nil)
end)

Test("Combat Data tab edits the engine settings", function()
	local module
	EllesmereUI.RegisterSettingsModule = function(def) module = def end
	EllesmereUI.OptionsUtil = {
		KeyItems = function(items) return items end,
		KeyLabel = function(items, value)
			for _, item in ipairs(items) do if item.key == value then return item.text end end
			return "Unavailable"
		end,
	}
	assert(loadfile("EllesmereUIOptions/EUI_DamageMeters_Options.lua"))("EllesmereUIOptions")
	local page
	for _, tab in ipairs(module.tabs) do if tab.key == "combatData" then page = tab end end
	assert(page, "Combat Data tab must be registered")
	local controls = {}
	local recorder = { Section = noop, Paragraph = noop, Button = noop }
	function recorder:Toggle(label, _, get, set) controls[label] = { get = get, set = set } end
	function recorder:Slider(label, _, low, high, step, get, set) controls[label] = { get = get, set = set } end
	function recorder:Dropdown(label, _, items, get, getLabel, set) controls[label] = { get = get, set = set, label = getLabel } end
	page.build(recorder)
	Equal(controls["Stored Combat Segments"].get(), 18)
	controls["Stored Combat Segments"].set(5); Equal(DM.DB().segmentsToKeep, 5)
	Equal(controls["DPS / HPS Time Measurement"].label(), "Effective Time")
	controls["DPS / HPS Time Measurement"].set("activity"); Equal(DM.DB().timeType, "activity")
	controls["Reset Overall for a New Raid Boss"].set(false); Equal(DM.DB().overallClearNewBoss, false)
	local meter
	for _, tab in ipairs(module.tabs) do if tab.key == "damageMeters" then meter = tab end end
	local all = setmetatable({}, { __index = function() return noop end })
	meter.build(all)
end)

Test("boss pulls are numbered with kill or wipe and boss health; trash folds together", function()
	DM.DB().segmentsToKeep = 18
	Equal(DM.ResetData(), true)
	local bossHP = 100
	function UnitExists(unit) return unit == "boss1" end
	function UnitHealth() return bossHP end
	function UnitHealthMax() return 100 end
	local function Trash(name)
		inCombat = true
		Log("SPELL_DAMAGE", playerGUID, "Alex", ME, ADD_GUID, name, ADD, 100, "Shot", 1, 10, -1, 1, 0, 0, 0)
		Tick(3)
		inCombat = false
		Tick(1)
	end
	local function Pull(hpLeft, success)
		Fire("ENCOUNTER_START", 1, "Immerseus", 3, 10)
		inCombat = true
		bossHP = 100
		Log("SPELL_DAMAGE", playerGUID, "Alex", ME, BOSS_GUID, "Immerseus", BOSS, 100, "Shot", 1, 500, -1, 1, 0, 0, 0)
		Tick(1)
		bossHP = hpLeft
		Tick(1)
		bossHP = 100 -- the boss resets after a wipe
		Fire("ENCOUNTER_END", 1, "Immerseus", 3, 10, success)
		inCombat = false
		Tick(1)
	end
	Trash("Add A"); Trash("Add B")
	Pull(34.4, 0)
	Pull(0, 1)
	Trash("Add C")
	Pull(80, 0) -- the counter starts over after a kill
	-- The server's moment of encounter right after a wipe is no try; its deaths join the wipe.
	Fire("ENCOUNTER_START", 1, "Immerseus", 3, 10)
	Log("UNIT_DIED", nil, nil, 0, partyGUID, "Casey", PARTY)
	Tick(1)
	Fire("ENCOUNTER_END", 1, "Immerseus", 3, 10, 0)
	Tick(1)
	-- Same with no damage at all, however long it lasts.
	Fire("ENCOUNTER_START", 1, "Immerseus", 3, 10)
	Log("SPELL_DAMAGE", BOSS_GUID, "Immerseus", BOSS, playerGUID, "Alex", ME, 200, "Swell", 1, 100, -1, 1, 0, 0, 0)
	for _ = 1, 30 do Tick(0.5) end
	-- A moment of combat in the reset ("Combat", 0:00): someone dies, nobody does anything.
	inCombat = true
	Log("SPELL_DAMAGE", ADD_GUID, "Add", ADD, playerGUID, "Alex", ME, 300, "Smash", 1, 100, -1, 1, 0, 0, 0)
	Log("UNIT_DIED", nil, nil, 0, playerGUID, "Alex", ME)
	inCombat = false
	Tick(0.5)
	-- A pull in which the boss is never touched.
	Fire("ENCOUNTER_START", 1, "Immerseus", 3, 10)
	inCombat = true
	bossHP = 100
	Log("SPELL_DAMAGE", playerGUID, "Alex", ME, ADD_GUID, "Add", ADD, 100, "Shot", 1, 50, -1, 1, 0, 0, 0)
	Tick(6)
	Fire("ENCOUNTER_END", 1, "Immerseus", 3, 10, 0)
	inCombat = false
	Tick(1)
	-- Away from a wipe, being hit without doing anything (and nobody dying) is no fight.
	Tick(120)
	inCombat = true
	Log("SPELL_DAMAGE", ADD_GUID, "Add", ADD, playerGUID, "Alex", ME, 300, "Smash", 1, 100, -1, 1, 0, 0, 0)
	Tick(3)
	inCombat = false
	Tick(1)
	local segs = DM.GetSegments()
	Equal(#segs, 6)
	Equal(DM.SegmentLabel(segs[1]), "Immerseus #1  |cffff5f5fWipe 80%|r")
	Equal(#segs[1].combat.deaths, 2)
	Fire("ENCOUNTER_START", 1, "Immerseus", 3, 10)
	Equal(E.GetCurrent().try, 2) -- the next real pull is #2
	Fire("ENCOUNTER_END", 1, "Immerseus", 3, 10, 0)
	Tick(1)
	Equal(DM.SegmentLabel(segs[3]), "Immerseus #2  |cff5fd35fKill|r")
	Equal(DM.SegmentLabel(segs[4]), "Immerseus #1  |cffff5f5fWipe 34%|r")
	Equal(DM.SegmentLabel(segs[2]), "Add C")
	local window = DM.windows[1]
	window.curSessionID = segs[6].combat
	local items = DM.SegmentMenuItems(window)
	Equal(items[1].text, "Trash (2)"); Equal(items[1].isActive, true)
	Equal(items[1].children[1].text, "Add A"); Equal(items[1].children[2].text, "Add B")
	Equal(items[2].text, "Immerseus #1  |cffff5f5fWipe 34%|r")
	Equal(items[4].text, "Add C") -- a single trash fight stays on its own
	Equal(items[6], "---"); Equal(items[7].text, "Current")
	-- Mouse wheel on the header steps through the fights; the title names the fight.
	window.curSessionID, window.curSession = nil, DM.S.Current
	window.StepSegment(1)
	Equal(window.curSessionID, segs[2].combat)
	window.StepSegment(1); window.StepSegment(1)
	Equal(window.curSessionID, segs[4].combat)
	Equal(window.fullTitle, "Immerseus #1 - " .. DM.TYPE_NAMES[window.curDMType])
	for _ = 1, 10 do window.StepSegment(1) end
	Equal(window.curSessionID, segs[6].combat) -- stops at the oldest
	for _ = 1, 10 do window.StepSegment(-1) end
	Equal(window.curSessionID, nil); Equal(window.curSession, DM.S.Current)
	window.curSessionID = nil
	UnitExists, UnitHealth, UnitHealthMax = nil, nil, nil
end)

Test("fights and Overall survive a reload, a fight in progress included", function()
	DM.DB().segmentsToKeep = 18; DM.DB().timeType = "effective"
	Equal(DM.ResetData(), true)
	inCombat = true
	Log("SPELL_DAMAGE", playerGUID, "Alex", ME, BOSS_GUID, "Boss", BOSS, 100, "Shot", 1, 600, -1, 1, 0, 0, 0)
	Tick(5)
	Log("UNIT_DIED", nil, nil, 0, partyGUID, "Casey", PARTY)
	inCombat = false
	Tick(1)
	Tick(10)
	inCombat = true
	Log("SPELL_DAMAGE", playerGUID, "Alex", ME, ADD_GUID, "Add", ADD, 100, "Shot", 1, 50, -1, 1, 0, 0, 0)
	Tick(3)
	Fire("PLAYER_LOGOUT") -- /reload during the second fight
	local saved = EllesmereUIDamageMetersFights
	assert(type(saved) == "table", "fights must be saved at logout")
	-- A fresh engine (the reload), with GetTime() starting over.
	for _, frame in ipairs(frames) do frame.events = {} end
	now, inCombat = 5, false
	EllesmereUIDamageMetersFights = saved
	assert(loadfile("EllesmereUIDamageMeters/EllesmereUIDamageMeters_Engine.lua"))("EllesmereUIDamageMeters")
	E = EllesmereUI.EDMEngine
	Fire("ADDON_LOADED", "EllesmereUIDamageMeters")
	Equal(EllesmereUIDamageMetersFights, nil)
	local segs = DM.GetSegments()
	Equal(#segs, 2); Equal(segs[1].name, "Add"); Equal(segs[2].name, "Boss")
	Equal(segs[2].time, 6)
	Equal(DM.GetSources(segs[2].combat, T.DamageDone)[1].total, 600)
	Equal(#DM.GetSources(segs[2].combat, T.Deaths), 1)
	Equal(E.GetCurrent(), segs[1].combat)
	Equal(DM.GetSources(E.GetOverall(), T.DamageDone)[1].total, 650)
	-- Recording carries on into the restored Overall.
	inCombat = true
	Log("SPELL_DAMAGE", playerGUID, "Alex", ME, ADD_GUID, "Add", ADD, 100, "Shot", 1, 50, -1, 1, 0, 0, 0)
	Tick(3)
	inCombat = false
	Tick(1)
	Equal(#DM.GetSegments(), 3)
	Equal(DM.GetSources(E.GetOverall(), T.DamageDone)[1].total, 700)
end)

Test("death recaps keep 32 events with health, overkill and absorbs, like Details", function()
	Fire("GROUP_ROSTER_UPDATE") -- the engine reloaded above; learn the group again
	local hp = 1000
	UnitHealth, UnitHealthMax = function() return hp end, function() return 1000 end
	Log("SPELL_AURA_APPLIED", partyGUID, "Casey", PARTY, partyGUID, "Casey", PARTY, 17, "Power Word: Shield", 2, "BUFF", 5000)
	for i = 1, 40 do
		hp = hp - 20
		Log("SPELL_DAMAGE", BOSS_GUID, "Boss", BOSS, partyGUID, "Casey", PARTY, 901, "Tick", 1, 20, -1, 1, 0, 0, 0)
	end
	Log("SPELL_MISSED", BOSS_GUID, "Boss", BOSS, partyGUID, "Casey", PARTY, 901, "Tick", 1, "ABSORB", false, 50)
	hp = 0
	Log("SPELL_DAMAGE", BOSS_GUID, "Boss", BOSS, partyGUID, "Casey", PARTY, 902, "Smash", 1, 900, 700, 1, 0, 0, 0)
	Log("UNIT_DIED", nil, nil, 0, partyGUID, "Casey", PARTY)
	UnitHealth, UnitHealthMax = nil, nil
	local deaths = DM.GetSources(E.GetCurrent(), T.Deaths)
	local recap = DM.GetBreakdown(E.GetCurrent(), T.Deaths, deaths[#deaths])
	Equal(deaths[#deaths].name, "Casey")
	Equal(#recap, 32); Equal(recap.hasHP, true, "hasHP")
	Equal(recap[1].label, "Spell 902"); Equal(recap[1].hp, 0); Equal(recap[1].overkill, 700)
	Equal(recap[2].shield, true, "shield"); Equal(recap[2].heal, true); Equal(recap[2].amount, 50)
	Equal(recap[3].hp, 20); Equal(recap[32].hp, 78) -- the 30 newest of 40 ticks
	local label, amount = DM.DeathLine(recap[1])
	assert(label:find("Spell 902", 1, true) and label:find("Boss", 1, true) and label:find("700 overkill", 1, true), label)
	assert(amount:find("900", 1, true) and amount:find(" 0%", 1, true), amount)
	label = DM.DeathLine(recap[2])
	assert(label:find("(absorb)", 1, true), label)
end)

Test("your death recap opens under the Release Spirit popup", function()
	local hooks, popup = {}, CreateFrame("Frame", "StaticPopup1", UIParent)
	popup.which, popup.width = "DEATH", 320
	function hooksecurefunc(name, fn) hooks[name] = fn end
	function StaticPopup_Visible(which) return popup:IsShown() and popup.which == which and "StaticPopup1" or nil end
	local dead = true
	function UnitIsDeadOrGhost() return dead end
	assert(loadfile("EllesmereUIDamageMeters/EllesmereUIDamageMeters_DeathRecap.lua"))("EllesmereUIDamageMeters")
	Tick(6)
	Log("SPELL_DAMAGE", BOSS_GUID, "Boss", BOSS, playerGUID, "Alex", ME, 903, "Crush", 1, 5000, 1200, 1, 0, 0, 0)
	popup:Show()
	hooks.StaticPopup_Show("DEATH") -- Blizzard shows the popup before the engine hears of the death
	Tick(0.2)
	local panel = EllesmereUIDMDeathRecap
	Equal(panel ~= nil and panel:IsShown() or false, false, "no death yet")
	Log("UNIT_DIED", nil, nil, 0, playerGUID, "Alex", ME)
	Tick(0.2)
	panel = EllesmereUIDMDeathRecap
	Equal(panel:IsShown(), true, "shown")
	assert(panel.sub:GetText():find("Killed by Spell 903", 1, true), panel.sub:GetText())
	-- Collapsed to the "Killed by" line by default; a click anywhere expands it (remembered).
	Equal(panel.lines[1] and panel.lines[1]:IsShown() or false, false, "collapsed by default")
	assert(panel.title:GetText():find("click to expand", 1, true), panel.title:GetText())
	panel.scripts.OnMouseUp(panel, "LeftButton")
	Equal(panel.lines[1]:IsShown(), true, "expanded"); Equal(DM.DB().deathRecapExpanded, true)
	assert(panel.lines[1].name:GetText():find("Spell 903", 1, true), panel.lines[1].name:GetText())
	assert(panel.title:GetText():find("click to collapse", 1, true), panel.title:GetText())
	panel.scripts.OnMouseUp(panel, "RightButton")
	Equal(panel.lines[1]:IsShown(), true, "right click does nothing")
	panel.scripts.OnMouseUp(panel, "LeftButton")
	Equal(panel.lines[1]:IsShown(), false, "collapsed again"); Equal(DM.DB().deathRecapExpanded, false)
	-- A resurrection offer replaces the DEATH popup: the recap stays, under it.
	popup.which = "RESURRECT"
	Tick(0.3)
	Equal(panel:IsShown(), true, "kept for the resurrection offer")
	popup:Hide(); Tick(0.3)
	Equal(panel:IsShown(), true, "kept while dead without a popup")
	-- Alive again: gone at once, even while UnitIsDeadOrGhost still says dead.
	local hp = 1 -- a corpse can read 1
	UnitHealth = function() return hp end
	Fire("UNIT_HEALTH", "player")
	Equal(panel:IsShown(), true, "still dead")
	hp = 5000
	Fire("UNIT_HEALTH", "party1")
	Equal(panel:IsShown(), true, "someone else's health")
	Fire("UNIT_HEALTH", "player")
	Equal(panel:IsShown(), false, "hidden once alive")
	UnitHealth = nil
	dead = false
	popup.which = "DEATH"; dead = true
	DM.DB().deathRecapPopup = false
	popup:Show(); hooks.StaticPopup_Show("DEATH"); Tick(0.2)
	Equal(panel:IsShown(), false, "option off")
	DM.DB().deathRecapPopup = nil
	-- A hit long before the death is not the killing blow.
	Tick(6)
	Log("SPELL_DAMAGE", BOSS_GUID, "Boss", BOSS, playerGUID, "Alex", ME, 904, "Gust", 1, 100, -1, 1, 0, 0, 0)
	Tick(20)
	Log("UNIT_DIED", nil, nil, 0, playerGUID, "Alex", ME)
	Tick(0.2)
	assert(panel.sub:GetText():find("not in the combat log (last event 20.0s before)", 1, true), panel.sub:GetText())
	-- Instant kills are the cause of death.
	Tick(6)
	Log("SPELL_INSTAKILL", BOSS_GUID, "Boss", BOSS, playerGUID, "Alex", ME, 905, "Doom", 1)
	Log("UNIT_DIED", nil, nil, 0, playerGUID, "Alex", ME)
	Tick(0.2)
	assert(panel.sub:GetText():find("Killed by Spell 905", 1, true) and panel.sub:GetText():find("Instant kill", 1, true), panel.sub:GetText())
	popup:Hide(); dead = false; Tick(0.3)
	Equal(panel:IsShown(), false)
	hooksecurefunc, StaticPopup_Visible, UnitIsDeadOrGhost = nil, nil, nil
end)

Test("a stalled combat log is cleared after a cast with no log events", function()
	local cleared = 0
	function CombatLogClearEntries() cleared = cleared + 1 end
	Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Shot", "", 1, 100)
	Fire("COMBAT_LOG_EVENT_UNFILTERED", now, "SPELL_CAST_SUCCESS", false, playerGUID, "Alex", ME, 0, nil, nil, 0, 0, 100, "Shot", 1)
	Tick(1)
	Equal(cleared, 0, "log working")
	Fire("UNIT_SPELLCAST_SUCCEEDED", "party1", "Frostbolt", "", 1, 116)
	Tick(1)
	Equal(cleared, 0, "someone else's cast")
	Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Shot", "", 1, 100)
	Tick(1)
	Equal(cleared, 1, "stalled log cleared")
	Tick(1)
	Equal(cleared, 1, "once")
	CombatLogClearEntries = nil
end)

Test("group sync shares totals every 10 seconds and the higher number wins", function()
	inCombat = false; Tick(15); E.CheckEnd()
	Equal(E.Reset(), true)
	local sent, enemies = {}, {}
	function SendAddonMessage(prefix, text, channel)
		local list = text:sub(1, 1) == "E" and enemies or sent
		list[#list + 1] = { prefix = prefix, text = text, channel = channel }
	end
	inCombat = true
	Log("SPELL_DAMAGE", playerGUID, "Alex", ME, BOSS_GUID, "Boss", BOSS, 100, "Arcane Shot", 64, 1000, -1, 64, 0, 0, 0)
	Log("SPELL_DAMAGE", partyGUID, "Casey", PARTY, BOSS_GUID, "Boss", BOSS, 200, "Frostbolt", 16, 500, -1, 16, 0, 0, 0)
	Tick(5)
	Equal(#sent, 0, "nothing before 10 seconds")
	for _ = 1, 16 do Tick(0.5) end
	Equal(#sent, 1, "one message")
	Equal(sent[1].prefix, "EUIDM2"); Equal(sent[1].channel, "PARTY")
	assert(#sent[1].text < 255)
	assert(sent[1].text:find("1,rs", 1, true), sent[1].text) -- Alex: 1000 damage = "rs" in base 36
	assert(sent[1].text:find("2,dw", 1, true), sent[1].text) -- Casey: 500 = "dw"
	Equal(#enemies, 1, "enemy damage taken")
	assert(enemies[1].text:match("^E\t%w+:%w+\tF130000000000010,15o,Boss$"), enemies[1].text) -- 1500 = "15o"
	-- Nothing grew: nothing is sent again.
	for _ = 1, 22 do Tick(0.5) end
	Equal(#sent, 1, "unchanged numbers are not resent")
	-- Another user saw more of Casey's damage, healing and an interrupt; less of Alex's.
	local seconds = E.Duration(E.GetCurrent())
	local function B36(n) local d, o = "0123456789abcdefghijklmnopqrstuvwxyz", ""; while n > 0 do local r = n % 36; o = d:sub(r + 1, r + 1) .. o; n = (n - r) / 36 end; return o end
	-- Header of a sender whose fight started startOffset seconds after this one.
	local function Head(seg, extra, startOffset)
		local since = math.floor(now - seg.start - (startOffset or 0))
		return B36(math.floor(E.Duration(seg)) + (extra or 0)) .. ":" .. B36(since)
	end
	Fire("CHAT_MSG_ADDON", "EUIDM2", "T\t" .. Head(E.GetCurrent()) .. "\t2," .. B36(4000) .. "," .. B36(700) .. ",," .. B36(1) .. ";1," .. B36(10), "PARTY", "Bob")
	local rows = DM.GetSources(E.GetCurrent(), T.DamageDone)
	Equal(rows[1].name, "Casey"); Equal(rows[1].total, 4000); Equal(rows[2].name, "Alex"); Equal(rows[2].total, 1000)
	local spells = DM.GetBreakdown(E.GetCurrent(), T.DamageDone, rows[1])
	Equal(spells[1].label, "Synced from group"); Equal(spells[1].amount, 3500); Equal(Sum(spells), 4000)
	Equal(DM.GetSources(E.GetCurrent(), T.HealingDone)[1].total, 700)
	Equal(DM.GetSources(E.GetCurrent(), T.Interrupts)[1].total, 1)
	local o = DM.GetSources(E.GetOverall(), T.DamageDone)
	Equal(o[1].name, "Casey"); Equal(o[1].total, 4000)
	-- Enemies: the higher damage taken wins; an enemy not seen here is added.
	Fire("CHAT_MSG_ADDON", "EUIDM2", "E\t" .. Head(E.GetCurrent()) .. "\tF130000000000010," .. B36(6000) .. ",Boss;F130000000000099," .. B36(800) .. ",Far Add;F130000000000010,1,Boss", "PARTY", "Bob")
	local foes = DM.GetSources(E.GetCurrent(), T.EnemyDamageTaken)
	Equal(#foes, 2); Equal(foes[1].name, "Boss"); Equal(foes[1].total, 6000); Equal(foes[2].name, "Far Add"); Equal(foes[2].total, 800)
	local hitters = DM.GetBreakdown(E.GetCurrent(), T.EnemyDamageTaken, foes[1])
	Equal(hitters[1].label, "Synced from group"); Equal(hitters[1].amount, 4500)
	Equal(DM.GetSources(E.GetOverall(), T.EnemyDamageTaken)[1].total, 6000)
	-- Totals of a fight of a different length are another fight: ignored.
	Fire("CHAT_MSG_ADDON", "EUIDM2", "T\t" .. Head(E.GetCurrent(), 60) .. "\t2," .. B36(9000), "PARTY", "Bob")
	Equal(DM.GetSources(E.GetCurrent(), T.DamageDone)[1].total, 4000)
	-- Totals of a fight as long but started at another time are another fight too.
	Fire("CHAT_MSG_ADDON", "EUIDM2", "T\t" .. Head(E.GetCurrent(), 0, 30) .. "\t2," .. B36(9000), "PARTY", "Bob")
	Equal(DM.GetSources(E.GetCurrent(), T.DamageDone)[1].total, 4000)
	-- Old installs (no fight start in the header) are ignored.
	Fire("CHAT_MSG_ADDON", "EUIDM2", "T\t" .. B36(math.floor(seconds)) .. "\t2," .. B36(9000), "PARTY", "Bob")
	Equal(DM.GetSources(E.GetCurrent(), T.DamageDone)[1].total, 4000)
	-- Learnt numbers are not echoed back; own new damage is sent.
	Log("SPELL_DAMAGE", playerGUID, "Alex", ME, BOSS_GUID, "Boss", BOSS, 100, "Arcane Shot", 64, 1000, -1, 64, 0, 0, 0)
	for _ = 1, 22 do Tick(0.5) end
	Equal(#sent, 2)
	assert(sent[2].text:find("\t1," .. B36(2000), 1, true), sent[2].text)
	assert(not sent[2].text:find("\t2,", 1, true) and not sent[2].text:find(";2,", 1, true), sent[2].text)
	-- Final totals go out when the fight ends.
	Log("SPELL_DAMAGE", playerGUID, "Alex", ME, BOSS_GUID, "Boss", BOSS, 100, "Arcane Shot", 64, 1000, -1, 64, 0, 0, 0)
	inCombat = false; Tick(0.5); Tick(0.5)
	Equal(E.InCombat(), false)
	Equal(#sent, 3, "final totals")
	-- Late totals from the group still join the fight that just ended.
	Fire("CHAT_MSG_ADDON", "EUIDM2", "T\t" .. Head(E.GetCurrent()) .. "\t2," .. B36(5000), "PARTY", "Bob")
	Equal(DM.GetSources(E.GetCurrent(), T.DamageDone)[1].total, 5000)
	-- Your own messages are ignored.
	Fire("CHAT_MSG_ADDON", "EUIDM2", "T\t1:1\t2," .. B36(99999), "PARTY", "Alex")
	Equal(DM.GetSources(E.GetCurrent(), T.DamageDone)[1].total, 5000)
	SendAddonMessage = nil
end)

Test("group sync shares deaths", function()
	local sent = {}
	function SendAddonMessage(prefix, text, channel)
		if text:sub(1, 1) == "D" then sent[#sent + 1] = { prefix = prefix, text = text, channel = channel } end
	end
	inCombat = true
	Log("SPELL_DAMAGE", playerGUID, "Alex", ME, BOSS_GUID, "Boss", BOSS, 100, "Arcane Shot", 64, 1000, -1, 64, 0, 0, 0)
	Tick(1)
	-- A death you did not see: added with the killing blow.
	Fire("CHAT_MSG_ADDON", "EUIDM2", "D\t2\t903\t5000\t1200\t0\tBoss", "PARTY", "Bob")
	local deaths = DM.GetSources(E.GetCurrent(), T.Deaths)
	Equal(#deaths, 1); Equal(deaths[1].name, "Casey"); Equal(deaths[1].class, "MAGE")
	local recap = DM.GetBreakdown(E.GetCurrent(), T.Deaths, deaths[1])
	Equal(#recap, 1); Equal(recap[1].spellID, 903); Equal(recap[1].amount, 5000); Equal(recap[1].overkill, 1200)
	Equal(#E.GetOverall().deaths, 1)
	-- Seen here a moment later: the full recap replaces it, no second death.
	Log("SPELL_DAMAGE", BOSS_GUID, "Boss", BOSS, partyGUID, "Casey", PARTY, 901, "Bite", 1, 300, -1, 1, 0, 0, 0)
	Log("SPELL_DAMAGE", BOSS_GUID, "Boss", BOSS, partyGUID, "Casey", PARTY, 903, "Smash", 1, 5000, 1200, 1, 0, 0, 0)
	Log("UNIT_DIED", nil, nil, 0, partyGUID, "Casey", PARTY)
	deaths = DM.GetSources(E.GetCurrent(), T.Deaths)
	Equal(#deaths, 1)
	Equal(#DM.GetBreakdown(E.GetCurrent(), T.Deaths, deaths[1]), 2)
	for _ = 1, 6 do Tick(0.5) end
	Equal(#sent, 0, "a death learnt from the group is not sent again")
	-- Your own death goes out right away, with the killing blow.
	Log("SPELL_DAMAGE", BOSS_GUID, "Boss", BOSS, playerGUID, "Alex", ME, 904, "Gust", 1, 7000, 300, 1, 0, 0, 0)
	Log("UNIT_DIED", nil, nil, 0, playerGUID, "Alex", ME)
	Tick(0.5)
	Equal(#sent, 1)
	Equal(sent[1].text, "D\t1\t904\t7000\t300\t0\tBoss")
	-- Someone else's death waits a moment and is dropped if another user sent it first.
	Tick(6)
	Log("UNIT_DIED", nil, nil, 0, partyGUID, "Casey", PARTY)
	Fire("CHAT_MSG_ADDON", "EUIDM2", "D\t2\t0\t0\t0\t0\t", "PARTY", "Bob")
	for _ = 1, 6 do Tick(0.5) end
	Equal(#sent, 1, "dropped")
	Tick(6)
	Log("UNIT_DIED", nil, nil, 0, partyGUID, "Casey", PARTY)
	for _ = 1, 6 do Tick(0.5) end
	Equal(#sent, 2, "sent after the wait")
	Equal(#DM.GetSources(E.GetCurrent(), T.Deaths), 4)
	inCombat = false; Tick(0.5)
	SendAddonMessage = nil
end)

Test("group sync sends the 10 enemies with the most new damage per round", function()
	inCombat = false; Tick(15); E.CheckEnd()
	local sent = {}
	function SendAddonMessage(prefix, text, channel) sent[#sent + 1] = text end
	inCombat = true
	for i = 1, 30 do
		Log("SPELL_DAMAGE", playerGUID, "Alex", ME, string.format("0xF1300000000002%02d", i), "Add " .. i, ADD, 100, "Arcane Shot", 64, 1000 + i, -1, 64, 0, 0, 0)
	end
	Tick(12) -- one long frame: the round is queued, one message sent
	local function Enemies()
		local n = 0
		for _, text in ipairs(sent) do
			if text:sub(1, 1) == "E" then for _ in text:gmatch("[^;]+") do n = n + 1 end end
		end
		return n
	end
	for _ = 1, 10 do Tick(0.5) end
	Equal(Enemies(), 10, "first round")
	assert(table.concat(sent, "\n"):find("Add 30", 1, true), "biggest first")
	for _ = 1, 22 do Tick(0.5) end
	Equal(Enemies(), 20, "second round")
	inCombat = false; Tick(0.5); Tick(0.5)
	SendAddonMessage = nil
end)

Test("a stray hit after a kill does not blank Current", function()
	Fire("ENCOUNTER_START", 9, "Galakras", 3, 10)
	inCombat = true
	Log("SPELL_DAMAGE", playerGUID, "Alex", ME, BOSS_GUID, "Galakras", BOSS, 100, "Shot", 1, 500, -1, 1, 0, 0, 0)
	Tick(3)
	inCombat = false
	Fire("ENCOUNTER_END", 9, "Galakras", 3, 10, 1)
	local kill = DM.GetSegments()[1].combat
	Equal(kill.name, "Galakras")
	local shown = 0
	E.Listen(function(what) if what == "shown" then shown = shown + 1 end end)
	-- A leftover ground effect hits you: a fight starts, nothing in it.
	Log("SPELL_DAMAGE", BOSS_GUID, "Galakras", BOSS, playerGUID, "Alex", ME, 900, "Flames", 4, 300, -1, 4, 0, 0, 0)
	Equal(E.InCombat(), true)
	Equal(E.GetCurrent(), kill, "the kill stays on screen")
	Equal(shown, 0)
	Tick(0.5)
	Equal(E.InCombat(), false)
	Equal(DM.GetSegments()[1].combat, kill, "the stray fight is dropped")
	-- A real pull shows as soon as the group does damage.
	inCombat = true
	Log("SPELL_DAMAGE", BOSS_GUID, "Galakras", BOSS, playerGUID, "Alex", ME, 900, "Flames", 4, 300, -1, 4, 0, 0, 0)
	Equal(E.GetCurrent(), kill)
	Log("SPELL_DAMAGE", playerGUID, "Alex", ME, ADD_GUID, "Add", ADD, 100, "Shot", 1, 10, -1, 1, 0, 0, 0)
	Equal(shown, 1)
	Equal(E.GetCurrent() ~= kill, true, "the new fight shows")
	Tick(3)
	inCombat = false
	Tick(1)
end)

Test("group sync sends every number when a boss encounter ends", function()
	inCombat = false; Tick(15); E.CheckEnd()
	local sent = {}
	function SendAddonMessage(prefix, text, channel) sent[#sent + 1] = text end
	inCombat = true
	Fire("ENCOUNTER_START", 77, "Sync Boss", 14, 10)
	Log("SPELL_DAMAGE", playerGUID, "Alex", ME, BOSS_GUID, "Sync Boss", BOSS, 100, "Arcane Shot", 64, 1000, -1, 64, 0, 0, 0)
	for _ = 1, 26 do Tick(0.5) end
	local rounds = #sent
	assert(rounds >= 2, "a regular round went out")
	Equal(sent[1]:sub(1, 1), "T")
	-- Nothing grew since, yet the encounter end sends it all again.
	Fire("ENCOUNTER_END", 77, "Sync Boss", 14, 10, 1)
	for _ = 1, 4 do Tick(0.5) end
	local again = table.concat(sent, "\n", rounds + 1)
	assert(again:find("T\t", 1, true) and again:find("\t1,rs", 1, true), again)
	assert(again:find("E\t", 1, true) and again:find(",rs,Sync Boss", 1, true), again)
	inCombat = false; Tick(0.5); Tick(0.5)
	SendAddonMessage = nil
end)

local function B36(n) local d, o = "0123456789abcdefghijklmnopqrstuvwxyz", ""; n = math.floor(n); while n > 0 do local r = n % 36; o = d:sub(r + 1, r + 1) .. o; n = (n - r) / 36 end; return o end
local function SyncHead(seg) return B36(E.Duration(seg)) .. ":" .. B36(now - seg.start) end
local function OverallDamage(name)
	for _, row in ipairs(DM.GetSources(E.GetOverall(), T.DamageDone)) do
		if row.name == name then return row.total end
	end
	return 0
end

Test("late group totals join the fight they are of, not a short fight that started after it", function()
	inCombat = false; Tick(15); E.CheckEnd()
	Equal(E.Reset(), true)
	inCombat = true
	Log("SPELL_DAMAGE", partyGUID, "Casey", PARTY, ADD_GUID, "Gunner", ADD, 200, "Frostbolt", 16, 2000, -1, 16, 0, 0, 0)
	Tick(8)
	inCombat = false; Tick(0.5)
	local gunner = DM.GetSegments()[1].combat
	Equal(gunner.name, "Gunner")
	Tick(12)
	-- A stray hit starts a fight here; the sender's final totals of the
	-- Gunner fight (8 seconds, as long as this one could become) arrive.
	inCombat = true
	Log("SPELL_DAMAGE", ADD_GUID, "Add", ADD, playerGUID, "Alex", ME, 900, "Smash", 1, 100, -1, 1, 0, 0, 0)
	Tick(1)
	Fire("CHAT_MSG_ADDON", "EUIDM2", "T\t" .. SyncHead(gunner) .. "\t2," .. B36(2000), "PARTY", "Bob")
	Equal(OverallDamage("Casey"), 2000, "not counted twice in Overall")
	Fire("CHAT_MSG_ADDON", "EUIDM2", "T\t" .. SyncHead(gunner) .. "\t2," .. B36(3000), "PARTY", "Bob")
	Equal(DM.GetSources(gunner, T.DamageDone)[1].total, 3000, "the Gunner fight is raised")
	Equal(OverallDamage("Casey"), 3000)
	inCombat = false; Tick(0.5)
	Equal(DM.GetSegments()[1].combat, gunner, "the stray fight is dropped")
end)

Test("after a wipe the group's final totals join the wipe, not the reset pull", function()
	inCombat = false; Tick(15); E.CheckEnd()
	Equal(E.Reset(), true)
	Fire("ENCOUNTER_START", 88, "Wipe Boss", 14, 10)
	inCombat = true
	Log("SPELL_DAMAGE", partyGUID, "Casey", PARTY, BOSS_GUID, "Wipe Boss", BOSS, 200, "Frostbolt", 16, 5000, -1, 16, 0, 0, 0)
	Tick(60)
	inCombat = false
	Fire("ENCOUNTER_END", 88, "Wipe Boss", 14, 10, 0)
	local wipe = DM.GetSegments()[1].combat
	Equal(wipe.name, "Wipe Boss")
	-- The server starts the encounter again for a moment.
	Tick(3)
	Fire("ENCOUNTER_START", 88, "Wipe Boss", 14, 10)
	Tick(1)
	-- Another user saw all of Casey's damage in the wipe.
	Fire("CHAT_MSG_ADDON", "EUIDM2", "T\t" .. SyncHead(wipe) .. "\t2," .. B36(8000), "PARTY", "Bob")
	Equal(DM.GetSources(wipe, T.DamageDone)[1].total, 8000)
	Equal(OverallDamage("Casey"), 8000)
	Fire("ENCOUNTER_END", 88, "Wipe Boss", 14, 10, 0)
	Tick(1)
	Equal(DM.GetSegments()[1].combat, wipe)
	Equal(DM.GetSources(wipe, T.DamageDone)[1].total, 8000)
end)

do
	local sent = {}
	local group, raid, instance, guild
	local oldGroup, oldRaid, oldGuild = IsInGroup, IsInRaid, IsInGuild
	local oldHome, oldInstance = LE_PARTY_CATEGORY_HOME, LE_PARTY_CATEGORY_INSTANCE
	local oldThrottle = ChatThrottleLib
	LE_PARTY_CATEGORY_HOME, LE_PARTY_CATEGORY_INSTANCE = 1, 2
	function IsInGroup(category) return category == 2 and instance or category ~= 2 and group end
	function IsInRaid() return raid end
	function IsInGuild() return guild end
	local function Send(text, channel, language, target)
		sent[#sent + 1] = { text = text, channel = channel, language = language, target = target, at = now }
	end
	local function Throttle(immediate)
		local ctl = { pending = {}, immediate = immediate or 0, maxPending = 0, depth = 0, maxDepth = 0 }
		function ctl:SendChatMessage(priority, prefix, text, channel, language, target, queueName, callback, job)
			Equal(priority, "BULK"); Equal(prefix, "EUIDMReport"); Equal(queueName, "EUIDMReport")
			self.depth = self.depth + 1
			self.maxDepth = math.max(self.maxDepth, self.depth)
			if self.immediate > 0 then
				self.immediate = self.immediate - 1
				Send(text, channel, language, target)
				callback(job)
			else
				self.pending[#self.pending + 1] = {
					text = text, channel = channel, language = language, target = target, callback = callback, job = job,
				}
				self.maxPending = math.max(self.maxPending, #self.pending)
			end
			self.depth = self.depth - 1
		end
		function ctl:FlushOne()
			local message = table.remove(self.pending, 1)
			assert(message, "no throttled message pending")
			Send(message.text, message.channel, message.language, message.target)
			message.callback(message.job)
		end
		ChatThrottleLib = ctl
		return ctl
	end
	local function LongReport()
		local report = { title = "Large Report", rows = {} }
		for i = 1, 40 do report.rows[i] = string.rep("x", 200) end
		return report
	end
	local function BytesSince(index)
		local bytes = 0
		for i = (index or 0) + 1, #sent do bytes = bytes + #sent[i].text + 40 end
		return bytes
	end
	local function ReportTest(name, fn)
		Test(name, function()
			DM.CancelChatReport()
			wipe(sent)
			ChatThrottleLib = nil
			now = now + 2 -- refill the shared fallback budget between independent cases
			group, raid, instance, guild = true, false, false, true
			SendChatMessage = Send
			DM.DB().numberFormat, DM.DB().timeType = 2, "effective"
			fn()
			DM.CancelChatReport()
		end)
	end
	local function Fixture(dmType)
		local actor = {
			guid = playerGUID, name = "Alex-Realm", group = true, class = "HUNTER",
			damage = 20000, healing = 5000, taken = 1000, interrupts = 3, dispels = 2,
			dmgActive = 10, healActive = 5,
			dmgSpells = { { id = 100, amount = 15000 }, { id = 1, amount = 5000 } },
			healSpells = { { id = 300, amount = 5000 } },
			intSpells = { { id = 400, amount = 3 } },
			dispSpells = { { id = 500, amount = 2 } },
			takenFrom = { { name = "Boss", amount = 1000 } },
		}
		local combat = {
			name = "Report Boss", boss = true, try = 2, result = "kill", start = now - 20, finish = now,
			actors = {
				alex = actor,
				casey = { name = "Casey", group = true, damage = 10000, healing = 12000, taken = 3000, interrupts = 1, dispels = 4 },
				robin = { name = "Robin", group = true, damage = 5000, healing = 1000, taken = 500 },
				boss = { name = "Boss", enemy = true, taken = 35000, takenFrom = { { name = "Alex", amount = 20000 } } },
			},
			deaths = {
				{ name = "Alex", time = 11, at = now - 9, events = {
					{ id = 300, amount = 100, heal = true, source = "Casey", at = now - 11, hp = 35 },
					{ id = 1, amount = 500, source = "Boss", at = now - 10, hp = 0, overkill = 50 },
				} },
				{ name = "Casey", time = 12, at = now - 8, events = {} },
			},
		}
		return { curDMType = dmType or T.DamageDone, curSession = DM.S.Current, curSessionID = combat }, combat
	end

	ReportTest("reports damage, healing, taken, enemy taken, interrupts, dispels, and deaths", function()
		local cases = {
			{ T.DamageDone, "1. Alex: 20K (1K)" },
			{ T.HealingDone, "1. Casey: 12K (600)" },
			{ T.DamageTaken, "1. Casey: 3K (150)" },
			{ T.EnemyDamageTaken, "1. Boss: 35K (1.7K)" },
			{ T.Interrupts, "1. Alex: 3" },
			{ T.Dispels, "1. Casey: 4" },
			{ T.Deaths, "1. Alex: 0:11" },
		}
		for _, case in ipairs(cases) do
			local report = assert(DM.BuildChatReport(Fixture(case[1])))
			Equal(report.rows[1], case[2])
			assert(report.title:find(DM.TYPE_NAMES[case[1]], 1, true))
			assert(report.title:find("Fight: Report Boss #2  Kill (0:20)", 1, true))
			assert(not report.title:find("|", 1, true))
		end
	end)
	ReportTest("report amounts follow number formatting and activity-time settings", function()
		local W = Fixture()
		local values = { [0] = "1K", [1] = "20K", [2] = "20K (1K)", [3] = "20K / 1K" }
		for mode = 0, 3 do
			DM.DB().numberFormat = mode
			Equal(DM.BuildChatReport(W).rows[1], "1. Alex: " .. values[mode])
		end
		DM.DB().numberFormat, DM.DB().timeType = 2, "activity"
		Equal(DM.BuildChatReport(W).rows[1], "1. Alex: 20K (2K)")
	end)
	ReportTest("reports current and overall sessions without confusing them with a stored fight", function()
		local W, combat = Fixture()
		local current, overall = E.GetCurrent, E.GetOverall
		W.curSessionID = nil
		E.GetCurrent = function() return combat end
		combat.name, combat.boss = nil, nil
		local report = DM.BuildChatReport(W)
		assert(report.title:find("Current: Combat (0:20)", 1, true))
		W.curSession = DM.S.Overall
		E.GetOverall = function() return combat end
		report = DM.BuildChatReport(W)
		E.GetCurrent, E.GetOverall = current, overall
		assert(report.title:find("Overall (0:20)", 1, true))
		Equal(report.rows[1], "1. Alex: 20K (1K)")
	end)
	ReportTest("open spell breakdowns and death recaps report their displayed rows", function()
		local W = Fixture()
		W.source = DM.GetSources(W.curSessionID, W.curDMType)[1]
		local report = DM.BuildChatReport(W)
		Equal(report.rows[1], "1. Spell 100: 15K (75.0%)")
		Equal(report.rows[2], "2. Melee: 5K (25.0%)")
		assert(report.title:find("Damage Done - Alex", 1, true))
		W = Fixture(T.Deaths)
		W.source = DM.GetSources(W.curSessionID, W.curDMType)[1]
		report = DM.BuildChatReport(W)
		Equal(#report.rows, 2)
		assert(report.rows[1]:find("-1.0s Melee", 1, true))
		assert(report.rows[1]:find("-500 0%", 1, true))
		assert(report.rows[2]:find("+100 35%", 1, true))
		assert(not report.rows[1]:find("|", 1, true))
	end)
	ReportTest("opening a report snapshots strings, not mutable combat or window state", function()
		local W, combat = Fixture()
		local report = DM.BuildChatReport(W)
		combat.actors.alex.damage, combat.name = 1, "Changed"
		W.curDMType = T.HealingDone
		Equal(report.rows[1], "1. Alex: 20K (1K)")
		assert(not report.title:find("Changed", 1, true))
	end)
	ReportTest("short reports send the header and selected rows immediately without a timer delay", function()
		local report = DM.BuildChatReport(Fixture())
		Equal(DM.SendChatReport(report, 2, "PARTY"), true)
		Equal(#sent, 3)
		Equal(sent[1].text, report.title); Equal(sent[2].text, report.rows[1]); Equal(sent[3].text, report.rows[2])
		for _, message in ipairs(sent) do Equal(message.at, now) end
		Equal(DM.IsChatReporting(), false)
		Tick(5); Equal(#sent, 3)
		Equal(sent[1].channel, "PARTY"); Equal(sent[1].target, nil)
		Equal(DM.DB().reportRows, 2); Equal(DM.DB().reportChannel, "PARTY")
	end)
	ReportTest("short reports stop at available rows and retain a separate queued copy", function()
		local ctl = Throttle()
		local report = DM.BuildChatReport(Fixture(T.Interrupts))
		Equal(DM.SendChatReport(report, 40, "GUILD"), true)
		local first = report.rows[1]
		report.rows[1] = "Mutated"
		for _ = 1, 3 do ctl:FlushOne() end
		Equal(#sent, 3); Equal(sent[2].text, first); Equal(sent[1].channel, "GUILD")
		Equal(ctl.maxPending, 1); Equal(DM.IsChatReporting(), false)
	end)
	ReportTest("large fallback reports respect byte budgets rather than one-line-per-second pacing", function()
		local W, combat = Fixture()
		for i = 1, 50 do combat.actors["extra" .. i] = { name = "Extra " .. i, group = true, damage = i } end
		Equal(#DM.BuildChatReport(W).rows, 40)
		local report = LongReport()
		Equal(DM.SendChatReport(report, 40, "SAY"), true)
		Equal(#sent, 5); assert(BytesSince() <= 1200)
		Tick(0.1)
		Equal(#sent, 6); assert(BytesSince() <= 1280)
		local before = #sent
		Tick(100)
		assert(#sent > before + 1); assert(BytesSince(before) <= 1200, "long frames must not bank an unlimited burst")
		for _ = 1, 12 do Tick(1) end
		Equal(#sent, 41); Equal(DM.IsChatReporting(), false)
	end)
	ReportTest("the default ten-row report fits in the immediate native burst", function()
		local W, combat = Fixture()
		for i = 1, 7 do combat.actors["extra" .. i] = { name = "Extra " .. i, group = true, damage = 100 * i } end
		local report = DM.BuildChatReport(W)
		Equal(DM.SendChatReport(report, 10, "RAID"), false)
		raid = true
		Equal(DM.SendChatReport(report, 10, "RAID"), true)
		Equal(#sent, 11); Equal(DM.IsChatReporting(), false)
		for _, message in ipairs(sent) do Equal(message.at, now) end
	end)
	ReportTest("ChatThrottleLib sends all available bulk lines immediately without recursive sends", function()
		local ctl = Throttle(math.huge)
		local report = LongReport()
		Equal(DM.SendChatReport(report, 40, "WHISPER", "Friend-Realm"), true)
		Equal(#sent, 41); Equal(ctl.maxPending, 0); Equal(ctl.maxDepth, 1)
		for _, message in ipairs(sent) do
			Equal(message.at, now); Equal(message.channel, "WHISPER"); Equal(message.target, "Friend-Realm")
		end
		Equal(sent[1].text, report.title); Equal(DM.IsChatReporting(), false)
		Tick(1); Equal(#sent, 41)
	end)
	ReportTest("deferred throttle callbacks resume immediately and queue at most one line per report", function()
		local ctl = Throttle(2)
		local report = DM.BuildChatReport(Fixture())
		Equal(DM.SendChatReport(report, 3, "PARTY"), true)
		Equal(#sent, 2); Equal(#ctl.pending, 1); Equal(DM.IsChatReporting(), true)
		Tick(0.1); Equal(#sent, 2); Equal(#ctl.pending, 1)
		ctl:FlushOne()
		Equal(#sent, 3); Equal(#ctl.pending, 1); Equal(sent[3].text, report.rows[2])
		ctl:FlushOne()
		Equal(#sent, 4); Equal(#ctl.pending, 0); Equal(sent[4].text, report.rows[3])
		Equal(ctl.maxPending, 1); Equal(DM.IsChatReporting(), false)
	end)
	ReportTest("cancelled throttle callbacks cannot advance or cancel a replacement report", function()
		local ctl = Throttle()
		local first = DM.BuildChatReport(Fixture())
		Equal(DM.SendChatReport(first, 3, "PARTY"), true)
		DM.CancelChatReport()
		local second = { title = "Replacement", rows = { "1. New row" } }
		Equal(DM.SendChatReport(second, 1, "WHISPER", "Friend"), true)
		Equal(#ctl.pending, 2)
		ctl:FlushOne() -- the old line already handed to the library can still arrive
		Equal(#sent, 1); Equal(sent[1].text, first.title)
		Equal(#ctl.pending, 1); Equal(DM.IsChatReporting(), true)
		ctl:FlushOne(); Equal(sent[2].text, "Replacement")
		ctl:FlushOne(); Equal(sent[3].text, "1. New row")
		Equal(#ctl.pending, 0); Equal(DM.IsChatReporting(), false)
	end)
	ReportTest("the fallback byte budget is shared across cancelled and replacement reports", function()
		local report = LongReport()
		Equal(DM.SendChatReport(report, 40, "SAY"), true)
		Equal(#sent, 5)
		DM.CancelChatReport()
		Equal(DM.SendChatReport(report, 1, "SAY"), true)
		Equal(#sent, 6); assert(BytesSince() <= 1200)
		Equal(DM.IsChatReporting(), true)
		Tick(0.2)
		Equal(#sent, 7); Equal(DM.IsChatReporting(), false)
	end)
	ReportTest("Whisper uses the typed character name and keeps the recipient out of saved settings", function()
		local report = DM.BuildChatReport(Fixture())
		Equal(DM.SendChatReport(report, 1, "WHISPER", "  Friend-Realm  "), true)
		Tick(0.1); Tick(1)
		Equal(#sent, 2)
		for _, line in ipairs(sent) do Equal(line.channel, "WHISPER"); Equal(line.target, "Friend-Realm") end
		Equal(DM.DB().reportRecipient, nil)
	end)
	ReportTest("Whisper preserves UTF-8 character-name bytes under Windows locale rules", function()
		local name = string.char(208, 144, 208, 160)
		local report = DM.BuildChatReport(Fixture())
		Equal(DM.SendChatReport(report, 1, "WHISPER", " " .. name .. " "), true)
		Tick(0.1); Tick(1)
		Equal(sent[1].target, name); Equal(sent[2].target, name)
	end)
	ReportTest("invalid row counts, recipients, and unavailable destinations fail explicitly without sending", function()
		local report = DM.BuildChatReport(Fixture())
		local count = #messages
		for _, rows in ipairs({ 0, -1, 41, 1.5, "2" }) do Equal(DM.SendChatReport(report, rows, "PARTY"), false) end
		Equal(DM.SendChatReport(report, 0 / 0, "PARTY"), false)
		for _, name in ipairs({ "", "Two Names", "Bad|Name", "Name\nOther" }) do
			Equal(DM.SendChatReport(report, 1, "WHISPER", name), false)
		end
		Equal(DM.SendChatReport(report, 1, "WHISPER"), false)
		Equal(DM.SendChatReport(report, 1, "UNSUPPORTED"), false)
		Equal(DM.SendChatReport(report, 1, "RAID"), false)
		Equal(DM.SendChatReport(report, 1, "INSTANCE_CHAT"), false)
		group, guild = false, false
		Equal(DM.SendChatReport(report, 1, "PARTY"), false)
		Equal(DM.SendChatReport(report, 1, "GUILD"), false)
		Equal(DM.SendChatReport(report, 1, "OFFICER"), false)
		Equal(DM.SendChatReport({ title = "Invalid", rows = { false } }, 1, "SAY"), false)
		Equal(DM.SendChatReport(nil, 1, "SAY"), false)
		assert(#messages > count)
		Tick(5); Equal(#sent, 0); Equal(DM.IsChatReporting(), false)
	end)
	ReportTest("Raid, Instance, Officer, and Yell route to the requested chat type", function()
		local report = DM.BuildChatReport(Fixture())
		raid, instance = true, true
		for _, channel in ipairs({ "RAID", "INSTANCE_CHAT", "OFFICER", "YELL" }) do
			Equal(DM.SendChatReport(report, 1, channel), true)
			Tick(0.1); Tick(1)
			Equal(sent[#sent].channel, channel); Equal(sent[#sent].target, nil)
		end
	end)
	ReportTest("losing party or guild membership stops remaining lines with a visible message", function()
		local report = LongReport()
		for _, channel in ipairs({ "PARTY", "GUILD" }) do
			group, guild = true, true
			Tick(2)
			Equal(DM.SendChatReport(report, 40, channel), true)
			Equal(DM.IsChatReporting(), true)
			local n, errors = #sent, #messages
			group, guild = false, false
			Tick(1)
			Equal(#sent, n); Equal(DM.IsChatReporting(), false); Equal(#messages, errors + 1)
		end
	end)
	ReportTest("report cancellation, busy checks, and chat API errors never leave a stuck sender", function()
		local ctl = Throttle()
		local report = DM.BuildChatReport(Fixture())
		Equal(DM.SendChatReport(report, 3, "PARTY"), true)
		Equal(DM.SendChatReport(report, 3, "PARTY"), false)
		DM.CancelChatReport()
		ctl:FlushOne(); Equal(#sent, 1); Equal(#ctl.pending, 0)
		ChatThrottleLib = nil
		SendChatMessage = function() error("mock chat failure") end
		local errors = #messages
		Equal(DM.SendChatReport(report, 1, "PARTY"), false)
		Equal(DM.IsChatReporting(), false); Equal(#messages, errors + 1)
		assert(messages[#messages]:find("mock chat failure", 1, true))
	end)
	ReportTest("throttle transport failures and lost membership stop without raw-send fallbacks", function()
		local report = DM.BuildChatReport(Fixture())
		ChatThrottleLib = { SendChatMessage = function() error("mock throttle failure") end }
		local errors = #messages
		Equal(DM.SendChatReport(report, 1, "PARTY"), false)
		Equal(#sent, 0); Equal(DM.IsChatReporting(), false); Equal(#messages, errors + 1)
		local ctl = Throttle()
		Equal(DM.SendChatReport(report, 3, "PARTY"), true)
		group = false
		ctl:FlushOne()
		Equal(#sent, 1); Equal(#ctl.pending, 0); Equal(DM.IsChatReporting(), false)
	end)
	local function ValidUTF8(text)
		local i = 1
		while i <= #text do
			local byte, length = text:byte(i), 1
			if byte >= 240 then length = 4 elseif byte >= 224 then length = 3 elseif byte >= 192 then length = 2
			elseif byte >= 128 then return false end
			for j = 1, length - 1 do
				local nextByte = text:byte(i + j)
				if not nextByte or nextByte < 128 or nextByte >= 192 then return false end
			end
			i = i + length
		end
		return true
	end
	ReportTest("long UTF-8 names and encounter labels fit chat byte limits without markup or line injection", function()
		local W, combat = Fixture()
		local text = string.rep(string.char(208, 144), 150) .. string.rep(string.char(228, 184, 128), 50)
		combat.name = "|cffff0000" .. text .. "|r\n|Hspell:1|hLink|h"
		combat.actors.alex.name = text .. "\n|Ticon:16|t|cffff0000Name|r"
		local report = DM.BuildChatReport(W)
		for _, line in ipairs({ report.title, report.rows[1] }) do
			assert(#line <= 255); assert(ValidUTF8(line)); assert(not line:find("|", 1, true))
			assert(not line:find("[%z\1-\31\127]"))
		end
		assert(report.rows[1]:find(": 20K (1K)", 1, true))
		Equal(DM.SendChatReport(report, 1, "SAY"), true)
		Tick(0.1); Tick(1)
		for _, line in ipairs(sent) do assert(#line.text <= 255 and ValidUTF8(line.text)) end
	end)
	ReportTest("each meter header places Report between Window and Reset even when Reset is hidden", function()
		for _, W in ipairs(DM.windows) do
			Equal(W.hdrBtns[4], W.resetBtn); Equal(W.hdrBtns[5], W.reportBtn); Equal(W.hdrBtns[6], W.winBtn)
			W.Layout()
			assert(W.winBtn.point[4] < W.reportBtn.point[4] and W.reportBtn.point[4] < W.resetBtn.point[4])
		end
		local hidden = DM.DB().hideResetButton
		DM.DB().hideResetButton = true; DM.Apply()
		for _, W in ipairs(DM.windows) do
			Equal(W.resetBtn:IsShown(), false); Equal(W.reportBtn:IsShown(), true)
		end
		DM.DB().hideResetButton = hidden; DM.Apply()
	end)
	ReportTest("the report dialog exposes a Whisper name field and sends only after explicit confirmation", function()
		local W = DM.windows[1]
		local fixture = Fixture(T.HealingDone)
		W.curSessionID, W.curSession = fixture.curSessionID, DM.S.Current
		W.SetDMType(T.HealingDone)
		DM.DB().reportChannel = nil
		W.reportBtn.scripts.OnClick(W.reportBtn, "LeftButton")
		local f = EllesmereUIDMReportFrame
		Equal(f:IsShown(), true); Equal(#sent, 0)
		Equal(f.destination, "PARTY"); Equal(f.recipient:IsShown(), false)
		f.SetChannel("WHISPER")
		Equal(f.recipient:IsShown(), true); Equal(f.recipientLabel:IsShown(), true)
		f.rows:SetText("2"); f.recipient:SetText("Friend-Realm")
		local first = f.report.rows[1]
		f.send.scripts.OnClick()
		Equal(f:IsShown(), false); Equal(#sent, 3)
		Equal(#sent, 3); Equal(sent[2].text, first); Equal(sent[3].target, "Friend-Realm")
		DM.OpenChatReport(W); Equal(f.recipient:GetText(), "")
		f.rows:SetText("0"); f.send.scripts.OnClick()
		Equal(f:IsShown(), true); assert(f.error:GetText():find("whole number", 1, true))
		f:Hide()
	end)
	ReportTest("reopening the report dialog exposes Stop Report during a queued send", function()
		local ctl = Throttle(1)
		local W = DM.windows[1]
		W.curSessionID = select(2, Fixture())
		W.SetDMType(T.DamageDone)
		Equal(DM.OpenChatReport(W), true)
		local f = EllesmereUIDMReportFrame
		f.SetChannel("PARTY"); f.rows:SetText("3"); f.send.scripts.OnClick()
		Tick(0.1); Equal(#sent, 1)
		DM.OpenChatReport(W)
		Equal(f.cancel.label:GetText(), "Stop Report"); Equal(f.send.enabled, false)
		f.cancel.scripts.OnClick()
		ctl:FlushOne()
		Tick(2); Equal(#sent, 2); Equal(#ctl.pending, 0); Equal(DM.IsChatReporting(), false)
	end)
	ReportTest("empty views and unselected meter types do not produce header-only reports", function()
		local W, combat = Fixture()
		combat.actors = {}
		local report, err = DM.BuildChatReport(W)
		Equal(report, nil); assert(err)
		Equal(DM.OpenChatReport(W), false)
		W.curDMType = nil
		Equal(DM.OpenChatReport(W), false)
		Equal(#sent, 0)
	end)

	DM.CancelChatReport()
	IsInGroup, IsInRaid, IsInGuild = oldGroup, oldRaid, oldGuild
	LE_PARTY_CATEGORY_HOME, LE_PARTY_CATEGORY_INSTANCE = oldHome, oldInstance
	ChatThrottleLib = oldThrottle
	SendChatMessage = nil
end

print(string.format("%d passed, %d failed", passed, #failures))
if #failures > 0 then error(table.concat(failures, "\n"), 0) end
