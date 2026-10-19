-------------------------------------------------------------------------------
--  EUI_Minimap_Buttons.lua  (5.4.8 port of the EllesmereUI Minimap)
--
--  The addon button group (flyout grid behind one toggle button), ungrouped
--  buttons on the button row, Free Move (Shift + drag), the element row
--  (tracking, calendar, mail), the Friends Online button and the custom
--  tooltips (friends, calendar lockouts), and "Mouseover Extra Buttons".
--  Same behavior as retail; the HUD atlases of retail do not exist in 5.4.8,
--  so the indicators use the 5.4.8 minimap art (tracking magnifier, mailbox,
--  calendar page with the day number) in the EllesmereUI black boxes.
-------------------------------------------------------------------------------
local _, P = ...
local ns = P.ns
local EMM = P.EMM

local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min

-- External weak-keyed lookup table for frame state (no keys on Blizzard frames).
local FFD = setmetatable({}, { __mode = "k" })
local function GetFFD(frame)
	local d = FFD[frame]
	if not d then
		d = {}
		FFD[frame] = d
	end
	return d
end
P.GetFFD = GetFFD

local DB = P.DB

-------------------------------------------------------------------------------
--  Shared button state
-------------------------------------------------------------------------------
local cachedAddonButtons = {}
local addonVisible = {}         -- persistent: does the addon WANT its button visible
local suppressVisTrack = false  -- our own Show/Hide calls are not tracked
local flyoutOwnedFrames = {}
P.cachedAddonButtons = cachedAddonButtons
P.addonVisible = addonVisible
P.flyoutOwnedFrames = flyoutOwnedFrames

local flyoutToggle, flyoutPanel
local flyoutSavedParents = {}
local flyoutSavedRegions = {}
P.flyoutSavedRegions = flyoutSavedRegions

local FLYOUT_BTN_SIZE = 24
local FLYOUT_PADDING = 4
local FLYOUT_COLS = 4

-- Mouseover Extra Buttons: set below, fired by the flyout and friends tooltip.
local MO_Evaluate

local function QueueApplyAll()
	if P.QueueApplyAll then
		P.QueueApplyAll()
	end
end

-------------------------------------------------------------------------------
--  Button decorations (ring border and dark disc of the stock minimap buttons)
-------------------------------------------------------------------------------
local JUNK_PATHS = {
	"interface\\minimap\\minimap%-trackingborder",
	"interface\\minimap\\ui%-minimap%-background",
	"interface\\minimap\\ui%-minimap%-zoombutton%-highlight",
}

local function IsJunkTexture(region)
	if type(region) ~= "table" or not region.IsObjectType or not region:IsObjectType("Texture") then
		return false
	end
	local path = region:GetTexture()
	if type(path) == "string" then
		path = path:lower():gsub("/", "\\")
		for _, pattern in ipairs(JUNK_PATHS) do
			if path:match(pattern) then
				return true
			end
		end
	end
	return false
end

local function StripButtonDecorations(btn)
	if not flyoutSavedRegions[btn] then
		local saved = { junk = {} }
		for _, region in ipairs({ btn:GetRegions() }) do
			if IsJunkTexture(region) then
				saved.junk[#saved.junk + 1] = { region = region, alpha = region:GetAlpha(), shown = region:IsShown() }
			end
		end
		local hl = btn.GetHighlightTexture and btn:GetHighlightTexture()
		if hl and IsJunkTexture(hl) then
			saved.junk[#saved.junk + 1] = { region = hl, alpha = hl:GetAlpha(), shown = hl:IsShown() }
		end
		local icon = btn.icon or btn.Icon
		if icon then
			local pts = {}
			for i = 1, icon:GetNumPoints() do
				pts[i] = { icon:GetPoint(i) }
			end
			saved.icon = icon
			saved.iconPoints = pts
			saved.iconTC = { icon:GetTexCoord() }
		end
		saved.btnW, saved.btnH = btn:GetWidth(), btn:GetHeight()
		flyoutSavedRegions[btn] = saved
	end
	for _, info in ipairs(flyoutSavedRegions[btn].junk) do
		info.region:SetAlpha(0)
		info.region:Hide()
	end
end

local function RestoreButtonDecorations(btn)
	local saved = flyoutSavedRegions[btn]
	if not saved then
		return
	end
	for _, info in ipairs(saved.junk) do
		info.region:SetAlpha(info.alpha)
		if info.shown then
			info.region:Show()
		end
	end
	if saved.icon and saved.iconPoints then
		saved.icon:ClearAllPoints()
		for _, pt in ipairs(saved.iconPoints) do
			saved.icon:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5])
		end
		if saved.iconTC and #saved.iconTC >= 8 then
			saved.icon:SetTexCoord(unpack(saved.iconTC))
		end
	end
	if saved.btnW and saved.btnH then
		btn:SetSize(saved.btnW, saved.btnH)
	end
	flyoutSavedRegions[btn] = nil
end

local function IsUngrouped(btn)
	-- A group of one has nothing to open: the only button stands on the row.
	if btn == P.soloAddonButton then
		return true
	end
	local mp = DB()
	if not mp or not mp.ungroupedButtons then
		return false
	end
	local name = btn:GetName()
	return name and mp.ungroupedButtons[name] and true or false
end
P.IsUngrouped = IsUngrouped

local function GetMinimapButtonLabel(btn)
	local name = btn:GetName() or ""
	return (name:gsub("^LibDBIcon10_", ""):gsub("^Lib_GPI_Minimap_", ""):gsub("MinimapButton$", ""):gsub("_MinimapButton$", ""))
end
P.GetMinimapButtonLabel = GetMinimapButtonLabel

local function CollectFlyoutButtons()
	local collected = {}
	for _, btn in ipairs(cachedAddonButtons) do
		if addonVisible[btn] ~= false and not IsUngrouped(btn) then
			collected[#collected + 1] = btn
		end
	end
	table.sort(collected, function(a, b)
		return GetMinimapButtonLabel(a):lower() < GetMinimapButtonLabel(b):lower()
	end)
	return collected
end
P.CollectFlyoutButtons = CollectFlyoutButtons

local function GetAddonBtnSize()
	local mp = DB()
	return mp and mp.addonBtnSize or FLYOUT_BTN_SIZE
end

local function GetInteractableBtnSize()
	local mp = DB()
	return mp and mp.interactableBtnSize or 22
end
P.GetInteractableBtnSize = GetInteractableBtnSize

local function GetCustomTooltipScale()
	local mp = DB()
	return mp and mp.customTooltipScale or 1.0
end
P.GetCustomTooltipScale = GetCustomTooltipScale

-- EUI-look black box behind an addon button (row and grid alike).
local function ShowAddonBtnBox(btn)
	local d = GetFFD(btn)
	if not d.ungroupBg then
		d.ungroupBg = P.BlackBox(btn, 0.8)
	end
	local ubg = d.ungroupBg
	ubg:SetFrameStrata(btn:GetFrameStrata())
	ubg:SetFrameLevel(max(0, btn:GetFrameLevel() - 1))
	ubg:Show()
end

-- The icon texture of an addon button (named field, else its first shown art).
local function FindIcon(btn)
	local icon = btn.icon or btn.Icon
	if icon then
		return icon
	end
	local d = GetFFD(btn)
	for _, region in ipairs({ btn:GetRegions() }) do
		if region:IsObjectType("Texture") and region:IsShown() and region:GetAlpha() > 0
			and not IsJunkTexture(region) and region ~= (d.ungroupBg and d.ungroupBg.tex) then
			return region
		end
	end
end

local function FitIcon(btn, inset)
	local icon = FindIcon(btn)
	if icon then
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", btn, "TOPLEFT", inset, -inset)
		icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -inset, inset)
		pcall(icon.SetTexCoord, icon, 0.05, 0.95, 0.05, 0.95)
	end
end

-------------------------------------------------------------------------------
--  Grow Tooltip/Popup: the open direction of every popup and tooltip off a
--  minimap button. Auto follows the Button Row Position.
-------------------------------------------------------------------------------
local Grow = {
	edge = {
		left = { "TOPRIGHT", "TOPLEFT", -4, 0 },
		right = { "TOPLEFT", "TOPRIGHT", 4, 0 },
		up = { "BOTTOMLEFT", "TOPLEFT", 0, 4 },
		down = { "TOPLEFT", "BOTTOMLEFT", 0, -4 },
	},
	center = {
		left = { "RIGHT", "LEFT", -4, 0 },
		right = { "LEFT", "RIGHT", 4, 0 },
		up = { "BOTTOM", "TOP", 0, 4 },
		down = { "TOP", "BOTTOM", 0, -4 },
	},
	tt = { left = "left", right = "right", up = "above", down = "below" },
}
P.Grow = Grow

function Grow.Dir()
	local mp = DB()
	local g = (mp and mp.flyoutGrowDir) or "auto"
	if g ~= "auto" then
		return g
	end
	local rp = (mp and mp.btnRowPosition) or "blUp"
	if rp == "blUp" or rp == "tlDown" or rp == "brUp" or rp == "trDown" then
		return "left"
	end
	return "down"
end

function Grow.TT()
	return Grow.tt[Grow.Dir()] or "left"
end

local function ShowButtonTip(owner, text)
	P.ShowTip(owner, text, { anchor = Grow.TT(), scale = GetCustomTooltipScale() })
end
P.ShowButtonTip = ShowButtonTip

-------------------------------------------------------------------------------
--  Flyout grid
-------------------------------------------------------------------------------
local flyoutBuilt = false

local function MouseOverFlyoutChild(panel)
	local focus = GetMouseFocus()
	while focus do
		if focus == panel then
			return true
		end
		focus = focus.GetParent and focus:GetParent()
	end
	return false
end

