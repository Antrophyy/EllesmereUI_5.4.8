-- Character sheet in the EllesmereUI style (EllesmereUIBlizzardSkin_CharacterSheet.lua),
-- made for 5.4.8. Same layout, fonts, font sizes, colors and texts; the parts
-- that need retail systems are mapped to their Mists of Pandaria version:
--   upgrade track      -> item upgrade level ("Upgrade Level: 1/2")
--   crests             -> Valor and Justice points
--   tertiary stats     -> Hit and Expertise (in Secondary), Resilience and PvP Power (in PvP)
--   atlas art          -> EllesmereUI PNG art converted to TGA (media\charsheet)
-- Styles (like the EllesmereUI card): EllesmereUI, Modern, Blizz Default, Off.

local addonName = ...
local ns = EllesmereUI

local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local format, pairs, ipairs, tinsert = format, pairs, ipairs, tinsert

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------
local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\media\\charsheet\\"
local FONT = ns.FONT
local FONT_FALLBACK = "Fonts\\ARIALN.TTF"
local ICON_COORD = 30 / 32 -- 30 x 30 icons in a 32 x 32 TGA

local ACCENT = { r = 12 / 255, g = 210 / 255, b = 157 / 255 }
local ILVL_PURPLE = { r = 0.6, g = 0.2, b = 1 }
local MISSING_RED = { r = 0.898, g = 0.286, b = 0.286 } -- #e54949

-- EllesmereUI layout, measured from a 540 x 424 sheet: the right slot column
-- and the stats column keep their distance to the right edge, the rows
-- spread over extra height, the weapons stay centered under the model.
local BASE_W, BASE_H = 540, 424
local MIN_W, MAX_W = 540, 900
local MIN_H, MAX_H = 424, 720
local RIGHT_COLUMN_X = 540 - 294 -- slot left edge, from the right edge
local STATS_X = 540 - 345 -- stats column left edge, from the right edge

local ITEM_LEVEL_SIZE = 11
local UPGRADE_SIZE = 11

local DEFAULT_COLORS = {
	Attributes = { 0.047, 0.824, 0.616 },
	Secondary = { 0.471, 0.255, 0.784 },
	Attack = { 1, 0.353, 0.122 },
	Defense = { 0.247, 0.655, 1 },
	Currencies = { 1, 0.784, 0.341 },
	PvP = { 0.671, 0.431, 0.349 },
}

local SECTION_KEYS = { "Attributes", "Secondary", "Attack", "Defense", "Currencies", "PvP" }

local GEAR_SLOTS = {
	"CharacterHeadSlot", "CharacterNeckSlot", "CharacterShoulderSlot", "CharacterBackSlot",
	"CharacterChestSlot", "CharacterWaistSlot", "CharacterLegsSlot", "CharacterFeetSlot",
	"CharacterWristSlot", "CharacterHandsSlot", "CharacterFinger0Slot", "CharacterFinger1Slot",
	"CharacterTrinket0Slot", "CharacterTrinket1Slot", "CharacterMainHandSlot", "CharacterSecondaryHandSlot",
}
local ALL_SLOTS = {
	"CharacterHeadSlot", "CharacterNeckSlot", "CharacterShoulderSlot", "CharacterBackSlot",
	"CharacterChestSlot", "CharacterShirtSlot", "CharacterTabardSlot", "CharacterWristSlot",
	"CharacterHandsSlot", "CharacterWaistSlot", "CharacterLegsSlot", "CharacterFeetSlot",
	"CharacterTrinket0Slot", "CharacterTrinket1Slot", "CharacterFinger0Slot", "CharacterFinger1Slot",
	"CharacterMainHandSlot", "CharacterSecondaryHandSlot",
}
local LEFT_COLUMN = {
	CharacterHeadSlot = true, CharacterNeckSlot = true, CharacterShoulderSlot = true,
	CharacterBackSlot = true, CharacterChestSlot = true, CharacterShirtSlot = true,
	CharacterTabardSlot = true, CharacterWristSlot = true, CharacterSecondaryHandSlot = true,
}
-- EllesmereUI grid: 2 columns, 280 px apart, 41 px rows.
local SLOT_GRID = {
	CharacterHeadSlot = { 0, 0 }, CharacterNeckSlot = { 0, 1 }, CharacterShoulderSlot = { 0, 2 },
	CharacterBackSlot = { 0, 3 }, CharacterChestSlot = { 0, 4 }, CharacterShirtSlot = { 0, 5 },
	CharacterTabardSlot = { 0, 6 }, CharacterWristSlot = { 0, 7 },
	CharacterHandsSlot = { 1, 0 }, CharacterWaistSlot = { 1, 1 }, CharacterLegsSlot = { 1, 2 },
	CharacterFeetSlot = { 1, 3 }, CharacterFinger0Slot = { 1, 4 }, CharacterFinger1Slot = { 1, 5 },
	CharacterTrinket0Slot = { 1, 6 }, CharacterTrinket1Slot = { 1, 7 },
}

-- Slots that take an enchant in Mists of Pandaria (rings only for enchanters).
local ENCHANT_SLOTS = { [3] = true, [5] = true, [7] = true, [8] = true, [9] = true, [10] = true, [15] = true, [16] = true, [17] = true }
local RING_SLOTS = { [11] = true, [12] = true }
local ENCHANTING_SKILL_LINE = 333

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

---------------------------------------------------------------------------
-- Settings (EllesmereUIBlizzardSkinDB.charSheet)
---------------------------------------------------------------------------
local function Defaults()
	local colors = {}
	for key, c in pairs(DEFAULT_COLORS) do
		colors[key] = { c[1], c[2], c[3] }
	end
	return {
		style = "eui", -- eui / modern / blizzard / off
		modernColor = { 0.067, 0.067, 0.067 },
		modernAlpha = 97,
		-- Sheet size (EllesmereUI and Modern). EllesmereUI's own sheet is 540 x 424.
		width = 640,
		height = 500,
		showItemLevel = true,
		showUpgradeTrack = true,
		showGems = true,
		iconZoom = 7, -- percent, EllesmereUI 0.07
		showEnchants = true,
		enchantNames = false,
		enchantSize = 9,
		enchantUseColor = false, -- false: white (Text) / item level color (Colored Text)
		enchantColor = { 1, 1, 1 },
		flyoutItemLevels = false,
		showDurability = false,
		durabilityLocation = "model",
		durabilityShowLabel = true,
		hideSlotFlyoutArrows = false,
		sections = { Attributes = true, Secondary = true, Attack = true, Defense = true, Currencies = true, PvP = true },
		showMana = false,
		showValor = true,
		showJustice = true,
		secondaryText = "pct", -- pct / value / both
		secondaryHighlights = false,
		blizzColors = true,
		colors = colors,
		collapsed = {},
		sectionOrder = nil,
	}
end

local function CopyDefaults(src, dst)
	for key, value in pairs(src) do
		if dst[key] == nil then
			if type(value) == "table" then
				local copy = {}
				CopyDefaults(value, copy)
				dst[key] = copy
			else
				dst[key] = value
			end
		elseif type(value) == "table" and type(dst[key]) == "table" then
			CopyDefaults(value, dst[key])
		end
	end
end

local db = Defaults()
-- The style the sheet runs with this session (a change between Blizz Default,
-- Off and the EllesmereUI looks needs a reload, like EllesmereUI).
local activeStyle

local function Themed()
	return activeStyle == "eui" or activeStyle == "modern"
end

local function Stock()
	return activeStyle == "blizzard"
end

local function SheetOn()
	return activeStyle ~= nil and activeStyle ~= "off"
end

-- Blizz Default + "Blizzard UI Color": stat titles and item level in Blizzard's yellow.
local function BlizzColor()
	if Stock() and db.blizzColors then
		local n = NORMAL_FONT_COLOR
		return n and n.r or 1, n and n.g or 0.82, n and n.b or 0
	end
end

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------
-- Font from Global Settings > Fonts (module key "blizzardSkin"). flags nil
-- or "": the module outline (with a drop shadow when it has none).
local function SetFont(fs, size, flags)
	if ns.ApplyModuleFont then
		ns.ApplyModuleFont(fs, size, "blizzardSkin", (flags ~= "" and flags) or nil)
		return
	end
	fs:SetFont(FONT, size, flags or "")
	if not fs:GetFont() then
		fs:SetFont(FONT_FALLBACK, size, flags or "")
	end
end

local function NewText(parent, size, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	SetFont(fs, size)
	return fs
end

local function Solid(parent, layer, r, g, b, a, sublevel)
	local tex = parent:CreateTexture(nil, layer or "BACKGROUND")
	tex:SetTexture(r, g, b, a)
	if sublevel then
		tex:SetDrawLayer(layer or "BACKGROUND", sublevel)
	end
	return tex
end

-- Border made of 4 textures inside the frame edges (EllesmereUI PP.CreateBorder).
local function CreateBorder(frame, thickness, r, g, b, a, layer)
	local edges = {}
	local function Edge()
		local tex = frame:CreateTexture(nil, layer or "OVERLAY")
		tex:SetTexture(r, g, b, a)
		edges[#edges + 1] = tex
		return tex
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
	function edges:SetColor(nr, ng, nb, na)
		for i = 1, 4 do
			self[i]:SetTexture(nr, ng, nb, na)
		end
	end
	return edges
end

-- Alpha out every texture region of a frame (EllesmereUI FadeRegions).
local function FadeRegions(frame, keep)
	if not frame then
		return
	end
	local regions = { frame:GetRegions() }
	for i = 1, #regions do
		local r = regions[i]
		if r and r:IsObjectType("Texture") and not (keep and keep[r]) then
			r:SetAlpha(0)
		end
	end
end

-- 5.4.8 has no C_Timer: one frame runs the delayed calls.
local timerFrame = CreateFrame("Frame")
local timers = {}
timerFrame:Hide()
timerFrame:SetScript("OnUpdate", function(self)
	local now = GetTime()
	local i = 1
	while i <= #timers do
		local t = timers[i]
		if now >= t.at then
			table.remove(timers, i)
			if not t.cancelled then
				t.fn()
			end
		else
			i = i + 1
		end
	end
	if #timers == 0 then
		self:Hide()
	end
end)

local function After(delay, fn)
	local t = { at = GetTime() + delay, fn = fn }
	timers[#timers + 1] = t
	timerFrame:Show()
	return t
end

-- Trailing debounce: only the last call in the window runs.
local function Debounced(delay, fn)
	local pending
	return function()
		if pending then
			pending.cancelled = true
		end
		pending = After(delay, function()
			pending = nil
			fn()
		end)
	end
end

local function RegisterEvents(frame, events)
	for i = 1, #events do
		pcall(frame.RegisterEvent, frame, events[i])
	end
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

---------------------------------------------------------------------------
-- Item info from a scanning tooltip (5.4.8 GetItemInfo has the base item level
-- only; the tooltip shows the upgraded level, the upgrade level and the enchant).
---------------------------------------------------------------------------
local scanTip
local ITEM_LEVEL_PATTERN, UPGRADE_PATTERN, ENCHANT_PATTERN

local function ToPattern(fmt)
	if not fmt then
		return nil
	end
	-- Escape magic characters (not %), then "%d" -> number and "%s" -> text.
	local p = fmt:gsub("([%(%)%.%[%]%^%$%*%+%-%?])", "%%%1")
	p = p:gsub("%%d", "(%%d+)"):gsub("%%s", "(.+)")
	return "^" .. p .. "$"
end

local function EnsureScanTip()
	if scanTip then
		return scanTip
	end
	scanTip = CreateFrame("GameTooltip", "EUI_CharSheetScanTip", nil, "GameTooltipTemplate")
	scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
	ITEM_LEVEL_PATTERN = ToPattern(ITEM_LEVEL or "Item Level %d")
	UPGRADE_PATTERN = ToPattern(ITEM_UPGRADE_TOOLTIP_FORMAT or "Upgrade Level: %d/%d")
	ENCHANT_PATTERN = ToPattern(ENCHANTED_TOOLTIP_LINE or "Enchanted: %s")
	return scanTip
end

local scanCache = {}

-- Returns { ilvl, upCur, upMax, enchant } for the item the tooltip shows.
local function ReadScan(tip)
	local info = {}
	for i = 2, tip:NumLines() do
		local fs = _G["EUI_CharSheetScanTipTextLeft" .. i]
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
	return info
end

local function ScanInventory(slotID)
	local link = GetInventoryItemLink("player", slotID)
	if not link then
		return nil
	end
	local key = "i" .. slotID .. link
	local cached = scanCache[key]
	if cached then
		return cached
	end
	local tip = EnsureScanTip()
	tip:ClearLines()
	tip:SetOwner(WorldFrame, "ANCHOR_NONE")
	tip:SetInventoryItem("player", slotID)
	local info = ReadScan(tip)
	if info.ilvl then
		scanCache[key] = info
	end
	return info
end

local function ScanBag(bag, slot)
	local link = GetContainerItemLink(bag, slot)
	if not link then
		return nil
	end
	local key = "b" .. link
	local cached = scanCache[key]
	if cached then
		return cached
	end
	local tip = EnsureScanTip()
	tip:ClearLines()
	tip:SetOwner(WorldFrame, "ANCHOR_NONE")
	tip:SetBagItem(bag, slot)
	local info = ReadScan(tip)
	if info.ilvl then
		scanCache[key] = info
	end
	return info
end

local function EquippedItemLevel(slotID)
	local info = ScanInventory(slotID)
	if info and info.ilvl then
		return info.ilvl
	end
	local link = GetInventoryItemLink("player", slotID)
	if link then
		local _, _, _, ilvl = GetItemInfo(link)
		return ilvl or 0
	end
	return 0
end

---------------------------------------------------------------------------
-- Player info
---------------------------------------------------------------------------
-- Primary stat by spec (5.4.8 GetSpecializationInfo has no primary stat).
local SPEC_PRIMARY = {
	[250] = 1, [251] = 1, [252] = 1, [66] = 1, [70] = 1, [71] = 1, [72] = 1, [73] = 1,
	[103] = 2, [104] = 2, [253] = 2, [254] = 2, [255] = 2, [268] = 2, [269] = 2,
	[259] = 2, [260] = 2, [261] = 2, [263] = 2,
	[102] = 4, [105] = 4, [62] = 4, [63] = 4, [64] = 4, [270] = 4, [65] = 4,
	[256] = 4, [257] = 4, [258] = 4, [262] = 4, [264] = 4, [265] = 4, [266] = 4, [267] = 4,
}
local STAT_NAMES = { "Strength", "Agility", "Stamina", "Intellect", "Spirit" }

-- UnitStat: stat, effectiveStat, posBuff, negBuff. The sheet shows the effective value.
local function EffectiveStat(index)
	local _, effective = UnitStat("player", index)
	return effective or 0
end

local function SpecID()
	local spec = GetSpecialization and GetSpecialization()
	return spec and GetSpecializationInfo(spec), spec
end

local function PrimaryStatIndex()
	local id = SpecID()
	if id and SPEC_PRIMARY[id] then
		return SPEC_PRIMARY[id]
	end
	local best, bestValue = 4, -1
	for _, i in ipairs({ 1, 2, 4 }) do
		local _, v = UnitStat("player", i)
		if v and v > bestValue then
			best, bestValue = i, v
		end
	end
	return best
end

local function SpecRole()
	local _, spec = SpecID()
	return spec and GetSpecializationRole(spec)
end

-- "spell", "ranged" or "melee": which crit, haste and hit the sheet shows.
local function CombatType()
	if PrimaryStatIndex() == 4 then
		return "spell"
	end
	local _, class = UnitClass("player")
	if class == "HUNTER" then
		return "ranged"
	end
	return "melee"
end

local function SpellCrit()
	local lowest
	for school = 2, 7 do
		local c = GetSpellCritChance(school)
		if c and (not lowest or c < lowest) then
			lowest = c
		end
	end
	return lowest or 0
end

local function CritChance()
	local t = CombatType()
	if t == "spell" then
		return SpellCrit(), CR_CRIT_SPELL
	elseif t == "ranged" then
		return GetRangedCritChance() or 0, CR_CRIT_RANGED
	end
	return GetCritChance() or 0, CR_CRIT_MELEE
end

local function Haste()
	local t = CombatType()
	if t == "spell" then
		return UnitSpellHaste("player") or 0, CR_HASTE_SPELL
	elseif t == "ranged" then
		return GetRangedHaste() or 0, CR_HASTE_RANGED
	end
	return GetMeleeHaste() or 0, CR_HASTE_MELEE
end

local function HitChance()
	local t = CombatType()
	if t == "spell" then
		return (GetCombatRatingBonus(CR_HIT_SPELL) or 0) + (GetSpellHitModifier() or 0), CR_HIT_SPELL
	elseif t == "ranged" then
		return (GetCombatRatingBonus(CR_HIT_RANGED) or 0) + (GetHitModifier() or 0), CR_HIT_RANGED
	end
	return (GetCombatRatingBonus(CR_HIT_MELEE) or 0) + (GetHitModifier() or 0), CR_HIT_MELEE
end

local function Rating(cr)
	return cr and GetCombatRating(cr) or 0
end

local function MaxMana()
	return UnitPowerMax("player", 0) or 0
end

local function DurabilityPercent()
	local lowest = 100
	for slotID = 1, 19 do
		local cur, mx = GetInventoryItemDurability(slotID)
		if cur and mx and mx > 0 then
			local pct = cur / mx * 100
			if pct < lowest then
				lowest = pct
			end
		end
	end
	return floor(lowest)
end

local function DurabilityColor(pct)
	if pct > 50 then
		return (100 - pct) / 50, 1, 0
	end
	return 1, pct / 50, 0
end

local function IsEnchanter()
	if not GetProfessions then
		return false
	end
	local p1, p2 = GetProfessions()
	for _, index in ipairs({ p1, p2 }) do
		if index then
			local skillLine = select(7, GetProfessionInfo(index))
			if skillLine == ENCHANTING_SKILL_LINE then
				return true
			end
		end
	end
	return false
end

---------------------------------------------------------------------------
-- State shared by the builders
---------------------------------------------------------------------------
local S = {
	slots = {}, -- [slotName] = { itemLevel, upgrade, enchant, enchantHover, border, missing, gems }
	sections = {},
	statsValues = {},
}

---------------------------------------------------------------------------
-- Window chrome (EllesmereUI PreSkinCharacterSheet)
---------------------------------------------------------------------------
-- Cover-fit: the backdrop keeps its 561 x 433 aspect and is cropped, never stretched.
local BG_ASPECT = 561 / 433
local function UpdateBackdropCoords()
	local bg = S.bg
	if not bg then
		return
	end
	local fw, fh = CharacterFrame:GetSize()
	if not fw or fw == 0 or not fh or fh == 0 then
		return
	end
	local fa = fw / fh
	if fa > BG_ASPECT then
		local vis = BG_ASPECT / fa
		local trim = (1 - vis) / 2
		bg:SetTexCoord(0, 1, trim, 1 - trim)
	else
		local vis = fa / BG_ASPECT
		local trim = (1 - vis) / 2
		bg:SetTexCoord(trim, 1 - trim, 0, 1)
	end
end

local function ApplyBackdropStyle()
	if not S.bg then
		return
	end
	if db.style == "modern" then
		S.bg:SetAlpha(0)
		S.bgOverlay:SetAlpha(0)
		local c = db.modernColor
		S.modernBg:SetTexture(c[1], c[2], c[3], (db.modernAlpha or 97) / 100)
	else
		S.bg:SetAlpha(1)
		S.bgOverlay:SetAlpha(1)
		S.modernBg:SetTexture(0, 0, 0, 0)
	end
end

local function ApplyIconZoom()
	if not Themed() then
		return
	end
	local z = (db.iconZoom or 7) / 100
	for _, slotName in ipairs(ALL_SLOTS) do
		local icon = _G[slotName .. "IconTexture"]
		if icon then
			icon:SetTexCoord(z, 1 - z, z, 1 - z)
		end
	end
end

local function SkinChrome()
	local frame = CharacterFrame

	FadeRegions(frame)
	FadeRegions(CharacterFrameInset)
	FadeRegions(CharacterFrameInsetRight)
	if CharacterFrameInset and CharacterFrameInset.Bg then
		CharacterFrameInset.Bg:SetAlpha(0)
	end

	-- Backdrop: EllesmereUI modern_blizz art + 0.62 black, or the Modern flat color.
	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetDrawLayer("BACKGROUND", -8)
	bg:SetTexture(MEDIA .. "sheet-bg")
	bg:SetAllPoints(frame)
	local overlay = Solid(frame, "BACKGROUND", 0, 0, 0, 0.62, -7)
	overlay:SetAllPoints(frame)
	local modernBg = Solid(frame, "BACKGROUND", 0, 0, 0, 0, -6)
	modernBg:SetAllPoints(frame)
	S.bg, S.bgOverlay, S.modernBg = bg, overlay, modernBg
	frame:HookScript("OnSizeChanged", UpdateBackdropCoords)
	UpdateBackdropCoords()
	ApplyBackdropStyle()

	-- The AdventureMap atlas border does not exist in 5.4.8; EllesmereUI's own
	-- fallback is this 1 px border.
	local borderFrame = CreateFrame("Frame", nil, frame)
	borderFrame:SetAllPoints(frame)
	borderFrame:SetFrameLevel(frame:GetFrameLevel() + 6)
	CreateBorder(borderFrame, 1, 0.2, 0.2, 0.2, 1, "OVERLAY")

	-- The right inset (stats sidebar box and the sidebar tab art) parks off-screen.
	-- Two anchors keep its size, so the Blizzard panes anchored to it stay valid.
	if CharacterFrameInsetRight then
		CharacterFrameInsetRight:ClearAllPoints()
		CharacterFrameInsetRight:SetPoint("TOPLEFT", frame, "TOPLEFT", 10000, -10000)
		CharacterFrameInsetRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 10000, -10000)
	end

	-- Title and level text in the middle of the top bar.
	if CharacterFrameTitleText then
		CharacterFrameTitleText:ClearAllPoints()
		CharacterFrameTitleText:SetPoint("TOP", frame, "TOP", 0, -6)
		CharacterFrameTitleText:SetJustifyH("CENTER")
	end
	if CharacterLevelText and CharacterFrameTitleText then
		CharacterLevelText:ClearAllPoints()
		CharacterLevelText:SetPoint("TOP", CharacterFrameTitleText, "BOTTOM", 0, -5)
		CharacterLevelText:SetJustifyH("CENTER")
	end

	-- Close button: a plain "X".
	local close = CharacterFrameCloseButton
	if close then
		for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
			local tex = close[getter] and close[getter](close)
			if tex then
				tex:SetAlpha(0)
			end
		end
		close:SetSize(24, 24)
		close:ClearAllPoints()
		close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -1)
		local x = close:CreateTexture(nil, "OVERLAY")
		x:SetTexture(MEDIA .. "eui-close")
		x:SetTexCoord(0, ICON_COORD, 0, ICON_COORD)
		x:SetSize(14, 14)
		x:SetPoint("CENTER", -2, 0)
		x:SetVertexColor(1, 1, 1, 0.75)
		close:HookScript("OnEnter", function() x:SetVertexColor(1, 1, 1, 1) end)
		close:HookScript("OnLeave", function() x:SetVertexColor(1, 1, 1, 0.75) end)
	end

	-- The sheet stays open wide (EllesmereUI has no collapsed sheet).
	if CharacterFrameExpandButton then
		CharacterFrameExpandButton:SetAlpha(0)
		CharacterFrameExpandButton:EnableMouse(false)
	end
	PaperDollFrame:HookScript("OnShow", function()
		if not CharacterFrame.Expanded then
			CharacterFrame_Expand()
		end
	end)

	-- Blizzard's model and its art make room for ours.
	if CharacterModelFrame then
		CharacterModelFrame:Hide()
		CharacterModelFrame:EnableMouse(false)
	end

	-- Faint background on the Reputation and Currency lists.
	local function TabBg(anchor)
		if not anchor then
			return
		end
		local tex = Solid(anchor:GetParent() or anchor, "BACKGROUND", 0, 0, 0, 0.1, -7)
		tex:SetPoint("TOPLEFT", anchor, "TOPLEFT", 10, -10)
		tex:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -10, 0)
	end
	TabBg(ReputationListScrollFrame)
	TabBg(TokenFrameContainer)
