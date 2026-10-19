-------------------------------------------------------------------------------
--  EllesmereUIQoL_MovementAlert.lua (5.4.8 port of retail Movement Alerts)
--
--  1. Movement Cooldown Alert: your class's mobility spell(s) counting down
--     while on cooldown (text / icon / bar), so you know when they are back.
--  2. Time Spiral: a "FREE MOVEMENT" banner for 10 seconds when a tracked
--     mobility spell lights up (spell activation overlay glow).
--  Settings: EllesmereUIQoLDB.movementAlert (retail profile.movementAlert),
--  same keys and defaults as retail.
--
--  5.4.8 differences:
--    * Mists spell lists per class (talents are class wide in Mists, so the
--      list is per class; only known spells are tracked).
--    * Cooldowns are plain numbers here (no secret values, no duration
--      objects): one 0.1 s poll while something is shown.
--    * Text-to-speech (C_VoiceChat) does not exist in 5.4.8: the TTS keys
--      are kept but only the Sound plays.
--    * Gateway Shard alert: the Gateway Control Shard item does not exist in
--      Mists; not ported (its keys are kept).
-------------------------------------------------------------------------------
local addonName = ...
local ns = EllesmereUI

local floor, max, min = math.floor, math.max, math.min
local format = string.format
local GetTime = GetTime

local M = {}  -- module table (keeps the local count low)
ns.MovementAlert = M

local playerClass = select(2, UnitClass("player"))

-------------------------------------------------------------------------------
--  Mists mobility spells (class -> ids). Buff-active spells show a label
--  while their aura is up instead of a cooldown.
-------------------------------------------------------------------------------
local MOVEMENT_ABILITIES = {
	DEATHKNIGHT = { 96268 },                         -- Death's Advance
	DRUID = { 102401, 102280, 1850, 106898 },        -- Wild Charge, Displacer Beast, Dash, Stampeding Roar
	HUNTER = { 781 },                                -- Disengage
	MAGE = { 1953, 108843 },                         -- Blink, Blazing Speed
	MONK = { 109132, 115008, 101545, 116841 },       -- Roll, Chi Torpedo, Flying Serpent Kick, Tiger's Lust
	PALADIN = { 85499 },                             -- Speed of Light
	PRIEST = { 121536, 73325 },                      -- Angelic Feather, Leap of Faith
	ROGUE = { 36554, 108212, 2983 },                 -- Shadowstep, Burst of Speed, Sprint
	SHAMAN = { 79206, 108273 },                      -- Spiritwalker's Grace, Windwalk Totem
	WARLOCK = { 48020, 111771, 111400 },             -- Demonic Circle: Teleport, Demonic Gateway, Burning Rush
	WARRIOR = { 6544 },                              -- Heroic Leap
}
M.MOVEMENT_ABILITIES = MOVEMENT_ABILITIES

local BUFF_ACTIVE_SPELLS = {
	[111400] = "Burning Rush Active!",
}

-- Off until checked (retail MOVEMENT_DEFAULT_OFF, Mists ids).
local MOVEMENT_DEFAULT_OFF = {
	[2983] = true,    -- Sprint
	[73325] = true,   -- Leap of Faith
	[106898] = true,  -- Stampeding Roar
	[1850] = true,    -- Dash
	[79206] = true,   -- Spiritwalker's Grace
	[108273] = true,  -- Windwalk Totem
	[116841] = true,  -- Tiger's Lust
	[111771] = true,  -- Demonic Gateway
	[111400] = true,  -- Burning Rush
}
M.DEFAULT_OFF = MOVEMENT_DEFAULT_OFF
M.BUFF_ACTIVE = BUFF_ACTIVE_SPELLS

local MIN_REAL_COOLDOWN = 3  -- shorter windows are shared lockouts / the GCD

local function SpellEffectivelyEnabled(override, spellId)
	if override and override.enabled ~= nil then
		return override.enabled ~= false
	end
	return not MOVEMENT_DEFAULT_OFF[spellId]
end
M.SpellEffectivelyEnabled = SpellEffectivelyEnabled

