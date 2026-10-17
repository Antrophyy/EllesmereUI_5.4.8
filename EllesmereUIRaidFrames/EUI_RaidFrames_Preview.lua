-------------------------------------------------------------------------------
--  EUI_RaidFrames_Preview.lua  (5.4.8 port of retail EUI_RaidFrames_Preview)
--
--  Fake members while the settings are open. Preview Mode (previewMode):
--    "overlay" = a dark panel docked beside the settings window, the real
--                frames dimmed (alpha 0.2);
--    "real"    = the fake frames drawn where the real ones sit, the real
--                frames hidden (alpha 0) and mouse-blocked;
--    "none"    = no preview.
--  Raid preview: 20 members (4 groups) at the base size, laid out with the
--  live layout math. Size preview (RF.ShowSizePreview(tier)): the tier's
--  member count and size where the live frames would land. Party preview:
--  5 members with the party view. Buttons are plain (insecure) Buttons with
--  rfKind "preview", btn.rfSettings = the view, btn.rfPreview = fake data,
--  painted by the Button file (RF.StyleButton / RF.UpdateButton).
--  Not ported: the retail aura/buff tickers (the aura files draw their own
--  sample icons from btn.rfPreview), test mode, spec-override overlays.
-------------------------------------------------------------------------------
local addonName, RF = ...
local ns = EllesmereUI
local ERF = RF.ERF

local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local ipairs, pairs, tostring = ipairs, pairs, tostring
local random = math.random

local function Profile()
	return RF.Profile()
end

local function PixelSnap(v)
	return RF.Snap(v or 0, UIParent)
end

local function SafeCall(fn, ...)
	if not fn then
		return
	end
	local ok, err = pcall(fn, ...)
	if not ok then
		geterrorhandler()(err)
	end
end

-------------------------------------------------------------------------------
--  Fake roster (retail ns._PV_ROSTER; classes 5.4.8 does not have swapped)
-------------------------------------------------------------------------------
RF._PV_ROSTER = {
	{ name = "Xeno", class = "MONK", role = "TANK" },
	{ name = "Grimjaw", class = "WARRIOR", role = "TANK" },
	{ name = "Stickymittens", class = "PALADIN", role = "HEALER" },
	{ name = "Toxik", class = "MONK", role = "HEALER" },
	{ name = "Delasteve", class = "PALADIN", role = "HEALER" },
	{ name = "Burne", class = "DRUID", role = "HEALER" },
	{ name = "Lily", class = "PALADIN", role = "HEALER" },
	{ name = "Kulia", class = "PALADIN", role = "DAMAGER" },
	{ name = "Thiaspriest", class = "PRIEST", role = "DAMAGER" },
	{ name = "Pelleas", class = "SHAMAN", role = "DAMAGER" },
	{ name = "Khardi", class = "HUNTER", role = "DAMAGER" },
	{ name = "Morgath", class = "DEATHKNIGHT", role = "DAMAGER" },
	{ name = "Drakmoor", class = "WARRIOR", role = "DAMAGER" },
	{ name = "Embertide", class = "MAGE", role = "DAMAGER" },
	{ name = "Elyndra", class = "MAGE", role = "DAMAGER" },
	{ name = "Fenwick", class = "ROGUE", role = "DAMAGER" },
	{ name = "Zulkhar", class = "WARLOCK", role = "DAMAGER" },
	{ name = "Luneth", class = "DRUID", role = "DAMAGER" },
	{ name = "Stormhelm", class = "SHAMAN", role = "DAMAGER" },
}

-- Power type by class (numbers = 5.4.8 power type ids, RF.POWER_TOKENS).
local CLASS_POWER = {
	WARRIOR = 1, ROGUE = 3, DEATHKNIGHT = 6, HUNTER = 2,
}

local pvData = {}      -- [i] = fake member table (raid, up to 40)
local partyData = {}   -- [i] = fake member table (party, 5)

