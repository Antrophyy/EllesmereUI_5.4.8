-- EllesmereUI Unit Frames for 5.4.8: building the frames and laying them out.
-- One secure unit button per unit (SecureUnitButtonTemplate + RegisterUnitWatch),
-- everything else is plain textures and status bars on it.

local addonName = ...
local ns = EllesmereUI
local UF = ns.UF

local floor, min, max = math.floor, math.min, math.max

-- Interrupt spells per class (for the kick tick and the "on cooldown" color).
UF.INTERRUPTS = {
	ROGUE = { 1766 }, WARRIOR = { 6552 }, PALADIN = { 96231 }, DEATHKNIGHT = { 47528 },
	MAGE = { 2139 }, SHAMAN = { 57994 }, DRUID = { 80964, 80965, 78675 }, MONK = { 116705 },
	PRIEST = { 15487 }, HUNTER = { 147362, 34490 }, WARLOCK = { 19647, 103135 },
}

---------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------
local function NewBar(parent)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetStatusBarTexture(UF.WHITE)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(1)
	local tex = bar:GetStatusBarTexture()
	tex:SetHorizTile(false)
	tex:SetVertTile(false)
	return bar
end

local function CreateTexts(frame)
	local overlay = CreateFrame("Frame", nil, frame)
	overlay:SetFrameLevel(frame:GetFrameLevel() + 20)
	frame.TextOverlay = overlay
	frame.Texts = {}
	for _, slot in ipairs({ "left", "right", "center", "extra" }) do
		frame.Texts[slot] = UF.NewText(overlay, 12)
	end
end

local function CreatePortrait(frame)
	local p = CreateFrame("Frame", nil, frame)
	p:SetFrameLevel(frame:GetFrameLevel() + 1)
	p.bg = UF.Solid(p, "BACKGROUND", 0.1, 0.1, 0.1, 1)
	p.bg:SetAllPoints()
	p.tex = p:CreateTexture(nil, "ARTWORK")
	p.tex:SetAllPoints()
	p.classTex = p:CreateTexture(nil, "ARTWORK")
	p.classTex:SetAlpha(0.8)
	p.ring = p:CreateTexture(nil, "OVERLAY")
	p.ring:SetTexture(UF.MEDIA .. "icons\\circle_border")
	p.ring:Hide()
	p.border = UF.CreateBorder(p, p, true)
	p.border:SetShown(false)
	-- Cast icon shown over the portrait (Cast Icon > Show Icon on Portrait). Its
	-- own frame sits over a 3D portrait model; while it shows, the ring, outer
	-- ring and inner shadow move to a layer above it, so the icon does not
	-- cover the portrait's decoration.
	local ci = CreateFrame("Frame", nil, p)
	ci:SetAllPoints()
	ci:SetFrameLevel(p:GetFrameLevel() + 2)
	ci.tex = ci:CreateTexture(nil, "ARTWORK")
	ci.tex:SetAllPoints()
	ci.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	function ci:SetTexture(texture) self.tex:SetTexture(texture) end
	ci:Hide()
	ci:SetScript("OnShow", function() UF.PortraitDecorAbove(p, true) end)
	ci:SetScript("OnHide", function() UF.PortraitDecorAbove(p, false) end)
	p.castIcon = ci
	frame.Portrait = p
end

function UF.PortraitDecorAbove(p, on)
	if on and not p.decor then
		p.decor = CreateFrame("Frame", nil, p)
		p.decor:SetAllPoints()
		p.decor:SetFrameLevel(p:GetFrameLevel() + 3)
	end
	if not p.decor then
		return
	end
	local parent = on and p.decor or p
	for _, key in ipairs({ "ring", "outerRing", "innerShadow" }) do
		if p[key] then p[key]:SetParent(parent) end
	end
end

local function EnsureModel(p)
	if not p.model then
		p.model = CreateFrame("PlayerModel", nil, p)
		p.model:SetAllPoints()
		p.model:SetFrameLevel(p:GetFrameLevel() + 1)
	end
	return p.model
end
UF.EnsureModel = EnsureModel

local function CreateCastbar(frame)
	local holder = CreateFrame("Frame", nil, frame)
	holder:SetFrameStrata("HIGH")
	holder.bg = UF.Solid(holder, "BACKGROUND", 0, 0, 0, 0.5)
	holder.bg:SetAllPoints()
	local bar = NewBar(holder)
	bar:SetMinMaxValues(0, 1)
	holder.bar = bar
	holder.uninterruptible = UF.Solid(bar, "ARTWORK", 0.5, 0.5, 0.5, 1, 2)
	holder.uninterruptible:SetAllPoints(bar:GetStatusBarTexture())
	holder.uninterruptible:Hide()
	holder.mid = UF.Solid(bar, "ARTWORK", 0.318, 0.820, 0.357, 1, 3)
	holder.mid:Hide()
	holder.tick = UF.Solid(bar, "OVERLAY", 1, 1, 1, 1, 4)
	holder.tick:SetWidth(2)
	holder.tick:Hide()
	holder.border = UF.CreateBorder(bar, holder)
	holder.icon = CreateFrame("Frame", nil, holder)
	holder.icon.bg = UF.Solid(holder.icon, "BACKGROUND", 0, 0, 0, 1)
	holder.icon.bg:SetAllPoints()
	holder.icon.tex = holder.icon:CreateTexture(nil, "ARTWORK")
	holder.icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	holder.icon.border = UF.CreateBorder(holder.icon, holder.icon)
	local textLayer = CreateFrame("Frame", nil, bar)
	textLayer:SetAllPoints(bar)
	textLayer:SetFrameLevel(bar:GetFrameLevel() + 2)
	holder.name = UF.NewText(textLayer, 11)
	holder.time = UF.NewText(textLayer, 10)
	holder.target = UF.NewText(textLayer, 11)
	holder:Hide()
	frame.Castbar = holder
end

local function CreateTextBar(frame)
	local btb = CreateFrame("Frame", nil, frame)
	btb:SetFrameLevel(frame:GetFrameLevel() + 3)
	btb.bg = UF.Solid(btb, "BACKGROUND", 0.2, 0.2, 0.2, 1)
	btb.bg:SetAllPoints()
	btb.border = UF.CreateBorder(btb, btb)
	btb.texts = {
		btbLeft = UF.NewText(btb, 11),
		btbRight = UF.NewText(btb, 11),
		btbCenter = UF.NewText(btb, 11),
	}
	btb.classIcon = btb:CreateTexture(nil, "OVERLAY")
	btb:Hide()
	frame.TextBar = btb