-------------------------------------------------------------------------------
--  Settings
-------------------------------------------------------------------------------
local function Defaults()
	return {
		combatOnly = false,
		displayMode = "text",
		textSize = 24,
		iconSize = 40,
		textColorR = 1, textColorG = 1, textColorB = 1,
		textColorUseClass = false,
		barShowIcon = true,
		barShowDuration = true,
		barTexture = "none",
		precision = 1,
		spellOverrides = {},
		maSoundKey = "none",
		maTtsEnabled = false, maTtsVoiceID = 0, maTtsVolume = 100,
		tsEnabled = false,
		tsTextFormat = "FREE MOVEMENT\\n%.1f",
		tsColorR = 0.53, tsColorG = 1, tsColorB = 0,
		tsColorUseClass = false,
		tsSoundKey = "none",
		tsTtsEnabled = false, tsTtsVoiceID = 0, tsTtsMessage = "Free movement", tsTtsVolume = 100,
		gwEnabled = false, gwCombatOnly = false, gwText = "GATEWAY READY",
		gwColorR = 0.7, gwColorG = 0, gwColorB = 1, gwColorUseClass = false,
		gwSoundKey = "none", gwTtsEnabled = false, gwTtsVoiceID = 0,
		gwTtsMessage = "Gateway ready", gwTtsVolume = 100,
	}
end
M.Defaults = Defaults

-- First login: the user's retail values (profile "Naowh").
local function SeedRetail(t)
	local s = {
		enabledClasses = {
			HUNTER = true, WARRIOR = true, ROGUE = true, MAGE = true, PRIEST = true, SHAMAN = true,
			EVOKER = true, WARLOCK = true, DEMONHUNTER = true, DEATHKNIGHT = true, DRUID = true,
			MONK = true, PALADIN = true,
		},
		spellOverrides = { [101545] = { enabled = false }, [121536] = { enabled = false }, [186257] = { enabled = false } },
		displayMode = "text_nd", textSize = 16, precision = 0,
		textColorUseClass = true, barShowDuration = true, barShowIcon = true, barTexture = "none",
		tsEnabled = true, tsTtsEnabled = true, tsTtsMessage = "Time Spiral",
		tsColorR = 0.70588235294118, tsColorG = 1, tsColorB = 0.37647058823529, tsTtsVolume = 80,
		gwEnabled = true, gwTtsVolume = 100, gwColorR = 0.7, gwColorG = 0, gwColorB = 1, maTtsVolume = 80,
		pos = { point = "CENTER", relPoint = "CENTER", x = 10, y = 63.5, width = 200, height = 40 },
		tsPos = { point = "CENTER", relPoint = "CENTER", x = 0, y = 63.5, width = 200, height = 40 },
		gwPos = { point = "CENTER", relPoint = "CENTER", x = 4, y = 168, width = 200, height = 40 },
	}
	for k, v in pairs(s) do t[k] = v end
end

local firstLook = true
local function MA()
	local q = ns.GetQoLDB and ns.GetQoLDB()
	if type(q) ~= "table" then return nil end
	local t = q.movementAlert
	if type(t) ~= "table" then
		t = {}
		q.movementAlert = t
	end
	if t._seeded ~= 1 then
		if firstLook and next(t) == nil then SeedRetail(t) end
		ns.CopyDefaults(Defaults(), t)
		t._seeded = 1
	end
	firstLook = false
	return t
end
ns.GetMovementAlertDB = MA

local function MovementEnabled()
	local ma = MA()
	local ec = ma and ma.enabledClasses
	return type(ec) == "table" and ec[playerClass] == true or false
end
M.MovementEnabled = MovementEnabled

-------------------------------------------------------------------------------
--  Fonts, colors, sounds
-------------------------------------------------------------------------------
local function FontPath()
	return (ns.GetFontPath and ns.GetFontPath("qol")) or STANDARD_TEXT_FONT
end
local function FontOutline()
	local o = (ns.GetFontOutlineFlag and ns.GetFontOutlineFlag("qol")) or ""
	if not o:find("OUTLINE") then o = (o == "") and "OUTLINE" or (o .. ", OUTLINE") end
	return o