-- One fake member: index 1 is the player.
local function NewMember(i, entry)
	local m = {}
	if i == 1 then
		local _, pc = UnitClass("player")
		m.name = UnitName("player") or "Player"
		m.class = pc or "WARRIOR"
		local role = RF.UnitRole("player")
		if role ~= "TANK" and role ~= "HEALER" then
			role = "DAMAGER"
		end
		m.role = role
		m.isPlayer = true
		m.leader = true
	else
		m.name = entry.name
		m.class = entry.class
		m.role = entry.role
	end
	m.level = 90
	m.hpMax = 100
	m.hp = 40 + random(60)
	m.powerType = (m.role == "HEALER") and 0 or (CLASS_POWER[m.class] or 0)
	m.powerToken = RF.POWER_TOKENS and RF.POWER_TOKENS[m.powerType] or "MANA"
	m.powerMax = 100
	m.power = 50 + random(50)
	m.absorb = 0
	m.healAbsorb = 0
	m.incomingHeal = 0
	m.index = i
	return m
end

local function FillExtras(list, count)
	-- Shields: one per group of five, heal absorbs and heal prediction on two.
	for g = 0, floor((count - 1) / 5) do
		local slot = g * 5 + random(5)
		if list[slot] then
			list[slot].absorb = 5 + random(25)
		end
	end
	local a, b = 1 + random(max(1, count - 1)), 1 + random(max(1, count - 1))
	if list[a] then
		list[a].healAbsorb = 20 + random(20)
	end
	if list[b] and list[b].hp < 95 then
		list[b].incomingHeal = 10 + random(20)
	end
	-- Two dispellable debuffs and one member out of range.
	if list[3] then
		list[3].dispelType = "Magic"
	end
	if list[min(count, 8)] then
		list[min(count, 8)].dispelType = "Poison"
	end
	if list[min(count, 4)] and count > 4 then
		list[min(count, 4)].outOfRange = true
	end
	if list[2] then
		list[2].raidMarker = 1
		list[2].assist = true
		list[2].threat = 3
		list[2].inCombat = true
	end
end

local function BuildRoster(list, count)
	for i = 1, 40 do
		list[i] = nil
	end
	local n = #RF._PV_ROSTER
	for i = 1, count do
		list[i] = NewMember(i, RF._PV_ROSTER[((i - 2) % n) + 1])
	end
	FillExtras(list, count)
end

-- Sort one block of members like the live headers (role order, self pin).
local function SortBlock(block, sortByRole, roleOrder, selfFirst, selfLast)
	local pri = {}
	for p, r in ipairs(roleOrder or { "TANK", "HEALER", "DAMAGER" }) do
		pri[r] = p
	end
	local pin = (selfFirst or selfLast) and true or false
	local sl = selfLast and true or false
	table.sort(block, function(a, b)
		local ap, bp = (pin and a.isPlayer) and true or false, (pin and b.isPlayer) and true or false
		if ap ~= bp then
			return ap ~= sl
		end
		if sortByRole then
			local ra, rb = pri[a.role] or 99, pri[b.role] or 99
			if ra ~= rb then
				return ra < rb
			end
		end
		return a.index < b.index
	end)
end

-------------------------------------------------------------------------------
--  Views
-------------------------------------------------------------------------------
-- Raid preview: the raw profile (base 20-man size, no tier scale).
RF._pvRaidView = setmetatable({}, {
	__index = function(_, key)
		local p = Profile()
		return p and p[key]
	end,
})

-- Size preview: the tier's size + its auto-resize scale.
local sizeView = { w = nil, h = nil, scale = 1 }
RF._pvSizeView = setmetatable({}, {
	__index = function(_, key)
		if key == "frameWidth" and sizeView.w then
			return sizeView.w
		end
		if key == "frameHeight" and sizeView.h then
			return sizeView.h
		end
		local p = Profile()
		local val = p and p[key]
		if RF.INDICATOR_SCALE_KEYS[key] and type(val) == "number" and sizeView.scale ~= 1 then
			return val * sizeView.scale
		end
		return val
	end,
})

