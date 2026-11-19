-- Lua 5.1, from the repository root. Runs the addon's drivers and click snippets;
-- no game installation, saved bindings, or live actions are accessed.
assert(_VERSION == "Lua 5.1")
local function eq(got, want) assert(got == want, ("expected %s, got %s"):format(tostring(want), tostring(got))) end
local function up(fn, key)
	for i = 1, 60 do
		local name, v = debug.getupvalue(fn, i)
		if name == key then return v end
	end
	error("missing upvalue " .. key)
end
local noop = function() end
local combat, secure, battle, keyDown, flags, pages, saved, owners
function InCombatLockdown() return combat end
function GetBindingKey(cmd) return unpack(saved[cmd] or {}) end
function ClearOverrideBindings(owner) assert(not combat); owner.keys = {} end
function SetOverrideBindingClick(owner, _, key, name, button)
	assert(not combat)
	owner.keys[key] = "CLICK " .. name .. ":" .. (button or "LeftButton")
end
local function binding(key)
	for _, owner in ipairs(owners) do if owner.keys[key] then return owner.keys[key] end end
	for cmd, keys in pairs(saved) do for _, k in ipairs(keys) do if k == key then return cmd end end end
end
local function run(frame, snippet, args)
	if not snippet then return end
	local scope = args or {}
	scope.self, scope.control, scope.tonumber = frame, frame, tonumber
	scope.HasVehicleActionBar = function() return flags.hasVehicle end
	scope.HasOverrideActionBar = function() return flags.hasOverride end
	scope.HasTempShapeshiftActionBar = function() return flags.shapeshift end
	scope.GetVehicleBarIndex = function() return pages.vehicle end
	scope.GetOverrideBarIndex = function() return pages.override end
	scope.GetTempShapeshiftBarIndex = function() return pages.temp end
	scope.GetBonusBarOffset = function() return pages.bonus end
	scope.GetActionBarPage = function() return pages.normal end
	local previous = secure
	secure = true
	local result = setfenv(assert(loadstring(snippet)), scope)()
	secure = previous
	return result
end

