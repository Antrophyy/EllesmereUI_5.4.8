-- Settings pages of Core Addons > Action Bars (EllesmereUI EUI_ActionBars_Options.lua
-- and ActionBars_Options\*: the same pages, sections, labels, tooltips and keys).
-- Pages: Bar Display (per bar, picked with "Edit Bar"), XP Bar, Menu, Bags &
-- Rep Bars, Bar Animations. Rows that need a retail-only API are left out
-- (textured border styles, custom shapes other than Cropped, End Caps, One
-- Button Assist, Show Item Rank, Hide Casting Animations, Skyriding paging,
-- CD swipe color, assisted highlight).
-- Part of EllesmereUIOptions (load on demand); skipped when EllesmereUIActionBars
-- is not loaded.

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUIActionBars") then
	return
end
local EAB = ns.EAB
if not EAB then
	return
end

local floor = math.floor
local sel = { bar = "MainBar" }
-- Unlock Mode cog "Element Options" picks the bar first (retail setter).
ns._setActionBarKey = function(key) if EAB and EAB.BAR_LOOKUP and EAB.BAR_LOOKUP[key] then sel.bar = key end end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function DB()
	return EAB.db.profile
end

local function SB(key)
	return DB().bars[key or sel.bar]
end

local function SVal(key, default, barKey)
	local v = SB(barKey)[key]
	if v == nil then
		return default
	end
	return v
end

local function Items(list)
	local out = {}
	for i = 1, #list do
		out[i] = { value = list[i][1], name = list[i][2] }
	end
	return out
end

local function LabelOf(list, value)
	for i = 1, #list do
		if list[i][1] == value then
			return list[i][2]
		end
	end
	return tostring(value or "")
end

