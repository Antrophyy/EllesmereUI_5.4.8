-------------------------------------------------------------------------------
--  EllesmereUIMinimap.lua  (5.4.8 port of the EllesmereUI Minimap, retail 9.3.8)
--
--  The defaults (same keys and values as retail), the saved settings
--  (EllesmereUIMinimapDB.profile.minimap, like the retail profile), the
--  first-run seed with the retail "Naowh" profile, and the helpers the other
--  files share: timers (5.4.8 has no C_Timer), pixel borders, the EllesmereUI
--  widget tooltip, accent color and the Visibility checklist.
--
--  Files: this one, EUI_Minimap_Buttons.lua (addon button group, free move,
--  element row, extra buttons, custom tooltips) and EUI_Minimap_Map.lua (map
--  shape, border, Blizzard parts, text, visibility, micro menu, Unlock Mode).
--
--  Not in 5.4.8, left out: Blizzard / Classic stock styles, textured border
--  styles, Textured Circle shape, Icon Size (no SetIconScale), Great Vault,
--  M+ Portals, Crafting Orders, Omnium Folio (expansion landing page), Addon
--  Compartment, housing map, BNet favorites. The 5.4.8 queue eye (Queue
--  Status) takes the Omnium Folio's place: pinned to a map corner.
-------------------------------------------------------------------------------
local addonName, P = ...
local ns = EllesmereUI

local EMM = {}
ns.EMM = EMM
P.EMM = EMM
P.ns = ns

local floor, abs, max, min = math.floor, math.abs, math.max, math.min

P.MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"
P.WHITE = "Interface\\Buttons\\WHITE8X8"
P.BG = "Interface\\ChatFrame\\ChatFrameBackground"

-------------------------------------------------------------------------------
--  Defaults (EllesmereUI 9.3.8 Minimap defaults, same keys)
-------------------------------------------------------------------------------
local defaults = {
	profile = {
		minimap = {
			enabled = true,
			shape = "square",
			rotateMinimap = false,
			borderSize = 1,
			showCoords = false,
			coordPrecision = 0,
			coordsMode = "always",
			coordsPosition = "topLeft",
			coordsScale = 1.0,
			showFPS = false,
			fpsTextSize = 12,
			fpsScale = 1.0,
			fpsShowLocalMS = true,
			fpsShowWorldMS = false,
			fpsUseAccent = false,
			fpsColorClockAMPM = false,
			fpsPosition = "bottomLeft",
			fpsOffsetX = 0,
			fpsOffsetY = 0,
			fpsHoverTooltip = "none",
			fpsUpdateInterval = 3,
			clockHoverTooltip = "none",
			diffTextEnabled = false,
			diffTextPosition = "topLeft",
			diffTextSize = 12,
			diffTextOffsetX = 0,
			diffTextOffsetY = 0,
			fpsColorSuffix = true,
			diffTextAccent = false,
			diffTextReactive = false,
			borderR = 0, borderG = 0, borderB = 0, borderA = 1,
			useClassColor = false,
			locationMode = "inside",
			locationPosition = "bottom",
			zoneReactiveColor = false,
			zoneShowSubZone = false,
			scrollZoom = true,
			openMicroMenuOnMiddleClick = true,
			savedZoom = 0,
			zoomResetSeconds = 0,
			hideZoomButtons = false,
			hideTrackingButton = false,
			hideGameTime = false,
			hideMail = false,
			mailPosition = "button",
			mailOffsetX = 0,
			mailOffsetY = 0,
			hideRaidDifficulty = false,
			friendsMaxRows = 0,
			friendsShowNotes = false,
			hideExtraBtns = { friendsOnline = false, groupButton = false },
			mouseoverExtraBtns = false,
			-- 5.4.8 queue eye (QueueStatusMinimapButton): never | hover | always,
			-- pinned to a map corner like retail's Omnium Folio.
			queueStatusMode = "always",
			queueStatusCorner = "BOTTOMLEFT",
			queueStatusX = 0,
			queueStatusY = 0,
			queueStatusScale = 0.8,
			hideAddonButtons = false,
			addonBtnSize = 24,
			interactableBtnSize = 21,
			ungroupedButtons = {},
			freeMoveBtns = false,
			btnBackgrounds = true,
			btnPositions = {},
			btnRowPosition = "blUp",
			btnRowSpacing = 0,
			btnRowDistance = 0,
			flyoutGrowDir = "auto",
			elementRowPosition = "tlDown",
			elementRowSpacing = 0,
			elementRowDistance = 0,
			customTooltipScale = 1.0,
			clockMode = "inside",
			clockPosition = "top",
			clockFormat = "12h",
			clockScale = 1.15,
			clockOffsetX = 0,
			clockOffsetY = 0,
			locationScale = 1.15,
			locationOffsetX = 0,
			locationOffsetY = 0,
			lock = false,
			visibility = "always",
			opacity = 100,
			visOnlyInstances = false,
			visHideMounted = false,
			visHideNoTarget = false,
			visHideNoEnemy = false,
		},
	},
}
EMM.defaults = defaults