-------------------------------------------------------------------------------
--  Buttons
-------------------------------------------------------------------------------
local raidButtons, partyButtons = {}, {}
RF._previewButtons = raidButtons
RF._partyPreviewButtons = partyButtons
local groupLabels = {}

local function NewPreviewButton(parent)
	local btn = CreateFrame("Button", nil, parent)
	btn.rfKind = "preview"
	btn.rfPreview = {}
	btn:SetSize(72, 46)
	if RF.StyleButton then
		SafeCall(RF.StyleButton, btn)
	end
	btn:EnableMouse(false)
	btn:Hide()
	return btn
end

local function GetButton(list, i, parent)
	local btn = list[i]
	if not btn then
		btn = NewPreviewButton(parent)
		list[i] = btn
	end
	if btn:GetParent() ~= parent then
		btn:SetParent(parent)
	end
	return btn
end

-- Size + paint one preview button from its fake member.
local function Paint(btn, view, w, h, data)
	btn.rfSettings = view
	btn.rfPreview = data
	btn:SetSize(PixelSnap(w), PixelSnap(h))
	btn:Show()
	if RF.RelayoutButton then
		SafeCall(RF.RelayoutButton, btn)
	end
	if RF.UpdateButton then
		SafeCall(RF.UpdateButton, btn)
	end
end

-------------------------------------------------------------------------------
--  Containers
-------------------------------------------------------------------------------
local overlay, realHost, partyOverlay

local function OptionsWindow()
	return ns and ns._mainFrame
end

local function OptionsShown()
	local mf = OptionsWindow()
	return (mf and mf:IsShown()) and true or false
end

local function NewOverlay()
	local oc = CreateFrame("Frame", nil, UIParent)
	oc:SetFrameStrata("FULLSCREEN_DIALOG")
	oc:SetFrameLevel(10)
	oc:SetClampedToScreen(true)
	local bg = oc:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetTexture(0, 0, 0, 0.9)
	local title = oc:CreateFontString(nil, "OVERLAY")
	RF.SetFont(title, 13)
	title:SetPoint("TOP", oc, "TOP", 0, -7)
	oc.title = title
	-- Group numbers draw above the bars.
	local num = CreateFrame("Frame", nil, oc)
	num:SetAllPoints(oc)
	num:SetFrameLevel(min(oc:GetFrameLevel() + 60, 127))
	oc.numbers = num
	oc:Hide()
	return oc
end

-- Docked to the left edge of the settings window (screen center fallback).
local function DockOverlay(oc, titleText)
	oc:ClearAllPoints()
	local mf = OptionsWindow()
	if mf then
		oc:SetPoint("RIGHT", mf, "LEFT", -6, 0)
	else
		oc:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
	RF.SetFont(oc.title, 13)
	oc.title:SetText(titleText)
	oc.title:SetTextColor(1, 1, 1, 0.9)
	oc:Show()
end

local function RealHost()
	if not realHost then
		realHost = CreateFrame("Frame", nil, UIParent)
		realHost:SetFrameStrata("HIGH")
		local num = CreateFrame("Frame", nil, realHost)
		num:SetAllPoints(realHost)
		num:SetFrameLevel(min(realHost:GetFrameLevel() + 60, 127))
		realHost.numbers = num
	end
	return realHost
end

