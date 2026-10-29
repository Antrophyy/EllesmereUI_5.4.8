setfenv(1, select(2, ...).env)
-- Live cooldowns for bag/bank grids and list rows, without inventory reflow.
local ns = select(2, ...)
local states, active = {}, {}
local driver = CreateFrame("Frame")
driver:Hide()
driver:RegisterEvent("BAG_UPDATE_COOLDOWN")

local function Profile()
    return EllesmereUI._bagsDB.profile
end

local function SyncDriver()
    driver:SetShown(next(active) ~= nil)
end

local function ClearVisual(btn, state)
    if btn.Cooldown then btn.Cooldown:Clear() end
    if state then
        state.start, state.duration, state.expires = nil, nil, nil
        if state.text then state.text:Hide() end
    end
    active[btn] = nil
end

local function CanShow(btn, state)
    return state.bag ~= nil and state.slot ~= nil and btn:IsVisible()
        and (not btn._lvIcon or btn._lvIcon:IsShown())
end

local function TimeText(left)
    if left >= 3600 then return string.format("%dh", math.floor(left / 3600 + 0.5)) end
    if left >= 60 then return string.format("%dm", math.floor(left / 60 + 0.5)) end
    return tostring(math.ceil(left))
end

local function PaintText(btn, state, now, restyle)
    if not Profile().bagShowCooldownText then
        if state.text then state.text:Hide() end
        return
    end
    if not state.text then
        local text = (btn._textOverlay or btn):CreateFontString(nil, "OVERLAY", nil, 7)
        text:SetPoint("CENTER", btn._lvIcon or btn.icon or btn, "CENTER", 0, 0)
        text:SetTextColor(1, 1, 1, 1)
        state.text = text
        restyle = true
    end
    if restyle then
        EllesmereUI.ApplyIconTextFont(state.text, ns.GetFont(), Profile().bagCooldownFontSize or 11, "bags")
    end
    local text = TimeText(state.expires - now)
    if text ~= state.label then
        state.text:SetText(text)
        state.label = text
    end
    state.text:Show()
end

local function Refresh(btn, state)
    if not CanShow(btn, state) then
        ClearVisual(btn, state)
        return
    end
    local start, duration, enabled = C_Container.GetContainerItemCooldown(state.bag, state.slot)
    local now = GetTime()
    if not start or not duration or not enabled or enabled == 0
        or start <= 0 or duration <= 0 or start + duration <= now then
        ClearVisual(btn, state)
        return
    end
    if state.start ~= start or state.duration ~= duration or not btn.Cooldown:IsShown() then
        btn.Cooldown:SetDrawEdge(true)
        btn.Cooldown:SetCooldown(start, duration)
    end
    state.start, state.duration, state.expires = start, duration, start + duration
    active[btn] = state
    PaintText(btn, state, now, true)
end

function ns.UpdateItemCooldown(btn, bag, slot)
    if not btn.Cooldown then return end
    local state = states[btn]
    if not state then
        state = {}
        states[btn] = state
        btn:HookScript("OnShow", function(self)
            Refresh(self, state)
            SyncDriver()
        end)
        btn:HookScript("OnHide", function(self)
            ClearVisual(self, state)
            SyncDriver()
        end)
    end
    state.bag, state.slot = bag, slot
    Refresh(btn, state)
    SyncDriver()
end

function ns.ClearItemCooldown(btn)
    local state = states[btn]
    if state then state.bag, state.slot = nil, nil end
    ClearVisual(btn, state)
    SyncDriver()
end

function ns.RefreshItemCooldowns()
    for btn, state in pairs(states) do Refresh(btn, state) end
    SyncDriver()
end
EUI_Bags.RefreshCooldowns = ns.RefreshItemCooldowns

-- The event can omit its bag ID, and shared item cooldowns affect other bags.
driver:SetScript("OnEvent", ns.RefreshItemCooldowns)
local elapsedTotal = 0
driver:SetScript("OnUpdate", function(_, elapsed)
    elapsedTotal = elapsedTotal + elapsed
    if elapsedTotal < 0.1 then return end
    elapsedTotal = 0
    local now = GetTime()
    for btn, state in pairs(active) do
        if not CanShow(btn, state) or state.expires <= now then
            ClearVisual(btn, state)
        else
            PaintText(btn, state, now)
        end
    end
    SyncDriver()
end)

EllesmereUI.applyHooks = EllesmereUI.applyHooks or {}
table.insert(EllesmereUI.applyHooks, ns.RefreshItemCooldowns)
