-------------------------------------------------------------------------------
--  EUI_ActionBars_ButtonArt.lua  (5.4.8 port)
--
--  The EllesmereUI button look (retail EUI_ActionBars_ButtonArt.lua, Pushed.lua,
--  Glows.lua, Range.lua and the font part of Apply.lua): square icon with zoom,
--  1 px pixel border, flat slot background, the square highlight / pushed /
--  checked / flash art in the Bar Interactions color, the keybind / charges /
--  macro text in the EllesmereUI font, cooldown numbers (5.4.8 has none of its
--  own), desaturate / dim on cooldown, out of range coloring, Hide Charge Count
--  at 0, Show Equipped Item Color and the proc glows.
--  Not in 5.4.8 (no mask textures, no swipe color, no textured border
--  backdrops): custom button shapes other than Cropped, CD swipe color,
--  textured border styles, cooldown edge art, assisted highlight.
-------------------------------------------------------------------------------
local addonName, P = ...
local EAB = P.EAB

local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min
local pairs, ipairs = pairs, ipairs
local GetTime = GetTime
local HIGHLIGHT_TEXTURES = P.HIGHLIGHT_TEXTURES

local RANGE_RED = { 1, 0.1, 0.1 }

-------------------------------------------------------------------------------
--  Colors of the Bar Interactions (retail: pushed / highlight custom color or
--  class color)
-------------------------------------------------------------------------------
local function InteractionColor(prefix)
	local p = P.Profile()
	if p[prefix .. "UseClassColor"] then
		local r, g, b = P.ClassColor()
		return r, g, b, 1
	end
	local c = p[prefix .. "CustomColor"] or { r = 0.973, g = 0.839, b = 0.604, a = 1 }
	return c.r or 1, c.g or 1, c.b or 1, c.a or 1
end
P.InteractionColor = InteractionColor

-- Border thickness in pixels (retail ResolveBorderThickness, regular column).
function P.BorderPixels(s)
	local entry = EAB.BORDER_THICKNESS[s.borderThickness or "thin"] or EAB.BORDER_THICKNESS.thin
	if s.borderEnabled == false then
		return 0
	end
	return entry.regular
end

-------------------------------------------------------------------------------
--  Square art (retail MakeButtonSquare): done once per button
-------------------------------------------------------------------------------
local function SquareTexture(tex, path)
	if not tex then
		return
	end
	tex:SetTexture(path)
	tex:SetTexCoord(0, 1, 0, 1)
	tex:ClearAllPoints()
	tex:SetAllPoints(tex:GetParent())
end

