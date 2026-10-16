-------------------------------------------------------------------------------
--  EllesmereUITopBar_QoL_Stealth.lua (5.4.8 port of retail
--  NaowhUI_QoL_Stealth.lua): two reminders sharing one settings table:
--  restealth (rogue, opted-in druid specs) and wrong form / stance / seal
--  (druid, warrior, shadow priest, paladin).
--
--  5.4.8 changes:
--    * Forms are checked by GetShapeshiftFormID (the form index depends on
--      the forms a character knows): Balance = Moonkin Form, Feral = Cat
--      Form, Guardian = Bear Form; Arms / Fury = Battle or Berserker
--      Stance, Protection = Defensive Stance; Shadow = Shadowform.
--    * Paladin (retail: auras) = a Seal must be active (GetShapeshiftForm),
--      and Protection also needs Righteous Fury ("CHECK SEAL" /
--      "RIGHTEOUS FURY").
--    * Travel / Aquatic / Flight Form count as "mounted" (retail: travel).
--    * No PLAYER_MOUNT_DISPLAY_CHANGED: player UNIT_AURA catches mounting.
-------------------------------------------------------------------------------
local ns = EllesmereUI
local Q = ns.NaowhQoL
if not Q then return end

local floor, max, min = math.floor, math.max, math.min

local SECTION = "stealth"
local DEFAULTS = Q.DEFAULTS[SECTION]

local function DB() return Q.DB(SECTION) end
Q.StealthDB = DB

local ST = {}
Q.Stealth = ST

local inCombat, stealthed, isResting, inInstance = false, false, false, false

local stealthFrame, stealthLabel
local stanceFrame, stanceLabel

local ev = CreateFrame("Frame")
local wanted, registered = {}, {}
local SyncEvents

-------------------------------------------------------------------------------
--  Gating
-------------------------------------------------------------------------------
-- Rogues always. Druids: Feral (2) always, the other specs when opted in.
local function IsStealthSpec()
	local cls = Q.ClassFile()
	if cls == "ROGUE" then return true end
	if cls ~= "DRUID" then return false end
	local t = DB()
	local idx = Q.SpecIndex()
	if idx == 2 then return true end
	if idx == 1 and t.enableBalance then return true end
	if idx == 3 and t.enableGuardian then return true end
	if idx == 4 and t.enableResto then return true end
	return false
end

-- Accepted GetShapeshiftFormID values per spec index.
local MOONKIN, CAT, BEAR = 31, 1, 5
local BATTLE, DEFENSIVE, BERSERKER = 17, 18, 19
local SHADOWFORM = 28
local TRAVEL_FORMS = { [3] = true, [4] = true, [27] = true, [29] = true }
local RIGHTEOUS_FURY = 25780

local EXPECTED_FORMS = {
	DRUID   = { [1] = { MOONKIN }, [2] = { CAT }, [3] = { BEAR } },
	WARRIOR = { [1] = { BATTLE, BERSERKER }, [2] = { BATTLE, BERSERKER }, [3] = { DEFENSIVE } },
	PRIEST  = { [3] = { SHADOWFORM } },
	PALADIN = { [1] = "seal", [2] = "sealRF", [3] = "seal" },
}

local STANCE_LABELS = {
	DRUID   = "CHECK FORM",
	WARRIOR = "CHECK STANCE",
	PRIEST  = "SHADOWFORM",
	PALADIN = "CHECK SEAL",
}

local function DefaultStanceLabel()
	return STANCE_LABELS[Q.ClassFile()] or "CHECK STANCE"
end

local function GetExpectedForm()
	local classForms = EXPECTED_FORMS[Q.ClassFile()]
	if not classForms then return nil end
	return classForms[Q.SpecIndex()]
end

local function HasPlayerBuff(spellId)
	for i = 1, 40 do
		local name, _, _, _, _, _, _, _, _, _, id = UnitAura("player", i, "HELPFUL")
		if not name then return false end
		if id == spellId then return true end
	end
	return false
end

