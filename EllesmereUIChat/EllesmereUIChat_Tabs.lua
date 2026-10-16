-------------------------------------------------------------------------------
--  EllesmereUIChat_Tabs.lua  (5.4.8 port of EllesmereUIChat_Tabs.lua)
--
--  EllesmereUI tabs drawn over Blizzard's tabs. Blizzard's tabs stay the
--  working buttons (click, drag to undock, tab menu, whisper windows); their
--  art and label are emptied and a "ghost" (our frame, a child of the tab)
--  paints the EllesmereUI tab: background color or texture, label, active
--  underline, border, separator and the whisper alert glow. Being the tab's
--  child, a ghost follows it everywhere, also into the dock's scroll area.
--
--  Tab width: the label width plus Inner Padding X on each side (General and
--  Combat Log; whisper tabs keep Blizzard's dock sizes).
-------------------------------------------------------------------------------
local _, P = ...
local ECHAT = P.ECHAT
local DB = P.DB
local FD = P.FD

local floor, min, max = math.floor, math.min, math.max

-- Blizzard tab -> its ghost (only chat tabs are in here).
local ghostOf = {}

local function TabFontPath()
	return P.ResolveFont(DB().tabFont)
end

local function TabFontFlag()
	return ECHAT.GetOutlineFlag()
end

-------------------------------------------------------------------------------
--  Ghost
-------------------------------------------------------------------------------
local function Pulse(g, elapsed)
	g.pulse = (g.pulse or 0) + elapsed
	local t = (g.pulse % 1) * 2
	if t > 1 then
		t = 2 - t
	end
	g.glow:SetAlpha(0.25 + 0.5 * t)
end

local function StartFlash(g)
	if not g.flashing then
		g.flashing = true
		g.pulse = 0
		g.glow:Show()
		g:SetScript("OnUpdate", Pulse)
	end
end

local function StopFlash(g)
	if g.flashing then
		g.flashing = nil
		g:SetScript("OnUpdate", nil)
	end
	g.glow:Hide()
end

local function BuildGhost(tab)
	local g = CreateFrame("Frame", nil, tab)
	g:EnableMouse(false)
	g.bg = g:CreateTexture(nil, "BACKGROUND")
	g.bg:SetAllPoints()
	g.fs = g:CreateFontString(nil, "OVERLAY")
	P.SetFont(g.fs, TabFontPath(), DB().tabFontSize or 11, TabFontFlag())
	g.fs:SetWordWrap(false)
	g.fs:SetJustifyH("CENTER")
	-- Measures the label's natural width (the visible label is edge-clamped).
	g.measure = g:CreateFontString(nil, "OVERLAY")
	P.SetFont(g.measure, TabFontPath(), DB().tabFontSize or 11, TabFontFlag())
	g.measure:Hide()
	g.underline = g:CreateTexture(nil, "OVERLAY", nil, 7)
	g.underline:SetPoint("BOTTOMLEFT")
	g.underline:SetPoint("BOTTOMRIGHT")
	g.underline:Hide()
	g.sep = g:CreateTexture(nil, "OVERLAY", nil, 7)
	g.sep:SetPoint("TOPLEFT", g, "TOPRIGHT", 0, 0)
	g.sep:SetPoint("BOTTOMLEFT", g, "BOTTOMRIGHT", 0, 0)
	g.sep:Hide()
	g.edges = P.CreateEdges(g, g, "BORDER", 1)
	-- Whisper alert: Blizzard's art, tinted with the label color.
	g.glow = g:CreateTexture(nil, "OVERLAY", nil, 6)
	g.glow:SetTexture("Interface\\ChatFrame\\ChatFrameTab-NewMessage")
	g.glow:SetBlendMode("ADD")
	g.glow:SetDesaturated(true)
	g.glow:SetPoint("TOPLEFT", g, "TOPLEFT", 8, -11)
	g.glow:SetPoint("BOTTOMRIGHT", g, "BOTTOMRIGHT", -8, 0)
	g.glow:Hide()
	return g
end

-- Blizzard's tab label (GetRegions does not always return a Button's text
-- in 5.4.8, so it is hidden by name too, on every refresh).
local function HideBlizzardLabel(tab)
	local fs = tab.GetFontString and tab:GetFontString()
	if fs then
		fs:SetAlpha(0)
	end
	local named = _G[tab:GetName() .. "Text"]
	if named and named ~= fs then
		named:SetAlpha(0)
	end
