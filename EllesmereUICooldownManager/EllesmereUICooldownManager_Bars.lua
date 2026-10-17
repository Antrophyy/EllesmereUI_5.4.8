-------------------------------------------------------------------------------
--  EllesmereUICooldownManager_Bars.lua
--  The CDM bars: build, layout (retail LayoutCDMBar: rows, base row count,
--  row growth, grow direction, orientation), position (Unlock Mode "CDM_" ..
--  key movers, retail edge-anchored saved points), anchoring to another bar or
--  the cursor, visibility, out-of-combat fade, the event / update driver and
--  the boot sequence.
-------------------------------------------------------------------------------
local addonName, P = ...
local ns = EllesmereUI
local CDM = P.CDM
local BV = CDM.BV

local floor, ceil, max, min, abs = math.floor, math.ceil, math.max, math.min, math.abs

local barFrames = {}   -- [key] = frame
CDM.barFrames = barFrames
local inCombat = false
local preview = false   -- options open: show sample state on every bar

-- Default spots for bars without a saved position.
local DEFAULT_POS = {
	cooldowns = { point = "CENTER", relPoint = "CENTER", x = 0, y = -180 },
	utility   = { point = "CENTER", relPoint = "CENTER", x = 0, y = -240 },
	buffs     = { point = "CENTER", relPoint = "CENTER", x = 0, y = -120 },
}

-------------------------------------------------------------------------------
--  Position helpers (retail EUI_CDM_Bars.lua)
-------------------------------------------------------------------------------
function CDM.ResolveGrowAnchorPoint(bd, ignoreRowGrow)
	local grow = (bd and bd.growDirection) or "CENTER"
	local horiz, vert
	if grow == "RIGHT" then horiz = "LEFT"
	elseif grow == "LEFT" then horiz = "RIGHT"
	elseif grow == "DOWN" then vert = "TOP"
	elseif grow == "UP" then vert = "BOTTOM" end
	local rowGrow = bd and bd.rowGrowDirection
	if rowGrow and not ignoreRowGrow then
		if bd.verticalOrientation then
			if rowGrow == "RIGHT" then horiz = horiz or "LEFT"
			elseif rowGrow == "LEFT" then horiz = horiz or "RIGHT" end
		else
			if rowGrow == "DOWN" then vert = vert or "TOP"
			elseif rowGrow == "UP" then vert = vert or "BOTTOM" end
		end
	end
	local pt = (vert or "") .. (horiz or "")
	if pt == "" then return "CENTER" end
	return pt
end

function CDM.CenterToAnchorCoord(pt, x, y, fw, fh)
	local sx, sy = x, y
	if pt:find("LEFT", 1, true) then sx = x - fw / 2
	elseif pt:find("RIGHT", 1, true) then sx = x + fw / 2 end
	if pt:find("TOP", 1, true) then sy = y + fh / 2
	elseif pt:find("BOTTOM", 1, true) then sy = y - fh / 2 end
	return sx, sy
end

function CDM.AnchorCoordToCenter(pt, sx, sy, fw, fh)
	local x, y = sx, sy
	if pt:find("LEFT", 1, true) then x = sx + fw / 2
	elseif pt:find("RIGHT", 1, true) then x = sx - fw / 2 end
	if pt:find("TOP", 1, true) then y = sy - fh / 2
	elseif pt:find("BOTTOM", 1, true) then y = sy + fh / 2 end
	return x, y
end

