-------------------------------------------------------------------------------
--  EUI_RaidFrames_Options.lua: settings of Raid Frames (EllesmereUI Core
--  Addons > Raid Frames). Tabs in retail order: Raid Frames, Party Frames,
--  Buff Manager, Debuff Manager, Click Casting.
--
--  Port of retail EUI_RaidFrames_Options.lua and RaidFrames_Options\
--  FramesPages / VisualBars / VisualIndicators_Options.lua. Same sections,
--  labels, tooltips, value lists and saved keys. Retail-only rows are left
--  out (Blizzard / Classic / Party Frames kit styles, private auras,
--  targeted spells, ping marker, summon, FrameSort, WoW Forever missing
--  buffs, spec / condition overrides, preview eye icons, textured borders).
--
--  The Party Frames tab uses the same section builders as the Raid Frames
--  tab with a party context (retail SGet / SSet / SVal): a section the party
--  keeps its own settings for (partySyncSections[section] == false) reads
--  and writes "party_<key>"; a synced section is covered by a "Synced with
--  Raid Settings" overlay (click it to unsync).
--
--  Buff Manager, Debuff Manager and Click Casting are built by their own
--  option files (EllesmereUI.RFO_Build*Page).
-------------------------------------------------------------------------------
local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUIRaidFrames") then
	return
end
local ERF = ns.ERF
if not ERF or not ns.RegisterSettingsModule then
	return
end
local RF = ERF.RF

local floor, max, min = math.floor, math.max, math.min
local pairs, ipairs, type, tostring = pairs, ipairs, type, tostring

-- Builders and shared state live in this table (keeps the main chunk far
-- below the Lua 5.1 local limit).
local O = {}

local function P()
	return RF.Profile()
end

---------------------------------------------------------------------------
-- Value lists ({ value, label } arrays, retail order and labels)
---------------------------------------------------------------------------
O.POS = {
	{ "topleft", "Top Left" }, { "top", "Top" }, { "topright", "Top Right" },
	{ "left", "Left" }, { "center", "Center" }, { "right", "Right" },
	{ "bottomleft", "Bottom Left" }, { "bottom", "Bottom" }, { "bottomright", "Bottom Right" },
}
O.POS_NONE = {}
for i = 1, #O.POS do
	O.POS_NONE[i] = O.POS[i]
