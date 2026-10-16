-------------------------------------------------------------------------------
--  EllesmereUIBlizzardSkin_WindowEngine.lua (5.4.8 port)
--  Shared engine for the Blizzard Window Skins: style-aware window shells
--  (EllesmereUI art backdrop vs Modern flat color), the primitive skinners
--  every window pack builds from, and per-window boot for load-on-demand
--  Blizzard addons. Port of retail EllesmereUIBlizzardSkin_WindowEngine.lua.
--
--  5.4.8 differences:
--   - SetTexture(r, g, b, a) instead of SetColorTexture; no atlases
--     (EllesmereUI TGA art or a 1px border instead).
--   - Classic templates: 3-slice buttons ($parentLeft/Middle/Right),
--     UIDropDownMenuTemplate, InputBoxTemplate, UIPanelScrollBarTemplate,
--     HybridScrollBarTemplate, CharacterFrameTabButtonTemplate tabs.
--   - ElvUI: a window whose ElvUI skin is on is left to ElvUI.
--
--  Style model (per window, Blizzard Skins > Window Skins):
--    "eui"    -> modern_blizz art backdrop (cover-fit) + black overlay.
--    "modern" -> the same skin on a flat user color (Global Options).
--    "off"    -> the window pack never runs (reload-gated).
--
--  Safety rules (from retail):
--   - Per-frame state lives in a weak-keyed EXTERNAL table (FFD); never
--     write custom keys onto Blizzard frames.
--   - Visual-only: SetAlpha(0) on textures. Never Hide/Show/SetParent a
--     Blizzard frame, never SetScript on Blizzard frames (HookScript /
--     hooksecurefunc only).
--   - Each window pack is pcall-isolated.
-------------------------------------------------------------------------------
local addonName = ...
local ns = EllesmereUI
local BS = ns.BlizzSkin
local PP = BS.PP

local WSkin = {}
ns.WSkin = WSkin
BS.WSkin = WSkin

local Forbidden = BS.Forbidden
local WHITE = BS.WHITE
local MEDIA = BS.MEDIA
local CORE_MEDIA = (ns.MEDIA or "Interface\\AddOns\\EllesmereUI\\media\\")

WSkin.CLOSE_TEX = MEDIA .. "charsheet\\eui-close.tga"
WSkin.ARROW_DOWN_TEX = MEDIA .. "charsheet\\eui-arrow-down3.tga"
WSkin.ARROW_UP_TEX = MEDIA .. "charsheet\\eui-arrow-up3.tga"
WSkin.ARROW_RIGHT_TEX = CORE_MEDIA .. "ui\\eui-arrow-right.tga"
WSkin.BG_TEX = MEDIA .. "modern_blizz.tga"

-- Weak-keyed external state (keeps our keys off Blizzard frames) -------------
local FFD = setmetatable({}, { __mode = "k" })
local function GetFFD(frame)
	local d = FFD[frame]
	if not d then
		d = {}
		FFD[frame] = d
	end
	return d
end
WSkin.GetFFD = GetFFD
WSkin.FFD = FFD

local setupInProgress = setmetatable({}, { __mode = "k" })
function WSkin.CompleteSetup(frame, key, apply, ...)
	local d = GetFFD(frame)
	if d[key] or setupInProgress[frame] then
		return
	end
	setupInProgress[frame] = true
	local ok, err = pcall(apply, frame, d, ...)
	setupInProgress[frame] = nil
	if not ok then
		error(err, 0)
	end
	d[key] = true
end

-------------------------------------------------------------------------------
--  Theme tokens (dungeons-and-raids reskin family).
-------------------------------------------------------------------------------
local Theme = {}
WSkin.Theme = Theme
local function ResolveTheme()
	local r, g, b = BS.Accent()
	Theme.accR, Theme.accG, Theme.accB = r, g, b
	Theme.bgR, Theme.bgG, Theme.bgB, Theme.bgA = 0.08, 0.08, 0.08, 0.92
	Theme.insetR, Theme.insetG, Theme.insetB, Theme.insetA = 0.04, 0.04, 0.04, 0.85
	Theme.brdR, Theme.brdG, Theme.brdB, Theme.brdA = 0.2, 0.2, 0.2, 1
	Theme.fontPath = BS.FontPath()
	Theme.fontFlag = BS.FontFlag()
	Theme.fontShadow = (Theme.fontFlag == "")
end
WSkin.ResolveTheme = ResolveTheme
ResolveTheme()

local function SolidTex(parent, layer, r, g, b, a, sublevel)
	return BS.SolidTex(parent, layer, r, g, b, a, sublevel)
end
WSkin.SolidTex = SolidTex

local function AddBorder(frame, r, g, b, a)
	if GetFFD(frame).border then
		return
	end
	local c = PP.CreateBorder(frame, r or Theme.brdR, g or Theme.brdG, b or Theme.brdB, a or Theme.brdA, 1, "BORDER", -7)
	-- Same frame level as the skinned frame: its text draws above the border.
	if c and c.SetFrameLevel then
		c:SetFrameLevel(frame:GetFrameLevel())
	end
	GetFFD(frame).border = c
end
WSkin.AddBorder = AddBorder

