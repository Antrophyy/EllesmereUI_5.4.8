-------------------------------------------------------------------------------
--  EllesmereUIBlizzardSkin_Tooltips.lua (5.4.8 port)
--  Port of the retail "Tooltips, Menus & Popups" part of
--  EllesmereUIBlizzardSkin.lua:
--   - tooltip reskin (GameTooltip, ItemRef, shopping and world map tooltips),
--     fonts, health strip, tooltip extras (titles, item level, guild rank,
--     unit target, mount, player buffs, max stack, spell title accent)
--   - context menus (DropDownList1..N), static popups, resurrect glow
--   - LFG queue popup (+ countdown bar), ready status, role check popup
--   - game menu (GameMenuFrame)
--   - UberTooltips CVar, Anchor to Cursor, Fixed Position (Unlock Mode),
--     Growth Direction, Show Tooltips mode (+ peek modifier)
--
--  5.4.8 differences:
--   - Frames draw their art with SetBackdrop: the skin removes the backdrop
--     (or fades the backdrop holder frames) and draws its own flat color.
--   - No C_TooltipInfo / TooltipDataProcessor: OnTooltipSetUnit / Item / Spell.
--   - Item level of other players: computed from the inspect data (scan
--     tooltip), no C_PaperDollInfo.
--   - Mount: only mounts that you own can be detected (no mount journal by
--     spell in 5.4.8).
--   - Not in 5.4.8: Quick Keybind frame, premade group invite / application
--     dialogs (LFGList), M+ score, Blizzard Menu API, tooltip containers.
--   - ElvUI: its tooltip module (E.private.tooltip.enable) owns tooltips;
--     its misc skin owns menus, popups and the game menu; its lfg skin owns
--     the queue popups. Ours stands down there.
-------------------------------------------------------------------------------
local addonName = ...
local ns = EllesmereUI
local BS = ns.BlizzSkin
local WSkin = ns.WSkin

local PP = BS.PP
local GetFFD = WSkin.GetFFD
local Forbidden = BS.Forbidden
local WHITE = BS.WHITE
local floor, max, min, ceil = math.floor, math.max, math.min, math.ceil
local format = string.format

local TT = {}
BS.Tooltips = TT

-- Blizzard reskin colors (retail EllesmereUI.RESKIN).
local RESKIN = {
	BG_R = 0.067, BG_G = 0.067, BG_B = 0.067,
	TT_ALPHA = 0.92,  -- tooltip background alpha
	CTX_ALPHA = 0.95, -- context menu background alpha
	QT_ALPHA = 0.97,  -- popups background alpha
	BRD_ALPHA = 0.18, -- border alpha (white)
}
BS.RESKIN = RESKIN

-- Queue accept countdown defaults (retail EllesmereUI.QUEUE_TIMER).
local QT = {
	TEXT_R = 1, TEXT_G = 0.831, TEXT_B = 0,
	TEXT_SIZE = 9, BAR_HEIGHT = 11, TEXT_OFFSET_Y = 0,
}
BS.QUEUE_TIMER = QT

-- Defaults (unset key = this value).
local D = BS.defaults
D.customTooltips = true
D.reskinPopupsMenus = true
D.resurrectAcceptGlow = false
D.reskinQueuePopup = true
D.showQueueTimer = true
D.reskinGameMenu = true
D.tooltipFontScale = 1
D.tooltipAnchorCursor = false
D.tooltipCursorPosition = "top"
D.tooltipCursorOffsetX = 0
D.tooltipCursorOffsetY = 0
D.tooltipPlayerTitles = false
D.tooltipItemLevel = true
D.tooltipShowMount = false
D.tooltipShowGuildRank = false
D.tooltipShowTarget = false
D.tooltipHideHealthStrip = true
D.tooltipHealthStripHeight = 3
D.tooltipShowMode = "always"
D.tooltipShowModifier = "none"
D.tooltipGrowthDirection = "default"
D.showItemMaxStacks = false
D.itemStackModifier = "none"
D.tooltipShowBuffs = false
D.tooltipBuffPosition = "bottom"
D.tooltipBuffSize = 20
D.tooltipBuffsPerRow = 8
D.tooltipBuffOffsetX = 0
D.tooltipBuffOffsetY = 0

local Get = BS.Get
local function DB()
	return BS.DB()
end

-------------------------------------------------------------------------------
--  ElvUI
-------------------------------------------------------------------------------
-- ElvUI's tooltip module on (E.private.tooltip.enable, default on).
function TT.ElvUITooltipOn()
	if not IsAddOnLoaded("ElvUI") then
		return false
	end
	local ok, E = pcall(function() return ElvUI and ElvUI[1] end)
	local private = ok and E and E.private
	if private and private.tooltip then
		return private.tooltip.enable ~= false
	end
	local db = ElvUIPrivateDB
	if type(db) ~= "table" then
		return true
	end
	local charKey = (UnitName("player") or "") .. " - " .. (GetRealmName() or "")
	local pkey = db.profileKeys and db.profileKeys[charKey] or charKey
	local prof = db.profiles and db.profiles[pkey]
	if prof and prof.tooltip and prof.tooltip.enable == false then
		return false
	end
	return true
end
function TT.ElvUIMiscOn()
	return BS.ElvUISkins("misc")
end
function TT.ElvUILFGOn()
	return BS.ElvUISkins("lfg")
end

-- What is active this session (decided at login; the masters need a reload).
local ttActive, pmActive, queueActive, gmActive = false, false, false, false
function TT.TooltipActive()
	return ttActive
end

local function TooltipsWanted()
	return Get("customTooltips") ~= false and not TT.ElvUITooltipOn()
end

-------------------------------------------------------------------------------
--  Element & Text Color ("native" | "accent" | "custom" | "class").
--  Unset = native unless the legacy accentReskinElements key is on.
-------------------------------------------------------------------------------
local function ElementMode()
	local db = DB()
	local mode = db.popupMenuButtonTextColorMode
	if mode == nil then
		mode = db.accentReskinElements and "accent" or "native"
	end
	return mode
end
TT.ElementMode = ElementMode

local function ElementColor()
	local db = DB()
	local mode = ElementMode()
	if mode == "custom" then
		local c = db.popupMenuButtonTextColor or { r = 1, g = 1, b = 1 }
		return c.r or 1, c.g or 1, c.b or 1
	elseif mode == "class" then
		local _, class = UnitClass("player")
		local c = class and RAID_CLASS_COLORS[class]
		if c then
			return c.r, c.g, c.b
		end
	end
	return BS.Accent()
end
TT.ElementColor = ElementColor

local function AccentOn()
	return ElementMode() ~= "native"
end

-------------------------------------------------------------------------------
--  Configured borders (prefix = "tooltip" | "popupMenu" | "popupMenuButton").
--  <prefix>BorderThicknessPx (0-4, 0 = none), <prefix>BorderColorMode
--  ("custom" | "accent" | "class"), <prefix>BorderColor, <prefix>BorderOpacity,
--  <prefix>BorderBehind. 5.4.8 has solid borders only (no border textures).
-------------------------------------------------------------------------------
function TT.BorderSize(prefix)
	local db = DB()
	local size = db[prefix .. "BorderThicknessPx"]
	if type(size) ~= "number" then
		size = (prefix == "tooltip" and type(db.tooltipBorderSize) == "number" and db.tooltipBorderSize) or 1
	end
	return size
end

function TT.BorderColor(prefix)
	local db = DB()
	local mode = db[prefix .. "BorderColorMode"] or "custom"
	local r, g, b
	if mode == "accent" then
		r, g, b = BS.Accent()
	elseif mode == "class" then
		local _, class = UnitClass("player")
		local c = class and RAID_CLASS_COLORS[class]
		if c then
			r, g, b = c.r, c.g, c.b
		else
			r, g, b = 1, 1, 1
		end
	else
		local c = db[prefix .. "BorderColor"]
		r, g, b = (c and c.r) or 1, (c and c.g) or 1, (c and c.b) or 1
	end
	local a = db[prefix .. "BorderOpacity"]
	if a == nil then
		a = (mode == "custom") and RESKIN.BRD_ALPHA or 0.5
	end
	return r, g, b, a
end

local function ApplyBorder(owner, prefix)
	if not owner or Forbidden(owner) then
		return
	end
	local d = GetFFD(owner)
	local size = TT.BorderSize(prefix)
	local r, g, b, a = TT.BorderColor(prefix)
	local bf = d.configBorder
	if not bf then
		bf = CreateFrame("Frame", nil, owner)
		bf:SetAllPoints(owner)
		bf:EnableMouse(false)
		d.configBorder = bf
		d.configBorderC = PP.CreateBorder(bf, r, g, b, a, max(size, 1), "OVERLAY", 7)
	end
	local lvl = owner:GetFrameLevel() or 1
	bf:SetFrameLevel(DB()[prefix .. "BorderBehind"] and max(0, lvl - 1) or (lvl + 4))
	if d.configBorderC and d.configBorderC.SetFrameLevel then
		d.configBorderC:SetFrameLevel(bf:GetFrameLevel())
	end
	if size <= 0 then
		bf:Hide()
		return
	end
	bf:Show()
	PP.SetBorderColor(bf, r, g, b, a)
	PP.SetBorderSize(bf, size)
end
TT.ApplyBorder = ApplyBorder

-- Removes a frame's own backdrop (5.4.8 art). Visual only.
local function NoBackdrop(f)
	if f and f.GetBackdrop and f.SetBackdrop and f:GetBackdrop() then
		f:SetBackdrop(nil)
	end
end

local function FadeTextureRegions(frame, keep)
	if not frame or not frame.GetRegions then
		return
	end
	local regions = { frame:GetRegions() }
	for i = 1, #regions do
		local r = regions[i]
		if r and r.IsObjectType and r:IsObjectType("Texture") and not GetFFD(r).owned and not (keep and keep[r]) then
			r:SetAlpha(0)
		end
	end
end