function P.StyleButton(btn)
	if btn.eabStyled then
		return
	end
	btn.eabStyled = true
	local name = btn:GetName()
	btn.icon = btn.icon or _G[name .. "Icon"]
	btn.cooldown = btn.cooldown or _G[name .. "Cooldown"]
	btn.HotKey = _G[name .. "HotKey"]
	btn.Count = _G[name .. "Count"]
	btn.Name = _G[name .. "Name"]
	btn.Flash = _G[name .. "Flash"]
	btn.Border = _G[name .. "Border"]
	btn.NormalTex = _G[name .. "NormalTexture"] or btn:GetNormalTexture()
	btn.FlyoutArrow = btn.FlyoutArrow or _G[name .. "FlyoutArrow"]
	btn.FlyoutBorder = btn.FlyoutBorder or _G[name .. "FlyoutBorder"]
	btn.FlyoutBorderShadow = btn.FlyoutBorderShadow or _G[name .. "FlyoutBorderShadow"]

	-- Blizzard's frame art goes (retail HideBorder).
	local nt = btn.NormalTex
	if nt then
		nt:SetTexture(nil)
		nt:SetAlpha(0)
		nt:Hide()
	end
	if btn.FlyoutBorder then btn.FlyoutBorder:SetAlpha(0) end
	if btn.FlyoutBorderShadow then btn.FlyoutBorderShadow:SetAlpha(0) end

	-- Icon fills the button.
	local icon = btn.icon
	if icon then
		icon:ClearAllPoints()
		icon:SetAllPoints(btn)
	end
	if btn.cooldown then
		btn.cooldown:ClearAllPoints()
		btn.cooldown:SetAllPoints(btn)
	end

	-- Square interaction art.
	SquareTexture(btn:GetHighlightTexture(), HIGHLIGHT_TEXTURES[1])
	SquareTexture(btn:GetPushedTexture(), HIGHLIGHT_TEXTURES[2])
	SquareTexture(btn:GetCheckedTexture(), HIGHLIGHT_TEXTURES[1])
	SquareTexture(btn.Flash, HIGHLIGHT_TEXTURES[1])
	if btn.Border then
		btn.Border:SetBlendMode("BLEND")
		SquareTexture(btn.Border, HIGHLIGHT_TEXTURES[1])
		btn.Border:Hide()
	end

	-- Flat slot background behind the icon (retail fd.slotBG).
	local bg = btn:CreateTexture(nil, "BACKGROUND", nil, -1)
	bg:SetAllPoints(btn)
	btn.slotBG = bg

	-- Blizzard Icon Background (empty slot art; off by default).
	local ibg = btn:CreateTexture(nil, "BACKGROUND", nil, -2)
	ibg:SetTexture("Interface\\Buttons\\UI-Quickslot")
	ibg:SetTexCoord(0.2, 0.8, 0.2, 0.8)
	ibg:SetAllPoints(btn)
	ibg:Hide()
	btn.iconBG = ibg

	-- Text above the cooldown swipe, proc glows (+5) and a border above effects (+6).
	local textHost = CreateFrame("Frame", nil, btn)
	textHost:SetAllPoints(btn)
	textHost:SetFrameLevel(btn:GetFrameLevel() + 7)
	btn.textHost = textHost
	for _, key in ipairs({ "HotKey", "Count", "Name" }) do
		local fs = btn[key]
		if fs then
			fs:SetParent(textHost)
			fs:SetDrawLayer("OVERLAY", 1)
		end
	end
	if btn.FlyoutArrow then
		btn.FlyoutArrow:SetParent(textHost)
		btn.FlyoutArrow:SetDrawLayer("OVERLAY", 2)
	end

	-- Pixel border (above the icon, under the text).
	local borderHost = CreateFrame("Frame", nil, btn)
	borderHost:SetAllPoints(btn)
	borderHost:SetFrameLevel(btn:GetFrameLevel() + 2)
	btn.borderHost = borderHost
	btn.edges = P.CreateEdges(borderHost, btn, "OVERLAY", 2)

	-- Cooldown numbers.
	local cdHost = CreateFrame("Frame", nil, btn)
	cdHost:SetAllPoints(btn)
	cdHost:SetFrameLevel(btn:GetFrameLevel() + 3)
	local cdText = cdHost:CreateFontString(nil, "OVERLAY")
	P.SetIconFont(cdText, 12)
	cdText:SetPoint("CENTER", cdHost, "CENTER", 0, 0)
	btn.cdHost = cdHost
	btn.cdText = cdText

	-- Pushed art shown while a bound key is held (P.SetKeyPushed).
	local kp = textHost:CreateTexture(nil, "ARTWORK", nil, 1)
	kp:SetAllPoints(btn)
	kp:Hide()
	btn.keyPushTex = kp

	-- Border-type pushed / highlight (retail _setupBorderEdges).
	btn.pushEdges = P.CreateEdges(textHost, btn, "OVERLAY", 3)
	btn.hlEdges = P.CreateEdges(textHost, btn, "OVERLAY", 3)
	P.ShowEdges(btn.pushEdges, false)
	P.ShowEdges(btn.hlEdges, false)
	btn:HookScript("OnMouseDown", function(self)
		if self.pushEdgesOn then P.ShowEdges(self.pushEdges, true) end
	end)
	btn:HookScript("OnMouseUp", function(self)
		P.ShowEdges(self.pushEdges, false)
	end)
	btn:HookScript("OnHide", function(self)
		P.ShowEdges(self.pushEdges, false)
	end)
	btn:HookScript("OnEnter", function(self)
		if self.hlEdgesOn then P.ShowEdges(self.hlEdges, true) end
	end)
	btn:HookScript("OnLeave", function(self)
		P.ShowEdges(self.hlEdges, false)
	end)
end

-- Key press look: a key binding clicks the button without the engine's
-- pushed state, so a copy of the pushed art shows while the key is held
-- (retail Pushed-State Flash). Our own texture: nothing protected is touched.
function P.SetKeyPushed(btn, down)
	local t = btn.keyPushTex
	if down then
		if t and btn.keyPushOn then t:Show() end
		if btn.pushEdgesOn then P.ShowEdges(btn.pushEdges, true) end
	else
		if t then t:Hide() end
		P.ShowEdges(btn.pushEdges, false)
	end
end

