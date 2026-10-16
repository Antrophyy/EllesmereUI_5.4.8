-------------------------------------------------------------------------------
--  EUI_ResourceBars_TotemBar.lua  (5.4.8 port of the EllesmereUI Resource Bars)
--
--  The totem bar: square icons for the active totems (GetTotemInfo 1..4,
--  shaman totems, druid mushrooms, monk statues, death knight ghoul, ...)
--  in the retail Totem Bar look: pixel border, zoomed icons, cooldown swipe
--  and a timer. Retail re-skins Blizzard's TotemFrame; 5.4.8's TotemFrame
--  lives on the player frame, so the bar draws its own four buttons.
--  enabledClasses: nil = off; { SHAMAN = true, ... } = on for those classes.
-------------------------------------------------------------------------------
local addonName, P = ...
local ns = P.ns
local ERB = P.ERB

local floor, max = math.floor, math.max
local format = string.format
local GetTime = GetTime
local MAX = MAX_TOTEMS or 4

local bar
local buttons = {}

local function TCfg()
	return P.Profile().totemBar
end

local function Active()
	local t = TCfg()
	local class = select(2, UnitClass("player"))
	return t.enabledClasses and class and t.enabledClasses[class] and true or false
end
ERB.TotemBarActive = Active

local function TimerText(sec)
	if sec >= 60 then
		return format("%dm", floor(sec / 60 + 0.5))
	elseif sec >= 10 then
		return format("%d", floor(sec + 0.5))
	end
	return format("%.1f", sec)
end

local function ButtonOnUpdate(self, elapsed)
	self.acc = (self.acc or 0) + elapsed
	if self.acc < 0.1 then
		return
	end
	self.acc = 0
	local left = (self.start or 0) + (self.duration or 0) - GetTime()
	if left <= 0 then
		self.timer:SetText("")
		self:SetScript("OnUpdate", nil)
		return
	end
	self.timer:SetText(TimerText(left))
end

local function CreateButton(i)
	local b = CreateFrame("Button", nil, bar)
	b.slot = i
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetAllPoints()
	b.icon:SetTexCoord(0.055, 0.945, 0.055, 0.945)
	b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
	b.cd:SetAllPoints()
	if b.cd.SetDrawEdge then
		b.cd:SetDrawEdge(false)
	end
	b.cd.noCooldownCount = true
	b.border = P.CreateBorder(b, 3)
	b.timer = P.NewText(b.border, 11)
	b.timer:SetPoint("CENTER")
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetTotem(self.slot)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	buttons[i] = b
	return b
end

local function GrowDir(t)
	local vertical = t.orientation == "VERTICAL"
	local d = t.growDirection
	if vertical then
		return (d == "UP" or d == "CENTER") and d or "DOWN", true
	end
	return (d == "LEFT" or d == "CENTER") and d or "RIGHT", false
end

local function UpdateTotems()
	if not bar then
		return
	end
	local t = TCfg()
	if not Active() and not ERB.unlockActive then
		bar:SetAlpha(0)
		bar:Hide()
		return
	end
	bar:Show()
	bar:SetAlpha(1)
	local size = t.iconSize or 30
	local sp = P.Snap(t.spacing or 2, bar)
	local dir, vertical = GrowDir(t)
	local list = {}
	for i = 1, MAX do
		local have, name, start, duration, icon = GetTotemInfo(i)
		local b = buttons[i] or CreateButton(i)
		if have and icon and icon ~= "" and duration and duration > 0 then
			list[#list + 1] = b
			b.icon:SetTexture(icon)
			b.start, b.duration = start, duration
			CooldownFrame_SetTimer(b.cd, start, duration, 1)
			if t.showTimer ~= false then
				P.SetFont(b.timer, t.timerSize or 11)
				b:SetScript("OnUpdate", ButtonOnUpdate)
				ButtonOnUpdate(b, 1)
			else
				b.timer:SetText("")
				b:SetScript("OnUpdate", nil)
			end
			b:Show()
		else
			b:Hide()
			b:SetScript("OnUpdate", nil)
		end
	end
	local n = #list
	local total = n * size + max(0, n - 1) * sp
	for idx, b in ipairs(list) do
		b:SetSize(size, size)
		b:ClearAllPoints()
		local off = (idx - 1) * (size + sp)
		if vertical then
			if dir == "UP" then
				b:SetPoint("BOTTOM", bar, "BOTTOM", 0, off)
			elseif dir == "CENTER" then
				b:SetPoint("TOP", bar, "CENTER", 0, total / 2 - off)
			else
				b:SetPoint("TOP", bar, "TOP", 0, -off)
			end
		else
			if dir == "LEFT" then
				b:SetPoint("RIGHT", bar, "RIGHT", -off, 0)
			elseif dir == "CENTER" then
				b:SetPoint("LEFT", bar, "CENTER", -total / 2 + off, 0)
			else
				b:SetPoint("LEFT", bar, "LEFT", off, 0)
			end
		end
		b.border:Apply(t.borderSize or 0, t.borderR, t.borderG, t.borderB, t.borderA)
		b.border:SetFrameLevel(b:GetFrameLevel() + (t.borderBehind and 0 or 3))
	end
end
ERB.UpdateTotems = UpdateTotems

local function LayoutTotemBar()
	local t = TCfg()
	if not bar then
		bar = CreateFrame("Frame", "ERB_TotemBarFrame", UIParent)
		bar:SetClampedToScreen(true)
		ERB.totemFrame = bar
	end
	bar:SetFrameStrata(t.frameStrata or "MEDIUM")
	bar:SetFrameLevel(15)
	local size = t.iconSize or 30
	local sp = t.spacing or 2
	local maxDim = size * MAX + sp * (MAX - 1)
	if t.orientation == "VERTICAL" then
		bar:SetSize(size, maxDim)
	else
		bar:SetSize(maxDim, size)
	end
	P.UnlockPlace(bar, "ERB_TotemBar", function()
		bar:ClearAllPoints()
		local pos = t.unlockPos
		if pos and pos.point then
			bar:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, P.Snap(pos.x or 0, bar), P.Snap(pos.y or 0, bar))
		else
			bar:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
		end
	end)
	UpdateTotems()
end
ERB.LayoutTotemBar = LayoutTotemBar

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_TOTEM_UPDATE")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function()
	if ERB.db then
		UpdateTotems()
	end
end)

P.OnApply(LayoutTotemBar)

function ERB.RegisterTotemUnlock()
	if not ns.RegisterUnlockElements then
		return
	end
	ns:RegisterUnlockElements({
		P.UnlockElement("ERB_TotemBar", "Totem Bar", 5, function() return bar end,
			function() return TCfg() end, Active),
	}, "EllesmereUIResourceBars")
end
