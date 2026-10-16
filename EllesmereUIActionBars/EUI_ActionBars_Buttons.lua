-------------------------------------------------------------------------------
--  EUI_ActionBars_Buttons.lua  (5.4.8 port)
--
--  The buttons. Action buttons are our own secure buttons
--  (SecureActionButtonTemplate + ActionButtonTemplate, the LibActionButton
--  pattern): Blizzard's action bar code never runs on them, so nothing taints
--  them. The secure parts (click, drag, page swap) run in restricted code; the
--  look is updated here from the game events. Stance and pet buttons use
--  Blizzard's StanceButtonTemplate / PetActionButtonTemplate (their own secure
--  click scripts) with our update code, like ElvUI does on 5.4.8.
--
--  Keys: every bar binds its standard command (ACTIONBUTTON1,
--  MULTIACTIONBAR1BUTTON1, SHAPESHIFTBUTTON1, BONUSACTIONBUTTON1, and
--  EUI_BAR9_BUTTON1 / EUI_BAR10_BUTTON1 from Bindings.xml) to its button with
--  SetOverrideBindingClick. A key press uses the "Keybind" mouse button so
--  Cast Actions on Key Down applies to keys only; a mouse click always acts on
--  release (retail behavior).
-------------------------------------------------------------------------------
local addonName, P = ...
local EAB = P.EAB

local pairs, ipairs, next, type, tonumber, tostring = pairs, ipairs, next, type, tonumber, tostring
local max = math.max
local InCombatLockdown = InCombatLockdown
local GetActionInfo, HasAction, GetActionTexture = GetActionInfo, HasAction, GetActionTexture
local GetActionCooldown, GetActionCharges, GetActionCount = GetActionCooldown, GetActionCharges, GetActionCount
local IsUsableAction, IsActionInRange, IsCurrentAction, IsAutoRepeatAction = IsUsableAction, IsActionInRange, IsCurrentAction, IsAutoRepeatAction
local IsAttackAction, IsConsumableAction, IsStackableAction, IsItemAction = IsAttackAction, IsConsumableAction, IsStackableAction, IsItemAction
local GetActionText, IsEquippedAction = GetActionText, IsEquippedAction

P.allButtons = {}      -- [btn] = true, every button of every bar
P.actionButtons = {}   -- [btn] = true, action buttons
P.barButtons = {}      -- [barKey] = { btn1, btn2, ... }
EAB.barButtons = P.barButtons
local activeButtons = {}  -- action buttons holding an action
P.activeButtons = activeButtons

local gridCount = 0       -- ACTIONBAR_SHOWGRID depth (a spell is being dragged)
P.gridShown = false

-------------------------------------------------------------------------------
--  Secure snippets
-------------------------------------------------------------------------------
-- Click: a key press comes in as "Keybind" and acts on the edge Cast Actions
-- on Key Down picks; a mouse press acts on release.
local CLICK_SNIPPET = [[
	if button == "Keybind" then
		local kd = self:GetAttribute("eab-keydown") and true or false
		if (down and true or false) ~= kd then
			return false
		end
		return "LeftButton"
	end
	if down then
		return false
	end
]]

local DRAG_START_SNIPPET = [[
	if self:GetAttribute("buttonlock") and not IsModifiedClick("PICKUPACTION") then
		return false
	end
	local action = self:GetAttribute("action")
	if not action or not HasAction(action) then
		return false
	end
	return "action", action
]]

local RECEIVE_DRAG_SNIPPET = [[
	if not kind or not value then
		return false
	end
	return "action", self:GetAttribute("action")
]]

-------------------------------------------------------------------------------
--  Action button: content (port of the LibActionButton Action type)
-------------------------------------------------------------------------------
local function IsUsableMethod(self)
	return IsUsableAction(self.action)
end

local function SpellIdOf(action)
	local actionType, id = GetActionInfo(action)
	if actionType == "spell" then
		return id
	elseif actionType == "macro" then
		local _, _, spellId = GetMacroSpell(id)
		return spellId
	end
end