-------------------------------------------------------------------------------
--  Per bar art: border, zoom, slot background, interactions, text
-------------------------------------------------------------------------------
-- Button text anchors (retail EAB.PlaceButtonText).
EAB.TEXT_ANCHOR_ORDER = { "TOPLEFT", "TOP", "TOPRIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
EAB.TEXT_ANCHOR_JUSTIFY = {
	TOPLEFT = "LEFT", TOP = "CENTER", TOPRIGHT = "RIGHT",
	BOTTOMLEFT = "LEFT", BOTTOM = "CENTER", BOTTOMRIGHT = "RIGHT",
}
EAB.TEXT_INSET_X = 1
EAB.TEXT_INSET_Y = { keybind = 3, count = 4, macro = 4 }

function EAB.StockTextOffsets(kind, anchor)
	if not EAB.TEXT_ANCHOR_JUSTIFY[anchor] then
		return 0, 0
	end
	local x = 0
	if anchor:find("LEFT", 1, true) then
		x = EAB.TEXT_INSET_X
	elseif anchor:find("RIGHT", 1, true) then
		x = -EAB.TEXT_INSET_X
	end
	local y = EAB.TEXT_INSET_Y[kind] or 0
	if anchor:find("TOP", 1, true) then
		y = -y
	end
	return x, y
end

function EAB.ApplyShapeTextOffsets(bs, kbX, kbY, ctX, ctY)
	local ax, ay = 0, 0
	if bs.keybindAnchor then ax, ay = EAB.StockTextOffsets("keybind", bs.keybindAnchor) end
	bs.keybindOffsetX, bs.keybindOffsetY = kbX + ax, kbY + ay
	ax, ay = 0, 0
	if bs.countAnchor then ax, ay = EAB.StockTextOffsets("count", bs.countAnchor) end
	bs.countOffsetX, bs.countOffsetY = ctX + ax, ctY + ay
end

local function PlaceText(fs, parent, anchor, ox, oy)
	local justify = anchor and EAB.TEXT_ANCHOR_JUSTIFY[anchor]
	if not justify then
		return false
	end
	local edge = anchor:find("TOP", 1, true) and "TOP" or "BOTTOM"
	fs:ClearAllPoints()
	fs:SetPoint(edge .. "LEFT", parent, edge .. "LEFT", ox or 0, oy or 0)
	fs:SetPoint(edge .. "RIGHT", parent, edge .. "RIGHT", ox or 0, oy or 0)
	fs:SetJustifyH(justify)
	return true
end
EAB.PlaceButtonText = PlaceText

-- Icon texcoords: zoom, Cropped (retail ApplyShapeToButton none / cropped).
local function ApplyIconCoords(btn, s)
	local icon = btn.icon
	if not icon then
		return
	end
	local p = P.Profile()
	local z = (s.iconZoom or p.iconZoom or 5.5) / 100
	if s.buttonShape == "cropped" then
		icon:SetTexCoord(z, 1 - z, z + 0.10, 1 - z - 0.10)
	elseif z > 0 then
		icon:SetTexCoord(z, 1 - z, z, 1 - z)
	else
		icon:SetTexCoord(0, 1, 0, 1)
	end
end
P.ApplyIconCoords = ApplyIconCoords

-- Border size in pixels and color (retail ApplyBordersForBar).
local function ApplyBorder(btn, s)
	local px = P.PixelFor(btn)
	local size = P.BorderPixels(s) * px
	local c = s.borderColor or { r = 0, g = 0, b = 0, a = 1 }
	local r, g, b, a = c.r or 0, c.g or 0, c.b or 0, c.a or 1
	if s.borderClassColor then
		r, g, b = P.ClassColor()
	end
	P.LayoutEdges(btn.edges, size, r, g, b, a)
	btn.borderHost:SetFrameLevel(s.borderBehind and btn:GetFrameLevel() or (btn:GetFrameLevel() + 2))
	if s.borderAboveEffects and not s.borderBehind then
		btn.borderHost:SetFrameLevel(btn:GetFrameLevel() + 6)
	end
end

local function ApplySlotBackground(btn)
	local p = P.Profile()
	local c = p.slotBgColor or { r = 0.15, g = 0.15, b = 0.15 }
	local a = p.slotBgOpacity
	if a == nil then a = 50 end
	btn.slotBG:SetTexture(c.r or 0.15, c.g or 0.15, c.b or 0.15, a / 100)
	btn.iconBG:SetAlpha(p.blizzIconBgAlpha or 1)
end

-- Pushed / highlight / checked art (retail ApplyPushedTextures,
-- ApplyHighlightTextures, ApplyCheckedTextures).
local function ApplyInteractions(btn)
	local p = P.Profile()
	local px = P.PixelFor(btn)

	local pt = btn:GetPushedTexture()
	local kp = btn.keyPushTex
	local pType = p.pushedTextureType or 2
	local pr, pg, pb = InteractionColor("pushed")
	btn.pushEdgesOn = nil
	btn.keyPushOn = nil
	if pt then
		if pType == 6 then
			pt:SetAlpha(0)
		elseif pType == 5 then
			pt:SetAlpha(0)
			btn.pushEdgesOn = true
			P.LayoutEdges(btn.pushEdges, (p.pushedBorderSize or 4) * px, pr, pg, pb, 1)
			P.ShowEdges(btn.pushEdges, false)
		elseif pType == 4 then
			pt:SetTexture(pr, pg, pb, 0.35)
			pt:SetVertexColor(1, 1, 1, 1)
			pt:SetAlpha(1)
			if kp then
				kp:SetTexture(pr, pg, pb, 0.35)
				kp:SetVertexColor(1, 1, 1, 1)
				btn.keyPushOn = true
			end
		else
			SquareTexture(pt, HIGHLIGHT_TEXTURES[pType] or HIGHLIGHT_TEXTURES[2])
			pt:SetVertexColor(pr, pg, pb, 1)
			pt:SetAlpha(1)
			if kp then
				kp:SetTexture(HIGHLIGHT_TEXTURES[pType] or HIGHLIGHT_TEXTURES[2])
				kp:SetTexCoord(0, 1, 0, 1)
				kp:SetVertexColor(pr, pg, pb, 1)
				btn.keyPushOn = true
			end
		end
	end

	local ht = btn:GetHighlightTexture()
	local hType = p.highlightTextureType or 2
	local hr, hg, hb = InteractionColor("highlight")
	btn.hlEdgesOn = nil
	if ht then
		if hType == 6 then
			ht:SetAlpha(0)
		elseif hType == 5 then
			ht:SetAlpha(0)
			btn.hlEdgesOn = true
			P.LayoutEdges(btn.hlEdges, (p.highlightBorderSize or 4) * px, hr, hg, hb, 1)
			P.ShowEdges(btn.hlEdges, false)
		elseif hType == 4 then
			ht:SetTexture(hr, hg, hb, 0.35)
			ht:SetVertexColor(1, 1, 1, 1)
			ht:SetBlendMode("BLEND")
			ht:SetAlpha(1)
		else
			SquareTexture(ht, HIGHLIGHT_TEXTURES[hType] or HIGHLIGHT_TEXTURES[1])
			ht:SetBlendMode("BLEND")
			ht:SetVertexColor(hr, hg, hb, 1)
			ht:SetAlpha(1)
		end
	end

	local ct = btn:GetCheckedTexture()
	if ct then
		ct:SetAlpha(p.showCastHighlight == false and 0 or 1)
	end
end
P.ApplyInteractions = ApplyInteractions

-- Text: keybind, charges, macro name (retail ApplyFontsForBar).
local function ApplyFonts(btn, s, info)
	local small = info.isStance or info.isPetBar
	local hk, ct, nm = btn.HotKey, btn.Count, btn.Name
	local host = btn.textHost
	if hk then
		local size = s.keybindFontSize or 12
		if small then size = max(size - 2, 6) end
		P.SetIconFont(hk, size)
		hk:SetHeight(size + 4)
		local kbX, kbY = s.keybindOffsetX or 0, s.keybindOffsetY or 0
		if not (s.keybindAnchor and PlaceText(hk, host, s.keybindAnchor, kbX, kbY)) then
			hk:ClearAllPoints()
			hk:SetPoint("TOPRIGHT", host, "TOPRIGHT", -1 + kbX, -3 + kbY)
			hk:SetPoint("TOPLEFT", host, "TOPLEFT", 4 + kbX, -3 + kbY)
			hk:SetJustifyH("RIGHT")
		end
	end
	if ct then
		local size = s.countFontSize or 12
		P.SetIconFont(ct, size)
		local c = s.countFontColor or { r = 1, g = 1, b = 1 }
		ct:SetTextColor(c.r or 1, c.g or 1, c.b or 1)
		local ox, oy = s.countOffsetX or 0, s.countOffsetY or 0
		if not (s.countAnchor and PlaceText(ct, host, s.countAnchor, ox, oy)) then
			ct:ClearAllPoints()
			ct:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -1 + ox, 4 + oy)
			ct:SetJustifyH("RIGHT")
		end
	end
	if nm then
		if s.hideMacroText then
			nm:SetAlpha(0)
		else
			nm:SetAlpha(1)
			local size = s.macroFontSize or 12
			if small then size = max(size - 2, 6) end
			nm:SetFont(P.FontPath(), size, "OUTLINE")
			nm:SetShadowOffset(0, 0)
			nm:SetHeight(size + 4)
			local c = s.macroFontColor or { r = 1, g = 1, b = 1 }
			nm:SetTextColor(c.r or 1, c.g or 1, c.b or 1)
			local ox, oy = s.macroOffsetX or 0, s.macroOffsetY or 0
			if not (s.macroAnchor and PlaceText(nm, host, s.macroAnchor, ox, oy)) then
				nm:ClearAllPoints()
				nm:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 1 + ox, 4 + oy)
				nm:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -1 + ox, 4 + oy)
				nm:SetJustifyH("CENTER")
			end
		end
	end
	-- Cooldown numbers (retail CooldownFonts.ApplyToFrame).
	local cdt = btn.cdText
	if cdt then
		local size = s.cooldownFontSize or 12
		if s.cooldownFontFit then
			local w, h = btn:GetWidth() or 36, btn:GetHeight() or 36
			local cap = max(5, floor(min(w, h) * 0.40))
			if size > cap then size = cap end
		end
		P.SetIconFont(cdt, size)
		local c = s.cooldownTextColor or { r = 1, g = 1, b = 1 }
		cdt:SetTextColor(c.r or 1, c.g or 1, c.b or 1)
		cdt:ClearAllPoints()
		cdt:SetPoint("CENTER", btn.cdHost, "CENTER", s.cooldownTextXOffset or 0, s.cooldownTextYOffset or 0)
	end
