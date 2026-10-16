-- Spec assignment popup for the profile system (retail EllesmereUI_Presets.lua).
--
-- Every Mists class and its specs in 5 columns, one checkbox per spec, with
-- the retail links (Check All | Check Tanks | Check Healers | Check DPS |
-- Uncheck All). Specs already assigned to another profile are grayed out.
-- Built with the 5.4.8 API only (solid color textures, 1 pixel borders).
--
-- Also holds the small popup kit (ns.PopupKit) the profile popups share
-- (EllesmereUI_ProfileSync.lua): the settings window helpers are local to
-- EllesmereUIOptions, which may not be loaded.

local ns = EllesmereUI

---------------------------------------------------------------------------
-- Popup kit
---------------------------------------------------------------------------
local Kit = {}
ns.PopupKit = Kit

local FONT_FALLBACK = "Fonts\\ARIALN.TTF"

function Kit.Accent()
	if ns.ResolveAccent then
		local r, g, b = ns.ResolveAccent()
		if r then
			return r, g, b
		end
	end
	return 12 / 255, 210 / 255, 157 / 255
end

function Kit.Solid(parent, layer, r, g, b, a)
	local tex = parent:CreateTexture(nil, layer or "BACKGROUND")
	tex:SetTexture(r, g, b, a)
	return tex
end

-- 1 pixel border of 4 textures; :SetColor(r, g, b, a) repaints it.
function Kit.Border(frame, r, g, b, a)
	local border = {}
	local function Edge()
		local tex = frame:CreateTexture(nil, "BORDER")
		tex:SetTexture(r, g, b, a)
		border[#border + 1] = tex
		return tex
	end
	local top = Edge()
	top:SetPoint("TOPLEFT")
	top:SetPoint("TOPRIGHT")
	top:SetHeight(1)
	local bottom = Edge()
	bottom:SetPoint("BOTTOMLEFT")
	bottom:SetPoint("BOTTOMRIGHT")
	bottom:SetHeight(1)
	local left = Edge()
	left:SetPoint("TOPLEFT", 0, -1)
	left:SetPoint("BOTTOMLEFT", 0, 1)
	left:SetWidth(1)
	local right = Edge()
	right:SetPoint("TOPRIGHT", 0, -1)
	right:SetPoint("BOTTOMRIGHT", 0, 1)
	right:SetWidth(1)
	function border:SetColor(nr, ng, nb, na)
		for i = 1, #self do
			self[i]:SetTexture(nr, ng, nb, na)
		end
	end
	return border
end

function Kit.Text(parent, size, r, g, b, a)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont(ns.FONT, size, "")
	if not fs:GetFont() then
		fs:SetFont(FONT_FALLBACK, size, "")
	end
	fs:SetTextColor(r or 1, g or 1, b or 1, a or 1)
	return fs
end

-- Small tooltip (the settings window one is local to EllesmereUIOptions).
local tip
function Kit.ShowTip(owner, text)
	if not text or text == "" then
		return
	end
	if not tip then
		tip = CreateFrame("Frame", nil, UIParent)
		tip:SetFrameStrata("TOOLTIP")
		tip:SetFrameLevel(100)
		Kit.Solid(tip, "BACKGROUND", 0.067, 0.067, 0.067, 0.94):SetAllPoints()
		Kit.Border(tip, 1, 1, 1, 0.15)
		tip.text = Kit.Text(tip, 12, 1, 1, 1, 0.85)
		tip.text:SetPoint("TOPLEFT", 9, -8)
		tip.text:SetWidth(230)
		tip.text:SetJustifyH("LEFT")
		tip.text:SetWordWrap(true)
	end
	tip.text:SetText(text)
	tip:SetSize(230 + 18, (tip.text:GetStringHeight() or 14) + 16)
	tip:ClearAllPoints()
	tip:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, 4)
	tip:Show()
end

function Kit.HideTip()
	if tip then
		tip:Hide()
	end
end

