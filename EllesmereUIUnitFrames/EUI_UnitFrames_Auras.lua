-- EllesmereUI Unit Frames for 5.4.8: buffs and debuffs. Retail uses engine
-- aura containers; here a UnitAura loop fills plain icon buttons with the
-- same layout (anchor, growth, rows, spacing) and the 5.4.8 filters.

local addonName = ...
local ns = EllesmereUI
local UF = ns.UF

local floor, min, max = math.floor, math.min, math.max
local format = format
local GetTime = GetTime

-- Container point on the icon side / frame point (EllesmereUI tables).
local ANCHOR_FP = {
	topleft = { "BOTTOMLEFT", "TOPLEFT", 0, 1 }, topright = { "BOTTOMRIGHT", "TOPRIGHT", 0, 1 },
	bottomleft = { "TOPLEFT", "BOTTOMLEFT", 0, -1 }, bottomright = { "TOPRIGHT", "BOTTOMRIGHT", 0, -1 },
	left = { "TOPRIGHT", "TOPLEFT", -1, 0 }, right = { "TOPLEFT", "TOPRIGHT", 1, 0 },
}
local AUTO_GROWTH = {
	topleft = { "RIGHT", "UP" }, topright = { "LEFT", "UP" }, bottomleft = { "RIGHT", "DOWN" },
	bottomright = { "LEFT", "DOWN" }, left = { "LEFT", "DOWN" }, right = { "RIGHT", "DOWN" },
}

-- Sated / Exhaustion debuffs are never shown.
local HIDDEN_DEBUFFS = { [57723] = true, [57724] = true, [80354] = true, [95809] = true }

