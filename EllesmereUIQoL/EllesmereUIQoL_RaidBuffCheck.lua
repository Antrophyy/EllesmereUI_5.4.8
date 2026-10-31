-------------------------------------------------------------------------------
--  EllesmereUIQoL_RaidBuffCheck.lua -- Raid Buff Check, part of Raid Tools
--  (5.4.8 port of retail EllesmereUIQoL_RaidBuffCheck.lua)
--
--  A window listing each group member's flask, food and missing raid buffs
--  (QoL > Raid Tools > Raid Buff Check, off by default). Opens from the Buff
--  Check button (any group member: it only reads auras) and, if wanted, on
--  every ready check while the player leads or assists. Settings live in the
--  Raid Tools slice (EllesmereUIQoLDB.raidTools); RaidTools' Apply calls
--  ns.BuffCheckSync, so nothing listens while it is off.
--
--  Mists differences: no augment or vantus runes (those columns are gone),
--  the raid buffs are the eight Mists categories (any provider fills one),
--  flasks are the Mists flasks, Alchemist's Flask and Crystal of Insanity,
--  or a battle and a guardian elixir together, and every aura is readable
--  (UnitBuff). Out of combat only; the window hides when combat starts.
-------------------------------------------------------------------------------
local ns = EllesmereUI
if not ns then return end
local Q = ns.QoL

local EXPIRE_SOON = 600     -- under 10 minutes left shows the time instead of a check
local TICK = 15             -- re-render interval for the countdowns while the window is open
local TEX_YES  = "Interface\\RaidFrame\\ReadyCheck-Ready"
local TEX_NO   = "Interface\\RaidFrame\\ReadyCheck-NotReady"
local FLASK_ICON = "Interface\\Icons\\INV_Alchemy_Potion_06"
local FOOD_ICON = "Interface\\Icons\\INV_Misc_Food_15"
local EATING_ICON = "Interface\\Icons\\INV_Misc_Fork&Knife"
local WELL_FED_SPELL = 19705    -- "Well Fed" (name source, localized)
local FOOD_SPELL = 433          -- "Food" (the eating channel, name source)

-- Buff IDs. Copies of AuraBuff Reminders' Mists lists on purpose: QoL must
-- not depend on a sibling child addon the user may have disabled.
local FLASK_IDS = {
	105689, 105691, 105696, 105694, 105693, -- Spring Blossoms, Warm Sun, Winter's Bite, Earth, Falling Leaves
	79638, 79639, 79640,                    -- Alchemist's Flask (Enhanced Strength / Agility / Intellect)
	127230,                                 -- Crystal of Insanity (Visions of Insanity)
}
-- Elixirs: a battle and a guardian one together count as a flask. -- unsure IDs
local BATTLE_ELIXIRS = { 105682, 105683, 105684, 105685, 105686, 105688 }
local GUARDIAN_ELIXIRS = { 105681, 105687 }

-- The eight Mists raid buff categories; provides = classes that can bring it.
local RAID_BUFFS = {
	{ name = "Stats", icon = 1126, buffIDs = { 1126, 20217, 115921, 117666, 90363 },
	  provides = { DRUID = true, PALADIN = true, MONK = true } },
	{ name = "Stamina", icon = 21562, buffIDs = { 21562, 469, 6307, 109773, 90364 },
	  provides = { PRIEST = true, WARRIOR = true, WARLOCK = true } },
	{ name = "Attack Power", icon = 6673, buffIDs = { 6673, 57330, 19506 },
	  provides = { WARRIOR = true, DEATHKNIGHT = true, HUNTER = true } },
	{ name = "Spell Power", icon = 1459, buffIDs = { 1459, 61316, 109773, 77747, 126309 },
	  provides = { MAGE = true, WARLOCK = true, SHAMAN = true } },
	{ name = "Attack Speed", icon = 55610, buffIDs = { 55610, 113742, 30809, 128432, 128433 },
	  provides = { DEATHKNIGHT = true, ROGUE = true, SHAMAN = true } },
	{ name = "Spell Haste", icon = 24907, buffIDs = { 24907, 15473, 49868, 51470, 135678 },
	  provides = { DRUID = true, PRIEST = true, SHAMAN = true } },
	{ name = "Critical Strike", icon = 17007, buffIDs = { 1459, 61316, 17007, 24932, 116781, 24604, 90309, 126373, 126309 },
	  provides = { DRUID = true, MONK = true, MAGE = true } },
	{ name = "Mastery", icon = 19740, buffIDs = { 19740, 116956, 93435, 128997 },
	  provides = { PALADIN = true, SHAMAN = true } },
}

