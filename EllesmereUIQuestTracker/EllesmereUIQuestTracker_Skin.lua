-------------------------------------------------------------------------------
-- EllesmereUIQuestTracker_Skin.lua (5.4.8 port)
--
-- Retail restyles ObjectiveTrackerFrame (fonts, sizes, title / completed /
-- focused colors, header color, accent line under the header, "All
-- Objectives" header). 5.4.8 draws the tracker with the WatchFrame:
--   WatchFrameHeader / WatchFrameTitle   = the master "Objectives" header
--   WatchFrameCollapseExpandButton       = its minimize button
--   WatchFrame_SetLine(line, ...)        = every quest / achievement / scenario line
--   WATCHFRAME_LINKBUTTONS               = one per shown quest / achievement
-- Only hooksecurefunc / HookScript: no SetScript on Blizzard frames, no
-- writes to Blizzard tables or globals (state lives in our weak tables).
-- Retail parts with no 5.4.8 counterpart (section headers, quest type icons,
-- block click areas) are skipped.
-------------------------------------------------------------------------------
local addonName, P = ...
local ns = EllesmereUI
local EQT = P.EQT

local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"

-------------------------------------------------------------------------------
-- Settings readers (fallbacks = retail Get*RGB fallbacks)
-------------------------------------------------------------------------------
local function GetTitleSize()  return EQT.Cfg("titleFontSize")     or 12 end
local function GetObjSize()    return EQT.Cfg("objectiveFontSize") or 10 end
local function GetHeaderSize() return EQT.Cfg("headerFontSize")    or 13 end

local function GetTitleRGB()
	local c = EQT.DB()
	return c.titleR or 1.0, c.titleG or 0.910, c.titleB or 0.471
end
local function GetCompletedRGB()
	local c = EQT.DB()
	return c.completedR or 0.251, c.completedG or 1.0, c.completedB or 0.349
end
local function GetFocusRGB()
	local c = EQT.DB()
	return c.focusR or 0.871, c.focusG or 0.251, c.focusB or 1.0
end

local function GetAccent()
	if ns.ResolveAccent then
		local r, g, b = ns.ResolveAccent()
		if r then return r, g, b end
	end
	return 0.047, 0.824, 0.624
end
EQT.GetAccent = GetAccent

local function GetClassColorRGB()
	local _, class = UnitClass("player")
	local cc = class and ns.GetClassColor and ns.GetClassColor(class)
	if cc and cc.r then return cc.r, cc.g, cc.b end
	return 1.0, 1.0, 1.0
end
EQT.GetClassColorRGB = GetClassColorRGB

-- Header Color / Line Color: Class Color / Custom Color / Accent Color
-- (the UseAccent keys count as true until set to false).
local function GetHeaderRGB()
	local c = EQT.DB()
	if c.headerShowClassColor then return GetClassColorRGB() end
	if c.headerUseAccent ~= false then return GetAccent() end
	return c.headerR or 1.0, c.headerG or 1.0, c.headerB or 1.0
end
local function GetLineRGB()
	local c = EQT.DB()
	if c.lineShowClassColor then return GetClassColorRGB() end
	if c.lineUseAccent ~= false then return GetAccent() end
	return c.lineR or 1.0, c.lineG or 1.0, c.lineB or 1.0
end

-- Font: the module font ("__global" = EllesmereUI font for Quest Tracker).
local function GetFont()
	local key = EQT.Cfg("font")
	if key and key ~= "__global" and ns.ResolveFontName then
		local p = ns.ResolveFontName(key)
		if p then return p end
	end
	return (ns.GetFontPath and ns.GetFontPath("questTracker")) or DEFAULT_FONT
end
local function GetOutline()
	return (ns.GetFontOutlineFlag and ns.GetFontOutlineFlag("questTracker")) or ""
end

local fontSize = setmetatable({}, { __mode = "k" })  -- fs -> size we set
local function StyleFS(fs, size)
	if not fs or not fs.SetFont then return end
	local flags = GetOutline()
	fs:SetFont(GetFont(), size, flags)
	if not fs:GetFont() then fs:SetFont(DEFAULT_FONT, size, flags) end
	if flags == "" then
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 1)
	else
		fs:SetShadowOffset(0, 0)
	end
	fontSize[fs] = size
end

-- Font settings changed: every string we styled takes the new face.
function EQT.RefreshFonts()
	for fs, size in pairs(fontSize) do
		StyleFS(fs, size)
	end
end

-------------------------------------------------------------------------------
-- Lines. Hooked inside WatchFrame_SetLine so the new font is in place before
-- Blizzard checks whether the next quest still fits: the line heights are
-- measured again with the new font (same rules as WatchFrame_SetLine).
-------------------------------------------------------------------------------
local LINE_H = 16  -- WATCHFRAME_LINEHEIGHT

local function FixLineHeight(line, size, fullHeight)
	local text = line.text
	local baseH = WATCHFRAME_LINEHEIGHT or LINE_H
	text:SetHeight(0)
	local h = text:GetHeight() or 0
	if h > baseH then
		if fullHeight then
			line:SetHeight(h + 4)
		else
			-- Two lines, like WATCHFRAME_MULTIPLE_LINEHEIGHT for our size.
			local two = math.ceil(size) * 2 + 5
			line:SetHeight(two)
			text:SetHeight(two)
		end
	else
		line:SetHeight(baseH)
	end
end

local function OnSetLine(line, anchor, verticalOffset, isHeader, text, dash, hasItem, fullHeight)
	if not line or not line.text then return end
	local size = isHeader and GetTitleSize() or GetObjSize()
	StyleFS(line.text, size)
	if line.dash then StyleFS(line.dash, GetObjSize()) end
	FixLineHeight(line, size, fullHeight)
end

