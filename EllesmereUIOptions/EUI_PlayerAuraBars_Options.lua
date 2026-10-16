-- Settings tab Unit Frames > Player Aura Bars (retail
-- EUI_PlayerAuraBars_ManagerPages.lua: same sections, labels, tooltips and
-- keys, built with this window's Page API).
--
-- Layout: retail shows a tile sidebar (BUFF BARS / DEBUFF BARS) next to the
-- selected bar. Here the content header holds the same choices: the Editing
-- Spec picker, the bar picker with rename / delete, "+ Buff Bar" and
-- "+ Debuff Bar". The Filter Editor and the Buff Blacklist (retail popups)
-- are page modes with a "Back to Bars" button. The live bars show sample
-- icons while this tab is open (retail draws a preview box on the page).
--
-- 5.4.8 differences: no Border Style / Icon Shape rows (no textured borders
-- or masks), no Bleed color, debuff filters without a 5.4.8 aura flag
-- (Important, Crowd Control, Role, Raid In Combat, Bleed) and sort
-- "Important" are left out; Icon Effects glow is on / off (Blizzard glow);
-- retail-only preset spells are hidden from the lists.
-- Part of EllesmereUIOptions (load on demand); adds a tab to Unit Frames.

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUIUnitFrames") then
	return
end
local UF = ns.UF
if not (UF and UF.PAB) then
	return
end
local PAB = UF.PAB

local floor, max, min = math.floor, math.max, math.min
local format = string.format
local FONT = ns.FONT
local FONT_FALLBACK = "Fonts\\ARIALN.TTF"
local CONTENT_PAD = 45

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
local sel = { kind = "buff", id = "default" }
local specSel = "allspecs"
local mode = "bars"          -- "bars" / "filters" / "blacklist"
local filterSel
local rev = 0

local function S()
	return PAB.S()
end

local function Rebuild()
	rev = rev + 1
	if ns.RebuildSettingsPage then
		ns.RebuildSettingsPage()
	end
end

-- Unlock Mode "Element Options" pre-selects the bar (retail setter).
ns._setPABSelection = function(kind, id, bucket)
	sel = { kind = kind, id = id or "default" }
	mode = "bars"
	if bucket then
		specSel = bucket
	elseif sel.id == "default" and specSel ~= "allspecs" and not specSel:match("^spec%d") then
		specSel = "allspecs"
	end
	rev = rev + 1
end

local function IsSpecView(key)
	return key == "allspecs" or (type(key) == "string" and key:match("^spec%d") ~= nil)
end

-- Bars listed in the current Editing Spec view: { kind, id, cfg, label }.
local function ListedBars()
	local s = S()
	local out = {}
	local defaults = s.useBlizzardBuffs ~= true and IsSpecView(specSel)
	if defaults then
		out[#out + 1] = { kind = "buff", id = "default", cfg = ns.PAB_DefaultBuffsCfg(s), label = "Buffs" }
	end
	for _, bar in ipairs(ns.PAB_BucketBars(true, specSel)) do
		out[#out + 1] = { kind = "buff", id = bar.id, cfg = bar, label = bar.name or "Buff Bar" }
	end
	if defaults then
		out[#out + 1] = { kind = "debuff", id = "default", cfg = ns.PAB_DefaultDebuffsCfg(s), label = "Debuffs" }
	end
	for _, bar in ipairs(ns.PAB_BucketBars(false, specSel)) do
		out[#out + 1] = { kind = "debuff", id = bar.id, cfg = bar, label = bar.name or "Debuff Bar" }
	end
	return out
end

-- The selected bar entry (falls back to the first listed bar).
local function Selected()
	local list = ListedBars()
	for _, e in ipairs(list) do
		if e.kind == sel.kind and e.id == sel.id then
			return e
		end
	end
	local e = list[1]
	if e then
		sel = { kind = e.kind, id = e.id }
	end
	return e
end

local function PageKey()
	local e = Selected()
	return table.concat({ mode, specSel, e and e.kind or "-", tostring(e and e.id or "-"), tostring(filterSel or "-"), rev }, ":")
end

-- Every bar (all buckets) for the "Apply to all Bars" icons.
local function AllBarCfgs()
	local s = S()
	local list = { ns.PAB_DefaultBuffsCfg(s), ns.PAB_DefaultDebuffsCfg(s) }
	for _, e in ipairs(PAB.AllCustomBars()) do
		list[#list + 1] = e.bar
	end
	return list
end

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------
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

local function ClassRGB(class)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then
		return c.r, c.g, c.b
	end
	return 1, 1, 1
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
-- Value lists
---------------------------------------------------------------------------
local POINTS = {
	{ "TOP", "Top" }, { "BOTTOM", "Bottom" }, { "LEFT", "Left" }, { "RIGHT", "Right" },
	{ "TOPLEFT", "Top Left" }, { "TOPRIGHT", "Top Right" }, { "BOTTOMLEFT", "Bottom Left" },
	{ "BOTTOMRIGHT", "Bottom Right" }, { "CENTER", "Center" },
}
local OUTLINES = { { "default", "Default" }, { "none", "Drop Shadow" }, { "outline", "Outline" }, { "thick", "Thick Outline" } }
local GROW = {
	{ "LEFT", "Left" }, { "RIGHT", "Right" }, { "CENTER_HORIZONTAL", "Centered Horizontal" },
	{ "CENTER_VERTICAL", "Centered Vertical" }, { "UP", "Up" }, { "DOWN", "Down" },
}
local WRAP = { { "LEFT", "Left" }, { "RIGHT", "Right" }, { "UP", "Up" }, { "DOWN", "Down" } }
local SORT_METHOD = { { "Default", "Default" }, { "Expiration", "Expiration" }, { "Name", "Name" } }
local SORT_DIR = { { "Normal", "Normal" }, { "Reverse", "Reverse" } }
local TYPE_ICON_POS = {
	{ "none", "None" }, { "topleft", "Top Left" }, { "top", "Top" }, { "topright", "Top Right" },
	{ "left", "Left" }, { "center", "Center" }, { "right", "Right" },
	{ "bottomleft", "Bottom Left" }, { "bottom", "Bottom" }, { "bottomright", "Bottom Right" },
}
local DISPEL_COLORS = {
	{ "dispelColorMagic", "Magic", { 0.349, 0.475, 1.0 } },
	{ "dispelColorCurse", "Curse", { 0.636, 0.0, 0.64 } },
	{ "dispelColorDisease", "Disease", { 0.671, 0.384, 0.098 } },
	{ "dispelColorPoison", "Poison", { 0.0, 0.706, 0.286 } },
}
local CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID" }

---------------------------------------------------------------------------
-- Row builders on a cfg (default and custom bars share them)
---------------------------------------------------------------------------
local function G(cfg, key, default)
	return function()
		local v = cfg[key]
		if v == nil then
			return default
		end
		return v
	end
end

local function W(cfg, key)
	return function(v)
		cfg[key] = v
	end
end

local function CogSlider(cfg, label, key, default, lo, hi, step, tip)
	return { type = "slider", label = label, tip = tip, min = lo, max = hi, step = step or 1, get = G(cfg, key, default), set = W(cfg, key) }
end

local function CogDropdown(cfg, label, list, key, default, tip)
	return { type = "dropdown", label = label, tip = tip, items = function() return Items(list) end, get = G(cfg, key, default), set = W(cfg, key) }
end

-- Two-lane write (retail): a key sits in at most one lane; empty -> nil.
local function LaneSet(cfg, showKey, hideKey, k, lane, v)
	local mine, other = lane == "show" and showKey or hideKey, lane == "show" and hideKey or showKey
	cfg[mine] = cfg[mine] or {}
	cfg[mine][k] = v or nil
	if v and cfg[other] then
		cfg[other][k] = nil
	end
	for _, key in ipairs({ mine, other }) do
		if cfg[key] and not next(cfg[key]) then
			cfg[key] = nil
		end
	end
end

local function FilterNames(map)
	local names = {}
	for _, f in ipairs(ns.PAB_Filters()) do
		if map and map[f.id] then
			names[#names + 1] = f.name
		end
	end
	return names
end

-- ASSIGNED BUFFS -----------------------------------------------------------
local function BuildAssignedBuffs(p, cfg)
	p:Section("Assigned Buffs")
	local function Broad()
		return cfg.showAllBuffs ~= false or cfg.hasDuration == true
	end
	local LOCK_TIP = "All Buffs or Has Duration is selected, so every buff already shows. Use the red Hide box to exclude these instead."
	p:LaneSelect("Filters", "Which buffs this bar shows. Left box: show the filter's spells; red box: hide them.",
		function()
			local items = {
				{ action = function()
					filterSel = nil
					mode = "filters"
					Rebuild()
				end, name = "Edit Filters" },
				{ action = function()
					if not Broad() then
						return
					end
					mode = "blacklist"
					Rebuild()
				end, name = "Edit Blacklist",
				  locked = function() return not Broad() end,
				  lockedTip = "Requires All Buffs or Has Duration to be enabled" },
				{ value = "__allBuffs", name = "All Buffs", tip = "Show every buff. Use the Hide lane below to remove specific filters." },
				{ value = "__hasDuration", name = "Has Duration", tip = "Show every buff that has a duration (hides permanent buffs). Use the Hide lane below to remove specific filters." },
				{ header = true, name = "Show", rightLabel = "Hide" },
			}
			local seen = {}
			for _, f in ipairs(ns.PAB_Filters()) do
				if not seen[f.name] then
					seen[f.name] = true
					items[#items + 1] = { value = f.id, name = f.name, twoLane = true,
						showLocked = Broad, showLockedTip = LOCK_TIP }
				end
			end
			return items
		end,
		function(v)
			if v == "__allBuffs" then return cfg.showAllBuffs ~= false end
			if v == "__hasDuration" then return cfg.hasDuration == true end
			return cfg.filters and cfg.filters[v] and true or false
		end,
		function(v)
			if v == "__allBuffs" then
				cfg.showAllBuffs = not (cfg.showAllBuffs ~= false)
				cfg.hasDuration = nil
			elseif v == "__hasDuration" then
				local on = not (cfg.hasDuration == true)
				cfg.hasDuration = on or nil
				if on then cfg.showAllBuffs = false end
			else
				LaneSet(cfg, "filters", "negFilters", v, "show", not (cfg.filters and cfg.filters[v]))
			end
		end,
		function(v)
			return type(v) == "number" and cfg.negFilters and cfg.negFilters[v] and true or false
		end,
		function(v)
			LaneSet(cfg, "filters", "negFilters", v, "hide", not (cfg.negFilters and cfg.negFilters[v]))
		end,
		function()
			if not ns.PAB_BuffBarHasContent(cfg) then
				return "|cffff4040None|r"
			end
			local names = {}
			if cfg.showAllBuffs ~= false then
				names[1] = "All Buffs"
			elseif cfg.hasDuration == true then
				names[1] = "Has Duration"
			else
				names = FilterNames(cfg.filters)
			end
			local hidden = #FilterNames(cfg.negFilters)
			local txt = #names > 0 and table.concat(names, ", ") or (#(cfg.spells or {}) .. " spells")
			if hidden > 0 then
				txt = txt .. ", " .. hidden .. " hidden"
			end
			return txt
		end)
	p:MultiSelect("Extra Spells", "Single spells this bar always shows (on top of the filters).",
		function()
			local items = {
				{ action = function()
					AskSpellId("Add Spell ID", "Enter the spell ID to track.", function(id)
						cfg.spells = cfg.spells or {}
						for _, x in ipairs(cfg.spells) do
							if x == id then return end
						end
						cfg.spells[#cfg.spells + 1] = id
						Rebuild()
					end)
				end, name = "Custom Spell ID" },
			}
			local selected = {}
			local selName = {}
			for _, id in ipairs(cfg.spells or {}) do
				selected[#selected + 1] = id
				selName[GetSpellInfo(id) or id] = true
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
			-- Presets: known on this client, not selected, not in a checked filter.
			local covered = {}
			for fid in pairs(cfg.filters or {}) do
				local f = ns.PAB_GetFilter(fid)
				for id, on in pairs(f and f.spells or {}) do
					if on then covered[id] = true end
				end
			end
			local presets, names = {}, {}
			for _, id in ipairs(ns.PAB_AllPresetSpells()) do
				local name = GetSpellInfo(id)
				if name and not names[name] and not selName[name] and not covered[id] then
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
		function(id)
			for _, x in ipairs(cfg.spells or {}) do
				if x == id then return true end
			end
			return false
		end,
		function(id)
			cfg.spells = cfg.spells or {}
			for i = #cfg.spells, 1, -1 do
				if cfg.spells[i] == id then
					local fam = ns.PAB_SPELL_FAMILY[id]
					for j = #cfg.spells, 1, -1 do
						local x = cfg.spells[j]
						if x == id then
							table.remove(cfg.spells, j)
						elseif fam then
							for _, alt in ipairs(fam) do
								if alt == x then table.remove(cfg.spells, j) break end
							end
						end
					end
					return
				end
			end
			cfg.spells[#cfg.spells + 1] = id
		end,
		function()
			local n = #(cfg.spells or {})
			return n > 0 and (n .. " spells") or "None"
		end)
end

-- ASSIGNED DEBUFFS ---------------------------------------------------------
local function BuildAssignedDebuffs(p, cfg)
	p:Section("Assigned Debuffs")
	local function AllOn()
		return cfg.showAllDebuffs ~= false
	end
	local CLASS_LOCK = "All Debuffs is selected, so every debuff already shows. Use the red Hide box to exclude these instead."
	local MATCH_LOCK = "Uncheck All Debuffs to choose how the Show filters combine."
	local function ClearExclusive(skey)
		local other = ns.PAB_ExclusiveSkey[skey]
		if other then
			if cfg.classFilters then cfg.classFilters[other] = nil end
			if cfg.negClassFilters then cfg.negClassFilters[other] = nil end
		end
	end
	p:LaneSelect("Filters", "Which debuffs this bar shows. Left box: show the category; red box: hide it.",
		function()
			local items = {
				{ value = "__allDebuffs", name = "All Debuffs", tip = "Show every debuff. Use the Hide lane below to remove specific filters." },
				{ value = "__debuffHasDuration", name = "Has Duration", tip = "Only show debuffs that have a duration, excluding permanent ones. Combines with the filters below; checked alone it shows every timed debuff." },
				{ header = true, name = "Match Mode" },
				{ value = "__matchAny", name = "Match Any Filter", tip = "Shows debuffs that match any checked Show filter (the default).",
				  locked = AllOn, lockedTip = MATCH_LOCK },
				{ value = "__matchAll", name = "Match All Filters", tip = "Shows only debuffs that match every checked Show filter (dispel types count as one); opposites like Non-Player Auras with Cast By You show nothing.",
				  locked = AllOn, lockedTip = MATCH_LOCK },
				{ header = true, name = "Show", rightLabel = "Hide" },
			}
			for _, it in ipairs(ns.PAB_ClassItems()) do
				if it.isHeader then
					items[#items + 1] = { header = true, name = it.label }
				else
					items[#items + 1] = { value = it.key, name = it.label, tip = it.tooltip, twoLane = true,
						showLocked = AllOn, showLockedTip = CLASS_LOCK }
				end
			end
			return items
		end,
		function(v)
			if v == "__allDebuffs" then return AllOn() end
			if v == "__debuffHasDuration" then return cfg.hasDuration == true end
			if v == "__matchAny" then return cfg.debuffMatch ~= "all" end
			if v == "__matchAll" then return cfg.debuffMatch == "all" end
			return cfg.classFilters and cfg.classFilters[v] and true or false
		end,
		function(v)
			if v == "__allDebuffs" then
				cfg.showAllDebuffs = not AllOn()
			elseif v == "__debuffHasDuration" then
				cfg.hasDuration = not (cfg.hasDuration == true) or nil
			elseif v == "__matchAny" then
				cfg.debuffMatch = nil
			elseif v == "__matchAll" then
				cfg.debuffMatch = "all"
			else
				local on = not (cfg.classFilters and cfg.classFilters[v])
				if on then ClearExclusive(v) end
				LaneSet(cfg, "classFilters", "negClassFilters", v, "show", on)
			end
		end,
		function(v)
			return cfg.negClassFilters and cfg.negClassFilters[v] and true or false
		end,
		function(v)
			local on = not (cfg.negClassFilters and cfg.negClassFilters[v])
			if on then ClearExclusive(v) end
			LaneSet(cfg, "classFilters", "negClassFilters", v, "hide", on)
		end,
		function()
			if ns.PAB_DebuffMatchEmpty(cfg) or not ns.PAB_DebuffBarHasContent(cfg) then
				return "|cffff4040None|r"
			end
			local sep = (cfg.debuffMatch == "all" and not AllOn()) and " & " or ", "
			local names = {}
			if AllOn() then
				names[1] = "All Debuffs"
			else
				for _, it in ipairs(ns.PAB_ClassItems()) do
					if not it.isHeader and cfg.classFilters and cfg.classFilters[it.key] then
						names[#names + 1] = it.label
					end
				end
				if #names == 0 and cfg.hasDuration then names[1] = "Has Duration" end
			end
			local hidden = 0
			for _ in pairs(cfg.negClassFilters or {}) do hidden = hidden + 1 end
			local txt = table.concat(names, sep)
			if hidden > 0 then
				txt = txt .. ", " .. hidden .. " hidden"
			end
			return txt
		end)
	p:Dropdown("Max Duration", "Only show debuffs whose full duration is at most this many seconds. Combines with the filters; Unlimited applies no cap.",
		function()
			return {
				{ value = "unlimited", name = "Unlimited" },
				{ value = "custom", name = cfg.maxDurSec and format("Custom (%ds)", cfg.maxDurSec) or "Custom..." },
			}
		end,
		function() return cfg.maxDurSec and "custom" or "unlimited" end,
		function() return cfg.maxDurSec and format("Custom (%ds)", cfg.maxDurSec) or "Unlimited" end,
		function(v)
			if v == "unlimited" then
				cfg.maxDurSec = nil
				return
			end
			ns.ShowInputPopup({
				title = "Max Duration",
				message = "Enter the maximum debuff duration in seconds:",
				text = tostring(cfg.maxDurSec or 30),
				confirmText = "Apply",
				cancelText = "Cancel",
				onConfirm = function(text)
					local n = tonumber(text and strtrim(text) or "")
					if n and n > 0 then
						cfg.maxDurSec = n
						Rebuild()
					end
				end,
			})
		end)
end

-- CORE ---------------------------------------------------------------------
local function BuildCore(p, cfg)
	p:Section("Core")
	p:Slider("Icon Size", "Size of every icon on this bar.", 16, 400, 1, G(cfg, "iconSize", 32), W(cfg, "iconSize"))
	p:Cog("Icon Size", {
		{ type = "slider", label = "Icon Zoom", min = 0, max = 0.20, step = 0.01, get = G(cfg, "iconZoom", 0.055), set = W(cfg, "iconZoom") },
	}, { icon = "resize" })
	p:Dropdown("Growth Direction", "Where new icons go.", function() return Items(GROW) end,
		G(cfg, "growDirection", "LEFT"), function() return LabelOf(GROW, cfg.growDirection or "LEFT") end,
		function(v)
			if (v == "UP" or v == "DOWN") and cfg.iconWrapDirection ~= "LEFT" and cfg.iconWrapDirection ~= "RIGHT" then
				cfg.iconWrapDirection = "LEFT"
			elseif (v == "LEFT" or v == "RIGHT") and cfg.iconWrapDirection ~= "UP" and cfg.iconWrapDirection ~= "DOWN" then
				cfg.iconWrapDirection = "DOWN"
			end
			cfg.growDirection = v
		end)
	p:Cog("Growth", {
		{ type = "dropdown", label = "Icon Wrap",
		  items = function()
			local dir = cfg.growDirection or "LEFT"
			local out = Items(WRAP)
			for _, it in ipairs(out) do
				local horiz = it.value == "LEFT" or it.value == "RIGHT"
				if (dir == "LEFT" or dir == "RIGHT") and horiz or (dir == "UP" or dir == "DOWN") and not horiz then
					it.locked = function() return true end
				end
			end
			return out
		  end,
		  get = G(cfg, "iconWrapDirection", "LEFT"), set = W(cfg, "iconWrapDirection") },
	}, { icon = "directions", disabled = function()
		local d = cfg.growDirection or "LEFT"
		return d == "CENTER_HORIZONTAL" or d == "CENTER_VERTICAL"
	end })
	p:Dropdown("Sort Method", "Order of the icons (each filter group is sorted on its own).", function() return Items(SORT_METHOD) end,
		G(cfg, "sortMethod", "Default"), function() return LabelOf(SORT_METHOD, cfg.sortMethod or "Default") end, W(cfg, "sortMethod"))
	p:Dropdown("Sort Direction", "Normal or reversed order.", function() return Items(SORT_DIR) end,
		G(cfg, "sortDirection", "Normal"), function() return LabelOf(SORT_DIR, cfg.sortDirection or "Normal") end, W(cfg, "sortDirection"))
	p:Toggle("Duration", "Show the time left on each icon.", function() return cfg.durationShow ~= false end,
		function(v) cfg.durationShow = v end)
	p:Cog("Duration Text", {
		CogSlider(cfg, "Text Size", "durationTextSize", 11, 6, 60),
		CogSlider(cfg, "Offset X", "durationOffsetX", 0, -50, 50),
		CogSlider(cfg, "Offset Y", "durationOffsetY", 0, -50, 50),
		CogDropdown(cfg, "Position", POINTS, "durationPosition", "CENTER"),
		{ type = "toggle", label = "Show S for Seconds", get = function() return cfg.durationShowSeconds == true end,
		  set = function(v) cfg.durationShowSeconds = v or nil end },
		{ type = "slider", label = "Precise Below (minutes, 0 = off)", min = 0, max = 60, step = 1,
		  get = function() return cfg.durationPrecisionThreshold and floor(cfg.durationPrecisionThreshold / 60 + 0.5) or 0 end,
		  set = function(v) cfg.durationPrecisionThreshold = v > 0 and floor(v * 60 + 0.5) or nil end },
	}, { icon = "resize" })
	p:Swatch("Duration Color", function() return cfg.durationColorR or 1, cfg.durationColorG or 1, cfg.durationColorB or 1 end,
		function(r, g, b) cfg.durationColorR, cfg.durationColorG, cfg.durationColorB = r, g, b end)
	p:Toggle("Stacks", "Show the stack count on each icon.", function() return cfg.stackShow ~= false end,
		function(v) cfg.stackShow = v end)
	p:Cog("Stacks Text", {
		CogSlider(cfg, "Text Size", "stackTextSize", 11, 6, 60),
		CogSlider(cfg, "Offset X", "stackOffsetX", 0, -50, 50),
		CogSlider(cfg, "Offset Y", "stackOffsetY", 0, -50, 50),
		CogDropdown(cfg, "Position", POINTS, "stackPosition", "BOTTOMRIGHT"),
	}, { icon = "resize" })
	p:Swatch("Stacks Color", function() return cfg.stackColorR or 1, cfg.stackColorG or 1, cfg.stackColorB or 1 end,
		function(r, g, b) cfg.stackColorR, cfg.stackColorG, cfg.stackColorB = r, g, b end)
end

-- DISPLAY ------------------------------------------------------------------
local function SyncAll(keys, cfg)
	return function()
		for _, other in ipairs(AllBarCfgs()) do
			if other ~= cfg then
				for _, k in ipairs(keys) do
					other[k] = cfg[k]
				end
			end
		end
	end, function()
		for _, other in ipairs(AllBarCfgs()) do
			for _, k in ipairs(keys) do
				if other[k] ~= cfg[k] then return false end
			end
		end
		return true
	end
end

local function FontOutlineRow(p, cfg)
	p:Dropdown("Font Outline", "Outline of the duration and stack text. Default follows Global Settings > Fonts.",
		function() return Items(OUTLINES) end, G(cfg, "fontOutline", "default"),
		function() return LabelOf(OUTLINES, cfg.fontOutline or "default") end, W(cfg, "fontOutline"))
end

local function BuildDisplay(p, cfg, isBuff)
	p:Section("Display")
	p:Slider("Border Size", "Border thickness in pixels (0 = no border).", 0, 4, 1, G(cfg, "borderSize", 1), W(cfg, "borderSize"))
	p:Swatch("Border Color", function() return cfg.borderR or 0, cfg.borderG or 0, cfg.borderB or 0, cfg.borderA or 1 end,
		function(r, g, b, a) cfg.borderR, cfg.borderG, cfg.borderB, cfg.borderA = r, g, b, a end, { alpha = true })
	local apply, synced = SyncAll({ "borderSize", "borderR", "borderG", "borderB", "borderA" }, cfg)
	p:Sync("Apply Border Size and Color to all Bars", apply, synced)
	p:Toggle("Show Behind", "Draw the border behind the icon's cooldown swipe.", function() return cfg.borderBehind == true end,
		function(v) cfg.borderBehind = v or nil end)
	p:Slider("Icons Per Row", "Icons in one row (or column for vertical growth).", 1, 20, 1, G(cfg, "iconsPerRow", isBuff and 11 or 8), W(cfg, "iconsPerRow"))
	p:Cog("Icons Per Row", {
		CogSlider(cfg, "Max Rows", "maxRows", isBuff and 3 or 2, 1, 10),
		CogSlider(cfg, "Max Total", "maxTotal", isBuff and 32 or 16, 1, 40),
	})
	p:Slider("Spacing", "Gap between icons.", -5, 20, 1, G(cfg, "padding", 5), W(cfg, "padding"))
	p:Cog("Spacing", { CogSlider(cfg, "Row Spacing", "rowSpacing", 12, -5, 20) })
	p:Slider("Icon Zoom", "Crops the icon edges (percent).", 0, 15, 0.5,
		function() return (cfg.iconZoom or 0.055) * 100 end, function(v) cfg.iconZoom = v / 100 end)
	p:Toggle("Show Duration Swipe", "Darkening sweep over the icon as the aura runs out.", function() return cfg.showSwipe ~= false end,
		function(v) cfg.showSwipe = v end)
	p:Cog("Duration Swipe", {
		{ type = "toggle", label = "Reverse Swipe", get = function() return cfg.reverseSwipe ~= false end, set = function(v) cfg.reverseSwipe = v end },
	})
	p:Toggle("Show Tooltips", "Show aura tooltips when hovering this bar's icons.", function() return cfg.showTooltips ~= false end,
		function(v) cfg.showTooltips = v end)
	if isBuff then
		FontOutlineRow(p, cfg)
		p:Toggle("Right-Click to Cancel", "Right-clicking a buff icon cancels the buff (out of combat; the 5.4.8 client blocks it in combat). Turning this off makes the bar's icons click-through; tooltips still follow the Show Tooltips setting.",
			function() return cfg.rightClickCancel ~= false end, function(v) cfg.rightClickCancel = v end)
	end
end

-- DEBUFF DISPLAY + DISPEL COLORS -------------------------------------------
local function BuildDebuffDisplay(p, cfg)
	p:Section("Debuff Display")
	p:Dropdown("Type Icon Position", "Shows the debuff's dispel type icon (Magic, Curse, Disease, Poison) on the bar.",
		function() return Items(TYPE_ICON_POS) end, G(cfg, "dispelIconPosition", "none"),
		function() return LabelOf(TYPE_ICON_POS, cfg.dispelIconPosition or "none") end, W(cfg, "dispelIconPosition"))
	p:Cog("Type Icon", {
		CogSlider(cfg, "Icon Size", "dispelIconSize", 16, 8, 48),
		CogSlider(cfg, "Offset X", "dispelIconOffsetX", 0, -50, 50),
		CogSlider(cfg, "Offset Y", "dispelIconOffsetY", 0, -50, 50),
	}, { disabled = function() return (cfg.dispelIconPosition or "none") == "none" end,
		disabledTip = "This option requires a Type Icon Position other than None." })
	FontOutlineRow(p, cfg)

	p:Section("Dispel Colors")
	for _, d in ipairs(DISPEL_COLORS) do
		local key, fb = d[1], d[3]
		p:ColorRow(d[2], "Border color of " .. d[2] .. " debuffs.",
			function()
				local c = cfg[key]
				return c and c.r or fb[1], c and c.g or fb[2], c and c.b or fb[3]
			end,
			function(r, g, b) cfg[key] = { r = r, g = g, b = b } end)
	end
end

-- ICON EFFECTS ---------------------------------------------------------------
local function BuildFx(p, cfg)
	cfg.fxList = cfg.fxList or {}
	for i, e in ipairs(cfg.fxList) do
		e.filters = e.filters or {}
		p:Section("Icon Effects" .. (#cfg.fxList > 1 and (" " .. i) or ""))
		p:MultiSelect("Filters", "Debuff categories this effect paints. The first effect whose filters match an icon wins.",
			function()
				local items = {}
				for _, it in ipairs(ns.PAB_FxClassItems()) do
					items[#items + 1] = { value = it.key, name = it.label, tip = it.tooltip }
				end
				return items
			end,
			function(k) return e.filters[k] and true or false end,
			function(k) e.filters[k] = not e.filters[k] or nil end,
			function()
				local names = {}
				for _, it in ipairs(ns.PAB_FxClassItems()) do
					if e.filters[it.key] then names[#names + 1] = it.label end
				end
				return #names > 0 and table.concat(names, ", ") or "None"
			end)
		p:InlineIcon("Delete", ns.MEDIA .. "ui\\eui-close", function()
			for j = #cfg.fxList, 1, -1 do
				if cfg.fxList[j] == e then
					table.remove(cfg.fxList, j)
				end
			end
			Rebuild()
		end)
		p:Toggle("Icon Glow", "Blizzard action button glow on matching icons.", function() return (e.glowType or 0) > 0 end,
			function(v) e.glowType = v and 1 or 0 end)
		p:Slider("Border", "Extra border around matching icons (0 = none).", 0, 4, 1, function() return e.borderSize or 0 end,
			function(v) e.borderSize = v end)
		p:Swatch("Border Color", function()
			local c = e.borderColor or {}
			return c.r or 0, c.g or 0, c.b or 0
		end, function(r, g, b) e.borderColor = { r = r, g = g, b = b } end)
		p:Slider("Size", "Icon size of matching icons (0 = the bar's icon size).", 0, 400, 1, function() return e.size or 0 end,
			function(v) e.size = v > 0 and v or nil end)
	end
	p:WideButton(function() return "Add Icon Effects Per-Filter" end, "Glow, border or size for chosen debuff categories.",
		function() return false end,
		function()
			cfg.fxList[#cfg.fxList + 1] = { filters = {} }
			Rebuild()
		end)
end

---------------------------------------------------------------------------
-- Bars page body
---------------------------------------------------------------------------
local function BuildBars(p)
	local s = S()
	p:Section("Player Aura Bars")
	p:Toggle("Disable All", "Turns off Player Aura Bars completely.", function() return not ns.PAB_Enabled() end,
		function(v)
			ns.PAB_SetEnabled(not v)
			Rebuild()
			if v then
				ns.ShowConfirmPopup({
					title = "Reload Recommended",
					message = "Player Aura Bars are disabled and Blizzard's default display is back. A UI reload is recommended to finish cleanup.",
					confirmText = "Reload Now",
					cancelText = "Later",
					onConfirm = function() ReloadUI() end,
				})
			end
		end)
	p:Toggle("Use Blizzard Buffs", "Keeps Blizzard's own buff and debuff display and turns off the built-in Buffs and Debuffs bars. Custom bars keep working.",
		function() return s.useBlizzardBuffs == true end,
		function(v)
			s.useBlizzardBuffs = v and true or nil
			ns.PAB_ApplyUseBlizzard()
			Rebuild()
		end, function() return not ns.PAB_Enabled() end)

	if not ns.PAB_Enabled() then
		p:Paragraph("Replaces Blizzard's default buff and debuff display with fully customizable bars.")
		p:WideButton(function() return "Enable Player Aura Bars" end, nil, function() return true end, function()
			ns.PAB_SetEnabled(true)
			Rebuild()
		end)
		return
	end

	local e = Selected()
	if not e then
		p:Paragraph("No bars in this view. Use + Buff Bar or + Debuff Bar above to add one.")
		return
	end
	local cfg, isBuff = e.cfg, e.kind == "buff"
	local sub
	if e.id == "default" then
		sub = "(Built-in bar. Cannot be deleted)"
	else
		sub = isBuff and "(Custom buff bar)" or "(Custom debuff bar)"
	end
	p:Section(e.label .. " " .. sub)
	p:Toggle("Enable Bar", "Show this bar.", function() return cfg.enabled ~= false end, function(v)
		if e.id == "default" then
			cfg.enabled = (not v) and false or nil
		else
			cfg.enabled = v and true or false
		end
	end)
	p:Blank()

	if isBuff then
		BuildAssignedBuffs(p, cfg)
	else
		BuildAssignedDebuffs(p, cfg)
	end
	BuildCore(p, cfg)
	BuildDisplay(p, cfg, isBuff)
	if not isBuff then
		BuildDebuffDisplay(p, cfg)
		BuildFx(p, cfg)
	end
end

---------------------------------------------------------------------------
-- Filter Editor (retail modal) and Buff Blacklist (retail popup)
---------------------------------------------------------------------------
local function SelectedFilter()
	local list = ns.PAB_Filters()
	if filterSel then
		for _, f in ipairs(list) do
			if f.id == filterSel then return f end
		end
	end
	filterSel = list[1] and list[1].id or nil
	return list[1]
end

local function BuildFilters(p)
	local f = SelectedFilter()
	if not f then
		p:Paragraph("No filters yet. Use + Add Filter above.")
		return
	end
	p:Section(f.name)
	p:Dropdown("Search Spells", "Add a preset spell to this filter.",
		function()
			local items, names = {}, {}
			for _, id in ipairs(ns.PAB_AllPresetSpells()) do
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
			ns.PAB_AddSpellToFilter(f.id, id)
			Rebuild()
		end)
	p:Button("Add Spell ID", "Add any spell by its ID.", "Add Spell ID", function()
		AskSpellId("Add Spell ID", "Enter the spell ID to add to this filter.", function(id)
			ns.PAB_AddSpellToFilter(f.id, id)
			Rebuild()
		end)
	end)

	-- Rows grouped by class hint, deduplicated by name; unknown ids hidden.
	local groups, names, unknown = {}, {}, 0
	local ids = {}
	for id in pairs(f.spells) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local name = GetSpellInfo(id)
		if not name then
			unknown = unknown + 1
		elseif not names[name] then
			names[name] = true
			local class = ns.PAB_SPELL_CLASS_HINTS[id] or "Custom"
			groups[class] = groups[class] or {}
			table.insert(groups[class], id)
		end
	end
	local order = { "Custom" }
	for _, c in ipairs(CLASS_ORDER) do order[#order + 1] = c end
	local any = false
	for _, class in ipairs(order) do
		local list = groups[class]
		if list then
			any = true
			table.sort(list, function(a, b) return (GetSpellInfo(a) or "") < (GetSpellInfo(b) or "") end)
			local title = class == "Custom" and "Custom" or (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or class)
			p:Section(title)
			for _, id in ipairs(list) do
				p:Toggle(SpellLabel(id), "Spell ID " .. id .. (class ~= "Custom" and "" or ""),
					function() return f.spells[id] == true end,
					function(v) ns.PAB_SetSpellState(f.id, id, v and true or false) end)
				p:InlineIcon("Delete", ns.MEDIA .. "ui\\eui-close", function()
					ns.PAB_SetSpellState(f.id, id, nil)
					Rebuild()
				end)
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

local function BuildBlacklist(p)
	local e = Selected()
	local cfg = e and e.cfg
	if not cfg or e.kind ~= "buff" then
		mode = "bars"
		return BuildBars(p)
	end
	p:Section("Buff Blacklist")
	p:Paragraph("Spells on this list never show on \"" .. e.label .. "\" while All Buffs or Has Duration is on.")
	p:Button("Add Spell ID", "Add a spell to the blacklist by its ID.", "Add Spell ID", function()
		AskSpellId("Add Spell ID", "Enter the spell ID to blacklist.", function(id)
			cfg.blacklist = cfg.blacklist or {}
			cfg.blacklist[id] = true
			Rebuild()
		end)
	end)
	p:Blank()
	local ids = {}
	for id in pairs(cfg.blacklist or {}) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		p:Label(SpellLabel(id), "Spell ID " .. id)
		p:InlineIcon("Remove", ns.MEDIA .. "ui\\eui-close", function()
			cfg.blacklist[id] = nil
			if not next(cfg.blacklist) then cfg.blacklist = nil end
			Rebuild()
		end)
	end
end

local function Build(p)
	ns.PAB_ImportBM2Filters()
	if mode == "filters" then
		return BuildFilters(p)
	elseif mode == "blacklist" then
		return BuildBlacklist(p)
	end
	return BuildBars(p)
end

---------------------------------------------------------------------------
-- Content header
---------------------------------------------------------------------------
local function SpecItems()
	local items = { { value = "allspecs", name = "All Specs" } }
	for _, g in ipairs(PAB.GROUP_BUCKETS) do
		items[#items + 1] = { value = g.key, name = g.name }
	end
	for i = 1, (GetNumSpecializations and GetNumSpecializations() or 0) do
		local id, name = GetSpecializationInfo(i)
		if id then
			items[#items + 1] = { value = "spec" .. id, name = name }
		end
	end
	return items
end

local function SpecLabel()
	for _, it in ipairs(SpecItems()) do
		if it.value == specSel then return it.name end
	end
	specSel = "allspecs"
	return "All Specs"
end

local function PromptRename(e)
	ns.ShowInputPopup({
		title = "Rename Bar",
		message = format("Enter a new name for \"%s\":", e.label),
		text = e.cfg.name or e.label,
		confirmText = "Rename",
		cancelText = "Cancel",
		onConfirm = function(text)
			text = text and strtrim(text) or ""
			if text ~= "" then
				e.cfg.name = text
				ns.PAB_ApplyLiveConfig()
				Rebuild()
			end
		end,
	})
end

local function PromptDelete(e)
	ns.ShowConfirmPopup({
		title = "Delete Bar",
		message = e.kind == "buff" and "Delete this buff bar?" or "Delete this debuff bar?",
		confirmText = "Delete",
		cancelText = "Cancel",
		onConfirm = function()
			if e.kind == "buff" then
				ns.PAB_DeleteCustomBuffBar(e.id)
			else
				ns.PAB_DeleteCustomDebuffBar(e.id)
			end
			sel = { kind = e.kind, id = "default" }
			Rebuild()
		end,
	})
end

local function PromptAdd(isBuff)
	ns.ShowInputPopup({
		title = isBuff and "Add Buff Bar" or "Add Debuff Bar",
		message = "Name",
		text = "",
		confirmText = "Create",
		cancelText = "Cancel",
		onConfirm = function(text)
			text = text and strtrim(text) or ""
			local name = text ~= "" and text or nil
			local bar = isBuff and ns.PAB_AddCustomBuffBar(name, specSel) or ns.PAB_AddCustomDebuffBar(name, specSel)
			sel = { kind = isBuff and "buff" or "debuff", id = bar.id }
			ns.PAB_ApplyLiveConfig()
			Rebuild()
		end,
	})
end

local function HeaderBars(page, host, width)
	local y = 16
	local DD_H, ICON, GAP = 30, 30, 6
	-- Row 1: Editing Spec | bar picker | rename | delete
	local specLabel = Text(host, 11, 0.45)
	specLabel:SetText("EDITING SPEC")
	local SPEC_W, BAR_W = 190, 260
	local total = SPEC_W + 12 + BAR_W + GAP + ICON + GAP + ICON
	local x0 = floor((width - total) / 2)
	specLabel:SetPoint("BOTTOMLEFT", host, "TOPLEFT", x0, -y + 2)
	local spec = page:HeaderDropdown(host, SPEC_W, DD_H, SpecItems, function() return specSel end, SpecLabel, function(v)
		specSel = v
		sel = { kind = "buff", id = "default" }
		Rebuild()
	end)
	spec:SetPoint("TOPLEFT", host, "TOPLEFT", x0, -y)
	local barLabel = Text(host, 11, 0.45)
	barLabel:SetText("BAR")
	local bars = page:HeaderDropdown(host, BAR_W, DD_H,
		function()
			local items = {}
			local lastKind = nil
			for _, e in ipairs(ListedBars()) do
				if e.kind ~= lastKind then
					items[#items + 1] = { header = true, name = e.kind == "buff" and "BUFF BARS" or "DEBUFF BARS" }
					lastKind = e.kind
				end
				local off = e.cfg.enabled == false
				items[#items + 1] = { value = e.kind .. ":" .. tostring(e.id), name = e.label .. (off and "  |cff888888(off)|r" or "") }
			end
			return items
		end,
		function() return sel.kind .. ":" .. tostring(sel.id) end,
		function()
			local e = Selected()
			return e and e.label or "No bars"
		end,
		function(v)
			local kind, id = v:match("^(%a+):(.+)$")
			sel = { kind = kind, id = tonumber(id) or id }
			Rebuild()
		end)
	bars:SetPoint("LEFT", spec, "RIGHT", 12, 0)
	barLabel:SetPoint("BOTTOMLEFT", bars, "TOPLEFT", 0, 2)
	local e = Selected()
	local custom = e and e.id ~= "default"
	local rename = page:HeaderIconButton(host, ICON, "Interface\\Buttons\\UI-GuildButton-PublicNote-Up", 16, "Rename", function()
		local cur = Selected()
		if cur and cur.id ~= "default" then PromptRename(cur) end
	end)
	rename:SetPoint("LEFT", bars, "RIGHT", GAP, 0)
	rename:SetAlpha(custom and 1 or 0.3)
	local delete = page:HeaderIconButton(host, ICON, ns.MEDIA .. "ui\\eui-close", 16, "Delete", function()
		local cur = Selected()
		if cur and cur.id ~= "default" then PromptDelete(cur) end
	end)
	delete:SetPoint("LEFT", rename, "RIGHT", GAP, 0)
	delete:SetAlpha(custom and 1 or 0.3)
	y = y + DD_H + 12
	-- Row 2: + Buff Bar | + Debuff Bar
	local addBuff = FlatButton(host, 150, 28, "+ Add Buff Bar", function() PromptAdd(true) end, "Create a custom buff bar in the selected spec view.")
	local addDebuff = FlatButton(host, 150, 28, "+ Add Debuff Bar", function() PromptAdd(false) end, "Create a custom debuff bar in the selected spec view.")
	addBuff:SetPoint("TOPRIGHT", host, "TOP", -6, -y)
	addDebuff:SetPoint("TOPLEFT", host, "TOP", 6, -y)
	if not ns.PAB_Enabled() then
		addBuff:Hide()
		addDebuff:Hide()
	end
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
			text = text and strtrim(text) or ""
			local f = ns.PAB_AddFilter(text ~= "" and text or nil)
			filterSel = f.id
			Rebuild()
		end,
	})
end

local function HeaderFilters(page, host, width)
	local y = 16
	local DD_H, ICON, GAP = 30, 30, 6
	local BACK_W, DD_W, ADD_W = 130, 260, 120
	local total = BACK_W + 12 + DD_W + GAP + ICON + GAP + ICON + 12 + ADD_W
	local x0 = floor((width - total) / 2)
	local back = FlatButton(host, BACK_W, DD_H, "< Back to Bars", function()
		mode = "bars"
		Rebuild()
	end)
	back:SetPoint("TOPLEFT", host, "TOPLEFT", x0, -y)
	if mode == "blacklist" then
		local title = Text(host, 14, 0.85)
		title:SetPoint("LEFT", back, "RIGHT", 16, 0)
		title:SetText("Buff Blacklist")
		return y + DD_H + 14
	end
	local dd = page:HeaderDropdown(host, DD_W, DD_H,
		function()
			local items = {}
			for _, f in ipairs(ns.PAB_Filters()) do
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
				ns.PAB_RenameFilter(cur.id, text and strtrim(text) or "")
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
			message = "Delete this filter? It is removed from every bar using it.",
			confirmText = "Delete",
			cancelText = "Cancel",
			onConfirm = function()
				ns.PAB_DeleteFilter(cur.id)
				filterSel = nil
				ns.PAB_ApplyLiveConfig()
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
	-- Sample icons on the live bars while this tab shows.
	host:HookScript("OnShow", function() ns.PAB_SetPreview(true) end)
	host:HookScript("OnHide", function() ns.PAB_SetPreview(false) end)
	if mode == "bars" then
		return HeaderBars(page, host, width)
	end
	return HeaderFilters(page, host, width)
end

ns.PAB_OptionsTab = {
	key = "playerAuraBars",
	name = "Player Aura Bars",
	description = "Your own buffs and debuffs as fully customizable bars.",
	build = Build,
	header = BuildHeader,
	pageKey = PageKey,
}

-- Retail entry points of the Filter Editor (also used by the Filters dropdown).
ns.PABMP_ShowFilterEditor = function()
	filterSel = nil
	mode = "filters"
	Rebuild()
end
ns.PABMP_ShowBlacklist = function()
	mode = "blacklist"
	Rebuild()
end
