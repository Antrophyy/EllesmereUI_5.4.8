-- Settings pages of UI Reskin Addons > Bags (EllesmereUI EUI_Bags_Options.lua:
-- the same pages, sections, options, texts and keys). Part of
-- EllesmereUIOptions (load on demand); skipped when EllesmereUIBags is not loaded.

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUIBags") then
	return
end

local function P()
	return ns._bagsDB and ns._bagsDB.profile or {}
end

local function Bags() return _G.EUI_Bags end
local function Bank() return _G.EUI_BankFrame end

local function RefreshBags()
	local b = Bags()
	if b and b.RefreshInventory then b:RefreshInventory() end
end
local function RefreshBank()
	local b = Bank()
	if b and b.RefreshBank then b:RefreshBank() end
end
local function TextSizes()
	local b = Bags()
	if b and b.RefreshTextSizes then b:RefreshTextSizes() end
	local k = Bank()
	if k and k.RefreshTextSizes then k:RefreshTextSizes() end
end
local function ResetAndRefreshBagLayout()
	local b = Bags()
	if not b then return end
	b._asCols = nil
	b._asMaxGridW = nil
	b._asMaxH = nil
	if b.RefreshInventory then b:RefreshInventory() end
end

local function ReloadPopup(message)
	ns.ShowConfirmPopup({
		title = "Reload Required",
		message = message,
		confirmText = "Reload Now",
		cancelText = "Later",
		reload = true,
	})
end

local function Items(list)
	return function()
		local out = {}
		for i, e in ipairs(list) do out[i] = { value = e[1], name = e[2] } end
		return out
	end
end
local function Label(list, value)
	for _, e in ipairs(list) do
		if e[1] == value then return e[2] end
	end
	return tostring(value or "")
end

local DISPLAY_MODES = { { "grid", "Grid" }, { "list", "List" } }
local BAG_TYPES = { { "all", "All Items" }, { "onebag", "OneBag" }, { "multibag", "MultiBag" } }

local function DefaultBagType()
	local t = P().bagDefaultBagType
	if t == "all" or t == "onebag" or t == "multibag" then return t end
	return P().bagDefaultOneBag and "onebag" or "all"
end

