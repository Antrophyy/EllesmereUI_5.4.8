-- Settings pages of Core Addons > Resource Bars (EllesmereUI
-- EUI_ResourceBars_Options.lua and ResourceBars_Options\*: the same pages,
-- sections, labels, tooltips and keys). Pages: Class, Power and Health Bars
-- (with the class resource preview), Cast Bar (with the cast bar preview),
-- GCD Bar, Totem Bar.
-- The retail threshold popups are drawn here as a page of their own: the
-- "Settings" buttons switch the first page to the threshold editor of that
-- bar (Back returns), built from the normal rows.
-- Rows that need a retail-only feature are left out: Border Style textures,
-- Blizzard / Classic styles, Blizzard class art, Cooldown Manager buff and
-- spender colors, talent gates, Ironfur / Ignore Pain / Sweeping Strikes,
-- Enhance 5 Bar, Arcane Soul, Colored Empowered Stages, skyriding / housing
-- visibility, Anchor to Cursor, the swing timer.
-- Part of EllesmereUIOptions (load on demand); skipped when
-- EllesmereUIResourceBars is not loaded.

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUIResourceBars") then
	return
end
local ERB = ns.ERB
if not ERB or not ERB.db then
	return
end

local floor, max, min = math.floor, math.max, math.min

local function P()
	return ERB.db.profile
end
local function H() return P().health end
local function PW() return P().primary end
local function S() return P().secondary end
local function CB() return P().castBar end
local function GB() return P().gcdBar end
local function TB() return P().totemBar end

local function Get(tbl, key, default)
	return function()
		local v = tbl()[key]
		if v == nil then
			return default
		end
		return v
	end
end

local function Set(tbl, key)
	return function(v) tbl()[key] = v end
end

-- Percent slider over a 0..1 key.
local function GetPct(tbl, key, default)
	return function()
		local v = tbl()[key]
		if v == nil then v = default end
		return floor((v or 0) * 100 + 0.5)
	end
end
local function SetPct(tbl, key)
	return function(v) tbl()[key] = v / 100 end
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

local function Drop(p, label, tip, list, tbl, key, default, isDisabled, onSet)
	p:Dropdown(label, tip,
		function() return Items(list) end,
		function() local v = tbl()[key]; if v == nil then return default end; return v end,
		function() local v = tbl()[key]; if v == nil then v = default end; return LabelOf(list, v) end,
		function(v)
			tbl()[key] = v
			if onSet then onSet(v) end
		end,
		nil, isDisabled)
end

local function Req(name)
	return "This option requires " .. name .. " to be enabled"
end

-- Color getter / setter on flat r/g/b/a keys.
local function RGBA(tbl, prefix, dr, dg, db, da)
	return function()
		local t = tbl()
		return t[prefix .. "R"] or dr, t[prefix .. "G"] or dg, t[prefix .. "B"] or db, t[prefix .. "A"] or da
	end, function(r, g, b, a)
		local t = tbl()
		t[prefix .. "R"], t[prefix .. "G"], t[prefix .. "B"] = r, g, b
		if a ~= nil then
			t[prefix .. "A"] = a
		end
	end
end

local function Rebuild()
	if ns.RebuildSettingsPage then
		ns.RebuildSettingsPage()
	end
end

---------------------------------------------------------------------------
-- Value lists (retail labels)
---------------------------------------------------------------------------
local ORIENTATIONS = { { "HORIZONTAL", "Horizontal" }, { "VERTICAL_UP", "Vertical Up" }, { "VERTICAL_DOWN", "Vertical Down" } }
local STRATAS = { { "BACKGROUND", "Background" }, { "LOW", "Low" }, { "MEDIUM", "Medium" }, { "HIGH", "High" }, { "DIALOG", "Dialog" } }
local SHIFTS = { { "None", "None" }, { "Up", "Up" }, { "Down", "Down" } }
local ANCHORS = { { "LEFT", "Left" }, { "CENTER", "Center" }, { "RIGHT", "Right" } }
local GRAD_DIRS = { { "HORIZONTAL", "Horizontal" }, { "VERTICAL", "Vertical" } }
local HEALTH_TEXT = {
	{ "none", "None" }, { "perhp", "Health %" }, { "perhpnosign", "Health % (No Sign)" }, { "curhpshort", "Health #" },
	{ "perhpnum", "Health % | #" }, { "both", "Health # | %" },
}
local POWER_TEXT = { { "none", "None" }, { "smart", "Smart Text" }, { "curpp", "Power Value" }, { "perpp", "Power %" }, { "both", "Power Value | Power %" } }
local HASH_MODES = { { "percent", "%" }, { "value", "Value" } }
local DIRECTIONS = { { "from", "From" }, { "upto", "Up to" } }
local AMOUNT_MODES = { { "percent", "Percent" }, { "value", "Amount" } }

local function TextureItems()
	return ERB.TextureItems()
end