end

local function CreateAbsorbs(frame)
	local health = frame.Health
	local layer = CreateFrame("Frame", nil, health)
	layer:SetAllPoints(health)
	layer:SetFrameLevel(health:GetFrameLevel() + 1)
	frame.AbsorbLayer = layer
	frame.HealPredMine = layer:CreateTexture(nil, "BORDER", nil, 1)
	frame.HealPredOther = layer:CreateTexture(nil, "BORDER", nil, 2)
	frame.Shield = layer:CreateTexture(nil, "ARTWORK", nil, 1)
	frame.OverShield = layer:CreateTexture(nil, "ARTWORK", nil, 2)
	frame.HealAbsorb = layer:CreateTexture(nil, "ARTWORK", nil, 3)
	frame.HealAbsorbBg = layer:CreateTexture(nil, "ARTWORK", nil, 0)
	frame.GlowLine = layer:CreateTexture(nil, "OVERLAY")
	frame.GlowLine:SetTexture(UF.MEDIA .. "icons\\cast_spark")
	frame.GlowLine:SetBlendMode("ADD")
	for _, key in ipairs({ "HealPredMine", "HealPredOther", "Shield", "OverShield", "HealAbsorb", "HealAbsorbBg", "GlowLine" }) do
		frame[key]:Hide()
	end
	-- Thin absorb strips (Absorb Bar / Heal Absorb Bar).
	local strips = CreateFrame("Frame", nil, frame)
	strips:SetAllPoints(frame)
	strips:SetFrameLevel(frame:GetFrameLevel() + 12)
	frame.AbsorbStrip = UF.Solid(strips, "OVERLAY", 1, 1, 1, 1)
	frame.HealAbsorbStrip = UF.Solid(strips, "OVERLAY", 0.78, 0.11, 0.11, 1)
	frame.AbsorbStrip:Hide()
	frame.HealAbsorbStrip:Hide()
	frame.StripLayer = strips
end

local function CreateIndicators(frame)
	local holder = CreateFrame("Frame", nil, frame)
	holder:SetAllPoints(frame)
	holder:SetFrameLevel(frame:GetFrameLevel() + 25)
	frame.IndicatorLayer = holder
	frame.RaidIcon = holder:CreateTexture(nil, "OVERLAY", nil, 6)
	frame.RaidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	frame.RaidIcon:Hide()
	frame.Leader = holder:CreateTexture(nil, "OVERLAY", nil, 7)
	frame.Leader:Hide()
	frame.Combat = holder:CreateTexture(nil, "OVERLAY", nil, 5)
	frame.Combat:Hide()
	frame.Elite = holder:CreateTexture(nil, "OVERLAY", nil, 5)
	frame.Elite:SetTexture(UF.MEDIA .. "icons\\elite")
	frame.Elite:Hide()
	frame.Faction = holder:CreateTexture(nil, "OVERLAY", nil, 5)
	frame.Faction:Hide()
	frame.ThreatPct = UF.NewText(holder, 12)
	frame.ThreatPct:Hide()
	frame.DispelOverlay = frame.Health:CreateTexture(nil, "OVERLAY", nil, 1)
	frame.DispelOverlay:SetTexture(UF.WHITE)
	frame.DispelOverlay:Hide()
	-- Player Threat (Non-Tank): a soft glow border outside the frame.
	frame.ThreatBorder = UF.CreateBorder(holder, frame, true)
	frame.ThreatBorder:SetShown(false)
end

local function CreatePowerText(frame)
	local layer = CreateFrame("Frame", nil, frame.Power)
	layer:SetFrameLevel(frame.Power:GetFrameLevel() + 3)
	frame.PowerTextLayer = layer
	frame.PowerText = UF.NewText(layer, 9)
	frame.PowerText:Hide()
end

-- unitKey: "player", "target", "focus", "pet", "targettarget", "focustarget", "boss1".."boss5"
function UF.CreateUnitFrame(unitKey, name)
	local frame = CreateFrame("Button", name, UIParent, "SecureUnitButtonTemplate")
	frame.unitKey = unitKey
	frame.settingsKey = unitKey:match("^boss%d$") and "boss" or unitKey
	frame.unit = unitKey
	frame.isBoss = frame.settingsKey == "boss"
	frame.isMini = unitKey == "pet" or unitKey == "targettarget" or unitKey == "focustarget"
	frame.isMain = unitKey == "player" or unitKey == "target" or unitKey == "focus"
	frame:SetAttribute("unit", unitKey)
	frame:SetAttribute("*type1", "target")
	frame:SetAttribute("*type2", "togglemenu")
	if unitKey == "player" or unitKey == "pet" then
		frame:SetAttribute("toggleForVehicle", true)
	end
	frame:RegisterForClicks("AnyUp")
	frame:SetFrameStrata("MEDIUM")
	ClickCastFrames = ClickCastFrames or {}
	ClickCastFrames[frame] = true

	frame.bars = CreateFrame("Frame", nil, frame)
	frame.bars:SetFrameLevel(frame:GetFrameLevel() + 2)
	frame.Health = NewBar(frame.bars)
	frame.Health:SetFrameLevel(frame.bars:GetFrameLevel())
	frame.Health.bg = frame.Health:CreateTexture(nil, "BACKGROUND")
	frame.Health.bg:SetTexture(UF.WHITE)
	frame.Health.fullBg = UF.Solid(frame.Health, "BACKGROUND", 0, 0, 0, 0, -1)
	frame.Health.fullBg:SetAllPoints()
	frame.Power = NewBar(frame)
	frame.Power:SetFrameLevel(frame.bars:GetFrameLevel() + 2)
	frame.Power.bg = UF.Solid(frame.Power, "BACKGROUND", 0.067, 0.067, 0.067, 1)
	frame.Power.bg:SetAllPoints()
	frame.Power.border = UF.CreateBorder(frame.Power, frame.Power)
	frame.Power.border:SetShown(false)

	CreatePortrait(frame)
	CreateTexts(frame)
	CreatePowerText(frame)
	CreateAbsorbs(frame)

	-- Unified border over portrait, health and power.
	frame.BorderLayer = CreateFrame("Frame", nil, frame)
	frame.BorderLayer:SetAllPoints(frame)
	frame.BorderLayer:SetFrameLevel(frame:GetFrameLevel() + 10)
	frame.Border = UF.CreateBorder(frame.BorderLayer, frame)

	CreateIndicators(frame)
	if frame.isMain or frame.isBoss then
		CreateCastbar(frame)
	end
	if frame.isMain then
		CreateTextBar(frame)
	end
	if unitKey == "player" then
		UF.CreateClassPower(frame)
	end
	if frame.isMain or frame.isBoss then
		UF.CreateAuraContainers(frame)
	end

	frame:SetScript("OnEnter", UF.OnEnter)
	frame:SetScript("OnLeave", UF.OnLeave)
	return frame
