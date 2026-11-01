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
local function Upvalue(fn, wanted)
	for i = 1, 60 do
		local name, value = debug.getupvalue(fn, i)
		if name == wanted then return value end
		if not name then break end
	end
	error("Missing upvalue: " .. wanted)
end
local noop = function() end
local frames, now, levelWrites = {}, 100, 0
local Frame = {}
Frame.__index = Frame
local function Object(kind, name, parent)
	local f = setmetatable({
		kind = kind, name = name, parent = parent, children = {}, regions = {}, scripts = {}, events = {},
		shown = true, alpha = 1, level = parent and math.min(parent.level + 1, 128) or 0,
		width = 190, height = 400, enabled = true,
	}, Frame)
	if name then _G[name] = f end
	return f
end
function CreateFrame(kind, name, parent)
	local f = Object(kind, name, parent)
	if parent then parent.children[#parent.children + 1] = f end
	frames[#frames + 1] = f
	return f
end
function Frame:GetName() return self.name end
function Frame:GetParent() return self.parent end
function Frame:GetObjectType() return self.kind end
function Frame:IsObjectType(kind) return self.kind == kind end
function Frame:IsForbidden() return self.forbidden or false end
function Frame:GetChildren() return unpack(self.children) end
function Frame:GetRegions() return unpack(self.regions) end
function Frame:SetParent(parent)
	if self.parent then
		for i, child in ipairs(self.parent.children) do
			if child == self then table.remove(self.parent.children, i); break end
		end
	end
	self.parent = parent
	if parent then parent.children[#parent.children + 1] = self end
end
function Frame:SetFrameLevel(level)
	levelWrites = levelWrites + 1
	local delta = level - self.level
	self.level = level
	local function Propagate(frame)
		for _, child in ipairs(frame.children) do
			child.level = math.max(0, math.min(128, child.level + delta))
			Propagate(child)
		end
	end
	Propagate(self)
end
function Frame:GetFrameLevel() return self.level end
function Frame:SetFrameStrata(strata) self.strata = strata end
function Frame:GetFrameStrata() return self.strata or (self.parent and self.parent:GetFrameStrata()) or "MEDIUM" end
function Frame:SetScript(event, fn) self.scripts[event] = fn end
function Frame:GetScript(event) return self.scripts[event] end
function Frame:HookScript(event, fn)
	local old = self.scripts[event]
	self.scripts[event] = function(...)
		if old then old(...) end
		fn(...)
	end
end
function Frame:RegisterEvent(event) self.events[event] = true end
function Frame:UnregisterEvent(event) self.events[event] = nil end
function Frame:UnregisterAllEvents() self.events = {} end
function Frame:IsShown() return self.shown end
function Frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
local function Visibility(frame, shown)
	if frame.shown == shown then return end
	frame.shown = shown
	local fn = frame.scripts[shown and "OnShow" or "OnHide"]
	if fn then fn(frame) end
end
function Frame:Show() Visibility(self, true) end
function Frame:Hide() Visibility(self, false) end
function Frame:SetShown(shown) Visibility(self, shown and true or false) end
function Frame:SetAlpha(alpha) self.alpha = alpha end
function Frame:GetAlpha() return self.alpha end
function Frame:SetSize(w, h) self.width, self.height = w, h end
function Frame:SetWidth(w) self.width = w end
function Frame:SetHeight(h) self.height = h end
function Frame:GetWidth() return self.width end
function Frame:GetHeight() return self.height end
function Frame:GetTop() return 600 end
function Frame:GetRight() return 800 end
function Frame:GetScale() return 1 end
function Frame:GetEffectiveScale() return 1 end
function Frame:SetPoint(...) self.point = { ... } end
function Frame:ClearAllPoints() self.point = nil end
function Frame:SetAllPoints(anchor) self.anchor = anchor or self.parent end
function Frame:SetText(text)
	local changed = self.text ~= text
	self.text = text
	if changed and self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
end
function Frame:GetText() return self.text end
function Frame:SetFont(path, size, flags) self.font, self.fontSize, self.flags = path, size, flags end
function Frame:GetFont() return self.font or "font", self.fontSize or 11, self.flags or "" end
function Frame:GetStringWidth() return #(self.text or "") * 6 end
function Frame:GetTextColor() return 1, 1, 1 end
function Frame:SetTexture(...) self.texture = { ... } end
function Frame:GetTexture() return self.texture and self.texture[1] end
function Frame:IsEnabled() return self.enabled end
function Frame:Enable() self.enabled = true end
function Frame:Disable() self.enabled = false end
function Frame:SetEnabled(enabled) self.enabled = enabled end
function Frame:SetID(id) self.id = id end
function Frame:GetID() return self.id end
function Frame:SetScrollChild(child) self.scrollChild = child end
function Frame:SetVerticalScroll(value) self.scroll = value end
function Frame:GetVerticalScroll() return self.scroll or 0 end
function Frame:SetOwner(owner) self.owner = owner end
function Frame:SetHyperlink(link) self.link = link end
function Frame:IsOwned(owner) return self.owner == owner end
function Frame:CreateTexture(name)
	local t = Object("Texture", name, self)
	self.regions[#self.regions + 1] = t
	return t
end
function Frame:CreateFontString(name)
	local t = Object("FontString", name, self)
	self.regions[#self.regions + 1] = t
	return t
end
for _, method in ipairs({
	"SetDrawLayer", "SetVertexColor", "SetBlendMode", "SetTexCoord", "SetTextColor", "SetJustifyH",
	"SetWordWrap", "SetTextInsets", "SetAutoFocus", "SetMaxLetters", "ClearFocus", "EnableMouse",
	"EnableMouseWheel", "RegisterForClicks", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor",
	"AddLine", "SetPropagateKeyboardInput", "EnableKeyboard", "SetClampedToScreen",
}) do Frame[method] = noop end

function GetTime() return now end
function InCombatLockdown() return false end
function IsLoggedIn() return false end
function geterrorhandler() return error end
function wipe(t) for key in pairs(t) do t[key] = nil end; return t end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function strsplit(separator, text)
	local out = {}
	for value in (text .. separator):gmatch("(.-)" .. separator) do out[#out + 1] = value end
	return unpack(out)
end
function hooksecurefunc(target, method, hook)
	if type(target) == "string" then target, method, hook = _G, target, method end
	local original = assert(target[method], "Missing native function: " .. method)
	target[method] = function(...)
		local result = { original(...) }
		hook(...)
		return unpack(result)
	end
end
format, tinsert, StaticPopupDialogs = string.format, table.insert, {}
PlaySound, EquipmentFlyout_DisplayButton, EquipmentFlyoutPopoutButton_ShowAll = noop, noop, noop
PLAYER_TITLE_NONE = "No Title"
UIParent = CreateFrame("Frame")
CharacterFrame = CreateFrame("Frame", "CharacterFrame", UIParent)
CharacterFrame:SetFrameLevel(122)
PaperDollFrame = CreateFrame("Frame", "PaperDollFrame", CharacterFrame)
PaperDollFrame:SetFrameLevel(129)
CharacterStatsPane = CreateFrame("Frame", "CharacterStatsPane", PaperDollFrame)
PaperDollTitlesPane = CreateFrame("ScrollFrame", "PaperDollTitlesPane", PaperDollFrame)
PaperDollEquipmentManagerPane = CreateFrame("ScrollFrame", "PaperDollEquipmentManagerPane", PaperDollFrame)
PAPERDOLL_SIDEBARS = {
	{ frame = "CharacterStatsPane" }, { frame = "PaperDollTitlesPane" }, { frame = "PaperDollEquipmentManagerPane" },
}
for i = 1, 3 do
	local tab = CreateFrame("Button", "PaperDollSidebarTab" .. i, PaperDollFrame)
	tab:SetID(i)
end
PaperDollTitlesPane:Hide()
PaperDollEquipmentManagerPane:Hide()
GameTooltip = CreateFrame("GameTooltip", nil, UIParent)
function PaperDollFrame_UpdateSidebarTabs() end
function PaperDollEquipmentManagerPane_Update() end
local sets = { "Tank", "PvP", "Damage" }
function GetEquipmentSetInfoByName(name)
	for i, set in ipairs(sets) do if set == name then return set, i, i == 1, nil, nil, nil, nil, 0 end end
end
local titles, currentTitle = { "the Defender", "the Explorer" }, -1
function GetNumTitles() return #titles end
function IsTitleKnown(id) return titles[id] and 1 or 0 end
function GetTitleName(id) return titles[id] end
function GetCurrentTitle() return currentTitle end
function SetCurrentTitle(id) currentTitle = id end

EllesmereUI = {
	FONT = "font", applyHooks = {},
	PhysicalHeight = function() return 1080 end,
	GetFontPath = function() return "font" end,
	ApplyModuleFont = function(text, size) text:SetFont("font", size, "") end,
	ModuleDB = function(name, _, key)
		_G[name] = _G[name] or {}
		if key then _G[name][key] = _G[name][key] or {}; return _G[name][key] end
		return _G[name]
	end,
}
local ns = EllesmereUI
local function Load(name) return assert(loadfile([[EllesmereUIBlizzardSkin\]] .. name))("EllesmereUIBlizzardSkin") end
Load("EllesmereUIBlizzardSkin.lua")
local BS = ns.BlizzSkin
local function Tick(seconds)
	now = now + (seconds or 0.1)
	for _, frame in ipairs(frames) do
		if frame:IsVisible() and frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, seconds or 0.1) end
	end
end
local function AboveParents(frame)
	for _, child in ipairs({ frame:GetChildren() }) do
		if not child:IsForbidden() then
			assert(child:GetFrameLevel() > frame:GetFrameLevel(), (child:GetName() or child.kind) .. " is behind its parent")
			AboveParents(child)
		end
	end
end

Test("reproduces the client limit and repairs high-level descendants explicitly", function()
	local root = CreateFrame("Frame", nil, UIParent)
	root:SetFrameLevel(138)
	local child = CreateFrame("Frame", nil, root)
	local button = CreateFrame("Button", nil, child)
	Equal(child:GetFrameLevel(), 128); Equal(button:GetFrameLevel(), 128)
	BS.EnsureChildFrameLevels(root)
	Equal(root:GetFrameLevel(), 138); Equal(child:GetFrameLevel(), 139); Equal(button:GetFrameLevel(), 140)
end)
Test("preserves intentional higher levels and does not raise the whole window", function()
	local root = CreateFrame("Frame", nil, UIParent)
	root:SetFrameLevel(20)
	local low, high = CreateFrame("Frame", nil, root), CreateFrame("Frame", nil, root)
	high:SetFrameLevel(30)
	BS.EnsureChildFrameLevels(root)
	Equal(low:GetFrameLevel(), 21); Equal(high:GetFrameLevel(), 30); Equal(root:GetFrameLevel(), 20)
	local before = levelWrites
	BS.EnsureChildFrameLevels(root)
	Equal(levelWrites, before)
end)
Test("watching preserves native scripts and repairs only when the level changes", function()
	local root = CreateFrame("Frame", nil, UIParent)
	local button = CreateFrame("Button", nil, root)
	local updates, shown = 0, 0
	local click = noop
	root:SetScript("OnUpdate", function() updates = updates + 1 end)
	root:SetScript("OnShow", function() shown = shown + 1 end)
	button:SetScript("OnClick", click)
	BS.WatchChildFrameLevels(root)
	BS.WatchChildFrameLevels(root)
	local before = levelWrites
	Tick()
	Equal(updates, 1); Equal(levelWrites, before)
	root:SetFrameLevel(160)
	Equal(button:GetFrameLevel(), 128)
	Tick()
	AboveParents(root); Equal(root:GetFrameLevel(), 160); Equal(button:GetScript("OnClick"), click)
	root:Hide(); Tick(); Equal(updates, 2)
	root:Show(); Equal(shown, 1)
end)
Test("forbidden subtrees are not modified", function()
	local root = CreateFrame("Frame", nil, UIParent)
	root:SetFrameLevel(150)
	local blocked = CreateFrame("Frame", nil, root)
	blocked.forbidden = true
	BS.EnsureChildFrameLevels(root)
	Equal(blocked:GetFrameLevel(), 128)
end)

local beforeLoad = #frames
Load("EllesmereUIBlizzardSkin_CharacterSheet.lua")
local init
for i = beforeLoad + 1, #frames do
	if frames[i].events.PLAYER_LOGIN then init = frames[i] end
end
assert(init, "character sheet initializer not found")
init.scripts.OnEvent(init, "ADDON_LOADED", "EllesmereUIBlizzardSkin")
init.scripts.OnEvent(init, "PLAYER_LOGIN")
local BuildSheet = Upvalue(init.scripts.OnEvent, "BuildSheet")
local BuildSidebar = Upvalue(BuildSheet, "BuildSidebar")
local S = Upvalue(BuildSidebar, "S")
S.statsPanel = CreateFrame("Frame", "TestStatsPanel", PaperDollFrame)
S.statsPanel:SetFrameLevel(137)
local pane = PaperDollEquipmentManagerPane
local scrollChild = CreateFrame("Frame", nil, pane)
pane.buttons = {}
local function EquipmentRow(name)
	local row = CreateFrame("Button", nil, scrollChild)
	row.name = name
	row.text = row:CreateFontString()
	row.icon = row:CreateTexture()
	row:SetScript("OnClick", function(self) pane.selectedSetName = self.name end)
	pane.buttons[#pane.buttons + 1] = row
	return row
end
for _, name in ipairs(sets) do EquipmentRow(name) end
BuildSidebar()
local function SelectSidebar(index)
	for i, def in ipairs(PAPERDOLL_SIDEBARS) do _G[def.frame]:SetShown(i == index) end
	PaperDollFrame_UpdateSidebarTabs()
end

Test("actual equipment pane repair makes every row higher than its parent", function()
	SelectSidebar(3)
	Equal(pane:GetFrameLevel(), 138)
	AboveParents(pane)
	for _, row in ipairs(pane.buttons) do
		row.scripts.OnClick(row)
		Equal(pane.selectedSetName, row.name)
	end
end)
Test("new equipment rows created after a bag/loot update are repaired without changing click handlers", function()
	local row = EquipmentRow("New Set")
	Equal(row:GetFrameLevel(), 128)
	local original = row.scripts.OnClick
	PaperDollEquipmentManagerPane_Update()
	AboveParents(pane); Equal(row.scripts.OnClick, original)
	row.scripts.OnClick(row); Equal(pane.selectedSetName, "New Set")
end)
Test("actual Titles panel shows its search, scroll child, and selectable titles above level 137", function()
	SelectSidebar(2)
	local panel = EUI_CharSheetTitles
	Equal(panel:GetFrameLevel(), 137); Equal(panel:IsShown(), true)
	AboveParents(panel)
	local scroll = EUI_CharSheetTitlesScroll
	local count = 0
	for _, row in ipairs({ scroll.scrollChild:GetChildren() }) do
		if row:IsShown() then
			count = count + 1
			if row.titleId == 2 then row.scripts.OnClick(row) end
		end
	end
	Equal(count, 3); Equal(currentTitle, 2)
end)
Test("title search and newly learned titles remain visible and interactive", function()
	local search, scroll = EUI_CharSheetTitlesSearch, EUI_CharSheetTitlesScroll
	search:SetText("Defender")
	local visible = 0
	for _, row in ipairs({ scroll.scrollChild:GetChildren() }) do if row:IsShown() then visible = visible + 1 end end
	Equal(visible, 2)
	titles[3] = "the Newcomer"
	for _, frame in ipairs(frames) do
		if frame.events.KNOWN_TITLES_UPDATE then frame.scripts.OnEvent(frame, "KNOWN_TITLES_UPDATE") end
	end
	search:SetText("")
	AboveParents(EUI_CharSheetTitles)
	local found
	for _, row in ipairs({ scroll.scrollChild:GetChildren() }) do
		if row:IsShown() and row.titleId == 3 then found = row end
	end
	assert(found); found.scripts.OnClick(found); Equal(currentTitle, 3)
end)
Test("repeated window raises and tab switches do not leave controls behind or ratchet levels", function()
	for level = 150, 170, 5 do
		EUI_CharSheetTitles:SetFrameLevel(level)
		pane:SetFrameLevel(level + 1)
		SelectSidebar(3); Tick(); AboveParents(pane)
		SelectSidebar(2); Tick(); AboveParents(EUI_CharSheetTitles)
		local writes = levelWrites
		Tick(); Tick()
		Equal(levelWrites, writes)
	end
end)

ns.WSkin = { RegisterWindow = noop }
local equipped = "item:100:0:101:102:0:0:0:0"
function GetInventoryItemLink(_, slot) if slot == 1 then return equipped end end
function GetItemStats(link)
	if link == equipped then return { EMPTY_SOCKET_RED = 2 } end
	return {}
end
function GetItemGem(_, index) return "Gem", "item:" .. (100 + index) end
function GetItemIcon(id) return "Interface\\Icons\\Gem" .. id end
function GetItemInfo(link) return "Gem", link, 3, nil, nil, "Gem", nil, nil, nil, "Interface\\Icons\\Gem" end
CharacterHeadSlot = CreateFrame("Button", "CharacterHeadSlot", PaperDollFrame)
Load("EllesmereUIBlizzardSkin_SocketPanel.lua")
for _, fn in ipairs(Upvalue(BS.OnLogin, "loginCallbacks")) do fn() end
PaperDollFrame:Hide()
PaperDollFrame:Show()
local socketPanel = EUI_CharSheet_SocketPanel
local function GemButtons()
	local out = {}
	for _, child in ipairs({ socketPanel:GetChildren() }) do if child.icon and child:IsShown() then out[#out + 1] = child end end
	return out
end
Test("actual socket panel paints gem icons and borders above the level-142 panel", function()
	Equal(socketPanel:GetFrameLevel(), 142); Equal(socketPanel:IsShown(), true)
	local gems = GemButtons()
	Equal(#gems, 2)
	AboveParents(socketPanel)
	for _, gem in ipairs(gems) do
		Equal(gem.icon:GetAlpha(), 1)
		assert(gem.icon:GetTexture():find("Interface\\Icons\\Gem", 1, true))
		assert(BS.PP.GetBorder(gem):GetFrameLevel() > gem:GetFrameLevel())
	end
end)
Test("gem tooltips respond after the panel is raised again", function()
	socketPanel:SetFrameLevel(180)
	Tick()
	AboveParents(socketPanel)
	local gem = GemButtons()[1]
	gem.scripts.OnEnter(gem)
	Equal(GameTooltip.owner, gem); Equal(GameTooltip.link, "item:101")
	gem.scripts.OnLeave(gem)
end)
Test("socket rebuilds on item-info and inventory events keep the layer invariant", function()
	for _, event in ipairs({ "GET_ITEM_INFO_RECEIVED", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED" }) do
		for _, frame in ipairs(frames) do
			if frame.events[event] then frame.scripts.OnEvent(frame, event, 1) end
		end
		Tick(0.2)
		AboveParents(socketPanel); Equal(#GemButtons(), 2)
	end
end)

print(string.format("%d passed, %d failed", passed, #failures))
if #failures > 0 then error(table.concat(failures, "\n"), 0) end
