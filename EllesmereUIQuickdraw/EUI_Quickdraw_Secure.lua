-------------------------------------------------------------------------------
--  EUI_Quickdraw_Secure.lua (5.4.8 port of retail Secure / Gates / Runtime)
--
--  One secure button per action menu (SecureActionButtonTemplate), clicked
--  by the menu's key through an override binding (SetOverrideBindingClick on
--  the EUI_RADIAL<n> keys). A restricted snippet wrapped on its OnClick:
--    key down  -> shows the menu's secure frame (at the cursor: a full screen
--                 secure frame's GetMousePosition gives the cursor point),
--                 binds Escape / Menu Cancel Action / Fan mouse wheel /
--                 Toggled Menu Select Action to this button while it is open;
--    key up    -> reads the pointer from a big secure frame centred on the
--                 menu (GetMousePosition -> dx, dy), picks the entry (the HIT
--                 code below: angle for Arc, cell for Grid, centred entry for
--                 Fan), writes that entry's type / spell / item / macro /
--                 macrotext / marker attributes and lets the click fire it.
--  5.4.8 restricted frames have GetMousePosition, SetBindingClick,
--  ClearBindings and math.atan2 / math.sqrt, so this works in combat.
--  Entries with no secure action (battle pets, specs, random mount, raid
--  target markers) fire from Lua in PostClick.
--  Retail arms nested menus with gate frames (the path the pointer took); this
--  port decides by where the pointer is on release.
-------------------------------------------------------------------------------
local ns = EllesmereUI
local QD = ns.Quickdraw

local Secure = { buttons = {}, rings = {} }
QD.Secure = Secure

local PTR_SIZE = 4096
local ACTION_KEYS = { "spell", "item", "macro", "macrotext", "marker", "action" }

-- Picks the entry under dx, dy (menu units from the centre). Sets hitC.
-- Shared by the restricted snippet and the drawing code, so what is
-- highlighted is what fires. Restricted-environment safe (math.*, no globals).
local HIT = [[
local L = self:GetAttribute("qd-layout")
local n = self:GetAttribute("qd-n") or 0
if n > 0 then
	if L == "GRID" then
		if not noPtr then
			local cols = self:GetAttribute("qd-cols") or 1
			local rows = self:GetAttribute("qd-rows") or 1
			local pitch = self:GetAttribute("qd-pitch") or 50
			local col = math.floor(dx / pitch + cols / 2)
			local row = math.floor(-dy / pitch + rows / 2)
			if col >= 0 and col < cols and row >= 0 and row < rows then
				local c = row * cols + col + 1
				if c <= n then hitC = c end
			end
		end
	elseif L == "FAN" then
		local sel = self:GetAttribute("qd-sel") or 1
		if sel > n then sel = n end
		hitC = sel
		if not noPtr and self:GetAttribute("qd-mouse") then
			local pitch = self:GetAttribute("qd-pitch") or 50
			local vis = self:GetAttribute("qd-vis") or 0
			local half = self:GetAttribute("qd-half") or 20
			local along, across = dx, dy
			if not self:GetAttribute("qd-horiz") then along, across = -dy, dx end
			if math.abs(across) <= half then
				local off = math.floor(along / pitch + 0.5)
				if off >= -vis and off <= vis and sel + off >= 1 and sel + off <= n then
					hitC = sel + off
				end
			end
		end
	elseif not noPtr then
		local TWO_PI = 2 * math.pi
		local dist = math.sqrt(dx * dx + dy * dy)
		local theta = math.atan2(dx, dy)
		local band = self:GetAttribute("qd-cband")
		if band and dist >= band then
			for i = 1, n do
				local m = self:GetAttribute("qd-nest" .. i)
				if m and m > 0 and not hitC then
					local cs = self:GetAttribute("qd-cs" .. i) or 0
					local cst = self:GetAttribute("qd-cst" .. i) or 0
					if cst > 0 then
						local rel = (theta - cs + cst * 0.5) % TWO_PI
						if rel < m * cst then
							hitC = (self:GetAttribute("qd-nb" .. i) or 0) + math.floor(rel / cst) + 1
						end
					end
				end
			end
		end
		if not hitC and dist >= (self:GetAttribute("qd-dead") or 0) then
			local step = self:GetAttribute("qd-step") or 0
			local start = self:GetAttribute("qd-start") or 0
			if step == 0 then
				hitC = 1
			else
				local rel = theta - start
				if self:GetAttribute("qd-full") then
					hitC = (math.floor(rel / step + 0.5) % n) + 1
				else
					rel = rel % TWO_PI
					if rel <= (n - 1) * step + step * 0.5 then
						local idx = math.floor(rel / step + 0.5) + 1
						if idx >= 1 and idx <= n then hitC = idx end
					end
				end
			end
		end
	end
end
]]
Secure.HIT = HIT