end

---------------------------------------------------------------------------
-- Look donor of mini frames and inherited boss borders
---------------------------------------------------------------------------
-- Mini frames copy border, bar texture and highlight from a main frame:
-- lookSource if set, else focus, then target, then player.
function UF.Donor(unitKey)
	local db = UF.db
	local s = UF.Settings(unitKey)
	local function Usable(key)
		return db.enabledFrames[key] ~= false and db[key].barVisibility ~= "never"
	end
	local pick = s and s.lookSource
	if pick == "player" then
		return db.player
	end
	if (pick == "target" or pick == "focus") and Usable(pick) then
		return db[pick]
	end
	if Usable("focus") then
		return db.focus
	elseif Usable("target") then
		return db.target
	end
	return db.player
end

-- Settings that decide the look (border, texture, highlight) of a frame.
function UF.LookSettings(frame)
	local s = UF.Settings(frame.settingsKey)
	if frame.isMini then
		return UF.Donor(frame.settingsKey)
	end
	if frame.isBoss and not s.borderCustom then
		return UF.Donor("boss")
	end
	return s
end

function UF.BarTextureFor(frame)
	local s = UF.Settings(frame.settingsKey)
	local key = s.healthBarTexture
	if (frame.isMini or frame.isBoss) and (key == nil or key == "inherit") then
		key = UF.Donor(frame.settingsKey).healthBarTexture
	end
	if key == nil or key == "inherit" then
		key = UF.db.healthBarTexture
	end
	return UF.BarTexturePath(key)
end

function UF.BorderSizeFor(frame)
	local s = UF.Settings(frame.settingsKey)
	if frame.isMini and s.borderSizeOverride then
		return s.borderSizeOverride
	end
	return UF.LookSettings(frame).borderSize or 1
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------
-- Like retail: Target of Target and Focus Target never have a power bar,
-- whatever their saved powerPosition says (no setting for it either).
local NO_POWER_UNITS = { targettarget = true, focustarget = true }

local function PowerAttached(s, frame)
	if frame and NO_POWER_UNITS[frame.settingsKey] then
		return false
	end
	local pos = s.powerPosition or "below"
	return (pos == "below" or pos == "above") and (s.powerHeight or 0) > 0
end
UF.PowerAttached = PowerAttached

local function PowerShown(s, frame)
	if frame and NO_POWER_UNITS[frame.settingsKey] then
		return false
	end
	return (s.powerPosition or "below") ~= "none" and (s.powerHeight or 0) > 0
end
UF.PowerShown = PowerShown

-- Portrait state: "none", "attached" or "detached".
local function PortraitStyle(frame, s)
	if s.showPortrait == false then
		return "none"
	end
	if frame.isMain then
		local style = s.portraitStyle or "attached"
		if style == "none" then
			return "none"
		end
		return style
	end
	return s.showPortrait and "attached" or "none"
end
UF.PortraitStyle = PortraitStyle

local function ClassPowerAboveHeight(frame, s)
	if frame.unitKey ~= "player" or not frame.ClassPower or not frame.ClassPower.active then
		return 0
	end
	if (s.classPowerStyle or "none") ~= "modern" or (s.classPowerPosition or "top") ~= "above" then
		return 0
	end
	return frame.ClassPower.pipHeight or 0
end

local function TextBarAttached(frame, s)
	if not frame.TextBar or not s.bottomTextBar then
		return nil
	end
	local pos = s.btbPosition or "bottom"
	if pos == "top" or pos == "bottom" then
		return pos
	end
	return nil
end

-- Sizes of the frame (EllesmereUI formula).
function UF.FrameSize(frame)
	local s = UF.Settings(frame.settingsKey)
	local barH = (s.healthHeight or 46) + (PowerAttached(s, frame) and s.powerHeight or 0)
	local portraitW = PortraitStyle(frame, s) == "attached" and barH or 0
	local width = (s.frameWidth or 181) + portraitW
	local btbH = TextBarAttached(frame, s) and (s.bottomTextBarHeight or 16) or 0
	local cpH = ClassPowerAboveHeight(frame, s)
	return width, barH + btbH + cpH, barH, portraitW, btbH, cpH
end

local function ApplyBarFill(bar, reverse, vertical)
	bar:SetOrientation(vertical and "VERTICAL" or "HORIZONTAL")
	if bar.SetReverseFill then
		bar:SetReverseFill(reverse and true or false)
	end
	bar:SetRotatesTexture(vertical and true or false)
end