local function StrataItemsMatch()
	local items = { { value = "__match", name = "Match Main Strata" } }
	for _, s in ipairs(STRATAS) do
		items[#items + 1] = { value = s[1], name = s[2] }
	end
	return items
end

local function TextureItemsMatch()
	local items = { { value = "__match", name = "Match Main Texture" } }
	for _, it in ipairs(ERB.TextureItems()) do
		items[#items + 1] = it
	end
	return items
end

---------------------------------------------------------------------------
-- Visibility checklist (retail BuildVisibilityRow; one setting for all
-- three bars, stored on each)
---------------------------------------------------------------------------
local function Axis(key)
	for _, axis in ipairs(ERB.VIS_AXES) do
		if axis.key == key then
			return axis
		end
	end
end

local function VisItems()
	local items = {
		{ value = "state:never", name = "Never" },
		{ value = "state:always", name = "Always" },
		{ value = "state:mouseover", name = "Mouseover" },
		{ value = "match:all", name = "Match All Conditions" },
		{ value = "match:any", name = "Match Any Condition" },
	}
	for _, axis in ipairs(ERB.VIS_AXES) do
		items[#items + 1] = { value = "show:" .. axis.key, name = "Show: " .. axis.label }
		items[#items + 1] = { value = "hide:" .. axis.key, name = "Hide: " .. axis.label }
	end
	return items
end

-- stores(): the tables written; the first one is read.
local function VisibilityRow(p, label, stores, tip, isDisabled)
	p:MultiSelect(label, tip or "When the bars are shown. Never / Always / Mouseover is the base state; the Show conditions must match (all or any), a Hide condition always hides.",
		VisItems,
		function(value)
			local s = stores()[1]
			local kind, key = value:match("^(%a+):(.+)$")
			if kind == "state" then
				return ERB.VisBase(s) == key
			elseif kind == "match" then
				return (s.visibilityMatch or "all") == key
			end
			local axis = Axis(key)
			return ERB.VisFlag(s, kind == "show" and axis.show or axis.hide)
		end,
		function(value)
			local list = stores()
			local kind, key = value:match("^(%a+):(.+)$")
			local first = list[1]
			for _, s in ipairs(list) do
				if kind == "state" then
					ERB.SetVisBase(s, key)
				elseif kind == "match" then
					s.visibilityMatch = key ~= "all" and key or nil
				else
					local axis = Axis(key)
					local laneKey = kind == "show" and axis.show or axis.hide
					local otherKey = kind == "show" and axis.hide or axis.show
					local on = not ERB.VisFlag(first, laneKey)
					if s ~= first then
						on = ERB.VisFlag(first, laneKey)
					end
					ERB.SetVisFlag(s, laneKey, on)
					if on then
						ERB.SetVisFlag(s, otherKey, false)
					end
				end
			end
		end,
		function()
			local s = stores()[1]
			local base = ERB.VisBase(s)
			local text = base == "never" and "Never" or (base == "mouseover" and "Mouseover" or "Always")
			local n = 0
			for _, axis in ipairs(ERB.VIS_AXES) do
				if ERB.VisFlag(s, axis.show) or ERB.VisFlag(s, axis.hide) then
					n = n + 1
				end
			end
			if n > 0 and base ~= "never" then
				text = text .. " + " .. n .. (n == 1 and " condition" or " conditions")
			end
			return text
		end, isDisabled)
end

---------------------------------------------------------------------------
-- Druid per-form cogs (retail AddFormBarBtn / AddFormTextBtn)
---------------------------------------------------------------------------
local isDruid = select(2, UnitClass("player")) == "DRUID"
local FORMS = { { "mana", "Caster" }, { "rage", "Bear" }, { "energy", "Cat" }, { "moonkin", "Moonkin" } }

local function FormCog(p, tbl, field, title)
	if not isDruid then
		return
	end
	local rows = {}
	for _, f in ipairs(FORMS) do
		local key = f[1]
		rows[#rows + 1] = { type = "toggle", label = f[2],
			get = function() local t = tbl()[field]; return not (t and t[key]) end,
			set = function(v)
				local c = tbl()
				c[field] = c[field] or {}
				c[field][key] = (not v) and true or nil
			end }
	end
	p:Cog(title, rows, { tip = title })
end

---------------------------------------------------------------------------
-- Specs (threshold entries)
---------------------------------------------------------------------------
local specCache
local function AllSpecs()
	if specCache then
		return specCache
	end
	specCache = {}
	local classes = {}
	for classID = 1, (GetNumClasses and GetNumClasses() or 11) do
		local name, file = GetClassInfo(classID)
		if name and file then
			classes[#classes + 1] = { id = classID, name = name, file = file }
		end
	end
	table.sort(classes, function(a, b) return a.name < b.name end)
	for _, c in ipairs(classes) do
		local n = GetNumSpecializationsForClassID and GetNumSpecializationsForClassID(c.id) or 0
		for i = 1, n do
			local id, sname = GetSpecializationInfoForClassID(c.id, i)
			if id then
				specCache[#specCache + 1] = { id = id, name = sname, class = c.name, file = c.file }
			end
		end
	end
	return specCache
end

local function SpecInfo(id)
	for _, s in ipairs(AllSpecs()) do
		if s.id == id then
			return s
		end
	end
end

local function Hex(file)
	local r, g, b = ERB.ClassColor(file)
	return format("|cff%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

local function EntryLabel(entry)
	local parts = {}
	for _, id in ipairs(entry.specIDs or {}) do
		if id == 0 then
			parts[#parts + 1] = "All Specs"
		else
			local s = SpecInfo(id)
			parts[#parts + 1] = s and (Hex(s.file) .. s.name .. " " .. s.class .. "|r") or tostring(id)
		end
	end
	return #parts > 0 and table.concat(parts, ", ") or "No Spec"
end

local function Claimed(entries, id)
	for _, e in ipairs(entries) do
		for _, sid in ipairs(e.specIDs or {}) do
			if sid == id or sid == 0 then
				return true
			end
		end
	end
	return false
end

---------------------------------------------------------------------------
-- Page state: main page or a threshold editor ("health" / "primary" /
-- "secondary"); rev rebuilds the page after a structural change.
---------------------------------------------------------------------------
local editing
local rev = 0
local pendingSpecs = {}

local function PageKey()
	return (editing or "main") .. ":" .. rev
end

local function Restructure()
	rev = rev + 1
	Rebuild()
end

local function OpenEditor(which)
	editing = which
	wipe(pendingSpecs)
	Restructure()
end

local BAR_TITLES = { health = "Health Bar", primary = "Power Bar", secondary = "Class Resource" }

-- Is a class resource entry for a bar-type resource (Focus, Fury, Eclipse)?
local function EntryIsBarType(entry)
	local ids = entry.specIDs or {}
	if #ids == 0 then
		return false
	end
	for _, id in ipairs(ids) do
		if id == 0 then
			local res = ERB.GetSecondaryResource()
			return res and res.type == "bar" or false
		end
		if not ERB.BAR_TYPE_SPECS[id] then
			return false
		end
	end
	return true
end

local function BandRows(p, entry, isCount, isBar, defaultColor)
	p:Toggle("Multi-band Coloring", "Color the bar by ranges instead of a single threshold.\nUp to (<=) / From (>=)\nAny remaning values outside the bands will use fill color.\n|cff888888Bars can use % or actual value; pip resources use counts.|r",
		function() return entry.multiBandEnabled and true or false end,
		function(v)
			entry.multiBandEnabled = v
			if v and (not entry.bands or #entry.bands == 0) then
				local r, g, b, a = defaultColor()
				entry.bands = { { to = isCount and (entry.thresholdCount or 3) or (entry.thresholdPct or 30), r = r, g = g, b = b, a = a } }
			end
			Restructure()
		end)
	local function BandOff() return not entry.multiBandEnabled end
	p:Dropdown("Direction", "Up to: a band colors values at or below its number. From: at or above.",
		function() return Items(DIRECTIONS) end,
		function() return entry.bandReverse and "from" or "upto" end,
		function() return entry.bandReverse and "From" or "Up to" end,
		function(v) entry.bandReverse = (v == "from") end, nil, BandOff)
	if isBar then
		p:Dropdown("Values as", "Band numbers as a percent of the bar or as an amount.",
			function() return Items(AMOUNT_MODES) end,
			function() return entry.bandMode == "value" and "value" or "percent" end,
			function() return entry.bandMode == "value" and "Amount" or "Percent" end,
			function(v) entry.bandMode = v end, nil, BandOff)
		p:Blank()
	end
	if not entry.multiBandEnabled then
		return
	end
	entry.bands = entry.bands or {}
	local maxTo = isCount and 20 or 100
	if isBar and entry.bandMode == "value" then
		maxTo = 1000
	end
	for i = 1, #entry.bands do
		local band = entry.bands[i]
		p:Slider("Band " .. i .. ": " .. (entry.bandReverse and "From" or "Up to"), nil, 1, maxTo, 1,
			function() return band.to or 1 end,
			function(v)
				band.to = v
				table.sort(entry.bands, function(a, b) return (a.to or 0) < (b.to or 0) end)
			end)
		p:Swatch("Band Color", function() return band.r or 1, band.g or 1, band.b or 1, band.a or 1 end,
			function(r, g, b, a) band.r, band.g, band.b, band.a = r, g, b, a or band.a end, { alpha = true })
		p:Button("Remove Band " .. i, nil, "Remove", function()
			table.remove(entry.bands, i)
			Restructure()
		end)
	end
	p:WideButton(function() return "+ Add Band" end, nil, function() return false end, function()
		local last = entry.bands[#entry.bands]
		local r, g, b, a = defaultColor()
		entry.bands[#entry.bands + 1] = { to = last and ((last.to or 0) + 1) or 1, r = r, g = g, b = b, a = a }
		Restructure()
	end)
end

-- Threshold editor (retail BuildThresholdSettingsButton popup / the class
-- resource "Threshold & Hash Lines" page).
local function BuildThresholdEditor(p)
	local which = editing
	local bar = P()[which]
	local isClass = which == "secondary"
	bar.thresholdSpecs = bar.thresholdSpecs or {}
	local entries = bar.thresholdSpecs
	p:WideButton(function() return "Back" end, "Back to the bar settings.", function() return false end, function()
		editing = nil
		Restructure()
	end)
	local title = isClass and "Threshold & Hash Lines" or (which == "health" and "Health Bar Threshold" or "Power Bar Threshold")
	p:Section(title)
	if not isClass then
		p:Paragraph("Each entry colors the bar for the specs it names (a spec's own entry wins over All Specs). The bar's normal fill color shows outside the threshold.")
	else
		p:Paragraph("Each entry sets the threshold color and hash lines for the specs it names (a spec's own entry wins over All Specs).")
	end
	-- Spec picker + Add Specs.
	p:MultiSelect("Select a Spec...", "Pick the specs for a new entry, then click Add Specs.",
		function()
			local items = { { value = 0, name = "All Specs", locked = function() return Claimed(entries, 0) end,
				lockedTip = "Already used by another entry" } }
			for _, s in ipairs(AllSpecs()) do
				local id = s.id
				items[#items + 1] = { value = id, name = Hex(s.file) .. s.name .. " " .. s.class .. "|r",
					locked = function() return Claimed(entries, id) end, lockedTip = "Already used by another entry" }
			end
			return items
		end,
		function(id) return pendingSpecs[id] and true or false end,
		function(id)
			if id == 0 then
				wipe(pendingSpecs)
				pendingSpecs[0] = true
			else
				pendingSpecs[0] = nil
				pendingSpecs[id] = (not pendingSpecs[id]) and true or nil
			end
		end,
		function()
			local n = 0
			for _ in pairs(pendingSpecs) do n = n + 1 end
			if pendingSpecs[0] then return "All Specs" end
			return n == 0 and "Select a Spec..." or (n .. (n == 1 and " spec" or " specs"))
		end)
	p:Button("Add Specs", "Adds an entry for the picked specs.", "Add Specs", function()
		local ids = {}
		if pendingSpecs[0] then
			ids = { 0 }
		else
			for id in pairs(pendingSpecs) do ids[#ids + 1] = id end
			table.sort(ids)
		end
		if #ids == 0 then
			return
		end
		local e
		if isClass then
			e = { specIDs = ids, hashValues = "", hashWidth = 1, hashColorR = 1, hashColorG = 1, hashColorB = 1, hashColorA = 0.7,
				thresholdEnabled = true, thresholdPartialOnly = false,
				thresholdR = bar.thresholdR or 0x0c / 255, thresholdG = bar.thresholdG or 0xd2 / 255,
				thresholdB = bar.thresholdB or 0x9d / 255, thresholdA = bar.thresholdA or 1 }
			local isBar = EntryIsBarType(e)
			e.thresholdCount = isBar and 30 or 3
			local res = ERB.GetSecondaryResource()
			if isBar and res and res.power == "FOCUS_BAR" then
				e.thresholdReverse = true
			end
		else
			e = { specIDs = ids, thresholdEnabled = true, thresholdPct = 30, thresholdPartialOnly = false,
				thresholdR = 1, thresholdG = 0.2, thresholdB = 0.2, thresholdA = 1 }
			if which == "primary" then
				local _, token = UnitPowerType("player")
				for _, id in ipairs(ids) do
					local sid = GetSpecialization() and GetSpecializationInfo(GetSpecialization())
					if id == sid and (token == "MANA" or token == "FOCUS" or token == "ENERGY") then
						e.thresholdPartialOnly = true
					end
				end
			end
		end
		entries[#entries + 1] = e
		wipe(pendingSpecs)
		Restructure()
	end)

	-- Hash lines of the health / power bar (flat keys, retail BuildHashCog).
	if not isClass then
		local function B() return P()[which] end
		local function HashOff() return not B().hashEnabled end
		p:Section((which == "health" and "Health Bar" or "Power Bar") .. " Hash Lines")
		p:Toggle("Show Hash Lines", "Draw tick lines across the bar at positions you choose.", Get(B, "hashEnabled", false), Set(B, "hashEnabled"))
		p:Button("Positions", "Comma separated list, e.g. 25, 50, 75.", "Edit", function()
			ns.ShowInputPopup({ title = "Hash Line Positions", message = "Comma separated list, e.g. 25, 50, 75.",
				text = B().hashValues or "",
				onConfirm = function(text)
					local out = {}
					for s in (text or ""):gmatch("[^,]+") do
						local n = tonumber((s:gsub("%s", "")))
						if n and n >= 0 then out[#out + 1] = tostring(n) end
					end
					B().hashValues = table.concat(out, ", ")
					ERB:ApplyAll()
					if ns.RefreshSettings then ns.RefreshSettings() end
				end })
		end)
		Drop(p, "Mode", "Positions as a percent of the bar or as values.", HASH_MODES, B, "hashMode", "percent", HashOff)
		p:Slider("Thickness", nil, 1, 5, 1, Get(B, "hashWidth", 1), Set(B, "hashWidth"), HashOff)
		local hg, hs = RGBA(B, "hashColor", 1, 1, 1, 0.7)
		p:ColorRow("Color", nil, hg, hs, { alpha = true }, HashOff)
	end

	if #entries == 0 then
		p:Section("Entries")
		p:Paragraph("No entries yet. Pick specs above and click Add Specs.")
		return
	end
	for idx = 1, #entries do
		local entry = entries[idx]
		p:Section(idx .. ". " .. EntryLabel(entry))
		local function Off() return entry.thresholdEnabled == false or entry.multiBandEnabled end
		local function ThreshColor()
			return entry.thresholdR or bar.thresholdR or 1, entry.thresholdG or bar.thresholdG or 0.2,
				entry.thresholdB or bar.thresholdB or 0.2, entry.thresholdA or bar.thresholdA or 1
		end
		p:Toggle("Threshold Color", "Colors the bar with the threshold color past the threshold.",
			function() return entry.thresholdEnabled ~= false end,
			function(v) entry.thresholdEnabled = v end)
		p:Swatch("Threshold Color", ThreshColor,
			function(r, g, b, a) entry.thresholdR, entry.thresholdG, entry.thresholdB, entry.thresholdA = r, g, b, a or entry.thresholdA end,
			{ alpha = true, disabled = Off })
		if isClass then
			local isBar = EntryIsBarType(entry)
			local pctMode = isBar and (entry.thresholdMode or "percent") ~= "value"
			p:Slider(isBar and (pctMode and "Threshold %" or "Threshold") or "Threshold", nil, 1,
				isBar and (pctMode and 100 or 1000) or 20, 1,
				function() return entry.thresholdCount or (isBar and 30 or 3) end,
				function(v) entry.thresholdCount = v end, Off)
			p:Dropdown("Direction", "From: the threshold color at or above the threshold. Up to: at or below.",
				function() return Items(DIRECTIONS) end,
				function() return entry.thresholdReverse and "upto" or "from" end,
				function() return entry.thresholdReverse and "Up to" or "From" end,
				function(v) entry.thresholdReverse = (v == "upto") end, nil, Off)
			if isBar then
				p:Dropdown("Threshold as", nil, function() return Items({ { "percent", "Percent" }, { "value", "Value" } }) end,
					function() return entry.thresholdMode or "percent" end,
					function() return (entry.thresholdMode == "value") and "Value" or "Percent" end,
					function(v) entry.thresholdMode = v; Restructure() end, nil, Off)
			else
				p:Toggle("Only color at/above threshold", "Only available with the 'From' direction -- it highlights the pips at/above the threshold.",
					function() return entry.thresholdPartialOnly and true or false end,
					function(v) entry.thresholdPartialOnly = v end,
					function() return Off() or entry.thresholdReverse end)
			end
			p:Toggle("Recolor Text Instead Of Bar", nil,
				function() return entry.thresholdTextInstead and true or false end,
				function(v) entry.thresholdTextInstead = v end)
			-- Hash lines of this entry.
			local hashLabel = isBar and ((entry.hashMode == "percent") and "Hash at Percent" or "Hash at Value") or "Hash at Stack"
			p:Button(hashLabel, isBar and "(Ex: 25,50,75)" or "(Ex: 2,4)", (entry.hashValues and entry.hashValues ~= "") and entry.hashValues or "Edit", function()
				ns.ShowInputPopup({ title = hashLabel, message = isBar and "(Ex: 25,50,75)" or "(Ex: 2,4)",
					text = entry.hashValues or "",
					onConfirm = function(text)
						local out = {}
						for s in (text or ""):gmatch("[^,]+") do
							local n = tonumber((s:gsub("%s", "")))
							if n and n > 0 then out[#out + 1] = tostring(n) end
						end
						entry.hashValues = table.concat(out, ", ")
						ERB:ApplyAll()
						Restructure()
					end })
			end)
			p:Swatch("Hash Color", function() return entry.hashColorR or 1, entry.hashColorG or 1, entry.hashColorB or 1, entry.hashColorA or 0.7 end,
				function(r, g, b, a) entry.hashColorR, entry.hashColorG, entry.hashColorB, entry.hashColorA = r, g, b, a or entry.hashColorA end,
				{ alpha = true })
			p:Cog("Hash Line Style", {
				{ type = "toggle", label = "Position by percent", tip = "Bar-type resources only (pips use stack counts)",
				  get = function() return entry.hashMode == "percent" end,
				  set = function(v) entry.hashMode = v and "percent" or "value" end,
				  disabled = function() return not isBar end },
				{ type = "slider", label = "Hash Width", min = 1, max = 4, step = 1,
				  get = function() return entry.hashWidth or 1 end, set = function(v) entry.hashWidth = v end },
			})
			BandRows(p, entry, not isBar, isBar, ThreshColor)
		else
			p:Slider("Threshold %", nil, 1, 99, 1,
				function() return entry.thresholdPct or 30 end,
				function(v) entry.thresholdPct = v end, Off)
			if which == "primary" then
				p:Toggle("Threshold color below value", "Off: the threshold color above the threshold. On: below it.",
					function() return entry.thresholdPartialOnly and true or false end,
					function(v) entry.thresholdPartialOnly = v end, Off)
			end
			p:Toggle("Recolor Text Instead Of Bar", nil,
				function() return entry.thresholdTextInstead and true or false end,
				function(v) entry.thresholdTextInstead = v end)
			if which ~= "primary" then
				p:Blank()
			end
			BandRows(p, entry, false, true, ThreshColor)
		end
		p:WideButton(function() return "Delete Entry" end, "Removes this entry.", function() return false end, function()
			table.remove(entries, idx)
			Restructure()
		end)
	end
end

---------------------------------------------------------------------------
-- Shared bar rows (health / power)
---------------------------------------------------------------------------
local function BorderRows(p, tbl, offFn, name)
	p:Slider("Border Size", "Border size in pixels; for a textured style this is the size of its edge art.", 0, 32, 1,
		Get(tbl, "borderSize", 1), Set(tbl, "borderSize"), offFn)
	local bg, bs = RGBA(tbl, "border", 0, 0, 0, 1)
	p:Swatch("Border Color", bg, bs, { alpha = true, disabled = offFn })
	p:Cog("Border Options", {
		{ type = "toggle", label = "Show Behind", get = function() return tbl().borderBehind and true or false end,
		  set = function(v) tbl().borderBehind = v or nil end },
	}, { icon = "directions", disabled = offFn, disabledTip = Req(name) })
end

local function OpacityRow(p, tbl, offFn, name)
	p:Slider("Opacity", nil, 0, 100, 5, GetPct(tbl, "barAlpha", 1), SetPct(tbl, "barAlpha"), offFn)
	p:Cog("Out of Combat Opacity", {
		{ type = "toggle", label = "Fade Out of Combat", get = function() return tbl().oocFadeEnabled == true end,
		  set = function(v) tbl().oocFadeEnabled = v end },
		{ type = "slider", label = "Opacity", min = 0, max = 100, step = 1, get = GetPct(tbl, "oocAlpha", 0.5), set = SetPct(tbl, "oocAlpha"),
		  disabled = function() return not tbl().oocFadeEnabled end },
	}, { disabled = offFn, disabledTip = Req(name) })
	p:Sync("Apply Opacity to all Bars", function()
		local v = tbl().barAlpha or 1
		local pr = P()
		pr.health.barAlpha, pr.primary.barAlpha, pr.secondary.barAlpha = v, v, v
	end, function()
		local pr = P()
		return pr.health.barAlpha == pr.primary.barAlpha and pr.primary.barAlpha == pr.secondary.barAlpha
	end)
end

local function SizeRows(p, tbl, offFn, hMin, hMax, wMin)
	p:Slider("Height", nil, hMin or 1, hMax or 60, 1, Get(tbl, "height", 14), Set(tbl, "height"), offFn)
	p:Sync("Apply Height to all Bars", function()
		local v = tbl().height or 14
		local pr = P()
		pr.health.height, pr.primary.height, pr.secondary.pipHeight = v, v, v
	end, function()
		local pr = P()
		return pr.health.height == pr.primary.height and pr.primary.height == pr.secondary.pipHeight
	end)
	p:Slider("Width", nil, wMin or 50, 800, 1, Get(tbl, "width", 214), Set(tbl, "width"), offFn)
	p:Sync("Apply Width to all Bars", function()
		local v = tbl().width or 214
		local pr = P()
		pr.health.width, pr.primary.width, pr.secondary.pipWidth = v, v, v
	end, function()
		local pr = P()
		return pr.health.width == pr.primary.width and pr.primary.width == pr.secondary.pipWidth
	end)
end

local function FillRow(p, tbl, offFn, name, isHealth)
	p:Slider("Fill Color", "Opacity of the bar fill; below 100 the world shows through the fill instead of the background.", 0, 100, 1,
		Get(tbl, "fillOpacity", 100), Set(tbl, "fillOpacity"), offFn)
	local gg, gs = RGBA(tbl, "gradient", 0.2, 0.2, 0.8, 1)
	p:Swatch("Gradient End Color", gg, gs, { alpha = true,
		disabled = function() return offFn() or not tbl().gradientEnabled end })
	p:Swatch("Custom Colored",
		function() local t = tbl(); return t.fillR or 1, t.fillG or 1, t.fillB or 1, 1 end,
		function(r, g, b) local t = tbl(); t.fillR, t.fillG, t.fillB = r, g, b; t.customColored = true end,
		{ active = function() return tbl().customColored and true or false end,
		  onClick = function()
			if not tbl().customColored then
				tbl().customColored = true
				return true
			end
		  end, disabled = offFn })
	if isHealth then
		p:Swatch("Class Colored", function() local r, g, b = ERB.ClassColor(); return r, g, b, 1 end, function() end,
			{ readonly = true, active = function() return not tbl().customColored end,
			  onClick = function() tbl().customColored = false; return true end, disabled = offFn })
	else
		p:Swatch("Power Colored", function()
				local pt = ERB.GetPrimaryPowerType()
				local r, g, b = ERB.PowerColor(pt and ERB.PowerToken(pt) or "MANA")
				return r, g, b, 1
			end, function() end,
			{ readonly = true, active = function() return not tbl().customColored end,
			  onClick = function() tbl().customColored = false; return true end, disabled = offFn })
	end
	p:Cog("Fill Settings", {
		{ type = "toggle", label = "Enable Gradient", get = Get(tbl, "gradientEnabled", false), set = Set(tbl, "gradientEnabled") },
		{ type = "dropdown", label = "Gradient Direction", items = function() return Items(GRAD_DIRS) end,
		  get = Get(tbl, "gradientDir", "HORIZONTAL"), set = Set(tbl, "gradientDir") },
	}, { disabled = offFn, disabledTip = Req(name) })
end

local function TextRows(p, tbl, offFn, name, isHealth)
	local list = isHealth and HEALTH_TEXT or POWER_TEXT
	local label = isHealth and "Health Text" or "Power Text"
	Drop(p, label, nil, list, tbl, "textFormat", isHealth and "none" or "perpp", offFn)
	local cogRows = {}
	if not isHealth then
		cogRows[#cogRows + 1] = { type = "toggle", label = "Show %", get = function() return tbl().showPercent ~= false end,
			set = Set(tbl, "showPercent") }
	end
	cogRows[#cogRows + 1] = { type = "dropdown", label = "Anchor", tip = "Anchor the text inside the bar. The X/Y offsets move it from there.",
		items = function() return Items(ANCHORS) end, get = Get(tbl, "textAnchor", "CENTER"), set = Set(tbl, "textAnchor") }
	cogRows[#cogRows + 1] = { type = "slider", label = "X Offset", min = -100, max = 100, step = 1, get = Get(tbl, "textXOffset", 0), set = Set(tbl, "textXOffset") }
	cogRows[#cogRows + 1] = { type = "slider", label = "Y Offset", min = -100, max = 100, step = 1, get = Get(tbl, "textYOffset", 0), set = Set(tbl, "textYOffset") }
	p:Cog(label, cogRows, { icon = "directions", disabled = offFn, disabledTip = Req(name) })
	FormCog(p, tbl, "textDisabledForms", "Enable/Disable per Form")
	local function TextOff() return offFn() or (tbl().textFormat or "none") == "none" end
	p:Label("Text Color", nil, TextOff)
	p:Swatch("Custom Colored",
		function() local t = tbl(); return t.textFillR or 1, t.textFillG or 1, t.textFillB or 1, t.textFillA or 1 end,
		function(r, g, b, a) local t = tbl(); t.textFillR, t.textFillG, t.textFillB, t.textFillA = r, g, b, a or t.textFillA end,
		{ alpha = true, active = function() return tbl().textCustomColored ~= false end,
		  onClick = function()
			if tbl().textCustomColored == false then
				tbl().textCustomColored = true
				return true
			end
		  end, disabled = TextOff })
	p:Swatch(isHealth and "Class Colored" or "Power Colored", function()
			local r, g, b
			if isHealth then
				r, g, b = ERB.ClassColor()
			else
				local pt = ERB.GetPrimaryPowerType()
				r, g, b = ERB.PowerColor(pt and ERB.PowerToken(pt) or "MANA")
			end
			return r, g, b, 1
		end, function() end,
		{ readonly = true, active = function() return tbl().textCustomColored == false end,
		  onClick = function() tbl().textCustomColored = false; return true end, disabled = TextOff })
	p:Slider("Text Size", nil, 8, 24, 1, Get(tbl, "textSize", 11), Set(tbl, "textSize"), TextOff)
end

local function ThresholdButton(p, which, offFn)
	p:Button("Threshold Settings", "Per-spec threshold colors, color bands and (for the class resource) hash lines.", "Settings", function()
		if offFn and offFn() then
			return
		end
		OpenEditor(which)
	end)
end

---------------------------------------------------------------------------
-- Class, Power and Health Bars page
---------------------------------------------------------------------------
local function BuildBarDisplay(p)
	local pr = P()
	-- BAR DISPLAY -------------------------------------------------------------
	p:Section("Bar Display")
	VisibilityRow(p, "Visibility", function() local x = P(); return { x.secondary, x.health, x.primary } end)
	local smoothItems = { { value = "secondary", name = "Class Resource Bar" }, { value = "primary", name = "Power Bar" }, { value = "health", name = "Health Bar" } }
	p:MultiSelect("Smooth Bars", nil, function() return smoothItems end,
		function(k) return P()[k].smoothBars and true or false end,
		function(k) P()[k].smoothBars = not P()[k].smoothBars end,
		function()
			local on = {}
			for _, it in ipairs(smoothItems) do
				if P()[it.value].smoothBars then on[#on + 1] = it.name end
			end
			return #on == 0 and "None" or table.concat(on, ", ")
		end)

	p:Toggle("Dark Mode Class Resource", nil, Get(S, "darkTheme", false), function(v) S().darkTheme = v; Restructure() end)
	local function BgLabel()
		if pr.splitBg then return "Background (Class Resource)" end
		if pr.secondary.darkTheme then return "Background (Health & Power)" end
		return "Background"
	end
	p:Slider(BgLabel(), nil, 0, 100, 1,
		function()
			local x = P()
			local a = x.splitBg and (x.secondary.barBgA or 0.5) or (x.health.bgA or 0.75)
			return floor(a * 100 + 0.5)
		end,
		function(v)
			local x, a = P(), v / 100
			if x.splitBg then
				x.secondary.barBgA = a
			else
				x.health.bgA, x.primary.bgA, x.secondary.barBgA = a, a, a
			end
		end)
	p:Swatch("Background Color",
		function()
			local x = P()
			if x.splitBg then
				return x.secondary.barBgR or 0, x.secondary.barBgG or 0, x.secondary.barBgB or 0, 1
			end
			return x.health.bgR or 0.067, x.health.bgG or 0.067, x.health.bgB or 0.067, 1
		end,
		function(r, g, b)
			local x = P()
			if x.splitBg then
				x.secondary.barBgR, x.secondary.barBgG, x.secondary.barBgB = r, g, b
			else
				x.health.bgR, x.health.bgG, x.health.bgB = r, g, b
				x.primary.bgR, x.primary.bgG, x.primary.bgB = r, g, b
				x.secondary.barBgR, x.secondary.barBgG, x.secondary.barBgB = r, g, b
			end
		end)
	p:Cog("Background", {
		{ type = "toggle", label = "Choose background per bar", get = function() return P().splitBg == true end,
		  set = function(v)
			local x = P()
			x.splitBg = v and true or false
			if not v then
				local h = x.health
				x.primary.bgR, x.primary.bgG, x.primary.bgB, x.primary.bgA = h.bgR, h.bgG, h.bgB, h.bgA
				x.secondary.barBgR, x.secondary.barBgG, x.secondary.barBgB, x.secondary.barBgA = h.bgR, h.bgG, h.bgB, h.bgA
			end
			Restructure()
		  end },
	})
	if pr.splitBg then
		p:Slider("Health Background", nil, 0, 100, 1, GetPct(H, "bgA", 0.75), SetPct(H, "bgA"))
		local hg, hs = RGBA(H, "bg", 0.067, 0.067, 0.067, 1)
		p:Swatch("Health Background Color", hg, function(r, g, b) hs(r, g, b, nil) end)
		p:Slider("Power Background", nil, 0, 100, 1, GetPct(PW, "bgA", 0.75), SetPct(PW, "bgA"))
		local pg, ps = RGBA(PW, "bg", 0.067, 0.067, 0.067, 1)
		p:Swatch("Power Background Color", pg, function(r, g, b) ps(r, g, b, nil) end)
	end

	p:Dropdown("Texture", nil, TextureItems,
		function() return P().general.barTexture or "none" end,
		function() return ERB.TextureLabel(P().general.barTexture) end,
		function(v) P().general.barTexture = v end,
		{ texturePreview = true, previewPath = function(v) return ERB.TexturePath(v) end })
	p:Cog("Texture Settings", {
		{ type = "dropdown", label = "Health Texture", items = TextureItemsMatch,
		  get = function() local x = P(); return (x.splitTex and x.health.barTexture) or "__match" end,
		  set = function(v) ERB.SetBarTexture(P(), "health", v ~= "__match" and v or nil) end,
		  labelFn = function() local x = P(); local v = x.splitTex and x.health.barTexture; return v and ERB.TextureLabel(v) or "Match Main Texture" end },
		{ type = "dropdown", label = "Power Texture", items = TextureItemsMatch,
		  get = function() local x = P(); return (x.splitTex and x.primary.barTexture) or "__match" end,
		  set = function(v) ERB.SetBarTexture(P(), "primary", v ~= "__match" and v or nil) end,
		  labelFn = function() local x = P(); local v = x.splitTex and x.primary.barTexture; return v and ERB.TextureLabel(v) or "Match Main Texture" end },
	})
	Drop(p, "Frame Strata", "Controls the order that overlapping elements display in. Set higher to show above other elements.",
		STRATAS, function() return P().general end, "frameStrata", "MEDIUM")
	p:Cog("Frame Strata Settings", {
		{ type = "dropdown", label = "Health Strata", items = StrataItemsMatch,
		  get = function() return H().frameStrata or "__match" end,
		  set = function(v) H().frameStrata = v ~= "__match" and v or false end },
		{ type = "dropdown", label = "Power Strata", items = StrataItemsMatch,
		  get = function() return PW().frameStrata or "__match" end,
		  set = function(v) PW().frameStrata = v ~= "__match" and v or false end },
	})

	local function ExpandOn() return PW().enabled ~= false and PW().expandIfNoResource end
	p:Toggle("Expand Power Bar if No Resource", "When the class resource bar is not shown, this automatically adds the class resource height to the power bar.",
		Get(PW, "expandIfNoResource", false),
		function(v)
			PW().expandIfNoResource = v
			if v then S().shiftElementsIfNoResource = "None" end
		end,
		function()
			return PW().enabled == false or ((S().shiftElementsIfNoResource or "None") ~= "None" and not PW().expandIfNoResource)
		end)
	p:Cog("Expand Offset", {
		{ type = "slider", label = "Extra Y Offset", min = -50, max = 50, step = 1, get = Get(PW, "expandIfNoResourceExtraY", 0), set = Set(PW, "expandIfNoResourceExtraY") },
	}, { icon = "directions", disabled = function() return not ExpandOn() end, disabledTip = Req("Expand Power Bar if No Resource") })
	Drop(p, "Shift Elements if No Resource", "Shifts any elements anchored to the class resource bar up or down to offset the missing class resource.",
		SHIFTS, S, "shiftElementsIfNoResource", "None",
		function() return ExpandOn() and (S().shiftElementsIfNoResource or "None") == "None" end,
		function(v) if v ~= "None" then PW().expandIfNoResource = false end end)
	p:Cog("Shift Offset", {
		{ type = "slider", label = "Extra Y Offset", min = -50, max = 50, step = 1, get = Get(S, "shiftElementsIfNoResourceExtraY", 0), set = Set(S, "shiftElementsIfNoResourceExtraY") },
	}, { icon = "directions" })
	Drop(p, "Shift Elements if No Power", "Shifts any elements anchored to the power bar up or down to offset the missing power bar. Applies both when the Power Bar is disabled and for specs that have no power (for example, Beast Mastery and Marksmanship Hunters, whose Focus shows as the class resource bar).",
		SHIFTS, PW, "shiftElementsIfNoPower", "None")
	p:Cog("Shift Offset", {
		{ type = "slider", label = "Extra Y Offset", min = -50, max = 50, step = 1, get = Get(PW, "shiftElementsIfNoPowerExtraY", 0), set = Set(PW, "shiftElementsIfNoPowerExtraY") },
	}, { icon = "directions" })

	-- CLASS RESOURCE BAR ------------------------------------------------------
	p:Section("Class Resource Bar")
	local function ClassOff() return not S().enabled end
	p:Toggle("Show Class Resource", nil, Get(S, "enabled", true), function(v) S().enabled = v; Restructure() end)
	p:Cog("Class Resource", {
		{ type = "toggle", label = "Hide Power Bar if Resource", get = Get(S, "hidePowerIfResource", false), set = Set(S, "hidePowerIfResource") },
		{ type = "toggle", label = "Draw Above Other Bars", tip = "Draws the class resource bar above the health, power and GCD bar borders.",
		  get = Get(S, "raiseLevel", false), set = Set(S, "raiseLevel") },
	}, { disabled = ClassOff, disabledTip = Req("Class Resource") })
	FormCog(p, S, "barDisabledForms", "Enable/Disable Bar per Form")
	p:Dropdown("Orientation", nil, function() return Items(ORIENTATIONS) end,
		function() local v = S().pipOrientation or "HORIZONTAL"; if v == "VERTICAL" then v = "VERTICAL_DOWN" end; return v end,
		function() local v = S().pipOrientation or "HORIZONTAL"; if v == "VERTICAL" then v = "VERTICAL_DOWN" end; return LabelOf(ORIENTATIONS, v) end,
		Set(S, "pipOrientation"), nil, ClassOff)
	if S().enabled then
		p:Slider("Height", nil, 1, 60, 1, Get(S, "pipHeight", 20), Set(S, "pipHeight"), ClassOff)
		p:Sync("Apply Height to all Bars", function()
			local x = P(); local v = x.secondary.pipHeight or 20
			x.primary.height, x.health.height = v, v
		end, function() local x = P(); return x.primary.height == x.secondary.pipHeight and x.health.height == x.secondary.pipHeight end)
		p:Slider("Width", nil, 10, 800, 1, Get(S, "pipWidth", 214), Set(S, "pipWidth"), ClassOff)
		p:Sync("Apply Width to all Bars", function()
			local x = P(); local v = x.secondary.pipWidth or 214
			x.primary.width, x.health.width = v, v
		end, function() local x = P(); return x.primary.width == x.secondary.pipWidth and x.health.width == x.secondary.pipWidth end)

		p:Slider("Border Size", "Border size in pixels; for a textured style this is the size of its edge art.", 0, 32, 1,
			Get(S, "borderSize", 1), Set(S, "borderSize"), ClassOff)
		local sbg, sbs = RGBA(S, "border", 0, 0, 0, 1)
		p:Swatch("Border Color", sbg, sbs, { alpha = true, disabled = ClassOff })
		p:Cog("Pip Border", {
			{ type = "toggle", label = "Border on individual pips", tip = "Draws a border around each pip instead of the bar as a whole.",
			  get = Get(S, "borderOnPips", false), set = Set(S, "borderOnPips") },
			{ type = "toggle", label = "Background on individual pips", tip = "Draws the class resource background inside each pip so the gaps between pips stay clear.",
			  get = Get(S, "pipBgOnPips", false), set = Set(S, "pipBgOnPips"),
			  disabled = function() return not S().borderOnPips end },
		})
		p:Sync("Apply Border to all Bars", function()
			local x = P(); local s = x.secondary
			for _, t in ipairs({ x.primary, x.health }) do
				t.borderSize, t.borderR, t.borderG, t.borderB, t.borderA = s.borderSize, s.borderR, s.borderG, s.borderB, s.borderA
			end
		end, function()
			local x = P(); local s = x.secondary
			return x.primary.borderSize == s.borderSize and x.health.borderSize == s.borderSize
		end)
		p:Slider("Bar Spacing", nil, 0, 20, 1, Get(S, "pipSpacing", 1), Set(S, "pipSpacing"), ClassOff)
		local gpg, gps = RGBA(S, "gap", 0, 0, 0, 1)
		p:Swatch("Gap Color", gpg, gps, { alpha = true, disabled = function() return ClassOff() or not S().gapColorEnabled end })
		p:Cog("Gap Color", {
			{ type = "toggle", label = "Custom Gap Color", tip = "Enable the toggle to set a custom gap color",
			  get = function() return S().gapColorEnabled and true or false end, set = function(v) S().gapColorEnabled = v or nil end },
		}, { disabled = ClassOff })

		p:Slider("Empty Bar Overlay", nil, 0, 100, 5, GetPct(S, "bgA", 0.1), SetPct(S, "bgA"), ClassOff)
		local ovg, ovs = RGBA(S, "bg", 1, 1, 1, 1)
		p:Swatch("Empty Bar Overlay Color", ovg, function(r, g, b) ovs(r, g, b, nil) end, { disabled = ClassOff })
		OpacityRow(p, S, ClassOff, "Class Resource")

		p:Slider("Fill Color", "Opacity of the resource fill; below 100 the world shows through the fill instead of the background.", 0, 100, 1,
			Get(S, "fillOpacity", 100), Set(S, "fillOpacity"), ClassOff)
		local function SwOff() return ClassOff() or S().darkTheme end
		local function Mode()
			local s = S()
			if s.resourceColored then return "resource" end
			if s.classColored ~= false then return "class" end
			return "custom"
		end
		p:Swatch("Custom Colored", function() local s = S(); return s.fillR or 0.95, s.fillG or 0.9, s.fillB or 0.6, 1 end,
			function(r, g, b) local s = S(); s.fillR, s.fillG, s.fillB = r, g, b end,
			{ active = function() return Mode() == "custom" end,
			  onClick = function()
				if Mode() ~= "custom" then
					S().resourceColored, S().classColored = false, false
					return true
				end
			  end, disabled = SwOff })
		p:Swatch("Class Colored", function() local r, g, b = ERB.ClassColor(); return r, g, b, 1 end, function() end,
			{ readonly = true, active = function() return Mode() == "class" end,
			  onClick = function() S().resourceColored, S().classColored = false, true; return true end, disabled = SwOff })
		p:Swatch("Class Resource Color", function()
				local res = ERB.GetSecondaryResource()
				local r, g, b = ERB.ResolveSecondaryResourceColor(res and res.power)
				if not r then r, g, b = ERB.ClassColor() end
				return r, g, b, 1
			end, function() end,
			{ readonly = true, active = function() return Mode() == "resource" end,
			  onClick = function() S().resourceColored, S().classColored = true, true; return true end, disabled = SwOff })
		p:Cog("Fill Settings", {
			{ type = "toggle", label = "Darken Partially Filled Resources", tip = "Makes partially filled Burning Embers darker than completed ones.",
			  get = function() return S().darkenPartialPips ~= false end, set = Set(S, "darkenPartialPips") },
			{ type = "toggle", label = "Rune Type Colors", tip = "Death Knight: Blood, Unholy, Frost and Death runes in their own colors (with Class or Class Resource Color).",
			  get = function() return S().runesByType ~= false end, set = Set(S, "runesByType") },
		}, { disabled = ClassOff, disabledTip = Req("Class Resource") })

		local function TextOff() return ClassOff() or not S().showText end
		p:Toggle("Resource Text", nil, Get(S, "showText", true), function(v) S().showText = v end, ClassOff)
		p:Swatch("Resource Text Color", function() local s = S(); return s.textR or 1, s.textG or 1, s.textB or 1, 1 end,
			function(r, g, b) local s = S(); s.textR, s.textG, s.textB = r, g, b end, { disabled = TextOff })
		p:Cog("Resource Text", {
			{ type = "toggle", label = "Show %", get = function() return S().showPercent and true or false end, set = Set(S, "showPercent") },
			{ type = "toggle", label = "Only if Power Bar Hidden", tip = "Show the resource text only while the power bar is hidden - disabled, filtered off for this spec, a spec with no power, or hidden by \"Hide Power Bar if Resource\". Off = always show the text.",
			  get = Get(S, "showTextOnlyIfNoPower", false), set = Set(S, "showTextOnlyIfNoPower") },
			{ type = "slider", label = "Size", min = 8, max = 24, step = 1, get = Get(S, "textSize", 11), set = Set(S, "textSize") },
			{ type = "dropdown", label = "Anchor", tip = "Anchor the text inside the bar. The X/Y offsets move it from there.",
			  items = function() return Items(ANCHORS) end, get = Get(S, "textAnchor", "CENTER"), set = Set(S, "textAnchor") },
			{ type = "slider", label = "X Offset", min = -100, max = 100, step = 1, get = Get(S, "textXOffset", 0), set = Set(S, "textXOffset") },
			{ type = "slider", label = "Y Offset", min = -100, max = 100, step = 1, get = Get(S, "textYOffset", 0), set = Set(S, "textYOffset") },
		}, { disabled = TextOff, disabledTip = Req("Resource Text") })
		FormCog(p, S, "textDisabledForms", "Enable/Disable per Form")
		p:Button("Threshold & Hash Lines", "Per-spec threshold colors, color bands and hash lines of the class resource.", "Settings", function()
			OpenEditor("secondary")
		end)

		local class = select(2, UnitClass("player"))
		if class == "DEATHKNIGHT" then
			p:Toggle("Custom Recharge Color", "Choose the color of recharging runes instead of a dimmed version of the rune color.",
				Get(S, "runesCustomRecharge", false), Set(S, "runesCustomRecharge"), ClassOff)
			local rg, rs = RGBA(S, "runesRecharge", 0.5, 0.5, 0.5, 1)
			p:Swatch("Recharge Color", rg, rs, { alpha = true, disabled = function() return ClassOff() or not S().runesCustomRecharge end })
			p:Toggle("Simple Runes", "Show rune count in center and remove recharge text/animation", Get(S, "runesSimple", false), Set(S, "runesSimple"), ClassOff)
		elseif class == "HUNTER" then
			p:Toggle("Show Focus as Power Bar (BM/MM)", "When enabled, BM and MM specs show Focus as the standard power bar instead of a class resource bar.",
				Get(S, "hunterFocusAsPower", false), function(v) S().hunterFocusAsPower = v; Restructure() end)
			p:Blank()
		end
	end

	-- POWER BAR -----------------------------------------------------------------
	p:Section("Power Bar")
	local function PowOff() return PW().enabled == false end
	p:Toggle("Show Power Bar", nil, function() return PW().enabled ~= false end, function(v) PW().enabled = v; Restructure() end)
	FormCog(p, PW, "barDisabledForms", "Enable/Disable Bar per Form")
	p:Dropdown("Orientation", nil, function() return Items(ORIENTATIONS) end,
		function() return PW().orientation or P().general.orientation or "HORIZONTAL" end,
		function() return LabelOf(ORIENTATIONS, PW().orientation or P().general.orientation or "HORIZONTAL") end,
		Set(PW, "orientation"), nil, PowOff)
	if PW().enabled ~= false then
		SizeRows(p, PW, PowOff, 1, 100)
		BorderRows(p, PW, PowOff, "Power Bar")
		OpacityRow(p, PW, PowOff, "Power Bar")
		FillRow(p, PW, PowOff, "Power Bar", false)
		TextRows(p, PW, PowOff, "Power Bar", false)
		ThresholdButton(p, "primary", PowOff)
		if isDruid then
			-- Retail "Power Type" for Feral / Guardian: the form power or Mana.
			p:Dropdown("Power Type", "Feral and Guardian: show the form power (Energy / Rage) or Mana on the power bar.",
				function() return Items({ { "default", "Form Power" }, { "alt", "Mana" } }) end,
				function()
					local sid = GetSpecialization() and GetSpecializationInfo(GetSpecialization())
					local ov = PW().powerTypeOverride
					return (sid and ov and ov[sid]) and "alt" or "default"
				end,
				function()
					local sid = GetSpecialization() and GetSpecializationInfo(GetSpecialization())
					local ov = PW().powerTypeOverride
					return (sid and ov and ov[sid]) and "Mana" or "Form Power"
				end,
				function(v)
					local sid = GetSpecialization() and GetSpecializationInfo(GetSpecialization())
					if not sid then return end
					PW().powerTypeOverride = PW().powerTypeOverride or {}
					PW().powerTypeOverride[sid] = (v == "alt") and true or nil
				end, nil, function()
					local spec = GetSpecialization()
					return PowOff() or not (spec == 2 or spec == 3)
				end)
		else
			p:Blank()
		end
	end

	-- HEALTH BAR ----------------------------------------------------------------
	p:Section("Health Bar")
	local function HpOff() return not H().enabled end
	p:Toggle("Show Health Bar", nil, Get(H, "enabled", false), function(v) H().enabled = v; Restructure() end)
	FormCog(p, H, "barDisabledForms", "Enable/Disable Bar per Form")
	p:Dropdown("Orientation", nil, function() return Items(ORIENTATIONS) end,
		function() return H().orientation or P().general.orientation or "HORIZONTAL" end,
		function() return LabelOf(ORIENTATIONS, H().orientation or P().general.orientation or "HORIZONTAL") end,
		Set(H, "orientation"), nil, HpOff)
	if H().enabled then
		for _, k in ipairs(ERB.HEALTH_INDICATORS) do
			local order = k.key == "absorb" and ERB.ABSORB_STYLE_ORDER or ERB.HEAL_ABSORB_STYLE_ORDER
			local label = k.key == "absorb" and "Absorb Style" or "Heal Absorb Style"
			local function StyleItems()
				local items = {}
				for _, key in ipairs(order) do
					items[#items + 1] = { value = key, name = ERB.ABSORB_STYLE_NAMES[key] }
				end
				local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
				if lsm then
					for _, name in ipairs(lsm:List("statusbar")) do
						items[#items + 1] = { value = "sm:" .. name, name = name }
					end
				end
				return items
			end
			local function StyleOff() local v = H()[k.style]; return HpOff() or not v or v == "none" end
			p:Dropdown(label, nil, StyleItems,
				function() return H()[k.style] or "none" end,
				function()
					local v = H()[k.style] or "none"
					if v:sub(1, 3) == "sm:" then return v:sub(4) end
					return ERB.ABSORB_STYLE_NAMES[v] or v
				end,
				function(v) H()[k.style] = (v ~= "none") and v or nil end, nil, HpOff)
			p:Swatch(label .. " Color", function()
					local c = H()[k.color]
					return c and c.r or k.r, c and c.g or k.g, c and c.b or k.b, 1
				end,
				function(r, g, b) H()[k.color] = { r = r, g = g, b = b } end,
				{ disabled = function()
					local v = H()[k.style]
					return StyleOff() or v == "largeOutlinedStripes" or v == "largeOutlinedStripesR"
				end })
			p:Slider(k.key == "absorb" and "Absorb Opacity" or "Heal Absorb Opacity", nil, 5, 100, 1,
				function() return H()[k.opacity] or k.def end, function(v) H()[k.opacity] = v end, StyleOff)
		end
		SizeRows(p, H, HpOff, 1, 40)
		BorderRows(p, H, HpOff, "Health Bar")
		OpacityRow(p, H, HpOff, "Health Bar")
		FillRow(p, H, HpOff, "Health Bar", true)
		TextRows(p, H, HpOff, "Health Bar", true)
		ThresholdButton(p, "health", HpOff)
		p:Blank()
	end
end

---------------------------------------------------------------------------
-- Class resource preview (the page header)
---------------------------------------------------------------------------
local previewPips, previewFill = 3, 55

local function BuildPreviewHeader(page, host, width)
	if editing then
		return 0
	end
	local res = ERB.GetSecondaryResource()
	if not res or not S().enabled then
		return 0
	end
	local container = CreateFrame("Frame", nil, host)
	container:SetSize(width, 80)
	container:SetPoint("TOP", host, "TOP", 0, 0)
	local scaleHost = CreateFrame("Frame", nil, container)
	scaleHost:SetPoint("CENTER")
	scaleHost:SetSize(10, 10)
	local pipsF = {}
	local bgTex = scaleHost:CreateTexture(nil, "BACKGROUND")
	local fillTex = scaleHost:CreateTexture(nil, "ARTWORK")
	local edges = {}
	for i = 1, 4 do
		edges[i] = scaleHost:CreateTexture(nil, "OVERLAY", nil, 7)
	end
	local count = scaleHost:CreateFontString(nil, "OVERLAY")
	count:SetFont(ns.GetFontPath and ns.GetFontPath("resourceBars") or ns.FONT, 11, "OUTLINE")
	local function Update()
		local sp = S()
		local scale = UIParent:GetEffectiveScale() / max(0.01, host:GetEffectiveScale())
		scaleHost:SetScale(scale)
		local w, h = sp.pipWidth or 214, sp.pipHeight or 20
		local avail = (width - 40) / scale
		if w > avail then
			scaleHost:SetScale(scale * avail / w)
		end
		scaleHost:SetSize(w, h)
		local r, g, b = ERB.SecondaryBaseColor(sp, res)
		local bgR, bgG, bgB, bgA = sp.barBgR or 0, sp.barBgG or 0, sp.barBgB or 0, sp.barBgA or 0.5
		if sp.darkTheme then bgR, bgG, bgB, bgA = 0, 0, 0, 1 end
		bgTex:SetAllPoints()
		bgTex:SetTexture(bgR, bgG, bgB, bgA)
		local tex = ERB.TexturePath(P().general.barTexture)
		local fillA = (sp.fillOpacity or 100) / 100
		for _, pf in ipairs(pipsF) do pf.bg:Hide(); pf.fill:Hide() end
		fillTex:Hide()
		if res.type == "bar" then
			fillTex:SetTexture(tex)
			fillTex:SetVertexColor(r, g, b, fillA)
			fillTex:ClearAllPoints()
			fillTex:SetPoint("TOPLEFT")
			fillTex:SetPoint("BOTTOMLEFT")
			fillTex:SetWidth(max(1, w * previewFill / 100))
			fillTex:Show()
			count:SetText(sp.showPercent and (previewFill .. "%") or tostring(floor((res.max or 100) * previewFill / 100)))
		else
			local n = res.max or 5
			local lit = min(n, max(1, floor(n * previewPips / 5 + 0.5)))
			local spacing = sp.pipSpacing or 1
			local px = 768 / (ns.PhysicalHeight and ns.PhysicalHeight() or 1080) / UIParent:GetEffectiveScale()
			local gap = spacing * px
			local pw = (w - gap * (n - 1)) / n
			for i = 1, n do
				local pf = pipsF[i]
				if not pf then
					pf = { bg = scaleHost:CreateTexture(nil, "BORDER"), fill = scaleHost:CreateTexture(nil, "ARTWORK") }
					pipsF[i] = pf
				end
				local x = (i - 1) * (pw + gap)
				for _, t in ipairs({ pf.bg, pf.fill }) do
					t:ClearAllPoints()
					t:SetPoint("TOPLEFT", scaleHost, "TOPLEFT", x, 0)
					t:SetSize(pw, h)
				end
				pf.bg:SetTexture(sp.bgR or 1, sp.bgG or 1, sp.bgB or 1, sp.bgA or 0.1)
				pf.bg:Show()
				if i <= lit then
					pf.fill:SetTexture(tex)
					pf.fill:SetVertexColor(r, g, b, fillA)
					pf.fill:Show()
				end
			end
			count:SetText(tostring(lit))
		end
		local bs = (sp.borderSize or 0) * (768 / (ns.PhysicalHeight and ns.PhysicalHeight() or 1080) / UIParent:GetEffectiveScale())
		local br, bg2, bb, ba = sp.borderR or 0, sp.borderG or 0, sp.borderB or 0, sp.borderA or 1
		edges[1]:ClearAllPoints(); edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT"); edges[1]:SetHeight(max(0.01, bs))
		edges[2]:ClearAllPoints(); edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT"); edges[2]:SetHeight(max(0.01, bs))
		edges[3]:ClearAllPoints(); edges[3]:SetPoint("TOPLEFT"); edges[3]:SetPoint("BOTTOMLEFT"); edges[3]:SetWidth(max(0.01, bs))
		edges[4]:ClearAllPoints(); edges[4]:SetPoint("TOPRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT"); edges[4]:SetWidth(max(0.01, bs))
		for i = 1, 4 do
			edges[i]:SetTexture(br, bg2, bb, ba)
			edges[i]:SetShown(bs > 0 and not sp.borderOnPips)
		end
		count:ClearAllPoints()
		local anchor = sp.textAnchor or "CENTER"
		count:SetPoint(anchor, scaleHost, anchor, sp.textXOffset or 0, sp.textYOffset or 0)
		count:SetFont(ns.GetFontPath and ns.GetFontPath("resourceBars") or ns.FONT, sp.textSize or 11, "OUTLINE")
		count:SetTextColor(sp.textR or 1, sp.textG or 1, sp.textB or 1, 0.9)
		count:SetShown(sp.showText and res.type ~= "runes")
	end
	page:OnRefresh(Update)
	Update()
	return 80
end

---------------------------------------------------------------------------
-- Cast Bar page
---------------------------------------------------------------------------
local PREVIEW_ICONS = {
	"Interface\\Icons\\Spell_Nature_Lightning", "Interface\\Icons\\Spell_Fire_FlameBolt",
	"Interface\\Icons\\Spell_Frost_FrostBolt02", "Interface\\Icons\\Spell_Holy_FlashHeal",
	"Interface\\Icons\\Spell_Shadow_ShadowBolt", "Interface\\Icons\\Spell_Nature_HealingTouch",
}

local function BuildCastPreview(page, host, width)
	local c0 = CB()
	local container = CreateFrame("Frame", nil, host)
	container:SetSize(10, 10)
	container:SetPoint("CENTER", host, "TOP", 0, -40)
	local bg = container:CreateTexture(nil, "BACKGROUND")
	local fill = container:CreateTexture(nil, "ARTWORK")
	local spark = container:CreateTexture(nil, "OVERLAY")
	spark:SetTexture("Interface\\AddOns\\EllesmereUIResourceBars\\media\\cast_spark")
	spark:SetBlendMode("ADD")
	local icon = container:CreateTexture(nil, "ARTWORK")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:SetTexture(PREVIEW_ICONS[math.random(#PREVIEW_ICONS)])
	local edges = {}
	for i = 1, 4 do edges[i] = container:CreateTexture(nil, "OVERLAY", nil, 7) end
	local name = container:CreateFontString(nil, "OVERLAY")
	local timer = container:CreateFontString(nil, "OVERLAY")
	local frac = math.random(30, 85) / 100
	local function Update()
		local c = CB()
		local scale = UIParent:GetEffectiveScale() / max(0.01, host:GetEffectiveScale())
		local h = c.height or 20
		local iconW = (c.showIcon ~= false and not ERB.CastIconFree(c)) and h or 0
		local w = (c.width or 220)
		local total = w + iconW
		local avail = (width - 40) / scale
		container:SetScale(total > avail and scale * avail / total or scale)
		container:SetSize(total, h)
		local barLeft = (iconW > 0 and not c.iconOnRight) and iconW or 0
		bg:ClearAllPoints()
		bg:SetPoint("TOPLEFT", container, "TOPLEFT", barLeft, 0)
		bg:SetSize(w, h)
		bg:SetTexture(c.bgR or 0, c.bgG or 0, c.bgB or 0, c.bgA or 0.7)
		fill:ClearAllPoints()
		fill:SetPoint("TOPLEFT", container, "TOPLEFT", barLeft, 0)
		fill:SetSize(max(1, w * frac), h)
		fill:SetTexture(ERB.TexturePath(c.texture))
		local r, g, b = c.fillR or 0.898, c.fillG or 0.729, c.fillB or 0.267
		if c.classColored then r, g, b = ERB.ClassColor() end
		local fa = (c.fillOpacity or 100) / 100
		if c.gradientEnabled then
			fill:SetVertexColor(1, 1, 1, 1)
			if c.gradientDir == "VERTICAL" then
				fill:SetGradientAlpha("VERTICAL", c.gradientR or 0.2, c.gradientG or 0.2, c.gradientB or 0.8, (c.gradientA or 1) * fa, r, g, b, fa)
			else
				fill:SetGradientAlpha("HORIZONTAL", r, g, b, fa, c.gradientR or 0.2, c.gradientG or 0.2, c.gradientB or 0.8, (c.gradientA or 1) * fa)
			end
		else
			fill:SetVertexColor(r, g, b, fa)
		end
		spark:ClearAllPoints()
		spark:SetSize(8, h)
		spark:SetPoint("CENTER", fill, "RIGHT")
		spark:SetShown(c.showSpark and true or false)
		icon:ClearAllPoints()
		if c.showIcon ~= false then
			local size = (ERB.CastIconFree(c) and (c.iconSize or 0) > 0) and c.iconSize or h
			icon:SetSize(size, size)
			if ERB.CastIconFree(c) then
				if c.iconOnRight then
					icon:SetPoint("LEFT", container, "RIGHT", c.iconOffsetX or 0, c.iconOffsetY or 0)
				else
					icon:SetPoint("RIGHT", container, "LEFT", c.iconOffsetX or 0, c.iconOffsetY or 0)
				end
			else
				icon:SetPoint(c.iconOnRight and "TOPRIGHT" or "TOPLEFT", container, c.iconOnRight and "TOPRIGHT" or "TOPLEFT")
			end
			icon:Show()
		else
			icon:Hide()
		end
		local px = 768 / (ns.PhysicalHeight and ns.PhysicalHeight() or 1080) / UIParent:GetEffectiveScale()
		local bs = (c.borderSize or 0) * px
		edges[1]:ClearAllPoints(); edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT"); edges[1]:SetHeight(max(0.01, bs))
		edges[2]:ClearAllPoints(); edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT"); edges[2]:SetHeight(max(0.01, bs))
		edges[3]:ClearAllPoints(); edges[3]:SetPoint("TOPLEFT"); edges[3]:SetPoint("BOTTOMLEFT"); edges[3]:SetWidth(max(0.01, bs))
		edges[4]:ClearAllPoints(); edges[4]:SetPoint("TOPRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT"); edges[4]:SetWidth(max(0.01, bs))
		for i = 1, 4 do
			edges[i]:SetTexture(c.borderR or 0, c.borderG or 0, c.borderB or 0, c.borderA or 1)
			edges[i]:SetShown(bs > 0)
		end
		local font = ns.GetFontPath and ns.GetFontPath("resourceBars") or ns.FONT
		local flag = ns.GetFontOutlineFlag and ns.GetFontOutlineFlag("resourceBars") or "OUTLINE"
		name:SetFont(font, c.spellTextSize or 11, flag)
		timer:SetFont(font, c.timerSize or 11, flag)
		name:ClearAllPoints()
		timer:ClearAllPoints()
		local function Pt(side)
			if side == "center" then return "CENTER", 0 end
			if side == "left" then return "LEFT", 4 end
			return "RIGHT", -4
		end
		local np, nx = Pt(c.spellTextSide or "left")
		name:SetPoint(np, bg, np, nx + (c.spellTextX or 0), c.spellTextY or 0)
		name:SetText("Spell Name")
		name:SetTextColor(c.spellTextR or 1, c.spellTextG or 1, c.spellTextB or 1, c.spellTextA or 1)
		name:SetShown(c.showSpellText ~= false)
		local tp, tx = Pt(c.timerSide or "right")
		timer:SetPoint(tp, bg, tp, tx + (c.timerX or 0), c.timerY or 0)
		if c.showTotalDuration then
			timer:SetText(format("%.1f / %.1f", 3 * frac, 3))
		else
			timer:SetText(format("%.1f", 3 * (1 - frac)))
		end
		timer:SetTextColor(c.timerR or 1, c.timerG or 1, c.timerB or 1, c.timerA or 1)
		timer:SetShown(c.showTimer ~= false)
		container:SetShown(c.enabled and true or false)
	end
	page:OnRefresh(Update)
	Update()
	return 80
end

local function BuildCastBar(p)
	local function Off() return not CB().enabled end
	local req = Req("Player Cast Bar")
	p:Section("Layout")
	p:Toggle("Enable Player Cast Bar", nil, Get(CB, "enabled", true), Set(CB, "enabled"))
	Drop(p, "Frame Strata", "Controls the order that overlapping elements display in. Set higher to show above other elements.",
		STRATAS, CB, "frameStrata", "MEDIUM", Off)
	p:Slider("Height", nil, 1, 60, 1, Get(CB, "height", 20), Set(CB, "height"), Off)
	p:Slider("Width", nil, 50, 800, 1, Get(CB, "width", 220), Set(CB, "width"), Off)
	p:Toggle("Show Spell Icon", nil, function() return CB().showIcon ~= false end, Set(CB, "showIcon"), Off)
	p:Cog("Spell Icon Settings", {
		{ type = "toggle", label = "Icon on Right", tip = "Attach the spell icon to the right of the cast bar instead of the left.",
		  get = Get(CB, "iconOnRight", false), set = Set(CB, "iconOnRight") },
		{ type = "toggle", label = "Show Icon Divider", tip = "Draw a 1px divider between the spell icon and the cast bar, matching the border color.",
		  get = Get(CB, "showIconDivider", false), set = Set(CB, "showIconDivider"),
		  disabled = function() return ERB.CastIconFree(CB()) end },
		{ type = "slider", label = "Icon Size", tip = "0 matches the bar height. Any other size or offset detaches the icon from the bar.",
		  min = 0, max = 64, step = 1, get = Get(CB, "iconSize", 0), set = Set(CB, "iconSize") },
		{ type = "slider", label = "Offset X", min = -100, max = 100, step = 1, get = Get(CB, "iconOffsetX", 0), set = Set(CB, "iconOffsetX") },
		{ type = "slider", label = "Offset Y", min = -100, max = 100, step = 1, get = Get(CB, "iconOffsetY", 0), set = Set(CB, "iconOffsetY") },
	}, { disabled = function() return Off() or CB().showIcon == false end, disabledTip = req })
	p:Toggle("Show Spark", nil, Get(CB, "showSpark", true), Set(CB, "showSpark"), Off)
	p:Toggle("Always Show", "Keep the cast bar visible (sitting empty) when you are not casting, instead of hiding it.",
		Get(CB, "alwaysShow", false), Set(CB, "alwaysShow"), Off)
	p:Blank()

	p:Section("Display")
	p:Slider("Border Size", "Border size in pixels; for a textured style this is the size of its edge art.", 0, 32, 1,
		Get(CB, "borderSize", 1), Set(CB, "borderSize"), Off)
	local cbg, cbs = RGBA(CB, "border", 0, 0, 0, 1)
	p:Swatch("Border Color", cbg, cbs, { alpha = true, disabled = function() return Off() or (CB().borderSize or 0) == 0 end })
	p:Slider("Background", nil, 0, 100, 1, GetPct(CB, "bgA", 0.7), SetPct(CB, "bgA"), Off)
	local bgg, bgs = RGBA(CB, "bg", 0, 0, 0, 0.7)
	p:Swatch("Background Color", bgg, function(r, g, b) bgs(r, g, b, nil) end, { disabled = Off })
	p:Slider("Fill Color", "Opacity of the bar fill; below 100 the world shows through the fill instead of the background.", 0, 100, 1,
		Get(CB, "fillOpacity", 100), Set(CB, "fillOpacity"), Off)
	local gg, gs = RGBA(CB, "gradient", 0.2, 0.2, 0.8, 1)
	p:Swatch("Gradient End Color", gg, gs, { alpha = true, disabled = function() return Off() or not CB().gradientEnabled end })
	p:Swatch("Custom Colored", function() local c = CB(); return c.fillR or 0.898, c.fillG or 0.729, c.fillB or 0.267, 1 end,
		function(r, g, b) local c = CB(); c.fillR, c.fillG, c.fillB = r, g, b; c.classColored = false end,
		{ active = function() return not CB().classColored end,
		  onClick = function() if CB().classColored then CB().classColored = false; return true end end, disabled = Off })
	p:Swatch("Class Colored", function() local r, g, b = ERB.ClassColor(); return r, g, b, 1 end, function() end,
		{ readonly = true, active = function() return CB().classColored and true or false end,
		  onClick = function() CB().classColored = true; return true end, disabled = Off })
	p:Cog("Fill Settings", {
		{ type = "toggle", label = "Enable Gradient", get = Get(CB, "gradientEnabled", false), set = Set(CB, "gradientEnabled") },
		{ type = "dropdown", label = "Gradient Direction", items = function() return Items(GRAD_DIRS) end,
		  get = Get(CB, "gradientDir", "HORIZONTAL"), set = Set(CB, "gradientDir") },
		{ type = "toggle", label = "Gray When Out of Range", tip = "Grays the fill while your target is out of range of the spell being cast.",
		  get = function() return CB().outOfRangeGray == true end, set = Set(CB, "outOfRangeGray") },
	}, { disabled = Off, disabledTip = req })
	p:Dropdown("Bar Texture", nil, TextureItems, Get(CB, "texture", "none"),
		function() return ERB.TextureLabel(CB().texture) end, Set(CB, "texture"),
		{ texturePreview = true, previewPath = function(v) return ERB.TexturePath(v) end }, Off)
	local SPELL_SIDES = { { "none", "None" }, { "left", "Left" }, { "right", "Right" }, { "center", "Center" } }
	p:Dropdown("Spell Text", nil, function() return Items(SPELL_SIDES) end,
		function() return CB().showSpellText == false and "none" or (CB().spellTextSide or "left") end,
		function() return LabelOf(SPELL_SIDES, CB().showSpellText == false and "none" or (CB().spellTextSide or "left")) end,
		function(v)
			if v == "none" then CB().showSpellText = false else CB().showSpellText = true; CB().spellTextSide = v end
		end, nil, Off)
	local function SpellOff() return Off() or CB().showSpellText == false end
	local stg, sts = RGBA(CB, "spellText", 1, 1, 1, 1)
	p:Swatch("Spell Text Color", stg, sts, { alpha = true, disabled = SpellOff })
	p:Cog("Spell Text Settings", {
		{ type = "slider", label = "Text Size", min = 8, max = 24, step = 1, get = Get(CB, "spellTextSize", 11), set = Set(CB, "spellTextSize") },
		{ type = "slider", label = "X Offset", min = -100, max = 100, step = 1, get = Get(CB, "spellTextX", 0), set = Set(CB, "spellTextX") },
		{ type = "slider", label = "Y Offset", min = -100, max = 100, step = 1, get = Get(CB, "spellTextY", 0), set = Set(CB, "spellTextY") },
	}, { icon = "directions", disabled = SpellOff, disabledTip = req })
	local TIMER_SIDES = { { "none", "None" }, { "right", "Right" }, { "left", "Left" } }
	p:Dropdown("Duration Text", nil, function() return Items(TIMER_SIDES) end,
		function() return CB().showTimer == false and "none" or (CB().timerSide or "right") end,
		function() return LabelOf(TIMER_SIDES, CB().showTimer == false and "none" or (CB().timerSide or "right")) end,
		function(v)
			if v == "none" then CB().showTimer = false else CB().showTimer = true; CB().timerSide = v end
		end, nil, Off)
	local function TimerOff() return Off() or CB().showTimer == false end
	local tg, ts = RGBA(CB, "timer", 1, 1, 1, 1)
	p:Swatch("Duration Text Color", tg, ts, { alpha = true, disabled = TimerOff })
	p:Cog("Timer Settings", {
		{ type = "slider", label = "Timer Size", min = 8, max = 24, step = 1, get = Get(CB, "timerSize", 11), set = Set(CB, "timerSize") },
		{ type = "slider", label = "X Offset", min = -100, max = 100, step = 1, get = Get(CB, "timerX", 0), set = Set(CB, "timerX") },
		{ type = "slider", label = "Y Offset", min = -100, max = 100, step = 1, get = Get(CB, "timerY", 0), set = Set(CB, "timerY") },
	}, { icon = "directions", disabled = TimerOff, disabledTip = req })
	p:Toggle("Show Total Duration", "Shows elapsed / total duration (e.g. 0.4 / 2.0) instead of counting down from the total.",
		Get(CB, "showTotalDuration", false), Set(CB, "showTotalDuration"), TimerOff)

	p:Section("Tick Markers")
	local function MarksOff() return Off() or not CB().showChannelTicks end
	p:Toggle("Enable Tick Markers", nil, Get(CB, "showChannelTicks", true), function(v)
		local c = CB()
		c.showChannelTicks = v
		if v and not c.showTickMarks and not c.showLastTick then c.showTickMarks = true end
	end, Off)
	p:Toggle("Channel Ticks", "Shows tick marks on channeled spells. Only supported spells are shown.",
		Get(CB, "showTickMarks", true), Set(CB, "showTickMarks"), MarksOff)
	local tmg, tms = RGBA(CB, "tickMarks", 1, 1, 1, 0.7)
	p:Swatch("Channel Ticks Color", tmg, tms, { alpha = true, disabled = function() return MarksOff() or not CB().showTickMarks end })
	p:Toggle("Last Tick", "Highlights the final damage tick. Requires a supported channeled spell.",
		Get(CB, "showLastTick", false), Set(CB, "showLastTick"), MarksOff)
	local ltg, lts = RGBA(CB, "lastTick", 1, 0.82, 0, 0.95)
	p:Swatch("Last Tick Color", ltg, lts, { alpha = true, disabled = function() return MarksOff() or not CB().showLastTick end })
	p:Blank()

	p:Section("Latency")
	local function LatOff() return Off() or not CB().latencyEnabled end
	p:Toggle("Enable Latency Overlay", "Shows a colored overlay at the end of the cast bar representing your network latency for each spell. Helps you time spell queuing.",
		Get(CB, "latencyEnabled", false), Set(CB, "latencyEnabled"), Off)
	local lg, ls = RGBA(CB, "latency", 0.835, 0.29, 0.29, 1)
	p:Swatch("Latency Color", lg, ls, { alpha = true, disabled = LatOff })
	p:Toggle("Show Latency Text", "Appends your latency in milliseconds to the cast timer, e.g. 1.8 (42ms).",
		Get(CB, "latencyShowText", false), Set(CB, "latencyShowText"), LatOff)
end

---------------------------------------------------------------------------
-- GCD Bar page
---------------------------------------------------------------------------
local GCD_ORIENT = {
	{ "HORIZONTAL", "Horizontal (Right)" }, { "HORIZONTAL_LEFT", "Horizontal (Left)" },
	{ "VERTICAL_UP", "Vertical (Up)" }, { "VERTICAL_DOWN", "Vertical (Down)" },
}

local function BuildGCD(p)
	local function Off() return not GB().enabled end
	local req = Req("GCD Bar")
	p:Section("Layout")
	p:Toggle("Enable GCD Bar", "Shows a bar that fills over the global cooldown.", Get(GB, "enabled", false), Set(GB, "enabled"))
	p:Cog("GCD Bar Position", {
		{ type = "slider", label = "X Offset", min = -600, max = 600, step = 1,
		  get = function() local g = GB(); return (g.unlockPos and g.unlockPos.point) and (g.unlockPos.x or 0) or (g.anchorX or 0) end,
		  set = function(v) local g = GB(); if g.unlockPos and g.unlockPos.point then g.unlockPos.x = v else g.anchorX = v end end },
		{ type = "slider", label = "Y Offset", min = -600, max = 600, step = 1,
		  get = function() local g = GB(); return (g.unlockPos and g.unlockPos.point) and (g.unlockPos.y or 0) or (g.anchorY or -78) end,
		  set = function(v) local g = GB(); if g.unlockPos and g.unlockPos.point then g.unlockPos.y = v else g.anchorY = v end end },
	}, { icon = "directions", disabled = Off, disabledTip = req })
	Drop(p, "Frame Strata", "Controls the order that overlapping elements display in. Set higher to show above other elements.",
		STRATAS, GB, "frameStrata", "MEDIUM", Off)
	p:Slider("Height", nil, 1, 60, 1, Get(GB, "height", 12), Set(GB, "height"), Off)
	p:Slider("Width", nil, 50, 800, 1, Get(GB, "width", 220), Set(GB, "width"), Off)
	Drop(p, "Orientation", nil, GCD_ORIENT, GB, "orientation", "HORIZONTAL", Off)
	p:Toggle("Instance Only", "Only show the GCD bar while in a dungeon, raid, arena or battleground.", Get(GB, "instanceOnly", false), Set(GB, "instanceOnly"), Off)
	p:Toggle("Only Instant Casts", "Only show the GCD bar for instant-cast abilities. While hard-casting or channeling a spell, the bar stays hidden (the cast bar already shows that progress).",
		Get(GB, "instantOnly", false), Set(GB, "instantOnly"), Off)
	p:Toggle("Always Show", "Keep the GCD bar visible (sitting empty) when no global cooldown is running, instead of hiding it.",
		Get(GB, "alwaysShow", false), Set(GB, "alwaysShow"), Off)
	p:Cog("Always Show", {
		{ type = "toggle", label = "Show Fill Color When Idle", tip = "Show the bar full of its fill color while no global cooldown is running, instead of the background color.",
		  get = function() return GB().idleShowFill == true end, set = function(v) GB().idleShowFill = v or nil end },
	})

	p:Section("Display")
	p:Slider("Border Size", "Border size in pixels; for a textured style this is the size of its edge art.", 0, 32, 1,
		Get(GB, "borderSize", 1), Set(GB, "borderSize"), Off)
	local gbg, gbs = RGBA(GB, "border", 0, 0, 0, 1)
	p:Swatch("Border Color", gbg, gbs, { alpha = true, disabled = function() return Off() or (GB().borderSize or 0) == 0 end })
	p:Slider("Background", nil, 0, 100, 1, GetPct(GB, "bgA", 0.7), SetPct(GB, "bgA"), Off)
	local bgg, bgs = RGBA(GB, "bg", 0, 0, 0, 0.7)
	p:Swatch("Background Color", bgg, function(r, g, b) bgs(r, g, b, nil) end, { disabled = Off })
	p:Label("Color", nil, Off)
	local gg, gs = RGBA(GB, "gradient", 0.2, 0.2, 0.8, 1)
	p:Swatch("Gradient End Color", gg, gs, { alpha = true, disabled = function() return Off() or not GB().gradientEnabled end })
	local fg, fs = RGBA(GB, "fill", 0.267, 0.729, 0.898, 1)
	p:Swatch("Custom Colored", fg, function(r, g, b, a) fs(r, g, b, a); GB().classColored = false end,
		{ alpha = true, active = function() return not GB().classColored end,
		  onClick = function() if GB().classColored then GB().classColored = false; return true end end, disabled = Off })
	p:Swatch("Class Colored", function() local r, g, b = ERB.ClassColor(); return r, g, b, 1 end, function() end,
		{ readonly = true, active = function() return GB().classColored and true or false end,
		  onClick = function() GB().classColored = true; return true end, disabled = Off })
	p:Cog("Gradient Settings", {
		{ type = "toggle", label = "Enable Gradient", get = Get(GB, "gradientEnabled", false), set = Set(GB, "gradientEnabled") },
		{ type = "dropdown", label = "Gradient Direction", items = function() return Items(GRAD_DIRS) end,
		  get = Get(GB, "gradientDir", "HORIZONTAL"), set = Set(GB, "gradientDir") },
	}, { disabled = Off, disabledTip = req })
	p:Dropdown("Bar Texture", nil, TextureItems, Get(GB, "texture", "none"),
		function() return ERB.TextureLabel(GB().texture) end, Set(GB, "texture"),
		{ texturePreview = true, previewPath = function(v) return ERB.TexturePath(v) end }, Off)
	p:Toggle("Show Spark", "Show a small glowing spark that moves along the leading edge of the fill.", Get(GB, "showSpark", false), Set(GB, "showSpark"), Off)
	p:Toggle("Deplete Fill", "Start the bar full and drain it as the global cooldown elapses, instead of filling it up.", Get(GB, "depleteFill", false), Set(GB, "depleteFill"), Off)
	p:Blank()
end

---------------------------------------------------------------------------
-- Totem Bar page
---------------------------------------------------------------------------
local CLASS_ORDER = { "DEATHKNIGHT", "DRUID", "HUNTER", "MAGE", "MONK", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" }

local function BuildTotem(p)
	local function Off() return not TB().enabledClasses end
	local req = "Select a class above"
	p:Section("Layout")
	p:MultiSelect("Enabled Classes", "The totem bar shows for the classes picked here (the settings are shared by all characters).",
		function()
			local items = { { value = "NONE", name = "None (Disabled)" } }
			for _, cf in ipairs(CLASS_ORDER) do
				local name = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[cf]) or cf
				items[#items + 1] = { value = cf, name = Hex(cf) .. name .. "|r" }
			end
			return items
		end,
		function(key)
			local ec = TB().enabledClasses
			if key == "NONE" then return ec == nil end
			return ec and ec[key] and true or false
		end,
		function(key)
			local t = TB()
			if key == "NONE" then
				t.enabledClasses = nil
				return
			end
			t.enabledClasses = t.enabledClasses or {}
			t.enabledClasses[key] = (not t.enabledClasses[key]) and true or nil
			if next(t.enabledClasses) == nil then t.enabledClasses = nil end
		end,
		function()
			local ec = TB().enabledClasses
			if not ec then return "None (Disabled)" end
			local n = 0
			for _ in pairs(ec) do n = n + 1 end
			return n .. (n == 1 and " class" or " classes")
		end)
	p:Slider("Icon Size", nil, 16, 60, 1, Get(TB, "iconSize", 30), Set(TB, "iconSize"), Off)
	p:Cog("Icon Settings", {
		{ type = "slider", label = "Spacing", min = 0, max = 20, step = 1, get = Get(TB, "spacing", 2), set = Set(TB, "spacing") },
	}, { disabled = Off, disabledTip = req })
	p:Slider("Timer Size", nil, 6, 24, 1, Get(TB, "timerSize", 11), Set(TB, "timerSize"), function() return Off() or TB().showTimer == false end)
	p:Toggle("Show Timer", nil, function() return TB().showTimer ~= false end, Set(TB, "showTimer"), Off)
	p:Slider("Border Size", "Border size in pixels; for a textured style this is the size of its edge art.", 0, 32, 1,
		Get(TB, "borderSize", 1), Set(TB, "borderSize"), Off)
	local tbg, tbs = RGBA(TB, "border", 0, 0, 0, 1)
	p:Swatch("Border Color", tbg, tbs, { alpha = true, disabled = function() return Off() or (TB().borderSize or 0) == 0 end })
	p:Cog("Border Options", {
		{ type = "toggle", label = "Show Behind", get = function() return TB().borderBehind and true or false end, set = function(v) TB().borderBehind = v or nil end },
	}, { icon = "directions", disabled = Off, disabledTip = req })
	Drop(p, "Frame Strata", "Controls the order that overlapping elements display in. Set higher to show above other elements.",
		STRATAS, TB, "frameStrata", "MEDIUM", Off)
	Drop(p, "Orientation", nil, { { "HORIZONTAL", "Horizontal" }, { "VERTICAL", "Vertical" } }, TB, "orientation", "HORIZONTAL", Off)
	local GROWS = { { "", "Default" }, { "CENTER", "Center" }, { "LEFT", "Left" }, { "RIGHT", "Right" }, { "UP", "Up" }, { "DOWN", "Down" } }
	p:Dropdown("Grow Direction", "Which way the icons line up from the bar's edge. Horizontal: Right, Left or Center; Vertical: Down, Up or Center.",
		function() return Items(GROWS) end,
		function() return TB().growDirection or "" end,
		function() return LabelOf(GROWS, TB().growDirection or "") end,
		function(v) TB().growDirection = (v ~= "") and v or nil end, nil, Off)
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------
local function BuildMain(p)
	if editing then
		BuildThresholdEditor(p)
	else
		BuildBarDisplay(p)
	end
end

ns.RegisterSettingsModule({
	key = "resourceBars",
	name = "Resource Bars",
	group = "Core Addons",
	tabs = {
		{ key = "display", name = "Class, Power and Health Bars", description = "Custom class resource, health, and mana bar display.",
		  build = BuildMain, header = BuildPreviewHeader, pageKey = PageKey },
		{ key = "castBar", name = "Cast Bar", description = "Custom class resource, health, and mana bar display.",
		  build = BuildCastBar, header = BuildCastPreview },
		{ key = "gcdBar", name = "GCD Bar", description = "Custom class resource, health, and mana bar display.", build = BuildGCD },
		{ key = "totemBar", name = "Totem Bar", description = "Custom class resource, health, and mana bar display.", build = BuildTotem },
	},
	onEnter = function()
		previewPips, previewFill = math.random(3, 4), math.random(30, 80)
	end,
	reset = function()
		editing = nil
		ERB:Reset()
		Restructure()
	end,
	resetTip = "Set all Resource Bars settings back to the EllesmereUI defaults (positions too).",
})