local OPEN = [[
	if self:GetAttribute("qd-cursor") then
		local scr = self:GetFrameRef("screen")
		local sx, sy = scr:GetMousePosition()
		if sx then
			local s = ring:GetScale()
			if not s or s <= 0 then s = 1 end
			ring:ClearAllPoints()
			ring:SetPoint("CENTER", scr, "BOTTOMLEFT", sx * scr:GetWidth() / s, sy * scr:GetHeight() / s)
		end
	end
	ring:Show()
	local me = self:GetName()
	self:SetBindingClick(true, "ESCAPE", me, "QDCancel")
	local ck = self:GetAttribute("qd-cancelkey")
	if ck then self:SetBindingClick(true, ck, me, "QDCancel") end
	if self:GetAttribute("qd-layout") == "FAN" then
		self:SetBindingClick(true, "MOUSEWHEELUP", me, "QDWheelUp")
		self:SetBindingClick(true, "MOUSEWHEELDOWN", me, "QDWheelDown")
	end
	if self:GetAttribute("qd-toggle") then
		local sk = self:GetAttribute("qd-confirmkey")
		if sk then self:SetBindingClick(true, sk, me, "QDConfirm") end
	end
]]

local CLICK = [[
local ring = self:GetFrameRef("ring")
self:SetAttribute("qd-fired", nil)
if button == "QDWheelUp" or button == "QDWheelDown" then
	if down and ring:IsShown() then
		local n = self:GetAttribute("qd-n") or 0
		local sel = self:GetAttribute("qd-sel") or 1
		local d = (button == "QDWheelUp") and -1 or 1
		if self:GetAttribute("qd-inv") then d = -d end
		sel = sel + d
		if sel > n then sel = n end
		if sel < 1 then sel = 1 end
		self:SetAttribute("qd-sel", sel)
	end
	return false
end
if button == "QDCancel" then
	if down then
		ring:Hide()
		self:ClearBindings()
	end
	return false
end
if button == "QDConfirm" then
	if not down or not ring:IsShown() then return false end
else
	if down then
		if ring:IsShown() then
			ring:Hide()
			self:ClearBindings()
			return false
		end
		if (self:GetAttribute("qd-n") or 0) < 1 then return false end
]] .. OPEN .. [[
		return false
	end
	if not ring:IsShown() then return false end
	if self:GetAttribute("qd-toggle") then return false end
end
local ptr = self:GetFrameRef("ptr")
local fx, fy = ptr:GetMousePosition()
local noPtr = not fx
local dx, dy = 0, 0
if fx then
	dx = (fx - 0.5) * ptr:GetWidth()
	dy = (fy - 0.5) * ptr:GetHeight()
end
local hitC = nil
]] .. HIT .. [[
ring:Hide()
self:ClearBindings()
if not hitC then return false end
local t = self:GetAttribute("qd-t" .. hitC)
if not t then return false end
self:SetAttribute("spell", nil)
self:SetAttribute("item", nil)
self:SetAttribute("macro", nil)
self:SetAttribute("macrotext", nil)
self:SetAttribute("marker", nil)
self:SetAttribute("action", nil)
self:SetAttribute("qd-fired", hitC)
if t == "insecure" then
	self:SetAttribute("type", nil)
	return "LeftButton"
end
local k = self:GetAttribute("qd-k" .. hitC)
local v = self:GetAttribute("qd-v" .. hitC)
local cyc = self:GetAttribute("qd-cyc" .. hitC)
if cyc then
	local pos = ((self:GetAttribute("qd-cp" .. hitC) or 0) % cyc) + 1
	self:SetAttribute("qd-cp" .. hitC, pos)
	v = self:GetAttribute("qd-cv" .. hitC .. "-" .. pos)
end
self:SetAttribute("type", t)
if k then self:SetAttribute(k, v) end
local a = self:GetAttribute("qd-a" .. hitC)
if a then self:SetAttribute("action", a) end
return "LeftButton"
]]
Secure.CLICK = CLICK