-- Raid encounter debuffs (ElvUI MoP RaidDebuffs, Mogu'shan Vaults .. Siege of
-- Orgrimmar, plus Malkorok's Ancient Barriers). Some are applied with a player
-- as caster (Ancient Barrier is cast by you on yourself), so a caster test
-- would call them player auras; they always count as "Non-Player".
UF.ENCOUNTER_DEBUFFS = {}
for _, id in ipairs({
	116161, 116281, 116374, 116417, 116525, 116778, 116784, 116835, 116942, 117436, 117519, 117708, 117723,
	117878, 117949, 118048, 118091, 118135, 118163, 118303, 119086, 119775, 119985, 120629, 120669, 121949,
	122055, 122064, 122151, 122370, 122740, 122752, 122760, 122761, 122777, 122835, 123011, 123036, 123081,
	123121, 123180, 123474, 123705, 123812, 123963, 125206, 129078, 130395, 131788, 131790, 131792, 132222,
	133597, 133767, 133768, 133798, 134256, 134366, 134391, 134691, 135000, 135695, 136050, 136192, 136193,
	136228, 136295, 136478, 136512, 136587, 136654, 136708, 136710, 136719, 136722, 136753, 136767, 136857,
	136903, 136914, 136922, 136992, 137162, 137341, 137359, 137360, 137371, 137408, 137422, 137440, 137633,
	137641, 137731, 137972, 138297, 138329, 138349, 138372, 138569, 138609, 138659, 138732, 139011, 139840,
	139843, 139857, 140092, 140179, 140701, 142315, 142864, 142865, 142913, 142948, 142990, 143198, 143385,
	143431, 143434, 143436, 143480, 143494, 143579, 143638, 143701, 143766, 143767, 143773, 143777, 143780,
	143791, 143800, 143840, 143919, 143974, 143990, 144089, 144215, 144236, 144330, 144351, 144358, 144459,
	144467, 144514, 144774, 144851, 145065, 145171, 145183, 145195, 145218, 146124, 146235, 146589, 146594,
	146902, 147029, 147207, 147383,
	142862, 142863, -- Ancient Barrier, Weak Ancient Barrier (Malkorok)
}) do
	UF.ENCOUNTER_DEBUFFS[id] = true
end

-- Debuff from a player or player pet (encounter debuffs never are).
function UF.DebuffFromPlayer(caster, spellId)
	if spellId and UF.ENCOUNTER_DEBUFFS[spellId] then
		return false
	end
	return caster ~= nil and UnitPlayerControlled(caster) and true or false
end

local PREVIEW_BUFFS = { 1459, 21562, 19740, 20217, 1126, 6673 }
local PREVIEW_DEBUFFS = { { 172, "Magic" }, { 980, "Curse" }, { 589, "Magic" }, { 2818, "Poison" }, { 55095, "Disease" }, { 8921, nil } }

---------------------------------------------------------------------------
-- Icons
---------------------------------------------------------------------------
local function TimeText(left, precise)
	if left >= 3600 then
		return format("%dh", floor(left / 3600 + 0.5))
	elseif left >= 60 then
		return format("%dm", floor(left / 60 + 0.5))
	elseif precise and left < precise then
		return format("%.1f", left)
	end
	return format("%d", floor(left + 0.5))
end

local function IconOnUpdate(self, elapsed)
	self.tick = (self.tick or 0) + elapsed
	if self.tick < 0.1 then
		return
	end
	self.tick = 0
	if self.expires and self.expires > 0 then
		local left = self.expires - GetTime()
		if left > 0 then
			self.timer:SetText(TimeText(left, self.precise))
		else
			self.timer:SetText("")
		end
	end
end

local function IconOnEnter(self)
	local frame = self.frame
	if not self.index or frame.preview and UF.IsFake(frame) then
		return
	end
	local s = frame.settings
	if s.showAuraTooltips == false then
		return
	end
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
	GameTooltip:SetUnitAura(frame.unit, self.index, self.filter)
	GameTooltip:Show()
end

local function IconOnLeave()
	GameTooltip:Hide()
end

local function CreateIcon(container)
	local icon = CreateFrame("Button", nil, container)
	icon:EnableMouse(true)
	icon:RegisterForClicks("RightButtonUp")
	icon.tex = icon:CreateTexture(nil, "ARTWORK")
	icon.cd = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
	icon.cd:SetReverse(true)
	icon.cd:SetAllPoints(icon.tex)
	icon.overlay = CreateFrame("Frame", nil, icon)
	icon.overlay:SetAllPoints()
	icon.overlay:SetFrameLevel(icon.cd:GetFrameLevel() + 2)
	icon.border = UF.CreateBorder(icon.overlay, icon)
	icon.stealable = icon.overlay:CreateTexture(nil, "OVERLAY")
	icon.stealable:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Stealable")
	icon.stealable:SetBlendMode("ADD")
	icon.stealable:SetPoint("TOPLEFT", -3, 3)
	icon.stealable:SetPoint("BOTTOMRIGHT", 3, -3)
	icon.stealable:Hide()
	icon.count = UF.NewText(icon.overlay, 14, "OVERLAY", true)
	icon.timer = UF.NewText(icon.overlay, 10, "OVERLAY", true)
	icon.frame = container.frame
	icon:SetScript("OnEnter", IconOnEnter)
	icon:SetScript("OnLeave", IconOnLeave)
	icon:Hide()
	return icon
end

local function GetIcon(container, i)
	local icon = container.icons[i]
	if not icon then
		icon = CreateIcon(container)
		container.icons[i] = icon
	end
	return icon
end

function UF.CreateAuraContainers(frame)
	for _, key in ipairs({ "Buffs", "Debuffs" }) do
		local c = CreateFrame("Frame", nil, frame)
		c:SetSize(1, 1)
		c:SetFrameLevel(frame:GetFrameLevel() + 30)
		c.icons = {}
		c.frame = frame
		c.kind = key == "Buffs" and "buff" or "debuff"
		frame[key] = c
	end
end

---------------------------------------------------------------------------
-- Settings view of one container (boss "simple" mode included)
---------------------------------------------------------------------------
local function BossSimpleMode(value, isDebuff)
	if value == true then
		return "left"
	end
	if value == "left" or value == "right" then
		return value
	end
	if isDebuff and value == nil then
		return "left"
	end
	return "none"
end
UF.BossSimpleMode = BossSimpleMode

-- Resolves where and how a container draws; nil = hidden.
local function ContainerConfig(frame, kind)
	local s = frame.settings
	local p = kind -- "buff" / "debuff"
	local cfg = {}
	local simple = "none"
	if frame.isBoss then
		simple = BossSimpleMode(kind == "buff" and s.simpleBuffs or s.simpleDebuffs, kind == "debuff")
	end
	if simple ~= "none" then
		local h = frame:GetHeight()
		cfg.simple = simple
		cfg.size = h > 0 and h or (s.healthHeight or 34) + 6
		cfg.height = cfg.size
		cfg.anchor = simple == "left" and "left" or "right"
		cfg.growth = simple == "left" and "left" or "right"
		cfg.max = kind == "buff" and (s.maxBuffs or 4) or (s.maxDebuffs or 10)
		cfg.perRow = s[p .. "MaxPerRow"] or cfg.max
		cfg.offX = s[kind == "buff" and "simpleBuffOffsetX" or "simpleDebuffOffsetX"] or s[p .. "OffsetX"] or 0
		cfg.offY = s[kind == "buff" and "simpleBuffOffsetY" or "simpleDebuffOffsetY"] or s[p .. "OffsetY"] or 0
		local sp = s[kind == "buff" and "simpleBuffSpacing" or "simpleDebuffSpacing"] or 1
		cfg.spX, cfg.spY = sp, sp
		cfg.showTimer = s[kind == "buff" and "simpleBuffShowCooldownText" or "simpleDebuffShowCooldownText"]
		cfg.timerSize = s[kind == "buff" and "simpleBuffCooldownTextSize" or "simpleDebuffCooldownTextSize"] or 14
		cfg.timerX = s[kind == "buff" and "simpleBuffCooldownTextOffsetX" or "simpleDebuffCooldownTextOffsetX"] or 0
		cfg.timerY = s[kind == "buff" and "simpleBuffCooldownTextOffsetY" or "simpleDebuffCooldownTextOffsetY"] or 0
	else
		local anchor
		if kind == "buff" then
			if s.showBuffs == false then
				return nil
			end
			anchor = s.buffAnchor or "topleft"
		else
			anchor = s.debuffAnchor or "bottomleft"
		end
		if anchor == "none" then
			return nil
		end
		cfg.anchor = anchor
		cfg.growth = s[p .. "Growth"] or "auto"
		cfg.size = s[p .. "Size"] or 22
		cfg.height = s[p .. "CropIcons"] and floor(cfg.size * 0.75 + 0.5) or cfg.size
		cfg.max = kind == "buff" and (s.maxBuffs or 4) or (s.maxDebuffs or 20)
		cfg.perRow = s[p .. "MaxPerRow"] or cfg.max
		cfg.offX = s[p .. "OffsetX"] or 0
		cfg.offY = s[p .. "OffsetY"] or 0
		if frame.isBoss then
			local sp = s[p .. "Spacing"] or 1
			cfg.spX, cfg.spY = sp, sp
		else
			cfg.spX, cfg.spY = s[p .. "SpacingX"] or 1, s[p .. "SpacingY"] or 1
		end
		cfg.showTimer = s[p .. "ShowCooldownText"]
		cfg.timerSize = s[p .. "CooldownTextSize"] or 10
		cfg.timerX = s[p .. "CooldownTextOffsetX"] or 0
		cfg.timerY = s[p .. "CooldownTextOffsetY"] or 0
	end
	cfg.zoom = s[p .. "IconZoom"] or 0.07
	cfg.dispelBorder = s[p .. "DispelBorder"] and not (kind == "buff" and frame.unitKey == "player")
	cfg.stackSize = s[p .. "StackTextSize"] or 14
	cfg.stackPos = s[p .. "StackTextPosition"] or "bottomright"
	cfg.stackX = s[p .. "StackTextOffsetX"] or 0
	cfg.stackY = s[p .. "StackTextOffsetY"] or 0
	cfg.precise = s[p .. "CooldownTextPrecision"]
	cfg.timerColor = s[p .. "CooldownTextColor"]
	cfg.stackColor = s[p .. "StackTextColor"]
	cfg.max = min(40, cfg.max)
	cfg.perRow = max(1, min(cfg.perRow, cfg.max))
	return cfg
end

local STACK_POINTS = {
	bottomright = { "BOTTOMRIGHT", -1, 0 }, bottomleft = { "BOTTOMLEFT", 1, 0 },
	topright = { "TOPRIGHT", -1, 0 }, topleft = { "TOPLEFT", 1, 0 }, center = { "CENTER", 0, 0 },
}

local function StyleIcon(icon, cfg, s)
	local px = UF.Pixel()
	icon:SetSize(cfg.size, cfg.height)
	local bsize = (s.auraBorderSize or 1) * px
	icon.tex:ClearAllPoints()
	icon.tex:SetPoint("TOPLEFT", bsize, -bsize)
	icon.tex:SetPoint("BOTTOMRIGHT", -bsize, bsize)
	local z = cfg.zoom
	local vcut = 0
	if cfg.height < cfg.size then
		vcut = (1 - cfg.height / cfg.size) / 2 * (1 - 2 * z)
	end
	icon.tex:SetTexCoord(z, 1 - z, z + vcut, 1 - z - vcut)
	icon.border:SetBorderSize(bsize)
	icon.baseBorder = { s.auraBorderR or 0, s.auraBorderG or 0, s.auraBorderB or 0, s.auraBorderA or 1 }
	icon.border:SetBorderColor(unpack(icon.baseBorder))
	icon.border:SetShown(bsize > 0)
	UF.SetFont(icon.count, cfg.stackSize, true)
	local sp = STACK_POINTS[cfg.stackPos] or STACK_POINTS.bottomright
	icon.count:ClearAllPoints()
	icon.count:SetPoint(sp[1], icon, sp[1], sp[2] + cfg.stackX, sp[3] + cfg.stackY)
	local sc = cfg.stackColor
	icon.count:SetTextColor(sc and sc.r or 1, sc and sc.g or 1, sc and sc.b or 1, 1)
	UF.SetFont(icon.timer, cfg.timerSize, true)
	icon.timer:ClearAllPoints()
	icon.timer:SetPoint("CENTER", icon, "CENTER", cfg.timerX, cfg.timerY)
	local tc = cfg.timerColor
	icon.timer:SetTextColor(tc and tc.r or 1, tc and tc.g or 1, tc and tc.b or 1, 1)
	icon.timer:SetShown(cfg.showTimer and true or false)
	icon.precise = cfg.precise and cfg.precise > 0 and cfg.precise or nil
	icon:SetScript("OnUpdate", cfg.showTimer and IconOnUpdate or nil)
end

-- Places container + icons (called on layout and when the count changes).
local function PlaceContainer(frame, container, cfg, count)
	local px = UF.Pixel()
	container:ClearAllPoints()
	local fp = ANCHOR_FP[cfg.anchor]
	local cbOff = 0
	local holder = frame.Castbar
	if holder and holder.enabled and (cfg.anchor == "bottomleft" or cfg.anchor == "bottomright")
		and not (frame.unitKey == "player" and frame.settings.lockCastbarToFrame == false) then
		cbOff = -(holder:GetHeight() or 0)
	end
	container:SetPoint(fp[1], frame, fp[2], fp[3] + cfg.offX, fp[4] + cfg.offY + cbOff)
	local auto = AUTO_GROWTH[cfg.anchor]
	local g = cfg.growth
	local primary, secondary
	if g == "left" or g == "right" then
		primary, secondary = g:upper(), auto[2]
	elseif g == "up" or g == "down" then
		primary, secondary = g:upper(), auto[1]
	else
		primary, secondary = auto[1], auto[2]
	end
	local horiz = (primary == "LEFT" or primary == "RIGHT") and primary or secondary
	local vert = (primary == "UP" or primary == "DOWN") and primary or secondary
	local corner = (vert == "UP" and "BOTTOM" or "TOP") .. (horiz == "LEFT" and "RIGHT" or "LEFT")
	local stepX = cfg.size + cfg.spX * px
	local stepY = cfg.height + cfg.spY * px
	for i = 1, count do
		local icon = container.icons[i]
		local n = i - 1
		local a, b = n % cfg.perRow, floor(n / cfg.perRow)
		local col, row
		if primary == "LEFT" or primary == "RIGHT" then
			col, row = a, b
		else
			col, row = b, a
		end
		local x = col * stepX * (horiz == "LEFT" and -1 or 1)
		local y = row * stepY * (vert == "UP" and 1 or -1)
		icon:ClearAllPoints()
		icon:SetPoint(corner, container, fp[1], x, y)
	end
end

function UF.LayoutAuras(frame)
	frame.settings = UF.Settings(frame.settingsKey)
	for _, key in ipairs({ "Buffs", "Debuffs" }) do
		local container = frame[key]
		container.cfgValid = nil
		-- Icons are made out of combat (children of a secure frame).
		local cfg = ContainerConfig(frame, container.kind)
		if cfg and not InCombatLockdown() then
			for i = #container.icons + 1, cfg.max do
				GetIcon(container, i)
			end
		end
		for _, icon in ipairs(container.icons) do
			icon:Hide()
		end
	end
end

---------------------------------------------------------------------------
-- Filters
---------------------------------------------------------------------------
local function IsMine(caster)
	return caster == "player" or caster == "pet" or caster == "vehicle"
end

local function CanDispel(dtype)
	local list = UF.DISPEL_BY_CLASS[select(2, UnitClass("player"))]
	return list and dtype and list[dtype] or false
end

-- Debuff filter mode of target / focus / boss.
function UF.DebuffFilterMode(s)
	local mode = s.debuffFilterMode
	if mode == "all" or mode == "tracked" or mode == "own" or mode == "important" or mode == "importantOwn" or mode == "importantOrOwn" then
		return mode
	end
	return s.onlyPlayerDebuffs and "own" or "all"
end

local function TrackedEntry(list, spellId)
	return list and spellId and list[spellId] == true
end

local function DebuffAllowed(frame, s, spellId, caster, dtype, duration, isBoss)
	-- Hide Exhaustion (retail debuffHideExhaustion, nil = on).
	if spellId and HIDDEN_DEBUFFS[spellId] and s.debuffHideExhaustion ~= false then
		return false
	end
	if TrackedEntry(s.debuffExclude, spellId) then
		return false
	end
	local mine = IsMine(caster)
	if TrackedEntry(s.debuffInclude, spellId) then
		local mineOnly
		if frame.isBoss then
			mineOnly = not (s.debuffIncludeAnyCaster and s.debuffIncludeAnyCaster[spellId])
		else
			mineOnly = s.debuffIncludeMine and s.debuffIncludeMine[spellId]
		end
		if not mineOnly or mine then
			return true
		end
	end
	if s.debuffHasDuration and not (duration and duration > 0) then
		return false
	end
	if frame.unitKey == "player" then
		local neg = s.debuffNegClasses
		local tests = {
			CastByMe = mine, BossAura = isBoss, Dispellable = CanDispel(dtype),
			DispelTyped = dtype ~= nil and dtype ~= "", DispelMagic = dtype == "Magic", DispelCurse = dtype == "Curse",
			DispelPoison = dtype == "Poison", DispelDisease = dtype == "Disease",
			NonPlayer = not UF.DebuffFromPlayer(caster, spellId), AnyPlayer = UF.DebuffFromPlayer(caster, spellId),
		}
		if neg then
			for key, on in pairs(neg) do
				if on and tests[key] then
					return false
				end
			end
		end
		if s.debuffShowAll ~= false then
			return true
		end
		local any, all, count = false, true, 0
		for key, value in pairs(tests) do
			if s["debuff" .. key] then
				count = count + 1
				if value then
					any = true
				else
					all = false
				end
			end
		end
		if count == 0 then
			return s.debuffHasDuration and true or false
		end
		if s.debuffFilterMatch == "all" then
			return all
		end
		return any
	end
	local mode = UF.DebuffFilterMode(s)
	if mode == "tracked" then
		return false
	elseif mode == "own" then
		return mine
	elseif mode == "important" then
		return isBoss and true or false
	elseif mode == "importantOwn" then
		return mine and isBoss
	elseif mode == "importantOrOwn" then
		return mine or isBoss
	end
	return true
end

local function BuffAllowed(frame, s, spellId, caster, dtype, duration, stealable)
	if frame.unitKey == "player" then
		if s.buffBlacklist and spellId and s.buffBlacklist[spellId] then
			return false
		end
		if s.buffHasDuration then
			return duration and duration > 0
		end
		return s.buffShowAll ~= false
	end
	if s.buffDurOnly and not (duration and duration > 0) then
		return false
	end
	local tests = { Stealable = stealable and true or false, Dispellable = dtype ~= nil and dtype ~= "" }
	local neg = s.buffNegClasses
	if neg then
		for key, on in pairs(neg) do
			if on and tests[key] then
				return false
			end
		end
	end
	local anyShow = false
	local count = 0
	for key, value in pairs(tests) do
		if s["buff" .. key] then
			count = count + 1
			anyShow = anyShow or value
		end
	end
	if count == 0 then
		return true
	end
	return anyShow
end

---------------------------------------------------------------------------
-- Update
---------------------------------------------------------------------------
local function DispelColor(frame, dtype, kind)
	if not dtype or dtype == "" then
		return nil
	end
	local s = frame.settings
	if frame.unitKey == "player" and kind == "debuff" and s.debuffDispelUsePalette then
		local c = UF.db[UF.DISPEL_KEYS[dtype] or ""]
		if c then
			return c.r, c.g, c.b
		end
	end
	local c = DebuffTypeColor and DebuffTypeColor[dtype]
	if c then
		return c.r, c.g, c.b
	end
	return nil
end

local function ShowIcon(frame, container, cfg, n, data)
	local icon = GetIcon(container, n)
	if icon.styleStamp ~= container.styleStamp then
		StyleIcon(icon, cfg, frame.settings)
		icon.styleStamp = container.styleStamp
	end
	icon.index = data.index
	icon.filter = data.filter
	icon.tex:SetTexture(data.icon)
	icon.count:SetText((data.count and data.count > 1) and data.count or "")
	if data.duration and data.duration > 0 then
		CooldownFrame_SetTimer(icon.cd, data.expires - data.duration, data.duration, 1)
		icon.cd:Show()
		icon.expires = data.expires
	else
		icon.cd:Hide()
		icon.expires = nil
		icon.timer:SetText("")
	end
	local r, g, b
	if cfg.dispelBorder then
		r, g, b = DispelColor(frame, data.dtype, container.kind)
	end
	if r then
		icon.border:SetBorderColor(r, g, b, 1)
		icon.border:SetShown(true)
	else
		icon.border:SetBorderColor(unpack(icon.baseBorder))
		icon.border:SetShown((frame.settings.auraBorderSize or 1) > 0)
	end
	local glow = frame.settings.buffPurgeGlow
	icon.stealable:SetShown(container.kind == "buff" and data.stealable and glow == 99 and true or false)
	icon:Show()
end

local scratch = {}

local function Collect(frame, container, cfg)
	local unit = frame.unit
	local s = frame.settings
	local list = scratch
	wipe(list)
	if UF.IsFake(frame) or (frame.preview and UF.previewAuras) then
		local src = container.kind == "buff" and PREVIEW_BUFFS or PREVIEW_DEBUFFS
		local now = GetTime()
		for i = 1, min(cfg.max, #src) do
			local entry = src[i]
			local id = type(entry) == "table" and entry[1] or entry
			local _, _, iconTex = GetSpellInfo(id)
			list[#list + 1] = {
				icon = iconTex, count = (i == 2) and 3 or 0, duration = 30, expires = now + 10 + i * 4,
				dtype = type(entry) == "table" and entry[2] or nil, stealable = i == 1,
			}
		end
		return list
	end
	if not UnitExists(unit) then
		return list
	end
	local filter = container.kind == "buff" and "HELPFUL" or "HARMFUL"
	local stealables = {}
	for i = 1, 40 do
		local name, _, icon, count, dtype, duration, expires, caster, stealable, _, spellId, _, isBoss = UnitAura(unit, i, filter)
		if not name then
			break
		end
		local ok
		if container.kind == "buff" then
			ok = BuffAllowed(frame, s, spellId, caster, dtype, duration, stealable)
		else
			ok = DebuffAllowed(frame, s, spellId, caster, dtype, duration, isBoss)
		end
		if ok then
			local entry = {
				index = i, filter = filter, icon = icon, count = count, duration = duration, expires = expires,
				dtype = dtype, stealable = stealable,
			}
			-- Purgeable buffs lead the row while their glow is on.
			if container.kind == "buff" and stealable and s.buffPurgeGlow == 99 then
				stealables[#stealables + 1] = entry
			else
				list[#list + 1] = entry
			end
		end
	end
	for i = #stealables, 1, -1 do
		table.insert(list, 1, stealables[i])
	end
	return list
end

-- /euiauras [unit] (default focus): prints each debuff of the unit and if the
-- frame's filter keeps it, plus the container state. For bug reports.
local function DebugAuras(msg)
	local key = (msg and msg:match("%S+")) or "focus"
	local frame = UF.frames and UF.frames[key]
	local out = DEFAULT_CHAT_FRAME
	if not frame or not frame.Debuffs then
		out:AddMessage("|cff0cd29fEUI auras|r: no EllesmereUI frame with auras for '" .. key .. "'")
		return
	end
	local s = UF.Settings(frame.settingsKey)
	local c = frame.Debuffs
	local cfg = ContainerConfig(frame, "debuff")
	out:AddMessage(format("|cff0cd29fEUI auras|r %s: unit=%s exists=%s frameShown=%s mode=%s anchor=%s max=%s hasDuration=%s",
		key, tostring(frame.unit), tostring(UnitExists(frame.unit)), tostring(frame:IsShown()),
		UF.DebuffFilterMode(s), tostring(s.debuffAnchor), tostring(cfg and cfg.max), tostring(s.debuffHasDuration)))
	local shown = 0
	for _, icon in ipairs(c.icons) do
		if icon:IsShown() then
			shown = shown + 1
		end
	end
	out:AddMessage(format("  container: visible=%s icons=%d shown=%d", tostring(c:IsVisible()), #c.icons, shown))
	for i = 1, 40 do
		local name, _, _, count, dtype, duration, _, caster, _, _, spellId, _, isBoss = UnitAura(frame.unit, i, "HARMFUL")
		if not name then
			break
		end
		local ok = DebuffAllowed(frame, s, spellId, caster, dtype, duration, isBoss)
		out:AddMessage(format("  %d. %s (%s) caster=%s dur=%s boss=%s -> %s", i, name, tostring(spellId), tostring(caster),
			tostring(duration), tostring(isBoss), ok and "|cff00ff00shown|r" or "|cffff4040filtered|r"))
	end
end
SLASH_EUIAURAS1 = "/euiauras"
SlashCmdList.EUIAURAS = DebugAuras

function UF.UpdateAuras(frame)
	if not frame.Buffs then
		return
	end
	frame.settings = UF.Settings(frame.settingsKey)
	for _, key in ipairs({ "Buffs", "Debuffs" }) do
		local container = frame[key]
		if not container.cfgValid then
			container.cfgValid = true
			container.cfg = ContainerConfig(frame, container.kind)
			container.styleStamp = (container.styleStamp or 0) + 1
			container.placedCount = nil
		end
		local cfg = container.cfg
		local shown = 0
		if cfg then
			local list = Collect(frame, container, cfg)
			for i = 1, min(#list, cfg.max) do
				shown = shown + 1
				ShowIcon(frame, container, cfg, shown, list[i])
			end
			if container.placedCount ~= shown then
				PlaceContainer(frame, container, cfg, shown)
				container.placedCount = shown
			end
		end
		for i = shown + 1, #container.icons do
			container.icons[i]:Hide()
		end
	end
end