local function LayoutPortrait(frame, s, style, barH, portraitW, top)
	local p = frame.Portrait
	p:ClearAllPoints()
	p.border:SetShown(false)
	p.ring:Hide()
	UF.PortraitExtras(p, s, false, 0)
	if style == "none" then
		p:Hide()
		return
	end
	p:Show()
	local side = s.portraitSide or "left"
	if style == "attached" then
		p:SetSize(portraitW, barH)
		if side == "right" then
			p:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -top)
		else
			p:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -top)
		end
		p:SetFrameLevel(frame:GetFrameLevel() + 1)
		return
	end
	-- Detached: 15 px outside the health bar, its own border or ring.
	local size = max(8, barH + (s.portraitSize or 0) + 10)
	local px = UF.Pixel()
	p:SetSize(size, size)
	p:SetFrameLevel(frame:GetFrameLevel() + 15)
	local x, y = s.portraitX or 0, s.portraitY or 0
	if side == "right" then
		p:SetPoint("TOPLEFT", frame.Health, "TOPRIGHT", 15 + x, 5 + y)
	elseif side == "top" then
		p:SetPoint("BOTTOM", frame.Health, "TOP", x, 15 + y)
	else
		p:SetPoint("TOPRIGHT", frame.Health, "TOPLEFT", -15 + x, 5 + y)
	end
	local shape = s.detachedPortraitShape or "portrait"
	local round = shape == "circle" and (s.portraitMode or "2d") ~= "3d"
	UF.PortraitExtras(p, s, round, size)
	if round then
		local ringSize = size * 128 / 94
		p.ring:ClearAllPoints()
		p.ring:SetPoint("CENTER", p, "CENTER")
		p.ring:SetSize(ringSize, ringSize)
		p.ring:Show()
		p.bg:Hide()
	elseif shape ~= "none" then
		local bsize = s.detachedPortraitBorderSize or 7
		p.border:SetBorderSize(max(1, floor(bsize / 2 + 0.5)) * px)
		p.border:SetShown(true)
		p.bg:Show()
	end
end

-- Outer Ring and Inner Shadow on a round detached portrait (retail
-- ns.UF_PortraitExtras). Ring art from EllesmereUI media\portraits, tinted
-- with the frame border color; Outer Ring Size = percent of the portrait.
UF.OUTER_RING_ART = {
	pixels = "pixels_ring", ["pixels-textured"] = "pixels_ring_textured", ["pixels-shadow"] = "pixels_ring_shadow",
	["pixels-textured-shadow"] = "pixels_ring_textured_shadow", ["thin-border"] = "pixels_ring_thin_border",
}
function UF.PortraitExtras(p, s, round, size)
	local art = round and UF.OUTER_RING_ART[s.detachedPortraitOuterRing or "none"]
	if art then
		if not p.outerRing then
			p.outerRing = p:CreateTexture(nil, "OVERLAY", nil, 1)
		end
		local ring = p.outerRing
		ring:SetTexture(UF.MEDIA .. "portraits\\" .. art)
		local ext = ((s.detachedPortraitOuterRingScale or 118) - 100) / 200
		local o = size * ext - 4
		ring:ClearAllPoints()
		ring:SetPoint("TOPLEFT", p, "TOPLEFT", -o, o)
		ring:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", o, -o)
		local bc = s.borderColor
		ring:SetVertexColor(bc and bc.r or 0, bc and bc.g or 0, bc and bc.b or 0, s.borderAlpha or 1)
		ring:Show()
	elseif p.outerRing then
		p.outerRing:Hide()
	end
	if round and s.detachedPortraitInnerShadow then
		if not p.innerShadow then
			p.innerShadow = p:CreateTexture(nil, "ARTWORK", nil, 7)
			p.innerShadow:SetTexture(UF.MEDIA .. "portraits\\pixels_inner_shadow")
			p.innerShadow:SetAllPoints(p)
		end
		p.innerShadow:Show()
	elseif p.innerShadow then
		p.innerShadow:Hide()
	end
end

local function LayoutTexts(frame, s)
	local overlay = frame.TextOverlay
	overlay:ClearAllPoints()
	overlay:SetAllPoints(frame.Health)
	local barW = s.frameWidth or 181
	local texts = frame.Texts
	local fallbackSize = s.textSize or 12
	for slot, fs in pairs(texts) do
		local prefix = slot .. "Text"
		local content = s[prefix .. "Content"] or "none"
		fs:ClearAllPoints()
		if content == "none" or (slot == "extra" and not frame.isMain and not frame.isBoss) then
			fs:Hide()
		else
			fs:Show()
			UF.SetFont(fs, s[prefix .. "Size"] or fallbackSize)
			local x, y = s[prefix .. "X"] or 0, s[prefix .. "Y"] or 0
			local pct = (s[prefix .. "WidthPct"] or 100) / 100
			if slot == "left" then
				fs:SetJustifyH("LEFT")
				fs:SetPoint("LEFT", overlay, "LEFT", 5 + x, y)
				local rightUsed = (s.rightTextContent or "none") ~= "none"
				fs:SetWidth(max(20, (rightUsed and barW * 0.58 or barW - 10) * pct))
			elseif slot == "right" then
				fs:SetJustifyH("RIGHT")
				fs:SetPoint("RIGHT", overlay, "RIGHT", -5 + x, y)
				fs:SetWidth(max(20, barW * 0.5 * pct))
			elseif slot == "center" then
				fs:SetJustifyH("CENTER")
				fs:SetPoint("CENTER", overlay, "CENTER", x, y)
				fs:SetWidth(max(20, barW * 0.9 * pct))
			else
				local align = s.extraTextAlign or "left"
				fs:SetWidth(max(20, (barW - 10) * pct))
				if align == "right" then
					fs:SetJustifyH("RIGHT")
					fs:SetPoint("RIGHT", overlay, "RIGHT", -5 + x, y)
				elseif align == "center" then
					fs:SetJustifyH("CENTER")
					fs:SetPoint("CENTER", overlay, "CENTER", x, y)
				else
					fs:SetJustifyH("LEFT")
					fs:SetPoint("LEFT", overlay, "LEFT", 5 + x, y)
				end
			end
		end
	end
end

