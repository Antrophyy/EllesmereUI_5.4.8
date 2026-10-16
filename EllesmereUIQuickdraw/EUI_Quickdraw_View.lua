-------------------------------------------------------------------------------
--  EUI_Quickdraw_View.lua (5.4.8 port of retail Geometry / View / Paint)
--
--  Geometry of a menu (QD.BuildLayout: where each entry sits, and the numbers
--  the secure snippet needs to pick an entry) and the drawing of an open
--  menu: icons, selection highlight, cooldowns, usability dimming, world
--  marker pips, the action text label. Everything drawn here lives on a
--  plain (not protected) frame inside the menu's secure frame, so it can be
--  updated in combat.
-------------------------------------------------------------------------------
local ns = EllesmereUI
local QD = ns.Quickdraw

local pi, sin, cos, sqrt = math.pi, math.sin, math.cos, math.sqrt
local floor, ceil, min, max, abs = math.floor, math.ceil, math.min, math.max, math.abs
local ipairs, type = ipairs, type

local DEAD_ZONE = 24      -- retail: release inside it cancels
local FAN_SHRINK = 0.85   -- fan neighbours shrink per step
local FAN_FADE = 0.75     -- and fade per step
local WHITE = "Interface\\Buttons\\WHITE8X8"

-- Selection color (retail SelectColor): class, custom, else the UI accent.
function QD.SelectColor(index)
	if QD.ACfg(index, "useClassColor") then
		local _, class = UnitClass("player")
		local c = RAID_CLASS_COLORS and class and RAID_CLASS_COLORS[class]
		if c then return c.r, c.g, c.b end
	end
	if not QD.ACfg(index, "selectColorCustom") and ns.ResolveAccent then
		return ns.ResolveAccent()
	end
	local sc = QD.ACfg(index, "selectColor")
	if type(sc) == "table" then return sc[1] or 1, sc[2] or 1, sc[3] or 1 end
	return 0.047, 0.824, 0.624
end

