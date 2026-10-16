-- Settings page of QoL Addons > DataBars (EllesmereUI EllesmereUIDataBars_Options.lua:
-- the same layout, labels, tooltips and keys, built with this window's Page API).
--
-- Content header: the bar picker with rename / delete, "+ New Bar" and its
-- template cards, and the preview strip of the selected bar (click a block to
-- scroll to its section, drag it to reorder, right click to remove it), plus
-- "Add Block". Body: Bar Settings, then one section per block in bar order.
--
-- 5.4.8 differences: the preview strip is always drawn left to right (retail
-- shows a vertical bar in a side popout); blocks are added from the "Add Block"
-- dropdown instead of a "+" tile; Menu Elements is a plain checklist (no drag
-- reordering); rows for retail-only data (Reagent Bag, WoW Token, Loadout
-- name, Dialog channel, Crests, Great Vault) are left out.
-- Part of EllesmereUIOptions (load on demand); skipped when EllesmereUIDataBars
-- is not loaded. The runtime API is EllesmereUI.EDB (the DataBars ns).

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUIDataBars") then
	return
end
local EDB = ns.EDB
if not EDB then
	return
end

local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local format = string.format

local FONT = ns.FONT
local FONT_FALLBACK = "Fonts\\ARIALN.TTF"
local CONTENT_PAD = 45

---------------------------------------------------------------------------
-- Selection, rebuilds
---------------------------------------------------------------------------
local rev = 0
local cardsOpen = false

local function Profile()
	return EDB.GetProfile()
end

local function SelectedBar()
	local p = Profile()
	if not p then
		return nil
	end
	local cfg = p.selectedBarId and EDB.GetBar(p.selectedBarId)
	if not cfg then
		cfg = p.bars[1]
		p.selectedBarId = cfg and cfg.id or nil
	end
	return cfg
end

local function PageKey()
	local cfg = SelectedBar()
	return (cfg and cfg.id or 0) .. ":" .. rev
end

-- Structural change (blocks added / moved / removed, sizing mode, ...): the
-- page is rebuilt for a new key.
local function Rebuild()
	rev = rev + 1
	if ns.RebuildSettingsPage then
		ns.RebuildSettingsPage()
	end
end

-- Section name of every block of the last page build, per page key.
local sectionNames = {}

local TYPE_LABEL = {}
for _, t in ipairs(EDB.BLOCK_TYPES) do
	TYPE_LABEL[t.key] = t.label
end

local function BlockLabel(b)
	return TYPE_LABEL[b.type] or b.type
end

local function ClassRGB()
	local _, class = UnitClass("player")
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then
		return c.r, c.g, c.b
	end
	return 1, 1, 1
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

---------------------------------------------------------------------------
-- Small widgets for the header (EllesmereUI look)
---------------------------------------------------------------------------
local function SetFont(fs, size)
	fs:SetFont(FONT, size, "")
	if not fs:GetFont() then
		fs:SetFont(FONT_FALLBACK, size, "")
	end
end

local function Text(parent, size, alpha)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	SetFont(fs, size)
	fs:SetTextColor(1, 1, 1, alpha or 1)
	return fs
end

local function Solid(parent, layer, r, g, b, a)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND")
	t:SetTexture(r, g, b, a or 1)
	return t
end

-- 1 px border (4 textures inside the frame).
local function Border(frame, r, g, b, a)
	local e = {}
	for i = 1, 4 do
		e[i] = frame:CreateTexture(nil, "BORDER")
		e[i]:SetTexture(1, 1, 1, 1)
	end
	e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT"); e[1]:SetHeight(1)
	e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(1)
	e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT"); e[3]:SetWidth(1)
	e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(1)
	local obj = {}
	function obj:SetColor(cr, cg, cb, ca)
		for i = 1, 4 do e[i]:SetVertexColor(cr, cg, cb, ca or 1) end
	end
	obj:SetColor(r, g, b, a)
	return obj
end

local function Accent()
	if ns.ResolveAccent then
		local r, g, b = ns.ResolveAccent()
		if r then
			return r, g, b
		end
	end
	return 12 / 255, 210 / 255, 157 / 255
end

-- Flat text button (EllesmereUI MakeStyledButton).
local function FlatButton(parent, w, h, label, onClick, tip)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, h)
	b.bg = Solid(b, "BACKGROUND", 0.061, 0.095, 0.112, 0.9)
	b.bg:SetAllPoints()
	b.border = Border(b, 1, 1, 1, 0.2)
	b.text = Text(b, 12, 0.75)
	b.text:SetPoint("CENTER")
	b.text:SetText(label)
	b:SetScript("OnEnter", function(self)
		local r, g, bl = Accent()
		self.border:SetColor(r, g, bl, 0.6)
		self.text:SetTextColor(1, 1, 1, 1)
		if tip then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(tip, 1, 1, 1, 1, true)
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function(self)
		self.border:SetColor(1, 1, 1, 0.2)
		self.text:SetTextColor(1, 1, 1, 0.75)
		GameTooltip:Hide()
	end)
	b:SetScript("OnClick", onClick)
	return b
end

---------------------------------------------------------------------------
-- Bar actions (popups)
---------------------------------------------------------------------------
local function PromptRenameBar(cfg)
	if not ns.ShowInputPopup then
		return
	end
	local old = cfg.name or ""
	ns.ShowInputPopup({
		title = "Rename DataBar",
		message = format("Enter a new name for \"%s\":", old),
		text = old,
		confirmText = "Rename",
		cancelText = "Cancel",
		onConfirm = function(newName)
			newName = newName and strtrim(newName) or ""
			if newName == "" or newName == old then
				return
			end
			EDB.RenameBar(cfg.id, newName)
			Rebuild()
		end,
	})
end

local function PromptDeleteBar(cfg)
	ns.ShowConfirmPopup({
		title = "Delete DataBar",
		message = format("Are you sure you want to delete \"%s\"?", cfg.name or ""),
		confirmText = "Delete",
		cancelText = "Cancel",
		onConfirm = function()
			EDB.DeleteBar(cfg.id)
			local p = Profile()
			local bars = EDB.BarsInOrder()
			if p then
				p.selectedBarId = bars[1] and bars[1].id or nil
			end
			Rebuild()
		end,
	})
end

local function PromptRemoveBlock(cfg, b)
	ns.ShowConfirmPopup({
		title = "Remove Block",
		message = format("Remove the %s block from \"%s\"?", BlockLabel(b), cfg.name or ""),
		confirmText = "Remove",
		cancelText = "Cancel",
		onConfirm = function()
			EDB.RemoveBlock(cfg.id, b.id)
			Rebuild()
		end,
	})
end

---------------------------------------------------------------------------
-- Template cards
---------------------------------------------------------------------------
local TEMPLATE_CARDS = {
	{ key = "empty", icon = ns.MEDIA .. "ui\\eui-directions", crop = 30 / 32, title = "Start Empty",
	  desc = "A blank bar to build from scratch." },
	{ key = "bottom", icon = ns.MEDIA .. "ui\\eui-resize-5", crop = 30 / 32, title = "Top/Bottom Info Bar",
	  desc = "Full-width bar with the classic info blocks." },
	{ key = "minimapc", icon = EDB.MEDIA .. "coordinates", crop = 1, title = "Minimap Companion",
	  desc = "Compact clock and FPS readout." },
	{ key = "microstrip", icon = ns.MEDIA .. "ui\\cogs", crop = 30 / 32, title = "Micro Menu Strip",
	  desc = "Just the micro menu buttons." },
}

local function CreateBarFromTemplate(key)
	EDB.CreateBar(key)
	cardsOpen = false
	Rebuild()
end

