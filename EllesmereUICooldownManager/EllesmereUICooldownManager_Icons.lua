-------------------------------------------------------------------------------
--  EllesmereUICooldownManager_Icons.lua
--  One CDM icon: art, border, cooldown swipe + text, charges / stacks, keybind,
--  desaturate / range / usable colouring, glows (proc, active, buff, pandemic,
--  CD ready) and the cooldown-state effects (retail EUI_CDM_Icons.lua,
--  EUI_CDM_Glows.lua, EUI_CDM_HookIconStyle.lua, rewritten for 5.4.8:
--  Cooldown frames here only have SetCooldown / SetReverse, so the swipe
--  colour options and edge / bling switches are not available).
-------------------------------------------------------------------------------
local addonName, P = ...
local ns = EllesmereUI
local CDM = P.CDM
local BV = CDM.BV

local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min
local format = string.format
local GetTime = GetTime

local GCD_SPELL = 61304   -- the global cooldown spell

-------------------------------------------------------------------------------
--  Glows: EllesmereUI.Glows (retail EllesmereUI_Glows.lua API) when the core
--  has it, else Blizzard's action button proc glow.
-------------------------------------------------------------------------------
local function Glows()
	local G = ns.Glows
	if G and G.StartGlow and G.StopGlow then return G end
end

-- CDM saved glow numbering (retail ns.GLOW_VIEW = MakeView{1,4,2,3,5,6,7,8}):
-- 1 Pixel, 2 Shape, 3 Action Button, 4 Auto-Cast, 5 GCD, 6 Modern WoW,
-- 7 Classic WoW, 8 Blackout -> the shared EllesmereUI.Glows.STYLES index.
CDM.GLOW_TO_SHARED = { 1, 4, 2, 3, 5, 6, 7, 8 }
CDM.GLOW_NAMES = { "Pixel Glow", "Shape Glow", "Action Button Glow", "Auto-Cast Shine", "GCD", "Modern WoW Glow", "Classic WoW Glow", "Blackout" }
-- Retail proc glow default: Modern WoW Glow (6).
CDM.PROC_GLOW_DEFAULT = 6

-- A style the core does not have falls back to Action Button Glow.
function CDM.GlowShared(style)
	local shared = CDM.GLOW_TO_SHARED[tonumber(style) or 1] or 1
	local styles = ns.Glows and ns.Glows.STYLES
	if styles and not styles[shared] then shared = 2 end
	return shared
end

local function StartGlow(icon, slot, style, r, g, b)
	local host = icon.glow
	local sig = slot .. ":" .. tostring(style) .. ":" .. format("%.2f%.2f%.2f", r or 1, g or 1, b or 1)
	if icon._glowSig == sig then return end
	icon._glowSig = sig
	local G = Glows()
	if G then
		host:Show()
		G.StartGlow(host, CDM.GlowShared(style), icon:GetWidth(), r or 1, g or 1, b or 1, { th = icon._bd and icon._bd.pixelGlowThickness or nil }, icon:GetHeight())
	else
		host:SetAlpha(1)
		host:Show()
		ActionButton_ShowOverlayGlow(host)
	end
end

local function StopGlow(icon)
	if not icon._glowSig then return end
	icon._glowSig = nil
	local G = Glows()
	if G then
		G.StopGlow(icon.glow)
	else
		ActionButton_HideOverlayGlow(icon.glow)
	end
end
CDM.StopIconGlow = StopGlow

-- Retail glow colour: glowColor = "custom" -> glowColorR/G/B; "class" -> class colour.
local function ClassRGB()
	local _, class = UnitClass("player")
	local c = class and RAID_CLASS_COLORS[class]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

local function SettingColor(ss, prefix, dr, dg, db)
	if ss then
		local mode = ss[prefix .. "Color"]
		if mode == "custom" then
			return ss[prefix .. "ColorR"] or dr, ss[prefix .. "ColorG"] or dg, ss[prefix .. "ColorB"] or db
		elseif mode == "class" or ss[prefix .. "ClassColor"] then
			return ClassRGB()
		end
		-- Unified glow colour (retail ResolveGlowColor).
		if ss.glowColor == "custom" then
			return ss.glowColorR or dr, ss.glowColorG or dg, ss.glowColorB or db
		elseif ss.glowColor == "class" then
			return ClassRGB()
		end
	end
	return dr, dg, db
