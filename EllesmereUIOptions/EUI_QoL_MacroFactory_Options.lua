-- Settings for Quality of Life > QoL: the Macro Factory block at the top of
-- the page (retail EUI_MacroFactory.lua, EllesmereUI.BuildMacroFactory).
-- Left: the general macros, right: the macros of the current spec. Click an
-- icon to create its macro, right-click for its menu (create / delete, Show
-- Tooltip, extras, item options with drag to reorder). The macro list and
-- the macro writing live in EllesmereUIQoL_MacroFactory.lua (ns.MacroFactory).
-- Like retail, the block is kept out of the settings search.
-- 5.4.8: no SetColorTexture / clip children / smooth scrollbar (a spec list
-- longer than three rows scrolls with the mouse wheel), low frame levels.

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUIQoL") then
	return
end

local floor, max, min, abs = math.floor, math.max, math.min, math.abs

local ICON_SIZE = 40
local ICON_GAP = 40
local ICONS_PER_ROW = 4
local SPEC_ICONS_PER_ROW = 3
local SPEC_ICON_GAP = 70
local FIRST_ICON_Y = -34
local ROW_STRIDE = 66
local MAX_SPEC_VISIBLE_ROWS = 3
local MARKS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local MENU_BG = { 0.06, 0.06, 0.06 }

local function L(s) return ns.L(s) end

-- Small check box of the menus: returns a Refresh(on) function.
local function CheckBox(row, PP, EG)
	local box = CreateFrame("Frame", nil, row)
	box:SetSize(16, 16)
	box:SetPoint("RIGHT", row, "RIGHT", -10, 0)
	local bg = box:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetTexture(0.114, 0.106, 0.099, 1)
	local brd = ns.MakeBorder(box, 0.4, 0.4, 0.4, 0.6)
	local ck = box:CreateTexture(nil, "ARTWORK")
	ck:SetPoint("TOPLEFT", 2, -2)
	ck:SetPoint("BOTTOMRIGHT", -2, 2)
	return function(on)
		ck:SetTexture(EG.r, EG.g, EG.b, 1)
		if on then
			ck:Show()
			brd:SetColor(EG.r, EG.g, EG.b, 0.8)
		else
			ck:Hide()
			brd:SetColor(0.4, 0.4, 0.4, 0.6)
		end
	end
end

-- Menu row: hover highlight and a grey label that turns white on hover.
local function MenuRow(menu, y, h, fontPath, text)
	local r = CreateFrame("Button", nil, menu)
	r:SetHeight(h)
	r:SetFrameLevel(menu:GetFrameLevel() + 2)
	r:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, y)
	r:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -1, y)
	local hl = r:CreateTexture(nil, "ARTWORK")
	hl:SetAllPoints()
	hl:SetTexture(1, 1, 1, 0)
	local fs = r:CreateFontString(nil, "OVERLAY")
	fs:SetFont(fontPath, 13, "")
	fs:SetTextColor(0.75, 0.75, 0.75, 1)
	fs:SetPoint("LEFT", r, "LEFT", 12, 0)
	if text then fs:SetText(text) end
	r._hl, r._fs = hl, fs
	r:SetScript("OnEnter", function() fs:SetTextColor(1, 1, 1, 1); hl:SetTexture(1, 1, 1, 0.04) end)
	r:SetScript("OnLeave", function() fs:SetTextColor(0.75, 0.75, 0.75, 1); hl:SetTexture(1, 1, 1, 0) end)
	return r
end

local function MenuDivider(menu, y, h)
	local dv = CreateFrame("Frame", nil, menu)
	dv:SetHeight(h)
	dv:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, y)
	dv:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -1, y)
	local line = dv:CreateTexture(nil, "ARTWORK")
	line:SetHeight(1)
	line:SetPoint("LEFT", dv, "LEFT", 10, 0)
	line:SetPoint("RIGHT", dv, "RIGHT", -10, 0)
	line:SetTexture(1, 1, 1, 0.08)
end

