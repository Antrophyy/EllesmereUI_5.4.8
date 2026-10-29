if _G.EllesmereUIInterruptsLoaded then
	return
end
_G.EllesmereUIInterruptsLoaded = true

local addonName = ...
local ns = EllesmereUI

local GetTime = GetTime
local UnitName = UnitName
local UnitClass = UnitClass
local UnitGUID = UnitGUID
local UnitExists = UnitExists
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsConnected = UnitIsConnected
local UnitCreatureFamily = UnitCreatureFamily
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local GetSpellInfo = GetSpellInfo
local GetNumGroupMembers = GetNumGroupMembers
local IsInRaid = IsInRaid
local CanInspect = CanInspect
local CheckInteractDistance = CheckInteractDistance
local NotifyInspect = NotifyInspect
local ClearInspectPlayer = ClearInspectPlayer
local GetInspectSpecialization = GetInspectSpecialization
local GetTalentInfo = GetTalentInfo
local GetGlyphSocketInfo = GetGlyphSocketInfo
local format = format
local pairs = pairs
local ipairs = ipairs
local tinsert = table.insert
local tremove = table.remove
local tsort = table.sort
local wipe = table.wipe
local band = bit.band
local random = math.random

-- Old name kept: players with the old addon still share interrupt data.
local ADDON_PREFIX = "AntrophyUtilitiesInterrupts"
local BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local MAX_LINES_CAP = 30

local SORT_MODES = {
	{ key = "cooldown", text = "Cooldown" },
	{ key = "priority", text = "Spell priority" },
}
local SORT_MODE_TEXT = {}
for i = 1, #SORT_MODES do
	SORT_MODE_TEXT[SORT_MODES[i].key] = SORT_MODES[i].text
end

-- Up: the anchor is the bottom of the frame and new bars are added above.
-- Down: the anchor is the top of the frame and new bars are added below.
local GROW_DIRECTIONS = {
	{ key = "UP", text = "Up" },
	{ key = "DOWN", text = "Down" },
}

local locale = GetLocale()
local L = {
	offline = "offline",
	dead = "dead",
	testOn = "Test mode ON. Fake players are shown. Turn it off in the settings (/eui).",
	testOff = "Test mode OFF.",
}
if locale == "ruRU" then
	L.offline = "вне сети"
	L.dead = "мертв"
end

local function CreateDefaults()
	return {
		enabled = true,
		noRaid = true,
		roles = { TANK = true, DAMAGER = true, HEALER = false },
		sortMode = "cooldown",
		sortDescending = false,
		-- Base spell IDs (spellDB[i][1]) in the order of the "Spell priority" sort.
		-- Empty = default order (see NormalizeSpellPriority).
		spellPriority = {},
		point ={ "BOTTOM", "CENTER", 0, 0 },
		growDirection = "UP",
		width = 190,
		lineHeight = 18,
		maxLines = 15,
		scale = 100,
		alpha = 100,
		fontSize = 11,
		fontName = STANDARD_TEXT_FONT,
		barTexture = BAR_TEXTURE,
		useClassColorName = true,
		desaturateOnCooldown = true,
		onlyOnCooldown = false,
		showSpellName = true,
		clickThrough = false,
		hideUnavailable = false,
		colors = {
			ready = { 0.15, 0.7, 0.15 },
			active = { 0.95, 0.82, 0.2 },
			cooldown = { 0.85, 0.2, 0.2 },
			unavailable = { 0.45, 0.45, 0.45 },
			name = { 1, 1, 1 },
			spell = { 1, 1, 1 },
			time = { 1, 1, 1 },
		},
		save = {},
		specCache = {},
	}
end

local function CopyDefaults(src, dst)
	for key, value in pairs(src) do
		if type(value) == "table" then
			if type(dst[key]) ~= "table" then
				dst[key] = {}
			end
			CopyDefaults(value, dst[key])
		elseif dst[key] == nil then
			dst[key] = value
		end
	end
end

-- Real saved data is only available at ADDON_LOADED. Until then use defaults.
local db = CreateDefaults()

local addon = CreateFrame("Frame", ADDON_PREFIX .. "Frame", UIParent)
local lines = {}
local rosterUnits = {}
local rosterGUIDs = {}
local entries = {}
local visibleEntries = {}
local cdsNav = {}
local sessionFlags = {}
local sessionPets = {}
local sessionPetOwner = {}
local petSpellSeen = {}
local inspectQueue = {}
local inspectQueued = {}
local inspected = {}
local spellInfoCache = {}
local currentInspect = nil
local currentInspectStarted = 0
local playerName = nil
local nextRosterUpdate = 0
local rosterDirty = true
local refreshElapsed = 0
local inspectElapsed = 0
local testMode = false
local testElapsed = 0
local testStates = {}

local spellIsTalent = {
	[102060] = true,
}

-- Talents that are not interrupts, but replace an interrupt spell.
-- Asphyxiate (108194) is a stun and replaces Strangulate, so a DK with it has no Strangulate.
local talentMarkerSpells = {
	[108194] = true,
}

local spellTalentsList = {
	WARRIOR = { [9] = 102060 },
	DEATHKNIGHT = { [9] = 108194 },
}

local spellGlyphsList = {
	ROGUE = { [56805] = true },
	DEATHKNIGHT = { [58686] = true },
	SHAMAN = { [55451] = true },
	MAGE = { [115703] = true },
	DRUID = { [116216] = true },
}

local spellCdByTalentFix = {
	[1766] = { 56805, -2 },
	[47528] = { 58686, -1 },
	[57994] = { 55451, 3 },
	[2139] = { 115703, 4 },
	[106839] = { 116216, 5 },
}

local spellTalentReplaceOther = {
	[47476] = 108194,
}

local spellSharingCD = {
	[102060] = { [6552] = 15 },
	[6552] = { [102060] = 15 },
}

-- Role of each spec that is not a damage dealer. All other specs are DAMAGER.
local specRoles = {
	[65] = "HEALER",  -- Holy Paladin
	[105] = "HEALER", -- Restoration Druid
	[256] = "HEALER", -- Discipline Priest
	[257] = "HEALER", -- Holy Priest
	[264] = "HEALER", -- Restoration Shaman
	[270] = "HEALER", -- Mistweaver Monk
	[66] = "TANK",    -- Protection Paladin
	[73] = "TANK",    -- Protection Warrior
	[104] = "TANK",   -- Guardian Druid
	[250] = "TANK",   -- Blood Death Knight
	[268] = "TANK",   -- Brewmaster Monk
}

local ROLES = {
	{ key = "TANK", text = "Tank" },
	{ key = "DAMAGER", text = "Damage" },
	{ key = "HEALER", text = "Healer" },
}

local specInDBase = {
	[253] = 4, [254] = 5, [255] = 6,
	[71] = 4, [72] = 5, [73] = 6,
	[65] = 4, [66] = 5, [70] = 6,
	[62] = 4, [63] = 5, [64] = 6,
	[256] = 4, [257] = 5, [258] = 6,
	[265] = 4, [266] = 5, [267] = 6,
	[250] = 4, [251] = 5, [252] = 6,
	[259] = 4, [260] = 5, [261] = 6,
	[102] = 4, [103] = 5, [104] = 6, [105] = 7,
	[268] = 4, [269] = 5, [270] = 6,
	[262] = 4, [263] = 5, [264] = 6,
	[0] = 3,
}

