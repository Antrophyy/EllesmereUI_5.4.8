-------------------------------------------------------------------------------
--  EllesmereUIFriends.lua (5.4.8 port of retail EllesmereUIFriends 9.4 and the
--  friends parts of EllesmereUI_FriendsKit.lua)
--
--  Retail decorates Blizzard's own friends rows (no custom list, no friend
--  groups: retail removed them). This port does the same on the 5.4.8 list
--  (FriendsFrameFriendsScrollFrame, a HybridScrollFrame):
--    * class icon per row (Class Icon Theme), the game icon for other games,
--      the offline icon for offline friends;
--    * class colored names (WoW friends: whole name, Battle.net: "(toon)");
--    * faction banner behind each row (Enable Faction Banners);
--    * status orb (online / AFK / DND / offline) after the name, replacing
--      Blizzard's status icon;
--    * the friend note appended to the info line;
--    * tile wash, hover bar, house font (font key "friends");
--    * auto-accept group invites from friends (and guildmates);
--    * Border Size / Border Color: only while the Blizzard Skins+ "Friends
--      List" window skin is off (retail: only this module's own flat look);
--    * Enable Accent Colors: accent labels on the list's bottom buttons while
--      the Blizzard Skins+ window skin draws them.
--  Only decoration: Blizzard keeps the rows, the click handler, the
--  right-click menus (FriendsFrame_ShowDropdown / _ShowBNDropdown), whisper
--  and invite. No SetScript on Blizzard frames (hooksecurefunc / HookScript).
--  Skipped (no 5.4.8 counterpart): region icons (no GetCurrentRegion, no
--  retail realm list on this client), 12.1 Social UI tiles, the Raid tab and
--  window chrome skin (Blizzard Skins+ draws the window here).
-------------------------------------------------------------------------------
local addonName = ...
local ns = EllesmereUI

local FR = {}
ns.Friends = FR

local FONT_KEY = "friends"
local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\media\\"
local OFFLINE_ICON = MEDIA .. "offline"
local ORB_TEX = MEDIA .. "status-orb"
local FACTION_TEX = {
	Alliance = MEDIA .. "alliance",
	Horde = MEDIA .. "horde",
	Neutral = MEDIA .. "neutral",
}

-- 5.4.8 FriendsFrame.lua button types
local TYPE_BNET = FRIENDS_BUTTON_TYPE_BNET or 2
local TYPE_WOW = FRIENDS_BUTTON_TYPE_WOW or 3

-------------------------------------------------------------------------------
--  Defaults / DB (EllesmereUIFriendsDB = retail profile.addons.EllesmereUIFriends:
--  { friends = { ... } })
-------------------------------------------------------------------------------
local DEFAULTS = {
	enabled = true,
	scale = 1,
	bgR = 0.05, bgG = 0.05, bgB = 0.055, bgAlpha = 1,
	tileR = 0, tileG = 0, tileB = 0, tileAlpha = 0.35,
	showBorder = true,
	borderSize = 1,
	borderR = 0, borderG = 0, borderB = 0, borderA = 1,
	useClassColor = false,
	useAccentTab = true,
	showClassIcons = true,
	iconStyle = "modern",
	classColorNames = true,
	nameColorR = 0.863, nameColorG = 0.820, nameColorB = 0.565,
	accentColors = true,
	factionBanners = false,
	showRegionIcons = true,
	useBlizzardStyle = false,
	useClassicStyle = false,
	autoAcceptFriendInvites = false,
	autoAcceptGuildInvites = false,
	showOffline = true,
	visibility = "always",
	visOnlyInstances = false,
	visHideHousing = false,
	visHideMounted = false,
	visHideNoTarget = false,
	visHideNoEnemy = false,
}
FR.DEFAULTS = DEFAULTS

local function Root()
	return ns.ModuleDB("EllesmereUIFriendsDB")
end

-- The friends settings table (defaults filled in).
local function F()
	local root = Root()
	local f = root.friends
	if type(f) ~= "table" then
		f = {}
		root.friends = f
	end
	for k, v in pairs(DEFAULTS) do
		if f[k] == nil then f[k] = v end
	end
	return f
end
FR.DB = F

