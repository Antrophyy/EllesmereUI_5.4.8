-------------------------------------------------------------------------------
--  EUI_Nameplates_Auras.lua
--
--  Debuffs, enemy buffs and crowd control on the plate (retail Core
--  Positions: debuffSlot / buffSlot / ccSlot in the slots top, left, right,
--  topleft, topright, bottom, with slot size, offsets, growth, raise strata,
--  spacing, cropped icons, duration and stack texts, pandemic and dispel
--  glows).
--  5.4.8: UnitAura works only on unit tokens, so the auras are read while the
--  plate has one (target, mouseover, focus, boss, arena, group) and kept by
--  GUID; the combat log removes them, and re-applies auras of the player
--  whose duration is already known. A plate without a GUID shows no auras.
--  Retail's 12.1 aura groups and filter presets are not in 5.4.8: the
--  include / exclude lists of npAuraFilters are read as spell ID lists.
-------------------------------------------------------------------------------
local addonName, P = ...
local ns, ENP = P.ns, P.ENP
local defaults = P.defaults
local Plate = P.Plate

local floor, max, min = math.floor, math.max, math.min
local format = string.format
local GetTime = GetTime
local UnitAura = UnitAura
local pairs, ipairs = pairs, ipairs

-------------------------------------------------------------------------------
--  Crowd control spells (Mists of Pandaria): stuns, incapacitates,
--  disorients, fears, roots, silences, Cyclone.
-------------------------------------------------------------------------------
local CC = {}
for _, id in ipairs({
	-- stuns
	408, 1833, 853, 105593, 119072, 20549, 132168, 132169, 5211, 22570, 9005, 102546, 89766, 30283,
	22703, 108194, 91800, 91797, 115001, 119381, 120086, 122242, 24394, 90337, 117526, 44572, 118905,
	113801, 96201, 118895, 7922, 50519, 56626, 126246, 126355, 126423,
	-- incapacitate / disorient / sleep
	118, 28271, 28272, 61305, 61721, 61780, 126819, 51514, 20066, 6770, 2094, 9484, 88625, 99, 3355,
	19386, 82691, 115078, 137460, 31661, 105421, 710, 6358, 115268, 2637, 76780, 1776, 107079, 19503,
	33786, 113506, 1499, 60192, 123393,
	-- fears / horror
	5782, 118699, 5484, 6789, 8122, 5246, 20511, 10326, 145067, 1513, 64044, 113792, 87204, 104045,
	-- roots
	339, 122, 33395, 64695, 63685, 96294, 102359, 116706, 136634, 105771, 45334, 19185, 113770, 127797,
	-- silences
	15487, 1330, 47476, 34490, 102051, 31935, 81261, 24259, 115782, 55021, 18498, 137143,
}) do
	CC[id] = true
end
ENP.CC_SPELLS = CC

local CAN_PURGE = { SHAMAN = true, PRIEST = true, MAGE = true, HUNTER = true, WARLOCK = true }
local canPurge = CAN_PURGE[P.PLAYER_CLASS] or false

-------------------------------------------------------------------------------
--  Aura cache by GUID
-------------------------------------------------------------------------------
local cache = {}        -- [guid] = { debuffs = {...}, buffs = {...}, cc = {...}, at = time }
local durations = {}    -- [spellId] = last seen full duration (player auras and CC)
ENP.auraCache = cache

local function Filters()
	local f = P.Profile().npAuraFilters
	return type(f) == "table" and f or {}
end

local function InList(list, id)
	return type(list) == "table" and id and list[id] == true
end

local function NewEntry(name, icon, count, dtype, duration, expires, caster, stealable, id)
	return {
		name = name, icon = icon, count = count or 0, dtype = dtype, duration = duration or 0,
		expires = expires or 0, caster = caster, stealable = stealable, id = id,
	}
end

local function IsMine(caster)
	return caster == "player" or caster == "pet" or caster == "vehicle"
end