-- Flat button (retail popup buttons): accent = green outline, else white.
function Kit.Button(parent, w, h, label, accent, size)
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(w, h)
	btn.bg = Kit.Solid(btn, "BACKGROUND", 0.077, 0.068, 0.058, 0.92)
	btn.bg:SetAllPoints()
	btn.border = Kit.Border(btn, 1, 1, 1, 0.25)
	btn.label = Kit.Text(btn, size or 14, 1, 1, 1, 0.5)
	btn.label:SetPoint("CENTER")
	btn.label:SetText(label)
	btn.accent = accent
	function btn:SetVisual(hover)
		if self.accent then
			local r, g, b = Kit.Accent()
			local a = hover and 1 or 0.9
			self.border:SetColor(r, g, b, a)
			self.label:SetTextColor(r, g, b, a)
		else
			self.border:SetColor(1, 1, 1, hover and 0.40 or 0.25)
			self.label:SetTextColor(1, 1, 1, hover and 0.75 or 0.50)
		end
	end
	btn:SetScript("OnEnter", function(self) self:SetVisual(true) end)
	btn:SetScript("OnLeave", function(self) self:SetVisual(false) end)
	btn:SetVisual(false)
	return btn
end

-- Full screen dimmer + centered box; Escape and a click outside close it.
-- onClose runs whenever it closes that way (not when the caller hides it).
function Kit.Dimmer(name, level)
	local dimmer = CreateFrame("Frame", name, UIParent)
	dimmer:SetFrameStrata("FULLSCREEN_DIALOG")
	dimmer:SetFrameLevel(level or 20)
	dimmer:SetAllPoints(UIParent)
	dimmer:EnableMouse(true)
	dimmer:EnableMouseWheel(true)
	dimmer:SetScript("OnMouseWheel", function() end)
	Kit.Solid(dimmer, "BACKGROUND", 0, 0, 0, 0.25):SetAllPoints()
	dimmer:Hide()
	local box = CreateFrame("Frame", nil, dimmer)
	box:SetFrameLevel(dimmer:GetFrameLevel() + 5)
	box:EnableMouse(true)
	Kit.Solid(box, "BACKGROUND", 0.077, 0.068, 0.058, 1):SetAllPoints()
	-- 2px inset border at 0.15 (retail)
	Kit.Border(box, 1, 1, 1, 0.15)
	dimmer.box = box
	local function Dismiss()
		dimmer:Hide()
		if dimmer.onClose then
			dimmer.onClose()
		end
	end
	dimmer.Dismiss = Dismiss
	dimmer:SetScript("OnMouseDown", function()
		if not box:IsMouseOver() then
			Dismiss()
		end
	end)
	dimmer:EnableKeyboard(true)
	dimmer:SetScript("OnKeyDown", function(self, key)
		if key == "ESCAPE" then
			self:SetPropagateKeyboardInput(false)
			Dismiss()
		else
			self:SetPropagateKeyboardInput(true)
		end
	end)
	return dimmer, box
end

---------------------------------------------------------------------------
-- Classes and specs (Mists of Pandaria; spec IDs are the retail numbers).
-- role: TANK / HEALER / DAMAGER (role links).
---------------------------------------------------------------------------
local SPEC_DATA = {
	{ class = "DEATHKNIGHT", name = "Death Knight", specs = {
		{ id = 250, name = "Blood", role = "TANK" },
		{ id = 251, name = "Frost", role = "DAMAGER" },
		{ id = 252, name = "Unholy", role = "DAMAGER" },
	} },
	{ class = "DRUID", name = "Druid", specs = {
		{ id = 102, name = "Balance", role = "DAMAGER" },
		{ id = 103, name = "Feral", role = "DAMAGER" },
		{ id = 104, name = "Guardian", role = "TANK" },
		{ id = 105, name = "Restoration", role = "HEALER" },
	} },
	{ class = "HUNTER", name = "Hunter", specs = {
		{ id = 253, name = "Beast Mastery", role = "DAMAGER" },
		{ id = 254, name = "Marksmanship", role = "DAMAGER" },
		{ id = 255, name = "Survival", role = "DAMAGER" },
	} },
	{ class = "MAGE", name = "Mage", specs = {
		{ id = 62, name = "Arcane", role = "DAMAGER" },
		{ id = 63, name = "Fire", role = "DAMAGER" },
		{ id = 64, name = "Frost", role = "DAMAGER" },
	} },
	{ class = "MONK", name = "Monk", specs = {
		{ id = 268, name = "Brewmaster", role = "TANK" },
		{ id = 270, name = "Mistweaver", role = "HEALER" },
		{ id = 269, name = "Windwalker", role = "DAMAGER" },
	} },
	{ class = "PALADIN", name = "Paladin", specs = {
		{ id = 65, name = "Holy", role = "HEALER" },
		{ id = 66, name = "Protection", role = "TANK" },
		{ id = 70, name = "Retribution", role = "DAMAGER" },
	} },
	{ class = "PRIEST", name = "Priest", specs = {
		{ id = 256, name = "Discipline", role = "HEALER" },
		{ id = 257, name = "Holy", role = "HEALER" },
		{ id = 258, name = "Shadow", role = "DAMAGER" },
	} },
	{ class = "ROGUE", name = "Rogue", specs = {
		{ id = 259, name = "Assassination", role = "DAMAGER" },
		{ id = 260, name = "Combat", role = "DAMAGER" },
		{ id = 261, name = "Subtlety", role = "DAMAGER" },
	} },
	{ class = "SHAMAN", name = "Shaman", specs = {
		{ id = 262, name = "Elemental", role = "DAMAGER" },
		{ id = 263, name = "Enhancement", role = "DAMAGER" },
		{ id = 264, name = "Restoration", role = "HEALER" },
	} },
	{ class = "WARLOCK", name = "Warlock", specs = {
		{ id = 265, name = "Affliction", role = "DAMAGER" },
		{ id = 266, name = "Demonology", role = "DAMAGER" },
		{ id = 267, name = "Destruction", role = "DAMAGER" },
	} },
	{ class = "WARRIOR", name = "Warrior", specs = {
		{ id = 71, name = "Arms", role = "DAMAGER" },
		{ id = 72, name = "Fury", role = "DAMAGER" },
		{ id = 73, name = "Protection", role = "TANK" },
	} },
}
ns.SPEC_DATA = SPEC_DATA

