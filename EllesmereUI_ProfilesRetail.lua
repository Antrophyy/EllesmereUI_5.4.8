-- Retail profile strings -> the Mists layout (EllesmereUI_Profiles.lua).
--
-- A retail string holds data.addons[folder] = that module's retail profile
-- (complete for the active profile, only non-default values otherwise) and
-- profile-root fields (fonts, euiAccent, uiScale, unlockLayout,
-- blizzSkinGlobals, chatBubbles, tooltipFixedPos). Each converter returns
-- the module's new SavedVariables table; missing keys are filled from the
-- Mists defaults when the module loads after the reload.
--
-- Modules that only partly match (QoL, Quest Tracker, Spell History,
-- Blizzard Skins+, Top Bar) start from the current Mists settings and take
-- over only the matching keys. Newer modules register their own converter in
-- R.CONVERT from their runtime file (data = the whole retail export is the 3rd
-- argument). Retail-only modules (Dragon Riding) are skipped.

local ns = EllesmereUI

local R = {}
ns.ProfileRetail = R

local DeepCopy = ns.ProfileDeepCopy

local function Current(folder)
	local entry = ns.ProfileAddonEntry(folder)
	local root = entry and _G[entry.svName]
	local copy = type(root) == "table" and DeepCopy(root) or {}
	for _, path in ipairs(ns.PROFILE_PRIVATE[folder] or {}) do
		local t = copy
		local parts = {}
		for part in path:gmatch("[^%.]+") do
			parts[#parts + 1] = part
		end
		for i = 1, #parts - 1 do
			t = type(t) == "table" and t[parts[i]] or nil
		end
		if type(t) == "table" then
			t[parts[#parts]] = nil
		end
	end
	return copy
end

-- {r,g,b} -> {1,2,3} (Mists Spell History / character sheet colors)
local function RGBArray(c, fallback)
	if type(c) ~= "table" then
		return fallback
	end
	local f = fallback or { 1, 1, 1 }
	return { c.r or c[1] or f[1], c.g or c[2] or f[2], c.b or c[3] or f[3] }
end

local function Pct(v)
	if type(v) ~= "number" then
		return nil
	end
	return math.floor(v * 100 + 0.5)
end

-- Modules whose retail profile is the Mists "sv.profile" as is.
local function AsProfile(blob)
	return { profile = DeepCopy(blob), version = 1 }
end

local CONVERT = {}
-- Modules add their own converter: EllesmereUI.ProfileRetail.CONVERT[folder] = function(blob, notes) return newSV end
R.CONVERT = CONVERT

CONVERT.EllesmereUIActionBars = function(blob)
	return AsProfile(blob)
end

CONVERT.EllesmereUIRaidFrames = function(blob)
	return AsProfile(blob)
end

CONVERT.EllesmereUINameplates = function(blob)
	return AsProfile(blob)
end

CONVERT.EllesmereUIBags = function(blob)
	-- Always a .profile table, or the first-run seed would replace it.
	return { profile = DeepCopy(blob) }
end

CONVERT.EllesmereUIDataBars = function(blob)
	local profile = DeepCopy(blob)
	profile.characters = nil
	return { profile = profile }
end

CONVERT.EllesmereUIUnitFrames = function(blob)
	return DeepCopy(blob)
end

CONVERT.EllesmereUIResourceBars = function(blob, notes)
	local root = AsProfile(blob)
	-- Retail bars anchored to the Cooldown Manager keep the Mists position.
	local cur = Current("EllesmereUIResourceBars").profile
	local kept = false
	for section, cfg in pairs(root.profile) do
		if type(cfg) == "table" and type(cfg.anchorTo) == "string" and cfg.anchorTo ~= "none" and cfg.anchorTo ~= "" then
			local mine = type(cur) == "table" and type(cur[section]) == "table" and cur[section].unlockPos
			cfg.unlockPos = DeepCopy(mine) or nil
			kept = true
		end
	end
	if kept then
		notes[#notes + 1] = "Resource Bars: bars anchored to the Cooldown Manager keep your current position."
	end
	return root
end

CONVERT.EllesmereUIChat = function(blob)
	local profile = DeepCopy(blob)
	local chat = profile.chat
	if type(chat) == "table" and type(chat.chatPosition) == "table" then
		local cp = chat.chatPosition
		if (cp.point or "BOTTOMLEFT") == "BOTTOMLEFT" and (cp.relPoint or "BOTTOMLEFT") == "BOTTOMLEFT"
			and type(cp.x) == "number" and type(cp.y) == "number" then
			profile.chatPos = { x = cp.x, y = cp.y }
		end
	end
	return { profile = profile, version = 1 }
end

CONVERT.EllesmereUIMinimap = function(blob)
	local root = AsProfile(blob)
	local mm = root.profile.minimap
	if type(mm) == "table" then
		-- Without this the module takes Blizzard's minimap size and spot again.
		mm._capturedOnce = true
	end
	return root
end

CONVERT.EllesmereUIQoL = function(blob)
	local root = Current("EllesmereUIQoL")
	if type(blob.battleRes) == "table" then
		root.battleRes = DeepCopy(blob.battleRes)
	end
	if type(blob.bloodlust) == "table" then
		root.bloodlust = DeepCopy(blob.bloodlust)
	end
	if not root.battleRes and not root.bloodlust then
		return nil
	end
	return root
end

local QT_KEYS = {
	"autoAccept", "autoAcceptPreventMulti", "autoAcceptShiftSkip",
	"autoAcceptIgnoreTrivial", "autoTurnIn", "autoTurnInShiftSkip",
}
CONVERT.EllesmereUIQuestTracker = function(blob)
	local qt = type(blob.questTracker) == "table" and blob.questTracker or blob
	local root = Current("EllesmereUIQuestTracker")
	local any = false
	for _, k in ipairs(QT_KEYS) do
		if qt[k] ~= nil then
			root[k] = qt[k]
			any = true
		end
	end
	return any and root or nil
end

-- Retail Damage Meters -> Mists Spell History (only its spell history part).
CONVERT.EllesmereUIDamageMeters = function(blob, notes)
	local sh = type(blob.dm) == "table" and blob.dm.spellHistory
	if type(sh) ~= "table" then
		return nil
	end
	local root = Current("EllesmereUIDamageMeters")
	root.spellHistory = type(root.spellHistory) == "table" and root.spellHistory or {}
	local d = root.spellHistory
	local function set(k, v)
		if v ~= nil then
			d[k] = v
		end
	end
	for _, k in ipairs({ "iconEnabled", "barEnabled", "iconSize", "iconSpacing", "iconFadeTime",
		"iconAnimation", "barWidth", "textSize" }) do
		set(k, sh[k])
	end
	for k, v in pairs(sh) do
		if (k:find("^iconHideIn") or k:find("^barHideIn")) and not k:find("Delve") then
			d[k] = v
		end
	end
	set("iconGrow", sh.growDirection)
	set("iconZoom", Pct(sh.iconZoom))
	set("iconMax", sh.iconCount)
	set("iconOpacity", Pct(sh.iconOpacity))
	set("barMax", sh.maxBars)
	set("barHideTopBar", sh.hideTopBar)
	set("barHeight", sh.shBarHeight)
	-- Retail keeps a texture key ("match" = the damage meter texture); Mists
	-- keeps a file path. Only a SharedMedia texture installed here carries over.
	local tex = sh.spellHistoryBarTexture
	if type(tex) == "string" and tex:sub(1, 3) == "sm:" then
		local lsm = ns.GetLSM and ns.GetLSM()
		local path = lsm and lsm:Fetch("statusbar", tex:sub(4), true)
		if path then
			d.barTexture = path
		end
	end
	set("barOpacity", Pct(sh.barOpacity))
	if sh.barColor then
		d.barColor = RGBArray(sh.barColor, d.barColor)
	end
	if sh.barColorUseClass then
		d.barColorMode = "class"
	elseif sh.barColorUseAccent then
		d.barColorMode = "accent"
	elseif sh.barColorUseClass == false or sh.barColorUseAccent == false then
		d.barColorMode = "custom"
	end
	if sh.textColor then
		d.textColor = RGBArray(sh.textColor, d.textColor)
	end
	if sh.textColorUseAccent ~= nil then
		d.textColorMode = sh.textColorUseAccent and "accent" or "custom"
	end
	if sh.bgR or sh.bgG or sh.bgB then
		local bg = d.bgColor or { 0, 0, 0 }
		d.bgColor = { sh.bgR or bg[1], sh.bgG or bg[2], sh.bgB or bg[3] }
	end
	set("bgAlpha", Pct(sh.bgAlpha))
	notes[#notes + 1] = "Spell History: settings come from the retail Damage Meters spell history; positions stay as they are."
	return root
end

-- Retail NaowhUI top bar (rides in the profile as addons.NaowhUI_EUI.topBar).
local function ConvertTopBar(nui)
	local tb = type(nui) == "table" and nui.topBar
	if type(tb) ~= "table" then
		return nil
	end
	local root = Current("EllesmereUITopBar")
	for k, v in pairs(tb) do
		root[k] = DeepCopy(v)
	end
	root._seeded = 1
	return root
end

-- Retail character sheet keys (on the retail account root) -> Mists charSheet.
local CHARSHEET_SAME = {
	"showItemLevel", "showUpgradeTrack", "showGems", "showEnchants", "flyoutItemLevels",
}
local CHARSHEET_MAP = {
	charSheetEnchantNames = "enchantNames",
	charSheetEnchantSize = "enchantSize",
	showCharSheetDurability = "showDurability",
	charSheetDurabilityLocation = "durabilityLocation",
	charSheetDurabilityShowLabel = "durabilityShowLabel",
	charSheetHideSlotFlyoutArrows = "hideSlotFlyoutArrows",
	showManaStat = "showMana",
	charSheetBlizzColors = "blizzColors",
	highlightSecondaryItems = "secondaryHighlights",
}

local function ConvertCharSheet(g, cs)
	for _, k in ipairs(CHARSHEET_SAME) do
		if g[k] ~= nil then
			cs[k] = g[k]
		end
	end
	for from, to in pairs(CHARSHEET_MAP) do
		if g[from] ~= nil then
			cs[to] = g[from]
		end
	end
	if type(g.charSheetIconZoom) == "number" then
		cs.iconZoom = Pct(g.charSheetIconZoom)
	end
	if g.showSecondaryBoth then
		cs.secondaryText = "both"
	elseif g.showSecondaryRaw then
		cs.secondaryText = "value"
	elseif g.showSecondaryBoth == false and g.showSecondaryRaw == false then
		cs.secondaryText = "pct"
	end
	local styles = g.blizzWindowSkinStyles
	if g.themedCharacterSheet == false then
		cs.style = "off"
	elseif type(styles) == "table" and styles.charsheet then
		cs.style = styles.charsheet
	end
end

local CHARSHEET_SKIP = { statSectionsOrder = true, statCategoryColors = true, statCategoryUseColor = true,
	charSheetCollapsedSections = true, charSheetIconZoom = true, themedCharacterSheet = true,
	showSecondaryBoth = true, showSecondaryRaw = true }
for _, k in ipairs(CHARSHEET_SAME) do
	CHARSHEET_SKIP[k] = true
end
for k in pairs(CHARSHEET_MAP) do
	CHARSHEET_SKIP[k] = true
end

-- Blizzard Skins+ keys of a retail account root (full account strings have
-- no blizzSkinGlobals bundle; the whole account root comes instead).
local BS_PREFIXES = {
	"tooltip", "reskin", "blizzWin", "popupMenu", "inspect", "lootToast", "queueTimer",
	"uberTooltips", "customTooltips", "resurrectAcceptGlow", "accentReskinElements",
	"charSheet", "showStatCategory_", "statSections", "statCategory", "themedCharacterSheet",
	"showItemLevel", "showUpgradeTrack", "showGems", "showEnchants", "flyoutItemLevels",
	"showCharSheetDurability", "showManaStat", "highlightSecondaryItems", "showSecondary",
}
function R.PickBlizzSkinGlobals(acct)
	local out = {}
	for k, v in pairs(acct) do
		if type(k) == "string" then
			for _, p in ipairs(BS_PREFIXES) do
				if k:sub(1, #p) == p then
					out[k] = DeepCopy(v)
					break
				end
			end
		end
	end
	return out
end

local function ConvertBlizzSkin(data)
	local g = data.blizzSkinGlobals
	local hasBubbles = type(data.chatBubbles) == "table"
	local hasTipPos = type(data.tooltipFixedPos) == "table"
	if type(g) ~= "table" and not hasBubbles and not hasTipPos then
		return nil
	end
	local root = Current("EllesmereUIBlizzardSkin")
	if type(g) == "table" then
		for k, v in pairs(g) do
			if not CHARSHEET_SKIP[k] and not k:find("^showStatCategory_") then
				root[k] = DeepCopy(v)
			end
		end
		root.charSheet = type(root.charSheet) == "table" and root.charSheet or {}
		ConvertCharSheet(g, root.charSheet)
	end
	if hasBubbles then
		root.chatBubbles = DeepCopy(data.chatBubbles)
		root.chatBubbles.seeded = true
	end
	if hasTipPos then
		root.tooltipFixedPos = DeepCopy(data.tooltipFixedPos)
	end
	return root
end

-- Unlock Mode links: only between elements this client has.
local LAYOUT_MAP = {
	anchors = "unlockAnchors",
	widthMatch = "unlockWidthMatch",
	heightMatch = "unlockHeightMatch",
	widthMatchExtra = "unlockWidthMatchExtra",
	heightMatchExtra = "unlockHeightMatchExtra",
	phantomBounds = "phantomBounds",
}

local function ConvertLayout(ul, notes)
	if type(ul) ~= "table" then
		return nil
	end
	local known = ns._unlockRegisteredElements
	if type(known) ~= "table" or next(known) == nil then
		known = nil
	end
	local function Known(key)
		if not known or type(key) ~= "string" or key == "UIParent" then
			return true
		end
		return known[key] ~= nil
	end
	local out, dropped, lost = {}, 0, {}
	for from, to in pairs(LAYOUT_MAP) do
		local src = ul[from]
		if type(src) == "table" then
			local t = {}
			for child, v in pairs(src) do
				local target = type(v) == "table" and v.target or v
				if from == "phantomBounds" or (Known(child) and Known(target)) then
					t[child] = DeepCopy(v)
				else
					dropped = dropped + 1
					if from == "anchors" and Known(child) then
						lost[child] = true
					end
				end
			end
			out[to] = t
		end
	end
	if dropped > 0 then
		notes[#notes + 1] = format("Unlock Mode Layout: %d link(s) to retail-only elements (Cooldown Manager, Raid Frames, ...) were left out. Elements that were anchored to them keep your current position.", dropped)
	end
	if next(out) == nil then
		return nil, lost
	end
	return out, lost
end

-- Where an unlock element keeps its own position (path in the module's
-- SavedVariables). An element whose retail anchor target is not in Mists
-- (e.g. the player frame on the Cooldown Manager) keeps the current spot.
local POSITION_PATHS = {
	ERB_Health = { "EllesmereUIResourceBars", "profile", "health", "unlockPos" },
	ERB_Power = { "EllesmereUIResourceBars", "profile", "primary", "unlockPos" },
	ERB_ClassResource = { "EllesmereUIResourceBars", "profile", "secondary", "unlockPos" },
	ERB_CastBar = { "EllesmereUIResourceBars", "profile", "castBar", "unlockPos" },
	ERB_GCDBar = { "EllesmereUIResourceBars", "profile", "gcdBar", "unlockPos" },
	ERB_TotemBar = { "EllesmereUIResourceBars", "profile", "totemBar", "unlockPos" },
	EBS_Minimap = { "EllesmereUIMinimap", "profile", "minimap", "position" },
}
for _, k in ipairs({ "player", "target", "focus", "pet", "targettarget", "focustarget", "boss", "classPower", "playerCastbar" }) do
	POSITION_PATHS[k] = { "EllesmereUIUnitFrames", "positions", k }
end
for _, k in ipairs({ "MainBar", "Bar2", "Bar3", "Bar4", "Bar5", "Bar6", "Bar7", "Bar8", "Bar9", "Bar10",
	"StanceBar", "PetBar", "MicroBar", "BagBar", "ExtraActionButton", "XPBar", "RepBar" }) do
	POSITION_PATHS[k] = { "EllesmereUIActionBars", "profile", "barPositions", k }
end

local function KeepPositions(addons, lost)
	for child in pairs(lost or {}) do
		local path = POSITION_PATHS[child]
		local root = path and addons[path[1]]
		if root then
			local cur = Current(path[1])
			for i = 2, #path - 1 do
				cur = type(cur) == "table" and cur[path[i]] or nil
				if type(root[path[i]]) ~= "table" then
					root[path[i]] = {}
				end
				root = root[path[i]]
			end
			local last = path[#path]
			root[last] = type(cur) == "table" and DeepCopy(cur[last]) or nil
		end
	end
end

local function ConvertGlobals(data)
	local g = {}
	if type(data.fonts) == "table" then
		g.fonts = DeepCopy(data.fonts)
		g.fonts._styleSlots = nil
		g.fonts.neverShowSlug = nil
		-- A retail file path (often another addon's folder); the name is resolved here.
		g.fonts.unitNameFontPath = nil
	end
	local acc = data.euiAccent
	if type(acc) == "table" then
		g.useClassAccentColor = acc.useClass and true or false
		if type(acc.custom) == "table" then
			g.customAccentColor = { r = acc.custom.r, g = acc.custom.g, b = acc.custom.b }
		end
	end
	if type(data.uiScale) == "number" then
		g.ppUIScale = data.uiScale
		g.ppUIScaleAuto = false
	end
	-- Global Settings > Colors (EllesmereUI_Colors.lua): same keys as retail.
	if type(data.customColors) == "table" then
		g.customColors = DeepCopy(data.customColors)
	end
	if type(data.darkMode) == "table" then
		g.darkMode = DeepCopy(data.darkMode)
	end
	if next(g) == nil then
		return nil
	end
	return g
end

-- Fonts and SharedMedia textures the string names but this client does not
-- have. Nothing breaks: a missing texture draws a flat bar, a missing font
-- falls back to Expressway. The import page lists them.
local function MissingMedia(out, notes)
	local lsm = ns.GetLSM and ns.GetLSM()
	local tex, fonts = {}, {}
	local function FontKnown(name)
		return name == "__global" or name == "__default" or name == ""
			or (ns.FONT_FILES and ns.FONT_FILES[name]) or (ns.FONT_BLIZZARD and ns.FONT_BLIZZARD[name])
			or (ns.BLIZZARD_FONT_KEY and name == ns.BLIZZARD_FONT_KEY)
			or (ns.EXPRESSWAY_FORCED_KEY and name == ns.EXPRESSWAY_FORCED_KEY)
			or (lsm and lsm:IsValid("font", name))
	end
	local function TexKnown(name)
		if not lsm then
			return false
		end
		return lsm:Fetch("statusbar", name, true) or lsm:Fetch("background", name, true)
			or lsm:Fetch("border", name, true)
	end
	local function Walk(t, depth)
		if depth > 30 then
			return
		end
		for k, v in pairs(t) do
			if type(v) == "table" then
				Walk(v, depth + 1)
			elseif type(v) == "string" then
				local key = type(k) == "string" and k:lower() or ""
				if v:sub(1, 3) == "sm:" then
					local name = v:sub(4)
					if not TexKnown(name) then
						tex[name] = true
					end
				elseif (key:find("font$") or key == "global") and not v:find("\\") and not FontKnown(v) then
					fonts[v] = true
				end
			end
		end
	end
	Walk(out.addons, 1)
	if out.globals and out.globals.fonts then
		Walk(out.globals.fonts, 1)
	end
	local function List(set)
		local l = {}
		for name in pairs(set) do
			l[#l + 1] = name
		end
		table.sort(l)
		return table.concat(l, ", ")
	end
	if next(tex) then
		notes[#notes + 1] = "Textures not installed here (bars show a flat texture until you install them, e.g. with SharedMedia, or pick another): " .. List(tex) .. "."
	end
	if next(fonts) then
		notes[#notes + 1] = "Fonts not installed here (Expressway is used instead): " .. List(fonts) .. "."
	end
end

-- Retail Spec Overrides: some settings have their own value per spec group
-- (profile.specOverrides, retail EllesmereUI_SpecOverrides.lua). The module
-- data holds the values of the spec the exporter was in, so the values for
-- the importing character's spec (or the default ones) are written in.
local SPECOV_PS, SPECOV_FS, SPECOV_NIL = "\30", "\31", "__SPECOV_NIL__"

local function SegKey(t, seg)
	if t[seg] ~= nil then
		return seg
	end
	local n = tonumber(seg)
	if n ~= nil and t[n] ~= nil then
		return n
	end
	return seg
end

local function ApplySpecOverrides(data)
	local store = data.specOverrides
	if type(store) ~= "table" or type(data.addons) ~= "table" then
		return
	end
	local specID
	local idx = GetSpecialization and GetSpecialization()
	if idx and GetSpecializationInfo then
		specID = GetSpecializationInfo(idx)
	end
	for _, entry in ipairs(store) do
		local values = type(entry) == "table" and entry.values
		local def = type(values) == "table" and values.default
		if type(def) == "table" then
			local m = specID and (values[specID] or values[tostring(specID)])
			if type(m) ~= "table" then
				m = def
			end
			for fkey, dv in pairs(def) do
				local v = m[fkey]
				if v == nil then
					v = dv
				end
				local folder, path = type(fkey) == "string" and fkey:match("^([^\31]+)\31(.*)$")
				local t = folder and data.addons[folder]
				-- Only plain values on paths that exist (never build new tables).
				if type(t) == "table" and v ~= SPECOV_NIL and v ~= nil and type(v) ~= "table" then
					local segs = {}
					for seg in (path .. SPECOV_PS):gmatch("(.-)" .. SPECOV_PS) do
						segs[#segs + 1] = seg
					end
					for i = 1, #segs - 1 do
						t = t and t[SegKey(t, segs[i])]
						if type(t) ~= "table" then
							t = nil
							break
						end
					end
					if t and #segs > 0 then
						t[SegKey(t, segs[#segs])] = v
					end
				end
			end
		end
	end
end

-- The override stores are kept too (EllesmereUI_SpecOverrides.lua switches
-- the values with the spec / condition at run time). A retail fkey points
-- into the retail module profile; the Mists path can differ (converters wrap
-- the profile or rename keys), so each setting is mapped by running the
-- module's converter with a probe value and looking for what changed. The
-- stored values go through the converter the same way.
local SPECOV_PROBE_NUM = 98765.4321
local SPECOV_PROBE_STR = "__EUIPROBE__"
-- Retail-only specs (Evoker, Demon Hunter, ...) are dropped from groups.
local MISTS_SPECS = {
	[62] = 1, [63] = 1, [64] = 1, [65] = 1, [66] = 1, [70] = 1, [71] = 1, [72] = 1, [73] = 1,
	[102] = 1, [103] = 1, [104] = 1, [105] = 1, [250] = 1, [251] = 1, [252] = 1, [253] = 1,
	[254] = 1, [255] = 1, [256] = 1, [257] = 1, [258] = 1, [259] = 1, [260] = 1, [261] = 1,
	[262] = 1, [263] = 1, [264] = 1, [265] = 1, [266] = 1, [267] = 1, [268] = 1, [269] = 1, [270] = 1,
}
-- Conditions this port does not have.
local DROPPED_CONDS = { darkmode = true, druid_form = true }

local function SpecovSegs(path)
	local segs = {}
	for seg in (path .. SPECOV_PS):gmatch("(.-)" .. SPECOV_PS) do
		segs[#segs + 1] = seg
	end
	return segs
end

local function SpecovSet(t, segs, v)
	for i = 1, #segs - 1 do
		local k = SegKey(t, segs[i])
		if type(t[k]) ~= "table" then
			if v == nil then
				return
			end
			local n = tonumber(segs[i])
			if n and t[n] == nil and t[segs[i]] == nil then
				k = n
			end
			t[k] = {}
		end
		t = t[k]
	end
	t[SegKey(t, segs[#segs])] = v
end

local function SpecovRead(t, path)
	for _, seg in ipairs(SpecovSegs(path)) do
		if type(t) ~= "table" then
			return nil
		end
		t = t[SegKey(t, seg)]
	end
	return t
end

-- Leaf paths that differ between two converter outputs.
local function SpecovDiff(a, b, prefix, out)
	local keys = {}
	if type(a) == "table" then
		for k in pairs(a) do
			keys[k] = true
		end
	end
	if type(b) == "table" then
		for k in pairs(b) do
			keys[k] = true
		end
	end
	for k in pairs(keys) do
		local va = type(a) == "table" and a[k] or nil
		local vb = type(b) == "table" and b[k] or nil
		local p = prefix and (prefix .. SPECOV_PS .. tostring(k)) or tostring(k)
		if type(va) == "table" or type(vb) == "table" then
			if type(va) == type(vb) then
				SpecovDiff(va, vb, p, out)
			elseif type(vb) ~= "table" then
				out[#out + 1] = p
			else
				SpecovDiff(nil, vb, p, out)
			end
		elseif va ~= vb then
			out[#out + 1] = p
		end
	end
	return out
end

local function MapOverrides(data, notes)
	local specStore = type(data.specOverrides) == "table" and data.specOverrides or nil
	local condStore = type(data.condOverrides) == "table" and data.condOverrides or nil
	local hasSpec = specStore and next(specStore) ~= nil
	local hasCond = condStore and next(condStore) ~= nil
	local specGroupsIn = type(data.specOverrideGroups) == "table" and data.specOverrideGroups or {}
	local condGroupsIn = type(data.condOverrideGroups) == "table" and data.condOverrideGroups or {}
	if not hasSpec and not hasCond and not next(specGroupsIn) and not next(condGroupsIn) then
		return nil
	end
	local addons = type(data.addons) == "table" and data.addons or {}

	-- Every stored value per fkey.
	local samples = {}
	for _, store in ipairs({ specStore or {}, condStore or {} }) do
		for _, e in ipairs(store) do
			if type(e) == "table" and type(e.values) == "table" then
				for _, m in pairs(e.values) do
					if type(m) == "table" then
						for fkey, v in pairs(m) do
							if type(fkey) == "string" and type(v) ~= "table" then
								samples[fkey] = samples[fkey] or {}
								samples[fkey][v] = true
							end
						end
					end
				end
			end
		end
	end

	local baseOut = {}
	local function Run(folder, blob)
		local ok, root = pcall(CONVERT[folder], blob, {}, data)
		if ok and type(root) == "table" then
			return root
		end
		return nil
	end
	local function Base(folder)
		if baseOut[folder] == nil then
			baseOut[folder] = Run(folder, DeepCopy(addons[folder])) or false
		end
		return baseOut[folder] or nil
	end

	-- fkey -> { [mistsFkey] = { id = true } or { byValue = {} } } or false
	local maps = {}
	local function MapFKey(fkey)
		if maps[fkey] ~= nil then
			return maps[fkey]
		end
		maps[fkey] = false
		local folder, path = fkey:match("^([^\31]+)\31(.*)$")
		if not folder or not CONVERT[folder] or type(addons[folder]) ~= "table" or path == "" then
			return false
		end
		local base = Base(folder)
		if not base then
			return false
		end
		local segs = SpecovSegs(path)
		local function With(v)
			local b = DeepCopy(addons[folder])
			SpecovSet(b, segs, v)
			return Run(folder, b)
		end
		-- Probe values by the type of the stored values, then the values.
		local probes, kind = {}, nil
		for v in pairs(samples[fkey] or {}) do
			if v ~= SPECOV_NIL then
				kind = kind or type(v)
			end
		end
		if kind == "number" or kind == nil then
			probes[#probes + 1] = SPECOV_PROBE_NUM
		end
		if kind == "boolean" or kind == nil then
			probes[#probes + 1] = true
			probes[#probes + 1] = false
		end
		if kind == "string" then
			probes[#probes + 1] = SPECOV_PROBE_STR
		end
		for v in pairs(samples[fkey] or {}) do
			if v ~= SPECOV_NIL then
				probes[#probes + 1] = v
			end
		end
		local targets, probeOut, probeVal
		for _, pv in ipairs(probes) do
			local out = With(pv)
			local d = out and SpecovDiff(base, out, nil, {}) or {}
			if #d > 0 then
				targets, probeOut, probeVal = d, out, pv
				break
			end
		end
		if not targets or #targets > 4 then
			return false
		end
		local result = {}
		for _, t in ipairs(targets) do
			local tf = folder .. SPECOV_FS .. t
			if SpecovRead(probeOut, t) == probeVal and t:sub(-#path) == path then
				result[tf] = { id = true }
			else
				result[tf] = { byValue = {} }
			end
		end
		-- Non-identity targets: run each stored value through the converter.
		for v in pairs(samples[fkey] or {}) do
			local out
			for tf, info in pairs(result) do
				if info.byValue then
					out = out or With(v ~= SPECOV_NIL and v or nil) or false
					local cv = out and SpecovRead(out, tf:match("^[^\31]+\31(.*)$")) or nil
					if type(cv) == "table" then
						cv = nil
					end
					info.byValue[v] = (cv == nil) and SPECOV_NIL or cv
				end
			end
		end
		maps[fkey] = result
		return result
	end

	local unmapped, unmappedSeen = {}, {}
	local droppedSpecs = false
	local function MapStore(store, specKeyed)
		local out = {}
		for _, e in ipairs(store or {}) do
			local vals = type(e) == "table" and e.values
			if type(vals) == "table" and type(vals.default) == "table" then
				local ne = {}
				for k, v in pairs(e) do
					if k ~= "values" then
						ne[k] = DeepCopy(v)
					end
				end
				ne.values = {}
				for k, m in pairs(vals) do
					local key = tonumber(k) or k
					local keep = type(m) == "table"
					if keep and specKeyed and key ~= "default" and not MISTS_SPECS[key] then
						keep = false
						droppedSpecs = true
					end
					if keep then
						local nm = {}
						for fkey, v in pairs(m) do
							local mp = type(fkey) == "string" and type(v) ~= "table" and MapFKey(fkey)
							if mp then
								for tf, info in pairs(mp) do
									if info.id then
										nm[tf] = v
									else
										nm[tf] = info.byValue[v]
									end
								end
							elseif not unmappedSeen[fkey] then
								unmappedSeen[fkey] = true
								unmapped[#unmapped + 1] = tostring(e.label or e.slotLabel or fkey)
							end
						end
						if next(nm) then
							ne.values[key] = nm
						end
					end
				end
				if type(ne.values.default) == "table" and next(ne.values.default) then
					-- Keep only per-spec maps for settings the default knows.
					for k, m in pairs(ne.values) do
						if k ~= "default" then
							for tf in pairs(m) do
								if ne.values.default[tf] == nil then
									m[tf] = nil
								end
							end
							if not next(m) then
								ne.values[k] = nil
							end
						end
					end
					out[#out + 1] = ne
				end
			end
		end
		return out
	end

	local ov = {}
	ov.specOverrides = MapStore(specStore, true)
	ov.condOverrides = MapStore(condStore, false)
	ov.specOverrideGroups = {}
	for _, g in ipairs(specGroupsIn) do
		if type(g) == "table" then
			local ng = DeepCopy(g)
			ng.specs = {}
			for _, sid in ipairs(type(g.specs) == "table" and g.specs or {}) do
				sid = tonumber(sid)
				if sid and MISTS_SPECS[sid] then
					ng.specs[#ng.specs + 1] = sid
				elseif sid then
					droppedSpecs = true
				end
			end
			ov.specOverrideGroups[#ov.specOverrideGroups + 1] = ng
		end
	end
	ov.condOverrideGroups = {}
	local droppedConds = false
	for _, g in ipairs(condGroupsIn) do
		if type(g) == "table" then
			local ng = DeepCopy(g)
			ng.conds = {}
			for c, on in pairs(type(g.conds) == "table" and g.conds or {}) do
				if DROPPED_CONDS[c] then
					droppedConds = true
				elseif on then
					ng.conds[c] = true
				end
			end
			if not ng.conds.keybind then
				ng.key, ng.keyOn = nil, nil
			end
			if type(ng.icon) == "table" and ng.icon.kind == "cond" and DROPPED_CONDS[ng.icon.key or ""] then
				ng.icon = nil
			end
			ov.condOverrideGroups[#ov.condOverrideGroups + 1] = ng
		end
	end
	ov.specOverrideNextId = tonumber(data.specOverrideNextId)
	ov.condOverrideNextId = tonumber(data.condOverrideNextId)

	local nSpec, nCond = #ov.specOverrides, #ov.condOverrides
	notes[#notes + 1] = format("Spec overrides: kept (%d spec group(s), %d setting(s); %d conditional group(s), %d setting(s)). They switch with your spec and the conditions. The module settings start with the values of your current spec.",
		#ov.specOverrideGroups, nSpec, #ov.condOverrideGroups, nCond)
	if droppedSpecs then
		notes[#notes + 1] = "Spec overrides: specs that do not exist in Mists of Pandaria (Evoker, Demon Hunter) were removed from the groups."
	end
	if droppedConds then
		notes[#notes + 1] = "Conditional overrides: the Dark Mode and Druid Form conditions do not exist here and were removed from the groups."
	end
	if #unmapped > 0 then
		table.sort(unmapped)
		local seen, list = {}, {}
		for _, l in ipairs(unmapped) do
			if not seen[l] then
				seen[l] = true
				list[#list + 1] = l
			end
		end
		notes[#notes + 1] = format("Spec overrides: %d setting(s) have no Mists of Pandaria equivalent and were left out: %s.", #unmapped, table.concat(list, ", "))
	end
	if data.specUnlockOverrides or data.condUnlockOverrides or data.specBmOverrides
		or data.specDmOverrides or data.condBmOverrides or data.condDmOverrides then
		notes[#notes + 1] = "Spec overrides: per-group Unlock Mode layouts and Buff / Debuff Manager setups are retail only and were left out."
	end
	return ov
end
R.MapOverrides = MapOverrides

local SKIPPED_NAMES = {
	EllesmereUIDragonRiding = "Dragon Riding",
}

-- data = retail exportData. Returns { addons, globals, layout }, notes.
function R.Convert(data)
	if type(data) ~= "table" then
		return nil, "Invalid import string."
	end
	local notes = {}
	local out = { addons = {} }
	-- Never change the caller's table: the steps below edit the retail data.
	data = DeepCopy(data)
	if R.Migrate then
		R.Migrate(data, data.profileName)
	end
	local okSpec, errSpec = pcall(ApplySpecOverrides, data)
	if not okSpec then
		notes[#notes + 1] = "Spec overrides could not be read (" .. tostring(errSpec) .. ")."
	end
	local addons = type(data.addons) == "table" and data.addons or {}
	local skipped = {}
	for folder, blob in pairs(addons) do
		local fn = CONVERT[folder]
		if fn and type(blob) == "table" then
			local ok, root = pcall(fn, blob, notes, data)
			if ok and type(root) == "table" then
				out.addons[folder] = root
			elseif not ok then
				local entry = ns.ProfileAddonEntry(folder)
				notes[#notes + 1] = (entry and entry.display or folder) .. ": could not be converted (" .. tostring(root) .. ")."
			end
		elseif SKIPPED_NAMES[folder] then
			skipped[#skipped + 1] = SKIPPED_NAMES[folder]
		end
	end
	local tb = ConvertTopBar(addons.NaowhUI_EUI)
	if tb then
		out.addons.EllesmereUITopBar = tb
	end
	local bs = ConvertBlizzSkin(data)
	if bs then
		out.addons.EllesmereUIBlizzardSkin = bs
	end
	out.globals = ConvertGlobals(data)
	local lost
	out.layout, lost = ConvertLayout(data.unlockLayout, notes)
	KeepPositions(out.addons, lost)
	local okOv, ov = pcall(MapOverrides, data, notes)
	if okOv then
		out.overrides = ov
	else
		notes[#notes + 1] = "Spec overrides could not be converted (" .. tostring(ov) .. "); the values of your current spec are used."
	end
	if #skipped > 0 then
		table.sort(skipped)
		notes[#notes + 1] = "Not in Mists of Pandaria, skipped: " .. table.concat(skipped, ", ") .. "."
	end
	MissingMedia(out, notes)
	notes[#notes + 1] = "Positions are taken over as saved on retail. With a different screen size or UI scale, move them in Unlock Mode."
	if next(out.addons) == nil and not out.globals then
		return nil, "This retail string has no settings for addons that exist in Mists of Pandaria."
	end
	return out, notes
end