-- Reads all auras of a unit token into the cache entry of its GUID.
function P.ScanAuras(unit)
	local guid = UnitGUID(unit)
	if not guid then return nil end
	local p = P.Profile()
	local f = Filters()
	local e = cache[guid]
	if not e then
		e = {}
		cache[guid] = e
	end
	local debuffs, buffs, ccs = {}, {}, {}
	local showAll = p.showAllDebuffs == true
	local ccAsDebuff = (p.ccSlot or "right") == "none"
	for i = 1, 40 do
		local name, _, icon, count, dtype, duration, expires, caster, stealable, _, id = UnitAura(unit, i, "HARMFUL")
		if not name then break end
		local mine = IsMine(caster)
		if mine and duration and duration > 0 then durations[id] = duration end
		local isCC = (CC[id] or InList(f.ccInclude, id)) and not InList(f.ccExclude, id)
		if isCC and (mine or InList(f.ccIncludeAnyCaster, id) or CC[id]) and not ccAsDebuff then
			if duration and duration > 0 then durations[id] = duration end
			ccs[#ccs + 1] = NewEntry(name, icon, count, dtype, duration, expires, caster, stealable, id)
		elseif not InList(f.exclude, id) then
			if showAll or mine or InList(f.includeAnyCaster, id) then
				debuffs[#debuffs + 1] = NewEntry(name, icon, count, dtype, duration, expires, caster, stealable, id)
			end
		end
	end
	if UnitCanAttack("player", unit) then
		local mode = p.npEnemyBuffFilter or "important"
		for i = 1, 40 do
			local name, _, icon, count, dtype, duration, expires, caster, stealable, _, id = UnitAura(unit, i, "HELPFUL")
			if not name then break end
			local show
			if mode == "showall" then
				show = true
			elseif mode == "dispellable" then
				show = stealable or (dtype == "Magic" and canPurge)
			else
				show = stealable or dtype == "Magic"
			end
			if show then
				buffs[#buffs + 1] = NewEntry(name, icon, count, dtype, duration, expires, caster, stealable, id)
			end
		end
	end
	e.debuffs, e.buffs, e.cc, e.at = debuffs, buffs, ccs, GetTime()
	return e
end

-- Combat log: removal everywhere, re-application of auras with a known
-- duration (the plate's next unit token scan corrects everything).
function P.AuraCombatLog(sub, srcGUID, dstGUID, spellId, spellName, auraType)
	local e = cache[dstGUID]
	if sub == "UNIT_DIED" or sub == "UNIT_DESTROYED" then
		cache[dstGUID] = nil
		return true
	end
	if not e then return false end
	if sub == "SPELL_AURA_REMOVED" then
		for _, list in ipairs({ e.debuffs, e.buffs, e.cc }) do
			for i = #list, 1, -1 do
				if list[i].id == spellId then
					table.remove(list, i)
				end
			end
		end
		return true
	elseif sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REFRESH" or sub == "SPELL_AURA_APPLIED_DOSE" then
		local dur = durations[spellId]
		if not dur or auraType ~= "DEBUFF" then return false end
		local mine = srcGUID == UnitGUID("player") or srcGUID == UnitGUID("pet")
		local list
		if CC[spellId] then
			list = e.cc
		elseif mine then
			list = e.debuffs
		else
			return false
		end
		local now = GetTime()
		for _, a in ipairs(list) do
			if a.id == spellId and (not mine or IsMine(a.caster)) then
				a.expires = now + dur
				a.duration = dur
				if sub == "SPELL_AURA_APPLIED_DOSE" then a.count = (a.count or 0) + 1 end
				return true
			end
		end
		if sub == "SPELL_AURA_APPLIED" then
			local _, _, icon = GetSpellInfo(spellId)
			list[#list + 1] = NewEntry(spellName, icon, 0, nil, dur, now + dur, mine and "player" or nil, false, spellId)
			return true
		end
	end
	return false
end

function P.WipeAuraCache()
	wipe(cache)
end

-------------------------------------------------------------------------------
--  Icons
-------------------------------------------------------------------------------
local function KindKey(kind)
	return kind == "debuffs" and "debuff" or kind == "buffs" and "buff" or "cc"
end

local function DurationCfg(kind)
	local p = P.Profile()
	local k = KindKey(kind)
	local size = p[k .. "DurationTextSize"] or p.auraDurationTextSize or 11
	local x = p[k .. "DurationTextX"] or p.auraDurationTextX or 0
	local y = p[k .. "DurationTextY"] or p.auraDurationTextY or 0
	local c = p[k .. "DurationTextColor"] or p.auraDurationTextColor or defaults.auraDurationTextColor
	local pos = p[k .. "TimerPosition"] or p.auraTextPosition or "topleft"
	return size, x, y, c, pos
end

local POS = {
	topleft = { "TOPLEFT", 1, -1, "LEFT" }, topright = { "TOPRIGHT", -1, -1, "RIGHT" },
	bottomleft = { "BOTTOMLEFT", 1, 1, "LEFT" }, bottomright = { "BOTTOMRIGHT", -1, 1, "RIGHT" },
	center = { "CENTER", 0, 0, "CENTER" },
}

local function CreateIcon(row)
	local b = CreateFrame("Frame", nil, row)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetPoint("TOPLEFT", 1, -1)
	b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints()
	b.bg:SetTexture(0, 0, 0, 1)
	b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
	b.cd:SetAllPoints(b.icon)
	b.cd:SetReverse(true)
	if b.cd.SetHideCountdownNumbers then b.cd:SetHideCountdownNumbers(true) end
	b.cd.noCooldownCount = true
	b.textFrame = CreateFrame("Frame", nil, b)
	b.textFrame:SetAllPoints()
	b.textFrame:SetFrameLevel(b.cd:GetFrameLevel() + 2)
	b.timer = P.NewText(b.textFrame, 11)
	b.count = P.NewText(b.textFrame, 11)
	b.glowFrame = CreateFrame("Frame", nil, b)
	b.glowFrame:SetPoint("TOPLEFT", -2, 2)
	b.glowFrame:SetPoint("BOTTOMRIGHT", 2, -2)
	b.glowFrame:SetFrameLevel(b.cd:GetFrameLevel() + 1)   -- under the text
	b.glow = P.CreateEdges(b.glowFrame, b.glowFrame, "OVERLAY", 7)
	b.glowFrame:Hide()
	return b
end

local function ApplyIconStyle(b, kind, w, h)
	local p = P.Profile()
	b:SetSize(w, h)
	local k = KindKey(kind)
	local cropped = p[k .. "CropIcons"]
	local z = 0.08
	if cropped then
		local uSpan = 1 - 2 * z
		local vSpan = uSpan * (h / w)
		local v0 = 0.5 - vSpan / 2
		b.icon:SetTexCoord(z, 1 - z, v0, 1 - v0)
	else
		b.icon:SetTexCoord(z, 1 - z, z, 1 - z)
	end
	local noBorder = p["hide" .. (kind == "debuffs" and "Debuff" or kind == "buffs" and "Buff" or "CC") .. "IconBorder"]
	if noBorder then
		b.icon:SetPoint("TOPLEFT", 0, 0)
		b.icon:SetPoint("BOTTOMRIGHT", 0, 0)
		b.bg:Hide()
	else
		b.icon:SetPoint("TOPLEFT", 1, -1)
		b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
		b.bg:Show()
	end
	local size, x, y, c, pos = DurationCfg(kind)
	P.SetFont(b.timer, size, P.IconOutline())
	b.timer:SetTextColor(c.r, c.g, c.b, 1)
	b.timer:ClearAllPoints()
	local tp = POS[pos]
	if tp then
		b.timer:SetPoint(tp[1], b, tp[1], tp[2] + x, tp[3] + y)
		b.timer:SetJustifyH(tp[4])
		b.showTimer = true
	else
		b.showTimer = false
	end
	local spos = p.auraStackTextPosition or "bottomright"
	P.SetFont(b.count, p.auraStackTextSize or 11, P.IconOutline())
	local sc = p.auraStackTextColor or defaults.auraStackTextColor
	b.count:SetTextColor(sc.r, sc.g, sc.b, 1)
	b.count:ClearAllPoints()
	local spp = POS[spos]
	if spp then
		b.count:SetPoint(spp[1], b, spp[1], spp[2] + (p.auraStackTextX or 0), spp[3] + (p.auraStackTextY or 0))
		b.showCount = true
	else
		b.showCount = false
	end
end

local function FormatTime(left)
	if left >= 3600 then
		return format("%dh", floor(left / 3600 + 0.5))
	elseif left >= 60 then
		return format("%dm", floor(left / 60 + 0.5))
	elseif left >= 10 then
		return format("%d", floor(left))
	end
	return format("%.0f", left)
end

-------------------------------------------------------------------------------
--  Rows
-------------------------------------------------------------------------------
local KINDS = { "debuffs", "buffs", "cc" }

function P.BuildAuras(plate)
	plate.auraRows = {}
	plate.slotRows = {}
	for _, kind in ipairs(KINDS) do
		local row = CreateFrame("Frame", nil, plate)
		row:SetSize(1, 1)
		row.kind = kind
		row.icons = {}
		row.count = 0
		plate.auraRows[kind] = row
	end
end

local function SlotOf(kind)
	local p = P.Profile()
	if kind == "debuffs" then return p.debuffSlot or "top" end
	if kind == "buffs" then return p.buffSlot or "left" end
	return p.ccSlot or "right"
end

local function SpacingOf(kind)
	local p = P.Profile()
	if kind == "debuffs" then return p.debuffSpacing or 2 end
	if kind == "buffs" then return p.buffSpacing or 2 end
	return p.ccSpacing or 2
end

function Plate:ApplyAuraLayout()
	local p = P.Profile()
	wipe(self.slotRows)
	for _, kind in ipairs(KINDS) do
		local row = self.auraRows[kind]
		local slot = SlotOf(kind)
		row.slot = slot
		if slot ~= "none" then
			self.slotRows[slot] = row
		end
		local size = P.SlotSize(slot ~= "none" and slot or "top")
		local cropped = p[KindKey(kind) .. "CropIcons"]
		local h = size
		if cropped then
			local pct = tonumber(p[KindKey(kind) .. "CropPercent"]) or 10
			pct = max(5, min(25, pct))
			h = floor(size * (1 - 2 * pct / 100) + 0.5)
		end
		row.iconW, row.iconH = size, h
		for _, b in ipairs(row.icons) do
			ApplyIconStyle(b, kind, size, h)
		end
		local base = self.blizz:GetFrameStrata()
		if slot ~= "none" and p[slot .. "SlotRaiseStrata"] then
			row:SetFrameStrata(P.RaisedStrata(base))
		else
			row:SetFrameStrata(base)
		end
	end
	self:LayoutAuras()
end

-- The anchor above the health bar for top rows: the top text when one is
-- set (retail TopAnchorFor).
local function TopAnchor(plate)
	local fs = plate.texts.textSlotTop
	if fs and fs.element and fs.element ~= "none" and fs:IsShown() and not plate.nameOnly then
		return fs
	end
	return plate.health
end

local function PlaceRow(plate, row)
	local p = P.Profile()
	local slot = row.slot
	local n = row.count
	local w, h = row.iconW or 24, row.iconH or 24
	local sp = SpacingOf(row.kind)
	local xo, yo = P.SlotOffsets(slot)
	local health = plate.health
	row:ClearAllPoints()
	if n == 0 or slot == "none" then
		row:Hide()
		return
	end
	local total = n * w + (n - 1) * sp
	local growth, vertical = "right", false
	if slot == "top" then
		local anchor = TopAnchor(plate)
		row:SetSize(total, h)
		row:SetPoint("BOTTOM", anchor, "TOP", xo, (p.debuffYOffset or 2) + yo)
	elseif slot == "bottom" then
		row:SetSize(total, h)
		row:SetPoint("TOP", (plate.castShown and plate.cast) or health, "BOTTOM", xo, -2 + yo)
	elseif slot == "left" then
		row:SetSize(total, h)
		row:SetPoint("BOTTOMRIGHT", health, "BOTTOMLEFT", -(p.sideAuraXOffset or 2) + xo, yo)
		growth = "left"
	elseif slot == "right" then
		row:SetSize(total, h)
		row:SetPoint("BOTTOMLEFT", health, "BOTTOMRIGHT", (p.sideAuraXOffset or 2) + xo, yo)
	else -- topleft / topright
		growth = p[slot .. "SlotGrowth"] or (slot == "topleft" and "left" or "right")
		local corner = slot == "topleft" and "BOTTOMLEFT" or "BOTTOMRIGHT"
		local hc = slot == "topleft" and "TOPLEFT" or "TOPRIGHT"
		if growth == "up" then
			vertical = true
			row:SetSize(w, n * h + (n - 1) * sp)
		else
			row:SetSize(total, h)
		end
		row:SetPoint(corner, health, hc, xo, (p.debuffYOffset or 2) + yo)
		-- "left" growth from the top-left corner runs out over the left edge.
		if slot == "topleft" and growth == "left" then
			row:ClearAllPoints()
			row:SetPoint("BOTTOMRIGHT", health, "TOPLEFT", w + xo, (p.debuffYOffset or 2) + yo)
		elseif slot == "topright" and growth == "right" then
			row:ClearAllPoints()
			row:SetPoint("BOTTOMLEFT", health, "TOPRIGHT", -w + xo, (p.debuffYOffset or 2) + yo)
		end
	end
	for i = 1, n do
		local b = row.icons[i]
		b:ClearAllPoints()
		if vertical then
			local side = slot == "topleft" and "LEFT" or "RIGHT"
			b:SetPoint("BOTTOM" .. side, row, "BOTTOM" .. side, 0, (i - 1) * (h + sp))
		elseif growth == "left" then
			b:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -(i - 1) * (w + sp), 0)
		else
			b:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", (i - 1) * (w + sp), 0)
		end
	end
	row.first = row.icons[1]
	row.last = row.icons[n]
	if growth == "left" then
		row.first, row.last = row.icons[n], row.icons[1]
	end
	row:Show()
end

function Plate:LayoutAuras()
	for _, kind in ipairs(KINDS) do
		PlaceRow(self, self.auraRows[kind])
	end
end

local function Fill(plate, row, list, cap)
	local now = GetTime()
	local n = 0
	local kind = row.kind
	local p = P.Profile()
	if list then
		for _, a in ipairs(list) do
			if n >= cap then break end
			if a.expires == 0 or a.expires > now then
				n = n + 1
				local b = row.icons[n]
				if not b then
					b = CreateIcon(row)
					row.icons[n] = b
					ApplyIconStyle(b, kind, row.iconW or 24, row.iconH or 24)
				end
				b.aura = a
				b.icon:SetTexture(a.icon)
				if a.duration and a.duration > 0 and a.expires > 0 then
					b.cd:SetCooldown(a.expires - a.duration, a.duration)
					b.cd:Show()
				else
					b.cd:Hide()
				end
				if b.showCount and (a.count or 0) > 1 then
					b.count:SetText(a.count)
					b.count:Show()
				else
					b.count:Hide()
				end
				-- Glows: pandemic (own debuffs in their last 30%) and dispel
				-- (purgeable enemy buffs).
				local glow
				if kind == "debuffs" and p.pandemicGlow and a.duration > 0 and a.expires > 0
					and (a.expires - now) <= a.duration * 0.3 then
					glow = p.pandemicGlowColor or defaults.pandemicGlowColor
				elseif kind == "buffs" and p.dispelGlow and (a.stealable or a.dtype == "Magic") then
					glow = p.dispelGlowColor or defaults.dispelGlowColor
				end
				if glow then
					P.LayoutEdges(b.glow, p.pandemicGlowThickness or 1, glow.r, glow.g, glow.b, 1)
					b.glowFrame:Show()
				else
					b.glowFrame:Hide()
				end
				b:Show()
			end
		end
	end
	for i = n + 1, #row.icons do
		row.icons[i]:Hide()
		row.icons[i].aura = nil
	end
	row.count = n
	PlaceRow(plate, row)
end

function Plate:UpdateAuras()
	if not self.auraRows then return end
	local e
	if self.unit and not self.isFriendly then
		e = P.ScanAuras(self.unit)
	elseif self.guid then
		e = cache[self.guid]
	end
	if self.isFriendly or self.nameOnly or self.hiddenPlate then
		e = nil
	end
	local p = P.Profile()
	Fill(self, self.auraRows.debuffs, e and e.debuffs, p.maxDebuffs or 5)
	Fill(self, self.auraRows.buffs, e and e.buffs, 4)
	Fill(self, self.auraRows.cc, e and e.cc, 3)
	self:UpdateAuraTimers()
	if self.isTarget and p.showTargetArrows then self:PlaceArrows() end
end

-- Duration texts and expiry (every 0.2 s from the plate driver).
function Plate:UpdateAuraTimers()
	local now = GetTime()
	local expired = false
	for _, kind in ipairs(KINDS) do
		local row = self.auraRows[kind]
		for i = 1, row.count do
			local b = row.icons[i]
			local a = b.aura
			if a and a.expires > 0 then
				local left = a.expires - now
				if left <= 0 then
					expired = true
				elseif b.showTimer then
					b.timer:SetText(FormatTime(left))
					b.timer:Show()
				else
					b.timer:Hide()
				end
			else
				b.timer:Hide()
			end
		end
	end
	if expired then
		self:UpdateAuras()
	end
end

function Plate:ClearAuras()
	for _, kind in ipairs(KINDS) do
		local row = self.auraRows[kind]
		for _, b in ipairs(row.icons) do
			b:Hide()
			b.aura = nil
		end
		row.count = 0
		row:Hide()
	end
end
