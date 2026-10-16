-- Spell History (EllesmereUI "Spell History", made for the 5.4.8 client).
-- Two displays share one history of the player's casts:
--   Icon History: a strip of recent spell icons.
--   Bar History:  a window with one bar per cast (icon, name, cast time, target).
-- Cast detection follows TrufiGCD (works on 5.4.8): casts are added at START,
-- instants at SUCCEEDED, channels at CHANNEL_START or their first SUCCEEDED.

local addonName = ...
local ns = EllesmereUI

local GetTime = GetTime
local GetSpellInfo = GetSpellInfo
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local floor, min, max = math.floor, math.min, math.max
local tinsert, tremove = table.insert, table.remove
local format = format

local MAX_HISTORY = 80
local MAX_ICONS = 10
local MAX_BARS = 10
local ANIM_DUR = 0.5
local ANIM_SLIDE_PX = 6
local FADE_DUR = 1.5
local STOP_GRACE = 0.3 -- a STOP without SUCCEEDED becomes "failed" after this time
local HEADER_H = 22
local ROW_GAP = 1
local FAIL_COLOR = { 0.86, 0.255, 0.255 }
local ACCENT = { 12 / 255, 210 / 255, 157 / 255 }
local FONT = ns.FONT
local BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"

-- Never shown: auto attacks and helper / off-hand / duplicate hits (list from TrufiGCD).
local IGNORED = {
	[6603] = true, [75] = true,
	[61391] = true, [5374] = true, [27576] = true, [88263] = true, [98057] = true,
	[32175] = true, [32176] = true, [96103] = true, [85384] = true, [57794] = true,
	[52174] = true, [135299] = true, [121473] = true, [121474] = true, [114093] = true,
	[114089] = true, [115357] = true, [115360] = true, [127797] = true, [102794] = true,
	[50622] = true, [122128] = true, [110745] = true, [120696] = true, [120692] = true,
	[115464] = true, [126526] = true, [132951] = true, [107270] = true, [137584] = true,
	[137585] = true, [117993] = true, [124040] = true,
}