-------------------------------------------------------------------------------
--  Real frames under the preview: alpha (combat-legal) + mouse blockers
--  (our own insecure frames, dropped at combat start)
-------------------------------------------------------------------------------
do
	local rfBlock, partyBlock
	local function block(frame, host)
		if not frame then
			frame = CreateFrame("Frame", nil, UIParent)
			frame:EnableMouse(true)
		end
		frame:ClearAllPoints()
		frame:SetAllPoints(host)
		frame:SetFrameStrata(host:GetFrameStrata())
		frame:SetFrameLevel(min(host:GetFrameLevel() + 50, 127))
		frame:Show()
		return frame
	end
	function RF._SetPreviewMouseBlock(on)
		if on and not InCombatLockdown() then
			local c, pc = RF._containerFrame, RF._partyContainerFrame
			if c then
				rfBlock = block(rfBlock, c)
			end
			if pc then
				partyBlock = block(partyBlock, pc)
			end
		else
			if rfBlock then
				rfBlock:Hide()
			end
			if partyBlock then
				partyBlock:Hide()
			end
		end
	end
	function RF._RefreshPreviewMouseBlockStrata()
		if rfBlock and rfBlock:IsShown() and RF._containerFrame then
			rfBlock:SetFrameStrata(RF._containerFrame:GetFrameStrata())
		end
		if partyBlock and partyBlock:IsShown() and RF._partyContainerFrame then
			partyBlock:SetFrameStrata(RF._partyContainerFrame:GetFrameStrata())
		end
	end
end

-- Overlay: real frames faint (0.2), no block. Real: hidden (0) + blocked.
function RF._SetRealFramesPreviewHidden(on)
	local s = Profile()
	local isOverlay = s and s.previewMode == "overlay"
	local a = 1
	if on then
		a = isOverlay and 0.2 or 0
	end
	if RF._containerFrame then
		RF._containerFrame:SetAlpha(a)
	end
	if RF._partyContainerFrame then
		RF._partyContainerFrame:SetAlpha(a)
	end
	RF._SetPreviewMouseBlock(on and not isOverlay)
	if RF.PF_SetPreviewAlpha then
		SafeCall(RF.PF_SetPreviewAlpha, a)
	end
end

