-------------------------------------------------------------------------------
--  EllesmereUIBlizzardSkin.lua (5.4.8 port)
--  Base of the Blizzard Skins+ addon: saved settings, per-window style,
--  timers and pixel borders that every skin file of this addon uses.
--  Retail keeps these settings in EllesmereUIDB; this port keeps them in
--  EllesmereUIBlizzardSkinDB (same key names).
--
--  Every file of this addon starts with:
--      local addonName = ...
--      local ns = EllesmereUI
--      local BS = ns.BlizzSkin
-------------------------------------------------------------------------------
local addonName = ...
local ns = EllesmereUI

local BS = {}
ns.BlizzSkin = BS
BS.ADDON = addonName
BS.MEDIA = "Interface\\AddOns\\" .. addonName .. "\\media\\"
BS.WHITE = "Interface\\Buttons\\WHITE8X8"

local floor, max = math.floor, math.max

-------------------------------------------------------------------------------
--  Saved settings. BS.DB() is the root table (EllesmereUIBlizzardSkinDB).
--  The character sheet keeps its own sub table (charSheet).
-------------------------------------------------------------------------------
function BS.DB()
	local db = EllesmereUIBlizzardSkinDB
	if type(db) ~= "table" then
		db = {}
		EllesmereUIBlizzardSkinDB = db
	end
	return db
end

-- Files register defaults for root keys here; BS.Get returns the default
-- while a key is unset (nil), like retail's "nil = default" keys.
BS.defaults = {}
function BS.Get(key)
	local v = BS.DB()[key]
	if v == nil then
		v = BS.defaults[key]
	end
	return v
end
function BS.Set(key, value)
	BS.DB()[key] = value
end

-------------------------------------------------------------------------------
--  Per-window skin style: "eui" | "modern" | "off" (nil = "eui").
--  EllesmereUIBlizzardSkinDB.blizzWindowSkinStyles[winKey]. The character
--  sheet keeps its own style (charSheet.style); the inspect sheet follows it.
-------------------------------------------------------------------------------
function BS.GetWindowStyle(winKey)
	if winKey == "charsheet" or winKey == "inspect" then
		local cs = ns.GetCharSheetDB and ns.GetCharSheetDB()
		local s = cs and cs.style or "eui"
		if s == "blizzard" then
			return "off"
		end
		return s
	end
	local styles = BS.DB().blizzWindowSkinStyles
	local s = type(styles) == "table" and styles[winKey]
	if s == "modern" or s == "off" then
		return s
	end
	return "eui"
end
-- Retail name, used by the window engine and the skin files.
ns.GetBlizzWindowStyle = BS.GetWindowStyle

function BS.SetWindowStyle(winKey, style)
	local db = BS.DB()
	if type(db.blizzWindowSkinStyles) ~= "table" then
		db.blizzWindowSkinStyles = {}
	end
	if style == "eui" then
		style = nil
	end
	db.blizzWindowSkinStyles[winKey] = style
end

-------------------------------------------------------------------------------
--  ElvUI. With ElvUI's own skin on for a frame, our skin for it stands down
--  (two skins on one frame fight). elvKey = E.private.skins.blizzard[elvKey].
-------------------------------------------------------------------------------
function BS.ElvUISkins(elvKey)
	local E = ElvUI and ElvUI[1]
	if not E or not E.private or not E.private.skins then
		return false
	end
	local b = E.private.skins.blizzard
	if not b or not b.enable then
		return false
	end
	if elvKey == nil then
		return true
	end
	return b[elvKey] and true or false
end

-------------------------------------------------------------------------------
--  Timers (5.4.8 has no C_Timer): BS.After(seconds, fn), BS.NewTicker.
-------------------------------------------------------------------------------
local timerFrame = CreateFrame("Frame")
local timers = {}
local function TimerUpdate(self, elapsed)
	local now = GetTime()
	local i = 1
	while i <= #timers do
		local t = timers[i]
		if t.cancelled then
			table.remove(timers, i)
		elseif now >= t.at then
			if t.every then
				t.at = now + t.every
				i = i + 1
			else
				table.remove(timers, i)
			end
			local ok, err = pcall(t.fn, t)
			if not ok then
				geterrorhandler()(err)
			end
		else
			i = i + 1
		end
	end
	if #timers == 0 then
		self:SetScript("OnUpdate", nil)
	end