end

-------------------------------------------------------------------------------
--  Sounds ("sm:<LibSharedMedia name>")
-------------------------------------------------------------------------------
function CDM.PlaySoundKey(key)
	if type(key) ~= "string" or key == "" or key == "none" then return end
	local name = key:match("^sm:(.+)$")
	local LSM = ns.GetLSM and ns.GetLSM()
	if name and LSM then
		local path = LSM:Fetch("sound", name, true)
		if path then PlaySoundFile(path, "Master") end
	end
end

-------------------------------------------------------------------------------
--  Creation / style
-------------------------------------------------------------------------------
local function Solid(parent, layer, sub)
	local t = parent:CreateTexture(nil, layer, nil, sub)
	t:SetTexture(1, 1, 1, 1)
	return t
end

local function ShowTooltip(self)
	local e = self._entry
	local bd = self._bd
	if not (e and bd and bd.showTooltip) then return end
	-- NaowhUI "Hide CDM Tooltips in Combat" (NaowhUI_CDM.lua).
	if InCombatLockdown() and CDM.DB().cdmBars.hideTooltipsInCombat then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if e.kind == "slot" then
		GameTooltip:SetInventoryItem("player", e.slot)
	elseif e.itemID then
		GameTooltip:SetItemByID(e.itemID)
	elseif e.spellID then
		GameTooltip:SetSpellByID(e.spellID)
	end
	GameTooltip:Show()
end

