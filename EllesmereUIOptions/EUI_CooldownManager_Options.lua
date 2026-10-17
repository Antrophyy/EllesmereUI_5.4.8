-- Settings of Cooldown Manager (retail EUI_CooldownManager_Options.lua and
-- CooldownManager_Options\*.lua: pages "CDM Bars", "Bar Glows" and
-- "Tracking Bars"; same section headers, labels and keys, built with this
-- window's Page API). Part of EllesmereUIOptions (load on demand); skipped
-- when EllesmereUICooldownManager is not loaded. Setters only store: the
-- runtime's ns.applyHooks entry rebuilds the bars.
--
-- Layout: the content header holds the bar picker (+ add / rename / delete)
-- and the live preview of the selected bar (retail LivePreview_Options.lua):
-- click an icon for its per-spell menu, drag to reorder, middle-click to
-- remove, "+" opens the add-spell picker. The live bars also show every
-- tracked entry while the window is open.
--
-- 5.4.8 differences: no Blizzard / Classic style flags, no Rotation Assist
-- (no C_AssistedCombat), no FocusKick bar (focus nameplate kick tracker),
-- no textured borders / icon masks (Custom Icon Shape = None / Cropped),
-- no swipe colours (5.4.8 cooldown frames cannot tint the swipe), no talent
-- conditions, no RPT sync.

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUICooldownManager") then
	return
end
local CDM = ns.CDM
if not CDM then
	return
end

local floor, max, min = math.floor, math.max, math.min
local format = string.format
local U = ns.OptionsUtil
local FONT_FALLBACK = "Fonts\\ARIALN.TTF"

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
local selBar = "cooldowns"
local selTBB = 1
local selTBBGroup = nil   -- Tracking Bars: a group selected with "Edit Group"
local rev = 0

local function Rebuild()
	rev = rev + 1
	if ns.RebuildSettingsPage then
		ns.RebuildSettingsPage()
	end
end

local function DB()
	return CDM.DB()
end

local function PortedBars()
	local out = {}
	for _, bd in ipairs(CDM.Bars()) do
		if CDM.IsPortedBar(bd) and bd.key then out[#out + 1] = bd end
	end
	return out
end

-- The selected bar (falls back to the first one).
local function BD()
	local bd = CDM.BarByKey(selBar)
	if bd and CDM.IsPortedBar(bd) then return bd end
	local first = PortedBars()[1]
	if first then selBar = first.key end
	return first or {}
end

local function IsDefaultBar(key)
	return key == "cooldowns" or key == "utility" or key == "buffs"
end

---------------------------------------------------------------------------
-- Small widgets for the header (EllesmereUI MakeStyledButton look)
---------------------------------------------------------------------------
local function SetFont(fs, size)
	local path = ns.FONT or (ns.GetFontPath and ns.GetFontPath("cdm")) or FONT_FALLBACK
	fs:SetFont(path, size, "")
	if not fs:GetFont() then fs:SetFont(FONT_FALLBACK, size, "") end
end

local function Text(parent, size, alpha)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	SetFont(fs, size)
	fs:SetTextColor(1, 1, 1, alpha or 1)
	return fs
end

local function Accent()
	if ns.ResolveAccent then
		local r, g, b = ns.ResolveAccent()
		if r then return r, g, b end
	end
	return 12 / 255, 210 / 255, 157 / 255
end

local function FlatButton(parent, w, h, label, onClick, tip)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, h)
	local bg = b:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetTexture(0.061, 0.095, 0.112, 0.9)
	local edges = {}
	for i = 1, 4 do
		edges[i] = b:CreateTexture(nil, "BORDER")
		edges[i]:SetTexture(1, 1, 1, 0.2)
	end
	edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT"); edges[1]:SetHeight(1)
	edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT"); edges[2]:SetHeight(1)
	edges[3]:SetPoint("TOPLEFT"); edges[3]:SetPoint("BOTTOMLEFT"); edges[3]:SetWidth(1)
	edges[4]:SetPoint("TOPRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT"); edges[4]:SetWidth(1)
	local function Edge(r, g, bl, a)
		for i = 1, 4 do edges[i]:SetTexture(r, g, bl, a) end
	end
	b.text = Text(b, 12, 0.75)
	b.text:SetPoint("CENTER")
	b.text:SetText(label)
	b:SetScript("OnEnter", function(self)
		local r, g, bl = Accent()
		Edge(r, g, bl, 0.6)
		self.text:SetTextColor(1, 1, 1, 1)
		if tip then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(tip, 1, 1, 1, 1, true)
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function(self)
		Edge(1, 1, 1, 0.2)
		self.text:SetTextColor(1, 1, 1, 0.75)
		GameTooltip:Hide()
	end)
	b:SetScript("OnClick", onClick)
	return b
end

local function AskNumber(title, message, onNumber)
	ns.ShowInputPopup({
		title = title,
		message = message,
		text = "",
		confirmText = "Add",
		cancelText = "Cancel",
		onConfirm = function(text)
			local id = tonumber(text and strtrim(text) or "")
			if id and id > 0 then
				onNumber(floor(id))
				Rebuild()
			end
		end,
	})
end

---------------------------------------------------------------------------
-- Value lists (retail labels)
---------------------------------------------------------------------------
local function Items(list)
	local out = {}
	for i = 1, #list do out[i] = { value = list[i][1], name = list[i][2] } end
	return out
end
local function LabelOf(list, v, fallback)
	for i = 1, #list do
		if list[i][1] == v then return list[i][2] end
	end
	return fallback or tostring(v)
end

local VIS_LIST = {
	{ "always", "Always" }, { "show_not_dragonriding", "Always (Hide While Skyriding)" },
	{ "in_combat", "In Combat" }, { "out_of_combat", "Out of Combat" },
	{ "in_raid", "In Raid" }, { "in_party", "In Party" }, { "solo", "Solo" },
	{ "mouseover", "Mouseover" }, { "never", "Never" },
}
local GROW_LIST = { { "CENTER", "Centered" }, { "RIGHT", "Grow Right" }, { "LEFT", "Grow Left" }, { "UP", "Grow Up" }, { "DOWN", "Grow Down" } }
local ROWGROW_H = { { "CENTER", "Grow Centered" }, { "DOWN", "Grow Down" }, { "UP", "Grow Up" } }
local ROWGROW_V = { { "CENTER", "Grow Centered" }, { "RIGHT", "Grow Right" }, { "LEFT", "Grow Left" } }
local STRATA_LIST = { { "BACKGROUND", "Background" }, { "LOW", "Low" }, { "MEDIUM", "Medium" }, { "HIGH", "High" }, { "DIALOG", "Dialog" } }
local SHAPE_LIST = { { "none", "None" }, { "cropped", "Cropped" } }
local POS_LIST = {
	{ "center", "Center" }, { "top", "Top" }, { "bottom", "Bottom" }, { "left", "Left" }, { "right", "Right" },
	{ "topleft", "Top Left" }, { "topright", "Top Right" }, { "bottomleft", "Bottom Left" }, { "bottomright", "Bottom Right" },
}
local ALIGN_LIST = { { "left", "Left" }, { "right", "Right" } }
local SIDE_LIST = { { "left", "Left" }, { "right", "Right" }, { "top", "Top" }, { "bottom", "Bottom" } }
local BARTYPE_LIST = { { "cooldowns", "Cooldowns" }, { "utility", "Utility" }, { "buffs", "Buffs" } }
local CDSTATE_LIST = {
	{ false, "None" },
	{ "lowerAlphaOnCD", "Lower Alpha (On CD)" },
	{ "hiddenOnCDShift", "Hidden on CD (Shift Icons)" },
	{ "hiddenReadyShift", "Hidden CD Ready (Shift Icons)" },
	{ "hiddenUnusableShift", "Hidden Until Usable (Shift Icons)" },
	{ "hiddenOnCD", "Hidden (On CD)" },
	{ "hiddenReady", "Hidden (CD Ready)" },
	{ "hiddenUnusable", "Hidden (Until Usable)" },
	{ "pixelGlowReady", "Glow (CD Ready)" },
	{ "glowOnCD", "Glow (On CD)" },
	{ "pixelGlowReadyUsable", "Glow CD Ready (Resource Aware)" },
}
local GLOW_MODE_LIST = { { "default", "Default" }, { "custom", "Custom" } }

-- Glow styles: EllesmereUI.Glows (retail list) when the core has it.
local function GlowItems(withNone)
	-- CDM saved numbering (retail GLOW_ITEMS order): 1 Pixel, 3 Action Button,
	-- 4 Auto-Cast, 2 Shape, 5 GCD, 6 Modern WoW, 7 Classic WoW.
	local out = {}
	if withNone then out[#out + 1] = { value = 0, name = "None" } end
	for _, i in ipairs({ 1, 3, 4, 2, 5, 6, 7 }) do
		out[#out + 1] = { value = i, name = CDM.GLOW_NAMES[i] }
	end
	return out
end
local function GlowLabel(v)
	for _, it in ipairs(GlowItems(true)) do
		if it.value == v then return it.name end
	end
	return v and ("Style " .. tostring(v)) or "None"
end

---------------------------------------------------------------------------
-- Bars: add / rename / delete (retail custom bars "custom_<n>_<id>_<id>")
---------------------------------------------------------------------------
local function AddBar(barType)
	local bars = CDM.Bars()
	local key = format("custom_%d_%d_%03d", #bars + 1, math.random(100000, 999999), math.random(0, 999))
	local name = barType == "buffs" and "Buff Bar" or (barType == "utility" and "Utility Bar" or "Cooldown Bar")
	local bd = CDM.NewBarTemplate(key, name, barType, 36)
	bd.desaturateOnCD = true
	bd.showCharges = true
	bars[#bars + 1] = bd
	selBar = key
	CDM.Apply()
	Rebuild()
end

local function PromptAddBar()
	ns.ShowInputPopup({
		title = "Add Bar",
		message = "Name the new bar. It starts as a cooldown bar; change Bar Type below.",
		text = "",
		confirmText = "Add",
		cancelText = "Cancel",
		onConfirm = function(text)
			AddBar("cooldowns")
			text = text and strtrim(text) or ""
			if text ~= "" then BD().name = text end
			CDM.Apply()
			Rebuild()
		end,
	})
end

local function PromptRename()
	local bd = BD()
	ns.ShowInputPopup({
		title = "Rename Bar",
		message = format("Enter a new name for \"%s\":", bd.name or bd.key),
		text = bd.name or "",
		confirmText = "Rename",
		cancelText = "Cancel",
		onConfirm = function(text)
			text = text and strtrim(text) or ""
			if text ~= "" then bd.name = text end
			CDM.Apply()
			Rebuild()
		end,
	})
end

local function PromptDelete()
	local bd = BD()
	if IsDefaultBar(bd.key) then return end
	ns.ShowConfirmPopup({
		title = "Delete Bar",
		message = format("Delete \"%s\"? Its spells are removed from every spec.", bd.name or bd.key),
		confirmText = "Delete",
		cancelText = "Cancel",
		onConfirm = function()
			local bars = CDM.Bars()
			for i = #bars, 1, -1 do
				if bars[i] == bd then table.remove(bars, i) end
			end
			for _, sp in pairs(CDM.Root().specProfiles) do
				if type(sp) == "table" and type(sp.barSpells) == "table" then sp.barSpells[bd.key] = nil end
			end
			DB().cdmBarPositions[bd.key] = nil
			selBar = "cooldowns"
			CDM.Apply()
			Rebuild()
		end,
	})
end

---------------------------------------------------------------------------
-- Spells of the selected bar (current spec)
---------------------------------------------------------------------------
local function SD()
	return CDM.BarSpellData(BD().key)
end

local function AddEntry(id)
	local list = SD().assignedSpells
	for _, v in ipairs(list) do
		if v == id then return end
	end
	list[#list + 1] = id
	CDM.Apply()
end

local function MoveEntry(i, d)
	local list = SD().assignedSpells
	local j = i + d
	if j < 1 or j > #list then return end
	list[i], list[j] = list[j], list[i]
	CDM.Apply()
end

local function RemoveEntry(i)
	local list = SD().assignedSpells
	if i > #list then return end
	table.remove(list, i)
	CDM.Apply()
end

local function EntryLabel(bd, id, sd)
	local e = CDM.ResolveEntry(bd, id, sd)
	local icon, name, kind
	if e then
		icon, name, kind = e.icon, e.name, e.kind
	elseif type(id) == "number" and id > 0 then
		local n2, _, ic = GetSpellInfo(id)
		name, icon = n2, ic
	end
	local label = (icon and ("|T" .. tostring(icon) .. ":16:16:0:0:64:64:5:59:5:59|t ") or "") .. (name or ("ID " .. tostring(id)))
	if not e then label = "|cff777777" .. label .. "|r" end
	local tip
	if type(id) == "number" and id < 0 and -id <= 19 then
		tip = "Equipment slot " .. (-id) .. " (trinket / on-use item)."
	elseif type(id) == "number" and id < 0 then
		tip = "Item ID " .. (-id) .. (e and e.itemID ~= -id and (" (shown as item " .. e.itemID .. " here)") or "")
	else
		tip = "Spell ID " .. tostring(id)
	end
	if not e then
		tip = tip .. "\n\nHidden: this spell / item does not exist on this client or this character does not know it."
	elseif kind == "timed" then
		tip = tip .. "\n\nShown for " .. tostring(e.duration) .. " s after you cast it."
	end
	return label, tip
end

-- Per-spell settings store (spellSettingsCD / spellSettingsBuff), created on write.
local function SpellStore(bd, id, create)
	local store = CDM.SpellSettingsStore(bd, create)
	if not store then return nil end
	local ss = store[id]
	if not ss and create then
		ss = {}
		store[id] = ss
	end
	return ss
end

---------------------------------------------------------------------------
-- Live preview (retail LivePreview_Options.lua BuildCDMLivePreview) and its
-- menus (retail SpellPicker_Options.lua ShowSpellPicker: the per-spell
-- settings menu with flyout "subnav" rows, and the add-spell picker).
-- The suite's dropdown menu is local to EllesmereUIOptions.lua and has no
-- flyouts, so this file draws its own menus in the same look.
--   left / right click an icon: per-spell menu    middle click: remove
--   drag an icon: reorder                         "+": add-spell picker
---------------------------------------------------------------------------
local LP = {}
ns.CDM_LivePreview = LP   -- test hook
LP.MENU_W = 210
LP.ITEM_H = 26
LP.MAX_ROWS = 16
LP.DRAG_THRESHOLD = 3
LP.dragEndTime = 0

-- Settings table of an entry: spells -> spellSettingsCD / spellSettingsBuff,
-- items / equipment slots -> profile.customActiveStates (retail cas).
function LP.Store(bd, id, create)
	if type(id) == "number" and id < 0 then
		local cas = DB().customActiveStates
		if not cas[id] and create then cas[id] = {} end
		return cas[id]
	end
	return SpellStore(bd, id, create)
end

-- Writes one key; an emptied settings table is dropped (retail SetOwn).
function LP.SetOwn(bd, id, k, v)
	local ss = LP.Store(bd, id, v ~= nil)
	if not ss then return end
	ss[k] = v
	if next(ss) == nil then
		if type(id) == "number" and id < 0 then
			DB().customActiveStates[id] = nil
		else
			local store = CDM.SpellSettingsStore(bd)
			if store then store[id] = nil end
		end
	end
	CDM.Apply()
end

function LP.Get(bd, id, k)
	local ss = LP.Store(bd, id)
	return ss and ss[k]
end

-- Moves entry `from` so it lands before original position `to` (1..n+1).
function LP.MoveTo(list, from, to)
	if from < 1 or from > #list or to < 1 or to > #list + 1 then return false end
	if to == from or to == from + 1 then return false end
	local v = table.remove(list, from)
	if to > from then to = to - 1 end
	table.insert(list, to, v)
	return true
end

---------------------------------------------------------------------------
-- Menu frames (dropdown look: dark box, 1 px border, hover highlight)
---------------------------------------------------------------------------
local function MenuBorder(f, a)
	local e = {}
	for i = 1, 4 do
		e[i] = f:CreateTexture(nil, "BORDER")
		e[i]:SetTexture(1, 1, 1, a)
	end
	e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT"); e[1]:SetHeight(1)
	e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(1)
	e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT"); e[3]:SetWidth(1)
	e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(1)
	return e
end

function LP.CloseMenus()
	if LP.tbbMenu then LP.tbbMenu:Hide() end
	if LP.sound then LP.sound:Hide() end
	if LP.flyout then LP.flyout:Hide() end
	if LP.menu then LP.menu:Hide() end
	if LP.catcher then LP.catcher:Hide() end
end

local function EnsureCatcher()
	if LP.catcher then return LP.catcher end
	local c = CreateFrame("Button", nil, UIParent)
	c:SetAllPoints(UIParent)
	c:SetFrameStrata("FULLSCREEN_DIALOG")
	c:SetFrameLevel(1)
	c:RegisterForClicks("AnyUp")
	c:SetScript("OnClick", LP.CloseMenus)
	c:Hide()
	LP.catcher = c
	return c
end

local function NewMenu(level)
	local m = CreateFrame("Frame", nil, UIParent)
	m:SetFrameStrata("FULLSCREEN_DIALOG")
	m:SetFrameLevel(level) -- keep < 128: 5.4.8 clamps higher levels and the rows end up under the bg
	m:SetClampedToScreen(true)
	m:EnableMouse(true)
	m:EnableMouseWheel(true)
	m:SetSize(LP.MENU_W, 10)
	local bg = m:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetTexture(0.075, 0.113, 0.141, 0.98)
	MenuBorder(m, 0.20)
	m.buttons = {}
	m.offset = 0
	m:SetScript("OnMouseWheel", function(self, delta)
		local maxOff = math.max(0, #(self.rows or {}) - LP.MAX_ROWS)
		self.offset = math.min(maxOff, math.max(0, self.offset - delta * 3))
		LP.Render(self)
	end)
	m:Hide()
	return m
end

local function MenuButton(m, i)
	local b = m.buttons[i]
	if b then return b end
	b = CreateFrame("Button", nil, m)
	b:SetHeight(LP.ITEM_H)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b.hl = b:CreateTexture(nil, "ARTWORK")
	b.hl:SetAllPoints()
	b.hl:SetTexture(1, 1, 1, 0.08)
	b.hl:Hide()
	b.line = b:CreateTexture(nil, "ARTWORK")
	b.line:SetHeight(1)
	b.line:SetPoint("LEFT", 8, 0)
	b.line:SetPoint("RIGHT", -8, 0)
	b.line:SetTexture(1, 1, 1, 0.12)
	b.text = Text(b, 12, 0.85)
	b.text:SetPoint("LEFT", 10, 0)
	b.text:SetJustifyH("LEFT")
	b.text:SetWordWrap(false)
	b.value = Text(b, 11, 0.45)
	b.value:SetPoint("RIGHT", -22, 0)
	b.value:SetJustifyH("RIGHT")
	b.arrow = Text(b, 12, 0.5)
	b.arrow:SetPoint("RIGHT", -8, 0)
	b.arrow:SetText(">")
	b.check = b:CreateTexture(nil, "OVERLAY")
	b.check:SetSize(14, 14)
	b.check:SetPoint("RIGHT", -6, 0)
	b.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
	b:SetScript("OnEnter", function(self)
		local r = self.row
		if not r or r.divider or r.header then return end
		self.hl:Show()
		if r.subnav then LP.OpenFlyout(self, r) elseif m == LP.menu and LP.flyout then LP.flyout:Hide() end
		if r.tip then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(r.tip, 1, 1, 1, 1, true)
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function(self)
		self.hl:Hide()
		GameTooltip:Hide()
	end)
	b:SetScript("OnClick", function(self)
		local r = self.row
		if not r or r.divider or r.header or r.disabled then return end
		if r.subnav then
			LP.OpenFlyout(self, r)
			return
		end
		if r.onClick then r.onClick(r) end
	end)
	m.buttons[i] = b
	return b
end

-- rows: { text, value (string, right side), subnav (row with items/get/set),
-- divider, header, checked, onClick, tip, color = { r, g, b }, disabled }
function LP.Render(m)
	local rows = m.rows or {}
	local n = math.min(#rows, LP.MAX_ROWS)
	local maxOff = math.max(0, #rows - LP.MAX_ROWS)
	if m.offset > maxOff then m.offset = maxOff end
	local y = -1
	for i = 1, LP.MAX_ROWS do
		local b = MenuButton(m, i)
		local r = rows[m.offset + i]
		if r and i <= n then
			b.row = r
			local h = r.divider and 9 or LP.ITEM_H
			b:SetHeight(h)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", m, "TOPLEFT", 1, y)
			b:SetPoint("TOPRIGHT", m, "TOPRIGHT", -1, y)
			y = y - h
			b.line:SetShown(r.divider and true or false)
			b.text:SetShown(not r.divider)
			b.text:SetText(r.text or "")
			local c = r.color
			if r.header then
				b.text:SetTextColor(1, 1, 1, 0.35)
			elseif c then
				b.text:SetTextColor(c[1], c[2], c[3], 1)
			else
				b.text:SetTextColor(1, 1, 1, r.disabled and 0.3 or 0.85)
			end
			local val = r.subnav and r.subnav.label and r.subnav.label() or r.value
			b.value:SetText(val or "")
			b.value:SetShown(val ~= nil and not r.divider)
			b.arrow:SetShown(r.subnav and true or false)
			b.check:SetShown(r.checked and true or false)
			b.text:ClearAllPoints()
			b.text:SetPoint("LEFT", 10, 0)
			b.text:SetPoint("RIGHT", (r.subnav and -90) or (r.checked ~= nil and -24) or -8, 0)
			b:Show()
		else
			b.row = nil
			b:Hide()
		end
	end
	m:SetHeight(-y + 1)
end

local function ShowMenu(m, anchor, rows, point, relPoint, x, y)
	m.rows = rows
	m.offset = 0
	LP.Render(m)
	m:ClearAllPoints()
	m:SetPoint(point or "TOPLEFT", anchor, relPoint or "BOTTOMLEFT", x or 0, y or -2)
	m:Show()
end

-- Flyout of a subnav row: single-select list, the current value checked.
function LP.OpenFlyout(button, row)
	LP.flyout = LP.flyout or NewMenu(40)
	local sn = row.subnav
	local cur = sn.get()
	local rows = {}
	for _, it in ipairs(sn.items()) do
		if it.divider then
			rows[#rows + 1] = { divider = true }
		else
			rows[#rows + 1] = {
				text = it.label, checked = (it.val == cur), tip = it.tip,
				onClick = function()
					sn.set(it.val)
					if it.after then it.after() end
					if LP.flyout then LP.flyout:Hide() end
					if LP.sound and LP.sound:IsShown() then LP.Render(LP.sound) end
					if LP.menu and LP.menu:IsShown() then
						if LP.menu.rebuild then LP.menu.rebuild() else LP.Render(LP.menu) end
					end
				end,
			}
		end
	end
	ShowMenu(LP.flyout, button, rows, "TOPLEFT", "TOPRIGHT", 2, 0)
end

-- Color picker: the suite's retail-style picker (ns.OpenColorPicker), else
-- Blizzard's OpenColorPicker.
function LP.PickColor(r, g, b, set)
	LP.CloseMenus()
	if ns.OpenColorPicker then
		ns.OpenColorPicker(function() return r or 1, g or 1, b or 1, 1 end,
			function(nr, ng, nb) set(nr, ng, nb) end, false)
		return
	end
	if not OpenColorPicker then return end
	OpenColorPicker({
		r = r or 1, g = g or 1, b = b or 1, hasOpacity = false,
		swatchFunc = function()
			local nr, ng, nb = ColorPickerFrame:GetColorRGB()
			set(nr, ng, nb)
		end,
		cancelFunc = function() set(r, g, b) end,
	})
end

---------------------------------------------------------------------------
-- Per-spell menu (retail ShowSpellPicker, removeOnly)
---------------------------------------------------------------------------
local function SoundItems()
	local items = { { val = "none", label = "None" } }
	local LSM = ns.GetLSM and ns.GetLSM()
	if LSM then
		local names = LSM:List("sound") or {}
		for _, n in ipairs(names) do
			if n ~= "None" then
				items[#items + 1] = { val = "sm:" .. n, label = n, after = function() CDM.PlaySoundKey("sm:" .. n) end }
			end
		end
	end
	return items
end

local function GlowFlyItems(defaultLabel)
	local items = {}
	if defaultLabel then items[#items + 1] = { val = nil, label = defaultLabel } end
	items[#items + 1] = { val = 0, label = "None" }
	for _, i in ipairs({ 1, 3, 4, 2, 5, 6, 7 }) do items[#items + 1] = { val = i, label = CDM.GLOW_NAMES[i] } end
	return items
end
local function ActiveGlowItems()
	local items = { { val = nil, label = "None" } }
	for _, i in ipairs({ 1, 3, 4, 2, 5, 6, 7 }) do items[#items + 1] = { val = i, label = CDM.GLOW_NAMES[i] } end
	return items
end

local function Pick(items, v, fallback)
	for _, it in ipairs(items) do
		if it.val == v then return it.label end
	end
	return fallback
end

-- One subnav row bound to a settings key.
function LP.SubRow(bd, id, label, key, itemsFn, opts)
	opts = opts or {}
	return {
		text = label, tip = opts.tip,
		subnav = {
			items = itemsFn,
			get = function()
				local v = LP.Get(bd, id, key)
				if opts.read then v = opts.read(v) end
				return v
			end,
			set = function(v)
				if opts.write then opts.write(v) else LP.SetOwn(bd, id, key, v) end
			end,
			label = function()
				local v = LP.Get(bd, id, key)
				if opts.read then v = opts.read(v) end
				return Pick(itemsFn(), v, opts.fallback or "Default")
			end,
		},
	}
end

-- Glow Effect Color row (Default / Class Color / Custom -> color picker).
function LP.ColorRow(bd, id, label, modeKey, prefix)
	local function items()
		return {
			{ val = nil, label = "Default" },
			{ val = "class", label = "Class Color" },
			{ val = "custom", label = "Custom",
				after = function()
					LP.PickColor(LP.Get(bd, id, prefix .. "R") or 1, LP.Get(bd, id, prefix .. "G") or 1, LP.Get(bd, id, prefix .. "B") or 1,
						function(r, g, b)
							local ss = LP.Store(bd, id, true)
							ss[modeKey] = "custom"
							ss[prefix .. "R"], ss[prefix .. "G"], ss[prefix .. "B"] = r, g, b
							CDM.Apply()
						end)
				end },
		}
	end
	return LP.SubRow(bd, id, label, modeKey, items)
end

-- A checked toggle row bound to a boolean settings key (nil = off).
function LP.ToggleRow(bd, id, label, key, tip)
	local on = LP.Get(bd, id, key) and true or false
	return {
		text = label, tip = tip, checked = on,
		onClick = function()
			LP.SetOwn(bd, id, key, (not (LP.Get(bd, id, key) and true or false)) or nil)
			if LP.menu and LP.menu.rebuild then LP.menu.rebuild() end
		end,
	}
end

-- Asks for a number and writes it to key (empty = cleared).
function LP.NumberRow(bd, id, label, key, prompt, fmt)
	local v = LP.Get(bd, id, key)
	return {
		text = label, value = v and (fmt and fmt(v) or tostring(v)) or "Off",
		onClick = function()
			LP.CloseMenus()
			ns.ShowInputPopup({
				title = label, message = prompt, text = v and tostring(v) or "",
				confirmText = "Save", cancelText = "Cancel",
				onConfirm = function(text)
					local n = tonumber(text and strtrim(text) or "")
					LP.SetOwn(bd, id, key, (n and n > 0) and n or nil)
				end,
			})
		end,
	}
end

-- Copy to / Remove from Other Specs (retail): this entry on the same bar in
-- every other spec of your class, with its settings.
function LP.OtherSpecKeys()
	local cur, out = CDM.SpecKey(), {}
	for i = 1, (GetNumSpecializations and GetNumSpecializations() or 0) do
		local sid = GetSpecializationInfo(i)
		if sid and tostring(sid) ~= cur then out[#out + 1] = tostring(sid) end
	end
	return out
end

function LP.CopyToOtherSpecs(bd, id)
	local storeKey = CDM.IsBuffBar(bd) and "spellSettingsBuff" or "spellSettingsCD"
	local own = CDM.SpecProfile()[storeKey]
	own = own and own[id]
	for _, key in ipairs(LP.OtherSpecKeys()) do
		local list = CDM.BarSpellData(bd.key, key).assignedSpells
		local have = false
		for _, v in ipairs(list) do if v == id then have = true break end end
		if not have then list[#list + 1] = id end
		if own then
			local sp = CDM.SpecProfile(key)
			sp[storeKey] = sp[storeKey] or {}
			sp[storeKey][id] = CDM.DeepCopy(own)
		end
	end
	CDM.Apply()
end

function LP.RemoveFromOtherSpecs(bd, id)
	local storeKey = CDM.IsBuffBar(bd) and "spellSettingsBuff" or "spellSettingsCD"
	for _, key in ipairs(LP.OtherSpecKeys()) do
		local list = CDM.BarSpellData(bd.key, key).assignedSpells
		for i = #list, 1, -1 do
			if list[i] == id then table.remove(list, i) end
		end
		local sp = CDM.SpecProfile(key)
		if sp[storeKey] then sp[storeKey][id] = nil end
	end
	CDM.Apply()
end

-- Threshold rows (retail per-spell Threshold Text).
function LP.ThresholdRows(bd, id, rows)
	rows[#rows + 1] = LP.NumberRow(bd, id, "Threshold Seconds", "thresholdSeconds",
		"At or below this many seconds the timer turns the Threshold Color. Empty turns it off.")
	rows[#rows + 1] = {
		text = "Threshold Color", value = LP.Get(bd, id, "thresholdColorR") and "Custom" or "Red",
		onClick = function()
			LP.PickColor(LP.Get(bd, id, "thresholdColorR") or 1, LP.Get(bd, id, "thresholdColorG") or 0.2, LP.Get(bd, id, "thresholdColorB") or 0.2,
				function(r, g, b)
					local ss = LP.Store(bd, id, true)
					ss.thresholdColorR, ss.thresholdColorG, ss.thresholdColorB = r, g, b
					ss.thresholdColorEnabled = true
					CDM.Apply()
				end)
		end,
	}
	rows[#rows + 1] = LP.ToggleRow(bd, id, "Threshold Decimals", "thresholdDecimals", "Under the threshold the timer shows one decimal.")
end

function LP.SpellMenuRows(bd, idx)
	local sd = CDM.BarSpellData(bd.key)
	local id = sd.assignedSpells[idx]
	local rows = {}
	rows[#rows + 1] = {
		text = "Remove Spell", color = { 1, 0.35, 0.35 },
		onClick = function()
			LP.CloseMenus()
			RemoveEntry(idx)
			Rebuild()
		end,
	}
	if type(id) ~= "number" then return rows end
	rows[#rows + 1] = { divider = true }
	local isBuff = CDM.IsBuffBar(bd) or (id <= -2000000000)
	local isItem = id < 0 and id > -2000000000
	if isBuff then
		rows[#rows + 1] = LP.SubRow(bd, id, "Buff Glow", "buffGlow", function() return GlowFlyItems("Default") end)
		rows[#rows + 1] = LP.ColorRow(bd, id, "Glow Effect Color", "buffGlowColor", "buffGlowColor")
		rows[#rows + 1] = LP.SubRow(bd, id, "Always Show Buff", "alwaysShow", function()
			return { { val = nil, label = "Default" }, { val = "on", label = "Show" }, { val = "off", label = "Hide" }, { val = "missing", label = "Show When Missing" } }
		end)
		rows[#rows + 1] = LP.SubRow(bd, id, "Desaturate Inactive", "desatInactive", function()
			return { { val = nil, label = "Default" }, { val = "on", label = "Desaturate" }, { val = "off", label = "Full Color" } }
		end)
		rows[#rows + 1] = LP.SubRow(bd, id, "Audio on Buff Gain", "buffActiveSoundKey", SoundItems,
			{ read = function(v) return v or "none" end, write = function(v) LP.SetOwn(bd, id, "buffActiveSoundKey", (v ~= "none" and v) or nil) end, fallback = "None" })
		rows[#rows + 1] = LP.SubRow(bd, id, "Audio on Buff Loss", "buffLostSoundKey", SoundItems,
			{ read = function(v) return v or "none" end, write = function(v) LP.SetOwn(bd, id, "buffLostSoundKey", (v ~= "none" and v) or nil) end, fallback = "None" })
		rows[#rows + 1] = LP.SubRow(bd, id, "Reverse Swipe", "reverseSwipe", function()
			return { { val = nil, label = "Off" }, { val = true, label = "Reverse Swipe" } }
		end, { read = function(v) return v and true or nil end, fallback = "Off" })
		-- Stack Text and Glows (retail): Glow at Stacks, Show Stack Text.
		rows[#rows + 1] = { header = true, text = "STACK TEXT AND GLOWS" }
		rows[#rows + 1] = LP.ToggleRow(bd, id, "Glow at Stacks", "buffGlowStackEnabled",
			"Replaces Buff Glow: the icon glows when its stack count matches the comparison, in this buff's Buff Glow style.")
		if LP.Get(bd, id, "buffGlowStackEnabled") then
			rows[#rows + 1] = LP.SubRow(bd, id, "Comparison", "buffGlowStackOperator", function()
				return { { val = "lt", label = "Below (<)" }, { val = "lte", label = "At Most (<=)" }, { val = "eq", label = "Exactly (=)" },
					{ val = nil, label = "At Least (>=)" }, { val = "gt", label = "Above (>)" } }
			end, { fallback = "At Least (>=)" })
			rows[#rows + 1] = LP.NumberRow(bd, id, "Stack Count", "buffGlowStackThreshold", "The stack count to compare against.")
		end
		rows[#rows + 1] = LP.SubRow(bd, id, "Show Stack Text", "showChargeStackText", function()
			return { { val = nil, label = "Default" }, { val = true, label = "Show" }, { val = false, label = "Hide" } }
		end)
		LP.ThresholdRows(bd, id, rows)
		rows[#rows + 1] = { divider = true }
		rows[#rows + 1] = { text = "Copy to Other Specs", tip = "Adds this buff, with its settings, to this bar in your other specs.",
			onClick = function() LP.CloseMenus(); LP.CopyToOtherSpecs(bd, id) end }
		rows[#rows + 1] = { text = "Remove from Other Specs", tip = "Removes this buff and its settings from this bar in your other specs.",
			onClick = function() LP.CloseMenus(); LP.RemoveFromOtherSpecs(bd, id) end }
		return rows
	end
	if not isItem then
		rows[#rows + 1] = LP.SubRow(bd, id, "Proc Glow", "procGlow", function() return GlowFlyItems("Default") end)
		rows[#rows + 1] = LP.SubRow(bd, id, "Active State", "activeSwipeMode", function()
			return { { val = nil, label = "Show Active State" }, { val = "none", label = "Hide Active State" } }
		end, { fallback = "Show Active State",
			tip = "While the spell's own aura is up, the icon shows the aura timer. (5.4.8 cannot colour the swipe.)" })
		rows[#rows + 1] = LP.SubRow(bd, id, "Active State Glow", "activeGlow", ActiveGlowItems, { fallback = "None" })
		rows[#rows + 1] = LP.SubRow(bd, id, "Non Active State", "desatNotActive", function()
			return { { val = nil, label = "None" }, { val = true, label = "Desaturate When Not Active" } }
		end, { read = function(v) return v and true or nil end, fallback = "None" })
	end
	rows[#rows + 1] = LP.SubRow(bd, id, "Cooldown Saturation", "noDesatOnCD", function()
		return { { val = nil, label = "None" }, { val = true, label = "Keep Colored (On CD)" } }
	end, { read = function(v) return v and true or nil end, fallback = "None" })
	local stateItems = function()
		local out = {}
		for _, it in ipairs(CDSTATE_LIST) do
			local v = it[1]
			if v == false then v = nil end
			local entry = { val = v, label = it[2] }
			if v == "lowerAlphaOnCD" then
				entry.after = function()
					LP.CloseMenus()
					ns.ShowInputPopup({
						title = "Lower Alpha (On CD)",
						message = "Opacity in percent while the spell is on cooldown.",
						text = tostring(floor((LP.Get(bd, id, "cdStateLowerAlpha") or 0.5) * 100 + 0.5)),
						confirmText = "Save", cancelText = "Cancel",
						onConfirm = function(text)
							local pct = tonumber(text and strtrim(text) or "")
							if pct then LP.SetOwn(bd, id, "cdStateLowerAlpha", math.max(0, math.min(100, pct)) / 100) end
						end,
					})
				end
			end
			out[#out + 1] = entry
		end
		return out
	end
	rows[#rows + 1] = LP.SubRow(bd, id, "Cooldown State Effect", "cdStateEffect", stateItems,
		{ read = function(v) if v == false then return nil end return v end, fallback = "None" })
	local eff = LP.Get(bd, id, "cdStateEffect")
	if eff == "pixelGlowReady" or eff == "glowOnCD" or eff == "pixelGlowReadyUsable" or eff == "buttonGlowReady" then
		rows[#rows + 1] = LP.SubRow(bd, id, "Glow Style", "cdStateGlowStyle", function()
			local out = {}
			for i = 1, 8 do out[#out + 1] = { val = i, label = CDM.GLOW_NAMES[i] } end
			return out
		end, { read = function(v) if type(v) ~= "number" then return (eff == "glowOnCD") and 8 or 1 end return v end })
	end
	rows[#rows + 1] = LP.SubRow(bd, id, "Cooldown Swipe", "reverseSwipe", function()
		return { { val = nil, label = "Off" }, { val = true, label = "Reverse Swipe" } }
	end, { read = function(v) return v and true or nil end, fallback = "Off" })
	rows[#rows + 1] = LP.SubRow(bd, id, "Audio Effect on CD Ready", "cdReadySoundKey", SoundItems,
		{ read = function(v) return v or "none" end, write = function(v) LP.SetOwn(bd, id, "cdReadySoundKey", (v ~= "none" and v) or nil) end, fallback = "None" })
	rows[#rows + 1] = LP.ColorRow(bd, id, "Glow Effect Color", "glowColor", "glowColor")
	-- Charges / swipe / colouring (retail per-spell options).
	rows[#rows + 1] = { header = true, text = "SWIPE AND CHARGES" }
	rows[#rows + 1] = LP.ToggleRow(bd, id, "Hide CD Swipe", "hideCDSwipe", "No cooldown swipe on this icon.")
	rows[#rows + 1] = LP.ToggleRow(bd, id, "Suppress GCD", "suppressGCD", "No swipe for the global cooldown on this icon.")
	rows[#rows + 1] = LP.ToggleRow(bd, id, "Hide Charge Text", "hideChargeText")
	rows[#rows + 1] = LP.ToggleRow(bd, id, "Hide Swipe (Charges)", "chargeHideSwipe", "No recharge swipe while a charge is banked.")
	rows[#rows + 1] = LP.ToggleRow(bd, id, "Hide Duration (Charges > 0)", "chargeHideCdText", "No recharge timer while a charge is banked.")
	rows[#rows + 1] = LP.ToggleRow(bd, id, "Stay Hidden While Charges Remain", "chargeHideUntilSpent", "The icon only shows once every charge is spent.")
	if not isItem then
		rows[#rows + 1] = LP.ToggleRow(bd, id, "Color Out of Range", "outOfRangeColoring", "Tints this icon red while the target is out of range.")
		rows[#rows + 1] = LP.ToggleRow(bd, id, "Ignore Resource Cost", "noResourceTint", "Keeps the icon in full color while you lack the resource to cast it.")
	end
	LP.ThresholdRows(bd, id, rows)
	if not isItem then
		rows[#rows + 1] = { divider = true }
		rows[#rows + 1] = { text = "Copy to Other Specs", tip = "Adds this spell, with its settings, to this bar in your other specs.",
			onClick = function() LP.CloseMenus(); LP.CopyToOtherSpecs(bd, id) end }
		rows[#rows + 1] = { text = "Remove from Other Specs", tip = "Removes this spell and its settings from this bar in your other specs.",
			onClick = function() LP.CloseMenus(); LP.RemoveFromOtherSpecs(bd, id) end }
	end
	return rows
end

function LP.ShowSpellMenu(anchor, idx)
	local bd = BD()
	if LP.menu and LP.menu:IsShown() and LP.menu.anchor == anchor then
		LP.CloseMenus()
		return
	end
	LP.CloseMenus()
	LP.menu = LP.menu or NewMenu(20)
	LP.menu.anchor = anchor
	EnsureCatcher():Show()
	-- Rows are rebuilt when the Cooldown State changes (Glow Style appears).
	LP.menu.rebuild = function() LP.menu.rows = LP.SpellMenuRows(bd, idx); LP.Render(LP.menu) end
	ShowMenu(LP.menu, anchor, LP.SpellMenuRows(bd, idx))
end

---------------------------------------------------------------------------
-- Add-spell picker (retail "+" slot -> ShowSpellPicker / ShowBuffBarPicker)
---------------------------------------------------------------------------
function LP.PickerRows(bd)
	local sd = CDM.BarSpellData(bd.key)
	local have = {}
	for _, v in ipairs(sd.assignedSpells) do have[v] = true end
	local isBuff = CDM.IsBuffBar(bd)
	local function Add(id)
		LP.CloseMenus()
		AddEntry(id)
		Rebuild()
	end
	local rows = {}
	local list = CDM.SpellbookSpells()
	table.sort(list, function(a, b)
		local ac, bc = a.baseCD > 0, b.baseCD > 0
		if ac ~= bc then return ac end
		if (a.tab > 1) ~= (b.tab > 1) then return a.tab > 1 end
		return a.name < b.name
	end)
	rows[#rows + 1] = { header = true, text = isBuff and "SPELLBOOK (BUFF OF THE SPELL)" or "SPELLBOOK" }
	for _, s in ipairs(list) do
		if not have[s.spellID] then
			rows[#rows + 1] = {
				text = "|T" .. tostring(s.icon) .. ":14:14:0:0:64:64:5:59:5:59|t " .. s.name,
				value = s.baseCD > 0 and format("%ds", s.baseCD) or nil,
				onClick = function() Add(s.spellID) end,
			}
		end
	end
	-- Talents not selected right now: the icon shows once the talent is picked.
	local talents = CDM.UnselectedTalentSpells and CDM.UnselectedTalentSpells() or {}
	local talentRows = {}
	for _, s in ipairs(talents) do
		if not have[s.spellID] then
			talentRows[#talentRows + 1] = {
				text = "|T" .. tostring(s.icon) .. ":14:14:0:0:64:64:5:59:5:59|t " .. s.name,
				value = s.baseCD > 0 and format("%ds", s.baseCD) or nil,
				color = { 0.55, 0.55, 0.55 },
				tip = "Talent not selected. The icon shows on the bar when you select this talent.",
				onClick = function() Add(s.spellID) end,
			}
		end
	end
	if #talentRows > 0 then
		rows[#rows + 1] = { divider = true }
		rows[#rows + 1] = { header = true, text = "TALENTS (NOT SELECTED)" }
		for _, r in ipairs(talentRows) do rows[#rows + 1] = r end
	end
	if not isBuff then
		rows[#rows + 1] = { divider = true }
		rows[#rows + 1] = { header = true, text = "PRESETS" }
		for _, slot in ipairs({ 13, 14 }) do
			if not have[-slot] then
				rows[#rows + 1] = { text = format("Trinket %d (slot %d)", slot - 12, slot), onClick = function() Add(-slot) end }
			end
		end
		local racial = CDM.MyRacial()
		if racial and not have[racial] then
			local n, _, ic = GetSpellInfo(racial)
			rows[#rows + 1] = { text = "|T" .. tostring(ic) .. ":14:14:0:0:64:64:5:59:5:59|t Racial: " .. tostring(n), onClick = function() Add(racial) end }
		end
		for _, pr in ipairs(CDM.ITEM_PRESETS) do
			local iid = pr.itemID or (pr.resolve and pr.resolve())
			if iid and not have[-iid] then
				local ic = GetItemIcon(iid)
				rows[#rows + 1] = { text = (ic and ("|T" .. tostring(ic) .. ":14:14:0:0:64:64:5:59:5:59|t ") or "") .. pr.name, onClick = function() Add(-iid) end }
			end
		end
	end
	rows[#rows + 1] = { divider = true }
	rows[#rows + 1] = { text = "Custom Spell ID", color = { Accent() }, onClick = function()
		LP.CloseMenus()
		AskNumber("Custom Spell ID", isBuff and "Enter the spell ID of the buff to track." or "Enter the spell ID to add to this bar.", function(id) AddEntry(id) end)
	end }
	if not isBuff then
		rows[#rows + 1] = { text = "Custom Item ID", color = { Accent() }, onClick = function()
			LP.CloseMenus()
			AskNumber("Custom Item ID", "Enter the item ID to add to this bar.", function(id) AddEntry(-id) end)
		end }
	end
	rows[#rows + 1] = { text = "Add Class Defaults", color = { Accent() },
		tip = "Adds the default spells of your class for this bar (only spells you know).",
		onClick = function()
			LP.CloseMenus()
			for _, id in ipairs(CDM.DefaultSpellList(isBuff and "buffs" or (bd.barType == "utility" and "utility" or "cooldowns"))) do
				AddEntry(id)
			end
			Rebuild()
		end }
	return rows
end

function LP.ShowPicker(anchor)
	LP.CloseMenus()
	LP.menu = LP.menu or NewMenu(20)
	LP.menu.anchor = anchor
	LP.menu.rebuild = nil
	EnsureCatcher():Show()
	ShowMenu(LP.menu, anchor, LP.PickerRows(BD()))
end

---------------------------------------------------------------------------
-- Preview slots, layout and drag-reorder
---------------------------------------------------------------------------
local function SlotBorder(f, r, g, b, a, size)
	local e = {}
	for i = 1, 4 do
		e[i] = f:CreateTexture(nil, "OVERLAY")
		e[i]:SetTexture(r, g, b, a)
	end
	e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT"); e[1]:SetHeight(size)
	e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(size)
	e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT"); e[3]:SetWidth(size)
	e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(size)
	return e
end
local function ShowEdges(e, on)
	for i = 1, 4 do e[i]:SetShown(on) end
end

local function CursorIn(frame)
	local x, y = GetCursorPosition()
	local s = frame:GetEffectiveScale()
	return x / s, y / s
end

-- Insert position (1..n+1) for a cursor over the preview: the nearest slot,
-- before it when the cursor is on its leading half.
function LP.DropIndex(slots, n, cx, cy, vertical)
	local best, bestD, bestI = nil, nil, nil
	for i = 1, n do
		local s = slots[i]
		local sx, sy = s:GetCenter()
		if sx then
			local d = (sx - cx) * (sx - cx) + (sy - cy) * (sy - cy)
			if not bestD or d < bestD then best, bestD, bestI = s, d, i end
		end
	end
	if not best then return nil end
	local sx, sy = best:GetCenter()
	local after
	if vertical then after = cy < sy else after = cx > sx end
	if best._reversed then after = not after end
	return after and bestI + 1 or bestI
end

function LP.StartDrag(slot)
	LP.dragSlot = slot
	local g = LP.ghost
	if not g then
		g = CreateFrame("Frame", nil, UIParent)
		g:SetFrameStrata("TOOLTIP")
		g.tex = g:CreateTexture(nil, "ARTWORK")
		g.tex:SetAllPoints()
		g:EnableMouse(false)
		LP.ghost = g
	end
	g:SetSize(slot:GetWidth() * slot:GetEffectiveScale() / UIParent:GetEffectiveScale(), slot:GetHeight() * slot:GetEffectiveScale() / UIParent:GetEffectiveScale())
	g.tex:SetTexture(slot.icon:GetTexture())
	g.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	g:SetAlpha(0.8)
	g:Show()
	slot:SetAlpha(0.3)
	if LP.indicator then LP.indicator:Show() end
end

function LP.UpdateDrag()
	local slot = LP.dragSlot
	if not slot then return end
	local x, y = CursorIn(UIParent)
	LP.ghost:ClearAllPoints()
	LP.ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
	local pv = LP.preview
	local cx, cy = CursorIn(slot)
	local to = LP.DropIndex(pv.slots, pv.count, cx, cy, pv.vertical)
	LP.dropTo = to
	local ind = LP.indicator
	if ind and to then
		local ref = pv.slots[math.min(to, pv.count)]
		ind:ClearAllPoints()
		local leading = to <= pv.count
		if ref._reversed then leading = not leading end
		if pv.vertical then
			ind:SetSize(ref:GetWidth(), 2)
			ind:SetPoint(leading and "BOTTOM" or "TOP", ref, leading and "TOP" or "BOTTOM", 0, leading and 1 or -1)
		else
			ind:SetSize(2, ref:GetHeight())
			ind:SetPoint(leading and "RIGHT" or "LEFT", ref, leading and "LEFT" or "RIGHT", leading and -1 or 1, 0)
		end
	end
end

function LP.FinishDrag()
	local slot = LP.dragSlot
	if not slot then return end
	LP.dragSlot = nil
	LP.dragEndTime = GetTime()
	if LP.ghost then LP.ghost:Hide() end
	if LP.indicator then LP.indicator:Hide() end
	slot:SetAlpha(1)
	local to = LP.dropTo
	LP.dropTo = nil
	if to and LP.MoveTo(SD().assignedSpells, slot.idx, to) then
		CDM.Apply()
		Rebuild()
	end
end

local function CreateSlot(parent, i)
	local s = CreateFrame("Button", nil, parent)
	s:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
	s:SetHitRectInsets(-3, -3, -3, -3)
	s.bg = s:CreateTexture(nil, "BACKGROUND")
	s.bg:SetAllPoints()
	s.bg:SetTexture(0.08, 0.08, 0.08, 0.6)
	s.icon = s:CreateTexture(nil, "ARTWORK")
	s.edges = SlotBorder(s, 0, 0, 0, 1, 1)
	s.hl = SlotBorder(s, 12 / 255, 210 / 255, 157 / 255, 1, 2)
	ShowEdges(s.hl, false)
	s.idx = i
	s:SetScript("OnEnter", function(self)
		if LP.dragSlot then return end
		local r, g, b = Accent()
		for k = 1, 4 do self.hl[k]:SetTexture(r, g, b, 1) end
		ShowEdges(self.hl, true)
		if self.tip then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(self.tip, 1, 1, 1, 1, true)
			GameTooltip:AddLine("Click: settings   Middle-click: remove   Drag: reorder", 0.6, 0.6, 0.6, true)
			GameTooltip:Show()
		end
	end)
	s:SetScript("OnLeave", function(self)
		ShowEdges(self.hl, false)
		GameTooltip:Hide()
	end)
	s:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" then return end
		self.downX, self.downY = GetCursorPosition()
		self:SetScript("OnUpdate", function(me)
			if LP.dragSlot then
				LP.UpdateDrag()
				return
			end
			local x, y = GetCursorPosition()
			if math.abs(x - me.downX) + math.abs(y - me.downY) > LP.DRAG_THRESHOLD then
				LP.CloseMenus()
				GameTooltip:Hide()
				LP.StartDrag(me)
				LP.UpdateDrag()
			end
		end)
	end)
	s:SetScript("OnMouseUp", function(self)
		self:SetScript("OnUpdate", nil)
		if LP.dragSlot == self then LP.FinishDrag() end
	end)
	s:SetScript("OnClick", function(self, button)
		if GetTime() - LP.dragEndTime < 0.2 then return end
		if button == "MiddleButton" then
			LP.CloseMenus()
			RemoveEntry(self.idx)
			Rebuild()
			return
		end
		LP.ShowSpellMenu(self, self.idx)
	end)
	return s
end

-- Builds the preview under the bar picker; returns its height.
function LP.Build(host, width, y)
	local bd = BD()
	if not bd.key then return 0 end
	local sd = CDM.BarSpellData(bd.key)
	local list = sd.assignedSpells
	local count = #list
	local PAD = 45
	local availW = width - PAD * 2
	local MAX_H = 200

	local pv = CreateFrame("Frame", nil, host)
	LP.preview = pv
	pv.slots = {}
	pv.count = count
	if not host._lpHooked then
		host._lpHooked = true
		host:HookScript("OnHide", function()
			LP.CloseMenus()
			if LP.dragSlot then LP.FinishDrag() end
		end)
	end

	-- Grid like the live bar (rows, base row count, orientation); the "+"
	-- joins the last row after its last icon. Short rows are centered.
	local iw, ih = CDM.IconDims(bd)
	local sp = math.max(0, bd.spacing or 2)
	local grow = bd.growDirection or "CENTER"
	local vertical = (grow == "UP" or grow == "DOWN" or (grow == "CENTER" and bd.verticalOrientation)) and true or false
	local reverse = grow == "LEFT" or grow == "UP"
	pv.vertical = vertical
	local stride, rows, topCount = 0, 1, 0
	if count > 0 then stride, rows, topCount = CDM.TopRowStride(bd, count) end
	local rowLen = {}
	for r = 0, rows - 1 do
		rowLen[r] = (r == 0) and topCount or math.min(stride, count - topCount - (r - 1) * stride)
	end
	local cols = math.max(stride, rowLen[rows - 1] + 1)
	local cw, ch = iw + sp, ih + sp
	local W = (vertical and rows or cols) * (vertical and cw or cw) - sp
	local H = (vertical and cols or rows) * ch - sp
	if vertical then W = rows * cw - sp end
	local scale = math.min(1, availW / math.max(1, W), (MAX_H - 10) / math.max(1, H))
	pv:SetSize(W, H)
	pv:SetScale(scale)
	pv:SetPoint("TOPLEFT", host, "TOPLEFT", (width - W * scale) / 2 / scale, -y / scale)

	-- Cell (row r, position pos along the row) -> TOPLEFT offset.
	local function Place(frame, r, pos, L)
		local off = (cols - L) / 2
		local along = (off + pos)
		if vertical then
			frame:SetPoint("TOPLEFT", pv, "TOPLEFT", r * cw, -along * ch)
		else
			frame:SetPoint("TOPLEFT", pv, "TOPLEFT", along * cw, -r * ch)
		end
	end

	local idx = 0
	for r = 0, rows - 1 do
		local n = rowLen[r]
		local L = (r == rows - 1) and (n + 1) or n
		for c = 0, n - 1 do
			idx = idx + 1
			local id = list[idx]
			local s = CreateSlot(pv, idx)
			pv.slots[idx] = s
			s:SetSize(iw, ih)
			s._reversed = reverse
			Place(s, r, reverse and (L - 1 - c) or c, L)
			local e = CDM.ResolveEntry(bd, id, sd)
			local tex = e and e.icon
			if not tex and type(id) == "number" and id > 0 then tex = select(3, GetSpellInfo(id)) end
			s.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
			s.icon:ClearAllPoints()
			s.icon:SetPoint("TOPLEFT", 1, -1)
			s.icon:SetPoint("BOTTOMRIGHT", -1, 1)
			local z = CDM.BV(bd, "iconZoom") or 0.08
			if bd.iconShape == "cropped" then
				local t = CDM.CropPercent(bd) / 100
				s.icon:SetTexCoord(z, 1 - z, z + t, 1 - z - t)
			else
				s.icon:SetTexCoord(z, 1 - z, z, 1 - z)
			end
			s.icon:SetDesaturated(not e)
			s:SetAlpha(e and 1 or 0.45)
			local label, tip = EntryLabel(bd, id, sd)
			s.tip = label .. "\n" .. tip
		end
	end
	-- "+" slot (retail add button: accent "+", grey border).
	local add = CreateFrame("Button", nil, pv)
	LP.addButton = add
	add:SetSize(iw, ih)
	do
		local n = rowLen[rows - 1]
		Place(add, rows - 1, reverse and 0 or n, n + 1)
	end
	local abg = add:CreateTexture(nil, "BACKGROUND")
	abg:SetAllPoints()
	abg:SetTexture(0.08, 0.08, 0.08, 0.4)
	add.edges = SlotBorder(add, 0.3, 0.3, 0.3, 0.5, 1)
	add.hl = SlotBorder(add, 12 / 255, 210 / 255, 157 / 255, 1, 2)
	ShowEdges(add.hl, false)
	add.lbl = Text(add, math.max(12, floor(ih * 0.6)), 0.6)
	add.lbl:SetPoint("CENTER", 0, 1)
	add.lbl:SetText("+")
	local ar, ag, ab = Accent()
	add.lbl:SetTextColor(ar, ag, ab, 0.6)
	add:SetScript("OnEnter", function(self)
		local r, g, b = Accent()
		self.lbl:SetTextColor(r, g, b, 1)
		ShowEdges(self.hl, true)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(CDM.IsBuffBar(BD()) and "Add a Buff Spell" or "Add a CD/Utility Spell", 1, 1, 1)
		GameTooltip:Show()
	end)
	add:SetScript("OnLeave", function(self)
		local r, g, b = Accent()
		self.lbl:SetTextColor(r, g, b, 0.6)
		ShowEdges(self.hl, false)
		GameTooltip:Hide()
	end)
	add:SetScript("OnClick", function(self) LP.ShowPicker(self) end)

	-- Drop indicator (accent line).
	local ind = pv:CreateTexture(nil, "OVERLAY")
	ind:SetTexture(ar, ag, ab, 1)
	ind:Hide()
	LP.indicator = ind
	return H * scale + 6
end

---------------------------------------------------------------------------
-- CDM Bars page
---------------------------------------------------------------------------
local function Sync(p, label, keys)
	p:Sync("Apply " .. label .. " to all Bars", function()
		local src = BD()
		for _, b in ipairs(PortedBars()) do
			if b ~= src then
				for _, k in ipairs(keys) do b[k] = CDM.DeepCopy(src[k]) end
			end
		end
		CDM.Apply()
	end, function()
		local src = BD()
		for _, b in ipairs(PortedBars()) do
			for _, k in ipairs(keys) do
				if b[k] ~= src[k] and type(src[k]) ~= "table" then return false end
			end
		end
		return true
	end)
end

local function Get(k) return function() return CDM.BV(BD(), k) end end
local function Set(k) return function(v) BD()[k] = v end end

local function BuildBars(p)
	local bd = BD()
	if not bd.key then
		p:Paragraph("No bars.")
		return
	end
	local isBuff = CDM.IsBuffBar(bd)
	local function off() return bd.enabled == false end

	p:Section("Bar Layout")
	p:Toggle("Enable Bar", "Shows this bar.", function() return bd.enabled ~= false end, function(v) bd.enabled = v end)
	if not IsDefaultBar(bd.key) then
		p:Dropdown("Bar Type", "Cooldowns / Utility bars track spell and item cooldowns, Buffs bars track auras (your buffs and your debuffs on the target).",
			function() return Items(BARTYPE_LIST) end,
			function() return bd.barType end,
			function() return LabelOf(BARTYPE_LIST, bd.barType) end,
			function(v) bd.barType = v end, nil, off)
	else
		p:Blank()
	end
	p:Dropdown("Visibility", "When the bar is shown.",
		function() return Items(VIS_LIST) end,
		function() return bd.barVisibility or "always" end,
		function() return LabelOf(VIS_LIST, bd.barVisibility or "always") end,
		function(v) bd.barVisibility = v end, nil, off)
	Sync(p, "Visibility", { "barVisibility", "visOnlyInstances", "visHideMounted", "visHideNoTarget", "visHideNoEnemy" })
	local VIS_OPTS = {
		{ "visOnlyInstances", "Only in Instances" }, { "visHideMounted", "Hide When Mounted" },
		{ "visHideNoTarget", "Hide Without a Target" }, { "visHideNoEnemy", "Hide Without an Enemy Target" },
	}
	p:MultiSelect("Visibility Options", "Extra rules on top of Visibility.",
		function() return Items(VIS_OPTS) end,
		function(v) return bd[v] == true end,
		function(v) bd[v] = not bd[v] end,
		function()
			local n = 0
			for _, o in ipairs(VIS_OPTS) do if bd[o[1]] then n = n + 1 end end
			return n == 0 and "None" or (n .. " selected")
		end, off)
	p:Slider("Number of Rows", "Rows the icons wrap into.", 1, 6, 1,
		function() return bd.numRows or 1 end,
		function(v)
			bd.numRows = v
			if v ~= 2 then
				bd.topRowCount = nil; bd.customTopRowEnabled = nil
				bd.customTopRowSizeEnabled = nil; bd.topRowSizeOffset = nil
				bd.customBottomRowSizeEnabled = nil; bd.bottomRowSizeOffset = nil
				bd.rowGrowDirection = nil
			end
		end, off)
	local horiz = not ((bd.growDirection == "UP" or bd.growDirection == "DOWN") or ((bd.growDirection or "CENTER") == "CENTER" and bd.verticalOrientation))
	p:Cog("Row Icons", {
		{ type = "toggle", label = "Custom Base Row Count", tip = "Two rows only: how many icons the first row holds.",
			get = function() return bd.customTopRowEnabled == true end, set = function(v) bd.customTopRowEnabled = v or nil end,
			disabled = function() return (bd.numRows or 1) ~= 2 end },
		{ type = "slider", label = "Base Row Count", min = 1, max = 20, step = 1,
			get = function() return bd.topRowCount or 1 end, set = function(v) bd.topRowCount = v end,
			disabled = function() return (bd.numRows or 1) ~= 2 or not bd.customTopRowEnabled end },
		{ type = "toggle", label = "Custom Bottom Row Size",
			get = function() return bd.customBottomRowSizeEnabled == true end, set = function(v) bd.customBottomRowSizeEnabled = v or nil end,
			disabled = function() return (bd.numRows or 1) ~= 2 end },
		{ type = "slider", label = "Bottom Row Size Offset", min = -20, max = 20, step = 1,
			get = function() return bd.bottomRowSizeOffset or 0 end, set = function(v) bd.bottomRowSizeOffset = v end,
			disabled = function() return (bd.numRows or 1) ~= 2 or not bd.customBottomRowSizeEnabled end },
		{ type = "dropdown", label = "Row Growth", items = function() return Items(horiz and ROWGROW_H or ROWGROW_V) end,
			get = function() return bd.rowGrowDirection or "CENTER" end,
			set = function(v) bd.rowGrowDirection = (v ~= "CENTER") and v or nil end,
			labelFn = function() return LabelOf(horiz and ROWGROW_H or ROWGROW_V, bd.rowGrowDirection or "CENTER") end },
	})
	p:Toggle("Bar Background", "A background behind the whole bar.",
		function() return bd.barBgEnabled == true end, function(v) bd.barBgEnabled = v end, off)
	p:Swatch("Bar Background Color",
		function() return bd.barBgR or 0, bd.barBgG or 0, bd.barBgB or 0, bd.barBgA or 0.5 end,
		function(r, g, b, a) bd.barBgR, bd.barBgG, bd.barBgB, bd.barBgA = r, g, b, a end,
		{ alpha = true, disabled = function() return not bd.barBgEnabled end })
	p:Slider("Bar Opacity", nil, 0, 100, 1,
		function() return floor((bd.barOpacity or 1) * 100 + 0.5) end,
		function(v) bd.barOpacity = v / 100 end, off)
	Sync(p, "Bar Opacity", { "barOpacity" })
	p:Toggle("Fade Out of Combat", "Lowers the bar's opacity while you are out of combat.",
		function() return bd.oocFadeEnabled == true end, function(v) bd.oocFadeEnabled = v end, off)
	p:Slider("Out of Combat Opacity", nil, 0, 100, 5,
		function() return floor((bd.oocFadeAlpha or 0.5) * 100 + 0.5) end,
		function(v) bd.oocFadeAlpha = v / 100 end, function() return off() or not bd.oocFadeEnabled end)
	p:Dropdown("Grow Direction", "Which way the bar grows from its saved position.",
		function() return Items(GROW_LIST) end,
		function() return bd.growDirection or "CENTER" end,
		function() return LabelOf(GROW_LIST, bd.growDirection or "CENTER") end,
		function(v) bd.growDirection = v; bd.rowGrowDirection = nil end, nil, off)
	p:Toggle("Vertical Orientation", "Centered bars stack their icons vertically.",
		function() return bd.verticalOrientation == true end, function(v) bd.verticalOrientation = v; bd.rowGrowDirection = nil end, off)
	p:Slider("Icon Size", nil, 12, 80, 1, Get("iconSize"), Set("iconSize"), off)
	Sync(p, "Icon Size", { "iconSize" })
	p:Slider("Icon Spacing", nil, -2, 20, 1, Get("spacing"), Set("spacing"), off)
	Sync(p, "Icon Spacing", { "spacing" })
	-- Max Icons + Overflow To (retail maxIcons / overflowTarget).
	p:Slider("Max Icons (0 = Off)", "Caps the icons on this bar; the rest move to the Overflow To bar (or are not shown).", 0, 20, 1,
		function() return bd.maxIcons or 0 end, function(v) bd.maxIcons = (v > 0) and v or nil end, off)
	local ofList = { { "none", "None" } }
	for _, b in ipairs(PortedBars()) do
		if b ~= bd then ofList[#ofList + 1] = { b.key, "CDM: " .. (b.name or b.key) } end
	end
	p:Dropdown("Overflow To", "The bar that shows the icons past Max Icons.",
		function() return Items(ofList) end,
		function() return bd.overflowTarget or "none" end,
		function() return LabelOf(ofList, bd.overflowTarget or "none", "None") end,
		function(v) bd.overflowTarget = (v ~= "none") and v or nil end, nil,
		function() return off() or not (bd.maxIcons and bd.maxIcons > 0) end)
	p:Dropdown("Bar Strata", nil,
		function() return Items(STRATA_LIST) end, Get("barStrata"),
		function() return LabelOf(STRATA_LIST, CDM.BV(bd, "barStrata")) end, Set("barStrata"), nil, off)
	local anchorList = { { "none", "None" }, { "mouse", "Mouse Cursor" } }
	for _, b in ipairs(PortedBars()) do
		if b ~= bd then anchorList[#anchorList + 1] = { b.key, "CDM: " .. (b.name or b.key) } end
	end
	p:Dropdown("Anchor To", "Attach this bar to another bar (or the cursor). An anchored bar has no mover in Unlock Mode.",
		function() return Items(anchorList) end,
		function() return bd.anchorTo or "none" end,
		function() return LabelOf(anchorList, bd.anchorTo or "none", "None") end,
		function(v) bd.anchorTo = v end, nil, off)
	p:Cog("Anchor", {
		{ type = "dropdown", label = "Anchor Position", items = function() return Items(SIDE_LIST) end,
			get = function() return bd.anchorPosition or "left" end, set = function(v) bd.anchorPosition = v end,
			labelFn = function() return LabelOf(SIDE_LIST, bd.anchorPosition or "left") end },
		{ type = "slider", label = "Offset X", min = -200, max = 200, step = 1,
			get = function() return bd.anchorOffsetX or 0 end, set = function(v) bd.anchorOffsetX = v end },
		{ type = "slider", label = "Offset Y", min = -200, max = 200, step = 1,
			get = function() return bd.anchorOffsetY or 0 end, set = function(v) bd.anchorOffsetY = v end },
	}, { disabled = function() return (bd.anchorTo or "none") == "none" end })

	p:Section("Icon Display")
	p:Slider("Border Size", nil, 0, 4, 1, Get("borderSize"), Set("borderSize"), off)
	p:Swatch("Border Color",
		function() return bd.borderR or 0, bd.borderG or 0, bd.borderB or 0, bd.borderA or 1 end,
		function(r, g, b, a) bd.borderR, bd.borderG, bd.borderB, bd.borderA = r, g, b, a; bd.borderClassColor = false end,
		{ alpha = true })
	p:Toggle("Class Colored Border", nil, function() return bd.borderClassColor == true end, function(v) bd.borderClassColor = v end, off)
	p:ColorRow("Icon Background", nil,
		function() return bd.bgR or 0.08, bd.bgG or 0.08, bd.bgB or 0.08, bd.bgA or 0.6 end,
		function(r, g, b, a) bd.bgR, bd.bgG, bd.bgB, bd.bgA = r, g, b, a end, { alpha = true }, off)
	p:Slider("Icon Zoom", "Crops the icon art edge (%).", 0, 20, 1,
		function() return floor((CDM.BV(bd, "iconZoom") or 0.08) * 100 + 0.5) end,
		function(v) bd.iconZoom = v / 100 end, off)
	p:Dropdown("Custom Icon Shape", "Cropped = wide icons (80 % height).",
		function() return Items(SHAPE_LIST) end,
		function() return bd.iconShape or "none" end,
		function() return LabelOf(SHAPE_LIST, bd.iconShape or "none", "None") end,
		function(v) bd.iconShape = v end, nil, off)
	p:Cog("Cropped Shape", {
		{ type = "slider", label = "Adjust Crop", min = 5, max = 25, step = 1,
			tip = "How much is trimmed from the icon's top and bottom, as a percentage per side. 10% is the classic cropped look.",
			get = function() return CDM.CropPercent(bd) end, set = function(v) bd.iconCropPercent = v end },
	}, { disabled = function() return bd.iconShape ~= "cropped" end })
	Sync(p, "Icon Shape", { "iconShape", "iconZoom", "borderSize", "iconCropPercent" })
	p:Toggle("Show Cooldown Text", nil, function() return bd.showCooldownText ~= false end, function(v) bd.showCooldownText = v end, off)
	p:Slider("Duration Size", nil, 6, 30, 1, Get("cooldownFontSize"), Set("cooldownFontSize"), off)
	p:Cog("Duration Text", {
		{ type = "dropdown", label = "Position", items = function() return Items(POS_LIST) end,
			get = function() return bd.cooldownTextPosition or "center" end, set = function(v) bd.cooldownTextPosition = v end,
			labelFn = function() return LabelOf(POS_LIST, bd.cooldownTextPosition or "center") end },
		{ type = "slider", label = "Offset X", min = -30, max = 30, step = 1, get = function() return bd.cooldownTextX or 0 end, set = function(v) bd.cooldownTextX = v end },
		{ type = "slider", label = "Offset Y", min = -30, max = 30, step = 1, get = function() return bd.cooldownTextY or 0 end, set = function(v) bd.cooldownTextY = v end },
		{ type = "color", label = "Color", get = function() return bd.cooldownTextR or 1, bd.cooldownTextG or 1, bd.cooldownTextB or 1, 1 end,
			set = function(r, g, b) bd.cooldownTextR, bd.cooldownTextG, bd.cooldownTextB = r, g, b end },
	})
	p:Slider("Charge/Stack Size", nil, 6, 30, 1, Get("stackCountSize"), Set("stackCountSize"), off)
	p:Cog("Charges / Stacks", {
		{ type = "toggle", label = "Show Charge/Stack Text", tip = "Show the charge and stack counters on this bar's icons.",
			get = function() return bd.showChargeStackText ~= false end,
			set = function(v) bd.showChargeStackText = (not v) and false or nil end },
		{ type = "dropdown", label = "Position", items = function() return Items(POS_LIST) end,
			get = function() return CDM.BV(bd, "stackCountPosition") end, set = function(v) bd.stackCountPosition = v end,
			labelFn = function() return LabelOf(POS_LIST, CDM.BV(bd, "stackCountPosition")) end },
		{ type = "slider", label = "Offset X", min = -30, max = 30, step = 1, get = function() return bd.stackCountX or 0 end, set = function(v) bd.stackCountX = v end },
		{ type = "slider", label = "Offset Y", min = -30, max = 30, step = 1, get = function() return bd.stackCountY or 0 end, set = function(v) bd.stackCountY = v end },
		{ type = "color", label = "Color", get = function() return bd.stackCountR or 1, bd.stackCountG or 1, bd.stackCountB or 1, 1 end,
			set = function(r, g, b) bd.stackCountR, bd.stackCountG, bd.stackCountB = r, g, b end },
	})
	p:Toggle("Only Show Numbers", "Hide this bar's icons and show only the duration text.",
		function() return bd.onlyShowNumbers == true end, function(v) bd.onlyShowNumbers = v and true or nil end, off)
	p:Toggle("Charges/Stacks Only (No Icon)", "Hide this bar's icon art, cooldown swipe and cooldown text, leaving only the charge or stack count.",
		function() return bd.chargesOnly == true end, function(v) bd.chargesOnly = v and true or nil end, off)
	if isBuff then
		p:Toggle("Keep Buffs in Same Place", "Inactive buffs keep their empty slot, so the other icons do not shift.",
			function() return bd.hidePlaceholderIcon == true end, function(v) bd.hidePlaceholderIcon = v end,
			function() return off() or bd.showInactiveBuffIcons == true end)
		p:Blank()
		p:Toggle("Always Show Buffs", "Shows a greyed placeholder icon for each tracked buff that is not active.",
			function() return bd.showInactiveBuffIcons == true end, function(v) bd.showInactiveBuffIcons = v end, off)
		p:Toggle("Desaturate Inactive Buffs", nil,
			function() return bd.desaturateInactiveBuffs ~= false end, function(v) bd.desaturateInactiveBuffs = v end,
			function() return off() or not bd.showInactiveBuffIcons end)
		p:Toggle("Pandemic Glow", "Glows a buff in its last 30 %.",
			function() return bd.pandemicGlow == true end, function(v) bd.pandemicGlow = v end, off)
		p:Dropdown("Pandemic Glow Style", nil,
			function() return GlowItems(false) end,
			function() local v = bd.pandemicGlowStyle or 1; if v < 1 then v = 1 end return v end,
			function() local v = bd.pandemicGlowStyle or 1; if v < 1 then v = 1 end return GlowLabel(v) end,
			function(v) bd.pandemicGlowStyle = v end, nil, function() return off() or not bd.pandemicGlow end)
		p:Dropdown("Pandemic Glow Color", nil,
			function() return Items(GLOW_MODE_LIST) end,
			function() return bd.pandemicGlowMode or "default" end,
			function() return LabelOf(GLOW_MODE_LIST, bd.pandemicGlowMode or "default") end,
			function(v) bd.pandemicGlowMode = v end, nil, function() return off() or not bd.pandemicGlow end)
		p:Swatch("Pandemic Glow Color",
			function() local c = bd.pandemicGlowColor or {}; return c.r or 1, c.g or 1, c.b or 0, 1 end,
			function(r, g, b) bd.pandemicGlowColor = { r = r, g = g, b = b }; bd.pandemicGlowMode = "custom" end)
		p:Dropdown("Buff Glow", "Glows every active buff of this bar (per-buff glows in the spell cog win).",
			function() return GlowItems(true) end,
			function() return (bd.buffGlowMode == "custom") and (bd.buffGlowType or 0) or 0 end,
			function() return GlowLabel((bd.buffGlowMode == "custom") and (bd.buffGlowType or 0) or 0) end,
			function(v) bd.buffGlowType = v; bd.buffGlowMode = (v and v > 0) and "custom" or "default" end, nil, off)
		p:Swatch("Buff Glow Color",
			function() return bd.buffGlowR or 1, bd.buffGlowG or 1, bd.buffGlowB or 1, 1 end,
			function(r, g, b) bd.buffGlowR, bd.buffGlowG, bd.buffGlowB = r, g, b; bd.buffGlowClassColor = false end)
	else
		p:Toggle("Show Charges", nil, function() return bd.showCharges ~= false end, function(v) bd.showCharges = v end, off)
		p:Toggle("Hide Charge Count at 0", nil, function() return bd.hideZeroChargeText == true end, function(v) bd.hideZeroChargeText = v end, off)
		p:Toggle("Desaturate on Cooldown", nil, function() return bd.desaturateOnCD ~= false end, function(v) bd.desaturateOnCD = v end, off)
		p:Slider("Swipe Opacity", "Darkness of the cooldown swipe.", 0, 100, 5,
			function() return floor((CDM.BV(bd, "swipeAlpha") or 0.7) * 100 + 0.5) end,
			function(v) bd.swipeAlpha = v / 100 end, off)
		p:Toggle("Suppress GCD", "No swipe for the global cooldown.", function() return bd.suppressGCD == true end, function(v) bd.suppressGCD = v end, off)
		p:Toggle("Out of Range Overlay", "Tints spells red while the target is out of range.",
			function() return bd.outOfRangeOverlay == true end, function(v) bd.outOfRangeOverlay = v end, off)
		p:Toggle("Show Item Count", nil, function() return bd.showItemCount ~= false end, function(v) bd.showItemCount = v end, off)
		p:Toggle("Hide Items if Missing", "Items you have none of are hidden.",
			function() return bd.hideItemsIfMissing == true end, function(v) bd.hideItemsIfMissing = v end, off)
		p:Toggle("Show Non-On Use Trinkets", "Trinket slots also show trinkets without a use effect.",
			function() return bd.showPassiveTrinkets ~= false end, function(v) bd.showPassiveTrinkets = v end, off)
		p:Toggle("Mirror Key Presses", "When you press an ability's keybind, its icon on this bar shows a pushed-down look, even while the ability is on cooldown.",
			function() return bd.pressMirror == true end, function(v) bd.pressMirror = v or nil end, off)
		p:Dropdown("Active State", "While the spell's own aura is up the icon shows the aura timer (reverse swipe).",
			function() return Items({ { "blizzard", "Show Active State" }, { "none", "Hide Active State" } }) end,
			function() return bd.activeStateAnim == "none" and "none" or "blizzard" end,
			function() return bd.activeStateAnim == "none" and "Hide Active State" or "Show Active State" end,
			function(v) bd.activeStateAnim = v end, nil, off)
	end
	p:Toggle("Show Keybind", "Shows the key the spell is bound to on your action bars.",
		function() return bd.showKeybind == true end, function(v) bd.showKeybind = v end, off)
	p:Cog("Keybind", {
		{ type = "slider", label = "Size", min = 6, max = 24, step = 1, get = function() return CDM.BV(bd, "keybindSize") end, set = function(v) bd.keybindSize = v end },
		{ type = "dropdown", label = "Align", items = function() return Items(ALIGN_LIST) end,
			get = function() return bd.keybindAlign or "left" end, set = function(v) bd.keybindAlign = v end,
			labelFn = function() return LabelOf(ALIGN_LIST, bd.keybindAlign or "left") end },
		{ type = "slider", label = "Offset X", min = -20, max = 20, step = 1, get = function() return CDM.BV(bd, "keybindOffsetX") end, set = function(v) bd.keybindOffsetX = v end },
		{ type = "slider", label = "Offset Y", min = -20, max = 20, step = 1, get = function() return CDM.BV(bd, "keybindOffsetY") end, set = function(v) bd.keybindOffsetY = v end },
		{ type = "color", label = "Color", alpha = true, get = function() return bd.keybindR or 1, bd.keybindG or 1, bd.keybindB or 1, bd.keybindA or 0.9 end,
			set = function(r, g, b, a) bd.keybindR, bd.keybindG, bd.keybindB, bd.keybindA = r, g, b, a end },
	}, { disabled = function() return not bd.showKeybind end })
	Sync(p, "Keybind", { "showKeybind", "keybindSize", "keybindAlign", "keybindOffsetX", "keybindOffsetY" })
	p:Toggle("Show Tooltip on Hover", nil, function() return bd.showTooltip == true end, function(v) bd.showTooltip = v end, off)

	p:Section("Extras")
	local cb = DB().cdmBars
	p:Toggle("Enable Cooldown Manager", "Turns every CDM bar on or off.",
		function() return cb.enabled ~= false end, function(v) cb.enabled = v end)
	p:Toggle("Show Glows Only in Combat (global)", "Suppresses every CDM glow while out of combat.",
		function() return cb.glowsOnlyInCombat == true end, function(v) cb.glowsOnlyInCombat = v end)
	p:Toggle("Stable Keybinds", "Keybind text stays the same across action bar swaps (stealth, forms, stances).",
		function() return cb.stableKeybinds ~= false end, function(v) cb.stableKeybinds = v; CDM._keysDirty = true end)
	p:Toggle("Hide CDM Tooltips in Combat", "No spell tooltips on CDM icons while you are in combat (NaowhUI Gameplay setting).",
		function() return cb.hideTooltipsInCombat == true end, function(v) cb.hideTooltipsInCombat = v end)
	p:Toggle("Swap Combat Potions When Missing", "When your bags have none of one potion, its icon swaps to track another potion of the same kind you own.",
		function() return cb.swapPotionsWhenMissing == true end, function(v) cb.swapPotionsWhenMissing = v end)
	p:Blank()

	-- Spells are edited in the live preview above (retail: no spell list on the page).
end

local function BarsHeader(page, host, width)
	local y = 16
	local DD_H, ICON, GAP = 30, 30, 6
	local BAR_W, ADD_W = 260, 120
	local total = BAR_W + GAP + ICON + GAP + ICON + 12 + ADD_W
	local x0 = floor((width - total) / 2)
	local label = Text(host, 11, 0.45)
	label:SetText("BAR")
	local dd = page:HeaderDropdown(host, BAR_W, DD_H,
		function()
			local items = {}
			for _, b in ipairs(PortedBars()) do
				local offTxt = b.enabled == false and "  |cff888888(off)|r" or ""
				items[#items + 1] = { value = b.key, name = (b.name or b.key) .. offTxt }
			end
			return items
		end,
		function() return BD().key end,
		function() return BD().name or BD().key or "No bars" end,
		function(v)
			selBar = v
			Rebuild()
		end)
	dd:SetPoint("TOPLEFT", host, "TOPLEFT", x0, -y)
	label:SetPoint("BOTTOMLEFT", dd, "TOPLEFT", 0, 2)
	local custom = not IsDefaultBar(BD().key)
	local rename = page:HeaderIconButton(host, ICON, "Interface\\Buttons\\UI-GuildButton-PublicNote-Up", 16, "Rename", PromptRename)
	rename:SetPoint("LEFT", dd, "RIGHT", GAP, 0)
	local delete = page:HeaderIconButton(host, ICON, ns.MEDIA .. "ui\\eui-close", 16, "Delete", PromptDelete)
	delete:SetPoint("LEFT", rename, "RIGHT", GAP, 0)
	delete:SetAlpha(custom and 1 or 0.3)
	local add = FlatButton(host, ADD_W, DD_H, "+ Add Bar", PromptAddBar, "Create a custom bar.")
	add:SetPoint("LEFT", delete, "RIGHT", 12, 0)
	y = y + DD_H + 14
	-- Live preview of the selected bar (current spec).
	local previewY = y
	y = y + LP.Build(host, width, y)
	local hint = Text(host, 11, 0.4)
	hint:SetPoint("TOP", host, "TOP", 0, -y - 4)
	hint:SetText("Click an icon for its settings, drag to reorder, middle-click to remove.")
	-- Layout settings (rows, size, spacing, growth, shape) change the grid:
	-- redraw the preview when they change. Only the shown page does this,
	-- refreshers of older pages stay registered.
	local function Sig()
		local bd = BD()
		local count = #CDM.BarSpellData(bd.key).assignedSpells
		local iw, ih = CDM.IconDims(bd)
		local stride, rows, top = 0, 1, 0
		if count > 0 then stride, rows, top = CDM.TopRowStride(bd, count) end
		local t = { bd.key, count, iw, ih, bd.spacing or 2, bd.growDirection or "CENTER",
			bd.verticalOrientation, stride, rows, top, bd.iconShape,
			CDM.CropPercent(bd), CDM.BV(bd, "iconZoom") or 0.08 }
		for i = 1, 13 do t[i] = tostring(t[i]) end
		return table.concat(t, ":")
	end
	local sig = Sig()
	page:OnRefresh(function()
		if not host:IsVisible() or LP.dragSlot or not BD().key then return end
		local s = Sig()
		if s == sig then return end
		sig = s
		LP.CloseMenus()
		if LP.preview then
			LP.preview:Hide()
			LP.preview:SetParent(nil)
		end
		local h = previewY + LP.Build(host, width, previewY)
		hint:SetPoint("TOP", host, "TOP", 0, -h - 4)
		page:SetHeaderHeight(h + 24)
	end)
	return y + 24
end

---------------------------------------------------------------------------
-- Tracking Bars page
---------------------------------------------------------------------------
local function TData()
	return CDM.TBB.Data()
end

local function TCfg()
	local t = TData()
	if not t.bars[selTBB] then selTBB = #t.bars end
	return t.bars[selTBB]
end

local function BuildTracking(p)
	if selTBBGroup and LP.TBBBuildGroupPage(p, selTBBGroup) then return end
	local cfg = TCfg()
	if not cfg then
		p:Section("Tracking Bars")
		p:Paragraph("Tracking Bars show one aura (your buff, or your debuff on the target) as a timer bar. Bars are per specialization. Open the dropdown above to add one.")
		return
	end
	local V = CDM.TBB.V
	local function g(k) return function() return V(cfg, k) end end
	local function s(k) return function(v) cfg[k] = v end end
	local function off() return cfg.enabled == false end
	p:Section("Tracking Bars")
	p:Toggle("Enable Bar", nil, function() return cfg.enabled ~= false end, function(v) cfg.enabled = v end)
	p:Button("Tracked Spell", "Spell ID " .. tostring(cfg.spellID) .. ". Click to change it.", "Change Spell", function()
		AskNumber("Tracked Spell", "Enter the spell ID of the buff or debuff to track.", function(id)
			cfg.spellID = id
			cfg.name = GetSpellInfo(id) or cfg.name
		end)
	end)
	p:Toggle("Hide When Inactive", "Hides the bar unless the aura is up.", g("hideWhenInactive"), s("hideWhenInactive"), off)
	p:Toggle("Only In Combat", nil, g("onlyInCombat"), s("onlyInCombat"), off)
	p:Slider("Width", nil, 40, 600, 1, g("width"), s("width"), off)
	p:Slider("Height", nil, 4, 60, 1, g("height"), s("height"), off)
	p:Toggle("Vertical Orientation", nil, g("verticalOrientation"), s("verticalOrientation"), off)
	p:Toggle("Reverse Fill", nil, g("reverseFill"), s("reverseFill"), off)
	p:Dropdown("Texture", nil,
		function()
			local items = { { name = "None", value = "none" } }
			local LSM = ns.GetLSM and ns.GetLSM()
			if LSM then
				local names = LSM:List("statusbar")
				for _, n in ipairs(names or {}) do items[#items + 1] = { name = n, value = "sm:" .. n } end
			end
			return items
		end,
		function() return cfg.texture or "none" end,
		function() local t = cfg.texture or "none"; return t == "none" and "None" or (t:match("^sm:(.+)$") or t) end,
		function(v) cfg.texture = v end, nil, off)
	p:Slider("Border Size", nil, 0, 4, 1, g("borderSize"), s("borderSize"), off)
	p:ColorRow("Fill Color", nil,
		function() return cfg.fillR or 1, cfg.fillG or 1, cfg.fillB or 1, V(cfg, "fillA") end,
		function(r, gg, b, a) cfg.fillR, cfg.fillG, cfg.fillB, cfg.fillA = r, gg, b, a; cfg.fillColorMode = "custom" end, { alpha = true }, off)
	p:ColorRow("Background Color", nil,
		function() return V(cfg, "bgR"), V(cfg, "bgG"), V(cfg, "bgB"), V(cfg, "bgA") end,
		function(r, gg, b, a) cfg.bgR, cfg.bgG, cfg.bgB, cfg.bgA = r, gg, b, a end, { alpha = true }, off)
	p:Toggle("Show Name", nil, function() return cfg.showName ~= false and cfg.namePosition ~= "none" end,
		function(v) cfg.showName = v; if v and cfg.namePosition == "none" then cfg.namePosition = "left" end end, off)
	p:Slider("Name Size", nil, 6, 24, 1, g("nameSize"), s("nameSize"), off)
	p:Toggle("Show Timer", nil, function() return cfg.showTimer ~= false and cfg.timerPosition ~= "none" end,
		function(v) cfg.showTimer = v; if v and cfg.timerPosition == "none" then cfg.timerPosition = "right" end end, off)
	p:Slider("Timer Size", nil, 6, 24, 1, g("timerSize"), s("timerSize"), off)
	p:Dropdown("Icon", nil,
		function() return Items({ { "none", "None" }, { "left", "Left" }, { "right", "Right" } }) end,
		function() return cfg.iconDisplay or "none" end,
		function() return LabelOf({ { "none", "None" }, { "left", "Left" }, { "right", "Right" } }, cfg.iconDisplay or "none") end,
		function(v) cfg.iconDisplay = v end, nil, off)
	p:Slider("Stacks Size", nil, 6, 24, 1, g("stacksSize"), s("stacksSize"), off)
	p:Toggle("Show Spark", nil, g("showSpark"), s("showSpark"), off)
	p:Toggle("Stack Based Bar", "The bar fills by stacks instead of time.", g("stackBasedBar"), s("stackBasedBar"), off)
	p:Slider("Max Stacks", nil, 1, 50, 1, g("stackThresholdMax"),
		function(v) cfg.stackThresholdMax = v; cfg.stackThresholdMaxEnabled = true end, function() return off() or not cfg.stackBasedBar end)
	p:Slider("Opacity", nil, 0, 100, 5, function() return floor((V(cfg, "opacity") or 1) * 100 + 0.5) end,
		function(v) cfg.opacity = v / 100 end, off)
	p:Dropdown("Group", "Grouped bars stack under the group's first bar and move together. Independent bars have their own mover.",
		function()
			local items = { { value = 0, name = "Independent" } }
			for _, gid in ipairs(LP.TBBGroupIDs()) do items[#items + 1] = { value = gid, name = LP.TBBGroupLabel(gid) } end
			items[#items + 1] = { value = -1, name = "+ New Group" }
			return items
		end,
		function() return CDM.TBB.GroupID(cfg) end,
		function() local gid = CDM.TBB.GroupID(cfg); return gid == 0 and "Independent" or LP.TBBGroupLabel(gid) end,
		function(v)
			if v == -1 then v = LP.TBBNextGroupID() end
			LP.TBBMoveToGroup(selTBB, v)
		end, nil, off)
	local gid = CDM.TBB.GroupID(cfg)
	if gid ~= 0 then LP.TBBGroupSection(p, gid) end
end

---------------------------------------------------------------------------
-- Tracking Bars header (retail BuffBarsPage_Options.lua BuildManagementDropdown):
-- one dropdown button whose menu lists the groups ("Edit Group" selects
-- the group's settings) with their bars, then the independent bars. A bar
-- row: icon = change buff, click = select, right-click / speaker = Audio
-- on Buff Gain / Loss, X = delete, drag = move into another group (drop on
-- a bar row: placed before that bar). "+ Add Bar to Group", "+ Add New
-- Group", "+ Add Independent Bar" create a bar and open the buff picker.
---------------------------------------------------------------------------
function LP.TBBGroupIDs()
	local seen, out = {}, {}
	for _, b in ipairs(TData().bars) do
		local gid = CDM.TBB.GroupID(b)
		if gid ~= 0 and not seen[gid] then
			seen[gid] = true
			out[#out + 1] = gid
		end
	end
	table.sort(out)
	return out
end

function LP.TBBGroupLabel(gid)
	local g = TData().groups[tostring(gid)]
	return (g and g.name) or ("Group " .. gid)
end

function LP.TBBGroupCount(gid)
	local n = 0
	for _, b in ipairs(TData().bars) do
		if CDM.TBB.GroupID(b) == gid then n = n + 1 end
	end
	return n
end

function LP.TBBNextGroupID()
	local m = 0
	for _, gid in ipairs(LP.TBBGroupIDs()) do if gid > m then m = gid end end
	for k in pairs(TData().groups) do
		local n = tonumber(k)
		if n and n > m then m = n end
	end
	return m + 1
end

-- Positions are keyed by bar index (retail tbbPositions): when the bar list
-- changes order, each independent bar keeps its own position and each group
-- keeps its anchor's position on its (possibly new) first bar.
function LP.TBBApplyOrder(newBars)
	local t, positions = CDM.TBB.Data()
	local oldIndex, oldGroupPos = {}, {}
	for i, b in ipairs(t.bars) do
		oldIndex[b] = i
		local gid = CDM.TBB.GroupID(b)
		if gid ~= 0 and oldGroupPos[gid] == nil then oldGroupPos[gid] = positions[tostring(i)] or false end
	end
	local newPos = {}
	local seenGroup = {}
	for j, b in ipairs(newBars) do
		local gid = CDM.TBB.GroupID(b)
		if gid == 0 then
			local i = oldIndex[b]
			newPos[tostring(j)] = i and positions[tostring(i)] or nil
		elseif not seenGroup[gid] then
			seenGroup[gid] = true
			local pos = oldGroupPos[gid]
			if pos == nil then
				local i = oldIndex[b]
				pos = i and positions[tostring(i)] or nil
			end
			newPos[tostring(j)] = pos or nil
		end
	end
	wipe(positions)
	for k, v in pairs(newPos) do positions[k] = v end
	wipe(t.bars)
	for j, b in ipairs(newBars) do t.bars[j] = b end
end

-- Moves bar idx into group gid (0 = independent); before = optional bar index
-- it is placed in front of (else after the group's last bar).
function LP.TBBMoveToGroup(idx, gid, before)
	local t = TData()
	local cfg = t.bars[idx]
	if not cfg then return false end
	local list = {}
	for i, b in ipairs(t.bars) do list[i] = b end
	local target = before and list[before]
	table.remove(list, idx)
	cfg.groupId = gid
	cfg.grouped = gid ~= 0
	local at
	if target and target ~= cfg then
		for i, b in ipairs(list) do if b == target then at = i end end
	else
		for i, b in ipairs(list) do
			if CDM.TBB.GroupID(b) == gid then at = i + 1 end
		end
	end
	table.insert(list, at or (#list + 1), cfg)
	LP.TBBApplyOrder(list)
	for i, b in ipairs(t.bars) do if b == cfg then selTBB = i end end
	CDM.Apply()
	return true
end

function LP.TBBRemove(idx)
	local t = TData()
	if not t.bars[idx] then return end
	local list = {}
	for i, b in ipairs(t.bars) do if i ~= idx then list[#list + 1] = b end end
	LP.TBBApplyOrder(list)
	selTBB = math.max(1, math.min(selTBB, #t.bars))
	CDM.Apply()
end

-- New bar in group gid; returns its index.
function LP.TBBAdd(gid)
	local cfg = CDM.TBB.AddBar(nil)
	cfg.spellID = 0
	cfg.name = "New Bar"
	cfg.groupId = gid
	cfg.grouped = gid ~= 0
	local t = TData()
	-- Keep a group's bars together: move the new bar behind its group.
	local idx = #t.bars
	if gid ~= 0 then
		LP.TBBMoveToGroup(idx, gid)
		for i, b in ipairs(t.bars) do if b == cfg then idx = i end end
	end
	selTBB = idx
	selTBBGroup = nil
	CDM.Apply()
	return idx
end

local function SetBarSpell(cfg, id)
	cfg.spellID = id
	cfg.name = GetSpellInfo(id) or cfg.name
	CDM.Apply()
end

-- Buff picker for a bar (retail ShowTBBSpellPicker): Bloodlust, your current
-- buffs, your spellbook, Custom Spell ID.
function LP.TBBPickerRows(idx)
	local cfg = TData().bars[idx]
	local rows = {}
	local function Pick(id)
		return function()
			LP.CloseMenus()
			if cfg then SetBarSpell(cfg, id) end
			Rebuild()
		end
	end
	local function Row(id, label)
		local name, _, icon = GetSpellInfo(id)
		if not name then return end
		rows[#rows + 1] = { text = "|T" .. tostring(icon) .. ":14:14:0:0:64:64:5:59:5:59|t " .. (label or name), checked = cfg and cfg.spellID == id or nil, onClick = Pick(id) }
	end
	rows[#rows + 1] = { header = true, text = "POPULAR" }
	Row(UnitFactionGroup("player") == "Alliance" and 32182 or 2825)
	rows[#rows + 1] = { header = true, text = "ACTIVE BUFFS" }
	local seen = {}
	for i = 1, 40 do
		local name, _, _, _, _, _, _, _, _, _, sid = UnitAura("player", i, "HELPFUL")
		if not name then break end
		if sid and not seen[sid] then
			seen[sid] = true
			Row(sid)
		end
	end
	rows[#rows + 1] = { header = true, text = "SPELLBOOK" }
	local list = CDM.SpellbookSpells()
	table.sort(list, function(a, b) return a.name < b.name end)
	for _, s in ipairs(list) do
		if not seen[s.spellID] then Row(s.spellID) end
	end
	local talents = CDM.UnselectedTalentSpells and CDM.UnselectedTalentSpells() or {}
	if #talents > 0 then
		rows[#rows + 1] = { header = true, text = "TALENTS (NOT SELECTED)" }
		for _, s in ipairs(talents) do
			if not seen[s.spellID] then
				local n = #rows
				Row(s.spellID)
				if #rows > n then
					rows[#rows].color = { 0.55, 0.55, 0.55 }
					rows[#rows].tip = "Talent not selected. The bar works when you select this talent."
				end
			end
		end
	end
	rows[#rows + 1] = { divider = true }
	rows[#rows + 1] = { text = "Custom Spell ID", color = { Accent() }, onClick = function()
		LP.CloseMenus()
		AskNumber("Custom Spell ID", "Enter the spell ID of the buff or debuff to track.", function(id)
			if cfg then SetBarSpell(cfg, id) end
		end)
	end }
	return rows
end

function LP.TBBShowPicker(anchor, idx)
	LP.CloseMenus()
	LP.menu = LP.menu or NewMenu(20)
	LP.menu.anchor = anchor
	LP.menu.rebuild = nil
	EnsureCatcher():Show()
	ShowMenu(LP.menu, anchor, LP.TBBPickerRows(idx))
end

-- Right-click a bar row: Audio on Buff Gain / Loss (keys on the bar config).
function LP.TBBSoundRows(idx)
	local cfg = TData().bars[idx]
	if not cfg then return {} end
	local function SRow(label, field)
		return {
			text = label,
			subnav = {
				items = SoundItems,
				get = function() return cfg[field] or "none" end,
				set = function(v) cfg[field] = (v ~= "none" and v) or nil; CDM.Apply() end,
				label = function() return Pick(SoundItems(), cfg[field] or "none", "None") end,
			},
		}
	end
	return { SRow("Audio on Buff Gain", "buffActiveSoundKey"), SRow("Audio on Buff Loss", "buffLostSoundKey") }
end

function LP.TBBShowSounds(anchor, idx)
	LP.flyout = LP.flyout or NewMenu(40)
	LP.sound = LP.sound or NewMenu(35)
	EnsureCatcher():Show()
	ShowMenu(LP.sound, anchor, LP.TBBSoundRows(idx), "TOPLEFT", "TOPRIGHT", 2, 0)
end

-- The management menu (fresh frame each open, like retail).
local function TBBRowFrame(menu, h)
	local item = CreateFrame("Button", nil, menu)
	item:SetHeight(h)
	item:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, -menu.mH)
	item:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -1, -menu.mH)
	item:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
	item.hl = item:CreateTexture(nil, "ARTWORK")
	item.hl:SetAllPoints()
	item.hl:SetTexture(1, 1, 1, 1)
	item.hl:SetAlpha(0)
	menu.mH = menu.mH + h
	menu.rowFrames[#menu.rowFrames + 1] = item
	return item
end

function LP.TBBBuildMenu(anchor)
	if LP.tbbMenu then LP.tbbMenu:Hide() end
	local t = TData()
	local menu = CreateFrame("Frame", nil, UIParent)
	LP.tbbMenu = menu
	menu:SetFrameStrata("FULLSCREEN_DIALOG")
	menu:SetFrameLevel(15) -- 5.4.8 levels stop at ~128
	menu:SetClampedToScreen(true)
	menu:EnableMouse(true)
	menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
	menu:SetWidth(anchor:GetWidth())
	local bg = menu:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetTexture(0.075, 0.113, 0.141, 0.98)
	MenuBorder(menu, 0.20)
	menu.mH = 4
	menu.rowFrames = {}
	local ar, ag, ab = Accent()

	local function Header(text)
		if menu.mH > 4 then menu.mH = menu.mH + 4 end
		local fs = Text(menu, 10, 0.9)
		fs:SetPoint("TOPLEFT", menu, "TOPLEFT", 10, -menu.mH - 5)
		fs:SetText(text)
		menu.mH = menu.mH + 20
	end
	local function Action(text, indent, onClick)
		local item = TBBRowFrame(menu, LP.ITEM_H)
		local fs = Text(item, 11, 0.9)
		fs:SetPoint("LEFT", 10 + indent, 0)
		fs:SetText(text)
		fs:SetTextColor(ar, ag, ab, 0.9)
		item:SetScript("OnEnter", function() item.hl:SetAlpha(0.08) end)
		item:SetScript("OnLeave", function() item.hl:SetAlpha(0) end)
		item:SetScript("OnClick", function() onClick() end)
		return item
	end
	local function GroupRow(gid)
		if menu.mH > 4 then menu.mH = menu.mH + 4 end
		local item = TBBRowFrame(menu, 22)
		item.dropGid = gid
		local fs = Text(item, 10, 0.9)
		fs:SetPoint("LEFT", 10, 0)
		fs:SetText(LP.TBBGroupLabel(gid):upper())
		local e = Text(item, 10, 0.85)
		e:SetPoint("RIGHT", -10, 0)
		e:SetText("Edit Group")
		e:SetTextColor(ar, ag, ab, 0.85)
		local sel = selTBBGroup == gid
		item.hl:SetAlpha(sel and 0.12 or 0)
		item:SetScript("OnEnter", function() item.hl:SetAlpha(0.08) end)
		item:SetScript("OnLeave", function() item.hl:SetAlpha(sel and 0.12 or 0) end)
		item:SetScript("OnClick", function()
			LP.TBBCloseMenu()
			selTBBGroup = gid
			Rebuild()
		end)
		return item
	end
	local function BarRow(idx, b)
		local item = TBBRowFrame(menu, LP.ITEM_H)
		item.dropGid = CDM.TBB.GroupID(b)
		item.dropIdx = idx
		local unassigned = not b.spellID or b.spellID == 0
		local name, _, icon = GetSpellInfo(b.spellID or 0)
		local ico = item:CreateTexture(nil, "OVERLAY")
		ico:SetSize(LP.ITEM_H - 8, LP.ITEM_H - 8)
		ico:SetPoint("LEFT", item, "LEFT", 18, 0)
		ico:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		ico:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
		if unassigned then ico:SetDesaturated(true); ico:SetAlpha(0.35) end
		local icoBtn = CreateFrame("Button", nil, item)
		icoBtn:SetAllPoints(ico)
		icoBtn:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText("Change buff", 1, 1, 1)
			GameTooltip:Show()
		end)
		icoBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
		icoBtn:SetScript("OnClick", function()
			LP.TBBCloseMenu()
			LP.TBBShowPicker(anchor, idx)
		end)
		local display = (not unassigned and name) or b.name or ("Bar " .. idx)
		if unassigned then display = display .. "  (no buff assigned)" end
		item.displayName = display
		local fs = Text(item, 11, 0.85)
		fs:SetPoint("LEFT", ico, "RIGHT", 6, 0)
		fs:SetPoint("RIGHT", item, "RIGHT", -50, 0)
		fs:SetJustifyH("LEFT")
		fs:SetWordWrap(false)
		fs:SetText(display)
		local del = CreateFrame("Button", nil, item)
		del:SetSize(14, 14)
		del:SetPoint("RIGHT", item, "RIGHT", -8, 0)
		local dt = del:CreateTexture(nil, "OVERLAY")
		dt:SetAllPoints()
		dt:SetTexture(ns.MEDIA .. "ui\\eui-close")
		del:SetAlpha(0.75)
		del:SetScript("OnClick", function()
			LP.TBBCloseMenu()
			ns.ShowConfirmPopup({
				title = "Delete Bar",
				message = format("Delete \"%s\"?", display),
				confirmText = "Delete", cancelText = "Cancel",
				onConfirm = function() LP.TBBRemove(idx); Rebuild() end,
			})
		end)
		local snd = CreateFrame("Button", nil, item)
		snd:SetSize(14, 14)
		snd:SetPoint("RIGHT", del, "LEFT", -6, 0)
		local st = snd:CreateTexture(nil, "OVERLAY")
		st:SetAllPoints()
		st:SetTexture("Interface\\Common\\VoiceChat-Speaker")
		local function HasSound() return (b.buffActiveSoundKey and b.buffActiveSoundKey ~= "none") or (b.buffLostSoundKey and b.buffLostSoundKey ~= "none") end
		snd:SetAlpha(HasSound() and 0.8 or 0.3)
		snd:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(HasSound() and "Edit Audio Effect" or "Add Audio Effect", 1, 1, 1)
			GameTooltip:Show()
		end)
		snd:SetScript("OnLeave", function() GameTooltip:Hide() end)
		snd:SetScript("OnClick", function() if not unassigned then LP.TBBShowSounds(item, idx) end end)
		snd:SetShown(not unassigned)
		local sel = idx == selTBB and not selTBBGroup
		item.hl:SetAlpha(sel and 0.12 or 0)
		item:SetScript("OnEnter", function() item.hl:SetAlpha(0.08) end)
		item:SetScript("OnLeave", function() item.hl:SetAlpha(sel and 0.12 or 0) end)
		item:SetScript("OnClick", function(_, button)
			if GetTime() - LP.dragEndTime < 0.2 then return end
			if button == "RightButton" then
				if not unassigned then LP.TBBShowSounds(item, idx) end
				return
			end
			if button == "MiddleButton" then
				LP.TBBCloseMenu()
				LP.TBBRemove(idx)
				Rebuild()
				return
			end
			LP.TBBCloseMenu()
			if unassigned then
				LP.TBBShowPicker(anchor, idx)
			else
				selTBB = idx
				selTBBGroup = nil
				Rebuild()
			end
		end)
		-- Drag: move into another group (drop on a group / its rows), or in
		-- front of the bar row under the cursor.
		item:SetScript("OnMouseDown", function(self, button)
			if button ~= "LeftButton" then return end
			self.downX, self.downY = GetCursorPosition()
			self:SetScript("OnUpdate", function(me)
				if LP.tbbDrag then LP.TBBDragUpdate(); return end
				local x, y = GetCursorPosition()
				if math.abs(x - me.downX) + math.abs(y - me.downY) > LP.DRAG_THRESHOLD then
					LP.TBBDragStart(me, idx)
				end
			end)
		end)
		item:SetScript("OnMouseUp", function(self)
			self:SetScript("OnUpdate", nil)
			if LP.tbbDrag and LP.tbbDrag.item == self then LP.TBBDragFinish() end
		end)
		return item
	end

	for _, gid in ipairs(LP.TBBGroupIDs()) do
		GroupRow(gid)
		for idx, b in ipairs(t.bars) do
			if CDM.TBB.GroupID(b) == gid then BarRow(idx, b) end
		end
		local add = Action("+ Add Bar to Group", 8, function()
			LP.TBBCloseMenu()
			LP.TBBShowPicker(anchor, LP.TBBAdd(gid))
		end)
		add.dropGid = gid
	end
	local anyIndep = false
	for _, b in ipairs(t.bars) do if CDM.TBB.GroupID(b) == 0 then anyIndep = true end end
	if anyIndep then
		Header("INDEPENDENT BARS")
		for idx, b in ipairs(t.bars) do
			if CDM.TBB.GroupID(b) == 0 then BarRow(idx, b) end
		end
	end
	local div = menu:CreateTexture(nil, "ARTWORK")
	div:SetHeight(1)
	div:SetTexture(1, 1, 1, 0.10)
	div:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, -menu.mH - 4)
	div:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -1, -menu.mH - 4)
	menu.mH = menu.mH + 9
	Action("+ Add New Group", 0, function()
		LP.TBBCloseMenu()
		LP.TBBShowPicker(anchor, LP.TBBAdd(LP.TBBNextGroupID()))
	end)
	local indep = Action("+ Add Independent Bar", 0, function()
		LP.TBBCloseMenu()
		LP.TBBShowPicker(anchor, LP.TBBAdd(0))
	end)
	indep.dropGid = 0
	if #t.bars > 1 then
		local h = Text(menu, 10, 0.35)
		h:SetPoint("TOP", menu, "TOP", 0, -menu.mH - 4)
		h:SetText("Drag a bar to move it into another group")
		menu.mH = menu.mH + 20
	end
	if #t.bars > 0 then
		local h = Text(menu, 10, 0.35)
		h:SetPoint("TOP", menu, "TOP", 0, -menu.mH - 4)
		h:SetText("Right-click a bar to set its sounds")
		menu.mH = menu.mH + 20
	end
	menu:SetHeight(menu.mH + 4)
	EnsureCatcher():Show()
	menu:Show()
	return menu
end

function LP.TBBCloseMenu()
	if LP.tbbMenu then LP.tbbMenu:Hide() end
	if LP.sound then LP.sound:Hide() end
	LP.CloseMenus()
end

function LP.TBBDragStart(item, idx)
	LP.tbbDrag = { item = item, idx = idx }
	local g = LP.tbbGhost
	if not g then
		g = CreateFrame("Frame", nil, UIParent)
		g:SetFrameStrata("TOOLTIP")
		g:SetSize(10, 20)
		g.lbl = Text(g, 11, 0.8)
		g.lbl:SetPoint("BOTTOMLEFT")
		LP.tbbGhost = g
	end
	g:Show()
	LP.TBBDragUpdate()
end

-- The menu row under the cursor that accepts a drop.
function LP.TBBDropRow()
	local menu = LP.tbbMenu
	if not menu then return nil end
	for _, f in ipairs(menu.rowFrames) do
		if f.dropGid and f:IsMouseOver() then return f end
	end
end

function LP.TBBDragUpdate()
	local d = LP.tbbDrag
	if not d then return end
	local g = LP.tbbGhost
	local x, y = GetCursorPosition()
	local s = UIParent:GetEffectiveScale()
	g:ClearAllPoints()
	g:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / s + 14, y / s - 22)
	local name = d.item.displayName or ""
	local row = LP.TBBDropRow()
	local cfg = TData().bars[d.idx]
	if row and cfg and row.dropGid ~= CDM.TBB.GroupID(cfg) then
		local ar, ag, ab = Accent()
		g.lbl:SetText(name .. "  >  " .. (row.dropGid == 0 and "Independent" or LP.TBBGroupLabel(row.dropGid)))
		g.lbl:SetTextColor(ar, ag, ab, 1)
	else
		g.lbl:SetText(name)
		g.lbl:SetTextColor(1, 1, 1, 0.8)
	end
end

function LP.TBBDragFinish()
	local d = LP.tbbDrag
	LP.tbbDrag = nil
	LP.dragEndTime = GetTime()
	if LP.tbbGhost then LP.tbbGhost:Hide() end
	if not d then return end
	local row = LP.TBBDropRow()
	if not row then return end
	local before = row.dropIdx
	if before == d.idx then return end
	local cfg = TData().bars[d.idx]
	if not cfg then return end
	if before or row.dropGid ~= CDM.TBB.GroupID(cfg) then
		LP.TBBCloseMenu()
		LP.TBBMoveToGroup(d.idx, row.dropGid, before)
		Rebuild()
	end
end

-- Group settings page (retail: "Edit Group" selects the group).
function LP.TBBGroupSection(p, gid)
	local t = TData()
	local key = tostring(gid)
	local function G() t.groups[key] = t.groups[key] or {}; return t.groups[key] end
	p:Section(LP.TBBGroupLabel(gid))
	p:Dropdown("Grow Direction", "Which way the group's bars stack from its first bar.",
		function() return Items({ { "DOWN", "Down" }, { "UP", "Up" } }) end,
		function() return (t.groups[key] and t.groups[key].grow) or t.groupGrowDirection or "DOWN" end,
		function() return (((t.groups[key] and t.groups[key].grow) or t.groupGrowDirection or "DOWN") == "UP") and "Up" or "Down" end,
		function(v) G().grow = v end)
	p:Slider("Spacing", "Space between the group's bars.", -5, 20, 1,
		function() return floor(((t.groups[key] and t.groups[key].spacing) or t.groupSpacing or 0) + 0.5) end,
		function(v) G().spacing = v end)
end

function LP.TBBBuildGroupPage(p, gid)
	if LP.TBBGroupCount(gid) == 0 then
		selTBBGroup = nil
		return false
	end
	LP.TBBGroupSection(p, gid)
	p:Button("Rename Group", nil, "Rename", function()
		ns.ShowInputPopup({
			title = "Rename Group", message = "Enter a new name for the group:",
			text = LP.TBBGroupLabel(gid), confirmText = "Rename", cancelText = "Cancel",
			onConfirm = function(text)
				text = text and strtrim(text) or ""
				local t = TData()
				t.groups[tostring(gid)] = t.groups[tostring(gid)] or {}
				t.groups[tostring(gid)].name = (text ~= "") and text or nil
				Rebuild()
			end,
		})
	end)
	p:Button("Ungroup Bars", "Every bar of this group becomes an independent bar.", "Ungroup", function()
		local t = TData()
		for _, b in ipairs(t.bars) do
			if CDM.TBB.GroupID(b) == gid then b.groupId = 0; b.grouped = false end
		end
		selTBBGroup = nil
		CDM.Apply()
		Rebuild()
	end)
	return true
end

local function TrackingHeader(page, host, width)
	local y = 16
	local DD_W, DD_H = 350, 34
	local btn = CreateFrame("Button", nil, host)
	LP.tbbButton = btn
	btn:SetSize(DD_W, DD_H)
	btn:SetPoint("TOPLEFT", host, "TOPLEFT", floor((width - DD_W) / 2), -y)
	local bg = btn:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetTexture(0.075, 0.113, 0.141, 0.9)
	MenuBorder(btn, 0.20)
	local lbl = Text(btn, 13, 0.75)
	lbl:SetPoint("LEFT", 12, 0)
	lbl:SetPoint("RIGHT", -28, 0)
	lbl:SetJustifyH("LEFT")
	lbl:SetWordWrap(false)
	local arrow = Text(btn, 12, 0.6)
	arrow:SetPoint("RIGHT", -12, 0)
	arrow:SetText("v")
	local t = TData()
	if selTBBGroup and LP.TBBGroupCount(selTBBGroup) > 0 then
		local n = LP.TBBGroupCount(selTBBGroup)
		lbl:SetText(LP.TBBGroupLabel(selTBBGroup) .. "  -  " .. n .. " " .. (n == 1 and "Bar" or "Bars"))
	else
		local cfg = TCfg()
		if cfg then
			local name = (cfg.spellID and cfg.spellID > 0 and GetSpellInfo(cfg.spellID)) or cfg.name or "Bar"
			local gid = CDM.TBB.GroupID(cfg)
			if gid ~= 0 then name = name .. "  (" .. LP.TBBGroupLabel(gid) .. ")" end
			lbl:SetText(name)
		elseif #t.bars == 0 then
			lbl:SetText("No Bars - Click to Add")
		else
			lbl:SetText("Select a bar")
		end
	end
	btn:SetScript("OnEnter", function() lbl:SetAlpha(1) end)
	btn:SetScript("OnLeave", function() lbl:SetAlpha(0.75) end)
	btn:SetScript("OnClick", function(self)
		if LP.tbbMenu and LP.tbbMenu:IsShown() then
			LP.TBBCloseMenu()
			return
		end
		LP.TBBBuildMenu(self)
	end)
	host:HookScript("OnHide", function()
		LP.TBBCloseMenu()
		if LP.tbbDrag then LP.TBBDragFinish() end
	end)
	return y + DD_H + 14
end

---------------------------------------------------------------------------
-- Bar Glows page (retail BuildBarGlowsPage + EUI_CooldownManager_
-- BarGlowConditions.lua). Header: target picker (action bars, CDM bars) and a
-- button grid built from the live buttons; left click a button to edit its
-- glows, right click to tick buffs on / off. Body: one block per glow:
--   (collapse bar: arrow, buff icon, name)
--   When <buff> Is [Active v]          | And [buff v] is [Active v]  (toggle)
--   At Stacks (cog)          (toggle)  | Glow Type (Blackout cog) (eye) [v]
--   Only In Combat           (toggle)  | Glow Color   [default][custom][class]
--   (icon) [Duplicate] [Remove]        |
-- 5.4.8: no hero talents, so the rows use retail's WoW Forever pairing.
---------------------------------------------------------------------------
local BG = CDM.BarGlows
local BGP = { frames = {}, previews = {} }
ns.CDM_BarGlowsPage = BGP   -- test hook

local BG_HINT = "Left click a button to edit its glow, right click to add a new glow"
local EYE_VISIBLE = ns.MEDIA .. "icons\\eui-visible"
local EYE_INVISIBLE = ns.MEDIA .. "icons\\eui-invisible"
local EYE_TC = 30 / 32   -- 30 x 30 art on a 32 x 32 canvas
local STATE_LIST = { { "ACTIVE", "Active" }, { "MISSING", "Missing" } }
local STACK_OPS = {
	{ "lt", "Below (<)" }, { "lte", "At Most (<=)" }, { "eq", "Exactly (=)" },
	{ "gte", "At Least (>=)" }, { "gt", "Above (>)" },
}

local function BGData()
	return BG.Data()
end

-- Selected target: an action bar index (number) or a CDM bar key (string).
function BGP.SelBar()
	local v = BGData().selectedBar
	if type(v) == "number" and BG.HasBar(v) then return v end
	if type(v) == "string" then
		local bd = CDM.BarByKey(v)
		if bd and CDM.IsPortedBar(bd) then return v end
	end
	local first = PortedBars()[1]
	if first then return first.key end
	return 1
end

function BGP.TargetLabel(sel)
	if type(sel) == "number" then return format("Action Bar %d", sel) end
	local bd = CDM.BarByKey(sel)
	return "CDM: " .. ((bd and (bd.name or bd.key)) or tostring(sel))
end

function BGP.TargetItems()
	local items = {}
	for _, b in ipairs(BG.BAR_ORDER) do
		if BG.HasBar(b) then
			if #items == 0 then items[1] = { header = true, name = "ACTION BARS" } end
			items[#items + 1] = { value = b, name = BGP.TargetLabel(b) }
		end
	end
	items[#items + 1] = { header = true, name = "COOLDOWN MANAGER" }
	for _, bd in ipairs(PortedBars()) do
		items[#items + 1] = { value = bd.key, name = BGP.TargetLabel(bd.key) }
	end
	return items
end

-- Buttons of the selected target: { tex, key (nil = cannot glow), w, h }.
function BGP.Slots(sel)
	local out = {}
	if type(sel) == "number" then
		local eab = ns.EAB and ns.EAB.db and ns.EAB.db.profile
		local s = eab and eab.bars and eab.bars[BG.BAR_KEYS[sel]]
		local n = 12
		local ov = s and (s.overrideNumIcons or s.numIcons)
		if ov and ov > 0 and ov < n then n = ov end
		for i = 1, n do
			local btn = BG.ActionButton(sel, i)
			local icon = btn and (btn.icon or (btn:GetName() and _G[btn:GetName() .. "Icon"]))
			local tex = icon and icon:IsShown() and icon:GetTexture() or nil
			local w = btn and btn:GetWidth() or 36
			local h = btn and btn:GetHeight() or 36
			out[i] = { tex = tex, key = sel .. "_" .. i, w = w, h = h, zoom = ((s and s.iconZoom) or 5.5) / 100 }
		end
		return out
	end
	local bd = CDM.BarByKey(sel)
	if not bd then return out end
	local iw, ih = CDM.IconDims(bd)
	local z = CDM.BV(bd, "iconZoom") or 0.08
	for i, e in ipairs(CDM.BarEntries(bd)) do
		-- Items and trinket slots have no buff spell to key a glow by.
		local glowable = e.spellID and e.kind ~= "item" and e.kind ~= "slot"
		out[i] = { tex = e.icon, key = glowable and ("cdms_" .. e.spellID) or nil, w = iw, h = ih, zoom = z,
			cropped = bd.iconShape == "cropped" and CDM.CropPercent(bd) / 100 or nil }
	end
	return out
end

-- The assignment key of the selected button (nil = none / cannot glow).
function BGP.SelKey()
	if not BGP.sel then return nil end
	local slot = BGP.Slots(BGP.SelBar())[BGP.sel]
	return slot and slot.key
end

local function BGList(key, create)
	local data = BGData()
	local list = data.assignments[key]
	if not list and create then
		list = {}
		data.assignments[key] = list
	end
	return list
end

local function SpellName(sid)
	sid = tonumber(sid)
	if not sid or sid <= 0 then return "Choose Buff", nil end
	local name, _, icon = GetSpellInfo(sid)
	return name or ("Spell " .. sid), icon
end

local function IconTag(icon, size)
	if not icon then return "" end
	return "|T" .. tostring(icon) .. ":" .. (size or 14) .. ":" .. (size or 14) .. ":0:0:64:64:5:59:5:59|t "
end

---------------------------------------------------------------------------
-- Buff menus (retail ShowBarGlowBuffMenu): CDM buff bar buffs, then the
-- Tracking Bars buffs, then a Custom Spell ID row (5.4.8 has no Blizzard
-- buff list to choose from). Built on the live preview menu (LP).
---------------------------------------------------------------------------
-- opts.isChecked(sid), opts.onPick(sid) ; opts.multi keeps the menu open.
function BGP.BuffRows(opts)
	local cdm, tbb = BG.BuffSpells()
	local rows = {}
	local function Add(sp)
		rows[#rows + 1] = {
			text = IconTag(sp.icon) .. tostring(sp.name),
			checked = opts.isChecked(sp.spellID) and true or false,
			onClick = function() opts.onPick(sp.spellID) end,
		}
	end
	if #cdm > 0 then
		rows[#rows + 1] = { header = true, text = "CDM BUFFS" }
		for _, sp in ipairs(cdm) do Add(sp) end
	end
	if #tbb > 0 then
		if #rows > 0 then rows[#rows + 1] = { divider = true } end
		rows[#rows + 1] = { header = true, text = "TRACKING BARS" }
		for _, sp in ipairs(tbb) do Add(sp) end
	end
	if #rows == 0 then
		rows[#rows + 1] = { header = true, text = "No Cooldown Manager buffs to choose from." }
	end
	rows[#rows + 1] = { divider = true }
	rows[#rows + 1] = { text = "Custom Spell ID", color = { Accent() },
		tip = "Any buff on you, or your debuff on the target, by its spell ID.",
		onClick = function()
			LP.CloseMenus()
			AskNumber("Custom Spell ID", "Enter the spell ID of the buff.", function(id) opts.onPick(id) end)
		end }
	return rows
end

function BGP.ShowMenu(anchor, rows, rebuildRows)
	LP.CloseMenus()
	LP.menu = LP.menu or NewMenu(20)
	LP.menu.anchor = anchor
	LP.menu.rebuild = rebuildRows and function() LP.menu.rows = rebuildRows(); LP.Render(LP.menu) end or nil
	EnsureCatcher():Show()
	ShowMenu(LP.menu, anchor, rows)
end

-- Right click on a grid button: tick buffs on / off for it (stays open).
function BGP.ShowAddPicker(i)
	local anchor = BGP.frames[i]
	local key = BGP.SelKey()
	if not (anchor and key) then return end
	local function rowsFn()
		local list = BGList(key) or {}
		local have = {}
		for _, e in ipairs(list) do if e.spellID then have[e.spellID] = true end end
		return BGP.BuffRows({
			isChecked = function(sid) return have[sid] end,
			onPick = function(sid)
				local l = BGList(key, true)
				local removed = false
				for n = #l, 1, -1 do
					if l[n].spellID == sid then
						table.remove(l, n)
						removed = true
						break
					end
				end
				if not removed then
					l[#l + 1] = { spellID = sid, glowStyle = 1, mode = "ACTIVE", onlyInCombat = false }
				end
				if #l == 0 then BGData().assignments[key] = nil end
				CDM.Apply()
				-- Rebuild the page (the glow list below), keep the menu open on
				-- the new grid button.
				BGP.keepMenu = true
				Rebuild()
				BGP.keepMenu = nil
				local nb = BGP.frames[i]
				if nb and LP.menu and LP.menu:IsShown() then
					LP.menu.anchor = nb
					LP.menu:ClearAllPoints()
					LP.menu:SetPoint("TOPLEFT", nb, "BOTTOMLEFT", 0, -2)
					LP.menu.rows = rowsFn()
					LP.Render(LP.menu)
				end
			end,
		})
	end
	BGP.menuFor = i
	BGP.ShowMenu(anchor, rowsFn(), rowsFn)
end

-- Single pick (the And buff).
function BGP.ShowBuffPick(anchor, current, onPick)
	BGP.menuFor = nil
	BGP.ShowMenu(anchor, BGP.BuffRows({
		isChecked = function(sid) return sid == tonumber(current) end,
		onPick = function(sid)
			LP.CloseMenus()
			onPick(sid)
		end,
	}))
end

function BGP.ShowStatePick(anchor, current, onPick)
	BGP.menuFor = nil
	local rows = {}
	for _, it in ipairs(STATE_LIST) do
		rows[#rows + 1] = { text = it[2], checked = it[1] == current, onClick = function()
			LP.CloseMenus()
			onPick(it[1])
		end }
	end
	BGP.ShowMenu(anchor, rows)
end

---------------------------------------------------------------------------
-- Preview glows on the grid buttons (the eye toggle of a glow)
---------------------------------------------------------------------------
function BGP.StopPreviews()
	for k, pv in pairs(BGP.previews) do
		if pv.ov then BG.StopOn(pv.ov) end
		BGP.previews[k] = nil
	end
end

function BGP.PreviewSig(entry)
	return table.concat({ tostring(entry.glowStyle), tostring(entry.colorMode), tostring(entry.glowAlpha),
		entry.glowColor and format("%.3f%.3f%.3f", entry.glowColor.r or 0, entry.glowColor.g or 0, entry.glowColor.b or 0) or "" }, ":")
end

function BGP.StartPreview(pvKey, entry)
	local f = BGP.frames[BGP.sel or 0]
	if not f then return end
	local pv = BGP.previews[pvKey] or {}
	BGP.previews[pvKey] = pv
	if not pv.ov or pv.ov:GetParent() ~= f then
		pv.ov = CreateFrame("Frame", nil, f)
		pv.ov:SetAllPoints(f)
		pv.ov:SetFrameLevel(f:GetFrameLevel() + 6)
	end
	BG.StopOn(pv.ov)
	BG.StartOn(pv.ov, entry, f:GetWidth(), f:GetHeight())
	pv.sig = BGP.PreviewSig(entry)
	pv.entry = entry
	if f.sel then ShowEdges(f.sel, false) end
end

function BGP.StopPreview(pvKey)
	local pv = BGP.previews[pvKey]
	if not pv then return end
	if pv.ov then BG.StopOn(pv.ov) end
	BGP.previews[pvKey] = nil
	local f = BGP.frames[BGP.sel or 0]
	if f and f.sel and not next(BGP.previews) then ShowEdges(f.sel, true) end
end

---------------------------------------------------------------------------
-- Header: target picker + button grid
---------------------------------------------------------------------------
local function BarGlowsHeader(page, host, width)
	local y = 20
	local DD_H, DD_W = 30, 350
	wipe(BGP.frames)
	local sel = BGP.SelBar()
	local label = Text(host, 11, 0.45)
	label:SetText("BAR")
	local dd = page:HeaderDropdown(host, DD_W, DD_H, BGP.TargetItems,
		function() return BGP.SelBar() end,
		function() return BGP.TargetLabel(BGP.SelBar()) end,
		function(v)
			BGData().selectedBar = v
			BGP.sel = nil
			LP.CloseMenus()
			Rebuild()
		end)
	dd:SetPoint("TOP", host, "TOP", 0, -y)
	label:SetPoint("BOTTOMLEFT", dd, "TOPLEFT", 0, 2)
	y = y + DD_H + 20

	local slots = BGP.Slots(sel)
	local n = #slots
	local data = BGData()
	local bw, bh = 36, 36
	if slots[1] then bw, bh = floor(slots[1].w + 0.5), floor(slots[1].h + 0.5) end
	if bw < 12 then bw = 36 end
	if bh < 12 then bh = bw end
	local pad = 2
	if type(sel) == "number" then
		local eab = ns.EAB and ns.EAB.db and ns.EAB.db.profile
		local s = eab and eab.bars and eab.bars[BG.BAR_KEYS[sel]]
		pad = (s and s.buttonPadding) or 2
	else
		pad = CDM.BarByKey(sel) and CDM.BarByKey(sel).spacing or 2
	end
	if pad < 0 then pad = 0 end
	local avail = width - 45 * 2
	local gridW = n * bw + math.max(0, n - 1) * pad
	if gridW > avail and gridW > 0 then
		local f = avail / gridW
		bw, bh, pad = floor(bw * f), floor(bh * f), pad * f
		gridW = n * bw + math.max(0, n - 1) * pad
	end
	local x0 = floor((width - gridW) / 2)
	local r, g, b = Accent()
	for i, slot in ipairs(slots) do
		local f = CreateFrame("Button", nil, host)
		BGP.frames[i] = f
		f:SetSize(bw, bh)
		f:SetPoint("TOPLEFT", host, "TOPLEFT", x0 + (i - 1) * (bw + pad), -y)
		f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		local bg = f:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetTexture(0.077, 0.068, 0.058, 0.5)
		local icon = f:CreateTexture(nil, "ARTWORK")
		icon:SetPoint("TOPLEFT", 1, -1)
		icon:SetPoint("BOTTOMRIGHT", -1, 1)
		if slot.tex then
			icon:SetTexture(slot.tex)
			local z = slot.zoom or 0.08
			local t = slot.cropped or 0
			icon:SetTexCoord(z, 1 - z, z + t, 1 - z - t)
			if not slot.key then icon:SetDesaturated(true) end
		else
			icon:SetTexture(0, 0, 0, 0.5)
		end
		SlotBorder(f, 0, 0, 0, 1, 1)
		local list = slot.key and data.assignments[slot.key]
		local hasAssign = list and #list > 0
		local isSel = BGP.sel == i and slot.key ~= nil
		f.white = SlotBorder(f, 1, 1, 1, 0.6, 2)
		f.sel = SlotBorder(f, r, g, b, 1, 2)
		ShowEdges(f.white, hasAssign and not isSel)
		ShowEdges(f.sel, isSel)
		f:SetAlpha((isSel or hasAssign) and 1 or 0.5)
		if slot.key and not isSel then
			f:SetScript("OnEnter", function(self)
				ShowEdges(self.sel, true)
				if not hasAssign then self:SetAlpha(0.55) end
			end)
			f:SetScript("OnLeave", function(self)
				ShowEdges(self.sel, false)
				if not hasAssign then self:SetAlpha(0.5) end
			end)
		end
		f:SetScript("OnClick", function(_, button)
			if not slot.key then return end   -- items / trinkets cannot glow
			if button == "RightButton" then
				if LP.menu and LP.menu:IsShown() and BGP.menuFor == i then
					LP.CloseMenus()
					return
				end
				LP.CloseMenus()
				if BGP.sel ~= i then
					BGP.sel = i
					Rebuild()
				end
				BGP.ShowAddPicker(i)
			else
				LP.CloseMenus()
				BGP.sel = i
				Rebuild()
			end
		end)
	end
	if n == 0 then
		local none = Text(host, 12, 0.4)
		none:SetPoint("TOP", host, "TOP", 0, -y - 10)
		none:SetText("This bar has no buttons.")
		bh = 30
	end
	host:HookScript("OnHide", function()
		if not BGP.keepMenu then LP.CloseMenus() end
		BGP.StopPreviews()
	end)
	y = y + bh + 20
	local tip = Text(host, 11, 0.7)
	tip:SetPoint("TOP", host, "TOP", 0, -y)
	tip:SetText(BG_HINT)
	return y + 14 + 15
end

---------------------------------------------------------------------------
-- Body
---------------------------------------------------------------------------
-- Collapse bar across the top of a glow (retail BuildBarGlowHeader).
local function CollapseBar(p, entry, idx)
	p:CloseRow()
	local collapsed = entry.collapsed == true
	if idx > 1 then p.y = p.y - 8 end
	local H = 38
	local pad = floor((p.child:GetWidth() - p:RowWidth()) / 2)
	local bar = CreateFrame("Button", nil, p.child)
	bar:SetPoint("TOPLEFT", p.child, "TOPLEFT", pad, p.y)
	bar:SetSize(p:RowWidth(), H)
	local bg = bar:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetTexture(1, 1, 1, 0.04)
	-- The arrow drawn three times, 1 px apart, for a bolder stroke.
	local arrows = {}
	for k, off in ipairs({ { 0, 0 }, { 1, 0 }, { 0, -1 } }) do
		local t = bar:CreateTexture(nil, "OVERLAY")
		t:SetSize(16, 16)
		t:SetTexture(ns.MEDIA .. "ui\\" .. (collapsed and "eui-arrow-right" or "eui-arrow-down3"))
		t:SetPoint("LEFT", bar, "LEFT", 10 + off[1], off[2])
		arrows[k] = t
	end
	local function PaintArrow(cr, cg, cb, ca)
		for _, t in ipairs(arrows) do t:SetVertexColor(cr, cg, cb, ca) end
	end
	PaintArrow(1, 1, 1, 0.7)
	local name, icon = SpellName(entry.spellID or 0)
	if not entry.spellID and entry.name then name = entry.name end
	local ico = bar:CreateTexture(nil, "ARTWORK")
	ico:SetSize(26, 26)
	ico:SetPoint("LEFT", arrows[1], "RIGHT", 11, 0)
	ico:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
	ico:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local title = Text(bar, 13, 1)
	title:SetPoint("LEFT", ico, "RIGHT", 10, 0)
	title:SetText(name)
	bar:SetScript("OnEnter", function()
		local r, g, b = Accent()
		bg:SetTexture(1, 1, 1, 0.08)
		PaintArrow(r, g, b, 1)
		title:SetTextColor(r, g, b, 1)
		if entry.spellID then
			-- 5.4.8 SetOwner needs a Frame (a Texture errors), so own by
			-- the bar and anchor next to the icon.
			GameTooltip:SetOwner(bar, "ANCHOR_NONE")
			GameTooltip:SetPoint("TOPLEFT", ico, "TOPRIGHT", 4, 0)
			GameTooltip:SetSpellByID(entry.spellID)
			GameTooltip:Show()
		end
	end)
	bar:SetScript("OnLeave", function()
		bg:SetTexture(1, 1, 1, 0.04)
		PaintArrow(1, 1, 1, 0.7)
		title:SetTextColor(1, 1, 1, 1)
		GameTooltip:Hide()
	end)
	bar:SetScript("OnClick", function()
		entry.collapsed = (not collapsed) and true or nil
		Rebuild()
	end)
	bar:EnableMouseWheel(true)
	bar:SetScript("OnMouseWheel", function(_, delta) p:ScrollBy(-delta * 60) end)
	p.y = p.y - H - (collapsed and 0 or 4)
	return not collapsed
end

-- A small dropdown-look button (for the And row).
local function MiniDrop(parent, w)
	local b = FlatButton(parent, w, 26, "", nil)
	b.text:ClearAllPoints()
	b.text:SetPoint("LEFT", 8, 0)
	b.text:SetPoint("RIGHT", -16, 0)
	b.text:SetJustifyH("LEFT")
	b.text:SetWordWrap(false)
	local arrow = Text(b, 10, 0.5)
	arrow:SetPoint("RIGHT", -6, 0)
	arrow:SetText("v")
	return b
end

-- Right cell of row 1: And [buff v] is [state v] (toggle).
local function AndControls(p, entry)
	local cell = p.lastCell
	if not cell then return end
	local function Cond()
		if type(entry.conditions) ~= "table" then entry.conditions = {} end
		if type(entry.conditions[1]) ~= "table" then entry.conditions[1] = {} end
		return entry.conditions[1]
	end
	local holder = CreateFrame("Frame", nil, cell)
	holder:SetAllPoints()
	holder:SetFrameLevel(cell:GetFrameLevel() + 2)
	local state = MiniDrop(holder, 86)
	state:SetPoint("RIGHT", cell, "RIGHT", -72, 0)
	local isWord = Text(holder, 13, 1)
	isWord:SetPoint("RIGHT", state, "LEFT", -8, 0)
	isWord:SetText("is")
	local buff = MiniDrop(holder, 190)
	buff:SetPoint("RIGHT", isWord, "LEFT", -8, 0)
	buff.icon = buff:CreateTexture(nil, "ARTWORK")
	buff.icon:SetSize(20, 20)
	buff.icon:SetPoint("LEFT", 3, 0)
	buff.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local function Paint()
		local c = type(entry.conditions) == "table" and entry.conditions[1] or {}
		local name, icon = SpellName(c.spellID)
		buff.text:SetText(name)
		buff.text:ClearAllPoints()
		buff.text:SetPoint("RIGHT", -16, 0)
		if icon then
			buff.icon:SetTexture(icon)
			buff.icon:Show()
			buff.text:SetPoint("LEFT", buff.icon, "RIGHT", 6, 0)
		else
			buff.icon:Hide()
			buff.text:SetPoint("LEFT", 8, 0)
		end
		state.text:SetText(c.state == "missing" and "Missing" or "Active")
		local on = entry.andMode == "and"
		for _, part in ipairs({ buff, state }) do
			part:SetAlpha(on and 1 or 0.3)
			part:EnableMouse(on)
		end
		isWord:SetAlpha(on and 1 or 0.3)
		cell.label:SetAlpha(on and 1 or 0.3)
	end
	buff:SetScript("OnClick", function(self)
		BGP.ShowBuffPick(self, Cond().spellID, function(sid)
			Cond().spellID = sid
			CDM.Apply()
			Paint()
		end)
	end)
	state:SetScript("OnClick", function(self)
		local c = Cond()
		BGP.ShowStatePick(self, c.state == "missing" and "MISSING" or "ACTIVE", function(v)
			c.state = (v == "MISSING") and "missing" or nil
			CDM.Apply()
			Paint()
		end)
	end)
	Paint()
	p:OnRefresh(function()
		if holder:IsVisible() then Paint() end
	end)
end

-- Bar glows offer Blackout too (retail GLOW_VIEW order ends with it).
local function GlowTypeItems()
	local out = GlowItems(false)
	out[#out + 1] = { value = 8, name = CDM.GLOW_NAMES[8] }
	return out
end

local function GlowTypeLabel(v)
	return CDM.GLOW_NAMES[v] or GlowLabel(v)
end

-- Mouse wheel over a custom control scrolls the page.
local function Wheel(frame, p)
	frame:EnableMouseWheel(true)
	frame:SetScript("OnMouseWheel", function(_, delta) p:ScrollBy(-delta * 60) end)
end

local function BuildBarGlows(p)
	BGP.StopPreviews()
	local key = BGP.SelKey()
	if not key then
		p:Paragraph(BG_HINT)
		return
	end
	local list = BGList(key) or {}
	if #list == 0 then
		p:Paragraph("No buffs assigned. Right click a button in the preview to assign buffs.")
		return
	end
	for idx, entry in ipairs(list) do
		if CollapseBar(p, entry, idx) then
			local pvKey = key .. "_" .. idx
			local ownName = entry.spellID and SpellName(entry.spellID) or (entry.name or "buff")

			-- Row 1: When <buff> Is [Active v] | And [buff v] is [Active v] (toggle)
			p:Dropdown("When " .. ownName .. " Is", nil,
				function() return Items(STATE_LIST) end,
				function() return entry.mode == "MISSING" and "MISSING" or "ACTIVE" end,
				function() return entry.mode == "MISSING" and "Missing" or "Active" end,
				function(v) entry.mode = v end)
			p:Toggle("And", "Also require a second buff to be active (or missing) for this glow. For an \"or\", add another glow to the same button.",
				function() return entry.andMode == "and" end,
				function(v) entry.andMode = v and "and" or nil end)
			AndControls(p, entry)

			-- Row 2: At Stacks (cog) | Glow Type (Blackout cog) (eye)
			p:Toggle("At Stacks", "Only glow once the buff's stack count matches the comparison set via the gear.",
				function() return entry.stackEnabled == true end,
				function(v) entry.stackEnabled = v or nil end,
				function() return entry.mode == "MISSING" end)
			p:Cog("At Stacks", {
				{ type = "dropdown", label = "Comparison", items = function() return Items(STACK_OPS) end,
					get = function() return entry.stackOperator or "gte" end,
					set = function(v) entry.stackOperator = (v ~= "gte") and v or nil end,
					labelFn = function() return LabelOf(STACK_OPS, entry.stackOperator or "gte") end },
				{ type = "slider", label = "Stack Count", min = 1, max = 99, step = 1,
					get = function() return tonumber(entry.stackThreshold) or 2 end,
					set = function(v) entry.stackThreshold = v end },
			}, {
				disabled = function() return entry.mode == "MISSING" or not entry.stackEnabled end,
				disabledTip = entry.mode == "MISSING" and "This option is not available in Buff Missing mode" or nil,
			})
			p:Dropdown("Glow Type", nil, GlowTypeItems,
				function() return tonumber(entry.glowStyle) or 1 end,
				function() return GlowTypeLabel(tonumber(entry.glowStyle) or 1) end,
				function(v) entry.glowStyle = tonumber(v) or 1 end)
			local eye = p:InlineIcon("Preview this glow on the button above", EYE_VISIBLE, function()
				if BGP.previews[pvKey] then BGP.StopPreview(pvKey) else BGP.StartPreview(pvKey, entry) end
			end, 22)
			local eyeTex = eye:GetRegions()   -- InlineIcon's only region: its icon
			if eyeTex then eyeTex:SetTexCoord(0, EYE_TC, 0, EYE_TC) end
			p:Cog("Blackout", {
				{ type = "slider", label = "Opacity", min = 1, max = 100, step = 1,
					get = function() return floor((entry.glowAlpha or 1) * 100 + 0.5) end,
					set = function(v) entry.glowAlpha = v / 100 end },
			}, {
				disabled = function() return (tonumber(entry.glowStyle) or 1) ~= 8 end,
				disabledTip = "This option requires the Blackout glow type",
			})
			p:OnRefresh(function()
				if not eye:IsVisible() then return end
				local pv = BGP.previews[pvKey]
				if eyeTex then eyeTex:SetTexture(pv and EYE_INVISIBLE or EYE_VISIBLE) end
				-- Style / colour / opacity changed: restart the preview glow.
				if pv and pv.sig ~= BGP.PreviewSig(entry) then BGP.StartPreview(pvKey, entry) end
			end)

			-- Row 3: Only In Combat | Glow Color [default][custom][class]
			p:Toggle("Only In Combat", nil,
				function() return entry.onlyInCombat == true end,
				function(v) entry.onlyInCombat = v or nil end)
			p:Label("Glow Color", "Default: the glow's own colour. Then a custom colour (click to pick) and your class colour.")
			local function Mode() return entry.colorMode or "default" end
			-- Inline items go right to left: class, custom, default.
			p:Swatch("Class Color",
				function()
					local _, class = UnitClass("player")
					local c = class and RAID_CLASS_COLORS[class]
					if c then return c.r, c.g, c.b, 1 end
					return 1, 1, 1, 1
				end, function() end,
				{ readonly = true, active = function() return Mode() == "class" end,
					onClick = function() entry.colorMode = "class"; return true end })
			p:Swatch("Custom Color",
				function()
					local c = entry.glowColor or {}
					return c.r or BG.DEFAULT_R, c.g or BG.DEFAULT_G, c.b or BG.DEFAULT_B, 1
				end,
				function(r, g, b)
					entry.glowColor = { r = r, g = g, b = b }
					entry.colorMode = "custom"
				end,
				{ active = function() return Mode() == "custom" end,
					onClick = function() entry.colorMode = "custom"; return false end })
			p:Swatch("Default Color",
				function() return BG.DEFAULT_R, BG.DEFAULT_G, BG.DEFAULT_B, 1 end, function() end,
				{ readonly = true, active = function() return Mode() == "default" end,
					onClick = function() entry.colorMode = "default"; return true end })

			-- Row 4: (icon) [Duplicate] [Remove]
			p:Button("", nil, "Remove", function()
				LP.CloseMenus()
				local l = BGList(key)
				if l and l[idx] == entry then table.remove(l, idx) end
				if l and #l == 0 then BGData().assignments[key] = nil end
				CDM.Apply()
				Rebuild()
			end)
			local cell = p.lastCell
			local dup = FlatButton(cell, 110, 28, "Duplicate", function()
				local l = BGList(key)
				if not l then return end
				local copy = CDM.DeepCopy(entry)
				copy.collapsed = nil   -- the copy opens expanded
				table.insert(l, idx + 1, copy)
				CDM.Apply()
				Rebuild()
			end, "Add a full copy of this glow right below it.")
			dup:SetPoint("RIGHT", cell, "RIGHT", -(20 + 150 + 8), 0)
			local sic = CreateFrame("Frame", nil, cell)
			sic:SetSize(28, 28)
			sic:SetPoint("RIGHT", dup, "LEFT", -8, 0)
			sic.tex = sic:CreateTexture(nil, "ARTWORK")
			sic.tex:SetAllPoints()
			sic.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			sic.tex:SetTexture((select(2, SpellName(entry.spellID))) or "Interface\\Icons\\INV_Misc_QuestionMark")
			sic:EnableMouse(true)
			sic:SetScript("OnEnter", function(self)
				if not entry.spellID then return end
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetSpellByID(entry.spellID)
				GameTooltip:Show()
			end)
			sic:SetScript("OnLeave", function() GameTooltip:Hide() end)
			Wheel(dup, p)
			Wheel(sic, p)
			p:Blank()
		end
	end
end

---------------------------------------------------------------------------
-- Register
---------------------------------------------------------------------------
local PAGES = {
	{
		key = "cdmBars",
		name = "CDM Bars",
		description = "Your cooldowns, utility spells and buffs as icon bars, per specialization.",
		build = BuildBars,
		header = BarsHeader,
		pageKey = function() return "bars:" .. selBar .. ":" .. CDM.SpecKey() .. ":" .. rev end,
	},
	{
		key = "cdmBarGlows",
		name = "Bar Glows",
		description = "Action button and CDM icon glows driven by your buffs.",
		build = BuildBarGlows,
		header = BarGlowsHeader,
		pageKey = function() return "glows:" .. tostring(BGP.SelBar()) .. ":" .. tostring(BGP.sel) .. ":" .. CDM.SpecKey() .. ":" .. rev end,
	},
	{
		key = "cdmTracking",
		name = "Tracking Bars",
		description = "Buffs and debuffs as timer bars, per specialization.",
		build = BuildTracking,
		header = TrackingHeader,
		pageKey = function() return "tbb:" .. selTBB .. ":" .. tostring(selTBBGroup) .. ":" .. CDM.SpecKey() .. ":" .. rev end,
	},
}

ns.RegisterSettingsModule({
	key = "cdm",
	name = "Cooldown Manager",
	group = "Core Addons",
	tabs = PAGES,
	reset = function()
		CDM.Reset()
		selBar = "cooldowns"
		selTBB = 1
		CDM.Apply()
	end,
	resetTip = "Set all Cooldown Manager settings back to default (your retail Naowh settings).",
	onEnter = function() CDM._preview = true; CDM.SetPreview(true) end,
	onLeave = function() CDM._preview = false; CDM.SetPreview(false) end,
})
