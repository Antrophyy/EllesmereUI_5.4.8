-------------------------------------------------------------------------------
--  EUI_RaidFrames_ClickCast_Options.lua  (5.4.8 port of the retail Click
--  Casting page, ns.CC_BuildPage in EUI_RaidFrames_ClickCast.lua)
--
--  Retail draws its own three-column panel (global sidebar, options, spec
--  sidebar, spell strip, quickbind). 5.4.8 rebuilds it with the settings Page
--  API: Global Options, a binding list for "Global" or one spec (spec
--  selector), add menus (spells from the spellbook, macros, items, actions),
--  and the per-binding options of the selected binding (key, Dynamic Rez,
--  out of combat, Active In, Cast On, Friendly / Enemy).
--  The tab is registered by EUI_RaidFrames_Options.lua (worker E) with
--  build = EllesmereUI.RFO_BuildClickCastPage, pageKey = RFO_ClickCastPageKey.
-------------------------------------------------------------------------------
if not IsAddOnLoaded("EllesmereUIRaidFrames") then
	return
end

local ns = EllesmereUI
local function Engine()
	local ERF = ns.ERF
	return ERF and ERF.RF
end

local REMOVE_ICON = "Interface\\Buttons\\UI-StopButton"
local EDIT_ICON = "Interface\\Buttons\\UI-GuildButton-PublicNote-Up"

-- Page state: which list is shown ("global" or a specID) and the selected binding.
local scope = nil
local selected = nil
local rev = 0

local function PageKey()
	return rev
end
ns.RFO_ClickCastPageKey = PageKey

local function Rebuild()
	rev = rev + 1
	if ns.RebuildSettingsPage then
		ns.RebuildSettingsPage()
	end
end

local function Apply()
	local RF = Engine()
	if RF and RF.CC_ApplyBindings then
		RF.CC_ApplyBindings()
	end
end

local function CurrentScope(RF)
	if scope == nil then
		scope = RF.CC_GetCurrentSpecID() or "global"
	end
	return scope
end

-- The binding list being edited (created on first add for a spec).
local function ScopeList(RF, create)
	local cc = RF.CC_GetClickCastDB()
	if not cc then
		return {}
	end
	local s = CurrentScope(RF)
	if s == "global" then
		return cc.globals
	end
	return RF.CC_SpecList(cc, s, create) or {}
end