local findSpecSpells = {
	[20473] = 65, [85222] = 65, [53563] = 65, [31842] = 65, [82327] = 65, [2812] = 65,
	[31935] = 66, [26573] = 66, [53600] = 66, [98057] = 66, [119072] = 66,
	[53385] = 70, [879] = 70, [84963] = 70, [138165] = 70,
	[19574] = 253, [34026] = 253,
	[34490] = 254, [53209] = 254, [19434] = 254,
	[3674] = 255, [53301] = 255,
	[62618] = 256, [47666] = 256, [89485] = 256, [109964] = 256, [47750] = 256, [81700] = 256,
	[64843] = 257, [126135] = 257, [88685] = 257, [47788] = 257, [34861] = 257, [64844] = 257,
	[34914] = 258, [129197] = 258, [8092] = 258, [15473] = 258, [2944] = 258, [15407] = 258,
	[55233] = 250, [55050] = 250, [56222] = 250, [114866] = 250, [49222] = 250, [48982] = 250, [56815] = 250,
	[49143] = 251, [51271] = 251, [130735] = 251, [49184] = 251, [49020] = 251,
	[49016] = 252, [130736] = 252, [55090] = 252, [49206] = 252, [85948] = 252,
	[51505] = 262, [61882] = 262, [51490] = 262,
	[17364] = 263, [60103] = 263, [51533] = 263,
	[77472] = 264, [974] = 264, [77130] = 264, [98008] = 264, [61295] = 264,
	[115308] = 268, [121253] = 268, [119582] = 268,
	[113656] = 269, [122470] = 269, [117418] = 269, [107428] = 269, [116740] = 269,
	[115151] = 270, [115313] = 270, [116680] = 270, [115175] = 270, [116849] = 270, [116670] = 270,
	[78674] = 102, [93402] = 102, [2912] = 102, [24858] = 102, [48505] = 102,
	[5217] = 103, [5221] = 103,
	[5229] = 104, [62606] = 104,
	[48438] = 105, [102342] = 105, [18562] = 105, [33763] = 105, [50464] = 105,
}

local petFamilies = {
	Ghoul = locale == "ruRU" and "Вурдалак" or "Ghoul",
	Gorilla = locale == "ruRU" and "Горилла" or "Gorilla",
	["Nether Ray"] = locale == "ruRU" and "Скат Пустоты" or "Nether Ray",
	Felhunter = locale == "ruRU" and "Охотник Скверны" or "Felhunter",
	Observer = locale == "ruRU" and "Наблюдатель" or "Observer",
}

local spellDB = {
	{6552,   "WARRIOR",      {6552, 15, 0}},
	{102060, "WARRIOR",      {102060, 40, 0}},
	{96231,  "PALADIN",      {96231, 15, 0}},
	{147362, "HUNTER",       {147362, 24, 0}, nil, {34490, 24, 0}, nil},
	{1766,   "ROGUE",        {1766, 15, 0}},
	{15487,  "PRIEST",       nil, nil, nil, {15487, 45, 0}},
	{47528,  "DEATHKNIGHT",  {47528, 15, 0}},
	{47476,  "DEATHKNIGHT",  {47476, 60, 0}},
	{57994,  "SHAMAN",       {57994, 12, 0}},
	{2139,   "MAGE",         {2139, 24, 0}},
	{116705, "MONK",         {116705, 15, 0}},
	{106839, "DRUID",        nil, nil, {106839, 15, 0}, {106839, 15, 0}},
	{19647,  "WARLOCK",      {19647, 24, 0}, nil, nil, nil, nil, pet = petFamilies.Felhunter},
	{26090,  "HUNTER",       {26090, 30, 0}, nil, nil, nil, nil, pet = petFamilies.Gorilla},
	{91802,  "DEATHKNIGHT",  {91802, 30, 0}, nil, nil, nil, nil, pet = petFamilies.Ghoul},
	{115781, "WARLOCK",      {115781, 24, 0}, nil, nil, nil, nil, pet = petFamilies.Observer},
	{50479,  "HUNTER",       {50479, 40, 0}, nil, nil, nil, nil, pet = petFamilies["Nether Ray"]},
	{78675,  "DRUID",        nil, {78675, 60, 8}},
}

-- Fake players for test mode: name, class, specID, pet interrupt spells they "have"
local testRoster = {
	{ "Warrior", "WARRIOR", 71 },
	{ "Rogue", "ROGUE", 259 },
	{ "Mage", "MAGE", 63 },
	{ "Deathknight", "DEATHKNIGHT", 250 },
	{ "Shaman", "SHAMAN", 263 },
	{ "Boomkin", "DRUID", 102 },
	{ "Feral", "DRUID", 103 },
	{ "Shadow", "PRIEST", 258 },
	{ "Hunter", "HUNTER", 253, pets = { [26090] = true } },
	{ "Warlock", "WARLOCK", 265, pets = { [19647] = true } },
	{ "Monk", "MONK", 269 },
	{ "Paladin", "PALADIN", 66 },
	{ "HolyPaladin", "PALADIN", 65 },
	{ "RestoShaman", "SHAMAN", 264 },
	{ "Mistweaver", "MONK", 270 },
}

local trackedSpellIDs = {}
for i = 1, #spellDB do
	for specIndex = 3, 7 do
		if spellDB[i][specIndex] then
			trackedSpellIDs[spellDB[i][specIndex][1]] = true
		end
	end
end

-- Base cooldown of a spellDB row: the first spec that has the spell.
local function BaseCooldown(spellData)
	for specIndex = 3, 7 do
		if spellData[specIndex] then
			return spellData[specIndex][2]
		end
	end
	return 0
end

-- Default priority: shortest base cooldown first (Kick before Silence),
-- same cooldown in spellDB order. Pet spells after the player's own spells.
local DEFAULT_PRIORITY = {}
do
	local rows = {}
	for i = 1, #spellDB do
		rows[i] = { id = spellDB[i][1], pet = spellDB[i].pet and 1 or 0, cd = BaseCooldown(spellDB[i]), index = i }
	end
	tsort(rows, function(a, b)
		if a.pet ~= b.pet then
			return a.pet < b.pet
		end
		if a.cd ~= b.cd then
			return a.cd < b.cd
		end
		return a.index < b.index
	end)
	for i = 1, #rows do
		DEFAULT_PRIORITY[i] = rows[i].id
	end
end

local spellDBByID = {}
for i = 1, #spellDB do
	spellDBByID[spellDB[i][1]] = spellDB[i]
end

-- spellID -> place in the priority list (1 = first).
local priorityRank = {}

local function Print(msg)
	ns.Print(msg)
end

local function UnitFullName(unit)
	if not unit or not UnitExists(unit) then
		return nil
	end
	if GetUnitName then
		local fullName = GetUnitName(unit, true)
		if fullName and fullName ~= "" and fullName ~= UNKNOWNOBJECT then
			return fullName
		end
	end
	local name, realm = UnitName(unit)
	if not name or name == UNKNOWNOBJECT then
		return nil
	end
	if realm and realm ~= "" then
		return name .. "-" .. realm
	end
	return name
end

local function ShortName(name)
	if not name then
		return "?"
	end
	return (name:gsub("%-.*$", ""))
end

local function GetFlags(name)
	sessionFlags[name] = sessionFlags[name] or {}
	return sessionFlags[name]
end

