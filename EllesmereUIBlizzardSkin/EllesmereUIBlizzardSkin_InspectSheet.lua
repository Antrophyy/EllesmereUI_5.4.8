-------------------------------------------------------------------------------
--  EllesmereUIBlizzardSkin_InspectSheet.lua (5.4.8 port)
--  The inspect window (InspectFrame, Blizzard_InspectUI) in the look of the
--  character sheet: same backdrop, slot grid, rarity borders, model art and
--  tabs, plus item level, upgrade level, enchant and gem text on every slot
--  and the average item level of the inspected player.
--
--  It follows the Character Sheet style (Blizzard Skins > Character Sheet):
--    EllesmereUI / Modern -> the full skin and the slot text.
--    Blizz Default        -> Blizzard's window, only the slot text.
--    Off                  -> nothing.
--  "Enable Inspect Sheet" (Character Sheet page) turns it off on its own.
--
--  5.4.8 differences from retail:
--   - item level / upgrade level / enchant come from a scanning tooltip
--     (5.4.8 has no C_Item / GetDetailedItemLevelInfo), like the char sheet;
--   - the average item level is computed from the slots (no inspect API);
--   - no M+ score, no transmog "View" button, no docking (the 5.4.8 panel
--     manager already puts the inspect and character windows side by side).
-------------------------------------------------------------------------------
local addonName = ...
local ns = EllesmereUI
local BS = ns.BlizzSkin
local WSkin = ns.WSkin

local floor, min, max = math.floor, math.min, math.max
local MEDIA = BS.MEDIA .. "charsheet\\"
local ICON_COORD = 30 / 32 -- 30 x 30 icons in a 32 x 32 TGA (char sheet art)
local MISSING_RED = { r = 0.898, g = 0.286, b = 0.286 }

-- Settings (root keys, retail names). Unset = default.
BS.defaults.themedInspectSheet = true
BS.defaults.inspectShowItemLevel = true
BS.defaults.inspectShowUpgradeTrack = true
BS.defaults.inspectShowEnchants = true
BS.defaults.inspectEnchantNames = false
BS.defaults.inspectShowGems = true

local GEAR_SLOTS = {
	"InspectHeadSlot", "InspectNeckSlot", "InspectShoulderSlot", "InspectBackSlot",
	"InspectChestSlot", "InspectWaistSlot", "InspectLegsSlot", "InspectFeetSlot",
	"InspectWristSlot", "InspectHandsSlot", "InspectFinger0Slot", "InspectFinger1Slot",
	"InspectTrinket0Slot", "InspectTrinket1Slot", "InspectMainHandSlot", "InspectSecondaryHandSlot",
}
local ALL_SLOTS = {
	"InspectHeadSlot", "InspectNeckSlot", "InspectShoulderSlot", "InspectBackSlot",
	"InspectChestSlot", "InspectShirtSlot", "InspectTabardSlot", "InspectWristSlot",
	"InspectHandsSlot", "InspectWaistSlot", "InspectLegsSlot", "InspectFeetSlot",
	"InspectFinger0Slot", "InspectFinger1Slot", "InspectTrinket0Slot", "InspectTrinket1Slot",
	"InspectMainHandSlot", "InspectSecondaryHandSlot",
}
-- Retail grid: 2 columns 280 px apart, 41 px rows from y -60.
local SLOT_GRID = {
	InspectHeadSlot = { 0, 0 }, InspectNeckSlot = { 0, 1 }, InspectShoulderSlot = { 0, 2 },
	InspectBackSlot = { 0, 3 }, InspectChestSlot = { 0, 4 }, InspectShirtSlot = { 0, 5 },
	InspectTabardSlot = { 0, 6 }, InspectWristSlot = { 0, 7 },
	InspectHandsSlot = { 1, 0 }, InspectWaistSlot = { 1, 1 }, InspectLegsSlot = { 1, 2 },
	InspectFeetSlot = { 1, 3 }, InspectFinger0Slot = { 1, 4 }, InspectFinger1Slot = { 1, 5 },
	InspectTrinket0Slot = { 1, 6 }, InspectTrinket1Slot = { 1, 7 },
}
-- Text on the right side of the slot (left column and the off hand).
local TEXT_RIGHT = {
	InspectHeadSlot = true, InspectNeckSlot = true, InspectShoulderSlot = true,
	InspectBackSlot = true, InspectChestSlot = true, InspectWristSlot = true,
	InspectSecondaryHandSlot = true,
}
-- Slots that take an enchant in Mists of Pandaria (rings: enchanters only,
-- unknown for another player, so never "Missing").
local ENCHANT_SLOTS = { [3] = true, [5] = true, [7] = true, [8] = true, [9] = true, [10] = true, [15] = true, [16] = true, [17] = true }
-- Slots counted in the average item level (no shirt, no tabard).
local AVG_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 }
local TWO_HAND = { INVTYPE_2HWEAPON = true, INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true }

local EMPTY_SOCKET_TEXTURES = {
	EMPTY_SOCKET_META = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Meta",
	EMPTY_SOCKET_RED = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Red",
	EMPTY_SOCKET_YELLOW = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Yellow",
	EMPTY_SOCKET_BLUE = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Blue",
	EMPTY_SOCKET_PRISMATIC = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Prismatic",
	EMPTY_SOCKET_NO_COLOR = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Prismatic",
	EMPTY_SOCKET_COGWHEEL = "Interface\\ItemSocketingFrame\\UI-EmptySocket-CogWheel",
	EMPTY_SOCKET_HYDRAULIC = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Hydraulic",
}

-- Per-frame state: our own weak table (no keys on Blizzard frames).
local FFD = setmetatable({}, { __mode = "k" })
local function GetFFD(frame)
	local d = FFD[frame]
	if not d then
		d = {}
		FFD[frame] = d
	end
	return d
end

-------------------------------------------------------------------------------
--  Style (latched at login, like the character sheet: a change between the
--  EllesmereUI looks and Blizz Default / Off needs a reload)
-------------------------------------------------------------------------------
local activeStyle, enabledAtLogin

local function CS()
	return ns.GetCharSheetDB and ns.GetCharSheetDB() or {}
end