local function LayoutPower(frame, s, barW)
	local power = frame.Power
	power:ClearAllPoints()
	power.border:SetShown(false)
	local pos = s.powerPosition or "below"
	if not PowerShown(s, frame) then
		power:Hide()
		if frame.unitKey == "player" and ns.SpellCostPrediction and not frame.headerPreview then
			ns.SpellCostPrediction.Detach("uf")
		end
		return
	end
	power:Show()
	-- Spell Cost Prediction (retail s.powerCostPrediction, player only).
	if frame.unitKey == "player" and ns.SpellCostPrediction and not frame.headerPreview then
		if s.powerCostPrediction == true then
			UF.POWER_COST_HOST = UF.POWER_COST_HOST or {
				PowerType = function() return (UnitPowerType("player")) end,
				Color = function()
					local ps = UF.db.player
					local r, g, b = ns.SpellCostPrediction.Color(ps)
					return r, g, b, (ps.powerBarOpacity or 100) / 100
				end,
			}
			ns.SpellCostPrediction.Attach("uf", power, UF.POWER_COST_HOST)
		else
			ns.SpellCostPrediction.Detach("uf")
		end
	end
	-- Like retail: a detached bar draws over the unified border (+10).
	local detached = pos ~= "below" and pos ~= "above"
	power:SetFrameLevel(frame:GetFrameLevel() + (detached and 12 or 4))
	frame.PowerTextLayer:SetFrameLevel(power:GetFrameLevel() + 3)
	local height = s.powerHeight or 6
	if pos == "below" then
		power:SetPoint("TOPLEFT", frame.Health, "BOTTOMLEFT", 0, 0)
		power:SetPoint("TOPRIGHT", frame.Health, "BOTTOMRIGHT", 0, 0)
		power:SetHeight(height)
		power:SetFrameStrata(frame:GetFrameStrata())
	elseif pos == "above" then
		power:SetPoint("BOTTOMLEFT", frame.Health, "TOPLEFT", 0, 0)
		power:SetPoint("BOTTOMRIGHT", frame.Health, "TOPRIGHT", 0, 0)
		power:SetHeight(height)
		power:SetFrameStrata(frame:GetFrameStrata())
	else
		local width = (s.powerWidth or 0) > 0 and s.powerWidth or barW
		power:SetSize(width, height)
		if pos == "detached_top" then
			power:SetPoint("BOTTOM", frame.Health, "TOP", s.powerX or 0, 15 + (s.powerY or 0))
		else
			power:SetPoint("TOP", frame.Health, "BOTTOM", s.powerX or 0, -15 + (s.powerY or 0))
		end
		power:SetFrameStrata(UF.db.enableCustomBarStratas and (UF.db.detachedPowerStrata or "HIGH") or frame:GetFrameStrata())
		local size = s.powerBorderSize or 0
		if size > 0 then
			local c = s.powerBorderColor or {}
			power.border:SetBorderSize(size * UF.Pixel())
			power.border:SetBorderColor(c.r or 0, c.g or 0, c.b or 0, s.powerBorderAlpha or 1)
			power.border:SetShown(true)
		end
	end
	ApplyBarFill(power, s.powerReverseFill, false)

	-- Power text
	local fs = frame.PowerText
	local textPos = s.powerPercentText or "none"
	local fmt = s.powerTextFormat or "perpp"
	fs:ClearAllPoints()
	if textPos == "none" or fmt == "none" then
		fs:Hide()
	else
		fs:Show()
		UF.SetFont(fs, s.powerPercentSize or 9)
		local x, y = s.powerPercentX or 0, s.powerPercentY or 0
		if textPos == "left" then
			fs:SetJustifyH("LEFT")
			fs:SetPoint("LEFT", power, "LEFT", 2 + x, y)
		elseif textPos == "right" then
			fs:SetJustifyH("RIGHT")
			fs:SetPoint("RIGHT", power, "RIGHT", -2 + x, y)
		else
			fs:SetJustifyH("CENTER")
			fs:SetPoint("CENTER", power, "CENTER", x, y)
		end
	end
end

local function LayoutTextBar(frame, s, width, top)
	local btb = frame.TextBar
	if not btb then
		return
	end
	if not s.bottomTextBar then
		btb:Hide()
		return
	end
	btb:Show()
	btb:ClearAllPoints()
	local pos = s.btbPosition or "bottom"
	local height = s.bottomTextBarHeight or 16
	btb.border:SetShown(false)
	if pos == "top" then
		btb:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -top)
		btb:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -top)
		btb:SetHeight(height)
		btb:SetFrameStrata(frame:GetFrameStrata())
	elseif pos == "bottom" then
		btb:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
		btb:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
		btb:SetHeight(height)
		btb:SetFrameStrata(frame:GetFrameStrata())
	else
		local w = (s.btbWidth or 0) > 0 and s.btbWidth or width
		btb:SetSize(w, height)
		if pos == "detached_top" then
			btb:SetPoint("BOTTOM", frame, "TOP", s.btbX or 0, 15 + (s.btbY or 0))
		else
			btb:SetPoint("TOP", frame, "BOTTOM", s.btbX or 0, -15 + (s.btbY or 0))
		end
		btb:SetFrameStrata(UF.db.enableCustomBarStratas and (UF.db.detachedTextBarStrata or "DIALOG") or frame:GetFrameStrata())
		local look = UF.LookSettings(frame)
		local c = look.borderColor or {}
		btb.border:SetBorderSize(UF.BorderSizeFor(frame) * UF.Pixel())
		btb.border:SetBorderColor(c.r or 0, c.g or 0, c.b or 0, look.borderAlpha or 1)
		btb.border:SetShown(UF.BorderSizeFor(frame) > 0)
	end
	local bg = s.btbBgColor or {}
	btb.bg:SetVertexColor(bg.r or 0.2, bg.g or 0.2, bg.b or 0.2, s.btbBgOpacity or 1)

	-- Class icon
	local icon = btb.classIcon
	local style = s.btbClassIcon or "none"
	local iconW = 0
	icon:ClearAllPoints()
	if style ~= "none" then
		local size = s.btbClassIconSize or 14
		icon:SetSize(size, size)
		icon:SetTexture(UF.ClassArtPath(style))
		icon:Show()
		local loc = s.btbClassIconLocation or "left"
		local x, y = s.btbClassIconX or 0, s.btbClassIconY or 0
		if loc == "center" then
			icon:SetPoint("CENTER", btb, "CENTER", x, y)
		elseif loc == "right" then
			icon:SetPoint("RIGHT", btb, "RIGHT", -3 + x, y)
		else
			icon:SetPoint("LEFT", btb, "LEFT", 3 + x, y)
			iconW = size + 3
		end
	else
		icon:Hide()
	end

	local barW = btb:GetWidth() > 0 and btb:GetWidth() or width
	for prefix, fs in pairs(btb.texts) do
		local content = s[prefix .. "Content"] or "none"
		fs:ClearAllPoints()
		if content == "none" then
			fs:Hide()
		else
			fs:Show()
			UF.SetFont(fs, s[prefix .. "Size"] or 11)
			local x, y = s[prefix .. "X"] or 0, s[prefix .. "Y"] or 0
			local pct = (s[prefix .. "WidthPct"] or 100) / 100
			if prefix == "btbLeft" then
				fs:SetJustifyH("LEFT")
				fs:SetPoint("LEFT", btb, "LEFT", 5 + iconW + x, y)
				fs:SetWidth(max(20, barW * 0.5 * pct))
			elseif prefix == "btbRight" then
				fs:SetJustifyH("RIGHT")
				fs:SetPoint("RIGHT", btb, "RIGHT", -5 + x, y)
				fs:SetWidth(max(20, barW * 0.5 * pct))
			else
				fs:SetJustifyH("CENTER")
				fs:SetPoint("CENTER", btb, "CENTER", x, y)
				fs:SetWidth(max(20, barW * 0.9 * pct))
			end
		end
	end
