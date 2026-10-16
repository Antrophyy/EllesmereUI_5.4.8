-------------------------------------------------------------------------------
--  EllesmereUIChat.lua  (5.4.8 port of the EllesmereUI Chat, retail 9.3.8)
--
--  The same look, settings keys and texts as retail. Retail draws chat text
--  on its own message frames because of 12.x taint rules; 5.4.8 has none of
--  those, so this port skins Blizzard's chat frames directly:
--    - one dark panel behind each chat window and its input box
--    - sidebar (friends, guild, durability, copy chat, channels, settings,
--      scroll to bottom) beside the main window
--    - input box restyle (height, font, input on top)
--    - outer panel border, inner borders, "Tabs Inside Chat Panel" band
--    - idle fade and the Visibility checklist
--    - Copy Chat and URL copy popups, Unlock Mode mover for the main window
--  Tabs: EllesmereUIChat_Tabs.lua. Message text (timestamps, short channel
--  names, class colored names, URLs, remembered lines, whisper sound):
--  EllesmereUIChat_Text.lua.
--
--  Not in 5.4.8, left out: Blizzard / Classic / WoW Forever styles, M+
--  Portals icon, textured border styles, Chat Bubbles page link, BNet toast
--  mover, Edit Mode store.
-------------------------------------------------------------------------------
local addonName, P = ...
local ns = EllesmereUI

local ECHAT = {}
ns.ECHAT = ECHAT
P.ECHAT = ECHAT
P.ns = ns

local floor, min, max, abs = math.floor, math.min, math.max, math.abs

P.MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"

-- Parking spot for Blizzard chat parts this module replaces.
P.hidden = CreateFrame("Frame")
P.hidden:Hide()

-------------------------------------------------------------------------------
--  Defaults (EllesmereUI 9.3.8 Chat defaults, same keys)
-------------------------------------------------------------------------------
local defaults = {
	profile = {
		chat = {
			enabled = true,
			visibility = "always",
			bgAlpha = 0.65,
			bgR = 0.03,
			bgG = 0.045,
			bgB = 0.05,
			bgTexture = "none",
			timestampFormat = "%I:%M ",
			timestampAll = false,
			font = "__global",
			outlineMode = "__global",
			fontSize = 12,
			tabFont = "__global",
			tabFontSize = 11,
			tabFontColor = { r = 1, g = 1, b = 1, a = 0.65 },
			tabFontColorActive = { r = 1, g = 1, b = 1, a = 1 },
			sidebarVisibility = "always",
			hideBorders = false,
			innerBorderColor = { r = 1, g = 1, b = 1, a = 0.06 },
			innerBorderColorMode = "custom",
			panelBorderBehind = false,
			tabBackgroundTexture = "none",
			activeTabBorder = true,
			tabBorderColorActive = { r = 1, g = 1, b = 1, a = 0.18 },
			extendBgBehindTabs = false,
			panelBorderTexture = "solid",
			panelBorderThickness = "none",
			panelBorderColorMode = "custom",
			panelBorderColor = { r = 1, g = 1, b = 1 },
			panelBorderOpacity = 0.18,
			tabSpacing = 1,
			tabPadding = 0,
			syncTabBorder = true,
			tabBorderTexture = "solid",
			tabBorderThickness = "none",
			tabBorderColorMode = "custom",
			tabBorderColor = { r = 1, g = 1, b = 1 },
			tabBorderOpacity = 0.18,
			tabHeight = 24,
			tabInnerPaddingX = 12,
			scrollButtonOnChat = false,
			tabBackgroundColor = { r = 0.03, g = 0.045, b = 0.05, a = 0.44 },
			tabBackgroundColorActive = { r = 0.03, g = 0.045, b = 0.05, a = 0.65 },
			activeUnderline = true,
			activeUnderlineColorMode = "accent",
			activeUnderlineColor = { r = 0.05, g = 0.82, b = 0.61, a = 1 },
			showFriends = true,
			showGuild = false,
			showDurability = false,
			showCopy = true,
			showVoice = false,
			showSettings = true,
			showScroll = true,
			hideTooltipOnHover = true,
			sidebarRight = false,
			sidebarSeparate = false,
			sidebarSeparateSpacing = 8,
			iconR = 1,
			iconG = 1,
			iconB = 1,
			iconUseAccent = false,
			idleFadeDelay = 15,
			idleFadeStrength = 40,
			idleFadeEnabled = true,
			inputOnTop = false,
			lockChatSize = false,
			abbreviateChannels = true,
			abbreviateChannelLetters = false,
			classColorNames = true,
			hideSidebarBg = false,
			sidebarIconScale = 1.0,
			sidebarIconSpacing = 10,
			freeMoveIcons = false,
			iconPositions = {},
			sidebarIconOrder = {
				showCopy = 1,
				showVoice = 3,
				showSettings = 4,
			},
			persistChatHistory = true,
			persistChatHistoryMaxLines = 100,
		},
	},
}
ECHAT.defaults = defaults

-------------------------------------------------------------------------------
--  First run: the retail EllesmereUI "Naowh" profile (EllesmereUIDB.profiles.
--  Naowh.addons.EllesmereUIChat.chat; retail keeps only the values that differ
--  from the defaults). Retail-only keys (chat position, toast position, tab
--  offset, M+ portals) are left out.
-------------------------------------------------------------------------------
local NAOWH_SEED = {
	sidebarIconScale = 0.5,
	lockChatSize = true,
	chatFontSize = 18,
	panelBorderOpacity = 0,
	bgR = 0,
	bgG = 0,
	bgB = 0,
	bgAlpha = 0,
	hideSidebarBg = true,
	idleFadeDelay = 30,
	panelBorderColor = { r = 0, g = 0, b = 0 },
	sidebarIconOrder = { showFriends = 1, showDurability = 3, showCopy = 4, showVoice = 5, showSettings = 6 },
	showFriends = false,
	hideBorders = true,
	sidebarWidth = 30,
	editBoxFontSize = 16,
	innerBorderColor = { r = 0, g = 0, b = 0, a = 1 },
	whisperSoundKey = "none",
	sidebarVisibility = "never",
	tabSpacing = 10,
	idleFadeStrength = 100,
	showScroll = false,
	showSettings = false,
	tabBackgroundColorActive = { a = 0 },
	showCopy = false,
	tabBackgroundColor = { a = 0 },
	tabFontSize = 14,
	tabInnerPaddingX = 0,
	tabFontColor = { a = 1 },
	outlineMode = "outline",
	editBoxHeight = 23,
	sidebarIconSpacing = 6,
}
ECHAT.NAOWH_SEED = NAOWH_SEED

-------------------------------------------------------------------------------
--  Saved settings: EllesmereUIChatDB.profile.chat (the retail profile shape)
-------------------------------------------------------------------------------
local function DeepCopy(v)
	if type(v) ~= "table" then
		return v
	end
	local t = {}
	for k, x in pairs(v) do
		t[k] = DeepCopy(x)
	end
	return t
end
P.DeepCopy = DeepCopy

local function NewProfile(seed)
	local profile = { chat = {} }
	if seed then
		for k, v in pairs(seed) do
			profile.chat[k] = DeepCopy(v)
		end
		profile.seeded = "Naowh"
	end
	ns.CopyDefaults(defaults.profile, profile)
	return profile
end

function ECHAT.InitDB()
	if type(EllesmereUIChatDB) ~= "table" then
		EllesmereUIChatDB = {}
	end
	local sv = EllesmereUIChatDB
	if type(sv.profile) ~= "table" then
		sv.profile = NewProfile(NAOWH_SEED)
	else
		ns.CopyDefaults(defaults.profile, sv.profile)
	end
	sv.version = 1
	ECHAT.db = {
		sv = sv,
		profile = sv.profile,
		ResetProfile = function(db)
			db.sv.profile = NewProfile(nil)
			db.profile = db.sv.profile
		end,
	}
end

local FALLBACK_CFG = { enabled = true, visibility = "always" }
function ECHAT.DB()
	local db = ECHAT.db
	return (db and db.profile and db.profile.chat) or FALLBACK_CFG
end
local DB = ECHAT.DB
P.DB = DB

-------------------------------------------------------------------------------
--  Timers (5.4.8 has no C_Timer): After, NewTimer (handle with :Cancel())
-------------------------------------------------------------------------------
do
	local tasks = {}
	local driver = CreateFrame("Frame")
	driver:Hide()
	local handle = {}
	handle.__index = handle
	handle.Cancel = function(self)
		self.cancelled = true
	end
	driver:SetScript("OnUpdate", function(self)
		local now = GetTime()
		local i = 1
		while i <= #tasks do
			local t = tasks[i]
			if t.cancelled then
				table.remove(tasks, i)
			elseif now >= t.at then
				if t.interval then
					t.at = now + t.interval
					i = i + 1
				else
					table.remove(tasks, i)
				end
				local ok, err = pcall(t.fn, t)
				if not ok then
					geterrorhandler()(err)
				end
			else
				i = i + 1
			end
		end
		if #tasks == 0 then
			self:Hide()
		end
	end)
	local function Add(t)
		setmetatable(t, handle)
		tasks[#tasks + 1] = t
		driver:Show()
		return t
	end
	function P.After(delay, fn)
		Add({ at = GetTime() + (delay or 0), fn = fn })
	end
	function P.NewTimer(delay, fn)
		return Add({ at = GetTime() + (delay or 0), fn = fn })
	end
	function P.NewTicker(interval, fn)
		return Add({ at = GetTime() + interval, interval = interval, fn = fn })
	end
end

-------------------------------------------------------------------------------
--  Pixels and edge borders
-------------------------------------------------------------------------------
function P.PixelFor(frame)
	local h = ns.PhysicalHeight and ns.PhysicalHeight() or 1080
	local scale = (frame and frame.GetEffectiveScale and frame:GetEffectiveScale()) or UIParent:GetEffectiveScale()
	return 768 / h / scale
end

-- Four edge textures on `parent`, laid around `host` (a frame or a texture).
function P.CreateEdges(parent, host, layer, sub)
	local e = { host = host or parent }
	for i = 1, 4 do
		e[i] = parent:CreateTexture(nil, layer or "OVERLAY", nil, sub or 2)
		e[i]:SetTexture(1, 1, 1, 1)
	end
	return e
end

-- size in the host's units; outside = drawn around the host, else inside it.
function P.LayoutEdges(e, size, r, g, b, a, outside)
	local host = e.host
	if not size or size <= 0 then
		for i = 1, 4 do
			e[i]:Hide()
		end
		e.size = 0
		return
	end
	e.size = size
	local o = outside and -size or 0
	e[1]:ClearAllPoints()
	e[1]:SetPoint("TOPLEFT", host, "TOPLEFT", o, -o)
	e[1]:SetPoint("TOPRIGHT", host, "TOPRIGHT", -o, -o)
	e[1]:SetHeight(size)
	e[2]:ClearAllPoints()
	e[2]:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", o, o)
	e[2]:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -o, o)
	e[2]:SetHeight(size)
	e[3]:ClearAllPoints()
	e[3]:SetPoint("TOPLEFT", e[1], "BOTTOMLEFT")
	e[3]:SetPoint("BOTTOMLEFT", e[2], "TOPLEFT")
	e[3]:SetWidth(size)
	e[4]:ClearAllPoints()
	e[4]:SetPoint("TOPRIGHT", e[1], "BOTTOMRIGHT")
	e[4]:SetPoint("BOTTOMRIGHT", e[2], "TOPRIGHT")
	e[4]:SetWidth(size)
	for i = 1, 4 do
		e[i]:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
		e[i]:Show()
	end
end

function P.ShowEdges(e, shown)
	if not e then
		return
	end
	for i = 1, 4 do
		if shown and (e.size or 0) > 0 then
			e[i]:Show()
		else
			e[i]:Hide()
		end
	end
end

-------------------------------------------------------------------------------
--  Accent and class color
-------------------------------------------------------------------------------
local DEFAULT_ACCENT = { 12 / 255, 210 / 255, 157 / 255 }

function P.Accent()
	if ns.ResolveAccent then
		local r, g, b = ns.ResolveAccent()
		if r then
			return r, g, b
		end
	end
	return DEFAULT_ACCENT[1], DEFAULT_ACCENT[2], DEFAULT_ACCENT[3]
end
ECHAT.AccentColor = function()
	local r, g, b = P.Accent()
	return r, g, b, 1
end