-- First login: the user's retail "Naowh" values.
local function SeedNaowh(root)
	local f = root.friends
	if type(f) ~= "table" then
		f = {}
		root.friends = f
	end
	f.borderSize = 0
	f.autoAcceptFriendInvites = true
	f.factionBanners = true
	f.useAccentTab = false
	f.autoAcceptGuildInvites = true
	root._seeded = 1
end

-------------------------------------------------------------------------------
--  Small helpers (5.4.8 has no C_Timer)
-------------------------------------------------------------------------------
local timerFrame = CreateFrame("Frame")
local timers = {}
timerFrame:Hide()
timerFrame:SetScript("OnUpdate", function(self, elapsed)
	local now = GetTime()
	local i = 1
	while i <= #timers do
		local t = timers[i]
		if now >= t.at then
			table.remove(timers, i)
			local ok, err = pcall(t.fn)
			if not ok then geterrorhandler()(err) end
		else
			i = i + 1
		end
	end
	if #timers == 0 then self:Hide() end
end)
local function After(delay, fn)
	timers[#timers + 1] = { at = GetTime() + (delay or 0), fn = fn }
	timerFrame:Show()
end
FR.After = After

-- Weak-keyed state per Blizzard frame (no custom keys on Blizzard frames).
local FFD = setmetatable({}, { __mode = "k" })
local function GetFFD(frame)
	local d = FFD[frame]
	if not d then
		d = {}
		FFD[frame] = d
	end
	return d
end

local function StripRealm(name)
	if type(name) ~= "string" then return nil end
	return (name:match("^([^%-]+)") or name):lower()
end

local function Hex(r, g, b)
	return string.format("|cff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function Accent()
	if ns.ResolveAccent then return ns.ResolveAccent() end
	return 0.05, 0.82, 0.62
end

-------------------------------------------------------------------------------
--  Class lookups
-------------------------------------------------------------------------------
-- Class Icon Theme: the choices the settings page lists (retail FriendsKit).
FR.ICON_STYLE_VALUES = {
	blizzard = "Blizzard",
	modern = "Modern",
	pixel = "Pixel",
	pixelsComic = "Pixels Comic",
	glyph = "Glyph",
	arcade = "Arcade",
	legend = "Legend",
	midnight = "Midnight",
	runic = "Runic",
}
FR.ICON_STYLE_ORDER = {
	"blizzard", "modern", "pixel", "pixelsComic", "glyph",
	"arcade", "legend", "midnight", "runic",
}

-- class-full sprite sheets (EllesmereUI CLASS_ICON_SPRITE_COORDS)
local SPRITE = {
	WARRIOR = { 0, 0.125, 0, 0.125 }, MAGE = { 0.125, 0.25, 0, 0.125 }, ROGUE = { 0.25, 0.375, 0, 0.125 },
	DRUID = { 0.375, 0.5, 0, 0.125 }, HUNTER = { 0, 0.125, 0.125, 0.25 }, SHAMAN = { 0.125, 0.25, 0.125, 0.25 },
	PRIEST = { 0.25, 0.375, 0.125, 0.25 }, WARLOCK = { 0.375, 0.5, 0.125, 0.25 }, PALADIN = { 0, 0.125, 0.25, 0.375 },
	DEATHKNIGHT = { 0.125, 0.25, 0.25, 0.375 }, MONK = { 0.25, 0.375, 0.25, 0.375 },
}
-- Blizzard style: the character-create class sheet (CLASS_ICON_TCOORDS).
local BLIZZ_CLASS_TEX = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local BLIZZ_COORDS = {
	WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.49609375, 0, 0.25 },
	ROGUE = { 0.49609375, 0.7421875, 0, 0.25 }, DRUID = { 0.7421875, 0.98828125, 0, 0.25 },
	HUNTER = { 0, 0.25, 0.25, 0.5 }, SHAMAN = { 0.25, 0.49609375, 0.25, 0.5 },
	PRIEST = { 0.49609375, 0.7421875, 0.25, 0.5 }, WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 },
	PALADIN = { 0, 0.25, 0.5, 0.75 }, DEATHKNIGHT = { 0.25, 0.49609375, 0.5, 0.75 },
	MONK = { 0.49609375, 0.7421875, 0.5, 0.75 },
}