end

---------------------------------------------------------------------------
-- Equipment slots: EllesmereUI grid, rarity borders, cropped icons
---------------------------------------------------------------------------
local function SheetWidth()
	return max(MIN_W, min(MAX_W, db.width or BASE_W))
end

local function SheetHeight()
	return max(MIN_H, min(MAX_H, db.height or BASE_H))
end

-- Slot grid for the current size. At 540 x 424 this is the EllesmereUI grid:
-- columns at x 14 and 294, rows 41 px apart from y -60, weapons at x 128.
local function LayoutSlots()
	local frame = CharacterFrame
	local width = SheetWidth()
	local rowStep = 41 + (SheetHeight() - BASE_H) / 8
	for slotName, grid in pairs(SLOT_GRID) do
		local slot = _G[slotName]
		if slot then
			slot:ClearAllPoints()
			local y = -60 - floor(grid[2] * rowStep + 0.5)
			if grid[1] == 0 then
				slot:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, y)
			else
				slot:SetPoint("TOPLEFT", frame, "TOPRIGHT", -RIGHT_COLUMN_X, y)
			end
		end
	end
	-- Weapons in the bottom strip, centered between the columns (pair = 86 px).
	local center = (14 + 37 + width - RIGHT_COLUMN_X) / 2
	CharacterMainHandSlot:ClearAllPoints()
	CharacterMainHandSlot:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", floor(center - 43), 10)
	CharacterSecondaryHandSlot:ClearAllPoints()
	CharacterSecondaryHandSlot:SetPoint("TOPLEFT", CharacterMainHandSlot, "TOPRIGHT", 12, 0)
end

-- Reputation / Currency list layout for the current size (set further down).
local RelayoutLists

-- The same width and height on every tab: Blizzard reads the global in
-- CharacterFrame_Expand, and CharacterFrame_Collapse (Reputation, Currency,
-- Pet) is post-hooked to call this again.
local function ApplySheetSize()
	if not Themed() then
		return
	end
	CHARACTERFRAME_EXPANDED_WIDTH = SheetWidth()
	local frame = CharacterFrame
	local changed = false
	if abs(frame:GetHeight() - SheetHeight()) > 0.5 then
		frame:SetHeight(SheetHeight())
		changed = true
	end
	if abs(frame:GetWidth() - SheetWidth()) > 0.5 then
		frame:SetWidth(SheetWidth())
		changed = true
	end
	if S.slotsSkinned then
		LayoutSlots()
	end
	if RelayoutLists then
		RelayoutLists()
	end
	-- Other windows next to the sheet move with its new size.
	if changed and frame:IsShown() and UpdateUIPanelPositions then
		UpdateUIPanelPositions(frame)
	end
end

local function SkinSlots()
	local frame = CharacterFrame
	for _, slotName in ipairs(ALL_SLOTS) do
		local slot = _G[slotName]
		if slot then
			-- Bronze slot frame and the weapon slot ornaments (BACKGROUND layer),
			-- and the quickslot normal texture.
			local regions = { slot:GetRegions() }
			for i = 1, #regions do
				local r = regions[i]
				if r:IsObjectType("Texture") and r:GetDrawLayer() == "BACKGROUND" then
					r:SetAlpha(0)
				end
			end
			local normal = _G[slotName .. "NormalTexture"] or slot:GetNormalTexture()
			if normal then
				normal:SetAlpha(0)
			end

			local holder = CreateFrame("Frame", nil, slot)
			holder:SetAllPoints(slot)
			holder:SetFrameLevel(slot:GetFrameLevel() + 1)
			local data = S.slots[slotName] or {}
			S.slots[slotName] = data
			data.border = CreateBorder(holder, 2, 0.4, 0.4, 0.4, 1, "OVERLAY")
			data.borderFrame = holder
		end
	end
	S.slotsSkinned = true
	ApplySheetSize()
	LayoutSlots()
	ApplyIconZoom()
end

local function UpdateSlotBorders()
	if not Themed() then
		return
	end
	for _, slotName in ipairs(ALL_SLOTS) do
		local slot, data = _G[slotName], S.slots[slotName]
		if slot and data and data.border then
			local r, g, b = 0.4, 0.4, 0.4
			if GetInventoryItemLink("player", slot:GetID()) then
				local quality = GetInventoryItemQuality("player", slot:GetID())
				if quality then
					r, g, b = QualityColor(quality)
				end
			end
			data.border:SetColor(r, g, b, 1)
		end
	end
end

---------------------------------------------------------------------------
-- Player model (EllesmereUI: LMB drag rotates, RMB drag pans, wheel zooms)
---------------------------------------------------------------------------
local function BuildModel()
	local frame = CharacterFrame
	local base = frame:GetFrameLevel()

	local model = CreateFrame("PlayerModel", "EUI_CharSheetModel", PaperDollFrame)
	model:SetFrameLevel(base + 2)
	model:SetPoint("TOPLEFT", CharacterHeadSlot, "TOPRIGHT", 0, 0)
	model:SetPoint("TOPRIGHT", CharacterHandsSlot, "TOPLEFT", 0, 0)
	model:SetPoint("BOTTOM", CharacterMainHandSlot, "TOP", 0, 0)

	local bgFrame = CreateFrame("Frame", nil, PaperDollFrame)
	bgFrame:SetFrameLevel(base + 1)
	bgFrame:SetPoint("TOPLEFT", CharacterHeadSlot, "TOPLEFT", -8, 10)
	bgFrame:SetPoint("BOTTOMRIGHT", model, "BOTTOMRIGHT", 0, -18)
	local bgTex = bgFrame:CreateTexture(nil, "BACKGROUND")
	bgTex:SetAllPoints(bgFrame)
	bgTex:SetTexture(MEDIA .. "character-bg")

	model:SetUnit("player")
	local zoom = 0
	model:SetPortraitZoom(zoom)
	S.model = model

	local ROTATE_SPEED, PAN_SPEED, ZOOM_STEP = 0.012, 0.01, 0.1
	local mouse = CreateFrame("Frame", nil, model)
	mouse:SetAllPoints(model)
	mouse:SetFrameLevel(model:GetFrameLevel() + 5)
	mouse:EnableMouse(true)
	mouse:EnableMouseWheel(true)
	local dragMode, lastX, lastY
	local function DragUpdate(self)
		if not dragMode then
			self:SetScript("OnUpdate", nil)
			return
		end
		if (dragMode == "rotate" and not IsMouseButtonDown("LeftButton"))
			or (dragMode == "pan" and not IsMouseButtonDown("RightButton")) then
			dragMode = nil
			self:SetScript("OnUpdate", nil)
			return
		end
		local cx, cy = GetCursorPosition()
		local scale = self:GetEffectiveScale()
		local x, y = cx / scale, cy / scale
		local dx, dy = x - lastX, y - lastY
		lastX, lastY = x, y
		if dragMode == "rotate" then
			model:SetFacing((model:GetFacing() or 0) + dx * ROTATE_SPEED)
		else
			local px, py, pz = model:GetPosition()
			model:SetPosition(px or 0, (py or 0) + dx * PAN_SPEED, (pz or 0) + dy * PAN_SPEED)
		end
	end
	mouse:SetScript("OnMouseDown", function(self, button)
		local cx, cy = GetCursorPosition()
		local scale = self:GetEffectiveScale()
		lastX, lastY = cx / scale, cy / scale
		if button == "LeftButton" then
			-- Dropping an item on the model equips it, like Blizzard's model.
			if CursorHasItem() then
				AutoEquipCursorItem()
				return
			end
			dragMode = "rotate"
		elseif button == "RightButton" then
			dragMode = "pan"
		end
		self:SetScript("OnUpdate", DragUpdate)
	end)
	mouse:SetScript("OnMouseUp", function(self)
		dragMode = nil
		self:SetScript("OnUpdate", nil)
	end)
	mouse:SetScript("OnHide", function(self)
		dragMode = nil
		self:SetScript("OnUpdate", nil)
	end)
	mouse:SetScript("OnMouseWheel", function(_, delta)
		zoom = max(0, min(1, zoom + delta * ZOOM_STEP))
		model:SetPortraitZoom(zoom)
	end)
	mouse:SetScript("OnReceiveDrag", function()
		AutoEquipCursorItem()
	end)

	-- Re-bind on gear and form changes, only while visible.
	local events = CreateFrame("Frame")
	RegisterEvents(events, { "PLAYER_EQUIPMENT_CHANGED", "UNIT_MODEL_CHANGED", "UPDATE_SHAPESHIFT_FORM", "PLAYER_ENTERING_WORLD" })
	events:SetScript("OnEvent", function(_, event, unit)
		if not CharacterFrame:IsShown() then
			return
		end
		if event == "UNIT_MODEL_CHANGED" and unit ~= "player" then
			return
		end
		model:SetUnit("player")
	end)
	PaperDollFrame:HookScript("OnShow", function()
		model:SetUnit("player")
		model:SetPortraitZoom(zoom)
	end)
end

---------------------------------------------------------------------------
-- Bottom tabs: flat blocks, own 9 px label, accent underline on the active tab
---------------------------------------------------------------------------
local charTabs = {}

local function UpdateTabVisuals()
	for i, tab in ipairs(charTabs) do
		local active = (CharacterFrame.selectedTab or 1) == i
		tab._label:SetTextColor(1, 1, 1, active and 1 or 0.5)
		tab._underline:SetShown(active)
		tab._activeHL:SetShown(active)
	end