local function UpdateCount(btn)
	local action = btn.action
	local fs = btn.Count
	if not fs then
		return
	end
	if not HasAction(action) then
		fs:SetText("")
		return
	end
	if IsConsumableAction(action) or IsStackableAction(action) or (not IsItemAction(action) and (GetActionCount(action) or 0) > 0) then
		local count = GetActionCount(action) or 0
		if count > (btn.maxDisplayCount or 9999) then
			fs:SetText("*")
		else
			fs:SetText(count)
		end
		P.ApplyZeroCount(btn, count)
	else
		local charges, maxCharges = GetActionCharges(action)
		if charges and maxCharges and maxCharges > 1 then
			fs:SetText(charges)
			P.ApplyZeroCount(btn, charges)
		else
			fs:SetText("")
			P.ApplyZeroCount(btn, nil)
		end
	end
end

local function UpdateCooldown(btn)
	local action = btn.action
	local cd = btn.cooldown
	if not cd then
		return
	end
	if not HasAction(action) then
		cd:Hide()
		P.SetCooldownState(btn, nil)
		return
	end
	local start, duration, enable = GetActionCooldown(action)
	local charges, maxCharges, cStart, cDuration = GetActionCharges(action)
	local p = P.Profile()
	if maxCharges and maxCharges > 1 and charges and charges > 0 and charges < maxCharges and cStart and cDuration and cDuration > 0 then
		-- A charge is still there: the recharge runs as an edge-only cooldown.
		cd:SetCooldown(cStart, cDuration, charges, maxCharges)
		cd:Show()
		P.SetCooldownState(btn, cStart, cDuration, true)
	else
		CooldownFrame_SetTimer(cd, start, duration, enable, charges, maxCharges)
		if enable and enable ~= 0 then
			P.SetCooldownState(btn, start, duration, false)
		else
			P.SetCooldownState(btn, nil)
		end
	end
	if GetActionLossOfControlCooldown and cd.SetLossOfControlCooldown then
		local lStart, lDuration = GetActionLossOfControlCooldown(action)
		cd:SetLossOfControlCooldown(lStart or 0, lDuration or 0)
	end
end

local function UpdateState(btn)
	local action = btn.action
	if btn.kind ~= "action" then
		return
	end
	btn:SetChecked((IsCurrentAction(action) or IsAutoRepeatAction(action)) and 1 or nil)
end

local function StartFlash(btn)
	btn.flashing = 1
	btn.flashtime = 0
	UpdateState(btn)
end

local function StopFlash(btn)
	btn.flashing = 0
	if btn.Flash then
		btn.Flash:Hide()
	end
	UpdateState(btn)
end

local function UpdateFlash(btn)
	local action = btn.action
	if (IsAttackAction(action) and IsCurrentAction(action)) or IsAutoRepeatAction(action) then
		StartFlash(btn)
	else
		StopFlash(btn)
	end
end

local function UpdateOverlayGlow(btn)
	local action = btn.action
	local actionType, id = GetActionInfo(action)
	local spellId = SpellIdOf(action)
	if spellId and IsSpellOverlayed(spellId) then
		P.ShowProcGlow(btn)
	elseif actionType == "flyout" and btn.eabGlowing then
		-- a flyout keeps the glow its spell gave it
	else
		P.HideProcGlow(btn)
	end
end

-- Flyout arrow (retail EUI_ActionBars_Flyout.lua: square buttons keep the
-- arrow, no flyout border).
local function UpdateFlyout(btn)
	local arrow = btn.FlyoutArrow
	if not arrow then
		return
	end
	if btn.FlyoutBorder then btn.FlyoutBorder:Hide() end
	if btn.FlyoutBorderShadow then btn.FlyoutBorderShadow:Hide() end
	local actionType = GetActionInfo(btn.action)
	if actionType ~= "flyout" then
		arrow:Hide()
		return
	end
	local dist = 2
	if (SpellFlyout and SpellFlyout:IsShown() and SpellFlyout:GetParent() == btn) or GetMouseFocus() == btn then
		dist = 5
	end
	arrow:Show()
	arrow:ClearAllPoints()
	local dir = btn:GetAttribute("flyoutDirection")
	if dir == "LEFT" then
		arrow:SetPoint("LEFT", btn, "LEFT", -dist, 0)
		SetClampedTextureRotation(arrow, 270)
	elseif dir == "RIGHT" then
		arrow:SetPoint("RIGHT", btn, "RIGHT", dist, 0)
		SetClampedTextureRotation(arrow, 90)
	elseif dir == "DOWN" then
		arrow:SetPoint("BOTTOM", btn, "BOTTOM", 0, -dist)
		SetClampedTextureRotation(arrow, 180)
	else
		arrow:SetPoint("TOP", btn, "TOP", 0, dist)
		SetClampedTextureRotation(arrow, 0)
	end
