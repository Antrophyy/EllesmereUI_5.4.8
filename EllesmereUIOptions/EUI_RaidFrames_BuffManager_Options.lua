-- Settings tab Raid Frames > Buff Manager (retail Buff Manager v2 page:
-- EUI_RaidFrames_BuffManager.lua ns.BM_BuildPage + EUI_RaidFrames_ManagerPages.lua
-- BMP_* filter pieces; same keys, labels and tooltips, built with this
-- window's Page API).
--
-- Layout: retail shows a tile sidebar of the indicators next to a frame
-- preview. Here the content header holds the same choices: the Editing Spec
-- picker, the indicator picker with rename / delete, "Add New" (indicator
-- type) and "Edit Filters". The Filter Editor (retail modal) is a page mode
-- with a "Back to Indicators" button. The raid frame preview shows the
-- edited spec's indicators while this tab is open.
--
-- 5.4.8 differences: Frame Border is solid only (no dashed / textured
-- styles), no Icon Glow, no Custom Order, Show When for effects is
-- "When Any Present" only (as retail 12.1), retail-only spells (not on this
-- client) are hidden from the lists.
-- Part of EllesmereUIOptions (load on demand); the module and its tabs are
-- registered by EUI_RaidFrames_Options.lua.

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUIRaidFrames") then
	return
end

local floor, max, min = math.floor, math.max, math.min
local format = string.format
local FONT = ns.FONT
local FONT_FALLBACK = "Fonts\\ARIALN.TTF"

local function RFT()
	local ERF = ns.ERF
	return ERF and ERF.RF, ERF
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
local specSel        -- edited bucket key (nil = the player's active key)
local indSel         -- selected indicator id
local mode = "inds"  -- "inds" / "filters"
local filterSel
local rev = 0

local function Rebuild()
	rev = rev + 1
	if ns.RebuildSettingsPage then
		ns.RebuildSettingsPage()
	end
end

-- Repaint the frames after a change made outside a Page control.
local function Apply()
	local RF, ERF = RFT()
	if RF and RF.BM2_Invalidate then
		RF.BM2_Invalidate()
	end
	if ERF and ERF.ApplyAll then
		ERF:ApplyAll()
	end
end

local function SpecKey()
	local RF = RFT()
	if not specSel then
		specSel = RF and RF.BM2_SpecKey and RF.BM2_SpecKey() or "nonhealer"
	end
	return specSel
end

local function Inds()
	local RF = RFT()
	if not (RF and RF.BM2_SpecInds) then
		return {}
	end
	return (RF.BM2_SpecInds(SpecKey())) or {}
end

local function Selected()
	local list = Inds()
	for _, ind in ipairs(list) do
		if ind.id == indSel then
			return ind
		end
	end
	local ind = list[1]
	indSel = ind and ind.id or nil
	return ind
end

local function PageKey()
	return table.concat({ mode, tostring(specSel), tostring(indSel), tostring(filterSel), rev }, ":")
end

---------------------------------------------------------------------------
-- Value lists (retail POSITION / GROW / ORIENT / FRAMELVL / types)
---------------------------------------------------------------------------
local TYPES = {
	{ "icon", "Icon" }, { "square", "Square" }, { "bar", "Bar" },
	{ "healthcolor", "Health Bar Color" }, { "bgcolor", "Background Color" }, { "border", "Frame Border" },
}
local POSITIONS = {
	{ "TOPLEFT", "Top Left" }, { "TOP", "Top" }, { "TOPRIGHT", "Top Right" },
	{ "LEFT", "Left" }, { "CENTER", "Center" }, { "RIGHT", "Right" },
	{ "BOTTOMLEFT", "Bottom Left" }, { "BOTTOM", "Bottom" }, { "BOTTOMRIGHT", "Bottom Right" },
}
local GROW = { { "RIGHT", "Right" }, { "LEFT", "Left" }, { "UP", "Up" }, { "DOWN", "Down" }, { "CENTER", "Center" } }
local ORIENT = { { "HORIZONTAL", "Horizontal" }, { "VERTICAL", "Vertical" } }
local FRAMELVL = {
	{ "behindBorders", "Behind Borders" }, { "behindText", "Behind Text" }, { "medium", "Medium" },
	{ "high", "High" }, { "highest", "Highest" },
}
local SHOW_IN = { { "both", "Raid and Party" }, { "raid", "Raid Only" }, { "party", "Party Only" } }
local CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID" }

-- Growth that matches a position (retail: corners grow inward).
local function DefaultGrow(pos)
	if pos == "TOPRIGHT" or pos == "RIGHT" or pos == "BOTTOMRIGHT" then
		return "LEFT"
	elseif pos == "TOP" or pos == "CENTER" or pos == "BOTTOM" then
		return "CENTER"
	end
	return "RIGHT"
end

local function Items(list)
	local out = {}
	for i = 1, #list do
		out[i] = { value = list[i][1], name = list[i][2] }
	end
	return out
end

local function LabelOf(list, value)
	for i = 1, #list do
		if list[i][1] == value then
			return list[i][2]
		end
	end
	return tostring(value or "")
end

local function SpellLabel(id)
	local name, _, icon = GetSpellInfo(id)
	if icon then
		return "|T" .. icon .. ":14:14:0:0:64:64:5:59:5:59|t " .. (name or ("Spell " .. id))
	end
	return name or ("Spell " .. id)
end

local function SetFont(fs, size)
	fs:SetFont(FONT, size, "")
	if not fs:GetFont() then
		fs:SetFont(FONT_FALLBACK, size, "")
	end
end

local function Text(parent, size, alpha)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	SetFont(fs, size)
	fs:SetTextColor(1, 1, 1, alpha or 1)
	return fs
end

local function Accent()
	if ns.ResolveAccent then
		local r, g, b = ns.ResolveAccent()
		if r then
			return r, g, b
		end
	end
	return 12 / 255, 210 / 255, 157 / 255
end

-- Flat text button (EllesmereUI MakeStyledButton).
local function FlatButton(parent, w, h, label, onClick, tip)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, h)
	local bg = b:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetTexture(0.061, 0.095, 0.112, 0.9)
	local edges = {}
	for i = 1, 4 do
		edges[i] = b:CreateTexture(nil, "BORDER")
		edges[i]:SetTexture(1, 1, 1, 0.2)
	end
	edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT"); edges[1]:SetHeight(1)
	edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT"); edges[2]:SetHeight(1)
	edges[3]:SetPoint("TOPLEFT"); edges[3]:SetPoint("BOTTOMLEFT"); edges[3]:SetWidth(1)
	edges[4]:SetPoint("TOPRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT"); edges[4]:SetWidth(1)
	local function Edge(r, g, bl, a)
		for i = 1, 4 do edges[i]:SetTexture(r, g, bl, a) end
	end
	b.text = Text(b, 12, 0.75)
	b.text:SetPoint("CENTER")
	b.text:SetText(label)
	b:SetScript("OnEnter", function(self)
		local r, g, bl = Accent()
		Edge(r, g, bl, 0.6)
		self.text:SetTextColor(1, 1, 1, 1)
		if tip then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(tip, 1, 1, 1, 1, true)
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function(self)
		Edge(1, 1, 1, 0.2)
		self.text:SetTextColor(1, 1, 1, 0.75)
		GameTooltip:Hide()
	end)
	b:SetScript("OnClick", onClick)
	return b
end

local function AskSpellId(title, message, onId)
	ns.ShowInputPopup({
		title = title,
		message = message,
		text = "",
		confirmText = "Add",
		cancelText = "Cancel",
		onConfirm = function(text)
			local id = tonumber(text and strtrim(text) or "")
			if id and id > 0 then
				onId(floor(id))
			end
		end,
	})
end

---------------------------------------------------------------------------
-- Getter / setter helpers on an indicator
---------------------------------------------------------------------------
local function G(ind, key, default)
	return function()
		local v = ind[key]
		if v == nil then
			return default
		end
		return v
	end
end

local function W(ind, key)
	return function(v)
		ind[key] = v
	end
end

local function CogSlider(ind, label, key, default, lo, hi, step)
	return { type = "slider", label = label, min = lo, max = hi, step = step or 1, get = G(ind, key, default), set = W(ind, key) }
end

local function ColGet(ind, key, dr, dg, db)
	return function()
		local c = ind[key]
		if type(c) ~= "table" then
			return dr, dg, db, 1
		end
		return c.r or dr, c.g or dg, c.b or db, 1
	end
end

local function ColSet(ind, key)
	return function(r, g, b)
		ind[key] = { r = r, g = g, b = b }
	end
end

---------------------------------------------------------------------------
-- Editing Spec items: group buckets, healer specs, and the player's own
-- non-healer specs ("spec<ID>" buckets).
---------------------------------------------------------------------------
local function SpecItems()
	local RF = RFT()
	local items = {}
	for _, g in ipairs(RF and RF.BM_GROUP_BUCKETS or {}) do
		items[#items + 1] = { value = g.key, name = g.name }
	end
	items[#items + 1] = { header = true, name = "Healer Specs" }
	for _, s in ipairs(RF and RF.BM_HEALER_SPECS or {}) do
		items[#items + 1] = { value = s.key, name = s.name }
	end
	local own = {}
	for i = 1, (GetNumSpecializations and GetNumSpecializations() or 0) do
		local id, name = GetSpecializationInfo(i)
		if id and not (RF and RF.BM_SpecKeyForSpecID and RF.BM_SpecKeyForSpecID(id)) then
			own[#own + 1] = { value = "spec" .. id, name = name }
		end
	end
	if #own > 0 then
		items[#items + 1] = { header = true, name = "Your Specs" }
		for _, it in ipairs(own) do
			items[#items + 1] = it
		end
	end
	return items
end

local function SpecLabel()
	local key = SpecKey()
	for _, it in ipairs(SpecItems()) do
		if it.value == key then
			return it.name
		end
	end
	return key
end

local function IndLabel(ind)
	if not ind then
		return "No indicators"
	end
	return ind.name or (LabelOf(TYPES, ind.type or "icon") .. " " .. tostring(ind.id))
end

---------------------------------------------------------------------------
-- Spells (retail BMP_BuildAssignedFilters: Filters lanes + Extra Spells)
---------------------------------------------------------------------------
local function FilterNames(map)
	local RF = RFT()
	local names = {}
	for _, f in ipairs(RF.BM2_Filters()) do
		if map and map[f.id] then
			names[#names + 1] = f.name
		end
	end
	return names
end

local function LaneSet(ind, lane, fid, v)
	local mine, other = lane == "show" and "filters" or "negFilters", lane == "show" and "negFilters" or "filters"
	ind[mine] = ind[mine] or {}
	ind[mine][fid] = v or nil
	if v and ind[other] then
		ind[other][fid] = nil
	end
	if ind.negFilters and not next(ind.negFilters) then
		ind.negFilters = nil
	end
	ind.filters = ind.filters or {}
end

local function BuildSpells(p, ind)
	local RF = RFT()
	p:Section("Spells")
	p:LaneSelect("Filters", "Which buff filters this indicator shows. Left box: show the filter's spells; red box: hide them.",
		function()
			local items = {
				{ action = function()
					filterSel = nil
					mode = "filters"
					Rebuild()
				end, name = "Edit Filters" },
				{ header = true, name = "Show", rightLabel = "Hide" },
			}
			for _, f in ipairs(RF.BM2_Filters()) do
				items[#items + 1] = { value = f.id, name = f.name, twoLane = true }
			end
			return items
		end,
		function(v) return ind.filters and ind.filters[v] and true or false end,
		function(v) LaneSet(ind, "show", v, not (ind.filters and ind.filters[v])) end,
		function(v) return ind.negFilters and ind.negFilters[v] and true or false end,
		function(v) LaneSet(ind, "hide", v, not (ind.negFilters and ind.negFilters[v])) end,
		function()
			local names = FilterNames(ind.filters)
			local hidden = #FilterNames(ind.negFilters)
			local txt = #names > 0 and table.concat(names, ", ") or "|cff888888None|r"
			if hidden > 0 then
				txt = txt .. ", " .. hidden .. " hidden"
			end
			return txt
		end)
	p:MultiSelect("Extra Spells", "Single spells this indicator always shows (on top of the filters).",
		function()
			local items = {
				{ action = function()
					AskSpellId("Add Spell ID", "Enter the spell ID to track on this indicator.", function(id)
						ind.spells = ind.spells or {}
						for _, x in ipairs(ind.spells) do
							if x == id then return end
						end
						ind.spells[#ind.spells + 1] = id
						Apply()
						Rebuild()
					end)
				end, name = "Custom Spell ID" },
			}
			local selected, selSet = {}, {}
			for _, id in ipairs(ind.spells or {}) do
				selSet[id] = true
				if GetSpellInfo(id) then
					selected[#selected + 1] = id
				end
			end
			local function ByName(a, b)
				return (GetSpellInfo(a) or "") < (GetSpellInfo(b) or "")
			end
			table.sort(selected, ByName)
			if #selected > 0 then
				items[#items + 1] = { header = true, name = "Selected" }
				for _, id in ipairs(selected) do
					items[#items + 1] = { value = id, name = SpellLabel(id) }
				end
			end
			local presets, names = {}, {}
			for _, id in ipairs(RF.BM2_AllPresetSpells()) do
				local name = GetSpellInfo(id)
				if name and not selSet[id] and not names[name] then
					names[name] = true
					presets[#presets + 1] = id
				end
			end
			table.sort(presets, ByName)
			if #presets > 0 then
				items[#items + 1] = { header = true, name = "Presets" }
				for _, id in ipairs(presets) do
					items[#items + 1] = { value = id, name = SpellLabel(id) }
				end
			end
			return items
		end,
		function(v)
			for _, x in ipairs(ind.spells or {}) do
				if x == v then return true end
			end
			return false
		end,
		function(v)
			ind.spells = ind.spells or {}
			for i = #ind.spells, 1, -1 do
				if ind.spells[i] == v then
					table.remove(ind.spells, i)
					return
				end
			end
			ind.spells[#ind.spells + 1] = v
		end,
		function()
			local n = 0
			for _, id in ipairs(ind.spells or {}) do
				if GetSpellInfo(id) then n = n + 1 end
			end
			return n > 0 and (n .. " spells") or "|cff888888None|r"
		end)
	local hidden = 0
	for _, id in ipairs(ind.spells or {}) do
		if not GetSpellInfo(id) then hidden = hidden + 1 end
	end
	if hidden > 0 then
		p:Paragraph(format("%d extra spells of this indicator do not exist on this client (retail-only) and are ignored.", hidden))
	end
end

---------------------------------------------------------------------------
-- Indicator settings
---------------------------------------------------------------------------
local function AnchorItems(ind)
	local items = { { value = 0, name = "None" } }
	for _, o in ipairs(Inds()) do
		if o ~= ind and (o.type == "icon" or o.type == "square") and o.anchorTo ~= ind.id then
			items[#items + 1] = { value = o.id, name = IndLabel(o) }
		end
	end
	return items
end

local function BuildGeneral(p, ind)
	p:Section("Indicator")
	p:Toggle("Enabled", "Show this indicator.", function() return ind.enabled ~= false end, function(v) ind.enabled = v end)
	p:Dropdown("Type", "What this indicator draws.", function() return Items(TYPES) end,
		G(ind, "type", "icon"), function() return LabelOf(TYPES, ind.type or "icon") end,
		function(v)
			ind.type = v
			if (v == "bar") and not ind.barHeight then
				ind.barWidth, ind.barHeight = 30, 4
			end
			Rebuild()
		end)
	p:Toggle("Own Only", "Only show buffs you cast yourself (or your pet).", function() return ind.ownOnly == true end,
		function(v) ind.ownOnly = v end)
	p:Dropdown("Show In", "Party frames in arenas and small raids count as Party; Friendly Boss frames count as Raid.",
		function() return Items(SHOW_IN) end,
		function() return (ind.showIn == "raid" or ind.showIn == "party") and ind.showIn or "both" end,
		function() return LabelOf(SHOW_IN, (ind.showIn == "raid" or ind.showIn == "party") and ind.showIn or "both") end,
		function(v) ind.showIn = (v == "raid" or v == "party") and v or nil end,
		nil, function() return ind.anchorTo ~= nil end)
end

local function BuildPlaced(p, ind)
	local t = ind.type or "icon"
	p:Section("Core")
	p:Dropdown("Position", "Where on the frame the indicator sits.", function() return Items(POSITIONS) end,
		G(ind, "position", "TOPLEFT"), function() return LabelOf(POSITIONS, ind.position or "TOPLEFT") end,
		function(v)
			ind.position = v
			if t ~= "bar" then
				ind.growDirection = DefaultGrow(v)
			end
		end, nil, function() return ind.anchorTo ~= nil end)
	p:Cog("Position Offset", {
		CogSlider(ind, "Offset X", "offsetX", 0, -50, 50),
		CogSlider(ind, "Offset Y", "offsetY", 0, -50, 50),
	}, { icon = "directions" })
	if t == "bar" then
		p:Slider("Width", "Bar length (ignored with Full Width Bar).", 2, 200, 1, G(ind, "barWidth", 30), W(ind, "barWidth"))
		p:Slider("Height", "Bar thickness.", 1, 60, 1, G(ind, "barHeight", 4), W(ind, "barHeight"))
		p:Toggle("Full Width Bar", "Span the whole health bar width.", function() return ind.barFullWidth == true end,
			function(v) ind.barFullWidth = v end)
		p:Toggle("Full Height Bar", "Span the whole health bar height.", function() return ind.barFullHeight == true end,
			function(v) ind.barFullHeight = v end)
		p:Dropdown("Orientation", "Fill direction of the bar.", function() return Items(ORIENT) end,
			G(ind, "orientation", "HORIZONTAL"), function() return LabelOf(ORIENT, ind.orientation or "HORIZONTAL") end,
			W(ind, "orientation"))
		p:Toggle("Reverse Fill", "Fill from the other end.", function() return ind.reverseFill == true end,
			function(v) ind.reverseFill = v end)
		p:Dropdown("Frame Level", "Draw order of the bar on the frame.", function() return Items(FRAMELVL) end,
			G(ind, "frameLevel", "behindBorders"), function() return LabelOf(FRAMELVL, ind.frameLevel or "behindBorders") end,
			W(ind, "frameLevel"))
		p:Blank()
		p:Section("Colors")
		p:ColorRow("Color", "Bar fill color.", ColGet(ind, "color", 12 / 255, 210 / 255, 157 / 255), ColSet(ind, "color"))
		p:Slider("Opacity", "Bar fill opacity.", 0, 100, 1, G(ind, "barColorOpacity", 100), W(ind, "barColorOpacity"))
		p:ColorRow("Background", "Bar background color.", ColGet(ind, "barBgColor", 0, 0, 0), ColSet(ind, "barBgColor"))
		p:Slider("Background Opacity", "Bar background opacity.", 0, 100, 1, G(ind, "barBgOpacity", 50), W(ind, "barBgOpacity"))
		return
	end
	p:Slider("Size", "Icon size.", 4, 60, 1, G(ind, "size", 18), W(ind, "size"))
	p:Dropdown("Growth Direction", "Where the next icon goes.", function() return Items(GROW) end,
		G(ind, "growDirection", "RIGHT"), function() return LabelOf(GROW, ind.growDirection or "RIGHT") end,
		W(ind, "growDirection"), nil, function() return ind.anchorTo ~= nil end)
	p:Slider("Spacing", "Gap between icons.", -5, 20, 1, G(ind, "spacing", 0), W(ind, "spacing"))
	p:Slider("Max Icons", "Most icons this indicator shows at once.", 1, 10, 1,
		function() return ind.maxIcons or 10 end, function(v) ind.maxIcons = v end)
	p:Dropdown("Anchor To", "Continue another indicator's row instead of an own position.",
		function() return AnchorItems(ind) end,
		function() return ind.anchorTo or 0 end,
		function()
			if not ind.anchorTo then return "None" end
			for _, o in ipairs(Inds()) do
				if o.id == ind.anchorTo then return IndLabel(o) end
			end
			return "None"
		end,
		function(v) ind.anchorTo = (v and v ~= 0) and v or nil end)
	p:Dropdown("Frame Level", "Draw order of the icons on the frame.", function() return Items(FRAMELVL) end,
		G(ind, "frameLevel", "medium"), function() return LabelOf(FRAMELVL, ind.frameLevel or "medium") end,
		W(ind, "frameLevel"))

	p:Section("Display")
	if t == "square" then
		p:ColorRow("Color", "Square color.", ColGet(ind, "color", 12 / 255, 210 / 255, 157 / 255), ColSet(ind, "color"))
	else
		p:Toggle("Hide Icons", "Hide the spell icon (texts and swipe stay).", function() return ind.hideIcon == true end,
			function(v) ind.hideIcon = v end)
		p:Slider("Opacity", "Icon opacity.", 0, 100, 1, G(ind, "iconOpacity", 100), W(ind, "iconOpacity"))
	end
	p:Slider("Border Width", "Border thickness in pixels (0 = no border).", 0, 4, 1, G(ind, "indBorderSize", 1), W(ind, "indBorderSize"))
	p:Swatch("Border Color", ColGet(ind, "indBorderColor", 0, 0, 0), ColSet(ind, "indBorderColor"))
	p:Toggle("Duration Swipe", "Darkening sweep as the buff runs out.", function() return ind.showDuration ~= false end,
		function(v) ind.showDuration = v end)
	p:Toggle("Duration Text", "Show the time left.", function() return ind.showDurationText == true end,
		function(v) ind.showDurationText = v end)
	p:Cog("Duration Text", {
		CogSlider(ind, "Text Size", "durationTextSize", 8, 6, 30),
		CogSlider(ind, "Offset X", "durationTextOffsetX", 0, -30, 30),
		CogSlider(ind, "Offset Y", "durationTextOffsetY", 0, -30, 30),
	}, { icon = "resize" })
	p:Swatch("Duration Text Color", ColGet(ind, "durationTextColor", 1, 1, 1), ColSet(ind, "durationTextColor"))
	p:Toggle("Enable Threshold Text", "Color the duration text when little time is left.", function() return ind.thresholdEnabled == true end,
		function(v) ind.thresholdEnabled = v end)
	p:Cog("Threshold Text", {
		CogSlider(ind, "Threshold (seconds)", "threshold", 3, 1, 30),
	})
	p:Swatch("Threshold Text Color", ColGet(ind, "thresholdColor", 1, 0.25, 0.25), ColSet(ind, "thresholdColor"))
	p:Toggle("Show Stacks", "Show the stack count.", function() return ind.showStacks ~= false end,
		function(v) ind.showStacks = v end)
	p:Cog("Stacks Text", {
		CogSlider(ind, "Text Size", "stacksTextSize", 8, 6, 30),
		CogSlider(ind, "Offset X", "stacksOffsetX", -1, -30, 30),
		CogSlider(ind, "Offset Y", "stacksOffsetY", 2, -30, 30),
	}, { icon = "resize" })
	p:Swatch("Stacks Text Color", ColGet(ind, "stacksTextColor", 1, 1, 1), ColSet(ind, "stacksTextColor"))
end

local function BuildEffect(p, ind)
	local t = ind.type
	p:Section("Display")
	p:Dropdown("Show When", "Effect indicators show while a tracked buff is present.",
		function() return { { value = "present", name = "When Any Present" } } end,
		function() return "present" end, function() return "When Any Present" end,
		function() ind.showWhen = "present" end)
	if t == "border" then
		p:ColorRow("Color", "Border color.", ColGet(ind, "color", 0.05, 0.82, 0.62), ColSet(ind, "color"))
		p:Slider("Border Width", "Border thickness in pixels.", 1, 8, 1, G(ind, "borderWidth", 2), W(ind, "borderWidth"))
		p:Slider("Opacity", "Border opacity.", 0, 100, 1, G(ind, "borderOpacity", 100), W(ind, "borderOpacity"))
	else
		p:ColorRow("Color", t == "healthcolor" and "Health bar tint while the buff is up." or "Health background color while the buff is up.",
			ColGet(ind, "color", 0, 1, 0), ColSet(ind, "color"))
		p:Slider("Opacity", "Tint opacity.", 0, 100, 1, G(ind, "opacity", 100), W(ind, "opacity"))
	end
end

local function BuildGlobal(p)
	local RF = RFT()
	local prof = RF and RF.Profile and RF.Profile()
	if not prof then
		return
	end
	p:Section("Buff Manager")
	p:Slider("Icon Zoom", "Crops the icon edges of every Buff Manager icon.", 0, 0.2, 0.01,
		function() return prof.bmIconZoom or 0.08 end, function(v) prof.bmIconZoom = v end)
	p:Toggle("Auto Resize Icons (Raid)", "Buff Manager sizes follow the raid frame size tier.",
		function() return prof.autoResizeTrackedBuffs ~= false end, function(v) prof.autoResizeTrackedBuffs = v end)
	p:Toggle("Auto Resize Icons (Party)", "Buff Manager sizes follow the party frame size.",
		function() return prof.partyAutoResizeTrackedBuffs ~= false end, function(v) prof.partyAutoResizeTrackedBuffs = v end)
end

local function BuildIndicators(p)
	local ind = Selected()
	if not ind then
		p:Section("Indicators")
		p:Paragraph("Create an indicator to get started.")
		BuildGlobal(p)
		return
	end
	BuildGeneral(p, ind)
	BuildSpells(p, ind)
	local t = ind.type or "icon"
	if t == "icon" or t == "square" or t == "bar" then
		BuildPlaced(p, ind)
	elseif t == "framealpha" then
		p:Section("Display")
		p:Paragraph("Frame Alpha was removed in retail 12.1 and does not render. Change the type or delete this indicator.")
	else
		BuildEffect(p, ind)
	end
	BuildGlobal(p)
end

---------------------------------------------------------------------------
-- Filter Editor (retail BMP_ShowFilterEditor modal as a page mode)
---------------------------------------------------------------------------
local function SelectedFilter()
	local RF = RFT()
	local list = RF.BM2_Filters()
	if filterSel then
		for _, f in ipairs(list) do
			if f.id == filterSel then return f end
		end
	end
	filterSel = list[1] and list[1].id or nil
	return list[1]
end

local function BuildFilters(p)
	local RF = RFT()
	local f = SelectedFilter()
	if not f then
		p:Paragraph("No filters yet. Use + Add Filter above.")
		return
	end
	p:Section(f.name)
	p:Dropdown("Search Spells", "Add a preset spell to this filter.",
		function()
			local items, names = {}, {}
			for _, id in ipairs(RF.BM2_AllPresetSpells()) do
				local name = GetSpellInfo(id)
				if name and not names[name] and f.spells[id] == nil then
					names[name] = true
					items[#items + 1] = { value = id, name = SpellLabel(id), sort = name }
				end
			end
			table.sort(items, function(a, b) return a.sort < b.sort end)
			return items
		end,
		function() return nil end, function() return "Search Spells" end,
		function(id)
			RF.BM2_AddCustomSpell(f.id, id)
			Rebuild()
		end)
	p:Button("Add Spell ID", "Add any spell by its ID.", "Add Spell ID", function()
		AskSpellId("Add Spell ID", "Enter the spell ID to add to this filter.", function(id)
			RF.BM2_AddCustomSpell(f.id, id)
			Apply()
			Rebuild()
		end)
	end)
	-- Rows grouped by class, deduplicated by name; unknown (retail-only) ids hidden.
	local groups, names, unknown, ids = {}, {}, 0, {}
	for id in pairs(f.spells) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local name = GetSpellInfo(id)
		if not name then
			unknown = unknown + 1
		elseif not names[name] then
			names[name] = true
			local class = (not f.custom[id] and RF.BM2_SpellClass[id]) or "Custom"
			groups[class] = groups[class] or {}
			table.insert(groups[class], id)
		end
	end
	local order = { "Custom" }
	for _, c in ipairs(CLASS_ORDER) do order[#order + 1] = c end
	order[#order + 1] = "ALL"
	local any = false
	for _, class in ipairs(order) do
		local list = groups[class]
		if list then
			any = true
			table.sort(list, function(a, b) return (GetSpellInfo(a) or "") < (GetSpellInfo(b) or "") end)
			local title = (class == "Custom" and "Custom") or (class == "ALL" and "All Classes")
				or (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class
			p:Section(title)
			for _, id in ipairs(list) do
				p:Toggle(SpellLabel(id), "Spell ID " .. id,
					function() return f.spells[id] == true end,
					function(v) RF.BM2_SetSpellState(f.id, id, v and true or false) end)
				if f.custom[id] then
					p:InlineIcon("Delete", ns.MEDIA .. "ui\\eui-close", function()
						RF.BM2_SetSpellState(f.id, id, nil)
						Rebuild()
					end)
				end
			end
		end
	end
	if not any then
		p:Paragraph("No spells yet. Add spell IDs above.")
	end
	if unknown > 0 then
		p:Paragraph(format("%d spells of this filter do not exist on this client (retail-only) and are hidden.", unknown))
	end
end

local function Build(p)
	local RF = RFT()
	if not (RF and RF.BM2_SpecInds) then
		p:Paragraph("The Buff Manager engine is not loaded.")
		return
	end
	if mode == "filters" then
		return BuildFilters(p)
	end
	return BuildIndicators(p)
end

---------------------------------------------------------------------------
-- Content header
---------------------------------------------------------------------------
local function PromptRename(ind)
	ns.ShowInputPopup({
		title = "Rename Indicator",
		message = "Enter a new name for this indicator:",
		text = IndLabel(ind),
		confirmText = "Rename",
		cancelText = "Cancel",
		onConfirm = function(text)
			text = text and strtrim(text) or ""
			if text ~= "" then
				ind.name = text
				Rebuild()
			end
		end,
	})
end

local function PromptDelete(ind)
	ns.ShowConfirmPopup({
		title = "Delete Indicator",
		message = format("Delete \"%s\"?", IndLabel(ind)),
		confirmText = "Delete",
		cancelText = "Cancel",
		onConfirm = function()
			local RF = RFT()
			RF.BM2_DeleteIndicator(ind, SpecKey())
			indSel = nil
			Apply()
			Rebuild()
		end,
	})
end

local function SetPreviewKey()
	local RF = RFT()
	if RF then
		RF.BM_PreviewKey = SpecKey()
		if RF.BM_UpdateAll then
			RF.BM_UpdateAll()
		end
	end
end

local function HeaderInds(page, host, width)
	local RF = RFT()
	local y = 16
	local DD_H, ICON, GAP = 30, 30, 6
	local SPEC_W, IND_W = 210, 240
	local total = SPEC_W + 12 + IND_W + GAP + ICON + GAP + ICON
	local x0 = floor((width - total) / 2)
	local specLabel = Text(host, 11, 0.45)
	specLabel:SetText("EDITING SPEC")
	specLabel:SetPoint("BOTTOMLEFT", host, "TOPLEFT", x0, -y + 2)
	local spec = page:HeaderDropdown(host, SPEC_W, DD_H, SpecItems, SpecKey, SpecLabel, function(v)
		specSel = v
		indSel = nil
		SetPreviewKey()
		Rebuild()
	end)
	spec:SetPoint("TOPLEFT", host, "TOPLEFT", x0, -y)
	local indLabel = Text(host, 11, 0.45)
	indLabel:SetText("INDICATOR")
	local inds = page:HeaderDropdown(host, IND_W, DD_H,
		function()
			local items = {}
			for _, ind in ipairs(Inds()) do
				local off = ind.enabled == false
				items[#items + 1] = { value = ind.id, name = IndLabel(ind) .. "  |cff888888" .. LabelOf(TYPES, ind.type or "icon")
					.. (off and " (off)" or "") .. "|r" }
			end
			return items
		end,
		function() return indSel end,
		function() return IndLabel(Selected()) end,
		function(v)
			indSel = v
			Rebuild()
		end)
	inds:SetPoint("LEFT", spec, "RIGHT", 12, 0)
	indLabel:SetPoint("BOTTOMLEFT", inds, "TOPLEFT", 0, 2)
	local has = Selected() ~= nil
	local rename = page:HeaderIconButton(host, ICON, "Interface\\Buttons\\UI-GuildButton-PublicNote-Up", 16, "Rename", function()
		local cur = Selected()
		if cur then PromptRename(cur) end
	end)
	rename:SetPoint("LEFT", inds, "RIGHT", GAP, 0)
	rename:SetAlpha(has and 1 or 0.3)
	local delete = page:HeaderIconButton(host, ICON, ns.MEDIA .. "ui\\eui-close", 16, "Delete", function()
		local cur = Selected()
		if cur then PromptDelete(cur) end
	end)
	delete:SetPoint("LEFT", rename, "RIGHT", GAP, 0)
	delete:SetAlpha(has and 1 or 0.3)
	y = y + DD_H + 12
	-- Row 2: Add New (type) | Edit Filters
	local addHolder = page:HeaderDropdown(host, 200, 28,
		function() return Items(TYPES) end,
		function() return nil end,
		function() return "+ Add New" end,
		function(v)
			local ind = RF.BM2_AddIndicator(v, SpecKey())
			if ind then
				indSel = ind.id
			end
			Apply()
			Rebuild()
		end)
	addHolder:SetPoint("TOPRIGHT", host, "TOP", -6, -y)
	local edit = FlatButton(host, 200, 28, "Edit Filters", function()
		filterSel = nil
		mode = "filters"
		Rebuild()
	end, "Edit the buff filters (named spell lists) the indicators use.")
	edit:SetPoint("TOPLEFT", host, "TOP", 6, -y)
	y = y + 28 + 14
	return y
end

local function PromptAddFilter()
	ns.ShowInputPopup({
		title = "Add Filter",
		message = "Name the new filter.",
		text = "",
		confirmText = "Add",
		cancelText = "Cancel",
		onConfirm = function(text)
			local RF = RFT()
			text = text and strtrim(text) or ""
			local f = RF.BM2_AddFilter(text ~= "" and text or nil)
			filterSel = f and f.id
			Rebuild()
		end,
	})
end

local function HeaderFilters(page, host, width)
	local RF = RFT()
	local y = 16
	local DD_H, ICON, GAP = 30, 30, 6
	local BACK_W, DD_W, ADD_W = 160, 240, 120
	local total = BACK_W + 12 + DD_W + GAP + ICON + GAP + ICON + 12 + ADD_W
	local x0 = floor((width - total) / 2)
	local back = FlatButton(host, BACK_W, DD_H, "< Back to Indicators", function()
		mode = "inds"
		Apply()
		Rebuild()
	end)
	back:SetPoint("TOPLEFT", host, "TOPLEFT", x0, -y)
	local dd = page:HeaderDropdown(host, DD_W, DD_H,
		function()
			local items = {}
			for _, f in ipairs(RF.BM2_Filters()) do
				items[#items + 1] = { value = f.id, name = f.name .. (f.preset and "  |cff888888(preset)|r" or "") }
			end
			return items
		end,
		function() return filterSel end,
		function()
			local f = SelectedFilter()
			return f and f.name or "No filters"
		end,
		function(v)
			filterSel = v
			Rebuild()
		end)
	dd:SetPoint("LEFT", back, "RIGHT", 12, 0)
	local f = SelectedFilter()
	local editable = f and not f.preset
	local rename = page:HeaderIconButton(host, ICON, "Interface\\Buttons\\UI-GuildButton-PublicNote-Up", 16, "Rename", function()
		local cur = SelectedFilter()
		if not cur or cur.preset then return end
		ns.ShowInputPopup({
			title = "Rename Filter",
			message = format("Enter a new name for \"%s\":", cur.name),
			text = cur.name,
			confirmText = "Rename",
			cancelText = "Cancel",
			onConfirm = function(text)
				RF.BM2_RenameFilter(cur.id, text and strtrim(text) or "")
				Rebuild()
			end,
		})
	end)
	rename:SetPoint("LEFT", dd, "RIGHT", GAP, 0)
	rename:SetAlpha(editable and 1 or 0.3)
	local delete = page:HeaderIconButton(host, ICON, ns.MEDIA .. "ui\\eui-close", 16, "Delete", function()
		local cur = SelectedFilter()
		if not cur or cur.preset then return end
		ns.ShowConfirmPopup({
			title = "Delete Filter",
			message = "Delete this filter? It is removed from every indicator using it.",
			confirmText = "Delete",
			cancelText = "Cancel",
			onConfirm = function()
				RF.BM2_DeleteFilter(cur.id)
				filterSel = nil
				Apply()
				Rebuild()
			end,
		})
	end)
	delete:SetPoint("LEFT", rename, "RIGHT", GAP, 0)
	delete:SetAlpha(editable and 1 or 0.3)
	local add = FlatButton(host, ADD_W, DD_H, "+ Add Filter", PromptAddFilter)
	add:SetPoint("LEFT", delete, "RIGHT", 12, 0)
	return y + DD_H + 14
end

local function BuildHeader(page, host, width)
	local RF = RFT()
	if not (RF and RF.BM2_SpecInds) then
		return 1
	end
	-- The preview frames show the edited spec's indicators while this tab shows.
	host:HookScript("OnShow", SetPreviewKey)
	host:HookScript("OnHide", function()
		local R = RFT()
		if R then
			R.BM_PreviewKey = nil
			if R.BM_UpdateAll then R.BM_UpdateAll() end
		end
	end)
	SetPreviewKey()
	if mode == "filters" then
		return HeaderFilters(page, host, width)
	end
	return HeaderInds(page, host, width)
end

ns.RFO_BuildBuffManagerPage = Build
ns.RFO_BuffManagerHeader = BuildHeader
ns.RFO_BuffManagerPageKey = PageKey

-- Retail entry point of the Filter Editor.
ns.BMP_ShowFilterEditor = function()
	filterSel = nil
	mode = "filters"
	Rebuild()
end
ns.BMP_ShowIndicators = function()
	mode = "inds"
	Rebuild()
end
