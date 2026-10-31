-------------------------------------------------------------------------------
--  EllesmereUIBlizzardSkin_MailAlts.lua (5.4.8 port of retail
--  EllesmereUIBlizzardSkin_MailAlts.lua)
--  The Mail card's Alt List (opt-in, EllesmereUIDB.mailAltList): beside the
--  Send Mail page, the player's other characters of the same faction on this
--  realm (or a connected one). A click puts the name in the To: box; a
--  right click hides the character until it is ticked again in Shown
--  Characters on the Mail card.
--  Settings (account wide, EllesmereUIDB): mailAltList, mailAltHidden (by
--  player GUID), mailAltListSort ("recent" / "level" / "name"),
--  mailAltListMax, mailAltListMinLevel.
--  The roster, EllesmereUIDB.mailAltRoster (by player GUID), is written at
--  every login and logout even while the list is off, so every character
--  played since is listed the first time the list is turned on.
--  5.4.8: no Warbound items, so characters on other realms or of the other
--  faction (who cannot take mail) are left out instead of shown dimmed; the
--  row tooltip is the GameTooltip; the right-click menu is one action.
-------------------------------------------------------------------------------
local ns = EllesmereUI
local BS = ns.BlizzSkin
local WSkin = ns.WSkin
if not (BS and WSkin) then
	return
end

local Theme = WSkin.Theme
local wipe, sort, floor, max, min = wipe, table.sort, math.floor, math.max, math.min

local DEFAULT_MAX, DEFAULT_MIN_LEVEL, DEFAULT_SORT = 10, 1, "recent"
local MAX_ROWS = 20 -- the Max Characters Shown slider's top
local PANEL_W = 170
local ROW_H = 22
local ICON_SIZE = 16
local TOP_H = 25
local INSET = 1
local GAP = 4
local LIST_PAD = 4
local EMPTY_PAD = 10
local CLASS_ICONS = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"

local ev = CreateFrame("Frame")
local panel, title, emptyNote
local rows = {}
local dirty = true
local hooked = false
local myGuid
local connected
local shown = {}
local mailable = 0
local sortRoster
local placedTo, placedSide

-------------------------------------------------------------------------------
--  Settings and the roster
-------------------------------------------------------------------------------
local function Enabled()
	return EllesmereUIDB and EllesmereUIDB.mailAltList == true
end

local function Setting(key, default)
	local v = EllesmereUIDB and EllesmereUIDB[key]
	if v == nil then return default end
	return v
end

local function NumberSetting(key, default)
	local v = tonumber(Setting(key, default))
	return v and floor(v) or default
end

local function Roster()
	local db = EllesmereUIDB
	if type(db) ~= "table" then return nil end
	local r = db.mailAltRoster
	if type(r) ~= "table" then
		r = {}
		db.mailAltRoster = r
	end
	return r
end

local function Hidden()
	local h = EllesmereUIDB and EllesmereUIDB.mailAltHidden
	return type(h) == "table" and h or nil
end

local function RealmKey(realm)
	return (realm or ""):gsub("[%s%-]", "")
end

-- This character as the roster keeps it. An unknown level keeps the stored one.
local function RecordPlayer()
	local guid = UnitGUID("player")
	if guid then myGuid = guid end
	local name = UnitName("player")
	local realm = GetRealmName()
	local _, class = UnitClass("player")
	if not (guid and name and realm and class) then return end
	local roster = Roster()
	if not roster then return end
	local e = roster[guid]
	if type(e) ~= "table" then
		e = {}
		roster[guid] = e
	end
	e.name, e.realm, e.realmKey, e.class = name, realm, RealmKey(realm), class
	local level = UnitLevel("player")
	if type(level) == "number" and level > 0 then e.level = level end
	local faction = UnitFactionGroup("player")
	if faction then e.faction = faction end
	e.seen = time()
	dirty = true
end

-- "Level 90 Mage, Horde": the hover line of a row and of Shown Characters.
local function Describe(e)
	local class = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[e.class]) or e.class or ""
	local text = e.level and format(UNIT_TYPE_LEVEL_TEMPLATE or "Level %d %s", e.level, class) or class
	local faction = e.faction and _G["FACTION_" .. e.faction:upper()]
	if faction then text = text .. ", " .. faction end
	return text
end

-------------------------------------------------------------------------------
--  Who the list shows: the same faction on this realm or a connected one,
--  minus Shown Characters and Minimum Level.
-------------------------------------------------------------------------------
local function ConnectedRealms()
	if connected then return connected end
	local set = { [RealmKey(GetRealmName())] = true }
	if GetAutoCompleteRealms then
		local list = { GetAutoCompleteRealms() }
		if type(list[1]) == "table" then list = list[1] end
		for i = 1, #list do
			if type(list[i]) == "string" then set[RealmKey(list[i])] = true end
		end
	end
	connected = set
	return set