-- Raise popups an addon parents to its button after layout above the grid.
local function RaiseLateFlyoutChildren(btn)
	if not flyoutPanel or btn:GetParent() ~= flyoutPanel then
		return
	end
	local combat = InCombatLockdown()
	-- Our black backing box stays under the button (raised, it darkens the icon).
	local box = GetFFD(btn).ungroupBg
	local function raise(frame, level)
		for _, child in ipairs({ frame:GetChildren() }) do
			if child ~= box and not (combat and child:IsProtected()) then
				child:SetFrameStrata("DIALOG")
				child:SetFrameLevel(level)
				raise(child, level + 1)
			end
		end
	end
	raise(btn, flyoutPanel:GetFrameLevel() + 6)
end

local function LayoutFlyoutButtons()
	if not flyoutPanel then
		return
	end
	local buttons = CollectFlyoutButtons()
	-- Protected buttons cannot move in combat: leave them out of this pass.
	if InCombatLockdown() then
		local kept = 0
		for i = 1, #buttons do
			local btn = buttons[i]
			if btn:IsProtected() then
				QueueApplyAll()
			else
				kept = kept + 1
				buttons[kept] = btn
			end
		end
		for i = #buttons, kept + 1, -1 do
			buttons[i] = nil
		end
	end
	local count = #buttons
	if count == 0 then
		flyoutPanel:SetSize(1, 1)
		return
	end

	local btnSize = GetAddonBtnSize()
	local mp = DB()
	local boxes = not (mp and mp.btnBackgrounds == false)
	local margin = boxes and FLYOUT_PADDING or 8
	local cols = min(count, FLYOUT_COLS)
	local rows = ceil(count / cols)
	flyoutPanel:SetSize(margin * 2 + cols * btnSize + (cols - 1) * FLYOUT_PADDING,
		margin * 2 + rows * btnSize + (rows - 1) * FLYOUT_PADDING)

	for i, btn in ipairs(buttons) do
		if not flyoutSavedParents[btn] then
			local p1, rel, p2, ox, oy = btn:GetPoint(1)
			flyoutSavedParents[btn] = {
				parent = btn:GetParent(), strata = btn:GetFrameStrata(),
				point = p1, relTo = rel, relPoint = p2, x = ox, y = oy,
			}
		end
		local col = (i - 1) % cols
		local row = floor((i - 1) / cols)
		btn:SetParent(flyoutPanel)
		btn:SetFrameStrata("DIALOG")
		btn:ClearAllPoints()
		btn:SetPoint("TOPLEFT", flyoutPanel, "TOPLEFT", margin + col * (btnSize + FLYOUT_PADDING),
			-(margin + row * (btnSize + FLYOUT_PADDING)))
		btn:SetSize(btnSize, btnSize)
		suppressVisTrack = true
		btn:SetAlpha(1)
		btn:Show()
		suppressVisTrack = false
		btn:SetFrameLevel(flyoutPanel:GetFrameLevel() + 5)
		StripButtonDecorations(btn)
		if not boxes and GetFFD(btn).ungroupBg then
			GetFFD(btn).ungroupBg:Hide()
		end
		for _, child in ipairs({ btn:GetChildren() }) do
			child:SetFrameStrata("DIALOG")
			child:SetFrameLevel(flyoutPanel:GetFrameLevel() + 6)
		end
		if not GetFFD(btn).lateChildHook then
			GetFFD(btn).lateChildHook = true
			if btn:HasScript("OnClick") then
				btn:HookScript("OnClick", RaiseLateFlyoutChildren)
			end
		end
		FitIcon(btn, boxes and 3 or 2)
		if boxes then
			ShowAddonBtnBox(btn)
		end
	end
end

local function EnsureFlyoutPanel()
	if flyoutPanel then
		return
	end
	flyoutPanel = CreateFrame("Frame", nil, UIParent)
	flyoutPanel:SetFrameStrata("DIALOG")
	P.Panel(flyoutPanel, 0.1, 0.1, 0.1, 0.9, 0.3, 0.3, 0.3, 1)
	flyoutPanel:SetClampedToScreen(true)
	flyoutPanel:EnableMouse(true)
	flyoutOwnedFrames[flyoutPanel] = true
	P.flyoutPanel = flyoutPanel
	flyoutPanel:Hide()
	flyoutPanel:HookScript("OnShow", function(self)
		if MO_Evaluate then MO_Evaluate() end
		-- Click-away dismiss: any left press outside the grid and the toggle.
		self:SetScript("OnUpdate", function(m)
			if IsMouseButtonDown("LeftButton") and not m:IsMouseOver()
				and not (flyoutToggle and flyoutToggle:IsMouseOver())
				and not MouseOverFlyoutChild(m) then
				m:Hide()
			end
		end)
	end)
	flyoutPanel:HookScript("OnHide", function(self)
		self:SetScript("OnUpdate", nil)
		if MO_Evaluate then MO_Evaluate() end
	end)
end

local function BuildFlyoutContents()
	EnsureFlyoutPanel()
	LayoutFlyoutButtons()
	flyoutBuilt = true
end
P.BuildFlyoutContents = BuildFlyoutContents

local function InvalidateFlyout()
	flyoutBuilt = false
end
P.InvalidateFlyout = InvalidateFlyout

local function ShowFlyoutPanel()
	EnsureFlyoutPanel()
	local dir = Grow.Dir()
	flyoutPanel:ClearAllPoints()
	if dir == "right" then
		flyoutPanel:SetPoint("BOTTOMLEFT", flyoutToggle, "BOTTOMRIGHT", 2, 0)
	elseif dir == "up" then
		flyoutPanel:SetPoint("BOTTOMLEFT", flyoutToggle, "TOPLEFT", 0, 2)
	elseif dir == "down" then
		flyoutPanel:SetPoint("TOPLEFT", flyoutToggle, "BOTTOMLEFT", 0, -2)
	else
		flyoutPanel:SetPoint("BOTTOMRIGHT", flyoutToggle, "BOTTOMLEFT", -2, 0)
	end
	-- Show before layout: the addon-button Show hook checks IsShown().
	flyoutPanel:Show()
	if not flyoutBuilt then
		BuildFlyoutContents()
	end
end

local function HideFlyoutPanel()
	if flyoutPanel then
		flyoutPanel:Hide()
	end
end
P.HideFlyoutPanel = HideFlyoutPanel

local function ToggleFlyoutPanel()
	if flyoutPanel and flyoutPanel:IsShown() then
		HideFlyoutPanel()
	else
		ShowFlyoutPanel()
	end
end

-- The group toggle: a small 2 x 2 grid glyph in the accent color (retail's
-- Map-Filter-Button atlas does not exist in 5.4.8).
local function PaintToggle(btn, r, g, b)
	for _, sq in ipairs(btn._glyph) do
		sq:SetVertexColor(r, g, b, 1)
	end
end

local function LayoutToggleGlyph(btn)
	local sz = btn:GetWidth()
	local cell = max(2, floor(sz * 0.2 + 0.5))
	local gap = max(1, floor(sz * 0.08 + 0.5))
	local total = cell * 2 + gap
	for i, sq in ipairs(btn._glyph) do
		local col = (i - 1) % 2
		local row = floor((i - 1) / 2)
		sq:ClearAllPoints()
		sq:SetSize(cell, cell)
		sq:SetPoint("TOPLEFT", btn, "CENTER", -total / 2 + col * (cell + gap), total / 2 - row * (cell + gap))
	end
end
P.LayoutToggleGlyph = LayoutToggleGlyph

function P.CreateFlyoutToggle()
	if flyoutToggle then
		PaintToggle(flyoutToggle, P.Accent())
		return flyoutToggle
	end
	local btn = CreateFrame("Button", nil, Minimap)
	local size = GetInteractableBtnSize()
	btn:SetSize(size, size)
	btn:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMLEFT", 0, 0)
	btn:SetFrameLevel(Minimap:GetFrameLevel() + 10)
	btn._bg = P.BlackBox(btn, 0.8)
	btn._glyph = {}
	for i = 1, 4 do
		local sq = btn:CreateTexture(nil, "ARTWORK")
		sq:SetTexture(1, 1, 1, 1)
		btn._glyph[i] = sq
	end
	local hl = btn:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetTexture(1, 1, 1, 0.08)
	LayoutToggleGlyph(btn)
	PaintToggle(btn, P.Accent())
	P.OnAccent(function(r, g, b) PaintToggle(btn, r, g, b) end)

	btn:SetScript("OnClick", function(self)
		if GetFFD(self).freeMoveJustDragged then
			return
		end
		P.HideTip()
		ToggleFlyoutPanel()
	end)
	btn:SetScript("OnEnter", function(self)
		if flyoutPanel and flyoutPanel:IsShown() then
			return
		end
		if not GetFFD(self).freeMoveJustDragged then
			ShowButtonTip(self, "Addon Buttons")
		end
	end)
	btn:SetScript("OnLeave", function()
		P.HideTip()
	end)
	btn:HookScript("OnShow", function(self)
		if not self:IsMouseEnabled() then
			self:EnableMouse(true)
		end
	end)
	flyoutToggle = btn
	P.flyoutToggle = btn
	flyoutOwnedFrames[btn] = true
	return btn
end