-- Flat dark background for a popup-style frame (made once).
local function PopupBG(frame, layer, alpha)
	local d = GetFFD(frame)
	if not d.bg then
		d.bg = frame:CreateTexture(nil, layer or "BACKGROUND", nil, -8)
		d.bg:SetAllPoints()
		GetFFD(d.bg).owned = true
	end
	d.bg:SetTexture(RESKIN.BG_R, RESKIN.BG_G, RESKIN.BG_B, alpha or RESKIN.QT_ALPHA)
	d.bg:Show()
	return d.bg
end

-- Popup button (retail popup button look): Blizzard art faded, our
-- background color + configured border, 10% white hover, text color by the
-- Element & Text Color mode (dimmed while disabled).
local BUTTON_PIECES = { "Left", "Middle", "Right" }
local function ButtonTextRefresh(btn)
	local fs = btn.GetFontString and btn:GetFontString()
	local enabled = (btn.IsEnabled and btn:IsEnabled()) and true or false
	if fs then
		if not enabled then
			fs:SetTextColor(0.4, 0.4, 0.4, 1)
		elseif ElementMode() == "native" then
			if GetFFD(btn).nativeGold then fs:SetTextColor(1, 0.82, 0, 1) else fs:SetTextColor(1, 1, 1, 1) end
		else
			local r, g, b = ElementColor()
			fs:SetTextColor(r, g, b, 1)
		end
	end
	local d = GetFFD(btn)
	if d.bg then
		d.bg:SetAlpha(enabled and 1 or 0.5)
	end
end

local function StyleButton(btn, inset)
	if not btn or Forbidden(btn) then
		return
	end
	local d = GetFFD(btn)
	local name = btn.GetName and btn:GetName()
	-- Re-faded every call: Blizzard re-applies the art on state changes.
	local fs = btn.GetFontString and btn:GetFontString()
	local keep = {}
	if fs then keep[fs] = true end
	FadeTextureRegions(btn, keep)
	for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
		local fn = btn[getter]
		local t = fn and fn(btn)
		if t and not GetFFD(t).owned then
			t:SetAlpha(0)
		end
	end
	for _, k in ipairs(BUTTON_PIECES) do
		local r = btn[k] or (name and _G[name .. k])
		if type(r) == "table" and r.SetAlpha then
			r:SetAlpha(0)
		end
	end
	if not d.popupSkinned then
		d.popupSkinned = true
		local host = btn
		if inset then
			host = CreateFrame("Frame", nil, btn)
			host:SetPoint("TOPLEFT", inset, -inset)
			host:SetPoint("BOTTOMRIGHT", -inset, inset)
			host:SetFrameLevel(btn:GetFrameLevel())
			d.host = host
		end
		local bg = host:CreateTexture(nil, "BACKGROUND", nil, -6)
		bg:SetAllPoints(host)
		GetFFD(bg).owned = true
		d.bg = bg
		local hov = btn:CreateTexture(nil, "HIGHLIGHT")
		hov:SetTexture(1, 1, 1, 0.1)
		hov:SetAllPoints(host)
		GetFFD(hov).owned = true
		if btn.HookScript then
			btn:HookScript("OnEnable", ButtonTextRefresh)
			btn:HookScript("OnDisable", ButtonTextRefresh)
			btn:HookScript("OnLeave", ButtonTextRefresh)
			btn:HookScript("OnShow", ButtonTextRefresh)
		end
	end
	local c = DB().popupMenuButtonBackgroundColor or { r = 0.1, g = 0.1, b = 0.1, a = 0.8 }
	d.bg:SetTexture(c.r or 0.1, c.g or 0.1, c.b or 0.1, c.a == nil and 0.8 or c.a)
	ApplyBorder(d.host or btn, "popupMenuButton")
	ButtonTextRefresh(btn)
end
TT.StyleButton = StyleButton

-------------------------------------------------------------------------------
--  Tooltip skin
-------------------------------------------------------------------------------
function TT.GetTooltipBg()
	local db = DB()
	local c = db.tooltipBgColor
	local r = (c and c.r) or RESKIN.BG_R
	local g = (c and c.g) or RESKIN.BG_G
	local b = (c and c.b) or RESKIN.BG_B
	local a = db.tooltipBgOpacity
	if a == nil then
		a = RESKIN.TT_ALPHA
	end
	return r, g, b, a
end

local function SkinTooltip(tt)
	if not tt or Forbidden(tt) or not ttActive then
		return
	end
	NoBackdrop(tt)
	local d = GetFFD(tt)
	if not d.bg then
		d.bg = tt:CreateTexture(nil, "BACKGROUND", nil, -8)
		d.bg:SetAllPoints()
		GetFFD(d.bg).owned = true
	end
	d.bg:SetTexture(TT.GetTooltipBg())
	d.bg:Show()
	ApplyBorder(tt, "tooltip")
end
TT.SkinTooltip = SkinTooltip

local function TooltipFonts(tt, startFrom)
	if not tt or not ttActive then
		return
	end
	local name = tt.GetName and tt:GetName()
	if not name then
		return
	end
	local fp, ol = BS.FontPath(), BS.FontFlag()
	local scale = Get("tooltipFontScale") or 1
	local titleSize = floor(13 * scale + 0.5)
	local bodySize = floor(11 * scale + 0.5)
	local n = (tt.NumLines and tt:NumLines()) or 0
	for i = max(1, startFrom or 1), n do
		local left = _G[name .. "TextLeft" .. i]
		if not left then
			break
		end
		left:SetFont(fp, (i == 1) and titleSize or bodySize, ol)
		local right = _G[name .. "TextRight" .. i]
		if right then
			right:SetFont(fp, bodySize, ol)
		end
	end
end
TT.TooltipFonts = TooltipFonts

local relaying = setmetatable({}, { __mode = "k" })
local function TooltipOnShow(self)
	SkinTooltip(self)
	TooltipFonts(self)
	-- Re-show to resize with the new fonts.
	if ttActive and not relaying[self] then
		relaying[self] = true
		pcall(self.Show, self)
		relaying[self] = nil
	end
end

local hookedTips = setmetatable({}, { __mode = "k" })
local function HookTooltip(tt)
	if not tt or hookedTips[tt] or not tt.HookScript then
		return
	end
	hookedTips[tt] = true
	tt:HookScript("OnShow", TooltipOnShow)
end
TT.HookTooltip = HookTooltip

local TOOLTIP_NAMES = {
	"GameTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "ShoppingTooltip3",
	"ItemRefTooltip", "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2", "ItemRefShoppingTooltip3",
	"WorldMapTooltip", "WorldMapCompareTooltip1", "WorldMapCompareTooltip2", "WorldMapCompareTooltip3",
	"FriendsTooltip", "SmallTextTooltip", "LibDBIconTooltip", "FloatingBattlePetTooltip",
	"BattlePetTooltip", "FloatingPetBattleAbilityTooltip",
}

-------------------------------------------------------------------------------
--  Health strip (GameTooltipStatusBar)
-------------------------------------------------------------------------------
local stripStyled = false
local stripOwned = false -- false while ElvUI's tooltip module runs the bar
local function StripHidden()
	return Get("tooltipHideHealthStrip") ~= false
end

function TT.ApplyHealthStrip()
	local bar = GameTooltipStatusBar
	if not bar or not stripOwned then
		return
	end
	bar:SetAlpha(StripHidden() and 0 or 1)
end

function TT.ApplyHealthStripStyle()
	local bar = GameTooltipStatusBar
	if not stripStyled or not bar then
		return
	end
	local key = DB().tooltipHealthStripTexture
	local path = "Interface\\TargetingFrame\\UI-StatusBar"
	if type(key) == "string" and key ~= "" and key ~= "blizzard" then
		path = key
	end
	bar:SetStatusBarTexture(path)
	bar:SetHeight(Get("tooltipHealthStripHeight") or 3)
end

local function InitHealthStrip()
	local bar = GameTooltipStatusBar
	if not bar then
		return
	end
	stripOwned = true
	hooksecurefunc(bar, "Show", function(self)
		if StripHidden() then
			self:SetAlpha(0)
		end
	end)
	TT.ApplyHealthStrip()
end

local function StyleHealthStrip()
	local bar = GameTooltipStatusBar
	if not bar then
		return
	end
	local sbBg = bar:CreateTexture(nil, "BACKGROUND")
	sbBg:SetAllPoints()
	sbBg:SetTexture(0, 0, 0, 0.5)
	bar:ClearAllPoints()
	bar:SetPoint("BOTTOMLEFT", GameTooltip, "BOTTOMLEFT", 1, 1)
	bar:SetPoint("BOTTOMRIGHT", GameTooltip, "BOTTOMRIGHT", -1, 1)
	stripStyled = true
	TT.ApplyHealthStripStyle()
end

-------------------------------------------------------------------------------
--  Tooltip data: identity, item level (inspect), mount, target, buffs
-------------------------------------------------------------------------------
local tipGUID = nil      -- GUID the visible GameTooltip was built for
local ilvlShown = false  -- the Item Level line is on the tooltip already
local ilvlCache = {}     -- guid -> { ilvl =, time = }
local ILVL_TTL = 120
local mountCache = {}    -- guid -> { name = string|false, time = }
local MOUNT_TTL = 3

local function TipHasLine(tt, label)
	local nm = tt.GetName and tt:GetName()
	if not nm then
		return false
	end
	for i = 1, (tt:NumLines() or 0) do
		local fs = _G[nm .. "TextLeft" .. i]
		local txt = fs and fs:GetText()
		if txt and txt:find(label, 1, true) then
			return true
		end
	end
	return false
end

-- A unit token for a GUID (5.4.8 has no UnitTokenFromGUID).
local function TokenForGUID(guid)
	if not guid then
		return nil
	end
	for _, u in ipairs({ "mouseover", "target", "focus", "player" }) do
		if UnitExists(u) and UnitGUID(u) == guid then
			return u
		end
	end
	if IsInRaid and IsInRaid() then
		for i = 1, GetNumGroupMembers() do
			local u = "raid" .. i
			if UnitGUID(u) == guid then
				return u
			end
		end
	else
		for i = 1, (GetNumSubgroupMembers and GetNumSubgroupMembers() or 0) do
			local u = "party" .. i
			if UnitGUID(u) == guid then
				return u
			end
		end
	end
	return nil
