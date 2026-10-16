-- Settings window in the EllesmereUI style, built only with the 5.4.8 API
-- (solid color textures, no backdrop templates, no PNG art).
-- EllesmereUIOptions is load on demand: /eui loads it (ns.ToggleSettings in
-- the core). The pages are in the EUI_*_Options.lua files of this addon; the
-- art and font are in the core addon (EllesmereUI/media).

local ns = EllesmereUI

local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local format = format

---------------------------------------------------------------------------
-- Style
---------------------------------------------------------------------------
-- UI accent color (Global Settings > General > UI Accent Color). Changed in
-- place by ApplyAccent, so code that reads ACCENT when it paints follows it.
local ACCENT = { 12 / 255, 210 / 255, 157 / 255 }
if ns.ResolveAccent then
	ACCENT[1], ACCENT[2], ACCENT[3] = ns.ResolveAccent()
end
local PANEL_BG = { 0.069, 0.058, 0.047 }
local DROPDOWN_BG = { 0.103, 0.095, 0.088 }

local FONT = ns.FONT
local FONT_FALLBACK = "Fonts\\ARIALN.TTF"

-- The window art is the EllesmereUI default theme (eui-bg + eui-bg-new, logo
-- removed), cut into 9 tiles: media\ui\window_R_C.tga, from a 1500 x 1154
-- picture. Its usable area is 1300 x 946 at offset 100,104; the rest is shadow.
-- All numbers below are the EllesmereUI ones (1 unit = 1 art pixel); the
-- window scale makes 1 unit = 1 screen pixel by default, like EllesmereUI.
local ART_PATH = ns.MEDIA .. "ui\\"
local ART_LEFT, ART_TOP = 100, 104
local ART_TILE_W = 512
local ART_ROW_H = { 512, 512, 256 }

local WIN_W, WIN_H = 1300, 946
local SIDEBAR_W = 295
local HEADER_H = 138 -- title + description (the banner glow is in the art)
local TAB_BAR_H = 40 -- dark band with the tabs (in the art)
local CONTENT_TOP = HEADER_H + TAB_BAR_H
local FOOTER_H = 82
local LOGO_H = 86
local NAV_TOP = 114
local NAV_H = 40
local NAV_ICON_W, NAV_ICON_H = 46, 31
local GROUP_ROW_H = 28
local CHILD_ROW_H = 28
local GROUP_GAP = 10
local SEARCH_H = 28
local CONTENT_PAD = 45
local ROW_H = 50
local SECTION_H = 40
local CONTROL_W = 170
local CONTROL_H = 30
local SLIDER_W = 160
local CONTENT_W = WIN_W - SIDEBAR_W
local CONTENT_H = WIN_H - CONTENT_TOP - FOOTER_H
local MENU_ITEM_H = 24
local MENU_MAX_ITEMS = 15

local PANEL_SCALE_MIN, PANEL_SCALE_MAX = 0.75, 2.00
local ShiftWheelScale -- Shift + mouse wheel steps the Window Scale (set by BuildScaleControl)

local window, panel, contentHost, headerTitle, headerDesc
local pages = {}
local navButtons = {}
local currentPage
local refreshers = {}

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------
local function SetFont(fontString, size, path)
	fontString:SetFont(path or FONT, size, "")
	if not fontString:GetFont() then
		fontString:SetFont(FONT_FALLBACK, size, "")
	end
end

local function NewText(parent, size, alpha, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	SetFont(fs, size)
	fs:SetTextColor(1, 1, 1, alpha or 1)
	fs:SetJustifyH("LEFT")
	return fs
end

local function Solid(parent, layer, r, g, b, a)
	local tex = parent:CreateTexture(nil, layer or "BACKGROUND")
	tex:SetTexture(r, g, b, a)
	return tex
end

-- 1 pixel border made of 4 textures (BackdropTemplate does not exist in 5.4.8).
local function AddBorder(frame, r, g, b, a, layer)
	local border = {}
	local function Edge()
		local tex = frame:CreateTexture(nil, layer or "BORDER")
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

-- Accent colored parts that are painted once (EllesmereUI RegAccent): they
-- are painted again when the accent changes.
local accentParts = {}

local function AccentSolid(parent, layer, a)
	local tex = Solid(parent, layer, ACCENT[1], ACCENT[2], ACCENT[3], a)
	accentParts[#accentParts + 1] = { tex = tex, a = a }
	return tex
end

local function AccentGradient(parent, layer, a1)
	local tex = parent:CreateTexture(nil, layer)
	tex:SetTexture(1, 1, 1, 1)
	tex:SetGradientAlpha("HORIZONTAL", ACCENT[1], ACCENT[2], ACCENT[3], a1, ACCENT[1], ACCENT[2], ACCENT[3], 0)
	tex:Hide()
	accentParts[#accentParts + 1] = { grad = tex, a = a1 }
	return tex
end

local function AccentText(fs, a)
	fs:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3], a)
	accentParts[#accentParts + 1] = { text = fs, a = a }
end

local RefreshAll

local function ApplyAccent(r, g, b)
	ACCENT[1], ACCENT[2], ACCENT[3] = r, g, b
	for i = 1, #accentParts do
		local part = accentParts[i]
		if part.tex then
			part.tex:SetTexture(r, g, b, part.a)
		elseif part.grad then
			part.grad:SetGradientAlpha("HORIZONTAL", r, g, b, part.a, r, g, b, 0)
		elseif part.text then
			part.text:SetTextColor(r, g, b, part.a)
		end
	end
	if RefreshAll then
		RefreshAll()
	end
end
if ns.accentListeners then
	tinsert(ns.accentListeners, ApplyAccent)
end

local function RegisterRefresh(fn)
	refreshers[#refreshers + 1] = fn
end

function RefreshAll()
	for i = 1, #refreshers do
		refreshers[i]()
	end
end

-- Every module adds its apply function to ns.applyHooks. An error in one
-- module is reported but does not stop the others.
local function ApplyModules()
	local hooks = ns.applyHooks or {}
	local handler = geterrorhandler()
	for i = 1, #hooks do
		xpcall(hooks[i], handler)
	end
end

local function ApplyAndRefresh()
	ApplyModules()
	RefreshAll()
end

-- Page:OnRefresh functions (live previews) also run after every slider
-- step and color picker change, which do not refresh the whole window.
local liveRefreshers = {}

local function ApplyAndRefreshLive()
	ApplyModules()
	for i = 1, #liveRefreshers do
		liveRefreshers[i]()
	end
end

-- Mouse wheel over any control scrolls the current page
-- (Shift + wheel: Window Scale).
local function ForwardWheel(frame)
	frame:EnableMouseWheel(true)
	frame:SetScript("OnMouseWheel", function(_, delta)
		if ShiftWheelScale and ShiftWheelScale(delta) then
			return
		end
		if currentPage then
			currentPage:ScrollBy(-delta * 60)
		end
	end)
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------
local tip
local function ShowTip(owner, text)
	if not text or text == "" then
		return
	end
	if not tip then
		tip = CreateFrame("Frame", nil, UIParent)
		tip:SetFrameStrata("TOOLTIP")
		Solid(tip, "BACKGROUND", 0.067, 0.067, 0.067, 0.94):SetAllPoints()
		AddBorder(tip, 1, 1, 1, 0.15)
		tip.text = NewText(tip, 12, 0.85)
		tip.text:SetPoint("TOPLEFT", 9, -8)
		tip.text:SetWidth(250)
		tip.text:SetWordWrap(true)
		tip.text:SetSpacing(3)
	end
	tip.text:SetText(text)
	tip:SetSize(250 + 18, tip.text:GetStringHeight() + 16)
	tip:ClearAllPoints()
	tip:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 20, 4)
	tip:Show()
end

local function HideTip()
	if tip then
		tip:Hide()
	end
end

---------------------------------------------------------------------------
-- Buttons (footer style)
---------------------------------------------------------------------------
local function CreateFlatButton(parent, width, height, label, accent)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(width, height)
	Solid(button, "BACKGROUND", PANEL_BG[1], PANEL_BG[2], PANEL_BG[3], 0.92):SetAllPoints()
	button.border = AddBorder(button, 1, 1, 1, 0.4)
	button.label = NewText(button, 13, 0.5)
	button.label:SetPoint("CENTER")
	button.label:SetJustifyH("CENTER")
	button.label:SetText(label)
	button.accent = accent

	function button:SetVisual(hover)
		local a1, a2 = 0.4, 0.5
		if hover then
			a1, a2 = 0.6, 0.7
		end
		if self.accent then
			local alpha = hover and 1 or 0.7
			self.border:SetColor(ACCENT[1], ACCENT[2], ACCENT[3], alpha)
			self.label:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3], alpha)
		else
			self.border:SetColor(1, 1, 1, a1)
			self.label:SetTextColor(1, 1, 1, a2)
		end
	end
	button:SetScript("OnEnter", function(self)
		self:SetVisual(true)
		if self.tooltip then
			ShowTip(self, self.tooltip)
		end
	end)
	button:SetScript("OnLeave", function(self)
		self:SetVisual(false)
		HideTip()
	end)
	button:SetVisual(false)
	return button
end

---------------------------------------------------------------------------
-- Popups (EllesmereUI ShowConfirmPopup / ShowInfoPopup): dark box over a dim
-- screen. opts: title, message, disclaimer (red line), typeToConfirm (word
-- to type first), confirmText, cancelText, hideCancel, onConfirm, onCancel,
-- reload (ReloadUI after onConfirm).
---------------------------------------------------------------------------
local POPUP_W = 420
local popup

local function BuildPopup()
	-- Named like retail (Unlock Mode checks EUIConfirmDimmer); above the Unlock Mode banner.
	popup = CreateFrame("Frame", "EUIConfirmDimmer", UIParent)
	popup:SetAllPoints(UIParent)
	popup:SetFrameStrata("TOOLTIP")
	popup:SetFrameLevel(90) -- above the Unlock Mode banner (50) and tip (60); levels stop at 128
	popup:EnableMouse(true)
	popup:EnableKeyboard(true)
	Solid(popup, "BACKGROUND", 0, 0, 0, 0.55):SetAllPoints()

	local box = CreateFrame("Frame", nil, popup)
	popup.box = box
	box:SetWidth(POPUP_W)
	box:SetPoint("CENTER", 0, 60)
	box:EnableMouse(true)
	Solid(box, "BACKGROUND", PANEL_BG[1], PANEL_BG[2], PANEL_BG[3], 0.98):SetAllPoints()
	AddBorder(box, 1, 1, 1, 0.15)
	popup.accent = AccentSolid(box, "ARTWORK", 0.7)
	popup.accent:SetHeight(2)
	popup.accent:SetPoint("TOPLEFT", 1, -1)
	popup.accent:SetPoint("TOPRIGHT", -1, -1)

	popup.title = NewText(box, 18, 1)
	popup.title:SetPoint("TOP", 0, -22)
	popup.title:SetJustifyH("CENTER")
	popup.message = NewText(box, 13, 0.75)
	popup.message:SetWidth(POPUP_W - 60)
	popup.message:SetJustifyH("CENTER")
	popup.message:SetSpacing(3)
	popup.message:SetWordWrap(true)
	popup.disclaimer = NewText(box, 12, 1)
	popup.disclaimer:SetTextColor(0.9, 0.3, 0.3, 0.9)
	popup.disclaimer:SetWidth(POPUP_W - 60)
	popup.disclaimer:SetJustifyH("CENTER")
	popup.disclaimer:SetWordWrap(true)

	-- Scrolling text for info popups.
	local scroll = CreateFrame("ScrollFrame", nil, box)
	popup.scroll = scroll
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(POPUP_W - 60, 10)
	scroll:SetScrollChild(child)
	popup.content = NewText(child, 13, 0.75)
	popup.content:SetPoint("TOPLEFT")
	popup.content:SetWidth(POPUP_W - 60)
	popup.content:SetSpacing(3)
	popup.content:SetWordWrap(true)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local range = self:GetVerticalScrollRange()
		self:SetVerticalScroll(min(range, max(0, self:GetVerticalScroll() - delta * 40)))
	end)

	local edit = CreateFrame("EditBox", nil, box)
	popup.edit = edit
	edit:SetSize(200, 28)
	edit:SetAutoFocus(false)
	edit:SetJustifyH("CENTER")
	edit:SetFont(FONT, 13, "")
	edit:SetTextColor(1, 1, 1, 1)
	Solid(edit, "BACKGROUND", 0.030, 0.023, 0.018, 0.5):SetAllPoints()
	AddBorder(edit, 1, 1, 1, 0.15)
	edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

	popup.confirm = CreateFlatButton(box, 170, 34, "", true)
	popup.cancel = CreateFlatButton(box, 170, 34, "")

	local function Close()
		popup:Hide()
		popup.edit:ClearFocus()
	end
	popup.Close = Close
	popup.cancel:SetScript("OnClick", function()
		local opts = popup.opts
		Close()
		if opts and opts.onCancel then
			opts.onCancel()
		end
	end)
	popup.confirm:SetScript("OnClick", function()
		local opts = popup.opts
		if popup.word and (popup.edit:GetText() or ""):lower() ~= popup.word:lower() then
			return
		end
		local text = popup.edit:GetText()
		Close()
		if opts and opts.onConfirm then
			-- Input popups (ShowInputPopup) hand the typed text over.
			opts.onConfirm(popup.input and text or nil)
		end
		if opts and opts.reload then
			ReloadUI()
		end
	end)
	edit:SetScript("OnTextChanged", function(self)
		local ok = not popup.word or (self:GetText() or ""):lower() == popup.word:lower()
		popup.confirm:SetAlpha(ok and 1 or 0.35)
	end)
	edit:SetScript("OnEnterPressed", function() popup.confirm:Click() end)
	popup:SetScript("OnKeyDown", function(self, key)
		if key == "ESCAPE" then
			self:SetPropagateKeyboardInput(false)
			-- opts.onDismiss (retail): Escape only closes the popup.
			local opts = popup.opts
			if opts and opts.onDismiss then
				Close()
				opts.onDismiss()
				return
			end
			popup.cancel:Click()
		else
			self:SetPropagateKeyboardInput(true)
		end
	end)
	popup:Hide()
end

local function LayoutPopup(opts, info)
	if not popup then
		BuildPopup()
	end
	popup.opts = opts
	popup.word = (not info) and opts.typeToConfirm or nil
	popup.input = (not info) and opts.input and true or nil
	popup.title:SetText(opts.title or "")
	local y = -22 - 18 - 16
	local box = popup.box
	popup.message:ClearAllPoints()
	popup.disclaimer:ClearAllPoints()
	popup.edit:ClearAllPoints()
	popup.scroll:ClearAllPoints()
	popup.message:SetShown(not info)
	popup.scroll:SetShown(info and true or false)
	if info then
		popup.content:SetText(opts.content or "")
		local h = min(380, popup.content:GetStringHeight() + 4)
		popup.scroll:SetSize(POPUP_W - 60, h)
		popup.scroll:SetPoint("TOP", box, "TOP", 0, y)
		popup.scroll:GetScrollChild():SetHeight(popup.content:GetStringHeight() + 4)
		popup.scroll:SetVerticalScroll(0)
		y = y - h - 20
	else
		popup.message:SetText(opts.message or "")
		popup.message:SetPoint("TOP", box, "TOP", 0, y)
		y = y - popup.message:GetStringHeight() - 16
	end
	if opts.disclaimer and not info then
		popup.disclaimer:SetText(opts.disclaimer)
		popup.disclaimer:SetPoint("TOP", box, "TOP", 0, y)
		popup.disclaimer:Show()
		y = y - popup.disclaimer:GetStringHeight() - 16
	else
		popup.disclaimer:Hide()
	end
	if popup.word then
		popup.edit:SetWidth(200)
		popup.edit:SetPoint("TOP", box, "TOP", 0, y - 18)
		popup.edit:SetText("")
		popup.edit:Show()
		if not popup.typeLabel then
			popup.typeLabel = NewText(box, 12, 0.5)
			popup.typeLabel:SetJustifyH("CENTER")
		end
		popup.typeLabel:ClearAllPoints()
		popup.typeLabel:SetPoint("BOTTOM", popup.edit, "TOP", 0, 6)
		popup.typeLabel:SetText(format('Type "%s" to continue', popup.word))
		popup.typeLabel:Show()
		y = y - 18 - 28 - 18
		popup.confirm:SetAlpha(0.35)
	elseif popup.input then
		-- Text input (EllesmereUI ShowInputPopup): the box starts with opts.text.
		popup.edit:SetWidth(POPUP_W - 120)
		popup.edit:SetPoint("TOP", box, "TOP", 0, y)
		popup.edit:SetText(opts.text or "")
		popup.edit:Show()
		if popup.typeLabel then
			popup.typeLabel:Hide()
		end
		y = y - 28 - 20
		popup.confirm:SetAlpha(1)
	else
		popup.edit:Hide()
		if popup.typeLabel then
			popup.typeLabel:Hide()
		end
		popup.confirm:SetAlpha(1)
	end
	popup.confirm:ClearAllPoints()
	popup.cancel:ClearAllPoints()
	popup.confirm.label:SetText(opts.confirmText or OKAY)
	popup.cancel.label:SetText(opts.cancelText or CANCEL)
	if opts.hideCancel then
		popup.cancel:Hide()
		popup.confirm:SetPoint("TOP", box, "TOP", 0, y)
	else
		popup.cancel:Show()
		popup.cancel:SetPoint("TOPRIGHT", box, "TOP", -8, y)
		popup.confirm:SetPoint("TOPLEFT", box, "TOP", 8, y)
	end
	y = y - 34 - 22
	box:SetHeight(-y)
	popup:Show()
	if popup.word or popup.input then
		popup.edit:SetFocus()
		if popup.input then
			popup.edit:HighlightText()
		end
	end
end

local function ShowConfirmPopup(opts)
	LayoutPopup(opts, false)
end

local function ShowInfoPopup(opts)
	opts.confirmText = opts.confirmText or "Close"
	opts.hideCancel = true
	LayoutPopup(opts, true)
end

-- Text input popup (EllesmereUI ShowInputPopup): opts.text = starting text;
-- onConfirm(text) gets what was typed.
local function ShowInputPopup(opts)
	opts.input = true
	LayoutPopup(opts, false)
end

ns.ShowConfirmPopup = ShowConfirmPopup
ns.ShowInfoPopup = ShowInfoPopup
ns.ShowInputPopup = ShowInputPopup

---------------------------------------------------------------------------
-- String popup (retail EllesmereUI_Profiles.lua BuildStringPopup): a big
-- scrolling text box for profile strings. opts: title, subtitle, text
-- (read-only box with this text, selected for Ctrl+C) or editable = true
-- (paste box), confirmText, onConfirm(str) (editable only).
---------------------------------------------------------------------------
local stringPopup

-- Paste absorber (retail AttachImportPasteAbsorber): a multi-line box lays
-- out again after every pasted character, so a long profile string stalls
-- the client. The box stays capped small; OnChar collects the whole paste
-- in a Lua buffer and the box shows a short line instead.
local function AttachPasteAbsorber(editBox)
	local CAP = 2048
	editBox:SetMaxLetters(0)
	editBox:SetMaxBytes(CAP)
	local buf, bufN, lastN = {}, 0, 0
	local captured
	local settingText = false
	local absorber = {}

	local function Finalize()
		editBox:SetScript("OnUpdate", nil)
		local s = strtrim(table.concat(buf, "", 1, bufN))
		wipe(buf)
		bufN, lastN = 0, 0
		local boxText = editBox:GetText() or ""
		if #s > #boxText then
			captured = s
			settingText = true
			editBox:SetText(format("[ Import string captured (%d characters) ]", #s))
			editBox:SetCursorPosition(0)
			settingText = false
		elseif #boxText >= CAP then
			-- Nothing reached the buffer past the cap: lift the cap so a
			-- second paste lands fully in the box (slower, but complete).
			captured = nil
			editBox:SetMaxBytes(0)
			settingText = true
			editBox:SetText("")
			settingText = false
			ShowInfoPopup({ title = "Paste Interrupted", content = "The pasted string could not be read completely. Please paste it again." })
		else
			captured = nil
		end
	end

	editBox:HookScript("OnChar", function(_, c)
		bufN = bufN + 1
		buf[bufN] = c
		if bufN == 1 then
			lastN = 0
			editBox:SetScript("OnUpdate", function()
				if bufN == lastN then
					Finalize()
				else
					lastN = bufN
				end
			end)
		end
	end)
	editBox:HookScript("OnTextChanged", function(_, userInput)
		if userInput and not settingText and bufN == 0 then
			if captured then
				-- A manual edit after a capture: the user starts over.
				captured = nil
			elseif editBox:GetMaxBytes() == CAP and #(editBox:GetText() or "") >= CAP - 1 then
				-- The paste came in without OnChar and was cut at the cap: lift
				-- the cap so a second paste lands fully in the box.
				editBox:SetMaxBytes(0)
				settingText = true
				editBox:SetText("")
				settingText = false
				ShowInfoPopup({ title = "Paste Interrupted", content = "The pasted string could not be read completely. Please paste it again." })
			end
		end
	end)

	function absorber.GetText()
		if captured then
			return captured
		end
		return strtrim(editBox:GetText() or "")
	end
	function absorber.Reset()
		captured = nil
		wipe(buf)
		bufN, lastN = 0, 0
		editBox:SetScript("OnUpdate", nil)
		editBox:SetMaxBytes(CAP)
		settingText = true
		editBox:SetText("")
		settingText = false
	end
	return absorber
end

local function BuildStringPopup()
	local W, H = 520, 310
	local p = CreateFrame("Frame", nil, UIParent)
	stringPopup = p
	p:SetAllPoints(UIParent)
	p:SetFrameStrata("TOOLTIP")
	p:SetFrameLevel(80)
	p:EnableMouse(true)
	p:EnableMouseWheel(true)
	p:SetScript("OnMouseWheel", function() end)
	Solid(p, "BACKGROUND", 0, 0, 0, 0.25):SetAllPoints()

	local box = CreateFrame("Frame", nil, p)
	p.box = box
	box:SetSize(W, H)
	box:SetPoint("CENTER", 0, 60)
	box:EnableMouse(true)
	Solid(box, "BACKGROUND", 0.077, 0.068, 0.058, 1):SetAllPoints()
	AddBorder(box, 1, 1, 1, 0.15)

	p.title = NewText(box, 15, 1)
	p.title:SetPoint("TOP", 0, -20)
	p.title:SetJustifyH("CENTER")
	p.subtitle = NewText(box, 11, 0.45)
	p.subtitle:SetPoint("TOP", p.title, "BOTTOM", 0, -4)
	p.subtitle:SetJustifyH("CENTER")

	local sf = CreateFrame("ScrollFrame", nil, box)
	sf:SetPoint("TOPLEFT", box, "TOPLEFT", 20, -58)
	sf:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -20, 52)
	sf:EnableMouseWheel(true)
	local inner = Solid(box, "BORDER", 0, 0, 0, 0.25)
	inner:SetPoint("TOPLEFT", sf, "TOPLEFT", -6, 6)
	inner:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", 6, -6)
	local sc = CreateFrame("Frame", nil, sf)
	sc:SetSize(W - 40, 1)
	sf:SetScrollChild(sc)
	local track = Solid(sf, "OVERLAY", 1, 1, 1, 0.02)
	track:SetWidth(4)
	track:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 0, 0)
	track:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", 0, 0)
	local thumb = Solid(sf, "OVERLAY", 1, 1, 1, 0.27)
	thumb:SetWidth(4)

	local edit = CreateFrame("EditBox", nil, sc)
	p.edit = edit
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetFont(FONT, 11, "")
	edit:SetTextColor(1, 1, 1, 0.75)
	edit:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, 0)
	edit:SetWidth(W - 40 - 14)
	edit:SetHeight(1)
	edit:SetScript("OnEscapePressed", function() p:Hide() end)

	p.placeholder = NewText(sc, 11, 0.2)
	p.placeholder:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, 0)
	p.placeholder:SetText("Paste your profile string here...")

	local function UpdateThumb()
		local range = sf:GetVerticalScrollRange()
		if range <= 0 then
			track:Hide()
			thumb:Hide()
			return
		end
		local trackH = sf:GetHeight()
		local thumbH = max(20, trackH * trackH / (trackH + range))
		thumb:SetHeight(thumbH)
		thumb:ClearAllPoints()
		thumb:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 0, -(trackH - thumbH) * sf:GetVerticalScroll() / range)
		track:Show()
		thumb:Show()
	end
	sf:SetScript("OnMouseWheel", function(self, delta)
		local range = self:GetVerticalScrollRange()
		self:SetVerticalScroll(min(range, max(0, self:GetVerticalScroll() - delta * 40)))
		UpdateThumb()
	end)
	sf:SetScript("OnMouseDown", function() edit:SetFocus() end)

	-- 5.4.8 edit boxes have no GetNumLines: estimate the wrapped lines from
	-- the average glyph width of a sample of the text (profile strings
	-- have no spaces, so they wrap anywhere).
	local measure = edit:CreateFontString(nil, "BACKGROUND")
	measure:SetFont(FONT, 11, "")
	measure:SetAlpha(0)
	measure:SetPoint("TOPLEFT")
	local function NumLines()
		if edit.GetNumLines then
			return edit:GetNumLines()
		end
		local text = edit:GetText() or ""
		if text == "" then
			return 1
		end
		local lineW = max(50, edit:GetWidth() - 4)
		local lines = 0
		for part in (text .. "\n"):gmatch("([^\n]*)\n") do
			local sample = part:sub(1, 200)
			local w = 0
			if #sample > 0 then
				measure:SetText(sample)
				w = measure:GetStringWidth() / #sample * #part
			end
			lines = lines + max(1, math.ceil(w / lineW))
		end
		return lines + 1
	end

	local pending
	local function RefreshHeight()
		pending = 2
	end
	p:SetScript("OnUpdate", function()
		if not pending then
			return
		end
		pending = pending - 1
		if pending > 0 then
			return
		end
		pending = nil
		local _, fontH = edit:GetFont()
		local h = NumLines() * (fontH or 11) * 1.2
		local sfH = sf:GetHeight() or 100
		sc:SetHeight(max(sfH, h + 4))
		edit:SetHeight(max(sfH, h + 4))
		sf:UpdateScrollChildRect()
		UpdateThumb()
	end)
	p.RefreshHeight = RefreshHeight

	edit:SetScript("OnTextChanged", function(self, userInput)
		if p.readOnly and userInput then
			self:SetText(p.readOnly)
			self:HighlightText()
		end
		p.placeholder:SetShown(not p.readOnly and (self:GetText() or "") == "")
		RefreshHeight()
	end)
	edit:SetScript("OnMouseUp", function(self)
		self:SetFocus()
		if p.readOnly then
			self:HighlightText()
		end
	end)
	edit:SetScript("OnEditFocusGained", function(self)
		if p.readOnly then
			self:HighlightText()
		end
	end)
	p.absorber = AttachPasteAbsorber(edit)

	p.confirm = CreateFlatButton(box, 120, 26, "Import", true)
	p.confirm:SetPoint("BOTTOMRIGHT", box, "BOTTOM", -4, 14)
	p.cancel = CreateFlatButton(box, 120, 26, "Cancel")
	p.cancel:SetPoint("BOTTOMLEFT", box, "BOTTOM", 4, 14)
	p.close = CreateFlatButton(box, 120, 26, "Close")
	p.close:SetPoint("BOTTOM", box, "BOTTOM", 0, 14)
	p.cancel:SetScript("OnClick", function() p:Hide() end)
	p.close:SetScript("OnClick", function() p:Hide() end)
	p.confirm:SetScript("OnClick", function()
		local str = p.absorber.GetText()
		if str and #str > 0 then
			local fn = p.onConfirm
			p:Hide()
			if fn then
				fn(str)
			end
		end
	end)

	p:SetScript("OnMouseDown", function()
		if not box:IsMouseOver() then
			p:Hide()
		end
	end)
	p:EnableKeyboard(true)
	p:SetScript("OnKeyDown", function(self, key)
		if key == "ESCAPE" then
			self:SetPropagateKeyboardInput(false)
			self:Hide()
		else
			self:SetPropagateKeyboardInput(true)
		end
	end)
	p:SetScript("OnHide", function()
		edit:ClearFocus()
		sf:SetVerticalScroll(0)
	end)
	p:Hide()