-------------------------------------------------------------------------------
--  First run: the retail EllesmereUI "Naowh" profile (EllesmereUIDB.profiles.
--  Naowh.addons.EllesmereUIMinimap.minimap on the retail client; retail keeps
--  only the values that differ from the defaults). Retail-only keys are left out.
-------------------------------------------------------------------------------
local NAOWH_SEED = {
	mailPosition = "TOPLEFT",
	mailOffsetY = 20,
	interactableBtnSize = 28,
	mouseoverExtraBtns = true,
	fpsColorSuffix = false,
	fpsColorClockAMPM = true,
	fpsColor = { r = 0, g = 0.81176470588235, b = 1 },
	customTooltipScale = 1.2,
	diffTextEnabled = true,
	diffTextSize = 14,
	diffTextPosition = "topRight",
	diffTextOffsetX = 2,
	diffTextAccent = true,
	mapSize = 255,
	clockMode = "none",
	clockOffsetY = 1,
	clockScale = 1.4,
	hideGameTime = true,
	locationOffsetY = -8,
	locationScale = 1.4,
	zoneInside = true,
	coordsMode = "hover",
	coordsPosition = "bottom",
	coordsScale = 1.4,
	coordsBelow = false,
	coordsBelowOffsetY = 2,
	btnRowDistance = 1,
	position = { point = "CENTER", relPoint = "CENTER", x = 1150.5003662109, y = 590.50018305331 },
	_capturedOnce = true,
}
EMM.NAOWH_SEED = NAOWH_SEED

-------------------------------------------------------------------------------
--  Saved settings
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
	local profile = DeepCopy(defaults.profile)
	if seed then
		for k, v in pairs(seed) do
			profile.minimap[k] = DeepCopy(v)
		end
		profile.seeded = "Naowh"
	end
	return profile
end

function EMM:InitDB()
	if type(EllesmereUIMinimapDB) ~= "table" then
		EllesmereUIMinimapDB = {}
	end
	local sv = EllesmereUIMinimapDB
	if type(sv.profile) ~= "table" then
		sv.profile = NewProfile(NAOWH_SEED)
	else
		ns.CopyDefaults(defaults.profile, sv.profile)
	end
	sv.version = 1
	self.db = {
		sv = sv,
		profile = sv.profile,
		ResetProfile = function(db)
			db.sv.profile = NewProfile(nil)
			db.profile = db.sv.profile
		end,
	}
end

-- The minimap table of the profile (retail EBS.db.profile.minimap).
function P.DB()
	return EMM.db and EMM.db.profile and EMM.db.profile.minimap
end
EMM.DB = P.DB

-------------------------------------------------------------------------------
--  Timers (5.4.8 has no C_Timer): After, NewTimer, NewTicker (handles with
--  :Cancel()), all on one OnUpdate.
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

-- Run after combat (protected work requested in combat), keyed.
do
	local pending = {}
	local f = CreateFrame("Frame")
	f:RegisterEvent("PLAYER_REGEN_ENABLED")
	f:SetScript("OnEvent", function()
		local list = pending
		pending = {}
		for _, fn in pairs(list) do
			fn()
		end
	end)
	function P.AfterCombat(key, fn)
		pending[key] = fn
	end
end

-------------------------------------------------------------------------------
--  Pixels and borders
-------------------------------------------------------------------------------
-- One physical pixel in the units of `frame`.
function P.PixelFor(frame)
	local h = ns.PhysicalHeight and ns.PhysicalHeight() or 1080
	return 768 / h / ((frame and frame:GetEffectiveScale()) or UIParent:GetEffectiveScale())
end

function P.Snap(v, frame)
	local px = P.PixelFor(frame)
	return floor(v / px + 0.5) * px
end

