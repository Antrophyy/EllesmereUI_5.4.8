-- First time setup (retail EllesmereUI_FirstInstall.lua): one popup on the
-- first login of a new install. Three columns (Core / QoL / UI Reskin), one
-- checkbox per installed EllesmereUI addon, Check All / Uncheck All, and
-- "Reload UI" turns the unchecked addons off (5.4.8: for this character).
--
-- Added in this port: "Import Profile" opens the Profiles page with the paste
-- box, so a new user can bring a profile (also a retail string) right away.
-- `/eui setup` and Profiles > First Time Setup open it again.
--
-- Left out: the Cursor Circle checkbox (no cursor circle in the Mists QoL
-- module) and the style picker that follows on retail (no Style page here).

local ns = EllesmereUI

local GROUPS = {
	{
		header = "Core Addons",
		entries = {
			{ label = "Action Bars", addon = "EllesmereUIActionBars" },
			{ label = "Nameplates", addon = "EllesmereUINameplates" },
			{ label = "Unit Frames", addon = "EllesmereUIUnitFrames" },
			{ label = "Cooldown Manager", addon = "EllesmereUICooldownManager" },
			{ label = "Raid Frames", addon = "EllesmereUIRaidFrames" },
			{ label = "Resource Bars", addon = "EllesmereUIResourceBars" },
		},
	},
	{
		header = "QoL Addons",
		entries = {
			{ label = "Quality of Life", addon = "EllesmereUIQoL" },
			{ label = "AuraBuff Reminders", addon = "EllesmereUIAuraBuffReminders" },
			{ label = "DataBars", addon = "EllesmereUIDataBars" },
			{ label = "Quickdraw", addon = "EllesmereUIQuickdraw" },
			{ label = "Top Bar", addon = "EllesmereUITopBar" },
			{ label = "Reforge", addon = "EllesmereUIReforge" },
			{ label = "Interrupt Tracker", addon = "EllesmereUIInterruptTracker" },
		},
	},
	{
		header = "UI Reskin Addons",
		entries = {
			{ label = "Blizzard Skins+", addon = "EllesmereUIBlizzardSkin" },
			{ label = "Friends List", addon = "EllesmereUIFriends" },
			{ label = "Damage Meters", addon = "EllesmereUIDamageMeters" },
			{ label = "Chat", addon = "EllesmereUIChat" },
			{ label = "Bags", addon = "EllesmereUIBags" },
			{ label = "Challenge Mode Tools", addon = "EllesmereUIChallengeTimer" },
			{ label = "Quest Tracker", addon = "EllesmereUIQuestTracker" },
			{ label = "Minimap", addon = "EllesmereUIMinimap" },
		},
	},
}

local function DB()
	if type(EllesmereUIDB) ~= "table" then
		EllesmereUIDB = {}
	end
	return EllesmereUIDB
end

-- Installed? (GetAddOnInfo gives reason "MISSING" for a folder that is not there.)
local function IsInstalled(folder)
	local name, _, _, _, _, reason = GetAddOnInfo(folder)
	return name ~= nil and reason ~= "MISSING"
end

-- Enabled for this character (5.4.8 GetAddOnInfo: 4th value).
local function IsEnabled(folder)
	local _, _, _, enabled = GetAddOnInfo(folder)
	return enabled and true or false
end

local CB_BOX = { 0.075, 0.113, 0.141 }
local CB_BRD_A, CB_ACT_BRD_A = 0.25, 0.85

local function Tex(parent, layer, r, g, b, a)
	local t = parent:CreateTexture(nil, layer)
	t:SetTexture(r, g, b, a)
	return t
end

local function Font(parent, size, r, g, b, a)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	local path = ns.GetFontPath and ns.GetFontPath() or ns.FONT
	fs:SetFont(path or ns.FONT, size, "")
	if not fs:GetFont() then
		fs:SetFont(ns.FONT, size, "")
	end
	fs:SetTextColor(r, g, b, a)
	return fs
end

local popup