-------------------------------------------------------------------------------
--  Modern backdrop color (one global color + opacity, default #111111 97%).
-------------------------------------------------------------------------------
local MODERN_FALLBACK = { r = 0.067, g = 0.067, b = 0.067, a = 0.97 }
function WSkin.GetModernBG()
	local c = BS.DB().blizzWindowModernDefault
	if not (type(c) == "table" and c.r) then
		c = MODERN_FALLBACK
	end
	return c.r or MODERN_FALLBACK.r, c.g or MODERN_FALLBACK.g,
		c.b or MODERN_FALLBACK.b, c.a or MODERN_FALLBACK.a
end

function WSkin.GetStyle(winKey)
	return BS.GetWindowStyle(winKey)
end

-------------------------------------------------------------------------------
--  FadeRegions: alpha-out every direct texture region of a frame. `keep` is a
--  set of textures to leave alone. Visual-only, no Hide().
-------------------------------------------------------------------------------
local function FadeTextures(keep, ...)
	for i = 1, select("#", ...) do
		local r = (select(i, ...))
		if r and r.IsObjectType and r:IsObjectType("Texture") and not (keep and keep[r]) then
			r:SetAlpha(0)
		end
	end
end
local function FadeRegions(frame, keep)
	if not frame or Forbidden(frame) or not frame.GetRegions then
		return
	end
	FadeTextures(keep, frame:GetRegions())
end
WSkin.FadeRegions = FadeRegions

-- Named texture pieces: $parent<suffix> globals and parentKeys.
function WSkin.FadeNamed(frame, suffixes)
	if not frame then
		return
	end
	local name = frame.GetName and frame:GetName()
	for i = 1, #suffixes do
		local k = suffixes[i]
		local t = frame[k] or (name and _G[name .. k])
		if type(t) == "table" and t.SetAlpha and t.IsObjectType and t:IsObjectType("Texture") then
			t:SetAlpha(0)
		end
	end
end

-------------------------------------------------------------------------------
--  Restrip registry: frames Blizzard repaints get re-faded on demand. Every
--  texture the engine created is protected via the frame's FFD entry.
-------------------------------------------------------------------------------
local _restrip = {}
local _windowRestrips = {}
local registrationWindow

function WSkin.WindowCallback(winKey, fn)
	return function(...)
		if WSkin.GetStyle(winKey) == "off" then
			return
		end
		local previous = registrationWindow
		registrationWindow = winKey
		local ok, err = pcall(fn, ...)
		registrationWindow = previous
		if not ok then
			error(err, 0)
		end
	end
end

local function Register(frame, keep)
	if not frame then
		return
	end
	_restrip[frame] = keep or true
	if registrationWindow then
		local frames = _windowRestrips[registrationWindow]
		if not frames then
			frames = {}
			_windowRestrips[registrationWindow] = frames
		end
		frames[frame] = true
	end
end
WSkin.Register = Register

local PROTECT_KEYS = { "bg", "bgOverlay", "modernBg", "hover", "selBar", "rightShade", "fill", "x", "topBar", "bottomBar", "arrow", "caret", "label", "underline", "activeHL", "strip" }
local function Restrip(winKey)
	local frames = winKey and _windowRestrips[winKey] or _restrip
	if winKey and not _windowRestrips[winKey] then
		return
	end
	for frame in pairs(frames) do
		local keep = _restrip[frame]
		if frame and not Forbidden(frame) then
			local k = (type(keep) == "table") and keep or nil
			local d = FFD[frame]
			if d then
				local merged = {}
				if k then
					for t in pairs(k) do
						merged[t] = true
					end
				end
				for _, key in ipairs(PROTECT_KEYS) do
					if type(d[key]) == "table" then
						merged[d[key]] = true
					end
				end
				k = merged
			end
			FadeRegions(frame, k)
		end
	end
end
WSkin.Restrip = Restrip

-------------------------------------------------------------------------------
--  Style-aware window shell: both backdrop variants on the frame, the one
--  matching the window's style shown. RefreshStyles() live-swaps them.
-------------------------------------------------------------------------------
local _shells = {}

local BG_ASPECT = 561 / 433
local BASE_L, BASE_R, BASE_T, BASE_B = 0.25, 1, 0, 0.75
local BASE_U, BASE_V = BASE_R - BASE_L, BASE_B - BASE_T

local function ApplyShellStyle(winKey)
	local entry = _shells[winKey]
	if not entry then
		return
	end
	local style = WSkin.GetStyle(winKey)
	for frame in pairs(entry) do
		local d = FFD[frame]
		if d then
			if style == "modern" then
				if d.bg then d.bg:SetAlpha(0) end
				if d.bgOverlay then d.bgOverlay:SetAlpha(0) end
				if d.modernBg then
					local r, g, b, a = WSkin.GetModernBG()
					d.modernBg:SetTexture(r, g, b, a)
					d.modernBg:SetAlpha(1)
				end
			else
				if d.bg then d.bg:SetAlpha(1) end
				if d.bgOverlay then d.bgOverlay:SetAlpha(1) end
				if d.modernBg then d.modernBg:SetTexture(0, 0, 0, 0) end
			end
		end
	end
end

local _styleCallbacks = {}
function WSkin.OnStylesChanged(fn)
	_styleCallbacks[#_styleCallbacks + 1] = fn
end

function WSkin.RefreshStyles()
	for winKey in pairs(_shells) do
		ApplyShellStyle(winKey)
	end
	for _, fn in ipairs(_styleCallbacks) do
		pcall(fn)
	end
end
ns._WSkinRefreshStyles = WSkin.RefreshStyles

function WSkin.AdoptShell(winKey, frame, atlasTex, overlayTex)
	if not frame then
		return
	end
	local d = GetFFD(frame)
	if atlasTex then d.bg = atlasTex end
	if overlayTex then d.bgOverlay = overlayTex end
	if not d.modernBg then
		d.modernBg = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
		d.modernBg:SetTexture(0, 0, 0, 0)
		d.modernBg:SetAllPoints(frame)
	end
	local entry = _shells[winKey]
	if not entry then
		entry = {}
		_shells[winKey] = entry
	end
	entry[frame] = true
	ApplyShellStyle(winKey)
end

-- Cover-fit the shell art into fw x fh: native aspect 561x433, centred crop.
function WSkin.CoverFit(tex, fw, fh)
	if not fw or fw == 0 or not fh or fh == 0 then
		return
	end
	local fa = fw / fh
	if fa > BG_ASPECT then
		local visV = BASE_V * (BG_ASPECT / fa)
		local trimV = (BASE_V - visV) / 2
		tex:SetTexCoord(BASE_L, BASE_R, BASE_T + trimV, BASE_B - trimV)
	else
		local visU = BASE_U * (fa / BG_ASPECT)
		local trimU = (BASE_U - visU) / 2
		tex:SetTexCoord(BASE_L + trimU, BASE_R - trimU, BASE_T, BASE_B)
	end
end

-- Full shell for a window: fade Blizzard art, lay both backdrops, border it.
-- opts.noBorder, opts.noTopBar, opts.bottomBar (true or height),
-- opts.inset = { left, top, right, bottom } when the frame rect is bigger
-- than its visible panel (old 5.4.8 windows with transparent art margins).
function WSkin.Shell(winKey, frame, opts)
	if not frame or Forbidden(frame) then
		return
	end
	local d = GetFFD(frame)
	local keep = {}
	for _, key in ipairs(PROTECT_KEYS) do
		if type(d[key]) == "table" then keep[d[key]] = true end
	end
	FadeRegions(frame, keep)
	Register(frame, true)
	if not d.bg then
		-- The art host: the frame itself, or an inset child for old windows.
		local host = frame
		local ins = opts and opts.inset
		if ins then
			host = CreateFrame("Frame", nil, frame)
			host:SetPoint("TOPLEFT", frame, "TOPLEFT", ins[1] or 0, -(ins[2] or 0))
			host:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(ins[3] or 0), ins[4] or 0)
			host:SetFrameLevel(max(0, frame:GetFrameLevel() - 1))
			d.host = host
		end
		local bg = host:CreateTexture(nil, "BACKGROUND", nil, -8)
		bg:SetTexture(WSkin.BG_TEX)
		bg:SetAllPoints(host)
		d.bg = bg
		local overlay = host:CreateTexture(nil, "BACKGROUND", nil, -7)
		overlay:SetTexture(0, 0, 0, 0.62)
		overlay:SetAllPoints(host)
		d.bgOverlay = overlay
		d.modernBg = host:CreateTexture(nil, "BACKGROUND", nil, -6)
		d.modernBg:SetTexture(0, 0, 0, 0)
		d.modernBg:SetAllPoints(host)

		local function UpdateBgTexCoords()
			WSkin.CoverFit(bg, host:GetSize())
		end
		host:HookScript("OnSizeChanged", UpdateBgTexCoords)
		UpdateBgTexCoords()

		if not (opts and opts.noTopBar) then
			local topBar = host:CreateTexture(nil, "BACKGROUND", nil, -5)
			topBar:SetTexture(0, 0, 0, 0.5)
			topBar:SetPoint("TOPLEFT")
			topBar:SetPoint("TOPRIGHT")
			topBar:SetHeight(type(opts and opts.topBar) == "number" and opts.topBar or 25)
			d.topBar = topBar
		end
		local bb = opts and opts.bottomBar
		if bb then
			local bottomBar = host:CreateTexture(nil, "BACKGROUND", nil, -5)
			bottomBar:SetTexture(0, 0, 0, 0.5)
			bottomBar:SetPoint("BOTTOMLEFT")
			bottomBar:SetPoint("BOTTOMRIGHT")
			bottomBar:SetHeight(type(bb) == "number" and bb or 25)
			d.bottomBar = bottomBar
		end
		if not (opts and opts.noBorder) then
			AddBorder(host)
		end
	end
	WSkin.AdoptShell(winKey, frame)
end

-- Retail's AtlasBorder (AdventureMap_TopBorder) has no 5.4.8 art: 1px border.
function WSkin.AtlasBorder(frame)
	AddBorder(frame)
end

-------------------------------------------------------------------------------
--  Primitive skinners. All idempotent (guarded via FFD), all visual-only.
-------------------------------------------------------------------------------

-- Flat solid panel. opts.noBg = strip only; opts.inset = darker nested fill;
-- opts.noBorder = skip border; opts.shade = translucent black content wash.
function WSkin.Panel(frame, opts)
	if not frame or Forbidden(frame) then
		return
	end
	opts = opts or {}
	local d = GetFFD(frame)
	local keep = {}
	if d.bg then keep[d.bg] = true end
	FadeRegions(frame, keep)
	Register(frame, true)
	if not d.bg and not opts.noBg then
		local r, g, b, a = Theme.bgR, Theme.bgG, Theme.bgB, Theme.bgA
		if opts.inset then r, g, b, a = Theme.insetR, Theme.insetG, Theme.insetB, Theme.insetA end
		if opts.shade then r, g, b, a = 0, 0, 0, 0.25 end
		local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
		bg:SetTexture(r, g, b, a)
		bg:SetAllPoints(frame)
		d.bg = bg
	end
	if not opts.noBorder then
		AddBorder(frame)
	end
end

-- Strip an InsetFrameTemplate child (Bg + corner/edge textures).
local INSET_PIECES = {
	"Bg", "InsetBorderTop", "InsetBorderBottom", "InsetBorderLeft", "InsetBorderRight",
	"InsetBorderTopLeft", "InsetBorderTopRight", "InsetBorderBottomLeft", "InsetBorderBottomRight",
}
function WSkin.Inset(inset)
	if not inset or Forbidden(inset) then
		return
	end
	FadeRegions(inset)
	WSkin.FadeNamed(inset, INSET_PIECES)
	Register(inset, true)
end

function WSkin.Font(fs, r, g, b)
	if not fs or not fs.GetFont then
		return
	end
	local _, size = fs:GetFont()
	fs:SetFont(Theme.fontPath, size or 12, Theme.fontFlag or "")
	if Theme.fontShadow then
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 1)
	else
		fs:SetShadowOffset(0, 0)
	end
	if r then
		fs:SetTextColor(r, g, b or r)
	end