end
local function AddTimer(t)
	timers[#timers + 1] = t
	timerFrame:SetScript("OnUpdate", TimerUpdate)
	return t
end
local TimerMethods = {}
TimerMethods.__index = TimerMethods
function TimerMethods:Cancel()
	self.cancelled = true
end
function TimerMethods:IsCancelled()
	return self.cancelled and true or false
end
function BS.After(seconds, fn)
	return AddTimer(setmetatable({ at = GetTime() + (seconds or 0), fn = fn }, TimerMethods))
end
function BS.NewTimer(seconds, fn)
	return BS.After(seconds, fn)
end
function BS.NewTicker(seconds, fn)
	return AddTimer(setmetatable({ at = GetTime() + seconds, every = seconds, fn = fn }, TimerMethods))
end

-------------------------------------------------------------------------------
--  Pixel-perfect borders (retail PP.CreateBorder): 4 textures, 1 physical
--  pixel thick at any UI scale. Returns the border container frame.
-------------------------------------------------------------------------------
local PP = {}
BS.PP = PP
local function Perfect()
	local ph = (ns.PhysicalHeight and ns.PhysicalHeight()) or 1080
	return 768 / ph
end
function PP.UpdateMult()
	PP.perfect = Perfect()
	PP.mult = PP.perfect / (UIParent:GetScale() or 1)
end
PP.UpdateMult()

local borders = setmetatable({}, { __mode = "k" })
local function SnapBorder(c, frame, size)
	local es = c:GetEffectiveScale()
	if not es or es <= 0 then
		return
	end
	local px = (PP.perfect or Perfect()) / es
	local edge = max(px, floor((size or 1) + 0.5) * px)
	c._top:ClearAllPoints()
	c._top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	c._top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	c._top:SetHeight(edge)
	c._bottom:ClearAllPoints()
	c._bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	c._bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	c._bottom:SetHeight(edge)
	c._left:ClearAllPoints()
	c._left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -edge)
	c._left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, edge)
	c._left:SetWidth(edge)
	c._right:ClearAllPoints()
	c._right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -edge)
	c._right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, edge)
	c._right:SetWidth(edge)
end

function PP.CreateBorder(frame, r, g, b, a, size, layer, subLevel)
	local bd = borders[frame]
	if bd then
		return bd.container
	end
	local c = CreateFrame("Frame", nil, frame)
	c:SetAllPoints(frame)
	c:SetFrameLevel(frame:GetFrameLevel() + 1)
	local function T()
		local t = c:CreateTexture(nil, layer or "OVERLAY", nil, subLevel or 0)
		t:SetTexture(BS.WHITE)
		t:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
		return t
	end
	c._top, c._bottom, c._left, c._right = T(), T(), T(), T()
	bd = { container = c, size = size or 1 }
	borders[frame] = bd
	SnapBorder(c, frame, bd.size)
	-- The effective scale is final one frame after creation.
	local ticks = 0
	c:SetScript("OnUpdate", function(self)
		ticks = ticks + 1
		SnapBorder(self, frame, bd.size)
		if ticks >= 2 then
			self:SetScript("OnUpdate", nil)
		end
	end)
	c:SetScript("OnSizeChanged", function(self)
		SnapBorder(self, frame, bd.size)
	end)
	return c
end

function PP.SetBorderColor(frame, r, g, b, a)
	local bd = borders[frame]
	if not bd then
		return
	end
	local c = bd.container
	c._top:SetVertexColor(r, g, b, a or 1)
	c._bottom:SetVertexColor(r, g, b, a or 1)
	c._left:SetVertexColor(r, g, b, a or 1)
	c._right:SetVertexColor(r, g, b, a or 1)
end

function PP.SetBorderSize(frame, size)
	local bd = borders[frame]
	if not bd then
		return
	end
	bd.size = size or 1
	SnapBorder(bd.container, frame, bd.size)
end

function PP.GetBorder(frame)
	local bd = borders[frame]
	return bd and bd.container
end

-- Re-snap every border after a UI scale change.
function PP.RefreshAll()
	PP.UpdateMult()
	for frame, bd in pairs(borders) do
		SnapBorder(bd.container, frame, bd.size)
	end