local PAD, TITLE_H, HEAD_H = 8, 24, 20
local ROW_H, NAME_W, CELL_W, ICON = 18, 110, 24, 14
local BUFF_SLOTS, BUFF_STEP = #RAID_BUFFS, 16
local CELLS = 2             -- flask, food
local BLOCK_GAP = 12
local ROWS_PER_BLOCK = 20
local TOTAL_ROWS = 3        -- Missing, Expiring soon, Unknown
local MIN_W = 320           -- fits the checkbox row and the note line
local NOTE_H = 16
local CB_H = 22             -- checkbox row between the totals and the note

local colX = { NAME_W, NAME_W + CELL_W }
local buffsX = NAME_W + CELLS * CELL_W + 4
local blockW = buffsX + BUFF_SLOTS * BUFF_STEP + 2

local ev = CreateFrame("Frame")
local frame
local rows, heads = {}, {}
local units = {}            -- display order
local isMember = {}         -- [unit] = true for listed group members
local states = {}           -- [unit] = last computed state
local shownUnits = {}       -- units drawn, in order
local providers = {}        -- [classToken] = true for connected members
local dirty, flushPending = {}, false
local Render                -- defined with the refresh code below

local function CDB()
	return ns.GetRaidToolsDB and ns.GetRaidToolsDB()
end

local function Enabled()
	local c = CDB()
	return c and c.buffCheck == true
end

local function OpenOnReady()
	local c = CDB()
	return c and c.buffCheckOnReady ~= false
end

-- Default on: shows only the players who are not fully buffed.
local function OnlyMissing()
	local c = CDB()
	return not c or c.buffCheckOnlyMissing ~= false
end

local function CanLead()
	if IsInRaid() then
		return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
	end
	return IsInGroup() and UnitIsGroupLeader("player")
end

local function Msg(text)
	local say = ns.Print or print
	say("|cff0cd29dEllesmereUI:|r " .. text)
end

local function SpellIcon(id)
	local _, _, icon = GetSpellInfo(id)
	return icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

-------------------------------------------------------------------------------
--  Aura lookups: one UnitBuff pass per unit into a spell ID -> expiry map.
-------------------------------------------------------------------------------
local auraExp, auraName = {}, {}

-- true or an expiration time = has it.
local function ScanUnit(unit)
	wipe(auraExp)
	wipe(auraName)
	for i = 1, 40 do
		local name, _, _, _, _, _, expires, _, _, _, spellID = UnitBuff(unit, i)
		if not name then break end
		local v = (expires and expires > 0) and expires or true
		if spellID then auraExp[spellID] = v end
		auraName[name] = v
	end
end

local function AnyOf(ids)
	local best
	for i = 1, #ids do
		local v = auraExp[ids[i]]
		if v then
			if v == true then return true end
			if not best or v > best then best = v end
		end
	end
	return best
end

local function FlaskState()
	local v = AnyOf(FLASK_IDS)
	if v then return v end
	local b, g = AnyOf(BATTLE_ELIXIRS), AnyOf(GUARDIAN_ELIXIRS)
	if b and g then
		if b == true then return g end
		if g == true then return b end
		return math.min(b, g)
	end
	return false
end

-- "eating" while the food channel is up and no Well Fed shows yet.
local function FoodState()
	local wellFed = GetSpellInfo(WELL_FED_SPELL) or "Well Fed"
	local v = auraName[wellFed]
	if v then return v end
	local food = GetSpellInfo(FOOD_SPELL) or "Food"
	if auraName[food] then return "eating" end
	return false
end

-- Seconds left when under EXPIRE_SOON, else nil.
local function SoonLeft(v, now)
	if type(v) ~= "number" then return nil end
	local left = v - now
	if left < EXPIRE_SOON then return math.max(0, left) end