local function ClassIconSprite(style)
	if not FR.ICON_STYLE_VALUES[style or ""] or style == "blizzard" then
		style = "modern"
	end
	return "Interface\\AddOns\\EllesmereUI\\media\\class\\" .. style -- shared class sheets (core media)
end

-- Localized class name -> class file (male and female names).
local classByName
local function ClassToken(name)
	if type(name) ~= "string" or name == "" then return nil end
	if not classByName then
		classByName = {}
		if GetNumClasses and GetClassInfo then
			for i = 1, GetNumClasses() do
				local loc, token = GetClassInfo(i)
				if loc and token then classByName[loc] = token end
			end
		end
		for _, list in ipairs({ LOCALIZED_CLASS_NAMES_MALE, LOCALIZED_CLASS_NAMES_FEMALE }) do
			if type(list) == "table" then
				for token, loc in pairs(list) do classByName[loc] = token end
			end
		end
	end
	local token = classByName[name]
	if token then return token end
	-- English names / tokens ("Death Knight" -> DEATHKNIGHT)
	local guess = name:upper():gsub("%s+", "")
	if RAID_CLASS_COLORS and RAID_CLASS_COLORS[guess] then return guess end
	return nil
end
FR.ClassToken = ClassToken

local function ClassColor(token)
	local c = token and ((CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[token]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]))
	if c then return c.r, c.g, c.b end
end

-------------------------------------------------------------------------------
--  Window chrome: who draws the frame
-------------------------------------------------------------------------------
-- True while the Blizzard Skins+ "Friends List" window skin draws the window
-- (retail: a Window Skins style other than Blizz Default).
function FR.ChromeShell()
	local BS = ns.BlizzSkin
	if not (BS and BS.GetWindowStyle) then return false end
	local ok, style = pcall(BS.GetWindowStyle, "socialui")
	return ok and style ~= "off"
end

-------------------------------------------------------------------------------
--  Friend data of a row (5.4.8 GetFriendInfo / BNGetFriendInfo / BNGetToonInfo)
-------------------------------------------------------------------------------
local info = {}
local function ReadFriend(button)
	wipe(info)
	local bt, id = button.buttonType, button.id
	if not id then return nil end
	if bt == TYPE_WOW then
		local name, level, class, area, connected, status, note = GetFriendInfo(id)
		if not name then return nil end
		info.kind = "wow"
		info.online = connected and true or false
		info.state = connected and "wow" or "offline"
		info.classFile = ClassToken(class)
		info.faction = UnitFactionGroup("player")
		info.afk = status == CHAT_FLAG_AFK
		info.dnd = status == CHAT_FLAG_DND
		info.note = note
		return info
	elseif bt == TYPE_BNET then
		local presenceID, presenceName, battleTag, isBTag, toonName, toonID, client, isOnline, lastOnline, isAFK, isDND, messageText, noteText = BNGetFriendInfo(id)
		if not presenceID then return nil end
		info.kind = "bnet"
		info.online = isOnline and true or false
		info.afk = isAFK and true or false
		info.dnd = isDND and true or false
		info.note = noteText
		if isOnline then
			if client == (BNET_CLIENT_WOW or "WoW") then
				info.state = "wow"
				if toonID and BNGetToonInfo then
					local _, _, _, _, _, faction, _, class = BNGetToonInfo(toonID)
					info.faction = faction
					info.classFile = ClassToken(class)
				end
			else
				info.state = "other"
			end
		else
			info.state = "offline"
		end
		return info
	end
	return nil
end

-------------------------------------------------------------------------------
--  Row decoration
-------------------------------------------------------------------------------
local function ApplyFont(fs, size)
	if fs and fs.SetFont then ns.ApplyModuleFont(fs, size, FONT_KEY) end
end

