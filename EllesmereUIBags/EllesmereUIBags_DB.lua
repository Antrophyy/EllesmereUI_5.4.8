setfenv(1, select(2, ...).env) -- 5.4.8 port: retail APIs from EllesmereUIBags_Compat.lua
-------------------------------------------------------------------------------
--  EllesmereUIBags_DB.lua
--  Bags profile database + login-time seeding. Lives in the resident module
--  (first in the TOC, the options file's old slot) so the DB exists from login
--  regardless of the LoadOnDemand options surface. NewDB stays at Bags
--  file-execution time: the suite-safe window (after the parent's SVs) and, in
--  standalone builds, the pre-SV window the Lite re-root queue handles.
-------------------------------------------------------------------------------
local addonNS = select(2, ...)
local BAGS_DEFAULTS = {
    profile = {
        bagScale              = 1,
        bagItemIconZoom       = 0.08,
        bagColumns            = 12,
        bagAutoSize           = false,
        bagCatTitleSize       = 11,
        bagCountFontSize      = 11,
        bagShowCooldownText   = false,
        bagCooldownFontSize   = 11,
        itemlevelFontSize     = 12,
        showItemlevelInBags   = true,
        showUpgradeIndicator  = true,
        bagShowTrackRank      = false,
        itemlevelUseCustomColor = false,
        bagHideEmptyCategories = true,
        bagSplitSetGearBySet  = false,
        bagShowSetGearName    = false,
        bagSetNameFontSize    = 9,
        bagMergeDuplicates    = true,
        bagListMergeDuplicates = false,
        bagSidebarCollapsed   = false,
        bankSidebarCollapsed  = false,
        bagShowPinnedItems    = true,
        bagShowRecentItems    = true,
        bagPinnedInOneBag     = true,
        bagRecentInOneBag     = false,
        bagShowRecentClear    = false,
        bagShowPinRecentTips  = true,
        bagShowSortIcon       = true,
        bagSortToBottom       = false,
        bagHideRandomize      = false,
        bagDefaultBagType     = "all",   -- "all" | "onebag" | "multibag"
        bagDefaultOneBag      = false,   -- legacy; migrated to bagDefaultBagType
        bagNestByExpansion    = false,
        bankNestByExpansion   = false,
        bankGroupByCategory   = false,
        bankCategorySidebar   = false,
        bankHideTabsInSidebar = false,
        bankHideEmptyWhenNested = false,
        bankListView          = false,  -- reload to apply
        bagArmoryGroupBySlot  = false,
        bagCompactArmorySlotGroups = false,
        bagHideOneBagWarning  = false,
        bagHideAddCategory    = false,
        bagMoveNoShift        = false,
        bagAllowWindowsOverBags = true,
        bagStackSplitter      = false,
        enableGoldTracking    = true,
        detachReagentBag      = false,
        enhancedBags          = true,
        bagDesaturateJunkItems = false,
        bagDisplayBindType    = false,
        bagBindTypeFontSize   = 11,
        bagDisplayMode        = "grid",  -- "grid" | "list" (reload to apply)
        bagListRoundIcons     = false,
        bagListSplitArmor     = false,
        bagListSplitWeapons   = false,
        bagListSplitProfessions = false,
        bagListGapL           = 15,
        bagListGapR           = 23,
        bagListFontSize       = 11,
        bagListRowHeight      = 24,
        bagListQualityBorder  = false,
        bagListHideStripes    = false,
        bagListSectionValue   = false,
    },
}
local db = EllesmereUI.Lite.NewDB("EllesmereUIBagsDB", BAGS_DEFAULTS)
EllesmereUI._bagsDB = db

-------------------------------------------------------------------------------
--  5.4.8 port: the bag settings of the retail EllesmereUI profile ("Naowh"),
--  written once into a new EllesmereUIBagsDB so the bags look the same as on
--  retail. Reset Bags goes back to the EllesmereUI defaults above, as retail.
-------------------------------------------------------------------------------
local RETAIL_PROFILE = {
    bagDefaultBagType     = "onebag",
    bagMergeDuplicates    = false,
    bagAutoSize           = true,
    bagHideRandomize      = true,
    bagArmoryGroupBySlot  = true,
    bagHideOneBagWarning  = true,
    bagSidebarCollapsed   = true,
    bagCountFontSize      = 14,
    bagCatTitleSize       = 14,
    itemlevelFontSize     = 14,
    bagDisabledCategories = { ["Housing"] = true },
    bagHiddenInAllItems   = {},
    bagCategoryState = {
        ["Weapons / Trinkets"] = { groupName = "The Armory", groupNameCustom = true },
        ["Armor"]              = { groupName = "The Armory", groupNameCustom = true },
        ["Item Set Gear"]      = { groupName = "The Armory", groupNameCustom = true },
        ["Consumables"]        = { groupName = "Adventure Prep", groupNameCustom = true },
        ["Gear Enhancements"]  = { groupName = "Adventure Prep", groupNameCustom = true },
    },
    bagCategoryOrder = {
        "Pinned Items", "Recent Items", "Weapons / Trinkets", "Armor", "Item Set Gear",
        "Consumables", "Gear Enhancements", "Trade Goods", "Professions", "Reagent Bag",
        "Miscellaneous", "Quest Items", "Housing",
    },
}

local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("ADDON_LOADED")
loadFrame:SetScript("OnEvent", function(self, _, name)
    if name ~= "EllesmereUIBags" then return end
    self:UnregisterEvent("ADDON_LOADED")
    addonNS.AttachSavedVariables()
    if db._isNew then
        local p = db.profile
        for k, v in pairs(RETAIL_PROFILE) do
            p[k] = type(v) == "table" and CopyTable(v) or v
        end
        if not EllesmereUIDB then EllesmereUIDB = {} end
        -- The retail first-run seeding below already happened there.
        EllesmereUIDB.bagDisabledCategoriesSeeded = true
        EllesmereUIDB.bagDefaultGroupsSeeded = true
    end
    if _G.EUI_CategoryManager then _G.EUI_CategoryManager:InitCategories() end
end)

-- Footer "Reset Bags" (retail onReset): the profile back to the defaults, and
-- the per-character data in EllesmereUIDB cleared.
function EllesmereUI._bagsReset()
    local p = db.profile
    if p then
        for k in pairs(p) do p[k] = nil end
        EllesmereUI.Lite.DeepMergeDefaults(p, db._profileDefaults)
    end
    if EllesmereUIDB then
        EllesmereUIDB.bagPinnedItems = nil
        EllesmereUIDB.bagItemAssignments = nil
        EllesmereUIDB.characterGold = nil
        EllesmereUIDB.warbandGold = nil
        EllesmereUIDB.bagCurrencyByChar = nil
    end
    if _G.EUI_CategoryManager then _G.EUI_CategoryManager:InitCategories() end
    if _G.EUI_Bags and _G.EUI_Bags.ApplyWindowLayering then _G.EUI_Bags:ApplyWindowLayering() end
    if _G.EUI_Bags and _G.EUI_Bags:IsVisible() and _G.EUI_Bags.RefreshInventory then _G.EUI_Bags:RefreshInventory() end
    if _G.EUI_Bags and _G.EUI_Bags.RefreshCooldowns then _G.EUI_Bags:RefreshCooldowns() end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")

    if not EllesmereUIDB then EllesmereUIDB = {} end
    local p = db.profile

    -- 5.4.8 port: ElvUI's own bags take over the same bag keys and the bank.
    local E = _G.ElvUI and _G.ElvUI[1]
    if E and E.private and E.private.bags and E.private.bags.enable then
        EllesmereUI.Print("ElvUI Bags is on. Turn it off (ElvUI > Bags > Enable) to use EllesmereUI Bags, or disable EllesmereUI Bags in the AddOns list.")
    end

    -- The bank grouping dropdowns were replaced by two toggles. Convert the
    -- short-lived string keys once, then drop them.
    if p.bankGroupBy ~= nil then
        if p.bankGroupBy == "category" then
            p.bankGroupByCategory = true
        elseif p.bankGroupBy == "expansion" then
            p.bankNestByExpansion = true
        end
        p.bankGroupBy = nil
        p.bankSubGroupBy = nil
    end

    -- Default disabled categories: Housing and Quest Items off by default
    if EllesmereUIDB.bagDisabledCategoriesSeeded == nil then
        EllesmereUIDB.bagDisabledCategoriesSeeded = true
        if not p.bagDisabledCategories then p.bagDisabledCategories = {} end
        p.bagDisabledCategories["Housing"] = true
        p.bagDisabledCategories["Quest Items"] = true
    end

    -- Default category groups and order
    if not EllesmereUIDB.bagDefaultGroupsSeeded then
        EllesmereUIDB.bagDefaultGroupsSeeded = true
        -- Only seed if user has no existing customization
        if not p.bagCategoryState and not p.bagCategoryOrder then
            p.bagCategoryState = {
                ["Weapons / Trinkets"] = { groupName = "The Armory", groupNameCustom = true },
                ["Armor"]              = { groupName = "The Armory", groupNameCustom = true },
                ["Item Set Gear"]      = { groupName = "The Armory", groupNameCustom = true },
                ["Consumables"]        = { groupName = "Adventure Prep", groupNameCustom = true },
                ["Gear Enhancements"]  = { groupName = "Adventure Prep", groupNameCustom = true },
            }
            p.bagCategoryOrder = {
                "Pinned Items",
                "Recent Items",
                "Weapons / Trinkets",
                "Armor",
                "Item Set Gear",
                "Consumables",
                "Gear Enhancements",
                "Trade Goods",
                "Professions",
                "Reagent Bag",
                "Miscellaneous",
                "Quest Items",
                "Housing",
            }
            -- Re-init categories with the new state
            if _G.EUI_CategoryManager then
                _G.EUI_CategoryManager:InitCategories()
            end
        end
    end
    -- Migrate old numeric-keyed disabled categories to name-keyed
    if p.bagDisabledCategories and _G.EUI_CategoryManager then
        local dc = p.bagDisabledCategories
        local cats = _G.EUI_CategoryManager:GetCategories()
        local migrated = {}
        local changed = false
        for k, v in pairs(dc) do
            if type(k) == "number" then
                if cats[k] then migrated[cats[k]._defaultName] = v end
                changed = true
            else
                migrated[k] = v
            end
        end
        if changed then p.bagDisabledCategories = migrated end
    end
end)