function CDM.CreateIcon(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(36, 36)
	f.bg = Solid(f, "BACKGROUND")
	f.bg:SetAllPoints()
	f.tex = f:CreateTexture(nil, "ARTWORK")
	f.borders = {}
	for i = 1, 4 do f.borders[i] = Solid(f, "OVERLAY", 1) end

	f.cd = CreateFrame("Cooldown", nil, f)
	f.cd.noCooldownCount = true   -- OmniCC: the CDM draws its own text
	f.cd:SetAllPoints(f.tex)

	-- Glow above the swipe, text above the glow.
	f.glow = CreateFrame("Frame", nil, f)
	f.glow:SetAllPoints()
	f.glow:SetFrameLevel(f.cd:GetFrameLevel() + 1)

	f.textHost = CreateFrame("Frame", nil, f)
	f.textHost:SetAllPoints()
	f.textHost:SetFrameLevel(f.glow:GetFrameLevel() + 2)
	f.cdText = f.textHost:CreateFontString(nil, "OVERLAY")
	f.countText = f.textHost:CreateFontString(nil, "OVERLAY")
	f.keyText = f.textHost:CreateFontString(nil, "OVERLAY")

	f:SetScript("OnEnter", ShowTooltip)
	f:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return f
end

local function PlaceText(fs, parent, pos, x, y)
	fs:ClearAllPoints()
	pos = (pos or "center"):lower()
	local map = {
		center = "CENTER", top = "TOP", bottom = "BOTTOM", left = "LEFT", right = "RIGHT",
		topleft = "TOPLEFT", topright = "TOPRIGHT", bottomleft = "BOTTOMLEFT", bottomright = "BOTTOMRIGHT",
	}
	local pt = map[pos] or "CENTER"
	fs:SetPoint(pt, parent, pt, x or 0, y or 0)
end

-- Icon height factor for the cropped shape (retail CdmCropFactor: 10 % per side).
function CDM.CropPercent(bd)
	local pct = tonumber(bd and bd.iconCropPercent) or 10
	if pct < 5 then pct = 5 elseif pct > 25 then pct = 25 end
	return pct
end

function CDM.IconDims(bd, size)
	size = size or BV(bd, "iconSize")
	if bd.iconShape == "cropped" then
		return size, floor(size * (1 - 2 * CDM.CropPercent(bd) / 100) + 0.5)
	end
	return size, size
end

-- Applies the bar's look to an icon (retail RefreshCDMIconAppearance).
function CDM.StyleIcon(f, bd, w, h)
	f._bd = bd
	f:SetSize(w, h)
	local bs = BV(bd, "borderSize") or 1
	if bd.borderThickness == "none" then bs = 0 end
	local br, bg, bb, ba = bd.borderR or 0, bd.borderG or 0, bd.borderB or 0, bd.borderA or 1
	if bd.borderClassColor then br, bg, bb = ClassRGB() end
	local b = f.borders
	for i = 1, 4 do
		b[i]:SetVertexColor(br, bg, bb, ba)
		b[i]:ClearAllPoints()
		b[i]:SetShown(bs > 0)
	end
	if bs > 0 then
		b[1]:SetPoint("TOPLEFT"); b[1]:SetPoint("TOPRIGHT"); b[1]:SetHeight(bs)
		b[2]:SetPoint("BOTTOMLEFT"); b[2]:SetPoint("BOTTOMRIGHT"); b[2]:SetHeight(bs)
		b[3]:SetPoint("TOPLEFT"); b[3]:SetPoint("BOTTOMLEFT"); b[3]:SetWidth(bs)
		b[4]:SetPoint("TOPRIGHT"); b[4]:SetPoint("BOTTOMRIGHT"); b[4]:SetWidth(bs)
	end
	f.bg:SetVertexColor(bd.bgR or 0.08, bd.bgG or 0.08, bd.bgB or 0.08, BV(bd, "bgA"))
	f.tex:ClearAllPoints()
	f.tex:SetPoint("TOPLEFT", bs, -bs)
	f.tex:SetPoint("BOTTOMRIGHT", -bs, bs)
	local z = BV(bd, "iconZoom") or 0.08
	if bd.iconShape == "cropped" then
		local trim = CDM.CropPercent(bd) / 100
		f.tex:SetTexCoord(z, 1 - z, z + trim, 1 - z - trim)
	else
		f.tex:SetTexCoord(z, 1 - z, z, 1 - z)
	end
	f.cd:SetAlpha(BV(bd, "swipeAlpha") or 0.7)

	local key = CDM.FONT_KEY
	ns.ApplyModuleFont(f.cdText, BV(bd, "cooldownFontSize"), key)
	f.cdText:SetTextColor(BV(bd, "cooldownTextR"), BV(bd, "cooldownTextG"), BV(bd, "cooldownTextB"))
	PlaceText(f.cdText, f, bd.cooldownTextPosition, BV(bd, "cooldownTextX"), BV(bd, "cooldownTextY"))

	ns.ApplyModuleFont(f.countText, BV(bd, "stackCountSize"), key)
	f.countText:SetTextColor(BV(bd, "stackCountR"), BV(bd, "stackCountG"), BV(bd, "stackCountB"))
	PlaceText(f.countText, f, BV(bd, "stackCountPosition"), BV(bd, "stackCountX"), BV(bd, "stackCountY"))

	ns.ApplyModuleFont(f.keyText, BV(bd, "keybindSize"), key)
	f.keyText:SetTextColor(bd.keybindR or 1, bd.keybindG or 1, bd.keybindB or 1, bd.keybindA or 0.9)
	f.keyText:ClearAllPoints()
	if (bd.keybindAlign or "left") == "right" then
		f.keyText:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(BV(bd, "keybindOffsetX") or 2), BV(bd, "keybindOffsetY") or -2)
	else
		f.keyText:SetPoint("TOPLEFT", f, "TOPLEFT", BV(bd, "keybindOffsetX") or 2, BV(bd, "keybindOffsetY") or -2)
	end
	f:EnableMouse(bd.showTooltip and true or false)
	-- Only Show Numbers / Charges/Stacks Only (retail onlyShowNumbers /
	-- chargesOnly): no icon art, border or background; chargesOnly also drops
	-- the swipe (its text is cleared per update).
	local bare = bd.onlyShowNumbers or bd.chargesOnly
	f.tex:SetAlpha(bare and 0 or 1)
	f.bg:SetShown(not bare)
	if bare then
		for i = 1, 4 do b[i]:Hide() end
	end
	f.cd:SetAlpha(bd.chargesOnly and 0 or (BV(bd, "swipeAlpha") or 0.7))
	f._glowSig = nil
	StopGlow(f)
end

