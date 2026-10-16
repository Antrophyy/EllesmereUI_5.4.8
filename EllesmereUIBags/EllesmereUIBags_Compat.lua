-------------------------------------------------------------------------------
--  EllesmereUIBags_Compat.lua (5.4.8 port)
--  The retail EllesmereUI Bags files run on Mists of Pandaria through this
--  file. It builds a private environment (ns.env) that every other file of
--  this addon uses as its global table (setfenv on line 1): reads fall back to
--  the real _G, writes go to the real _G. In it, the retail APIs the bag code
--  calls (C_Container, C_Item, C_Timer, ItemLocation, Enum, C_Bank, MenuUtil,
--  ...) are rebuilt with the 5.4.8 API, and "EllesmereUI" is a proxy of the
--  core table that adds the retail framework helpers the bags need (popups,
--  widget tooltip, pixel borders, Lite DB, L/Lf, ...). Nothing here is written
--  into the real globals, so other addons never see these shims.
-------------------------------------------------------------------------------
local addonName, ns = ...
local Core = EllesmereUI

local _G = _G
local type, pairs, ipairs, select, tonumber, tostring = type, pairs, ipairs, select, tonumber, tostring
local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local wipe = wipe

-- Filled while this file runs; the metatable (reads -> _G, writes -> _G) is
-- set at the end, so nothing below leaks into the real globals.
local env = {}
ns.env = env
Core._bagsEnv = env

local function noop() end
env.noop = noop

local MEDIA = "Interface\\AddOns\\EllesmereUIBags\\Media\\"
ns.MEDIA = MEDIA