end

-- One pixel between shown tabs (EllesmereUI NormalizeTabRow).
local function NormalizeTabRow()
	local prev
	for _, tab in ipairs(charTabs) do
		if tab:IsShown() then
			if prev then
				tab:ClearAllPoints()
				tab:SetPoint("LEFT", prev, "RIGHT", 1, 0)
			end
			prev = tab
		end
	end
end

-- Blizzard's tab text is hidden with a transparent font. In 5.4.8 a text's
-- alpha is its color alpha, and PanelTemplates_SelectTab sets a new font
-- object (with its color) on every tab change, so SetAlpha(0) does not stay.
-- Same size as Blizzard's, so the tab widths do not change.
local hiddenTabFont

local function HideBlizzardTabText(tab)
	if not hiddenTabFont then
		hiddenTabFont = CreateFont("EUI_CharSheetHiddenTabFont")
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

local function SkinTabs()
	for i = 1, 4 do
		local tab = _G["CharacterFrameTab" .. i]
		if tab then
			charTabs[i] = tab
			local regions = { tab:GetRegions() }
			for j = 1, #regions do
				local r = regions[j]
				if r:IsObjectType("Texture") then
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
			local text = blizLabel and blizLabel:GetText() or ("Tab " .. i)
			HideBlizzardTabText(tab)
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

			local underline = Solid(tab, "OVERLAY", ACCENT.r, ACCENT.g, ACCENT.b, 1, 6)
			underline:SetHeight(1)
			underline:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 0)
			underline:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, 0)
			underline:Hide()

			-- 2 px shorter, like every EllesmereUI tab row.
			tab:SetHeight(max(1, tab:GetHeight() - 2))
			tab._label, tab._underline, tab._activeHL = label, underline, activeHL
		end
	end
	NormalizeTabRow()
	UpdateTabVisuals()
	hooksecurefunc("PanelTemplates_SetTab", function(owner)
		if owner == CharacterFrame then
			UpdateTabVisuals()
		end
	end)
	-- Select / Deselect set Blizzard's fonts again: hide the text again after them.
	local isCharTab = {}
	for _, tab in ipairs(charTabs) do
		isCharTab[tab] = true
	end
	local function Rehide(tab)
		if isCharTab[tab] then
			HideBlizzardTabText(tab)
		end
	end
	hooksecurefunc("PanelTemplates_SelectTab", Rehide)
	hooksecurefunc("PanelTemplates_DeselectTab", Rehide)
	if PetPaperDollFrame_UpdateIsAvailable then
		hooksecurefunc("PetPaperDollFrame_UpdateIsAvailable", NormalizeTabRow)
	end
	CharacterFrame:HookScript("OnShow", function()
		NormalizeTabRow()
		UpdateTabVisuals()
	end)
end

---------------------------------------------------------------------------
-- Custom thin scrollbar (EllesmereUI AttachCustomScrollbar)
---------------------------------------------------------------------------
local function AttachScrollbar(scrollFrame, scrollChild, owner, topInset)
	local track = CreateFrame("Frame", nil, owner)
	track:SetWidth(3)
	track:SetPoint("TOPRIGHT", owner, "TOPRIGHT", -2, topInset or 0)
	track:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -2, 0)
	track:SetFrameLevel(scrollFrame:GetFrameLevel() + 2)
	track:Hide()
	local thumb = CreateFrame("Button", nil, track)
	thumb:SetWidth(3)
	thumb:SetHeight(20)
	thumb:EnableMouse(true)
	Solid(thumb, "ARTWORK", 1, 1, 1, 0.2):SetAllPoints()

	local function Info()
		local contentH = scrollChild:GetHeight() or 0
		local viewH = scrollFrame:GetHeight() or 0
		return contentH, viewH, max(0, contentH - viewH)
	end
	local function Update()
		local contentH, viewH, maxScroll = Info()
		if contentH <= 0 or viewH <= 0 or maxScroll <= 0 then
			track:Hide()
			return
		end
		track:Show()
		local pct = max(0, min(1, scrollFrame:GetVerticalScroll() / maxScroll))
		local trackH = track:GetHeight()
		local thumbH = max(20, trackH * min(1, viewH / contentH))
		thumb:SetHeight(thumbH)
		thumb:ClearAllPoints()
		thumb:SetPoint("TOP", track, "TOP", 0, -(pct * max(0, trackH - thumbH)))
	end
	track.Update = Update
	function track.Clamp()
		local _, _, maxScroll = Info()
		scrollFrame:SetVerticalScroll(max(0, min(maxScroll, scrollFrame:GetVerticalScroll())))
		Update()
	end
	scrollFrame:HookScript("OnVerticalScroll", Update)
	scrollFrame:HookScript("OnSizeChanged", Update)
	scrollChild:HookScript("OnSizeChanged", Update)
	scrollFrame:EnableMouseWheel(true)
	scrollFrame:SetScript("OnMouseWheel", function(_, delta)
		local _, _, maxScroll = Info()
		if maxScroll <= 0 then
			return
		end
		scrollFrame:SetVerticalScroll(max(0, min(maxScroll, scrollFrame:GetVerticalScroll() - delta * 20)))
		Update()
	end)
	local drag = {}
	thumb:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" then
			return
		end
		local _, y = GetCursorPosition()
		drag.startY = y / UIParent:GetEffectiveScale()
		drag.startScroll = scrollFrame:GetVerticalScroll()
		self:SetScript("OnUpdate", function(btn)
			if not IsMouseButtonDown("LeftButton") then
				btn:SetScript("OnUpdate", nil)
				return
			end
			local _, _, maxScroll = Info()
			if maxScroll <= 0 then
				return
			end
			local _, cy = GetCursorPosition()
			local dy = drag.startY - cy / UIParent:GetEffectiveScale()
			local travel = max(1, track:GetHeight() - thumb:GetHeight())
			scrollFrame:SetVerticalScroll(max(0, min(maxScroll, drag.startScroll + dy / travel * maxScroll)))
			Update()
		end)
	end)
	thumb:SetScript("OnMouseUp", function(self)
		self:SetScript("OnUpdate", nil)
	end)
	return track
end

---------------------------------------------------------------------------
-- Stat sections
---------------------------------------------------------------------------
local function SectionColor(key)
	local r, g, b = BlizzColor()
	if r then
		return r, g, b
	end
	local c = db.colors[key] or DEFAULT_COLORS[key]
	return c[1], c[2], c[3]
end

local function CurrencyAmount(id)
	local _, amount = GetCurrencyInfo(id)
	return amount or 0
end

local function CurrencyTooltip(stat, r, g, b)
	local name, amount, _, earnedThisWeek, weeklyMax, totalMax = GetCurrencyInfo(stat.currencyID)
	GameTooltip:AddLine((name or stat.name) .. " " .. (amount or 0), r, g, b, true)
	if weeklyMax and weeklyMax > 0 then
		GameTooltip:AddLine(format("This week: %d / %d", earnedThisWeek or 0, weeklyMax), 1, 1, 1, true)
	end
	if totalMax and totalMax > 0 then
		GameTooltip:AddLine(format("Maximum: %d", totalMax), 1, 1, 1, true)
	end
end

local function ShowWhen(stat)
	local w = stat.showWhen
	if not w then
		return true
	end
	if w == "physical" then
		return CombatType() ~= "spell"
	elseif w == "spell" then
		return CombatType() == "spell"
	elseif w == "healer" then
		return SpecRole() == "HEALER"
	end
	return true
end

local function StatShown(stat)
	if not ShowWhen(stat) then
		return false
	end
	if stat.showKey and not db[stat.showKey] then
		return false
	end
	if stat.showIf and not stat.showIf() then
		return false
	end
	return true
end

local function StatName(stat)
	if type(stat.name) == "function" then
		return stat.name()
	end
	return stat.name
end

-- Section definitions. func returns the shown value; rawFunc the rating
-- (used by the Secondary Text setting and the tooltip).
local function SectionDefs()
	return {
		{
			key = "Attributes", title = "Attributes",
			stats = {
				{ name = function() return STAT_NAMES[PrimaryStatIndex()] end, primary = true,
					func = function() return EffectiveStat(PrimaryStatIndex()) end },
				{ name = "Stamina", statIndex = 3, func = function() return EffectiveStat(3) end, tooltip = "Increases health" },
				{ name = "Health", func = function() return UnitHealthMax("player") end, tooltip = "The amount of damage you can take" },
				{ name = "Mana", func = MaxMana, showKey = "showMana", showIf = function() return MaxMana() > 0 end,
					tooltip = "The size of your mana pool" },
			},
		},
		{
			key = "Secondary", title = "Secondary",
			stats = {
				{ name = "Critical Strike", format = "%.2f%%", itemMod = "ITEM_MOD_CRIT_RATING_SHORT",
					func = function() return (CritChance()) end, rawFunc = function() return Rating(select(2, CritChance())) end },
				{ name = "Haste", format = "%.2f%%", itemMod = "ITEM_MOD_HASTE_RATING_SHORT",
					func = function() return (Haste()) end, rawFunc = function() return Rating(select(2, Haste())) end },
				{ name = "Mastery", format = "%.2f%%", itemMod = "ITEM_MOD_MASTERY_RATING_SHORT",
					func = function() return GetMasteryEffect() or 0 end, rawFunc = function() return Rating(CR_MASTERY) end },
				{ name = "Hit", format = "%.2f%%", itemMod = "ITEM_MOD_HIT_RATING_SHORT",
					func = function() return (HitChance()) end, rawFunc = function() return Rating(select(2, HitChance())) end },
				{ name = "Expertise", format = "%.2f%%", itemMod = "ITEM_MOD_EXPERTISE_RATING_SHORT", showWhen = "physical",
					func = function() return (GetExpertise()) or 0 end, rawFunc = function() return Rating(CR_EXPERTISE) end },
				{ name = "Spirit", statIndex = 5, itemMod = "ITEM_MOD_SPIRIT_SHORT", showWhen = "healer",
					func = function() return EffectiveStat(5) end, tooltip = "Increases mana regeneration" },
			},
		},
		{
			key = "Attack", title = "Attack",
			stats = {
				{ name = "Attack Power", showWhen = "physical", tooltip = "Increases the damage of your attacks",
					func = function()
						local b, p, n
						if CombatType() == "ranged" then
							b, p, n = UnitRangedAttackPower("player")
						else
							b, p, n = UnitAttackPower("player")
						end
						return (b or 0) + (p or 0) + (n or 0)
					end },
				{ name = "Spell Power", showWhen = "spell", tooltip = "Increases the power of your spells and abilities",
					func = function()
						local best = 0
						for school = 2, 7 do
							best = max(best, GetSpellBonusDamage(school) or 0)
						end
						if SpecRole() == "HEALER" then
							best = max(best, GetSpellBonusHealing() or 0)
						end
						return best
					end },
				{ name = "Attack Speed", format = "%.2f", showWhen = "physical", tooltip = "Seconds between attacks",
					func = function()
						if CombatType() == "ranged" then
							return (UnitRangedDamage("player")) or 0
						end
						return (UnitAttackSpeed("player")) or 0
					end },
			},
		},
		{
			key = "Defense", title = "Defense",
			stats = {
				{ name = "Armor", tooltip = "Reduces physical damage taken", armor = true,
					func = function() local _, effective = UnitArmor("player") return effective or 0 end },
				{ name = "Dodge", format = "%.2f%%", tooltip = "Chance to avoid melee attacks", func = function() return GetDodgeChance() or 0 end },
				{ name = "Parry", format = "%.2f%%", tooltip = "Chance to deflect melee attacks", func = function() return GetParryChance() or 0 end },
				{ name = "Block", format = "%.2f%%", tooltip = "Chance to block incoming attacks with a shield", func = function() return GetBlockChance() or 0 end },
			},
		},
		{
			key = "Currencies", title = "Currencies",
			stats = {
				{ name = "Valor", currencyID = 396, showKey = "showValor", func = function() return CurrencyAmount(396) end },
				{ name = "Justice", currencyID = 395, showKey = "showJustice", func = function() return CurrencyAmount(395) end },
			},
		},
		{
			key = "PvP", title = "PvP",
			stats = {
				{ name = "Resilience", format = "%.2f%%", tooltip = "Reduces damage taken from players",
					func = function()
						return (GetCombatRatingBonus(COMBAT_RATING_RESILIENCE_PLAYER_DAMAGE_TAKEN) or 0)
							+ (GetModResilienceDamageReduction and GetModResilienceDamageReduction() or 0)
					end,
					rawFunc = function() return Rating(COMBAT_RATING_RESILIENCE_PLAYER_DAMAGE_TAKEN) end },
				{ name = "PvP Power", format = "%.2f%%", tooltip = "Increases damage and healing against players",
					func = function() return max(GetPvpPowerDamage() or 0, GetPvpPowerHealing() or 0) end,
					rawFunc = function() return Rating(CR_PVP_POWER) end },
				{ name = "Honor", currencyID = 392, func = function() return CurrencyAmount(392) end },
				{ name = "Conquest", currencyID = 390, func = function() return CurrencyAmount(390) end },
			},
		},
	}
end

-- Tooltip descriptions, the EllesmereUI texts with the MoP stats added.
local function SecondaryDescription(name, pct)
	if name == "Critical Strike" then
		return format("Increases your chance to critically hit by %.2f%%.", pct)
	elseif name == "Haste" then
		return format("Increases attack and casting speed by %.2f%%.", pct)
	elseif name == "Mastery" then
		local _, spec = SpecID()
		if spec and GetSpecializationMasterySpells and GetSpellDescription then
			local s1, s2 = GetSpecializationMasterySpells(spec)
			local d = s1 and GetSpellDescription(s1) or ""
			if s2 then
				local d2 = GetSpellDescription(s2)
				if d2 and d2 ~= "" then
					d = d .. "\n" .. d2
				end
			end
			if d ~= "" then
				return d
			end
		end
		return format("Increases the effectiveness of your Mastery by %.2f%%.", pct)
	elseif name == "Hit" then
		return format("Reduces your chance to miss by %.2f%%.", pct)
	elseif name == "Expertise" then
		return format("Reduces the chance for your attacks to be dodged or parried by %.2f%%.", pct)
	elseif name == "Resilience" then
		return format("Reduces damage taken from players by %.2f%%.", pct)
	elseif name == "PvP Power" then
		return format("Increases damage and healing done against players by %.2f%%.", pct)
	end
	return ""
end

---------------------------------------------------------------------------
-- Stat hover highlight: equipped items that carry the stat get a pulsing border
---------------------------------------------------------------------------
local highlightFrames = {}
local highlightTicker

local function StopStatHighlights()
	for _, f in pairs(highlightFrames) do
		f:Hide()
	end
	if highlightTicker then
		highlightTicker:Hide()
	end
end

local function StartStatHighlights(modKey)
	StopStatHighlights()
	if not modKey then
		return
	end
	if not highlightTicker then
		highlightTicker = CreateFrame("Frame", nil, PaperDollFrame)
		highlightTicker:SetScript("OnUpdate", function()
			local a = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(GetTime() * math.pi / 0.6))
			for _, f in pairs(highlightFrames) do
				if f:IsShown() then
					f.edges:SetColor(1, 1, 1, a)
				end
			end
		end)
	end
	local any = false
	for _, slotName in ipairs(GEAR_SLOTS) do
		local slot = _G[slotName]
		local link = slot and GetInventoryItemLink("player", slot:GetID())
		local stats = link and GetItemStats(link)
		local value = stats and stats[modKey]
		if value and value > 0 then
			local f = highlightFrames[slotName]
			if not f then
				f = CreateFrame("Frame", nil, slot)
				f:SetPoint("TOPLEFT", slot, "TOPLEFT", -3, 3)
				f:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", 3, -3)
				f.edges = CreateBorder(f, 2, 1, 1, 1, 1, "OVERLAY")
				highlightFrames[slotName] = f
			end
			f:SetFrameLevel(slot:GetFrameLevel() + 5)
			f:Show()
			any = true
		end
	end
	if any then
		highlightTicker:Show()
	end
end