end

-- Item level from the inspect data, read from a hidden scan tooltip so
-- upgraded items count with their upgraded level.
local scanTip
local ILVL_PATTERN = "^" .. (ITEM_LEVEL or "Item Level %d"):gsub("%%d", "(%%d+)")
local function SlotItemLevel(unit, slot)
	local link = GetInventoryItemLink(unit, slot)
	if not link then
		return nil
	end
	if not scanTip then
		scanTip = CreateFrame("GameTooltip", "EUIBlizzSkinScanTooltip", nil, "GameTooltipTemplate")
	end
	scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
	scanTip:ClearLines()
	scanTip:SetInventoryItem(unit, slot)
	for i = 2, min(6, scanTip:NumLines() or 0) do
		local fs = _G["EUIBlizzSkinScanTooltipTextLeft" .. i]
		local txt = fs and fs:GetText()
		local v = txt and tonumber(txt:match(ILVL_PATTERN))
		if v then
			scanTip:Hide()
			return v, link
		end
	end
	scanTip:Hide()
	local _, _, _, lvl = GetItemInfo(link)
	return lvl, link
end

local ILVL_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 }
-- Average equipped item level, nil while item data is still loading.
local function InspectItemLevel(unit)
	local total, missing = 0, false
	local mainLvl, mainLink, hasOff = nil, nil, false
	for _, slot in ipairs(ILVL_SLOTS) do
		local id = GetInventoryItemID(unit, slot)
		if id then
			local lvl, link = SlotItemLevel(unit, slot)
			if not lvl then
				missing = true
			else
				total = total + lvl
				if slot == 16 then
					mainLvl, mainLink = lvl, link
				elseif slot == 17 then
					hasOff = true
				end
			end
		end
	end
	if missing then
		return nil
	end
	-- A two-hand weapon without an off hand counts twice (Blizzard's rule).
	if mainLvl and not hasOff and mainLink then
		local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(mainLink)
		if equipLoc == "INVTYPE_2HWEAPON" or equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_RANGEDRIGHT" then
			total = total + mainLvl
		end
	end
	if total <= 0 then
		return nil
	end
	return floor(total / 16)
end

-- Inspect request pacing (retail _insp): a dwell before asking, a minimum gap
-- after anyone's request, and passive mode while another addon polls.
local insp = {
	active = false, lastAny = 0, lastForeign = 0, ourAt = -1, pendingGUID = nil,
	pendingAt = 0, dwellGUID = nil, dwellAt = 0, dwellArmed = false,
	MIN_GAP = 2, DWELL = 0.9, FOREIGN_WINDOW = 10, PENDING_TTL = 5,
}
local inspectFrame

local function AddItemLevelLine(ilvl)
	if not GameTooltip:IsShown() or ilvlShown or TipHasLine(GameTooltip, "Item Level") then
		return
	end
	local n = GameTooltip:NumLines() or 0
	GameTooltip:AddDoubleLine("Item Level:", ilvl, 1, 1, 1, 1, 1, 1)
	TooltipFonts(GameTooltip, n + 1)
	pcall(GameTooltip.Show, GameTooltip)
	ilvlShown = true
end

local function ReadInspect(guid, tries)
	local unit = TokenForGUID(guid)
	if not unit or UnitGUID(unit) ~= guid then
		return
	end
	local v = InspectItemLevel(unit)
	if not v then
		if (tries or 0) < 3 then
			BS.After(0.4, function() ReadInspect(guid, (tries or 0) + 1) end)
		end
		return
	end
	ilvlCache[guid] = { ilvl = v, time = GetTime() }
	if tipGUID == guid then
		AddItemLevelLine(v)
	end
end

local function OnInspectReady(self, _, guid)
	if Get("tooltipItemLevel") == false then
		self:UnregisterEvent("INSPECT_READY")
		insp.active = false
		return
	end
	if not guid then
		return
	end
	if guid == insp.pendingGUID then
		insp.pendingGUID = nil
	end
	ReadInspect(guid, 0)
end

function insp.Activate()
	if insp.active then
		return
	end
	insp.active = true
	insp.lastAny = GetTime()
	if not inspectFrame then
		inspectFrame = CreateFrame("Frame")
		inspectFrame:SetScript("OnEvent", OnInspectReady)
		hooksecurefunc("NotifyInspect", function()
			if not insp.active then
				return
			end
			local t = GetTime()
			insp.lastAny = t
			if insp.ourAt ~= t then
				insp.lastForeign = t
			end
		end)
	end
	inspectFrame:RegisterEvent("INSPECT_READY")
end

local function InspectBlocked(guid)
	local f = InspectFrame
	if f and f:IsShown() then
		return true
	end
	return false
end

local DwellTick
DwellTick = function()
	insp.dwellArmed = false
	local guid = insp.dwellGUID
	if not guid then
		return
	end
	if tipGUID ~= guid or not GameTooltip:IsShown() or Get("tooltipItemLevel") == false or InCombatLockdown() then
		insp.dwellGUID = nil
		return
	end
	local now = GetTime()
	local cached = ilvlCache[guid]
	if (cached and now - cached.time < ILVL_TTL) or InspectBlocked(guid) then
		insp.dwellGUID = nil
		return
	end
	local readyAt = max(insp.dwellAt + insp.DWELL, insp.lastAny + insp.MIN_GAP)
	if guid == insp.pendingGUID then
		readyAt = max(readyAt, insp.pendingAt + insp.PENDING_TTL)
	end
	local unit = TokenForGUID(guid)
	if unit and unit ~= "mouseover" and unit ~= "target" and unit ~= "focus" then
		-- Group member: another addon polling the group feeds us.
		readyAt = max(readyAt, insp.lastForeign + insp.FOREIGN_WINDOW)
	end
	if readyAt > now then
		insp.dwellArmed = true
		BS.After(readyAt - now, DwellTick)
		return
	end
	insp.dwellGUID = nil
	if not unit or not UnitExists(unit) or not CanInspect(unit) then
		return
	end
	insp.pendingGUID = guid
	insp.pendingAt = now
	insp.ourAt = now
	NotifyInspect(unit)
end

local function RequestInspect(guid)
	if insp.dwellArmed and insp.dwellGUID == guid then
		return
	end
	if InspectBlocked(guid) then
		return
	end
	if insp.dwellGUID ~= guid then
		insp.dwellGUID = guid
		insp.dwellAt = GetTime()
	end
	if not insp.dwellArmed then
		insp.dwellArmed = true
		BS.After(insp.DWELL, DwellTick)
	end
end

-- Mounts you own: spellID -> name (5.4.8 companions).
local ownMounts, ownMountsAt = nil, 0
local function OwnMounts()
	if ownMounts and GetTime() - ownMountsAt < 60 then
		return ownMounts
	end
	ownMounts, ownMountsAt = {}, GetTime()
	if GetNumCompanions and GetCompanionInfo then
		for i = 1, (GetNumCompanions("MOUNT") or 0) do
			local _, name, spellID = GetCompanionInfo("MOUNT", i)
			if spellID then
				ownMounts[spellID] = name
			end
		end
	end
	return ownMounts
end

-- The mount a player rides, when it is one of yours (5.4.8 cannot tell a
-- mount buff from another buff otherwise).
local function MountedName(unit)
	if not unit or not UnitIsPlayer(unit) or InCombatLockdown() then
		return nil
	end
	local own = OwnMounts()
	for i = 1, 40 do
		local name, _, _, _, _, _, _, _, _, _, spellID = UnitBuff(unit, i)
		if not name then
			break
		end
		if spellID and own[spellID] then
			return own[spellID] or name
		end
	end
	return nil
end

-- "Targeting:" line, updated in place on refresh.
local function TargetLine(tt, unit)
	if not (unit and Get("tooltipShowTarget")) then
		return
	end
	local tu = unit .. "target"
	local label = "Targeting:"
	local tName, r, g, b
	if UnitExists(tu) then
		if UnitIsUnit(tu, "player") then
			tName, r, g, b = "You", 0.1, 1, 0.1
		else
			tName, r, g, b = UnitName(tu), 0.9, 0.9, 0.9
			if UnitIsPlayer(tu) then
				local _, cf = UnitClass(tu)
				local cc = cf and RAID_CLASS_COLORS[cf]
				if cc then
					r, g, b = cc.r, cc.g, cc.b
				end
			else
				local reaction = UnitReaction(tu, "player")
				local fc = reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
				if fc then
					r, g, b = fc.r, fc.g, fc.b
				end
			end
		end
	end
	for i = 2, (tt:NumLines() or 0) do
		local lineL = _G["GameTooltipTextLeft" .. i]
		if lineL and lineL:GetText() == label then
			local lineR = _G["GameTooltipTextRight" .. i]
			if lineR then
				if tName then
					lineR:SetText(tName)
					lineR:SetTextColor(r, g, b)
				else
					lineR:SetText("-")
					lineR:SetTextColor(0.6, 0.6, 0.6)
				end
			end
			return
		end
	end
	if tName then
		tt:AddDoubleLine(label, tName, 1, 1, 1, r, g, b)
	end
end

-- Player buffs as icons next to the tooltip (tooltipShowBuffs).
local buffBox
local BUFF_POS = {
	bottom = { "TOPLEFT", "BOTTOMLEFT", 1, -1, 0, -2 },
	top = { "BOTTOMLEFT", "TOPLEFT", 1, 1, 0, 2 },
	left = { "TOPRIGHT", "TOPLEFT", -1, -1, -2, 0 },
	right = { "TOPLEFT", "TOPRIGHT", 1, -1, 2, 0 },
}
local function BuffIcon(i)
	local icons = GetFFD(buffBox).icons
	local f = icons[i]
	if not f then
		f = CreateFrame("Frame", nil, buffBox)
		f.bg = BS.SolidTex(f, "BACKGROUND", 0, 0, 0, 1)
		f.bg:SetAllPoints()
		f.icon = f:CreateTexture(nil, "ARTWORK")
		f.icon:SetPoint("TOPLEFT", 1, -1)
		f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
		f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		icons[i] = f
	end
	return f
end

function TT.LayoutBuffs(unit)
	if not buffBox then
		return
	end
	local icons = GetFFD(buffBox).icons
	if not Get("tooltipShowBuffs") or not unit or not ttActive then
		buffBox:Hide()
		return
	end
	local size = Get("tooltipBuffSize") or 20
	local perRow = max(1, Get("tooltipBuffsPerRow") or 8)
	local p = BUFF_POS[Get("tooltipBuffPosition") or "bottom"] or BUFF_POS.bottom
	buffBox:ClearAllPoints()
	buffBox:SetPoint(p[1], GameTooltip, p[2], p[5] + (Get("tooltipBuffOffsetX") or 0), p[6] + (Get("tooltipBuffOffsetY") or 0))
	local n = 0
	for i = 1, 16 do
		local name, _, tex = UnitBuff(unit, i)
		if not name then
			break
		end
		n = n + 1
		local f = BuffIcon(n)
		f:SetSize(size, size)
		f.icon:SetTexture(tex)
		local col = (n - 1) % perRow
		local row = floor((n - 1) / perRow)
		f:ClearAllPoints()
		f:SetPoint(p[1], buffBox, p[1], col * (size + 2) * p[3], row * (size + 2) * p[4])
		f:Show()
	end
	for i = n + 1, #icons do
		icons[i]:Hide()
	end
	if n == 0 then
		buffBox:Hide()
		return
	end
	buffBox:SetSize(min(n, perRow) * (size + 2), ceil(n / perRow) * (size + 2))
	buffBox:Show()
end

local function ShowBuffs(unit)
	if not Get("tooltipShowBuffs") then
		if buffBox then
			buffBox:Hide()
		end
		return
	end
	if not buffBox then
		buffBox = CreateFrame("Frame", nil, GameTooltip)
		buffBox:SetSize(1, 1)
		GetFFD(buffBox).icons = {}
		GameTooltip:HookScript("OnHide", function()
			buffBox:Hide()
		end)
		if GameTooltip:HasScript("OnTooltipCleared") then
			GameTooltip:HookScript("OnTooltipCleared", function()
				buffBox:Hide()
			end)
		end
	end
	TT.LayoutBuffs(unit)
end

local nameL1
local function OnTooltipSetUnit(tt)
	if tt ~= GameTooltip or not ttActive then
		return
	end
	local nBefore = tt:NumLines() or 0
	local _, unit = tt:GetUnit()
	if not unit and UnitExists("mouseover") then
		unit = "mouseover"
	end
	local guid = unit and UnitGUID(unit)
	tipGUID = guid
	ilvlShown = false
	if buffBox then
		buffBox:Hide()
	end
	if not guid then
		return
	end
	if not UnitIsPlayer(unit) then
		TargetLine(tt, unit)
		TooltipFonts(tt, nBefore)
		return
	end
	local _, classFile = UnitClass(unit)
	local pname, prealm = UnitName(unit)
	nameL1 = nameL1 or _G.GameTooltipTextLeft1
	if not nameL1 or not classFile then
		return
	end
	-- Player titles are hidden unless tooltipPlayerTitles is on.
	if not Get("tooltipPlayerTitles") and pname then
		local display = (prealm and prealm ~= "") and (pname .. "-" .. prealm) or pname
		local cur = nameL1:GetText()
		if cur and cur ~= display then
			local titled = UnitPVPName and UnitPVPName(unit)
			if titled and titled ~= pname and cur:find(titled, 1, true) then
				nameL1:SetText((cur:gsub(titled:gsub("(%W)", "%%%1"), (pname:gsub("%%", "%%%%")), 1)))
			end
		end
	end
	local cc = RAID_CLASS_COLORS[classFile]
	if cc then
		nameL1:SetTextColor(cc.r, cc.g, cc.b)
		if GameTooltipStatusBar then
			GameTooltipStatusBar:SetStatusBarColor(cc.r, cc.g, cc.b)
		end
	end
	-- Guild rank next to the guild name: <Guild> [Rank].
	if Get("tooltipShowGuildRank") then
		local guildName, rankName = GetGuildInfo(unit)
		if guildName and rankName then
			local suffix = " [" .. rankName .. "]"
			for i = 2, nBefore do
				local line = _G["GameTooltipTextLeft" .. i]
				local text = line and line:GetText()
				if text and text:find(guildName, 1, true) then
					if text:sub(-#suffix) ~= suffix then
						line:SetText(text .. suffix)
					end
					break
				end
			end
		end
	end
	-- Mount (yours only, green check).
	if Get("tooltipShowMount") and not TipHasLine(tt, "Mount:") then
		local cached = mountCache[guid]
		local mountName
		if cached and GetTime() - cached.time < MOUNT_TTL then
			mountName = cached.name
		else
			mountName = MountedName(unit) or false
			mountCache[guid] = { name = mountName, time = GetTime() }
		end
		if mountName then
			tt:AddDoubleLine("Mount:", mountName .. " |TInterface\\RaidFrame\\ReadyCheck-Ready:0|t", 1, 1, 1, 1, 1, 1)
		end
	end
	ShowBuffs(unit)
	TargetLine(tt, unit)
	-- Item level.
	if Get("tooltipItemLevel") ~= false then
		if not insp.active then
			insp.Activate()
		end
		local ilvl
		if UnitIsUnit(unit, "player") then
			local _, equipped = GetAverageItemLevel()
			if equipped and equipped > 0 then
				ilvl = floor(equipped)
			end
		else
			local cached = ilvlCache[guid]
			if cached and GetTime() - cached.time < ILVL_TTL then
				ilvl = cached.ilvl
			elseif CanInspect(unit) and not InCombatLockdown() and not (InspectFrame and InspectFrame:IsShown()) then
				RequestInspect(guid)
			end
		end
		if ilvl and not TipHasLine(tt, "Item Level") then
			tt:AddDoubleLine("Item Level:", ilvl, 1, 1, 1, 1, 1, 1)
			ilvlShown = true
		end
	end
	TooltipFonts(tt, nBefore)
	pcall(tt.Show, tt)
end

-- Spell titles in the element color (not in native mode).
local function OnTooltipSetSpell(tt)
	if tt ~= GameTooltip or not ttActive or not AccentOn() then
		return
	end
	nameL1 = nameL1 or _G.GameTooltipTextLeft1
	if nameL1 then
		nameL1:SetTextColor(ElementColor())
	end
end

-- Max stack line (showItemMaxStacks; optional modifier). Works without the reskin.
local function ModifierHeld(mod)
	if not mod or mod == "none" then
		return true
	end
	if mod == "shift" then
		return IsShiftKeyDown()
	elseif mod == "control" then
		return IsControlKeyDown()
	elseif mod == "alt" then
		return IsAltKeyDown()
	end
	return true
end
local function OnTooltipSetItem(tt)
	if not Get("showItemMaxStacks") or not ModifierHeld(Get("itemStackModifier")) then
		return
	end
	local _, link = tt:GetItem()
	if not link then
		return
	end
	local _, _, _, _, _, _, _, maxStack = GetItemInfo(link)
	if maxStack and maxStack > 1 and not TipHasLine(tt, "Max Stack") then
		tt:AddDoubleLine("Max Stack:", maxStack, 1, 1, 1, 1, 1, 1)
		pcall(tt.Show, tt)
	end
end

local function InitTooltipData()
	GameTooltip:HookScript("OnHide", function()
		tipGUID = nil
	end)
	if Get("tooltipItemLevel") ~= false then
		insp.Activate()
	end
	GameTooltip:HookScript("OnTooltipSetUnit", OnTooltipSetUnit)
	GameTooltip:HookScript("OnTooltipSetSpell", OnTooltipSetSpell)
end

local function InitTooltipVisual()
	for _, name in ipairs(TOOLTIP_NAMES) do
		HookTooltip(_G[name])
	end
	StyleHealthStrip()
end

-------------------------------------------------------------------------------
--  Context menus (DropDownList1..UIDROPDOWNMENU_MAXLEVELS)
-------------------------------------------------------------------------------
local function SkinDropList(list)
	if not list or Forbidden(list) or not pmActive then
		return
	end
	local name = list:GetName()
	if name then
		for _, suffix in ipairs({ "Backdrop", "MenuBackdrop" }) do
			local f = _G[name .. suffix]
			if f and f.SetAlpha then
				f:SetAlpha(0)
			end
		end
	end
	local d = GetFFD(list)
	if not d.bg then
		d.bg = list:CreateTexture(nil, "BACKGROUND", nil, -8)
		d.bg:SetPoint("TOPLEFT", list, "TOPLEFT", 1, -1)
		d.bg:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -1, 1)
		GetFFD(d.bg).owned = true
	end
	d.bg:SetTexture(RESKIN.BG_R, RESKIN.BG_G, RESKIN.BG_B, 1)
	d.bg:SetAlpha(RESKIN.CTX_ALPHA)
	ApplyBorder(list, "popupMenu")
end

local hookedLists = setmetatable({}, { __mode = "k" })
local function HookDropLists()
	for i = 1, (UIDROPDOWNMENU_MAXLEVELS or 2) do
		local list = _G["DropDownList" .. i]
		if list and not hookedLists[list] then
			hookedLists[list] = true
			list:HookScript("OnShow", SkinDropList)
			if list:IsShown() then
				SkinDropList(list)
			end
		end
	end
end

local function InitMenus()
	HookDropLists()
	if UIDropDownMenu_CreateFrames then
		hooksecurefunc("UIDropDownMenu_CreateFrames", HookDropLists)
	end
end

-------------------------------------------------------------------------------
--  Static popups
-------------------------------------------------------------------------------
local function PopupButtons(popup)
	local list = {}
	local name = popup:GetName()
	for i = 1, 4 do
		local b = popup["button" .. i] or (name and _G[name .. "Button" .. i])
		if b then
			list[#list + 1] = b
		end
	end
	local extra = popup.extraButton or (name and _G[name .. "ExtraButton"])
	if extra then
		list[#list + 1] = extra
	end
	return list
end

local function SkinPopupEditBox(eb)
	if not eb or GetFFD(eb).popupSkinned then
		return
	end
	GetFFD(eb).popupSkinned = true
	FadeTextureRegions(eb)
	local name = eb:GetName()
	for _, k in ipairs({ "Left", "Middle", "Right", "Mid" }) do
		local r = eb[k] or (name and _G[name .. k])
		if type(r) == "table" and r.SetAlpha then
			r:SetAlpha(0)
		end
	end
	local host = CreateFrame("Frame", nil, eb)
	host:SetPoint("TOPLEFT", eb, "TOPLEFT", -6, -2)
	host:SetPoint("BOTTOMRIGHT", eb, "BOTTOMRIGHT", 2, 2)
	host:SetFrameLevel(max(0, eb:GetFrameLevel() - 1))
	local bg = host:CreateTexture(nil, "BACKGROUND", nil, -6)
	bg:SetAllPoints()
	bg:SetTexture(0.05, 0.05, 0.05, 0.9)
	GetFFD(bg).owned = true
	local r, g, b = 1, 1, 1
	if AccentOn() then
		r, g, b = ElementColor()
	end
	PP.CreateBorder(host, r, g, b, 0.5, 1, "OVERLAY", 7)
end

local function SkinPopup(popup)
	if not popup or Forbidden(popup) or not pmActive then
		return
	end
	NoBackdrop(popup)
	PopupBG(popup)
	ApplyBorder(popup, "popupMenu")
	for _, btn in ipairs(PopupButtons(popup)) do
		StyleButton(btn)
	end
	local name = popup:GetName()
	SkinPopupEditBox(popup.editBox or (name and _G[name .. "EditBox"]))
	if name and _G[name .. "WideEditBox"] then
		SkinPopupEditBox(_G[name .. "WideEditBox"])
	end
end
TT.SkinPopup = SkinPopup

local function InitPopups()
	for i = 1, (STATICPOPUP_NUMDIALOGS or 4) do
		local popup = _G["StaticPopup" .. i]
		if popup then
			popup:HookScript("OnShow", SkinPopup)
		end
	end
end

-------------------------------------------------------------------------------
--  Resurrect Accept Glow (resurrectAcceptGlow, default off): pulsing border
--  around Accept on the resurrect popups. Hooks install on first enable.
-------------------------------------------------------------------------------
local RES_WHICH = { RESURRECT = true, RESURRECT_NO_SICKNESS = true, RESURRECT_NO_TIMER = true }
local resGlowHooked = false

local function ResGlowButton(popup)
	return popup.button1 or (popup:GetName() and _G[popup:GetName() .. "Button1"])
end

local function ResGlowGet(btn)
	local d = GetFFD(btn)
	if not d.resGlow then
		local ov = CreateFrame("Frame", nil, btn)
		ov:SetPoint("TOPLEFT", btn, "TOPLEFT", -3, 3)
		ov:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 3, -3)
		ov:SetFrameLevel(btn:GetFrameLevel() + 5)
		ov:Hide()
		PP.CreateBorder(ov, 1, 1, 1, 1, 2, "OVERLAY", 7)
		local ag = ov:CreateAnimationGroup()
		ag:SetLooping("BOUNCE")
		local pulse = ag:CreateAnimation("Alpha")
		pulse:SetChange(-0.85)
		pulse:SetDuration(0.7)
		pulse:SetSmoothing("IN_OUT")
		d.resGlow, d.resGlowAG = ov, ag
	end
	return d.resGlow, d.resGlowAG
end

local function ResGlowStart(btn)
	local ov, ag = ResGlowGet(btn)
	if AccentOn() then
		PP.SetBorderColor(ov, BS.ACCENT.r, BS.ACCENT.g, BS.ACCENT.b, 1)
	else
		PP.SetBorderColor(ov, 1, 1, 1, 1)
	end
	ov:SetAlpha(1)
	ov:Show()
	if ag and not ag:IsPlaying() then
		ag:Play()
	end
end

local function ResGlowStop(btn)
	local d = btn and WSkin.FFD[btn]
	if d and d.resGlow then
		if d.resGlowAG then
			d.resGlowAG:Stop()
		end
		d.resGlow:Hide()
	end
end

local function ResGlowRefresh(popup)
	local btn = ResGlowButton(popup)
	if not btn then
		return
	end
	if Get("resurrectAcceptGlow") and RES_WHICH[popup.which] and popup:IsShown() then
		ResGlowStart(btn)
	else
		ResGlowStop(btn)
	end
end

function TT.EnsureResurrectGlow()
	if Get("resurrectAcceptGlow") and not resGlowHooked then
		resGlowHooked = true
		for i = 1, (STATICPOPUP_NUMDIALOGS or 4) do
			local popup = _G["StaticPopup" .. i]
			if popup then
				popup:HookScript("OnShow", function(self)
					if Get("resurrectAcceptGlow") then
						ResGlowRefresh(self)
					end
				end)
				popup:HookScript("OnHide", function(self)
					ResGlowStop(ResGlowButton(self))
				end)
			end
		end
	end
	if resGlowHooked then
		for i = 1, (STATICPOPUP_NUMDIALOGS or 4) do
			local popup = _G["StaticPopup" .. i]
			if popup then
				ResGlowRefresh(popup)
			end
		end
	end
end

-------------------------------------------------------------------------------
--  LFG queue popup: reskin + accept countdown bar, ready status, role check
-------------------------------------------------------------------------------
local TIMER_DURATION = 40
local timerBar, timerText, timerBg, timerBorder, timerEndTime
local timerEUI = nil -- true: EllesmereUI style, false: Blizzard style

local function SkinQueuePopup()
	local dialog = LFGDungeonReadyDialog
	if not dialog or not queueActive then
		return
	end
	-- Keep the dungeon art (dimmed), drop the backdrop and filigree.
	NoBackdrop(dialog)
	local keep = {}
	if dialog.background then
		keep[dialog.background] = true
		dialog.background:SetAlpha(0.35)
	end
	if dialog.bottomArt then
		keep[dialog.bottomArt] = true
	end
	FadeTextureRegions(dialog, keep)
	if dialog.filigree then
		dialog.filigree:SetAlpha(0)
	end
	local d = GetFFD(dialog)
	if not d.bgFrame then
		-- A frame below the dialog, so its bg draws under the dungeon art.
		local bgFrame = CreateFrame("Frame", nil, dialog)
		bgFrame:SetAllPoints(dialog)
		bgFrame:SetFrameLevel(max(0, dialog:GetFrameLevel() - 1))
		d.bgFrame = bgFrame
		local bg = bgFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
		bg:SetAllPoints()
		bg:SetTexture(RESKIN.BG_R, RESKIN.BG_G, RESKIN.BG_B, RESKIN.QT_ALPHA)
		GetFFD(bg).owned = true
	end
	ApplyBorder(d.bgFrame, "popupMenu")
	-- Close (minimize) button: Blizzard art faded, a flat "-" instead.
	local closeBtn = _G.LFGDungeonReadyDialogCloseButton
	if closeBtn then
		FadeTextureRegions(closeBtn)
		for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture" }) do
			local t = closeBtn[getter] and closeBtn[getter](closeBtn)
			if t and not GetFFD(t).owned then
				t:SetAlpha(0)
			end
		end
		local cd = GetFFD(closeBtn)
		if not cd.icon then
			local ico = closeBtn:CreateTexture(nil, "OVERLAY", nil, 7)
			ico:SetTexture(WHITE)
			ico:SetVertexColor(1, 1, 1, 0.8)
			ico:SetSize(9, 2)
			ico:SetPoint("CENTER", closeBtn, "CENTER", -2, 2)
			GetFFD(ico).owned = true
			cd.icon = ico
		end
		cd.icon:Show()
	end
	StyleButton(dialog.enterButton or _G.LFGDungeonReadyDialogEnterDungeonButton)
	StyleButton(dialog.leaveButton or _G.LFGDungeonReadyDialogLeaveQueueButton)
end

local function QueueTimerCustomized()
	local db = DB()
	return db.queueTimerTextColor ~= nil or db.queueTimerTextSize ~= nil
		or db.queueTimerBarHeight ~= nil or db.queueTimerTextOffsetY ~= nil
end

function TT.RefreshQueueTimerStyle()
	if not timerBar then
		return
	end
	if timerEUI == false and not QueueTimerCustomized() then
		timerText:SetFontObject("GameFontHighlight")
		timerText:ClearAllPoints()
		timerText:SetPoint("CENTER", timerBar, "CENTER", 0, 0)
		timerBar:SetHeight(9)
		return
	end
	local db = DB()
	local c = db.queueTimerTextColor
	timerText:SetFont(BS.FontPath(), db.queueTimerTextSize or QT.TEXT_SIZE, "")
	timerText:SetShadowOffset(1, -1)
	timerText:SetShadowColor(0, 0, 0, 1)
	timerText:SetTextColor((c and c.r) or QT.TEXT_R, (c and c.g) or QT.TEXT_G, (c and c.b) or QT.TEXT_B, 1)
	timerText:ClearAllPoints()
	timerText:SetPoint("CENTER", timerBar, "CENTER", 0, db.queueTimerTextOffsetY or QT.TEXT_OFFSET_Y)
	timerBar:SetHeight(db.queueTimerBarHeight or QT.BAR_HEIGHT)
	if timerEUI then
		local r, g, b = BS.Accent()
		timerBar:SetStatusBarColor(r, g, b, 0.75)
	end
end

local function TimerOnUpdate(self)
	local remaining = timerEndTime - GetTime()
	if remaining <= 0 then
		self:SetScript("OnUpdate", nil)
		self:Hide()
		return
	end
	self:SetValue(remaining)
	timerText:SetText(format("%d", ceil(remaining)))
end

local function ShowQueueTimer(useEuiStyle)
	local dialog = LFGDungeonReadyDialog
	if not dialog then
		return
	end
	local d = GetFFD(dialog)
	if not timerBar then
		timerBar = CreateFrame("StatusBar", nil, d.bgFrame or dialog)
		timerBar:SetMinMaxValues(0, TIMER_DURATION)
		timerBg = timerBar:CreateTexture(nil, "BACKGROUND")
		timerBg:SetAllPoints()
		timerBg:SetTexture(0, 0, 0, 0.7)
		timerBorder = timerBar:CreateTexture(nil, "OVERLAY")
		timerBorder:SetTexture("Interface\\CastingBar\\UI-CastingBar-Border")
		timerBorder:SetSize(256, 64)
		timerBorder:SetPoint("TOP", timerBar, 0, 28)
		timerText = timerBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		-- The bar follows the dialog's visibility.
		dialog:HookScript("OnHide", function()
			timerBar:SetScript("OnUpdate", nil)
			timerBar:Hide()
		end)
	end
	timerBar:SetFrameLevel(dialog:GetFrameLevel() + 5)
	timerBar:ClearAllPoints()
	if useEuiStyle then
		timerBar:SetStatusBarTexture(WHITE)
		local mult = PP.mult or 1
		timerBar:SetPoint("BOTTOMLEFT", dialog, "BOTTOMLEFT", mult, mult)
		timerBar:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -mult, mult)
		local r, g, b = BS.Accent()
		timerBar:SetStatusBarColor(r, g, b, 0.75)
		timerBg:SetTexture(0, 0, 0, 0.5)
		timerBorder:Hide()
		timerEUI = true
	else
		timerBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
		timerBar:SetPoint("TOP", dialog, "BOTTOM", 0, -5)
		timerBar:SetWidth(190)
		timerBar:SetStatusBarColor(1, 0.1, 0)
		timerBorder:Show()
		timerEUI = false
	end
	timerBg:Show()
	TT.RefreshQueueTimerStyle()
	timerEndTime = GetTime() + TIMER_DURATION
	timerBar:SetValue(TIMER_DURATION)
	timerText:SetText(format("%d", TIMER_DURATION))
	timerBar:Show()
	timerBar:SetScript("OnUpdate", TimerOnUpdate)
end

local function SkinQueueStatus()
	local status = LFGDungeonReadyStatus
	if not status or not queueActive then
		return
	end
	NoBackdrop(status)
	PopupBG(status)
	ApplyBorder(status, "popupMenu")
end

local function SkinRoleCheckPopup()
	local popup = LFDRoleCheckPopup
	if not popup or not queueActive then
		return
	end
	NoBackdrop(popup)
	PopupBG(popup)
	ApplyBorder(popup, "popupMenu")
	StyleButton(_G.LFDRoleCheckPopupAcceptButton)
	StyleButton(_G.LFDRoleCheckPopupDeclineButton)
end

local function InitQueuePopups()
	local f = CreateFrame("Frame")
	f:RegisterEvent("LFG_PROPOSAL_SHOW")
	f:RegisterEvent("LFG_PROPOSAL_FAILED")
	f:RegisterEvent("LFG_PROPOSAL_SUCCEEDED")
	f:SetScript("OnEvent", function(_, event)
		if event == "LFG_PROPOSAL_SHOW" then
			if queueActive then
				SkinQueuePopup()
			end
			if Get("showQueueTimer") ~= false then
				ShowQueueTimer(queueActive)
			end
		else
			SkinQueueStatus()
		end
	end)
	if not queueActive then
		return
	end
	if LFGDungeonReadyStatus then
		LFGDungeonReadyStatus:HookScript("OnShow", SkinQueueStatus)
	end
	if LFDRoleCheckPopup then
		LFDRoleCheckPopup:HookScript("OnShow", SkinRoleCheckPopup)
		if LFDRoleCheckPopup:IsShown() then
			SkinRoleCheckPopup()
		end
	end
	-- Blizzard re-sets the dialog backdrop per proposal type.
	if LFGDungeonReadyPopup_Update then
		hooksecurefunc("LFGDungeonReadyPopup_Update", function()
			if LFGDungeonReadyDialog and LFGDungeonReadyDialog:IsShown() then
				SkinQueuePopup()
			end
		end)
	end
end

-------------------------------------------------------------------------------
--  Game menu (GameMenuFrame)
-------------------------------------------------------------------------------
local function GameMenuButtons()
	local list = {}
	local kids = { GameMenuFrame:GetChildren() }
	for i = 1, #kids do
		local b = kids[i]
		if b and b.IsObjectType and b:IsObjectType("Button") and b.GetFontString and b:GetFontString() then
			list[#list + 1] = b
		end
	end
	return list
end

-- Retail's game menu button font is its template size minus 2 (16 - 2).
local GM_FONT_SIZE = 14
local function GameMenuButton(btn)
	local d = GetFFD(btn)
	local first = not d.popupSkinned
	-- Retail's menu buttons are white in the native mode (Blizzard's own
	-- color there); the 5.4.8 template is gold, so no nativeGold here.
	d.nativeGold = false
	StyleButton(btn, 2)
	if first then
		local fs = btn:GetFontString()
		if fs then
			fs:SetFont(BS.FontPath(), GM_FONT_SIZE, "")
		end
	end
end

-- Retail layout: a 255 px wide menu, 196 x 32 buttons (frame 200 x 36 with
-- the 2 px inset), 4 px between buttons, 16 px between groups, in retail's
-- order: Options + Shop | EllesmereUI (+ other addon buttons) | the
-- other Blizzard buttons | Log Out + Exit Game | Return to Game.
local GM_W, GM_BTN_W, GM_BTN_H = 255, 200, 36
local GM_GROUP_GAP, GM_TOP, GM_BOTTOM = 12, 48, 34
local GM_GROUPS = {
	{ "GameMenuButtonOptions", "GameMenuButtonMacOptions", "GameMenuButtonUIOptions", "GameMenuButtonStore" },
	false, -- addon buttons (EllesmereUI first)
	{ "GameMenuButtonKeybindings", "GameMenuButtonMacros", "GameMenuButtonHelp", "GameMenuButtonRatings" },
	{ "GameMenuButtonLogout", "GameMenuButtonQuit" },
	{ "GameMenuButtonContinue" },
}
local GM_KNOWN = {}
for _, g in ipairs(GM_GROUPS) do
	if g then
		for _, n in ipairs(g) do
			GM_KNOWN[n] = true
		end
	end
end

local function AddonMenuButtons()
	local list = {}
	for _, b in ipairs(GameMenuButtons()) do
		local n = b:GetName()
		if b:IsShown() and not (n and GM_KNOWN[n]) then
			list[#list + 1] = b
		end
	end
	table.sort(list, function(a, b)
		local na, nb = a:GetName() or "~", b:GetName() or "~"
		local ea, eb = na:find("EllesmereUI", 1, true) and 0 or 1, nb:find("EllesmereUI", 1, true) and 0 or 1
		if ea ~= eb then
			return ea < eb
		end
		-- EllesmereUI before its Unlock Mode button.
		if #na ~= #nb and ea == 0 then
			return #na < #nb
		end
		return na < nb
	end)
	return list
end

local gmLayoutBusy = false
local function LayoutGameMenu()
	if not gmActive or not GameMenuFrame or gmLayoutBusy then
		return
	end
	gmLayoutBusy = true
	local y = -GM_TOP
	local placedAny = false
	for _, g in ipairs(GM_GROUPS) do
		local buttons
		if g then
			buttons = {}
			for _, n in ipairs(g) do
				local b = _G[n]
				if b and b:IsShown() then
					buttons[#buttons + 1] = b
				end
			end
		else
			buttons = AddonMenuButtons()
		end
		if #buttons > 0 then
			if placedAny then
				y = y - GM_GROUP_GAP
			end
			for _, b in ipairs(buttons) do
				b:ClearAllPoints()
				b:SetSize(GM_BTN_W, GM_BTN_H)
				b:SetPoint("TOP", GameMenuFrame, "TOP", 0, y)
				y = y - GM_BTN_H
			end
			placedAny = true
		end
	end
	GameMenuFrame:SetSize(GM_W, -y + GM_BOTTOM)
	gmLayoutBusy = false
end
TT.LayoutGameMenu = LayoutGameMenu

local gmHeaderText
local function ApplyGameMenu()
	if not gmActive or not GameMenuFrame then
		return
	end
	NoBackdrop(GameMenuFrame)
	PopupBG(GameMenuFrame)
	ApplyBorder(GameMenuFrame, "popupMenu")
	if gmHeaderText then
		gmHeaderText:SetTextColor(ElementColor())
	end
	for _, btn in ipairs(GameMenuButtons()) do
		GameMenuButton(btn)
	end
	LayoutGameMenu()
end
TT.ApplyGameMenu = ApplyGameMenu

local function InitGameMenu()
	if not GameMenuFrame then
		return
	end
	local regions = { GameMenuFrame:GetRegions() }
	for i = 1, #regions do
		local r = regions[i]
		if r:IsObjectType("Texture") then
			r:SetAlpha(0)
		elseif r:IsObjectType("FontString") and not gmHeaderText then
			gmHeaderText = r
		end
	end
	if gmHeaderText then
		local _, hSize = gmHeaderText:GetFont()
		gmHeaderText:SetFont(BS.FontPath(), hSize or 16, "")
		gmHeaderText:ClearAllPoints()
		gmHeaderText:SetPoint("CENTER", GameMenuFrame, "TOP", 0, -28)
	end
	ApplyGameMenu()
	GameMenuFrame:HookScript("OnShow", function()
		ApplyGameMenu()
		-- Other addons (EllesmereUI core, ElvUI, ...) chain their buttons on
		-- show too: lay out again once they are done.
		BS.After(0, LayoutGameMenu)
	end)
	-- Blizzard (GameMenuFrame_UpdateVisibleButtons) and the EllesmereUI core
	-- re-anchor Log Out when they rebuild the list: re-apply our layout.
	if GameMenuButtonLogout then
		hooksecurefunc(GameMenuButtonLogout, "SetPoint", LayoutGameMenu)
	end
	if GameMenuFrame_UpdateVisibleButtons then
		hooksecurefunc("GameMenuFrame_UpdateVisibleButtons", LayoutGameMenu)
	end
	-- They also grow the menu height by their button count.
	hooksecurefunc(GameMenuFrame, "SetHeight", LayoutGameMenu)
end

-------------------------------------------------------------------------------
--  Anchoring: Anchor to Cursor, Fixed Position (Unlock Mode), Growth Direction
--  All ride the GameTooltip_SetDefaultAnchor post-hook (the path every
--  default-anchored tooltip takes). Explicitly anchored tooltips (SetOwner
--  with an anchor) are never touched.
-------------------------------------------------------------------------------
local POINT_FOR_POS = {
	bottomright = "TOPLEFT", bottomleft = "TOPRIGHT", topright = "BOTTOMLEFT", topleft = "BOTTOMRIGHT",
	right = "LEFT", left = "RIGHT", top = "BOTTOM", bottom = "TOP", center = "CENTER",
}
local cursorFrame
-- True while GameTooltip shows the world mouseover unit (set when the unit is
-- built; GetUnit() stops returning the token once the mouse has left).
local ttMouseoverUnit = false
-- True while GameTooltip rides the cursor (set by ApplyCursorAnchor, cleared
-- by every SetOwner). Frames the mouse has been off the owner for.
local ttOnCursor = false
local ownerLostFrames = 0

local function IsWorldOwner(owner)
	return owner == UIParent or owner == WorldFrame
end

-- 5.4.8 does not always hide a cursor tooltip when the mouse leaves what
-- opened it (the tip then stays glued to the cursor). Hide it ourselves.
local function CursorTipLost(tt)
	local owner = tt:GetOwner()
	if not owner then
		return true
	end
	if IsWorldOwner(owner) then
		-- The engine fades world tips (units, objects) in C code, without
		-- calling GameTooltip:FadeOut, so the FadeOut hook never runs.
		return tt:GetAlpha() < 0.99 or (ttMouseoverUnit and not UnitExists("mouseover"))
	end
	if Forbidden(owner) or not owner.IsMouseOver then
		return false
	end
	if owner:IsVisible() and owner:IsMouseOver(4, -4, -4, 4) then
		ownerLostFrames = 0
		return false
	end
	-- Two frames off the owner: skips one-frame gaps while the owner moves.
	ownerLostFrames = ownerLostFrames + 1
	return ownerLostFrames >= 2
end

local function EnsureCursorFrame()
	if cursorFrame then
		return cursorFrame
	end
	cursorFrame = CreateFrame("Frame", "EllesmereUI_TooltipCursorAnchor", UIParent)
	cursorFrame:SetSize(1, 1)
	cursorFrame:SetFrameStrata("TOOLTIP")
	cursorFrame:Hide()
	local lastX, lastY
	cursorFrame:SetScript("OnUpdate", function(self)
		local tt = GameTooltip
		if ttOnCursor and tt:IsShown() and not Forbidden(tt) and CursorTipLost(tt) then
			tt:Hide()
			return
		end
		local scale = UIParent:GetEffectiveScale()
		if not scale or scale <= 0 then
			return
		end
		local x, y = GetCursorPosition()
		if x ~= lastX or y ~= lastY then
			lastX, lastY = x, y
			self:ClearAllPoints()
			self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
		end
	end)
	return cursorFrame
end

local function CursorOn()
	return ttActive and Get("tooltipAnchorCursor") and true or false
end

local function ApplyCursorAnchor(tt)
	local cf = EnsureCursorFrame()
	cf:Show()
	local scale = UIParent:GetEffectiveScale()
	if scale and scale > 0 then
		local x, y = GetCursorPosition()
		cf:ClearAllPoints()
		cf:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
	end
	ttOnCursor = true
	ownerLostFrames = 0
	local point = POINT_FOR_POS[Get("tooltipCursorPosition") or "top"] or "BOTTOM"
	tt:ClearAllPoints()
	tt:SetPoint(point, cf, "CENTER", Get("tooltipCursorOffsetX") or 0, Get("tooltipCursorOffsetY") or 0)
end

-- Fixed box: the saved position (tooltipFixedPos = { centerX, centerY } from
-- the UIParent center), or, with none saved, a box whose bottom-right corner
-- is Blizzard's default tooltip spot (so Growth Direction can pin a corner).
local FIXED_W, FIXED_H = 280, 165
local anchorFrame
local fixedArmed, fixedEnforcing = false, false

local function EnsureFixedFrame()
	if not anchorFrame then
		anchorFrame = CreateFrame("Frame", "EllesmereUI_TooltipFixedAnchor", UIParent)
		anchorFrame:SetSize(FIXED_W, FIXED_H)
		anchorFrame:EnableMouse(false)
		anchorFrame:SetPoint("CENTER")
	end
	return anchorFrame
end

local function SavedPos()
	local pos = DB().tooltipFixedPos
	if type(pos) == "table" and pos.centerX and pos.centerY then
		return pos
	end
	return nil
end

local function PositionFixed()
	local af = EnsureFixedFrame()
	af:ClearAllPoints()
	local pos = SavedPos()
	if pos then
		af:SetPoint("CENTER", UIParent, "CENTER", pos.centerX, pos.centerY)
	else
		af:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -(CONTAINER_OFFSET_X or 0) - 13, CONTAINER_OFFSET_Y or 0)
	end
	return af
end
TT.PositionFixed = PositionFixed

local function GrowthDir()
	local dir = Get("tooltipGrowthDirection")
	if dir == "up" or dir == "down" then
		return dir
	end
	return nil
end

local function WantFixed()
	if not ttActive or CursorOn() then
		return false
	end
	return SavedPos() ~= nil or GrowthDir() ~= nil
end

local function CornerFor()
	local cx, cy
	local pos = SavedPos()
	if pos then
		cx, cy = pos.centerX, pos.centerY
	else
		cx, cy = 1, -1 -- Blizzard's spot: bottom right
	end
	local dir = GrowthDir()
	local vert = (dir == "down" and "TOP") or (dir == "up" and "BOTTOM") or ((cy < 0) and "BOTTOM" or "TOP")
	return vert .. ((cx < 0) and "LEFT" or "RIGHT")
end

local function EnforceFixed(tt)
	if not WantFixed() or not anchorFrame then
		return
	end
	local corner = CornerFor()
	local point, relTo = tt:GetPoint(1)
	if tt:GetNumPoints() == 1 and point == corner and relTo == anchorFrame then
		return
	end
	fixedEnforcing = true
	tt:ClearAllPoints()
	tt:SetPoint(corner, anchorFrame, corner, 0, 0)
	fixedEnforcing = false
end

-------------------------------------------------------------------------------
--  Show Tooltips mode (tooltipShowMode): always | outOfCombat |
--  outOfBossCombat | never, with a peek modifier. A suppressed tooltip is
--  parked in a hidden host frame (it stays "shown"), so peek is a reparent.
-------------------------------------------------------------------------------
local inEncounter = false
local parked = false
local origParent
local suppressHost = CreateFrame("Frame", nil, UIParent)
suppressHost:Hide()

local function ShowModifierHeld()
	local mod = Get("tooltipShowModifier") or "none"
	if mod == "none" then
		return false
	end
	return ModifierHeld(mod)
end
TT.PeekHeld = ShowModifierHeld

local function EncounterInProgress()
	if IsEncounterInProgress then
		local ok, v = pcall(IsEncounterInProgress)
		if ok and v ~= nil then
			return v and true or false
		end
	end
	return inEncounter
end

local function Suppressed(tt)
	if tt ~= GameTooltip or not ttActive then
		return false
	end
	local mode = Get("tooltipShowMode") or "always"
	if mode == "always" or ShowModifierHeld() then
		return false
	end
	if mode == "never" then
		return true
	elseif mode == "outOfCombat" then
		return InCombatLockdown() or UnitAffectingCombat("player") and true or false
	elseif mode == "outOfBossCombat" then
		return EncounterInProgress()
	end
	return false
end
TT.Suppressed = Suppressed

local function HideShopping()
	for i = 1, 3 do
		local s = _G["ShoppingTooltip" .. i]
		if s and s:IsShown() and parked then
			s:Hide()
		end
	end
end

local function Park(tt)
	if parked then
		return
	end
	parked = true
	origParent = tt:GetParent()
	if origParent == suppressHost then
		origParent = nil
	end
	tt:SetParent(suppressHost)
	BS.After(0, HideShopping)
end
local function Unpark(tt)
	if not parked then
		return
	end
	parked = false
	tt:SetParent(origParent or UIParent)
	tt:SetFrameStrata("TOOLTIP")
end
local function ApplySuppression(tt)
	if Suppressed(tt) then
		Park(tt)
	else
		Unpark(tt)
	end
end

local stateWatcher
local function UpdateStateWatcher()
	local mode = Get("tooltipShowMode") or "always"
	local need = ttActive and (mode == "outOfCombat" or mode == "outOfBossCombat")
	if not stateWatcher then
		if not need then
			return
		end
		stateWatcher = CreateFrame("Frame")
		stateWatcher:SetScript("OnEvent", function(_, event)
			if event == "ENCOUNTER_START" then
				inEncounter = true
			elseif event == "ENCOUNTER_END" then
				inEncounter = false
			end
			if Suppressed(GameTooltip) and GameTooltip:IsShown() then
				Park(GameTooltip)
			end
		end)
	end
	if need then
		stateWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
		stateWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
		stateWatcher:RegisterEvent("ENCOUNTER_START")
		stateWatcher:RegisterEvent("ENCOUNTER_END")
	else
		stateWatcher:UnregisterAllEvents()
	end
	if (mode == "always" or not ttActive) and parked then
		Unpark(GameTooltip)
	end
end

-- Peek while already hovering: re-run the hovered frame's OnEnter.
local function FireHoveredOnEnter()
	local frame = GetMouseFocus and GetMouseFocus()
	local anchor = frame
	while frame and frame ~= WorldFrame and frame ~= UIParent do
		if Forbidden(frame) then
			break
		end
		-- Action buttons are protected, but their OnEnter only builds the
		-- tooltip (5.4.8 has no secret values), so peek can re-run it.
		local protected = frame.IsProtected and frame:IsProtected() and frame.action == nil
		if not protected and frame.GetScript then
			local ok, onEnter = pcall(frame.GetScript, frame, "OnEnter")
			if ok and onEnter then
				pcall(onEnter, frame)
				if GameTooltip:IsShown() then
					return
				end
				anchor = frame
				break
			end
		end
		frame = frame.GetParent and frame:GetParent()
	end
	if not GameTooltip:IsShown() and UnitExists("mouseover") then
		GameTooltip_SetDefaultAnchor(GameTooltip, anchor or UIParent)
		GameTooltip:SetUnit("mouseover")
		GameTooltip:Show()
	end
end

local function KeyMatches(key, mod)
	return (mod == "shift" and (key == "LSHIFT" or key == "RSHIFT"))
		or (mod == "control" and (key == "LCTRL" or key == "RCTRL"))
		or (mod == "alt" and (key == "LALT" or key == "RALT"))
end

local function InitAnchoring()
	-- One post-hook for every default-anchored tooltip.
	hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tt, parent)
		if tt ~= GameTooltip or not ttActive or Forbidden(tt) then
			return
		end
		if CursorOn() then
			if IsWorldOwner(parent) and not UnitExists("mouseover") then
				-- World object (corpse, chest, mailbox): no unit to watch and
				-- the engine never fades it on our anchor. Let the engine
				-- follow the cursor so it hides the tip itself.
				tt:SetOwner(parent, "ANCHOR_CURSOR")
			else
				ApplyCursorAnchor(tt)
			end
		elseif WantFixed() then
			fixedArmed = true
			PositionFixed()
			EnforceFixed(tt)
		end
		if (Get("tooltipShowMode") or "always") ~= "always" then
			ApplySuppression(tt)
		end
	end)
	-- Every tooltip build starts with SetOwner: disarm (explicit anchors stay)
	-- and restore a parked tooltip before the new build.
	hooksecurefunc(GameTooltip, "SetOwner", function(tt)
		fixedArmed = false
		ttOnCursor = false
		Unpark(tt)
		if (Get("tooltipShowMode") or "always") ~= "always" then
			ApplySuppression(tt)
		end
	end)
	-- Blizzard can re-point the tooltip after show (comparison slide): keep it
	-- on the fixed corner while a default-anchored tooltip is up.
	hooksecurefunc(GameTooltip, "SetPoint", function(tt)
		if fixedEnforcing or not fixedArmed then
			return
		end
		EnforceFixed(tt)
	end)
	GameTooltip:HookScript("OnShow", function(tt)
		if (Get("tooltipShowMode") or "always") ~= "always" then
			ApplySuppression(tt)
		end
	end)
	GameTooltip:HookScript("OnHide", function()
		ttMouseoverUnit = false
		ttOnCursor = false
		if cursorFrame then
			cursorFrame:Hide()
		end
	end)
	GameTooltip:HookScript("OnTooltipCleared", function()
		ttMouseoverUnit = false
	end)
	GameTooltip:HookScript("OnTooltipSetUnit", function(tt)
		-- A UIParent-owned unit tip built while a unit is under the mouse is
		-- the world mouseover tip (the engine may not report the token).
		ttMouseoverUnit = IsWorldOwner(tt:GetOwner()) and UnitExists("mouseover") and true or false
	end)
	-- World unit tooltips fade out slowly; while on the cursor, hide at once.
	if GameTooltip.FadeOut then
		hooksecurefunc(GameTooltip, "FadeOut", function(self)
			if self == GameTooltip and CursorOn() then
				self:Hide()
			end
		end)
	end
	local modWatcher = CreateFrame("Frame")
	modWatcher:RegisterEvent("MODIFIER_STATE_CHANGED")
	modWatcher:SetScript("OnEvent", function(_, _, key, down)
		if not ttActive then
			return
		end
		local mod = Get("tooltipShowModifier") or "none"
		if mod == "none" or not KeyMatches(key, mod) then
			return
		end
		if down == 1 then
			if parked and GameTooltip:IsShown() then
				Unpark(GameTooltip)
				-- On 5.4.8 the hidden host hides the tooltip for the engine,
				-- which empties it; an empty tip is rebuilt from the hover.
				if (GameTooltip:NumLines() or 0) > 0 then
					return
				end
				GameTooltip:Hide()
			end
			FireHoveredOnEnter()
		elseif GameTooltip:IsShown() and Suppressed(GameTooltip) then
			Park(GameTooltip)
		end
	end)
	UpdateStateWatcher()
