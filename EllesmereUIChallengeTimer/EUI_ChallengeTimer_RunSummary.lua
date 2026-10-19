-------------------------------------------------------------------------------
--  EUI_ChallengeTimer_RunSummary.lua (5.4.8 port)
--  Run Summary (Challenge Mode Tools): overview of a finished Challenge Mode with one
--  row per party member, plus a per character history of finished runs (/ov).
--
--  5.4.8: the numbers come from the combat log (retail reads Blizzard's damage
--  meter): damage done (pets count for their owner), damage taken,
--  interrupts and deaths. Spec and item level come from inspecting the group.
--  M+ score and loot do not exist for Challenge Modes and are skipped; the
--  header shows the medal instead of the key level / chest count.
--  Run records live in the per character EllesmereUIChallengeRunsDB.
-------------------------------------------------------------------------------
local addonName, P = ...
local ns = EllesmereUI

local floor, max, min = math.floor, math.max, math.min
local format = string.format


local db
local SV_NAME = "EllesmereUIChallengeRunsDB"
local SCHEMA = 1

local function Cfg()
	local p = db and db.profile
	return p and p.runSummary
end

local function Enabled()
	local c = Cfg()
	return c and c.enabled == true
end

-------------------------------------------------------------------------------
--  Store
-------------------------------------------------------------------------------
local function GetSV()
	local sv = _G[SV_NAME]
	if type(sv) ~= "table" then sv = {}; _G[SV_NAME] = sv end
	if type(sv.runs) ~= "table" then sv.runs = {} end
	if sv.schema == nil then sv.schema = SCHEMA end
	return sv
end

local function HistorySize()
	local c = Cfg()
	local n = c and tonumber(c.historySize) or 20
	if n < 5 then n = 5 elseif n > 50 then n = 50 end
	return n
end

local function StoreRun(record)
	local runs = GetSV().runs
	table.insert(runs, 1, record)
	for i = #runs, HistorySize() + 1, -1 do runs[i] = nil end
end

function P.RS_GetRuns()
	return GetSV().runs
end

function P.RS_ClearHistory()
	wipe(GetSV().runs)
end

-------------------------------------------------------------------------------
--  Collector
-------------------------------------------------------------------------------
local roster = {}      -- [guid] = member record
local petOwner = {}    -- [pet guid] = owner guid
local collecting = false
local frame
local lastRecord

local function ResetCollector()
	wipe(roster)
	wipe(petOwner)
end

local function EnsureMember(guid, unit)
	local rec = roster[guid]
	if not rec then
		rec = { guid = guid, damage = 0, damageTaken = 0, interrupts = 0, deaths = 0 }
		roster[guid] = rec
	end
	if unit then
		rec.unit = unit
		rec.name = UnitName(unit) or rec.name
		local _, class = UnitClass(unit)
		rec.class = class or rec.class
	end
	return rec
end

local function OwnSpecIcon()
	local spec = GetSpecialization()
	if not spec then return nil end
	local _, _, _, icon = GetSpecializationInfo(spec)
	return icon
end

local function SpecIconForSpecID(specID)
	if not specID or specID == 0 then return nil end
	local _, _, _, icon = GetSpecializationInfoByID(specID)
	return icon
end

local INV_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17 }
local function UnitItemLevel(unit)
	local total, count = 0, 0
	for _, slot in ipairs(INV_SLOTS) do
		local link = GetInventoryItemLink(unit, slot)
		if link then
			local _, _, _, ilvl = GetItemInfo(link)
			if ilvl and ilvl > 0 then
				total = total + ilvl
				count = count + 1
			end
		end
	end
	if count == 0 then return nil end
	return floor(total / count + 0.5)
end

local function ScanRoster()
	wipe(petOwner)
	for i = 1, #P.GROUP_UNITS do
		local unit = P.GROUP_UNITS[i]
		local guid = UnitExists(unit) and UnitGUID(unit)
		if guid then
			local rec = EnsureMember(guid, unit)
			local pet = (unit == "player") and "pet" or ("partypet" .. i - 1)
			local petGUID = UnitGUID(pet)
			if petGUID then petOwner[petGUID] = guid end
			if unit == "player" then
				rec.specIcon = OwnSpecIcon() or rec.specIcon
				local _, equipped = GetAverageItemLevel()
				if equipped and equipped > 0 then rec.ilvl = floor(equipped) end
			end
		end
	end
end

