-- Settings pages of Interrupt Tracker (QoL Addons > Interrupt Tracker).
-- Part of EllesmereUIOptions (load on demand); skipped when EllesmereUIInterruptTracker is not loaded.

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUIInterruptTracker") then
	return
end

local U = ns.OptionsUtil
local MediaItems = U.MediaItems

local function DB()
	return ns.GetInterruptDB()
end

local function SortItems()
	local items = {}
	for i = 1, #ns.SORT_MODES do
		items[i] = { name = ns.SORT_MODES[i].text, value = ns.SORT_MODES[i].key }
	end
	return items
end

local function SortLabel()
	for i = 1, #ns.SORT_MODES do
		if ns.SORT_MODES[i].key == DB().sortMode then
			return ns.SORT_MODES[i].text
		end
	end
	return "?"
end

-- Drag-and-drop list of the tracked interrupts (order of the "Spell priority"
-- sort). Drag a row up or down: the other rows move out of the way, the
-- order is saved when the mouse button is released. Dim while another sort
-- mode is selected.
local PRIO_ROW_H = 28
local floor, max, min, abs = math.floor, math.max, math.min, math.abs

local function BuildPriorityList(p)
	-- The search index runs the builders on a recorder (no frames).
	if type(p.child) ~= "table" or not ns.GetInterruptSpellPriority then
		return
	end
	p:CloseRow()
	local fontPath = (ns.GetFontPath and ns.GetFontPath()) or STANDARD_TEXT_FONT
	local width = p:RowWidth()
	local pad = floor((p.child:GetWidth() - width) / 2)
	local count = #ns.GetInterruptSpellPriority()
	local height = count * PRIO_ROW_H

	local list = CreateFrame("Frame", nil, p.child)
	list:SetSize(width, height)
	list:SetPoint("TOPLEFT", p.child, "TOPLEFT", pad, p.y - 6)
	p.y = p.y - 6 - height - 6

	local function Wheel(frame)
		frame:EnableMouseWheel(true)
		frame:SetScript("OnMouseWheel", function(_, delta) p:ScrollBy(-delta * 60) end)
	end
	Wheel(list)

	local function Text(parent, size, alpha)
		local fs = parent:CreateFontString(nil, "OVERLAY")
		fs:SetFont(fontPath, size, "")
		fs:SetTextColor(1, 1, 1, alpha)
		fs:SetWordWrap(false)
		return fs
	end

	local rows = {}  -- rows[i] = row frame of the spell at place i
	local drag       -- { row, from, offset, moving, y0 }

	local function CursorY()
		local _, cy = GetCursorPosition()
		return (list:GetTop() or 0) - cy / list:GetEffectiveScale()
	end

	local function PlaceRow(row, slot)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(slot - 1) * PRIO_ROW_H)
	end

	local function Paint()
		for i = 1, #rows do
			local row = rows[i]
			row.rank:SetText(i)
			row.bg:SetTexture(0, 0, 0, (i % 2 == 0) and 0.2 or 0.1)
		end
	end

	-- Fills the rows from the saved order (rows are reused).
	local function Fill()
		local spells = ns.GetInterruptSpellPriority()
		for i = 1, #spells do
			local s = spells[i]
			local row = rows[i]
			local name, _, icon = GetSpellInfo(s.id)
			row.spellID = s.id
			row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
			row.name:SetText(name or ("Spell " .. s.id))
			local cc = RAID_CLASS_COLORS[s.class] or NORMAL_FONT_COLOR
			local className = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[s.class]) or s.class
			if s.pet then
				className = className .. " (" .. s.pet .. ")"
			end
			row.class:SetText(className)
			row.class:SetTextColor(cc.r, cc.g, cc.b, 0.9)
			row.cd:SetText(s.cooldown .. "s")
			PlaceRow(row, i)
		end
		Paint()
	end

	-- Slot (1-based) for a dragged row whose top is at y below the list top.
	local function SlotAt(y)
		return max(1, min(#rows, floor((y + PRIO_ROW_H / 2) / PRIO_ROW_H) + 1))
	end

	-- While dragging: the dragged row follows the cursor, the others make room.
	local function LayoutDrag()
		local target = SlotAt(CursorY() - drag.offset)
		local slot = 1
		for i = 1, #rows do
			local row = rows[i]
			if row ~= drag.row then
				if slot == target then
					slot = slot + 1
				end
				PlaceRow(row, slot)
				slot = slot + 1
			end
		end
		local y = max(0, min(height - PRIO_ROW_H, CursorY() - drag.offset))
		drag.row:ClearAllPoints()
		drag.row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -y)
	end

	local function EndDrag(commit)
		local d = drag
		drag = nil
		if not d then
			return
		end
		d.row:SetFrameLevel(list:GetFrameLevel() + 1)
		d.row:SetLifted(false)
		d.row:SetAlpha(1)
		if commit and d.moving then
			local to = SlotAt(d.lastY - d.offset)
			if to ~= d.from then
				ns.MoveInterruptSpellPriority(d.from, to)
				-- Reordering means the user wants this order: use it.
				if DB().sortMode ~= "priority" then
					DB().sortMode = "priority"
					if ns.RefreshSettings then
						ns.RefreshSettings()
					end
				end
				ns.ApplyInterruptSettings()
			end
		end
		-- Rows keep their frames; Fill writes the new order into them.
		Fill()
	end

	list:SetScript("OnUpdate", function()
		if not drag then
			return
		end
		if not IsMouseButtonDown("LeftButton") then
			EndDrag(true)
			return
		end
		local y = CursorY()
		drag.lastY = y
		if not drag.moving and abs(y - drag.y0) > 4 then
			drag.moving = true
			drag.row:SetFrameLevel(list:GetFrameLevel() + 6)
			drag.row:SetLifted(true)
			GameTooltip:Hide()
		end
		if drag.moving then
			LayoutDrag()
		end
	end)
	list:SetScript("OnHide", function() EndDrag(false) end)
	-- The order may have changed while the page was hidden (reset, profile).
	list:SetScript("OnShow", function()
		if not drag then
			Fill()
		end
	end)

	for i = 1, count do
		local row = CreateFrame("Button", nil, list)
		row:SetSize(width, PRIO_ROW_H)
		row:SetFrameLevel(list:GetFrameLevel() + 1)
		Wheel(row)

		row.bg = row:CreateTexture(nil, "BACKGROUND")
		row.bg:SetAllPoints()
		-- Lifted look while dragged: solid dark fill and an accent edge
		-- (textures on the row itself, so nothing covers its text).
		row.liftParts = {}
		local liftBg = row:CreateTexture(nil, "BACKGROUND", nil, 1)
		liftBg:SetAllPoints()
		liftBg:SetTexture(0.08, 0.08, 0.08, 0.95)
		row.liftParts[1] = liftBg
		local edges = {
			{ "TOPLEFT", "TOPRIGHT", nil, 1 },
			{ "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
			{ "TOPLEFT", "BOTTOMLEFT", 1, nil },
			{ "TOPRIGHT", "BOTTOMRIGHT", 1, nil },
		}
		for e = 1, #edges do
			local edge = row:CreateTexture(nil, "BORDER", nil, 1)
			edge:SetPoint(edges[e][1])
			edge:SetPoint(edges[e][2])
			if edges[e][3] then edge:SetWidth(1) end
			if edges[e][4] then edge:SetHeight(1) end
			row.liftParts[#row.liftParts + 1] = edge
		end
		row.SetLifted = function(self, on)
			local ar, ag, ab = ns.GetAccentColor()
			for k = 1, #self.liftParts do
				if k > 1 then
					self.liftParts[k]:SetTexture(ar, ag, ab, 0.8)
				end
				self.liftParts[k]:SetShown(on)
			end
		end
		row:SetLifted(false)
		row.hl = row:CreateTexture(nil, "BORDER")
		row.hl:SetAllPoints()
		row.hl:SetTexture(1, 1, 1, 0.04)
		row.hl:Hide()

		row.rank = Text(row, 12, 0.45)
		row.rank:SetPoint("LEFT", row, "LEFT", 14, 0)
		row.rank:SetWidth(22)
		row.rank:SetJustifyH("RIGHT")

		-- Grip: three short lines.
		row.gripLines = {}
		for g = 1, 3 do
			local line = row:CreateTexture(nil, "ARTWORK")
			line:SetSize(10, 1)
			line:SetPoint("LEFT", row, "LEFT", 46, (g - 2) * 3)
			line:SetTexture(1, 1, 1, 0.35)
			row.gripLines[g] = line
		end

		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(PRIO_ROW_H - 8, PRIO_ROW_H - 8)
		row.icon:SetPoint("LEFT", row, "LEFT", 66, 0)
		row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

		row.name = Text(row, 13, 1)
		row.name:SetPoint("LEFT", row.icon, "RIGHT", 10, 0)
		row.name:SetWidth(floor(width * 0.4))
		row.name:SetJustifyH("LEFT")

		row.cd = Text(row, 12, 0.45)
		row.cd:SetPoint("RIGHT", row, "RIGHT", -20, 0)
		row.cd:SetJustifyH("RIGHT")

		row.class = Text(row, 12, 0.9)
		row.class:SetPoint("RIGHT", row, "RIGHT", -70, 0)
		row.class:SetJustifyH("RIGHT")

		row:SetScript("OnEnter", function(self)
			if drag then
				return
			end
			self.hl:Show()
			for g = 1, 3 do
				self.gripLines[g]:SetTexture(1, 1, 1, 0.8)
			end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			if self.spellID then
				GameTooltip:SetSpellByID(self.spellID)
			end
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Drag up or down to change the priority.", 0.8, 0.8, 0.8)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function(self)
			self.hl:Hide()
			for g = 1, 3 do
				self.gripLines[g]:SetTexture(1, 1, 1, 0.35)
			end
			GameTooltip:Hide()
		end)
		row:SetScript("OnMouseDown", function(self, button)
			if button ~= "LeftButton" then
				return
			end
			local from
			for k = 1, #rows do
				if rows[k] == self then
					from = k
				end
			end
			local y = CursorY()
			drag = { row = self, from = from, offset = y - (from - 1) * PRIO_ROW_H, y0 = y, lastY = y, moving = false }
		end)
		rows[i] = row
	end
	Fill()

	p:OnRefresh(function()
		if not drag then
			Fill()
		end
		list:SetAlpha(DB().sortMode == "priority" and 1 or 0.35)
	end)
	list:SetAlpha(DB().sortMode == "priority" and 1 or 0.35)
end

local PAGE_DEFS = {
	{
		key = "general",
		name = "General",
		description = "Turn the tracker on or off and choose who is shown.",
		build = function(p)
			p:WideButton(
				function() return ns.IsTestMode() and "Test Mode: ON" or "Test Mode: OFF" end,
				"Show about 15 fake players. They use interrupts at random, die and disconnect, so you can try all settings without a group. Not saved after a reload.",
				function() return ns.IsTestMode() end,
				function() ns.SetTestMode(not ns.IsTestMode()) end)

			p:Section("Tracker")
			p:Toggle("Enable tracker", "Show the interrupt bars.",
				function() return DB().enabled end, function(v) ns.SetInterruptsEnabled(v) end)
			p:Toggle("Click through", "The bars ignore the mouse: clicks go to the game world behind them. Tooltips do not work while this is on. It has no effect in Unlock Mode, so you can still move the frame.",
				function() return DB().clickThrough end, function(v) DB().clickThrough = v end)
			p:Toggle("Show when solo", "Show your own interrupt when you are not in a group.",
				function() return DB().noRaid end, function(v) DB().noRaid = v; ns.ScheduleRosterUpdate(0) end)

			p:Section("Who is shown")
			p:MultiSelect("Roles", "Show interrupts of players with these roles. The role comes from the player's spec; if the spec is not known yet, from the group role.",
				function()
					local items = {}
					for i = 1, #ns.ROLES do
						items[i] = { name = ns.ROLES[i].text, value = ns.ROLES[i].key }
					end
					return items
				end,
				function(role) return DB().roles[role] end,
				function(role) ns.SetRoleShown(role, not DB().roles[role]) end,
				function()
					local names = {}
					for i = 1, #ns.ROLES do
						if DB().roles[ns.ROLES[i].key] then
							names[#names + 1] = ns.ROLES[i].text
						end
					end
					if #names == #ns.ROLES then
						return "All roles"
					elseif #names == 0 then
						return "None"
					end
					return table.concat(names, ", ")
				end)
			p:Toggle("Hide dead or offline players", "Players who are dead or offline are not shown. They come back when they are alive and online again.",
				function() return DB().hideUnavailable end, function(v) DB().hideUnavailable = v end)
			p:Toggle("Show only on cooldown", "Hide interrupts that are ready. Only used interrupts are shown.",
				function() return DB().onlyOnCooldown end, function(v) DB().onlyOnCooldown = v end)
		end,
	},
	{
		key = "sorting",
		name = "Sorting",
		description = "Choose the order of the bars.",
		build = function(p)
			p:Section("Order")
			p:Dropdown("Sort by", "Cooldown: ready interrupts on top, shortest total cooldown first (Kick before Silence).\n\nSpell priority: ready interrupts on top, in your order from the list below.\n\nIn both modes interrupts on cooldown come next, least time left first (2 s left above 4 s left). Dead or offline players at the bottom.", SortItems,
				function() return DB().sortMode end, SortLabel, function(v) DB().sortMode = v end)
			p:Toggle("Reverse order", "Ready interrupts stay on top, but inside each group the order is reversed: longest cooldown first (or last spell of your priority list first), most time left first.",
				function() return DB().sortDescending end, function(v) DB().sortDescending = v end)

			p:Section("Spell priority")
			p:Paragraph("Drag a spell up or down. Spells higher in the list are shown first when they are ready. Used when 'Sort by' is 'Spell priority' (dragging a spell turns it on).")
			BuildPriorityList(p)
			p:Button("Default order", "Put the spells back in the default order: shortest cooldown first, pet spells last.", "Reset order", function()
				ns.ResetInterruptSpellPriority()
			end)
		end,
	},
	{
		key = "appearance",
		name = "Appearance",
		description = "Size of the frame, look and colors of the bars, and the text.",
		build = function(p)
			p:Section("Layout")
			p:Dropdown("Grow Direction", "Up: the bottom of the list stays in place and the list grows upward when more bars are shown. Down: the top stays in place and the list grows downward. The order of the bars is the same in both.",
				function()
					local items = {}
					for i = 1, #ns.GROW_DIRECTIONS do
						items[i] = { name = ns.GROW_DIRECTIONS[i].text, value = ns.GROW_DIRECTIONS[i].key }
					end
					return items
				end,
				function() return DB().growDirection end,
				function()
					for i = 1, #ns.GROW_DIRECTIONS do
						if ns.GROW_DIRECTIONS[i].key == DB().growDirection then
							return ns.GROW_DIRECTIONS[i].text
						end
					end
					return "?"
				end,
				function(v) DB().growDirection = v end)
			p:Slider("Width", "Width of the bars.", 120, 320, 1, function() return DB().width end, function(v) DB().width = v end)
			p:Slider("Bar height", "Height of one bar.", 14, 28, 1, function() return DB().lineHeight end, function(v) DB().lineHeight = v end)
			p:Slider("Visible bars", "How many bars can be shown at the same time.", 5, ns.MAX_LINES_CAP, 1,
				function() return DB().maxLines end, function(v) DB().maxLines = v end)
			p:Slider("Scale %", "Size of the whole frame.", 60, 180, 1, function() return DB().scale end, function(v) DB().scale = v end)
			p:Slider("Opacity %", "Opacity of the whole frame.", 20, 100, 1, function() return DB().alpha end, function(v) DB().alpha = v end)

			p:Section("Bars")
			p:Dropdown("Bar texture", "Texture of the bars. Textures from LibSharedMedia are listed too.",
				function() return MediaItems(ns.GetBarTextures()) end,
				function() return ns.GetInterruptBarTexture() end,
				function() return ns.GetBarTextureLabel(ns.GetInterruptBarTexture()) end,
				function(v) DB().barTexture = v end,
				{ texturePreview = true })
			p:Toggle("Gray icon when not ready", "The spell icon is gray while on cooldown, dead or offline.",
				function() return DB().desaturateOnCooldown end, function(v) DB().desaturateOnCooldown = v end)
			p:Color("Ready color", "Bar color when the interrupt can be used now.", "ready")
			p:Color("Active color", "Bar color while the effect is still running, for example Solar Beam.", "active")
			p:Color("On cooldown color", "Bar color when the interrupt was used and is not ready.", "cooldown")
			p:Color("Dead or offline color", "Bar color when the player cannot use the interrupt.", "unavailable")

			p:Section("Text")
			p:Dropdown("Font", "Font of all bar text. Fonts from LibSharedMedia are listed too.",
				function() return MediaItems(ns.GetFonts()) end,
				function() return ns.GetInterruptFont() end,
				function() return ns.GetFontLabel(ns.GetInterruptFont()) end,
				function(v) DB().fontName = v end,
				{ fontPreview = true })
			p:Slider("Font size", "Size of all bar text.", 8, 16, 1, function() return DB().fontSize end, function(v) DB().fontSize = v end)
			p:Toggle("Class colored names", "Player names use their class color. Turn off to use your own name color.",
				function() return DB().useClassColorName end, function(v) DB().useClassColorName = v end)
			p:Color("Name color", "Color of the player names. Used when 'Class colored names' is off.", "name",
				function() return DB().useClassColorName end)
			p:Toggle("Show spell name", "Show the interrupt name in the middle of the bar. Turn off for a smaller look (the icon and tooltip still show the spell).",
				function() return DB().showSpellName end, function(v) DB().showSpellName = v end)
			p:Color("Spell name color", "Color of the spell name in the middle of the bar.", "spell",
				function() return not DB().showSpellName end)
			p:Color("Timer color", "Color of the time left and the dead / offline text on the right.", "time")

			p:Section("Reset")
			p:Button("Default colors", "Set all bar and text colors on this page back to the default.", "Reset colors", function()
				local defaults = ns.CreateInterruptDefaults().colors
				for key, value in pairs(defaults) do
					local c = DB().colors[key]
					c[1], c[2], c[3] = value[1], value[2], value[3]
				end
			end)
		end,
	},
}

ns.RegisterSettingsModule({
	-- Not an EllesmereUI module; it sits with the other helpers.
	key = "interrupts",
	name = "Interrupt Tracker",
	group = "QoL Addons",
	tabs = PAGE_DEFS,
	reset = function() ns.ResetInterruptSettings() end,
	resetTip = "Set all Interrupt Tracker settings back to default. Frame position and cooldowns are kept.",
})