-------------------------------------------------------------------------------
--  Raid preview (retail RefreshPreview)
-------------------------------------------------------------------------------
-- Lay out `count` members of `list` in groups of five on `anchor`.
-- Returns the footprint.
local function LayoutRaid(view, list, count, anchor, padX, padY, numbersHost, unitGrowth, groupGrowth, bw, bh)
	local s = view
	local cs = PixelSnap(RF.CellSpacing(s))
	local gs = PixelSnap(RF.GroupSpacing(s))
	local groupW, groupH
	if unitGrowth == "RIGHT" or unitGrowth == "LEFT" then
		groupW, groupH = 5 * bw + 4 * cs, bh
	else
		groupW, groupH = bw, 5 * bh + 4 * cs
	end
	local nGroups = floor((count + 4) / 5)
	local slots, minGX, maxGY = RF._RFGroupFlow(groupGrowth, groupW, groupH, gs, max(nGroups, 4))
	local uStepX, uStepY = 0, 0
	if unitGrowth == "DOWN" then
		uStepY = -(bh + cs)
	elseif unitGrowth == "UP" then
		uStepY = bh + cs
	elseif unitGrowth == "RIGHT" then
		uStepX = bw + cs
	else
		uStepX = -(bw + cs)
	end
	local minUX, maxUY = min(0, 4 * uStepX), max(0, 4 * uStepY)
	-- Custom group order moves each group's frames to its visual slot.
	local slotOf = nil
	local order = s.customGroupOrder and not s.mergeGroups and RF._RFValidatedGroupOrder(s.groupOrder)
	if order then
		slotOf = {}
		local k = 0
		for _, g in ipairs(order) do
			if g <= nGroups then
				slotOf[g] = k
				k = k + 1
			end
		end
	end
	local sortByRole = s.sortMode == "ROLE"
	local selfFirst = s.showSelfFirst or s.showSelfLast
	for g = 0, nGroups - 1 do
		local block = {}
		for u = 1, 5 do
			local m = list[g * 5 + u]
			if m then
				block[#block + 1] = m
			end
		end
		SortBlock(block, sortByRole, s.roleOrder, selfFirst, s.showSelfLast)
		local slot = slotOf and slotOf[g + 1] or g
		local gx = slots[slot][1] - minGX
		local gy = slots[slot][2] - maxGY
		local first = nil
		for u = 0, #block - 1 do
			local idx = g * 5 + u + 1
			local btn = GetButton(raidButtons, idx, anchor)
			btn:ClearAllPoints()
			btn:SetPoint("TOPLEFT", anchor, "TOPLEFT", gx + u * uStepX - minUX + padX, gy + u * uStepY - maxUY - padY)
			Paint(btn, view, bw, bh, block[u + 1])
			if u == 0 then
				first = btn
			end
		end
		-- Group numbers: the preview always shows them (shared size/color).
		local lbl = groupLabels[g + 1]
		if not lbl then
			lbl = numbersHost:CreateFontString(nil, "OVERLAY")
			groupLabels[g + 1] = lbl
		end
		if lbl:GetParent() ~= numbersHost then
			lbl:SetParent(numbersHost)
		end
		RF.SetFont(lbl, s.groupNumberSize or 10)
		local gc = s.groupNumberColor or {}
		lbl:SetTextColor(gc.r or 1, gc.g or 1, gc.b or 1, gc.a or 0.75)
		lbl:SetText(tostring(g + 1))
		lbl:ClearAllPoints()
		local ox, oy = s.groupNumberOffsetX or 0, s.groupNumberOffsetY or 0
		if first then
			if unitGrowth == "DOWN" then
				lbl:SetPoint("BOTTOM", first, "TOP", ox, 4 + oy)
			elseif unitGrowth == "UP" then
				lbl:SetPoint("TOP", first, "BOTTOM", ox, -4 + oy)
			elseif unitGrowth == "RIGHT" then
				lbl:SetPoint("RIGHT", first, "LEFT", -3 + ox, oy)
			else
				lbl:SetPoint("LEFT", first, "RIGHT", 3 + ox, oy)
			end
			lbl:Show()
		else
			lbl:Hide()
		end
	end
	for i = nGroups + 1, #groupLabels do
		groupLabels[i]:Hide()
	end
	for i = count + 1, #raidButtons do
		raidButtons[i]:Hide()
	end
	if nGroups <= 4 then
		return RF._RFFootprint(bw, bh, unitGrowth, groupGrowth, cs, gs)
	end
	-- More groups than the 4-group box (size preview 25-40): measure.
	local w, h = 0, 0
	for i = 0, nGroups - 1 do
		w = max(w, slots[i][1] - minGX + groupW)
		h = max(h, maxGY - slots[i][2] + groupH)
	end
	return w, h
end

local function HideRaidButtons()
	for _, b in ipairs(raidButtons) do
		b:Hide()
	end
	for _, l in ipairs(groupLabels) do
		l:Hide()
	end
end

function RF.RefreshPreview()
	if RF._partyPvActive then
		return RF.RefreshPartyPreview()
	end
	if RF._sizePreviewTier then
		return RF.ShowSizePreview(RF._sizePreviewTier)
	end
	if not RF._previewActive then
		return
	end
	local s = Profile()
	local view = RF._pvRaidView
	local ug, gg = RF._RFEffectiveGrowth(s.unitGrowth or "DOWN", s.groupGrowth or "RIGHT", s.mergeGroups)
	local bw, bh = PixelSnap(s.frameWidth or 72), PixelSnap(s.frameHeight or 46)
	local isOverlay = s.previewMode == "overlay"
	if isOverlay then
		overlay = overlay or NewOverlay()
		if realHost then
			realHost:Hide()
		end
		local pad, top = 20, 25
		local w, h = LayoutRaid(view, pvData, 20, overlay, pad, pad + top, overlay.numbers, ug, gg, bw, bh)
		overlay:SetSize(w + pad * 2, h + pad * 2 + top)
		DockOverlay(overlay, "Overlay Preview")
	else
		if overlay then
			overlay:Hide()
		end
		local host = RealHost()
		local w, h = LayoutRaid(view, pvData, 20, host, 0, 0, host.numbers, ug, gg, bw, bh)
		host:SetSize(max(w, 1), max(h, 1))
		host:ClearAllPoints()
		local bl, bt = RF._RFBaseTopLeft()
		if bl then
			bl, bt = RF._ClampTopLeft(bl, bt, w, h)
			host:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", PixelSnap(bl), PixelSnap(bt))
		else
			host:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
		end
		host:Show()
	end
end

function RF.ShowPreview()
	if not OptionsShown() or InCombatLockdown() then
		return
	end
	if RF._HookOptionsWindow then
		RF._HookOptionsWindow()
	end
	local s = Profile()
	if not s or (s.previewMode or "overlay") == "none" then
		return
	end
	if RF._sizePreviewTier then
		RF.HideSizePreview(true)
	end
	if RF._partyPvActive then
		RF.HidePartyPreview(true)
	end
	if not RF._previewActive then
		RF._previewActive = true
		BuildRoster(pvData, 20)
	end
	RF._SetRealFramesPreviewHidden(true)
	RF.RefreshPreview()
end

local function RestoreReal()
	RF._SetRealFramesPreviewHidden(false)
	if not InCombatLockdown() then
		if RF.LayoutGroups then
			RF.LayoutGroups()
		end
		if RF._ApplyTierOffset then
			RF._ApplyTierOffset()
		end
		if RF.UpdateVisibility then
			RF.UpdateVisibility()
		end
		if RF._UpdatePartyVisibility then
			RF._UpdatePartyVisibility()
		end
	end
end

-- skipRestore: another preview takes over at once (no real-frame flash).
function RF.HidePreview(skipRestore)
	if not RF._previewActive then
		return
	end
	RF._previewActive = false
	HideRaidButtons()
	if overlay then
		overlay:Hide()
	end
	if realHost then
		realHost:Hide()
	end
	if not skipRestore then
		RestoreReal()
	end
end

-- Live Real <-> Overlay <-> None switch.
function RF.ApplyPreviewMode()
	local s = Profile()
	local mode = s and s.previewMode or "overlay"
	if mode == "none" then
		RF.HidePreview()
		RF.HidePartyPreview()
		return
	end
	if RF._partyPvActive then
		RF._SetRealFramesPreviewHidden(true)
		RF.RefreshPartyPreview()
	elseif RF._previewActive then
		RF._SetRealFramesPreviewHidden(true)
		RF.RefreshPreview()
	else
		RF.ShowPreview()
	end
end

function RF.IsPreviewActive()
	return (RF._previewActive or RF._partyPvActive or RF._sizePreviewTier) and true or false
end

function RF.ResetPreviewRandomization()
	if RF._previewActive then
		BuildRoster(pvData, 20)
		RF.RefreshPreview()
	end
	if RF._partyPvActive then
		BuildRoster(partyData, 5)
		RF.RefreshPartyPreview()
	end
end

-------------------------------------------------------------------------------
--  Size preview (retail _ShowSizePreview): a tier's member count at the
--  tier's size and growth, screen-anchored where the live frames land.
-------------------------------------------------------------------------------
function RF.ShowSizePreview(tier)
	if InCombatLockdown() then
		return
	end
	tier = tonumber(tier) or 20
	local s = Profile()
	if not s then
		return
	end
	if RF._previewActive then
		RF.HidePreview(true)
	end
	if RF._partyPvActive then
		RF.HidePartyPreview(true)
	end
	if RF._sizePreviewTier ~= tier then
		BuildRoster(pvData, tier)
	end
	RF._sizePreviewTier = tier
	local ov = nil
	if tier ~= 20 then
		local _, o = RF._RFResolveTierOverride(tier)
		ov = o
	end
	local w0 = (ov and ov.width) or s.frameWidth or 72
	local h0 = (ov and ov.height) or s.frameHeight or 46
	sizeView.w, sizeView.h = w0, h0
	local scale = max(min(min(w0 / (s.frameWidth or 72), h0 / (s.frameHeight or 46)), 1.5), 0.7)
	sizeView.scale = s.autoResizeIndicators and scale or 1
	local ug, gg = RF._RFEffectiveGrowth((ov and ov.unitGrowth) or s.unitGrowth or "DOWN",
		(ov and ov.groupGrowth) or s.groupGrowth or "RIGHT", s.mergeGroups)
	local bw, bh = PixelSnap(w0), PixelSnap(h0)
	if overlay then
		overlay:Hide()
	end
	local host = RealHost()
	local w, h = LayoutRaid(RF._pvSizeView, pvData, tier, host, 0, 0, host.numbers, ug, gg, bw, bh)
	host:SetSize(max(w, 1), max(h, 1))
	host:ClearAllPoints()
	local cs = PixelSnap(RF.CellSpacing(s))
	local gs = PixelSnap(RF.GroupSpacing(s))
	local tw, th = RF._RFFootprint(w0, h0, ug, gg, cs, gs)
	local x, y = RF._RFTierTopLeft(tw, th, ug, gg, (ov and ov.offsetX) or 0, (ov and ov.offsetY) or 0)
	if x then
		x, y = RF._ClampTopLeft(x, y, w, h)
		host:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", PixelSnap(x), PixelSnap(y))
	else
		host:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
	host:Show()
	-- Real frames hidden under it (always screen-anchored).
	if RF._containerFrame then
		RF._containerFrame:SetAlpha(0)
	end
end

function RF.HideSizePreview(skipRestore)
	if not RF._sizePreviewTier then
		return
	end
	RF._sizePreviewTier = nil
	HideRaidButtons()
	if realHost then
		realHost:Hide()
	end
	if not skipRestore then
		RestoreReal()
	end
end
RF._ShowSizePreview = RF.ShowSizePreview
RF._HideSizePreview = RF.HideSizePreview

-------------------------------------------------------------------------------
--  Party preview (retail RefreshPartyPreview / ShowPartyPreview)
-------------------------------------------------------------------------------
function RF.RefreshPartyPreview()
	if not RF._partyPvActive then
		return
	end
	local s = Profile()
	if RF._UpdatePartyIndicatorScale then
		RF._UpdatePartyIndicatorScale()
	end
	local view = RF._scaledPartyProxy
	local pw, ph, pcs = RF.RF_PartyDims(s)
	local w, h, spacing = PixelSnap(pw), PixelSnap(ph), PixelSnap(pcs)
	local pitch = spacing + (RF._PT_AlongPitchSafe and RF._PT_AlongPitchSafe(s) or 0)
	local unitGrowth = RF._PartyGrowth(s)

	-- Party order: Sort By + Self First / Self Last; Hide Self drops you.
	local sortMode = s.partySortMode or s.sortMode
	local pSelfFirst = s.partyShowSelfFirst
	if pSelfFirst == nil then
		pSelfFirst = s.showSelfFirst
	end
	local pSelfLast = s.partySelfLast
	if pSelfLast == nil then
		pSelfLast = s.showSelfLast
	end
	local block = {}
	for i = 1, 5 do
		if partyData[i] and not (s.partyHideSelf and partyData[i].isPlayer) then
			block[#block + 1] = partyData[i]
		end
	end
	SortBlock(block, sortMode == "ROLE", s.partyRoleOrder or s.roleOrder, pSelfFirst or pSelfLast, pSelfLast)
	local shown = #block

	local stepX, stepY, basePoint = 0, 0, "TOPLEFT"
	if unitGrowth == "RIGHT" then
		stepX = w + pitch
	elseif unitGrowth == "LEFT" then
		stepX = -(w + pitch)
		basePoint = "TOPRIGHT"
	elseif unitGrowth == "UP" then
		stepY = h + pitch
		basePoint = "BOTTOMLEFT"
	else
		stepY = -(h + pitch)
	end
	local isVert = unitGrowth == "DOWN" or unitGrowth == "UP"
	local totalW = isVert and w or (w * shown + pitch * (shown - 1))
	local totalH = isVert and (h * shown + pitch * (shown - 1)) or h

	local anchor, padX, padY = nil, 0, 0
	if s.previewMode == "overlay" then
		partyOverlay = partyOverlay or NewOverlay()
		anchor = partyOverlay
		padX, padY = 10, 10 + 25
		partyOverlay:SetSize(totalW + 20, totalH + 20 + 25)
		DockOverlay(partyOverlay, "Overlay Preview")
		-- Inside the overlay the stack runs from its own corner.
		if basePoint == "TOPRIGHT" then
			padX = -10
		elseif basePoint == "BOTTOMLEFT" then
			padY = -10
		end
	else
		if partyOverlay then
			partyOverlay:Hide()
		end
		anchor = RF._partyContainerFrame or UIParent
	end
	local centerShift = 0
	if s.partyFlipGrowth == "centered" and anchor == RF._partyContainerFrame then
		centerShift = (5 - shown) / 2
	end
	local cx, cy = PixelSnap(stepX * centerShift), PixelSnap(stepY * centerShift)
	local parent = (anchor == partyOverlay) and partyOverlay or UIParent
	for i = 1, shown do
		local btn = GetButton(partyButtons, i, parent)
		btn:SetFrameStrata(anchor == partyOverlay and "FULLSCREEN_DIALOG" or "HIGH")
		btn:ClearAllPoints()
		local ox = PixelSnap(stepX * (i - 1)) + cx
		local oy = PixelSnap(stepY * (i - 1)) + cy
		if anchor == partyOverlay then
			btn:SetPoint(basePoint, anchor, basePoint, ox + padX, oy - padY)
		else
			btn:SetPoint(basePoint, anchor, basePoint, ox, oy)
		end
		Paint(btn, view, w, h, block[i])
	end
	for i = shown + 1, #partyButtons do
		partyButtons[i]:Hide()
	end
end

function RF.ShowPartyPreview()
	if not OptionsShown() or InCombatLockdown() then
		return
	end
	if RF._HookOptionsWindow then
		RF._HookOptionsWindow()
	end
	local s = Profile()
	if not s or (s.previewMode or "overlay") == "none" then
		return
	end
	if RF._sizePreviewTier then
		RF.HideSizePreview(true)
	end
	if RF._previewActive then
		RF.HidePreview(true)
	end
	if not RF._partyPvActive then
		RF._partyPvActive = true
		BuildRoster(partyData, 5)
	end
	RF._SetRealFramesPreviewHidden(true)
	RF.RefreshPartyPreview()
end

function RF.HidePartyPreview(skipRestore)
	if not RF._partyPvActive then
		return
	end
	RF._partyPvActive = false
	for _, b in ipairs(partyButtons) do
		b:Hide()
	end
	if partyOverlay then
		partyOverlay:Hide()
	end
	if not skipRestore then
		RestoreReal()
	end
end

-- Whatever preview is on screen, closed and the real frames restored.
function RF.EnsureRealFramesRestored()
	RF.HidePreview(true)
	RF.HidePartyPreview(true)
	RF.HideSizePreview(true)
	RestoreReal()
end

-- Retail ns names the options code may call.
ERF.ShowPreview = function()
	RF.ShowPreview()
end
ERF.HidePreview = function()
	RF.EnsureRealFramesRestored()
end
