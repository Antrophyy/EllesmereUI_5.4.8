-------------------------------------------------------------------------------
--  EllesmereUIDataBars_Compat.lua (5.4.8 port)
--  The retail EllesmereUI DataBars files (9.3.8) run on Mists of Pandaria
--  through this file, the same way as the Bags port. It builds a private
--  environment (ns.env) that every other file of this addon uses as its global
--  table (setfenv on line 1): reads fall back to the real _G, writes go to the
--  real _G. In it, the retail APIs the bar code calls (C_Timer, C_Map, C_PvP,
--  C_CurrencyInfo, C_Spell, C_Item, C_FriendList, C_BattleNet, ...) are rebuilt
--  with the 5.4.8 API, and "EllesmereUI" is a proxy of the core table that
--  adds the retail framework pieces the bars need: Lite addon / DB, pixel
--  borders, combat queue, the Visibility checklist, mouseover reveal, Unlock
--  Mode elements, bar textures and number formatting. Nothing here is written
--  into the real globals, so other addons never see these shims.
-------------------------------------------------------------------------------
local addonName, ns = ...
local Core = EllesmereUI

local _G = _G
local type, pairs, ipairs, select, tonumber, tostring = type, pairs, ipairs, select, tonumber, tostring
local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local format = string.format
local wipe = wipe
local tinsert = table.insert

-- Filled while this file runs; the metatable (reads -> _G, writes -> _G) is
-- set at the end, so nothing below leaks into the real globals.
local env = {}
ns.env = env

local function noop() end
env.noop = noop