local function Build()
	local EG = ns.ELLESMERE_GREEN or { r = 12 / 255, g = 210 / 255, b = 157 / 255 }
	local COL_W, COL_GAP = 210, 18
	local CONTENT_LEFT, CONTENT_RIGHT, CONTENT_TOP = 41, 36, 216
	local HEADER_H, HEADER_PAD, ROW_H, BOX_SZ, CHECK_INSET = 32, 6, 28, 18, 3

	-- Only the addons that are installed.
	local groups = {}
	for _, g in ipairs(GROUPS) do
		local entries = {}
		for _, e in ipairs(g.entries) do
			if IsInstalled(e.addon) then
				entries[#entries + 1] = e
			end
		end
		if #entries > 0 then
			groups[#groups + 1] = { header = g.header, entries = entries }
		end
	end
	local tallest = 0
	for _, g in ipairs(groups) do
		tallest = math.max(tallest, #g.entries)
	end
	local W = CONTENT_LEFT + CONTENT_RIGHT + #groups * COL_W + (#groups - 1) * COL_GAP
	local H = CONTENT_TOP + HEADER_H + HEADER_PAD + tallest * ROW_H + 110

	-- Dimmer + panel. No Escape (like retail): a button closes it.
	local dimmer = CreateFrame("Frame", "EUIFirstInstall", UIParent)
	popup = dimmer
	dimmer:SetAllPoints(UIParent)
	dimmer:SetFrameStrata("FULLSCREEN_DIALOG")
	dimmer:SetFrameLevel(20)
	dimmer:EnableMouse(true)
	dimmer:EnableMouseWheel(true)
	dimmer:SetScript("OnMouseWheel", function() end)
	Tex(dimmer, "BACKGROUND", 0, 0, 0, 0.55):SetAllPoints()

	local panel = CreateFrame("Frame", nil, dimmer)
	panel:SetSize(W, H)
	panel:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
	panel:SetClampedToScreen(true)
	panel:EnableMouse(true)
	Tex(panel, "BACKGROUND", 0.077, 0.068, 0.058, 0.98):SetAllPoints()
	ns.MakeBorder(panel, 1, 1, 1, 0.15)
	local lvl = panel:GetFrameLevel()

	-- Header art: three mini module cards (the three columns in miniature).
	local CARD_W, CARD_H, CARD_GAP = 124, 52, 14
	for i = 1, 3 do
		local center = i == 2
		local h = center and CARD_H + 10 or CARD_H
		local card = CreateFrame("Frame", nil, panel)
		card:SetFrameLevel(lvl + 1)
		card:SetSize(CARD_W, h)
		card:SetPoint("CENTER", panel, "TOP", (i - 2) * (CARD_W + CARD_GAP), -54)
		Tex(card, "BACKGROUND", 0.121, 0.113, 0.106, 1):SetAllPoints()
		local accent = Tex(card, "ARTWORK", EG.r, EG.g, EG.b, center and 0.95 or 0.7)
		accent:SetHeight(2)
		accent:SetPoint("TOPLEFT", 1, -1)
		accent:SetPoint("TOPRIGHT", -1, -1)
		local box = Tex(card, "ARTWORK", CB_BOX[1], CB_BOX[2], CB_BOX[3], 1)
		box:SetSize(12, 12)
		box:SetPoint("TOPLEFT", 12, -14)
		local check = Tex(card, "OVERLAY", EG.r, EG.g, EG.b, center and 1 or 0.8)
		check:SetSize(6, 6)
		check:SetPoint("CENTER", box, "CENTER")
		local l1 = Tex(card, "ARTWORK", 1, 1, 1, center and 0.42 or 0.32)
		l1:SetSize(CARD_W - 52, 5)
		l1:SetPoint("LEFT", box, "RIGHT", 8, 0)
		local l2 = Tex(card, "ARTWORK", 1, 1, 1, 0.16)
		l2:SetSize(CARD_W - 72, 5)
		l2:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -8)
		if center then
			local l3 = Tex(card, "ARTWORK", 1, 1, 1, 0.12)
			l3:SetSize(CARD_W - 84, 5)
			l3:SetPoint("TOPLEFT", l2, "BOTTOMLEFT", 0, -7)
		end
		ns.MakeBorder(card, 1, 1, 1, center and 0.16 or 0.10)
	end

	local eyebrow = Font(panel, 13, EG.r, EG.g, EG.b, 0.9)
	eyebrow:SetPoint("TOP", panel, "TOP", 0, -104)
	eyebrow:SetText("FIRST TIME SETUP")
	local title = Font(panel, 25, 1, 1, 1, 1)
	title:SetPoint("TOP", eyebrow, "BOTTOM", 0, -6)
	title:SetText("Welcome to EllesmereUI")
	local sub = Font(panel, 14, 1, 1, 1, 0.45)
	sub:SetPoint("TOP", title, "BOTTOM", 0, -8)
	sub:SetWidth(W - 60)
	sub:SetJustifyH("CENTER")
	sub:SetWordWrap(true)
	sub:SetText("Choose which addons you want enabled. You can change any of these later in the EllesmereUI settings panel.")

	-- Check All | Uncheck All
	local function Link(text)
		local b = CreateFrame("Button", nil, panel)
		b:SetFrameLevel(lvl + 2)
		local l = Font(b, 14, 1, 1, 1, 0.45)
		l:SetText(text)
		l:SetPoint("CENTER")
		b:SetSize(l:GetStringWidth() + 4, 20)
		b:SetScript("OnEnter", function() l:SetTextColor(1, 1, 1, 0.8) end)
		b:SetScript("OnLeave", function() l:SetTextColor(1, 1, 1, 0.45) end)
		return b
	end
	local checkAll = Link("Check All")
	checkAll:SetPoint("TOPLEFT", panel, "TOPLEFT", CONTENT_LEFT, -196)
	local divider = Tex(panel, "OVERLAY", 1, 1, 1, 0.18)
	divider:SetSize(1, 12)
	divider:SetPoint("LEFT", checkAll, "RIGHT", 10, 0)
	local uncheckAll = Link("Uncheck All")
	uncheckAll:SetPoint("LEFT", checkAll, "RIGHT", 20, 0)

	local rows = {}
	local function Visual(row)
		row.check:SetShown(row.checked)
		if row.checked then
			row.border:SetColor(EG.r, EG.g, EG.b, CB_ACT_BRD_A)
		else
			row.border:SetColor(1, 1, 1, CB_BRD_A)
		end
	end
	for c, group in ipairs(groups) do
		local col = CreateFrame("Frame", nil, panel)
		col:SetFrameLevel(lvl + 1)
		col:SetSize(COL_W, H - CONTENT_TOP - 80)
		col:SetPoint("TOPLEFT", panel, "TOPLEFT", CONTENT_LEFT + (c - 1) * (COL_W + COL_GAP), -CONTENT_TOP)
		local hdr = Font(col, 18, EG.r, EG.g, EG.b, 0.9)
		hdr:SetPoint("TOPLEFT", 4, -4)
		hdr:SetText(group.header)
		local y = HEADER_H + HEADER_PAD
		for _, entry in ipairs(group.entries) do
			local row = CreateFrame("Button", nil, col)
			row:SetSize(COL_W, ROW_H)
			row:SetPoint("TOPLEFT", col, "TOPLEFT", 0, -y)
			local box = CreateFrame("Frame", nil, row)
			box:SetSize(BOX_SZ, BOX_SZ)
			box:SetPoint("LEFT", row, "LEFT", 8, 0)
			box:SetFrameLevel(row:GetFrameLevel() + 1)
			Tex(box, "BACKGROUND", CB_BOX[1], CB_BOX[2], CB_BOX[3], 1):SetAllPoints()
			row.border = ns.MakeBorder(box, 1, 1, 1, CB_BRD_A)
			row.check = Tex(box, "ARTWORK", EG.r, EG.g, EG.b, 1)
			row.check:SetPoint("TOPLEFT", CHECK_INSET, -CHECK_INSET)
			row.check:SetPoint("BOTTOMRIGHT", -CHECK_INSET, CHECK_INSET)
			row.label = Font(row, 17, 1, 1, 1, 0.65)
			row.label:SetPoint("LEFT", box, "RIGHT", 8, 0)
			row.label:SetText(entry.label)
			row.addon = entry.addon
			row.checked = IsEnabled(entry.addon)
			Visual(row)
			row:SetScript("OnClick", function(self)
				self.checked = not self.checked
				Visual(self)
			end)
			row:SetScript("OnEnter", function(self) self.label:SetTextColor(1, 1, 1, 0.9) end)
			row:SetScript("OnLeave", function(self) self.label:SetTextColor(1, 1, 1, 0.65) end)
			rows[#rows + 1] = row
			y = y + ROW_H
		end
	end
	checkAll:SetScript("OnClick", function()
		for _, row in ipairs(rows) do
			row.checked = true
			Visual(row)
		end
	end)
	uncheckAll:SetScript("OnClick", function()
		for _, row in ipairs(rows) do
			row.checked = false
			Visual(row)
		end
	end)

	-- Writes the choices (they take effect on the next reload) and closes.
	local function Commit()
		for _, row in ipairs(rows) do
			if row.checked then
				EnableAddOn(row.addon)
			else
				DisableAddOn(row.addon)
			end
		end
		DB().firstInstallPopupShown = true
		dimmer:Hide()
	end

	local function Button(text, green)
		local b = CreateFrame("Button", nil, panel)
		b:SetFrameLevel(lvl + 2)
		b:SetSize(200, 39)
		Tex(b, "BACKGROUND", 0.077, 0.068, 0.058, 0.92):SetAllPoints()
		local r, g, bl = 1, 1, 1
		if green then
			r, g, bl = EG.r, EG.g, EG.b
		end
		local base = green and 0.9 or 0.5
		local brd = ns.MakeBorder(b, r, g, bl, base)
		local l = Font(b, 16, r, g, bl, base)
		l:SetPoint("CENTER")
		l:SetText(text)
		b:SetScript("OnEnter", function(self)
			l:SetTextColor(r, g, bl, 1)
			brd:SetColor(r, g, bl, 1)
			if self.tooltip and ns.ShowWidgetTooltip then
				ns.ShowWidgetTooltip(self, self.tooltip)
			end
		end)
		b:SetScript("OnLeave", function()
			l:SetTextColor(r, g, bl, base)
			brd:SetColor(r, g, bl, base)
			if ns.HideWidgetTooltip then
				ns.HideWidgetTooltip()
			end
		end)
		return b
	end

	local import = Button("Import Profile", false)
	import:SetPoint("BOTTOMRIGHT", panel, "BOTTOM", -8, 38)
	import.tooltip = "Paste a profile string (from Mists or retail EllesmereUI). Your addon choices above are kept and apply with the reload after the import."
	import:SetScript("OnClick", function()
		if ns.HideWidgetTooltip then
			ns.HideWidgetTooltip()
		end
		Commit()
		if ns.LoadOptions() and ns.OpenProfileImport then
			ns.OpenProfileImport()
		end
	end)

	local done = Button("Reload UI", true)
	done:SetPoint("BOTTOMLEFT", panel, "BOTTOM", 8, 38)
	done:SetScript("OnClick", function()
		Commit()
		ReloadUI()
	end)

	dimmer:Hide()
end

-- Opens the popup (also `/eui setup` and the Profiles page). Not in combat:
-- it ends in a reload.
function ns.ShowFirstInstall()
	if InCombatLockdown() then
		ns.Print("First time setup cannot open in combat.")
		return
	end
	if ns.Hide and ns._mainFrame and ns._mainFrame:IsShown() then
		ns:Hide()
	end
	if popup then
		-- Rebuild so the checkboxes show the current enable state.
		popup:Hide()
		popup:SetParent(nil)
		popup = nil
	end
	Build()
	popup:Show()
end

-- First login of a new install only: EllesmereUIDB was empty when the core
-- loaded (ns._freshInstall, set in EllesmereUI.lua). Anyone else is stamped
-- so it never shows by itself.
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_LOGIN")
	local db = DB()
	if db.firstInstallPopupShown then
		return
	end
	if not ns._freshInstall then
		db.firstInstallPopupShown = true
		return
	end
	local wait = 0.5
	self:SetScript("OnUpdate", function(f, elapsed)
		wait = wait - elapsed
		if wait > 0 then
			return
		end
		f:SetScript("OnUpdate", nil)
		if not DB().firstInstallPopupShown and not InCombatLockdown() then
			ns.ShowFirstInstall()
		end
	end)
end)
