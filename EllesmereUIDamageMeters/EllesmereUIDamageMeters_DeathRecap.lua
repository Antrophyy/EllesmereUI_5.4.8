-- Death recap on the Release Spirit popup: when you die, what killed you is
-- shown right under Blizzard's DEATH popup, already expanded (newest event
-- first, with your health after each one). Reads the engine's death recap.

local ns = EllesmereUI
local DM = ns.EDM
local E = ns.EDMEngine
if not DM or not E then return end

local MAX_LINES = 12
local LINE_H = 18
local HDR_H = 38
local RECENT = 60 -- seconds: only a death this recent belongs to the popup
local KILL_WINDOW = 3 -- seconds: a hit this close to the death is what killed you

local panel, anchor
local Show, Place, AnchorPopup -- forward

-- Your newest death in Overall (deaths join Overall whatever fight they belong to).
local function LastDeath()
	local overall = E.GetOverall()
	local deaths = overall and overall.deaths
	if not deaths then return nil end
	local me = UnitName("player")
	for i = #deaths, 1, -1 do
		local d = deaths[i]
		if d.name == me then
			local age = GetTime() - (d.at or 0)
			if age >= -1 and age <= RECENT then return d, overall end
			return nil
		end
	end
	return nil
end

local function Line(i)
	local l = panel.lines[i]
	if l then return l end
	l = CreateFrame("StatusBar", nil, panel)
	l:SetHeight(LINE_H)
	l:SetPoint("TOPLEFT", panel, "TOPLEFT", 6 + LINE_H + 2, -(HDR_H + (i - 1) * (LINE_H + 1)))
	l:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -(HDR_H + (i - 1) * (LINE_H + 1)))
	l.bg = l:CreateTexture(nil, "BACKGROUND")
	l.bg:SetAllPoints()
	l.bg:SetTexture(1, 1, 1, 0.06)
	l.icon = l:CreateTexture(nil, "ARTWORK")
	l.icon:SetSize(LINE_H, LINE_H)
	l.icon:SetPoint("RIGHT", l, "LEFT", -2, 0)
	l.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	l.name = l:CreateFontString(nil, "OVERLAY")
	l.name:SetPoint("LEFT", l, "LEFT", 4, 0)
	l.name:SetPoint("RIGHT", l, "RIGHT", -72, 0)
	l.name:SetJustifyH("LEFT")
	l.name:SetWordWrap(false)
	l.amount = l:CreateFontString(nil, "OVERLAY")
	l.amount:SetPoint("RIGHT", l, "RIGHT", -4, 0)
	l.amount:SetJustifyH("RIGHT")
	panel.lines[i] = l
	return l
end

local function Build()
	if panel then return panel end
	panel = CreateFrame("Frame", "EllesmereUIDMDeathRecap", UIParent)
	panel:SetFrameStrata("DIALOG")
	panel:SetClampedToScreen(true)
	panel:Hide()
	panel.bg = panel:CreateTexture(nil, "BACKGROUND")
	panel.bg:SetAllPoints()
	panel.bg:SetTexture(0.05, 0.05, 0.05, 0.92)
	panel.edges = {}
	for i = 1, 4 do
		local t = panel:CreateTexture(nil, "BORDER")
		t:SetTexture(0, 0, 0, 1)
		panel.edges[i] = t
	end
	panel.edges[1]:SetPoint("TOPLEFT"); panel.edges[1]:SetPoint("TOPRIGHT"); panel.edges[1]:SetHeight(1)
	panel.edges[2]:SetPoint("BOTTOMLEFT"); panel.edges[2]:SetPoint("BOTTOMRIGHT"); panel.edges[2]:SetHeight(1)
	panel.edges[3]:SetPoint("TOPLEFT"); panel.edges[3]:SetPoint("BOTTOMLEFT"); panel.edges[3]:SetWidth(1)
	panel.edges[4]:SetPoint("TOPRIGHT"); panel.edges[4]:SetPoint("BOTTOMRIGHT"); panel.edges[4]:SetWidth(1)
	panel.title = panel:CreateFontString(nil, "OVERLAY")
	panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -5)
	panel.title:SetJustifyH("LEFT")
	panel.sub = panel:CreateFontString(nil, "OVERLAY")
	panel.sub:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -20)
	panel.sub:SetPoint("RIGHT", panel, "RIGHT", -6, 0)
	panel.sub:SetJustifyH("LEFT")
	panel.sub:SetWordWrap(false)
	panel.lines = {}
	-- Click anywhere on it to expand / collapse the event lines (remembered,
	-- collapsed to the "Killed by" line by default).
	panel:EnableMouse(true)
	panel:SetScript("OnMouseUp", function(_, button)
		if button ~= "LeftButton" then return end
		local c = DM.DB()
		c.deathRecapExpanded = not c.deathRecapExpanded
		Show()
	end)
	-- Stay while you are dead (a resurrection offer replaces the DEATH popup,
	-- releasing hides it): follow whichever popup is up, gone once alive.
	panel.elapsed = 0
	panel:SetScript("OnUpdate", function(self, dt)
		self.elapsed = self.elapsed + dt
		if self.elapsed < 0.2 then return end
		self.elapsed = 0
		if UnitIsDeadOrGhost and not UnitIsDeadOrGhost("player") then
			self:Hide()
			return
		end
		local popup = AnchorPopup()
		if popup ~= anchor or (anchor and not anchor:IsShown()) then Place(popup) end
	end)
	return panel