end
local function SetFontSafe(fs, size)
	fs:SetFont(FontPath(), size, FontOutline())
	if not fs:GetFont() then fs:SetFont(STANDARD_TEXT_FONT, size, FontOutline()) end
end

local function ResolveAlertColor(prefix, useClassKey)
	local ma = MA()
	if ma[useClassKey] then
		local c = RAID_CLASS_COLORS[playerClass]
		if c then return c.r, c.g, c.b end
	end
	return ma[prefix .. "R"] or 1, ma[prefix .. "G"] or 1, ma[prefix .. "B"] or 1
end

-- Sound list of the QoL addon (EllesmereUIQoL_Extras.lua, same keys as retail).
local function PlayAlertSound(key)
	if not key or key == "none" then return end
	local Q = ns.QoL
	local path = Q and Q.SOUND_PATHS and Q.SOUND_PATHS[key]
	if path then PlaySoundFile(path, "Master") end
end
M.PlayAlertSound = PlayAlertSound

-- Retail plays TTS when on, else the sound. No TTS in 5.4.8: always the sound.
local function FireTrackerAlert(prefix)
	PlayAlertSound(MA()[prefix .. "SoundKey"])
end

local function BarTexturePath(key)
	if type(key) == "string" and key:find("[\\/]") then return key end
	return "Interface\\Buttons\\WHITE8X8"
end

-------------------------------------------------------------------------------
--  Display: a pool of slots stacked up from the mover frame
-------------------------------------------------------------------------------
local movementFrame = CreateFrame("Frame", "EUI_MovementAlertFrame", UIParent)
movementFrame:SetSize(200, 40)
movementFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
movementFrame:SetFrameStrata("HIGH")
movementFrame:Hide()
M.frame = movementFrame

local displayPool = {}
local activeSlotCount = 0

local function CreateDisplaySlot()
	local slot = CreateFrame("Frame", nil, movementFrame)
	slot:SetSize(200, 40)
	slot.text = slot:CreateFontString(nil, "OVERLAY")
	SetFontSafe(slot.text, 24)
	slot.text:SetPoint("CENTER")

	slot.icon = CreateFrame("Frame", nil, slot)
	slot.icon:SetSize(40, 40)
	slot.icon:SetPoint("CENTER")
	slot.icon.border = slot.icon:CreateTexture(nil, "BACKGROUND")
	slot.icon.border:SetAllPoints()
	slot.icon.border:SetTexture(0, 0, 0, 1)
	slot.icon.tex = slot.icon:CreateTexture(nil, "ARTWORK")
	slot.icon.tex:SetPoint("TOPLEFT", 2, -2)
	slot.icon.tex:SetPoint("BOTTOMRIGHT", -2, 2)
	slot.icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	slot.icon.cooldown = CreateFrame("Cooldown", nil, slot.icon, "CooldownFrameTemplate")
	slot.icon.cooldown:SetAllPoints(slot.icon.tex)
	-- Our own number (OmniCC and Blizzard numbers stay off this frame).
	slot.icon.cooldown.noCooldownCount = true
	slot.icon.textHolder = CreateFrame("Frame", nil, slot.icon)
	slot.icon.textHolder:SetAllPoints()
	slot.icon.textHolder:SetFrameLevel(slot.icon.cooldown:GetFrameLevel() + 2)
	slot.icon.timeText = slot.icon.textHolder:CreateFontString(nil, "OVERLAY")
	SetFontSafe(slot.icon.timeText, 24)
	slot.icon.timeText:SetPoint("CENTER")
	slot.icon:Hide()

	slot.bar = CreateFrame("StatusBar", nil, slot)
	slot.bar:SetSize(150, 20)
	slot.bar:SetPoint("CENTER")
	slot.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
	slot.bar:SetMinMaxValues(0, 1)
	slot.bar:SetValue(0)
	slot.bar.bg = slot.bar:CreateTexture(nil, "BACKGROUND")
	slot.bar.bg:SetAllPoints()
	slot.bar.bg:SetTexture(0.1, 0.1, 0.1, 0.8)
	slot.bar.text = slot.bar:CreateFontString(nil, "OVERLAY")
	SetFontSafe(slot.bar.text, 12)
	slot.bar.text:SetPoint("CENTER")
	slot.bar.icon = slot.bar:CreateTexture(nil, "OVERLAY")
	slot.bar.icon:SetSize(20, 20)
	slot.bar.icon:SetPoint("RIGHT", slot.bar, "LEFT", -4, 0)
	slot.bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	slot.bar:Hide()
	return slot