end

local function ShowStringPopup(opts)
	if not stringPopup then
		BuildStringPopup()
	end
	local p = stringPopup
	p.title:SetText(opts.title or "")
	p.subtitle:SetText(opts.subtitle or "")
	p.onConfirm = opts.onConfirm
	p.absorber.Reset()
	if opts.editable then
		p.readOnly = nil
		p.edit:SetText("")
		p.confirm.label:SetText(opts.confirmText or "Import")
		p.confirm:Show()
		p.cancel:Show()
		p.close:Hide()
	else
		p.readOnly = opts.text or ""
		p.edit:SetMaxBytes(0)
		p.edit:SetText(p.readOnly)
		p.confirm:Hide()
		p.cancel:Hide()
		p.close:Show()
	end
	p.placeholder:SetShown(opts.editable and true or false)
	p.RefreshHeight()
	p:Show()
	p.edit:SetFocus()
	if p.readOnly then
		p.edit:HighlightText()
	end
end
ns.ShowStringPopup = ShowStringPopup

---------------------------------------------------------------------------
-- Tracked Auras popup (retail EllesmereUI_Widgets_AuraPopups.lua
-- ShowTrackedAurasPopup): INCLUDED / EXCLUDED spell lists, tri-state maps
-- { [spellID] = true (on) | false (off) }. Adding an ID to one list removes
-- it from the other. opts: eyebrow, title, subtitle, includeGet, excludeGet,
-- includePrompt, excludePrompt, onChanged, copyFrom = { label, choices =
-- { {key, label} }, apply(key) }, includeMine = { anyGet } | { mineGet }
-- (anyGet: entries default to your casts, the map holds any-caster opt-outs;
-- mineGet: entries default to any caster, the map holds MINE opt-ins).
-- FULLSCREEN_DIALOG strata so the Add Spell ID input popup (TOOLTIP) is on top.
---------------------------------------------------------------------------
local trackedPopup

local function TrackedSpellInfo(id)
	local name, _, icon = GetSpellInfo(id)
	return name, icon
end

local function BuildTrackedPopup()
	local d = CreateFrame("Button", nil, UIParent)
	trackedPopup = d
	d:SetAllPoints(UIParent)
	d:SetFrameStrata("FULLSCREEN_DIALOG")
	d:SetFrameLevel(20)
	d:EnableMouseWheel(true)
	d:SetScript("OnMouseWheel", function() end)
	Solid(d, "BACKGROUND", 0, 0, 0, 0.35):SetAllPoints()
	d:SetScript("OnClick", function(self) self:Hide() end)

	local p = CreateFrame("Frame", nil, d)
	d.panel = p
	p:SetSize(520, 470)
	p:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	p:SetFrameLevel(d:GetFrameLevel() + 10)
	p:EnableMouse(true)
	Solid(p, "BACKGROUND", 0.077, 0.068, 0.058, 1):SetAllPoints()
	AddBorder(p, 1, 1, 1, 0.15)
	p:EnableKeyboard(true)
	p:SetScript("OnKeyDown", function(self, key)
		self:SetPropagateKeyboardInput(key ~= "ESCAPE")
		if key == "ESCAPE" then
			d:Hide()
		end
	end)

	d.eyebrow = NewText(p, 11, 0.9)
	d.eyebrow:SetPoint("TOP", 0, -16)
	d.eyebrow:SetJustifyH("CENTER")
	AccentText(d.eyebrow, 0.9)
	d.title = NewText(p, 20, 0.95)
	d.title:SetPoint("TOP", 0, -32)
	d.title:SetJustifyH("CENTER")
	d.subtitle = NewText(p, 12, 0.6)
	d.subtitle:SetPoint("TOP", d.title, "BOTTOM", 0, -4)
	d.subtitle:SetWidth(470)
	d.subtitle:SetJustifyH("CENTER")

	local close = CreateFrame("Button", nil, p)
	close:SetSize(19, 19)
	close:SetPoint("TOPRIGHT", -10, -10)
	local ct = close:CreateTexture(nil, "OVERLAY")
	ct:SetAllPoints()
	ct:SetTexture(ns.MEDIA .. "ui\\eui-close")
	close:SetAlpha(0.5)
	close:SetScript("OnEnter", function(self) self:SetAlpha(0.9) end)
	close:SetScript("OnLeave", function(self) self:SetAlpha(0.5) end)
	close:SetScript("OnClick", function() d:Hide() end)

	-- Copy-from band: label, source dropdown, Apply.
	local band = CreateFrame("Frame", nil, p)
	d.band = band
	band:SetHeight(24)
	band.label = NewText(band, 12, 0.85)
	band.label:SetPoint("LEFT", 0, 0)
	band.apply = CreateFlatButton(band, 64, 24, "Apply", true)
	band.apply:SetPoint("RIGHT", 0, 0)
	local dd = CreateFrame("Button", nil, band)
	band.dd = dd
	dd:SetSize(110, 24)
	dd:SetPoint("RIGHT", band.apply, "LEFT", -8, 0)
	Solid(dd, "BACKGROUND", 0.114, 0.106, 0.099, 1):SetAllPoints()
	AddBorder(dd, 0.4, 0.4, 0.4, 0.6)
	dd.text = NewText(dd, 12, 0.8)
	dd.text:SetPoint("LEFT", 8, 0)
	dd.text:SetPoint("RIGHT", -18, 0)
	dd.text:SetWordWrap(false)
	local arrow = dd:CreateTexture(nil, "OVERLAY")
	arrow:SetSize(10, 10)
	arrow:SetPoint("RIGHT", -6, 0)
	arrow:SetTexture(ns.MEDIA .. "icons\\eui-arrow")
	local list = CreateFrame("Frame", nil, p)
	band.list = list
	list:SetFrameLevel(p:GetFrameLevel() + 20)
	list:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 0, -2)
	list:SetWidth(110)
	Solid(list, "BACKGROUND", 0.077, 0.068, 0.058, 0.98):SetAllPoints()
	AddBorder(list, 1, 1, 1, 0.15)
	list.rows = {}
	list:Hide()
	dd:SetScript("OnClick", function() list:SetShown(not list:IsShown()) end)

	d.vdiv = Solid(p, "ARTWORK", 1, 1, 1, 0.08)
	d.vdiv:SetWidth(1)
	d.hdiv = Solid(p, "ARTWORK", 1, 1, 1, 0.08)
	d.hdiv:SetHeight(1)

	local COL_W = 228
	local function Column(x, colTitle)
		local col = { rows = {} }
		col.title = NewText(p, 11, 0.45)
		col.title:SetText(colTitle)
		col.add = CreateFlatButton(p, 96, 24, "Add Spell ID", true)
		col.scroll = CreateFrame("ScrollFrame", nil, p)
		col.child = CreateFrame("Frame", nil, col.scroll)
		col.child:SetSize(COL_W, 1)
		col.scroll:SetScrollChild(col.child)
		col.scroll:EnableMouseWheel(true)
		col.scroll:SetScript("OnMouseWheel", function(self, delta)
			local maxS = max(0, col.child:GetHeight() - self:GetHeight())
			self:SetVerticalScroll(min(maxS, max(0, self:GetVerticalScroll() - delta * 30)))
		end)
		col.x = x
		function col:Place(secY)
			self.title:ClearAllPoints()
			self.title:SetPoint("TOPLEFT", p, "TOPLEFT", x, secY - 16)
			self.add:ClearAllPoints()
			self.add:SetPoint("TOPRIGHT", p, "TOPLEFT", x + COL_W, secY - 8)
			self.scroll:ClearAllPoints()
			self.scroll:SetPoint("TOPLEFT", p, "TOPLEFT", x, secY - 44)
			self.scroll:SetPoint("BOTTOMRIGHT", p, "BOTTOMLEFT", x + COL_W, 62)
		end
		function col:Row(i)
			local row = self.rows[i]
			if row then
				return row
			end
			row = CreateFrame("Button", nil, self.child)
			row:SetSize(COL_W, 28)
			row:SetPoint("TOPLEFT", self.child, "TOPLEFT", 0, -(i - 1) * 29)
			row.hl = Solid(row, "BACKGROUND", 1, 1, 1, 0)
			row.hl:SetAllPoints()
			row.box = CreateFrame("Frame", nil, row)
			row.box:SetSize(16, 16)
			row.box:SetPoint("LEFT", 2, 0)
			Solid(row.box, "BACKGROUND", 0.114, 0.106, 0.099, 1):SetAllPoints()
			row.boxBorder = AddBorder(row.box, 0.4, 0.4, 0.4, 0.6)
			row.chk = Solid(row.box, "ARTWORK", ACCENT[1], ACCENT[2], ACCENT[3], 1)
			row.chk:SetPoint("TOPLEFT", 3, -3)
			row.chk:SetPoint("BOTTOMRIGHT", -3, 3)
			row.icon = row:CreateTexture(nil, "ARTWORK")
			row.icon:SetSize(20, 20)
			row.icon:SetPoint("LEFT", row.box, "RIGHT", 6, 0)
			row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			row.x = CreateFrame("Button", nil, row)
			row.x:SetSize(14, 14)
			row.x:SetPoint("RIGHT", -4, 0)
			row.x:SetFrameLevel(row:GetFrameLevel() + 2)
			local xt = row.x:CreateTexture(nil, "OVERLAY")
			xt:SetAllPoints()
			xt:SetTexture(ns.MEDIA .. "ui\\eui-close")
			row.x:SetAlpha(0.5)
			row.x:SetScript("OnEnter", function(self)
				self:SetAlpha(0.9)
				ShowTip(self, "Remove")
			end)
			row.x:SetScript("OnLeave", function(self)
				self:SetAlpha(0.5)
				HideTip()
			end)
			row.mine = CreateFrame("Button", nil, row)
			row.mine:SetSize(30, 16)
			row.mine:SetPoint("RIGHT", row.x, "LEFT", -2, 0)
			row.mine:SetFrameLevel(row:GetFrameLevel() + 2)
			row.mine.text = NewText(row.mine, 11, 1)
			row.mine.text:SetPoint("CENTER")
			row.mine.text:SetText("MINE")
			row.name = NewText(row, 13, 0.9)
			row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
			row.name:SetWordWrap(false)
			row:SetScript("OnEnter", function(self) self.hl:SetTexture(1, 1, 1, 0.04) end)
			row:SetScript("OnLeave", function(self) self.hl:SetTexture(1, 1, 1, 0) end)
			self.rows[i] = row
			return row
		end
		return col
	end
	d.inc = Column(24, "INCLUDED DEBUFFS")
	d.exc = Column(268, "EXCLUDED DEBUFFS")

	d.done = CreateFlatButton(p, 150, 32, "Done", true)
	d.done:SetPoint("BOTTOM", 0, 14)
	d.done:SetScript("OnClick", function() d:Hide() end)
	d:Hide()
end

local function ShowTrackedAurasPopup(opts)
	if not trackedPopup then
		BuildTrackedPopup()
	end
	local d, p = trackedPopup, trackedPopup.panel
	d.opts = opts
	d.eyebrow:SetText(opts.eyebrow or "TRACKED AURAS")
	d.title:SetText(opts.title or "Tracked Auras")
	local hdrY = 0
	if opts.subtitle then
		d.subtitle:SetText(opts.subtitle)
		d.subtitle:Show()
		hdrY = 18
	else
		d.subtitle:Hide()
	end
	p:SetHeight(470 + hdrY)

	local band = d.band
	local cf = opts.copyFrom
	band.list:Hide()
	if cf then
		band:ClearAllPoints()
		band:SetPoint("TOPLEFT", p, "TOPLEFT", 24, -68 - hdrY)
		band:SetPoint("TOPRIGHT", p, "TOPRIGHT", -24, -68 - hdrY)
		band.label:SetText(cf.label or "Copy From:")
		band.dd.text:SetText("Select...")
		band.dd.text:SetTextColor(1, 1, 1, 0.8)
		band.chosen = nil
		for i, choice in ipairs(cf.choices) do
			local row = band.list.rows[i]
			if not row then
				row = CreateFrame("Button", nil, band.list)
				row:SetHeight(22)
				row:SetPoint("TOPLEFT", 1, -4 - (i - 1) * 22)
				row:SetPoint("TOPRIGHT", -1, -4 - (i - 1) * 22)
				row.hl = Solid(row, "BACKGROUND", 1, 1, 1, 0)
				row.hl:SetAllPoints()
				row.text = NewText(row, 12, 0.85)
				row.text:SetPoint("LEFT", 8, 0)
				row:SetScript("OnEnter", function(self) self.hl:SetTexture(1, 1, 1, 0.06) end)
				row:SetScript("OnLeave", function(self) self.hl:SetTexture(1, 1, 1, 0) end)
				band.list.rows[i] = row
			end
			row.text:SetText(choice.label)
			row:SetScript("OnClick", function()
				band.chosen = choice.key
				band.dd.text:SetText(choice.label)
				band.dd.text:SetTextColor(1, 1, 1, 1)
				band.list:Hide()
			end)
			row:Show()
		end
		for i = #cf.choices + 1, #band.list.rows do
			band.list.rows[i]:Hide()
		end
		band.list:SetHeight(#cf.choices * 22 + 8)
		band:Show()
	else
		band:Hide()
	end

	local secY = (cf and -104 or -68) - hdrY
	d.hdiv:ClearAllPoints()
	d.hdiv:SetPoint("TOPLEFT", p, "TOPLEFT", 20, secY)
	d.hdiv:SetPoint("TOPRIGHT", p, "TOPRIGHT", -20, secY)
	d.vdiv:ClearAllPoints()
	d.vdiv:SetPoint("TOP", p, "TOP", 0, secY - 8)
	d.vdiv:SetPoint("BOTTOM", p, "BOTTOM", 0, 62)
	d.inc:Place(secY)
	d.exc:Place(secY)

	local function Changed()
		if opts.onChanged then
			opts.onChanged()
		end
	end
	local withMine = opts.includeMine
	local function ScopeMap()
		if not withMine then
			return nil
		end
		if withMine.mineGet then
			return withMine.mineGet()
		end
		return withMine.anyGet and withMine.anyGet()
	end
	local function MineOn(id)
		local map = ScopeMap()
		if withMine.mineGet then
			return map ~= nil and map[id] == true
		end
		return not (map and map[id])
	end

	local RefreshBoth
	local function Fill(col, listFn, otherFn, mine)
		for _, row in ipairs(col.rows) do
			row:Hide()
		end
		local list = listFn() or {}
		local sorted = {}
		for id, v in pairs(list) do
			local name, icon = TrackedSpellInfo(id)
			sorted[#sorted + 1] = { id = id, on = v == true, name = name or tostring(id), icon = icon }
		end
		table.sort(sorted, function(a, b) return a.name < b.name end)
		for i, e in ipairs(sorted) do
			local row = col:Row(i)
			row.icon:SetTexture(e.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
			row.name:SetText(e.name .. " |cff808080(" .. e.id .. ")|r")
			row.name:SetPoint("RIGHT", row, "RIGHT", mine and -52 or -24, 0)
			row.chk:SetTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
			row.chk:SetShown(e.on)
			if e.on then
				row.boxBorder:SetColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.8)
			else
				row.boxBorder:SetColor(0.4, 0.4, 0.4, 0.6)
			end
			row.icon:SetDesaturated(not e.on)
			row.icon:SetAlpha(e.on and 1 or 0.45)
			row.name:SetAlpha(e.on and 0.9 or 0.45)
			if mine then
				row.mine:Show()
				if MineOn(e.id) then
					row.mine.text:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3], e.on and 1 or 0.45)
				else
					row.mine.text:SetTextColor(0.6, 0.6, 0.6, e.on and 0.4 or 0.25)
				end
				row.mine:SetScript("OnClick", function()
					local map = ScopeMap()
					if map then
						map[e.id] = (not map[e.id]) or nil
					end
					Changed()
					RefreshBoth()
				end)
				row.mine:SetScript("OnEnter", function(self)
					ShowTip(self, MineOn(e.id) and "Showing this aura from your casts only; click for any caster."
						or "Showing this aura from any caster; click for your casts only.")
				end)
				row.mine:SetScript("OnLeave", HideTip)
			else
				row.mine:Hide()
			end
			row:SetScript("OnClick", function()
				local l2 = listFn()
				if l2 then
					l2[e.id] = not (l2[e.id] == true)
					Changed()
					RefreshBoth()
				end
			end)
			row.x:SetScript("OnClick", function()
				local l2 = listFn()
				if l2 then
					l2[e.id] = nil
				end
				if mine then
					local map = ScopeMap()
					if map then
						map[e.id] = nil
					end
				end
				Changed()
				RefreshBoth()
			end)
			row:Show()
		end
		col.child:SetHeight(max(1, #sorted * 29))
		col.add:SetScript("OnClick", function()
			ShowInputPopup({
				title = "Add Spell ID",
				message = col == d.inc and (opts.includePrompt or "Enter the spell ID to always show.")
					or (opts.excludePrompt or "Enter the spell ID to exclude."),
				text = "",
				confirmText = "Add",
				cancelText = "Cancel",
				onConfirm = function(text)
					local id = tonumber(text or "")
					local l2 = id and id > 0 and listFn()
					if l2 then
						local other = otherFn()
						if other then
							other[id] = nil
						end
						l2[id] = true
						Changed()
						if d:IsShown() and d.opts == opts then
							RefreshBoth()
						end
					end
				end,
			})
		end)
	end
	RefreshBoth = function()
		Fill(d.inc, opts.includeGet, opts.excludeGet, withMine)
		Fill(d.exc, opts.excludeGet, opts.includeGet, nil)
	end
	if cf then
		band.apply:SetScript("OnClick", function()
			if band.chosen then
				cf.apply(band.chosen)
				RefreshBoth()
			end
		end)
	end
	d.inc.scroll:SetVerticalScroll(0)
	d.exc.scroll:SetVerticalScroll(0)
	RefreshBoth()
	d:Show()
end
ns.ShowTrackedAurasPopup = ShowTrackedAurasPopup

---------------------------------------------------------------------------
-- Dropdown menu (one shared menu for all dropdowns)
---------------------------------------------------------------------------
local menu, menuCatcher

local function CloseMenu()
	if menu then
		menu:Hide()
		menu.owner = nil
	end
	if menuCatcher then
		menuCatcher:Hide()
	end
end

local function UpdateMenu()
	local owner = menu.owner
	if not owner then
		return
	end
	local items = menu.items
	local current = owner.getValue()
	for i = 1, MENU_MAX_ITEMS do
		local button = menu.buttons[i]
		local item = items[menu.offset + i]
		if item then
			button.item = item
			button.text:SetText(item.name)
			if owner.fontPreview then
				SetFont(button.text, 13, owner.fontPath and owner.fontPath(item.value) or item.value)
			else
				SetFont(button.text, 13)
			end
			if owner.texturePreview then
				button.preview:SetTexture(owner.previewPath and owner.previewPath(item.value) or item.value)
				button.preview:SetVertexColor(1, 1, 1, 0.45)
				button.preview:Show()
			else
				button.preview:Hide()
			end
			local selected
			if owner.multi then
				-- Multi-select: checkbox on the left, the menu stays open.
				local checked = owner.isChecked(item.value) and true or false
				button.box:Show()
				button.check:SetShown(checked)
				if checked then
					button.boxBorder:SetColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.6)
				else
					button.boxBorder:SetColor(1, 1, 1, 0.15)
				end
				button.text:ClearAllPoints()
				button.text:SetPoint("LEFT", 34, 0)
				button.text:SetPoint("RIGHT", -10, 0)
				button.baseColor = checked and { 1, 1, 1, 1 } or { 1, 1, 1, 0.53 }
				selected = false
			else
				button.box:Hide()
				button.text:ClearAllPoints()
				button.text:SetPoint("LEFT", 10, 0)
				button.text:SetPoint("RIGHT", -10, 0)
				selected = item.value == current
				button.baseColor = selected and { ACCENT[1], ACCENT[2], ACCENT[3], 1 } or { 1, 1, 1, 0.53 }
			end
			-- item.separator: a thin line ("---" in EllesmereUI lists).
			-- item.locked (fn): dimmed and not clickable, item.lockedTip explains.
			-- item.header: a gray caption row (item.rightLabel on the right).
			-- item.action (fn): a pinned action row (accent text, closes the menu).
			-- item.twoLane (multi menus with owner.isHidden): a red "Hide" box on
			-- the right (EllesmereUI two-lane filter rows); item.showLocked (fn)
			-- dims the left box and blocks it (item.showLockedTip explains).
			button.locked = item.locked and item.locked() or false
			button.line:SetShown(item.separator and true or false)
			button.text:SetShown(not item.separator)
			button.rightText:Hide()
			button.hideBox:Hide()
			button.showLocked = nil
			if item.separator then
				button.box:Hide()
				selected = false
			elseif item.header then
				button.box:Hide()
				button.text:ClearAllPoints()
				button.text:SetPoint("LEFT", 10, 0)
				button.text:SetPoint("RIGHT", -10, 0)
				SetFont(button.text, 11)
				button.baseColor = { 1, 1, 1, 0.35 }
				if item.rightLabel then
					button.rightText:SetText(item.rightLabel)
					button.rightText:Show()
				end
				selected = false
			elseif item.action then
				button.box:Hide()
				button.text:ClearAllPoints()
				button.text:SetPoint("LEFT", 10, 0)
				button.text:SetPoint("RIGHT", -10, 0)
				button.baseColor = { ACCENT[1], ACCENT[2], ACCENT[3], 0.9 }
				selected = false
			elseif owner.multi then
				if item.twoLane and owner.isHidden then
					local hidden = owner.isHidden(item.value) and true or false
					button.hideBox:Show()
					button.hideCheck:SetShown(hidden)
					button.hideBorder:SetColor(0.9, 0.2, 0.2, hidden and 0.8 or 0.35)
					button.text:SetPoint("RIGHT", -34, 0)
					if hidden then
						button.baseColor = { 1, 1, 1, 0.53 }
					end
				end
				button.showLocked = item.showLocked and item.showLocked() or nil
				if button.showLocked then
					button.box:SetAlpha(0.3)
				else
					button.box:SetAlpha(1)
				end
			end
			button:SetAlpha(button.locked and 0.35 or 1)
			button.selected:SetShown(selected)
			button.mark:SetShown(selected)
			button.text:SetTextColor(unpack(button.baseColor))
			button:Show()
		else
			button.item = nil
			button:Hide()
		end
	end
	local total = #items
	if total > MENU_MAX_ITEMS then
		local trackH = menu:GetHeight() - 4
		local thumbH = max(20, trackH * MENU_MAX_ITEMS / total)
		local pos = (trackH - thumbH) * menu.offset / (total - MENU_MAX_ITEMS)
		menu.thumb:SetHeight(thumbH)
		menu.thumb:ClearAllPoints()
		menu.thumb:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -2, -2 - pos)
		menu.thumb:Show()
	else
		menu.thumb:Hide()
	end