-- Positions a bar frame from its saved point (edge-anchored so it grows from
-- the fixed edge), or next to the bar it is anchored to.
local function ApplyPosition(bd, f)
	local w, h = f:GetWidth() or 0, f:GetHeight() or 0
	f:ClearAllPoints()
	-- Anchored to another CDM bar (retail anchorTo = bar key).
	local target = bd.anchorTo and bd.anchorTo ~= "none" and barFrames[bd.anchorTo]
	if target and target ~= f then
		local side = bd.anchorPosition or "left"
		local ox, oy = bd.anchorOffsetX or 0, bd.anchorOffsetY or 0
		if side == "right" then f:SetPoint("LEFT", target, "RIGHT", ox, oy)
		elseif side == "top" then f:SetPoint("BOTTOM", target, "TOP", ox, oy)
		elseif side == "bottom" then f:SetPoint("TOP", target, "BOTTOM", ox, oy)
		else f:SetPoint("RIGHT", target, "LEFT", ox, oy) end
		return
	end
	if bd.anchorTo == "mouse" then
		-- Follows the cursor (OnUpdate in the driver).
		f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", 0, 0)
		return
	end
	local pos = CDM.DB().cdmBarPositions[bd.key] or DEFAULT_POS[bd.key]
		or { point = "CENTER", relPoint = "CENTER", x = 0, y = -300 }
	local pt = pos.point or "CENTER"
	local px, py = pos.x or 0, pos.y or 0
	-- Re-project onto the anchor of the bar's current growth (lossless).
	local want = CDM.ResolveGrowAnchorPoint(bd)
	if pt ~= want then
		local cx, cy = CDM.AnchorCoordToCenter(pt, px, py, w, h)
		px, py = CDM.CenterToAnchorCoord(want, cx, cy, w, h)
		pt = want
	end
	f:SetPoint(pt, UIParent, pos.relPoint or "CENTER", px, py)
end
CDM.ApplyPosition = ApplyPosition

-------------------------------------------------------------------------------
--  Bar frames
-------------------------------------------------------------------------------
local function GetBarFrame(bd)
	local f = barFrames[bd.key]
	if not f then
		f = CreateFrame("Frame", nil, UIParent)
		f:SetSize(1, 1)
		f:SetClampedToScreen(true)
		f.icons = {}
		f.bgTex = f:CreateTexture(nil, "BACKGROUND")
		f.bgTex:SetAllPoints()
		f.bgTex:SetTexture(1, 1, 1, 1)
		barFrames[bd.key] = f
	end
	f.key = bd.key
	return f
end