end

-------------------------------------------------------------------------------
--  Unlock Mode: "Tooltip" mover for the fixed position. Hidden while Anchor to
--  Cursor is on or the tooltip reskin is off.
-------------------------------------------------------------------------------
function TT.ResetFixedPosition()
	DB().tooltipFixedPos = nil
	PositionFixed()
end

local function RegisterUnlock()
	if not ns.RegisterUnlockElements then
		return
	end
	ns:RegisterUnlockElements({
		ns.MakeUnlockElement({
			key = "EUI_TooltipAnchor",
			label = "Tooltip",
			group = "Blizzard Windows",
			order = 650,
			subtitle = "Fixed Position",
			noResize = true,
			noAnchorTarget = true,
			noAnchorTo = true,
			noSizeMatchTarget = true,
			isHidden = function()
				return not ttActive or CursorOn()
			end,
			getFrame = function()
				local af = EnsureFixedFrame()
				if af:GetNumPoints() == 0 then
					PositionFixed()
				end
				return af
			end,
			getSize = function()
				local af = EnsureFixedFrame()
				return af:GetWidth(), af:GetHeight()
			end,
			savePos = function(_, point, relPoint, x, y)
				if point == "CENTER" and (relPoint or "CENTER") == "CENTER" then
					DB().tooltipFixedPos = { centerX = x, centerY = y }
				end
				if not ns._unlockActive then
					PositionFixed()
				end
			end,
			loadPos = function()
				local pos = SavedPos()
				if pos then
					return { point = "CENTER", relPoint = "CENTER", x = pos.centerX, y = pos.centerY }
				end
				return nil
			end,
			clearPos = function()
				DB().tooltipFixedPos = nil
			end,
			applyPos = function()
				PositionFixed()
			end,
		}),
	}, "EllesmereUIBlizzardSkin")