end

local function ScrollMenu(delta)
	local maxOffset = max(0, #menu.items - MENU_MAX_ITEMS)
	menu.offset = min(maxOffset, max(0, menu.offset - delta * 3))
	UpdateMenu()
end

local function BuildMenu()
	menuCatcher = CreateFrame("Button", nil, UIParent)
	menuCatcher:SetAllPoints(UIParent)
	menuCatcher:SetFrameStrata("FULLSCREEN_DIALOG")
	menuCatcher:SetFrameLevel(1)
	menuCatcher:RegisterForClicks("AnyUp")
	menuCatcher:SetScript("OnClick", CloseMenu)
	menuCatcher:Hide()

	menu = CreateFrame("Frame", nil, UIParent)
	menu:SetFrameStrata("FULLSCREEN_DIALOG")
	menu:SetFrameLevel(10)
	menu:EnableMouse(true)
	menu:EnableMouseWheel(true)
	menu:SetScript("OnMouseWheel", function(_, delta) ScrollMenu(delta) end)
	Solid(menu, "BACKGROUND", DROPDOWN_BG[1], DROPDOWN_BG[2], DROPDOWN_BG[3], 0.98):SetAllPoints()
	AddBorder(menu, 1, 1, 1, 0.2)
	menu.thumb = AccentSolid(menu, "OVERLAY", 0.5)
	menu.thumb:SetWidth(3)
	menu.buttons = {}
	menu.offset = 0
	menu.items = {}

	for i = 1, MENU_MAX_ITEMS do
		local button = CreateFrame("Button", nil, menu)
		button:SetHeight(MENU_ITEM_H)
		button:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, -1 - (i - 1) * MENU_ITEM_H)
		button:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -6, -1 - (i - 1) * MENU_ITEM_H)
		button.selected = Solid(button, "BACKGROUND", 1, 1, 1, 0.04)
		button.selected:SetAllPoints()
		button.hover = Solid(button, "ARTWORK", 1, 1, 1, 0.08)
		button.hover:SetAllPoints()
		button.hover:Hide()
		button.mark = AccentSolid(button, "ARTWORK", 1)
		button.mark:SetPoint("TOPLEFT")
		button.mark:SetPoint("BOTTOMLEFT")
		button.mark:SetWidth(2)
		button.preview = button:CreateTexture(nil, "BORDER")
		button.preview:SetPoint("TOPLEFT", 4, -2)
		button.preview:SetPoint("BOTTOMRIGHT", -4, 2)
		-- Checkbox for multi-select menus (EllesmereUI style: dark box, green square when checked).
		button.box = CreateFrame("Frame", nil, button)
		button.box:SetSize(16, 16)
		button.box:SetPoint("LEFT", 10, 0)
		Solid(button.box, "BACKGROUND", 0.114, 0.106, 0.099, 1):SetAllPoints()
		button.boxBorder = AddBorder(button.box, 1, 1, 1, 0.15)
		button.check = AccentSolid(button.box, "ARTWORK", 1)
		button.check:SetPoint("TOPLEFT", 2, -2)
		button.check:SetPoint("BOTTOMRIGHT", -2, 2)
		button.box:Hide()
		button.text = NewText(button, 13, 0.53)
		button.text:SetPoint("LEFT", 10, 0)
		button.text:SetPoint("RIGHT", -10, 0)
		button.text:SetShadowOffset(1, -1)
		button.text:SetShadowColor(0, 0, 0, 1)
		button.text:SetWordWrap(false)
		button.baseColor = { 1, 1, 1, 0.53 }
		button.line = Solid(button, "ARTWORK", 1, 1, 1, 0.12)
		button.line:SetHeight(1)
		button.line:SetPoint("LEFT", 8, 0)
		button.line:SetPoint("RIGHT", -8, 0)
		button.line:Hide()
		button.rightText = NewText(button, 11, 0.35)
		button.rightText:SetPoint("RIGHT", -10, 0)
		button.rightText:Hide()
		-- Red "Hide" lane box (two-lane filter rows).
		button.hideBox = CreateFrame("Button", nil, button)
		button.hideBox:SetSize(16, 16)
		button.hideBox:SetPoint("RIGHT", -10, 0)
		Solid(button.hideBox, "BACKGROUND", 0.114, 0.106, 0.099, 1):SetAllPoints()
		button.hideBorder = AddBorder(button.hideBox, 0.9, 0.2, 0.2, 0.35)
		button.hideCheck = Solid(button.hideBox, "ARTWORK", 0.9, 0.2, 0.2, 1)
		button.hideCheck:SetPoint("TOPLEFT", 2, -2)
		button.hideCheck:SetPoint("BOTTOMRIGHT", -2, 2)
		button.hideBox:Hide()
		button.hideBox:SetScript("OnEnter", function(self)
			local item = self:GetParent().item
			ShowTip(self, item and item.hideTip or "Hide")
		end)
		button.hideBox:SetScript("OnLeave", HideTip)
		button.hideBox:SetScript("OnClick", function(self)
			local parent = self:GetParent()
			local owner = menu.owner
			if not owner or not parent.item or not owner.toggleHidden then
				return
			end
			owner.toggleHidden(parent.item.value)
			ApplyAndRefresh()
			UpdateMenu()
		end)
		button.hideBox:EnableMouseWheel(true)
		button.hideBox:SetScript("OnMouseWheel", function(_, delta) ScrollMenu(delta) end)
		button:SetScript("OnEnter", function(self)
			if self.item and (self.item.separator or self.item.header) then
				return
			end
			if self.showLocked then
				self.hover:Show()
				ShowTip(self, self.item and self.item.showLockedTip)
				return
			end
			if self.locked then
				ShowTip(self, self.item and self.item.lockedTip)
				return
			end
			self.hover:Show()
			if not self.mark:IsShown() then
				self.text:SetTextColor(1, 1, 1, 1)
			end
			if self.item and self.item.tip then
				ShowTip(self, self.item.tip)
			end
		end)
		button:SetScript("OnLeave", function(self)
			self.hover:Hide()
			self.text:SetTextColor(unpack(self.baseColor))
			HideTip()
		end)
		button:SetScript("OnClick", function(self)
			local owner = menu.owner
			if not owner or not self.item or self.item.separator or self.item.header or self.locked then
				return
			end
			if self.item.action then
				CloseMenu()
				self.item.action()
				return
			end
			if owner.multi then
				if self.showLocked then
					return
				end
				owner.toggle(self.item.value)
				ApplyAndRefresh()
				UpdateMenu()
				if self:IsMouseOver() then
					self.text:SetTextColor(1, 1, 1, 1)
				end
				return
			end
			owner.setValue(self.item.value)
			CloseMenu()
			ApplyAndRefresh()
		end)
		button:EnableMouseWheel(true)
		button:SetScript("OnMouseWheel", function(_, delta) ScrollMenu(delta) end)
		menu.buttons[i] = button
	end
	menu:Hide()
end

