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
	"SetPoint", "ClearAllPoints", "SetAllPoints", "SetClampedToScreen", "SetMovable", "SetResizable",
	"SetMinResize", "SetMaxResize", "EnableMouse", "EnableMouseWheel", "SetHitRectInsets",
	"SetJustifyH", "SetJustifyV", "SetWordWrap", "SetTextColor", "SetVertexColor", "SetTexCoord",
	"SetStatusBarColor", "SetScrollChild", "RegisterForClicks", "RegisterForDrag",
	"SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetBlendMode",
	"SetHighlightTexture", "SetNormalTexture", "SetShadowColor", "SetShadowOffset",
	"SetDrawLayer", "SetDesaturated", "StartMoving", "StopMovingOrSizing", "StartSizing",
}) do
	Frame[method] = noop
end

UIParent = CreateFrame("Frame")
UIParent:SetSize(2560, 1440)
GameTooltip = CreateFrame("GameTooltip")
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
	assert(panel.lines[1].name:GetText():find("Spell 903", 1, true), panel.lines[1].name:GetText())
	-- The collapse button hides the lines and keeps the summary; it is remembered.
	panel.toggle.scripts.OnClick(panel.toggle)
	Equal(panel.lines[1]:IsShown(), false, "collapsed"); Equal(panel.toggle.text:GetText(), "+")
	Equal(DM.DB().deathRecapCollapsed, true)
	panel.toggle.scripts.OnClick(panel.toggle)
	Equal(panel.lines[1]:IsShown(), true, "expanded"); Equal(panel.toggle.text:GetText(), "-")
	-- A resurrection offer replaces the DEATH popup: the recap stays, under it.
	popup.which = "RESURRECT"
	Tick(0.3)
	Equal(panel:IsShown(), true, "kept for the resurrection offer")
	popup:Hide(); Tick(0.3)
	Equal(panel:IsShown(), true, "kept while dead without a popup")
	-- Alive again: gone.
	dead = false; Tick(0.3)
	Equal(panel:IsShown(), false, "hidden once alive")
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
	Equal(sent[1].prefix, "EUIDM"); Equal(sent[1].channel, "PARTY")
	assert(#sent[1].text < 255)
	assert(sent[1].text:find("1,rs", 1, true), sent[1].text) -- Alex: 1000 damage = "rs" in base 36
	assert(sent[1].text:find("2,dw", 1, true), sent[1].text) -- Casey: 500 = "dw"
	Equal(#enemies, 1, "enemy damage taken")
	Equal(enemies[1].text, "E\t" .. sent[1].text:match("^T\t(%w+)") .. "\tF130000000000010,15o,Boss") -- 1500 = "15o"
	-- Nothing grew: nothing is sent again.
	for _ = 1, 22 do Tick(0.5) end
	Equal(#sent, 1, "unchanged numbers are not resent")
	-- Another user saw more of Casey's damage, healing and an interrupt; less of Alex's.
	local seconds = E.Duration(E.GetCurrent())
	local function B36(n) local d, o = "0123456789abcdefghijklmnopqrstuvwxyz", ""; while n > 0 do local r = n % 36; o = d:sub(r + 1, r + 1) .. o; n = (n - r) / 36 end; return o end
	Fire("CHAT_MSG_ADDON", "EUIDM", "T\t" .. B36(math.floor(seconds)) .. "\t2," .. B36(4000) .. "," .. B36(700) .. ",," .. B36(1) .. ";1," .. B36(10), "PARTY", "Bob")
	local rows = DM.GetSources(E.GetCurrent(), T.DamageDone)
	Equal(rows[1].name, "Casey"); Equal(rows[1].total, 4000); Equal(rows[2].name, "Alex"); Equal(rows[2].total, 1000)
	local spells = DM.GetBreakdown(E.GetCurrent(), T.DamageDone, rows[1])
	Equal(spells[1].label, "Synced from group"); Equal(spells[1].amount, 3500); Equal(Sum(spells), 4000)
	Equal(DM.GetSources(E.GetCurrent(), T.HealingDone)[1].total, 700)
	Equal(DM.GetSources(E.GetCurrent(), T.Interrupts)[1].total, 1)
	local o = DM.GetSources(E.GetOverall(), T.DamageDone)
	Equal(o[1].name, "Casey"); Equal(o[1].total, 4000)
	-- Enemies: the higher damage taken wins; an enemy not seen here is added.
	Fire("CHAT_MSG_ADDON", "EUIDM", "E\t" .. B36(math.floor(seconds)) .. "\tF130000000000010," .. B36(6000) .. ",Boss;F130000000000099," .. B36(800) .. ",Far Add;F130000000000010,1,Boss", "PARTY", "Bob")
	local foes = DM.GetSources(E.GetCurrent(), T.EnemyDamageTaken)
	Equal(#foes, 2); Equal(foes[1].name, "Boss"); Equal(foes[1].total, 6000); Equal(foes[2].name, "Far Add"); Equal(foes[2].total, 800)
	local hitters = DM.GetBreakdown(E.GetCurrent(), T.EnemyDamageTaken, foes[1])
	Equal(hitters[1].label, "Synced from group"); Equal(hitters[1].amount, 4500)
	Equal(DM.GetSources(E.GetOverall(), T.EnemyDamageTaken)[1].total, 6000)
	-- Totals of a fight of a different length are another fight: ignored.
	Fire("CHAT_MSG_ADDON", "EUIDM", "T\t" .. B36(math.floor(seconds) + 60) .. "\t2," .. B36(9000), "PARTY", "Bob")
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
	Fire("CHAT_MSG_ADDON", "EUIDM", "T\t" .. B36(math.floor(E.Duration(E.GetCurrent()))) .. "\t2," .. B36(5000), "PARTY", "Bob")
	Equal(DM.GetSources(E.GetCurrent(), T.DamageDone)[1].total, 5000)
	-- Your own messages are ignored.
	Fire("CHAT_MSG_ADDON", "EUIDM", "T\t1\t2," .. B36(99999), "PARTY", "Alex")
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
	Fire("CHAT_MSG_ADDON", "EUIDM", "D\t2\t903\t5000\t1200\t0\tBoss", "PARTY", "Bob")
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
	Fire("CHAT_MSG_ADDON", "EUIDM", "D\t2\t0\t0\t0\t0\t", "PARTY", "Bob")
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

print(string.format("%d passed, %d failed", passed, #failures))
if #failures > 0 then error(table.concat(failures, "\n"), 0) end