-------------------------------------------------------------------------------
--  Geometry
-------------------------------------------------------------------------------
-- Flattened entries (Grid / Fan): a nest shows its menu's entries in place.
local function Flatten(index)
	local out = {}
	for _, slot in ipairs(QD.UsableSlots(index)) do
		if slot.kind == "palette" then
			for _, child in ipairs(QD.ChildSlots(QD.ChildIndex(slot))) do
				out[#out + 1] = { slot = child, child = true }
			end
		else
			out[#out + 1] = { slot = slot }
		end
	end
	return out
end

-- Layout of palette `index`:
--   L.mode, L.n (cells the snippet picks among at the top level),
--   L.cells[c] = { slot, x, y, size, parent (nest top index) }
--   L.attrs = the qd-* attributes of the secure button.
function QD.BuildLayout(index)
	local pa = QD.PA(index)
	local mode = pa.layout
	if mode ~= "FAN" and mode ~= "GRID" then mode = "ARC" end
	local iconSize = max(8, pa.iconSize or 40)
	local L = { mode = mode, cells = {}, iconSize = iconSize, attrs = {}, index = index }
	local A = L.attrs
	A["qd-layout"] = mode

	if mode == "ARC" then
		local top = QD.UsableSlots(index)
		local n = #top
		L.n = n
		local deg = min(360, max(30, pa.arcSpan or 360))
		local rot = (pa.arcRotation or 0) * pi / 180
		local full = deg >= 359.5
		local step, start
		if full then
			step = n > 0 and (2 * pi / n) or 0
			start = rot
		else
			local span = deg * pi / 180
			step = n > 1 and (span / (n - 1)) or 0
			start = rot - span * 0.5
		end
		-- Menu Radius is a minimum: the ring grows until icons stop touching.
		local R = pa.radius or 100
		if n > 1 and step > 0 and step * 0.5 < pi * 0.5 then
			R = max(R, (iconSize * 1.414) / (2 * sin(step * 0.5)))
		end
		L.radius = R
		for k = 1, n do
			local a = start + (k - 1) * step
			L.cells[k] = { slot = top[k], x = R * sin(a), y = R * cos(a), size = iconSize, angle = a }
		end
		A["qd-n"] = n
		A["qd-step"] = step
		A["qd-start"] = start
		A["qd-full"] = full and true or nil
		A["qd-dead"] = DEAD_ZONE

		-- Nests: the nested menu's entries on an outer arc centred on the nest.
		local childSize = iconSize * min(1, max(0.4, pa.nestScale or 0.8))
		local CR = R + iconSize * 0.5 + (pa.nestBand or 40) + childSize * 0.5
		local maxSpan = (pa.arcChildMaxSpan or 90) * pi / 180
		local contained = pa.arcChildOverflow ~= "MIDPOINT"
		local anyNest = false
		local c = n
		for k = 1, n do
			local slot = top[k]
			if slot.kind == "palette" then
				local children = QD.ChildSlots(QD.ChildIndex(slot))
				local m = #children
				if m > 0 then
					anyNest = true
					local cst = (childSize * 1.25) / CR
					if m > 1 then cst = min(cst, maxSpan / (m - 1)) end
					if contained and n > 1 and step > 0 then cst = min(cst, step / m) end
					local cs = L.cells[k].angle - (m - 1) * cst * 0.5
					A["qd-nest" .. k] = m
					A["qd-nb" .. k] = c
					A["qd-cs" .. k] = cs
					A["qd-cst" .. k] = cst
					L.cells[k].nest = { first = c + 1, last = c + m }
					for j = 1, m do
						local a = cs + (j - 1) * cst
						c = c + 1
						L.cells[c] = { slot = children[j], x = CR * sin(a), y = CR * cos(a), size = childSize, parent = k }
					end
				end
			end
		end
		if anyNest then
			A["qd-cband"] = (R + iconSize * 0.5 + CR - childSize * 0.5) * 0.5
		end
		L.total = c
		return L
	end

	local flat = Flatten(index)
	local n = #flat
	L.n = n
	L.total = n
	A["qd-n"] = n
	local gap = max(0, pa.fanGap or 10)
	local pitch = iconSize + gap
	A["qd-pitch"] = pitch
	for i = 1, n do
		L.cells[i] = { slot = flat[i].slot, x = 0, y = 0, size = iconSize, flatChild = flat[i].child }
	end

	if mode == "GRID" then
		local cols
		if pa.gridAutoColumns ~= false then
			cols = max(1, ceil(sqrt(max(1, n))))
		else
			cols = max(1, min(max(1, n), pa.gridColumns or 4))
		end
		local rows = max(1, ceil(n / cols))
		A["qd-cols"] = cols
		A["qd-rows"] = rows
		for i = 1, n do
			local col = (i - 1) % cols
			local row = floor((i - 1) / cols)
			L.cells[i].x = (col - (cols - 1) * 0.5) * pitch
			L.cells[i].y = -(row - (rows - 1) * 0.5) * pitch
		end
		return L
	end

	-- FAN: a strip steered by the mouse wheel; the centred entry is selected.
	A["qd-vis"] = max(0, min(4, floor(pa.fanVisible or 2)))
	A["qd-horiz"] = pa.fanOrientation ~= "VERTICAL" and true or nil
	A["qd-inv"] = pa.fanInvert and true or nil
	A["qd-mouse"] = pa.fanMouseSelect ~= false and true or nil
	A["qd-half"] = iconSize * 0.5
	return L
end

-------------------------------------------------------------------------------
--  Drawing
-------------------------------------------------------------------------------
local View = {}
QD.View = View

local function MakeIcon(view)
	local f = CreateFrame("Frame", nil, view)
	f:SetSize(40, 40)
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetTexture(0, 0, 0, 0.8)
	f.bg:SetPoint("TOPLEFT", -1, 1)
	f.bg:SetPoint("BOTTOMRIGHT", 1, -1)
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetAllPoints()
	f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	-- selection border (4 edges, 2 px)
	f.edges = {}
	for i = 1, 4 do
		local t = f:CreateTexture(nil, "OVERLAY")
		t:SetTexture(WHITE)
		f.edges[i] = t
	end
	f.edges[1]:SetPoint("TOPLEFT", -2, 2); f.edges[1]:SetPoint("TOPRIGHT", 2, 2); f.edges[1]:SetHeight(2)
	f.edges[2]:SetPoint("BOTTOMLEFT", -2, -2); f.edges[2]:SetPoint("BOTTOMRIGHT", 2, -2); f.edges[2]:SetHeight(2)
	f.edges[3]:SetPoint("TOPLEFT", -2, 2); f.edges[3]:SetPoint("BOTTOMLEFT", -2, -2); f.edges[3]:SetWidth(2)
	f.edges[4]:SetPoint("TOPRIGHT", 2, 2); f.edges[4]:SetPoint("BOTTOMRIGHT", 2, -2); f.edges[4]:SetWidth(2)
	f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
	f.cd:SetAllPoints()
	f.pip = f:CreateTexture(nil, "OVERLAY")
	f.pip:SetTexture(WHITE)
	f.pip:SetSize(6, 6)
	f.pip:SetPoint("TOPRIGHT", -2, -2)
	f.pip:SetVertexColor(1, 1, 1, 0.95)
	f.pip:Hide()
	return f
end

local function SetSelected(f, on, r, g, b)
	for i = 1, 4 do
		if on then
			f.edges[i]:SetVertexColor(r, g, b, 1)
			f.edges[i]:Show()
		else
			f.edges[i]:Hide()
		end
	end
end

-- The drawing frame of a menu (child of its secure ring frame).
function View.Ensure(index, ring)
	if ring.view then return ring.view end
	local view = CreateFrame("Frame", nil, ring)
	view:SetPoint("CENTER")
	view:SetSize(1, 1)
	view.icons = {}
	view.index = index
	view.center = view:CreateTexture(nil, "ARTWORK")
	view.center:SetTexture(WHITE)
	view.center:SetSize(6, 6)
	view.center:SetPoint("CENTER")
	view.label = view:CreateFontString(nil, "OVERLAY")
	ns.ApplyModuleFont(view.label, 14, QD.FONT_KEY)
	view.label:SetText("")
	view.label:Hide()
	ring.view = view
	ring:HookScript("OnShow", function() View.Open(index) end)
	ring:HookScript("OnHide", function() View.Close(index) end)
	return view
end

local function Icon(view, c)
	local f = view.icons[c]
	if not f then
		f = MakeIcon(view)
		view.icons[c] = f
	end
	return f
end

-- Puts the icons where the layout says (out of combat, or Fan in combat).
function View.Layout(index, L, ring)
	local view = View.Ensure(index, ring)
	view.L = L
	for c = (L.total or 0) + 1, #view.icons do view.icons[c]:Hide() end
	for c = 1, L.total or 0 do
		local cell = L.cells[c]
		local f = Icon(view, c)
		f:ClearAllPoints()
		f:SetPoint("CENTER", view, "CENTER", cell.x, cell.y)
		f:SetSize(cell.size, cell.size)
		f:SetAlpha(1)
		f.icon:SetTexture(QD.SlotIcon(cell.slot))
		f.slot = cell.slot
		SetSelected(f, false)
		if cell.parent then f:Hide() else f:Show() end
	end
	view.center:SetShown(L.mode == "ARC")
	ns.ApplyModuleFont(view.label, 14, QD.FONT_KEY)
	if L.mode == "FAN" then View.LayoutFan(index) end
end

-- Fan: the selected entry in the middle, neighbours shrinking outwards.
function View.LayoutFan(index)
	local ring = QD.Secure and QD.Secure.rings[index]
	local view = ring and ring.view
	local L = view and view.L
	if not L or L.mode ~= "FAN" then return end
	local btn = QD.Secure.buttons[index]
	local sel = btn and btn:GetAttribute("qd-sel") or 1
	local A = L.attrs
	local vis, pitch, horiz = A["qd-vis"] or 0, A["qd-pitch"] or 50, A["qd-horiz"]
	for c = 1, L.total do
		local f = view.icons[c]
		local off = c - sel
		if f and abs(off) <= vis then
			local size = L.iconSize * (FAN_SHRINK ^ abs(off))
			local along = off * pitch
			f:ClearAllPoints()
			if horiz then
				f:SetPoint("CENTER", view, "CENTER", along, 0)
			else
				f:SetPoint("CENTER", view, "CENTER", 0, -along)
			end
			f:SetSize(size, size)
			f:SetAlpha(FAN_FADE ^ abs(off))
			f:Show()
		elseif f then
			f:Hide()
		end
	end
	view.hover = nil
	View.Update(index, true)
end

-- Cursor position relative to the menu centre, in the menu's units.
local function PointerDelta(ring)
	local cx, cy = ring:GetCenter()
	if not cx then return nil end
	local x, y = GetCursorPosition()
	local es = ring:GetEffectiveScale()
	return x / es - cx, y / es - cy
end

-- Hover highlight, nests, label, cooldowns.
function View.Update(index, force)
	local ring = QD.Secure.rings[index]
	local btn = QD.Secure.buttons[index]
	local view = ring and ring.view
	local L = view and view.L
	if not L or not btn then return end
	local dx, dy = PointerDelta(ring)
	local hit = QD.Secure.InsecureHit(btn, dx, dy)
	if hit == view.hover and not force then return end
	view.hover = hit
	local r, g, b = QD.SelectColor(index)
	view.center:SetVertexColor(r, g, b, 0.8)
	-- which nest is open: the hovered nest entry or one of its children
	local openNest = nil
	if hit and L.mode == "ARC" then
		local cell = L.cells[hit]
		if cell then openNest = cell.parent or (cell.nest and hit) end
	end
	for c = 1, L.total do
		local cell = L.cells[c]
		local f = view.icons[c]
		if f then
			if cell.parent then
				f:SetShown(cell.parent == openNest)
			end
			SetSelected(f, c == hit, r, g, b)
		end
	end
	local pa = QD.PA(index)
	if hit and pa.showActionText and L.cells[hit] and view.icons[hit] then
		local f = view.icons[hit]
		view.label:ClearAllPoints()
		view.label:SetPoint("TOP", f, "BOTTOM", 0, -4)
		view.label:SetText(QD.SlotName(L.cells[hit].slot))
		view.label:SetTextColor(r, g, b, 1)
		view.label:Show()
	else
		view.label:Hide()
	end
end

-- Cooldowns, usability and marker pips of the shown icons.
function View.UpdateState(index)
	local ring = QD.Secure.rings[index]
	local view = ring and ring.view
	local L = view and view.L
	if not L then return end
	local pa = QD.PA(index)
	local showCD, dim, pips = pa.showCooldowns ~= false, pa.showUsability ~= false, pa.worldMarkerPip ~= false
	for c = 1, L.total do
		local f = view.icons[c]
		local slot = L.cells[c].slot
		if f and slot then
			local start, dur = nil, nil
			if showCD then start, dur = QD.SlotCooldown(slot) end
			if start and dur and dur > 1.5 then
				CooldownFrame_SetTimer(f.cd, start, dur, 1)
			else
				f.cd:Hide()
			end
			if dim and not QD.SlotUsableNow(slot) then
				f.icon:SetVertexColor(0.4, 0.4, 0.4)
			else
				f.icon:SetVertexColor(1, 1, 1)
			end
			f.pip:SetShown(pips and QD.SlotMarkerPlaced(slot))
		end
	end
end

local ticker = CreateFrame("Frame")
ticker:Hide()
local openSet = {}
local elapsedState = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
	elapsedState = elapsedState + elapsed
	local doState = elapsedState > 0.2
	if doState then elapsedState = 0 end
	for index in pairs(openSet) do
		View.Update(index)
		if doState then View.UpdateState(index) end
	end
end)

function View.Open(index)
	local ring = QD.Secure.rings[index]
	if ring and ring.view then ring.view.hover = -1 end
	openSet[index] = true
	ticker:Show()
	View.Update(index, true)
	View.UpdateState(index)
end

function View.Close(index)
	openSet[index] = nil
	if next(openSet) == nil then ticker:Hide() end
end