local function OpenMenu(owner)
	if not menu then
		BuildMenu()
	end
	local items = owner.getItems()
	menu.owner = owner
	menu.items = items
	local current = owner.getValue()
	local currentIndex = 1
	for i = 1, #items do
		if items[i].value == current then
			currentIndex = i
			break
		end
	end
	menu.offset = min(max(0, #items - MENU_MAX_ITEMS), max(0, currentIndex - floor(MENU_MAX_ITEMS / 2)))

	local visible = min(#items, MENU_MAX_ITEMS)
	local height = visible * MENU_ITEM_H + 2
	menu:SetSize(owner:GetWidth(), height)
	menu:ClearAllPoints()
	local bottom = owner:GetBottom() or 0
	if bottom * owner:GetEffectiveScale() / UIParent:GetEffectiveScale() - height < 20 then
		menu:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, 2)
	else
		menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
	end
	menuCatcher:Show()
	menu:Show()
	UpdateMenu()
end

---------------------------------------------------------------------------
-- Controls
---------------------------------------------------------------------------
local function CreateToggle(row, getValue, setValue)
	local toggle = CreateFrame("Button", nil, row)
	toggle:SetSize(40, 20)
	toggle:SetPoint("RIGHT", row, "RIGHT", -20, 0)
	toggle.track = toggle:CreateTexture(nil, "BACKGROUND")
	toggle.track:SetAllPoints()
	toggle.knob = toggle:CreateTexture(nil, "ARTWORK")
	toggle.knob:SetSize(16, 16)
	toggle.progress = getValue() and 1 or 0
	toggle.target = toggle.progress

	local function Draw(p)
		toggle.track:SetTexture(
			0.267 + (ACCENT[1] - 0.267) * p,
			0.267 + (ACCENT[2] - 0.267) * p,
			0.267 + (ACCENT[3] - 0.267) * p,
			0.65 + 0.10 * p)
		toggle.knob:SetTexture(1, 1, 1, 0.5 + 0.5 * p)
		toggle.knob:ClearAllPoints()
		toggle.knob:SetPoint("LEFT", toggle, "LEFT", 2 + 20 * p, 0)
	end

	local function Animate(self, elapsed)
		local step = elapsed / 0.075
		if self.progress < self.target then
			self.progress = min(self.target, self.progress + step)
		else
			self.progress = max(self.target, self.progress - step)
		end
		Draw(self.progress)
		if self.progress == self.target then
			self:SetScript("OnUpdate", nil)
		end
	end

	function toggle:Refresh()
		local target = getValue() and 1 or 0
		if target ~= self.target then
			self.target = target
			self:SetScript("OnUpdate", Animate)
		end
	end

	toggle:SetScript("OnClick", function(self)
		if row.disabled then
			return
		end
		setValue(not getValue())
		ApplyAndRefresh()
	end)
	toggle:SetScript("OnEnter", function() row:SetHover(true) end)
	toggle:SetScript("OnLeave", function() row:SetHover(false) end)
	ForwardWheel(toggle)

	-- Clicking anywhere on the row flips the toggle too.
	row:SetScript("OnMouseUp", function(_, button)
		if button == "LeftButton" then
			toggle:Click()
		end
	end)

	Draw(toggle.progress)
	return toggle
end

local function CreateSlider(row, minValue, maxValue, step, getValue, setValue)
	local box = CreateFrame("EditBox", nil, row)
	box:SetSize(40, 26)
	box:SetPoint("RIGHT", row, "RIGHT", -20, 0)
	box:SetAutoFocus(false)
	box:SetJustifyH("CENTER")
	box:SetFont(FONT, 13, "")
	if not box:GetFont() then
		box:SetFont(FONT_FALLBACK, 13, "")
	end
	box:SetTextColor(1, 1, 1, 0.53)
	box:SetMaxLetters(5)
	Solid(box, "BACKGROUND", 0.030, 0.023, 0.018, 0.40):SetAllPoints()
	AddBorder(box, 1, 1, 1, 0.02)

	local slider = CreateFrame("Frame", nil, row)
	slider:SetSize(SLIDER_W, 20)
	slider:SetPoint("RIGHT", box, "LEFT", -12, 0)
	slider:EnableMouse(true)
	local track = Solid(slider, "BACKGROUND", 1, 1, 1, 0.16)
	track:SetHeight(4)
	track:SetPoint("LEFT")
	track:SetPoint("RIGHT")
	local fill = AccentSolid(slider, "BORDER", 0.75)
	fill:SetHeight(4)
	fill:SetPoint("LEFT")
	local blocker = Solid(slider, "ARTWORK", PANEL_BG[1], PANEL_BG[2], PANEL_BG[3], 1)
	blocker:SetSize(16, 16)
	local thumb = AccentSolid(slider, "OVERLAY", 1)
	thumb:SetSize(14, 14)

	local function Place(value)
		local pct = (value - minValue) / (maxValue - minValue)
		pct = min(1, max(0, pct))
		local x = 7 + (slider:GetWidth() - 14) * pct
		fill:SetWidth(max(1, x))
		thumb:ClearAllPoints()
		thumb:SetPoint("CENTER", slider, "LEFT", x, 0)
		blocker:ClearAllPoints()
		blocker:SetPoint("CENTER", slider, "LEFT", x, 0)
		if not box:HasFocus() then
			box:SetText(tostring(value))
		end
	end

	local function SetFromNumber(value)
		value = minValue + floor((value - minValue) / step + 0.5) * step
		value = min(maxValue, max(minValue, value))
		if value ~= getValue() then
			setValue(value)
			ApplyAndRefreshLive()
		end
		Place(getValue())
	end

	local function SetFromCursor()
		local cursorX = GetCursorPosition() / slider:GetEffectiveScale()
		local left = slider:GetLeft() or 0
		local pct = (cursorX - left - 7) / (slider:GetWidth() - 14)
		SetFromNumber(minValue + pct * (maxValue - minValue))
	end

	slider:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" and not row.disabled then
			self.dragging = true
			SetFromCursor()
		end
	end)
	slider:SetScript("OnMouseUp", function(self)
		self.dragging = false
	end)
	slider:SetScript("OnUpdate", function(self)
		if self.dragging then
			if IsMouseButtonDown("LeftButton") then
				SetFromCursor()
			else
				self.dragging = false
			end
		end
	end)
	slider:SetScript("OnEnter", function() row:SetHover(true) end)
	slider:SetScript("OnLeave", function() row:SetHover(false) end)
	ForwardWheel(slider)

	box:SetScript("OnEditFocusGained", function(self)
		self:SetTextColor(1, 1, 1, 1)
		self:HighlightText()
	end)
	box:SetScript("OnEditFocusLost", function(self)
		self:SetTextColor(1, 1, 1, 0.53)
		self:HighlightText(0, 0)
		Place(getValue())
	end)
	box:SetScript("OnEnterPressed", function(self)
		local number = tonumber(self:GetText())
		self:ClearFocus()
		if number and not row.disabled then
			SetFromNumber(number)
		end
	end)
	box:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	box:SetScript("OnEnter", function() row:SetHover(true) end)
	box:SetScript("OnLeave", function() row:SetHover(false) end)

	local control = { Refresh = function() Place(getValue()) end }
	Place(getValue())
	return control
end

local function CreateDropdown(row, getItems, getValue, getLabel, setValue, options)
	local drop = CreateFrame("Button", nil, row)
	drop:SetSize(CONTROL_W, CONTROL_H)
	drop:SetPoint("RIGHT", row, "RIGHT", -20, 0)
	drop.bg = Solid(drop, "BACKGROUND", DROPDOWN_BG[1], DROPDOWN_BG[2], DROPDOWN_BG[3], 0.9)
	drop.bg:SetAllPoints()
	drop.border = AddBorder(drop, 1, 1, 1, 0.2)
	drop.preview = drop:CreateTexture(nil, "ARTWORK")
	drop.preview:SetPoint("TOPLEFT", 2, -2)
	drop.preview:SetPoint("BOTTOMRIGHT", -2, 2)
	drop.preview:SetVertexColor(1, 1, 1, 0.35)
	drop.preview:Hide()
	drop.text = NewText(drop, 13, 0.5)
	drop.text:SetShadowOffset(1, -1)
	drop.text:SetShadowColor(0, 0, 0, 1)
	drop.text:SetPoint("LEFT", 12, 0)
	drop.text:SetPoint("RIGHT", -30, 0)
	drop.text:SetWordWrap(false)
	drop.arrow = drop:CreateTexture(nil, "ARTWORK")
	-- EllesmereUI icons\eui-arrow.png (30 x 30 in a 32 x 32 TGA).
	drop.arrow:SetTexture(ART_PATH .. "eui-arrow")
	drop.arrow:SetTexCoord(0, 30 / 32, 0, 30 / 32)
	drop.arrow:SetSize(26, 26)
	drop.arrow:SetPoint("CENTER", drop, "RIGHT", -17, 0)
	drop.arrow:SetVertexColor(1, 1, 1, 0.6)

	drop.getItems = getItems
	drop.getValue = getValue
	drop.setValue = setValue
	drop.fontPreview = options and options.fontPreview
	drop.fontPath = options and options.fontPath
	drop.texturePreview = options and options.texturePreview
	drop.previewPath = options and options.previewPath
	drop.multi = options and options.multi
	drop.isChecked = options and options.isChecked
	drop.toggle = options and options.toggle
	drop.isHidden = options and options.isHidden
	drop.toggleHidden = options and options.toggleHidden

	local function SetVisual(hover)
		drop.bg:SetTexture(DROPDOWN_BG[1], DROPDOWN_BG[2], DROPDOWN_BG[3], hover and 0.98 or 0.9)
		drop.border:SetColor(1, 1, 1, hover and 0.3 or 0.2)
		drop.text:SetTextColor(1, 1, 1, hover and 0.6 or 0.5)
	end

	drop:SetScript("OnClick", function(self)
		if row.disabled then
			return
		end
		if menu and menu.owner == self and menu:IsShown() then
			CloseMenu()
		else
			OpenMenu(self)
		end
	end)
	drop:SetScript("OnEnter", function()
		SetVisual(true)
		row:SetHover(true)
	end)
	drop:SetScript("OnLeave", function()
		SetVisual(false)
		row:SetHover(false)
	end)
	ForwardWheel(drop)

	function drop:Refresh()
		self.text:SetText(getLabel())
		if self.fontPreview then
			SetFont(self.text, 13, self.fontPath and self.fontPath(getValue()) or getValue())
		end
		if self.texturePreview then
			self.preview:SetTexture(self.previewPath and self.previewPath(getValue()) or getValue())
			self.preview:SetVertexColor(1, 1, 1, 0.35)
			self.preview:Show()
		end
	end
	drop:Refresh()
	return drop
end

-- Color access for a swatch. colorKey: a key of the Interrupt Tracker colors (string),
-- a function that returns the color table to edit ({ r, g, b } as [1]..[3] or
-- .r .g .b, optional alpha [4] / .a), or a { get = fn, set = fn } pair where
-- get returns r, g, b, a and set takes r, g, b, a.
local function ColorAccess(colorKey)
	if type(colorKey) == "table" and colorKey.get then
		return colorKey.get, colorKey.set
	end
	local function Table()
		if type(colorKey) == "function" then
			return colorKey()
		end
		return ns.GetInterruptDB().colors[colorKey]
	end
	local function Get()
		local c = Table()
		if c.r ~= nil then
			return c.r, c.g, c.b, c.a
		end
		return c[1], c[2], c[3], c[4]
	end
	local function Set(r, g, b, a)
		local c = Table()
		if c.r ~= nil or c[1] == nil then
			c.r, c.g, c.b = r, g, b
			if a ~= nil and c.a ~= nil then
				c.a = a
			end
		else
			c[1], c[2], c[3] = r, g, b
			if a ~= nil and c[4] ~= nil then
				c[4] = a
			end
		end
	end
	return Get, Set
end

---------------------------------------------------------------------------
-- Color picker popup (EllesmereUI_Widgets_Color.lua, replaces Blizzard's
-- ColorPickerFrame): saturation/value square, hue bar, alpha bar, New / Prev
-- previews, Hex# and Opacity boxes, Cancel / OK, Favorites and Recent Colors.
-- 5.4.8: SetTexture(r, g, b, a) + SetGradientAlpha in place of
-- SetColorTexture / CreateColor, and an OnUpdate in place of
-- GLOBAL_MOUSE_DOWN + C_Timer for the click-off close.
---------------------------------------------------------------------------
local WHITE = "Interface\\Buttons\\WHITE8X8"
local PICKER_MAX_SWATCHES = 10

local function HSVtoRGB(h, s, v)
	local c = v * s
	local x = c * (1 - abs((h / 60) % 2 - 1))
	local m = v - c
	local r, g, b
	if h < 60 then r, g, b = c, x, 0
	elseif h < 120 then r, g, b = x, c, 0
	elseif h < 180 then r, g, b = 0, c, x
	elseif h < 240 then r, g, b = 0, x, c
	elseif h < 300 then r, g, b = x, 0, c
	else r, g, b = c, 0, x
	end
	return r + m, g + m, b + m
end

local function RGBtoHSV(r, g, b)
	local mx, mn = max(r, g, b), min(r, g, b)
	local d = mx - mn
	local h
	local s = (mx == 0) and 0 or (d / mx)
	if d == 0 then
		h = 0
	elseif mx == r then
		h = 60 * (((g - b) / d) % 6)
	elseif mx == g then
		h = 60 * (((b - r) / d) + 2)
	else
		h = 60 * (((r - g) / d) + 4)
	end
	return h, s, mx
end

-- Recent colors and favorites, saved in EllesmereUIDB.colorPicker (like retail).
local function PickerDB()
	if type(EllesmereUIDB) ~= "table" then
		EllesmereUIDB = {}
	end
	local db = EllesmereUIDB.colorPicker
	if type(db) ~= "table" then
		db = {}
		EllesmereUIDB.colorPicker = db
	end
	db.recentColors = db.recentColors or {}
	db.favorites = db.favorites or {}
	return db
end

local function ColorKey(r, g, b)
	return format("%d-%d-%d", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

local function RecordRecentColor(r, g, b)
	local list = PickerDB().recentColors
	local key = ColorKey(r, g, b)
	for i = #list, 1, -1 do
		if ColorKey(list[i][1], list[i][2], list[i][3]) == key then
			table.remove(list, i)
		end
	end
	table.insert(list, 1, { r, g, b })
	while #list > PICKER_MAX_SWATCHES do
		table.remove(list)
	end
end

local function IsFavorite(r, g, b)
	local key = ColorKey(r, g, b)
	for _, c in ipairs(PickerDB().favorites) do
		if ColorKey(c[1], c[2], c[3]) == key then
			return true
		end
	end
	return false
end

local function ToggleFavorite(r, g, b)
	local list = PickerDB().favorites
	local key = ColorKey(r, g, b)
	for i = #list, 1, -1 do
		if ColorKey(list[i][1], list[i][2], list[i][3]) == key then
			table.remove(list, i)
			return false
		end
	end
	table.insert(list, 1, { r, g, b })
	while #list > PICKER_MAX_SWATCHES do
		table.remove(list)
	end
	return true
end

local colorPicker

local function BuildColorPicker()
	local PAD, PAD_TOP, PAD_RIGHT = 31, 21, 26
	local SV_SIZE = 200
	local BAR_W, BAR_GAP = 20, 10
	local RIGHT_W, RIGHT_GAP = 70, 19
	local POPUP_H = PAD_TOP + 28 + SV_SIZE + 80 + PAD
	local BASE_W = PAD + SV_SIZE + BAR_GAP + BAR_W + BAR_GAP + BAR_W + RIGHT_GAP + RIGHT_W + PAD_RIGHT
	local BASE_W_NO_ALPHA = PAD + SV_SIZE + BAR_GAP + BAR_W + RIGHT_GAP + RIGHT_W + PAD_RIGHT
	-- With an alpha bar only the right column grows, so OK / Cancel clear the Opacity box.
	local OPACITY_BLOCK_H = 50
	local DIM = 0.53

	local currentH, currentS, currentV, currentA = 0, 1, 1, 1
	local prevR, prevG, prevB, prevA = 1, 1, 1, 1
	local swatchFunc, cancelFunc
	local hasOpacity = false
	local updating = false
	local confirmed = false

	local popup = CreateFrame("Frame", "EllesmereUIColorPicker", UIParent)
	popup:SetSize(BASE_W, POPUP_H)
	popup:SetPoint("CENTER")
	popup:SetFrameStrata("FULLSCREEN_DIALOG")
	popup:SetFrameLevel(100)
	popup:SetClampedToScreen(true)
	popup:SetMovable(true)
	popup:EnableMouse(true)
	popup:Hide()
	tinsert(UISpecialFrames, "EllesmereUIColorPicker")

	Solid(popup, "BACKGROUND", 0.077, 0.068, 0.058, 1):SetAllPoints()
	AddBorder(popup, 1, 1, 1, 0.15)

	-- Click outside closes (and cancels). Armed once the click that opened it is released.
	local clickOff = CreateFrame("Frame", nil, popup)
	local armed = false
	clickOff:SetScript("OnUpdate", function()
		local down = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
		if not armed then
			armed = not down
		elseif down and not popup:IsMouseOver() then
			popup:Hide()
		end
	end)

	-- Title bar (drag to move)
	local titleBar = CreateFrame("Frame", nil, popup)
	titleBar:SetHeight(28)
	titleBar:SetPoint("TOPLEFT")
	titleBar:SetPoint("TOPRIGHT")
	titleBar:EnableMouse(true)
	titleBar:RegisterForDrag("LeftButton")
	titleBar:SetScript("OnDragStart", function() popup:StartMoving() end)
	titleBar:SetScript("OnDragStop", function() popup:StopMovingOrSizing() end)
	local titleLbl = NewText(titleBar, 12, 1)
	titleLbl:SetAlpha(0.5)
	titleLbl:SetPoint("CENTER", 0, -10)
	titleLbl:SetText("Color Picker")

	local closeBtn = CreateFrame("Button", nil, popup)
	closeBtn:SetSize(25, 25)
	closeBtn:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -13, -12)
	closeBtn:SetFrameLevel(popup:GetFrameLevel() + 5)
	local closeIcon = closeBtn:CreateTexture(nil, "ARTWORK")
	closeIcon:SetAllPoints()
	closeIcon:SetTexture(ns.MEDIA .. "ui\\eui-close")
	closeIcon:SetAlpha(0.40)
	closeBtn:SetScript("OnEnter", function() closeIcon:SetAlpha(0.50) end)
	closeBtn:SetScript("OnLeave", function() closeIcon:SetAlpha(0.40) end)
	closeBtn:SetScript("OnClick", function() popup:Hide() end)

	local outR, outG, outB, outA = 1, 1, 1, 1
	popup.GetColorRGB = function() return outR, outG, outB end
	popup.GetColorAlpha = function() return outA end

	local UpdateSVPadHue, UpdateSVCrosshair, UpdateHueIndicator
	local UpdateAlphaBar, UpdateHexInput, UpdateOpacityInput
	local newPreviewTex, prevPreviewTex

	local function FireCallbacks()
		if swatchFunc then
			swatchFunc()
		end
	end

	local function UpdateAllControls()
		if updating then
			return
		end
		updating = true
		local r, g, b = HSVtoRGB(currentH, currentS, currentV)
		outR, outG, outB, outA = r, g, b, currentA
		UpdateSVPadHue(currentH)
		UpdateSVCrosshair(currentS, currentV)
		UpdateHueIndicator(currentH)
		UpdateAlphaBar(r, g, b, currentA)
		UpdateHexInput(r, g, b)
		UpdateOpacityInput(currentA)
		newPreviewTex:SetTexture(r, g, b, currentA)
		updating = false
	end

	-- Drag helper: runs fn while the left button is held.
	local function DragArea(frame, fn)
		frame:EnableMouse(true)
		frame:SetScript("OnMouseDown", function(self, button)
			if button ~= "LeftButton" then
				return
			end
			fn()
			UpdateAllControls()
			FireCallbacks()
			self:SetScript("OnUpdate", function()
				if not IsMouseButtonDown("LeftButton") then
					self:SetScript("OnUpdate", nil)
					return
				end
				fn()
				UpdateAllControls()
				FireCallbacks()
			end)
		end)
		frame:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
	end

	-- Saturation / value square
	local svPad = CreateFrame("Frame", nil, popup)
	svPad:SetSize(SV_SIZE, SV_SIZE)
	svPad:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD, -(PAD_TOP + 28))
	local svHue = Solid(svPad, "BACKGROUND", 1, 0, 0, 1)
	svHue:SetAllPoints()
	local svWhite = svPad:CreateTexture(nil, "BORDER")
	svWhite:SetAllPoints()
	svWhite:SetTexture(WHITE)
	svWhite:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 0)
	local svBlack = svPad:CreateTexture(nil, "ARTWORK")
	svBlack:SetAllPoints()
	svBlack:SetTexture(WHITE)
	svBlack:SetGradientAlpha("VERTICAL", 0, 0, 0, 1, 0, 0, 0, 0)
	AddBorder(svPad, 1, 1, 1, 0.06, "OVERLAY")

	local ARM = 6
	local chT = Solid(svPad, "OVERLAY", 1, 1, 1, 0.9); chT:SetSize(1, ARM)
	local chB = Solid(svPad, "OVERLAY", 1, 1, 1, 0.9); chB:SetSize(1, ARM)
	local chL = Solid(svPad, "OVERLAY", 1, 1, 1, 0.9); chL:SetSize(ARM, 1)
	local chR = Solid(svPad, "OVERLAY", 1, 1, 1, 0.9); chR:SetSize(ARM, 1)

	UpdateSVPadHue = function(h)
		local r, g, b = HSVtoRGB(h, 1, 1)
		svHue:SetTexture(r, g, b, 1)
	end
	UpdateSVCrosshair = function(s, v)
		local x = s * SV_SIZE
		local y = -(1 - v) * SV_SIZE
		chT:ClearAllPoints(); chT:SetPoint("BOTTOM", svPad, "TOPLEFT", x, y + 2)
		chB:ClearAllPoints(); chB:SetPoint("TOP", svPad, "TOPLEFT", x, y - 2)
		chL:ClearAllPoints(); chL:SetPoint("RIGHT", svPad, "TOPLEFT", x - 2, y)
		chR:ClearAllPoints(); chR:SetPoint("LEFT", svPad, "TOPLEFT", x + 2, y)
	end
	DragArea(svPad, function()
		local cx, cy = GetCursorPosition()
		local scale = svPad:GetEffectiveScale()
		cx, cy = cx / scale, cy / scale
		currentS = max(0, min(1, (cx - svPad:GetLeft()) / SV_SIZE))
		currentV = max(0, min(1, (cy - svPad:GetBottom()) / SV_SIZE))
	end)

	-- Hue bar (red at the top, 6 gradient segments)
	local hueBar = CreateFrame("Frame", nil, popup)
	hueBar:SetSize(BAR_W, SV_SIZE)
	hueBar:SetPoint("TOPLEFT", svPad, "TOPRIGHT", BAR_GAP, 0)
	local HUE_COLORS = { { 1, 0, 0 }, { 1, 1, 0 }, { 0, 1, 0 }, { 0, 1, 1 }, { 0, 0, 1 }, { 1, 0, 1 }, { 1, 0, 0 } }
	local segH = SV_SIZE / 6
	for i = 1, 6 do
		local seg = hueBar:CreateTexture(nil, "BACKGROUND")
		seg:SetSize(BAR_W, segH)
		seg:SetPoint("TOPLEFT", hueBar, "TOPLEFT", 0, -(i - 1) * segH)
		seg:SetTexture(WHITE)
		local top, bot = HUE_COLORS[i], HUE_COLORS[i + 1]
		seg:SetGradientAlpha("VERTICAL", bot[1], bot[2], bot[3], 1, top[1], top[2], top[3], 1)
	end
	AddBorder(hueBar, 1, 1, 1, 0.06, "ARTWORK")
	local hueInd = Solid(hueBar, "OVERLAY", 1, 1, 1, 1)
	hueInd:SetSize(BAR_W + 4, 2)
	UpdateHueIndicator = function(h)
		hueInd:ClearAllPoints()
		hueInd:SetPoint("CENTER", hueBar, "TOPLEFT", BAR_W / 2, -(h / 360) * SV_SIZE)
	end
	DragArea(hueBar, function()
		local _, cy = GetCursorPosition()
		cy = cy / hueBar:GetEffectiveScale()
		currentH = max(0, min(1, (hueBar:GetTop() - cy) / SV_SIZE)) * 360
	end)

	-- Alpha bar over a checkerboard
	local alphaBar = CreateFrame("Frame", nil, popup)
	alphaBar:SetSize(BAR_W, SV_SIZE)
	alphaBar:SetPoint("TOPLEFT", hueBar, "TOPRIGHT", BAR_GAP, 0)
	local CK = 10
	for row = 0, math.ceil(SV_SIZE / CK) - 1 do
		for col = 0, math.ceil(BAR_W / CK) - 1 do
			local c = ((row + col) % 2 == 0) and 0.3 or 0.15
			local ck = Solid(alphaBar, "BACKGROUND", c, c, c, 1)
			ck:SetSize(CK, CK)
			ck:SetPoint("TOPLEFT", alphaBar, "TOPLEFT", col * CK, -row * CK)
		end
	end
	local alphaGrad = alphaBar:CreateTexture(nil, "ARTWORK")
	alphaGrad:SetAllPoints()
	alphaGrad:SetTexture(WHITE)
	local alphaInd = Solid(alphaBar, "OVERLAY", 1, 1, 1, 1)
	alphaInd:SetSize(BAR_W + 4, 2)
	AddBorder(alphaBar, 1, 1, 1, 0.06, "OVERLAY")
	UpdateAlphaBar = function(r, g, b, a)
		alphaGrad:SetGradientAlpha("VERTICAL", r, g, b, 0, r, g, b, 1)
		alphaInd:ClearAllPoints()
		alphaInd:SetPoint("CENTER", alphaBar, "TOPLEFT", BAR_W / 2, -(1 - a) * SV_SIZE)
	end
	DragArea(alphaBar, function()
		local _, cy = GetCursorPosition()
		cy = cy / alphaBar:GetEffectiveScale()
		currentA = 1 - max(0, min(1, (alphaBar:GetTop() - cy) / SV_SIZE))
	end)

	-- Right column: New, Prev, Hex#, Opacity, Cancel, OK
	local rightCol = CreateFrame("Frame", nil, popup)
	rightCol:SetSize(RIGHT_W, SV_SIZE)
	rightCol:SetPoint("TOPLEFT", alphaBar, "TOPRIGHT", RIGHT_GAP, 0)

	local nl = NewText(rightCol, 10, DIM)
	nl:SetPoint("TOPLEFT", rightCol, "TOPLEFT", 0, 0)
	nl:SetText("New")
	newPreviewTex = Solid(rightCol, "ARTWORK", 1, 1, 1, 1)
	newPreviewTex:SetSize(RIGHT_W, 26)
	newPreviewTex:SetPoint("TOPLEFT", rightCol, "TOPLEFT", 0, -14)
	prevPreviewTex = Solid(rightCol, "ARTWORK", 1, 1, 1, 1)
	prevPreviewTex:SetSize(RIGHT_W, 26)
	prevPreviewTex:SetPoint("TOPLEFT", newPreviewTex, "BOTTOMLEFT", 0, -4)

	-- Clicking Prev restores the color the picker opened with.
	local prevBtn = CreateFrame("Button", nil, rightCol)
	prevBtn:SetAllPoints(prevPreviewTex)
	prevBtn:SetFrameLevel(rightCol:GetFrameLevel() + 5)
	prevBtn:SetScript("OnClick", function()
		currentH, currentS, currentV = RGBtoHSV(prevR, prevG, prevB)
		currentA = hasOpacity and prevA or 1
		UpdateAllControls()
		FireCallbacks()
	end)

	local pl = NewText(rightCol, 10, DIM)
	pl:SetPoint("TOPLEFT", prevPreviewTex, "BOTTOMLEFT", 0, -6)
	pl:SetText("Prev")
	local hexLbl = NewText(rightCol, 10, DIM)
	hexLbl:SetPoint("TOPLEFT", pl, "BOTTOMLEFT", 0, -21)
	hexLbl:SetText("Hex#")

	local function NewBox(anchor, maxLetters)
		local box = CreateFrame("EditBox", nil, rightCol)
		box:SetSize(RIGHT_W, 24)
		box:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
		SetFont(box, 10)
		box:SetTextColor(1, 1, 1, DIM)
		box:SetMaxLetters(maxLetters)
		box:SetAutoFocus(false)
		box:EnableMouse(true)
		box:SetJustifyH("CENTER")
		Solid(box, "BACKGROUND", 0.213, 0.204, 0.196, 0.5):SetAllPoints()
		AddBorder(box, 1, 1, 1, 0.04)
		return box
	end

	local hexBox = NewBox(hexLbl, 6)
	local lastValidHex = "FFFFFF"
	local lastHexR, lastHexG, lastHexB = -1, -1, -1
	UpdateHexInput = function(r, g, b)
		if hexBox:HasFocus() then
			return
		end
		local ri, gi, bi = floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5)
		if ri == lastHexR and gi == lastHexG and bi == lastHexB then
			return
		end
		lastHexR, lastHexG, lastHexB = ri, gi, bi
		lastValidHex = format("%02X%02X%02X", ri, gi, bi)
		hexBox:SetText(lastValidHex)
	end
	local function ReadHex()
		local txt = (hexBox:GetText() or ""):upper():gsub("[^%dA-F]", "")
		if #txt == 6 then
			currentH, currentS, currentV = RGBtoHSV(tonumber(txt:sub(1, 2), 16) / 255,
				tonumber(txt:sub(3, 4), 16) / 255, tonumber(txt:sub(5, 6), 16) / 255)
			lastValidHex = txt
			UpdateAllControls()
			FireCallbacks()
			return true
		end
		return false
	end
	local hexEscaping = false
	hexBox:SetScript("OnEnterPressed", function(self)
		if not ReadHex() then
			self:SetText(lastValidHex)
		end
		self:ClearFocus()
	end)
	hexBox:SetScript("OnEscapePressed", function(self)
		hexEscaping = true
		self:SetText(lastValidHex)
		self:ClearFocus()
		hexEscaping = false
		popup:Hide()
	end)
	hexBox:SetScript("OnEditFocusLost", function(self)
		if not hexEscaping and not ReadHex() then
			self:SetText(lastValidHex)
		end
	end)
	hexBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
	hexBox:SetScript("OnTextChanged", function(self)
		if self:HasFocus() then
			ReadHex()
		end
	end)

	-- Opacity box (only with an alpha bar): integer percent 0-100.
	local opacityLbl = NewText(rightCol, 10, DIM)
	opacityLbl:SetPoint("TOPLEFT", hexBox, "BOTTOMLEFT", 0, -10)
	opacityLbl:SetText("Opacity")
	local opacityBox = NewBox(opacityLbl, 3)
	opacityBox:SetNumeric(true)
	local lastOpacityPct = -1
	UpdateOpacityInput = function(a)
		if opacityBox:HasFocus() then
			return
		end
		local pct = floor((a or 1) * 100 + 0.5)
		if pct == lastOpacityPct then
			return
		end
		lastOpacityPct = pct
		opacityBox:SetText(tostring(pct))
	end
	local function ApplyOpacityText(commit)
		local n = tonumber(opacityBox:GetText())
		if n then
			n = max(0, min(100, floor(n + 0.5)))
			currentA = n / 100
			lastOpacityPct = n
			UpdateAllControls()
			FireCallbacks()
		elseif commit then
			opacityBox:SetText(tostring(floor(currentA * 100 + 0.5)))
		end
	end
	local opacityEscaping = false
	opacityBox:SetScript("OnEnterPressed", function(self)
		ApplyOpacityText(true)
		self:ClearFocus()
	end)
	opacityBox:SetScript("OnEscapePressed", function(self)
		opacityEscaping = true
		self:SetText(tostring(floor(currentA * 100 + 0.5)))
		self:ClearFocus()
		opacityEscaping = false
		popup:Hide()
	end)
	opacityBox:SetScript("OnEditFocusLost", function()
		if not opacityEscaping then
			ApplyOpacityText(true)
		end
	end)
	opacityBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
	opacityBox:SetScript("OnTextChanged", function(self)
		if self:HasFocus() then
			ApplyOpacityText(false)
		end
	end)

	local okBtn = CreateFlatButton(rightCol, RIGHT_W, 21, "OK")
	SetFont(okBtn.label, 10)
	okBtn:SetPoint("BOTTOMLEFT", rightCol, "BOTTOMLEFT", 0, 0)
	okBtn:SetFrameLevel(popup:GetFrameLevel() + 2)
	okBtn:SetScript("OnClick", function()
		RecordRecentColor(HSVtoRGB(currentH, currentS, currentV))
		FireCallbacks()
		confirmed = true
		popup:Hide()
	end)

	local cancelBtn = CreateFrame("Button", nil, rightCol)
	cancelBtn:SetSize(RIGHT_W, 14)
	cancelBtn:SetPoint("BOTTOM", okBtn, "TOP", 0, 5)
	cancelBtn:SetFrameLevel(popup:GetFrameLevel() + 2)
	local cancelText = NewText(cancelBtn, 10, 0.4)
	cancelText:SetPoint("CENTER")
	cancelText:SetJustifyH("CENTER")
	cancelText:SetText("cancel")
	cancelBtn:SetScript("OnEnter", function() cancelText:SetTextColor(1, 1, 1, 0.7) end)
	cancelBtn:SetScript("OnLeave", function() cancelText:SetTextColor(1, 1, 1, 0.4) end)
	cancelBtn:SetScript("OnClick", function() popup:Hide() end)

	-- Favorites and Recent Colors (below the square)
	local RefreshSwatchRows
	local SWATCH_SZ, SWATCH_SPACING = 19, 4

	local function MakeSwatchBtn(parent, isFavorites)
		local btn = CreateFrame("Button", nil, parent)
		btn:SetSize(SWATCH_SZ, SWATCH_SZ)
		btn:SetFrameLevel(parent:GetFrameLevel() + 2)
		btn.tex = btn:CreateTexture(nil, "ARTWORK")
		btn.tex:SetAllPoints()
		btn:SetScript("OnEnter", function(self)
			local c = self.color
			if not c then
				return
			end
			local hex = format("%02X%02X%02X", floor(c[1] * 255 + 0.5), floor(c[2] * 255 + 0.5), floor(c[3] * 255 + 0.5))
			ShowTip(self, "|cff" .. hex .. "#|r" .. hex .. "\n"
				.. (isFavorites and "Right-click: remove favorite" or "Right-click: favorite"))
		end)
		btn:SetScript("OnLeave", HideTip)
		btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		btn:SetScript("OnClick", function(self, mouseButton)
			local c = self.color
			if not c then
				return
			end
			if mouseButton == "RightButton" then
				if isFavorites or not IsFavorite(c[1], c[2], c[3]) then
					ToggleFavorite(c[1], c[2], c[3])
				end
				RefreshSwatchRows()
			else
				currentH, currentS, currentV = RGBtoHSV(c[1], c[2], c[3])
				UpdateAllControls()
				FireCallbacks()
			end
		end)
		btn:Hide()
		return btn
	end

	local favLbl = NewText(popup, 10, DIM)
	favLbl:SetPoint("TOPLEFT", svPad, "BOTTOMLEFT", 0, -10)
	favLbl:SetText("Favorites")
	local favRow = CreateFrame("Frame", nil, popup)
	favRow:SetSize(BASE_W - PAD - PAD_RIGHT, SWATCH_SZ)
	favRow:SetPoint("TOPLEFT", favLbl, "BOTTOMLEFT", 0, -3)
	local rcLbl = NewText(popup, 10, DIM)
	rcLbl:SetPoint("TOPLEFT", favRow, "BOTTOMLEFT", 0, -8)
	rcLbl:SetText("Recent Colors")
	local rcRow = CreateFrame("Frame", nil, popup)
	rcRow:SetSize(BASE_W - PAD - PAD_RIGHT, SWATCH_SZ)
	rcRow:SetPoint("TOPLEFT", rcLbl, "BOTTOMLEFT", 0, -3)

	local favSwatches, rcSwatches = {}, {}
	local function PopulateSwatchRow(pool, row, data, isFavorites)
		local count = min(#data, PICKER_MAX_SWATCHES)
		for i = 1, max(count, #pool) do
			local btn = pool[i]
			if not btn then
				btn = MakeSwatchBtn(row, isFavorites)
				pool[i] = btn
			end
			if i <= count then
				btn.color = data[i]
				btn.tex:SetTexture(data[i][1], data[i][2], data[i][3], 1)
				btn:ClearAllPoints()
				if i == 1 then
					btn:SetPoint("LEFT", row, "LEFT", 0, 0)
				else
					btn:SetPoint("LEFT", pool[i - 1], "RIGHT", SWATCH_SPACING, 0)
				end
				btn:Show()
			else
				btn:Hide()
			end
		end
	end
	RefreshSwatchRows = function()
		local db = PickerDB()
		PopulateSwatchRow(favSwatches, favRow, db.favorites, true)
		PopulateSwatchRow(rcSwatches, rcRow, db.recentColors, false)
	end

	-- Any close but OK (X, cancel, Escape, click outside) puts the old color back.
	popup:SetScript("OnHide", function()
		local cancel = not confirmed and cancelFunc
		confirmed = false
		swatchFunc, cancelFunc = nil, nil
		svPad:SetScript("OnUpdate", nil)
		hueBar:SetScript("OnUpdate", nil)
		alphaBar:SetScript("OnUpdate", nil)
		HideTip()
		if cancel then
			cancel()
		end
		RefreshAll()
	end)

	-- info: r, g, b, opacity, hasOpacity, swatchFunc (live change), cancelFunc
	popup.Open = function(self, info)
		if self:IsShown() then
			self:Hide()
		end
		confirmed = false
		swatchFunc = info.swatchFunc
		cancelFunc = info.cancelFunc
		hasOpacity = info.hasOpacity or false
		local r, g, b = info.r or 0, info.g or 0, info.b or 0
		local a = info.opacity or 1
		prevR, prevG, prevB, prevA = r, g, b, a
		currentH, currentS, currentV = RGBtoHSV(r, g, b)
		currentA = hasOpacity and a or 1
		prevPreviewTex:SetTexture(r, g, b, hasOpacity and a or 1)
		rightCol:ClearAllPoints()
		if hasOpacity then
			alphaBar:Show()
			self:SetWidth(BASE_W)
			rightCol:SetPoint("TOPLEFT", alphaBar, "TOPRIGHT", RIGHT_GAP, 0)
			rightCol:SetHeight(SV_SIZE + OPACITY_BLOCK_H)
			opacityLbl:Show()
			opacityBox:Show()
		else
			alphaBar:Hide()
			self:SetWidth(BASE_W_NO_ALPHA)
			rightCol:SetPoint("TOPLEFT", hueBar, "TOPRIGHT", RIGHT_GAP, 0)
			rightCol:SetHeight(SV_SIZE)
			opacityLbl:Hide()
			opacityBox:Hide()
		end
		-- Centered under the cursor; above it if it would drop below the settings window.
		local cx, cy = GetCursorPosition()
		local scale = self:GetEffectiveScale()
		cx, cy = cx / scale, cy / scale
		local pw, ph = self:GetWidth(), self:GetHeight()
		local x, y = cx - pw * 0.5, cy - 30
		if window and window:IsShown() then
			local bottom = window:GetBottom()
			if bottom and (y - ph) < bottom * window:GetEffectiveScale() / scale then
				y = cy + 30 + ph
			end
		end
		self:ClearAllPoints()
		self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
		lastHexR, lastOpacityPct = -1, -1
		armed = false
		RefreshSwatchRows()
		self:Show()
		UpdateAllControls()
	end

	return popup
end

-- Opens the color picker. get/set: r, g, b, a. hasAlpha: the 4th value is
-- edited too. Changes apply live; Cancel / X / Escape / click outside restore.
local function OpenColorPicker(get, set, hasAlpha, onChange)
	colorPicker = colorPicker or BuildColorPicker()
	local r, g, b, a = get()
	r, g, b, a = r or 0, g or 0, b or 0, a or 1
	local function Apply(nr, ng, nb, na)
		set(nr, ng, nb, hasAlpha and na or nil)
		onChange()
		ApplyAndRefreshLive()
	end
	colorPicker:Open({
		r = r, g = g, b = b, opacity = a,
		hasOpacity = hasAlpha and true or false,
		swatchFunc = function()
			local nr, ng, nb = colorPicker.GetColorRGB()
			Apply(nr, ng, nb, colorPicker.GetColorAlpha())
		end,
		cancelFunc = function() Apply(r, g, b, a) end,
	})
end
-- Public for option files with their own menus: ns.OpenColorPicker(get, set, hasAlpha, onChange)
ns.OpenColorPicker = function(get, set, hasAlpha, onChange)
	return OpenColorPicker(get, set, hasAlpha, onChange or function() end)
end

local function CreateColorSwatch(row, colorKey, hasAlpha)
	local get, set = ColorAccess(colorKey)
	local swatch = CreateFrame("Button", nil, row)
	swatch:SetSize(24, 24)
	swatch:SetPoint("RIGHT", row, "RIGHT", -20, 0)
	local outline = Solid(swatch, "BACKGROUND", 1, 1, 1, 1)
	outline:SetPoint("TOPLEFT", -1, 1)
	outline:SetPoint("BOTTOMRIGHT", 1, -1)
	local inner = Solid(swatch, "BORDER", 0, 0, 0, 1)
	inner:SetAllPoints()
	swatch.color = swatch:CreateTexture(nil, "ARTWORK")
	swatch.color:SetPoint("TOPLEFT", 1, -1)
	swatch.color:SetPoint("BOTTOMRIGHT", -1, 1)
	swatch.hex = NewText(row, 12, 0.45)
	swatch.hex:SetPoint("RIGHT", swatch, "LEFT", -12, 0)

	function swatch:Refresh()
		local r, g, b = get()
		self.color:SetTexture(r, g, b, 1)
		self.hex:SetText(format("#%02X%02X%02X", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5)))
	end

	swatch:SetScript("OnClick", function(self)
		if row.disabled then
			return
		end
		OpenColorPicker(get, set, hasAlpha, function() self:Refresh() end)
	end)
	swatch:SetScript("OnEnter", function() row:SetHover(true) end)
	swatch:SetScript("OnLeave", function() row:SetHover(false) end)
	ForwardWheel(swatch)

	swatch:Refresh()
	return swatch
end

---------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------
local Page = {}
Page.__index = Page

function Page:RowWidth()
	return CONTENT_W - CONTENT_PAD * 2
end

function Page:Section(text)
	self.openRow = nil
	-- 20 px spacer between sections, like EllesmereUI pages.
	if self.y < -6 then
		self.y = self.y - 20
	end
	local frame = CreateFrame("Frame", nil, self.child)
	frame:SetSize(self:RowWidth(), SECTION_H)
	frame:SetPoint("TOPLEFT", self.child, "TOPLEFT", CONTENT_PAD, self.y)
	local label = NewText(frame, 12, 0.41)
	label:SetPoint("BOTTOMLEFT", 0, 8)
	label:SetText(text:upper())
	local line = Solid(frame, "ARTWORK", 1, 1, 1, 0.02)
	line:SetPoint("BOTTOMLEFT")
	line:SetPoint("BOTTOMRIGHT")
	line:SetHeight(1)
	self.section = text
	self:AddTarget("\2" .. text, frame, self.y)
	self.rowIndex = 0
	self.y = self.y - SECTION_H
end

-- Search targets: where a section or a setting is on the page, so a search
-- result can scroll to it. Keys are "\2<section>" and "<section>\1<label>".
function Page:AddTarget(key, frame, y)
	if not self.targets[key] then
		self.targets[key] = { frame = frame, y = y }
	end
end

-- Two-column layout, like the EllesmereUI dual rows: every row holds two cells
-- (left and right) with a thin divider between them. A section or a paragraph
-- closes the open row, so the next setting starts a new row.
function Page:CloseRow()
	self.openRow = nil
end

-- Creates one cell. controlWidth is the space the control needs on the right,
-- so the label can be cut off before it touches the control.
function Page:Row(label, description, isDisabled, controlWidth)
	local rowWidth = self:RowWidth()
	local cellWidth = floor(rowWidth / 2)
	local row = self.openRow
	local leftSide = row == nil
	if leftSide then
		self.rowIndex = self.rowIndex + 1
		row = CreateFrame("Frame", nil, self.child)
		row:SetSize(rowWidth, ROW_H)
		row:SetPoint("TOPLEFT", self.child, "TOPLEFT", CONTENT_PAD, self.y)
		local bg = Solid(row, "BACKGROUND", 0, 0, 0, (self.rowIndex % 2 == 0) and 0.2 or 0.1)
		bg:SetAllPoints()
		ForwardWheel(row)
		row.top = self.y
		self.openRow = row
		self.y = self.y - ROW_H
	else
		local divider = Solid(row, "BORDER", 1, 1, 1, 0.06)
		divider:SetWidth(1)
		divider:SetPoint("TOP", row, "TOP", 0, -8)
		divider:SetPoint("BOTTOM", row, "BOTTOM", 0, 8)
		self.openRow = nil
	end

	local cell = CreateFrame("Frame", nil, row)
	cell:SetSize(cellWidth, ROW_H)
	if leftSide then
		cell:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	else
		cell:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
	end
	cell:EnableMouse(true)
	cell.hover = Solid(cell, "BORDER", 1, 1, 1, 0.025)
	cell.hover:SetAllPoints()
	cell.hover:Hide()
	cell.label = NewText(cell, 14, 1)
	cell.label:SetPoint("LEFT", 20, 0)
	cell.labelWidth = max(40, cellWidth - 40 - (controlWidth or 0) - 12)
	cell.label:SetWidth(cell.labelWidth)
	-- Inline items (cog, swatches, sync icon) go right to left, left of the control.
	cell.inlineRight = 20 + ((controlWidth and controlWidth > 0) and (controlWidth + 8) or 0)
	self.lastCell = cell
	cell.label:SetWordWrap(false)
	cell.label:SetText(label)
	if label and label ~= "" then
		self:AddTarget((self.section or "") .. "\1" .. label, cell, row.top)
	end

	function cell:SetHover(on)
		self.hover:SetShown(on)
		if on then
			ShowTip(self, description)
		else
			HideTip()
		end
	end
	cell:SetScript("OnEnter", function(self) self:SetHover(true) end)
	cell:SetScript("OnLeave", function(self) self:SetHover(false) end)
	ForwardWheel(cell)

	if isDisabled then
		RegisterRefresh(function()
			cell.disabled = isDisabled() and true or false
			cell:SetAlpha(cell.disabled and 0.3 or 1)
		end)
	end

	return cell
end

function Page:Toggle(label, description, getValue, setValue, isDisabled)
	local cell = self:Row(label, description, isDisabled, 40)
	local toggle = CreateToggle(cell, getValue, setValue)
	RegisterRefresh(function() toggle:Refresh() end)
end

function Page:Slider(label, description, minValue, maxValue, step, getValue, setValue, isDisabled)
	local cell = self:Row(label, description, isDisabled, SLIDER_W + 12 + 40)
	local slider = CreateSlider(cell, minValue, maxValue, step, getValue, setValue)
	RegisterRefresh(slider.Refresh)
end

function Page:Dropdown(label, description, getItems, getValue, getLabel, setValue, options, isDisabled)
	local cell = self:Row(label, description, isDisabled, CONTROL_W)
	local drop = CreateDropdown(cell, getItems, getValue, getLabel, setValue, options)
	RegisterRefresh(function() drop:Refresh() end)
end

-- Empty cell, keeps the next setting in the right column.
function Page:Blank()
	self:Row("", nil, nil, 0)
end

-- Dropdown with checkboxes: several items can be on at the same time.
function Page:MultiSelect(label, description, getItems, isChecked, toggle, getLabel, isDisabled)
	local cell = self:Row(label, description, isDisabled, CONTROL_W)
	local drop = CreateDropdown(cell, getItems, function() return nil end, getLabel, function() end,
		{ multi = true, isChecked = isChecked, toggle = toggle })
	RegisterRefresh(function() drop:Refresh() end)
end

-- Two-lane checkbox dropdown (EllesmereUI filter dropdowns): the left box
-- shows an item (isChecked / toggle), the red right box hides it (isHidden /
-- toggleHidden) on items with twoLane = true. Items may also be headers
-- (header, rightLabel) and pinned actions (action = fn).
function Page:LaneSelect(label, description, getItems, isChecked, toggle, isHidden, toggleHidden, getLabel, isDisabled)
	local cell = self:Row(label, description, isDisabled, CONTROL_W)
	local drop = CreateDropdown(cell, getItems, function() return nil end, getLabel, function() end,
		{ multi = true, isChecked = isChecked, toggle = toggle, isHidden = isHidden, toggleHidden = toggleHidden })
	RegisterRefresh(function() drop:Refresh() end)
	return drop
end


function Page:Color(label, description, colorKey, isDisabled)
	local cell = self:Row(label, description, isDisabled, 24 + 12 + 60)
	local swatch = CreateColorSwatch(cell, colorKey)
	RegisterRefresh(function() swatch:Refresh() end)
end

function Page:Button(label, description, buttonText, onClick)
	local cell = self:Row(label, description, nil, 150)
	local button = CreateFlatButton(cell, 150, 28, buttonText)
	button:SetPoint("RIGHT", cell, "RIGHT", -20, 0)
	button.tooltip = description
	button:SetScript("OnClick", function()
		onClick()
		ApplyAndRefresh()
	end)
	ForwardWheel(button)
end

-- One-line text box (the retail Profile Name field). set(text) runs on
-- every change; placeholder = dim text while empty.
function Page:TextInput(label, description, getText, setText, placeholder)
	local cell = self:Row(label, description, nil, CONTROL_W)
	local edit = CreateFrame("EditBox", nil, cell)
	edit:SetSize(CONTROL_W, CONTROL_H)
	edit:SetPoint("RIGHT", cell, "RIGHT", -20, 0)
	edit:SetAutoFocus(false)
	edit:SetFont(FONT, 13, "")
	edit:SetTextColor(1, 1, 1, 0.9)
	edit:SetTextInsets(10, 10, 0, 0)
	edit:SetMaxLetters(48)
	Solid(edit, "BACKGROUND", DROPDOWN_BG[1], DROPDOWN_BG[2], DROPDOWN_BG[3], 0.9):SetAllPoints()
	local border = AddBorder(edit, 1, 1, 1, 0.2)
	local hint = NewText(edit, 13, 0.25)
	hint:SetPoint("LEFT", 10, 0)
	hint:SetText(placeholder or "")
	local setting = false
	edit:SetScript("OnTextChanged", function(self)
		local text = self:GetText() or ""
		hint:SetShown(text == "")
		if not setting then
			setText(text)
		end
	end)
	edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	edit:SetScript("OnEditFocusGained", function() border:SetColor(1, 1, 1, 0.4) end)
	edit:SetScript("OnEditFocusLost", function() border:SetColor(1, 1, 1, 0.2) end)
	edit:SetScript("OnEnter", function() cell:SetHover(true) end)
	edit:SetScript("OnLeave", function() cell:SetHover(false) end)
	ForwardWheel(edit)
	local function Refresh()
		if not edit:HasFocus() then
			setting = true
			edit:SetText(getText() or "")
			setting = false
		end
		hint:SetShown((edit:GetText() or "") == "")
	end
	RegisterRefresh(Refresh)
	Refresh()
	return edit
end

-- Key binding button (EllesmereUI BuildKeybindButton): left-click, then press
-- a key (with Shift / Ctrl / Alt) to set it; Escape cancels; right-click
-- unbinds. getKey returns the binding ("ALT-CTRL-SHIFT-X" form) or nil.
local MODIFIER_KEYS = {
	LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
	LMETA = true, RMETA = true, UNKNOWN = true,
}
function Page:Keybind(label, description, getKey, setKey, isDisabled)
	local cell = self:Row(label, description, isDisabled, 126)
	local button = CreateFlatButton(cell, 126, 28, "")
	button:SetPoint("RIGHT", cell, "RIGHT", -20, 0)
	button.tooltip = description
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local function Refresh()
		if button.capturing then
			button.label:SetText("Press a key...")
		else
			local key = getKey()
			button.label:SetText((key and key ~= "") and key or "Not Bound")
		end
	end
	local function Stop()
		button.capturing = nil
		button:EnableKeyboard(false)
		button:SetScript("OnKeyDown", nil)
		Refresh()
	end
	button:SetScript("OnClick", function(self, mouse)
		if cell.disabled then
			return
		end
		if mouse == "RightButton" then
			Stop()
			setKey(nil)
			ApplyAndRefresh()
			return
		end
		if self.capturing then
			Stop()
			return
		end
		self.capturing = true
		self:EnableKeyboard(true)
		self:SetScript("OnKeyDown", function(btn, key)
			if MODIFIER_KEYS[key] then
				return
			end
			if key == "ESCAPE" then
				Stop()
				return
			end
			local combo = ""
			if IsAltKeyDown() then combo = combo .. "ALT-" end
			if IsControlKeyDown() then combo = combo .. "CTRL-" end
			if IsShiftKeyDown() then combo = combo .. "SHIFT-" end
			Stop()
			setKey(combo .. key)
			ApplyAndRefresh()
		end)
		Refresh()
	end)
	button:HookScript("OnHide", function()
		if button.capturing then
			Stop()
		end
	end)
	ForwardWheel(button)
	RegisterRefresh(Refresh)
	Refresh()
end

---------------------------------------------------------------------------
-- Inline items on the last cell: cog popups, color swatches, sync icons
-- (EllesmereUI BuildInlineCog / BuildColorSwatch / BuildSyncIcon).
---------------------------------------------------------------------------
-- Takes width pixels from the right side of the cell and returns the x offset
-- (from the cell's right edge) where the item's RIGHT goes.
local function TakeInline(cell, width)
	local x = cell.inlineRight
	cell.inlineRight = cell.inlineRight + width + 8
	cell.labelWidth = max(30, cell.labelWidth - width - 8)
	cell.label:SetWidth(cell.labelWidth)
	return -x
end

-- Small icon button on the last cell, left of its control (e.g. a remove X).
function Page:InlineIcon(tooltip, iconPath, onClick, size)
	local cell = self.lastCell
	size = size or 16
	local button = CreateFrame("Button", nil, cell)
	button:SetSize(size, size)
	button:SetPoint("RIGHT", cell, "RIGHT", TakeInline(cell, size), 0)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexture(iconPath)
	button:SetAlpha(0.45)
	button:SetScript("OnEnter", function(self)
		self:SetAlpha(0.9)
		ShowTip(self, tooltip)
	end)
	button:SetScript("OnLeave", function(self)
		self:SetAlpha(0.45)
		HideTip()
	end)
	button:SetScript("OnClick", function()
		if cell.disabled then
			return
		end
		HideTip()
		onClick()
		ApplyAndRefresh()
	end)
	ForwardWheel(button)
	return button
end

-- Label only cell (for rows made of swatches).
function Page:Label(label, description, isDisabled)
	return self:Row(label, description, isDisabled, 0)
end

-- Color row with get/set functions (r, g, b, a). opts.alpha edits alpha too.
function Page:ColorRow(label, description, get, set, opts, isDisabled)
	local cell = self:Row(label, description, isDisabled, 24 + 12 + 60)
	local swatch = CreateColorSwatch(cell, { get = get, set = set }, opts and opts.alpha)
	RegisterRefresh(function() swatch:Refresh() end)
end

-- Small color square. get/set: r, g, b, a. opts:
--   alpha     = edit alpha too
--   active    = fn, true -> full alpha, false -> 0.3 (a "mode" pair)
--   onClick   = fn, return true to stop the color picker (switches a mode)
--   readonly  = true: shows the color only (onClick still runs)
--   disabled  = fn, true -> dimmed and not clickable
function Page:Swatch(tooltip, get, set, opts)
	opts = opts or {}
	local cell = self.lastCell
	local swatch = CreateFrame("Button", nil, cell)
	swatch:SetSize(20, 20)
	swatch:SetPoint("RIGHT", cell, "RIGHT", TakeInline(cell, 20), 0)
	local outline = Solid(swatch, "BACKGROUND", 1, 1, 1, 0.8)
	outline:SetPoint("TOPLEFT", -1, 1)
	outline:SetPoint("BOTTOMRIGHT", 1, -1)
	Solid(swatch, "BORDER", 0, 0, 0, 1):SetAllPoints()
	swatch.color = swatch:CreateTexture(nil, "ARTWORK")
	swatch.color:SetPoint("TOPLEFT", 1, -1)
	swatch.color:SetPoint("BOTTOMRIGHT", -1, 1)
	local function Refresh()
		local r, g, b = get()
		swatch.color:SetTexture(r or 1, g or 1, b or 1, 1)
		local off = cell.disabled or (opts.disabled and opts.disabled())
		swatch.off = off
		if off then
			swatch:SetAlpha(0.15)
		elseif opts.active then
			swatch:SetAlpha(opts.active() and 1 or 0.3)
		else
			swatch:SetAlpha(1)
		end
	end
	swatch:SetScript("OnClick", function()
		if swatch.off then
			return
		end
		if opts.onClick and opts.onClick() then
			ApplyAndRefresh()
			return
		end
		if opts.readonly then
			return
		end
		OpenColorPicker(get, set, opts.alpha, RefreshAll)
	end)
	swatch:SetScript("OnEnter", function(self)
		ShowTip(self, tooltip)
	end)
	swatch:SetScript("OnLeave", HideTip)
	ForwardWheel(swatch)
	RegisterRefresh(Refresh)
	Refresh()
	return swatch
end

-- "Apply to all frames" icon: apply() copies this unit's value to the others.
function Page:Sync(tooltip, apply, isSynced)
	local cell = self.lastCell
	local button = CreateFrame("Button", nil, cell)
	button:SetSize(18, 18)
	button:SetPoint("RIGHT", cell, "RIGHT", TakeInline(cell, 18), 0)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexture(ART_PATH .. "sync")
	icon:SetTexCoord(0, 30 / 32, 0, 30 / 32)
	local function Refresh()
		local synced = isSynced and isSynced()
		button.synced = synced
		if synced then
			icon:SetVertexColor(1, 1, 1, 1)
			button:SetAlpha(button:IsMouseOver() and 0.4 or 0.2)
		else
			icon:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
			button:SetAlpha(button:IsMouseOver() and 1 or 0.75)
		end
	end
	button:SetScript("OnClick", function()
		if cell.disabled then
			return
		end
		apply()
		ApplyAndRefresh()
	end)
	button:SetScript("OnEnter", function(self)
		Refresh()
		ShowTip(self, tooltip .. (button.synced and "\n\nAll frames already match." or ""))
	end)
	button:SetScript("OnLeave", function()
		Refresh()
		HideTip()
	end)
	ForwardWheel(button)
	RegisterRefresh(Refresh)
	Refresh()
end

-- Cog popup ---------------------------------------------------------------
local COG_ICONS = { cog = "cogs", directions = "eui-directions", resize = "eui-resize-5" }
local COG_W = 390
local COG_ROW_H = 34
local cogOpen, cogCatcher

local function CloseCog()
	if cogOpen then
		cogOpen:Hide()
		if cogOpen.button then
			cogOpen.button:UpdateState()
		end
		cogOpen = nil
	end
	if cogCatcher then
		cogCatcher:Hide()
	end
end

local function BuildCogPopup(title, rows)
	local popup = CreateFrame("Frame", nil, window)
	popup:SetFrameStrata("DIALOG")
	popup:SetFrameLevel(100)
	popup:EnableMouse(true)
	Solid(popup, "BACKGROUND", 0.077, 0.068, 0.058, 0.97):SetAllPoints()
	AddBorder(popup, 1, 1, 1, 0.15)
	local titleText = NewText(popup, 12, 0.7)
	titleText:SetPoint("TOP", 0, -12)
	titleText:SetText(title)
	local y = -34
	for _, def in ipairs(rows) do
		local row = CreateFrame("Frame", nil, popup)
		row:SetSize(COG_W, COG_ROW_H)
		row:SetPoint("TOPLEFT", popup, "TOPLEFT", 0, y)
		row:EnableMouse(true)
		row.label = NewText(row, 13, 0.6)
		row.label:SetPoint("LEFT", 16, 0)
		row.label:SetWordWrap(false)
		row.label:SetText(def.label)
		row.SetHover = function(self, on)
			if on then
				ShowTip(self, def.tip)
			else
				HideTip()
			end
		end
		row:SetScript("OnEnter", function(self) self:SetHover(true) end)
		row:SetScript("OnLeave", function(self) self:SetHover(false) end)
		local control
		if def.type == "toggle" then
			row.label:SetWidth(COG_W - 100)
			control = CreateToggle(row, def.get, def.set)
			RegisterRefresh(function() control:Refresh() end)
		elseif def.type == "slider" then
			row.label:SetWidth(COG_W - SLIDER_W - 100)
			control = CreateSlider(row, def.min, def.max, def.step or 1, def.get, def.set)
			RegisterRefresh(control.Refresh)
		elseif def.type == "dropdown" then
			row.label:SetWidth(COG_W - CONTROL_W - 50)
			local function Label()
				local value = def.get()
				for _, item in ipairs(def.items()) do
					if item.value == value then
						return item.name
					end
				end
				return tostring(value or "")
			end
			control = CreateDropdown(row, def.items, def.get, def.labelFn or Label, def.set, def.options)
			RegisterRefresh(function() control:Refresh() end)
		elseif def.type == "color" then
			row.label:SetWidth(COG_W - 140)
			control = CreateColorSwatch(row, { get = def.get, set = def.set }, def.alpha)
			RegisterRefresh(function() control:Refresh() end)
		elseif def.type == "input" then
			-- Short text input (retail cog type="input", e.g. Separator / Prefix).
			local w = def.inputWidth or 60
			row.label:SetWidth(COG_W - w - 50)
			local box = CreateFrame("EditBox", nil, row)
			box:SetSize(w, 24)
			box:SetPoint("RIGHT", row, "RIGHT", -16, 0)
			box:SetAutoFocus(false)
			box:SetJustifyH("CENTER")
			box:SetFont(FONT, 13, "")
			box:SetTextColor(1, 1, 1, 1)
			if def.maxLetters then
				box:SetMaxLetters(def.maxLetters)
			end
			Solid(box, "BACKGROUND", DROPDOWN_BG[1], DROPDOWN_BG[2], DROPDOWN_BG[3], 1):SetAllPoints()
			AddBorder(box, 1, 1, 1, 0.2)
			local function Commit(self)
				self:ClearFocus()
				if row.disabled then
					return
				end
				def.set(self:GetText() or "")
				ApplyAndRefresh()
			end
			box:SetScript("OnEnterPressed", Commit)
			box:SetScript("OnEditFocusLost", function(self)
				if (self:GetText() or "") ~= tostring(def.get() or "") then
					Commit(self)
				end
			end)
			box:SetScript("OnEscapePressed", function(self)
				self:SetText(tostring(def.get() or ""))
				self:ClearFocus()
			end)
			control = box
			RegisterRefresh(function()
				if not box:HasFocus() then
					box:SetText(tostring(def.get() or ""))
				end
				box:EnableMouse(not row.disabled)
			end)
		end
		if def.disabled then
			RegisterRefresh(function()
				row.disabled = def.disabled() and true or false
				row:SetAlpha(row.disabled and 0.3 or 1)
			end)
		end
		y = y - COG_ROW_H
	end
	popup:SetSize(COG_W, -y + 10)
	popup:Hide()
	return popup
end

-- opts: icon ("cog" / "directions" / "resize"), disabled (fn), tip (string)
function Page:Cog(title, rows, opts)
	opts = opts or {}
	local cell = self.lastCell
	local button = CreateFrame("Button", nil, cell)
	button:SetSize(24, 24)
	button:SetPoint("RIGHT", cell, "RIGHT", TakeInline(cell, 24), 0)
	button:SetFrameLevel(cell:GetFrameLevel() + 5)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexture(ART_PATH .. (COG_ICONS[opts.icon or "cog"] or "cogs"))
	icon:SetTexCoord(0, 30 / 32, 0, 30 / 32)
	function button:UpdateState()
		local off = cell.disabled or (opts.disabled and opts.disabled())
		self.off = off
		local open = cogOpen and cogOpen.button == self
		self:SetAlpha(off and 0.15 or ((open or self:IsMouseOver()) and 0.7 or 0.4))
	end
	button:SetScript("OnClick", function(self)
		if self.off then
			return
		end
		if cogOpen and cogOpen.button == self then
			CloseCog()
			return
		end
		CloseCog()
		CloseMenu()
		if not self.popup then
			self.popup = BuildCogPopup(title, rows)
			self.popup.button = self
			RefreshAll()
		end
		local popup = self.popup
		popup:ClearAllPoints()
		local bottom = self:GetBottom() or 0
		if bottom * self:GetEffectiveScale() / UIParent:GetEffectiveScale() - popup:GetHeight() * popup:GetEffectiveScale() / UIParent:GetEffectiveScale() < 20 then
			popup:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 8, 4)
		else
			popup:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 8, -4)
		end
		if not cogCatcher then
			cogCatcher = CreateFrame("Button", nil, UIParent)
			cogCatcher:SetAllPoints(UIParent)
			cogCatcher:SetFrameStrata("DIALOG")
			cogCatcher:SetFrameLevel(1)
			cogCatcher:RegisterForClicks("AnyUp")
			cogCatcher:SetScript("OnClick", CloseCog)
			window:HookScript("OnHide", CloseCog)
		end
		cogCatcher:Show()
		cogOpen = popup
		popup:Show()
		self:UpdateState()
	end)
	button:SetScript("OnEnter", function(self)
		self:UpdateState()
		if self.off and opts.disabledTip then
			ShowTip(self, opts.disabledTip)
		elseif opts.tip then
			ShowTip(self, opts.tip)
		end
	end)
	button:SetScript("OnLeave", function(self)
		self:UpdateState()
		HideTip()
	end)
	ForwardWheel(button)
	RegisterRefresh(function() button:UpdateState() end)
	return button