end

local function ByName(a, b)
	local ea, eb = sortRoster[a], sortRoster[b]
	if ea.name ~= eb.name then return ea.name:lower() < eb.name:lower() end
	if ea.realmKey ~= eb.realmKey then return ea.realmKey < eb.realmKey end
	return a < b
end
local function ByLevel(a, b)
	local la, lb = sortRoster[a].level or 0, sortRoster[b].level or 0
	if la ~= lb then return la > lb end
	return ByName(a, b)
end
local function ByRecent(a, b)
	local sa, sb = sortRoster[a].seen or 0, sortRoster[b].seen or 0
	if sa ~= sb then return sa > sb end
	return ByName(a, b)
end
local SORTS = { recent = ByRecent, level = ByLevel, name = ByName }

local function Collect()
	wipe(shown)
	mailable = 0
	local roster = Roster()
	local faction = UnitFactionGroup("player")
	if not roster or not faction or faction == "Neutral" then return end
	local me = myGuid or UnitGUID("player")
	local hidden = Hidden()
	local minLevel = NumberSetting("mailAltListMinLevel", DEFAULT_MIN_LEVEL)
	local realms = ConnectedRealms()
	for guid, e in pairs(roster) do
		if guid ~= me and type(e) == "table" and type(e.name) == "string" and e.realmKey
			and e.faction == faction and realms[e.realmKey] then
			mailable = mailable + 1
			if not (hidden and hidden[guid]) and (e.level or 0) >= minLevel then
				shown[#shown + 1] = guid
			end
		end
	end
	sortRoster = roster
	sort(shown, SORTS[Setting("mailAltListSort", DEFAULT_SORT)] or ByRecent)
	sortRoster = nil
	local cap = max(1, min(MAX_ROWS, NumberSetting("mailAltListMax", DEFAULT_MAX)))
	for i = #shown, cap + 1, -1 do shown[i] = nil end
end

-------------------------------------------------------------------------------
--  Rows
-------------------------------------------------------------------------------
local Paint, Place

local function Font(fs, size, r, g, b)
	fs:SetFont(Theme.fontPath or STANDARD_TEXT_FONT, size, Theme.fontFlag or "")
	if Theme.fontShadow then
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 1)
	else
		fs:SetShadowOffset(0, 0)
	end
	if r then fs:SetTextColor(r, g, b) end
end

local function ClassColor(class)
	local c = (ns.GetClassColor and ns.GetClassColor(class)) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

local function RowEnter(self)
	local roster = Roster()
	local e = self._guid and roster and roster[self._guid]
	if type(e) ~= "table" then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	local r, g, b = ClassColor(e.class)
	local head = e.name
	if self._foreign then head = head .. " - " .. (e.realm or e.realmKey) end
	GameTooltip:AddLine(head, r, g, b)
	GameTooltip:AddLine(Describe(e), 1, 1, 1)
	GameTooltip:AddLine("Click to mail, right-click to hide.", 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

local function RowLeave(self)
	if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end

local function SetShown(guid, on)
	if not EllesmereUIDB then return end
	local h = EllesmereUIDB.mailAltHidden
	if on then
		if type(h) == "table" then
			h[guid] = nil
			if not next(h) then EllesmereUIDB.mailAltHidden = nil end
		end
	else
		if type(h) ~= "table" then
			h = {}
			EllesmereUIDB.mailAltHidden = h
		end
		h[guid] = true
	end
	dirty = true
end

local function RowClick(self, button)
	if not self._guid then return end
	if button == "RightButton" then
		SetShown(self._guid, false)
		GameTooltip:Hide()
		Paint()
		Place()
		return
	end
	local box = SendMailNameEditBox
	if box and self._target then box:SetText(self._target) end
end

local function NewRow(i)
	local r = CreateFrame("Button", nil, panel)
	r:SetHeight(ROW_H)
	r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local hl = r:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetTexture(1, 1, 1, 0.08)
	local icon = r:CreateTexture(nil, "ARTWORK")
	icon:SetSize(ICON_SIZE, ICON_SIZE)
	icon:SetPoint("LEFT", r, "LEFT", 6, 0)
	local lvl = r:CreateFontString(nil, "OVERLAY")
	local name = r:CreateFontString(nil, "OVERLAY")
	Font(lvl, 11, 0.6, 0.6, 0.6)
	Font(name, 12)
	lvl:SetPoint("RIGHT", r, "RIGHT", -6, 0)
	lvl:SetJustifyH("RIGHT")
	name:SetPoint("LEFT", icon, "RIGHT", 5, 0)
	name:SetPoint("RIGHT", lvl, "LEFT", -4, 0)
	name:SetJustifyH("LEFT")
	name:SetWordWrap(false)
	r._icon, r._name, r._lvl = icon, name, lvl
	r:SetScript("OnClick", RowClick)
	r:SetScript("OnEnter", RowEnter)
	r:SetScript("OnLeave", RowLeave)
	r:SetPoint("TOPLEFT", panel, "TOPLEFT", INSET, -(TOP_H + LIST_PAD + (i - 1) * ROW_H))
	r:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -INSET, -(TOP_H + LIST_PAD + (i - 1) * ROW_H))
	rows[i] = r
	return r