-------------------------------------------------------------------------------
--  Row modes: [map corner][growth direction] (blUp = left edge, bottom corner,
--  upward). point/rel = button anchor -> map anchor; dirX/dirY = growth;
--  awayX/awayY = the Distance from Map push; arc = the corner's angle on the
--  circle (circle shape), arcDir = the walk direction.
-------------------------------------------------------------------------------
local BTN_ROW_MODES = {
	blUp = { point = "BOTTOMRIGHT", rel = "BOTTOMLEFT", dirX = 0, dirY = 1, awayX = -1, awayY = 0, arc = 225, arcDir = -1 },
	tlDown = { point = "TOPRIGHT", rel = "TOPLEFT", dirX = 0, dirY = -1, awayX = -1, awayY = 0, arc = 135, arcDir = 1 },
	brUp = { point = "BOTTOMLEFT", rel = "BOTTOMRIGHT", dirX = 0, dirY = 1, awayX = 1, awayY = 0, arc = 315, arcDir = 1 },
	trDown = { point = "TOPLEFT", rel = "TOPRIGHT", dirX = 0, dirY = -1, awayX = 1, awayY = 0, arc = 45, arcDir = -1 },
	tlRight = { point = "BOTTOMLEFT", rel = "TOPLEFT", dirX = 1, dirY = 0, awayX = 0, awayY = 1, arc = 135, arcDir = -1 },
	trLeft = { point = "BOTTOMRIGHT", rel = "TOPRIGHT", dirX = -1, dirY = 0, awayX = 0, awayY = 1, arc = 45, arcDir = 1 },
	blRight = { point = "TOPLEFT", rel = "BOTTOMLEFT", dirX = 1, dirY = 0, awayX = 0, awayY = -1, arc = 225, arcDir = 1 },
	brLeft = { point = "TOPRIGHT", rel = "BOTTOMRIGHT", dirX = -1, dirY = 0, awayX = 0, awayY = -1, arc = 315, arcDir = -1 },
}

local function GetBtnRowMode(mp)
	return BTN_ROW_MODES[mp and mp.btnRowPosition or "blUp"] or BTN_ROW_MODES.blUp
end

local function GetElementRowMode(mp)
	return BTN_ROW_MODES[mp and mp.elementRowPosition or "tlDown"] or BTN_ROW_MODES.tlDown
end

local function GetRowBase(mode, distance)
	local d = distance or 0
	return d * mode.awayX, d * mode.awayY
end

-------------------------------------------------------------------------------
--  Free Move: Shift + drag any minimap-area button; offsets in btnPositions.
-------------------------------------------------------------------------------
local function GetBtnPosKey(frame)
	if frame._indicatorKey then
		return frame._indicatorKey
	end
	local name = frame:GetName()
	if name then
		return name
	end
	if frame == flyoutToggle then
		return "_flyoutToggle"
	end
end

local function GetBtnOffset(key)
	local mp = DB()
	if not mp or not mp.freeMoveBtns or not mp.btnPositions then
		return 0, 0
	end
	local pos = mp.btnPositions[key]
	if not pos then
		return 0, 0
	end
	return pos.x or 0, pos.y or 0
end

local function SaveBtnOffset(key, x, y)
	local mp = DB()
	if not mp then
		return
	end
	mp.btnPositions = mp.btnPositions or {}
	mp.btnPositions[key] = { x = x, y = y }
end

local freeMoveHooked = {}

local function EnableFreeMove(frame)
	if not frame or freeMoveHooked[frame] then
		return
	end
	freeMoveHooked[frame] = true
	local key = GetBtnPosKey(frame)
	if not key then
		return
	end
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)

	-- Third-party buttons own OnClick: wrap it so a drag does not click.
	if not frame._indicatorKey and frame ~= flyoutToggle then
		local origClick = frame:GetScript("OnClick")
		if origClick then
			frame:SetScript("OnClick", function(self, ...)
				if GetFFD(self).freeMoveJustDragged then
					return
				end
				origClick(self, ...)
			end)
		end
	end

	local isDragging = false
	local startX, startY, origOffX, origOffY
	local origPoint, origRel, origRelPoint, origX, origY

	local function CursorDelta(self)
		local es = self:GetEffectiveScale()
		local cx, cy = GetCursorPosition()
		return cx / es - startX, cy / es - startY
	end

	local function Finish(self)
		isDragging = false
		self:SetScript("OnUpdate", nil)
		local dx, dy = CursorDelta(self)
		SaveBtnOffset(key, origOffX + dx, origOffY + dy)
		P.After(0, function() GetFFD(self).freeMoveJustDragged = nil end)
		if P.ApplyMinimap then P.ApplyMinimap() end
	end

	local function FreeMoveOnUpdate(self)
		if not IsMouseButtonDown("LeftButton") then
			Finish(self)
			return
		end
		local dx, dy = CursorDelta(self)
		if origPoint then
			self:ClearAllPoints()
			self:SetPoint(origPoint, origRel, origRelPoint, origX + origOffX + dx, origY + origOffY + dy)
		end
	end

	frame:HookScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" or not IsShiftKeyDown() then
			return
		end
		local mp = DB()
		if not mp or not mp.freeMoveBtns then
			return
		end
		isDragging = true
		GetFFD(self).freeMoveJustDragged = true
		local es = self:GetEffectiveScale()
		startX, startY = GetCursorPosition()
		startX, startY = startX / es, startY / es
		origOffX, origOffY = GetBtnOffset(key)
		origPoint, origRel, origRelPoint, origX, origY = self:GetPoint(1)
		origX = (origX or 0) - origOffX
		origY = (origY or 0) - origOffY
		self:SetScript("OnUpdate", FreeMoveOnUpdate)
	end)
	frame:HookScript("OnMouseUp", function(self, button)
		if button ~= "LeftButton" or not isDragging then
			return
		end
		Finish(self)
	end)
end

local function ApplyBtnOffset(frame)
	if not frame then
		return
	end
	local key = GetBtnPosKey(frame)
	if not key then
		return
	end
	local ox, oy = GetBtnOffset(key)
	if ox == 0 and oy == 0 then
		return
	end
	local p1, rel, p2, x, y = frame:GetPoint(1)
	if p1 then
		frame:SetPoint(p1, rel, p2, (x or 0) + ox, (y or 0) + oy)
	end
end

-------------------------------------------------------------------------------
--  Gathering the minimap's addon buttons
-------------------------------------------------------------------------------
-- Blizzard frames that never go into the group.
local flyoutBlacklist = {
	MinimapZoomIn = true,
	MinimapZoomOut = true,
	MinimapBackdrop = true,
	GameTimeFrame = true,
	TimeManagerClockButton = true,
	MiniMapMailFrame = true,
	MiniMapVoiceChatFrame = true,
	QueueStatusMinimapButton = true,
	HelpOpenTicketButton = true,
	MiniMapWorldMapButton = true,
	MiniMapTracking = true,
	MiniMapTrackingButton = true,
	MiniMapRecordingButton = true,
}

-- Pin / POI frames (HandyNotes, TomTom, GatherMate ...).
local flyoutPinPatterns = { "^HandyNotes", "^TomTom", "^HereBeDragons", "^Questie", "^GatherMate", "^pin", "^Pin", "^Carbonite" }

local function IsPinFrame(name)
	if not name then
		return false
	end
	for _, pat in ipairs(flyoutPinPatterns) do
		if name:match(pat) then
			return true
		end
	end
	return false
end

local addonButtonHooks = {}

local function HideMinimapChild(btn)
	suppressVisTrack = true
	if InCombatLockdown() and btn:IsProtected() then
		QueueApplyAll()
	else
		btn:Hide()
	end
	btn:SetAlpha(0)
	suppressVisTrack = false
	if not addonButtonHooks[btn] then
		addonButtonHooks[btn] = true
		hooksecurefunc(btn, "Show", function(self)
			if not suppressVisTrack then
				-- While the grid is open its buttons are shown by us.
				if not (flyoutPanel and flyoutPanel:IsShown()) then
					addonVisible[self] = true
					InvalidateFlyout()
				end
			end
			if InCombatLockdown() then
				return
			end
			if flyoutPanel and flyoutPanel:IsShown() then
				return
			end
			if IsUngrouped(self) then
				return
			end
			local mp = DB()
			if mp and mp.enabled and not flyoutOwnedFrames[self] then
				self:SetAlpha(0)
			end
		end)
		hooksecurefunc(btn, "Hide", function(self)
			if not suppressVisTrack then
				if flyoutPanel and flyoutPanel:IsShown() then
					self:Show()
					return
				end
				addonVisible[self] = false
				InvalidateFlyout()
			end
		end)
	end
end

-- Third-party tooltips follow Grow Tooltip/Popup.
local hookedTT = {}
local function RepointTT(tt, btn)
	if tt and tt:IsShown() and tt:GetOwner() == btn then
		local gpt = Grow.edge[Grow.Dir()] or Grow.edge.left
		tt:ClearAllPoints()
		tt:SetPoint(gpt[1], btn, gpt[2], gpt[3], gpt[4])
	end
end
local function HookAddonBtnTT(btn)
	if hookedTT[btn] then
		return
	end
	hookedTT[btn] = true
	btn:HookScript("OnEnter", function(self)
		RepointTT(_G.GameTooltip, self)
		RepointTT(_G.LibDBIconTooltip, self)
	end)
end