end

function WSkin.White(fs, r, g, b)
	if fs and fs.SetTextColor then
		fs:SetTextColor(r or 1, g or 1, b or 1)
	end
end

-- 3-slice / panel button pieces in 5.4.8 templates.
local BUTTON_PIECES = { "Left", "Middle", "Right", "LeftSeparator", "RightSeparator", "Mid" }

local function ApplyButton(btn, d, keepKeys)
	local keep = {}
	if d.bg then keep[d.bg] = true end
	if d.hover then keep[d.hover] = true end
	if keepKeys then
		for _, k in ipairs(keepKeys) do
			local r = btn[k]
			if r then keep[r] = true end
		end
	end
	FadeRegions(btn, keep)
	for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
		local fn = btn[getter]
		local t = fn and fn(btn)
		if t and not keep[t] then
			t:SetAlpha(0)
		end
	end
	local name = btn.GetName and btn:GetName()
	for _, k in ipairs(BUTTON_PIECES) do
		local r = btn[k] or (name and _G[name .. k])
		if r and not keep[r] and r.SetAlpha then
			r:SetAlpha(0)
		end
	end

	local fill = d.bg
	if not fill then
		fill = btn:CreateTexture(nil, "BACKGROUND")
		d.bg = fill
	end
	fill:SetTexture(Theme.bgR, Theme.bgG, Theme.bgB, Theme.bgA)
	fill:SetAllPoints(btn)
	AddBorder(btn)

	local hover = d.hover
	if not hover then
		hover = btn:CreateTexture(nil, "HIGHLIGHT")
		d.hover = hover
	end
	hover:SetTexture(1, 1, 1, 0.1)
	hover:SetAllPoints(btn)
	Register(btn, keep)
end

function WSkin.Button(btn, keepKeys)
	if not btn or Forbidden(btn) then
		return
	end
	WSkin.CompleteSetup(btn, "skinned", ApplyButton, keepKeys)
end

function WSkin.WhiteButtonLabel(btn)
	if not btn then
		return
	end
	local lab = btn.Text or (btn.GetFontString and btn:GetFontString())
	if not lab then
		return
	end
	WSkin.White(lab)
	local d = GetFFD(btn)
	if not d.whiteHook then
		d.whiteHook = true
		if btn.HookScript then
			btn:HookScript("OnEnable", function() WSkin.White(lab) end)
		end
	end
end

function WSkin.StateButtonLabel(btn)
	if not btn then
		return
	end
	local lab = btn.Text or (btn.GetFontString and btn:GetFontString())
	if not lab then
		return
	end
	local d = GetFFD(btn)
	if d.stateHook then
		return
	end
	d.stateHook = true
	local function reflect()
		if btn:IsEnabled() then
			WSkin.White(lab)
		else
			lab:SetTextColor(0.5, 0.5, 0.5)
		end
	end
	if btn.HookScript then
		btn:HookScript("OnEnable", reflect)
		btn:HookScript("OnDisable", reflect)
	end
	reflect()
end

-- Search / input box (InputBoxTemplate, SearchBoxTemplate) -> near-black
-- block + border. opts.noBorder; opts.inset = { l, t, r, b } offsets of the
-- block (InputBoxTemplate draws its art 5px left of the frame).
local EDIT_PIECES = { "Left", "Right", "Middle", "Mid" }
function WSkin.EditBox(eb, opts)
	if not eb or Forbidden(eb) then
		return
	end
	local d = GetFFD(eb)
	if d.bg then
		return
	end
	FadeRegions(eb)
	WSkin.FadeNamed(eb, EDIT_PIECES)
	local ins = opts and opts.inset or { -5, 0, 0, 0 }
	local host = eb
	if ins[1] ~= 0 or ins[2] ~= 0 or ins[3] ~= 0 or ins[4] ~= 0 then
		host = CreateFrame("Frame", nil, eb)
		host:SetPoint("TOPLEFT", eb, "TOPLEFT", ins[1], -ins[2])
		host:SetPoint("BOTTOMRIGHT", eb, "BOTTOMRIGHT", -ins[3], ins[4])
		host:SetFrameLevel(max(0, eb:GetFrameLevel() - 1))
		d.host = host
	end
	local fill = SolidTex(host, "BACKGROUND", 0.02, 0.02, 0.02, 1)
	fill:SetAllPoints(host)
	d.bg = fill
	if not (opts and opts.noBorder) then
		AddBorder(host)
	end
end

-- Checkbox -> dark block + accent tick. opts.stockCheck keeps the check
-- color; opts.hover = alpha of a white hover wash.
function WSkin.Checkbox(cb, opts)
	if not cb or Forbidden(cb) then
		return
	end
	local d = GetFFD(cb)
	if d.skinned then
		return
	end
	d.skinned = true
	if cb.SetNormalTexture then cb:SetNormalTexture("") end
	if cb.SetPushedTexture then cb:SetPushedTexture("") end
	if cb.SetHighlightTexture then cb:SetHighlightTexture("") end
	local checked = cb.GetCheckedTexture and cb:GetCheckedTexture()
	local dchecked = cb.GetDisabledCheckedTexture and cb:GetDisabledCheckedTexture()
	local regions = { cb:GetRegions() }
	for i = 1, #regions do
		local r = regions[i]
		if r and r ~= checked and r ~= dchecked and r.IsObjectType and r:IsObjectType("Texture") then
			r:SetAlpha(0)
		end
	end
	local inset = (opts and opts.fillInset) or 4
	local fill = SolidTex(cb, "BACKGROUND", 0.02, 0.02, 0.02, 1)
	fill:SetPoint("TOPLEFT", inset, -inset)
	fill:SetPoint("BOTTOMRIGHT", -inset, inset)
	d.bg = fill
	if opts and opts.hover then
		local hover = SolidTex(cb, "HIGHLIGHT", 1, 1, 1, opts.hover)
		hover:SetPoint("TOPLEFT", inset, -inset)
		hover:SetPoint("BOTTOMRIGHT", -inset, inset)
		d.hover = hover
	end
	local bh = CreateFrame("Frame", nil, cb)
	bh:SetPoint("TOPLEFT", inset, -inset)
	bh:SetPoint("BOTTOMRIGHT", -inset, inset)
	bh:SetFrameLevel(cb:GetFrameLevel() + 1)
	AddBorder(bh, 0.25, 0.25, 0.25, 1)
	d.borderHost = bh
	if checked and not (opts and opts.stockCheck) then
		checked:SetVertexColor(Theme.accR, Theme.accG, Theme.accB, 1)
	end
end