local GROW_DIRS = {
	{ key = "LEFT", text = "Left" },
	{ key = "RIGHT", text = "Right" },
	{ key = "UP", text = "Up" },
	{ key = "DOWN", text = "Down" },
}
local GROW_VECTOR = { LEFT = { -1, 0 }, RIGHT = { 1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }

local ANIMATIONS = {
	{ key = "none", text = "None" },
	{ key = "slide", text = "Slide In" },
	{ key = "fly", text = "Fly In" },
}

local COLOR_MODES_TEXT = {
	{ key = "custom", text = "Custom Color" },
	{ key = "accent", text = "Accent Color" },
}
local COLOR_MODES_BAR = {
	{ key = "class", text = "Class Color" },
	{ key = "custom", text = "Custom Color" },
	{ key = "accent", text = "Accent Color" },
}

-- Visibility options (EllesmereUI "Visibility Options"). Delves do not exist on 5.4.8.
local VISIBILITY = {
	{ key = "HideInDungeon", text = "Hide in Dungeons" },
	{ key = "HideInRaid", text = "Hide in Raids" },
	{ key = "HideInPvP", text = "Hide in PvP" },
	{ key = "HideOutOfInstance", text = "Hide out of Instances" },
}

local function CreateDefaults()
	return {
		-- Icon History
		iconEnabled = false,
		iconGrow = "LEFT",
		iconHideInDungeon = false,
		iconHideInRaid = false,
		iconHideInPvP = false,
		iconHideOutOfInstance = false,
		iconSize = 36,
		iconZoom = 8, -- % cut from each side of the icon (shared with the bars)
		iconMax = 5,
		iconSpacing = 1,
		iconOpacity = 100,
		iconAnimation = "slide",
		iconFadeTime = 0,
		iconPos = { 0, -180 },
		-- Bar History
		barEnabled = false,
		barHideInDungeon = false,
		barHideInRaid = false,
		barHideInPvP = false,
		barHideOutOfInstance = false,
		bgColor = { 0, 0, 0 },
		bgAlpha = 25,
		barHideTopBar = false,
		barHeight = 20,
		barMax = 5,
		barTexture = BAR_TEXTURE,
		textSize = 11,
		textColorMode = "custom",
		textColor = { 1, 1, 1 },
		barColorMode = "custom",
		barColor = { 0.298, 0.565, 0.494 },
		barOpacity = 100,
		barWidth = 300,
		barPos = { 250, -100 },
	}
end

local function CopyDefaults(src, dst)
	for key, value in pairs(src) do
		if type(value) == "table" then
			if type(dst[key]) ~= "table" then
				dst[key] = {}
			end
			CopyDefaults(value, dst[key])
		elseif dst[key] == nil then
			dst[key] = value
		end
	end
end

local db = CreateDefaults()
local loaded = false

local history = {}
local currentCast, currentChannel
local lastSucceededLine
local sent -- last UNIT_SPELLCAST_SENT: spell name, target, time
local fadeClock = 0 -- runs only out of combat, so icons do not fade in combat
local previewOn = false
local iconsUnlocked, barsUnlocked = false, false
local animEntry, animStart
local scrollOffset = 0
local previewSpells

local driver = CreateFrame("Frame")

---------------------------------------------------------------------------
-- History
---------------------------------------------------------------------------
local Refresh -- defined below

local function NewEntry(spellID, status)
	if not spellID or IGNORED[spellID] then
		return nil
	end
	local name, _, icon = GetSpellInfo(spellID)
	if not name or not icon then
		return nil
	end
	local now = GetTime()
	local entry = {
		spellID = spellID,
		name = name,
		icon = icon,
		status = status,
		timestamp = now,
		fadeBase = fadeClock,
	}
	if sent and sent.name == name and now - sent.time < 3 then
		entry.target = sent.target
	end
	return entry
end

local function Push(entry)
	tinsert(history, 1, entry)
	if #history > MAX_HISTORY then
		history[#history] = nil
	end
	animEntry, animStart = entry, GetTime()
	scrollOffset = 0
	Refresh()
end

local function Finish(entry, status)
	entry.status = status
	entry.finished = GetTime()
	entry.stopAt = nil
	Refresh()
end

local function SetCastTimes(entry, startMS, endMS)
	local now = GetTime()
	entry.startTime = startMS and startMS / 1000 or now
	entry.endTime = endMS and endMS / 1000 or entry.startTime
end

-- 5.4.8 payload: unit, spellName, rank, lineID, spellID (SENT: unit, spellName, rank, target, lineID).
local function OnSpellEvent(event, unit, spellName, rank, arg4, arg5)
	if event == "UNIT_SPELLCAST_SENT" then
		sent = { name = spellName, target = (arg4 and arg4 ~= "") and arg4 or nil, time = GetTime() }
		return
	end
	local lineID, spellID = arg4, arg5

	if event == "UNIT_SPELLCAST_START" then
		local entry = NewEntry(spellID, "casting")
		if not entry then
			return
		end
		local _, _, _, _, startMS, endMS = UnitCastingInfo("player")
		SetCastTimes(entry, startMS, endMS)
		entry.lineID = lineID
		currentCast = entry
		Push(entry)

	elseif event == "UNIT_SPELLCAST_DELAYED" then
		if currentCast then
			local _, _, _, _, startMS, endMS = UnitCastingInfo("player")
			if endMS then
				SetCastTimes(currentCast, startMS, endMS)
			end
		end

	elseif event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
		local entry = currentChannel
		if not entry or entry.spellID ~= spellID or GetTime() - entry.timestamp > 1 then
			if event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
				return
			end
			entry = NewEntry(spellID, "channeling")
			if not entry then
				return
			end
			entry.isChannel = true
			currentChannel = entry
			Push(entry)
		end
		local _, _, _, _, startMS, endMS = UnitChannelInfo("player")
		if endMS then
			SetCastTimes(entry, startMS, endMS)
		end

	elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		if currentChannel then
			Finish(currentChannel, "success")
			currentChannel = nil
		end

	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		if IGNORED[spellID] then
			return
		end
		-- Some spells send SUCCEEDED twice with the same line id.
		if lineID and lineID ~= 0 then
			if lineID == lastSucceededLine then
				return
			end
			lastSucceededLine = lineID
		end
		local cast = currentCast
		if cast and ((lineID ~= 0 and cast.lineID == lineID) or cast.spellID == spellID) then
			currentCast = nil
			Finish(cast, "success")
			return
		end
		-- SUCCEEDED after the cast was already marked failed (latency): undo it.
		local now = GetTime()
		for i = 1, min(5, #history) do
			local e = history[i]
			if e.spellID == spellID and (e.status == "failed" or e.status == "interrupted") and now - (e.finished or 0) < 1 then
				e.status = "success"
				Refresh()
				return
			end
		end
		-- Channel ticks, and channels that send SUCCEEDED before CHANNEL_START.
		if currentChannel and currentChannel.spellID == spellID then
			return
		end
		local channelName, _, _, _, startMS, endMS = UnitChannelInfo("player")
		if channelName and channelName == spellName then
			local entry = NewEntry(spellID, "channeling")
			if entry then
				entry.isChannel = true
				SetCastTimes(entry, startMS, endMS)
				currentChannel = entry
				Push(entry)
			end
			return
		end
		-- Instant cast. Hidden / internal spells have no link.
		if not GetSpellLink(spellID) then
			return
		end
		local entry = NewEntry(spellID, "success")
		if entry then
			entry.isInstant = true
			Push(entry)
		end

	elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_FAILED_QUIET" then
		local status = event == "UNIT_SPELLCAST_INTERRUPTED" and "interrupted" or "failed"
		local cast = currentCast
		-- Match by line id; a FAILED of a different (queued) spell must not touch the cast.
		if cast and ((lineID ~= 0 and cast.lineID == lineID) or ((lineID == 0 or cast.lineID == 0) and cast.spellID == spellID)) then
			currentCast = nil
			Finish(cast, status)
		elseif status == "interrupted" and currentChannel and currentChannel.spellID == spellID then
			Finish(currentChannel, "interrupted")
			currentChannel = nil
		end

	elseif event == "UNIT_SPELLCAST_STOP" then
		local cast = currentCast
		if cast and cast.status == "casting" and (cast.lineID == lineID or cast.spellID == spellID) then
			-- SUCCEEDED may still come; if not, OnUpdate marks it failed.
			cast.stopAt = GetTime()
		end
	end
end

---------------------------------------------------------------------------
-- Shared helpers
---------------------------------------------------------------------------
-- Font and outline from Global Settings > Fonts (module key "damageMeters").
local function SetFont(fs, size)
	if ns.ApplyModuleFont then
		ns.ApplyModuleFont(fs, size, "damageMeters")
		return
	end
	fs:SetFont(FONT, size, "OUTLINE")
	if not fs:GetFont() then
		fs:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
	end
end

local function HiddenByZone(prefix)
	local inInstance, instanceType = IsInInstance()
	if not inInstance or instanceType == "none" then
		return db[prefix .. "HideOutOfInstance"]
	elseif instanceType == "raid" then
		return db[prefix .. "HideInRaid"]
	elseif instanceType == "pvp" or instanceType == "arena" then
		return db[prefix .. "HideInPvP"]
	end
	return db[prefix .. "HideInDungeon"] -- party, scenario
end

local function Zoom(texture)
	local z = (db.iconZoom or 0) / 100
	texture:SetTexCoord(z, 1 - z, z, 1 - z)
end

-- Spells from the action bars, used to fill empty slots while previewing.
local function GetPreviewSpells()
	if previewSpells then
		return previewSpells
	end
	previewSpells = {}
	local seen = {}
	for slot = 1, 120 do
		local actionType, id = GetActionInfo(slot)
		if actionType == "spell" and id and not seen[id] then
			local name, _, icon, _, _, _, castTime = GetSpellInfo(id)
			if name and icon then
				seen[id] = true
				previewSpells[#previewSpells + 1] = { name = name, icon = icon, castTime = (castTime or 0) / 1000 }
				if #previewSpells >= MAX_BARS then
					break
				end
			end
		end
	end
	if #previewSpells == 0 then
		previewSpells[1] = { name = "Spell", icon = "Interface\\Icons\\INV_Misc_QuestionMark", castTime = 1.5 }
	end
	return previewSpells
end

-- Green box shown in Unlock Mode; dragging it moves dragFrame.
local function CreateMover(parent, label, dragFrame, onStop)
	local mover = CreateFrame("Frame", nil, parent)
	mover:SetAllPoints(parent)
	mover:SetFrameLevel(parent:GetFrameLevel() + 30)
	mover:EnableMouse(true)
	mover:RegisterForDrag("LeftButton")
	local bg = mover:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.15)
	local function Edge(p1, p2, horizontal)
		local tex = mover:CreateTexture(nil, "OVERLAY")
		tex:SetTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.9)
		tex:SetPoint(p1)
		tex:SetPoint(p2)
		if horizontal then
			tex:SetHeight(1)
		else
			tex:SetWidth(1)
		end
	end
	Edge("TOPLEFT", "TOPRIGHT", true)
	Edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
	Edge("TOPLEFT", "BOTTOMLEFT", false)
	Edge("TOPRIGHT", "BOTTOMRIGHT", false)
	local text = mover:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	text:SetPoint("BOTTOMLEFT", mover, "TOPLEFT", 0, 3)
	text:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
	text:SetText(label)
	mover:SetScript("OnDragStart", function() dragFrame:StartMoving() end)
	mover:SetScript("OnDragStop", function()
		dragFrame:StopMovingOrSizing()
		dragFrame:SetUserPlaced(false)
		onStop()
	end)
	mover:Hide()
	return mover
end

---------------------------------------------------------------------------
-- Icon History
---------------------------------------------------------------------------
-- head = the newest icon; its center is the saved position, so changing the
-- number of icons or the direction does not move the strip.
local head = CreateFrame("Frame", "EUI_SpellHistoryIcons", UIParent)
head:SetMovable(true)
head:SetClampedToScreen(true)
head:SetFrameStrata("MEDIUM")
head:Hide()

local iconBox = CreateFrame("Frame", nil, head) -- covers the whole strip (for the mover)
local icons = {}
for i = 1, MAX_ICONS do
	local f = CreateFrame("Frame", nil, head)
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetAllPoints()
	f.bg:SetTexture(0, 0, 0, 0.4)
	f.tex = f:CreateTexture(nil, "ARTWORK")
	f.tex:SetAllPoints()
	f:Hide()
	icons[i] = f
end

local function SaveIconPosition()
	local cx, cy = head:GetCenter()
	local px, py = UIParent:GetCenter()
	if cx and px then
		db.iconPos = { floor(cx - px + 0.5), floor(cy - py + 0.5) }
	end
	head:ClearAllPoints()
	head:SetPoint("CENTER", UIParent, "CENTER", db.iconPos[1], db.iconPos[2])
end

local iconMover = CreateMover(iconBox, "Spell History: Icons", head, SaveIconPosition)

local function LayoutIcons()
	local size, spacing, count = db.iconSize, db.iconSpacing, db.iconMax
	local vec = GROW_VECTOR[db.iconGrow] or GROW_VECTOR.LEFT
	head:SetSize(size, size)
	-- While Unlock Mode is open its movers own the spot; an unlock anchor after.
	if not (ns._unlockActive and head:GetNumPoints() > 0) then
		head:ClearAllPoints()
		head:SetPoint("CENTER", UIParent, "CENTER", db.iconPos[1], db.iconPos[2])
		if not ns._unlockActive and ns.IsUnlockAnchored and ns.IsUnlockAnchored("EDM_IconHistory") and ns.ReapplyOwnAnchor then
			ns.ReapplyOwnAnchor("EDM_IconHistory")
		end
	end
	head:SetAlpha(db.iconOpacity / 100)
	for i = 1, MAX_ICONS do
		local f = icons[i]
		f:SetSize(size, size)
		f.baseX = vec[1] * (i - 1) * (size + spacing)
		f.baseY = vec[2] * (i - 1) * (size + spacing)
		f:ClearAllPoints()
		f:SetPoint("CENTER", head, "CENTER", f.baseX, f.baseY)
		Zoom(f.tex)
	end
	local length = count * size + (count - 1) * spacing
	iconBox:ClearAllPoints()
	if db.iconGrow == "LEFT" then
		iconBox:SetPoint("TOPRIGHT", head, "TOPRIGHT")
		iconBox:SetSize(length, size)
	elseif db.iconGrow == "RIGHT" then
		iconBox:SetPoint("TOPLEFT", head, "TOPLEFT")
		iconBox:SetSize(length, size)
	elseif db.iconGrow == "UP" then
		iconBox:SetPoint("BOTTOMLEFT", head, "BOTTOMLEFT")
		iconBox:SetSize(size, length)
	else
		iconBox:SetPoint("TOPLEFT", head, "TOPLEFT")
		iconBox:SetSize(size, length)
	end
end

local function RefreshIcons(now)
	if not head:IsShown() then
		return
	end
	local fadeTime = db.iconFadeTime
	local slot = 0
	for i = 1, #history do
		if slot >= db.iconMax then
			break
		end
		local entry = history[i]
		local alpha = 1
		if fadeTime > 0 then
			local age = fadeClock - entry.fadeBase
			if age > fadeTime then
				alpha = 1 - (age - fadeTime) / FADE_DUR
			end
		end
		if alpha > 0 then
			slot = slot + 1
			local f = icons[slot]
			f.tex:SetTexture(entry.icon)
			if entry.status == "failed" or entry.status == "interrupted" then
				f.tex:SetVertexColor(FAIL_COLOR[1], FAIL_COLOR[2], FAIL_COLOR[3])
			else
				f.tex:SetVertexColor(1, 1, 1)
			end
			local dx, dy, scale = 0, 0, 1
			if slot == 1 and entry == animEntry and db.iconAnimation ~= "none" then
				local t = min((now - animStart) / ANIM_DUR, 1)
				local inv = 1 - t
				local ease = 1 - inv * inv * inv
				alpha = alpha * (0.5 + 0.5 * ease)
				if db.iconAnimation == "slide" then
					local vec = GROW_VECTOR[db.iconGrow] or GROW_VECTOR.LEFT
					dx = -vec[1] * ANIM_SLIDE_PX * (1 - ease)
					dy = -vec[2] * ANIM_SLIDE_PX * (1 - ease)
				else
					scale = 1.35 + (1 - 1.35) * ease
				end
				if t >= 1 then
					animEntry = nil
				end
			end
			f:SetScale(scale)
			f:ClearAllPoints()
			f:SetPoint("CENTER", head, "CENTER", (f.baseX + dx) / scale, (f.baseY + dy) / scale)
			f:SetAlpha(alpha)
			f:Show()
		end
	end
	-- Preview: fill empty slots with action bar spells.
	if previewOn or iconsUnlocked then
		local spells = GetPreviewSpells()
		for i = slot + 1, db.iconMax do
			local f = icons[i]
			local spell = spells[(i - 1) % #spells + 1]
			f.tex:SetTexture(spell.icon)
			f.tex:SetVertexColor(1, 1, 1)
			f:SetScale(1)
			f:ClearAllPoints()
			f:SetPoint("CENTER", head, "CENTER", f.baseX, f.baseY)
			f:SetAlpha(0.75)
			f:Show()
		end
		slot = db.iconMax
	end
	for i = slot + 1, MAX_ICONS do
		icons[i]:Hide()
	end
end

---------------------------------------------------------------------------
-- Bar History
---------------------------------------------------------------------------
local win = CreateFrame("Frame", "EUI_SpellHistoryBars", UIParent)
win:SetMovable(true)
win:SetClampedToScreen(true)
win:SetFrameStrata("MEDIUM")
win:EnableMouseWheel(true)
win:Hide()
win.bg = win:CreateTexture(nil, "BACKGROUND")
win.bg:SetAllPoints()
win.header = CreateFrame("Frame", nil, win)
win.header:SetPoint("TOPLEFT")
win.header:SetPoint("TOPRIGHT")
win.header:SetHeight(HEADER_H)
win.header.bg = win.header:CreateTexture(nil, "BACKGROUND")
win.header.bg:SetAllPoints()
win.header.bg:SetTexture(0, 0, 0, 0.35)
win.header.line = win.header:CreateTexture(nil, "BORDER")
win.header.line:SetPoint("BOTTOMLEFT")
win.header.line:SetPoint("BOTTOMRIGHT")
win.header.line:SetHeight(1)
win.header.line:SetTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.6)
win.title = win.header:CreateFontString(nil, "OVERLAY")
win.title:SetPoint("LEFT", 8, 0)

local rows = {}
for i = 1, MAX_BARS do
	local row = CreateFrame("Frame", nil, win)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetPoint("TOPLEFT")
	row.icon:SetPoint("BOTTOMLEFT")
	row.bar = CreateFrame("StatusBar", nil, row)
	row.bar:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 1, 0)
	row.bar:SetPoint("BOTTOMRIGHT")
	row.bar:SetMinMaxValues(0, 1)
	row.barBg = row.bar:CreateTexture(nil, "BACKGROUND")
	row.barBg:SetAllPoints()
	row.name = row.bar:CreateFontString(nil, "OVERLAY")
	row.name:SetPoint("LEFT", 4, 0)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)
	row.right = row.bar:CreateFontString(nil, "OVERLAY")
	row.right:SetPoint("RIGHT", -4, 0)
	row.right:SetJustifyH("RIGHT")
	row.right:SetWordWrap(false)
	row:Hide()
	rows[i] = row