end

local function Popup(which)
	local name = StaticPopup_Visible and StaticPopup_Visible(which or "DEATH")
	return name and _G[name] or nil
end

-- The popup the recap hangs under while you are dead.
local ANCHORS = { "DEATH", "RESURRECT", "RESURRECT_NO_SICKNESS", "RESURRECT_NO_TIMER" }
function AnchorPopup()
	for i = 1, #ANCHORS do
		local popup = Popup(ANCHORS[i])
		if popup then return popup end
	end
	return nil
end

-- Under the popup, or where the first popup sits when none is up.
function Place(popup)
	anchor = popup
	panel:ClearAllPoints()
	if popup then
		panel:SetPoint("TOP", popup, "BOTTOM", 0, -4)
		panel:SetWidth(math.max(popup:GetWidth() or 320, 320))
	else
		panel:SetPoint("TOP", UIParent, "TOP", 0, -135)
		panel:SetWidth(320)
	end
end

function Show()
	if DM.DB().deathRecapPopup == false then
		if panel then panel:Hide() end
		return
	end
	-- Opened by the DEATH popup; already open (collapse click), it stays.
	local popup = Popup() or (panel and panel:IsShown() and AnchorPopup())
	local death, overall = LastDeath()
	if not death and panel and panel:IsShown() then death, overall = panel.death, panel.overall end
	if not (popup or (panel and panel:IsShown())) or not death then
		if panel then panel:Hide() end
		return
	end
	Build()
	panel.death, panel.overall = death, overall
	local list = DM.GetBreakdown(overall, DM.T.Deaths, { death = death })
	local tex = DM.TexturePath(DM.DB().barTexture)
	DM.SetFont(panel.title, 12)
	DM.SetFont(panel.sub, 11)
	local expanded = DM.DB().deathRecapExpanded and true or false
	panel.title:SetText(expanded and "Death Recap |cff999999(click to collapse)|r" or "Death Recap |cff999999(click to expand)|r")
	panel.title:SetTextColor(DM.Accent())
	local killer
	for i = 1, #list do
		if not list[i].heal then killer = list[i] break end
	end
	-- Only a hit right before the death killed you. An older one means the
	-- killing blow never reached the combat log (out of range, scripted kill).
	if killer and (killer.ago or 0) < -KILL_WINDOW then killer = nil end
	if killer then
		local text = "Killed by " .. killer.label
		if killer.source then text = text .. " |cff999999(" .. killer.source .. ")|r" end
		if killer.instakill then
			text = text .. " |cffff5f5fInstant kill|r"
		else
			text = text .. " |cffff5f5f" .. DM.Abbrev(killer.amount) .. "|r"
		end
		if killer.overkill then text = text .. " |cff999999(" .. DM.Abbrev(killer.overkill) .. " overkill)|r" end
		panel.sub:SetText(text)
	elseif list[1] and list[1].ago then
		panel.sub:SetText(format("|cff999999Killing blow not in the combat log (last event %.1fs before).|r", -list[1].ago))
	else
		panel.sub:SetText("|cff999999No damage recorded.|r")
	end
	local top = 1
	for i = 1, #list do if list[i].amount > top then top = list[i].amount end end
	local n = expanded and math.min(#list, MAX_LINES) or 0
	for i = 1, n do
		local e, l = list[i], Line(i)
		DM.SetFont(l.name, 11)
		DM.SetFont(l.amount, 11)
		l:SetStatusBarTexture(tex)
		if list.hasHP then
			l:SetMinMaxValues(0, 100)
			l:SetValue(e.hp or 0)
		else
			l:SetMinMaxValues(0, top)
			l:SetValue(e.amount)
		end
		if e.heal then
			l:SetStatusBarColor(0.3, 0.75, 0.3, 0.7)
		else
			l:SetStatusBarColor(0.75, 0.25, 0.25, 0.7)
		end
		l.icon:SetTexture(e.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
		local name, amount = DM.DeathLine(e)
		l.name:SetText(name)
		l.amount:SetText(amount)
		l:Show()
	end
	for i = n + 1, #panel.lines do panel.lines[i]:Hide() end
	Place(AnchorPopup())
	panel:SetHeight(n > 0 and (HDR_H + n * (LINE_H + 1) + 4) or (HDR_H - 2))
	panel.elapsed = 0
	panel:Show()
end
DM.ShowDeathRecapPopup = Show

-- The popup is shown on PLAYER_DEAD, maybe before the engine records the
-- death; look again a moment later and whenever a death is recorded.
if hooksecurefunc then
	hooksecurefunc("StaticPopup_Show", function(which)
		if which == "DEATH" then DM.After(0.1, Show) end
	end)
end
E.Listen(function(what)
	if what == "death" and Popup() then DM.After(0.1, Show) end
end)