-- One-time parts of a row (retail SkinFriendButton).
local function SkinRow(button, d)
	if d.skinned then return end
	d.skinned = true

	d.tileBg = button:CreateTexture(nil, "BACKGROUND", nil, 2)
	d.tileBg:SetAllPoints()
	d.tileBg:SetTexture(0, 0, 0, 0.10)

	d.factionBg = button:CreateTexture(nil, "BACKGROUND", nil, 3)
	d.factionBg:SetAllPoints()
	d.factionBg:SetAlpha(0.2)

	-- Hover bar (retail: the groupfinder highlight atlas, tinted blue).
	local hover = button:CreateTexture(nil, "ARTWORK", nil, -7)
	hover:SetAllPoints()
	hover:SetTexture(1, 1, 1, 1)
	hover:SetGradientAlpha("HORIZONTAL", 0.4, 0.7, 1, 0.25, 0.4, 0.7, 1, 0)
	hover:Hide()
	local hoverFill = button:CreateTexture(nil, "ARTWORK", nil, -8)
	hoverFill:SetAllPoints()
	hoverFill:SetTexture(1, 1, 1, 0.02)
	hoverFill:SetBlendMode("ADD")
	hoverFill:Hide()
	button:HookScript("OnEnter", function() hover:Show(); hoverFill:Show() end)
	button:HookScript("OnLeave", function() hover:Hide(); hoverFill:Hide() end)

	d.classIcon = button:CreateTexture(nil, "ARTWORK", nil, 2)
	d.orb = button:CreateTexture(nil, "OVERLAY", nil, 3)
	d.orb:SetSize(18, 18)
	d.orb:SetTexture(ORB_TEX)

	-- Name moves right for the class icon; info sits under the name.
	local name, infoFS = button.name, button.info
	if name then
		local p1, rel, p2, x, y = name:GetPoint(1)
		if p1 then
			name:SetPoint(p1, rel, p2, (x or 0) + 20, y or 0)
		end
	end
	if infoFS and name then
		infoFS:ClearAllPoints()
		infoFS:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
	end
end

local function HideParts(d)
	if not d.skinned then return end
	d.classIcon:Hide()
	d.orb:Hide()
	d.factionBg:Hide()
end

local function UpdateClassIcon(button, d, p, fi)
	local icon = d.classIcon
	if button.gameIcon then button.gameIcon:SetAlpha(0) end
	if not p.showClassIcons then
		icon:Hide()
		return
	end
	local h = (button:GetHeight() or 34) - 4
	if h <= 0 then
		icon:Hide()
		return
	end
	icon:ClearAllPoints()
	if fi.state == "wow" then
		local inset = math.floor(h * 0.025 + 0.5)
		local iconH = h - inset * 2
		icon:SetPoint("LEFT", button, "LEFT", 4, 0)
		icon:SetSize(iconH, iconH)
		local cf = fi.classFile
		if not cf then
			icon:Hide()
			return
		end
		local style = p.iconStyle or "modern"
		local c
		if style == "blizzard" then
			c = (CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[cf]) or BLIZZ_COORDS[cf]
			icon:SetTexture(BLIZZ_CLASS_TEX)
		else
			c = SPRITE[cf]
			icon:SetTexture(ClassIconSprite(style))
		end
		if not c then
			icon:Hide()
			return
		end
		icon:SetTexCoord(c[1], c[2], c[3], c[4])
		icon:SetAlpha(1)
	else
		local smallH = math.floor(h * 0.75)
		icon:SetSize(smallH, smallH)
		icon:SetPoint("LEFT", button, "LEFT", 4 + math.floor((h - smallH) / 2), 0)
		icon:SetTexCoord(0, 1, 0, 1)
		if fi.state == "other" then
			local tex = button.gameIcon and button.gameIcon:GetTexture()
			if not tex then
				icon:Hide()
				return
			end
			icon:SetTexture(tex)
			icon:SetAlpha(1)
		else
			icon:SetTexture(OFFLINE_ICON)
			icon:SetAlpha(0.5)
		end
	end
	icon:SetDesaturated(false)
	icon:Show()
end

local function UpdateFaction(d, p, fi)
	local tex = FACTION_TEX.Neutral
	if p.factionBanners ~= false and fi.state == "wow" and fi.online then
		if fi.faction == "Alliance" then
			tex = FACTION_TEX.Alliance
		elseif fi.faction == "Horde" then
			tex = FACTION_TEX.Horde
		end
	end
	d.factionBg:SetTexture(tex)
	d.factionBg:SetTexCoord(0, 1, 0, 1)
	d.factionBg:SetAlpha(0.2)
	d.factionBg:Show()