-------------------------------------------------------------------------------
--  Small globals the retail code expects
-------------------------------------------------------------------------------
-- 5.4.8 has no secret values.
env.issecretvalue = function() return false end
env.Clamp = function(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end
if not BreakUpLargeNumbers then
	env.BreakUpLargeNumbers = function(value)
		local s = tostring(floor((value or 0) + 0.5))
		local sign, digits = s:match("^(%-?)(%d+)$")
		if not digits then return s end
		local out = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
		if out:sub(1, 1) == "," then out = out:sub(2) end
		return sign .. out
	end
end
env.GetHaste = function() return GetMeleeHaste and GetMeleeHaste() or 0 end
-- Retail-only systems the bar code tests for (nil = not in 5.4.8).
env.C_Texture = false
env.C_ToyBox = false
env.C_WowTokenPublic = false
env.C_Bank = false
env.C_Reputation = false
env.C_GossipInfo = false
env.C_MajorFactions = false
env.C_DelvesUI = false
env.C_ClassTalents = false
env.C_Traits = false
env.C_TradeSkillUI = false
env.PlayerSpellsUtil = false
env.ChatFrameUtil = false
env.PlayerHasToy = function() return false end

-------------------------------------------------------------------------------
--  C_Timer (5.4.8 has none): After, NewTimer, NewTicker; handles :Cancel().
-------------------------------------------------------------------------------
do
	local tasks = {}
	local driver = CreateFrame("Frame")
	driver:Hide()
	local now = 0
	local Handle = {}
	Handle.__index = Handle
	function Handle:Cancel() self.cancelled = true end
	function Handle:IsCancelled() return self.cancelled == true end
	driver:SetScript("OnUpdate", function(self, elapsed)
		now = now + elapsed
		local i = 1
		while i <= #tasks do
			local t = tasks[i]
			if t.cancelled then
				table.remove(tasks, i)
			elseif t.at <= now then
				if t.interval then
					t.at = now + t.interval
					i = i + 1
				else
					table.remove(tasks, i)
				end
				local ok, err = pcall(t.fn, t)
				if not ok then geterrorhandler()(err) end
			else
				i = i + 1
			end
		end
		if #tasks == 0 then self:Hide() end
	end)
	local function Add(t)
		setmetatable(t, Handle)
		tasks[#tasks + 1] = t
		driver:Show()
		return t
	end
	env.C_Timer = {
		After = function(delay, fn) Add({ at = now + (delay or 0), fn = fn }) end,
		NewTimer = function(delay, fn) return Add({ at = now + (delay or 0), fn = fn }) end,
		NewTicker = function(interval, fn)
			interval = max(0.01, interval or 1)
			return Add({ at = now + interval, interval = interval, fn = fn })
		end,
	}
end

-------------------------------------------------------------------------------
--  Calendar and add-on lists
-------------------------------------------------------------------------------
env.C_DateAndTime = {
	GetCurrentCalendarTime = function()
		local weekday, month, day, year = CalendarGetDate()
		return { weekday = weekday, month = month, monthDay = day, year = year }
	end,
	-- 5.4.8 has no weekly reset API: the daily reset (GetQuestResetTime) moved
	-- to the region's reset day (Tuesday in the US, Wednesday elsewhere), the
	-- same rule as the Minimap port.
	GetSecondsUntilWeeklyReset = function()
		local daily = GetQuestResetTime and GetQuestResetTime()
		if not daily or daily <= 0 then return 0 end
		local resetAt = time() + daily
		local wday = tonumber(date("%w", resetAt)) or 0
		local portal = (GetCVar("portal") or ""):upper()
		local target = (portal == "US") and 2 or 3
		return daily + ((target - wday) % 7) * 86400
	end,
}

env.C_AddOns = {
	GetNumAddOns = GetNumAddOns,
	GetAddOnInfo = GetAddOnInfo,
	IsAddOnLoaded = IsAddOnLoaded,
}

-------------------------------------------------------------------------------
--  Map position and zone rules
-------------------------------------------------------------------------------
-- GetPlayerMapPosition reads the map the world map shows; it is moved to the
-- player's zone (SetMapToCurrentZone) after zone changes, and never while
-- the world map is open (that would change the player's map view).
do
	-- Re-centered after zone changes and when the world map closes (the
	-- player may have browsed another zone), never on WORLD_MAP_UPDATE: that
	-- fires from SetMapToCurrentZone itself and would loop.
	local mapDirty = true
	local watch = CreateFrame("Frame")
	for _, e in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do
		watch:RegisterEvent(e)
	end
	watch:SetScript("OnEvent", function()
		mapDirty = true
	end)
	if WorldMapFrame and WorldMapFrame.HookScript then
		WorldMapFrame:HookScript("OnHide", function() mapDirty = true end)
	end
	local function MapToPlayer()
		if WorldMapFrame and WorldMapFrame:IsShown() then return end
		if mapDirty and SetMapToCurrentZone then
			mapDirty = false
			SetMapToCurrentZone()
		end
	end
	local Pos = {}
	Pos.__index = Pos
	function Pos:GetXY() return self.x, self.y end
	env.C_Map = {
		GetBestMapForUnit = function() return 1 end,
		GetPlayerMapPosition = function()
			MapToPlayer()
			local x, y = GetPlayerMapPosition("player")
			if not x then return nil end
			return setmetatable({ x = x, y = y }, Pos)
		end,
		GetMapInfo = function() return nil end,
	}
	-- Continent of the player's zone (C_Map parent walk on retail).
	function ns.ContinentName()
		MapToPlayer()
		local c = GetCurrentMapContinent and GetCurrentMapContinent()
		if not c or c < 1 then return nil end
		local list = { GetMapContinents() }
		-- 5.4.8 returns names only (no ids): the continent index is the position.
		local name = list[c]
		if type(name) == "string" then return name end
		return nil
	end
end

env.C_PvP = {
	GetZonePVPInfo = function() return (GetZonePVPInfo()) end,
}

-------------------------------------------------------------------------------
--  Bags, items, spells
-------------------------------------------------------------------------------
env.C_Container = {
	GetContainerNumFreeSlots = GetContainerNumFreeSlots,
	GetContainerNumSlots = GetContainerNumSlots,
	GetBagName = GetBagName,
	GetItemCooldown = GetItemCooldown,
}

env.C_Item = {
	GetItemCount = GetItemCount,
	GetItemCooldown = GetItemCooldown,
	GetItemInfo = GetItemInfo,
	GetItemNameByID = function(id) return (GetItemInfo(id)) end,
}

env.C_Spell = {
	GetSpellInfo = function(id)
		local name, _, icon = GetSpellInfo(id)
		if not name then return nil end
		return { name = name, iconID = icon, spellID = id }
	end,
	GetSpellCooldown = function(id)
		local start, duration, enabled = GetSpellCooldown(id)
		if not start then return nil end
		return { startTime = start, duration = duration, isEnabled = enabled == 1 }
	end,
}

env.C_SpecializationInfo = {
	GetSpecialization = function() return GetSpecialization() end,
	GetSpecializationInfo = function(i) return GetSpecializationInfo(i) end,
}

-------------------------------------------------------------------------------
--  Currencies (5.4.8 GetCurrencyInfo / GetCurrencyListInfo return lists)
-------------------------------------------------------------------------------
do
	local scan
	local function Description(id)
		if not scan then
			scan = CreateFrame("GameTooltip", "EllesmereUIDataBarsScanTip", nil, "GameTooltipTemplate")
			scan:SetOwner(WorldFrame, "ANCHOR_NONE")
		end
		scan:ClearLines()
		if not scan.SetCurrencyByID then return nil end
		local ok = pcall(scan.SetCurrencyByID, scan, id)
		if not ok then return nil end
		local lines = {}
		for i = 2, scan:NumLines() or 0 do
			local fs = _G["EllesmereUIDataBarsScanTipTextLeft" .. i]
			local t = fs and fs:GetText()
			if t and t ~= "" and t ~= " " then lines[#lines + 1] = t end
		end
		return #lines > 0 and table.concat(lines, "\n") or nil
	end
	env.C_CurrencyInfo = {
		GetCurrencyInfo = function(id)
			local name, amount, texture, earnedThisWeek, weeklyMax, totalMax, isDiscovered, quality = GetCurrencyInfo(id)
			if not name or name == "" then return nil end
			return {
				name = name, quantity = amount or 0, iconFileID = texture,
				quantityEarnedThisWeek = earnedThisWeek, maxWeeklyQuantity = weeklyMax,
				maxQuantity = totalMax or 0, discovered = isDiscovered and true or false,
				quality = quality, description = Description(id),
				useTotalEarnedForMaxQty = false,
			}
		end,
		GetCurrencyListSize = GetCurrencyListSize,
		GetCurrencyListInfo = function(i)
			local name, isHeader, isExpanded = GetCurrencyListInfo(i)
			if not name then return nil end
			return { name = name, isHeader = isHeader and true or false, isHeaderExpanded = isExpanded and true or false }
		end,
		ExpandCurrencyList = function(i, expand) ExpandCurrencyList(i, expand and 1 or 0) end,
		GetCurrencyListLink = GetCurrencyListLink,
		GetCurrencyIDFromLink = function(link)
			return tonumber(type(link) == "string" and link:match("currency:(%d+)") or nil)
		end,
		OpenCurrencyPanel = function()
			if ToggleCharacter then ToggleCharacter("TokenFrame") end
		end,
	}
end

-------------------------------------------------------------------------------
--  Friends and guild (retail C_FriendList / C_BattleNet / C_GuildInfo tables)
-------------------------------------------------------------------------------
local CLASS_TOKEN_BY_NAME = {}
for token, name in pairs(LOCALIZED_CLASS_NAMES_MALE or {}) do CLASS_TOKEN_BY_NAME[name] = token end
for token, name in pairs(LOCALIZED_CLASS_NAMES_FEMALE or {}) do CLASS_TOKEN_BY_NAME[name] = token end

env.C_FriendList = {
	GetNumFriends = function() return (GetNumFriends()) or 0 end,
	GetNumOnlineFriends = function() return select(2, GetNumFriends()) or 0 end,
	GetFriendInfoByIndex = function(i)
		local name, level, className, area, connected, status = GetFriendInfo(i)
		if not name then return nil end
		return {
			name = name, level = level, className = className, area = area,
			connected = connected and true or false,
			afk = status == CHAT_FLAG_AFK, dnd = status == CHAT_FLAG_DND,
		}
	end,
}

env.C_BattleNet = {
	GetFriendAccountInfo = function(i)
		local presenceID, presenceName, battleTag, isBattleTagPresence, toonName, toonID, client, isOnline, _, isAFK, isDND = BNGetFriendInfo(i)
		if not presenceID then return nil end
		local ga = { isOnline = isOnline and true or false, clientProgram = client, characterName = toonName }
		if toonID and BNGetToonInfo then
			local _, tName, tClient, realmName, _, faction, _, className, _, zoneName = BNGetToonInfo(toonID)
			ga.characterName = tName or toonName
			ga.clientProgram = tClient or client
			ga.realmName = realmName
			ga.factionName = faction
			ga.areaName = zoneName
			ga.classToken = className and CLASS_TOKEN_BY_NAME[className]
		end
		local accountName = presenceName
		if (not accountName or accountName == "") and battleTag then accountName = battleTag:match("^[^#]+") end
		return { accountName = accountName, battleTag = battleTag, isAFK = isAFK, isDND = isDND, gameAccountInfo = ga }
	end,
}

env.C_GuildInfo = {
	GuildRoster = function() if GuildRoster then GuildRoster() end end,
}

env.C_PartyInfo = {
	InviteUnit = function(name) InviteUnit(name) end,
}

-------------------------------------------------------------------------------
--  Fonts and pixel borders
-------------------------------------------------------------------------------
local FONT_FALLBACK = "Fonts\\ARIALN.TTF"

local function PrimeFontShadow(fs, useShadow)
	if not (fs and fs.SetShadowOffset) then return end
	if useShadow then
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 1)
	else
		fs:SetShadowOffset(0, 0)
	end
end

local PP = {}
local function Perfect()
	local ph = (Core.PhysicalHeight and Core.PhysicalHeight()) or 1080
	return 768 / ph
end
function PP.UpdateMult()
	PP.perfect = Perfect()
	PP.mult = PP.perfect / (UIParent:GetScale() or 1)
end
PP.UpdateMult()
function PP.Size(frame, w, h) frame:SetSize(w, h or w) end
function PP.Point(obj, a1, a2, a3, a4, a5)
	if not a2 then a2 = obj:GetParent() end
	obj:SetPoint(a1, a2, a3, a4, a5)
end

local borders = setmetatable({}, { __mode = "k" })
local function SnapBorder(c, frame, size)
	local es = c:GetEffectiveScale()
	if not es or es <= 0 then return end
	local px = (PP.perfect or Perfect()) / es
	local edge = max(px, floor((size or 1) + 0.5) * px)
	c._top:ClearAllPoints()
	c._top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	c._top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
	c._top:SetHeight(edge)
	c._bottom:ClearAllPoints()
	c._bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
	c._bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	c._bottom:SetHeight(edge)
	c._left:ClearAllPoints()
	c._left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -edge)
	c._left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, edge)
	c._left:SetWidth(edge)
	c._right:ClearAllPoints()
	c._right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -edge)
	c._right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, edge)
	c._right:SetWidth(edge)
