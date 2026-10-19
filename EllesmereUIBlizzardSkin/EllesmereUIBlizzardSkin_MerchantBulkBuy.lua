-------------------------------------------------------------------------------
--  EllesmereUIBlizzardSkin_MerchantBulkBuy.lua (5.4.8 port of retail
--  EllesmereUIBlizzardSkin_MerchantBulkBuy.lua)
--  Merchant Bulk Buy (merchantBulkBuy, off by default, independent of the
--  merchant skin): shift-clicking a vendor item opens a quantity dialog that
--  can buy past a single stack, in grid and list mode.
--    - Post-hooks MerchantItemButton_OnModifiedClick and hides the stock
--      StackSplitFrame; no keys written on Blizzard frames. Hooks install on
--      the first enable only.
--    - Buys in chunks of GetMerchantItemMaxStack, sending the next chunk only
--      after BAG_UPDATE_DELAYED shows the previous one landed; stops on
--      MERCHANT_CLOSED, UI_ERROR_MESSAGE or when the item count drops.
--    - Max is capped by bag room, stock, gold and item / currency costs;
--      +1 Stack adds one full stack per click.
--    - Extended-cost purchases and gold totals at or above
--      MERCHANT_HIGH_PRICE_COST ask first.
--  5.4.8: GetMerchantItemInfo instead of C_MerchantFrame, the item ID read
--  from the item link, the bag API without C_Container, and a StaticPopup
--  for the confirmation (the settings window loads on demand).
-------------------------------------------------------------------------------
local ns = EllesmereUI
local BS = ns.BlizzSkin
local WSkin = ns.WSkin
if not (BS and WSkin) then
	return
end

local Theme = WSkin.Theme
local floor, min, max = math.floor, math.min, math.max
local band = bit.band
local tonumber, tostring, select = tonumber, tostring, select

local events = CreateFrame("Frame")
local dialog, job, hooked

local function Enabled()
	return BS.DB().merchantBulkBuy == true
end

local function Font(fs, size)
	fs:SetFont(Theme.fontPath, size, Theme.fontFlag or "")
	if Theme.fontShadow then
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 1)
	else
		fs:SetShadowOffset(0, 0)
	end
end

local function MerchantItemID(index)
	local link = GetMerchantItemLink(index)
	local id = link and link:match("item:(%d+)")
	return id and tonumber(id)
end

local function BagRoom(itemID, fallbackStack)
	local stackSize = select(8, GetItemInfo(itemID)) or fallbackStack or 1
	local family = GetItemFamily(itemID) or 0
	local room = 0
	for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
		local _, bagFamily = GetContainerNumFreeSlots(bag)
		if not bagFamily or bagFamily == 0 or band(bagFamily, family) ~= 0 then
			for slot = 1, GetContainerNumSlots(bag) do
				local id = GetContainerItemID(bag, slot)
				if not id then
					room = room + stackSize
				elseif id == itemID then
					local _, count = GetContainerItemInfo(bag, slot)
					room = room + max(stackSize - (count or stackSize), 0)
				end
			end
		end
	end
	return room
end

local function MerchantInfo(index)
	local name, _, price, quantity, numAvailable, _, extendedCost = GetMerchantItemInfo(index)
	if not name then
		return nil
	end
	return { name = name, price = price or 0, stackCount = quantity or 1,
		numAvailable = numAvailable or -1, hasExtendedCost = extendedCost and true or false }
end

local function MaxBundles(index, info, itemID, step)
	local n = floor(min(BagRoom(itemID, step), 999999) / step)
	if info.numAvailable >= 0 then n = min(n, info.numAvailable) end
	if info.price > 0 then n = min(n, floor(GetMoney() / info.price)) end
	for i = 1, GetMerchantItemCostInfo(index) or 0 do
		local _, value, link = GetMerchantItemCostItem(index, i)
		if link and value and value > 0 then
			local have
			local currencyID = link:match("currency:(%d+)")
			if currencyID then
				have = select(2, GetCurrencyInfo(tonumber(currencyID)))
			else
				have = GetItemCount(link)
			end
			if have then n = min(n, floor(have / value)) end
		end
	end
	return max(n, 0)
