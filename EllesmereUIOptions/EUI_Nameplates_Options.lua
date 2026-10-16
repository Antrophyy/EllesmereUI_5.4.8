-- Settings pages of Core Addons > Nameplates (EllesmereUI
-- EUI_Nameplates_Options.lua and Nameplates_Options\*: the same pages,
-- sections, labels, tooltips, value lists and keys). Pages: Display (with a
-- simple nameplate preview), Colors, General.
-- Rows that need a retail-only feature are left out: Blizzard / Classic /
-- Forever styles, border textures, Wrap Around Castbar, Icon Borders, Class
-- Resource, faction badge, Debuff Based Coloring, Important Cast color and
-- glow, Casts In Front of Nameplates, Focus Text Reminders, Cast Lockout as
-- CC, Tracked Auras popups, Line of Sight, Range Check, Distance Text,
-- stacked spacing, NPC titles, subtitle text, Focus Cast
-- Height, Hide Enemy Nameplates out of Combat, Blood DK / Sunder rows, text
-- strata / width of non-name texts, and the preview eye buttons.
-- Added (not on retail): the "Load Naowh Profile" button on the General page.
-- Part of EllesmereUIOptions (load on demand); skipped when
-- EllesmereUINameplates is not loaded.

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUINameplates") then
	return
end
local ENP = ns.ENP
if not ENP or not ENP.db then
	return
end

local floor, max, min = math.floor, math.max, math.min
local defaults = ENP.defaults
local BAR_W = 150
local WHITE = "Interface\\Buttons\\WHITE8X8"
local MEDIA = "Interface\\AddOns\\EllesmereUINameplates\\media\\"

---------------------------------------------------------------------------
-- Profile access
---------------------------------------------------------------------------
local function DB()
	return ENP.db.profile
end

local function Val(key)
	local v = DB()[key]
	if v == nil then
		v = defaults[key]
	end
	return v
end

local function Get(key, default)
	return function()
		local v = Val(key)
		if v == nil then
			return default
		end
		return v
	end
end

local function Set(key)
	return function(v) DB()[key] = v end
end

local function On(key, default)
	return function()
		local v = Val(key)
		if v == nil then
			return default and true or false
		end
		return v == true
	end
end

local function Off(key, default)
	local on = On(key, default)
	return function() return not on() end
end

-- Percent slider over a 0..1 key.
local function GetPct(key, default, fallbackKey)
	return function()
		local v = Val(key)
		if v == nil and fallbackKey then
			v = Val(fallbackKey)
		end
		if v == nil then
			v = default
		end
		return floor((v or 0) * 100 + 0.5)
	end
end
local function SetPct(key)
	return function(v) DB()[key] = v / 100 end
end

-- Color getter / setter on { r, g, b [, a] } keys; fallbackKey is read while
-- the key is unset (e.g. Mini Enemies shows Enemies).
local function CGet(key, fallbackKey)
	return function()
		local c = DB()[key] or defaults[key]
		if not c and fallbackKey then
			c = DB()[fallbackKey] or defaults[fallbackKey]
		end
		if type(c) ~= "table" then
			return 1, 1, 1, 1
		end
		return c.r or 1, c.g or 1, c.b or 1, c.a or 1
	end
end
local function CSet(key, alpha)
	return function(r, g, b, a)
		local t = { r = r, g = g, b = b }
		if alpha then
			t.a = a or 1
		end
		DB()[key] = t
	end
end

local function Items(list)
	local out = {}
	for i = 1, #list do
		if list[i] == "---" then
			out[i] = { separator = true, name = "" }
		else
			out[i] = { value = list[i][1], name = list[i][2] }
		end
	end
	return out
end

local function LabelOf(list, value)
	for i = 1, #list do
		if list[i] ~= "---" and list[i][1] == value then
			return list[i][2]
		end
	end
	return tostring(value or "")
end

local function ItemLabel(items, value)
	for i = 1, #items do
		if items[i].value == value then
			return items[i].name
		end
	end
	return "None"
end

-- Dropdown over one key with a fixed { value, name } list.
local function Drop(p, label, tip, list, key, default, isDisabled, onSet)
	p:Dropdown(label, tip,
		function() return Items(list) end,
		function() local v = Val(key); if v == nil then v = default end; return v end,
		function() local v = Val(key); if v == nil then v = default end; return LabelOf(list, v) end,
		function(v)
			DB()[key] = v
			if onSet then onSet(v) end
		end,
		nil, isDisabled)
end

local function Swatch(p, tip, key, opts)
	opts = opts or {}
	return p:Swatch(tip, CGet(key, opts.fallback), CSet(key, opts.alpha), opts)
end

local function RunApplyHooks()
	for _, fn in ipairs(ns.applyHooks or {}) do
		pcall(fn)
	end
end

-- Structural changes rebuild the page (every tab has pageKey = rev).
local rev = 0
local function PageKey()
	return rev
end
local function Rebuild()
	rev = rev + 1
	if ns.RebuildSettingsPage then
		ns.RebuildSettingsPage()
	end
end

local function PlayerClassColor()
	local _, cls = UnitClass("player")
	local c = cls and RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
	if c then
		return c.r, c.g, c.b, 1
	end
	return 1, 1, 1, 1
end

local function ElvUINote(p)
	if ENP.active then
		return
	end
	p:Label("ElvUI nameplates are on, so these nameplates are off",
		"The ElvUI nameplates are enabled on this character. The EllesmereUI nameplates stay off while they are on. Turn off the ElvUI nameplates and reload to use these settings.")
	p:Blank()
end

---------------------------------------------------------------------------
-- Textures (bar texture list, stripe overlays)
---------------------------------------------------------------------------
local function LSM()
	return (ns.GetLSM and ns.GetLSM()) or (LibStub and LibStub("LibSharedMedia-3.0", true))
end

local STRIPES = {
	{ "striped-v2", "Stripes" }, { "striped-wide-v2", "Wide Stripes" }, { "stripes-medium", "Medium Stripes" },
	{ "stripes-small-close", "Small Dense Stripes" }, { "stripes-small-spread", "Small Spread Stripes" },
	{ "striped-tiny", "Tiny Stripes" },
}
local STRIPE_KEYS = {}
for _, s in ipairs(STRIPES) do
	STRIPE_KEYS[s[1]] = true
end

local function TexPath(key)
	if not key or key == "none" or key == "" then
		return nil
	end
	if STRIPE_KEYS[key] then
		return MEDIA .. key
	end
	if key:sub(1, 3) == "sm:" then
		local lsm = LSM()
		return (lsm and lsm:Fetch("statusbar", key:sub(4), true)) or WHITE
	end
	if ENP.BAR_TEXTURE_NAMES and ENP.BAR_TEXTURE_NAMES[key] then
		return MEDIA .. "textures\\" .. key
	end
	return WHITE
end

local function BarTextureItems()
	return ENP.TextureItems()
end