end

-- 1 px border made of 4 textures inside the frame (retail PP.CreateBorder).
-- Returns the container frame (SetAlpha / SetFrameLevel / Show / Hide).
function PP.CreateBorder(frame, r, g, b, a, size, layer, subLevel)
	local bd = borders[frame]
	if bd then return bd.container end
	local c = CreateFrame("Frame", nil, frame)
	c:SetAllPoints(frame)
	c:SetFrameLevel(frame:GetFrameLevel() + 1)
	local function T()
		local t = c:CreateTexture(nil, layer or "OVERLAY", nil, subLevel or 0)
		t:SetTexture("Interface\\Buttons\\WHITE8X8")
		t:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
		return t
	end
	c._top, c._bottom, c._left, c._right = T(), T(), T(), T()
	bd = { container = c, size = size or 1 }
	borders[frame] = bd
	SnapBorder(c, frame, bd.size)
	local ticks = 0
	c:SetScript("OnUpdate", function(self)
		ticks = ticks + 1
		SnapBorder(self, frame, bd.size)
		if ticks >= 2 then self:SetScript("OnUpdate", nil) end
	end)
	c:SetScript("OnSizeChanged", function(self) SnapBorder(self, frame, bd.size) end)
	return c
end
function PP.SetBorderColor(frame, r, g, b, a)
	local bd = borders[frame]
	if not bd then return end
	local c = bd.container
	for _, t in ipairs({ c._top, c._bottom, c._left, c._right }) do t:SetVertexColor(r, g, b, a or 1) end