end
RegisterUnlock()

-------------------------------------------------------------------------------
--  UberTooltips CVar (Detailed Tooltips): enforced at login only after the
--  user set it in EllesmereUI.
-------------------------------------------------------------------------------
local function SetUber(value)
	if ns.SetCVarSafe then
		ns.SetCVarSafe("UberTooltips", value)
	elseif SetCVar then
		pcall(SetCVar, "UberTooltips", value)
	end
end

function TT.SetUberTooltips(on)
	local db = DB()
	db.uberTooltipsManual = true
	db.uberTooltips = on and true or false
	SetUber(on and "1" or "0")
end

local function ApplyUberTooltips()
	local db = DB()
	if db.uberTooltipsManual then
		SetUber(db.uberTooltips and "1" or "0")
	else
		SetUber("1")
	end
end

-------------------------------------------------------------------------------
--  Live apply (every settings change) and login
-------------------------------------------------------------------------------
BS.OnApply(function()
	TT.ApplyHealthStrip()
	TT.ApplyHealthStripStyle()
	TT.RefreshQueueTimerStyle()
	TT.EnsureResurrectGlow()
	if ttActive then
		for _, name in ipairs(TOOLTIP_NAMES) do
			local tt = _G[name]
			if tt and tt.IsShown and tt:IsShown() then
				SkinTooltip(tt)
				TooltipFonts(tt)
			end
		end
		if buffBox and buffBox:IsShown() then
			TT.LayoutBuffs(GameTooltip:IsShown() and select(2, GameTooltip:GetUnit()) or nil)
		end
	end
	if cursorFrame and not CursorOn() then
		cursorFrame:Hide()
	end
	if anchorFrame then
		PositionFixed()
	end
	UpdateStateWatcher()
	if pmActive then
		for i = 1, (UIDROPDOWNMENU_MAXLEVELS or 2) do
			local list = _G["DropDownList" .. i]
			if list and list:IsShown() then
				SkinDropList(list)
			end
		end
		for i = 1, (STATICPOPUP_NUMDIALOGS or 4) do
			local popup = _G["StaticPopup" .. i]
			if popup and popup:IsShown() then
				SkinPopup(popup)
			end
		end
	end
	if gmActive and GameMenuFrame and GameMenuFrame:IsShown() then
		ApplyGameMenu()
	end
end)

