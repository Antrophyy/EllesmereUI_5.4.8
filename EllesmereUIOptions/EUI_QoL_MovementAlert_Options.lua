-- Settings for Quality of Life > Movement Alerts (retail EUI_QoL_MovementAlert_Options.lua).
-- Tab builder only: EUI_QoL_Options.lua adds the tab. Settings live in
-- EllesmereUIQoLDB.movementAlert; setters only store, the runtime follows
-- them through ns.applyHooks. Not on 5.4.8: TTS rows (no C_VoiceChat) and
-- the Gateway Shard alert (no Gateway Control Shard item in Mists).

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUIQoL") then
	return
end

local U = ns.OptionsUtil

local function MA() return ns.GetMovementAlertDB and ns.GetMovementAlertDB() or {} end
local function M() return ns.MovementAlert end

local CLASS_ORDER = {
	"DEATHKNIGHT", "DRUID", "HUNTER", "MAGE", "MONK", "PALADIN",
	"PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR",
}

local function ClassLabel(cf)
	local name = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[cf]) or (cf:sub(1, 1) .. cf:sub(2):lower())
	local c = RAID_CLASS_COLORS[cf]
	local hex = c and c.colorStr or "ffffffff"
	return "|c" .. hex .. name .. "|r"
end

local function Items(list)
	local items = {}
	for i = 1, #list, 2 do
		items[#items + 1] = { value = list[i], name = list[i + 1] }
	end
	return function() return items end, function(v)
		for i = 1, #list, 2 do
			if list[i] == v then return list[i + 1] end
		end
		return tostring(v)
	end
end

local DM_ITEMS, DM_LABEL = Items({
	"text_nd", "Text: Name Duration",
	"text_dn", "Text: Duration Name",
	"text_d", "Text: Duration",
	"icon", "Icon",
	"bar", "Bar",
})

local function SoundItems()
	local Q = ns.QoL
	local items = {}
	if Q and Q.SOUND_ORDER then
		for _, key in ipairs(Q.SOUND_ORDER) do
			items[#items + 1] = { value = key, name = Q.SOUND_NAMES[key] or key }
		end
	else
		items[1] = { value = "none", name = "None" }
	end
	return items
end
local function SoundLabel(key)
	local Q = ns.QoL
	return (Q and Q.SOUND_NAMES and Q.SOUND_NAMES[key or "none"]) or (key == "none" and "None") or tostring(key)
end

local function BarTexItems()
	local items = { { name = "None", value = "none" } }
	for _, item in ipairs(U.MediaItems(ns.GetBarTextures and ns.GetBarTextures() or {})) do
		items[#items + 1] = item
	end
	return items
end
local function BarTexLabel(v)
	if v == nil or v == "none" or not tostring(v):find("[\\/]") then return "None" end
	return ns.GetBarTextureLabel and ns.GetBarTextureLabel(v) or tostring(v)
end

-- Which class's spell list the Tracked Spells section shows (kept across rebuilds).
local spellClass = select(2, UnitClass("player"))

local function SpellRowLabel(spellId)
	local name, _, icon = GetSpellInfo(spellId)
	return "|T" .. (icon or "Interface\\Icons\\INV_Misc_QuestionMark") .. ":16:16:0:0:64:64:5:59:5:59|t " .. (name or ("Spell " .. spellId))
end

ns.QoLO_BuildMovementAlertPage = function(p)
	if not ns.GetMovementAlertDB or not M() then
		return
	end
	local ma = MA()
	local function maOff() return type(MA().enabledClasses) ~= "table" end

	-- Live preview while the page is shown (retail loops a fake cooldown).
	if type(p.scroll) == "table" and not p.scroll.maHooked and M().SetPreview then
		p.scroll.maHooked = true
		p.scroll:HookScript("OnShow", function() if not maOff() then M().SetPreview(true) end end)
		p.scroll:HookScript("OnHide", function() M().SetPreview(false) end)
	end

	-- MOVEMENT COOLDOWN ALERT ---------------------------------------------
	p:Section("Movement Cooldown Alert")
	p:MultiSelect("Enable Movement Alerts", "Shows the checked classes' mobility spell(s) counting down on cooldown. Nothing checked = feature disabled. Use Unlock Mode to reposition/resize.",
		function()
			local items = {}
			for _, cf in ipairs(CLASS_ORDER) do items[#items + 1] = { value = cf, name = ClassLabel(cf) } end
			return items
		end,
		function(cf) local ec = MA().enabledClasses; return type(ec) == "table" and ec[cf] or false end,
		function(cf)
			local m = MA()
			if type(m.enabledClasses) ~= "table" then m.enabledClasses = {} end
			m.enabledClasses[cf] = (not m.enabledClasses[cf]) or nil
			if not next(m.enabledClasses) then m.enabledClasses = nil end
		end,
		function()
			local ec, n = MA().enabledClasses, 0
			if type(ec) == "table" then
				for _, cf in ipairs(CLASS_ORDER) do if ec[cf] then n = n + 1 end end
			end
			if n == 0 then return "None" end
			if n == #CLASS_ORDER then return "All Classes" end
			return n .. " Classes"
		end)
	p:Toggle("Combat Only", "Only show the alert while in combat.",
		function() return MA().combatOnly == true end, function(v) MA().combatOnly = v end, maOff)

	local function swatchOff() return maOff() or MA().displayMode == "icon" end
	p:Dropdown("Display Mode", "Text, an icon with a cooldown swipe, or a bar.",
		DM_ITEMS,
		function() local v = MA().displayMode or "text"; return v == "text" and "text_dn" or v end,
		function() local v = MA().displayMode or "text"; return DM_LABEL(v == "text" and "text_dn" or v) end,
		function(v)
			local m = MA()
			local function isText(x) return x == nil or x == "text" or x == "text_nd" or x == "text_dn" or x == "text_d" end
			if isText(m.displayMode) ~= isText(v) then m.textSize = isText(v) and 24 or 12 end
			m.displayMode = v
		end, nil, maOff)
	p:Cog("Display Size", {
		{ type = "slider", label = "Text Size", min = 8, max = 72, step = 1,
		  get = function() return MA().textSize or 24 end, set = function(v) MA().textSize = v end },
		{ type = "slider", label = "Icon Size", min = 16, max = 128, step = 1,
		  get = function() return MA().iconSize or 40 end, set = function(v) MA().iconSize = v end,
		  disabled = function() return MA().displayMode ~= "icon" end },
		{ type = "toggle", label = "Show Decimal",
		  get = function() return (tonumber(MA().precision) or 1) > 0 end,
		  set = function(v) MA().precision = v and 1 or 0 end,
		  disabled = function() return MA().displayMode == "icon" end },
	}, { icon = "resize", disabled = maOff, disabledTip = "Select an Enabled Class" })
	p:Swatch("Class Colored",
		function()
			local c = RAID_CLASS_COLORS[select(2, UnitClass("player"))]
			if c then return c.r, c.g, c.b end
			return 1, 1, 1
		end,
		function() end,
		{ readonly = true, disabled = swatchOff, active = function() return MA().textColorUseClass == true end,
		  onClick = function() MA().textColorUseClass = true; return true end })
	p:Swatch("Custom Colored",
		function() local m = MA(); return m.textColorR or 1, m.textColorG or 1, m.textColorB or 1 end,
		function(r, g, b) local m = MA(); m.textColorR, m.textColorG, m.textColorB = r, g, b end,
		{ disabled = swatchOff, active = function() return MA().textColorUseClass ~= true end,
		  onClick = function()
			  if MA().textColorUseClass then
				  MA().textColorUseClass = false
				  return true
			  end
		  end })

	local function barOff() return maOff() or MA().displayMode ~= "bar" end
	p:Dropdown("Bar Texture", "Texture of the bar (Bar display mode).",
		BarTexItems, function() return MA().barTexture or "none" end,
		function() return BarTexLabel(MA().barTexture) end,
		function(v) MA().barTexture = v end,
		{ texturePreview = true }, barOff)
	p:Cog("Bar Settings", {
		{ type = "toggle", label = "Show Icon on Bar",
		  get = function() return MA().barShowIcon ~= false end, set = function(v) MA().barShowIcon = v end },
		{ type = "toggle", label = "Show Duration Text",
		  get = function() return MA().barShowDuration ~= false end, set = function(v) MA().barShowDuration = v end },
	}, { disabled = barOff, disabledTip = "Requires Bar display mode" })

	p:Dropdown("Sound", "Plays once when a shown cooldown is ready again.",
		SoundItems, function() return MA().maSoundKey or "none" end,
		function() return SoundLabel(MA().maSoundKey) end,
		function(v)
			MA().maSoundKey = v
			if M().PlayAlertSound then M().PlayAlertSound(v) end
		end, nil, maOff)

	-- TRACKED SPELLS -------------------------------------------------------
	p:Section("Tracked Spells")
	p:Dropdown("Class", "Whose spells are listed below. Only spells your character knows are tracked.",
		function()
			local items = {}
			for _, cf in ipairs(CLASS_ORDER) do items[#items + 1] = { value = cf, name = ClassLabel(cf) } end
			return items
		end,
		function() return spellClass end,
		function() return ClassLabel(spellClass) end,
		function(v) spellClass = v end)
	p:Button("Add Spell", "Track another spell of this class by its spell ID.", "+ Add Spell", function()
		ns.ShowInputPopup({
			title = "Add Spell",
			message = "Spell ID to track for " .. ClassLabel(spellClass) .. ":",
			text = "",
			confirmText = "Add",
			cancelText = "Cancel",
			onConfirm = function(text)
				local id = tonumber(text)
				if not id or not GetSpellInfo(id) then return end
				local m = MA()
				m.spellOverrides = m.spellOverrides or {}
				local ov = m.spellOverrides[id] or {}
				ov.enabled, ov.class = true, spellClass
				m.spellOverrides[id] = ov
				ns.RebuildSettingsPage()
			end,
		})
	end)

	local overrides = ma.spellOverrides or {}
	local ids, seen = {}, {}
	for _, id in ipairs(M().MOVEMENT_ABILITIES[spellClass] or {}) do
		ids[#ids + 1] = id
		seen[id] = true
	end
	local custom = {}
	for id, ov in pairs(overrides) do
		if type(id) == "number" and not seen[id] and type(ov) == "table" and ov.class == spellClass then
			custom[#custom + 1] = id
		end
	end
	table.sort(custom)
	for _, id in ipairs(custom) do ids[#ids + 1] = id end

	for _, id in ipairs(ids) do
		local spellId = id
		local isCustom = not seen[spellId]
		local function Ov()
			local m = MA()
			m.spellOverrides = m.spellOverrides or {}
			return m.spellOverrides[spellId]
		end
		local label = SpellRowLabel(spellId)
		local ov = overrides[spellId]
		if ov and ov.customText and ov.customText ~= "" then
			label = label .. " |cff888888(" .. ov.customText .. ")|r"
		end
		p:Toggle(label, "Track this spell. The pencil sets a custom text shown in place of the spell name.",
			function() return M().SpellEffectivelyEnabled(Ov(), spellId) end,
			function(v)
				local m = MA()
				m.spellOverrides = m.spellOverrides or {}
				local o = m.spellOverrides[spellId] or {}
				o.enabled = v
				if isCustom then o.class = spellClass end
				m.spellOverrides[spellId] = o
			end)
		p:InlineIcon("Custom Text", "Interface\\Buttons\\UI-GuildButton-PublicNote-Up", function()
			ns.ShowInputPopup({
				title = "Custom Text",
				message = "Text shown in place of the spell name (empty = spell name):",
				text = (Ov() and Ov().customText) or "",
				confirmText = "Save",
				cancelText = "Cancel",
				onConfirm = function(text)
					local m = MA()
					m.spellOverrides = m.spellOverrides or {}
					local o = m.spellOverrides[spellId] or {}
					o.customText = (text and text ~= "") and text or nil
					if isCustom then o.class = spellClass end
					m.spellOverrides[spellId] = o
					ns.RebuildSettingsPage()
				end,
			})
		end)
		if isCustom then
			p:InlineIcon("Remove", "Interface\\Buttons\\UI-StopButton", function()
				MA().spellOverrides[spellId] = nil
				ns.RebuildSettingsPage()
			end)
		end
	end

	-- EXTRA TRACKING -------------------------------------------------------
	local function tsOff() return not MA().tsEnabled end
	p:Section("Extra Tracking")
	p:Toggle("Enable Time Spiral Tracker", "Flashes a banner whenever a tracked mobility spell lights up (spell activation glow, for example when its cooldown is reset). Use Unlock Mode to reposition/resize.",
		function() return MA().tsEnabled == true end, function(v) MA().tsEnabled = v end)
	p:Cog("Time Spiral Settings", {
		{ type = "toggle", label = "Use Class Color",
		  get = function() return MA().tsColorUseClass == true end, set = function(v) MA().tsColorUseClass = v end },
		{ type = "color", label = "Color",
		  get = function() local m = MA(); return m.tsColorR or 0.53, m.tsColorG or 1, m.tsColorB or 0 end,
		  set = function(r, g, b) local m = MA(); m.tsColorR, m.tsColorG, m.tsColorB = r, g, b end,
		  disabled = function() return MA().tsColorUseClass == true end },
		{ type = "dropdown", label = "Sound", items = SoundItems,
		  get = function() return MA().tsSoundKey or "none" end,
		  set = function(v)
			  MA().tsSoundKey = v
			  if M().PlayAlertSound then M().PlayAlertSound(v) end
		  end },
	}, { disabled = tsOff, disabledTip = "Enable Time Spiral Tracker first." })
	p:TextInput("Text Format", "Banner text. %.1f = seconds left, \\n = new line.",
		function() return MA().tsTextFormat or "FREE MOVEMENT\\n%.1f" end,
		function(t) MA().tsTextFormat = (t ~= "") and t or nil end,
		"FREE MOVEMENT\\n%.1f")
end
