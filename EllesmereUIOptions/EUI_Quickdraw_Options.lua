-- Settings page of Quickdraw (retail EUI_Quickdraw_Options.lua). Part of
-- EllesmereUIOptions (load on demand); skipped when EllesmereUIQuickdraw is
-- not loaded. Setters only store: the runtime's ns.applyHooks entry applies
-- every change. Same sections, labels and tooltips as retail; the retail
-- drag-and-drop preview is an entry list with "Add" menus here.

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUIQuickdraw") then
	return
end

local QD = ns.Quickdraw
if not QD then return end

local editPalette = 1

local function Cfg(key) return QD.P()[key] end
local function Set(key, v) QD.P()[key] = v end
local function ACfg(key) return QD.ACfg(editPalette, key) end
local function ASet(key, v) QD.ASet(editPalette, key, v) end
local function Off() return Cfg("enabled") ~= true end

-- Structural changes (menu, layout, entries) build a new page: pageKey = rev.
local rev = 0
local function PageKey()
	local pal = QD.EnsurePalette(math.min(editPalette, QD.PaletteCount()))
	local key = QD.P().confirmKey
	return table.concat({ rev, editPalette, QD.PaletteCount(), tostring(QD.ACfg(editPalette, "layout")),
		pal and #pal.slots or 0, (type(key) == "string" and key ~= "") and 1 or 0 }, ":")
end
local function Rebuild()
	rev = rev + 1
	if ns.RebuildSettingsPage then ns.RebuildSettingsPage() end
end

local function MenuName(i)
	local pal = QD.P().palettes[i]
	return (type(pal) == "table" and type(pal.name) == "string" and pal.name ~= "" and pal.name) or QD.AutoPaletteName(i)
end

local function IconText(icon, text)
	return "|T" .. tostring(icon or QD.QUESTION_MARK) .. ":16:16:0:0:64:64:5:59:5:59|t " .. tostring(text or "")
end

local function Palette() return QD.EnsurePalette(editPalette) end
local function Full() local pal = Palette(); return not pal or #pal.slots >= QD.MAX_SLOTS end

local function AddSlot(slot)
	local pal = Palette()
	if not pal or not slot then return end
	if not QD.AddSlot(pal, QD.CopyTable(slot)) then
		ns.Print("Quickdraw: an action menu holds at most " .. QD.MAX_SLOTS .. " entries.")
	end
end

-------------------------------------------------------------------------------
--  Menus: add (empty or preset), delete, keys
-------------------------------------------------------------------------------
local function HearthEntries()
	local out = {}
	for _, id in ipairs({ 6948, 64488, 54452, 28585, 93672 }) do
		if GetItemCount(id) > 0 then out[#out + 1] = { slot = { kind = "item", id = id } } end
	end
	return out
end

local PRESETS = {
	{ key = "empty", label = "Empty" },
	{ key = "marker_target", label = "Target Markers", build = function() return QD.TargetMarkerEntries() end },
	{ key = "marker_world", label = "World Markers", build = function() return QD.WorldMarkerEntries() end },
	{ key = "hearth", label = "Hearthstones", build = HearthEntries },
	{ key = "spec", label = "Specializations", build = function() return QD.SpecEntries() end },
	{ key = "mount", label = "Mounts", build = function() return QD.MountEntries() end },
	{ key = "emote", label = "Emotes", build = function() return QD.EmoteEntries() end },
}

local function AddPalette(presetKey)
	local count = QD.PaletteCount()
	if count >= QD.MAX_PALETTES then return end
	local index = count + 1
	QD.P().palettes[index] = nil
	Set("paletteCount", index)
	local pal = QD.EnsurePalette(index)
	for _, preset in ipairs(PRESETS) do
		if preset.key == presetKey and preset.build then
			pal.name = preset.label
			for _, e in ipairs(preset.build()) do
				if #pal.slots < QD.MAX_SLOTS then pal.slots[#pal.slots + 1] = QD.CopyTable(e.slot) end
			end
		end
	end
	editPalette = index
end

-- Removes a menu; later menus (and their keys) move down one place.
local function DeletePalette(index)
	if InCombatLockdown() then return end
	local p = QD.P()
	local count = QD.PaletteCount()
	if count <= 1 then return end
	local keys = {}
	for i = 1, count do keys[i] = { QD.GetKey(i) } end
	for i = index, count - 1 do p.palettes[i] = p.palettes[i + 1] end
	p.palettes[count] = nil
	for i = 1, count - 1 do
		local pal = p.palettes[i]
		if type(pal) == "table" and type(pal.slots) == "table" then
			for s = #pal.slots, 1, -1 do
				local slot = pal.slots[s]
				local child = QD.ChildIndex(slot)
				if child == index then
					table.remove(pal.slots, s)
				elseif child and child > index then
					slot.palette = child - 1
				end
			end
		end
	end
	p.paletteCount = count - 1
	-- keys follow their menus
	for i = 1, count do
		local action = QD.BINDING_PREFIX .. i
		local k1, k2 = GetBindingKey(action)
		if k1 then SetBinding(k1) end
		if k2 then SetBinding(k2) end
	end
	for i = 1, count do
		local target = (i < index) and i or (i > index and i - 1 or nil)
		if target then
			for _, key in ipairs(keys[i]) do SetBinding(key, QD.BINDING_PREFIX .. target) end
		end
	end
	SaveBindings(GetCurrentBindingSet())
	if editPalette >= index and editPalette > 1 then editPalette = editPalette - 1 end
end

local function SetMenuKey(chord)
	if InCombatLockdown() then
		ns.Print("Quickdraw: key bindings cannot change in combat.")
		return
	end
	if chord then
		local action = GetBindingAction(chord)
		local mine = QD.BINDING_PREFIX .. editPalette
		if action and action ~= "" and action ~= mine then
			ns.ShowConfirmPopup({
				title = "Key Already Bound",
				message = chord .. " is bound to " .. (_G["BINDING_NAME_" .. action] or action) .. ". Bind it to " .. MenuName(editPalette) .. " instead?",
				confirmText = "Bind",
				cancelText = "Cancel",
				onConfirm = function()
					QD.SetKey(editPalette, chord)
					Rebuild()
				end,
			})
			return
		end
	end
	QD.SetKey(editPalette, chord)
end

-- Every appearance setting of `src` copied onto `dst` (retail CopyAllMenuSettings).
local function CopyAllMenuSettings(src, dst)
	local from = QD.EnsurePalette(src)
	local to = QD.EnsurePalette(dst)
	if not from or not to then return end
	to.appearance = {}
	for key in pairs(QD.APPEARANCE_KEYS) do
		to.appearance[key] = QD.CopyTable(QD.ACfg(src, key))
	end
end

-------------------------------------------------------------------------------
--  "Add" menus (retail Add Entry categories)
-------------------------------------------------------------------------------
local CATEGORIES = {
	{ label = "Nest Another Action Menu", build = function() return QD.PaletteEntries(editPalette) end,
	  tip = "Adds another action menu as one entry. Arc: its entries open on an outer arc when you point at it. Grid / Fan: its entries are shown in place of it." },
	{ label = "Spells", build = function() return QD.SpellEntries() end },
	{ label = "Mounts", build = function() return QD.MountEntries() end },
	{ label = "Items", build = function() return QD.ItemEntries() end, tip = "Usable items in your bags and equipped items with a Use effect." },
	{ label = "Macros", build = function() return QD.MacroEntries() end },
	{ label = "Battle Pets", build = function() return QD.PetEntries() end },
	{ label = "Equipment Sets", build = function() return QD.EquipSetEntries() end },
	{ label = "Target Markers", build = function() return QD.TargetMarkerEntries() end },
	{ label = "World Markers", build = function() return QD.WorldMarkerEntries() end },
	{ label = "Specializations", build = function() return QD.SpecEntries() end, tip = "Switches to the talent spec holding this specialization." },
	{ label = "Emotes", build = function() return QD.EmoteEntries() end },
	{ label = "Other", build = function() return QD.OtherEntries() end, tip = "Resurrect: your battle resurrection in combat, your normal resurrection out of combat." },
}

local function CategoryDropdown(p, cat)
	local cache = {}
	p:Dropdown(cat.label, cat.tip,
		function()
			cache = cat.build() or {}
			local items = {}
			for i, e in ipairs(cache) do
				items[#items + 1] = { name = IconText(e.icon, e.name), value = i }
			end
			if #items == 0 then items[1] = { name = "Nothing to add", value = 0 } end
			return items
		end,
		function() return nil end,
		function() return "Add..." end,
		function(v)
			local e = cache[v]
			if e then AddSlot(e.slot) end
			Rebuild()
		end,
		nil,
		function() return Off() or Full() end)
end

-------------------------------------------------------------------------------
--  Page
-------------------------------------------------------------------------------
local function Build(p)
	local count = QD.PaletteCount()
	if editPalette > count then editPalette = count end

	-- GENERAL
	p:Section("GENERAL")
	p:Toggle("Enable Quickdraw", "Hold a keybind to open a menu of actions; point or scroll to choose, release to fire.",
		function() return Cfg("enabled") == true end,
		function(v) Set("enabled", v and true or false) end)
	p:Dropdown("Add Action Menu", "Adds a new action menu, empty or filled from a preset.",
		function()
			local items = {}
			for _, preset in ipairs(PRESETS) do items[#items + 1] = { name = preset.label, value = preset.key } end
			return items
		end,
		function() return nil end,
		function() return "Empty or Preset..." end,
		function(v) AddPalette(v); Rebuild() end,
		nil,
		function() return Off() or QD.PaletteCount() >= QD.MAX_PALETTES end)

	-- ACTION MENU SETUP
	p:Section("ACTION MENU SETUP")
	p:Dropdown("Editing Action Menu", "The action menu the settings below change.",
		function()
			local items = {}
			for i = 1, QD.PaletteCount() do items[#items + 1] = { name = MenuName(i), value = i } end
			return items
		end,
		function() return editPalette end,
		function() return MenuName(editPalette) end,
		function(v) editPalette = v; Rebuild() end)
	p:Keybind("Action Menu Keybind", "Hold this key to open the menu, release it to use the entry you point at. Right-click to unbind.",
		function() return QD.GetKey(editPalette) end,
		SetMenuKey, Off)

	local function HasSelectKey()
		local key = Cfg("confirmKey")
		return type(key) == "string" and key ~= ""
	end
	p:Keybind("Toggled Menu Select Action",
		"Uses the entry you are pointing at while a menu is kept open with Toggle Menu Open. One key shared by every menu, claimed only while a menu is up -- a mouse button keeps its normal use the rest of the time.",
		function() local k = Cfg("confirmKey"); return (type(k) == "string" and k ~= "") and k or nil end,
		function(chord) Set("confirmKey", chord or ""); Rebuild() end, Off)
	p:Toggle("Toggle Menu Open",
		"Keep this menu open when you let go of its keybind.\nPoint at an entry and press the Select Action key to use it.\nPress the menu's own keybind again, or Escape, to close it.",
		function() return ACfg("toggleMode") == true end,
		function(v) ASet("toggleMode", v) end,
		function() return Off() or not HasSelectKey() end)
	if HasSelectKey() then
		p:Keybind("Menu Cancel Action",
			"Closes an open menu without using anything. Escape always does this as well. One key shared by every menu, claimed only while a menu is up -- a mouse button keeps its normal use the rest of the time.",
			function() local k = Cfg("cancelKey"); return (type(k) == "string" and k ~= "") and k or nil end,
			function(chord)
				if chord then
					if chord == Cfg("confirmKey") then
						ns.Print("Quickdraw: that key is already the Toggled Menu Select Action.")
						return
					end
					for i = 1, QD.PaletteCount() do
						local k1, k2 = QD.GetKey(i)
						if k1 == chord or k2 == chord then
							ns.Print("Quickdraw: that key opens a menu, so it cannot also close one.")
							return
						end
					end
				end
				Set("cancelKey", chord or "")
			end, Off)
		p:Blank()
	end

	local specs = QD.ClassSpecs()
	p:MultiSelect("Assign to Spec", "Loads this action menu only in the chosen specializations. None chosen = every specialization.",
		function()
			local items = {}
			for _, s in ipairs(specs) do items[#items + 1] = { name = IconText(s.icon, s.name), value = s.id } end
			return items
		end,
		function(id) local sp = QD.PaletteSpecs(editPalette); return sp and sp[id] and true or false end,
		function(id)
			local pal = Palette()
			pal.specs = pal.specs or {}
			pal.specs[id] = (not pal.specs[id]) and true or nil
			if next(pal.specs) == nil then pal.specs = nil end
		end,
		function()
			local sp = QD.PaletteSpecs(editPalette)
			if not sp then return "All Specs" end
			local names = {}
			for _, s in ipairs(specs) do if sp[s.id] then names[#names + 1] = s.name end end
			return #names > 0 and table.concat(names, ", ") or "Other Class"
		end, Off)
	if count > 1 then
		p:Dropdown("Apply All Settings From", "Copy every setting from another action menu to this one.",
			function()
				local items = {}
				for i = 1, count do
					if i ~= editPalette then items[#items + 1] = { name = MenuName(i), value = i } end
				end
				return items
			end,
			function() return nil end,
			function() return "Choose Menu..." end,
			function(src)
				local dst = editPalette
				ns.ShowConfirmPopup({
					title = "Apply All Settings",
					message = "Copy all settings from " .. MenuName(src) .. " to " .. MenuName(dst) .. "?",
					disclaimer = "This overwrites this action menu's current settings. Its actions, name, and keybind are not changed.",
					confirmText = "Apply",
					cancelText = "Cancel",
					onConfirm = function()
						CopyAllMenuSettings(src, dst)
						for _, fn in ipairs(ns.applyHooks or {}) do pcall(fn) end
						Rebuild()
					end,
				})
			end, nil, Off)
	else
		p:Blank()
	end
	p:Button("Rename Action Menu", "Gives this action menu a new name.", "Rename",
		function()
			ns.ShowInputPopup({
				title = "Rename Action Menu",
				message = "New name for " .. MenuName(editPalette) .. ":",
				text = MenuName(editPalette),
				confirmText = "Rename",
				cancelText = "Cancel",
				onConfirm = function(text)
					text = text and text:gsub("^%s+", ""):gsub("%s+$", "") or ""
					Palette().name = (text ~= "") and text or QD.AutoPaletteName(editPalette)
					Rebuild()
				end,
			})
		end)
	p:Button("Delete Action Menu", "Deletes this action menu and its entries. Menus after it move down one place, with their keybinds.", "Delete",
		function()
			if count <= 1 then
				ns.Print("Quickdraw: the last action menu cannot be deleted.")
				return
			end
			local index = editPalette
			ns.ShowConfirmPopup({
				title = "Delete Action Menu",
				message = "Delete " .. MenuName(index) .. "?",
				confirmText = "Delete",
				cancelText = "Cancel",
				onConfirm = function()
					DeletePalette(index)
					for _, fn in ipairs(ns.applyHooks or {}) do pcall(fn) end
					Rebuild()
				end,
			})
		end)

	-- ACTIONS (retail preview: the entries of the menu, in order)
	p:Section("ACTIONS")
	local pal = Palette()
	if #pal.slots == 0 then
		p:Paragraph("This action menu is empty. Add entries with the menus below, or pick up a spell, item, macro, mount, battle pet or equipment set and press Add From Cursor.")
	end
	for i, slot in ipairs(pal.slots) do
		local usable = slot.kind == "palette" or QD.SlotUsable(slot)
		local name = QD.SlotName(slot)
		if not usable then name = "|cff808080" .. name .. " (not available)|r" end
		p:Label(IconText(QD.SlotIcon(slot), i .. ". " .. name), nil, Off)
		p:InlineIcon("Remove", ns.MEDIA .. "ui\\eui-close", function()
			QD.RemoveSlot(Palette(), i)
			Rebuild()
		end)
		if i < #pal.slots then
			p:InlineIcon("Move Down", "Interface\\Buttons\\Arrow-Down-Up", function()
				QD.MoveSlot(Palette(), i, i + 1)
				Rebuild()
			end)
		end
		if i > 1 then
			p:InlineIcon("Move Up", "Interface\\Buttons\\Arrow-Up-Up", function()
				QD.MoveSlot(Palette(), i, i - 1)
				Rebuild()
			end)
		end
	end
	if #pal.slots % 2 == 1 then p:Blank() end

	for _, cat in ipairs(CATEGORIES) do CategoryDropdown(p, cat) end
	p:Button("Custom Macro...", "Adds an entry that runs your own macro text.", "Add Macro Text",
		function()
			if Full() then return end
			ns.ShowInputPopup({
				title = "Custom Macro",
				message = "Macro text (one command; use ; between /cast options):",
				text = "",
				confirmText = "Add",
				cancelText = "Cancel",
				onConfirm = function(text)
					if type(text) ~= "string" or text == "" then return end
					AddSlot({ kind = "macrotext", macrotext = text, name = text:match("^/%a+%s+(.+)$") or text })
					for _, fn in ipairs(ns.applyHooks or {}) do pcall(fn) end
					Rebuild()
				end,
			})
		end)
	p:Button("Add From Cursor", "Pick up a spell, item, macro, mount, battle pet or equipment set, then press this to add it.", "Add From Cursor",
		function()
			local slot = QD.SlotFromCursor()
			if slot then
				AddSlot(slot)
				ClearCursor()
				Rebuild()
			else
				ns.Print("Quickdraw: nothing usable on the cursor.")
			end
		end)

	-- LAYOUT
	p:Section("LAYOUT")
	local layoutMode = ACfg("layout") or "ARC"
	p:Dropdown("Layout", nil,
		function() return { { name = "Arc", value = "ARC" }, { name = "Fan", value = "FAN" }, { name = "Grid", value = "GRID" } } end,
		function() return layoutMode end,
		function() return ({ ARC = "Arc", FAN = "Fan", GRID = "Grid" })[ACfg("layout") or "ARC"] or "Arc" end,
		function(v) ASet("layout", v); Rebuild() end, nil, Off)
	if layoutMode == "GRID" then
		p:Cog("Grid Settings", {
			{ type = "slider", label = "Spacing", min = 0, max = 40, step = 1,
			  get = function() return ACfg("fanGap") or 10 end, set = function(v) ASet("fanGap", v) end },
		})
	end
	local function fixedOff() return Off() or (ACfg("centerMode") or "CURSOR") ~= "SCREEN" end
	p:Dropdown("Open At", nil,
		function() return { { name = "Cursor", value = "CURSOR" }, { name = "Fixed Position", value = "SCREEN" } } end,
		function() return ACfg("centerMode") or "CURSOR" end,
		function() return (ACfg("centerMode") == "SCREEN") and "Fixed Position" or "Cursor" end,
		function(v) ASet("centerMode", v) end, nil, Off)
	p:Cog("Fixed Position", {
		{ type = "slider", label = "X Offset", min = -800, max = 800, step = 1,
		  get = function() return ACfg("posX") or 0 end, set = function(v) ASet("posX", v) end },
		{ type = "slider", label = "Y Offset", min = -600, max = 600, step = 1,
		  get = function() return ACfg("posY") or 0 end, set = function(v) ASet("posY", v) end },
	}, { disabled = fixedOff, disabledTip = "Requires Fixed Position mode" })

	if layoutMode == "GRID" then
		p:Toggle("Auto Columns", nil,
			function() return ACfg("gridAutoColumns") ~= false end,
			function(v) ASet("gridAutoColumns", v) end, Off)
		p:Slider("Grid Columns", "How many entries a row of the grid holds. 1 stacks them into a single column; " .. QD.MAX_SLOTS .. " -- the most slots an action menu can hold -- lays them out in a single row.",
			1, QD.MAX_SLOTS, 1,
			function() return ACfg("gridColumns") or 4 end,
			function(v) ASet("gridColumns", v) end,
			function() return Off() or ACfg("gridAutoColumns") ~= false end)
	elseif layoutMode == "ARC" then
		p:Slider("Distance from Center", nil, 50, 220, 1,
			function() return ACfg("radius") or 100 end,
			function(v) ASet("radius", v) end, Off)
		p:Slider("Arc Span", nil, 30, 360, 5,
			function() return ACfg("arcSpan") or 360 end,
			function(v) ASet("arcSpan", v) end, Off)
		p:Cog("Arc Rotation", {
			{ type = "slider", label = "Arc Rotation", min = -180, max = 180, step = 5,
			  get = function() return ACfg("arcRotation") or 0 end, set = function(v) ASet("arcRotation", v) end },
		}, { disabled = function() return Off() or (ACfg("arcSpan") or 360) >= 360 end, disabledTip = "Requires an Arc Span below 360" })
	else
		p:Dropdown("Fan Direction", nil,
			function() return { { name = "Horizontal", value = "HORIZONTAL" }, { name = "Vertical", value = "VERTICAL" } } end,
			function() return ACfg("fanOrientation") or "HORIZONTAL" end,
			function() return (ACfg("fanOrientation") == "VERTICAL") and "Vertical" or "Horizontal" end,
			function(v) ASet("fanOrientation", v) end, nil, Off)
		p:Cog("Fan Settings", {
			{ type = "toggle", label = "Select Action with Mouse",
			  get = function() return ACfg("fanMouseSelect") ~= false end, set = function(v) ASet("fanMouseSelect", v) end },
			{ type = "slider", label = "Spacing", min = 0, max = 40, step = 1,
			  get = function() return ACfg("fanGap") or 10 end, set = function(v) ASet("fanGap", v) end },
			{ type = "toggle", label = "Invert Scroll",
			  get = function() return ACfg("fanInvert") == true end, set = function(v) ASet("fanInvert", v) end },
		})
		p:Slider("Visible Icons", "Scroll the mouse wheel to move along the fan; the middle entry is used.", 1, 9, 2,
			function() return ((ACfg("fanVisible") or 2) * 2) + 1 end,
			function(v) ASet("fanVisible", (v - 1) * 0.5) end, Off)
	end

	local hasNest = false
	for i = 1, count do
		local pl = QD.P().palettes[i]
		if type(pl) == "table" and type(pl.slots) == "table" then
			for _, s in ipairs(pl.slots) do if s.kind == "palette" then hasNest = true end end
		end
	end
	if hasNest and layoutMode == "ARC" then
		p:Slider("Nest Distance", "The gap between a nested menu's icons and the entry that opens it.", 0, 160, 1,
			function() return ACfg("nestBand") or 40 end,
			function(v) ASet("nestBand", v) end, Off)
		p:Cog("Arc Nest Shape", {
			{ type = "dropdown", label = "Nest Width",
			  tip = "How far along the arc a nest may spread its entries. Contained keeps it clear of the next nest either side, so two of them are never drawn on top of one another. Overflowing lets it use the whole of Max Nest Span.",
			  items = function() return { { name = "Contained", value = "NONE" }, { name = "Overflowing", value = "MIDPOINT" } } end,
			  get = function() return ACfg("arcChildOverflow") or "NONE" end,
			  set = function(v) ASet("arcChildOverflow", v) end,
			  labelFn = function() return (ACfg("arcChildOverflow") == "MIDPOINT") and "Overflowing" or "Contained" end },
			{ type = "slider", label = "Max Nest Span", min = 30, max = 180, step = 5,
			  tip = "The widest angle a nest's entries may spread over.",
			  get = function() return ACfg("arcChildMaxSpan") or 90 end, set = function(v) ASet("arcChildMaxSpan", v) end },
		})
		p:Slider("Nest Icon Size", nil, 0.4, 1.0, 0.05,
			function() return ACfg("nestScale") or 0.8 end,
			function(v) ASet("nestScale", v) end, Off)
	end
	p:Slider("Icon Size", nil, 24, 72, 1,
		function() return ACfg("iconSize") or 40 end,
		function(v) ASet("iconSize", v) end, Off)
	p:Slider("Scale", nil, 0.5, 2.0, 0.01,
		function() return ACfg("scale") or 1.0 end,
		function(v) ASet("scale", v) end, Off)

	-- APPEARANCE
	p:Section("APPEARANCE")
	p:Toggle("Show Cooldowns", nil,
		function() return ACfg("showCooldowns") ~= false end,
		function(v) ASet("showCooldowns", v) end, Off)
	p:Toggle("Dim Unusable Actions", "Dims any actions you can't use right now.",
		function() return ACfg("showUsability") ~= false end,
		function(v) ASet("showUsability", v) end, Off)
	p:Label("Selection Color", nil, Off)
	p:Swatch("Custom Color",
		function()
			local c = ACfg("selectColor") or {}
			return c[1] or 0.047, c[2] or 0.824, c[3] or 0.624, 1
		end,
		function(r, g, b)
			ASet("selectColor", { r, g, b })
			ASet("selectColorCustom", true)
			ASet("useClassColor", false)
		end,
		{ active = function() return ACfg("useClassColor") ~= true and ACfg("selectColorCustom") == true end,
		  onClick = function()
			if ACfg("selectColorCustom") ~= true or ACfg("useClassColor") == true then
				ASet("selectColorCustom", true)
				ASet("useClassColor", false)
				return true
			end
		  end })
	p:Swatch("Accent Color",
		function() return ns.ResolveAccent() end,
		function() end,
		{ readonly = true,
		  active = function() return ACfg("useClassColor") ~= true and ACfg("selectColorCustom") ~= true end,
		  onClick = function()
			ASet("selectColorCustom", false)
			ASet("useClassColor", false)
			return true
		  end })
	p:Swatch("Class Color",
		function()
			local _, class = UnitClass("player")
			local c = RAID_CLASS_COLORS and class and RAID_CLASS_COLORS[class]
			if c then return c.r, c.g, c.b, 1 end
			return 1, 1, 1, 1
		end,
		function() end,
		{ readonly = true,
		  active = function() return ACfg("useClassColor") == true end,
		  onClick = function()
			ASet("useClassColor", true)
			return true
		  end })
	p:Toggle("Show Action Text Label", "Show the selected action's name next to the selected icon.",
		function() return ACfg("showActionText") == true end,
		function(v) ASet("showActionText", v) end, Off)
	p:Toggle("Hide Unavailable Actions", "Hides any actions not available to this character.",
		function() return ACfg("hideUnusable") ~= false end,
		function(v) ASet("hideUnusable", v) end, Off)
	p:Toggle("Toggle World Markers",
		"Use a world marker entry again to pick that marker back up. Off places the marker again, at the new position.\nThis does not change the entry that clears all world markers, or the cycling entry.",
		function() return ACfg("worldMarkerToggle") ~= false end,
		function(v) ASet("worldMarkerToggle", v) end, Off)
	p:Cog("World Marker Entries", {
		{ type = "toggle", label = "Show Placed-Marker Pips",
		  tip = "Mark a world marker entry whose marker is on the ground with a small corner square, so you can see whether pressing it places or picks up.",
		  get = function() return ACfg("worldMarkerPip") ~= false end, set = function(v) ASet("worldMarkerPip", v) end },
	})
end

ns.RegisterSettingsModule({
	key = "quickdraw",
	name = "Quickdraw",
	group = "QoL Addons",
	tabs = {
		{
			key = "quickdraw",
			name = "Quickdraw",
			description = "Hold a keybind to open a menu of actions; point or scroll to choose, release to fire.",
			build = Build,
			pageKey = PageKey,
		},
	},
	reset = function()
		editPalette = 1
		QD.Reset()
		rev = rev + 1
	end,
	resetTip = "Set all Quickdraw settings back to default. Key bindings stay.",
})