-- Returns ok, label override.
local function CheckForm(expected)
	if expected == "seal" or expected == "sealRF" then
		if (GetShapeshiftForm() or 0) == 0 then return false end
		if expected == "sealRF" and not HasPlayerBuff(RIGHTEOUS_FURY) then
			return false, "RIGHTEOUS FURY"
		end
		return true
	end
	local id = GetShapeshiftFormID()
	for i = 1, #expected do
		if id == expected[i] then return true end
	end
	return false
end

local function IsDruidTravelForm()
	if Q.ClassFile() ~= "DRUID" then return false end
	local id = GetShapeshiftFormID()
	return id and TRAVEL_FORMS[id] or false
end

-------------------------------------------------------------------------------
--  Stance sound
-------------------------------------------------------------------------------
local stanceTicker, lastStanceSound, stanceSoundFired = nil, 0, false
local STANCE_SOUND_COOLDOWN = 0.9

local function StopStanceSound()
	if stanceTicker then
		stanceTicker:Cancel()
		stanceTicker = nil
	end
end

local function PlayStanceSound(key)
	local now = GetTime()
	if now - lastStanceSound < STANCE_SOUND_COOLDOWN then return end
	lastStanceSound = now
	Q.PlaySound(key)
end

local function StartStanceSound(t)
	StopStanceSound()
	stanceSoundFired = true
	local key = t.stanceSound or Q.SOUND_NONE
	if key == Q.SOUND_NONE then return end
	PlayStanceSound(key)
	local interval = t.stanceSoundInterval or 3
	if interval > 0 then
		stanceTicker = Q.NewTicker(interval, function() PlayStanceSound(key) end)
	end
end

-------------------------------------------------------------------------------
--  Frames
-------------------------------------------------------------------------------
local function BuildFrames()
	if stealthFrame then return true end
	local t = DB()
	if not (t.enabled or t.stanceEnabled) then return false end

	stealthFrame = CreateFrame("Frame", "NaowhUIStealthReminder", UIParent)
	stealthFrame:SetSize(DEFAULTS.width, DEFAULTS.height)
	stealthFrame:SetPoint("CENTER", UIParent, "CENTER", DEFAULTS.x, DEFAULTS.y)
	stealthFrame:Hide()
	stealthLabel = stealthFrame:CreateFontString(nil, "OVERLAY")
	Q.SetFont(stealthLabel, Q.FontPath(), 24, "OUTLINE")
	stealthLabel:SetPoint("CENTER")

	stanceFrame = CreateFrame("Frame", "NaowhUIStanceReminder", UIParent)
	stanceFrame:SetSize(DEFAULTS.stanceWidth, DEFAULTS.stanceHeight)
	stanceFrame:SetPoint("CENTER", UIParent, "CENTER", DEFAULTS.stanceX, DEFAULTS.stanceY)
	stanceFrame:Hide()
	stanceLabel = stanceFrame:CreateFontString(nil, "OVERLAY")
	Q.SetFont(stanceLabel, Q.FontPath(), 24, "OUTLINE")
	stanceLabel:SetPoint("CENTER")
	return true
end

-- The box height sets the base size (a resize scales the text); scale
-- multiplies it.
local function FitLabel(label, frame, fontName, scale)
	local size = max(6, min(120, floor(frame:GetHeight() * 0.55 * (scale or 1))))
	local path = Q.FontPath(fontName)
	if label._path == path and label._size == size then return end
	label._path, label._size = path, size
	Q.SetFont(label, path, size, "OUTLINE")
end

local function SetLabel(label, text, r, g, b)
	if label._text ~= text then
		label._text = text
		label:SetText(text)
	end
	if label._r ~= r or label._g ~= g or label._b ~= b then
		label._r, label._g, label._b = r, g, b
		label:SetTextColor(r, g, b)
	end
end

-------------------------------------------------------------------------------
--  Stealth reminder
-------------------------------------------------------------------------------
local placedStealth, placedStance = false, false

