-- Run with Lua 5.1 from the repository root. No game installation is accessed.
assert(_VERSION == "Lua 5.1", "These checks must run on Lua 5.1.")

local function Equal(actual, expected)
	assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local passed = 0
local function Test(name, fn)
	fn()
	passed = passed + 1
	print("PASS " .. name)
end
local noop = function() end
local now = 1000
local Frame = {}
Frame.__index = Frame
function CreateFrame(kind, name, parent)
	local f = setmetatable({
		kind = kind, parent = parent, children = {}, scripts = {}, events = {},
		shown = true, level = parent and parent.level + 1 or 0,
		width = 200, height = 100, scale = 1,
	}, Frame)
	if name then _G[name] = f end
	if parent then parent.children[#parent.children + 1] = f end
	return f
end
function Frame:GetChildren() return unpack(self.children) end
function Frame:GetParent() return self.parent end
function Frame:SetFrameStrata(strata) self.strata = strata end
function Frame:GetFrameStrata() return self.strata or (self.parent and self.parent:GetFrameStrata()) or "MEDIUM" end
function Frame:SetFrameLevel(level) self.level = level end
function Frame:GetFrameLevel() return self.level end
function Frame:CreateTexture() return CreateFrame("Texture", nil, self) end
function Frame:CreateFontString() return CreateFrame("FontString", nil, self) end
function Frame:SetScript(event, fn) self.scripts[event] = fn end
function Frame:RegisterEvent(event) self.events[event] = true end
function Frame:UnregisterEvent(event) self.events[event] = nil end
function Frame:SetPoint(...) self.point = { ... } end
function Frame:GetPoint() return unpack(self.point or {}) end
function Frame:GetNumPoints() return self.point and 1 or 0 end
function Frame:ClearAllPoints() self.point = nil end
function Frame:SetSize(w, h) self.width, self.height = w, h end
function Frame:GetSize() return self.width, self.height end
function Frame:SetWidth(w) self.width = w end
function Frame:SetHeight(h) self.height = h end
function Frame:GetWidth() return self.width end
function Frame:GetHeight() return self.height end
function Frame:SetScale(scale) self.scale = scale end
function Frame:GetEffectiveScale() return self.scale end
function Frame:GetCenter() return 960, 540 end
function Frame:GetBottom() return 540 - self.height / 2 end
function Frame:GetTop() return 540 + self.height / 2 end
function Frame:Show() self.shown = true end
function Frame:Hide() self.shown = false end
function Frame:SetShown(shown) self.shown = shown and true or false end
function Frame:IsShown() return self.shown end
function Frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function Frame:EnableMouse(enabled) self.mouse = enabled and true or false end
function Frame:SetFont(path, size, flags) self.font = { path, size, flags } end
function Frame:GetFont() return unpack(self.font or {}) end
function Frame:SetTexture(texture) self.texture = texture end
function Frame:GetTexture() return self.texture end
function Frame:SetText(text) self.text = text end
function Frame:GetText() return self.text end
function Frame:SetOwner(owner) self.owner = owner end
function Frame:IsOwned(owner) return self.owner == owner end
function Frame:SetSpellByID(id) self.spellID = id end
for _, method in ipairs({
	"SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetAllPoints", "SetAlpha",
	"SetJustifyH", "SetTextColor", "SetVertexColor", "SetDesaturated", "SetClampedToScreen",
	"SetMovable", "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "AddLine",
}) do Frame[method] = noop end

function GetTime() return now end
function GetLocale() return "enUS" end
function InCombatLockdown() return false end
function UnitExists(unit) return unit == "player" end
function UnitName(unit) if UnitExists(unit) then return "Tester", "Realm" end end
function UnitClass() return "Death Knight", "DEATHKNIGHT" end
function UnitGUID(unit) if UnitExists(unit) then return "PlayerGUID" end end
function UnitIsDeadOrGhost() return false end
function UnitIsConnected() return true end
function UnitGroupRolesAssigned() return "TANK" end
function GetNumGroupMembers() return 0 end
function IsInRaid() return false end
function GetSpecialization() return 1 end
function GetSpecializationInfo() return 250 end
function GetSpellInfo(id) return "Spell " .. id, nil, "Icon" .. id end
GetTalentInfo, GetGlyphSocketInfo, UnitCreatureFamily = noop, noop, noop
STANDARD_TEXT_FONT = "font"
NORMAL_FONT_COLOR = { r = 1, g = 1, b = 1 }
RAID_CLASS_COLORS = {}
function wipe(t) for k in pairs(t) do t[k] = nil end; return t end
table.wipe, format = wipe, string.format
bit = { band = function(a, b) return a == b and a or 0 end }
UIParent = CreateFrame("Frame")
UIParent:SetSize(1920, 1080)
GameTooltip = CreateFrame("GameTooltip", nil, UIParent)
GameTooltip:SetFrameStrata("TOOLTIP")
GameTooltip:Hide()
local unlockElement, unlockListener
EllesmereUI = {
	applyHooks = {}, Print = noop,
	ModuleDB = function(name) _G[name] = _G[name] or {}; return _G[name] end,
	MakeUnlockElement = function(def) return def end,
	RegisterUnlockElements = function(_, elements) unlockElement = elements[1] end,
	RegisterUnlockModeListener = function(_, _, fn) unlockListener = fn end,
}
local ns = EllesmereUI
assert(loadfile([[EllesmereUIInterruptTracker\EllesmereUIInterruptTracker.lua]]))("EllesmereUIInterruptTracker")
local tracker = AntrophyUtilitiesInterruptsFrame
tracker.scripts.OnEvent(tracker, "ADDON_LOADED", "EllesmereUIInterruptTracker")
tracker.scripts.OnEvent(tracker, "PLAYER_LOGIN")
local rows = {}
for _, child in ipairs(tracker.children) do
	if child.kind == "Button" and child.iconFrame then rows[#rows + 1] = child end
end
local function AssertLow(frame)
	Equal(frame:GetFrameStrata(), "LOW")
	for _, child in ipairs(frame.children) do AssertLow(child) end
end
local strataOrder = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN_DIALOG = 6, TOOLTIP = 7 }
local function Above(a, b)
	local sa, sb = strataOrder[a:GetFrameStrata()], strataOrder[b:GetFrameStrata()]
	if sa ~= sb then return sa > sb end
	return a:GetFrameLevel() > b:GetFrameLevel()
end
local function Update()
	now = now + 0.1
	tracker.scripts.OnUpdate(tracker, 0.1)
end

Test("the real tracker and every pooled row, icon, text and move box inherit LOW", function()
	Equal(#rows, 30)
	AssertLow(tracker)
end)
Test("normal game panels cover the tracker regardless of their frame levels", function()
	for _, name in ipairs({ "CharacterFrame", "AchievementFrame", "GuildFrame", "FriendsFrame", "QuestLogFrame" }) do
		local panel = CreateFrame("Frame", name, UIParent)
		panel:SetFrameStrata("MEDIUM")
		panel:SetFrameLevel(1)
		tracker:SetFrameLevel(200)
		for _, row in ipairs(rows) do
			assert(Above(panel, row)); assert(Above(panel, row.iconFrame))
		end
		assert(Above(panel, tracker))
		panel:SetFrameStrata("HIGH")
		assert(Above(panel, tracker))
	end
	tracker:SetFrameLevel(1)
end)
Test("test bars stay visible in the HUD without being hidden on panel open", function()
	ns.SetTestMode(true)
	Update()
	local shown = 0
	for _, row in ipairs(rows) do if row:IsVisible() then shown = shown + 1 end end
	assert(shown > 0)
	for _, panel in ipairs({ CharacterFrame, AchievementFrame, GuildFrame }) do
		panel:Hide(); panel:Show(); Update()
		assert(tracker:IsVisible()); assert(Above(panel, tracker))
	end
	AssertLow(tracker)
end)
Test("settings, resets and repeated show/hide do not raise the tracker again", function()
	ns.GetInterruptDB().width = 250
	ns.ApplyInterruptSettings()
	Equal(tracker:GetWidth(), 250)
	for _ = 1, 3 do tracker:Hide(); tracker:Show(); Update(); AssertLow(tracker) end
	ns.ResetInterruptSettings()
	AssertLow(tracker)
end)
Test("bar hover tooltips retain their normal tooltip layer", function()
	local row
	for _, candidate in ipairs(rows) do if candidate:IsVisible() then row = candidate; break end end
	assert(row and row.entrySpellID)
	row.scripts.OnEnter(row)
	assert(GameTooltip:IsShown()); Equal(GameTooltip.spellID, row.entrySpellID)
	Equal(GameTooltip:GetFrameStrata(), "TOOLTIP")
	row.scripts.OnLeave(row)
	Equal(GameTooltip:IsShown(), false)
end)
Test("Unlock Mode keeps its registered mover target and restores click-through behavior", function()
	Equal(unlockElement.key, "EUI_InterruptTracker"); Equal(unlockElement.getFrame(), tracker)
	ns.GetInterruptDB().clickThrough = true
	ns.ApplyInterruptSettings()
	for _, row in ipairs(rows) do Equal(row.mouse, false) end
	ns._unlockActive = true
	unlockListener(true)
	Equal(tracker.mouse, false); Equal(tracker.mover:IsShown(), false)
	AssertLow(tracker)
	unlockElement.setWidth(nil, 260)
	Equal(tracker:GetWidth(), 260)
	ns._unlockActive = false
	unlockListener(false)
	for _, row in ipairs(rows) do Equal(row.mouse, false) end
	ns.GetInterruptDB().clickThrough = false
	ns.ApplyInterruptSettings()
	for _, row in ipairs(rows) do Equal(row.mouse, true) end
	AssertLow(tracker)
end)
Test("disabling and re-enabling retains layering and the empty Unlock Mode target", function()
	ns.SetTestMode(false)
	Update()
	ns.SetInterruptsEnabled(false)
	Update()
	Equal(tracker:IsShown(), false)
	ns._unlockActive = true
	unlockListener(true)
	Equal(tracker:IsShown(), true)
	ns._unlockActive = false
	unlockListener(false)
	Equal(tracker:IsShown(), false)
	ns.SetInterruptsEnabled(true)
	Update()
	Equal(tracker:IsShown(), true)
	AssertLow(tracker)
end)

print(string.format("%d passed", passed))