-- UIDropDownMenuTemplate -> flat block + house arrow. The block covers the
-- visible part (the template's frame has 16-20px art margins).
-- "MENU" dropdowns (UIDropDownMenu_Initialize(..., "MENU")) are invisible
-- anchors for a popup menu (EJ loot filter, difficulty), so they get no block.
local dropdownMenuHooked
function WSkin.Dropdown(dd)
	if not dd or Forbidden(dd) then
		return
	end
	if not dropdownMenuHooked and _G.UIDropDownMenu_Initialize then
		dropdownMenuHooked = true
		hooksecurefunc("UIDropDownMenu_Initialize", function(frame, _, displayMode)
			local fd = frame and FFD[frame]
			if fd and fd.host and displayMode == "MENU" then
				fd.host:Hide()
			end
		end)
	end
	if dd.displayMode == "MENU" then
		return
	end
	local d = GetFFD(dd)
	if d.skinned then
		return
	end
	d.skinned = true
	local name = dd.GetName and dd:GetName()
	FadeRegions(dd)
	WSkin.FadeNamed(dd, { "Left", "Middle", "Right", "Background", "Texture" })
	local button = dd.Button or (name and _G[name .. "Button"])
	local host = CreateFrame("Frame", nil, dd)
	if button then
		host:SetPoint("TOPLEFT", dd, "TOPLEFT", 18, -2)
		host:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
	else
		host:SetAllPoints(dd)
	end
	host:SetFrameLevel(max(0, dd:GetFrameLevel()))
	d.host = host
	local fill = SolidTex(host, "BACKGROUND", Theme.bgR, Theme.bgG, Theme.bgB, Theme.bgA)
	fill:SetAllPoints(host)
	d.bg = fill
	AddBorder(host, 0.25, 0.25, 0.25, 1)
	if button then
		local bd = GetFFD(button)
		for _, g in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
			local t = button[g] and button[g](button)
			if t then t:SetAlpha(0) end
		end
		local hl = button.GetHighlightTexture and button:GetHighlightTexture()
		if hl then
			hl:SetTexture(1, 1, 1, 0.05)
			hl:ClearAllPoints()
			hl:SetAllPoints(host)
		end
		local arrow = button:CreateTexture(nil, "OVERLAY")
		arrow:SetTexture(WSkin.ARROW_DOWN_TEX)
		arrow:SetSize(12, 12)
		arrow:SetPoint("CENTER", button, "CENTER", 0, 0)
		bd.arrow = arrow
		d.arrow = arrow
	end
	local label = dd.Text or (name and _G[name .. "Text"])
	if label then
		WSkin.White(label)
	end
end

-- Old-style (UIPanelScrollBarTemplate / HybridScrollBarTemplate / Faux)
-- scroll bar -> track art gone, slim 4px white thumb, flat arrow buttons.
-- keepSteppers leaves the up/down buttons as Blizzard draws them.
local SCROLL_PIECES = { "Top", "Bottom", "Middle", "Track", "BG", "Background", "ScrollBarTop", "ScrollBarBottom", "ScrollBarMiddle", "trackBG" }
local function StepperButton(btn, up)
	if not btn or GetFFD(btn).arrow then
		return
	end
	local d = GetFFD(btn)
	for _, g in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
		local t = btn[g] and btn[g](btn)
		if t then t:SetAlpha(0) end
	end
	local arrow = btn:CreateTexture(nil, "OVERLAY")
	arrow:SetTexture(up and WSkin.ARROW_UP_TEX or WSkin.ARROW_DOWN_TEX)
	arrow:SetSize(10, 10)
	arrow:SetPoint("CENTER")
	arrow:SetVertexColor(1, 1, 1, 0.6)
	d.arrow = arrow
	btn:HookScript("OnEnter", function() arrow:SetVertexColor(1, 1, 1, 1) end)
	btn:HookScript("OnLeave", function() arrow:SetVertexColor(1, 1, 1, 0.6) end)
	local function reflect()
		arrow:SetAlpha(btn:IsEnabled() and 1 or 0.3)
	end
	btn:HookScript("OnEnable", reflect)
	btn:HookScript("OnDisable", reflect)
	reflect()
end

function WSkin.ScrollBar(sb, keepSteppers)
	if not sb or Forbidden(sb) then
		return
	end
	local d = GetFFD(sb)
	if d.skinned then
		return
	end
	d.skinned = true
	local name = sb.GetName and sb:GetName()
	FadeRegions(sb)
	WSkin.FadeNamed(sb, SCROLL_PIECES)
	-- The track art of a UIPanelScrollFrameTemplate sits on the scroll frame.
	local parent = sb:GetParent()
	local pname = parent and parent.GetName and parent:GetName()
	if pname then
		for _, k in ipairs({ "Top", "Bottom", "Middle", "ScrollBarTop", "ScrollBarBottom", "ScrollBarMiddle" }) do
			local t = _G[pname .. k]
			if type(t) == "table" and t.SetAlpha and t.IsObjectType and t:IsObjectType("Texture") then
				t:SetAlpha(0)
			end
		end
	end
	if not keepSteppers then
		StepperButton(sb.ScrollUpButton or (name and _G[name .. "ScrollUpButton"]), true)
		StepperButton(sb.ScrollDownButton or (name and _G[name .. "ScrollDownButton"]), false)
	end
	local thumb = (sb.GetThumbTexture and sb:GetThumbTexture()) or sb.thumbTexture or (name and _G[name .. "ThumbTexture"])
	if thumb and not GetFFD(thumb).bg then
		thumb:SetTexture(1, 1, 1, 0.3)
		thumb:SetWidth(4)
		GetFFD(thumb).bg = thumb
		d.fill = thumb
	end
end

local function IsScrollBar(frame)
	if not frame.IsObjectType or not frame:IsObjectType("Slider") then
		return false
	end
	local name = frame.GetName and frame:GetName()
	return frame.ScrollUpButton or (name and _G[name .. "ScrollUpButton"]) or (name and name:find("ScrollBar$")) and true or false
end
WSkin.IsScrollBar = IsScrollBar

function WSkin.ScrollBarsIn(frame, depth)
	depth = depth or 0
	if not frame or depth > 7 or Forbidden(frame) or not frame.GetChildren then
		return
	end
	local children = { frame:GetChildren() }
	for i = 1, #children do
		local child = children[i]
		if child and not WSkin.IsForeignFrame(child, frame) then
			if IsScrollBar(child) then
				WSkin.ScrollBar(child)
			end
			WSkin.ScrollBarsIn(child, depth + 1)
		end
	end
end

-- Close (X) button -> art gone, the house close glyph.
function WSkin.CloseButton(btn)
	if not btn or Forbidden(btn) then
		return
	end
	local d = GetFFD(btn)
	if d.x then
		return
	end
	if btn.SetNormalTexture then btn:SetNormalTexture("") end
	if btn.SetPushedTexture then btn:SetPushedTexture("") end
	if btn.SetHighlightTexture then btn:SetHighlightTexture("") end
	if btn.SetDisabledTexture then btn:SetDisabledTexture("") end
	FadeRegions(btn)
	local x = btn:CreateTexture(nil, "OVERLAY")
	x:SetTexture(WSkin.CLOSE_TEX)
	x:SetSize(14, 14)
	x:SetPoint("CENTER", -2, 0)
	x:SetVertexColor(1, 1, 1, 0.75)
	d.x = x
	btn:HookScript("OnEnter", function() if d.x then d.x:SetVertexColor(1, 1, 1, 1) end end)
	btn:HookScript("OnLeave", function() if d.x then d.x:SetVertexColor(1, 1, 1, 0.75) end end)
end

-- Page-nav / arrow button -> flat block + house arrow ("<" / ">" / "^" / "v").
function WSkin.PageButton(btn, ch, size)
	if not btn or Forbidden(btn) then
		return
	end
	local d = GetFFD(btn)
	if d.block then
		return
	end
	d.block = true
	for _, g in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
		local fn = btn[g]
		local t = fn and fn(btn)
		if t and t.SetAlpha then t:SetAlpha(0) end
	end
	local bg = SolidTex(btn, "BACKGROUND", Theme.bgR, Theme.bgG, Theme.bgB, Theme.bgA)
	bg:SetAllPoints(btn)
	d.bg = bg
	AddBorder(btn)
	local s = size or 14
	local arrow = btn:CreateTexture(nil, "OVERLAY")
	if ch == "<" or ch == ">" then
		arrow:SetTexture(WSkin.ARROW_RIGHT_TEX)
		if ch == "<" then
			arrow:SetTexCoord(1, 0, 0, 1)
		end
	elseif ch == "^" then
		arrow:SetTexture(WSkin.ARROW_UP_TEX)
	else
		arrow:SetTexture(WSkin.ARROW_DOWN_TEX)
	end
	arrow:SetSize(s, s)
	arrow:SetPoint("CENTER")
	arrow:SetAlpha(0.9)
	d.arrow = arrow
	local hover = SolidTex(btn, "HIGHLIGHT", 1, 1, 1, 0.1)
	hover:SetAllPoints(btn)
	d.hover = hover
	local function reflect()
		btn:SetAlpha(btn:IsEnabled() and 1 or 0.5)
	end
	btn:HookScript("OnEnable", reflect)
	btn:HookScript("OnDisable", reflect)
	reflect()
end

-- PrevPageButton / NextPageButton (or $parentPrevPageButton) under a frame.
function WSkin.PagingIn(frame, depth)
	depth = depth or 0
	if not frame or depth > 8 or not frame.GetChildren or Forbidden(frame) then
		return
	end
	if depth > 0 and WSkin.IsForeignFrame(frame) then
		return
	end
	local name = frame.GetName and frame:GetName()
	local prev = frame.PrevPageButton or (name and _G[name .. "PrevPageButton"])
	local nextB = frame.NextPageButton or (name and _G[name .. "NextPageButton"])
	if prev then WSkin.PageButton(prev, "<") end
	if nextB then WSkin.PageButton(nextB, ">") end
	local children = { frame:GetChildren() }
	for i = 1, #children do
		WSkin.PagingIn(children[i], depth + 1)
	end
end

-- 1px black frame around a texture region (squared icons).
function WSkin.BorderRegion(parent, region)
	if not (parent and region) then
		return
	end
	local d = GetFFD(region)
	if d.bordered then
		return
	end
	d.bordered = true
	local host = CreateFrame("Frame", nil, parent)
	host:SetPoint("TOPLEFT", region, "TOPLEFT", -1, 1)
	host:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 1, -1)
	host:SetFrameLevel(parent:GetFrameLevel() + 2)
	PP.CreateBorder(host, 0, 0, 0, 1, 1, "OVERLAY", 7)
	d.borderHost = host