end

local function SaveBarPosition()
	local left, top = win:GetLeft(), win:GetTop()
	local px, py = UIParent:GetCenter()
	if left and px then
		db.barPos = { floor(left - px + 0.5), floor(top - py + 0.5) }
	end
	win:ClearAllPoints()
	win:SetPoint("TOPLEFT", UIParent, "CENTER", db.barPos[1], db.barPos[2])
end

local barMover = CreateMover(win, "Spell History: Bars", win, SaveBarPosition)

local function TextColor()
	if db.textColorMode == "accent" then
		return ACCENT[1], ACCENT[2], ACCENT[3]
	end
	local c = db.textColor
	return c[1], c[2], c[3]
end

local function BarColor()
	if db.barColorMode == "class" then
		local c = RAID_CLASS_COLORS[select(2, UnitClass("player"))]
		if c then
			return c.r, c.g, c.b
		end
	elseif db.barColorMode == "accent" then
		return ACCENT[1], ACCENT[2], ACCENT[3]
	end
	local c = db.barColor
	return c[1], c[2], c[3]
end

local function LayoutBars()
	local height, count = db.barHeight, db.barMax
	local top = db.barHideTopBar and 0 or HEADER_H
	win:SetSize(max(150, db.barWidth), top + count * (height + ROW_GAP) - ROW_GAP)
	if not (ns._unlockActive and win:GetNumPoints() > 0) then
		win:ClearAllPoints()
		win:SetPoint("TOPLEFT", UIParent, "CENTER", db.barPos[1], db.barPos[2])
		if not ns._unlockActive and ns.IsUnlockAnchored and ns.IsUnlockAnchored("EDM_BarHistory") and ns.ReapplyOwnAnchor then
			ns.ReapplyOwnAnchor("EDM_BarHistory")
		end
	end
	win:SetAlpha(db.barOpacity / 100)
	local c = db.bgColor
	win.bg:SetTexture(c[1], c[2], c[3], db.bgAlpha / 100)
	win.header:SetShown(not db.barHideTopBar)
	SetFont(win.title, db.textSize)
	win.title:SetText("Spell History")
	win.title:SetTextColor(TextColor())
	local texture = (type(db.barTexture) == "string" and db.barTexture ~= "") and db.barTexture or BAR_TEXTURE
	for i = 1, MAX_BARS do
		local row = rows[i]
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", win, "TOPLEFT", 0, -top - (i - 1) * (height + ROW_GAP))
		row:SetPoint("TOPRIGHT", win, "TOPRIGHT", 0, -top - (i - 1) * (height + ROW_GAP))
		row:SetHeight(height)
		row.icon:SetWidth(height)
		Zoom(row.icon)
		row.bar:SetStatusBarTexture(texture)
		if not row.bar:GetStatusBarTexture() or not row.bar:GetStatusBarTexture():GetTexture() then
			row.bar:SetStatusBarTexture(BAR_TEXTURE)
		end
		row.barBg:SetTexture(row.bar:GetStatusBarTexture():GetTexture())
		SetFont(row.name, db.textSize)
		SetFont(row.right, db.textSize)
		if i > count then
			row:Hide()
		end
	end