local accentCallbacks = {}
function P.OnAccent(fn)
	accentCallbacks[#accentCallbacks + 1] = fn
end
if ns.accentListeners then
	tinsert(ns.accentListeners, function(r, g, b)
		for i = 1, #accentCallbacks do
			accentCallbacks[i](r, g, b)
		end
	end)
end

function P.ClassColor()
	if ns.GetPlayerClassColor then
		local r, g, b = ns.GetPlayerClassColor()
		if r then
			return r, g, b
		end
	end
	local _, class = UnitClass("player")
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then
		return c.r, c.g, c.b
	end
	return 1, 1, 1
end
ECHAT.ClassColor = function()
	local r, g, b = P.ClassColor()
	return r, g, b, 1
end

function P.Hex(r, g, b)
	return format("%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

-- A color table under a custom / accent / class mode (retail ResolveModeColor).
function P.ModeColor(mode, stored, fallback)
	if mode == "accent" then
		local r, g, b = P.Accent()
		return r, g, b, (stored and stored.a) or fallback.a or 1
	elseif mode == "class" then
		local r, g, b = P.ClassColor()
		return r, g, b, (stored and stored.a) or fallback.a or 1
	end
	local c = stored or fallback
	local a = c.a
	if a == nil then
		a = fallback.a
	end
	if a == nil then
		a = 1
	end
	return c.r or fallback.r or 1, c.g or fallback.g or 1, c.b or fallback.b or 1, a
end

-------------------------------------------------------------------------------
--  Fonts (Global Settings > Fonts, module key "chat"; the Chat page's own
--  Font / Outline Mode pickers override it)
-------------------------------------------------------------------------------
local function ModuleFont()
	return (ns.GetFontPath and ns.GetFontPath("chat")) or ns.FONT or STANDARD_TEXT_FONT
end

function P.ResolveFont(key)
	if not key or key == "__global" then
		return ModuleFont()
	end
	return (ns.ResolveFontName and ns.ResolveFontName(key)) or ModuleFont()
end

function ECHAT.GetFont()
	return P.ResolveFont(DB().font)
end

function ECHAT.GetOutlineFlag()
	local mode = DB().outlineMode or "__global"
	if mode == "__global" then
		return (ns.GetFontOutlineFlag and ns.GetFontOutlineFlag("chat")) or ""
	elseif mode == "outline" then
		return "OUTLINE"
	elseif mode == "thick" then
		return "THICKOUTLINE"
	end
	return ""
end

-- Sets a font; a broken font file falls back to Arial Narrow (5.4.8 errors on
-- SetText without a font).
function P.SetFont(obj, path, size, flags)
	obj:SetFont(path or ModuleFont(), size, flags or "")
	if not obj:GetFont() then
		obj:SetFont("Fonts\\ARIALN.TTF", size, flags or "")
	end
end

function P.NewText(parent, layer, size)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	P.SetFont(fs, ECHAT.GetFont(), size or 10, "")
	return fs
end

-- Chat text size is Blizzard's per-window setting (tab menu > Font Size).
local function GetFrameFontSize(id)
	if FCF_GetChatWindowInfo and id then
		local _, fontSize = FCF_GetChatWindowInfo(id)
		if fontSize and fontSize > 0 then
			return fontSize
		end
	end
	return 12
end
P.GetFrameFontSize = GetFrameFontSize

local function GetEditBoxHeight()
	return min(60, max(10, DB().editBoxHeight or 23))
end
P.GetEditBoxHeight = GetEditBoxHeight

local function GetEditBoxFont()
	local key = DB().editBoxFont
	if not key or key == "__chat" then
		return ECHAT.GetFont()
	end
	return P.ResolveFont(key)
end

local function GetEditBoxFontSize(id)
	return DB().editBoxFontSize or GetFrameFontSize(id)
end

-------------------------------------------------------------------------------
--  Layout readers (retail ExtendBgBehindTabs / InputOnTop / BordersHidden)
-------------------------------------------------------------------------------
function ECHAT.ExtendBgBehindTabs(cfg)
	return (cfg or DB()).extendBgBehindTabs == true
end
function ECHAT.InputOnTop(cfg)
	return (cfg or DB()).inputOnTop and true or false
end
function ECHAT.BordersHidden(cfg)
	return (cfg or DB()).hideBorders and true or false
end

function P.TabHeight()
	return DB().tabHeight or 24
end
-- Tab band height (the tab strip behind the tabs when Tabs Inside Chat Panel).
function P.TabAreaHeight()
	local cfg = DB()
	local pad = ECHAT.ExtendBgBehindTabs(cfg) and 0 or (cfg.tabPadding or 0)
	return P.TabHeight() + pad
end

local BG_R, BG_G, BG_B, BG_A = 0.03, 0.045, 0.05, 0.65
function P.BgColor()
	return BG_R, BG_G, BG_B, BG_A
end

function P.InnerBorderColor(cfg)
	cfg = cfg or DB()
	local c = cfg.innerBorderColor
	if cfg.innerBorderColorMode == "accent" then
		local r, g, b = P.Accent()
		return r, g, b, (c and c.a) or 0.06
	end
	c = c or { r = 1, g = 1, b = 1, a = 0.06 }
	return c.r or 1, c.g or 1, c.b or 1, c.a == nil and 0.06 or c.a
end

local BORDER_STEPS = { none = 0, thin = 1, normal = 2, heavy = 3, strong = 4 }
P.BORDER_STEPS = BORDER_STEPS
P.BORDER_LABELS = { [0] = "none", "thin", "normal", "heavy", "strong" }
-- Border Size slider (0-4) <-> the saved thickness label.
function ECHAT.BORDER_STEP(label)
	return BORDER_STEPS[label or "none"] or 0
end
function ECHAT.BORDER_LABEL(step)
	return P.BORDER_LABELS[floor((step or 0) + 0.5)] or "none"
end
-- The custom inner border color (the swatch shows it in any mode).
function ECHAT.InnerBorderColorCustom()
	local c = DB().innerBorderColor or {}
	return c.r or 1, c.g or 1, c.b or 1, c.a == nil and 0.06 or c.a
end

-- Panel border color and alpha (custom / accent / class).
function P.PanelBorderColor(cfg, prefix)
	cfg = cfg or DB()
	prefix = prefix or "panelBorder"
	local mode = cfg[prefix .. "ColorMode"] or "custom"
	local r, g, b
	if mode == "accent" then
		r, g, b = P.Accent()
	elseif mode == "class" then
		r, g, b = P.ClassColor()
	else
		local c = cfg[prefix .. "Color"] or { r = 1, g = 1, b = 1 }
		r, g, b = c.r or 1, c.g or 1, c.b or 1
	end
	local a = cfg[prefix .. "Opacity"]
	if a == nil then
		a = (mode == "custom") and 0.18 or 0.5
	end
	return r, g, b, a
end

-------------------------------------------------------------------------------
--  Background texture (Background Texture / Tab Texture: a bar texture path
--  from Global Settings media, "none" = flat color)
-------------------------------------------------------------------------------
function P.TexturePath(key)
	if not key or key == "" or key == "none" then
		return nil
	end
	return key
end

function P.PaintFill(tex, path, r, g, b, a)
	if path then
		tex:SetTexture(path)
		tex:SetVertexColor(r, g, b, a)
	else
		tex:SetTexture(r, g, b, a)
		tex:SetVertexColor(1, 1, 1, 1)
	end
end

-------------------------------------------------------------------------------
--  EllesmereUI widget tooltip (dark box, 1 px border, white text)
-------------------------------------------------------------------------------
local tip, tipMeasure
function P.ShowTip(owner, text, side)
	if not owner or not text or text == "" then
		return
	end
	if not tip then
		tip = CreateFrame("Frame", nil, UIParent)
		tip:SetFrameStrata("TOOLTIP")
		tip:SetFrameLevel(250)
		tip:SetClampedToScreen(true)
		local bg = tip:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetTexture(0.067, 0.067, 0.067, 0.94)
		local e = P.CreateEdges(tip, tip, "BORDER", 0)
		P.LayoutEdges(e, P.PixelFor(tip), 1, 1, 1, 0.15)
		tip.text = tip:CreateFontString(nil, "OVERLAY")
		tip.text:SetPoint("TOPLEFT", 9, -7)
		tip.text:SetJustifyH("LEFT")
		tipMeasure = tip:CreateFontString(nil, "OVERLAY")
		tipMeasure:Hide()
	end
	P.SetFont(tip.text, ModuleFont(), 12, "")
	P.SetFont(tipMeasure, ModuleFont(), 12, "")
	tip.text:SetTextColor(1, 1, 1, 0.85)
	tip.text:SetText(text)
	tipMeasure:SetText(text)
	local w = tipMeasure:GetStringWidth() or 40
	tip.text:SetWidth(w + 2)
	tip:SetSize(w + 20, (tip.text:GetStringHeight() or 12) + 14)
	tip:ClearAllPoints()
	if side == "left" then
		tip:SetPoint("RIGHT", owner, "LEFT", -4, 0)
	elseif side == "right" then
		tip:SetPoint("LEFT", owner, "RIGHT", 4, 0)
	else
		tip:SetPoint("BOTTOM", owner, "TOP", 0, 4)
	end
	tip:Show()
end

function P.HideTip()
	if tip then
		tip:Hide()
	end
end

-------------------------------------------------------------------------------
--  Visibility checklist (retail BuildVisibilityRow on the "visibility" key,
--  no Mouseover for chat): Never / Always base, Match All / Any, Show / Hide
--  lanes. Same lane keys as the Minimap and Action Bars ports.
-------------------------------------------------------------------------------
local function InCombat()
	return (InCombatLockdown() or UnitAffectingCombat("player")) and true or false
end

ECHAT.VIS_AXES = {
	{ key = "in_combat", label = "In Combat", show = "in_combat", hide = "hide_in_combat", test = InCombat },
	{ key = "out_of_combat", label = "Out of Combat", show = "out_of_combat", hide = "hide_out_of_combat",
		test = function() return not InCombat() end },
	{ key = "in_raid", label = "In Raid Group", show = "in_raid", hide = "hide_in_raid",
		test = function() return IsInRaid() and true or false end },
	{ key = "in_party", label = "In Party", show = "in_party", hide = "hide_in_party",
		test = function() return (IsInGroup() and not IsInRaid()) and true or false end },
	{ key = "solo", label = "Solo", show = "solo", hide = "hide_solo",
		test = function() return not IsInGroup() end },
	{ key = "instances", label = "Instances", show = "visOnlyInstances", hide = "visHideInstances",
		test = function() local inside = IsInInstance() return inside and true or false end },
	{ key = "mounted", label = "Mounted", show = "visOnlyMounted", hide = "visHideMounted",
		test = function() return IsMounted() and true or false end },
	{ key = "target", label = "Target", show = "visHideNoTarget", hide = "visHideWithTarget",
		test = function() return UnitExists("target") and true or false end },
	{ key = "enemy", label = "Enemy Target", show = "visHideNoEnemy", hide = "visHideWithEnemy",
		test = function() return (UnitExists("target") and UnitCanAttack("player", "target")) and true or false end },
	{ key = "resting", label = "Resting", show = "visOnlyResting", hide = "visHideResting",
		test = function() return IsResting() and true or false end },
}

function ECHAT.VisFlag(s, key)
	if key:match("^vis") then
		return s[key] and true or false
	end
	local modes = s.visibilityModes
	if modes and modes[key] then
		return true
	end
	local vis = s.visibility
	if vis and vis ~= "always" and vis ~= "never" and vis ~= "mouseover" and vis == key then
		return true
	end
	return false
end

function ECHAT.SetVisFlag(s, key, on)
	if key:match("^vis") then
		s[key] = on and true or nil
		return
	end
	s.visibilityModes = s.visibilityModes or {}
	s.visibilityModes[key] = on and true or nil
end

function ECHAT.VisBase(s)
	return (s and s.visibility == "never") and "never" or "always"
end

function ECHAT.SetVisBase(s, mode)
	local old = s.visibility
	if old and old ~= "always" and old ~= "never" and old ~= "mouseover" then
		ECHAT.SetVisFlag(s, old, true)
	end
	s.visibility = mode
end

function ECHAT.EvalVisibility(s)
	if ECHAT.VisBase(s) == "never" then
		return false
	end
	local anyShow, allOk, anyOk = false, true, false
	for _, axis in ipairs(ECHAT.VIS_AXES) do
		local hideOn = ECHAT.VisFlag(s, axis.hide)
		local showOn = ECHAT.VisFlag(s, axis.show)
		if hideOn or showOn then
			local now = axis.test()
			if hideOn and now then
				return false
			end
			if showOn then
				anyShow = true
				if now then
					anyOk = true
				else
					allOk = false
				end
			end
		end
	end
	if anyShow then
		if s.visibilityMatch == "any" then
			if not anyOk then
				return false
			end
		elseif not allOk then
			return false
		end
	end
	return true
end

-------------------------------------------------------------------------------
--  Per chat frame data (kept off Blizzard's tables)
-------------------------------------------------------------------------------
local frameData = {}
local function FD(obj)
	local d = frameData[obj]
	if not d then
		d = {}
		frameData[obj] = d
	end
	return d
end
P.FD = FD

-- Every chat frame Blizzard has made (permanent 1-10 and whisper windows).
function P.ForEachChatFrame(fn)
	for _, name in ipairs(CHAT_FRAMES or {}) do
		local cf = _G[name]
		if cf then
			fn(cf)
		end
	end
end

function P.SelectedWindow()
	if GENERAL_CHAT_DOCK and FCFDock_GetSelectedWindow then
		return FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK) or ChatFrame1
	end
	return SELECTED_CHAT_FRAME or ChatFrame1
end

-------------------------------------------------------------------------------
--  Fonts on the chat frames and input boxes
-------------------------------------------------------------------------------
local function ApplyFrameFont(cf)
	local font, outline = ECHAT.GetFont(), ECHAT.GetOutlineFlag()
	P.SetFont(cf, font, GetFrameFontSize(cf:GetID()), outline)
	if outline == "" then
		cf:SetShadowOffset(1, -1)
		cf:SetShadowColor(0, 0, 0, 0.8)
	else
		cf:SetShadowOffset(0, 0)
	end
end

local function ApplyEditBoxFont(eb, id)
	if not eb then
		return
	end
	local font, size, outline = GetEditBoxFont(), GetEditBoxFontSize(id), ECHAT.GetOutlineFlag()
	P.SetFont(eb, font, size, outline)
	local name = eb:GetName()
	local header = name and _G[name .. "Header"]
	local suffix = name and _G[name .. "HeaderSuffix"]
	if header then
		P.SetFont(header, font, size, outline)
	end
	if suffix then
		P.SetFont(suffix, font, size, outline)
	end
end

function ECHAT.ApplyFonts()
	P.ForEachChatFrame(function(cf)
		if FD(cf).skinned then
			ApplyFrameFont(cf)
			ApplyEditBoxFont(_G[cf:GetName() .. "EditBox"], cf:GetID())
		end
	end)
	if ECHAT.ApplySidebarIconScale then
		ECHAT.ApplySidebarIconScale()
	end
	if ECHAT.ApplyTabLayout then
		ECHAT.ApplyTabLayout()
	end
end

-- One size for every chat window (the options slider), saved in Blizzard's
-- per-window storage and mirrored into the profile (chatFontSize).
function ECHAT.ApplyChatFontSize(size)
	if type(size) ~= "number" or size <= 0 then
		return
	end
	for i = 1, NUM_CHAT_WINDOWS or 10 do
		if _G["ChatFrame" .. i] and SetChatWindowSize then
			SetChatWindowSize(i, size)
		end
	end
	P.ForEachChatFrame(function(cf)
		local font, _, flags = cf:GetFont()
		if font then
			cf:SetFont(font, size, flags or "")
		end
	end)
	ECHAT.ApplyFonts()
end

-- First sight captures the live size; later logins re-apply the profile's.
function ECHAT.SyncChatFontSize()
	local cfg = DB()
	if cfg.chatFontSize == nil then
		local fh = GetFrameFontSize(1)
		if type(fh) == "number" and fh > 0 then
			cfg.chatFontSize = floor(fh + 0.5)
		end
		return
	end
	ECHAT.ApplyChatFontSize(cfg.chatFontSize)
end

-------------------------------------------------------------------------------
--  Chat frame skin
-------------------------------------------------------------------------------
local function HideRegionsOf(frame)
	if not frame or not frame.GetRegions then
		return
	end
	for _, r in ipairs({ frame:GetRegions() }) do
		if r.GetObjectType and r:GetObjectType() == "Texture" then
			r:SetTexture(nil)
			r:SetAlpha(0)
		end
	end
end
P.HideRegionsOf = HideRegionsOf

local function SkinResizeButton(cf)
	local rb = cf.resizeButton or _G[cf:GetName() .. "ResizeButton"]
	if not rb or FD(rb).skinned then
		return
	end
	FD(rb).skinned = true
	rb:SetSize(18, 18)
	rb:ClearAllPoints()
	rb:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", -2, 2)
	rb:SetFrameStrata("HIGH")
	local tex = P.MEDIA .. "resize_element"
	rb:SetNormalTexture(tex)
	rb:SetHighlightTexture(tex)
	rb:SetPushedTexture(tex)
	for _, t in ipairs({ rb:GetNormalTexture(), rb:GetHighlightTexture(), rb:GetPushedTexture() }) do
		t:SetDesaturated(true)
		t:SetVertexColor(1, 1, 1)
		t:ClearAllPoints()
		t:SetAllPoints()
	end
	rb:SetAlpha(0.4)
	rb:HookScript("OnEnter", function(self) self:SetAlpha(0.75) end)
	rb:HookScript("OnLeave", function(self) self:SetAlpha(0.4) end)
	-- Lock Main Chat Size: the main window's grip stays hidden.
	rb:HookScript("OnShow", function(self)
		if P.started and cf == ChatFrame1 and DB().lockChatSize then
			self:Hide()
		end
	end)
end

-- Up / Down recall without Alt (EllesmereUI; the 5.4.8 alt-arrow switch is
-- unreliable, so the history is kept here, like Prat and ElvUI do).
local function OnArrowPressed(eb, key)
	local d = FD(eb)
	local h = d.history
	if not h or #h == 0 then
		return
	end
	if key == "UP" then
		d.histIdx = min(#h, (d.histIdx or 0) + 1)
	elseif key == "DOWN" then
		d.histIdx = max(0, (d.histIdx or 0) - 1)
	else
		return
	end
	if d.histIdx == 0 then
		eb:SetText("")
	else
		eb:SetText(h[#h - d.histIdx + 1] or "")
	end
end

local function SkinEditBox(cf)
	local name = cf:GetName()
	local eb = name and _G[name .. "EditBox"]
	if not eb or FD(eb).skinned then
		return
	end
	local d = FD(eb)
	d.skinned = true
	for _, suffix in ipairs({ "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" }) do
		local t = _G[name .. "EditBox" .. suffix]
		if t then
			t:SetTexture(nil)
			t:SetAlpha(0)
		end
	end
	eb:SetTextInsets(8, 8, 0, 0)
	-- Input on Top covers the newest lines: its own fill hides them.
	d.fill = eb:CreateTexture(nil, "BACKGROUND", nil, -8)
	d.fill:SetAllPoints()
	d.fill:Hide()
	ApplyEditBoxFont(eb, cf:GetID())

	d.history = {}
	d.histIdx = 0
	eb:SetAltArrowKeyMode(false)
	eb:HookScript("OnArrowPressed", OnArrowPressed)
	hooksecurefunc(eb, "AddHistoryLine", function(self, text)
		if type(text) ~= "string" or text == "" then
			return
		end
		local h = FD(self).history
		if h[#h] ~= text then
			h[#h + 1] = text
			if #h > 50 then
				table.remove(h, 1)
			end
		end
	end)
	eb:HookScript("OnEditFocusLost", function(self)
		FD(self).histIdx = 0
	end)
	-- Typing and focus count as chat activity (idle fade).
	eb:HookScript("OnEditFocusGained", function()
		if ECHAT.OnEditFocus then ECHAT.OnEditFocus(true) end
	end)
	eb:HookScript("OnEditFocusLost", function()
		if ECHAT.OnEditFocus then ECHAT.OnEditFocus(false) end
	end)
	eb:HookScript("OnChar", function()
		if ECHAT.OnActiveMessage then ECHAT.OnActiveMessage() end
	end)
end

-- Header ("Say:", "Party:") and its suffix: our font, 8 px from the box edge.
local function OnUpdateHeader(eb)
	if not P.started or not eb or not FD(eb).skinned then
		return
	end
	local name = eb:GetName()
	local header = _G[name .. "Header"]
	local suffix = _G[name .. "HeaderSuffix"]
	if not header then
		return
	end
	local cf = eb.chatFrame or eb:GetParent()
	ApplyEditBoxFont(eb, cf and cf.GetID and cf:GetID())
	header:ClearAllPoints()
	header:SetPoint("LEFT", eb, "LEFT", 8, 0)
	local w = header:GetWidth() or 0
	if suffix and suffix:IsShown() then
		w = w + (suffix:GetWidth() or 0)
	end
	eb:SetTextInsets(8 + w, 8, 0, 0)
end

-- Combat log filter bar: one dark bar matching the panel, accent on the
-- active filter.
local function SkinCombatLogBar()
	local qbf = _G.CombatLogQuickButtonFrame_Custom
	local cf = _G.ChatFrame2
	if not qbf or not cf or FD(qbf).skinned then
		return
	end
	local d = FD(qbf)
	d.skinned = true
	local tex = _G.CombatLogQuickButtonFrame_CustomTexture
	if tex then
		tex:SetTexture(nil)
		tex:SetAlpha(0)
	end
	d.bg = qbf:CreateTexture(nil, "BACKGROUND", nil, -8)
	d.bg:SetAllPoints()
	d.div = qbf:CreateTexture(nil, "OVERLAY", nil, 7)
	d.div:SetTexture(1, 1, 1, 0.06)
	d.div:SetPoint("BOTTOMLEFT")
	d.div:SetPoint("BOTTOMRIGHT")
	d.div:SetHeight(P.PixelFor(qbf))
	d.buttons = {}
	local function Recolor()
		for _, btn in ipairs(d.buttons) do
			local fs = btn:GetFontString()
			if fs then
				if btn.GetChecked and btn:GetChecked() then
					local r, g, b = P.Accent()
					fs:SetTextColor(r, g, b, 1)
				else
					fs:SetTextColor(1, 1, 1, 0.5)
				end
			end
		end
	end
	d.Recolor = Recolor
	local function SkinButtons()
		for _, btn in ipairs({ qbf:GetChildren() }) do
			-- Filter buttons only (they have a label); the settings arrow keeps its art.
			local label = btn.GetFontString and btn:GetFontString()
			local hasText = label and label:GetText() and label:GetText() ~= ""
			if hasText and not FD(btn).skinned and btn:GetObjectType() ~= "StatusBar" then
				FD(btn).skinned = true
				d.buttons[#d.buttons + 1] = btn
				HideRegionsOf(btn)
				local fs = btn:GetFontString()
				if fs then
					P.SetFont(fs, ECHAT.GetFont(), 12, "")
				end
				btn:HookScript("OnClick", function() P.After(0, Recolor) end)
			end
		end
		Recolor()
	end
	d.SkinButtons = SkinButtons
	SkinButtons()
	if Blizzard_CombatLog_Update_QuickButtons then
		hooksecurefunc("Blizzard_CombatLog_Update_QuickButtons", function()
			SkinButtons()
		end)
	end
	P.OnAccent(Recolor)
	ECHAT.ApplyCombatLogBar()
end

function ECHAT.ApplyCombatLogBar()
	local qbf = _G.CombatLogQuickButtonFrame_Custom
	local cf = _G.ChatFrame2
	if not qbf or not cf or not FD(qbf).skinned then
		return
	end
	local d = FD(qbf)
	qbf:ClearAllPoints()
	-- Flush: the bar's bottom meets the panel top (chat frame top + 3).
	qbf:SetPoint("BOTTOMLEFT", cf, "TOPLEFT", -10, 3)
	qbf:SetPoint("BOTTOMRIGHT", cf, "TOPRIGHT", 10, 3)
	local path = P.TexturePath(DB().bgTexture)
	P.PaintFill(d.bg, path, BG_R, BG_G, BG_B, BG_A)
end

local function SkinChatFrame(cf)
	local d = FD(cf)
	if d.skinned then
		return
	end
	d.skinned = true
	local name = cf:GetName()

	-- Blizzard's frame art: emptied (its hover fade and window color keep
	-- writing to textures that draw nothing).
	for _, key in ipairs(CHAT_FRAME_TEXTURES or {}) do
		local t = _G[name .. key]
		if t and t.SetTexture then
			t:SetTexture(nil)
		end
	end

	-- Unified dark panel behind the text and the input box: our textures on
	-- the chat frame itself (they show, hide and fade with it).
	d.bg = cf:CreateTexture(nil, "BACKGROUND", nil, -8)
	d.edges = P.CreateEdges(cf, d.bg, "BORDER", 1)
	d.inputDiv = cf:CreateTexture(nil, "BORDER", nil, 2)
	d.inputDiv:SetTexture(1, 1, 1, 1)

	-- Button frame (scroll arrows, minimize): parked; the sidebar has
	-- Scroll to Bottom and the mouse wheel scrolls.
	local bf = _G[name .. "ButtonFrame"]
	if bf then
		bf:SetParent(P.hidden)
	end

	SkinResizeButton(cf)
	SkinEditBox(cf)
	ApplyFrameFont(cf)
	cf:SetFading(false)
	cf:SetClampedToScreen(true)

	-- Mouse wheel scrolls (retail turns chatMouseScroll on).
	cf:SetScript("OnMouseWheel", FloatingChatFrame_OnMouseScroll)
	cf:EnableMouseWheel(true)

	if ECHAT.HookChatFrameText then
		ECHAT.HookChatFrameText(cf)
	end
	if ECHAT.SkinTab then
		ECHAT.SkinTab(cf)
	end
end
P.SkinChatFrame = SkinChatFrame

-------------------------------------------------------------------------------
--  Panel geometry and paint
-------------------------------------------------------------------------------
local INPUT_TOP_DROP = 5

-- Panel insets around the chat frame: l, r, t, b.
function P.PanelInsets(cf)
	local cfg = DB()
	local h = GetEditBoxHeight()
	local b = ECHAT.InputOnTop(cfg) and -6 or -(12 + h)
	return -10, 10, 3, b
end

function ECHAT.ApplyInputPosition()
	local cfg = DB()
	local onTop = ECHAT.InputOnTop(cfg)
	local h = GetEditBoxHeight()
	P.ForEachChatFrame(function(cf)
		local d = FD(cf)
		if not d.skinned then
			return
		end
		local eb = _G[cf:GetName() .. "EditBox"]
		if eb then
			eb:ClearAllPoints()
			if onTop then
				eb:SetPoint("TOPLEFT", cf, "TOPLEFT", -10, -INPUT_TOP_DROP)
				eb:SetPoint("TOPRIGHT", cf, "TOPRIGHT", 5, -INPUT_TOP_DROP)
			else
				eb:SetPoint("TOPLEFT", cf, "BOTTOMLEFT", -10, -8)
				eb:SetPoint("TOPRIGHT", cf, "BOTTOMRIGHT", 5, -8)
			end
			eb:SetHeight(h)
			local ed = FD(eb)
			if ed.fill then
				ed.fill:SetTexture(BG_R, BG_G, BG_B, max(BG_A, 0.9))
				ed.fill:SetShown(onTop)
			end
		end
		local l, r, t, b = P.PanelInsets(cf)
		d.bg:ClearAllPoints()
		d.bg:SetPoint("TOPLEFT", cf, "TOPLEFT", l, t)
		d.bg:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", r, b)
		d.inputDiv:ClearAllPoints()
		if onTop then
			local y = -(h + INPUT_TOP_DROP)
			d.inputDiv:SetPoint("TOPLEFT", cf, "TOPLEFT", -10, y)
			d.inputDiv:SetPoint("TOPRIGHT", cf, "TOPRIGHT", 10, y)
		else
			d.inputDiv:SetPoint("BOTTOMLEFT", cf, "BOTTOMLEFT", -10, -8)
			d.inputDiv:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", 10, -8)
		end
		d.inputDiv:SetHeight(P.PixelFor(cf))
		-- Clamp the whole panel (tabs above, input below) to the screen.
		local left = l
		if cf == ChatFrame1 and FD(cf).sidebar and (cfg.sidebarVisibility or "always") ~= "never" and not cfg.sidebarRight then
			left = left - (FD(cf).sidebar:GetWidth() or 0) - ((cfg.sidebarSeparate and (cfg.sidebarSeparateSpacing or 8)) or 0)
		end
		cf:SetClampRectInsets(left, r, t + P.TabAreaHeight(), b)
	end)
	ECHAT.ApplyBorders()
end

function ECHAT.ApplyBackground()
	local p = DB()
	BG_R, BG_G, BG_B, BG_A = p.bgR or 0.03, p.bgG or 0.045, p.bgB or 0.05, p.bgAlpha or 0.65
	local path = P.TexturePath(p.bgTexture)
	P.ForEachChatFrame(function(cf)
		local d = FD(cf)
		if d.bg then
			P.PaintFill(d.bg, path, BG_R, BG_G, BG_B, BG_A)
		end
		local eb = _G[cf:GetName() .. "EditBox"]
		local ed = eb and FD(eb)
		if ed and ed.fill then
			ed.fill:SetTexture(BG_R, BG_G, BG_B, max(BG_A, 0.9))
		end
	end)
	local sb = FD(ChatFrame1).sidebar
	if sb then
		P.PaintFill(sb.bg, path, BG_R, BG_G, BG_B, BG_A)
	end
	ECHAT.ApplyCombatLogBar()
	ECHAT.ApplyExtendedBackground()
end

-- Inner borders (1 px around each panel) and dividers.
function ECHAT.ApplyBorders()
	local cfg = DB()
	local hide = ECHAT.BordersHidden(cfg)
	local r, g, b, a = P.InnerBorderColor(cfg)
	P.ForEachChatFrame(function(cf)
		local d = FD(cf)
		if d.edges then
			local px = P.PixelFor(cf)
			P.LayoutEdges(d.edges, px, r, g, b, a)
			P.ShowEdges(d.edges, not hide)
			d.inputDiv:SetTexture(r, g, b, a)
			d.inputDiv:SetShown(not hide)
		end
	end)
	local sb = FD(ChatFrame1).sidebar
	if sb then
		P.LayoutEdges(sb.edges, P.PixelFor(sb), r, g, b, a)
		P.ShowEdges(sb.edges, not hide and not cfg.hideSidebarBg)
		sb.div:SetTexture(r, g, b, a)
		sb.div:SetShown(not hide and cfg.sidebarSeparate ~= true)
	end
	ECHAT.ApplyExtendedBackground()
end

-------------------------------------------------------------------------------
--  Tabs Inside Chat Panel band, outer panel border, separate sidebar border
-------------------------------------------------------------------------------
local band, sideBand, panelBorder, sbBorder

local function SidebarInLayout(cfg)
	local mode = cfg.sidebarVisibility or "always"
	return mode == "always" or (mode == "mouseover" and P.sidebarHoverLayout)
end

local function NewBorderFrame()
	local f = CreateFrame("Frame", nil, UIParent)
	f:EnableMouse(false)
	f.edges = P.CreateEdges(f, f, "OVERLAY", 7)
	return f
end

function ECHAT.ApplyExtendedBackground()
	local cfg = DB()
	local cf1 = ChatFrame1
	local d1 = FD(cf1)
	if not d1.bg then
		return
	end
	local extend = ECHAT.ExtendBgBehindTabs(cfg)
	local areaH = P.TabAreaHeight()
	local path = P.TexturePath(cfg.bgTexture)

	if extend and not band then
		band = CreateFrame("Frame", nil, UIParent)
		band.tex = band:CreateTexture(nil, "BACKGROUND")
		band.tex:SetAllPoints()
		P.band = band
	end
	if band then
		band:ClearAllPoints()
		band:SetPoint("BOTTOMLEFT", d1.bg, "TOPLEFT", 0, 0)
		band:SetPoint("BOTTOMRIGHT", d1.bg, "TOPRIGHT", 0, 0)
		band:SetHeight(areaH)
		band:SetFrameStrata("BACKGROUND")
		band:SetFrameLevel(1)
		P.PaintFill(band.tex, path, BG_R, BG_G, BG_B, BG_A)
		band:SetAlpha(P.alphaCur or 1)
		band:SetShown(extend)
	end

	-- The sidebar's matching strip plus the sidebar / chat hairline.
	local sb = d1.sidebar
	if sb then
		local showSb = extend and not cfg.hideSidebarBg
		if showSb and not sideBand then
			sideBand = CreateFrame("Frame", nil, sb)
			sideBand.tex = sideBand:CreateTexture(nil, "BACKGROUND")
			sideBand.tex:SetAllPoints()
			sideBand.div = sideBand:CreateTexture(nil, "OVERLAY", nil, 7)
		end
		if sideBand then
			sideBand:ClearAllPoints()
			sideBand:SetPoint("BOTTOMLEFT", sb, "TOPLEFT", 0, 0)
			sideBand:SetPoint("BOTTOMRIGHT", sb, "TOPRIGHT", 0, 0)
			sideBand:SetHeight(areaH)
			sideBand:SetFrameLevel(sb:GetFrameLevel())
			P.PaintFill(sideBand.tex, path, BG_R, BG_G, BG_B, BG_A)
			local div = sideBand.div
			div:SetTexture(P.InnerBorderColor(cfg))
			div:SetWidth(P.PixelFor(sb))
			div:ClearAllPoints()
			if cfg.sidebarRight then
				div:SetPoint("TOPLEFT")
				div:SetPoint("BOTTOMLEFT")
			else
				div:SetPoint("TOPRIGHT")
				div:SetPoint("BOTTOMRIGHT")
			end
			div:SetShown(not cfg.hideBorders and cfg.sidebarSeparate ~= true)
			sideBand:SetShown(showSb)
		end
	end

	-- One border around the whole panel: band, chat background, and the
	-- sidebar on whichever side it is (a separate sidebar gets its own).
	if not panelBorder then
		panelBorder = NewBorderFrame()
		P.panelBorder = panelBorder
	end
	local includeSidebar = sb and not cfg.hideSidebarBg and SidebarInLayout(cfg) and cfg.sidebarSeparate ~= true
	local top = extend and areaH or 0
	panelBorder:ClearAllPoints()
	if includeSidebar and not cfg.sidebarRight then
		panelBorder:SetPoint("TOPLEFT", sb, "TOPLEFT", 0, top)
		panelBorder:SetPoint("BOTTOMRIGHT", d1.bg, "BOTTOMRIGHT", 0, 0)
	elseif includeSidebar then
		panelBorder:SetPoint("TOPLEFT", d1.bg, "TOPLEFT", 0, top)
		panelBorder:SetPoint("BOTTOMRIGHT", sb, "BOTTOMRIGHT", 0, 0)
	else
		panelBorder:SetPoint("TOPLEFT", d1.bg, "TOPLEFT", 0, top)
		panelBorder:SetPoint("BOTTOMRIGHT", d1.bg, "BOTTOMRIGHT", 0, 0)
	end
	local behind = cfg.panelBorderBehind == true
	panelBorder:SetFrameStrata(behind and "BACKGROUND" or "MEDIUM")
	panelBorder:SetFrameLevel(behind and 0 or 96)
	local steps = BORDER_STEPS[cfg.panelBorderThickness or "none"] or 0
	local px = P.PixelFor(panelBorder)
	local br, bg, bb, ba = P.PanelBorderColor(cfg, "panelBorder")
	P.LayoutEdges(panelBorder.edges, steps * px, br, bg, bb, ba, behind)
	panelBorder:SetAlpha(P.alphaCur or 1)
	panelBorder:SetShown(steps > 0)

	local wantSb = cfg.sidebarSeparate == true and sb and not cfg.hideSidebarBg
		and (cfg.sidebarVisibility or "always") ~= "never"
	if wantSb and not sbBorder then
		sbBorder = NewBorderFrame()
		P.sbBorder = sbBorder
	end
	if sbBorder then
		if wantSb then
			sbBorder:ClearAllPoints()
			sbBorder:SetPoint("TOPLEFT", sb, "TOPLEFT", 0, (extend and not cfg.hideSidebarBg) and areaH or 0)
			sbBorder:SetPoint("BOTTOMRIGHT", sb, "BOTTOMRIGHT", 0, 0)
			sbBorder:SetFrameStrata(behind and "BACKGROUND" or "MEDIUM")
			sbBorder:SetFrameLevel(behind and 0 or 96)
			P.LayoutEdges(sbBorder.edges, steps * px, br, bg, bb, ba, behind)
			sbBorder:SetAlpha(min(P.alphaCur or 1, P.sbFadeAlpha or 1))
			sbBorder:SetShown(steps > 0)
		else
			sbBorder:Hide()
		end
	end
	if ECHAT.ApplyTabAppearance then
		ECHAT.ApplyTabAppearance()
	end
end

-------------------------------------------------------------------------------
--  Lock Main Chat Size
-------------------------------------------------------------------------------
function ECHAT.ApplyLockChatSize()
	local cf1 = ChatFrame1
	local rb = cf1 and (cf1.resizeButton or _G.ChatFrame1ResizeButton)
	if not rb then
		return
	end
	if DB().lockChatSize then
		rb:Hide()
	elseif not cf1.isLocked and not cf1.isUninteractable then
		rb:Show()
	end
end

-------------------------------------------------------------------------------
--  Sidebar: icon column beside the main chat window
-------------------------------------------------------------------------------
local ICON_ALPHA, ICON_HOVER_ALPHA = 0.4, 0.9
local BASE_ICON, BASE_FRIEND, BASE_FONT = 22, 26, 9

ECHAT.SIDEBAR_CHAIN_KEYS = { "showFriends", "showGuild", "showDurability", "showCopy", "showVoice", "showSettings" }
local SIDEBAR_FALLBACK_ORDER = {
	showFriends = -20, showGuild = -15, showDurability = -10,
	showCopy = 1, showVoice = 3, showSettings = 4,
}
ECHAT.SIDEBAR_ICON_LABELS = {
	showFriends = "Friends",
	showGuild = "Guild",
	showDurability = "Durability",
	showCopy = "Copy Chat",
	showVoice = "Voice/Channels",
	showSettings = "Settings",
	showScroll = "Scroll to Bottom",
}
local TOOLTIP_LABELS = {
	showFriends = "Friends", showGuild = "Guild", showDurability = "Equipment Durability",
	showCopy = "Copy Chat", showVoice = "Voice/Channels", showSettings = "Settings",
	showScroll = "Scroll to Bottom",
}
local ICON_FILES = {
	showFriends = "chat_friends", showGuild = "chat_guild", showDurability = "chat_durability",
	showCopy = "chat_copy", showVoice = "chat_voice", showSettings = "chat_settings",
	showScroll = "chat_scroll2",
}
local FREE_MOVE_KEYS = {
	showFriends = "friends", showGuild = "guild", showDurability = "durability",
	showCopy = "copy", showVoice = "voice", showSettings = "settings", showScroll = "scroll",
}

-- Chain icon keys in the user's saved order.
function ECHAT.ResolveSidebarIconOrder()
	local map = DB().sidebarIconOrder or {}
	local keys, index = {}, {}
	for i, k in ipairs(ECHAT.SIDEBAR_CHAIN_KEYS) do
		keys[i] = k
		index[k] = i
	end
	local function OrderOf(k)
		local o = map[k]
		if type(o) == "number" then
			return o
		end
		return SIDEBAR_FALLBACK_ORDER[k] or 999
	end
	table.sort(keys, function(a, b)
		local oa, ob = OrderOf(a), OrderOf(b)
		if oa ~= ob then
			return oa < ob
		end
		return index[a] < index[b]
	end)
	return keys
end

function ECHAT.SidebarWidthDefault()
	return 40
end

local function SidebarWidth()
	return min(100, max(30, DB().sidebarWidth or ECHAT.SidebarWidthDefault()))
end

local function IconColor()
	local cfg = DB()
	if cfg.iconUseAccent then
		return P.Accent()
	end
	return cfg.iconR or 1, cfg.iconG or 1, cfg.iconB or 1
end

-- Toward the chat panel (retail ANCHOR_RIGHT).
local function TipSide()
	return DB().sidebarRight and "left" or "right"
end

local function SetIconHover(btn, on)
	local r, g, b = IconColor()
	btn.icon:SetVertexColor(r, g, b, on and ICON_HOVER_ALPHA or ICON_ALPHA)
	if btn.count then
		btn.count:SetTextColor(r, g, b, on and 0.9 or 0.5)
	end
end

local function MakeIcon(sb, key)
	local btn = CreateFrame("Button", nil, sb)
	btn.key = key
	btn:SetSize(BASE_ICON, BASE_ICON)
	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	btn.icon = btn:CreateTexture(nil, "ARTWORK")
	btn.icon:SetAllPoints()
	btn.icon:SetTexture(P.MEDIA .. ICON_FILES[key])
	btn.icon:SetDesaturated(true)
	btn:SetScript("OnEnter", function(self)
		SetIconHover(self, true)
		if not self.justDragged then
			P.ShowTip(self, TOOLTIP_LABELS[key], TipSide())
		end
		if ECHAT.OnHoverChange then ECHAT.OnHoverChange() end
	end)
	btn:SetScript("OnLeave", function(self)
		SetIconHover(self, false)
		P.HideTip()
	end)
	SetIconHover(btn, false)
	return btn
end

local function MakeCount(btn, sb, inside)
	local fs = sb:CreateFontString(nil, "OVERLAY")
	P.SetFont(fs, ECHAT.GetFont(), BASE_FONT, "")
	fs:SetText("0")
	btn.count = fs
	btn.countDrop = inside
	return fs
end

local function OpenFriends()
	if InCombatLockdown() then
		UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1.0, 0.3, 0.3, 1.0)
		return
	end
	ToggleFriendsFrame(1)
end

local function OpenGuild()
	if InCombatLockdown() then
		UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1.0, 0.3, 0.3, 1.0)
		return
	end
	if ToggleGuildFrame then
		ToggleGuildFrame()
	end
end

local function OpenChannels()
	if InCombatLockdown() then
		return
	end
	-- 5.4.8: Social > Chat (the channel list) is the Friends frame's third tab.
	ToggleFriendsFrame(3)
end

local function OpenSettings()
	if InCombatLockdown() then
		return
	end
	if ns.LoadOptions and ns.LoadOptions() and ns.OpenSettingsModule then
		ns.OpenSettingsModule("chat")
	elseif ns.ToggleSettings then
		ns.ToggleSettings()
	end
end

local function UpdateFriendsCount(btn)
	local bnOnline = 0
	if BNGetNumFriends then
		local _, online = BNGetNumFriends()
		bnOnline = online or 0
	end
	local _, wowOnline = GetNumFriends()
	btn.count:SetText((bnOnline or 0) + (wowOnline or 0))
end

local lastRoster = 0
local function UpdateGuildCount(btn)
	if not IsInGuild() then
		btn.count:SetText(0)
		return
	end
	local now = GetTime()
	if not InCombatLockdown() and now - lastRoster >= 15 then
		lastRoster = now
		GuildRoster()
	end
	local _, online = GetNumGuildMembers()
	btn.count:SetText(online or 0)
end

local function UpdateDurability(btn)
	local lowest = 100
	for slot = 1, 18 do
		local cur, mx = GetInventoryItemDurability(slot)
		if cur and mx and mx > 0 then
			local pct = cur / mx * 100
			if pct < lowest then
				lowest = pct
			end
		end
	end
	btn.count:SetText(floor(lowest) .. "%")
end

local function BuildSidebar()
	local cf = ChatFrame1
	local d = FD(cf)
	if d.sidebar or not d.bg then
		return
	end
	local sb = CreateFrame("Frame", "EllesmereUIChatSidebar", UIParent)
	d.sidebar = sb
	sb:SetWidth(SidebarWidth())
	sb:SetFrameStrata(cf:GetFrameStrata())
	sb:SetFrameLevel(cf:GetFrameLevel() + 1)
	sb.bg = sb:CreateTexture(nil, "BACKGROUND")
	sb.bg:SetAllPoints()
	sb.edges = P.CreateEdges(sb, sb, "BORDER", 1)
	sb.div = sb:CreateTexture(nil, "OVERLAY", nil, 7)
	sb:EnableMouse(true)
	sb:SetScript("OnEnter", function()
		if (DB().sidebarVisibility or "always") == "mouseover" then
			P.sbFadeTarget = 1
			if not P.sidebarHoverLayout then
				P.sidebarHoverLayout = true
				ECHAT.ApplySidebarIcons()
				ECHAT.ApplyExtendedBackground()
			end
			P.sbFadeFrame:Show()
		end
		if ECHAT.OnHoverChange then ECHAT.OnHoverChange() end
	end)
	sb:SetScript("OnLeave", function()
		if (DB().sidebarVisibility or "always") == "mouseover" then
			P.After(0, function()
				if not sb:IsMouseOver() then
					P.sbFadeTarget = 0
					P.sbFadeFrame:Show()
				end
			end)
		end
	end)

	local buttons = {}
	sb.buttons = buttons
	for _, key in ipairs(ECHAT.SIDEBAR_CHAIN_KEYS) do
		buttons[key] = MakeIcon(sb, key)
	end
	buttons.showScroll = MakeIcon(sb, "showScroll")

	local friends = buttons.showFriends
	MakeCount(friends, sb, 7)
	friends:SetScript("OnClick", OpenFriends)
	local ev = CreateFrame("Frame")
	for _, e in ipairs({ "BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE", "FRIENDLIST_UPDATE",
		"PLAYER_ENTERING_WORLD", "BN_CONNECTED", "BN_DISCONNECTED", "BN_FRIEND_INFO_CHANGED" }) do
		pcall(ev.RegisterEvent, ev, e)
	end
	ev:SetScript("OnEvent", function() UpdateFriendsCount(friends) end)
	UpdateFriendsCount(friends)

	local guild = buttons.showGuild
	MakeCount(guild, sb, 7)
	guild:SetScript("OnClick", OpenGuild)
	local gev = CreateFrame("Frame")
	gev:RegisterEvent("GUILD_ROSTER_UPDATE")
	gev:RegisterEvent("PLAYER_GUILD_UPDATE")
	gev:RegisterEvent("PLAYER_ENTERING_WORLD")
	gev:SetScript("OnEvent", function() UpdateGuildCount(guild) end)

	local dura = buttons.showDurability
	MakeCount(dura, sb, 0)
	local dev = CreateFrame("Frame")
	dev:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
	dev:RegisterEvent("UPDATE_INVENTORY_ALERTS")
	dev:RegisterEvent("PLAYER_ENTERING_WORLD")
	dev:SetScript("OnEvent", function() P.After(0, function() UpdateDurability(dura) end) end)
	UpdateDurability(dura)

	buttons.showCopy:SetScript("OnClick", function()
		if ECHAT.ShowCopyPopup then
			ECHAT.ShowCopyPopup(P.SelectedWindow())
		end
	end)
	buttons.showVoice:SetScript("OnClick", OpenChannels)
	buttons.showSettings:SetScript("OnClick", OpenSettings)
	buttons.showScroll:SetScript("OnClick", function()
		local cf2 = P.SelectedWindow()
		if cf2 and cf2.ScrollToBottom then
			cf2:ScrollToBottom()
		end
	end)
	-- Scroll to Bottom tells you there is more below (like Blizzard's arrow).
	buttons.showScroll.flash = 0
	buttons.showScroll:SetScript("OnUpdate", function(self, elapsed)
		local cf2 = P.SelectedWindow()
		local below = cf2 and cf2.AtBottom and not cf2:AtBottom()
		if below then
			self.flash = self.flash + elapsed
			local a = 0.4 + 0.5 * (0.5 + 0.5 * math.sin(self.flash * 4))
			local r, g, b = IconColor()
			self.icon:SetVertexColor(r, g, b, self:IsMouseOver() and ICON_HOVER_ALPHA or a)
			self.wasBelow = true
		elseif self.wasBelow then
			self.wasBelow = nil
			SetIconHover(self, self:IsMouseOver())
		end
	end)

	for key, btn in pairs(buttons) do
		ECHAT.EnableIconFreeMove(btn, key)
	end
end

function ECHAT.SidebarIconExists(key)
	local sb = FD(ChatFrame1).sidebar
	return sb and sb.buttons and sb.buttons[key] ~= nil
end

-- Icon chain, laid out from the sidebar top (natural spots + free move
-- offsets).
function ECHAT.ApplySidebarIcons()
	local cfg = DB()
	local sb = FD(ChatFrame1).sidebar
	if not sb then
		return
	end
	local gap = cfg.sidebarIconSpacing or 10
	local shift = (ECHAT.ExtendBgBehindTabs(cfg) and not cfg.freeMoveIcons) and P.TabAreaHeight() or 0
	local mode = cfg.sidebarVisibility or "always"
	local hidden = mode == "never"
		or (mode == "mouseover" and (P.sbFadeTarget or 0) == 0 and (P.sbFadeAlpha or 0) == 0)
		or P.passthrough == true
	local positions = cfg.freeMoveIcons and cfg.iconPositions or nil
	local y = -gap + shift
	for _, key in ipairs(ECHAT.ResolveSidebarIconOrder()) do
		local btn = sb.buttons[key]
		local shown = cfg[key] ~= false and not hidden
		btn:SetShown(shown)
		if btn.count then
			btn.count:SetShown(shown)
		end
		if shown then
			local h = btn:GetHeight()
			local pos = positions and positions[FREE_MOVE_KEYS[key]]
			local ox, oy = pos and pos.x or 0, pos and pos.y or 0
			btn:ClearAllPoints()
			btn:SetPoint("TOP", sb, "TOP", ox, y + oy)
			btn.naturalY = y
			local bottom = y - h
			if btn.count then
				btn.count:ClearAllPoints()
				btn.count:SetPoint("TOP", btn, "BOTTOM", 0, btn.countDrop or 0)
				bottom = bottom + (btn.countDrop or 0) - (btn.count:GetStringHeight() or BASE_FONT)
			end
			y = bottom - gap
		end
	end
	local scroll = sb.buttons.showScroll
	scroll:SetShown(cfg.showScroll ~= false
		and (not hidden or (cfg.scrollButtonOnChat == true and P.passthrough ~= true)))
	ECHAT.ApplyScrollButtonPosition()
end

function ECHAT.ApplyScrollButtonPosition()
	local cf1 = ChatFrame1
	local sb = FD(cf1).sidebar
	if not sb then
		return
	end
	local cfg = DB()
	local btn = sb.buttons.showScroll
	btn:ClearAllPoints()
	if cfg.scrollButtonOnChat then
		btn:SetParent(UIParent)
		btn:SetFrameStrata(cf1:GetFrameStrata())
		btn:SetFrameLevel(cf1:GetFrameLevel() + 5)
		btn:SetPoint("BOTTOMRIGHT", cf1, "BOTTOMRIGHT", 8, -6)
		btn:SetAlpha(P.alphaCur or 1)
	else
		btn:SetParent(sb)
		btn:SetFrameLevel(sb:GetFrameLevel() + 1)
		btn:SetAlpha(1)
		local pos = cfg.freeMoveIcons and cfg.iconPositions and cfg.iconPositions.scroll
		btn:SetPoint("BOTTOM", sb, "BOTTOM", pos and pos.x or 0, 10 + (pos and pos.y or 0))
	end
end

-- Free Move Icons: Shift+drag an icon; its offset from its natural spot is
-- saved (iconPositions[key] = { x, y }).
function ECHAT.EnableIconFreeMove(btn, key)
	local fkey = FREE_MOVE_KEYS[key]
	local startX, startY, baseX, baseY
	local function Stop(self)
		self:SetScript("OnUpdate", self.normalUpdate)
		P.After(0, function() self.justDragged = nil end)
	end
	btn.normalUpdate = btn:GetScript("OnUpdate")
	local click = btn:GetScript("OnClick")
	if click then
		btn:SetScript("OnClick", function(self, ...)
			if self.justDragged then
				return
			end
			click(self, ...)
		end)
	end
	btn:HookScript("OnMouseDown", function(self, mouse)
		local cfg = DB()
		if mouse ~= "LeftButton" or not IsShiftKeyDown() or not cfg.freeMoveIcons then
			return
		end
		self.justDragged = true
		local es = self:GetEffectiveScale()
		startX, startY = GetCursorPosition()
		startX, startY = startX / es, startY / es
		local pos = cfg.iconPositions and cfg.iconPositions[fkey]
		baseX, baseY = pos and pos.x or 0, pos and pos.y or 0
		self:SetScript("OnUpdate", function(s)
			if not IsMouseButtonDown("LeftButton") then
				Stop(s)
				return
			end
			local es2 = s:GetEffectiveScale()
			local cx, cy = GetCursorPosition()
			local nx = floor(baseX + (cx / es2 - startX) + 0.5)
			local ny = floor(baseY + (cy / es2 - startY) + 0.5)
			local c = DB()
			c.iconPositions = c.iconPositions or {}
			c.iconPositions[fkey] = { x = nx, y = ny }
			if key == "showScroll" then
				ECHAT.ApplyScrollButtonPosition()
			else
				s:ClearAllPoints()
				s:SetPoint("TOP", s:GetParent(), "TOP", nx, (s.naturalY or 0) + ny)
			end
		end)
	end)
	btn:HookScript("OnMouseUp", function(self)
		if self.justDragged then
			Stop(self)
		end
	end)
end

function ECHAT.ApplyIconFreeMove()
	ECHAT.ApplySidebarIcons()
end

function ECHAT.ApplyIconColor()
	local sb = FD(ChatFrame1).sidebar
	if not sb then
		return
	end
	for _, btn in pairs(sb.buttons) do
		SetIconHover(btn, false)
	end
end

function ECHAT.ApplySidebarIconScale()
	local sb = FD(ChatFrame1).sidebar
	if not sb then
		return
	end
	local scale = DB().sidebarIconScale or 1.0
	for key, btn in pairs(sb.buttons) do
		local base = (key == "showFriends" or key == "showGuild") and BASE_FRIEND or BASE_ICON
		btn:SetSize(base * scale, base * scale)
		if btn.count then
			P.SetFont(btn.count, ECHAT.GetFont(), max(7, BASE_FONT * scale), "")
		end
	end
	ECHAT.ApplySidebarIcons()
end

function ECHAT.ApplySidebarBackground()
	local cfg = DB()
	local sb = FD(ChatFrame1).sidebar
	if not sb then
		return
	end
	sb.bg:SetShown(not cfg.hideSidebarBg)
	ECHAT.ApplyBorders()
end

function ECHAT.ApplySidebarWidth()
	local sb = FD(ChatFrame1).sidebar
	if not sb then
		return
	end
	sb:SetWidth(SidebarWidth())
	ECHAT.ApplySidebarPosition()
end

function ECHAT.ApplySidebarPosition()
	local cfg = DB()
	local d = FD(ChatFrame1)
	local sb = d.sidebar
	if not sb or not d.bg then
		return
	end
	local gap = cfg.sidebarSeparate == true and (cfg.sidebarSeparateSpacing or 8) or 0
	sb:ClearAllPoints()
	if cfg.sidebarRight then
		sb:SetPoint("TOPLEFT", d.bg, "TOPRIGHT", gap, 0)
		sb:SetPoint("BOTTOMLEFT", d.bg, "BOTTOMRIGHT", gap, 0)
	else
		sb:SetPoint("TOPRIGHT", d.bg, "TOPLEFT", -gap, 0)
		sb:SetPoint("BOTTOMRIGHT", d.bg, "BOTTOMLEFT", -gap, 0)
	end
	sb.div:ClearAllPoints()
	sb.div:SetWidth(P.PixelFor(sb))
	if cfg.sidebarRight then
		sb.div:SetPoint("TOPLEFT")
		sb.div:SetPoint("BOTTOMLEFT")
	else
		sb.div:SetPoint("TOPRIGHT")
		sb.div:SetPoint("BOTTOMRIGHT")
	end
	ECHAT.ApplyBorders()
	ECHAT.ApplyInputPosition()
end

-- Sidebar visibility: always, mouseover, never (0.25 s fade on hover).
P.sbFadeTarget, P.sbFadeAlpha = 1, 1
P.sbFadeFrame = CreateFrame("Frame")
P.sbFadeFrame:Hide()
P.sbFadeFrame:SetScript("OnUpdate", function(self, dt)
	local step = dt * 4
	if P.sbFadeTarget > P.sbFadeAlpha then
		P.sbFadeAlpha = min(P.sbFadeTarget, P.sbFadeAlpha + step)
	else
		P.sbFadeAlpha = max(P.sbFadeTarget, P.sbFadeAlpha - step)
	end
	local sb = FD(ChatFrame1).sidebar
	local a = min(P.sbFadeAlpha, P.alphaCur or 1)
	if sb then
		sb:SetAlpha(a)
	end
	if sbBorder then
		sbBorder:SetAlpha(a)
	end
	if P.sbFadeAlpha == P.sbFadeTarget then
		self:Hide()
		if P.sbFadeTarget == 0 and P.sidebarHoverLayout then
			P.sidebarHoverLayout = false
			ECHAT.ApplySidebarIcons()
			ECHAT.ApplyExtendedBackground()
		end
	end
end)

function ECHAT.ApplySidebarVisibility()
	local cfg = DB()
	local sb = FD(ChatFrame1).sidebar
	if not sb then
		return
	end
	local mode = cfg.sidebarVisibility or "always"
	if mode == "always" then
		P.sidebarHoverLayout = true
		P.sbFadeTarget, P.sbFadeAlpha = 1, 1
		sb:SetAlpha(P.alphaCur or 1)
	else
		P.sidebarHoverLayout = false
		P.sbFadeTarget, P.sbFadeAlpha = 0, 0
		sb:SetAlpha(0)
	end
	sb:EnableMouse(mode ~= "never" and P.passthrough ~= true)
	ECHAT.ApplySidebarIcons()
	ECHAT.ApplyExtendedBackground()
	ECHAT.ApplyInputPosition()
end

-------------------------------------------------------------------------------
--  Fade: visibility (top authority) and idle fade, animated
-------------------------------------------------------------------------------
local FADE_IN, FADE_OUT, IDLE_FADE_OUT = 0.35, 1.0, 2.0
local alphaTarget, visAlpha = 1, 1
local visChatVisible = true
local idleActive = false
P.alphaCur = 1

-- Strength 100 hides chat fully: alpha 0 and clicks pass through to the world.
local function SetPassthrough(on)
	on = on and true or false
	if P.passthrough == on then
		return
	end
	P.passthrough = on
	P.ForEachChatFrame(function(cf)
		local d = FD(cf)
		if on then
			d.mouseWas = cf:IsMouseEnabled()
			cf:EnableMouse(false)
		elseif d.mouseWas ~= nil then
			cf:EnableMouse(d.mouseWas)
			d.mouseWas = nil
		end
		local tab = _G[cf:GetName() .. "Tab"]
		if tab then
			tab:EnableMouse(not on)
		end
	end)
	local gdm = _G.GeneralDockManager
	if gdm and gdm.overflowButton then
		gdm.overflowButton:EnableMouse(not on)
	end
	local sb = FD(ChatFrame1).sidebar
	if sb then
		sb:EnableMouse(not on and (DB().sidebarVisibility or "always") ~= "never")
	end
	ECHAT.ApplySidebarIcons()
end

function ECHAT.ApplyAlpha(a)
	P.alphaCur = a
	SetPassthrough(a <= 0)
	P.ForEachChatFrame(function(cf)
		cf:SetAlpha(a)
		local tab = _G[cf:GetName() .. "Tab"]
		if tab and not cf.isDocked then
			tab:SetAlpha(a)
		end
	end)
	if _G.GeneralDockManager then
		_G.GeneralDockManager:SetAlpha(a)
	end
	if band then
		band:SetAlpha(a)
	end
	if panelBorder then
		panelBorder:SetAlpha(a)
	end
	if sbBorder then
		sbBorder:SetAlpha(min(a, P.sbFadeAlpha or 1))
	end
	local cfg = DB()
	local sb = FD(ChatFrame1).sidebar
	if sb then
		local mode = cfg.sidebarVisibility or "always"
		if mode == "mouseover" then
			sb:SetAlpha(min(a, P.sbFadeAlpha or 0))
		elseif mode == "never" then
			sb:SetAlpha(0)
		else
			sb:SetAlpha(a)
		end
		if cfg.scrollButtonOnChat then
			sb.buttons.showScroll:SetAlpha(a)
		end
	end
end

local fadeFrame = CreateFrame("Frame")
fadeFrame:Hide()
local fadeAccum = 0
fadeFrame:SetScript("OnUpdate", function(self, dt)
	local cur = P.alphaCur
	if cur == alphaTarget then
		self:Hide()
		ECHAT.ApplyAlpha(cur)
		return
	end
	local fadingIn = alphaTarget > cur
	local duration = fadingIn and FADE_IN or (idleActive and IDLE_FADE_OUT or FADE_OUT)
	local step = dt / duration
	if fadingIn then
		cur = min(alphaTarget, cur + step)
	else
		cur = max(alphaTarget, cur - step)
	end
	P.alphaCur = cur
	fadeAccum = fadeAccum + dt
	if fadeAccum < 0.016 and cur ~= alphaTarget then
		return
	end
	fadeAccum = 0
	ECHAT.ApplyAlpha(cur)
	if cur == alphaTarget then
		self:Hide()
	end
end)

local function SetAlphaTarget(a)
	alphaTarget = a
	fadeFrame:Show()
end

function ECHAT.SetChatAlpha(a)
	visAlpha = a
	visChatVisible = a >= 1
	SetAlphaTarget(a)
end

function ECHAT.SetIdleFadeAlpha(a)
	SetAlphaTarget(min(a, visAlpha))
end

local function GetIdleFadeAlpha()
	return 1 - min(DB().idleFadeStrength or 40, 100) / 100
end

local editFocusCount, hovering = 0, false

function ECHAT.RefreshVisibility()
	local cfg = DB()
	local vis = ECHAT.EvalVisibility(cfg)
	-- Typing always shows chat (the input box is part of the chat frame here).
	if editFocusCount > 0 then
		vis = true
	end
	local a = vis and 1 or 0
	if a == 1 and idleActive then
		ECHAT.SetChatAlpha(1)
		ECHAT.SetIdleFadeAlpha(GetIdleFadeAlpha())
	else
		ECHAT.SetChatAlpha(a)
	end
end

local idleTimer
local function IdleApplicable()
	return ECHAT.VisBase(DB()) ~= "never"
end

local function StartIdleFade()
	idleTimer = nil
	if DB().idleFadeEnabled == false or idleActive then
		return
	end
	idleActive = true
	ECHAT.SetIdleFadeAlpha(GetIdleFadeAlpha())
end

local function CancelIdleFade()
	idleActive = false
	if idleTimer then
		idleTimer:Cancel()
		idleTimer = nil
	end
	if visChatVisible then
		ECHAT.SetIdleFadeAlpha(1)
	end
end

function ECHAT.ResetIdleTimer()
	CancelIdleFade()
	local cfg = DB()
	if not P.started or not IdleApplicable() or cfg.idleFadeEnabled == false then
		return
	end
	if hovering or editFocusCount > 0 then
		return
	end
	idleTimer = P.NewTimer(cfg.idleFadeDelay or 15, StartIdleFade)
end
ECHAT.ApplyIdleFadeHoverMotion = function() end

-- Player chat in a shown window, whispers, typing: wake (at most once a second).
local lastWake = 0
function ECHAT.OnActiveMessage()
	if not P.started or not IdleApplicable() then
		return
	end
	local now = GetTime()
	if now - lastWake < 1 then
		return
	end
	lastWake = now
	if hovering or editFocusCount > 0 then
		CancelIdleFade()
	else
		ECHAT.ResetIdleTimer()
	end
end

function ECHAT.OnEditFocus(gained)
	if gained then
		editFocusCount = editFocusCount + 1
	else
		editFocusCount = max(0, editFocusCount - 1)
	end
	if not P.started then
		return
	end
	ECHAT.RefreshVisibility()
	if editFocusCount > 0 then
		CancelIdleFade()
	else
		ECHAT.ResetIdleTimer()
	end
end

-- Hover over any part of chat (tabs, panel, sidebar) keeps it awake. The
-- cursor is checked against the panel rects 5 times a second; nothing else
-- runs while idle.
local function CursorOverChat()
	local x, y = GetCursorPosition()
	local over = false
	local function Test(region, padTop)
		if over or not region then
			return
		end
		local l, r, b, t = region:GetLeft(), region:GetRight(), region:GetBottom(), region:GetTop()
		if not l then
			return
		end
		-- Textures have no scale of their own: their frame's.
		local owner = region.GetEffectiveScale and region or region:GetParent()
		local s = owner:GetEffectiveScale()
		local cx, cy = x / s, y / s
		if cx >= l and cx <= r and cy >= b and cy <= t + (padTop or 0) then
			over = true
		end
	end
	P.ForEachChatFrame(function(cf)
		if cf:IsVisible() or cf == ChatFrame1 then
			local d = FD(cf)
			if d.bg then
				Test(d.bg, (cf.isDocked or cf == ChatFrame1) and 0 or P.TabHeight() + 8)
			end
		end
	end)
	if not over then
		Test(_G.GeneralDockManager)
	end
	local sb = FD(ChatFrame1).sidebar
	if not over and sb and sb:IsVisible() and (DB().sidebarVisibility or "always") ~= "never" then
		Test(sb)
	end
	return over
end

local hoverPoll = CreateFrame("Frame")
hoverPoll:Hide()
local pollAccum = 0
hoverPoll:SetScript("OnUpdate", function(_, dt)
	pollAccum = pollAccum + dt
	if pollAccum < 0.2 then
		return
	end
	pollAccum = 0
	local over = CursorOverChat()
	if over and not hovering then
		hovering = true
		if IdleApplicable() then
			CancelIdleFade()
		end
	elseif not over and hovering then
		hovering = false
		ECHAT.ResetIdleTimer()
	end
end)

function ECHAT.OnHoverChange()
	pollAccum = 1
end

-------------------------------------------------------------------------------
--  Copy Chat popup (the sidebar's copy icon)
-------------------------------------------------------------------------------
local function StripUIEscapes(text)
	if not text then
		return ""
	end
	text = text:gsub("|H.-|h(.-)|h", "%1")
	text = text:gsub("|T.-|t", "")
	text = text:gsub("|K.-|k", "")
	text = text:gsub("|n", "\n")
	text = text:gsub("||", "|")
	return text
end
P.StripUIEscapes = StripUIEscapes

local copyDimmer

local function FlatButton(parent, w, h, text)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, h)
	local bg = b:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetTexture(0.06, 0.06, 0.06, 0.92)
	local e = P.CreateEdges(b, b, "BORDER", 1)
	P.LayoutEdges(e, P.PixelFor(b), 1, 1, 1, 0.25)
	b.label = P.NewText(b, "OVERLAY", 10)
	b.label:SetPoint("CENTER")
	b.label:SetText(text)
	b.label:SetTextColor(1, 1, 1, 0.8)
	b:SetScript("OnEnter", function()
		local r, g, bb = P.Accent()
		P.LayoutEdges(e, P.PixelFor(b), r, g, bb, 0.9)
		b.label:SetTextColor(1, 1, 1, 1)
	end)
	b:SetScript("OnLeave", function()
		P.LayoutEdges(e, P.PixelFor(b), 1, 1, 1, 0.25)
		b.label:SetTextColor(1, 1, 1, 0.8)
	end)
	return b
end
P.FlatButton = FlatButton

local function BuildCopyPopup()
	local W, H = 520, 340
	local dimmer = CreateFrame("Frame", "EllesmereUIChatCopyFrame", UIParent)
	dimmer:SetFrameStrata("FULLSCREEN_DIALOG")
	dimmer:SetAllPoints(UIParent)
	dimmer:EnableMouse(true)
	dimmer:EnableMouseWheel(true)
	dimmer:SetScript("OnMouseWheel", function() end)
	dimmer:Hide()
	local dim = dimmer:CreateTexture(nil, "BACKGROUND")
	dim:SetAllPoints()
	dim:SetTexture(0, 0, 0, 0.25)
	tinsert(UISpecialFrames, "EllesmereUIChatCopyFrame")

	local popup = CreateFrame("Frame", nil, dimmer)
	popup:SetSize(W, H)
	popup:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
	popup:SetFrameLevel(dimmer:GetFrameLevel() + 10)
	popup:EnableMouse(true)
	local bg = popup:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetTexture(0.077, 0.068, 0.058, 0.95)
	P.LayoutEdges(P.CreateEdges(popup, popup, "BORDER", 1), P.PixelFor(popup), 1, 1, 1, 0.15)

	local scroll = CreateFrame("ScrollFrame", nil, popup)
	scroll:SetPoint("TOPLEFT", popup, "TOPLEFT", 20, -20)
	scroll:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -26, 60)
	local eb = CreateFrame("EditBox", nil, scroll)
	eb:SetMultiLine(true)
	eb:SetMaxLetters(0)
	eb:SetAutoFocus(false)
	eb:SetWidth(W - 46)
	eb:SetHeight(H - 80)
	P.SetFont(eb, ECHAT.GetFont(), 12, ECHAT.GetOutlineFlag())
	eb:SetTextColor(1, 1, 1, 0.75)
	scroll:SetScrollChild(eb)
	eb:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		dimmer:Hide()
	end)
	-- Read only: typing puts the text back.
	eb:SetScript("OnTextChanged", function(self)
		if self.readOnly and self:GetText() ~= self.readOnly then
			self:SetText(self.readOnly)
			self:HighlightText()
		end
		scroll:UpdateScrollChildRect()
	end)
	eb:SetScript("OnCursorChanged", function(self, x, y, w, h)
		local top = -y
		local view = scroll:GetHeight()
		local cur = scroll:GetVerticalScroll()
		if top < cur then
			scroll:SetVerticalScroll(top)
		elseif top + h > cur + view then
			scroll:SetVerticalScroll(min(scroll:GetVerticalScrollRange(), top + h - view))
		end
	end)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local v = self:GetVerticalScroll() - delta * 36
		self:SetVerticalScroll(max(0, min(self:GetVerticalScrollRange(), v)))
	end)

	-- Thin scroll bar
	local track = CreateFrame("Button", nil, popup)
	track:SetWidth(8)
	track:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 2, -2)
	track:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 2, 2)
	local thumb = track:CreateTexture(nil, "ARTWORK")
	thumb:SetTexture(1, 1, 1, 0.27)
	thumb:SetWidth(4)
	thumb:SetHeight(40)
	thumb:SetPoint("TOP", track, "TOP", 0, 0)
	local dragging, dragOff = false, 0
	local function Range()
		return scroll:GetVerticalScrollRange() or 0
	end
	local function UpdateThumb()
		local range = Range()
		local view = scroll:GetHeight() or 1
		if range <= 0 then
			thumb:Hide()
			return
		end
		thumb:Show()
		local trackH = track:GetHeight()
		local thumbH = max(20, trackH * view / (view + range))
		thumb:SetHeight(thumbH)
		local pct = scroll:GetVerticalScroll() / range
		thumb:ClearAllPoints()
		thumb:SetPoint("TOP", track, "TOP", 0, -(pct * (trackH - thumbH)))
	end
	local function ScrollFromCursor()
		local _, cy = GetCursorPosition()
		local s = track:GetEffectiveScale()
		local top = track:GetTop()
		if not top then
			return
		end
		local trackH = track:GetHeight()
		local thumbH = thumb:GetHeight()
		local travel = trackH - thumbH
		if travel <= 0 then
			return
		end
		local pct = max(0, min(1, (top - cy / s - dragOff) / travel))
		scroll:SetVerticalScroll(pct * Range())
	end
	track:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" then
			return
		end
		local _, cy = GetCursorPosition()
		local s = self:GetEffectiveScale()
		local tt, tb = thumb:GetTop(), thumb:GetBottom()
		if tt and tb and cy / s <= tt and cy / s >= tb then
			dragOff = tt - cy / s
		else
			dragOff = thumb:GetHeight() / 2
			ScrollFromCursor()
		end
		dragging = true
	end)
	track:SetScript("OnMouseUp", function() dragging = false end)
	popup:SetScript("OnUpdate", function()
		if dragging then
			ScrollFromCursor()
		end
		UpdateThumb()
	end)
	dimmer:HookScript("OnHide", function() dragging = false end)

	local close = FlatButton(popup, 90, 24, "Close")
	close:SetPoint("BOTTOM", popup, "BOTTOM", 0, 14)
	close:SetScript("OnClick", function() dimmer:Hide() end)

	dimmer:SetScript("OnMouseDown", function()
		if not popup:IsMouseOver() then
			dimmer:Hide()
		end
	end)
	popup.eb = eb
	popup.scroll = scroll
	dimmer.popup = popup
	return dimmer