-- Enabled Categories: every category the sorting can turn off.
local function CategoryItems()
	local items = {}
	local cm = _G.EUI_CategoryManager
	if cm then
		for _, cat in ipairs(cm:GetCategories()) do
			if not cat.isCatchAll and not cat.isPinned and not cat.isRecent and not cat.isReagentBag
				and not cat.isSpecialBag and not cat.isEquipSet then
				items[#items + 1] = { value = cat._defaultName, name = cat.name }
			end
		end
	end
	return items
end
local function CategoryEnabled(key)
	local dc = P().bagDisabledCategories
	return not (dc and dc[key])
end
local function ToggleCategory(key)
	local p = P()
	p.bagDisabledCategories = p.bagDisabledCategories or {}
	if CategoryEnabled(key) then
		p.bagDisabledCategories[key] = true
	else
		p.bagDisabledCategories[key] = nil
	end
	RefreshBags()
end
local function CategoriesLabel()
	local items, on = CategoryItems(), 0
	for _, it in ipairs(items) do
		if CategoryEnabled(it.value) then on = on + 1 end
	end
	if on == #items then return "All" end
	if on == 0 then return "None" end
	return on .. " / " .. #items
end

-- Enabled Currencies: the character's currency list (5.4.8 GetCurrencyListInfo)
-- plus tracked ones no longer listed. Per character, like EllesmereUI.
local function CurrencyOrder()
	return ns._BagsCurrencyOrder and ns._BagsCurrencyOrder()
end
local function CurrencyItems()
	local items, listed = {}, {}
	local collapsed = {}
	local i = 1
	while i <= GetCurrencyListSize() do
		local name, isHeader, isExpanded = GetCurrencyListInfo(i)
		if isHeader and not isExpanded then
			collapsed[#collapsed + 1] = i
			ExpandCurrencyList(i, 1)
		end
		i = i + 1
	end
	for idx = 1, GetCurrencyListSize() do
		local name, isHeader = GetCurrencyListInfo(idx)
		if name and not isHeader then
			local link = GetCurrencyListLink(idx)
			local id = link and tonumber(link:match("currency:(%d+)"))
			if id then
				items[#items + 1] = { value = id, name = name }
				listed[id] = true
			end
		end
	end
	for k = #collapsed, 1, -1 do
		ExpandCurrencyList(collapsed[k], 0)
	end
	local co = CurrencyOrder()
	if co then
		local retired = {}
		for id in pairs(co) do
			if type(id) == "number" and not listed[id] then retired[#retired + 1] = id end
		end
		table.sort(retired)
		for k = #retired, 1, -1 do
			local name = GetCurrencyInfo(retired[k])
			table.insert(items, 1, { value = retired[k], name = (name and name ~= "" and name or ("Currency " .. retired[k])) .. " (Retired)" })
		end
	end
	return items
end
local function CurrencyTracked(id)
	local co = CurrencyOrder()
	return co and co[id] and true or false
end
local function ToggleCurrency(id)
	local co = CurrencyOrder()
	if not co then return end
	if co[id] then
		co[id] = nil
	else
		local maxOrder = 0
		for _, ord in pairs(co) do
			if type(ord) == "number" and ord > maxOrder then maxOrder = ord end
		end
		co[id] = maxOrder + 1
	end
	RefreshBags()
end
local function CurrenciesLabel()
	local co, n = CurrencyOrder(), 0
	if co then for _ in pairs(co) do n = n + 1 end end
	return n == 0 and "None" or (n .. " tracked")
end

---------------------------------------------------------------------------
-- Bags page
---------------------------------------------------------------------------
local function BuildBags(p)
	p:Paragraph("Reposition this element with Shift+Click and Drag.\nDrag categories on bag sidebar to reposition, group or ungroup.")

	-- Grid View / List View sections are only built while bags or bank use that layout.
	local bagList = P().bagDisplayMode == "list"
	local anyGrid = not bagList or P().bankListView ~= true
	local anyList = bagList or P().bankListView == true

	p:Section("Layout")
	p:Dropdown("Bag Display", "Grid shows item icons in a grid. List shows one row per item, grouped by category with a Junk section at the end (OneBag and MultiBag keep slot order, as in the grid): click a column name on the bag window to sort within each category, drag it to reorder, or right-click it to add or remove columns. Requires a UI reload.",
		Items(DISPLAY_MODES),
		function() return P().bagDisplayMode == "list" and "list" or "grid" end,
		function() return Label(DISPLAY_MODES, P().bagDisplayMode == "list" and "list" or "grid") end,
		function(v)
			if v == (P().bagDisplayMode == "list" and "list" or "grid") then return end
			P().bagDisplayMode = v
			if ns.RebuildSettingsPage then ns.RebuildSettingsPage() end
			ReloadPopup("Bag display changed. A UI reload is needed to apply.")
		end)
	p:Dropdown("Default Bag Type", "Which view bags (and the bank) open to by default. The bank has no MultiBag view, so MultiBag opens the bank to OneBank.",
		Items(BAG_TYPES),
		DefaultBagType,
		function() return Label(BAG_TYPES, DefaultBagType()) end,
		function(v)
			P().bagDefaultBagType = v
			local b = Bags()
			if b and b:IsVisible() then RefreshBags() end
		end)

	p:Slider("Window Scale", "Scale of the bag and bank windows.", 50, 150, 5,
		function() return math.floor((P().bagScale or 1) * 100 + 0.5) end,
		function(v)
			P().bagScale = v / 100
			local s = v / 100
			if _G.EUI_Bags then _G.EUI_Bags:SetScale(s) end
			if _G.EUI_BagsReagent then _G.EUI_BagsReagent:SetScale(s) end
			if _G.EUI_BagsWindow then _G.EUI_BagsWindow:SetScale(s) end
			local k = Bank()
			if k and k:IsVisible() then k:SetScale(s) end
		end)
	p:Toggle("Auto-Size to Fit", "Grow the bag window (more columns + taller, keeping its shape) so all of the active tab's slots are visible without scrolling. It only grows while open -- switching to a bigger tab enlarges it, smaller tabs keep the size -- and resets when you close the bags. Never smaller than your normal size.",
		function() return P().bagAutoSize == true end,
		function(v)
			P().bagAutoSize = v
			ResetAndRefreshBagLayout()
		end)

	p:Toggle("Move Bags Without Shift", "When enabled, left-click dragging the bag window will move it without needing to hold Shift.",
		function() return P().bagMoveNoShift or false end,
		function(v) P().bagMoveNoShift = v end)
	p:Toggle("Stack Splitter", "Also use the split dialog with Auto Split in OneBag, MultiBag, the bank and the guild bank, replacing Blizzard's split popup there. All Items and category views always use it.",
		function() return P().bagStackSplitter == true end,
		function(v) P().bagStackSplitter = v and true or false end)

	p:Toggle("Allow Windows Over Bags", "Click another window, such as the Auction House, to bring it in front of the bags. Click the bags to bring them forward again. Frame Strata overrides it once set.",
		function() return P().bagAllowWindowsOverBags ~= false end,
		function(v)
			P().bagAllowWindowsOverBags = v and true or false
			local b = Bags()
			if b and b.ApplyWindowLayering then b:ApplyWindowLayering() end
		end)
	local STRATA = { { "BACKGROUND", "Background" }, { "LOW", "Low" }, { "MEDIUM", "Medium" }, { "HIGH", "High" }, { "DIALOG", "Dialog" } }
	local function CurStrata()
		local q = P()
		return q.bagFrameStrata or (q.bagAllowWindowsOverBags == false and "HIGH" or "MEDIUM")
	end
	p:Dropdown("Frame Strata", "Controls the order that overlapping elements display in. Set higher to show above other elements.",
		Items(STRATA), CurStrata, function() return Label(STRATA, CurStrata()) end,
		function(v)
			P().bagFrameStrata = v
			local b = Bags()
			if b and b.ApplyWindowLayering then b:ApplyWindowLayering() end
		end)
	p:Toggle("Open Bags with Character Window", "The bags automatically open when the character window is opened and close again when the character window is closed.",
		function() return P().bagOpenWithCharacter == true end,
		function(v)
			P().bagOpenWithCharacter = v and true or false
			if _G.EUI_Bags and _G.EUI_Bags.HookCharacterFrame then _G.EUI_Bags:HookCharacterFrame() end
		end)
	p:Toggle("Hide Sidebar Icons When Collapsed", "Hides a collapsed sidebar; its expand arrow sits by the Inventory title.",
		function() return P().bagHideSidebarIconsCollapsed == true end,
		function(v)
			P().bagHideSidebarIconsCollapsed = v and true or false
			RefreshBags()
		end)

	p:Section("Items")
	p:Slider("Icon Zoom", "Crops the border of every item icon in bags and bank. 0 shows the full icon.", 0, 0.20, 0.01,
		function() return P().bagItemIconZoom or 0.08 end,
		function(v)
			P().bagItemIconZoom = v
			local b = Bags()
			if b and b.RefreshIconZoom then b:RefreshIconZoom() end
			local k = Bank()
			if k and k.RefreshIconZoom then k:RefreshIconZoom() end
		end)
	p:Toggle("Desaturate Junk Items", "Display junk items in a greyed-out style.",
		function() return P().bagDesaturateJunkItems == true end,
		function(v)
			P().bagDesaturateJunkItems = v
			RefreshBags()
		end)
	p:Cog("Junk Item Visuals", {
		{ type = "toggle", label = "Show Coin Icon", tip = "Show a coin on the corner of each junk item's icon (grid view).",
		  get = function() return P().bagShowJunkCoin == true end,
		  set = function(v) P().bagShowJunkCoin = v and true or false; RefreshBags() end },
	})

	p:Section("Categories")
	p:MultiSelect("Enabled Categories", "Turn sorting categories on or off. Items of a category that is off go to Miscellaneous.",
		CategoryItems, CategoryEnabled, ToggleCategory, CategoriesLabel)
	p:Toggle("Hide Categories with 0 Items", "Hide sidebar categories that have no items in them.",
		function() return P().bagHideEmptyCategories ~= false end,
		function(v)
			P().bagHideEmptyCategories = v
			RefreshBags()
		end)

	p:Toggle("Hide 'Add Category' Tab", "Hides the Add Category button at the bottom of the bag sidebar.",
		function() return P().bagHideAddCategory or false end,
		function(v)
			P().bagHideAddCategory = v
			RefreshBags()
		end)
	p:Toggle("Split Set Gear by Set", "Show one sub-category per equipment set (named after the set) nested under Item Set Gear. Gear in several sets goes to the first one.",
		function() return P().bagSplitSetGearBySet == true end,
		function(v)
			P().bagSplitSetGearBySet = v
			local b = Bags()
			if b and b.InvalidateSetCategories then
				b.InvalidateSetCategories()
			elseif _G.EUI_CategoryManager then
				_G.EUI_CategoryManager:OnEquipmentSetsChanged()
			end
			if b and b.UpdateSetEventRegistration then b.UpdateSetEventRegistration() end
			RefreshBags()
		end)

	p:Section("Pinned & Recent")
	p:Toggle("Show Pinned Items", "Show the Pinned Items category in the sidebar and content grid.",
		function() return P().bagShowPinnedItems ~= false end,
		function(v)
			P().bagShowPinnedItems = v
			RefreshBags()
		end)
	p:Cog("Pinned Items Options", {
		{ type = "toggle", label = "Show in OneBag/MultiBag",
		  get = function() return P().bagPinnedInOneBag ~= false end,
		  set = function(v) P().bagPinnedInOneBag = v; RefreshBags() end },
		{ type = "toggle", label = "Hide from Other Categories", tip = "Pinned items show only in Pinned Items, not in their categories or Recent Items.",
		  get = function() return P().bagHidePinnedInCategories == true end,
		  set = function(v) P().bagHidePinnedInCategories = v; RefreshBags() end },
	}, { disabled = function() return P().bagShowPinnedItems == false end, disabledTip = "Show Pinned Items" })
	p:Toggle("Show Recent Items", "Show the Recent Items category in the sidebar and content grid for newly acquired items.",
		function() return P().bagShowRecentItems ~= false end,
		function(v)
			P().bagShowRecentItems = v
			RefreshBags()
		end)
	p:Cog("Recent Items Options", {
		{ type = "toggle", label = "Show in OneBag/MultiBag",
		  get = function() return P().bagRecentInOneBag == true end,
		  set = function(v) P().bagRecentInOneBag = v; RefreshBags() end },
		{ type = "toggle", label = "Show Clear Button",
		  get = function() return P().bagShowRecentClear == true end,
		  set = function(v) P().bagShowRecentClear = v; RefreshBags() end },
	}, { disabled = function() return P().bagShowRecentItems == false end, disabledTip = "Show Recent Items" })

	if anyGrid then
		p:Section("Grid View")
		p:Toggle("Show Item Level", "Display item levels on equipment items in the inventory.",
			function() return P().showItemlevelInBags ~= false end,
			function(v)
				P().showItemlevelInBags = v
				RefreshBags()
			end)
		p:Cog("Item Level Options", {
			{ type = "toggle", label = "Show Gear Track Rank",
			  tip = "5.4.8: the item upgrade level (1/2, 2/2) of upgraded gear, in the stack count corner.",
			  get = function() return P().bagShowTrackRank or false end,
			  set = function(v) P().bagShowTrackRank = v; RefreshBags() end },
		}, { disabled = function() return P().showItemlevelInBags == false end, disabledTip = "Show Item Level" })
		p:Slider("Item Level Text Size", "Font size for item level numbers on equipment items.", 8, 16, 1,
			function() return P().itemlevelFontSize or 12 end,
			function(v)
				P().itemlevelFontSize = v
				TextSizes()
			end)

		p:Toggle("Show BoE / Warbound Text", "Display Binds on Equipped on equipment items in your bags and bank.",
			function() return P().bagDisplayBindType end,
			function(v)
				P().bagDisplayBindType = v
				RefreshBags()
				RefreshBank()
			end)
		p:Cog("BoE / Warbound Text Options", {
			{ type = "slider", label = "Text Size", min = 8, max = 16, step = 1,
			  get = function() return P().bagBindTypeFontSize or 11 end,
			  set = function(v) P().bagBindTypeFontSize = v; TextSizes() end },
		}, { icon = "resize", disabled = function() return not P().bagDisplayBindType end, disabledTip = "Show BoE / Warbound Text" })
		p:Slider("Item Count Text Size", "Font size for stack counts, keystone levels, and dungeon abbreviations.", 8, 16, 1,
			function() return P().bagCountFontSize or 11 end,
			function(v)
				P().bagCountFontSize = v
				TextSizes()
			end)

		if not bagList then
			p:Toggle("Merge Duplicate Items", "Show copies of the same item that sit in separate bag slots as one icon with their counts added together. Turn this off to keep every slot separate, for example when you deliberately split stacks. Merging is always paused while the mail, trade, auction house, vendor, bank or guild bank window is open, since those take one bag slot at a time.",
				function() return P().bagMergeDuplicates ~= false end,
				function(v)
					P().bagMergeDuplicates = v
					RefreshBags()
				end)
			p:Toggle("Show Set Name on Gear", "Display the equipment set's name at the bottom of bag items that belong to one of your equipment sets.",
				function() return P().bagShowSetGearName == true end,
				function(v)
					P().bagShowSetGearName = v
					local b = Bags()
					if b and b.UpdateSetEventRegistration then b.UpdateSetEventRegistration() end
					RefreshBags()
				end)
			p:Cog("Set Name Text Options", {
				{ type = "slider", label = "Text Size", min = 7, max = 14, step = 1,
				  get = function() return P().bagSetNameFontSize or 9 end,
				  set = function(v) P().bagSetNameFontSize = v; TextSizes() end },
			}, { icon = "resize", disabled = function() return P().bagShowSetGearName ~= true end, disabledTip = "Show Set Name on Gear" })

			p:Slider("Category Title Size", "Font size for category titles in the sidebar and content grid.", 8, 16, 1,
				function() return P().bagCatTitleSize or 11 end,
				function(v)
					P().bagCatTitleSize = v
					RefreshBags()
				end)
			p:Toggle("Nest by Expansion", "In the All Items bag view, show each category's items under indented expansion sub-headers (newest expansions first), even when everything in that category is from one expansion.",
				function() return P().bagNestByExpansion == true end,
				function(v)
					P().bagNestByExpansion = v and true or false
					RefreshBags()
				end)

			local function ArmoryOff()
				local dc = P().bagDisabledCategories
				return dc and dc["Armor"] == true
			end
			p:Toggle("Group Armory by Slot", "In The Armory and the Weapons / Trinkets, Armor, and Item Set Gear category views, group items under equip-slot sub-headers (Head, Shoulders, Chest, ...). Does not add sidebar views.",
				function() return P().bagArmoryGroupBySlot == true end,
				function(v)
					P().bagArmoryGroupBySlot = v and true or false
					ResetAndRefreshBagLayout()
				end, ArmoryOff)
			p:Cog("Armory Slot Group Options", {
				{ type = "toggle", label = "Compact Slot Groups",
				  tip = "Place smaller Armory slot groups beside each other and fill the unused end of each row with empty-slot blocks. Large groups still use full rows.",
				  get = function() return P().bagCompactArmorySlotGroups == true end,
				  set = function(v) P().bagCompactArmorySlotGroups = v and true or false; ResetAndRefreshBagLayout() end },
			}, { disabled = function() return ArmoryOff() or P().bagArmoryGroupBySlot ~= true end, disabledTip = "Group Armory by Slot" })
			p:Toggle("Show Pinned & Recent Tips", "Show helpful tip text on Pinned Items and Recent Items category headers.",
				function() return P().bagShowPinRecentTips ~= false end,
				function(v)
					P().bagShowPinRecentTips = v
					RefreshBags()
				end)

			p:Toggle("Hide OneBag Randomize Button", "Hide the randomize (dice) button in the OneBag view.",
				function() return P().bagHideRandomize == true end,
				function(v)
					P().bagHideRandomize = v
					RefreshBags()
				end)
			p:Blank()
		end
	end

	if anyList then
		p:Section("List View")
		p:Slider("Left Gap", "Empty space between this side of the bag and bank lists and their rows.", 0, 50, 1,
			function() return P().bagListGapL or 15 end,
			function(v) P().bagListGapL = v; RefreshBags(); RefreshBank() end)
		p:Slider("Right Gap", "Empty space between this side of the bag and bank lists and their rows.", 0, 50, 1,
			function() return P().bagListGapR or 23 end,
			function(v) P().bagListGapR = v; RefreshBags(); RefreshBank() end)

		p:Toggle("Round Icons", "Show the item icons in the bag and bank lists as circles instead of squares.",
			function() return P().bagListRoundIcons == true end,
			function(v) P().bagListRoundIcons = v and true or false; RefreshBags(); RefreshBank() end)
		p:Slider("List Text Size", "Text size of the bag and bank lists.", 8, 16, 1,
			function() return P().bagListFontSize or 11 end,
			function(v) P().bagListFontSize = v; RefreshBags(); RefreshBank() end)

		p:Slider("Row Height", "Height of each row in the bag and bank lists. Icons shrink to fit short rows.", 16, 32, 1,
			function() return P().bagListRowHeight or 24 end,
			function(v) P().bagListRowHeight = v; RefreshBags(); RefreshBank() end)
		p:Toggle("Quality Icon Border", "Draw a border in the item's quality color around square icons in the bag and bank lists.",
			function() return P().bagListQualityBorder == true end,
			function(v) P().bagListQualityBorder = v and true or false; RefreshBags(); RefreshBank() end,
			function() return P().bagListRoundIcons == true end)

		p:Toggle("Hide Row Stripes", "Remove the shading on every other row in the bag and bank lists.",
			function() return P().bagListHideStripes == true end,
			function(v) P().bagListHideStripes = v and true or false; RefreshBags(); RefreshBank() end)
		if bagList then
			p:Toggle("Show Section Value", "Show the total vendor sell price of each section's items next to its count in the bag list.",
				function() return P().bagListSectionValue == true end,
				function(v) P().bagListSectionValue = v and true or false; RefreshBags() end)

			p:Toggle("Split Armor by Type", "In the list, group armor under sub-headers by armor type (Cloth, Leather, Mail, Plate, ...).",
				function() return P().bagListSplitArmor == true end,
				function(v) P().bagListSplitArmor = v and true or false; RefreshBags() end)
			p:Toggle("Split Weapons by Type", "In the list, group weapons under sub-headers by weapon type (Swords, Staves, Bows, ...).",
				function() return P().bagListSplitWeapons == true end,
				function(v) P().bagListSplitWeapons = v and true or false; RefreshBags() end)

			p:Toggle("Split Professions by Type", "In the list, group profession items, recipes and trade goods under sub-headers by profession or material (Tailoring, Enchanting, Herb, Cloth, ...).",
				function() return P().bagListSplitProfessions == true end,
				function(v) P().bagListSplitProfessions = v and true or false; RefreshBags() end)
			p:Toggle("Merge Duplicate Items", "In the list, show copies of the same item that sit in separate bag slots, including unstackable items, as one row with their counts added together. Gear is never merged, and OneBag and MultiBag always show every slot. Merging is paused while the mail, trade, auction house, vendor, bank or guild bank window is open.",
				function() return P().bagListMergeDuplicates == true end,
				function(v) P().bagListMergeDuplicates = v and true or false; RefreshBags() end)
		else
			p:Blank()
		end
	end

	p:Section("Extras")
	-- Bag Top Bar Icons (retail): which header icons show.
	local TOP_ICONS = { { value = "bagShowBagsIcon", name = "Bags Icon" }, { value = "bagShowSortIcon", name = "Sort Icon" } }
	p:MultiSelect("Bag Top Bar Icons", "Choose which icons show in the bag window's top bar.",
		function() return TOP_ICONS end,
		function(k) return P()[k] ~= false end,
		function(k)
			P()[k] = P()[k] == false
			local b = Bags()
			if b and b.SyncHeaderIcons then b:SyncHeaderIcons() end
		end,
		function()
			local on = {}
			for _, it in ipairs(TOP_ICONS) do
				if P()[it.value] ~= false then on[#on + 1] = it.name end
			end
			return #on > 0 and table.concat(on, ", ") or "None"
		end)
	p:Cog("Sort Options", {
		{ type = "toggle", label = "Sort to Bottom",
		  tip = "Sorting normally packs your items into the first free slots, at the top of the grid. Turn this on to pack them into the last slots instead, so the empty slots end up at the top. The item order itself does not change. This affects the OneBag, MultiBag and bank views -- category views fill their own grid with no gaps, so there is nothing to move.",
		  get = function() return P().bagSortToBottom == true end,
		  set = function(v) P().bagSortToBottom = v and true or false end },
	}, { disabled = function() return P().bagShowSortIcon == false end, disabledTip = "Show Sort Icon" })
	p:Toggle("Gold Tracking and History", "Track and display gold amounts from all your characters on hover.",
		function() return P().enableGoldTracking ~= false end,
		function(v) P().enableGoldTracking = v end)

	p:MultiSelect("Enabled Currencies", "Currencies shown in the bag footer, for this character. The currency tab's Show on Backpack checkbox adds and removes them too.",
		CurrencyItems, CurrencyTracked, ToggleCurrency, CurrenciesLabel)
	p:Toggle("Hide OneBag/MultiBag Warning", "Hide the warning text at the top of the OneBag and MultiBag views.",
		function() return P().bagHideOneBagWarning == true end,
		function(v)
			P().bagHideOneBagWarning = v
			RefreshBags()
		end)
end

---------------------------------------------------------------------------
-- Bank page
---------------------------------------------------------------------------
local function BuildBank(p)
	p:Paragraph("Each bank bag you place in a bank bag slot is a tab of its own in the bank sidebar.\nWindow scale, icon zoom and item level settings are shared with the Bags page.")

	p:Section("Display")
	p:Toggle("List View", "Show one row per item instead of the icon grid, with the same columns, sorting and round icon option as the bags List display. Empty slots and headers with no items are hidden. Click a column name on the bank window to sort, drag it to reorder, or right-click it to add or remove columns. Requires a UI reload.",
		function() return P().bankListView == true end,
		function(v)
			v = v and true or false
			if v == (P().bankListView == true) then return end
			P().bankListView = v
			ReloadPopup("Bank display changed. A UI reload is needed to apply.")
		end)
	p:Blank()

	p:Section("Grouping")
	p:Toggle("Nest by Expansion", "In the OneBank view, split the grid under expansion headers, newest first. Per-tab views are unaffected.",
		function() return P().bankNestByExpansion == true end,
		function(v) P().bankNestByExpansion = v and true or false; RefreshBank() end)
	p:Toggle("Group by Category", "Split items by category -- Armor, Consumables, Professions and so on -- using the same category list, order and renames as the All Items bag view. Nests inside the expansion headers when Nest by Expansion is also on. Categories that split further do so automatically: gear by equipment slot, Professions and Trade Goods by profession and material type.",
		function() return P().bankGroupByCategory == true end,
		function(v) P().bankGroupByCategory = v and true or false; RefreshBank() end)

	p:Section("Sidebar")
	p:Toggle("Category Sidebar", "List item categories in the bank sidebar the way the bags sidebar does -- groups such as The Armory with Weapons and Armor under them. Selecting one filters the grid to that category. Categories that split further list their parts as a third level while selected: Professions by profession, Armor by equipment slot, Trade Goods by material.",
		function() return P().bankCategorySidebar == true end,
		function(v) P().bankCategorySidebar = v and true or false; RefreshBank() end)
	p:Toggle("Hide Bank Tabs in Sidebar", "Drop the individual Bank / bank bag entries once the category list is doing the navigating. The consolidated views stay.",
		function() return P().bankHideTabsInSidebar == true end,
		function(v) P().bankHideTabsInSidebar = v and true or false; RefreshBank() end,
		function() return P().bankCategorySidebar ~= true end)

	p:Toggle("Hide Empty Slots When Grouped", "While either grouping toggle is on, drop the trailing block of empty slots so the view only shows items. Turn this off to keep the free slots visible for depositing.",
		function() return P().bankHideEmptyWhenNested == true end,
		function(v) P().bankHideEmptyWhenNested = v and true or false; RefreshBank() end,
		function()
			return P().bankListView == true or not (P().bankNestByExpansion or P().bankGroupByCategory)
		end)
	p:Blank()
end

ns.RegisterSettingsModule({
	key = "bags",
	name = "Bags",
	group = "UI Reskin Addons",
	tabs = {
		{ key = "bags", name = "Bags", description = "Enhanced inventory system with sidebar categories, item levels, and quality borders.", build = BuildBags,
		  -- Grid View / List View sections follow the display modes.
		  pageKey = function() return (P().bagDisplayMode == "list" and "list" or "grid") .. (P().bankListView and ":banklist" or "") end },
		{ key = "bank", name = "Bank", description = "Enhanced inventory system with sidebar categories, item levels, and quality borders.", build = BuildBank },
	},
	reset = function()
		if ns._bagsReset then ns._bagsReset() end
	end,
	resetTip = "Set all Bags settings back to default (also clears pinned items, item assignments, gold history and tracked currencies).",
})