-- Four edge textures (the EllesmereUI "solid" pixel border).
function P.CreateEdges(parent, host, layer, sub)
	local e = { host = host or parent }
	for i = 1, 4 do
		e[i] = parent:CreateTexture(nil, layer or "OVERLAY", nil, sub or 2)
		e[i]:SetTexture(1, 1, 1, 1)
	end
	return e
end

-- size in the host's units; outside = drawn around the host instead of inside.
function P.LayoutEdges(e, size, r, g, b, a, outside)
	local host = e.host
	if not size or size <= 0 then
		for i = 1, 4 do e[i]:Hide() end
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
		e[i]:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
		e[i]:Show()
	end
end

function P.ColorEdges(e, r, g, b, a)
	for i = 1, 4 do
		e[i]:SetVertexColor(r, g, b, a or 1)
	end
end

-- Flat panel: background + 1 px border (EllesmereUI MakeBorder look).
function P.Panel(frame, r, g, b, a, br, bg, bb, ba)
	local tex = frame:CreateTexture(nil, "BACKGROUND")
	tex:SetAllPoints()
	tex:SetTexture(r, g, b, a)
	frame._panelBg = tex
	local e = P.CreateEdges(frame, frame, "BORDER", 0)
	P.LayoutEdges(e, P.PixelFor(frame), br or 1, bg or 1, bb or 1, ba or 0.15)
	frame._panelEdges = e
	return tex, e
end

-- Black box behind a button (retail BackdropTemplate bgFile box).
function P.BlackBox(btn, alpha)
	local box = CreateFrame("Frame", nil, btn)
	box:SetAllPoints(btn)
	box:SetFrameLevel(max(0, btn:GetFrameLevel() - 1))
	local tex = box:CreateTexture(nil, "BACKGROUND")
	tex:SetAllPoints()
	tex:SetTexture(0, 0, 0, alpha or 0.8)
	box.tex = tex
	return box
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

-- Callbacks run with r, g, b when the UI accent changes.
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

-- For the settings swatches.
EMM.AccentColor = function()
	return P.Accent()
end
EMM.ClassColor = function()
	local r, g, b = P.ClassColor()
	return r, g, b, 1
end