end
P.UpdateFlyout = UpdateFlyout

local function SetTooltip(btn)
	local s = P.BarSettings(btn.barKey)
	if s and s.disableTooltips then
		return
	end
	if GetCVar("UberTooltips") == "1" then
		GameTooltip_SetDefaultAnchor(GameTooltip, btn)
	else
		GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
	end
	if GameTooltip:SetAction(btn.action) then
		btn.UpdateTooltip = SetTooltip
	else
		btn.UpdateTooltip = nil
	end
end

-- Empty slot visibility: Always Show Buttons, or an action, or a drag.
function P.UpdateGridAlpha(btn)
	if btn.kind ~= "action" then
		return
	end
	local s = P.BarSettings(btn.barKey)
	local showEmpty = not s or s.alwaysShowButtons ~= false
	local visible = showEmpty or P.gridShown or P.qkOpen or HasAction(btn.action)
	if btn.eabOutsideCount then
		visible = false
	end
	btn:SetAlpha(visible and 1 or 0)
	if btn.slotBG then
		btn.slotBG:SetShown(visible)
	end
	if btn.edges then
		P.ShowEdges(btn.edges, visible)
	end
	if btn.iconBG then
		btn.iconBG:SetShown(P.Profile().showBlizzIconBg and visible and not HasAction(btn.action) and true or false)
	end
end

local function Update(btn)
	local action = btn.action
	if not action then
		return
	end
	local has = HasAction(action)
	if has then
		activeButtons[btn] = true
		UpdateState(btn)
		P.UpdateUsable(btn)
		UpdateCooldown(btn)
		UpdateFlash(btn)
	else
		activeButtons[btn] = nil
		if btn.cooldown then btn.cooldown:Hide() end
		P.SetCooldownState(btn, nil)
		btn:SetChecked(nil)
		StopFlash(btn)
	end

	-- Macro name (not on consumables).
	if btn.Name then
		if has and not IsConsumableAction(action) and not IsStackableAction(action) and (IsItemAction(action) or (GetActionCount(action) or 0) == 0) then
			btn.Name:SetText(GetActionText(action) or "")
		else
			btn.Name:SetText("")
		end
	end

	local texture = GetActionTexture(action)
	if texture then
		btn.icon:SetTexture(texture)
		btn.icon:Show()
		btn.rangeChecked = true
	else
		btn.icon:Hide()
		btn.rangeChecked = nil
		btn.outOfRange = nil
	end

	UpdateCount(btn)
	UpdateFlyout(btn)
	UpdateOverlayGlow(btn)
	P.UpdateEquippedBorder(btn)
	P.UpdateGridAlpha(btn)
	P.UpdateHotkeyColor(btn)
	if GameTooltip:GetOwner() == btn then
		SetTooltip(btn)
	end
end
P.UpdateActionButton = Update

-- The action attribute changed (page swap, setup): new slot, new content.
local function UpdateAction(btn, force)
	local action = tonumber(btn:GetAttribute("action"))
	if force or action ~= btn.action then
		btn.action = action
		Update(btn)
	end
end
P.UpdateAction = UpdateAction

-------------------------------------------------------------------------------
--  Action button: creation
-------------------------------------------------------------------------------
local function OnEnter(self)
	SetTooltip(self)
	UpdateFlyout(self)
end

local function OnLeave(self)
	GameTooltip:Hide()
	UpdateFlyout(self)
end

local function PreClick(self, button, down)
	if button == "Keybind" then
		P.SetKeyPushed(self, down)
	end
end

local function PostClick(self)
	UpdateState(self)
end

local function OnAttributeChanged(self, name)
	if name == "action" then
		UpdateAction(self)
	end
end