function ST.StealthUpdate()
	if not BuildFrames() then return end
	local t = DB()

	if not placedStealth then
		stealthFrame:ClearAllPoints()
		local point = t.point or "CENTER"
		stealthFrame:SetPoint(point, UIParent, point, t.x or 0, t.y or 150)
		stealthFrame:SetSize(t.width or 200, t.height or 40)
		placedStealth = true
	end

	FitLabel(stealthLabel, stealthFrame, t.font, t.textScale)

	if stealthed then
		SetLabel(stealthLabel, (t.stealthText and t.stealthText ~= "") and t.stealthText or "STEALTH",
			Q.EffectiveColor(t, "stealthR", "stealthG", "stealthB", "stealthUseClassColor"))
	else
		SetLabel(stealthLabel, (t.warningText and t.warningText ~= "") and t.warningText or "RESTEALTH",
			Q.EffectiveColor(t, "warningR", "warningG", "warningB", "warningUseClassColor"))
	end

	if not t.enabled then stealthFrame:Hide(); return end
	if Q.unlockActive then
		stealthFrame:Show()
		return
	end
	if not IsStealthSpec() then stealthFrame:Hide(); return end
	if t.disableWhenRested and isResting and not inInstance then stealthFrame:Hide(); return end
	if t.groupOnly and GetNumGroupMembers() == 0 then stealthFrame:Hide(); return end
	if inCombat then stealthFrame:Hide(); return end
	if IsMounted() then stealthFrame:Hide(); return end
	if stealthed and t.showStealthed == false then stealthFrame:Hide(); return end
	if not stealthed and t.showNotStealthed == false then stealthFrame:Hide(); return end
	stealthFrame:Show()
end

-------------------------------------------------------------------------------
--  Stance reminder
-------------------------------------------------------------------------------
function ST.StanceUpdate()
	if not BuildFrames() then return end
	local t = DB()

	if not placedStance then
		stanceFrame:ClearAllPoints()
		local point = t.stancePoint or "CENTER"
		stanceFrame:SetPoint(point, UIParent, point, t.stanceX or 0, t.stanceY or 100)
		stanceFrame:SetSize(t.stanceWidth or 200, t.stanceHeight or 40)
		placedStance = true
	end

	-- stanceFont falls back to the stealth half's font.
	FitLabel(stanceLabel, stanceFrame,
		(t.stanceFont and t.stanceFont ~= Q.FONT_DEFAULT) and t.stanceFont or t.font, t.stanceTextScale)

	local function Paint(override)
		local text = (t.stanceWarnText and t.stanceWarnText ~= "") and t.stanceWarnText or override or DefaultStanceLabel()
		SetLabel(stanceLabel, text,
			Q.EffectiveColor(t, "stanceWarnR", "stanceWarnG", "stanceWarnB", "stanceWarnUseClassColor"))
	end
	Paint()

	local function Off()
		StopStanceSound()
		stanceFrame:Hide()
	end

	if not t.stanceEnabled then Off(); return end
	-- Silent static preview while positioning.
	if Q.unlockActive then
		StopStanceSound()
		stanceSoundFired = false
		stanceFrame:Show()
		return
	end
	if t.stanceCombatOnly and not inCombat then Off(); return end
	if IsMounted() or IsDruidTravelForm() then Off(); return end
	if t.stanceDisableWhenRested and isResting and not inInstance then Off(); return end
	if t.stanceInstanceOnly and not inInstance then Off(); return end

	local expected = GetExpectedForm()
	if not expected then Off(); return end

	local ok, override = CheckForm(expected)
	if ok then
		stanceSoundFired = false
		Off()
		return
	end
	Paint(override)
	stanceFrame:Show()

	if t.stanceSoundEnabled then
		if not stanceTicker and not stanceSoundFired then StartStanceSound(t) end
	else
		StopStanceSound()
		stanceSoundFired = false
	end
end

local function UpdateBoth()
	ST.StealthUpdate()
	ST.StanceUpdate()
end

-- Re-reads position and size from the settings and the events wanted.
function ST.Reposition()
	placedStealth, placedStance = false, false
	SyncEvents()
	UpdateBoth()
end

-------------------------------------------------------------------------------
--  Lifecycle
-------------------------------------------------------------------------------
local function Teardown()
	StopStanceSound()
	stanceSoundFired = false
	for e in pairs(registered) do ev:UnregisterEvent(e) end
	wipe(registered)
	if stealthFrame then stealthFrame:Hide() end
	if stanceFrame then stanceFrame:Hide() end
end