-- Insecure copy of HIT for the drawing code (reads the button's attributes).
local hitFn = loadstring("local self, dx, dy, noPtr = ...; local hitC = nil; " .. HIT .. " return hitC")
Secure.hitFn = hitFn
function Secure.InsecureHit(btn, dx, dy)
	if not btn then return nil end
	return hitFn(btn, dx or 0, dy or 0, dx == nil)
end

-------------------------------------------------------------------------------
--  Frames
-------------------------------------------------------------------------------
local header, screen
local bindOwner = CreateFrame("Frame", "EUIQuickdrawBindingOwner", UIParent)

local function Shared()
	if header then return end
	header = CreateFrame("Frame", "EUIQuickdrawHeader", UIParent, "SecureHandlerStateTemplate")
	screen = CreateFrame("Frame", "EUIQuickdrawScreen", UIParent, "SecureHandlerStateTemplate")
	screen:SetAllPoints(UIParent)
	screen:EnableMouse(false)
	screen:Show()
end

local function OnPostClick(self)
	local c = self:GetAttribute("qd-fired")
	local cell = c and self.qdCells and self.qdCells[c]
	if cell and cell.insecure then
		QD.FireInsecure(cell.slot)
	end
end

-- The secure button + frames of menu `index` (out of combat only).
local function Ensure(index)
	local btn = Secure.buttons[index]
	if btn then return btn end
	Shared()
	local ring = CreateFrame("Frame", "EUIQuickdrawRing" .. index, UIParent, "SecureHandlerStateTemplate")
	ring:SetFrameStrata("DIALOG")
	ring:SetSize(1, 1)
	ring:SetPoint("CENTER")
	ring:EnableMouse(false)
	ring:Hide()
	local ptr = CreateFrame("Frame", "EUIQuickdrawPointer" .. index, ring, "SecureHandlerStateTemplate")
	ptr:SetSize(PTR_SIZE, PTR_SIZE)
	ptr:SetPoint("CENTER")
	ptr:EnableMouse(false)

	btn = CreateFrame("Button", "EUIQuickdrawPalette" .. index, UIParent, "SecureActionButtonTemplate")
	btn:SetSize(1, 1)
	btn:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -10, -10)
	btn:SetAlpha(0)
	btn:EnableMouse(false)
	btn:RegisterForClicks("AnyUp", "AnyDown")
	SecureHandlerSetFrameRef(btn, "ring", ring)
	SecureHandlerSetFrameRef(btn, "ptr", ptr)
	SecureHandlerSetFrameRef(btn, "screen", screen)
	SecureHandlerWrapScript(btn, "OnClick", header, CLICK)
	btn:SetScript("PostClick", OnPostClick)
	btn:HookScript("OnAttributeChanged", function(_, name)
		if name == "qd-sel" then QD.View.LayoutFan(index) end
	end)
	btn:Show()

	Secure.buttons[index] = btn
	Secure.rings[index] = ring
	QD.View.Ensure(index, ring)
	return btn
end
Secure.Ensure = Ensure

