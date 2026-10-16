-------------------------------------------------------------------------------
--  EllesmereUITopBar.lua (5.4.8 port of the NaowhUI top bar, NaowhUI_TopBar.lua)
--
--  [friends guild] [clock] [hearth portals] at the top of the screen, plus a
--  FPS / MS readout under it. Same keys, look and options as retail.
--
--  5.4.8 changes:
--    * Friends / Guild open with ToggleFriendsFrame / ToggleGuildFrame (not
--      protected here), so only the hearth button is secure.
--    * No toys: the random rotation rolls the hearth items and spells of
--      Mists of Pandaria (Hearthstone, Innkeeper's Daughter, Dark Portal,
--      Ethereal Portal, Astral Recall).
--    * Middle-click (retail: Dalaran Hearthstone) = Wormhole Generator
--      (Pandaria, else Northrend). Right-click (retail: Key to the Arcantina)
--      = the class travel spell (Zen Pilgrimage, Death Gate, Teleport:
--      Moonglade, Mage teleport to the Vale of Eternal Blossoms).
--    * M+ Portals = the Challenge Mode teleports (EllesmereUITopBar_Portals.lua).
--    * "Hide EllesmereUI FPS / MS Counter" hides the Minimap's FPS / MS text
--      (this port has no QoL FPS counter).
--    * Resting icon = the 5.4.8 resting state icon (pulses), not the flipbook.
--    * Hearthstone picker = a checkbox dropdown on the settings page.
-------------------------------------------------------------------------------
local addonName = ...
local ns = EllesmereUI

local floor, max, min = math.floor, math.max, math.min
local format = string.format

local TopBar = {}
ns.TopBar = TopBar

local FONT_KEY = "topBar"
local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\media\\"
local FALLBACK_FONT = STANDARD_TEXT_FONT

-------------------------------------------------------------------------------
--  Defaults / DB (EllesmereUITopBarDB, retail NaowhUIEUIDB topBar keys)
-------------------------------------------------------------------------------
local BAR_DEFAULTS = {
	enabled           = false,
	iconSize          = 18,
	buttonGap         = 4,
	edgeInset         = 14,
	use24h            = true,
	hideInCombat      = false,
	hideEUIFps        = true,
	bgAlpha           = 0.85,
	showSystem        = true,
	showSystemTooltip = true,
	sysSize           = 11,
	clockFont         = "__default",   -- follow the EllesmereUI font (Top Bar module font)
	clockSize         = 20,
	baseHearthOnly    = false,
	-- hearthPool = { [key] = true } once curated; nil = every owned stone rolls.
	iconR             = 1,
	iconG             = 1,
	iconB             = 1,
	-- pos = { point, relPoint, x, y } once moved in Unlock Mode; nil = top centre.
}
TopBar.DEFAULTS = BAR_DEFAULTS

local db

local function TDB()
	if not db then
		db = ns.ModuleDB("EllesmereUITopBarDB")
	end
	for k, v in pairs(BAR_DEFAULTS) do
		if db[k] == nil then db[k] = v end
	end
	return db
end
ns.GetTopBarDB = TDB

-- First login: the retail NaowhUI preset (bar on, EllesmereUI FPS hidden).
local function SeedNaowh(t)
	t.enabled, t.hideEUIFps = true, true
	t._seeded = 1
end

local function IconRGB()
	local t = TDB()
	return t.iconR or 1, t.iconG or 1, t.iconB or 1
end

local CLOCK_PAD = 6   -- room above/below the clock inside its pill
local BTN_PAD   = 8   -- button footprint around the icon

local function BtnSize()
	return (TDB().iconSize or 18) + BTN_PAD
end

local function BarHeight()
	local t = TDB()
	return max((t.clockSize or 20) + CLOCK_PAD, BtnSize() + 2)
end

-------------------------------------------------------------------------------
--  Timers and combat queue (5.4.8 has no C_Timer)
-------------------------------------------------------------------------------
local combatQueue = {}
local combatFrame = CreateFrame("Frame")
combatFrame:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	local list = combatQueue
	combatQueue = {}
	for i = 1, #list do
		local ok, err = pcall(list[i])
		if not ok then geterrorhandler()(err) end
	end
end)

