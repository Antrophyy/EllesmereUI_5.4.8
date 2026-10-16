-------------------------------------------------------------------------------
--  EUI_RaidFrames_Headers.lua  (5.4.8 port of retail EUI_RaidFrames_Layout,
--  _Sort, _Reload, _Party, _PartyLayout, _Visibility and the Blizzard frame
--  suppression of EllesmereUIRaidFrames.lua)
--
--  Secure group headers (8 per-group headers + 1 flat header for Merge
--  Groups, 1 party header + a static self button), sorting, layout, raid
--  size tiers, sizes and auto-resize scales, visibility (secure state
--  drivers), Blizzard raid/party frame hiding, frame strata, group numbers,
--  unlock mode and the free right-click camera.
--
--  5.4.8 has SecureGroupHeaderTemplate with groupBy GROUP/CLASS/ROLE/
--  ASSIGNEDROLE, nameList + sortMethod NAMELIST, startingIndex pre-spawn and
--  RegisterStateDriver, so the retail design ports almost 1:1. Not ported:
--  12.1 aura containers on the headers, FrameSort provider, Edit Mode
--  overlay suppression, the Party Frames kit / stock styles.
-------------------------------------------------------------------------------
local addonName, RF = ...
local ns = EllesmereUI
local ERF = RF.ERF

local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local pairs, ipairs, type, tostring = pairs, ipairs, type, tostring
local wipe = wipe

-- Placeholder name of an unresolved roster entry (FrameXML global string).
local UNKNOWN = UNKNOWNOBJECT or "Unknown"

RF._separatedHdrs = RF._separatedHdrs or {}
RF._flatButtons = RF._flatButtons or {}
RF._raidButtons = RF._raidButtons or {}     -- every raid header button
RF._partyAllButtons = RF._partyAllButtons or {}
local separatedHdrs = RF._separatedHdrs

local MOVER_GROUPS = 4
RF.MOVER_GROUPS = MOVER_GROUPS
RF._RF_GRID_ROWS = 2

local function Profile()
	return RF.Profile()
end

-- Pixel snap in UIParent units (retail PixelSnap).
local function PixelSnap(v)
	if not v then
		return 0
	end
	return RF.Snap(v, UIParent)
end
RF.PixelSnap = PixelSnap

local function SafeCall(fn, ...)
	if not fn then
		return
	end
	local ok, err = pcall(fn, ...)
	if not ok then
		geterrorhandler()(err)
	end
end
RF._SafeCall = SafeCall

-------------------------------------------------------------------------------
--  Public accessors (contract)
-------------------------------------------------------------------------------
function RF.GetRaidContainer()
	return RF._containerFrame
end
function RF.GetPartyContainer()
	return RF._partyContainerFrame
end
function RF.GetRaidButtons()
	return RF._raidButtons
end
function RF.GetPartyButtons()
	return RF._partyAllButtons
end
function RF.GetPartyHeader()
	return RF._partyHeader
end
function RF.GetFlatHeader()
	return RF._flatHeader
end
function RF.GetSeparatedHeaders()
	return separatedHdrs
end
function RF.RaidShown()
	return RF._raidFramesVisible == true
end
function RF.PartyShown()
	return RF._partyFramesVisible == true
end