function P.CreateActionButton(info, index, header)
	local slot = (info.page - 1) * 12 + index
	local name = "EABButton" .. slot
	local btn = CreateFrame("CheckButton", name, header, "SecureActionButtonTemplate, ActionButtonTemplate")
	btn.kind = "action"
	btn.barKey = info.key
	btn.info = info
	btn.index = index
	btn.bindCommand = info.bind .. index
	btn.IsUsable = IsUsableMethod
	btn.flashing = 0
	btn.flashtime = 0

	btn:SetAttribute("type", "action")
	btn:SetAttribute("action", slot)
	btn:SetAttribute("checkselfcast", true)
	btn:SetAttribute("checkfocuscast", true)
	btn:SetAttribute("buttonlock", GetCVar("lockActionBars") == "1")
	btn:SetAttribute("eab-keydown", GetCVarBool("ActionButtonUseKeyDown") and true or false)
	btn:RegisterForDrag("LeftButton", "RightButton")
	btn:RegisterForClicks("AnyUp", "AnyDown")

	header:WrapScript(btn, "OnClick", CLICK_SNIPPET)
	header:WrapScript(btn, "OnDragStart", DRAG_START_SNIPPET)
	header:WrapScript(btn, "OnReceiveDrag", RECEIVE_DRAG_SNIPPET)
	-- Page swaps rewrite the action attribute in restricted code.
	btn:SetAttribute("_childupdate-eab-page", ([[
		local page = tonumber(message) or 1
		self:SetAttribute("action", %d + (page - 1) * 12)
	]]):format(index))

	btn:SetScript("OnAttributeChanged", OnAttributeChanged)
	btn:SetScript("OnEnter", OnEnter)
	btn:SetScript("OnLeave", OnLeave)
	btn:SetScript("PreClick", PreClick)
	btn:SetScript("PostClick", PostClick)

	P.StyleButton(btn)
	P.allButtons[btn] = true
	P.actionButtons[btn] = true
	UpdateAction(btn, true)
	return btn
end

-------------------------------------------------------------------------------
--  Stance buttons (StanceButtonTemplate; update like Blizzard StanceBar_UpdateState)
-------------------------------------------------------------------------------
local function StanceUsable(self)
	local _, _, _, isCastable = GetShapeshiftFormInfo(self:GetID())
	return isCastable
end

function P.CreateStanceButton(info, index, header)
	local btn = CreateFrame("CheckButton", "EABStanceButton" .. index, header, "StanceButtonTemplate")
	btn:SetID(index)
	btn.kind = "stance"
	btn.barKey = info.key
	btn.info = info
	btn.index = index
	btn.bindCommand = info.bind .. index
	btn.IsUsable = StanceUsable
	btn:RegisterForClicks(GetCVarBool("ActionButtonUseKeyDown") and "AnyDown" or "AnyUp")
	btn:HookScript("OnEnter", function(self)
		local s = P.BarSettings(self.barKey)
		if s and s.disableTooltips then GameTooltip:Hide() end
	end)
	local nt2 = _G[btn:GetName() .. "NormalTexture2"]
	if nt2 then nt2:SetAlpha(0) end
	P.StyleButton(btn)
	P.allButtons[btn] = true
	return btn
end

function P.UpdateStanceButtons()
	local list = P.barButtons.StanceBar
	if not list then
		return
	end
	local numForms = GetNumShapeshiftForms() or 0
	for i, btn in ipairs(list) do
		if i <= numForms then
			local texture, _, isActive, isCastable = GetShapeshiftFormInfo(i)
			btn.icon:SetTexture(texture or "Interface\\Icons\\Spell_Nature_WispSplode")
			btn.icon:Show()
			local start, duration, enable = GetShapeshiftFormCooldown(i)
			if btn.cooldown then
				CooldownFrame_SetTimer(btn.cooldown, start, duration, enable)
			end
			if enable and enable ~= 0 then
				P.SetCooldownState(btn, start, duration, false)
			else
				P.SetCooldownState(btn, nil)
			end
			btn:SetChecked(isActive and 1 or nil)
			if isCastable then
				btn.icon:SetVertexColor(1, 1, 1)
			else
				btn.icon:SetVertexColor(0.4, 0.4, 0.4)
			end
		else
			btn.icon:Hide()
			btn:SetChecked(nil)
		end
	end
end

-------------------------------------------------------------------------------
--  Pet buttons (PetActionButtonTemplate; update like Blizzard PetActionBar_Update)
-------------------------------------------------------------------------------
local function PetUsable(self)
	return GetPetActionSlotUsable(self:GetID())
end

