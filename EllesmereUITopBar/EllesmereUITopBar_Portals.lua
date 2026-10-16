-------------------------------------------------------------------------------
--  EllesmereUITopBar_Portals.lua (5.4.8 port of NaowhUI_Portals.lua)
--
--  Portal flyout of the top bar; each portal is a secure button. 5.4.8: the
--  Challenge Mode teleports (gold rewards) instead of the M+ season list.
--  The retail toggles that hide EllesmereUI's minimap / chat M+ buttons are
--  left out (this port has no such buttons).
-------------------------------------------------------------------------------
local addonName = ...
local ns = EllesmereUI
local TopBar = ns.TopBar
if not TopBar then return end

-- Same list as EllesmereUIDataBars (SEASON_PORTALS), with short labels.
local PORTALS = {
	{ ids = { 131204 }, short = "TJS" },   -- Path of the Jade Serpent (Temple of the Jade Serpent)
	{ ids = { 131205 }, short = "SSB" },   -- Path of the Stout Brew (Stormstout Brewery)
	{ ids = { 131206 }, short = "SPM" },   -- Path of the Shado-Pan (Shado-Pan Monastery)
	{ ids = { 131222 }, short = "MSP" },   -- Path of the Mogu King (Mogu'shan Palace)
	{ ids = { 131225 }, short = "GSS" },   -- Path of the Setting Sun (Gate of the Setting Sun)
	{ ids = { 131228 }, short = "SNT" },   -- Path of the Black Ox (Siege of Niuzao Temple)
	{ ids = { 131229 }, short = "SM" },    -- Path of the Scarlet Mitre (Scarlet Monastery)
	{ ids = { 131231 }, short = "SH" },    -- Path of the Scarlet Blade (Scarlet Halls)
	{ ids = { 131232 }, short = "SCH" },   -- Path of the Necromancer (Scholomance)
}

-- The variant of this teleport the character knows, or nil for none.
local function KnownSpell(entry)
	for i = 1, #entry.ids do
		local id = entry.ids[i]
		if (IsPlayerSpell and IsPlayerSpell(id)) or (IsSpellKnown and IsSpellKnown(id)) then return id end
	end
	return nil
end

-------------------------------------------------------------------------------
--  Flyout
-------------------------------------------------------------------------------
local flyout, flyoutBtns

local function Border(frame, r, g, b, a)
	local PP = ns.PP
	if PP and PP.CreateBorder then
		PP.CreateBorder(frame, r, g, b, a, 1, "OVERLAY", 7)
	elseif ns.MakeBorder then
		ns.MakeBorder(frame, r, g, b, a)
	end
end

-- The cast attribute only moves on learning a spell, and never in combat.
local function RefreshPortalButtons()
	if not flyoutBtns then return end
	local locked = InCombatLockdown()

	for _, btn in ipairs(flyoutBtns) do
		local resolved = KnownSpell(btn.entry)
		local known    = resolved ~= nil
		local spellID  = resolved or btn.entry.ids[1]   -- none known: show the primary, greyed out

		if btn.spellID ~= spellID or not btn._wired then
			local name, _, icon = GetSpellInfo(spellID)
			if icon then btn.icon:SetTexture(icon) end
			if not locked and name then
				btn:SetAttribute("spell", name)
				btn.spellID = spellID
				btn._wired = true
			end
		end

		if btn._lastKnown ~= known then
			btn._lastKnown = known
			btn.icon:SetDesaturated(not known)
			btn.icon:SetAlpha(known and 1 or 0.4)
		end
		local start, dur = 0, 0
		if known then start, dur = GetSpellCooldown(spellID) end
		if start and dur and dur > 1.5 then
			btn.cooldown:SetCooldown(start, dur)
		else
			btn.cooldown:SetCooldown(0, 0)
		end
	end
end

local function CreateFlyout()
	if flyout then return flyout end

	local BTN_SIZE, SPACING, PADDING, COLS = 32, 2, 4, 4
	local ROWS = math.ceil(#PORTALS / COLS)
	local flyW = PADDING * 2 + BTN_SIZE * COLS + SPACING * (COLS - 1)
	local flyH = PADDING * 2 + BTN_SIZE * ROWS + SPACING * (ROWS - 1)

	-- SecureHandlerStateTemplate so the flyout can close ITSELF on combat
	-- start: it parents secure buttons, so our own Hide() is protected then.
	flyout = CreateFrame("Frame", "EllesmereUITopBarPortalFlyout", UIParent, "SecureHandlerStateTemplate")
	flyout:SetSize(flyW, flyH)
	flyout:SetFrameStrata("DIALOG")
	flyout:SetFrameLevel(100)
	flyout:SetClampedToScreen(true)
	flyout:Hide()

	local bg = flyout:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetTexture(0.04, 0.04, 0.06, 0.95)
	Border(flyout, 1, 1, 1, 0.06)

	-- A custom state ("combat"), not "visibility": this only ever closes it.
	flyout:SetAttribute("_onstate-combat", [[
		if newstate == "in" then self:Hide() end
	]])
	RegisterStateDriver(flyout, "combat", "[combat] in; out")

	local font = (ns.GetFontPath and ns.GetFontPath("topBar")) or STANDARD_TEXT_FONT

	flyoutBtns = {}
	for i, entry in ipairs(PORTALS) do
		local col = (i - 1) % COLS
		local row = math.floor((i - 1) / COLS)

		local btn = CreateFrame("Button", "EllesmereUITopBarPortal" .. i, flyout, "SecureActionButtonTemplate")
		btn:SetSize(BTN_SIZE, BTN_SIZE)
		btn:SetPoint("TOPLEFT", flyout, "TOPLEFT",
			PADDING + col * (BTN_SIZE + SPACING),
			-(PADDING + row * (BTN_SIZE + SPACING)))
		btn.entry = entry

		local icon = btn:CreateTexture(nil, "ARTWORK")
		icon:SetAllPoints()
		icon:SetTexCoord(6 / 64, 58 / 64, 6 / 64, 58 / 64)
		btn.icon = icon

		Border(btn, 0, 0, 0, 1)

		local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
		cd:SetAllPoints()
		cd.noCooldownCount = true
		cd.noOCC = true
		btn.cooldown = cd

		if entry.short then
			local label = btn:CreateFontString(nil, "OVERLAY")
			label:SetFont(font, 8, "OUTLINE")
			if not label:GetFont() then label:SetFont(STANDARD_TEXT_FONT, 8, "OUTLINE") end
			label:SetPoint("BOTTOM", btn, "BOTTOM", 0, 2)
			label:SetTextColor(1, 1, 1, 0.9)
			label:SetText(entry.short)
		end

		local hover = btn:CreateTexture(nil, "HIGHLIGHT")
		hover:SetAllPoints()
		hover:SetTexture(1, 1, 1, 0.2)

		btn:RegisterForClicks("AnyUp")
		btn:SetAttribute("type", "spell")

		btn:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetSpellByID(self.spellID or self.entry.ids[1])
			GameTooltip:Show()
		end)
		btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

		flyoutBtns[i] = btn
	end
	RefreshPortalButtons()

	flyout:SetScript("OnShow", function(self)
		self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
		self:RegisterEvent("SPELLS_CHANGED")
		RefreshPortalButtons()
	end)
	flyout:SetScript("OnHide", function(self) self:UnregisterAllEvents() end)
	flyout:SetScript("OnEvent", function() RefreshPortalButtons() end)

	-- Escape closes it (out of combat; in combat the state driver already did).
	tinsert(UISpecialFrames, "EllesmereUITopBarPortalFlyout")

	return flyout
end

function TopBar.TogglePortalFlyout(anchorBtn)
	if InCombatLockdown() then return end
	local fly = CreateFlyout()
	if fly:IsShown() then
		fly:Hide()
		return
	end
	-- The top bar sits at the top of the screen, so open downward; a bar
	-- moved to the lower half opens upward.
	fly:ClearAllPoints()
	local _, y = anchorBtn:GetCenter()
	if y and y < (UIParent:GetHeight() / 2) then
		fly:SetPoint("BOTTOM", anchorBtn, "TOP", 0, 4)
	else
		fly:SetPoint("TOP", anchorBtn, "BOTTOM", 0, -4)
	end
	fly:Show()
end

function TopBar.HidePortalFlyout()
	if flyout and not InCombatLockdown() then flyout:Hide() end
end