local function SheetOn()
	return enabledAtLogin and activeStyle ~= nil and activeStyle ~= "off"
end

-- The full skin: EllesmereUI or Modern, and ElvUI's inspect skin not on.
local function Themed()
	if not SheetOn() then
		return false
	end
	if activeStyle ~= "eui" and activeStyle ~= "modern" then
		return false
	end
	return not BS.ElvUISkins("inspect")
end

local function Stock()
	return SheetOn() and not Themed()
end

-------------------------------------------------------------------------------
--  Helpers
-------------------------------------------------------------------------------
local function SetFont(fs, size, flags)
	if ns.ApplyModuleFont then
		ns.ApplyModuleFont(fs, size, "blizzardSkin", (flags ~= "" and flags) or nil)
		return
	end
	fs:SetFont(BS.FontPath(), size, flags or "")
end

local function NewText(parent, size, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	SetFont(fs, size)
	return fs
end

local function Solid(parent, layer, r, g, b, a, sub)
	return BS.SolidTex(parent, layer, r, g, b, a, sub)
end

-- Border of 4 textures inside the frame edges (char sheet CreateBorder).
local function CreateBorder(frame, thickness, r, g, b, a, layer)
	local edges = {}
	local function Edge()
		local t = frame:CreateTexture(nil, layer or "OVERLAY")
		t:SetTexture(r, g, b, a)
		edges[#edges + 1] = t
		return t
	end
	local top = Edge()
	top:SetPoint("TOPLEFT")
	top:SetPoint("TOPRIGHT")
	top:SetHeight(thickness)
	local bottom = Edge()
	bottom:SetPoint("BOTTOMLEFT")
	bottom:SetPoint("BOTTOMRIGHT")
	bottom:SetHeight(thickness)
	local left = Edge()
	left:SetPoint("TOPLEFT", 0, -thickness)
	left:SetPoint("BOTTOMLEFT", 0, thickness)
	left:SetWidth(thickness)
	local right = Edge()
	right:SetPoint("TOPRIGHT", 0, -thickness)
	right:SetPoint("BOTTOMRIGHT", 0, thickness)
	right:SetWidth(thickness)
	edges.SetColor = function(self, nr, ng, nb, na)
		for i = 1, 4 do
			self[i]:SetTexture(nr, ng, nb, na)
		end
	end
	return edges
end

local function FadeRegions(frame, keep)
	WSkin.FadeRegions(frame, keep)
end

local function QualityColor(quality)
	if quality and GetItemQualityColor then
		local r, g, b = GetItemQualityColor(quality)
		if r then
			return r, g, b
		end
	end
	return 1, 1, 1
end

local function ShowTextTooltip(owner, text)
	if not text or text == "" then
		return
	end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText(text, 1, 1, 1, 1, true)
	GameTooltip:Show()
end

local function HideTooltip()
	GameTooltip:Hide()
end

local function Unit()
	return InspectFrame and InspectFrame.unit
end

-------------------------------------------------------------------------------
--  Scanning tooltip: upgraded item level, upgrade level and enchant of an
--  inspected item (5.4.8 GetItemInfo has the base item level only).
-------------------------------------------------------------------------------
local scanTip
local ITEM_LEVEL_PATTERN, UPGRADE_PATTERN, ENCHANT_PATTERN

local function ToPattern(fmt)
	local p = fmt:gsub("([%(%)%.%[%]%^%$%*%+%-%?])", "%%%1")
	p = p:gsub("%%d", "(%%d+)"):gsub("%%s", "(.+)")
	return "^" .. p .. "$"
end

local function EnsureScanTip()
	if scanTip then
		return scanTip
	end
	scanTip = CreateFrame("GameTooltip", "EUI_InspectSheetScanTip", nil, "GameTooltipTemplate")
	scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
	ITEM_LEVEL_PATTERN = ToPattern(ITEM_LEVEL or "Item Level %d")
	UPGRADE_PATTERN = ToPattern(ITEM_UPGRADE_TOOLTIP_FORMAT or "Upgrade Level: %d/%d")
	ENCHANT_PATTERN = ToPattern(ENCHANTED_TOOLTIP_LINE or "Enchanted: %s")
	return scanTip
end

-- [unit guid .. slot .. link] = { ilvl, upCur, upMax, enchant }
local scanCache = {}

local function ScanSlot(unit, slotID, link)
	local key = (UnitGUID(unit) or unit) .. ":" .. slotID .. ":" .. link
	local cached = scanCache[key]
	if cached then
		return cached
	end
	local tip = EnsureScanTip()
	tip:ClearLines()
	tip:SetOwner(WorldFrame, "ANCHOR_NONE")
	tip:SetInventoryItem(unit, slotID)
	local info = {}
	for i = 2, (tip:NumLines() or 0) do
		local fs = _G["EUI_InspectSheetScanTipTextLeft" .. i]
		local text = fs and fs:GetText()
		if text and text ~= "" then
			if not info.ilvl then
				local lvl = text:match(ITEM_LEVEL_PATTERN)
				if lvl then
					info.ilvl = tonumber(lvl)
				end
			end
			if not info.upCur then
				local cur, mx = text:match(UPGRADE_PATTERN)
				if cur then
					info.upCur, info.upMax = tonumber(cur), tonumber(mx)
				end
			end
			if not info.enchant then
				local ench = text:match(ENCHANT_PATTERN)
				if ench then
					info.enchant = ench
				end
			end
		end
	end
	if info.ilvl then
		scanCache[key] = info
	end
	return info
end

-- Item level of a slot: the tooltip's (upgraded) level, else the base level.
local function SlotItemLevel(unit, slotID)
	local link = GetInventoryItemLink(unit, slotID)
	if not link then
		return nil
	end
	local info = ScanSlot(unit, slotID, link)
	if info and info.ilvl then
		return info.ilvl, link
	end
	local _, _, _, ilvl = GetItemInfo(link)
	return ilvl, link
end

-- Average equipped item level of the inspected player (Blizzard's rule: 16
-- slots, an empty off hand next to a two-hander counts the two-hander twice).
-- Returns nil while an item is still loading.
local function AverageItemLevel(unit)
	local total, complete = 0, true
	for _, slotID in ipairs(AVG_SLOTS) do
		local ilvl = SlotItemLevel(unit, slotID)
		if ilvl then
			total = total + ilvl
		elseif GetInventoryItemTexture(unit, slotID) then
			complete = false
		end
	end
	-- Two-hander with an empty off hand.
	local mh = GetInventoryItemLink(unit, 16)
	if mh and not GetInventoryItemLink(unit, 17) and not GetInventoryItemTexture(unit, 17) then
		local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(mh)
		if equipLoc and TWO_HAND[equipLoc] then
			total = total + (SlotItemLevel(unit, 16) or 0)
		end
	end
	if not complete or total <= 0 then
		return nil
	end
	return total / #AVG_SLOTS
end

-------------------------------------------------------------------------------
--  State
-------------------------------------------------------------------------------
local S = {
	slots = {}, -- [slotName] = { border, itemLevel, upgrade, enchant, enchantHover, gems }
	tabs = {},
}

-------------------------------------------------------------------------------
--  Window chrome (EllesmereUI / Modern)
-------------------------------------------------------------------------------
do
	local BG_ASPECT = 561 / 433

	local function UpdateBackdropCoords()
		local bg = S.bg
		if not bg then
			return
		end
		local fw, fh = InspectFrame:GetSize()
		if not fw or fw == 0 or not fh or fh == 0 then
			return
		end
		local fa = fw / fh
		if fa > BG_ASPECT then
			local trim = (1 - BG_ASPECT / fa) / 2
			bg:SetTexCoord(0, 1, trim, 1 - trim)
		else
			local trim = (1 - fa / BG_ASPECT) / 2
			bg:SetTexCoord(trim, 1 - trim, 0, 1)
		end
	end

	-- EllesmereUI art or the Modern flat color of the character sheet.
	function S.ApplyBackdropStyle()
		if not S.bg then
			return
		end
		local db = CS()
		if db.style == "modern" then
			S.bg:SetAlpha(0)
			S.bgOverlay:SetAlpha(0)
			local c = db.modernColor or { 0.067, 0.067, 0.067 }
			S.modernBg:SetTexture(c[1], c[2], c[3], (db.modernAlpha or 97) / 100)
		else
			S.bg:SetAlpha(1)
			S.bgOverlay:SetAlpha(1)
			S.modernBg:SetTexture(0, 0, 0, 0)
		end
	end

	function S.ApplyIconZoom()
		if not Themed() then
			return
		end
		local z = (CS().iconZoom or 7) / 100
		for _, slotName in ipairs(ALL_SLOTS) do
			local icon = _G[slotName .. "IconTexture"]
			if icon then
				icon:SetTexCoord(z, 1 - z, z, 1 - z)
			end
		end
	end

	local MODEL_ART = {
		"InspectModelFrameBackgroundTopLeft", "InspectModelFrameBackgroundTopRight",
		"InspectModelFrameBackgroundBotLeft", "InspectModelFrameBackgroundBotRight",
		"InspectModelFrameBackgroundOverlay",
		"InspectModelFrameBorderTopLeft", "InspectModelFrameBorderTopRight",
		"InspectModelFrameBorderBottomLeft", "InspectModelFrameBorderBottomRight",
		"InspectModelFrameBorderLeft", "InspectModelFrameBorderRight",
		"InspectModelFrameBorderTop", "InspectModelFrameBorderBottom", "InspectModelFrameBorderBottom2",
	}
	local MODEL_CONTROLS = {
		"InspectModelFrameControlFrameZoomInButton", "InspectModelFrameControlFrameZoomOutButton",
		"InspectModelFrameControlFramePanButton", "InspectModelFrameControlFrameRotateLeftButton",
		"InspectModelFrameControlFrameRotateRightButton", "InspectModelFrameControlFrameRotateResetButton",
	}

	local function SkinModel()
		local model = InspectModelFrame
		if not model then
			return
		end
		for _, n in ipairs(MODEL_ART) do
			local t = _G[n]
			if t and t.SetAlpha then
				t:SetAlpha(0)
			end
		end
		-- The model control strip (zoom / rotate) stays hidden, like retail.
		local cf = InspectModelFrameControlFrame
		if cf then
			cf:SetAlpha(0)
			cf:EnableMouse(false)
		end
		for _, n in ipairs(MODEL_CONTROLS) do
			local b = _G[n]
			if b then
				b:SetAlpha(0)
				b:EnableMouse(false)
			end
		end
		-- The model fills the space between the slot columns, down to the weapons.
		if InspectHeadSlot and InspectHandsSlot and InspectMainHandSlot then
			model:ClearAllPoints()
			model:SetPoint("TOPLEFT", InspectHeadSlot, "TOPRIGHT", 0, 0)
			model:SetPoint("TOPRIGHT", InspectHandsSlot, "TOPLEFT", 0, 0)
			model:SetPoint("BOTTOM", InspectMainHandSlot, "TOP", 0, 4)
		end
		-- character-bg behind the gear and the model (char sheet art).
		local bgFrame = CreateFrame("Frame", nil, InspectPaperDollFrame or InspectFrame)
		bgFrame:SetFrameLevel(max(0, model:GetFrameLevel() - 1))
		if InspectHeadSlot and InspectHandsSlot then
			bgFrame:SetPoint("TOPLEFT", InspectHeadSlot, "TOPLEFT", -8, 10)
			bgFrame:SetPoint("RIGHT", InspectHandsSlot, "RIGHT", 8, 0)
			bgFrame:SetPoint("BOTTOM", model, "BOTTOM", 0, -18)
		else
			bgFrame:SetPoint("TOPLEFT", model, "TOPLEFT", -8, 10)
			bgFrame:SetPoint("BOTTOMRIGHT", model, "BOTTOMRIGHT", 0, -18)
		end
		local bgTex = bgFrame:CreateTexture(nil, "BACKGROUND")
		bgTex:SetAllPoints(bgFrame)
		bgTex:SetTexture(MEDIA .. "character-bg")
		S.modelBg = bgFrame
	end

	local function SkinSlots()
		for _, slotName in ipairs(ALL_SLOTS) do
			local slot = _G[slotName]
			if slot then
				-- Bronze slot frame and weapon ornaments (BACKGROUND), quickslot art.
				local regions = { slot:GetRegions() }
				for i = 1, #regions do
					local r = regions[i]
					if r and r.IsObjectType and r:IsObjectType("Texture") and r:GetDrawLayer() == "BACKGROUND"
						and r ~= _G[slotName .. "IconTexture"] then
						r:SetAlpha(0)
					end
				end
				local frameTex = _G[slotName .. "Frame"]
				if frameTex and frameTex.SetAlpha then
					frameTex:SetAlpha(0)
				end
				local normal = _G[slotName .. "NormalTexture"] or (slot.GetNormalTexture and slot:GetNormalTexture())
				if normal then
					normal:SetAlpha(0)
				end
				local holder = CreateFrame("Frame", nil, slot)
				holder:SetAllPoints(slot)
				holder:SetFrameLevel(slot:GetFrameLevel() + 1)
				local data = S.slots[slotName] or {}
				S.slots[slotName] = data
				data.border = CreateBorder(holder, 2, 0.4, 0.4, 0.4, 1, "OVERLAY")
			end
		end
		-- Retail grid inside the 338 px window.
		local items = InspectPaperDollItemsFrame or InspectFrame
		for slotName, grid in pairs(SLOT_GRID) do
			local slot = _G[slotName]
			if slot then
				slot:ClearAllPoints()
				slot:SetPoint("TOPLEFT", items, "TOPLEFT", 10 + grid[1] * 280, -60 - grid[2] * 41)
			end
		end
		if InspectMainHandSlot and InspectSecondaryHandSlot then
			InspectMainHandSlot:ClearAllPoints()
			InspectMainHandSlot:SetPoint("BOTTOMLEFT", InspectFrame, "BOTTOMLEFT", 128, 10)
			InspectSecondaryHandSlot:ClearAllPoints()
			InspectSecondaryHandSlot:SetPoint("TOPLEFT", InspectMainHandSlot, "TOPRIGHT", 12, 0)
		end
		S.ApplyIconZoom()
	end

	-- Bottom tabs: the character sheet tab (flat block, own 9 px label,
	-- accent underline on the active tab). Blizzard's text hides behind a
	-- transparent font (PanelTemplates set a new font object on every change).
	local hiddenTabFont
	local function HideTabText(tab)
		if not hiddenTabFont then
			hiddenTabFont = CreateFont("EUI_InspectSheetHiddenTabFont")
			hiddenTabFont:SetFontObject(GameFontNormalSmall)
			hiddenTabFont:SetTextColor(0, 0, 0, 0)
			hiddenTabFont:SetShadowColor(0, 0, 0, 0)
		end
		tab:SetNormalFontObject(hiddenTabFont)
		tab:SetHighlightFontObject(hiddenTabFont)
		tab:SetDisabledFontObject(hiddenTabFont)
		local fs = tab:GetFontString()
		if fs then
			fs:SetTextColor(0, 0, 0, 0)
			fs:SetShadowColor(0, 0, 0, 0)
		end
	end

	function S.UpdateTabVisuals()
		local frame = InspectFrame
		if not frame then
			return
		end
		local sel = frame.selectedTab or 1
		local barsOn = WSkin.AccentBarShown()
		for i, tab in ipairs(S.tabs) do
			local d = FFD[tab]
			if d then
				local active = sel == i
				local alpha = active and 1 or 0.5
				if not active and tab.IsEnabled and not tab:IsEnabled() then
					alpha = 0.25 -- disabled (no talents / no guild)
				end
				d.label:SetTextColor(1, 1, 1, alpha)
				d.underline:SetShown(active and barsOn)
				d.activeHL:SetShown(active)
			end
		end
		if S.modelBg then
			S.modelBg:SetShown(sel == 1)
		end
	end

	local function NormalizeTabRow()
		local prev
		for _, tab in ipairs(S.tabs) do
			if tab:IsShown() then
				if prev then
					tab:ClearAllPoints()
					tab:SetPoint("LEFT", prev, "RIGHT", 1, 0)
				end
				prev = tab
			end
		end
	end

	local function SkinTabs()
		for i = 1, 4 do
			local tab = _G["InspectFrameTab" .. i]
			if tab then
				S.tabs[i] = tab
				local d = GetFFD(tab)
				local regions = { tab:GetRegions() }
				for j = 1, #regions do
					local r = regions[j]
					if r and r.IsObjectType and r:IsObjectType("Texture") then
						r:SetAlpha(0)
					end
				end
				local hl = tab:GetHighlightTexture()
				if hl then
					hl:SetAlpha(0)
				end
				local bg = Solid(tab, "BACKGROUND", 0.068, 0.056, 0.052, 1)
				bg:SetAllPoints()
				local activeHL = Solid(tab, "ARTWORK", 1, 1, 1, 0.02, -6)
				activeHL:SetAllPoints()
				activeHL:SetBlendMode("ADD")
				activeHL:Hide()

				local blizLabel = tab:GetFontString()
				local text = blizLabel and blizLabel:GetText() or ""
				HideTabText(tab)
				tab:SetPushedTextOffset(0, 0)
				local label = NewText(tab, 9)
				label:SetPoint("CENTER", tab, "CENTER", 0, 0)
				label:SetJustifyH("CENTER")
				label:SetText(text)
				hooksecurefunc(tab, "SetText", function(_, newText)
					if newText then
						label:SetText(newText)
					end
				end)

				local ur, ug, ub = WSkin.AccentBarColor()
				local underline = Solid(tab, "OVERLAY", ur, ug, ub, 1, 6)
				underline:SetHeight(1)
				underline:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 0)
				underline:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, 0)
				underline:Hide()
				WSkin.RegisterAccentUnderline(underline)

				-- 2 px shorter, like every EllesmereUI tab row.
				tab:SetHeight(max(1, tab:GetHeight() - 2))
				d.label, d.underline, d.activeHL, d.bg = label, underline, activeHL, bg
			end
		end
		NormalizeTabRow()
		local isTab = {}
		for _, tab in ipairs(S.tabs) do
			isTab[tab] = true
		end
		local function Rehide(tab)
			if isTab[tab] then
				HideTabText(tab)
			end
		end
		-- Select / Deselect / Enable / Disable set Blizzard's fonts again.
		hooksecurefunc("PanelTemplates_SelectTab", Rehide)
		hooksecurefunc("PanelTemplates_DeselectTab", Rehide)
		hooksecurefunc("PanelTemplates_SetTab", function(owner)
			if owner == InspectFrame then
				S.UpdateTabVisuals()
			end
		end)
		hooksecurefunc("PanelTemplates_EnableTab", function(owner, id)
			if owner == InspectFrame then
				Rehide(S.tabs[id])
				S.UpdateTabVisuals()
			end
		end)
		hooksecurefunc("PanelTemplates_DisableTab", function(owner, id)
			if owner == InspectFrame then
				Rehide(S.tabs[id])
				S.UpdateTabVisuals()
			end
		end)
		WSkin.OnLooksChanged(S.UpdateTabVisuals)
		InspectFrame:HookScript("OnShow", function()
			NormalizeTabRow()
			S.UpdateTabVisuals()
		end)
		S.UpdateTabVisuals()
	end

	-- PvP tab: art gone, each bracket a flat dark panel, white text.
	local function SkinPvPTab()
		local f = InspectPVPFrame
		if not f then
			return
		end
		for _, k in ipairs({ "BG", "Div1", "Div2", "Div3" }) do
			if f[k] and f[k].SetAlpha then
				f[k]:SetAlpha(0)
			end
		end
		for _, k in ipairs({ "RatedBG", "Arena2v2", "Arena3v3", "Arena5v5" }) do
			local sec = f[k]
			if sec then
				WSkin.Panel(sec, { shade = true })
				if sec.BGType then
					WSkin.Font(sec.BGType)
					WSkin.White(sec.BGType)
				end
				for _, fk in ipairs({ "RatingLabel", "WinsLabel" }) do
					if sec[fk] then
						WSkin.Font(sec[fk], 0.7, 0.7, 0.7)
					end
				end
				for _, fk in ipairs({ "Rating", "Wins" }) do
					if sec[fk] then
						WSkin.Font(sec[fk])
						WSkin.White(sec[fk])
					end
				end
			end
		end
	end

	-- Talents tab: blue / gold art gone, square talent icons; the picked
	-- talent gets an accent edge in place of Blizzard's gold ring.
	local function SkinTalentButton(btn)
		if not btn or GetFFD(btn).talent then
			return
		end
		local d = GetFFD(btn)
		d.talent = true
		if btn.Slot then
			btn.Slot:SetAlpha(0)
		end
		local icon = btn.icon
		if not icon then
			return
		end
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		local host = CreateFrame("Frame", nil, btn)
		host:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
		host:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
		host:SetFrameLevel(btn:GetFrameLevel() + 2)
		BS.PP.CreateBorder(host, 0, 0, 0, 1, 1, "OVERLAY", 7)
		local border = btn.border
		local function Paint()
			if border and border:IsShown() then
				local r, g, b = WSkin.AccentBarColor()
				BS.PP.SetBorderColor(host, r, g, b, 1)
			else
				BS.PP.SetBorderColor(host, 0, 0, 0, 1)
			end
		end
		if border then
			border:SetAlpha(0)
			hooksecurefunc(border, "Show", Paint)
			hooksecurefunc(border, "Hide", Paint)
		end
		Paint()
	end

	local function SkinTalentTab()
		local f = InspectTalentFrame
		if not f then
			return
		end
		FadeRegions(f)
		local spec = f.InspectSpec or _G.Specialization
		if spec then
			if spec.ring then
				spec.ring:SetAlpha(0)
			end
			if spec.specIcon then
				spec.specIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
				WSkin.BorderRegion(spec, spec.specIcon)
			end
			for _, k in ipairs({ "specName", "roleName", "description" }) do
				if spec[k] then
					WSkin.Font(spec[k])
					WSkin.White(spec[k])
				end
			end
		end
		for i = 1, 6 do
			for j = 1, 3 do
				SkinTalentButton(_G["TalentsTalentRow" .. i .. "Talent" .. j])
			end
		end
	end

	-- Guild tab: the parchment gone, banner and tabard kept, white text.
	local function SkinGuildTab()
		local f = InspectGuildFrame
		if not f then
			return
		end
		if InspectGuildFrameBG then
			InspectGuildFrameBG:SetAlpha(0)
		end
		for _, k in ipairs({ "guildName", "guildLevel", "guildNumMembers" }) do
			if f[k] then
				WSkin.Font(f[k])
				WSkin.White(f[k])
			end
		end
	end

	function S.SkinChrome()
		local frame = InspectFrame
		FadeRegions(frame)
		WSkin.RemovePortrait(frame)
		if InspectFrameInset then
			WSkin.Inset(InspectFrameInset)
		end
		WSkin.FadeNamed(frame, { "Bg", "TitleBg", "TopTileStreaks", "BtnCornerLeft", "BtnCornerRight", "ButtonBottomBorder" })

		-- Backdrop: char sheet art + 0.62 black, or the Modern flat color.
		local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
		bg:SetTexture(MEDIA .. "sheet-bg")
		bg:SetAllPoints(frame)
		local overlay = Solid(frame, "BACKGROUND", 0, 0, 0, 0.62, -7)
		overlay:SetAllPoints(frame)
		local modernBg = Solid(frame, "BACKGROUND", 0, 0, 0, 0, -6)
		modernBg:SetAllPoints(frame)
		S.bg, S.bgOverlay, S.modernBg = bg, overlay, modernBg
		frame:HookScript("OnSizeChanged", UpdateBackdropCoords)
		UpdateBackdropCoords()
		S.ApplyBackdropStyle()

		local borderFrame = CreateFrame("Frame", nil, frame)
		borderFrame:SetAllPoints(frame)
		borderFrame:SetFrameLevel(frame:GetFrameLevel() + 6)
		CreateBorder(borderFrame, 1, 0.2, 0.2, 0.2, 1, "OVERLAY")

		-- Title and level line in the middle of the top bar.
		if InspectFrameTitleText then
			InspectFrameTitleText:ClearAllPoints()
			InspectFrameTitleText:SetPoint("TOP", frame, "TOP", 0, -6)
			InspectFrameTitleText:SetJustifyH("CENTER")
		end
		if InspectLevelText and InspectFrameTitleText then
			InspectLevelText:ClearAllPoints()
			InspectLevelText:SetPoint("TOP", InspectFrameTitleText, "BOTTOM", 0, -5)
		end
		WSkin.CloseButton(InspectFrameCloseButton)

		SkinSlots()
		SkinModel()
		SkinTabs()
		SkinPvPTab()
		SkinTalentTab()
		SkinGuildTab()
		-- Talent buttons are built late on some clients: retry on show.
		if InspectTalentFrame then
			InspectTalentFrame:HookScript("OnShow", SkinTalentTab)
		end
	end