local function GetSpellVisual(spellID)
	local info = spellInfoCache[spellID]
	if info then
		return info[1], info[2]
	end
	local name, _, icon = GetSpellInfo(spellID)
	info = { name or tostring(spellID), icon or "Interface\\Icons\\INV_Misc_QuestionMark" }
	spellInfoCache[spellID] = info
	return info[1], info[2]
end

local function ApplyPosition()
	-- While Unlock Mode is open its mover owns the spot; an unlock anchor after.
	if ns._unlockActive and addon:GetNumPoints() > 0 then
		return
	end
	addon:ClearAllPoints()
	addon:SetPoint(db.point[1], UIParent, db.point[2], db.point[3], db.point[4])
	if not ns._unlockActive and ns.IsUnlockAnchored and ns.IsUnlockAnchored("EUI_InterruptTracker") and ns.ReapplyOwnAnchor then
		ns.ReapplyOwnAnchor("EUI_InterruptTracker")
	end
end

local function GrowsUp()
	return db.growDirection ~= "DOWN"
end

-- Frame point the bars grow from: BOTTOM when growing up, TOP when growing down.
local function AnchorPoint()
	return GrowsUp() and "BOTTOM" or "TOP"
end

-- The position is stored as the anchor (bottom or top center) of the frame,
-- measured from the screen center, in the frame's own scale.
local function SavePosition()
	local cx = addon:GetCenter()
	local edge = GrowsUp() and addon:GetBottom() or addon:GetTop()
	local pcx, pcy = UIParent:GetCenter()
	if not cx or not edge or not pcx then
		return false
	end
	local ratio = UIParent:GetEffectiveScale() / addon:GetEffectiveScale()
	db.point = { AnchorPoint(), "CENTER", math.floor(cx - pcx * ratio + 0.5), math.floor(edge - pcy * ratio + 0.5) }
	ApplyPosition()
	return true
end

local function IsPositionNormalized()
	return db.point[1] == AnchorPoint() and db.point[2] == "CENTER"
end

local function ValidSortMode(mode)
	return SORT_MODE_TEXT[mode] ~= nil
end

