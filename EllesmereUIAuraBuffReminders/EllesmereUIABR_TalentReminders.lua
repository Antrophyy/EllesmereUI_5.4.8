-------------------------------------------------------------------------------
--  EllesmereUIABR_TalentReminders.lua (5.4.8 port of retail Talent Reminders)
--
--  In a chosen dungeon / raid / PvP zone, shows the talent you want picked
--  when it is not (and, with "Show 'Not Needed' Reminder", shows it outside
--  those zones while it is picked).
--
--  5.4.8 changes: talents are the MoP 6-row talents. A reminder stores the
--  talent index (GetTalentInfo) plus its name; "picked" = the talent is
--  selected in the active spec group. Zones are matched by instance name.
--  Old entries with only a spellID still work (IsPlayerSpell / IsSpellKnown).
-------------------------------------------------------------------------------
local addonName, P = ...
local ns = EllesmereUI
local EABR = ns.ABR
if not EABR then return end
local D = P.DATA

local ICON_SIZE = 40
local anchor
local pool, active = {}, {}

local function Reminders()
	return EABR.Profile().talentReminders
end

-- Talent state by index in the active spec group.
function EABR.TalentInfo(index)
	local group = GetActiveSpecGroup and GetActiveSpecGroup() or nil
	local name, texture, tier, column, selected, available = GetTalentInfo(index, false, group)
	return name, texture, selected, tier, column
end

local function HasTalent(r)
	if r.talentIndex then
		local name, _, selected = EABR.TalentInfo(r.talentIndex)
		if name and r.spellName and name ~= r.spellName then
			-- Index points at another talent now (class changed): fall back to the name.
			for i = 1, 18 do
				local n, _, sel = EABR.TalentInfo(i)
				if n == r.spellName then return sel and true or false end
			end
			return false
		end
		return selected and true or false
	end
	if r.spellID then return EABR.Known(r.spellID) end
	return false
end
EABR.HasTalent = HasTalent

local function GetIcon(i)
	local f = pool[i]
	if f then return f end
	f = CreateFrame("Frame", "EABR_TalentIcon" .. i, anchor)
	f:SetSize(ICON_SIZE, ICON_SIZE)
	f:SetFrameStrata("MEDIUM")
	f:SetFrameLevel(100)
	local icon = f:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	f._icon = icon
	EABR.ApplyIconBorder(f)
	local text = f:CreateFontString(nil, "OVERLAY")
	EABR.SetABRFont(text, EABR.ResolveFontPath(), 11)
	text:SetPoint("TOP", f, "BOTTOM", 0, -2)
	text:SetTextColor(1, 1, 1, 1)
	f._text = text
	pool[i] = f
	return f
end

local function HideIcons()
	for _, f in pairs(pool) do f:Hide() end
	wipe(active)
end

local function Collect(out)
	local _, iType = GetInstanceInfo()
	local inInstance = iType == "party" or iType == "raid" or iType == "scenario" or iType == "arena" or iType == "pvp"
	if InCombatLockdown() or not inInstance or (EABR.InChallengeRun and EABR.InChallengeRun()) then return end
	local list = Reminders()
	if not list or #list == 0 then return end
	local zone = GetInstanceInfo()
	local _, playerClass = UnitClass("player")
	local spec = EABR.GetSpecID()
	for _, r in ipairs(list) do
		if (not r.class or r.class == playerClass) and not (r.talentSource == "spec" and r.specID and r.specID ~= spec) then
			local match = false
			for _, zn in ipairs(r.zoneNames or {}) do
				if zn == zone then match = true end
			end
			local has = HasTalent(r)
			local texture = r.icon or (r.spellID and EABR.Tex(r.spellID)) or "Interface\\Icons\\INV_Misc_QuestionMark"
			if match and not has then
				out[#out + 1] = { texture = texture, label = r.spellName or "Unknown" }
			elseif not match and r.showNotNeeded and has then
				out[#out + 1] = { texture = texture, label = (r.spellName or "Unknown") .. " (N/N)" }
			end
		end
	end
end

function EABR.TalentRefresh()
	if not anchor then return end
	HideIcons()
	if UnitIsDeadOrGhost("player") or IsResting() or (IsMounted() and IsFlying()) or UnitInVehicle("player") then return end
	local out = {}
	Collect(out)
	local n = #out
	if n == 0 then return end
	local p = EABR.Profile()
	anchor:ClearAllPoints()
	anchor:SetPoint("TOP", EABR.iconAnchor or UIParent, "BOTTOM", 0, p.talentReminderYOffset or -50)
	local spacing = 40
	local totalW = n * ICON_SIZE + (n - 1) * spacing
	for i, e in ipairs(out) do
		local f = GetIcon(i)
		f._icon:SetTexture(e.texture)
		EABR.SetABRFont(f._text, EABR.ResolveFontPath(), 11)
		f._text:SetText(e.label)
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", anchor, "TOP", -totalW / 2 + (i - 1) * (ICON_SIZE + spacing), 0)
		f:Show()
		active[#active + 1] = f
	end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		anchor = CreateFrame("Frame", "EABR_TalentAnchor", UIParent)
		anchor:SetSize(1, 1)
		anchor:SetFrameStrata("MEDIUM")
		anchor:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
		self:RegisterEvent("PLAYER_TALENT_UPDATE")
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		return
	end
	if event == "PLAYER_REGEN_DISABLED" then
		HideIcons()
		return
	end
	if EABR.RequestRefresh then EABR.RequestRefresh() end
end)