end

-------------------------------------------------------------------------------
--  Slot text: item level, upgrade level, enchant, gems; average item level
-------------------------------------------------------------------------------
do
	-- ElvUI "Display Inspect Info" writes its own strings beside the slots.
	local function HideElvUIInfo()
		if not ElvUI then
			return
		end
		for _, slotName in ipairs(ALL_SLOTS) do
			local slot = _G[slotName]
			if slot then
				if slot.iLvlText then slot.iLvlText:SetAlpha(0) end
				if slot.enchantText then slot.enchantText:SetAlpha(0) end
				for u = 1, 10 do
					if slot["textureSlotBackdrop" .. u] then slot["textureSlotBackdrop" .. u]:SetAlpha(0) end
					if slot["textureSlot" .. u] then slot["textureSlot" .. u]:SetAlpha(0) end
				end
			end
		end
		if InspectFrame.ItemLevelText then
			InspectFrame.ItemLevelText:SetAlpha(0)
		end
	end

	function S.BuildLabels()
		local parent = InspectPaperDollFrame or InspectFrame
		local overlay = CreateFrame("Frame", "EUI_InspectSheetTextOverlay", parent)
		overlay:SetAllPoints(InspectFrame)
		overlay:SetFrameLevel(InspectFrame:GetFrameLevel() + 10)
		overlay:EnableMouse(false)
		S.overlay = overlay

		-- Blizz Default keeps Blizzard's bronze slot frames: text further out.
		local LX = Stock() and 22 or 15
		local EX = Stock() and 12 or 5

		local gemContainer
		if Themed() then
			gemContainer = CreateFrame("Frame", nil, parent)
			gemContainer:SetAllPoints(InspectFrame)
			gemContainer:SetFrameLevel((InspectHeadSlot and InspectHeadSlot:GetFrameLevel() or InspectFrame:GetFrameLevel()) + 4)
		end

		for _, slotName in ipairs(GEAR_SLOTS) do
			local slot = _G[slotName]
			if slot then
				local data = S.slots[slotName] or {}
				S.slots[slotName] = data
				local right = TEXT_RIGHT[slotName]

				data.itemLevel = NewText(overlay, 11)
				data.itemLevel:SetJustifyH("CENTER")
				if right then
					data.itemLevel:SetPoint("CENTER", slot, "RIGHT", LX, 10)
				else
					data.itemLevel:SetPoint("CENTER", slot, "LEFT", -LX, 10)
				end

				data.upgrade = NewText(overlay, 11)
				data.upgrade:SetJustifyH("CENTER")
				if right then
					data.upgrade:SetPoint("LEFT", data.itemLevel, "RIGHT", 3, 0)
				else
					data.upgrade:SetPoint("RIGHT", data.itemLevel, "LEFT", -3, 0)
				end

				data.enchant = NewText(overlay, 9)
				data.enchant:SetWordWrap(false)
				local hover = CreateFrame("Frame", nil, overlay)
				hover:SetSize(20, 20)
				hover:SetFrameLevel(overlay:GetFrameLevel() + 20)
				hover:EnableMouse(true)
				hover:Hide()
				if right then
					data.enchant:SetPoint("LEFT", slot, "RIGHT", EX, -5)
					data.enchant:SetJustifyH("LEFT")
					hover:SetPoint("LEFT", slot, "RIGHT", EX, -5)
				else
					data.enchant:SetPoint("RIGHT", slot, "LEFT", -EX, -5)
					data.enchant:SetJustifyH("RIGHT")
					hover:SetPoint("RIGHT", slot, "LEFT", -EX, -5)
				end
				hover:SetScript("OnEnter", function(self) ShowTextTooltip(self, data.enchantTip) end)
				hover:SetScript("OnLeave", HideTooltip)
				data.enchantHover = hover

				-- Gems inside the icon, bottom right, stacking upward (max 2).
				if gemContainer then
					data.gems = {}
					for i = 1, 2 do
						local g = CreateFrame("Frame", nil, gemContainer)
						g:SetSize(15, 15)
						g:EnableMouse(true)
						g:Hide()
						g.icon = g:CreateTexture(nil, "ARTWORK")
						g.icon:SetAllPoints()
						g.edges = CreateBorder(g, 2, 1, 1, 1, 1, "OVERLAY")
						g:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 2 + (i - 1) * 16)
						g:SetScript("OnEnter", function(self)
							if self.link then
								GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
								GameTooltip:SetHyperlink(self.link)
								GameTooltip:Show()
							end
						end)
						g:SetScript("OnLeave", HideTooltip)
						data.gems[i] = g
					end
				end
			end
		end

		-- Average item level under the level line.
		local avg = NewText(overlay, 16)
		avg:SetTextColor(0.6, 0.2, 1, 1)
		avg:SetJustifyH("CENTER")
		avg:SetPoint("TOP", InspectFrame, "TOP", 0, -43)
		avg:Hide()
		S.avgText = avg

		-- Eye toggle in the top left: hides the slot text for the session.
		if Themed() then
			local eye = CreateFrame("Button", "EUI_InspectSheetTextEye", parent)
			eye:SetSize(20, 20)
			eye:SetPoint("TOPLEFT", InspectFrame, "TOPLEFT", 14, -6)
			eye:SetFrameLevel(InspectFrame:GetFrameLevel() + 20)
			eye:SetAlpha(0.4)
			local tex = eye:CreateTexture(nil, "OVERLAY")
			tex:SetAllPoints()
			tex:SetTexture(MEDIA .. "eui-visible")
			tex:SetTexCoord(0, ICON_COORD, 0, ICON_COORD)
			local hidden = false
			eye:SetScript("OnClick", function(self)
				hidden = not hidden
				tex:SetTexture(MEDIA .. (hidden and "eui-invisible" or "eui-visible"))
				overlay:SetAlpha(hidden and 0 or 1)
				ShowTextTooltip(self, hidden and "Show Item Text" or "Hide Item Text")
			end)
			eye:SetScript("OnEnter", function(self)
				self:SetAlpha(0.8)
				ShowTextTooltip(self, hidden and "Show Item Text" or "Hide Item Text")
			end)
			eye:SetScript("OnLeave", function(self)
				self:SetAlpha(0.4)
				HideTooltip()
			end)
		end
	end

	local function UpdateGems(data, link)
		if not data.gems then
			return
		end
		local entries = {}
		if link and BS.Get("inspectShowGems") then
			local stats = GetItemStats(link)
			local total, emptyTexture = 0, nil
			if stats then
				for key, count in pairs(stats) do
					local tex = EMPTY_SOCKET_TEXTURES[key]
					if tex and count and count > 0 then
						total = total + count
						emptyTexture = emptyTexture or tex
					end
				end
			end
			local filled = 0
			for i = 1, 4 do
				local _, gemLink = GetItemGem(link, i)
				if gemLink then
					filled = filled + 1
					local _, _, quality, _, _, _, _, _, _, icon = GetItemInfo(gemLink)
					entries[#entries + 1] = { icon = icon or (GetItemIcon and GetItemIcon(gemLink)) or "Interface\\Icons\\INV_Misc_QuestionMark", link = gemLink, quality = quality or 2 }
				end
			end
			for _ = 1, max(0, total - filled) do
				entries[#entries + 1] = { icon = emptyTexture, empty = true }
			end
		end
		for i, g in ipairs(data.gems) do
			local e = entries[i]
			if e then
				g.icon:SetTexture(e.icon)
				g.link = e.link
				if e.empty or (e.quality or 0) < 3 then
					g.edges:SetColor(0.75, 0.75, 0.75, 1)
				else
					g.edges:SetColor(1, 0.82, 0, 1)
				end
				g:Show()
			else
				g.link = nil
				g:Hide()
			end
		end
	end

	local function UpdateSlot(slotName, unit)
		local slot, data = _G[slotName], S.slots[slotName]
		if not slot or not data or not data.itemLevel then
			return
		end
		local slotID = slot:GetID()
		local link = unit and GetInventoryItemLink(unit, slotID)
		local info = link and ScanSlot(unit, slotID, link)
		local quality = link and (GetInventoryItemQuality(unit, slotID) or select(3, GetItemInfo(link)))
		local r, g, b = QualityColor(quality)

		if BS.Get("inspectShowItemLevel") and link then
			local ilvl = (info and info.ilvl) or select(4, GetItemInfo(link))
			if ilvl then
				data.itemLevel:SetText(tostring(ilvl))
				data.itemLevel:SetTextColor(r, g, b, 0.9)
				data.itemLevel:Show()
			else
				data.itemLevel:Hide()
			end
		else
			data.itemLevel:Hide()
		end

		-- Upgrade level "(1/2)" in place of the retail upgrade track.
		if BS.Get("inspectShowUpgradeTrack") and data.itemLevel:IsShown() and info and info.upCur and info.upMax and info.upMax > 0 then
			data.upgrade:SetText("(" .. info.upCur .. "/" .. info.upMax .. ")")
			data.upgrade:SetTextColor(r, g, b, 0.8)
			data.upgrade:Show()
		else
			data.upgrade:Hide()
		end

		-- Enchant: Text = plain name, Colored Text = outlined name in the item
		-- level color, a red "Missing" on a level 90 player's item without one.
		local enchant = info and info.enchant
		local missing = link and info and info.ilvl and ENCHANT_SLOTS[slotID] and not enchant
			and (UnitLevel(unit) or 0) >= 90
		local size = BS.Get("inspectEnchantSize") or CS().enchantSize or 9
		if BS.Get("inspectShowEnchants") and (enchant or missing) then
			data.enchantTip = enchant or "Enchant missing"
			if missing then
				SetFont(data.enchant, size, "")
				data.enchant:SetTextColor(MISSING_RED.r, MISSING_RED.g, MISSING_RED.b, 0.9)
			elseif BS.Get("inspectEnchantNames") then
				SetFont(data.enchant, size, "OUTLINE")
				data.enchant:SetTextColor(r + (1 - r) * 0.5, g + (1 - g) * 0.5, b + (1 - b) * 0.5, 0.9)
			else
				SetFont(data.enchant, size, "")
				data.enchant:SetTextColor(1, 1, 1, 0.8)
			end
			-- At most 45% of the gap between the slot columns.
			local maxW
			local lr = InspectHeadSlot and InspectHeadSlot:GetRight()
			local rl = InspectHandsSlot and InspectHandsSlot:GetLeft()
			if lr and rl and rl > lr then
				maxW = (rl - lr) * 0.45
			end
			data.enchant:SetWidth(maxW or 0)
			data.enchant:SetText(enchant or "Missing")
			data.enchant:Show()
			data.enchantHover:SetWidth(min(maxW or 100, max(20, data.enchant:GetStringWidth() or 20)))
			data.enchantHover:Show()
		else
			data.enchant:Hide()
			data.enchantHover:Hide()
		end

		if data.border then
			if link then
				data.border:SetColor(r, g, b, 1)
			else
				data.border:SetColor(0.4, 0.4, 0.4, 1)
			end
		end
		UpdateGems(data, link)
	end

	function S.Refresh()
		if not S.overlay or not InspectFrame or not InspectFrame:IsShown() then
			return
		end
		HideElvUIInfo()
		local unit = Unit()
		for _, slotName in ipairs(GEAR_SLOTS) do
			UpdateSlot(slotName, unit)
		end
		-- Borders of the shirt and tabard slots.
		for _, slotName in ipairs({ "InspectShirtSlot", "InspectTabardSlot" }) do
			local data, slot = S.slots[slotName], _G[slotName]
			if data and data.border and slot then
				local link = unit and GetInventoryItemLink(unit, slot:GetID())
				if link then
					data.border:SetColor(QualityColor(GetInventoryItemQuality(unit, slot:GetID())))
				else
					data.border:SetColor(0.4, 0.4, 0.4, 1)
				end
			end
		end
		local avg = unit and AverageItemLevel(unit)
		if avg and S.avgText then
			S.avgText:SetFormattedText("%.2f", avg)
			S.avgText:Show()
		elseif S.avgText then
			S.avgText:Hide()
		end
	end
end

-------------------------------------------------------------------------------
--  Build and events
-------------------------------------------------------------------------------
local built = false
local refreshQueued = false

local function QueueRefresh()
	if refreshQueued then
		return
	end
	refreshQueued = true
	BS.After(0.1, function()
		refreshQueued = false
		S.Refresh()
	end)
end

local function Setup()
	if built or not InspectFrame or not SheetOn() then
		return
	end
	built = true
	if Themed() then
		S.SkinChrome()
	end
	S.BuildLabels()

	-- Blizzard repaints the slots on show and on every INSPECT_READY.
	if InspectPaperDollFrame_UpdateButtons then
		hooksecurefunc("InspectPaperDollFrame_UpdateButtons", QueueRefresh)
	end
	local ev = CreateFrame("Frame")
	ev:SetScript("OnEvent", function(_, event, arg1)
		if event == "UNIT_INVENTORY_CHANGED" and arg1 ~= Unit() then
			return
		end
		QueueRefresh()
	end)
	InspectFrame:HookScript("OnShow", function()
		ev:RegisterEvent("INSPECT_READY")
		ev:RegisterEvent("UNIT_INVENTORY_CHANGED")
		ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
		QueueRefresh()
	end)
	InspectFrame:HookScript("OnHide", function()
		ev:UnregisterAllEvents()
		-- Scans are per player: drop them when the window closes.
		wipe(scanCache)
	end)
	if InspectFrame:IsShown() then
		ev:RegisterEvent("INSPECT_READY")
		ev:RegisterEvent("UNIT_INVENTORY_CHANGED")
		ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
		QueueRefresh()
	end
end

-- Live settings (EllesmereUI <-> Modern backdrop, icon zoom, text options).
BS.OnApply(function()
	if not built then
		return
	end
	S.ApplyBackdropStyle()
	S.ApplyIconZoom()
	if S.UpdateTabVisuals and Themed() then
		S.UpdateTabVisuals()
	end
	S.Refresh()
end)

BS.OnLogin(function()
	local cs = CS()
	activeStyle = ns.CharSheetStyleActive and ns.CharSheetStyleActive() or cs.style or "eui"
	enabledAtLogin = BS.Get("themedInspectSheet") ~= false
	if IsAddOnLoaded("Blizzard_InspectUI") then
		Setup()
	end
end)

-- The window engine applies this for EllesmereUI / Modern ("inspect" follows
-- the character sheet style; no card of its own). Blizz Default (style "off"
-- for the engine) still gets the slot text through the loader below.
WSkin.RegisterWindow({
	key = "inspect",
	addons = { Blizzard_InspectUI = true },
	elvui = "inspect",
	apply = Setup,
})

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
	if name == "Blizzard_InspectUI" and IsLoggedIn() then
		self:UnregisterEvent("ADDON_LOADED")
		Setup()
	end
end)

-------------------------------------------------------------------------------
--  Settings: Character Sheet page > Inspect Sheet (retail "INSPECT SHEET")
-------------------------------------------------------------------------------
ns.BlizzSkinCharSheetOptions = ns.BlizzSkinCharSheetOptions or {}
table.insert(ns.BlizzSkinCharSheetOptions, function(p, U)
	local function off()
		return CS().style == "off" or BS.Get("themedInspectSheet") == false
	end
	local function EnchantMode()
		if not BS.Get("inspectShowEnchants") then
			return "none"
		end
		return BS.Get("inspectEnchantNames") and "text" or "icons"
	end

	p:Section("Inspect Sheet")
	p:Toggle("Enable Inspect Sheet", "Applies EllesmereUI theme styling to the inspect sheet window. It follows the Character Sheet style. Needs a UI reload.",
		function() return BS.Get("themedInspectSheet") ~= false end,
		function(v)
			BS.Set("themedInspectSheet", v and true or false)
			BS.AskReload()
		end,
		function() return CS().style == "off" end)
	p:Dropdown("Enchants", "How enchants show beside each item. Text: the enchant name. Colored Text: the name with an outline, in the item level color. A level 90 player's item without an enchant shows a red 'Missing'.",
		function() return U.KeyItems(ns.CHARSHEET_ENCHANT_MODES) end,
		EnchantMode,
		function() return U.KeyLabel(ns.CHARSHEET_ENCHANT_MODES, EnchantMode()) end,
		function(v)
			BS.Set("inspectShowEnchants", v ~= "none")
			if v ~= "none" then
				BS.Set("inspectEnchantNames", v == "text")
			end
		end, nil, off)
	p:Slider("Enchant Text Size", "Size of the enchant text on the inspect sheet. Unset, it follows the character sheet.", 6, 20, 1,
		function() return BS.Get("inspectEnchantSize") or CS().enchantSize or 9 end,
		function(v) BS.Set("inspectEnchantSize", v) end,
		function() return off() or not BS.Get("inspectShowEnchants") end)
	local DETAILS = {
		{ key = "inspectShowItemLevel", text = "Item Level" },
		{ key = "inspectShowUpgradeTrack", text = "Upgrade Level" },
		{ key = "inspectShowGems", text = "Gems" },
	}
	p:MultiSelect("Item Details", "Choose what shows on each item of the inspected player. Upgrade Level is the item upgrade (for example 1/2). Gems are not shown with Blizz Default.",
		function() return U.KeyItems(DETAILS) end,
		function(key) return BS.Get(key) and true or false end,
		function(key) BS.Set(key, not BS.Get(key)) end,
		function()
			local names = {}
			for i = 1, #DETAILS do
				if BS.Get(DETAILS[i].key) then
					names[#names + 1] = DETAILS[i].text
				end
			end
			return #names == 0 and "None" or table.concat(names, ", ")
		end, off)
end)