function P.CreatePetButton(info, index, header)
	local name = "EABPetButton" .. index
	local btn = CreateFrame("CheckButton", name, header, "PetActionButtonTemplate")
	btn:SetID(index)
	btn.kind = "pet"
	btn.barKey = info.key
	btn.info = info
	btn.index = index
	btn.bindCommand = info.bind .. index
	btn.IsUsable = PetUsable
	btn:RegisterForClicks(GetCVarBool("ActionButtonUseKeyDown") and "AnyDown" or "AnyUp")
	btn.autoCastable = _G[name .. "AutoCastable"]
	btn.shine = _G[name .. "Shine"]
	btn:HookScript("OnEnter", function(self)
		local s = P.BarSettings(self.barKey)
		if s and s.disableTooltips then GameTooltip:Hide() end
	end)
	local nt2 = _G[name .. "NormalTexture2"]
	if nt2 then nt2:SetAlpha(0) end
	P.StyleButton(btn)
	if btn.shine then
		btn.shine:ClearAllPoints()
		btn.shine:SetAllPoints(btn)
	end
	P.allButtons[btn] = true
	return btn
end

function P.UpdatePetButtons()
	local list = P.barButtons.PetBar
	if not list then
		return
	end
	local hasBar = PetHasActionBar()
	for i, btn in ipairs(list) do
		local name, subtext, texture, isToken, isActive, autoCastAllowed, autoCastEnabled = GetPetActionInfo(i)
		if not isToken then
			btn.icon:SetTexture(texture)
			btn.tooltipName = name
		else
			btn.icon:SetTexture(_G[texture])
			btn.tooltipName = _G[name]
		end
		btn.isToken = isToken
		btn.tooltipSubtext = subtext
		if isActive and hasBar then
			btn:SetChecked(1)
			if IsPetAttackAction(i) then
				PetActionButton_StartFlash(btn)
			else
				PetActionButton_StopFlash(btn)
			end
		else
			btn:SetChecked(nil)
			PetActionButton_StopFlash(btn)
		end
		if btn.autoCastable then
			btn.autoCastable:SetShown(autoCastAllowed and true or false)
		end
		if btn.shine then
			if autoCastEnabled then
				AutoCastShine_AutoCastStart(btn.shine)
			else
				AutoCastShine_AutoCastStop(btn.shine)
			end
		end
		if texture then
			btn.icon:Show()
			if GetPetActionSlotUsable(i) and hasBar then
				btn.icon:SetVertexColor(1, 1, 1)
				btn.icon:SetDesaturated(nil)
			else
				btn.icon:SetVertexColor(0.4, 0.4, 0.4)
				btn.icon:SetDesaturated(1)
			end
		else
			btn.icon:Hide()
		end
		btn.hasPetAction = texture and true or false
		-- Empty pet slots: shown with Always Show Buttons, else only while
		-- something is dragged.
		local s = P.BarSettings(btn.barKey)
		local showEmpty = not s or s.alwaysShowButtons ~= false
		local visible = (texture or showEmpty or P.petGrid or P.qkOpen) and not btn.eabOutsideCount
		btn:SetAlpha(visible and 1 or 0)
		btn.slotBG:SetShown(visible and true or false)
		P.ShowEdges(btn.edges, visible and true or false)
	end
	P.UpdatePetCooldowns()
end

function P.UpdatePetCooldowns()
	local list = P.barButtons.PetBar
	if not list then
		return
	end
	for i, btn in ipairs(list) do
		local start, duration, enable = GetPetActionCooldown(i)
		if btn.cooldown then
			CooldownFrame_SetTimer(btn.cooldown, start, duration, enable)
		end
		if enable and enable ~= 0 and btn.hasPetAction then
			P.SetCooldownState(btn, start, duration, false)
		else
			P.SetCooldownState(btn, nil)
		end
		if GameTooltip:GetOwner() == btn and PetActionButton_OnEnter then
			PetActionButton_OnEnter(btn)
		end
	end
end

-------------------------------------------------------------------------------
--  Range / flash ticker (one OnUpdate for every action button with content)
-------------------------------------------------------------------------------
local ticker = CreateFrame("Frame")
local rangeTimer, flashTimer = 0, 0
ticker:SetScript("OnUpdate", function(_, elapsed)
	rangeTimer = rangeTimer - elapsed
	flashTimer = flashTimer - elapsed
	local doRange = rangeTimer <= 0
	local doFlash = flashTimer <= 0
	if not doRange and not doFlash then
		return
	end
	for btn in pairs(activeButtons) do
		if doFlash and btn.flashing == 1 and btn.Flash then
			btn.Flash:SetShown(not btn.Flash:IsShown())
		end
		if doRange and btn.rangeChecked then
			local inRange = IsActionInRange(btn.action)
			local out = (inRange == 0)
			if out ~= (btn.outOfRange or false) then
				btn.outOfRange = out or nil
				P.UpdateHotkeyColor(btn)
				P.UpdateUsable(btn)
			end
		end
	end
	if doRange then rangeTimer = 0.2 end
	if doFlash then flashTimer = ATTACK_BUTTON_FLASH_TIME or 0.4 end
end)