function P.Hex(r, g, b)
	return format("%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

-------------------------------------------------------------------------------
--  Fonts (Global Settings > Fonts, module key "minimap")
-------------------------------------------------------------------------------
function P.FontPath()
	return (ns.GetFontPath and ns.GetFontPath("minimap")) or ns.FONT or "Fonts\\FRIZQT__.TTF"
end

-- Module text (clock, zone, coordinates, FPS): the module outline or a shadow.
function P.SetFont(fs, size)
	if ns.ApplyModuleFont then
		ns.ApplyModuleFont(fs, size, "minimap")
	else
		fs:SetFont(P.FontPath(), size, "")
	end
end

-- Plain font (retail tooltips: no outline, no shadow).
function P.SetPlainFont(fs, size, flags)
	fs:SetFont(P.FontPath(), size, flags or "")
	if not fs:GetFont() then
		fs:SetFont("Fonts\\ARIALN.TTF", size, flags or "")
	end
end

-- New FontString with a font already set: 5.4.8 errors on SetText without
-- one. Callers set their real font and size afterwards.
function P.NewText(parent, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	P.SetPlainFont(fs, 10)
	return fs
end

-------------------------------------------------------------------------------
--  Widget tooltip (EllesmereUI.ShowWidgetTooltip): dark box, 1 px border,
--  white text, opened to a side of the owner. opts.anchor = "left" | "right" |
--  "above" | "below"; opts.scale.
-------------------------------------------------------------------------------
local tip, tipMeasure
function P.ShowTip(owner, text, opts)
	if not owner or not text or text == "" then
		return
	end
	opts = opts or {}
	if not tip then
		tip = CreateFrame("Frame", nil, UIParent)
		tip:SetFrameStrata("TOOLTIP")
		tip:SetFrameLevel(250)
		tip:SetClampedToScreen(true)
		P.Panel(tip, 0.067, 0.067, 0.067, 0.94, 1, 1, 1, 0.15)
		tip.text = P.NewText(tip)
		tip.text:SetPoint("TOPLEFT", 9, -7)
		tip.text:SetJustifyH("LEFT")
		tip.text:SetSpacing(2)
		tipMeasure = P.NewText(tip)
		tipMeasure:Hide()
		tip:SetScript("OnUpdate", function(self, elapsed)
			if self.fade then
				self.fade = self.fade + elapsed
				local a = min(1, self.fade / 0.15)
				self:SetAlpha(a)
				if a >= 1 then
					self.fade = nil
				end
			end
		end)
	end
	P.SetPlainFont(tip.text, 12)
	P.SetPlainFont(tipMeasure, 12)
	tip.text:SetTextColor(1, 1, 1, 0.85)
	tip.text:SetText(text)
	-- Widest line (multi-line text measures per line).
	local w = 0
	for line in (text .. "\n"):gmatch("(.-)\n") do
		tipMeasure:SetText(line)
		w = max(w, tipMeasure:GetStringWidth() or 0)
	end
	tip.text:SetWidth(w + 2)
	tip:SetSize(w + 20, (tip.text:GetStringHeight() or 12) + 14)
	tip:SetScale(opts.scale or 1)
	tip:ClearAllPoints()
	local side = opts.anchor or "above"
	if side == "left" then
		tip:SetPoint("RIGHT", owner, "LEFT", -4, 0)
	elseif side == "right" then
		tip:SetPoint("LEFT", owner, "RIGHT", 4, 0)
	elseif side == "below" then
		tip:SetPoint("TOP", owner, "BOTTOM", 0, -4)
	else
		tip:SetPoint("BOTTOM", owner, "TOP", 0, 4)
	end
	tip:SetAlpha(0)
	tip.fade = 0
	tip:Show()
end

function P.HideTip()
	if tip then
		tip:Hide()
	end
end

-------------------------------------------------------------------------------
--  Visibility checklist (retail EvalVisibility / BuildVisibilityRow on the
--  "visibility" key): Never / Always / Mouseover base, Match All / Any, Show /
--  Hide lanes. The same lane keys as the Action Bars port. Evaluated in Lua:
--  the minimap is not a protected frame.
-------------------------------------------------------------------------------
local function InCombat()
	return (InCombatLockdown() or UnitAffectingCombat("player")) and true or false
end

EMM.VIS_AXES = {
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

function EMM.VisFlag(s, key)
	if key:match("^vis") then
		return s[key] and true or false
	end
	local modes = s.visibilityModes
	if modes and modes[key] then
		return true
	end
	-- Legacy scalar modes (retail visibility = "in_combat" ...) read as their Show lane.
	local vis = s.visibility
	if vis and vis ~= "always" and vis ~= "never" and vis ~= "mouseover" and vis == key then
		return true
	end
	return false
end

function EMM.SetVisFlag(s, key, on)
	if key:match("^vis") then
		s[key] = on and true or nil
		return
	end
	s.visibilityModes = s.visibilityModes or {}
	s.visibilityModes[key] = on and true or nil
end

function EMM.VisBase(s)
	local vis = s and s.visibility or "always"
	if vis == "never" then
		return "never"
	elseif vis == "mouseover" then
		return "mouseover"
	end
	return "always"
end

function EMM.SetVisBase(s, mode)
	local old = s.visibility
	if old and old ~= "always" and old ~= "never" and old ~= "mouseover" then
		EMM.SetVisFlag(s, old, true)
	end
	s.visibility = mode
end

-- true = shown, false = hidden, "mouseover" = shown while hovered.
function EMM.EvalVisibility(s)
	local base = EMM.VisBase(s)
	if base == "never" then
		return false
	end
	local anyShow, allOk, anyOk = false, true, false
	for _, axis in ipairs(EMM.VIS_AXES) do
		local hideOn = EMM.VisFlag(s, axis.hide)
		local showOn = EMM.VisFlag(s, axis.show)
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
	if base == "mouseover" then
		return "mouseover"
	end
	return true
end

-------------------------------------------------------------------------------
--  ElvUI: its own minimap module takes the same frames; run one of them.
-------------------------------------------------------------------------------
function P.ElvUIMinimapActive()
	if not IsAddOnLoaded("ElvUI") then
		return false
	end
	local ok, E = pcall(function() return ElvUI and ElvUI[1] end)
	local private = ok and E and E.private
	if private and private.general and private.general.minimap then
		return private.general.minimap.enable ~= false
	end
	local db = ElvUIPrivateDB
	if type(db) ~= "table" then
		return true
	end
	local charKey = (UnitName("player") or "") .. " - " .. (GetRealmName() or "")
	local pkey = db.profileKeys and db.profileKeys[charKey] or charKey
	local prof = db.profiles and db.profiles[pkey]
	if prof and prof.general and prof.general.minimap and prof.general.minimap.enable == false then
		return false
	end
	return true
end