local Frame = {}
Frame.__index = Frame
local lastFrame
function CreateFrame(_, name, parent, template)
	assert(not combat)
	local f = setmetatable({name = name, parent = parent, template = template, shown = true, attrs = {},
		children = {}, scripts = {}, wraps = {}, keys = {}}, Frame)
	if parent then parent.children[#parent.children + 1] = f end
	if name then _G[name] = f end
	lastFrame = f
	owners[#owners + 1] = f
	return f
end
function Frame:GetName() return self.name end
function Frame:GetFrameLevel() return 1 end
function Frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function Frame:SetShown(on)
	if self.shown == on then return end
	self.shown = on
	for _, child in ipairs(self.children) do
		if child.template == "SecureHandlerShowHideTemplate" and child.shown then
			run(child, child.attrs[on and "_onshow" or "_onhide"])
		end
	end
end
function Frame:Hide() self:SetShown(false) end
function Frame:SetParent(parent) self.parent = parent end
function Frame:SetAttribute(key, value)
	assert(not combat or secure)
	self.attrs[key] = value
	if self.scripts.OnAttributeChanged then self.scripts.OnAttributeChanged(self, key, value) end
end
function Frame:GetAttribute(key) return self.attrs[key] end
function Frame:SetScript(key, fn) self.scripts[key] = fn end
function Frame:WrapScript(btn, key, code) btn.wraps[key] = code end
function Frame:Execute(code) assert(not combat); run(self, code) end
function Frame:ClearBindings() assert(secure); self.keys = {} end
function Frame:SetBindingClick(_, key, name, button)
	assert(secure); self.keys[key] = "CLICK " .. name .. ":" .. button
end
function Frame:ChildUpdate(id, message)
	for _, child in ipairs(self.children) do
		run(child, child.attrs["_childupdate-" .. id], {message = message})
	end
end
function RegisterStateDriver(f, state, cond) f[state .. "Driver"] = cond end
for _, key in ipairs({"SetFrameStrata", "SetFrameLevel", "SetSize", "Show", "EnableMouse", "SetAlpha", "SetChecked", "HookScript",
	"RegisterForDrag", "RegisterForClicks", "RegisterEvent", "UnregisterEvent", "UnregisterAllEvents", "SetAllPoints"}) do Frame[key] = noop end
function Frame:CreateTexture() return { Hide = noop } end
GetActionInfo, GetActionTexture, HasAction, IsCurrentAction, IsAutoRepeatAction, hooksecurefunc = noop, noop, noop, noop, noop, noop
function GetCVarBool() return keyDown end
function GetCVar() return "0" end
function UnitClass() return "Mage", "MAGE" end
GameTooltip = { GetOwner = noop }
C_PetBattles = { IsInBattle = function() return battle end }

local function setup(hideNative, missingNative)
	combat, secure, battle, keyDown, flags, owners = false, false, false, true, {}, {}
	pages = { vehicle = 13, override = 12, temp = 14, normal = 1, bonus = 0 }
	saved = { ACTIONBUTTON1 = {"1", "NUMPAD1"}, ACTIONBUTTON6 = {"CTRL-6"}, MULTIACTIONBAR1BUTTON1 = {"F"} }
	UIParent = CreateFrame("Frame")
	OverrideActionBar = CreateFrame("Frame", nil, UIParent)
	OverrideActionBar:Hide()
	if missingNative then OverrideActionBar = nil end
	ActionBarController, MainMenuBar = CreateFrame("Frame"), CreateFrame("Frame")
	EllesmereUI, EllesmereUIActionBarsDB = {}, nil
	local P = {}
	for _, name in ipairs({"EllesmereUIActionBars", "EUI_ActionBars_Buttons", "EUI_ActionBars_Bars"}) do
		assert(loadfile("EllesmereUIActionBars\\" .. name .. ".lua"))("EllesmereUIActionBars", P)
	end
	local createBar = up(up(lastFrame.scripts.OnEvent, "Start"), "CreateBar")
	P.EAB:InitDB()
	P.Profile().hideBlizzardVehicleBar = hideNative
	P.BarSettings("MainBar").paging = { alt = 4 }
	P.CreateEdges, P.ShowEdges, P.SetCooldownState, P.UpdateEquippedBorder, P.HideProcGlow, P.UpdateHotkeyColor =
		noop, noop, noop, noop, noop, noop
	P.StyleButton = function(btn) btn.icon = { Hide = noop } end
	createBar(P.BAR_LOOKUP.MainBar)
	createBar(P.BAR_LOOKUP.Bar2)
	P.HideBlizzardBars()
	P.ApplyPaging("MainBar")
	P.UpdateKeybinds()
	return P
end

-- Only the macro terms exercised below; run the actual registered page and
-- child-update snippets (not a reimplementation of their slot calculation).
local function page(P)
	local header = P.barFrames.MainBar
	for term in header.pageDriver:gmatch("[^;]+") do
		local matches = not term:find("[", 1, true)
		for condition in term:gmatch("%[([^%]]+)%]") do matches = matches or flags[condition] end
		if matches then
			run(header, header.attrs["_onstate-page"], {newstate = term:match("(%w+)$")})
			return
		end
	end
	error("no matching page")
end
local mainClick = "CLICK EABButton1:Keybind"
local function clickAction(btn, button, down)
	if run(btn, btn.wraps.OnClick, {button = button, down = down}) ~= false then return btn:GetAttribute("action") end
end
local function keyAction(key, down)
	local name, button = assert(binding(key)):match("^CLICK ([^:]+):(.+)$")
	return clickAction(assert(_G[name]), button, down)
end
local P = setup(false)
eq(binding("1"), mainClick)
combat = true
OverrideActionBar:SetShown(true)
eq(binding("1"), "ACTIONBUTTON1"); eq(binding("NUMPAD1"), "ACTIONBUTTON1")
eq(binding("CTRL-6"), "ACTIONBUTTON6"); eq(binding("F"), "CLICK EABButton61:Keybind")
OverrideActionBar:Hide()
eq(binding("1"), mainClick); eq(binding("NUMPAD1"), mainClick)
print("PASS: native vehicle bar gets the configured primary, secondary and modified keys in combat; exit restores EUI")

combat = false
OverrideActionBar:SetShown(true)
saved.ACTIONBUTTON1 = {"R"}
P.UpdateKeybinds()
eq(binding("R"), "ACTIONBUTTON1")
battle = true; P.UpdateKeybinds()
OverrideActionBar:Hide()
eq(binding("R"), "ACTIONBUTTON1"); eq(binding("F"), "MULTIACTIONBAR1BUTTON1")
battle = false; P.UpdateKeybinds()
eq(binding("R"), mainClick); eq(binding("1"), nil); eq(binding("NUMPAD1"), nil)
P.BarSettings("MainBar").enabled = false; P.UpdateKeybinds()
OverrideActionBar:SetShown(true); OverrideActionBar:Hide()
eq(binding("R"), "ACTIONBUTTON1")
print("PASS: rebinding while seated, pet battles and disabled main bars do not restore obsolete EUI overrides")

for _, config in ipairs({{false}, {true}, {false, true}}) do
	P = setup(unpack(config))
	combat = true
	-- Unskinned vehicle / hidden native bar, with a modifier and manual page active.
	flags = { vehicleui = true, hasVehicle = true, overridebar = true, hasOverride = true, ["mod:alt"] = true, ["bar:2"] = true }
	page(P)
	eq(binding("1"), mainClick); eq(EABButton1.action, 145); eq(EABButton6:GetAttribute("action"), 150)
	for _, onDown in ipairs({true, false}) do
		combat = false; keyDown = onDown; P.ApplyClickSettings(); combat = true
		eq(clickAction(EABButton1, "LeftButton", true), nil)
		local mouseSlot = clickAction(EABButton1, "LeftButton", false)
		eq(mouseSlot, 145); eq(keyAction("1", onDown), mouseSlot); eq(keyAction("1", not onDown), nil)
		eq(keyAction("CTRL-6", onDown), clickAction(EABButton6, "LeftButton", false))
	end
	flags.vehicleui, flags.hasVehicle = false, false; page(P); eq(EABButton1.action, 133)
	flags = {shapeshift = true}; page(P); eq(EABButton1.action, 157)
	flags = {possessbar = true, hasVehicle = true}; page(P); eq(EABButton1.action, 145)
	pages.bonus, flags = 5, {["bonusbar:5"] = true, ["mod:alt"] = true}; page(P); eq(EABButton1.action, 121)
	pages.bonus, pages.normal, flags = 0, 2, {vehicleui = true}; page(P); eq(EABButton1.action, 13)
	flags = {["mod:alt"] = true}; page(P); eq(EABButton1.action, 37)
	flags = {["bar:2"] = true}; page(P); eq(EABButton1.action, 13)
	flags = {}; page(P); eq(EABButton1.action, 1); eq(EABButton1:GetAttribute("action"), 1)
end
print("PASS: EUI-only vehicle, override, temporary and possess pages take priority and return to normal paging")