end

-- fresh: Blizzard just wrote this row's texts. Our own repaints (settings
-- changes) start again from Blizzard's last texts, so nothing doubles up.
local function DecorateRow(button)
	local d = GetFFD(button)
	local p = F()
	local bt = button.buttonType
	if not p.enabled or (bt ~= TYPE_WOW and bt ~= TYPE_BNET) or not button:IsShown() then
		HideParts(d)
		return
	end
	local fi = ReadFriend(button)
	if not fi then
		HideParts(d)
		return
	end
	SkinRow(button, d)

	local nameFS, infoFS = button.name, button.info
	ApplyFont(nameFS, 12)
	ApplyFont(infoFS, 9)

	-- Blizzard's status icon gives way to the orb.
	if button.status then button.status:SetAlpha(0) end

	-- Texts Blizzard wrote (ours are recognised and replaced by the originals).
	local curName = nameFS and nameFS:GetText()
	if curName ~= d.lastName or d.origName == nil then
		d.origName = curName
		if nameFS then d.origR, d.origG, d.origB = nameFS:GetTextColor() end
	end
	local curInfo = infoFS and infoFS:GetText()
	if curInfo ~= d.lastInfo or d.origInfo == nil then
		d.origInfo = curInfo or ""
	end

	-- Name: Blizzard's text and color, then the class color.
	local nameText = d.origName
	if nameFS and nameText then
		if d.origR then nameFS:SetTextColor(d.origR, d.origG, d.origB) end
		if p.classColorNames and fi.classFile then
			local r, g, b = ClassColor(fi.classFile)
			if r then
				if fi.kind == "wow" then
					nameFS:SetTextColor(r, g, b)
				else
					local code = Hex(r, g, b)
					nameText = nameText:gsub("%((.-)%)", function(inner)
						inner = inner:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
						return "(" .. code .. inner .. "|r)"
					end)
				end
			end
		end
		nameFS:SetText(nameText)
		d.lastName = nameText
	end

	-- Info: Blizzard's line plus the friend note.
	if infoFS then
		local text = d.origInfo
		local note = fi.note
		if type(note) == "string" and note ~= "" then
			if text ~= "" then
				text = text .. "  |cff888888|  " .. note .. "|r"
			else
				text = "|cff888888" .. note .. "|r"
			end
		end
		infoFS:SetText(text)
		d.lastInfo = text
	end

	-- Status orb right after the name.
	local orb = d.orb
	orb:ClearAllPoints()
	if nameFS then
		local w = nameFS:GetStringWidth() or 0
		orb:SetPoint("TOPLEFT", nameFS, "TOPLEFT", w - 1, 3)
	end
	if fi.online then
		if fi.dnd then
			orb:SetVertexColor(1, 0.2, 0.2, 1)
		elseif fi.afk then
			orb:SetVertexColor(1, 0.8, 0, 1)
		else
			orb:SetVertexColor(0.2, 1, 0.2, 1)
		end
	else
		orb:SetVertexColor(0.4, 0.4, 0.4, 0.6)
	end
	orb:Show()

	UpdateClassIcon(button, d, p, fi)
	UpdateFaction(d, p, fi)
end
FR.DecorateRow = DecorateRow

local function ScrollFrame()
	return FriendsFrameFriendsScrollFrame
end

function FR.DecorateAll()
	local sf = ScrollFrame()
	if not (sf and sf.buttons) then return end
	if FriendsFrame and not FriendsFrame:IsShown() then return end
	for i = 1, #sf.buttons do
		DecorateRow(sf.buttons[i])
	end
end