end

local function GetDisplaySlot(index)
	if not displayPool[index] then displayPool[index] = CreateDisplaySlot() end
	return displayPool[index]
end

local function LayoutDisplaySlots(count)
	local w, h = movementFrame:GetWidth(), movementFrame:GetHeight()
	for i = 1, count do
		local slot = displayPool[i]
		if slot then
			slot:ClearAllPoints()
			slot:SetSize(w, h)
			if i == 1 then
				slot:SetPoint("BOTTOM", movementFrame, "BOTTOM", 0, 0)
			else
				slot:SetPoint("BOTTOM", displayPool[i - 1], "TOP", 0, 2)
			end
		end
	end
end

local function StyleSlot(slot)
	local ma = MA()
	local frameH, frameW = movementFrame:GetHeight(), movementFrame:GetWidth()
	local fontSize = max(8, min(72, ma.textSize or 24))
	local r, g, b = ResolveAlertColor("textColor", "textColorUseClass")
	SetFontSafe(slot.text, fontSize)
	slot.text:SetTextColor(r, g, b)
	SetFontSafe(slot.icon.timeText, fontSize)
	slot.icon.timeText:SetTextColor(r, g, b)
	SetFontSafe(slot.bar.text, fontSize)
	local barH = max(12, floor(frameH * 0.5))
	local barW = frameW - (ma.barShowIcon ~= false and (barH + 8) or 0) - 10
	slot.bar:SetSize(max(50, barW), barH)
	slot.bar.icon:SetSize(barH, barH)
	local texPath = BarTexturePath(ma.barTexture)
	if slot.bar.lastTex ~= texPath then
		slot.bar:SetStatusBarTexture(texPath)
		slot.bar.lastTex = texPath
	end
	local iconSz = max(16, min(128, ma.iconSize or 40))
	slot.icon:SetSize(iconSz, iconSz)
end

-------------------------------------------------------------------------------
--  Tracked spells of the player
-------------------------------------------------------------------------------
local cachedSpells = {}

local function KnowsSpell(id)
	return (IsPlayerSpell and IsPlayerSpell(id)) or IsSpellKnown(id)
end

local function BuildEntry(spellId, override)
	local name, _, icon = GetSpellInfo(spellId)
	if not name then return nil end
	local entry = {
		spellId = spellId,
		spellName = name,
		spellIcon = icon,
		customText = override and override.customText ~= "" and override.customText or nil,
	}
	if BUFF_ACTIVE_SPELLS[spellId] then
		entry.checkType = "buffActive"
		entry.customText = entry.customText or BUFF_ACTIVE_SPELLS[spellId]
		return entry
	end
	local _, maxCharges, _, chargeDur = GetSpellCharges(spellId)
	if maxCharges and maxCharges > 1 then
		entry.isChargeSpell = true
		entry.maxCharges = maxCharges
		entry.rechargeDuration = chargeDur
	end
	local base = GetSpellBaseCooldown(spellId)
	entry.baseDuration = (base and base > 0) and base / 1000 or (chargeDur or 0)
	return entry
end

-- Spells shown on cooldown at the last check (the "ready" sound fires when one
-- leaves this set).
local readyAlertShown, readyScratch = {}, {}