BS.OnAccentChanged(function()
	TT.RefreshQueueTimerStyle()
end)

BS.OnLogin(function()
	local elvTT = TT.ElvUITooltipOn()
	ttActive = Get("customTooltips") ~= false and not elvTT
	pmActive = Get("reskinPopupsMenus") ~= false and not TT.ElvUIMiscOn()
	gmActive = Get("reskinGameMenu") ~= false and not TT.ElvUIMiscOn()
	queueActive = Get("reskinQueuePopup") ~= false and not TT.ElvUILFGOn()

	local function Step(fn)
		local ok, err = pcall(fn)
		if not ok then
			geterrorhandler()(err)
		end
	end
	Step(ApplyUberTooltips)
	if not elvTT then
		Step(InitHealthStrip)
	end
	-- Max stack works without the reskin.
	Step(function()
		GameTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
		if ItemRefTooltip then
			ItemRefTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
		end
	end)
	if ttActive then
		Step(InitTooltipData)
		Step(InitTooltipVisual)
		Step(InitAnchoring)
	end
	if pmActive then
		Step(InitMenus)
		Step(InitPopups)
	end
	Step(InitQueuePopups)
	if gmActive then
		Step(InitGameMenu)
	end
	Step(TT.EnsureResurrectGlow)
end)