end

-- Cast bar settings with the player key names resolved.
function UF.CastSettings(frame)
	local s = UF.Settings(frame.settingsKey)
	local isPlayer = frame.unitKey == "player"
	local c = {}
	if isPlayer then
		c.enabled = s.showPlayerCastbar and true or false
		c.height = (s.playerCastbarHeight and s.playerCastbarHeight > 0) and s.playerCastbarHeight or 14
		c.width = s.playerCastbarWidth or s.frameWidth or 181
		c.showIcon = s.showPlayerCastIcon ~= false
		c.iconInWidth = s.playerCastbarIconInWidth ~= false
		c.iconRight = s.playerCastbarIconRight
		c.iconOnPortrait = s.playerCastbarIconOnPortrait
		c.iconX, c.iconY = s.playerCastIconOffsetX or 0, s.playerCastIconOffsetY or 0
	else
		c.enabled = s.showCastbar ~= false
		c.height = s.castbarHeight or 14
		c.width = s.castbarWidth or 0
		c.showIcon = s.showCastIcon ~= false
		c.iconInWidth = s.castbarIconInWidth ~= false
		c.iconRight = s.castbarIconRight
		c.iconOnPortrait = s.castbarIconOnPortrait
		c.iconX, c.iconY = s.castIconOffsetX or 0, s.castIconOffsetY or 0
	end
	if c.iconOnPortrait and (not c.showIcon or PortraitStyle(frame, s) == "none") then
		c.iconOnPortrait = false
	end
	return c, s
end

local function LayoutCastbar(frame, s, frameW)
	if frame.unitKey == "player" then
		UF.ApplyBlizzCastbar()
	end
	local holder = frame.Castbar
	if not holder then
		return
	end
	local c = UF.CastSettings(frame)
	holder.enabled = c.enabled
	if not c.enabled then
		holder:Hide()
		return
	end
	local width = c.width
	if width <= 0 then
		width = frame.isBoss and frameW or (s.frameWidth or 181)
	elseif width < 30 then
		width = 30
	end
	local height = c.height
	holder:SetSize(width, height)
	if frame.unitKey == "player" and s.lockCastbarToFrame == false then
		-- Its own spot (Unlock Mode element "playerCastbar").
		UF.PlaceFree(holder, "playerCastbar")
	else
		holder._eufFree = nil
		holder:ClearAllPoints()
		if frame.isBoss then
			holder:SetPoint("TOP", frame, "BOTTOM", s.castbarOffsetX or 0, s.castbarOffsetY or 0)
		else
			holder:SetPoint("TOP", frame, "BOTTOM", 0, 0)
		end
	end
	holder:SetFrameStrata(UF.db.raiseCastbarStrata ~= false and "HIGH" or frame:GetFrameStrata())
	holder.bg:SetVertexColor(0, 0, 0, 1)
	local bgc = s.castBgColor or {}
	holder.bg:SetVertexColor(bgc.r or 0, bgc.g or 0, bgc.b or 0, s.castBgAlpha or 0.5)

	local bar = holder.bar
	local icon = holder.icon
	bar:ClearAllPoints()
	icon:ClearAllPoints()
	local showIcon = c.showIcon and not c.iconOnPortrait
	local px = UF.Pixel()
	if showIcon then
		icon:Show()
		icon:SetSize(height, height)
		icon.tex:ClearAllPoints()
		icon.tex:SetPoint("TOPLEFT", px, -px)
		icon.tex:SetPoint("BOTTOMRIGHT", -px, px)
		icon.border:SetBorderSize(px)
		icon.border:SetBorderColor(0, 0, 0, 1)
		local right = c.iconRight
		if c.iconInWidth then
			if right then
				icon:SetPoint("TOPRIGHT", holder, "TOPRIGHT", c.iconX, c.iconY)
				bar:SetPoint("TOPLEFT", holder, "TOPLEFT")
				bar:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -height, 0)
			else
				icon:SetPoint("TOPLEFT", holder, "TOPLEFT", c.iconX, c.iconY)
				bar:SetPoint("TOPLEFT", holder, "TOPLEFT", height, 0)
				bar:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT")
			end
		else
			bar:SetAllPoints(holder)
			if right then
				icon:SetPoint("TOPLEFT", holder, "TOPRIGHT", c.iconX, c.iconY)
			else
				icon:SetPoint("TOPRIGHT", holder, "TOPLEFT", c.iconX, c.iconY)
			end
		end
	else
		icon:Hide()
		bar:SetAllPoints(holder)
	end
	bar:SetStatusBarTexture(UF.BarTextureFor(frame))
	ApplyBarFill(bar, s.castReverseFill, false)
	holder.uninterruptible:ClearAllPoints()
	holder.uninterruptible:SetAllPoints(bar:GetStatusBarTexture())

	-- Border: 1 px black by default; Custom Border Style sets size and color.
	local bsize, bc, ba = 1, nil, 1
	if s.castBorderCustom then
		bsize = s.castBorderSize or 1
		bc = s.castBorderColor
		ba = s.castBorderAlpha or 1
	end
	holder.border:SetBorderSize(bsize * px)
	bc = bc or {}
	holder.border:SetBorderColor(bc.r or 0, bc.g or 0, bc.b or 0, ba)
	-- Cast Icon cog (retail): Icon Border = the cast bar's border size and
	-- color round the icon; Vertical Separator = a divider between an
	-- integrated icon and the bar in the same look.
	if showIcon and s.castIconBorder then
		icon.border:SetBorderSize(bsize * px)
		icon.border:SetBorderColor(bc.r or 0, bc.g or 0, bc.b or 0, ba)
	end
	local sep = holder.iconSep
	if showIcon and c.iconInWidth and s.castIconSeparator and bsize > 0 then
		if not sep then
			sep = holder:CreateTexture(nil, "OVERLAY", nil, 7)
			holder.iconSep = sep
		end
		sep:SetTexture(bc.r or 0, bc.g or 0, bc.b or 0, ba)
		sep:ClearAllPoints()
		sep:SetWidth(bsize * px)
		local edge = c.iconRight and "TOPRIGHT" or "TOPLEFT"
		local edgeB = c.iconRight and "BOTTOMRIGHT" or "BOTTOMLEFT"
		sep:SetPoint("TOP", bar, edge, 0, 0)
		sep:SetPoint("BOTTOM", bar, edgeB, 0, 0)
		sep:Show()
	elseif sep then
		sep:Hide()
	end

	-- Texts: name left, duration right, target before the duration.
	local nameSide = s.castSpellNameSide or "left"
	local durSide = s.showCastDuration == false and "none" or (s.castDurationSide or "right")
	local targetSide = s.showCastTarget == false and "none" or (s.castSpellTargetSide or "right")
	if s.castCombineNameTarget and not frame.isBoss then
		targetSide = "none"
	end
	local timerW = (s.castDurationSize or 10) * 2.2 + 5
	local function Place(fs, side, size, x, y, color, defaultX)
		fs:ClearAllPoints()
		if side == "none" then
			fs:Hide()
			return
		end
		fs:Show()
		UF.SetFont(fs, size)
		color = color or {}
		fs:SetTextColor(color.r or 1, color.g or 1, color.b or 1, 1)
		if side == "left" then
			fs:SetJustifyH("LEFT")
			fs:SetPoint("LEFT", bar, "LEFT", 5 + x, y)
		elseif side == "right" then
			fs:SetJustifyH("RIGHT")
			fs:SetPoint("RIGHT", bar, "RIGHT", (defaultX or -3) + x, y)
		else
			fs:SetJustifyH("CENTER")
			fs:SetPoint("CENTER", bar, "CENTER", x, y)
		end
	end
	Place(holder.time, durSide, s.castDurationSize or 10, s.castDurationX or 0, s.castDurationY or 0, s.castDurationColor)
	-- The box is wider than the room it reserves (timerW), up to half the bar:
	-- the countdown sits at the anchored edge and a pushback's added time
	-- ("1.5+0.50") fits instead of being cut off.
	holder.time:SetWidth(max(timerW * 2.5, (width - (showIcon and c.iconInWidth and height or 0)) * 0.5))
	local targetX = (durSide == "right" and targetSide == "right") and (-3 - timerW) or -3
	Place(holder.target, targetSide, s.castSpellTargetSize or 11, s.castSpellTargetX or 0, s.castSpellTargetY or 0, s.castSpellTargetColor, targetX)
	Place(holder.name, nameSide, s.castSpellNameSize or 11, s.castSpellNameX or 0, s.castSpellNameY or 1, s.castSpellNameColor)
	local barW = width - (showIcon and c.iconInWidth and height or 0)
	holder.name:SetWidth(max(20, barW * (targetSide == "none" and 0.8 or 0.42)))
	holder.target:SetWidth(max(20, barW * 0.35))
	holder.tick:SetHeight(height)
	holder.hideWhenIdle = s.castbarHideWhenInactive ~= false
	if not holder.casting and not holder.preview then
		holder:SetShown(not holder.hideWhenIdle)
	end
