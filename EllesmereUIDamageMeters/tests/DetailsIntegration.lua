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
local playerGUID = "0x0000000000000001"
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
function GetTime() return 20 end
function InCombatLockdown() return locked end
function UnitAffectingCombat() return locked end
function UnitName() return "Alex", "Home" end
function UnitGUID() return playerGUID end
function UnitClass() return "Hunter", "HUNTER" end
function IsInInstance() return true, "party" end
function IsInGroup() return true end
function IsInRaid() return false end
function GetInstanceInfo() return "Dungeon", "party", 1 end
function GetCursorPosition() return 500, 500 end
function GetSpellInfo(id) return "Spell " .. id, nil, "Icon" .. id end
function GetSpecializationInfoByID(id) return id, "Spec", "", "SpecIcon" end
function IsAddOnLoaded(name) return name == "EllesmereUIDamageMeters" end
function geterrorhandler() return error end
ClearOverrideBindings, SetOverrideBindingClick = noop, noop
RAID_CLASS_COLORS = { HUNTER = { r = 0.67, g = 0.83, b = 0.45 }, MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
bit = { band = function(a, b)
	local result, place = 0, 1
	while a > 0 and b > 0 do
		if a % 2 == 1 and b % 2 == 1 then result = result + place end
		a, b, place = math.floor(a / 2), math.floor(b / 2), place * 2
	end
	return result
end }

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
local function Container(actors)
	local c = { _ActorTable = actors, _NameIndexTable = {} }
	for i, actor in ipairs(actors) do c._NameIndexTable[actor.nome] = i end
	return c
end
local function Targets(name, amount)
	local c = Container({ { nome = name, total = amount } })
	function c:GetAmount(target)
		local index = self._NameIndexTable[target]
		return index and self._ActorTable[index].total or 0
	end
	return c
end
local function Combat(damage, heal, misc)
	local c = { Container(damage or {}), Container(heal or {}), Container({}), Container(misc or {}), duration = 20, deaths = {} }
	function c:GetActorList(attribute) return self[attribute]._ActorTable end
	function c:GetCombatTime() return self.duration end
	function c:GetDeaths() return self.deaths end
	function c:GetCombatName() return self.name or "Boss" end
	return c
end
local function Window(enabled)
	local w = { enabled = enabled, closed = 0, opened = 0 }
	function w:IsEnabled() return self.enabled end
	function w:ShutDown() self.enabled = false; self.closed = self.closed + 1 end
	function w:EnableInstance() self.enabled = true; self.opened = self.opened + 1 end
	return w
end
local function Legacy()
	local me = { nome = "Alex-Home", serial = UnitGUID(), classe = "HUNTER", grupo = true, total = 2000.25,
		damage_taken = 300, damage_from = { Boss = true, ["Imp <Boss>"] = true },
		spell_tables = { _ActorTable = { [1] = { total = 500 }, [100] = { total = 1000 } } },
		targets = Targets("Boss", 2000), pets = { "Wolf <Alex-Home>" }, Tempo = function() return 10 end }
	local pet = { nome = "Wolf <Alex-Home>", owner = me, total = 500,
		spell_tables = { _ActorTable = { [200] = { total = 500 } } }, targets = Targets("Boss", 500) }
	local other = { nome = "Casey-Other", classe = "MAGE", grupo = true, total = 1000, targets = Targets("Boss", 1000) }
	local boss = { nome = "Boss", classe = "UNKNOW", flag_original = 0x840, damage_taken = 3000, targets = Targets(me.nome, 300) }
	local imp = { nome = "Imp <Boss>", owner = boss, targets = Targets(me.nome, 100) }
	local outsider = { nome = "Bystander", flag_original = 0x410, total = 9000, damage_taken = 9000 }
	local dummy = { nome = "Dummy", flag_original = 0x820, damage_taken = 100 }
	local healer = { nome = me.nome, serial = me.serial, classe = me.classe, grupo = true, total = 1000,
		pets = { pet.nome }, spell_tables = { _ActorTable = { [300] = { total = 600 } } }, Tempo = function() return 5 end }
	local healpet = { nome = pet.nome, owner = healer, total = 400,
		spell_tables = { _ActorTable = { [301] = { total = 400 } } } }
	local misc = { nome = me.nome, serial = me.serial, grupo = true, interrupt = 3, dispell = 2, pets = { pet.nome },
		interrupt_spell_tables = { _ActorTable = { [400] = { counter = 2 } } },
		dispell_spell_tables = { _ActorTable = { [500] = { dispell = 1 } } } }
	local miscpet = { nome = pet.nome, owner = misc, interrupt = 1, dispell = 1,
		interrupt_spell_tables = { _ActorTable = { [401] = { counter = 1 } } },
		dispell_spell_tables = { _ActorTable = { [500] = { dispell = 1 } } } }
	local current = Combat({ pet, outsider, boss, me, other, imp, dummy }, { healer, healpet }, { misc, miscpet })
	current.deaths = { {
		{ { false, 300, 40, 18, 1, me.nome }, { true, 1, 300, 19, 0, "Boss" }, { 3, 10, 1, 19 } },
		20, me.nome, me.classe, dead_at = 15,
	} }
	local d = {
		playername = me.nome, userversion = "v1.29.3", current = current, overall = Combat(), segments = { current },
		time_type = 2, segments_amount = 25, segments_auto_erase = 1, update_speed = 0.5,
		overall_flag = 1, overall_clear_newboss = false, overall_clear_newchallenge = false,
		cloud_capture = false, use_row_animations = true,
		capture_real = { damage = true, heal = true, energy = true, miscdata = true, aura = true },
		capture_current = {}, tabela_instancias = { Window(true), Window(false), Window(true) },
	}
	function d:GetCombat(which) return which == -1 and self.overall or self.current end
	function d:GetCombatSegments() return self.segments end
	function d:IsInCombat() return self.inCombat or false end
	function d:CaptureGet(key) return self.capture_real[key] end
	function d:CaptureSet(enabled, key, real)
		Equal(real, true, "hard capture toggle")
		self.capture_real[key], self.capture_current[key] = enabled, enabled
	end
	function d:SetWindowUpdateSpeed(value) self.update_speed = value; self.timerUpdated = true end
	function d:SetUseAnimations(value) self.use_row_animations = value; self.animationUpdated = true end
	function d:OverallOptions(bossReset, challengeReset)
		if bossReset ~= nil then self.overall_clear_newboss = bossReset end
		if challengeReset ~= nil then self.overall_clear_newchallenge = challengeReset end
	end
	function d:AtualizaGumpPrincipal(instance, force) Equal(instance, -1); Equal(force, true); self.refreshed = true end
	function d:GetInstance(id) return self.tabela_instancias[id] end
	function d:OpenOptionsWindow(instance, noReopen) self.optionsInstance = instance; Equal(noReopen, true) end
	function d:CreateEventListener()
		local listener = { events = {} }
		function listener:RegisterEvent(event, fn) self.events[event] = fn end
		self.listener = listener
		return listener
	end
	d.tabela_historico = { resetar = function()
		d.reset = true
		d.current, d.overall, d.segments = Combat(), Combat(), {}
		if d.listener then d.listener.events.DETAILS_DATA_RESET() end
	end }
	_G.Details, _G._detalhes = nil, d
	return d
end

local d = Legacy()
assert(loadfile([[EllesmereUIDamageMeters\EllesmereUIDamageMeters_Details.lua]]))("EllesmereUIDamageMeters")
assert(loadfile([[EllesmereUIDamageMeters\EllesmereUIDamageMeters_Meter.lua]]))("EllesmereUIDamageMeters")
local B, DM = EllesmereUI.EDMDetails, EllesmereUI.EDM
local T = DM.T

Test("legacy and modern globals without aliasing or modifying Details", function()
	Equal(B.GetAddon(), d)
	Equal(_G.Details, nil)
	_G.Details = { GetCombat = noop }
	Equal(B.GetAddon(), _G.Details)
	_G.Details = {}
	Equal(B.GetAddon(), d)
	_G.Details = nil
end)

Test("legacy rows: grouping, pets, realm-qualified self, and rates", function()
	local rows, duration = DM.GetSources(d.current, T.DamageDone)
	Equal(#rows, 2); Equal(duration, 20)
	Equal(rows[1].name, d.playername); Equal(rows[1].total, 2000); Equal(rows[1].perSec, 100)
	Equal(rows[1].isLocalPlayer, true); Equal(rows[2].total, 1000)
	local heals = DM.GetSources(d.current, T.HealingDone)
	Equal(#heals, 1); Equal(heals[1].total, 1000); Equal(heals[1].perSec, 50)
end)

Test("legacy spell breakdowns include pets once and label melee", function()
	local rows = DM.GetSources(d.current, T.DamageDone)
	local spells = DM.GetBreakdown(d.current, T.DamageDone, rows[1])
	Equal(#spells, 3); Equal(spells[1].amount, 1000)
	local sum = 0
	for _, spell in ipairs(spells) do sum = sum + spell.amount end
	Equal(sum, 2000); Equal(DM.SpellName(1), "Melee")
	local heals = DM.GetSources(d.current, T.HealingDone)
	local healingSpells = DM.GetBreakdown(d.current, T.HealingDone, heals[1])
	Equal(#healingSpells, 2); Equal(healingSpells[1].amount + healingSpells[2].amount, 1000)
end)

Test("legacy incoming and enemy damage use target containers without pet double counting", function()
	local incoming = DM.GetSources(d.current, T.DamageTaken)
	Equal(#incoming, 1); Equal(incoming[1].total, 300)
	local sources = DM.GetBreakdown(d.current, T.DamageTaken, incoming[1])
	Equal(#sources, 1); Equal(sources[1].label, "Boss"); Equal(sources[1].amount, 300)
	local enemies = DM.GetSources(d.current, T.EnemyDamageTaken)
	Equal(#enemies, 2); Equal(enemies[1].name, "Boss"); Equal(enemies[1].total, 3000)
	local attackers = DM.GetBreakdown(d.current, T.EnemyDamageTaken, enemies[1])
	Equal(#attackers, 2); Equal(attackers[1].amount + attackers[2].amount, 3000)
end)

Test("legacy interrupt and dispel containers include pet actions", function()
	local interrupts = DM.GetSources(d.current, T.Interrupts)
	Equal(#interrupts, 1); Equal(interrupts[1].total, 3)
	local spells = DM.GetBreakdown(d.current, T.Interrupts, interrupts[1])
	Equal(#spells, 2); Equal(spells[1].amount + spells[2].amount, 3)
	local dispels = DM.GetSources(d.current, T.Dispels)
	local dispelSpells = DM.GetBreakdown(d.current, T.Dispels, dispels[1])
	Equal(dispels[1].total, 2); Equal(#dispelSpells, 1); Equal(dispelSpells[1].amount, 2)
end)

Test("death recaps keep chronological offsets and distinguish healing", function()
	local deaths = DM.GetSources(d.current, T.Deaths)
	Equal(#deaths, 1); Equal(deaths[1].deathTime, 15); Equal(deaths[1].isLocalPlayer, true)
	local recap = DM.GetBreakdown(d.current, T.Deaths, deaths[1])
	Equal(#recap, 2); Equal(recap[1].label, "Melee"); Equal(recap[1].ago, -1)
	Equal(recap[1].heal, false); Equal(recap[2].heal, true); Equal(recap[2].ago, -2)
end)

Test("modern spell maps, actor lookup, targets, and enemy API remain supported", function()
	local actor = { nome = d.playername, grupo = true, total = 800, spells = { _ActorTable = { [42] = { total = 800 } } },
		targets = { Enemy = 800 } }
	local enemy = { nome = "Enemy", damage_taken = 800, IsNeutralOrEnemy = function() return true end }
	local modern = Combat({ actor, enemy })
	modern[1].GetActor = function(_, name) return name == actor.nome and actor or enemy end
	_G.Details = { GetCombat = function() return modern end, playername = actor.nome, time_type = 2 }
	Equal(B.GetActor(modern[1], actor.nome), actor)
	local rows = DM.GetSources(modern, T.DamageDone)
	Equal(rows[1].perSec, 40)
	local spells = DM.GetBreakdown(modern, T.DamageDone, rows[1])
	Equal(spells[1].amount, 800)
	local targets = DM.GetSources(modern, T.EnemyDamageTaken)
	Equal(DM.GetBreakdown(modern, T.EnemyDamageTaken, targets[1])[1].amount, 800)
	_G.Details = nil
end)

Test("Details time setting changes EUI DPS/HPS and native windows", function()
	Equal(B.SetSetting("time_type", 1), true); Equal(d.refreshed, true)
	Equal(DM.GetSources(d.current, T.DamageDone)[1].perSec, 200)
	Equal(DM.GetSources(d.current, T.HealingDone)[1].perSec, 200)
	B.SetCapture("damage", false)
	Equal(DM.GetSources(d.current, T.DamageDone)[1].perSec, 100)
	B.SetCapture("damage", true); B.SetSetting("time_type", 2)
	Equal(DM.FormatBarValue(0, 0, 2), "0 (0)")
	d.current.duration = 0
	Equal(DM.GetSources(d.current, T.DamageDone)[1].perSec, nil)
	d.current.duration = 20
end)

Test("all 25 retained segments are selectable and overall timing is consistent", function()
	local old = d.segments
	d.segments = {}
	for i = 1, 25 do d.segments[i] = Combat(); d.segments[i].name = "Fight " .. i end
	Equal(#DM.GetSegments(), 25); Equal(DM.GetSegments()[25].name, "Fight 25")
	d.overall.duration = 0
	Equal(DM.CombatTime(d.overall), 500)
	Equal(DM.GetCombat({ curSession = DM.S.Overall }), d.overall)
	Equal(DM.GetCombat({ curSessionID = old[1] }), old[1])
	d.segments = old
end)

Test("engine settings use native setters and reject invalid or unsupported values", function()
	Equal(B.SetSetting("update_speed", 0.2), true); Equal(d.timerUpdated, true); Equal(d.update_speed, 0.2)
	Equal(B.SetSetting("use_row_animations", false), true); Equal(d.animationUpdated, true)
	Equal(B.SetSetting("overall_clear_newchallenge", true), true); Equal(d.overall_clear_newboss, false)
	Equal(B.SetSetting("overall_clear_newchallenge", false), true); Equal(d.overall_clear_newchallenge, false)
	Equal(B.SetSetting("segments_amount", 10), true)
	local before = #messages
	Equal(B.SetSetting("segments_amount", 0), false)
	Equal(B.SetSetting("segments_amount", 2.5), false)
	Equal(B.SetSetting("update_speed", 0 / 0), false)
	Equal(B.SetSetting("not_a_setting", true), false)
	Equal(#messages, before + 4); Equal(d.segments_amount, 10)
	local setter = d.SetWindowUpdateSpeed
	d.SetWindowUpdateSpeed = nil
	Equal(B.HasSetting("update_speed"), false)
	Equal(B.SetSetting("update_speed", 0.5), false)
	d.SetWindowUpdateSpeed = setter
end)

Test("capture and overall switches persist through Details APIs without changing unrelated flags", function()
	for _, key in ipairs({ "damage", "heal", "energy", "miscdata", "aura" }) do
		Equal(B.SetCapture(key, false), true); Equal(B.GetCapture(key), false); Equal(d.capture_current[key], false)
		B.SetCapture(key, true)
	end
	d.overall_flag = 33
	B.SetOverallFlag(16, true); Equal(d.overall_flag, 49)
	B.SetOverallFlag(16, true); Equal(d.overall_flag, 49)
	B.SetOverallFlag(1, false); Equal(d.overall_flag, 48)
	B.SetOverallFlag(16, false); Equal(d.overall_flag, 32)
end)

Test("native window hiding is reversible, idempotent, and persists over adapter reload", function()
	d.initializing = true
	Equal(B.SetWindowsHidden(true), nil); Equal(d.tabela_instancias[1].closed, 0)
	d.initializing = nil
	Equal(B.SetWindowsHidden(true), true)
	Equal(d.tabela_instancias[1].closed, 1); Equal(d.tabela_instancias[2].closed, 0)
	B.SetWindowsHidden(true); Equal(d.tabela_instancias[1].closed, 1)
	assert(loadfile([[EllesmereUIDamageMeters\EllesmereUIDamageMeters_Details.lua]]))("EllesmereUIDamageMeters")
	B = EllesmereUI.EDMDetails
	B.SetWindowsHidden(false)
	Equal(d.tabela_instancias[1].opened, 1); Equal(d.tabela_instancias[2].opened, 0)
	Equal(d.tabela_instancias[3].opened, 1); Equal(EllesmereUIDamageMetersDB.detailsWindowRestore, nil)
end)

Test("advanced options receive the existing native instance without forcing it open", function()
	Equal(B.OpenOptions(), true)
	Equal(d.optionsInstance, d.tabela_instancias[1])
end)

Test("native window restoration is isolated between characters", function()
	local firstGUID, firstWindows = playerGUID, d.tabela_instancias
	B.SetWindowsHidden(true)
	playerGUID = "0x0000000000000002"
	d.tabela_instancias = { Window(false), Window(true), Window(false) }
	B.SetWindowsHidden(true)
	B.SetWindowsHidden(false)
	Equal(d.tabela_instancias[1].opened, 0); Equal(d.tabela_instancias[2].opened, 1)
	Equal(d.tabela_instancias[3].opened, 0)
	assert(EllesmereUIDamageMetersDB.detailsWindowRestore[firstGUID], "other character's restore state must be kept")
	playerGUID, d.tabela_instancias = firstGUID, firstWindows
	B.SetWindowsHidden(false)
	Equal(firstWindows[1].enabled, true); Equal(firstWindows[2].enabled, false); Equal(firstWindows[3].enabled, true)
	Equal(EllesmereUIDamageMetersDB.detailsWindowRestore, nil)
end)

Test("reset supports r236, blocks player/Details combat, and fails visibly when unsupported", function()
	local original = d
	d = Legacy()
	locked = true
	Equal(DM.ResetData(), false); Equal(d.reset, nil)
	locked = false; d.inCombat = true
	Equal(DM.ResetData(), false); Equal(d.reset, nil)
	d.inCombat = false
	Equal(DM.ResetData(), true); Equal(d.reset, true); Equal(#d.segments, 0)
	d.tabela_historico = nil
	Equal(DM.ResetData(), false)
	d = original; _G._detalhes = d
	local modern = { GetCombat = noop, ResetSegmentData = function(self) self.reset = true end }
	_G.Details = modern
	Equal(DM.ResetData(), true); Equal(modern.reset, true)
	_G.Details = nil
end)

Test("modern look preserves layout, selected meters, visibility, bookmarks, and native settings", function()
	local config = DM.DB()
	local windows, bookmarks, count, visibility = config.windows, config.bookmarks, config.windowCount, config.visibility
	local nativeRate = d.update_speed
	DM.ApplyModernStyle()
	Equal(config.windows, windows); Equal(config.bookmarks, bookmarks); Equal(config.windowCount, count)
	Equal(config.visibility, visibility); Equal(d.update_speed, nativeRate)
	Equal(config.barTexture, "none"); Equal(config.barHeight, 20); Equal(config.rightFontSize, 12)
end)

Test("login builds meter windows and renders actual legacy data and breakdowns", function()
	Fire("ADDON_LOADED", "EllesmereUIDamageMeters")
	Fire("PLAYER_LOGIN")
	Equal(#DM.windows, DM.DB().windowCount)
	local window = DM.windows[1]
	window.curSession = DM.S.Current
	window.SetDMType(T.DamageDone)
	Equal(window.count, 2); Equal(window.rows[1].label:GetText(), "Alex")
	Equal(window.rows[1].amount:GetText(), "2K (100)")
	window.OpenSource(window.sources[1])
	Equal(window.srcCount, 3)
	window.CloseSource()
	local found = false
	for _, element in ipairs(EllesmereUI.unlockList) do if element.key == "EDM_Win1" then found = true end end
	Equal(found, true)
end)

Test("Details events clear stale segments and breakdowns and honor auto-current", function()
	local window = DM.windows[1]
	DM.WinDB(1).autoCurrentOnCombat = true
	window.curSession = DM.S.Overall
	d.listener.events.COMBAT_PLAYER_ENTER()
	Equal(window.curSession, DM.S.Current)
	window.SetDMType(T.DamageDone)
	window.OpenSource(window.sources[1])
	window.curSessionID = Combat()
	d.listener.events.DETAILS_DATA_SEGMENTREMOVED()
	Equal(window.curSessionID, nil); Equal(window.source, nil)
	window.OpenSource(window.sources[1])
	d.listener.events.DETAILS_DATA_RESET()
	Equal(window.source, nil)
end)

Test("empty current fights show an explicit no-data message", function()
	local current = d.current
	d.current = Combat()
	local window = DM.windows[1]
	window.curSessionID, window.curSession = nil, DM.S.Current
	window.SetDMType(T.DamageDone)
	Equal(window.count, 0); Equal(window.msg:GetText(), "No combat data"); Equal(window.msg:IsShown(), true)
	d.current = current
	window.Refresh()
	Equal(window.count, 2); Equal(window.msg:IsShown(), false)
end)

Test("EUI Details tab edits the real engine and remains usable without Details", function()
	local module
	EllesmereUI.RegisterSettingsModule = function(def) module = def end
	EllesmereUI.OptionsUtil = {
		KeyItems = function(items) return items end,
		KeyLabel = function(items, value)
			for _, item in ipairs(items) do if item.key == value then return item.text end end
			return "Unavailable"
		end,
	}
	assert(loadfile([[EllesmereUIOptions\EUI_DamageMeters_Options.lua]]))("EllesmereUIOptions")
	Equal(module.name, "Damage Meters")
	local page
	for _, tab in ipairs(module.tabs) do if tab.key == "details" then page = tab end end
	assert(page, "Details tab must be registered")
	local controls = {}
	local recorder = { Section = noop, Paragraph = noop, Button = noop }
	function recorder:Toggle(label, _, get, set, disabled) controls[label] = { get = get, set = set, disabled = disabled } end
	function recorder:Slider(label, _, low, high, step, get, set, disabled) controls[label] = { get = get, set = set, disabled = disabled } end
	function recorder:Dropdown(label, _, items, get, getLabel, set, _, disabled) controls[label] = { get = get, set = set, disabled = disabled } end
	page.build(recorder)
	controls["Stored Combat Segments"].set(12); Equal(d.segments_amount, 12)
	controls["Collect Healing"].set(false); Equal(d.capture_real.heal, false)
	Equal(controls["Collect Damage"].get(), true)
	controls["Collect Healing"].set(true)
	controls["DPS / HPS Time Measurement"].set(1); Equal(d.time_type, 1)
	controls["DPS / HPS Time Measurement"].set(2)
	_G._detalhes = nil
	page.build({ Section = noop, Paragraph = noop })
	DM.windows[1].Refresh()
	Equal(DM.windows[1].msg:GetText(), "Details! is required")
	local before = #messages
	Equal(B.SetSetting("segments_amount", 10), false); Equal(#messages, before + 1)
	_G._detalhes = d
end)

print(string.format("%d passed, %d failed", passed, #failures))
if #failures > 0 then error(table.concat(failures, "\n"), 0) end
