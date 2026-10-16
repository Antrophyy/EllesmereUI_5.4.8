-------------------------------------------------------------------------------
--  EUI_ActionBars_QuickKeybind.lua  (5.4.8 port)
--
--  Quick Keybind Mode (retail EUI_ActionBars_QuickKeybind.lua + Blizzard's
--  Quick Keybind frame, which 5.4.8 does not have): every bar that is not
--  set to Never comes up with its empty slots and a highlight on each button;
--  hover a button and press a key (with Shift / Ctrl / Alt), a mouse button
--  or the mouse wheel to bind it, right-click to unbind it. Okay saves the
--  bindings (account or Character Specific Keybindings), Cancel puts the
--  saved ones back. The settings window's key button and /kb open it.
-------------------------------------------------------------------------------
local addonName, P = ...
local EAB = P.EAB
local ns = P.ns

local ipairs, pairs = ipairs, pairs
local InCombatLockdown = InCombatLockdown

P.qkOpen = false

local MODIFIER_KEYS = {
	LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
	LMETA = true, RMETA = true, UNKNOWN = true,
}
local MOUSE_KEYS = { MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5" }

local dialog, binder

local function Accent()
	if ns.ResolveAccent then
		local r, g, b = ns.ResolveAccent()
		if r then return r, g, b end
	end
	return 0.05, 0.82, 0.62
end

local function ButtonLabel(btn)
	local info = btn.info
	return (info and info.label or "") .. " - Button " .. (btn.index or "?")
end

local function KeysText(cmd)
	local keys = { GetBindingKey(cmd) }
	if #keys == 0 then
		return "Not Bound"
	end
	for i, k in ipairs(keys) do
		keys[i] = GetBindingText and GetBindingText(k, "KEY_") or k
	end
	return table.concat(keys, ", ")
end

-------------------------------------------------------------------------------
--  Button highlights (retail QuickKeybindHighlightTexture in the EUI square
--  art and the Bar Interactions color)
-------------------------------------------------------------------------------
local function SetHighlight(btn, on, hover)
	local t = btn.qkHL
	if on and not t then
		t = btn.textHost:CreateTexture(nil, "OVERLAY", nil, 4)
		t:SetAllPoints(btn)
		t:SetTexture(P.HIGHLIGHT_TEXTURES[1])
		btn.qkHL = t
	end
	if not t then
		return
	end
	if on then
		local r, g, b = P.InteractionColor("highlight")
		t:SetVertexColor(r, g, b, 1)
		t:SetAlpha(hover and 1 or 0.5)
		t:Show()
	else
		t:Hide()
	end
end

local function RefreshHighlights()
	for btn in pairs(P.allButtons) do
		SetHighlight(btn, P.qkOpen, binder and binder.button == btn)
	end
end

-------------------------------------------------------------------------------
--  Binder: sits over the hovered button and takes the key / mouse
-------------------------------------------------------------------------------
local function ShowBinderTooltip()
	local btn = binder.button
	if not btn then
		return
	end
	GameTooltip:SetOwner(binder, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()
	GameTooltip:AddLine(ButtonLabel(btn), 1, 1, 1)
	GameTooltip:AddLine(KeysText(btn.bindCommand), 1, 0.82, 0)
	GameTooltip:Show()
end

local function Bind(key)
	local btn = binder.button
	if not btn or not btn.bindCommand or InCombatLockdown() then
		return
	end
	local combo = ""
	if IsAltKeyDown() then combo = combo .. "ALT-" end
	if IsControlKeyDown() then combo = combo .. "CTRL-" end
	if IsShiftKeyDown() then combo = combo .. "SHIFT-" end
	combo = combo .. key
	SetBinding(combo, btn.bindCommand)
	P.UpdateKeybinds()
	for b in pairs(P.allButtons) do
		P.UpdateHotkey(b)
	end
	ShowBinderTooltip()
end

local function Unbind()
	local btn = binder.button
	if not btn or not btn.bindCommand or InCombatLockdown() then
		return
	end
	local keys = { GetBindingKey(btn.bindCommand) }
	for _, k in ipairs(keys) do
		SetBinding(k)
	end
	P.UpdateKeybinds()
	P.UpdateHotkey(btn)
	ShowBinderTooltip()
end

local function CreateBinder()
	binder = CreateFrame("Button", "EABQuickKeybinder", UIParent)
	binder:SetFrameStrata("DIALOG")
	binder:EnableKeyboard(true)
	binder:EnableMouseWheel(true)
	binder:RegisterForClicks("AnyUp")
	binder:Hide()
	binder:SetScript("OnKeyDown", function(self, key)
		if MODIFIER_KEYS[key] then
			return
		end
		if key == "ESCAPE" then
			EAB:CloseQuickKeybind(true)
			return
		end
		Bind(key)
	end)
	binder:SetScript("OnClick", function(self, mouse)
		if mouse == "RightButton" then
			Unbind()
		elseif MOUSE_KEYS[mouse] then
			Bind(MOUSE_KEYS[mouse])
		end
	end)
	binder:SetScript("OnMouseWheel", function(self, delta)
		Bind(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
	end)
	binder:SetScript("OnLeave", function(self)
		local btn = self.button
		self.button = nil
		self:Hide()
		GameTooltip:Hide()
		if btn then SetHighlight(btn, P.qkOpen, false) end
	end)
end

local function OnButtonEnter(btn)
	if not P.qkOpen or not binder or not btn.bindCommand then
		return
	end
	if binder.button and binder.button ~= btn then
		SetHighlight(binder.button, true, false)
	end
	binder.button = btn
	binder:ClearAllPoints()
	binder:SetAllPoints(btn)
	binder:Show()
	SetHighlight(btn, true, true)
	ShowBinderTooltip()
end

local hooked = {}
local function HookButtons()
	for btn in pairs(P.allButtons) do
		if not hooked[btn] then
			hooked[btn] = true
			btn:HookScript("OnEnter", OnButtonEnter)
		end
	end
end

-------------------------------------------------------------------------------
--  Dialog (Blizzard's Quick Keybind frame, EllesmereUI look)
-------------------------------------------------------------------------------
local function FlatButton(parent, w, h, text, accent)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, h)
	local bg = b:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetTexture(0.077, 0.068, 0.058, 0.92)
	local edges = P.CreateEdges(b, b, "BORDER", 0)
	local label = b:CreateFontString(nil, "OVERLAY")
	P.SetModuleFont(label, 13)
	label:SetPoint("CENTER")
	label:SetText(text)
	local function Visual(hover)
		local r, g, bl = 1, 1, 1
		if accent then r, g, bl = Accent() end
		local a = hover and (accent and 1 or 0.7) or (accent and 0.7 or 0.5)
		P.LayoutEdges(edges, P.PixelFor(b), r, g, bl, hover and 0.6 or 0.4)
		label:SetTextColor(r, g, bl, a)
	end
	b:SetScript("OnEnter", function() Visual(true) end)
	b:SetScript("OnLeave", function() Visual(false) end)
	b.Visual = Visual
	Visual(false)
	return b
end

local function CreateDialog()
	dialog = CreateFrame("Frame", "EABQuickKeybindDialog", UIParent)
	dialog:SetSize(440, 168)
	dialog:SetPoint("TOP", UIParent, "TOP", 0, -140)
	dialog:SetFrameStrata("DIALOG")
	dialog:SetFrameLevel(50)
	dialog:EnableMouse(true)
	dialog:SetMovable(true)
	dialog:RegisterForDrag("LeftButton")
	dialog:SetScript("OnDragStart", dialog.StartMoving)
	dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
	dialog:SetClampedToScreen(true)
	local bg = dialog:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetTexture(0.077, 0.068, 0.058, 0.97)
	dialog.edges = P.CreateEdges(dialog, dialog, "BORDER", 0)
	dialog.line = dialog:CreateTexture(nil, "ARTWORK")
	dialog.line:SetPoint("TOPLEFT", 1, -1)
	dialog.line:SetPoint("TOPRIGHT", -1, -1)
	dialog.line:SetHeight(2)

	local title = dialog:CreateFontString(nil, "OVERLAY")
	P.SetModuleFont(title, 16)
	title:SetPoint("TOP", 0, -16)
	title:SetText(QUICK_KEYBIND_MODE or "Quick Keybind Mode")
	title:SetTextColor(1, 1, 1, 1)

	local desc = dialog:CreateFontString(nil, "OVERLAY")
	P.SetModuleFont(desc, 12)
	desc:SetPoint("TOP", title, "BOTTOM", 0, -10)
	desc:SetWidth(400)
	desc:SetJustifyH("CENTER")
	desc:SetTextColor(1, 1, 1, 0.6)
	desc:SetText("You are in Quick Keybind Mode. Mouse over a button and press the desired key to set the binding for that button. Right-click a button to clear its binding.")

	-- Character Specific Keybindings
	local check = CreateFrame("Button", nil, dialog)
	check:SetSize(18, 18)
	check:SetPoint("TOPLEFT", dialog, "TOPLEFT", 24, -104)
	local cbg = check:CreateTexture(nil, "BACKGROUND")
	cbg:SetAllPoints()
	cbg:SetTexture(0.03, 0.023, 0.018, 0.6)
	local cedges = P.CreateEdges(check, check, "BORDER", 0)
	P.LayoutEdges(cedges, P.PixelFor(check), 1, 1, 1, 0.25)
	local mark = check:CreateTexture(nil, "ARTWORK")
	mark:SetPoint("TOPLEFT", 4, -4)
	mark:SetPoint("BOTTOMRIGHT", -4, 4)
	local clabel = dialog:CreateFontString(nil, "OVERLAY")
	P.SetModuleFont(clabel, 12)
	clabel:SetPoint("LEFT", check, "RIGHT", 8, 0)
	clabel:SetTextColor(1, 1, 1, 0.75)
	clabel:SetText(CHARACTER_SPECIFIC_KEYBINDINGS or "Character Specific Keybindings")
	function dialog:RefreshCheck()
		local r, g, b = Accent()
		mark:SetTexture(r, g, b, 0.9)
		mark:SetShown(self.charSpecific and true or false)
	end
	check:SetScript("OnClick", function()
		dialog.charSpecific = not dialog.charSpecific
		dialog:RefreshCheck()
	end)

	local okay = FlatButton(dialog, 110, 28, OKAY or "Okay", true)
	okay:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -16, 14)
	okay:SetScript("OnClick", function() EAB:CloseQuickKeybind(true) end)
	local cancel = FlatButton(dialog, 110, 28, CANCEL or "Cancel")
	cancel:SetPoint("RIGHT", okay, "LEFT", -10, 0)
	cancel:SetScript("OnClick", function() EAB:CloseQuickKeybind(false) end)
	dialog.okay = okay

	dialog:SetScript("OnHide", function()
		if P.qkOpen then
			EAB:CloseQuickKeybind(true)
		end
	end)
	tinsert(UISpecialFrames, "EABQuickKeybindDialog")
	dialog:Hide()
end

-------------------------------------------------------------------------------
--  Open / close
-------------------------------------------------------------------------------
local function Surface()
	P.ApplyAllVisibility()
	for btn in pairs(P.actionButtons) do
		P.UpdateGridAlpha(btn)
	end
	P.UpdatePetButtons()
	EAB:RefreshMouseover()
	RefreshHighlights()
end

function EAB:IsQuickKeybindOpen()
	return P.qkOpen
end

function EAB:OpenQuickKeybind()
	if P.qkOpen or not P.started then
		return
	end
	if InCombatLockdown() then
		ns.Print("Quick Keybind Mode is not available in combat.")
		return
	end
	if not dialog then
		CreateDialog()
		CreateBinder()
	end
	HookButtons()
	P.qkOpen = true
	dialog.charSpecific = (GetCurrentBindingSet and GetCurrentBindingSet() == 2) and true or false
	dialog:RefreshCheck()
	local r, g, b = Accent()
	P.LayoutEdges(dialog.edges, P.PixelFor(dialog), 1, 1, 1, 0.15)
	dialog.line:SetTexture(r, g, b, 0.7)
	dialog.okay.Visual(false)
	dialog:Show()
	Surface()
end

-- save = true: keep the new bindings (Okay); false: back to the saved ones.
function EAB:CloseQuickKeybind(save)
	if not P.qkOpen then
		return
	end
	P.qkOpen = false
	if binder then
		binder.button = nil
		binder:Hide()
	end
	GameTooltip:Hide()
	if save then
		SaveBindings(dialog.charSpecific and 2 or 1)
	else
		LoadBindings(GetCurrentBindingSet())
	end
	if dialog:IsShown() then
		dialog:Hide()
	end
	Surface()
	P.UpdateKeybinds()
	for btn in pairs(P.allButtons) do
		P.UpdateHotkey(btn)
	end
end

function EAB:ToggleQuickKeybind()
	if P.qkOpen then
		self:CloseQuickKeybind(true)
	else
		self:OpenQuickKeybind()
	end
end

-- Combat ends the mode (bindings cannot change in combat).
do
	local f = CreateFrame("Frame")
	f:RegisterEvent("PLAYER_REGEN_DISABLED")
	f:SetScript("OnEvent", function()
		if P.qkOpen then
			EAB:CloseQuickKeybind(true)
		end
	end)
end

SLASH_EABQUICKKEYBIND1 = "/kb"
SlashCmdList.EABQUICKKEYBIND = function()
	EAB:ToggleQuickKeybind()
end