end

-- One button in the middle of the page, on its own row (EllesmereUI WideButton).
-- getText and isActive are read on every refresh; active = green accent style.
function Page:WideButton(getText, description, isActive, onClick)
	self:CloseRow()
	local frame = CreateFrame("Frame", nil, self.child)
	frame:SetSize(self:RowWidth(), 48)
	frame:SetPoint("TOPLEFT", self.child, "TOPLEFT", CONTENT_PAD, self.y)
	ForwardWheel(frame)
	local button = CreateFlatButton(frame, 220, 32, getText())
	button:SetPoint("CENTER")
	button.tooltip = description
	button:SetScript("OnClick", function()
		onClick()
		ApplyAndRefresh()
	end)
	ForwardWheel(button)
	RegisterRefresh(function()
		button.accent = isActive()
		button.label:SetText(getText())
		button:SetVisual(button:IsMouseOver())
	end)
	self.y = self.y - 48
end

function Page:Paragraph(text)
	self:CloseRow()
	local fs = NewText(self.child, 13, 0.53)
	fs:SetPoint("TOPLEFT", self.child, "TOPLEFT", CONTENT_PAD + 2, self.y - 10)
	fs:SetWidth(self:RowWidth() - 4)
	fs:SetWordWrap(true)
	fs:SetSpacing(4)
	fs:SetText(text)
	self.y = self.y - 10 - fs:GetStringHeight() - 6
end

