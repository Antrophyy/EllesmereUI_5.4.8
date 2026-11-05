-- Run with Lua 5.1 from the repository root. No game installation is accessed.
assert(_VERSION == "Lua 5.1", "These checks must run on Lua 5.1.")

local passed, failures = 0, {}
local function Equal(actual, expected)
	assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
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
local function Upvalue(fn, key)
	for i = 1, 60 do
		local name, value = debug.getupvalue(fn, i)
		if name == key then return value end
		if not name then break end
	end
	error("Missing upvalue: " .. key)
end

local noop = function() end
local now, messages = 100, {}
local guids = { player = "Player1", raid1 = "Player1", raid2 = "Player2", pet = "Pet1",
	target = "Enemy1", focus = "Enemy1", boss1 = "Enemy1", vehicle = "Vehicle1" }
for i = 3, 10 do guids["raid" .. i] = "Player" .. i end
for i = 1, 4 do guids["party" .. i] = "Party" .. i end
local harmful, helpful = {}, {}
function wipe(t) for key in pairs(t) do t[key] = nil end; return t end
format = string.format
tremove = table.remove
function GetTime() return now end
function UnitGUID(unit) return guids[unit] end
function UnitExists(unit) return guids[unit] ~= nil end
function UnitIsUnit(a, b) return guids[a] and guids[a] == guids[b] end
function UnitClass() return "Death Knight", "DEATHKNIGHT" end
function UnitPlayerControlled(unit) return unit and unit ~= "boss1" and unit ~= "target" end
function UnitCanAttack(_, unit) return unit == "target" or unit == "focus" end
function UnitIsFriend(_, unit) return not UnitCanAttack("player", unit) end
function UnitName(unit) return unit, "Realm" end
function UnitHealth() return 75000 end
function UnitHealthMax() return 100000 end
function UnitIsDeadOrGhost() return false end
function UnitIsConnected() return true end
function UnitGroupRolesAssigned() return "TANK" end
function GetNumGroupMembers() return 2 end
function GetPartyAssignment() return false end
function IsInRaid() return true end
function InCombatLockdown() return false end
function GetSpecialization() return 1 end
function GetSpecializationInfo() return 250, "Blood", "", "", "TANK" end
function GetSpecializationRole() return "TANK" end
function GetSpellInfo(id) return "Spell " .. id, nil, "Icon" .. id end
RegisterUnitWatch, UnregisterUnitWatch = noop, noop
RAID_CLASS_COLORS = { DEATHKNIGHT = { r = 0.77, g = 0.12, b = 0.23 } }
DebuffTypeColor = { Disease = { r = 0.6, g = 0.4, b = 0 } }
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) messages[#messages + 1] = message end }
function UnitAura(unit, index, filter)
	local list = filter == "HELPFUL" and helpful[unit] or harmful[unit]
	local a = list and list[index]
	if not a then return nil end
	return a.name or ("Spell " .. a.spellId), nil, a.icon or ("Icon" .. a.spellId), a.count or 0, a.dtype,
		a.duration or 30, a.expires or 130, a.caster, a.stealable, nil, a.spellId, a.canApply, a.isBoss
end
local originalUnitAura = UnitAura

local Frame = {}
Frame.__index = Frame
function CreateFrame(_, name, parent)
	local f = setmetatable({ scripts = {}, events = {}, shown = true, width = 200, height = 30, parent = parent }, Frame)
	if name then _G[name] = f end
	return f
end
function Frame:CreateTexture() return CreateFrame("Texture", nil, self) end
function Frame:CreateFontString() return CreateFrame("FontString", nil, self) end
function Frame:SetScript(event, fn) self.scripts[event] = fn end
function Frame:HookScript(event, fn)
	local previous = self.scripts[event]
	self.scripts[event] = function(...)
		if previous then previous(...) end
		fn(...)
	end
end
function Frame:RegisterEvent(event) self.events[event] = true end
function Frame:UnregisterEvent(event) self.events[event] = nil end
function Frame:RegisterUnitEvent(event) self:RegisterEvent(event) end
function Frame:UnregisterAllEvents() wipe(self.events) end
function Frame:SetAttribute(key, value) self[key] = value end
function Frame:GetAttribute(key) return self[key] end
function Frame:Hide() self.shown = false end
function Frame:Show() self.shown = true end
function Frame:SetShown(shown) self.shown = shown and true or false end
function Frame:IsShown() return self.shown end
function Frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function Frame:SetSize(w, h) self.width, self.height = w, h end
function Frame:GetSize() return self.width, self.height end
function Frame:SetPoint(...) self.point = { ... } end
function Frame:ClearAllPoints() self.point = nil end
function Frame:SetWidth(w) self.width = w end
function Frame:SetHeight(h) self.height = h end
function Frame:GetWidth() return self.width end
function Frame:GetHeight() return self.height end
function Frame:GetFrameLevel() return 1 end
function Frame:GetFrameStrata() return "MEDIUM" end
function Frame:GetEffectiveScale() return 1 end
function Frame:GetParent() return self.parent end
function Frame:SetText(text) self.text = text end
function Frame:GetText() return self.text end
function Frame:GetStringWidth() return #(self.text or "") * 6 end
function Frame:SetTexture(texture) self.texture = texture end
function Frame:SetCooldown(start, duration) self.start, self.duration = start, duration end
function Frame:SetOwner(owner) self.owner = owner end
function Frame:IsOwned(owner) return self.owner == owner end
function Frame:SetUnitAura(unit, index, filter) self.aura = { unit, index, filter } end
function Frame:GetFont() return "font", 12, "" end
function Frame:GetStatusBarTexture()
	if not self.barTexture then self.barTexture = self:CreateTexture() end
	return self.barTexture
end
for _, name in ipairs({
	"SetAllPoints", "SetFrameLevel", "SetFrameStrata", "SetReverse",
	"SetFont", "SetTextColor", "SetShadowColor", "SetShadowOffset", "SetJustifyH", "SetJustifyV",
	"SetWordWrap", "SetNonSpaceWrap", "SetTexCoord", "SetBlendMode", "SetVertexColor", "SetDrawLayer",
	"EnableMouse", "RegisterForClicks", "SetBorderSize", "SetBorderColor", "SetAlpha", "SetClipsChildren",
	"SetStatusBarTexture", "SetStatusBarColor", "SetValue", "SetMinMaxValues", "SetClampedToScreen",
	"SetHideCountdownNumbers", "SetOrientation", "SetReverseFill", "SetScale",
	"SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor",
}) do Frame[name] = noop end
function CooldownFrame_SetTimer(frame, start, duration) frame:SetCooldown(start, duration) end
local function NewText(parent) return parent:CreateFontString() end
local function CreateEdges() return {} end
local function LayoutEdges(edges, size) edges.size = size end
local function Shown(icons)
	local n = 0
	for _, icon in ipairs(icons) do if icon:IsShown() then n = n + 1 end end
	return n
end
UIParent = CreateFrame("Frame")
GameTooltip = CreateFrame("GameTooltip")
EllesmereUI = { applyHooks = {}, Print = noop }
local ns = EllesmereUI
Test("the core manifest loads the shared aura function after creating the namespace", function()
	local loaded = 0
	for line in io.lines([[EllesmereUI\EllesmereUI.toc]]) do
		line = line:match("^%s*(.-)%s*$")
		if line == "EllesmereUI.lua" or line == "EllesmereUI_Auras.lua" then
			assert(loadfile([[EllesmereUI\]] .. line))("EllesmereUI", ns)
			loaded = loaded + 1
		end
	end
	Equal(loaded, 2); Equal(EllesmereUI, ns); Equal(type(ns.FilterDuplicateDiseases), "function")
end)
local Filter = ns.FilterDuplicateDiseases

local function Aura(id, caster, expires, index)
	return { spellId = id, caster = caster, expires = expires or 130, duration = 30, index = index, count = 0 }
end
local function ReportedAuras()
	local ids = { 115798, 55095, 55078, 55095, 55078, 44457, 8050, 31803, 81326, 14914,
		118253, 118297, 348, 130320, 115804, 1130, 146198, 81298, 128531 }
	local casters = { "player", "player", "player", "player", "player", "raid6", "raid9", "party3", "party3",
		"raid8", "party2", "raidpet9", "raid7", "party4", "party4", "party2", "raid7", false, "party4" }
	local list = {}
	for i, id in ipairs(ids) do
		list[i] = Aura(id, casters[i] or nil, i <= 3 and 120 or 130, i)
		if id == 55095 or id == 55078 then list[i].dtype = "Disease" end
	end
	return list
end

Test("the reported 19 aura entries produce 17 distinct displayed debuffs", function()
	local raw = ReportedAuras()
	local list, n = Filter(raw)
	Equal(#raw, 19); Equal(#list, 17); Equal(n, 17)
	Equal(list[1], raw[1]); Equal(list[2], raw[4]); Equal(list[3], raw[5]); Equal(list[4], raw[6])
	Equal(raw[2].index, 2); Equal(raw[4].index, 4)
end)
Test("latest expiry keeps the whole record and never sums stack counts", function()
	local a, b = Aura(55095, "player", 120, 1), Aura(55095, "player", 130, 2)
	a.count, b.count = 2, 3
	local list = Filter({ a, b })
	Equal(#list, 1); Equal(list[1], b); Equal(list[1].count, 3); Equal(list[1].index, 2)
	b.expires = 120
	Equal(Filter({ a, b })[1], a)
end)
Test("separate casters, pets, and diseases remain separate", function()
	local raw = { Aura(55095, "player"), Aura(55095, "raid2"), Aura(55095, "pet"),
		Aura(55078, "player"), Aura(55078, "raid2") }
	Equal(Filter(raw), raw); Equal(#Filter(raw), 5)
end)
Test("unit-token aliases for the same source are consolidated", function()
	local a, b = Aura(55078, "player", 120), Aura(55078, "raid1", 130)
	Equal(#Filter({ a, b }), 1); Equal(Filter({ a, b })[1], b)
end)
Test("unknown casters are not merged and unresolved tokens are kept distinct", function()
	local raw = { Aura(55095), Aura(55095), Aura(55095, ""), Aura(55095, ""),
		Aura(55095, "raid39"), Aura(55095, "raid40") }
	Equal(Filter(raw), raw); Equal(#Filter(raw), 6)
end)
Test("nameplate source GUID snapshots survive recycled unit tokens", function()
	local a, b = Aura(55095, "raid2"), Aura(55095, "raid2")
	a.casterGUID, b.casterGUID = "OldMember", "NewMember"
	Equal(#Filter({ a, b }), 2)
	b.casterGUID, b.caster = "OldMember", nil
	Equal(#Filter({ a, b }), 1)
end)
Test("other spells are not merged even when name, icon, spell and caster match", function()
	local a, b = Aura(44457, "player"), Aura(44457, "player")
	a.name, b.name, a.icon, b.icon = "Same", "Same", "Icon", "Icon"
	Equal(#Filter({ a, b }), 2)
	a.spellId, b.spellId = 55078, 55095
	Equal(#Filter({ a, b }), 2)
end)
Test("bounded scans ignore stale pooled entries and never mutate the source array", function()
	local raw = { Aura(55095, "player", 120), Aura(55095, "player", 130), Aura(55078, "player", 999) }
	local list, n = Filter(raw, 2)
	Equal(n, 1); Equal(list[1], raw[2]); Equal(#raw, 3); Equal(raw[1].expires, 120)
	local same, zero = Filter(raw, 0)
	Equal(same, raw); Equal(zero, 0)
	Equal(select(2, Filter(raw, 1)), 1)
	Equal(select(2, Filter(raw, 3)), 2)
end)
Test("the normalizer supports cached id records without hooking UnitAura", function()
	local a, b = { id = 55095, casterGUID = "Source", expires = 120 }, { id = 55095, casterGUID = "Source", expires = 130 }
	Equal(Filter({ a, b })[1], b)
	Equal(UnitAura, originalUnitAura)
	local empty = {}; Equal(Filter(empty), empty)
end)

assert(loadfile([[EllesmereUIUnitFrames\EUI_UnitFrames_Core.lua]]))("EllesmereUIUnitFrames")
local coreUF = ns.UF
Test("Target, Focus, and Boss aura defaults preserve independent saved values", function()
	local defaults = coreUF.Defaults()
	for _, key in ipairs({ "target", "focus", "boss" }) do
		Equal(defaults[key].debuffMineScale, 100); Equal(defaults[key].debuffMineFirst, false)
		Equal(defaults[key].debuffGrowth, "auto")
	end
	Equal(defaults.player.debuffMineScale, nil); Equal(defaults.player.debuffMineFirst, nil)
	local previous = EllesmereUIUnitFramesDB
	EllesmereUIUnitFramesDB = {
		target = { debuffSize = 24 },
		focus = { debuffMineScale = 150, debuffMineFirst = true, debuffGrowth = "down" },
		boss = { debuffMineScale = 125, debuffMineFirst = true, debuffGrowth = "right" },
	}
	local db = coreUF.InitDB()
	Equal(db.target.debuffMineScale, 100); Equal(db.target.debuffSize, 24)
	Equal(db.target.debuffMineFirst, false)
	db.target.debuffMineScale = 135
	db.target.debuffMineFirst = true
	coreUF.InitDB()
	Equal(db.target.debuffMineScale, 135)
	Equal(db.target.debuffMineFirst, true)
	Equal(db.focus.debuffMineScale, 150); Equal(db.focus.debuffMineFirst, true); Equal(db.focus.debuffGrowth, "down")
	Equal(db.boss.debuffMineScale, 125); Equal(db.boss.debuffMineFirst, true); Equal(db.boss.debuffGrowth, "right")
	EllesmereUIUnitFramesDB = previous
end)

local settings = {}
local UF = { db = {}, frames = {}, DISPEL_BY_CLASS = {}, DISPEL_KEYS = {},
	Settings = function(key) return settings[key] end, IsFake = function(frame) return frame.fake end,
	Pixel = function() return 1 end, NewText = NewText, SetFont = function(fs, size) fs.fontSize = size end,
	MAIN_UNITS = coreUF.MAIN_UNITS, MINI_UNITS = coreUF.MINI_UNITS, UNIT_LABELS = coreUF.UNIT_LABELS,
	CLASS_STYLE_ORDER = coreUF.CLASS_STYLE_ORDER, CLASS_STYLE_NAMES = coreUF.CLASS_STYLE_NAMES,
	CreateBorder = function() return CreateFrame("Frame") end }
ns.UF = UF
assert(loadfile([[EllesmereUIUnitFrames\EUI_UnitFrames_Auras.lua]]))("EllesmereUIUnitFrames")
local function UnitFrame(key)
	harmful[key] = ReportedAuras()
	local frame = CreateFrame("Frame")
	frame.unit, frame.unitKey = key, key
	frame.settingsKey = key:match("^boss%d$") and "boss" or key
	frame.isBoss = frame.settingsKey == "boss"
	settings[frame.settingsKey] = {
		maxDebuffs = 20, debuffAnchor = "bottomleft", debuffShowCooldownText = true, showAuraTooltips = true,
		simpleBuffs = "none", simpleDebuffs = "none",
	}
	if frame.isBoss then guids[key] = guids[key] or key end
	frame.settings = settings[frame.settingsKey]
	UF.frames[key] = frame
	UF.CreateAuraContainers(frame)
	return frame
end
local function DebuffOrder(frame, expected)
	Equal(Shown(frame.Debuffs.icons), #expected)
	for i, index in ipairs(expected) do Equal(frame.Debuffs.icons[i].index, index) end
end
Test("target and focus render one icon per disease with correct timer and tooltip index", function()
	for _, key in ipairs({ "target", "focus" }) do
		local frame = UnitFrame(key)
		UF.UpdateAuras(frame)
		Equal(Shown(frame.Debuffs.icons), 17)
		local icon = frame.Debuffs.icons[2]
		Equal(icon.index, 4); Equal(icon.expires, 130); Equal(icon.cd.start, 100)
		icon.scripts.OnEnter(icon)
		Equal(GameTooltip.aura[1], key); Equal(GameTooltip.aura[2], 4); Equal(GameTooltip.aura[3], "HARMFUL")
	end
end)
Test("unit-frame caps and own/exclude filters apply without disease copies filling slots", function()
	local frame = UnitFrame("target")
	settings.target.maxDebuffs, settings.target.debuffFilterMode = 3, "own"
	UF.UpdateAuras(frame)
	Equal(Shown(frame.Debuffs.icons), 3); Equal(frame.Debuffs.icons[3].index, 5)
	settings.target.debuffExclude = { [55095] = true }
	UF.UpdateAuras(frame)
	Equal(Shown(frame.Debuffs.icons), 2); Equal(frame.Debuffs.icons[2].index, 5)
	harmful.target = {}
	UF.UpdateAuras(frame)
	Equal(Shown(frame.Debuffs.icons), 0)
end)
Test("helpful auras are unchanged and a second DK still gets its own debuff", function()
	local frame = UnitFrame("target")
	helpful.target = { Aura(55095, "player"), Aura(55095, "player") }
	harmful.target[#harmful.target + 1] = Aura(55095, "raid2")
	UF.UpdateAuras(frame)
	Equal(Shown(frame.Buffs.icons), 2); Equal(Shown(frame.Debuffs.icons), 18)
	helpful.target = nil
end)
Test("refreshing either copy and removing one copy never creates or loses an extra icon", function()
	local frame = UnitFrame("target")
	harmful.target = { Aura(55095, "player", 120), Aura(55095, "player", 130) }
	UF.UpdateAuras(frame)
	Equal(Shown(frame.Debuffs.icons), 1); Equal(frame.Debuffs.icons[1].index, 2)
	harmful.target[1].expires = 135
	UF.UpdateAuras(frame)
	Equal(Shown(frame.Debuffs.icons), 1)
	Equal(frame.Debuffs.icons[1].index, 1); Equal(frame.Debuffs.icons[1].expires, 135)
	table.remove(harmful.target, 1)
	UF.UpdateAuras(frame)
	Equal(Shown(frame.Debuffs.icons), 1)
	Equal(frame.Debuffs.icons[1].index, 1); Equal(frame.Debuffs.icons[1].expires, 130)
end)
Test("the debug command labels suppressed raw copies instead of claiming they are shown", function()
	local frame = UnitFrame("target")
	UF.UpdateAuras(frame)
	wipe(messages)
	SlashCmdList.EUIAURAS("target")
	local copies = 0
	for _, line in ipairs(messages) do
		if line:find("duplicate hidden", 1, true) then
			copies = copies + 1
			assert(line:find("guid=Player1", 1, true))
			assert(line:find("expires=120", 1, true))
		end
	end
	Equal(copies, 2)
end)
Test("diagnostics do not call real auras duplicates while sample icons are previewed", function()
	local frame = UnitFrame("target")
	frame.preview, UF.previewAuras = true, true
	UF.UpdateAuras(frame)
	wipe(messages)
	SlashCmdList.EUIAURAS("target")
	frame.preview, UF.previewAuras = nil, nil
	local preview = 0
	for _, line in ipairs(messages) do
		assert(not line:find("duplicate hidden", 1, true))
		if line:find("preview active", 1, true) then preview = preview + 1 end
	end
	Equal(preview, 19)
end)

Test("125 percent enlarges only own target debuffs and leaves texts and tooltips unchanged", function()
	local frame = UnitFrame("target")
	settings.target.debuffMineScale = 125
	UF.UpdateAuras(frame)
	Equal(Shown(frame.Debuffs.icons), 17)
	local mine, other = frame.Debuffs.icons[2], frame.Debuffs.icons[4]
	Equal(mine:GetWidth(), 27.5); Equal(mine:GetHeight(), 27.5); Equal(other:GetWidth(), 22)
	Equal(mine.timer.fontSize, 10); Equal(mine.count.fontSize, 14)
	Equal(mine.index, 4); Equal(mine.expires, 130)
	mine.scripts.OnEnter(mine)
	Equal(GameTooltip.aura[2], 4)
end)
Test("own sizing includes pet, vehicle, and player token aliases but not unknown sources", function()
	local frame = UnitFrame("target")
	settings.target.debuffMineScale = 150
	harmful.target = {
		Aura(1001, "player"), Aura(1002, "pet"), Aura(1003, "vehicle"), Aura(1004, "raid1"),
		Aura(1005, "raid2"), Aura(1006),
	}
	UF.UpdateAuras(frame)
	for i = 1, 4 do Equal(frame.Debuffs.icons[i]:GetWidth(), 33) end
	Equal(frame.Debuffs.icons[5]:GetWidth(), 22); Equal(frame.Debuffs.icons[6]:GetWidth(), 22)
end)
Test("buffs and unsupported player/pet frames stay at their normal size", function()
	local target = UnitFrame("target")
	settings.target.debuffMineScale = 150
	helpful.target = { Aura(1001, "player") }
	UF.UpdateAuras(target)
	Equal(target.Buffs.icons[1]:GetWidth(), 22)
	helpful.target = nil
	for _, key in ipairs({ "player", "pet" }) do
		local frame = UnitFrame(key)
		settings[key].debuffMineScale = 150
		UF.UpdateAuras(frame)
		Equal(frame.Debuffs.icons[1]:GetWidth(), 22)
	end
end)
Test("100 percent keeps the original uniform layout", function()
	local frame = UnitFrame("target")
	settings.target.debuffMineScale, settings.target.debuffMaxPerRow = 100, 3
	UF.UpdateAuras(frame)
	local expected = { { 0, 0 }, { 23, 0 }, { 46, 0 }, { 0, -23 }, { 23, -23 }, { 46, -23 } }
	for i, point in ipairs(expected) do
		local icon = frame.Debuffs.icons[i]
		Equal(icon:GetWidth(), 22); Equal(icon:GetHeight(), 22)
		Equal(icon.point[4], point[1]); Equal(icon.point[5], point[2])
	end
end)
Test("mixed rows advance by the largest icon and recalculate on same-count ownership changes", function()
	local frame = UnitFrame("target")
	local s = settings.target
	s.debuffSize, s.debuffMineScale, s.debuffMaxPerRow = 20, 125, 2
	harmful.target = { Aura(1001, "player"), Aura(1002, "raid2"), Aura(1003, "raid2"), Aura(1004, "player") }
	UF.UpdateAuras(frame)
	local icons = frame.Debuffs.icons
	Equal(icons[2].point[4], 26); Equal(icons[3].point[5], -26); Equal(icons[4].point[4], 21)
	harmful.target[1].caster = "raid2"
	UF.UpdateAuras(frame)
	Equal(Shown(icons), 4); Equal(icons[1]:GetWidth(), 20)
	Equal(icons[2].point[4], 21); Equal(icons[3].point[5], -21)
	harmful.target[2].caster = "player"
	UF.UpdateAuras(frame)
	Equal(icons[2]:GetWidth(), 25); Equal(icons[3].point[5], -26)
end)
Test("cropped icons keep their aspect ratio and resize live through the normal layout path", function()
	local frame = UnitFrame("target")
	local s = settings.target
	s.debuffSize, s.debuffMineScale, s.debuffCropIcons = 20, 125, true
	UF.UpdateAuras(frame)
	local icon = frame.Debuffs.icons[1]
	Equal(icon:GetWidth(), 25); Equal(icon:GetHeight(), 18.75)
	s.debuffMineScale = 200
	UF.LayoutAuras(frame); UF.UpdateAuras(frame)
	Equal(icon:GetWidth(), 40); Equal(icon:GetHeight(), 30)
	s.debuffMineScale = 100
	UF.LayoutAuras(frame); UF.UpdateAuras(frame)
	Equal(icon:GetWidth(), 20); Equal(icon:GetHeight(), 15)
end)

local function Bounds(icon)
	local point = icon.point
	local left = point[4] - (point[1]:find("RIGHT", 1, true) and icon:GetWidth() or 0)
	local bottom = point[5] - (point[1]:find("TOP", 1, true) and icon:GetHeight() or 0)
	return left, bottom, left + icon:GetWidth(), bottom + icon:GetHeight()
end
Test("mixed sizes do not overlap in any of the 60 anchor/growth/crop combinations", function()
	for _, anchor in ipairs({ "topleft", "topright", "bottomleft", "bottomright", "left", "right" }) do
		for _, growth in ipairs({ "auto", "left", "right", "up", "down" }) do
			for _, cropped in ipairs({ false, true }) do
				local frame = UnitFrame("target")
				local s = settings.target
				s.debuffAnchor, s.debuffGrowth, s.debuffCropIcons = anchor, growth, cropped
				s.debuffMineScale, s.debuffMaxPerRow = 150, 3
				harmful.target = {}
				for i = 1, 7 do harmful.target[i] = Aura(1000 + i, i % 2 == 1 and "player" or "raid2") end
				UF.UpdateAuras(frame)
				for i = 1, 7 do
					local left, bottom, right, top = Bounds(frame.Debuffs.icons[i])
					for j = i + 1, 7 do
						local l, b, r, t = Bounds(frame.Debuffs.icons[j])
						assert(not (left < r and right > l and bottom < t and top > b),
							anchor .. "/" .. growth .. "/" .. tostring(cropped) .. ": icons overlap")
					end
				end
			end
		end
	end
end)
Test("preview icons demonstrate both own and other-caster sizes", function()
	local frame = UnitFrame("target")
	settings.target.debuffMineScale = 125
	frame.fake = true
	UF.UpdateAuras(frame)
	Equal(Shown(frame.Debuffs.icons), 6)
	Equal(frame.Debuffs.icons[1]:GetWidth(), 27.5)
	Equal(frame.Debuffs.icons[2]:GetWidth(), 22)
end)
Test("saved scale values are constrained to 100 through 200 percent", function()
	for _, case in ipairs({ { 50, 22 }, { 100, 22 }, { 125, 27.5 }, { 200, 44 }, { 250, 44 } }) do
		local frame = UnitFrame("target")
		settings.target.debuffMineScale = case[1]
		UF.UpdateAuras(frame)
		Equal(frame.Debuffs.icons[1]:GetWidth(), case[2])
	end
end)
Test("Target, Focus, and Boss pages expose all three aura controls as visible rows", function()
	local module
	StaticPopupDialogs = {}
	function IsAddOnLoaded(name) return name == "EllesmereUIUnitFrames" end
	ns.RegisterSettingsModule = function(def) module = def end
	assert(loadfile([[EllesmereUIOptions\EUI_UnitFrames_Options.lua]]))("EllesmereUIOptions")
	local builder = Upvalue(module.tabs[1].build, "AuraRows")
	local controls, cogs, counts = {}, {}, {}
	local page = { Dropdown = noop, Toggle = noop, MultiSelect = noop, Cog = noop, Sync = noop, Swatch = noop,
		Button = noop, Section = noop, Paragraph = noop, Label = noop, WideButton = noop, Blank = noop }
	function page:Slider(label, _, low, high, step, get, set, disabled)
		controls[label] = { low = low, high = high, step = step, get = get, set = set, disabled = disabled }
	end
	function page:Toggle(label, _, get, set, disabled)
		controls[label] = { get = get, set = set, disabled = disabled }
	end
	function page:Dropdown(label, _, items, get, getLabel, set, _, disabled)
		counts[label] = (counts[label] or 0) + 1
		controls[label] = { items = items, get = get, getLabel = getLabel, set = set, disabled = disabled }
	end
	function page:Cog(label, rows) cogs[label] = rows end
	UF.db = coreUF.Defaults()
	local directions = { "right", "up", "down" }
	for i, unit in ipairs({ "target", "focus", "boss" }) do
		wipe(controls); wipe(cogs); wipe(counts)
		if unit == "boss" then module.tabs[2].build(page) else builder(page, unit) end
		local slider, order, growth = controls["My Debuff Size (%)"], controls["My Debuffs First"], controls["Debuff Growth Direction"]
		assert(slider and order and growth, unit .. ": missing a visible aura control")
		Equal(slider.low, 100); Equal(slider.high, 200); Equal(slider.step, 5)
		Equal(slider.get(), 100); Equal(order.get(), false); Equal(growth.get(), "auto")
		Equal(slider.disabled(), false); Equal(order.disabled(), false); Equal(growth.disabled(), false)
		Equal(counts["Debuff Growth Direction"], 1)
		local choices = {}
		for _, item in ipairs(growth.items()) do choices[item.value] = true end
		for _, value in ipairs({ "auto", "up", "down", "left", "right" }) do assert(choices[value]) end
		for _, row in ipairs(cogs["Debuff Settings"]) do assert(row.label ~= "Growth Direction") end
		slider.set(125 + i * 5); order.set(true); growth.set(directions[i])
		Equal(UF.db[unit].debuffMineScale, 125 + i * 5)
		Equal(UF.db[unit].debuffMineFirst, true); Equal(UF.db[unit].debuffGrowth, directions[i])
		UF.db[unit].debuffAnchor = "none"
		if unit == "boss" then
			for _, side in ipairs({ "left", "right" }) do
				UF.db.boss.simpleDebuffs = side
				Equal(slider.disabled(), false); Equal(order.disabled(), false); Equal(growth.disabled(), false)
			end
			UF.db.boss.simpleDebuffs = "none"
		end
		Equal(slider.disabled(), true); Equal(order.disabled(), true); Equal(growth.disabled(), true)
		UF.db[unit].debuffAnchor = "bottomleft"
		Equal(slider.disabled(), false); Equal(order.disabled(), false); Equal(growth.disabled(), false)
	end
	Equal(UF.db.target.debuffMineScale, 130); Equal(UF.db.focus.debuffMineScale, 135); Equal(UF.db.boss.debuffMineScale, 140)
	wipe(controls)
	builder(page, "player")
	assert(controls["Debuff Growth Direction"])
	Equal(controls["My Debuff Size (%)"], nil); Equal(controls["My Debuffs First"], nil)
end)

Test("own-first stably groups target debuffs at the left with rightward growth", function()
	local frame = UnitFrame("target")
	settings.target.debuffMineFirst, settings.target.debuffMineScale = true, 125
	settings.target.debuffGrowth = "right"
	local raw = {
		Aura(44457, "raid2"), Aura(55095, "player"), Aura(8050, "raid3"),
		Aura(55078, "player"), Aura(115798, "player"), Aura(81298),
	}
	harmful.target = raw
	UF.UpdateAuras(frame)
	DebuffOrder(frame, { 2, 4, 5, 1, 3, 6 })
	Equal(frame.Debuffs.icons[1].point[4], 0)
	Equal(frame.Debuffs.icons[4].point[4], 85.5)
	Equal(frame.Debuffs.icons[1]:GetWidth(), 27.5)
	Equal(frame.Debuffs.icons[4]:GetWidth(), 22)
	raw[2].expires, raw[4].expires = 150, 135
	UF.UpdateAuras(frame)
	DebuffOrder(frame, { 2, 4, 5, 1, 3, 6 })
	Equal(raw[1].spellId, 44457); Equal(raw[2].spellId, 55095); Equal(#raw, 6)
end)
Test("own-first includes pet, vehicle, and player aliases while unknown casters follow", function()
	local frame = UnitFrame("target")
	settings.target.debuffMineFirst = true
	harmful.target = {
		Aura(1001, "raid2"), Aura(1002, "pet"), Aura(1003),
		Aura(1004, "raid1"), Aura(1005, "vehicle"), Aura(1006, "player"),
	}
	UF.UpdateAuras(frame)
	DebuffOrder(frame, { 2, 4, 5, 6, 1, 3 })
end)
Test("own-first and disease consolidation happen before display caps without bypassing filters", function()
	local frame = UnitFrame("target")
	settings.target.debuffMineFirst, settings.target.maxDebuffs = true, 2
	harmful.target = {
		Aura(1001, "raid2"), Aura(55095, "player", 120), Aura(1002, "raid3"),
		Aura(55078, "player", 125), Aura(55095, "player", 135),
	}
	UF.UpdateAuras(frame)
	DebuffOrder(frame, { 5, 4 })
	Equal(frame.Debuffs.icons[1].expires, 135)
	frame.Debuffs.icons[1].scripts.OnEnter(frame.Debuffs.icons[1])
	Equal(GameTooltip.aura[2], 5)
	settings.target.debuffExclude = { [55095] = true }
	UF.UpdateAuras(frame)
	DebuffOrder(frame, { 4, 1 })
end)
Test("turning own-first off restores client order and relayouts mixed sizes immediately", function()
	local frame = UnitFrame("target")
	settings.target.debuffMineScale = 125
	harmful.target = { Aura(1001, "raid2"), Aura(1002, "player"), Aura(1003, "raid2"), Aura(1004, "player") }
	UF.UpdateAuras(frame)
	DebuffOrder(frame, { 1, 2, 3, 4 })
	Equal(frame.Debuffs.icons[2].point[4], 23)
	settings.target.debuffMineFirst = true
	UF.UpdateAuras(frame)
	DebuffOrder(frame, { 2, 4, 1, 3 })
	Equal(frame.Debuffs.icons[2].point[4], 28.5)
	settings.target.debuffMineFirst = false
	UF.UpdateAuras(frame)
	DebuffOrder(frame, { 1, 2, 3, 4 })
	Equal(frame.Debuffs.icons[2].point[4], 23)
end)
Test("own-first does not reorder buffs or unsupported player/pet debuffs", function()
	local target = UnitFrame("target")
	settings.target.debuffMineFirst = true
	helpful.target = { Aura(1001, "raid2"), Aura(1002, "player") }
	UF.UpdateAuras(target)
	Equal(target.Buffs.icons[1].index, 1); Equal(target.Buffs.icons[2].index, 2)
	helpful.target = nil
	for _, key in ipairs({ "player", "pet" }) do
		local frame = UnitFrame(key)
		settings[key].debuffMineFirst = true
		harmful[key] = { Aura(1001, "raid2"), Aura(1002, "player") }
		UF.UpdateAuras(frame)
		DebuffOrder(frame, { 1, 2 })
	end
end)
Test("own-first respects leftward growth instead of changing the selected direction", function()
	local frame = UnitFrame("target")
	settings.target.debuffMineFirst, settings.target.debuffMineScale = true, 125
	settings.target.debuffGrowth = "left"
	harmful.target = { Aura(1001, "raid2"), Aura(1002, "player"), Aura(1003, "raid3") }
	UF.UpdateAuras(frame)
	DebuffOrder(frame, { 2, 1, 3 })
	Equal(frame.Debuffs.icons[1].point[1], "TOPRIGHT")
	Equal(frame.Debuffs.icons[2].point[4], -28.5)
end)
Test("the preview prioritizes all own samples before applying a small icon cap", function()
	local frame = UnitFrame("target")
	settings.target.debuffMineFirst, settings.target.debuffMineScale = true, 125
	settings.target.maxDebuffs = 2
	frame.fake = true
	UF.UpdateAuras(frame)
	Equal(Shown(frame.Debuffs.icons), 2)
	Equal(frame.Debuffs.icons[1]:GetWidth(), 27.5); Equal(frame.Debuffs.icons[2]:GetWidth(), 27.5)
	Equal(frame.Debuffs.icons[1].expires, 114); Equal(frame.Debuffs.icons[2].expires, 122)
	settings.target.debuffMineFirst = false
	UF.UpdateAuras(frame)
	Equal(frame.Debuffs.icons[2]:GetWidth(), 22); Equal(frame.Debuffs.icons[2].expires, 118)
end)
Test("own-first preserves all-own, all-other, and empty lists across updates", function()
	local frame = UnitFrame("target")
	settings.target.debuffMineFirst = true
	for _, caster in ipairs({ "player", "raid2" }) do
		harmful.target = { Aura(1001, caster), Aura(1002, caster), Aura(1003, caster) }
		UF.UpdateAuras(frame)
		DebuffOrder(frame, { 1, 2, 3 })
	end
	harmful.target = {}
	UF.UpdateAuras(frame)
	DebuffOrder(frame, {})
end)

Test("Focus and every regular Boss frame support own sizing, ordering, caps, and rightward growth", function()
	for _, key in ipairs({ "focus", "boss1", "boss2", "boss3", "boss4", "boss5" }) do
		local frame = UnitFrame(key)
		local s = settings[frame.settingsKey]
		s.debuffMineScale, s.debuffMineFirst, s.debuffGrowth = 125, true, "right"
		s.debuffSize, s.maxDebuffs = 20, 3
		harmful[key] = { Aura(1001, "raid2"), Aura(55095, "player"), Aura(55078, "player"), Aura(1002, "raid3") }
		UF.UpdateAuras(frame)
		DebuffOrder(frame, { 2, 3, 1 })
		Equal(frame.Debuffs.icons[1]:GetWidth(), 25); Equal(frame.Debuffs.icons[3]:GetWidth(), 20)
		Equal(frame.Debuffs.icons[2].point[4], 26)
		frame.Debuffs.icons[1].scripts.OnEnter(frame.Debuffs.icons[1])
		Equal(GameTooltip.aura[1], key); Equal(GameTooltip.aura[2], 2)
		s.debuffFilterMode = "own"
		UF.UpdateAuras(frame)
		DebuffOrder(frame, { 2, 3 })
	end
end)
Test("Simple Boss Display honors every growth direction on both sides", function()
	for _, side in ipairs({ "left", "right" }) do
		for _, growth in ipairs({ "auto", "left", "right", "up", "down" }) do
			local frame = UnitFrame("boss1")
			frame:SetHeight(40)
			local s = settings.boss
			s.simpleDebuffs, s.debuffAnchor, s.debuffGrowth = side, "none", growth
			s.debuffMineScale, s.debuffMineFirst, s.debuffMaxPerRow = 125, true, 2
			harmful.boss1 = { Aura(1001, "raid2"), Aura(55095, "player"), Aura(1002, "raid3") }
			UF.UpdateAuras(frame)
			DebuffOrder(frame, { 2, 1, 3 })
			local icons = frame.Debuffs.icons
			Equal(icons[1]:GetWidth(), 50); Equal(icons[2]:GetWidth(), 40)
			local direction = growth == "auto" and side or growth
			local x = direction == "left" and -51 or direction == "right" and 51 or 0
			local y = direction == "up" and 51 or direction == "down" and -51 or 0
			Equal(icons[2].point[4], x); Equal(icons[2].point[5], y)
			for i = 1, 3 do
				local l, b, r, t = Bounds(icons[i])
				for j = i + 1, 3 do
					local left, bottom, right, top = Bounds(icons[j])
					assert(not (l < right and r > left and b < top and t > bottom), side .. "/" .. growth .. ": icons overlap")
				end
			end
		end
	end
end)
Test("all five Boss frames share settings and update when those settings change", function()
	local bosses = {}
	for i = 1, 5 do bosses[i] = UnitFrame("boss" .. i); bosses[i]:SetHeight(36) end
	local s = settings.boss
	s.simpleDebuffs, s.debuffGrowth, s.debuffMineScale, s.debuffMineFirst = "right", "down", 150, true
	for i, frame in ipairs(bosses) do
		harmful["boss" .. i] = { Aura(1001, "raid2"), Aura(55078, "player") }
		UF.UpdateAuras(frame)
		DebuffOrder(frame, { 2, 1 }); Equal(frame.Debuffs.icons[1]:GetWidth(), 54)
		Equal(frame.Debuffs.icons[2].point[5], -55)
	end
	s.simpleDebuffs, s.debuffGrowth, s.debuffMineScale, s.debuffMineFirst = "left", "auto", 100, false
	for _, frame in ipairs(bosses) do
		UF.LayoutAuras(frame); UF.UpdateAuras(frame)
		DebuffOrder(frame, { 1, 2 }); Equal(frame.Debuffs.icons[1]:GetWidth(), 36)
		Equal(frame.Debuffs.icons[2].point[4], -37)
	end
end)
Test("Focus and Simple Boss previews demonstrate the new controls", function()
	for _, key in ipairs({ "focus", "boss1" }) do
		local frame = UnitFrame(key)
		frame.fake = true
		frame:SetHeight(40)
		local s = settings[frame.settingsKey]
		s.debuffMineScale, s.debuffMineFirst, s.maxDebuffs, s.debuffGrowth = 150, true, 2, "up"
		if frame.isBoss then s.simpleDebuffs = "right" end
		UF.UpdateAuras(frame)
		local size = frame.isBoss and 60 or 33
		Equal(Shown(frame.Debuffs.icons), 2)
		Equal(frame.Debuffs.icons[1]:GetWidth(), size); Equal(frame.Debuffs.icons[2]:GetWidth(), size)
		Equal(frame.Debuffs.icons[2].point[5], size + 1)
	end
end)
Test("hidden Focus/Boss debuffs stay hidden and simple buffs retain their own layout", function()
	for _, key in ipairs({ "focus", "boss1" }) do
		local frame = UnitFrame(key)
		local s = settings[frame.settingsKey]
		s.debuffMineScale, s.debuffMineFirst, s.debuffAnchor = 150, true, "none"
		UF.UpdateAuras(frame)
		Equal(Shown(frame.Debuffs.icons), 0)
	end
	local frame = UnitFrame("boss1")
	frame:SetHeight(40)
	settings.boss.simpleBuffs, settings.boss.buffGrowth = "left", "up"
	settings.boss.debuffMineScale, settings.boss.debuffGrowth = 150, "down"
	helpful.boss1 = { Aura(1001, "player"), Aura(1002, "raid2") }
	UF.UpdateAuras(frame)
	Equal(frame.Buffs.icons[1]:GetWidth(), 40)
	Equal(frame.Buffs.icons[2].point[4], -41); Equal(frame.Buffs.icons[2].point[5], 0)
	helpful.boss1 = nil
end)

local np = { maxDebuffs = 5 }
local NP = { ns = ns, ENP = {}, Plate = {}, PLAYER_CLASS = "DEATHKNIGHT",
	defaults = { auraDurationTextColor = { r = 1, g = 1, b = 1 }, auraStackTextColor = { r = 1, g = 1, b = 1 } },
	Profile = function() return np end, NewText = NewText, SetFont = noop, IconOutline = function() return "" end,
	CreateEdges = CreateEdges, LayoutEdges = LayoutEdges, SlotSize = function() return 24 end,
	SlotOffsets = function() return 0, 0 end }
assert(loadfile([[EllesmereUINameplates\EUI_Nameplates_Auras.lua]]))("EllesmereUINameplates", NP)
local function Nameplate()
	local plate = CreateFrame("Frame")
	for name, method in pairs(NP.Plate) do plate[name] = method end
	plate.unit, plate.guid = "target", guids.target
	plate.blizz, plate.health, plate.texts = CreateFrame("Frame"), CreateFrame("Frame"), {}
	plate.UpdateColor = noop
	NP.BuildAuras(plate)
	plate:ApplyAuraLayout()
	return plate
end
Test("nameplates render three own debuffs from the five client entries", function()
	harmful.target = ReportedAuras()
	local plate = Nameplate()
	plate:UpdateAuras()
	Equal(plate.auraRows.debuffs.count, 3)
	Equal(plate.auraRows.debuffs.icons[2].aura.expires, 130)
	Equal(#NP.ENP.auraCache[guids.target].debuffs, 5)
end)
Test("cached nameplates stay consolidated after losing their unit token and combat-log refresh", function()
	harmful.target = ReportedAuras()
	local plate = Nameplate()
	plate:UpdateAuras()
	plate.unit = nil
	for _ = 1, 3 do plate:UpdateAuras(); Equal(plate.auraRows.debuffs.count, 3) end
	NP.AuraCombatLog("SPELL_AURA_REFRESH", guids.player, guids.target, 55095, "Frost Fever", "DEBUFF")
	plate:UpdateAuras()
	Equal(plate.auraRows.debuffs.count, 3)
end)
Test("nameplate display caps and custom CC routing use the consolidated lists", function()
	harmful.target = ReportedAuras()
	np.maxDebuffs = 3
	local plate = Nameplate()
	plate:UpdateAuras()
	Equal(plate.auraRows.debuffs.count, 3); Equal(plate.auraRows.debuffs.icons[3].aura.id, 55078)
	np.npAuraFilters = { ccInclude = { [55095] = true } }
	plate:UpdateAuras()
	Equal(plate.auraRows.cc.count, 1); Equal(plate.auraRows.debuffs.count, 2)
	np.npAuraFilters, np.maxDebuffs = nil, 5
end)
Test("nameplate rescans discard old icons and keep other casters when showing all", function()
	harmful.target = { Aura(55095, "player"), Aura(55095, "player"), Aura(55095, "raid2") }
	np.showAllDebuffs = true
	local plate = Nameplate()
	plate:UpdateAuras()
	Equal(plate.auraRows.debuffs.count, 2)
	harmful.target = {}
	plate:UpdateAuras()
	Equal(plate.auraRows.debuffs.count, 0); Equal(Shown(plate.auraRows.debuffs.icons), 0)
	np.showAllDebuffs = nil
end)

assert(loadfile([[EllesmereUIUnitFrames\EUI_UnitFrames_PlayerAuraBars_Presets.lua]]))("EllesmereUIUnitFrames")
assert(loadfile([[EllesmereUIUnitFrames\EUI_UnitFrames_PlayerAuraBars_Seed.lua]]))("EllesmereUIUnitFrames")
assert(loadfile([[EllesmereUIUnitFrames\EUI_UnitFrames_PlayerAuraBars.lua]]))("EllesmereUIUnitFrames")
Test("player aura bars share the same consolidated harmful scan without altering buffs", function()
	harmful.player, helpful.player = ReportedAuras(), { Aura(55095, "player"), Aura(55095, "player") }
	UF.PAB.RefreshAll()
	Equal(#UF.PAB.debuffs, 17); Equal(UF.PAB.debuffs[2].index, 4); Equal(#UF.PAB.buffs, 2)
end)
Test("player aura record recycling does not alias or resurrect hidden copies", function()
	for _ = 1, 3 do
		harmful.player = { Aura(55078, "player"), Aura(55078, "player"), Aura(55095, "raid2") }
		UF.PAB.RefreshAll()
		Equal(#UF.PAB.debuffs, 2); assert(UF.PAB.debuffs[1] ~= UF.PAB.debuffs[2])
		harmful.player = {}
		UF.PAB.RefreshAll()
		Equal(#UF.PAB.debuffs, 0)
		harmful.player = ReportedAuras()
		UF.PAB.RefreshAll()
		Equal(#UF.PAB.debuffs, 17); Equal(UF.PAB.debuffs[2].index, 4)
	end
end)

do
	local presets = UF.PAB_PRESETS
	local defensiveSeed = presets.BM2_FILTER_SEED[1]
	local curated = {}
	for _, id in ipairs(defensiveSeed.enabled) do curated[id] = true end
	local expected = {
		DEATHKNIGHT = { 48707, 48792, 55233, 81256, 42650, 145629 },
		DRUID = { 22812, 61336, 106922, 102342 },
		HUNTER = { 19263, 148467, 53480 },
		MAGE = { 45438, 115760, 110960, 113862 },
		MONK = { 120954, 115203, 122278, 122783, 115176, 131523, 122470, 125174, 116849, 115213 },
		PALADIN = { 498, 642, 31850, 86659, 1022, 6940, 31821 },
		PRIEST = { 47585, 33206, 47788, 114908, 81782 },
		ROGUE = { 31224, 5277, 74001, 74002, 88611 },
		SHAMAN = { 108271, 30823, 98007 },
		WARLOCK = { 104773, 110913, 108416, 132413 },
		WARRIOR = { 871, 12975, 118038, 114030, 114028, 97463 },
	}
	local symbiosis = { 110570, 110575, 113075, 113306, 113072, 110617, 110696,
		126456, 110700, 110715, 110788, 110791, 122291 }
	local minor = {
		49039, 81162, 101568, 77535, 105284,
		124769, 132402, 122286, 102351, 102352,
		5384, 110597, 54216, 62305,
		11426, 1463, 115610, 115611, 110909, 111264,
		115295, 123402, 118604, 115307, 115308, 126453, 116033, 123232, 116844,
		132403, 114039, 1044, 65148, 86273,
		586, 45242, 96267, 114214, 27827, 112833, 17, 47753, 6346, 110717,
		1966, 122289, 45182, 73651,
		114893, 118347, 31616, 8178, 114896,
		6229, 108366, 108359,
		55694, 23920, 113002, 18499, 132404, 112048, 3411, 122292, 114029, 46947,
		59542, 28880, 59543, 59544, 59545, 59547, 59548, 121093,
	}
	local excluded = {
		49222, 122285, -- Bone Shield exception, including Symbiosis
		186265, 212800, 363916, 184364, 192081, 325174, -- later-client replacements/classes
		114216, 114556, 81164, 128939, -- lockout, passive talents, stored Elusive Brew charges
		89485, 123231, 30884, -- non-protective Inner Focus, DPS upgrade, Nature's Guardian passive
		49028, 51052, 62618, 98008, 97462, 76577, 109964, -- cast IDs instead of recipient effects
		48743, 633, 19236, 109304, -- instant heals, no lasting defensive buff
		774, 139, 33763, 2825, 32182, 80353, 105697, 146193, -- ordinary HoTs/offense/gear/consumables
	}
	for _, id in ipairs(minor) do excluded[#excluded + 1] = id end
	Test("original-MoP Defensives contains only the agreed major activated cooldowns", function()
		Equal(defensiveSeed.key, "defensives"); Equal(#defensiveSeed.disabled, 0)
		local required = { [20594] = true }
		for class, ids in pairs(expected) do
			for _, id in ipairs(ids) do
				assert(curated[id], class .. ": missing defensive aura " .. id)
				Equal(presets.SPELL_CLASS_HINTS[id], class)
				required[id] = true
			end
		end
		for _, id in ipairs(symbiosis) do
			assert(curated[id], "missing Symbiosis defense " .. id)
			required[id] = true
		end
		assert(curated[20594], "missing Stoneform")
		for id in pairs(curated) do assert(required[id], "unintended defensive aura " .. id) end
		for _, id in ipairs(excluded) do assert(not curated[id], "not a curated defensive aura: " .. id) end
	end)
	Test("every defensive family stays inside original-MoP defensive coverage", function()
		for id in pairs(curated) do
			for _, member in ipairs(presets.PAB_SPELL_FAMILY[id] or {}) do
				assert(curated[member], "family injects an unrelated/retail aura: " .. id .. " -> " .. member)
			end
		end
		Equal(presets.PAB_SPELL_FAMILY[114908][1], 114908)
		Equal(presets.PAB_SPELL_FAMILY[48792][1], 48792)
	end)
	Test("legacy Defensives migrates once without changing its ID or bar layout", function()
		local original = UF.db.playerAuraBars
		local filter = { id = 42, name = "Defensives", preset = true, spells = {
			[48707] = true, [48792] = false, [49039] = false, [11426] = false, [114214] = false, [114216] = true,
			[186265] = true, [212800] = true, [98765] = true, [98766] = false,
		} }
		local store = { nextId = 51, list = { filter } }
		local bar = { id = 7, filters = { [42] = true }, maxTotal = 4, maxRows = 1, iconsPerRow = 4,
			iconSize = 40, pos = { x = 20, y = -80 }, showAllBuffs = false }
		UF.db.playerAuraBars = { enabled = true, pabFilters = store, customBuffBars = { bar } }
		Equal(ns.PAB_ImportBM2Filters(), 10)
		Equal(store.list[1], filter); Equal(filter.id, 42); Equal(filter.mopDefensivesRevision, 2)
		for id in pairs(curated) do Equal(filter.spells[id], id ~= 48792) end
		Equal(filter.spells[114216], nil); Equal(filter.spells[186265], nil); Equal(filter.spells[212800], nil)
		Equal(filter.spells[98765], true); Equal(filter.spells[98766], false)
		Equal(filter.spells[49222], nil); Equal(filter.spells[122285], nil)
		Equal(bar.filters[42], true); Equal(bar.maxTotal, 4); Equal(bar.maxRows, 1)
		Equal(bar.iconSize, 40); Equal(bar.pos.x, 20); Equal(bar.pos.y, -80)
		local nextId = store.nextId
		ns.PAB_SetSpellState(42, 48707, false)
		filter.spells[120954], filter.spells[115203] = true, false
		Equal(ns.PAB_ImportBM2Filters(), 0); Equal(store.nextId, nextId)
		Equal(filter.spells[48707], false); Equal(filter.spells[110570], false)
		Equal(filter.spells[120954], true); Equal(filter.spells[115203], false)
		UF.db.playerAuraBars = original
	end)
	Test("revision-1 saved filters lose all retired extras while retained choices and custom additions survive", function()
		local f = { id = 31, name = "Defensives", preset = true, mopDefensivesRevision = 1,
			spells = { [98765] = true, [98766] = false } }
		for id in pairs(curated) do f.spells[id] = true end
		for _, id in ipairs(minor) do f.spells[id] = true end
		f.spells[48792], f.spells[110575] = false, false
		local store = { nextId = 32, list = { f } }
		presets.ImportPresets(store)
		Equal(f.id, 31); Equal(f.mopDefensivesRevision, 2)
		for _, id in ipairs(minor) do Equal(f.spells[id], nil, "retired aura " .. id) end
		for id in pairs(curated) do Equal(f.spells[id], id ~= 48792 and id ~= 110575) end
		Equal(f.spells[98765], true); Equal(f.spells[98766], false)
		f.spells[11426] = true -- explicit re-add after migration
		presets.ImportPresets(store)
		Equal(f.spells[11426], true); Equal(f.spells[105284], nil)
		Equal(f.spells[48792], false); Equal(f.spells[110575], false)
		f.mopDefensivesRevision = 3
		presets.ImportPresets(store)
		Equal(f.mopDefensivesRevision, 3)
	end)
	Test("fresh and first-run seeded filters enable all curated defenses without adding Bone Shield", function()
		local stores = { { nextId = 1, list = {} }, UF.PAB_SeedTable().pabFilters }
		for _, store in ipairs(stores) do
			presets.ImportPresets(store)
			local f
			for _, filter in ipairs(store.list) do if filter.name == "Defensives" then f = filter end end
			assert(f)
			for id in pairs(curated) do Equal(f.spells[id], true) end
			for _, id in ipairs(excluded) do Equal(f.spells[id], nil) end
			Equal(presets.ImportPresets(store), 0)
		end
	end)

	local original = UF.db.playerAuraBars
	local store = { nextId = 1, list = {} }
	presets.ImportPresets(store)
	UF.db.playerAuraBars = { enabled = true, pabFilters = store }
	local f = store.list[1]
	local cfg = { showAllBuffs = false, filters = { [f.id] = true } }
	local BuffContent = Upvalue(Upvalue(UF.PAB.RefreshAll, "UpdateBar"), "BuffContent")
	local function CollectBuffs(auras, config, cap)
		helpful.player = auras
		UF.PAB.RefreshAll()
		local out = {}
		BuffContent(config or cfg, out, cap or 40)
		return out
	end
	Test("a Defensives-only bar resolves the complete catalog without extra Raid CDs or Externals filters", function()
		local resolved = ns.PAB_ResolveSpells(cfg)
		Equal(#resolved, #defensiveSeed.enabled)
		for _, id in ipairs(resolved) do assert(curated[id], "unexpected resolved aura " .. id) end
	end)
	Test("every curated aura reaches the real buff collector from self, ally, pet and unknown casters", function()
		for _, caster in ipairs({ "player", "raid2", "pet", false }) do
			for first = 1, #defensiveSeed.enabled, 40 do
				local auras = {}
				for i = first, math.min(first + 39, #defensiveSeed.enabled) do
					auras[#auras + 1] = Aura(defensiveSeed.enabled[i], caster or nil, 130)
				end
				local out = CollectBuffs(auras)
				Equal(#out, #auras)
				for i, aura in ipairs(out) do
					Equal(aura.spellId, auras[i].spellId); Equal(aura.index, i); Equal(aura.filter, "HELPFUL")
				end
			end
		end
	end)
	Test("external and zero-duration area protections display on a DK without caster restrictions", function()
		local auras = {
			Aura(33206, "raid2"), Aura(47788, "party1"), Aura(116849, "raid3"),
			Aura(145629), Aura(81782), Aura(98007), Aura(31821),
			Aura(114908, "raid2"), Aura(115213, "raid3"), Aura(97463, "raid4"),
		}
		for i = 4, 7 do auras[i].duration, auras[i].expires = 0, 0 end
		local out = CollectBuffs(auras)
		Equal(#out, 10)
		Equal(out[6].duration, 0); Equal(out[6].expires, 0)
	end)
	Test("Bone Shield, passive procs, rotational mitigation and minor buffs do not leak into Defensives", function()
		for first = 1, #excluded, 40 do
			local auras = {}
			for i = first, math.min(first + 39, #excluded) do auras[#auras + 1] = Aura(excluded[i], "player") end
			Equal(#CollectBuffs(auras), 0)
		end
	end)
	Test("explicit disabled variants, Hide filters and current icon caps remain effective", function()
		f.spells[48792], f.spells[115203] = false, false
		presets.ImportPresets(store)
		Equal(#CollectBuffs({ Aura(48792, "player"), Aura(115203, "player") }), 0)
		f.spells[48792], f.spells[115203] = true, true
		local hidden = { id = store.nextId, name = "Hidden", spells = { [33206] = true } }
		store.nextId = store.nextId + 1; store.list[#store.list + 1] = hidden
		local narrow = { showAllBuffs = false, filters = cfg.filters, negFilters = { [hidden.id] = true } }
		local auras = { Aura(33206, "raid2"), Aura(48707, "player"), Aura(116849, "raid3") }
		local out = CollectBuffs(auras, narrow)
		Equal(#out, 2); Equal(out[1].spellId, 48707)
		narrow.spells = { 33206 }
		Equal(#CollectBuffs(auras, narrow), 3)
		Equal(#CollectBuffs(auras, cfg, 1), 1)
		Equal(#CollectBuffs({}, cfg), 0)
	end)
	Test("normal bar reload upgrades a linked legacy filter and renders self and ally defenses", function()
		local oldBars = UF.PAB.bars
		UF.PAB.bars = {}
		local legacy = { nextId = 8, list = { { id = 7, name = "Defensives", preset = true,
			spells = { [48707] = true, [49039] = false } } } }
		local barCfg = { id = 9, name = "Defensives", enabled = true, showAllBuffs = false,
			filters = { [7] = true }, maxTotal = 4, iconsPerRow = 4, maxRows = 1, iconSize = 40 }
		UF.db.playerAuraBars = {
			enabled = true, pabFilters = legacy, defaultBuffs = { enabled = false },
			defaultDebuffs = { enabled = false }, customBuffBars = { barCfg }, customDebuffBars = {},
		}
		helpful.player = {
			Aura(49222, "player"), Aura(48707, "player"), Aura(33206, "raid2"),
			Aura(116849, "raid3"), Aura(114908, "raid2"), Aura(145629),
		}
		UF.PAB.ReloadAll()
		local bar
		for _, candidate in pairs(UF.PAB.bars) do if candidate.id == 9 then bar = candidate end end
		assert(bar and bar.shown)
		Equal(bar.count, 4); Equal(bar.cfg, barCfg); Equal(barCfg.maxTotal, 4)
		for i, id in ipairs({ 48707, 33206, 116849, 114908 }) do
			Equal(bar.icons[i].rec.spellId, id); Equal(bar.icons[i].rec.index, i + 1)
			Equal(bar.icons[i]:IsShown(), true)
		end
		helpful.player = { Aura(145629) }
		UF.PAB.RefreshAll()
		Equal(bar.count, 1); Equal(bar.icons[1].rec.spellId, 145629)
		Equal(bar.icons[2]:IsShown(), false)
		helpful.player = {}
		UF.PAB.RefreshAll()
		Equal(bar.count, 0)
		UF.PAB.bars = oldBars
	end)
	Test("the existing expanded bar stops showing Vigor and routine shields after reload", function()
		local oldBars = UF.PAB.bars
		UF.PAB.bars = {}
		local filter = { id = 5, name = "Defensives", preset = true, mopDefensivesRevision = 1,
			spells = { [105284] = true, [17] = true, [77535] = true, [48792] = true, [33206] = true } }
		local position = { x = 10, y = -30 }
		local barCfg = { id = 12, name = "Defensives", enabled = true, showAllBuffs = false,
			filters = { [5] = true }, maxTotal = 4, iconsPerRow = 4, maxRows = 1, iconSize = 40, pos = position }
		UF.db.playerAuraBars = {
			enabled = true, pabFilters = { nextId = 6, list = { filter } },
			defaultBuffs = { enabled = false }, defaultDebuffs = { enabled = false },
			customBuffBars = { barCfg }, customDebuffBars = {},
		}
		helpful.player = {
			Aura(105284, "raid2"), Aura(17, "raid3"), Aura(77535, "player"),
			Aura(48792, "player"), Aura(33206, "raid2"),
		}
		UF.PAB.ReloadAll()
		local bar
		for _, candidate in pairs(UF.PAB.bars) do if candidate.id == 12 then bar = candidate end end
		assert(bar and bar.shown)
		Equal(bar.count, 2)
		Equal(bar.icons[1].rec.spellId, 48792); Equal(bar.icons[1].rec.index, 4)
		Equal(bar.icons[2].rec.spellId, 33206); Equal(bar.icons[2].rec.index, 5)
		Equal(filter.spells[105284], nil); Equal(filter.mopDefensivesRevision, 2)
		Equal(barCfg.pos, position); Equal(barCfg.maxTotal, 4); Equal(barCfg.iconSize, 40)
		UF.PAB.bars = oldBars
	end)
	UF.db.playerAuraBars = original
	helpful.player = {}
end

local rfSettings = { debuffCap = 20, debuffShowDurText = true, debuffHideTooltips = false }
local rfProfile = { dmDebuff = { all = true }, hideLustDebuff = false }
local RF = { ERF = {}, LVL_AURA = 10, Profile = function() return rfProfile end, SettingsFor = function() return rfSettings end,
	Snap = function(v) return v end, NewText = NewText, SetIconFont = noop, CreateEdges = CreateEdges,
	LayoutEdges = LayoutEdges, BM_OwnsDefensives = function() return true end,
	OnApply = noop,
	POS_POINT = { bottomright = "BOTTOMRIGHT", bottomleft = "BOTTOMLEFT", top = "TOP", bottom = "BOTTOM" },
	NewTicker = function() return { Cancel = noop } end }
assert(loadfile([[EllesmereUIRaidFrames\EUI_RaidFrames_Auras.lua]]))("EllesmereUIRaidFrames", RF)
local function RaidButton()
	local btn = CreateFrame("Button")
	btn.unit = "raid2"
	btn.health = CreateFrame("StatusBar", nil, btn)
	return btn
end
Test("raid-frame debuffs and tooltips use the selected disease record", function()
	harmful.raid2 = ReportedAuras()
	local btn = RaidButton()
	RF.AuraUpdate(btn)
	Equal(Shown(btn.rfAura.base.icons), 17)
	local disease
	for _, icon in ipairs(btn.rfAura.base.icons) do if icon.spellId == 55095 then disease = icon end end
	assert(disease); Equal(disease.auraIndex, 4); Equal(disease.expires, 130)
	disease.scripts.OnEnter(disease)
	Equal(GameTooltip.aura[1], "raid2"); Equal(GameTooltip.aura[2], 4)
end)
Test("raid-frame pooled scans remain independent after shrinking and growing", function()
	local btn = RaidButton()
	for _ = 1, 3 do
		harmful.raid2 = ReportedAuras(); RF.AuraUpdate(btn)
		Equal(Shown(btn.rfAura.base.icons), 17)
		harmful.raid2 = { Aura(55078, "player") }; RF.AuraUpdate(btn)
		Equal(Shown(btn.rfAura.base.icons), 1)
		harmful.raid2 = {}; RF.AuraUpdate(btn)
		Equal(Shown(btn.rfAura.base.icons), 0)
	end
end)

local coTank = { enabled = true, debuffEnabled = true, debuffFilter = "all", debuffCap = 3 }
local Q = { DEFAULTS = { coTank = { width = 150, height = 20, x = 200, y = 0 } },
	DB = function() return coTank end, SpecRole = function() return "TANK" end,
	FontPath = function() return "font" end, SetFont = noop, After = function(_, fn) fn() end,
	RegisterRefresh = noop, RegisterReset = noop, OnSpecChanged = noop, OnUnlockModeChanged = noop, RegisterMover = noop }
ns.NaowhQoL = Q
assert(loadfile([[EllesmereUITopBar\EllesmereUITopBar_QoL_CoTank.lua]]))()
Test("Co-Tank caps are applied after consolidation, not before scanning the later copy", function()
	harmful.raid2 = ReportedAuras()
	Q.CoTank.Update()
	local bars = Upvalue(Q.CoTank.Update, "bars")
	local icons = bars[1].icons
	Equal(Shown(icons), 3); Equal(icons[2]._index, 4); Equal(icons[3]._index, 5)
	Equal(icons[2]._expires, 130)
end)
Test("Co-Tank refresh removes stale icons without modifying the underlying aura list", function()
	harmful.raid2 = { Aura(55095, "player"), Aura(55095, "player") }
	Q.CoTank.Update()
	local icons = Upvalue(Q.CoTank.Update, "bars")[1].icons
	Equal(Shown(icons), 1); Equal(#harmful.raid2, 2)
	harmful.raid2 = {}
	Q.CoTank.Update()
	Equal(Shown(icons), 0)
end)

print(string.format("%d passed, %d failed", passed, #failures))
if #failures > 0 then error(table.concat(failures, "\n"), 0) end
