-- Settings tab Raid Frames > Debuff Manager (retail
-- EUI_RaidFrames_ManagerPages.lua DMP_BuildPage: same sections, labels,
-- tooltips and keys, built with this window's Page API).
--
-- Layout: retail shows a sidebar of indicator tiles (Base Icons first) next
-- to the selected indicator's settings. Here the content header holds the
-- same choices: the Editing Spec picker, the indicator picker with rename /
-- delete, and "+ Add New" (indicator type). The page below edits the
-- selected indicator.
--
-- 5.4.8 differences: no Bleed filter (5.4.8 debuffs carry no bleed type),
-- the glow controls are one pixel glow with a color (no engine glow
-- styles), no preview band (the live frames show sample debuffs while the
-- settings preview is on), no spec-override "Custom Debuff Manager".
-- Part of EllesmereUIOptions (load on demand); worker E adds the tab.

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUIRaidFrames") then
	return
end

local floor = math.floor
local format = string.format
local FONT = ns.FONT
local FONT_FALLBACK = "Fonts\\ARIALN.TTF"

local function RF()
	local ERF = ns.ERF
	return ERF and ERF.RF
end

local function P()
	local rf = RF()
	return rf and rf.Profile and rf.Profile()
end

local function DM()
	local rf = RF()
	return rf and rf.DM_Get and rf.DM_Get()
end

---------------------------------------------------------------------------
-- State (session-sticky like retail)
---------------------------------------------------------------------------
local dmSel = "base"          -- "base" or a tile id
local dmSpecSel = "allspecs"  -- editing bucket
local rev = 0

local function Rebuild()
	rev = rev + 1
	if ns.RebuildSettingsPage then
		ns.RebuildSettingsPage()
	end
end

---------------------------------------------------------------------------
-- Value lists (retail)
---------------------------------------------------------------------------
local POS = {
	{ "topleft", "Top Left" }, { "top", "Top" }, { "topright", "Top Right" },
	{ "left", "Left" }, { "center", "Center" }, { "right", "Right" },
	{ "bottomleft", "Bottom Left" }, { "bottom", "Bottom" }, { "bottomright", "Bottom Right" },
}
local GROW = {
	{ "LEFT", "Left" }, { "RIGHT", "Right" }, { "UP", "Up" }, { "DOWN", "Down" }, { "CENTER", "Center" },
}
local TIPS = {
	{ "hidden", "Hidden" }, { "shown", "Shown" }, { "cursor", "Shown At Cursor" },
	{ "modifier", "Shown on Modifier" }, { "combat", "Hidden In Combat" },
}
local MODKEYS = { { "none", "None" }, { "shift", "Shift" }, { "control", "Control" }, { "alt", "Alt" } }
local FRAME_LEVELS = {
	{ "behindBorders", "Behind Borders" }, { "behindText", "Behind Text" }, { "medium", "Medium" },
	{ "high", "High" }, { "highest", "Highest" },
}
local ORIENT = { { "HORIZONTAL", "Horizontal" }, { "VERTICAL", "Vertical" } }
local GLOWS = { { 0, "None" }, { 1, "Pixel Glow" } }

local TYPE_NAMES = { icons = "Icon", glow = "Frame Glow", square = "Square",
	healthcolor = "Health Bar Color", bar = "Duration Bar" }
local TYPE_ORDER = { "icons", "square", "glow", "healthcolor", "bar" }

local CAT_VALUES = { boss = "Boss", role = "Role", priority = "Important",
	cc = "Crowd Control", raid = "Raid", raidcombat = "Raid In Combat", dispel = "Dispellable",
	nonplayer = "Non-Player" }
local CAT_ORDER = { "nonplayer", "priority", "boss", "role", "cc", "raid", "raidcombat", "dispel" }
local LESS_CAT_VALUES = { castbyme = "Cast By You", magic = "Magic", curse = "Curse", poison = "Poison",
	disease = "Disease", canapply = "Can Apply Aura" }
local LESS_CAT_ORDER = { "castbyme", "magic", "curse", "poison", "disease", "canapply" }

-- Two-lane filter rows (retail FILTER_ITEMS / TILE_LANE_ITEMS).
local LANE_ROWS = {
	{ key = "nonplayer", label = "Non-Player Auras",
	  tip = "Debuffs not caused by any player or player pet (this is what shows most pve debuffs)." },
	{ key = "priority", label = "Important", tip = "Debuffs Blizzard flags as priority for raid frames." },
	{ key = "cc", label = "Crowd Control", tip = "Loss-of-control debuffs. When shown, these lead the row and carry the CC glow." },
	{ key = "boss", label = "Boss Debuffs", tip = "Debuffs applied by boss encounters." },
	{ key = "role", label = "Role Debuffs", tip = "Debuffs flagged as relevant to your role." },
	{ key = "raid", label = "Raid", tip = "Blizzard's curated raid-frame debuff set." },
	{ key = "raidcombat", label = "Raid In Combat", tip = "The stricter in-combat subset of the raid set." },
	{ key = "dispel_you", label = "Dispellable By You", tip = "Debuffs you can dispel." },
	{ key = "dispel_typed", label = "Dispels",
	  tip = "Any debuff with a dispel type (Magic, Curse, Disease, Poison), even if you cannot remove it." },
	{ header = "Less Common Filters" },
	{ key = "castbyme", label = "Cast By You", tip = "Debuffs applied by you or your pet." },
	{ key = "anyplayer", label = "From Any Player",
	  tip = "Debuffs caused by any player or player pet. The opposite of Non-Player Auras; checking one clears the other." },
	{ key = "magic", label = "Magic", tip = "Debuffs with the Magic dispel type." },
	{ key = "curse", label = "Curse", tip = "Debuffs with the Curse dispel type." },
	{ key = "poison", label = "Poison", tip = "Debuffs with the Poison dispel type." },
	{ key = "disease", label = "Disease", tip = "Debuffs with the Disease dispel type." },
	{ key = "canapply", label = "Can Apply Aura", tip = "Debuffs your own class is able to apply." },
}

-- Icon Effects filter rows (retail TILE_FILTER_ITEMS, single lane).
local FX_ROWS = {
	{ key = "nonplayer", label = "Non-Player Auras" }, { key = "priority", label = "Important" },
	{ key = "cc", label = "Crowd Control" }, { key = "boss", label = "Boss Debuffs" },
	{ key = "role", label = "Role Debuffs" }, { key = "raid", label = "Raid" },
	{ key = "raidcombat", label = "Raid In Combat" }, { key = "dispel_you", label = "Dispellable By You" },
	{ key = "dispel_typed", label = "Dispels" },
}

local MATCH_LOCK = "Uncheck All Debuffs to choose how the Show filters combine."
local SHOW_LOCK = "All Debuffs is selected, so every debuff already shows. Use the red Hide box to exclude these instead."

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

local function TipModeKey(v)
	if v == false then return "shown" end
	if v == "cursor" or v == "combat" or v == "modifier" then return v end
	return "hidden"
end

local function TipModeStore(k)
	if k == "shown" then return false end
	if k == "hidden" then return true end
	return k
end

-- Retail DmDefaultGrow: icons flow into the frame from the anchored edge.
local function DefaultGrow(pos)
	if pos == "right" or pos == "topright" or pos == "bottomright" then return "LEFT" end
	if pos == "left" or pos == "topleft" or pos == "bottomleft" then return "RIGHT" end
	if pos == "top" then return "DOWN" end
	if pos == "bottom" then return "UP" end
	return "CENTER"
end

local function RowCat(k)
	if k == "dispel_you" or k == "dispel_typed" then return "dispel" end
	if k == "anyplayer" then return "nonplayer" end
	return k
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

local function ColorGet(tbl, key, dr, dg, db)
	return function()
		local c = tbl[key]
		if type(c) == "table" then
			return c.r or dr, c.g or dg, c.b or db, c.a or 1
		end
		return dr, dg, db, 1
	end
end

local function ColorSet(tbl, key)
	return function(r, g, b)
		tbl[key] = { r = r, g = g, b = b }
	end
end

-- Two-lane write (retail DmSetLane): show lane in `show`, hide lane in
-- owner.neg; the dispel / nonplayer flavors are global (dm).
local function SetLane(show, owner, dm, k, v, neg)
	local cat, modeKey, mode = k, nil, nil
	if k == "dispel_you" or k == "dispel_typed" then
		cat, modeKey, mode = "dispel", "dispelMode", (k == "dispel_typed") and "typed" or "you"
	elseif k == "nonplayer" or k == "anyplayer" then
		cat, modeKey, mode = "nonplayer", "nonplayerMode", (k == "anyplayer") and "any" or nil
	end
	if neg and v then
		owner.neg = owner.neg or {}
		owner.neg[cat] = true
		show[cat] = nil
	else
		if not neg then
			show[cat] = v and true or nil
		end
		if (neg or v) and owner.neg then
			owner.neg[cat] = nil
			if not next(owner.neg) then
				owner.neg = nil
			end
		end
	end
	if v and modeKey then
		dm[modeKey] = mode
	end
end

-- Lane read (retail checkbox getters).
local function LaneGet(show, owner, dm, k, neg)
	local function NegHas(cat) return owner.neg ~= nil and owner.neg[cat] == true end
	if k == "dispel_you" or k == "dispel_typed" then
		local typed = dm.dispelMode == "typed"
		if (k == "dispel_typed") ~= typed then
			return false
		end
		if neg then return NegHas("dispel") end
		return show.dispel == true
	end
	if k == "nonplayer" or k == "anyplayer" then
		if (dm.nonplayerMode == "any") ~= (k == "anyplayer") then
			return false
		end
		if neg then return NegHas("nonplayer") end
		return show.nonplayer == true
	end
	if neg then return NegHas(k) end
	return show[k] == true
end

---------------------------------------------------------------------------
-- Spec views and indicators
---------------------------------------------------------------------------
local GROUPS = {
	{ key = "nonhealer", name = "All Non-Healers" },
	{ key = "tanks", name = "All Tanks" },
	{ key = "dps", name = "All DPS" },
	{ key = "healers", name = "All Healers" },
}

local function SpecItems()
	local items = { { value = "allspecs", name = "All Specs" } }
	for _, g in ipairs(GROUPS) do
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

local function SpecName(key)
	for _, it in ipairs(SpecItems()) do
		if it.value == key then
			return it.name
		end
	end
	return key
end

local function ConcreteSpecID()
	local m = type(dmSpecSel) == "string" and dmSpecSel:match("^spec(%d+)$")
	return m and tonumber(m) or nil
end

-- Indicators listed for the view: { kind = "base"|"tile", t, bucket, inherited }.
local function ListedIndicators()
	local rf = RF()
	local dm = DM()
	local out = {}
	if not (rf and dm) then
		return out
	end
	local sid = ConcreteSpecID()
	if dmSpecSel == "allspecs" or sid then
		out[#out + 1] = { kind = "base", bucket = "allspecs", inherited = sid ~= nil }
	end
	local function AddBucket(key, inherited)
		local tl = rf.DM_BucketTiles(key, false)
		for i = 1, #(tl or {}) do
			out[#out + 1] = { kind = "tile", t = tl[i], bucket = key, inherited = inherited }
		end
	end
	if dmSpecSel == "allspecs" then
		AddBucket("allspecs", false)
	elseif sid then
		AddBucket("allspecs", true)
		local roleKey = rf.DM_RoleBucketForSpecID(sid)
		if roleKey ~= "healers" then
			AddBucket("nonhealer", true)
		end
		if roleKey then
			AddBucket(roleKey, true)
		end
		AddBucket(dmSpecSel, false)
	else
		if dmSpecSel == "tanks" or dmSpecSel == "dps" then
			AddBucket("nonhealer", true)
		end
		AddBucket(dmSpecSel, false)
	end
	return out
end

local function TileName(t)
	return t.name or TYPE_NAMES[t.type] or t.type
end

local function EntryKey(e)
	return e.kind == "base" and "base" or ("t" .. tostring(e.t.id))
end

local function Selected()
	local list = ListedIndicators()
	for _, e in ipairs(list) do
		if EntryKey(e) == (dmSel == "base" and "base" or ("t" .. tostring(dmSel))) then
			return e
		end
	end
	local e = list[1]
	dmSel = e and (e.kind == "base" and "base" or e.t.id) or "base"
	return e
end

local function TileSubtitle(t)
	local names = {}
	if t.all == true then names[#names + 1] = "All Debuffs" end
	if t.hasDuration == true then names[#names + 1] = "Has Duration" end
	local cats = {}
	if t.claim then
		for _, cat in ipairs(CAT_ORDER) do
			if t.claim[cat] then cats[#cats + 1] = CAT_VALUES[cat] end
		end
		for _, cat in ipairs(LESS_CAT_ORDER) do
			if t.claim[cat] then cats[#cats + 1] = LESS_CAT_VALUES[cat] end
		end
	end
	if #names == 0 and #cats == 0 then return "No filters routed" end
	if #cats > 0 then
		local matchOn = t.match == "all" and t.all ~= true and #cats >= 2
		names[#names + 1] = table.concat(cats, matchOn and " & " or ", ")
	end
	return table.concat(names, ", ")
end

-- Per-spec disable of an inherited indicator (retail inhDis / baseOff on
-- the viewing spec's bucket).
local function SpecBucket(create)
	local rf = RF()
	if not (rf and ConcreteSpecID()) then
		return nil
	end
	local _, b = rf.DM_BucketTiles(dmSpecSel, create)
	return b
end

---------------------------------------------------------------------------
-- Filters (two-lane dropdown)
---------------------------------------------------------------------------
-- owner: the dm table (base) or a tile; show: dm (base) or tile.claim.
local function BuildFilters(p, dm, owner, show, isBase)
	local prof = P()
	local function AllOn()
		if isBase then
			return dm.all ~= false
		end
		return owner.all == true
	end
	p:LaneSelect("Filters", "Which debuffs show here. Left box: show the category; red box: hide it.",
		function()
			local items = {
				{ value = "__all", name = "All Debuffs",
				  tip = isBase and "Show every debuff. Use the Hide lane below to remove specific filters."
					or "Show every debuff in this indicator. Use the Hide lane below to remove specific filters." },
				{ value = "__dur", name = "Has Duration",
				  tip = "Only show debuffs that have a duration, excluding permanent ones. Combines with the filters below; checked alone it shows every timed debuff." },
			}
			if isBase then
				items[#items + 1] = { value = "__exh", name = "Hide Exhaustion",
					tip = "Hides Sated, Exhaustion, Temporal Displacement and the other Bloodlust lockout debuffs." }
			end
			items[#items + 1] = { header = true, name = "Match Mode" }
			items[#items + 1] = { value = "__any", name = "Match Any Filter", locked = AllOn, lockedTip = MATCH_LOCK,
				tip = "Shows debuffs that match any checked Show filter (the default)." }
			items[#items + 1] = { value = "__allm", name = "Match All Filters", locked = AllOn, lockedTip = MATCH_LOCK,
				tip = "Shows only debuffs that match every checked Show filter (dispel types count as one); the rest stay where they already show." }
			items[#items + 1] = { header = true, name = "Show", rightLabel = "Hide" }
			for _, r in ipairs(LANE_ROWS) do
				if r.header then
					items[#items + 1] = { header = true, name = r.header }
				else
					items[#items + 1] = { value = r.key, name = r.label, tip = r.tip, twoLane = true,
						showLocked = isBase and AllOn or nil, showLockedTip = SHOW_LOCK }
				end
			end
			return items
		end,
		function(v)
			if v == "__all" then return AllOn() end
			if v == "__dur" then return owner.hasDuration == true end
			if v == "__exh" then return prof and prof.hideLustDebuff ~= false end
			if v == "__any" then return owner.match ~= "all" end
			if v == "__allm" then return owner.match == "all" end
			return LaneGet(show, owner, dm, v, false)
		end,
		function(v)
			if v == "__all" then
				if isBase then
					dm.all = not AllOn()
				else
					owner.all = not AllOn() or nil
				end
			elseif v == "__dur" then
				owner.hasDuration = not (owner.hasDuration == true) or nil
			elseif v == "__exh" then
				if prof then
					prof.hideLustDebuff = not (prof.hideLustDebuff ~= false)
				end
			elseif v == "__any" then
				owner.match = nil
			elseif v == "__allm" then
				owner.match = "all"
			else
				SetLane(show, owner, dm, v, not LaneGet(show, owner, dm, v, false), false)
			end
		end,
		function(v)
			return LaneGet(show, owner, dm, v, true)
		end,
		function(v)
			SetLane(show, owner, dm, v, not LaneGet(show, owner, dm, v, true), true)
		end,
		function()
			local names = {}
			if AllOn() then
				names[1] = "All Debuffs"
			else
				for _, r in ipairs(LANE_ROWS) do
					if r.key and LaneGet(show, owner, dm, r.key, false) then
						names[#names + 1] = r.label
					end
				end
				if #names == 0 and owner.hasDuration then
					names[1] = "Has Duration"
				end
			end
			local hidden = 0
			for _ in pairs(owner.neg or {}) do
				hidden = hidden + 1
			end
			local sep = (owner.match == "all" and not AllOn()) and " & " or ", "
			local txt = table.concat(names, sep)
			if hidden > 0 then
				txt = (txt ~= "" and (txt .. ", ") or "") .. hidden .. " hidden"
			end
			if txt == "" then
				return "|cffff4040None|r"
			end
			return txt
		end)
end

-- Max Duration (EllesmereUI.MaxDurationDropdown): Unlimited or a custom cap.
local function MaxDuration(p, owner)
	p:Dropdown("Max Duration", "Only show debuffs whose full duration is at most this many seconds. Combines with the filters; Unlimited applies no cap.",
		function()
			return {
				{ value = "unlimited", name = "Unlimited" },
				{ value = "custom", name = owner.maxDurSec and format("Custom (%ds)", owner.maxDurSec) or "Custom..." },
			}
		end,
		function() return owner.maxDurSec and "custom" or "unlimited" end,
		function() return owner.maxDurSec and format("Custom (%ds)", owner.maxDurSec) or "Unlimited" end,
		function(v)
			if v == "unlimited" then
				owner.maxDurSec = nil
				return
			end
			if not ns.ShowInputPopup then
				return
			end
			ns.ShowInputPopup({
				title = "Max Duration",
				message = "Enter the maximum debuff duration in seconds:",
				text = tostring(owner.maxDurSec or 30),
				confirmText = "Apply",
				cancelText = "Cancel",
				onConfirm = function(text)
					local n = tonumber(text and strtrim(text) or "")
					if n and n > 0 then
						owner.maxDurSec = n
						Rebuild()
					end
				end,
			})
		end)
end

---------------------------------------------------------------------------
-- Icon Effects (per-filter glow / border / size)
---------------------------------------------------------------------------
local function BuildFx(p, fxOwner, dm)
	local list = fxOwner.fxList or {}
	for bi = 1, #list do
		local e = list[bi]
		e.filters = e.filters or {}
		p:Section("Icon Effects")
		p:MultiSelect("Filters", "Which debuffs get these effects.",
			function()
				local out = {}
				for _, r in ipairs(FX_ROWS) do
					out[#out + 1] = { value = r.key, name = r.label }
				end
				return out
			end,
			function(k)
				if k == "dispel_you" then return (e.filters.dispel and true or false) and dm.dispelMode ~= "typed" end
				if k == "dispel_typed" then return (e.filters.dispel and true or false) and dm.dispelMode == "typed" end
				return e.filters[k] and true or false
			end,
			function(k)
				if k == "dispel_you" or k == "dispel_typed" then
					local on = not e.filters.dispel or ((k == "dispel_typed") ~= (dm.dispelMode == "typed"))
					e.filters.dispel = on or nil
					if on then
						dm.dispelMode = (k == "dispel_typed") and "typed" or "you"
					end
					return
				end
				e.filters[k] = (not e.filters[k]) or nil
			end,
			function()
				local names = {}
				for _, r in ipairs(FX_ROWS) do
					local k = RowCat(r.key)
					if e.filters[k] and (k ~= "dispel" or ((r.key == "dispel_typed") == (dm.dispelMode == "typed"))) then
						names[#names + 1] = r.label
					end
				end
				return #names > 0 and table.concat(names, ", ") or "None"
			end)
		p:Dropdown("Icon Glow", "A glow around the matched icons.", function() return Items(GLOWS) end,
			function() return (e.glowType or 0) > 0 and 1 or 0 end,
			function() return LabelOf(GLOWS, (e.glowType or 0) > 0 and 1 or 0) end,
			function(v) e.glowType = v end)
		p:Swatch("Glow Color", function() return e.glowR or 1, e.glowG or 0.776, e.glowB or 0.376 end,
			function(r, g, b) e.glowR, e.glowG, e.glowB = r, g, b end,
			{ active = function() return not e.glowClassColor end,
			  disabled = function() return (e.glowType or 0) == 0 end })
		p:Swatch("Class Color", function() return Accent() end, function() end,
			{ readonly = true, active = function() return e.glowClassColor == true end,
			  onClick = function() e.glowClassColor = not e.glowClassColor or nil return true end,
			  disabled = function() return (e.glowType or 0) == 0 end })
		p:Slider("Border", "Border thickness on the matched icons (0 = the display border).", 0, 4, 1,
			function() return e.borderSize or 0 end, function(v) e.borderSize = v end)
		p:Swatch("Border Color", ColorGet(e, "borderColor", 0, 0, 0), ColorSet(e, "borderColor"))
		p:Slider("Size", "Icon size for the matched filters (0 = the grid's own size).", 0, 80, 1,
			function() return e.size or 0 end,
			function(v) e.size = (v and v > 0) and v or nil end)
		local idx = bi
		p:Button("Remove Effect", "Delete this Icon Effects block.", "Delete", function()
			table.remove(list, idx)
			Rebuild()
		end)
	end
	p:WideButton(function() return "Add Icon Effects Per-Filter" end, "Add a glow / border / size for chosen filters.",
		function() return false end,
		function()
			fxOwner.fxList = fxOwner.fxList or {}
			fxOwner.fxList[#fxOwner.fxList + 1] = { filters = {} }
			Rebuild()
		end)
end

---------------------------------------------------------------------------
-- Base Icons
---------------------------------------------------------------------------
local function BuildBase(p, e)
	local prof = P()
	local dm = DM()
	if not (prof and dm) then
		return
	end
	if e and e.inherited then
		p:Section("Indicator")
		p:Toggle("Enabled For This Spec", "Inherited from All Specs. Off hides the Base Icons grid for this spec only.",
			function()
				local b = SpecBucket(false)
				return not (b and b.baseOff)
			end,
			function(v)
				local b = SpecBucket(true)
				if b then
					b.baseOff = (not v) or nil
				end
			end)
		p:Blank()
	end
	p:Section("Assigned Debuffs")
	BuildFilters(p, dm, dm, dm, true)
	MaxDuration(p, dm)

	p:Section("Core")
	p:Slider("Size", "Size of each debuff icon.", 10, 80, 1,
		function() return prof.debuffSize or 18 end, function(v) prof.debuffSize = v end)
	p:Cog("Icon Zoom", {
		{ type = "slider", label = "Zoom", min = 0, max = 0.20, step = 0.01,
		  get = function() return prof.debuffIconZoom or 0.08 end, set = function(v) prof.debuffIconZoom = v end },
	}, { icon = "resize" })
	p:Slider("Max Debuffs", "Most debuffs shown per filter group.", 1, 10, 1,
		function() return prof.debuffCap or 3 end, function(v) prof.debuffCap = v end)
	p:Dropdown("Position", "Where the debuffs sit on the frame.", function() return Items(POS) end,
		function() return prof.debuffPosition or "bottomright" end,
		function() return LabelOf(POS, prof.debuffPosition or "bottomright") end,
		function(v)
			prof.debuffPosition = v
			prof.debuffGrowDirection = DefaultGrow(v)
		end)
	p:Cog("Position Offset", {
		{ type = "slider", label = "Offset X", min = -50, max = 50, step = 1,
		  get = function() return prof.debuffOffsetX or 0 end, set = function(v) prof.debuffOffsetX = v end },
		{ type = "slider", label = "Offset Y", min = -50, max = 50, step = 1,
		  get = function() return prof.debuffOffsetY or 0 end, set = function(v) prof.debuffOffsetY = v end },
	}, { icon = "directions" })
	p:Dropdown("Growth Direction", "Where new icons go.", function() return Items(GROW) end,
		function() return prof.debuffGrowDirection or "LEFT" end,
		function() return LabelOf(GROW, prof.debuffGrowDirection or "LEFT") end,
		function(v) prof.debuffGrowDirection = v end)
	p:Slider("Icons Per Row", "Wraps into a new row (or column for vertical growth) after this many icons; below 2 keeps one continuous run.",
		0, 20, 1, function() return prof.debuffPerRow or 5 end, function(v) prof.debuffPerRow = v end)
	p:Blank()

	p:Section("Display")
	p:Slider("Border", "Border thickness of each debuff icon.", 0, 4, 1,
		function() return prof.debuffBorderSize or 1 end, function(v) prof.debuffBorderSize = v end)
	p:Swatch("Border Color", ColorGet(prof, "debuffBorderColor", 0, 0, 0), ColorSet(prof, "debuffBorderColor"))
	p:Slider("Spacing", "Space between icons.", -1, 10, 1,
		function() return floor((prof.debuffSpacing or 1) + 0.5) end, function(v) prof.debuffSpacing = v end)
	p:Toggle("Show Duration Text", "Show the time left on each icon.",
		function() return prof.debuffShowDurText and true or false end, function(v) prof.debuffShowDurText = v end)
	p:Cog("Duration Text", {
		{ type = "slider", label = "Text Size", min = 6, max = 26, step = 1,
		  get = function() return prof.debuffDurTextSize or 10 end, set = function(v) prof.debuffDurTextSize = v end },
		{ type = "slider", label = "Offset X", min = -20, max = 20, step = 1,
		  get = function() return prof.debuffDurTextOffsetX or 0 end, set = function(v) prof.debuffDurTextOffsetX = v end },
		{ type = "slider", label = "Offset Y", min = -20, max = 20, step = 1,
		  get = function() return prof.debuffDurTextOffsetY or 0 end, set = function(v) prof.debuffDurTextOffsetY = v end },
	}, { icon = "resize" })
	p:Swatch("Duration Color", ColorGet(prof, "debuffDurTextColor", 1, 1, 1), ColorSet(prof, "debuffDurTextColor"))
	p:Toggle("Show Stacks", "Show the stack count on each icon.",
		function() return prof.debuffShowStacks ~= false end, function(v) prof.debuffShowStacks = v end)
	p:Cog("Stacks Text", {
		{ type = "slider", label = "Text Size", min = 6, max = 26, step = 1,
		  get = function() return prof.debuffStacksTextSize or 11 end, set = function(v) prof.debuffStacksTextSize = v end },
		{ type = "slider", label = "Offset X", min = -20, max = 20, step = 1,
		  get = function() return prof.debuffStacksOffsetX or 0 end, set = function(v) prof.debuffStacksOffsetX = v end },
		{ type = "slider", label = "Offset Y", min = -20, max = 20, step = 1,
		  get = function() return prof.debuffStacksOffsetY or 0 end, set = function(v) prof.debuffStacksOffsetY = v end },
	}, { icon = "resize" })
	p:Swatch("Stacks Color", ColorGet(prof, "debuffStacksTextColor", 1, 1, 1), ColorSet(prof, "debuffStacksTextColor"))
	p:Dropdown("Tooltips", "Debuff tooltips on mouseover.", function() return Items(TIPS) end,
		function() return TipModeKey(prof.debuffHideTooltips) end,
		function() return LabelOf(TIPS, TipModeKey(prof.debuffHideTooltips)) end,
		function(k) prof.debuffHideTooltips = TipModeStore(k) end)
	p:Cog("Tooltips", {
		{ type = "dropdown", label = "Use Modifier", items = function() return Items(MODKEYS) end,
		  get = function() return prof.debuffTooltipModifier or "none" end,
		  set = function(v) prof.debuffTooltipModifier = v end },
	}, { disabled = function() return TipModeKey(prof.debuffHideTooltips) ~= "modifier" end,
	     disabledTip = "This option requires Tooltips to be set to Shown on Modifier" })
	p:Toggle("Show Duration Swipe", "Dark clock swipe over each icon.",
		function() return prof.debuffShowSwipe ~= false end, function(v) prof.debuffShowSwipe = v end)

	BuildFx(p, dm, dm)
end

---------------------------------------------------------------------------
-- Indicator tiles
---------------------------------------------------------------------------
local function TEff(t, prof, key, baseKey, default)
	local v = t[key]
	if v == nil then v = prof[baseKey] end
	if v == nil then v = default end
	return v
end

local function BuildGridTile(p, t, prof, dm)
	p:Section("Assigned Debuffs")
	BuildFilters(p, dm, t, t.claim, false)
	MaxDuration(p, t)

	p:Section("Core")
	p:Slider("Size", "Size of each icon in this indicator.", 10, 80, 1,
		function() return t.size or 18 end, function(v) t.size = v end)
	p:Cog("Icon Zoom", {
		{ type = "slider", label = "Zoom", min = 0, max = 0.20, step = 0.01,
		  get = function() return TEff(t, prof, "iconZoom", "debuffIconZoom", 0.08) end, set = function(v) t.iconZoom = v end },
	}, { icon = "resize" })
	p:Slider("Max Debuffs", "Most debuffs this indicator shows.", 1, 10, 1,
		function() return t.cap or 3 end, function(v) t.cap = v end)
	p:Dropdown("Position", "Where this indicator sits on the frame.", function() return Items(POS) end,
		function() return t.position or "top" end, function() return LabelOf(POS, t.position or "top") end,
		function(v)
			t.growDirection = DefaultGrow(v)
			t.position = v
		end)
	p:Cog("Position Offset", {
		{ type = "slider", label = "Offset X", min = -50, max = 50, step = 1,
		  get = function() return t.offsetX or 0 end, set = function(v) t.offsetX = v end },
		{ type = "slider", label = "Offset Y", min = -50, max = 50, step = 1,
		  get = function() return t.offsetY or 0 end, set = function(v) t.offsetY = v end },
	}, { icon = "directions" })
	p:Dropdown("Growth Direction", "Where new icons go.", function() return Items(GROW) end,
		function() return t.growDirection or "CENTER" end, function() return LabelOf(GROW, t.growDirection or "CENTER") end,
		function(v) t.growDirection = v end)
	p:Slider("Icons Per Row", "Wraps into a new row (or column for vertical growth) after this many icons; below 2 keeps one continuous run.",
		0, 20, 1, function() return t.iconsPerRow or 0 end, function(v) t.iconsPerRow = v end)
	p:Blank()

	p:Section("Display")
	p:Slider("Border", "Border thickness of each icon.", 0, 4, 1,
		function() return TEff(t, prof, "borderSize", "debuffBorderSize", 1) end, function(v) t.borderSize = v end)
	p:Swatch("Border Color", function()
		local c = t.borderColor or prof.debuffBorderColor or {}
		return c.r or 0, c.g or 0, c.b or 0
	end, ColorSet(t, "borderColor"))
	p:Slider("Spacing", "Space between icons.", -1, 10, 1,
		function() return t.spacing or 1 end, function(v) t.spacing = v end)
	p:Toggle("Show Duration Text", "Show the time left on each icon.",
		function()
			if t.showDurText ~= nil then return t.showDurText and true or false end
			return prof.debuffShowDurText and true or false
		end, function(v) t.showDurText = v and true or false end)
	p:Cog("Duration Text", {
		{ type = "slider", label = "Text Size", min = 6, max = 26, step = 1,
		  get = function() return TEff(t, prof, "durTextSize", "debuffDurTextSize", 10) end, set = function(v) t.durTextSize = v end },
		{ type = "slider", label = "Offset X", min = -20, max = 20, step = 1,
		  get = function() return TEff(t, prof, "durTextOffsetX", "debuffDurTextOffsetX", 0) end, set = function(v) t.durTextOffsetX = v end },
		{ type = "slider", label = "Offset Y", min = -20, max = 20, step = 1,
		  get = function() return TEff(t, prof, "durTextOffsetY", "debuffDurTextOffsetY", 0) end, set = function(v) t.durTextOffsetY = v end },
	}, { icon = "resize" })
	p:Swatch("Duration Color", function()
		local c = t.durTextColor or prof.debuffDurTextColor or {}
		return c.r or 1, c.g or 1, c.b or 1
	end, ColorSet(t, "durTextColor"))
	p:Toggle("Show Stacks", "Show the stack count on each icon.",
		function()
			if t.showStacks ~= nil then return t.showStacks and true or false end
			return prof.debuffShowStacks ~= false
		end, function(v) t.showStacks = v and true or false end)
	p:Cog("Stacks Text", {
		{ type = "slider", label = "Text Size", min = 6, max = 26, step = 1,
		  get = function() return TEff(t, prof, "stacksTextSize", "debuffStacksTextSize", 11) end, set = function(v) t.stacksTextSize = v end },
		{ type = "slider", label = "Offset X", min = -20, max = 20, step = 1,
		  get = function() return TEff(t, prof, "stacksOffsetX", "debuffStacksOffsetX", 0) end, set = function(v) t.stacksOffsetX = v end },
		{ type = "slider", label = "Offset Y", min = -20, max = 20, step = 1,
		  get = function() return TEff(t, prof, "stacksOffsetY", "debuffStacksOffsetY", 0) end, set = function(v) t.stacksOffsetY = v end },
	}, { icon = "resize" })
	p:Swatch("Stacks Color", function()
		local c = t.stacksTextColor or prof.debuffStacksTextColor or {}
		return c.r or 1, c.g or 1, c.b or 1
	end, ColorSet(t, "stacksTextColor"))
	p:Dropdown("Tooltips", "Debuff tooltips on mouseover.", function() return Items(TIPS) end,
		function()
			local v = t.hideTooltips
			if v == nil then v = prof.debuffHideTooltips end
			return TipModeKey(v)
		end,
		function()
			local v = t.hideTooltips
			if v == nil then v = prof.debuffHideTooltips end
			return LabelOf(TIPS, TipModeKey(v))
		end,
		function(k) t.hideTooltips = TipModeStore(k) end)
	p:Toggle("Show Duration Swipe", "Dark clock swipe over each icon.",
		function()
			if t.showSwipe ~= nil then return t.showSwipe and true or false end
			return prof.debuffShowSwipe ~= false
		end, function(v) t.showSwipe = v and true or false end)
	if t.type == "square" then
		p:ColorRow("Color", "Color of the flat squares.", function()
			local c = t.color or {}
			return c.r or 1, c.g or 0.35, c.b or 0.35, c.a or 1
		end, function(r, g, b, a)
			t.color = { r = r, g = g, b = b, a = a or 1 }
		end, { alpha = true })
		p:Blank()
	end
	BuildFx(p, t, dm)
end

local function BuildEffectTile(p, t, prof, dm)
	p:Section("Effect")
	BuildFilters(p, dm, t, t.claim, false)
	if t.type == "glow" then
		p:Dropdown("Glow", "Glow style around the frame.", function() return { { value = 1, name = "Pixel Glow" } } end,
			function() return 1 end, function() return "Pixel Glow" end, function(v) t.glowType = v end)
		p:Swatch("Glow Color", ColorGet(t, "color", 1, 0.78, 0.38), ColorSet(t, "color"))
		MaxDuration(p, t)
		p:Blank()
	elseif t.type == "healthcolor" then
		p:Label("Color", "Tint over the health bar while a matched debuff is up.")
		p:Swatch("Color", ColorGet(t, "color", 1, 0.25, 0.25), ColorSet(t, "color"))
		p:Slider("Opacity", "Opacity of the tint.", 5, 100, 1,
			function() return t.opacity or 45 end, function(v) t.opacity = v end)
		MaxDuration(p, t)
	elseif t.type == "bar" then
		p:Blank()
		local isVert = (t.orientation or "HORIZONTAL") == "VERTICAL"
		p:Section("Core")
		p:Dropdown("Orientation", "Bar direction.", function() return Items(ORIENT) end,
			function() return t.orientation or "HORIZONTAL" end,
			function() return LabelOf(ORIENT, t.orientation or "HORIZONTAL") end,
			function(v)
				t.orientation = v
				Rebuild()
			end)
		p:Dropdown("Position", "Where the bar sits on the frame.", function() return Items(POS) end,
			function() return t.position or "bottom" end, function() return LabelOf(POS, t.position or "bottom") end,
			function(v) t.position = v end)
		p:Cog("Position Offset", {
			{ type = "slider", label = "Offset X", min = -50, max = 50, step = 1,
			  get = function() return t.offsetX or 0 end, set = function(v) t.offsetX = v end },
			{ type = "slider", label = "Offset Y", min = -50, max = 50, step = 1,
			  get = function() return t.offsetY or 0 end, set = function(v) t.offsetY = v end },
			{ type = "dropdown", label = "Frame Level", items = function() return Items(FRAME_LEVELS) end,
			  get = function() return t.frameLevel or "behindBorders" end, set = function(v) t.frameLevel = v end },
		}, { icon = "directions" })
		p:Toggle("Reverse Fill", "Fill the bar from the other end.",
			function() return t.reverseFill or false end, function(v) t.reverseFill = v and true or false end)
		p:Blank()
		p:Section("Display")
		p:Slider(isVert and "Height" or "Width", "Bar length.", 5, 200, 1,
			function() return t.width or 60 end, function(v) t.width = v end,
			function() return t.barFullWidth end)
		p:Slider(isVert and "Width" or "Height", "Bar thickness.", 1, 100, 1,
			function() return t.height or 5 end, function(v) t.height = v end,
			function() return t.barFullHeight end)
		p:Toggle(isVert and "Full Height Bar" or "Full Width Bar", "The bar spans the frame.",
			function() return t.barFullWidth or false end, function(v) t.barFullWidth = v and true or false end)
		p:Toggle(isVert and "Full Width Bar" or "Full Height Bar", "The bar is as thick as the frame.",
			function() return t.barFullHeight or false end, function(v) t.barFullHeight = v and true or false end)
		p:Slider("Color", "Bar color opacity.", 0, 100, 1,
			function() return t.barColorOpacity or 100 end, function(v) t.barColorOpacity = v end)
		p:Swatch("Bar Color", ColorGet(t, "color", 0.25, 0.8, 0.45), ColorSet(t, "color"))
		p:Slider("Background", "Background opacity.", 0, 100, 1,
			function() return t.barBgOpacity or 50 end, function(v) t.barBgOpacity = v end)
		p:Swatch("Background Color", ColorGet(t, "barBgColor", 0, 0, 0), ColorSet(t, "barBgColor"))
	end
end

local function BuildTile(p, e)
	local prof = P()
	local dm = DM()
	local t = e.t
	if not (prof and dm and t) then
		return
	end
	t.claim = t.claim or {}
	p:Section("Indicator")
	if e.inherited then
		p:Toggle("Enabled For This Spec", "Inherited from " .. SpecName(e.bucket) .. ". Off hides this indicator for this spec only.",
			function()
				local b = SpecBucket(false)
				return not (b and b.inhDis and b.inhDis[t.id])
			end,
			function(v)
				local b = SpecBucket(true)
				if b then
					b.inhDis[t.id] = (not v) or nil
				end
			end)
		p:Blank()
		p:Paragraph(format("Inherited from %s. Edit it there, or use the toggle to enable or disable it for this spec.", SpecName(e.bucket)))
		return
	end
	p:Toggle("Enabled", "Show this indicator.", function() return t.enabled ~= false end,
		function(v) t.enabled = v and true or false end)
	p:Label(TYPE_NAMES[t.type] or t.type, TileSubtitle(t))
	if t.type == "icons" or t.type == "square" then
		BuildGridTile(p, t, prof, dm)
	else
		BuildEffectTile(p, t, prof, dm)
	end
end

---------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------
local function Build(p)
	if not (RF() and P()) then
		p:Section("Debuff Manager")
		p:Paragraph("Raid Frames are not loaded.")
		return
	end
	local e = Selected()
	if not e then
		p:Section("Debuff Manager")
		p:Paragraph(format("Indicators added here show on every spec in this group. The Base Icons grid lives in %s.", "All Specs"))
		return
	end
	if e.kind == "base" then
		BuildBase(p, e)
	else
		BuildTile(p, e)
	end
end
ns.RFO_BuildDebuffManagerPage = Build

ns.RFO_DebuffManagerPageKey = function()
	return table.concat({ "dm", dmSpecSel, tostring(dmSel), rev }, ":")
end

---------------------------------------------------------------------------
-- Content header: Editing Spec | indicator | rename | delete, + Add New
---------------------------------------------------------------------------
local function PromptRename(t)
	ns.ShowInputPopup({
		title = "Rename Indicator",
		message = "Enter a new name for this indicator:",
		text = TileName(t),
		confirmText = "Rename",
		cancelText = "Cancel",
		onConfirm = function(text)
			text = text and strtrim(text) or ""
			t.name = text ~= "" and text or nil
			Rebuild()
		end,
	})
end

local function PromptDelete(t)
	ns.ShowConfirmPopup({
		title = "Delete Indicator",
		message = "Delete this indicator? Its settings are removed from the profile.",
		confirmText = "Delete",
		cancelText = "Cancel",
		onConfirm = function()
			local rf = RF()
			if rf and rf.DM_DeleteTile then
				rf.DM_DeleteTile(t.id)
			end
			dmSel = "base"
			if ns.ERF and ns.ERF.ApplyAll then
				ns.ERF:ApplyAll()
			end
			Rebuild()
		end,
	})
end

local function Header(page, host, width)
	local y = 16
	local DD_H, ICON, GAP = 30, 30, 6
	local SPEC_W, IND_W, ADD_W = 190, 240, 150
	local total = SPEC_W + 12 + IND_W + GAP + ICON + GAP + ICON
	local x0 = floor((width - total) / 2)
	local specLabel = Text(host, 11, 0.45)
	specLabel:SetText("EDITING SPEC")
	specLabel:SetPoint("BOTTOMLEFT", host, "TOPLEFT", x0, -y + 2)
	local spec = page:HeaderDropdown(host, SPEC_W, DD_H, SpecItems, function() return dmSpecSel end,
		function() return SpecName(dmSpecSel) end,
		function(v)
			dmSpecSel = v
			dmSel = "base"
			Rebuild()
		end)
	spec:SetPoint("TOPLEFT", host, "TOPLEFT", x0, -y)
	local indLabel = Text(host, 11, 0.45)
	indLabel:SetText("INDICATOR")
	local ind = page:HeaderDropdown(host, IND_W, DD_H,
		function()
			local items = {}
			for _, e in ipairs(ListedIndicators()) do
				local name
				if e.kind == "base" then
					name = "Base Icons"
				else
					name = TileName(e.t)
					if e.t.enabled == false then
						name = name .. "  |cff888888(off)|r"
					end
				end
				if e.inherited then
					name = name .. "  |cff888888(inherited)|r"
				end
				items[#items + 1] = { value = EntryKey(e), name = name }
			end
			return items
		end,
		function() return dmSel == "base" and "base" or ("t" .. tostring(dmSel)) end,
		function()
			local e = Selected()
			if not e then
				return "No indicator selected"
			end
			return e.kind == "base" and "Base Icons" or TileName(e.t)
		end,
		function(v)
			if v == "base" then
				dmSel = "base"
			else
				dmSel = tonumber(v:sub(2)) or v:sub(2)
			end
			Rebuild()
		end)
	ind:SetPoint("LEFT", spec, "RIGHT", 12, 0)
	indLabel:SetPoint("BOTTOMLEFT", ind, "TOPLEFT", 0, 2)
	local cur = Selected()
	local own = cur and cur.kind == "tile" and not cur.inherited
	local rename = page:HeaderIconButton(host, ICON, "Interface\\Buttons\\UI-GuildButton-PublicNote-Up", 16, "Rename Indicator", function()
		local e = Selected()
		if e and e.kind == "tile" and not e.inherited then
			PromptRename(e.t)
		end
	end)
	rename:SetPoint("LEFT", ind, "RIGHT", GAP, 0)
	rename:SetAlpha(own and 1 or 0.3)
	local delete = page:HeaderIconButton(host, ICON, ns.MEDIA .. "ui\\eui-close", 16, "Delete Indicator", function()
		local e = Selected()
		if e and e.kind == "tile" and not e.inherited then
			PromptDelete(e.t)
		end
	end)
	delete:SetPoint("LEFT", rename, "RIGHT", GAP, 0)
	delete:SetAlpha(own and 1 or 0.3)
	y = y + DD_H + 14
	-- "+ Add New": pick the indicator type; it lands in the edited spec view.
	local add = page:HeaderDropdown(host, ADD_W, 28,
		function()
			local items = { { header = true, name = "Indicator" } }
			for _, k in ipairs(TYPE_ORDER) do
				items[#items + 1] = { value = k, name = TYPE_NAMES[k] }
			end
			return items
		end,
		function() return nil end,
		function() return "+ Add New" end,
		function(v)
			local rf = RF()
			if not (rf and rf.DM_AddTile) then
				return
			end
			local t = rf.DM_AddTile(v, dmSpecSel)
			if t then
				dmSel = t.id
			end
			if ns.ERF and ns.ERF.ApplyAll then
				ns.ERF:ApplyAll()
			end
			Rebuild()
		end)
	add:SetPoint("TOP", host, "TOP", 0, -y)
	y = y + 28 + 14
	return y
end
ns.RFO_DebuffManagerHeader = Header
