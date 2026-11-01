-- Settings pages of QoL Addons > BIS Tracker. Part of EllesmereUIOptions
-- (load on demand); skipped when EllesmereUIBISTracker is not loaded.
--   Loot:     raid and boss pickers, then every item of the boss with one
--             button per difficulty (want it from there) and a Warforged /
--             Thunderforged only box next to it.
--   My List:  everything picked, by boss, with remove buttons.
--   Settings: the list shown when you kill a boss.

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUIBISTracker") then
	return
end

local BIS = ns.BIS
local floor, max = math.floor, math.max
local RetryLater, InfoText, SlotOrder

local function DB()
	return BIS.DB()
end

---------------------------------------------------------------------------
-- Small widgets (the options file's own are local to it)
---------------------------------------------------------------------------
local function FontPath()
	return (ns.GetFontPath and ns.GetFontPath()) or STANDARD_TEXT_FONT
end

local function Text(parent, size, alpha)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont(FontPath(), size, "")
	fs:SetTextColor(1, 1, 1, alpha or 1)
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetWordWrap(false)
	return fs
end

local function Solid(parent, layer, r, g, b, a)
	local t = parent:CreateTexture(nil, layer)
	t:SetTexture(r, g, b, a)
	return t
end

local function Border(frame, r, g, b, a)
	local edges = {}
	local function Edge(p1, p2, w, h)
		local t = Solid(frame, "BORDER", r, g, b, a)
		t:SetPoint(p1)
		t:SetPoint(p2)
		if w then t:SetWidth(w) end
		if h then t:SetHeight(h) end
		edges[#edges + 1] = t
	end
	Edge("TOPLEFT", "TOPRIGHT", nil, 1)
	Edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
	Edge("TOPLEFT", "BOTTOMLEFT", 1, nil)
	Edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)
	return {
		SetColor = function(_, nr, ng, nb, na)
			for i = 1, #edges do
				edges[i]:SetTexture(nr, ng, nb, na)
			end
		end,
	}
end

local function Wheel(p, frame)
	frame:EnableMouseWheel(true)
	frame:SetScript("OnMouseWheel", function(_, delta) p:ScrollBy(-delta * 60) end)
end

local function QualityColor(q)
	local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q or 4]
	if c then
		return c.r, c.g, c.b
	end
	return 0.64, 0.21, 0.93
end

local function ShowItemTip(owner, link, extra)
	BIS.ShowItemTooltip(owner, link, extra)
end

local function ShowTextTip(owner, title, text)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText(title, 1, 1, 1)
	if text then
		GameTooltip:AddLine(text, 1, 0.82, 0, true)
	end
	GameTooltip:Show()
end

-- Toggle chip: label, accent fill when on. paint(on, enabled).
local function Chip(p, parent, w, h, label)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, h)
	b.bg = Solid(b, "BACKGROUND", 0.08, 0.08, 0.09, 0.9)
	b.bg:SetAllPoints()
	b.border = Border(b, 1, 1, 1, 0.15)
	b.label = Text(b, 11, 0.6)
	b.label:SetPoint("CENTER", 0, 0)
	b.label:SetText(label)
	Wheel(p, b)
	function b:Paint(on, enabled)
		local r, g, bl = ns.ResolveAccent()
		local hover = self:IsMouseOver() and enabled
		self:SetAlpha(enabled and 1 or 0.3)
		if on then
			self.bg:SetTexture(r, g, bl, hover and 0.45 or 0.32)
			self.border:SetColor(r, g, bl, 0.9)
			self.label:SetTextColor(1, 1, 1, 1)
		else
			self.bg:SetTexture(0.08, 0.08, 0.09, hover and 1 or 0.9)
			self.border:SetColor(1, 1, 1, hover and 0.3 or 0.15)
			self.label:SetTextColor(1, 1, 1, hover and 0.85 or 0.55)
		end
	end
	return b
end