end

-------------------------------------------------------------------------------
--  Small helpers
-------------------------------------------------------------------------------
-- 5.4.8 has no IsForbidden (frames are never forbidden there).
function BS.Forbidden(frame)
	return frame and frame.IsForbidden and frame:IsForbidden() or false
end

-- Solid color texture (retail SetColorTexture).
function BS.SolidTex(parent, layer, r, g, b, a, sublevel)
	local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)
	t:SetTexture(r or 0, g or 0, b or 0, a or 1)
	return t
end

-- Accent color (EllesmereUI green, or the user's accent).
function BS.Accent()
	if ns.ResolveAccent then
		local r, g, b = ns.ResolveAccent()
		if r then
			return r, g, b
		end
	end
	return 12 / 255, 210 / 255, 157 / 255
end

-- Live accent table, like retail EllesmereUI.ELLESMERE_GREEN.
BS.ACCENT = { r = 12 / 255, g = 210 / 255, b = 157 / 255 }
local accentCallbacks = {}
function BS.OnAccentChanged(fn)
	accentCallbacks[#accentCallbacks + 1] = fn
end
local function RefreshAccent()
	local r, g, b = BS.Accent()
	BS.ACCENT.r, BS.ACCENT.g, BS.ACCENT.b = r, g, b
	for i = 1, #accentCallbacks do
		pcall(accentCallbacks[i], r, g, b)
	end
end
ns.accentListeners = ns.accentListeners or {}
table.insert(ns.accentListeners, function()
	RefreshAccent()
end)

-- Font of the Blizzard Skins module (Global Settings > Fonts).
function BS.FontPath()
	return (ns.GetFontPath and ns.GetFontPath("blizzardSkin")) or ns.FONT or STANDARD_TEXT_FONT
end
function BS.FontFlag()
	return (ns.GetFontOutlineFlag and ns.GetFontOutlineFlag("blizzardSkin")) or ""
end
function BS.SetFont(fs, size, flags)
	if not fs or not fs.SetFont then
		return
	end
	if ns.ApplyModuleFont then
		ns.ApplyModuleFont(fs, size, "blizzardSkin", flags)
	else
		fs:SetFont(BS.FontPath(), size, flags or BS.FontFlag())
	end
end

-------------------------------------------------------------------------------
--  Apply callbacks: every skin file adds a function that re-applies its live
--  settings; settings changes and UI scale changes run them all.
-------------------------------------------------------------------------------
local applyCallbacks = {}
function BS.OnApply(fn)
	applyCallbacks[#applyCallbacks + 1] = fn
end
function BS.ApplyAll()
	RefreshAccent()
	PP.RefreshAll()
	for i = 1, #applyCallbacks do
		local ok, err = pcall(applyCallbacks[i])
		if not ok then
			geterrorhandler()(err)
		end
	end
end
ns.applyHooks = ns.applyHooks or {}
table.insert(ns.applyHooks, function()
	BS.ApplyAll()
end)

-- Login callbacks: run once at PLAYER_LOGIN, after every file loaded and the
-- saved settings are in.
local loginCallbacks = {}
function BS.OnLogin(fn)
	if IsLoggedIn and IsLoggedIn() then
		local ok, err = pcall(fn)
		if not ok then
			geterrorhandler()(err)
		end
		return
	end
	loginCallbacks[#loginCallbacks + 1] = fn
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self, event, name)
	if event == "ADDON_LOADED" then
		if name == addonName then
			BS.DB()
		end
		return
	end
	self:UnregisterEvent("PLAYER_LOGIN")
	RefreshAccent()
	PP.UpdateMult()
	for i = 1, #loginCallbacks do
		local ok, err = pcall(loginCallbacks[i])
		if not ok then
			geterrorhandler()(err)
		end
	end
end)

-- Reload popup for settings that apply at load (a window turned on or off).
StaticPopupDialogs["EUI_BLIZZSKIN_RELOAD"] = {
	text = "EllesmereUI: this change needs a UI reload.",
	button1 = RELOADUI or "Reload UI",
	button2 = LATER or "Later",
	OnAccept = function()
		ReloadUI()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}
function BS.AskReload()
	StaticPopup_Show("EUI_BLIZZSKIN_RELOAD")
end