-- Layout listeners (extras re-anchor beside the containers): fn(kind),
-- kind = "raid" | "party". Called after every out-of-combat layout pass.
RF._layoutListeners = RF._layoutListeners or {}
function RF.OnLayout(fn)
	RF._layoutListeners[#RF._layoutListeners + 1] = fn
end
local function NotifyLayout(kind)
	for i = 1, #RF._layoutListeners do
		SafeCall(RF._layoutListeners[i], kind)
	end
end

-------------------------------------------------------------------------------
--  Group helpers (retail EllesmereUIRaidFrames.lua)
-------------------------------------------------------------------------------
-- Keep subgroup identity separate from its visual slot. Invalid orders fall
-- back to the original layout.
function RF._RFValidatedGroupOrder(order)
	if type(order) ~= "table" or #order ~= 8 then
		return nil
	end
	for i = 1, 8 do
		local group = order[i]
		if type(group) ~= "number" or group < 1 or group > 8 or group % 1 ~= 0 then
			return nil
		end
		for previous = 1, i - 1 do
			if order[previous] == group then
				return nil
			end
		end
	end
	return order
end

-- Show Groups as the frames apply it. Hide Groups 5-8 in Mythic Raid: 5.4.8
-- Mythic (flex/heroic 10-25 era) has no difficulty 16, so this only fires on
-- a client that reports it; the key and behavior are kept.
RF._mythicGroups = {}
function RF._VisibleGroups()
	local s = Profile()
	local vg = s and s.visibleGroups
	if not (s and s.mythicRaidHideGroups) then
		return vg
	end
	local _, _, difficultyID = GetInstanceInfo()
	if difficultyID ~= 16 then
		return vg
	end
	local t = RF._mythicGroups
	for g = 1, 8 do
		t[g] = g <= 4 and not (vg and vg[g] == false)
	end
	return t
end

-- Head count for the size breakpoints (hidden Show Groups excluded).
function RF._GetEffectiveRaidSize()
	local n = GetNumGroupMembers() or 0
	if n == 0 then
		return n
	end
	local s = Profile()
	if not s or s.excludeHiddenGroupsFromSize == false then
		return n
	end
	if not IsInRaid() then
		return n
	end
	local vg = RF._VisibleGroups()
	if not vg then
		return n
	end
	local anyHidden = false
	for g = 1, 8 do
		if vg[g] == false then
			anyHidden = true
			break
		end
	end
	if not anyHidden then
		return n
	end
	local count = 0
	for ri = 1, n do
		local _, _, sub = GetRaidRosterInfo(ri)
		if not sub or vg[sub] ~= false then
			count = count + 1
		end
	end
	if count == 0 then
		return n
	end
	return count
end

-------------------------------------------------------------------------------
--  Growth helpers (retail EUI_RaidFrames_Reload.lua, verbatim math)
-------------------------------------------------------------------------------
function RF._RFGrowthIsVertical(g)
	return g == "DOWN" or g == "UP"
end

-- Group slot origins along the growth flow + the normalization origin.
function RF._RFGroupFlow(groupGrowth, groupW, groupH, gs, count, out)
	local n = count or MOVER_GROUPS
	local stepX, stepY = 0, 0
	if groupGrowth == "DOWNRIGHT" then
		stepX, stepY = (groupW + gs), -(groupH + gs)
	elseif groupGrowth == "DOWN" then
		stepY = -(groupH + gs)
	elseif groupGrowth == "UP" then
		stepY = (groupH + gs)
	elseif groupGrowth == "RIGHT" then
		stepX = (groupW + gs)
	else
		stepX = -(groupW + gs)
	end
	local slots, minX, maxY = out or {}, 0, 0
	for i = 0, n - 1 do
		local px, py = 0, 0
		if groupGrowth == "DOWNRIGHT" then
			px = floor(i / RF._RF_GRID_ROWS) * stepX
			py = (i % RF._RF_GRID_ROWS) * stepY
		else
			px, py = i * stepX, i * stepY
		end
		local p = slots[i]
		if p then
			p[1], p[2] = px, py
		else
			slots[i] = { px, py }
		end
	end
	local nc = min(MOVER_GROUPS, n)
	for i = 0, nc - 1 do
		local px, py = slots[i][1], slots[i][2]
		if px < minX then
			minX = px
		end
		if py > maxY then
			maxY = py
		end
	end
	return slots, minX, maxY
end

-- Footprint of the 4-group mover box.
function RF._RFFootprint(bw, bh, unitGrowth, groupGrowth, cs, gs)
	bw, bh = PixelSnap(bw), PixelSnap(bh)
	local groupW, groupH
	if unitGrowth == "RIGHT" or unitGrowth == "LEFT" then
		groupW = 5 * bw + 4 * cs
		groupH = bh
	else
		groupW = bw
		groupH = 5 * bh + 4 * cs
	end
	if groupGrowth == "DOWNRIGHT" then
		local rows = RF._RF_GRID_ROWS
		local cols = floor((MOVER_GROUPS + rows - 1) / rows)
		return PixelSnap(cols * groupW + (cols - 1) * gs), PixelSnap(rows * groupH + (rows - 1) * gs)
	end
	if groupGrowth == "DOWN" or groupGrowth == "UP" then
		return PixelSnap(groupW), PixelSnap(MOVER_GROUPS * groupH + (MOVER_GROUPS - 1) * gs)
	end
	return PixelSnap(MOVER_GROUPS * groupW + (MOVER_GROUPS - 1) * gs), PixelSnap(groupH)
end

-- First-button point/xOffset/yOffset for a header growing along unitGrowth.
function RF._RFHeaderPoint(unitGrowth, cs)
	if unitGrowth == "DOWN" then
		return "TOP", 0, -cs
	elseif unitGrowth == "UP" then
		return "BOTTOM", 0, cs
	elseif unitGrowth == "RIGHT" then
		return "LEFT", cs, 0
	end
	return "RIGHT", -cs, 0
end

function RF._RFColAnchor(unitGrowth, groupGrowth)
	if groupGrowth == "DOWN" or groupGrowth == "RIGHT" then
		if RF._RFGrowthIsVertical(unitGrowth) then
			return "LEFT"
		end
		return "TOP"
	end
	if RF._RFGrowthIsVertical(unitGrowth) then
		return "RIGHT"
	end
	return "BOTTOM"
end

-- Merged mode: heal a same-axis pair and the grid flow (flat header has one
-- column axis).
function RF._RFEffectiveGrowth(unitGrowth, groupGrowth, merged)
	if not merged then
		return unitGrowth, groupGrowth
	end
	if groupGrowth == "DOWNRIGHT" then
		groupGrowth = "RIGHT"
	end
	if RF._RFGrowthIsVertical(unitGrowth) == RF._RFGrowthIsVertical(groupGrowth) then
		unitGrowth = RF._RFGrowthIsVertical(unitGrowth) and "RIGHT" or "DOWN"
	end
	return unitGrowth, groupGrowth
end

function RF._RFGrowthCorner(unitGrowth, groupGrowth)
	local h = (unitGrowth == "LEFT" or groupGrowth == "LEFT") and "RIGHT" or "LEFT"
	local v = (unitGrowth == "UP" or groupGrowth == "UP") and "BOTTOM" or "TOP"
	return v .. h
end

function RF._RFCornerTerms(tw, th, bw, bh, unitGrowth, groupGrowth)
	local corner = RF._RFGrowthCorner(unitGrowth, groupGrowth)
	local kx = (corner:find("RIGHT") and (bw - tw)) or 0
	local ky = (corner:find("BOTTOM") and -(bh - th)) or 0
	return kx, ky
end

-- Saved (point, relPoint, x, y) -> TOPLEFT in UIParent bottom-left space.
function RF._RFPosTopLeft(pos, w, h)
	local uw, uh = UIParent:GetWidth(), UIParent:GetHeight()
	local function frac(p)
		p = p or "CENTER"
		local fx = (p:find("LEFT") and 0) or (p:find("RIGHT") and 1) or 0.5
		local fy = (p:find("BOTTOM") and 0) or (p:find("TOP") and 1) or 0.5
		return fx, fy
	end
	local rfx, rfy = frac(pos.relPoint or pos.point)
	local pfx, pfy = frac(pos.point)
	local ax = uw * rfx + (pos.x or 0)
	local ay = uh * rfy + (pos.y or 0)
	return ax - pfx * w, ay + (1 - pfy) * h
end

-- 5.4.8 addition: keep a box of w x h (TOPLEFT x, y) on screen. The user's
-- retail positions were saved on another resolution / UI scale; the saved
-- values stay untouched, only the applied position is clamped.
function RF._ClampTopLeft(x, y, w, h)
	local uw, uh = UIParent:GetWidth(), UIParent:GetHeight()
	if not uw or uw <= 0 or not uh or uh <= 0 then
		return x, y
	end
	if w >= uw then
		x = 0
	else
		x = max(0, min(x, uw - w))
	end
	if h >= uh then
		y = uh
	else
		y = min(uh, max(y, h))
	end
	return x, y
end

function RF._RFBaseTopLeft()
	local s = Profile()
	local pos = s and s.unlockPos
	if not pos then
		return nil
	end
	local cs = PixelSnap(s.cellSpacing or 2)
	local gs = PixelSnap(s.groupSpacing or 8)
	local ug, gg = RF._RFEffectiveGrowth(s.unitGrowth or "DOWN", s.groupGrowth or "RIGHT", s.mergeGroups)
	local w, h = RF._RFFootprint(s.frameWidth or 72, s.frameHeight or 46, ug, gg, cs, gs)
	local l, t = RF._RFPosTopLeft(pos, w, h)
	return l, t, w, h
end

function RF._RFTierTopLeft(tw, th, unitGrowth, groupGrowth, ox, oy)
	local bl, bt, bw, bh = RF._RFBaseTopLeft()
	if not bl then
		return nil
	end
	local kx, ky = RF._RFCornerTerms(tw, th, bw, bh, unitGrowth, groupGrowth)
	return bl + (ox or 0) + kx, bt + (oy or 0) + ky
end

-- Size tier bucket + override table (cascade toward 20).
function RF._RFResolveTierOverride(numMembers)
	local s = Profile()
	local overrides = s and s.raidSizeOverrides
	if not overrides or not numMembers or numMembers <= 0 then
		return 20, nil
	end
	local o10, o15, o25, o30, o40 = overrides[10], overrides[15], overrides[25], overrides[30], overrides[40]
	local b10 = (o10 and o10.sizeCap) or 10
	local b15 = (o15 and o15.sizeCap) or 15
	local b25 = (o25 and o25.sizeMin) or 21
	local b30 = (o30 and o30.sizeMin) or 26
	local b40 = (o40 and o40.sizeMin) or 31
	local tier
	if numMembers <= b10 then
		tier = 10
	elseif numMembers <= b15 then
		tier = 15
	elseif numMembers < b25 then
		tier = 20
	elseif numMembers < b30 then
		tier = 25
	elseif numMembers < b40 then
		tier = 30
	else
		tier = 40
	end
	if tier == 20 then
		return 20, nil
	end
	local ov
	if tier < 20 then
		ov = overrides[tier] or (tier == 10 and overrides[15]) or nil
	else
		ov = overrides[tier]
		if not ov and tier == 30 then
			ov = overrides[25]
		end
		if not ov and tier == 40 then
			ov = overrides[30] or overrides[25]
		end
	end
	if type(ov) ~= "table" then
		ov = nil
	end
	return tier, ov
end

function RF._GetRaidSizeFrameDimensions(groupSize)
	local s = Profile()
	local baseW = s.frameWidth or 125
	local baseH = s.frameHeight or 60
	local _, ov = RF._RFResolveTierOverride(groupSize)
	if ov then
		return ov.width or baseW, ov.height or baseH
	end
	return baseW, baseH
end

-- Mover save path: live (active-tier) center -> base-footprint center.
function RF._RFRebaseSavedCenter(cx, cy)
	local s = Profile()
	local _, ov = RF._RFResolveTierOverride(RF._GetEffectiveRaidSize())
	if not ov then
		return cx, cy
	end
	local cs = PixelSnap(s.cellSpacing or 2)
	local gs = PixelSnap(s.groupSpacing or 8)
	local bug, bgg = RF._RFEffectiveGrowth(s.unitGrowth or "DOWN", s.groupGrowth or "RIGHT", s.mergeGroups)
	local bw, bh = RF._RFFootprint(s.frameWidth or 72, s.frameHeight or 46, bug, bgg, cs, gs)
	local ug, gg = RF._RFEffectiveGrowth(ov.unitGrowth or s.unitGrowth or "DOWN",
		ov.groupGrowth or s.groupGrowth or "RIGHT", s.mergeGroups)
	local tw, th = RF._RFFootprint(ov.width or s.frameWidth or 72, ov.height or s.frameHeight or 46, ug, gg, cs, gs)
	local kx, ky = RF._RFCornerTerms(tw, th, bw, bh, ug, gg)
	return cx - (ov.offsetX or 0) - kx - (tw - bw) / 2, cy - (ov.offsetY or 0) - ky - (bh - th) / 2
end

-- Owned creation point for raidSizeOverrides (options use it).
function RF._EnsureRaidSizeOverrides()
	local s = Profile()
	if not s.raidSizeOverrides then
		s.raidSizeOverrides = { _topLeftAnchored = true, _cornerAnchored = true }
	else
		RF._NormalizeTierOffsetAnchors()
	end
	return s.raidSizeOverrides
end

-- One-time offset scheme conversions (markers inside raidSizeOverrides).
function RF._NormalizeTierOffsetAnchors()
	local s = Profile()
	if not s then
		return
	end
	local ov = s.raidSizeOverrides
	if type(ov) ~= "table" then
		return
	end
	local phantoms = nil
	for k, v in pairs(ov) do
		if type(k) == "string" and tonumber(k) ~= nil and type(v) == "table" then
			phantoms = phantoms or {}
			phantoms[#phantoms + 1] = k
		end
	end
	if phantoms then
		for i = 1, #phantoms do
			local k = phantoms[i]
			local n = tonumber(k)
			if ov[n] == nil then
				ov[n] = ov[k]
			end
			ov[k] = nil
		end
	end
	if ov._topLeftAnchored and ov._cornerAnchored then
		return
	end
	local cs = PixelSnap(s.cellSpacing or 2)
	local gs = PixelSnap(s.groupSpacing or 8)
	local pos = s.unlockPos
	local bl, bt, bw, bh = RF._RFBaseTopLeft()
	if not ov._topLeftAnchored then
		ov._topLeftAnchored = true
		if pos and bl then
			for _, o in pairs(ov) do
				if type(o) == "table" then
					local ug, gg = RF._RFEffectiveGrowth(o.unitGrowth or s.unitGrowth or "DOWN",
						o.groupGrowth or s.groupGrowth or "RIGHT", s.mergeGroups)
					local tw, th = RF._RFFootprint(o.width or s.frameWidth or 72, o.height or s.frameHeight or 46, ug, gg, cs, gs)
					local tl, tt = RF._RFPosTopLeft(pos, tw, th)
					o.offsetX = floor((o.offsetX or 0) + (tl - bl) + 0.5)
					o.offsetY = floor((o.offsetY or 0) + (tt - bt) + 0.5)
				end
			end
		end
	end
	if not ov._cornerAnchored then
		ov._cornerAnchored = true
		if pos and bl then
			for _, o in pairs(ov) do
				if type(o) == "table" then
					local ug, gg = RF._RFEffectiveGrowth(o.unitGrowth or s.unitGrowth or "DOWN",
						o.groupGrowth or s.groupGrowth or "RIGHT", s.mergeGroups)
					local tw, th = RF._RFFootprint(o.width or s.frameWidth or 72, o.height or s.frameHeight or 46, ug, gg, cs, gs)
					local kx, ky = RF._RFCornerTerms(tw, th, bw, bh, ug, gg)
					if kx ~= 0 then
						o.offsetX = floor((o.offsetX or 0) - kx + 0.5)
					end
					if ky ~= 0 then
						o.offsetY = floor((o.offsetY or 0) - ky + 0.5)
					end
				end
			end
		end
	end
end

-- Anchored raid container: the unlock anchor folds the tier offset in.
ns._anchorExtraOffset = ns._anchorExtraOffset or {}
ns._anchorExtraOffset["RF_RaidFrames"] = function()
	local _, ov = RF._RFResolveTierOverride(RF._GetEffectiveRaidSize())
	return (ov and ov.offsetX) or 0, (ov and ov.offsetY) or 0
end

-- Position the raid container: active tier footprint pinned at the base
-- footprint's growth corner + the tier's offsets (clamped to the screen).
function RF._ApplyTierOffset()
	local c = RF._containerFrame
	if not c or InCombatLockdown() then
		return
	end
	if ns.IsUnlockAnchored and ns.IsUnlockAnchored("RF_RaidFrames") then
		if ns.ReapplyUnlockAnchor then
			SafeCall(ns.ReapplyUnlockAnchor, "RF_RaidFrames")
		end
		return
	end
	local s = Profile()
	if not s.unlockPos then
		return
	end
	local _, ov = RF._RFResolveTierOverride(RF._GetEffectiveRaidSize())
	local cs = PixelSnap(s.cellSpacing or 2)
	local gs = PixelSnap(s.groupSpacing or 8)
	local fw = (ov and ov.width) or s.frameWidth or 72
	local fh = (ov and ov.height) or s.frameHeight or 46
	local ug, gg = RF._RFEffectiveGrowth((ov and ov.unitGrowth) or s.unitGrowth or "DOWN",
		(ov and ov.groupGrowth) or s.groupGrowth or "RIGHT", s.mergeGroups)
	local tw, th = RF._RFFootprint(fw, fh, ug, gg, cs, gs)
	local x, y = RF._RFTierTopLeft(tw, th, ug, gg, (ov and ov.offsetX) or 0, (ov and ov.offsetY) or 0)
	if not x then
		return
	end
	x, y = RF._ClampTopLeft(x, y, tw, th)
	c:ClearAllPoints()
	c:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", PixelSnap(x), PixelSnap(y))
	if not c:IsShown() then
		c:SetSize(tw, th)
	end
end

-------------------------------------------------------------------------------
--  Frame strata (retail _ResolveFrameStrata / ApplyFrameStrata)
-------------------------------------------------------------------------------
local STRATA_OK = { BACKGROUND = true, LOW = true, MEDIUM = true, HIGH = true, DIALOG = true }
function RF._ResolveFrameStrata(isParty)
	local s = Profile()
	local strata = nil
	if isParty and RF._IsPartySectionCustom("rangeTooltip") then
		strata = s and rawget(s, "party_frameStrata")
	end
	strata = strata or (s and s.frameStrata) or "LOW"
	if not STRATA_OK[strata] then
		strata = "LOW"
	end
	return strata
end
RF.ResolveFrameStrata = RF._ResolveFrameStrata

function RF.ApplyFrameStrata()
	if not Profile() then
		return false
	end
	if InCombatLockdown() then
		RF.AfterCombat("rf_strata", RF.ApplyFrameStrata)
		return false
	end
	local changed = false
	local c, pc = RF._containerFrame, RF._partyContainerFrame
	local rs, ps = RF._ResolveFrameStrata(false), RF._ResolveFrameStrata(true)
	if c and c:GetFrameStrata() ~= rs then
		c:SetFrameStrata(rs)
		changed = true
	end
	if pc and pc:GetFrameStrata() ~= ps then
		pc:SetFrameStrata(ps)
		changed = true
	end
	if changed and RF._RefreshPreviewMouseBlockStrata then
		RF._RefreshPreviewMouseBlockStrata()
	end
	return changed
end

-------------------------------------------------------------------------------
--  Sorting: name lists (retail EUI_RaidFrames_Sort.lua). A nameList is a
--  filter as much as an order; every list ends with the placeholder token so
--  a member still named UNKNOWNOBJECT stays visible.
-------------------------------------------------------------------------------
local function EffRole(unit)
	return RF.UnitRole(unit)
end

function RF._GetPlayerSubgroup()
	if not IsInRaid() then
		return 1
	end
	local n = GetNumGroupMembers()
	for i = 1, n do
		if UnitIsUnit("raid" .. i, "player") then
			local _, _, subgroup = GetRaidRosterInfo(i)
			return subgroup
		end
	end
	return nil
end

function RF._FinishNameList(members, noToken)
	local names = {}
	for i = 1, #members do
		names[i] = members[i].name
	end
	if not noToken then
		names[#names + 1] = UNKNOWN
	end
	return table.concat(names, ",")
end

local function RolePri(roleOrder)
	local pri = {}
	for p, r in ipairs(roleOrder) do
		pri[r] = p
	end
	return pri
end

function RF._BuildSelfFirstNameList(playerGroup, sortByRole, roleOrder, selfLast)
	if not IsInRaid() or not playerGroup then
		return nil
	end
	local pri = sortByRole and RolePri(roleOrder) or nil
	local members = {}
	for i = 1, GetNumGroupMembers() do
		local name, _, subgroup = GetRaidRosterInfo(i)
		if not name then
			return nil
		end
		if subgroup == playerGroup then
			if name ~= UNKNOWN then
				local unit = "raid" .. i
				members[#members + 1] = {
					name = name,
					isPlayer = UnitIsUnit(unit, "player") and true or false,
					rolePri = pri and (pri[EffRole(unit)] or 99) or 99,
					index = i,
				}
			end
		elseif name == UNKNOWN then
			return nil
		end
	end
	if #members == 0 then
		return nil
	end
	selfLast = selfLast and true or false
	table.sort(members, function(a, b)
		if a.isPlayer ~= b.isPlayer then
			return a.isPlayer ~= selfLast
		end
		if sortByRole and a.rolePri ~= b.rolePri then
			return a.rolePri < b.rolePri
		end
		return a.index < b.index
	end)
	return RF._FinishNameList(members)
end

-- Default class order: player classes alphabetical by localized name
-- (5.4.8: GetNumClasses + GetClassInfo(i) -> className, classFile, classID).
function RF._GetDefaultClassOrder()
	if RF._defaultClassOrderCache then
		return RF._defaultClassOrderCache
	end
	local list, names = {}, {}
	local n = (GetNumClasses and GetNumClasses()) or 0
	for i = 1, n do
		local className, classFile = GetClassInfo(i)
		if classFile then
			list[#list + 1] = classFile
			names[classFile] = className or classFile
		end
	end
	table.sort(list, function(a, b)
		return (names[a] or a) < (names[b] or b)
	end)
	RF._classNameByToken = names
	if #list > 0 then
		RF._defaultClassOrderCache = list
	end
	return list
end

function RF._BuildPartyClassNameList(includePlayer, sortByRole, roleOrder, classOrder)
	if not IsInGroup() then
		return nil
	end
	classOrder = classOrder or RF._GetDefaultClassOrder()
	local classPri = {}
	for i, c in ipairs(classOrder) do
		classPri[c] = i
	end
	local rolePri = sortByRole and RolePri(roleOrder) or nil
	local units = {}
	if includePlayer then
		units[#units + 1] = "player"
	end
	for i = 1, 4 do
		units[#units + 1] = "party" .. i
	end
	local members = {}
	for _, unit in ipairs(units) do
		if UnitExists(unit) then
			local name, server = UnitName(unit)
			if not name then
				return nil
			end
			if name ~= UNKNOWN then
				if server and server ~= "" then
					name = name .. "-" .. server
				end
				local _, classToken = UnitClass(unit)
				members[#members + 1] = {
					name = name,
					rolePri = (rolePri and rolePri[EffRole(unit)]) or 99,
					classPri = classPri[classToken] or 99,
				}
			end
		end
	end
	if #members == 0 then
		return nil
	end
	table.sort(members, function(a, b)
		if sortByRole and a.rolePri ~= b.rolePri then
			return a.rolePri < b.rolePri
		end
		if a.classPri ~= b.classPri then
			return a.classPri < b.classPri
		end
		return a.name < b.name
	end)
	return RF._FinishNameList(members)
end

-- Party header nameList in arena / Small Raid (header bound to raid units).
function RF._BuildArenaNameList(hideSelf, selfFirst, selfLast, sortByRole, roleOrder, onlyGroup)
	if not IsInRaid() then
		return nil
	end
	local pri = sortByRole and RolePri(roleOrder) or nil
	local members = {}
	for i = 1, GetNumGroupMembers() do
		local name, _, subgroup = GetRaidRosterInfo(i)
		if not name then
			return nil
		end
		if not (onlyGroup and subgroup ~= onlyGroup) then
			local unit = "raid" .. i
			local isPlayer = UnitIsUnit(unit, "player") and true or false
			if not (hideSelf and isPlayer) then
				if name ~= UNKNOWN then
					members[#members + 1] = {
						name = name,
						isPlayer = isPlayer,
						rolePri = pri and (pri[EffRole(unit)] or 99) or 99,
						index = i,
					}
				end
			elseif name == UNKNOWN then
				return nil
			end
		elseif name == UNKNOWN then
			return nil
		end
	end
	if #members == 0 then
		return nil
	end
	selfLast = selfLast and true or false
	table.sort(members, function(a, b)
		if (selfFirst or selfLast) and a.isPlayer ~= b.isPlayer then
			return a.isPlayer ~= selfLast
		end
		if sortByRole and a.rolePri ~= b.rolePri then
			return a.rolePri < b.rolePri
		end
		return a.index < b.index
	end)
	return RF._FinishNameList(members)
end

function RF._BuildMergedSelfNameList(sortByRole, roleOrder, selfLast, visibleGroups)
	if not IsInRaid() then
		return nil
	end
	local pri = sortByRole and RolePri(roleOrder) or nil
	local members = {}
	for i = 1, GetNumGroupMembers() do
		local name, _, subgroup = GetRaidRosterInfo(i)
		if not name then
			return nil
		end
		if not visibleGroups or visibleGroups[subgroup] ~= false then
			if name ~= UNKNOWN then
				local unit = "raid" .. i
				members[#members + 1] = {
					name = name,
					isPlayer = UnitIsUnit(unit, "player") and true or false,
					rolePri = pri and (pri[EffRole(unit)] or 99) or 99,
					index = i,
				}
			end
		elseif name == UNKNOWN then
			return nil
		end
	end
	if #members == 0 then
		return nil
	end
	selfLast = selfLast and true or false
	table.sort(members, function(a, b)
		if a.isPlayer ~= b.isPlayer then
			return a.isPlayer ~= selfLast
		end
		if sortByRole and a.rolePri ~= b.rolePri then
			return a.rolePri < b.rolePri
		end
		return a.index < b.index
	end)
	return RF._FinishNameList(members)
end

-- Raid Prioritize Class lists: role -> class -> name (+ self pinning).
function RF._BuildRaidClassLists(merged, visibleGroups, sortByRole, roleOrder, classOrder, selfFirst, selfLast, onlyGroup)
	if not IsInRaid() then
		return nil
	end
	local classPri = {}
	for i, c in ipairs(classOrder or RF._GetDefaultClassOrder()) do
		classPri[c] = i
	end
	local rolePri = sortByRole and RolePri(roleOrder) or {}
	local sl = selfLast == true
	local pin = (selfFirst or selfLast) and true or false
	local groups, bad = {}, {}
	for g = 1, 8 do
		groups[g] = {}
	end
	for i = 1, GetNumGroupMembers() do
		local name, _, subgroup, _, _, classToken = GetRaidRosterInfo(i)
		if not name or not subgroup then
			return nil
		end
		local skip = (merged and visibleGroups and visibleGroups[subgroup] == false)
			or (onlyGroup ~= nil and subgroup ~= onlyGroup)
		if name == UNKNOWN then
			if merged or onlyGroup then
				if skip then
					return nil
				end
			elseif not skip then
				bad[subgroup] = true
			end
		elseif not skip then
			local unit = "raid" .. i
			local g = groups[merged and 1 or subgroup]
			g[#g + 1] = {
				name = name,
				isPlayer = pin and (UnitIsUnit(unit, "player") and true or false) or false,
				rolePri = (sortByRole and rolePri[EffRole(unit)]) or 99,
				classPri = classPri[classToken] or 99,
			}
		end
	end
	local function less(a, b)
		if a.isPlayer ~= b.isPlayer then
			return a.isPlayer ~= sl
		end
		if a.rolePri ~= b.rolePri then
			return a.rolePri < b.rolePri
		end
		if a.classPri ~= b.classPri then
			return a.classPri < b.classPri
		end
		return a.name < b.name
	end
	if merged or onlyGroup then
		local list = groups[merged and 1 or onlyGroup]
		if not list or #list == 0 then
			return nil
		end
		table.sort(list, less)
		return RF._FinishNameList(list)
	end
	local out = {}
	for g = 1, 8 do
		local list = groups[g]
		if #list > 0 and not bad[g] then
			table.sort(list, less)
			out[g] = RF._FinishNameList(list, true)
		end
	end
	return out
end

-- Sort attributes on the raid headers (retail ApplySortToHeaders).
-- Sort By = FrameSort is not available on 5.4.8: it falls back to the Group
-- sort, as retail does when FrameSort is absent.
function RF.ApplySortToHeaders()
	if not RF._containerFrame or InCombatLockdown() then
		return
	end
	local s = Profile()
	local sortByRole = s.sortMode == "ROLE"
	local roleOrder = s.roleOrder or { "TANK", "HEALER", "DAMAGER" }
	local live = RF._RFVisWanted()
	local classOn = s.prioritizeClass == true and IsInRaid()
	local classNative = classOn and not sortByRole
	local classLists = live and classOn and sortByRole
	local selfOn = live and (s.showSelfFirst or s.showSelfLast) and IsInRaid()
	local selfLast = s.showSelfLast

	local baseGroupBy, baseSortMethod, baseGroupingOrder
	if classNative then
		baseGroupBy = "CLASS"
		baseSortMethod = "NAME"
		baseGroupingOrder = table.concat(s.classOrder or RF._GetDefaultClassOrder(), ",")
	else
		baseGroupBy = sortByRole and "ASSIGNEDROLE" or nil
		baseSortMethod = sortByRole and "NAME" or "INDEX"
		baseGroupingOrder = sortByRole and (table.concat(roleOrder, ",") .. ",NONE") or ""
	end

	local function applySortTo(hdr, gb, sm, go, nl, gf)
		local needs = (hdr:GetAttribute("groupBy") ~= gb)
			or (hdr:GetAttribute("sortMethod") ~= sm)
			or (hdr:GetAttribute("groupingOrder") ~= go)
			or (hdr:GetAttribute("nameList") ~= nl)
			or (hdr:GetAttribute("groupFilter") ~= gf)
		if needs then
			local shown = hdr:IsShown()
			if shown then
				hdr:Hide()
			end
			hdr:SetAttribute("groupFilter", gf)
			hdr:SetAttribute("groupBy", gb)
			hdr:SetAttribute("sortMethod", sm)
			hdr:SetAttribute("groupingOrder", go)
			hdr:SetAttribute("nameList", nl)
			if shown then
				hdr:Show()
			end
		end
	end

	if s.mergeGroups and RF._flatHeader then
		local mergedList = nil
		if classLists or (classNative and selfOn) then
			mergedList = RF._BuildRaidClassLists(true, RF._VisibleGroups(), sortByRole, roleOrder,
				s.classOrder, s.showSelfFirst, selfLast)
		end
		if not mergedList and selfOn then
			mergedList = RF._BuildMergedSelfNameList(sortByRole, roleOrder, selfLast, RF._VisibleGroups())
		end
		if mergedList then
			applySortTo(RF._flatHeader, nil, "NAMELIST", "", mergedList, nil)
		else
			applySortTo(RF._flatHeader, baseGroupBy, baseSortMethod, baseGroupingOrder, nil,
				RF._flatGfStr or RF._flatHeader:GetAttribute("groupFilter"))
		end
	else
		local groupLists = nil
		if classLists then
			groupLists = RF._BuildRaidClassLists(false, nil, true, roleOrder, s.classOrder, s.showSelfFirst, selfLast)
		end
		local playerGroup = selfOn and RF._GetPlayerSubgroup() or nil
		if playerGroup and groupLists and groupLists[playerGroup] then
			playerGroup = nil
		end
		local selfNameList = nil
		if playerGroup then
			if classOn then
				selfNameList = RF._BuildRaidClassLists(false, nil, sortByRole, roleOrder, s.classOrder,
					s.showSelfFirst, selfLast, playerGroup)
			end
			selfNameList = selfNameList or RF._BuildSelfFirstNameList(playerGroup, sortByRole, roleOrder, selfLast)
			if not selfNameList then
				playerGroup = nil
			end
		end
		for group = 1, 8 do
			local hdr = separatedHdrs[group]
			if not hdr then
				break
			end
			local groupList = groupLists and groupLists[group]
			if groupList then
				applySortTo(hdr, nil, "NAMELIST", "", groupList, nil)
			elseif playerGroup and group == playerGroup then
				applySortTo(hdr, nil, "NAMELIST", "", selfNameList, nil)
			else
				applySortTo(hdr, baseGroupBy, baseSortMethod, baseGroupingOrder, nil, tostring(group))
			end
		end
	end
end

-------------------------------------------------------------------------------
--  Unit buttons: base setup shared by every header button
-------------------------------------------------------------------------------
-- Free right-click camera (retail freeRightClickCamera). Retail watches
-- GLOBAL_MOUSE_DOWN, which 5.4.8 lacks: here each button's OnMouseDown
-- starts a watcher, and a right-drag past a few pixels turns on mouselook.
do
	local watcher = CreateFrame("Frame")
	watcher:Hide()
	local inLook, lastX, lastY = false, 0, 0
	local THRESHOLD = 4
	local function stopLook()
		watcher:Hide()
		if inLook then
			inLook = false
			if IsMouselooking and IsMouselooking() then
				pcall(MouselookStop)
			end
		end
	end
	watcher:SetScript("OnUpdate", function()
		if not IsMouseButtonDown("RightButton") then
			stopLook()
			return
		end
		if inLook then
			return
		end
		local x, y = GetCursorPosition()
		if abs(x - lastX) > THRESHOLD or abs(y - lastY) > THRESHOLD then
			if pcall(MouselookStart) then
				inLook = true
			end
		end
	end)
	function RF._CameraMouseDown(_, button)
		if button ~= "RightButton" then
			return
		end
		local s = Profile()
		if not (s and s.freeRightClickCamera) then
			return
		end
		inLook = false
		lastX, lastY = GetCursorPosition()
		watcher:Show()
	end
end

-- Out of combat, right after the header made the button.
function RF._PrepButton(btn, kind, list)
	btn.rfKind = kind
	btn:SetAttribute("*type1", "target")
	btn:SetAttribute("*type2", "togglemenu")
	if btn.RegisterForClicks then
		btn:RegisterForClicks("AnyUp")
	end
	btn:HookScript("OnMouseDown", RF._CameraMouseDown)
	if list then
		list[#list + 1] = btn
	end
	if RF.StyleButton then
		SafeCall(RF.StyleButton, btn)
	end
end

-- Restricted-environment setup for a header-made button (size + base
-- clicks; Click Casting overrides the click attributes later).
local function InitConfig(bw, bh)
	return ([[
		self:SetWidth(%d)
		self:SetHeight(%d)
		self:SetAttribute("*type1", "target")
		self:SetAttribute("*type2", "togglemenu")
	]]):format(bw, bh)
end

-- Header children: 5.4.8 stores them as hdr[i] and attribute "child"..i.
local function HeaderChild(hdr, i)
	return hdr[i] or hdr:GetAttribute("child" .. i)
end
RF._HeaderChild = HeaderChild

-------------------------------------------------------------------------------
--  Raid headers (retail _BuildHeaderSet / CreateHeaders)
-------------------------------------------------------------------------------
function RF._BuildHeaderSet(merge)
	local c = RF._containerFrame
	if not c then
		return
	end
	if merge and RF._flatHeader then
		return
	end
	if not merge and separatedHdrs[1] then
		return
	end
	if InCombatLockdown() then
		RF.AfterCombat("rf_layout", RF.FullLayout)
		return
	end
	local s = Profile()
	local bw = PixelSnap(RF._activeSizeW or s.frameWidth or 72)
	local bh = PixelSnap(RF._activeSizeH or s.frameHeight or 46)
	local initConfig = InitConfig(bw, bh)
	local iu, ig = RF._RFEffectiveGrowth(s.unitGrowth or "DOWN", s.groupGrowth or "RIGHT", merge)
	local initPoint, initX, initY = RF._RFHeaderPoint(iu, PixelSnap(s.cellSpacing or 2))

	-- A header makes children only while visible: show the container around
	-- the pre-spawn.
	local hid = not c:IsShown()
	if hid then
		c:Show()
	end
	if not merge then
		for group = 1, 8 do
			local hdr = CreateFrame("Frame", "ERFGroupHeader" .. group, c, "SecureGroupHeaderTemplate")
			hdr:SetAttribute("template", "SecureUnitButtonTemplate")
			hdr:SetAttribute("templateType", "Button")
			hdr:SetAttribute("initialConfigFunction", initConfig)
			hdr:SetAttribute("point", initPoint)
			hdr:SetAttribute("xOffset", initX)
			hdr:SetAttribute("yOffset", initY)
			hdr:SetAttribute("groupFilter", tostring(group))
			hdr:SetAttribute("showRaid", true)
			hdr:SetAttribute("showParty", true)
			hdr:SetAttribute("showPlayer", true)
			hdr:SetAttribute("showSolo", s.showWhenSolo or false)
			hdr:SetAttribute("maxColumns", 1)
			hdr:SetAttribute("unitsPerColumn", 5)
			hdr:SetAttribute("sortMethod", "INDEX")
			-- Pre-create 5 buttons (oUF/ElvUI startingIndex trick).
			hdr:SetAttribute("startingIndex", -4)
			hdr:Show()
			hdr:SetAttribute("startingIndex", 1)
			for i = 1, 5 do
				local btn = HeaderChild(hdr, i)
				if btn then
					btn.rfGroup = group
					RF._PrepButton(btn, "raid", RF._raidButtons)
				end
			end
			separatedHdrs[group] = hdr
		end
	else
		local hdr = CreateFrame("Frame", "ERFFlatHeader", c, "SecureGroupHeaderTemplate")
		hdr:SetAttribute("template", "SecureUnitButtonTemplate")
		hdr:SetAttribute("templateType", "Button")
		hdr:SetAttribute("initialConfigFunction", initConfig)
		hdr:SetAttribute("point", initPoint)
		hdr:SetAttribute("xOffset", initX)
		hdr:SetAttribute("yOffset", initY)
		hdr:SetAttribute("groupFilter", "1,2,3,4,5,6,7,8")
		hdr:SetAttribute("showRaid", true)
		hdr:SetAttribute("showParty", true)
		hdr:SetAttribute("showPlayer", true)
		hdr:SetAttribute("showSolo", s.showWhenSolo or false)
		hdr:SetAttribute("unitsPerColumn", 5)
		hdr:SetAttribute("maxColumns", 8)
		hdr:SetAttribute("columnSpacing", PixelSnap(s.groupSpacing or 8))
		hdr:SetAttribute("columnAnchorPoint", RF._RFColAnchor(iu, ig))
		hdr:SetAttribute("sortMethod", "INDEX")
		hdr:SetAttribute("startingIndex", -39)
		hdr:Show()
		hdr:SetAttribute("startingIndex", 1)
		hdr:Hide()
		RF._flatHeader = hdr
		for i = 1, 40 do
			local btn = HeaderChild(hdr, i)
			if btn then
				RF._PrepButton(btn, "raid", RF._raidButtons)
				RF._flatButtons[#RF._flatButtons + 1] = btn
			end
		end
	end
	if hid then
		c:Hide()
	end
	RF.ApplySortToHeaders()
end

function RF.CreateHeaders()
	if RF._containerFrame then
		return
	end
	local s = Profile()
	local c = CreateFrame("Frame", "EllesmereUIRaidFrameContainer", UIParent)
	RF._containerFrame = c
	c:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	c:SetSize(1, 1)
	c:SetFrameStrata(RF._ResolveFrameStrata(false))
	c:Show()

	-- Group-number labels on a raised overlay (5.4.8 levels stop near 128).
	local ov = CreateFrame("Frame", nil, c)
	ov:SetAllPoints(c)
	ov:SetFrameLevel(min(c:GetFrameLevel() + 60, 127))
	RF._groupNumberOverlay = ov
	RF._groupNumberLabels = {}
	for gi = 1, 8 do
		local lbl = ov:CreateFontString(nil, "OVERLAY")
		RF.SetFont(lbl, s.groupNumberSize or 10)
		lbl:Hide()
		RF._groupNumberLabels[gi] = lbl
	end
	RF._BuildHeaderSet((s.mergeGroups and true) or false)
end

-------------------------------------------------------------------------------
--  Raid layout (retail _LayoutGroupsImpl / LayoutGroups / _UpdateGroupNumbers)
-------------------------------------------------------------------------------
function RF._UpdateGroupNumbers()
	local labels = RF._groupNumberLabels
	if not labels or InCombatLockdown() then
		return
	end
	local s = Profile()
	if (not s.showGroupNumbers) or s.mergeGroups or (not IsInRaid()) then
		for g = 1, 8 do
			labels[g]:Hide()
		end
		return
	end
	local unitGrowth = s.unitGrowth or "DOWN"
	local activeOv = RF._activeTierOverride
	if activeOv and activeOv.unitGrowth then
		unitGrowth = activeOv.unitGrowth
	end
	local vg = RF._VisibleGroups() or { true, true, true, true, true, true, false, false }
	local size = s.groupNumberSize or 10
	local gc = s.groupNumberColor or {}
	local ox, oy = s.groupNumberOffsetX or 0, s.groupNumberOffsetY or 0
	for group = 1, 8 do
		local lbl = labels[group]
		local hdr = separatedHdrs[group]
		local firstBtn = nil
		if hdr and vg[group] ~= false then
			for i = 1, 5 do
				local btn = HeaderChild(hdr, i)
				if btn and btn:IsShown() and btn:GetAttribute("unit") then
					firstBtn = btn
					break
				end
			end
		end
		if firstBtn then
			lbl:ClearAllPoints()
			if unitGrowth == "DOWN" then
				lbl:SetPoint("BOTTOM", firstBtn, "TOP", ox, 4 + oy)
			elseif unitGrowth == "UP" then
				lbl:SetPoint("TOP", firstBtn, "BOTTOM", ox, -4 + oy)
			elseif unitGrowth == "RIGHT" then
				lbl:SetPoint("RIGHT", firstBtn, "LEFT", -3 + ox, oy)
			else
				lbl:SetPoint("LEFT", firstBtn, "RIGHT", 3 + ox, oy)
			end
			RF.SetFont(lbl, size)
			lbl:SetText(tostring(group))
			lbl:SetTextColor(gc.r or 1, gc.g or 1, gc.b or 1, gc.a or 0.75)
			lbl:Show()
		else
			lbl:Hide()
		end
	end
end

local groupFlowSlots = {}

-- Re-anchor children before a header's growth attributes change.
local function ClearChildren(hdr)
	local ci = 1
	local child = HeaderChild(hdr, ci)
	while child do
		child:ClearAllPoints()
		ci = ci + 1
		child = HeaderChild(hdr, ci)
	end
end

function RF._LayoutGroupsImpl()
	local c = RF._containerFrame
	if not c or InCombatLockdown() then
		return
	end
	local s = Profile()
	local merged = s.mergeGroups
	RF._BuildHeaderSet((merged and true) or false)
	local groupGrowth = s.groupGrowth or "RIGHT"
	local unitGrowth = s.unitGrowth or "DOWN"
	local activeOv = RF._activeTierOverride
	if activeOv then
		groupGrowth = activeOv.groupGrowth or groupGrowth
		unitGrowth = activeOv.unitGrowth or unitGrowth
	end
	unitGrowth, groupGrowth = RF._RFEffectiveGrowth(unitGrowth, groupGrowth, merged)
	local bw = PixelSnap(RF._activeSizeW or s.frameWidth or 72)
	local bh = PixelSnap(RF._activeSizeH or s.frameHeight or 46)
	local cs = PixelSnap(s.cellSpacing or 2)
	local gs = PixelSnap(s.groupSpacing or 8)
	local hdrPoint, hdrXOff, hdrYOff = RF._RFHeaderPoint(unitGrowth, cs)
	local colAnchor = RF._RFColAnchor(unitGrowth, groupGrowth)
	local groupW, groupH
	if unitGrowth == "RIGHT" or unitGrowth == "LEFT" then
		groupW, groupH = 5 * bw + 4 * cs, bh
	else
		groupW, groupH = bw, 5 * bh + 4 * cs
	end
	local vg = RF._VisibleGroups() or { true, true, true, true, true, true, false, false }

	if merged then
		for group = 1, 8 do
			local hdr = separatedHdrs[group]
			if hdr and hdr:IsShown() then
				hdr:Hide()
			end
		end
		local gfParts = {}
		for i = 1, 8 do
			if vg[i] ~= false then
				gfParts[#gfParts + 1] = tostring(i)
			end
		end
		local gfStr = table.concat(gfParts, ",")
		local fh = RF._flatHeader
		if fh then
			local corner = RF._RFGrowthCorner(unitGrowth, groupGrowth)
			fh:ClearAllPoints()
			fh:SetPoint(corner, c, corner, 0, 0)
			RF._flatGfStr = gfStr
			local selfOwns = (s.showSelfFirst or s.showSelfLast
				or (s.prioritizeClass == true and s.sortMode == "ROLE")) and IsInRaid()
			if not selfOwns and fh:GetAttribute("groupFilter") ~= gfStr then
				fh:SetAttribute("groupFilter", gfStr)
			end
			local changed = false
			if fh:GetAttribute("point") ~= hdrPoint or fh:GetAttribute("xOffset") ~= hdrXOff
				or fh:GetAttribute("yOffset") ~= hdrYOff or fh:GetAttribute("columnAnchorPoint") ~= colAnchor then
				ClearChildren(fh)
				fh:SetAttribute("point", hdrPoint)
				fh:SetAttribute("xOffset", hdrXOff)
				fh:SetAttribute("yOffset", hdrYOff)
				fh:SetAttribute("columnAnchorPoint", colAnchor)
				changed = true
			end
			if fh:GetAttribute("columnSpacing") ~= gs then
				fh:SetAttribute("columnSpacing", gs)
			end
			if changed and fh:IsShown() then
				fh:Hide()
				fh:Show()
			elseif not fh:IsShown() then
				fh:Show()
			end
		end
	else
		if RF._flatHeader and RF._flatHeader:IsShown() then
			RF._flatHeader:Hide()
		end
		local slots, minX, maxY = RF._RFGroupFlow(groupGrowth, groupW, groupH, gs, 8, groupFlowSlots)
		local hdrAnchor, hdrOffX, hdrOffY = "TOPLEFT", 0, 0
		if unitGrowth == "UP" then
			hdrAnchor = "BOTTOMLEFT"
			hdrOffY = -groupH
		end
		if unitGrowth == "LEFT" then
			hdrAnchor = "TOPRIGHT"
			hdrOffX = groupW
		end
		-- Hide Empty Groups (real raid only, while the set is shown).
		local occupied = nil
		if s.hideEmptyGroups ~= false and IsInRaid() and RF._RFVisWanted() then
			occupied = {}
			for ri = 1, GetNumGroupMembers() or 0 do
				local _, _, sub = GetRaidRosterInfo(ri)
				if sub then
					occupied[sub] = true
				end
			end
		end
		local visSlot = 0
		local groupOrder = s.customGroupOrder and RF._RFValidatedGroupOrder(s.groupOrder)
		for slot = 1, 8 do
			local group = groupOrder and groupOrder[slot] or slot
			local hdr = separatedHdrs[group]
			if hdr then
				if vg[group] == false or (occupied and not occupied[group]) then
					if hdr:IsShown() then
						hdr:Hide()
					end
				else
					local x = PixelSnap(slots[visSlot][1] - minX + hdrOffX)
					local y = PixelSnap(slots[visSlot][2] - maxY + hdrOffY)
					visSlot = visSlot + 1
					hdr:ClearAllPoints()
					hdr:SetPoint(hdrAnchor, c, "TOPLEFT", x, y)
					local changed = false
					if hdr:GetAttribute("point") ~= hdrPoint or hdr:GetAttribute("xOffset") ~= hdrXOff
						or hdr:GetAttribute("yOffset") ~= hdrYOff then
						ClearChildren(hdr)
						hdr:SetAttribute("point", hdrPoint)
						hdr:SetAttribute("xOffset", hdrXOff)
						hdr:SetAttribute("yOffset", hdrYOff)
						changed = true
					end
					if changed and hdr:IsShown() then
						hdr:Hide()
						hdr:Show()
					elseif not hdr:IsShown() then
						hdr:Show()
					end
				end
			end
		end
	end

	RF.ApplySortToHeaders()
	RF._rfRaidLaidVis = RF._RFVisWanted()

	local totalW, totalH
	if merged then
		if unitGrowth == "DOWN" or unitGrowth == "UP" then
			totalW = MOVER_GROUPS * groupW + (MOVER_GROUPS - 1) * gs
			totalH = groupH
		else
			totalW = groupW
			totalH = MOVER_GROUPS * groupH + (MOVER_GROUPS - 1) * gs
		end
	else
		totalW, totalH = RF._RFFootprint(bw, bh, unitGrowth, groupGrowth, cs, gs)
	end
	c:SetSize(PixelSnap(totalW), PixelSnap(totalH))
	RF._UpdateGroupNumbers()
end

-- Coalescing re-entrancy guard (max 3 passes).
function RF.LayoutGroups()
	if RF._inLayoutGroups then
		RF._layoutGroupsDirty = true
		return
	end
	RF._inLayoutGroups = true
	local passes = 0
	repeat
		RF._layoutGroupsDirty = false
		passes = passes + 1
		local ok, err = pcall(RF._LayoutGroupsImpl)
		if not ok then
			RF._inLayoutGroups = false
			geterrorhandler()(err)
			return
		end
	until (not RF._layoutGroupsDirty) or passes >= 3
	RF._inLayoutGroups = false
	NotifyLayout("raid")
end

-------------------------------------------------------------------------------
--  Raid reload: active size tier, auto-resize scales, button sizes, layout
--  (retail ReloadFrames minus the per-button restyle, which the Button
--  file does through RF.RelayoutButton).
-------------------------------------------------------------------------------
function RF.ReloadRaidFrames()
	local s = Profile()
	if not s or not RF._containerFrame then
		return false
	end
	if RF._eventFrame then
		if s.mythicRaidHideGroups then
			RF._eventFrame:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
		else
			RF._eventFrame:UnregisterEvent("PLAYER_DIFFICULTY_CHANGED")
		end
	end
	local prevW, prevH, prevScale, prevBm = RF._activeSizeW, RF._activeSizeH, RF._indicatorScale, RF._bmScale
	local n = RF._GetEffectiveRaidSize()
	if n > 0 then
		RF._activeSizeW, RF._activeSizeH = RF._GetRaidSizeFrameDimensions(n)
		local _, ov = RF._RFResolveTierOverride(n)
		RF._activeTierOverride = ov
	else
		RF._activeSizeW, RF._activeSizeH = nil, nil
		RF._activeTierOverride = nil
	end
	-- Auto resize: tier size vs the base (20-man) size, clamped 0.7 - 1.5.
	local sizeScale = 1
	if RF._activeSizeW and RF._activeSizeH then
		local scale = min(RF._activeSizeW / (s.frameWidth or 72), RF._activeSizeH / (s.frameHeight or 46))
		sizeScale = max(min(scale, 1.5), 0.7)
	end
	RF._bmScale = (s.autoResizeTrackedBuffs ~= false) and sizeScale or 1
	RF._indicatorScale = s.autoResizeIndicators and sizeScale or 1

	if InCombatLockdown() then
		RF.AfterCombat("rf_layout", RF.FullLayout)
	else
		RF._BuildHeaderSet((s.mergeGroups and true) or false)
		local bw = PixelSnap(RF._activeSizeW or s.frameWidth or 72)
		local bh = PixelSnap(RF._activeSizeH or s.frameHeight or 46)
		for _, btn in ipairs(RF._raidButtons) do
			btn:SetSize(bw, bh)
		end
		RF.LayoutGroups()
		RF._ApplyTierOffset()
	end
	return prevW ~= RF._activeSizeW or prevH ~= RF._activeSizeH or prevScale ~= RF._indicatorScale
		or prevBm ~= RF._bmScale
end

-------------------------------------------------------------------------------
--  Party frames (retail EUI_RaidFrames_Party.lua / _PartyLayout.lua)
-------------------------------------------------------------------------------
-- Party Target frames between stacked frames open the pitch (Extras file).
local function AlongPitch(s)
	if RF.PT_AlongPitch then
		local ok, v = pcall(RF.PT_AlongPitch, s)
		if ok and type(v) == "number" then
			return v
		end
	end
	return 0
end
RF._PT_AlongPitchSafe = AlongPitch

-- Party indicator / Buff Manager scale: party size vs the raid base size.
function RF._UpdatePartyIndicatorScale()
	local s = Profile()
	if not s then
		return
	end
	local pw, ph, _, pres = RF.RF_PartyDims(s)
	pw = pw - (pres or 0)
	local scale = max(min(min(pw / (s.frameWidth or 72), ph / (s.frameHeight or 46)), 1.3), 0.7)
	RF._partyBmScale = (s.partyAutoResizeTrackedBuffs ~= false) and scale or 1
	RF._partyIndicatorScale = s.partyAutoResizeIndicators and scale or 1
end

function RF._PartyGrowth(s)
	if s.partyHorizontal then
		return (s.partyFlipGrowth == true) and "LEFT" or "RIGHT"
	end
	return (s.partyFlipGrowth == true) and "UP" or "DOWN"
end

function RF._CreatePartyHeader()
	if RF._partyHeader then
		return
	end
	local s = Profile()
	local pc = CreateFrame("Frame", "EllesmereUIPartyFrameContainer", UIParent)
	RF._partyContainerFrame = pc
	pc:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	pc:SetSize(1, 1)
	pc:SetFrameStrata(RF._ResolveFrameStrata(true))
	local pw, ph, pcs = RF.RF_PartyDims(s)
	local bw, bh, cs = PixelSnap(pw), PixelSnap(ph), PixelSnap(pcs)

	local hdr = CreateFrame("Frame", "ERFPartyHeader", pc, "SecureGroupHeaderTemplate")
	hdr:SetAttribute("template", "SecureUnitButtonTemplate")
	hdr:SetAttribute("templateType", "Button")
	hdr:SetAttribute("initialConfigFunction", InitConfig(bw, bh))
	hdr:SetAttribute("point", "TOP")
	hdr:SetAttribute("xOffset", 0)
	hdr:SetAttribute("yOffset", -cs)
	hdr:SetAttribute("groupFilter", "1,2,3,4,5,6,7,8")
	-- showRaid: arena and Small Raid bind the party header to raid1-5.
	hdr:SetAttribute("showRaid", true)
	hdr:SetAttribute("showParty", true)
	hdr:SetAttribute("showPlayer", true)
	hdr:SetAttribute("showSolo", s.partyShowWhenSolo or false)
	hdr:SetAttribute("maxColumns", 1)
	hdr:SetAttribute("unitsPerColumn", 5)
	pc:Show()
	hdr:SetAttribute("startingIndex", -4)
	hdr:Show()
	hdr:SetAttribute("startingIndex", 1)
	pc:Hide()
	RF._partyHeader = hdr
	for i = 1, 5 do
		local btn = HeaderChild(hdr, i)
		if btn then
			btn:SetSize(bw, bh)
			RF._PrepButton(btn, "party", RF._partyAllButtons)
		end
	end
	-- Static unit="player" self button for Show Self First / Self Last.
	local sb = CreateFrame("Button", "ERFPartySelfButton", pc, "SecureUnitButtonTemplate")
	sb:SetAttribute("unit", "player")
	sb:SetSize(bw, bh)
	sb.rfIsSelf = true
	RF._partySelfButton = sb
	RF._PrepButton(sb, "party", RF._partyAllButtons)
	sb:Hide()
end

-- Self button + header at their slot offsets (retail _PositionPartySlots).
function RF._PositionPartySlots(bw, bh, cs, unitGrowth)
	local hdr, pc = RF._partyHeader, RF._partyContainerFrame
	if not hdr then
		return false
	end
	local s = Profile()
	local pSelfFirst = s.partyShowSelfFirst
	if pSelfFirst == nil then
		pSelfFirst = s.showSelfFirst
	end
	local pSelfLast = s.partySelfLast
	if pSelfLast == nil then
		pSelfLast = s.showSelfLast
	end
	local hideSelf = s.partyHideSelf
	local _, live = RF._RFVisWanted()
	local useSelf = live and (pSelfFirst or pSelfLast) and not hideSelf and IsInGroup() and not RF._PartyInRaid()
	useSelf = useSelf and true or false
	hdr:SetSize(bw, bh)
	local stepX, stepY, basePoint = 0, 0, "TOPLEFT"
	if unitGrowth == "RIGHT" then
		stepX = bw + cs
	elseif unitGrowth == "LEFT" then
		stepX = -(bw + cs)
		basePoint = "TOPRIGHT"
	elseif unitGrowth == "UP" then
		stepY = bh + cs
		basePoint = "BOTTOMLEFT"
	else
		stepY = -(bh + cs)
	end
	local centerShift = 0
	local centered = (s.partyFlipGrowth == "centered")
	if not live then
		centerShift = 0
	elseif not IsInGroup() then
		if centered or s.partyCenterWhenSolo then
			centerShift = 2
		end
	elseif centered then
		local shown = GetNumGroupMembers() or 0
		if shown > 5 then
			shown = 5
		end
		if hideSelf then
			shown = shown - 1
		end
		if shown < 1 then
			shown = 1
		end
		centerShift = (5 - shown) / 2
	end
	local cx, cy = PixelSnap(stepX * centerShift), PixelSnap(stepY * centerShift)
	local sb = RF._partySelfButton
	if useSelf then
		local selfSlot, hdrSlot = 0, 1
		if pSelfLast then
			local others = (GetNumGroupMembers() or 1) - 1
			if others < 0 then
				others = 0
			end
			selfSlot, hdrSlot = others, 0
		end
		if sb then
			sb:SetSize(bw, bh)
			sb:ClearAllPoints()
			sb:SetPoint(basePoint, pc, basePoint, PixelSnap(stepX * selfSlot) + cx, PixelSnap(stepY * selfSlot) + cy)
			sb:Show()
		end
		hdr:ClearAllPoints()
		hdr:SetPoint(basePoint, pc, basePoint, PixelSnap(stepX * hdrSlot) + cx, PixelSnap(stepY * hdrSlot) + cy)
	else
		if sb then
			sb:Hide()
		end
		hdr:ClearAllPoints()
		hdr:SetPoint(basePoint, pc, basePoint, cx, cy)
	end
	local first = (useSelf and not pSelfLast and sb) or hdr
	local selfMode = (useSelf and "button") or (hideSelf and "hidden") or "header"
	RF._partySelfMode = selfMode
	if first ~= RF._partyFirstSlot then
		RF._partyFirstSlot = first
		if RF.PF_ReAnchor then
			SafeCall(RF.PF_ReAnchor)
		end
	end
	return useSelf
end

-- Party container = the unlock mover's rect, always 5 slots.
function RF._SizePartyContainer(bw, bh, cs, unitGrowth)
	local pc = RF._partyContainerFrame
	if not pc then
		return
	end
	local cw, ch
	if unitGrowth == "RIGHT" or unitGrowth == "LEFT" then
		cw, ch = 5 * bw + 4 * cs, bh
	else
		cw, ch = bw, 5 * bh + 4 * cs
	end
	cw, ch = PixelSnap(cw), PixelSnap(ch)
	local curW, curH = pc:GetSize()
	if abs((curW or 0) - cw) > 0.01 or abs((curH or 0) - ch) > 0.01 then
		local hdr = RF._partyHeader
		local shown = hdr and hdr:IsShown()
		if shown then
			hdr:Hide()
		end
		pc:SetSize(cw, ch)
		if shown then
			hdr:Show()
		end
	end
end

-- Party container size + saved position (clamped on screen).
function RF._ApplyPartyContainerGeometry()
	local pc = RF._partyContainerFrame
	local s = Profile()
	if not pc or not s then
		return
	end
	if InCombatLockdown() then
		RF.AfterCombat("rf_partygeom", RF._ApplyPartyContainerGeometry)
		return
	end
	local pw, ph, pcs = RF.RF_PartyDims(s)
	local unitGrowth = RF._PartyGrowth(s)
	local bw, bh, cs = PixelSnap(pw), PixelSnap(ph), PixelSnap(pcs) + AlongPitch(s)
	RF._SizePartyContainer(bw, bh, cs, unitGrowth)
	if ns.IsUnlockAnchored and ns.IsUnlockAnchored("RF_PartyFrames") and pc:GetLeft() then
		return
	end
	local pos = s.partyUnlockPos
	if pos and pos.point then
		local cw, ch
		if unitGrowth == "RIGHT" or unitGrowth == "LEFT" then
			cw, ch = 5 * bw + 4 * cs, bh
		else
			cw, ch = bw, 5 * bh + 4 * cs
		end
		local x, y = RF._RFPosTopLeft(pos, cw, ch)
		x, y = RF._ClampTopLeft(x, y, cw, ch)
		pc:ClearAllPoints()
		pc:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", PixelSnap(x), PixelSnap(y))
	end
end

function RF._LayoutPartyFrames()
	local hdr = RF._partyHeader
	if not hdr or InCombatLockdown() then
		return
	end
	local s = Profile()
	local pw, ph, pcs = RF.RF_PartyDims(s)
	local bw, bh, cs = PixelSnap(pw), PixelSnap(ph), PixelSnap(pcs)
	cs = cs + AlongPitch(s)
	local unitGrowth = RF._PartyGrowth(s)
	local hdrPoint, hdrXOff, hdrYOff
	if unitGrowth == "DOWN" then
		hdrPoint, hdrXOff, hdrYOff = "TOP", 0, -cs
	elseif unitGrowth == "UP" then
		hdrPoint, hdrXOff, hdrYOff = "BOTTOM", 0, cs
	elseif unitGrowth == "RIGHT" then
		hdrPoint, hdrXOff, hdrYOff = "LEFT", cs, 0
	else
		hdrPoint, hdrXOff, hdrYOff = "RIGHT", -cs, 0
	end
	if hdr:GetAttribute("point") ~= hdrPoint or hdr:GetAttribute("xOffset") ~= hdrXOff
		or hdr:GetAttribute("yOffset") ~= hdrYOff then
		local wasShown = hdr:IsShown()
		if wasShown then
			hdr:Hide()
		end
		ClearChildren(hdr)
		hdr:SetAttribute("point", hdrPoint)
		hdr:SetAttribute("xOffset", hdrXOff)
		hdr:SetAttribute("yOffset", hdrYOff)
		if wasShown then
			hdr:Show()
		end
	end
	local useSelf = RF._PositionPartySlots(bw, bh, cs, unitGrowth)
	local hideSelf = s.partyHideSelf and true or false
	RF._SizePartyContainer(bw, bh, cs, unitGrowth)

	local pSortMode = s.partySortMode or s.sortMode
	local sortByRole = pSortMode == "ROLE"
	local roleOrder = s.partyRoleOrder or s.roleOrder or { "TANK", "HEALER", "DAMAGER" }
	local _, live = RF._RFVisWanted()
	local wantShowPlayer = (not hideSelf and not useSelf) and true or false
	local gb, sm, go, nl, gf = nil, nil, nil, nil, nil
	local smallRaidGroup = RF._SmallRaidGroup()
	if not live then
		nl = nil
	elseif RF._PartyInRaid() then
		local pSelfFirst = s.partyShowSelfFirst
		if pSelfFirst == nil then
			pSelfFirst = s.showSelfFirst
		end
		local pSelfLast = s.partySelfLast
		if pSelfLast == nil then
			pSelfLast = s.showSelfLast
		end
		nl = RF._BuildArenaNameList(hideSelf, pSelfFirst, pSelfLast, sortByRole, roleOrder, smallRaidGroup)
	elseif s.partyPrioritizeClass then
		nl = RF._BuildPartyClassNameList(wantShowPlayer, sortByRole, roleOrder, s.partyClassOrder)
	end
	if nl then
		gb, sm, go, gf = nil, "NAMELIST", "", nil
	else
		gb = sortByRole and "ASSIGNEDROLE" or nil
		sm = sortByRole and "NAME" or "INDEX"
		go = sortByRole and (table.concat(roleOrder, ",") .. ",NONE") or ""
		local fGroup = smallRaidGroup or ((s.partySmallRaid == true and not RF._InArena()) and 1) or nil
		gf = fGroup and tostring(fGroup) or "1,2,3,4,5,6,7,8"
	end
	local needs = (hdr:GetAttribute("groupBy") ~= gb) or (hdr:GetAttribute("sortMethod") ~= sm)
		or (hdr:GetAttribute("groupingOrder") ~= go) or (hdr:GetAttribute("showPlayer") ~= wantShowPlayer)
		or (hdr:GetAttribute("nameList") ~= nl) or (hdr:GetAttribute("groupFilter") ~= gf)
	if needs then
		local shown = hdr:IsShown()
		if shown then
			hdr:Hide()
		end
		hdr:SetAttribute("groupFilter", gf)
		hdr:SetAttribute("nameList", nl)
		hdr:SetAttribute("groupingOrder", go)
		hdr:SetAttribute("groupBy", gb)
		hdr:SetAttribute("sortMethod", sm)
		hdr:SetAttribute("showPlayer", wantShowPlayer)
		if shown then
			hdr:Show()
		end
	end
	RF._partyLaidVis = live
	if (not IsInRaid() or RF._PartyInRaid()) and RF.FB_ReAnchor then
		SafeCall(RF.FB_ReAnchor)
	end
	if RF.PT_Layout then
		SafeCall(RF.PT_Layout)
	end
	NotifyLayout("party")
end

-- Party reload: scale, button sizes, layout (retail ReloadPartyFrames minus
-- the per-button restyle).
function RF.ReloadPartyFrames()
	if not RF._partyHeader then
		return false
	end
	local s = Profile()
	local prevScale, prevBm = RF._partyIndicatorScale, RF._partyBmScale
	RF._UpdatePartyIndicatorScale()
	if InCombatLockdown() then
		RF.AfterCombat("rf_layout", RF.FullLayout)
	else
		local pw, ph = RF.RF_PartyDims(s)
		local bw, bh = PixelSnap(pw), PixelSnap(ph)
		for _, btn in ipairs(RF._partyAllButtons) do
			btn:SetSize(bw, bh)
		end
		RF._LayoutPartyFrames()
	end
	return prevScale ~= RF._partyIndicatorScale or prevBm ~= RF._partyBmScale
end

-------------------------------------------------------------------------------
--  Visibility (retail EUI_RaidFrames_Visibility.lua)
-------------------------------------------------------------------------------
function RF._InArena()
	local _, instanceType = IsInInstance()
	return instanceType == "arena"
end

function RF._PartyInRaid()
	if RF._InArena() then
		return true
	end
	local s = Profile()
	return (s and s.partySmallRaid == true and IsInRaid() and (GetNumGroupMembers() or 0) < 10) and true or false
end

function RF._SmallRaidGroup()
	if RF._InArena() or not RF._PartyInRaid() then
		return nil
	end
	return 1
end

-- (raidWanted, partyWanted) for the current group state.
function RF._RFVisWanted()
	local s = Profile()
	if not s then
		return false, false
	end
	if not IsInGroup() then
		return s.showWhenSolo and true or false, s.partyShowWhenSolo and true or false
	end
	if IsInRaid() and not RF._PartyInRaid() then
		return true, false
	end
	return false, true
end

-- Secure visibility drivers (macro per mode and Show When Solo).
RF._RF_VIS_MACROS = {
	raid = {
		group = { [true] = "[@raid1,exists] show; [@party1,exists][group] hide; show", [false] = "[@raid1,exists] show; hide" },
		small = { [true] = "[@raid10,exists] show; [@raid1,exists][@party1,exists][group] hide; show", [false] = "[@raid10,exists] show; hide" },
		arena = { [true] = "[@raid1,exists][@party1,exists][group] hide; show", [false] = "hide" },
	},
	party = {
		group = { [true] = "[@raid1,exists] hide; show", [false] = "[@raid1,exists] hide; [@party1,exists][group] show; hide" },
		small = { [true] = "[@raid10,exists] hide; show", [false] = "[@raid10,exists] hide; [@raid1,exists][@party1,exists][group] show; hide" },
		arena = { [true] = "show", [false] = "[@raid1,exists][@party1,exists][group] show; hide" },
	},
}

function RF._RFSyncVisDrivers()
	local c, pc = RF._containerFrame, RF._partyContainerFrame
	if not c or not pc or InCombatLockdown() then
		return
	end
	local s = Profile()
	local M = RF._RF_VIS_MACROS
	local mode = (RF._InArena() and "arena") or ((s.partySmallRaid == true) and "small") or "group"
	local r = M.raid[mode][s.showWhenSolo and true or false]
	local p = M.party[mode][s.partyShowWhenSolo and true or false]
	if RF._rfRaidVisMacro ~= r then
		RegisterStateDriver(c, "visibility", r)
		RF._rfRaidVisMacro = r
	end
	if RF._rfPartyVisMacro ~= p then
		RegisterStateDriver(pc, "visibility", p)
		RF._rfPartyVisMacro = p
	end
end

local function UpdateButtons(list)
	if not RF.UpdateButton then
		return
	end
	for _, btn in ipairs(list) do
		if btn:IsVisible() and btn:GetAttribute("unit") then
			SafeCall(RF.UpdateButton, btn)
		end
	end
end

function RF.UpdateVisibility()
	local c = RF._containerFrame
	if not c or InCombatLockdown() then
		return
	end
	if RF._previewActive then
		return
	end
	if not RF._sizePreviewTier and not RF._partyPvActive then
		c:SetAlpha(1)
	end
	local s = Profile()
	local visible = RF._RFVisWanted()
	local wasVisible = RF._raidFramesVisible
	RF._raidFramesVisible = visible
	local wantSolo = s.showWhenSolo or false
	for _, hdr in ipairs(separatedHdrs) do
		if hdr:GetAttribute("showSolo") ~= wantSolo then
			hdr:SetAttribute("showSolo", wantSolo)
		end
	end
	if RF._flatHeader and RF._flatHeader:GetAttribute("showSolo") ~= wantSolo then
		RF._flatHeader:SetAttribute("showSolo", wantSolo)
	end
	RF._RFSyncVisDrivers()
	c:SetShown(visible)
	if visible then
		if RF._rfRaidLaidVis ~= true then
			RF.LayoutGroups()
		end
		local force = RF._visForceRebuild
		RF._visForceRebuild = nil
		if (not wasVisible) or force then
			UpdateButtons(RF._raidButtons)
		end
	else
		if RF._rfRaidLaidVis ~= false then
			RF.LayoutGroups()
			RF._ApplyTierOffset()
		end
	end
end

function RF._UpdatePartyVisibility()
	local pc, hdr = RF._partyContainerFrame, RF._partyHeader
	if not hdr or InCombatLockdown() then
		return
	end
	if RF._partyPvActive or RF._previewActive then
		return
	end
	if not RF._sizePreviewTier then
		pc:SetAlpha(1)
	end
	local s = Profile()
	local _, visible = RF._RFVisWanted()
	local wasVisible = RF._partyFramesVisible
	RF._partyFramesVisible = visible
	local wantSolo = s.partyShowWhenSolo or false
	if hdr:GetAttribute("showSolo") ~= wantSolo then
		hdr:SetAttribute("showSolo", wantSolo)
	end
	RF._RFSyncVisDrivers()
	pc:SetShown(visible)
	if visible then
		if IsInGroup() then
			RF._SuppressBlizzParty()
		end
		RF._LayoutPartyFrames()
		UpdateButtons(RF._partyAllButtons)
	else
		if RF._partyLaidVis ~= false then
			RF._LayoutPartyFrames()
		end
	end
	if wasVisible ~= visible and RF.FB_ReAnchor then
		SafeCall(RF.FB_ReAnchor)
	end
end

-- Combat half: the drivers show/hide the containers; keep the flags in step.
function RF._RFCombatVisEdge()
	local raid, party = RF._RFVisWanted()
	if raid ~= (RF._raidFramesVisible == true) then
		RF._raidFramesVisible = raid
	end
	if party ~= (RF._partyFramesVisible == true) then
		RF._partyFramesVisible = party
	end
end

-------------------------------------------------------------------------------
--  Blizzard frames (retail ~863, done the ElvUI MoP way): the compact raid
--  container always goes away (the raid manager sidebar with markers and
--  ready check stays); Blizzard party frames go once our party frames show.
-------------------------------------------------------------------------------
do
	local hidden = CreateFrame("Frame")
	hidden:Hide()
	RF._blizzHiddenParent = hidden

	local function handleFrame(frame, reparent)
		if not frame then
			return
		end
		frame:UnregisterAllEvents()
		frame:Hide()
		if reparent then
			frame:SetParent(hidden)
		end
		local health = frame.healthbar or frame.healthBar
		if health and health.UnregisterAllEvents then
			health:UnregisterAllEvents()
		end
		local power = frame.manabar
		if power and power.UnregisterAllEvents then
			power:UnregisterAllEvents()
		end
		local spell = frame.spellbar
		if spell and spell.UnregisterAllEvents then
			spell:UnregisterAllEvents()
		end
		local alt = frame.powerBarAlt
		if alt and alt.UnregisterAllEvents then
			alt:UnregisterAllEvents()
		end
	end

	-- Blizzard raid group frames (CompactRaidGroup<n>, members, flat
	-- CompactRaidFrame<n>) keep their own GROUP_ROSTER_UPDATE / unit events
	-- after the container is hidden. Their 5.4.8 roster code can then call
	-- UnitHealthMax(nil) (CompactUnitFrame.lua:317). Silence them too.
	-- UnregisterAllEvents is safe in combat; Hide is not (secure buttons).
	local function silenceFrame(frame)
		if not frame then
			return
		end
		frame:UnregisterAllEvents()
		if not InCombatLockdown() then
			frame:Hide()
		end
	end
	local function silenceGroup(group)
		if not group then
			return
		end
		silenceFrame(group)
		local name = group:GetName()
		for m = 1, MEMBERS_PER_RAID_GROUP or 5 do
			silenceFrame(_G[name .. "Member" .. m])
		end
	end
	local function silenceBlizzRaidUnits()
		for g = 1, NUM_RAID_GROUPS or 8 do
			silenceGroup(_G["CompactRaidGroup" .. g])
		end
		local i = 1
		while _G["CompactRaidFrame" .. i] do
			silenceFrame(_G["CompactRaidFrame" .. i])
			i = i + 1
		end
	end
	local hookedGroups = false
	local function hookBlizzRaidGroups()
		if hookedGroups then
			return
		end
		hookedGroups = true
		if type(_G.CompactRaidGroup_GenerateForGroup) == "function" then
			hooksecurefunc("CompactRaidGroup_GenerateForGroup", function(groupIndex)
				silenceGroup(_G["CompactRaidGroup" .. tostring(groupIndex)])
			end)
		end
		if type(_G.CompactRaidFrameContainer_GetUnitFrame) == "function" then
			hooksecurefunc("CompactRaidFrameContainer_GetUnitFrame", function()
				silenceBlizzRaidUnits()
			end)
		end
	end

	local hookedContainer = false
	function RF._SuppressBlizzRaid()
		-- Groups can exist without the LoD container (FrameXML owns them).
		hookBlizzRaidGroups()
		silenceBlizzRaidUnits()
		if InCombatLockdown() then
			RF.AfterCombat("rf_blizzraid", RF._SuppressBlizzRaid)
			return
		end
		local crc = _G.CompactRaidFrameContainer
		if not crc then
			return
		end
		handleFrame(crc, true)
		if not hookedContainer then
			hookedContainer = true
			crc:HookScript("OnShow", function(self)
				if not InCombatLockdown() then
					self:Hide()
				end
			end)
			if type(_G.CompactRaidFrameManager_UpdateShown) == "function" then
				hooksecurefunc("CompactRaidFrameManager_UpdateShown", function()
					if not InCombatLockdown() and crc:IsShown() then
						crc:Hide()
					end
				end)
			end
		end
	end

	function RF._SuppressBlizzParty()
		if RF._blizzPartySuppressed then
			return
		end
		if InCombatLockdown() then
			RF.AfterCombat("rf_blizzparty", RF._SuppressBlizzParty)
			return
		end
		RF._blizzPartySuppressed = true
		for i = 1, 4 do
			handleFrame(_G["PartyMemberFrame" .. i], true)
		end
		handleFrame(_G.PartyMemberBackground, true)
		-- Raid-style party frames (FrameXML builds CompactPartyFrame lazily
		-- through CompactPartyFrame_Generate).
		local cpf = _G.CompactPartyFrame
		if cpf then
			handleFrame(cpf, true)
		elseif type(_G.CompactPartyFrame_Generate) == "function" and not RF._cpfHooked then
			RF._cpfHooked = true
			hooksecurefunc("CompactPartyFrame_Generate", function()
				local f = _G.CompactPartyFrame
				if f and not InCombatLockdown() then
					handleFrame(f, true)
				end
			end)
		end
	end
end

-------------------------------------------------------------------------------
--  Unlock mode (retail RegisterWithUnlockMode: RF_RaidFrames, RF_PartyFrames;
--  RF_HealerMana is registered by the Extras file)
-------------------------------------------------------------------------------
function RF.RegisterWithUnlockMode()
	if not (ns and ns.RegisterUnlockElements and ns.MakeUnlockElement) then
		return
	end
	if not RF._containerFrame or not RF._partyContainerFrame then
		return
	end
	local realPP = ns.PP
	local function snap(frame, v)
		if realPP and realPP.SnapForES and frame then
			return realPP.SnapForES(v, frame:GetEffectiveScale())
		end
		return floor(v + 0.5)
	end
	ns:RegisterUnlockElements({
		ns.MakeUnlockElement({
			key = "RF_RaidFrames",
			label = "Raid Frames",
			group = "Raid Frames",
			order = 500,
			noResize = true,
			noInitHook = true,
			getFrame = function()
				return RF._containerFrame
			end,
			getSize = function()
				return RF._containerFrame:GetWidth(), RF._containerFrame:GetHeight()
			end,
			savePos = function(_, point, relPoint, x, y, srcPoint, srcRelPoint)
				if srcPoint and not (srcPoint == "CENTER" and (srcRelPoint or "CENTER") == "CENTER") then
					x, y = RF._RFRebaseSavedCenter(x, y)
				end
				Profile().unlockPos = { point = point, relPoint = relPoint, x = snap(RF._containerFrame, x), y = snap(RF._containerFrame, y) }
			end,
			loadPos = function()
				return Profile().unlockPos
			end,
			clearPos = function()
				Profile().unlockPos = nil
			end,
			applyPos = function()
				RF._ApplyTierOffset()
			end,
		}),
		ns.MakeUnlockElement({
			key = "RF_PartyFrames",
			label = "Party Frames",
			group = "Raid Frames",
			order = 501,
			noResize = true,
			getFrame = function()
				return RF._partyContainerFrame
			end,
			getSize = function()
				return RF._partyContainerFrame:GetWidth(), RF._partyContainerFrame:GetHeight()
			end,
			savePos = function(_, point, relPoint, x, y)
				Profile().partyUnlockPos = { point = point, relPoint = relPoint, x = snap(RF._partyContainerFrame, x), y = snap(RF._partyContainerFrame, y) }
			end,
			loadPos = function()
				return Profile().partyUnlockPos
			end,
			clearPos = function()
				Profile().partyUnlockPos = nil
			end,
			applyPos = function()
				RF._ApplyPartyContainerGeometry()
			end,
		}),
	}, addonName)
	if ns.RegisterUnlockModeListener and not RF._unlockListener then
		RF._unlockListener = true
		ns:RegisterUnlockModeListener(addonName, function(on)
			-- Overlay previews fade out while Unlock Mode is open.
			if on and RF._previewActive and RF.HidePreview then
				RF.HidePreview()
			end
			if on and RF._partyPvActive and RF.HidePartyPreview then
				RF.HidePartyPreview()
			end
		end)
	end
end
RF._RFRegisterUnlock = RF.RegisterWithUnlockMode

-------------------------------------------------------------------------------
--  Full layout pass + roster events
-------------------------------------------------------------------------------
-- Everything protected, out of combat: tier/sizes, raid layout + position,
-- party layout + position, visibility. Buttons whose size or scale changed
-- re-run RF.RelayoutButton.
function RF.FullLayout()
	if not RF._containerFrame or not Profile() then
		return
	end
	if InCombatLockdown() then
		RF.AfterCombat("rf_layout", RF.FullLayout)
		return
	end
	RF._NormalizeTierOffsetAnchors()
	local raidChanged = RF.ReloadRaidFrames()
	RF._ApplyPartyContainerGeometry()
	local partyChanged = RF.ReloadPartyFrames()
	RF.UpdateVisibility()
	RF._UpdatePartyVisibility()
	if RF.RelayoutButton then
		if raidChanged then
			for _, btn in ipairs(RF._raidButtons) do
				SafeCall(RF.RelayoutButton, btn)
			end
		end
		if partyChanged then
			for _, btn in ipairs(RF._partyAllButtons) do
				SafeCall(RF.RelayoutButton, btn)
			end
		end
	end
end

-- Re-layout soon (next frame), or after combat.
function RF.RequestLayout()
	if RF._layoutQueued then
		return
	end
	RF._layoutQueued = true
	RF.After(0, function()
		RF._layoutQueued = false
		if InCombatLockdown() then
			RF._RFCombatVisEdge()
			RF.AfterCombat("rf_layout", RF.FullLayout)
		else
			RF.FullLayout()
		end
	end)
end

do
	local f = CreateFrame("Frame")
	RF._eventFrame = f
	f:RegisterEvent("GROUP_ROSTER_UPDATE")
	f:RegisterEvent("PLAYER_ROLES_ASSIGNED")
	f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
	f:RegisterEvent("PLAYER_ENTERING_WORLD")
	f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	f:RegisterEvent("PLAYER_REGEN_DISABLED")
	f:RegisterEvent("ADDON_LOADED")
	f:SetScript("OnEvent", function(_, event, arg1)
		if not ERF.started then
			return
		end
		if event == "ADDON_LOADED" then
			if arg1 == "Blizzard_CompactRaidFrames" then
				RF._SuppressBlizzRaid()
			end
			return
		end
		if event == "PLAYER_REGEN_DISABLED" then
			-- Mouse blockers of the options preview must never trap clicks.
			if RF._SetPreviewMouseBlock then
				RF._SetPreviewMouseBlock(false)
			end
			return
		end
		if event == "PLAYER_ENTERING_WORLD" then
			RF._SuppressBlizzRaid()
		end
		if InCombatLockdown() then
			RF._RFCombatVisEdge()
		end
		RF.RequestLayout()
	end)
end
