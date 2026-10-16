-------------------------------------------------------------------------------
--  EUI_ActionBars_Bars.lua  (5.4.8 port)
--
--  The bars (retail EllesmereUIActionBars.lua LayoutBar / CreateBarFrame /
--  paging / visibility / mouseover fade, EUI_ActionBars_Visibility.lua,
--  EUI_ActionBars_ExtraBars.lua): secure bar frames, the grid layout (icon
--  size, spacing, icons, rows, orientation, grow direction, icon order),
--  paging, the Visibility checklist as secure state drivers, Bar Opacity and
--  the mouseover fade (Show All Bars on Mouseover, Show When Spellbook Is Open,
--  Show During Drag), Bar Background, Toggle Action Bar keys, Action Bar 1
--  paging arrows, Blizzard's bars switched off, the Micro Menu, Bag Bar and
--  Extra Action Button holders and the Unlock Mode movers.
-------------------------------------------------------------------------------
local addonName, P = ...
local EAB = P.EAB
local ns = P.ns

local floor, ceil, max, min, abs = math.floor, math.ceil, math.max, math.min, math.abs
local pairs, ipairs, tostring, format = pairs, ipairs, tostring, string.format
local InCombatLockdown = InCombatLockdown

local barFrames = {}
P.barFrames = barFrames
EAB.barFrames = barFrames
local hoverStates = {}
P.hoverStates = hoverStates
local hiddenParent = CreateFrame("Frame", "EABHiddenParent", UIParent)
hiddenParent:Hide()
P.hiddenParent = hiddenParent

-------------------------------------------------------------------------------
--  Positions
-------------------------------------------------------------------------------
function P.GetPosition(key)
	local p = P.Profile()
	local pos = p.barPositions and p.barPositions[key]
	if pos and pos.point then
		return pos
	end
	return P.DEFAULT_POSITIONS[key] or { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 }
end

-- While Unlock Mode is open the movers own the spot; an unlock anchor (Anchor
-- in Unlock Mode) owns it afterwards.
function P.PlaceFrame(frame, key)
	if ns._unlockActive and frame._eabPlaced and frame:GetNumPoints() > 0 then
		return
	end
	frame._eabPlaced = true
	local pos = P.GetPosition(key)
	frame:ClearAllPoints()
	frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
	if not ns._unlockActive and ns.IsUnlockAnchored and ns.IsUnlockAnchored(key) and ns.ReapplyOwnAnchor then
		ns.ReapplyOwnAnchor(key)
	end
end

-- Anchor point a bar keeps when it resizes (retail growth direction).
local function GrowPoint(s, isVertical)
	local g = (s.growDirection or "up"):upper()
	if isVertical then
		if g == "UP" then return "BOTTOM" elseif g == "DOWN" then return "TOP" end
	else
		if g == "RIGHT" then return "LEFT" elseif g == "LEFT" then return "RIGHT" end
	end
	return "CENTER"
end

local POINT_X = { LEFT = -0.5, RIGHT = 0.5, TOPLEFT = -0.5, TOPRIGHT = 0.5, BOTTOMLEFT = -0.5, BOTTOMRIGHT = 0.5 }
local POINT_Y = { TOP = 0.5, BOTTOM = -0.5, TOPLEFT = 0.5, TOPRIGHT = 0.5, BOTTOMLEFT = -0.5, BOTTOMRIGHT = -0.5 }

-- Saves a frame's place as an offset of its grow point from the screen center.
function P.SavePosition(key, frame, point)
	local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local cx, cy = frame:GetCenter()
	if not cx then
		return
	end
	local ux, uy = UIParent:GetCenter()
	local w, h = frame:GetWidth() * scale, frame:GetHeight() * scale
	point = point or "CENTER"
	local x = cx * scale - ux + (POINT_X[point] or 0) * w
	local y = cy * scale - uy + (POINT_Y[point] or 0) * h
	local p = P.Profile()
	p.barPositions[key] = {
		point = point, relPoint = "CENTER",
		x = floor(x * 2 + 0.5) / 2, y = floor(y * 2 + 0.5) / 2,
	}
end

-------------------------------------------------------------------------------
--  Paging (retail BuildPagingConditions / GetClassPagingConditions on the
--  5.4.8 pages: 7-10 stance and form bars, 11 possess, 12 vehicle,
--  13 temporary shapeshift, 14 override)
-------------------------------------------------------------------------------
local function MainBarAuto(bs)
	local parts = { "[overridebar] 14", "[vehicleui] 12", "[shapeshift] 13" }
	return parts
end

function EAB.HasCustomPaging(bs)
	local p = bs and bs.paging
	if not p or next(p) == nil then
		return false
	end
	if bs.modTargetPaging ~= false then
		return true
	end
	for id in pairs(p) do
		if not EAB.MOD_TARGET_PAGING[id] then
			return true
		end
	end
	return false
end