end

function ECHAT.ShowCopyPopup(cf)
	local text = ECHAT.ReadChatText and ECHAT.ReadChatText(cf) or ""
	if text == "" then
		text = "(No chat history)"
	end
	if not copyDimmer then
		copyDimmer = BuildCopyPopup()
	end
	local popup = copyDimmer.popup
	P.SetFont(popup.eb, ECHAT.GetFont(), 12, ECHAT.GetOutlineFlag())
	popup.eb.readOnly = nil
	popup.eb:SetText(text)
	popup.eb.readOnly = text
	copyDimmer:Show()
	P.After(0.05, function()
		popup.eb:SetFocus()
		popup.eb:SetCursorPosition(#text)
		popup.eb:HighlightText()
		popup.scroll:UpdateScrollChildRect()
		popup.scroll:SetVerticalScroll(popup.scroll:GetVerticalScrollRange() or 0)
	end)
end

-------------------------------------------------------------------------------
--  URL copy popup (a clicked URL in chat)
-------------------------------------------------------------------------------
local urlBackdrop, urlPopup

local function HideUrlPopup()
	if urlPopup then
		urlPopup:Hide()
	end
	if urlBackdrop then
		urlBackdrop:Hide()
	end
end

local function FadeIn(frame)
	frame.fade = 0
	frame:SetAlpha(0)
	frame:SetScript("OnUpdate", function(self, elapsed)
		self.fade = self.fade + elapsed
		local a = min(1, self.fade / 0.2)
		self:SetAlpha(a)
		if a >= 1 then
			self:SetScript("OnUpdate", nil)
		end
	end)
end

function ECHAT.ShowUrlPopup(url)
	if not urlPopup then
		urlBackdrop = CreateFrame("Button", nil, UIParent)
		urlBackdrop:SetFrameStrata("DIALOG")
		urlBackdrop:SetFrameLevel(99)
		urlBackdrop:SetAllPoints(UIParent)
		local t = urlBackdrop:CreateTexture(nil, "BACKGROUND")
		t:SetAllPoints()
		t:SetTexture(0, 0, 0, 0.10)
		urlBackdrop:RegisterForClicks("AnyUp")
		urlBackdrop:SetScript("OnClick", HideUrlPopup)
		urlBackdrop:Hide()

		urlPopup = CreateFrame("Frame", "EllesmereUIChatUrlFrame", UIParent)
		urlPopup:SetFrameStrata("DIALOG")
		urlPopup:SetFrameLevel(100)
		urlPopup:SetSize(340, 52)
		urlPopup:EnableMouse(true)
		urlPopup:SetClampedToScreen(true)
		local bg = urlPopup:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetTexture(0.077, 0.068, 0.058, 0.97)
		P.LayoutEdges(P.CreateEdges(urlPopup, urlPopup, "OVERLAY", 7), P.PixelFor(urlPopup), 1, 1, 1, 0.15)
		local hint = P.NewText(urlPopup, "OVERLAY", 8)
		hint:SetTextColor(1, 1, 1, 0.5)
		hint:SetPoint("TOP", urlPopup, "TOP", 0, -6)
		hint:SetText("Ctrl+C to copy, Escape to close")
		local eb = CreateFrame("EditBox", nil, urlPopup)
		eb:SetSize(300, 16)
		eb:SetPoint("TOP", hint, "BOTTOM", 0, -4)
		P.SetFont(eb, ECHAT.GetFont(), 11, "")
		eb:SetAutoFocus(false)
		eb:SetJustifyH("CENTER")
		local ebBg = eb:CreateTexture(nil, "BACKGROUND")
		ebBg:SetTexture(0.112, 0.105, 0.098, 1)
		ebBg:SetPoint("TOPLEFT", -6, 4)
		ebBg:SetPoint("BOTTOMRIGHT", 6, -4)
		eb:SetScript("OnEscapePressed", function(self)
			self:ClearFocus()
			HideUrlPopup()
		end)
		eb:SetScript("OnKeyDown", function(self, key)
			if key == "C" and IsControlKeyDown() then
				P.After(0.05, HideUrlPopup)
			end
		end)
		eb:SetScript("OnTextChanged", function(self)
			if self.url and self:GetText() ~= self.url then
				self:SetText(self.url)
				self:HighlightText()
			end
		end)
		eb:SetScript("OnMouseUp", function(self) self:HighlightText() end)
		urlPopup:SetScript("OnMouseDown", function()
			urlPopup.eb:SetFocus()
			urlPopup.eb:HighlightText()
		end)
		urlPopup.eb = eb
		tinsert(UISpecialFrames, "EllesmereUIChatUrlFrame")
		urlPopup:SetScript("OnHide", function() urlBackdrop:Hide() end)
	end
	urlPopup.eb.url = nil
	urlPopup.eb:SetText(url)
	urlPopup.eb.url = url
	urlPopup:ClearAllPoints()
	local cx, cy = GetCursorPosition()
	local s = UIParent:GetEffectiveScale()
	urlPopup:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", cx / s, cy / s + 10)
	urlBackdrop:Show()
	FadeIn(urlBackdrop)
	urlPopup:Show()
	FadeIn(urlPopup)
	urlPopup.eb:SetFocus()
	urlPopup.eb:HighlightText()
end

-------------------------------------------------------------------------------
--  Unlock Mode: the main chat window (EllesmereUI core Unlock Mode, retail
--  ECHAT_MainChat). Blizzard keeps its saved position (FCF), so the element
--  places itself (ownsPosition) and the core never re-applies it at login.
-------------------------------------------------------------------------------
-- The spot is also kept in our own DB (profile.chatPos, BOTTOMLEFT offsets in
-- UIParent units, like retail's chat position key): Blizzard's chat-cache
-- copy did not survive a /reload, so it is re-applied after Blizzard
-- restores the window (FCF_RestorePositionAndDimensions) and at login.
local function SavedChatPos()
	local p = ECHAT.db and ECHAT.db.profile
	return p and p.chatPos
end

-- l, b: the window's BOTTOMLEFT in its own units (read live when omitted).
local function StoreChatPos(l, b)
	local p = ECHAT.db and ECHAT.db.profile
	local cf = ChatFrame1
	if not l then
		l, b = cf:GetLeft(), cf:GetBottom()
	end
	if not p or not l or not b then
		return
	end
	local s = cf:GetEffectiveScale() / UIParent:GetEffectiveScale()
	p.chatPos = { x = floor(l * s + 0.5), y = floor(b * s + 0.5) }
end

local applyingChatPos
function ECHAT.ApplyChatPos()
	local pos = SavedChatPos()
	if not pos or applyingChatPos or InCombatLockdown() or ns._unlockActive then
		return
	end
	local cf = ChatFrame1
	local s = cf:GetEffectiveScale() / UIParent:GetEffectiveScale()
	if s <= 0 then
		return
	end
	local l, b = cf:GetLeft(), cf:GetBottom()
	if l and abs(l * s - pos.x) < 1 and abs(b * s - pos.y) < 1 then
		return
	end
	applyingChatPos = true
	cf:ClearAllPoints()
	cf:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", pos.x / s, pos.y / s)
	if cf:IsMovable() then
		cf:SetUserPlaced(true)
	end
	if FCF_SavePositionAndDimensions then
		FCF_SavePositionAndDimensions(cf)
	end
	applyingChatPos = nil
end

local chatPosHooked
local function HookChatPos()
	if chatPosHooked then
		return
	end
	chatPosHooked = true
	-- Blizzard restores its own copy on UPDATE_CHAT_WINDOWS: put ours back.
	if FCF_RestorePositionAndDimensions then
		hooksecurefunc("FCF_RestorePositionAndDimensions", function(cf)
			if cf == ChatFrame1 then
				ECHAT.ApplyChatPos()
			end
		end)
	end
	-- A Blizzard drag (unlocked chat) saves through here: remember it too.
	if FCF_SavePositionAndDimensions then
		hooksecurefunc("FCF_SavePositionAndDimensions", function(cf)
			if cf == ChatFrame1 and not applyingChatPos then
				StoreChatPos()
			end
		end)
	end
end

local function RegisterUnlock()
	HookChatPos()
	if not ns.RegisterUnlockElements then
		return
	end
	local function Place(x, y)
		local cf = ChatFrame1
		cf:ClearAllPoints()
		cf:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
		if cf:IsMovable() then
			cf:SetUserPlaced(true)
		end
		StoreChatPos(x, y)
		if FCF_SavePositionAndDimensions then
			applyingChatPos = true
			FCF_SavePositionAndDimensions(cf)
			applyingChatPos = nil
		end
	end
	-- The window's center as an offset from the screen center (UIParent units).
	local function CenterPos()
		local cf = ChatFrame1
		local cx, cy = cf:GetCenter()
		if not cx then
			return nil
		end
		local s = cf:GetEffectiveScale() / UIParent:GetEffectiveScale()
		local uw, uh = UIParent:GetSize()
		return { point = "CENTER", relPoint = "CENTER", x = cx * s - uw / 2, y = cy * s - uh / 2 }
	end
	ns:RegisterUnlockElements({
		ns.MakeUnlockElement({
			key = "ECHAT_MainChat",
			label = "Chat",
			group = "Chat",
			order = 600,
			noResize = true,
			ownsPosition = true,
			noInitHook = true,
			getFrame = function() return ChatFrame1 end,
			getSize = function()
				return ChatFrame1:GetWidth(), ChatFrame1:GetHeight()
			end,
			isHidden = function() return not P.started end,
			-- Saved through Blizzard (FCF), also while Unlock Mode commits.
			savePos = function(_, point, relPoint, x, y)
				if InCombatLockdown() then return end
				local cf = ChatFrame1
				local s = cf:GetEffectiveScale() / UIParent:GetEffectiveScale()
				local w, h = cf:GetWidth() * s, cf:GetHeight() * s
				local uw, uh = UIParent:GetSize()
				local left, bottom
				if point == "CENTER" and (relPoint or "CENTER") == "CENTER" then
					left, bottom = uw / 2 + x - w / 2, uh / 2 + y - h / 2
				else
					local l, b = cf:GetLeft(), cf:GetBottom()
					if not l then return end
					left, bottom = l * s, b * s
				end
				Place(floor(left / s + 0.5), floor(bottom / s + 0.5))
			end,
			loadPos = CenterPos,
			applyPos = function() end,
		}),
	}, "EllesmereUIChat")
end

-------------------------------------------------------------------------------
--  ElvUI: its own chat module skins the same frames; run one of them.
-------------------------------------------------------------------------------
function P.ElvUIChatActive()
	if not IsAddOnLoaded("ElvUI") then
		return false
	end
	local ok, E = pcall(function() return ElvUI and ElvUI[1] end)
	local private = ok and E and E.private
	if private and private.chat then
		return private.chat.enable ~= false
	end
	local db = ElvUIPrivateDB
	if type(db) ~= "table" then
		return true
	end
	local charKey = (UnitName("player") or "") .. " - " .. (GetRealmName() or "")
	local pkey = db.profileKeys and db.profileKeys[charKey] or charKey
	local prof = db.profiles and db.profiles[pkey]
	if prof and prof.chat and prof.chat.enable == false then
		return false
	end
	return true
end

function ECHAT.IsDisabledByElvUI()
	return P.disabledByElvUI and true or false
end

function ECHAT.IsRunning()
	return P.started and true or false
end

-------------------------------------------------------------------------------
--  Apply everything (settings changes, reset, UI scale)
-------------------------------------------------------------------------------
function ECHAT.RefreshAll()
	if not P.started then
		return
	end
	P.ForEachChatFrame(SkinChatFrame)
	ECHAT.ApplyFonts()
	ECHAT.ApplySidebarWidth()
	ECHAT.ApplySidebarVisibility()
	ECHAT.ApplySidebarBackground()
	ECHAT.ApplyIconColor()
	ECHAT.ApplySidebarIconScale()
	ECHAT.ApplyInputPosition()
	ECHAT.ApplyBackground()
	ECHAT.ApplyLockChatSize()
	if ECHAT.ApplyTextSettings then
		ECHAT.ApplyTextSettings()
	end
	if ECHAT.ApplyTabLayout then
		ECHAT.ApplyTabLayout()
	end
	ECHAT.RefreshVisibility()
	ECHAT.ResetIdleTimer()
end

function ECHAT.Reset()
	if ECHAT.db then
		ECHAT.db:ResetProfile()
	end
	if P.started then
		ECHAT.ApplyChatFontSize(GetFrameFontSize(1))
		DB().chatFontSize = nil
		ECHAT.SyncChatFontSize()
	end
	ECHAT.RefreshAll()
end

-------------------------------------------------------------------------------
--  Start (PLAYER_LOGIN)
-------------------------------------------------------------------------------
local function HideSocialButtons()
	for _, name in ipairs({ "ChatFrameMenuButton", "FriendsMicroButton" }) do
		local f = _G[name]
		if f then
			f:SetParent(P.hidden)
		end
	end
end

local function Start()
	if P.started then
		return
	end
	if P.ElvUIChatActive() then
		ns.Print("ElvUI's chat is on, so EllesmereUI Chat stays off. Turn off ElvUI > Chat > Enable to use it.")
		P.disabledByElvUI = true
		return
	end
	P.started = true
	local cfg = DB()
	BG_R, BG_G, BG_B, BG_A = cfg.bgR or BG_R, cfg.bgG or BG_G, cfg.bgB or BG_B, cfg.bgAlpha or BG_A

	if ns.SetCVarSafe then
		ns.SetCVarSafe("chatMouseScroll", 1)
	end
	P.ForEachChatFrame(SkinChatFrame)
	HideSocialButtons()
	BuildSidebar()

	hooksecurefunc("ChatEdit_UpdateHeader", OnUpdateHeader)
	if FCF_OpenTemporaryWindow then
		hooksecurefunc("FCF_OpenTemporaryWindow", function()
			P.ForEachChatFrame(SkinChatFrame)
			ECHAT.RefreshAll()
		end)
	end
	if FCF_OpenNewWindow then
		hooksecurefunc("FCF_OpenNewWindow", function()
			P.ForEachChatFrame(SkinChatFrame)
			ECHAT.RefreshAll()
		end)
	end
	if FCF_SetLocked then
		hooksecurefunc("FCF_SetLocked", function()
			ECHAT.ApplyLockChatSize()
		end)
	end
	-- The tab menu's Font Size: mirrored into the profile, our face kept.
	if FCF_SetChatWindowFontSize then
		hooksecurefunc("FCF_SetChatWindowFontSize", function(_, chatFrame, fontSize)
			local size = fontSize
			if not size then
				local cf = chatFrame or (FCF_GetCurrentChatFrame and FCF_GetCurrentChatFrame())
				size = cf and GetFrameFontSize(cf:GetID())
			end
			if type(size) == "number" then
				DB().chatFontSize = size
			end
			ECHAT.ApplyFonts()
		end)
	end
	if IsAddOnLoaded("Blizzard_CombatLog") then
		SkinCombatLogBar()
	end

	ECHAT.RefreshAll()
	ECHAT.SyncChatFontSize()
	if ECHAT.RestoreHistory then
		ECHAT.RestoreHistory()
	end
	if ECHAT.AppendSharedMediaSounds then
		ECHAT.AppendSharedMediaSounds()
	end
	P.OnAccent(function()
		if P.started then
			ECHAT.ApplyBorders()
			ECHAT.ApplyIconColor()
		end
	end)
	hoverPoll:Show()

	-- Visibility checklist: re-evaluated on the state changes it reads.
	local vis = CreateFrame("Frame")
	for _, ev in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE",
		"ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_UPDATE_RESTING",
		"COMPANION_UPDATE", "UNIT_FACTION" }) do
		pcall(vis.RegisterEvent, vis, ev)
	end
	if vis.RegisterUnitEvent then
		pcall(vis.RegisterUnitEvent, vis, "UNIT_AURA", "player")
	end
	vis:SetScript("OnEvent", function() ECHAT.RefreshVisibility() end)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:RegisterEvent("UPDATE_CHAT_WINDOWS")
loader:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS")
loader:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == addonName then
			ECHAT.InitDB()
			ns.applyHooks = ns.applyHooks or {}
			tinsert(ns.applyHooks, function() ECHAT.RefreshAll() end)
			RegisterUnlock()
		elseif arg1 == "Blizzard_CombatLog" and P.started then
			SkinCombatLogBar()
		end
	elseif event == "PLAYER_LOGIN" then
		Start()
	elseif P.started then
		-- Blizzard re-applies window settings (fonts, dock) on these.
		P.After(0, function()
			ECHAT.RefreshAll()
			ECHAT.ApplyChatPos()
		end)
	end
end)