-------------------------------------------------------------------------------
-- Colors. After every WatchFrame_Update: each shown link button names the
-- lines of one quest / achievement (startLine = its title).
-------------------------------------------------------------------------------
local function QuestInfo(watchIndex)
	local qIndex = GetQuestIndexForWatch(watchIndex)
	if not qIndex then return nil end
	local _, _, _, _, _, _, _, _, questID = GetQuestLogTitle(qIndex)
	return questID
end

local function TitleRGB(button)
	if button.type == "QUEST" then
		local questID = QuestInfo(button.index)
		local focus = GetSuperTrackedQuestID()
		if questID and focus and focus ~= 0 and questID == focus then
			return GetFocusRGB()
		end
		if button.isComplete then
			return GetCompletedRGB()
		end
	end
	return GetTitleRGB()
end

local function ColorButtonTitle(button)
	local lines = button.lines
	local first = button.startLine
	if not (lines and first) then return end
	local line = lines[first]
	if line and line.text then
		line.text:SetTextColor(TitleRGB(button))
	end
end

local function ColorAllTitles()
	local list = WATCHFRAME_LINKBUTTONS
	if type(list) ~= "table" then return end
	for _, button in pairs(list) do
		if type(button) == "table" and button.IsShown and button:IsShown() then
			ColorButtonTitle(button)
		end
	end
end
EQT.RestyleAll = function()
	EQT.RestyleHeader()
	ColorAllTitles()
end

-- Mouse leaves a quest: Blizzard puts its gold back; ours again.
local function OnHighlight(button, onEnter)
	if onEnter then return end
	if type(button) == "table" then ColorButtonTitle(button) end
end

-------------------------------------------------------------------------------
-- Master header ("Objectives", retail "All Objectives"): font, header color,
-- tinted minimize button and a 1px line under it (Line Color).
-------------------------------------------------------------------------------
local divider
local function EnsureDivider()
	if divider then return divider end
	local wf = _G.WatchFrame
	if not wf then return nil end
	divider = wf:CreateTexture(nil, "OVERLAY")
	divider:SetPoint("TOPLEFT", _G.WatchFrameHeader, "BOTTOMLEFT", 0, -2)
	divider:SetPoint("RIGHT", wf, "RIGHT", -12, 0)
	divider:SetHeight(1)
	return divider
end

function EQT.ShouldHideMasterHeader()
	return EQT.Cfg("hideAllObjectivesHeader") ~= false
end

local function UpdateDivider()
	local tex = EnsureDivider()
	if not tex then return end
	local header = _G.WatchFrameHeader
	local show = EQT.Cfg("skinHeaders") and not EQT.ShouldHideMasterHeader()
		and header and header:IsShown()
	if not show then
		tex:Hide()
		return
	end
	local r, g, b = GetLineRGB()
	tex:SetTexture(r, g, b, 1)
	tex:Show()
end

function EQT.RestyleHeader()
	if not EQT.Cfg("skinHeaders") then
		UpdateDivider()
		return
	end
	local title = _G.WatchFrameTitle
	if title then
		StyleFS(title, GetHeaderSize())
		title:SetTextColor(GetHeaderRGB())
		local header = _G.WatchFrameHeader
		if header and header:IsShown() and title:GetText() then
			header:SetWidth((title:GetWidth() or 0) + 4)
			header:SetHeight(math.max(16, GetHeaderSize() + 3))
		end
	end
	local btn = _G.WatchFrameCollapseExpandButton
	if btn then
		local r, g, b = GetHeaderRGB()
		for _, tex in ipairs({ btn:GetNormalTexture(), btn:GetPushedTexture(), btn:GetDisabledTexture() }) do
			if tex then
				tex:SetDesaturated(true)
				tex:SetVertexColor(r, g, b)
			end
		end
	end
	UpdateDivider()
end

-- Hide All Objectives: the header and its minimize button go (alpha 0, no
-- mouse) and the lines move up into the space the header took.
local linesMoved = false
function EQT.ApplyMasterHeaderVisibility()
	local header = _G.WatchFrameHeader
	local btn = _G.WatchFrameCollapseExpandButton
	local lines = _G.WatchFrameLines
	local wf = _G.WatchFrame
	if not (header and wf) then return end
	local hide = EQT.ShouldHideMasterHeader()
	header:SetAlpha(hide and 0 or 1)
	header:EnableMouse(not hide)
	if btn then
		btn:SetAlpha(hide and 0 or 1)
		btn:EnableMouse(not hide)
	end
	-- WatchFrameLines: TOPLEFT -30 below the WatchFrame top in WatchFrame.xml.
	if lines and (hide or linesMoved) then
		lines:SetPoint("TOPLEFT", wf, "TOPLEFT", 0, hide and -4 or -30)
		linesMoved = hide
	end
	UpdateDivider()
end

-------------------------------------------------------------------------------
-- Entry point
-------------------------------------------------------------------------------
local inited = false
function EQT.InitSkin()
	if inited or not _G.WatchFrame then return end
	inited = true
	hooksecurefunc("WatchFrame_SetLine", OnSetLine)
	hooksecurefunc("WatchFrame_Update", function()
		ColorAllTitles()
		EQT.RestyleHeader()
		if EQT.OnTrackerUpdate then EQT.OnTrackerUpdate() end
	end)
	hooksecurefunc("WatchFrameLinkButtonTemplate_Highlight", OnHighlight)
	-- Expand / collapse change what is shown (and the background size).
	hooksecurefunc("WatchFrame_Collapse", function()
		UpdateDivider()
		if EQT.OnTrackerUpdate then EQT.OnTrackerUpdate() end
	end)
	-- Lines Blizzard already built keep the old font until the next update;
	-- the quest log fires one soon after login.
	EQT.RestyleHeader()
end