end

-- Everything of a bar's look on one button.
function P.ApplyButtonArt(btn, s, info)
	P.StyleButton(btn)
	ApplyIconCoords(btn, s)
	ApplyBorder(btn, s)
	ApplySlotBackground(btn)
	ApplyInteractions(btn)
	ApplyFonts(btn, s, info)
	if btn.cooldown then
		-- CD Swipe Opacity: 80 (the default) is Blizzard's own swipe.
		btn.cooldown:SetAlpha(min(1, (P.Profile().cdSwipeAlpha or 80) / 80))
	end
	P.UpdateHotkey(btn)
end

-------------------------------------------------------------------------------
--  Keybind text and its color (white, red while out of range like retail)
-------------------------------------------------------------------------------
function P.UpdateHotkey(btn)
	local hk = btn.HotKey
	if not hk then
		return
	end
	local s = P.BarSettings(btn.barKey)
	if not s or s.hideKeybind then
		hk:SetText("")
		hk:Hide()
		return
	end
	local cmd = btn.bindCommand
	local key = cmd and GetBindingKey(cmd)
	local text = key and P.FormatHotkey(key) or ""
	hk:SetText(text)
	hk:Show()
	P.UpdateHotkeyColor(btn)
end

function P.UpdateHotkeyColor(btn)
	local hk = btn.HotKey
	if not hk then
		return
	end
	if btn.outOfRange then
		hk:SetTextColor(RANGE_RED[1], RANGE_RED[2], RANGE_RED[3])
		return
	end
	local s = P.BarSettings(btn.barKey)
	local c = s and s.keybindFontColor or { r = 1, g = 1, b = 1 }
	hk:SetTextColor(c.r or 1, c.g or 1, c.b or 1)