end

local function TabLabel(tab)
	local text = tab.GetText and tab:GetText()
	if not text or text == "" then
		local fs = _G[tab:GetName() .. "Text"]
		text = fs and fs:GetText()
	end
	return text or ""
end

-- Blizzard's tab art and label emptied; the ghost paints instead.
function ECHAT.SkinTab(cf)
	local tab = _G[cf:GetName() .. "Tab"]
	if not tab then
		return
	end
	local td = FD(tab)
	if td.ghost then
		return
	end
	for _, r in ipairs({ tab:GetRegions() }) do
		local t = r.GetObjectType and r:GetObjectType()
		if t == "Texture" then
			r:SetTexture(nil)
			r:SetAlpha(0)
		elseif t == "FontString" then
			r:SetAlpha(0)
		end
	end
	HideBlizzardLabel(tab)
	local flash = _G[tab:GetName() .. "Flash"]
	if flash then
		P.HideRegionsOf(flash)
	end
	td.cf = cf
	td.ghost = BuildGhost(tab)
	ghostOf[tab] = td.ghost
	-- Tab alpha: docked tabs ride the dock's alpha (the chat fade), so they
	-- stay at 1; undocked tabs take the chat fade directly.
	hooksecurefunc(tab, "SetAlpha", function(self, a)
		if td.settingAlpha then
			return
		end
		local want = cf.isDocked and 1 or (P.alphaCur or 1)
		if a ~= want then
			td.settingAlpha = true
			self:SetAlpha(want)
			td.settingAlpha = false
		end
	end)
	tab:SetAlpha(1)
	if ECHAT.RequestTabRefresh then
		ECHAT.RequestTabRefresh()
	end
end

-------------------------------------------------------------------------------
--  Styling
-------------------------------------------------------------------------------
local function StyleGhost(g, cf, isActive)
	local cfg = DB()
	local fs = g.fs
	P.SetFont(fs, TabFontPath(), cfg.tabFontSize or 11, TabFontFlag())

	local tr, tg, tb, ta
	if cf.isTemporary then
		-- Whisper tabs keep the whisper color as their marker.
		local info = ChatTypeInfo[cf.chatType == "BN_WHISPER" and "BN_WHISPER" or "WHISPER"]
		tr, tg, tb, ta = (info and info.r) or 1, (info and info.g) or 0.5, (info and info.b) or 1, 1
	elseif isActive then
		tr, tg, tb, ta = P.ModeColor(cfg.tabFontColorActiveMode or "custom", cfg.tabFontColorActive,
			{ r = 1, g = 1, b = 1, a = 1 })
	else
		tr, tg, tb, ta = P.ModeColor(cfg.tabFontColorMode or "custom", cfg.tabFontColor,
			{ r = 1, g = 1, b = 1, a = 0.65 })
	end
	fs:SetTextColor(tr, tg, tb, ta)
	g.glow:SetVertexColor(tr, tg, tb)

	-- Background: color or texture, active / inactive.
	local br, bgc, bb, ba
	if isActive then
		br, bgc, bb, ba = P.ModeColor(cfg.tabBackgroundColorActiveMode or "custom", cfg.tabBackgroundColorActive,
			{ r = 0.03, g = 0.045, b = 0.05, a = 0.65 })
	else
		local c = cfg.tabBackgroundColor or {}
		br, bgc, bb = c.r or 0.03, c.g or 0.045, c.b or 0.05
		ba = c.a == nil and 0.44 or c.a
	end
	P.PaintFill(g.bg, P.TexturePath(cfg.tabBackgroundTexture), br, bgc, bb, ba)

	local px = P.PixelFor(g)
	-- Active underline.
	if cfg.activeUnderline ~= false and isActive then
		local mode = cfg.activeUnderlineColorMode or "accent"
		if mode == "border" then
			mode = "custom"
		end
		local ur, ug, ub, ua = P.ModeColor(mode, cfg.activeUnderlineColor, { r = 0.05, g = 0.82, b = 0.61, a = 1 })
		g.underline:SetTexture(ur, ug, ub, ua)
		g.underline:SetHeight(px)
		g.underline:Show()
	else
		g.underline:Hide()
	end

	-- Separator (tabs inside the panel): 1 px in the gap after the tab.
	local extend = ECHAT.ExtendBgBehindTabs(cfg)
	if extend and not cfg.hideBorders then
		g.sep:SetTexture(P.InnerBorderColor(cfg))
		g.sep:SetWidth(px)
		g.sep:Show()
	else
		g.sep:Hide()
	end

	-- Own border (tabs outside the panel): the panel's when synced.
	local prefix = (cfg.syncTabBorder ~= false) and "panelBorder" or "tabBorder"
	local steps = P.BORDER_STEPS[cfg[prefix .. "Thickness"] or "none"] or 0
	if extend then
		steps = 0
	end
	local r, gg, b, a = P.PanelBorderColor(cfg, prefix)
	if cfg.activeTabBorder ~= false and isActive and cfg.tabBorderColorActive then
		local ac = cfg.tabBorderColorActive
		r, gg, b = ac.r or r, ac.g or gg, ac.b or b
		a = ac.a == nil and a or ac.a
	end
	P.LayoutEdges(g.edges, steps * px, r, gg, b, a)