end

local function MinutesText(left)
	return string.format("%dm", math.ceil(left / 60))
end

-------------------------------------------------------------------------------
--  Window
-------------------------------------------------------------------------------
local function Font(parent, size, r, g, b)
	return ns.MakeFont(parent, size, nil, r, g, b)
end

local function SetCell(cell, state, now)
	if state == nil then
		cell.tex:Hide()
		cell.q:SetText("?")
		cell.q:SetTextColor(0.6, 0.6, 0.6)
		cell.q:Show()
		return
	end
	local left = SoonLeft(state, now)
	if left then
		cell.tex:Hide()
		cell.q:SetText(MinutesText(left))
		cell.q:SetTextColor(1, 0.8, 0.2)
		cell.q:Show()
		return
	end
	cell.q:Hide()
	if state == "eating" then
		cell.tex:SetTexture(EATING_ICON)
		cell.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	else
		cell.tex:SetTexture(state and TEX_YES or TEX_NO)
		cell.tex:SetTexCoord(0, 1, 0, 1)
	end
	cell.tex:Show()
end

local function MakeCell(parent)
	local cell = CreateFrame("Frame", nil, parent)
	cell:SetSize(CELL_W, ROW_H)
	cell.tex = cell:CreateTexture(nil, "ARTWORK")
	cell.tex:SetSize(ICON, ICON)
	cell.tex:SetPoint("CENTER")
	cell.q = Font(cell, 11, 0.6, 0.6, 0.6)
	cell.q:SetPoint("CENTER")
	cell.q:SetText("?")
	return cell
end

local function MakeRow(i)
	local r = CreateFrame("Frame", nil, frame.table)
	r:SetSize(blockW, ROW_H)
	if i % 2 == 0 then
		local stripe = r:CreateTexture(nil, "BACKGROUND")
		stripe:SetTexture(1, 1, 1, 0.03)
		stripe:SetAllPoints(r)
	end
	r.name = Font(r, 11, 1, 1, 1)
	r.name:SetPoint("LEFT", r, "LEFT", 4, 0)
	r.name:SetWidth(NAME_W - 6)
	r.name:SetJustifyH("LEFT")
	r.name:SetWordWrap(false)
	r.flask = MakeCell(r)
	r.food = MakeCell(r)
	r.cells = { r.flask, r.food }
	for k = 1, CELLS do
		r.cells[k]:SetPoint("LEFT", r, "LEFT", colX[k], 0)
	end
	r.buffs = {}
	for j = 1, BUFF_SLOTS do
		local t = r:CreateTexture(nil, "ARTWORK")
		t:SetSize(ICON, ICON)
		t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		t:SetPoint("LEFT", r, "LEFT", buffsX + (j - 1) * BUFF_STEP, 0)
		r.buffs[j] = t
	end
	r.buffsOk = r:CreateTexture(nil, "ARTWORK")
	r.buffsOk:SetSize(ICON, ICON)
	r.buffsOk:SetTexture(TEX_YES)
	r.buffsOk:SetPoint("LEFT", r, "LEFT", buffsX, 0)
	r.buffsQ = Font(r, 11, 0.6, 0.6, 0.6)
	r.buffsQ:SetPoint("LEFT", r.buffsOk, "LEFT", 0, 0)
	r.buffsQ:SetText("?")
	rows[i] = r
	return r
end

local function MakeHeader(b)
	local h = CreateFrame("Frame", nil, frame.table)
	h:SetSize(blockW, HEAD_H)
	local function Icon(k, tex, tip)
		local hit = CreateFrame("Frame", nil, h)
		hit:SetSize(CELL_W, HEAD_H)
		hit:SetPoint("LEFT", h, "LEFT", colX[k], 0)
		local t = hit:CreateTexture(nil, "ARTWORK")
		t:SetSize(ICON + 2, ICON + 2)
		t:SetPoint("CENTER")
		t:SetTexture(tex)
		t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		hit:EnableMouse(true)
		hit:SetScript("OnEnter", function(self) ns.ShowWidgetTooltip(self, tip) end)
		hit:SetScript("OnLeave", function() ns.HideWidgetTooltip() end)
	end
	Icon(1, FLASK_ICON, "Flask\n(or a battle and a guardian elixir)")
	Icon(2, FOOD_ICON, "Food")
	h.buffsLabel = Font(h, 11, 0.8, 0.8, 0.8)
	h.buffsLabel:SetPoint("LEFT", h, "LEFT", buffsX, 0)
	h.buffsLabel:SetText("Raid Buffs")
	heads[b] = h
	return h