end

-------------------------------------------------------------------------------
--  Square quality borders for item tiles: the square edge follows Blizzard's
--  (round) quality ring color; black when the item has no rarity color.
-------------------------------------------------------------------------------
local QUALITY_CHROMA = 0.1
function WSkin.RingQuality(ring)
	if not (ring and ring.IsShown and ring.GetVertexColor) then
		return
	end
	if not ring:IsShown() then
		return
	end
	local r, g, b = ring:GetVertexColor()
	if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
		return
	end
	if (math.max(r, g, b) - math.min(r, g, b)) <= QUALITY_CHROMA then
		return
	end
	return r, g, b
end

-- Quality from an item link (5.4.8 item buttons rarely carry IconBorder).
function WSkin.LinkQuality(link)
	if not link then
		return
	end
	local _, _, quality = GetItemInfo(link)
	if quality and quality >= 2 then
		local r, g, b = GetItemQualityColor(quality)
		return r, g, b
	end
end

local _qTiles = setmetatable({}, { __mode = "k" })
local function PaintQuality(btn)
	local host = _qTiles[btn]
	if not host then
		return
	end
	local name = btn.GetName and btn:GetName()
	local ring = btn.IconBorder or (name and _G[name .. "IconBorder"])
	local r, g, b = WSkin.RingQuality(ring)
	PP.SetBorderColor(host, r or 0, g or 0, b or 0, 1)
end
WSkin.PaintQuality = PaintQuality

-- Square 1px border on `owner` around `icon`. With r, g, b: that color;
-- without: follows the button's IconBorder ring when it has one (else black;
-- call WSkin.SetQualityColor to paint it from an item link).
function WSkin.QualityBorder(owner, icon, r, g, b)
	if not (owner and icon) then
		return
	end
	local d = GetFFD(owner)
	local host = d.qBorder
	if not host then
		host = CreateFrame("Frame", nil, owner)
		host:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
		host:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
		host:SetFrameLevel(owner:GetFrameLevel() + 6)
		PP.CreateBorder(host, 0, 0, 0, 1, 1, "OVERLAY", 7)
		d.qBorder = host
	end
	if r then
		_qTiles[owner] = nil
		PP.SetBorderColor(host, r, g, b, 1)
		return
	end
	_qTiles[owner] = host
	PaintQuality(owner)
end

-- Paint a tile's square border from an item link (nil link = black).
function WSkin.SetQualityColor(owner, link)
	local d = FFD[owner]
	local host = d and d.qBorder
	if not host then
		return
	end
	local r, g, b = WSkin.LinkQuality(link)
	PP.SetBorderColor(host, r or 0, g or 0, b or 0, 1)
end

-- Square an icon (crop the baked bevel) and optionally border it.
function WSkin.SquareIcon(icon, parent, quality)
	if not icon or not icon.SetTexCoord then
		return
	end
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	if parent then
		if quality then
			WSkin.QualityBorder(parent, icon)
		else
			WSkin.BorderRegion(parent, icon)
		end
	end
	return true
end

-- One quest-style reward tile (QuestInfoItem / QuestInfoRewardItem): name
-- plate gone, white name, square icon + rarity border.
local REWARD_TILE_ART = { "NameFrame", "IconBorder", "IconOverlay" }
function WSkin.QuestRewardTile(btn)
	if not btn then
		return
	end
	local n = btn.GetName and btn:GetName()
	for i = 1, #REWARD_TILE_ART do
		local k = REWARD_TILE_ART[i]
		local t = btn[k] or (n and _G[n .. k])
		if type(t) == "table" and t.SetAlpha and t.IsObjectType and t:IsObjectType("Texture") then
			t:SetAlpha(0)
		end
	end
	local name = btn.Name or (n and _G[n .. "Name"])
	if name and name.SetTextColor then
		name:SetTextColor(1, 1, 1)
	end
	local icon = btn.Icon or (n and _G[n .. "IconTexture"])
	WSkin.SquareIcon(icon, btn, true)
end

-- Remove the round corner portrait of a ButtonFrameTemplate /
-- PortraitFrameTemplate window.
function WSkin.RemovePortrait(frame)
	if not frame then
		return
	end
	local name = frame.GetName and frame:GetName()
	for _, k in ipairs({ "portrait", "Portrait", "PortraitFrame", "portraitFrame", "PortraitOverlay" }) do
		local t = frame[k] or (name and _G[name .. k])
		if type(t) == "table" and t.SetAlpha then t:SetAlpha(0) end
	end
end

-------------------------------------------------------------------------------
--  Tabs. One PanelTemplates hook keeps selection state fresh on all skinned
--  tabs (CharacterFrameTabButtonTemplate, TabButtonTemplate, top tabs).
-------------------------------------------------------------------------------
local _skinnedTabs = setmetatable({}, { __mode = "k" })

local TAB_BG = { 0.068, 0.056, 0.052 }
local TAB_BG_DARK = { 0.03, 0.03, 0.03 }

local function TabIsSelected(tab)
	local od = FFD[tab]
	if od and od.selOverride ~= nil then
		return od.selOverride
	end
	if od and od.selFn then
		local ok, v = pcall(od.selFn, tab)
		if ok then return v and true or false end
	end
	-- PanelTemplates disable the selected tab (5.4.8).
	if tab.IsEnabled and od and od.panelTab then
		return not tab:IsEnabled()
	end
	local parent = tab:GetParent()
	if parent and PanelTemplates_GetSelectedTab and tab.GetID then
		local ok, s = pcall(PanelTemplates_GetSelectedTab, parent)
		if ok and s ~= nil then
			return s == tab:GetID()
		end
	end
	return false
end

local function UpdateTabVisual(tab)
	local d = FFD[tab]
	if not d or not d.underline then
		return
	end
	local sel = TabIsSelected(tab)
	-- PanelTemplates swap the tab's font object on every select / enable,
	-- which brings Blizzard's label back: hide it again on every update.
	if d.blizLabel and d.blizLabel.SetAlpha then
		d.blizLabel:SetAlpha(0)
		if d.blizLabel.SetTextColor then d.blizLabel:SetTextColor(0, 0, 0, 0) end
	end
	if d.label then
		d.label:SetTextColor(1, 1, 1, sel and 1 or 0.5)
	end
	d.underline:SetShown(sel and WSkin.AccentBarShown())
	if d.activeHL then
		d.activeHL:SetShown(sel and not d.darkActive)
	end
	if d.bg and d.darkActive then
		local c = sel and TAB_BG_DARK or TAB_BG
		d.bg:SetTexture(c[1], c[2], c[3], 1)
	end
end

local function UpdateAllTabs()
	for tab in pairs(_skinnedTabs) do
		UpdateTabVisual(tab)
	end
end
WSkin.UpdateAllTabs = UpdateAllTabs

function WSkin.SetTabSelection(tab, selected)
	if not tab then
		return
	end
	GetFFD(tab).selOverride = selected
	UpdateTabVisual(tab)
end

local _tabHooked = false
local function EnsureTabHooks()
	if _tabHooked then
		return
	end
	_tabHooked = true
	for _, fn in ipairs({ "PanelTemplates_SetTab", "PanelTemplates_UpdateTabs", "PanelTemplates_SelectTab", "PanelTemplates_DeselectTab", "PanelTemplates_EnableTab", "PanelTemplates_DisableTab" }) do
		if _G[fn] then
			hooksecurefunc(fn, UpdateAllTabs)
		end
	end
end

local TAB_PIECES = { "Left", "Middle", "Right", "LeftDisabled", "MiddleDisabled", "RightDisabled",
	"HighlightTexture", "LeftHighlight", "MiddleHighlight", "RightHighlight", "LeftActive", "MiddleActive", "RightActive" }