-- One centered row of action items (EllesmereUI BuildActionCardRow, inline
-- form): icon, title and a dim description, thin dividers between them. A
-- "hero" item is boxed with an accent top edge. Card fields (each one may be
-- a function, read on every refresh): icon = { path, texcoord right, bottom },
-- title, desc, hero, accent ({ r, g, b }; nil = UI accent), iconSize;
-- sizeAlso = { title, desc } of its other form (the width fits both);
-- onClick; link = { text, onClick, accent } under a hero item.
function Page:ActionCards(cards)
	self:CloseRow()
	local ROW_H, ICON, DIV_GAP, DIV_H = 60, 26, 24, 40
	local GAP, BOX_L, BOX_GAP, BOX_R = 14, 24, 20, 14
	local LINK_GAP, LINK_H = 8, 16
	local function Get(v)
		if type(v) == "function" then
			return v()
		end
		return v
	end
	local hasLink = false
	for i = 1, #cards do
		if cards[i].link then
			hasLink = true
		end
	end
	local blockH = ROW_H + (hasLink and (LINK_GAP + LINK_H) or 0)
	local rowFrame = CreateFrame("Frame", nil, self.child)
	ForwardWheel(rowFrame)
	local parts, total = {}, (#cards - 1) * (DIV_GAP * 2 + 1)
	for i = 1, #cards do
		local spec = cards[i]
		local card = CreateFrame("Button", nil, rowFrame)
		card:SetFrameLevel(rowFrame:GetFrameLevel() + 2)
		ForwardWheel(card)
		local p = { spec = spec, card = card }
		p.icon = card:CreateTexture(nil, "ARTWORK")
		p.title = NewText(card, 13, 0.9)
		p.title:SetWordWrap(false)
		p.desc = NewText(card, 11, 0.45)
		p.desc:SetWordWrap(true)
		local w = 0
		local function Measure(t, d)
			p.title:SetText(t)
			p.desc:SetText(d)
			w = max(w, math.ceil(p.title:GetStringWidth()), math.ceil(p.desc:GetStringWidth()))
		end
		if spec.sizeAlso then
			Measure(spec.sizeAlso[1], spec.sizeAlso[2])
		end
		Measure(Get(spec.title), Get(spec.desc))
		p.textW = w
		-- The boxed form always keeps room for its padding, so both forms fit.
		p.boxable = spec.hero ~= nil
		p.width = (p.boxable and (BOX_L + BOX_R + BOX_GAP) or GAP) + ICON + w
		total = total + p.width
		parts[i] = p
	end
	local avail = self:RowWidth()
	local x0 = CONTENT_PAD + floor((avail - total) / 2)
	rowFrame:SetSize(total, blockH)
	rowFrame:SetPoint("TOPLEFT", self.child, "TOPLEFT", x0, self.y)

	local x = 0
	for i = 1, #parts do
		local p = parts[i]
		local spec, card = p.spec, p.card
		if i > 1 then
			local div = Solid(rowFrame, "ARTWORK", 1, 1, 1, 0.10)
			div:SetSize(1, DIV_H)
			div:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", x + DIV_GAP, -floor((ROW_H - DIV_H) / 2))
			x = x + DIV_GAP * 2 + 1
		end
		card:SetSize(p.width, ROW_H)
		card:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", x, 0)
		x = x + p.width
		if p.boxable then
			p.bg = Solid(card, "BACKGROUND", 0.077, 0.068, 0.058, 0.50)
			p.bg:SetAllPoints()
			p.border = AddBorder(card, 1, 1, 1, 0.12)
			p.line = card:CreateTexture(nil, "ARTWORK")
			p.line:SetPoint("TOPLEFT", 1, -1)
			p.line:SetPoint("TOPRIGHT", -1, -1)
			p.line:SetHeight(2)
		end
		if spec.link then
			local link = CreateFrame("Button", nil, rowFrame)
			p.link = link
			link.text = NewText(link, 12, 0.7)
			link.text:SetPoint("TOP")
			link.text:SetJustifyH("CENTER")
			link.text:SetText(spec.link.text)
			link:SetSize(link.text:GetStringWidth() + 10, LINK_H)
			link:SetPoint("TOP", card, "BOTTOM", 0, -LINK_GAP)
			local function Paint(hover)
				local ac = spec.link.accent or { r = ACCENT[1], g = ACCENT[2], b = ACCENT[3] }
				link.text:SetTextColor(ac.r, ac.g, ac.b, hover and 1 or 0.7)
			end
			link.Paint = Paint
			link:SetScript("OnEnter", function() Paint(true) end)
			link:SetScript("OnLeave", function() Paint(false) end)
			link:SetScript("OnClick", spec.link.onClick)
			ForwardWheel(link)
		end

		local function Paint(hover)
			local boxed = p.boxable and Get(spec.hero)
			local ac = Get(spec.accent) or { r = ACCENT[1], g = ACCENT[2], b = ACCENT[3] }
			local icon = Get(spec.icon)
			local size = spec.iconSize or ICON
			local padL = p.boxable and (boxed and BOX_L or floor(BOX_L / 2)) or 0
			p.icon:SetTexture(icon[1])
			p.icon:SetTexCoord(0, icon[2] or 1, 0, icon[3] or 1)
			p.icon:SetSize(size, size)
			p.icon:ClearAllPoints()
			p.icon:SetPoint("LEFT", card, "LEFT", padL + floor((ICON - size) / 2), 0)
			p.icon:SetVertexColor(ac.r, ac.g, ac.b)
			p.icon:SetAlpha(hover and 1 or (boxed and 0.6 or 0.75))
			local textX = padL + ICON + (boxed and BOX_GAP or GAP)
			p.title:ClearAllPoints()
			p.title:SetPoint("TOPLEFT", card, "LEFT", textX, ICON / 2 + 2)
			p.title:SetWidth(p.textW)
			p.title:SetText(Get(spec.title))
			p.title:SetAlpha(hover and 1 or 0.9)
			p.desc:ClearAllPoints()
			p.desc:SetPoint("TOPLEFT", p.title, "BOTTOMLEFT", 0, -4)
			p.desc:SetWidth(p.textW)
			p.desc:SetText(Get(spec.desc))
			p.desc:SetAlpha((boxed and 0.35 or 0.45) + (hover and not boxed and 0.15 or 0))
			if p.boxable then
				p.bg:SetShown(boxed)
				p.line:SetShown(boxed)
				p.line:SetTexture(ac.r, ac.g, ac.b, 0.6)
				p.bg:SetTexture(hover and 0.119 or 0.077, hover and 0.111 or 0.068, hover and 0.104 or 0.058, 0.50)
				p.border:SetColor(1, 1, 1, boxed and (hover and 0.22 or 0.12) or 0)
			end
			if p.link then
				p.link:SetShown(boxed and true or false)
				p.link.Paint(p.link:IsMouseOver())
			end
		end
		card:SetScript("OnEnter", function() Paint(true) end)
		card:SetScript("OnLeave", function() Paint(false) end)
		card:SetScript("OnClick", function()
			if spec.onClick then
				spec.onClick()
			end
			ApplyAndRefresh()
		end)
		RegisterRefresh(function() Paint(card:IsMouseOver()) end)
		Paint(false)
	end
	self.y = self.y - blockH - 6
end

-- Height of the fixed header (see CreatePage); the settings scroll below it.
function Page:SetHeaderHeight(h)
	h = floor((h or 0) + 0.5)
	if self.headerH == h then
		return
	end
	self.headerH = h
	self.headerHost:SetHeight(max(1, h))
	self.scroll:ClearAllPoints()
	self.scroll:SetPoint("TOPLEFT", contentHost, "TOPLEFT", 0, -h)
	self.scroll:SetPoint("BOTTOMRIGHT", contentHost, "BOTTOMRIGHT", 0, 0)
	self.viewH = CONTENT_H - h
	if self.scroll:IsShown() then
		self.scroll:UpdateScrollChildRect()
		self:UpdateThumb()
	end
end

-- A dropdown for a page header (the EllesmereUI centered bar picker).
function Page:HeaderDropdown(parent, width, height, getItems, getValue, getLabel, setValue)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(width, height)
	holder.SetHover = function() end
	local drop = CreateDropdown(holder, getItems, getValue, getLabel, setValue)
	drop:ClearAllPoints()
	drop:SetAllPoints(holder)
	RegisterRefresh(function() drop:Refresh() end)
	return holder, drop
end

-- A square icon button in the dropdown style (the Quick Keybind key button).
function Page:HeaderIconButton(parent, size, iconPath, iconSize, tooltip, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(size, size)
	b.bg = Solid(b, "BACKGROUND", DROPDOWN_BG[1], DROPDOWN_BG[2], DROPDOWN_BG[3], 0.9)
	b.bg:SetAllPoints()
	b.border = AddBorder(b, 1, 1, 1, 0.2)
	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetSize(iconSize, iconSize)
	icon:SetPoint("CENTER")
	icon:SetTexture(iconPath)
	icon:SetVertexColor(1, 1, 1, 0.5)
	local function Visual(hover)
		b.bg:SetTexture(DROPDOWN_BG[1], DROPDOWN_BG[2], DROPDOWN_BG[3], hover and 0.98 or 0.9)
		b.border:SetColor(1, 1, 1, hover and 0.3 or 0.2)
		icon:SetVertexColor(1, 1, 1, hover and 0.6 or 0.5)
	end
	b:SetScript("OnEnter", function(self)
		Visual(true)
		ShowTip(self, tooltip)
	end)
	b:SetScript("OnLeave", function()
		Visual(false)
		HideTip()
	end)
	b:SetScript("OnClick", function()
		HideTip()
		onClick()
	end)
	ForwardWheel(b)
	return b
end

-- Runs fn on every settings refresh (after each change), like the controls.
function Page:OnRefresh(fn)
	RegisterRefresh(fn)
	liveRefreshers[#liveRefreshers + 1] = fn
end

-- Reveal (scroll to and flash) a setting from outside the page.
function Page:RevealSetting(section, label)
	self:Reveal((section or "") .. "\1" .. label)
end

function Page:UpdateThumb()
	local range = self.scroll:GetVerticalScrollRange()
	if range <= 0 then
		self.track:Hide()
		self.thumb:Hide()
		return
	end
	local trackH = (self.viewH or CONTENT_H) - 8
	local total = trackH + range
	local thumbH = max(30, trackH * trackH / total)
	local pos = (trackH - thumbH) * self.scroll:GetVerticalScroll() / range
	self.thumb:SetHeight(thumbH)
	self.thumb:ClearAllPoints()
	self.thumb:SetPoint("TOPRIGHT", self.scroll, "TOPRIGHT", -12, -4 - pos)
	self.track:Show()
	self.thumb:Show()
end

function Page:ScrollBy(delta)
	CloseMenu()
	CloseCog()
	local range = self.scroll:GetVerticalScrollRange()
	local value = min(range, max(0, self.scroll:GetVerticalScroll() + delta))
	self.scroll:SetVerticalScroll(value)
	self:UpdateThumb()
end

function Page:Show()
	if self.headerHost then
		self.headerHost:Show()
	end
	self.scroll:Show()
	self.scroll:UpdateScrollChildRect()
	self:UpdateThumb()
end

function Page:Hide()
	if self.headerHost then
		self.headerHost:Hide()
	end
	self.scroll:Hide()
end

-- Short green glow on a search target (fill + border), fading out.
local FLASH_HOLD, FLASH_FADE = 0.6, 1.2
local flashDriver, flashFrame, flashTime

local function Flash(frame)
	if not frame.flashFill then
		frame.flashFill = AccentSolid(frame, "OVERLAY", 0)
		frame.flashFill:SetAllPoints()
		frame.flashBorder = AddBorder(frame, ACCENT[1], ACCENT[2], ACCENT[3], 0, "OVERLAY")
	end
	if not flashDriver then
		flashDriver = CreateFrame("Frame")
		flashDriver:SetScript("OnUpdate", function(self, elapsed)
			flashTime = flashTime + elapsed
			local f = 1
			if flashTime > FLASH_HOLD then
				f = max(0, 1 - (flashTime - FLASH_HOLD) / FLASH_FADE)
			end
			flashFrame.flashFill:SetTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.12 * f)
			flashFrame.flashBorder:SetColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.8 * f)
			if f <= 0 then
				self:Hide()
			end
		end)
	end
	if flashFrame and flashFrame ~= frame then
		flashFrame.flashFill:SetTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0)
		flashFrame.flashBorder:SetColor(ACCENT[1], ACCENT[2], ACCENT[3], 0)
	end
	flashFrame, flashTime = frame, 0
	flashDriver:Show()
end

-- Scrolls so the target is near the top of the page and flashes it.
function Page:Reveal(key)
	local target = self.targets[key]
	if not target then
		return
	end
	local range = max(0, self.child:GetHeight() - (self.viewH or CONTENT_H))
	self.scroll:SetVerticalScroll(min(range, max(0, -target.y - 40)))
	self:UpdateThumb()
	Flash(target.frame)
end

local function CreatePage(def)
	local page = setmetatable({ def = def, y = -6, rowIndex = 0, targets = {} }, Page)
	local scroll = CreateFrame("ScrollFrame", nil, contentHost)
	scroll:SetPoint("TOPLEFT", contentHost, "TOPLEFT", 0, 0)
	scroll:SetPoint("BOTTOMRIGHT", contentHost, "BOTTOMRIGHT", 0, 0)
	ForwardWheel(scroll)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(CONTENT_W, 10)
	scroll:SetScrollChild(child)
	page.scroll = scroll
	page.child = child

	page.track = Solid(scroll, "OVERLAY", 1, 1, 1, 0.02)
	page.track:SetWidth(4)
	page.track:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", -12, -4)
	page.track:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", -12, 4)
	page.thumb = Solid(scroll, "OVERLAY", 1, 1, 1, 0.27)
	page.thumb:SetWidth(4)

	def.build(page)
	child:SetHeight(-page.y + 24)
	-- def.header(page, host, width): a fixed area above the scrolling
	-- settings (EllesmereUI content header: the Action Bars bar picker and
	-- live preview). It returns its height; page:SetHeaderHeight changes it.
	if def.header then
		local host = CreateFrame("Frame", nil, contentHost)
		host:SetPoint("TOPLEFT", contentHost, "TOPLEFT", 0, 0)
		host:SetPoint("TOPRIGHT", contentHost, "TOPRIGHT", 0, 0)
		host:SetHeight(1)
		ForwardWheel(host)
		local line = Solid(host, "ARTWORK", 1, 1, 1, 0.06)
		line:SetHeight(1)
		line:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", CONTENT_PAD, 0)
		line:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -CONTENT_PAD, 0)
		page.headerHost = host
		page:SetHeaderHeight(def.header(page, host, CONTENT_W) or 0)
		host:Hide()
	end
	scroll:Hide()
	return page
end

---------------------------------------------------------------------------
-- Modules (sidebar entries)
---------------------------------------------------------------------------
-- Every EUI_*_Options.lua file of this addon adds one module with
-- ns.RegisterSettingsModule, in the EllesmereUI groups and order (the .toc
-- order). A file skips itself when its module addon is not loaded.
--   key, name, group (one of GROUPS) or fixed = true (rows under Unlock Mode: Global Settings, Profiles; icon / iconOn = art)
--   tabs = page defs { key, name, description, build(p) [, pageKey] }
--   reset = footer "Reset <name>" button, resetTip = its tooltip
--   onEnter / onLeave run when the module is shown or hidden (previews).
local GROUPS = { "Core Addons", "QoL Addons", "UI Reskin Addons" }
local MODULES = {}

ns.RegisterSettingsModule = function(def)
	if window then
		-- The sidebar is built once, with the modules known then.
		return
	end
	MODULES[#MODULES + 1] = def
end

-- Shared helpers for the page files.
ns.OptionsUtil = {
	-- { { key =, text = } } -> dropdown items
	KeyItems = function(list)
		local items = {}
		for i = 1, #list do
			items[i] = { name = list[i].text, value = list[i].key }
		end
		return items
	end,
	KeyLabel = function(list, value)
		for i = 1, #list do
			if list[i].key == value then
				return list[i].text
			end
		end
		return "?"
	end,
	-- ns.GetBarTextures() / ns.GetFonts() -> dropdown items
	MediaItems = function(list)
		local items = {}
		for i = 1, #list do
			items[i] = { name = list[i].name, value = list[i].path }
		end
		return items
	end,
}

local currentModule
local resetButton

local tabBars = {}

local function SelectTab(moduleIndex, tabIndex)
	CloseMenu()
	CloseCog()
	HideTip()
	local module = MODULES[moduleIndex]
	local def = module.tabs[tabIndex]
	pages[moduleIndex] = pages[moduleIndex] or {}
	-- def.pageKey: pages that change with a selection (the unit of the Unit
	-- Frames pages) are built once per key.
	local cacheKey = tabIndex
	if def.pageKey then
		cacheKey = tabIndex .. ":" .. tostring(def.pageKey())
	end
	local page = pages[moduleIndex][cacheKey]
	if not page then
		page = CreatePage(def)
		pages[moduleIndex][cacheKey] = page
	end
	if currentPage and currentPage ~= page then
		currentPage:Hide()
	end
	currentPage = page
	currentPage:Show()
	headerTitle:SetText(module.name)
	headerDesc:SetText(def.description)
	local buttons = tabBars[moduleIndex].buttons
	for i = 1, #buttons do
		buttons[i]:SetSelected(i == tabIndex)
	end
	module.selectedTab = tabIndex
	RefreshAll()
end

local function LeaveModule()
	local module = currentModule and MODULES[currentModule]
	if module and module.onLeave then
		module.onLeave()
	end
end

local function EnterModule()
	local module = currentModule and MODULES[currentModule]
	if module and module.onEnter and window:IsShown() then
		module.onEnter()
	end
end

local function SelectModule(moduleIndex)
	if currentModule ~= moduleIndex then
		LeaveModule()
		currentModule = moduleIndex
		EnterModule()
	end
	if resetButton then
		-- EllesmereUI: "Reset <Module>".
		resetButton.tooltip = MODULES[moduleIndex].resetTip
		resetButton.label:SetText("Reset " .. MODULES[moduleIndex].name)
		-- Modules with nothing to reset (Profiles) hide it, like EllesmereUI.
		resetButton:SetShown(MODULES[moduleIndex].reset ~= nil)
	end
	for i = 1, #navButtons do
		navButtons[i]:SetSelected(i == moduleIndex)
	end
	if ns._sidebarEnsureVisible then
		ns._sidebarEnsureVisible(navButtons[moduleIndex])
	end
	for i, bar in pairs(tabBars) do
		bar:SetShown(i == moduleIndex)
	end
	SelectTab(moduleIndex, MODULES[moduleIndex].selectedTab or 1)
end

-- Subtab (EllesmereUI): font 16, dim text, white on hover, white with a green
-- underline (text width + 14, 2 px) when active. Width = text width + 30.
local function CreateTabButton(bar, moduleIndex, tabIndex, def, x)
	local button = CreateFrame("Button", nil, bar)
	button.label = NewText(button, 16, 0.53)
	button.label:SetPoint("CENTER", 0, 0)
	button.label:SetJustifyH("CENTER")
	button.label:SetText(def.name)
	local textWidth = button.label:GetStringWidth()
	button:SetSize(textWidth + 30, TAB_BAR_H)
	button:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", x, 0)
	button.underline = AccentSolid(button, "ARTWORK", 1)
	button.underline:SetSize(textWidth + 14, 2)
	button.underline:SetPoint("BOTTOM", button, "BOTTOM", 0, 0)

	function button:SetVisual(hover)
		if self.selected then
			self.label:SetTextColor(1, 1, 1, 1)
		else
			self.label:SetTextColor(1, 1, 1, hover and 0.86 or 0.53)
		end
	end
	function button:SetSelected(selected)
		self.selected = selected
		self.underline:SetShown(selected)
		self:SetVisual(self:IsMouseOver())
	end
	button:SetScript("OnEnter", function(self) self:SetVisual(true) end)
	button:SetScript("OnLeave", function(self) self:SetVisual(false) end)
	button:SetScript("OnClick", function() SelectTab(moduleIndex, tabIndex) end)
	button:SetSelected(false)
	return button, button:GetWidth()
end

---------------------------------------------------------------------------
-- Sidebar rows (EllesmereUI DecorateSidebarButton)
---------------------------------------------------------------------------
local HOVER_TINT = { 0.85, 0.95, 0.90 }

-- Horizontal gradient from alpha a1 (left) to 0 (right).
local function Gradient(parent, layer, r, g, b, a1)
	local tex = parent:CreateTexture(nil, layer)
	tex:SetTexture(1, 1, 1, 1)
	tex:SetGradientAlpha("HORIZONTAL", r, g, b, a1, r, g, b, 0)
	tex:Hide()
	return tex
end

-- Selected: green bar on the left, green glow, thin top / bottom lines.
-- Hover: light glow and a light bar on the left.
local function DecorateSidebarButton(button)
	button.indicator = AccentSolid(button, "ARTWORK", 1)
	button.indicator:SetWidth(3)
	button.indicator:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 0)
	button.indicator:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", -1, 0)
	button.indicator:Hide()

	button.glow = AccentGradient(button, "BACKGROUND", 0.15)
	button.glow:SetAllPoints()
	button.glowTop = Gradient(button, "BORDER", 0.7, 0.7, 0.7, 0.5)
	button.glowTop:SetHeight(1)
	button.glowTop:SetPoint("TOPLEFT")
	button.glowTop:SetPoint("TOPRIGHT")
	button.glowBot = Gradient(button, "BORDER", 0.7, 0.7, 0.7, 0.5)
	button.glowBot:SetHeight(1)
	button.glowBot:SetPoint("BOTTOMLEFT")
	button.glowBot:SetPoint("BOTTOMRIGHT")

	button.hoverGlow = Gradient(button, "BACKGROUND", HOVER_TINT[1], HOVER_TINT[2], HOVER_TINT[3], 0.03)
	button.hoverGlow:SetAllPoints()
	button.hoverIndicator = Solid(button, "ARTWORK", HOVER_TINT[1], HOVER_TINT[2], HOVER_TINT[3], 0.25)
	button.hoverIndicator:SetWidth(3)
	button.hoverIndicator:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 0)
	button.hoverIndicator:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", -1, 0)
	button.hoverIndicator:Hide()

	button.highlight = Solid(button, "HIGHLIGHT", 1, 1, 1, 0.06)
	button.highlight:SetAllPoints()

	function button:ShowSelected(on)
		self.indicator:SetShown(on)
		self.glow:SetShown(on)
		self.glowTop:SetShown(on)
		self.glowBot:SetShown(on)
	end
	function button:ShowHover(on)
		self.hoverGlow:SetShown(on)
		self.hoverIndicator:SetShown(on)
	end
end

-- Unlock Mode: always the top row, with the EllesmereUI icon art. It is an
-- action, never "selected".
local function CreateUnlockButton(sidebar, onClick)
	local button = CreateFrame("Button", nil, sidebar)
	button:SetSize(SIDEBAR_W, NAV_H)
	button:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 0, -NAV_TOP)
	DecorateSidebarButton(button)
	-- 52 x 37 icon in a 64 x 64 TGA, drawn at 46 x 31 like EllesmereUI.
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetTexture(ART_PATH .. "unlockmode")
	button.icon:SetTexCoord(0, 52 / 64, 0, 37 / 64)
	button.icon:SetSize(NAV_ICON_W, NAV_ICON_H)
	button.icon:SetPoint("LEFT", button, "LEFT", 20, 0)
	button.icon:SetAlpha(0.6)
	button.label = NewText(button, 14, 0.6)
	button.label:SetPoint("LEFT", button.icon, "RIGHT", 10, 0)
	button.label:SetText("Unlock Mode")
	button:SetScript("OnEnter", function(self)
		self:ShowHover(true)
		self.label:SetTextColor(1, 1, 1, 0.86)
	end)
	button:SetScript("OnLeave", function(self)
		self:ShowHover(false)
		self.label:SetTextColor(1, 1, 1, 0.6)
	end)
	button:SetScript("OnClick", onClick)
	return button
end

-- Fixed rows under Unlock Mode (Global Settings, Profiles): row = 1, 2, ...
-- def.icon / def.iconOn = art in media\ui (default: the EllesmereUI settings
-- icon); white off art, green -on art while selected.
local function CreateGlobalButton(sidebar, def, onClick, row)
	local button = CreateFrame("Button", nil, sidebar)
	button:SetSize(SIDEBAR_W, NAV_H)
	button:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 0, -(NAV_TOP + NAV_H * (row or 1)))
	DecorateSidebarButton(button)
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetTexCoord(0, 52 / 64, 0, 37 / 64)
	button.icon:SetSize(NAV_ICON_W, NAV_ICON_H)
	button.icon:SetPoint("LEFT", button, "LEFT", 20, 0)
	button.label = NewText(button, 14, 0.6)
	button.label:SetPoint("LEFT", button.icon, "RIGHT", 10, 0)
	button.label:SetText(def.name)
	function button:SetVisual(hover)
		local alpha = 0.6
		if self.selected then
			alpha = 1
		elseif hover then
			alpha = 0.86
		end
		self.label:SetTextColor(1, 1, 1, alpha)
		self.icon:SetTexture(ART_PATH .. (self.selected and (def.iconOn or "settings-ig-on-2") or (def.icon or "settings-ig-2")))
		self.icon:SetAlpha(self.selected and 1 or 0.6)
		self:ShowHover(hover and not self.selected)
	end
	function button:SetSelected(selected)
		self.selected = selected
		self:ShowSelected(selected)
		self:SetVisual(self:IsMouseOver())
	end
	button:SetScript("OnEnter", function(self) self:SetVisual(true) end)
	button:SetScript("OnLeave", function(self) self:SetVisual(false) end)
	button:SetScript("OnClick", onClick)
	button:SetSelected(false)
	return button
end

-- Group header: green label, not clickable.
local function CreateGroupHeader(parent, text)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(SIDEBAR_W, GROUP_ROW_H)
	row.label = NewText(row, 15, 1)
	AccentText(row.label, 1)
	row.label:SetPoint("LEFT", row, "LEFT", 20, 0)
	row.label:SetText(text)
	return row
end