---------------------------------------------------------------------------
-- Raid / boss pickers
---------------------------------------------------------------------------
local function SelectedRaid()
	local raids = BIS.GetRaids()
	local sel = DB().selRaid
	for _, r in ipairs(raids) do
		if r.id == sel then
			return sel
		end
	end
	-- Default: the newest raid (Siege of Orgrimmar).
	for _, r in ipairs(raids) do
		if r.id == BIS.RAID_SOO then
			return r.id
		end
	end
	return raids[1] and raids[1].id or nil
end

local function SelectedBoss(raidID)
	-- 0 = All Bosses (the default): the loot of the whole raid.
	local sel = DB().selBoss
	for _, b in ipairs(BIS.GetBosses(raidID)) do
		if b.id == sel then
			return sel
		end
	end
	return 0
end

local function RaidItems()
	local items = {}
	for _, r in ipairs(BIS.GetRaids()) do
		items[#items + 1] = { name = r.name, value = r.id }
	end
	return items
end

local function BossName(raidID, bossID)
	if bossID == 0 then
		return "All Bosses"
	end
	return BIS.BossName(raidID, bossID)
end

local function BossItems()
	local items = { { name = "All Bosses", value = 0 } }
	for _, b in ipairs(BIS.GetBosses(SelectedRaid())) do
		local n = 0
		local saved = BIS.CharDB().bosses[b.id]
		if saved then
			for _ in pairs(saved.items) do
				n = n + 1
			end
		end
		items[#items + 1] = { name = n > 0 and (b.name .. "  (" .. n .. ")") or b.name, value = b.id }
	end
	return items
end

---------------------------------------------------------------------------
-- Loot list
---------------------------------------------------------------------------
-- While the loot is loading: look again every second (the page is rebuilt
-- when the loot state changes; see LootKey).
local retryFrame
RetryLater = function()
	retryFrame = retryFrame or CreateFrame("Frame")
	local waited = 0
	retryFrame:SetScript("OnUpdate", function(self, elapsed)
		waited = waited + elapsed
		if waited < 1 then
			return
		end
		self:SetScript("OnUpdate", nil)
		if BIS.OnLootData then
			BIS.OnLootData()
		end
	end)
end

-- "Slot - Armor" under the item name. The journal colors a slot / armor
-- type you cannot use in a dark red; that code is replaced by a readable red.
local INFO_GRAY, UNUSABLE_RED = "|cff8c8c8c", "|cffff6b6b"
local function Plain(text)
	text = tostring(text or "")
	local colored = text:find("|c%x%x%x%x%x%x%x%x") ~= nil
	return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")), colored
end
function InfoText(slot, armor)
	local parts = {}
	for _, v in ipairs({ slot or "", armor or "" }) do
		local text, unusable = Plain(v)
		if text ~= "" then
			parts[#parts + 1] = (unusable and UNUSABLE_RED or INFO_GRAY) .. text .. "|r"
		end
	end
	return table.concat(parts, INFO_GRAY .. "  -  |r")
end

-- Equipment order of the journal's slot names (English client); unknown
-- slots (tokens, other) come last.
local SLOT_ORDER = {}
for i, slot in ipairs({ "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands", "Waist", "Legs", "Feet",
	"Finger", "Trinket", "One-Hand", "Main Hand", "Two-Hand", "Ranged", "Off Hand", "Held In Off-hand", "Relic" }) do
	SLOT_ORDER[slot] = i
end
function SlotOrder(slot)
	local plain = tostring(slot or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	return SLOT_ORDER[plain] or 99
end

local ITEM_ROW_H = 40
local searchText = "" -- kept while you switch bosses
local CHIP_W, CHIP_H, WF_W, GROUP_GAP = 58, 24, 34, 10

local function BuildLootList(p, raidID, bossID)
	local allBosses = bossID == 0
	local items, state
	if allBosses then
		items, state = BIS.GetRaidLoot(raidID)
	else
		items, state = BIS.GetLoot(raidID, bossID)
	end
	if state == "loading" then
		RetryLater()
	end
	-- A whole raid is built once, when every boss's loot is there (building
	-- hundreds of rows on every bit of data that arrives makes the game lag).
	if allBosses and state == "loading" then
		p:Paragraph("Loading the loot of the whole raid from the Encounter Journal...")
		return
	end
	if #items == 0 then
		if state == "loading" then
			p:Paragraph("Loading the loot of this boss from the Encounter Journal...")
		else
			p:Paragraph("The Encounter Journal gave no loot for this boss. Type /bis debug in chat and send what it prints.")
		end
		return
	end
	if state ~= "ok" then
		p:Paragraph("Some item names are still loading; the list fills in by itself.")
	end
	p:CloseRow()

	-- Picked items first, then the rest; in both grouped by slot (head,
	-- neck, ... weapons, other) and alphabetical inside a slot (the journal
	-- order is by slot). The order is set when the page is built, so rows do
	-- not jump while you click.
	local function Picked(item)
		local saved = BIS.CharDB().bosses[item.bossID]
		return saved and saved.items[item.name] ~= nil or false
	end
	local sorted = {}
	for i = 1, #items do
		sorted[i] = items[i]
	end
	table.sort(sorted, function(a, b)
		local pa, pb = Picked(a), Picked(b)
		if pa ~= pb then
			return pa
		end
		local sa, sb = SlotOrder(a.slot), SlotOrder(b.slot)
		if sa ~= sb then
			return sa < sb
		end
		return a.name < b.name
	end)
	items = sorted

	local diffs = BIS.GetDifficulties(raidID)
	local forged = BIS.ForgedName(raidID)
	local width = p:RowWidth()
	local pad = floor((p.child:GetWidth() - width) / 2)
	local groupW = CHIP_W + (forged and (2 + WF_W) or 0)
	local controlsW = #diffs * groupW + (#diffs - 1) * GROUP_GAP

	-- Search box: filters by item name, slot or armor type while typing.
	local SEARCH_H = 30
	local search = CreateFrame("EditBox", nil, p.child)
	search:SetSize(width, SEARCH_H)
	search:SetPoint("TOPLEFT", p.child, "TOPLEFT", pad, p.y - 8)
	search:SetAutoFocus(false)
	search:SetFont(FontPath(), 13, "")
	search:SetTextColor(1, 1, 1, 0.9)
	search:SetTextInsets(34, 30, 0, 0)
	search:SetMaxLetters(60)
	Wheel(p, search)
	local sbg = Solid(search, "BACKGROUND", 0.08, 0.08, 0.09, 0.9)
	sbg:SetAllPoints()
	local sborder = Border(search, 1, 1, 1, 0.15)
	local glass = search:CreateTexture(nil, "ARTWORK")
	glass:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
	glass:SetSize(14, 14)
	glass:SetPoint("LEFT", 12, -1)
	glass:SetVertexColor(1, 1, 1, 0.5)
	local placeholder = Text(search, 13, 0.3)
	placeholder:SetPoint("LEFT", 34, 0)
	placeholder:SetText("Search items (name, slot, armor)")
	local clear = CreateFrame("Button", nil, search)
	clear:SetSize(22, 22)
	clear:SetPoint("RIGHT", -6, 0)
	clear.label = Text(clear, 14, 0.5)
	clear.label:SetPoint("CENTER", 0, 1)
	clear.label:SetText("x")
	p.y = p.y - 8 - SEARCH_H

	-- Column labels
	local head = CreateFrame("Frame", nil, p.child)
	head:SetSize(width, 22)
	head:SetPoint("TOPLEFT", p.child, "TOPLEFT", pad, p.y - 6)
	Wheel(p, head)
	local itemLabel = Text(head, 11, 0.4)
	itemLabel:SetPoint("LEFT", 14, 0)
	itemLabel:SetText("ITEM")
	local noMatch = Text(p.child, 13, 0.45)
	noMatch:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 14, -14)
	noMatch:SetText("No items match your search.")
	noMatch:Hide()
	local hint = Text(head, 11, 0.4)
	hint:SetPoint("RIGHT", -14, 0)
	hint:SetText(forged and ("CLICK THE VERSIONS YOU WANT  -  WF = " .. forged:upper()) or "CLICK THE DIFFICULTIES YOU WANT")
	p.y = p.y - 6 - 22

	local list = CreateFrame("Frame", nil, p.child)
	list:SetSize(width, #items * ITEM_ROW_H)
	list:SetPoint("TOPLEFT", p.child, "TOPLEFT", pad, p.y - 2)
	Wheel(p, list)
	p.y = p.y - 2 - #items * ITEM_ROW_H - 8

	local painters = {}
	local function PaintAll()
		for i = 1, #painters do
			painters[i]()
		end
	end

	local rows = {}
	local function Layout()
		local q = (searchText or ""):lower()
		local n = 0
		for _, row in ipairs(rows) do
			local show = q == "" or row.haystack:find(q, 1, true) ~= nil
			row:SetShown(show)
			if show then
				n = n + 1
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(n - 1) * ITEM_ROW_H)
				row.bg:SetTexture(0, 0, 0, (n % 2 == 0) and 0.2 or 0.1)
			end
		end
		noMatch:SetShown(n == 0)
		placeholder:SetShown((search:GetText() or "") == "")
		clear:SetShown((search:GetText() or "") ~= "")
	end

	for i, item in ipairs(items) do
		local row = CreateFrame("Frame", nil, list)
		row:SetSize(width, ITEM_ROW_H)
		row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(i - 1) * ITEM_ROW_H)
		Wheel(p, row)
		rows[#rows + 1] = row
		row.haystack = (item.name .. " " .. (item.slot or "") .. " " .. (item.armor or "") .. " " .. (item.bossName or "")):lower()
		row.bg = Solid(row, "BACKGROUND", 0, 0, 0, (i % 2 == 0) and 0.2 or 0.1)
		row.bg:SetAllPoints()
		row.mark = row:CreateTexture(nil, "ARTWORK")
		row.mark:SetPoint("TOPLEFT")
		row.mark:SetPoint("BOTTOMLEFT")
		row.mark:SetWidth(2)

		-- Any difficulty's link for the tooltip (Normal first).
		local anyLink
		for _, key in ipairs({ "normal", "heroic", "flex", "lfr" }) do
			if item.byDiff[key] and item.byDiff[key].link then
				anyLink = anyLink or item.byDiff[key].link
			end
		end

		local nameBtn = CreateFrame("Button", nil, row)
		nameBtn:SetPoint("TOPLEFT", 10, 0)
		nameBtn:SetPoint("BOTTOMLEFT", 10, 0)
		nameBtn:SetWidth(width - controlsW - 30)
		Wheel(p, nameBtn)
		local icon = nameBtn:CreateTexture(nil, "ARTWORK")
		icon:SetSize(28, 28)
		icon:SetPoint("LEFT", 0, 0)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
		local name = Text(nameBtn, 13, 1)
		name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -1)
		name:SetPoint("RIGHT", nameBtn, "RIGHT", 0, 0)
		name:SetJustifyH("LEFT")
		name:SetText(item.name)
		name:SetTextColor(QualityColor(item.quality))
		local info = Text(nameBtn, 11, 1)
		info:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 10, 1)
		info:SetPoint("RIGHT", nameBtn, "RIGHT", 0, 0)
		info:SetJustifyH("LEFT")
		local infoText = InfoText(item.slot, item.armor)
		if allBosses and item.bossName then
			infoText = infoText .. "|cff8c8c8c  -  |r|cffbfbfbf" .. item.bossName .. "|r"
		end
		info:SetText(infoText)
		nameBtn:SetScript("OnEnter", function(self) ShowItemTip(self, anyLink) end)
		nameBtn:SetScript("OnLeave", function() BIS.HideItemTooltip() end)
		nameBtn:SetScript("OnClick", function()
			if IsModifiedClick("CHATLINK") and anyLink then
				ChatEdit_InsertLink(anyLink)
			end
		end)

		-- Difficulty groups, right to left.
		local x = -14
		for j = #diffs, 1, -1 do
			local key = diffs[j]
			local d = BIS.DIFF_BY_KEY[key]
			local has = item.byDiff[key] ~= nil
			local wf
			if forged then
				wf = Chip(p, row, WF_W, CHIP_H, "WF")
				wf:SetPoint("RIGHT", row, "RIGHT", x, 0)
				x = x - WF_W - 2
			end
			local chip = Chip(p, row, CHIP_W, CHIP_H, d.text)
			chip:SetPoint("RIGHT", row, "RIGHT", x, 0)
			x = x - CHIP_W - GROUP_GAP

			local function Paint()
				local wish = BIS.GetWish(item.bossID, item.name, key)
				chip:Paint(wish ~= nil and wish.base, has)
				if wf then
					wf:Paint(wish ~= nil and wish.wf, has)
				end
			end
			painters[#painters + 1] = Paint

			chip:SetScript("OnClick", function()
				if not has then
					return
				end
				local wish = BIS.GetWish(item.bossID, item.name, key)
				BIS.SetWant(raidID, item.bossID, item, key, "base", not (wish and wish.base))
				PaintAll()
			end)
			chip:SetScript("OnEnter", function(self)
				Paint()
				local link = item.byDiff[key] and item.byDiff[key].link
				if link then
					ShowItemTip(self, link, function(tt)
						tt:AddLine(" ")
						tt:AddLine("Click: want the " .. (forged and "normal " or "") .. d.long .. " version of this item.", 0.05, 0.82, 0.62)
					end)
				else
					ShowTextTip(self, d.long, "The journal lists no " .. d.long .. " version of this item"
						.. (state ~= "ok" and " yet (still loading; the page updates when it arrives)." or "."))
				end
			end)
			chip:SetScript("OnLeave", function()
				BIS.HideItemTooltip()
				Paint()
			end)
			if wf then
				wf:SetScript("OnClick", function()
					if not has then
						return
					end
					local wish = BIS.GetWish(item.bossID, item.name, key)
					BIS.SetWant(raidID, item.bossID, item, key, "wf", not (wish and wish.wf))
					PaintAll()
				end)
				wf:SetScript("OnEnter", function(self)
					Paint()
					ShowTextTip(self, d.text .. " " .. forged,
						"Click: want the " .. forged .. " version of this item on " .. d.long
						.. ". Turn on " .. d.text .. " too if you want either version.")
				end)
				wf:SetScript("OnLeave", function()
					GameTooltip:Hide()
					Paint()
				end)
			end
		end

		painters[#painters + 1] = function()
			local saved = BIS.CharDB().bosses[item.bossID]
			local wanted = saved and saved.items[item.name] ~= nil
			local r, g, b = ns.ResolveAccent()
			row.mark:SetTexture(r, g, b, wanted and 0.9 or 0)
		end
	end

	search:SetScript("OnTextChanged", function(self)
		searchText = self:GetText() or ""
		Layout()
	end)
	search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	search:SetScript("OnEditFocusGained", function()
		local r, g, b = ns.ResolveAccent()
		sborder:SetColor(r, g, b, 0.8)
	end)
	search:SetScript("OnEditFocusLost", function() sborder:SetColor(1, 1, 1, 0.15) end)
	clear:SetScript("OnClick", function()
		search:SetText("")
		search:ClearFocus()
	end)
	search:SetText(searchText or "")
	Layout()

	p:OnRefresh(PaintAll)
	PaintAll()
end

---------------------------------------------------------------------------
-- My List
---------------------------------------------------------------------------
local LIST_ROW_H, BOSS_ROW_H = 32, 34

local function BuildWishList(p)
	local list = BIS.GetWishList()
	if #list == 0 then
		p:Paragraph("Nothing picked yet. Choose a raid and a boss on the Loot tab and click the difficulties you want an item from.")
		return
	end
	p:CloseRow()
	local width = p:RowWidth()
	local pad = floor((p.child:GetWidth() - width) / 2)

	local function RemoveButton(parent, tip, onClick)
		local b = CreateFrame("Button", nil, parent)
		b:SetSize(22, 22)
		b:SetPoint("RIGHT", parent, "RIGHT", -10, 0)
		b.label = Text(b, 14, 0.45)
		b.label:SetPoint("CENTER", 0, 1)
		b.label:SetText("x")
		Wheel(p, b)
		b:SetScript("OnEnter", function(self)
			self.label:SetTextColor(1, 0.35, 0.35, 1)
			ShowTextTip(self, tip)
		end)
		b:SetScript("OnLeave", function(self)
			self.label:SetTextColor(1, 1, 1, 0.45)
			GameTooltip:Hide()
		end)
		b:SetScript("OnClick", function()
			GameTooltip:Hide()
			onClick()
		end)
		return b
	end

	local lastRaid
	for _, boss in ipairs(list) do
		if boss.raid ~= lastRaid then
			lastRaid = boss.raid
			p:Section(boss.raid ~= "" and boss.raid or "Raid")
		end
		local head = CreateFrame("Button", nil, p.child)
		head:SetSize(width, BOSS_ROW_H)
		head:SetPoint("TOPLEFT", p.child, "TOPLEFT", pad, p.y - 4)
		Wheel(p, head)
		local hbg = Solid(head, "BACKGROUND", 1, 1, 1, 0.04)
		hbg:SetAllPoints()
		local hname = Text(head, 14, 0.95)
		hname:SetPoint("LEFT", 14, 0)
		hname:SetText(boss.name)
		local hcount = Text(head, 11, 0.4)
		hcount:SetPoint("LEFT", hname, "RIGHT", 10, 0)
		hcount:SetText(#boss.items .. (#boss.items == 1 and " item" or " items") .. "  -  click to edit")
		head:SetScript("OnClick", function()
			DB().selRaid, DB().selBoss = boss.raidID, boss.bossID
			if ns.SelectPage then
				ns:SelectPage(1)
			end
		end)
		RemoveButton(head, "Remove all items of " .. boss.name, function()
			BIS.RemoveBoss(boss.bossID)
		end)
		p.y = p.y - 4 - BOSS_ROW_H

		for i, it in ipairs(boss.items) do
			local row = CreateFrame("Button", nil, p.child)
			row:SetSize(width, LIST_ROW_H)
			row:SetPoint("TOPLEFT", p.child, "TOPLEFT", pad, p.y)
			Wheel(p, row)
			local bg = Solid(row, "BACKGROUND", 0, 0, 0, (i % 2 == 0) and 0.2 or 0.1)
			bg:SetAllPoints()
			local icon = row:CreateTexture(nil, "ARTWORK")
			icon:SetSize(22, 22)
			icon:SetPoint("LEFT", 24, 0)
			icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			icon:SetTexture(it.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
			local name = Text(row, 13, 1)
			name:SetPoint("LEFT", icon, "RIGHT", 10, 0)
			name:SetWidth(floor(width * 0.45))
			name:SetJustifyH("LEFT")
			name:SetText(it.name)
			name:SetTextColor(QualityColor(it.quality))
			local parts = {}
			local forged = BIS.ForgedName(boss.raidID) or "Warforged"
			for _, d in ipairs(it.diffs) do
				local def = BIS.DIFF_BY_KEY[d.key]
				local v = BIS.VersionText(d.base, d.wf, boss.raidID)
				parts[#parts + 1] = (def and def.text or d.key) .. (v ~= "" and (" |cffff8c26" .. v .. "|r") or "")
			end
			local diffsText = Text(row, 12, 0.7)
			diffsText:SetPoint("RIGHT", row, "RIGHT", -44, 0)
			diffsText:SetJustifyH("RIGHT")
			diffsText:SetText(table.concat(parts, "  -  "))
			local link = it.diffs[1] and it.diffs[1].link
			row:SetScript("OnEnter", function(self) ShowItemTip(self, link) end)
			row:SetScript("OnLeave", function() BIS.HideItemTooltip() end)
			row:SetScript("OnClick", function()
				if IsModifiedClick("CHATLINK") and link then
					ChatEdit_InsertLink(link)
				end
			end)
			RemoveButton(row, "Remove " .. it.name, function()
				BIS.RemoveItem(boss.bossID, it.name)
			end)
			p.y = p.y - LIST_ROW_H
		end
	end
	p.y = p.y - 8
end

---------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------
local PAGES
local function ActiveTab()
	if ns.GetActiveModule and ns:GetActiveModule() == "bisTracker" then
		return ns:GetActivePage()
	end
	return nil
end

-- Loot page key: raid, boss and whether all item names were known when built.
local shownLootKey -- key of the Loot page built last
local function LootKey()
	local raid = SelectedRaid()
	local boss = raid and SelectedBoss(raid)
	local items, state
	if boss == 0 then
		items, state = BIS.GetRaidLoot(raid)
	else
		items, state = BIS.GetLoot(raid, boss)
	end
	-- The picked items shown: the page is built again (picked items on
	-- top) when you come back to it after picking.
	local picked = {}
	for bossID, saved in pairs(BIS.CharDB().bosses) do
		if bossID == boss or (boss == 0 and saved.raidID == raid) then
			for name in pairs(saved.items) do
				picked[#picked + 1] = bossID .. name
			end
		end
	end
	table.sort(picked)
	local fc, fs = BIS.GetFilter()
	if boss == 0 and state == "loading" then
		return tostring(raid) .. ":0:" .. fc .. "/" .. fs .. ":loading"
	end
	-- Difficulty versions found: a late item name adds one (e.g. the Heroic
	-- version of an item already listed), and the page must show it.
	local versions = 0
	for _, it in ipairs(items) do
		for _ in pairs(it.byDiff) do
			versions = versions + 1
		end
	end
	shownLootKey = tostring(raid) .. ":" .. tostring(boss) .. ":" .. fc .. "/" .. fs .. ":" .. state .. ":" .. #items .. ":" .. versions .. ":" .. table.concat(picked, "\1")
	return shownLootKey
end

PAGES = {
	{
		key = "loot",
		name = "Loot",
		description = "Pick the items you want from each raid boss. When you kill that boss, a list shows what you are after.",
		pageKey = LootKey,
		build = function(p)
			if not BIS.HasEJ() then
				p:Paragraph("This client has no Encounter Journal data, so the loot cannot be listed.")
				return
			end
			local raid = SelectedRaid()
			local boss = raid and SelectedBoss(raid)
			p:Section("Raid & Boss")
			p:Dropdown("Raid", "Raids of Mists of Pandaria, from the Encounter Journal.",
				RaidItems,
				function() return SelectedRaid() end,
				function() return BIS.RaidName(SelectedRaid()) or "Select a raid" end,
				function(v)
					DB().selRaid = v
					DB().selBoss = nil
					ns.RebuildSettingsPage()
				end)
			p:Dropdown("Boss", "All Bosses shows the loot of the whole raid. The number in brackets is how many items you picked from that boss.",
				BossItems,
				function() return SelectedBoss(SelectedRaid()) end,
				function() return BossName(SelectedRaid(), SelectedBoss(SelectedRaid())) or "Select a boss" end,
				function(v)
					DB().selRaid = SelectedRaid()
					DB().selBoss = v
					ns.RebuildSettingsPage()
				end)
			p:Dropdown("Class / Spec", "Shows only the loot of a class or spec, like the Dungeon Journal filter. Items you picked stay picked when they are filtered out.",
				BIS.FilterItems,
				function() local c, sp = BIS.GetFilter(); return c .. ":" .. sp end,
				BIS.FilterLabel,
				function(v)
					local c, sp = tostring(v):match("^(%d+):(%d+)$")
					BIS.SetFilter(tonumber(c) or 0, tonumber(sp) or 0)
					ns.RebuildSettingsPage()
				end)
			if not raid or not boss then
				p:Paragraph("The Encounter Journal has not listed the raids yet. Open this page again in a moment.")
				return
			end
			p:Section("Loot")
			if type(p.child) ~= "table" then
				return -- search index (no frames)
			end
			BuildLootList(p, raid, boss)
		end,
	},
	{
		key = "list",
		name = "My List",
		description = "Everything you picked, by boss. Click a boss to edit it on the Loot tab.",
		pageKey = function() return BIS.ListVersion() end,
		build = function(p)
			p:Section("Picked Items")
			if type(p.child) ~= "table" then
				return
			end
			BuildWishList(p)
			p:Section("Manage")
			p:Button("Clear My List", "Removes every picked item of this character.", "Clear", function()
				if ns.ShowConfirmPopup then
					ns.ShowConfirmPopup({
						title = "Clear My List",
						message = "Remove every picked item of this character?",
						confirmText = "Clear",
						cancelText = "Cancel",
						onConfirm = function() BIS.ClearAll() end,
					})
				else
					BIS.ClearAll()
				end
			end)
		end,
	},
	{
		key = "settings",
		name = "Settings",
		description = "The list that shows when you kill a boss you picked items from.",
		build = function(p)
			p:Section("Boss Kill List")
			p:Toggle("Show List on Kill", "When you kill a boss on a difficulty you picked items for, a small window lists them.",
				function() return DB().popup end,
				function(v) DB().popup = v and true or false end)
			p:Toggle("Print to Chat", "Also prints the wanted items (as links) to your chat window.",
				function() return DB().chat end,
				function(v) DB().chat = v and true or false end)
			p:Toggle("Glow Wanted Loot", "A gold glow around an item on your list in the loot roll popup and the loot window.",
				function() return DB().lootGlow end,
				function(v)
					DB().lootGlow = v and true or false
					BIS.UpdateLootGlows()
				end)
			p:Slider("Hide After (sec)", "Closes the list by itself after this many seconds (0 = stays until you close it).",
				0, 120, 5,
				function() return DB().autoHide or 0 end,
				function(v) DB().autoHide = v end,
				function() return not DB().popup end)
			p:Slider("Scale", nil, 0.5, 2, 0.05,
				function() return DB().scale or 1 end,
				function(v) DB().scale = v; BIS.ApplyLook() end,
				function() return not DB().popup end)
			p:Slider("Opacity", nil, 0.2, 1, 0.05,
				function() return DB().alpha or 1 end,
				function(v) DB().alpha = v; BIS.ApplyLook() end,
				function() return not DB().popup end)
			p:Section("Tools")
			p:Button("Preview", "Shows the list as it looks after a kill (your first picked boss). Drag it to move it.", "Show", function()
				BIS.TestPopup()
			end)
			p:Button("Position", "Puts the list back at the top of the screen.", "Reset Position", function()
				BIS.ResetPosition()
			end)
		end,
	},
}

-- Rebuild the open page when its data changed.
BIS.OnLootData = function()
	-- Only while this boss's loot is still loading (item info also arrives
	-- for tooltips; a rebuild then would re-sort the rows under the mouse).
	if ActiveTab() ~= 1 or not ns.RebuildSettingsPage then
		return
	end
	local raid = SelectedRaid()
	local boss = raid and SelectedBoss(raid)
	local cached = boss and BIS.LootState and BIS.LootState(boss, raid)
	if cached == "ok" or cached == "empty" then
		return
	end
	if cached == "partial" then
		-- Gave up waiting, but names can still come in: rebuild only when
		-- that changed the list (new item or difficulty version).
		local before = shownLootKey
		if LootKey() == before then
			return
		end
	end
	ns.RebuildSettingsPage()
end
BIS.OnListChanged = function()
	local tab = ActiveTab()
	if tab == 2 and ns.RebuildSettingsPage then
		ns.RebuildSettingsPage()
	end
end

ns.RegisterSettingsModule({
	key = "bisTracker",
	name = "BIS Tracker",
	group = "QoL Addons",
	tabs = PAGES,
	reset = function() BIS.ResetSettings() end,
	resetTip = "Set the BIS Tracker settings back to default. Your picked items are kept.",
})