-------------------------------------------------------------------------------
--  Window border (only while Blizzard Skins+ does not draw the window)
-------------------------------------------------------------------------------
local borderHost
local function UpdateBorder()
	if not FriendsFrame then return end
	local p = F()
	local size = p.borderSize or 0
	local want = p.enabled and not FR.ChromeShell() and size > 0
	if not want then
		if borderHost then borderHost:Hide() end
		return
	end
	local PP = ns.PP
	if not (PP and PP.CreateBorder) then return end
	if not borderHost then
		borderHost = CreateFrame("Frame", nil, FriendsFrame)
		borderHost:SetAllPoints(FriendsFrame)
		borderHost:SetFrameLevel(FriendsFrame:GetFrameLevel() + 2)
		PP.CreateBorder(borderHost, 0, 0, 0, 1, size, "OVERLAY", 7)
	end
	PP.SetBorderSize(borderHost, size)
	local r, g, b, a
	if p.useClassColor then
		r, g, b = Accent()
		a = 1
	else
		r, g, b, a = p.borderR or 0, p.borderG or 0, p.borderB or 0, p.borderA or 1
	end
	PP.SetBorderColor(borderHost, r, g, b, a)
	borderHost:Show()
end

-------------------------------------------------------------------------------
--  Accent colors on the bottom buttons (retail UpdateBottomButtonAccent)
-------------------------------------------------------------------------------
local ACCENT_BUTTONS = {
	"FriendsFrameSendMessageButton",
	"WhoFrameWhoButton",
	"WhoFrameAddFriendButton",
	"WhoFrameGroupInviteButton",
}
local accentHooked = {}

local function PaintButtonLabel(btn)
	local lab = btn and btn.GetFontString and btn:GetFontString()
	if not lab then return end
	local p = F()
	if not (p.enabled and p.accentColors ~= false and FR.ChromeShell()) then
		if GetFFD(btn).accentPainted then
			GetFFD(btn).accentPainted = nil
			-- Hand the label back to the window skin's colors.
			if btn:IsEnabled() then lab:SetTextColor(1, 1, 1) else lab:SetTextColor(0.5, 0.5, 0.5) end
		end
		return
	end
	if btn:IsEnabled() then
		local r, g, b = Accent()
		lab:SetTextColor(r, g, b, 0.9)
		GetFFD(btn).accentPainted = true
	end
end

local function UpdateButtonAccent()
	for _, n in ipairs(ACCENT_BUTTONS) do
		local btn = _G[n]
		if btn then
			if not accentHooked[btn] then
				accentHooked[btn] = true
				-- After the window skin's own state hook (deferred one frame).
				local function later() After(0, function() PaintButtonLabel(btn) end) end
				btn:HookScript("OnEnable", later)
				btn:HookScript("OnDisable", later)
				btn:HookScript("OnShow", later)
			end
			PaintButtonLabel(btn)
		end
	end
end

-------------------------------------------------------------------------------
--  Auto-accept group invites from friends (retail FriendsKit.SyncAutoAccept)
-------------------------------------------------------------------------------
local function IsFriendName(name)
	local want = StripRealm(name)
	if not want then return false end
	for i = 1, (GetNumFriends and GetNumFriends() or 0) do
		local n = GetFriendInfo(i)
		if StripRealm(n) == want then return true end
	end
	if BNGetNumFriends then
		local num = BNGetNumFriends() or 0
		for i = 1, num do
			local _, _, _, _, toonName, _, client = BNGetFriendInfo(i)
			if client == (BNET_CLIENT_WOW or "WoW") and StripRealm(toonName) == want then return true end
			local toons = BNGetNumFriendToons and BNGetNumFriendToons(i) or 0
			for j = 1, toons do
				local _, tName, tClient = BNGetFriendToonInfo(i, j)
				if tClient == (BNET_CLIENT_WOW or "WoW") and StripRealm(tName) == want then return true end
			end
		end
	end
	return false
end

local function IsGuildmateName(name)
	if not (IsInGuild and IsInGuild()) then return false end
	local want = StripRealm(name)
	if not want then return false end
	for i = 1, (GetNumGuildMembers() or 0) do
		local n = GetGuildRosterInfo(i)
		if StripRealm(n) == want then return true end
	end
	return false
end
FR.IsFriendName = IsFriendName