end

-------------------------------------------------------------------------------
--  Usable color, range tint (retail ApplyRangeTint), desaturate / dim on CD
-------------------------------------------------------------------------------
function P.UpdateUsable(btn)
	local icon = btn.icon
	if not icon then
		return
	end
	local s = P.BarSettings(btn.barKey)
	if btn.outOfRange and s and s.outOfRangeColoring then
		local c = s.outOfRangeColor or { r = 0.8, g = 0.1, b = 0.1 }
		icon:SetVertexColor(c.r or 0.8, c.g or 0.1, c.b or 0.1)
		return
	end
	local isUsable, notEnoughMana = btn:IsUsable()
	if isUsable then
		icon:SetVertexColor(1, 1, 1)
	elseif notEnoughMana then
		icon:SetVertexColor(0.5, 0.5, 1)
	else
		icon:SetVertexColor(0.4, 0.4, 0.4)
	end
end

-- Cooldown state painted on the icon: Desaturate on Cooldown, Alpha when on CD.
local function PaintCooldownState(btn, onCD)
	local p = P.Profile()
	local icon = btn.icon
	if not icon then
		return
	end
	if btn.eabDesat ~= (onCD and p.desaturateOnCooldown and true or false) then
		btn.eabDesat = onCD and p.desaturateOnCooldown and true or false
		icon:SetDesaturated(btn.eabDesat and 1 or nil)
	end
	local a = 1
	if onCD and (p.alphaWhenOnCD or 100) < 100 then
		a = (p.alphaWhenOnCD or 100) / 100
	end
	if btn.eabIconAlpha ~= a then
		btn.eabIconAlpha = a
		icon:SetAlpha(a)
	end
end