-- Module row: indented label, no icon. Normal white 0.6, hover 0.86, selected 1.
local function CreateModuleRow(parent, def, onClick)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(SIDEBAR_W, CHILD_ROW_H)
	DecorateSidebarButton(button)
	button.label = NewText(button, 14, 0.6)
	button.label:SetPoint("LEFT", button, "LEFT", 36, 0)
	button.label:SetText(def.name)

	function button:SetVisual(hover)
		local alpha = 0.6
		if self.selected then
			alpha = 1
		elseif hover then
			alpha = 0.86
		end
		self.label:SetTextColor(1, 1, 1, alpha)
		self:ShowHover(hover and not self.selected)
	end
	function button:SetSelected(selected)
		self.selected = selected
		self:ShowSelected(selected)
		self:SetVisual(self:IsMouseOver())
	end
	button:SetScript("OnEnter", function(self) self:SetVisual(true) end)
	button:SetScript("OnLeave", function(self) self:SetVisual(false) end)
	button:SetScript("OnClick", onClick)
	button:SetSelected(false)
	-- Profile Sync icon at the right (EllesmereUI_ProfileSync.lua).
	if ns.AttachSidebarSync then
		ns.AttachSidebarSync(button, def)
	end
	return button
end

---------------------------------------------------------------------------
-- Unlock Mode: the EllesmereUI core runs the retail Unlock Mode
-- (EUI_UnlockMode*.lua). The window hands it its frame and the calls it makes
-- to hide, reopen and navigate the window (retail EllesmereUI panel API).
---------------------------------------------------------------------------
local function StartUnlockFromWindow()
	if InCombatLockdown() then
		return
	end
	-- Back on this module and tab when Unlock Mode closes.
	ns._unlockReturnModule = currentModule and MODULES[currentModule].key or nil
	ns._unlockReturnPage = currentModule and MODULES[currentModule].selectedTab or nil
	CloseMenu()
	HideTip()
	if ns.EnterUnlockMode then
		ns.EnterUnlockMode()
	end
end

---------------------------------------------------------------------------
-- Window position (EllesmereUIDB.window) and Window Scale (EllesmereUIDB.
-- panelScale, like EllesmereUI_Panel.lua): the window is pixel perfect
-- (1 unit = 1 screen pixel) times the Window Scale, 75% to 200%.
---------------------------------------------------------------------------
-- v = 2: 1 unit = 1 art pixel. Older saved sizes used other units, so they are dropped.
local WINDOW_STATE_VERSION = 2

local function WindowDB()
	if type(EllesmereUIDB) ~= "table" then
		EllesmereUIDB = {}
	end
	local state = EllesmereUIDB.window
	if type(state) ~= "table" or state.v ~= WINDOW_STATE_VERSION then
		state = { v = WINDOW_STATE_VERSION }
		EllesmereUIDB.window = state
	end
	return state
end

-- 1 unit = 1 screen pixel, like EllesmereUI. 5.4.8 has no
-- GetPhysicalScreenSize, so the height comes from the resolution setting.
local function PixelPerfectScale()
	local height = ns.PhysicalHeight()
	return 768 / height / UIParent:GetEffectiveScale()
end

local function PanelScale()
	local db = type(EllesmereUIDB) == "table" and EllesmereUIDB or {}
	local scale = tonumber(db.panelScale)
	if not scale then
		-- Before the Window Scale slider the corner grips saved the window scale
		-- itself (state.scale): keep that size, on the nearest 5% step.
		local old = type(db.window) == "table" and tonumber(db.window.scale)
		scale = old and floor(old / PixelPerfectScale() * 20 + 0.5) / 20 or 1
		scale = max(PANEL_SCALE_MIN, min(PANEL_SCALE_MAX, scale))
		if type(EllesmereUIDB) == "table" then
			EllesmereUIDB.panelScale = scale
			if type(db.window) == "table" then
				db.window.scale = nil
			end
		end
	end
	return max(PANEL_SCALE_MIN, min(PANEL_SCALE_MAX, scale))
end

-- Stored in UIParent units: the top left corner.
local function SaveWindowState()
	local left, top = window:GetLeft(), window:GetTop()
	if not left or not top then
		return
	end
	local scale = window:GetScale()
	local state = WindowDB()
	state.left = left * scale
	state.top = top * scale
end

local function ApplyWindowState()
	local state = WindowDB()
	local scale = PixelPerfectScale() * PanelScale()
	window:SetScale(scale)
	window:ClearAllPoints()
	if tonumber(state.left) and tonumber(state.top) then
		window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", state.left / scale, state.top / scale)
	else
		window:SetPoint("CENTER")
	end
end

-- Runs change() (a UI Scale change) and keeps the settings window at the
-- same size and place on the screen, like EllesmereUI's panel.
ns.KeepWindowAcrossScale = function(change)
	if not window then
		change()
		return
	end
	local uiBefore = UIParent:GetEffectiveScale()
	local effBefore = window:GetEffectiveScale()
	local left, top = window:GetLeft(), window:GetTop()
	change()
	local uiAfter = UIParent:GetEffectiveScale()
	if abs(uiAfter - uiBefore) < 0.00001 or uiAfter <= 0 then
		return
	end
	window:SetScale(effBefore / uiAfter)
	if left and top then
		local eff = window:GetEffectiveScale()
		window:ClearAllPoints()
		window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * effBefore / eff, top * effBefore / eff)
	end
	SaveWindowState()
end