function EAB.BuildPagingConditions(barKey)
	local bs = P.BarSettings(barKey)
	local info = P.BAR_LOOKUP[barKey]
	local defaultPage = info.page or 1
	local cfg = bs and bs.paging or {}
	local isMain = barKey == "MainBar"
	local custom = EAB.HasCustomPaging(bs)
	if not isMain and not custom then
		return nil
	end
	local parts = {}
	if isMain then
		for _, c in ipairs(MainBarAuto(bs)) do
			parts[#parts + 1] = c
		end
	end
	local noModTarget = bs and bs.modTargetPaging == false
	if not noModTarget then
		for _, st in ipairs(EAB.PAGING_STATES.modifier) do
			if cfg[st.id] then
				parts[#parts + 1] = st.macro .. " " .. cfg[st.id]
			end
		end
	end
	local _, class = UnitClass("player")
	local classStates = EAB.PAGING_STATES.class[class]
	if classStates then
		for _, st in ipairs(classStates) do
			if cfg[st.id] then
				parts[#parts + 1] = st.macro .. " " .. cfg[st.id]
			end
		end
	end
	if isMain then
		for i = 2, EAB.NUM_PAGES do
			parts[#parts + 1] = "[bar:" .. i .. "] " .. i
		end
		-- 5.4.8 pages bar 1 by the stance / form offset for every class
		-- (6 + offset); the possess bar is bonus bar 5.
		if not (bs and bs.disableFormPaging) then
			parts[#parts + 1] = "[bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10"
		end
		parts[#parts + 1] = "[bonusbar:5] 11"
	end
	if not noModTarget then
		for _, st in ipairs(EAB.PAGING_STATES.target) do
			if cfg[st.id] then
				parts[#parts + 1] = st.macro .. " " .. cfg[st.id]
			end
		end
	end
	parts[#parts + 1] = tostring(defaultPage)
	return table.concat(parts, "; ")
end

local PAGE_SNIPPET = [[
	local page = tonumber(newstate) or 1
	self:SetAttribute("actionpage", page)
	control:ChildUpdate("eab-page", page)
]]

function P.ApplyPaging(key)
	local info = P.BAR_LOOKUP[key]
	local frame = barFrames[key]
	if not frame or not info.page then
		return
	end
	if InCombatLockdown() then
		P.AfterCombat("paging" .. key, function() P.ApplyPaging(key) end)
		return
	end
	local cond = EAB.BuildPagingConditions(key)
	if frame.eabPageCond == cond then
		return
	end
	frame.eabPageCond = cond
	if cond then
		RegisterStateDriver(frame, "page", cond)
	else
		UnregisterStateDriver(frame, "page")
		frame:Execute(format([[ control:ChildUpdate("eab-page", %d) ]], info.page))
	end
end
EAB.RebuildBarPaging = function(_, key) P.ApplyPaging(key) end

-------------------------------------------------------------------------------
--  Visibility drivers (retail BuildVisibilityString)
-------------------------------------------------------------------------------
P.visToggled = {}
P.dragOverride = false
P.spellbookOpen = false

local function VisAxisMacro(axis, want)
	if want then
		return axis.on
	end
	return axis.off
end

-- The Show / Hide lanes of a bar as macro terms.
local function LaneTerms(s)
	local hideGates, shows, luaShowFail = {}, {}, false
	local anyShowLane = false
	for _, axis in ipairs(EAB.VIS_AXES) do
		local hideOn = EAB.VisFlag(s, axis.hide)
		local showOn = EAB.VisFlag(s, axis.show)
		if axis.lua then
			local now = axis.lua()
			if hideOn and now then
				hideGates[#hideGates + 1] = "[]"
			end
			if showOn then
				anyShowLane = true
				shows[#shows + 1] = { lua = true, ok = now }
			end
		else
			if hideOn then
				hideGates[#hideGates + 1] = "[" .. axis.on .. "]"
			end
			if showOn then
				anyShowLane = true
				shows[#shows + 1] = { macro = axis.on }
			end
		end
	end
	return hideGates, shows, anyShowLane
end

local function BuildVisibilityString(info, s)
	local key = info.key
	local base = EAB.VisBase(s)
	if P.visToggled[key] then
		base = (base == "never") and "always" or (base == "always" and "never" or base)
	end
	if info.isStance and (GetNumShapeshiftForms() or 0) == 0 then
		return "hide"
	end

	local prefix
	if key == "MainBar" then
		prefix = "[petbattle] hide; "
	elseif info.isStance then
		prefix = "[vehicleui][petbattle] hide; "
	elseif info.isPetBar then
		prefix = "[petbattle][vehicleui][overridebar][possessbar][nopet] hide; "
	else
		prefix = "[vehicleui][petbattle][overridebar] hide; "
	end

	-- Quick Keybind Mode brings up every bar that is not set to Never.
	if P.qkOpen and base ~= "never" then
		return prefix .. "show"
	end
	if base == "never" then
		local sb = s.spellbookShow and P.spellbookOpen
		local drag = s.dragShow and P.gridShown
		if sb or drag then
			return prefix .. "show"
		end
		return prefix .. "hide"
	end

	local hideGates, shows = LaneTerms(s)
	local str = prefix
	for _, g in ipairs(hideGates) do
		str = str .. g .. " hide; "
	end
	if #shows == 0 then
		return str .. "show"
	end
	if s.visibilityMatch == "any" then
		for _, sh in ipairs(shows) do
			if sh.lua then
				if sh.ok then
					return str .. "show"
				end
			else
				str = str .. "[" .. sh.macro .. "] show; "
			end
		end
		return str .. "hide"
	end
	local terms = {}
	for _, sh in ipairs(shows) do
		if sh.lua then
			if not sh.ok then
				return str .. "hide"
			end
		else
			terms[#terms + 1] = sh.macro
		end
	end
	if #terms == 0 then
		return str .. "show"
	end
	return str .. "[" .. table.concat(terms, ",") .. "] show; hide"
end
EAB.BuildVisibilityString = BuildVisibilityString

function P.ApplyVisibility(key)
	local info = P.BAR_LOOKUP[key]
	local frame = barFrames[key]
	local s = P.BarSettings(key)
	if not frame or not s or info.visibilityOnly then
		return
	end
	if InCombatLockdown() then
		P.AfterCombat("vis" .. key, function() P.ApplyVisibility(key) end)
		return
	end
	local str = BuildVisibilityString(info, s)
	if s.enabled == false then
		str = "hide"
	end
	if frame.eabVisStr ~= str then
		frame.eabVisStr = str
		RegisterStateDriver(frame, "visibility", str)
	end
end

function P.ApplyAllVisibility()
	for _, info in ipairs(P.BAR_CONFIG) do
		P.ApplyVisibility(info.key)
	end
	if P.ApplyExtraVisibility then
		P.ApplyExtraVisibility()
	end
end

-- Lua-only lanes (Instances, Resting) follow their events.
do
	local f = CreateFrame("Frame")
	f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	f:RegisterEvent("PLAYER_UPDATE_RESTING")
	f:RegisterEvent("PLAYER_ENTERING_WORLD")
	f:SetScript("OnEvent", function()
		if P.Profile() then
			P.ApplyAllVisibility()
		end
	end)
end

-------------------------------------------------------------------------------
--  Bar Opacity and the mouseover fade (retail EAB_VTABLE.Hover)
-------------------------------------------------------------------------------
-- Bars the Visibility checklist hides in Lua (the Extra Action Button only
-- fades: its button is protected).
P.extraBlocked = {}

local function RestingAlpha(s, key)
	if key and P.extraBlocked[key] then
		return 0, false
	end
	if s.mouseoverEnabled or EAB.VisBase(s) == "mouseover" then
		return 0, true
	end
	return s._savedBarAlpha or s.mouseoverAlpha or 1, false
end
P.RestingAlpha = RestingAlpha

local function HoverAlpha(s)
	return s._savedBarAlpha or 1
end

local function Revealed(key, s)
	-- Spellbook open, a drag in progress, Quick Keybind Mode: mouseover bars show.
	if P.qkOpen then
		return true
	end
	if s.spellbookShow and P.spellbookOpen then
		return true
	end
	if P.gridShown and P.BAR_LOOKUP[key] and not P.BAR_LOOKUP[key].visibilityOnly then
		return true
	end
	return false
end

local function AnyHovered()
	for k, st in pairs(hoverStates) do
		local s = P.BarSettings(k)
		if st.isHovered and s and s.mouseoverEnabled then
			return true
		end
	end
	return false
end

local function FadeInOne(key)
	local st = hoverStates[key]
	local s = P.BarSettings(key)
	if not st or not s or not s.mouseoverEnabled then
		return
	end
	if st.fadeDir ~= "in" then
		st.fadeDir = "in"
		P.FadeTo(st.frame, HoverAlpha(s), s.mouseoverSpeed or 0.15)
	end
end

local function FadeOutOne(key)
	local st = hoverStates[key]
	local s = P.BarSettings(key)
	if not st or not s or not s.mouseoverEnabled then
		return
	end
	if Revealed(key, s) then
		return
	end
	if st.fadeDir ~= "out" then
		st.fadeDir = "out"
		P.FadeTo(st.frame, (RestingAlpha(s, key)), s.mouseoverSpeed or 0.15)
	end
end

local function OnHoverEnter(key)
	local st = hoverStates[key]
	if not st then
		return
	end
	st.isHovered = true
	FadeInOne(key)
	local s = P.BarSettings(key)
	if s and s.mouseoverEnabled and P.Profile().mouseoverShowAll then
		for other in pairs(hoverStates) do
			if other ~= key then
				FadeInOne(other)
			end
		end
	end
end

local function OnHoverLeave(key)
	local st = hoverStates[key]
	if not st then
		return
	end
	st.isHovered = false
	if st.pending then
		return
	end
	st.pending = true
	P.After(0.1, function()
		st.pending = nil
		if st.isHovered then
			return
		end
		if st.frame:IsMouseOver() then
			st.isHovered = true
			return
		end
		if SpellFlyout and SpellFlyout:IsShown() and SpellFlyout:IsMouseOver() then
			return
		end
		if P.Profile().mouseoverShowAll and AnyHovered() then
			return
		end
		FadeOutOne(key)
		if P.Profile().mouseoverShowAll then
			for other, ost in pairs(hoverStates) do
				if other ~= key and not ost.isHovered then
					FadeOutOne(other)
				end
			end
		end
	end)
end

-- Hover hooks on a fade target and its buttons (once per frame).
function P.AttachHover(key, frame, buttons)
	local st = hoverStates[key]
	if not st then
		st = { frame = frame, isHovered = false }
		hoverStates[key] = st
	else
		st.frame = frame
	end
	if not frame.eabHoverHooked then
		frame.eabHoverHooked = true
		frame:HookScript("OnEnter", function() OnHoverEnter(key) end)
		frame:HookScript("OnLeave", function() OnHoverLeave(key) end)
	end
	for _, b in ipairs(buttons or {}) do
		if not b.eabHoverHooked then
			b.eabHoverHooked = true
			b:HookScript("OnEnter", function() OnHoverEnter(key) end)
			b:HookScript("OnLeave", function() OnHoverLeave(key) end)
		end
	end
end

-- Click Through bars do not get mouse events: poll the cursor for them.
local pollFrame = CreateFrame("Frame")
local pollElapsed = 0
pollFrame:Hide()
pollFrame:SetScript("OnUpdate", function(self, elapsed)
	pollElapsed = pollElapsed + elapsed
	if pollElapsed < 0.1 then
		return
	end
	pollElapsed = 0
	local any = false
	for key, st in pairs(hoverStates) do
		local s = P.BarSettings(key)
		if s and s.mouseoverEnabled and s.clickThrough and st.frame:IsVisible() then
			any = true
			local over = st.frame:IsMouseOver()
			if over and not st.isHovered then
				OnHoverEnter(key)
			elseif not over and st.isHovered then
				OnHoverLeave(key)
			end
		end
	end
	if not any then
		self:Hide()
	end
end)

-- Paints every bar's resting alpha (retail RefreshMouseover).
function EAB:RefreshMouseover()
	local needPoll = false
	for key, st in pairs(hoverStates) do
		local s = P.BarSettings(key)
		if s then
			if s.mouseoverEnabled then
				if s.clickThrough then
					needPoll = true
				end
				if P.extraBlocked[key] then
					P.StopFade(st.frame, 0)
					st.fadeDir = "out"
				elseif Revealed(key, s) then
					st.fadeDir = "in"
					P.FadeTo(st.frame, HoverAlpha(s), s.mouseoverSpeed or 0.15)
				elseif not st.isHovered then
					local resting = RestingAlpha(s, key)
					P.StopFade(st.frame, resting)
					st.fadeDir = (resting == 0) and "out" or nil
				end
			else
				P.StopFade(st.frame, (RestingAlpha(s, key)))
				st.fadeDir = nil
			end
		end
	end
	if needPoll then
		pollFrame:Show()
	end
end

-- A drag started / ended: empty slots show, mouseover bars come up, Never
-- bars with Show During Drag appear (out of combat).
function P.OnGridChanged(shown)
	EAB:RefreshMouseover()
	if not InCombatLockdown() then
		for _, info in ipairs(P.BAR_CONFIG) do
			local s = P.BarSettings(info.key)
			if s and s.dragShow then
				P.ApplyVisibility(info.key)
			end
		end
	end
end

-- Spellbook / macro window open (retail _UpdateSpellbookNeverBars).
local function SpellbookChanged()
	local open = (SpellBookFrame and SpellBookFrame:IsShown()) or (MacroFrame and MacroFrame:IsShown()) or false
	if open == P.spellbookOpen then
		return
	end
	P.spellbookOpen = open
	EAB:RefreshMouseover()
	for _, info in ipairs(P.BAR_CONFIG) do
		local s = P.BarSettings(info.key)
		if s and s.spellbookShow then
			P.ApplyVisibility(info.key)
		end
	end
end

local function HookSpellbookFrames()
	if SpellBookFrame and not SpellBookFrame.eabHooked then
		SpellBookFrame.eabHooked = true
		SpellBookFrame:HookScript("OnShow", SpellbookChanged)
		SpellBookFrame:HookScript("OnHide", SpellbookChanged)
	end
	if MacroFrame and not MacroFrame.eabHooked then
		MacroFrame.eabHooked = true
		MacroFrame:HookScript("OnShow", SpellbookChanged)
		MacroFrame:HookScript("OnHide", SpellbookChanged)
	end
end

-------------------------------------------------------------------------------
--  Bar frames and their buttons
-------------------------------------------------------------------------------
local function CreateBar(info)
	local frame = CreateFrame("Frame", "EABBar_" .. info.key, UIParent, "SecureHandlerStateTemplate")
	frame:SetFrameStrata("MEDIUM")
	frame:SetSize(36, 36)
	frame.eabKey = info.key
	frame:SetAttribute("_onstate-page", PAGE_SNIPPET)
	if info.page then
		frame:SetAttribute("actionpage", info.page)
	end
	barFrames[info.key] = frame

	-- Bar Background (retail ApplyBackgroundForBar).
	frame.bgFill = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
	frame.bgFill:Hide()
	local bgHost = CreateFrame("Frame", nil, frame)
	bgHost:SetFrameLevel(max(0, frame:GetFrameLevel()))
	frame.bgHost = bgHost
	frame.bgEdges = P.CreateEdges(bgHost, bgHost, "BORDER", 0)
	P.ShowEdges(frame.bgEdges, false)

	local buttons = {}
	for i = 1, info.count do
		local btn
		if info.isStance then
			btn = P.CreateStanceButton(info, i, frame)
		elseif info.isPetBar then
			btn = P.CreatePetButton(info, i, frame)
		else
			btn = P.CreateActionButton(info, i, frame)
		end
		buttons[i] = btn
	end
	P.barButtons[info.key] = buttons
	P.AttachHover(info.key, frame, buttons)
	return frame
end

-- Retail ns.GetOrderFlips: icon order -> column / row flips.
local function OrderFlips(s, isVertical, rowsUpward)
	local order = s.iconOrder
	if order == nil then
		order = s.reverseIconOrder and "reversed" or "default"
	end
	local flowFlip, hA, vA = false, nil, nil
	if order == "reversed" then
		flowFlip = true
	elseif order == "TOPLEFT" then hA, vA = "LEFT", "TOP"
	elseif order == "TOPRIGHT" then hA, vA = "RIGHT", "TOP"
	elseif order == "BOTTOMLEFT" then hA, vA = "LEFT", "BOTTOM"
	elseif order == "BOTTOMRIGHT" then hA, vA = "RIGHT", "BOTTOM"
	end
	local colFlip, rowFlip = false, false
	if isVertical then
		rowFlip = flowFlip or (vA == "BOTTOM")
		colFlip = (hA == "RIGHT")
	else
		colFlip = flowFlip or (hA == "RIGHT")
		if vA then
			rowFlip = ((vA == "TOP") == rowsUpward)
		end
	end
	return colFlip, rowFlip, (hA ~= nil)
end

function EAB:GetNumIcons(key)
	local info = P.BAR_LOOKUP[key]
	local s = P.BarSettings(key)
	local n = s.overrideNumIcons or s.numIcons or info.count
	if n < 1 or n > info.count then
		n = info.count
	end
	if info.isStance then
		n = min(n, GetNumShapeshiftForms() or info.count)
	end
	if n < 1 then
		n = 1
	end
	return n
end

-- Base (unset) button size: 45 for action bars, 30 for stance / pet (retail).
function EAB:BaseButtonSize(key)
	local info = P.BAR_LOOKUP[key]
	if info and (info.isStance or info.isPetBar) then
		return 30
	end
	return 45
end

function EAB:ButtonSize(key)
	local s = P.BarSettings(key)
	local base = self:BaseButtonSize(key)
	local w = (s.buttonWidth and s.buttonWidth > 0) and s.buttonWidth or base
	local h = (s.buttonHeight and s.buttonHeight > 0) and s.buttonHeight or base
	return w, h
end

-- The grid layout (retail LayoutBar).
-- The grid math (retail ComputeBarLayout): every shown button's anchor
-- ("TOPLEFT" / "BOTTOMLEFT" of the bar), offset and size, and the bar size.
-- onePx: one physical pixel in the bar's units. Shared with the settings
-- preview, which draws the same grid.
function EAB:ComputeLayout(key, onePx)
	local info = P.BAR_LOOKUP[key]
	local s = P.BarSettings(key)
	onePx = onePx or 1
	local numIcons = self:GetNumIcons(key)
	local numRows = s.overrideNumRows or s.numRows or 1
	if numRows < 1 then numRows = 1 end
	local stride = ceil(numIcons / numRows)
	if stride < 1 then stride = 1 end
	numRows = ceil(numIcons / stride)

	local btnW, btnH = self:ButtonSize(key)
	if s.buttonShape == "cropped" then
		btnH = btnH * 0.80
	end
	local padding = s.buttonPadding or 2
	btnW = floor(btnW / onePx + 0.5) * onePx
	btnH = floor(btnH / onePx + 0.5) * onePx
	padding = floor(padding / onePx + 0.5) * onePx
	local stepW, stepH = btnW + padding, btnH + padding
	local extraW = s._matchExtraPixels or 0
	local extraH = s._matchExtraPixelsH or 0

	local isVertical = s.orientation == "vertical"
	local growDir = (s.growDirection or "up"):upper()
	local rowsUpward = not isVertical and (growDir == "UP" or growDir == "CENTER")
	local colFlip, rowFlip, cornerFill = OrderFlips(s, isVertical, rowsUpward)

	local out = {}
	for i = 1, numIcons do
		local col, row
		if isVertical then
			if cornerFill then
				col = (i - 1) % numRows
				row = floor((i - 1) / numRows)
			else
				col = floor((i - 1) / stride)
				row = (i - 1) % stride
			end
		else
			col = (i - 1) % stride
			row = floor((i - 1) / stride)
		end
		if colFlip then col = (isVertical and numRows or stride) - 1 - col end
		if rowFlip then row = (isVertical and stride or numRows) - 1 - row end
		local e = {}
		e.w = (extraW > 0 and col < extraW) and (btnW + onePx) or btnW
		e.h = (extraH > 0 and row < extraH) and (btnH + onePx) or btnH
		e.x = col * stepW + min(col, extraW) * onePx
		if rowsUpward then
			e.y = row * stepH + min(row, extraH) * onePx
			e.anchor = "BOTTOMLEFT"
		else
			e.y = -(row * stepH + min(row, extraH) * onePx)
			e.anchor = "TOPLEFT"
		end
		out[i] = e
	end
	local totalCols = isVertical and numRows or stride
	local totalRows = isVertical and stride or numRows
	local frameW = totalCols * btnW + (totalCols - 1) * padding + extraW * onePx
	local frameH = totalRows * btnH + (totalRows - 1) * padding + extraH * onePx
	return out, max(frameW, 1), max(frameH, 1), numIcons, isVertical
end

-- The grid layout (retail LayoutBar).
function P.LayoutBar(key)
	local info = P.BAR_LOOKUP[key]
	local frame = barFrames[key]
	local buttons = P.barButtons[key]
	local s = P.BarSettings(key)
	if not frame or not buttons or not s then
		return
	end
	if InCombatLockdown() then
		P.AfterCombat("layout" .. key, function() P.LayoutBar(key) end)
		return
	end

	local layout, frameW, frameH, numIcons, isVertical = EAB:ComputeLayout(key, P.PixelFor(frame))
	for i = 1, info.count do
		local btn = buttons[i]
		local e = layout[i]
		if not e then
			btn.eabOutsideCount = true
			btn:Hide()
		else
			btn.eabOutsideCount = nil
			btn:Show()
			btn:ClearAllPoints()
			btn:SetPoint(e.anchor, frame, e.anchor, e.x, e.y)
			btn:SetSize(e.w, e.h)
			if btn.autoCastable then
				btn.autoCastable:SetSize(e.w * 1.93, e.h * 1.93)
			end
		end
	end
	frame:SetSize(frameW, frameH)
	P.PlaceFrame(frame, key)

	-- Flyout direction from the screen thirds (retail).
	local flyDir
	local cx, cy = frame:GetCenter()
	if cx and cy then
		local r = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
		cx, cy = cx * r, cy * r
		local uw, uh = UIParent:GetWidth(), UIParent:GetHeight()
		if isVertical then
			flyDir = (cx > uw * 2 / 3) and "LEFT" or "RIGHT"
		else
			flyDir = (cy > uh * 2 / 3) and "DOWN" or "UP"
		end
	else
		flyDir = isVertical and "RIGHT" or "UP"
	end
	for _, btn in ipairs(buttons) do
		btn:SetAttribute("flyoutDirection", flyDir)
	end

	-- Click Through (retail ApplyClickThroughForBar).
	local clickable = not s.clickThrough
	for _, btn in ipairs(buttons) do
		btn:EnableMouse(clickable)
	end
	frame:EnableMouse(clickable and s.mouseoverEnabled and true or false)

	P.ApplyBackground(key)
	if key == "MainBar" and P.LayoutPagingArrows then
		P.LayoutPagingArrows()
	end
end

-- Bar Background (retail ApplyBackgroundForBar).
function P.ApplyBackground(key)
	local frame = barFrames[key]
	local s = P.BarSettings(key)
	if not frame or not s then
		return
	end
	if not s.bgEnabled then
		frame.bgFill:Hide()
		P.ShowEdges(frame.bgEdges, false)
		return
	end
	local c = s.bgColor or { r = 0, g = 0, b = 0, a = 0.5 }
	local alpha = s.bgOpacity ~= nil and s.bgOpacity / 100 or (c.a or 0.5)
	frame.bgFill:SetTexture(c.r or 0, c.g or 0, c.b or 0, alpha)
	local pad = s.bgPadding
	local padX = pad ~= nil and pad or (s.bgPadX or 0)
	local padY = pad ~= nil and pad or (s.bgPadY or 0)
	local mx = max(1, min(4, floor((s.bgMultiplierX or 1) + 0.5)))
	local my = max(1, min(4, floor((s.bgMultiplierY or 1) + 0.5)))
	local iconPad = s.buttonPadding or 0
	local growX = (mx - 1) * ((frame:GetWidth() or 0) + iconPad)
	local growY = (my - 1) * ((frame:GetHeight() or 0) + iconPad)
	local left, right, top, bottom = -padX, padX, padY, -padY
	if (s.bgExpandDirectionX or "right") == "left" then left = left - growX else right = right + growX end
	if (s.bgExpandDirectionY or "up") == "down" then bottom = bottom - growY else top = top + growY end
	frame.bgFill:ClearAllPoints()
	frame.bgFill:SetPoint("TOPLEFT", frame, "TOPLEFT", left, top)
	frame.bgFill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", right, bottom)
	frame.bgFill:Show()
	local host = frame.bgHost
	host:ClearAllPoints()
	host:SetPoint("TOPLEFT", frame, "TOPLEFT", left, top)
	host:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", right, bottom)
	host:SetFrameLevel(s.bgBorderBehind and max(0, frame:GetFrameLevel() - 1) or frame:GetFrameLevel())
	local entry = EAB.BORDER_THICKNESS[s.bgBorderThickness or "none"]
	local size = (entry and entry.regular or 0) * P.PixelFor(frame)
	local bc = s.bgBorderColor or { r = 0, g = 0, b = 0, a = 1 }
	P.LayoutEdges(frame.bgEdges, size, bc.r or 0, bc.g or 0, bc.b or 0, bc.a or 1)
	P.ShowEdges(frame.bgEdges, size > 0)
end

-------------------------------------------------------------------------------
--  Orientation helpers for the settings (retail EAB methods)
-------------------------------------------------------------------------------
function EAB:BarSupportsOrientation(key)
	local info = P.BAR_LOOKUP[key]
	return info and info.count ~= nil or false
end

function EAB:GetOrientationForBar(key)
	local s = P.BarSettings(key)
	return not s or s.orientation ~= "vertical"
end

function EAB:SetOrientationForBar(key, isHorizontal)
	local s = P.BarSettings(key)
	if not s then
		return
	end
	s.orientation = isHorizontal and "horizontal" or "vertical"
	local g = (s.growDirection or "up"):upper()
	if isHorizontal then
		if g == "UP" or g == "DOWN" then s.growDirection = "center" end
	else
		if g == "LEFT" or g == "RIGHT" then s.growDirection = "up" end
	end
end

-------------------------------------------------------------------------------
--  Action Bar 1 paging arrows (retail SetupPagingFrame: secure /changeactionbar
--  macros, the page number between them)
-------------------------------------------------------------------------------
local pagingFrame
local function PageMacro(delta)
	local parts = {}
	for i = 1, EAB.NUM_PAGES do
		local target = ((i - 1 + delta) % EAB.NUM_PAGES) + 1
		parts[#parts + 1] = "[bar:" .. i .. "] " .. target
	end
	return "/changeactionbar " .. table.concat(parts, "; ")
end

local function SetupPagingFrame()
	if pagingFrame then
		return
	end
	pagingFrame = CreateFrame("Frame", "EABPagingFrame", barFrames.MainBar)
	pagingFrame:SetSize(18, 50)
	local function Arrow(delta, tex)
		local b = CreateFrame("Button", nil, pagingFrame, "SecureActionButtonTemplate")
		b:SetSize(18, 18)
		b:SetAttribute("type", "macro")
		b:SetAttribute("macrotext", PageMacro(delta))
		b:RegisterForClicks("AnyUp")
		b:SetNormalTexture("Interface\\MainMenuBar\\UI-MainMenu-Scroll" .. tex .. "Button-Up")
		b:SetPushedTexture("Interface\\MainMenuBar\\UI-MainMenu-Scroll" .. tex .. "Button-Down")
		b:SetHighlightTexture("Interface\\MainMenuBar\\UI-MainMenu-Scroll" .. tex .. "Button-Highlight", "ADD")
		return b
	end
	pagingFrame.up = Arrow(1, "Up")
	pagingFrame.down = Arrow(-1, "Down")
	pagingFrame.text = pagingFrame:CreateFontString(nil, "OVERLAY")
	P.SetIconFont(pagingFrame.text, 12)
	pagingFrame.up:SetPoint("TOP", pagingFrame, "TOP", 0, 0)
	pagingFrame.down:SetPoint("BOTTOM", pagingFrame, "BOTTOM", 0, 0)
	pagingFrame.text:SetPoint("CENTER", pagingFrame, "CENTER", 0, 0)
	pagingFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
	pagingFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	pagingFrame:SetScript("OnEvent", function(self)
		self.text:SetText(GetActionBarPage())
	end)
	pagingFrame.text:SetText(GetActionBarPage() or 1)
end

function P.LayoutPagingArrows()
	local s = P.BarSettings("MainBar")
	if not s or not s.showPagingArrows then
		if pagingFrame then pagingFrame:Hide() end
		return
	end
	if InCombatLockdown() then
		return
	end
	SetupPagingFrame()
	local frame = barFrames.MainBar
	local _, h = EAB:ButtonSize("MainBar")
	pagingFrame:SetHeight(max(h, 36))
	pagingFrame:ClearAllPoints()
	if s.pagingArrowsRight then
		pagingFrame:SetPoint("LEFT", frame, "RIGHT", 4, 0)
	else
		pagingFrame:SetPoint("RIGHT", frame, "LEFT", -4, 0)
	end
	pagingFrame:Show()
end

-------------------------------------------------------------------------------
--  Toggle Action Bar keys (retail toggleVisKey: flips Always / Never at run
--  time, out of combat, without changing the saved setting)
-------------------------------------------------------------------------------
local toggleButtons = {}
function P.UpdateToggleBindings()
	for _, info in ipairs(P.BAR_CONFIG) do
		local s = P.BarSettings(info.key)
		local key = s and s.toggleVisKey
		if key and key ~= "" then
			local b = toggleButtons[info.key]
			if not b then
				b = CreateFrame("Button", "EABToggle_" .. info.key, UIParent)
				b:SetScript("OnClick", function()
					if InCombatLockdown() then
						return
					end
					P.visToggled[info.key] = not P.visToggled[info.key] or nil
					P.ApplyVisibility(info.key)
				end)
				toggleButtons[info.key] = b
			end
			SetOverrideBindingClick(P.bindOwner, true, key, b:GetName())
		end
	end
end

-------------------------------------------------------------------------------
--  Blizzard's bars (ElvUI DisableBlizzard pattern: unregister, hide, re-parent)
-------------------------------------------------------------------------------
local function Kill(frame)
	if type(frame) == "string" then
		frame = _G[frame]
	end
	if not frame then
		return
	end
	frame:UnregisterAllEvents()
	frame:Hide()
	frame:SetParent(hiddenParent)
end

local BLIZZ_BUTTON_PREFIXES = {
	"ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
	"MultiBarRightButton", "MultiBarLeftButton", "MultiCastActionButton",
}

function P.HideBlizzardBars()
	if P.blizzardHidden then
		return
	end
	P.blizzardHidden = true
	local p = P.Profile()

	for _, bar in ipairs({ "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight" }) do
		if _G[bar] then
			_G[bar]:SetParent(hiddenParent)
		end
	end
	for i = 1, 12 do
		for _, prefix in ipairs(BLIZZ_BUTTON_PREFIXES) do
			local b = _G[prefix .. i]
			if b then
				b:Hide()
				b:UnregisterAllEvents()
				b:SetAttribute("statehidden", true)
			end
		end
	end

	-- The vehicle exit button lives in MainMenuBar: keep it on screen.
	local leave = MainMenuBarVehicleLeaveButton
	if leave then
		leave:SetParent(UIParent)
		leave:ClearAllPoints()
		leave:SetPoint("LEFT", barFrames.MainBar, "RIGHT", 6, 0)
		hooksecurefunc(leave, "SetPoint", function(self, _, rel)
			if rel ~= barFrames.MainBar and not self.eabMoving then
				self.eabMoving = true
				self:ClearAllPoints()
				self:SetPoint("LEFT", barFrames.MainBar, "RIGHT", 6, 0)
				self.eabMoving = nil
			end
		end)
	end

	-- Retail "Hide Blizzard's Vehicle Bar" off: Blizzard's vehicle / override
	-- bar still comes up in skinned vehicles (Action Bar 1 pages to the same
	-- abilities). On: only Action Bar 1 shows them.
	ActionBarController:UnregisterAllEvents()
	ActionBarController:RegisterEvent("UPDATE_EXTRA_ACTIONBAR")
	if not p.hideBlizzardVehicleBar then
		ActionBarController:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR")
		ActionBarController:RegisterEvent("UPDATE_OVERRIDE_ACTIONBAR")
		ActionBarController:RegisterEvent("UNIT_DISPLAYPOWER")
	else
		for i = 1, 6 do
			local b = _G["OverrideActionBarButton" .. i]
			if b then
				b:Hide()
				b:UnregisterAllEvents()
				b:SetAttribute("statehidden", true)
			end
		end
		Kill(OverrideActionBar)
	end

	MainMenuBar:EnableMouse(false)
	MainMenuBar:SetAlpha(0)
	if MainMenuBarArtFrame then
		MainMenuBarArtFrame:UnregisterEvent("ACTIONBAR_PAGE_CHANGED")
		MainMenuBarArtFrame:UnregisterEvent("ADDON_LOADED")
		MainMenuBarArtFrame:Hide()
		MainMenuBarArtFrame:SetParent(hiddenParent)
	end
	Kill(StanceBarFrame)
	Kill(PossessBarFrame)
	Kill(PetActionBarFrame)
	Kill(MultiCastActionBarFrame)
	if MainMenuBarPerformanceBar then
		MainMenuBarPerformanceBar:SetParent(hiddenParent)
	end

	-- Experience and reputation: ours, unless Use Blizzard's Rep Bars.
	if not p.useBlizzardDataBars then
		Kill(MainMenuExpBar)
		Kill(MainMenuBarMaxLevelBar)
		Kill(ReputationWatchBar)
	else
		for _, name in ipairs({ "MainMenuExpBar", "ReputationWatchBar" }) do
			local f = _G[name]
			if f then
				f:SetParent(UIParent)
			end
		end
		if MainMenuBarMaxLevelBar then
			MainMenuBarMaxLevelBar:SetParent(hiddenParent)
		end
	end

	-- PlayerTalentFrame touches the stock bars on a spec change (ElvUI).
	if PlayerTalentFrame then
		PlayerTalentFrame:UnregisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
	elseif TalentFrame_LoadUI then
		hooksecurefunc("TalentFrame_LoadUI", function()
			if PlayerTalentFrame then
				PlayerTalentFrame:UnregisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
			end
		end)
	end
	if UIPARENT_MANAGED_FRAME_POSITIONS then
		UIPARENT_MANAGED_FRAME_POSITIONS.ExtraActionBarFrame = nil
	end
end

-------------------------------------------------------------------------------
--  Micro Menu, Bag Bar and Extra Action Button holders (retail EXTRA_BARS:
--  visibility only; positions in barPositions)
-------------------------------------------------------------------------------
local extraHolders = {}
P.extraHolders = extraHolders

local function MicroButtonList()
	local list = {}
	for _, name in ipairs(MICRO_BUTTONS or {}) do
		local b = _G[name]
		if b then
			list[#list + 1] = b
		end
	end
	return list
end

local function LayoutMicroBar()
	local holder = extraHolders.MicroBar
	if not holder then
		return
	end
	local list = MicroButtonList()
	local x = 0
	local w, h = 28, 58
	for i, b in ipairs(list) do
		if b:IsShown() or i == 1 then
			b:SetParent(holder)
			b:ClearAllPoints()
			b:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", x, 0)
			w, h = b:GetWidth(), b:GetHeight()
			x = x + w - 3
		end
	end
	holder:SetSize(max(x + 3, 1), max((h or 58) - 20, 1))
	P.PlaceFrame(holder, "MicroBar")
end

local BAG_BUTTONS = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot" }

local function LayoutBagBar()
	local holder = extraHolders.BagBar
	if not holder then
		return
	end
	local x = 0
	local h = 30
	for _, name in ipairs(BAG_BUTTONS) do
		local b = _G[name]
		if b then
			b:SetParent(holder)
			b:ClearAllPoints()
			b:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -x, 0)
			x = x + b:GetWidth() + 3
			h = max(h, b:GetHeight())
		end
	end
	holder:SetSize(max(x - 3, 1), h)
	P.PlaceFrame(holder, "BagBar")
end

local function SetupExtraHolders()
	if extraHolders.MicroBar then
		return
	end
	local micro = CreateFrame("Frame", "EABMicroBar", UIParent)
	micro:SetFrameStrata("MEDIUM")
	extraHolders.MicroBar = micro
	LayoutMicroBar()
	P.AttachHover("MicroBar", micro, MicroButtonList())
	if UpdateMicroButtonsParent then
		hooksecurefunc("UpdateMicroButtonsParent", function(parent)
			if parent ~= micro then
				LayoutMicroBar()
			end
		end)
	end
	if MoveMicroButtons then
		hooksecurefunc("MoveMicroButtons", function()
			LayoutMicroBar()
		end)
	end

	local bags = CreateFrame("Frame", "EABBagBar", UIParent)
	bags:SetFrameStrata("MEDIUM")
	extraHolders.BagBar = bags
	LayoutBagBar()
	local bagList = {}
	for _, name in ipairs(BAG_BUTTONS) do
		if _G[name] then bagList[#bagList + 1] = _G[name] end
	end
	P.AttachHover("BagBar", bags, bagList)

	local extra = CreateFrame("Frame", "EABExtraActionHolder", UIParent)
	extra:SetSize(52, 52)
	extraHolders.ExtraActionButton = extra
	if ExtraActionBarFrame then
		ExtraActionBarFrame:SetParent(extra)
		ExtraActionBarFrame:ClearAllPoints()
		ExtraActionBarFrame:SetPoint("CENTER", extra, "CENTER", 0, 0)
	end
	P.PlaceFrame(extra, "ExtraActionButton")
	P.AttachHover("ExtraActionButton", extra, { ExtraActionButton1 })
end

-- Visibility of the visibility-only bars (Lua: not secure frames, except the
-- Extra Action Button which only fades).
function P.ApplyExtraVisibility()
	for _, key in ipairs({ "MicroBar", "BagBar", "ExtraActionButton" }) do
		local holder = extraHolders[key]
		local s = P.BarSettings(key)
		if holder and s then
			local base = EAB.VisBase(s)
			local allow = base ~= "never"
			-- Pet battles hide them (retail extra bar visibility proxy).
			if C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle() then
				allow = false
			end
			if allow then
				for _, axis in ipairs(EAB.VIS_AXES) do
					if EAB.VisFlag(s, axis.hide) and P.LaneNow(axis) then
						allow = false
					end
				end
			end
			if key == "ExtraActionButton" then
				local was = P.extraBlocked[key]
				P.extraBlocked[key] = (not allow) or nil
				if was ~= P.extraBlocked[key] then
					EAB:RefreshMouseover()
				end
			else
				holder:SetShown(allow)
			end
		end
	end
end

-- A lane's state now (Lua side, for the non-secure bars).
local LANE_NOW = {
	in_combat = function() return UnitAffectingCombat("player") end,
	out_of_combat = function() return not UnitAffectingCombat("player") end,
	in_raid = function() return IsInRaid() end,
	in_party = function() return IsInGroup() and not IsInRaid() end,
	solo = function() return not IsInGroup() end,
	mounted = function() return IsMounted() end,
	target = function() return UnitExists("target") end,
	enemy = function() return UnitExists("target") and UnitCanAttack("player", "target") end,
}
function P.LaneNow(axis)
	if axis.lua then
		return axis.lua()
	end
	local fn = LANE_NOW[axis.key]
	return fn and fn() or false
end

-- True when a non-secure bar's checklist allows it now (XP / Rep bars).
function P.VisibilityAllows(s)
	if EAB.VisBase(s) == "never" then
		return false
	end
	local anyShow, allShow, count = false, true, 0
	for _, axis in ipairs(EAB.VIS_AXES) do
		local now = P.LaneNow(axis)
		if EAB.VisFlag(s, axis.hide) and now then
			return false
		end
		if EAB.VisFlag(s, axis.show) then
			count = count + 1
			if now then anyShow = true else allShow = false end
		end
	end
	if count == 0 then
		return true
	end
	if s.visibilityMatch == "any" then
		return anyShow
	end
	return allShow
end

do
	local f = CreateFrame("Frame")
	for _, e in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE", "PLAYER_TARGET_CHANGED",
		"UNIT_AURA", "COMPANION_UPDATE", "ZONE_CHANGED_NEW_AREA", "PLAYER_UPDATE_RESTING",
		"PET_BATTLE_OPENING_START", "PET_BATTLE_CLOSE" }) do
		f:RegisterEvent(e)
	end
	f:SetScript("OnEvent", function(_, event, unit)
		if event == "UNIT_AURA" and unit ~= "player" then
			return
		end
		if P.Profile() then
			P.ApplyExtraVisibility()
			if P.UpdateDataBars then P.UpdateDataBars() end
		end
	end)
end

-------------------------------------------------------------------------------
--  Unlock Mode elements (EllesmereUI core Unlock Mode, retail
--  EllesmereUIActionBars RegisterUnlockElements). Positions: P.SavePosition
--  format (the grow point's offset from the screen center).
-------------------------------------------------------------------------------
-- Retail Lite addon lookup used by the core (grow direction / orientation).
function EAB:SetGrowDirectionForBar(key, dir)
	local s = P.BarSettings(key)
	if not s then
		return
	end
	s.growDirection = (dir or "up"):lower()
	P.LayoutBar(key)
end
ns._liteAddons = ns._liteAddons or {}
ns._liteAddons["EllesmereUIActionBars"] = EAB

-- Square button size from a whole bar size along one axis (retail setWidth /
-- setHeight): leftover physical pixels go to the first columns / rows.
local function SizeFromBar(key, total, axis)
	local s = P.BarSettings(key)
	local info = P.BAR_LOOKUP[key]
	if not s or not info or not total then
		return
	end
	local numIcons = EAB:GetNumIcons(key)
	local numRows = s.overrideNumRows or s.numRows or 1
	if numRows < 1 then numRows = 1 end
	local stride = ceil(numIcons / numRows)
	if stride < 1 then stride = 1 end
	numRows = ceil(numIcons / stride)
	local isVert = s.orientation == "vertical"
	local count
	if axis == "w" then
		count = isVert and numRows or stride
	else
		count = isVert and stride or numRows
	end
	local PP = ns.PP
	local onePx = PP and PP.mult or 1
	local physTarget = floor(total / onePx + 0.5)
	local physPad = floor((s.buttonPadding or 2) / onePx + 0.5)
	local raw = (physTarget - (count - 1) * physPad) / count
	if axis == "h" and s.buttonShape == "cropped" then
		raw = raw / 0.80
	end
	if raw < 8 then raw = 8 end
	local base = floor(raw)
	s.buttonWidth = base * onePx
	s.buttonHeight = s.buttonWidth
	local each = (axis == "h" and s.buttonShape == "cropped") and floor(base * 0.80) or base
	local extra = physTarget - (count * each + (count - 1) * physPad)
	local field = axis == "w" and "_matchExtraPixels" or "_matchExtraPixelsH"
	if extra > 0 and extra <= count then
		s[field] = extra
	else
		s[field] = nil
	end
	P.LayoutBar(key)
end

local POINT_X = { LEFT = -0.5, RIGHT = 0.5, TOPLEFT = -0.5, TOPRIGHT = 0.5, BOTTOMLEFT = -0.5, BOTTOMRIGHT = 0.5 }
local POINT_Y = { TOP = 0.5, BOTTOM = -0.5, TOPLEFT = 0.5, TOPRIGHT = 0.5, BOTTOMLEFT = -0.5, BOTTOMRIGHT = -0.5 }

local function GetFrame(key)
	if barFrames[key] then
		return barFrames[key]
	end
	if extraHolders[key] then
		return extraHolders[key]
	end
	return P.dataBarFrames and P.dataBarFrames[key]
end

local function MakeElement(info, order)
	local key = info.key
	local isButtonBar = info.count ~= nil
	return ns.MakeUnlockElement({
		key = key,
		label = info.label,
		group = "Action Bars",
		order = 200 + order,
		noResize = not (isButtonBar or info.isDataBar) or nil,
		getFrame = function() return GetFrame(key) end,
		isHidden = function()
			local s = P.BarSettings(key)
			return not P.started or not s or not GetFrame(key) or EAB.VisBase(s) == "never"
		end,
		getSize = function()
			local f = GetFrame(key)
			if f then
				return f:GetWidth(), f:GetHeight()
			end
			return 100, 30
		end,
		setWidth = isButtonBar and function(_, w) SizeFromBar(key, w, "w") end
			or (info.isDataBar and function(_, w)
				local s = P.BarSettings(key)
				if s then s.width = max(floor(w + 0.5), 20) end
				if P.ApplyDataBars then P.ApplyDataBars() end
			end) or nil,
		setHeight = isButtonBar and function(_, h) SizeFromBar(key, h, "h") end
			or (info.isDataBar and function(_, h)
				local s = P.BarSettings(key)
				if s then s.height = max(floor(h + 0.5), 2) end
				if P.ApplyDataBars then P.ApplyDataBars() end
			end) or nil,
		-- Stored as the grow point's offset (the bar keeps that edge when it
		-- changes size); the core hands CENTER offsets in UIParent units.
		savePos = function(_, point, relPoint, x, y)
			local f = GetFrame(key)
			local p = P.Profile()
			if not p then return end
			if f and point == "CENTER" and relPoint == "CENTER" then
				local s = P.BarSettings(key)
				local gp = "CENTER"
				if isButtonBar and s then
					gp = GrowPoint(s, s.orientation == "vertical")
				end
				local scale = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
				x = x + (POINT_X[gp] or 0) * f:GetWidth() * scale
				y = y + (POINT_Y[gp] or 0) * f:GetHeight() * scale
				point = gp
			end
			p.barPositions[key] = { point = point, relPoint = relPoint or "CENTER", x = x, y = y }
			if not ns._unlockActive and f and not InCombatLockdown() then
				P.PlaceFrame(f, key)
			end
		end,
		loadPos = function()
			local p = P.Profile()
			local pos = p and p.barPositions[key]
			if not pos or not pos.point then
				return nil
			end
			return { point = pos.point, relPoint = pos.relPoint or pos.point, x = pos.x, y = pos.y }
		end,
		clearPos = function()
			local p = P.Profile()
			if p then p.barPositions[key] = nil end
		end,
		applyPos = function()
			local f = GetFrame(key)
			if f and not InCombatLockdown() then
				P.PlaceFrame(f, key)
			end
		end,
	})
end

local function RegisterUnlock()
	if not ns.RegisterUnlockElements then
		return
	end
	local elements = {}
	for i, info in ipairs(P.ALL_BARS) do
		elements[#elements + 1] = MakeElement(info, i)
	end
	ns:RegisterUnlockElements(elements, "EllesmereUIActionBars")
	-- After Unlock Mode the bars sit on their saved grow points again (a drag
	-- leaves them on a corner point).
	ns:RegisterUnlockModeListener("EllesmereUIActionBars", function(on)
		if not on and P.started then
			EAB:ApplyAll()
		end
	end)
end

-------------------------------------------------------------------------------
--  Apply (every settings change: ns.applyHooks)
-------------------------------------------------------------------------------
function EAB:ApplyBar(key)
	local info = P.BAR_LOOKUP[key]
	local s = P.BarSettings(key)
	local buttons = P.barButtons[key]
	if not info or not s or not buttons then
		return
	end
	EAB.VisibilityCompat.Normalize(s)
	P.LayoutBar(key)
	for _, btn in ipairs(buttons) do
		P.ApplyButtonArt(btn, s, info)
		if btn.kind == "action" then
			P.UpdateActionButton(btn)
		end
	end
	P.ApplyPaging(key)
	P.ApplyVisibility(key)
end

function EAB:ApplyAll()
	if not self.db or not P.started then
		return
	end
	if InCombatLockdown() then
		-- Look only now; protected work (layout, drivers) after combat.
		for _, info in ipairs(P.BAR_CONFIG) do
			local s = P.BarSettings(info.key)
			for _, btn in ipairs(P.barButtons[info.key] or {}) do
				P.ApplyButtonArt(btn, s, info)
			end
		end
		P.AfterCombat("applyAll", function() EAB:ApplyAll() end)
		return
	end
	for _, info in ipairs(P.BAR_CONFIG) do
		self:ApplyBar(info.key)
	end
	P.UpdateStanceButtons()
	P.UpdatePetButtons()
	P.RefreshCooldownNumbers()
	self:RefreshProcGlows()
	P.UpdateKeybinds()
	P.ApplyClickSettings()
	LayoutMicroBar()
	LayoutBagBar()
	if extraHolders.ExtraActionButton then
		P.PlaceFrame(extraHolders.ExtraActionButton, "ExtraActionButton")
	end
	for _, info in ipairs(P.EXTRA_BARS) do
		local s = P.BarSettings(info.key)
		if s then
			EAB.VisibilityCompat.Normalize(s)
		end
	end
	P.ApplyExtraVisibility()
	if P.ApplyDataBars then
		P.ApplyDataBars()
	end
	self:RefreshMouseover()
end

-------------------------------------------------------------------------------
--  Start
-------------------------------------------------------------------------------
-- ElvUI's own action bars take the same buttons and keys: run one of them.
local function ElvUIBarsActive()
	if not IsAddOnLoaded("ElvUI") then
		return false
	end
	local ok, E = pcall(function() return ElvUI and ElvUI[1] end)
	local private = ok and E and E.private
	if private and private.actionbar then
		return private.actionbar.enable ~= false
	end
	-- ElvUI not set up yet: read its saved per-character profile (the bars
	-- are on unless that profile turned them off).
	local db = ElvUIPrivateDB
	if type(db) ~= "table" then
		return true
	end
	local charKey = (UnitName("player") or "") .. " - " .. (GetRealmName() or "")
	local pkey = db.profileKeys and db.profileKeys[charKey] or charKey
	local prof = db.profiles and db.profiles[pkey]
	if prof and prof.actionbar and prof.actionbar.enable == false then
		return false
	end
	return true
end

local function Start()
	if P.started then
		return
	end
	if ElvUIBarsActive() then
		ns.Print("ElvUI's action bars are on, so EllesmereUI Action Bars stay off. Turn off ElvUI > ActionBars > Enable to use them.")
		P.disabledByElvUI = true
		return
	end
	P.started = true
	for _, info in ipairs(P.BAR_CONFIG) do
		CreateBar(info)
	end
	P.HideBlizzardBars()
	SetupExtraHolders()
	RegisterUnlock()
	P.EnableButtonEvents()
	HookSpellbookFrames()
	EAB:ApplyAll()
end

-- For the settings: running, or kept off because ElvUI's bars are on.
function EAB:IsRunning()
	return P.started and true or false
end

function EAB:IsDisabledByElvUI()
	return P.disabledByElvUI and true or false
end

-- Stance forms appear / disappear (talents, level): relayout the stance bar.
function P.OnStanceFormsChanged()
	if not P.started then
		return
	end
	if InCombatLockdown() then
		P.AfterCombat("stance", P.OnStanceFormsChanged)
		return
	end
	P.LayoutBar("StanceBar")
	P.ApplyVisibility("StanceBar")
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == addonName then
			EAB:InitDB()
			ns.applyHooks = ns.applyHooks or {}
			tinsert(ns.applyHooks, function() EAB:ApplyAll() end)
		elseif arg1 == "Blizzard_MacroUI" then
			HookSpellbookFrames()
		end
	elseif event == "PLAYER_LOGIN" then
		if InCombatLockdown() then
			-- /reload in combat: secure frames wait for the end of combat.
			P.AfterCombat("start", Start)
		else
			Start()
		end
	end
end)