-------------------------------------------------------------------------------
--  Small globals the retail code expects
-------------------------------------------------------------------------------
env.Clamp = function(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end
env.tIndexOf = function(t, value)
	for i = 1, #t do
		if t[i] == value then return i end
	end
	return nil
end
env.securecallfunction = securecall or function(fn, ...) return fn(...) end
env.IsKeyDown = function(key)
	if key == "LSHIFT" then return IsLeftShiftKeyDown() end
	if key == "RSHIFT" then return IsRightShiftKeyDown() end
	if key == "LCTRL" then return IsLeftControlKeyDown() end
	if key == "LALT" then return IsLeftAltKeyDown() end
	return false
end
-- Retail-only systems the bag code tests for (false = not in 5.4.8).
env.C_PlayerInteractionManager = false
env.EventRegistry = false
env.EventUtil = false
env.C_ChallengeMode = false

-- Sound names of 5.4.8 PlaySound (strings, not kit IDs).
env.SOUNDKIT = {
	IG_BACKPACK_OPEN = "igBackPackOpen",
	IG_BACKPACK_CLOSE = "igBackPackClose",
	UI_BAG_SORTING_01 = "igMainMenuOptionCheckBoxOn",
}

-------------------------------------------------------------------------------
--  C_Timer.After (5.4.8 has no C_Timer)
-------------------------------------------------------------------------------
do
	local timers = {}
	local driver = CreateFrame("Frame")
	driver:Hide()
	local now = 0
	driver:SetScript("OnUpdate", function(self, elapsed)
		now = now + elapsed
		local i = 1
		while i <= #timers do
			local t = timers[i]
			if t.at <= now then
				table.remove(timers, i)
				local ok, err = pcall(t.fn)
				if not ok then geterrorhandler()(err) end
			else
				i = i + 1
			end
		end
		if #timers == 0 then self:Hide() end
	end)
	env.C_Timer = {
		After = function(delay, fn)
			timers[#timers + 1] = { at = now + (delay or 0), fn = fn }
			driver:Show()
		end,
	}
end
local C_Timer = env.C_Timer

-------------------------------------------------------------------------------
--  Item classes. 5.4.8 GetItemInfo returns localized type strings only, so
--  they are mapped to the retail Enum.ItemClass / subclass numbers.
-------------------------------------------------------------------------------
local IC = {
	Consumable = 0, Container = 1, Weapon = 2, Gem = 3, Armor = 4, Reagent = 5,
	Projectile = 6, Tradegoods = 7, ItemEnhancement = 8, Recipe = 9, Quiver = 11,
	Questitem = 12, Key = 13, Miscellaneous = 15, Glyph = 16, Battlepet = 17,
}
env.Enum = {
	ItemClass = IC,
	ItemBind = {
		None = 0, OnAcquire = 1, OnEquip = 2, OnUse = 3, Quest = 4,
		ToWoWAccount = 7, ToBnetAccount = 8, ToBnetAccountUntilEquipped = 9,
	},
	ItemWeaponSubclass = { Bow = 2, Gun = 3, Crossbow = 18, Wand = 19 },
	ItemArmorSubclass = {},
	BankType = { Character = 0, Account = 2 },
	BagSlotFlags = {},
}

local CLASS_BY_NAME = {
	["Consumable"] = 0, ["Container"] = 1, ["Weapon"] = 2, ["Gem"] = 3, ["Armor"] = 4,
	["Reagent"] = 5, ["Projectile"] = 6, ["Trade Goods"] = 7, ["Item Enhancement"] = 8,
	["Recipe"] = 9, ["Quiver"] = 11, ["Quest"] = 12, ["Key"] = 13, ["Miscellaneous"] = 15,
	["Glyph"] = 16, ["Battle Pets"] = 17,
}
local WEAPON_SUB_BY_NAME = {
	["One-Handed Axes"] = 0, ["Two-Handed Axes"] = 1, ["Bows"] = 2, ["Guns"] = 3,
	["One-Handed Maces"] = 4, ["Two-Handed Maces"] = 5, ["Polearms"] = 6,
	["One-Handed Swords"] = 7, ["Two-Handed Swords"] = 8, ["Staves"] = 10,
	["Fist Weapons"] = 13, ["Miscellaneous"] = 14, ["Daggers"] = 15, ["Thrown"] = 16,
	["Crossbows"] = 18, ["Wands"] = 19, ["Fishing Poles"] = 20,
}
local ARMOR_SUB_BY_NAME = {
	["Miscellaneous"] = 0, ["Cloth"] = 1, ["Leather"] = 2, ["Mail"] = 3, ["Plate"] = 4,
	["Shields"] = 6, ["Librams"] = 7, ["Idols"] = 8, ["Totems"] = 9, ["Sigils"] = 10, ["Relic"] = 11,
}
-- Localized names: the auction house lists keep the same order on every locale.
do
	local ok, list = pcall(function() return { GetAuctionItemClasses() } end)
	local ORDER = { 2, 4, 1, 0, 16, 7, 9, 3, 15, 12, 17 }
	if ok and list then
		for i, name in ipairs(list) do
			if ORDER[i] and CLASS_BY_NAME[name] == nil then CLASS_BY_NAME[name] = ORDER[i] end
		end
	end
	local okW, weapons = pcall(function() return { GetAuctionItemSubClasses(1) } end)
	local WORDER = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 14, 15, 16, 18, 19, 20 }
	if okW and weapons then
		for i, name in ipairs(weapons) do
			if WORDER[i] and WEAPON_SUB_BY_NAME[name] == nil then WEAPON_SUB_BY_NAME[name] = WORDER[i] end
		end
	end
end
ns.CLASS_BY_NAME = CLASS_BY_NAME

local function ClassIDs(itemType, subType)
	local classID = itemType and CLASS_BY_NAME[itemType]
	if classID == nil then
		if itemType then classID = IC.Miscellaneous else return nil, nil end
	end
	local subclassID
	if classID == IC.Weapon then
		subclassID = subType and WEAPON_SUB_BY_NAME[subType]
	elseif classID == IC.Armor then
		subclassID = subType and ARMOR_SUB_BY_NAME[subType]
	end
	-- Enchant scrolls and armor kits: the retail "Item Enhancement" class.
	if subType == "Item Enhancement" and (classID == IC.Tradegoods or classID == IC.Consumable) then
		classID = IC.ItemEnhancement
	end
	return classID, subclassID
end

-------------------------------------------------------------------------------
--  Scanning tooltip (item level, bind state, upgrade level, red text)
-------------------------------------------------------------------------------
local scanTip = CreateFrame("GameTooltip", "EUIBagsScanTooltip", nil, "GameTooltipTemplate")
scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
local scanLines = {}

-- setter: a GameTooltip method name; returns the number of lines read.
local function Scan(setter, a, b)
	scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
	scanTip:ClearLines()
	local ok = pcall(scanTip[setter], scanTip, a, b)
	if not ok then return 0 end
	local n = scanTip:NumLines() or 0
	for i = 1, n do
		local L = scanLines[i]
		if not L then L = {}; scanLines[i] = L end
		local left = _G["EUIBagsScanTooltipTextLeft" .. i]
		local right = _G["EUIBagsScanTooltipTextRight" .. i]
		L.left = left and left:GetText()
		if left then L.lr, L.lg, L.lb = left:GetTextColor() else L.lr, L.lg, L.lb = 1, 1, 1 end
		L.right = right and right:IsShown() and right:GetText() or nil
		if right then L.rr, L.rg, L.rb = right:GetTextColor() else L.rr, L.rg, L.rb = 1, 1, 1 end
	end
	return n
end

local function Pattern(fmt)
	if not fmt then return nil end
	fmt = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
	fmt = fmt:gsub("%%d", "(%%d+)")
	fmt = fmt:gsub("%%s", "(.+)")
	return "^" .. fmt .. "$"
end
local ITEM_LEVEL_PAT = Pattern(ITEM_LEVEL or "Item Level %d")
local UPGRADE_PAT = Pattern(ITEM_UPGRADE_TOOLTIP_FORMAT or "Upgrade Level: %d/%d")

local BIND_LINES
local function BindLines()
	if BIND_LINES then return BIND_LINES end
	local E = env.Enum.ItemBind
	BIND_LINES = {}
	local function add(text, v) if text then BIND_LINES[text] = v end end
	add(ITEM_BIND_ON_PICKUP, E.OnAcquire)
	add(ITEM_BIND_ON_EQUIP, E.OnEquip)
	add(ITEM_BIND_ON_USE, E.OnUse)
	add(ITEM_BIND_QUEST, E.Quest)
	add(ITEM_BIND_TO_ACCOUNT, E.ToWoWAccount)
	add(ITEM_BIND_TO_BNETACCOUNT, E.ToBnetAccount)
	add(ITEM_BNETACCOUNTBOUND, E.ToBnetAccount)
	add(ITEM_ACCOUNTBOUND, E.ToWoWAccount)
	return BIND_LINES
end

-- Static facts of an item (bind type), cached by item ID.
local bindCache = {}
local function LinkBindType(link)
	local id = link and tonumber(link:match("item:(%d+)"))
	if not id then return 0 end
	local v = bindCache[id]
	if v ~= nil then return v end
	local n = Scan("SetHyperlink", link)
	-- Item data not loaded yet ("Retrieving item information"): ask again later.
	if n < 2 then return 0 end
	local map = BindLines()
	v = 0
	for i = 2, min(n, 6) do
		local t = scanLines[i].left
		if t and map[t] then v = map[t]; break end
	end
	bindCache[id] = v
	return v
end

-- Item level and upgrade text of a link (the tooltip shows the upgraded
-- level; 5.4.8 GetItemInfo has the base level only). Cached by link.
local levelCache, levelCacheN = {}, 0
local function LinkLevelInfo(link, bag, slot)
	local c = levelCache[link]
	if c then return c[1], c[2], c[3], c[4] end
	local n
	if bag and slot then n = Scan("SetBagItem", bag, slot) end
	if not n or n == 0 then n = Scan("SetHyperlink", link) end
	local ilvl, cur, maxL
	for i = 2, min(n, 8) do
		local t = scanLines[i].left
		if t then
			if not ilvl then ilvl = tonumber(t:match(ITEM_LEVEL_PAT)) end
			if not cur and UPGRADE_PAT then
				local a, b = t:match(UPGRADE_PAT)
				if a then cur, maxL = tonumber(a), tonumber(b) end
			end
		end
	end
	if n > 0 then
		if levelCacheN > 4000 then wipe(levelCache); levelCacheN = 0 end
		levelCache[link] = { ilvl or false, cur or false, maxL or false }
		levelCacheN = levelCacheN + 1
	end
	return ilvl, cur, maxL
end

-- Soulbound state of the item in a bag slot (changes when a BoE is equipped).
local function SlotIsBound(bag, slot)
	local n = Scan("SetBagItem", bag, slot)
	if n == 0 and bag == BANK_CONTAINER then
		n = Scan("SetInventoryItem", "player", BankButtonIDToInvSlotID(slot))
	end
	for i = 2, min(n, 6) do
		local t = scanLines[i].left
		if t and (t == ITEM_SOULBOUND or t == ITEM_ACCOUNTBOUND or t == ITEM_BNETACCOUNTBOUND
			or t == ITEM_BIND_ON_PICKUP or t == ITEM_BIND_QUEST) then
			return true
		end
	end
	return false
end

-------------------------------------------------------------------------------
--  GetItemInfo / GetItemInfoInstant in the retail shape
-------------------------------------------------------------------------------
local rawGetItemInfo = GetItemInfo

local function ExpansionGuess(itemID, reqLevel)
	if reqLevel and reqLevel >= 86 then return 4 end
	if reqLevel and reqLevel >= 81 then return 3 end
	if reqLevel and reqLevel >= 71 then return 2 end
	if reqLevel and reqLevel >= 61 then return 1 end
	if not itemID then return nil end
	if itemID < 23000 then return 0 end
	if itemID < 34000 then return 1 end
	if itemID < 52000 then return 2 end
	if itemID < 72000 then return 3 end
	return 4
end

local function BattlePetInfo(link)
	local species, level, quality = link:match("battlepet:(%d+):(%d+):(%d+)")
	local name = link:match("%[(.-)%]")
	local icon = species and C_PetJournal and C_PetJournal.GetPetInfoBySpeciesID
		and select(2, C_PetJournal.GetPetInfoBySpeciesID(tonumber(species)))
	return name or "", tonumber(quality) or 1, tonumber(level) or 1, icon or "Interface\\Icons\\INV_Box_PetCarrier_01"
end

-- name, link, quality, ilvl, reqLevel, type, subType, maxStack, equipLoc, icon,
-- sellPrice, classID, subclassID, bindType, expacID
local function GetItemInfoRetail(item)
	if item == nil then return nil end
	if type(item) == "string" and item:find("battlepet:", 1, true) then
		local name, quality, level, icon = BattlePetInfo(item)
		return name, item, quality, level, 0, "Battle Pets", "Companion Pets", 1, "", icon, 0,
			IC.Miscellaneous, 2, 0, 4
	end
	local name, link, quality, ilvl, reqLevel, itemType, subType, maxStack, equipLoc, icon, sellPrice = rawGetItemInfo(item)
	if not name then return nil end
	local classID, subclassID = ClassIDs(itemType, subType)
	local id = link and tonumber(link:match("item:(%d+)"))
	return name, link, quality, ilvl, reqLevel, itemType, subType, maxStack, equipLoc, icon, sellPrice,
		classID, subclassID, LinkBindType(link), ExpansionGuess(id, reqLevel)
end
env.GetItemInfo = GetItemInfoRetail

local function ItemIDOf(item)
	if type(item) == "number" then return item end
	if type(item) ~= "string" then return nil end
	if item:find("battlepet:", 1, true) then return 82800 end
	return tonumber(item:match("item:(%d+)")) or tonumber(item)
end

-- itemID, type, subType, equipLoc, icon, classID, subclassID
local function GetItemInfoInstant(item)
	local id = ItemIDOf(item)
	if not id then return nil end
	if type(item) == "string" and item:find("battlepet:", 1, true) then
		local _, _, _, icon = BattlePetInfo(item)
		return 82800, "Battle Pets", "Companion Pets", "", icon, IC.Miscellaneous, 2
	end
	local _, _, _, _, _, itemType, subType, _, equipLoc, icon = rawGetItemInfo(item)
	if not itemType then return id end
	local classID, subclassID = ClassIDs(itemType, subType)
	return id, itemType, subType, equipLoc, icon, classID, subclassID
end
env.GetItemInfoInstant = GetItemInfoInstant

-------------------------------------------------------------------------------
--  ItemLocation
-------------------------------------------------------------------------------
local LocationMT = {}
LocationMT.__index = LocationMT
function LocationMT:IsValid() return self.bag ~= nil and self.slot ~= nil end
function LocationMT:SetBagAndSlot(bag, slot) self.bag, self.slot = bag, slot end
function LocationMT:GetBagAndSlot() return self.bag, self.slot end
function LocationMT:IsBagAndSlot() return self.bag ~= nil end
env.ItemLocation = {
	CreateFromBagAndSlot = function(_, bag, slot) return setmetatable({ bag = bag, slot = slot }, LocationMT) end,
	CreateEmpty = function() return setmetatable({}, LocationMT) end,
}

-------------------------------------------------------------------------------
--  C_Container
-------------------------------------------------------------------------------
local rawGetContainerItemInfo = GetContainerItemInfo
local rawGetContainerItemLink = GetContainerItemLink

-- Fields 5.4.8 cannot return directly are read on first use.
local infoMT = {
	__index = function(t, k)
		local v
		if k == "isBound" then
			v = SlotIsBound(t._bag, t._slot)
		elseif k == "hasNoValue" then
			local link = t.hyperlink
			local price = link and select(11, rawGetItemInfo(link))
			v = not price or price == 0
		elseif k == "itemName" then
			local link = t.hyperlink
			if link and link:find("battlepet:", 1, true) then
				v = (BattlePetInfo(link))
			else
				v = link and rawGetItemInfo(link) or (link and link:match("%[(.-)%]")) or ""
			end
		else
			return nil
		end
		rawset(t, k, v)
		return v
	end,
}

local C_Container = {}
env.C_Container = C_Container

function C_Container.GetContainerItemInfo(bag, slot)
	local texture, count, locked, quality, readable, lootable, link, isFiltered = rawGetContainerItemInfo(bag, slot)
	if not texture then return nil end
	link = link or rawGetContainerItemLink(bag, slot)
	if (not quality or quality < 0) and link then
		if link:find("battlepet:", 1, true) then
			quality = select(2, BattlePetInfo(link))
		else
			quality = select(3, rawGetItemInfo(link))
		end
	end
	return setmetatable({
		_bag = bag, _slot = slot,
		iconFileID = texture,
		stackCount = count or 1,
		isLocked = locked and true or false,
		quality = quality or 1,
		isReadable = readable and true or false,
		hasLoot = lootable and true or false,
		hyperlink = link,
		isFiltered = isFiltered and true or false,
		itemID = ItemIDOf(link),
	}, infoMT)
end
C_Container.GetContainerItemLink = rawGetContainerItemLink
C_Container.GetContainerNumSlots = function(bag) return GetContainerNumSlots(bag) or 0 end
C_Container.GetContainerNumFreeSlots = function(bag) return GetContainerNumFreeSlots(bag) end
C_Container.GetContainerItemCooldown = function(bag, slot) return GetContainerItemCooldown(bag, slot) end
C_Container.PickupContainerItem = function(bag, slot) return PickupContainerItem(bag, slot) end
C_Container.SplitContainerItem = function(bag, slot, n) return SplitContainerItem(bag, slot, n) end
C_Container.UseContainerItem = function(bag, slot) return UseContainerItem(bag, slot) end
-- 5.4.8 throws "invalid container ID" for the backpack (0), bank (-1) and
-- keyring/other non-equippable containers; retail returns nil, so match that.
C_Container.ContainerIDToInventoryID = function(bag)
	if type(bag) ~= "number" or bag < 1 then return nil end
	local ok, invID = pcall(ContainerIDToInventoryID, bag)
	if ok then return invID end
	return nil
end
C_Container.SetItemSearch = function(text) return SetItemSearch(text or "") end
C_Container.GetContainerItemQuestInfo = function(bag, slot)
	local isQuestItem, questID, isActive = GetContainerItemQuestInfo(bag, slot)
	return { isQuestItem = isQuestItem and true or false, questID = questID, isActive = isActive and true or false }
end
-- Blizzard's own sort arrived in 6.0: SortBags / SortBank are emulated below
-- (ns.SortContainers); the sort direction is ours only.
C_Container.SetSortBagsRightToLeft = nil
C_Container.GetSortBagsRightToLeft = nil

-------------------------------------------------------------------------------
--  C_Item
-------------------------------------------------------------------------------
local C_Item = {}
env.C_Item = C_Item
C_Item.GetItemInfo = GetItemInfoRetail
C_Item.GetItemInfoInstant = GetItemInfoInstant
C_Item.GetItemQualityColor = function(q)
	if not q or q < 0 then q = 1 end
	return GetItemQualityColor(q)
end
C_Item.IsEquippableItem = function(item) return IsEquippableItem(item) end
C_Item.IsUsableItem = function(item) return IsUsableItem(item) end
C_Item.GetItemSpell = function(item) return GetItemSpell(item) end
C_Item.IsEquippedItem = function(item) return IsEquippedItem(item) end
C_Item.GetItemMaxStackSizeByID = function(id) return select(8, rawGetItemInfo(id)) end
C_Item.GetItemSubClassInfo = nil
C_Item.IsBoundToAccountUntilEquip = function() return false end
C_Item.DoesItemExist = function(loc)
	return loc and loc.bag and loc.slot and rawGetContainerItemLink(loc.bag, loc.slot) ~= nil or false
end
C_Item.IsLocked = function(loc)
	if not (loc and loc.bag) then return false end
	return select(3, rawGetContainerItemInfo(loc.bag, loc.slot)) and true or false
end
C_Item.GetCurrentItemLevel = function(loc)
	if not (loc and loc.bag) then return nil end
	local link = rawGetContainerItemLink(loc.bag, loc.slot)
	if not link then return nil end
	return (LinkLevelInfo(link, loc.bag, loc.slot)) or nil
end
C_Item.GetDetailedItemLevelInfo = function(link)
	if not link then return nil end
	local lvl = LinkLevelInfo(link)
	if lvl then return lvl end
	return select(4, rawGetItemInfo(link))
end

-- Upgrade level of an item (the 5.4 item upgrade system), in the retail
-- GetUpgradeTrack shape: "cur/max" text and a color (none in MoP: the item
-- level keeps its quality color).
function ns.GetUpgradeTrack(link)
	if type(link) ~= "string" or not link:find("item:", 1, true) then return "", nil end
	local _, cur, maxL = LinkLevelInfo(link)
	if cur and maxL and maxL > 0 then return cur .. "/" .. maxL, nil end
	return "", nil
end

-------------------------------------------------------------------------------
--  C_TooltipInfo (only the red-text test of the bags uses it)
-------------------------------------------------------------------------------
local function TooltipData(n)
	local lines = {}
	for i = 1, n do
		local L = scanLines[i]
		lines[i] = {
			leftText = L.left, leftColor = { r = L.lr, g = L.lg, b = L.lb },
			rightText = L.right, rightColor = L.right and { r = L.rr, g = L.rg, b = L.rb } or nil,
		}
	end
	return { lines = lines }
end
env.C_TooltipInfo = {
	GetBagItem = function(bag, slot)
		local n = Scan("SetBagItem", bag, slot)
		if n == 0 and bag == BANK_CONTAINER then
			n = Scan("SetInventoryItem", "player", BankButtonIDToInvSlotID(slot))
		end
		return TooltipData(n)
	end,
	GetHyperlink = function(link) return TooltipData(Scan("SetHyperlink", link)) end,
}

-------------------------------------------------------------------------------
--  C_CurrencyInfo
-------------------------------------------------------------------------------
env.C_CurrencyInfo = {
	GetCurrencyInfo = function(id)
		local name, amount, texture, _, _, _, isDiscovered = GetCurrencyInfo(id)
		if not name or name == "" then return nil end
		if texture and not texture:find("\\", 1, true) then texture = "Interface\\Icons\\" .. texture end
		return { name = name, quantity = amount or 0, iconFileID = texture, discovered = isDiscovered and true or false }
	end,
	GetBackpackCurrencyInfo = function(i)
		local name, count, texture, currencyID = GetBackpackCurrencyInfo(i)
		if not name then return nil end
		return { name = name, quantity = count, iconFileID = texture, currencyTypesID = currencyID }
	end,
	GetCoinTextureString = function(n) return GetCoinTextureString(n) end,
	GetCurrencyListSize = function() return GetCurrencyListSize() end,
	GetCurrencyListInfo = function(i)
		local name, isHeader, isExpanded, _, _, count, icon = GetCurrencyListInfo(i)
		if not name then return nil end
		return { name = name, isHeader = isHeader, isHeaderExpanded = isExpanded, quantity = count, iconFileID = icon }
	end,
	GetCurrencyListLink = function(i) return GetCurrencyListLink(i) end,
	GetCurrencyIDFromLink = function(link) return link and tonumber(link:match("currency:(%d+)")) end,
	ExpandCurrencyList = function(i, expand) ExpandCurrencyList(i, expand and 1 or 0) end,
}

-------------------------------------------------------------------------------
--  Equipment sets (5.4.8: sets by index / name)
-------------------------------------------------------------------------------
env.C_EquipmentSet = {
	GetEquipmentSetIDs = function()
		local ids = {}
		for i = 1, (GetNumEquipmentSets and GetNumEquipmentSets() or 0) do ids[#ids + 1] = i end
		return ids
	end,
	GetEquipmentSetInfo = function(index)
		local name, icon = GetEquipmentSetInfo(index)
		if icon and not tostring(icon):find("\\", 1, true) then icon = "Interface\\Icons\\" .. icon end
		return name, icon
	end,
	GetItemLocations = function(index)
		local name = GetEquipmentSetInfo(index)
		return name and GetEquipmentSetLocations(name) or nil
	end,
}
env.EquipmentManager_GetLocationData = function(loc)
	local player, bank, bags, _, slot, bag = EquipmentManager_UnpackLocation(loc)
	return { isBags = bags and not bank or false, isBank = bank, bag = bag, slot = slot, isPlayer = player }
end

-------------------------------------------------------------------------------
--  C_NewItems / C_ChallengeMode guards
-------------------------------------------------------------------------------
env.C_NewItems = setmetatable({
	ClearAll = (C_NewItems and C_NewItems.ClearAll) or noop,
}, { __index = C_NewItems or {} })

-------------------------------------------------------------------------------
--  Classic bank (5.4.8): the main bank (-1, 28 slots) and 7 bank bag slots
--  (containers 5-11). The retail C_Bank calls the bank file makes are mapped.
-------------------------------------------------------------------------------
local BANK_BAG_FIRST = (NUM_BAG_SLOTS or 4) + 1
local BANK_BAG_LAST = (NUM_BAG_SLOTS or 4) + (NUM_BANKBAGSLOTS or 7)
ns.BANK_BAG_FIRST, ns.BANK_BAG_LAST = BANK_BAG_FIRST, BANK_BAG_LAST
local CHARACTER_BANK = env.Enum.BankType.Character
env.C_Bank = {
	CloseBankFrame = function() CloseBankFrame() end,
	-- "Buy Bank Tab" = buy the next bank bag slot (5.4.8 GetNumBankSlots).
	CanPurchaseBankTab = function(bankType)
		if bankType ~= CHARACTER_BANK then return false end
		local _, full = GetNumBankSlots()
		return not full
	end,
	HasMaxBankTabs = function(bankType)
		if bankType ~= CHARACTER_BANK then return true end
		local _, full = GetNumBankSlots()
		return full and true or false
	end,
}

-------------------------------------------------------------------------------
--  Physical sort (SortBags / SortBank arrived in 6.0). Stacks are merged
--  first, then items are swapped into order, one round per BAG_UPDATE.
--  Profession bags (non-zero family) sort apart and keep their items.
-------------------------------------------------------------------------------
do
	local sorter = CreateFrame("Frame")
	local job

	local function Finish()
		sorter:UnregisterAllEvents()
		sorter:SetScript("OnUpdate", nil)
		local done = job and job.onDone
		job = nil
		if done then done() end
	end

	local function Slots(bags)
		local out = {}
		for _, bag in ipairs(bags) do
			for slot = 1, GetContainerNumSlots(bag) or 0 do
				out[#out + 1] = { bag = bag, slot = slot }
			end
		end
		return out
	end

	local function AnyLocked(slots)
		for _, s in ipairs(slots) do
			if select(3, rawGetContainerItemInfo(s.bag, s.slot)) then return true end
		end
		return false
	end

	-- One merge pass: the smallest partial stack goes onto the largest.
	local function MergePass(slots)
		local byID, moved = {}, false
		for _, s in ipairs(slots) do
			local _, count = rawGetContainerItemInfo(s.bag, s.slot)
			local link = count and rawGetContainerItemLink(s.bag, s.slot)
			local id = link and ItemIDOf(link)
			if id then
				local maxStack = select(8, rawGetItemInfo(id)) or 1
				if maxStack > 1 and count < maxStack then
					local list = byID[id]
					if not list then list = {}; byID[id] = list end
					list[#list + 1] = { bag = s.bag, slot = s.slot, count = count }
				end
			end
		end
		for _, list in pairs(byID) do
			if #list >= 2 then
				table.sort(list, function(a, b) return a.count < b.count end)
				local lo, hi = 1, #list
				while lo < hi do
					PickupContainerItem(list[lo].bag, list[lo].slot)
					PickupContainerItem(list[hi].bag, list[hi].slot)
					ClearCursor()
					moved = true
					lo, hi = lo + 1, hi - 1
				end
			end
		end
		return moved
	end

	-- One sort pass: computes the order, then swaps toward it (selection sort).
	local function SortPass(slots, compare, toBottom)
		local items = {}
		for i, s in ipairs(slots) do
			local link = rawGetContainerItemLink(s.bag, s.slot)
			if link then
				local _, count = rawGetContainerItemInfo(s.bag, s.slot)
				items[#items + 1] = { pos = i, link = link, count = count or 1, bag = s.bag, slot = s.slot }
			end
		end
		if #items == 0 then return false end
		table.sort(items, compare)
		local offset = toBottom and (#slots - #items) or 0
		local at, where = {}, {}
		for idx, d in ipairs(items) do at[d.pos] = idx; where[idx] = d.pos end
		local first, last, step = 1, #items, 1
		if toBottom then first, last, step = #items, 1, -1 end
		local moved = false
		for i = first, last, step do
			local t = i + offset
			local s = where[i]
			if s ~= t then
				local displaced = at[t]
				local same = displaced and items[displaced].link == items[i].link
				if not same then
					PickupContainerItem(slots[s].bag, slots[s].slot)
					PickupContainerItem(slots[t].bag, slots[t].slot)
					ClearCursor()
					where[i] = t
					if displaced then where[displaced] = s end
					at[t] = i
					at[s] = displaced
					moved = true
				end
			end
		end
		return moved
	end

	local function Step()
		if not job or InCombatLockdown() then Finish(); return end
		job.rounds = job.rounds + 1
		if job.rounds > 60 then Finish(); return end
		for _, group in ipairs(job.groups) do
			if AnyLocked(group.slots) then return end -- wait for the next update
		end
		local moved = false
		if job.phase == "merge" then
			for _, group in ipairs(job.groups) do
				if MergePass(group.slots) then moved = true end
			end
			if not moved then job.phase = "sort" end
		end
		if job.phase == "sort" then
			moved = false
			for _, group in ipairs(job.groups) do
				if SortPass(group.slots, job.compare, job.toBottom) then moved = true end
			end
			if not moved then Finish() end
		end
	end

	local elapsed = 0
	local function OnUpdate(self, dt)
		elapsed = elapsed + dt
		if elapsed < 0.15 then return end
		elapsed = 0
		Step()
	end

	-- bags: container IDs; compare(a, b) over { link, count, bag, slot }.
	function ns.SortContainers(bags, compare, toBottom, onDone)
		if InCombatLockdown() then return false end
		if job then Finish() end
		local normal, special = {}, {}
		for _, bag in ipairs(bags) do
			local _, family = GetContainerNumFreeSlots(bag)
			if bag > 0 and family and family ~= 0 then
				special[#special + 1] = bag
			else
				normal[#normal + 1] = bag
			end
		end
		local groups = { { slots = Slots(normal) } }
		for _, bag in ipairs(special) do groups[#groups + 1] = { slots = Slots({ bag }) } end
		job = { groups = groups, compare = compare, toBottom = toBottom, onDone = onDone, phase = "merge", rounds = 0 }
		elapsed = 1
		sorter:SetScript("OnUpdate", OnUpdate)
		return true
	end

	function ns.IsSorting() return job ~= nil end
end

-- Blizzard-like order: item class, quality, item level, name, stack size.
local CLASS_ORDER = { [IC.Weapon] = 1, [IC.Armor] = 2, [IC.Consumable] = 3, [IC.Gem] = 4,
	[IC.ItemEnhancement] = 5, [IC.Tradegoods] = 6, [IC.Recipe] = 7, [IC.Glyph] = 8,
	[IC.Container] = 9, [IC.Questitem] = 10, [IC.Miscellaneous] = 11 }
local function DefaultSortCompare(a, b)
	if not a._k then
		local _, _, qa, la, _, _, _, _, _, _, _, ca = GetItemInfoRetail(a.link)
		a._k = { CLASS_ORDER[ca or 15] or 12, -(qa or 0), -(la or 0), (GetItemInfoRetail(a.link)) or "" }
	end
	if not b._k then
		local _, _, qb, lb, _, _, _, _, _, _, _, cb = GetItemInfoRetail(b.link)
		b._k = { CLASS_ORDER[cb or 15] or 12, -(qb or 0), -(lb or 0), (GetItemInfoRetail(b.link)) or "" }
	end
	local ka, kb = a._k, b._k
	for i = 1, 4 do
		if ka[i] ~= kb[i] then return ka[i] < kb[i] end
	end
	if a.count ~= b.count then return a.count > b.count end
	if a.bag ~= b.bag then return a.bag < b.bag end
	return a.slot < b.slot
end
ns.DefaultSortCompare = DefaultSortCompare

C_Container.SortBags = function()
	local p = Core._bagsDB and Core._bagsDB.profile
	ns.SortContainers({ 0, 1, 2, 3, 4 }, DefaultSortCompare, p and p.bagSortToBottom)
end
C_Container.SortBank = function()
	local p = Core._bagsDB and Core._bagsDB.profile
	local bags = { BANK_CONTAINER }
	for b = BANK_BAG_FIRST, BANK_BAG_LAST do bags[#bags + 1] = b end
	ns.SortContainers(bags, DefaultSortCompare, p and p.bagSortToBottom)
end

-------------------------------------------------------------------------------
--  Icons and atlases. 5.4.8 SetTexture takes paths only: the retail file IDs
--  and atlas names the bags use are mapped to 5.4.8 art.
-------------------------------------------------------------------------------
local I = "Interface\\Icons\\"
local ICONS = {
	[132485] = I .. "INV_BannerPVP_01", [132640] = I .. "INV_Chest_Christmas01",
	[132996] = I .. "INV_Gizmo_02", [133633] = I .. "INV_Misc_Bag_08",
	[133634] = I .. "INV_Misc_Bag_09", [133635] = I .. "INV_Misc_Bag_09_Black",
	[133652] = I .. "INV_Misc_Bag_19", [133656] = I .. "INV_Misc_Bag_23_Netherweave",
	[133659] = I .. "INV_Misc_Bag_26_Spellfire", [133660] = I .. "INV_Misc_Bag_27",
	[133668] = I .. "INV_Misc_Bag_HerbPouch", [133784] = I .. "INV_Misc_Coin_01",
	[133975] = I .. "INV_Misc_Food_19", [134332] = I .. "INV_Misc_Note_06",
	[134400] = I .. "INV_Misc_QuestionMark", [135805] = I .. "Spell_Fire_Fire",
	[136240] = I .. "Trade_Alchemy", [136241] = I .. "Trade_BlackSmithing",
	[136242] = I .. "Trade_BrewPoison", [136244] = I .. "Trade_Engraving",
	[136245] = I .. "Trade_Fishing", [136246] = I .. "Trade_Herbalism",
	[136247] = I .. "Trade_LeatherWorking", [136248] = I .. "Trade_Mining",
	[136249] = I .. "Trade_Tailoring", [348520] = I .. "INV_Misc_Bag_30",
	[348523] = I .. "INV_Misc_Bag_33", [348524] = I .. "INV_Misc_Bag_34",
	[413587] = I .. "Achievement_GuildPerk_MobileBanking",
	-- Newer than 5.4.8: the closest 5.4.8 icon.
	[4871338] = I .. "Trade_Tailoring",              -- Item Set Gear (needle set)
	[3751725] = I .. "INV_Axe_09",                   -- Weapons / Trinkets
	[4382688] = I .. "INV_Chest_Plate04",            -- Armor
	[7548911] = I .. "INV_Misc_Food_19",             -- Consumables (EllesmereUI's own fallback)
	[7549094] = I .. "INV_Misc_Gem_Sapphire_02",     -- Gear Enhancements (blue gem)
	[7548925] = I .. "Trade_BlackSmithing",          -- Professions (smith's tools)
	[5524917] = I .. "INV_Misc_Bag_07",              -- Miscellaneous
	[7726459] = I .. "INV_Misc_QuestionMark",        -- Housing (not in 5.4.8)
	[3622222] = I .. "INV_Misc_Bag_EnchantedRunecloth",
	[1542854] = I .. "INV_Box_02", [1542860] = I .. "INV_Box_02",
	[4641307] = I .. "INV_Misc_Bag_17", [4549238] = I .. "INV_Misc_Bag_15",
	[5931149] = I .. "INV_Misc_Bag_EnchantedRunecloth", [4549226] = I .. "INV_Misc_Bag_16",
	[1379173] = I .. "INV_Misc_Bag_EnchantedMageweave", [2023244] = I .. "INV_Misc_Bag_14",
}
ns.ICONS = ICONS

-- Any icon value the bags pass around -> a 5.4.8 texture path.
function ns.IconPath(icon)
	if type(icon) == "number" then return ICONS[icon] or (I .. "INV_Misc_QuestionMark") end
	if type(icon) == "string" and icon ~= "" and not icon:find("\\", 1, true) and not icon:find("/", 1, true) then
		return I .. icon
	end
	return icon
end

local ATLAS = {
	["bag-main"] = { "Interface\\Buttons\\Button-Backpack-Up" },
	["charactercreate-icon-dice"] = { "Interface\\Buttons\\UI-GroupLoot-Dice-Up" },
	["Crosshair_Quest_64"] = { "Interface\\GossipFrame\\AvailableQuestIcon" },
	["friendslist-recentallies-Pin-yellow"] = { "Interface\\Common\\FavoritesIcon", 0.1, 0.9, 0.1, 0.9 },
	["auctionhouse-icon-clock"] = { I .. "INV_Misc_PocketWatch_01", 0.08, 0.92, 0.08, 0.92 },
	["Petjournalv2-Icon-PlusButton"] = { "Interface\\PaperDollInfoFrame\\Character-Plus" },
}
function env.SetAtlas(tex, name)
	if not tex then return end
	if name == nil or name == "" then
		tex:SetTexture(nil)
		return
	end
	local a = ATLAS[name]
	if a then
		tex:SetTexture(a[1])
		tex:SetTexCoord(a[2] or 0, a[3] or 1, a[4] or 0, a[5] or 1)
	else
		tex:SetTexture(ns.IconPath(name))
	end
end

-------------------------------------------------------------------------------
--  CreateFrame: retail frame types and templates -> 5.4.8. Item buttons get a
--  global name (their 5.4.8 template children are named "$parentCount", ...)
--  and the retail ItemButton methods and fields.
-------------------------------------------------------------------------------
local rawCreateFrame = CreateFrame
local itemButtonN = 0

local function CooldownCompat(cd)
	if not cd or cd._euiCompat then return end
	cd._euiCompat = true
	local setCooldown = cd.SetCooldown
	cd.SetCooldown = function(self, start, duration)
		self:Show()
		setCooldown(self, start, duration)
	end
	cd.Clear = function(self) self:Hide() end
	cd.SetDrawEdge = noop
	cd.SetHideCountdownNumbers = noop
	cd.SetSwipeTexture = noop
end
ns.CooldownCompat = CooldownCompat

local function BankSlotEnter(self)
	local bag = self:GetParent():GetID()
	if bag ~= BANK_CONTAINER then
		ContainerFrameItemButton_OnEnter(self)
		return
	end
	GameTooltip:SetOwner(self, (self:GetRight() or 0) >= GetScreenWidth() / 2 and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
	local has = GameTooltip:SetInventoryItem("player", BankButtonIDToInvSlotID(self:GetID()))
	if not has then GameTooltip:Hide() end
	CursorUpdate(self)
end

function ns.AdoptItemButton(btn)
	local n = btn:GetName()
	btn.Count = _G[n .. "Count"]
	btn.Cooldown = _G[n .. "Cooldown"]
	btn.NewItemTexture = _G[n .. "NewItemTexture"]
	btn.IconQuestTexture = _G[n .. "IconQuestTexture"]
	btn.NormalTexture = btn:GetNormalTexture()
	-- Retail-only template parts: false (not there in 5.4.8).
	btn.IconBorder = false
	btn.BattlepayItemTexture = false
	btn.ProfessionQualityOverlay = false
	btn.IconOverlay = false
	btn.IconOverlay2 = false
	btn.IconMask = false
	btn.HighlightTexture = false
	btn.PushedTexture = false
	btn.UpgradeIcon = false
	btn.flash = false
	btn.newitemglowAnim = false
	-- Text the bag code creates on first use.
	btn.SetNameText = false
	if btn.IconQuestTexture then btn.IconQuestTexture:SetAlpha(0) end
	if btn.searchOverlay then btn.searchOverlay:SetAlpha(0) end
	CooldownCompat(btn.Cooldown)
	btn.SetItemButtonTexture = function(self, tex) SetItemButtonTexture(self, tex) end
	btn.SetItemButtonCount = function(self, c) SetItemButtonCount(self, c) end
	btn.SetItemButtonQuality = noop
	-- The main bank (-1) shows its tooltip through the inventory slot.
	btn:SetScript("OnEnter", BankSlotEnter)
	btn.UpdateTooltip = BankSlotEnter
	return btn
end

-- Retail-only events: a 5.4.8 stand-in, or false = never fires here.
-- (RegisterEvent on an unknown event name is an error in 5.4.8.)
local EVENT_MAP = {
	CURSOR_CHANGED = "CURSOR_UPDATE",
	PLAYER_LEVEL_CHANGED = false,
	CHALLENGE_MODE_RESET = false,
	BAG_CONTAINER_UPDATE = false,
	PLAYER_INTERACTION_MANAGER_FRAME_HIDE = false,
	BANK_TABS_CHANGED = false,
	BANK_TAB_SETTINGS_UPDATED = false,
	PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED = false,
}
local probeFrame = rawCreateFrame("Frame")
local rawRegisterEvent, rawUnregisterEvent = probeFrame.RegisterEvent, probeFrame.UnregisterEvent
local function SafeRegisterEvent(self, event)
	local mapped = EVENT_MAP[event]
	if mapped == false then return end
	pcall(rawRegisterEvent, self, mapped or event)
end
local function SafeUnregisterEvent(self, event)
	local mapped = EVENT_MAP[event]
	if mapped == false then return end
	pcall(rawUnregisterEvent, self, mapped or event)
end

function env.CreateFrame(frameType, name, parent, template, id)
	if frameType == "ItemButton" then frameType = "Button" end
	if template then
		template = template:gsub("BackdropTemplate", ""):gsub("BankPanelPurchaseButtonScriptTemplate", "")
		template = template:gsub("^[%s,]+", ""):gsub("[%s,]+$", ""):gsub(",%s*,", ",")
		if template == "" then template = nil end
	end
	local isItem = template and template:find("ContainerFrameItemButtonTemplate", 1, true)
	if isItem and not name then
		itemButtonN = itemButtonN + 1
		name = "EUIBagsItemButton" .. itemButtonN
	end
	local f = rawCreateFrame(frameType, name, parent, template, id)
	f.RegisterEvent = SafeRegisterEvent
	f.UnregisterEvent = SafeUnregisterEvent
	if isItem then ns.AdoptItemButton(f) end
	if frameType == "Cooldown" then CooldownCompat(f) end
	return f
end

-------------------------------------------------------------------------------
--  Alpha animations: 5.4.8 Alpha animations have SetChange only. The retail
--  SetFromAlpha / SetToAlpha groups the bags build run on OnUpdate instead.
-------------------------------------------------------------------------------
do
	local AG = {}
	AG.__index = AG
	local AN = {}
	AN.__index = AN
	function AN:SetFromAlpha(a) self.from = a end
	function AN:SetToAlpha(a) self.to = a end
	function AN:SetDuration(d) self.duration = d end
	function AN:SetSmoothing(s) self.smoothing = s end
	function AN:SetStartDelay() end
	function AG:CreateAnimation() local a = setmetatable({ from = 0, to = 1, duration = 0.2 }, AN); self.anim = a; return a end
	function AG:SetScript(name, fn) if name == "OnFinished" then self.onFinished = fn end end
	function AG:Stop()
		self.playing = false
		self.driver:Hide()
	end
	function AG:IsPlaying() return self.playing end
	function AG:Play()
		local a = self.anim
		if not a then return end
		self.playing = true
		self.t = 0
		self.target:SetAlpha(a.from or 0)
		self.driver:Show()
	end
	function env.CreateAnimationGroupCompat(target)
		local g = setmetatable({ target = target }, AG)
		local driver = rawCreateFrame("Frame", nil, target)
		driver:Hide()
		driver:SetScript("OnUpdate", function(self, elapsed)
			local a = g.anim
			g.t = g.t + elapsed
			local p = a.duration > 0 and min(1, g.t / a.duration) or 1
			if a.smoothing == "OUT" then p = 1 - (1 - p) * (1 - p)
			elseif a.smoothing == "IN" then p = p * p end
			target:SetAlpha((a.from or 0) + ((a.to or 1) - (a.from or 0)) * p)
			if g.t >= a.duration then
				g.playing = false
				self:Hide()
				if g.onFinished then g.onFinished(g) end
			end
		end)
		g.driver = driver
		return g
	end
end

-------------------------------------------------------------------------------
--  Fonts (retail EllesmereUI_Fonts helpers). No SLUG renderer in 5.4.8.
-------------------------------------------------------------------------------
local FONT_EXPRESSWAY = Core.MEDIA .. "fonts\\Expressway.TTF"

local function SlugFlag(flag)
	if not flag or flag == "" then return flag or "" end
	return (flag:gsub("%s*,%s*SLUG", ""))
end

local function PrimeFontShadow(fs, useShadow)
	if not (fs and fs.SetShadowOffset) then return end
	if useShadow then
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 1)
	else
		fs:SetShadowOffset(0, 0)
	end
end

local function SafeSetFont(fs, path, size, flags)
	fs:SetFont(path, size, flags or "")
	if not fs:GetFont() then fs:SetFont("Fonts\\ARIALN.TTF", size, flags or "") end
end
ns.SafeSetFont = SafeSetFont

local function ApplyIconTextFont(fs, fontPath, size, key)
	if not (fs and fs.SetFont) then return end
	local flag = Core.GetIconTextOutlineFlag and Core.GetIconTextOutlineFlag(key) or "OUTLINE"
	flag = SlugFlag(flag)
	PrimeFontShadow(fs, flag == "")
	SafeSetFont(fs, fontPath, size, flag)
end

-------------------------------------------------------------------------------
--  Pixel perfect borders (retail PP / PanelPP, 4 strips inside the frame)
-------------------------------------------------------------------------------
local PP = {}
local function Perfect()
	local ph = (Core.PhysicalHeight and Core.PhysicalHeight()) or 1080
	return 768 / ph
end
function PP.UpdateMult()
	PP.perfect = Perfect()
	PP.mult = PP.perfect / (UIParent:GetScale() or 1)
end
PP.UpdateMult()
function PP.Snap(x)
	if x == 0 then return 0 end
	local m = PP.mult
	local r = floor(x / m + 0.5) * m
	local rounded = floor(r + 0.5)
	if abs(r - rounded) < 0.001 then r = rounded end
	return r
end
function PP.Scale(x) return x end
function PP.Size(frame, w, h) frame:SetSize(w, h or w) end
function PP.Point(obj, a1, a2, a3, a4, a5)
	if not a2 then a2 = obj:GetParent() end
	obj:SetPoint(a1, a2, a3, a4, a5)
end
function PP.DisablePixelSnap() end

local borders = setmetatable({}, { __mode = "k" })
local function SnapBorder(c, frame, size)
	local es = c:GetEffectiveScale()
	if not es or es <= 0 then return end
	local px = (PP.perfect or Perfect()) / es
	local edge = max(px, floor((size or 1) + 0.5) * px)
	c._top:ClearAllPoints()
	c._top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	c._top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	c._top:SetHeight(edge)
	c._bottom:ClearAllPoints()
	c._bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	c._bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	c._bottom:SetHeight(edge)
	c._left:ClearAllPoints()
	c._left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -edge)
	c._left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, edge)
	c._left:SetWidth(edge)
	c._right:ClearAllPoints()
	c._right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -edge)
	c._right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, edge)
	c._right:SetWidth(edge)
end

function PP.CreateBorder(frame, r, g, b, a, size, layer, subLevel)
	local bd = borders[frame]
	if bd then return bd.container end
	local c = rawCreateFrame("Frame", nil, frame)
	c:SetAllPoints(frame)
	c:SetFrameLevel(frame:GetFrameLevel() + 1)
	local function T()
		local t = c:CreateTexture(nil, layer or "OVERLAY", nil, subLevel or 0)
		t:SetTexture("Interface\\Buttons\\WHITE8X8")
		t:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
		return t
	end
	c._top, c._bottom, c._left, c._right = T(), T(), T(), T()
	bd = { container = c, size = size or 1 }
	borders[frame] = bd
	SnapBorder(c, frame, bd.size)
	-- Re-snap once the frame has its final scale.
	local ticks = 0
	c:SetScript("OnUpdate", function(self)
		ticks = ticks + 1
		SnapBorder(self, frame, bd.size)
		if ticks >= 2 then self:SetScript("OnUpdate", nil) end
	end)
	c:SetScript("OnSizeChanged", function(self) SnapBorder(self, frame, bd.size) end)
	return c
end
function PP.SetBorderColor(frame, r, g, b, a)
	local bd = borders[frame]
	if not bd then return end
	local c = bd.container
	c._top:SetVertexColor(r, g, b, a or 1)
	c._bottom:SetVertexColor(r, g, b, a or 1)
	c._left:SetVertexColor(r, g, b, a or 1)
	c._right:SetVertexColor(r, g, b, a or 1)
end
function PP.GetBorders(frame) local bd = borders[frame]; return bd and bd.container end
function PP.HideBorder(frame) local bd = borders[frame]; if bd then bd.container:Hide() end end
function PP.ShowBorder(frame) local bd = borders[frame]; if bd then bd.container:Show() end end

local PanelPP = setmetatable({}, { __index = PP })
PanelPP.mult = 1

local function MakeBorder(parent, r, g, b, a)
	local bf = rawCreateFrame("Frame", nil, parent)
	bf:SetAllPoints(parent)
	bf:SetFrameLevel(parent:GetFrameLevel() + 1)
	bf:EnableMouse(false)
	PP.CreateBorder(bf, r, g, b, a or 1, 1, "BORDER", 7)
	return {
		_frame = bf,
		SetColor = function(self, cr, cg, cb, ca) PP.SetBorderColor(bf, cr, cg, cb, ca or 1) end,
	}
end

local function MakeFont(parent, size, flags, r, g, b, a)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	SafeSetFont(fs, FONT_EXPRESSWAY, size, flags or "")
	if r then fs:SetTextColor(r, g, b, a or 1) end
	return fs
end

local function Solid(parent, layer, r, g, b, a)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND")
	t:SetTexture(r, g, b, a or 1)
	return t
end

local function lerp(a, b, t) return a + (b - a) * t end

-------------------------------------------------------------------------------
--  Accent (EllesmereUI green unless the user picked another accent)
-------------------------------------------------------------------------------
local ACCENT = { r = 12 / 255, g = 210 / 255, b = 157 / 255 }
local function RefreshAccentColor()
	if Core.ResolveAccent then
		local r, g, b = Core.ResolveAccent()
		if r then ACCENT.r, ACCENT.g, ACCENT.b = r, g, b end
	end
end
RefreshAccentColor()
if Core.accentListeners then
	tinsert(Core.accentListeners, function(r, g, b) ACCENT.r, ACCENT.g, ACCENT.b = r, g, b end)
end
local function GetAccentColor()
	return ACCENT.r, ACCENT.g, ACCENT.b
end

-------------------------------------------------------------------------------
--  Widget tooltip (retail ShowWidgetTooltip look: dark box, 1px border)
-------------------------------------------------------------------------------
local tipFrame
local function TipFrame()
	if tipFrame then return tipFrame end
	local f = rawCreateFrame("Frame", nil, UIParent)
	f:SetFrameStrata("TOOLTIP")
	f:SetFrameLevel(200)
	f:SetSize(250, 40)
	Solid(f, "BACKGROUND", 0.067, 0.067, 0.067, 0.92):SetAllPoints()
	MakeBorder(f, 1, 1, 1, 0.15)
	f.text = MakeFont(f, 10, nil, 1, 1, 1, 0.8)
	f.text:SetPoint("TOPLEFT", 8, -8)
	f.text:SetPoint("TOPRIGHT", -8, -8)
	f.text:SetWordWrap(true)
	f.text:SetSpacing(3)
	f.fadeIn = env.CreateAnimationGroupCompat(f)
	local a = f.fadeIn:CreateAnimation("Alpha")
	a:SetDuration(0.25); a:SetSmoothing("OUT")
	f.fadeOut = env.CreateAnimationGroupCompat(f)
	local b = f.fadeOut:CreateAnimation("Alpha")
	b:SetDuration(0.25); b:SetSmoothing("IN")
	f.fadeOut:SetScript("OnFinished", function() f:SetAlpha(0); f:Hide() end)
	f:Hide()
	tipFrame = f
	return f
end

local function ShowWidgetTooltip(owner, text, opts)
	if type(text) == "function" then text = text() end
	if not owner or not text or text == "" then return end
	local tt = TipFrame()
	tt.fadeOut:Stop()
	tt:SetWidth(opts and opts.width or 250)
	tt.text:SetJustifyH(opts and opts.justify or "CENTER")
	if opts and opts.color then
		tt.text:SetTextColor(opts.color[1], opts.color[2], opts.color[3], opts.color[4] or 0.8)
	else
		tt.text:SetTextColor(1, 1, 1, 0.8)
	end
	tt.text:SetText(text)
	tt:ClearAllPoints()
	if opts and opts.anchor == "cursor" then
		local s = tt:GetEffectiveScale()
		local cx, cy = GetCursorPosition()
		tt:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", cx / s, cy / s + 4)
	elseif opts and opts.anchor == "below" then
		tt:SetPoint("TOP", owner, "BOTTOM", 0, -4)
	else
		tt:SetPoint("BOTTOM", owner, "TOP", 0, 4)
	end
	tt:SetAlpha(0)
	tt:Show()
	if not (opts and opts.width) then
		tt:SetWidth(min((tt.text:GetStringWidth() or 0) + 16, 250))
	end
	tt:SetHeight((tt.text:GetStringHeight() or 10) + 16)
	-- Keep it on the screen.
	local left, right = tt:GetLeft(), tt:GetRight()
	local sw = UIParent:GetWidth()
	if left and left < 0 then
		local p, rel, rp, x, y = tt:GetPoint(1)
		tt:SetPoint(p, rel, rp, (x or 0) - left, y or 0)
	elseif right and right > sw then
		local p, rel, rp, x, y = tt:GetPoint(1)
		tt:SetPoint(p, rel, rp, (x or 0) - (right - sw), y or 0)
	end
	tt.fadeIn.anim:SetFromAlpha(0)
	tt.fadeIn.anim:SetToAlpha(1)
	tt.fadeIn:Play()
end

local function HideWidgetTooltip(instant)
	local tt = tipFrame
	if not tt or not tt:IsShown() then return end
	tt.fadeIn:Stop()
	if instant == true then tt:SetAlpha(0); tt:Hide(); return end
	tt.fadeOut.anim:SetFromAlpha(tt:GetAlpha())
	tt.fadeOut.anim:SetToAlpha(0)
	tt.fadeOut:Play()
end

-------------------------------------------------------------------------------
--  Popups (retail confirm / input popups)
-------------------------------------------------------------------------------
local function PopupScale()
	local ph = (Core.PhysicalHeight and Core.PhysicalHeight()) or 1080
	local base = GetScreenHeight() / ph
	local user = (EllesmereUIDB and EllesmereUIDB.panelScale) or 1
	return base * user
end

local function MakePopupButton(parent, point, rel, relPoint, x, y, dR, dG, dB, dA, hR, hG, hB, hA, bdR, bdG, bdB, bdA, bhR, bhG, bhB, bhA)
	local btn = rawCreateFrame("Button", nil, parent)
	btn:SetSize(125, 27)
	btn:SetPoint(point, rel, relPoint, x, y)
	btn:SetFrameLevel(parent:GetFrameLevel() + 2)
	Solid(btn, "BACKGROUND", 0, 0, 0, 0.5):SetAllPoints()
	local brd = MakeBorder(btn, bdR, bdG, bdB, bdA)
	local lbl = MakeFont(btn, 12, nil, dR, dG, dB)
	lbl:SetAlpha(dA)
	lbl:SetPoint("CENTER")
	local progress, target = 0, 0
	local function Apply(t)
		lbl:SetTextColor(lerp(dR, hR, t), lerp(dG, hG, t), lerp(dB, hB, t), lerp(dA, hA, t))
		brd:SetColor(lerp(bdR, bhR, t), lerp(bdG, bhG, t), lerp(bdB, bhB, t), lerp(bdA, bhA, t))
	end
	local function OnUpdate(self, elapsed)
		local dir = (target == 1) and 1 or -1
		progress = progress + dir * (elapsed / 0.1)
		if (dir == 1 and progress >= 1) or (dir == -1 and progress <= 0) then
			progress = target
			self:SetScript("OnUpdate", nil)
		end
		Apply(progress)
	end
	btn:SetScript("OnEnter", function(self) target = 1; self:SetScript("OnUpdate", OnUpdate) end)
	btn:SetScript("OnLeave", function(self) target = 0; self:SetScript("OnUpdate", OnUpdate) end)
	btn._lbl = lbl
	btn._resetAnim = function() progress = 0; target = 0; Apply(0); btn:SetScript("OnUpdate", nil) end
	return btn
end

local function PopupShell(name, w, h)
	local dimmer = rawCreateFrame("Frame", name .. "Dimmer", UIParent)
	dimmer:SetFrameStrata("FULLSCREEN_DIALOG")
	dimmer:SetFrameLevel(100)
	dimmer:SetAllPoints(UIParent)
	dimmer:EnableMouse(true)
	dimmer:EnableMouseWheel(true)
	dimmer:SetScript("OnMouseWheel", noop)
	dimmer:Hide()
	Solid(dimmer, "BACKGROUND", 0, 0, 0, 0.25):SetAllPoints()
	local popup = rawCreateFrame("Frame", name, dimmer)
	popup:SetSize(w, h)
	popup:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
	popup:SetFrameStrata("FULLSCREEN_DIALOG")
	popup:SetFrameLevel(dimmer:GetFrameLevel() + 10)
	popup:EnableMouse(true)
	Solid(popup, "BACKGROUND", 0.077, 0.068, 0.058, 1):SetAllPoints()
	MakeBorder(popup, 1, 1, 1, 0.15)
	popup._title = MakeFont(popup, 16, "", 1, 1, 1)
	popup._title:SetPoint("TOP", popup, "TOP", 0, -20)
	popup._dimmer = dimmer
	popup:EnableKeyboard(true)
	popup:SetScript("OnKeyDown", function(self, key)
		if key == "ESCAPE" then
			self:SetPropagateKeyboardInput(false)
			dimmer:Hide()
			if self._onCancel then self._onCancel() end
		else
			self:SetPropagateKeyboardInput(true)
		end
	end)
	dimmer:SetScript("OnMouseDown", function()
		if not popup:IsMouseOver() then
			dimmer:Hide()
			if popup._onCancel then popup._onCancel() end
		end
	end)
	return popup
end

local TEXT_DIM = { r = 1, g = 1, b = 1, a = 0.6 }

local confirmPopup
local function ShowConfirmPopup(_, opts)
	HideWidgetTooltip(true)
	if not confirmPopup then
		local p = PopupShell("EUIBagsConfirmPopup", 390, 176)
		p._msg = MakeFont(p, 12, nil, TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, TEXT_DIM.a)
		p._msg:SetPoint("TOP", p._title, "BOTTOM", 0, -10)
		p._msg:SetWidth(330)
		p._msg:SetJustifyH("CENTER")
		p._msg:SetWordWrap(true)
		p._msg:SetSpacing(4)
		local A = ACCENT
		p._cancelBtn = MakePopupButton(p, "BOTTOMRIGHT", p, "BOTTOM", -8, 13,
			1, 1, 1, 0.7, 1, 1, 1, 0.9, 1, 1, 1, 0.5, 1, 1, 1, 0.6)
		p._confirmBtn = MakePopupButton(p, "BOTTOMLEFT", p, "BOTTOM", 8, 13,
			A.r, A.g, A.b, 0.9, A.r, A.g, A.b, 1, A.r, A.g, A.b, 0.9, A.r, A.g, A.b, 1)
		-- Optional checkbox above the buttons
		local cb = rawCreateFrame("Button", nil, p)
		cb:SetSize(330, 18)
		cb:SetFrameLevel(p:GetFrameLevel() + 2)
		local box = rawCreateFrame("Frame", nil, cb)
		box:SetSize(14, 14)
		box:SetPoint("LEFT", cb, "LEFT", 0, 0)
		Solid(box, "BACKGROUND", 0.103, 0.095, 0.088, 1):SetAllPoints()
		MakeBorder(box, 1, 1, 1, 0.25)
		local check = Solid(box, "ARTWORK", A.r, A.g, A.b, 1)
		check:SetPoint("TOPLEFT", 3, -3)
		check:SetPoint("BOTTOMRIGHT", -3, 3)
		check:Hide()
		local lbl = MakeFont(cb, 11, nil, TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, TEXT_DIM.a)
		lbl:SetPoint("LEFT", box, "RIGHT", 6, 0)
		cb:SetScript("OnClick", function()
			p._cbChecked = not p._cbChecked
			check:SetShown(p._cbChecked)
		end)
		cb:Hide()
		p._cbRow, p._cbCheck, p._cbLabel = cb, check, lbl
		confirmPopup = p
	end
	local p = confirmPopup
	p._title:SetText(opts.title or "Confirm")
	p._msg:SetText(opts.message or "Are you sure?")
	local cbH = 0
	if opts.checkbox then
		p._cbChecked = false
		p._cbCheck:Hide()
		p._cbLabel:SetText(opts.checkbox)
		p._cbRow:SetWidth(20 + p._cbLabel:GetStringWidth())
		p._cbRow:ClearAllPoints()
		p._cbRow:SetPoint("BOTTOM", p, "BOTTOM", 0, 13 + 27 + 10)
		p._cbRow:Show()
		cbH = 28
	else
		p._cbRow:Hide()
	end
	local overflow = max(0, (p._msg:GetStringHeight() or 0) - 44)
	p:SetHeight(176 + overflow + cbH)
	p._cancelBtn._lbl:SetText(opts.cancelText or CANCEL)
	p._confirmBtn._lbl:SetText(opts.confirmText or OKAY)
	p._onCancel = opts.onDismiss or opts.onCancel
	if opts.hideCancel then
		p._cancelBtn:Hide()
		p._confirmBtn:ClearAllPoints()
		p._confirmBtn:SetPoint("BOTTOM", p, "BOTTOM", 0, 13)
	else
		p._cancelBtn:Show()
		p._confirmBtn:ClearAllPoints()
		p._confirmBtn:SetPoint("BOTTOMLEFT", p, "BOTTOM", 8, 13)
	end
	p._cancelBtn._resetAnim()
	p._confirmBtn._resetAnim()
	p._cancelBtn:SetScript("OnClick", function()
		p._dimmer:Hide()
		if opts.onCancel then opts.onCancel() end
	end)
	p._confirmBtn:SetScript("OnClick", function()
		p._dimmer:Hide()
		if opts.onConfirm then opts.onConfirm(p._cbChecked) end
		if opts.reload then ReloadUI() end
	end)
	p:SetScale(PopupScale())
	p._dimmer:Show()
end

local inputPopup
local function ShowInputPopup(_, opts)
	HideWidgetTooltip(true)
	if not inputPopup then
		local p = PopupShell("EUIBagsInputPopup", 390, 194)
		p._msg = MakeFont(p, 12, nil, TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, TEXT_DIM.a)
		p._msg:SetPoint("TOP", p._title, "BOTTOM", 0, -8)
		p._msg:SetWidth(330)
		p._msg:SetJustifyH("CENTER")
		p._msg:SetWordWrap(true)
		p._msg:SetSpacing(4)
		local input = rawCreateFrame("Frame", nil, p)
		input:SetSize(270, 28)
		input:SetPoint("TOP", p._msg, "BOTTOM", 0, -12)
		input:SetFrameLevel(p:GetFrameLevel() + 2)
		Solid(input, "BACKGROUND", 0, 0, 0, 0.5):SetAllPoints()
		local ibrd = MakeBorder(input, 1, 1, 1, 0.2)
		local eb = rawCreateFrame("EditBox", nil, input)
		eb:SetPoint("TOPLEFT", 12, -1)
		eb:SetPoint("BOTTOMRIGHT", -12, 1)
		SafeSetFont(eb, FONT_EXPRESSWAY, 11, "")
		eb:SetTextColor(1, 1, 1, 0.9)
		eb:SetAutoFocus(false)
		eb:SetMaxLetters(30)
		local ph = eb:CreateFontString(nil, "ARTWORK")
		SafeSetFont(ph, FONT_EXPRESSWAY, 11, "")
		ph:SetTextColor(TEXT_DIM.r, TEXT_DIM.g, TEXT_DIM.b, TEXT_DIM.a * 0.5)
		ph:SetPoint("LEFT", eb, "LEFT", 0, 0)
		eb:SetScript("OnTextChanged", function(self)
			ph:SetShown((self:GetText() or "") == "")
		end)
		eb:SetScript("OnEscapePressed", function()
			p._dimmer:Hide()
			if p._onCancel then p._onCancel() end
		end)
		local flash, fl = rawCreateFrame("Frame", nil, input), 0
		flash:Hide()
		flash:SetScript("OnUpdate", function(self, elapsed)
			fl = fl + elapsed
			if fl >= 0.7 then self:Hide(); ibrd:SetColor(1, 1, 1, 0.2); return end
			local t = fl / 0.7
			ibrd:SetColor(lerp(0.9, 1, t), lerp(0.15, 1, t), lerp(0.15, 1, t), lerp(0.7, 0.2, t))
		end)
		p._flash = function() fl = 0; ibrd:SetColor(0.9, 0.15, 0.15, 0.7); flash:Show(); eb:SetFocus() end
		local A = ACCENT
		p._cancelBtn = MakePopupButton(p, "BOTTOMRIGHT", p, "BOTTOM", -8, 13,
			1, 1, 1, 0.7, 1, 1, 1, 0.9, 1, 1, 1, 0.5, 1, 1, 1, 0.6)
		p._confirmBtn = MakePopupButton(p, "BOTTOMLEFT", p, "BOTTOM", 8, 13,
			A.r, A.g, A.b, 0.9, A.r, A.g, A.b, 1, A.r, A.g, A.b, 0.9, A.r, A.g, A.b, 1)
		p._editBox, p._placeholder = eb, ph
		p._dimmer:HookScript("OnHide", function() eb:ClearFocus() end)
		inputPopup = p
	end
	local p = inputPopup
	p._title:SetText(opts.title or "")
	p._msg:SetText(opts.message or "")
	p._editBox:SetText("")
	p._placeholder:SetText(opts.placeholder or "")
	p._placeholder:Show()
	p._cancelBtn._lbl:SetText(opts.cancelText or CANCEL)
	p._confirmBtn._lbl:SetText(opts.confirmText or OKAY)
	p._cancelBtn._resetAnim()
	p._confirmBtn._resetAnim()
	p._onCancel = opts.onCancel
	local function Confirm()
		local text = p._editBox:GetText() or ""
		if text == "" and not opts.allowEmpty then p._flash(); return end
		p._dimmer:Hide()
		if opts.onConfirm then opts.onConfirm(text) end
	end
	p._editBox:SetScript("OnEnterPressed", Confirm)
	p._confirmBtn:SetScript("OnClick", Confirm)
	p._cancelBtn:SetScript("OnClick", function()
		p._dimmer:Hide()
		if opts.onCancel then opts.onCancel() end
	end)
	p:SetScale(PopupScale())
	p._dimmer:Show()
	p._editBox:SetFocus()
end

-------------------------------------------------------------------------------
--  MenuUtil.CreateContextMenu (retail context menus; EllesmereUI's dark menu
--  skin). Description API: CreateButton, CreateCheckbox, CreateTitle,
--  CreateDivider, SetScrollMode.
-------------------------------------------------------------------------------
do
	local Desc = {}
	Desc.__index = Desc
	local function NewDesc(kind, text, fn, extra)
		return setmetatable({ kind = kind, text = text, fn = fn, extra = extra, items = {} }, Desc)
	end
	function Desc:CreateButton(text, fn)
		local d = NewDesc("button", text, fn)
		self.items[#self.items + 1] = d
		return d
	end
	function Desc:CreateCheckbox(text, isSelected, setSelected)
		local d = NewDesc("checkbox", text, setSelected, isSelected)
		self.items[#self.items + 1] = d
		return d
	end
	function Desc:CreateTitle(text)
		local d = NewDesc("title", text)
		self.items[#self.items + 1] = d
		return d
	end
	function Desc:CreateDivider()
		local d = NewDesc("divider")
		self.items[#self.items + 1] = d
		return d
	end
	function Desc:SetScrollMode(h) self.scrollH = h end

	local ITEM_H, PAD, MIN_W = 20, 4, 140
	local levels = {}
	local catcher
	local Layout

	local function CloseFrom(level)
		for i = #levels, level, -1 do
			if levels[i] then levels[i]:Hide() end
		end
	end
	local function CloseAll()
		CloseFrom(1)
		if catcher then catcher:Hide() end
	end
	ns.CloseContextMenu = CloseAll

	local function GetLevel(i)
		local f = levels[i]
		if f then return f end
		f = rawCreateFrame("Frame", nil, UIParent)
		f:SetFrameStrata("FULLSCREEN_DIALOG")
		f:SetFrameLevel(20 + i * 5)
		f:EnableMouse(true)
		f:EnableMouseWheel(true)
		f:SetClampedToScreen(true)
		Solid(f, "BACKGROUND", 0.067, 0.067, 0.067, 0.96):SetAllPoints()
		MakeBorder(f, 0, 0, 0, 1)
		f.rows = {}
		f.offset = 0
		f.Layout = function(self) Layout(self) end
		f:SetScript("OnMouseWheel", function(self, delta)
			if not self.maxRows or #self.desc.items <= self.maxRows then return end
			self.offset = max(0, min(#self.desc.items - self.maxRows, self.offset - delta))
			self:Layout()
		end)
		f:Hide()
		levels[i] = f
		return f
	end

	local function Row(f, idx)
		local r = f.rows[idx]
		if r then return r end
		r = rawCreateFrame("Button", nil, f)
		r:SetHeight(ITEM_H)
		r.hl = Solid(r, "BACKGROUND", 1, 1, 1, 0.08)
		r.hl:SetAllPoints()
		r.hl:Hide()
		r.box = rawCreateFrame("Frame", nil, r)
		r.box:SetSize(12, 12)
		r.box:SetPoint("LEFT", 8, 0)
		Solid(r.box, "BACKGROUND", 0.103, 0.095, 0.088, 1):SetAllPoints()
		MakeBorder(r.box, 1, 1, 1, 0.25)
		r.check = Solid(r.box, "ARTWORK", ACCENT.r, ACCENT.g, ACCENT.b, 1)
		r.check:SetPoint("TOPLEFT", 2, -2)
		r.check:SetPoint("BOTTOMRIGHT", -2, 2)
		r.text = r:CreateFontString(nil, "OVERLAY")
		SafeSetFont(r.text, FONT_EXPRESSWAY, 12, "")
		r.text:SetJustifyH("LEFT")
		r.text:SetWordWrap(false)
		r.arrow = r:CreateFontString(nil, "OVERLAY")
		SafeSetFont(r.arrow, FONT_EXPRESSWAY, 12, "")
		r.arrow:SetPoint("RIGHT", -6, 0)
		r.arrow:SetText(">")
		r.line = Solid(r, "ARTWORK", 1, 1, 1, 0.12)
		r.line:SetHeight(1)
		r.line:SetPoint("LEFT", 8, 0)
		r.line:SetPoint("RIGHT", -8, 0)
		r:SetScript("OnEnter", function(self)
			local d = self.desc
			if not d or d.kind == "title" or d.kind == "divider" then return end
			self.hl:Show()
			CloseFrom(f.level + 1)
			if #d.items > 0 then
				local sub = GetLevel(f.level + 1)
				sub.level = f.level + 1
				sub.desc = d
				sub.offset = 0
				sub:Layout()
				sub:ClearAllPoints()
				sub:SetPoint("TOPLEFT", self, "TOPRIGHT", 2, PAD)
				sub:Show()
			end
		end)
		r:SetScript("OnLeave", function(self) self.hl:Hide() end)
		r:SetScript("OnClick", function(self)
			local d = self.desc
			if not d then return end
			if d.kind == "checkbox" then
				if d.fn then d.fn() end
				f:Layout()
				return
			end
			if d.kind == "button" and #d.items == 0 then
				CloseAll()
				if d.fn then d.fn() end
			end
		end)
		f.rows[idx] = r
		return r
	end

	Layout = function(f)
		local d = f.desc
		local items = d.items
		local maxRows = d.scrollH and floor(d.scrollH / ITEM_H) or #items
		f.maxRows = maxRows
		local shown = min(#items, maxRows)
		local measure = f.measure or f:CreateFontString(nil, "OVERLAY")
		f.measure = measure
		SafeSetFont(measure, FONT_EXPRESSWAY, 12, "")
		local w = MIN_W
		for _, it in ipairs(items) do
			if it.text then
				measure:SetText(it.text)
				w = max(w, (measure:GetStringWidth() or 0) + 52)
			end
		end
		measure:SetText("")
		for i = 1, max(shown, #f.rows) do
			local r = (i <= shown) and Row(f, i) or f.rows[i]
			if i <= shown then
				local it = items[i + f.offset]
				r.desc = it
				r:ClearAllPoints()
				r:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -PAD - (i - 1) * ITEM_H)
				r:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -PAD - (i - 1) * ITEM_H)
				r.hl:Hide()
				r.line:SetShown(it.kind == "divider")
				r.text:SetShown(it.kind ~= "divider")
				r.arrow:SetShown(it.kind == "button" and #it.items > 0)
				r.box:SetShown(it.kind == "checkbox")
				r.text:ClearAllPoints()
				r.text:SetPoint("LEFT", it.kind == "checkbox" and 26 or 10, 0)
				r.text:SetPoint("RIGHT", -18, 0)
				r.text:SetText(it.text or "")
				if it.kind == "title" then
					r.text:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b, 1)
				else
					r.text:SetTextColor(1, 1, 1, 0.85)
				end
				if it.kind == "checkbox" then
					r.check:SetTexture(ACCENT.r, ACCENT.g, ACCENT.b, 1)
					r.check:SetShown(it.extra and it.extra() and true or false)
				end
				r:Show()
			else
				r:Hide()
			end
		end
		f:SetSize(w, shown * ITEM_H + PAD * 2)
	end

	local function OpenRoot(owner, desc)
		if not catcher then
			catcher = rawCreateFrame("Button", nil, UIParent)
			catcher:SetAllPoints(UIParent)
			catcher:SetFrameStrata("FULLSCREEN_DIALOG")
			catcher:SetFrameLevel(1)
			catcher:RegisterForClicks("AnyUp")
			catcher:SetScript("OnClick", CloseAll)
			catcher:EnableKeyboard(true)
			catcher:SetScript("OnKeyDown", function(self, key)
				if key == "ESCAPE" then
					self:SetPropagateKeyboardInput(false)
					CloseAll()
				else
					self:SetPropagateKeyboardInput(true)
				end
			end)
		end
		CloseAll()
		local f = GetLevel(1)
		f.level = 1
		f.desc = desc
		f.offset = 0
		f:Layout()
		local s = f:GetEffectiveScale()
		local cx, cy = GetCursorPosition()
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cx / s, cy / s)
		catcher:Show()
		f:Show()
	end

	env.MenuUtil = {
		CreateContextMenu = function(owner, generator)
			local root = NewDesc("root")
			generator(owner, root)
			if #root.items == 0 then return end
			OpenRoot(owner, root)
		end,
	}
end

-------------------------------------------------------------------------------
--  Lite DB (retail EllesmereUI.Lite.NewDB): db.profile is a copy of the
--  defaults until the SavedVariables load, then the saved profile (missing
--  keys filled from the defaults).
-------------------------------------------------------------------------------
local function DeepMergeDefaults(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			DeepMergeDefaults(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
	return dst
end

local dbReady = false
local pendingDBs = {}
local Lite = {
	DeepMergeDefaults = DeepMergeDefaults,
	IsDBReady = function() return dbReady end,
	NewDB = function(svName, defaults)
		local db = { _svName = svName, _profileDefaults = defaults.profile or {} }
		db.profile = DeepMergeDefaults({}, db._profileDefaults)
		pendingDBs[#pendingDBs + 1] = db
		return db
	end,
}
ns.Lite = Lite

-- Called at this addon's ADDON_LOADED (EllesmereUIBags_DB.lua).
function ns.AttachSavedVariables()
	for _, db in ipairs(pendingDBs) do
		local root = _G[db._svName]
		if type(root) ~= "table" then
			root = {}
			_G[db._svName] = root
		end
		db._isNew = type(root.profile) ~= "table"
		if db._isNew then root.profile = {} end
		db.profile = DeepMergeDefaults(root.profile, db._profileDefaults)
		db._root = root
	end
	dbReady = true
end

-------------------------------------------------------------------------------
--  Localization: the port is English only (retail L() returns the key on enUS).
-------------------------------------------------------------------------------
local function L(s) return s end
local function Lf(fmt, ...)
	if type(fmt) ~= "string" then return tostring(fmt) end
	-- Retail format strings use positional "%1$d" specifiers; 5.4.8 format
	-- has them too, but plain ones are safer for the few used here.
	local plain = fmt:gsub("%%(%d)%$", "%%")
	return string.format(plain, ...)
end

-------------------------------------------------------------------------------
--  Escape closes registered windows (UISpecialFrames needs a global name)
-------------------------------------------------------------------------------
local escN = 0
local function RegisterEscapeClose(frame, opts)
	if not frame or (opts and opts.padOnly) then return end
	local name = frame:GetName()
	if not name then
		escN = escN + 1
		name = "EUIBagsEscapeFrame" .. escN
		_G[name] = frame
	end
	for _, v in ipairs(UISpecialFrames) do
		if v == name then return end
	end
	tinsert(UISpecialFrames, name)
end

-------------------------------------------------------------------------------
--  CVar hold (muting sound effects while a sort moves items)
-------------------------------------------------------------------------------
local held = {}
local function HoldCVar(name, value)
	if held[name] == nil then held[name] = GetCVar(name) end
	SetCVar(name, value)
end
local function ReleaseCVar(name, value)
	local was = held[name]
	held[name] = nil
	SetCVar(name, value or was or "1")
end

-------------------------------------------------------------------------------
--  The EllesmereUI proxy the bag files see as "EllesmereUI"
-------------------------------------------------------------------------------
local uninstallHooks = {}
local EUI = setmetatable({
	IS_FOREVER = false,
	L = L,
	Lf = Lf,
	PP = PP,
	PanelPP = PanelPP,
	MakeBorder = MakeBorder,
	MakeFont = MakeFont,
	MakePopupButton = MakePopupButton,
	SolidTex = Solid,
	lerp = lerp,
	EXPRESSWAY = FONT_EXPRESSWAY,
	ELLESMERE_GREEN = ACCENT,
	TEXT_WHITE = { r = 1, g = 1, b = 1 },
	TEXT_DIM = TEXT_DIM,
	GetAccentColor = GetAccentColor,
	ShowWidgetTooltip = ShowWidgetTooltip,
	HideWidgetTooltip = HideWidgetTooltip,
	ShowConfirmPopup = ShowConfirmPopup,
	ShowInputPopup = ShowInputPopup,
	RegisterEscapeClose = RegisterEscapeClose,
	SlugFlag = SlugFlag,
	StripSlugFlag = SlugFlag,
	PrimeFontShadow = PrimeFontShadow,
	ApplyIconTextFont = ApplyIconTextFont,
	Lite = Lite,
	_ModuleNS = { [addonName] = ns },
	HoldCVar = HoldCVar,
	ReleaseCVar = ReleaseCVar,
	OnUninstall = function(fn) uninstallHooks[#uninstallHooks + 1] = fn end,
	ClientIcon = function(icon) return ns.IconPath(icon) end,
	GetUpgradeTrack = ns.GetUpgradeTrack,
	GetCraftedTrackColor = function() return nil end,
	_TRACK_RANK = nil,
	PrintError = function(msg) DEFAULT_CHAT_FRAME:AddMessage("|cffff6060EllesmereUI|r: " .. tostring(msg)) end,
	RequestReload = function(title, message, work)
		ShowConfirmPopup(nil, { title = title or "Reload Required", message = message or "A reload is required to apply this.",
			confirmText = "Reload Now", cancelText = "Later", onConfirm = work, reload = true })
	end,
	RefreshPage = function()
		if Core.RefreshSettings then pcall(Core.RefreshSettings) end
	end,
	EnsureLoaded = function() return Core.LoadOptions and Core.LoadOptions() end,
	-- Controller (gamepad cursor) support does not exist in 5.4.8.
	PadInUse = function() return false end,
	PadCP = function() return false end,
	PadCursorShown = function() return false end,
	PadGamepadUI = function() return false end,
	PadNative = function() return false end,
	PadHint = noop,
	PadFocus = noop,
	RaiseGamePadCursor = noop,
	RegisterPadFrame = noop,
}, { __index = Core, __newindex = Core })
env.EllesmereUI = EUI
ns.EUI = EUI
ns.uninstallHooks = uninstallHooks
ns.GetAccentRGB = GetAccentColor

-- Core helpers the bags read: GetFontPath / GetFontOutlineFlag / ResolveAccent
-- come from the core table; make sure the outline flags never carry SLUG.
-- rawset: a plain write would go through to the core table.
rawset(EUI, "GetFontOutlineFlag", function(key)
	return SlugFlag(Core.GetFontOutlineFlag and Core.GetFontOutlineFlag(key) or "")
end)
rawset(EUI, "GetFontPath", function(key)
	return (Core.GetFontPath and Core.GetFontPath(key)) or FONT_EXPRESSWAY
end)

-- Uninstall EUI (core) runs the bag hooks too.
if Core.Uninstall then
	hooksecurefunc(Core, "Uninstall", function()
		for _, fn in ipairs(uninstallHooks) do pcall(fn) end
	end)
end

-- Pixel size follows UI scale changes.
local scaleWatch = rawCreateFrame("Frame")
scaleWatch:RegisterEvent("UI_SCALE_CHANGED")
scaleWatch:RegisterEvent("DISPLAY_SIZE_CHANGED")
scaleWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
scaleWatch:SetScript("OnEvent", function()
	PP.UpdateMult()
	RefreshAccentColor()
end)

-- From here on the environment reads and writes the real globals for every
-- name not defined above.
setmetatable(env, { __index = _G, __newindex = _G })