end

local function LayoutIndicators(frame, s)
	local px = UF.Pixel()
	-- Raid marker
	local icon = frame.RaidIcon
	icon:ClearAllPoints()
	local size = s.raidMarkerSize or 28
	icon:SetSize(size, size)
	local align = s.raidMarkerAlign or "right"
	local x, y = s.raidMarkerX or 0, s.raidMarkerY or 0
	if frame.isBoss then
		if align == "right" then
			icon:SetPoint("LEFT", frame, "RIGHT", x, y)
		elseif align == "center" then
			icon:SetPoint("CENTER", frame, "TOP", x, y)
		else
			icon:SetPoint("RIGHT", frame, "LEFT", x, y)
		end
	elseif align == "left" then
		icon:SetPoint("CENTER", frame, "TOPLEFT", x, y)
	elseif align == "center" then
		icon:SetPoint("CENTER", frame, "TOP", x, y)
	else
		icon:SetPoint("CENTER", frame, "TOPRIGHT", x, y)
	end

	local function Corner(tex, position, sizeKey, xKey, yKey, defaultSize)
		local sz = s[sizeKey] or defaultSize
		tex:ClearAllPoints()
		tex:SetSize(sz, sz)
		local ox, oy = s[xKey] or 0, s[yKey] or 0
		local host = frame.Health
		if position == "portrait" and frame.Portrait:IsShown() then
			tex:SetPoint("TOPLEFT", frame.Portrait, "TOPLEFT", ox, oy)
		elseif position == "topright" then
			tex:SetPoint("TOPRIGHT", host, "TOPRIGHT", ox, oy)
		elseif position == "bottomleft" then
			tex:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", ox, oy)
		elseif position == "bottomright" then
			tex:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", ox, oy)
		elseif position == "healthbar" or position == "center" then
			tex:SetPoint("CENTER", host, "CENTER", ox, oy)
		elseif position == "textbar" and frame.TextBar and frame.TextBar:IsShown() then
			tex:SetPoint("CENTER", frame.TextBar, "CENTER", ox, oy)
		else
			tex:SetPoint("TOPLEFT", host, "TOPLEFT", ox, oy)
		end
	end
	Corner(frame.Leader, s.leaderIndicatorPosition or "topleft", "leaderIndicatorSize", "leaderIndicatorX", "leaderIndicatorY", 16)
	Corner(frame.Combat, s.combatIndicatorPosition or "healthbar", "combatIndicatorSize", "combatIndicatorX", "combatIndicatorY", 22)
	Corner(frame.Elite, s.eliteIndicatorPosition or "topleft", "eliteIndicatorSize", "eliteIndicatorX", "eliteIndicatorY", 16)
	Corner(frame.Faction, s.factionIndicatorPosition or "topright", "factionIndicatorSize", "factionIndicatorX", "factionIndicatorY", 18)

	-- Threat % text (target / focus)
	local db = UF.db
	local fs = frame.ThreatPct
	fs:ClearAllPoints()
	UF.SetFont(fs, db.threatPctSize or 12)
	local tpos = db.threatPctPosition or "CENTER"
	local tx, ty = db.threatPctXOffset or 0, db.threatPctYOffset or 0
	if tpos == "LEFT" then
		fs:SetPoint("LEFT", frame.Health, "LEFT", 4 + tx, ty)
	elseif tpos == "RIGHT" then
		fs:SetPoint("RIGHT", frame.Health, "RIGHT", -4 + tx, ty)
	elseif tpos == "OUTLEFT" then
		fs:SetPoint("RIGHT", frame, "LEFT", -4 + tx, ty)
	elseif tpos == "OUTRIGHT" then
		fs:SetPoint("LEFT", frame, "RIGHT", 4 + tx, ty)
	else
		fs:SetPoint("CENTER", frame.Health, "CENTER", tx, ty)
	end

	frame.ThreatBorder:SetBorderSize(2 * px)