local function MakeTemplateCard(host, x, y, w, h, def)
	local card = CreateFrame("Button", nil, host)
	card:SetSize(w, h)
	card:SetPoint("TOPLEFT", host, "TOPLEFT", x, y)
	local bg = Solid(card, "BACKGROUND", 0.077, 0.068, 0.058, 0.5)
	bg:SetAllPoints()
	local border = Border(card, 1, 1, 1, 0.12)
	local r, g, b = Accent()
	local line = Solid(card, "ARTWORK", r, g, b, 0.6)
	line:SetPoint("TOPLEFT", 1, -1)
	line:SetPoint("TOPRIGHT", -1, -1)
	line:SetHeight(2)
	local icon = card:CreateTexture(nil, "ARTWORK")
	icon:SetSize(24, 24)
	icon:SetPoint("LEFT", 14, 0)
	icon:SetTexture(def.icon)
	icon:SetTexCoord(0, def.crop, 0, def.crop)
	icon:SetVertexColor(r, g, b)
	icon:SetAlpha(0.6)
	local title = Text(card, 12, 0.9)
	title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, 1)
	title:SetPoint("RIGHT", card, "RIGHT", -8, 0)
	title:SetJustifyH("LEFT")
	title:SetWordWrap(false)
	title:SetText(def.title)
	local desc = Text(card, 10, 0.35)
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	desc:SetPoint("RIGHT", card, "RIGHT", -8, 0)
	desc:SetJustifyH("LEFT")
	desc:SetWordWrap(false)
	desc:SetText(def.desc)
	card:SetScript("OnEnter", function()
		bg:SetTexture(0.119, 0.111, 0.104, 0.5)
		border:SetColor(1, 1, 1, 0.22)
		title:SetAlpha(1)
		icon:SetAlpha(0.85)
	end)
	card:SetScript("OnLeave", function()
		bg:SetTexture(0.077, 0.068, 0.058, 0.5)
		border:SetColor(1, 1, 1, 0.12)
		title:SetAlpha(0.9)
		icon:SetAlpha(0.6)
	end)
	card:SetScript("OnClick", function() CreateBarFromTemplate(def.key) end)
	return card
end