-- Inspect the party one at a time for spec and item level.
local inspectPending
local function InspectSweep()
	if inspectPending or InCombatLockdown() then return end
	for i = 2, #P.GROUP_UNITS do
		local unit = P.GROUP_UNITS[i]
		local guid = UnitExists(unit) and UnitGUID(unit)
		local rec = guid and roster[guid]
		if rec and (not rec.specIcon or not rec.ilvl) and CanInspect(unit) then
			inspectPending = guid
			NotifyInspect(unit)
			P.Timer.After(3, function()
				if inspectPending == guid then inspectPending = nil end
			end)
			return
		end
	end
end

local function OnInspectReady(guid)
	if guid ~= inspectPending then return end
	inspectPending = nil
	local rec = roster[guid]
	local unit = rec and rec.unit
	if rec and unit and UnitGUID(unit) == guid then
		rec.specIcon = SpecIconForSpecID(GetInspectSpecialization(unit)) or rec.specIcon
		rec.ilvl = UnitItemLevel(unit) or rec.ilvl
	end
	ClearInspectPlayer()
	P.Timer.After(1, InspectSweep)
end

local function MemberOf(guid)
	if not guid then return nil end
	return roster[guid] or (petOwner[guid] and roster[petOwner[guid]])
end

local DAMAGE_EVENTS = { SPELL_DAMAGE = 15, SPELL_PERIODIC_DAMAGE = 15, RANGE_DAMAGE = 15,
	DAMAGE_SHIELD = 15, SWING_DAMAGE = 12 }

local function OnCombatLog(...)
	local _, subEvent, _, srcGUID, _, _, _, destGUID = ...
	local amountIdx = DAMAGE_EVENTS[subEvent]
	if amountIdx then
		local amount = select(amountIdx, ...)
		if type(amount) ~= "number" then return end
		local src = MemberOf(srcGUID)
		if src then src.damage = src.damage + amount end
		local dst = roster[destGUID]
		if dst then dst.damageTaken = dst.damageTaken + amount end
	elseif subEvent == "SPELL_INTERRUPT" then
		local src = MemberOf(srcGUID)
		if src then src.interrupts = src.interrupts + 1 end
	elseif subEvent == "UNIT_DIED" then
		local dst = roster[destGUID]
		if dst and not (dst.unit and UnitIsFeignDeath(dst.unit)) then
			dst.deaths = dst.deaths + 1
		end
	elseif subEvent == "SPELL_SUMMON" then
		local src = roster[srcGUID]
		if src and destGUID then petOwner[destGUID] = srcGUID end
	end
end

local function StartCollecting()
	ResetCollector()
	collecting = true
	ScanRoster()
	frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	frame:RegisterEvent("GROUP_ROSTER_UPDATE")
	frame:RegisterEvent("UNIT_PET")
	frame:RegisterEvent("INSPECT_READY")
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	InspectSweep()
end

local function StopCollecting()
	collecting = false
	if frame then
		frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		frame:UnregisterEvent("GROUP_ROSTER_UPDATE")
		frame:UnregisterEvent("UNIT_PET")
		frame:UnregisterEvent("INSPECT_READY")
		frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
	end
end

local function OnEvent(_, event, ...)
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		OnCombatLog(...)
	elseif event == "GROUP_ROSTER_UPDATE" or event == "UNIT_PET" then
		ScanRoster()
		InspectSweep()
	elseif event == "INSPECT_READY" then
		OnInspectReady(...)
	elseif event == "PLAYER_REGEN_ENABLED" then
		InspectSweep()
	end
end

-------------------------------------------------------------------------------
--  Sorting (header click; retail keys)
-------------------------------------------------------------------------------
local SORT_KEYS = { dps = true, damageTaken = true, interrupts = true, deaths = true }

local function SortState()
	local c = Cfg() or {}
	local key = SORT_KEYS[c.sortKey] and c.sortKey or "dps"
	return key, c.sortAsc == true
end

local function SortMembers(list)
	local key, asc = SortState()
	table.sort(list, function(a, b)
		local va, vb = a[key] or 0, b[key] or 0
		if va ~= vb then
			if asc then return va < vb end
			return va > vb
		end
		return (a.name or "") < (b.name or "")
	end)
end

-------------------------------------------------------------------------------
--  Run end -> record
-------------------------------------------------------------------------------
local ShowWindow, RefreshWindowIfOpen