local function CacheMovementSpells()
	wipe(cachedSpells)
	local overrides = MA().spellOverrides or {}
	local seen = {}
	for _, spellId in ipairs(MOVEMENT_ABILITIES[playerClass] or {}) do
		if SpellEffectivelyEnabled(overrides[spellId], spellId) and KnowsSpell(spellId) then
			local e = BuildEntry(spellId, overrides[spellId])
			if e then
				cachedSpells[#cachedSpells + 1] = e
				seen[spellId] = true
			end
		end
	end
	-- User-added spells of this class.
	for spellId, override in pairs(overrides) do
		if type(spellId) == "number" and not seen[spellId] and type(override) == "table"
			and override.class == playerClass and override.enabled ~= false and KnowsSpell(spellId) then
			local e = BuildEntry(spellId, override)
			if e then cachedSpells[#cachedSpells + 1] = e end
		end
	end
	-- Carry the on-cooldown set over to the new list and drop the spells it no
	-- longer tracks, so a form or spec change never sounds "ready" for a spell
	-- that is still on cooldown.
	if next(readyAlertShown) then
		local carried = readyScratch
		wipe(carried)
		for _, e in ipairs(cachedSpells) do
			if readyAlertShown[e.spellId] then carried[e.spellId] = e end
		end
		readyAlertShown, readyScratch = carried, readyAlertShown
	end
end
M.CacheMovementSpells = CacheMovementSpells

-- Remaining cooldown (seconds) and its total, or nil when ready / GCD only.
local function SpellCooldown(entry)
	local id = entry.spellId
	if entry.isChargeSpell then
		local cur, maxC, start, dur = GetSpellCharges(id)
		if cur and maxC and cur < 1 and start and dur and dur > 0 then
			local rem = start + dur - GetTime()
			if rem > 0 then return rem, dur end
		end
		return nil
	end
	-- By name first: form variants (Wild Charge) share the spellbook name.
	local start, dur, enabled = GetSpellCooldown(entry.spellName)
	if not start then start, dur, enabled = GetSpellCooldown(id) end
	if not start or not dur or dur <= 0 or enabled == 0 then return nil end
	local gs, gd = GetSpellCooldown(61304)
	if gd and gd > 0 and gs == start and gd == dur then return nil end  -- the GCD
	local base = entry.baseDuration or 0
	if dur < MIN_REAL_COOLDOWN and base > dur then return nil end      -- shared lockout
	local rem = start + dur - GetTime()
	if rem <= 0 then return nil end
	return rem, dur
end

local function BuffActive(entry)
	local i = 1
	while true do
		local name, _, _, _, _, _, _, _, _, _, spellId = UnitAura("player", i, "HELPFUL")
		if not name then return false end
		if spellId == entry.spellId then return true end
		i = i + 1
	end
end

-------------------------------------------------------------------------------
--  Rendering
-------------------------------------------------------------------------------
local function ShowSlot(index, entry, rem, total)
	local ma = MA()
	local slot = GetDisplaySlot(index)
	StyleSlot(slot)
	local mode = ma.displayMode or "text"
	local prec = ((tonumber(ma.precision) or 1) > 0) and 1 or 0
	local precFmt = "%." .. prec .. "f"
	local name = entry.customText or entry.spellName or "Movement"
	slot.text:Hide(); slot.icon:Hide(); slot.bar:Hide()

	if not rem then
		-- Buff-active label (Burning Rush).
		slot.text:SetText(name)
		slot.text:Show()
		slot:Show()
		return
	end
	if mode == "icon" and entry.spellIcon then
		slot.icon.tex:SetTexture(entry.spellIcon)
		slot.icon.cooldown:SetCooldown(GetTime() - (total - rem), total)
		slot.icon.timeText:SetText(format(precFmt, rem))
		slot.icon:Show()
	elseif mode == "bar" then
		local r, g, b = ResolveAlertColor("textColor", "textColorUseClass")
		slot.bar:SetStatusBarColor(r, g, b)
		slot.bar:SetMinMaxValues(0, total)
		slot.bar:SetValue(rem)
		if ma.barShowDuration ~= false then
			slot.bar.text:SetText(format(precFmt, rem))
			slot.bar.text:Show()
		else
			slot.bar.text:Hide()
		end
		if ma.barShowIcon ~= false and entry.spellIcon then
			slot.bar.icon:SetTexture(entry.spellIcon)
			slot.bar.icon:Show()
		else
			slot.bar.icon:Hide()
		end
		slot.bar:Show()
	else
		local num = format(precFmt, rem)
		if mode == "text_nd" then
			slot.text:SetText("No " .. name .. " " .. num)
		elseif mode == "text_d" then
			slot.text:SetText(num)
		else  -- text_dn and the legacy "text"
			slot.text:SetText(num .. " No " .. name)
		end
		slot.text:Show()
	end
	slot:Show()
end

local inCombat = false
local previewEnds  -- options preview (nil = off)

local pollFrame = CreateFrame("Frame")
pollFrame:Hide()
do
	local acc = 0
	pollFrame:SetScript("OnUpdate", function(_, elapsed)
		acc = acc + elapsed
		if acc < 0.1 then return end
		acc = 0
		M.Check()
	end)
end

local function HideDisplay()
	for i = 1, #displayPool do displayPool[i]:Hide() end
	activeSlotCount = 0
	movementFrame:Hide()
	pollFrame:Hide()
end

M.Check = function()
	local ma = MA()
	if not ma then return end
	if ns._unlockActive then return end
	local count = 0
	if previewEnds then
		-- Settings page preview: a fake 8 s cooldown on the first tracked spell.
		local rem = previewEnds - GetTime()
		if rem <= 0 then
			previewEnds = GetTime() + 8
			rem = 8
		end
		local e = cachedSpells[1] or { spellName = "Movement", spellIcon = "Interface\\Icons\\Spell_Arcane_Blink" }
		count = 1
		ShowSlot(1, e, rem, 8)
	elseif MovementEnabled() and not (ma.combatOnly and not inCombat) then
		local now = readyScratch
		wipe(now)
		for _, entry in ipairs(cachedSpells) do
			if entry.checkType == "buffActive" then
				if BuffActive(entry) then
					count = count + 1
					ShowSlot(count, entry)
				end
			else
				local rem, total = SpellCooldown(entry)
				if rem then
					count = count + 1
					ShowSlot(count, entry, rem, total)
					now[entry.spellId] = entry
				end
			end
		end
		-- Sound once when a shown cooldown ends.
		for spellId in pairs(readyAlertShown) do
			if not now[spellId] then
				FireTrackerAlert("ma")
				break
			end
		end
		readyAlertShown, readyScratch = now, readyAlertShown
	end
	for i = count + 1, #displayPool do displayPool[i]:Hide() end
	if count > 0 then
		activeSlotCount = count
		LayoutDisplaySlots(count)
		movementFrame:Show()
		pollFrame:Show()
	else
		HideDisplay()
	end
end

M.ApplyMovementFrame = function()
	local ma = MA()
	if not ma then return end
	if not ns._unlockActive then
		movementFrame:ClearAllPoints()
		local pos = ma.pos
		if pos and pos.point then
			movementFrame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
		else
			movementFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
		end
	end
	local pos = ma.pos
	movementFrame:SetSize((pos and pos.width) or 200, (pos and pos.height) or 40)
	for _, slot in ipairs(displayPool) do StyleSlot(slot) end
	M.Check()
end

M.SetPreview = function(on)
	if on then
		previewEnds = previewEnds or (GetTime() + 8)
	else
		previewEnds = nil
	end
	M.Check()
end
M.PreviewActive = function() return previewEnds ~= nil end

-------------------------------------------------------------------------------
--  Time Spiral banner
-------------------------------------------------------------------------------
local tsFrame = CreateFrame("Frame", "EUI_TimeSpiralFrame", UIParent)
tsFrame:SetSize(200, 40)
tsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
tsFrame:SetFrameStrata("HIGH")
tsFrame:Hide()
local tsText = tsFrame:CreateFontString(nil, "OVERLAY")
SetFontSafe(tsText, 22)
tsText:SetPoint("CENTER")
M.tsFrame = tsFrame

local tsActiveTime
local tsActiveSpells = {}
local procDebounce = 0
local TS_WINDOW = 10

local function TrackedMobilitySpell(spellId)
	if BUFF_ACTIVE_SPELLS[spellId] then return false end
	for _, list in pairs(MOVEMENT_ABILITIES) do
		for _, id in ipairs(list) do
			if id == spellId then return true end
		end
	end
	local ov = MA().spellOverrides
	return ov and ov[spellId] and ov[spellId].enabled ~= false or false
end

tsFrame:SetScript("OnUpdate", function(self, elapsed)
	self.acc = (self.acc or 0) + elapsed
	if self.acc < 0.1 then return end
	self.acc = 0
	local ma = MA()
	if not ma.tsEnabled or not tsActiveTime then
		self:Hide()
		return
	end
	local remaining = TS_WINDOW - (GetTime() - tsActiveTime)
	if remaining > 0 then
		local fmt = (ma.tsTextFormat or "FREE MOVEMENT\\n%.1f"):gsub("\\n", "\n")
		local ok, txt = pcall(format, fmt, remaining)
		tsText:SetText(ok and txt or fmt)
	else
		tsActiveTime = nil
		self:Hide()
	end
end)

M.ApplyTimeSpiralFrame = function()
	local ma = MA()
	if not ma then return end
	if not ma.tsEnabled then
		tsActiveTime = nil
		tsFrame:Hide()
		return
	end
	local pos = ma.tsPos
	if not ns._unlockActive then
		tsFrame:ClearAllPoints()
		if pos and pos.point then
			tsFrame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
		else
			tsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
		end
	end
	tsFrame:SetSize((pos and pos.width) or 200, (pos and pos.height) or 40)
	SetFontSafe(tsText, max(10, min(72, floor(tsFrame:GetHeight() * 0.55))))
	tsText:SetTextColor(ResolveAlertColor("tsColor", "tsColorUseClass"))
end

local function OnGlowShow(spellId)
	local now = GetTime()
	if not TrackedMobilitySpell(spellId) or (now - procDebounce) < 0.12 then return end
	procDebounce = now
	tsActiveSpells[spellId] = true
	tsActiveTime = now
	FireTrackerAlert("ts")
	tsFrame.acc = 1
	tsFrame:Show()
end

local function OnGlowHide(spellId)
	if spellId then tsActiveSpells[spellId] = nil end
	if not next(tsActiveSpells) then
		tsActiveTime = nil
		tsFrame:Hide()
	end
end

-------------------------------------------------------------------------------
--  Events (only while a tracker is on)
-------------------------------------------------------------------------------
local loader = CreateFrame("Frame")
local BASELINE_EVENTS = {
	"PLAYER_SPECIALIZATION_CHANGED", "PLAYER_TALENT_UPDATE", "PLAYER_REGEN_DISABLED",
	"PLAYER_REGEN_ENABLED", "UPDATE_SHAPESHIFT_FORM", "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED",
}
local MOVE_EVENTS = { "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE", "SPELL_UPDATE_CHARGES" }
local reg = { base = false, move = false, ts = false }

M.UpdateEventRegistration = function()
	local ma = MA()
	if not ma then return end
	local moveOn = MovementEnabled()
	local anyOn = moveOn or ma.tsEnabled
	if anyOn ~= reg.base then
		reg.base = anyOn
		for _, ev in ipairs(BASELINE_EVENTS) do
			if anyOn then loader:RegisterEvent(ev) else loader:UnregisterEvent(ev) end
		end
		if anyOn then
			inCombat = UnitAffectingCombat("player") and true or false
			CacheMovementSpells()
		end
	end
	if moveOn ~= reg.move then
		reg.move = moveOn
		for _, ev in ipairs(MOVE_EVENTS) do
			if moveOn then loader:RegisterEvent(ev) else loader:UnregisterEvent(ev) end
		end
		if moveOn then
			loader:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
			loader:RegisterUnitEvent("UNIT_AURA", "player")
		else
			loader:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
			loader:UnregisterEvent("UNIT_AURA")
		end
	end
	local tsOn = ma.tsEnabled and true or false
	if tsOn ~= reg.ts then
		reg.ts = tsOn
		if tsOn then
			loader:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
			loader:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
		else
			loader:UnregisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
			loader:UnregisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
		end
	end
end

loader:SetScript("OnEvent", function(_, event, arg1)
	if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_TALENT_UPDATE" or event == "SPELLS_CHANGED"
		or event == "UPDATE_SHAPESHIFT_FORM" then
		CacheMovementSpells()
		M.Check()
	elseif event == "PLAYER_ENTERING_WORLD" then
		inCombat = UnitAffectingCombat("player") and true or false
		wipe(tsActiveSpells)
		tsActiveTime = nil
		CacheMovementSpells()
		M.Check()
	elseif event == "PLAYER_REGEN_DISABLED" then
		inCombat = true
		M.Check()
	elseif event == "PLAYER_REGEN_ENABLED" then
		inCombat = false
		M.Check()
	elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
		if MA().tsEnabled then OnGlowShow(arg1) end
	elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
		OnGlowHide(arg1)
	else
		-- Cooldown / aura / cast changes: one check on the next poll tick.
		pollFrame:Show()
	end
end)

-------------------------------------------------------------------------------
--  Apply (settings window) + Unlock Mode + login
-------------------------------------------------------------------------------
local loggedIn = false
M.ApplyAll = function()
	if not loggedIn or not MA() then return end
	M.UpdateEventRegistration()
	CacheMovementSpells()
	M.ApplyMovementFrame()
	M.ApplyTimeSpiralFrame()
end
ns.MovementAlertApply = M.ApplyAll

ns.applyHooks = ns.applyHooks or {}
tinsert(ns.applyHooks, function() M.ApplyAll() end)

local function MakeMoverEntry(key, label, order, isShown, frame, applyFn, posKey)
	return ns.MakeUnlockElement({
		key = key,
		label = label,
		group = "Quality of Life",
		order = order,
		isHidden = function() return not isShown() end,
		getFrame = function() return frame end,
		getSize = function()
			local pos = MA()[posKey]
			return (pos and pos.width) or 200, (pos and pos.height) or 40
		end,
		setWidth = function(_, w)
			local m = MA()
			m[posKey] = m[posKey] or {}
			m[posKey].width = max(60, floor(w + 0.5))
			applyFn()
		end,
		setHeight = function(_, h)
			local m = MA()
			m[posKey] = m[posKey] or {}
			m[posKey].height = max(20, floor(h + 0.5))
			applyFn()
		end,
		savePos = function(_, point, relPoint, x, y)
			if not point then return end
			local m = MA()
			m[posKey] = m[posKey] or {}
			m[posKey].point, m[posKey].relPoint, m[posKey].x, m[posKey].y = point, relPoint, x, y
		end,
		loadPos = function()
			local pos = MA()[posKey]
			if pos and pos.point then return pos end
			return nil
		end,
		clearPos = function()
			local m = MA()
			if m[posKey] then
				m[posKey].point, m[posKey].relPoint, m[posKey].x, m[posKey].y = nil, nil, nil, nil
			end
			applyFn()
		end,
		applyPos = applyFn,
	})
end

local function RegisterUnlock()
	if not ns.RegisterUnlockElements or not ns.MakeUnlockElement then return end
	ns:RegisterUnlockElements({
		MakeMoverEntry("EUI_MovementAlert", "Movement Alerts", 750, MovementEnabled, movementFrame,
			function() M.ApplyMovementFrame() end, "pos"),
		MakeMoverEntry("EUI_TimeSpiralAlert", "Movement Alerts - Time Spiral", 751,
			function() return MA().tsEnabled end, tsFrame, function() M.ApplyTimeSpiralFrame() end, "tsPos"),
	}, addonName)
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
	self:UnregisterAllEvents()
	loggedIn = true
	RegisterUnlock()
	M.ApplyAll()
end)

-------------------------------------------------------------------------------
--  Retail profile import: also take the movementAlert table.
-------------------------------------------------------------------------------
do
	local R = ns.ProfileRetail
	if R and R.CONVERT then
		local prev = R.CONVERT.EllesmereUIQoL
		R.CONVERT.EllesmereUIQoL = function(blob, notes)
			local root = prev and prev(blob, notes)
			if type(blob) == "table" and type(blob.movementAlert) == "table" then
				local copy = ns.ProfileDeepCopy or function(t) return t end
				root = root or copy(EllesmereUIQoLDB or {})
				root.movementAlert = copy(blob.movementAlert)
				root.movementAlert._seeded = nil
			end
			return root
		end
	end
end