end

-- Full layout of one frame from its settings. Secure parts (size, position)
-- only out of combat; visual parts any time.
function UF.Layout(frame)
	local s = UF.Settings(frame.settingsKey)
	if not s then
		return
	end
	frame.settings = s
	if frame.ClassPower then
		-- Decides if the pips are active (the frame grows for "above").
		UF.LayoutClassPower(frame)
	end
	local width, height, barH, portraitW, btbH, cpH = UF.FrameSize(frame)
	if not InCombatLockdown() then
		frame:SetSize(width, height)
		frame:SetFrameStrata(s.frameStrata or UF.db.frameStrata or "MEDIUM")
	end
	local px = UF.Pixel()
	local style = PortraitStyle(frame, s)
	local side = s.portraitSide or "left"
	local btbPos = TextBarAttached(frame, s)
	local top = (btbPos == "top" and btbH or 0)
	local barsTop = top + cpH
	local leftInset = (style == "attached" and side ~= "right") and portraitW or 0
	local rightInset = (style == "attached" and side == "right") and portraitW or 0

	frame.bars:ClearAllPoints()
	frame.bars:SetPoint("TOPLEFT", frame, "TOPLEFT", leftInset, -barsTop)
	frame.bars:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -rightInset, -barsTop)
	frame.bars:SetHeight(barH)

	local health = frame.Health
	health:ClearAllPoints()
	local powerAbove = PowerAttached(s, frame) and s.powerPosition == "above"
	health:SetPoint("TOPLEFT", frame.bars, "TOPLEFT", 0, powerAbove and -(s.powerHeight or 6) or 0)
	health:SetPoint("TOPRIGHT", frame.bars, "TOPRIGHT", 0, powerAbove and -(s.powerHeight or 6) or 0)
	health:SetHeight(s.healthHeight or 46)
	local texture = UF.BarTextureFor(frame)
	health:SetStatusBarTexture(texture)
	health.bg:SetTexture(texture)
	frame.Power:SetStatusBarTexture(texture)
	ApplyBarFill(health, s.healthReverseFill, s.healthVerticalFill)
	frame.barWidth = s.frameWidth or 181
	frame.barTexture = texture

	LayoutPortrait(frame, s, style, barH, portraitW, barsTop)
	LayoutPower(frame, s, s.frameWidth or 181)
	LayoutTexts(frame, s)
	LayoutTextBar(frame, s, width, 0)

	-- Unified border (+ highlight color on hover)
	local look = UF.LookSettings(frame)
	local bsize = UF.BorderSizeFor(frame)
	frame.Border:SetBorderSize(bsize * px)
	local bc = look.borderColor or {}
	frame.borderColor = { bc.r or 0, bc.g or 0, bc.b or 0, look.borderAlpha or 1 }
	frame.Border:SetBorderColor(unpack(frame.borderColor))

	LayoutCastbar(frame, s, width)
	LayoutIndicators(frame, s)
	if frame.ClassPower then
		UF.LayoutClassPower(frame)
	end
	if frame.Buffs then
		UF.LayoutAuras(frame)
	end
	UF.UpdateAll(frame)
end
UF.ReflowFrame = UF.Layout

---------------------------------------------------------------------------
-- Hover: tooltip and highlight border
---------------------------------------------------------------------------
function UF.HighlightOn(frame)
	if frame.isBoss then
		local s = UF.db.boss
		if s.bossHoverBorderEnabled then
			return s.bossHoverBorderColor, s.bossHoverBorderAlpha
		end
		return nil
	end
	if frame.isMini and UF.Settings(frame.settingsKey).showHighlightBorder == false then
		return nil
	end
	local look = UF.LookSettings(frame)
	if UF.db.player.highlightEnabled == false then
		return nil
	end
	return look.highlightColor, look.highlightAlpha
end

function UF.OnEnter(self)
	self.hovered = true
	local c, a = UF.HighlightOn(self)
	if c then
		self.Border:SetBorderColor(c.r or 1, c.g or 1, c.b or 1, a or 1)
	end
	local s = UF.Settings(self.settingsKey)
	if s.showUnitTooltip ~= false and not self.preview then
		UnitFrame_OnEnter(self)
	end
	UF.UpdateAlpha(self)
end

function UF.OnLeave(self)
	self.hovered = false
	UF.UpdateBorderColor(self)
	UnitFrame_OnLeave(self)
	UF.UpdateAlpha(self)
end

-- Border color: target border on the targeted boss, else the normal color.
function UF.UpdateBorderColor(frame)
	if frame.hovered then
		local c, a = UF.HighlightOn(frame)
		if c then
			frame.Border:SetBorderColor(c.r or 1, c.g or 1, c.b or 1, a or 1)
			return
		end
	end
	if frame.isBoss then
		local s = UF.db.boss
		if s.bossTargetBorderEnabled and UnitExists(frame.unit) and UnitIsUnit(frame.unit, "target") then
			local c = s.bossTargetBorderColor or {}
			frame.Border:SetBorderColor(c.r or 1, c.g or 1, c.b or 1, s.bossTargetBorderAlpha or 1)
			return
		end
	end
	if frame.dispelBorderColor then
		frame.Border:SetBorderColor(unpack(frame.dispelBorderColor))
		return
	end
	frame.Border:SetBorderColor(unpack(frame.borderColor or { 0, 0, 0, 1 }))
end