-- Spec ID -> spec name in the client language (static English name if the
-- client has none, e.g. a retail-only spec ID).
function ns.SpecName(specID)
	if GetSpecializationInfoByID then
		local _, name = GetSpecializationInfoByID(specID)
		if name and name ~= "" then
			return name
		end
	end
	for _, cls in ipairs(SPEC_DATA) do
		for _, spec in ipairs(cls.specs) do
			if spec.id == specID then
				return spec.name
			end
		end
	end
	return tostring(specID)
end

---------------------------------------------------------------------------
-- Spec assignment popup
--   opts.db[opts.dbKey][presetKey] = { [specID] = true } (edited in place)
--   other keys of db[dbKey] = specs taken by other profiles (grayed out)
--   opts.title, opts.subtitle, opts.buttonText, opts.onDone, opts.onCancel
---------------------------------------------------------------------------
local NUM_COLS = 5
local COL_LISTS = { { 1, 6, 11 }, { 2, 7 }, { 3, 8 }, { 4, 9 }, { 5, 10 } }
local COL_W, COL_GAP = 165, 12
local CONTENT_LEFT, CONTENT_RIGHT, CONTENT_TOP = 41, 36, 120
local CLASS_H, CLASS_PAD_TOP, CLASS_PAD_BOT = 32, 4, 2
local SPEC_H, CLASS_GAP = 28, 10
local BOX_SZ, CHECK_INSET = 18, 3
local POPUP_W = CONTENT_LEFT + CONTENT_RIGHT + NUM_COLS * COL_W + (NUM_COLS - 1) * COL_GAP
local POPUP_H = 620

-- Checkbox colors (retail CB_BOX / BORDER constants)
local CB_BOX = { 0.114, 0.106, 0.099 }
local BORDER = { 0.224, 0.215, 0.207 }
local CB_BRD_A, CB_ACT_BRD_A = 0.6, 0.9

local specPopup