local function RunOutOfCombat(fn)
	if not InCombatLockdown() then
		fn()
		return
	end
	combatQueue[#combatQueue + 1] = fn
	combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
end
TopBar.RunOutOfCombat = RunOutOfCombat

-------------------------------------------------------------------------------
--  Hearthstones:  left = the random rotation | middle = wormhole | right = class travel
-------------------------------------------------------------------------------
local BASE_HEARTH = 6948   -- plain Hearthstone, the universal fallback

-- Hearth items of Mists of Pandaria (bag items, used by item id).
local HEARTH_POOL = {
	6948,    -- Hearthstone
	64488,   -- The Innkeeper's Daughter (Archaeology)
	93672,   -- Dark Portal (TCG)
	54452,   -- Ethereal Portal (TCG)
}

-- Hearth-equivalents granted by a class.
local HEARTH_SPELLS = {
	556,     -- Astral Recall (Shaman)
}

-- Middle-click: first owned (retail: Dalaran Hearthstone).
local MIDDLE_TRAVEL = {
	{ item = 87215 },   -- Wormhole Generator: Pandaria
	{ item = 48933 },   -- Wormhole Generator: Northrend
}

-- Right-click: first known (retail: Key to the Arcantina).
local RIGHT_TRAVEL = {
	{ spell = 126892 },   -- Zen Pilgrimage (Monk)
	{ spell = 50977 },    -- Death Gate (Death Knight)
	{ spell = 18960 },    -- Teleport: Moonglade (Druid)
	{ spell = 132621 },   -- Teleport: Vale of Eternal Blossoms (Mage, Alliance)
	{ spell = 132627 },   -- Teleport: Vale of Eternal Blossoms (Mage, Horde)
}

local _hearthId   -- the item the left click will use; the tooltip reads its cooldown

local function ItemName(id, fallback)
	local name = GetItemInfo(id)
	return name or fallback
end

local function ItemIcon(id)
	local icon = GetItemIcon and GetItemIcon(id)
	if not icon then icon = select(10, GetItemInfo(id)) end
	return icon or "Interface\\Icons\\INV_Misc_Rune_01"
end

local function OwnsItem(id)
	return (GetItemCount(id) or 0) > 0
end

local function KnowsSpell(id)
	if IsPlayerSpell and IsPlayerSpell(id) then return true end
	return IsSpellKnown and IsSpellKnown(id) or false
end

-- Everything this character can hearth with. Spells carry their own key
-- prefix so an item and an ability can never collide in the stored set.
local function OwnedHearths()
	local out = {}
	for _, id in ipairs(HEARTH_POOL) do
		if OwnsItem(id) then
			out[#out + 1] = {
				key = "i" .. id, id = id,
				name = ItemName(id, "Item " .. id), icon = ItemIcon(id),
			}
		end
	end
	for _, id in ipairs(HEARTH_SPELLS) do
		if KnowsSpell(id) then
			local name, _, icon = GetSpellInfo(id)
			out[#out + 1] = {
				key = "s" .. id, id = id, spell = true,
				name = name or ("Spell " .. id),
				icon = icon or "Interface\\Icons\\INV_Misc_Rune_01",
			}
		end
	end
	return out
end
TopBar.OwnedHearths = OwnedHearths

-- No stored set means every owned stone rolls. A stored set is used as written.
local function InRotation(key)
	local pool = TDB().hearthPool
	if type(pool) ~= "table" then return true end
	return pool[key] == true
end
TopBar.InRotation = InRotation

local function RotationEntries()
	local out = {}
	for _, e in ipairs(OwnedHearths()) do
		if InRotation(e.key) then out[#out + 1] = e end
	end
	return out
end

-- Toggles one stone; an all-ticked set is stored as no set (new stones join).
function TopBar.ToggleHearth(key)
	local entries = OwnedHearths()
	local pool = {}
	for _, e in ipairs(entries) do pool[e.key] = InRotation(e.key) or nil end
	pool[key] = (not pool[key]) or nil
	for _, e in ipairs(entries) do
		if not pool[e.key] then
			TDB().hearthPool = pool
			return
		end
	end
	TDB().hearthPool = nil
end

local function HearthMacro(id)
	_hearthId = id
	return "/use item:" .. id
end

-- Left click: the plain stone when Base Hearthstone Only is on, else a roll
-- of the rotation. An empty rotation falls back to it too.
local function HearthResolve()
	if TDB().baseHearthOnly then return HearthMacro(BASE_HEARTH) end
	local pool = RotationEntries()
	if #pool == 0 then return HearthMacro(BASE_HEARTH) end
	local pick = pool[math.random(#pool)]
	if pick.spell then
		_hearthId = nil
		return "/cast " .. pick.name
	end
	return HearthMacro(pick.id)
end

-- First usable entry of a travel list: macro text, name (nil = none).
local function TravelResolve(list)
	for _, e in ipairs(list) do
		if e.item and OwnsItem(e.item) then
			return "/use item:" .. e.item, ItemName(e.item, "Item " .. e.item)
		elseif e.spell and KnowsSpell(e.spell) then
			local name = GetSpellInfo(e.spell)
			if name then return "/cast " .. name, name end
		end
	end
	return "", nil
end

-------------------------------------------------------------------------------
--  Elements
-------------------------------------------------------------------------------
-- White art with the detail cut out of the alpha, which is what makes it tintable.
local ICON = {
	friends = MEDIA .. "icon-friends",
	guild   = MEDIA .. "icon-guild",
	hearth  = MEDIA .. "icon-hearth",
	mplus   = MEDIA .. "icon-mplus",
}

local TIP = {
	friends = "Friends",
	guild   = "Guild & Communities",
	hearth  = "Hearthstone",
	mplus   = "Challenge Mode Portals",
}

local LEFT_ORDER  = { "friends", "guild" }
local RIGHT_ORDER = { "hearth", "mplus" }

-------------------------------------------------------------------------------
--  Bar
-------------------------------------------------------------------------------
local bar, clockText, leftGroup, rightGroup
local buttons = {}

local function GetFont()
	return (ns.GetFontPath and ns.GetFontPath(FONT_KEY)) or FALLBACK_FONT
end

-- Takes precedence over the saved setting, so hovering a dropdown entry previews it.
local _clockFontPreview

local function ClockFontPath()
	local v = _clockFontPreview or TDB().clockFont
	if not v or v == "__default" then return GetFont() end
	return (ns.ResolveFontName and ns.ResolveFontName(v)) or GetFont()
end

-- A FontString needs a valid font before SetText.
local function SetFontSafe(fs, path, size, flags)
	fs:SetFont(path, size, flags)
	if not fs:GetFont() then fs:SetFont(FALLBACK_FONT, size, flags) end
end

local function SetClockFont(size)
	if not clockText then return end
	SetFontSafe(clockText, ClockFontPath(), size, "")
end

local function AccentRGB()
	if ns.ResolveAccent then return ns.ResolveAccent() end
	return 12 / 255, 210 / 255, 157 / 255
end

-- Set when a fit is skipped for combat, so the ticker retries once it ends.
local _fitPending = false

-- Resizing re-anchors the secure children, which is protected in combat.
local function FitBarWidth()
	if not (bar and leftGroup and rightGroup and clockText) then return end
	if InCombatLockdown() then _fitPending = true; return end
	_fitPending = false
	local t = TDB()
	local gap = 22
	local clockW = max(24, (clockText:GetStringWidth() or 0) + 8)
	bar:SetWidth(max(120,
		t.edgeInset + leftGroup:GetWidth() + gap + clockW + gap + rightGroup:GetWidth() + t.edgeInset))
end

-- The bar parents a secure button, so Hide() in combat is protected. A
-- visibility state driver does it from inside the secure environment.
local function ApplyBarVisibility()
	if not bar or InCombatLockdown() then return end
	local t = TDB()
	if t.enabled and t.hideInCombat then
		RegisterStateDriver(bar, "visibility", "[combat] hide; show")
	else
		UnregisterStateDriver(bar, "visibility")
		if t.enabled then bar:Show() else bar:Hide() end
	end
end

-- SetPoint re-anchors the secure children, so it is protected in combat.
local function ApplyBarPosition()
	if not bar or InCombatLockdown() then return end
	if ns._unlockActive and bar:GetNumPoints() > 0 then return end
	local p = TDB().pos
	bar:ClearAllPoints()
	if p then
		bar:SetPoint(p.point or "TOP", UIParent, p.relPoint or "TOP", p.x or 0, p.y or 0)
	else
		bar:SetPoint("TOP", UIParent, "TOP", 0, 0)
	end
	if not ns._unlockActive and ns.IsUnlockAnchored and ns.IsUnlockAnchored("EUI_TopBar") and ns.ReapplyOwnAnchor then
		ns.ReapplyOwnAnchor("EUI_TopBar")
	end
end
TopBar.ApplyBarPosition = ApplyBarPosition

-- Returns whether the time changed, so callers skip the re-fit on the other 59 ticks.
local function PaintClock()
	if not clockText then return false end
	local use24h = TDB().use24h
	local txt = date(use24h and "%H:%M" or "%I:%M %p")
	if not use24h then txt = txt:gsub("^0", "") end
	if txt == clockText._last then return false end
	clockText._last = txt
	clockText:SetText(txt)
	return true
end

-- Re-fits too: a different typeface changes the string width.
local function PreviewClockFont(name)
	if _clockFontPreview == name then return end
	_clockFontPreview = name
	SetClockFont(TDB().clockSize or 20)
	FitBarWidth()
end
TopBar.PreviewClockFont = PreviewClockFont

local function UpdateResting()
	local rf = bar and bar._restFrame
	if not rf then return end
	if TDB().enabled and IsResting and IsResting() then rf:Show() else rf:Hide() end
end

-------------------------------------------------------------------------------
--  Live info
-------------------------------------------------------------------------------
local function FriendsOnline()
	local _, bn = BNGetNumFriends()
	local _, wow = GetNumFriends()
	return (bn or 0) + (wow or 0)
end

local function GuildOnline()
	if not IsInGuild() then return nil end
	local _, online = GetNumGuildMembers()
	return online or 0
end

local function HearthCooldown()
	local id = _hearthId
	if not id then return nil end
	local start, dur = GetItemCooldown(id)
	if type(start) == "number" and type(dur) == "number" and dur > 0 then
		local rem = start + dur - GetTime()
		if rem > 0 then return rem end
	end
	return nil
end

local function FmtCD(sec)
	sec = floor(sec + 0.5)
	if sec >= 3600 then
		return format("%d:%02d:%02d", sec / 3600, (sec % 3600) / 60, sec % 60)
	end
	return format("%d:%02d", sec / 60, sec % 60)
end

local function FpsRGB(fps)
	if fps >= 100 then return 0.25, 1, 0.25
	elseif fps >= 60 then return 0.55, 1, 0.25
	elseif fps >= 30 then return 1, 1, 0.25 end
	return 1, 0.35, 0.25
end

local function MsRGB(ms)
	if ms < 75 then return 0.25, 1, 0.25
	elseif ms < 150 then return 1, 1, 0.25 end
	return 1, 0.35, 0.25
end

-- Includes the "ff" alpha prefix, so the escape below is |c%s (not |cff%s).
local function Hex(r, g, b)
	return format("ff%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

-------------------------------------------------------------------------------
--  Tooltips
-------------------------------------------------------------------------------
local ROSTER_CAP = 40   -- keep a big guild's tooltip from running off the screen
local BNET_WOW = BNET_CLIENT_WOW or "WoW"

-- Online BNet friends in WoW, then WoW friends.
local function AddFriendsRoster()
	local shown, hidden = 0, 0
	local function row(left, right, lr, lg, lb)
		if shown < ROSTER_CAP then GameTooltip:AddDoubleLine(left, right or "", lr, lg, lb, 0.7, 0.7, 0.7)
		else hidden = hidden + 1 end
		shown = shown + 1
	end
	local numBN = BNGetNumFriends() or 0
	for i = 1, numBN do
		local _, presenceName, battleTag, _, toonName, toonID, client, isOnline = BNGetFriendInfo(i)
		if isOnline and client == BNET_WOW then
			local right = toonName or ""
			if toonID and BNGetToonInfo then
				local zone = select(10, BNGetToonInfo(toonID))
				if zone and zone ~= "" then right = (right ~= "" and (right .. " - ") or "") .. zone end
			end
			local acc = presenceName
			if not acc or acc == "" then acc = battleTag and battleTag:match("^[^#]+") end
			row(acc or "?", right, 0.51, 0.77, 1)
		end
	end
	for i = 1, (GetNumFriends() or 0) do
		local name, level, _, area, connected = GetFriendInfo(i)
		if connected then
			local left = name or "?"
			if level and level > 0 then left = left .. "  " .. level end
			row(left, area, 1, 1, 1)
		end
	end
	if hidden > 0 then GameTooltip:AddLine(("... and %d more"):format(hidden), 0.5, 0.5, 0.5) end
	return shown
end

-- Guild name + online members, class-coloured. GuildRoster() answers async and is rate-limited.
local _lastGuildTipRoster = 0
local function AddGuildRoster()
	local now = GetTime()
	if now - _lastGuildTipRoster >= 10 then _lastGuildTipRoster = now; GuildRoster() end
	local gname = GetGuildInfo("player")
	if gname then GameTooltip:AddLine(gname, 0.1, 1, 0.1) end
	local shown, hidden = 0, 0
	for i = 1, (GetNumGuildMembers() or 0) do
		local name, _, _, level, _, zone, _, _, isOnline, status, class = GetGuildRosterInfo(i)
		if isOnline then
			if shown < ROSTER_CAP then
				local cc = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
				local r, g, b = 1, 1, 1
				if cc then r, g, b = cc.r, cc.g, cc.b end
				local cn = name and name:match("[^%-]+") or "?"
				local st = ""
				if status == 1 then st = "  |cff808080<AFK>|r"
				elseif status == 2 then st = "  |cff808080<DND>|r"
				elseif type(status) == "string" and status ~= "" then st = "  |cff808080" .. status .. "|r" end
				GameTooltip:AddDoubleLine((level and (level .. "  ") or "") .. cn .. st, zone or "", r, g, b, 0.7, 0.7, 0.7)
			else hidden = hidden + 1 end
			shown = shown + 1
		end
	end
	if hidden > 0 then GameTooltip:AddLine(("... and %d more"):format(hidden), 0.5, 0.5, 0.5) end
end

local function ShowElementTooltip(self)
	local key = self._key
	local ar, ag, ab = AccentRGB()
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")

	if key == "friends" then
		GameTooltip:AddLine("Friends", 1, 1, 1)
		GameTooltip:AddDoubleLine("Online", tostring(FriendsOnline()), 0.7, 0.7, 0.7, 0.3, 1, 0.3)
		if not InCombatLockdown() then
			GameTooltip:AddLine(" ")
			local ok, count = pcall(AddFriendsRoster)
			if ok and count == 0 then GameTooltip:AddLine("No friends online", 0.6, 0.6, 0.6) end
		end
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Left-click: open Friends", ar, ag, ab)
	elseif key == "guild" then
		GameTooltip:AddLine("Guild & Communities", 1, 1, 1)
		local n = GuildOnline()
		if n then
			GameTooltip:AddDoubleLine("Online", tostring(n), 0.7, 0.7, 0.7, 1, 0.6, 0.1)
			if not InCombatLockdown() then
				GameTooltip:AddLine(" ")
				pcall(AddGuildRoster)
			end
		else
			GameTooltip:AddLine("Not in a guild", 0.7, 0.7, 0.7)
		end
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Left-click: open Guild", ar, ag, ab)
	elseif key == "hearth" then
		GameTooltip:AddLine("Hearthstone", 1, 1, 1)
		local loc = GetBindLocation and GetBindLocation()
		if loc then GameTooltip:AddDoubleLine("Bind", loc, 0.7, 0.7, 0.7, 1, 1, 1) end
		local cd = HearthCooldown()
		if cd then GameTooltip:AddDoubleLine("Cooldown", FmtCD(cd), 0.7, 0.7, 0.7, 1, 0.3, 0.3)
		else GameTooltip:AddDoubleLine("Cooldown", "Ready", 0.7, 0.7, 0.7, 0.3, 1, 0.3) end
		GameTooltip:AddLine(" ")
		-- A rotation of one is a pin, so name it rather than calling it random.
		local pool = not TDB().baseHearthOnly and RotationEntries()
		if not pool or #pool == 0 then
			GameTooltip:AddLine("Left-click: " .. ItemName(BASE_HEARTH, "Hearthstone"), ar, ag, ab)
		elseif #pool == 1 then
			GameTooltip:AddLine("Left-click: " .. pool[1].name, ar, ag, ab)
		else
			GameTooltip:AddLine("Left-click: random Hearthstone", ar, ag, ab)
		end
		local _, midName = TravelResolve(MIDDLE_TRAVEL)
		if midName then GameTooltip:AddLine("Middle-click: " .. midName, ar, ag, ab) end
		local _, rightName = TravelResolve(RIGHT_TRAVEL)
		if rightName then GameTooltip:AddLine("Right-click: " .. rightName, ar, ag, ab) end
	elseif key == "mplus" then
		-- One line, anchored right: a tall tooltip below would cover the flyout it opens.
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Challenge Mode Portals", 1, 1, 1)
	else
		GameTooltip:AddLine(self._tipText or "", 1, 1, 1)
	end
	GameTooltip:Show()
end

-- The table is reused and the comparator hoisted, so a rescan allocates nothing.
local _memTable, _lastMemScan = {}, 0
local function ByMemDesc(a, b) return a.mem > b.mem end
local function ShowSystemTooltip(owner)
	local ar, ag, ab = AccentRGB()
	GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
	local fps = floor(GetFramerate() + 0.5)
	local _, _, home, world = GetNetStats()
	home, world = home or 0, world or home or 0
	GameTooltip:AddDoubleLine("FPS", fps .. " fps", 0.7, 0.7, 0.7, FpsRGB(fps))
	GameTooltip:AddDoubleLine("Home Latency", floor(home) .. " ms", 0.7, 0.7, 0.7, MsRGB(home))
	GameTooltip:AddDoubleLine("World Latency", floor(world) .. " ms", 0.7, 0.7, 0.7, MsRGB(world))

	-- The memory scan is a frame spike, so rescan at most every 30s.
	local now = GetTime()
	if (now - _lastMemScan) >= 30 then
		_lastMemScan = now
		UpdateAddOnMemoryUsage()
		local count = 0
		for i = 1, GetNumAddOns() do
			local mem = GetAddOnMemoryUsage(i)
			if mem and mem > 0 then
				count = count + 1
				local e = _memTable[count]
				if not e then e = {}; _memTable[count] = e end
				local name, title = GetAddOnInfo(i)
				e.name = title or name or "?"
				e.mem  = mem
			end
		end
		for i = count + 1, #_memTable do _memTable[i] = nil end
		table.sort(_memTable, ByMemDesc)
	end
	if #_memTable > 0 then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Addon Memory", ar, ag, ab)
		for i = 1, min(10, #_memTable) do
			local e = _memTable[i]
			local ms = e.mem > 1024 and format("%.2f MB", e.mem / 1024) or format("%.0f KB", e.mem)
			GameTooltip:AddDoubleLine(e.name, ms, 1, 1, 1, ar, ag, ab)
		end
	end

	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Left-click: refresh    Shift+Left-click: collect garbage", ar, ag, ab)
	GameTooltip:Show()
end

-- `live` re-shows the tooltip while hovered (the hearth, so its cooldown ticks).
local function AttachTooltip(b, live)
	b:SetScript("OnEnter", function(self)
		if self._icon then self._icon:SetVertexColor(AccentRGB()) end
		ShowElementTooltip(self)
		if live then
			self._ttT = 0
			self:SetScript("OnUpdate", function(s, e)
				s._ttT = s._ttT + e
				if s._ttT >= 0.5 then s._ttT = 0; ShowElementTooltip(s) end
			end)
		end
	end)
	b:SetScript("OnLeave", function(self)
		if self._icon then self._icon:SetVertexColor(IconRGB()) end
		self:SetScript("OnUpdate", nil)
		GameTooltip:Hide()
	end)
end

-------------------------------------------------------------------------------
--  Updates
-------------------------------------------------------------------------------
local _lastRoster = 0
local function UpdateBadges()
	if not bar then return end   -- bar never built: don't even poll the guild roster
	local fb = buttons.friends
	if fb and fb._badge then
		local n = FriendsOnline()
		fb._badge:SetText((n and n > 0) and tostring(n) or "")
	end
	local gb = buttons.guild
	if gb and gb._badge then
		local n = GuildOnline()
		gb._badge:SetText((n and n > 0) and tostring(n) or "")
	end
	-- Request a fresh roster; it answers via GUILD_ROSTER_UPDATE, so throttle hard.
	if IsInGuild() and not InCombatLockdown() then
		local now = GetTime()
		if (now - _lastRoster) >= 15 then _lastRoster = now; GuildRoster() end
	end
end

-- Below the bar while it is up; centred on it once it hides, where the clock sat.
-- sysBtn parents nothing secure, so this is combat-safe.
local function AnchorSystem()
	local sysBtn = bar and bar._sysBtn
	if not sysBtn then return end
	sysBtn:ClearAllPoints()
	if bar:IsShown() then
		sysBtn:SetPoint("TOP", bar, "BOTTOM", 0, -2)
	else
		sysBtn:SetPoint("CENTER", bar, "CENTER", 0, 0)
	end
end

-- Runs while the bar is hidden in combat too: sysBtn is a sibling of the bar.
local _lastFps, _lastMs
local function UpdateSystemText()
	local sysBtn = bar and bar._sysBtn
	if not sysBtn then return end
	local t = TDB()
	if not (t.enabled and t.showSystem) then sysBtn:Hide(); return end

	local fps  = floor(GetFramerate() + 0.5)
	local home = floor(select(3, GetNetStats()) or 0)
	if fps == _lastFps and home == _lastMs and sysBtn:IsShown() then return end
	_lastFps, _lastMs = fps, home

	bar._sysText:SetText(format("FPS: |c%s%d|r  MS: |c%s%d|r", Hex(FpsRGB(fps)), fps, Hex(MsRGB(home)), home))
	sysBtn:Show()
	sysBtn:SetWidth(max(40, bar._sysText:GetStringWidth() + 10))
end

local function ApplyIconColor()
	local r, g, b = IconRGB()
	for _, btn in pairs(buttons) do
		if btn._icon then btn._icon:SetVertexColor(r, g, b) end
	end
end
TopBar.ApplyIconColor = ApplyIconColor

-------------------------------------------------------------------------------
--  Element construction
-------------------------------------------------------------------------------
-- Parented straight to its final group: SetParent on a secure frame is
-- blocked in combat, so these are never re-parented later.
local function CreateElement(key, container)
	local b = CreateFrame("Button", "EllesmereUITopBar_" .. key, container,
		key == "hearth" and "SecureActionButtonTemplate" or nil)
	b:RegisterForClicks("AnyUp")

	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("CENTER")
	icon:SetTexture(ICON[key])
	icon:SetVertexColor(IconRGB())
	b._icon    = icon
	b._tipText = TIP[key]
	b._key     = key

	-- Centred on the icon, not the button: the button is padded.
	if key == "friends" or key == "guild" then
		local badge = b:CreateFontString(nil, "OVERLAY")
		SetFontSafe(badge, GetFont(), 10, "OUTLINE")
		badge:SetJustifyH("CENTER")
		badge:SetPoint("CENTER", icon, "BOTTOM", 0, 1)
		if key == "guild" then badge:SetTextColor(1, 0.62, 0.10) else badge:SetTextColor(0.30, 1, 0.30) end
		b._badge = badge
	end

	AttachTooltip(b, key == "hearth")
	buttons[key] = b
	return b
end

-- Out of combat only.
local function WireElement(key)
	local b = buttons[key]
	if not b then return end

	if key == "mplus" then
		b:EnableMouse(true)
		b:SetScript("OnClick", function(self)
			if TopBar.TogglePortalFlyout then TopBar.TogglePortalFlyout(self) end
		end)
		return
	end

	if key == "friends" then
		b:EnableMouse(true)
		b:SetScript("OnClick", function()
			if ToggleFriendsFrame then ToggleFriendsFrame(1) end
		end)
		return
	end

	if key == "guild" then
		b:EnableMouse(true)
		b:SetScript("OnClick", function()
			if ToggleGuildFrame then ToggleGuildFrame() end
		end)
		return
	end

	if key == "hearth" then
		-- Button-scoped attributes, so each click is separate.
		b:SetAttribute("type", "macro")
		b:SetAttribute("macrotext", HearthResolve())                          -- left: rotation
		b:SetAttribute("*type2", "macro")
		b:SetAttribute("*macrotext2", (TravelResolve(RIGHT_TRAVEL)))          -- right: class travel
		b:SetAttribute("*type3", "macro")
		b:SetAttribute("*macrotext3", (TravelResolve(MIDDLE_TRAVEL)))         -- middle: wormhole
		b:EnableMouse(true)
		-- Re-resolve per click: the left re-rolls, and item names may not be cached at login.
		b:SetScript("PreClick", function(self)
			if InCombatLockdown() then return end
			self:SetAttribute("macrotext", HearthResolve())
			self:SetAttribute("*macrotext2", (TravelResolve(RIGHT_TRAVEL)))
			self:SetAttribute("*macrotext3", (TravelResolve(MIDDLE_TRAVEL)))
		end)
	end
end

-- Out of combat only.
local function LayoutGroup(container, order, btnSize, gap, iconSize)
	if not container then return end
	local x = 0
	for _, key in ipairs(order) do
		local b = buttons[key]
		if b then
			b:SetSize(btnSize, btnSize)
			b:ClearAllPoints()
			b:SetPoint("LEFT", container, "LEFT", x, 0)
			b._icon:SetSize(iconSize, iconSize)
			x = x + btnSize + gap
		end
	end
	container:SetSize(max(1, x - gap), btnSize)
end

-------------------------------------------------------------------------------
--  Build
-------------------------------------------------------------------------------
function TopBar.Create()
	if bar then return bar end
	local t = TDB()

	bar = CreateFrame("Frame", "EllesmereUITopBar", UIParent)
	bar:SetSize(360, BarHeight())
	bar:SetFrameStrata("MEDIUM")
	-- A saved pos is a raw offset, so a UI-scale change could push the bar out of reach.
	bar:SetClampedToScreen(true)
	ApplyBarPosition()

	-- Three dark pills with transparent gaps; the bar frame itself has no background.
	bar._segs, bar._segLines = {}, {}
	for i = 1, 3 do
		local seg = bar:CreateTexture(nil, "BACKGROUND")
		seg:SetTexture(0.03, 0.03, 0.04, t.bgAlpha)
		bar._segs[i] = seg
		local line = bar:CreateTexture(nil, "BORDER")
		line:SetHeight(1)
		line:SetPoint("BOTTOMLEFT",  seg, "BOTTOMLEFT",  0, 0)
		line:SetPoint("BOTTOMRIGHT", seg, "BOTTOMRIGHT", 0, 0)
		bar._segLines[i] = line
	end
	bar._segL, bar._segC, bar._segR = bar._segs[1], bar._segs[2], bar._segs[3]

	local function ApplyAccent(r, g, b)
		if not (r and g and b) then r, g, b = AccentRGB() end
		for _, line in ipairs(bar._segLines) do line:SetTexture(r, g, b, 0.55) end
	end
	ApplyAccent(AccentRGB())
	ns.accentListeners = ns.accentListeners or {}
	tinsert(ns.accentListeners, ApplyAccent)
	bar._applyAccent = ApplyAccent

	clockText = bar:CreateFontString(nil, "OVERLAY")
	SetClockFont(t.clockSize or 20)   -- must precede SetText
	clockText:SetPoint("CENTER", bar, "CENTER", 0, 0)
	clockText:SetTextColor(1, 1, 1, 1)
	clockText:SetText("--:--")

	local clockBtn = CreateFrame("Button", nil, bar)
	clockBtn:SetSize(80, BarHeight())
	clockBtn:SetPoint("CENTER", clockText, "CENTER", 0, 0)
	clockBtn:SetScript("OnEnter", function(self)
		clockText:SetTextColor(AccentRGB())
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:SetText(date("%A, %B %d"), 1, 1, 1)
		GameTooltip:Show()
	end)
	clockBtn:SetScript("OnLeave", function()
		clockText:SetTextColor(1, 1, 1)
		GameTooltip:Hide()
	end)
	clockBtn:SetScript("OnClick", function()
		if ToggleCalendar then ToggleCalendar() end
	end)
	bar._clockBtn = clockBtn

	-- Resting icon (5.4.8 state icon, pulsing), overlaid on the clock so it never affects width.
	local restFrame = CreateFrame("Frame", nil, bar)
	restFrame:SetSize(14, 14)
	restFrame:SetPoint("CENTER", clockText, "TOPRIGHT", 5, 2)
	restFrame:Hide()
	local restIcon = restFrame:CreateTexture(nil, "OVERLAY")
	restIcon:SetAllPoints()
	restIcon:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
	restIcon:SetTexCoord(0, 0.5, 0, 0.421875)   -- PlayerRestIcon's part of the sheet
	bar._restFrame = restFrame
	do
		local timer = 0
		local function RestOnUpdate(_, elapsed)
			timer = (timer + elapsed) % 2
			local a = timer < 1 and timer or (2 - timer)
			restIcon:SetAlpha(0.45 + 0.55 * a)
		end
		restFrame:SetScript("OnShow", function()
			timer = 0
			restFrame:SetScript("OnUpdate", RestOnUpdate)
		end)
		restFrame:SetScript("OnHide", function() restFrame:SetScript("OnUpdate", nil) end)
	end

	-- Parented to UIParent rather than the bar: Hide In Combat hides the bar,
	-- and a child would go with it. It still anchors to the bar.
	local sysBtn = CreateFrame("Button", nil, UIParent)
	sysBtn:SetSize(120, 14)
	sysBtn:SetFrameStrata("MEDIUM")
	sysBtn:RegisterForClicks("AnyUp")
	local sysText = sysBtn:CreateFontString(nil, "OVERLAY")
	sysText:SetPoint("CENTER")
	SetFontSafe(sysText, GetFont(), t.sysSize or 11, "OUTLINE")
	bar._sysBtn, bar._sysText = sysBtn, sysText

	-- Hooked, so the readout follows whatever hides the bar, including the combat state driver.
	AnchorSystem()
	bar:HookScript("OnShow", AnchorSystem)
	bar:HookScript("OnHide", AnchorSystem)
	sysBtn:SetScript("OnEnter", function(self)
		if not TDB().showSystemTooltip then return end
		ShowSystemTooltip(self)
		self._ttT = 0
		self:SetScript("OnUpdate", function(s, e)
			s._ttT = s._ttT + e
			if s._ttT >= 1 then s._ttT = 0; ShowSystemTooltip(s) end
		end)
	end)
	sysBtn:SetScript("OnLeave", function(self)
		self:SetScript("OnUpdate", nil)
		GameTooltip:Hide()
	end)
	sysBtn:SetScript("OnClick", function(self)
		if IsShiftKeyDown() then collectgarbage("collect") end
		_lastMemScan = 0
		if TDB().showSystemTooltip and self:IsMouseOver() then ShowSystemTooltip(self) end
	end)

	leftGroup  = CreateFrame("Frame", nil, bar)
	rightGroup = CreateFrame("Frame", nil, bar)
	leftGroup:SetHeight(BtnSize())
	rightGroup:SetHeight(BtnSize())

	for _, key in ipairs(LEFT_ORDER)  do CreateElement(key, leftGroup)  end
	for _, key in ipairs(RIGHT_ORDER) do CreateElement(key, rightGroup) end

	-- Unlock Mode can build the bar while it is switched off.
	if not t.enabled and not InCombatLockdown() then
		bar:Hide()
		bar._sysBtn:Hide()
	end

	return bar
end

-- Tied to `enabled`, not to the frame: Unlock Mode can construct a bar the user has switched off.
local ticker = CreateFrame("Frame")
local tickerOn, tickAcc, badgeT = false, 0, 0
local function OnTick()
	if not bar then return end
	-- FPS/MS runs even while the bar is hidden in combat, hence before the IsShown gate.
	UpdateSystemText()
	if not bar:IsShown() then return end
	if PaintClock() or _fitPending then FitBarWidth() end
	badgeT = badgeT + 1
	if badgeT >= 10 then badgeT = 0; UpdateBadges() end
end

local function StartTicker()
	if tickerOn then return end
	tickerOn, tickAcc, badgeT = true, 0, 0
	ticker:SetScript("OnUpdate", function(_, elapsed)
		tickAcc = tickAcc + elapsed
		if tickAcc >= 1 then
			tickAcc = 0
			OnTick()
		end
	end)
end

local function StopTicker()
	if not tickerOn then return end
	tickerOn = false
	ticker:SetScript("OnUpdate", nil)
end

local _pendingApply = false

function TopBar.Apply()
	if not bar then return end
	local t = TDB()

	-- Combat-safe first (textures / fontstrings / non-secure frames only).
	for _, seg in ipairs(bar._segs) do
		seg:SetTexture(0.03, 0.03, 0.04, t.bgAlpha)
	end
	bar._applyAccent()
	SetClockFont(t.clockSize or 20)
	clockText._last = nil   -- force a repaint at the new font/size
	PaintClock()

	local sysSize = t.sysSize or 11
	SetFontSafe(bar._sysText, GetFont(), sysSize, "OUTLINE")
	bar._sysBtn:SetHeight(sysSize + 3)
	_lastFps = nil   -- force a re-measure: the string width moved with the font
	AnchorSystem()
	UpdateSystemText()

	for _, key in ipairs({ "friends", "guild" }) do
		local b = buttons[key]
		if b and b._badge then SetFontSafe(b._badge, GetFont(), 10, "OUTLINE") end
	end
	UpdateBadges()
	ApplyIconColor()

	if t.enabled then StartTicker() else StopTicker() end

	-- Everything below moves the secure child or writes secure attributes: protected in combat.
	if InCombatLockdown() then
		if not _pendingApply then
			_pendingApply = true
			RunOutOfCombat(function()
				_pendingApply = false
				TopBar.Apply()
			end)
		end
		return
	end

	local h = BarHeight()
	bar:SetHeight(h)
	bar._clockBtn:SetHeight(h)
	ApplyBarPosition()   -- re-asserts after a combat-deferred Apply
	ApplyBarVisibility()

	TopBar.ApplyEUIFpsSuppression()

	for _, key in ipairs(LEFT_ORDER)  do WireElement(key) end
	for _, key in ipairs(RIGHT_ORDER) do WireElement(key) end

	local btnSize = BtnSize()
	LayoutGroup(leftGroup,  LEFT_ORDER,  btnSize, t.buttonGap, t.iconSize)
	LayoutGroup(rightGroup, RIGHT_ORDER, btnSize, t.buttonGap, t.iconSize)

	leftGroup:ClearAllPoints()
	leftGroup:SetPoint("LEFT", bar, "LEFT", t.edgeInset, 0)
	rightGroup:ClearAllPoints()
	rightGroup:SetPoint("RIGHT", bar, "RIGHT", -t.edgeInset, 0)

	-- Side pills hug their button groups; the centre pill spans the bar height.
	local SEG_PAD = 6
	bar._segL:ClearAllPoints()
	bar._segL:SetPoint("TOPLEFT",     leftGroup, "TOPLEFT",     -SEG_PAD, 0)
	bar._segL:SetPoint("BOTTOMRIGHT", leftGroup, "BOTTOMRIGHT",  SEG_PAD, 0)
	bar._segR:ClearAllPoints()
	bar._segR:SetPoint("TOPLEFT",     rightGroup, "TOPLEFT",     -SEG_PAD, 0)
	bar._segR:SetPoint("BOTTOMRIGHT", rightGroup, "BOTTOMRIGHT",  SEG_PAD, 0)
	bar._segC:ClearAllPoints()
	bar._segC:SetPoint("LEFT",   clockText, "LEFT",  -(SEG_PAD + 4), 0)
	bar._segC:SetPoint("RIGHT",  clockText, "RIGHT",  (SEG_PAD + 4), 0)
	bar._segC:SetPoint("TOP",    bar, "TOP",    0, 0)
	bar._segC:SetPoint("BOTTOM", bar, "BOTTOM", 0, 0)

	local rs = max(12, floor(h * 0.55 + 0.5))
	bar._restFrame:SetSize(rs, rs)

	FitBarWidth()
	UpdateResting()
end

-------------------------------------------------------------------------------
--  EllesmereUI FPS suppression (5.4.8: the Minimap's FPS / MS text)
-------------------------------------------------------------------------------
-- The previous value is kept in t._mmFpsPrev so it can be handed back.
local function ApplyEUIFpsSuppression()
	local EMM = ns.EMM
	local mm = EMM and EMM.DB and EMM.DB()
	if type(mm) ~= "table" then return end
	local t = TDB()
	local on = t.enabled and t.hideEUIFps
	local changed = false

	if on then
		if t._mmFpsPrev == nil then
			t._mmFpsPrev = mm.showFPS and true or false
		end
		if mm.showFPS then
			mm.showFPS = false
			changed = true
		end
	elseif t._mmFpsPrev ~= nil then
		if (mm.showFPS and true or false) ~= t._mmFpsPrev then
			mm.showFPS = t._mmFpsPrev
			changed = true
		end
		t._mmFpsPrev = nil
	end

	if changed and EMM.ApplyAll then pcall(EMM.ApplyAll) end
end
TopBar.ApplyEUIFpsSuppression = ApplyEUIFpsSuppression

function TopBar.SetEnabled(v)
	TDB().enabled = v and true or false
	if TDB().enabled and not bar then TopBar.Create() end   -- built lazily; see Boot
	TopBar.Apply()
end

-- Every settings change (the settings window runs ns.applyHooks).
ns.applyHooks = ns.applyHooks or {}
tinsert(ns.applyHooks, function()
	if not db then return end
	if TDB().enabled and not bar then TopBar.Create() end
	if bar then TopBar.Apply() end
end)

-------------------------------------------------------------------------------
--  Unlock Mode
-------------------------------------------------------------------------------
local function RegisterUnlock()
	if not (ns.RegisterUnlockElements and ns.MakeUnlockElement) then return end
	ns:RegisterUnlockElements({
		ns.MakeUnlockElement({
			key   = "EUI_TopBar",
			label = "Top Bar",
			group = "Top Bar",
			order = 1,
			-- The bar auto-fits, so a resize handle would be overwritten by the next Apply.
			noResize = true,
			isHidden = function() return not TDB().enabled end,
			getFrame = function() return bar or TopBar.Create() end,
			getSize  = function()
				if not bar then return 360, BarHeight() end
				return bar:GetWidth(), bar:GetHeight()
			end,
			savePos = function(_, point, relPoint, x, y)
				TDB().pos = { point = point, relPoint = relPoint, x = x, y = y }
			end,
			loadPos = function()
				local p = TDB().pos
				if not p then return nil end
				return { point = p.point, relPoint = p.relPoint, x = p.x, y = p.y }
			end,
			clearPos = function() TDB().pos = nil end,
			applyPos = function() ApplyBarPosition() end,
		}),
	}, addonName)
end

-- Hands the Minimap FPS text back first, then defaults + the Naowh preset.
function TopBar.Reset()
	local t = TDB()
	if t._mmFpsPrev ~= nil then
		t.hideEUIFps = false
		ApplyEUIFpsSuppression()
	end
	-- NaowhUI QoL (own settings page) keeps its table.
	local qol = t.qol
	wipe(t)
	t.qol = qol
	TDB()
	SeedNaowh(t)
	if not bar then TopBar.Create() end
	TopBar.Apply()
end

-------------------------------------------------------------------------------
--  Boot
-------------------------------------------------------------------------------
local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:RegisterEvent("PLAYER_UPDATE_RESTING")
boot:RegisterEvent("FRIENDLIST_UPDATE")
boot:RegisterEvent("BN_FRIEND_INFO_CHANGED")
boot:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE")
boot:RegisterEvent("BN_FRIEND_ACCOUNT_OFFLINE")
boot:RegisterEvent("GUILD_ROSTER_UPDATE")
boot:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == addonName then
			self:UnregisterEvent("ADDON_LOADED")
			local t = TDB()
			if t._seeded ~= 1 then SeedNaowh(t) end
			RegisterUnlock()
		end
		return
	end
	if not db then return end
	if event == "PLAYER_UPDATE_RESTING" then
		UpdateResting()
		return
	end
	if event == "FRIENDLIST_UPDATE" or event == "GUILD_ROSTER_UPDATE" or event:find("^BN_") then
		UpdateBadges()
		return
	end

	-- Lazy: an unused bar costs no frames, no secure button and no ticker.
	if bar or TDB().enabled then
		if not bar then TopBar.Create() end
		TopBar.Apply()
	end
end)
