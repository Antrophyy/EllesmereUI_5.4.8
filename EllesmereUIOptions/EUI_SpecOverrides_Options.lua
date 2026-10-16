-- Spec Overrides + Conditional Overrides in the settings window (retail
-- EllesmereUI_SpecOverrides.lua UI parts; engine: EllesmereUI\EllesmereUI_SpecOverrides.lua).
--
--   * spec button (class glyph) at the right end of the tab bar: the cards
--     popup (Default Editing Mode, spec groups, + Add New Spec Group,
--     Conditional Overrides, + Add New Conditional Group, View All / Remove
--     Overrides);
--   * "Editing as <group>" banner above the window + override glow; every
--     setting changed in that mode is captured for the group;
--   * 1px gold border (+ "Overridden by" info badge) on overridden settings,
--     red border on settings another group owns for a shared spec;
--   * "Overrides" tab under Profiles (Spec / Conditional list: Go to Setting,
--     Remove Override).
--
-- No edits in EllesmereUIOptions.lua: this file loads right after it and
-- wraps ns.RegisterSettingsModule; the tab builders it wraps hand over the
-- page objects, whose metatable is the Page class (Row, Toggle, ...).
-- Which settings a slot shows is found by probing: a captured value is
-- changed for a moment and the slot's getters are read again.

local ns = EllesmereUI
local SO = ns and ns.SO
if not SO or not ns.RegisterSettingsModule then
	return
end
local Cond = SO.Cond
local Kit = ns.PopupKit
local NIL = SO.NIL
local FS, PS = ns.SPECOV_FS, ns.SPECOV_PS

local MEDIA = ns.MEDIA
local ICON_DIR = MEDIA .. "icons\\overrides\\"
local GLYPH_SPRITE = MEDIA .. "class\\glyph"
local MODERN_SPRITE = MEDIA .. "class\\modern"
local MULTISPEC_ICON = ICON_DIR .. "multispec"
local ROLE_MEDIA = "Interface\\AddOns\\EllesmereUIRaidFrames\\Media\\"
local ROLE_ICONS = {
	TANK = ROLE_MEDIA .. "tank-modern",
	HEALER = ROLE_MEDIA .. "healer-modern",
	DAMAGER = ROLE_MEDIA .. "dps-modern",
}
local ROLE_ORDER = { "TANK", "HEALER", "DAMAGER" }
local COND_ICONS = {
	keybind = "override-keybinds",
	dungeon = "override-dungeons",
	raid = "override-raid",
	arena = "override-arena",
	battleground = "override-horde",
	solo = "override-solo",
}
local CLASS_COORDS = {
	WARRIOR = { 0, 0.125, 0, 0.125 }, MAGE = { 0.125, 0.25, 0, 0.125 },
	ROGUE = { 0.25, 0.375, 0, 0.125 }, DRUID = { 0.375, 0.5, 0, 0.125 },
	HUNTER = { 0, 0.125, 0.125, 0.25 }, SHAMAN = { 0.125, 0.25, 0.125, 0.25 },
	PRIEST = { 0.25, 0.375, 0.125, 0.25 }, WARLOCK = { 0.375, 0.5, 0.125, 0.25 },
	PALADIN = { 0, 0.125, 0.25, 0.375 }, DEATHKNIGHT = { 0.125, 0.25, 0.25, 0.375 },
	MONK = { 0.25, 0.375, 0.25, 0.375 },
}
local CLASS_ORDER = ns.CLASS_TOKEN_ORDER or {
	"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT",
	"SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID",
}

-- Theme color #c7a65a (antique gold) and the "Editing as" orange.
local ACCENT_R, ACCENT_G, ACCENT_B = 199 / 255, 166 / 255, 90 / 255
local EDIT_R, EDIT_G, EDIT_B = 1, 0.72, 0.2
local GOLD_R, GOLD_G, GOLD_B = 199 / 255, 166 / 255, 90 / 255

-- Settings module key -> module folder (EllesmereUIOptions.lua FOLDER_MODULES).
local KEY_FOLDER = {
	unitFrames = "EllesmereUIUnitFrames", actionBars = "EllesmereUIActionBars",
	resourceBars = "EllesmereUIResourceBars", minimap = "EllesmereUIMinimap",
	chat = "EllesmereUIChat", dataBars = "EllesmereUIDataBars",
	damageMeters = "EllesmereUIDamageMeters", interrupts = "EllesmereUIInterruptTracker",
	blizzardSkins = "EllesmereUIBlizzardSkin", cdm = "EllesmereUICooldownManager",
	auraBuff = "EllesmereUIAuraBuffReminders", friends = "EllesmereUIFriends",
	quickdraw = "EllesmereUIQuickdraw", raidFrames = "EllesmereUIRaidFrames",
	qol = "EllesmereUIQoL", nameplates = "EllesmereUINameplates", topBar = "EllesmereUITopBar",
	bags = "EllesmereUIBags", questTracker = "EllesmereUIQuestTracker",
	EllesmereUIMythicTimer = "EllesmereUIMythicTimer", reforge = "EllesmereUIReforge",
}
local MODULE_TITLES = {}

-- Pages outside the override systems (spell / spec coupled systems).
local EXCLUDED_PAGES = {
	EllesmereUICooldownManager = { ["Bar Glows"] = true, ["Tracking Bars"] = true },
	EllesmereUIRaidFrames = { ["HoverCast"] = true, ["Click Casting"] = true, ["Click Cast"] = true },
	EllesmereUIUnitFrames = { ["Player Aura Bars"] = true },
}

local function Solid(parent, layer, r, g, b, a)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND")
	t:SetTexture(r, g, b, a)
	return t
end

local function Text(parent, size, r, g, b, a)
	return Kit.Text(parent, size, r, g, b, a)
end

local function ShowTip(owner, text)
	Kit.ShowTip(owner, text)
end

local function HideTip()
	Kit.HideTip()
end

---------------------------------------------------------------------------
-- Pages and slots
---------------------------------------------------------------------------
local pages = {}        -- every real page built (weak)
setmetatable(pages, { __mode = "k" })
local lastCell          -- slot the mouse was last over (capture attribution)
local storeVersion = 1
local walkDirty = true