local function BuildRecord(run)
	local duration = max(1, run.elapsed or 0)
	local members = {}
	for _, rec in pairs(roster) do
		members[#members + 1] = {
			name = rec.name or "?", class = rec.class, specIcon = rec.specIcon, ilvl = rec.ilvl,
			damage = rec.damage, dps = rec.damage / duration, damageTaken = rec.damageTaken,
			interrupts = rec.interrupts, deaths = rec.deaths,
		}
	end
	SortMembers(members)
	local medal = run.medal or 0
	return {
		mapID = run.mapID, mapName = run.mapName, level = 0,
		timeMS = floor((run.elapsed or 0) * 1000), timeLimit = run.maxTime or 0,
		medal = medal, onTime = medal > 0,
		deaths = run.deaths or 0, timeLost = 0,
		finishedAt = time(), members = members,
	}
end

-- refreshOnly: the server's exact time arrived after the record was made.
function P.RS_RunCompleted(run, refreshOnly)
	if not Enabled() then return end
	if refreshOnly then
		if lastRecord and lastRecord.mapID == run.mapID then
			local duration = max(1, run.elapsed or 0)
			lastRecord.timeMS = floor((run.elapsed or 0) * 1000)
			lastRecord.medal = run.medal or lastRecord.medal
			lastRecord.onTime = (lastRecord.medal or 0) > 0
			for _, m in ipairs(lastRecord.members) do m.dps = (m.damage or 0) / duration end
			if RefreshWindowIfOpen then RefreshWindowIfOpen() end
		end
		return
	end
	StopCollecting()
	local record = BuildRecord(run)
	lastRecord = record
	StoreRun(record)
	P.Timer.After(2, function()
		if ShowWindow and Enabled() then ShowWindow(record) end
	end)
end

function P.RS_RunStarted()
	if not Enabled() then return end
	lastRecord = nil
	StartCollecting()
end

function P.RS_RunReset()
	StopCollecting()
end

function P.RS_Apply()
	if Enabled() then
		if not frame then
			frame = CreateFrame("Frame")
			frame:SetScript("OnEvent", OnEvent)
		end
		local run = P.EMT and P.EMT.currentRun
		if not collecting and run and run.active then
			StartCollecting()
		end
	elseif frame then
		frame:UnregisterAllEvents()
		StopCollecting()
	end
	if RefreshWindowIfOpen then RefreshWindowIfOpen() end
end

function P.RS_OnEnable(database)
	db = database
	if not db then return end
	P.RS_Apply()
end

-------------------------------------------------------------------------------
--  Window
-------------------------------------------------------------------------------
local PAD        = 15
local HEAD_H     = 56
local COLHDR_H   = 22
local COL_GAP    = 15
local SUB_GAP    = 5
local ICON_SZ    = 20
local DEFAULT_TEXT_SZ = 14
local TITLE_SZ   = 17
local SUBLINE_SZ = 13
local COLHDR_SZ  = 12
local PICKER_SZ  = 12
local NAME_MIN   = 150
local PICKER_W   = 240
local PICKER_H   = 22
local CLOSE_W    = 14
local HEADER_GAP = 10
local CLASS_ICON_TEX = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"

local COLUMNS = {
	{ key = "spec",        header = "",           kind = "icon", minW = ICON_SZ, cfg = "showSpecIcons", gapAfter = SUB_GAP },
	{ key = "name",        header = "Player",     kind = "text", justify = "LEFT",  minW = NAME_MIN, sub = "inline" },
	{ key = "dps",         header = "DPS",        kind = "text", justify = "RIGHT", minW = 52, cfg = "colDps" },
	{ key = "damageTaken", header = "Taken",      kind = "text", justify = "RIGHT", minW = 52, cfg = "colDamageTaken" },
	{ key = "interrupts",  header = "Interrupts", kind = "text", justify = "RIGHT", minW = 28, cfg = "colInterrupts" },
	{ key = "deaths",      header = "Deaths",     kind = "text", justify = "RIGHT", minW = 28, cfg = "colDeaths" },
}

local win, rows, colHdr, titleFS, subFS, pickerBtn, pickerLbl, pickerMenu
local visibleCols = {}
local currentRecord
local rowsTextSize

local function TextSize()
	local c = Cfg()
	local v = c and tonumber(c.textSize) or DEFAULT_TEXT_SZ
	if v < 8 then v = 8 elseif v > 24 then v = 24 end
	return v
end

local function RowHeight(size)
	return size + 9
end

local function NewFS(parent, size, r, g, b, a, flags)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	P.SetFS(fs, size, flags)
	fs:SetTextColor(r or 1, g or 1, b or 1, a or 1)
	fs:SetWordWrap(false)
	return fs
end

local function Abbrev(v)
	if type(v) ~= "number" then return nil end
	if v >= 1e9 then return format("%.2fB", v / 1e9) end
	if v >= 1e6 then return format("%.2fM", v / 1e6) end
	if v >= 1e4 then return format("%.1fK", v / 1e3) end
	return format("%d", floor(v + 0.5))