local function AddBinding(RF, binding)
	if binding.enabled == nil then
		binding.enabled = true
	end
	local list = ScopeList(RF, true)
	list[#list + 1] = binding
	selected = binding
	Apply()
	Rebuild()
end

local function RemoveBinding(RF, binding)
	local list = ScopeList(RF)
	for i = #list, 1, -1 do
		if list[i] == binding then
			table.remove(list, i)
		end
	end
	if selected == binding then
		selected = nil
	end
	Apply()
	Rebuild()
end

local TYPE_LABEL = {
	spell = "Spell", macro = "Macro", item = "Item", target = "Action", menu = "Action",
	dispel = "Preset", external = "Preset", dynamicrez = "Preset", trinket1 = "Item", trinket2 = "Item",
}

local function BindingText(RF, b)
	local name = RF.CC_GetBindingName(b)
	local key = (b.key and b.key ~= "") and RF.CC_FormatKey(b.key) or "Not Bound"
	local icon = RF.CC_GetBindingIcon(b)
	local iconStr = icon and ("|T" .. icon .. ":16:16:0:0:64:64:5:59:5:59|t  ") or ""
	local dim = (b.type == "spell" and not RF.CC_IsBindingKnown(b)) and "|cff808080" or ""
	return iconStr .. dim .. name .. (dim ~= "" and "|r" or "") .. "  |cff8a8a8a" .. key .. "|r"
end

-- Mouse button choices for the key editor ("" = a keyboard key).
local BUTTON_LIST = {
	{ key = "", text = "Keyboard Key" },
	{ key = "BUTTON1", text = "Left Click" },
	{ key = "BUTTON2", text = "Right Click" },
	{ key = "BUTTON3", text = "Middle Click" },
	{ key = "BUTTON4", text = "Mouse 4" },
	{ key = "BUTTON5", text = "Mouse 5" },
	{ key = "MOUSEWHEELUP", text = "Wheel Up" },
	{ key = "MOUSEWHEELDOWN", text = "Wheel Down" },
}

local ACTION_LIST = {
	{ key = "target", text = "Target Unit" },
	{ key = "menu", text = "Context Menu" },
	{ key = "dispel", text = "Dispels" },
	{ key = "external", text = "Externals" },
	{ key = "dynamicrez", text = "Dynamic Rez" },
	{ key = "trinket1", text = "Trinket 1" },
	{ key = "trinket2", text = "Trinket 2" },
	{ key = "custommacro", text = "Custom Macro" },
}

local CTX_ITEMS = {
	{ name = "Solo", value = "solo", tip = "Active while you are not in a group." },
	{ name = "Party", value = "party", tip = "Active in a PvE party." },
	{ name = "Raid", value = "raid", tip = "Active in a PvE raid." },
	{ name = "PvP", value = "pvp", tip = "Active in battlegrounds and arenas." },
}

-- Key editing: the saved key is "ALT-CTRL-SHIFT-<KEY>".
local function KeyParts(RF, b)
	local parsed = RF.CC_ParseKeyString(b.key)
	return parsed
end

local function SetKey(RF, b, mods, key)
	if not key or key == "" then
		b.key = nil
	else
		b.key = RF.CC_CanonKey(mods .. key)
	end
	-- Hovercast is not available for unmodified left / right click.
	if (b.key == "BUTTON1" or b.key == "BUTTON2") and b.hovercast then
		b.hovercast = false
	end
	Apply()
	Rebuild()
end

local function ToggleMod(RF, b, mod, on)
	local parsed = KeyParts(RF, b)
	local mods = parsed.modifiers:gsub(mod .. "%-", "")
	if on then
		mods = mods .. mod .. "-"
	end
	if parsed.key == "" then
		-- No key yet: keep the modifier choice for when a key is picked.
		b._pendingMods = mods
		Rebuild()
		return
	end
	SetKey(RF, b, mods, parsed.key)
end

local function HasMod(RF, b, mod)
	local parsed = KeyParts(RF, b)
	local mods = parsed.key == "" and (b._pendingMods or "") or parsed.modifiers
	return mods:find(mod .. "-", 1, true) ~= nil
end

local function EncodeMacro(text)
	return (text or ""):gsub("\n", "\\n")
end
local function DecodeMacro(text)
	return (text or ""):gsub("\\n", "\n")
end

-------------------------------------------------------------------------------
--  Per-binding options (retail PER-SPELL OPTIONS)
-------------------------------------------------------------------------------
local function BuildBindingOptions(p, RF, b)
	local t = b.type
	p:Section("Per-Spell Options")
	p:Paragraph((TYPE_LABEL[t] or "Action") .. ":  " .. BindingText(RF, b))

	p:Toggle("Enabled", "Turn this binding off without deleting it.",
		function() return b.enabled ~= false end,
		function(v) b.enabled = v and true or false; Apply() end)
	p:InlineIcon("Remove this binding", REMOVE_ICON, function() RemoveBinding(RF, b) end)

	-- Keybind: mouse button (or keyboard) + modifiers.
	p:Dropdown("Mouse Button", "The mouse button or wheel direction that runs this binding. Pick Keyboard Key to use a key instead (it works while the mouse is over a frame).",
		function() return ns.OptionsUtil.KeyItems(BUTTON_LIST) end,
		function()
			local parsed = KeyParts(RF, b)
			return parsed.isMouseButton and parsed.key or ""
		end,
		function()
			local parsed = KeyParts(RF, b)
			return parsed.isMouseButton and ns.OptionsUtil.KeyLabel(BUTTON_LIST, parsed.key) or "Keyboard Key"
		end,
		function(v)
			local parsed = KeyParts(RF, b)
			local mods = parsed.key == "" and (b._pendingMods or "") or parsed.modifiers
			if v == "" then
				if parsed.isMouseButton then
					b._pendingMods = mods
					b.key = nil
					Apply()
				end
				Rebuild()
				return
			end
			b._pendingMods = nil
			SetKey(RF, b, mods, v)
		end)
	local parsedNow = KeyParts(RF, b)
	if not parsedNow.isMouseButton then
		p:Keybind("Keyboard Key", "Left-click, then press a key (with Shift / Ctrl / Alt). Right-click to clear.",
			function()
				local k = b.key
				return (k and k ~= "") and RF.CC_FormatKey(k) or nil
			end,
			function(k)
				b._pendingMods = nil
				if not k then
					SetKey(RF, b, "", nil)
				else
					SetKey(RF, b, "", k)
				end
			end)
	else
		p:Toggle("Shift", "Hold Shift for this binding.",
			function() return HasMod(RF, b, "SHIFT") end,
			function(v) ToggleMod(RF, b, "SHIFT", v) end)
		p:Toggle("Ctrl", "Hold Ctrl for this binding.",
			function() return HasMod(RF, b, "CTRL") end,
			function(v) ToggleMod(RF, b, "CTRL", v) end)
		p:Toggle("Alt", "Hold Alt for this binding.",
			function() return HasMod(RF, b, "ALT") end,
			function(v) ToggleMod(RF, b, "ALT", v) end)
	end
	local conflicts = RF.CC_FindKeyConflicts(b.key, b)
	if #conflicts > 0 then
		local names = {}
		for i = 1, #conflicts do
			names[i] = RF.CC_GetBindingName(conflicts[i])
		end
		p:Paragraph("|cffff5555Conflicting Keybind:|r " .. table.concat(names, ", ")
			.. ". A spec binding wins over a global one; otherwise the first binding keeps the key.")
	end

	if t == "macro" and (b.macroText or not b.macroName) then
		p:Button("Macro Text", "The macro this binding runs. Write \\n between lines. 255 characters at most.", "Edit Macro", function()
			ns.ShowInputPopup({
				title = "Custom Macro",
				message = "Macro text. Write \\n between lines (example: /cast [@mouseover] Flash Heal).",
				text = EncodeMacro(b.macroText),
				confirmText = "Save",
				onConfirm = function(text)
					b.macroText = DecodeMacro(text)
					Apply()
					Rebuild()
				end,
			})
		end)
	end

	local canSmartRez = t == "spell" or t == "macro" or t == "item" or t == "dispel" or t == "external"
		or t == "trinket1" or t == "trinket2"
	if canSmartRez then
		p:Toggle("Enable Dynamic Rez", "On a dead unit this binding casts your resurrection spell (battle rez in combat) instead of its normal action.",
			function() return b.smartRez end,
			function(v) b.smartRez = v and true or nil; Apply() end)
	end

	local hasAdvancedOpts = canSmartRez or t == "dynamicrez"
	if hasAdvancedOpts or t == "menu" or t == "target" then
		local oocLabel = "Only Cast Out of Combat"
		if t == "menu" then
			oocLabel = "Only Open Menu Out of Combat"
		elseif t == "target" then
			oocLabel = "Only Target Out of Combat"
		end
		p:Toggle(oocLabel, nil,
			function() return b.oocOnly end,
			function(v) b.oocOnly = v and true or nil; Apply() end)
	end

	p:MultiSelect("Active In", "Content this binding is active in. Outside it the key keeps its normal use.",
		function() return CTX_ITEMS end,
		function(key) return RF.CC_CtxEnabled(b, key) end,
		function(key)
			local set = b.groupCtx
			if type(set) ~= "table" then
				set = {}
				for _, c in ipairs(RF.CC_CTX_ORDER) do
					set[c] = true
				end
				b.groupCtx = set
			end
			set[key] = not (set[key] == true)
			local n = 0
			for _, c in ipairs(RF.CC_CTX_ORDER) do
				if set[c] == true then
					n = n + 1
				end
			end
			if n == #RF.CC_CTX_ORDER then
				b.groupCtx = nil
			end
			Apply()
		end,
		function()
			local set = b.groupCtx
			if type(set) ~= "table" then
				return "All"
			end
			local on = {}
			for _, item in ipairs(CTX_ITEMS) do
				if set[item.value] == true then
					on[#on + 1] = item.name
				end
			end
			if #on == 0 then
				return "None"
			end
			return table.concat(on, ", ")
		end)

	if hasAdvancedOpts then
		local bare = b.key == "BUTTON1" or b.key == "BUTTON2"
		local HC = {
			{ key = "frames", text = "Frames" },
			{ key = "units", text = "Mouseover" },
			{ key = "both", text = "Frames and Mouseover" },
		}
		p:Dropdown("Cast On", "Frames: only when clicking or hovering the raid frames. Mouseover: on any unit under the mouse (nameplates, world, other frames)."
			.. (bare and "\n\nHovercast is not available for unmodified left/right click" or ""),
			function()
				local items = ns.OptionsUtil.KeyItems(HC)
				if bare then
					items[2].locked = function() return true end
					items[3].locked = function() return true end
					items[2].lockedTip = "Hovercast is not available for unmodified left/right click"
					items[3].lockedTip = items[2].lockedTip
				end
				return items
			end,
			function()
				if b.hovercast == "both" then
					return "both"
				end
				return b.hovercast and "units" or "frames"
			end,
			function()
				local v = (b.hovercast == "both" and "both") or (b.hovercast and "units") or "frames"
				return ns.OptionsUtil.KeyLabel(HC, v)
			end,
			function(v)
				if bare and v ~= "frames" then
					return
				end
				b.hovercast = (v == "both" and "both") or (v == "units" and true) or false
				Apply()
				Rebuild()
			end)
		if t == "spell" or t == "item" or b.hovercast then
			p:Toggle("Friendly", "Cast on friendly units. Disabling both disables this binding.",
				function() return b.hoverFriendly ~= false end,
				function(v) b.hoverFriendly = v and true or false; Apply(); Rebuild() end)
			p:Toggle("Enemy", "Cast on enemy units. Disabling both disables this binding.",
				function() return b.hoverEnemy == true end,
				function(v) b.hoverEnemy = v and true or false; Apply(); Rebuild() end)
		end
	end
end

-------------------------------------------------------------------------------
--  The page
-------------------------------------------------------------------------------
function ns.RFO_BuildClickCastPage(p)
	local RF = Engine()
	if not RF or not RF.CC_GetClickCastDB then
		p:Paragraph("Click Casting is not loaded.")
		return
	end
	local cc = RF.CC_GetClickCastDB()
	if not cc then
		p:Paragraph("Click Casting is not available yet.")
		return
	end
	local clique = IsAddOnLoaded("Clique")
	local function Off()
		return not cc.enabled
	end

	p:Section("Global Options")
	p:Toggle("Enable Click Casting",
		clique and 'Please disable the addon "Clique" to use this feature.'
			or "Cast spells, macros and actions by clicking the raid and party frames (or pressing keys while hovering them).",
		function() return cc.enabled end,
		function(v)
			if clique then
				return
			end
			RF.CC_SetEnabled(v)
			Rebuild()
		end,
		function() return clique end)
	p:Toggle("Trigger Bindings on Down", "Run bindings when the mouse button or key goes down instead of up.",
		function() return cc.downClick end,
		function(v) RF.CC_SetDownClick(v) end, Off)
	local MF = { { key = "all", text = "All Unit Frames" }, { key = "rf", text = "EUI Raid & Party Frames" } }
	p:Dropdown("Mouseover Frames", "Which frames use the frame bindings: only the EllesmereUI raid and party frames, or every unit frame that supports click casting (EllesmereUI unit frames and others).",
		function() return ns.OptionsUtil.KeyItems(MF) end,
		function() return cc.allFrames and "all" or "rf" end,
		function() return ns.OptionsUtil.KeyLabel(MF, cc.allFrames and "all" or "rf") end,
		function(v) RF.CC_SetAllFrames(v == "all") end, nil, Off)

	-- Binding list: Global or one spec.
	p:Section("Bindings")
	local function ScopeItems()
		local items = { { name = "Global Bindings", value = "global" } }
		local n = (GetNumSpecializations and GetNumSpecializations()) or 0
		for i = 1, n do
			local id, name, _, icon = GetSpecializationInfo(i)
			if id then
				local label = (icon and ("|T" .. icon .. ":14|t ") or "") .. (name or ("Spec " .. i))
				if id == RF.CC_GetCurrentSpecID() then
					label = label .. "  |cff8a8a8a(current)|r"
				end
				items[#items + 1] = { name = label, value = id }
			end
		end
		return items
	end
	p:Dropdown("Edit Bindings For", "Global bindings apply to every spec. A spec binding wins over a global binding on the same key.",
		ScopeItems,
		function() return CurrentScope(RF) end,
		function()
			local s = CurrentScope(RF)
			for _, item in ipairs(ScopeItems()) do
				if item.value == s then
					return item.name
				end
			end
			return "Global Bindings"
		end,
		function(v)
			scope = v
			selected = nil
			Rebuild()
		end)

	-- Add menus (retail "Add New" / "Add Global Binding": Spells, Macros, Items, Actions).
	p:Dropdown("Add Spell", "Add a spell from your spellbook.",
		function()
			local items = {}
			for _, sp in ipairs(RF.CC_GetClassSpells()) do
				items[#items + 1] = { name = (sp.icon and ("|T" .. sp.icon .. ":14|t ") or "") .. sp.name, value = sp.id, sp = sp }
			end
			if #items == 0 then
				items[1] = { name = "No spells found", header = true }
			end
			return items
		end,
		function() return nil end,
		function() return "Add Spell..." end,
		function(v)
			if not v then
				return
			end
			local name = GetSpellInfo(v)
			AddBinding(RF, { type = "spell", spell = name, spellID = v })
		end)
	p:Dropdown("Add Action", "Add a targeting / menu action, a class preset (dispels, externals, dynamic rez), a trinket or a custom macro.",
		function() return ns.OptionsUtil.KeyItems(ACTION_LIST) end,
		function() return nil end,
		function() return "Add Action..." end,
		function(v)
			if v == "custommacro" then
				AddBinding(RF, { type = "macro", macroText = "" })
			elseif v then
				AddBinding(RF, { type = v })
			end
		end)
	p:Dropdown("Add Macro", "Add one of your account or character macros (by name).",
		function()
			local items = {}
			for _, m in ipairs(RF.CC_GetAllMacros()) do
				items[#items + 1] = { name = (m.icon and ("|T" .. m.icon .. ":14|t ") or "") .. m.name, value = m.macroName }
			end
			if #items == 0 then
				items[1] = { name = "No macros", header = true }
			end
			return items
		end,
		function() return nil end,
		function() return "Add Macro..." end,
		function(v)
			if v then
				AddBinding(RF, { type = "macro", macroName = v })
			end
		end)
	p:Dropdown("Add Item", "Add an equipped item with a use effect.",
		function()
			local items = {}
			for _, it in ipairs(RF.CC_GetEquippedItems()) do
				items[#items + 1] = { name = (it.icon and ("|T" .. it.icon .. ":14|t ") or "") .. it.name, value = it.itemSlot, it = it }
			end
			if #items == 0 then
				items[1] = { name = "No usable items equipped", header = true }
			end
			return items
		end,
		function() return nil end,
		function() return "Add Item..." end,
		function(v)
			if v then
				local itemID = GetInventoryItemID("player", v)
				local name = itemID and GetItemInfo(itemID)
				AddBinding(RF, { type = "item", itemSlot = v, itemName = name })
			end
		end)

	local list = ScopeList(RF)
	p:Section(CurrentScope(RF) == "global" and "Global Bindings" or "Spec Bindings")
	if #list == 0 then
		p:Paragraph("No bindings yet. Use the Add menus above. Unbound clicks keep their normal use (left click targets, right click opens the menu).")
	end
	local known = {}
	for i = 1, #list do
		known[i] = list[i]
	end
	for i = 1, #known do
		local b = known[i]
		if type(b) == "table" then
			local isSel = selected == b
			p:Toggle((isSel and "|cff0cd29f> |r" or "") .. BindingText(RF, b),
				(b.type == "spell" and not RF.CC_IsBindingKnown(b)) and "Not currently talented / known." or "Click the pencil to edit this binding.",
				function() return b.enabled ~= false end,
				function(v) b.enabled = v and true or false; Apply() end)
			p:InlineIcon("Remove", REMOVE_ICON, function() RemoveBinding(RF, b) end)
			p:InlineIcon("Edit", EDIT_ICON, function()
				selected = (selected == b) and nil or b
				Rebuild()
			end)
		end
	end

	if selected then
		-- The selected binding may belong to another list after a scope change.
		local inList = false
		for i = 1, #list do
			if list[i] == selected then
				inList = true
			end
		end
		if inList then
			BuildBindingOptions(p, RF, selected)
		else
			selected = nil
		end
	else
		p:Paragraph("Select a binding (pencil icon) to edit its options.")
	end
end