end

local function DressIcon(tex, class)
	local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
	if coords then
		tex:SetTexture(CLASS_ICONS)
		tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		tex:Show()
	else
		tex:Hide()
	end
end

-------------------------------------------------------------------------------
--  The panel: the mail window's own shell (EllesmereUI / Modern follow the
--  Mail style), a dark box while the mail skin is off.
-------------------------------------------------------------------------------
local function Build()
	if not Theme.fontPath and WSkin.ResolveTheme then WSkin.ResolveTheme() end
	panel = CreateFrame("Frame", "EllesmereUIMailAltList", SendMailFrame)
	panel:SetWidth(PANEL_W)
	panel:SetHeight(100)
	panel:SetClampedToScreen(true)
	panel:SetFrameStrata(SendMailFrame:GetFrameStrata())
	-- It hangs outside the window: a click on its empty parts stays off the world.
	panel:EnableMouse(true)
	if WSkin.GetStyle("mail") == "off" then
		local bg = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
		bg:SetAllPoints()
		bg:SetTexture(0.05, 0.05, 0.05, 0.92)
		local band = panel:CreateTexture(nil, "BACKGROUND", nil, -5)
		band:SetTexture(0, 0, 0, 0.5)
		band:SetPoint("TOPLEFT")
		band:SetPoint("TOPRIGHT")
		band:SetHeight(TOP_H)
		WSkin.AddBorder(panel)
	else
		WSkin.Shell("mail", panel)
	end
	title = panel:CreateFontString(nil, "OVERLAY")
	Font(title, 12, 1, 1, 1)
	title:SetPoint("TOP", panel, "TOP", 0, -(TOP_H - 12) / 2 - 1)
	title:SetText("Alts")
	emptyNote = panel:CreateFontString(nil, "OVERLAY")
	Font(emptyNote, 11, 0.6, 0.6, 0.6)
	emptyNote:SetWidth(PANEL_W - EMPTY_PAD * 2)
	emptyNote:SetPoint("TOP", panel, "TOP", 0, -(TOP_H + EMPTY_PAD))
	emptyNote:SetJustifyH("CENTER")
	emptyNote:SetSpacing(2)
end

Paint = function()
	dirty = false
	Collect()
	local roster = Roster()
	local own = RealmKey(GetRealmName())
	local n = #shown
	for i = 1, n do
		local guid = shown[i]
		local e = roster[guid]
		local r = rows[i] or NewRow(i)
		local foreign = e.realmKey ~= own
		r._guid, r._foreign = guid, foreign
		-- Mail addresses a connected realm's character as "Name-Realm".
		r._target = foreign and (e.name .. "-" .. e.realmKey) or e.name
		DressIcon(r._icon, e.class)
		r._name:SetText(foreign and (e.name .. (FOREIGN_SERVER_LABEL or " (*)")) or e.name)
		r._name:SetTextColor(ClassColor(e.class))
		r._lvl:SetText(e.level or "")
		r:Show()
	end
	for i = n + 1, #rows do
		local r = rows[i]
		if GameTooltip:IsOwned(r) then GameTooltip:Hide() end
		r:Hide()
		r._guid, r._target = nil, nil
	end
	local h
	if n > 0 then
		emptyNote:Hide()
		h = TOP_H + LIST_PAD * 2 + n * ROW_H
	else
		emptyNote:SetText(mailable == 0
			and "Log into your other characters to list them here."
			or "Your other characters are hidden by Shown Characters or Minimum Level.")
		emptyNote:Show()
		h = TOP_H + EMPTY_PAD * 2 + math.ceil(emptyNote:GetStringHeight())
	end
	panel:SetHeight(h)
end

local function ScreenRect(f)
	local s = f:GetEffectiveScale()
	local l, r, t, b = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
	if not (l and r and t and b) then return nil end
	return l * s, r * s, t * s, b * s
end

local function Anchor(to, side)
	if placedTo == to and placedSide == side then return end
	placedTo, placedSide = to, side
	panel:ClearAllPoints()
	if side == "left" then
		panel:SetPoint("TOPRIGHT", to, "TOPLEFT", -GAP, 0)
	else
		panel:SetPoint("TOPLEFT", to, "TOPRIGHT", GAP, 0)
	end