end
O.POS_NONE[#O.POS_NONE + 1] = { "none", "None" }

O.HEALTH_COLOR = {
	{ "class", "Class Color" }, { "classReactive", "Class Color Reactive" }, { "dark", "Dark Mode" },
	{ "classic", "Classic" }, { "custom", "Custom Color" }, { "customDynamic", "Custom Dynamic Colors" },
}
O.HEALTH_TEXT = {
	{ "none", "None" }, { "percent", "Percent" }, { "percentNoSign", "Percent (No Sign)" },
	{ "number", "Number" }, { "numberPercent", "Number | Percent" }, { "percentNumber", "Percent | Number" },
	{ "missing", "Missing Number" },
}
O.POWER_TEXT = {
	{ "none", "None" }, { "percent", "Percent" }, { "percentNoSign", "Percent (No Sign)" },
	{ "number", "Number" }, { "numberPercent", "Number | Percent" }, { "percentNumber", "Percent | Number" },
}
O.GROWTH = { { "DOWN", "Down" }, { "UP", "Up" }, { "RIGHT", "Right" }, { "LEFT", "Left" } }
O.GROUP_GROWTH = {
	{ "DOWN", "Down" }, { "UP", "Up" }, { "RIGHT", "Right" }, { "LEFT", "Left" },
	{ "DOWNRIGHT", "Down and then Right" },
}
O.SELF_POS = { { "none", "Default" }, { "first", "First" }, { "last", "Last" } }

-- Absorb styles: retail labels (the "blizzard" key is labeled Classic WoW).
-- Retail-only compound styles (Default Blizz Frames, Blizzard Raid Bar) do
-- not exist on 5.4.8 and are left out of the lists.
O.ABSORB_LABEL = {
	none = "None", striped = "Striped", stripedReversed = "Striped Reversed",
	stripedThick = "Striped Thick", stripedThickR = "Striped Thick Reversed", clean = "Clean (Flat)",
	blizzard = "Classic WoW", largeOutlinedStripes = "Large Outlined Stripes",
	largeOutlinedStripesR = "Large Outlined Stripes R", largeStripes = "Large Stripes",
	largeStripesR = "Large Stripes R", maxHealthStripes = "Max Health Stripes",
	pixelsShield = "Pixels Shield", pixelsShieldEdge = "Pixels Shield Edge", pixelsShieldFill = "Pixels Shield Fill",
}
O.MAX_HEALTH_ORDER = {
	"none", "maxHealthStripes", "striped", "stripedReversed", "stripedThick", "stripedThickR", "clean",
	"blizzard", "largeOutlinedStripes", "largeOutlinedStripesR", "largeStripes", "largeStripesR", "pixelsShield",
}

-- MoP classes (sort lists). Names from the client, alphabetical default.
O.CLASS_TOKENS = {
	"DEATHKNIGHT", "DRUID", "HUNTER", "MAGE", "MONK", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR",
}
O.ROLE_LABELS = { TANK = "Tank", HEALER = "Healer", DAMAGER = "DPS" }

---------------------------------------------------------------------------
-- Generic helpers
---------------------------------------------------------------------------
local function Items(list)
	if type(list) == "function" then
		list = list()
	end
	local items = {}
	for i = 1, #list do
		local e = list[i]
		if e == "---" then
			items[#items + 1] = { separator = true, name = "" }
		else
			items[#items + 1] = { value = e[1], name = e[2], tip = e[3] }
		end
	end
	return items
end
O.Items = Items

local function LabelOf(list, value)
	if type(list) == "function" then
		list = list()
	end
	for i = 1, #list do
		if type(list[i]) == "table" and list[i][1] == value then
			return list[i][2]
		end
	end
	return tostring(value or "")
end
O.LabelOf = LabelOf

-- LOCALIZED_CLASS_NAMES_MALE is a FrameXML global (not in the 5.4.8 API
-- file): read guarded, English names as the fallback.
O.CLASS_NAMES = {
	DEATHKNIGHT = "Death Knight", DRUID = "Druid", HUNTER = "Hunter", MAGE = "Mage", MONK = "Monk",
	PALADIN = "Paladin", PRIEST = "Priest", ROGUE = "Rogue", SHAMAN = "Shaman", WARLOCK = "Warlock", WARRIOR = "Warrior",
}
function O.ClassName(token)
	local names = type(LOCALIZED_CLASS_NAMES_MALE) == "table" and LOCALIZED_CLASS_NAMES_MALE or nil
	local n = names and names[token]
	if type(n) ~= "string" then
		n = O.CLASS_NAMES[token] or tostring(token)
	end
	return n
end

function O.DefaultClassOrder()
	local list = {}
	for i = 1, #O.CLASS_TOKENS do
		list[i] = O.CLASS_TOKENS[i]
	end
	table.sort(list, function(a, b) return O.ClassName(a) < O.ClassName(b) end)
	return list
end

-- Saved class order, always covering every class (retail GetClassItems).
function O.ClassOrder(saved)
	local known, seen, out = {}, {}, {}
	for i = 1, #O.CLASS_TOKENS do
		known[O.CLASS_TOKENS[i]] = true
	end
	if type(saved) == "table" then
		for _, t in ipairs(saved) do
			if known[t] and not seen[t] then
				out[#out + 1] = t
				seen[t] = true
			end
		end
	end
	for _, t in ipairs(O.DefaultClassOrder()) do
		if not seen[t] then
			out[#out + 1] = t
			seen[t] = true
		end
	end
	return out
end

-- Moves entry `value` of array `list` one place up; returns a FRESH table
-- (retail: never mutate in place, the party falls back to the raid table).
function O.MoveUp(list, value)
	local out = {}
	for i = 1, #list do
		out[i] = list[i]
	end
	for i = 2, #out do
		if out[i] == value then
			out[i], out[i - 1] = out[i - 1], out[i]
			break
		end
	end
	return out
end

function O.PlayerClassColor()
	local _, ct = UnitClass("player")
	return RF.ClassColor(ct)
end

function O.AccentColor()
	return RF.Accent()
end

function O.PlayerPowerColor()
	local _, token = UnitPowerType("player")
	return RF.PowerColor(token or "MANA")
end

-- Runs the module refresh and repaints the window (for clicks on frames
-- that are not Page controls, like the sync overlays).
function O.ApplyNow()
	ERF:ApplyAll()
	if ns.RefreshSettings then
		ns.RefreshSettings()
	end
end

-- Rebuilds the shown page (rows that exist only for some settings, like
-- the custom raid size rows; the tab's pageKey changes with them).
function O.Rebuild()
	if ns.RebuildSettingsPage then
		RF.After(0, ns.RebuildSettingsPage)
	end
end

-- The search index runs the page builders on a recorder (no frames, no
-- page fields): code that touches page frames checks this first.
function O.IsPage(p)
	return type(rawget(p, "targets")) == "table" and rawget(p, "child") ~= nil
end

---------------------------------------------------------------------------
-- Settings context (retail SGet / SSet / SVal / SWrite). party = true: a
-- key of an unsynced party section reads / writes "party_<key>", with the
-- raid value as fallback.
---------------------------------------------------------------------------
function O.NewCtx(party)
	local C = { party = party }
	local function Custom(key)
		if not party then
			return false
		end
		local sec = RF._PARTY_KEY_SECTION[key]
		return sec and RF._IsPartySectionCustom(sec) or false
	end
	C.Custom = Custom
	C.Get = function(key)
		local p = P()
		if not p then
			return nil
		end
		if Custom(key) then
			local pv = p["party_" .. key]
			if pv ~= nil then
				return pv
			end
		end
		return p[key]
	end
	C.Val = function(key, default)
		local v = C.Get(key)
		if v == nil then
			return default
		end
		return v
	end
	C.Set = function(key, v)
		local p = P()
		if not p then
			return
		end
		if Custom(key) then
			p["party_" .. key] = v
		else
			p[key] = v
		end
	end
	return C
end

---------------------------------------------------------------------------
-- Row helpers (C = context)
---------------------------------------------------------------------------
function O.Toggle(p, C, label, tip, key, default, isDisabled, after)
	p:Toggle(label, tip, function() return C.Val(key, default) and true or false end,
		function(v)
			C.Set(key, v)
			if after then
				after(v)
			end
		end, isDisabled)
end

function O.Slider(p, C, label, tip, minV, maxV, step, key, default, isDisabled, after)
	p:Slider(label, tip, minV, maxV, step, function() return C.Val(key, default) end,
		function(v)
			C.Set(key, v)
			if after then
				after(v)
			end
		end, isDisabled)
end

function O.Drop(p, C, label, tip, list, key, default, isDisabled, after, options)
	local get = function() return C.Val(key, default) end
	p:Dropdown(label, tip, function() return Items(list) end, get,
		function() return LabelOf(list, get()) end,
		function(v)
			C.Set(key, v)
			if after then
				after(v)
			end
		end, options, isDisabled)
end

-- Cog rows
function O.CT(C, label, key, default, tip, disabled, after)
	return {
		type = "toggle", label = label, tip = tip, disabled = disabled,
		get = function() return C.Val(key, default) and true or false end,
		set = function(v)
			C.Set(key, v)
			if after then
				after(v)
			end
		end,
	}
end

function O.CS(C, label, key, default, minV, maxV, step, tip, disabled)
	return {
		type = "slider", label = label, tip = tip, min = minV, max = maxV, step = step or 1, disabled = disabled,
		get = function() return C.Val(key, default) end,
		set = function(v) C.Set(key, v) end,
	}
end

function O.CD(C, label, list, key, default, tip, disabled)
	return {
		type = "dropdown", label = label, tip = tip, disabled = disabled,
		items = function() return Items(list) end,
		get = function() return C.Val(key, default) end,
		labelFn = function() return LabelOf(list, C.Val(key, default)) end,
		set = function(v) C.Set(key, v) end,
	}
end

-- X / Y offset cog (retail directions icon).
function O.OffsetCog(p, C, title, keyX, keyY, minX, maxX, minY, maxY, disabled, extra)
	local rows = {}
	if extra then
		for i = 1, #extra do
			rows[#rows + 1] = extra[i]
		end
	end
	rows[#rows + 1] = O.CS(C, "Offset X", keyX, 0, minX, maxX)
	rows[#rows + 1] = O.CS(C, "Offset Y", keyY, 0, minY or minX, maxY or maxX)
	p:Cog(title, rows, { icon = "directions", disabled = disabled })
end

-- Color get / set over a { r, g, b [, a] } key (+ optional alpha key).
function O.CGet(C, key, dr, dg, db, alphaKey, da)
	return function()
		local c = C.Get(key)
		local a
		if alphaKey then
			a = C.Val(alphaKey, da or 1)
		else
			a = (type(c) == "table" and c.a) or da or 1
		end
		if type(c) == "table" then
			return c.r or dr, c.g or dg, c.b or db, a
		end
		return dr, dg, db, a
	end
end

function O.CSet(C, key, alphaKey, alphaInTable)
	return function(r, g, b, a)
		if alphaInTable then
			C.Set(key, { r = r, g = g, b = b, a = a })
		else
			C.Set(key, { r = r, g = g, b = b })
		end
		if alphaKey then
			C.Set(alphaKey, a)
		end
	end
end

-- Mode swatches (retail Name / Health Text color triples): Custom nearest
-- the control, then Class, Accent (and Power). A click on an inactive one
-- switches the mode; the active Custom one opens the color picker.
function O.ModeSwatches(p, C, modeKey, defMode, customKey, cr, cg, cb, withPower, disabled)
	local function Mode()
		return C.Val(modeKey, defMode)
	end
	local function Pick(mode)
		return function()
			if Mode() ~= mode then
				C.Set(modeKey, mode)
				return true
			end
			return mode ~= "custom"
		end
	end
	p:Swatch("Custom Color", O.CGet(C, customKey, cr, cg, cb), O.CSet(C, customKey),
		{ active = function() return Mode() == "custom" end, onClick = Pick("custom"), disabled = disabled })
	p:Swatch("Class Color", function() local r, g, b = O.PlayerClassColor() return r, g, b, 1 end, function() end,
		{ active = function() return Mode() == "class" end, onClick = Pick("class"), readonly = true, disabled = disabled })
	p:Swatch("Accent Color", function() local r, g, b = O.AccentColor() return r, g, b, 1 end, function() end,
		{ active = function() return Mode() == "accent" end, onClick = Pick("accent"), readonly = true, disabled = disabled })
	if withPower then
		p:Swatch("Power Colored Text", function() local r, g, b = O.PlayerPowerColor() return r, g, b, 1 end, function() end,
			{ active = function() return Mode() == "power" end, onClick = Pick("power"), readonly = true, disabled = disabled })
	end
end

---------------------------------------------------------------------------
-- Party sections: "Synced with Raid Settings" overlay (retail SyncOverlay).
-- O.SecStart after p:Section, O.SecEnd at the end of the section's rows.
---------------------------------------------------------------------------
function O.SecStart(p, C, sectionKey)
	if C.party and O.IsPage(p) then
		C.secKey = sectionKey
		C.secY = p.y
	end
end

function O.SecEnd(p, C)
	if not C.party or not C.secKey or not O.IsPage(p) then
		C.secKey = nil
		return
	end
	local sectionKey, top = C.secKey, C.secY
	C.secKey = nil
	p:CloseRow()
	local height = top - p.y
	if height <= 0 then
		return
	end
	local pad = floor((p.child:GetWidth() - p:RowWidth()) / 2)
	local ov = CreateFrame("Frame", nil, p.child)
	ov:SetPoint("TOPLEFT", p.child, "TOPLEFT", pad, top)
	ov:SetSize(p:RowWidth(), height)
	ov:SetFrameLevel(p.child:GetFrameLevel() + 50)
	ov:EnableMouse(true)
	local bg = ov:CreateTexture(nil, "OVERLAY")
	bg:SetAllPoints()
	bg:SetTexture(17 / 255, 15 / 255, 12 / 255, 0.98)
	local label = ov:CreateFontString(nil, "OVERLAY")
	label:SetFont(ns.FONT or "Fonts\\FRIZQT__.TTF", 13, "")
	label:SetPoint("CENTER", ov, "CENTER", 0, 0)
	label:SetTextColor(1, 1, 1, 0.56)
	label:SetText("Synced with Raid Settings")
	ov:SetScript("OnEnter", function()
		local r, g, b = RF.Accent()
		label:SetTextColor(r, g, b, 1)
	end)
	ov:SetScript("OnLeave", function() label:SetTextColor(1, 1, 1, 0.56) end)
	-- A click unsyncs the section, like unchecking it in "Use Raid Settings For".
	ov:SetScript("OnMouseUp", function(self, button)
		if button ~= "LeftButton" then
			return
		end
		local prof = P()
		if not prof then
			return
		end
		prof.partySyncSections = prof.partySyncSections or {}
		prof.partySyncSections[sectionKey] = false
		self:Hide()
		O.ApplyNow()
	end)
	ov:EnableMouseWheel(true)
	ov:SetScript("OnMouseWheel", function(_, delta) p:ScrollBy(-delta * 60) end)
	local function Refresh()
		ov:SetShown(not RF._IsPartySectionCustom(sectionKey))
	end
	p:OnRefresh(Refresh)
	Refresh()
end

---------------------------------------------------------------------------
-- Preview (retail previewMode real / overlay / none): fake raid frames
-- while the Raid Frames tab is open, fake party frames on the Party Frames
-- tab (engine: RF.ShowPreview / HidePreview / ShowPartyPreview /
-- HidePartyPreview).
---------------------------------------------------------------------------
O.view = { entered = false, tab = nil }

function O.UpdatePreview()
	local prof = P()
	local mode = prof and prof.previewMode or "overlay"
	local tab = O.view.entered and O.view.tab or nil
	-- A raid size preview (tier editor) ends when the Raid Frames tab goes.
	if O.sizeTier and tab ~= "raid" then
		O.sizeTier = nil
		if RF.HideSizePreview then RF.HideSizePreview() end
	end
	if O.sizeTier then
		return
	end
	if tab == "raid" and mode ~= "none" then
		if RF.HidePartyPreview then RF.HidePartyPreview() end
		if RF.ShowPreview then RF.ShowPreview() end
	elseif tab == "party" and mode ~= "none" then
		if RF.HidePreview then RF.HidePreview() end
		if RF.ShowPartyPreview then RF.ShowPartyPreview() end
	else
		if RF.HidePreview then RF.HidePreview() end
		if RF.HidePartyPreview then RF.HidePartyPreview() end
	end
end

-- The page's scroll frame shows / hides with its tab (and with the window).
function O.TrackTab(p, tab)
	if not O.IsPage(p) then
		return
	end
	p.scroll:HookScript("OnShow", function()
		O.view.tab = tab
		O.UpdatePreview()
	end)
	p.scroll:HookScript("OnHide", function()
		if O.view.tab == tab then
			O.view.tab = nil
			O.UpdatePreview()
		end
	end)
end

O.PREVIEW_MODES = { { "real", "Real Preview" }, { "overlay", "Overlay Preview" }, { "none", "No Preview" } }

-- Fixed header above the settings: the retail "Preview Mode" row.
function O.PreviewHeader(page, host, width)
	local label = host:CreateFontString(nil, "OVERLAY")
	label:SetFont(ns.FONT or "Fonts\\FRIZQT__.TTF", 14, "")
	label:SetTextColor(1, 1, 1, 0.6)
	label:SetPoint("TOP", host, "TOP", 0, -14)
	label:SetText("Preview Mode")
	local holder = page:HeaderDropdown(host, 180, 30,
		function() return Items(O.PREVIEW_MODES) end,
		function() local prof = P() return prof and prof.previewMode or "overlay" end,
		function() local prof = P() return LabelOf(O.PREVIEW_MODES, prof and prof.previewMode or "overlay") end,
		function(v)
			local prof = P()
			if prof then
				prof.previewMode = v
			end
			if RF.ApplyPreviewMode and O.view.entered and O.view.tab == "raid" then
				RF.ApplyPreviewMode()
			end
			O.UpdatePreview()
		end)
	holder:SetPoint("TOP", label, "BOTTOM", 0, -9)
	return 76
end

---------------------------------------------------------------------------
-- Shared controls of the two frame pages
---------------------------------------------------------------------------
-- Checked names of a checkbox dropdown (retail BuildVisOptsCBDropdown text).
function O.CheckedLabel(items, isChecked)
	local names = {}
	for i = 1, #items do
		if isChecked(items[i].value) then
			names[#names + 1] = items[i].name
		end
	end
	if #names == 0 then
		return "None"
	end
	return table.concat(names, ", ")
end

-- Checkbox dropdown over a set of boolean keys (Auto Resize Icons, Hover
-- Borders, Show Power Bar For). defs = { { value, label, key, default } }.
function O.KeyChecks(p, C, label, tip, defs, isDisabled, after)
	local items = {}
	local byValue = {}
	for i = 1, #defs do
		items[i] = { value = defs[i][1], name = defs[i][2] }
		byValue[defs[i][1]] = defs[i]
	end
	local function isChecked(v)
		local d = byValue[v]
		return d and C.Val(d[3], d[4]) and true or false
	end
	p:MultiSelect(label, tip, function() return items end, isChecked,
		function(v)
			local d = byValue[v]
			if d then
				C.Set(d[3], not isChecked(v))
				if after then
					after(v)
				end
			end
		end,
		function() return O.CheckedLabel(items, isChecked) end, isDisabled)
end

-- Sort By (retail BuildSortByControl): Group / Role, plus the role order
-- (retail drags the role rows; here a pick moves a role one place up).
function O.SortBy(p, label, getMode, setMode, getRoles, setRoles)
	local function Roles()
		local ro = getRoles()
		if type(ro) ~= "table" or #ro < 3 then
			ro = { "TANK", "HEALER", "DAMAGER" }
		end
		return ro
	end
	p:Dropdown(label, "Group: by raid group. Role: by assigned role, in the role order below (pick a role to move it one place up).",
		function()
			local items = {
				{ value = "INDEX", name = "Group" },
				{ value = "ROLE", name = "Role" },
				{ separator = true, name = "" },
				{ header = true, name = "Role Order" },
			}
			local ro = Roles()
			for i = 1, #ro do
				items[#items + 1] = { value = "role:" .. ro[i], name = i .. ". " .. (O.ROLE_LABELS[ro[i]] or ro[i]),
					tip = "Move up" }
			end
			return items
		end,
		getMode,
		function() return getMode() == "ROLE" and "Role" or "Group" end,
		function(v)
			if type(v) == "string" and v:sub(1, 5) == "role:" then
				setRoles(O.MoveUp(Roles(), v:sub(6)))
			else
				setMode(v)
			end
		end)
end

-- Class Sorting cog (retail: Prioritize Class + drag-to-reorder Class Order).
function O.ClassSortCog(p, prioKey, orderKey)
	local function Order()
		local prof = P()
		return O.ClassOrder(prof and prof[orderKey])
	end
	p:Cog("Class Sorting", {
		{ type = "toggle", label = "Prioritize Class", tip = "This will not override sorting by role",
			get = function() local prof = P() return prof and prof[prioKey] and true or false end,
			set = function(v) P()[prioKey] = v end },
		{ type = "dropdown", label = "Class Order", tip = "Pick a class to move it one place up.",
			disabled = function() local prof = P() return not (prof and prof[prioKey]) end,
			items = function()
				local items = {}
				local order = Order()
				for i = 1, #order do
					items[i] = { value = order[i], name = i .. ". " .. O.ClassName(order[i]) }
				end
				return items
			end,
			get = function() return nil end,
			labelFn = function()
				local order = Order()
				return O.ClassName(order[1]) .. ", " .. O.ClassName(order[2]) .. ", ..."
			end,
			set = function(v) P()[orderKey] = O.MoveUp(Order(), v) end },
	})
end

---------------------------------------------------------------------------
-- Raid Frames tab: FRAME SIZES, FRAME DISPLAY, LAYOUT
---------------------------------------------------------------------------
O.TIERS = { 10, 15, 25, 30, 40 }
O.TIER_LABELS = { [10] = "10 Man", [15] = "15 Man", [25] = "25 Man", [30] = "30 Man", [40] = "40 Man" }
-- Custom switch boundary per tier (retail TIER_BOUNDS).
O.TIER_BOUNDS = {
	[10] = { key = "sizeCap", label = "Covers Up To", def = 10, min = 5, max = 14,
		tip = "Highest group size that uses this layout." },
	[15] = { key = "sizeCap", label = "Covers Up To", def = 15, min = 11, max = 19,
		tip = "Highest group size that uses this layout." },
	[25] = { key = "sizeMin", label = "Switch At", def = 21, min = 21, max = 30,
		tip = "Group size at which this layout takes over from the 20 Man layout." },
	[30] = { key = "sizeMin", label = "Switch At", def = 26, min = 22, max = 40,
		tip = "Group size at which this layout takes over from the 25 Man layout." },
	[40] = { key = "sizeMin", label = "Switch At", def = 31, min = 31, max = 40,
		tip = "Group size at which this layout takes over from the 30 Man layout." },
}

function O.TierOverride(tier)
	local prof = P()
	local ovs = prof and prof.raidSizeOverrides
	local ov = type(ovs) == "table" and ovs[tier]
	return type(ov) == "table" and ov or nil
end

function O.EnsureTier(tier)
	local prof = P()
	prof.raidSizeOverrides = prof.raidSizeOverrides or {}
	local ovs = prof.raidSizeOverrides
	if type(ovs[tier]) ~= "table" then
		ovs[tier] = { width = prof.frameWidth or 125, height = prof.frameHeight or 60 }
	end
	return ovs[tier]
end

-- Page key of the Raid Frames tab: the page is built again when the set of
-- custom raid sizes changes (their rows exist only while they are added).
function O.RaidPageKey()
	local s = "raid"
	for _, tier in ipairs(O.TIERS) do
		if O.TierOverride(tier) then
			s = s .. ":" .. tier
		end
	end
	return s
end

-- Group / Unit Growth (retail ReadGroupGrowth / KeepGrowthPerpendicular):
-- merged groups cannot draw the grid flow or a same-axis pair.
function O.GrowthVertical(v)
	return v == "DOWN" or v == "UP" or v == "DOWNRIGHT"
end

function O.KeepPerpendicular(newVal, other, setOther)
	if O.GrowthVertical(newVal) == O.GrowthVertical(other) then
		setOther(O.GrowthVertical(newVal) and "RIGHT" or "DOWN")
	end
end

function O.ReadGroupGrowth(v)
	local prof = P()
	if v == "DOWNRIGHT" and prof and prof.mergeGroups then
		return "RIGHT"
	end
	return v
end

function O.GroupGrowthItems()
	local items = Items(O.GROUP_GROWTH)
	for i = 1, #items do
		if items[i].value == "DOWNRIGHT" then
			items[i].locked = function() local prof = P() return prof and prof.mergeGroups end
			items[i].lockedTip = "This option requires Merge Groups to be disabled."
		end
	end
	return items
end

function O.FixOneTier(ov, prof)
	O.KeepPerpendicular(ov.groupGrowth or prof.groupGrowth or "RIGHT", ov.unitGrowth or prof.unitGrowth or "DOWN",
		function(nv) ov.unitGrowth = nv end)
end

function O.FixTierOverridesPerpendicular()
	local prof = P()
	local ovs = prof.raidSizeOverrides
	if type(ovs) ~= "table" then
		return
	end
	for _, ov in pairs(ovs) do
		if type(ov) == "table" then
			O.FixOneTier(ov, prof)
		end
	end
end

-- One custom raid size: width (+ options cog) | height (+ remove icon).
function O.TierRows(p, C, tier)
	local label = O.TIER_LABELS[tier]
	local tb = O.TIER_BOUNDS[tier]
	p:Slider(label .. " Frame Width", nil, 40, 300, 1,
		function() local ov = O.TierOverride(tier) return ov and ov.width or C.Val("frameWidth", 72) end,
		function(v) O.EnsureTier(tier).width = v end)
	p:Cog(label .. " Options", {
		{ type = "slider", label = tb.label, tip = tb.tip, min = tb.min, max = tb.max, step = 1,
			get = function() local ov = O.TierOverride(tier) return ov and ov[tb.key] or tb.def end,
			set = function(v) O.EnsureTier(tier)[tb.key] = v end },
		{ type = "dropdown", label = "Group Growth",
			items = O.GroupGrowthItems,
			get = function()
				local ov = O.TierOverride(tier)
				return O.ReadGroupGrowth(ov and ov.groupGrowth or P().groupGrowth or "RIGHT")
			end,
			labelFn = function()
				local ov = O.TierOverride(tier)
				return LabelOf(O.GROUP_GROWTH, O.ReadGroupGrowth(ov and ov.groupGrowth or P().groupGrowth or "RIGHT"))
			end,
			set = function(v)
				local ov = O.EnsureTier(tier)
				ov.groupGrowth = v
				if P().mergeGroups then
					O.KeepPerpendicular(v, ov.unitGrowth or P().unitGrowth or "DOWN", function(nv) ov.unitGrowth = nv end)
				end
			end },
		{ type = "dropdown", label = "Unit Growth",
			items = function() return Items(O.GROWTH) end,
			get = function() local ov = O.TierOverride(tier) return ov and ov.unitGrowth or P().unitGrowth or "DOWN" end,
			labelFn = function()
				local ov = O.TierOverride(tier)
				return LabelOf(O.GROWTH, ov and ov.unitGrowth or P().unitGrowth or "DOWN")
			end,
			set = function(v)
				local ov = O.EnsureTier(tier)
				ov.unitGrowth = v
				if P().mergeGroups then
					O.KeepPerpendicular(v, ov.groupGrowth or P().groupGrowth or "RIGHT", function(nv) ov.groupGrowth = nv end)
				end
			end },
		{ type = "slider", label = "X Offset", min = -1000, max = 1000, step = 1,
			get = function() local ov = O.TierOverride(tier) return ov and ov.offsetX or 0 end,
			set = function(v) O.EnsureTier(tier).offsetX = v end },
		{ type = "slider", label = "Y Offset", min = -1000, max = 1000, step = 1,
			get = function() local ov = O.TierOverride(tier) return ov and ov.offsetY or 0 end,
			set = function(v) O.EnsureTier(tier).offsetY = v end },
	}, { icon = "directions" })
	p:Slider(label .. " Frame Height", nil, 20, 150, 1,
		function() local ov = O.TierOverride(tier) return ov and ov.height or C.Val("frameHeight", 46) end,
		function(v) O.EnsureTier(tier).height = v end)
	-- Retail eye icon: preview this raid size (the regular preview returns after).
	p:InlineIcon("Preview " .. label .. " frame size (click again to hide)", ns.MEDIA .. "icons\\flashlight", function()
		if O.sizeTier == tier then
			O.sizeTier = nil
			if RF.HideSizePreview then RF.HideSizePreview() end
			O.UpdatePreview()
		elseif RF.ShowSizePreview then
			if O.sizeTier and RF.HideSizePreview then RF.HideSizePreview() end
			O.sizeTier = tier
			RF.ShowSizePreview(tier)
		end
	end, 18)
	p:InlineIcon("Remove " .. label .. " size", ns.MEDIA .. "ui\\eui-close", function()
		if O.sizeTier == tier then
			O.sizeTier = nil
			if RF.HideSizePreview then RF.HideSizePreview() end
		end
		local prof = P()
		local ovs = prof.raidSizeOverrides
		if type(ovs) == "table" then
			ovs[tier] = nil
			-- Conversion markers stay; only tier tables count as content.
			local any = false
			for _, o in pairs(ovs) do
				if type(o) == "table" then
					any = true
					break
				end
			end
			if not any then
				prof.raidSizeOverrides = nil
			end
		end
		O.Rebuild()
	end, 18)
end

function O.BuildFrameSizes(p, C)
	p:Section("FRAME SIZES")
	O.Slider(p, C, "20 Man Frame Width", nil, 40, 300, 1, "frameWidth", 72)
	O.Slider(p, C, "20 Man Frame Height", nil, 20, 150, 1, "frameHeight", 46)
	for _, tier in ipairs(O.TIERS) do
		if O.TierOverride(tier) then
			O.TierRows(p, C, tier)
		end
	end
	-- Add Custom Raid Size | Auto Resize Icons (offered tiers exclude the added ones).
	local any = false
	for _, tier in ipairs(O.TIERS) do
		if not O.TierOverride(tier) then
			any = true
		end
	end
	if any then
		p:Dropdown("Add Custom Raid Size",
			"This option allows you to set custom frame sizing and positioning to different raid sizes. Note: This does NOT resize/reposition frames while in combat, if players join/leave mid combat it will resize after combat completes.",
			function()
				local items = { { value = "_select", name = "Select Raid Size" } }
				for _, tier in ipairs(O.TIERS) do
					if not O.TierOverride(tier) then
						items[#items + 1] = { value = tostring(tier), name = O.TIER_LABELS[tier] }
					end
				end
				return items
			end,
			function() return "_select" end,
			function() return "Select Raid Size" end,
			function(v)
				local tier = tonumber(v)
				if not tier then
					return
				end
				local prof = P()
				prof.raidSizeOverrides = prof.raidSizeOverrides or {}
				-- Seed from the current 20 man size.
				prof.raidSizeOverrides[tier] = { width = prof.frameWidth or 125, height = prof.frameHeight or 60 }
				O.Rebuild()
			end)
	else
		p:Blank()
	end
	O.KeyChecks(p, C, "Auto Resize Icons",
		"Indicators & Auras: icons and texts follow the frame size of the active raid size. Tracked Buffs: the Buff Manager icons do too.",
		{ { "indicators", "Indicators & Auras", "autoResizeIndicators", false },
			{ "trackedBuffs", "Tracked Buffs", "autoResizeTrackedBuffs", true } })
end

function O.BuildFrameDisplay(p, C)
	p:Section("FRAME DISPLAY")
	O.Slider(p, C, "Frame Spacing", nil, -1, 15, 1, "cellSpacing", 2)
	p:Cog("Frame Spacing Settings", {
		O.CT(C, "Compact Mode", "raidCompactMode", false,
			"Frames overlap by the border size, so neighbours share one border line: each group reads as one outline with separators. Needs a border size above 0."),
	})
	O.Slider(p, C, "Group Spacing", nil, -1, 15, 1, "groupSpacing", 8)
	p:Cog("Group Spacing Settings", {
		O.CT(C, "Grid Mode", "raidGridMode", false,
			"With Compact Mode on, the raid groups share their border lines too.",
			function() return not C.Val("raidCompactMode", false) end),
	})
	-- Border Style: 5.4.8 has the Solid border only (no border texture registry).
	p:Dropdown("Border Style", nil, function() return { { value = "solid", name = "Solid" } } end,
		function() return "solid" end, function() return "Solid" end,
		function(v) C.Set("borderTexture", v) end)
	O.Slider(p, C, "Border Size", nil, 0, 8, 1, "borderSize", 1, nil,
		function() C.Set("borderSizePx", nil) end)
	p:Swatch("Border", O.CGet(C, "borderColor", 0, 0, 0, "borderAlpha", 1), O.CSet(C, "borderColor", "borderAlpha"),
		{ alpha = true })
	-- Show When Solo | Hover Borders (+ Hover / Target swatches, sizes cog).
	O.Toggle(p, C, "Show When Solo", "Show the raid frames when you are not in a group. Not available while only the Party Frames Show When Solo is on.",
		"showWhenSolo", false,
		function() local prof = P() return prof.partyShowWhenSolo and not prof.showWhenSolo end)
	O.KeyChecks(p, C, "Hover Borders", nil,
		{ { "hover", "Hover Border", "hoverBorderEnabled", true }, { "target", "Target Border", "targetBorderEnabled", true } })
	p:Swatch("Hover", O.CGet(C, "hoverBorderColor", 1, 1, 1, "hoverBorderAlpha", 1), O.CSet(C, "hoverBorderColor", "hoverBorderAlpha"),
		{ alpha = true, active = function() return C.Val("hoverBorderEnabled", true) end })
	p:Swatch("Target", O.CGet(C, "targetBorderColor", 1, 1, 1, "targetBorderAlpha", 1), O.CSet(C, "targetBorderColor", "targetBorderAlpha"),
		{ alpha = true, active = function() return C.Val("targetBorderEnabled", true) end })
	p:Cog("Highlight Border", {
		{ type = "slider", label = "Hover Border Size", min = 1, max = 8, step = 1,
			get = function() return C.Val("hoverBorderSize", 1) end,
			set = function(v) C.Set("hoverBorderSize", v) C.Set("hoverBorderSizePx", nil) end },
		{ type = "slider", label = "Target Border Size", min = 1, max = 8, step = 1,
			get = function() return C.Val("targetBorderSize", 1) end,
			set = function(v) C.Set("targetBorderSize", v) C.Set("targetBorderSizePx", nil) end },
	}, { icon = "directions", disabled = function() return C.Val("borderSize", 1) > 0 end,
		disabledTip = "Only used while Border Size is 0: with a border, the highlight recolors it." })
end

-- Saved custom group order: a permutation of 1..8, else nil.
function O.ValidGroupOrder(order)
	if type(order) ~= "table" or #order ~= 8 then
		return nil
	end
	local seen = {}
	for i = 1, 8 do
		local g = order[i]
		if type(g) ~= "number" or g < 1 or g > 8 or seen[g] then
			return nil
		end
		seen[g] = true
	end
	return order
end

function O.GroupList()
	local prof = P()
	local list = {}
	local saved = prof.customGroupOrder and not prof.mergeGroups and O.ValidGroupOrder(prof.groupOrder)
	for i = 1, 8 do
		list[i] = saved and saved[i] or i
	end
	return list
end

function O.GroupVisible(k)
	local vg = P().visibleGroups
	return vg and vg[k] ~= false
end

function O.BuildLayout(p, C)
	p:Section("LAYOUT")
	p:Dropdown("Group Growth", nil, O.GroupGrowthItems,
		function() return O.ReadGroupGrowth(C.Val("groupGrowth", "RIGHT")) end,
		function() return LabelOf(O.GROUP_GROWTH, O.ReadGroupGrowth(C.Val("groupGrowth", "RIGHT"))) end,
		function(v)
			local prof = P()
			prof.groupGrowth = v
			if prof.mergeGroups then
				O.KeepPerpendicular(v, prof.unitGrowth or "DOWN", function(nv) prof.unitGrowth = nv end)
				O.FixTierOverridesPerpendicular()
			end
		end)
	O.Drop(p, C, "Unit Growth", nil, O.GROWTH, "unitGrowth", "DOWN", nil, function(v)
		local prof = P()
		if prof.mergeGroups then
			O.KeepPerpendicular(v, prof.groupGrowth or "RIGHT", function(nv) prof.groupGrowth = nv end)
			O.FixTierOverridesPerpendicular()
		end
	end)
	-- Sort By (+ Class Sorting cog) | Self Position
	O.SortBy(p, "Sort By",
		function() return C.Val("sortMode", "INDEX") end,
		function(v) C.Set("sortMode", v) end,
		function() return C.Val("roleOrder", nil) end,
		function(ro) P().roleOrder = ro end)
	O.ClassSortCog(p, "prioritizeClass", "classOrder")
	p:Dropdown("Self Position", nil, function() return Items(O.SELF_POS) end,
		function()
			if C.Val("showSelfLast", false) then return "last" end
			if C.Val("showSelfFirst", false) then return "first" end
			return "none"
		end,
		function()
			if C.Val("showSelfLast", false) then return "Last" end
			if C.Val("showSelfFirst", false) then return "First" end
			return "Default"
		end,
		function(v)
			C.Set("showSelfFirst", v == "first")
			C.Set("showSelfLast", v == "last")
		end)
	-- Show Groups (+ cog) | Merge Groups
	p:MultiSelect("Show Groups", nil,
		function()
			local items = {}
			for i, g in ipairs(O.GroupList()) do
				items[i] = { value = g, name = "Group " .. g }
			end
			return items
		end,
		O.GroupVisible,
		function(k)
			local prof = P()
			if not prof.visibleGroups then
				prof.visibleGroups = { true, true, true, true, true, true, false, false }
			end
			prof.visibleGroups[k] = not O.GroupVisible(k)
		end,
		function()
			local names = {}
			for _, g in ipairs(O.GroupList()) do
				if O.GroupVisible(g) then
					names[#names + 1] = "Group " .. g
				end
			end
			return #names > 0 and table.concat(names, ", ") or "None"
		end)
	p:Cog("Show Groups", {
		O.CT(C, "Hide Empty Groups", "hideEmptyGroups", true,
			"Collapse subgroups that have no members so the remaining groups close ranks. For example, if only groups 1, 2, 3 and 6 have players, they show with no gaps instead of leaving empty space where groups 4 and 5 would be. Real raid frames only."),
		O.CT(C, "Exclude Hidden from Size", "excludeHiddenGroupsFromSize", true,
			"When using custom raid sizes, don't count members in hidden groups toward the raid-size breakpoint. For example, if you hide groups 7 and 8, a full 40-man raid is sized as if it were 24-man instead of jumping to the 30-man frame size. Has no effect unless you have custom raid sizes set up."),
		{ type = "toggle", label = "Custom Group Order", tip = "Display separated raid groups in your chosen order.",
			disabled = function() return InCombatLockdown() end,
			get = function() return P().customGroupOrder == true end,
			set = function(v)
				if InCombatLockdown() then
					return
				end
				P().customGroupOrder = v
			end },
		{ type = "dropdown", label = "Group Order", tip = "Pick a group to move it one place up.",
			disabled = function() local prof = P() return not prof.customGroupOrder or prof.mergeGroups or InCombatLockdown() end,
			items = function()
				local items = {}
				for i, g in ipairs(O.GroupList()) do
					items[i] = { value = g, name = i .. ". Group " .. g }
				end
				return items
			end,
			get = function() return nil end,
			labelFn = function()
				local list = O.GroupList()
				return list[1] .. ", " .. list[2] .. ", " .. list[3] .. ", ..."
			end,
			set = function(v)
				if InCombatLockdown() or P().mergeGroups then
					return
				end
				P().groupOrder = O.MoveUp(O.GroupList(), v)
			end },
	})
	O.Toggle(p, C, "Merge Groups", nil, "mergeGroups", false, nil, function(v)
		if v then
			local prof = P()
			O.KeepPerpendicular(prof.groupGrowth or "RIGHT", prof.unitGrowth or "DOWN", function(nv) prof.unitGrowth = nv end)
			O.FixTierOverridesPerpendicular()
		end
	end)
end

---------------------------------------------------------------------------
-- Visual sections, part 1 (retail VisualBars_Options.lua): HEALTH BAR,
-- ABSORBS, POWER BAR, TEXT DISPLAY. Raid and party pages (C.party).
-- Retail eye icons (health / absorb / power preview animations) are left out.
---------------------------------------------------------------------------
-- Absorb style items: the given order, then SharedMedia bars after a divider.
function O.AbsorbItems(order)
	local items = {}
	for _, key in ipairs(order) do
		items[#items + 1] = { value = key, name = O.ABSORB_LABEL[key] or (RF.ABSORB_STYLE_NAMES and RF.ABSORB_STYLE_NAMES[key]) or key }
	end
	local lsm = RF.LSM and RF.LSM()
	if lsm then
		local list = lsm:List("statusbar")
		if list and #list > 0 then
			items[#items + 1] = { separator = true, name = "" }
			for i = 1, #list do
				items[#items + 1] = { value = "sm:" .. list[i], name = list[i] }
			end
		end
	end
	return items
end

function O.AbsorbLabel(key)
	if type(key) == "string" and key:sub(1, 3) == "sm:" then
		return key:sub(4)
	end
	return O.ABSORB_LABEL[key] or (RF.ABSORB_STYLE_NAMES and RF.ABSORB_STYLE_NAMES[key]) or tostring(key or "")
end

O.ABSORB_PREVIEW = {
	texturePreview = true,
	previewPath = function(v)
		if not v or v == "none" then
			return nil
		end
		return RF.AbsorbTexture(v)
	end,
}

function O.AbsorbDrop(p, C, label, tip, order, key, default, after)
	p:Dropdown(label, tip, function() return O.AbsorbItems(order) end,
		function() return C.Val(key, default) end,
		function() return O.AbsorbLabel(C.Val(key, default)) end,
		function(v)
			C.Set(key, v)
			if after then
				after(v)
			end
		end, O.ABSORB_PREVIEW)
end

-- Placement labels follow the fill axis (retail SyncAbsorbEdgeLabels).
function O.EdgeItems(C, withReverse)
	local vert = C.Val("healthVerticalFill", false) and true or false
	local list = { { "overlay", "Overlay" } }
	if withReverse then
		list[#list + 1] = { "overlayReverse", "Overlay Reverse" }
		list[#list + 1] = { "overlayReverseFull", "Overlay Reverse (Full)" }
	end
	list[#list + 1] = { "right", vert and "From Top Edge" or "From Right Edge" }
	list[#list + 1] = { "left", vert and "From Bottom Edge" or "From Left Edge" }
	return list
end

O.ABSORB_BAR_POS = {
	{ "none", "None" }, { "aboveRight", "Above Frame Right" }, { "aboveLeft", "Above Frame Left" },
	{ "topRight", "Top Right" }, { "topLeft", "Top Left" }, { "rightVertical", "Right Edge (Vertical)" },
	{ "leftVertical", "Left Edge (Vertical)" },
}
O.HEAL_ABSORB_BAR_POS = {
	{ "none", "None" }, { "belowAbsorb", "Below Absorb Bar" }, { "aboveRight", "Above Frame Right" },
	{ "aboveLeft", "Above Frame Left" }, { "topRight", "Top Right" }, { "topLeft", "Top Left" },
	{ "rightVertical", "Right Edge (Vertical)" }, { "leftVertical", "Left Edge (Vertical)" },
}
O.VERTICAL_GROW = { { "up", "Up" }, { "down", "Down" } }
O.OVERSHIELD = { { "never", "Never" }, { "always", "Always" }, { "fromleft", "From Left" } }

function O.IsVerticalBar(pos)
	return pos == "rightVertical" or pos == "leftVertical"
end

-- The size slider reads as width for the vertical positions (retail retitles it).
function O.BarSizeLabel(p, getPos)
	if not O.IsPage(p) then
		return
	end
	local cell = p.lastCell
	p:OnRefresh(function()
		cell.label:SetText(O.IsVerticalBar(getPos()) and "Bar Width" or "Bar Height")
	end)
end

function O.BuildHealthBar(p, C)
	p:Section("HEALTH BAR")
	O.SecStart(p, C, "healthBar")
	local function Dark()
		return C.Val("healthColorMode", "class") == "dark"
	end
	-- Health Bar Texture (+ fill cog) | Fill Opacity
	p:Dropdown("Health Bar Texture", nil, ERF.TextureItems,
		function() return C.Val("healthBarTexture", "atrocity") end,
		function() return ERF.TextureLabel(C.Val("healthBarTexture", "atrocity")) end,
		function(v) C.Set("healthBarTexture", v) end,
		{ texturePreview = true, previewPath = RF.TexturePath })
	p:Cog("Health Bar Fill", {
		O.CT(C, "Vertical Fill", "healthVerticalFill", false,
			"Fill the health bar bottom-to-top instead of left-to-right. Absorbs, heal prediction and the bar background follow the same axis."),
		O.CT(C, "Fill Missing Health", "healthInvertFill", false,
			"The bar fills with missing health, growing as the unit takes damage."),
	})
	O.Slider(p, C, "Fill Opacity", "Not available in Dark Mode", 0, 100, 1, "healthBarOpacity", 100, Dark)
	-- Fill Color (+ custom / dynamic swatches) | Background (+ custom / class swatches)
	O.Drop(p, C, "Fill Color",
		"Custom Dynamic Colors: the health bar smoothly blends between three colors you pick -- one for full health (100%), one for half (50%), and one for empty (0%) -- shifting through them as the unit takes damage or is healed.",
		O.HEALTH_COLOR, "healthColorMode", "class")
	local function Mode()
		return C.Val("healthColorMode", "class")
	end
	p:Swatch("Custom fill color (Custom Color only)", O.CGet(C, "customFillColor", 37 / 255, 193 / 255, 29 / 255),
		O.CSet(C, "customFillColor"), { disabled = function() return Mode() ~= "custom" end })
	-- Built right to left so the swatches read 100% | 50% | 0%.
	p:Swatch("Health bar color at empty (0%) health", O.CGet(C, "dynamicColor0", 0xE3 / 255, 0x30 / 255, 0x30 / 255),
		O.CSet(C, "dynamicColor0"),
		{ disabled = function() return Mode() ~= "customDynamic" and Mode() ~= "classReactive" end })
	p:Swatch("Health bar color at half (50%) health", O.CGet(C, "dynamicColor50", 0xEC / 255, 0xEC / 255, 0x32 / 255),
		O.CSet(C, "dynamicColor50"),
		{ disabled = function() return Mode() ~= "customDynamic" and Mode() ~= "classReactive" end })
	p:Swatch("Health bar color at full (100%) health", O.CGet(C, "dynamicColor100", 0, 1, 0),
		O.CSet(C, "dynamicColor100"),
		{ disabled = function() return Mode() ~= "customDynamic" end })
	O.Slider(p, C, "Background", "Not available in Dark Mode.", 0, 100, 1, "bgDarkness", 50, Dark)
	p:Swatch("Class Colored Background", function() local r, g, b = O.PlayerClassColor() return r, g, b, 1 end, function() end,
		{ readonly = true, disabled = Dark,
			active = function() return C.Val("bgClassColored", false) end,
			onClick = function() C.Set("bgClassColored", true) return true end })
	p:Swatch("Custom Background Color", O.CGet(C, "customBgColor", 17 / 255, 17 / 255, 17 / 255), O.CSet(C, "customBgColor"),
		{ disabled = Dark,
			active = function() return not C.Val("bgClassColored", false) end,
			onClick = function()
				if C.Val("bgClassColored", false) then
					C.Set("bgClassColored", false)
					return true
				end
			end })
	-- Heal Prediction (+ swatch) | Prediction Opacity
	O.Toggle(p, C, "Heal Prediction", nil, "healPrediction", false)
	p:Swatch("Heal Prediction", O.CGet(C, "healPredColor", 102 / 255, 243 / 255, 102 / 255), O.CSet(C, "healPredColor"),
		{ active = function() return C.Val("healPrediction", false) end })
	O.Slider(p, C, "Prediction Opacity", nil, 5, 100, 1, "healPredOpacity", 75,
		function() return not C.Val("healPrediction", false) end)
	-- Smooth Health Bars | Threat Borders
	O.Toggle(p, C, "Smooth Health Bars", nil, "smoothBars", true)
	O.Slider(p, C, "Threat Borders", "Size of the aggro warning border. 0 = off.", 0, 4, 1, "threatBorderSize", 2)
	O.SecEnd(p, C)
end

function O.BuildAbsorbs(p, C)
	p:Section("ABSORBS")
	O.SecStart(p, C, "absorbs")
	local function AbsorbOff()
		return C.Val("absorbStyle", "none") == "none"
	end
	-- Absorb Style (+ swatch, rendering cog) | Absorb Opacity
	O.AbsorbDrop(p, C, "Absorb Style", nil, RF.ABSORB_STYLE_ORDER, "absorbStyle", "none", function(v)
		C.Set("absorbOpacity", v == "clean" and 30 or 90)
	end)
	p:Swatch("Absorb Color", O.CGet(C, "absorbColor", 1, 1, 1), O.CSet(C, "absorbColor"), { disabled = AbsorbOff })
	p:Cog("Absorb Rendering", {
		{ type = "dropdown", label = "Placement",
			items = function() return Items(O.EdgeItems(C, true)) end,
			get = function() return C.Val("absorbEdgeMode", "overlay") end,
			labelFn = function() return LabelOf(O.EdgeItems(C, true), C.Val("absorbEdgeMode", "overlay")) end,
			set = function(v) C.Set("absorbEdgeMode", v) end },
		{ type = "dropdown", label = "Show Overshield",
			tip = "Overshield is the part of an absorb exceeding your empty health. Always backfills it over current health from the shield's edge; From Left grows it from the opposite end of the bar; Never hides it.",
			items = function()
				local items = Items(O.OVERSHIELD)
				items[3].locked = function() return C.Val("absorbEdgeMode", "overlay") ~= "overlay" end
				items[3].lockedTip = "From Left only works with the Overlay placement."
				return items
			end,
			get = function() return O.OvershieldMode(C) end,
			labelFn = function() return LabelOf(O.OVERSHIELD, O.OvershieldMode(C)) end,
			set = function(v)
				-- Mirror the legacy boolean (Never / Always).
				C.Set("showOvershield", v ~= "never")
				C.Set("overshieldMode", v)
			end },
	})
	O.Slider(p, C, "Absorb Opacity", nil, 5, 100, 1, "absorbOpacity", 90, AbsorbOff)
	-- Absorb Bar (+ rendering cog) | Bar Height (+ swatch)
	local function BarPos()
		local pos = C.Get("absorbBarPosition")
		if pos then
			return pos
		end
		return C.Val("absorbBarEnabled", false) and "aboveRight" or "none"
	end
	p:Dropdown("Absorb Bar", nil, function() return Items(O.ABSORB_BAR_POS) end, BarPos,
		function() return LabelOf(O.ABSORB_BAR_POS, BarPos()) end,
		function(v)
			C.Set("absorbBarEnabled", v ~= "none")
			C.Set("absorbBarPosition", v)
		end)
	p:Cog("Absorb Bar Rendering", {
		O.CD(C, "Vertical Grow", O.VERTICAL_GROW, "absorbBarGrowDir", "up", nil,
			function() return not O.IsVerticalBar(BarPos()) end),
	}, { disabled = function() return not O.IsVerticalBar(BarPos()) end,
		disabledTip = "Only affects the vertical (Right/Left Edge) positions" })
	O.Slider(p, C, "Bar Height", nil, 1, 20, 1, "absorbBarHeight", 4, function() return BarPos() == "none" end)
	O.BarSizeLabel(p, BarPos)
	p:Swatch("Absorb Bar Color", O.CGet(C, "absorbBarColor", 1, 1, 1), O.CSet(C, "absorbBarColor", nil, true),
		{ alpha = true, active = function() return BarPos() ~= "none" end })
	-- Heal Absorb Style (+ swatch, rendering cog) | Heal Absorb Opacity
	local function HealOff()
		return C.Val("healAbsorbStyle", "clean") == "none"
	end
	O.AbsorbDrop(p, C, "Heal Absorb Style", nil, RF.HEAL_ABSORB_STYLE_ORDER, "healAbsorbStyle", "clean", function(v)
		C.Set("healAbsorbOpacity", v == "clean" and 50 or 75)
	end)
	p:Swatch("Heal Absorb Color", O.CGet(C, "healAbsorbColor", 0.8, 0.15, 0.15), O.CSet(C, "healAbsorbColor"),
		{ disabled = function()
			local st = C.Val("healAbsorbStyle", "clean")
			return st == "none" or st == "largeOutlinedStripes" or st == "largeOutlinedStripesR"
		end })
	p:Cog("Heal Absorb Rendering", {
		{ type = "dropdown", label = "Placement",
			items = function() return Items(O.EdgeItems(C, false)) end,
			get = function() return C.Val("healAbsorbEdgeMode", "overlay") end,
			labelFn = function() return LabelOf(O.EdgeItems(C, false), C.Val("healAbsorbEdgeMode", "overlay")) end,
			set = function(v) C.Set("healAbsorbEdgeMode", v) end },
		O.CS(C, "Backing Opacity", "healAbsorbBgOpacity", 25, 0, 100),
		O.CT(C, "Show Over Dispels", "healAbsorbOverDispel", false),
	})
	O.Slider(p, C, "Heal Absorb Opacity", nil, 5, 100, 1, "healAbsorbOpacity", 75, HealOff)
	-- Heal Absorb Bar (+ rendering cog) | Bar Height (+ swatch)
	local function HealBarPos()
		return C.Get("healAbsorbBarPosition") or "none"
	end
	O.Drop(p, C, "Heal Absorb Bar", nil, O.HEAL_ABSORB_BAR_POS, "healAbsorbBarPosition", "none")
	p:Cog("Heal Absorb Bar Rendering", {
		O.CD(C, "Vertical Grow", O.VERTICAL_GROW, "healAbsorbBarGrowDir", "up", nil,
			function() return not O.IsVerticalBar(HealBarPos()) end),
	}, { disabled = function() return not O.IsVerticalBar(HealBarPos()) end,
		disabledTip = "Only affects the vertical (Right/Left Edge) positions" })
	O.Slider(p, C, "Bar Height", nil, 1, 20, 1, "healAbsorbBarHeight", 4, function() return HealBarPos() == "none" end)
	O.BarSizeLabel(p, HealBarPos)
	p:Swatch("Heal Absorb Bar Color", O.CGet(C, "healAbsorbBarColor", 200 / 255, 29 / 255, 29 / 255),
		O.CSet(C, "healAbsorbBarColor", nil, true),
		{ alpha = true, active = function() return HealBarPos() ~= "none" end })
	-- Max Health Style (+ swatch, cog) | Max Health Opacity
	local function MaxOff()
		return C.Val("maxHealthStyle", "maxHealthStripes") == "none"
	end
	O.AbsorbDrop(p, C, "Max Health Style", nil, O.MAX_HEALTH_ORDER, "maxHealthStyle", "maxHealthStripes")
	p:Swatch("Max Health Color", O.CGet(C, "maxHealthColor", 0.7, 0.1, 0.1), O.CSet(C, "maxHealthColor"),
		{ disabled = function()
			local st = C.Val("maxHealthStyle", "maxHealthStripes")
			return st == "none" or st == "largeOutlinedStripes" or st == "largeOutlinedStripesR"
		end })
	p:Cog("Max Health Rendering", {
		O.CS(C, "Backing Opacity", "maxHealthBgOpacity", 100, 0, 100),
	})
	O.Slider(p, C, "Max Health Opacity", nil, 5, 100, 1, "maxHealthOpacity", 100, MaxOff)
	O.SecEnd(p, C)
end

-- Legacy boolean fallback (profiles from before the dropdown).
function O.OvershieldMode(C)
	local m = C.Get("overshieldMode")
	if m == nil then
		m = (C.Val("showOvershield", true) == false) and "never" or "always"
	end
	return m
end

function O.PowerOff(C)
	return not C.Val("powerShowForHealer", true) and not C.Val("powerShowForTank", true) and not C.Val("powerShowForDPS", false)
end

O.POWER_BORDER = { { "eui", "EllesmereUI" }, { "divider", "Divider" }, { "border", "Border" } }

function O.BuildPowerBar(p, C)
	p:Section("POWER BAR")
	O.SecStart(p, C, "powerBar")
	local function Off()
		return O.PowerOff(C)
	end
	-- Show Power Bar For | Power Height (+ cog)
	O.KeyChecks(p, C, "Show Power Bar For", nil,
		{ { "healer", "Healers", "powerShowForHealer", true }, { "tank", "Tanks", "powerShowForTank", true },
			{ "dps", "DPS", "powerShowForDPS", false } })
	O.Slider(p, C, "Power Height", nil, 1, 20, 1, "powerHeight", 4, Off)
	p:Cog("Power Height", {
		O.CT(C, "Icons Ignore Power Bar", "powerUniformAnchors", false,
			"Anchor icons and text as if no power bar existed, so frames with and without one line up identically."),
		O.CT(C, "Extend Health Bar Behind Power", "extendHealthBehindPower", false,
			"Health bar spans the full frame height and the power bar draws on top of it."),
	}, { disabled = Off, disabledTip = "This option requires Show Power Bar For to include a role." })
	-- Border Style | Border Size (+ swatch)
	O.Drop(p, C, "Border Style", nil, O.POWER_BORDER, "powerBorderStyle", "divider", Off)
	local function BorderOff()
		return Off() or C.Val("powerBorderStyle", "eui") == "eui"
	end
	O.Slider(p, C, "Border Size", nil, 0, 4, 1, "powerBorderSize", 1, BorderOff)
	p:Swatch("Border Color", O.CGet(C, "powerBorderColor", 0, 0, 0, "powerBorderAlpha", 1),
		O.CSet(C, "powerBorderColor", "powerBorderAlpha"),
		{ alpha = true, disabled = function() return BorderOff() or C.Val("powerBorderSize", 1) == 0 end })
	-- Smooth Power Bars | Background (+ power / custom swatches)
	O.Toggle(p, C, "Smooth Power Bars", nil, "smoothPowerBars", true, Off)
	O.Slider(p, C, "Background", nil, 0, 100, 1, "powerBgDarkness", 70, Off)
	p:Swatch("Power Colored Background. Power colors can be adjusted in Global Settings -> Colors.",
		function() local r, g, b = O.PlayerPowerColor() return r, g, b, 1 end, function() end,
		{ readonly = true,
			active = function() return C.Val("powerBgPowerColored", false) end,
			onClick = function() C.Set("powerBgPowerColored", true) return true end })
	p:Swatch("Custom Colored Background", O.CGet(C, "powerBgColor", 0, 0, 0), O.CSet(C, "powerBgColor"),
		{ active = function() return not C.Val("powerBgPowerColored", false) end,
			onClick = function()
				if C.Val("powerBgPowerColored", false) then
					C.Set("powerBgPowerColored", false)
					return true
				end
			end })
	O.SecEnd(p, C)
end

O.LEVEL_POS = {
	{ "name", "Attach to Name" }, { "nameDiv", "Attach to Name (Divider)" },
	{ "topleft", "Top Left" }, { "top", "Top" }, { "topright", "Top Right" },
	{ "left", "Left" }, { "center", "Center" }, { "right", "Right" },
	{ "bottomleft", "Bottom Left" }, { "bottom", "Bottom" }, { "bottomright", "Bottom Right" },
	{ "none", "None" },
}
O.HEAL_ABSORB_TEXT = { { "none", "None" }, { "short", "Short (240k)" }, { "amount", "Amount" } }

function O.BuildTextDisplay(p, C)
	p:Section("TEXT DISPLAY")
	O.SecStart(p, C, "textDisplay")
	-- Name Size (+ name cog) | Name Color
	O.Slider(p, C, "Name Size", nil, 6, 26, 1, "nameSize", 10)
	p:Cog("Name Text", {
		O.CS(C, "Max Characters (0=off)", "nameMaxLength", 15, 0, 30),
		O.CT(C, "Show Above Icons", "nameTextAboveIcons", false, "Render the name and health text above buff and debuff icons."),
	})
	p:Label("Name Color")
	O.ModeSwatches(p, C, "nameColorMode", "class", "nameCustomColor", 1, 1, 1)
	-- Name Position (+ offset cog) | Health Text (+ color swatches)
	O.Drop(p, C, "Name Position", nil, O.POS_NONE, "namePosition", "center")
	O.OffsetCog(p, C, "Name Offset", "nameOffsetX", "nameOffsetY", -500, 500)
	O.Drop(p, C, "Health Text", nil, O.HEALTH_TEXT, "healthTextMode", "none")
	O.ModeSwatches(p, C, "healthTextColorMode", "custom", "healthTextCustomColor", 1, 1, 1)
	-- Health Text Position (+ offset cog) | Health Text Size (off while Health Text is None)
	local function HTOff()
		return C.Val("healthTextMode", "none") == "none"
	end
	O.Drop(p, C, "Health Text Position", nil, O.POS, "healthTextPosition", "center", HTOff)
	O.OffsetCog(p, C, "Health Text Offset", "healthTextOffsetX", "healthTextOffsetY", -150, 150, -75, 75, HTOff)
	O.Slider(p, C, "Health Text Size", nil, 6, 26, 1, "healthTextSize", 9, HTOff)
	-- Level Position (+ offset cog) | Level Size
	local function LvlPos()
		return C.Val("levelTextPosition", "none")
	end
	local function LvlSpotOff()
		local pos = LvlPos()
		return pos == "none" or pos == "name" or pos == "nameDiv"
	end
	O.Drop(p, C, "Level Position",
		"Attach to Name puts the level in front of the name (\"60 Name\", Divider: \"60 | Name\") at the Name Size; a position shows it on its own spot in the name's color.",
		O.LEVEL_POS, "levelTextPosition", "none")
	O.OffsetCog(p, C, "Level Offset", "levelTextOffsetX", "levelTextOffsetY", -500, 500, nil, nil, LvlSpotOff)
	O.Slider(p, C, "Level Size", nil, 6, 26, 1, "levelTextSize", 10, LvlSpotOff)
	-- Power Text (+ swatches) | Power Text Size (+ position cog)
	local function PowerOff()
		return O.PowerOff(C)
	end
	local function PTOff()
		return PowerOff() or C.Val("powerTextMode", "none") == "none"
	end
	O.Drop(p, C, "Power Text", "Shows only on frames whose power bar shows.", O.POWER_TEXT, "powerTextMode", "none", PowerOff)
	O.ModeSwatches(p, C, "powerTextColorMode", "custom", "powerTextCustomColor", 1, 1, 1, true, PTOff)
	O.Slider(p, C, "Power Text Size", nil, 6, 26, 1, "powerTextSize", 8, PTOff)
	p:Cog("Power Text Position", {
		O.CD(C, "Position", O.POS, "powerTextPosition", "bottom"),
		O.CS(C, "Offset X", "powerTextOffsetX", 0, -150, 150),
		O.CS(C, "Offset Y", "powerTextOffsetY", 0, -75, 75),
	}, { icon = "directions", disabled = PTOff })
	-- Heal Absorb Text (+ swatches) | Heal Absorb Text Position (+ offset cog)
	local function HAOff()
		return C.Val("healAbsorbTextMode", "none") == "none"
	end
	O.Drop(p, C, "Heal Absorb Text", "Shows the heal absorb amount on the frame; hidden at zero.",
		O.HEAL_ABSORB_TEXT, "healAbsorbTextMode", "none")
	O.ModeSwatches(p, C, "healAbsorbTextColorMode", "custom", "healAbsorbTextCustomColor", 1, 0.3, 0.3)
	O.Drop(p, C, "Heal Absorb Text Position", nil, O.POS, "healAbsorbTextPosition", "center", HAOff)
	O.OffsetCog(p, C, "Heal Absorb Text Offset", "healAbsorbTextOffsetX", "healAbsorbTextOffsetY", -150, 150, -75, 75, HAOff)
	-- Heal Absorb Text Size | (blank)
	O.Slider(p, C, "Heal Absorb Text Size", nil, 6, 26, 1, "healAbsorbTextSize", 9, HAOff)
	p:Blank()
	O.SecEnd(p, C)
end

---------------------------------------------------------------------------
-- Visual sections, part 2 (retail VisualIndicators_Options.lua):
-- INDICATORS, DISPELS, TOP NAME BAR, FRIENDLY BOSS FRAMES, EXTRA FRAMES
-- (raid only), PET FRAMES, EXTRAS. Left out: WoW Forever Missing Buffs,
-- Ping Marker, Incoming Summon (no 5.4.8 API), the "less common" expander
-- (all rows are shown), Color Custom Borders (textured borders only).
---------------------------------------------------------------------------
-- Role icon styles (retail labels; the "blizzLight" key reads Modern Light).
O.ROLE_STYLE_LABEL = {
	none = "None", modern = "Modern", modernCircle = "Modern Circle", styled = "Styled",
	classicCircle = "Classic Circle", classic = "Classic", blizzDefault = "Blizz Default",
	blizzLight = "Modern Light", pixels = "Pixels",
}
O.ROLE_STYLE_ORDER = { "none", "modern", "blizzLight", "pixels", "modernCircle", "styled", "classicCircle", "classic", "blizzDefault" }

function O.RoleStyleList()
	local list = {}
	for _, key in ipairs(O.ROLE_STYLE_ORDER) do
		-- Only styles the engine knows (RF.ROLE_ICON_STYLE_ORDER).
		local known = false
		for _, k in ipairs(RF.ROLE_ICON_STYLE_ORDER or O.ROLE_STYLE_ORDER) do
			if k == key then
				known = true
			end
		end
		if known then
			list[#list + 1] = { key, O.ROLE_STYLE_LABEL[key] or key }
		end
	end
	return list
end

O.COMBAT_STYLE = {
	{ "standard", "Standard" }, { "class", "Class Theme" }, { "combat0", "Arcade" }, { "combat1", "Dungeoneer" },
	{ "combat2", "Classic" }, { "combat3", "Cross" }, { "combat4", "Circle" }, { "combat5", "Square" },
}
O.DISPEL_OVERLAY = {
	{ "none", "None" }, { "fill", "Fill Overlay" }, { "full", "Full Overlay" },
	{ "gradient", "Gradient Overlay" }, { "gradient_sharp", "Gradient Sharp" },
}
O.NONE_POS = { { "none", "None" } }
for i = 1, #O.POS do
	O.NONE_POS[#O.NONE_POS + 1] = O.POS[i]
end

-- Position dropdown whose "None" switches the indicator off (Marker,
-- Leader, Combat Icon, Type Icon): showKey on/off + posKey.
function O.ShowPosDrop(p, C, label, tip, showKey, showDef, posKey, posDef, after)
	local function Get()
		if not C.Val(showKey, showDef) then
			return "none"
		end
		return C.Val(posKey, posDef)
	end
	p:Dropdown(label, tip, function() return Items(O.NONE_POS) end, Get,
		function() return LabelOf(O.NONE_POS, Get()) end,
		function(v)
			if v == "none" then
				C.Set(showKey, false)
			else
				C.Set(showKey, true)
				C.Set(posKey, v)
			end
			if after then
				after(v)
			end
		end)
end

function O.BuildIndicators(p, C)
	p:Section("INDICATORS")
	O.SecStart(p, C, "indicators")
	local function RoleOff()
		return C.Val("roleIconStyle", "modern") == "none" and not C.Val("roleText", false)
	end
	-- Role Icons (+ cog) | Show Role
	O.Drop(p, C, "Role Icons", nil, O.RoleStyleList, "roleIconStyle", "modern")
	p:Cog("Role Icons", {
		O.CT(C, "Hide In Combat", "roleIconHideInCombat", false, "Hide role icons while you are in combat."),
		O.CT(C, "Show Behind Border", "roleIconBehindBorder", false,
			"Draw role icons behind the frame border, including the hover and target highlight."),
		O.CT(C, "Role Text", "roleText", false, "Shows Tank / Healer / DPS as text in the role colors instead of the role icon."),
		{ type = "color", label = "Tank Text Color", get = O.CGet(C, "roleTextTankColor", 59 / 255, 130 / 255, 246 / 255),
		  set = O.CSet(C, "roleTextTankColor"), disabled = function() return not C.Val("roleText", false) end },
		{ type = "color", label = "Healer Text Color", get = O.CGet(C, "roleTextHealerColor", 32 / 255, 201 / 255, 151 / 255),
		  set = O.CSet(C, "roleTextHealerColor"), disabled = function() return not C.Val("roleText", false) end },
		{ type = "color", label = "DPS Text Color", get = O.CGet(C, "roleTextDPSColor", 240 / 255, 100 / 255, 54 / 255),
		  set = O.CSet(C, "roleTextDPSColor"), disabled = function() return not C.Val("roleText", false) end },
	})
	O.KeyChecks(p, C, "Show Role", nil,
		{ { "tank", "Tank", "showRoleForTank", true }, { "healer", "Healer", "showRoleForHealer", true },
			{ "dps", "DPS", "showRoleForDPS", true } }, RoleOff)
	-- Role Position (+ offset cog) | Role Icon Size
	O.Drop(p, C, "Role Position", nil, O.POS, "roleIconPosition", "bottomleft", RoleOff)
	O.OffsetCog(p, C, "Role Icon Offset", "roleIconOffsetX", "roleIconOffsetY", -50, 50)
	O.Slider(p, C, "Role Icon Size", nil, 8, 30, 1, "roleIconSize", 14, RoleOff)
	-- Marker Position (+ offset cog) | Marker Size
	O.ShowPosDrop(p, C, "Marker Position", nil, "showRaidMarker", true, "raidMarkerPosition", "center")
	O.OffsetCog(p, C, "Marker Offset", "raidMarkerOffsetX", "raidMarkerOffsetY", -50, 50)
	O.Slider(p, C, "Marker Size", nil, 8, 40, 1, "raidMarkerSize", 16,
		function() return not C.Val("showRaidMarker", true) end)
	-- Missing Buffs (retail showMissingBuffs on the MoP raid buffs) | Size
	local function MissingOff() return not C.Val("showMissingBuffs", false) end
	O.ShowPosDrop(p, C, "Missing Buffs",
		"Shows the icon of each raid buff you can provide (stats, stamina, attack power, spell power, crit, mastery) that the member lacks from anyone.",
		"showMissingBuffs", false, "missingBuffsPosition", "top")
	p:Cog("Missing Buffs Settings", {
		O.CS(C, "X Offset", "missingBuffsOffsetX", 0, -50, 50, 1),
		O.CS(C, "Y Offset", "missingBuffsOffsetY", 0, -50, 50, 1),
		O.CT(C, "Only Out of Combat", "missingBuffsOnlyOutOfCombat", true, "Hide the missing buff icons while you are in combat."),
		O.CT(C, "Missing Buffs Glow", "missingBuffsGlow", false, "A pulsing glow around the missing buff icons."),
		{ type = "color", label = "Glow Color", get = O.CGet(C, "missingBuffsGlowColor", 1, 0.82, 0),
		  set = O.CSet(C, "missingBuffsGlowColor"), disabled = function() return not C.Val("missingBuffsGlow", false) end },
	}, { disabled = MissingOff, disabledTip = "Choose a Missing Buffs position first." })
	O.Slider(p, C, "Missing Buffs Size", nil, 8, 40, 1, "missingBuffsSize", 16, MissingOff)
	-- Ready Check / Rez (+ cog) | Icon Size. 5.4.8 has no summon API: the
	-- Incoming Summon row is left out.
	O.Drop(p, C, "Ready Check / Summon / Rez", nil, O.POS, "readyCheckPosition", "center")
	p:Cog("Ready Check / Summon / Rez", {
		O.CT(C, "Show Ready Check", "showReadyCheck", true),
		O.CT(C, "Show Incoming Resurrection", "showIncomingRez", true),
		O.CS(C, "Offset X", "readyCheckOffsetX", 0, -50, 50),
		O.CS(C, "Offset Y", "readyCheckOffsetY", 0, -50, 50),
	}, { icon = "directions" })
	O.Slider(p, C, "Icon Size", nil, 8, 40, 1, "readyCheckSize", 20)
	-- Status Text (+ cog) | Text Size (+ swatch)
	O.Drop(p, C, "Status Text", nil, O.NONE_POS, "statusTextPosition", "center")
	p:Cog("Status Text", {
		O.CT(C, "Show AFK", "statusShowAFK", false),
		O.CS(C, "Offset X", "statusTextOffsetX", 0, -50, 50),
		O.CS(C, "Offset Y", "statusTextOffsetY", 0, -50, 50),
	})
	O.Slider(p, C, "Text Size", nil, 6, 30, 1, "statusTextSize", 14)
	p:Swatch("Status Text Color", O.CGet(C, "statusTextColor", 1, 1, 1), O.CSet(C, "statusTextColor"))
	-- Leader Icon (+ cog) | Leader Icon Size
	O.ShowPosDrop(p, C, "Leader Icon", nil, "showLeaderIcon", false, "leaderIconPosition", "top")
	p:Cog("Leader Icon", {
		O.CT(C, "Show In Combat", "showLeaderIconInCombat", true,
			"Show the leader/assistant icon while you are in combat. Disable to hide it during combat."),
		O.CS(C, "Offset X", "leaderIconOffsetX", 0, -50, 50),
		O.CS(C, "Offset Y", "leaderIconOffsetY", 0, -50, 50),
	}, { icon = "directions" })
	O.Slider(p, C, "Leader Icon Size", nil, 8, 30, 1, "leaderIconSize", 14,
		function() return not C.Val("showLeaderIcon", false) end)
	-- Combat Icon (+ cog) | Combat Icon Size (+ swatch)
	O.ShowPosDrop(p, C, "Combat Icon", "Shows on members who are in combat.", "showCombatIndicator", false,
		"combatIndicatorPosition", "right")
	p:Cog("Combat Icon", {
		O.CD(C, "Style", O.COMBAT_STYLE, "combatIndicatorStyle", "standard"),
		{ type = "toggle", label = "Class Colored",
			tip = "Tint the combat icon by the member's class color. Not available for the Arcade/Dungeoneer/Classic/Cross/Circle/Square styles.",
			disabled = function()
				local st = C.Val("combatIndicatorStyle", "standard")
				return st:find("^combat%d") and true or false
			end,
			get = function() return C.Val("combatIndicatorColor", "custom") == "classcolor" end,
			set = function(v) C.Set("combatIndicatorColor", v and "classcolor" or "custom") end },
		O.CS(C, "Offset X", "combatIndicatorOffsetX", 0, -50, 50),
		O.CS(C, "Offset Y", "combatIndicatorOffsetY", 0, -50, 50),
	})
	O.Slider(p, C, "Combat Icon Size", nil, 8, 40, 1, "combatIndicatorSize", 16,
		function() return not C.Val("showCombatIndicator", false) end)
	p:Swatch("Combat Icon Color", O.CGet(C, "combatIndicatorCustomColor", 1, 0.2, 0.2), O.CSet(C, "combatIndicatorCustomColor"))
	-- Show Group Numbers | Number Size (raid only: the party has no groups)
	if not C.party then
		O.Toggle(p, C, "Show Group Numbers", nil, "showGroupNumbers", false)
		O.OffsetCog(p, C, "Group Number Offset", "groupNumberOffsetX", "groupNumberOffsetY", -50, 50)
		O.Slider(p, C, "Number Size", nil, 6, 30, 1, "groupNumberSize", 10)
		p:Swatch("Group Number Color", O.CGet(C, "groupNumberColor", 1, 1, 1, nil, 0.75),
			O.CSet(C, "groupNumberColor", nil, true), { alpha = true })
	end
	O.SecEnd(p, C)
end

O.DISPEL_SWATCHES = {
	{ "Magic", "dispelColorMagic", 0.354, 0.396, 0.74 },
	{ "Curse", "dispelColorCurse", 0.636, 0.0, 0.64 },
	{ "Disease", "dispelColorDisease", 0.71, 0.379, 0.0 },
	{ "Poison", "dispelColorPoison", 0.052, 0.586, 0.62 },
	{ "Bleed", "dispelColorBleed", 0.75, 0.15, 0.15 },
}

function O.BuildDispels(p, C)
	p:Section("DISPELS")
	O.SecStart(p, C, "dispels")
	-- Dispel Overlay | Overlay Opacity
	O.Drop(p, C, "Dispel Overlay", nil, O.DISPEL_OVERLAY, "dispelOverlay", "fill")
	O.Slider(p, C, "Overlay Opacity", nil, 5, 100, 1, "dispelOverlayOpacity", 100,
		function() return C.Val("dispelOverlay", "fill") == "none" end)
	-- Frame Border (+ cog) | Type Icon Position (+ icon cog)
	O.Slider(p, C, "Frame Border", nil, 0, 4, 1, "dispelBorderSize", 2)
	p:Cog("Dispel Border", {
		O.CS(C, "Debuff Icon Border", "dispelIconBorderSize", 2, -1, 4,
			"Thickness in physical pixels. -1 follows the Debuff Manager's Border setting, 0 hides the dispel color border."),
	})
	O.ShowPosDrop(p, C, "Type Icon Position", nil, "showDispelIcons", false, "dispelIconPosition", "center")
	p:Cog("Dispel Icon", {
		O.CS(C, "Icon Size", "dispelIconSize", 16, 8, 48),
		O.CS(C, "Offset X", "dispelIconOffsetX", 0, -50, 50),
		O.CS(C, "Offset Y", "dispelIconOffsetY", 0, -50, 50),
	}, { icon = "resize", disabled = function() return not C.Val("showDispelIcons", false) end,
		disabledTip = "This option requires a Type Icon Position other than None" })
	-- Dispel Colors | Only Show Dispellable
	p:Label("Dispel Colors", "Per-type alpha 0 hides that type's border and overlay.")
	-- Swatches go right to left: Bleed first, so they read Magic .. Bleed.
	for i = #O.DISPEL_SWATCHES, 1, -1 do
		O.DispelSwatch(p, C, O.DISPEL_SWATCHES[i])
	end
	p:Toggle("Only Show Dispellable", "Highlight only debuffs you can dispel (off: any dispellable debuff).",
		function() return not C.Val("dispelShowAll", true) end,
		function(v) C.Set("dispelShowAll", not v) end)
	O.SecEnd(p, C)
end

function O.DispelSwatch(p, C, d)
	p:Swatch(d[1], O.CGet(C, d[2], d[3], d[4], d[5]), O.CSet(C, d[2], nil, true), { alpha = true })
end

function O.BuildTopNameBar(p, C)
	p:Section("TOP NAME BAR")
	O.SecStart(p, C, "topNameBar")
	local function Off()
		return not C.Val("topNameBarEnabled", false)
	end
	O.Toggle(p, C, "Enable Top Name Bar", "A name bar on the frame's top edge (the in-frame name hides).", "topNameBarEnabled", false)
	p:Cog("Top Name Bar Options", {
		O.CT(C, "Divider", "topNameBarDivider", false, "Separates the name bar from the health bar with a border-size line."),
		O.CT(C, "Match Highlight Colors", "topNameBarDividerMatchColor", false, "The divider follows hover and target colors.",
			function() return not C.Val("topNameBarDivider", false) end),
	}, { disabled = Off, disabledTip = "Enable Top Name Bar first." })
	O.Slider(p, C, "Height", nil, 8, 40, 1, "topNameBarHeight", 20, Off)
	-- Background (+ swatch) | Text Size (+ offset cog)
	O.Slider(p, C, "Background", nil, 0, 100, 1, "topNameBarBgOpacity", 80, Off)
	p:Swatch("Background Color", O.CGet(C, "topNameBarBgColor", 17 / 255, 17 / 255, 17 / 255), O.CSet(C, "topNameBarBgColor"),
		{ disabled = Off })
	O.Slider(p, C, "Text Size", nil, 6, 30, 1, "topNameBarTextSize", 11, Off)
	O.OffsetCog(p, C, "Text Offset", "topNameBarTextOffsetX", "topNameBarTextOffsetY", -50, 50, nil, nil, Off)
	-- Alignment & Color (+ custom / class swatches) | Show on Bottom
	O.Drop(p, C, "Alignment & Color", nil, { { "center", "Center" }, { "left", "Left" }, { "right", "Right" } },
		"topNameBarTextAlign", "center", Off)
	local function Mode()
		return C.Val("topNameBarTextColorMode", "class")
	end
	p:Swatch("Custom Color", O.CGet(C, "topNameBarTextColor", 1, 1, 1), O.CSet(C, "topNameBarTextColor"),
		{ disabled = Off, active = function() return Mode() == "custom" end,
			onClick = function()
				if Mode() ~= "custom" then
					C.Set("topNameBarTextColorMode", "custom")
					return true
				end
			end })
	p:Swatch("Class Color", function() local r, g, b = O.PlayerClassColor() return r, g, b, 1 end, function() end,
		{ disabled = Off, readonly = true, active = function() return Mode() == "class" end,
			onClick = function() C.Set("topNameBarTextColorMode", "class") return true end })
	O.Toggle(p, C, "Show on Bottom", "Places the bar at the bottom of the frame instead of the top.", "topNameBarBottom", false, Off)
	O.SecEnd(p, C)
end

-- Move Frames button of a Free Move group (retail RF_OptMoveFramesButton):
-- a label cell with a button that toggles the group's drag overlay.
function O.MoveButton(p, label, isShown, setShown, allowed)
	local cell = p:Label(label)
	if not O.IsPage(p) or not cell then
		return
	end
	local btn = CreateFrame("Button", nil, cell)
	btn:SetSize(140, 26)
	btn:SetPoint("RIGHT", cell, "RIGHT", -20, 0)
	btn:SetFrameLevel(cell:GetFrameLevel() + 5)
	local bg = btn:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetTexture(0.077, 0.068, 0.058, 0.92)
	local edges = {}
	for i = 1, 4 do
		edges[i] = btn:CreateTexture(nil, "BORDER")
		edges[i]:SetTexture(1, 1, 1, 0.25)
	end
	edges[1]:SetPoint("TOPLEFT") edges[1]:SetPoint("TOPRIGHT") edges[1]:SetHeight(1)
	edges[2]:SetPoint("BOTTOMLEFT") edges[2]:SetPoint("BOTTOMRIGHT") edges[2]:SetHeight(1)
	edges[3]:SetPoint("TOPLEFT") edges[3]:SetPoint("BOTTOMLEFT") edges[3]:SetWidth(1)
	edges[4]:SetPoint("TOPRIGHT") edges[4]:SetPoint("BOTTOMRIGHT") edges[4]:SetWidth(1)
	local text = btn:CreateFontString(nil, "OVERLAY")
	text:SetFont(ns.FONT or "Fonts\\FRIZQT__.TTF", 13, "")
	text:SetPoint("CENTER")
	local function Shown()
		return isShown and isShown() or false
	end
	local function Update()
		text:SetText(Shown() and "Stop Moving" or "Move Frames")
		btn:SetAlpha(allowed() and 1 or 0.35)
	end
	btn:SetScript("OnEnter", function(self)
		cell:SetHover(true)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		if allowed() then
			GameTooltip:SetText("Drag the overlay to position the frames, then click again to lock", 1, 1, 1, 1, true)
		else
			GameTooltip:SetText("This option requires Position to be set to Free Move", 1, 1, 1, 1, true)
		end
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function()
		cell:SetHover(false)
		GameTooltip:Hide()
	end)
	btn:SetScript("OnClick", function()
		if not allowed() or not setShown then
			return
		end
		setShown(not Shown())
		Update()
	end)
	p:OnRefresh(Update)
	Update()
	return btn
end

O.GROUP_POSITION = { { "left", "Before First Group" }, { "right", "After Last Group" }, { "free", "Free Move" } }

-- FRIENDLY BOSS FRAMES (raid tab). Engine: RF.FB_Apply, RF.FB_IsMoverShown,
-- RF.FB_SetMoverShown (worker B2; the settings refresh runs ApplyAll too).
function O.FB()
	local prof = P()
	if not prof.friendlyBoss then
		prof.friendlyBoss = { display = "never", position = "right" }
	end
	return prof.friendlyBoss
end

function O.FBApply()
	if RF.FB_Apply then
		RF.FB_Apply()
	end
end

function O.BuildFriendlyBoss(p, C)
	p:Section("FRIENDLY BOSS FRAMES")
	local tipOff = "This option requires Add Friendly Boss Group to be set to Healers or Always."
	local function Off()
		return (O.FB().display or "never") == "never"
	end
	p:Dropdown("Add Friendly Boss Group", "Healable boss NPCs (boss1-5) as frames beside the raid.",
		function() return Items({ { "never", "Never" }, { "healers", "Healers" }, { "always", "Always" } }) end,
		function() return O.FB().display or "never" end,
		function() return LabelOf({ { "never", "Never" }, { "healers", "Healers" }, { "always", "Always" } }, O.FB().display or "never") end,
		function(v)
			O.FB().display = v
			O.FBApply()
		end)
	p:Cog("Friendly Boss Group", {
		{ type = "toggle", label = "Show in Dungeons",
			get = function() return O.FB().showInDungeons == true end,
			set = function(v)
				O.FB().showInDungeons = v and true or nil
				O.FBApply()
			end },
	}, { disabled = Off, disabledTip = tipOff })
	p:Dropdown("Position", tipOff, function() return Items(O.GROUP_POSITION) end,
		function() return O.FB().position or "right" end,
		function() return LabelOf(O.GROUP_POSITION, O.FB().position or "right") end,
		function(v)
			O.FB().position = v
			if v ~= "free" and RF.FB_SetMoverShown then
				RF.FB_SetMoverShown(false)
			end
			O.FBApply()
		end, nil, Off)
	-- Free Move Position (+ options cog) | Boss Health Color
	O.MoveButton(p, "Free Move Position", RF.FB_IsMoverShown, RF.FB_SetMoverShown,
		function() return not Off() and O.FB().position == "free" and not InCombatLockdown() end)
	p:Cog("Free Move Options", {
		{ type = "toggle", label = "Horizontal Frames",
			get = function() return O.FB().freeHorizontal == true end,
			set = function(v)
				O.FB().freeHorizontal = v
				O.FBApply()
				if RF.FB_IsMoverShown and RF.FB_IsMoverShown() and RF.FB_SetMoverShown then
					RF.FB_SetMoverShown(true)
				end
			end },
	}, { disabled = function() return Off() or O.FB().position ~= "free" end,
		disabledTip = "This option requires Position to be set to Free Move" })
	p:Label("Boss Health Color", nil, Off)
	p:Swatch("Boss Health Color",
		function()
			local c = O.FB().healthColor
			if c then
				return c.r, c.g, c.b, 1
			end
			return 23 / 255, 172 / 255, 49 / 255, 1
		end,
		function(r, g, b)
			O.FB().healthColor = { r = r, g = g, b = b }
			O.FBApply()
		end)
	-- Extra Width | Extra Height
	p:Slider("Extra Width", "Widens or narrows the boss frames relative to the raid frame size.", -50, 100, 1,
		function() return O.FB().extraWidth or 0 end,
		function(v)
			O.FB().extraWidth = v
			O.FBApply()
		end, Off)
	p:Slider("Extra Height", "Makes the boss frames taller or shorter relative to the raid frame size.", -50, 100, 1,
		function() return O.FB().extraHeight or 0 end,
		function(v)
			O.FB().extraHeight = v
			O.FBApply()
		end, Off)
end

-- EXTRA FRAMES (raid tab). Engine: RF.XF_Apply, RF.XF_IsMoverShown,
-- RF.XF_SetMoverShown, the hotkey button ERFExtraFramesBindBtn (worker B2).
function O.XF()
	local prof = P()
	if not prof.extraFrames then
		prof.extraFrames = { showTanks = false, position = "right", players = {} }
	end
	return prof.extraFrames
end

function O.XFApply()
	if RF.XF_Apply then
		RF.XF_Apply()
	end
	if RF.XF_IsMoverShown and RF.XF_IsMoverShown() and RF.XF_SetMoverShown then
		RF.XF_SetMoverShown(true)
	end
end

function O.XFConfigured()
	return O.XF().showTanks == true or (EllesmereUIDB and EllesmereUIDB.extraFramesKey) ~= nil
end

function O.XFGrowDir()
	local set = O.XF()
	return set.growDirection or (set.freeHorizontal and "RIGHT" or "DOWN")
end

function O.XFWrapList()
	local g = O.XFGrowDir()
	if g == "RIGHT" or g == "LEFT" then
		return { { "DOWN", "Down" }, { "UP", "Up" } }
	end
	return { { "RIGHT", "Right" }, { "LEFT", "Left" } }
end

function O.XFWrapDir()
	local wd = O.XF().wrapDirection
	local g = O.XFGrowDir()
	if g == "RIGHT" or g == "LEFT" then
		return (wd == "UP" or wd == "DOWN") and wd or "DOWN"
	end
	return (wd == "LEFT" or wd == "RIGHT") and wd or "RIGHT"
end

function O.BuildExtraFrames(p, C)
	p:Section("EXTRA FRAMES")
	local function Off()
		return not O.XFConfigured()
	end
	local function NotFree()
		return Off() or O.XF().position ~= "free"
	end
	-- Add to Extra Group Hotkey | Show Tanks in Extra Group (+ cog)
	p:Keybind("Add to Extra Group Hotkey",
		"Left-click to set a keybind. Right-click to unbind.\nPress the key while hovering a raid frame to add or remove that player from the Extra Frames group.",
		function() return EllesmereUIDB and EllesmereUIDB.extraFramesKey end,
		function(key)
			if not EllesmereUIDB then
				EllesmereUIDB = {}
			end
			local bindBtn = _G["ERFExtraFramesBindBtn"]
			if bindBtn then
				-- Override bindings cannot change in combat: keep the old key.
				if InCombatLockdown() then
					return
				end
				if key or EllesmereUIDB.extraFramesKey then
					ClearOverrideBindings(bindBtn)
				end
				if key then
					SetOverrideBindingClick(bindBtn, true, key, "ERFExtraFramesBindBtn")
				end
			end
			EllesmereUIDB.extraFramesKey = key
			if not O.XFConfigured() and RF.XF_SetMoverShown then
				RF.XF_SetMoverShown(false)
			end
		end)
	p:Toggle("Show Tanks in Extra Group",
		"Automatically duplicates the raid's tanks into the Extra Frames group. Shares the frame cap with hotkey picks.",
		function() return O.XF().showTanks == true end,
		function(v)
			O.XF().showTanks = v
			if not O.XFConfigured() and RF.XF_SetMoverShown then
				RF.XF_SetMoverShown(false)
			end
			O.XFApply()
		end)
	p:Cog("Show Tanks Options", {
		{ type = "toggle", label = "Exclude Myself",
			tip = "Skips your own frame when Show Tanks duplicates the raid's tanks. Hotkey picks can still add you.",
			get = function() return O.XF().excludeSelfTank == true end,
			set = function(v)
				O.XF().excludeSelfTank = v or nil
				O.XFApply()
			end },
	})
	-- Position | Free Move Position
	p:Dropdown("Position", nil, function() return Items(O.GROUP_POSITION) end,
		function() return O.XF().position or "right" end,
		function() return LabelOf(O.GROUP_POSITION, O.XF().position or "right") end,
		function(v)
			O.XF().position = v
			if v ~= "free" and RF.XF_SetMoverShown then
				RF.XF_SetMoverShown(false)
			end
			O.XFApply()
		end, nil, Off)
	O.MoveButton(p, "Free Move Position", RF.XF_IsMoverShown, RF.XF_SetMoverShown,
		function() return not NotFree() and not InCombatLockdown() end)
	-- Grow Direction | Wrap Direction (+ wrap cog), Free Move only
	p:Dropdown("Grow Direction", "Direction the frames are laid out.", function() return Items(O.GROWTH) end,
		O.XFGrowDir, function() return LabelOf(O.GROWTH, O.XFGrowDir()) end,
		function(v)
			local set = O.XF()
			set.growDirection = v
			-- Keep the legacy key coherent for exports / older reads.
			set.freeHorizontal = (v == "RIGHT" or v == "LEFT")
			O.XFApply()
		end, nil, NotFree)
	p:Dropdown("Wrap Direction", "Direction each new row or column stacks. Set Wrap After in the cog to enable wrapping.",
		function() return Items(O.XFWrapList()) end,
		O.XFWrapDir, function() return LabelOf(O.XFWrapList(), O.XFWrapDir()) end,
		function(v)
			O.XF().wrapDirection = v
			O.XFApply()
		end, nil, NotFree)
	p:Cog("Row Wrapping", {
		{ type = "slider", label = "Wrap After", min = 0, max = 20, step = 1,
			get = function() return O.XF().wrapAfter or 0 end,
			set = function(v)
				O.XF().wrapAfter = v
				O.XFApply()
			end },
	})
	-- Extra Width (+ cog) | Extra Height
	p:Slider("Extra Width", "Widens or narrows the extra frames relative to the raid frame size.", -50, 100, 1,
		function() return O.XF().extraWidth or 0 end,
		function(v)
			O.XF().extraWidth = v
			O.XFApply()
		end, Off)
	p:Cog("Extra Frame Size", {
		{ type = "toggle", label = "Auto Resize Indicators",
			get = function() return O.XF().autoResizeIndicators ~= false end,
			set = function(v)
				-- nil = on (additive key); false = off.
				if v then
					O.XF().autoResizeIndicators = nil
				else
					O.XF().autoResizeIndicators = false
				end
				O.XFApply()
			end },
	})
	p:Slider("Extra Height", "Makes the extra frames taller or shorter relative to the raid frame size.", -50, 100, 1,
		function() return O.XF().extraHeight or 0 end,
		function(v)
			O.XF().extraHeight = v
			O.XFApply()
		end, Off)
end

-- PET FRAMES (both tabs, each with its own switch). Per-tab placement keys
-- (retail PF.TAB_KEY): a tab reads the shared value until it sets its own.
O.PF_TAB_KEY = {
	party = { position = "party_position", extraWidth = "party_extraWidth", extraHeight = "party_extraHeight" },
	raid = { position = "raid_position", extraWidth = "raid_extraWidth", extraHeight = "raid_extraHeight" },
}

function O.PF()
	local prof = P()
	if not prof.petFrames then
		prof.petFrames = { position = "right" }
	end
	return prof.petFrames
end

function O.PFGet(tab, k)
	local raw = O.PF()
	local tk = O.PF_TAB_KEY[tab][k]
	if tk and raw[tk] ~= nil then
		return raw[tk]
	end
	return raw[k]
end

function O.PFSet(tab, k, v)
	O.PF()[O.PF_TAB_KEY[tab][k] or k] = v
end

function O.PFApply()
	if RF.PF_Apply then
		RF.PF_Apply()
	end
end

function O.PFOwnerSide()
	local side = O.PF().ownerSide
	if P().partyHorizontal then
		if side ~= "above" and side ~= "below" then
			side = "below"
		end
	elseif side ~= "left" and side ~= "right" then
		side = "right"
	end
	return side
end

function O.BuildPetFrames(p, C)
	p:Section("PET FRAMES")
	local tab = C.party and "party" or "raid"
	local function Off()
		return O.PF()[tab] ~= true
	end
	local positions = { { "left", "Before First Group" }, { "right", "After Last Group" }, { "free", "Free Move" } }
	if C.party then
		positions[#positions + 1] = { "owner", "Beside Owner" }
	end
	-- Show Pets | Position
	p:Toggle("Show Pets", "Adds your group's pets beside these frames, with their health, name, range and click-casting.",
		function() return not Off() end,
		function(v)
			O.PF()[tab] = v and true or false
			if not v and RF.PF_IsMoverShown and RF.PF_IsMoverShown(tab) and RF.PF_SetMoverShown then
				RF.PF_SetMoverShown(false)
			end
			O.PFApply()
		end)
	p:Dropdown("Position", nil, function() return Items(positions) end,
		function() return O.PFGet(tab, "position") or "right" end,
		function() return LabelOf(positions, O.PFGet(tab, "position") or "right") end,
		function(v)
			O.PFSet(tab, "position", v)
			if v ~= "free" and RF.PF_IsMoverShown and RF.PF_IsMoverShown(tab) and RF.PF_SetMoverShown then
				RF.PF_SetMoverShown(false)
			end
			O.PFApply()
		end, nil, Off)
	-- Extra Width | Extra Height
	p:Slider("Extra Width", "Widens or narrows the pet frames relative to the frame size.", -50, 100, 1,
		function() return O.PFGet(tab, "extraWidth") or 0 end,
		function(v)
			O.PFSet(tab, "extraWidth", v)
			O.PFApply()
			if RF.PF_PlaceMover then RF.PF_PlaceMover(tab) end
		end, Off)
	p:Slider("Extra Height", "Makes the pet frames taller or shorter relative to the frame size.", -50, 100, 1,
		function() return O.PFGet(tab, "extraHeight") or 0 end,
		function(v)
			O.PFSet(tab, "extraHeight", v)
			O.PFApply()
			if RF.PF_PlaceMover then RF.PF_PlaceMover(tab) end
		end, Off)
	-- Free Move Position | Pet Side (Beside Owner, party only)
	O.MoveButton(p, "Free Move Position",
		function() return RF.PF_IsMoverShown and RF.PF_IsMoverShown(tab) end,
		function(show) if RF.PF_SetMoverShown then RF.PF_SetMoverShown(show, tab) end end,
		function() return not Off() and O.PFGet(tab, "position") == "free" and not InCombatLockdown() end)
	if C.party then
		local sides = { { "right", "Right" }, { "left", "Left" }, { "above", "Above" }, { "below", "Below" } }
		p:Dropdown("Pet Side", "Beside stacked frames, above or below horizontal ones.",
			function()
				local items = Items(sides)
				for i = 1, #items do
					local across = items[i].value == "above" or items[i].value == "below"
					items[i].locked = function() return across ~= (P().partyHorizontal and true or false) end
					items[i].lockedTip = across and "This option requires Horizontal Frames"
						or "This option requires Horizontal Frames to be disabled"
				end
				return items
			end,
			O.PFOwnerSide, function() return LabelOf(sides, O.PFOwnerSide()) end,
			function(v)
				O.PF().ownerSide = v
				O.PFApply()
			end, nil,
			function() return Off() or O.PFGet(tab, "position") ~= "owner" end)
	end
end

O.TOOLTIP_MODE = {
	{ "always", "Always" }, { "outOfCombat", "Out of Combat" }, { "outOfBossCombat", "Out of Boss Combat" }, { "never", "Never" },
}
O.BUFF_TIPS = { { "hidden", "Hidden" }, { "shown", "Shown" }, { "cursor", "Shown At Cursor" }, { "combat", "Hidden In Combat" } }
O.STRATA = { { "BACKGROUND", "Background" }, { "LOW", "Low" }, { "MEDIUM", "Medium" }, { "HIGH", "High" }, { "DIALOG", "Dialog" } }
O.HM_MODE = { { "none", "None" }, { "party", "In Party" }, { "raid", "In Raid" }, { "both", "In Party & Raid" } }

-- Same derive as the runtime tooltip mode: unset follows showTooltip.
function O.TooltipMode(C)
	local m = C.Get("tooltipMode")
	if m ~= nil then
		return m
	end
	if C.Val("showTooltip", true) == false then
		return "never"
	end
	if EllesmereUIDB and EllesmereUIDB.showUnitTooltipsInCombat then
		return "always"
	end
	return "outOfCombat"
end

function O.HM()
	local prof = P()
	if not prof.healerMana then
		prof.healerMana = { mode = "none" }
	end
	return prof.healerMana
end

function O.HMRefresh()
	if RF.HM_Rebuild then
		RF.HM_Rebuild()
	end
end

function O.BuildExtras(p, C)
	p:Section("EXTRAS")
	O.SecStart(p, C, "rangeTooltip")
	-- Out of Range Alpha | Show Raid Frames Tooltip (+ cog)
	p:Slider("Out of Range Alpha", nil, 10, 100, 1,
		function() return floor(C.Val("oorAlpha", 0.4) * 100 + 0.5) end,
		function(v) C.Set("oorAlpha", v / 100) end)
	p:Dropdown("Show Raid & Party Frames Tooltip", "Controls when the tooltip appears as you hover a raid or party frame",
		function() return Items(O.TOOLTIP_MODE) end,
		function() return O.TooltipMode(C) end,
		function() return LabelOf(O.TOOLTIP_MODE, O.TooltipMode(C)) end,
		function(v) C.Set("tooltipMode", v) end)
	local function BuffTip()
		local v = C.Val("buffHideTooltips", true)
		if v == false then
			return "shown"
		end
		if v == "cursor" or v == "combat" then
			return v
		end
		return "hidden"
	end
	p:Cog("Tooltip Settings", {
		{ type = "dropdown", label = "Buff Tooltips",
			tip = "Tooltip behavior when hovering a buff/HoT icon on a raid or party frame.",
			items = function() return Items(O.BUFF_TIPS) end,
			get = BuffTip,
			labelFn = function() return LabelOf(O.BUFF_TIPS, BuffTip()) end,
			set = function(k)
				local v = k
				if k == "shown" then
					v = false
				elseif k == "hidden" then
					v = true
				end
				C.Set("buffHideTooltips", v)
			end },
	})
	-- Healer Mana Display (+ cog) | Healer Mana Text Color
	p:Dropdown("Healer Mana Display",
		"Shows a mana percentage row for every healer in your group as its own movable text display. Position it in Unlock Mode.",
		function() return Items(O.HM_MODE) end,
		function()
			local m = O.HM().mode
			return (m == "party" or m == "raid" or m == "both") and m or "none"
		end,
		function()
			local m = O.HM().mode
			return LabelOf(O.HM_MODE, (m == "party" or m == "raid" or m == "both") and m or "none")
		end,
		function(v)
			O.HM().mode = v
			O.HMRefresh()
		end)
	p:Cog("Healer Mana Display", {
		{ type = "slider", label = "Text Size", min = 8, max = 24, step = 1,
			get = function() return O.HM().textSize or 12 end,
			set = function(v) O.HM().textSize = v O.HMRefresh() end },
		{ type = "slider", label = "Spacing", tip = "Vertical space between rows.", min = 0, max = 12, step = 1,
			get = function() return O.HM().spacing or 2 end,
			set = function(v) O.HM().spacing = v O.HMRefresh() end },
		{ type = "dropdown", label = "Text Align",
			items = function() return Items({ { "LEFT", "Left" }, { "CENTER", "Center" }, { "RIGHT", "Right" } }) end,
			get = function() local a = O.HM().align return (a == "RIGHT" or a == "CENTER") and a or "LEFT" end,
			set = function(k) O.HM().align = k O.HMRefresh() end },
		{ type = "dropdown", label = "Text Growth", tip = "Which way the rows stack as healers are added.",
			items = function() return Items({ { "DOWN", "Down" }, { "UP", "Up" } }) end,
			get = function() return O.HM().growth == "UP" and "UP" or "DOWN" end,
			set = function(k) O.HM().growth = k O.HMRefresh() end },
		{ type = "toggle", label = "Show Names in Raid",
			tip = "Shows each healer's name before the number while in a raid. In a party the display always shows numbers only.",
			get = function() return O.HM().showNames ~= false end,
			set = function(v)
				if v then
					O.HM().showNames = nil
				else
					O.HM().showNames = false
				end
				O.HMRefresh()
			end },
		{ type = "toggle", label = "Class Colored Names",
			get = function() return O.HM().classNames ~= false end,
			set = function(v)
				if v then
					O.HM().classNames = nil
				else
					O.HM().classNames = false
				end
				O.HMRefresh()
			end },
	})
	p:Label("Healer Mana Text Color")
	p:Swatch("Custom Colored",
		function()
			local c = O.HM().color
			return (c and c.r) or 1, (c and c.g) or 1, (c and c.b) or 1, 1
		end,
		function(r, g, b)
			local hm = O.HM()
			hm.color = { r = r, g = g, b = b }
			hm.colorMode = "custom"
			O.HMRefresh()
		end,
		{ active = function() return O.HM().colorMode ~= "power" end,
			onClick = function()
				local hm = O.HM()
				if hm.colorMode == "power" then
					hm.colorMode = "custom"
					O.HMRefresh()
					return true
				end
			end })
	p:Swatch("Power Colored", function() local r, g, b = RF.PowerColor("MANA") return r, g, b, 1 end, function() end,
		{ readonly = true, active = function() return O.HM().colorMode == "power" end,
			onClick = function()
				O.HM().colorMode = "power"
				O.HMRefresh()
				return true
			end })
	-- Hide Blizzard Party Panel | Status Colors
	p:Toggle("Hide Blizzard Party Panel", "Hides the collapsed Blizzard party/raid sidebar panel on the side of the screen.",
		function() return EllesmereUIDB and EllesmereUIDB.hideBlizzardPartyFrame or false end,
		function(v)
			if not EllesmereUIDB then
				EllesmereUIDB = {}
			end
			EllesmereUIDB.hideBlizzardPartyFrame = v
			if ns._applyHideBlizzardPartyFrame then
				ns._applyHideBlizzardPartyFrame()
			end
		end)
	p:Label("Status Colors", "Health bar background of offline and dead members.")
	p:Swatch("Dead", O.CGet(C, "statusColorDead", 0x24 / 255, 0x17 / 255, 0x17 / 255), O.CSet(C, "statusColorDead"))
	p:Swatch("Offline", O.CGet(C, "statusColorOffline", 0x66 / 255, 0x66 / 255, 0x66 / 255), O.CSet(C, "statusColorOffline"))
	-- Right Mouse Camera Unlock | Frame Strata
	O.Toggle(p, C, "Right Mouse Camera Unlock",
		"Allows free camera movement while holding and dragging right mouse button over raid frames. Right-click tap still opens the unit menu.",
		"freeRightClickCamera", false)
	O.Drop(p, C, "Frame Strata", "Controls the display order of raid and party frames. Set higher to show above other elements.",
		O.STRATA, "frameStrata", "LOW")
	O.SecEnd(p, C)
end

-- Every visual section, in retail order (raid and party pages).
function O.BuildVisualSections(p, C)
	O.BuildHealthBar(p, C)
	O.BuildAbsorbs(p, C)
	O.BuildPowerBar(p, C)
	O.BuildTextDisplay(p, C)
	O.BuildIndicators(p, C)
	O.BuildDispels(p, C)
	O.BuildTopNameBar(p, C)
	if not C.party then
		O.BuildFriendlyBoss(p, C)
		O.BuildExtraFrames(p, C)
	end
	O.BuildPetFrames(p, C)
	O.BuildExtras(p, C)
end

---------------------------------------------------------------------------
-- Party Frames tab: RAID SYNC AND SOLO, FRAMES, PARTY TARGETS, PORTRAIT
---------------------------------------------------------------------------
function O.SectionHasCustom(section)
	local prof = P()
	for key, sec in pairs(RF._PARTY_KEY_SECTION) do
		if sec == section and rawget(prof, "party_" .. key) ~= nil then
			return true
		end
	end
	return false
end

function O.SetSynced(section, synced)
	local prof = P()
	prof.partySyncSections = prof.partySyncSections or {}
	prof.partySyncSections[section] = synced and true or false
end

function O.BuildRaidSync(p, C)
	p:Section("RAID SYNC AND SOLO")
	-- Use Raid Settings For (checked = synced) | Show When Solo (+ cog)
	local function Synced(k)
		local ss = P().partySyncSections
		if not ss then
			return true
		end
		return ss[k] ~= false
	end
	local items = {}
	for _, sec in ipairs(RF._PARTY_SECTION_ORDER) do
		items[#items + 1] = { value = sec, name = RF._PARTY_SECTION_LABELS[sec] or sec }
	end
	p:MultiSelect("Use Raid Settings For",
		"Checked sections use the Raid tab settings. Uncheck a section to give the party frames their own settings for it.",
		function() return items end, Synced,
		function(k)
			if Synced(k) then
				O.SetSynced(k, false)
				return
			end
			-- Re-syncing discards custom party values; ask first if any exist.
			if O.SectionHasCustom(k) and ns.ShowConfirmPopup then
				ns.ShowConfirmPopup({
					title = "Re-sync " .. (RF._PARTY_SECTION_LABELS[k] or k) .. "?",
					message = "This will discard your custom party settings for this section and use raid settings instead.",
					confirmText = "Sync",
					cancelText = "Cancel",
					onConfirm = function()
						local prof = P()
						for key, sec in pairs(RF._PARTY_KEY_SECTION) do
							if sec == k then
								prof["party_" .. key] = nil
							end
						end
						O.SetSynced(k, true)
						O.ApplyNow()
					end,
				})
				return
			end
			O.SetSynced(k, true)
		end,
		function() return O.CheckedLabel(items, Synced) end)
	local function SoloOff()
		local prof = P()
		return prof.showWhenSolo and not prof.partyShowWhenSolo
	end
	p:Toggle("Show When Solo", "Show the party frames when you are not in a group. Not available while only the Raid tab Show When Solo is on.",
		function() return P().partyShowWhenSolo and true or false end,
		function(v) P().partyShowWhenSolo = v end, SoloOff)
	p:Cog("Show When Solo", {
		{ type = "toggle", label = "Center When Solo",
			tip = "When you are solo, center the player frame on the party frame instead of anchoring it at the top.",
			get = function() return P().partyCenterWhenSolo or false end,
			set = function(v) P().partyCenterWhenSolo = v end },
	}, { disabled = SoloOff, disabledTip = "Not available while only the Raid tab Show When Solo is on." })
end

O.PARTY_GROWTH = { { "default", "Default" }, { "reversed", "Reversed" }, { "centered", "Centered" } }

function O.BuildPartyFrames(p, C)
	p:Section("FRAMES")
	local prof = P
	-- Frame Width | Frame Height
	p:Slider("Frame Width", nil, 40, 300, 1, function() return prof().partyFrameWidth or 125 end,
		function(v) prof().partyFrameWidth = v end)
	p:Slider("Frame Height", nil, 20, 150, 1, function() return prof().partyFrameHeight or 60 end,
		function(v) prof().partyFrameHeight = v end)
	-- Horizontal Frames | Sort By (+ Class Sorting cog)
	p:Toggle("Horizontal Frames", nil, function() return prof().partyHorizontal and true or false end,
		function(v) prof().partyHorizontal = v end)
	O.SortBy(p, "Sort By",
		function() return prof().partySortMode or "ROLE" end,
		function(v) prof().partySortMode = v end,
		function() return prof().partyRoleOrder or prof().roleOrder end,
		function(ro) prof().partyRoleOrder = ro end)
	O.ClassSortCog(p, "partyPrioritizeClass", "partyClassOrder")
	-- Self Position | Hide Self
	local function SelfPos()
		if prof().partySelfLast then
			return "last"
		end
		if prof().partyShowSelfFirst ~= false then
			return "first"
		end
		return "none"
	end
	p:Dropdown("Self Position", nil, function() return Items(O.SELF_POS) end, SelfPos,
		function() return LabelOf(O.SELF_POS, SelfPos()) end,
		function(v)
			prof().partyShowSelfFirst = v == "first"
			prof().partySelfLast = v == "last"
		end)
	p:Toggle("Hide Self", nil, function() return prof().partyHideSelf and true or false end,
		function(v) prof().partyHideSelf = v end)
	-- Auto Resize Icons | Frame Spacing
	O.KeyChecks(p, C, "Auto Resize Icons",
		"Indicators & Auras: icons and texts follow the party frame size. Tracked Buffs: the Buff Manager icons do too.",
		{ { "indicators", "Indicators & Auras", "partyAutoResizeIndicators", false },
			{ "trackedBuffs", "Tracked Buffs", "partyAutoResizeTrackedBuffs", true } })
	p:Slider("Frame Spacing", nil, -1, 15, 1,
		function()
			local v = prof().partyCellSpacing
			if v == nil then
				v = prof().cellSpacing or 2
			end
			return v
		end,
		function(v) prof().partyCellSpacing = v end)
	p:Cog("Party Frame Spacing Settings", {
		{ type = "toggle", label = "Compact Mode",
		  tip = "Party frames overlap by the border size, so neighbours share one border line. Needs a border size above 0.",
		  get = function() return prof().partyCompactMode == true end,
		  set = function(v) prof().partyCompactMode = v or nil end },
	})
	-- Frame Growth (view over the tri-state partyFlipGrowth) | Party Frames in Small Raids
	local function Growth()
		local v = prof().partyFlipGrowth
		if v == "centered" then
			return "centered"
		end
		return v == true and "reversed" or "default"
	end
	p:Dropdown("Frame Growth",
		"Default grows down or right, Reversed grows up or left, and Centered keeps the frames centered as the party size changes.",
		function() return Items(O.PARTY_GROWTH) end, Growth,
		function() return LabelOf(O.PARTY_GROWTH, Growth()) end,
		function(v)
			if v == "centered" then
				prof().partyFlipGrowth = "centered"
			elseif v == "reversed" then
				prof().partyFlipGrowth = true
			else
				prof().partyFlipGrowth = false
			end
		end)
	p:Toggle("Party Frames in Small Raids", "In raid groups under 10 players, show group 1 as party frames and hide everyone else.",
		function() return prof().partySmallRaid and true or false end,
		function(v) prof().partySmallRaid = v end)
end

-- Page key of the Party Frames tab: rows that exist only while Party
-- Targets is on or for a Portrait Mode (retail hides them).
function O.PartyPageKey()
	local prof = P()
	if not prof then
		return "party"
	end
	return "party:" .. (prof.partyShowTargets and "t" or "-") .. ":" .. tostring(prof.partyPortraitStyle or "none")
end

O.PT_FILL = { { "class", "Class Color" }, { "dark", "Dark Mode" }, { "classic", "Classic" }, { "custom", "Custom Color" } }
O.PT_SIDES = { { "top", "Top" }, { "bottom", "Bottom" }, { "left", "Left" }, { "right", "Right" } }

function O.PTRefresh()
	if RF.PT_Refresh then
		RF.PT_Refresh()
	end
end

-- The side the target frames take: the saved one, else right of stacked
-- frames / below horizontal ones (retail PT_ShownSide).
function O.PTShownSide(defaultOnly)
	local prof = P()
	if not defaultOnly and prof.partyTargetPosition then
		return prof.partyTargetPosition
	end
	return prof.partyHorizontal and "bottom" or "right"
end

function O.BuildPartyTargets(p, C)
	p:Section("PARTY TARGETS")
	local prof = P
	local DARK_TIP = "Not available in Dark Mode."
	-- Enable Party Targets | Include Own Target
	p:Toggle("Enable Party Targets",
		"Show a smaller secure target button beside each party frame. Left-click a button to target that party member's current target.",
		function() return prof().partyShowTargets and true or false end,
		function(v)
			prof().partyShowTargets = v
			if RF.PT_SetEnabled then
				RF.PT_SetEnabled(v)
			end
			O.Rebuild()
		end)
	if not prof().partyShowTargets then
		p:Blank()
		return
	end
	p:Toggle("Include Own Target", "Also show your own target beside your frame. Not available with Hide Self.",
		function() return prof().partyTargetIncludeSelf and true or false end,
		function(v)
			prof().partyTargetIncludeSelf = v
			if RF.PT_SetIncludeSelf then
				RF.PT_SetIncludeSelf(v)
			end
		end,
		function() return prof().partyHideSelf == true end)
	-- Fill Color (+ swatch) | Background (+ swatches)
	local function Mode()
		return prof().partyTargetHealthColorMode or "class"
	end
	local function Dark()
		return Mode() == "dark"
	end
	p:Dropdown("Fill Color", "Class Color uses the class color for players and the reaction color for NPCs.",
		function() return Items(O.PT_FILL) end, Mode, function() return LabelOf(O.PT_FILL, Mode()) end,
		function(v)
			prof().partyTargetHealthColorMode = v
			O.PTRefresh()
		end)
	p:Swatch("Only available with Custom fill color",
		function()
			local c = prof().partyTargetCustomFillColor
			if c then
				return c.r, c.g, c.b, 1
			end
			return 37 / 255, 193 / 255, 29 / 255, 1
		end,
		function(r, g, b)
			prof().partyTargetCustomFillColor = { r = r, g = g, b = b }
			O.PTRefresh()
		end, { disabled = function() return Mode() ~= "custom" end })
	p:Slider("Background", DARK_TIP, 0, 100, 1, function() return prof().partyTargetBgDarkness or 50 end,
		function(v)
			prof().partyTargetBgDarkness = v
			O.PTRefresh()
		end, Dark)
	p:Swatch("Class Colored Background", function() local r, g, b = O.PlayerClassColor() return r, g, b, 1 end, function() end,
		{ readonly = true, disabled = Dark,
			active = function() return prof().partyTargetBgClassColored and true or false end,
			onClick = function()
				prof().partyTargetBgClassColored = true
				O.PTRefresh()
				return true
			end })
	p:Swatch("Custom Background Color",
		function()
			local c = prof().partyTargetCustomBgColor
			if c then
				return c.r, c.g, c.b, 1
			end
			return 17 / 255, 17 / 255, 17 / 255, 1
		end,
		function(r, g, b)
			prof().partyTargetCustomBgColor = { r = r, g = g, b = b }
			O.PTRefresh()
		end,
		{ disabled = Dark, active = function() return not prof().partyTargetBgClassColored end,
			onClick = function()
				if prof().partyTargetBgClassColored then
					prof().partyTargetBgClassColored = false
					O.PTRefresh()
					return true
				end
			end })
	-- Width | Height (absolute, not scaled with the party frames)
	p:Slider("Width", nil, 20, 300, 1, function() return prof().partyTargetWidth or 70 end,
		function(v) prof().partyTargetWidth = v end)
	p:Slider("Height", nil, 10, 150, 1, function() return prof().partyTargetHeight or 33 end,
		function(v) prof().partyTargetHeight = v end)
	-- Position (+ offsets cog) | (blank). A pick of the default side is stored as unset.
	p:Dropdown("Position", "Right by default, or Bottom with Horizontal Frames.",
		function() return Items(O.PT_SIDES) end,
		function() return O.PTShownSide() end,
		function() return LabelOf(O.PT_SIDES, O.PTShownSide()) end,
		function(v) prof().partyTargetPosition = (v ~= O.PTShownSide(true)) and v or nil end)
	p:Cog("Target Position Offsets", {
		{ type = "slider", label = "X Offset", min = -100, max = 100, step = 1,
			get = function() return prof().partyTargetOffsetX or 0 end,
			set = function(v) prof().partyTargetOffsetX = v end },
		{ type = "slider", label = "Y Offset", min = -100, max = 100, step = 1,
			get = function() return prof().partyTargetOffsetY or 0 end,
			set = function(v) prof().partyTargetOffsetY = v end },
	}, { icon = "directions" })
	p:Blank()
end

O.PORTRAIT_MODE = { { "none", "None" }, { "attached", "Attached" }, { "detached", "Detached" } }
-- Art Style: retail also offers class art sets (media not on this client);
-- "Class" keeps the saved class style.
O.PORTRAIT_ART = { { "3d", "3D Portrait" }, { "2d", "2D Portrait" }, { "class", "Class" } }
O.PORTRAIT_SIDE = {
	{ "left", "Left" }, { "right", "Right" }, { "top", "Top" },
	{ "insideleft", "Inside Left" }, { "insideright", "Inside Right" }, { "insidecenter", "Inside Center" },
}
-- Shapes need mask textures, which 5.4.8 does not have: the plain ones only.
O.PORTRAIT_SHAPE = { { "none", "None" }, { "portrait", "Portrait" }, { "square", "Square" } }

function O.IsInside(side)
	return side == "insideleft" or side == "insideright" or side == "insidecenter"
end

function O.PtRefresh()
	if RF.RF_PtRefreshAll then
		RF.RF_PtRefreshAll()
	end
end

function O.BuildPortrait(p, C)
	p:Section("PORTRAIT")
	local prof = P
	local function Style()
		return prof().partyPortraitStyle or "none"
	end
	local function Art()
		return prof().partyPortraitMode or "2d"
	end
	-- An Art Style pick, with the side effects of leaving / entering 3D.
	local function SetArt(v)
		local pr = prof()
		pr.partyPortraitMode = v
		if v == "3d" and pr.partyPortraitStyle == "detached" then
			pr.partyPortraitShape = "none"
		end
		if v ~= "3d" then
			if pr.partyPortraitShape == "none" then
				pr.partyPortraitShape = "portrait"
			end
			if O.IsInside(pr.partyPortraitSide) then
				pr.partyPortraitSide = "left"
			end
		end
		O.PtRefresh()
	end
	-- Portrait Mode | Art Style
	p:Dropdown("Portrait Mode", "Attached widens each frame by the portrait.",
		function() return Items(O.PORTRAIT_MODE) end, Style, function() return LabelOf(O.PORTRAIT_MODE, Style()) end,
		function(v)
			local pr = prof()
			local prev = pr.partyPortraitStyle or "none"
			if v == prev then
				return
			end
			if v == "detached" and Art() == "3d" then
				pr.partyPortraitShape = "none"
			end
			if v ~= "detached" then
				pr.partyPortraitSize = 0
				local sd = pr.partyPortraitSide
				if sd == "top" or O.IsInside(sd) then
					pr.partyPortraitSide = "left"
				end
			end
			pr.partyPortraitStyle = v
			O.PtRefresh()
			O.Rebuild()
		end)
	p:Dropdown("Art Style", "Portrait Mode is set to None",
		function() return Items(O.PORTRAIT_ART) end, Art, function() return LabelOf(O.PORTRAIT_ART, Art()) end,
		function(v)
			if v == "3d" and Art() ~= "3d" and not (EllesmereUIDB and EllesmereUIDB.dismissed3DWarning) and ns.ShowConfirmPopup then
				ns.ShowConfirmPopup({
					title = "3D Portraits",
					message = "3D portraits may cause a slight loss in performance efficiency. Do you want to enable them?",
					confirmText = "Enable",
					cancelText = "Cancel",
					onConfirm = function()
						if not EllesmereUIDB then
							EllesmereUIDB = {}
						end
						EllesmereUIDB.dismissed3DWarning = true
						SetArt("3d")
						O.ApplyNow()
					end,
				})
				return
			end
			SetArt(v)
		end, nil, function() return Style() == "none" end)
	if Style() == "none" then
		return
	end
	-- Size (+ zoom cog) | Position (+ offsets cog)
	local function Side()
		return prof().partyPortraitSide or "left"
	end
	p:Slider("Size", "Only available in Detached or Inside modes", -50, 100, 1,
		function() return prof().partyPortraitSize or 0 end,
		function(v) prof().partyPortraitSize = v end,
		function() return Style() ~= "detached" and not O.IsInside(Side()) end)
	p:Cog("Portrait Zoom", {
		{ type = "slider", label = "2D Zoom", min = 50, max = 100, step = 1,
			get = function() return prof().partyPortraitArtScale or 100 end,
			set = function(v) prof().partyPortraitArtScale = v end },
		{ type = "slider", label = "3D Zoom", min = 100, max = RF.RF_PT_ZOOM3D_MAX or 500, step = 1,
			tip = "Above 300 the camera pulls back to show the whole character.",
			get = function() return prof().partyPortrait3dZoom or 100 end,
			set = function(v) prof().partyPortrait3dZoom = v end },
		{ type = "slider", label = "Character Size", min = 50, max = 200, step = 1,
			tip = "Scales the 3D character from the portrait's bottom edge, for use with the full-body 3D Zoom range above 300.",
			disabled = function() return Style() ~= "detached" or not O.IsInside(Side()) end,
			get = function() return prof().partyPortraitCharScale or 100 end,
			set = function(v) prof().partyPortraitCharScale = v end },
	})
	p:Dropdown("Position", nil,
		function()
			local items = Items(O.PORTRAIT_SIDE)
			for i = 1, #items do
				local v = items[i].value
				items[i].locked = function()
					if v == "top" and Style() == "attached" then
						return true
					end
					if O.IsInside(v) then
						return Art() ~= "3d" or Style() ~= "detached"
					end
					return false
				end
				if v == "top" then
					items[i].lockedTip = "Top position is only available in Detached mode"
				elseif O.IsInside(v) then
					items[i].lockedTip = "Inside positions require 3D Art Style and Detached mode"
				end
			end
			return items
		end,
		Side, function() return LabelOf(O.PORTRAIT_SIDE, Side()) end,
		function(v) prof().partyPortraitSide = v end)
	p:Cog("Portrait Position Offsets", {
		{ type = "slider", label = "X Offset", min = -100, max = 100, step = 1,
			get = function() return prof().partyPortraitX or 0 end,
			set = function(v) prof().partyPortraitX = v end },
		{ type = "slider", label = "Y Offset", min = -100, max = 100, step = 1,
			get = function() return prof().partyPortraitY or 0 end,
			set = function(v) prof().partyPortraitY = v end },
	}, { icon = "directions", disabled = function() return Style() ~= "detached" end,
		disabledTip = "This option requires Portrait Mode to be set to Detached." })
	if Style() ~= "detached" then
		return
	end
	-- Shape | Shape Border (+ settings cog)
	p:Dropdown("Shape", nil,
		function()
			local items = Items(O.PORTRAIT_SHAPE)
			items[1].locked = function() return Art() ~= "3d" end
			items[1].lockedTip = "None shape requires 3D Art Style"
			return items
		end,
		function() return prof().partyPortraitShape or "portrait" end,
		function() return LabelOf(O.PORTRAIT_SHAPE, prof().partyPortraitShape or "portrait") end,
		function(v) prof().partyPortraitShape = v end)
	p:Label("Shape Border")
	p:Cog("Shape Border Settings", {
		{ type = "slider", label = "Size", min = 1, max = 7, step = 1,
			get = function() return prof().partyPortraitBorderSize or 7 end,
			set = function(v) prof().partyPortraitBorderSize = v end },
		{ type = "slider", label = "Opacity", min = 0, max = 100, step = 1,
			get = function() return prof().partyPortraitBorderOpacity or 100 end,
			set = function(v) prof().partyPortraitBorderOpacity = v end },
	})
	local function ClassOn()
		return prof().partyPortraitBorderClassColor ~= false
	end
	p:Swatch("Custom Color",
		function()
			local c = prof().partyPortraitBorderColor or { r = 0, g = 0, b = 0 }
			return c.r, c.g, c.b, 1
		end,
		function(r, g, b) prof().partyPortraitBorderColor = { r = r, g = g, b = b } end,
		{ active = function() return not ClassOn() end,
			onClick = function()
				if ClassOn() then
					prof().partyPortraitBorderClassColor = false
					return true
				end
			end })
	p:Swatch("Class Colored", function() local r, g, b = O.PlayerClassColor() return r, g, b, 1 end, function() end,
		{ readonly = true, active = ClassOn,
			onClick = function()
				prof().partyPortraitBorderClassColor = true
				return true
			end })
end

---------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------
O.raidCtx = O.NewCtx(false)
O.partyCtx = O.NewCtx(true)

function O.BuildRaidPage(p)
	O.TrackTab(p, "raid")
	local C = O.raidCtx
	O.BuildFrameSizes(p, C)
	O.BuildFrameDisplay(p, C)
	O.BuildLayout(p, C)
	O.BuildVisualSections(p, C)
end

function O.BuildPartyPage(p)
	O.TrackTab(p, "party")
	local C = O.partyCtx
	O.BuildRaidSync(p, C)
	O.BuildPartyFrames(p, C)
	O.BuildPartyTargets(p, C)
	O.BuildPortrait(p, C)
	O.BuildVisualSections(p, C)
end

-- Buff Manager / Debuff Manager / Click Casting: built by their own files
-- (EllesmereUI.RFO_Build<Name>Page, RFO_<Name>Header, RFO_<Name>PageKey).
function O.ManagerTab(key, name, description, id)
	local def = { key = key, name = name, description = description }
	def.build = function(p)
		-- Buff / Debuff Manager: the raid preview stays up so edited
		-- indicators are visible (Click Casting shows none).
		if id ~= "ClickCast" then
			O.TrackTab(p, "raid")
		end
		local build = ns["RFO_Build" .. id .. "Page"]
		if build then
			build(p)
		else
			p:Section(name)
			p:Label(name .. " is not available.")
		end
	end
	if ns["RFO_" .. id .. "Header"] then
		def.header = ns["RFO_" .. id .. "Header"]
	end
	if ns["RFO_" .. id .. "PageKey"] then
		def.pageKey = ns["RFO_" .. id .. "PageKey"]
	end
	return def
end

---------------------------------------------------------------------------
-- Module (EllesmereUI: Core Addons > Raid Frames)
---------------------------------------------------------------------------
ns.RegisterSettingsModule({
	key = "raidFrames",
	name = "Raid & Party Frames",
	group = "Core Addons",
	tabs = {
		{ key = "frames", name = "Raid", description = "Configure raid frame appearance and behavior.",
			build = O.BuildRaidPage, header = O.PreviewHeader, pageKey = O.RaidPageKey },
		{ key = "party", name = "Party Frames", description = "Configure party frame appearance and behavior.",
			build = O.BuildPartyPage, header = O.PreviewHeader, pageKey = O.PartyPageKey },
		O.ManagerTab("buffs", "Buff Manager", "Track buffs and HoTs on your raid and party frames.", "BuffManager"),
		O.ManagerTab("debuffs", "Debuff Manager", "Choose which debuffs show on your raid and party frames.", "DebuffManager"),
		O.ManagerTab("clickCast", "Click Casting", "Cast spells by clicking raid and party frames.", "ClickCast"),
	},
	reset = function() ERF:ResetProfile() end,
	resetTip = "Set all Raid & Party Frames settings back to default. Frame positions are reset too.",
	onEnter = function()
		O.view.entered = true
		O.UpdatePreview()
	end,
	onLeave = function()
		O.view.entered = false
		O.UpdatePreview()
	end,
})