-------------------------------------------------------------------------------
--  Events
-------------------------------------------------------------------------------
local function ForAll(fn, onlyActive)
	for btn in pairs(onlyActive and activeButtons or P.actionButtons) do
		fn(btn)
	end
end

local function SpellMatches(btn, spellId)
	local action = btn.action
	local actionType, id = GetActionInfo(action)
	if actionType == "spell" then
		return id == spellId
	elseif actionType == "macro" then
		local _, _, macroSpell = GetMacroSpell(id)
		return macroSpell == spellId
	elseif actionType == "flyout" then
		return FlyoutHasSpell(id, spellId)
	end
	return false
end

function P.ShowGrid(show)
	if show then
		gridCount = gridCount + 1
	elseif gridCount > 0 then
		gridCount = gridCount - 1
	end
	local shown = gridCount > 0
	if shown == P.gridShown then
		return
	end
	P.gridShown = shown
	for btn in pairs(P.actionButtons) do
		P.UpdateGridAlpha(btn)
	end
	if P.OnGridChanged then
		P.OnGridChanged(shown)
	end
end

local events = CreateFrame("Frame")
P.buttonEvents = events
local EVENTS = {
	"PLAYER_ENTERING_WORLD", "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID", "ACTIONBAR_SLOT_CHANGED",
	"UPDATE_BINDINGS", "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS", "UPDATE_SHAPESHIFT_USABLE",
	"UPDATE_SHAPESHIFT_COOLDOWN", "UPDATE_VEHICLE_ACTIONBAR", "UPDATE_OVERRIDE_ACTIONBAR",
	"ACTIONBAR_UPDATE_STATE", "ACTIONBAR_UPDATE_USABLE", "ACTIONBAR_UPDATE_COOLDOWN", "PLAYER_TARGET_CHANGED",
	"TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "ARCHAEOLOGY_CLOSED", "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT",
	"START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL", "UNIT_INVENTORY_CHANGED", "LEARNED_SPELL_IN_TAB",
	"PET_STABLE_UPDATE", "PET_STABLE_SHOW", "SPELL_UPDATE_CHARGES", "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW",
	"SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", "UPDATE_SUMMONPETS_ACTION", "COMPANION_UPDATE",
	"UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "SPELL_UPDATE_USABLE", "PLAYER_EQUIPMENT_CHANGED",
	"LOSS_OF_CONTROL_ADDED", "LOSS_OF_CONTROL_UPDATE", "UPDATE_MACROS", "CVAR_UPDATE",
	"PET_BAR_UPDATE", "PET_BAR_UPDATE_COOLDOWN", "PET_BAR_UPDATE_USABLE", "PET_BAR_SHOWGRID",
	"PET_BAR_HIDEGRID", "PET_UI_UPDATE", "UNIT_PET", "UNIT_FLAGS", "UNIT_AURA", "PLAYER_CONTROL_LOST",
	"PLAYER_CONTROL_GAINED", "PLAYER_FARSIGHT_FOCUS_CHANGED",
}