-- Writes one menu's entries and geometry into its secure button.
local function Push(index, active)
	local btn = Secure.buttons[index]
	if not btn and not active then return end
	btn = Ensure(index)
	local ring = Secure.rings[index]
	ring:Hide()
	local L
	if active then
		L = QD.BuildLayout(index)
	else
		-- idle menu (no key, module off, deleted): nothing to pick
		L = { mode = "ARC", n = 0, total = 0, cells = {}, iconSize = 40, index = index,
			attrs = { ["qd-layout"] = "ARC", ["qd-n"] = 0 } }
	end
	local pa = QD.PA(index)

	-- clear the previous push
	for _, key in ipairs(btn.qdAttrKeys or {}) do btn:SetAttribute(key, nil) end
	for c = 1, btn.qdTotal or 0 do
		btn:SetAttribute("qd-t" .. c, nil)
		btn:SetAttribute("qd-k" .. c, nil)
		btn:SetAttribute("qd-v" .. c, nil)
		btn:SetAttribute("qd-a" .. c, nil)
		btn:SetAttribute("qd-cyc" .. c, nil)
	end
	local keys = {}
	for key, value in pairs(L.attrs) do
		btn:SetAttribute(key, value)
		keys[#keys + 1] = key
	end
	local cursor = pa.centerMode ~= "SCREEN"
	btn:SetAttribute("qd-cursor", cursor and true or nil)
	btn:SetAttribute("qd-toggle", pa.toggleMode and true or nil)
	local p = QD.P()
	local sk = type(p.confirmKey) == "string" and p.confirmKey ~= "" and p.confirmKey or nil
	local ck = type(p.cancelKey) == "string" and p.cancelKey ~= "" and p.cancelKey or nil
	btn:SetAttribute("qd-confirmkey", sk)
	btn:SetAttribute("qd-cancelkey", ck)
	keys[#keys + 1] = "qd-cursor"
	btn.qdAttrKeys = keys

	for c = 1, L.total or 0 do
		local cell = L.cells[c]
		local t, k, v, a = QD.ResolveAction(cell.slot, pa)
		if t == "cycle" then
			local steps = QD.CycleWorldSteps()
			btn:SetAttribute("qd-cyc" .. c, #steps)
			for j, step in ipairs(steps) do btn:SetAttribute("qd-cv" .. c .. "-" .. j, step) end
			t, k, v, a = "worldmarker", "marker", steps[1], "set"
		end
		cell.insecure = (t == "insecure") or nil
		btn:SetAttribute("qd-t" .. c, t)
		btn:SetAttribute("qd-k" .. c, k)
		btn:SetAttribute("qd-v" .. c, v)
		btn:SetAttribute("qd-a" .. c, a)
	end
	btn.qdTotal = L.total or 0
	btn.qdCells = L.cells
	local sel = btn:GetAttribute("qd-sel") or 1
	if sel > (L.n or 0) or sel < 1 then sel = 1 end
	btn:SetAttribute("qd-sel", sel)

	local scale = math.max(0.5, math.min(2, pa.scale or 1))
	ring:SetScale(scale)
	ring:ClearAllPoints()
	if cursor then
		ring:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	else
		ring:SetPoint("CENTER", UIParent, "CENTER", (pa.posX or 0) / scale, (pa.posY or 0) / scale)
	end
	QD.View.Layout(index, L, ring)
end
Secure.Push = Push

-- Every menu + the key overrides (retail _EQD_Apply). Out of combat only.
local function ApplyNow()
	local p = QD.P()
	ClearOverrideBindings(bindOwner)
	QD.appliedKeys = QD.KeySignature()
	local count = QD.PaletteCount()
	for index = 1, QD.MAX_PALETTES do
		local k1, k2 = QD.GetKey(index)
		local active = p.enabled == true and index <= count and (k1 or k2) and QD.PaletteActive(index)
			and #QD.UsableSlots(index) > 0
		Push(index, active and true or false)
		if active then
			local name = Secure.buttons[index]:GetName()
			if k1 then SetOverrideBindingClick(bindOwner, true, k1, name) end
			if k2 then SetOverrideBindingClick(bindOwner, true, k2, name) end
		end
	end
end

function QD.Apply()
	QD.AfterCombat("apply", ApplyNow)
end

-- Events can come in bursts (bags, spells): apply once on the next frame.
local pending = CreateFrame("Frame")
pending:Hide()
pending:SetScript("OnUpdate", function(self)
	self:Hide()
	QD.Apply()
end)
function QD.RequestApply()
	pending:Show()
end