end

local function Clock(seconds)
	if type(seconds) ~= "number" or seconds < 0 then seconds = 0 end
	local whole = floor(seconds)
	return format("%d:%02d", floor(whole / 60), whole % 60)
end

local function ShortName(name)
	if type(name) ~= "string" then return "?" end
	return name:match("^([^%-]+)") or name
end

local function NonZero(v)
	if type(v) == "number" and floor(v) > 0 then return v end
	return nil
end

local function CellText(col, m)
	local k = col.key
	if k == "name" then
		local r, g, b = P.ClassColor(m.class)
		return P.Hex(r, g, b) .. ShortName(m.name) .. "|r"
	end
	if k == "dps" then return Abbrev(NonZero(m.dps)) or "-" end
	if k == "damageTaken" then return Abbrev(NonZero(m.damageTaken)) or "-" end
	if k == "interrupts" then return NonZero(m.interrupts) and format("%d", floor(m.interrupts)) or "-" end
	if k == "deaths" then return NonZero(m.deaths) and format("%d", floor(m.deaths)) or "-" end
	return ""
end

local function SubText(col, m, c)
	if col.key == "name" and c and c.colItemLevel ~= false and m.ilvl then
		return format("(%d)", m.ilvl)
	end
	return ""
end

local function RunWhen(ts)
	if not ts then return "" end
	local h = tonumber(date("%H", ts)) or 0
	local ampm = (h >= 12) and "pm" or "am"
	h = h % 12
	if h == 0 then h = 12 end
	return format("%s %d, %d:%s%s", date("%b", ts), tonumber(date("%d", ts)) or 0, h, date("%M", ts), ampm)
end

local function MedalText(medal, size)
	local tex = P.MEDAL_ICONS[medal or 0]
	if not tex then return "" end
	return format("|T%s:%d:%d:0:0|t ", tex, size, size)
end

local function RunLabel(rec)
	return format("%s%s   %s", MedalText(rec.medal, 12), rec.mapName or "?", RunWhen(rec.finishedAt))
end

local function SavePositionFromFrame()
	local c = Cfg()
	if not (c and win) then return end
	local point, _, relPoint, x, y = win:GetPoint(1)
	if not point then return end
	c.position = { point = point, relPoint = relPoint or point, x = x, y = y }
end

local function ApplyPosition()
	if not win then return end
	local c = Cfg()
	local pos = c and c.position
	win:ClearAllPoints()
	if pos and pos.point then
		win:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
	else
		win:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	end
end

local function StampRowFonts(row, size)
	for _, fs in pairs(row.text) do P.SetFS(fs, size) end
	for _, sfs in pairs(row.sub) do P.SetFS(sfs, size - 2, "") end
	row:SetHeight(RowHeight(size))
end

local function MakeRow(parent, size)
	size = size or DEFAULT_TEXT_SZ
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(RowHeight(size))
	row.text, row.sub, row.icons = {}, {}, {}
	local px = (ns.PP and ns.PP.mult) or 1
	for _, col in ipairs(COLUMNS) do
		local fs = NewFS(row, size)
		fs:SetJustifyH(col.justify or (col.kind == "icon" and "CENTER" or "LEFT"))
		row.text[col.key] = fs
		if col.kind == "icon" then
			local cell = CreateFrame("Frame", nil, row)
			cell:SetSize(ICON_SZ, ICON_SZ)
			cell.bg = cell:CreateTexture(nil, "BACKGROUND")
			cell.bg:SetAllPoints()
			cell.bg:SetTexture(0, 0, 0, 1)
			cell.tex = cell:CreateTexture(nil, "ARTWORK")
			cell.tex:SetPoint("TOPLEFT", cell, "TOPLEFT", px, -px)
			cell.tex:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", -px, px)
			row.icons[col.key] = cell
		elseif col.sub then
			local sfs = NewFS(row, size - 2, 0.55, 0.55, 0.55, 1, "")
			sfs:SetJustifyH("LEFT")
			row.sub[col.key] = sfs
		end
	end
	return row
end