local function AddGetter(cell, fn)
	if cell and type(fn) == "function" then
		cell._soGets = cell._soGets or {}
		cell._soGets[#cell._soGets + 1] = fn
	end
end

local wrapped = false
local function InstallPageWraps(Page)
	if wrapped then
		return
	end
	wrapped = true
	local origRow = Page.Row
	Page.Row = function(self, label, ...)
		local cell = origRow(self, label, ...)
		if cell and self._soCells and label and label ~= "" then
			cell._soMeta = {
				key = self._soModule,
				folder = KEY_FOLDER[self._soModule],
				page = self._soTab,
				section = self.section,
				label = label,
			}
			self._soCells[#self._soCells + 1] = cell
			local origHover = cell.SetHover
			cell.SetHover = function(c, on)
				if on then
					lastCell = c
				end
				return origHover(c, on)
			end
		end
		return cell
	end
	local function After(name, getterArg)
		local orig = Page[name]
		if not orig then
			return
		end
		Page[name] = function(self, ...)
			local r1, r2 = orig(self, ...)
			local get = getterArg(...)
			if get then
				AddGetter(self.lastCell, get)
			end
			return r1, r2
		end
	end
	After("Toggle", function(_, _, get) return get end)
	After("Slider", function(_, _, _, _, _, get) return get end)
	After("Dropdown", function(_, _, _, get) return get end)
	After("ColorRow", function(_, _, get) return get end)
	After("Swatch", function(_, get) return get end)
	After("Color", function(_, _, colorKey)
		if type(colorKey) == "table" and type(colorKey.get) == "function" then
			return colorKey.get
		elseif type(colorKey) == "function" then
			return function()
				local c = colorKey()
				if type(c) ~= "table" then
					return c
				end
				return c.r or c[1], c.g or c[2], c.b or c[3], c.a or c[4]
			end
		end
	end)
	local function Multi(getItems, isChecked)
		if type(getItems) ~= "function" or type(isChecked) ~= "function" then
			return nil
		end
		return function()
			local parts = {}
			for _, item in ipairs(getItems() or {}) do
				if type(item) == "table" and item.value ~= nil then
					parts[#parts + 1] = tostring(isChecked(item.value))
				end
			end
			return table.concat(parts, ",")
		end
	end
	After("MultiSelect", function(_, _, getItems, isChecked) return Multi(getItems, isChecked) end)
	After("LaneSelect", function(_, _, getItems, isChecked) return Multi(getItems, isChecked) end)
	local origCog = Page.Cog
	if origCog then
		Page.Cog = function(self, title, rows, ...)
			local r = origCog(self, title, rows, ...)
			for _, def in ipairs(rows or {}) do
				if type(def) == "table" and type(def.get) == "function" then
					AddGetter(self.lastCell, def.get)
				end
			end
			return r
		end
	end
end

-- Sees every tab builder; real pages carry the Page class as metatable.
local overridesTab
local origRegister = ns.RegisterSettingsModule
ns.RegisterSettingsModule = function(def)
	if type(def) == "table" then
		MODULE_TITLES[def.key or ""] = def.name
		for _, tab in ipairs(def.tabs or {}) do
			local origBuild = tab.build
			if type(origBuild) == "function" and tab ~= overridesTab then
				tab.build = function(p, ...)
					local mt = getmetatable(p)
					if type(mt) == "table" and rawget(mt, "Row") then
						InstallPageWraps(mt)
						p._soModule = def.key
						p._soTab = tab.name
						p._soCells = {}
						pages[p] = true
						walkDirty = true
					end
					return origBuild(p, ...)
				end
			end
		end
		if def.key == "profiles" and overridesTab then
			local has = false
			for _, tab in ipairs(def.tabs or {}) do
				if tab == overridesTab then
					has = true
				end
			end
			if not has then
				def.tabs[#def.tabs + 1] = overridesTab
			end
		end
	end
	return origRegister(def)
end

local function CurrentPage()
	local w = _G.EllesmereUISettings
	if not w or not w:IsShown() then
		return nil
	end
	for p in pairs(pages) do
		if p.scroll and p.scroll:IsShown() then
			return p
		end
	end
	return nil
end

local function PageExcluded(folder, tabName)
	if not folder or not SO.ELIGIBLE[folder] then
		return true
	end
	local ex = EXCLUDED_PAGES[folder]
	return ex and tabName and ex[tabName] or false
end

-- All return values of a slot's getters as one string.
local function Signature(cell)
	local parts = {}
	for _, fn in ipairs(cell._soGets or {}) do
		local res = { pcall(fn) }
		if not res[1] then
			parts[#parts + 1] = "!"
		else
			for i = 2, 5 do
				parts[#parts + 1] = tostring(res[i])
			end
		end
	end
	return table.concat(parts, "|")
end

local function ProbeValue(cur)
	local t = type(cur)
	if t == "number" then
		return cur + 7.25
	elseif t == "boolean" then
		return not cur
	elseif t == "string" then
		return cur .. "\1"
	elseif cur == nil then
		return 7.25
	end
	return nil
end

-- fkeys (of the given list) the slot reads.
local function ProbeCell(cell, fkeys)
	local reads = {}
	if not cell._soGets or #cell._soGets == 0 then
		return reads
	end
	local before = Signature(cell)
	for _, fkey in ipairs(fkeys) do
		local cur = SO.ReadLive(fkey)
		local pv = ProbeValue(cur)
		if pv ~= nil and SO.WriteLive(fkey, pv) then
			local after = Signature(cell)
			SO.WriteLive(fkey, cur)
			if after ~= before then
				reads[fkey] = true
			end
		end
	end
	return reads
end

---------------------------------------------------------------------------
-- Gold / red slot marks
---------------------------------------------------------------------------
local function Border(frame, r, g, b, a, layer)
	local b4 = Kit.Border(frame, r, g, b, a)
	for i = 1, #b4 do
		b4[i]:SetDrawLayer(layer or "OVERLAY")
	end
	return b4
end

local function SetSlotMark(cell, mode, tip)
	if mode == "gold" and not cell._soGold then
		local host = CreateFrame("Frame", nil, cell)
		host:SetAllPoints()
		host:SetFrameLevel(cell:GetFrameLevel() + 8)
		Border(host, GOLD_R, GOLD_G, GOLD_B, 0.9)
		local badge = CreateFrame("Frame", nil, host)
		badge:SetSize(14, 14)
		badge:SetPoint("TOPLEFT", cell, "TOPLEFT", 3, -3)
		badge:EnableMouse(true)
		local ico = badge:CreateTexture(nil, "OVERLAY")
		ico:SetAllPoints()
		ico:SetTexture(ICON_DIR .. "eui-info")
		ico:SetVertexColor(GOLD_R, GOLD_G, GOLD_B, 0.85)
		badge:SetScript("OnEnter", function(self)
			ico:SetVertexColor(GOLD_R, GOLD_G, GOLD_B, 1)
			if cell._soTip then
				ShowTip(self, cell._soTip)
			end
		end)
		badge:SetScript("OnLeave", function()
			ico:SetVertexColor(GOLD_R, GOLD_G, GOLD_B, 0.85)
			HideTip()
		end)
		host.badge = badge
		cell._soGold = host
	end
	if mode == "red" and not cell._soRed then
		local host = CreateFrame("Button", nil, cell)
		host:SetAllPoints()
		host:SetFrameLevel(cell:GetFrameLevel() + 12)
		host:EnableMouse(true)
		Border(host, 0.9, 0.2, 0.2, 0.9)
		Solid(host, "OVERLAY", 0.9, 0.2, 0.2, 0.05):SetAllPoints()
		host:SetScript("OnEnter", function(self)
			ShowTip(self, self.tip)
		end)
		host:SetScript("OnLeave", HideTip)
		cell._soRed = host
	end
	if cell._soGold then
		cell._soGold:SetShown(mode == "gold")
		cell._soTip = (mode == "gold") and tip or nil
		cell._soGold.badge:SetShown(mode == "gold" and tip ~= nil)
	end
	if cell._soRed then
		cell._soRed:SetShown(mode == "red")
		cell._soRed.tip = tip
	end
end

local function GoldWalk(page)
	if not page or not page._soCells then
		return
	end
	local folder = KEY_FOLDER[page._soModule]
	local excluded = PageExcluded(folder, page._soTab)
	local fkeys = {}
	if not excluded then
		local prefix = folder .. FS
		for fkey in pairs(SO.AllFKeys()) do
			if fkey:sub(1, #prefix) == prefix then
				fkeys[#fkeys + 1] = fkey
			end
		end
	end
	for _, cell in ipairs(page._soCells) do
		local mode, tip
		if #fkeys > 0 then
			if cell._soReadsVersion ~= storeVersion then
				cell._soReads = ProbeCell(cell, fkeys)
				cell._soReadsVersion = storeVersion
			end
			if next(cell._soReads) then
				mode, tip = SO.SlotStatus(cell._soReads)
			end
		end
		if mode or cell._soGold or cell._soRed then
			SetSlotMark(cell, mode, tip)
		end
	end
end

---------------------------------------------------------------------------
-- Auto-capture: the first hook of ns.applyHooks diffs the open module's
-- settings against the session snapshot after every change; the last hook
-- absorbs what the modules themselves write while applying.
---------------------------------------------------------------------------
local banner, bannerText, bannerStatus, glow
local SetEditStatus

local function DiffTables(old, new, prefix, out)
	for k, nv in pairs(new) do
		local ov = old[k]
		local path = prefix and (prefix .. PS .. tostring(k)) or tostring(k)
		if type(nv) == "table" and type(ov) == "table" then
			DiffTables(ov, nv, path, out)
		elseif nv ~= ov then
			out[#out + 1] = path
		end
	end
	for k in pairs(old) do
		if new[k] == nil then
			out[#out + 1] = prefix and (prefix .. PS .. tostring(k)) or tostring(k)
		end
	end
end

local function CurrentFolder()
	local page = CurrentPage()
	return page and KEY_FOLDER[page._soModule], page
end

local function Resync(folder)
	if not SO.watchSnap then
		return
	end
	if folder then
		local live = SO.DBFor(folder)
		SO.watchSnap[folder] = live and ns.ProfileDeepCopy(live) or nil
	else
		SO.watchSnap = SO.SnapshotLive()
	end
end

local function CaptureHook()
	if not SO.EditSessionActive() or not SO.watchSnap then
		return
	end
	if SO.applying then
		Resync()
		return
	end
	local folder, page = CurrentFolder()
	if not folder or not SO.ELIGIBLE[folder] then
		return
	end
	local live = SO.DBFor(folder)
	local old = SO.watchSnap[folder]
	if not live or not old then
		Resync(folder)
		return
	end
	local paths = {}
	DiffTables(old, live, nil, paths)
	if #paths == 0 then
		return
	end
	local fkeys = {}
	for i, p in ipairs(paths) do
		fkeys[i] = folder .. FS .. p
	end
	-- Attribution: the slot under the mouse, only when it really reads one
	-- of the changed settings (header pickers and the like never capture).
	local cell = lastCell
	local meta = cell and cell._soMeta
	if meta and meta.folder == folder and not PageExcluded(folder, page._soTab) then
		local reads = ProbeCell(cell, fkeys)
		if next(reads) then
			local crumb = (MODULE_TITLES[meta.key] or folder)
			if meta.page then
				crumb = crumb .. "  >  " .. meta.page
			end
			if meta.section then
				crumb = crumb .. "  >  " .. meta.section:upper()
			end
			local msg, r, g, b = SO.Capture(fkeys, {
				label = meta.label, module = folder, page = meta.page,
				section = meta.section, crumb = crumb,
			})
			if msg and SetEditStatus then
				SetEditStatus(msg, r, g, b)
			end
		end
	end
	-- The snapshot is taken again after the modules applied (tail hook).
end

local function TailHook()
	if SO.EditSessionActive() and SO.watchSnap and not SO.applying then
		Resync((CurrentFolder()))
	end
end

ns.applyHooks = ns.applyHooks or {}
table.insert(ns.applyHooks, 1, function()
	local ok, err = pcall(CaptureHook)
	if not ok then
		geterrorhandler()(err)
	end
end)

---------------------------------------------------------------------------
-- Group icons
---------------------------------------------------------------------------
local function PlayerClass()
	local _, cls = UnitClass("player")
	return cls
end

local function ApplyGroupIcon(tex, icon)
	tex:SetTexCoord(0, 1, 0, 1)
	tex:SetDesaturated(false)
	tex:SetVertexColor(1, 1, 1, 1)
	if icon and icon.kind == "cond" and COND_ICONS[icon.key] then
		tex:SetTexture(ICON_DIR .. COND_ICONS[icon.key])
	elseif icon and icon.kind == "multi" then
		tex:SetTexture(MULTISPEC_ICON)
	elseif icon and icon.kind == "role" and ROLE_ICONS[icon.key] then
		tex:SetTexture(ROLE_ICONS[icon.key])
	elseif icon and icon.kind == "class" and CLASS_COORDS[icon.key] then
		local c = CLASS_COORDS[icon.key]
		tex:SetTexture(MODERN_SPRITE)
		tex:SetTexCoord(c[1], c[2], c[3], c[4])
	else
		tex:SetTexture(GLYPH_SPRITE)
		local c = CLASS_COORDS[PlayerClass() or ""]
		if c then
			tex:SetTexCoord(c[1], c[2], c[3], c[4])
		end
	end
end

---------------------------------------------------------------------------
-- Popup chrome
---------------------------------------------------------------------------
local function SmallButton(parent, w, h, label, r, g, b)
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(w, h)
	Solid(btn, "BACKGROUND", 0.10, 0.10, 0.11, 0.9):SetAllPoints()
	r, g, b = r or 1, g or 1, b or 1
	local accent = r ~= 1 or g ~= 1 or b ~= 1
	local brd = Kit.Border(btn, r, g, b, accent and 0.5 or 0.22)
	local lbl = Text(btn, 12, r, g, b, accent and 1 or 0.7)
	lbl:SetPoint("CENTER")
	lbl:SetText(label)
	btn.label = lbl
	btn.brd = brd
	btn:SetScript("OnEnter", function()
		brd:SetColor(r, g, b, accent and 0.9 or 0.4)
	end)
	btn:SetScript("OnLeave", function()
		brd:SetColor(r, g, b, accent and 0.5 or 0.22)
	end)
	return btn
end

local function PopupFrame(w, h)
	local p = CreateFrame("Frame", nil, UIParent)
	p:SetSize(w, h)
	p:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
	p:SetFrameStrata("FULLSCREEN_DIALOG")
	p:SetFrameLevel(40)
	p:EnableMouse(true)
	p:SetToplevel(true)
	Solid(p, "BACKGROUND", 0.06, 0.06, 0.07, 0.97):SetAllPoints()
	Kit.Border(p, 1, 1, 1, 0.15)
	p:Hide()
	return p
end

-- Name + icon popup (spec groups and conditional groups).
local function BuildNameIconPopup(defs, onCreate)
	local p = PopupFrame(380, 300)
	p._title = Text(p, 14, ACCENT_R, ACCENT_G, ACCENT_B, 1)
	p._title:SetPoint("TOP", p, "TOP", 0, -14)
	local nameLbl = Text(p, 12, 1, 1, 1, 0.6)
	nameLbl:SetPoint("TOPLEFT", p, "TOPLEFT", 20, -44)
	nameLbl:SetText("Name")
	local nameBox = CreateFrame("EditBox", nil, p)
	nameBox:SetSize(340, 26)
	nameBox:SetPoint("TOPLEFT", p, "TOPLEFT", 20, -62)
	nameBox:SetAutoFocus(false)
	nameBox:SetFont(ns.FONT, 13, "")
	nameBox:SetTextColor(1, 1, 1, 1)
	nameBox:SetTextInsets(8, 8, 0, 0)
	nameBox:SetMaxLetters(24)
	Solid(nameBox, "BACKGROUND", 0.10, 0.10, 0.11, 0.9):SetAllPoints()
	Kit.Border(nameBox, 1, 1, 1, 0.12)
	nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	p._nameBox = nameBox
	local iconLbl = Text(p, 12, 1, 1, 1, 0.6)
	iconLbl:SetPoint("TOPLEFT", p, "TOPLEFT", 20, -102)
	iconLbl:SetText("Icon")
	p._iconBtns = {}
	local PER_ROW, SZ, GAP = 8, 34, 8
	for i, def in ipairs(defs) do
		local col = (i - 1) % PER_ROW
		local rowI = math.floor((i - 1) / PER_ROW)
		local b = CreateFrame("Button", nil, p)
		b:SetSize(SZ, SZ)
		b:SetPoint("TOPLEFT", p, "TOPLEFT", 20 + col * (SZ + GAP), -122 - rowI * (SZ + GAP))
		local t = b:CreateTexture(nil, "ARTWORK")
		t:SetAllPoints()
		ApplyGroupIcon(t, def)
		b._brd = Kit.Border(b, 1, 1, 1, 0.10)
		b._def = def
		b:SetScript("OnClick", function(self)
			p._selectedIcon = self._def
			for _, ob in ipairs(p._iconBtns) do
				if ob == self then
					ob._brd:SetColor(ACCENT_R, ACCENT_G, ACCENT_B, 0.9)
				else
					ob._brd:SetColor(1, 1, 1, 0.10)
				end
				ob:SetAlpha(ob == self and 1 or 0.7)
			end
		end)
		b:SetAlpha(0.7)
		p._iconBtns[#p._iconBtns + 1] = b
	end
	local create = SmallButton(p, 110, 28, "Create Group", ACCENT_R, ACCENT_G, ACCENT_B)
	create:SetPoint("BOTTOM", p, "BOTTOM", 44, 14)
	create:SetScript("OnClick", function() onCreate(p) end)
	p._createLbl = create.label
	local cancel = SmallButton(p, 80, 28, "Cancel")
	cancel:SetPoint("RIGHT", create, "LEFT", -8, 0)
	cancel:SetScript("OnClick", function() p:Hide() end)
	return p
end

local function SelectIcon(p, want)
	p._selectedIcon = nil
	for _, ob in ipairs(p._iconBtns) do
		local sel = want and ob._def and ob._def.kind == want.kind and ob._def.key == want.key or false
		if sel then
			p._selectedIcon = ob._def
		end
		ob:SetAlpha(sel and 1 or 0.7)
		if sel then
			ob._brd:SetColor(ACCENT_R, ACCENT_G, ACCENT_B, 0.9)
		else
			ob._brd:SetColor(1, 1, 1, 0.10)
		end
	end
end

---------------------------------------------------------------------------
-- Spec groups: creation and editing
---------------------------------------------------------------------------
local RefreshCardsPopup
local nameIconPopup

local function ShowNameIconPopup(specIDs, editing)
	if not nameIconPopup then
		local defs = { { kind = "multi" } }
		for _, role in ipairs(ROLE_ORDER) do
			defs[#defs + 1] = { kind = "role", key = role }
		end
		for _, cls in ipairs(CLASS_ORDER) do
			defs[#defs + 1] = { kind = "class", key = cls }
		end
		nameIconPopup = BuildNameIconPopup(defs, function(p)
			local g = p._editing
			if g then
				local name = p._nameBox:GetText()
				if name and name ~= "" then
					g.name = name
				end
				if p._selectedIcon then
					g.icon = p._selectedIcon
				end
				p:Hide()
				SO.Notify("store")
				return
			end
			local specs = p._specs
			p:Hide()
			if not specs or #specs == 0 then
				return
			end
			SO.CreateGroup(specs, p._nameBox:GetText(), p._selectedIcon)
		end)
	end
	local p = nameIconPopup
	p._specs = specIDs
	p._editing = editing
	p._title:SetText(editing and format("Edit Group: %s", editing.name or "?") or "New Spec Group")
	p._createLbl:SetText(editing and "Save" or "Create Group")
	p._nameBox:SetText(editing and (editing.name or "") or "")
	SelectIcon(p, editing and editing.icon or nil)
	p:Show()
end

-- Spec picker: the profile system's spec popup (EllesmereUI_Presets.lua).
local function PickSpecs(title, preChecked, onDone)
	if not ns.ShowSpecAssignPopup then
		return
	end
	local set = {}
	for _, id in ipairs(preChecked or {}) do
		set[id] = true
	end
	local dummy = { _specOv = { _specs = set } }
	ns.ShowSpecAssignPopup({
		db = dummy,
		dbKey = "_specOv",
		presetKey = "_specs",
		title = title,
		subtitle = "Select the specs this group edits:",
		buttonText = "Next",
		onCancel = function() end,
		onDone = function(assignments)
			local specs = {}
			for specID, on in pairs(assignments or {}) do
				if on and type(specID) == "number" then
					specs[#specs + 1] = specID
				end
			end
			table.sort(specs)
			onDone(specs)
		end,
	})
end

local cardsPopup

local function StartGroupCreation()
	PickSpecs("New Spec Group", nil, function(specs)
		if #specs > 0 then
			ShowNameIconPopup(specs)
		end
	end)
end

local function EditGroupSpecs(g)
	if cardsPopup then
		cardsPopup:Hide()
	end
	PickSpecs(format("Edit Group: %s", g.name or "?"), g.specs, function(specs)
		SO.SetGroupSpecs(g, specs)
		ShowNameIconPopup(nil, g)
	end)
end

---------------------------------------------------------------------------
-- Conditional groups: condition picker + name / icon
---------------------------------------------------------------------------
local condNamePopup, condPicker

local function GroupTooltip(g)
	local parts = {}
	for _, def in ipairs(ns.CONDITIONS or {}) do
		if g.conds and g.conds[def.id] then
			local line = def.label
			if def.id == "keybind" then
				line = line .. ": " .. (g.key and (GetBindingText and GetBindingText(g.key) or g.key) or "no key set")
			end
			parts[#parts + 1] = line
		end
	end
	return table.concat(parts, "\n")
end

local function ShowCondNamePopup(conds, keyStr, existing)
	if not condNamePopup then
		local defs = {}
		for _, cdef in ipairs(ns.CONDITIONS or {}) do
			if COND_ICONS[cdef.id] then
				defs[#defs + 1] = { kind = "cond", key = cdef.id }
			end
		end
		condNamePopup = BuildNameIconPopup(defs, function(p)
			local c = p._conds
			p:Hide()
			if not c or not next(c) then
				return
			end
			local icon = p._selectedIcon
			if not icon and not p._existing then
				for _, cdef in ipairs(ns.CONDITIONS or {}) do
					if c[cdef.id] and COND_ICONS[cdef.id] then
						icon = { kind = "cond", key = cdef.id }
						break
					end
				end
			end
			local g, isNew = Cond.SaveGroup(p._existing, c, p._key, p._nameBox:GetText(), icon)
			if isNew then
				Cond.EnterEdit(g)
			end
		end)
	end
	local p = condNamePopup
	p._conds = conds
	p._key = keyStr
	p._existing = existing
	p._title:SetText(existing and "Edit Conditional Group" or "New Conditional Group")
	p._createLbl:SetText(existing and "Save" or "Create Group")
	p._nameBox:SetText(existing and (existing.name or "") or "")
	local want = existing and existing.icon
	if not want then
		for _, cdef in ipairs(ns.CONDITIONS or {}) do
			if conds and conds[cdef.id] and COND_ICONS[cdef.id] then
				want = { kind = "cond", key = cdef.id }
				break
			end
		end
	end
	SelectIcon(p, want)
	p:Show()
end

local function ShowCondPicker(existing)
	local p = condPicker
	if not p then
		p = PopupFrame(340, 100)
		p._title = Text(p, 14, ACCENT_R, ACCENT_G, ACCENT_B, 1)
		p._title:SetPoint("TOP", p, "TOP", 0, -14)
		local sub = Text(p, 11, 1, 1, 1, 0.5)
		sub:SetPoint("TOP", p, "TOP", 0, -32)
		sub:SetText("Select the conditions that activate this group:")
		p._rows = {}
		local y = -52
		for _, def in ipairs(ns.CONDITIONS or {}) do
			local row = CreateFrame("Button", nil, p)
			row:SetSize(300, 24)
			row:SetPoint("TOPLEFT", p, "TOPLEFT", 20, y)
			local box = row:CreateTexture(nil, "ARTWORK")
			box:SetSize(14, 14)
			box:SetPoint("LEFT", row, "LEFT", 0, 0)
			box:SetTexture(0.10, 0.10, 0.11, 0.9)
			local check = row:CreateTexture(nil, "OVERLAY")
			check:SetSize(8, 8)
			check:SetPoint("CENTER", box, "CENTER", 0, 0)
			check:SetTexture(ACCENT_R, ACCENT_G, ACCENT_B, 1)
			check:Hide()
			local lbl = Text(row, 12, 1, 1, 1, def.comingSoon and 0.35 or 0.85)
			lbl:SetPoint("LEFT", box, "RIGHT", 8, 0)
			lbl:SetText(def.label .. (def.comingSoon and "  |cff888888Coming Soon|r" or ""))
			row._check = check
			row._condID = def.id
			if def.comingSoon then
				row:SetScript("OnEnter", function(self) ShowTip(self, "This condition is coming in a future update.") end)
				row:SetScript("OnLeave", HideTip)
			else
				row:SetScript("OnClick", function(self)
					p._staged[self._condID] = not p._staged[self._condID] or nil
					self._check:SetShown(p._staged[self._condID] and true or false)
					p._syncKeyRow()
				end)
			end
			p._rows[#p._rows + 1] = row
			y = y - 26
		end
		-- Toggle key row (only while Keybind is checked).
		local keyRow = CreateFrame("Frame", nil, p)
		keyRow:SetSize(300, 26)
		keyRow:SetPoint("TOPLEFT", p, "TOPLEFT", 20, y - 4)
		local keyLbl = Text(keyRow, 12, 1, 1, 1, 0.6)
		keyLbl:SetPoint("LEFT", keyRow, "LEFT", 0, 0)
		keyLbl:SetText("Toggle Key")
		local keyBtn = SmallButton(keyRow, 150, 22, "")
		keyBtn:SetPoint("LEFT", keyLbl, "RIGHT", 12, 0)
		local function ShowKeyText()
			if p._capturing then
				keyBtn.label:SetText("Press a key...")
			elseif p._stagedKey then
				keyBtn.label:SetText(GetBindingText and GetBindingText(p._stagedKey) or p._stagedKey)
			else
				keyBtn.label:SetText("Click to Set Key")
			end
		end
		p._showKeyText = ShowKeyText
		keyBtn:SetScript("OnClick", function()
			p._capturing = not p._capturing
			p:EnableKeyboard(p._capturing and true or false)
			ShowKeyText()
		end)
		p:SetScript("OnKeyDown", function(_, key)
			if not p._capturing then
				return
			end
			if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" then
				return
			end
			p._capturing = false
			p:EnableKeyboard(false)
			if key ~= "ESCAPE" then
				local mods = ""
				if IsAltKeyDown() then
					mods = mods .. "ALT-"
				end
				if IsControlKeyDown() then
					mods = mods .. "CTRL-"
				end
				if IsShiftKeyDown() then
					mods = mods .. "SHIFT-"
				end
				p._stagedKey = mods .. key
			end
			ShowKeyText()
		end)
		local keyClear = CreateFrame("Button", nil, keyRow)
		keyClear:SetSize(20, 20)
		keyClear:SetPoint("LEFT", keyBtn, "RIGHT", 6, 0)
		local kx = Text(keyClear, 13, 1, 1, 1, 0.6)
		kx:SetPoint("CENTER")
		kx:SetText("x")
		keyClear:SetScript("OnEnter", function() kx:SetTextColor(1, 0.4, 0.4, 1) end)
		keyClear:SetScript("OnLeave", function() kx:SetTextColor(1, 1, 1, 0.6) end)
		keyClear:SetScript("OnClick", function()
			p._stagedKey = nil
			ShowKeyText()
		end)
		p._syncKeyRow = function()
			keyRow:SetShown(p._staged.keybind and true or false)
			p:SetHeight(-y + 56 + (p._staged.keybind and 34 or 0))
			ShowKeyText()
		end
		local nextBtn = SmallButton(p, 110, 28, "Next", ACCENT_R, ACCENT_G, ACCENT_B)
		nextBtn:SetPoint("BOTTOM", p, "BOTTOM", 44, 14)
		nextBtn:SetScript("OnClick", function()
			if not next(p._staged) then
				return
			end
			if p._staged.keybind and not p._stagedKey then
				ShowTip(nextBtn, "Set the toggle key first (or uncheck Keybind).")
				return
			end
			local conds = {}
			for k, v in pairs(p._staged) do
				conds[k] = v
			end
			p:Hide()
			ShowCondNamePopup(conds, p._stagedKey, p._editing)
		end)
		local cancel = SmallButton(p, 80, 28, "Cancel")
		cancel:SetPoint("RIGHT", nextBtn, "LEFT", -8, 0)
		cancel:SetScript("OnClick", function()
			p._capturing = false
			p:EnableKeyboard(false)
			p:Hide()
		end)
		condPicker = p
	end
	p._editing = existing
	p._staged = {}
	p._stagedKey = existing and existing.key or nil
	p._capturing = false
	p:EnableKeyboard(false)
	if existing and existing.conds then
		for k, v in pairs(existing.conds) do
			p._staged[k] = v
		end
	end
	for _, row in ipairs(p._rows) do
		row._check:SetShown(p._staged[row._condID] and true or false)
	end
	p._title:SetText(existing and format("Edit Conditional: %s", existing.name or "?") or "New Conditional Group")
	p._syncKeyRow()
	p:Show()
end

---------------------------------------------------------------------------
-- Cards popup
---------------------------------------------------------------------------
local specBtn

local function BuildCardRow(parent, y, opts)
	local row = CreateFrame("Button", nil, parent)
	row:SetSize(parent:GetWidth() - 20, 40)
	row:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)
	local hl = row:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetTexture(1, 1, 1, 0.05)
	local brd = Kit.Border(row, 1, 1, 1, opts.active and 0.8 or 0.08)
	if opts.active then
		brd:SetColor(ACCENT_R, ACCENT_G, ACCENT_B, 0.8)
	end
	local icon = row:CreateTexture(nil, "ARTWORK")
	icon:SetSize(26, 26)
	icon:SetPoint("LEFT", row, "LEFT", 8, 0)
	if opts.iconApply then
		opts.iconApply(icon)
	end
	local name = Text(row, 13, 1, 1, 1, opts.dim and 0.55 or 0.9)
	name:SetPoint("LEFT", icon, "RIGHT", 10, 0)
	name:SetPoint("RIGHT", row, "RIGHT", -50, 0)
	name:SetJustifyH("LEFT")
	name:SetWordWrap(false)
	name:SetText(opts.name)
	if opts.tooltip and opts.tooltip ~= "" then
		row:SetScript("OnEnter", function(self) ShowTip(self, opts.tooltip) end)
		row:SetScript("OnLeave", HideTip)
	end
	row:SetScript("OnClick", opts.onClick)
	local del
	if opts.onDelete then
		del = CreateFrame("Button", nil, row)
		del:SetSize(20, 20)
		del:SetPoint("RIGHT", row, "RIGHT", -6, 0)
		del:SetFrameLevel(row:GetFrameLevel() + 2)
		local xt = del:CreateTexture(nil, "OVERLAY")
		xt:SetTexture(MEDIA .. "ui\\eui-close")
		xt:SetTexCoord(0, 30 / 32, 0, 30 / 32)
		xt:SetSize(13, 13)
		xt:SetPoint("CENTER")
		xt:SetVertexColor(1, 1, 1, 0.75)
		del:SetScript("OnEnter", function(self)
			xt:SetVertexColor(1, 1, 1, 1)
			ShowTip(self, "Delete Override Group")
		end)
		del:SetScript("OnLeave", function()
			xt:SetVertexColor(1, 1, 1, 0.75)
			HideTip()
		end)
		del:SetScript("OnClick", opts.onDelete)
	end
	if opts.onEdit then
		local ed = CreateFrame("Button", nil, row)
		ed:SetSize(16, 16)
		if del then
			ed:SetPoint("RIGHT", del, "LEFT", -2, 0)
		else
			ed:SetPoint("RIGHT", row, "RIGHT", -6, 0)
		end
		ed:SetFrameLevel(row:GetFrameLevel() + 2)
		local ico = ed:CreateTexture(nil, "OVERLAY")
		ico:SetAllPoints()
		ico:SetTexture(ICON_DIR .. "eui-edit")
		ed:SetAlpha(0.75)
		ed:SetScript("OnEnter", function(self)
			self:SetAlpha(1)
			ShowTip(self, "Edit Override Group")
		end)
		ed:SetScript("OnLeave", function(self)
			self:SetAlpha(0.75)
			HideTip()
		end)
		ed:SetScript("OnClick", opts.onEdit)
	end
	return row, 44
end

local function OpenOverridesList()
	if cardsPopup then
		cardsPopup:Hide()
	end
	ns:SelectModule("profiles")
	ns:SelectPage("Overrides")
end

RefreshCardsPopup = function()
	local p = cardsPopup
	if not p or not p:IsShown() then
		return
	end
	for _, r in ipairs(p._rows or {}) do
		r:Hide()
	end
	p._rows = {}
	local y = -40
	local function add(row, h)
		p._rows[#p._rows + 1] = row
		y = y - h
	end
	local editGroup, condEdit = SO.EditGroup(), Cond._edit

	add(BuildCardRow(p, y, {
		name = "Default Editing Mode",
		active = not editGroup and not condEdit,
		iconApply = function(tex) ApplyGroupIcon(tex, nil) end,
		tooltip = "Edit normally: changes apply to your current spec",
		onClick = function()
			SO.ExitGroupEdit()
			Cond.ExitEdit()
			RefreshCardsPopup()
		end,
	}))

	for _, g in ipairs(SO.GetGroups() or {}) do
		local names = {}
		for _, id in ipairs(g.specs or {}) do
			names[#names + 1] = SO.SpecName(id)
		end
		if #names == 0 then
			names[1] = "No specs (edit the group to add some)"
		end
		add(BuildCardRow(p, y, {
			name = g.name or "?",
			active = editGroup == g,
			iconApply = function(tex) ApplyGroupIcon(tex, g.icon) end,
			tooltip = table.concat(names, "\n"),
			onEdit = function() EditGroupSpecs(g) end,
			onClick = function()
				if SO.EditGroup() == g then
					SO.ExitGroupEdit()
				else
					SO.EnterGroupEdit(g)
				end
				RefreshCardsPopup()
			end,
			onDelete = function()
				ns.ShowConfirmPopup({
					title = "Delete Spec Group",
					message = format("Delete the group '%s'? Its captured overrides are removed with it; settings keep their current live values.", g.name or "?"),
					confirmText = "Delete",
					cancelText = "Cancel",
					onConfirm = function()
						SO.DeleteGroup(g)
						RefreshCardsPopup()
					end,
				})
			end,
		}))
	end

	add(BuildCardRow(p, y, {
		name = "+ Add New Spec Group",
		dim = true,
		iconApply = function(tex)
			tex:SetTexture(GLYPH_SPRITE)
			tex:SetTexCoord(0, 0.125, 0, 0.125)
			tex:SetDesaturated(true)
			tex:SetVertexColor(1, 1, 1, 0.25)
		end,
		onClick = function()
			p:Hide()
			StartGroupCreation()
		end,
	}))

	do
		local hdr = CreateFrame("Frame", nil, p)
		hdr:SetSize(p:GetWidth() - 20, 26)
		hdr:SetPoint("TOPLEFT", p, "TOPLEFT", 10, y - 6)
		local hl = Text(hdr, 13, ACCENT_R, ACCENT_G, ACCENT_B, 1)
		hl:SetPoint("BOTTOM", hdr, "BOTTOM", 0, 4)
		hl:SetText("Conditional Overrides")
		local sub = Text(hdr, 12, 0.55, 0.55, 0.55, 1)
		sub:SetPoint("TOP", hl, "BOTTOM", 0, -2)
		sub:SetText("(Spec prio'd for settings conflicts)")
		p._rows[#p._rows + 1] = hdr
		y = y - 52
	end

	for _, g in ipairs(ns.Conditions_GetGroups and ns.Conditions_GetGroups() or {}) do
		add(BuildCardRow(p, y, {
			name = (g.name or "?") .. (g.conds and g.conds.keybind and g.keyOn and "  |cffc7a65aOn|r" or ""),
			active = condEdit == g,
			iconApply = function(tex) ApplyGroupIcon(tex, g.icon) end,
			tooltip = GroupTooltip(g),
			onEdit = function()
				p:Hide()
				ShowCondPicker(g)
			end,
			onClick = function()
				if Cond._edit == g then
					Cond.ExitEdit()
				else
					Cond.EnterEdit(g)
				end
				RefreshCardsPopup()
			end,
			onDelete = function()
				ns.ShowConfirmPopup({
					title = "Delete Conditional Group",
					message = format("Delete the conditional '%s'? Its captured overrides are removed with it.", g.name or "?"),
					confirmText = "Delete",
					cancelText = "Cancel",
					onConfirm = function()
						Cond.DeleteGroup(g)
						RefreshCardsPopup()
					end,
				})
			end,
		}))
	end

	add(BuildCardRow(p, y, {
		name = "+ Add New Conditional Group",
		dim = true,
		iconApply = function(tex)
			tex:SetTexture(ICON_DIR .. COND_ICONS.dungeon)
			tex:SetTexCoord(0, 1, 0, 1)
			tex:SetDesaturated(true)
			tex:SetVertexColor(1, 1, 1, 0.25)
		end,
		onClick = function()
			p:Hide()
			ShowCondPicker(nil)
		end,
	}))

	local link = CreateFrame("Button", nil, p)
	link:SetSize(p:GetWidth() - 20, 22)
	link:SetPoint("TOPLEFT", p, "TOPLEFT", 10, y - 2)
	local ll = Text(link, 12, ACCENT_R, ACCENT_G, ACCENT_B, 0.9)
	ll:SetPoint("CENTER")
	ll:SetText("View All / Remove Overrides")
	link:SetScript("OnEnter", function() ll:SetTextColor(ACCENT_R, ACCENT_G, ACCENT_B, 1) end)
	link:SetScript("OnLeave", function() ll:SetTextColor(ACCENT_R, ACCENT_G, ACCENT_B, 0.9) end)
	link:SetScript("OnClick", function()
		SO.CloseEditSessions()
		OpenOverridesList()
	end)
	p._rows[#p._rows + 1] = link
	y = y - 26
	p:SetHeight(-y + 12)
end

local function ModalOpen()
	local c = _G.EUIConfirmDimmer
	if c and c:IsShown() then
		return true
	end
	for _, f in ipairs({ nameIconPopup, condNamePopup, condPicker }) do
		if f and f:IsShown() then
			return true
		end
	end
	return false
end

local function ToggleCardsPopup(anchor)
	if cardsPopup and cardsPopup:IsShown() then
		cardsPopup:Hide()
		return
	end
	if not cardsPopup then
		local w = _G.EllesmereUISettings or UIParent
		local p = CreateFrame("Frame", nil, w)
		p:Hide()
		p:SetSize(280, 100)
		p:SetFrameStrata("DIALOG")
		p:SetFrameLevel(60)
		p:EnableMouse(true)
		p:SetClampedToScreen(true)
		Solid(p, "BACKGROUND", 0.06, 0.06, 0.07, 0.99):SetAllPoints()
		Kit.Border(p, 1, 1, 1, 0.15)
		local title = Text(p, 13, ACCENT_R, ACCENT_G, ACCENT_B, 1)
		title:SetPoint("TOP", p, "TOP", 0, -12)
		title:SetText("Spec Overrides")
		-- Click anywhere else closes it (5.4.8: no GLOBAL_MOUSE_DOWN).
		local wasDown = true
		p:SetScript("OnUpdate", function(self)
			local down = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
			if down and not wasDown and not ModalOpen() and not self:IsMouseOver()
				and not (specBtn and specBtn:IsMouseOver()) then
				local spec = _G.EUISpecAssignDimmer
				if not (spec and spec:IsShown()) then
					self:Hide()
				end
			end
			wasDown = down
		end)
		p:SetScript("OnShow", function()
			wasDown = true
		end)
		cardsPopup = p
	end
	cardsPopup:ClearAllPoints()
	if anchor then
		cardsPopup:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 4, -8)
	else
		cardsPopup:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
	end
	cardsPopup:Show()
	RefreshCardsPopup()
end
ns.SpecOverrides_ToggleCardsPopup = ToggleCardsPopup

---------------------------------------------------------------------------
-- "Editing as" banner + glow
---------------------------------------------------------------------------
local function EnsureBanner()
	if banner then
		return banner
	end
	local w = _G.EllesmereUISettings
	if not w then
		return nil
	end
	banner = CreateFrame("Frame", nil, w)
	banner:SetSize(680, 44)
	banner:SetPoint("BOTTOM", w, "TOP", 0, 0)
	banner:SetClampedToScreen(true)
	banner:SetFrameStrata("DIALOG")
	banner:SetFrameLevel(20)
	Solid(banner, "BACKGROUND", 0.05, 0.05, 0.06, 0.92):SetAllPoints()
	local line = Solid(banner, "BORDER", EDIT_R, EDIT_G, EDIT_B, 0.7)
	line:SetPoint("BOTTOMLEFT")
	line:SetPoint("BOTTOMRIGHT")
	line:SetHeight(1)
	bannerText = Text(banner, 13, EDIT_R, EDIT_G, EDIT_B, 1)
	bannerText:SetPoint("TOPLEFT", banner, "TOPLEFT", 16, -8)
	bannerStatus = Text(banner, 11, 1, 1, 1, 0.6)
	bannerStatus:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", 16, 7)
	bannerStatus:SetPoint("RIGHT", banner, "RIGHT", -100, 0)
	bannerStatus:SetJustifyH("LEFT")
	bannerStatus:SetWordWrap(false)
	local done = SmallButton(banner, 74, 24, "Done")
	done:SetPoint("RIGHT", banner, "RIGHT", -12, 0)
	done:SetScript("OnEnter", function() done.brd:SetColor(EDIT_R, EDIT_G, EDIT_B, 0.8) end)
	done:SetScript("OnLeave", function() done.brd:SetColor(1, 1, 1, 0.22) end)
	done:SetScript("OnClick", function()
		SO.ExitGroupEdit()
		Cond.ExitEdit()
	end)
	banner:Hide()
	-- Background glow while "Editing as" (under the content).
	glow = CreateFrame("Frame", nil, w)
	glow:SetAllPoints(w)
	glow:SetFrameLevel(w:GetFrameLevel())
	glow:EnableMouse(false)
	local tex = glow:CreateTexture(nil, "BORDER")
	tex:SetAllPoints()
	tex:SetTexture(ICON_DIR .. "eui-glow-override")
	glow:Hide()
	return banner
end

SetEditStatus = function(text, r, g, b)
	if bannerStatus then
		bannerStatus:SetText(text or "")
		bannerStatus:SetTextColor(r or 1, g or 1, b or 0.6, 1)
	end
end

local function UpdateBanner()
	local g = SO.EditGroup() or Cond._edit
	if not g then
		if banner then
			banner:Hide()
			glow:Hide()
		end
		return
	end
	if not EnsureBanner() then
		return
	end
	bannerText:SetText(format("Editing as %s", g.name or "?"))
	if Cond._edit then
		SetEditStatus("Any setting you change now applies only while this conditional is active.", 1, 1, 0.6)
	else
		SetEditStatus("Any setting you change now applies only to this group's specs.", 1, 1, 0.6)
	end
	banner:Show()
	glow:Show()
end

---------------------------------------------------------------------------
-- Spec button at the right end of the tab bar
---------------------------------------------------------------------------
local HEADER_H, TAB_BAR_H = 138, 40
local lastPage

local function UpdateButtonState()
	if not specBtn then
		return
	end
	local page = CurrentPage()
	local key = page and page._soModule
	local folder = key and KEY_FOLDER[key]
	if not page or key == "profiles" or key == "global" or not folder then
		specBtn:Hide()
		return
	end
	specBtn:Show()
	local off = PageExcluded(folder, page._soTab)
	specBtn._off = off
	specBtn:SetAlpha(off and 0.35 or (specBtn:IsMouseOver() and 1 or 0.9))
end

local function EnsureSpecButton()
	local w = _G.EllesmereUISettings
	if specBtn or not w then
		return
	end
	specBtn = CreateFrame("Button", nil, w)
	specBtn:SetSize(26, 26)
	specBtn:SetPoint("TOPRIGHT", w, "TOPRIGHT", -45, -(HEADER_H + (TAB_BAR_H - 26) / 2))
	specBtn:SetFrameLevel(w:GetFrameLevel() + 20)
	local tex = specBtn:CreateTexture(nil, "OVERLAY")
	tex:SetAllPoints()
	tex:SetTexture(GLYPH_SPRITE)
	local c = CLASS_COORDS[PlayerClass() or ""]
	if c then
		tex:SetTexCoord(c[1], c[2], c[3], c[4])
	end
	specBtn:SetAlpha(0.9)
	specBtn:SetScript("OnEnter", function(self)
		if self._off then
			ShowTip(self, "This page is excluded from overrides.")
			return
		end
		self:SetAlpha(1)
		ShowTip(self, "Settings Overrides")
	end)
	specBtn:SetScript("OnLeave", function(self)
		self:SetAlpha(self._off and 0.35 or 0.9)
		HideTip()
	end)
	specBtn:SetScript("OnClick", function(self)
		if self._off then
			return
		end
		HideTip()
		ToggleCardsPopup(self)
	end)
	-- Watches the open page: button state and the gold borders.
	local elapsed = 0
	specBtn:SetScript("OnUpdate", function(_, e)
		elapsed = elapsed + e
		if elapsed < 0.1 then
			return
		end
		elapsed = 0
		local page = CurrentPage()
		if page ~= lastPage then
			lastPage = page
			walkDirty = true
			UpdateButtonState()
			if SO.EditSessionActive() then
				Resync()
			end
		end
		if walkDirty and page then
			walkDirty = false
			local ok, err = pcall(GoldWalk, page)
			if not ok then
				geterrorhandler()(err)
			end
		end
	end)
	-- Settings window open / closed: Default Editing Mode, end of sessions.
	w:HookScript("OnShow", function()
		SO.OnPanelShown()
		walkDirty = true
	end)
	w:HookScript("OnHide", function()
		if cardsPopup then
			cardsPopup:Hide()
		end
		for _, f in ipairs({ nameIconPopup, condNamePopup, condPicker }) do
			if f then
				f:Hide()
			end
		end
		SO.OnPanelHidden()
	end)
	if w:IsShown() then
		SO.OnPanelShown()
	end
	UpdateButtonState()
end

table.insert(SO.listeners, function(what)
	if what == "store" or what == "session" then
		storeVersion = storeVersion + 1
	end
	walkDirty = true
	UpdateBanner()
	UpdateButtonState()
	if RefreshCardsPopup then
		RefreshCardsPopup()
	end
end)

---------------------------------------------------------------------------
-- "Overrides" tab under Profiles
---------------------------------------------------------------------------
local listMode = "spec"
local listRev = 0

local function RebuildList()
	listRev = listRev + 1
	if ns.RebuildSettingsPage then
		ns.RebuildSettingsPage()
	end
end

local function Block(p, h)
	p:CloseRow()
	local f = CreateFrame("Frame", nil, p.child)
	f:SetSize(p:RowWidth(), h)
	f:SetPoint("TOPLEFT", p.child, "TOPLEFT", 45, p.y)
	p.y = p.y - h
	return f
end

local function TitleCase(s)
	return (s:gsub("(%a[%w']*)", function(w)
		return w:sub(1, 1):upper() .. w:sub(2):lower()
	end))
end

local function ModeToggle(p)
	local f = Block(p, 31 + 29)
	local BTN_W, BTN_H = 180, 31
	local wrap = CreateFrame("Frame", nil, f)
	wrap:SetSize(BTN_W * 2, BTN_H)
	wrap:SetPoint("TOP", f, "TOP", 0, -14)
	Kit.Border(wrap, 1, 1, 1, 0.10)
	local ar, ag, ab = Kit.Accent()
	for i, m in ipairs({ { key = "spec", label = "Spec Overrides" }, { key = "cond", label = "Conditional Overrides" } }) do
		local btn = CreateFrame("Button", nil, wrap)
		btn:SetSize(BTN_W, BTN_H)
		btn:SetPoint("LEFT", wrap, "LEFT", (i - 1) * BTN_W, 0)
		local bg = btn:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		local lbl = Text(btn, 13, 1, 1, 1, 1)
		lbl:SetPoint("CENTER")
		lbl:SetText(m.label)
		if listMode == m.key then
			bg:SetTexture(ar, ag, ab, 0.85)
		else
			bg:SetTexture(0.10, 0.10, 0.11, 0.85)
			lbl:SetTextColor(1, 1, 1, 0.55)
			btn:SetScript("OnEnter", function()
				bg:SetTexture(0.16, 0.16, 0.17, 0.9)
				lbl:SetTextColor(1, 1, 1, 0.85)
			end)
			btn:SetScript("OnLeave", function()
				bg:SetTexture(0.10, 0.10, 0.11, 0.85)
				lbl:SetTextColor(1, 1, 1, 0.55)
			end)
			btn:SetScript("OnClick", function()
				listMode = m.key
				RebuildList()
			end)
		end
	end
end

local function Hint(p, text)
	local f = Block(p, 80)
	local fs = Text(f, 13, 1, 1, 1, 0.5)
	fs:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -10)
	fs:SetWidth(f:GetWidth() - 40)
	fs:SetJustifyH("LEFT")
	fs:SetText(text)
end

local function GoToSetting(entry)
	local folder = entry.module
	if not folder then
		for fkey in pairs(entry.values and entry.values.default or {}) do
			folder = SO.SplitFKey(fkey)
			break
		end
	end
	if folder and ns.NavigateToElementSettings then
		ns:NavigateToElementSettings(folder, entry.page, entry.section, nil, entry.slotLabel or entry.label)
	end
end

local function ListRow(p, entry, isCond)
	local row = Block(p, 38)
	local name = Text(row, 13, 1, 1, 1, 0.9)
	name:SetPoint("LEFT", row, "LEFT", 20, 0)
	name:SetText(entry.label or entry.slotLabel or "?")
	local crumb = Text(row, 11, 1, 1, 1, 0.3)
	crumb:SetPoint("LEFT", name, "RIGHT", 10, 0)
	crumb:SetText(entry.crumb and TitleCase(entry.crumb) or "")
	if isCond then
		local owner
		for fkey in pairs(entry.values and entry.values.default or {}) do
			owner = SO.EntryOwning(fkey)
			if owner then
				break
			end
		end
		if owner then
			local og = SO.GroupById(owner.group)
			local warn = Text(row, 11, 1, 0.45, 0.45, 0.85)
			warn:SetPoint("LEFT", crumb, "RIGHT", 10, 0)
			warn:SetText(format("held by '%s'", (og and og.name) or "?"))
			local hit = CreateFrame("Frame", nil, row)
			hit:SetAllPoints(warn)
			hit:EnableMouse(true)
			hit:SetScript("OnEnter", function(self)
				ShowTip(self, "A spec override owns this setting, so this conditional value never applies outside an editing session. Remove the spec override to let it through.")
			end)
			hit:SetScript("OnLeave", HideTip)
		end
	end
	local rm = SmallButton(row, 116, 22, "Remove Override")
	rm:SetPoint("RIGHT", row, "RIGHT", -20, 0)
	rm:SetScript("OnEnter", function() rm.brd:SetColor(1, 0.35, 0.35, 0.8) end)
	rm:SetScript("OnClick", function()
		ns.ShowConfirmPopup({
			title = isCond and "Remove Conditional Override" or "Remove Spec Override",
			message = format("Remove '%s'? The setting keeps its current live value.", entry.label or "?"),
			confirmText = "Remove",
			cancelText = "Cancel",
			onConfirm = function()
				SO.RemoveEntry(entry, isCond)
				RebuildList()
			end,
		})
	end)
	local go = SmallButton(row, 104, 22, "Go to Setting")
	go:SetPoint("RIGHT", rm, "LEFT", -20, 0)
	go:SetScript("OnEnter", function() go.brd:SetColor(ACCENT_R, ACCENT_G, ACCENT_B, 0.8) end)
	go:SetScript("OnClick", function() GoToSetting(entry) end)
end

local function BuildSpecList(p)
	local store = SO.GetStore() or {}
	local groups = SO.GetGroups() or {}
	if #store == 0 then
		p:Section("Spec Overrides")
		Hint(p, "No spec overrides yet. Click the spec glyph next to the module search bar, select or create a spec group, and any setting you change while editing as that group is saved here.")
		return
	end
	-- An entry lists under every group that customizes it.
	local function Customizes(entry, g)
		if entry.group == g.id then
			return true
		end
		local def = entry.values and entry.values.default
		for _, sid in ipairs(g.specs or {}) do
			local m = def and entry.values[sid]
			if type(m) == "table" then
				for fkey, dv in pairs(def) do
					if m[fkey] ~= nil and m[fkey] ~= dv then
						return true
					end
				end
			end
		end
		return false
	end
	local byGroup, ungrouped = {}, {}
	for _, entry in ipairs(store) do
		local listed = false
		for _, g in ipairs(groups) do
			if Customizes(entry, g) then
				byGroup[g.id] = byGroup[g.id] or {}
				table.insert(byGroup[g.id], entry)
				listed = true
			end
		end
		if not listed then
			ungrouped[#ungrouped + 1] = entry
		end
	end
	for _, g in ipairs(groups) do
		local list = byGroup[g.id]
		if list and #list > 0 then
			p:Section(g.name or "?")
			for _, entry in ipairs(list) do
				ListRow(p, entry, false)
			end
		end
	end
	if #ungrouped > 0 then
		p:Section("Ungrouped")
		for _, entry in ipairs(ungrouped) do
			ListRow(p, entry, false)
		end
	end
end

local function BuildCondList(p)
	local store = Cond.GetStore() or {}
	local groups = ns.Conditions_GetGroups and ns.Conditions_GetGroups() or {}
	if #store == 0 and #groups == 0 then
		p:Section("Conditional Overrides")
		Hint(p, "No conditional overrides yet. Click the Conditional Overrides button next to the module search bar and create a conditional group (Dungeon, Raid, Keybind...). Spec overrides always take precedence over conditionals.")
		return
	end
	for _, g in ipairs(groups) do
		local list = {}
		for _, entry in ipairs(store) do
			local owns = entry.group == g.id
			local def = entry.values and entry.values.default
			local m = def and entry.values[g.id]
			if not owns and type(m) == "table" then
				for fkey, dv in pairs(def) do
					if m[fkey] ~= nil and m[fkey] ~= dv then
						owns = true
						break
					end
				end
			end
			if owns then
				list[#list + 1] = entry
			end
		end
		if #list > 0 then
			p:Section(g.name or "?")
			for _, entry in ipairs(list) do
				ListRow(p, entry, true)
			end
		end
	end
end

overridesTab = {
	key = "overrides",
	name = "Overrides",
	description = "Every spec and conditional override of this profile: go to the setting or remove the override.",
	pageKey = function() return listMode .. ":" .. listRev end,
	build = function(p)
		if type(getmetatable(p)) ~= "table" or not rawget(getmetatable(p), "Row") then
			-- Search index pass: titles only.
			p:Section("Spec Overrides")
			p:Section("Conditional Overrides")
			return
		end
		Cond.PruneRedundant()
		SO.PruneRedundantValues()
		ModeToggle(p)
		if listMode == "cond" then
			BuildCondList(p)
		else
			BuildSpecList(p)
		end
	end,
}
ns.SpecOverridesPage = overridesTab

---------------------------------------------------------------------------
-- Hooks that need the window (built on first open)
---------------------------------------------------------------------------
table.insert(ns.applyHooks, function()
	local ok, err = pcall(TailHook)
	if not ok then
		geterrorhandler()(err)
	end
end)

-- Test hooks (offline harness).
SO.UI = {
	CurrentPage = CurrentPage,
	GoldWalk = GoldWalk,
	ToggleCardsPopup = ToggleCardsPopup,
	SetLastCell = function(cell) lastCell = cell end,
	SpecButton = function() return specBtn end,
	EnsureSpecButton = function() EnsureSpecButton() end,
}

-- The window is created when it first opens; the first page build happens
-- inside that, so the button and window hooks attach on the next frame.
local waiter = CreateFrame("Frame")
waiter:SetScript("OnUpdate", function(self)
	if _G.EllesmereUISettings then
		self:SetScript("OnUpdate", nil)
		EnsureSpecButton()
	end
end)