local function TemplateCardRow(host, top, width)
	local gap = 10
	local cw = floor((width - 2 * CONTENT_PAD - gap * (#TEMPLATE_CARDS - 1)) / #TEMPLATE_CARDS)
	for i, def in ipairs(TEMPLATE_CARDS) do
		MakeTemplateCard(host, CONTENT_PAD + (i - 1) * (cw + gap), -top, cw, 54, def)
	end
	return 54
end

---------------------------------------------------------------------------
-- Preview strip: the selected bar's blocks, sized by the bar's own layout
-- solver (live content widths, scaled to the strip).
---------------------------------------------------------------------------
local STRIP_H = 40

local function LiveBarLength(cfg)
	local rec = EDB._live and EDB._live[cfg.id]
	if rec and rec.bar then
		local l = (cfg.orientation == "V") and rec.bar:GetHeight() or rec.bar:GetWidth()
		if l and l > 1 then
			return l
		end
	end
	if cfg.lengthMode == "full" then
		return (cfg.orientation == "V") and UIParent:GetHeight() or UIParent:GetWidth()
	end
	return cfg.length or 400
end

local function CreatePreviewStrip(page, host, width, cfg)
	local strip = CreateFrame("Frame", nil, host)
	strip:SetSize(width, STRIP_H)
	EDB.MakePreviewBackdrop(strip, cfg.theme, not cfg.hideBorder)
	local edge = Border(strip, 0, 0, 0, cfg.hideBorder and 0 or 0.8)
	strip.segs = {}
	local marker = Solid(strip, "OVERLAY", 1, 1, 1, 0.9)
	marker:SetWidth(2)
	marker:SetPoint("TOP")
	marker:SetPoint("BOTTOM")
	marker:Hide()

	local drag
	local function BoundaryIndex(x)
		-- Nearest block boundary to x (1 = before the first, n + 1 = after the last).
		local best, bestD = 1, math.huge
		for i, s in ipairs(strip.segs) do
			local d = abs(x - s.x)
			if d < bestD then best, bestD = i, d end
		end
		local d = abs(x - width)
		if d < bestD then best = #strip.segs + 1 end
		return best
	end
	local function CursorX()
		local cx = GetCursorPosition() / strip:GetEffectiveScale()
		return cx - (strip:GetLeft() or 0)
	end

	local function MakeSeg(b)
		local seg = CreateFrame("Button", nil, strip)
		seg:RegisterForClicks("AnyUp")
		seg.hl = Solid(seg, "OVERLAY", 1, 1, 1, 0.08)
		seg.hl:SetAllPoints()
		seg.hl:Hide()
		seg.div = Solid(seg, "ARTWORK", 1, 1, 1, 0.12)
		seg.div:SetWidth(1)
		seg.div:SetPoint("TOPRIGHT")
		seg.div:SetPoint("BOTTOMRIGHT")
		seg.label = Text(seg, 11, 0.85)
		seg.label:SetPoint("LEFT", 3, 0)
		seg.label:SetPoint("RIGHT", -3, 0)
		seg.label:SetWordWrap(false)
		seg.label:SetText(BlockLabel(b))
		seg.block = b
		seg:SetScript("OnEnter", function(self)
			self.hl:Show()
			if EDB.SetBlockEditHighlight then EDB.SetBlockEditHighlight(cfg.id, b.id) end
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(BlockLabel(b), 1, 1, 1)
			GameTooltip:AddLine("Click: scroll to its settings", 0.8, 0.8, 0.8)
			GameTooltip:AddLine("Drag: reorder", 0.8, 0.8, 0.8)
			GameTooltip:AddLine("Right Click: remove", 0.8, 0.8, 0.8)
			GameTooltip:Show()
		end)
		seg:SetScript("OnLeave", function(self)
			self.hl:Hide()
			if EDB.SetBlockEditHighlight then EDB.SetBlockEditHighlight(nil, nil) end
			GameTooltip:Hide()
		end)
		seg:SetScript("OnMouseDown", function(self, button)
			if button == "LeftButton" then
				drag = { seg = self, x0 = CursorX(), moving = false }
			end
		end)
		seg:SetScript("OnMouseUp", function(self, button)
			if button == "RightButton" then
				PromptRemoveBlock(cfg, b)
				return
			end
			if button ~= "LeftButton" or not drag then
				return
			end
			local d = drag
			drag = nil
			marker:Hide()
			if d.moving then
				local from
				for i, s in ipairs(strip.segs) do
					if s == self then from = i end
				end
				local to = BoundaryIndex(CursorX())
				if from and to ~= from and to ~= from + 1 then
					EDB.MoveBlockTo(cfg.id, b.id, to)
					Rebuild()
				end
				return
			end
			local names = sectionNames[PageKey()]
			if names and names[b.id] then
				page:Reveal("\2" .. names[b.id])
			end
		end)
		return seg
	end

	for i, b in ipairs(cfg.blocks) do
		strip.segs[i] = MakeSeg(b)
	end

	strip:SetScript("OnUpdate", function()
		if drag then
			if not IsMouseButtonDown("LeftButton") then
				drag = nil
				marker:Hide()
			elseif drag.moving or abs(CursorX() - drag.x0) > 5 then
				drag.moving = true
				local idx = BoundaryIndex(CursorX())
				local x = (idx > #strip.segs) and width or strip.segs[idx].x
				marker:ClearAllPoints()
				marker:SetPoint("TOP", strip, "TOPLEFT", min(width - 1, max(1, x)), 0)
				marker:SetPoint("BOTTOM", strip, "BOTTOMLEFT", min(width - 1, max(1, x)), 0)
				marker:Show()
			end
		end
		if strip.relayout then
			strip.relayout = strip.relayout - 1
			if strip.relayout <= 0 then
				strip.relayout = nil
				strip:Layout()
			end
		end
	end)

	function strip:Layout()
		local c = EDB.GetBar(cfg.id)
		if not c then
			return
		end
		EDB.MakePreviewBackdrop(self, c.theme, not c.hideBorder)
		edge:SetColor(0, 0, 0, c.hideBorder and 0 or 0.8)
		local realL = LiveBarLength(c)
		local scale = width / max(1, realL)
		local segs = EDB.SolveLayout(c, width, function(b)
			local w = EDB.GetLiveAutoLength(c.id, b.id)
			return (w or 0) * scale
		end)
		for i, s in ipairs(segs) do
			local f = self.segs[i]
			if f then
				f.x = s.at or 0
				f:ClearAllPoints()
				f:SetPoint("TOPLEFT", self, "TOPLEFT", f.x, 0)
				f:SetSize(max(2, s.px or 0), STRIP_H)
				f.label:SetShown((s.px or 0) >= 24)
				f.div:SetShown(i < #segs)
			end
		end
	end
	strip:Layout()
	-- Settings changes re-apply the bars on the next frame; lay out after that.
	page:OnRefresh(function()
		if strip:IsVisible() then
			strip.relayout = 3
		end
	end)
	return strip
end

---------------------------------------------------------------------------
-- Content header
---------------------------------------------------------------------------
local function BuildHeader(page, host, width)
	local cfg = SelectedBar()
	local y = 16

	if not cfg then
		local title = Text(host, 14, 0.85)
		title:SetPoint("TOP", host, "TOP", 0, -y)
		title:SetText("Create your first DataBar")
		y = y + 26
		y = y + TemplateCardRow(host, y, width) + 16
		return y
	end

	-- Row 1: bar picker | rename | delete | + New Bar (centered as a group)
	local DD_W, DD_H, ICON, NEW_W, GAP = 280, 30, 30, 110, 6
	local total = DD_W + GAP + ICON + GAP + ICON + 10 + NEW_W
	local x0 = floor((width - total) / 2)
	local dd = page:HeaderDropdown(host, DD_W, DD_H,
		function()
			local items = {}
			for _, b in ipairs(EDB.BarsInOrder()) do
				items[#items + 1] = { value = b.id, name = b.name or ("DataBar " .. b.id) }
			end
			return items
		end,
		function() local c = SelectedBar(); return c and c.id end,
		function() local c = SelectedBar(); return c and c.name or "" end,
		function(v)
			Profile().selectedBarId = v
			Rebuild()
		end)
	dd:SetPoint("TOPLEFT", host, "TOPLEFT", x0, -y)
	local rename = page:HeaderIconButton(host, ICON, "Interface\\Buttons\\UI-GuildButton-PublicNote-Up", 16, "Rename", function()
		local c = SelectedBar()
		if c then PromptRenameBar(c) end
	end)
	rename:SetPoint("LEFT", dd, "RIGHT", GAP, 0)
	local delete = page:HeaderIconButton(host, ICON, ns.MEDIA .. "ui\\eui-close", 16, "Delete", function()
		local c = SelectedBar()
		if c then PromptDeleteBar(c) end
	end)
	delete:SetPoint("LEFT", rename, "RIGHT", GAP, 0)
	local newBtn = FlatButton(host, NEW_W, DD_H, cardsOpen and "- New Bar" or "+ New Bar", function()
		cardsOpen = not cardsOpen
		Rebuild()
	end, "Create a new DataBar from a template.")
	newBtn:SetPoint("LEFT", delete, "RIGHT", 10, 0)
	y = y + DD_H + 12

	-- Row 2: template cards (while "+ New Bar" is open)
	if cardsOpen then
		y = y + TemplateCardRow(host, y, width) + 12
	end

	-- Row 3: preview strip
	local stripW = width - 2 * CONTENT_PAD
	local strip = CreatePreviewStrip(page, host, stripW, cfg)
	strip:SetPoint("TOPLEFT", host, "TOPLEFT", CONTENT_PAD, -y)
	y = y + STRIP_H + 8

	-- Row 4: hint | Add Block
	local hint = Text(host, 11, 0.4)
	hint:SetPoint("TOPLEFT", host, "TOPLEFT", CONTENT_PAD, -y - 7)
	hint:SetText("Drag to Reorder. Click to Scroll. Right Click to Remove.")
	local add = page:HeaderDropdown(host, 170, 26,
		function()
			local items = {}
			for _, t in ipairs(EDB.BLOCK_TYPES) do
				items[#items + 1] = { value = t.key, name = t.label }
			end
			return items
		end,
		function() return nil end,
		function() return "+ Add Block" end,
		function(v)
			local c = SelectedBar()
			if c then
				EDB.AddBlock(c.id, v)
				Rebuild()
			end
		end)
	add:SetPoint("TOPRIGHT", host, "TOPRIGHT", -CONTENT_PAD, -y)
	y = y + 26 + 12
	return y
end

---------------------------------------------------------------------------
-- Visibility checklist (retail BuildVisibilityRow, same lanes as the
-- Minimap page)
---------------------------------------------------------------------------
local function Axis(key)
	for _, axis in ipairs(EDB.VIS_AXES) do
		if axis.key == key then
			return axis
		end
	end
end

local function VisibilityRow(p, cfg)
	p:MultiSelect("Visibility", "When this bar is shown. Never / Always / Mouseover is the base state (Never turns the bar off completely); the Show conditions must match (all or any), a Hide condition always hides.",
		function()
			local items = {
				{ value = "state:never", name = "Never" },
				{ value = "state:always", name = "Always" },
				{ value = "state:mouseover", name = "Mouseover" },
				{ value = "match:all", name = "Match All Conditions" },
				{ value = "match:any", name = "Match Any Condition" },
			}
			for _, axis in ipairs(EDB.VIS_AXES) do
				items[#items + 1] = { value = "show:" .. axis.key, name = "Show: " .. axis.label }
				items[#items + 1] = { value = "hide:" .. axis.key, name = "Hide: " .. axis.label }
			end
			return items
		end,
		function(value)
			local kind, key = value:match("^(%a+):(.+)$")
			if kind == "state" then
				return EDB.VisBase(cfg) == key
			elseif kind == "match" then
				return (cfg.visibilityMatch or "all") == key
			end
			local axis = Axis(key)
			return EDB.VisFlag(cfg, kind == "show" and axis.show or axis.hide)
		end,
		function(value)
			local kind, key = value:match("^(%a+):(.+)$")
			if kind == "state" then
				EDB.SetVisBase(cfg, key)
				return
			elseif kind == "match" then
				cfg.visibilityMatch = key
				return
			end
			local axis = Axis(key)
			local laneKey = kind == "show" and axis.show or axis.hide
			local otherKey = kind == "show" and axis.hide or axis.show
			local on = not EDB.VisFlag(cfg, laneKey)
			EDB.SetVisFlag(cfg, laneKey, on)
			if on then
				EDB.SetVisFlag(cfg, otherKey, false)
			end
		end,
		function()
			local base = EDB.VisBase(cfg)
			local text = base == "never" and "Never" or (base == "mouseover" and "Mouseover" or "Always")
			local n = 0
			for _, axis in ipairs(EDB.VIS_AXES) do
				if EDB.VisFlag(cfg, axis.show) or EDB.VisFlag(cfg, axis.hide) then
					n = n + 1
				end
			end
			if n > 0 and base ~= "never" then
				text = text .. " + " .. n .. (n == 1 and " condition" or " conditions")
			end
			return text
		end)
end

---------------------------------------------------------------------------
-- Color swatch rows (retail multiSwatch: Custom / Class / Accent [/ 4th])
---------------------------------------------------------------------------
-- Swatches go right to left on the cell, so they are added last first.
local DYNAMIC_TEXT = { durability = "Dynamic", location = "Reactive", coords = "Reactive", ilvl = "Band" }

local function TextColorSwatches(p, b)
	local function AnyFlag()
		return b.useClassColor or b.useAccentColor or b.useCoinColor or b.useDynamicColor
	end
	local function Clear()
		b.useClassColor, b.useAccentColor, b.useCoinColor, b.useDynamicColor = nil, nil, nil, nil
	end
	if b.type == "gold" then
		p:Swatch("Coin Colored", function() return 0.886, 0.675, 0.478, 1 end, function() end,
			{ readonly = true, active = function() return b.useCoinColor and true or false end,
			  onClick = function() Clear(); b.useCoinColor = true; return true end })
	elseif DYNAMIC_TEXT[b.type] then
		p:Swatch(DYNAMIC_TEXT[b.type], function() local r, g, bl = EDB.BlockTextDynamic(b.type); return r, g, bl, 1 end, function() end,
			{ readonly = true, active = function() return b.useDynamicColor and true or false end,
			  onClick = function() Clear(); b.useDynamicColor = true; return true end })
	end
	p:Swatch("Accent Color", function() local r, g, bl = Accent(); return r, g, bl, 1 end, function() end,
		{ readonly = true, active = function() return b.useAccentColor and true or false end,
		  onClick = function() Clear(); b.useAccentColor = true; return true end })
	p:Swatch("Class Colored", function() local r, g, bl = ClassRGB(); return r, g, bl, 1 end, function() end,
		{ readonly = true, active = function() return b.useClassColor and true or false end,
		  onClick = function() Clear(); b.useClassColor = true; return true end })
	p:Swatch("Custom Color",
		function()
			local c = b.color
			if c then return c.r or 1, c.g or 1, c.b or 1, 1 end
			return 1, 1, 1, 1
		end,
		function(r, g, bl) b.color = { r = r, g = g, b = bl } end,
		{ active = function() return not AnyFlag() end,
		  onClick = function()
			if AnyFlag() then
				Clear()
				return true
			end
		  end })
end

local function IconColorSwatches(p, b, s)
	local function FlagsOff()
		return not b.useIconClassColor and not b.useIconAccentColor and not b.useIconDefaultColor
	end
	local function Clear()
		b.useIconClassColor, b.useIconAccentColor, b.useIconDefaultColor = nil, nil, nil
	end
	local custom = s.iconStyle ~= "wow"
	local noDefault = custom and (b.type == "spec" or b.type == "profession" or b.type == "profession2")
	if not noDefault then
		p:Swatch(b.type == "durability" and "Dynamic" or "Default",
			function() local r, g, bl = EDB.BlockIconDefault(b.type, s); return r, g, bl, 1 end, function() end,
			{ readonly = true,
			  active = function() return (b.useIconDefaultColor or (FlagsOff() and b.iconColor == nil)) and true or false end,
			  onClick = function() Clear(); b.useIconDefaultColor = true; return true end })
	end
	p:Swatch("Accent Color", function() local r, g, bl = Accent(); return r, g, bl, 1 end, function() end,
		{ readonly = true,
		  active = function()
			if b.useIconAccentColor then return true end
			-- Professions default to the accent (their skill bar color).
			return (custom and (b.type == "profession" or b.type == "profession2") and FlagsOff() and b.iconColor == nil) and true or false
		  end,
		  onClick = function() Clear(); b.useIconAccentColor = true; return true end })
	p:Swatch("Class Colored", function() local r, g, bl = ClassRGB(); return r, g, bl, 1 end, function() end,
		{ readonly = true,
		  active = function()
			if b.useIconClassColor then return true end
			-- The spec icon defaults to the class color.
			return (custom and b.type == "spec" and (b.useIconDefaultColor or (FlagsOff() and b.iconColor == nil))) and true or false
		  end,
		  onClick = function() Clear(); b.useIconClassColor = true; return true end })
	p:Swatch("Custom Color",
		function()
			local c = b.iconColor
			if c then return c.r or 1, c.g or 1, c.b or 1, 1 end
			local r, g, bl = EDB.BlockIconDefault(b.type, s)
			return r, g, bl, 1
		end,
		function(r, g, bl) b.iconColor = { r = r, g = g, b = bl } end,
		{ active = function() return (FlagsOff() and b.iconColor ~= nil) and true or false end,
		  onClick = function()
			-- First click selects Custom (seeded from the default), the next
			-- one opens the color picker.
			if not FlagsOff() or b.iconColor == nil then
				Clear()
				if b.iconColor == nil then
					local r, g, bl = EDB.BlockIconDefault(b.type, s)
					b.iconColor = { r = r, g = g, b = bl }
				end
				return true
			end
		  end })
end

---------------------------------------------------------------------------
-- Generic row specs -> Page controls
---------------------------------------------------------------------------
-- spec.type: toggle / slider / dropdown / multi / label / blank; spec.after(p)
-- adds inline items (swatches, cogs) to the cell just made.
local function Emit(p, spec)
	if not spec or spec.type == "blank" then
		p:Blank()
		return
	end
	if spec.type == "toggle" then
		p:Toggle(spec.label, spec.tip, spec.get, spec.set, spec.disabled)
	elseif spec.type == "slider" then
		p:Slider(spec.label, spec.tip, spec.min, spec.max, spec.step or 1, spec.get, spec.set, spec.disabled)
	elseif spec.type == "dropdown" then
		local list = spec.list
		p:Dropdown(spec.label, spec.tip,
			spec.items or function()
				local out = Items(list)
				if spec.locked then
					for _, it in ipairs(out) do
						local v = it.value
						it.locked = function() return spec.locked(v) end
						it.lockedTip = spec.lockedTip and spec.lockedTip(v)
					end
				end
				return out
			end,
			spec.get,
			spec.labelFn or function() return LabelOf(list, spec.get()) end,
			spec.set, spec.options, spec.disabled)
	elseif spec.type == "multi" then
		p:MultiSelect(spec.label, spec.tip, spec.items, spec.isChecked, spec.toggle, spec.labelFn, spec.disabled)
	elseif spec.type == "label" then
		p:Label(spec.label, spec.tip, spec.disabled)
	end
	if spec.after then
		spec.after(p)
	end
end

local function Rows(p, list)
	for i = 1, #list, 2 do
		Emit(p, list[i])
		Emit(p, list[i + 1] or { type = "blank" })
	end
end

-- Settings value helpers on a table.
local function Toggle(t, key, label, tip, defaultOn, extra)
	local spec = { type = "toggle", label = label, tip = tip,
		get = function()
			if defaultOn then return t[key] ~= false end
			return t[key] == true
		end,
		set = function(v) t[key] = v and true or false end }
	if extra then for k, v in pairs(extra) do spec[k] = v end end
	return spec
end

local function Num(t, key, default)
	return function()
		local v = t[key]
		if v == nil then v = default end
		return v
	end
end

local function SetNum(t, key)
	return function(v) t[key] = v end
end

---------------------------------------------------------------------------
-- Bar settings
---------------------------------------------------------------------------
local STRATA = {
	{ "BACKGROUND", "Background" }, { "LOW", "Low" }, { "MEDIUM", "Medium" },
	{ "HIGH", "High" }, { "DIALOG", "Dialog" },
}
local SIZING = { { "auto", "Auto Sized" }, { "even", "Even Split" } }
local ORIENT = { { "H", "Horizontal" }, { "V", "Vertical" } }
local BG_STYLE = { { "eui", "EllesmereUI" }, { "modern", "Modern" } }
local EDGES = { { "none", "None" }, { "bottom", "Bottom" }, { "top", "Top" }, { "left", "Left" }, { "right", "Right" } }

local function BuildBarSettings(p, cfg)
	local theme = cfg.theme
	if not theme then
		theme = { style = "eui", euiAlpha = 0.5 }
		cfg.theme = theme
	end
	local vertical = cfg.orientation == "V"

	p:Section("Bar Settings")

	-- Block Sizing (retail Auto Sized / Even Split switch above the section)
	Emit(p, { type = "dropdown", label = "Block Sizing", list = SIZING,
		tip = "Auto Sized: every block takes the width of its content plus its gaps, and one Fill Remaining block takes the rest. Even Split: every block gets an equal share of the bar.",
		get = function() return EDB.BarSizingMode(cfg) end,
		set = function(v) cfg.sizingMode = v; Rebuild() end })
	p:Blank()

	-- Visibility (+ Bar Layer cog) | Hide Border
	VisibilityRow(p, cfg)
	p:Cog("Bar Layer", {
		{ type = "dropdown", label = "Bar Strata",
		  tip = "Screen layer this bar renders on. Raise it to draw over other frames, lower it to sit behind them.",
		  items = function() return Items(STRATA) end,
		  get = function() return cfg.barStrata or "MEDIUM" end,
		  set = function(v) cfg.barStrata = v end,
		  labelFn = function() return LabelOf(STRATA, cfg.barStrata or "MEDIUM") end },
	})
	Emit(p, { type = "toggle", label = "Hide Border", tip = "Hide the 1-pixel outline around the bar.",
		get = function() return cfg.hideBorder == true end,
		set = function(v) cfg.hideBorder = v and true or false end })

	-- Orientation | Background Style (+ EllesmereUI Background cog)
	Emit(p, { type = "dropdown", label = "Orientation", list = ORIENT,
		tip = "Horizontal bars lay blocks left to right; vertical bars stack them top to bottom.",
		get = function() return cfg.orientation == "V" and "V" or "H" end,
		set = function(v)
			cfg.orientation = v
			-- An edge snap that no longer matches the orientation remaps.
			local e = cfg.snapEdge
			if v == "V" and (e == "bottom" or e == "top") then
				cfg.snapEdge = "left"
			elseif v == "H" and (e == "left" or e == "right") then
				cfg.snapEdge = "bottom"
			end
			Rebuild()
		end })
	Emit(p, { type = "dropdown", label = "Background Style", list = BG_STYLE,
		tip = "EllesmereUI matches the window-skin shell; Modern is a flat color.",
		get = function() return theme.style == "modern" and "modern" or "eui" end,
		set = function(v)
			theme.style = v
			-- Selecting Modern starts Bar Opacity at 95.
			if v == "modern" then
				theme.modernColor = theme.modernColor or { r = 0.067, g = 0.067, b = 0.067 }
				theme.modernColor.a = 0.95
			end
		end,
		after = function(pp)
			pp:Cog("EllesmereUI Background", {
				{ type = "slider", label = "Backdrop Dim", min = 0, max = 100, step = 1,
				  get = function() return floor((theme.euiAlpha == nil and 0.5 or theme.euiAlpha) * 100 + 0.5) end,
				  set = function(v) theme.euiAlpha = v / 100 end },
			}, { disabled = function() return theme.style == "modern" end, disabledTip = "This option requires the EllesmereUI Background Style" })
		end })

	-- Bar Opacity (+ Modern color swatch) | Bar Texture
	Emit(p, { type = "slider", label = "Bar Opacity", min = 0, max = 100, step = 1,
		tip = "Opacity of the bar's background; the swatch picks the Modern color.",
		get = function()
			if theme.style == "modern" then
				local c = theme.modernColor
				local a = c and c.a
				if a == nil then a = 0.95 end
				return floor(a * 100 + 0.5)
			end
			local a = theme.euiOpacity
			if a == nil then a = 1 end
			return floor(a * 100 + 0.5)
		end,
		set = function(v)
			if theme.style == "modern" then
				theme.modernColor = theme.modernColor or { r = 0.067, g = 0.067, b = 0.067 }
				theme.modernColor.a = v / 100
			else
				theme.euiOpacity = v / 100
			end
		end,
		after = function(pp)
			pp:Swatch("Modern Color",
				function()
					local c = theme.modernColor or {}
					return c.r or 0.067, c.g or 0.067, c.b or 0.067, 1
				end,
				function(r, g, b)
					theme.modernColor = theme.modernColor or { a = 0.95 }
					theme.modernColor.r, theme.modernColor.g, theme.modernColor.b = r, g, b
				end,
				{ disabled = function() return theme.style ~= "modern" end })
		end })
	Emit(p, { type = "dropdown", label = "Bar Texture",
		tip = "Background texture for this bar, tinted by the bar's color and opacity.",
		items = function()
			-- LibSharedMedia textures registered after login join the list.
			if EDB.EUI and EDB.EUI.AppendSharedMediaTextures and EDB.barTextures then
				EDB.EUI.AppendSharedMediaTextures(EDB.barTextureNames, EDB.barTextureOrder, nil, EDB.barTextures)
			end
			local out = { { value = "none", name = "None" } }
			for _, key in ipairs(EDB.barTextureOrder or {}) do
				if key ~= "none" and key ~= "---" then
					out[#out + 1] = { value = key, name = (EDB.barTextureNames and EDB.barTextureNames[key]) or key }
				end
			end
			return out
		end,
		get = function() return cfg.barTexture or "none" end,
		labelFn = function()
			local key = cfg.barTexture or "none"
			return (EDB.barTextureNames and EDB.barTextureNames[key]) or key
		end,
		set = function(v) cfg.barTexture = v end,
		options = { texturePreview = true, previewPath = function(v)
			return (EDB.barTextures and EDB.barTextures[v]) or "Interface\\Buttons\\WHITE8X8"
		end },
		disabled = function() return theme.style ~= "modern" end })

	-- Full Screen Width | Snap to Screen Edge
	local lenLabel, fullLabel, thickLabel
	if vertical then
		lenLabel, fullLabel, thickLabel = "Height", "Full Screen Height", "Width"
	else
		lenLabel, fullLabel, thickLabel = "Width", "Full Screen Width", "Height"
	end
	Emit(p, { type = "toggle", label = fullLabel, tip = "Sizes the bar to the full screen extent along its axis.",
		get = function() return cfg.lengthMode == "full" end,
		set = function(v) cfg.lengthMode = v and "full" or "custom" end })
	Emit(p, { type = "dropdown", label = "Snap to Screen Edge", list = EDGES,
		tip = "Pins the bar flush against a screen edge; moving the bar in unlock mode sets this back to None.",
		get = function() return cfg.snapEdge or "none" end,
		set = function(v) cfg.snapEdge = v end,
		locked = function(v)
			if vertical then return v == "bottom" or v == "top" end
			return v == "left" or v == "right"
		end,
		lockedTip = function(v)
			if v == "bottom" or v == "top" then return "Not available for vertical bars" end
			return "Not available for horizontal bars"
		end })

	-- Width | Height (length + thickness in screen terms)
	Emit(p, { type = "slider", label = lenLabel, min = 100, max = 3000, step = 10,
		tip = "Size of the bar along its block axis in pixels.",
		get = Num(cfg, "length", 400), set = SetNum(cfg, "length"),
		disabled = function() return cfg.lengthMode == "full" end })
	Emit(p, { type = "slider", label = thickLabel, min = 16, max = 400, step = 1,
		tip = "Size of the bar across its block axis in pixels.",
		get = Num(cfg, "thickness", 30), set = SetNum(cfg, "thickness") })

	-- Text Scale | Hover Highlight Blocks
	Emit(p, { type = "slider", label = "Text Scale", min = 50, max = 150, step = 5,
		tip = "Scales every text element on this bar.",
		get = Num(cfg, "fontScale", 100), set = SetNum(cfg, "fontScale") })
	Emit(p, { type = "toggle", label = "Hover Highlight Blocks", tip = "Shows a faint white wash over each block on mouseover.",
		get = function() return cfg.hoverHighlight == true end,
		set = function(v) cfg.hoverHighlight = v and true or false end })
end

---------------------------------------------------------------------------
-- Block sections
---------------------------------------------------------------------------
local ICON_COLOR_BLOCKS = {
	durability = true, gold = true, travel = true, spec = true,
	profession = true, profession2 = true, currency = true,
	audio = true, location = true, coords = true, ilvl = true, bags = true, ldb = true,
}

local MM_LABELS = {
	menu = "Menu", guild = "Guild", social = "Social", char = "Character", spell = "Spellbook",
	talent = "Talents", ach = "Achievements", quest = "Quests", lfg = "Group Finder", pvp = "PvP",
	journal = "Dungeon Journal", pet = "Mounts & Pets", shop = "Shop", help = "Help",
}

local GOLD_TIP = { { key = "tipSession", label = "Session" }, { key = "tipCharacters", label = "Characters" } }

local function HearthstoneList(s)
	local list = { { "random", "Random Hearthstone" } }
	local owned = {}
	for _, id in ipairs(EDB.TravelHearthstoneIDs or {}) do
		if EDB.TravelIsUsable and EDB.TravelIsUsable(id) then owned[#owned + 1] = id end
	end
	local cur = s.hsChoice
	if cur == nil then cur = s.randomizeHs and "random" or 6948 end
	if type(cur) == "number" then
		local seen = false
		for _, id in ipairs(owned) do if id == cur then seen = true end end
		if not seen then owned[#owned + 1] = cur end
	end
	local names = {}
	for _, id in ipairs(owned) do names[id] = (GetItemInfo(id)) or ("Item " .. id) end
	table.sort(owned, function(a, b) return names[a] < names[b] end)
	for _, id in ipairs(owned) do list[#list + 1] = { id, names[id] } end
	return list
end

local function TypeRows(cfg, b, s)
	local t = b.type
	if t == "audio" then
		local CH = { { "master", "Master" }, { "sfx", "Sound Effects" }, { "music", "Music" }, { "ambience", "Ambience" } }
		return {
			{ type = "dropdown", label = "Audio Channel", list = CH,
			  tip = "Which audio channel the block's volume bar adjusts.",
			  get = function() return s.channel or "master" end, set = function(v) s.channel = v end },
		}
	elseif t == "clock" then
		return {
			{ type = "toggle", label = "Local Time", tip = "Local computer time instead of server time.",
			  get = function()
				if s.localTime == nil then return GetCVar("timeMgrUseLocalTime") == "1" end
				return s.localTime == true
			  end,
			  set = function(v) s.localTime = v and true or false end },
			{ type = "toggle", label = "24 Hour Clock", tip = "Use 24-hour time.",
			  get = function()
				if s.twentyFour == nil then return GetCVar("timeMgrUseMilitaryTime") == "1" end
				return s.twentyFour == true
			  end,
			  set = function(v) s.twentyFour = v and true or false end },
			Toggle(s, "showMail", "Mail Alert", "Shows an envelope icon when you have unread mail."),
			Toggle(s, "showResting", "Resting Icon", "Shows a rest icon while your character is resting."),
		}
	elseif t == "combat" then
		return { Toggle(s, "onlyInCombat", "Show Only In Combat", "Shows the combat status text only while your character is in combat.") }
	elseif t == "ms" then
		local LAT = { { "home", "Home" }, { "world", "World" }, { "both", "Both" } }
		return {
			{ type = "dropdown", label = "Latency", list = LAT,
			  tip = "Which latency to show: home, world, or both side by side.",
			  get = function() return EDB.LatencyMode(s) end, set = function(v) s.latencyMode = v end },
			Toggle(s, "showIcon", "Show Icon", "Shows a house or globe icon marking which latency each value is.", false, {
				after = function(pp)
					local function Off() return s.showIcon ~= true end
					local function FlagsOff() return not b.useIconClassColor and not b.useIconAccentColor and not b.useIconDefaultColor end
					local function Clear() b.useIconClassColor, b.useIconAccentColor, b.useIconDefaultColor = nil, nil, nil end
					pp:Swatch("Accent Color", function() local r, g, bl = Accent(); return r, g, bl, 1 end, function() end,
						{ readonly = true, disabled = Off, active = function() return b.useIconAccentColor == true end,
						  onClick = function() Clear(); b.useIconAccentColor = true; return true end })
					pp:Swatch("Class Colored", function() local r, g, bl = ClassRGB(); return r, g, bl, 1 end, function() end,
						{ readonly = true, disabled = Off, active = function() return b.useIconClassColor == true end,
						  onClick = function() Clear(); b.useIconClassColor = true; return true end })
					pp:Swatch("Custom Color",
						function() local c = b.iconColor; if c then return c.r or 1, c.g or 1, c.b or 1, 1 end return 1, 1, 1, 1 end,
						function(r, g, bl) b.iconColor = { r = r, g = g, b = bl } end,
						{ disabled = Off, active = FlagsOff,
						  onClick = function() if not FlagsOff() then Clear(); return true end end })
				end }),
		}
	elseif t == "location" then
		local W = { { "auto", "Automatic" }, { "manual", "Manual" } }
		local function Inert()
			if EDB.BarSizingMode(cfg) ~= "auto" then return true end
			return EDB.EnsureFillBlock(cfg) == b.id
		end
		return {
			{ type = "dropdown", label = "Width", list = W,
			  tip = "Automatic follows the zone name. Manual holds the block at a fixed width and clips longer names, so it never shifts the blocks beside it.",
			  get = function() return EDB.LocationWidthMode(s) end, set = function(v) s.widthMode = v end,
			  disabled = Inert },
			{ type = "slider", label = "Max Width", min = 60, max = 400, step = 5,
			  tip = "How wide the block stays, whatever the zone is called.",
			  get = function() return s.maxWidth or EDB.LOC_MAX_WIDTH_DEFAULT end,
			  set = function(v) s.maxWidth = v end,
			  disabled = function() return Inert() or EDB.LocationWidthMode(s) ~= "manual" end },
			Toggle(s, "showSubZone", "Zone and Subzone", "Shows the zone and the subzone together instead of the subzone alone.", true),
		}
	elseif t == "coords" then
		local DEC = { { 0, "None" }, { 1, "One" }, { 2, "Two" } }
		return {
			{ type = "dropdown", label = "Decimals", list = DEC,
			  tip = "How precise the coordinates read. More decimals make the block wider.",
			  get = Num(s, "precision", 0), set = SetNum(s, "precision") },
			Toggle(s, "hideInInstance", "Hide in Instance", "Removes the block from the bar in instanced content, where player coordinates are unavailable.", true),
		}
	elseif t == "gold" then
		return {
			Toggle(s, "showIcons", "Show Icon", "Shows the coin icon next to the amount.", true),
			Toggle(s, "showBagSpace", "Show Bag Space", "Shows your free bag slots."),
			Toggle(s, "coinIcons", "Coin Icons", "Uses Blizzard's coin textures instead of the letter suffixes."),
			{ type = "multi", label = "Show Tooltip Data", tip = "Which sections the gold tooltip shows.",
			  items = function()
				local out = {}
				for _, e in ipairs(GOLD_TIP) do out[#out + 1] = { value = e.key, name = e.label } end
				return out
			  end,
			  isChecked = function(k) return s[k] ~= false end,
			  toggle = function(k) s[k] = (s[k] == false) end,
			  labelFn = function()
				local on = {}
				for _, e in ipairs(GOLD_TIP) do if s[e.key] ~= false then on[#on + 1] = e.label end end
				return #on == 0 and "None" or table.concat(on, ", ")
			  end },
			Toggle(s, "abbreviate", "Abbreviate Amount", "Shows large amounts using K/M suffixes (284,208g becomes 284.2Kg) instead of the full grouped number. The tooltip always shows the exact amount."),
		}
	elseif t == "profession" or t == "profession2" then
		local TD = { { "name", "Name and Bar" }, { "values", "Values" } }
		return {
			{ type = "dropdown", label = "Text Display", list = TD,
			  get = function() return s.textDisplay or "name" end, set = function(v) s.textDisplay = v end },
		}
	elseif t == "xprep" then
		local TD = { { "off", "Off" }, { "values", "Values" }, { "percentage", "Percentage" } }
		local TF = { { "context", "With Level / Faction" }, { "plain", "Value Only" } }
		local MODE = { { "auto", "Automatic" }, { "xp", "Experience" }, { "rep", "Reputation" } }
		return {
			{ type = "dropdown", label = "Text Display", list = TD,
			  get = function() return EDB.GetXPRepTextDisplay(s) end, set = function(v) s.textDisplay = v end },
			{ type = "dropdown", label = "Text Format", list = TF,
			  get = function() return s.textFormat or "context" end, set = function(v) s.textFormat = v end,
			  disabled = function() return EDB.GetXPRepTextDisplay(s) == "off" end },
			{ type = "dropdown", label = "Mode", list = MODE,
			  tip = "Automatic shows XP while leveling and reputation at max level.",
			  get = function() return s.mode or "auto" end, set = function(v) s.mode = v end },
		}
	elseif t == "spec" then
		return { Toggle(s, "useUppercase", "Uppercase Text", "Renders the spec text in uppercase.") }
	elseif t == "travel" then
		return {
			{ type = "dropdown", label = "Left Click",
			  tip = "Which hearthstone the left click uses. Random Hearthstone picks a random owned variant each cast. Right click always rolls a random one.",
			  items = function() return Items(HearthstoneList(s)) end,
			  get = function()
				local c = s.hsChoice
				if c == nil then c = s.randomizeHs and "random" or 6948 end
				return c
			  end,
			  labelFn = function()
				local c = s.hsChoice
				if c == nil then c = s.randomizeHs and "random" or 6948 end
				return LabelOf(HearthstoneList(s), c)
			  end,
			  set = function(v) s.hsChoice = v; s.randomizeHs = (v == "random") end },
		}
	elseif t == "micromenu" then
		local AL
		if cfg.orientation == "V" then
			AL = { { "LEFT", "Top" }, { "CENTER", "Center" }, { "RIGHT", "Bottom" } }
		else
			AL = { { "LEFT", "Left" }, { "CENTER", "Center" }, { "RIGHT", "Right" } }
		end
		return {
			{ type = "dropdown", label = "Align Content", list = AL, tip = "Where the icon strip sits inside its slot.",
			  get = function() return b.align or "CENTER" end, set = function(v) b.align = v end },
			Toggle(s, "disableBlizzardMicroMenu", "Hide Blizzard Micro Menu", "Hides Blizzard's own micro menu while any bar has this on."),
			{ type = "slider", label = "Menu Spacing", min = 0, max = 16, step = 1,
			  tip = "Gap between the main menu button and the icon row.",
			  get = Num(s, "mainMenuSpacing", 4), set = SetNum(s, "mainMenuSpacing") },
			{ type = "slider", label = "Icon Spacing", min = 0, max = 16, step = 1,
			  tip = "Gap between the micro menu icons.",
			  get = function() return floor((s.iconSpacing or 2) + 0.5) end, set = SetNum(s, "iconSpacing") },
			{ type = "multi", label = "Menu Elements", tip = "Which micro menu buttons this block shows.",
			  items = function()
				local out = {}
				for _, key in ipairs(EDB.GetMicroMenuOrder(s, {})) do
					out[#out + 1] = { value = key, name = MM_LABELS[key] or key }
				end
				return out
			  end,
			  isChecked = function(k) return EDB.MicroMenuButtonOn(s, k) and true or false end,
			  toggle = function(k) s[k] = not EDB.MicroMenuButtonOn(s, k) end,
			  labelFn = function()
				local n, total = 0, 0
				for _, key in ipairs(EDB.GetMicroMenuOrder(s, {})) do
					total = total + 1
					if EDB.MicroMenuButtonOn(s, key) then n = n + 1 end
				end
				return n .. " of " .. total .. " shown"
			  end },
		}
	elseif t == "currency" then
		return {
			{ type = "dropdown", label = "Currency", tip = "Pick any currency your character has discovered.",
			  items = function()
				local values, order = EDB.BuildCurrencyList()
				local out = { { value = 0, name = "Select a currency" } }
				for _, id in ipairs(order) do out[#out + 1] = { value = id, name = values[id] } end
				return out
			  end,
			  get = function() return s.currencyId or 0 end,
			  labelFn = function()
				if not s.currencyId then return "Select a currency" end
				local name = GetCurrencyInfo(s.currencyId)
				return (name and name ~= "") and name or tostring(s.currencyId)
			  end,
			  set = function(v) if v == 0 then s.currencyId = nil else s.currencyId = v end end },
			Toggle(s, "showIcon", "Show Icon", "Shows the currency icon next to the amount.", true),
			Toggle(s, "showDescription", "Show Description", "Shows the currency's description text in the tooltip. Turn off for a compact tooltip with just the name and the amount.", true),
		}
	elseif t == "bags" then
		local DISPLAY = { { "free", "Free" }, { "used", "Used" }, { "freeTotal", "Free / Total" }, { "usedTotal", "Used / Total" } }
		return {
			{ type = "dropdown", label = "Display", list = DISPLAY, tip = "Which slot count the block shows.",
			  get = function() return s.value or "free" end, set = function(v) s.value = v end },
			{ type = "slider", label = "Low Space Warning", min = 0, max = 50, step = 1,
			  tip = "Colors the number when free slots drop below this many; the swatch picks the color. Zero turns it off.",
			  get = Num(s, "lowThreshold", 0), set = SetNum(s, "lowThreshold"),
			  after = function(pp)
				pp:Swatch("Low Space Color",
					function()
						local d = EDB.BAGS_LOW_COLOR
						local c = s.lowColor
						if c then return c.r or d[1], c.g or d[2], c.b or d[3], 1 end
						return d[1], d[2], d[3], 1
					end,
					function(r, g, bl) s.lowColor = { r = r, g = g, b = bl } end,
					{ disabled = function() return (s.lowThreshold or 0) <= 0 end })
			  end },
		}
	elseif t == "ilvl" then
		local VAL = { { "equipped", "Equipped" }, { "total", "Total" }, { "both", "Both" } }
		local DEC = { { 0, "None" }, { 1, "One" }, { 2, "Two" } }
		return {
			{ type = "dropdown", label = "Item Level", list = VAL,
			  tip = "Equipped counts your worn gear. Total also counts upgrades sitting in your bags.",
			  get = function() return s.value or "equipped" end, set = function(v) s.value = v end },
			{ type = "dropdown", label = "Decimals", list = DEC, tip = "How many decimal places the number carries.",
			  get = Num(s, "precision", 0), set = SetNum(s, "precision") },
		}
	elseif t == "ldb" then
		return {
			{ type = "dropdown", label = "Plugin",
			  tip = "Any LibDataBroker plugin registered right now. One block per plugin -- add the block again for a second one.",
			  items = function()
				local values, order = EDB.BuildLDBList()
				local out = { { value = "", name = "Select a plugin" } }
				for _, name in ipairs(order) do out[#out + 1] = { value = name, name = values[name] } end
				if s.source and not values[s.source] then
					out[#out + 1] = { value = s.source, name = s.source .. " |cff808080(not loaded)|r" }
				end
				return out
			  end,
			  get = function() return s.source or "" end,
			  labelFn = function() return s.source or "Select a plugin" end,
			  set = function(v) if v == "" then s.source = nil else s.source = v end end },
			Toggle(s, "showIcon", "Show Icon", "Shows the plugin's own icon next to its text.", true),
			Toggle(s, "showText", "Show Text", "Shows the plugin's text. Off leaves an icon-only block that still carries the plugin's tooltip and clicks.", true),
			Toggle(s, "showLabel", "Show Label", "Prefixes the plugin's own name to its text."),
			Toggle(s, "stripColors", "Strip Colors", "Removes the color codes the plugin writes into its own text, so this block's Text Color applies. Off keeps the plugin's colors.", true),
			{ type = "slider", label = "Max Width", min = 0, max = 400, step = 5,
			  tip = "Holds the block at this width and clips longer text, so a plugin whose text keeps changing length never shifts the blocks beside it. Zero sizes the block to whatever the plugin currently says.",
			  get = function() return s.maxWidth or 0 end,
			  set = function(v) if v == 0 then s.maxWidth = nil else s.maxWidth = v end end },
		}
	end
	return {}
end

-- The right cell of the Icon Color row (retail iconRowRight).
local function IconRowRight(b, s)
	local t = b.type
	if t == "travel" then
		return Toggle(s, "clickableTeleports", "Show Challenge Mode Portals",
			"Show the challenge mode teleport section in the tooltip. Ready rows are click-to-teleport.", true)
	elseif t == "audio" then
		return Toggle(s, "showIcon", "Show Icon", "Shows the audio icon next to the volume bar.", true)
	elseif t == "profession" or t == "profession2" then
		return Toggle(s, "showIcon", "Show Icon", "Shows the profession icons next to the text.", true)
	elseif t == "spec" then
		return Toggle(s, "showIcon", "Show Icon", "Shows the spec icon next to the text.", true)
	elseif t == "location" then
		return Toggle(s, "showIcon", "Show Icon", "Shows the map pin next to the zone name.", true)
	elseif t == "coords" then
		return Toggle(s, "showIcon", "Show Icon", "Shows the marker icon next to the coordinates.", true)
	elseif t == "bags" then
		return Toggle(s, "showIcon", "Show Icon", "Shows the bag icon next to the slot count.", true)
	elseif t == "durability" then
		return Toggle(s, "showIcon", "Show Icon", "Shows the icon next to the durability readout.")
	elseif t == "ilvl" then
		local PRE = { { "none", "None" }, { "short", "ILVL" }, { "long", "Item Level" }, { "icon", "Icon" } }
		return { type = "dropdown", label = "Prefix", list = PRE,
			tip = "What sits in front of the number. Icon shows the character icon; the color swatches on the left tint it.",
			get = function() return s.prefix or "short" end, set = function(v) s.prefix = v end }
	elseif t == "gold" then
		return Toggle(s, "showSmall", "Show Silver and Copper", "Shows silver and copper, not just gold.")
	end
	return { type = "blank" }
end

local function BuildBlockSection(p, cfg, b, secName)
	local s = b.settings
	if not s then
		s = {}
		b.settings = s
	end
	local vertical = cfg.orientation == "V"
	local isSpacer = b.type == "spacer"
	local mode = EDB.BarSizingMode(cfg)
	local isFill = mode == "auto" and EDB.EnsureFillBlock(cfg) == b.id

	p:Section(secName)

	-- Sizing (auto mode): per-side gaps (not on the fill block) and the
	-- Fill Remaining / Force Centered designations.
	if mode == "auto" then
		if not isFill then
			local gl, gr = "Left Gap", "Right Gap"
			if vertical then gl, gr = "Top Gap", "Bottom Gap" end
			Emit(p, { type = "slider", label = gl, min = 0, max = 200, step = 1,
				tip = "Empty space reserved on this side of the block's content.",
				get = function() local l = EDB.ContentGapsOf(b); return l end,
				set = function(v) b.contentGapL = v end })
			Emit(p, { type = "slider", label = gr, min = 0, max = 200, step = 1,
				tip = "Empty space reserved on this side of the block's content.",
				get = function() local _, r = EDB.ContentGapsOf(b); return r end,
				set = function(v) b.contentGapR = v end })
		end
		Emit(p, { type = "toggle", label = "Set as 'Fill Remaining Space' Block",
			tip = "Stretches this block to absorb the space the sized blocks leave over; exactly one block per bar fills.",
			get = function() return EDB.EnsureFillBlock(cfg) == b.id end,
			set = function(v)
				if v then
					cfg.fillBlockId = b.id
					Rebuild()
				end
			end,
			disabled = function() return EDB.EnsureFillBlock(cfg) == b.id end })
		Emit(p, { type = "toggle", label = "Force Centered",
			tip = "Pins this block's content to the exact center of the bar; blocks before it pack left, blocks after pack right. Combined with Fill Remaining, the block also absorbs the leftover space around the center.",
			get = function() return cfg.centerBlockId == b.id end,
			set = function(v)
				if v then
					cfg.centerBlockId = b.id
				elseif cfg.centerBlockId == b.id then
					cfg.centerBlockId = nil
				end
			end })
	end

	-- Text Align (+ Text Position) | Content Scale (+ Content Position)
	if not isSpacer then
		local AL
		if vertical then
			AL = { { "LEFT", "Top" }, { "CENTER", "Center" }, { "RIGHT", "Bottom" } }
		else
			AL = { { "LEFT", "Left" }, { "CENTER", "Center" }, { "RIGHT", "Right" } }
		end
		local function TextPosCog(pp)
			pp:Cog("Text Position", {
				{ type = "slider", label = "X Offset", min = -50, max = 50, step = 1, get = Num(b, "textXOff", 0), set = SetNum(b, "textXOff") },
				{ type = "slider", label = "Y Offset", min = -50, max = 50, step = 1, get = Num(b, "textYOff", 0), set = SetNum(b, "textYOff") },
			}, { icon = "directions" })
		end
		if b.type == "micromenu" then
			Emit(p, { type = "toggle", label = "Enable Text", tip = "Shows the online friend and guild counters.",
				get = function() return s.hideSocialText ~= true end,
				set = function(v) s.hideSocialText = not v end,
				after = TextPosCog })
		else
			Emit(p, { type = "dropdown", label = "Text Align", list = AL, tip = "Where the block's content sits inside its slot.",
				get = function() return b.align or "CENTER" end,
				set = function(v)
					b.align = v
					-- XP / Rep: a picked alignment also places the bar's label.
					if b.type == "xprep" then b.labelAlign = v end
				end,
				after = TextPosCog })
		end
		Emit(p, { type = "slider", label = "Content Scale", min = 50, max = 200, step = 5,
			tip = "Scales this block's content as a group inside its slot.",
			get = Num(b, "scale", 100), set = SetNum(b, "scale"),
			after = function(pp)
				pp:Cog("Content Position", {
					{ type = "slider", label = "X Offset", min = -50, max = 50, step = 1, get = Num(b, "xOff", 0), set = SetNum(b, "xOff") },
					{ type = "slider", label = "Y Offset", min = -50, max = 50, step = 1, get = Num(b, "yOff", 0), set = SetNum(b, "yOff") },
				}, { icon = "directions" })
			end })
	end

	-- Block Background (+ swatch) | Text Color
	Emit(p, { type = "toggle", label = "Block Background", tip = "Tints this block's slot with its own color.",
		get = function() return b.bg ~= nil end,
		set = function(v)
			if v then
				b.bg = b.bg or { r = 0, g = 0, b = 0, a = 0.5 }
			else
				b.bg = nil
			end
		end,
		after = function(pp)
			pp:Swatch("Block Background Color",
				function()
					local c = b.bg or {}
					return c.r or 0, c.g or 0, c.b or 0, c.a or 0.5
				end,
				function(r, g, bl, a) b.bg = { r = r, g = g, b = bl, a = a or 0.5 } end,
				{ alpha = true, disabled = function() return b.bg == nil end })
		end })
	if isSpacer then
		p:Blank()
	else
		p:Label("Text Color")
		TextColorSwatches(p, b)
	end

	-- Icon Color | per-type right cell
	if ICON_COLOR_BLOCKS[b.type] then
		p:Label("Icon Color")
		IconColorSwatches(p, b, s)
		Emit(p, IconRowRight(b, s))
	end

	-- Type rows, then Icon Style (beside Menu Elements on the micro menu)
	local rows = TypeRows(cfg, b, s)
	if EDB.BlockHasIconStyle(b.type) then
		local STYLE = { { "custom", "Custom" }, { "wow", "Blizzard" } }
		rows[#rows + 1] = { type = "dropdown", label = "Icon Style", list = STYLE,
			get = function() return s.iconStyle or "custom" end,
			-- Rebuild: the icon color swatches depend on the style.
			set = function(v) s.iconStyle = v; Rebuild() end,
			disabled = function()
				if b.type == "ilvl" then return s.prefix ~= "icon" end
				if b.type == "gold" then return s.showIcons == false end
				if b.type == "micromenu" then return false end
				return s.showIcon == false
			end }
	end
	Rows(p, rows)
end

---------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------
local function Build(p)
	local cfg = SelectedBar()
	local key = PageKey()
	local names = {}
	sectionNames[key] = names
	if not cfg then
		p:Section("DataBars")
		p:Paragraph("You have no DataBars yet. Pick a template above to create one: an empty bar, a full-width info bar, a small companion for the minimap, or a micro menu strip.")
		return
	end

	BuildBarSettings(p, cfg)

	local used = {}
	for _, b in ipairs(cfg.blocks) do
		local base = BlockLabel(b)
		used[base] = (used[base] or 0) + 1
		local secName = used[base] > 1 and (base .. " " .. used[base]) or base
		names[b.id] = secName
		BuildBlockSection(p, cfg, b, secName)
	end
	if #cfg.blocks == 0 then
		p:Section("Blocks")
		p:Paragraph("This bar has no blocks yet. Use \"+ Add Block\" above the bar preview to add a clock, gold, the micro menu and more.")
	end
end

-- Deep link from a live block to its own settings (a Currency or Broker
-- block with nothing picked yet sends the player to its picker).
function EDB.OpenBlockSettings(barId, blockId)
	local p = Profile()
	if p then
		p.selectedBarId = barId
	end
	if not ns.OpenSettingsModule then
		return
	end
	-- Opening the module shows the page of the (newly) selected bar.
	local page = ns.OpenSettingsModule("dataBars")
	local names = sectionNames[PageKey()]
	if page and names and names[blockId] then
		page:Reveal("\2" .. names[blockId])
	end
end

ns.RegisterSettingsModule({
	key = "dataBars",
	name = "DataBars",
	group = "QoL Addons",
	tabs = {
		{ key = "dataBars", name = "DataBars", description = "User-created info bars: clock, gold, XP, micro menu and more.",
		  build = Build,
		  header = BuildHeader,
		  pageKey = PageKey },
	},
	reset = function()
		-- Resets the SELECTED bar's appearance and behavior to defaults; keeps
		-- its id, name and blocks. Never wipes the bar list.
		local cfg = SelectedBar()
		if not cfg then
			return
		end
		cfg.orientation = "H"
		cfg.lengthMode = "custom"
		cfg.length = 400
		cfg.thickness = 30
		cfg.fontScale = 100
		cfg.theme = { style = "eui", euiAlpha = 0.5, modernColor = { r = 0.067, g = 0.067, b = 0.067, a = 0.95 } }
		cfg.hideBorder = nil
		cfg.visibility = "always"
		cfg.visibilityModes = nil
		cfg.visibilityMatch = nil
		for _, axis in ipairs(EDB.VIS_AXES) do
			if axis.show:match("^vis") then cfg[axis.show] = nil end
			if axis.hide:match("^vis") then cfg[axis.hide] = nil end
		end
		cfg.savedPos = nil
		cfg.snapEdge = nil
		cfg.barStrata = nil
		EDB.ApplyBar(cfg.id)
		Rebuild()
	end,
	resetTip = "Set the selected DataBar's look, size, visibility and position back to the defaults (its blocks stay).",
})