events:SetScript("OnEvent", function(self, event, arg1)
	if event == "ACTIONBAR_SLOT_CHANGED" then
		for btn in pairs(P.actionButtons) do
			if arg1 == 0 or arg1 == btn.action then
				Update(btn)
			end
		end
		if P.OnSlotChanged then P.OnSlotChanged(arg1) end
	elseif event == "PLAYER_ENTERING_WORLD" or event == "UPDATE_VEHICLE_ACTIONBAR"
		or event == "UPDATE_OVERRIDE_ACTIONBAR" or event == "PET_STABLE_UPDATE" or event == "PET_STABLE_SHOW"
		or event == "UPDATE_MACROS" then
		ForAll(Update)
		P.UpdateStanceButtons()
		P.UpdatePetButtons()
	elseif event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_SHAPESHIFT_USABLE" or event == "UPDATE_SHAPESHIFT_COOLDOWN" then
		if event == "UPDATE_SHAPESHIFT_FORM" then
			-- attack icons change with the form
			for btn in pairs(activeButtons) do
				local tex = GetActionTexture(btn.action)
				if tex then btn.icon:SetTexture(tex) end
			end
		end
		P.UpdateStanceButtons()
	elseif event == "UPDATE_SHAPESHIFT_FORMS" then
		P.UpdateStanceButtons()
		if P.OnStanceFormsChanged then P.OnStanceFormsChanged() end
	elseif event == "ACTIONBAR_SHOWGRID" then
		P.ShowGrid(true)
	elseif event == "ACTIONBAR_HIDEGRID" then
		P.ShowGrid(false)
	elseif event == "UPDATE_BINDINGS" then
		if P.UpdateKeybinds then P.UpdateKeybinds() end
		for btn in pairs(P.allButtons) do
			P.UpdateHotkey(btn)
		end
	elseif event == "PLAYER_TARGET_CHANGED" then
		rangeTimer = 0
		P.UpdatePetButtons()
	elseif event == "ACTIONBAR_UPDATE_STATE" or event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_CLOSE"
		or event == "ARCHAEOLOGY_CLOSED"
		or ((event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE") and arg1 == "player")
		or (event == "COMPANION_UPDATE" and arg1 == "MOUNT") then
		ForAll(UpdateState, true)
	elseif event == "ACTIONBAR_UPDATE_USABLE" or event == "SPELL_UPDATE_USABLE" then
		ForAll(P.UpdateUsable, true)
	elseif event == "ACTIONBAR_UPDATE_COOLDOWN" or event == "LOSS_OF_CONTROL_ADDED" or event == "LOSS_OF_CONTROL_UPDATE" then
		for btn in pairs(activeButtons) do
			UpdateCooldown(btn)
			if GameTooltip:GetOwner() == btn then
				SetTooltip(btn)
			end
		end
	elseif event == "PLAYER_ENTER_COMBAT" then
		for btn in pairs(activeButtons) do
			if IsAttackAction(btn.action) then StartFlash(btn) end
		end
	elseif event == "PLAYER_LEAVE_COMBAT" then
		for btn in pairs(activeButtons) do
			if IsAttackAction(btn.action) then StopFlash(btn) end
		end
	elseif event == "START_AUTOREPEAT_SPELL" then
		for btn in pairs(activeButtons) do
			if IsAutoRepeatAction(btn.action) then StartFlash(btn) end
		end
	elseif event == "STOP_AUTOREPEAT_SPELL" then
		for btn in pairs(activeButtons) do
			if btn.flashing == 1 and not IsAttackAction(btn.action) then StopFlash(btn) end
		end
	elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
		for btn in pairs(activeButtons) do
			if SpellMatches(btn, arg1) then P.ShowProcGlow(btn) end
		end
	elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
		for btn in pairs(activeButtons) do
			if SpellMatches(btn, arg1) then P.HideProcGlow(btn) end
		end
	elseif event == "SPELL_UPDATE_CHARGES" then
		for btn in pairs(activeButtons) do
			UpdateCount(btn)
			UpdateCooldown(btn)
		end
	elseif event == "PLAYER_EQUIPMENT_CHANGED" then
		for btn in pairs(activeButtons) do
			P.UpdateEquippedBorder(btn)
		end
	elseif event == "UPDATE_SUMMONPETS_ACTION" then
		for btn in pairs(activeButtons) do
			local actionType = GetActionInfo(btn.action)
			if actionType == "summonpet" then
				local tex = GetActionTexture(btn.action)
				if tex then btn.icon:SetTexture(tex) end
			end
		end
	elseif event == "UNIT_INVENTORY_CHANGED" or event == "LEARNED_SPELL_IN_TAB" then
		if event == "LEARNED_SPELL_IN_TAB" or arg1 == "player" then
			local owner = GameTooltip:GetOwner()
			if owner and P.actionButtons[owner] then SetTooltip(owner) end
		end
	elseif event == "CVAR_UPDATE" then
		if P.ApplyClickSettings then P.ApplyClickSettings() end
	elseif event == "PET_BAR_UPDATE_COOLDOWN" then
		P.UpdatePetCooldowns()
	elseif event == "PET_BAR_SHOWGRID" then
		P.petGrid = true
		P.UpdatePetButtons()
	elseif event == "PET_BAR_HIDEGRID" then
		P.petGrid = nil
		P.UpdatePetButtons()
	elseif event == "UNIT_PET" or event == "UNIT_FLAGS" or event == "UNIT_AURA" then
		if (event == "UNIT_PET" and arg1 == "player") or arg1 == "pet" then
			P.UpdatePetButtons()
		end
	elseif event == "PET_BAR_UPDATE" or event == "PET_UI_UPDATE" or event == "PET_BAR_UPDATE_USABLE"
		or event == "PLAYER_CONTROL_LOST" or event == "PLAYER_CONTROL_GAINED" or event == "PLAYER_FARSIGHT_FOCUS_CHANGED" then
		P.UpdatePetButtons()
	end
end)

function P.EnableButtonEvents()
	for _, e in ipairs(EVENTS) do
		events:RegisterEvent(e)
	end
end

-- Blizzard's pet hotkey code rewrites the text on UPDATE_BINDINGS; ours wins.
hooksecurefunc("PetActionButton_SetHotkeys", function(self)
	if P.allButtons[self] then
		P.UpdateHotkey(self)
	end
end)

-------------------------------------------------------------------------------
--  Click settings: Cast Actions on Key Down, Lock Action Bars
-------------------------------------------------------------------------------
function P.ApplyClickSettings()
	if InCombatLockdown() then
		P.AfterCombat("clicks", P.ApplyClickSettings)
		return
	end
	local keyDown = GetCVarBool("ActionButtonUseKeyDown") and true or false
	local locked = GetCVar("lockActionBars") == "1"
	for btn in pairs(P.allButtons) do
		if btn.kind == "action" then
			btn:SetAttribute("eab-keydown", keyDown)
			btn:SetAttribute("buttonlock", locked)
		else
			btn:RegisterForClicks(keyDown and "AnyDown" or "AnyUp")
		end
	end
end

-------------------------------------------------------------------------------
--  Key bindings (retail UpdateKeybinds: the standard commands go to our
--  buttons through override bindings; none during pet battles)
-------------------------------------------------------------------------------
local bindOwner = CreateFrame("Frame", "EABBindingOwner", UIParent)
P.bindOwner = bindOwner

function P.UpdateKeybinds()
	if InCombatLockdown() then
		P.AfterCombat("keybinds", P.UpdateKeybinds)
		return
	end
	ClearOverrideBindings(bindOwner)
	if C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle() then
		return
	end
	for _, info in ipairs(P.BAR_CONFIG) do
		local list = P.barButtons[info.key]
		local s = P.BarSettings(info.key)
		if list and s and s.enabled ~= false then
			for _, btn in ipairs(list) do
				local cmd = btn.bindCommand
				if cmd then
					local keys = { GetBindingKey(cmd) }
					for _, key in ipairs(keys) do
						if key and key ~= "" then
							if btn.kind == "action" then
								SetOverrideBindingClick(bindOwner, false, key, btn:GetName(), "Keybind")
							else
								SetOverrideBindingClick(bindOwner, false, key, btn:GetName())
							end
						end
					end
				end
			end
		end
	end
	if P.UpdateToggleBindings then
		P.UpdateToggleBindings()
	end
end

do
	local f = CreateFrame("Frame")
	f:RegisterEvent("PET_BATTLE_OPENING_DONE")
	f:RegisterEvent("PET_BATTLE_CLOSE")
	f:SetScript("OnEvent", function()
		P.UpdateKeybinds()
	end)
end

-- Readable names for the Action Bar 9 / 10 commands (Key Bindings window).
BINDING_HEADER_EUI_BAR9 = "EllesmereUI Action Bar 9"
BINDING_HEADER_EUI_BAR10 = "EllesmereUI Action Bar 10"
for i = 1, 12 do
	_G["BINDING_NAME_EUI_BAR9_BUTTON" .. i] = "Action Bar 9 Button " .. i
	_G["BINDING_NAME_EUI_BAR10_BUTTON" .. i] = "Action Bar 10 Button " .. i
end

-- Spell flyouts opened from our buttons get the square look.
if SpellFlyout then
	hooksecurefunc(SpellFlyout, "Show", function()
		if P.Profile() then
			P.StyleFlyoutButtons()
		end
	end)
end
