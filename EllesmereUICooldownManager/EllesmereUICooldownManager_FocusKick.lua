-------------------------------------------------------------------------------
--  EllesmereUICooldownManager_FocusKick.lua
--  FocusKick (retail EUI_CDM_FocusKick.lua): a cooldowns bar ("focuskick")
--  pinned to the focus target's nameplate (or the target's, Show on Target),
--  holding your interrupt; Focus Cast Sound when the focus starts an
--  interruptible cast while your interrupt is ready; Focus Text Reminders
--  ("FOCUS" under caster mobs in dungeons while no focus is set).
--  5.4.8: nameplates come from EllesmereUINameplates (ENP.byGUID); without
--  that addon the bar sits on the focus / target unit frame instead.
-------------------------------------------------------------------------------
local addonName, P = ...
local ns = EllesmereUI
local CDM = P.CDM

local FK = {}
CDM.FocusKick = FK
FK.KEY = "focuskick"

-- Class interrupts (Mists of Pandaria).
FK.INTERRUPTS = {
	WARRIOR = { 6552 }, ROGUE = { 1766 }, DEATHKNIGHT = { 47528 }, PALADIN = { 96231 },
	SHAMAN = { 57994 }, MAGE = { 2139 }, HUNTER = { 147362, 34490 }, MONK = { 116705 },
	DRUID = { 80964, 80965, 78675 }, PRIEST = { 15487 }, WARLOCK = { 19647, 115781 },
}