local function StatTooltip(owner, section, stat, titleFS)
	local value = stat.func()
	if value == nil then
		return
	end
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	-- The title's live color, so a color change shows at once.
	local r, g, b = titleFS:GetTextColor()
	local name = StatName(stat)
	local shown = stat.format and format(stat.format, value) or tostring(value)

	if stat.currencyID then
		CurrencyTooltip(stat, r, g, b)
	elseif stat.rawFunc then
		GameTooltip:AddLine(format("%s %.2f%% (%d rating)", name, value, stat.rawFunc()), r, g, b, true)
		GameTooltip:AddLine(SecondaryDescription(name, value), 1, 1, 1, true)
	elseif stat.primary or stat.statIndex then
		local index = stat.statIndex or PrimaryStatIndex()
		local stat1, effective, posBuff, negBuff = UnitStat("player", index)
		-- Base value like Blizzard's 5.4.8 sheet: stat - posBuff - negBuff.
		local base = (stat1 or 0) - (posBuff or 0) - (negBuff or 0)
		local line = name .. " " .. (effective or value)
		local bonus = (posBuff or 0) + (negBuff or 0)
		if bonus ~= 0 then
			line = line .. " (" .. base .. (bonus > 0 and "+" or "") .. bonus .. ")"
		end
		GameTooltip:AddLine(line, r, g, b, true)
		local tip = stat.tooltip
		if stat.primary then
			if index == 1 then
				tip = "Increases melee attack power"
			elseif index == 2 then
				tip = "Increases dodge chance and attack power"
			else
				tip = "Increases spell power and spell critical strike chance"
			end
		end
		if tip then
			GameTooltip:AddLine(tip, 1, 1, 1, true)
		end
	else
		GameTooltip:AddLine(name .. " " .. shown, r, g, b, true)
		if stat.tooltip then
			GameTooltip:AddLine(stat.tooltip, 1, 1, 1, true)
		end
		if stat.armor and PaperDollFrame_GetArmorReduction then
			local reduction = PaperDollFrame_GetArmorReduction(value, UnitLevel("player"))
			if reduction and reduction > 0 then
				GameTooltip:AddLine(" ")
				GameTooltip:AddLine(format("Physical damage reduction: %.2f%%", reduction), 1, 1, 1, true)
				GameTooltip:AddLine("|cff888888(Against an evenly matched enemy)|r", 1, 1, 1, true)
			end
		end
	end
	GameTooltip:Show()
	if db.secondaryHighlights and section.key == "Secondary" then
		StartStatHighlights(stat.itemMod)
	end
end