-- Keeps db.spellPriority a full list: unknown or double IDs are dropped,
-- tracked spells that are missing (empty list, new in an update) are added
-- at the end in default order.
local function NormalizeSpellPriority()
	local saved = type(db.spellPriority) == "table" and db.spellPriority or {}
	local list, seen = {}, {}
	for i = 1, #saved do
		local id = tonumber(saved[i])
		if id and spellDBByID[id] and not seen[id] then
			list[#list + 1] = id
			seen[id] = true
		end
	end
	for i = 1, #DEFAULT_PRIORITY do
		local id = DEFAULT_PRIORITY[i]
		if not seen[id] then
			list[#list + 1] = id
			seen[id] = true
		end
	end
	db.spellPriority = list
	wipe(priorityRank)
	for i = 1, #list do
		priorityRank[list[i]] = i
	end
end

local function ClampSettings()
	db.width = math.min(320, math.max(120, tonumber(db.width) or 190))
	db.lineHeight = math.min(28, math.max(14, tonumber(db.lineHeight) or 18))
	db.maxLines = math.min(MAX_LINES_CAP, math.max(5, tonumber(db.maxLines) or 15))
	db.scale = math.min(180, math.max(60, tonumber(db.scale) or 100))
	db.alpha = math.min(100, math.max(20, tonumber(db.alpha) or 100))
	db.fontSize = math.min(16, math.max(8, tonumber(db.fontSize) or 11))
	if not ValidSortMode(db.sortMode) then
		db.sortMode = "cooldown"
	end
	NormalizeSpellPriority()
	if db.growDirection ~= "UP" and db.growDirection ~= "DOWN" then
		db.growDirection = "UP"
	end
	if type(db.point) ~= "table" or type(db.point[1]) ~= "string" or type(db.point[2]) ~= "string"
		or type(db.point[3]) ~= "number" or type(db.point[4]) ~= "number" then
		db.point = { AnchorPoint(), "CENTER", 0, 0 }
	end
end

local function GetBarTexturePath()
	if type(db.barTexture) == "string" and db.barTexture ~= "" then
		return db.barTexture
	end
	return BAR_TEXTURE
end

local function GetFontPath()
	if type(db.fontName) == "string" and db.fontName ~= "" then
		return db.fontName
	end
	return STANDARD_TEXT_FONT
end

local function EnsureColorDefaults()
	local defaults = CreateDefaults().colors
	if type(db.colors) ~= "table" then
		db.colors = {}
	end
	for key, value in pairs(defaults) do
		local c = db.colors[key]
		if type(c) ~= "table" or type(c[1]) ~= "number" or type(c[2]) ~= "number" or type(c[3]) ~= "number" then
			db.colors[key] = value
		end
	end
end

local function SetFontSafe(fontString, path, size)
	fontString:SetFont(path, size, "OUTLINE")
	if not fontString:GetFont() then
		fontString:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
	end
end

local function ApplyLineVisualSettings(line)
	line.bar:SetTexture(GetBarTexturePath())
	if not line.bar:GetTexture() then
		line.bar:SetTexture(BAR_TEXTURE)
	end
	line.barBg:SetTexture(line.bar:GetTexture())
	local fontPath = GetFontPath()
	SetFontSafe(line.leftText, fontPath, db.fontSize)
	SetFontSafe(line.centerText, fontPath, db.fontSize)
	SetFontSafe(line.rightText, fontPath, db.fontSize)
end

local shownLines = 0

local MOVER_EMPTY_LINES = 3

-- True only while Unlock Mode (settings sidebar) is open.
local unlocked = false

-- The order is always the same: the first bar is on top. Growing down, the top
-- bar stays at the anchor. Growing up, the last shown bar stays at the anchor
-- (bottom), so the list grows upward when more bars are shown.
local function PositionLines()
	local lineHeight = db.lineHeight
	local growsUp = GrowsUp()
	for i = 1, MAX_LINES_CAP do
		local line = lines[i]
		if line then
			line:ClearAllPoints()
			if growsUp then
				line:SetPoint("BOTTOMLEFT", addon, "BOTTOMLEFT", 0, (shownLines - i) * lineHeight)
			else
				line:SetPoint("TOPLEFT", addon, "TOPLEFT", 0, -((i - 1) * lineHeight))
			end
		end
	end
end

-- Normal: no background and no mouse area on the frame itself, so an empty
-- frame is fully invisible. Unlock Mode: a move box with a border and a label is
-- shown (also when there are no bars), so the frame can always be found and dragged.
local function ApplyLockState()
	addon:EnableMouse(unlocked)
	addon:SetMovable(unlocked)
	PositionLines()
	-- Click through: bars ignore the mouse (no tooltips). Not while unlocked,
	-- because then the bars must be draggable.
	for i = 1, MAX_LINES_CAP do
		if lines[i] then
			lines[i]:EnableMouse(unlocked or not db.clickThrough)
		end
	end
	local boxLines = shownLines
	if unlocked and boxLines == 0 then
		boxLines = MOVER_EMPTY_LINES
	end
	-- The move box starts at the anchor, like the bars.
	local edge = AnchorPoint()
	addon.bg:ClearAllPoints()
	addon.bg:SetPoint(edge .. "LEFT", addon, edge .. "LEFT", 0, 0)
	addon.bg:SetPoint(edge .. "RIGHT", addon, edge .. "RIGHT", 0, 0)
	addon.bg:SetHeight(math.max(1, boxLines * db.lineHeight))
	addon.bg:SetAlpha(unlocked and 0.35 or 0)
	addon.mover:SetShown(unlocked)
end

local function LayoutFrame()
	ClampSettings()
	EnsureColorDefaults()
	local width = db.width
	local lineHeight = db.lineHeight
	addon:SetScale(db.scale / 100)
	addon:SetAlpha(db.alpha / 100)
	addon:SetSize(width, db.maxLines * lineHeight)
	for i = 1, MAX_LINES_CAP do
		local line = lines[i]
		line:SetSize(width, lineHeight - 1)
		line.iconFrame:ClearAllPoints()
		line.iconFrame:SetSize(lineHeight - 2, lineHeight - 2)
		line.iconFrame:SetPoint("LEFT", line, "LEFT", 1, 0)
		line.bar:ClearAllPoints()
		line.bar:SetPoint("TOPLEFT", line, "TOPLEFT", lineHeight, -1)
		line.bar:SetPoint("BOTTOMLEFT", line, "BOTTOMLEFT", lineHeight, 1)
		line.bar:SetWidth(width - lineHeight)
		line.barBg:ClearAllPoints()
		line.barBg:SetPoint("TOPLEFT", line, "TOPLEFT", lineHeight, -1)
		line.barBg:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", 0, 1)
		line.leftText:ClearAllPoints()
		line.leftText:SetPoint("LEFT", line, "LEFT", lineHeight + 4, 0)
		if db.showSpellName then
			line.leftText:SetWidth(math.floor(width * 0.35))
		else
			-- No spell name: the player name can use the free space.
			line.leftText:SetWidth(width - lineHeight - 4 - 48)
		end
		line.centerText:ClearAllPoints()
		line.centerText:SetPoint("LEFT", line.leftText, "RIGHT", 2, 0)
		line.centerText:SetPoint("RIGHT", line, "RIGHT", -46, 0)
		line.rightText:ClearAllPoints()
		line.rightText:SetPoint("RIGHT", line, "RIGHT", -4, 0)
		line.rightText:SetWidth(44)
		ApplyLineVisualSettings(line)
		if i > db.maxLines then
			line:Hide()
		end
	end
end

local function QueueInspect(unit)
	local name = UnitFullName(unit)
	if not name or name == playerName or inspected[name] or inspectQueued[name] then
		return
	end
	inspectQueued[name] = true
	tinsert(inspectQueue, { unit = unit, name = name })
end

local function RefreshInspectQueue()
	wipe(inspectQueue)
	wipe(inspectQueued)
	for name, unit in pairs(rosterUnits) do
		if name ~= playerName and not inspected[name] then
			QueueInspect(unit)
		end
	end
end

local function CollectTalentAndGlyphInfo(name, class, unit, specID, isInspect)
	local flags = GetFlags(name)
	wipe(flags)

	local inspectArg = isInspect and true or nil
	local talentGroup = GetActiveSpecGroup and GetActiveSpecGroup(inspectArg) or nil

	if class and spellTalentsList[class] then
		local classID = select(3, UnitClass(unit))
		for talentIndex, mappedSpell in pairs(spellTalentsList[class]) do
			local selected
			if isInspect then
				selected = select(5, GetTalentInfo(talentIndex, true, talentGroup, unit, classID))
			else
				selected = select(5, GetTalentInfo(talentIndex))
			end
			if selected then
				flags[mappedSpell] = true
			end
		end
	end

	if class and spellGlyphsList[class] then
		for glyphIndex = 1, 6 do
			local glyphSpellID
			if isInspect then
				glyphSpellID = select(4, GetGlyphSocketInfo(glyphIndex, talentGroup, true, unit))
			else
				glyphSpellID = select(4, GetGlyphSocketInfo(glyphIndex))
			end
			if glyphSpellID and spellGlyphsList[class][glyphSpellID] then
				flags[glyphSpellID] = true
			end
		end
	end

	if specID and specID > 0 then
		db.specCache[name] = specID
	end
end

local function UpdateSelfInfo()
	local name = UnitFullName("player")
	if not name then
		return
	end
	playerName = name
	local _, class = UnitClass("player")
	local specID = db.specCache[name] or 0
	if GetSpecialization and GetSpecializationInfo then
		local specIndex = GetSpecialization()
		if specIndex then
			specID = GetSpecializationInfo(specIndex) or specID
		end
	end
	CollectTalentAndGlyphInfo(name, class, "player", specID, false)
	inspected[name] = true
end

local function ProcessInspectQueue()
	if not db.enabled or testMode or InCombatLockdown() then
		return
	end
	if InspectFrame and InspectFrame:IsShown() then
		return
	end
	if currentInspect then
		return
	end
	local i = 1
	while i <= #inspectQueue do
		local data = inspectQueue[i]
		if UnitExists(data.unit) and UnitFullName(data.unit) == data.name then
			if CanInspect(data.unit) and CheckInteractDistance(data.unit, 1) then
				currentInspect = {
					unit = data.unit,
					name = data.name,
					guid = UnitGUID(data.unit),
				}
				currentInspectStarted = GetTime()
				tremove(inspectQueue, i)
				inspectQueued[data.name] = nil
				NotifyInspect(data.unit)
				return
			end
			i = i + 1
		else
			-- Unit token no longer points to this player.
			inspectQueued[data.name] = nil
			tremove(inspectQueue, i)
		end
	end
end

local function GetGroupUnits()
	local unitList = {}
	local count = GetNumGroupMembers() or 0
	if IsInRaid() then
		for i = 1, count do
			unitList[#unitList + 1] = "raid" .. i
		end
	elseif count > 0 then
		unitList[#unitList + 1] = "player"
		for i = 1, count - 1 do
			unitList[#unitList + 1] = "party" .. i
		end
	elseif db.noRaid then
		unitList[#unitList + 1] = "player"
	end
	return unitList
end

local function GetPetUnit(unit)
	if unit == "player" then
		return "pet"
	end
	return unit .. "pet"
end

local function RebuildCdsNav()
	wipe(cdsNav)
	for i = 1, #entries do
		local entry = entries[i]
		cdsNav[entry.name] = cdsNav[entry.name] or {}
		for specIndex = 3, 7 do
			if entry.spell[specIndex] then
				cdsNav[entry.name][entry.spell[specIndex][1]] = i
			end
		end
	end
end

local function CreateEntry(unit, name, class, spellData, fake)
	local baseID = spellData[1]
	local saveKey = name .. ":" .. tostring(baseID)
	local lastUse, cooldown, duration = 0, 0, 0
	if not fake then
		local saved = db.save[saveKey]
		local now = GetTime()
		-- GetTime() restarts after a PC reboot, so reject times from the "future".
		if type(saved) == "table" and type(saved[1]) == "number" and type(saved[2]) == "number"
			and saved[1] <= now and (saved[1] + saved[2] - now) > 0 then
			lastUse = saved[1]
			cooldown = saved[2]
			duration = tonumber(saved[3]) or 0
		else
			db.save[saveKey] = nil
		end
	end
	local entry = {
		unit = unit,
		name = name,
		class = class,
		spell = spellData,
		saveKey = saveKey,
		lastUse = lastUse,
		cooldown = cooldown,
		duration = duration,
	}
	entries[#entries + 1] = entry
	return entry
end

local function UpdatePetForUnit(unit)
	local ownerName = UnitFullName(unit)
	if not ownerName then
		return
	end
	local petUnit = GetPetUnit(unit)
	local family = UnitCreatureFamily(petUnit)
	if sessionPets[ownerName] ~= family then
		petSpellSeen[ownerName] = nil
	end
	sessionPets[ownerName] = family
	local petGUID = UnitGUID(petUnit)
	if petGUID then
		sessionPetOwner[petGUID] = ownerName
	end
end

local function ScheduleRosterUpdate(delay)
	delay = delay or 0
	local when = GetTime() + delay
	if nextRosterUpdate == 0 or when < nextRosterUpdate then
		nextRosterUpdate = when
	end
	rosterDirty = true
end

local function GetSpecRole(specID)
	return specRoles[specID] or "DAMAGER"
end

-- Role from the known spec. If the spec is not known yet, use the group role;
-- with no group role either, count the player as damage.
local function GetPlayerRole(name, unit, specID)
	specID = specID or db.specCache[name] or 0
	if specID > 0 then
		return GetSpecRole(specID)
	end
	if unit and UnitGroupRolesAssigned then
		local role = UnitGroupRolesAssigned(unit)
		if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
			return role
		end
	end
	return "DAMAGER"
end

local function IsRoleShown(role)
	return db.roles[role] and true or false
end

local function BuildTestEntries()
	local now = GetTime()
	for i = 1, #testRoster do
		local data = testRoster[i]
		local name, class, specID = data[1], data[2], data[3]
		if IsRoleShown(GetSpecRole(specID)) then
			testStates[name] = testStates[name] or { dead = false, offline = false }
			for spellIndex = 1, #spellDB do
				local spellData = spellDB[spellIndex]
				if spellData[2] == class and (not spellData.pet or (data.pets and data.pets[spellData[1]])) then
					local entry = CreateEntry("player", name, class, spellData, true)
					entry.fake = true
					entry.fakeSpec = specID
					-- Start some bars in the middle of a cooldown so all states are visible.
					if random() < 0.4 then
						local actual = spellData[specInDBase[specID] or 3] or spellData[3]
						if actual then
							entry.cooldown = actual[2]
							entry.lastUse = now - random() * actual[2]
						end
					end
				end
			end
		end
	end
	if testStates.Shadow then
		testStates.Shadow.dead = true
	end
	if testStates.Mage then
		testStates.Mage.offline = true
	end
end

local function UpdateRoster()
	if not rosterDirty then
		return
	end
	rosterDirty = false
	nextRosterUpdate = 0
	wipe(entries)
	wipe(rosterUnits)
	wipe(rosterGUIDs)

	UpdateSelfInfo()

	local groupUnits = GetGroupUnits()
	for i = 1, #groupUnits do
		local unit = groupUnits[i]
		local name = UnitFullName(unit)
		local _, class = UnitClass(unit)
		if name and class then
			rosterUnits[name] = unit
			local guid = UnitGUID(unit)
			if guid then
				rosterGUIDs[guid] = name
			end
			if not testMode and IsRoleShown(GetPlayerRole(name, unit)) then
				for spellIndex = 1, #spellDB do
					local spellData = spellDB[spellIndex]
					if spellData[2] == class then
						CreateEntry(unit, name, class, spellData)
					end
				end
			end
			UpdatePetForUnit(unit)
		end
	end

	if testMode then
		BuildTestEntries()
	end

	RebuildCdsNav()
	RefreshInspectQueue()
end

local function ApplyCooldownModifiers(entry, actualSpell)
	local cd = actualSpell[2]
	local duration = actualSpell[3] or 0
	local flags = GetFlags(entry.name)
	local fix = spellCdByTalentFix[actualSpell[1]]
	if fix then
		for i = 1, #fix, 2 do
			if flags[fix[i]] then
				cd = cd + fix[i + 1]
			end
		end
	end
	return cd, duration
end

local function GetActualSpellData(entry)
	local specID = entry.fakeSpec or db.specCache[entry.name] or 0
	local specIndex = specInDBase[specID] or 3
	local spellData = entry.spell
	local actualSpell = spellData[specIndex] or spellData[3]
	if not actualSpell then
		return nil
	end
	local flags = GetFlags(entry.name)
	if spellIsTalent[spellData[1]] and not flags[spellData[1]] then
		return nil
	end
	local replacementTalent = spellTalentReplaceOther[spellData[1]]
	if replacementTalent and flags[replacementTalent] then
		return nil
	end
	if spellData.pet and not entry.fake then
		local hasPet = sessionPets[entry.name] == spellData.pet
			or (petSpellSeen[entry.name] and petSpellSeen[entry.name][spellData[1]])
		if not hasPet and entry.name == playerName and IsSpellKnown then
			hasPet = IsSpellKnown(spellData[1], true)
		end
		local timeLeft = (entry.lastUse or 0) + (entry.cooldown or 0) - GetTime()
		if not hasPet and timeLeft <= 0 then
			return nil
		end
	end
	return actualSpell, specID
end

local function SaveEntry(entry)
	if not entry.fake then
		db.save[entry.saveKey] = { entry.lastUse, entry.cooldown, entry.duration }
	end
end

local function StartCooldown(entry)
	if not entry then
		return
	end
	local actualSpell = GetActualSpellData(entry)
	if not actualSpell then
		return
	end
	local cd, duration = ApplyCooldownModifiers(entry, actualSpell)
	entry.cooldown = cd
	entry.duration = duration
	entry.lastUse = GetTime()
	SaveEntry(entry)

	local shared = spellSharingCD[actualSpell[1]]
	local nav = cdsNav[entry.name]
	if shared and nav then
		for otherSpellID, otherCd in pairs(shared) do
			local other = entries[nav[otherSpellID] or 0]
			if other and other ~= entry then
				other.cooldown = otherCd
				other.duration = 0
				other.lastUse = entry.lastUse
				SaveEntry(other)
			end
		end
	end
end

local function GetEntryAvailability(entry)
	if entry.fake then
		local state = testStates[entry.name]
		if state and state.offline then
			return "offline"
		elseif state and state.dead then
			return "dead"
		end
		return nil
	end
	if not UnitIsConnected(entry.unit) then
		return "offline"
	elseif UnitIsDeadOrGhost(entry.unit) then
		return "dead"
	end
	return nil
end

local function ComputeSortKeys(entry, now)
	local actualSpell = entry.actual
	local spellName = GetSpellVisual(actualSpell[1])
	local cdLeft = (entry.lastUse or 0) + (entry.cooldown or 0) - now
	if cdLeft < 0 then
		cdLeft = 0
	end
	-- Groups: 0 = ready, 1 = on cooldown, 2 = dead or offline.
	entry.sortGroup = entry.unavailable and 2 or (cdLeft > 0 and 1 or 0)
	if entry.sortGroup == 0 and db.sortMode == "priority" then
		-- Ready: the user's spell order (Settings > Sorting).
		entry.sortKey = priorityRank[entry.spell[1]] or 999
	elseif entry.sortGroup == 0 then
		-- Ready: the interrupt with the shortest total cooldown first (Kick before Silence).
		entry.sortKey = ApplyCooldownModifiers(entry, actualSpell)
	else
		-- On cooldown: the one with the least time left first (2 s left above 4 s left).
		entry.sortKey = cdLeft
	end
	entry.sortTie = ShortName(entry.name):lower() .. "\001" .. spellName:lower()
end

local function SortEntries(a, b)
	if a.sortGroup ~= b.sortGroup then
		return a.sortGroup < b.sortGroup
	end
	if a.sortKey ~= b.sortKey then
		if db.sortDescending then
			return a.sortKey > b.sortKey
		end
		return a.sortKey < b.sortKey
	end
	if a.sortTie ~= b.sortTie then
		return a.sortTie < b.sortTie
	end
	return a.saveKey < b.saveKey
end

local function FormatTimeLeft(seconds)
	if seconds <= 0 then
		return ""
	elseif seconds < 10 then
		return format("%.1f", seconds)
	elseif seconds < 60 then
		return tostring(math.floor(seconds + 0.5))
	else
		return format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
	end
end

local function UpdateLine(line, entry, now)
	local actualSpell = entry.actual
	local spellID = actualSpell[1]
	local spellName, spellIcon = GetSpellVisual(spellID)
	local cd = entry.cooldown or 0
	local duration = entry.duration or 0
	local cdLeft = (entry.lastUse or 0) + cd - now
	local activeLeft = (entry.lastUse or 0) + duration - now
	local classColor = RAID_CLASS_COLORS[entry.class] or NORMAL_FONT_COLOR
	local status = "ready"
	local rightText = ""
	local color = db.colors.ready
	local barProgress = 1

	if entry.unavailable == "offline" then
		status = "offline"
		rightText = L.offline
		color = db.colors.unavailable
		barProgress = 1
	elseif entry.unavailable == "dead" then
		status = "dead"
		rightText = L.dead
		color = db.colors.unavailable
		barProgress = 1
	elseif activeLeft > 0 then
		status = "active"
		rightText = FormatTimeLeft(activeLeft)
		color = db.colors.active
		barProgress = duration > 0 and (activeLeft / duration) or 1
	elseif cdLeft > 0 then
		status = "cooldown"
		rightText = FormatTimeLeft(cdLeft)
		color = db.colors.cooldown
		barProgress = cd > 0 and (1 - (cdLeft / cd)) or 0
	end

	if barProgress < 0 then
		barProgress = 0
	elseif barProgress > 1 then
		barProgress = 1
	end

	line.entrySpellID = spellID
	line.entryName = entry.name
	line.icon:SetTexture(spellIcon)
	line.leftText:SetText(ShortName(entry.name))
	line.centerText:SetText(db.showSpellName and spellName or "")
	line.rightText:SetText(rightText)
	if db.useClassColorName then
		line.leftText:SetTextColor(classColor.r, classColor.g, classColor.b)
	else
		line.leftText:SetTextColor(db.colors.name[1], db.colors.name[2], db.colors.name[3])
	end
	line.centerText:SetTextColor(db.colors.spell[1], db.colors.spell[2], db.colors.spell[3])
	line.rightText:SetTextColor(db.colors.time[1], db.colors.time[2], db.colors.time[3])
	line.icon:SetDesaturated(db.desaturateOnCooldown and (status == "dead" or status == "offline" or status == "cooldown") and true or false)
	line.bar:SetVertexColor(color[1], color[2], color[3], 0.9)
	line.barBg:SetVertexColor(color[1], color[2], color[3], 0.25)
	-- A texture with width 0 is drawn at full size, so keep at least 1 pixel.
	-- The dim background track keeps an empty (0%) bar visible.
	local barWidth = (db.width - db.lineHeight) * barProgress
	if barWidth < 1 then
		barWidth = 1
	end
	line.bar:SetWidth(barWidth)
	line:Show()
end

local function RefreshDisplay()
	if not db.enabled and not testMode then
		if not unlocked then
			addon:Hide()
			return
		end
		-- Tracker is off, but Unlock Mode still shows the empty move box.
		addon:Show()
		for i = 1, MAX_LINES_CAP do
			lines[i]:Hide()
		end
		if shownLines ~= 0 then
			shownLines = 0
			ApplyLockState()
		end
		return
	end
	addon:Show()
	wipe(visibleEntries)
	local now = GetTime()
	for i = 1, #entries do
		local entry = entries[i]
		entry.actual = GetActualSpellData(entry)
		if entry.actual then
			local show = true
			if db.onlyOnCooldown then
				local cdLeft = (entry.lastUse or 0) + (entry.cooldown or 0) - now
				show = cdLeft > 0
			end
			if show then
				entry.unavailable = GetEntryAvailability(entry)
				if db.hideUnavailable and entry.unavailable then
					show = false
				end
			end
			if show then
				ComputeSortKeys(entry, now)
				visibleEntries[#visibleEntries + 1] = entry
			end
		end
	end
	tsort(visibleEntries, SortEntries)
	for i = 1, MAX_LINES_CAP do
		local entry = i <= db.maxLines and visibleEntries[i]
		if entry then
			UpdateLine(lines[i], entry, now)
		else
			lines[i]:Hide()
		end
	end
	local count = math.min(#visibleEntries, db.maxLines)
	if count ~= shownLines then
		shownLines = count
		ApplyLockState()
	end
end

local function UpdateTestSimulation(elapsed)
	testElapsed = testElapsed + elapsed
	if testElapsed < 0.5 then
		return
	end
	testElapsed = 0
	local now = GetTime()
	for i = 1, #entries do
		local entry = entries[i]
		if entry.fake and not GetEntryAvailability(entry) and GetActualSpellData(entry) then
			local cdLeft = (entry.lastUse or 0) + (entry.cooldown or 0) - now
			if cdLeft <= 0 and random() < 0.06 then
				StartCooldown(entry)
			end
		end
	end
	-- Sometimes a fake player dies, resurrects, disconnects or comes back.
	if random() < 0.04 then
		local data = testRoster[random(#testRoster)]
		local state = testStates[data[1]]
		if state then
			if random() < 0.75 then
				state.dead = not state.dead
			else
				state.offline = not state.offline
			end
		end
	end
end

local function CreateLine(index)
	local line = CreateFrame("Button", nil, addon)
	line:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = false,
		edgeSize = 8,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})
	line:SetBackdropColor(0, 0, 0, 0.35)
	line:SetBackdropBorderColor(0, 0, 0, 0.55)

	line.barBg = line:CreateTexture(nil, "BORDER")
	line.barBg:SetTexture(BAR_TEXTURE)

	line.bar = line:CreateTexture(nil, "ARTWORK")
	line.bar:SetTexture(BAR_TEXTURE)

	line.iconFrame = CreateFrame("Frame", nil, line)
	line.iconFrame:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
	line.iconFrame:SetBackdropColor(0, 0, 0, 0.5)
	line.icon = line.iconFrame:CreateTexture(nil, "ARTWORK")
	line.icon:SetAllPoints()

	line.leftText = line:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	line.leftText:SetJustifyH("LEFT")

	line.centerText = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	line.centerText:SetJustifyH("CENTER")

	line.rightText = line:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	line.rightText:SetJustifyH("RIGHT")

	-- Lines cover the whole frame, so they must pass dragging to the main frame.
	line:RegisterForDrag("LeftButton")
	line:SetScript("OnDragStart", function()
		if unlocked then
			addon:StartMoving()
		end
	end)
	line:SetScript("OnDragStop", function()
		addon:StopMovingOrSizing()
		SavePosition()
		if ns.RefreshSettings then
			ns.RefreshSettings()
		end
	end)
	line:SetScript("OnEnter", function(self)
		-- No tooltips in Unlock Mode: the bars are only for dragging then.
		if self.entrySpellID and not unlocked then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetSpellByID(self.entrySpellID)
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(ShortName(self.entryName), 1, 1, 1)
			GameTooltip:Show()
		end
	end)
	line:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	line:Hide()
	lines[index] = line
end

addon:SetClampedToScreen(true)
-- HIGH so it draws above the Raid Ability Timeline (MEDIUM) when the two overlap.
addon:SetFrameStrata("HIGH")
addon:SetMovable(true)
addon:EnableMouse(true)
addon:RegisterForDrag("LeftButton")
addon:SetScript("OnDragStart", function(self)
	if unlocked then
		self:StartMoving()
	end
end)
addon:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	SavePosition()
	if ns.RefreshSettings then
		ns.RefreshSettings()
	end
end)
addon.bg = addon:CreateTexture(nil, "BACKGROUND")
addon.bg:SetAllPoints()
addon.bg:SetTexture(0, 0, 0, 1)

-- Move box shown in Unlock Mode: green 1 px border around the background and a label above it.
addon.mover = CreateFrame("Frame", nil, addon)
addon.mover:SetAllPoints(addon.bg)
addon.mover:SetFrameLevel(addon:GetFrameLevel() + 20)
do
	local r, g, b = 12 / 255, 210 / 255, 157 / 255
	local function Edge(p1, p2, horizontal)
		local tex = addon.mover:CreateTexture(nil, "OVERLAY")
		tex:SetTexture(r, g, b, 0.9)
		tex:SetPoint(p1)
		tex:SetPoint(p2)
		if horizontal then
			tex:SetHeight(1)
		else
			tex:SetWidth(1)
		end
	end
	Edge("TOPLEFT", "TOPRIGHT", true)
	Edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
	Edge("TOPLEFT", "BOTTOMLEFT", false)
	Edge("TOPRIGHT", "BOTTOMRIGHT", false)
	local label = addon.mover:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("BOTTOMLEFT", addon.mover, "TOPLEFT", 0, 3)
	label:SetTextColor(r, g, b)
	label:SetText("Interrupt Tracker")
end
addon.mover:Hide()

for i = 1, MAX_LINES_CAP do
	CreateLine(i)
end

local RefreshOptionsPanel

local function SetEnabled(enabled)
	db.enabled = enabled and true or false
	if db.enabled then
		addon:Show()
		ScheduleRosterUpdate(0)
	elseif not testMode then
		addon:Hide()
	end
end

local function SetTestMode(enabled)
	testMode = enabled and true or false
	wipe(testStates)
	for i = 1, #testRoster do
		sessionFlags[testRoster[i][1]] = nil
	end
	addon:Show()
	ScheduleRosterUpdate(0)
	Print(testMode and L.testOn or L.testOff)
	if RefreshOptionsPanel then
		RefreshOptionsPanel()
	end
end

local function SetRoleShown(role, shown)
	db.roles[role] = shown and true or false
	ScheduleRosterUpdate(0)
end

local function ApplyAll()
	LayoutFrame()
	ApplyPosition()
	-- Grow Direction changed: move the anchor to the other edge, the frame box stays in place.
	if not IsPositionNormalized() then
		SavePosition()
	end
	ApplyLockState()
	RefreshDisplay()
end

local function ResetSettings()
	-- Keep data that is not a setting: cooldowns, known specs and the frame position.
	local keep = { save = db.save, specCache = db.specCache, point = db.point }
	wipe(db)
	CopyDefaults(CreateDefaults(), db)
	for key, value in pairs(keep) do
		db[key] = value
	end
	ClampSettings()
	EnsureColorDefaults()
	ApplyAll()
	ScheduleRosterUpdate(0)
end

RefreshOptionsPanel = function()
	if ns.RefreshSettings then
		ns.RefreshSettings()
	end
end

-- API for the settings window (EllesmereUIOptions, EUI_InterruptTracker_Options.lua).
ns.MAX_LINES_CAP = MAX_LINES_CAP
ns.SORT_MODES = SORT_MODES
ns.GROW_DIRECTIONS = GROW_DIRECTIONS
ns.GetInterruptDB = function() return db end
tinsert(ns.applyHooks, ApplyAll)
ns.ResetInterruptSettings = ResetSettings
ns.SetInterruptsEnabled = SetEnabled
ns.SetTestMode = SetTestMode
ns.IsTestMode = function() return testMode end
ns.SetRoleShown = SetRoleShown
ns.ROLES = ROLES
ns.ScheduleRosterUpdate = ScheduleRosterUpdate
ns.CreateInterruptDefaults = CreateDefaults
ns.GetInterruptBarTexture = GetBarTexturePath
ns.GetInterruptFont = GetFontPath

-- Spell priority list for the settings: { id, class, pet, cooldown } in order.
ns.GetInterruptSpellPriority = function()
	local out = {}
	for i = 1, #db.spellPriority do
		local data = spellDBByID[db.spellPriority[i]]
		out[i] = { id = data[1], class = data[2], pet = data.pet, cooldown = BaseCooldown(data) }
	end
	return out
end
-- Moves the spell at place `from` so it ends at place `to` (both 1-based).
ns.MoveInterruptSpellPriority = function(from, to)
	local list = db.spellPriority
	if not list[from] or to < 1 or to > #list or from == to then
		return
	end
	local id = tremove(list, from)
	tinsert(list, to, id)
	NormalizeSpellPriority()
	RefreshDisplay()
end
ns.ApplyInterruptSettings = ApplyAll
ns.ResetInterruptSpellPriority = function()
	db.spellPriority = {}
	NormalizeSpellPriority()
	RefreshDisplay()
end

-- Unlock Mode (EllesmereUI core): sample bars show while it is open; the core's
-- mover moves the frame (the frame's own dragging stays off then).
local function SetUnlocked(on)
	unlocked = on and true or false
	if not db then
		return
	end
	-- Close a bar tooltip that was open when Unlock Mode started.
	if unlocked then
		for i = 1, MAX_LINES_CAP do
			if lines[i] and GameTooltip:IsOwned(lines[i]) then
				GameTooltip:Hide()
				break
			end
		end
	end
	if not unlocked then
		-- Back on its saved grow edge (the mover left it on a corner point).
		ApplyPosition()
	end
	if not IsPositionNormalized() then
		SavePosition()
	end
	ApplyLockState()
	if unlocked then
		addon:EnableMouse(false)
		addon.mover:Hide()
		for i = 1, MAX_LINES_CAP do
			if lines[i] then lines[i]:EnableMouse(false) end
		end
	end
	RefreshDisplay()
end

-- The frame's center as an offset from the screen center, in UIParent units.
local function CenterPos()
	local cx, cy = addon:GetCenter()
	if not cx then
		return nil
	end
	local s = addon:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local uw, uh = UIParent:GetSize()
	return { point = "CENTER", relPoint = "CENTER", x = cx * s - uw / 2, y = cy * s - uh / 2 }
end

local function RegisterUnlock()
	if not ns.RegisterUnlockElements then
		return
	end
	ns:RegisterUnlockElements({
		ns.MakeUnlockElement({
			key = "EUI_InterruptTracker",
			label = "Interrupt Tracker",
			group = "Interrupt Tracker",
			order = 800,
			-- Placed by its own saved edge point (grow direction), never by the core.
			noInitHook = true,
			getFrame = function() return addon end,
			getSize = function() return addon:GetWidth(), addon:GetHeight() end,
			setWidth = function(_, w)
				db.width = math.min(320, math.max(120, math.floor(w + 0.5)))
				LayoutFrame()
				ApplyLockState()
				RefreshDisplay()
			end,
			isHidden = function() return not db or not db.enabled end,
			savePos = function(_, point, relPoint, x, y)
				if point ~= "CENTER" or (relPoint or "CENTER") ~= "CENTER" then
					SavePosition()
					return
				end
				-- Back to the frame's own scale, anchored at its grow edge.
				local s = addon:GetEffectiveScale() / UIParent:GetEffectiveScale()
				local h = addon:GetHeight()
				local fx, fy = x / s, y / s
				fy = GrowsUp() and (fy - h / 2) or (fy + h / 2)
				db.point = { AnchorPoint(), "CENTER", math.floor(fx + 0.5), math.floor(fy + 0.5) }
				if not InCombatLockdown() then
					ApplyPosition()
				end
			end,
			loadPos = CenterPos,
			clearPos = function() db.point = { AnchorPoint(), "CENTER", 0, 0 } end,
			applyPos = function() if db then ApplyPosition() end end,
		}),
	}, "EllesmereUIInterruptTracker")
	ns:RegisterUnlockModeListener("EllesmereUIInterruptTracker", SetUnlocked)
end
RegisterUnlock()

local function InitDB()
	-- Before 3.1 the settings were EllesmereUIDB.interrupts.
	db = ns.ModuleDB("EllesmereUIInterruptTrackerDB", "interrupts")
	CopyDefaults(CreateDefaults(), db)
	db.sortReadyFirst = nil -- removed option, ready interrupts are always on top now
	-- "Include healers" was replaced by the Roles multi-select.
	if db.includeHealers ~= nil then
		db.roles.HEALER = db.includeHealers and true or false
		db.includeHealers = nil
	end
	-- The frame is moved in Unlock Mode now; the old lock setting is not used.
	db.locked = nil
	db.lockDefaultV2 = nil
	ClampSettings()
	EnsureColorDefaults()
	-- Drop old and invalid saved cooldowns.
	local now = GetTime()
	for key, saved in pairs(db.save) do
		if type(saved) ~= "table" or type(saved[1]) ~= "number" or type(saved[2]) ~= "number"
			or saved[1] > now or saved[1] + saved[2] <= now then
			db.save[key] = nil
		end
	end
end

local function HandleCombatLog(...)
	local _, subEvent, _, sourceGUID, sourceName, sourceFlags, _, _, _, _, _, spellID = ...
	if subEvent ~= "SPELL_CAST_SUCCESS" or not sourceGUID then
		return
	end

	-- Only track group members and their pets (by GUID, so realm names do not matter).
	local name = rosterGUIDs[sourceGUID]
	local fromPet = false
	if not name then
		name = sessionPetOwner[sourceGUID]
		fromPet = name ~= nil
	end
	if not name then
		return
	end

	if not fromPet then
		local specID = findSpecSpells[spellID]
		if specID and band(sourceFlags or 0, COMBATLOG_OBJECT_TYPE_PLAYER) > 0 and db.specCache[name] ~= specID then
			db.specCache[name] = specID
			ScheduleRosterUpdate(0)
		end
	end

	if talentMarkerSpells[spellID] and not fromPet and not GetFlags(name)[spellID] then
		GetFlags(name)[spellID] = true
		ScheduleRosterUpdate(0)
	end

	if not trackedSpellIDs[spellID] then
		return
	end

	if spellIsTalent[spellID] and not GetFlags(name)[spellID] then
		GetFlags(name)[spellID] = true
		ScheduleRosterUpdate(0)
	end
	if fromPet then
		petSpellSeen[name] = petSpellSeen[name] or {}
		petSpellSeen[name][spellID] = true
	end

	local nav = cdsNav[name]
	local entryIndex = nav and nav[spellID]
	if entryIndex then
		StartCooldown(entries[entryIndex])
	end
end

addon:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		local loadedName = ...
		if loadedName ~= addonName then
			return
		end
		self:UnregisterEvent("ADDON_LOADED")
		InitDB()
		ApplyPosition()
		LayoutFrame()
		ApplyLockState()
		if not db.enabled then
			addon:Hide()
		end
		ScheduleRosterUpdate(0)
	elseif event == "PLAYER_LOGIN" then
		-- All addons are loaded now, so all LibSharedMedia media is registered.
		LayoutFrame()
		-- Older versions saved other anchor points: convert to the current anchor format.
		if not IsPositionNormalized() then
			SavePosition()
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		ScheduleRosterUpdate(0)
	elseif event == "PLAYER_TALENT_UPDATE" or event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "GLYPH_UPDATED" then
		UpdateSelfInfo()
		ScheduleRosterUpdate(0)
	elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" then
		ScheduleRosterUpdate(1)
	elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
		local unit = ...
		if unit and UnitExists(unit) then
			local name = UnitFullName(unit)
			if name then
				inspected[name] = nil
				if unit == "player" then
					UpdateSelfInfo()
				else
					sessionFlags[name] = nil
					QueueInspect(unit)
				end
				ScheduleRosterUpdate(0)
			end
		end
	elseif event == "UNIT_PET" then
		local unit = ...
		if unit and UnitExists(unit) then
			UpdatePetForUnit(unit)
		end
	elseif event == "INSPECT_READY" then
		local guid = ...
		if currentInspect and guid == currentInspect.guid and UnitExists(currentInspect.unit) and UnitGUID(currentInspect.unit) == guid then
			local _, class = UnitClass(currentInspect.unit)
			local specID = GetInspectSpecialization(currentInspect.unit) or 0
			CollectTalentAndGlyphInfo(currentInspect.name, class, currentInspect.unit, specID, true)
			inspected[currentInspect.name] = true
			-- Do not clear inspect data if the player opened the Blizzard inspect window meanwhile.
			if not (InspectFrame and InspectFrame:IsShown()) then
				ClearInspectPlayer()
			end
			currentInspect = nil
			currentInspectStarted = 0
			ScheduleRosterUpdate(0)
		end
	elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
		HandleCombatLog(...)
	elseif event == "PLAYER_LOGOUT" then
		SavePosition()
	end
end)

addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("PLAYER_ENTERING_WORLD")
addon:RegisterEvent("PLAYER_TALENT_UPDATE")
addon:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
addon:RegisterEvent("GLYPH_UPDATED")
addon:RegisterEvent("GROUP_ROSTER_UPDATE")
addon:RegisterEvent("PLAYER_ROLES_ASSIGNED")
addon:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
addon:RegisterEvent("UNIT_PET")
addon:RegisterEvent("INSPECT_READY")
addon:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
addon:RegisterEvent("PLAYER_LOGOUT")

addon:SetScript("OnUpdate", function(self, elapsed)
	if currentInspect and currentInspectStarted > 0 and (GetTime() - currentInspectStarted) > 5 then
		-- Inspect timed out: try this player again later.
		local unit = currentInspect.unit
		currentInspect = nil
		currentInspectStarted = 0
		QueueInspect(unit)
	end
	if nextRosterUpdate > 0 and GetTime() >= nextRosterUpdate then
		UpdateRoster()
	end
	if testMode then
		UpdateTestSimulation(elapsed)
	end
	refreshElapsed = refreshElapsed + elapsed
	if refreshElapsed >= 0.05 then
		refreshElapsed = 0
		RefreshDisplay()
	end
	inspectElapsed = inspectElapsed + elapsed
	if inspectElapsed >= 3.5 then
		inspectElapsed = 0
		ProcessInspectQueue()
	end
end)