end

-------------------------------------------------------------------------------
--  Refresh: place and style every ghost
-------------------------------------------------------------------------------
local function PlaceLabel(g)
	local padX = DB().tabInnerPaddingX or 12
	g.fs:ClearAllPoints()
	g.fs:SetPoint("LEFT", g, "LEFT", padX, 0)
	g.fs:SetPoint("RIGHT", g, "RIGHT", -padX, 0)
end

local function RefreshTab(cf, isActive, leftInset, leftExtend)
	local tab = _G[cf:GetName() .. "Tab"]
	local td = tab and FD(tab)
	local g = td and td.ghost
	if not g then
		return
	end
	local cfg = DB()
	local height = P.TabHeight()
	g:ClearAllPoints()
	local band = P.band
	if cf.isDocked and band and band:IsShown() then
		local onePx = P.PixelFor(g)
		g:SetPoint("TOP", band, "TOP", 0, -onePx)
		g:SetPoint("BOTTOM", band, "BOTTOM", 0, 0)
		g:SetPoint("LEFT", tab, "LEFT", leftExtend or 0, 0)
		g:SetPoint("RIGHT", tab, "RIGHT", 0, 0)
	else
		g:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", leftInset or 0, 0)
		g:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, 0)
		g:SetHeight(height)
	end
	-- Clicks land on the visible part only.
	tab:SetHitRectInsets(0, 0, max(0, (tab:GetHeight() or 32) - height), 0)
	HideBlizzardLabel(tab)
	g.fs:SetText(TabLabel(tab))
	PlaceLabel(g)
	StyleGhost(g, cf, isActive)
	if isActive then
		StopFlash(g)
	elseif tab.alerting then
		StartFlash(g)
	else
		StopFlash(g)
	end
	g:Show()
	if tab.conversationIcon then
		tab.conversationIcon:SetAlpha(0)
	end
	local tabAlpha = cf.isDocked and 1 or (P.alphaCur or 1)
	if tab:GetAlpha() ~= tabAlpha then
		tab:SetAlpha(tabAlpha)
	end
end