end

-- The window's events follow the window; READY_CHECK follows the option.
local function Listen(shown)
	ev:UnregisterAllEvents()
	if Enabled() and OpenOnReady() then ev:RegisterEvent("READY_CHECK") end
	if shown then
		ev:RegisterEvent("UNIT_AURA")
		ev:RegisterEvent("GROUP_ROSTER_UPDATE")
		ev:RegisterEvent("UNIT_CONNECTION")
		ev:RegisterEvent("PLAYER_REGEN_DISABLED")
	end
end

-- Kept as a TOPLEFT offset: the height (and width) change with the roster and
-- the filter, and the top-left corner must stay put while they do.
local function SavePosition()
	local c = CDB()
	if not c then return end
	local left, top = frame:GetLeft(), frame:GetTop()
	if not (left and top) then return end
	local x, y = left, top - UIParent:GetTop()
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
	c.buffCheckPos = { point = "TOPLEFT", relPoint = "TOPLEFT", x = x, y = y }
end

local function Build()
	if frame then return end
	frame = CreateFrame("Frame", "EllesmereUIRaidBuffCheck", UIParent)
	frame:SetFrameStrata("MEDIUM")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePosition()
	end)
	frame:Hide()
	frame:SetScript("OnHide", function()
		Listen(false)
		if frame._ticker then frame._ticker.Cancel(); frame._ticker = nil end
	end)

	local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
	bg:SetTexture(0.05, 0.05, 0.05, 0.92)
	bg:SetAllPoints(frame)
	local band = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
	band:SetTexture(0, 0, 0, 0.5)
	band:SetPoint("TOPLEFT")
	band:SetPoint("TOPRIGHT")
	band:SetHeight(TITLE_H)
	ns.MakeBorder(frame, 0.2, 0.2, 0.2, 1)

	local title = Font(frame, 12, 1, 1, 1)
	title:SetPoint("LEFT", frame, "TOPLEFT", PAD, -TITLE_H / 2)
	title:SetText("Raid Buff Check")

	local close = CreateFrame("Button", nil, frame)
	close:SetSize(16, 16)
	close:SetPoint("RIGHT", frame, "TOPRIGHT", -6, -TITLE_H / 2)
	local cfs = Font(close, 13, 1, 1, 1)
	cfs:SetPoint("CENTER", close, "CENTER", 0, 1)
	cfs:SetText("x")
	cfs:SetAlpha(0.7)
	close:SetScript("OnEnter", function() cfs:SetAlpha(1) end)
	close:SetScript("OnLeave", function() cfs:SetAlpha(0.7) end)
	close:SetScript("OnClick", function() frame:Hide() end)

	-- The checkbox above the note; its label is part of its hit rect.
	local ar, ag, ab = 1, 1, 1
	if ns.GetAccentColor then ar, ag, ab = ns.GetAccentColor() end
	local cb = CreateFrame("Button", nil, frame)
	cb:SetSize(14, 14)
	local box = cb:CreateTexture(nil, "BACKGROUND")
	box:SetTexture(0.08, 0.08, 0.08, 0.92)
	box:SetAllPoints(cb)
	ns.MakeBorder(cb, 0.35, 0.35, 0.35, 1)
	cb.check = cb:CreateTexture(nil, "ARTWORK")
	cb.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
	cb.check:SetPoint("CENTER")
	cb.check:SetSize(16, 16)
	cb.check:SetVertexColor(ar, ag, ab)
	cb.label = Font(frame, 11, 0.85, 0.85, 0.85)
	cb.label:SetPoint("LEFT", cb, "RIGHT", 6, 0)
	cb.label:SetText("Hide Fully Buffed")
	cb:SetHitRectInsets(0, -(cb.label:GetStringWidth() + 6), 0, 0)
	cb:SetScript("OnClick", function()
		local c = CDB()
		if not c then return end
		c.buffCheckOnlyMissing = not OnlyMissing()
		Render()
	end)
	cb:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD + 4, NOTE_H + (CB_H - 14) / 2)
	frame.onlyBox = cb

	frame.empty = Font(frame, 11, 0.4, 0.9, 0.4)
	frame.empty:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 4, -TITLE_H - 6)
	frame.empty:SetText("Everyone is fully buffed.")
	frame.empty:Hide()

	-- The table (column headers, player rows, totals) in one container, so
	-- "everyone fully buffed" hides it in one go.
	frame.table = CreateFrame("Frame", nil, frame)
	frame.table:SetAllPoints(frame)

	-- Totals under the first block: one count per column, aligned with its
	-- cells. Render places them; a row of zeros is hidden.
	local labels = { "Missing", "Expiring soon", "Unknown" }
	frame.totals = {}
	for t = 1, TOTAL_ROWS do
		local tr = CreateFrame("Frame", nil, frame.table)
		tr:SetSize(blockW, ROW_H)
		local lbl = Font(tr, 11, 0.85, 0.85, 0.85)
		lbl:SetPoint("LEFT", tr, "LEFT", 4, 0)
		lbl:SetText(labels[t])
		tr.counts = {}
		for k = 1, CELLS + 1 do
			local fs = Font(tr, 11, 1, 1, 1)
			if k <= CELLS then
				fs:SetPoint("CENTER", tr, "LEFT", colX[k] + CELL_W / 2, 0)
			else
				fs:SetPoint("CENTER", tr, "LEFT", buffsX + ICON / 2, 0)
			end
			tr.counts[k] = fs
		end
		frame.totals[t] = tr
	end
	frame.sep = frame.table:CreateTexture(nil, "ARTWORK")
	frame.sep:SetTexture(1, 1, 1, 0.15)
	frame.sep:SetHeight(1)
	frame.note = Font(frame, 10, 0.6, 0.6, 0.6)
	frame.note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, 4)
	frame.note:SetText("? = unknown (offline, dead or out of range)")

	local pos = CDB() and CDB().buffCheckPos
	if pos and pos.point == "TOPLEFT" then
		frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", pos.x or 0, pos.y or 0)
	else
		frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", UIParent:GetWidth() / 2 - MIN_W / 2, -150)
	end