end

-------------------------------------------------------------------------------
--  Accent color (EllesmereUI green unless the user picked another accent)
-------------------------------------------------------------------------------
local ACCENT = { r = 12 / 255, g = 210 / 255, b = 157 / 255 }
local function RefreshAccentColor()
	if Core.ResolveAccent then
		local r, g, b = Core.ResolveAccent()
		if r then ACCENT.r, ACCENT.g, ACCENT.b = r, g, b end
	end
end
RefreshAccentColor()
ns.accentCallbacks = {}
if Core.accentListeners then
	tinsert(Core.accentListeners, function(r, g, b)
		ACCENT.r, ACCENT.g, ACCENT.b = r, g, b
		for _, fn in ipairs(ns.accentCallbacks) do pcall(fn) end
	end)
end

-------------------------------------------------------------------------------
--  Lite addon + DB (retail EllesmereUI.Lite): OnInitialize at this addon's
--  ADDON_LOADED (SavedVariables are in), OnEnable at PLAYER_LOGIN.
-------------------------------------------------------------------------------
local function DeepCopy(v)
	if type(v) ~= "table" then return v end
	local t = {}
	for k, x in pairs(v) do t[k] = DeepCopy(x) end
	return t
end

local function DeepMergeDefaults(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			DeepMergeDefaults(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
	return dst
end

local Lite = { DeepCopy = DeepCopy, DeepMergeDefaults = DeepMergeDefaults }
function Lite.NewDB(svName, defaults)
	local root = _G[svName]
	if type(root) ~= "table" then
		root = {}
		_G[svName] = root
	end
	local db = { _svName = svName, _root = root, _profileDefaults = (defaults and defaults.profile) or {} }
	db._isNew = type(root.profile) ~= "table"
	if db._isNew then root.profile = {} end
	db.profile = DeepMergeDefaults(root.profile, db._profileDefaults)
	function db:ResetProfile()
		self._root.profile = DeepMergeDefaults({}, self._profileDefaults)
		self.profile = self._root.profile
	end
	return db
end
function Lite.NewAddon(name)
	local addon = { name = name }
	local f = CreateFrame("Frame")
	f:RegisterEvent("ADDON_LOADED")
	f:RegisterEvent("PLAYER_LOGIN")
	f:SetScript("OnEvent", function(self, event, arg1)
		if event == "ADDON_LOADED" then
			if arg1 ~= name then return end
			self:UnregisterEvent("ADDON_LOADED")
			if addon.OnInitialize then addon:OnInitialize() end
			addon._initialized = true
			if IsLoggedIn and IsLoggedIn() and not addon._enabled then
				addon._enabled = true
				if addon.OnEnable then addon:OnEnable() end
			end
		elseif event == "PLAYER_LOGIN" then
			self:UnregisterEvent("PLAYER_LOGIN")
			if addon._initialized and not addon._enabled then
				addon._enabled = true
				if addon.OnEnable then addon:OnEnable() end
			end
		end
	end)
	return addon
end

-------------------------------------------------------------------------------
--  Combat queue: keyed work run once combat ends (last caller per key wins).
-------------------------------------------------------------------------------
local function NewCombatQueue(frame)
	local pending, order = {}, {}
	frame = frame or CreateFrame("Frame")
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	frame:SetScript("OnEvent", function()
		local list, keys = pending, order
		pending, order = {}, {}
		for _, key in ipairs(keys) do
			local fn = list[key]
			if fn then
				local ok, err = pcall(fn)
				if not ok then geterrorhandler()(err) end
			end
		end
	end)
	return {
		Defer = function(key, fn)
			if pending[key] == nil then order[#order + 1] = key end
			pending[key] = fn
		end,
	}
end

-------------------------------------------------------------------------------
--  Visibility checklist (retail EvalVisibilityExtended on the "visibility"
--  key): Never / Always / Mouseover base, Match All / Any, Show / Hide lanes.
--  Same lane keys and rules as the Minimap and Action Bars ports.
-------------------------------------------------------------------------------
local function InCombat()
	return (InCombatLockdown() or UnitAffectingCombat("player")) and true or false
end
local VIS_AXES = {
	{ key = "in_combat", label = "In Combat", show = "in_combat", hide = "hide_in_combat", test = InCombat },
	{ key = "out_of_combat", label = "Out of Combat", show = "out_of_combat", hide = "hide_out_of_combat",
		test = function() return not InCombat() end },
	{ key = "in_raid", label = "In Raid Group", show = "in_raid", hide = "hide_in_raid",
		test = function() return IsInRaid() and true or false end },
	{ key = "in_party", label = "In Party", show = "in_party", hide = "hide_in_party",
		test = function() return (IsInGroup() and not IsInRaid()) and true or false end },
	{ key = "solo", label = "Solo", show = "solo", hide = "hide_solo",
		test = function() return not IsInGroup() end },
	{ key = "instances", label = "Instances", show = "visOnlyInstances", hide = "visHideInstances",
		test = function() local inside = IsInInstance() return inside and true or false end },
	{ key = "mounted", label = "Mounted", show = "visOnlyMounted", hide = "visHideMounted",
		test = function() return IsMounted() and true or false end },
	{ key = "target", label = "Target", show = "visHideNoTarget", hide = "visHideWithTarget",
		test = function() return UnitExists("target") and true or false end },
	{ key = "enemy", label = "Enemy Target", show = "visHideNoEnemy", hide = "visHideWithEnemy",
		test = function() return (UnitExists("target") and UnitCanAttack("player", "target")) and true or false end },
	{ key = "resting", label = "Resting", show = "visOnlyResting", hide = "visHideResting",
		test = function() return IsResting() and true or false end },
	{ key = "vehicle", label = "In Vehicle", show = "visOnlyVehicle", hide = "visHideVehicle",
		test = function() return UnitHasVehicleUI and UnitHasVehicleUI("player") and true or false end },
}
ns.VIS_AXES = VIS_AXES

local function VisFlag(s, key)
	if key:match("^vis") then return s[key] and true or false end
	local modes = s.visibilityModes
	if modes and modes[key] then return true end
	local vis = s.visibility
	if vis and vis ~= "always" and vis ~= "never" and vis ~= "mouseover" and vis == key then return true end
	return false
end
local function SetVisFlag(s, key, on)
	if key:match("^vis") then
		s[key] = on and true or nil
		return
	end
	s.visibilityModes = s.visibilityModes or {}
	s.visibilityModes[key] = on and true or nil
end
local function VisBase(s)
	local vis = s and s.visibility or "always"
	if vis == "never" then return "never" elseif vis == "mouseover" then return "mouseover" end
	return "always"
end
local function SetVisBase(s, mode)
	local old = s.visibility
	if old and old ~= "always" and old ~= "never" and old ~= "mouseover" then SetVisFlag(s, old, true) end
	s.visibility = mode
end
ns.VisFlag, ns.SetVisFlag, ns.VisBase, ns.SetVisBase = VisFlag, SetVisFlag, VisBase, SetVisBase

-- true = shown, false = hidden, "mouseover" = shown while hovered.
local function EvalVisibility(s)
	local base = VisBase(s)
	if base == "never" then return false end
	local anyShow, allOk, anyOk = false, true, false
	for _, axis in ipairs(VIS_AXES) do
		local hideOn = VisFlag(s, axis.hide)
		local showOn = VisFlag(s, axis.show)
		if hideOn or showOn then
			local now = axis.test()
			if hideOn and now then return false end
			if showOn then
				anyShow = true
				if now then anyOk = true else allOk = false end
			end
		end
	end
	if anyShow then
		if s.visibilityMatch == "any" then
			if not anyOk then return false end
		elseif not allOk then
			return false
		end
	end
	if base == "mouseover" then return "mouseover" end
	return true
end
ns.EvalVisibility = EvalVisibility

-------------------------------------------------------------------------------
--  Mouseover reveal (retail RegisterMouseoverTarget): a 0.1 s cursor poll
--  over plain-table proxies; Show / Hide fire only on a change.
-------------------------------------------------------------------------------
local moTargets = {}
do
	local poll = CreateFrame("Frame")
	local acc = 0
	poll:SetScript("OnUpdate", function(_, elapsed)
		acc = acc + elapsed
		if acc < 0.1 then return end
		acc = 0
		local cx, cy = GetCursorPosition()
		for _, t in ipairs(moTargets) do
			if t.eligible() then
				local over = false
				local l, b, w, h = t.proxy.GetRect()
				if l then
					local s = t.proxy.GetEffectiveScale() or 1
					local x, y = cx / s, cy / s
					over = x >= l and x <= l + w and y >= b and y <= b + h
				end
				if t.state ~= over then
					t.state = over
					if over then t.proxy.Show() else t.proxy.Hide() end
				end
			else
				t.state = nil
			end
		end
	end)
end
local function RegisterMouseoverTarget(proxy, eligible)
	moTargets[#moTargets + 1] = { proxy = proxy, eligible = eligible or function() return true end }
end

-------------------------------------------------------------------------------
--  Unlock Mode (MoP core: ns.unlockElements entries with SetUnlocked /
--  Snapshot / Changed / Restore). One mover per bar, built from the retail
--  MakeUnlockElement spec (getFrame, savePos, loadPos, applyPos, isHidden).
-------------------------------------------------------------------------------
local elementsByKey = {}

local function MakeMover(spec)
	local m = CreateFrame("Frame", nil, UIParent)
	m:SetFrameStrata("DIALOG")
	m:SetMovable(true)
	m:EnableMouse(true)
	m:RegisterForDrag("LeftButton")
	m:SetClampedToScreen(true)
	m.bg = m:CreateTexture(nil, "BACKGROUND")
	m.bg:SetAllPoints()
	PP.CreateBorder(m, ACCENT.r, ACCENT.g, ACCENT.b, 0.9, 1, "OVERLAY", 7)
	m.text = m:CreateFontString(nil, "OVERLAY")
	m.text:SetFont(Core.FONT or FONT_FALLBACK, 11, "OUTLINE")
	if not m.text:GetFont() then m.text:SetFont(FONT_FALLBACK, 11, "OUTLINE") end
	m.text:SetPoint("BOTTOMLEFT", m, "TOPLEFT", 0, 3)
	m:SetScript("OnDragStart", function(self) self:StartMoving() end)
	m:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local f = spec.getFrame and spec.getFrame()
		local scale = self:GetEffectiveScale() / UIParent:GetEffectiveScale()
		local cx, cy = self:GetCenter()
		local ux, uy = UIParent:GetCenter()
		if cx then
			local x = floor((cx * scale - ux) * 2 + 0.5) / 2
			local y = floor((cy * scale - uy) * 2 + 0.5) / 2
			spec.savePos(spec.key, "CENTER", "CENTER", x, y)
			if spec.applyPos and not (InCombatLockdown() and f and f:IsProtected()) then spec.applyPos() end
		end
		self:Sync()
		if Core.RefreshSettings then pcall(Core.RefreshSettings) end
	end)
	function m:Sync()
		local f = spec.getFrame and spec.getFrame()
		self:ClearAllPoints()
		if f then
			self:SetAllPoints(f)
		else
			self:SetSize(1, 1)
			self:SetPoint("CENTER")
		end
		self.bg:SetTexture(ACCENT.r, ACCENT.g, ACCENT.b, 0.15)
		self.text:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b)
		self.text:SetText(spec.labelFn and spec.labelFn() or spec.label or "")
	end
	m:Hide()
	return m
end

-- Retail EllesmereUI.MakeUnlockElement: keeps the spec as the element.
local function MakeUnlockElement(spec)
	return spec
end

-- Adds or refreshes the elements; a key registered before keeps its slot
-- (the core reads ns.unlockElements by index while Unlock Mode is open).
local function RegisterUnlockElements(_, list)
	Core.unlockElements = Core.unlockElements or {}
	for _, spec in ipairs(list) do
		local el = elementsByKey[spec.key]
		if not el then
			el = { name = spec.label }
			elementsByKey[spec.key] = el
			tinsert(Core.unlockElements, el)
		end
		el.spec = spec
		el.name = spec.label
		el.SetUnlocked = function(on)
			local sp = el.spec
			local hidden = sp.isHidden and sp.isHidden()
			local f = sp.getFrame and sp.getFrame()
			if not on or hidden or not f or InCombatLockdown() then
				if el.mover then el.mover:Hide() end
				return
			end
			if not el.mover then el.mover = MakeMover(sp) end
			el.mover:Sync()
			el.mover:Show()
		end
		el.Snapshot = function()
			local pos = el.spec.loadPos and el.spec.loadPos()
			local snap = { snapEdge = el.spec.getSnapEdge and el.spec.getSnapEdge() }
			if pos then snap.point, snap.relPoint, snap.x, snap.y = pos.point, pos.relPoint, pos.x, pos.y end
			return snap
		end
		el.Changed = function(snap)
			local pos = el.spec.loadPos and el.spec.loadPos()
			local edge = el.spec.getSnapEdge and el.spec.getSnapEdge()
			if edge ~= snap.snapEdge then return true end
			if not pos then return snap.point ~= nil end
			return pos.point ~= snap.point or pos.relPoint ~= snap.relPoint or pos.x ~= snap.x or pos.y ~= snap.y
		end
		el.Restore = function(snap)
			local sp = el.spec
			if sp.isHidden and sp.isHidden() then return end
			if snap.point then
				sp.savePos(sp.key, snap.point, snap.relPoint, snap.x, snap.y)
			elseif sp.clearPos then
				sp.clearPos()
			end
			if sp.setSnapEdge then sp.setSnapEdge(snap.snapEdge) end
			if sp.applyPos then sp.applyPos() end
			if el.mover and el.mover:IsShown() then el.mover:Sync() end
		end
	end
end

-------------------------------------------------------------------------------
--  Bar textures (retail BuildBarTextureTables / AppendSharedMediaTextures):
--  key = display name, value = file path; "none" = flat.
-------------------------------------------------------------------------------
local function AppendSharedMediaTextures(names, order, _, textures)
	local list = Core.GetBarTextures and Core.GetBarTextures() or {}
	for _, e in ipairs(list) do
		local key = e.name or e.path
		if key and not textures[key] then
			textures[key] = e.path
			names[key] = e.name or key
			order[#order + 1] = key
		end
	end
end
local function BuildBarTextureTables()
	local textures, names, order = {}, { none = "None" }, { "none" }
	AppendSharedMediaTextures(names, order, nil, textures)
	return textures, names, order
end

-------------------------------------------------------------------------------
--  Number formatting, names, colors
-------------------------------------------------------------------------------
local function AbbreviateNumber(val)
	val = tonumber(val) or 0
	local a = abs(val)
	local function Fmt(n, suffix)
		local s = format("%.1f", n)
		s = s:gsub("%.0$", "")
		return s .. suffix
	end
	if a >= 1e9 then return Fmt(val / 1e9, "B") end
	if a >= 1e6 then return Fmt(val / 1e6, "M") end
	if a >= 1e3 then return Fmt(val / 1e3, "K") end
	return tostring(floor(val + 0.5))
end

local function GetClassColor(token)
	local c = token and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
	if c then return c end
	return { r = 1, g = 1, b = 1 }
end

local function ColorText(text, r, g, b)
	return format("|cff%02x%02x%02x%s|r", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5), text or "")
end

-- "Name" or "Name-Realm" -> a whisper / invite target (no doubled realm).
local function BuildFullName(name, realm)
	if not name or name == "" then return nil end
	if name:find("%-") then
		local n, r = name:match("^([^%-]+)%-(.+)$")
		r = r and r:match("^([^%-]+)") or r
		return n .. "-" .. (r or "")
	end
	realm = realm and realm:gsub("%s+", "") or ""
	if realm == "" or realm == (GetRealmName() or ""):gsub("%s+", "") then return name end
	return name .. "-" .. realm
end

-- Retail ShowConfirmPopup-based reload prompt; a plain StaticPopup here.
StaticPopupDialogs["EUI_DATABARS_RELOAD"] = {
	text = "%s",
	button1 = ACCEPT or "Accept",
	button2 = CANCEL or "Cancel",
	OnAccept = function() ReloadUI() end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}
local function RequestReload(title, message)
	StaticPopup_Show("EUI_DATABARS_RELOAD", message or title or "Reload the UI now?")
end

-- Mists of Pandaria challenge mode teleports (retail SEASON_PORTALS shape).
local SEASON_PORTALS = {
	{ spellID = 131204 }, -- Path of the Jade Serpent (Temple of the Jade Serpent)
	{ spellID = 131205 }, -- Path of the Stout Brew (Stormstout Brewery)
	{ spellID = 131206 }, -- Path of the Shado-Pan (Shado-Pan Monastery)
	{ spellID = 131222 }, -- Path of the Mogu King (Mogu'shan Palace)
	{ spellID = 131225 }, -- Path of the Setting Sun (Gate of the Setting Sun)
	{ spellID = 131228 }, -- Path of the Black Ox (Siege of Niuzao Temple)
	{ spellID = 131229 }, -- Path of the Scarlet Mitre (Scarlet Monastery)
	{ spellID = 131231 }, -- Path of the Scarlet Blade (Scarlet Halls)
	{ spellID = 131232 }, -- Path of the Necromancer (Scholomance)
}

-------------------------------------------------------------------------------
--  The EllesmereUI proxy the DataBars files see as "EllesmereUI"
-------------------------------------------------------------------------------
local function L(s) return s end
local function Lf(fmt, ...)
	if type(fmt) ~= "string" then return tostring(fmt) end
	return format((fmt:gsub("%%(%d)%$", "%%")), ...)
end

local EUI = setmetatable({
	IS_FOREVER = false,
	L = L,
	Lf = Lf,
	PP = PP,
	Lite = Lite,
	_ModuleNS = { [addonName] = ns },
	NewCombatQueue = NewCombatQueue,
	ELLESMERE_GREEN = ACCENT,
	COLOR_CODES = { WHITE = "|cffffffff" },
	GetAccentColor = function() return ACCENT.r, ACCENT.g, ACCENT.b end,
	PrimeFontShadow = PrimeFontShadow,
	GetFontUseShadow = function() return (Core.GetFontOutlineFlag and Core.GetFontOutlineFlag("dataBars") or "") == "" end,
	AbbreviateNumber = AbbreviateNumber,
	LocaleHasNumberAbbreviation = function() return false end,
	BuildBarTextureTables = BuildBarTextureTables,
	AppendSharedMediaTextures = AppendSharedMediaTextures,
	VisOverrideValue = function() return nil end,
	CheckVisibilityOptions = function() return false end,
	EvalVisibilityExtended = function(cfg) return EvalVisibility(cfg) end,
	RegisterMouseoverTarget = RegisterMouseoverTarget,
	-- MakeUnlockElement / RegisterUnlockElements / _ELEMENT_SETTINGS_MAP: the core's
	-- (the EllesmereUI core runs the retail Unlock Mode since 3.11).
	_hasGlidingEvent = false,
	PartySpin_Create = noop,
	RegisterVisEdge = noop,
	SEASON_PORTALS = SEASON_PORTALS,
	RequestReload = RequestReload,
	GetClassColor = GetClassColor,
	ColorText = ColorText,
	BuildFullName = BuildFullName,
	ClassTokenFromLocalized = function(name) return name and CLASS_TOKEN_BY_NAME[name] end,
	InProtectedInstance = function() return false end,
	IsDevModeActive = function() return false end,
	PlayerCritChance = function() return GetCritChance(), CR_CRIT_MELEE end,
	EnsureLoaded = function() return Core.LoadOptions and Core.LoadOptions() end,
}, { __index = Core, __newindex = Core })
env.EllesmereUI = EUI
ns.EUI = EUI
ns.PP = PP
ns.ACCENT = ACCENT

-- Module font (Global Settings > Fonts, key "dataBars"). rawset: a plain write
-- would go through to the core table.
rawset(EUI, "GetFontOutlineFlag", function(key)
	return (Core.GetFontOutlineFlag and Core.GetFontOutlineFlag(key or "dataBars")) or ""
end)
rawset(EUI, "GetFontPath", function(key)
	return (Core.GetFontPath and Core.GetFontPath(key or "dataBars")) or Core.FONT or FONT_FALLBACK
end)

-- Pixel size and accent follow UI scale / theme changes.
local scaleWatch = CreateFrame("Frame")
scaleWatch:RegisterEvent("UI_SCALE_CHANGED")
scaleWatch:RegisterEvent("DISPLAY_SIZE_CHANGED")
scaleWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
scaleWatch:SetScript("OnEvent", function()
	PP.UpdateMult()
	RefreshAccentColor()
end)

-- From here on the environment reads and writes the real globals for every
-- name not defined above.
setmetatable(env, { __index = _G, __newindex = _G })