-- Tab -> flat dark block, our own 11px label mirroring Blizzard's text, a
-- faint wash + an accent underline on the active tab.
-- opts.darkActive: darker fill on the active tab instead of the wash.
-- opts.isSelected = function(tab) for tabs outside PanelTemplates.
-- opts.keepIcon: leave tab.Icon / $parentIcon alone (icon side tabs).
function WSkin.Tab(tab, opts)
	if not tab or Forbidden(tab) then
		return
	end
	local d = GetFFD(tab)
	if opts and opts.darkActive then d.darkActive = true end
	if opts and opts.isSelected then d.selFn = opts.isSelected end
	if d.bg then
		UpdateTabVisual(tab)
		if d.label and d.blizLabel and d.blizLabel.GetText then
			d.label:SetText(d.blizLabel:GetText() or "")
		end
		return
	end
	d.skinned = true
	d.panelTab = not (opts and opts.isSelected) and tab:GetParent() and tab:GetParent().numTabs ~= nil
	local name = tab.GetName and tab:GetName()
	local icon = tab.Icon or (name and _G[name .. "Icon"])
	local regions = { tab:GetRegions() }
	for j = 1, #regions do
		local r = regions[j]
		if r and r ~= icon and r.IsObjectType and r:IsObjectType("Texture") then
			r:SetTexture("")
		end
	end
	for _, k in ipairs(TAB_PIECES) do
		local t = tab[k] or (name and _G[name .. k])
		if t and t.SetTexture then t:SetTexture("") end
	end
	local hl = tab.GetHighlightTexture and tab:GetHighlightTexture()
	if hl then hl:SetTexture("") end

	d.bg = SolidTex(tab, "BACKGROUND", TAB_BG[1], TAB_BG[2], TAB_BG[3], 1)
	-- 5.4.8 bottom tabs keep transparent art margins: the block sits on the
	-- visible part of the tab.
	local ins = opts and opts.inset
	if ins then
		d.bg:SetPoint("TOPLEFT", tab, "TOPLEFT", ins[1], -ins[2])
		d.bg:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -ins[3], ins[4])
	else
		d.bg:SetAllPoints()
	end

	local activeHL = tab:CreateTexture(nil, "ARTWORK", nil, -6)
	activeHL:SetAllPoints(d.bg)
	activeHL:SetTexture(1, 1, 1, 0.02)
	activeHL:SetBlendMode("ADD")
	activeHL:Hide()
	d.activeHL = activeHL

	local hover = tab:CreateTexture(nil, "HIGHLIGHT")
	hover:SetAllPoints(d.bg)
	hover:SetTexture(1, 1, 1, 0.05)
	d.hover = hover

	local blizLabel = tab.Text or (name and _G[name .. "Text"]) or (tab.GetFontString and tab:GetFontString())
	local labelText = (blizLabel and blizLabel.GetText and blizLabel:GetText()) or ""
	if blizLabel and blizLabel.SetAlpha then
		blizLabel:SetAlpha(0)
	end
	if tab.SetPushedTextOffset then tab:SetPushedTextOffset(0, 0) end

	local label = tab:CreateFontString(nil, "OVERLAY")
	label:SetFont(Theme.fontPath, 11, Theme.fontFlag or "")
	if Theme.fontShadow then
		label:SetShadowOffset(1, -1)
		label:SetShadowColor(0, 0, 0, 1)
	end
	label:SetPoint("CENTER", d.bg, "CENTER", 0, 0)
	label:SetText(labelText)
	d.label = label
	d.blizLabel = blizLabel
	local function SyncLabel()
		if d.label and d.blizLabel and d.blizLabel.GetText then
			d.label:SetText(d.blizLabel:GetText() or "")
		end
	end
	hooksecurefunc(tab, "SetText", SyncLabel)
	if blizLabel and blizLabel ~= tab then
		hooksecurefunc(blizLabel, "SetText", SyncLabel)
		if blizLabel.SetFormattedText then
			hooksecurefunc(blizLabel, "SetFormattedText", SyncLabel)
		end
	end

	local underline = tab:CreateTexture(nil, "OVERLAY", nil, 6)
	underline:SetHeight(PP.mult or 1)
	underline:SetPoint("BOTTOMLEFT", d.bg, "BOTTOMLEFT", 0, 0)
	underline:SetPoint("BOTTOMRIGHT", d.bg, "BOTTOMRIGHT", 0, 0)
	local ur, ug, ub = WSkin.AccentBarColor()
	underline:SetTexture(ur, ug, ub, 1)
	underline:Hide()
	d.underline = underline

	_skinnedTabs[tab] = true
	EnsureTabHooks()
	tab:HookScript("OnClick", function()
		BS.After(0, UpdateAllTabs)
	end)
	tab:HookScript("OnShow", function() UpdateTabVisual(tab) end)
	tab:HookScript("OnEnable", function() UpdateTabVisual(tab) end)
	tab:HookScript("OnDisable", function() UpdateTabVisual(tab) end)
	UpdateTabVisual(tab)
end

-- Re-chain a row of skinned tabs with a 1px seam (first tab keeps its seat).
function WSkin.NormalizeTabRow(tabs, gap)
	if not tabs then
		return
	end
	local prev
	for i = 1, #tabs do
		local t = tabs[i]
		if t and (not t.IsShown or t:IsShown()) then
			if prev then
				t:ClearAllPoints()
				t:SetPoint("LEFT", prev, "RIGHT", gap or 1, 0)
			end
			prev = t
		end
	end
end