function FK.ClassInterrupts()
	local _, class = UnitClass("player")
	local out = {}
	for _, id in ipairs(FK.INTERRUPTS[class] or {}) do
		if CDM.IsKnownSpell(id) then out[#out + 1] = id end
	end
	return out
end

-- The bar (retail EnsureFocusKickBar): after "buffs", suppressGCD on.
function FK.EnsureBar()
	local bars = CDM.Bars()
	for _, b in ipairs(bars) do
		if b.key == FK.KEY then
			if b.suppressGCD == nil then b.suppressGCD = true end
			return b
		end
	end
	local bd = CDM.NewBarTemplate(FK.KEY, "FocusKick", "cooldowns", 28)
	bd.suppressGCD = true
	bd.enabled = false
	bd.nameplateAnchorSide = "LEFT"
	bd.nameplateOffsetX, bd.nameplateOffsetY = 0, 0
	local idx = #bars + 1
	for i, b in ipairs(bars) do
		if b.key == "buffs" then idx = i + 1 break end
	end
	table.insert(bars, idx, bd)
	return bd
end

-- An empty FocusKick bar gets your interrupt.
function FK.SeedSpells()
	local sd = CDM.BarSpellData(FK.KEY)
	if #sd.assignedSpells == 0 then
		for _, id in ipairs(FK.ClassInterrupts()) do sd.assignedSpells[#sd.assignedSpells + 1] = id end
	end
end

local function Unit(bd)
	return (bd and bd.focusKickUseTarget) and "target" or "focus"
end

local function Host(unit)
	local ENP = ns.ENP
	local guid = UnitGUID(unit)
	local plate = ENP and ENP.byGUID and guid and ENP.byGUID[guid]
	if plate and plate:IsShown() then return plate end
	if ns.UF and ns.UF.frames and ns.UF.frames[unit] and ns.UF.frames[unit]:IsShown() then return ns.UF.frames[unit] end
	return nil
end

-- Positions the bar on the unit's nameplate; false = nothing to anchor to.
function FK.ApplyAnchor(bd, f)
	local unit = Unit(bd)
	if not (UnitExists(unit) and UnitCanAttack("player", unit) and not UnitIsDead(unit)) then return false end
	local host = Host(unit)
	if not host then return false end
	local side = bd.nameplateAnchorSide or "LEFT"
	local ox, oy = bd.nameplateOffsetX or 0, bd.nameplateOffsetY or 0
	f:ClearAllPoints()
	if side == "RIGHT" then f:SetPoint("LEFT", host, "RIGHT", 2 + ox, oy)
	elseif side == "TOP" then f:SetPoint("BOTTOM", host, "TOP", ox, 2 + oy)
	elseif side == "BOTTOM" then f:SetPoint("TOP", host, "BOTTOM", ox, -2 + oy)
	else f:SetPoint("RIGHT", host, "LEFT", -2 + ox, oy) end
	return true
end

-- The bar's interrupt (Interrupt Spell pick, else the first known one).
function FK.InterruptSpell(bd)
	local sid = bd and bd.focusKickInterruptSpellID
	if sid and CDM.IsKnownSpell(sid) then return sid end
	return FK.ClassInterrupts()[1]
end

local function InterruptReady(bd)
	local sid = FK.InterruptSpell(bd)
	if not sid then return false end
	local s, d = GetSpellCooldown(sid)
	return not s or s == 0 or d <= 1.5
end

-------------------------------------------------------------------------------
--  Events: cast sound, reminders, re-anchoring
-------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
local reminders = {}   -- [plate] = fontstring

local function ReminderColor(bd)
	if bd.focusReminderUseAccent ~= false and ns.ResolveAccent then return ns.ResolveAccent() end
	return bd.focusReminderR or 1, bd.focusReminderG or 1, bd.focusReminderB or 1
end

function FK.RefreshReminders()
	local bd = CDM.BarByKey(FK.KEY)
	local ENP = ns.ENP
	local on = bd and bd.enabled ~= false and bd.focusReminderEnabled and ENP and ENP.visible
		and IsInInstance() and select(2, IsInInstance()) == "party"
		and not UnitExists("focus") and FK.InterruptSpell(bd) ~= nil
	for plate, fs in pairs(reminders) do
		if not (on and plate:IsShown() and ENP.visible[plate] and not plate.isFriendly and plate.IsCaster and plate:IsCaster()) then
			fs:Hide()
		end
	end
	if not on then return end
	local r, g, b = ReminderColor(bd)
	for plate in pairs(ENP.visible) do
		if not plate.isFriendly and plate.IsCaster and plate:IsCaster() then
			local fs = reminders[plate]
			if not fs then
				fs = plate:CreateFontString(nil, "OVERLAY")
				reminders[plate] = fs
			end
			ns.ApplyModuleFont(fs, bd.focusReminderSize or 26, CDM.FONT_KEY)
			fs:SetTextColor(r, g, b, 1)
			fs:ClearAllPoints()
			fs:SetPoint("TOP", plate, "BOTTOM", bd.focusReminderOffsetX or 0, -2 + (bd.focusReminderOffsetY or 0))
			fs:SetText("FOCUS")
			fs:Show()
		end
	end
end

ev:SetScript("OnEvent", function(_, event, unit, _, _, _, spellID)
	if not CDM.ready then return end
	local bd = CDM.BarByKey(FK.KEY)
	if not bd or bd.enabled == false then return end
	if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
		if unit ~= Unit(bd) then return end
		local notInterruptible
		if event == "UNIT_SPELLCAST_START" then
			notInterruptible = select(9, UnitCastingInfo(unit))
		else
			notInterruptible = select(8, UnitChannelInfo(unit))
		end
		if not notInterruptible and bd.focusCastSoundKey and InterruptReady(bd) then
			CDM.PlaySoundKey(bd.focusCastSoundKey)
		end
		return
	end
	CDM.UpdateAll(true)
end)
for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "PLAYER_FOCUS_CHANGED", "PLAYER_TARGET_CHANGED" }) do
	ev:RegisterEvent(e)
end

-- Reminders and the nameplate anchor follow the plates (they move and get
-- reused), checked a few times a second.
local acc = 0
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, elapsed)
	acc = acc + elapsed
	if acc < 0.25 or not CDM.ready then return end
	acc = 0
	local bd = CDM.BarByKey(FK.KEY)
	if not bd then return end
	FK.RefreshReminders()
	local f = CDM.barFrames and CDM.barFrames[FK.KEY]
	if f and f.bd == bd and f:IsShown() and not ns._unlockActive then
		if not FK.ApplyAnchor(bd, f) then f:SetAlpha(0) else f:SetAlpha(bd.barOpacity or 1) end
	end
end)