end

local function FormatEntry(entry, now)
	local duration = (entry.endTime or 0) - (entry.startTime or 0)
	if entry.status == "casting" or entry.status == "channeling" then
		local elapsed = max(0, now - entry.startTime)
		local progress = duration > 0 and elapsed / duration or 1
		if entry.status == "channeling" then
			progress = 1 - progress
		end
		return min(1, max(0, progress)), format("%.1f", elapsed), false
	elseif entry.status == "failed" or entry.status == "interrupted" then
		local progress = 1
		if duration > 0 and entry.finished then
			progress = (entry.finished - entry.startTime) / duration
			if entry.isChannel then
				progress = 1 - progress
			end
		end
		return min(1, max(0, progress)), entry.status == "interrupted" and "Interrupted" or "Failed", true
	end
	local text = ""
	if not entry.isInstant and entry.startTime then
		local total = (entry.isChannel and entry.finished or entry.endTime) - entry.startTime
		text = format("%.1fs", max(0, total))
	end
	if entry.target then
		text = (text ~= "" and (entry.target .. "  " .. text)) or entry.target
	end
	return 1, text, false
end

local function RefreshBars(now)
	if not win:IsShown() then
		return
	end
	local r, g, b = BarColor()
	local tr, tg, tb = TextColor()
	local spells = (previewOn or barsUnlocked) and GetPreviewSpells()
	for i = 1, db.barMax do
		local row = rows[i]
		local entry = history[scrollOffset + i]
		if entry then
			local progress, text, failed = FormatEntry(entry, now)
			row.icon:SetTexture(entry.icon)
			row.name:SetText(entry.name)
			row.right:SetText(text)
			row.bar:SetValue(progress)
			if failed then
				row.bar:SetStatusBarColor(FAIL_COLOR[1], FAIL_COLOR[2], FAIL_COLOR[3], 0.9)
				row.barBg:SetVertexColor(FAIL_COLOR[1], FAIL_COLOR[2], FAIL_COLOR[3], 0.2)
				row.right:SetTextColor(FAIL_COLOR[1], FAIL_COLOR[2], FAIL_COLOR[3])
			else
				row.bar:SetStatusBarColor(r, g, b, 0.9)
				row.barBg:SetVertexColor(r, g, b, 0.2)
				row.right:SetTextColor(tr, tg, tb)
			end
			row.name:SetTextColor(tr, tg, tb)
			row:SetAlpha(1)
			row:Show()
		elseif spells then
			local spell = spells[(i - 1) % #spells + 1]
			row.icon:SetTexture(spell.icon)
			row.name:SetText(spell.name)
			row.right:SetText(spell.castTime > 0 and format("%.1fs", spell.castTime) or "")
			row.bar:SetValue(1)
			row.bar:SetStatusBarColor(r, g, b, 0.9)
			row.barBg:SetVertexColor(r, g, b, 0.2)
			row.name:SetTextColor(tr, tg, tb)
			row.right:SetTextColor(tr, tg, tb)
			row:SetAlpha(0.75)
			row:Show()
		else
			row:Hide()
		end
		-- Name stops before the right text.
		row.name:SetPoint("RIGHT", row.right, "LEFT", -6, 0)
	end
end

win:SetScript("OnMouseWheel", function(_, delta)
	local maxOffset = max(0, #history - db.barMax)
	scrollOffset = min(maxOffset, max(0, scrollOffset - delta))
	RefreshBars(GetTime())
end)

---------------------------------------------------------------------------
-- Visibility, events, updates
---------------------------------------------------------------------------
local SPELL_EVENTS = {
	"UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED",
	"UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_FAILED_QUIET", "UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START",
	"UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP",
}
local eventsOn = false

-- Hidden by the meter's Show/Hide Windows keybind ("Include Spell History").
local keybindHidden = false

local function UpdateVisibility()
	local showIcons = db.iconEnabled and (previewOn or iconsUnlocked or not (keybindHidden or HiddenByZone("icon")))
	local showBars = db.barEnabled and (previewOn or barsUnlocked or not (keybindHidden or HiddenByZone("bar")))
	head:SetShown(showIcons and true or false)
	win:SetShown(showBars and true or false)
	-- The EllesmereUI core Unlock Mode draws the movers now.
	iconMover:Hide()
	barMover:Hide()
	if head:IsShown() or win:IsShown() then
		driver:Show()
	else
		driver:Hide()
	end
end

Refresh = function()
	local now = GetTime()
	RefreshIcons(now)
	RefreshBars(now)
end

local function Apply()
	if not loaded then
		return
	end
	local wanted = db.iconEnabled or db.barEnabled
	if wanted ~= eventsOn then
		eventsOn = wanted
		for i = 1, #SPELL_EVENTS do
			if wanted then
				driver:RegisterUnitEvent(SPELL_EVENTS[i], "player")
			else
				driver:UnregisterEvent(SPELL_EVENTS[i])
			end
		end
		if not wanted then
			wipe(history)
			currentCast, currentChannel = nil, nil
		end
	end
	scrollOffset = 0
	LayoutIcons()
	LayoutBars()
	UpdateVisibility()
	Refresh()
end

local elapsedSince = 0
driver:SetScript("OnUpdate", function(self, elapsed)
	if not UnitAffectingCombat("player") then
		fadeClock = fadeClock + elapsed
	end
	elapsedSince = elapsedSince + elapsed
	if elapsedSince < 0.02 then
		return
	end
	elapsedSince = 0
	local now = GetTime()
	-- Resolve casts that stopped without SUCCEEDED, and lost events.
	for i = 1, min(10, #history) do
		local e = history[i]
		if e.status == "casting" then
			if e.stopAt and now - e.stopAt > STOP_GRACE then
				if currentCast == e then
					currentCast = nil
				end
				e.status, e.finished, e.stopAt = "failed", e.stopAt, nil
			elseif not e.stopAt and e.endTime and now > e.endTime + 2 and currentCast ~= e then
				e.status, e.finished = "success", e.endTime
			end
		elseif e.status == "channeling" and currentChannel ~= e and e.endTime and now > e.endTime + 1 then
			e.status, e.finished = "success", e.endTime
		end
	end
	Refresh()
end)
driver:Hide()

driver:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		if ... ~= addonName then
			return
		end
		self:UnregisterEvent("ADDON_LOADED")
		-- Before 3.1 the settings were EllesmereUIDB.spellHistory.
		db = ns.ModuleDB("EllesmereUIDamageMetersDB", "spellHistory", "spellHistory")
		CopyDefaults(CreateDefaults(), db)
		loaded = true
		Apply()
	elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
		UpdateVisibility()
		Refresh()
	elseif event == "ACTIONBAR_SLOT_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" then
		previewSpells = nil
	else
		OnSpellEvent(event, ...)
	end
end)
driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("ZONE_CHANGED_NEW_AREA")
driver:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
driver:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

---------------------------------------------------------------------------
-- API for the settings window and Unlock Mode
---------------------------------------------------------------------------
ns.SH_GROW_DIRS = GROW_DIRS
ns.SH_ANIMATIONS = ANIMATIONS
ns.SH_TEXT_COLOR_MODES = COLOR_MODES_TEXT
ns.SH_BAR_COLOR_MODES = COLOR_MODES_BAR
ns.SH_VISIBILITY = VISIBILITY
ns.GetSpellHistoryDB = function() return db end

ns.SetSpellHistoryHidden = function(hidden)
	keybindHidden = hidden and true or false
	if db then
		UpdateVisibility()
	end
end

-- Shown while the Spell History page of the settings is open.
ns.SetSpellHistoryPreview = function(on)
	on = on and true or false
	if previewOn ~= on then
		previewOn = on
		previewSpells = nil
		UpdateVisibility()
		Refresh()
	end
end

ns.ResetSpellHistorySettings = function()
	local keep = { iconPos = db.iconPos, barPos = db.barPos }
	wipe(db)
	CopyDefaults(CreateDefaults(), db)
	for key, value in pairs(keep) do
		db[key] = value
	end
	Apply()
end

ns.applyHooks = ns.applyHooks or {}
tinsert(ns.applyHooks, Apply)

---------------------------------------------------------------------------
-- Unlock Mode (EllesmereUI core, retail EDM_IconHistory): the icon strip
-- (its newest icon is the saved center, the mover covers the whole strip)
-- and the bar window (saved as its top left corner).
---------------------------------------------------------------------------
local function SetUnlocked(on)
	iconsUnlocked, barsUnlocked = on and true or false, on and true or false
	local strata = on and "DIALOG" or "MEDIUM"
	head:SetFrameStrata(strata)
	win:SetFrameStrata(strata)
	if db then
		LayoutIcons()
		LayoutBars()
		UpdateVisibility()
		Refresh()
	end
end

local function RegisterUnlock()
	if not ns.RegisterUnlockElements then
		return
	end
	local MK = ns.MakeUnlockElement
	ns:RegisterUnlockElements({
		MK({
			key = "EDM_IconHistory",
			label = "Icon History",
			group = "Damage Meters",
			order = 700,
			noResize = true,
			getFrame = function() return head end,
			getSize = function() return iconBox:GetWidth(), iconBox:GetHeight() end,
			-- The mover covers the strip around the newest icon (negative insets).
			getInsets = function()
				local hl, hr, ht, hb = head:GetLeft(), head:GetRight(), head:GetTop(), head:GetBottom()
				local bl, br, bt, bb = iconBox:GetLeft(), iconBox:GetRight(), iconBox:GetTop(), iconBox:GetBottom()
				if not (hl and bl) then return nil end
				return bl - hl, hr - br, ht - bt, bb - hb
			end,
			isHidden = function() return not db or not db.iconEnabled end,
			savePos = function(_, point, relPoint, x, y)
				if point == "CENTER" and relPoint == "CENTER" then
					db.iconPos = { floor(x + 0.5), floor(y + 0.5) }
				end
				if not ns._unlockActive then LayoutIcons() end
			end,
			loadPos = function()
				if not db then return nil end
				return { point = "CENTER", relPoint = "CENTER", x = db.iconPos[1], y = db.iconPos[2] }
			end,
			clearPos = function() db.iconPos = { 0, -180 } end,
			applyPos = function() if db then LayoutIcons() end end,
		}),
		MK({
			key = "EDM_BarHistory",
			label = "Bar History",
			group = "Damage Meters",
			order = 701,
			getFrame = function() return win end,
			getSize = function() return win:GetWidth(), win:GetHeight() end,
			setWidth = function(_, w)
				db.barWidth = max(150, floor(w + 0.5))
				LayoutBars()
				Refresh()
			end,
			isHidden = function() return not db or not db.barEnabled end,
			-- Stored as the top left corner's offset from the screen center.
			savePos = function(_, point, relPoint, x, y)
				if point == "CENTER" and relPoint == "CENTER" then
					db.barPos = { floor(x - win:GetWidth() / 2 + 0.5), floor(y + win:GetHeight() / 2 + 0.5) }
				end
				if not ns._unlockActive then LayoutBars() end
			end,
			loadPos = function()
				if not db then return nil end
				return { point = "TOPLEFT", relPoint = "CENTER", x = db.barPos[1], y = db.barPos[2] }
			end,
			clearPos = function() db.barPos = { 250, -100 } end,
			applyPos = function() if db then LayoutBars() end end,
		}),
	}, "EllesmereUIDamageMeters")
	ns:RegisterUnlockModeListener("EllesmereUIDamageMeters", SetUnlocked)
end
RegisterUnlock()