end

local function CostText(index, info, bundles)
	local parts = {}
	if info.price > 0 then
		parts[#parts + 1] = GetCoinTextureString(info.price * bundles)
	end
	for i = 1, GetMerchantItemCostInfo(index) or 0 do
		local texture, value = GetMerchantItemCostItem(index, i)
		if texture and value and value > 0 then
			parts[#parts + 1] = (value * bundles) .. " |T" .. texture .. ":0|t"
		end
	end
	return table.concat(parts, "  ")
end

local function SyncEvents()
	if job or (dialog and dialog:IsShown()) then
		events:RegisterEvent("MERCHANT_CLOSED")
	else
		events:UnregisterEvent("MERCHANT_CLOSED")
	end
	if job then
		events:RegisterEvent("BAG_UPDATE_DELAYED")
		events:RegisterEvent("UI_ERROR_MESSAGE")
	else
		events:UnregisterEvent("BAG_UPDATE_DELAYED")
		events:UnregisterEvent("UI_ERROR_MESSAGE")
	end
end

local function StopJob()
	job = nil
	SyncEvents()
end

local function StepJob()
	local j = job
	if not j then return end
	local count = GetItemCount(j.itemID)
	if count < j.last then StopJob(); return end
	j.last = count
	local got = count - j.base
	if got < j.issued then return end
	local n = floor(min(j.chunk, j.target - got) / j.step) * j.step
	if n <= 0 or MerchantItemID(j.index) ~= j.itemID then StopJob(); return end
	j.issued = got + n
	BuyMerchantItem(j.index, n)
end

local function StartJob(index, itemID, qty, step, chunk)
	if MerchantItemID(index) ~= itemID then return end
	local count = GetItemCount(itemID)
	job = { index = index, itemID = itemID, target = qty, step = step, chunk = chunk,
		base = count, last = count, issued = 0 }
	SyncEvents()
	StepJob()
end

local function Current()
	local d = dialog
	local n = floor((d._eb:GetNumber() or 0) / d._step) * d._step
	return min(max(n, d._step), d._max)
end

local function ShowCost(qty)
	local d = dialog
	d._cost:SetText("Total: " .. CostText(d._index, d._info, qty / d._step))
	if qty > 0 then d._buy:Enable() else d._buy:Disable() end
	d._buy:SetAlpha(qty > 0 and 1 or 0.3)
end

local function SetValue(n)
	local d = dialog
	n = floor(n / d._step) * d._step
	n = min(max(n, d._step), d._max)
	d._eb:SetText(tostring(n))
	d._eb:SetCursorPosition(#d._eb:GetText())
	ShowCost(n)
end

local function Refresh()
	local d = dialog
	local index, owner = d._index, d._owner
	local info = (MerchantFrame.selectedTab or 1) == 1 and MerchantInfo(index)
	if not info or MerchantItemID(index) ~= d._itemID or not owner:IsVisible() or owner:GetID() ~= index then
		d:Hide()
		return
	end
	d._info = info
	d._step = max(info.stackCount, 1)
	d._max = MaxBundles(index, info, d._itemID, d._step) * d._step
	d._maxLbl:SetText("/ " .. d._max)
	if d._eb:HasFocus() and d._eb:GetNumber() <= d._max then
		ShowCost(Current())
	else
		SetValue(Current())
	end
end

StaticPopupDialogs["EUI_MERCHANT_BULK_BUY"] = {
	text = "Buy %s?",
	button1 = "Buy",
	button2 = CANCEL,
	OnAccept = function(_, data)
		if data then StartJob(data.index, data.itemID, data.qty, data.step, data.chunk) end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

local function DoBuy()
	local d = dialog
	local qty = Current()
	local index, itemID, step, chunk, info = d._index, d._itemID, d._step, d._chunk, d._info
	d:Hide()
	if qty < step then return end
	local bundles = qty / step
	if info.hasExtendedCost or info.price * bundles >= (MERCHANT_HIGH_PRICE_COST or 1500000) then
		local what = qty .. " x " .. (GetMerchantItemLink(index) or info.name or "") .. " for " .. CostText(index, info, bundles)
		local popup = StaticPopup_Show("EUI_MERCHANT_BULK_BUY", what)
		if popup then
			popup.data = { index = index, itemID = itemID, qty = qty, step = step, chunk = chunk }
		end
	else
		StartJob(index, itemID, qty, step, chunk)
	end
end

local function AddStack()
	local d = dialog
	local cur = Current()
	local n = (floor(cur / d._stackSize) + 1) * d._stackSize
	if floor(n / d._step) * d._step <= cur then n = cur + d._step end
	SetValue(n)
end

local function Nudge(dir)
	local d = dialog
	SetValue(Current() + dir * (IsShiftKeyDown() and d._chunk or d._step))
end

local function MakeButton(parent, w, h, label)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, h)
	WSkin.Button(b)
	local fs = b:CreateFontString(nil, "OVERLAY")
	Font(fs, 12)
	fs:SetPoint("CENTER", 0, 0)
	fs:SetTextColor(1, 1, 1, 0.9)
	fs:SetText(label)
	b._lbl = fs
	return b
end

local function CreateDialog()
	if not Theme.fontPath then WSkin.ResolveTheme() end
	local d = CreateFrame("Frame", "EUI_MerchantBulkBuyFrame", UIParent)
	d:SetFrameStrata("DIALOG")
	d:SetSize(232, 121)
	d:SetClampedToScreen(true)
	d:EnableMouse(true)
	d:EnableMouseWheel(true)
	d:Hide()
	WSkin.SolidTex(d, "BACKGROUND", Theme.bgR, Theme.bgG, Theme.bgB, 1):SetAllPoints()
	WSkin.AddBorder(d)

	local title = d:CreateFontString(nil, "OVERLAY")
	Font(title, 13)
	title:SetPoint("TOPLEFT", d, "TOPLEFT", 10, -9)
	title:SetTextColor(1, 1, 1, 0.9)
	title:SetText("Bulk Buy")

	local close = CreateFrame("Button", nil, d)
	close:SetSize(18, 18)
	close:SetPoint("TOPRIGHT", d, "TOPRIGHT", -4, -5)
	WSkin.CloseButton(close)
	close:SetScript("OnClick", function() d:Hide() end)

	local minus = MakeButton(d, 22, 22, "-")
	minus:SetPoint("TOPLEFT", d, "TOPLEFT", 10, -30)
	minus:SetScript("OnClick", function() Nudge(-1) end)

	local eb = CreateFrame("EditBox", nil, d)
	eb:SetSize(64, 22)
	eb:SetPoint("LEFT", minus, "RIGHT", 4, 0)
	eb:SetAutoFocus(false)
	eb:SetNumeric(true)
	eb:SetMaxLetters(6)
	eb:SetFont(Theme.fontPath, 12, "")
	eb:SetTextColor(1, 1, 1, 1)
	eb:SetJustifyH("CENTER")
	eb:SetTextInsets(4, 4, 0, 0)
	WSkin.EditBox(eb, { inset = { 0, 0, 0, 0 } })
	eb:SetScript("OnTextChanged", function(self, userInput)
		if not userInput then return end
		if self:GetNumber() > d._max then SetValue(d._max) else ShowCost(Current()) end
	end)
	eb:SetScript("OnEditFocusLost", function()
		if d:IsShown() then SetValue(Current()) end
	end)
	eb:SetScript("OnEnterPressed", DoBuy)
	eb:SetScript("OnEscapePressed", function() d:Hide() end)
	d._eb = eb

	local plus = MakeButton(d, 22, 22, "+")
	plus:SetPoint("LEFT", eb, "RIGHT", 4, 0)
	plus:SetScript("OnClick", function() Nudge(1) end)

	local maxLbl = d:CreateFontString(nil, "OVERLAY")
	Font(maxLbl, 12)
	maxLbl:SetPoint("LEFT", plus, "RIGHT", 8, 0)
	maxLbl:SetTextColor(0.7, 0.7, 0.7, 1)
	d._maxLbl = maxLbl

	local cost = d:CreateFontString(nil, "OVERLAY")
	Font(cost, 12)
	cost:SetPoint("TOPLEFT", minus, "BOTTOMLEFT", 0, -9)
	cost:SetPoint("RIGHT", d, "RIGHT", -10, 0)
	cost:SetJustifyH("LEFT")
	cost:SetWordWrap(false)
	cost:SetTextColor(1, 1, 1, 0.9)
	d._cost = cost

	local stackBtn = MakeButton(d, 66, 27, "+1 Stack")
	stackBtn:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 10, 10)
	stackBtn:SetScript("OnClick", AddStack)

	local maxBtn = MakeButton(d, 66, 27, "Max")
	maxBtn:SetPoint("BOTTOM", d, "BOTTOM", 0, 10)
	maxBtn:SetScript("OnClick", function() SetValue(d._max) end)

	local buy = MakeButton(d, 66, 27, "Buy")
	buy:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -10, 10)
	buy:SetScript("OnClick", DoBuy)
	d._buy = buy

	d:SetScript("OnMouseWheel", function(_, delta) Nudge(delta > 0 and 1 or -1) end)
	d:SetScript("OnShow", SyncEvents)
	d:SetScript("OnHide", function()
		eb:ClearFocus()
		SyncEvents()
	end)
	tinsert(UISpecialFrames, "EUI_MerchantBulkBuyFrame")
	return d
end

local function Validate()
	if dialog and dialog:IsShown() then Refresh() end
end

local function TakeOver(button)
	if not Enabled() then return end
	local ssf = StackSplitFrame
	if not ssf or not ssf:IsShown() or ssf.owner ~= button then return end
	local index = button:GetID()
	local itemID = index and MerchantItemID(index)
	local info = itemID and MerchantInfo(index)
	if not info then return end
	ssf:Hide()
	dialog = dialog or CreateDialog()
	local step = max(info.stackCount, 1)
	dialog._owner, dialog._index, dialog._itemID = button, index, itemID
	dialog._chunk = max(floor((GetMerchantItemMaxStack(index) or step) / step) * step, step)
	dialog._stackSize = max(select(8, GetItemInfo(itemID)) or step, 1)
	dialog._eb:SetText(tostring(step))
	local r, g, b = BS.Accent()
	dialog._buy._lbl:SetTextColor(r, g, b, 1)
	dialog:ClearAllPoints()
	dialog:SetPoint("BOTTOMLEFT", button, "TOPLEFT", -4, 6)
	dialog:Show()
	Refresh()
	if not dialog:IsShown() then return end
	dialog._eb:SetFocus()
	dialog._eb:HighlightText()
end

local function Install()
	if hooked then return end
	hooked = true
	if type(MerchantItemButton_OnModifiedClick) == "function" then
		hooksecurefunc("MerchantItemButton_OnModifiedClick", TakeOver)
	end
	if type(MerchantFrame_Update) == "function" then
		hooksecurefunc("MerchantFrame_Update", Validate)
	end
end

ns._Merchant_RefreshBulkBuy = function()
	if Enabled() then
		Install()
		return
	end
	if dialog then dialog:Hide() end
	StopJob()
end

events:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		self:UnregisterEvent("PLAYER_LOGIN")
		if Enabled() then Install() end
	elseif event == "BAG_UPDATE_DELAYED" then
		StepJob()
	elseif event == "MERCHANT_CLOSED" then
		if dialog then dialog:Hide() end
		StopJob()
	else
		StopJob()
	end
end)
events:RegisterEvent("PLAYER_LOGIN")