local function ShowPicker(anchor)
	if pickerMenu and pickerMenu:IsShown() then
		pickerMenu:Hide()
		return
	end
	if not pickerMenu then
		pickerMenu = CreateFrame("Frame", nil, win)
		pickerMenu:SetFrameStrata("FULLSCREEN_DIALOG")
		pickerMenu:EnableMouse(true)
		local bg = pickerMenu:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetTexture(0.06, 0.06, 0.06, 0.97)
		P.ApplyEdges(pickerMenu, "_edges", pickerMenu, pickerMenu, 1, 0.25, 0.25, 0.25, 1, true)
		pickerMenu.items = {}
	end
	local runs = P.RS_GetRuns()
	local n = max(1, #runs)
	for i = 1, n do
		local item = pickerMenu.items[i]
		if not item then
			item = CreateFrame("Button", nil, pickerMenu)
			item:SetHeight(PICKER_H)
			item.hl = item:CreateTexture(nil, "HIGHLIGHT")
			item.hl:SetAllPoints()
			item.hl:SetTexture(1, 1, 1, 0.06)
			item.label = NewFS(item, PICKER_SZ)
			item.label:SetPoint("LEFT", item, "LEFT", 8, 0)
			item.label:SetPoint("RIGHT", item, "RIGHT", -8, 0)
			item.label:SetJustifyH("LEFT")
			pickerMenu.items[i] = item
		end
		item:ClearAllPoints()
		item:SetPoint("TOPLEFT", pickerMenu, "TOPLEFT", 0, -(i - 1) * PICKER_H)
		item:SetPoint("TOPRIGHT", pickerMenu, "TOPRIGHT", 0, -(i - 1) * PICKER_H)
		local rec = runs[i]
		if rec then
			item.label:SetText(RunLabel(rec))
			item.label:SetTextColor(1, 1, 1, 1)
			item:SetScript("OnClick", function()
				pickerMenu:Hide()
				ShowWindow(rec)
			end)
		else
			item.label:SetText("No runs recorded yet")
			item.label:SetTextColor(1, 1, 1, 0.4)
			item:SetScript("OnClick", function() pickerMenu:Hide() end)
		end
		item:Show()
	end
	for i = n + 1, #pickerMenu.items do pickerMenu.items[i]:Hide() end
	pickerMenu:SetSize(PICKER_W, n * PICKER_H)
	pickerMenu:ClearAllPoints()
	pickerMenu:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
	pickerMenu:Show()
end

local function BuildWindow()
	if win then return win end
	win = CreateFrame("Frame", "EUIChallengeRunSummaryFrame", UIParent)
	win:SetFrameStrata("FULLSCREEN")
	win:SetClampedToScreen(true)
	win:SetMovable(true)
	win:EnableMouse(true)
	win:Hide()
	if UISpecialFrames then tinsert(UISpecialFrames, "EUIChallengeRunSummaryFrame") end

	local bg = win:CreateTexture(nil, "BACKGROUND", nil, 0)
	bg:SetAllPoints()
	bg:SetTexture(0.06, 0.06, 0.07, 0.92)

	local header = CreateFrame("Frame", nil, win)
	header:SetFrameLevel(win:GetFrameLevel() + 5)
	header:SetPoint("TOPLEFT", win, "TOPLEFT", 0, 0)
	header:SetPoint("TOPRIGHT", win, "TOPRIGHT", 0, 0)
	header:SetHeight(HEAD_H)
	header:EnableMouse(true)
	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", function() win:StartMoving() end)
	header:SetScript("OnDragStop", function()
		win:StopMovingOrSizing()
		SavePositionFromFrame()
	end)
	local hbg = header:CreateTexture(nil, "BACKGROUND")
	hbg:SetAllPoints()
	hbg:SetTexture(0, 0, 0, 0.25)
	local px = (ns.PP and ns.PP.mult) or 1
	local sep = header:CreateTexture(nil, "ARTWORK")
	sep:SetHeight(px)
	sep:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
	sep:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
	sep:SetTexture(1, 1, 1, 0.10)

	titleFS = NewFS(header, TITLE_SZ)
	titleFS:SetPoint("TOPLEFT", header, "TOPLEFT", PAD, -HEADER_GAP)
	titleFS:SetJustifyH("LEFT")
	subFS = NewFS(header, SUBLINE_SZ, 1, 1, 1, 0.8)
	subFS:SetPoint("TOPLEFT", titleFS, "BOTTOMLEFT", 0, -SUB_GAP)
	subFS:SetJustifyH("LEFT")

	local close = CreateFrame("Button", nil, header)
	close:SetSize(CLOSE_W, CLOSE_W)
	close:SetPoint("TOPRIGHT", header, "TOPRIGHT", -PAD, -(HEADER_GAP + 2))
	close.label = NewFS(close, 14, 1, 1, 1, 0.7)
	close.label:SetPoint("CENTER", 0, 0)
	close.label:SetText("x")
	close:SetScript("OnEnter", function() close.label:SetAlpha(0.9) end)
	close:SetScript("OnLeave", function() close.label:SetAlpha(0.7) end)
	close:SetScript("OnClick", function() win:Hide() end)

	pickerBtn = CreateFrame("Button", nil, header)
	pickerBtn:SetSize(PICKER_W, PICKER_H)
	pickerBtn:SetPoint("TOPRIGHT", close, "TOPLEFT", -HEADER_GAP, (PICKER_H - CLOSE_W) / 2)
	local pfill = pickerBtn:CreateTexture(nil, "BACKGROUND")
	pfill:SetAllPoints()
	pfill:SetTexture(0.08, 0.08, 0.08, 0.92)
	P.ApplyEdges(pickerBtn, "_edges", pickerBtn, pickerBtn, 1, 0.25, 0.25, 0.25, 1, true)
	local phover = pickerBtn:CreateTexture(nil, "HIGHLIGHT")
	phover:SetAllPoints()
	phover:SetTexture(1, 1, 1, 0.05)
	local parrow = NewFS(pickerBtn, PICKER_SZ, 1, 1, 1, 0.7)
	parrow:SetPoint("RIGHT", pickerBtn, "RIGHT", -6, 0)
	parrow:SetText("v")
	pickerLbl = NewFS(pickerBtn, PICKER_SZ)
	pickerLbl:SetPoint("LEFT", pickerBtn, "LEFT", 8, 0)
	pickerLbl:SetPoint("RIGHT", parrow, "LEFT", -6, 0)
	pickerLbl:SetJustifyH("LEFT")
	pickerBtn:SetScript("OnClick", function() ShowPicker(pickerBtn) end)

	colHdr = MakeRow(win)
	colHdr:SetPoint("TOPLEFT", win, "TOPLEFT", 0, -HEAD_H)
	colHdr:SetPoint("TOPRIGHT", win, "TOPRIGHT", 0, -HEAD_H)
	colHdr:SetHeight(COLHDR_H)
	for _, col in ipairs(COLUMNS) do
		local fs = colHdr.text[col.key]
		P.SetFS(fs, COLHDR_SZ)
		fs:SetTextColor(1, 1, 1, 0.45)
	end
	for _, cell in pairs(colHdr.icons) do cell:Hide() end
	colHdr.sortBtns = {}
	for _, col in ipairs(COLUMNS) do
		if SORT_KEYS[col.key] then
			local fs = colHdr.text[col.key]
			local btn = CreateFrame("Button", nil, colHdr)
			btn:SetFrameLevel(colHdr:GetFrameLevel() + 2)
			btn:SetScript("OnEnter", function()
				if not btn.active then fs:SetTextColor(1, 1, 1, 0.8) end
			end)
			btn:SetScript("OnLeave", function()
				if not btn.active then fs:SetTextColor(1, 1, 1, 0.45) end
			end)
			btn:SetScript("OnClick", function()
				local c = Cfg()
				if not c then return end
				local key, asc = SortState()
				if key == col.key then
					c.sortAsc = not asc
				else
					c.sortKey = col.key
					c.sortAsc = false
				end
				RefreshWindowIfOpen()
			end)
			colHdr.sortBtns[col.key] = btn
		end
	end
	local hsep = win:CreateTexture(nil, "ARTWORK")
	hsep:SetHeight(px)
	hsep:SetPoint("TOPLEFT", colHdr, "BOTTOMLEFT", PAD, 0)
	hsep:SetPoint("TOPRIGHT", colHdr, "BOTTOMRIGHT", -PAD, 0)
	hsep:SetTexture(1, 1, 1, 0.10)
	rows = {}
	local bh = CreateFrame("Frame", nil, win)
	bh:SetAllPoints()
	bh:SetFrameLevel(win:GetFrameLevel() + 10)
	P.ApplyEdges(win, "_edges", bh, win, 1, 0.1, 0.1, 0.1, 1, true)
	return win
end

local function VisibleColumns()
	local c = Cfg() or {}
	wipe(visibleCols)
	for _, col in ipairs(COLUMNS) do
		if not col.cfg or c[col.cfg] ~= false then
			visibleCols[#visibleCols + 1] = col
		end
	end
	return visibleCols
end

local function MeasuredWidth(fs, fallback)
	if not fs then return fallback end
	local w = fs:GetStringWidth()
	if type(w) ~= "number" then return fallback end
	if w > 0 then w = math.ceil(w) + 1 end
	return w
end

local function FillSpecCell(cell, m)
	local zoom = 0.08
	if m.specIcon then
		cell.tex:SetTexture(m.specIcon)
		cell.tex:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
		cell:Show()
		return
	end
	local coords = m.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[m.class]
	if coords then
		cell.tex:SetTexture(CLASS_ICON_TEX)
		local l, r, t, b = coords[1], coords[2], coords[3], coords[4]
		local dx, dy = (r - l) * zoom, (b - t) * zoom
		cell.tex:SetTexCoord(l + dx, r - dx, t + dy, b - dy)
		cell:Show()
		return
	end
	cell:Hide()
end

local function PlaceInto(container, cols, widths, primW)
	local x = PAD
	for idx, col in ipairs(cols) do
		local wt = widths[idx]
		local fs = container.text[col.key]
		local sfs = container.sub and container.sub[col.key]
		local icon = container.icons[col.key]
		if icon then
			icon:ClearAllPoints()
			icon:SetPoint("LEFT", container, "LEFT", x + (wt - ICON_SZ) / 2, 0)
		end
		local sb = container.sortBtns and container.sortBtns[col.key]
		if sb then
			sb:ClearAllPoints()
			sb:SetPoint("TOPLEFT", container, "TOPLEFT", x, 0)
			sb:SetPoint("BOTTOMRIGHT", container, "TOPLEFT", x + wt, -COLHDR_H)
			sb:Show()
		end
		if fs then
			fs:ClearAllPoints()
			fs:SetPoint("LEFT", container, "LEFT", x, 0)
			if col.sub == "inline" then
				fs:SetWidth(wt)
				if sfs then
					local own = MeasuredWidth(fs, 0)
					sfs:ClearAllPoints()
					sfs:SetPoint("LEFT", container, "LEFT", x + own + SUB_GAP, 0)
					sfs:SetWidth(max(1, wt - own - SUB_GAP))
					sfs:Show()
				end
			else
				fs:SetWidth(primW[idx])
			end
			fs:Show()
		end
		x = x + wt + (col.gapAfter or COL_GAP)
	end
	for _, col in ipairs(COLUMNS) do
		local isShown = false
		for _, vc in ipairs(cols) do
			if vc.key == col.key then isShown = true break end
		end
		if not isShown then
			if container.text[col.key] then container.text[col.key]:Hide() end
			if container.sub and container.sub[col.key] then container.sub[col.key]:Hide() end
			if container.icons[col.key] then container.icons[col.key]:Hide() end
			if container.sortBtns and container.sortBtns[col.key] then container.sortBtns[col.key]:Hide() end
		end
	end
end

local function RenderHeader(record)
	titleFS:SetText(MedalText(record.medal, TITLE_SZ) .. (record.mapName or "?"))
	local timeHex = record.onTime and "40ff40" or "ff6060"
	local sub = format("|cff%s%s|r / %s", timeHex, Clock((record.timeMS or 0) / 1000), Clock(record.timeLimit or 0))
	if (record.medal or 0) > 0 then
		sub = sub .. "   " .. (P.MEDAL_NAMES[record.medal] or "")
	else
		sub = sub .. "   No Medal"
	end
	sub = sub .. "   |cff808080" .. format("%d Deaths", record.deaths or 0) .. "|r"
	subFS:SetText(sub)
	pickerLbl:SetText(RunLabel(record))
end

local scratchWidths, scratchPrim = {}, {}

local function Render(record)
	if not record or not win then return end
	local c = Cfg() or {}
	local members = record.members or {}
	local cols = VisibleColumns()
	SortMembers(members)
	RenderHeader(record)
	local textSize = TextSize()
	local rowH = RowHeight(textSize)
	local restamp = rowsTextSize ~= textSize
	rowsTextSize = textSize
	for i = 1, #members do
		if not rows[i] then
			rows[i] = MakeRow(win, textSize)
		elseif restamp then
			StampRowFonts(rows[i], textSize)
		end
		local y = -(HEAD_H + COLHDR_H + (i - 1) * rowH)
		rows[i]:ClearAllPoints()
		rows[i]:SetPoint("TOPLEFT", win, "TOPLEFT", 0, y)
		rows[i]:SetPoint("TOPRIGHT", win, "TOPRIGHT", 0, y)
		local row, m = rows[i], members[i]
		row:Show()
		for _, col in ipairs(COLUMNS) do
			local fs = row.text[col.key]
			if fs then
				fs:SetText(CellText(col, m))
				fs:SetTextColor(1, 1, 1, 1)
			end
			local sfs = row.sub[col.key]
			if sfs then sfs:SetText(SubText(col, m, c)) end
		end
		if row.icons.spec then FillSpecCell(row.icons.spec, m) end
	end
	for i = #members + 1, #rows do rows[i]:Hide() end

	local sortKey = SortState()
	for _, col in ipairs(COLUMNS) do
		local fs = colHdr.text[col.key]
		if fs then fs:SetText(col.header) end
		local sb = colHdr.sortBtns[col.key]
		if sb then
			sb.active = (col.key == sortKey)
			fs:SetTextColor(1, 1, 1, sb.active and 1 or 0.45)
		end
	end

	local widths, primW, total = scratchWidths, scratchPrim, 0
	wipe(widths); wipe(primW)
	for idx, col in ipairs(cols) do
		local wp, wt = col.minW, col.minW
		if col.kind == "icon" then
			wt = max(col.minW, MeasuredWidth(colHdr.text[col.key], 0))
			wp = wt
		else
			wp = MeasuredWidth(colHdr.text[col.key], 0)
			for i = 1, #members do wp = max(wp, MeasuredWidth(rows[i].text[col.key], 0)) end
			if col.sub == "inline" then
				wt = max(col.minW, MeasuredWidth(colHdr.text[col.key], 0))
				for i = 1, #members do
					local a = MeasuredWidth(rows[i].text[col.key], 0)
					local b = MeasuredWidth(rows[i].sub[col.key], 0)
					wt = max(wt, a + (b > 0 and (SUB_GAP + b) or 0))
				end
			else
				wp = max(wp, col.minW)
				wt = wp
			end
		end
		primW[idx], widths[idx] = wp, wt
		total = total + wt
	end
	for idx = 1, #cols - 1 do total = total + (cols[idx].gapAfter or COL_GAP) end
	total = total + PAD * 2
	PlaceInto(colHdr, cols, widths, primW)
	for i = 1, #members do PlaceInto(rows[i], cols, widths, primW) end
	local headerMin = max(
		PAD + MeasuredWidth(titleFS, 0) + COL_GAP + PICKER_W + HEADER_GAP + CLOSE_W + PAD,
		PAD + MeasuredWidth(subFS, 0) + PAD)
	total = max(total, headerMin)
	local height = HEAD_H + COLHDR_H + #members * rowH + PAD
	local scale = tonumber(c.scale) or 1
	if scale < 0.5 then scale = 0.5 elseif scale > 2 then scale = 2 end
	win:SetScale(scale)
	win:SetSize(total, height)
end

ShowWindow = function(record)
	if not record then return end
	BuildWindow()
	currentRecord = record
	Render(record)
	ApplyPosition()
	win:Show()
end

RefreshWindowIfOpen = function()
	if win and win:IsShown() and currentRecord then Render(currentRecord) end
end

function P.RS_Show(index)
	local i = floor(tonumber(index) or 1)
	if i < 1 then i = 1 end
	local rec = P.RS_GetRuns()[i]
	if not rec then
		ns.Print("No runs recorded yet")
		return
	end
	ShowWindow(rec)
end

local PREVIEW_CLASSES = { "PALADIN", "PRIEST", "ROGUE", "DRUID", "MAGE" }
local PREVIEW_SPEC_IDS = { 66, 257, 259, 102, 64 }
function P.RS_ShowPreview()
	local members = {}
	for i = 1, 5 do
		members[i] = {
			name        = "Preview " .. i,
			class       = PREVIEW_CLASSES[i],
			specIcon    = SpecIconForSpecID(PREVIEW_SPEC_IDS[i]),
			ilvl        = 540 + i * 3,
			damage      = 3000000 + i * 800000,
			dps         = 21000 + i * 6000,
			damageTaken = 920000 - i * 120000,
			interrupts  = 5 - i,
			deaths      = i % 2,
		}
	end
	ShowWindow({
		mapID = 960, mapName = "Temple of the Jade Serpent", level = 0,
		timeMS = 1010000, timeLimit = 1800, medal = 2, onTime = true,
		deaths = 3, timeLost = 0, finishedAt = time(), members = members,
	})
end

SLASH_EUIMPLUS1 = "/ov"
SLASH_EUIMPLUS2 = "/euimplus"
SlashCmdList.EUIMPLUS = function(msg)
	if not Enabled() then
		ns.Print("Run Summary is disabled in Challenge Mode Tools.")
		return
	end
	local lower = msg and msg:lower() or ""
	if lower:find("preview", 1, true) then
		P.RS_ShowPreview()
		return
	end
	P.RS_Show(msg and tonumber(msg:match("%d+")))
end