local function Equal(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for k, v in pairs(a) do
		if not Equal(v, b[k]) then
			return false
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return false
		end
	end
	return true
end

-- Action bars only (retail GROUP_BAR_ORDER).
local GROUP = {}
for _, info in ipairs(EAB.BAR_CONFIG) do
	GROUP[#GROUP + 1] = info.key
end

-- "Apply to all Bars": copies keys from the selected bar to every bar.
local function Sync(p, tip, keys, filter)
	p:Sync(tip,
		function()
			local src = SB()
			for _, key in ipairs(GROUP) do
				if key ~= sel.bar and (not filter or filter(key)) then
					local dst = SB(key)
					for _, k in ipairs(keys) do
						dst[k] = EAB.DeepCopy(src[k])
					end
				end
			end
		end,
		function()
			local src = SB()
			for _, key in ipairs(GROUP) do
				if not filter or filter(key) then
					local dst = SB(key)
					for _, k in ipairs(keys) do
						if not Equal(src[k], dst[k]) then
							return false
						end
					end
				end
			end
			return true
		end)
end

local function Get(key, default)
	return function() return SVal(key, default) end
end

local function Set(key)
	return function(v) SB()[key] = v end
end

local function ColorGet(key, dr, dg, db, da, barKey)
	return function()
		local c = SB(barKey)[key]
		if type(c) ~= "table" then
			return dr, dg, db, da or 1
		end
		return c.r or dr, c.g or dg, c.b or db, c.a or da or 1
	end
end

local function ColorSet(key, alpha, barKey)
	return function(r, g, b, a)
		local s = SB(barKey)
		local c = {}
		c.r, c.g, c.b = r, g, b
		if alpha then
			c.a = a or 1
		elseif type(s[key]) == "table" then
			c.a = s[key].a
		end
		s[key] = c
	end
end

local function ProfileColorGet(key, dr, dg, db, da)
	return function()
		local c = DB()[key]
		if type(c) ~= "table" then
			return dr, dg, db, da or 1
		end
		return c.r or dr, c.g or dg, c.b or db, c.a or da or 1
	end
end

local function ProfileColorSet(key, alpha)
	return function(r, g, b, a)
		DB()[key] = { r = r, g = g, b = b, a = alpha and (a or 1) or nil }
	end
end

local function ClassColor()
	return EAB.ClassColor()
end

local function ReloadPopup(message)
	ns.ShowConfirmPopup({
		title = "Reload Required",
		message = message,
		confirmText = "Reload Now",
		cancelText = "Later",
		reload = true,
	})
end

local function NotRunning(p)
	if EAB:IsRunning() then
		return false
	end
	if EAB:IsDisabledByElvUI() then
		p:Paragraph("ElvUI's action bars are on, so EllesmereUI Action Bars stay off on this character.\nTurn off ElvUI > ActionBars > Enable and reload to use them.")
	else
		p:Paragraph("The action bars start at login (they cannot be built in combat).")
	end
	return true
end

---------------------------------------------------------------------------
-- Visibility checklist (retail BuildVisibilityRow: Never / Always /
-- Mouseover, match mode, Show / Hide lanes)
---------------------------------------------------------------------------
local function VisibilityItems()
	local items = {
		{ value = "state:never", name = "Never" },
		{ value = "state:always", name = "Always" },
		{ value = "state:mouseover", name = "Mouseover" },
		{ value = "match:all", name = "Match All Conditions" },
		{ value = "match:any", name = "Match Any Condition" },
	}
	for _, axis in ipairs(EAB.VIS_AXES) do
		items[#items + 1] = { value = "show:" .. axis.key, name = "Show: " .. axis.label }
		items[#items + 1] = { value = "hide:" .. axis.key, name = "Hide: " .. axis.label }
	end
	return items
end

local function Axis(key)
	for _, axis in ipairs(EAB.VIS_AXES) do
		if axis.key == key then
			return axis
		end
	end
end

local VIS_TIP = "When this bar is shown. Never / Always / Mouseover is the base state; the Show conditions must match (all or any), a Hide condition always hides. Bars switch in combat too (secure state drivers)."

local function VisibilityRow(p, barKey, label, tip)
	local function S() return SB(barKey) end
	p:MultiSelect(label or "Visibility", tip or VIS_TIP, VisibilityItems,
		function(value)
			local s = S()
			local kind, key = value:match("^(%a+):(.+)$")
			if kind == "state" then
				return EAB.VisBase(s) == key
			elseif kind == "match" then
				return (s.visibilityMatch or "all") == key
			end
			local axis = Axis(key)
			return EAB.VisFlag(s, kind == "show" and axis.show or axis.hide)
		end,
		function(value)
			local s = S()
			local kind, key = value:match("^(%a+):(.+)$")
			if kind == "state" then
				-- A legacy scalar mode (in_combat, ...) becomes its Show lane.
				local old = s.barVisibility
				if old and old ~= "always" and old ~= "never" and old ~= "mouseover" then
					EAB.SetVisFlag(s, old, true)
				end
				EAB.VisibilityCompat.ApplyMode(s, key)
				return
			elseif kind == "match" then
				s.visibilityMatch = key
				return
			end
			local axis = Axis(key)
			local laneKey = kind == "show" and axis.show or axis.hide
			local otherKey = kind == "show" and axis.hide or axis.show
			local on = not EAB.VisFlag(s, laneKey)
			EAB.SetVisFlag(s, laneKey, on)
			if on then
				EAB.SetVisFlag(s, otherKey, false)
			end
		end,
		function()
			local s = S()
			local base = EAB.VisBase(s)
			local text = base == "never" and "Never" or (base == "mouseover" and "Mouseover" or "Always")
			local n = 0
			for _, axis in ipairs(EAB.VIS_AXES) do
				if EAB.VisFlag(s, axis.show) or EAB.VisFlag(s, axis.hide) then
					n = n + 1
				end
			end
			if n > 0 and base ~= "never" then
				text = text .. " + " .. n .. (n == 1 and " condition" or " conditions")
			end
			return text
		end)
end

local VIS_KEYS = { "barVisibility", "alwaysHidden", "mouseoverEnabled", "mouseoverAlpha", "_savedBarAlpha",
	"combatShowEnabled", "combatHideEnabled", "visibilityModes", "visibilityMatch", "showInRaid", "showInParty",
	"showSolo", "dragShow", "spellbookShow", "clickThrough" }
for _, axis in ipairs(EAB.VIS_AXES) do
	if axis.show:match("^vis") then
		VIS_KEYS[#VIS_KEYS + 1] = axis.show
		VIS_KEYS[#VIS_KEYS + 1] = axis.hide
	end
end

---------------------------------------------------------------------------
-- Value lists (retail labels)
---------------------------------------------------------------------------
local BAR_LIST = {}
for _, info in ipairs(EAB.BAR_CONFIG) do
	BAR_LIST[#BAR_LIST + 1] = { info.key, info.label }
end
local ICON_ORDER = {
	{ "default", "Default" }, { "reversed", "Reversed" }, { "TOPLEFT", "Top Left" }, { "TOPRIGHT", "Top Right" },
	{ "BOTTOMLEFT", "Bottom Left" }, { "BOTTOMRIGHT", "Bottom Right" },
}
local GROW_H = { { "left", "Left" }, { "right", "Right" }, { "center", "Centered" } }
local GROW_V = { { "up", "Up" }, { "down", "Down" }, { "center", "Centered" } }
local SHAPES = { { "none", "None" }, { "cropped", "Cropped" } }
local BORDER_STYLES = { { "solid", "Solid" } }
local TEXT_ANCHORS = {
	{ "default", "Default" }, { "TOPLEFT", "Top Left" }, { "TOP", "Top" }, { "TOPRIGHT", "Top Right" },
	{ "BOTTOMLEFT", "Bottom Left" }, { "BOTTOM", "Bottom" }, { "BOTTOMRIGHT", "Bottom Right" },
}
local INTERACTION_TYPES = {
	{ 1, "Light" }, { 2, "Medium" }, { 3, "Strong" }, { 4, "Solid Color" }, { 5, "Border" }, { 6, "None" },
}
local PROC_GLOWS = { { 0, "None" }, { 1, "Pixel Glow" }, { 2, "Action Button Glow" }, { 3, "Auto-Cast Shine" } }
local GROW_X = { { "left", "Left" }, { "right", "Right" } }
local GROW_Y = { { "up", "Up" }, { "down", "Down" } }
local DATA_TEXT_POS = { { "center", "Center" }, { "left", "Left" }, { "right", "Right" }, { "top", "Top" }, { "bottom", "Bottom" } }

local function Dropdown(p, label, tip, list, get, set, isDisabled)
	p:Dropdown(label, tip, function() return Items(list) end, get,
		function() return LabelOf(list, get()) end, set, nil, isDisabled)
end

-- Text offsets cog (retail "<Text> Offsets": Position, X Offset, Y Offset).
local function TextCog(p, title, kind, anchorKey, oxKey, oyKey)
	p:Cog(title, {
		{ type = "dropdown", label = "Position", items = function() return Items(TEXT_ANCHORS) end,
		  get = function() return SB()[anchorKey] or "default" end,
		  set = function(v)
			local s = SB()
			local anchor = v ~= "default" and v or nil
			local prev = s[anchorKey] or nil
			if prev ~= anchor then
				-- the stock spacing moves with the position (retail SSeedTextOffsets)
				local px, py, nx, ny = 0, 0, 0, 0
				if prev then px, py = EAB.StockTextOffsets(kind, prev) end
				if anchor then nx, ny = EAB.StockTextOffsets(kind, anchor) end
				s[oxKey] = (s[oxKey] or 0) - px + nx
				s[oyKey] = (s[oyKey] or 0) - py + ny
			end
			s[anchorKey] = anchor or false
		  end },
		{ type = "slider", label = "X Offset", min = -150, max = 150, step = 1, get = Get(oxKey, 0), set = Set(oxKey) },
		{ type = "slider", label = "Y Offset", min = -150, max = 150, step = 1, get = Get(oyKey, 0), set = Set(oyKey) },
	}, { icon = "directions" })
end

---------------------------------------------------------------------------
-- Bar Display header (retail content header: Quick Keybind Mode key button,
-- the centered bar picker, the live preview and its hint)
---------------------------------------------------------------------------
local PREVIEW_MAX_H = 200
local HINT_H = 29
local CONTENT_PAD = 45

local function IsHintDismissed()
	return EllesmereUIDB and EllesmereUIDB.previewHintDismissed
end

local function IconFont(fs, size)
	local flags = ns.GetIconTextOutlineFlag and ns.GetIconTextOutlineFlag("actionBars") or "OUTLINE"
	fs:SetFont(ns.GetFontPath("actionBars"), size, flags)
	if not fs:GetFont() then
		fs:SetFont("Fonts\\ARIALN.TTF", size, flags)
	end
end

-- Default text placements of the real buttons (EUI_ActionBars_ButtonArt ApplyFonts).
local function PlaceKeybind(fs, bf, s)
	local ox, oy = s.keybindOffsetX or 0, s.keybindOffsetY or 0
	if not (s.keybindAnchor and EAB.PlaceButtonText(fs, bf, s.keybindAnchor, ox, oy)) then
		fs:ClearAllPoints()
		fs:SetPoint("TOPRIGHT", bf, "TOPRIGHT", -1 + ox, -3 + oy)
		fs:SetPoint("TOPLEFT", bf, "TOPLEFT", 4 + ox, -3 + oy)
		fs:SetJustifyH("RIGHT")
	end
end

local function PlaceCount(fs, bf, s)
	local ox, oy = s.countOffsetX or 0, s.countOffsetY or 0
	if not (s.countAnchor and EAB.PlaceButtonText(fs, bf, s.countAnchor, ox, oy)) then
		fs:ClearAllPoints()
		fs:SetPoint("BOTTOMRIGHT", bf, "BOTTOMRIGHT", -1 + ox, 4 + oy)
		fs:SetJustifyH("RIGHT")
	end
end

local function PlaceMacro(fs, bf, s)
	local ox, oy = s.macroOffsetX or 0, s.macroOffsetY or 0
	if not (s.macroAnchor and EAB.PlaceButtonText(fs, bf, s.macroAnchor, ox, oy)) then
		fs:ClearAllPoints()
		fs:SetPoint("BOTTOMLEFT", bf, "BOTTOMLEFT", 1 + ox, 4 + oy)
		fs:SetPoint("BOTTOMRIGHT", bf, "BOTTOMRIGHT", -1 + ox, 4 + oy)
		fs:SetJustifyH("CENTER")
	end
end

-- A clickable spot of the preview: hover tint, click reveals a setting.
local function HitOverlay(parent, onClick)
	local f = CreateFrame("Button", nil, parent)
	f:SetFrameLevel(parent:GetFrameLevel() + 3)
	local hl = f:CreateTexture(nil, "OVERLAY")
	hl:SetAllPoints()
	hl:SetTexture(1, 1, 1, 0.12)
	hl:Hide()
	f:SetScript("OnEnter", function() hl:Show() end)
	f:SetScript("OnLeave", function() hl:Hide() end)
	f:SetScript("OnClick", onClick)
	return f
end

-- The live preview of the selected bar: the bar's grid, icons, border, icon
-- background and texts at their real screen size (smaller when the bar does
-- not fit). Clicking an element scrolls to its setting.
local function CreatePreview(page, host, maxW, onClicked)
	local key = sel.bar
	local info = EAB.BAR_LOOKUP[key]
	local pv = CreateFrame("Frame", nil, host)
	pv:SetSize(1, 1)
	local entries = {}
	local function Reveal(section, label)
		return function()
			if onClicked then onClicked() end
			page:RevealSetting(section, label)
		end
	end
	for i = 1, info.count do
		local bf = CreateFrame("Frame", nil, pv)
		local bg = bf:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		local icon = bf:CreateTexture(nil, "ARTWORK")
		icon:SetAllPoints()
		local edges = {}
		for j = 1, 4 do
			edges[j] = bf:CreateTexture(nil, "OVERLAY", nil, 1)
		end
		local kb = bf:CreateFontString(nil, "OVERLAY", nil)
		kb:SetWordWrap(false)
		local ct = bf:CreateFontString(nil, "OVERLAY", nil)
		local mc = bf:CreateFontString(nil, "OVERLAY", nil)
		mc:SetWordWrap(false)
		local iconHit = HitOverlay(bf, Reveal("Icons", "Border Size"))
		iconHit:SetAllPoints(bf)
		local kbHit = HitOverlay(bf, Reveal("Text", "Keybind Text Size"))
		kbHit:SetFrameLevel(iconHit:GetFrameLevel() + 1)
		local ctHit = HitOverlay(bf, Reveal("Text", "Charges Text Size"))
		ctHit:SetFrameLevel(iconHit:GetFrameLevel() + 1)
		entries[i] = { frame = bf, bg = bg, icon = icon, edges = edges, keybind = kb, count = ct, macro = mc,
			kbHit = kbHit, ctHit = ctHit }
	end

	function pv:Update()
		local s = SB(key)
		local d = DB()
		local real = EAB.barButtons and EAB.barButtons[key] or {}
		local scale = UIParent:GetEffectiveScale() / host:GetEffectiveScale()
		local layout, frameW, frameH, numIcons = EAB:ComputeLayout(key, 1)
		local fit = math.min(1, maxW / (frameW * scale), PREVIEW_MAX_H / (frameH * scale))
		self:SetScale(scale * fit)
		self:SetSize(frameW, frameH)
		self.drawnH = frameH * scale * fit
		local px = 768 / (ns.PhysicalHeight and ns.PhysicalHeight() or 1080) / self:GetEffectiveScale()
		-- border
		local e = EAB.BORDER_THICKNESS[s.borderThickness or "thin"] or EAB.BORDER_THICKNESS.thin
		local bsize = (s.borderEnabled == false) and 0 or e.regular * px
		local bc = s.borderColor or { r = 0, g = 0, b = 0, a = 1 }
		local br, bg, bb, ba = bc.r or 0, bc.g or 0, bc.b or 0, bc.a or 1
		if s.borderClassColor then br, bg, bb = EAB.ClassColor() end
		local sc = d.slotBgColor or { r = 0.15, g = 0.15, b = 0.15 }
		local so = (d.slotBgOpacity == nil and 50 or d.slotBgOpacity) / 100
		local z = (s.iconZoom or d.iconZoom or 5.5) / 100
		local small = info.isStance or info.isPetBar
		local kbSize = s.keybindFontSize or 12
		local mcSize = s.macroFontSize or 12
		if small then kbSize, mcSize = math.max(kbSize - 2, 6), math.max(mcSize - 2, 6) end
		local kc = s.keybindFontColor or { r = 1, g = 1, b = 1 }
		local cc = s.countFontColor or { r = 1, g = 1, b = 1 }
		local mcol = s.macroFontColor or { r = 1, g = 1, b = 1 }
		for i, en in ipairs(entries) do
			local L = layout[i]
			local bf = en.frame
			if not L then
				bf:Hide()
			else
				bf:ClearAllPoints()
				bf:SetPoint(L.anchor, self, L.anchor, L.x, L.y)
				bf:SetSize(L.w, L.h)
				bf:Show()
				local rb = real[i]
				local tex = rb and rb.icon and rb.icon:IsShown() and rb.icon:GetTexture()
				en.bg:SetTexture(sc.r or 0.15, sc.g or 0.15, sc.b or 0.15, so)
				if tex then
					en.icon:SetTexture(tex)
					if s.buttonShape == "cropped" then
						en.icon:SetTexCoord(z, 1 - z, z + 0.10, 1 - z - 0.10)
					else
						en.icon:SetTexCoord(z, 1 - z, z, 1 - z)
					end
					en.icon:Show()
				else
					en.icon:Hide()
				end
				-- 1 px (Border Size) edges inside the button
				local ed = en.edges
				if bsize > 0 then
					ed[1]:ClearAllPoints(); ed[1]:SetPoint("TOPLEFT"); ed[1]:SetPoint("TOPRIGHT"); ed[1]:SetHeight(bsize)
					ed[2]:ClearAllPoints(); ed[2]:SetPoint("BOTTOMLEFT"); ed[2]:SetPoint("BOTTOMRIGHT"); ed[2]:SetHeight(bsize)
					ed[3]:ClearAllPoints(); ed[3]:SetPoint("TOPLEFT", ed[1], "BOTTOMLEFT"); ed[3]:SetPoint("BOTTOMLEFT", ed[2], "TOPLEFT"); ed[3]:SetWidth(bsize)
					ed[4]:ClearAllPoints(); ed[4]:SetPoint("TOPRIGHT", ed[1], "BOTTOMRIGHT"); ed[4]:SetPoint("BOTTOMRIGHT", ed[2], "TOPRIGHT"); ed[4]:SetWidth(bsize)
					for j = 1, 4 do
						ed[j]:SetTexture(br, bg, bb, ba)
						ed[j]:Show()
					end
				else
					for j = 1, 4 do ed[j]:Hide() end
				end
				-- texts (the real buttons' current text)
				IconFont(en.keybind, kbSize)
				en.keybind:SetHeight(kbSize + 4)
				en.keybind:SetTextColor(kc.r or 1, kc.g or 1, kc.b or 1)
				PlaceKeybind(en.keybind, bf, s)
				en.keybind:SetText((not s.hideKeybind and rb and rb.HotKey and rb.HotKey:GetText()) or "")
				IconFont(en.count, s.countFontSize or 12)
				en.count:SetTextColor(cc.r or 1, cc.g or 1, cc.b or 1)
				PlaceCount(en.count, bf, s)
				en.count:SetText((rb and rb.Count and rb.Count:GetText()) or "")
				en.macro:SetFont(ns.GetFontPath("actionBars"), mcSize, "OUTLINE")
				en.macro:SetHeight(mcSize + 4)
				en.macro:SetTextColor(mcol.r or 1, mcol.g or 1, mcol.b or 1)
				PlaceMacro(en.macro, bf, s)
				en.macro:SetText((not s.hideMacroText and rb and rb.Name and rb.Name:GetText()) or "")
				-- hit spots over the texts
				en.kbHit:ClearAllPoints()
				en.kbHit:SetPoint("TOPRIGHT", bf, "TOPRIGHT", 0, 0)
				en.kbHit:SetSize(L.w * 0.6, kbSize + 4)
				en.ctHit:ClearAllPoints()
				en.ctHit:SetPoint("BOTTOMRIGHT", bf, "BOTTOMRIGHT", 0, 0)
				en.ctHit:SetSize(L.w * 0.5, (s.countFontSize or 12) + 4)
				en.ctHit:SetShown((en.count:GetText() or "") ~= "")
				en.kbHit:SetShown((en.keybind:GetText() or "") ~= "")
			end
		end
	end
	return pv
end

local function BuildBarHeader(page, host, width)
	if not EAB:IsRunning() then
		return 0
	end
	local DD_H, DD_W, KB_GAP = 34, 350, 5
	local top = 20

	local dd = page:HeaderDropdown(host, DD_W, DD_H, function() return Items(BAR_LIST) end,
		function() return sel.bar end, function() return LabelOf(BAR_LIST, sel.bar) end,
		function(v)
			sel.bar = v
			if ns.RebuildSettingsPage then
				ns.RebuildSettingsPage()
			end
		end)
	dd:SetPoint("TOP", host, "TOP", (DD_H + KB_GAP) / 2, -top)

	local kb = page:HeaderIconButton(host, DD_H, ns.MEDIA .. "ui\\eui-keyboard", 24, "Quick Keybind Mode (/kb)", function()
		if InCombatLockdown() then
			return
		end
		if ns.ToggleSettingsWindow then
			ns.ToggleSettingsWindow()
		end
		EAB:OpenQuickKeybind()
	end)
	kb:SetPoint("RIGHT", dd, "LEFT", -KB_GAP, 0)

	local hint = host:CreateFontString(nil, "OVERLAY")
	hint:SetFont(ns.FONT, 11, "")
	if not hint:GetFont() then
		hint:SetFont("Fonts\\ARIALN.TTF", 11, "")
	end
	hint:SetTextColor(1, 1, 1, 0.45)
	hint:SetText("Click elements to scroll to and highlight their options")
	hint:SetPoint("BOTTOM", host, "BOTTOM", 0, 17)

	local pv
	local function Height()
		local h = top + DD_H + 10 + (pv.drawnH or 0) + 10
		if not IsHintDismissed() then
			h = h + HINT_H
		end
		return h
	end
	local function Relayout()
		pv:Update()
		hint:SetShown(not IsHintDismissed())
		page:SetHeaderHeight(Height())
	end
	pv = CreatePreview(page, host, width - CONTENT_PAD * 2, function()
		if not IsHintDismissed() then
			EllesmereUIDB.previewHintDismissed = true
			Relayout()
		end
	end)
	-- The preview runs at its own scale: its TOP point is placed in its units.
	local function Place()
		local s = pv:GetScale()
		pv:ClearAllPoints()
		pv:SetPoint("TOP", host, "TOP", 0, -(top + DD_H + 10) / (s > 0 and s or 1))
	end
	page:OnRefresh(function()
		if host:IsShown() then
			Relayout()
			Place()
		end
	end)
	host:HookScript("OnShow", function()
		Relayout()
		Place()
	end)
	pv:Update()
	Place()
	hint:SetShown(not IsHintDismissed())
	return Height()
end

---------------------------------------------------------------------------
-- Bar Display page
---------------------------------------------------------------------------
local function BuildBarDisplay(p)
	if NotRunning(p) then
		return
	end
	local info = EAB.BAR_LOOKUP[sel.bar]
	local _, class = UnitClass("player")
	if sel.bar == "Bar10" and class == "DRUID" then
		p:Paragraph("This Action Bar is also used as the Moonkin Form bar.\nChanging spells on a Druid for this bar will also change them on your Moonkin Form bar.")
	elseif sel.bar == "Bar10" and class == "WARRIOR" then
		p:Paragraph("5.4.8: this Action Bar uses action page 10, which no stance of yours uses.")
	end

	---------------------------------------------------------------------
	-- VISIBILITY
	---------------------------------------------------------------------
	p:Section("Visibility")
	VisibilityRow(p, nil)
	Sync(p, "Apply Visibility to all Bars", VIS_KEYS)
	p:Cog("Visibility", {
		{ type = "toggle", label = "Show When Spellbook Is Open",
		  tip = "While the spellbook or macro panel is open, this bar appears so you can drag abilities onto it.",
		  get = function() return SB().spellbookShow == true end,
		  set = function(v) SB().spellbookShow = v or nil end },
		{ type = "toggle", label = "Show During Drag",
		  tip = "While dragging a spell or item, this bar appears so you can drop onto it.",
		  get = function() return SB().dragShow == true end,
		  set = function(v) SB().dragShow = v end,
		  disabled = function() return EAB.VisBase(SB()) ~= "never" end },
		{ type = "toggle", label = "Click Through", get = Get("clickThrough", false), set = Set("clickThrough") },
	})
	p:Keybind("Toggle Action Bar", "Toggling an action bar is only available out of combat\n\nLeft-click to set a keybind.\nRight-click to unbind.",
		function() return SB().toggleVisKey end,
		function(v) SB().toggleVisKey = v end,
		function()
			local base = EAB.VisBase(SB())
			return base ~= "always" and base ~= "never"
		end)

	p:Slider("Bar Opacity", "Opacity of the bar (while shown; Mouseover bars fade to this when hovered).", 0, 100, 5,
		function()
			local s = SB()
			if s.mouseoverEnabled then
				return floor((s._savedBarAlpha or 1) * 100 + 0.5)
			end
			return floor((s.mouseoverAlpha or 1) * 100 + 0.5)
		end,
		function(v)
			local s = SB()
			if s.mouseoverEnabled then
				s._savedBarAlpha = v / 100
			else
				s.mouseoverAlpha = v / 100
			end
		end)
	Sync(p, "Apply Bar Opacity to all Bars", { "mouseoverAlpha", "_savedBarAlpha" })
	p:Toggle("Always Show Buttons", "Show button backgrounds even if a spell is not assigned to that slot.",
		function() return SB().alwaysShowButtons ~= false end,
		function(v) SB().alwaysShowButtons = v end)

	p:Toggle("Show All Bars on Mouseover", "Hovering one Mouseover bar shows them all.",
		function() return DB().mouseoverShowAll or false end,
		function(v) DB().mouseoverShowAll = v end,
		function()
			for _, s in pairs(DB().bars) do
				if type(s) == "table" and s.mouseoverEnabled then
					return false
				end
			end
			return true
		end)
	p:Blank()

	---------------------------------------------------------------------
	-- LAYOUT
	---------------------------------------------------------------------
	p:Section("Layout")
	p:Slider("Icon Size", "Size of the bar's buttons.", 16, 120, 1,
		function()
			local w = EAB:ButtonSize(sel.bar)
			return floor(w + 0.5)
		end,
		function(v)
			local s = SB()
			s.buttonWidth, s.buttonHeight = v, v
			s._matchExtraPixels, s._matchExtraPixelsH = nil, nil
		end)
	Sync(p, "Apply Icon Size to all Bars", { "buttonWidth", "buttonHeight", "_matchExtraPixels", "_matchExtraPixelsH" })
	p:Slider("Button Spacing", "Space between the buttons, in pixels.", -10, 20, 1, Get("buttonPadding", 2), Set("buttonPadding"))
	Sync(p, "Apply Button Spacing to all Bars", { "buttonPadding" })

	p:Slider("Number of Icons", "How many buttons the bar shows.", 1, info.count, 1,
		function()
			local v = SB().overrideNumIcons
			if v and v > 0 then return v end
			return SB().numIcons or info.count
		end,
		Set("overrideNumIcons"),
		function() return info.isStance end)
	Sync(p, "Apply Number of Icons to all Bars", { "overrideNumIcons" })
	p:Slider("Number of Rows", "Rows the buttons are split into (columns on a vertical bar).", 1, 12, 1,
		function()
			local v = SB().overrideNumRows
			if v and v > 0 then return v end
			return SB().numRows or 1
		end,
		Set("overrideNumRows"))
	Sync(p, "Apply Number of Rows to all Bars", { "overrideNumRows" })
	p:Cog("Row Settings", {
		{ type = "dropdown", label = "Grow Direction",
		  items = function() return Items(SB().orientation == "vertical" and GROW_V or GROW_H) end,
		  get = function()
			local list = SB().orientation == "vertical" and GROW_V or GROW_H
			local v = SVal("growDirection", "up")
			for _, e in ipairs(list) do
				if e[1] == v then return v end
			end
			return "center"
		  end,
		  set = Set("growDirection") },
	})

	p:Toggle("Vertical Orientation", "Lay the buttons out top to bottom.",
		function() return not EAB:GetOrientationForBar(sel.bar) end,
		function(v) EAB:SetOrientationForBar(sel.bar, not v) end)
	Sync(p, "Apply Orientation to all Bars", { "orientation", "growDirection" })
	Dropdown(p, "Icon Order", "Default fills from the first button; Reversed flips the order; a corner puts button 1 in that corner.",
		ICON_ORDER,
		function()
			local v = SB().iconOrder
			if v == nil then
				v = SB().reverseIconOrder and "reversed" or "default"
			end
			return v
		end,
		function(v)
			SB().reverseIconOrder = (v == "reversed")
			SB().iconOrder = v
		end)

	-- End Caps (retail BarVisibilityLayout_Options.lua EndCapsCtl): gryphons
	-- at the ends of a horizontal bar.
	local function CapsVertical() return not EAB:GetOrientationForBar(sel.bar) end
	p:MultiSelect("End Caps", "Gryphon art at the left and right end of the bar. Horizontal bars only.",
		function() return { { value = "L", name = "Left Endcap" }, { value = "R", name = "Right Endcap" } } end,
		function(v) return SB()[v == "L" and "endCapLeft" or "endCapRight"] == true end,
		function(v)
			local k = v == "L" and "endCapLeft" or "endCapRight"
			SB()[k] = not (SB()[k] == true)
		end,
		function()
			local l, r = SB().endCapLeft == true, SB().endCapRight == true
			if l and r then return "Left, Right" end
			return (l and "Left") or (r and "Right") or "None"
		end, CapsVertical)
	p:Cog("End Cap Settings", {
		{ type = "dropdown", label = "Art", tip = "Gryphon end caps of the 5.4.8 main bar.",
		  items = function() return Items({ { "blizzard", "Gryphon" }, { "classic", "Classic Gryphon" } }) end,
		  get = Get("endCapArt", "blizzard"), set = Set("endCapArt") },
		{ type = "slider", label = "Size", min = 50, max = 200, step = 5, tip = "Percent of the end caps' normal size.",
		  get = Get("endCapScale", 100), set = Set("endCapScale") },
		{ type = "slider", label = "X Offset", min = -100, max = 100, step = 1, tip = "Positive values move both end caps away from the bar.",
		  get = Get("endCapOffsetX", 0), set = Set("endCapOffsetX") },
		{ type = "slider", label = "Y Offset", min = -100, max = 100, step = 1,
		  get = Get("endCapOffsetY", 5), set = Set("endCapOffsetY") },
	}, { disabled = function() return CapsVertical() or not (SB().endCapLeft or SB().endCapRight) end })
	Sync(p, "Apply End Caps to all Bars", { "endCapLeft", "endCapRight", "endCapArt", "endCapScale", "endCapOffsetX", "endCapOffsetY" })
	p:Blank()

	---------------------------------------------------------------------
	-- ICONS
	---------------------------------------------------------------------
	p:Section("Icons")
	Dropdown(p, "Border Style", "Border art of the buttons. 5.4.8 draws the Solid style only (textured border styles need retail border backdrops).",
		BORDER_STYLES, function() return "solid" end, function() end)
	p:Slider("Border Size", "Thickness of the button border in pixels (0 = no border).", 0, 4, 1,
		function()
			local s = SB()
			local e = EAB.BORDER_THICKNESS[s.borderThickness or "thin"] or EAB.BORDER_THICKNESS.thin
			if s.borderEnabled == false then return 0 end
			return e.regular
		end,
		function(v)
			local s = SB()
			s.borderThickness = EAB.BORDER_LABEL_OF_STEP[v] or "thin"
			s.borderSize = v
			s.borderEnabled = v > 0
		end)
	p:Swatch("Class Colored", ClassColor, function() end, {
		readonly = true,
		active = function() return SB().borderClassColor and true or false end,
		onClick = function() SB().borderClassColor = true return true end,
	})
	p:Swatch("Custom Color", ColorGet("borderColor", 0, 0, 0, 1), ColorSet("borderColor", true), {
		alpha = true,
		active = function() return not SB().borderClassColor end,
		onClick = function()
			if SB().borderClassColor then
				SB().borderClassColor = false
				return true
			end
		end,
	})
	Sync(p, "Apply Border Size and Color to all Bars", { "borderThickness", "borderSize", "borderEnabled", "borderColor", "borderClassColor" })
	p:Cog("Border Options", {
		{ type = "toggle", label = "Show Behind", get = Get("borderBehind", false), set = Set("borderBehind") },
		{ type = "toggle", label = "Border Above Effects",
		  tip = "Draws this bar's button borders over proc glows and the cooldown swipe.",
		  get = Get("borderAboveEffects", false), set = Set("borderAboveEffects"),
		  disabled = function() return SB().borderBehind and true or false end },
	}, { icon = "directions" })

	Dropdown(p, "Custom Button Shape", "Cropped makes the buttons wider than tall. 5.4.8 has no mask textures, so the round and other custom shapes are not available.",
		SHAPES, function() return SB().buttonShape == "cropped" and "cropped" or "none" end,
		function(v)
			local s = SB()
			s.iconZoom = EAB.SHAPE_ZOOM_DEFAULTS[v] or 5.5
			s.buttonShape = v
			s.borderThickness = "thin"
			s.borderSize = 1
			s.borderEnabled = true
			if v == "cropped" then
				s.keybindFontSize, s.countFontSize = 11, 11
				EAB.ApplyShapeTextOffsets(s, 0, 1, 0, -1)
			else
				s.keybindFontSize, s.countFontSize = 12, 12
				EAB.ApplyShapeTextOffsets(s, 0, 0, 0, 0)
			end
		end)
	Sync(p, "Apply Custom Button Shape to all Bars", { "buttonShape", "iconZoom", "keybindFontSize", "countFontSize",
		"keybindOffsetX", "keybindOffsetY", "countOffsetX", "countOffsetY" })
	p:Slider("Icon Zoom", "Crops the edge of every icon (percent of each side).", 0, 10, 0.5,
		function() return SVal("iconZoom", DB().iconZoom or 5.5) end, Set("iconZoom"))
	Sync(p, "Apply Icon Zoom to all Bars", { "iconZoom" })

	p:Toggle("Blizzard Icon Background", "Shows Blizzard's slot art on empty slots.",
		function() return DB().showBlizzIconBg or false end,
		function(v) DB().showBlizzIconBg = v end)
	p:Cog("Icon Background", {
		{ type = "slider", label = "Opacity", min = 0, max = 100, step = 1,
		  tip = "Controls the opacity of the Blizzard icon slot background texture.",
		  get = function() return floor((DB().blizzIconBgAlpha or 1) * 100 + 0.5) end,
		  set = function(v) DB().blizzIconBgAlpha = v / 100 end },
	}, { disabled = function() return not DB().showBlizzIconBg end, disabledTip = "Blizzard Icon Background" })
	p:Toggle("Cooldown Numbers", "Shows the time left on cooldowns as numbers on the buttons (5.4.8 has no numbers of its own; this port draws them).",
		function() return DB().cooldownNumbers ~= false end,
		function(v) DB().cooldownNumbers = v end)
	p:Cog("Cooldown Numbers", {
		{ type = "toggle", label = "Charge Recharge Numbers",
		  tip = "Show the recharge countdown on charge spells while a charge is still banked. When off, the recharge timer only appears at 0 charges (Blizzard default).",
		  get = function() return DB().showChargeRechargeNumbers ~= false end,
		  set = function(v) DB().showChargeRechargeNumbers = v end },
	}, { disabled = function() return DB().cooldownNumbers == false end, disabledTip = "Cooldown Numbers" })

	p:Slider("Icon Background", "Opacity of the flat background behind every button icon; the swatch sets its color.", 0, 100, 1,
		function() local v = DB().slotBgOpacity if v == nil then v = 50 end return v end,
		function(v) DB().slotBgOpacity = v end)
	p:Swatch("Icon Background Color", ProfileColorGet("slotBgColor", 0.15, 0.15, 0.15),
		ProfileColorSet("slotBgColor"), { disabled = function() return (DB().slotBgOpacity or 50) == 0 end })
	p:Blank()

	---------------------------------------------------------------------
	-- ICON EFFECTS
	---------------------------------------------------------------------
	p:Section("Icon Effects")
	p:Toggle("Desaturate on Cooldown", "Desaturates (grays out) action button icons while the ability is on cooldown. GCD-only cooldowns are excluded.",
		function() return DB().desaturateOnCooldown or false end,
		function(v) DB().desaturateOnCooldown = v end)
	p:Toggle("Disable Tooltips", "No tooltip when the mouse is over this bar's buttons.", Get("disableTooltips", false), Set("disableTooltips"))
	Sync(p, "Apply Disable Tooltips to all Bars", { "disableTooltips" })

	p:Toggle("Out of Range Coloring", "Tints the icon while the target is out of range of the action.", Get("outOfRangeColoring", false), Set("outOfRangeColoring"))
	p:Swatch("Out of Range Color", ColorGet("outOfRangeColor", 0.8, 0.1, 0.1), ColorSet("outOfRangeColor"),
		{ disabled = function() return not SB().outOfRangeColoring end })
	Sync(p, "Apply Range Coloring to all Bars", { "outOfRangeColoring", "outOfRangeColor" })
	p:Blank()

	p:Slider("Alpha when on CD", "Dims action button icons to this opacity while on cooldown (100 = off), using the same detection as Desaturate on Cooldown.", 0, 100, 5,
		function() return DB().alphaWhenOnCD or 100 end,
		function(v) DB().alphaWhenOnCD = v end)
	p:Slider("CD Swipe Opacity", "Opacity of the cooldown swipe (the dark radial sweep). 5.4.8 cannot recolor the swipe.", 0, 100, 5,
		function() return DB().cdSwipeAlpha or 80 end,
		function(v) DB().cdSwipeAlpha = v end)

	p:Toggle("Hide Charge Count at 0", "Hide the charge number on action buttons when it reaches 0, instead of showing a 0. The number returns as soon as a charge or item comes back.",
		function() return DB().hideZeroCount or false end,
		function(v) DB().hideZeroCount = v or nil end)
	p:Toggle("Show Equipped Item Color", "Equipped items get a rarity color border.",
		function() return DB().showEquippedBorder or false end,
		function(v) DB().showEquippedBorder = v and true or false end)

	---------------------------------------------------------------------
	-- BAR BACKGROUND
	---------------------------------------------------------------------
	p:Section("Bar Background")
	local function BgOff() return not SB().bgEnabled end
	p:Toggle("Enable Bar Background", "A colored backdrop behind the whole bar.", Get("bgEnabled", false),
		function(v)
			SB().bgEnabled = v
			if ns.RebuildSettingsPage then ns.RebuildSettingsPage() end
		end)
	Sync(p, "Apply Bar Background Enable to all Bars", { "bgEnabled" })
	p:Slider("Spacing", "Space between the buttons and the background edge.", 0, 20, 1,
		function()
			local v = SB().bgPadding
			if v ~= nil then return v end
			return math.max(SB().bgPadX or 0, SB().bgPadY or 0)
		end,
		function(v)
			SB().bgPadX, SB().bgPadY = nil, nil
			SB().bgPadding = v
		end, BgOff)
	Sync(p, "Apply Bar Background Spacing to all Bars", { "bgPadding", "bgPadX", "bgPadY" })
	if SB().bgEnabled then
		p:ColorRow("Background Color", nil,
			function()
				local c = SB().bgColor or { r = 0, g = 0, b = 0 }
				return c.r, c.g, c.b, 1
			end,
			function(r, g, b)
				local old = SB().bgColor or { a = 0.5 }
				SB().bgColor = { r = r, g = g, b = b, a = old.a or 0.5 }
			end, nil, BgOff)
		Sync(p, "Apply Background Color to all Bars", { "bgColor" })
		p:Slider("Background Opacity", nil, 0, 100, 1,
			function()
				local s = SB()
				if s.bgOpacity ~= nil then return s.bgOpacity end
				return ((s.bgColor and s.bgColor.a) or 0.5) * 100
			end,
			Set("bgOpacity"), BgOff)
		Sync(p, "Apply Background Opacity to all Bars", { "bgOpacity" })

		Dropdown(p, "Border Style", "Border art of the background. 5.4.8 draws the Solid style only.", BORDER_STYLES,
			function() return "solid" end, function() end, BgOff)
		p:Cog("Border Options", {
			{ type = "toggle", label = "Show Behind", get = Get("bgBorderBehind", false), set = Set("bgBorderBehind") },
		}, { icon = "directions", disabled = BgOff, disabledTip = "Bar Background" })
		p:Slider("Border Size", "Thickness of the background border in pixels.", 0, 4, 1,
			function()
				local e = EAB.BORDER_THICKNESS[SB().bgBorderThickness or "none"]
				return e and e.regular or 0
			end,
			function(v) SB().bgBorderThickness = EAB.BORDER_LABEL_OF_STEP[v] or "none" end, BgOff)
		p:Swatch("Border Color", ColorGet("bgBorderColor", 0, 0, 0, 1), ColorSet("bgBorderColor", true),
			{ alpha = true, disabled = function() return BgOff() or (SB().bgBorderThickness or "none") == "none" end })
		Sync(p, "Apply Background Border Size and Color to all Bars", { "bgBorderThickness", "bgBorderColor", "bgBorderBehind" })

		p:Slider("Multiplier X", "Makes the background this many bar widths wide.", 1, 4, 1, Get("bgMultiplierX", 1), Set("bgMultiplierX"), BgOff)
		p:Cog("Multiplier X Settings", {
			{ type = "dropdown", label = "Growth Direction", items = function() return Items(GROW_X) end,
			  get = Get("bgExpandDirectionX", "right"), set = Set("bgExpandDirectionX") },
		}, { icon = "directions", disabled = BgOff })
		p:Slider("Multiplier Y", "Makes the background this many bar heights tall.", 1, 4, 1, Get("bgMultiplierY", 1), Set("bgMultiplierY"), BgOff)
		p:Cog("Multiplier Y Settings", {
			{ type = "dropdown", label = "Growth Direction", items = function() return Items(GROW_Y) end,
			  get = Get("bgExpandDirectionY", "up"), set = Set("bgExpandDirectionY") },
		}, { icon = "directions", disabled = BgOff })
	else
		p:Blank()
	end

	---------------------------------------------------------------------
	-- PAGING (bars on an action page)
	---------------------------------------------------------------------
	if EAB.BAR_KEY_TO_PAGE[sel.bar] then
		p:Section("Paging")
		local pageValues = { { "none", "Default" } }
		for _, bl in ipairs(EAB.BAR_CONFIG) do
			local pg = EAB.BAR_KEY_TO_PAGE[bl.key]
			if pg and bl.key ~= sel.bar then
				pageValues[#pageValues + 1] = { tostring(pg), bl.label }
			end
		end
		local function PageGet(id)
			return function()
				local paging = SB().paging
				local v = paging and paging[id]
				return v and tostring(v) or "none"
			end
		end
		local function PageSet(id)
			return function(v)
				local s = SB()
				s.paging = s.paging or {}
				if v == "none" then
					s.paging[id] = nil
				else
					s.paging[id] = tonumber(v)
				end
			end
		end
		local function ModTargetOn()
			local v = SB().modTargetPaging
			if v ~= nil then return v end
			local paging = SB().paging
			if paging then
				for id in pairs(EAB.MOD_TARGET_PAGING) do
					if paging[id] then return true end
				end
			end
			return false
		end
		if sel.bar == "MainBar" then
			p:Toggle("Disable Form Paging", "Keeps this bar on its page in any form or stance.", Get("disableFormPaging", false), Set("disableFormPaging"))
			p:Toggle("Paging Arrows", "Arrows beside Action Bar 1 that page it up and down, with the page number between them.",
				Get("showPagingArrows", false), Set("showPagingArrows"))
			p:Cog("Paging Arrow Settings", {
				{ type = "toggle", label = "Show Arrows on Right", get = Get("pagingArrowsRight", false), set = Set("pagingArrowsRight") },
			}, { disabled = function() return not SB().showPagingArrows end, disabledTip = "Paging Arrows" })
			p:Toggle("Skip Visible Bars When Paging", "Next and previous page, from the paging arrows, skip the pages your other enabled bars use.",
				Get("skipVisiblePagingBars", false), Set("skipVisiblePagingBars"))
		end
		p:Toggle("Modifier/Target Paging", "Page this bar while Shift, Ctrl or Alt is held or while you target a friend or an enemy.",
			ModTargetOn,
			function(v)
				SB().modTargetPaging = v and true or false
				if ns.RebuildSettingsPage then ns.RebuildSettingsPage() end
			end)
		if ModTargetOn() then
			Dropdown(p, "Shift Modifier", nil, pageValues, PageGet("shift"), PageSet("shift"))
			Dropdown(p, "Ctrl Modifier", nil, pageValues, PageGet("ctrl"), PageSet("ctrl"))
			Dropdown(p, "Alt Modifier", nil, pageValues, PageGet("alt"), PageSet("alt"))
			Dropdown(p, "Friendly Target", nil, pageValues, PageGet("help"), PageSet("help"))
			Dropdown(p, "Hostile Target", nil, pageValues, PageGet("harm"), PageSet("harm"))
		end
		local states = EAB.PAGING_STATES.class[class]
		if states then
			for _, st in ipairs(states) do
				Dropdown(p, st.label, nil, pageValues, PageGet(st.id), PageSet(st.id))
			end
		end
		p:CloseRow()
	end

	---------------------------------------------------------------------
	-- TEXT
	---------------------------------------------------------------------
	p:Section("Text")
	p:Toggle("Hide Keybind Text", nil, Get("hideKeybind", false), Set("hideKeybind"))
	Sync(p, "Apply Keybind Visibility to all Bars", { "hideKeybind" })
	p:Slider("Keybind Text Size", nil, 6, 30, 1, Get("keybindFontSize", 12), Set("keybindFontSize"))
	p:Swatch("Keybind Text Color", ColorGet("keybindFontColor", 1, 1, 1), ColorSet("keybindFontColor"))
	TextCog(p, "Keybind Text Offsets", "keybind", "keybindAnchor", "keybindOffsetX", "keybindOffsetY")
	Sync(p, "Apply Keybind Text Settings to all Bars", { "keybindFontColor", "keybindFontSize", "keybindOffsetX", "keybindOffsetY", "keybindAnchor" })

	p:Toggle("Hide Macro Text", nil, Get("hideMacroText", false), Set("hideMacroText"))
	Sync(p, "Apply Macro Text Visibility to all Bars", { "hideMacroText" })
	p:Slider("Macro Text Size", nil, 6, 30, 1, Get("macroFontSize", 12), Set("macroFontSize"))
	p:Swatch("Macro Text Color", ColorGet("macroFontColor", 1, 1, 1), ColorSet("macroFontColor"))
	TextCog(p, "Macro Text Offsets", "macro", "macroAnchor", "macroOffsetX", "macroOffsetY")
	Sync(p, "Apply Macro Text Settings to all Bars", { "macroFontColor", "macroFontSize", "macroOffsetX", "macroOffsetY", "macroAnchor" })

	p:Slider("Charges Text Size", nil, 6, 30, 1, Get("countFontSize", 12), Set("countFontSize"))
	p:Swatch("Charges Text Color", ColorGet("countFontColor", 1, 1, 1), ColorSet("countFontColor"))
	TextCog(p, "Charges Text Offsets", "count", "countAnchor", "countOffsetX", "countOffsetY")
	Sync(p, "Apply Charges Text Settings to all Bars", { "countFontColor", "countFontSize", "countOffsetX", "countOffsetY", "countAnchor" })
	p:Slider("Cooldown Text Size", nil, 6, 30, 1, Get("cooldownFontSize", 12), Set("cooldownFontSize"))
	p:Swatch("Cooldown Text Color", ColorGet("cooldownTextColor", 1, 1, 1), ColorSet("cooldownTextColor"))
	p:Cog("Cooldown Text", {
		{ type = "slider", label = "X Offset", min = -150, max = 150, step = 1, get = Get("cooldownTextXOffset", 0), set = Set("cooldownTextXOffset") },
		{ type = "slider", label = "Y Offset", min = -150, max = 150, step = 1, get = Get("cooldownTextYOffset", 0), set = Set("cooldownTextYOffset") },
		{ type = "toggle", label = "Fit Size to Button", tip = "Caps the countdown size so it cannot spill outside small buttons.",
		  get = Get("cooldownFontFit", false), set = function(v) SB().cooldownFontFit = v and true or false end },
	}, { icon = "directions" })
	Sync(p, "Apply Cooldown Text Settings to all Bars", { "cooldownTextColor", "cooldownFontSize", "cooldownTextXOffset", "cooldownTextYOffset", "cooldownFontFit" })
end

---------------------------------------------------------------------------
-- Data bar rows (XP / Reputation)
---------------------------------------------------------------------------
local function TextureItems()
	local items = { { value = "none", name = "None" } }
	local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
	if lsm then
		for _, name in ipairs(lsm:List("statusbar")) do
			items[#items + 1] = { value = name, name = name }
		end
	end
	return items
end

local function DataBarRows(p, key)
	local function S() return SB(key) end
	local function G(k, d) return function() local v = S()[k] if v == nil then return d end return v end end
	local function W(k) return function(v) S()[k] = v end end
	p:Slider("Width", "Width of the bar.", 50, 1200, 1, G("width", 400), W("width"))
	p:Slider("Height", "Height of the bar.", 4, 60, 1, G("height", 18), W("height"))
	p:Dropdown("Bar Texture", "Fill texture of the bar (LibSharedMedia textures are listed too).", TextureItems,
		G("barTexture", "none"),
		function() return S().barTexture or "None" end, W("barTexture"))
	p:Toggle("Click Through", "The bar does not take the mouse (no tooltip).", G("clickThrough", true), W("clickThrough"))
	p:Slider("Text Size", "Size of the bar text.", 6, 24, 1, G("textSize", 9), W("textSize"))
	p:Cog("Bar Text Offsets", {
		{ type = "dropdown", label = "Anchor", items = function() return Items(DATA_TEXT_POS) end,
		  get = function() return S().textAnchor or "center" end, set = W("textAnchor") },
		{ type = "slider", label = "X Offset", min = -150, max = 150, step = 1, get = G("textOffsetX", 0), set = W("textOffsetX") },
		{ type = "slider", label = "Y Offset", min = -150, max = 150, step = 1, get = G("textOffsetY", 0), set = W("textOffsetY") },
	}, { icon = "directions" })
	p:Toggle("Custom Border", "Use your own border size and color instead of the 1 px black line.", G("customBorder", false), W("customBorder"))
	p:Swatch("Border Color", ColorGet("borderColor", 0, 0, 0, 1, key), ColorSet("borderColor", true, key),
		{ alpha = true, disabled = function() return not S().customBorder end })
	p:Cog("Custom Border", {
		{ type = "slider", label = "Border Size", min = 0, max = 4, step = 1,
		  get = function()
			local e = EAB.BORDER_THICKNESS[S().borderThickness or "thin"]
			return e and e.regular or 1
		  end,
		  set = function(v) S().borderThickness = EAB.BORDER_LABEL_OF_STEP[v] or "thin" end },
	}, { icon = "resize", disabled = function() return not S().customBorder end, disabledTip = "Custom Border" })
	p:Dropdown("Bar Color", "By State uses the EllesmereUI colors (XP: purple / rested blue, reputation: by standing).",
		function() return Items({ { "state", "By State" }, { "accent", "Accent Color" }, { "custom", "Custom Color" } }) end,
		function() return S().colorMode or "state" end,
		function() return LabelOf({ { "state", "By State" }, { "accent", "Accent Color" }, { "custom", "Custom Color" } }, S().colorMode or "state") end,
		function(v) S().colorMode = v ~= "state" and v or nil end)
	p:Swatch("Custom Color", ColorGet("customColor", 1, 1, 1, 1, key), ColorSet("customColor", false, key),
		{ disabled = function() return S().colorMode ~= "custom" end })
end

---------------------------------------------------------------------------
-- XP Bar page
---------------------------------------------------------------------------
local function BuildXPBar(p)
	if NotRunning(p) then
		return
	end
	local function S() return SB("XPBar") end
	local function G(k, d) return function() local v = S()[k] if v == nil then return d end return v end end
	local function W(k) return function(v) S()[k] = v end end
	p:Paragraph("The XP bar hides at the level cap (90). Move it in Unlock Mode.")
	p:Section("Core")
	VisibilityRow(p, "XPBar", "XP Bar Visibility")
	p:Blank()
	DataBarRows(p, "XPBar")

	p:Section("Core Text Positions")
	p:Toggle("Show Level", "Starts the text with your level.", G("showLevel", false), W("showLevel"))
	p:Toggle("Show Raw Values", "XP as current / needed instead of a percentage.", G("showRawValues", false), W("showRawValues"))
	p:Toggle("Show %", "Adds the percentage after the raw values.", G("showPercent", false), W("showPercent"),
		function() return not S().showRawValues end)
	p:Toggle("Hide Text", "No text on the bar.", G("hideText", false), W("hideText"))

	p:Section("Display")
	p:Toggle("Show Rested", "Shows the rested XP: in the text and as the darker overlay ahead of the fill.", G("showRested", true), W("showRested"))
	p:ColorRow("Rested Color", "Color of the rested XP overlay.",
		function()
			local c = S().restedColor or EAB.XP_BAR_COLORS.xpRestedBG
			return c.r, c.g, c.b, c.a or 1
		end,
		function(r, g, b, a) S().restedColor = { r = r, g = g, b = b, a = a or 1 } end, { alpha = true },
		function() return S().showRested == false end)

	-- Retail XP bar extras (EUI_ActionBars_XPBar.lua).
	local XP = ns.EAB_XP
	if not XP then return end
	local function Col(key, r, g, b, a)
		return function()
			local c = S()[key]
			if c then return c.r, c.g, c.b, c.a or a or 1 end
			return r, g, b, a or 1
		end, function(nr, ng, nb, na) S()[key] = { r = nr, g = ng, b = nb, a = na or 1 } end
	end
	p:Section("Dividers")
	local DIVS = { { "", "None" }, { "4", "Quarters" }, { "5", "Fifths" }, { "10", "Tenths" }, { "20", "5% Lines" } }
	p:Dropdown("Dividers", "Lines that split the bar into equal parts.",
		function()
			local items = {}
			for _, d in ipairs(DIVS) do items[#items + 1] = { value = d[1], name = d[2] } end
			return items
		end,
		function() return S().divider or "" end,
		function()
			for _, d in ipairs(DIVS) do if d[1] == (S().divider or "") then return d[2] end end
			return "None"
		end,
		function(v) S().divider = (v ~= "") and v or nil end)
	local function DivOff() return not S().divider end
	local dg, ds = Col("dividerColor", 0, 0, 0, 0.8)
	p:Swatch("Divider Color", dg, ds, { alpha = true, disabled = DivOff })
	p:Toggle("Divider Text", "Labels each divider with its percent.", G("dividerText", false), W("dividerText"), DivOff)
	p:Cog("Divider Text Settings", {
		{ type = "slider", label = "Text Size", min = 6, max = 16, step = 1, get = G("dividerTextSize", 8), set = W("dividerTextSize") },
		{ type = "slider", label = "X Offset", min = -30, max = 30, step = 1, get = G("dividerTextOffX", 0), set = W("dividerTextOffX") },
		{ type = "slider", label = "Y Offset", min = -30, max = 30, step = 1, get = G("dividerTextOffY", 0), set = W("dividerTextOffY") },
		{ type = "color", label = "Text Color",
		  get = function() local c = S().dividerTextColor or { r = 1, g = 1, b = 1 }; return c.r, c.g, c.b end,
		  set = function(r, g, b) S().dividerTextColor = { r = r, g = g, b = b } end },
	}, { disabled = function() return DivOff() or not S().dividerText end })

	p:Section("Text Slots")
	local function SlotItems()
		local items = { { value = "none", name = "None" } }
		for _, it in ipairs(XP.ITEMS_TOP) do items[#items + 1] = { value = it[1], name = it[2] } end
		for _, it in ipairs(XP.ITEMS_SOLO) do items[#items + 1] = { value = it[1], name = it[2] .. " (alone)" } end
		return items
	end
	local SOLO = {}
	for _, it in ipairs(XP.ITEMS_SOLO) do SOLO[it[1]] = true end
	local function SlotRow(stem, label, tip)
		local key = "textSlot" .. stem
		local function Has(id)
			local v = S()[key]
			if id == "none" then return v == "none" or (stem ~= "Center" and (v == nil or v == "")) end
			if type(v) ~= "string" then return false end
			for x in v:gmatch("[^,]+") do if x == id then return true end end
			return false
		end
		p:MultiSelect(label, tip, SlotItems, Has,
			function(id)
				local v = S()[key]
				if id == "none" or SOLO[id] then
					S()[key] = (Has(id) and stem == "Center") and nil or id
					return
				end
				local list = {}
				if type(v) == "string" and v ~= "none" and not SOLO[v] then
					for x in v:gmatch("[^,]+") do if x ~= id then list[#list + 1] = x end end
				end
				if not Has(id) then list[#list + 1] = id end
				S()[key] = #list > 0 and table.concat(list, ",") or nil
			end,
			function()
				local v = S()[key]
				if v == nil or v == "" then return stem == "Center" and "Classic Text" or "None" end
				if v == "none" then return "None" end
				local names = {}
				for x in v:gmatch("[^,]+") do
					for _, it in ipairs(SlotItems()) do if it.value == x then names[#names + 1] = it.name end end
				end
				return table.concat(names, " - ")
			end)
		p:Slider(label .. " Size", nil, 6, 24, 1, G(key .. "Size", S().textSize or 9), W(key .. "Size"),
			function() return S()[key] == nil or S()[key] == "none" end)
	end
	SlotRow("Center", "Center Text", "Replaces the classic text with the picked items (none picked = the classic text).")
	SlotRow("Left", "Left Text", "Items shown at the bar's left end. One item marked alone is shown by itself.")
	SlotRow("Right", "Right Text", "Items shown at the bar's right end.")
	p:Toggle("Text Background", "A dark band behind the bar texts.", G("showTextBg", false), W("showTextBg"))
	local tg, ts = Col("textBgColor", 0, 0, 0, 0.5)
	p:Swatch("Text Background Color", tg, ts, { alpha = true, disabled = function() return not S().showTextBg end })

	p:Section("Fill")
	local GRADS = { { "", "Flat Color" }, { "HORIZONTAL", "Gradient (Horizontal)" }, { "VERTICAL", "Gradient (Vertical)" } }
	p:Dropdown("Fill Style", nil,
		function()
			local items = {}
			for _, d in ipairs(GRADS) do items[#items + 1] = { value = d[1], name = d[2] } end
			return items
		end,
		function() return S().fillGradient or "" end,
		function()
			for _, d in ipairs(GRADS) do if d[1] == (S().fillGradient or "") then return d[2] end end
			return "Flat Color"
		end,
		function(v) S().fillGradient = (v ~= "") and v or nil end)
	local function GradOff() return not S().fillGradient end
	local g1, s1 = Col("fillGradStart", 0.60, 0.40, 0.85, 1)
	local g2, s2 = Col("fillGradEnd", 0.00, 0.44, 0.87, 1)
	p:Swatch("Gradient Start", g1, s1, { alpha = true, disabled = GradOff })
	p:Swatch("Gradient End", g2, s2, { alpha = true, disabled = GradOff })

	p:Section("Quest XP Overlay")
	local function QOff() return not S().questOverlay end
	p:Toggle("Quest XP Overlay", "Shows the XP of the quests in your log ahead of the fill.", G("questOverlay", false), W("questOverlay"))
	p:Toggle("Completed Quests Only", nil, G("questOverlayCompleted", false), W("questOverlayCompleted"), QOff)
	p:Toggle("Current Zone Only", "Only the quests listed under the zone you are in.", G("questOverlayZone", false), W("questOverlayZone"), QOff)
	local qg, qs = Col("questOverlayColor", 1, 0.82, 0, 0.45)
	p:Swatch("Overlay Color", qg, qs, { alpha = true, disabled = QOff })
	local dg2, ds2 = Col("questOverlayDoneColor", 1, 0.82, 0, 0.6)
	p:Swatch("Completed Overlay Color", dg2, ds2, { alpha = true, disabled = function() return QOff() or not S().questOverlayCompleted end })
end

---------------------------------------------------------------------------
-- Menu, Bags & Rep Bars page
---------------------------------------------------------------------------
local function OpacityRow(p, key)
	p:Slider("Bar Opacity", "Opacity of the bar (while shown; Mouseover fades to this).", 0, 100, 5,
		function()
			local s = SB(key)
			if s.mouseoverEnabled then
				return floor((s._savedBarAlpha or 1) * 100 + 0.5)
			end
			return floor((s.mouseoverAlpha or 1) * 100 + 0.5)
		end,
		function(v)
			local s = SB(key)
			if s.mouseoverEnabled then
				s._savedBarAlpha = v / 100
			else
				s.mouseoverAlpha = v / 100
			end
		end)
end

local function BuildMenuBagsRep(p)
	if NotRunning(p) then
		return
	end
	p:Section("Micro Menu & Bags")
	VisibilityRow(p, "MicroBar", "Micro Menu Visibility")
	OpacityRow(p, "MicroBar")
	VisibilityRow(p, "BagBar", "Bag Bar Visibility")
	OpacityRow(p, "BagBar")
	VisibilityRow(p, "ExtraActionButton", "Extra Action Button Visibility")
	OpacityRow(p, "ExtraActionButton")

	p:Section("Reputation Bar")
	VisibilityRow(p, "RepBar", "Reputation Bar Visibility")
	p:Toggle("Use Blizzard's Rep Bars", "Keep Blizzard's own experience and reputation bars instead of these. Requires a UI reload.",
		function() return DB().useBlizzardDataBars or false end,
		function(v)
			DB().useBlizzardDataBars = v and true or false
			ReloadPopup("Blizzard data bars changed. A UI reload is needed to apply.")
		end)
	DataBarRows(p, "RepBar")

	p:Section("Vehicle Bar")
	p:Toggle("Hide Blizzard's Vehicle Bar", "Hide Blizzard's vehicle and override bar; Action Bar 1 shows the vehicle abilities either way. Requires a UI reload.",
		function() return DB().hideBlizzardVehicleBar or false end,
		function(v)
			DB().hideBlizzardVehicleBar = v and true or false
			ReloadPopup("Vehicle bar changed. A UI reload is needed to apply.")
		end)
	p:Blank()
end

---------------------------------------------------------------------------
-- Bar Animations page
---------------------------------------------------------------------------
local INTERACTIONS_TIP = "Bar Interactions are the light effects that happen when you hover/press a spell, your cooldown swipe line, aura active border glow, etc"

local function BuildAnimations(p)
	if NotRunning(p) then
		return
	end
	p:Section("Bar Interactions")
	p:ColorRow("Bar Interactions Color", INTERACTIONS_TIP,
		function()
			local c = DB().pushedCustomColor
			if not c then return 0.973, 0.839, 0.604, 1 end
			return c.r, c.g, c.b, c.a or 1
		end,
		function(r, g, b, a)
			local d = DB()
			d.pushedCustomColor = { r = r, g = g, b = b, a = a }
			d.highlightCustomColor = { r = r, g = g, b = b, a = a }
			d.cooldownEdgeColor = { r = r, g = g, b = b, a = a }
			d.procGlowColor = { r = r, g = g, b = b }
			if d.procGlowColorMode == "default" then d.procGlowColorMode = "custom" end
		end, { alpha = true },
		function() return DB().pushedUseClassColor end)
	p:Toggle("Class Colored Bar Interactions", INTERACTIONS_TIP,
		function() return DB().pushedUseClassColor end,
		function(v)
			local d = DB()
			d.pushedUseClassColor = v
			d.highlightUseClassColor = v
			d.cooldownEdgeUseClassColor = v
			d.procGlowUseClassColor = v
			if d.procGlowColorMode == "class" or (v and d.procGlowColorMode) then
				d.procGlowColorMode = v and "class" or "custom"
			end
		end)

	p:Dropdown("Pushed Type", "The overlay that appears on the icon when you press and hold a spell button",
		function() return Items(INTERACTION_TYPES) end,
		function() return DB().pushedTextureType or 2 end,
		function() return LabelOf(INTERACTION_TYPES, DB().pushedTextureType or 2) end,
		function(v) DB().pushedTextureType = v end)
	p:Cog("Pushed Border Settings", {
		{ type = "slider", label = "Border Size", min = 1, max = 10, step = 1,
		  get = function() return DB().pushedBorderSize or 4 end, set = function(v) DB().pushedBorderSize = v end },
	}, { disabled = function() return (DB().pushedTextureType or 2) ~= 5 end, disabledTip = "Border Pushed Type" })
	p:Dropdown("Highlight Type", "The overlay that appears on the icon when you hover your mouse over a spell button",
		function() return Items(INTERACTION_TYPES) end,
		function() return DB().highlightTextureType or 2 end,
		function() return LabelOf(INTERACTION_TYPES, DB().highlightTextureType or 2) end,
		function(v) DB().highlightTextureType = v end)
	p:Cog("Highlight Border Settings", {
		{ type = "slider", label = "Border Size", min = 1, max = 10, step = 1,
		  get = function() return DB().highlightBorderSize or 4 end, set = function(v) DB().highlightBorderSize = v end },
	}, { disabled = function() return (DB().highlightTextureType or 2) ~= 5 end, disabledTip = "Border Highlight Type" })

	p:Toggle("Show Highlight on Spell Cast", "The highlight overlay that appears on a spell button while it is the active/current action. Disable to hide it.",
		function() return DB().showCastHighlight ~= false end,
		function(v) DB().showCastHighlight = v end)
	p:Blank()

	p:Section("Custom Proc Glow")
	p:Dropdown("Custom Proc Glow", "Replaces Blizzard's proc glow (the spell activation overlay) on the action buttons. None keeps Blizzard's glow.",
		function() return Items(PROC_GLOWS) end,
		function()
			local d = DB()
			if not d.procGlowEnabled or (d.procGlowType or 1) == 0 then return 0 end
			return d.procGlowType or 1
		end,
		function()
			local d = DB()
			local v = (not d.procGlowEnabled or (d.procGlowType or 1) == 0) and 0 or (d.procGlowType or 1)
			return LabelOf(PROC_GLOWS, v)
		end,
		function(v)
			local d = DB()
			if v == 0 then
				d.procGlowEnabled = false
			else
				d.procGlowEnabled = true
				d.procGlowType = v
			end
		end)
	p:Swatch("Class Colored", ClassColor, function() end, {
		readonly = true,
		active = function() return DB().procGlowUseClassColor and true or false end,
		onClick = function()
			DB().procGlowUseClassColor = true
			DB().procGlowColorMode = "class"
			return true
		end,
		disabled = function() return not DB().procGlowEnabled end,
	})
	p:Swatch("Glow Color", ProfileColorGet("procGlowColor", 1, 0.776, 0.376), ProfileColorSet("procGlowColor"), {
		active = function() return not DB().procGlowUseClassColor end,
		onClick = function()
			if DB().procGlowUseClassColor then
				DB().procGlowUseClassColor = false
				DB().procGlowColorMode = "custom"
				return true
			end
		end,
		disabled = function() return not DB().procGlowEnabled end,
	})
	p:Blank()
end

ns.RegisterSettingsModule({
	key = "actionBars",
	name = "Action Bars",
	group = "Core Addons",
	tabs = {
		{ key = "display", name = "Bar Display", description = "Configure visuals and behavior for your action bars.",
		  build = BuildBarDisplay,
		  header = BuildBarHeader,
		  -- The page is built per bar (and per Bar Background / paging state).
		  pageKey = function()
			local s = SB()
			return sel.bar .. (s.bgEnabled and ":bg" or "") .. (s.modTargetPaging and ":mt" or "")
		  end },
		{ key = "xp", name = "XP Bar", description = "Configure visuals and behavior for your action bars.", build = BuildXPBar },
		{ key = "menubags", name = "Menu, Bags & Rep Bars", description = "Configure visuals and behavior for your action bars.", build = BuildMenuBagsRep },
		{ key = "animations", name = "Bar Animations", description = "Configure visuals and behavior for your action bars.", build = BuildAnimations },
	},
	reset = function()
		EAB:ResetProfile()
		EAB:ApplyAll()
	end,
	resetTip = "Set all Action Bars settings back to the EllesmereUI defaults (positions too).",
})