local function RecalculateSections()
	local visible = {}
	for _, sec in ipairs(S.sections) do
		if sec.container:IsShown() then
			visible[#visible + 1] = sec
		end
	end
	local y = 0
	for idx, sec in ipairs(visible) do
		local h = sec.collapsed and 16 or sec.height
		sec.container:ClearAllPoints()
		sec.container:SetPoint("TOPLEFT", S.scrollChild, "TOPLEFT", 0, y)
		sec.container:SetPoint("TOPRIGHT", S.scrollChild, "TOPRIGHT", 0, y)
		sec.container:SetHeight(h)
		y = y - h - 6
		-- First up and last down arrows are gray and do nothing.
		local first, last = idx == 1, idx == #visible
		sec.upBtn:SetAlpha(first and 0.25 or 1)
		sec.upBtn:EnableMouse(not first)
		sec.downBtn:SetAlpha(last and 0.25 or 1)
		sec.downBtn:EnableMouse(not last)
	end
	S.scrollChild:SetHeight(max(1, -y))
	if S.scrollTrack then
		S.scrollTrack.Clamp()
	end
end

local function UpdateAllStats()
	if not S.statsPanel then
		return
	end
	local mode = db.secondaryText
	for _, entry in ipairs(S.statsValues) do
		local row = entry.row
		if row.value:IsShown() then
			if entry.stat.primary then
				row.label:SetText(StatName(entry.stat))
			end
			if entry.stat.rawFunc and entry.section == "Secondary" and mode == "both" then
				row.value:SetText(format("%d (%.2f%%)", entry.stat.rawFunc() or 0, entry.stat.func() or 0))
			elseif entry.stat.rawFunc and entry.section == "Secondary" and mode == "value" then
				row.value:SetText(format("%d", entry.stat.rawFunc() or 0))
			else
				local v = entry.stat.func()
				row.value:SetText(v ~= nil and format(entry.stat.format or "%d", v) or "0")
			end
		end
	end
end

-- Shows rows by their filters and sizes each section (22 + 16 per row).
local function RefreshStatsVisibility()
	for _, sec in ipairs(S.sections) do
		local count = 0
		for i, row in ipairs(sec.rows) do
			local shown = not sec.collapsed and StatShown(row.stat)
			row.label:SetShown(shown)
			row.value:SetShown(shown)
			row.button:SetShown(shown)
			if shown then
				count = count + 1
			end
			row.shownIndex = shown and count or nil
		end
		-- Leader lines only between visible rows; rows stack without gaps.
		local y = -22
		for _, row in ipairs(sec.rows) do
			if row.shownIndex then
				row.label:ClearAllPoints()
				row.label:SetPoint("TOPLEFT", sec.container, "TOPLEFT", 0, y)
				row.value:ClearAllPoints()
				row.value:SetPoint("TOPRIGHT", sec.container, "TOPRIGHT", 0, y)
				row.button:ClearAllPoints()
				row.button:SetPoint("TOPLEFT", sec.container, "TOPLEFT", 0, y)
				row.button:SetPoint("TOPRIGHT", sec.container, "TOPRIGHT", 0, y)
				row.divider:Show()
				y = y - 16
			else
				row.divider:Hide()
			end
		end
		sec.height = 22 + count * 16
	end
	RecalculateSections()
	UpdateAllStats()
end

local function UpdateSectionVisibility()
	for _, sec in ipairs(S.sections) do
		local shown = db.sections[sec.key] ~= false
		sec.container:SetShown(shown)
	end
	RecalculateSections()
end

local function RefreshSectionColors()
	for _, sec in ipairs(S.sections) do
		local r, g, b = SectionColor(sec.key)
		sec.titleFS:SetTextColor(r, g, b, 1)
		sec.leftBar:SetTexture(r, g, b, 0.8)
		sec.rightBar:SetTexture(r, g, b, 0.8)
		sec.upIcon:SetVertexColor(r, g, b, 1)
		sec.downIcon:SetVertexColor(r, g, b, 1)
		local blizz = BlizzColor()
		for _, row in ipairs(sec.rows) do
			if blizz then
				row.value:SetTextColor(0.7, 0.7, 0.7, 0.8)
			else
				row.value:SetTextColor(r, g, b, 1)
			end
		end
	end
	if S.iLvlText then
		local r, g, b = BlizzColor()
		if r then
			S.iLvlText:SetTextColor(r, g, b, 1)
		else
			S.iLvlText:SetTextColor(ILVL_PURPLE.r, ILVL_PURPLE.g, ILVL_PURPLE.b, 1)
		end
	end
end

local function SaveOrder()
	local order = {}
	for _, sec in ipairs(S.sections) do
		order[#order + 1] = sec.key
	end
	db.sectionOrder = order
end

local function MoveSection(sec, delta)
	local visible = {}
	for i, s in ipairs(S.sections) do
		if s.container:IsShown() then
			visible[#visible + 1] = i
		end
	end
	for v, i in ipairs(visible) do
		if S.sections[i] == sec then
			local other = visible[v + delta]
			if other then
				S.sections[i], S.sections[other] = S.sections[other], S.sections[i]
				SaveOrder()
				RecalculateSections()
			end
			return
		end
	end
end

local function BuildSection(def)
	local container = CreateFrame("Frame", nil, S.scrollChild)
	container:SetWidth(170)
	local sec = { key = def.key, container = container, rows = {}, height = 0, collapsed = db.collapsed[def.key] == true }

	local titleBtn = CreateFrame("Button", nil, container)
	titleBtn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
	titleBtn:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
	titleBtn:SetHeight(16)
	titleBtn:RegisterForClicks("LeftButtonUp")
	local title = NewText(titleBtn, 11)
	title:SetPoint("CENTER", titleBtn, "CENTER", 0, 0)
	title:SetText(def.title)
	sec.titleFS = title

	local function Arrow(file, point)
		local btn = CreateFrame("Button", nil, titleBtn)
		btn:SetSize(12, 12)
		btn:SetPoint(point, titleBtn, point, 0, 0)
		btn:SetFrameLevel(titleBtn:GetFrameLevel() + 2)
		local icon = btn:CreateTexture(nil, "OVERLAY")
		icon:SetAllPoints()
		icon:SetTexture(MEDIA .. file)
		icon:SetTexCoord(0, ICON_COORD, 0, ICON_COORD)
		return btn, icon
	end
	sec.upBtn, sec.upIcon = Arrow("eui-arrow-up3", "LEFT")
	sec.downBtn, sec.downIcon = Arrow("eui-arrow-down3", "RIGHT")
	sec.upBtn:SetScript("OnClick", function() MoveSection(sec, -1) end)
	sec.downBtn:SetScript("OnClick", function() MoveSection(sec, 1) end)

	sec.leftBar = Solid(titleBtn, "ARTWORK", 1, 1, 1, 0.8)
	sec.leftBar:SetHeight(1)
	sec.leftBar:SetPoint("LEFT", sec.upBtn, "RIGHT", 6, 0)
	sec.leftBar:SetPoint("RIGHT", title, "LEFT", -6, 0)
	sec.rightBar = Solid(titleBtn, "ARTWORK", 1, 1, 1, 0.8)
	sec.rightBar:SetHeight(1)
	sec.rightBar:SetPoint("LEFT", title, "RIGHT", 6, 0)
	sec.rightBar:SetPoint("RIGHT", sec.downBtn, "LEFT", -6, 0)

	for _, stat in ipairs(def.stats) do
		local row = { stat = stat }
		row.label = NewText(container, 10)
		row.label:SetTextColor(0.7, 0.7, 0.7, 0.8)
		row.label:SetText(StatName(stat))
		row.value = NewText(container, 10)
		row.value:SetJustifyH("RIGHT")
		row.value:SetText("0")
		row.button = CreateFrame("Button", nil, container)
		row.button:SetHeight(16)
		row.button:SetScript("OnEnter", function(self) StatTooltip(self, sec, stat, title) end)
		row.button:SetScript("OnLeave", function()
			GameTooltip:Hide()
			StopStatHighlights()
		end)
		-- Thin leader line between label and value.
		row.divider = Solid(container, "OVERLAY", 1, 1, 1, 0.06)
		row.divider:SetHeight(1)
		row.divider:SetPoint("LEFT", row.label, "RIGHT", 10, 0)
		row.divider:SetPoint("RIGHT", row.value, "LEFT", -10, 0)
		sec.rows[#sec.rows + 1] = row
		S.statsValues[#S.statsValues + 1] = { row = row, stat = stat, section = def.key }
	end

	titleBtn:SetScript("OnClick", function()
		sec.collapsed = not sec.collapsed
		db.collapsed[sec.key] = sec.collapsed or nil
		RefreshStatsVisibility()
	end)
	return sec
end

---------------------------------------------------------------------------
-- Better items in the bags (item level tooltip), spec aware like EllesmereUI
---------------------------------------------------------------------------
local INVTYPE_TO_SLOT = {
	INVTYPE_HEAD = { 1, "Head" }, INVTYPE_NECK = { 2, "Neck" }, INVTYPE_SHOULDER = { 3, "Shoulder" },
	INVTYPE_CHEST = { 5, "Chest" }, INVTYPE_ROBE = { 5, "Chest" }, INVTYPE_WAIST = { 6, "Waist" },
	INVTYPE_LEGS = { 7, "Legs" }, INVTYPE_FEET = { 8, "Feet" }, INVTYPE_WRIST = { 9, "Wrist" },
	INVTYPE_HAND = { 10, "Hands" }, INVTYPE_FINGER = { { 11, 12 }, "Ring" }, INVTYPE_TRINKET = { { 13, 14 }, "Trinket" },
	INVTYPE_CLOAK = { 15, "Cloak" }, INVTYPE_WEAPON = { { 16, 17 }, "Weapon" },
	INVTYPE_WEAPONMAINHAND = { 16, "Main Hand" }, INVTYPE_WEAPONOFFHAND = { 17, "Off Hand" },
	INVTYPE_HOLDABLE = { 17, "Off Hand" }, INVTYPE_RANGEDRIGHT = { 16, "Main Hand" }, INVTYPE_RANGED = { 16, "Main Hand" },
	INVTYPE_SHIELD = { 17, "Shield" }, INVTYPE_2HWEAPON = { 16, "Two-Hand" },
}

-- Weapon subclass keys in the order of GetAuctionItemSubClasses(1) in 5.4.8.
local WEAPON_ORDER = { "AXE1H", "AXE2H", "BOW", "GUN", "MACE1H", "MACE2H", "POLEARM", "SWORD1H", "SWORD2H",
	"STAFF", "FIST", "MISC", "DAGGER", "THROWN", "CROSSBOW", "WAND", "FISHING" }
local function W(...)
	local t = {}
	for i = 1, select("#", ...) do
		t[select(i, ...)] = true
	end
	return t
end
local SPEC_EQUIP = {
	[250] = { weapons = W("AXE2H", "MACE2H", "SWORD2H", "POLEARM") },
	[251] = { weapons = W("AXE1H", "MACE1H", "SWORD1H", "AXE2H", "MACE2H", "SWORD2H", "POLEARM") },
	[252] = { weapons = W("AXE2H", "MACE2H", "SWORD2H", "POLEARM") },
	[102] = { weapons = W("STAFF", "POLEARM", "MACE2H", "DAGGER", "MACE1H", "FIST"), offhand = true },
	[103] = { weapons = W("STAFF", "POLEARM", "MACE2H") },
	[104] = { weapons = W("STAFF", "POLEARM", "MACE2H") },
	[105] = { weapons = W("STAFF", "POLEARM", "MACE2H", "DAGGER", "MACE1H", "FIST"), offhand = true },
	[253] = { weapons = W("BOW", "GUN", "CROSSBOW") },
	[254] = { weapons = W("BOW", "GUN", "CROSSBOW") },
	[255] = { weapons = W("BOW", "GUN", "CROSSBOW") },
	[62] = { weapons = W("STAFF", "DAGGER", "SWORD1H", "WAND"), offhand = true },
	[63] = { weapons = W("STAFF", "DAGGER", "SWORD1H", "WAND"), offhand = true },
	[64] = { weapons = W("STAFF", "DAGGER", "SWORD1H", "WAND"), offhand = true },
	[268] = { weapons = W("STAFF", "POLEARM", "FIST", "AXE1H", "MACE1H", "SWORD1H") },
	[269] = { weapons = W("FIST", "AXE1H", "MACE1H", "SWORD1H", "STAFF", "POLEARM") },
	[270] = { weapons = W("STAFF", "POLEARM", "FIST", "AXE1H", "MACE1H", "SWORD1H"), offhand = true },
	[65] = { weapons = W("MACE1H", "SWORD1H", "AXE1H"), shield = true, offhand = true },
	[66] = { weapons = W("MACE1H", "SWORD1H", "AXE1H"), shield = true },
	[70] = { weapons = W("MACE2H", "SWORD2H", "AXE2H", "POLEARM") },
	[256] = { weapons = W("STAFF", "WAND", "DAGGER", "MACE1H"), offhand = true },
	[257] = { weapons = W("STAFF", "WAND", "DAGGER", "MACE1H"), offhand = true },
	[258] = { weapons = W("STAFF", "WAND", "DAGGER", "MACE1H"), offhand = true },
	[259] = { weapons = W("DAGGER") },
	[260] = { weapons = W("SWORD1H", "MACE1H", "AXE1H", "FIST", "DAGGER") },
	[261] = { weapons = W("DAGGER") },
	[262] = { weapons = W("STAFF", "MACE1H", "AXE1H", "DAGGER", "FIST"), shield = true, offhand = true },
	[263] = { weapons = W("MACE1H", "AXE1H", "FIST") },
	[264] = { weapons = W("STAFF", "MACE1H", "AXE1H", "DAGGER", "FIST"), shield = true, offhand = true },
	[265] = { weapons = W("STAFF", "WAND", "DAGGER", "SWORD1H"), offhand = true },
	[266] = { weapons = W("STAFF", "WAND", "DAGGER", "SWORD1H"), offhand = true },
	[267] = { weapons = W("STAFF", "WAND", "DAGGER", "SWORD1H"), offhand = true },
	[71] = { weapons = W("AXE2H", "MACE2H", "SWORD2H", "POLEARM") },
	[72] = { weapons = W("AXE1H", "MACE1H", "SWORD1H", "AXE2H", "MACE2H", "SWORD2H", "POLEARM") },
	[73] = { weapons = W("AXE1H", "MACE1H", "SWORD1H"), shield = true },
}
-- Frost DK, Fury, rogues, Enhancement, Brewmaster, Windwalker.
local DUAL_WIELD_SPECS = { [251] = true, [72] = true, [259] = true, [260] = true, [261] = true, [263] = true, [268] = true, [269] = true }
local CLASS_ARMOR = { -- index in GetAuctionItemSubClasses(2): 2 cloth, 3 leather, 4 mail, 5 plate
	PALADIN = 5, DEATHKNIGHT = 5, WARRIOR = 5, HUNTER = 4, SHAMAN = 4,
	DRUID = 3, MONK = 3, ROGUE = 3, MAGE = 2, PRIEST = 2, WARLOCK = 2,
}

local itemClassNames
local function ItemClassNames()
	if itemClassNames then
		return itemClassNames
	end
	itemClassNames = { weapon = nil, armor = nil, weapons = {}, armors = {} }
	if GetAuctionItemClasses then
		local classes = { GetAuctionItemClasses() }
		itemClassNames.weapon, itemClassNames.armor = classes[1], classes[2]
		local weapons = { GetAuctionItemSubClasses(1) }
		if #weapons == #WEAPON_ORDER then
			for i, name in ipairs(weapons) do
				itemClassNames.weapons[name] = WEAPON_ORDER[i]
			end
		end
		local armors = { GetAuctionItemSubClasses(2) }
		for i = 1, min(5, #armors) do
			itemClassNames.armors[armors[i]] = i
		end
	end
	return itemClassNames
end

local function UsableBySpec(itemType, subType, equipLoc)
	local allow = SPEC_EQUIP[SpecID() or 0]
	if not allow then
		return true
	end
	local names = ItemClassNames()
	if equipLoc == "INVTYPE_SHIELD" then
		return allow.shield == true
	end
	if equipLoc == "INVTYPE_HOLDABLE" then
		return allow.offhand == true
	end
	if itemType == names.weapon then
		local key = names.weapons[subType]
		if not key then
			return true
		end
		return allow.weapons[key] == true
	end
	if itemType == names.armor then
		if equipLoc == "INVTYPE_CLOAK" or equipLoc == "INVTYPE_TABARD" or equipLoc == "INVTYPE_BODY" then
			return true
		end
		local tier = names.armors[subType]
		if not tier or tier == 1 then
			return true -- miscellaneous (rings, necks, trinkets)
		end
		local _, class = UnitClass("player")
		return CLASS_ARMOR[class] == nil or CLASS_ARMOR[class] == tier
	end
	return true
end

local betterCache, betterDirty = nil, true

local function ComputeBetterItems()
	local better = {}
	local names = ItemClassNames()
	-- 5.4.8 has no CanDualWield(): the specs that can.
	local canDualWield = DUAL_WIELD_SPECS[SpecID() or 0] or false
	local offHandBlocked = false
	local mhLink = GetInventoryItemLink("player", 16)
	if mhLink and not GetInventoryItemLink("player", 17) then
		local _, _, _, _, _, _, _, _, mhLoc = GetItemInfo(mhLink)
		if mhLoc == "INVTYPE_2HWEAPON" or mhLoc == "INVTYPE_RANGED" or mhLoc == "INVTYPE_RANGEDRIGHT" then
			offHandBlocked = true
		end
	end
	local playerLevel = UnitLevel("player")
	for bag = 0, NUM_BAG_SLOTS or 4 do
		for slot = 1, GetContainerNumSlots(bag) do
			local link = GetContainerItemLink(bag, slot)
			if link then
				local name, _, quality, baseLevel, reqLevel, itemType, subType, _, equipLoc, icon = GetItemInfo(link)
				if name and equipLoc and INVTYPE_TO_SLOT[equipLoc]
					and (itemType == names.weapon or itemType == names.armor)
					and (reqLevel or 0) <= playerLevel
					and UsableBySpec(itemType, subType, equipLoc) then
					local info = ScanBag(bag, slot)
					local level = (info and info.ilvl) or baseLevel or 0
					local map = INVTYPE_TO_SLOT[equipLoc]
					local targets = type(map[1]) == "table" and map[1] or { map[1] }
					local weaponBlocked = not canDualWield and (equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_WEAPONOFFHAND")
					for _, target in ipairs(targets) do
						if not (target == 17 and (offHandBlocked or weaponBlocked)) and level > EquippedItemLevel(target) then
							better[#better + 1] = { name = name, level = level, quality = quality or 1, icon = icon, slot = map[2] }
							break
						end
					end
				end
			end
		end
	end
	-- Only the best item per slot.
	local best = {}
	for _, item in ipairs(better) do
		local cur = best[item.slot]
		if not cur or item.level > cur.level then
			best[item.slot] = item
		end
	end
	local list = {}
	for _, item in pairs(best) do
		list[#list + 1] = item
	end
	table.sort(list, function(a, b) return a.level > b.level end)
	return list
end

local function BetterItems()
	if betterDirty or not betterCache then
		betterCache = ComputeBetterItems()
		betterDirty = false
	end
	return betterCache
end

---------------------------------------------------------------------------
-- Stats panel: item level header, durability, sections
---------------------------------------------------------------------------
local HEADER_H -- top of the stat sections, below the item level line

local function UpdateScrollHeaderOffset()
	if not S.scrollFrame then
		return
	end
	local h = HEADER_H
	local loc = db.durabilityLocation
	if loc == "footer" and Stock() then
		loc = "header"
	end
	if db.showDurability and loc == "header" then
		h = h + 16
	end
	local left = Stock() and 12 or 0
	S.scrollFrame:ClearAllPoints()
	S.scrollFrame:SetPoint("TOPLEFT", S.statsPanel, "TOPLEFT", left, -h)
	S.scrollFrame:SetPoint("BOTTOMRIGHT", S.statsPanel, "BOTTOMRIGHT", -12, 2)
	S.scrollTrack:ClearAllPoints()
	S.scrollTrack:SetPoint("TOPRIGHT", S.statsPanel, "TOPRIGHT", -2, -h)
	S.scrollTrack:SetPoint("BOTTOMRIGHT", S.statsPanel, "BOTTOMRIGHT", -2, 0)
	S.scrollTrack.Update()
end

local function UpdateItemLevelDisplay()
	if not S.iLvlText then
		return
	end
	local avg, equipped = GetAverageItemLevel()
	avg, equipped = avg or 0, equipped or avg or 0
	local avgText, eqText = format("%.2f", avg), format("%.2f", equipped)
	if avgText ~= eqText and #BetterItems() > 0 then
		S.iLvlText:SetText(format("%s / %s", eqText, avgText))
	else
		S.iLvlText:SetText(eqText)
	end
end

local function UpdateDurability()
	local labels = S.durability
	if not labels then
		return
	end
	labels.model:Hide()
	labels.header:Hide()
	labels.footer:Hide()
	if not (SheetOn() and db.showDurability) then
		return
	end
	local loc = db.durabilityLocation or "model"
	if loc == "footer" and Stock() then
		loc = "header"
	end
	local pct = DurabilityPercent()
	local r, g, b = DurabilityColor(pct)
	local text = db.durabilityShowLabel and ((DURABILITY or "Durability") .. ": " .. pct .. "%") or (pct .. "%")
	local fs = labels[loc] or labels.model
	fs:SetText(text)
	fs:SetTextColor(r, g, b, 1)
	fs:Show()
end

local function BuildStatsPanel()
	local frame = CharacterFrame
	local statsPanel
	if Stock() then
		-- Blizz Default: a child of Blizzard's stats pane (parked off-screen),
		-- laid over the pane's own right inset, so the sidebar tabs show and hide it.
		CharacterStatsPane:ClearAllPoints()
		CharacterStatsPane:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -10000)
		CharacterStatsPane:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, -10000)
		statsPanel = CreateFrame("Frame", "EUI_CharSheetStats", CharacterStatsPane)
		statsPanel:SetPoint("TOPLEFT", CharacterFrameInsetRight, "TOPLEFT", 3, -3)
		statsPanel:SetPoint("BOTTOMRIGHT", CharacterFrameInsetRight, "BOTTOMRIGHT", -3, 2)
		statsPanel:SetFrameLevel(CharacterFrameInsetRight:GetFrameLevel() + 5)
		HEADER_H = 55 - 16 -- no Mythic+ line in 5.4.8
	else
		-- Fixed 190 px column down the right of the sheet.
		statsPanel = CreateFrame("Frame", "EUI_CharSheetStats", PaperDollFrame)
		statsPanel:SetWidth(190)
		statsPanel:SetPoint("TOPLEFT", frame, "TOPRIGHT", -STATS_X, -60)
		statsPanel:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", -STATS_X, 40)
		statsPanel:SetFrameLevel(frame:GetFrameLevel() + 10)
		local sidebarBg = CreateFrame("Frame", nil, PaperDollFrame)
		sidebarBg:SetFrameLevel(frame:GetFrameLevel() + 1)
		sidebarBg:SetPoint("TOPLEFT", statsPanel, "TOPLEFT", -51, 10)
		sidebarBg:SetPoint("BOTTOMRIGHT", statsPanel, "BOTTOMRIGHT", 0, -10)
		Solid(sidebarBg, "BACKGROUND", 0, 0, 0, 0.2):SetAllPoints()
		HEADER_H = 75 - 16
	end
	S.statsPanel = statsPanel

	-- Item level: 18 px, purple (Blizzard yellow with Blizzard UI Color).
	local iLvl = NewText(statsPanel, 18)
	iLvl:SetPoint("TOP", statsPanel, "TOP", 0, Stock() and -8 or -(25 + 3))
	S.iLvlText = iLvl

	local iLvlButton = CreateFrame("Button", nil, statsPanel)
	iLvlButton:SetPoint("TOPLEFT", iLvl, "TOPLEFT", -10, 4)
	iLvlButton:SetPoint("BOTTOMRIGHT", iLvl, "BOTTOMRIGHT", 10, -4)
	iLvlButton:SetFrameLevel(statsPanel:GetFrameLevel() + 3)
	iLvlButton:SetScript("OnEnter", function(self)
		local items = BetterItems()
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Equipped Item Level", ILVL_PURPLE.r, ILVL_PURPLE.g, ILVL_PURPLE.b, 1)
		GameTooltip:AddLine(" ")
		if #items > 0 then
			GameTooltip:AddLine(format("You have %d better item%s in inventory", #items, #items == 1 and "" or "s"), 0.2, 1, 0.2)
			GameTooltip:AddLine(" ")
			for i = 1, min(#items, 10) do
				local item = items[i]
				GameTooltip:AddDoubleLine(format("|T%s:16|t  %s (iLvl %d)", item.icon or "", item.name, item.level), item.slot, 1, 1, 1, 0.7, 0.7, 0.7)
			end
			if #items > 10 then
				GameTooltip:AddLine(format("  ... and %d more", #items - 10), 0.7, 0.7, 0.7)
			end
		else
			GameTooltip:AddLine("No better items in inventory", 0.7, 0.7, 0.7, true)
		end
		GameTooltip:Show()
	end)
	iLvlButton:SetScript("OnLeave", HideTooltip)

	-- Durability: above the model, in the stats header, or in the frame footer.
	local durability = {}
	local modelAnchor = Stock() and CharacterModelFrame or S.model
	local overlay = CreateFrame("Frame", nil, PaperDollFrame)
	overlay:SetFrameLevel((modelAnchor and modelAnchor:GetFrameLevel() or frame:GetFrameLevel()) + 10)
	durability.model = NewText(overlay, 12)
	if modelAnchor then
		durability.model:SetPoint("TOP", modelAnchor, "TOP", 0, Stock() and -46 or -8)
	end
	durability.header = NewText(statsPanel, 12)
	durability.header:SetPoint("TOP", iLvl, "BOTTOM", 0, -4)
	durability.footer = NewText(PaperDollFrame, 12)
	durability.footer:SetPoint("RIGHT", frame, "BOTTOMRIGHT", -10, 6)
	for _, fs in pairs(durability) do
		fs:Hide()
	end
	S.durability = durability

	-- Scroll area with the stat sections.
	local scrollFrame = CreateFrame("ScrollFrame", "EUI_CharSheetStatsScroll", statsPanel)
	scrollFrame:SetFrameLevel(statsPanel:GetFrameLevel() + 1)
	local scrollChild = CreateFrame("Frame", nil, scrollFrame)
	scrollChild:SetWidth(170)
	scrollFrame:SetScrollChild(scrollChild)
	-- The child (and the sections anchored to it) follow the scroll width.
	scrollFrame:HookScript("OnSizeChanged", function(_, w)
		if w and w > 0 then
			scrollChild:SetWidth(w)
		end
	end)
	S.scrollFrame, S.scrollChild = scrollFrame, scrollChild
	S.scrollTrack = AttachScrollbar(scrollFrame, scrollChild, statsPanel, -HEADER_H)
	UpdateScrollHeaderOffset()
	local w = scrollFrame:GetWidth()
	if w and w > 0 then
		scrollChild:SetWidth(w)
	end

	local defs = SectionDefs()
	local byKey = {}
	for _, def in ipairs(defs) do
		byKey[def.key] = def
	end
	-- Saved order first, then any section the saved order does not know.
	local ordered, used = {}, {}
	for _, key in ipairs(db.sectionOrder or {}) do
		if byKey[key] and not used[key] then
			ordered[#ordered + 1] = byKey[key]
			used[key] = true
		end
	end
	for _, def in ipairs(defs) do
		if not used[def.key] then
			ordered[#ordered + 1] = def
		end
	end
	for _, def in ipairs(ordered) do
		S.sections[#S.sections + 1] = BuildSection(def)
	end

	RefreshSectionColors()
	UpdateSectionVisibility()
	RefreshStatsVisibility()
end

---------------------------------------------------------------------------
-- Sidebar labels (Character / Titles / Equipment), titles list, equipment sets
---------------------------------------------------------------------------
local topButtons = {}

local function PaintTopButton(btn)
	local t = btn.text
	if btn.active then
		t:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b, 1)
	elseif btn.disabled then
		t:SetTextColor(1, 1, 1, 0.25)
	elseif btn.hover then
		t:SetTextColor(1, 1, 1, 1)
	else
		t:SetTextColor(1, 1, 1, 0.6)
	end
end

local function SyncTopButtons()
	for _, btn in ipairs(topButtons) do
		local info = PAPERDOLL_SIDEBARS and PAPERDOLL_SIDEBARS[btn.paneIndex]
		local pane = info and _G[info.frame]
		btn.active = pane and pane:IsShown() and true or false
		btn.disabled = btn.tab and not btn.tab:IsEnabled() and true or false
		PaintTopButton(btn)
		if btn.panel then
			btn.panel:SetShown(btn.active)
		end
	end
end

local RefreshTitlesList

local function BuildTitlesPanel()
	local panel = CreateFrame("Frame", "EUI_CharSheetTitles", PaperDollFrame)
	panel:SetWidth(190)
	panel:SetPoint("TOPLEFT", S.statsPanel, "TOPLEFT", 0, 0)
	panel:SetPoint("BOTTOMLEFT", S.statsPanel, "BOTTOMLEFT", 0, 0)
	panel:SetFrameLevel(S.statsPanel:GetFrameLevel())
	panel:Hide()
	S.titlesPanel = panel

	local search = CreateFrame("EditBox", "EUI_CharSheetTitlesSearch", panel)
	search:SetSize(180, 24)
	search:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -30)
	search:SetAutoFocus(false)
	search:SetMaxLetters(20)
	Solid(search, "BACKGROUND", 0, 0, 0, 0.5):SetAllPoints()
	search:SetFont(ns.GetFontPath and ns.GetFontPath("blizzardSkin") or FONT, 10, "")
	if not search:GetFont() then
		search:SetFont(FONT_FALLBACK, 10, "")
	end
	search:SetTextColor(1, 1, 1, 1)
	search:SetTextInsets(4, 4, 0, 0)
	local hint = NewText(search, 10)
	hint:SetText("Search titles...")
	hint:SetTextColor(0.6, 0.6, 0.6, 0.7)
	hint:SetPoint("LEFT", search, "LEFT", 4, 0)
	local clearX = NewText(search, 11)
	clearX:SetText("x")
	clearX:SetTextColor(0.7, 0.7, 0.7, 1)
	clearX:SetPoint("RIGHT", search, "RIGHT", -4, 0)
	clearX:Hide()
	local clearHit = CreateFrame("Button", nil, search)
	clearHit:SetSize(14, 14)
	clearHit:SetPoint("CENTER", clearX, "CENTER", 0, 0)
	clearHit:Hide()
	clearHit:SetScript("OnClick", function()
		search:SetText("")
		search:ClearFocus()
	end)

	local scroll = CreateFrame("ScrollFrame", "EUI_CharSheetTitlesScroll", panel)
	scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -65)
	scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetWidth(180)
	child:SetHeight(1)
	scroll:SetScrollChild(child)
	AttachScrollbar(scroll, child, panel, -65)

	local TILE_H, TILE_STEP = 24, 26
	local buttons, order, built = {}, {}, false

	local function PaintSelection()
		local current = GetCurrentTitle and GetCurrentTitle() or -1
		if not current or current <= 0 then
			current = -1
		end
		for id, btn in pairs(buttons) do
			if id == current then
				btn.bg:SetTexture(ACCENT.r, ACCENT.g, ACCENT.b, 0.5)
			else
				btn.bg:SetTexture(1, 1, 1, 0.04)
			end
		end
	end
	S.paintTitleSelection = PaintSelection

	local function CreateTitleButton(id, text)
		local btn = CreateFrame("Button", nil, child)
		btn:SetSize(180, TILE_H)
		btn.bg = Solid(btn, "BACKGROUND", 1, 1, 1, 0.05)
		btn.bg:SetAllPoints()
		btn.hover = Solid(btn, "ARTWORK", 1, 1, 1, 0.1)
		btn.hover:SetAllPoints()
		btn.hover:Hide()
		btn.text = NewText(btn, 11)
		btn.text:SetTextColor(1, 1, 1, 1)
		btn.text:SetPoint("LEFT", btn, "LEFT", 10, 0)
		btn.text:SetText(text)
		btn.titleName = text
		btn.titleId = id
		btn:SetScript("OnEnter", function(self) self.hover:Show() end)
		btn:SetScript("OnLeave", function(self) self.hover:Hide() end)
		btn:SetScript("OnClick", function(self)
			PlaySound("igMainMenuOptionCheckBoxOff")
			SetCurrentTitle(self.titleId)
		end)
		buttons[id] = btn
		return btn
	end

	local function Build()
		if built then
			return
		end
		built = true
		CreateTitleButton(-1, PLAYER_TITLE_NONE or "No Title")
		for i = 1, GetNumTitles() do
			local known = IsTitleKnown(i)
			if known and known ~= 0 then
				local name = GetTitleName(i)
				if name then
					CreateTitleButton(i, strtrim(name))
				end
			end
		end
		wipe(order)
		for id in pairs(buttons) do
			order[#order + 1] = id
		end
		local function SortKey(id)
			return (buttons[id].titleName or ""):gsub("%%s", " "):gsub("^%s+", ""):gsub("%s+$", ""):lower()
		end
		table.sort(order, function(a, b)
			if a == -1 then
				return true
			elseif b == -1 then
				return false
			end
			return SortKey(a) < SortKey(b)
		end)
	end

	RefreshTitlesList = function()
		Build()
		local filter = (search:GetText() or ""):lower()
		local y = 0
		for _, id in ipairs(order) do
			local btn = buttons[id]
			local visible = filter == "" or id == -1 or (btn.titleName or ""):lower():find(filter, 1, true)
			if visible then
				btn:ClearAllPoints()
				btn:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
				btn:Show()
				y = y - TILE_STEP
			else
				btn:Hide()
			end
		end
		PaintSelection()
		child:SetHeight(max(1, -y))
		scroll:SetVerticalScroll(0)
	end

	local invalidate = CreateFrame("Frame")
	RegisterEvents(invalidate, { "KNOWN_TITLES_UPDATE", "UNIT_NAME_UPDATE", "PLAYER_PVP_RANK_CHANGED" })
	invalidate:SetScript("OnEvent", function(_, event, unit)
		if event == "KNOWN_TITLES_UPDATE" then
			built = false
			for id, btn in pairs(buttons) do
				btn:Hide()
				buttons[id] = nil
			end
			if panel:IsShown() then
				RefreshTitlesList()
			end
		elseif unit == nil or unit == "player" then
			PaintSelection()
		end
	end)

	search:SetScript("OnTextChanged", function(self)
		local has = (self:GetText() or "") ~= ""
		clearX:SetShown(has)
		clearHit:SetShown(has)
		RefreshTitlesList()
	end)
	search:SetScript("OnEditFocusGained", function(self)
		if self:GetText() == "" then
			hint:Hide()
		end
	end)
	search:SetScript("OnEditFocusLost", function(self)
		if self:GetText() == "" then
			hint:Show()
		end
	end)
	search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	panel:SetScript("OnShow", function()
		search:SetText("")
		RefreshTitlesList()
	end)
end

-- Blizzard's equipment set rows in the flat EllesmereUI look.
local function SkinEquipmentRows()
	local pane = PaperDollEquipmentManagerPane
	if not pane or not pane.buttons then
		return
	end
	for _, button in ipairs(pane.buttons) do
		for _, key in ipairs({ "BgTop", "BgMiddle", "BgBottom" }) do
			if button[key] then
				button[key]:SetAlpha(0)
			end
		end
		if button.Stripe then
			button.Stripe:SetTexture(1, 1, 1, 1)
			button.Stripe:SetAlpha(0.04)
			button.Stripe:Show()
		end
		if button.SelectedBar then
			button.SelectedBar:SetTexture(ACCENT.r, ACCENT.g, ACCENT.b, 1)
			button.SelectedBar:SetBlendMode("BLEND")
			button.SelectedBar:SetAlpha(0.2)
		end
		if button.HighlightBar then
			button.HighlightBar:SetTexture(1, 1, 1, 1)
			button.HighlightBar:SetBlendMode("BLEND")
			button.HighlightBar:SetAlpha(0.08)
		end
		if button.text then
			SetFont(button.text, 11)
			-- Gold set names read white; red (items missing) and the green New Set stay.
			if button.name then
				local _, _, _, _, _, _, _, numLost = GetEquipmentSetInfoByName(button.name)
				if (numLost or 0) == 0 then
					button.text:SetTextColor(1, 1, 1, 1)
				end
			end
		end
	end
end

local function BuildSidebar()
	local function LabelButton(name, label, paneIndex)
		local btn = CreateFrame("Frame", "EUI_CharSheet" .. name, PaperDollFrame)
		btn:SetSize(64, 25)
		btn:SetPoint("TOPLEFT", S.statsPanel, "TOPLEFT", (#topButtons) * (64 - 6), 0)
		btn:SetFrameLevel(S.statsPanel:GetFrameLevel() + 2)
		btn.text = NewText(btn, 10)
		btn.text:SetPoint("TOP", btn, "TOP", 0, 0)
		btn.text:SetText(label)
		btn.paneIndex = paneIndex
		btn.tab = _G["PaperDollSidebarTab" .. paneIndex]
		topButtons[#topButtons + 1] = btn
		-- Blizzard's own sidebar tab sits over the label (art faded out), so a
		-- click is a real click on Blizzard's button and keeps its tooltip.
		local tab = btn.tab
		if tab then
			tab:ClearAllPoints()
			tab:SetAllPoints(btn)
			tab:SetFrameLevel(btn:GetFrameLevel() + 1)
			for _, key in ipairs({ "TabBg", "Icon", "Hider", "Highlight" }) do
				if tab[key] then
					tab[key]:SetAlpha(0)
				end
			end
			tab:HookScript("OnEnter", function()
				btn.hover = true
				PaintTopButton(btn)
			end)
			tab:HookScript("OnLeave", function()
				btn.hover = false
				PaintTopButton(btn)
			end)
		end
		PaintTopButton(btn)
		return btn
	end

	LabelButton("StatsLabel", "Character", 1).panel = S.statsPanel
	BuildTitlesPanel()
	LabelButton("TitlesLabel", "Titles", 2).panel = S.titlesPanel
	LabelButton("EquipmentLabel", "Equipment", 3)
	hooksecurefunc("PaperDollFrame_UpdateSidebarTabs", SyncTopButtons)
	SyncTopButtons()

	-- Equipment Manager pane moves into the column under the labels.
	local pane = PaperDollEquipmentManagerPane
	if pane then
		pane:ClearAllPoints()
		pane:SetPoint("TOPLEFT", S.statsPanel, "TOPLEFT", 0, -27)
		pane:SetPoint("BOTTOMRIGHT", S.statsPanel, "BOTTOMRIGHT", -21, 0)
		pane:SetFrameLevel(S.statsPanel:GetFrameLevel() + 1)
		hooksecurefunc("PaperDollEquipmentManagerPane_Update", SkinEquipmentRows)
		if pane.scrollBar then
			pane.scrollBar:HookScript("OnValueChanged", SkinEquipmentRows)
		end
	end
end

---------------------------------------------------------------------------
-- Slot text: item level, upgrade level, enchant; gems; missing enchant pulse
---------------------------------------------------------------------------
local missingSlots = {}
local pulseTicker

local function SetSlotMissing(slotName, missing)
	local data = S.slots[slotName]
	local slot = _G[slotName]
	if not data or not slot then
		return
	end
	if missing then
		if not data.missing then
			local f = CreateFrame("Frame", nil, slot)
			f:SetAllPoints(slot)
			f:SetFrameLevel(slot:GetFrameLevel() + 2)
			f.edges = CreateBorder(f, 2, MISSING_RED.r, MISSING_RED.g, MISSING_RED.b, 1, "OVERLAY")
			data.missing = f
		end
		data.missing:Show()
		missingSlots[slotName] = data.missing
		pulseTicker:Show()
	else
		if data.missing then
			data.missing:Hide()
		end
		missingSlots[slotName] = nil
		if not next(missingSlots) then
			pulseTicker:Hide()
		end
	end
end

local function BuildSlotLabels()
	local overlay = CreateFrame("Frame", "EUI_CharSheetTextOverlay", PaperDollFrame)
	if Stock() then
		overlay:SetFrameLevel((CharacterModelFrame and CharacterModelFrame:GetFrameLevel() or CharacterFrame:GetFrameLevel()) + 10)
	else
		overlay:SetFrameLevel(CharacterFrame:GetFrameLevel() + 6)
	end
	overlay:SetAllPoints(CharacterFrame)
	overlay:EnableMouse(false)
	S.textOverlay = overlay

	-- Blizz Default keeps Blizzard's bronze slot frames, so the text sits further out.
	local LX = Stock() and 22 or 15
	local EX = Stock() and 12 or 5

	pulseTicker = CreateFrame("Frame", nil, PaperDollFrame)
	pulseTicker:Hide()
	pulseTicker:SetScript("OnUpdate", function()
		local a = 0.25 + 0.75 * (0.5 + 0.5 * math.sin(GetTime() * math.pi / 0.75))
		for _, f in pairs(missingSlots) do
			f:SetAlpha(a)
		end
	end)

	local gemContainer
	if Themed() then
		gemContainer = CreateFrame("Frame", nil, PaperDollItemsFrame or PaperDollFrame)
		gemContainer:SetAllPoints(CharacterFrame)
		gemContainer:SetFrameLevel(CharacterHeadSlot:GetFrameLevel() + 4)
	end

	for _, slotName in ipairs(GEAR_SLOTS) do
		local slot = _G[slotName]
		local data = S.slots[slotName] or {}
		S.slots[slotName] = data
		local left = LEFT_COLUMN[slotName]
		local mainHand = slotName == "CharacterMainHandSlot"

		data.itemLevel = NewText(overlay, ITEM_LEVEL_SIZE)
		data.itemLevel:SetTextColor(1, 1, 1, 0.8)
		data.itemLevel:SetJustifyH("CENTER")
		if left then
			data.itemLevel:SetPoint("CENTER", slot, "RIGHT", LX, 10)
		else
			data.itemLevel:SetPoint("CENTER", slot, "LEFT", -LX, 10)
		end

		data.enchant = NewText(overlay, db.enchantSize or 9)
		data.enchant:SetTextColor(1, 1, 1, 0.8)
		data.enchant:SetWordWrap(false)
		local hover = CreateFrame("Frame", nil, overlay)
		hover:SetSize(20, 20)
		hover:SetFrameLevel(overlay:GetFrameLevel() + 20)
		hover:EnableMouse(true)
		hover:Hide()
		if left then
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

		data.upgrade = NewText(overlay, UPGRADE_SIZE)
		data.upgrade:SetTextColor(1, 1, 1, 0.6)
		data.upgrade:SetJustifyH("CENTER")
		if left then
			data.upgrade:SetPoint("LEFT", data.itemLevel, "RIGHT", 3, 0)
		else
			data.upgrade:SetPoint("RIGHT", data.itemLevel, "LEFT", -3, 0)
		end

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
		if mainHand then
			data.isMainHand = true
		end
	end

	-- Eye toggle in the top left: hides all slot text for the session.
	if Themed() then
		local hidden = false
		local eye = CreateFrame("Button", "EUI_CharSheetTextEye", PaperDollFrame)
		eye:SetSize(20, 20)
		eye:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 14, -6)
		eye:SetFrameLevel(CharacterFrame:GetFrameLevel() + 20)
		eye:SetAlpha(0.4)
		local tex = eye:CreateTexture(nil, "OVERLAY")
		tex:SetAllPoints()
		tex:SetTexture(MEDIA .. "eui-visible")
		tex:SetTexCoord(0, ICON_COORD, 0, ICON_COORD)
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

local function UpdateGems(slotName, link)
	local data = S.slots[slotName]
	if not data or not data.gems then
		return
	end
	local entries = {}
	if link and db.showGems then
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
				g.edges:SetColor(0.75, 0.75, 0.75, 1) -- silver
			else
				g.edges:SetColor(1, 0.82, 0, 1) -- gold
			end
			g:Show()
		else
			g.link = nil
			g:Hide()
		end
	end
end

-- Stat Letters (retail charSheetItemStats): the secondary stats an item has,
-- as letters (C Crit, H Haste, M Mastery, Hit, Exp, S Spirit, D Dodge, P Parry,
-- PvP Power, Res). GetItemStats reads the item's base stats (not reforges).
local STAT_LETTERS = {
	{ "ITEM_MOD_CRIT_RATING_SHORT", "C" }, { "ITEM_MOD_HASTE_RATING_SHORT", "H" },
	{ "ITEM_MOD_MASTERY_RATING_SHORT", "M" }, { "ITEM_MOD_HIT_RATING_SHORT", "Hit" },
	{ "ITEM_MOD_EXPERTISE_RATING_SHORT", "Exp" }, { "ITEM_MOD_SPIRIT_SHORT", "S" },
	{ "ITEM_MOD_DODGE_RATING_SHORT", "D" }, { "ITEM_MOD_PARRY_RATING_SHORT", "P" },
	{ "ITEM_MOD_PVP_POWER_SHORT", "PvP" }, { "ITEM_MOD_RESILIENCE_RATING_SHORT", "Res" },
}
local statScratch = {}
function ns.ItemStatLetters(link)
	wipe(statScratch)
	local stats = GetItemStats(link, statScratch)
	if not stats then
		return nil
	end
	local out
	for _, e in ipairs(STAT_LETTERS) do
		if (stats[e[1]] or 0) > 0 then
			out = out and (out .. " " .. e[2]) or e[2]
		end
	end
	return out
end

local function UpdateSlotInfo(slotName)
	local slot, data = _G[slotName], S.slots[slotName]
	if not slot or not data or not data.itemLevel then
		return
	end
	local slotID = slot:GetID()
	local link = GetInventoryItemLink("player", slotID)
	local info = link and ScanInventory(slotID)
	local quality = link and GetInventoryItemQuality("player", slotID)
	local r, g, b = QualityColor(quality)

	-- Item level, colored by quality.
	if db.showItemLevel and link then
		local ilvl = (info and info.ilvl) or select(4, GetItemInfo(link)) or ""
		data.itemLevel:SetText(tostring(ilvl))
		data.itemLevel:SetTextColor(r, g, b, 0.9)
		data.itemLevel:Show()
	else
		data.itemLevel:Hide()
	end

	-- Upgrade level "(1/2)" in place of the retail upgrade track, then the
	-- Stat Letters (retail charSheetItemStats: the item's secondary stats).
	local up = (db.showUpgradeTrack and info and info.upCur and info.upMax and info.upMax > 0)
		and ("(" .. info.upCur .. "/" .. info.upMax .. ")") or nil
	local letters = db.charSheetItemStats and link and ns.ItemStatLetters(link) or nil
	if up or letters then
		data.upgrade:SetText(up and letters and (up .. " " .. letters) or up or letters)
		data.upgrade:SetTextColor(r, g, b, 0.8)
		data.upgrade:Show()
	else
		data.upgrade:Hide()
	end

	-- Enchant: "Text" = plain name, "Colored Text" = outlined name in the item
	-- level color, a red "Missing" when a level 90 item has no enchant.
	local enchant = info and info.enchant
	local canEnchant = ENCHANT_SLOTS[slotID] or (RING_SLOTS[slotID] and IsEnchanter())
	local missing = link and canEnchant and not enchant and (UnitLevel("player") or 0) >= 90
	local size = db.enchantSize or 9
	if db.showEnchants and (enchant or missing) then
		local text = enchant or "Missing"
		data.enchantTip = enchant or "Enchant missing"
		if missing then
			SetFont(data.enchant, size, "")
			data.enchant:SetTextColor(MISSING_RED.r, MISSING_RED.g, MISSING_RED.b, 0.9)
		elseif db.enchantNames then
			SetFont(data.enchant, size, "OUTLINE")
			if db.enchantUseColor then
				local c = db.enchantColor
				data.enchant:SetTextColor(c[1], c[2], c[3], 0.9)
			else
				data.enchant:SetTextColor(r + (1 - r) * 0.5, g + (1 - g) * 0.5, b + (1 - b) * 0.5, 0.9)
			end
		else
			SetFont(data.enchant, size, "")
			if db.enchantUseColor then
				local c = db.enchantColor
				data.enchant:SetTextColor(c[1], c[2], c[3], 0.8)
			else
				data.enchant:SetTextColor(1, 1, 1, 0.8)
			end
		end
		-- At most 45% of the gap between the equipment columns.
		local maxW
		local lr, rl = CharacterHeadSlot:GetRight(), CharacterHandsSlot:GetLeft()
		if lr and rl and rl > lr then
			maxW = (rl - lr) * 0.45
		end
		data.enchant:SetWidth(maxW or 0)
		data.enchant:SetText(text)
		data.enchant:Show()
		data.enchantHover:SetWidth(min(maxW or 100, max(20, data.enchant:GetStringWidth())))
		data.enchantHover:Show()
	else
		data.enchant:Hide()
		data.enchantHover:Hide()
	end
	SetSlotMissing(slotName, missing and db.showEnchants and true or false)

	if Themed() then
		UpdateGems(slotName, link)
	end
end

local function RefreshAllSlotLabels()
	if not S.textOverlay then
		return
	end
	for _, slotName in ipairs(GEAR_SLOTS) do
		UpdateSlotInfo(slotName)
	end
end

---------------------------------------------------------------------------
-- Gear flyout item levels and flyout arrows
---------------------------------------------------------------------------
local flyoutText = setmetatable({}, { __mode = "k" })

local flyoutStats = setmetatable({}, { __mode = "k" })

local function PaintFlyoutButton(button)
	local fs = flyoutText[button]
	-- Show Item Stats (retail flyoutItemStats): the stat letters at the bottom.
	local sfs = flyoutStats[button]
	local statLink
	if db.flyoutItemStats and button:IsShown() and button.location
		and not (EQUIPMENTFLYOUT_FIRST_SPECIAL_LOCATION and button.location >= EQUIPMENTFLYOUT_FIRST_SPECIAL_LOCATION) then
		local player, _, bags, voidStorage, slot, bag = EquipmentManager_UnpackLocation(button.location)
		if bags then
			statLink = GetContainerItemLink(bag, slot)
		elseif player and slot and not voidStorage then
			statLink = GetInventoryItemLink("player", slot)
		end
	end
	local letters = statLink and ns.ItemStatLetters(statLink)
	if letters then
		if not sfs then
			sfs = button:CreateFontString(nil, "OVERLAY")
			SetFont(sfs, 9, "OUTLINE")
			sfs:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
			sfs:SetJustifyH("CENTER")
			flyoutStats[button] = sfs
		end
		sfs:SetText(letters)
		sfs:SetTextColor(1, 1, 1, 0.9)
	elseif sfs then
		sfs:SetText("")
	end
	if not db.flyoutItemLevels or not button:IsShown() then
		if fs then
			fs:SetText("")
		end
		return
	end
	local location = button.location
	if not location or (EQUIPMENTFLYOUT_FIRST_SPECIAL_LOCATION and location >= EQUIPMENTFLYOUT_FIRST_SPECIAL_LOCATION) then
		if fs then
			fs:SetText("")
		end
		return
	end
	local player, bank, bags, voidStorage, slot, bag = EquipmentManager_UnpackLocation(location)
	local info, link
	if voidStorage then
		info = nil
	elseif bags then
		info = ScanBag(bag, slot)
		link = GetContainerItemLink(bag, slot)
	elseif player and slot then
		info = ScanInventory(slot)
		link = GetInventoryItemLink("player", slot)
	end
	if not fs then
		fs = button:CreateFontString(nil, "OVERLAY")
		SetFont(fs, 12, "OUTLINE")
		fs:SetPoint("TOP", button, "TOP", 0, -2)
		fs:SetJustifyH("CENTER")
		flyoutText[button] = fs
	end
	local ilvl = info and info.ilvl
	if not ilvl and link then
		ilvl = select(4, GetItemInfo(link))
	end
	if ilvl and ilvl > 0 then
		fs:SetText(ilvl)
		local quality = link and select(3, GetItemInfo(link))
		fs:SetTextColor(QualityColor(quality))
	else
		fs:SetText("")
	end
end

local flyoutArrowsHidden = false
local function ApplyFlyoutArrows()
	local hide = SheetOn() and db.hideSlotFlyoutArrows
	if not hide and not flyoutArrowsHidden then
		return
	end
	for _, slotName in ipairs(ALL_SLOTS) do
		local slot = _G[slotName]
		local button = slot and (slot.popoutButton or _G[slotName .. "PopoutButton"])
		if button then
			button:SetAlpha(hide and 0 or 1)
		end
	end
	flyoutArrowsHidden = hide and true or false
end

---------------------------------------------------------------------------
-- ElvUI: its "Character Frame" skin draws backdrops on the same frames.
---------------------------------------------------------------------------
local function ElvUICharacterSkinOn()
	local E = ElvUI and ElvUI[1]
	local skins = E and E.private and E.private.skins and E.private.skins.blizzard
	return skins and skins.enable and skins.character and true or false
end

-- Removes ElvUI's backdrops from the frames this sheet draws itself.
local function ClearElvUIBackdrops()
	local function Clear(f)
		if not f then
			return
		end
		if f.SetBackdrop then
			f:SetBackdrop(nil)
		end
		if f.backdrop then
			f.backdrop:Hide()
		end
		-- ElvUI StyleButton hover / pushed / checked overlays.
		for _, key in ipairs({ "hover", "pushed", "checked" }) do
			if f[key] and f[key].SetAlpha then
				f[key]:SetAlpha(0)
			end
		end
	end
	Clear(CharacterFrame)
	for _, slotName in ipairs(ALL_SLOTS) do
		Clear(_G[slotName])
	end
	for i = 1, 4 do
		Clear(_G["CharacterFrameTab" .. i])
	end
	for i = 1, 3 do
		Clear(_G["PaperDollSidebarTab" .. i])
	end
	print("|cff0cd29fEllesmereUI|r: ElvUI also skins the character frame. For the EllesmereUI sheet, turn off ElvUI > Skins > Character Frame.")
end

---------------------------------------------------------------------------
-- Reputation and Currency tabs (EllesmereUI Skin_RepCurrency, made for the
-- 5.4.8 frames: ReputationBar1-15 and the Blizzard_TokenUI rows)
---------------------------------------------------------------------------
local RC = setmetatable({}, { __mode = "k" }) -- per-frame skin state

-- House font at the text's own size, white unless a color is given.
local function HouseText(fs, r, g, b)
	if not fs or not fs.GetFont then
		return
	end
	local _, size = fs:GetFont()
	SetFont(fs, size or 12, "")
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetTextColor(r or 1, g or 1, b or 1)
end

-- Scroll bar (UIPanelScrollBar / HybridScrollBar): arrows and track gone,
-- the thumb a slim 4 px white strip.
local function SkinScrollBar(bar)
	if not bar or RC[bar] then
		return
	end
	RC[bar] = true
	local name = bar:GetName()
	for _, suffix in ipairs({ "ScrollUpButton", "ScrollDownButton" }) do
		local b = name and _G[name .. suffix]
		if b then
			for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
				local t = b[getter] and b[getter](b)
				if t then
					t:SetAlpha(0)
				end
			end
		end
	end
	local thumb = bar:GetThumbTexture()
	FadeRegions(bar, thumb and { [thumb] = true })
	if name then
		for _, suffix in ipairs({ "Track", "Top", "Bottom", "Middle", "BG" }) do
			local t = _G[name .. suffix]
			if t and t.SetAlpha then
				t:SetAlpha(0)
			end
		end
	end
	if thumb then
		thumb:SetTexture(1, 1, 1, 0.3)
		thumb:SetWidth(4)
	end
end

-- Chevron in place of Blizzard's +/- box: up = expanded, down = collapsed.
local function Chevron(parent, anchor)
	local g = parent:CreateTexture(nil, "OVERLAY")
	g:SetSize(14, 14)
	g:SetPoint("CENTER", anchor, "CENTER", 0, 0)
	g:SetTexCoord(0, ICON_COORD, 0, ICON_COORD)
	g:SetVertexColor(1, 1, 1, 0.75)
	return g
end

local function SetChevron(g, expanded, hover)
	g:SetTexture(MEDIA .. (expanded and "eui-arrow-up3" or "eui-arrow-down3"))
	g:SetVertexColor(1, 1, 1, hover and 1 or 0.75)
end

-- Checkbox (EllesmereUI SkinGuildCheck): dark 14 px box, 1 px border, green tick.
local function SkinCheck(cb)
	if not cb or RC[cb] then
		return
	end
	RC[cb] = true
	for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetCheckedTexture", "GetDisabledCheckedTexture" }) do
		local t = cb[getter] and cb[getter](cb)
		if t then
			t:SetAlpha(0)
		end
	end
	local box = CreateFrame("Frame", nil, cb)
	box:SetSize(14, 14)
	box:SetPoint("LEFT", cb, "LEFT", 4, 0)
	Solid(box, "BACKGROUND", 0.02, 0.02, 0.02, 1):SetAllPoints()
	CreateBorder(box, 1, 0.25, 0.25, 0.25, 1, "BORDER")
	local tick = Solid(box, "OVERLAY", ACCENT.r, ACCENT.g, ACCENT.b, 1)
	tick:SetPoint("TOPLEFT", 3, -3)
	tick:SetPoint("BOTTOMRIGHT", -3, 3)
	local wash = Solid(box, "ARTWORK", 1, 1, 1, 0.1)
	wash:SetAllPoints()
	wash:Hide()
	local hovering = false
	local function Update()
		local checked = cb:GetChecked() and true or false
		tick:SetShown(checked)
		wash:SetShown(hovering or checked)
		box:SetAlpha(cb:IsEnabled() and 1 or 0.4)
	end
	cb:HookScript("OnEnter", function() hovering = true Update() end)
	cb:HookScript("OnLeave", function() hovering = false Update() end)
	cb:HookScript("OnClick", Update)
	hooksecurefunc(cb, "SetChecked", Update)
	hooksecurefunc(cb, "Enable", Update)
	hooksecurefunc(cb, "Disable", Update)
	Update()
end

-- Popup: Blizzard's dialog art off, a house panel in its place.
-- withShell = the sheet backdrop (the Currency options popup, like EllesmereUI).
local function SkinPopup(pop, withShell)
	if not pop or RC[pop] then
		return
	end
	RC[pop] = true
	if pop.SetBackdrop then
		pop:SetBackdrop(nil)
	end
	FadeRegions(pop)
	if withShell and db.style ~= "modern" then
		local bg = pop:CreateTexture(nil, "BACKGROUND")
		bg:SetDrawLayer("BACKGROUND", -8)
		bg:SetTexture(MEDIA .. "sheet-bg")
		bg:SetAllPoints(pop)
		Solid(pop, "BACKGROUND", 0, 0, 0, 0.62, -7):SetAllPoints(pop)
	elseif withShell then
		local c = db.modernColor
		Solid(pop, "BACKGROUND", c[1], c[2], c[3], (db.modernAlpha or 97) / 100, -6):SetAllPoints(pop)
	else
		Solid(pop, "BACKGROUND", 0.05, 0.05, 0.05, 0.95, -6):SetAllPoints(pop)
	end
	local border = CreateFrame("Frame", nil, pop)
	border:SetAllPoints(pop)
	border:SetFrameLevel(pop:GetFrameLevel() + 6)
	CreateBorder(border, 1, 0.2, 0.2, 0.2, 1, "OVERLAY")
	local regions = { pop:GetRegions() }
	for i = 1, #regions do
		if regions[i]:IsObjectType("FontString") then
			HouseText(regions[i])
		end
	end
end

local function SkinCloseButton(btn)
	if not btn or RC[btn] then
		return
	end
	RC[btn] = true
	for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
		local t = btn[getter] and btn[getter](btn)
		if t then
			t:SetAlpha(0)
		end
	end
	local x = btn:CreateTexture(nil, "OVERLAY")
	x:SetTexture(MEDIA .. "eui-close")
	x:SetTexCoord(0, ICON_COORD, 0, ICON_COORD)
	x:SetSize(14, 14)
	x:SetPoint("CENTER", -2, 0)
	x:SetVertexColor(1, 1, 1, 0.75)
	btn:HookScript("OnEnter", function() x:SetVertexColor(1, 1, 1, 1) end)
	btn:HookScript("OnLeave", function() x:SetVertexColor(1, 1, 1, 0.75) end)
end

-- One reputation row. Blizzard repaints rows on every update (fonts, +/-
-- texture, row type), so the per-pass part runs after each update.
local function SkinReputationRow(i)
	local row = _G["ReputationBar" .. i]
	if not row then
		return
	end
	local name = row:GetName()
	local bar = _G[name .. "ReputationBar"]
	local button = _G[name .. "ExpandOrCollapseButton"]
	local d = RC[row]
	if not d then
		d = {}
		RC[row] = d
		-- Header plate and white hover (headers only, see below).
		d.plate = Solid(row, "BACKGROUND", 1, 1, 1, 0.05)
		d.plate:SetAllPoints(row)
		d.hover = Solid(row, "HIGHLIGHT", 1, 1, 1, 0.05)
		d.hover:SetAllPoints(row)
		local background = _G[name .. "Background"]
		if background then
			background:SetAlpha(0)
		end
		-- Flat bar on a dark trough with a 1 px border.
		if bar then
			for _, suffix in ipairs({ "LeftTexture", "RightTexture" }) do
				local t = _G[name .. "ReputationBar" .. suffix]
				if t then
					t:SetAlpha(0)
				end
			end
			bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
			local trough = Solid(bar, "BACKGROUND", 0.12, 0.12, 0.12, 0.85, -1)
			trough:SetAllPoints(bar)
			CreateBorder(bar, 1, 0.2, 0.2, 0.2, 1, "OVERLAY")
		end
		if button then
			local hl = button:GetHighlightTexture()
			if hl then
				hl:SetAlpha(0)
			end
			button:SetHitRectInsets(-6, -6, -6, -6)
			d.chevron = Chevron(button, button)
			button:HookScript("OnEnter", function() d.hoverChevron = true SetChevron(d.chevron, not row.isCollapsed, true) end)
			button:HookScript("OnLeave", function() d.hoverChevron = false SetChevron(d.chevron, not row.isCollapsed, false) end)
		end
	end
	local isHeader = button and button:IsShown()
	d.plate:SetShown(isHeader and true or false)
	d.hover:SetAlpha(isHeader and 1 or 0)
	if button then
		local normal = button:GetNormalTexture()
		if normal then
			normal:SetAlpha(0)
		end
		SetChevron(d.chevron, not row.isCollapsed, d.hoverChevron)
	end
	HouseText(_G[name .. "FactionName"])
	HouseText(_G[name .. "ReputationBarFactionStanding"])
end

-- Rows that fit the sheet height: Blizzard's 15 rows start at y -68, 23 px
-- apart, and end 11 px above the bottom of the 424 px sheet.
local REP_TOP, REP_STEP = 68, 23
local repRowsCreated = 15

local function RepRowCount()
	return max(1, floor((CharacterFrame:GetHeight() - REP_TOP - 11) / REP_STEP))
end

-- Extra ReputationBar rows for a taller sheet (Blizzard's update loop runs to
-- NUM_FACTIONS_DISPLAYED, so it fills them too).
local function EnsureRepRows()
	local n = RepRowCount()
	for i = repRowsCreated + 1, n do
		local row = CreateFrame("Button", "ReputationBar" .. i, ReputationFrame, "ReputationBarTemplate")
		row:SetID(i)
		repRowsCreated = i
	end
	NUM_FACTIONS_DISPLAYED = n
	return n
end

-- Every row from the left indent Blizzard gave it (header / child / faction)
-- to the right edge, so the list uses the full sheet width.
local function LayoutRepRow(i, right)
	local row = _G["ReputationBar" .. i]
	local d = RC[row]
	-- Blizzard sets the LEFT point on every update; a relayout without an
	-- update reuses the last one.
	local indent = d.indent or 34
	for p = 1, row:GetNumPoints() do
		local point, _, _, x = row:GetPoint(p)
		if point == "LEFT" then
			indent = x
		end
	end
	d.indent = indent
	local width = ReputationFrame:GetWidth() - right - indent
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", ReputationFrame, "TOPLEFT", indent, -REP_TOP - (i - 1) * REP_STEP)
	row:SetWidth(width)
	local title = _G["ReputationBar" .. i .. "FactionName"]
	if title then
		title:SetWidth(max(80, width - 140))
	end
end

local function SkinReputationRows()
	local n = NUM_FACTIONS_DISPLAYED or 15
	-- Blizzard: 50 px right margin with the scroll bar, 26 without.
	local right = (ReputationListScrollFrame and ReputationListScrollFrame:IsShown()) and 50 or 26
	for i = 1, repRowsCreated do
		SkinReputationRow(i)
		if i <= n then
			LayoutRepRow(i, right)
		else
			_G["ReputationBar" .. i]:Hide()
		end
	end
	-- "Standing" stays over the bars (101 px wide, at the right edge).
	if ReputationFrameStandingLabel then
		ReputationFrameStandingLabel:ClearAllPoints()
		ReputationFrameStandingLabel:SetPoint("TOP", ReputationFrame, "TOPRIGHT", -(right + 50), -42)
	end
end

local function SkinReputation()
	if not ReputationFrame or RC[ReputationFrame] then
		return
	end
	RC[ReputationFrame] = true
	HouseText(ReputationFrameFactionLabel)
	HouseText(ReputationFrameStandingLabel)
	if ReputationListScrollFrame then
		FadeRegions(ReputationListScrollFrame)
		SkinScrollBar(ReputationListScrollFrameScrollBar)
	end
	SkinReputationRows()
	hooksecurefunc("ReputationFrame_Update", SkinReputationRows)

	local detail = ReputationDetailFrame
	if detail then
		SkinPopup(detail)
		SkinCloseButton(ReputationDetailCloseButton)
		for _, cbName in ipairs({ "ReputationDetailAtWarCheckBox", "ReputationDetailInactiveCheckBox",
			"ReputationDetailMainScreenCheckBox", "ReputationDetailLFGBonusReputationCheckBox" }) do
			SkinCheck(_G[cbName])
		end
		HouseText(ReputationDetailFactionDescription)
	end
end

-- One currency row (TokenFrameContainer.buttons), per pass like reputation.
local function SkinCurrencyRow(button)
	local d = RC[button]
	if not d then
		d = {}
		RC[button] = d
		for _, key in ipairs({ "categoryLeft", "categoryRight", "categoryMiddle" }) do
			if button[key] then
				button[key]:SetAlpha(0)
			end
		end
		d.plate = Solid(button, "BACKGROUND", 1, 1, 1, 0.05)
		d.plate:SetAllPoints(button)
		if button.expandIcon then
			button.expandIcon:SetAlpha(0)
			d.chevron = Chevron(button, button.expandIcon)
		end
		if button.icon then
			button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end
		button:HookScript("OnEnter", function()
			if button.isHeader and d.chevron then
				SetChevron(d.chevron, button.isExpanded, true)
			end
		end)
		button:HookScript("OnLeave", function()
			if button.isHeader and d.chevron then
				SetChevron(d.chevron, button.isExpanded, false)
			end
		end)
	end
	-- Blizzard sets a new highlight texture file on every update.
	if button.highlight then
		button.highlight:SetTexture(1, 1, 1, 0.05)
	end
	d.plate:SetShown(button.isHeader and true or false)
	if d.chevron then
		d.chevron:SetShown(button.isHeader and true or false)
		SetChevron(d.chevron, button.isExpanded, false)
	end
	-- White text; a currency you have 0 of stays gray, like Blizzard's.
	local gray = not button.isHeader and button.count and button.count:GetText() == "0"
	local c = gray and 0.5 or 1
	HouseText(button.name, c, c, c)
	HouseText(button.count, c, c, c)
end

local addingTokenRows = false

local function SkinCurrencyRows()
	local container = TokenFrameContainer
	if not container or not container.buttons then
		return
	end
	-- Blizzard makes rows for a 360 px list once; a taller sheet needs more.
	local buttons = container.buttons
	local rowH = buttons[1]:GetHeight()
	local needed = math.ceil(container:GetHeight() / rowH) + 1
	if needed > #buttons and not addingTokenRows then
		addingTokenRows = true
		local before = #buttons
		HybridScrollFrame_CreateButtons(container, "TokenButtonTemplate", 1, -2, "TOPLEFT", "TOPLEFT", 0, -(TOKEN_BUTTON_OFFSET or 3))
		buttons = container.buttons
		-- Blizzard's stripe pattern: every second row.
		for i = before + 1, #buttons do
			if i % 2 == 1 and buttons[i].stripe then
				buttons[i].stripe:Hide()
			end
		end
		TokenFrame_Update()
		addingTokenRows = false
		return
	end
	-- Rows as wide as the list (Blizzard: 295 / 317 for the 338 px sheet).
	local width = container:GetWidth() - 4
	if width > 0 then
		container.scrollChild:SetWidth(width + 4)
	end
	for _, button in ipairs(buttons) do
		if width > 0 then
			button:SetWidth(width)
		end
		SkinCurrencyRow(button)
	end
end

local function SkinCurrency()
	if not TokenFrame or RC[TokenFrame] then
		return
	end
	RC[TokenFrame] = true
	if TokenFrameContainerScrollBar then
		SkinScrollBar(TokenFrameContainerScrollBar)
		TokenFrameContainerScrollBar:HookScript("OnValueChanged", SkinCurrencyRows)
	end
	hooksecurefunc("TokenFrame_Update", SkinCurrencyRows)
	SkinCurrencyRows()
	-- Faint list background, like the Reputation tab.
	if TokenFrameContainer then
		local tex = Solid(TokenFrame, "BACKGROUND", 0, 0, 0, 0.1, -7)
		tex:SetPoint("TOPLEFT", TokenFrameContainer, "TOPLEFT", 10, -10)
		tex:SetPoint("BOTTOMRIGHT", TokenFrameContainer, "BOTTOMRIGHT", -10, 0)
	end
	local pop = TokenFramePopup
	if pop then
		SkinPopup(pop, true)
		SkinCloseButton(TokenFramePopupCloseButton)
		SkinCheck(TokenFramePopupInactiveCheckBox)
		SkinCheck(TokenFramePopupBackpackCheckBox)
	end
end

-- Size change: more or fewer reputation rows, currency rows refilled.
RelayoutLists = function()
	if RC[ReputationFrame] then
		EnsureRepRows()
		if ReputationFrame:IsShown() then
			ReputationFrame_Update()
		else
			SkinReputationRows()
		end
	end
	if TokenFrame and RC[TokenFrame] and TokenFrame:IsShown() then
		TokenFrame_Update()
	end
end

local function SkinRepCurrency()
	-- The list area (CharacterFrameInset) spans the whole sheet, not
	-- Blizzard's 338 px column. The paper doll slots no longer use it.
	if CharacterFrameInset then
		CharacterFrameInset:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT", PANEL_INSET_RIGHT_OFFSET or -2, PANEL_INSET_BOTTOM_OFFSET or 4)
	end
	hooksecurefunc("CharacterFrame_Collapse", ApplySheetSize)
	SkinReputation()
	EnsureRepRows()
	-- Currency is the load-on-demand Blizzard_TokenUI.
	if IsAddOnLoaded("Blizzard_TokenUI") then
		SkinCurrency()
	else
		local wait = CreateFrame("Frame")
		wait:RegisterEvent("ADDON_LOADED")
		wait:SetScript("OnEvent", function(self, _, name)
			if name == "Blizzard_TokenUI" then
				self:UnregisterAllEvents()
				SkinCurrency()
			end
		end)
	end
end

-- ElvUI "Display Character Info" (General > Item Level) writes its own item
-- level, enchant and gem icons beside the character slots, on top of ours.
-- Alpha only: ElvUI keeps calling SetText / Show on them, which keeps alpha.
-- The inspect window is not touched.
local function HideElvUICharacterInfo()
	if not ElvUI then
		return
	end
	for _, slotName in ipairs(ALL_SLOTS) do
		local slot = _G[slotName]
		if slot then
			if slot.iLvlText then
				slot.iLvlText:SetAlpha(0)
			end
			if slot.enchantText then
				slot.enchantText:SetAlpha(0)
			end
			for u = 1, 10 do
				local backdrop = slot["textureSlotBackdrop" .. u]
				if backdrop then
					backdrop:SetAlpha(0)
				end
				local texture = slot["textureSlot" .. u]
				if texture then
					texture:SetAlpha(0)
				end
			end
		end
	end
	if CharacterFrame.ItemLevelText then
		CharacterFrame.ItemLevelText:SetAlpha(0)
	end
end

---------------------------------------------------------------------------
-- Build and events
---------------------------------------------------------------------------
local built = false
local queueStats

local function OnSheetShow()
	-- Every open: ElvUI can create its slot strings after our first build.
	HideElvUICharacterInfo()
	betterDirty = true
	UpdateItemLevelDisplay()
	RefreshStatsVisibility()
	RefreshAllSlotLabels()
	UpdateSlotBorders()
	UpdateDurability()
	ApplyFlyoutArrows()
	-- Sections settle after the first frame.
	After(0, function()
		if CharacterFrame:IsShown() then
			RefreshStatsVisibility()
		end
	end)
end

local function BuildSheet()
	if built or not SheetOn() then
		return
	end
	built = true
	if Themed() and ElvUICharacterSkinOn() then
		ClearElvUIBackdrops()
	end
	if Themed() then
		SkinChrome()
		SkinSlots()
		BuildModel()
		SkinTabs()
	end
	BuildStatsPanel()
	if Themed() then
		BuildSidebar()
		-- After the expand hook in SkinChrome: the sheet gets its saved size.
		PaperDollFrame:HookScript("OnShow", ApplySheetSize)
		SkinRepCurrency()
	end
	BuildSlotLabels()

	-- Stats: one repaint per frame while the sheet is open.
	local pending, specPending = false, false
	queueStats = function(spec)
		if spec then
			specPending = true
		end
		if pending then
			return
		end
		pending = true
		After(0, function()
			pending = false
			local doSpec = specPending
			specPending = false
			if not CharacterFrame:IsShown() then
				return
			end
			if doSpec then
				RefreshStatsVisibility()
			else
				UpdateAllStats()
			end
		end)
	end
	local statsEvents = CreateFrame("Frame")
	local STAT_EVENTS = {
		"UNIT_STATS", "COMBAT_RATING_UPDATE", "PLAYER_EQUIPMENT_CHANGED", "UNIT_ATTACK_POWER",
		"UNIT_RANGED_ATTACK_POWER", "UNIT_SPELL_HASTE", "UNIT_MAXPOWER", "UNIT_MAXHEALTH",
		"MASTERY_UPDATE", "SPELL_POWER_CHANGED", "PLAYER_DAMAGE_DONE_MODS", "UNIT_ATTACK_SPEED",
		"UNIT_DAMAGE", "UNIT_RANGEDDAMAGE", "UNIT_RESISTANCES", "UNIT_AURA", "CURRENCY_DISPLAY_UPDATE",
		"HONOR_CURRENCY_UPDATE", "PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED",
		"PLAYER_TALENT_UPDATE",
	}
	local SPEC_EVENTS = { PLAYER_SPECIALIZATION_CHANGED = true, ACTIVE_TALENT_GROUP_CHANGED = true, PLAYER_TALENT_UPDATE = true }
	statsEvents:SetScript("OnEvent", function(_, event, unit)
		if type(unit) == "string" and unit ~= "player" and not SPEC_EVENTS[event] then
			return
		end
		queueStats(SPEC_EVENTS[event])
	end)

	-- Item level, slot text, borders and gems: trailing debounce on item events.
	local itemEvents = CreateFrame("Frame")
	local refreshItems = Debounced(0.12, function()
		if not CharacterFrame:IsShown() then
			return
		end
		betterDirty = true
		UpdateItemLevelDisplay()
		RefreshAllSlotLabels()
		UpdateSlotBorders()
		UpdateDurability()
	end)
	local ITEM_EVENTS = {
		"PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED", "BAG_UPDATE", "GET_ITEM_INFO_RECEIVED",
		"PLAYER_AVG_ITEM_LEVEL_READY", "SOCKET_INFO_UPDATE", "ITEM_UPGRADE_MASTER_UPDATE",
		"UPDATE_INVENTORY_DURABILITY", "UPDATE_INVENTORY_ALERTS",
	}
	itemEvents:SetScript("OnEvent", function(_, event, unit)
		if event == "UNIT_INVENTORY_CHANGED" and unit ~= "player" then
			return
		end
		refreshItems()
	end)

	-- Events only while the sheet is open (stats fire many times a second in combat).
	CharacterFrame:HookScript("OnShow", function()
		RegisterEvents(statsEvents, STAT_EVENTS)
		RegisterEvents(itemEvents, ITEM_EVENTS)
	end)
	CharacterFrame:HookScript("OnHide", function()
		statsEvents:UnregisterAllEvents()
		itemEvents:UnregisterAllEvents()
		StopStatHighlights()
	end)
	PaperDollFrame:HookScript("OnShow", OnSheetShow)
	if CharacterFrame:IsShown() then
		RegisterEvents(statsEvents, STAT_EVENTS)
		RegisterEvents(itemEvents, ITEM_EVENTS)
		OnSheetShow()
	end
end

-- Live settings: everything the options page changes without a reload.
local function Apply()
	ApplyFlyoutArrows()
	if not built then
		return
	end
	ApplyBackdropStyle()
	ApplySheetSize()
	ApplyIconZoom()
	UpdateSectionVisibility()
	RefreshSectionColors()
	RefreshStatsVisibility()
	UpdateScrollHeaderOffset()
	UpdateDurability()
	RefreshAllSlotLabels()
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------
StaticPopupDialogs["EUI_CHARSHEET_RELOAD"] = {
	text = "Character Sheet theme setting requires a UI reload to fully apply.",
	button1 = "Reload Now",
	button2 = "Later",
	OnAccept = function() ReloadUI() end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}

local init = CreateFrame("Frame")
init:RegisterEvent("ADDON_LOADED")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == addonName then
		-- Before 3.1 the settings were EllesmereUIDB.charSheet.
		db = ns.ModuleDB("EllesmereUIBlizzardSkinDB", "charSheet", "charSheet")
		CopyDefaults(Defaults(), db)
	elseif event == "PLAYER_LOGIN" then
		self:UnregisterAllEvents()
		activeStyle = db.style
		if not CharacterFrame or not SheetOn() then
			return
		end
		-- Equipment flyout item levels work with every style.
		hooksecurefunc("EquipmentFlyout_DisplayButton", PaintFlyoutButton)
		ApplyFlyoutArrows()
		-- The heavy build runs on the first open.
		CharacterFrame:HookScript("OnShow", BuildSheet)
	end
end)

ns.applyHooks = ns.applyHooks or {}
tinsert(ns.applyHooks, Apply)

---------------------------------------------------------------------------
-- API for the settings window
---------------------------------------------------------------------------
ns.CHARSHEET_STYLES = {
	{ key = "eui", text = "EllesmereUI" },
	{ key = "modern", text = "Modern" },
	{ key = "blizzard", text = "Blizz Default" },
	{ key = "off", text = "Off" },
}
ns.CHARSHEET_ENCHANT_MODES = {
	{ key = "none", text = "None" },
	{ key = "icons", text = "Text" },
	{ key = "text", text = "Colored Text" },
}
ns.CHARSHEET_DURABILITY_LOCATIONS = {
	{ key = "model", text = "Above Model" },
	{ key = "header", text = "Stats Header" },
	{ key = "footer", text = "Frame Footer" },
}
ns.CHARSHEET_SECONDARY_TEXT = {
	{ key = "pct", text = "Percent" },
	{ key = "value", text = "Value" },
	{ key = "both", text = "Value (Percent)" },
}
ns.CHARSHEET_SECTIONS = {
	{ key = "Attributes", text = "Attributes" },
	{ key = "Secondary", text = "Secondary Stats" },
	{ key = "Attack", text = "Attack" },
	{ key = "Defense", text = "Defense" },
	{ key = "Currencies", text = "Currencies" },
	{ key = "PvP", text = "PvP" },
}

ns.GetCharSheetDB = function() return db end
ns.CharSheetStyleActive = function() return activeStyle or db.style end

-- EllesmereUI <-> Modern swap live; anything else needs a reload.
ns.SetCharSheetStyle = function(style)
	db.style = style
	local live = (style == "eui" or style == "modern") and Themed()
	if style == activeStyle or live then
		ApplyBackdropStyle()
	else
		StaticPopup_Show("EUI_CHARSHEET_RELOAD")
	end
end

ns.ResetCharSheetColors = function()
	for key, c in pairs(DEFAULT_COLORS) do
		local t = db.colors[key]
		if t then
			t[1], t[2], t[3] = c[1], c[2], c[3]
		else
			db.colors[key] = { c[1], c[2], c[3] }
		end
	end
end

ns.ResetCharSheetSettings = function()
	local style = db.style
	wipe(db)
	CopyDefaults(Defaults(), db)
	db.style = style
	if built then
		-- Default order back.
		local byKey = {}
		for _, sec in ipairs(S.sections) do
			byKey[sec.key] = sec
		end
		wipe(S.sections)
		for _, key in ipairs(SECTION_KEYS) do
			if byKey[key] then
				byKey[key].collapsed = false
				S.sections[#S.sections + 1] = byKey[key]
			end
		end
	end
end