-- SetPanelScale(userScale, pin): saves the Window Scale and glides the window
-- to it (0.12 s, ease-out). pin stays put on the screen: a region of the
-- window (the slider passes its track, so it never slides away from the
-- cursor), "cursor" (Shift + mouse wheel zooms about the mouse) or nil (the
-- window's center).
local SetPanelScale, StepPanelScale
local scaleListeners = {}
do
	local SCALE_DUR = 0.12
	local anim = CreateFrame("Frame")
	local scaleFrom, scaleTo, scaleElapsed
	local pinX, pinY, pinOX, pinOY

	-- Puts the pin's point back on its screen spot at the current scale.
	local function HoldPin()
		if not pinX then
			return
		end
		local s = window:GetEffectiveScale()
		window:ClearAllPoints()
		window:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", pinX / s - pinOX, pinY / s - pinOY)
	end

	local function OnUpdate(self, elapsed)
		scaleElapsed = scaleElapsed + elapsed
		local t = min(1, scaleElapsed / SCALE_DUR)
		local done = t >= 1
		window:SetScale(done and scaleTo or (scaleFrom + (scaleTo - scaleFrom) * t * (2 - t)))
		HoldPin()
		if done then
			self:SetScript("OnUpdate", nil)
			pinX = nil
			SaveWindowState()
			ApplyWindowState()
			for i = 1, #scaleListeners do
				scaleListeners[i]()
			end
		end
	end

	SetPanelScale = function(userScale, pin)
		userScale = max(PANEL_SCALE_MIN, min(PANEL_SCALE_MAX, userScale or 1))
		if type(EllesmereUIDB) == "table" then
			EllesmereUIDB.panelScale = userScale
		end
		if not window then
			return
		end
		pinX = nil
		local cx, cy
		if pin == "cursor" then
			local s = window:GetEffectiveScale()
			local x, y = GetCursorPosition()
			cx, cy = x / s, y / s
		else
			cx, cy = (pin or window):GetCenter()
		end
		local left, bottom = window:GetLeft(), window:GetBottom()
		if cx and cy and left and bottom then
			local s = window:GetEffectiveScale()
			pinOX, pinOY = cx - left, cy - bottom
			pinX, pinY = cx * s, cy * s
		end
		-- A new target mid-glide carries on from where the window is now.
		scaleFrom = window:GetScale()
		scaleTo = PixelPerfectScale() * userScale
		scaleElapsed = 0
		anim:SetScript("OnUpdate", OnUpdate)
	end

	-- One 5% step (delta > 0 grows). An off-step value steps to the next 5% mark.
	-- True when it changed.
	StepPanelScale = function(delta, pin)
		local cur = PanelScale() * 100
		local v
		if delta > 0 then
			v = floor(cur / 5 + 1e-6) * 5 + 5
		else
			v = math.ceil(cur / 5 - 1e-6) * 5 - 5
		end
		v = max(PANEL_SCALE_MIN * 100, min(PANEL_SCALE_MAX * 100, v))
		if abs(v - cur) < 0.01 then
			return false
		end
		SetPanelScale(v / 100, pin)
		return true
	end
end

-- Window Scale: the header slider left of the close X (EllesmereUI
-- EUI__General_Options.lua). 5% steps from 75% to 200%: a drag shows its value
-- live and applies on release, the mouse wheel steps one notch per tick.
-- Shift + mouse wheel anywhere on the window steps too and flashes the control.
local function BuildScaleControl()
	local MIN, MAX = PANEL_SCALE_MIN * 100, PANEL_SCALE_MAX * 100
	local STEP, TRACK_W, PCT_W, THUMB = 5, 110, 40, 12

	local ctl = CreateFrame("Frame", nil, panel)
	ctl:SetFrameLevel(panel:GetFrameLevel() + 20)
	ctl:SetHeight(24)
	ctl:SetPoint("RIGHT", window, "TOPRIGHT", -110, -31)

	local pctFs = NewText(ctl, 13, 0.9)
	pctFs:SetWidth(PCT_W)
	pctFs:SetJustifyH("RIGHT")
	pctFs:SetPoint("RIGHT", ctl, "RIGHT", 0, 0)
	local function ShowPct(v)
		pctFs:SetText(format("%d%%", floor(v + 0.5)))
	end
	local function SavedPct()
		return PanelScale() * 100
	end

	local track = CreateFrame("Frame", nil, ctl)
	track:SetSize(TRACK_W, 20)
	track:SetPoint("RIGHT", pctFs, "LEFT", -10, 0)
	track:EnableMouse(true)
	local trackDark = Solid(track, "BACKGROUND", 1, 1, 1, 0.16)
	trackDark:SetSize(TRACK_W, 4)
	trackDark:SetPoint("CENTER")
	local fill = AccentSolid(track, "BORDER", 0.75)
	fill:SetHeight(4)
	fill:SetPoint("LEFT", trackDark, "LEFT", 0, 0)
	local blocker = Solid(track, "ARTWORK", PANEL_BG[1], PANEL_BG[2], PANEL_BG[3], 1)
	blocker:SetSize(THUMB, THUMB)
	blocker:SetPoint("CENTER", fill, "RIGHT", 0, 0)
	local thumb = AccentSolid(track, "OVERLAY", 1)
	thumb:SetSize(THUMB, THUMB)
	thumb:SetPoint("CENTER", fill, "RIGHT", 0, 0)

	local pending -- the dragged value, shown until the release applies it
	local function Place(v)
		local ratio = max(0, min(1, (v - MIN) / (MAX - MIN)))
		fill:SetWidth(max(1, floor(TRACK_W * ratio + 0.5)))
	end
	local function Refresh()
		pending = nil
		ShowPct(SavedPct())
		Place(SavedPct())
	end
	local function Apply(v)
		ShowPct(v)
		if abs(v - SavedPct()) >= 0.01 then
			SetPanelScale(v / 100, track)
		end
	end
	local function FromCursor()
		local x = GetCursorPosition() / track:GetEffectiveScale()
		local ratio = max(0, min(1, (x - (trackDark:GetLeft() or 0)) / TRACK_W))
		local v = MIN + floor(ratio * (MAX - MIN) / STEP + 0.5) * STEP
		return max(MIN, min(MAX, v))
	end
	local function EndDrag(self)
		self:SetScript("OnUpdate", nil)
		if pending then
			local v = pending
			pending = nil
			Apply(v)
		end
	end
	track:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" then
			return
		end
		pending = FromCursor()
		ShowPct(pending)
		Place(pending)
		self:SetScript("OnUpdate", function(s)
			if not IsMouseButtonDown("LeftButton") then
				EndDrag(s)
				return
			end
			pending = FromCursor()
			ShowPct(pending)
			Place(pending)
		end)
	end)
	track:SetScript("OnMouseUp", EndDrag)

	local label = NewText(ctl, 13, 0.6)
	label:SetText("Window Scale")
	label:SetPoint("RIGHT", track, "LEFT", -16, 0)
	ctl:SetWidth(PCT_W + 10 + TRACK_W + 16 + label:GetStringWidth())
	ctl:EnableMouseWheel(true)
	ctl:SetScript("OnMouseWheel", function(_, delta)
		if pending then
			return
		end
		if StepPanelScale(delta, track) then
			ShowPct(SavedPct())
			Place(SavedPct())
		end
	end)

	-- Accent outline round the control: lights up on Shift + wheel and fades.
	local glowHost = CreateFrame("Frame", nil, ctl)
	glowHost:SetPoint("TOPLEFT", ctl, "TOPLEFT", -10, 6)
	glowHost:SetPoint("BOTTOMRIGHT", ctl, "BOTTOMRIGHT", 8, -6)
	local glow = AddBorder(glowHost, ACCENT[1], ACCENT[2], ACCENT[3], 0, "OVERLAY")
	local glowTime
	glowHost:SetScript("OnUpdate", function(self, elapsed)
		if not glowTime then
			return
		end
		glowTime = glowTime + elapsed
		local f = glowTime < 0.3 and 1 or max(0, 1 - (glowTime - 0.3) / 0.6)
		glow:SetColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.9 * f)
		if f <= 0 then
			glowTime = nil
		end
	end)

	ShiftWheelScale = function(delta)
		if not IsShiftKeyDown() or pending then
			return false
		end
		if StepPanelScale(delta, "cursor") then
			Refresh()
			glowTime = 0
		end
		return true
	end
	-- Any scale change (this slider, Shift + wheel) lands here once its glide ends.
	scaleListeners[#scaleListeners + 1] = function()
		if not pending then
			Refresh()
		end
	end
	window:HookScript("OnShow", function()
		-- Screen resolution or UI scale may have changed since the last open.
		ApplyWindowState()
		Refresh()
	end)
	Refresh()
end

---------------------------------------------------------------------------
-- Search (EllesmereUI global search): results popup under the search box.
-- Every tab, section and setting is a result; clicking one opens its module
-- and tab, scrolls to it and flashes it.
---------------------------------------------------------------------------
local SEARCH_METHODS = {
	Section = true, Toggle = true, Slider = true, Dropdown = true,
	MultiSelect = true, Color = true, Button = true, ColorRow = true, Label = true,
}
local RESULT_ROW_H = 34
local RESULT_ROW_GAP = 4
local MAX_RESULTS = 12
local function AccentHex()
	return format("|cff%02x%02x%02x", floor(ACCENT[1] * 255 + 0.5), floor(ACCENT[2] * 255 + 0.5), floor(ACCENT[3] * 255 + 0.5))
end
-- EllesmereUI eui-arrow-right, 30 x 30 art padded to 32 x 32.
local BREADCRUMB = " |T" .. ART_PATH .. "eui-arrow-right:12:12:0:0:32:32:0:30:0:30|t "

local searchIndex = {}
local searchPopup

-- Runs every page builder on a recorder to collect tabs, sections and setting
-- labels. Also fills module.searchText, used by the sidebar filter.
local function BuildSearchIndex()
	for m = 1, #MODULES do
		local module = MODULES[m]
		local words = { module.name:lower() }
		for t = 1, #module.tabs do
			local tab = module.tabs[t]
			words[#words + 1] = tab.name:lower()
			local base = module.name .. " " .. tab.name
			searchIndex[#searchIndex + 1] = {
				kind = "page", module = m, tab = t, label = tab.name,
				lLabel = tab.name:lower(), lDesc = (tab.description or ""):lower(),
				lAll = base:lower(),
			}
			local section
			local recorder = setmetatable({}, {
				__index = function(_, method)
					return function(_, text, description)
						if type(text) ~= "string" then
							return
						end
						words[#words + 1] = text:lower()
						if not SEARCH_METHODS[method] or text == "" then
							return
						end
						local entry = {
							module = m, tab = t, label = text, section = section,
							lLabel = text:lower(),
							lDesc = type(description) == "string" and description:lower() or "",
						}
						if method == "Section" then
							section = text
							entry.kind = "section"
							entry.section = nil
							entry.key = "\2" .. text
						else
							entry.kind = "setting"
							entry.key = (section or "") .. "\1" .. text
						end
						entry.lAll = (base .. " " .. (entry.section or "") .. " " .. text):lower()
						searchIndex[#searchIndex + 1] = entry
					end
				end,
			})
			tab.build(recorder)
		end
		module.searchText = table.concat(words, "\n")
	end
end

-- Letters of needle in order inside haystack; tighter runs score higher.
local function FuzzyScore(haystack, needle)
	local hi, score, run = 1, 0, 0
	for ni = 1, #needle do
		local c = needle:byte(ni)
		local found
		while hi <= #haystack do
			local same = haystack:byte(hi) == c
			hi = hi + 1
			if same then
				found = true
				break
			end
			run = 0
		end
		if not found then
			return nil
		end
		run = run + 1
		score = score + run
	end
	return score
end

local function ScoreEntry(entry, needle, words)
	local label = entry.lLabel
	local score
	if label == needle then
		score = 1000
	else
		local s = label:find(needle, 1, true)
		if s == 1 then
			score = 900
		elseif s and label:sub(s - 1, s - 1):find("[%s%p]") then
			score = 800
		elseif s then
			score = 700
		end
	end
	if not score and entry.kind == "page" and MODULES[entry.module].name:lower():find(needle, 1, true) then
		score = 600
	end
	if not score and #words > 1 then
		-- "spell history icon": every word somewhere in module, tab, section or label.
		local all = true
		for i = 1, #words do
			if not entry.lAll:find(words[i], 1, true) then
				all = false
				break
			end
		end
		if all then
			score = 500
		end
	end
	if not score and entry.lDesc:find(needle, 1, true) then
		score = 300
	end
	if not score and #needle >= 3 then
		local fuzzy = FuzzyScore(label, needle)
		if fuzzy and fuzzy >= #needle + 2 then
			score = 100 + fuzzy
		end
	end
	if not score then
		return nil
	end
	-- Shorter labels first; pages before sections before settings on a tie.
	local kindBonus = entry.kind == "page" and 3 or entry.kind == "section" and 2 or 0
	return score + kindBonus - #label * 0.01
end

local function SearchIndex(query)
	local needle = (query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if needle == "" then
		return {}
	end
	local words = {}
	for w in needle:gmatch("%S+") do
		words[#words + 1] = w
	end
	local scored = {}
	for i = 1, #searchIndex do
		local s = ScoreEntry(searchIndex[i], needle, words)
		if s then
			scored[#scored + 1] = { entry = searchIndex[i], score = s, order = i }
		end
	end
	table.sort(scored, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.order < b.order
	end)
	local results = {}
	for i = 1, min(#scored, MAX_RESULTS) do
		results[i] = scored[i].entry
	end
	return results
end

local revealDriver
local function JumpToResult(entry, searchBox)
	MODULES[entry.module].selectedTab = entry.tab
	SelectModule(entry.module)
	local page = currentPage
	if entry.key then
		page:Reveal(entry.key)
		-- Again on the next frame: a page built just now may not have its
		-- final scroll size yet.
		revealDriver = revealDriver or CreateFrame("Frame")
		revealDriver:SetScript("OnUpdate", function(self)
			self:SetScript("OnUpdate", nil)
			if currentPage == page then
				local range = max(0, page.child:GetHeight() - (page.viewH or CONTENT_H))
				local target = page.targets[entry.key]
				if target then
					page.scroll:SetVerticalScroll(min(range, max(0, -target.y - 40)))
					page:UpdateThumb()
				end
			end
		end)
	else
		page.scroll:SetVerticalScroll(0)
		page:UpdateThumb()
	end
	searchPopup:Hide()
	searchBox:SetText("")
	searchBox:ClearFocus()
end

local function BuildSearchPopup(search, searchBox)
	local popup = CreateFrame("Frame", nil, search)
	searchPopup = popup
	popup:SetWidth(380)
	popup:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -4)
	popup:SetFrameStrata("DIALOG")
	popup:SetFrameLevel(100)
	popup:SetClampedToScreen(true)
	popup:EnableMouse(true)
	popup:Hide()
	Solid(popup, "BACKGROUND", 0.098, 0.090, 0.082, 0.97):SetAllPoints()
	AddBorder(popup, 1, 1, 1, 0.12)

	local results, selected = {}, 1
	local rows = {}

	local function SetSelected(i)
		if rows[selected] then
			rows[selected].hl:SetTexture(1, 1, 1, 0)
		end
		selected = i
		if rows[selected] then
			rows[selected].hl:SetTexture(1, 1, 1, 0.08)
		end
	end

	for i = 1, MAX_RESULTS do
		local row = CreateFrame("Button", nil, popup)
		row:SetHeight(RESULT_ROW_H)
		local y = -4 - (i - 1) * (RESULT_ROW_H + RESULT_ROW_GAP)
		row:SetPoint("TOPLEFT", popup, "TOPLEFT", 5, y)
		row:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -5, y)
		row.hl = Solid(row, "ARTWORK", 1, 1, 1, 0)
		row.hl:SetAllPoints()
		row.label = NewText(row, 14, 1)
		row.label:SetTextColor(0.85, 0.85, 0.88, 1)
		row.label:SetShadowOffset(1, -1)
		row.label:SetShadowColor(0, 0, 0, 1)
		row.label:SetPoint("LEFT", row, "LEFT", 8, 8)
		row.label:SetPoint("RIGHT", row, "RIGHT", -8, 8)
		row.label:SetWordWrap(false)
		row.sub = NewText(row, 12, 0.45)
		row.sub:SetShadowOffset(1, -1)
		row.sub:SetShadowColor(0, 0, 0, 1)
		row.sub:SetPoint("LEFT", row, "LEFT", 8, -9)
		row.sub:SetPoint("RIGHT", row, "RIGHT", -8, -9)
		row.sub:SetWordWrap(false)
		row:SetScript("OnEnter", function(self) self.hl:SetTexture(1, 1, 1, 0.08) end)
		row:SetScript("OnLeave", function(self) self.hl:SetTexture(1, 1, 1, i == selected and 0.08 or 0) end)
		row:SetScript("OnClick", function(self)
			if self.entry then
				JumpToResult(self.entry, searchBox)
			end
		end)
		row:Hide()
		rows[i] = row
	end

	local function Run()
		results = SearchIndex(searchBox:GetText())
		for i = 1, MAX_RESULTS do
			local row, entry = rows[i], results[i]
			row.entry = entry
			if entry then
				local module = MODULES[entry.module]
				local tabName = module.tabs[entry.tab].name
				if entry.kind == "page" then
					row.label:SetText(AccentHex() .. "Page:|r " .. entry.label)
					row.sub:SetText(module.name)
				elseif entry.kind == "section" then
					row.label:SetText(AccentHex() .. "Section:|r " .. entry.label)
					row.sub:SetText(module.name .. BREADCRUMB .. tabName)
				else
					row.label:SetText(entry.label)
					row.sub:SetText(module.name .. BREADCRUMB .. tabName)
				end
				row:Show()
			else
				row:Hide()
			end
		end
		SetSelected(1)
		if #results > 0 then
			popup:SetHeight(#results * (RESULT_ROW_H + RESULT_ROW_GAP) - RESULT_ROW_GAP + 8)
			popup:Show()
		else
			popup:Hide()
		end
	end

	local function Step(d)
		if #results > 0 and popup:IsShown() then
			SetSelected((selected - 1 + d) % #results + 1)
		end
	end

	-- Click anywhere else closes the results. The 5.4.8 API has no
	-- GLOBAL_MOUSE_DOWN, so watch the buttons only while the popup is shown.
	popup:SetScript("OnShow", function(self)
		self.wasDown = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
	end)
	popup:SetScript("OnUpdate", function(self)
		local down = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
		if down and not self.wasDown and not self:IsMouseOver() and not search:IsMouseOver() then
			self:Hide()
		end
		self.wasDown = down
	end)

	searchBox:HookScript("OnTextChanged", Run)
	searchBox:HookScript("OnEditFocusGained", function(self)
		if (self:GetText() or "") ~= "" then
			Run()
		end
	end)
	searchBox:SetScript("OnEnterPressed", function(self)
		if popup:IsShown() and results[selected] then
			JumpToResult(results[selected], self)
		else
			self:ClearFocus()
		end
	end)
	searchBox:SetScript("OnTabPressed", function() Step(IsShiftKeyDown() and -1 or 1) end)
	searchBox:SetScript("OnArrowPressed", function(_, key)
		if key == "UP" then
			Step(-1)
		elseif key == "DOWN" then
			Step(1)
		end
	end)
end

-- Header (title, description, tab bars), close button, footer, content
-- host and the Window Scale control. Separate from BuildWindow: Lua 5.1 allows a
-- function at most 60 upvalues.
local function BuildHeaderAndFooter()
	-- Header: module title and the description of the open tab (the banner
	-- glow is in the art), then the tab bar on the dark band below it.
	local header = CreateFrame("Frame", nil, panel)
	header:SetPoint("TOPLEFT", SIDEBAR_W, 0)
	header:SetSize(CONTENT_W, HEADER_H)
	headerTitle = NewText(header, 36, 1)
	headerTitle:SetPoint("TOPLEFT", header, "TOPLEFT", CONTENT_PAD, -35)
	headerDesc = NewText(header, 14, 0.53)
	headerDesc:SetPoint("TOPLEFT", headerTitle, "BOTTOMLEFT", 2, -12)
	headerDesc:SetWidth(CONTENT_W - CONTENT_PAD * 2)

	for m = 1, #MODULES do
		local bar = CreateFrame("Frame", nil, header)
		bar:SetSize(CONTENT_W, TAB_BAR_H)
		bar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -9, 0)
		bar.buttons = {}
		local x = CONTENT_PAD
		for t = 1, #MODULES[m].tabs do
			local button, width = CreateTabButton(bar, m, t, MODULES[m].tabs[t], x)
			bar.buttons[t] = button
			x = x + width + 6
		end
		bar:Hide()
		tabBars[m] = bar
	end

	-- The close "X" box is painted in the art; this invisible 40 x 40 button
	-- sits on top of it and shows a light border on hover.
	local close = CreateFrame("Button", nil, panel)
	close:SetSize(40, 40)
	close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -14, -11)
	close:SetFrameLevel(panel:GetFrameLevel() + 20)
	close.border = AddBorder(close, 1, 1, 1, 0)
	close:SetScript("OnEnter", function(self) self.border:SetColor(1, 1, 1, 0.5) end)
	close:SetScript("OnLeave", function(self) self.border:SetColor(1, 1, 1, 0) end)
	close:SetScript("OnMouseDown", function(self) self.border:SetColor(1, 1, 1, 0.85) end)
	close:SetScript("OnMouseUp", function(self) self.border:SetColor(1, 1, 1, self:IsMouseOver() and 0.5 or 0) end)
	close:SetScript("OnClick", function() window:Hide() end)

	-- Footer: "Reset <Module>" and "Reload UI" on the left, "Close" on the right.
	local footer = CreateFrame("Frame", nil, panel)
	footer:SetPoint("BOTTOMLEFT", SIDEBAR_W, 0)
	footer:SetSize(CONTENT_W, FOOTER_H)

	-- Resets only the module that is open.
	resetButton = CreateFlatButton(footer, 180, 36, "Reset")
	resetButton:SetPoint("BOTTOMLEFT", 24, 24)
	resetButton:SetScript("OnClick", function()
		local module = MODULES[currentModule]
		if module then
			StaticPopup_Show("EUI_MODULE_RESET", module.name, nil, module)
		end
	end)

	local reload = CreateFlatButton(footer, 180, 36, "Reload UI")
	reload:SetPoint("BOTTOMLEFT", resetButton, "BOTTOMRIGHT", 20, 0)
	reload.tooltip = "Reload the user interface."
	reload:SetScript("OnClick", function() ReloadUI() end)

	local closeButton = CreateFlatButton(footer, 160, 36, "Close", true)
	closeButton:SetPoint("BOTTOMRIGHT", -24, 24)
	closeButton:SetScript("OnClick", function() window:Hide() end)

	-- Content
	contentHost = CreateFrame("Frame", nil, panel)
	contentHost:SetPoint("TOPLEFT", SIDEBAR_W, -CONTENT_TOP)
	contentHost:SetSize(CONTENT_W, CONTENT_H)

	BuildScaleControl()
end

-- Window art: 3 x 3 tiles at 1 unit = 1 art pixel. The shadow part hangs
-- outside the window frame. Two layers, so a theme change (Global Settings >
-- General > EUI Options Theme) crossfades like EllesmereUI ApplyThemeBG.
local artLayers = {}
local artFront = 1
local artFader
local ART_FADE = 0.35

local function PaintArt(layer, theme)
	local folder = ns.THEME_ART and ns.THEME_ART[ns.ResolveFactionTheme(theme)] or ""
	local tr, tg, tb
	if ns.ThemeTint then
		tr, tg, tb = ns.ThemeTint(theme, ns.ResolveThemeColor(theme))
	end
	for i = 1, #layer do
		local tile = layer[i]
		tile:SetTexture(format("%s%swindow_%d_%d", ART_PATH, folder, tile.r, tile.c))
		if tr then
			tile:SetDesaturated(true)
			tile:SetVertexColor(tr, tg, tb, 1)
		else
			tile:SetDesaturated(false)
			tile:SetVertexColor(1, 1, 1, 1)
		end
	end
end

local function SetArtAlpha(layer, alpha)
	for i = 1, #layer do
		layer[i]:SetAlpha(alpha)
	end
end

local function BuildThemeArt()
	for l = 1, 2 do
		local layer = {}
		local tileTop = 0
		for r = 1, 3 do
			for c = 1, 3 do
				local tile = window:CreateTexture(nil, "BACKGROUND", nil, l - 1)
				tile.r, tile.c = r, c
				tile:SetSize(ART_TILE_W, ART_ROW_H[r])
				tile:SetPoint("TOPLEFT", window, "TOPLEFT", (c - 1) * ART_TILE_W - ART_LEFT, -(tileTop - ART_TOP))
				layer[#layer + 1] = tile
			end
			tileTop = tileTop + ART_ROW_H[r]
		end
		artLayers[l] = layer
	end
	PaintArt(artLayers[1], ns.GetActiveTheme and ns.GetActiveTheme() or "EllesmereUI")
	SetArtAlpha(artLayers[2], 0)
	artFader = CreateFrame("Frame", nil, window)
	artFader:Hide()
	artFader:SetScript("OnUpdate", function(self, elapsed)
		self.t = self.t + elapsed
		local p = min(1, self.t / ART_FADE)
		SetArtAlpha(artLayers[artFront], p)
		if p >= 1 then
			SetArtAlpha(artLayers[3 - artFront], 0)
			self:Hide()
		end
	end)
end

-- New theme: the new art fades in over the old one.
ns.ApplyThemeArt = function(theme, instant)
	if not window then
		return
	end
	local back = artFront
	artFront = 3 - artFront
	local front = artLayers[artFront]
	PaintArt(front, theme)
	for i = 1, #front do
		front[i]:SetDrawLayer("BACKGROUND", 1)
		artLayers[back][i]:SetDrawLayer("BACKGROUND", 0)
	end
	if instant then
		SetArtAlpha(front, 1)
		SetArtAlpha(artLayers[back], 0)
		return
	end
	SetArtAlpha(front, 0)
	SetArtAlpha(artLayers[back], 1)
	artFader.t = 0
	artFader:Show()
end

-- Tint only (Custom Color picker): repaint the art on screen.
ns.ApplyThemeTint = function()
	if window then
		PaintArt(artLayers[artFront], ns.GetActiveTheme())
	end
end

local function BuildWindow()
	window = CreateFrame("Frame", "EllesmereUISettings", UIParent)
	window:SetSize(WIN_W, WIN_H)
	window:SetFrameStrata("HIGH")
	window:SetToplevel(true)
	window:SetClampedToScreen(true)
	window:EnableMouse(true)
	window:SetMovable(true)
	window:RegisterForDrag("LeftButton")
	window:SetScript("OnDragStart", window.StartMoving)
	window:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		-- Position is saved by this addon, not by the game's layout cache.
		self:SetUserPlaced(false)
		SaveWindowState()
	end)
	-- Shift + mouse wheel anywhere on the window steps the Window Scale.
	window:EnableMouseWheel(true)
	window:SetScript("OnMouseWheel", function(_, delta)
		if ShiftWheelScale then
			ShiftWheelScale(delta)
		end
	end)
	tinsert(UISpecialFrames, window:GetName())
	ApplyWindowState()

	BuildThemeArt()

	panel = CreateFrame("Frame", nil, window)
	panel:SetAllPoints()

	-- Sidebar (its background, lines and logo panel are in the art)
	local sidebar = CreateFrame("Frame", nil, panel)
	sidebar:SetPoint("TOPLEFT")
	sidebar:SetPoint("BOTTOMLEFT")
	sidebar:SetWidth(SIDEBAR_W)

	-- Addon name in the logo panel, where the EllesmereUI logo is in its art.
	local logo = NewText(sidebar, 28, 1)
	logo:SetPoint("TOPLEFT", 24, -(LOGO_H / 2) + 19)
	logo:SetText("EllesmereUI")
	local logoSub = NewText(sidebar, 11, 1)
	logoSub:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 1, -3)
	AccentText(logoSub, 1)
	logoSub:SetText("FOR MISTS OF PANDARIA")

	-- Unlock Mode is always the top row, with its own icon art.
	CreateUnlockButton(sidebar, StartUnlockFromWindow)
	ns._mainFrame = window

	-- Search box under the top rows (EllesmereUI "Search Features...").
	-- It filters the module list by module, tab and setting names.
	local fixedRows = 0
	for i = 1, #MODULES do
		if MODULES[i].fixed then
			fixedRows = fixedRows + 1
		end
	end
	local searchTop = NAV_TOP + NAV_H * (1 + fixedRows) + 13
	local search = CreateFrame("Frame", nil, sidebar)
	search:SetSize(SIDEBAR_W - 40, SEARCH_H)
	search:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 22, -searchTop)
	Solid(search, "BACKGROUND", 0.030, 0.023, 0.018, 0.35):SetAllPoints()
	local searchBorder = AddBorder(search, 1, 1, 1, 0.10)
	local searchBox = CreateFrame("EditBox", nil, search)
	searchBox:SetAllPoints()
	searchBox:SetAutoFocus(false)
	searchBox:SetFont(FONT, 13, "")
	if not searchBox:GetFont() then
		searchBox:SetFont(FONT_FALLBACK, 13, "")
	end
	searchBox:SetTextColor(1, 1, 1, 1)
	searchBox:SetTextInsets(10, 24, 0, 0)
	searchBox:SetMaxLetters(40)
	local placeholder = NewText(search, 12, 0.3)
	placeholder:SetPoint("LEFT", 10, 0)
	placeholder:SetText("Search Features...")
	local clear = CreateFrame("Button", nil, search)
	clear:SetSize(20, 20)
	clear:SetPoint("RIGHT", -4, 0)
	clear:SetFrameLevel(searchBox:GetFrameLevel() + 2)
	clear.label = NewText(clear, 15, 0.35)
	clear.label:SetPoint("CENTER")
	clear.label:SetJustifyH("CENTER")
	clear.label:SetText("x")
	clear:Hide()
	clear:SetScript("OnEnter", function(self) self.label:SetTextColor(1, 1, 1, 1) end)
	clear:SetScript("OnLeave", function(self) self.label:SetTextColor(1, 1, 1, 0.35) end)
	clear:SetScript("OnClick", function()
		searchBox:SetText("")
		searchBox:ClearFocus()
	end)
	search:EnableMouse(true)
	search:SetScript("OnEnter", function() searchBorder:SetColor(1, 1, 1, 0.15) end)
	search:SetScript("OnLeave", function()
		if not searchBox:HasFocus() then
			searchBorder:SetColor(1, 1, 1, 0.10)
		end
	end)
	searchBox:SetScript("OnEditFocusGained", function() searchBorder:SetColor(1, 1, 1, 0.15) end)
	searchBox:SetScript("OnEditFocusLost", function() searchBorder:SetColor(1, 1, 1, 0.10) end)
	searchBox:SetScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
	end)

	-- Words a module can be found by (sidebar filter) and the results list:
	-- its name, its tab names and every label on its pages.
	BuildSearchIndex()

	-- Grouped module list: green group headers, indented module rows.
	-- EllesmereUI: the list scrolls (smooth wheel, thin right thumb, click /
	-- drag on the track) and a down arrow under it jumps to the bottom.
	local listTop = searchTop + SEARCH_H + 6
	local LIST_BOTTOM = 62 -- room for the arrow and the version text
	local LIST_STEP, LIST_SPEED = 60, 12

	local listScroll = CreateFrame("ScrollFrame", nil, sidebar)
	listScroll:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 0, -listTop)
	listScroll:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", 0, LIST_BOTTOM)
	listScroll:EnableMouseWheel(true)
	local listChild = CreateFrame("Frame", nil, listScroll)
	listChild:SetSize(SIDEBAR_W, 1)
	listScroll:SetScrollChild(listChild)

	local listTrack = CreateFrame("Frame", nil, listScroll)
	listTrack:SetWidth(3)
	listTrack:SetPoint("TOPRIGHT", listScroll, "TOPRIGHT", -2, -2)
	listTrack:SetPoint("BOTTOMRIGHT", listScroll, "BOTTOMRIGHT", -2, 2)
	listTrack:SetFrameLevel(listScroll:GetFrameLevel() + 3)
	Solid(listTrack, "BACKGROUND", 1, 1, 1, 0.03):SetAllPoints()
	local listThumb = Solid(listTrack, "ARTWORK", 1, 1, 1, 0.25)
	listThumb:SetWidth(3)
	listThumb:SetHeight(40)
	listThumb:SetPoint("TOP")

	local listArrow = CreateFrame("Button", nil, sidebar)
	listArrow:SetSize(22, 19)
	listArrow:SetPoint("TOP", listScroll, "BOTTOM", 0, -5)
	listArrow:SetHitRectInsets(-12, -12, -6, -8)
	do
		-- EllesmereUI icons\eui-arrow-down3.png (30 x 30, stretched to 32 x 32).
		local t = listArrow:CreateTexture(nil, "ARTWORK")
		t:SetTexture(ART_PATH .. "eui-arrow-down3")
		t:SetAllPoints()
	end
	listArrow.atBottom = false

	local function ListRange()
		return max(0, listScroll:GetVerticalScrollRange() or 0)
	end

	local function UpdateListThumb()
		local range = ListRange()
		local cur = listScroll:GetVerticalScroll() or 0
		listArrow.atBottom = range <= 0.5 or cur >= range - 0.5
		if listArrow.atBottom then
			listArrow:SetAlpha(0.2)
		elseif listArrow:IsMouseOver() then
			listArrow:SetAlpha(1)
		else
			listArrow:SetAlpha(0.7)
		end
		if range <= 0 then
			listTrack:Hide()
			return
		end
		listTrack:Show()
		local trackH = listTrack:GetHeight()
		local visH = listScroll:GetHeight()
		local thumbH = max(30, trackH * visH / (visH + range))
		listThumb:SetHeight(thumbH)
		listThumb:ClearAllPoints()
		listThumb:SetPoint("TOP", listTrack, "TOP", 0, -(cur / range) * (trackH - thumbH))
	end
	listArrow:SetScript("OnEnter", function(self)
		if not self.atBottom then
			self:SetAlpha(1)
		end
	end)
	listArrow:SetScript("OnLeave", function(self)
		self:SetAlpha(self.atBottom and 0.2 or 0.7)
	end)

	-- Smooth scroll: glide towards the target.
	local listTarget = 0
	local listSmooth = CreateFrame("Frame", nil, listScroll)
	listSmooth:Hide()
	listSmooth:SetScript("OnUpdate", function(self, elapsed)
		local range = ListRange()
		listTarget = max(0, min(range, listTarget))
		local cur = listScroll:GetVerticalScroll() or 0
		local diff = listTarget - cur
		if math.abs(diff) < 0.3 then
			listScroll:SetVerticalScroll(listTarget)
			UpdateListThumb()
			self:Hide()
			return
		end
		listScroll:SetVerticalScroll(max(0, min(range, cur + diff * min(1, LIST_SPEED * elapsed))))
		UpdateListThumb()
	end)
	local function ScrollListTo(value)
		listTarget = max(0, min(ListRange(), value))
		listSmooth:Show()
	end
	listScroll:SetScript("OnMouseWheel", function(self, delta)
		if ShiftWheelScale and ShiftWheelScale(delta) then
			return
		end
		if ListRange() <= 0 then
			return
		end
		local base = listSmooth:IsShown() and listTarget or (self:GetVerticalScroll() or 0)
		ScrollListTo(base - delta * LIST_STEP)
	end)
	listScroll:SetScript("OnScrollRangeChanged", UpdateListThumb)
	listScroll:SetScript("OnSizeChanged", UpdateListThumb)
	listArrow:SetScript("OnClick", function()
		ScrollListTo(ListRange())
	end)

	-- Click / drag on the track: the thumb follows the cursor. The track
	-- is 3 px, the hit rect is wider.
	listTrack:EnableMouse(true)
	listTrack:SetHitRectInsets(-8, -2, 0, 0)
	local function ListToCursor()
		local range = ListRange()
		if range <= 0 then
			return
		end
		local trackH = listTrack:GetHeight()
		local thumbH = listThumb:GetHeight()
		local travel = max(1, trackH - thumbH)
		local _, cy = GetCursorPosition()
		local offset = ((listTrack:GetTop() or 0) - cy / listTrack:GetEffectiveScale()) - thumbH / 2
		offset = max(0, min(travel, offset))
		listTarget = offset / travel * range
		listScroll:SetVerticalScroll(listTarget)
		UpdateListThumb()
	end
	listTrack:SetScript("OnMouseDown", function(self)
		listSmooth:Hide()
		ListToCursor()
		self:SetScript("OnUpdate", ListToCursor)
	end)
	listTrack:SetScript("OnMouseUp", function(self)
		self:SetScript("OnUpdate", nil)
	end)
	listTrack:SetScript("OnHide", function(self)
		self:SetScript("OnUpdate", nil)
	end)

	-- Scrolls the list so a module row is fully visible (search results).
	ns._sidebarEnsureVisible = function(row)
		if not row or row:GetParent() ~= listChild or not row:IsShown() then
			return
		end
		local top = (listChild:GetTop() or 0) - (row:GetTop() or 0)
		local bottom = top + row:GetHeight()
		local cur = listScroll:GetVerticalScroll() or 0
		local visH = listScroll:GetHeight()
		if top < cur then
			ScrollListTo(top)
		elseif bottom > cur + visH then
			ScrollListTo(bottom - visH)
		end
	end

	local groupRows = {}
	for g = 1, #GROUPS do
		groupRows[g] = CreateGroupHeader(listChild, GROUPS[g])
	end
	local fixedRow = 0
	for i = 1, #MODULES do
		if MODULES[i].fixed then
			fixedRow = fixedRow + 1
			navButtons[i] = CreateGlobalButton(sidebar, MODULES[i], function() SelectModule(i) end, fixedRow)
		else
			navButtons[i] = CreateModuleRow(listChild, MODULES[i], function() SelectModule(i) end)
		end
	end

	local function LayoutSidebar()
		local filter = (searchBox:GetText() or ""):lower()
		local y = 0
		local first = true
		for i = 1, #MODULES do
			if not MODULES[i].fixed then
				navButtons[i]:Hide()
			end
		end
		for g = 1, #GROUPS do
			local shown = {}
			for i = 1, #MODULES do
				local module = MODULES[i]
				if module.group == GROUPS[g] and (filter == "" or module.searchText:find(filter, 1, true)) then
					shown[#shown + 1] = i
				end
			end
			local header = groupRows[g]
			if #shown > 0 then
				if not first then
					y = y + GROUP_GAP
				end
				first = false
				header:ClearAllPoints()
				header:SetPoint("TOPLEFT", listChild, "TOPLEFT", 0, -y)
				header:Show()
				y = y + GROUP_ROW_H
				for k = 1, #shown do
					local row = navButtons[shown[k]]
					row:ClearAllPoints()
					row:SetPoint("TOPLEFT", listChild, "TOPLEFT", 0, -y)
					row:Show()
					y = y + CHILD_ROW_H
				end
			else
				header:Hide()
			end
		end
		listChild:SetHeight(max(1, y))
		listScroll:UpdateScrollChildRect()
		ScrollListTo(listTarget)
		UpdateListThumb()
	end
	searchBox:SetScript("OnTextChanged", function(self)
		local empty = (self:GetText() or "") == ""
		placeholder:SetShown(empty)
		clear:SetShown(not empty)
		LayoutSidebar()
	end)
	LayoutSidebar()
	-- After the OnTextChanged above: it hooks into it.
	BuildSearchPopup(search, searchBox)

	local version = NewText(sidebar, 10, 0.53)
	version:SetAlpha(0.5)
	version:SetPoint("BOTTOMLEFT", 18, 18)
	version:SetText("v" .. (GetAddOnMetadata(ns.ADDON, "Version") or "?"))

	BuildHeaderAndFooter()

	window:SetScript("OnShow", function()
		EnterModule()
		RefreshAll()
		PlaySound("igCharacterInfoOpen")
	end)
	window:SetScript("OnHide", function()
		searchPopup:Hide()
		CloseMenu()
		HideTip()
		LeaveModule()
		PlaySound("igCharacterInfoClose")
	end)

	StaticPopupDialogs["EUI_MODULE_RESET"] = {
		text = "Reset all %s settings to default?",
		button1 = YES,
		button2 = NO,
		OnAccept = function(self, module)
			if module and module.reset then
				module.reset()
				ApplyModules()
				RefreshAll()
			end
		end,
		timeout = 0,
		whileDead = 1,
		hideOnEscape = 1,
	}

	window:Hide()
	SelectModule(1)
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------
ns.ToggleSettingsWindow = function()
	if not window then
		BuildWindow()
	end
	-- Settings asked for during Unlock Mode: it closes first (asking about
	-- unsaved changes), then the window opens (retail RegisterOnShow).
	if ns._unlockActive and ns.CloseUnlockMode then
		ns.CloseUnlockMode(function()
			if not window:IsShown() then
				window:Show()
			end
		end)
		return
	end
	if window:IsShown() then
		window:Hide()
	else
		window:Show()
	end
end

ns.RefreshSettings = function()
	if window and window:IsShown() then
		RefreshAll()
	end
end

-- Popups that change settings outside a page control (Tracked Auras): run
-- every module's apply hook, then refresh the open page.
ns.ApplySettingsChange = function()
	ApplyModules()
	ns.RefreshSettings()
end

---------------------------------------------------------------------------
-- Retail EllesmereUI panel API used by the core's Unlock Mode
-- (EUI_UnlockMode_Session.lua / _Movers.lua): hide the window for the open
-- animation, reopen it on the module and tab it showed before, and the
-- cog menu's "Element Options".
---------------------------------------------------------------------------
-- Retail addon folder (Unlock Mode element map) -> settings module key.
local FOLDER_MODULES = {
	EllesmereUIUnitFrames = "unitFrames", EllesmereUIActionBars = "actionBars",
	EllesmereUIResourceBars = "resourceBars", EllesmereUIMinimap = "minimap",
	EllesmereUIChat = "chat", EllesmereUIDataBars = "dataBars",
	EllesmereUIDamageMeters = "damageMeters", EllesmereUIInterruptTracker = "interrupts",
	EllesmereUIBlizzardSkin = "blizzardSkins",
	EllesmereUICooldownManager = "cdm", EllesmereUIAuraBuffReminders = "auraBuff",
	EllesmereUIFriends = "friends", EllesmereUIQuickdraw = "quickdraw",
	EllesmereUIRaidFrames = "raidFrames", EllesmereUIQoL = "qol",
	EllesmereUINameplates = "nameplates", EllesmereUITopBar = "topBar",
}

local function ModuleIndex(keyOrFolder)
	local key = FOLDER_MODULES[keyOrFolder] or keyOrFolder
	for i, def in ipairs(MODULES) do
		if def.key == key then
			return i
		end
	end
	return nil
end

-- Tab of the current module by name or index.
local function TabIndex(page)
	local module = currentModule and MODULES[currentModule]
	if not module then
		return nil
	end
	if type(page) == "number" then
		return module.tabs[page] and page or nil
	end
	for i, def in ipairs(module.tabs) do
		if def.name == page or def.key == page then
			return i
		end
	end
	return nil
end

function ns:Hide()
	if window then
		window:Hide()
	end
end

function ns:Toggle()
	ns.ToggleSettingsWindow()
end

function ns:GetActiveModule()
	return currentModule and MODULES[currentModule].key or nil
end

function ns:GetActivePage()
	return currentModule and MODULES[currentModule].selectedTab or nil
end

function ns:SelectModule(key)
	if not window then
		BuildWindow()
	end
	local i = ModuleIndex(key)
	if i then
		SelectModule(i)
	end
end

function ns:SelectPage(page)
	local t = TabIndex(page)
	if t and currentModule then
		SelectTab(currentModule, t)
	end
end

function ns:NavigateToElementSettings(moduleName, pageName, sectionName, preSelectFn, highlightText)
	if InCombatLockdown() then
		return
	end
	if not window then
		BuildWindow()
	end
	local i = ModuleIndex(moduleName)
	if not i then
		window:Show()
		return
	end
	if preSelectFn then
		pcall(preSelectFn)
	end
	window:Show()
	SelectModule(i)
	local t = pageName and TabIndex(pageName)
	if t then
		SelectTab(i, t)
	end
	if highlightText and currentPage and currentPage.RevealSetting then
		currentPage:RevealSetting(sectionName, highlightText)
	end
end


-- Window Scale (Global Settings reset puts it back to 100%).
ns.SetPanelScale = function(scale)
	SetPanelScale(scale)
end

-- Repaints every page (a setting changed outside the window).
ns.RefreshAllPages = function()
	if window then
		RefreshAll()
	end
end

-- Shows the current tab again (a page with def.pageKey is rebuilt for the new key).
ns.RebuildSettingsPage = function()
	if window and window:IsShown() and currentModule then
		SelectTab(currentModule, MODULES[currentModule].selectedTab or 1)
	end
end

-- Opens the window on a module (def.key), e.g. from a DataBars block that
-- asks for a setting. Returns the shown page (Page:Reveal / RevealSetting).
ns.OpenSettingsModule = function(key)
	if InCombatLockdown() then
		return nil
	end
	if not window then
		BuildWindow()
	end
	if ns._unlockActive then
		return nil
	end
	for i, def in ipairs(MODULES) do
		if def.key == key then
			window:Show()
			SelectModule(i)
			return currentPage
		end
	end
	return nil
end