Q.RegisterRefresh(SECTION, function()
	StopStanceSound()
	stanceSoundFired = false
	ST.Reposition()
end)
Q.RegisterReset(SECTION, function()
	Teardown()
	Q.ClearDB(SECTION)
end)
Q.OnSpecChanged(function()
	StopStanceSound()
	stanceSoundFired = false
	stealthed = IsStealthed() and true or false
	SyncEvents()
	UpdateBoth()
end)
Q.OnZoneChanged(function()
	local was = inInstance
	inInstance = Q.InDungeonOrRaid()
	if was ~= inInstance then UpdateBoth() end
end)
Q.OnUnlockModeChanged(function() UpdateBoth() end)

-------------------------------------------------------------------------------
--  Events (only while a half needs them)
-------------------------------------------------------------------------------
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_LOGOUT")

local function WantedEvents(t, out)
	wipe(out)
	local stealthOn = t.enabled and true or false
	local stanceOn = t.stanceEnabled and true or false
	if not (stealthOn or stanceOn) then return out end
	out.PLAYER_REGEN_DISABLED = true
	out.PLAYER_REGEN_ENABLED = true
	out.UNIT_AURA = true   -- mounting (and Righteous Fury)
	if stealthOn and IsStealthSpec() then out.UPDATE_STEALTH = true end
	if stanceOn then out.UPDATE_SHAPESHIFT_FORM = true end
	if stealthOn and t.groupOnly then out.GROUP_ROSTER_UPDATE = true end
	if (stealthOn and t.disableWhenRested) or (stanceOn and t.stanceDisableWhenRested) then
		out.PLAYER_UPDATE_RESTING = true
	end
	return out
end

function SyncEvents()
	inCombat = UnitAffectingCombat("player") and true or false
	stealthed = IsStealthed() and true or false
	isResting = IsResting() and true or false
	inInstance = Q.InDungeonOrRaid()
	WantedEvents(DB(), wanted)
	for e in pairs(wanted) do
		if not registered[e] then
			registered[e] = true
			if e == "UNIT_AURA" then
				ev:RegisterUnitEvent(e, "player")
			else
				ev:RegisterEvent(e)
			end
		end
	end
	for e in pairs(registered) do
		if not wanted[e] then
			registered[e] = nil
			ev:UnregisterEvent(e)
		end
	end
end

ev:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGOUT" then
		StopStanceSound()
		return
	end
	if event == "PLAYER_LOGIN" then
		ST.Reposition()
		return
	end
	if event == "UPDATE_STEALTH" then
		stealthed = IsStealthed() and true or false
		ST.StealthUpdate()
		return
	end
	if event == "UPDATE_SHAPESHIFT_FORM" then
		ST.StanceUpdate()
		return
	end
	if event == "GROUP_ROSTER_UPDATE" then
		ST.StealthUpdate()
		return
	end
	if event == "PLAYER_REGEN_DISABLED" then
		inCombat = true
	elseif event == "PLAYER_REGEN_ENABLED" then
		inCombat = false
	elseif event == "PLAYER_UPDATE_RESTING" then
		isResting = IsResting() and true or false
	elseif event == "UNIT_AURA" then
		-- Stealth also shows up as an aura (Vanish, Shadowmeld).
		stealthed = IsStealthed() and true or false
	end
	UpdateBoth()
end)

-------------------------------------------------------------------------------
--  Unlock Mode
-------------------------------------------------------------------------------
Q.RegisterMover({
	key      = "NaowhUI_StealthReminder",
	label    = "Stealth Reminder",
	order    = 110,
	section  = SECTION,
	db       = DB,
	apply    = ST.Reposition,
	getFrame = function() BuildFrames(); return stealthFrame end,
	pointKey = "point", xKey = "x", yKey = "y",
	widthKey = "width", heightKey = "height",
	isHidden = function() return not DB().enabled end,
})
Q.RegisterMover({
	key      = "NaowhUI_StanceReminder",
	label    = "Stance Reminder",
	order    = 120,
	section  = SECTION,
	db       = DB,
	apply    = ST.Reposition,
	getFrame = function() BuildFrames(); return stanceFrame end,
	pointKey = "stancePoint", xKey = "stanceX", yKey = "stanceY",
	widthKey = "stanceWidth", heightKey = "stanceHeight",
	isHidden = function() return not DB().stanceEnabled end,
})