end

-------------------------------------------------------------------------------
--  Roster and refresh: a state per unit, then Render draws the shown subset
-------------------------------------------------------------------------------
local sortName = {}
local function SortByName(a, b)
	local na, nb = sortName[a], sortName[b]
	if na ~= nb then
		if not na then return false end
		if not nb then return true end
		return na < nb
	end
	return a < b
end

local function CollectUnits()
	wipe(units)
	wipe(providers)
	wipe(isMember)
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do
			local u = "raid" .. i
			if UnitExists(u) then units[#units + 1] = u end
		end
	else
		units[1] = "player"
		for i = 1, GetNumSubgroupMembers() do
			local u = "party" .. i
			if UnitExists(u) then units[#units + 1] = u end
		end
	end
	wipe(sortName)
	for i = 1, #units do
		local u = units[i]
		local name = UnitName(u)
		if name then sortName[u] = strlower(name) end
	end
	table.sort(units, SortByName)
	for i = 1, #units do
		local u = units[i]
		isMember[u] = true
		if UnitIsConnected(u) then
			local _, cls = UnitClass(u)
			if cls then providers[cls] = true end
		end
	end
end

local function Provided(buff)
	for cls in pairs(buff.provides) do
		if providers[cls] then return true end
	end
	return false
end

local function ComputeState(unit)
	local s = states[unit]
	if not s then s = { icons = {} }; states[unit] = s end
	s.online = UnitIsConnected(unit) and true or false
	s.missing = 0
	s.buffsExp = nil
	local icons = s.icons
	if not s.online or UnitIsDeadOrGhost(unit) or not UnitIsVisible(unit) then
		s.flask, s.food = nil, nil
		for j = #icons, 1, -1 do icons[j] = nil end
		return
	end
	ScanUnit(unit)
	s.flask = FlaskState()
	s.food = FoodState()
	local n = 0
	for _, buff in ipairs(RAID_BUFFS) do
		if Provided(buff) then
			local has = AnyOf(buff.buffIDs)
			if not has then
				n = n + 1
				icons[n] = buff.icon
			elseif type(has) == "number" and (not s.buffsExp or has < s.buffsExp) then
				s.buffsExp = has
			end
		end
	end
	for j = #icons, n + 1, -1 do icons[j] = nil end
	s.missing = n
end

-- Missing, unknown (nil) and running out count; eating does not.
local function NotFullyBuffed(s, now)
	return not s.flask or not s.food or s.missing > 0
		or SoonLeft(s.flask, now) or SoonLeft(s.food, now) or SoonLeft(s.buffsExp, now)
end

local function PaintRow(r, unit, now)
	local s = states[unit]
	r.name:SetText(UnitName(unit))
	local _, cls = UnitClass(unit)
	local cc = cls and (ns.GetClassColor and ns.GetClassColor(cls) or RAID_CLASS_COLORS[cls])
	if cc and s.online then r.name:SetTextColor(cc.r, cc.g, cc.b) else r.name:SetTextColor(0.5, 0.5, 0.5) end
	SetCell(r.flask, s.flask, now)
	SetCell(r.food, s.food, now)
	local icons = s.icons
	for j = 1, BUFF_SLOTS do
		local id = icons[j]
		if id then
			r.buffs[j]:SetTexture(SpellIcon(id))
			r.buffs[j]:Show()
		else
			r.buffs[j]:Hide()
		end
	end
	-- flask is nil only for a row that was not read at all (offline, dead, out of range).
	local left = s.missing == 0 and SoonLeft(s.buffsExp, now)
	r.buffsOk:SetShown(s.flask ~= nil and s.missing == 0 and not left)
	if s.flask == nil then
		r.buffsQ:SetText("?")
		r.buffsQ:SetTextColor(0.6, 0.6, 0.6)
		r.buffsQ:Show()
	elseif left then
		r.buffsQ:SetText(MinutesText(left))
		r.buffsQ:SetTextColor(1, 0.8, 0.2)
		r.buffsQ:Show()
	else
		r.buffsQ:Hide()
	end
end

-- n == 0: Render hides the whole table; the empty message takes one row
-- under the title.
local function Layout(n, nTotals)
	if n == 0 then
		frame:SetSize(MIN_W, TITLE_H + 2 + ROW_H + 6 + CB_H + NOTE_H)
		return
	end
	local blocks = math.max(1, math.ceil(n / ROWS_PER_BLOCK))
	local perBlock = math.max(1, math.ceil(n / blocks))
	for b = 1, blocks do
		local h = heads[b] or MakeHeader(b)
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + (b - 1) * (blockW + BLOCK_GAP), -TITLE_H - 2)
		h:Show()
	end
	for b = blocks + 1, #heads do heads[b]:Hide() end
	for i = 1, n do
		local r = rows[i] or MakeRow(i)
		local b = math.floor((i - 1) / perBlock)
		local slot = (i - 1) % perBlock
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", heads[b + 1], "BOTTOMLEFT", 0, -slot * ROW_H)
		r:Show()
	end
	for i = n + 1, #rows do rows[i]:Hide() end
	frame:SetSize(math.max(MIN_W, PAD * 2 + blocks * blockW + (blocks - 1) * BLOCK_GAP),
		TITLE_H + 2 + HEAD_H + perBlock * ROW_H + 6 + nTotals * ROW_H + CB_H + NOTE_H)
end

-- totals[row][column]; columns are flask, food, raid buffs.
local totals = { {}, {}, {} }

local function Tally(t, col, v, now)
	if v == false then t[1][col] = t[1][col] + 1
	elseif v == nil then t[3][col] = t[3][col] + 1
	elseif SoonLeft(v, now) then t[2][col] = t[2][col] + 1 end
end

function Render()
	if not frame then return end
	local filter = OnlyMissing()
	local now = GetTime()
	for t = 1, TOTAL_ROWS do
		for k = 1, CELLS + 1 do totals[t][k] = 0 end
	end
	wipe(shownUnits)
	for i = 1, #units do
		local u = units[i]
		local s = states[u]
		if s then
			Tally(totals, 1, s.flask, now)
			Tally(totals, 2, s.food, now)
			-- Raid buffs: unread row = unknown, a missing buff = missing, else the soonest expiry.
			if s.flask == nil then
				totals[3][3] = totals[3][3] + 1
			elseif s.missing > 0 then
				totals[1][3] = totals[1][3] + 1
			elseif SoonLeft(s.buffsExp, now) then
				totals[2][3] = totals[2][3] + 1
			end
			if not filter or NotFullyBuffed(s, now) then shownUnits[#shownUnits + 1] = u end
		end
	end
	-- Totals rows with a non-zero count, stacked upward from the note line.
	local n = #shownUnits
	local nTotals, top = 0, nil
	for t = TOTAL_ROWS, 1, -1 do
		local tr = frame.totals[t]
		local any = false
		for k = 1, CELLS + 1 do
			local c = totals[t][k]
			tr.counts[k]:SetText(c)
			if c == 0 then
				tr.counts[k]:SetTextColor(0.3, 0.9, 0.3)
			else
				tr.counts[k]:SetTextColor(1, 0.3, 0.3)
				any = true
			end
		end
		tr:SetShown(any)
		if any then
			tr:ClearAllPoints()
			tr:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, NOTE_H + CB_H + nTotals * ROW_H)
			nTotals = nTotals + 1
			top = tr
		end
	end
	frame.sep:ClearAllPoints()
	if top then
		frame.sep:SetPoint("BOTTOMLEFT", top, "TOPLEFT", 0, 1)
		frame.sep:SetPoint("BOTTOMRIGHT", top, "TOPRIGHT", 0, 1)
	end
	frame.sep:SetShown(top ~= nil)

	Layout(n, nTotals)
	for i = 1, n do PaintRow(rows[i], shownUnits[i], now) end
	-- Nobody listed (everyone fully buffed): no header and no totals either.
	frame.table:SetShown(n > 0)
	frame.empty:SetShown(n == 0)
	frame.onlyBox.check:SetShown(filter)
end

local function Rebuild()
	if not frame or not frame:IsShown() or InCombatLockdown() then return end
	CollectUnits()
	wipe(states)
	for i = 1, #units do ComputeState(units[i]) end
	Render()
end

local function Flush()
	flushPending = false
	if not frame or not frame:IsShown() or InCombatLockdown() then wipe(dirty); return end
	for unit in pairs(dirty) do
		if isMember[unit] then ComputeState(unit) end
	end
	wipe(dirty)
	Render()
end

-------------------------------------------------------------------------------
--  Events
-------------------------------------------------------------------------------
local function Open()
	if InCombatLockdown() then
		Msg("Raid Buff Check cannot be opened in combat.")
		return
	end
	Build()
	frame:Show()
	Listen(true)
	Rebuild()
	if not frame._ticker and Q and Q.NewTicker then frame._ticker = Q.NewTicker(TICK, Render) end
end

-- Called by RaidTools' Apply (login, settings, profile switch).
function ns.BuffCheckSync()
	if not Enabled() and frame then frame:Hide() end
	Listen(frame and frame:IsShown())
end

ev:SetScript("OnEvent", function(_, event, unit)
	if event == "UNIT_AURA" or event == "UNIT_CONNECTION" then
		if not isMember[unit] then return end
		dirty[unit] = true
		if not flushPending and Q and Q.After then
			flushPending = true
			Q.After(0.2, Flush)
		end
	elseif event == "GROUP_ROSTER_UPDATE" then
		if not IsInGroup() then
			if frame then frame:Hide() end
			return
		end
		Rebuild()
	elseif event == "READY_CHECK" then
		if CanLead() then Open() end
	elseif event == "PLAYER_REGEN_DISABLED" then
		if frame then frame:Hide() end
	end
end)

-- The Buff Check button.
function ns.ToggleBuffCheck()
	if not Enabled() then return end
	if frame and frame:IsShown() then frame:Hide(); return end
	Open()
end