ns.QoLO_BuildMacroFactory = function(p)
	local MF = ns.MacroFactory
	-- The search index runs the builders on a recorder (no frames): skip,
	-- like retail keeps the Macro Factory out of the search.
	if not MF or type(p.child) ~= "table" then
		return
	end
	local PP = ns.PP
	local EG = ns.ELLESMERE_GREEN
	local fontPath = (ns.GetFontPath and ns.GetFontPath()) or STANDARD_TEXT_FONT
	local After = ns.QoL.After

	p:CloseRow()
	local width = p:RowWidth()
	local halfW = width / 2
	local pad = floor((p.child:GetWidth() - width) / 2)
	local generalRows = math.ceil(#MF.GENERAL_DEFS / ICONS_PER_ROW)
	-- Constant height (the larger of the two sides), so a spec change can
	-- rebuild the right side without moving the settings below.
	local maxRows = max(generalRows, MAX_SPEC_VISIBLE_ROWS)
	local SECTION_H = 102 + ROW_STRIDE * (maxRows - 1)

	local container = CreateFrame("Frame", nil, p.child)
	container:SetSize(width, SECTION_H)
	container:SetPoint("TOPLEFT", p.child, "TOPLEFT", pad, p.y - 14)
	p.y = p.y - 14 - SECTION_H

	-- Center divider.
	local divider = container:CreateTexture(nil, "ARTWORK")
	divider:SetWidth(1)
	divider:SetPoint("TOP", container, "TOP", 0, 0)
	divider:SetPoint("BOTTOM", container, "BOTTOM", 0, 0)
	divider:SetTexture(1, 1, 1, 0.15)

	local allButtons = {}
	local openMenus = {}

	local function HideMenus()
		for _, m in ipairs(openMenus) do
			if m:IsShown() then m:Hide() end
		end
	end
	container:SetScript("OnHide", HideMenus)

	-------------------------------------------------------------------------
	-- One side: title and a grid of macro icons. Returns its frame.
	-------------------------------------------------------------------------
	local function BuildGroup(defs, isLeft, titleText, perRow, gap, maxVisibleRows)
		perRow = perRow or ICONS_PER_ROW
		gap = gap or ICON_GAP
		local group = CreateFrame("Frame", nil, container)
		group:SetSize(halfW, SECTION_H)
		group:SetPoint("TOPLEFT", container, "TOPLEFT", isLeft and 0 or halfW, 0)
		group._buttons = {}

		local titleFS = group:CreateFontString(nil, "OVERLAY")
		titleFS:SetFont(fontPath, 16, "")
		titleFS:SetTextColor(1, 1, 1, 1)
		titleFS:SetPoint("TOP", group, "TOPLEFT", halfW / 2, 0)
		titleFS:SetText(titleText)
		group._title = titleFS

		local numIcons = #defs
		local totalRows = math.ceil(numIcons / perRow)

		-- Longer than the visible rows: a scroll frame (mouse wheel).
		local iconParent = group
		local topY = 0
		if maxVisibleRows and totalRows > maxVisibleRows then
			local visH = abs(FIRST_ICON_Y) + maxVisibleRows * ROW_STRIDE
			local contentH = abs(FIRST_ICON_Y) + totalRows * ROW_STRIDE
			topY = FIRST_ICON_Y + ICON_SIZE / 2 + 4
			local sf = CreateFrame("ScrollFrame", nil, group)
			sf:SetPoint("TOPLEFT", group, "TOPLEFT", 0, topY)
			sf:SetSize(halfW, visH)
			sf:EnableMouseWheel(true)
			local sc = CreateFrame("Frame", nil, sf)
			sc:SetSize(halfW, contentH)
			sf:SetScrollChild(sc)
			local maxScroll = max(0, contentH - visH)
			sf:SetScript("OnMouseWheel", function(self, delta)
				local v = (self:GetVerticalScroll() or 0) - delta * ROW_STRIDE
				self:SetVerticalScroll(max(0, min(maxScroll, v)))
				HideMenus()
			end)
			iconParent = sc
			topY = -topY
		end

		for gi, def in ipairs(defs) do
			local rowIdx = floor((gi - 1) / perRow)
			local colIdx = (gi - 1) % perRow
			local iconsInRow = min(perRow, numIcons - rowIdx * perRow)
			local rowW = iconsInRow * ICON_SIZE + (iconsInRow - 1) * gap
			local iconX = halfW / 2 - rowW / 2 + ICON_SIZE / 2 + colIdx * (ICON_SIZE + gap)
			local iconY = FIRST_ICON_Y - rowIdx * ROW_STRIDE + topY

			local btn = CreateFrame("Button", nil, iconParent)
			btn:SetSize(ICON_SIZE, ICON_SIZE)
			btn:SetPoint("TOP", iconParent, "TOPLEFT", iconX, iconY)
			btn:SetFrameLevel(iconParent:GetFrameLevel() + 3)

			local tex = btn:CreateTexture(nil, "ARTWORK")
			tex:SetAllPoints()
			tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			btn._tex = tex

			local bdr = CreateFrame("Frame", nil, btn)
			bdr:SetAllPoints()
			bdr:SetFrameLevel(btn:GetFrameLevel() + 1)
			PP.CreateBorder(bdr, 0, 0, 0, 1, 1)

			local hoverBdr = CreateFrame("Frame", nil, btn)
			hoverBdr:SetPoint("TOPLEFT", btn, "TOPLEFT", -1, 1)
			hoverBdr:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 1, -1)
			hoverBdr:SetFrameLevel(btn:GetFrameLevel() + 2)
			local ar, ag, ab = ns.GetAccentColor()
			PP.CreateBorder(hoverBdr, ar, ag, ab, 1, 2)
			hoverBdr:Hide()

			-- Label: one line, cut to the icon stride (full name on hover).
			local labelFS = iconParent:CreateFontString(nil, "OVERLAY")
			labelFS:SetFont(fontPath, 13, "")
			labelFS:SetTextColor(1, 1, 1, 0.9)
			labelFS:SetPoint("TOP", btn, "BOTTOM", 0, -4)
			labelFS:SetWidth(ICON_SIZE + gap - 8)
			labelFS:SetWordWrap(false)
			labelFS:SetJustifyH("CENTER")
			labelFS:SetText((L(def.label):gsub("\n", " ")))

			-- "Macro Created" flash (OnUpdate, no animation group).
			local flashFS = iconParent:CreateFontString(nil, "OVERLAY")
			flashFS:SetFont(fontPath, 9, "")
			flashFS:SetTextColor(1, 1, 1, 0)
			flashFS:SetPoint("TOP", btn, "BOTTOM", 0, -4)
			flashFS:Hide()
			local flashTex = btn:CreateTexture(nil, "OVERLAY")
			flashTex:SetAllPoints()
			flashTex:SetTexture(1, 1, 1, 0)
			local flashDriver = CreateFrame("Frame", nil, iconParent)
			flashDriver:Hide()
			local flashElapsed = 0
			flashDriver:SetScript("OnUpdate", function(self, dt)
				flashElapsed = flashElapsed + dt
				local e = flashElapsed
				if e < 0.08 then flashTex:SetTexture(1, 1, 1, 0.7 * (e / 0.08))
				elseif e < 0.38 then flashTex:SetTexture(1, 1, 1, 0.7 * (1 - (e - 0.08) / 0.3))
				else flashTex:SetTexture(1, 1, 1, 0) end
				if e < 0.15 then flashFS:SetTextColor(1, 1, 1, e / 0.15)
				elseif e < 0.95 then flashFS:SetTextColor(1, 1, 1, 1)
				elseif e < 1.55 then flashFS:SetTextColor(1, 1, 1, 1 - (e - 0.95) / 0.6)
				else
					flashFS:Hide()
					flashTex:SetTexture(1, 1, 1, 0)
					labelFS:Show()
					self:Hide()
				end
			end)
			local function PlayFlash()
				flashElapsed = 0
				flashFS:SetText(L("Macro Created"))
				flashFS:SetTextColor(1, 1, 1, 0)
				flashFS:Show()
				labelFS:Hide()
				flashDriver:Show()
			end

			local function GetDB() return MF.GetDB(def.name) end
			local function RefreshIcon() tex:SetTexture(MF.ButtonIcon(def)) end
			local function RefreshState()
				local exists = MF.Exists(def)
				tex:SetDesaturated(exists and true or false)
				btn._isGray = exists
			end
			btn._refreshIcon = RefreshIcon
			btn._refreshState = RefreshState
			RefreshIcon()

			-- Create, then open the macro window like retail.
			local function DoCreate()
				local ok, reason = MF.Create(def)
				if not ok then
					MF.Explain(reason)
					return
				end
				PlayFlash()
				After(0.15, function()
					if not InCombatLockdown() and ShowMacroFrame then ShowMacroFrame() end
				end)
			end

			-------------------------------------------------------------------
			-- Right-click menu (built on first use)
			-------------------------------------------------------------------
			local menuFrame = nil
			local function BuildMenu()
				if menuFrame then return end
				local MH, DH, HH, MW = 28, 14, 20, 240
				local cbItems = def.checkboxes
				local hasCheckboxes = cbItems and #cbItems > 0
				local xToggles = def.extraToggles
				local xChoices = def.extraChoices
				local xRows = (xToggles and #xToggles or 0) + (xChoices and #xChoices or 0)
				-- Popups outside the menu that still count as "inside".
				local menuChildren = {}

				local menuH = 4 + MH + MH + 4
				if xRows > 0 then menuH = menuH + DH + xRows * MH end
				if hasCheckboxes then menuH = menuH + DH + HH + #cbItems * MH end

				menuFrame = CreateFrame("Frame", nil, UIParent)
				menuFrame:SetFrameStrata("FULLSCREEN_DIALOG")
				menuFrame:SetFrameLevel(20)
				menuFrame:SetClampedToScreen(true)
				menuFrame:EnableMouse(true)
				menuFrame:SetSize(MW, menuH)
				menuFrame:Hide()
				openMenus[#openMenus + 1] = menuFrame
				local mBg = menuFrame:CreateTexture(nil, "BACKGROUND")
				mBg:SetAllPoints()
				mBg:SetTexture(MENU_BG[1], MENU_BG[2], MENU_BG[3], 0.95)
				ns.MakeBorder(menuFrame, 1, 1, 1, 0.2)
				local mY = -4

				-- Create / Delete
				local aR = MenuRow(menuFrame, mY, MH, fontPath)
				local function RefAct()
					aR._fs:SetText(MF.Exists(def) and L("|cffff4444Delete Macro|r") or L("Create Macro"))
				end
				RefAct()
				menuFrame._refreshAction = RefAct
				aR:SetScript("OnLeave", function() aR._fs:SetTextColor(0.75, 0.75, 0.75, 1); aR._hl:SetTexture(1, 1, 1, 0); RefAct() end)
				aR:SetScript("OnClick", function()
					if MF.Exists(def) then
						local ok, reason = MF.Delete(def)
						if not ok then MF.Explain(reason) end
					else
						DoCreate()
					end
					After(0.1, function() RefreshState(); RefAct() end)
				end)
				mY = mY - MH

				-- Show Tooltip
				local tR = MenuRow(menuFrame, mY, MH, fontPath, L("Show Tooltip"))
				local tCk = CheckBox(tR, PP, EG)
				local function RefTT() tCk(GetDB().showTooltip ~= false) end
				RefTT()
				tR:SetScript("OnClick", function()
					local db = GetDB()
					db.showTooltip = db.showTooltip == false
					RefTT()
					MF.Update(def)
				end)
				mY = mY - MH

				-- Extra rows: toggles (absent = off), then value pickers.
				if xRows > 0 then
					MenuDivider(menuFrame, mY, DH)
					mY = mY - DH
					for _, xt in ipairs(xToggles or {}) do
						local xR = MenuRow(menuFrame, mY, MH, fontPath, L(xt.label))
						local xCk = CheckBox(xR, PP, EG)
						local function RefX() xCk(GetDB()[xt.key] and true or false) end
						RefX()
						xR:SetScript("OnClick", function()
							local db = GetDB()
							-- nil rather than false, so an untouched default saves nothing.
							db[xt.key] = (not db[xt.key]) or nil
							RefX()
							MF.Update(def)
						end)
						mY = mY - MH
					end

					-- Marker picker: the current marker, and a list that drops out.
					for _, xc in ipairs(xChoices or {}) do
						local cR = MenuRow(menuFrame, mY, MH, fontPath, L(xc.label))
						local cAr = cR:CreateFontString(nil, "OVERLAY")
						cAr:SetFont(fontPath, 9, "")
						cAr:SetTextColor(0.55, 0.55, 0.55, 1)
						cAr:SetPoint("RIGHT", cR, "RIGHT", -10, 0)
						cAr:SetText("v")
						local cVal = cR:CreateFontString(nil, "OVERLAY")
						cVal:SetFont(fontPath, 12, "")
						cVal:SetTextColor(1, 1, 1, 0.9)
						cVal:SetPoint("RIGHT", cAr, "LEFT", -6, 0)
						local cIc = cR:CreateTexture(nil, "ARTWORK")
						cIc:SetSize(16, 16)
						cIc:SetTexture(MARKS)
						cIc:SetPoint("RIGHT", cVal, "LEFT", -5, 0)
						-- A bad saved value falls back to the default marker.
						local function RefChoice()
							local v = GetDB()[xc.key]
							if not MF.MARK_COORDS[v] then v = xc.default end
							local c = MF.MARK_COORDS[v]
							cIc:SetTexCoord(c[1], c[2], c[3], c[4])
							cVal:SetText(_G["RAID_TARGET_" .. v] or tostring(v))
						end
						RefChoice()

						local list = nil
						local function BuildList()
							if list then return end
							local LRH = 24
							list = CreateFrame("Frame", nil, menuFrame)
							list:SetFrameLevel(menuFrame:GetFrameLevel() + 10)
							list:SetClampedToScreen(true)
							list:EnableMouse(true)
							list:SetSize(MW - 24, 8 * LRH + 4)
							list:Hide()
							local lBg = list:CreateTexture(nil, "BACKGROUND")
							lBg:SetAllPoints()
							lBg:SetTexture(MENU_BG[1], MENU_BG[2], MENU_BG[3], 0.98)
							ns.MakeBorder(list, 1, 1, 1, 0.2)
							for oi = 1, 8 do
								local oY = -2 - (oi - 1) * LRH
								local oR = CreateFrame("Button", nil, list)
								oR:SetHeight(LRH)
								oR:SetFrameLevel(list:GetFrameLevel() + 2)
								oR:SetPoint("TOPLEFT", list, "TOPLEFT", 1, oY)
								oR:SetPoint("TOPRIGHT", list, "TOPRIGHT", -1, oY)
								local oHL = oR:CreateTexture(nil, "ARTWORK")
								oHL:SetAllPoints()
								oHL:SetTexture(1, 1, 1, 0)
								local oIc = oR:CreateTexture(nil, "OVERLAY")
								oIc:SetSize(16, 16)
								oIc:SetPoint("LEFT", oR, "LEFT", 10, 0)
								oIc:SetTexture(MARKS)
								local c = MF.MARK_COORDS[oi]
								oIc:SetTexCoord(c[1], c[2], c[3], c[4])
								local oFs = oR:CreateFontString(nil, "OVERLAY")
								oFs:SetFont(fontPath, 12, "")
								oFs:SetTextColor(0.8, 0.8, 0.8, 1)
								oFs:SetPoint("LEFT", oIc, "RIGHT", 8, 0)
								oFs:SetText(_G["RAID_TARGET_" .. oi] or tostring(oi))
								oR:SetScript("OnEnter", function() oFs:SetTextColor(1, 1, 1, 1); oHL:SetTexture(1, 1, 1, 0.06) end)
								oR:SetScript("OnLeave", function() oFs:SetTextColor(0.8, 0.8, 0.8, 1); oHL:SetTexture(1, 1, 1, 0) end)
								oR:SetScript("OnClick", function()
									GetDB()[xc.key] = oi
									RefChoice()
									list:Hide()
									MF.Update(def)
								end)
							end
							menuChildren[#menuChildren + 1] = list
						end
						cR:SetScript("OnClick", function()
							BuildList()
							if list:IsShown() then list:Hide(); return end
							list:ClearAllPoints()
							list:SetPoint("TOPRIGHT", cR, "BOTTOMRIGHT", -10, 2)
							list:Show()
						end)
						mY = mY - MH
					end
				end

				-- Item options (item macros only), drag to reorder.
				if hasCheckboxes then
					MenuDivider(menuFrame, mY, DH)
					mY = mY - DH
					local ht = menuFrame:CreateFontString(nil, "OVERLAY")
					ht:SetFont(fontPath, 10, "")
					ht:SetTextColor(1, 1, 1, 0.25)
					ht:SetPoint("TOP", menuFrame, "TOP", 0, mY - 4)
					ht:SetText(L("Drag to Reorder"))
					mY = mY - HH

					local cbBaseY = mY
					local rowFrames = {}
					local isDragging = false
					local insLine = menuFrame:CreateTexture(nil, "OVERLAY")
					insLine:SetHeight(2)
					insLine:Hide()

					-- Where a drop at cursor height cy (menu scale) would land.
					local function InsertIndex(self, cy)
						local mT = menuFrame:GetTop() or 0
						local iI = #cbItems
						for ri, rf in ipairs(rowFrames) do
							if rf ~= self and rf._baseY then
								local rm = mT + rf._baseY - MH / 2
								if cy > rm then iI = ri; break end
								iI = ri + 1
							end
						end
						return max(1, min(iI, #cbItems + 1))
					end

					local function EnsureOrder(db)
						if type(db.order) ~= "table" or #db.order < #cbItems then
							db.order = {}
							for oi = 1, #cbItems do db.order[oi] = oi end
						end
						return db.order
					end

					for ci = 1, #cbItems do
						local row = CreateFrame("Button", nil, menuFrame)
						row:SetHeight(MH)
						row._baseY = mY
						row._cbIndex = ci
						row:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", 1, mY)
						row:SetPoint("TOPRIGHT", menuFrame, "TOPRIGHT", -1, mY)
						row:SetFrameLevel(menuFrame:GetFrameLevel() + 2)
						local rl = row:CreateFontString(nil, "OVERLAY")
						rl:SetFont(fontPath, 13, "")
						rl:SetTextColor(0.75, 0.75, 0.75, 1)
						rl:SetPoint("LEFT", row, "LEFT", 12, 0)
						local rHL = row:CreateTexture(nil, "ARTWORK")
						rHL:SetAllPoints()
						rHL:SetTexture(1, 1, 1, 0)
						local rCk = CheckBox(row, PP, EG)
						row._lbl = rl

						-- Show option at list position `pos` of the saved order.
						row._setSlot = function(pos)
							local order = MF.Ordered(def, GetDB())
							local cb = cbItems[order[pos]] or cbItems[pos]
							row._cb = cb
							rl:SetText(MF.OptionName(cb))
							rCk(GetDB()[cb.key] ~= false)
						end
						row._setSlot(ci)

						row:SetScript("OnEnter", function()
							if isDragging then return end
							rl:SetTextColor(1, 1, 1, 1)
							rHL:SetTexture(1, 1, 1, 0.04)
						end)
						row:SetScript("OnLeave", function()
							if isDragging then return end
							rl:SetTextColor(0.75, 0.75, 0.75, 1)
							rHL:SetTexture(1, 1, 1, 0)
						end)
						row:SetScript("OnClick", function()
							if isDragging then return end
							local db = GetDB()
							local key = row._cb.key
							db[key] = db[key] == false
							rCk(db[key] ~= false)
							MF.Update(def)
							RefreshIcon()
						end)

						-- Drag (3 px threshold) via OnMouseDown / OnUpdate / OnMouseUp.
						local dsY, dgO = nil, nil
						row:SetScript("OnMouseDown", function(_, b)
							if b ~= "LeftButton" then return end
							local _, cy = GetCursorPosition()
							dsY = cy
						end)
						row:SetScript("OnMouseUp", function(self, b)
							if b ~= "LeftButton" then return end
							dsY = nil
							if not isDragging then return end
							isDragging = false
							insLine:Hide()
							self:SetFrameLevel(menuFrame:GetFrameLevel() + 2)
							self:SetAlpha(1)
							local _, cy = GetCursorPosition()
							cy = cy / menuFrame:GetEffectiveScale()
							local from = self._cbIndex
							local iI = InsertIndex(self, cy)
							if from < iI then iI = iI - 1 end
							local to = max(1, min(iI, #cbItems))
							local db = GetDB()
							local order = EnsureOrder(db)
							if from ~= to then
								local mv = table.remove(order, from)
								table.insert(order, to, mv)
							end
							for ri = 1, #rowFrames do
								local rf = rowFrames[ri]
								rf._cbIndex = ri
								local ry = cbBaseY - (ri - 1) * MH
								rf._baseY = ry
								rf:ClearAllPoints()
								rf:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", 1, ry)
								rf:SetPoint("TOPRIGHT", menuFrame, "TOPRIGHT", -1, ry)
								rf._setSlot(ri)
							end
							MF.Update(def)
							RefreshIcon()
						end)
						row:SetScript("OnUpdate", function(self)
							if not dsY then return end
							local _, cy = GetCursorPosition()
							local sc = menuFrame:GetEffectiveScale()
							if not isDragging then
								if abs(cy - dsY) < 3 then return end
								isDragging = true
								dgO = (cy / sc) - (self:GetTop() or 0)
								self:SetFrameLevel(menuFrame:GetFrameLevel() + 6)
								self:SetAlpha(0.8)
								for _, rf in ipairs(rowFrames) do
									rf._lbl:SetTextColor(0.75, 0.75, 0.75, 1)
								end
							end
							local cY = cy / sc
							local mT = menuFrame:GetTop() or 0
							local lY = cY - (dgO or 0) - mT
							lY = max(cbBaseY - (#cbItems - 1) * MH, min(lY, cbBaseY))
							self:ClearAllPoints()
							self:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", 1, lY)
							self:SetPoint("TOPRIGHT", menuFrame, "TOPRIGHT", -1, lY)
							local iI = InsertIndex(self, cY)
							local lnY = (iI <= 1) and (cbBaseY + 1) or (cbBaseY - (iI - 1) * MH + 1)
							insLine:SetTexture(EG.r, EG.g, EG.b, 0.9)
							insLine:ClearAllPoints()
							insLine:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", 8, lnY)
							insLine:SetPoint("TOPRIGHT", menuFrame, "TOPRIGHT", -8, lnY)
							insLine:Show()
						end)

						rowFrames[ci] = row
						mY = mY - MH
					end

					-- Item names arrive later when not cached: relabel while shown.
					menuFrame:SetScript("OnEvent", function()
						for ri, rf in ipairs(rowFrames) do rf._setSlot(ri) end
						RefreshIcon()
					end)
					menuFrame:SetScript("OnShow", function(self) self:RegisterEvent("GET_ITEM_INFO_RECEIVED") end)
					menuFrame:SetScript("OnHide", function(self) self:UnregisterEvent("GET_ITEM_INFO_RECEIVED") end)
				end

				-- Close on a click outside (the marker list counts as inside).
				menuFrame:SetScript("OnUpdate", function(self)
					if self:IsMouseOver() or btn:IsMouseOver() or not IsMouseButtonDown("LeftButton") then return end
					for _, child in ipairs(menuChildren) do
						if child:IsShown() and child:IsMouseOver() then return end
					end
					self:Hide()
				end)
			end

			local function ShowMenu()
				BuildMenu()
				if menuFrame:IsShown() then menuFrame:Hide(); return end
				HideMenus()
				local bs = btn:GetEffectiveScale()
				local us = UIParent:GetEffectiveScale()
				menuFrame:SetScale(bs / us)
				menuFrame:ClearAllPoints()
				menuFrame:SetPoint("TOP", btn, "BOTTOM", 0, -18)
				if menuFrame._refreshAction then menuFrame._refreshAction() end
				menuFrame:Show()
			end
			btn._showMenu = ShowMenu

			btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			btn:SetScript("OnEnter", function(self)
				hoverBdr:Show()
				local fullName = L(def.label):gsub("\n", " ")
				if self._isGray then
					ns.ShowWidgetTooltip(self, fullName .. "\n" .. L("|cff888888Created. Right-click to configure.|r"))
				else
					ns.ShowWidgetTooltip(self, fullName .. "\n" .. L("|cff888888Click to create. Right-click to configure.|r"))
				end
			end)
			btn:SetScript("OnLeave", function()
				hoverBdr:Hide()
				ns.HideWidgetTooltip()
			end)
			btn:SetScript("OnClick", function(self, button)
				if button == "RightButton" then ShowMenu(); return end
				if self._isGray then return end
				DoCreate()
				After(0.1, RefreshState)
			end)

			RefreshState()
			btn._def = def
			allButtons[#allButtons + 1] = btn
			group._buttons[#group._buttons + 1] = btn
		end
		return group
	end

	-- Left: general macros.
	BuildGroup(MF.GENERAL_DEFS, true, L("General Macro Factory"))

	-- Right: the spec's macros (rebuilt on a spec change).
	local specGroup, builtSpec = nil, nil
	local function BuildSpecSide()
		local specID, specName = MF.ActiveSpec()
		local className = UnitClass("player") or "Unknown"
		local defs = MF.SpecDefs(specID)
		local old = specGroup
		if #defs > 0 then
			specGroup = BuildGroup(defs, false, (specName or L("Spec")) .. " " .. className .. " " .. L("Macro Factory"),
				SPEC_ICONS_PER_ROW, SPEC_ICON_GAP, MAX_SPEC_VISIBLE_ROWS)
		else
			specGroup = CreateFrame("Frame", nil, container)
			specGroup:SetSize(halfW, SECTION_H)
			specGroup:SetPoint("TOPLEFT", container, "TOPLEFT", halfW, 0)
			specGroup._buttons = {}
			local emptyFS = specGroup:CreateFontString(nil, "OVERLAY")
			emptyFS:SetFont(fontPath, 16, "")
			emptyFS:SetTextColor(1, 1, 1, 0.25)
			emptyFS:SetPoint("CENTER", specGroup, "CENTER", 0, 0)
			emptyFS:SetJustifyH("CENTER")
			emptyFS:SetText(L("No spec macros for ") .. (specName or L("this spec")))
		end
		builtSpec = specID
		if old then
			HideMenus()
			old:Hide()
			-- Drop the old buttons from the refresh list.
			local keep = {}
			local gone = {}
			for _, b in ipairs(old._buttons) do gone[b] = true end
			for _, b in ipairs(allButtons) do
				if not gone[b] then keep[#keep + 1] = b end
			end
			allButtons = keep
		end
	end
	BuildSpecSide()

	-- PLAYER_SPECIALIZATION_CHANGED can fire more than once for one switch.
	tinsert(MF.specListeners, function()
		local specID = MF.ActiveSpec()
		if specID ~= builtSpec then BuildSpecSide() end
	end)

	-- Grey = macro exists. Follow macro changes made anywhere (macro window,
	-- other addons) and item / equipment changes for the icons.
	local function RefreshAll()
		for _, b in ipairs(allButtons) do
			b._refreshState()
			b._refreshIcon()
		end
	end
	container:RegisterEvent("UPDATE_MACROS")
	container:RegisterEvent("BAG_UPDATE")
	container:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	container:SetScript("OnEvent", function(self)
		if self:IsVisible() then RefreshAll() end
	end)
	container:SetScript("OnShow", RefreshAll)
end