end

-- Beside the mail window; past an open letter it would cover; on the window's
-- left when the screen has no room on its right.
Place = function()
	local mf, letter = MailFrame, OpenMailFrame
	local to, side = mf, "right"
	local ml, mr, mt = ScreenRect(mf)
	if mr then
		local s = panel:GetEffectiveScale()
		local w, h, g = PANEL_W * s, panel:GetHeight() * s, GAP * s
		local left = mr + g
		if letter and letter:IsShown() then
			local ll, lr, lt, lb = ScreenRect(letter)
			if ll and left < lr and left + w > ll and mt - h < lt and mt > lb then
				to, left = letter, lr + g
			end
		end
		local screen = UIParent:GetRight() * UIParent:GetEffectiveScale()
		if left + w > screen and ml - g - w >= 0 then
			to, side = mf, "left"
		end
	end
	Anchor(to, side)
end

-- Shown before the paint: a font string measures its height only while visible.
local function ShowPanel()
	if not panel then Build() end
	panel:Show()
	if dirty then Paint() end
	Place()
end

-------------------------------------------------------------------------------
--  Hooks: tab switches (Reply included), the letter window, the mailbox
-------------------------------------------------------------------------------
local function OnTab()
	if not Enabled() or not (SendMailFrame and SendMailFrame:IsVisible()) then return end
	ShowPanel()
end

local function OnInboxUpdate()
	if panel and panel:IsVisible() and Enabled() then Place() end
end

local function Install()
	if hooked then return end
	if type(MailFrameTab_OnClick) ~= "function" or not SendMailFrame then return end
	hooked = true
	hooksecurefunc("MailFrameTab_OnClick", OnTab)
	if type(InboxFrame_Update) == "function" then
		hooksecurefunc("InboxFrame_Update", OnInboxUpdate)
	end
	if OpenMailFrame then
		OpenMailFrame:HookScript("OnShow", OnInboxUpdate)
		OpenMailFrame:HookScript("OnHide", OnInboxUpdate)
	end
end

-------------------------------------------------------------------------------
--  The Mail card's options (WindowPacks1 mail options)
-------------------------------------------------------------------------------
local MA = {
	DEFAULT_MAX = DEFAULT_MAX, DEFAULT_MIN_LEVEL = DEFAULT_MIN_LEVEL,
	DEFAULT_SORT = DEFAULT_SORT, MAX_ROWS = MAX_ROWS,
	Describe = Describe,
}
BS.MailAlts = MA

-- A setting changed: the hooks on the first enable, the open Send Mail page
-- repainted, the panel put away when turned off.
function MA.Refresh()
	dirty = true
	if Enabled() then
		Install()
		if hooked and SendMailFrame and SendMailFrame:IsVisible() then ShowPanel() end
	elseif panel then
		panel:Hide()
	end
end

-- Every recorded character, for Shown Characters: this realm first, then by
-- name. A fresh list per call.
function MA.Entries()
	local out = {}
	local roster = Roster()
	if not roster then return out end
	for guid, e in pairs(roster) do
		if type(e) == "table" and type(e.name) == "string" and guid ~= myGuid then
			out[#out + 1] = { guid = guid, name = e.name, realm = e.realm or e.realmKey or "",
				class = e.class, level = e.level, faction = e.faction }
		end
	end
	local own = GetRealmName()
	sort(out, function(a, b)
		if a.realm ~= b.realm then
			if a.realm == own then return true end
			if b.realm == own then return false end
			return a.realm < b.realm
		end
		if a.name ~= b.name then return a.name:lower() < b.name:lower() end
		return a.guid < b.guid
	end)
	return out
end

function MA.IsShown(guid)
	local h = Hidden()
	return not (h and h[guid])
end

function MA.SetShown(guid, on)
	SetShown(guid, on)
	if panel and panel:IsVisible() then
		Paint()
		Place()
	end
end

-- Forgets a deleted or moved character (it comes back at its next login).
function MA.Remove(guid)
	local roster = Roster()
	if roster then roster[guid] = nil end
	SetShown(guid, true)
	if panel and panel:IsVisible() then
		Paint()
		Place()
	end
end

-------------------------------------------------------------------------------
--  Boot: the roster at login and logout; the hooks once the list is on
-------------------------------------------------------------------------------
ev:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		self:UnregisterEvent("PLAYER_LOGIN")
		RecordPlayer()
		if Enabled() then Install() end
	elseif event == "PLAYER_LOGOUT" then
		RecordPlayer()
	end
end)
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_LOGOUT")