-- Target / Focus Texture: the stripes, ---, then the bar textures (None first).
local function OverlayItems()
	local out = {}
	for _, s in ipairs(STRIPES) do
		out[#out + 1] = { value = s[1], name = s[2] }
	end
	out[#out + 1] = { separator = true, name = "" }
	for _, it in ipairs(ENP.TextureItems()) do
		out[#out + 1] = it
	end
	return out
end

-- Hover Texture: None, ---, the stripes, ---, the bar textures.
local function HoverItems()
	local out = { { value = "none", name = "None" }, { separator = true, name = "" } }
	for _, s in ipairs(STRIPES) do
		out[#out + 1] = { value = s[1], name = s[2] }
	end
	out[#out + 1] = { separator = true, name = "" }
	for _, it in ipairs(ENP.TextureItems()) do
		if it.value ~= "none" then
			out[#out + 1] = it
		end
	end
	return out
end

local TEX_OPTS = { texturePreview = true, previewPath = TexPath }

local function TexDrop(p, label, tip, key, getItems, isDisabled)
	p:Dropdown(label, tip, getItems,
		function() return Val(key) or "none" end,
		function() return ItemLabel(getItems(), Val(key) or "none") end,
		function(v) DB()[key] = v end,
		TEX_OPTS, isDisabled)
end

---------------------------------------------------------------------------
-- Value lists (retail labels)
---------------------------------------------------------------------------
local ABSORB_STYLES = {
	{ "blizzard", "Blizzard" }, { "striped", "Striped" }, { "clean", "Clean (Flat)" },
	{ "pixelsShield", "Pixels Shield" }, { "pixelsShieldEdge", "Pixels Shield Edge" }, { "pixelsShieldFill", "Pixels Shield Fill" },
}
local ABSORB_PLACEMENT = {
	{ "overlay", "Overlay" }, { "overlayReverse", "Overlay Reverse" }, { "right", "From Right Edge" }, { "left", "From Left Edge" },
}
local TIMER_POS = {
	{ "none", "None" }, { "topleft", "Top Left" }, { "topright", "Top Right" },
	{ "bottomleft", "Bottom Left" }, { "bottomright", "Bottom Right" }, { "center", "Center" },
}
local CAST_SIDES = { { "none", "None" }, { "left", "Left" }, { "right", "Right" }, { "center", "Center" } }
local ANCHORS = {
	{ "CENTER", "Center" }, { "LEFT", "Left" }, { "RIGHT", "Right" }, { "TOP", "Top" }, { "BOTTOM", "Bottom" },
	{ "TOPLEFT", "Top Left" }, { "TOPRIGHT", "Top Right" }, { "BOTTOMLEFT", "Bottom Left" }, { "BOTTOMRIGHT", "Bottom Right" },
}

-- Core text slots and elements.
local TEXT_SLOTS = {
	{ key = "textSlotTop", label = "Top Text", menu = "Top", point = "BOTTOM", rel = "TOP", x = 0, y = 4 },
	{ key = "textSlotRight", label = "Right Text", menu = "Right", point = "RIGHT", rel = "RIGHT", x = -2, y = 0 },
	{ key = "textSlotLeft", label = "Left Text", menu = "Left", point = "LEFT", rel = "LEFT", x = 4, y = 0 },
	{ key = "textSlotCenter", label = "Center Text", menu = "Center", point = "CENTER", rel = "CENTER", x = 0, y = 0 },
	{ key = "textSlotBottomLeft", label = "Bottom Left Text", menu = "Bottom Left", point = "TOPLEFT", rel = "BOTTOMLEFT", x = 0, y = -2, bottom = true },
	{ key = "textSlotBottomRight", label = "Bottom Right Text", menu = "Bottom Right", point = "TOPRIGHT", rel = "BOTTOMRIGHT", x = 0, y = -2, bottom = true },
}
local ELEMENTS = {
	{ "enemyName", "Enemy Name" }, { "levelName", "Level | Name" }, { "nameLevel", "Name | Level" }, { "level", "Level" },
	{ "targetOfTarget", "Target of Target" }, { "healthPercent", "Health %" }, { "healthPercentNoSign", "Health % (No Sign)" },
	{ "healthNumber", "Health #" }, { "healthPctNum", "Health % | #" }, { "healthNumPct", "Health # | %" },
	{ "healthPctNumDash", "Health % - #" }, { "healthNumPctDash", "Health # - %" },
}
local KNOWN_ELEMENT = {}
for _, e in ipairs(ELEMENTS) do
	KNOWN_ELEMENT[e[1]] = e[2]
end
local NAME_FAMILY = { enemyName = true, levelName = true, nameLevel = true }
local HEALTH_ELEMENTS = {
	healthPercent = true, healthPercentNoSign = true, healthNumber = true,
	healthPctNum = true, healthNumPct = true, healthPctNumDash = true, healthNumPctDash = true,
}
local COMBINED_HEALTH = { healthPctNum = true, healthNumPct = true, healthPctNumDash = true, healthNumPctDash = true }

local function SlotElement(slotKey)
	local v = Val(slotKey)
	if v == nil or not KNOWN_ELEMENT[v] then
		return "none"
	end
	return v
end

-- Core Text Coloring mode (retail ns.NP_SlotColorMode, as the engine reads it).
local function SlotColorMode(slotKey)
	local p = DB()
	local el = SlotElement(slotKey)
	local m = p[slotKey .. "ColorMode"]
	if m == "class" or m == "custom" then return m end
	if m == "level" then return (el ~= "targetOfTarget") and "level" or "custom" end
	if el == "level" and p.levelDifficultyColor == true then return "level" end
	if p[slotKey .. "ClassColor"] == true then return "class" end
	if p.enemyNameTextReactionColor == true and NAME_FAMILY[el] then
		for _, s in ipairs(TEXT_SLOTS) do
			if NAME_FAMILY[SlotElement(s.key)] then
				if s.key == slotKey then return "class" end
				break
			end
		end
	end
	return "custom"
end

-- Core Positions slots and elements.
local POSITIONS = {
	{ key = "top", label = "Top" }, { key = "right", label = "Right" },
	{ key = "left", label = "Left" }, { key = "topright", label = "Top Right" },
	{ key = "topleft", label = "Top Left" }, { key = "bottom", label = "Bottom" },
}
local POS_ELEMENTS = {
	{ id = "debuffs", name = "Debuffs", key = "debuffSlot", group = "debuffs", kind = "debuff", kindKey = "Debuff" },
	{ id = "buffs", name = "Buffs", key = "buffSlot", group = "buffs", kind = "buff", kindKey = "Buff" },
	{ id = "ccs", name = "Crowd Control", key = "ccSlot", group = "ccs", kind = "cc", kindKey = "CC" },
	{ id = "raidmarker", name = "Raid Marker", key = "raidMarkerPos", group = "raidmarker" },
	{ id = "rare", name = "Rare Indicator", key = "classificationSlot", hide = "classificationHideRare", other = "classificationHideQuest", group = "class",
	  tip = "Elite and rare marks. Always in the same slot as the Quest Indicator." },
	{ id = "quest", name = "Quest Indicator", key = "classificationSlot", hide = "classificationHideQuest", other = "classificationHideRare", group = "class",
	  tip = "Marks mobs for your active quests. Always in the same slot as the Rare Indicator." },
}
local GROWS = {
	topleft = { { "left", "Left" }, { "right", "Right" }, { "up", "Up" } },
	topright = { { "right", "Right" }, { "left", "Left" }, { "up", "Up" } },
}

local function ElementIn(e, slot)
	if Val(e.key) ~= slot then
		return false
	end
	if e.hide and Val(e.hide) == true then
		return false
	end
	return true
end

local function SlotGroups(slot)
	local groups = {}
	for _, e in ipairs(POS_ELEMENTS) do
		if ElementIn(e, slot) then
			groups[e.group] = true
		end
	end
	return groups
end

local function SlotEmpty(slot)
	return next(SlotGroups(slot)) == nil
end

---------------------------------------------------------------------------
-- Target / hover effect switches (as the engine reads them)
---------------------------------------------------------------------------
local function TGEui()
	local p = DB()
	if p.targetGlowEllesmereUI ~= nil then return p.targetGlowEllesmereUI == true end
	local style = p.targetGlowStyle or defaults.targetGlowStyle
	return style == "ellesmereui" or style == "vibrant"
end
local function TGBorderColor()
	local p = DB()
	if p.targetGlowBorderColor ~= nil then return p.targetGlowBorderColor == true end
	return (p.targetGlowStyle or defaults.targetGlowStyle) == "vibrant"
end
local function TGHighlight() return DB().targetGlowHighlight == true end
local function TGBorderSize() return DB().targetGlowBorderSize == true end
local function HVEui() return DB().hoverGlowEllesmereUI == true end
local function HVBorderColor() return DB().hoverGlowBorderColor == true end
local function HVBorderSize() return DB().hoverGlowBorderSize == true end
local function HVHighlight()
	local v = DB().hoverGlowHighlight
	if v ~= nil then return v == true end
	return true
end

local function BorderMode()
	local p = DB()
	if p.customBorderEnabled then return "custom" end
	if p.showBorder ~= false then return "basic" end
	return "none"
end

local function CurrentBorderSize()
	local p = DB()
	if p.customBorderEnabled then return p.customBorderSize or 1 end
	if p.showBorder ~= false then return p.borderSize or 1 end
	return 0
end

---------------------------------------------------------------------------
-- Display page header: a simple mock enemy plate
---------------------------------------------------------------------------
local PREVIEW_H = 160
local SAMPLE = {
	name = "Kobold Geomancer", level = "62", tot = "Tanky",
	pct = "68", pctDec = "68.4", num = "68.4K",
}
local PREVIEW_ICONS = {
	"Interface\\Icons\\Spell_Shadow_ShadowWordPain", "Interface\\Icons\\Ability_Gouge",
	"Interface\\Icons\\Spell_Nature_Slow",
}

local function SampleText(el, slotKey)
	local dec = DB()[slotKey .. "PctDecimal"] == true
	local pct = dec and SAMPLE.pctDec or SAMPLE.pct
	if el == "enemyName" then return SAMPLE.name end
	if el == "levelName" then return SAMPLE.level .. " | " .. SAMPLE.name end
	if el == "nameLevel" then return SAMPLE.name .. " | " .. SAMPLE.level end
	if el == "level" then return SAMPLE.level end
	if el == "targetOfTarget" then return SAMPLE.tot end
	if el == "healthPercent" then return pct .. "%" end
	if el == "healthPercentNoSign" then return pct end
	if el == "healthNumber" then return SAMPLE.num end
	if el == "healthPctNum" then return pct .. "% | " .. SAMPLE.num end
	if el == "healthNumPct" then return SAMPLE.num .. " | " .. pct .. "%" end
	if el == "healthPctNumDash" then return pct .. "% - " .. SAMPLE.num end
	if el == "healthNumPctDash" then return SAMPLE.num .. " - " .. pct .. "%" end
	return ""
end

local function PreviewFont()
	return (ns.GetFontPath and ns.GetFontPath("nameplates")) or ns.FONT or "Fonts\\FRIZQT__.TTF"
end

local function NewEdges(parent, layer)
	local e = {}
	for i = 1, 4 do
		e[i] = parent:CreateTexture(nil, layer or "OVERLAY", nil, 7)
	end
	return e
end

-- Edges inside the host, size in physical pixels.
local function LayoutEdges(e, host, sizePx, r, g, b, a)
	local px = 768 / ((ns.PhysicalHeight and ns.PhysicalHeight()) or 1080) / max(0.01, host:GetEffectiveScale())
	local s = (sizePx or 0) * px
	for i = 1, 4 do
		e[i]:ClearAllPoints()
		e[i]:SetTexture(r or 0, g or 0, b or 0, a or 1)
		if s > 0 then e[i]:Show() else e[i]:Hide() end
	end
	if s <= 0 then
		return
	end
	e[1]:SetPoint("TOPLEFT", host, "TOPLEFT")
	e[1]:SetPoint("TOPRIGHT", host, "TOPRIGHT")
	e[1]:SetHeight(s)
	e[2]:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT")
	e[2]:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT")
	e[2]:SetHeight(s)
	e[3]:SetPoint("TOPLEFT", host, "TOPLEFT")
	e[3]:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT")
	e[3]:SetWidth(s)
	e[4]:SetPoint("TOPRIGHT", host, "TOPRIGHT")
	e[4]:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT")
	e[4]:SetWidth(s)
end

local function BuildPreviewHeader(page, host, width)
	local container = CreateFrame("Frame", nil, host)
	container:SetSize(width, PREVIEW_H)
	container:SetPoint("TOP", host, "TOP", 0, 0)

	local scaleHost = CreateFrame("Frame", nil, container)
	scaleHost:SetSize(10, 10)
	scaleHost:SetPoint("CENTER")

	-- Health bar.
	local health = CreateFrame("Frame", nil, scaleHost)
	health:SetPoint("CENTER", scaleHost, "CENTER", 0, 0)
	health:SetSize(BAR_W, 17)
	local glow = health:CreateTexture(nil, "BACKGROUND")
	glow:SetPoint("TOPLEFT", health, "TOPLEFT", -6, 6)
	glow:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", 6, -6)
	local bg = health:CreateTexture(nil, "BORDER")
	bg:SetAllPoints()
	local fill = health:CreateTexture(nil, "ARTWORK")
	fill:SetPoint("TOPLEFT")
	fill:SetPoint("BOTTOMLEFT")
	local highlight = health:CreateTexture(nil, "ARTWORK", nil, 2)
	highlight:SetAllPoints()
	local absorb = health:CreateTexture(nil, "ARTWORK", nil, 3)
	local hash = health:CreateTexture(nil, "OVERLAY", nil, 2)
	local border = NewEdges(health)

	-- Texts.
	local texts = {}
	for _, s in ipairs(TEXT_SLOTS) do
		local fs = health:CreateFontString(nil, "OVERLAY")
		fs:SetFont(PreviewFont(), 10, "OUTLINE")
		fs:SetWordWrap(false)
		texts[s.key] = fs
	end

	-- Cast bar.
	local cast = CreateFrame("Frame", nil, scaleHost)
	local castBg = cast:CreateTexture(nil, "BORDER")
	castBg:SetAllPoints()
	local castFill = cast:CreateTexture(nil, "ARTWORK")
	castFill:SetPoint("TOPLEFT")
	castFill:SetPoint("BOTTOMLEFT")
	local castSpark = cast:CreateTexture(nil, "OVERLAY")
	castSpark:SetTexture(MEDIA .. "cast_spark")
	castSpark:SetBlendMode("ADD")
	local castBorder = NewEdges(cast)
	local iconFrame = CreateFrame("Frame", nil, scaleHost)
	local iconBg = iconFrame:CreateTexture(nil, "BACKGROUND")
	iconBg:SetAllPoints()
	iconBg:SetTexture(0, 0, 0, 1)
	local icon = iconFrame:CreateTexture(nil, "ARTWORK")
	icon:SetTexture("Interface\\Icons\\Spell_Shadow_ShadowBolt")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local castName = cast:CreateFontString(nil, "OVERLAY")
	castName:SetFont(PreviewFont(), 10, "OUTLINE")
	castName:SetWordWrap(false)
	local castTarget = cast:CreateFontString(nil, "OVERLAY")
	castTarget:SetFont(PreviewFont(), 10, "OUTLINE")
	castTarget:SetWordWrap(false)
	local castTimer = cast:CreateFontString(nil, "OVERLAY")
	castTimer:SetFont(PreviewFont(), 10, "OUTLINE")

	-- Debuff icons.
	local auras = {}
	for i = 1, 3 do
		local f = CreateFrame("Frame", nil, scaleHost)
		f.bg = f:CreateTexture(nil, "BACKGROUND")
		f.bg:SetAllPoints()
		f.bg:SetTexture(0, 0, 0, 1)
		f.tex = f:CreateTexture(nil, "ARTWORK")
		f.tex:SetTexture(PREVIEW_ICONS[i])
		f.timer = f:CreateFontString(nil, "OVERLAY")
		f.timer:SetFont(PreviewFont(), 11, "OUTLINE")
		f.timer:SetText(tostring(4 + i * 3))
		f.stack = f:CreateFontString(nil, "OVERLAY")
		f.stack:SetFont(PreviewFont(), 11, "OUTLINE")
		f.stack:SetText(i == 1 and "3" or "")
		auras[i] = f
	end

	local function TextColor(slotKey, el)
		local mode = SlotColorMode(slotKey)
		if mode == "class" then
			if el == "targetOfTarget" then
				return CGet(slotKey .. "Color")()
			end
			return CGet("enemyNameHostileColor", "hostile")()
		elseif mode == "level" then
			return 1, 0.82, 0
		end
		local c = DB()[slotKey .. "Color"] or defaults[slotKey .. "Color"] or defaults.textSlotTopColor
		return c.r or 1, c.g or 1, c.b or 1
	end

	local function TimerPoint(pos)
		if pos == "topleft" then return "TOPLEFT" end
		if pos == "topright" then return "TOPRIGHT" end
		if pos == "bottomleft" then return "BOTTOMLEFT" end
		if pos == "bottomright" then return "BOTTOMRIGHT" end
		return "CENTER"
	end

	local function Update()
		local p = DB()
		local w = BAR_W + (Val("healthBarWidth") or 0)
		local h = Val("healthBarHeight") or 17
		local ch = Val("castBarHeight") or 17
		local slot = Val("debuffSlot") or "top"
		local aSize = (slot ~= "none") and (Val(slot .. "SlotSize") or 24) or 24

		-- Fit the plate in the header.
		local needH = h + ch + 2 * (aSize + 26)
		local needW = w + 2 * (aSize * 3 + 40)
		local scale = UIParent:GetEffectiveScale() / max(0.01, host:GetEffectiveScale())
		scale = min(scale, (PREVIEW_H - 10) / needH, (width - 40) / needW)
		scaleHost:SetScale(max(0.2, scale))
		scaleHost:SetSize(w, h + ch)

		-- Health bar.
		health:ClearAllPoints()
		health:SetPoint("TOP", scaleHost, "TOP", 0, 0)
		health:SetSize(w, h)
		local bgc = p.bgColor or defaults.bgColor
		bg:SetTexture(bgc.r, bgc.g, bgc.b, Val("bgAlpha") or 1)
		fill:SetTexture(TexPath(Val("healthBarTexture")) or WHITE)
		local er, eg, eb = CGet("enemyInCombat")()
		if Val("targetColorEnabled") and TGEui() then
			er, eg, eb = CGet("target")()
		end
		fill:SetVertexColor(er, eg, eb, 1)
		fill:SetWidth(max(1, w * 0.68))
		absorb:Hide()
		if TGHighlight() then
			local hr, hg, hb = CGet("targetHighlightColor")()
			highlight:SetTexture(hr, hg, hb, Val("targetHighlightAlpha") or 0.2)
			highlight:Show()
		else
			highlight:Hide()
		end
		if TGEui() then
			local gr, gg, gb = CGet("targetGlowColor")()
			glow:SetTexture(gr, gg, gb, 0.35 * (Val("targetGlowAlpha") or 1))
			glow:Show()
		else
			glow:Hide()
		end
		if Val("hashLineEnabled") and (Val("hashLinePercent") or 0) > 0 then
			local hr, hg, hb = CGet("hashLineColor")()
			hash:SetTexture(hr, hg, hb, 1)
			hash:ClearAllPoints()
			hash:SetPoint("TOP", health, "TOPLEFT", w * Val("hashLinePercent") / 100, 0)
			hash:SetSize(1, h)
			hash:Show()
		else
			hash:Hide()
		end
		local bsize = CurrentBorderSize()
		local br, bgg, bb, ba
		if p.customBorderEnabled then
			br, bgg, bb = CGet("customBorderColor")()
			ba = Val("customBorderAlpha") or 1
		else
			br, bgg, bb = CGet("borderColor")()
			ba = 1
		end
		if TGBorderColor() then
			br, bgg, bb = CGet("targetBorderColor")()
		end
		if TGBorderSize() and p.targetBorderSizeValue then
			bsize = p.targetBorderSizeValue
		end
		LayoutEdges(border, health, bsize, br, bgg, bb, ba)

		-- Texts.
		for _, s in ipairs(TEXT_SLOTS) do
			local fs = texts[s.key]
			local el = SlotElement(s.key)
			if el == "none" then
				fs:Hide()
			else
				local size = Val(s.key .. "Size") or 10
				fs:SetFont(PreviewFont(), max(1, size), "OUTLINE")
				fs:ClearAllPoints()
				local x = s.x + (Val(s.key .. "XOffset") or 0)
				local y = s.y + (Val(s.key .. "YOffset") or 0)
				if s.bottom then
					fs:SetPoint(s.point, cast, s.rel, x, y)
				else
					fs:SetPoint(s.point, health, s.rel, x, y)
				end
				if NAME_FAMILY[el] then
					local nw = (s.key == "textSlotTop" or s.key == "textSlotCenter") and w or (w * 0.62)
					fs:SetWidth(max(20, nw * (Val("enemyNameWidthPct") or 100) / 100))
				else
					fs:SetWidth(0)
				end
				fs:SetText(SampleText(el, s.key))
				fs:SetTextColor(TextColor(s.key, el))
				fs:Show()
			end
		end

		-- Cast bar.
		local showIcon = Val("showCastIcon") ~= false
		local iconScale = Val("castIconScale") or 1
		local iconW, shiftX = 0, 0
		if showIcon and Val("castbarIconInWidth") and not Val("castIconFullSize") then
			iconW = ch * iconScale
			if not Val("castIconOnRight") then shiftX = iconW end
		end
		cast:ClearAllPoints()
		cast:SetSize(max(1, w - iconW), ch)
		cast:SetPoint("TOPLEFT", health, "TOPLEFT", shiftX, -h + (Val("castBarOffsetY") or 0))
		local cbg = p.castBgColor or defaults.castBgColor
		castBg:SetTexture(cbg.r, cbg.g, cbg.b, Val("castBgAlpha") or 0.9)
		castFill:SetTexture(TexPath(Val("castBarTexture")) or WHITE)
		castFill:SetVertexColor(CGet("castBar")())
		local cw = max(1, w - iconW)
		castFill:SetWidth(max(1, cw * 0.5))
		castSpark:ClearAllPoints()
		castSpark:SetSize(12, ch * 2)
		castSpark:SetPoint("CENTER", cast, "LEFT", cw * 0.5, 0)
		if Val("castBarSparkEnabled") ~= false then castSpark:Show() else castSpark:Hide() end
		local cbr, cbgg, cbb = CGet("castBorderColor")()
		LayoutEdges(castBorder, cast, Val("castBorderSize") or 0, cbr, cbgg, cbb, 1)

		iconFrame:ClearAllPoints()
		local xo, yo = Val("castIconOffsetX") or 0, Val("castIconOffsetY") or 0
		local onRight = Val("castIconOnRight")
		if Val("castIconFullSize") then
			local side = h + ch
			iconFrame:SetScale(1)
			iconFrame:SetSize(side, side)
			if onRight then
				iconFrame:SetPoint("TOPLEFT", health, "TOPRIGHT", xo, yo)
			else
				iconFrame:SetPoint("TOPRIGHT", health, "TOPLEFT", xo, yo)
			end
		else
			iconFrame:SetScale(iconScale)
			iconFrame:SetSize(ch, ch)
			if onRight then
				iconFrame:SetPoint("TOPLEFT", cast, "TOPRIGHT", xo, yo)
			else
				iconFrame:SetPoint("TOPRIGHT", cast, "TOPLEFT", xo, yo)
			end
		end
		icon:ClearAllPoints()
		if Val("hideCastIconBorder") then
			icon:SetPoint("TOPLEFT", 0, 0)
			icon:SetPoint("BOTTOMRIGHT", 0, 0)
			iconBg:Hide()
		else
			icon:SetPoint("TOPLEFT", 1, -1)
			icon:SetPoint("BOTTOMRIGHT", -1, 1)
			iconBg:Show()
		end
		if showIcon then iconFrame:Show() else iconFrame:Hide() end

		local function PlaceText(fs, side, ox, oy)
			fs:ClearAllPoints()
			if not side or side == "none" then
				fs:Hide()
				return
			end
			local pt = (side == "left" and "LEFT") or (side == "right" and "RIGHT") or "CENTER"
			local x = (side == "left" and 3) or (side == "right" and -3) or 0
			fs:SetPoint(pt, cast, pt, x + (ox or 0), oy or 0)
			fs:Show()
		end
		local combine = Val("castCombineNameTarget")
		castName:SetFont(PreviewFont(), max(1, Val("castNameSize") or 10), "OUTLINE")
		castName:SetText(combine and "Shadow Bolt > Tanky" or "Shadow Bolt")
		castName:SetTextColor(CGet("castNameColor")())
		castName:SetWidth(cw * (combine and 80 or (Val("castNameWidthPct") or 42)) / 100)
		PlaceText(castName, Val("castNameSide"), Val("castNameOffsetX"), Val("castNameOffsetY"))
		castTarget:SetFont(PreviewFont(), max(1, Val("castTargetSize") or 10), "OUTLINE")
		castTarget:SetText("Tanky")
		castTarget:SetWidth(cw * (Val("castTargetWidthPct") or 42) / 100)
		if Val("castTargetClassColor") then
			castTarget:SetTextColor(PlayerClassColor())
		else
			castTarget:SetTextColor(CGet("castTargetColor")())
		end
		PlaceText(castTarget, (not combine) and Val("castTargetSide") or "none", Val("castTargetOffsetX"), Val("castTargetOffsetY"))
		castTimer:SetFont(PreviewFont(), max(1, Val("castTimerSize") or 10), "OUTLINE")
		castTimer:SetText("1.2")
		castTimer:SetTextColor(CGet("castTimerColor")())
		PlaceText(castTimer, (Val("showCastTimer") ~= false) and (Val("castTimerSide") or "right") or "none",
			Val("castTimerOffsetX"), Val("castTimerOffsetY"))

		-- Debuffs in their Core Positions slot.
		local sp = Val("debuffSpacing") or 2
		local cropped = Val("debuffCropIcons")
		local ih = aSize
		if cropped then
			local pct = max(5, min(25, tonumber(Val("debuffCropPercent")) or 10))
			ih = floor(aSize * (1 - 2 * pct / 100) + 0.5)
		end
		local xo2, yo2 = Val(slot .. "SlotXOffset") or 0, Val(slot .. "SlotYOffset") or 0
		local growth = "right"
		if slot == "left" then
			growth = "left"
		elseif slot == "topleft" or slot == "topright" then
			growth = Val(slot .. "SlotGrowth") or (slot == "topleft" and "left" or "right")
		end
		local n = #auras
		local total = n * aSize + (n - 1) * sp
		local dpos = Val("debuffTimerPosition") or Val("auraTextPosition") or "topleft"
		local dsize = Val("debuffDurationTextSize") or Val("auraDurationTextSize") or 11
		local dr, dg, db2 = CGet("debuffDurationTextColor", "auraDurationTextColor")()
		local spos = Val("auraStackTextPosition") or "bottomright"
		for i, f in ipairs(auras) do
			f:ClearAllPoints()
			f:SetSize(aSize, ih)
			f.tex:ClearAllPoints()
			if Val("hideDebuffIconBorder") then
				f.tex:SetPoint("TOPLEFT", 0, 0)
				f.tex:SetPoint("BOTTOMRIGHT", 0, 0)
				f.bg:Hide()
			else
				f.tex:SetPoint("TOPLEFT", 1, -1)
				f.tex:SetPoint("BOTTOMRIGHT", -1, 1)
				f.bg:Show()
			end
			if cropped then
				local cut = (1 - ih / aSize) / 2 * 0.84
				f.tex:SetTexCoord(0.08, 0.92, 0.08 + cut, 0.92 - cut)
			else
				f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			end
			local k = i - 1
			if slot == "none" then
				f:Hide()
			else
				if slot == "top" then
					local anchor = (SlotElement("textSlotTop") ~= "none") and texts.textSlotTop or health
					f:SetPoint("BOTTOMLEFT", anchor, "TOP", -total / 2 + k * (aSize + sp) + xo2, (Val("debuffYOffset") or 2) + yo2)
				elseif slot == "bottom" then
					f:SetPoint("TOPLEFT", cast, "BOTTOM", -total / 2 + k * (aSize + sp) + xo2, -2 + yo2)
				elseif slot == "left" then
					f:SetPoint("BOTTOMRIGHT", health, "BOTTOMLEFT", -(Val("sideAuraXOffset") or 2) + xo2 - k * (aSize + sp), yo2)
				elseif slot == "right" then
					f:SetPoint("BOTTOMLEFT", health, "BOTTOMRIGHT", (Val("sideAuraXOffset") or 2) + xo2 + k * (aSize + sp), yo2)
				else
					local hc = slot == "topleft" and "TOPLEFT" or "TOPRIGHT"
					local y0 = (Val("debuffYOffset") or 2) + yo2
					if growth == "up" then
						local pt = slot == "topleft" and "BOTTOMLEFT" or "BOTTOMRIGHT"
						f:SetPoint(pt, health, hc, xo2, y0 + k * (ih + sp))
					elseif growth == "left" then
						f:SetPoint("BOTTOMRIGHT", health, hc, (slot == "topleft" and aSize or 0) + xo2 - k * (aSize + sp), y0)
					else
						f:SetPoint("BOTTOMLEFT", health, hc, (slot == "topright" and -aSize or 0) + xo2 + k * (aSize + sp), y0)
					end
				end
				f.timer:SetFont(PreviewFont(), max(1, dsize), "OUTLINE")
				f.timer:SetTextColor(dr, dg, db2, 1)
				f.timer:ClearAllPoints()
				local tp = TimerPoint(dpos)
				f.timer:SetPoint(tp, f, tp, Val("debuffDurationTextX") or Val("auraDurationTextX") or 0,
					Val("debuffDurationTextY") or Val("auraDurationTextY") or 0)
				if dpos == "none" then f.timer:Hide() else f.timer:Show() end
				f.stack:SetFont(PreviewFont(), max(1, Val("auraStackTextSize") or 11), "OUTLINE")
				f.stack:SetTextColor(CGet("auraStackTextColor")())
				f.stack:ClearAllPoints()
				local stp = TimerPoint(spos)
				f.stack:SetPoint(stp, f, stp, Val("auraStackTextX") or 0, Val("auraStackTextY") or 0)
				if spos == "none" then f.stack:Hide() else f.stack:Show() end
				f:Show()
			end
		end

		-- Center the health + cast stack.
		health:ClearAllPoints()
		health:SetPoint("CENTER", scaleHost, "CENTER", 0, ch / 2)
	end
	page:OnRefresh(Update)
	Update()
	return PREVIEW_H
end

---------------------------------------------------------------------------
-- Display page
---------------------------------------------------------------------------
local function TextCog(p, s)
	local el = SlotElement(s.key)
	local rows = {
		{ type = "slider", label = "Size", min = 6, max = 30, get = Get(s.key .. "Size", 10), set = Set(s.key .. "Size") },
		{ type = "slider", label = "X Offset", min = -300, max = 300, get = Get(s.key .. "XOffset", 0), set = Set(s.key .. "XOffset") },
		{ type = "slider", label = "Y Offset", min = -300, max = 300, get = Get(s.key .. "YOffset", 0), set = Set(s.key .. "YOffset") },
	}
	if NAME_FAMILY[el] and not s.bottom then
		rows[#rows + 1] = { type = "slider", label = "Width %", min = 10, max = 150,
			tip = "Maximum width the text can fill before it truncates, as a percentage of the bar.",
			get = Get("enemyNameWidthPct", 100), set = Set("enemyNameWidthPct") }
		rows[#rows + 1] = { type = "toggle", label = "Wrap",
			tip = "Lets long text wrap onto a second line instead of being cut off.",
			get = On("enemyNameWrap"), set = Set("enemyNameWrap") }
	end
	if HEALTH_ELEMENTS[el] then
		rows[#rows + 1] = { type = "toggle", label = "Show % Decimal",
			get = On(s.key .. "PctDecimal"), set = Set(s.key .. "PctDecimal") }
	end
	p:Cog(s.label .. " Settings", rows, { icon = "resize" })
end

local function TextItems(s)
	local items = { { value = "none", name = "Remove" }, { separator = true, name = "" } }
	local centerName = NAME_FAMILY[SlotElement("textSlotCenter")]
	for _, e in ipairs(ELEMENTS) do
		local id = e[1]
		local item = { value = id, name = e[2] }
		item.locked = function()
			for _, o in ipairs(TEXT_SLOTS) do
				if o.key ~= s.key then
					local oe = SlotElement(o.key)
					if oe == id or (NAME_FAMILY[id] and NAME_FAMILY[oe]) then
						return true
					end
				end
			end
			if (s.key == "textSlotLeft" or s.key == "textSlotRight") and COMBINED_HEALTH[id] and centerName then
				return true
			end
			return false
		end
		if (s.key == "textSlotLeft" or s.key == "textSlotRight") and COMBINED_HEALTH[id] and centerName then
			item.lockedTip = "Disabled when the Name/Level text is centered on the health bar due to overlapping text"
		else
			item.lockedTip = "This text is already shown in another slot."
		end
		items[#items + 1] = item
	end
	return items
end

local ADD_ORDER = { "enemyName", "healthPercent", "level", "healthNumber", "targetOfTarget" }

local function ElementUsed(id)
	for _, s in ipairs(TEXT_SLOTS) do
		local e = SlotElement(s.key)
		if e == id or (NAME_FAMILY[id] and NAME_FAMILY[e]) then
			return true
		end
	end
	return false
end

local function NextFreeElement()
	for _, id in ipairs(ADD_ORDER) do
		if not ElementUsed(id) then
			return id
		end
	end
	return nil
end

local function FreeTextSlot()
	for _, s in ipairs(TEXT_SLOTS) do
		if SlotElement(s.key) == "none" then
			return true
		end
	end
	return false
end

local function SlotCog(p, pos)
	local slot = pos.key
	local rows = {
		{ type = "slider", label = "Size", min = 10, max = 50, get = Get(slot .. "SlotSize", 24), set = Set(slot .. "SlotSize") },
		{ type = "slider", label = "X Offset", min = -300, max = 300, get = Get(slot .. "SlotXOffset", 0), set = Set(slot .. "SlotXOffset") },
		{ type = "slider", label = "Y Offset", min = -300, max = 300, get = Get(slot .. "SlotYOffset", 0), set = Set(slot .. "SlotYOffset") },
	}
	if GROWS[slot] then
		local list = GROWS[slot]
		rows[#rows + 1] = { type = "dropdown", label = "Grow",
			items = function() return Items(list) end,
			get = Get(slot .. "SlotGrowth", list[1][1]), set = Set(slot .. "SlotGrowth") }
	end
	for _, e in ipairs(POS_ELEMENTS) do
		if e.kind and ElementIn(e, slot) then
			local k, kk = e.kind, e.kindKey
			local cropOff = Off(k .. "CropIcons")
			rows[#rows + 1] = { type = "slider", label = "Spacing", min = -5, max = 20,
				get = Get(k .. "Spacing", 2), set = Set(k .. "Spacing") }
			rows[#rows + 1] = { type = "toggle", label = "Cropped Icons",
				get = On(k .. "CropIcons"), set = Set(k .. "CropIcons") }
			rows[#rows + 1] = { type = "slider", label = "Adjust Crop", min = 5, max = 25,
				tip = "How much is trimmed from the icon's top and bottom, as a percentage per side. 10% is the classic cropped look.",
				get = Get(k .. "CropPercent", 10), set = Set(k .. "CropPercent"), disabled = cropOff }
			rows[#rows + 1] = { type = "toggle", label = "Hide Border",
				get = On("hide" .. kk .. "IconBorder"), set = Set("hide" .. kk .. "IconBorder") }
		end
	end
	if Val("classificationSlot") == slot and not (Val("classificationHideRare") and Val("classificationHideQuest")) then
		rows[#rows + 1] = { type = "toggle", label = "Show In Instances",
			get = On("classificationShowInInstances"), set = Set("classificationShowInInstances") }
	end
	rows[#rows + 1] = { type = "toggle", label = "Raise Strata",
		tip = "Renders this slot's element above the rest of the nameplate.",
		get = On(slot .. "SlotRaiseStrata"), set = Set(slot .. "SlotRaiseStrata") }
	p:Cog(pos.label .. " Slot Settings", rows, { icon = "resize",
		disabled = function() return SlotEmpty(slot) end,
		disabledTip = "This option requires an aura or indicator to be assigned" })
end

local function PositionCell(p, pos)
	local slot = pos.key
	local function GetItems()
		local items = {}
		for _, e in ipairs(POS_ELEMENTS) do
			items[#items + 1] = {
				value = e.id, name = e.name, tip = e.tip,
				locked = function()
					for g in pairs(SlotGroups(slot)) do
						if g ~= e.group then
							return true
						end
					end
					return false
				end,
				lockedTip = "Only the Rare and Quest Indicators can share a slot.",
			}
		end
		return items
	end
	local function Find(id)
		for _, e in ipairs(POS_ELEMENTS) do
			if e.id == id then
				return e
			end
		end
	end
	p:MultiSelect(pos.label, nil, GetItems,
		function(id) return ElementIn(Find(id), slot) end,
		function(id)
			local e = Find(id)
			local d = DB()
			if ElementIn(e, slot) then
				if e.hide then
					if Val(e.other) == true then
						d[e.key] = "none"
						d[e.hide] = false
						d[e.other] = false
					else
						d[e.hide] = true
					end
				else
					d[e.key] = "none"
				end
			else
				if e.hide then
					local old = Val(e.key)
					local otherOn = old ~= "none" and Val(e.other) ~= true
					d[e.key] = slot
					d[e.hide] = false
					if not otherOn then
						d[e.other] = true
					end
				else
					d[e.key] = slot
				end
			end
			Rebuild()
		end,
		function()
			local names = {}
			for _, e in ipairs(POS_ELEMENTS) do
				if ElementIn(e, slot) then
					names[#names + 1] = e.name
				end
			end
			if #names == 0 then
				return "None"
			end
			return table.concat(names, ", ")
		end)
	SlotCog(p, pos)
end

local function BuildDisplay(p)
	ElvUINote(p)

	-------------------------------------------------------------------
	p:Section("Style")
	local BORDER_MODES = { { "none", "None" }, { "basic", "Basic" }, { "custom", "Custom" } }
	p:Dropdown("Border", nil, function() return Items(BORDER_MODES) end, BorderMode,
		function() return LabelOf(BORDER_MODES, BorderMode()) end,
		function(v)
			local d = DB()
			if v == "none" then
				d.showBorder, d.customBorderEnabled = false, false
			elseif v == "basic" then
				d.showBorder, d.customBorderEnabled = true, false
			else
				d.customBorderEnabled = true
			end
			Rebuild()
		end)
	Swatch(p, "Border Color", "borderColor", { disabled = function() return BorderMode() ~= "basic" end })
	p:Slider("Border Size", "This option is only used by the Basic border.", 1, 4, 1, Get("borderSize", 1), Set("borderSize"),
		function() return BorderMode() ~= "basic" end)

	if BorderMode() == "custom" then
		p:Slider("Custom Border Size", "Border size in pixels.", 0, 32, 1, Get("customBorderSize", 1), Set("customBorderSize"))
		p:Swatch("Border Color", CGet("customBorderColor"), function(r, g, b, a)
			DB().customBorderColor = { r = r, g = g, b = b }
			DB().customBorderAlpha = a or 1
		end, { alpha = true })
		p:Blank()
	end

	p:Slider("Background", nil, 0, 100, 1, GetPct("bgAlpha", 1), SetPct("bgAlpha"))
	Swatch(p, "Background Color", "bgColor")
	Drop(p, "Absorb Style", nil, ABSORB_STYLES, "absorbStyle", "blizzard")
	Swatch(p, "Absorb Color", "absorbColor", { disabled = function() return (Val("absorbStyle") or "blizzard") == "blizzard" end })
	p:Cog("Absorb Settings", {
		{ type = "slider", label = "Opacity", min = 5, max = 100, get = Get("absorbCleanAlpha", 30), set = Set("absorbCleanAlpha"),
		  disabled = function() return Val("absorbStyle") ~= "clean" end },
		{ type = "dropdown", label = "Placement",
		  tip = "Overlay fills empty health first, then draws any excess over current health. Overlay Reverse draws the shield back over current health; a shield larger than current health spans from the bar's left end. From Right Edge and From Left Edge grow the whole shield from that end of the bar.",
		  items = function() return Items(ABSORB_PLACEMENT) end, get = Get("absorbEdgeMode", "overlay"), set = Set("absorbEdgeMode") },
	})

	TexDrop(p, "Bar Texture", nil, "healthBarTexture", BarTextureItems)
	TexDrop(p, "Cast Bar Texture", nil, "castBarTexture", BarTextureItems)

	-------------------------------------------------------------------
	p:Section("Core Positions")
	for _, pos in ipairs(POSITIONS) do
		PositionCell(p, pos)
	end

	-------------------------------------------------------------------
	p:Section("Core Text Positions")
	local cells = 0
	for _, s in ipairs(TEXT_SLOTS) do
		if SlotElement(s.key) ~= "none" then
			cells = cells + 1
			p:Dropdown(s.label, nil, function() return TextItems(s) end,
				function() return SlotElement(s.key) end,
				function() return KNOWN_ELEMENT[SlotElement(s.key)] or "None" end,
				function(v)
					DB()[s.key] = v
					if v == "targetOfTarget" then
						DB()[s.key .. "ColorMode"] = "class"
					end
					Rebuild()
				end)
			TextCog(p, s)
		end
	end
	local function AddItems()
		local items = {}
		for _, s in ipairs(TEXT_SLOTS) do
			items[#items + 1] = {
				value = s.key, name = s.menu,
				locked = function() return SlotElement(s.key) ~= "none" end,
				lockedTip = "This text position is already used.",
			}
		end
		return items
	end
	p:Dropdown("Add Text Slot", "Adds a text to a free text position.",
		AddItems, function() return nil end,
		function()
			if not FreeTextSlot() then return "Every text position is full." end
			if not NextFreeElement() then return "Every text is already shown." end
			return "+ Add Text Slot"
		end,
		function(slotKey)
			local id = NextFreeElement()
			if not id or SlotElement(slotKey) ~= "none" then
				return
			end
			DB()[slotKey] = id
			if id == "targetOfTarget" then
				DB()[slotKey .. "ColorMode"] = "class"
			end
			Rebuild()
		end, nil,
		function() return not FreeTextSlot() or not NextFreeElement() end)
	cells = cells + 1

	-------------------------------------------------------------------
	local assigned = {}
	for _, s in ipairs(TEXT_SLOTS) do
		if SlotElement(s.key) ~= "none" then
			assigned[#assigned + 1] = s
		end
	end
	if #assigned > 0 then
		p:Section("Core Text Coloring")
		for _, s in ipairs(assigned) do
			local el = SlotElement(s.key)
			local list
			if el == "targetOfTarget" then
				list = { { "custom", "Custom" }, { "class", "Class" } }
			else
				list = { { "custom", "Custom" }, { "class", "Hostility / Class" }, { "level", "Level Difficulty" } }
			end
			p:Dropdown(s.label .. " Coloring", nil, function() return Items(list) end,
				function() return SlotColorMode(s.key) end,
				function() return LabelOf(list, SlotColorMode(s.key)) end,
				function(v)
					DB()[s.key .. "ColorMode"] = v
					Rebuild()
				end)
			local mode = SlotColorMode(s.key)
			if mode == "custom" or (el == "targetOfTarget" and mode == "class") then
				Swatch(p, (el == "targetOfTarget" and mode == "class") and "NPC Target Color" or "Custom Color", s.key .. "Color")
			elseif mode == "class" then
				Swatch(p, "Hostile Color", "enemyNameHostileColor", { fallback = "hostile" })
				Swatch(p, "Neutral Color", "enemyNameNeutralColor", { fallback = "neutral" })
			end
			if (el == "levelName" or el == "nameLevel") and mode ~= "level" then
				p:Cog(s.label .. " Coloring", {
					{ type = "toggle", label = "Level Difficulty Color",
					  get = function()
						local v = DB()[s.key .. "LevelDiffOn"]
						if v == nil then v = DB().levelDifficultyColor end
						return v == true
					  end,
					  set = Set(s.key .. "LevelDiffOn") },
				})
			end
		end
		if #assigned % 2 == 1 then
			p:Blank()
		end
	end

	-------------------------------------------------------------------
	p:Section("Health and Cast Bar")
	p:Slider("Health Bar Width", nil, 100, BAR_W + 100, 1,
		function() return BAR_W + (Val("healthBarWidth") or 0) end,
		function(v) DB().healthBarWidth = v - BAR_W end)
	p:Slider("Health Bar Height", nil, 6, 50, 1, Get("healthBarHeight", 17), Set("healthBarHeight"))
	p:Slider("Cast Bar Height", nil, 10, 40, 1, Get("castBarHeight", 17), Set("castBarHeight"))
	p:Toggle("Spell Icon", nil, On("showCastIcon", true), Set("showCastIcon"))
	p:Cog("Spell Icon Settings", {
		{ type = "slider", label = "Scale", min = 0.5, max = 2, step = 0.1, get = Get("castIconScale", 1),
		  set = function(v) DB().castIconScale = floor(v * 10 + 0.5) / 10 end },
		{ type = "slider", label = "X Offset", min = -50, max = 50, get = Get("castIconOffsetX", 0), set = Set("castIconOffsetX") },
		{ type = "slider", label = "Y Offset", min = -50, max = 50, get = Get("castIconOffsetY", 0), set = Set("castIconOffsetY") },
		{ type = "toggle", label = "Make Icon Part of the Bar",
		  tip = "This makes it so the width of the cast bar includes the icon, rather than placing it to the left of the cast bars width.",
		  get = On("castbarIconInWidth"), set = Set("castbarIconInWidth") },
		{ type = "toggle", label = "Icon on Right",
		  tip = "Place the cast bar spell icon on the right side of the bars instead of the left.",
		  get = On("castIconOnRight"), set = Set("castIconOnRight") },
		{ type = "toggle", label = "Full Sized (Health + Cast Bar)",
		  tip = "Make the spell icon a large square the combined height of the health bar plus the cast bar, flush with the top of the health bar and the bottom of the cast bar.",
		  get = On("castIconFullSize"), set = Set("castIconFullSize") },
		{ type = "toggle", label = "Hide Border",
		  tip = "Hide the 1-pixel border around the cast bar spell icon.",
		  get = On("hideCastIconBorder"), set = Set("hideCastIconBorder") },
	}, { icon = "resize", disabled = Off("showCastIcon", true), disabledTip = "This option requires Spell Icon to be enabled" })

	p:Slider("Cast Background", nil, 0, 100, 1, GetPct("castBgAlpha", 0.9), SetPct("castBgAlpha"))
	Swatch(p, "Cast Background Color", "castBgColor")
	p:Slider("Cast Bar Border", "Pixel-perfect border around the cast bar. Set to 0 for no border.", 0, 4, 1,
		Get("castBorderSize", 0), Set("castBorderSize"))
	Swatch(p, "Cast Bar Border Color", "castBorderColor")

	local TIMER_SIDES = { { "none", "None" }, { "right", "Right" }, { "left", "Left" } }
	local function TimerSide()
		if Val("showCastTimer") == false then return "none" end
		return Val("castTimerSide") or "right"
	end
	p:Dropdown("Cast Timer", nil, function() return Items(TIMER_SIDES) end, TimerSide,
		function() return LabelOf(TIMER_SIDES, TimerSide()) end,
		function(v)
			if v == "none" then
				DB().showCastTimer = false
			else
				DB().showCastTimer = true
				DB().castTimerSide = v
			end
		end)
	Swatch(p, "Cast Timer Color", "castTimerColor")
	p:Cog("Cast Timer Settings", {
		{ type = "slider", label = "Size", min = 6, max = 20, get = Get("castTimerSize", 10), set = Set("castTimerSize") },
		{ type = "slider", label = "X Offset", min = -300, max = 300, get = Get("castTimerOffsetX", 0), set = Set("castTimerOffsetX") },
		{ type = "slider", label = "Y Offset", min = -300, max = 300, get = Get("castTimerOffsetY", 0), set = Set("castTimerOffsetY") },
	}, { icon = "resize" })
	p:Slider("Cast Bar Y Offset", "Nudge the cast bar up or down from its default spot under the health bar.", -25, 75, 1,
		Get("castBarOffsetY", 0), Set("castBarOffsetY"))

	-------------------------------------------------------------------
	p:Section("Cast Colors and Effects")
	p:Label("Cast Color")
	Swatch(p, "Uninterruptible Cast", "castBarUninterruptible")
	Swatch(p, "Interrupt on CD", "interruptReady")
	Swatch(p, "Interruptible Cast", "castBar")
	p:Cog("Cast Color", {
		{ type = "toggle", label = "Show Shield Icon",
		  tip = "Show a shield icon on the cast bar when an enemy's cast cannot be interrupted.",
		  get = On("castBarShieldEnabled", true), set = Set("castBarShieldEnabled") },
		{ type = "toggle", label = "Show Spark",
		  tip = "Show the bright spark at the leading edge of the cast bar fill.",
		  get = On("castBarSparkEnabled", true), set = Set("castBarSparkEnabled") },
	}, { tip = "Cast Color Settings" })

	local KICK_HINT = { { "none", "None" }, { "tick", "Tick" }, { "tickbar", "Tick + Bar" } }
	local function KickHint()
		if Val("kickTickEnabled") == false then return "none" end
		if Val("interruptMidCastEnabled") then return "tickbar" end
		return "tick"
	end
	p:Dropdown("Kick Ready Mid-Cast Hint",
		"Shows where your interrupt will be ready during an enemy cast. \"Tick\" marks the exact spot on the cast bar; \"Tick + Bar\" also colours the window during which your interrupt will be available.",
		function() return Items(KICK_HINT) end, KickHint,
		function() return LabelOf(KICK_HINT, KickHint()) end,
		function(v)
			DB().kickTickEnabled = v ~= "none"
			DB().interruptMidCastEnabled = v == "tickbar"
		end)
	Swatch(p, "Interrupt Ready Mid-Cast", "interruptMidCastColor", { disabled = function() return KickHint() ~= "tickbar" end })

	p:Toggle("Show Interrupted Flash Effect",
		"Flash the enemy's cast bar and show \"Interrupted\" for a moment when their cast is interrupted. Use the swatch to change the flash colour.",
		On("interruptedFlashEnabled", true), Set("interruptedFlashEnabled"))
	Swatch(p, "Interrupted Flash Colour", "interruptedFlashColor", { disabled = Off("interruptedFlashEnabled", true) })
	p:Blank()

	-------------------------------------------------------------------
	p:Section("Target, Focus & Hover Effects")
	local TARGET_FX = {
		{ id = "eui", name = "EUI Glow", get = TGEui, key = "targetGlowEllesmereUI" },
		{ id = "border", name = "Border Color", get = TGBorderColor, key = "targetGlowBorderColor" },
		{ id = "highlight", name = "Highlight", get = TGHighlight, key = "targetGlowHighlight" },
		{ id = "size", name = "Border Size", get = TGBorderSize, key = "targetGlowBorderSize", tip = "Change Size in the Cogwheel", snap = "targetBorderSizeValue" },
	}
	local HOVER_FX = {
		{ id = "eui", name = "EUI Glow", get = HVEui, key = "hoverGlowEllesmereUI" },
		{ id = "border", name = "Border Color", get = HVBorderColor, key = "hoverGlowBorderColor" },
		{ id = "highlight", name = "Highlight", get = HVHighlight, key = "hoverGlowHighlight" },
		{ id = "size", name = "Border Size", get = HVBorderSize, key = "hoverGlowBorderSize", tip = "Change Size in the Cogwheel", snap = "hoverBorderSizeValue" },
	}
	local function FxSelect(label, list)
		local function Find(id)
			for _, e in ipairs(list) do
				if e.id == id then return e end
			end
		end
		p:MultiSelect(label, nil,
			function()
				local items = {}
				for _, e in ipairs(list) do
					items[#items + 1] = { value = e.id, name = e.name, tip = e.tip }
				end
				return items
			end,
			function(id) return Find(id).get() end,
			function(id)
				local e = Find(id)
				local on = not e.get()
				DB()[e.key] = on
				if on and e.snap and DB()[e.snap] == nil then
					DB()[e.snap] = CurrentBorderSize()
				end
			end,
			function()
				local names = {}
				for _, e in ipairs(list) do
					if e.get() then names[#names + 1] = e.name end
				end
				if #names == 0 then return "None" end
				return table.concat(names, ", ")
			end)
	end

	FxSelect("Target Effect", TARGET_FX)
	Swatch(p, "Glow Color", "targetGlowColor", { disabled = function() return not TGEui() end })
	Swatch(p, "Border Color", "targetBorderColor", { disabled = function() return not TGBorderColor() end })
	p:Cog("More Effects", {
		{ type = "color", label = "Highlight Color", get = CGet("targetHighlightColor"), set = CSet("targetHighlightColor") },
		{ type = "slider", label = "Highlight Opacity", min = 0, max = 100, get = GetPct("targetHighlightAlpha", 0.2), set = SetPct("targetHighlightAlpha") },
		{ type = "slider", label = "Glow Opacity", min = 0, max = 100, get = GetPct("targetGlowAlpha", 1), set = SetPct("targetGlowAlpha") },
		{ type = "slider", label = "Border Size", min = 0, max = 4,
		  get = function() return DB().targetBorderSizeValue or CurrentBorderSize() end, set = Set("targetBorderSizeValue"),
		  disabled = function() return not TGBorderSize() end },
	}, { disabled = function() return not (TGHighlight() or TGEui() or TGBorderSize()) end,
		disabledTip = "This option requires a Target Effect to be selected" })

	local ARROWS = { { "none", "None" } }
	for _, key in ipairs(ENP.TARGET_ARROW_ORDER or {}) do
		local st = ENP.TARGET_ARROW_STYLES[key]
		ARROWS[#ARROWS + 1] = { key, st and st.label or key }
	end
	local function ArrowValue()
		if not Val("showTargetArrows") then return "none" end
		local v = Val("targetArrowStyle") or (Val("targetArrowDouble") and "double") or "simple"
		if not ENP.TARGET_ARROW_STYLES[v] then v = "simple" end
		return v
	end
	local arrowsOff = function() return ArrowValue() == "none" end
	p:Dropdown("Target Arrows", nil, function() return Items(ARROWS) end, ArrowValue,
		function() return LabelOf(ARROWS, ArrowValue()) end,
		function(v)
			if v == "none" then
				DB().showTargetArrows = false
			else
				DB().showTargetArrows = true
				DB().targetArrowStyle = v
			end
		end)
	p:Swatch("Class Color", PlayerClassColor, function() end, {
		readonly = true,
		active = On("targetArrowClassColor"),
		disabled = arrowsOff,
		onClick = function()
			DB().targetArrowClassColor = true
			return true
		end,
	})
	p:Swatch("Custom Color", CGet("targetArrowColor"), CSet("targetArrowColor"), {
		active = Off("targetArrowClassColor"),
		disabled = arrowsOff,
		onClick = function()
			if Val("targetArrowClassColor") then
				DB().targetArrowClassColor = false
				return true
			end
		end,
	})
	p:Cog("Arrow Scale", {
		{ type = "slider", label = "Scale", min = 0.5, max = 3, step = 0.1, get = Get("targetArrowScale", 1),
		  set = function(v) DB().targetArrowScale = floor(v * 10 + 0.5) / 10 end },
	}, { icon = "resize", disabled = arrowsOff, disabledTip = "This option requires Target Arrows to be selected" })

	p:Toggle("Enable Target Color", nil, On("targetColorEnabled"), Set("targetColorEnabled"))
	Swatch(p, "Target Color", "target", { disabled = Off("targetColorEnabled") })
	p:Toggle("Enable Focus Color", nil, On("focusColorEnabled", true), Set("focusColorEnabled"))
	Swatch(p, "Focus Color", "focus", { disabled = Off("focusColorEnabled", true) })

	local function OverlayRow(label, prefix, cogTitle)
		local texKey = prefix .. "OverlayTexture"
		local function NoTex() return (Val(texKey) or "none") == "none" end
		TexDrop(p, label, nil, texKey, OverlayItems)
		Swatch(p, label .. " Color", prefix .. "OverlayColor",
			{ disabled = function() return NoTex() or Val(prefix .. "OverlayNoTint") == true end })
		p:Cog(cogTitle, {
			{ type = "slider", label = "Opacity", min = 5, max = 100, get = GetPct(prefix .. "OverlayAlpha", 1), set = SetPct(prefix .. "OverlayAlpha") },
			{ type = "toggle", label = "Full alpha on empty part of bar", get = On(prefix .. "OverlayFullBgAlpha"), set = Set(prefix .. "OverlayFullBgAlpha") },
			{ type = "toggle", label = "Don't tint (keep bar's own color)",
			  tip = "Tints the pattern with the bar's current color instead of the custom overlay color.",
			  get = On(prefix .. "OverlayNoTint"), set = Set(prefix .. "OverlayNoTint") },
		}, { disabled = NoTex, disabledTip = "This option requires a " .. label .. " to be selected" })
	end
	OverlayRow("Target Texture", "target", "Target Texture")
	OverlayRow("Focus Texture", "focus", "Focus Texture")

	-- Target / Focus Preview: mini bars in the target and focus colors.
	local function MiniPreview(label, colorKey, onKey, onDefault, texKey)
		local cell = p:Label(label)
		local bar = CreateFrame("Frame", nil, cell)
		bar:SetSize(170, 14)
		bar:SetPoint("RIGHT", cell, "RIGHT", -20, 0)
		local bgt = bar:CreateTexture(nil, "BACKGROUND")
		bgt:SetAllPoints()
		local ft = bar:CreateTexture(nil, "ARTWORK")
		ft:SetPoint("TOPLEFT")
		ft:SetPoint("BOTTOMLEFT")
		ft:SetWidth(170 * 0.7)
		local ov = bar:CreateTexture(nil, "ARTWORK", nil, 2)
		ov:SetPoint("TOPLEFT")
		ov:SetPoint("BOTTOMLEFT")
		ov:SetWidth(170 * 0.7)
		local edges = NewEdges(bar)
		local isOn = On(onKey, onDefault)
		p:OnRefresh(function()
			local bgc = DB().bgColor or defaults.bgColor
			bgt:SetTexture(bgc.r, bgc.g, bgc.b, Val("bgAlpha") or 1)
			ft:SetTexture(TexPath(Val("healthBarTexture")) or WHITE)
			local r, g, b
			if isOn() then
				r, g, b = CGet(colorKey)()
				bar:SetAlpha(1)
			else
				r, g, b = CGet("enemyInCombat")()
				bar:SetAlpha(0.3)
			end
			ft:SetVertexColor(r, g, b, 1)
			local tex = TexPath(Val(texKey))
			if tex then
				ov:SetTexture(tex)
				if Val(texKey:gsub("Texture$", "NoTint")) then
					ov:SetVertexColor(r, g, b, Val(texKey:gsub("Texture$", "Alpha")) or 1)
				else
					local orr, og, ob = CGet((texKey:gsub("Texture$", "Color")))()
					ov:SetVertexColor(orr, og, ob, Val(texKey:gsub("Texture$", "Alpha")) or 1)
				end
				ov:Show()
			else
				ov:Hide()
			end
			LayoutEdges(edges, bar, 1, 0, 0, 0, 1)
		end)
	end
	MiniPreview("Target Preview", "target", "targetColorEnabled", false, "targetOverlayTexture")
	MiniPreview("Focus Preview", "focus", "focusColorEnabled", true, "focusOverlayTexture")

	TexDrop(p, "Hover Texture", "Uses the Hover Effect color and opacity. Set to None for the flat hover highlight.",
		"hoverOverlayTexture", HoverItems)
	p:Cog("Hover Texture", {
		{ type = "toggle", label = "Full alpha on empty part of bar", get = On("hoverOverlayFullBgAlpha"), set = Set("hoverOverlayFullBgAlpha") },
	}, { disabled = function() return (Val("hoverOverlayTexture") or "none") == "none" end,
		disabledTip = "This option requires a Hover Texture to be selected" })
	FxSelect("Hover Effect", HOVER_FX)
	Swatch(p, "Glow Color", "hoverGlowColor", { fallback = "targetGlowColor", disabled = function() return not HVEui() end })
	Swatch(p, "Border Color", "hoverBorderColor", { fallback = "targetBorderColor", disabled = function() return not HVBorderColor() end })
	p:Cog("More Effects", {
		{ type = "color", label = "Highlight Color", get = CGet("hoverColor"), set = CSet("hoverColor") },
		{ type = "slider", label = "Highlight Opacity", min = 0, max = 100, get = GetPct("hoverAlpha", 0.3), set = SetPct("hoverAlpha") },
		{ type = "slider", label = "Glow Opacity", min = 0, max = 100, get = GetPct("hoverGlowAlpha", 1, "targetGlowAlpha"), set = SetPct("hoverGlowAlpha") },
		{ type = "slider", label = "Border Size", min = 0, max = 4,
		  get = function() return DB().hoverBorderSizeValue or CurrentBorderSize() end, set = Set("hoverBorderSizeValue"),
		  disabled = function() return not HVBorderSize() end },
	}, { disabled = function() return not (HVHighlight() or HVEui() or HVBorderSize()) end,
		disabledTip = "This option requires a Hover Effect to be selected" })

	-------------------------------------------------------------------
	p:Section("General Text")
	local function DurationRow(label, k)
		p:Dropdown(label, nil, function() return Items(TIMER_POS) end,
			function() return Val(k .. "TimerPosition") or Val("auraTextPosition") or "topleft" end,
			function() return LabelOf(TIMER_POS, Val(k .. "TimerPosition") or Val("auraTextPosition") or "topleft") end,
			Set(k .. "TimerPosition"))
		Swatch(p, label .. " Color", k .. "DurationTextColor", { fallback = "auraDurationTextColor" })
		local function G(suffix, fb)
			return function()
				local v = Val(k .. "DurationText" .. suffix)
				if v == nil then v = Val("auraDurationText" .. suffix) end
				if v == nil then v = fb end
				return v
			end
		end
		p:Cog(label .. " Settings", {
			{ type = "slider", label = "Size", min = 6, max = 20, get = G("Size", 11), set = Set(k .. "DurationTextSize") },
			{ type = "slider", label = "X Offset", min = -50, max = 50, get = G("X", 0), set = Set(k .. "DurationTextX") },
			{ type = "slider", label = "Y Offset", min = -50, max = 50, get = G("Y", 0), set = Set(k .. "DurationTextY") },
		}, { icon = "resize" })
	end
	DurationRow("Debuff Duration", "debuff")
	DurationRow("Buff Duration", "buff")
	DurationRow("CC Duration", "cc")
	Drop(p, "Aura Stacks", nil, TIMER_POS, "auraStackTextPosition", "bottomright")
	Swatch(p, "Aura Stacks Color", "auraStackTextColor")
	p:Cog("Aura Stacks Settings", {
		{ type = "slider", label = "Size", min = 6, max = 20, get = Get("auraStackTextSize", 11), set = Set("auraStackTextSize") },
		{ type = "slider", label = "X Offset", min = -50, max = 50, get = Get("auraStackTextX", 0), set = Set("auraStackTextX") },
		{ type = "slider", label = "Y Offset", min = -50, max = 50, get = Get("auraStackTextY", 0), set = Set("auraStackTextY") },
	}, { icon = "resize" })

	-- Spell name and target cannot share a side (the other one is bumped to None).
	local function CastSide(key, otherKey)
		return function(v)
			DB()[key] = v
			if v ~= "none" and Val(otherKey) == v then
				DB()[otherKey] = "none"
			end
		end
	end
	Drop(p, "Spell Name", nil, CAST_SIDES, "castNameSide", "left", nil, function(v)
		if v ~= "none" and Val("castTargetSide") == v then DB().castTargetSide = "none" end
	end)
	Swatch(p, "Spell Name Color", "castNameColor")
	p:Cog("Spell Name Settings", {
		{ type = "slider", label = "Size", min = 6, max = 20, get = Get("castNameSize", 10), set = Set("castNameSize") },
		{ type = "slider", label = "X Offset", min = -300, max = 300, get = Get("castNameOffsetX", 0), set = Set("castNameOffsetX") },
		{ type = "slider", label = "Y Offset", min = -300, max = 300, get = Get("castNameOffsetY", 0), set = Set("castNameOffsetY") },
		{ type = "slider", label = "Width %", min = 10, max = 150,
		  tip = "Maximum width the text can fill before it truncates, as a percentage of the bar.",
		  get = Get("castNameWidthPct", 42), set = Set("castNameWidthPct") },
		{ type = "toggle", label = "Wrap", tip = "Lets long text wrap onto a second line instead of being cut off.",
		  get = On("castNameWrap"), set = Set("castNameWrap") },
		{ type = "toggle", label = "Combine Spell Name and Target", get = On("castCombineNameTarget"), set = Set("castCombineNameTarget") },
	}, { icon = "resize" })
	local combined = On("castCombineNameTarget")
	p:Dropdown("Spell Target", "This option requires Combine Spell Name and Target to be disabled.",
		function() return Items(CAST_SIDES) end,
		Get("castTargetSide", "right"),
		function() return LabelOf(CAST_SIDES, Val("castTargetSide") or "right") end,
		CastSide("castTargetSide", "castNameSide"), nil, combined)
	p:Swatch("Class Color", PlayerClassColor, function() end, {
		readonly = true,
		active = On("castTargetClassColor", true),
		onClick = function()
			DB().castTargetClassColor = true
			return true
		end,
	})
	p:Swatch("Custom Color", CGet("castTargetColor"), CSet("castTargetColor"), {
		active = Off("castTargetClassColor", true),
		onClick = function()
			if Val("castTargetClassColor") then
				DB().castTargetClassColor = false
				return true
			end
		end,
	})
	p:Cog("Spell Target Settings", {
		{ type = "slider", label = "Size", min = 6, max = 20, get = Get("castTargetSize", 10), set = Set("castTargetSize") },
		{ type = "slider", label = "X Offset", min = -300, max = 300, get = Get("castTargetOffsetX", 0), set = Set("castTargetOffsetX") },
		{ type = "slider", label = "Y Offset", min = -300, max = 300, get = Get("castTargetOffsetY", 0), set = Set("castTargetOffsetY") },
		{ type = "slider", label = "Width %", min = 10, max = 150,
		  tip = "Maximum width the text can fill before it truncates, as a percentage of the bar.",
		  get = Get("castTargetWidthPct", 42), set = Set("castTargetWidthPct") },
		{ type = "toggle", label = "Wrap", tip = "Lets long text wrap onto a second line instead of being cut off.",
		  get = On("castTargetWrap"), set = Set("castTargetWrap") },
	}, { icon = "resize" })
end

---------------------------------------------------------------------------
-- Colors page
---------------------------------------------------------------------------
local function BuildColors(p)
	ElvUINote(p)
	local function ThreatNever() return (Val("threatColorMode") or "instances") == "never" end

	-------------------------------------------------------------------
	p:Section("Enemy Colors")
	p:Label("Enemy Types")
	Swatch(p, "Bosses", "boss")
	Swatch(p, "Mini-Bosses", "miniboss")
	Swatch(p, "Spell Casters", "caster")
	Swatch(p, "Enemies", "enemyInCombat")
	p:Cog("Enemy Colors", {
		{ type = "toggle", label = "Simple Coloring When Not In M+", get = On("owBasicColoring"), set = Set("owBasicColoring") },
		{ type = "color", label = "All Enemies", get = CGet("owBasicColor"), set = CSet("owBasicColor"),
		  disabled = Off("owBasicColoring") },
	})
	local OOC = { { "none", "No Change" }, { "darken", "Darken" }, { "color", "Change Color" } }
	local function OOCMode()
		if not Val("darkenEnemiesOOC") then return "none" end
		if Val("darkenOOCRecolor") then return "color" end
		return "darken"
	end
	p:Dropdown("Modify Out of Combat", "How enemy plates look while out of combat.",
		function() return Items(OOC) end, OOCMode,
		function() return LabelOf(OOC, OOCMode()) end,
		function(v)
			DB().darkenEnemiesOOC = v ~= "none"
			DB().darkenOOCRecolor = v == "color"
		end)
	Swatch(p, "Out of Combat Color", "darkenOOCColor", { disabled = function() return OOCMode() ~= "color" end })

	p:Label("Neutral & Mini Enemies")
	Swatch(p, "Mini Enemies", "miniEnemy", { fallback = "enemyInCombat" })
	Swatch(p, "Neutral", "neutral")
	p:Cog("Mini Enemies", {
		{ type = "toggle", label = "Mini Coloring M+ Only", get = On("miniColoringMPlusOnly"), set = Set("miniColoringMPlusOnly") },
	})
	p:Toggle("Enable Quest Mob Color", "Colors enemy nameplates for quest mobs you still need to kill.",
		On("questMobColorEnabled"), Set("questMobColorEnabled"))
	Swatch(p, "Quest Mob Color", "questMobColor", { disabled = Off("questMobColorEnabled") })

	-------------------------------------------------------------------
	p:Section("Threat Colors")
	Drop(p, "Show Threat Colors", "Where nameplates use the threat colors below. Instances covers dungeons, raids and delves.",
		{ { "never", "Never" }, { "instances", "Instances" }, { "always", "Always" } }, "threatColorMode", "instances")
	p:Label("Tank Threat", nil, ThreatNever)
	Swatch(p, "No Aggro", "tankNoAggro")
	Swatch(p, "Losing Aggro", "tankLosingAggro")

	p:Label("Non-Tank Threat", nil, ThreatNever)
	Swatch(p, "Near Aggro", "dpsNearAggro")
	Swatch(p, "Has Aggro", "dpsHasAggro")
	p:Cog("Near Aggro", {
		{ type = "toggle", label = "Glow Nameplate When Near Aggro",
		  tip = "Adds a steady red glow around the nameplate while the Near Aggro color is active.",
		  get = On("threatNearAggroGlow"), set = Set("threatNearAggroGlow") },
	})
	p:Toggle("DPS: Show Special \"No Aggro\" Color",
		"Shows a special color for non caster/mini-boss enemies when you do not have aggro on them.",
		On("dpsNoAggroEnabled"), Set("dpsNoAggroEnabled"), ThreatNever)
	Swatch(p, "No Aggro", "dpsNoAggro", { disabled = Off("dpsNoAggroEnabled") })
	p:Cog("No Aggro", {
		{ type = "toggle", label = "Override Mini-Boss colors", get = On("dpsNoAggroOverrideMiniBoss"), set = Set("dpsNoAggroOverrideMiniBoss") },
		{ type = "toggle", label = "Override Caster colors", get = On("dpsNoAggroOverrideCaster"), set = Set("dpsNoAggroOverrideCaster") },
		{ type = "toggle", label = "Override Boss colors", get = On("dpsNoAggroOverrideBoss", true), set = Set("dpsNoAggroOverrideBoss") },
	}, { disabled = function() return Val("dpsNoAggroEnabled") ~= true or Val("threatColorHealth") == false end,
		disabledTip = "This option requires the special No Aggro color and Health Bar in Show Threat On" })

	p:Toggle("Classic Tank Aggro",
		"Enables a three-tier tank aggro system: has aggro, losing aggro, and no aggro colors override all mob-type colors.",
		On("classicTankAggro"), Set("classicTankAggro"), ThreatNever)
	Swatch(p, "Has Aggro", "tankHasAggro", { disabled = Off("classicTankAggro") })
	p:Toggle("Tank: Show Special \"Has Aggro\" Color",
		"Shows a special color for non caster/mini-boss enemies when you have aggro on them.",
		On("tankHasAggroEnabled"), Set("tankHasAggroEnabled"), ThreatNever)
	Swatch(p, "Has Aggro", "tankHasAggro", { disabled = Off("tankHasAggroEnabled") })
	p:Cog("Has Aggro", {
		{ type = "toggle", label = "Override Mini-Boss and Caster colors", get = On("tankHasAggroOverrideMobType"), set = Set("tankHasAggroOverrideMobType") },
		{ type = "toggle", label = "Override Boss colors", get = On("tankHasAggroOverrideBoss", true), set = Set("tankHasAggroOverrideBoss") },
	})

	p:Toggle("Tank: Show Special \"Off-Tank\" Color",
		"Shows a special color for nameplates that another tank in your raid has aggro on.",
		On("offTankAggroEnabled", true), Set("offTankAggroEnabled"), ThreatNever)
	Swatch(p, "Off-Tank", "offTankAggro", { disabled = Off("offTankAggroEnabled", true) })
	local THREAT_ON = {
		{ id = "health", name = "Health Bar", key = "threatColorHealth", default = true },
		{ id = "border", name = "Border", key = "threatColorBorder", default = false },
		{ id = "name", name = "Name", key = "threatColorName", default = false },
	}
	local function ThreatOn(e)
		local v = Val(e.key)
		if v == nil then return e.default end
		return v == true
	end
	local function FindThreat(id)
		for _, e in ipairs(THREAT_ON) do
			if e.id == id then return e end
		end
	end
	p:MultiSelect("Show Threat On",
		"Chooses which parts of the nameplate show the threat colors; with Health Bar off, the bar keeps its Enemy Types color.",
		function()
			local items = {}
			for _, e in ipairs(THREAT_ON) do
				local item = { value = e.id, name = e.name }
				if e.id == "border" then
					item.locked = function() return BorderMode() == "none" end
					item.lockedTip = "This option requires a Border to be selected"
				end
				items[#items + 1] = item
			end
			return items
		end,
		function(id) return ThreatOn(FindThreat(id)) end,
		function(id)
			local e = FindThreat(id)
			DB()[e.key] = not ThreatOn(e)
		end,
		function()
			local names = {}
			for _, e in ipairs(THREAT_ON) do
				if ThreatOn(e) then names[#names + 1] = e.name end
			end
			if #names == 0 then return "None" end
			return table.concat(names, ", ")
		end, ThreatNever)
end

---------------------------------------------------------------------------
-- General page
---------------------------------------------------------------------------
local function BuildGeneral(p)
	ElvUINote(p)
	local friendlyOff = Off("showFriendlyPlayers", true)
	local nameOnly = On("friendlyNameOnly", true)

	-------------------------------------------------------------------
	p:Section("Other Nameplates")
	p:Toggle("Show EUI Friendly Player Nameplates",
		"When disabled, EUI relinquishes full control of friendly player nameplates to Blizzard. Use Blizzard's own Nameplate settings (Esc > Options > Nameplates) to control them.",
		On("showFriendlyPlayers", true), Set("showFriendlyPlayers"))
	p:Cog("Friendly Nameplate Settings", {
		{ type = "slider", label = "Distance", min = -50, max = 50, get = Get("friendlyPlateYOffset", 0), set = Set("friendlyPlateYOffset") },
		{ type = "slider", label = "Height", min = 6, max = 40, get = Get("friendlyHealthBarHeight", 17), set = Set("friendlyHealthBarHeight") },
		{ type = "slider", label = "Width", min = 80, max = 250, get = Get("friendlyHealthBarWidth", 150), set = Set("friendlyHealthBarWidth") },
		{ type = "toggle", label = "Class Colored Health Bar", get = On("classColorFriendly", true), set = Set("classColorFriendly") },
		{ type = "toggle", label = "Class Colored Names", get = On("friendlyNameClassColor"), set = Set("friendlyNameClassColor") },
		{ type = "toggle", label = "Target Border Effects",
		  tip = "Also applies the target Border Color and Border Size effects to friendly nameplates.",
		  get = On("friendlyTargetBorderFx"), set = Set("friendlyTargetBorderFx"),
		  disabled = function() return not (TGBorderColor() or TGBorderSize()) end },
	}, { disabled = function() return friendlyOff() or nameOnly() end, disabledTip = "Requires Name Only setting to be disabled" })
	p:Toggle("Make Friendly Nameplates Name Only",
		"Hide friendly player health bars and instead only see their names.",
		nameOnly, Set("friendlyNameOnly"), friendlyOff)
	p:Swatch("Class Color", PlayerClassColor, function() end, {
		readonly = true,
		active = On("classColorFriendly", true),
		disabled = function() return not nameOnly() end,
		onClick = function()
			DB().classColorFriendly = true
			return true
		end,
	})
	p:Swatch("White", function() return 1, 1, 1, 1 end, function() end, {
		readonly = true,
		active = Off("classColorFriendly", true),
		disabled = function() return not nameOnly() end,
		onClick = function()
			DB().classColorFriendly = false
			return true
		end,
	})

	local npcOff = Off("showFriendlyNPCs")
	p:Toggle("Show Friendly NPC Nameplates", nil, On("showFriendlyNPCs"), Set("showFriendlyNPCs"))
	Swatch(p, "NPC Bar & Name Color", "friendlyNPCColor", { disabled = function() return npcOff() or nameOnly() end })
	p:Cog("Friendly NPC Settings", {
		{ type = "slider", label = "Name Size", min = 6, max = 30, get = Get("friendlyNPCNameSize", 13), set = Set("friendlyNPCNameSize") },
		{ type = "color", label = "Name Color", get = CGet("friendlyNPCNameColor"), set = CSet("friendlyNPCNameColor") },
	}, { disabled = function() return npcOff() or not nameOnly() end,
		disabledTip = "Requires Show Friendly NPC Nameplates and Name Only mode to be enabled" })
	p:Slider("Friendly Name Size", "Adjusts the size of friendly player names shown in Name Only mode. Default is 15.",
		8, 30, 1, Get("friendlyNameSize", 15), Set("friendlyNameSize"), function() return not nameOnly() end)
	p:Cog("Name Distance", {
		{ type = "slider", label = "Distance", min = -50, max = 50, get = Get("friendlyNameOnlyYOffset", -20), set = Set("friendlyNameOnlyYOffset") },
	}, { icon = "directions", disabled = function() return not nameOnly() end })

	p:Toggle("Friendly Names Not Clickable",
		"Make friendly player and NPC nameplates click-through so their names never block your mouse or cause accidental friendly targeting.\n\nUse this when friendly names get in the way of clicking the world or the enemy nameplates behind them.\n\nIn Mists this works only when Enemy nameplate stacking is off.",
		On("friendlyClickThrough"), Set("friendlyClickThrough"))
	p:Toggle("Show Enemy Pet Nameplates", "Toggle visibility of enemy pet nameplates.", On("showEnemyPets"), Set("showEnemyPets"))

	-------------------------------------------------------------------
	p:Section("Nameplate Spacing")
	p:MultiSelect("Stacking Nameplates", "Choose which nameplates stack vertically instead of overlapping. In Mists one setting stacks all plates: with Enemy stacking on, friendly plates stack too.",
		function() return {
			{ value = "enemy", name = "Enemy Nameplates" },
			{ value = "friendly", name = "Friendly Nameplates" },
		} end,
		function(k)
			if k == "friendly" then return Val("stackingFriendly") == true end
			return Val("stackingEnabled") ~= false
		end,
		function(k)
			if k == "friendly" then
				DB().stackingFriendly = Val("stackingFriendly") ~= true
			else
				DB().stackingEnabled = Val("stackingEnabled") == false
			end
		end,
		function()
			local e, f = Val("stackingEnabled") ~= false, Val("stackingFriendly") == true
			if e and f then return "Enemy, Friendly" end
			if e then return "Enemy Nameplates" end
			if f then return "Friendly Nameplates" end
			return "None"
		end)
	p:Blank()
	p:Slider("Hitbox Size X",
		"Widens the clickable hitbox of enemy nameplates. 100% = matches bar width. Increase to make nameplates easier to click.",
		50, 250, 5, Get("hitboxScaleX", 100), Set("hitboxScaleX"))
	p:Slider("Hitbox Size Y",
		"Increases the clickable hitbox height of enemy nameplates. 100% = matches bar height. Increase to make nameplates easier to click.",
		50, 250, 5, Get("hitboxScaleY", 100), Set("hitboxScaleY"))

	-------------------------------------------------------------------
	p:Section("Extra Aura Options")
	p:Slider("Max Debuffs", "Maximum number of debuff icons shown on enemy nameplates.", 1, 10, 1, Get("maxDebuffs", 5), Set("maxDebuffs"))
	p:Blank()
	Drop(p, "Enemy Buff Filter",
		"Which enemy buffs show on nameplates. Important shows the buffs Blizzard flags for enemy nameplates plus anything dispellable; Only Dispellable shows just the buffs that can be dispelled, purged or soothed; Show All shows every buff. With a Dispel Glow style set, every dispellable buff shown glows.",
		{ { "important", "Important" }, { "dispellable", "Only Dispellable" }, { "showall", "Show All" } }, "npEnemyBuffFilter", "important")
	local GLOW_STYLES = { { 0, "None" }, { 1, "Pixel Glow" } }
	local function GlowStyle()
		if Val("dispelGlow") ~= true then return 0 end
		return 1
	end
	p:Dropdown("Dispel Glow Style", nil, function() return Items(GLOW_STYLES) end, GlowStyle,
		function() return LabelOf(GLOW_STYLES, GlowStyle()) end,
		function(v)
			if v == 0 then
				DB().dispelGlow = false
				return
			end
			if Val("dispelGlow") == true then
				DB().dispelGlowStyle = v
				return
			end
			ns.ShowConfirmPopup({
				title = "Dispel Glow",
				message = "Dispel Glow may cause a slight loss in performance efficiency. Do you want to enable it?",
				confirmText = "Enable",
				cancelText = "Cancel",
				onConfirm = function()
					DB().dispelGlow = true
					DB().dispelGlowStyle = v
					RunApplyHooks()
					if ns.RefreshAllPages then ns.RefreshAllPages() end
				end,
			})
		end)
	Swatch(p, "Glow Color", "dispelGlowColor", { disabled = function() return Val("dispelGlow") ~= true end })

	-------------------------------------------------------------------
	p:Section("Target and Focus Effects")
	p:Toggle("Show Hash Line on Target at Percent", nil, On("hashLineEnabled"), Set("hashLineEnabled"))
	Swatch(p, "Hash Line Color", "hashLineColor", { disabled = Off("hashLineEnabled") })
	p:Slider("Hash Line Location (Percent)", nil, 0, 100, 1, Get("hashLinePercent", 30), Set("hashLinePercent"), Off("hashLineEnabled"))
	p:Slider("Scale Target Nameplate (Percent)", "Scales your current target's nameplate. 100% = no change.",
		50, 200, 5, Get("targetScale", 100), Set("targetScale"))
	p:Slider("Non-Target Opacity",
		"Fades enemy nameplates that are not your current target or focus while you have a target. 100 = no fading.",
		0, 100, 1, Get("nonTargetAlpha", 100), Set("nonTargetAlpha"))
	p:Cog("Non-Target Opacity", {
		{ type = "toggle", label = "Keep Focus Full Opacity",
		  tip = "Your focus target's nameplate never fades with the non-target opacity.",
		  get = On("nonTargetKeepFocus", true), set = Set("nonTargetKeepFocus") },
	}, { disabled = function() return (Val("nonTargetAlpha") or 100) >= 100 end,
		disabledTip = "This option requires Non-Target Opacity to be below 100" })
	p:Toggle("Focus Letter", "Draws a white letter F on your current focus target's nameplate.",
		On("focusLetterEnabled"), Set("focusLetterEnabled"))
	p:Cog("Focus Letter", {
		{ type = "dropdown", label = "Anchor", items = function() return Items(ANCHORS) end,
		  get = Get("focusLetterAnchor", "CENTER"), set = Set("focusLetterAnchor") },
		{ type = "slider", label = "Size", min = 6, max = 40, get = Get("focusLetterSize", 18), set = Set("focusLetterSize") },
		{ type = "slider", label = "X", min = -100, max = 100, get = Get("focusLetterX", 0), set = Set("focusLetterX") },
		{ type = "slider", label = "Y", min = -100, max = 100, get = Get("focusLetterY", 0), set = Set("focusLetterY") },
	}, { icon = "resize", disabled = Off("focusLetterEnabled"), disabledTip = "This option requires Focus Letter to be enabled" })
	p:Blank()

	-------------------------------------------------------------------
	p:Section("Extras")
	p:Slider("Scale Nameplate On Cast (Percent)", "Scales enemy nameplates while they are casting. 100% = no change.",
		50, 200, 5, Get("castScale", 100), Set("castScale"))
	p:Toggle("Hide Enemy Name While Casting", "Hide the enemy name text while that nameplate's cast bar is visible.",
		On("hideEnemyNameWhileCasting"), Set("hideEnemyNameWhileCasting"))
	p:Toggle("Name Raid Marker",
		"Shows the target marker directly before the enemy name text. Uses its own size and does not use the Core Positions raid marker slot.",
		On("nameRaidMarkerEnabled"), Set("nameRaidMarkerEnabled"))
	p:Cog("Name Raid Marker", {
		{ type = "slider", label = "Size", min = 6, max = 32, get = Get("nameRaidMarkerSize", 14), set = Set("nameRaidMarkerSize") },
	}, { icon = "resize", disabled = Off("nameRaidMarkerEnabled"), disabledTip = "This option requires Name Raid Marker to be enabled" })
	p:Toggle("Replace Quest Icon with Objective",
		"On quest mobs in the open world, replaces the quest icon with the objective progress (ex: kill quests show 0/6, percentage objectives show 50%).",
		On("replaceQuestIconWithObjective"), Set("replaceQuestIconWithObjective"))
	p:Cog("Quest Objective", {
		{ type = "slider", label = "Text Size", min = 6, max = 24, get = Get("questObjectiveTextSize", 14), set = Set("questObjectiveTextSize") },
	}, { icon = "resize", disabled = Off("replaceQuestIconWithObjective"),
		disabledTip = "This option requires Replace Quest Icon with Objective to be enabled" })
	p:Toggle("Execute Pulse Glow", "Pulses a red glow on enemy nameplates below 30% health.", On("lowHpGlow"), Set("lowHpGlow"))
	p:Blank()

	-- Added on 5.4.8: the retail Naowh profile again.
	p:WideButton(function() return "Load Naowh Profile" end,
		"Replaces all Nameplates settings with the Naowh profile (the retail profile).",
		function() return false end,
		function()
			ns.ShowConfirmPopup({
				title = "Load Naowh Profile",
				message = "This replaces all your Nameplates settings with the Naowh profile. Do you want to continue?",
				confirmText = "Load",
				cancelText = "Cancel",
				onConfirm = function()
					ENP:ApplyNaowhProfile()
					RunApplyHooks()
					Rebuild()
				end,
			})
		end)
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------
local DESC = "Custom nameplate design and behavior."

ns.RegisterSettingsModule({
	key = "nameplates",
	name = "Nameplates",
	group = "Core Addons",
	tabs = {
		{ key = "display", name = "Display", description = DESC, build = BuildDisplay, header = BuildPreviewHeader, pageKey = PageKey },
		{ key = "colors", name = "Colors", description = DESC, build = BuildColors, pageKey = PageKey },
		{ key = "general", name = "General", description = DESC, build = BuildGeneral, pageKey = PageKey },
	},
	reset = function()
		ENP:ResetProfile()
		Rebuild()
	end,
	resetTip = "Set all Nameplates settings back to the EllesmereUI defaults.",
})