-------------------------------------------------------------------------------
--  Cooldown numbers: one ticker for every button with a running cooldown
-------------------------------------------------------------------------------
local cdActive = {}
local cdTicker = CreateFrame("Frame")
cdTicker:Hide()
local cdElapsed = 0

local function FormatRemaining(r)
	if r >= 3600 then
		return ceil(r / 3600) .. "h"
	elseif r >= 60 then
		return ceil(r / 60) .. "m"
	elseif r >= 1 then
		return tostring(floor(r + 0.5))
	end
	return string.format("%.1f", r)
end

local function TickButton(btn, now)
	local info = cdActive[btn]
	if not info then
		return
	end
	local remain = info.start + info.duration - now
	if remain <= 0 then
		cdActive[btn] = nil
		btn.cdText:SetText("")
		PaintCooldownState(btn, false)
		return
	end
	local p = P.Profile()
	if p.cooldownNumbers ~= false and (not info.recharge or p.showChargeRechargeNumbers ~= false) then
		btn.cdText:SetText(FormatRemaining(remain))
	else
		btn.cdText:SetText("")
	end
end

cdTicker:SetScript("OnUpdate", function(self, elapsed)
	cdElapsed = cdElapsed + elapsed
	if cdElapsed < 0.1 then
		return
	end
	cdElapsed = 0
	local now = GetTime()
	local any = false
	for btn in pairs(cdActive) do
		TickButton(btn, now)
		any = true
	end
	if not any then
		self:Hide()
	end
end)

-- start, duration: the main cooldown; recharge: true for a charge spell's
-- recharge while a charge is still there. GCD-only cooldowns (1.5 s and less)
-- show no number and do not count as "on cooldown" (retail rule).
function P.SetCooldownState(btn, start, duration, recharge)
	if not btn.cdText then
		return
	end
	if start and duration and duration > 1.5 and start > 0 then
		cdActive[btn] = { start = start, duration = duration, recharge = recharge }
		PaintCooldownState(btn, not recharge)
		TickButton(btn, GetTime())
		cdTicker:Show()
	else
		if cdActive[btn] then
			cdActive[btn] = nil
		end
		btn.cdText:SetText("")
		PaintCooldownState(btn, false)
	end
end

function P.RefreshCooldownNumbers()
	local now = GetTime()
	for btn in pairs(cdActive) do
		TickButton(btn, now)
	end
	for btn in pairs(P.allButtons or {}) do
		if not cdActive[btn] then
			PaintCooldownState(btn, false)
		else
			PaintCooldownState(btn, not cdActive[btn].recharge)
		end
	end
end

-------------------------------------------------------------------------------
--  Hide Charge Count at 0 (retail ns._EABZeroCountAlpha)
-------------------------------------------------------------------------------
function P.ApplyZeroCount(btn, value)
	local fs = btn.Count
	if not fs then
		return
	end
	local a = 1
	if P.Profile().hideZeroCount and (value == 0 or value == "0") then
		a = 0
	end
	fs:SetAlpha(a)
end

-------------------------------------------------------------------------------
--  Show Equipped Item Color (retail AB_EquippedBorderLook): the equipped
--  item's rarity color in the square art
-------------------------------------------------------------------------------
local function EquippedQuality(action)
	local aType, id = GetActionInfo(action)
	if aType == "item" and id then
		for slot = 1, 19 do
			if GetInventoryItemID("player", slot) == id then
				return GetInventoryItemQuality("player", slot)
			end
		end
		local _, _, q = GetItemInfo(id)
		return q
	end
	local tex = GetActionTexture(action)
	if tex then
		for slot = 1, 19 do
			if GetInventoryItemTexture("player", slot) == tex then
				return GetInventoryItemQuality("player", slot)
			end
		end
	end
end

function P.UpdateEquippedBorder(btn)
	local bd = btn.Border
	if not bd then
		return
	end
	local action = btn.kind == "action" and btn.action
	if not (action and P.Profile().showEquippedBorder and IsEquippedAction(action)) then
		bd:Hide()
		return
	end
	local q = EquippedQuality(action)
	if q and GetItemQualityColor then
		local r, g, b = GetItemQualityColor(q)
		bd:SetVertexColor(r, g, b, 1)
	else
		bd:SetVertexColor(0, 1, 0, 0.5)
	end
	bd:SetAlpha(1)
	bd:Show()
end