-- Tabs of a frame that uses PanelTemplates ($parentTab1..numTabs).
function WSkin.TabsOf(frame, prefix, opts)
	local name = prefix or (frame and frame.GetName and frame:GetName())
	if not name then
		return {}
	end
	local tabs = {}
	local n = (frame and frame.numTabs) or 10
	for i = 1, n do
		local t = _G[name .. "Tab" .. i]
		if not t then
			break
		end
		WSkin.Tab(t, opts)
		tabs[#tabs + 1] = t
	end
	return tabs
end

-------------------------------------------------------------------------------
--  Global look settings (Window Skins > Global Options). nil = defaults:
--  accent bar shown + accent colored, bar fills accent, links accent.
-------------------------------------------------------------------------------
local function LiveAccent()
	return BS.Accent()
end

function WSkin.AccentBarShown()
	local c = BS.DB().blizzWinAccentBar
	return not (type(c) == "table" and c.enabled == false)
end

function WSkin.AccentBarColor()
	local c = BS.DB().blizzWinAccentBar
	if type(c) == "table" and c.useCustom then
		local col = c.color
		if col then return col.r or 1, col.g or 1, col.b or 1 end
		return 1, 1, 1
	end
	return LiveAccent()
end

function WSkin.BarFillColor()
	local c = BS.DB().blizzWinBarFill
	local a = (type(c) == "table" and c.alpha) or 0.95
	if type(c) == "table" and c.useCustom then
		local col = c.color
		if col then return col.r or 1, col.g or 1, col.b or 1, a end
		return 1, 1, 1, a
	end
	local r, g, b = LiveAccent()
	return r * 0.8, g * 0.8, b * 0.8, a
end

function WSkin.LinkColor()
	local c = BS.DB().blizzWinLinks
	if type(c) == "table" and c.useCustom then
		local col = c.color
		if col then return col.r or 1, col.g or 1, col.b or 1 end
		return 1, 1, 1
	end
	return LiveAccent()
end

function WSkin.LinkColorHex()
	local r, g, b = WSkin.LinkColor()
	return string.format("%02x%02x%02x",
		math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local _fillBars = setmetatable({}, { __mode = "k" })
local _extUnderlines = setmetatable({}, { __mode = "k" })
local _lookCallbacks = {}

-- Flat accent progress bar fill (StatusBar).
function WSkin.ApplyBarFill(bar)
	if not bar or not bar.SetStatusBarColor then
		return
	end
	_fillBars[bar] = true
	if bar.SetStatusBarTexture then
		bar:SetStatusBarTexture(WHITE)
	end
	local r, g, b, a = WSkin.BarFillColor()
	bar:SetStatusBarColor(r, g, b, a)
end

function WSkin.RegisterAccentUnderline(tex)
	if tex then _extUnderlines[tex] = true end
end

function WSkin.OnLooksChanged(fn)
	_lookCallbacks[#_lookCallbacks + 1] = fn
end

function WSkin.RefreshLooks()
	ResolveTheme()
	local ur, ug, ub = WSkin.AccentBarColor()
	for tab in pairs(_skinnedTabs) do
		local d = FFD[tab]
		if d and d.underline then d.underline:SetTexture(ur, ug, ub, 1) end
		UpdateTabVisual(tab)
	end
	for tex in pairs(_extUnderlines) do
		tex:SetTexture(ur, ug, ub, 1)
	end
	local br, bgr, bb, ba = WSkin.BarFillColor()
	for bar in pairs(_fillBars) do
		if bar.SetStatusBarColor then
			bar:SetStatusBarColor(br, bgr, bb, ba)
		end
	end
	for _, fn in ipairs(_lookCallbacks) do
		pcall(fn)
	end
end
ns._WSkinRefreshLooks = WSkin.RefreshLooks
BS.OnAccentChanged(function() WSkin.RefreshLooks() end)
BS.OnApply(function()
	WSkin.RefreshLooks()
	WSkin.RefreshStyles()
end)

-------------------------------------------------------------------------------
--  Targeted art sweeps (skin time / debounced hooks only).
-------------------------------------------------------------------------------
function WSkin.ExemptArt(frame)
	if frame then GetFFD(frame).artExempt = true end
end
function WSkin.IsArtExempt(frame)
	local d = FFD[frame]
	return d and d.artExempt or false
end

-- Frame provenance: Blizzard's frames leave SECURE references (their global
-- name, their parentKey); frames another addon parented into a Blizzard
-- window leave tainted ones. Recursive discovery sweeps skip foreign frames.
local _foreign = setmetatable({}, { __mode = "k" })
function WSkin.IsForeignFrame(frame, parent)
	if _foreign[frame] then
		return true
	end
	local name = frame.GetName and frame:GetName()
	if name and _G[name] == frame then
		if issecurevariable(name) then
			return false
		end
		_foreign[frame] = true
		return true
	end
	parent = parent or (frame.GetParent and frame:GetParent())
	if not parent then
		return false
	end
	local insecureRef = false
	for k, v in pairs(parent) do
		if type(k) == "string" and v == frame then
			if issecurevariable(parent, k) then
				return false
			end
			insecureRef = true
		end
	end
	if insecureRef then
		_foreign[frame] = true
		return true
	end
	return false
end

local BG_ART_KEYS = {
	"CustomBG", "InfoBackground", "BackgroundTexture", "DungeonBackground",
	"Background", "background", "Bg", "bg", "BG", "WaterMark", "Watermark",
	"BackgroundOverlay", "Backplate", "CategoriesBG", "BackgroundTile",
	"TopFiligree", "BottomFiligree", "FilligreeOverlay",
	"BorderTopLeft", "BorderTopMiddle", "BorderTopRight",
	"BorderLeftMiddle", "BorderRightMiddle",
	"BorderBottomLeft", "BorderBottomMiddle", "BorderBottomRight",
	"TopTileStreaks", "TopLeftCorner", "TopRightCorner", "BotLeftCorner", "BotRightCorner",
	"TopBorder", "BottomBorder", "LeftBorder", "RightBorder", "BtnCornerLeft", "BtnCornerRight", "ButtonBottomBorder",
}
function WSkin.FadeKeyedArt(frame, depth)
	depth = depth or 0
	if not frame or depth > 6 or Forbidden(frame) then
		return
	end
	if WSkin.IsArtExempt(frame) then
		return
	end
	if depth > 0 and WSkin.IsForeignFrame(frame) then
		return
	end
	local name = frame.GetName and frame:GetName()
	for _, key in ipairs(BG_ART_KEYS) do
		local t = frame[key] or (name and _G[name .. key])
		if type(t) == "table" and t.IsObjectType and t:IsObjectType("Texture") then
			t:SetAlpha(0)
		end
	end
	if not frame.GetChildren then
		return
	end
	local children = { frame:GetChildren() }
	for i = 1, #children do
		WSkin.FadeKeyedArt(children[i], depth + 1)
	end
end

local ART_KEYWORDS = {
	"background", "corner", "parchment", "watermark", "shadow",
	"divider", "wood", "metal", "modelbackground", "-bg", "bg-", "_bg",
	"frametexture", "sheen", "plaque", "tile", "marble", "stone", "filigree",
	"ui-frame", "uiframe", "ui-panel", "border", "paper", "bookbg",
}
local function texIsIcon(hay)
	return hay and (hay:find("interface\\icons", 1, true) or hay:find("interface/icons", 1, true))
end
local function texHay(tex)
	local file = tex.GetTexture and tex:GetTexture()
	if type(file) == "string" then
		return file:lower()
	end
	return nil
end
WSkin.TexHay = texHay
WSkin.TexIsIcon = texIsIcon

-- Alpha decorative art under a frame by texture path keyword, keeping icons
-- and our own textures. Depth-capped.
function WSkin.FadeArtIn(frame, depth)
	depth = depth or 0
	if not frame or depth > 9 or not frame.GetRegions or Forbidden(frame) then
		return
	end
	if WSkin.IsArtExempt(frame) then
		return
	end
	if depth > 0 and WSkin.IsForeignFrame(frame) then
		return
	end
	local fd = FFD[frame]
	local regions = { frame:GetRegions() }
	for i = 1, #regions do
		local r = regions[i]
		if r and r.IsObjectType and r:IsObjectType("Texture") and (r:GetAlpha() or 0) > 0 then
			local mine = false
			if fd then
				for _, key in ipairs(PROTECT_KEYS) do
					if fd[key] == r then mine = true break end
				end
			end
			if not mine then
				local hay = texHay(r)
				if hay and not texIsIcon(hay) and not hay:find("white8x8", 1, true) then
					for _, kw in ipairs(ART_KEYWORDS) do
						if hay:find(kw, 1, true) then
							r:SetAlpha(0)
							break
						end
					end
				end
			end
		end
	end
	local children = { frame:GetChildren() }
	for i = 1, #children do
		WSkin.FadeArtIn(children[i], depth + 1)
	end
end

-- Flatten 3-slice buttons (UIPanelButtonTemplate etc.) under a frame. Never
-- touches icon buttons.
local function IsPanelButton(btn)
	if not btn.GetObjectType or btn:GetObjectType() ~= "Button" then
		return false
	end
	if btn.Left and btn.Middle and btn.Right then
		return true
	end
	local name = btn.GetName and btn:GetName()
	if name and _G[name .. "Left"] and _G[name .. "Middle"] and _G[name .. "Right"] and not _G[name .. "Icon"] then
		return true
	end
	-- UIPanelButtonTemplate: its Normal texture is the red button art.
	local nt = btn.GetNormalTexture and btn:GetNormalTexture()
	local hay = nt and texHay(nt)
	return hay and hay:find("ui-panel-button", 1, true) and true or false
end
WSkin.IsPanelButton = IsPanelButton

function WSkin.ButtonsIn(frame, depth)
	depth = depth or 0
	if not frame or depth > 9 or not frame.GetChildren or Forbidden(frame) then
		return
	end
	local children = { frame:GetChildren() }
	for i = 1, #children do
		local child = children[i]
		if child and not WSkin.IsForeignFrame(child, frame) then
			local cd = FFD[child]
			if not (cd and (cd.skinned or cd.x or cd.block)) and IsPanelButton(child) then
				WSkin.Button(child)
			end
			WSkin.ButtonsIn(child, depth + 1)
		end
	end
end

-- Search boxes, edit boxes and UIDropDownMenus under a frame, by parentKey
-- or by their template art.
local CONTROL_KEYS = {
	"SearchBox", "searchBox", "FilterDropdown", "FilterButton", "TypeDropdown", "Dropdown", "ClassDropdown",
}
local function IsDropDown(f)
	local name = f.GetName and f:GetName()
	return name and _G[name .. "Button"] and _G[name .. "Text"] and _G[name .. "Middle"] and true or false
end
WSkin.IsDropDown = IsDropDown
function WSkin.ControlsIn(frame, depth)
	depth = depth or 0
	if not frame or depth > 9 or not frame.GetChildren or Forbidden(frame) then
		return
	end
	if depth > 0 and WSkin.IsForeignFrame(frame) then
		return
	end
	for _, key in ipairs(CONTROL_KEYS) do
		local el = frame[key]
		if el and el.IsObjectType then
			if el:IsObjectType("EditBox") then
				WSkin.EditBox(el)
			elseif IsDropDown(el) then
				WSkin.Dropdown(el)
			end
		end
	end
	local children = { frame:GetChildren() }
	for i = 1, #children do
		local c = children[i]
		if c.IsObjectType and c:IsObjectType("EditBox") then
			local n = c.GetName and c:GetName()
			if c.Left or (n and _G[n .. "Left"]) then
				WSkin.EditBox(c)
			end
		elseif IsDropDown(c) then
			WSkin.Dropdown(c)
		end
		WSkin.ControlsIn(c, depth + 1)
	end
end

-- Common chrome for a framed window: close button, search/filter controls,
-- page nav, scroll bars, a centered title.
function WSkin.CommonChrome(frame, prefix, explicitControls)
	prefix = prefix or (frame.GetName and frame:GetName())
	if frame.CloseButton then WSkin.CloseButton(frame.CloseButton) end
	if prefix then
		local cb = _G[prefix .. "CloseButton"]
		if cb then WSkin.CloseButton(cb) end
	end
	if not explicitControls then
		WSkin.ControlsIn(frame)
		WSkin.PagingIn(frame)
		WSkin.ScrollBarsIn(frame)
	end
	local d = GetFFD(frame)
	if not d.titleCentered and d.topBar then
		local title = frame.TitleText or (prefix and (_G[prefix .. "TitleText"] or _G[prefix .. "Title"]))
		if title and title.ClearAllPoints and title.IsObjectType and title:IsObjectType("FontString") then
			d.titleCentered = true
			title:ClearAllPoints()
			title:SetPoint("CENTER", d.topBar, "CENTER", 0, 0)
			if title.SetJustifyH then title:SetJustifyH("CENTER") end
			WSkin.White(title)
		end
	end
end

function WSkin.HookShow(frame, fn)
	local d = GetFFD(frame)
	if d.showHook then
		return
	end
	d.showHook = true
	frame:HookScript("OnShow", fn)
end

-- Side tab (SpellBookSkillLineTab, PetJournal side tabs): gold frame gone,
-- the icon stays squared with a black edge; checked = accent edge.
function WSkin.SideTab(tab)
	if not tab then
		return
	end
	local d = GetFFD(tab)
	if d.sideTab then
		return
	end
	d.sideTab = true
	local name = tab.GetName and tab:GetName()
	local regions = { tab:GetRegions() }
	-- Guild bank tabs keep the icon in "<name>IconTexture" (their normal
	-- texture is the quickslot frame); spellbook tabs use the normal texture.
	local icon = tab.icon or tab.Icon or (name and (_G[name .. "IconTexture"] or _G[name .. "Icon"]))
	if not (icon and icon.IsObjectType and icon:IsObjectType("Texture")) then
		icon = tab.GetNormalTexture and tab:GetNormalTexture()
	end
	for i = 1, #regions do
		local r = regions[i]
		if r ~= icon and r.IsObjectType and r:IsObjectType("Texture") then
			r:SetAlpha(0)
		end
	end
	if icon then
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", 2, -2)
		icon:SetPoint("BOTTOMRIGHT", -2, 2)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end
	local pushed = tab.GetPushedTexture and tab:GetPushedTexture()
	if pushed then pushed:SetAlpha(0) end
	local hl = tab.GetHighlightTexture and tab:GetHighlightTexture()
	if hl then
		hl:SetTexture(1, 1, 1, 0.15)
		hl:ClearAllPoints()
		hl:SetPoint("TOPLEFT", 2, -2)
		hl:SetPoint("BOTTOMRIGHT", -2, 2)
	end
	local ct = tab.GetCheckedTexture and tab:GetCheckedTexture()
	if ct then ct:SetTexture("") end
	local host = CreateFrame("Frame", nil, tab)
	host:SetPoint("TOPLEFT", 1, -1)
	host:SetPoint("BOTTOMRIGHT", -1, 1)
	host:SetFrameLevel(tab:GetFrameLevel() + 2)
	PP.CreateBorder(host, 0, 0, 0, 1, 1, "OVERLAY", 7)
	d.borderHost = host
	local function reflect()
		local on = tab.GetChecked and tab:GetChecked()
		if on then
			local r, g, b = WSkin.AccentBarColor()
			PP.SetBorderColor(host, r, g, b, 1)
		else
			PP.SetBorderColor(host, 0, 0, 0, 1)
		end
	end
	d.reflect = reflect
	if tab.SetChecked then
		hooksecurefunc(tab, "SetChecked", reflect)
	end
	reflect()
end

-- An item / action slot button (ItemButtonTemplate-style): art gone, dark
-- block, square icon + border. opts.quality: rarity border.
function WSkin.ItemButton(btn, opts)
	if not btn or Forbidden(btn) then
		return
	end
	local d = GetFFD(btn)
	if d.itemSkinned then
		return
	end
	d.itemSkinned = true
	local name = btn.GetName and btn:GetName()
	local icon = btn.icon or btn.Icon or (name and (_G[name .. "IconTexture"] or _G[name .. "Icon"]))
	local nt = btn.GetNormalTexture and btn:GetNormalTexture()
	if nt then nt:SetAlpha(0) end
	local pt = btn.GetPushedTexture and btn:GetPushedTexture()
	if pt then pt:SetTexture(1, 1, 1, 0.15) end
	local hl = btn.GetHighlightTexture and btn:GetHighlightTexture()
	if hl then
		hl:SetTexture(1, 1, 1, 0.12)
		if icon then hl:SetAllPoints(icon) end
	end
	local bg = SolidTex(btn, "BACKGROUND", 0.02, 0.02, 0.02, 0.6, -1)
	if icon then bg:SetAllPoints(icon) else bg:SetAllPoints(btn) end
	d.bg = bg
	if icon then
		WSkin.SquareIcon(icon, btn, opts and opts.quality)
	end
end

-- Debounce: many hook fires in one frame -> one pass.
function WSkin.Debounce(fn)
	if registrationWindow then
		fn = WSkin.WindowCallback(registrationWindow, fn)
	end
	local pending = false
	return function()
		if pending then
			return
		end
		pending = true
		BS.After(0, function()
			pending = false
			fn()
		end)
	end
end

-------------------------------------------------------------------------------
--  Per-window boot. Packs register
--    { key, label, description, order, addons = { [name] = true }, elvui = "<E.private.skins.blizzard key>", apply = fn }
--  and the engine applies them when their Blizzard addon loads (or at login
--  for ones already loaded). Gated on the window style ("off" = never runs),
--  on ElvUI's own skin for that window, and pcall-isolated.
-------------------------------------------------------------------------------
local _windows = {}
WSkin.windows = _windows

-- Window list for the settings page: one entry per key (first one with a
-- label wins), sorted by order then label.
function WSkin.WindowList()
	local seen, list = {}, {}
	for _, e in ipairs(_windows) do
		if e.label and not seen[e.key] then
			seen[e.key] = true
			list[#list + 1] = e
		end
	end
	table.sort(list, function(a, b)
		local oa, ob = a.order or 500, b.order or 500
		if oa ~= ob then return oa < ob end
		return a.label < b.label
	end)
	return list
end

-- True when ElvUI skins this window itself (our pack stands down).
function WSkin.ElvUIOwns(winKey)
	for _, e in ipairs(_windows) do
		if e.key == winKey and e.elvui and BS.ElvUISkins(e.elvui) then
			return true
		end
	end
	return false
end

local function WindowOn(entry)
	if WSkin.GetStyle(entry.key) == "off" then
		return false
	end
	if entry.elvui and BS.ElvUISkins(entry.elvui) then
		return false
	end
	return true
end

local function TryApply(entry)
	if entry.applied or not WindowOn(entry) then
		return
	end
	entry.applied = true
	ResolveTheme()
	local previous = registrationWindow
	registrationWindow = entry.key
	local ok, err = pcall(entry.apply)
	registrationWindow = previous
	if not ok and err then
		geterrorhandler()(err)
	end
end

function WSkin.RegisterWindow(entry)
	_windows[#_windows + 1] = entry
	-- A pack registered after login (late file) whose addon is in already.
	if IsLoggedIn and IsLoggedIn() then
		local ready = true
		if entry.addons then
			for addon in pairs(entry.addons) do
				if not IsAddOnLoaded(addon) then ready = false break end
			end
		end
		if ready then TryApply(entry) end
	end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(_, event, name)
	if event == "PLAYER_LOGIN" then
		ResolveTheme()
		for _, entry in ipairs(_windows) do
			local ready = true
			if entry.addons then
				for addon in pairs(entry.addons) do
					if not IsAddOnLoaded(addon) then
						ready = false
						break
					end
				end
			end
			if ready then
				TryApply(entry)
			end
		end
		WSkin.RefreshStyles()
	elseif event == "ADDON_LOADED" and IsLoggedIn() then
		for _, entry in ipairs(_windows) do
			if entry.addons and entry.addons[name] then
				local ready = true
				for addon in pairs(entry.addons) do
					if not IsAddOnLoaded(addon) then ready = false break end
				end
				if ready then
					TryApply(entry)
				end
			end
		end
	end
end)