local function RefreshNow()
	if not P.started then
		return
	end
	local cfg = DB()
	local selected = P.SelectedWindow()
	local px = P.PixelFor(UIParent)
	local gap = (cfg.tabSpacing or 1) * px
	local extend = ECHAT.ExtendBgBehindTabs(cfg)

	-- The panel reaches 10 px left of ChatFrame1; the first tab's ghost
	-- stretches to the panel edge so the row lines up with it.
	local leftExtend = 0
	local d1 = FD(ChatFrame1)
	local dock = GENERAL_CHAT_DOCK
	local list = dock and dock.DOCKED_CHAT_FRAMES
	local first = list and list[1]
	local firstTab = first and _G[first:GetName() .. "Tab"]
	local bgLeft = d1.bg and d1.bg:GetLeft()
	local tabLeft = firstTab and firstTab:GetLeft()
	if bgLeft and tabLeft then
		local delta = bgLeft - tabLeft
		if delta < 0 and delta > -60 then
			leftExtend = delta
		end
	end

	if type(list) == "table" then
		for i, cf in ipairs(list) do
			local inset = 0
			if i == 1 then
				inset = leftExtend
			elseif not extend then
				inset = gap
			end
			RefreshTab(cf, cf == selected, inset, i == 1 and leftExtend or 0)
		end
	end
	-- Undocked windows: their own tab above them, active while shown.
	P.ForEachChatFrame(function(cf)
		if not cf.isDocked and cf:IsShown() then
			RefreshTab(cf, true, 0, 0)
		end
	end)
end
ECHAT.TabsRefreshNow = RefreshNow

local queued = false
local function RequestRefresh()
	if queued then
		return
	end
	queued = true
	P.After(0, function()
		queued = false
		RefreshNow()
	end)
end
ECHAT.RequestTabRefresh = RequestRefresh
ECHAT.TabsRefresh = RequestRefresh

-- Width: label + Inner Padding X each side (Blizzard's static tab resize).
hooksecurefunc("PanelTemplates_TabResize", function(tab, padding, absoluteSize)
	if absoluteSize or not P.started or not tab then
		return
	end
	local g = ghostOf[tab]
	if not g then
		return
	end
	local cfg = DB()
	P.SetFont(g.measure, TabFontPath(), cfg.tabFontSize or 11, TabFontFlag())
	g.measure:SetText(TabLabel(tab))
	local w = (g.measure:GetStringWidth() or 30) + 2 * (cfg.tabInnerPaddingX or 12)
	-- Tab Spacing is cut from the left of every tab after the first: add it
	-- here so the label keeps its room.
	local list = GENERAL_CHAT_DOCK and GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES
	local first = list and list[1]
	local isFirst = first and _G[first:GetName() .. "Tab"] == tab
	if not isFirst and not ECHAT.ExtendBgBehindTabs(cfg) then
		w = w + (cfg.tabSpacing or 1) * P.PixelFor(UIParent)
	end
	-- A little slack: string widths round down.
	tab:SetWidth(max(24, math.ceil(w) + 2))
end)

-------------------------------------------------------------------------------
--  Options entry points (same names as retail)
-------------------------------------------------------------------------------
function ECHAT.ApplyTabAppearance()
	RequestRefresh()
end
ECHAT.ApplyTabBorders = ECHAT.ApplyTabAppearance
ECHAT.ApplyTabSeparators = ECHAT.ApplyTabAppearance
ECHAT.ApplyTabSpacing = ECHAT.ApplyTabAppearance

-- Fonts, height or padding changed: Blizzard re-measures the tabs.
function ECHAT.ApplyTabLayout()
	if not P.started then
		return
	end
	if GENERAL_CHAT_DOCK and FCFDock_UpdateTabs then
		FCFDock_UpdateTabs(GENERAL_CHAT_DOCK, true)
	end
	P.ForEachChatFrame(function(cf)
		local tab = _G[cf:GetName() .. "Tab"]
		if tab and not cf.isDocked and FD(tab).ghost then
			PanelTemplates_TabResize(tab, tab.sizePadding or 0)
		end
	end)
	RequestRefresh()
end

function ECHAT.ApplyTabPadding()
	ECHAT.ApplyExtendedBackground()
	ECHAT.ApplySidebarIcons()
	RequestRefresh()
end

-------------------------------------------------------------------------------
--  Blizzard tab events: selection, dock changes, alerts, renames
-------------------------------------------------------------------------------
for _, fn in ipairs({ "FCFDock_UpdateTabs", "FCFTab_UpdateColors", "FCF_StartAlertFlash", "FCF_StopAlertFlash",
	"FCF_DockFrame", "FCF_UnDockFrame", "FCF_SetWindowName", "FCF_Close", "FCF_SetTabPosition" }) do
	if _G[fn] then
		hooksecurefunc(fn, RequestRefresh)
	end
end