-- Binds an entry to an icon.
function CDM.SetIconEntry(f, e, ss)
	f._entry = e
	f._ss = ss
	f.tex:SetTexture(e.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
	f._wasOnCD = nil
	f._wasActive = nil
	f.cd._sig = nil
	f.cd:Hide()
end

-------------------------------------------------------------------------------
--  Aura cache (rebuilt on UNIT_AURA / target change)
-------------------------------------------------------------------------------
local auraPlayer, auraPlayerName = {}, {}   -- player buffs: [spellID] / [name] = { dur, exp, count }
local auraTarget, auraTargetName = {}, {}   -- target debuffs cast by the player
local auraPlayerMine = {}                   -- player buffs cast by the player, by name
CDM.auraDirty = true

local function ScanUnit(unit, filter, byID, byName, mineByName)
	wipe(byID)
	wipe(byName)
	if mineByName then wipe(mineByName) end
	if not UnitExists(unit) then return end
	for i = 1, 40 do
		local name, _, _, count, _, dur, exp, caster, _, _, sid = UnitAura(unit, i, filter)
		if not name then break end
		local a = { dur = dur or 0, exp = exp or 0, count = count or 0, caster = caster }
		if sid and not byID[sid] then byID[sid] = a end
		if not byName[name] then byName[name] = a end
		if mineByName and (caster == "player" or caster == "pet" or caster == "vehicle") and not mineByName[name] then
			mineByName[name] = a
		end
	end
end

function CDM.RefreshAuras()
	ScanUnit("player", "HELPFUL", auraPlayer, auraPlayerName, auraPlayerMine)
	ScanUnit("target", "HARMFUL|PLAYER", auraTarget, auraTargetName)
	CDM.auraDirty = false
end

-- Aura of an entry (buff on the player, else the player's debuff on the target).
local function FindAura(e)
	local sid = e.spellID
	if CDM.LUST_SET[sid] then
		for _, id in ipairs(CDM.LUST_IDS) do
			local a = auraPlayer[id]
			if a then return a end
		end
		return nil
	end
	local a = auraPlayer[sid] or auraTarget[sid]
	if a then return a end
	if e.name then return auraPlayerName[e.name] or auraTargetName[e.name] end
end
CDM.FindAura = FindAura

-- Active state of a cooldown spell: its own aura cast by the player.
local function FindOwnAura(e)
	local a = auraPlayer[e.spellID]
	if a and (a.caster == "player" or a.caster == "pet" or a.caster == "vehicle") then return a end
	a = auraTarget[e.spellID]
	if a then return a end
	if e.name then return auraPlayerMine[e.name] or auraTargetName[e.name] end
end

-- Cast-timed entries (spellDurations): start time per spellID.
CDM.timedStart = {}

-------------------------------------------------------------------------------
--  Update
-------------------------------------------------------------------------------
local function FormatTime(s)
	if s >= 3600 then return format("%dh", ceil(s / 3600)) end
	if s >= 60 then return format("%dm", ceil(s / 60)) end
	if s >= 3 then return format("%d", ceil(s)) end
	return format("%.1f", s)
end

-- Threshold text (retail per-spell thresholdSeconds / thresholdColor* /
-- thresholdDecimals): at or under N seconds the timer takes the colour and
-- one decimal. Returns text, r, g, b (nil colour = the bar's).
local function ThresholdText(left, ss)
	local n = ss and tonumber(ss.thresholdSeconds)
	if n and n > 0 and left <= n then
		local text = ss.thresholdDecimals and format("%.1f", left) or FormatTime(left)
		if ss.thresholdColorEnabled ~= false then
			return text, ss.thresholdColorR or 1, ss.thresholdColorG or 0.2, ss.thresholdColorB or 0.2
		end
		return text
	end
	return FormatTime(left)
end

-- Glow at Stacks (retail buffGlowStackEnabled / Operator / Threshold).
local STACK_CMP = {
	lt = function(a, b) return a < b end, lte = function(a, b) return a <= b end,
	eq = function(a, b) return a == b end, gte = function(a, b) return a >= b end,
	gt = function(a, b) return a > b end,
}
local function StackGlowMatch(ss, stacks)
	if not (ss and ss.buffGlowStackEnabled) then return nil end
	local cmp = STACK_CMP[ss.buffGlowStackOperator or "gte"] or STACK_CMP.gte
	local n = tonumber(ss.buffGlowStackThreshold) or 2
	return cmp(math.max(stacks or 0, 1), n)
end

local function SetSwipe(f, start, dur, reverse)
	local cd = f.cd
	if not start or not dur or dur <= 0 then
		if cd._sig then
			cd._sig = nil
			cd:SetCooldown(0, 0)
			cd:Hide()
		end
		return
	end
	local sig = start .. ":" .. dur .. (reverse and "r" or "")
	if cd._sig ~= sig then
		cd._sig = sig
		cd:SetReverse(reverse and true or false)
		cd:Show()
		cd:SetCooldown(start, dur)
	end
end

-- GCD info: start, duration of the global cooldown right now.
local function GCDInfo()
	local s, d = GetSpellCooldown(GCD_SPELL)
	return s or 0, d or 0
end

-- Cooldown of an entry: start, duration, charges, maxCharges, chargeStart, chargeDur
local function EntryCooldown(e)
	if e.kind == "spell" then
		local s, d = GetSpellCooldown(e.spellID)
		local c, mc, cs, cdur = GetSpellCharges(e.spellID)
		return s or 0, d or 0, c, mc, cs, cdur
	elseif e.kind == "item" then
		local s, d = GetItemCooldown(e.itemID)
		return s or 0, d or 0
	elseif e.kind == "slot" then
		local s, d = GetInventoryItemCooldown("player", e.slot)
		return s or 0, d or 0
	end
	return 0, 0
end

-- Updates one icon. Returns true when the icon wants its slot shown
-- (false = hidden; the bar collapses or keeps the slot by the caller's rules).
function CDM.UpdateIcon(f, now, inCombat, glowsAllowed)
	local e, bd, ss = f._entry, f._bd, f._ss
	if not e or not bd then return false end
	now = now or GetTime()
	local text, count = "", nil
	local textR, textG, textB
	local desat, alpha, tintR, tintG, tintB = false, 1, 1, 1, 1
	local glowStyle, gr, gg, gb
	local show = true
	f._placeholder = nil

	if e.kind == "buff" or e.kind == "timed" then
		-- Aura tracking (Buffs bars, hosted buffs, cast-timed custom auras).
		local active, start, dur, stacks
		if e.kind == "timed" then
			local t0 = CDM.timedStart[e.spellID]
			if t0 and now < t0 + e.duration then
				active, start, dur = true, t0, e.duration
			end
		else
			local a = FindAura(e)
			if a then
				active = true
				stacks = a.count
				if a.dur and a.dur > 0 then start, dur = a.exp - a.dur, a.dur end
			end
		end
		if active then
			SetSwipe(f, start, dur, not (ss and ss.reverseSwipe))
			if dur and bd.showCooldownText ~= false then
				local left = start + dur - now
				if left > 0 then text, textR, textG, textB = ThresholdText(left, ss) end
			end
			if stacks and stacks > 1 then count = stacks end
			-- Glow at Stacks replaces the Buff Glow: glows only while the stack
			-- count matches (the spell's Buff Glow style, else Pixel Glow).
			local stackMatch = StackGlowMatch(ss, stacks)
			if stackMatch ~= nil then
				if stackMatch then
					glowStyle = (ss.buffGlow and ss.buffGlow > 0) and ss.buffGlow or 1
					gr, gg, gb = SettingColor(ss, "buffGlow", 1, 0.82, 0.1)
				end
			-- Buff glow (per spell), else the bar's custom buff glow.
			elseif ss and ss.buffGlow and ss.buffGlow > 0 then
				glowStyle = ss.buffGlow
				gr, gg, gb = SettingColor(ss, "buffGlow", 1, 0.82, 0.1)
			elseif bd.buffGlowMode == "custom" and (bd.buffGlowType or 0) > 0 then
				glowStyle = bd.buffGlowType
				if bd.buffGlowClassColor then gr, gg, gb = ClassRGB()
				else gr, gg, gb = bd.buffGlowR or 1, bd.buffGlowG or 1, bd.buffGlowB or 1 end
			end
			-- Pandemic glow: the last 30 % of the aura.
			if not glowStyle and bd.pandemicGlow and dur and dur > 0 and (start + dur - now) <= dur * 0.3 then
				local st = bd.pandemicGlowStyle or 1
				if st < 1 then st = 1 end
				glowStyle = st
				local c = bd.pandemicGlowMode == "custom" and bd.pandemicGlowColor
				if c then gr, gg, gb = c.r or 1, c.g or 1, c.b or 0 else gr, gg, gb = 1, 1, 0 end
			end
			if not f._wasActive and ss and ss.buffActiveSoundKey then CDM.PlaySoundKey(ss.buffActiveSoundKey) end
			f._wasActive = true
		else
			local lostKey = ss and (ss.buffLostSoundKey or ss.buffInactiveSoundKey)
			if f._wasActive and lostKey then CDM.PlaySoundKey(lostKey) end
			f._wasActive = false
			SetSwipe(f)
			local always = bd.showInactiveBuffIcons
			local ov = ss and ss.alwaysShow
			if ov == "on" or ov == "missing" then always = true elseif ov == "off" then always = false end
			if always then
				local dz = ss and ss.desatInactive
				if dz == "on" or (dz ~= "off" and bd.desaturateInactiveBuffs ~= false) then desat = true end
				alpha = 0.5
				f._placeholder = true
			elseif bd.hidePlaceholderIcon == true and CDM.IsBuffBar(bd) then
				-- Keep Buffs in Same Place: the slot stays, empty.
				alpha = 0
				f._placeholder = true
			else
				show = false
			end
		end
	else
		-- Cooldowns (spells, items, trinket slots).
		local s, d, charges, maxCharges, cs, cdur = EntryCooldown(e)
		local gs, gd = GCDInfo()
		local isGCD = d > 0 and gd > 0 and s == gs and d == gd
		local onCD = d > 1.5 and not isGCD
		local recharging = charges and maxCharges and maxCharges > 1 and charges < maxCharges
		local hasCharges = maxCharges and maxCharges > 1 and charges and charges > 0
		if maxCharges and maxCharges > 1 then
			-- Charges: the swipe shows the recharge; "on cooldown" = no charge left.
			onCD = charges == 0
			if bd.showCharges ~= false and not (ss and ss.hideChargeText) then
				if charges > 0 or not bd.hideZeroChargeText then count = charges end
			end
		end
		-- Per-spell swipe / text switches (retail charge and swipe options).
		local hideSwipe = ss and ss.hideCDSwipe
		local hideRechargeSwipe = hideSwipe or (ss and ss.chargeHideSwipe and hasCharges)
		local hideRechargeText = ss and ss.chargeHideCdText and hasCharges
		-- Active state (the spell's own aura is up).
		local aura = e.kind == "spell" and FindOwnAura(e) or nil
		local activeSwipe = aura and (ss == nil or ss.activeSwipeMode ~= "none") and bd.activeStateAnim ~= "none"
		if activeSwipe and aura.dur > 0 then
			SetSwipe(f, aura.exp - aura.dur, aura.dur, true)
			if bd.showCooldownText ~= false then
				local left = aura.exp - now
				if left > 0 then text, textR, textG, textB = ThresholdText(left, ss) end
			end
		elseif onCD then
			if hideSwipe then SetSwipe(f) else SetSwipe(f, s, d, ss and ss.reverseSwipe) end
			if bd.showCooldownText ~= false then
				local left = s + d - now
				if left > 0 then text, textR, textG, textB = ThresholdText(left, ss) end
			end
		elseif recharging and cs and cdur and cdur > 0 then
			if hideRechargeSwipe then SetSwipe(f) else SetSwipe(f, cs, cdur, ss and ss.reverseSwipe) end
			if bd.showCooldownText ~= false and not hideRechargeText then
				local left = cs + cdur - now
				if left > 0 then text, textR, textG, textB = ThresholdText(left, ss) end
			end
		elseif isGCD and not bd.suppressGCD and not (ss and ss.suppressGCD) and not hideSwipe then
			SetSwipe(f, s, d)
		else
			SetSwipe(f)
		end
		-- Stay Hidden While Charges Remain (retail chargeHideUntilSpent): the
		-- slot stays empty while a charge is banked.
		if ss and ss.chargeHideUntilSpent and hasCharges then
			alpha = 0
			f._placeholder = true
		end
		if onCD and bd.desaturateOnCD ~= false and not (ss and ss.noDesatOnCD) then desat = true end
		-- Non Active State: desaturated while the spell's own aura is not up.
		if ss and ss.desatNotActive and not aura then desat = true end

		-- Usable / range colouring.
		if e.kind == "spell" then
			local usable, noMana = IsUsableSpell(e.spellID)
			-- Ignore Resource Cost (retail noResourceTint): full colour without the resource.
			if noMana and not (ss and ss.noResourceTint) then
				tintR, tintG, tintB = 0.5, 0.5, 1
			elseif not usable and not onCD and not noMana then
				tintR, tintG, tintB = 0.4, 0.4, 0.4
			end
			if (bd.outOfRangeOverlay or (ss and ss.outOfRangeColoring)) and e.name and UnitExists("target") then
				if IsSpellInRange(e.name, "target") == 0 then tintR, tintG, tintB = 0.8, 0.1, 0.1 end
			end
		elseif e.kind == "item" then
			local n = GetItemCount(e.itemID, false, true) or 0
			if bd.showItemCount ~= false then count = n end
			if n == 0 then desat = true end
		end

		-- Glows: proc (spell activation overlay), active state, CD ready.
		if e.kind == "spell" and IsSpellOverlayed(e.spellID) and not (ss and ss.procGlow == 0) then
			glowStyle = (ss and ss.procGlow and ss.procGlow > 0) and ss.procGlow or CDM.PROC_GLOW_DEFAULT
			gr, gg, gb = SettingColor(ss, "procGlow", 1, 0.788, 0.137)
		elseif aura and ss and ss.activeGlow and ss.activeGlow > 0 then
			glowStyle = ss.activeGlow
			gr, gg, gb = SettingColor(ss, "activeGlow", 1, 0.85, 0)
		end

		-- Cooldown-state effects (retail CD_STATE_HIDE + ready glows).
		local eff = ss and ss.cdStateEffect
		if eff then
			local ready = not onCD
			if eff == "hiddenReady" or eff == "hiddenReadyShift" then
				if ready and not aura then show = false end
			elseif eff == "hiddenOnCD" or eff == "hiddenOnCDShift" then
				if not ready then show = false end
			elseif eff == "hiddenUnusable" or eff == "hiddenUnusableShift" then
				if not ready or (e.kind == "spell" and not IsUsableSpell(e.spellID)) then show = false end
			elseif eff == "pixelGlowReady" or eff == "buttonGlowReady" or eff == "glowReady" or eff == "pixelGlowReadyUsable" then
				if ready and not glowStyle and (eff ~= "pixelGlowReadyUsable" or e.kind ~= "spell" or IsUsableSpell(e.spellID)) then
					local st = ss.cdStateGlowStyle
					if type(st) ~= "number" then st = (eff == "buttonGlowReady" or eff == "glowReady") and 2 or 1 end
					glowStyle = st
					gr, gg, gb = SettingColor(ss, "cdStateGlow", 1, 1, 1)
				end
			end
			if eff == "lowerAlphaOnCD" and not ready then
				alpha = ss.cdStateLowerAlpha or 0.5
			elseif eff == "glowOnCD" and not ready and not glowStyle then
				local st = ss.cdStateGlowStyle
				if type(st) ~= "number" then st = 1 end
				glowStyle = st
				gr, gg, gb = SettingColor(ss, "cdStateGlow", 1, 1, 1)
			end
			if not show and (eff == "hiddenReady" or eff == "hiddenOnCD" or eff == "hiddenUnusable") then
				-- Non-shift effects keep the slot (alpha 0).
				f._placeholder = true
				show = true
				alpha = 0
			end
		end
		-- CD ready sound.
		if f._wasOnCD and not onCD and ss and ss.cdReadySoundKey then CDM.PlaySoundKey(ss.cdReadySoundKey) end
		f._wasOnCD = onCD
	end

	-- Paint.
	f.tex:SetDesaturated(desat)
	f.tex:SetVertexColor(tintR, tintG, tintB)
	-- Show Charge/Stack Text (bar showChargeStackText, per-spell override).
	local showCount = bd.showChargeStackText ~= false
	if ss and ss.showChargeStackText ~= nil then showCount = ss.showChargeStackText end
	if not showCount then count = nil end
	-- Only Show Numbers: the timer alone. Charges/Stacks Only: the count alone.
	if bd.chargesOnly then text = "" end
	f.cdText:SetText(text)
	if textR then
		f.cdText:SetTextColor(textR, textG, textB)
	else
		f.cdText:SetTextColor(BV(bd, "cooldownTextR"), BV(bd, "cooldownTextG"), BV(bd, "cooldownTextB"))
	end
	f.countText:SetText(count and tostring(count) or "")
	if bd.showKeybind then
		f.keyText:SetText(CDM.KeyFor(e))
	else
		f.keyText:SetText("")
	end
	f._alpha = alpha
	if glowStyle and glowsAllowed and alpha > 0 then
		StartGlow(f, "g", glowStyle, gr, gg, gb)
	else
		StopGlow(f)
	end
	return show
end