local function GatherMinimapButtons()
	wipe(cachedAddonButtons)
	if not Minimap then
		return
	end
	local sources = { Minimap }
	if flyoutPanel then
		sources[2] = flyoutPanel
	end
	for _, source in ipairs(sources) do
		for _, child in ipairs({ source:GetChildren() }) do
			if not flyoutOwnedFrames[child] then
				local name = child:GetName()
				if name and (flyoutBlacklist[name] or IsPinFrame(name)) then
					-- skip
				elseif child:IsObjectType("Button") and name and not name:match("%d+$") then
					local w = child:GetWidth() or 0
					if w >= 20 or addonVisible[child] ~= nil then
						if addonVisible[child] == nil then
							addonVisible[child] = child:IsShown() and true or false
						end
						cachedAddonButtons[#cachedAddonButtons + 1] = child
						HookAddonBtnTT(child)
					end
				elseif name and name:match("^LibDBIcon10_") then
					if addonVisible[child] == nil then
						addonVisible[child] = child:IsShown() and true or false
					end
					cachedAddonButtons[#cachedAddonButtons + 1] = child
					HookAddonBtnTT(child)
				end
			end
		end
	end
	-- The only minimap button at all stands on the row by itself.
	local solo, count = nil, 0
	for _, btn in ipairs(cachedAddonButtons) do
		if addonVisible[btn] ~= false then
			count = count + 1
			solo = btn
		end
	end
	P.soloAddonButton = (count == 1) and solo or nil
end
P.GatherMinimapButtons = GatherMinimapButtons

function P.HideAllMinimapButtons()
	GatherMinimapButtons()
	local flyoutOpen = flyoutPanel and flyoutPanel:IsShown()
	for _, btn in ipairs(cachedAddonButtons) do
		if not IsUngrouped(btn) then
			if not (flyoutOpen and btn:GetParent() == flyoutPanel) then
				HideMinimapChild(btn)
			end
		end
	end
end

-- For the settings (Ungroup Minimap Buttons): the addon buttons found on the
-- map, ungrouped ones first in their saved order, the rest A-Z.
function EMM.AddonButtonItems()
	local mp = DB()
	local ug = mp and mp.ungroupedButtons or {}
	local items = {}
	for _, btn in ipairs(cachedAddonButtons) do
		local name = btn:GetName()
		if name and addonVisible[btn] ~= false then
			items[#items + 1] = { value = name, name = GetMinimapButtonLabel(btn) }
		end
	end
	local function OrderOf(key)
		local v = ug[key]
		if type(v) == "number" then
			return v
		end
		return v and math.huge or nil
	end
	table.sort(items, function(a, b)
		local oa, ob = OrderOf(a.value), OrderOf(b.value)
		if oa and ob and oa ~= ob then
			return oa < ob
		end
		if oa and not ob then
			return true
		end
		if ob and not oa then
			return false
		end
		return a.name:lower() < b.name:lower()
	end)
	return items
end

-- Profile swap / reset: invalidate and re-show grid buttons.
function P.RefreshFlyout()
	InvalidateFlyout()
	if flyoutPanel and flyoutPanel:IsShown() then
		BuildFlyoutContents()
	end
	for _, btn in ipairs(cachedAddonButtons) do
		if btn:GetParent() == flyoutPanel then
			btn:SetAlpha(1)
			btn:Show()
		end
	end
end

-------------------------------------------------------------------------------
--  Indicator buttons (our own buttons: no Blizzard frame is moved)
-------------------------------------------------------------------------------
local customIndicators = {}
P.customIndicators = customIndicators

-- 5.4.8 icon art per indicator: texture, texcoords, icon size factor.
local INDICATOR_ART = {
	_tracking = { tex = "Interface\\Minimap\\Tracking\\None", coords = { 0.08, 0.92, 0.08, 0.92 }, scale = 1 },
	_mail = { tex = "Interface\\Minimap\\Tracking\\Mailbox", coords = { 0.08, 0.92, 0.08, 0.92 }, scale = 1 },
	_gameTime = { tex = "Interface\\Calendar\\UI-Calendar-Button", coords = { 0.0, 0.390625, 0.0, 0.78125 }, scale = 1.25 },
}

local function SizeIndicatorIcon(btn)
	local sz = btn:GetWidth()
	local art = INDICATOR_ART[btn._indicatorKey]
	local inset = 3
	local avail = sz - inset * 2
	local s = avail * (art and art.scale or 1)
	btn._icon:ClearAllPoints()
	btn._icon:SetSize(s, s)
	btn._icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
	if btn._day then
		P.SetPlainFont(btn._day, max(6, floor(s * 0.45 + 0.5)))
	end
end

local function CreateIndicatorBtn(key, parent, onClick)
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(GetInteractableBtnSize(), GetInteractableBtnSize())
	btn:SetFrameLevel(parent:GetFrameLevel() + 20)
	btn:EnableMouse(true)
	btn:RegisterForClicks("AnyUp")
	btn._bg = P.BlackBox(btn, 0.8)
	local art = INDICATOR_ART[key]
	local icon = btn:CreateTexture(nil, "ARTWORK")
	if art then
		icon:SetTexture(art.tex)
		icon:SetTexCoord(unpack(art.coords))
	end
	btn._icon = icon
	btn._indicatorKey = key
	SizeIndicatorIcon(btn)
	-- Hover / press tint (retail swaps Up / Mouseover / Down atlases).
	icon:SetVertexColor(0.85, 0.85, 0.85)
	btn:SetScript("OnEnter", function(self) self._icon:SetVertexColor(1, 1, 1) end)
	btn:SetScript("OnLeave", function(self) self._icon:SetVertexColor(0.85, 0.85, 0.85) end)
	btn:SetScript("OnMouseDown", function(self) self._icon:SetVertexColor(0.65, 0.65, 0.65) end)
	btn:SetScript("OnMouseUp", function(self)
		local v = self:IsMouseOver() and 1 or 0.85
		self._icon:SetVertexColor(v, v, v)
	end)
	if onClick then
		btn:SetScript("OnClick", function(self, mouse)
			if GetFFD(self).freeMoveJustDragged then
				return
			end
			onClick(self, mouse)
		end)
	end
	return btn
end

-- Wraps a button's OnEnter / OnLeave (keeps the base tint handlers).
local function WrapHover(btn, onEnter, onLeave)
	local baseEnter = btn:GetScript("OnEnter")
	local baseLeave = btn:GetScript("OnLeave")
	btn:SetScript("OnEnter", function(self)
		if baseEnter then baseEnter(self) end
		onEnter(self)
	end)
	btn:SetScript("OnLeave", function(self)
		if baseLeave then baseLeave(self) end
		onLeave(self)
	end)
end

-------------------------------------------------------------------------------
--  Friends Online: guild and Battle.net / character friends on hover. All
--  data is read when the tooltip opens. 5.4.8 has no BNet favorites.
-------------------------------------------------------------------------------
-- Localized class name -> class file.
local CLASS_FILE
local function ClassFile(localized)
	if not localized then
		return nil
	end
	if not CLASS_FILE then
		CLASS_FILE = {}
		for file, name in pairs(LOCALIZED_CLASS_NAMES_MALE or {}) do
			CLASS_FILE[name] = file
		end
		for file, name in pairs(LOCALIZED_CLASS_NAMES_FEMALE or {}) do
			CLASS_FILE[name] = file
		end
	end
	return CLASS_FILE[localized] or localized:upper():gsub(" ", "")
end

-- "Name-Realm" with the realm's spaces removed (retail BuildFullName).
local function BuildFullName(charName, realmName)
	if type(charName) ~= "string" or charName == "" then
		return nil
	end
	local base = charName:match("^([^%-]+)") or charName
	if type(realmName) == "string" then
		local realm = realmName:gsub("%s+", "")
		if realm ~= "" and realm ~= (GetRealmName() or ""):gsub("%s+", "") then
			return base .. "-" .. realm
		end
		return base
	end
	return charName
end

local function StripNote(note)
	if type(note) ~= "string" or note == "" then
		return nil
	end
	local s = note:find("||EUI:", 1, true)
	if s and note:find("||", s + 6, true) then
		note = note:sub(1, s - 1):match("^(.-)%s*$")
		if note == "" then
			return nil
		end
	end
	return note
end

local function GatherOnlineFriends()
	local guild, friends = {}, {}
	local seenBNet = {}
	local myName = UnitName("player")

	if IsInGuild() then
		local total = GetNumGuildMembers() or 0
		for i = 1, total do
			local name, _, _, level, _, zone, publicNote, _, online, _, classFile = GetGuildRosterInfo(i)
			if online and name then
				local short = name:match("^([^%-]+)") or name
				if short ~= myName then
					guild[#guild + 1] = { name = short, full = name, class = classFile, zone = zone or "",
						level = level, note = publicNote, kind = "guild" }
				end
			end
		end
	end

	local numBNet = BNGetNumFriends and BNGetNumFriends() or 0
	for i = 1, numBNet do
		local presenceID, presenceName, battleTag, _, toonName, toonID, client, isOnline, _, _, _, _, noteText = BNGetFriendInfo(i)
		if isOnline and client == (BNET_CLIENT_WOW or "WoW") and toonID then
			local _, charName, _, realmName, _, _, _, className, _, zoneName, level = BNGetToonInfo(toonID)
			charName = charName or toonName
			local tagName = battleTag and battleTag:match("^([^#]+)") or presenceName
			local entry = {
				name = charName or tagName or "???",
				full = BuildFullName(charName, realmName) or charName,
				class = ClassFile(className),
				zone = zoneName or "",
				level = level,
				bnetTag = tagName,
				bnetName = presenceName,
				presenceID = presenceID,
				toonID = toonID,
				note = noteText,
				kind = "bnet",
			}
			if charName then
				seenBNet[charName] = true
			end
			friends[#friends + 1] = entry
		end
	end

	local numChar = GetNumFriends and GetNumFriends() or 0
	for i = 1, numChar do
		local name, level, className, area, connected, _, note = GetFriendInfo(i)
		if connected and name and not seenBNet[name] then
			friends[#friends + 1] = {
				name = name:match("^([^%-]+)") or name,
				full = name,
				class = ClassFile(className),
				zone = area or "",
				level = level,
				note = note,
				kind = "char",
			}
		end
	end

	-- Guild members leave the friends list (no duplicates).
	local guildSet = {}
	for _, g in ipairs(guild) do
		guildSet[g.name] = true
	end
	for i = #friends, 1, -1 do
		if guildSet[friends[i].name] then
			table.remove(friends, i)
		end
	end

	local function byZone(a, b)
		local az, bz = a.zone or "", b.zone or ""
		if (az == "") ~= (bz == "") then
			return az ~= ""
		end
		if az ~= bz then
			return az < bz
		end
		return (a.name or "") < (b.name or "")
	end
	local function byTag(a, b)
		return (a.bnetTag or a.name or ""):lower() < (b.bnetTag or b.name or ""):lower()
	end
	table.sort(guild, byZone)
	table.sort(friends, byTag)
	return guild, friends
end

local function ClassHex(class)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then
		return P.Hex(c.r, c.g, c.b)
	end
end

local ShowFriendsTooltip, HideFriendsTooltip
do
	local friendsTT
	local rowsPool, headersPool, dividersPool = {}, {}, {}
	local FTT_PAD, FTT_ROW_H, FTT_HDR_H, FTT_GAP = 8, 14, 16, 2
	local FTT_DIV_PAD, FTT_NOTE_H, FTT_NOTE_INDENT, FTT_NOTE_MAX_W = 5, 12, 8, 260
	local hideToken = 0
	local menuOpen = false
	local measure

	local function CancelHide()
		hideToken = hideToken + 1
	end
	local function ScheduleHide()
		hideToken = hideToken + 1
		if menuOpen then
			return
		end
		local mine = hideToken
		P.After(0.15, function()
			if mine ~= hideToken or menuOpen then
				return
			end
			if friendsTT then
				friendsTT:Hide()
			end
		end)
	end

	-- Whisper: Battle.net friends by their account, others by name.
	local function OpenWhisper(charName, bnetName)
		if bnetName and bnetName ~= "" then
			if ChatFrame_SendSmartTell then
				ChatFrame_SendSmartTell(bnetName, DEFAULT_CHAT_FRAME)
				return
			end
			if ChatFrame_SendTell then
				ChatFrame_SendTell(bnetName, DEFAULT_CHAT_FRAME)
				return
			end
		end
		if charName and charName ~= "" and ChatFrame_SendTell then
			ChatFrame_SendTell(charName, DEFAULT_CHAT_FRAME)
		end
	end

	local function Invite(target, toonID)
		if toonID and BNInviteFriend then
			BNInviteFriend(toonID)
		elseif target and target ~= "" then
			InviteUnit(target)
		end
	end

	local menu
	local function GetMenu()
		if menu then
			return menu
		end
		local PAD, RH, MW = 4, 18, 96
		local m = CreateFrame("Frame", nil, UIParent)
		m:SetFrameStrata("TOOLTIP")
		m:SetFrameLevel(500)
		m:SetClampedToScreen(true)
		m:EnableMouse(true)
		m:SetSize(MW, PAD * 2 + RH * 2)
		m:Hide()
		P.Panel(m, 0.067, 0.067, 0.067, 0.95, 1, 1, 1, 0.15)
		local function MakeItem(text, yOff, onClick)
			local b = CreateFrame("Button", nil, m)
			b:RegisterForClicks("AnyUp")
			b:SetPoint("TOPLEFT", m, "TOPLEFT", PAD, yOff)
			b:SetPoint("TOPRIGHT", m, "TOPRIGHT", -PAD, yOff)
			b:SetHeight(RH)
			local hl = b:CreateTexture(nil, "BACKGROUND")
			hl:SetAllPoints()
			hl:SetTexture(1, 1, 1, 0.10)
			hl:Hide()
			b:SetScript("OnEnter", function() hl:Show() end)
			b:SetScript("OnLeave", function() hl:Hide() end)
			b:SetScript("OnClick", function()
				onClick(m)
				m:Hide()
			end)
			local fs = P.NewText(b)
			P.SetPlainFont(fs, 11)
			fs:SetJustifyH("LEFT")
			fs:SetPoint("LEFT", b, "LEFT", 6, 0)
			fs:SetText(text)
		end
		MakeItem("Whisper", -PAD, function(mm) OpenWhisper(mm._target, mm._bnet) end)
		MakeItem("Invite", -PAD - RH, function(mm) Invite(mm._target, mm._toon) end)
		m:SetScript("OnLeave", function(self)
			if not self:IsMouseOver() then
				self:Hide()
			end
		end)
		m:SetScript("OnHide", function()
			menuOpen = false
			ScheduleHide()
		end)
		menu = m
		return m
	end

	local function ShowRowMenu(rowBtn)
		local target, bnet = rowBtn._fttTarget, rowBtn._fttBnet
		if (not target or target == "") and (not bnet or bnet == "") then
			return
		end
		local m = GetMenu()
		m._target, m._bnet, m._toon = target, bnet, rowBtn._fttToon
		menuOpen = true
		CancelHide()
		m:ClearAllPoints()
		m:SetPoint("TOPLEFT", rowBtn, "TOPRIGHT", 0, 0)
		m:Show()
	end

	local function GetTT()
		if friendsTT then
			return friendsTT
		end
		local f = CreateFrame("Frame", nil, UIParent)
		f:SetFrameStrata("TOOLTIP")
		f:SetFrameLevel(200)
		f:SetClampedToScreen(true)
		f:EnableMouse(true)
		f:SetScript("OnEnter", CancelHide)
		f:SetScript("OnLeave", ScheduleHide)
		f:Hide()
		P.Panel(f, 0.067, 0.067, 0.067, 0.92, 1, 1, 1, 0.15)
		f:HookScript("OnShow", function() if MO_Evaluate then MO_Evaluate() end end)
		f:HookScript("OnHide", function()
			if menu then menu:Hide() end
			if MO_Evaluate then MO_Evaluate() end
		end)
		measure = P.NewText(f)
		measure:Hide()
		P.friendsTT = f
		friendsTT = f
		return f
	end

	local function SetRowTarget(btn, entry)
		btn._entry = entry
		btn._fttTarget = entry and (entry.full or entry.name) or nil
		btn._fttBnet = entry and entry.bnetName or nil
		btn._fttToon = entry and entry.toonID or nil
	end

	local function EnsureRow(idx)
		if rowsPool[idx] then
			return rowsPool[idx]
		end
		local tt = GetTT()
		local btn = CreateFrame("Button", nil, tt)
		btn:EnableMouse(true)
		btn:RegisterForClicks("AnyUp")
		btn:SetHeight(FTT_ROW_H)
		local hl = btn:CreateTexture(nil, "BACKGROUND")
		hl:SetAllPoints()
		hl:SetTexture(1, 1, 1, 0.08)
		hl:Hide()
		btn._hl = hl
		btn:SetScript("OnEnter", function(self)
			CancelHide()
			if self._entry then
				self._hl:Show()
			end
		end)
		btn:SetScript("OnLeave", function(self)
			self._hl:Hide()
			ScheduleHide()
		end)
		-- Left-click whispers; right-click opens the menu.
		btn:SetScript("OnClick", function(self, mouse)
			if not self._entry then
				return
			end
			if mouse == "RightButton" then
				ShowRowMenu(self)
			elseif mouse == "LeftButton" then
				OpenWhisper(self._fttTarget, self._fttBnet)
				CancelHide()
				if friendsTT then friendsTT:Hide() end
			end
		end)
		local nameFS = P.NewText(btn)
		nameFS:SetJustifyH("LEFT")
		nameFS:SetPoint("LEFT", btn, "TOPLEFT", 0, -FTT_ROW_H / 2)
		local zoneFS = P.NewText(btn)
		zoneFS:SetJustifyH("RIGHT")
		zoneFS:SetPoint("RIGHT", btn, "TOPRIGHT", 0, -FTT_ROW_H / 2)
		local noteFS = P.NewText(btn)
		noteFS:SetJustifyH("LEFT")
		noteFS:SetWordWrap(false)
		noteFS:SetTextColor(0.75, 0.75, 0.75, 0.9)
		noteFS:SetHeight(FTT_NOTE_H)
		noteFS:SetPoint("LEFT", btn, "TOPLEFT", FTT_NOTE_INDENT, -FTT_ROW_H - FTT_NOTE_H / 2)
		noteFS:SetPoint("RIGHT", btn, "TOPRIGHT", 0, -FTT_ROW_H - FTT_NOTE_H / 2)
		noteFS:Hide()
		rowsPool[idx] = { button = btn, name = nameFS, zone = zoneFS, note = noteFS }
		return rowsPool[idx]
	end

	local function EnsureHeader(idx)
		if headersPool[idx] then
			return headersPool[idx]
		end
		local fs = P.NewText(GetTT())
		fs:SetJustifyH("CENTER")
		fs:SetTextColor(1, 1, 1, 0.9)
		headersPool[idx] = fs
		return fs
	end

	local function EnsureDivider(idx)
		if dividersPool[idx] then
			return dividersPool[idx]
		end
		local tex = GetTT():CreateTexture(nil, "ARTWORK")
		tex:SetTexture(1, 1, 1, 0.12)
		tex:SetHeight(1)
		dividersPool[idx] = tex
		return tex
	end

	local function PlaceTT(tt, anchor)
		tt:ClearAllPoints()
		local gpt = Grow.edge[Grow.Dir()] or Grow.edge.left
		tt:SetPoint(gpt[1], anchor, gpt[2], gpt[3], gpt[4])
		tt:Show()
	end

	function ShowFriendsTooltip(anchor)
		CancelHide()
		if IsInGuild() and GuildRoster then
			GuildRoster()
		end
		local guild, friends = GatherOnlineFriends()
		local tt = GetTT()
		tt:SetScale(GetCustomTooltipScale())
		local total = #guild + #friends

		local mp = DB()
		local maxRows = mp and tonumber(mp.friendsMaxRows) or 0
		if maxRows < 0 then maxRows = 0 end
		-- Hard cap 30 rows per section ("...and N more").
		if maxRows == 0 or maxRows > 30 then maxRows = 30 end
		local showNotes = mp and mp.friendsShowNotes

		for i = 1, #rowsPool do
			local r = rowsPool[i]
			r.name:Hide()
			r.zone:Hide()
			r.note:Hide()
			r.button:Hide()
			r.button:SetHeight(FTT_ROW_H)
			SetRowTarget(r.button, nil)
			r.button._hl:Hide()
		end
		for i = 1, #headersPool do headersPool[i]:Hide() end
		for i = 1, #dividersPool do dividersPool[i]:Hide() end

		if total == 0 then
			local row = EnsureRow(1)
			P.SetPlainFont(row.name, 10)
			row.name:SetText("|cff888888No friends online|r")
			row.zone:SetText("")
			tt:SetSize(FTT_PAD * 2 + 140, FTT_PAD + FTT_ROW_H + FTT_PAD)
			row.button:ClearAllPoints()
			row.button:SetPoint("TOPLEFT", tt, "TOPLEFT", FTT_PAD, -FTT_PAD)
			row.button:SetPoint("TOPRIGHT", tt, "TOPRIGHT", -FTT_PAD, -FTT_PAD)
			row.button:Show()
			row.name:Show()
			PlaceTT(tt, anchor)
			return total
		end

		local sections = {}
		if #guild > 0 then sections[#sections + 1] = { title = "Guild", list = guild } end
		if #friends > 0 then sections[#sections + 1] = { title = "Friends", list = friends } end

		local rowIdx, hdrIdx, divIdx = 0, 0, 0
		local maxNameW, maxZoneW, maxNoteW = 0, 0, 0
		local curY = -FTT_PAD
		local acHex = P.Hex(P.Accent())

		for si, sec in ipairs(sections) do
			if si > 1 then
				curY = curY - FTT_DIV_PAD
				divIdx = divIdx + 1
				local div = EnsureDivider(divIdx)
				div:ClearAllPoints()
				div:SetPoint("TOPLEFT", tt, "TOPLEFT", FTT_PAD, curY)
				div:SetPoint("TOPRIGHT", tt, "TOPRIGHT", -FTT_PAD, curY)
				div:Show()
				curY = curY - div:GetHeight() - FTT_DIV_PAD
			end
			curY = curY - 5
			hdrIdx = hdrIdx + 1
			local hdr = EnsureHeader(hdrIdx)
			P.SetPlainFont(hdr, 12)
			hdr:SetText(sec.title .. " (|cff" .. acHex .. #sec.list .. "|r)")
			hdr:ClearAllPoints()
			hdr:SetPoint("TOP", tt, "TOP", 0, curY)
			hdr:Show()
			curY = curY - FTT_HDR_H - 5

			local shown = min(#sec.list, maxRows)
			for i = 1, shown do
				local e = sec.list[i]
				rowIdx = rowIdx + 1
				local row = EnsureRow(rowIdx)
				P.SetPlainFont(row.name, 10)
				P.SetPlainFont(row.zone, 10)
				local hex = ClassHex(e.class)
				local colored = hex and ("|cff" .. hex .. e.name .. "|r") or e.name
				if e.bnetTag then
					colored = "|cffffd100" .. e.bnetTag .. "|r (" .. colored .. ")"
				end
				local lvl = tonumber(e.level)
				if lvl and lvl > 0 then
					colored = colored .. " |cffb0b0b0" .. lvl .. "|r"
				end
				row.name:SetText(colored)
				row.name:SetTextColor(1, 1, 1, 0.85)
				local zone = e.zone or ""
				row.zone:SetText(zone ~= "" and ("|cff888888" .. zone .. "|r") or "")
				SetRowTarget(row.button, e)
				row.button:ClearAllPoints()
				row.button:SetPoint("TOPLEFT", tt, "TOPLEFT", FTT_PAD, curY)
				row.button:SetPoint("TOPRIGHT", tt, "TOPRIGHT", -FTT_PAD, curY)
				row.button:Show()
				row.name:Show()
				row.zone:Show()
				maxNameW = max(maxNameW, row.name:GetStringWidth() or 0)
				maxZoneW = max(maxZoneW, row.zone:GetStringWidth() or 0)

				local rowH = FTT_ROW_H
				local note = showNotes and StripNote(e.note)
				if note then
					P.SetPlainFont(row.note, 9)
					row.note:SetText(note)
					row.note:Show()
					P.SetPlainFont(measure, 9)
					measure:SetText(note)
					maxNoteW = max(maxNoteW, min(FTT_NOTE_MAX_W, measure:GetStringWidth() or 0))
					rowH = FTT_ROW_H + FTT_NOTE_H
				end
				row.button:SetHeight(rowH)
				curY = curY - (rowH + FTT_GAP)
			end

			if #sec.list > maxRows then
				rowIdx = rowIdx + 1
				local row = EnsureRow(rowIdx)
				P.SetPlainFont(row.name, 10)
				row.name:SetText("|cff888888...and " .. (#sec.list - maxRows) .. " more|r")
				row.zone:SetText("")
				SetRowTarget(row.button, nil)
				row.button:ClearAllPoints()
				row.button:SetPoint("TOPLEFT", tt, "TOPLEFT", FTT_PAD, curY)
				row.button:SetPoint("TOPRIGHT", tt, "TOPRIGHT", -FTT_PAD, curY)
				row.button:Show()
				row.name:Show()
				curY = curY - (FTT_ROW_H + FTT_GAP)
			end
		end

		local contentW = FTT_PAD + maxNameW + 16 + maxZoneW + FTT_PAD
		local noteW = FTT_PAD + FTT_NOTE_INDENT + maxNoteW + FTT_PAD
		tt:SetSize(max(contentW, noteW, 160), -curY + FTT_PAD)
		PlaceTT(tt, anchor)
		return total
	end

	function HideFriendsTooltip()
		ScheduleHide()
	end
end

-------------------------------------------------------------------------------
--  Calendar tooltip: saved instance lockouts with kill counts, server time
--  and the weekly reset.
-------------------------------------------------------------------------------
local calendarTT, calendarTitle
local calendarRows, calendarFooters = {}, {}
local CTT_PAD, CTT_ROW_H, CTT_TITLE_H, CTT_GAP = 8, 14, 16, 6

local function GetCalendarTT()
	if calendarTT then
		return calendarTT
	end
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetFrameStrata("TOOLTIP")
	f:SetFrameLevel(200)
	f:SetClampedToScreen(true)
	f:Hide()
	P.Panel(f, 0.067, 0.067, 0.067, 0.92, 1, 1, 1, 0.15)
	calendarTitle = P.NewText(f)
	calendarTitle:SetJustifyH("CENTER")
	calendarTitle:SetTextColor(1, 1, 1, 0.9)
	calendarTT = f
	return f
end

local function EnsureCalendarPair(pool, idx, la, ra)
	if pool[idx] then
		return pool[idx]
	end
	local tt = GetCalendarTT()
	local l = P.NewText(tt)
	l:SetJustifyH("LEFT")
	local r = P.NewText(tt)
	r:SetJustifyH("RIGHT")
	if la then
		l:SetTextColor(1, 1, 1, la)
		r:SetTextColor(1, 1, 1, ra)
	end
	pool[idx] = { left = l, right = r }
	return pool[idx]
end

local function GetServerTimeText()
	local h, m = GetGameTime()
	if GetCVar("timeMgrUseMilitaryTime") == "1" then
		return format("%02d:%02d", h, m)
	end
	local ampm = h >= 12 and "PM" or "AM"
	h = h % 12
	if h == 0 then h = 12 end
	return format("%d:%02d %s", h, m, ampm)
end

-- 5.4.8 has no weekly reset API: the daily reset (GetQuestResetTime) moved to
-- the region's reset day (Tuesday in the US, Wednesday elsewhere).
local function GetWeeklyResetText()
	local daily = GetQuestResetTime and GetQuestResetTime()
	if not daily or daily <= 0 or not SecondsToTime then
		return ""
	end
	local resetAt = time() + daily
	local wday = tonumber(date("%w", resetAt)) or 0
	local portal = (GetCVar("portal") or ""):upper()
	local target = (portal == "US") and 2 or 3
	local days = (target - wday) % 7
	return SecondsToTime(daily + days * 86400, true, nil, 3)
end

function P.HideCalendarTooltip()
	if calendarTT then
		calendarTT:Hide()
	end
end

function P.ShowCalendarTooltip(anchor, entries)
	local tt = GetCalendarTT()
	tt:SetScale(GetCustomTooltipScale())
	for i = 1, #calendarRows do
		calendarRows[i].left:Hide()
		calendarRows[i].right:Hide()
	end
	for i = 1, #calendarFooters do
		calendarFooters[i].left:Hide()
		calendarFooters[i].right:Hide()
	end
	P.SetPlainFont(calendarTitle, 12)
	calendarTitle:SetText("Calendar")
	local footerData = {
		{ left = "Server Time", right = GetServerTimeText() },
		{ left = "Weekly Reset", right = GetWeeklyResetText() },
	}
	local maxLeftW, maxRightW = 0, 0
	local curY = -CTT_PAD
	calendarTitle:ClearAllPoints()
	calendarTitle:SetPoint("TOP", tt, "TOP", 0, curY)
	calendarTitle:Show()
	curY = curY - CTT_TITLE_H - CTT_GAP

	local function PlacePair(pair, l, r)
		P.SetPlainFont(pair.left, 10)
		P.SetPlainFont(pair.right, 10)
		pair.left:SetText(l)
		pair.right:SetText(r or "")
		pair.left:ClearAllPoints()
		pair.left:SetPoint("TOPLEFT", tt, "TOPLEFT", CTT_PAD, curY)
		pair.right:ClearAllPoints()
		pair.right:SetPoint("TOPRIGHT", tt, "TOPRIGHT", -CTT_PAD, curY)
		pair.left:Show()
		if r and r ~= "" then pair.right:Show() end
		maxLeftW = max(maxLeftW, pair.left:GetStringWidth() or 0)
		maxRightW = max(maxRightW, pair.right:GetStringWidth() or 0)
		curY = curY - CTT_ROW_H
	end
	for i, entry in ipairs(entries or {}) do
		PlacePair(EnsureCalendarPair(calendarRows, i), entry.left, entry.right)
	end
	curY = curY - CTT_GAP
	for i, fd in ipairs(footerData) do
		PlacePair(EnsureCalendarPair(calendarFooters, i, 0.65, 0.80), fd.left, fd.right)
	end
	tt:SetSize(max(CTT_PAD + maxLeftW + 16 + maxRightW + CTT_PAD, 180), -curY + CTT_PAD)
	tt:ClearAllPoints()
	local gpt = Grow.edge[Grow.Dir()] or Grow.edge.left
	tt:SetPoint(gpt[1], anchor, gpt[2], gpt[3], gpt[4])
	tt:Show()
end

-- Saved instance lockouts (raids always, dungeons with encounter progress).
local LOCKOUT_TIER_ORDER = { lfr = 1, normal = 2, heroic = 3 }

function P.GetCalendarLockoutEntries()
	if not GetNumSavedInstances or not GetSavedInstanceInfo then
		return
	end
	if RequestRaidInfo then
		RequestRaidInfo()
	end
	local entries = {}
	for i = 1, GetNumSavedInstances() do
		local name, _, _, difficulty, locked, extended, _, isRaid, _, difficultyName, numEncounters, encounterProgress = GetSavedInstanceInfo(i)
		local held = name and (locked or extended)
		if held and not isRaid and not (numEncounters and numEncounters > 0) then
			held = false
		end
		if held then
			local tier = "normal"
			local label = difficultyName or ""
			if GetDifficultyInfo and difficulty then
				local dname, _, isHeroic = GetDifficultyInfo(difficulty)
				label = dname or label
				if isHeroic then
					tier = "heroic"
				end
			end
			if difficulty == 7 then
				tier = "lfr"
			end
			local rightText = label
			if numEncounters and numEncounters > 0 and encounterProgress and encounterProgress >= 0 then
				rightText = format("%s %d/%d", label, encounterProgress, numEncounters)
			end
			entries[#entries + 1] = { name = name, tierOrder = LOCKOUT_TIER_ORDER[tier] or 2, left = name, right = rightText }
		end
	end
	if #entries == 0 then
		return
	end
	table.sort(entries, function(a, b)
		if a.name ~= b.name then
			return a.name < b.name
		end
		return a.tierOrder < b.tierOrder
	end)
	return entries
end

-------------------------------------------------------------------------------
--  Building the indicators
-------------------------------------------------------------------------------
local function ToggleCalendarFrame()
	if ToggleCalendar then
		ToggleCalendar()
		return
	end
	if Calendar_LoadUI then
		Calendar_LoadUI()
	end
	if Calendar_Toggle then
		Calendar_Toggle()
	end
end

local function CalendarDay()
	if CalendarGetDate then
		local _, _, day = CalendarGetDate()
		if day then
			return day
		end
	end
	return tonumber(date("%d")) or 1
end

local function BuildCustomIndicators(minimap)
	if customIndicators.tracking then
		local fi = customIndicators.friends and customIndicators.friends._icon
		if fi then
			fi:SetVertexColor(P.Accent())
		end
		return
	end

	-- Tracking: opens Blizzard's tracking menu at our button.
	customIndicators.tracking = CreateIndicatorBtn("_tracking", minimap, function(self)
		if not MiniMapTrackingDropDown then
			return
		end
		ToggleDropDownMenu(1, nil, MiniMapTrackingDropDown, self, 0, 0)
		local list = _G.DropDownList1
		if list and list:IsShown() then
			local gpt = Grow.edge[Grow.Dir()] or Grow.edge.left
			list:ClearAllPoints()
			list:SetPoint(gpt[1], self, gpt[2], gpt[3], gpt[4])
		end
	end)
	WrapHover(customIndicators.tracking,
		function(self)
			if not GetFFD(self).freeMoveJustDragged then
				ShowButtonTip(self, TRACKING or "Tracking")
			end
		end,
		function() P.HideTip() end)

	-- Calendar: the calendar page with today's date.
	local cal = CreateIndicatorBtn("_gameTime", minimap, function()
		ToggleCalendarFrame()
	end)
	cal._day = P.NewText(cal)
	cal._day:SetPoint("CENTER", cal._icon, "CENTER", -1, -1)
	cal._day:SetTextColor(0, 0, 0, 1)
	-- The font first: 5.4.8 errors on SetText without one.
	SizeIndicatorIcon(cal)
	cal._calDay = CalendarDay()
	cal._day:SetText(cal._calDay)
	customIndicators.calendar = cal
	WrapHover(cal,
		function(self)
			if GetFFD(self).freeMoveJustDragged then
				return
			end
			local entries = P.GetCalendarLockoutEntries()
			if entries then
				P.ShowCalendarTooltip(self, entries)
			else
				ShowButtonTip(self, "Calendar")
			end
		end,
		function()
			P.HideCalendarTooltip()
			P.HideTip()
		end)

	-- Mail (informational: tooltip with the latest senders).
	customIndicators.mail = CreateIndicatorBtn("_mail", minimap, nil)
	WrapHover(customIndicators.mail,
		function(self)
			if P.HVRevealMapHover then P.HVRevealMapHover() end
			if GetFFD(self).freeMoveJustDragged then
				return
			end
			local text = HAVE_MAIL or "New Mail"
			if GetLatestThreeSenders then
				local s1, s2, s3 = GetLatestThreeSenders()
				if s1 or s2 or s3 then
					text = HAVE_MAIL_FROM or text
					for _, s in ipairs({ s1, s2, s3 }) do
						text = text .. "\n" .. s
					end
				end
			end
			ShowButtonTip(self, text)
		end,
		function() P.HideTip() end)

	-- Friends Online
	local fr = CreateIndicatorBtn("_friends", minimap, function()
		if InCombatLockdown() then
			UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1.0, 0.3, 0.3, 1.0)
			return
		end
		ToggleFriendsFrame(1)
	end)
	fr._icon:SetTexture("Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon")
	fr._icon:SetTexCoord(0, 1, 0, 1)
	fr._icon:SetDesaturated(true)
	fr._icon:SetVertexColor(P.Accent())
	fr._icon:SetAlpha(0.85)
	-- The friends icon keeps the accent tint (no grey press tint).
	fr:SetScript("OnMouseDown", nil)
	fr:SetScript("OnMouseUp", nil)
	P.OnAccent(function(r, g, b) fr._icon:SetVertexColor(r, g, b) end)
	fr:SetScript("OnEnter", function(self)
		self._icon:SetAlpha(1)
		if GetFFD(self).freeMoveJustDragged then
			return
		end
		ShowFriendsTooltip(self)
	end)
	fr:SetScript("OnLeave", function(self)
		self._icon:SetAlpha(0.85)
		HideFriendsTooltip()
	end)
	customIndicators.friends = fr
end

-- Blizzard's originals never render or take clicks.
local function HideBlizzardIndicators()
	for _, name in ipairs({ "MiniMapTracking", "MiniMapTrackingButton", "GameTimeFrame", "MiniMapMailFrame" }) do
		local f = _G[name]
		if f then
			f:SetAlpha(0)
			f:EnableMouse(false)
		end
	end
end

function P.SyncIndicatorVisibility()
	if customIndicators.mail then
		local hasMail = HasNewMail and HasNewMail() and true or false
		local mp = DB()
		if mp and mp.hideMail then
			hasMail = false
		end
		customIndicators.mail:SetShown(hasMail)
	end
end

-------------------------------------------------------------------------------
--  Mouseover Extra Buttons: Friends / Group Button (and ungrouped addon
--  buttons) show only while the mouse is over the minimap or one of them.
-------------------------------------------------------------------------------
local moActive = false
local moButtons = {}
local moHooked = {}
local moHideTimer

local function MO_OverAny()
	if Minimap then
		local mapRegion = GetFFD(Minimap).layoutFrame or Minimap
		if mapRegion:IsMouseOver() then
			return true
		end
	end
	if flyoutPanel and flyoutPanel:IsShown() then
		return true
	end
	if P.friendsTT and P.friendsTT:IsShown() then
		return true
	end
	for i = 1, #moButtons do
		local b = moButtons[i]
		if b:IsShown() and b:IsMouseOver() then
			return true
		end
	end
	return false
end
P.MO_OverAny = MO_OverAny

local function MO_Apply(show)
	local a = show and 1 or 0
	for i = 1, #moButtons do
		moButtons[i]:SetAlpha(a)
	end
end
P.MO_Apply = MO_Apply

local function MO_CancelHide()
	if moHideTimer then
		moHideTimer:Cancel()
		moHideTimer = nil
	end
end
P.MO_CancelHide = MO_CancelHide

MO_Evaluate = function()
	if not moActive then
		return
	end
	MO_CancelHide()
	if MO_OverAny() then
		MO_Apply(true)
	else
		-- A short delay bridges the gaps between adjacent frames.
		moHideTimer = P.NewTimer(0.12, function()
			moHideTimer = nil
			if moActive and not MO_OverAny() then
				MO_Apply(false)
			end
		end)
	end
end
P.MO_Evaluate = MO_Evaluate

function P.MO_IsActive()
	return moActive
end

local function MO_HookFrame(frame)
	if not frame or moHooked[frame] then
		return
	end
	moHooked[frame] = true
	frame:HookScript("OnEnter", function()
		if moActive then
			MO_CancelHide()
			MO_Apply(true)
		end
	end)
	frame:HookScript("OnLeave", function()
		if moActive then
			MO_Evaluate()
		end
	end)
end

local function MO_Refresh(p)
	wipe(moButtons)
	local heb = (p and p.hideExtraBtns) or {}
	if p and p.mouseoverExtraBtns then
		if customIndicators.friends and not heb.friendsOnline then
			moButtons[#moButtons + 1] = customIndicators.friends
		end
		if flyoutToggle and not heb.groupButton then
			moButtons[#moButtons + 1] = flyoutToggle
		end
		for _, btn in ipairs(cachedAddonButtons) do
			if addonVisible[btn] ~= false and IsUngrouped(btn) then
				moButtons[#moButtons + 1] = btn
			end
		end
	end
	moActive = #moButtons > 0
	if moActive then
		MO_HookFrame(Minimap)
		for i = 1, #moButtons do
			MO_HookFrame(moButtons[i])
		end
		MO_Evaluate()
	else
		MO_CancelHide()
		if customIndicators.friends then customIndicators.friends:SetAlpha(1) end
		if flyoutToggle then flyoutToggle:SetAlpha(1) end
		for _, btn in ipairs(cachedAddonButtons) do
			if IsUngrouped(btn) then
				btn:SetAlpha(1)
			end
		end
	end
end

-------------------------------------------------------------------------------
--  Layout of the element row, the button row and the extra buttons
-------------------------------------------------------------------------------
local MAIL_CORNER_POINTS = { TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true }

-- A button's spot on the circle round the map: radius r, angle t (radians).
local function ArcPoint(btn, minimap, r, t)
	btn:SetPoint("CENTER", minimap, "CENTER", P.Snap(r * math.cos(t), minimap), P.Snap(r * math.sin(t), minimap))
end

function P.LayoutIndicatorFrames(minimap, p, circleMode)
	local mapAnchor = GetFFD(minimap).layoutFrame or minimap

	BuildCustomIndicators(minimap)
	HideBlizzardIndicators()
	P.SyncIndicatorVisibility()

	local ci = customIndicators
	local sz = GetInteractableBtnSize()
	local showBg = p.btnBackgrounds ~= false
	local mailCorner = MAIL_CORNER_POINTS[p.mailPosition] and p.mailPosition or nil
	local px = P.PixelFor(minimap)

	local function ResizeIndicator(btn)
		if not btn then
			return
		end
		btn:SetSize(sz, sz)
		if btn._bg then
			btn._bg:SetShown(showBg)
		end
		SizeIndicatorIcon(btn)
	end
	ResizeIndicator(ci.tracking)
	-- Midnight rollover: today's date on the calendar page.
	if ci.calendar then
		local today = CalendarDay()
		if ci.calendar._calDay ~= today then
			ci.calendar._calDay = today
			ci.calendar._day:SetText(today)
		end
	end
	ResizeIndicator(ci.calendar)
	ResizeIndicator(ci.mail)
	if mailCorner and ci.mail and ci.mail._bg then
		ci.mail._bg:SetShown(false)
	end
	if flyoutToggle then
		flyoutToggle:SetSize(sz, sz)
		LayoutToggleGlyph(flyoutToggle)
		if flyoutToggle._bg then
			flyoutToggle._bg:SetShown(showBg)
		end
	end

	if ci.calendar then
		ci.calendar:SetShown(not p.hideGameTime)
	end

	if circleMode then
		-- Circle: a row growing left from the clock (skipping hidden elements).
		local clockBg = P.clockBg
		local leftAnchor = (clockBg and clockBg:IsShown()) and clockBg or nil
		local function PlaceLeft(btn)
			btn:ClearAllPoints()
			if leftAnchor then
				btn:SetPoint("RIGHT", leftAnchor, "LEFT", 0, 0)
			else
				btn:SetPoint("TOP", mapAnchor, "TOP", -20, -3)
			end
			leftAnchor = btn
		end
		if ci.tracking and not p.hideTrackingButton then
			PlaceLeft(ci.tracking)
			ci.tracking:Show()
		elseif ci.tracking then
			ci.tracking:Hide()
		end
		if ci.calendar and not p.hideGameTime then
			ci.calendar:ClearAllPoints()
			if clockBg and clockBg:IsShown() then
				ci.calendar:SetPoint("LEFT", clockBg, "RIGHT", 0, 0)
			else
				ci.calendar:SetPoint("TOP", mapAnchor, "TOP", 20, -3)
			end
		end
		if ci.mail and ci.mail:IsShown() then
			if mailCorner then
				ci.mail:ClearAllPoints()
				ci.mail:SetPoint(mailCorner, mapAnchor, mailCorner, p.mailOffsetX or 0, p.mailOffsetY or 0)
			else
				PlaceLeft(ci.mail)
			end
		end
	else
		-- Square / Rectangular: the element row from its corner, flush in
		-- whole physical pixels.
		local rowMode = GetElementRowMode(p)
		local baseX, baseY = GetRowBase(rowMode, p.elementRowDistance)
		local gap = P.Snap(p.elementRowSpacing or 0, minimap)
		local x, y = P.Snap(baseX, minimap), P.Snap(baseY, minimap)
		local function PlaceElement(btn)
			btn:ClearAllPoints()
			btn:SetPoint(rowMode.point, mapAnchor, rowMode.rel, x, y)
			local adv = (rowMode.dirX ~= 0) and btn:GetWidth() or btn:GetHeight()
			adv = floor(adv / px + 0.001) * px + gap
			x = x + adv * rowMode.dirX
			y = y + adv * rowMode.dirY
		end
		if ci.tracking and not p.hideTrackingButton then
			PlaceElement(ci.tracking)
			ci.tracking:Show()
		elseif ci.tracking then
			ci.tracking:Hide()
		end
		if ci.calendar and not p.hideGameTime then
			PlaceElement(ci.calendar)
		end
		if ci.mail and ci.mail:IsShown() then
			if mailCorner then
				ci.mail:ClearAllPoints()
				ci.mail:SetPoint(mailCorner, mapAnchor, mailCorner, p.mailOffsetX or 0, p.mailOffsetY or 0)
			else
				PlaceElement(ci.mail)
			end
		end
	end

	-- Button row: the group toggle first, then ungrouped buttons and extras.
	if flyoutToggle then
		local rowMode = GetBtnRowMode(p)
		local rowBaseX, rowBaseY = GetRowBase(rowMode, p.btnRowDistance)
		local rowGap = P.Snap(p.btnRowSpacing or 0, minimap)
		local rowX, rowY = P.Snap(rowBaseX, minimap), P.Snap(rowBaseY, minimap)
		-- Round maps (not with Free Move): the row walks the edge of the
		-- circle from its corner, half over the map, with a 4 px base gap.
		local arcR, arcT, arcDir
		local arcGap = 0
		if circleMode and not p.freeMoveBtns then
			local mapW = minimap:GetWidth() or 140
			arcR = mapW / 2 + (p.borderSize or 1) + (p.btnRowDistance or 0)
			arcGap = P.Snap(4, minimap)
			arcT = math.rad(rowMode.arc or 225)
			arcDir = rowMode.arcDir or -1
		end
		local function PlaceRowButton(btn)
			local adv = (rowMode.dirX ~= 0) and btn:GetWidth() or btn:GetHeight()
			adv = floor(adv / px + 0.001) * px + rowGap
			if arcR then
				ArcPoint(btn, minimap, arcR, arcT)
				arcT = arcT + arcDir * (adv + arcGap) / arcR
			else
				btn:SetPoint(rowMode.point, mapAnchor, rowMode.rel, rowX, rowY)
				rowX = rowX + adv * rowMode.dirX
				rowY = rowY + adv * rowMode.dirY
			end
		end

		flyoutToggle:ClearAllPoints()
		if flyoutToggle:IsShown() then
			PlaceRowButton(flyoutToggle)
		elseif arcR then
			ArcPoint(flyoutToggle, minimap, arcR, arcT)
		else
			flyoutToggle:SetPoint(rowMode.point, mapAnchor, rowMode.rel, rowX, rowY)
		end

		local mp = DB()
		local ungrouped = {}
		for _, btn in ipairs(cachedAddonButtons) do
			if addonVisible[btn] ~= false and IsUngrouped(btn) then
				local order = mp and mp.ungroupedButtons and mp.ungroupedButtons[btn:GetName()] or 999
				if type(order) ~= "number" then
					order = 999
				end
				ungrouped[#ungrouped + 1] = { btn = btn, order = order }
			end
		end
		table.sort(ungrouped, function(a, b) return a.order < b.order end)
		for _, entry in ipairs(ungrouped) do
			local btn = entry.btn
			if flyoutSavedParents[btn] then
				flyoutSavedParents[btn] = nil
			end
			if not (InCombatLockdown() and btn:IsProtected()) then
				btn:SetParent(minimap)
				btn:SetFrameStrata(minimap:GetFrameStrata())
				btn:SetFrameLevel(minimap:GetFrameLevel() + 11)
				btn:ClearAllPoints()
				if showBg then
					StripButtonDecorations(btn)
					btn:SetSize(sz, sz)
				else
					RestoreButtonDecorations(btn)
				end
				PlaceRowButton(btn)
				btn:SetMovable(false)
				btn:RegisterForDrag()
				btn:SetScript("OnDragStart", nil)
				btn:SetScript("OnDragStop", nil)
				if showBg then
					FitIcon(btn, 3)
					ShowAddonBtnBox(btn)
				elseif GetFFD(btn).ungroupBg then
					GetFFD(btn).ungroupBg:Hide()
				end
				suppressVisTrack = true
				btn:SetAlpha(1)
				btn:Show()
				suppressVisTrack = false
			else
				QueueApplyAll()
			end
		end

		local heb = p.hideExtraBtns or {}
		if ci.friends then
			if heb.friendsOnline then
				ci.friends:Hide()
			else
				ci.friends:SetSize(sz, sz)
				SizeIndicatorIcon(ci.friends)
				if ci.friends._bg then
					ci.friends._bg:SetShown(showBg)
				end
				ci.friends:SetParent(minimap)
				ci.friends:SetFrameLevel(minimap:GetFrameLevel() + 11)
				ci.friends:ClearAllPoints()
				PlaceRowButton(ci.friends)
				ci.friends:Show()
			end
		end
		if heb.groupButton then
			flyoutToggle:Hide()
		end
	end

	-- Free Move: Shift + drag on every row button, saved offsets on top.
	local heb = p.hideExtraBtns or {}
	local targets = {}
	if ci.tracking and not p.hideTrackingButton then targets[#targets + 1] = ci.tracking end
	if ci.calendar and not p.hideGameTime then targets[#targets + 1] = ci.calendar end
	if ci.mail then targets[#targets + 1] = ci.mail end
	if flyoutToggle then targets[#targets + 1] = flyoutToggle end
	if ci.friends and not heb.friendsOnline then targets[#targets + 1] = ci.friends end
	for _, btn in ipairs(cachedAddonButtons) do
		if addonVisible[btn] ~= false and IsUngrouped(btn) then
			targets[#targets + 1] = btn
		end
	end
	for _, frame in ipairs(targets) do
		EnableFreeMove(frame)
		if p.freeMoveBtns then
			ApplyBtnOffset(frame)
		end
	end

	MO_Refresh(p)
end
