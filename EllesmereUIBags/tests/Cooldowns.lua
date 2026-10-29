-- Run with Lua 5.1 from the repository root. No game installation is accessed.
assert(_VERSION == "Lua 5.1", "These checks must run on Lua 5.1.")

local passed, failures = 0, {}
local function Equal(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function Upvalue(fn, key)
    for i = 1, 60 do
        local name, value = debug.getupvalue(fn, i)
        if name == key then return value end
        if not name then break end
    end
    error("Missing upvalue: " .. key)
end
local noop = function() end
local now, queries, combat = 1000, 0, false
local frames, itemButtons, cooldowns = {}, {}, {}
local refreshes, secureCreates = 0, 0

local Frame = {}
Frame.__index = Frame
local function Object(kind, parent)
    local f = setmetatable({
        kind = kind, parent = parent, scripts = {}, events = {}, children = {}, texts = {},
        shown = true, width = 34, height = 34, level = 1, id = 0,
    }, Frame)
    if parent then parent.children[#parent.children + 1] = f end
    return f
end
function Frame:IsShown() return self.shown end
function Frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
local function Visibility(self, shown)
    if self.shown == shown then return end
    local before, list = {}, {}
    local function Collect(f)
        list[#list + 1] = f
        before[f] = f:IsVisible()
        for _, child in ipairs(f.children) do Collect(child) end
    end
    Collect(self)
    self.shown = shown
    for _, f in ipairs(list) do
        local visible = f:IsVisible()
        if visible ~= before[f] then
            local fn = f.scripts[visible and "OnShow" or "OnHide"]
            if fn then fn(f) end
        end
    end
end
function Frame:Show() Visibility(self, true) end
function Frame:Hide() Visibility(self, false) end
function Frame:SetShown(shown) Visibility(self, shown and true or false) end
function Frame:SetScript(event, fn) self.scripts[event] = fn end
function Frame:GetScript(event) return self.scripts[event] end
function Frame:HookScript(event, fn)
    local old = self.scripts[event]
    self.scripts[event] = function(...)
        if old then old(...) end
        fn(...)
    end
end
function Frame:RegisterEvent(event) self.events[event] = true end
function Frame:UnregisterEvent(event) self.events[event] = nil end
function Frame:UnregisterAllEvents() self.events = {} end
function Frame:SetSize(w, h) self.width, self.height = w, h end
function Frame:SetWidth(w) self.width = w end
function Frame:SetHeight(h) self.height = h end
function Frame:GetWidth() return self.width end
function Frame:GetHeight() return self.height end
function Frame:SetID(id) self.id = id end
function Frame:GetID() return self.id end
function Frame:GetParent() return self.parent end
function Frame:SetParent(parent) self.parent = parent end
function Frame:SetPoint(...) self.point = { ... } end
function Frame:ClearAllPoints() self.point = nil end
function Frame:SetAllPoints(anchor) self.anchor = anchor or self.parent end
function Frame:SetFrameLevel(level) self.level = level end
function Frame:GetFrameLevel() return self.level end
function Frame:SetFont(path, size, flags) self.font, self.size, self.flags = path, size, flags end
function Frame:SetText(text) self.text = text end
function Frame:GetText() return self.text end
function Frame:SetTexture(texture) self.texture = texture end
function Frame:GetTexture() return self.texture end
function Frame:GetStringWidth() return #(self.text or "") * 6 end
function Frame:SetCooldown(start, duration)
    self.start, self.duration = start, duration
    self.cooldownCalls = (self.cooldownCalls or 0) + 1
    self:Show()
end
function Frame:Clear() self:Hide() end
function Frame:SetOwner(owner) self.owner = owner end
function Frame:IsOwned(owner) return self.owner == owner end
function Frame:CreateTexture() return Object("Texture", self) end
function Frame:CreateFontString()
    local text = Object("FontString", self)
    self.texts[#self.texts + 1] = text
    return text
end
function Frame:GetHighlightTexture() return self.highlight end
function Frame:GetPushedTexture() return self.pushed end
function Frame:SetItemButtonTexture(texture) self.icon:SetTexture(texture) end
function Frame:SetItemButtonCount(count) self.count = count end
for _, method in ipairs({
    "EnableMouse", "RegisterForClicks", "RegisterForDrag", "SetTexCoord", "SetVertexColor", "SetTextColor",
    "SetAlpha", "SetJustifyH", "SetWordWrap", "SetMaxLines", "SetDrawEdge", "SetHideCountdownNumbers",
    "SetItemButtonQuality", "SetDesaturated", "SetRotation", "SetFrameStrata", "EnableMouseWheel",
}) do Frame[method] = noop end
function CreateFrame(kind, name, parent, template)
    if template == "ContainerFrameItemButtonTemplate" then
        assert(not combat, "created a secure item button during combat")
        secureCreates = secureCreates + 1
    end
    local f = Object(kind, parent)
    frames[#frames + 1] = f
    if name then _G[name] = f end
    if template == "ContainerFrameItemButtonTemplate" then
        f.icon = f:CreateTexture()
        f.Count = f:CreateFontString()
        f.Cooldown = CreateFrame("Cooldown", nil, f)
        f.Cooldown:Hide()
        itemButtons[#itemButtons + 1] = f
    end
    return f
end
function GetTime() return now end
function InCombatLockdown() return combat end
function tIndexOf(list, value)
    for i = 1, #list do if list[i] == value then return i end end
end
function SetItemButtonDesaturated(btn, desaturated) btn.desaturated = desaturated end
function wipe(t) for key in pairs(t) do t[key] = nil end; return t end
function CopyTable(t)
    local copy = {}
    for key, value in pairs(t) do copy[key] = type(value) == "table" and CopyTable(value) or value end
    return copy
end
UIParent = CreateFrame("Frame")
GameTooltip = CreateFrame("GameTooltip")
EUI_Bags = CreateFrame("Frame", nil, UIParent)
EUI_Bags.RefreshInventory = function() refreshes = refreshes + 1 end
EUI_Bags.RunItemOverlays = noop
EUI_Bags.itemOverlayIcons = {}
EUI_Bags.ShowStackSplitter = noop
ITEM_QUALITY_COLORS = { [1] = { r = 1, g = 1, b = 1 } }
EllesmereUI = {
    applyHooks = {}, L = function(text) return text end,
    SlugFlag = function() return "OUTLINE" end,
    GetFontPath = function() return "bags-font" end,
    GetFontOutlineFlag = function() return "OUTLINE" end,
    PrimeFontShadow = noop, _BagsItemUnusable = function() return false end,
    ApplyIconTextFont = function(text, path, size, module)
        text:SetFont(path, size, "OUTLINE")
        text.module = module
    end,
    Lite = {},
}
function EllesmereUI.Lite.DeepMergeDefaults(dst, src)
    for key, value in pairs(src) do
        if dst[key] == nil then dst[key] = type(value) == "table" and CopyTable(value) or value end
    end
end
function EllesmereUI.Lite.NewDB(name, defaults)
    local db = _G[name] or {}
    db.profile = db.profile or {}
    EllesmereUI.Lite.DeepMergeDefaults(db.profile, defaults.profile)
    db._profileDefaults = CopyTable(defaults.profile)
    _G[name] = db
    return db
end
C_Container = {
    GetContainerItemCooldown = function(bag, slot)
        queries = queries + 1
        local cd = cooldowns[bag] and cooldowns[bag][slot]
        if cd then return cd[1], cd[2], cd[3] end
        return 0, 0, 1
    end,
}
C_Item = {
    GetItemInfo = function() return "Item", nil, 1, 1, 1, "Miscellaneous", "", 1, "", "icon", 0, 15, 0, 0 end,
    GetItemInfoInstant = function() return 1, "Miscellaneous", "", "", "icon", 15, 0 end,
    GetItemQualityColor = function() return 1, 1, 1 end,
}
Enum = {
    ItemClass = { Armor = 4, Weapon = 2, Tradegoods = 7, Reagent = 5, Recipe = 9 },
    ItemBind = { OnAcquire = 1, OnEquip = 2, OnUse = 3, Quest = 4, ToWoWAccount = 7, ToBnetAccount = 8, ToBnetAccountUntilEquipped = 9 },
}
ItemLocation = { CreateEmpty = function() return {} end }

local ns = {
    env = setmetatable({}, { __index = _G, __newindex = _G }),
    GetFont = function() return EllesmereUI.GetFontPath("bags") end,
    SetBagFont = function(text, size) text:SetFont("bags-font", size, "OUTLINE") end,
    GetSelection = function() return 0 end, SLOT_SIZE = 34, SPACING = 4, itemSlots = {},
    SlotMiddleClick = noop, UpdatePawnArrow = noop, BankRoutePreClick = noop, BankRouteOnClick = noop,
    CreateInsetBorder = noop, SetInsetBorderColor = noop, SetInsetBorderThickness = noop,
    BagsItemUnusable = function() return false end,
}
function ns.SkinItemButton(btn)
    local overlay = CreateFrame("Frame", nil, btn)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(btn.Cooldown:GetFrameLevel() + 2)
    btn._textOverlay = overlay
    return overlay
end
local function Load(name) return assert(loadfile([[EllesmereUIBags\]] .. name))("EllesmereUIBags", ns) end
Load("EllesmereUIBags_DB.lua")
local profile = EllesmereUI._bagsDB.profile
Load("EllesmereUIBags_Cooldowns.lua")
local driver
for _, frame in ipairs(frames) do if frame.events.BAG_UPDATE_COOLDOWN then driver = frame end end
assert(driver, "no live bag cooldown listener registered")

local function Fire(bag)
    driver.scripts.OnEvent(driver, "BAG_UPDATE_COOLDOWN", bag)
end
local function Tick(seconds)
    now = now + seconds
    if driver:IsVisible() then driver.scripts.OnUpdate(driver, seconds) end
end
local function SetCooldown(bag, slot, start, duration, enabled)
    cooldowns[bag] = cooldowns[bag] or {}
    cooldowns[bag][slot] = { start, duration, enabled }
end
local function Text(btn)
    for _, text in ipairs((btn._textOverlay or btn).texts) do
        if text.module == "bags" then return text end
    end
end
local function Button(bag, slot, list)
    local parent = CreateFrame("Frame", nil, EUI_Bags)
    parent:SetID(bag)
    local btn = CreateFrame("ItemButton", nil, parent, "ContainerFrameItemButtonTemplate")
    btn:SetID(slot)
    ns.SkinItemButton(btn)
    if list then
        btn._lvIcon = btn:CreateTexture()
        btn._textOverlay:SetAllPoints(btn._lvIcon)
    end
    return btn
end
local function Test(name, fn)
    for _, btn in ipairs(itemButtons) do ns.ClearItemCooldown(btn); btn:Hide() end
    wipe(cooldowns)
    now, queries, refreshes, combat = 1000, 0, 0, false
    profile.bagShowCooldownText, profile.bagCooldownFontSize = false, 11
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("PASS " .. name)
    else
        failures[#failures + 1] = name .. ": " .. tostring(err)
        print("FAIL " .. failures[#failures])
    end
end

Test("defaults keep numbers opt-in with the bags icon font size", function()
    local defaults = EllesmereUI._bagsDB._profileDefaults
    Equal(defaults.bagShowCooldownText, false); Equal(defaults.bagCooldownFontSize, 11)
    Equal(driver:IsShown(), false)
end)
Test("using an item starts its swipe immediately while the same bag stays open", function()
    local btn = Button(0, 1)
    ns.UpdateItemCooldown(btn, 0, 1)
    Equal(btn.Cooldown:IsShown(), false); Equal(driver:IsShown(), false)
    SetCooldown(0, 1, now, 300, 1)
    Fire()
    Equal(btn.Cooldown:IsShown(), true); Equal(btn.Cooldown.start, 1000); Equal(btn.Cooldown.duration, 300)
    Equal(Text(btn), nil); Equal(refreshes, 0); Equal(driver:IsShown(), true)
end)
Test("bag-specific notifications refresh shared cooldowns and every pinned/recent copy", function()
    local copies = { Button(0, 1), Button(0, 1), Button(0, 1), Button(3, 2) }
    for i, btn in ipairs(copies) do ns.UpdateItemCooldown(btn, i == 4 and 3 or 0, i == 4 and 2 or 1) end
    SetCooldown(0, 1, now, 60, 1); SetCooldown(3, 2, now, 60, 1)
    Fire(0)
    for _, btn in ipairs(copies) do Equal(btn.Cooldown:IsShown(), true) end
    Equal(refreshes, 0)
end)
Test("cooldown text matches short buff-style durations and never shows zero before expiry", function()
    profile.bagShowCooldownText = true
    local btn = Button(0, 1)
    for _, case in ipairs({ { 148, "2m" }, { 90, "2m" }, { 60, "1m" }, { 28, "28" }, { 0.2, "1" }, { 3600, "1h" } }) do
        SetCooldown(0, 1, now, case[1], 1)
        ns.UpdateItemCooldown(btn, 0, 1)
        Equal(Text(btn):GetText(), case[2])
    end
    Equal(Text(btn).font, "bags-font"); Equal(Text(btn).size, 11)
    Equal(Text(btn).parent, btn._textOverlay); Equal(Text(btn).point[2], btn.icon)
end)
Test("one ticker counts down without querying or rebuilding inventory every frame", function()
    profile.bagShowCooldownText = true
    local btn = Button(0, 1)
    SetCooldown(0, 1, now, 3, 1)
    ns.UpdateItemCooldown(btn, 0, 1)
    Equal(Text(btn):GetText(), "3")
    local reads, calls = queries, btn.Cooldown.cooldownCalls
    Tick(1)
    Equal(Text(btn):GetText(), "2"); Equal(queries, reads); Equal(btn.Cooldown.cooldownCalls, calls)
    Tick(2)
    Equal(Text(btn):IsShown(), false); Equal(btn.Cooldown:IsShown(), false)
    Equal(driver:IsShown(), false); Equal(refreshes, 0)
end)
Test("ready, disabled, missing, and expired cooldowns clear stale visuals", function()
    profile.bagShowCooldownText = true
    local btn = Button(0, 1)
    for _, cd in ipairs({ { 0, 0, 1 }, { 1000, 300, 0 }, { 1000, 300, false }, { 500, 10, 1 }, {} }) do
        SetCooldown(0, 1, now, 300, 1); ns.UpdateItemCooldown(btn, 0, 1)
        SetCooldown(0, 1, cd[1], cd[2], cd[3]); Fire()
        Equal(btn.Cooldown:IsShown(), false); Equal(Text(btn):IsShown(), false)
        Equal(driver:IsShown(), false)
    end
end)
Test("unchanged cooldown events do not restart swipes, while reset/restart events do", function()
    local btn = Button(0, 1)
    SetCooldown(0, 1, now, 300, 1); ns.UpdateItemCooldown(btn, 0, 1)
    Fire(); Fire()
    Equal(btn.Cooldown.cooldownCalls, 1)
    SetCooldown(0, 1, now, 60, 1); Fire()
    Equal(btn.Cooldown.cooldownCalls, 2); Equal(btn.Cooldown.duration, 60)
    SetCooldown(0, 1, 0, 0, 1); Fire()
    Equal(btn.Cooldown:IsShown(), false)
end)
Test("pooled buttons follow their new slot and clear when emptied", function()
    profile.bagShowCooldownText = true
    local btn = Button(0, 1)
    SetCooldown(0, 1, now, 300, 1); ns.UpdateItemCooldown(btn, 0, 1)
    ns.UpdateItemCooldown(btn, 1, 2)
    Equal(btn.Cooldown:IsShown(), false); Equal(Text(btn):IsShown(), false)
    SetCooldown(1, 2, now, 25, 1); Fire()
    Equal(Text(btn):GetText(), "25")
    ns.ClearItemCooldown(btn)
    local reads = queries
    Fire(); Tick(1)
    Equal(queries, reads); Equal(btn.Cooldown:IsShown(), false); Equal(Text(btn):IsShown(), false)
end)
Test("hidden bag parents stop ticking and querying, and reopening reads fresh data", function()
    profile.bagShowCooldownText = true
    local btn = Button(0, 1)
    SetCooldown(0, 1, now, 300, 1); ns.UpdateItemCooldown(btn, 0, 1)
    btn:GetParent():Hide()
    Equal(driver:IsShown(), false); Equal(Text(btn):IsShown(), false)
    local reads = queries
    Fire(); Tick(1)
    Equal(queries, reads)
    SetCooldown(0, 1, now, 20, 1)
    btn:GetParent():Show()
    Equal(Text(btn):GetText(), "20"); Equal(btn.Cooldown:IsShown(), true)
end)
Test("an item first rendered while hidden starts on show", function()
    local btn = Button(0, 1)
    btn:Hide()
    SetCooldown(0, 1, now, 60, 1); ns.UpdateItemCooldown(btn, 0, 1)
    Equal(queries, 0)
    btn:Show()
    Equal(queries, 1); Equal(btn.Cooldown:IsShown(), true)
end)
Test("text toggles and size changes apply to current cooldowns without touching the swipe", function()
    local btn = Button(0, 1)
    SetCooldown(0, 1, now, 30, 1); ns.UpdateItemCooldown(btn, 0, 1)
    Equal(Text(btn), nil)
    profile.bagShowCooldownText, profile.bagCooldownFontSize = true, 16
    EUI_Bags:RefreshCooldowns()
    Equal(Text(btn):IsShown(), true); Equal(Text(btn).size, 16)
    Equal(btn.Cooldown.cooldownCalls, 1)
    profile.bagShowCooldownText = false; EUI_Bags:RefreshCooldowns()
    Equal(Text(btn):IsShown(), false); Equal(btn.Cooldown:IsShown(), true)
end)
Test("list cooldown labels are anchored to the icon and hidden without the icon column", function()
    profile.bagShowCooldownText = true
    local btn = Button(0, 1, true)
    SetCooldown(0, 1, now, 30, 1); ns.UpdateItemCooldown(btn, 0, 1)
    Equal(Text(btn).point[2], btn._lvIcon)
    btn._lvIcon:Hide(); Fire()
    Equal(Text(btn):IsShown(), false); Equal(btn.Cooldown:IsShown(), false)
    btn._lvIcon:Show(); ns.UpdateItemCooldown(btn, 0, 1)
    Equal(Text(btn):IsShown(), true)
end)
Test("the main bank and equipped bank bags use their actual container IDs", function()
    profile.bagShowCooldownText = true
    for _, bag in ipairs({ -1, 5, 11 }) do
        local btn = Button(bag, 3)
        ns.UpdateItemCooldown(btn, bag, 3)
        SetCooldown(bag, 3, now, 20 + bag, 1)
        Fire()
        Equal(Text(btn):GetText(), tostring(20 + bag))
    end
end)
Test("cooldown updates preserve native scripts and do not create secure frames in combat", function()
    local btn = Button(0, 1)
    local click, shows = noop, 0
    btn:SetScript("OnClick", click)
    btn:SetScript("OnShow", function() shows = shows + 1 end)
    ns.UpdateItemCooldown(btn, 0, 1)
    local created = secureCreates
    combat, profile.bagShowCooldownText = true, true
    SetCooldown(0, 1, now, 60, 1); Fire(); Tick(1)
    Equal(btn:GetScript("OnClick"), click); Equal(secureCreates, created)
    btn:Hide(); btn:Show()
    Equal(shows, 1); Equal(Text(btn):GetText(), "59")
end)

Load("EllesmereUIBags_Grid.lua")
local RenderGridButton = Upvalue(ns.RenderGridView, "RenderButton")
local function Data(bag, slot)
    return { bag = bag, slot = slot, itemLink = "item:1", info = { iconFileID = "icon", quality = 1, stackCount = 1, itemID = 1 } }
end
Test("the real grid renderer registers live cooldowns instead of using stale snapshot data", function()
    profile.bagShowCooldownText = true
    local btn = ns.GetOrCreateSlot(1)
    RenderGridButton(btn, Data(0, 1), 1, 0, 0, 0, 0, 12)
    SetCooldown(0, 1, now, 300, 1); Fire()
    Equal(btn.Cooldown:IsShown(), true); Equal(Text(btn):GetText(), "5m")
    RenderGridButton(btn, { bag = 0, slot = 1 }, 1, 0, 0, 0, 0, 12, true)
    Equal(btn.Cooldown:IsShown(), false); Equal(Text(btn):IsShown(), false)
end)

Load("EllesmereUIBags_List.lua")
local RenderEmpty = Upvalue(ns.RenderListView, "RenderEmptyRow")
Test("the real bag and bank list renderer refreshes live and clears removed icon columns", function()
    profile.bagShowCooldownText = true
    local btn = ns.CreateListRow(EUI_Bags)
    local d = Data(5, 2)
    ns.StampListItem(d)
    profile.bagListColumns = { "icon", "name" }
    local cols = ns.ListLayoutColumns(300)
    ns.RenderListRow(btn, d, cols, 300, 0, 0, false)
    SetCooldown(5, 2, now, 40, 1); Fire()
    Equal(Text(btn):GetText(), "40"); Equal(Text(btn).point[2], btn._lvIcon)
    profile.bagListColumns = { "name" }
    cols = ns.ListLayoutColumns(300)
    ns.RenderListRow(btn, d, cols, 300, 0, 0, false)
    Equal(btn.Cooldown:IsShown(), false); Equal(Text(btn):IsShown(), false)
    Fire(); Equal(btn.Cooldown:IsShown(), false)
    profile.bagListColumns = { "icon", "name" }
    cols = ns.ListLayoutColumns(300)
    ns.RenderListRow(btn, d, cols, 300, 0, 0, false)
    Equal(Text(btn):IsShown(), true)
    RenderEmpty(btn, cols, { bag = 5, slot = 2 }, 300, 0, 0, false)
    Equal(Text(btn):IsShown(), false); Equal(btn.Cooldown:IsShown(), false)
end)
Test("the Bags settings controls toggle text and resize it on open bags in both views", function()
    local module
    function IsAddOnLoaded(name) return name == "EllesmereUIBags" end
    EllesmereUI.RegisterSettingsModule = function(def) module = def end
    assert(loadfile([[EllesmereUIOptions\EUI_Bags_Options.lua]]))("EllesmereUIOptions")
    local controls = {}
    local page = { Section = noop, Dropdown = noop, Cog = noop, Swatch = noop, MultiSelect = noop,
        Blank = noop, Button = noop, Label = noop, Paragraph = noop, Sync = noop }
    function page:Toggle(label, _, get, set, disabled) controls[label] = { get = get, set = set, disabled = disabled } end
    function page:Slider(label, _, low, high, step, get, set, disabled)
        controls[label] = { low = low, high = high, get = get, set = set, disabled = disabled }
    end
    local btn = Button(0, 1)
    SetCooldown(0, 1, now, 60, 1); ns.UpdateItemCooldown(btn, 0, 1)
    for _, mode in ipairs({ "grid", "list" }) do
        profile.bagDisplayMode = mode
        module.tabs[1].build(page)
        local toggle, size = controls["Show Item Cooldown Text"], controls["Cooldown Text Size"]
        assert(toggle and size)
        Equal(toggle.get(), false); Equal(size.disabled(), true); Equal(size.low, 8); Equal(size.high, 20)
        toggle.set(true); Equal(Text(btn):IsShown(), true); Equal(size.disabled(), false)
        size.set(14); Equal(Text(btn).size, 14); Equal(profile.bagCooldownFontSize, 14)
        toggle.set(false); Equal(Text(btn):IsShown(), false); Equal(btn.Cooldown:IsShown(), true)
    end
end)
Test("Reset Bags removes cooldown text while preserving live swipes", function()
    profile.bagShowCooldownText = true
    local btn = Button(-1, 1)
    SetCooldown(-1, 1, now, 60, 1); ns.UpdateItemCooldown(btn, -1, 1)
    Equal(Text(btn):IsShown(), true)
    EllesmereUI._bagsReset()
    Equal(profile.bagShowCooldownText, false); Equal(profile.bagCooldownFontSize, 11)
    Equal(Text(btn):IsShown(), false); Equal(btn.Cooldown:IsShown(), true)
end)

print(string.format("%d passed, %d failed", passed, #failures))
if #failures > 0 then error(table.concat(failures, "\n"), 0) end