-------------------------------------------------------------------------------
--  Proc glows (retail Custom Proc Glow; off = Blizzard's own glow)
--  Styles: 1 Pixel Glow, 2 Action Button Glow, 3 Auto-Cast Shine.
-------------------------------------------------------------------------------
EAB.GLOW_STYLES = {
	{ key = 1, name = "Pixel Glow" },
	{ key = 2, name = "Action Button Glow" },
	{ key = 3, name = "Auto-Cast Shine" },
}

local function GlowColor()
	local p = P.Profile()
	if p.procGlowUseClassColor or p.procGlowColorMode == "class" then
		return P.ClassColor()
	end
	if p.procGlowColorMode == "default" then
		return 1, 0.776, 0.376
	end
	local c = p.procGlowColor or { r = 1, g = 0.776, b = 0.376 }
	return c.r or 1, c.g or 1, c.b or 1
end
EAB.GlowColor = GlowColor

local function CustomGlowOn()
	local p = P.Profile()
	return p.procGlowEnabled and (p.procGlowType or 1) ~= 0
end

-- Pixel Glow: 8 short lines running around the button edge.
local PIXEL_LINES = 8
local pixelDriver = CreateFrame("Frame")
local pixelActive = {}
pixelDriver:Hide()
pixelDriver:SetScript("OnUpdate", function(self, elapsed)
	local any = false
	for frame in pairs(pixelActive) do
		any = true
		frame.phase = (frame.phase + elapsed * 0.25) % 1
		local w, h = frame:GetWidth(), frame:GetHeight()
		local perim = 2 * (w + h)
		local len = perim / PIXEL_LINES * 0.5
		local th = frame.thick
		for i = 1, PIXEL_LINES do
			local line = frame.lines[i]
			local pos = ((frame.phase + (i - 1) / PIXEL_LINES) % 1) * perim
			line:ClearAllPoints()
			if pos < w then
				line:SetSize(min(len, w - pos), th)
				line:SetPoint("TOPLEFT", frame, "TOPLEFT", pos, 0)
			elseif pos < w + h then
				line:SetSize(th, min(len, w + h - pos))
				line:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -(pos - w))
			elseif pos < 2 * w + h then
				line:SetSize(min(len, 2 * w + h - pos), th)
				line:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(pos - w - h), 0)
			else
				line:SetSize(th, min(len, perim - pos))
				line:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, pos - 2 * w - h)
			end
		end
	end
	if not any then
		self:Hide()
	end
end)

local function PixelGlow(btn, on)
	local f = btn.eabPixelGlow
	if on then
		if not f then
			f = CreateFrame("Frame", nil, btn)
			f:SetFrameLevel(btn:GetFrameLevel() + 5)
			f.lines = {}
			for i = 1, PIXEL_LINES do
				f.lines[i] = f:CreateTexture(nil, "OVERLAY")
				f.lines[i]:SetTexture(1, 1, 1, 1)
			end
			f.phase = 0
			btn.eabPixelGlow = f
		end
		local px = P.PixelFor(btn)
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", btn, "TOPLEFT", -px, px)
		f:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", px, -px)
		f.thick = 2 * px
		local r, g, b = GlowColor()
		for i = 1, PIXEL_LINES do
			f.lines[i]:SetVertexColor(r, g, b, 1)
		end
		f:Show()
		pixelActive[f] = true
		pixelDriver:Show()
	elseif f then
		pixelActive[f] = nil
		f:Hide()
	end
end

-- Action Button Glow: Blizzard's alert art in the glow color, our own frame.
local ALERT_PARTS = { "spark", "innerGlow", "innerGlowOver", "outerGlow", "outerGlowOver", "ants" }
local function ButtonGlow(btn, on)
	local f = btn.eabAlert
	if on then
		if not f then
			f = CreateFrame("Frame", nil, btn, "ActionBarButtonSpellActivationAlert")
			if f.animOut then
				f.animOut:SetScript("OnFinished", function(anim) anim:GetParent():Hide() end)
			end
			btn.eabAlert = f
		end
		local w, h = btn:GetSize()
		f:SetFrameLevel(btn:GetFrameLevel() + 5)
		f:ClearAllPoints()
		f:SetSize(w * 1.4, h * 1.4)
		f:SetPoint("TOPLEFT", btn, "TOPLEFT", -w * 0.2, h * 0.2)
		f:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", w * 0.2, -h * 0.2)
		local r, g, b = GlowColor()
		for _, k in ipairs(ALERT_PARTS) do
			local t = f[k]
			if t and t.SetVertexColor then
				t:SetDesaturated(1)
				t:SetVertexColor(r, g, b)
			end
		end
		if not f:IsShown() or (f.animOut and f.animOut:IsPlaying()) then
			if f.animOut and f.animOut:IsPlaying() then f.animOut:Stop() end
			f:Show()
			if f.animIn then f.animIn:Play() end
		end
	elseif f and f:IsShown() then
		if f.animIn and f.animIn:IsPlaying() then f.animIn:Stop() end
		if f.animOut and btn:IsVisible() then
			f.animOut:Play()
		else
			f:Hide()
		end
	end
