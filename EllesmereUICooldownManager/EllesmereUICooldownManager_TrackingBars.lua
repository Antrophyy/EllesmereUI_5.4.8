-------------------------------------------------------------------------------
--  EllesmereUICooldownManager_TrackingBars.lua
--  Tracking Bars (retail EllesmereUICdmBuffBars.lua "Tracked Buff Bars"): one
--  status bar per tracked aura, per spec (specProfiles[spec].trackedBuffBars),
--  grouped bars chain under the group's first bar. Unlock Mode keys
--  "TBB_" .. index like retail; positions in specProfiles[spec].tbbPositions.
--  5.4.8: auras are plain values, so the bar reads UnitAura directly
--  (retail needs the Blizzard bar viewer); cooldown-type bars, charge hash
--  lines and gradients are not ported.
-------------------------------------------------------------------------------
local addonName, P = ...
local ns = EllesmereUI
local CDM = P.CDM

local floor, max, min = math.floor, math.max, math.min
local format = string.format

local TBB = {}
CDM.TBB = TBB
local frames = {}   -- [index] = bar frame

local function ClassRGB()
	local _, class = UnitClass("player")
	local c = class and RAID_CLASS_COLORS[class]
	if c then return c.r, c.g, c.b end
	return 0.05, 0.82, 0.62
end

-- Retail TBB_DEFAULT_BAR (the keys this port uses).
TBB.DEFAULT_BAR = {
	spellID = 0, name = "New Bar", enabled = true, hideWhenInactive = true, onlyInCombat = false,
	barVisibility = "always", grouped = true, height = 24, width = 270,
	verticalOrientation = false, reverseFill = false, texture = "none",
	fillA = 1, bgR = 0, bgG = 0, bgB = 0, bgA = 0.4, opacity = 1,
	showTimer = true, timerPosition = "right", timerSize = 11, timerX = 0, timerY = 0,
	showName = true, namePosition = "left", nameSize = 11, nameX = 0, nameY = 0,
	showSpark = true, iconDisplay = "none", iconSize = 24, iconX = 0, iconY = 0,
	stacksPosition = "center", stacksSize = 11, stacksX = 0, stacksY = 0,
	stackBasedBar = false, stackThresholdMaxEnabled = false, stackThresholdMax = 10,
	pandemicGlow = true, borderSize = 1,
}

function TBB.Data(specKey)
	local sp = CDM.SpecProfile(specKey)
	if type(sp.trackedBuffBars) ~= "table" then sp.trackedBuffBars = { selectedBar = 1, bars = {} } end
	local t = sp.trackedBuffBars
	if type(t.bars) ~= "table" then t.bars = {} end
	if type(t.groups) ~= "table" then t.groups = {} end
	if type(sp.tbbPositions) ~= "table" then sp.tbbPositions = {} end
	return t, sp.tbbPositions
end

function TBB.V(cfg, k)
	local v = cfg[k]
	if v == nil then v = TBB.DEFAULT_BAR[k] end
	return v
end
local V = TBB.V

function TBB.GroupID(cfg)
	if cfg.groupId ~= nil then return cfg.groupId end
	return (cfg.grouped ~= false) and 1 or 0
end