local function BuildSpecPopup()
	local dimmer, popup = Kit.Dimmer("EUISpecAssignDimmer", 20)
	popup:SetSize(POPUP_W, POPUP_H)
	popup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	popup.dimmer = dimmer

	popup.title = Kit.Text(popup, 22, 1, 1, 1, 1)
	popup.title:SetPoint("TOP", popup, "TOP", 0, -32)
	popup.subtitle = Kit.Text(popup, 14, 1, 1, 1, 0.45)
	popup.subtitle:SetPoint("TOP", popup.title, "BOTTOM", 0, -8)
	popup.subtitle:SetWidth(POPUP_W - 60)
	popup.subtitle:SetJustifyH("CENTER")
	popup.subtitle:SetWordWrap(true)

	-- Check All | Check Tanks | Check Healers | Check DPS | Uncheck All
	local LINK_Y, LINK_GAP = -103, 20
	local prevLink
	local function MakeLink(text)
		local btn = CreateFrame("Button", nil, popup)
		local lbl = Kit.Text(btn, 14, 1, 1, 1, 0.45)
		lbl:SetText(text)
		lbl:SetPoint("CENTER")
		btn:SetSize((lbl:GetStringWidth() or 60) + 4, 20)
		if prevLink then
			local div = Kit.Solid(popup, "OVERLAY", 1, 1, 1, 0.18)
			div:SetPoint("LEFT", prevLink, "RIGHT", LINK_GAP / 2, 0)
			div:SetSize(1, 12)
			btn:SetPoint("LEFT", prevLink, "RIGHT", LINK_GAP, 0)
		else
			btn:SetPoint("TOPLEFT", popup, "TOPLEFT", CONTENT_LEFT, LINK_Y)
		end
		btn:SetScript("OnEnter", function() lbl:SetTextColor(1, 1, 1, 0.80) end)
		btn:SetScript("OnLeave", function() lbl:SetTextColor(1, 1, 1, 0.45) end)
		prevLink = btn
		return btn
	end
	popup.checkAll = MakeLink("Check All")
	popup.checkTanks = MakeLink("Check Tanks")
	popup.checkHealers = MakeLink("Check Healers")
	popup.checkDPS = MakeLink("Check DPS")
	popup.uncheckAll = MakeLink("Uncheck All")

	-- Class headers and spec rows (built once; the data never changes).
	popup.rows = {}
	for colIdx = 1, NUM_COLS do
		local col = CreateFrame("Frame", nil, popup)
		col:SetPoint("TOPLEFT", popup, "TOPLEFT", CONTENT_LEFT + (colIdx - 1) * (COL_W + COL_GAP), -CONTENT_TOP)
		col:SetSize(COL_W, POPUP_H - CONTENT_TOP - 80)
		local yOff = 0
		for n, classIdx in ipairs(COL_LISTS[colIdx]) do
			local cls = SPEC_DATA[classIdx]
			if n > 1 then
				yOff = yOff + CLASS_GAP
			end
			yOff = yOff + CLASS_PAD_TOP
			local hdr = CreateFrame("Frame", nil, col)
			hdr:SetSize(COL_W, CLASS_H)
			hdr:SetPoint("TOPLEFT", col, "TOPLEFT", 0, -yOff)
			local label = Kit.Text(hdr, 18, 1, 1, 1, 0.7)
			label:SetPoint("BOTTOMLEFT", hdr, "BOTTOMLEFT", 4, 4)
			local clr = RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls.class]
			if clr then
				label:SetTextColor(clr.r, clr.g, clr.b, 0.9)
			end
			label:SetText((LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[cls.class]) or cls.name)
			yOff = yOff + CLASS_H + CLASS_PAD_BOT

			for _, spec in ipairs(cls.specs) do
				local row = CreateFrame("Button", nil, col)
				row:SetSize(COL_W, SPEC_H)
				row:SetPoint("TOPLEFT", col, "TOPLEFT", 0, -yOff)
				local box = CreateFrame("Frame", nil, row)
				box:SetSize(BOX_SZ, BOX_SZ)
				box:SetPoint("LEFT", row, "LEFT", 8, 0)
				row.boxBg = Kit.Solid(box, "BACKGROUND", CB_BOX[1], CB_BOX[2], CB_BOX[3], 1)
				row.boxBg:SetAllPoints()
				row.boxBorder = Kit.Border(box, BORDER[1], BORDER[2], BORDER[3], CB_BRD_A)
				local r, g, b = Kit.Accent()
				row.check = Kit.Solid(box, "ARTWORK", r, g, b, 1)
				row.check:SetPoint("TOPLEFT", box, "TOPLEFT", CHECK_INSET, -CHECK_INSET)
				row.check:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -CHECK_INSET, CHECK_INSET)
				row.box = box
				row.lbl = Kit.Text(row, 17, 1, 1, 1, 0.65)
				row.lbl:SetPoint("LEFT", box, "RIGHT", 8, 0)
				row.lbl:SetText(ns.SpecName(spec.id))
				row.specID = spec.id
				row.role = spec.role
				popup.rows[#popup.rows + 1] = row
				yOff = yOff + SPEC_H
			end
		end
	end

	-- Done (and Cancel when the caller gives onCancel)
	popup.done = Kit.Button(popup, 200, 39, "Done", true, 16)
	popup.cancel = Kit.Button(popup, 200, 39, "Cancel", false, 16)
	specPopup = popup
end

local function UpdateRow(row)
	local r, g, b = Kit.Accent()
	row.check:SetTexture(r, g, b, 1)
	if row.locked then
		row.check:Hide()
		row.boxBorder:SetColor(BORDER[1], BORDER[2], BORDER[3], CB_BRD_A * 0.4)
		row.boxBg:SetTexture(CB_BOX[1], CB_BOX[2], CB_BOX[3], 0.35)
		row.lbl:SetTextColor(1, 1, 1, 0.25)
	elseif row.checked then
		row.check:Show()
		row.boxBorder:SetColor(r, g, b, CB_ACT_BRD_A)
		row.boxBg:SetTexture(CB_BOX[1], CB_BOX[2], CB_BOX[3], 1)
		row.lbl:SetTextColor(1, 1, 1, 0.65)
	else
		row.check:Hide()
		row.boxBorder:SetColor(BORDER[1], BORDER[2], BORDER[3], CB_BRD_A)
		row.boxBg:SetTexture(CB_BOX[1], CB_BOX[2], CB_BOX[3], 1)
		row.lbl:SetTextColor(1, 1, 1, 0.65)
	end
end

function ns.ShowSpecAssignPopup(opts)
	if not specPopup then
		BuildSpecPopup()
	end
	local popup = specPopup
	local db, dbKey, presetKey = opts.db, opts.dbKey, opts.presetKey
	db[dbKey] = db[dbKey] or {}
	db[dbKey][presetKey] = db[dbKey][presetKey] or {}
	local assignments = db[dbKey][presetKey]

	popup.title:SetText(opts.title or "Assign Preset to Specs")
	popup.subtitle:SetText(opts.subtitle
		or format("Select which specs you want %s to be assigned to", tostring(presetKey)))

	-- specID -> the other profile that has it
	local lockedBy = {}
	for key, set in pairs(db[dbKey]) do
		if key ~= presetKey and type(set) == "table" then
			for specID in pairs(set) do
				lockedBy[specID] = key
			end
		end
	end

	local function SetChecked(row, on)
		if row.locked then
			return
		end
		row.checked = on and true or false
		assignments[row.specID] = on and true or nil
		UpdateRow(row)
	end

	for _, row in ipairs(popup.rows) do
		row.lockedBy = lockedBy[row.specID]
		row.locked = row.lockedBy ~= nil
		row.checked = assignments[row.specID] == true
		UpdateRow(row)
		row:SetScript("OnClick", function(self)
			SetChecked(self, not self.checked)
		end)
		row:SetScript("OnEnter", function(self)
			if self.locked then
				Kit.ShowTip(self.box, format("Already assigned to %s", self.lockedBy))
				return
			end
			self.lbl:SetTextColor(1, 1, 1, 0.90)
		end)
		row:SetScript("OnLeave", function(self)
			Kit.HideTip()
			if not self.locked then
				self.lbl:SetTextColor(1, 1, 1, 0.65)
			end
		end)
	end

	popup.checkAll:SetScript("OnClick", function()
		for _, row in ipairs(popup.rows) do
			SetChecked(row, true)
		end
	end)
	popup.uncheckAll:SetScript("OnClick", function()
		for _, row in ipairs(popup.rows) do
			SetChecked(row, false)
		end
	end)
	-- Role links add to the current checks (Tanks + Healers can be combined).
	local function CheckRole(role)
		for _, row in ipairs(popup.rows) do
			if row.role == role then
				SetChecked(row, true)
			end
		end
	end
	popup.checkTanks:SetScript("OnClick", function() CheckRole("TANK") end)
	popup.checkHealers:SetScript("OnClick", function() CheckRole("HEALER") end)
	popup.checkDPS:SetScript("OnClick", function() CheckRole("DAMAGER") end)

	popup.done.label:SetText(opts.buttonText or "Done")
	popup.done:ClearAllPoints()
	popup.cancel:ClearAllPoints()
	if opts.onCancel then
		popup.cancel:Show()
		popup.done:SetPoint("BOTTOMRIGHT", popup, "BOTTOM", -6, 38)
		popup.cancel:SetPoint("BOTTOMLEFT", popup, "BOTTOM", 6, 38)
	else
		popup.cancel:Hide()
		popup.done:SetPoint("BOTTOM", popup, "BOTTOM", 0, 38)
	end
	popup.dimmer.onClose = opts.onCancel
	popup.cancel:SetScript("OnClick", function()
		popup.dimmer.Dismiss()
	end)
	popup.done:SetScript("OnClick", function()
		popup.dimmer:Hide()
		if opts.onDone then
			opts.onDone(assignments)
		end
	end)
	popup.dimmer:Show()
end