end

-- Auto-Cast Shine: Blizzard's pet autocast sparkles in the glow color.
local function ShineGlow(btn, on)
	local f = btn.eabShine
	if on then
		if not f then
			f = CreateFrame("Frame", btn:GetName() .. "EABShine", btn, "AutoCastShineTemplate")
			f:SetAllPoints(btn)
			btn.eabShine = f
		end
		f:SetFrameLevel(btn:GetFrameLevel() + 5)
		f:Show()
		local r, g, b = GlowColor()
		if AutoCastShine_AutoCastStart then
			AutoCastShine_AutoCastStart(f, r, g, b)
		end
	elseif f then
		if AutoCastShine_AutoCastStop then
			AutoCastShine_AutoCastStop(f)
		end
		f:Hide()
	end
end

local function StopCustomGlows(btn)
	PixelGlow(btn, false)
	ButtonGlow(btn, false)
	ShineGlow(btn, false)
end

function P.ShowProcGlow(btn)
	btn.eabGlowing = true
	if CustomGlowOn() then
		if btn.overlay and ActionButton_HideOverlayGlow then
			ActionButton_HideOverlayGlow(btn)
		end
		local style = P.Profile().procGlowType or 1
		PixelGlow(btn, style == 1)
		ButtonGlow(btn, style == 2)
		ShineGlow(btn, style == 3)
	else
		StopCustomGlows(btn)
		if ActionButton_ShowOverlayGlow then
			ActionButton_ShowOverlayGlow(btn)
		end
	end
end

function P.HideProcGlow(btn)
	btn.eabGlowing = nil
	StopCustomGlows(btn)
	if btn.overlay and ActionButton_HideOverlayGlow then
		ActionButton_HideOverlayGlow(btn)
	end
end

-- Repaint every glowing button (the glow options changed).
function EAB:RefreshProcGlows()
	for btn in pairs(P.allButtons or {}) do
		if btn.eabGlowing then
			P.ShowProcGlow(btn)
		end
	end
end

-------------------------------------------------------------------------------
--  Flyout popups (retail EUI_ActionBars_Flyout.lua): the spell flyout of a
--  bar button gets the same square look.
-------------------------------------------------------------------------------
function P.StyleFlyoutButtons()
	local i = 1
	local b = _G["SpellFlyoutButton" .. i]
	while b do
		if not b.eabFlyStyled then
			b.eabFlyStyled = true
			local icon = _G[b:GetName() .. "Icon"]
			if icon then
				icon:ClearAllPoints()
				icon:SetAllPoints(b)
				icon:SetTexCoord(0.055, 0.945, 0.055, 0.945)
			end
			local nt = b:GetNormalTexture()
			if nt then nt:SetAlpha(0) end
			local bg = b:CreateTexture(nil, "BACKGROUND", nil, -1)
			bg:SetAllPoints(b)
			b.eabBG = bg
			local host = CreateFrame("Frame", nil, b)
			host:SetAllPoints(b)
			host:SetFrameLevel(b:GetFrameLevel() + 2)
			b.eabEdges = P.CreateEdges(host, b, "OVERLAY", 2)
			SquareTexture(b:GetHighlightTexture(), HIGHLIGHT_TEXTURES[1])
			SquareTexture(b:GetPushedTexture(), HIGHLIGHT_TEXTURES[2])
			SquareTexture(b:GetCheckedTexture(), HIGHLIGHT_TEXTURES[1])
		end
		local p = P.Profile()
		local c = p.slotBgColor or { r = 0.15, g = 0.15, b = 0.15 }
		b.eabBG:SetTexture(c.r, c.g, c.b, (p.slotBgOpacity or 50) / 100)
		P.LayoutEdges(b.eabEdges, P.PixelFor(b), 0, 0, 0, 1)
		local hr, hg, hb = InteractionColor("highlight")
		local ht = b:GetHighlightTexture()
		if ht then ht:SetVertexColor(hr, hg, hb, 1) end
		local pr, pg, pb = InteractionColor("pushed")
		local pt = b:GetPushedTexture()
		if pt then pt:SetVertexColor(pr, pg, pb, 1) end
		i = i + 1
		b = _G["SpellFlyoutButton" .. i]
	end
	for _, k in ipairs({ "SpellFlyoutHorizontalBackground", "SpellFlyoutVerticalBackground", "SpellFlyoutBackgroundEnd" }) do
		local t = _G[k]
		if t then t:SetAlpha(0) end
	end
end