function TBB.AddBar(spellID)
	local t = TBB.Data()
	local r, g, b = ClassRGB()
	local name = spellID and GetSpellInfo(spellID) or "New Bar"
	local cfg = { spellID = spellID or 0, name = name, fillR = r, fillG = g, fillB = b }
	-- New bars take the selected style preset (retail tbbStylePresets).
	local p = CDM.DB()
	local presetName = p.tbbSelectedStylePreset
	for _, pr in ipairs(p.tbbStylePresets or {}) do
		if pr.name == presetName and type(pr.style) == "table" then
			for k, v in pairs(pr.style) do cfg[k] = CDM.DeepCopy(v) end
		end
	end
	t.bars[#t.bars + 1] = cfg
	t.selectedBar = #t.bars
	return cfg
end

local function ResolveTexture(key)
	if type(key) ~= "string" or key == "" or key == "none" then return "Interface\\Buttons\\WHITE8X8" end
	local name = key:match("^sm:(.+)$")
	if name then
		local LSM = ns.GetLSM and ns.GetLSM()
		local path = LSM and LSM:Fetch("statusbar", name, true)
		return path or "Interface\\Buttons\\WHITE8X8"
	end
	return key
end

local function Frame(i)
	local f = frames[i]
	if f then return f end
	f = CreateFrame("Frame", nil, UIParent)
	f:SetClampedToScreen(true)
	f.border = f:CreateTexture(nil, "BACKGROUND")
	f.border:SetAllPoints()
	f.border:SetTexture(0, 0, 0, 1)
	f.bar = CreateFrame("StatusBar", nil, f)
	f.bar:SetMinMaxValues(0, 1)
	f.bg = f.bar:CreateTexture(nil, "BACKGROUND")
	f.bg:SetAllPoints()
	f.bg:SetTexture(1, 1, 1, 1)
	f.spark = f.bar:CreateTexture(nil, "OVERLAY")
	f.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
	f.spark:SetBlendMode("ADD")
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.text = CreateFrame("Frame", nil, f.bar)
	f.text:SetAllPoints()
	f.name = f.text:CreateFontString(nil, "OVERLAY")
	f.timer = f.text:CreateFontString(nil, "OVERLAY")
	f.stacks = f.text:CreateFontString(nil, "OVERLAY")
	f.glow = CreateFrame("Frame", nil, f)
	f.glow:SetAllPoints(f.bar)
	frames[i] = f
	return f
end

local POINTS = { left = "LEFT", right = "RIGHT", center = "CENTER", top = "TOP", bottom = "BOTTOM" }
local function PlaceText(fs, parent, pos, x, y)
	fs:ClearAllPoints()
	local pt = POINTS[pos or "center"] or "CENTER"
	local ox = (pt == "LEFT" and 4) or (pt == "RIGHT" and -4) or 0
	fs:SetPoint(pt, parent, pt, ox + (x or 0), y or 0)
end

local function StyleBar(f, cfg)
	local w, h = V(cfg, "width"), V(cfg, "height")
	local bs = V(cfg, "borderSize") or 1
	local vert = cfg.verticalOrientation
	local iconOn = cfg.iconDisplay == "left" or cfg.iconDisplay == "right"
	local isz = iconOn and (V(cfg, "iconSize") or h) or 0
	if vert then w, h = h, w end
	f:SetSize(w + (iconOn and (isz + 1) or 0), h)
	f:SetFrameStrata(cfg.strata or "MEDIUM")
	f.bar:ClearAllPoints()
	f.border:ClearAllPoints()
	if iconOn then
		f.icon:Show()
		f.icon:SetSize(isz, isz)
		f.icon:ClearAllPoints()
		if cfg.iconDisplay == "left" then
			f.icon:SetPoint("LEFT", f, "LEFT", V(cfg, "iconX"), V(cfg, "iconY"))
			f.border:SetPoint("TOPLEFT", f, "TOPLEFT", isz + 1, 0)
			f.border:SetPoint("BOTTOMRIGHT")
		else
			f.icon:SetPoint("RIGHT", f, "RIGHT", V(cfg, "iconX"), V(cfg, "iconY"))
			f.border:SetPoint("TOPLEFT")
			f.border:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(isz + 1), 0)
		end
	else
		f.icon:Hide()
		f.border:SetAllPoints()
	end
	f.border:SetShown(bs > 0)
	f.bar:SetPoint("TOPLEFT", f.border, "TOPLEFT", bs, -bs)
	f.bar:SetPoint("BOTTOMRIGHT", f.border, "BOTTOMRIGHT", -bs, bs)
	f.bar:SetOrientation(vert and "VERTICAL" or "HORIZONTAL")
	f.bar:SetReverseFill(cfg.reverseFill and true or false)
	f.bar:SetStatusBarTexture(ResolveTexture(cfg.texture))
	local r, g, b = cfg.fillR, cfg.fillG, cfg.fillB
	if cfg.fillColorMode == "class" or r == nil then r, g, b = ClassRGB() end
	f.bar:SetStatusBarColor(r, g, b, V(cfg, "fillA"))
	f.bg:SetVertexColor(V(cfg, "bgR"), V(cfg, "bgG"), V(cfg, "bgB"), V(cfg, "bgA"))
	f.spark:SetSize(12, (vert and w or h) * 2.2)
	local key = CDM.FONT_KEY
	ns.ApplyModuleFont(f.name, V(cfg, "nameSize"), key)
	ns.ApplyModuleFont(f.timer, V(cfg, "timerSize"), key)
	ns.ApplyModuleFont(f.stacks, V(cfg, "stacksSize"), key)
	PlaceText(f.name, f.bar, cfg.namePosition or "left", V(cfg, "nameX"), V(cfg, "nameY"))
	PlaceText(f.timer, f.bar, cfg.timerPosition or "right", V(cfg, "timerX"), V(cfg, "timerY"))
	PlaceText(f.stacks, iconOn and f.icon or f.bar, cfg.stacksPosition or "center", V(cfg, "stacksX"), V(cfg, "stacksY"))
	local showName = cfg.showName ~= false and cfg.namePosition ~= "none"
	-- Text Wrap (retail nameWrap): two lines within ~60 % of the bar.
	f.name:SetWordWrap(cfg.nameWrap and true or false)
	f.name:SetWidth(cfg.nameWrap and (vert and h or w) * 0.6 or 0)
	f.name:SetShown(showName)
	f.name:SetText(showName and (cfg.name or "") or "")
	f.timer:SetShown(cfg.showTimer ~= false and cfg.timerPosition ~= "none")
	local icon = cfg.spellID and cfg.spellID > 0 and (select(3, GetSpellInfo(cfg.spellID)))
	if CDM.LUST_SET[cfg.spellID] then
		icon = select(3, GetSpellInfo(UnitFactionGroup("player") == "Alliance" and 32182 or 2825)) or icon
	end
	f.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
	f:SetAlpha(V(cfg, "opacity") or 1)
	-- Ticks at Stacks (retail stackTicks: "2, 5" or "all") on stack based bars.
	f.ticks = f.ticks or {}
	for _, t in ipairs(f.ticks) do t:Hide() end
	local maxS = (cfg.stackThresholdMaxEnabled and cfg.stackThresholdMax) or 10
	if cfg.stackBasedBar and type(cfg.stackTicks) == "string" and cfg.stackTicks ~= "" and maxS > 1 then
		local list = {}
		if cfg.stackTicks:lower() == "all" then
			for n = 1, maxS - 1 do list[#list + 1] = n end
		else
			for n in cfg.stackTicks:gmatch("%d+") do list[#list + 1] = tonumber(n) end
		end
		local bw, bh = f.bar:GetWidth(), f.bar:GetHeight()
		if bw <= 0 then bw = (vert and h or w) - 2 * bs end
		if bh <= 0 then bh = (vert and w or h) - 2 * bs end
		for i, n in ipairs(list) do
			if n > 0 and n < maxS then
				local t = f.ticks[i]
				if not t then
					t = f.text:CreateTexture(nil, "OVERLAY")
					t:SetTexture(0, 0, 0, 0.8)
					f.ticks[i] = t
				end
				t:ClearAllPoints()
				if vert then
					t:SetSize(bw, 1)
					t:SetPoint("BOTTOM", f.bar, "BOTTOM", 0, bh * n / maxS)
				else
					t:SetSize(1, bh)
					t:SetPoint("LEFT", f.bar, "LEFT", bw * n / maxS, 0)
				end
				t:Show()
			end
		end
	end
	f._fillR, f._fillG, f._fillB = r, g, b
	f.cfg = cfg
	f.entry = { spellID = cfg.spellID, name = cfg.spellID and GetSpellInfo(cfg.spellID) }
end

-- Positions: group anchors from tbbPositions, members chained under them.
local function Layout()
	local t, positions = TBB.Data()
	local lastInGroup = {}
	for i, cfg in ipairs(t.bars) do
		local f = frames[i]
		if f and f.cfg == cfg then
			local gid = TBB.GroupID(cfg)
			f:ClearAllPoints()
			local prev = gid ~= 0 and lastInGroup[gid]
			if prev then
				local g = t.groups[tostring(gid)] or {}
				local sp = g.spacing or t.groupSpacing or 0
				if (g.grow or t.groupGrowDirection or "DOWN") == "UP" then
					f:SetPoint("BOTTOM", prev, "TOP", 0, sp)
				else
					f:SetPoint("TOP", prev, "BOTTOM", 0, -sp)
				end
			else
				local pos = positions[tostring(i)] or { point = "CENTER", relPoint = "CENTER", x = 0, y = -260 - (i - 1) * 30 }
				f:SetPoint(pos.point or "CENTER", UIParent, pos.relPoint or "CENTER", pos.x or 0, pos.y or 0)
			end
			-- Hidden (inactive) members collapse: the next bar chains to the last shown one.
			if gid ~= 0 and (f:IsShown() or not prev) then lastInGroup[gid] = f end
		end
	end
end
TBB.Layout = Layout

function TBB.Build()
	if not CDM.ready then return end
	local t = TBB.Data()
	local enabled = CDM.DB().cdmBars.enabled ~= false
	for i, cfg in ipairs(t.bars) do
		local f = Frame(i)
		if enabled and cfg.enabled ~= false and (cfg.spellID or 0) > 0 then
			StyleBar(f, cfg)
		else
			f.cfg = nil
			f:Hide()
		end
	end
	for i = #t.bars + 1, #frames do
		frames[i].cfg = nil
		frames[i]:Hide()
	end
	TBB.RegisterUnlock()
	TBB.Update(true)
end

local function FormatTime(s)
	if s >= 60 then return format("%d:%02d", floor(s / 60), floor(s % 60)) end
	if s >= 10 then return format("%d", floor(s)) end
	return format("%.1f", s)
end

function TBB.Update(force)
	local t = TBB.Data()
	local now = GetTime()
	local inCombat = InCombatLockdown()
	local changed = force
	local preview = ns._unlockActive or CDM._preview
	for i, cfg in ipairs(t.bars) do
		local f = frames[i]
		if f and f.cfg == cfg then
			local a = CDM.FindAura(f.entry)
			-- Audio on Buff Gain / Loss (retail per-bar sound keys).
			local on = a ~= nil
			if f._wasActive ~= nil and on ~= f._wasActive then
				CDM.PlaySoundKey(on and cfg.buffActiveSoundKey or cfg.buffLostSoundKey)
			end
			f._wasActive = on
			local show = true
			if cfg.onlyInCombat and not inCombat then show = false end
			local vis = cfg.barVisibility or "always"
			if vis == "never" or (vis == "in_combat" and not inCombat) or (vis == "out_of_combat" and inCombat) then show = false end
			if not a and cfg.hideWhenInactive ~= false then show = false end
			if preview then show = true end
			if a then
				local left = (a.exp or 0) - now
				local value = 1
				if cfg.stackBasedBar then
					local maxS = (cfg.stackThresholdMaxEnabled and cfg.stackThresholdMax) or 10
					value = min(1, (a.count or 0) / max(1, maxS))
				elseif a.dur and a.dur > 0 then
					value = max(0, left / a.dur)
				end
				-- Smooth Bars (retail): ease toward the value.
				if CDM.DB().tbbSmoothBars and f._val and math.abs(value - f._val) < 0.5 then
					value = f._val + (value - f._val) * 0.5
				end
				f._val = value
				f.bar:SetValue(value)
				-- Decimals (retail timerDecimals / timerDecimalThreshold).
				local tt = ""
				if a.dur and a.dur > 0 and left > 0 then
					if cfg.timerDecimals and left < (cfg.timerDecimalThreshold or 10) then
						tt = format("%.1f", left)
					else
						tt = FormatTime(left)
					end
				end
				f.timer:SetText(tt)
				f.stacks:SetText((a.count or 0) > 1 and tostring(a.count) or "")
				-- Stack Threshold (retail stackThresholdEnabled): its own colour at N+ stacks.
				if cfg.stackThresholdEnabled and (a.count or 0) >= (cfg.stackThreshold or 5) then
					f.bar:SetStatusBarColor(cfg.stackThresholdR or 1, cfg.stackThresholdG or 0.2, cfg.stackThresholdB or 0.2, cfg.stackThresholdA or 1)
					f._thrOn = true
				elseif f._thrOn then
					f._thrOn = nil
					f.bar:SetStatusBarColor(f._fillR or 1, f._fillG or 1, f._fillB or 1, V(cfg, "fillA"))
				end
				if cfg.showSpark and value > 0 and value < 1 then
					f.spark:ClearAllPoints()
					if cfg.verticalOrientation then
						f.spark:SetPoint("CENTER", f.bar, "BOTTOM", 0, f.bar:GetHeight() * value)
					else
						f.spark:SetPoint("CENTER", f.bar, "LEFT", f.bar:GetWidth() * value, 0)
					end
					f.spark:Show()
				else
					f.spark:Hide()
				end
			else
				f.bar:SetValue(preview and 0.6 or 0)
				f.timer:SetText("")
				f.stacks:SetText("")
				f.spark:Hide()
			end
			if show ~= f:IsShown() then
				changed = true
				f:SetShown(show)
			end
		end
	end
	if changed then Layout() end
end

-------------------------------------------------------------------------------
--  Unlock Mode: one mover per group anchor / ungrouped bar ("TBB_" .. index)
-------------------------------------------------------------------------------
function TBB.RegisterUnlock()
	if not (ns.RegisterUnlockElements and ns.MakeUnlockElement) then return end
	local t = TBB.Data()
	local MK = ns.MakeUnlockElement
	local elements = {}
	local seenGroup = {}
	for i, cfg in ipairs(t.bars) do
		local gid = TBB.GroupID(cfg)
		local anchor = gid == 0 or not seenGroup[gid]
		if gid ~= 0 then seenGroup[gid] = true end
		if anchor and frames[i] and frames[i].cfg == cfg then
			local idx = i
			elements[#elements + 1] = MK({
				key = "TBB_" .. idx,
				label = gid ~= 0 and format("Tracking Bar Group %d", gid) or format("Tracking Bar: %s", cfg.name or ("Bar " .. idx)),
				group = "Cooldown Manager",
				order = 650,
				noResize = true,
				noAnchorTarget = true,
				isHidden = function()
					local t2 = TBB.Data()
					return not t2.bars[idx]
				end,
				getFrame = function() return frames[idx] end,
				getSize = function()
					local f = frames[idx]
					if not f then return 270, 24 end
					return f:GetWidth(), f:GetHeight()
				end,
				savePos = function(_, point, relPoint, x, y)
					local _, positions = TBB.Data()
					positions[tostring(idx)] = { point = point, relPoint = relPoint, x = x, y = y }
					if not ns._unlockActive then Layout() end
				end,
				loadPos = function()
					local _, positions = TBB.Data()
					return positions[tostring(idx)]
				end,
				clearPos = function()
					local _, positions = TBB.Data()
					positions[tostring(idx)] = nil
				end,
				applyPos = function() Layout() end,
			})
		end
	end
	if #elements > 0 then ns:RegisterUnlockElements(elements, addonName) end
end

-- Updates ride on the CDM driver (10 / s).
local orig = CDM.UpdateAll
CDM.UpdateAll = function(relayout)
	orig(relayout)
	if CDM.ready then TBB.Update(false) end
end