-- Entries of a bar for the current spec.
local function BarEntries(bd)
	local sd = CDM.BarSpellData(bd.key)
	local out = {}
	local seen = {}
	for _, id in ipairs(sd.assignedSpells) do
		local e = CDM.ResolveEntry(bd, id, sd)
		if e then
			local k = (e.kind or "") .. ":" .. tostring(e.spellID or e.itemID or e.slot)
			if not seen[k] then
				seen[k] = true
				out[#out + 1] = e
			end
		end
	end
	return out
end
CDM.BarEntries = BarEntries

-- Builds (or rebuilds) every bar from the saved data.
function CDM.BuildAll()
	if not CDM.ready then return end
	local p = CDM.DB()
	local enabled = p.cdmBars.enabled ~= false
	local live = {}
	-- Pass 1: each bar's entries (with their settings from the bar they belong to).
	local lists = {}
	for _, bd in ipairs(CDM.Bars()) do
		if CDM.IsPortedBar(bd) and bd.key then
			local list = (enabled and bd.enabled ~= false) and BarEntries(bd) or {}
			for _, e in ipairs(list) do e._ss = CDM.SpellSettings(bd, e.id) end
			lists[bd.key] = list
		end
	end
	-- Pass 2: Max Icons + Overflow To (retail maxIcons / overflowTarget): the
	-- entries past the cap move to the end of the target bar (or are dropped).
	for _, bd in ipairs(CDM.Bars()) do
		local list = lists[bd.key]
		local cap = tonumber(bd.maxIcons) or 0
		if list and cap > 0 and #list > cap then
			local target = bd.overflowTarget and bd.overflowTarget ~= bd.key and lists[bd.overflowTarget]
			for i = cap + 1, #list do
				if target then target[#target + 1] = list[i] end
				list[i] = nil
			end
		end
	end
	for _, bd in ipairs(CDM.Bars()) do
		if CDM.IsPortedBar(bd) and bd.key then
			live[bd.key] = true
			local f = GetBarFrame(bd)
			f.bd = bd
			f:SetFrameStrata(BV(bd, "barStrata"))
			local entries = lists[bd.key] or {}
			f.entries = entries
			local iw, ih = CDM.IconDims(bd)
			for i, e in ipairs(entries) do
				local icon = f.icons[i]
				if not icon then
					icon = CDM.CreateIcon(f)
					f.icons[i] = icon
				end
				CDM.StyleIcon(icon, bd, iw, ih)
				CDM.SetIconEntry(icon, e, e._ss)
			end
			for i = #entries + 1, #f.icons do
				local icon = f.icons[i]
				icon._entry = nil
				CDM.StopIconGlow(icon)
				icon:Hide()
			end
			if bd.barBgEnabled then
				f.bgTex:SetVertexColor(bd.barBgR or 0, bd.barBgG or 0, bd.barBgB or 0, bd.barBgA or 0.5)
				f.bgTex:Show()
			else
				f.bgTex:Hide()
			end
		end
	end
	-- Bars deleted from the profile.
	for key, f in pairs(barFrames) do
		if not live[key] then
			f.entries = {}
			for _, icon in ipairs(f.icons) do icon._entry = nil; CDM.StopIconGlow(icon); icon:Hide() end
			f:Hide()
		end
	end
	CDM.RegisterUnlock()
	CDM.UpdateAll(true)
end

-------------------------------------------------------------------------------
--  Layout (retail LayoutCDMBar + ComputeTopRowStride)
-------------------------------------------------------------------------------
local function TopRowStride(bd, count)
	local numRows = bd.numRows or 1
	if numRows < 1 then numRows = 1 end
	if numRows == 2 then
		local topCount
		if bd.customTopRowEnabled and bd.topRowCount and bd.topRowCount > 0 then
			topCount = min(bd.topRowCount, count)
		elseif bd.customBottomRowEnabled and bd.bottomRowCount and bd.bottomRowCount > 0 then
			topCount = count - min(bd.bottomRowCount, count)
		end
		if topCount then
			if topCount < 0 then topCount = 0 end
			local bottomCount = count - topCount
			if bottomCount <= 0 or topCount <= 0 then return count, 1, count end
			return max(topCount, bottomCount), numRows, topCount
		end
	end
	local stride = ceil(count / numRows)
	if stride < 1 then stride = 1 end
	local rows = ceil(count / stride)
	local topCount = count - (rows - 1) * stride
	if topCount < 0 then topCount = 0 end
	return stride, rows, topCount
end
CDM.TopRowStride = TopRowStride

local function LayoutBar(f)
	local bd = f.bd
	local list = {}
	for _, icon in ipairs(f.icons) do
		if icon._entry and icon._wantShow then list[#list + 1] = icon end
	end
	local count = #list
	local iw, ih = CDM.IconDims(bd)
	local sp = bd.spacing or 2
	local grow = bd.growDirection or "CENTER"
	local horiz = grow == "RIGHT" or grow == "LEFT" or (grow == "CENTER" and not bd.verticalOrientation)
	local reverse = grow == "LEFT" or grow == "UP"
	if count == 0 then
		f:SetSize(horiz and iw or iw, horiz and ih or ih)
		f._empty = true
		ApplyPosition(bd, f)
		return
	end
	f._empty = false
	local stride, rows, topCount = TopRowStride(bd, count)
	-- Rows: on horizontal bars rows stack vertically, the first (base) row on top.
	local rowsReversed
	if horiz then rowsReversed = bd.rowGrowDirection == "UP" else rowsReversed = bd.rowGrowDirection == "LEFT" end
	-- Bottom row size offset (retail custom row sizes, 2 rows only).
	local function RowIconSize(row)
		local s = BV(bd, "iconSize")
		if rows == 2 then
			if row == 0 and bd.customTopRowSizeEnabled then s = s + (bd.topRowSizeOffset or 0) end
			if row == 1 and bd.customBottomRowSizeEnabled then s = s + (bd.bottomRowSizeOffset or 0) end
		end
		return CDM.IconDims(bd, s)
	end
	local W, H
	if horiz then
		W = stride * iw + (stride - 1) * sp
		H = 0
		for r = 0, rows - 1 do
			local _, rh = RowIconSize(r)
			H = H + rh + (r > 0 and sp or 0)
		end
	else
		H = stride * ih + (stride - 1) * sp
		W = 0
		for r = 0, rows - 1 do
			local rw = RowIconSize(r)
			W = W + rw + (r > 0 and sp or 0)
		end
	end
	f:SetSize(max(1, W), max(1, H))
	-- Place each icon.
	local idx = 0
	local rowOffset = 0
	for r = 0, rows - 1 do
		local n = (r == 0) and topCount or min(stride, count - topCount - (r - 1) * stride)
		local rw, rh = RowIconSize(r)
		local lineLen = n * (horiz and rw or rh) + (n - 1) * sp
		local full = horiz and W or H
		local start = floor((full - lineLen) / 2 + 0.5)
		for c = 0, n - 1 do
			idx = idx + 1
			local icon = list[idx]
			if not icon then break end
			local pos = c
			if reverse then pos = n - 1 - c end
			icon:ClearAllPoints()
			if icon:GetWidth() ~= rw or icon:GetHeight() ~= rh then CDM.StyleIcon(icon, bd, rw, rh) end
			if horiz then
				local x = start + pos * (rw + sp)
				local y = rowsReversed and (H - rowOffset - rh) or rowOffset
				icon:SetPoint("TOPLEFT", f, "TOPLEFT", x, -y)
			else
				local y = start + pos * (rh + sp)
				local x = rowsReversed and (W - rowOffset - rw) or rowOffset
				icon:SetPoint("TOPLEFT", f, "TOPLEFT", x, -y)
			end
			icon:Show()
		end
		rowOffset = rowOffset + (horiz and rh or rw) + sp
	end
	ApplyPosition(bd, f)
end
CDM.LayoutBar = LayoutBar

-------------------------------------------------------------------------------
--  Visibility (retail barVisibility + visibility options; dragonriding and
--  housing do not exist in 5.4.8)
-------------------------------------------------------------------------------
local function BarVisible(bd)
	if bd.enabled == false or CDM.DB().cdmBars.enabled == false then return false end
	if ns._unlockActive or preview then return true end
	local mode = bd.barVisibility or "always"
	if mode == "never" or mode == "show_dragonriding" then return false end
	if mode == "in_combat" and not inCombat then return false end
	if mode == "out_of_combat" and inCombat then return false end
	if mode == "in_raid" and not IsInRaid() then return false end
	if mode == "in_party" and (not IsInGroup() or IsInRaid()) then return false end
	if mode == "solo" and IsInGroup() then return false end
	if bd.visOnlyInstances then
		local inInst = IsInInstance()
		if not inInst then return false end
	end
	if bd.visHideMounted and IsMounted() then return false end
	if bd.visHideNoTarget and not UnitExists("target") then return false end
	if bd.visHideNoEnemy and not (UnitExists("target") and UnitCanAttack("player", "target")) then return false end
	return true
end
CDM.BarVisible = BarVisible

local function BarAlpha(bd, f)
	if bd.barVisibility == "mouseover" and not ns._unlockActive and not preview then
		return f:IsMouseOver() and (bd.barOpacity or 1) or 0
	end
	if bd.oocFadeEnabled and not inCombat then return BV(bd, "oocFadeAlpha") end
	return bd.barOpacity or 1
end

-------------------------------------------------------------------------------
--  Update driver
-------------------------------------------------------------------------------
function CDM.UpdateAll(relayout)
	if not CDM.ready then return end
	if CDM.auraDirty then CDM.RefreshAuras() end
	if CDM._keysDirty and not inCombat then CDM.RebuildKeybinds() end
	local now = GetTime()
	local glowsAllowed = not (CDM.DB().cdmBars.glowsOnlyInCombat and not inCombat)
	for _, f in pairs(barFrames) do
		local bd = f.bd
		if bd and f.entries then
			local visible = BarVisible(bd) and (#f.entries > 0 or ns._unlockActive)
			if not visible then
				if f:IsShown() then
					f:Hide()
					for _, icon in ipairs(f.icons) do CDM.StopIconGlow(icon) end
				end
			else
				local changed = relayout or not f:IsShown()
				for i = 1, #f.entries do
					local icon = f.icons[i]
					local want = CDM.UpdateIcon(icon, now, inCombat, glowsAllowed)
					if preview and not want then
						-- Options open: show every tracked entry.
						want = true
						icon._alpha = 0.5
					end
					if want ~= icon._wantShow then
						icon._wantShow = want
						changed = true
					end
					if not want then icon:Hide() end
					icon:SetAlpha(icon._alpha or 1)
				end
				if changed then LayoutBar(f) end
				f:SetAlpha(BarAlpha(bd, f))
				f:Show()
			end
		end
	end
end

-- Bars anchored to the cursor.
local function FollowCursor()
	local scale = UIParent:GetEffectiveScale()
	local x, y = GetCursorPosition()
	for _, f in pairs(barFrames) do
		local bd = f.bd
		if bd and bd.anchorTo == "mouse" and f:IsShown() then
			f:ClearAllPoints()
			f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale + (bd.anchorOffsetX or 0), y / scale + (bd.anchorOffsetY or 0))
		end
	end
end

local driver = CreateFrame("Frame")
local elapsedAcc = 0
driver:SetScript("OnUpdate", function(_, elapsed)
	elapsedAcc = elapsedAcc + elapsed
	if CDM._anyMouse then FollowCursor() end
	if elapsedAcc < 0.1 then return end
	elapsedAcc = 0
	CDM.UpdateAll(false)
end)
driver:Hide()

-- Options preview (the settings window shows every tracked entry).
function CDM.SetPreview(on)
	preview = on and true or false
	CDM.UpdateAll(true)
end

-------------------------------------------------------------------------------
--  Mirror Key Presses (retail pressMirror): pressing an ability's key shows
--  the pushed look on its icon (bars with the option on). A keyboard frame
--  that passes every key on; built out of combat once a bar asks for it.
-------------------------------------------------------------------------------
local pressFrame
local pressed = {}
local function PushOverlay(icon, on)
	if on and not icon.push then
		icon.push = icon.textHost:CreateTexture(nil, "BACKGROUND")
		icon.push:SetAllPoints(icon.tex)
		icon.push:SetTexture(0, 0, 0, 0.45)
	end
	if icon.push then icon.push:SetShown(on and true or false) end
end

local function KeyText(key)
	local mods = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "")
	return CDM.FormatKey(mods .. key), CDM.FormatKey(key)
end

local function OnPress(_, key)
	local full, bare = KeyText(key)
	for _, f in pairs(barFrames) do
		local bd = f.bd
		if bd and bd.pressMirror and f:IsShown() then
			for _, icon in ipairs(f.icons) do
				local kt = icon._entry and CDM.KeyFor(icon._entry)
				if kt and kt ~= "" and (kt == full or kt == bare) then
					PushOverlay(icon, true)
					pressed[icon] = key
				end
			end
		end
	end
end

local function OnRelease(_, key)
	for icon, k in pairs(pressed) do
		if k == key then
			PushOverlay(icon, false)
			pressed[icon] = nil
		end
	end
end

function CDM.UpdatePressMirror()
	local want = false
	for _, bd in ipairs(CDM.Bars()) do
		if bd.pressMirror then want = true break end
	end
	if want and not pressFrame then
		if InCombatLockdown() then
			CDM.OutOfCombat("pressMirror", CDM.UpdatePressMirror)
			return
		end
		pressFrame = CreateFrame("Frame", nil, UIParent)
		pressFrame:EnableKeyboard(true)
		pressFrame:SetPropagateKeyboardInput(true)
		pressFrame:SetScript("OnKeyDown", OnPress)
		pressFrame:SetScript("OnKeyUp", OnRelease)
	end
	if pressFrame then
		pressFrame:SetShown(want)
		if not want then
			for icon in pairs(pressed) do PushOverlay(icon, false) end
			wipe(pressed)
		end
	end
end

-------------------------------------------------------------------------------
--  Unlock Mode ("CDM_" .. key movers, group "Cooldown Manager")
-------------------------------------------------------------------------------
function CDM.RegisterUnlock()
	if not (ns.RegisterUnlockElements and ns.MakeUnlockElement) then return end
	local MK = ns.MakeUnlockElement
	local elements = {}
	local anyMouse = false
	for _, bd in ipairs(CDM.Bars()) do
		if bd.anchorTo == "mouse" then anyMouse = true end
		local key = bd.key
		if CDM.IsPortedBar(bd) and key and bd.enabled ~= false and bd.anchorTo ~= "mouse"
			and not (bd.anchorTo and bd.anchorTo ~= "none" and CDM.BarByKey(bd.anchorTo)) then
			local isBuff = CDM.IsBuffBar(bd)
			elements[#elements + 1] = MK({
				key = "CDM_" .. key,
				label = "CDM: " .. (bd.name or key),
				group = "Cooldown Manager",
				order = 600,
				noAnchorTarget = isBuff,
				noResize = true,
				isHidden = function() return not CDM.BarByKey(key) end,
				getFrame = function() return barFrames[key] end,
				getSize = function()
					local f = barFrames[key]
					if not f then return 36, 36 end
					return f:GetWidth(), f:GetHeight()
				end,
				savePos = function(_, point, relPoint, x, y)
					local bd2 = CDM.BarByKey(key)
					local f = barFrames[key]
					local storePoint, sx, sy = point, x, y
					if bd2 and f and point == "CENTER" then
						local want = CDM.ResolveGrowAnchorPoint(bd2)
						if want ~= "CENTER" then
							storePoint = want
							sx, sy = CDM.CenterToAnchorCoord(want, x, y, f:GetWidth() or 0, f:GetHeight() or 0)
						end
					end
					CDM.DB().cdmBarPositions[key] = { point = storePoint, relPoint = relPoint, x = sx, y = sy }
					if not ns._unlockActive then CDM.BuildAll() end
				end,
				loadPos = function()
					local pos = CDM.DB().cdmBarPositions[key]
					if not pos or not pos.point then return pos end
					if pos.point ~= "CENTER" then
						local f = barFrames[key]
						if f then
							local cx, cy = CDM.AnchorCoordToCenter(pos.point, pos.x or 0, pos.y or 0, f:GetWidth() or 0, f:GetHeight() or 0)
							return { point = "CENTER", relPoint = pos.relPoint, x = cx, y = cy }
						end
					end
					return pos
				end,
				clearPos = function() CDM.DB().cdmBarPositions[key] = nil end,
				applyPos = function()
					local bd2 = CDM.BarByKey(key)
					local f = barFrames[key]
					if bd2 and f then ApplyPosition(bd2, f) end
				end,
			})
		end
	end
	CDM._anyMouse = anyMouse
	if #elements > 0 then
		ns:RegisterUnlockElements(elements, addonName)
	end
end

-------------------------------------------------------------------------------
--  Apply (settings window: ns.applyHooks)
-------------------------------------------------------------------------------
function CDM.Apply()
	if not CDM.ready then return end
	CDM.BuildAll()
	CDM.UpdatePressMirror()
	if CDM.TBB and CDM.TBB.Build then CDM.TBB.Build() end
	if CDM.BarGlows and CDM.BarGlows.Refresh then CDM.BarGlows.Refresh() end
end

ns.applyHooks = ns.applyHooks or {}
tinsert(ns.applyHooks, function()
	if CDM.ready then CDM.Apply() end
end)

-------------------------------------------------------------------------------
--  Events / boot
-------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
CDM.eventFrame = ev
local function SpecChanged()
	CDM._myRacial = nil
	CDM.SeedSpecDefaults()
	CDM._keysDirty = true
	CDM.Apply()
end

local pendingBuild
local function QueueBuild()
	if pendingBuild then return end
	pendingBuild = CDM.After(0.2, function()
		pendingBuild = nil
		CDM.BuildAll()
	end)
end

ev:SetScript("OnEvent", function(self, event, arg1, _, _, _, arg5)
	if event == "ADDON_LOADED" then
		if arg1 == addonName then
			self:UnregisterEvent("ADDON_LOADED")
			CDM.InitDB()
		end
		return
	elseif event == "PLAYER_LOGIN" then
		CDM.ready = true
		CDM.SeedSpecDefaults()
		CDM._keysDirty = true
		CDM.RebuildKeybinds()
		CDM.Apply()
		driver:Show()
		if ns.RegisterUnlockModeListener then
			ns:RegisterUnlockModeListener(addonName, function() CDM.UpdateAll(true) end)
		end
		return
	end
	if not CDM.ready then return end
	if event == "UNIT_AURA" then
		if arg1 == "player" or arg1 == "target" then CDM.auraDirty = true end
	elseif event == "PLAYER_TARGET_CHANGED" then
		CDM.auraDirty = true
	elseif event == "PLAYER_REGEN_DISABLED" then
		inCombat = true
		CDM.UpdateAll(false)
	elseif event == "PLAYER_REGEN_ENABLED" then
		inCombat = false
		if CDM._keysDirty then CDM.RebuildKeybinds() end
		CDM.UpdateAll(false)
	elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
		if event == "ACTIVE_TALENT_GROUP_CHANGED" or arg1 == "player" or arg1 == nil then SpecChanged() end
	elseif event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
		if event == "SPELLS_CHANGED" then CDM.SeedSpecDefaults() end
		QueueBuild()
	elseif event == "BAG_UPDATE" then
		-- Items with "Hide Items if Missing" come and go.
		QueueBuild()
	elseif event == "UPDATE_BINDINGS" or event == "ACTIONBAR_SLOT_CHANGED" or event == "ACTIONBAR_PAGE_CHANGED"
		or event == "UPDATE_BONUS_ACTIONBAR" or event == "UPDATE_SHAPESHIFT_FORM" then
		CDM._keysDirty = true
		if not inCombat then CDM.RebuildKeybinds() end
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		-- Cast-timed custom auras (retail spellDurations: potions, trinket procs).
		if arg1 == "player" and arg5 then CDM.timedStart[arg5] = GetTime() end
	elseif event == "PLAYER_ENTERING_WORLD" then
		inCombat = InCombatLockdown() and true or false
		CDM.auraDirty = true
		QueueBuild()
	end
end)

for _, e in ipairs({
	"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "UNIT_AURA", "PLAYER_TARGET_CHANGED",
	"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_SPECIALIZATION_CHANGED",
	"ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_TALENT_UPDATE", "SPELLS_CHANGED", "PLAYER_EQUIPMENT_CHANGED",
	"BAG_UPDATE", "UPDATE_BINDINGS", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED",
	"UPDATE_BONUS_ACTIONBAR", "UPDATE_SHAPESHIFT_FORM", "UNIT_SPELLCAST_SUCCEEDED",
}) do
	ev:RegisterEvent(e)
end