local autoFrame
local hidePopup = false
local function AutoAcceptOnEvent(self, event, inviter)
	if event == "PARTY_INVITE_REQUEST" then
		local p = F()
		if not (p.enabled and p.autoAcceptFriendInvites) then return end
		if not inviter or inviter == "" or IsInGroup() then return end
		local ok = IsFriendName(inviter)
		if not ok and p.autoAcceptGuildInvites then
			ok = IsGuildmateName(inviter)
		end
		if ok then
			AcceptGroup()
			hidePopup = true
			self:RegisterEvent("GROUP_ROSTER_UPDATE")
		end
	elseif event == "GROUP_ROSTER_UPDATE" and hidePopup then
		hidePopup = false
		self:UnregisterEvent("GROUP_ROSTER_UPDATE")
		StaticPopup_Hide("PARTY_INVITE")
		StaticPopup_Hide("PARTY_INVITE_XREALM")
		if LFGInvitePopup and LFGInvitePopup:IsShown() then
			StaticPopupSpecial_Hide(LFGInvitePopup)
		end
	end
end

function FR.SyncAutoAccept()
	local p = F()
	local on = p.enabled and p.autoAcceptFriendInvites
	if on and not autoFrame then
		autoFrame = CreateFrame("Frame")
		autoFrame:SetScript("OnEvent", AutoAcceptOnEvent)
	end
	if not autoFrame then return end
	if on then
		autoFrame:RegisterEvent("PARTY_INVITE_REQUEST")
	else
		autoFrame:UnregisterEvent("PARTY_INVITE_REQUEST")
	end
end

-------------------------------------------------------------------------------
--  Apply / hooks
-------------------------------------------------------------------------------
function FR.Apply()
	FR.SyncAutoAccept()
	UpdateBorder()
	UpdateButtonAccent()
	FR.DecorateAll()
end

local hooked = false
local function HookList()
	if hooked then return end
	if not (FriendsFrame and FriendsFrame_UpdateFriends) then return end
	hooked = true
	-- Every list refresh Blizzard runs (FriendsList_Update and friends events).
	hooksecurefunc("FriendsFrame_UpdateFriends", FR.DecorateAll)
	-- Scrolling: the scroll frame calls its own saved copy of the update
	-- function, so the scroll bar's value change is hooked too.
	local bar = FriendsFrameFriendsScrollFrameScrollBar
	if bar then
		bar:HookScript("OnValueChanged", FR.DecorateAll)
	end
	FriendsFrame:HookScript("OnShow", function()
		UpdateBorder()
		UpdateButtonAccent()
		FR.DecorateAll()
	end)
end

-- Settings window: every change runs ns.applyHooks.
ns.applyHooks = ns.applyHooks or {}
tinsert(ns.applyHooks, function()
	if not hooked then return end
	FR.Apply()
end)

-- Accent color changes (Global Settings).
ns.accentListeners = ns.accentListeners or {}
tinsert(ns.accentListeners, function()
	if hooked then
		UpdateBorder()
		UpdateButtonAccent()
	end
end)

-- Back to defaults, then the Naowh values again (like Top Bar).
function FR.Reset()
	local root = Root()
	wipe(root)
	SeedNaowh(root)
	F()
	FR.Apply()
end

-------------------------------------------------------------------------------
--  Retail profile import (EllesmereUIFriends blob = { friends = { ... } })
-------------------------------------------------------------------------------
if ns.ProfileRetail and ns.ProfileRetail.CONVERT then
	ns.ProfileRetail.CONVERT[addonName] = function(blob, notes)
		local out = { _seeded = 1, friends = {} }
		local src = type(blob.friends) == "table" and blob.friends or {}
		for k, v in pairs(src) do
			if type(v) ~= "table" and type(v) ~= "function" then
				out.friends[k] = v
			end
		end
		if out.friends.showRegionIcons ~= nil and notes then
			notes[#notes + 1] = "Friends List: region icons are not available in Mists of Pandaria."
		end
		return out
	end
end

-------------------------------------------------------------------------------
--  Boot
-------------------------------------------------------------------------------
local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == addonName then
			self:UnregisterEvent("ADDON_LOADED")
			local root = Root()
			if root._seeded ~= 1 then SeedNaowh(root) end
			F()
		end
		return
	end
	self:UnregisterEvent("PLAYER_LOGIN")
	HookList()
	FR.Apply()
end)
