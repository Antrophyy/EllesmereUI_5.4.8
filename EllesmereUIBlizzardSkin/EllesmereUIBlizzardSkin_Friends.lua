-------------------------------------------------------------------------------
--  EllesmereUIBlizzardSkin_Friends.lua (5.4.8 port)
--  The 5.4.8 friends window (FriendsFrame) in the house window style, card
--  "Friends List" (key "socialui"). Built after retail's classic-style
--  friends skin (EllesmereUIBlizzardSkin_FriendsForever.lua) and the chrome
--  of the retail Social UI pack:
--    - shell, border, top bar, house close button, the corner portrait and
--      the Battle.net icon gone, the title in the house font;
--    - the Friends / Ignore / Pending tab row, the Battle.net bar with its
--      broadcast popup, the status dropdown, the list buttons;
--    - list rows keep Blizzard's own colors and icons and take the house
--      font; category headers lose their art; every scroll bar slimmed;
--    - the Who, Chat (channels) and Raid tabs: insets, column headers,
--      dropdowns, edit boxes, check boxes and buttons;
--    - the dialogs: Add Friend, Friends of Friends, BattleTag invite, the
--      new-channel dialog and the raid info window.
--  Retail-only parts skipped: Recent Allies, Quick Join, Recruit-a-Friend
--  rewards panel and the 12.x Social UI tab system (no 5.4.8 counterpart).
-------------------------------------------------------------------------------
local addonName = ...
local ns = EllesmereUI
local BS = ns.BlizzSkin
local WSkin = ns.WSkin

local WIN = "socialui"
local GetFFD = WSkin.GetFFD

-------------------------------------------------------------------------------
--  Helpers
-------------------------------------------------------------------------------
local H = {}

-- Tabs (bottom and top): WSkin.Tab plus a transparent font for Blizzard's
-- label, kept through PanelTemplates' font object changes.
do
	local hiddenFont
	local ours = setmetatable({}, { __mode = "k" })
	local hooked = false
	local function Hide(tab)
		if not ours[tab] then
			return
		end
		if not hiddenFont then
			hiddenFont = CreateFont("EUI_FriendsHiddenTabFont")
			hiddenFont:SetFontObject(GameFontNormalSmall)
			hiddenFont:SetTextColor(0, 0, 0, 0)
			hiddenFont:SetShadowColor(0, 0, 0, 0)
		end
		tab:SetNormalFontObject(hiddenFont)
		tab:SetHighlightFontObject(hiddenFont)
		tab:SetDisabledFontObject(hiddenFont)
		local fs = tab:GetFontString()
		if fs then
			fs:SetTextColor(0, 0, 0, 0)
			fs:SetShadowColor(0, 0, 0, 0)
		end
	end
	function H.Tabs(prefix, count, opts)
		local tabs = {}
		for i = 1, count do
			local tab = _G[prefix .. i]
			if tab then
				WSkin.Tab(tab, opts)
				ours[tab] = true
				Hide(tab)
				tabs[#tabs + 1] = tab
			end
		end
		if not hooked then
			hooked = true
			hooksecurefunc("PanelTemplates_SelectTab", Hide)
			hooksecurefunc("PanelTemplates_DeselectTab", Hide)
			local function ByIndex(owner, id)
				local name = owner and owner.GetName and owner:GetName()
				local tab = name and _G[name .. "Tab" .. tostring(id)]
				if tab then
					Hide(tab)
				end
			end
			hooksecurefunc("PanelTemplates_EnableTab", ByIndex)
			hooksecurefunc("PanelTemplates_DisableTab", ByIndex)
		end
		return tabs
	end
end

function H.Button(btn)
	if type(btn) == "table" then
		WSkin.Button(btn)
		WSkin.StateButtonLabel(btn)
	end
end

function H.Buttons(...)
	for i = 1, select("#", ...) do
		H.Button(_G[select(i, ...)])
	end
end

function H.Fade(...)
	for i = 1, select("#", ...) do
		local t = select(i, ...)
		if type(t) == "table" and t.SetAlpha then
			t:SetAlpha(0)
		end
	end
end

function H.Font(fs, r, g, b)
	if fs and fs.GetFont then
		WSkin.Font(fs, r, g, b)
	end
end

-- A dialog with a stock backdrop: the backdrop goes clear, a flat house
-- panel in its place.
function H.Dialog(frame)
	if not frame or GetFFD(frame).dialog then
		return
	end
	GetFFD(frame).dialog = true
	if frame.GetBackdrop and frame:GetBackdrop() then
		frame:SetBackdropColor(0, 0, 0, 0)
		frame:SetBackdropBorderColor(0, 0, 0, 0)
	end
	WSkin.Panel(frame)
	WSkin.FadeKeyedArt(frame)
	local name = frame:GetName()
	local title = name and (_G[name .. "Title"] or _G[name .. "HeaderText"])
	if title then
		H.Font(title)
	end
end

-- A bordered note box (TopLeft ... Middle pieces): a dark well.
function H.Well(frame, pad)
	if not frame or GetFFD(frame).well then
		return
	end
	GetFFD(frame).well = true
	WSkin.FadeRegions(frame)
	if frame.GetBackdrop and frame:GetBackdrop() then
		frame:SetBackdropColor(0, 0, 0, 0)
		frame:SetBackdropBorderColor(0, 0, 0, 0)
	end
	local host = CreateFrame("Frame", nil, frame)
	host:SetPoint("TOPLEFT", -(pad or 0), pad or 0)
	host:SetPoint("BOTTOMRIGHT", pad or 0, -(pad or 0))
	host:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
	local fill = WSkin.SolidTex(host, "BACKGROUND", 0.02, 0.02, 0.02, 1)
	fill:SetAllPoints(host)
	WSkin.AddBorder(host)
	GetFFD(frame).host = host
end

-- Column header (WhoFrameColumnHeaderTemplate): a flat strip + hover.
function H.ColumnHeader(hdr)
	if not hdr or GetFFD(hdr).column then
		return
	end
	GetFFD(hdr).column = true
	local n = hdr:GetName()
	H.Fade(_G[n .. "Left"], _G[n .. "Middle"], _G[n .. "Right"])
	local bg = WSkin.SolidTex(hdr, "BACKGROUND", 0, 0, 0, 0.3, -6)
	bg:SetPoint("TOPLEFT", 1, -1)
	bg:SetPoint("BOTTOMRIGHT", -1, 1)
	local hl = hdr.GetHighlightTexture and hdr:GetHighlightTexture()
	if hl then
		hl:SetTexture(1, 1, 1, 0.05)
		hl:SetAllPoints(bg)
	end
	local fs = hdr.GetFontString and hdr:GetFontString()
	if fs then
		H.Font(fs)
		WSkin.White(fs)
	end
end

-- List row: Blizzard's colors and icons stay, house font on its text.
function H.Row(btn, keys)
	if not btn or GetFFD(btn).row then
		return
	end
	GetFFD(btn).row = true
	local n = btn:GetName()
	for _, k in ipairs(keys) do
		H.Font(btn[k] or (n and _G[n .. k]))
	end
	local hl = btn.GetHighlightTexture and btn:GetHighlightTexture()
	if hl and hl.SetTexture and not btn.highlight then
		hl:SetTexture(1, 1, 1, 0.08)
	end
end

-------------------------------------------------------------------------------
--  Friends window
-------------------------------------------------------------------------------
do
	-- Friends tab: header tabs, Battle.net bar, status, broadcast, list.
	local function SkinFriendsTab()
		local hdr = FriendsTabHeader
		if hdr then
			WSkin.FadeRegions(hdr)
			H.Tabs("FriendsTabHeaderTab", 3, { darkActive = true })
		end
		local bn = FriendsFrameBattlenetFrame
		if bn then
			WSkin.FadeRegions(bn)
			if bn.Tag then
				H.Font(bn.Tag)
				WSkin.White(bn.Tag)
			end
			if bn.UnavailableLabel then
				H.Font(bn.UnavailableLabel)
			end
			local bf = bn.BroadcastFrame
			if bf then
				WSkin.Panel(bf)
				local sf = bf.ScrollFrame
				if sf then
					for _, k in ipairs({ "TopLeftBorder", "TopRightBorder", "TopBorder", "BottomLeftBorder",
						"BottomRightBorder", "BottomBorder", "LeftBorder", "RightBorder", "MiddleBorder" }) do
						H.Fade(sf[k])
					end
					if not GetFFD(sf).well then
						GetFFD(sf).well = true
						local fill = WSkin.SolidTex(sf, "BACKGROUND", 0.02, 0.02, 0.02, 1, -1)
						fill:SetPoint("TOPLEFT", -4, 4)
						fill:SetPoint("BOTTOMRIGHT", 4, -4)
					end
					if sf.ScrollBar then
						WSkin.ScrollBar(sf.ScrollBar)
					end
				end
				H.Button(bf.UpdateButton)
				H.Button(bf.CancelButton)
			end
		end
		if FriendsFrameStatusDropDown then
			WSkin.Dropdown(FriendsFrameStatusDropDown)
		end
		if FriendsFrameBroadcastInput then
			WSkin.EditBox(FriendsFrameBroadcastInput)
		end
		H.Buttons("FriendsFrameAddFriendButton", "FriendsFrameSendMessageButton")
		if FriendsListFrame then
			WSkin.FadeRegions(FriendsListFrame)
		end
		local sf = FriendsFrameFriendsScrollFrame
		if sf then
			H.Fade(FriendsFrameFriendsScrollFrameTop, FriendsFrameFriendsScrollFrameBottom, FriendsFrameFriendsScrollFrameMiddle)
			if FriendsFrameFriendsScrollFrameScrollBar then
				WSkin.ScrollBar(FriendsFrameFriendsScrollFrameScrollBar)
			end
			for i = 1, 20 do
				local b = _G["FriendsFrameFriendsScrollFrameButton" .. i]
				if not b then
					break
				end
				H.Row(b, { "name", "info", "text" })
				if b.summonButton then
					WSkin.ItemButton(b.summonButton)
				end
			end
		end
		-- Scroll of Resurrection / Recruit-a-Friend icons in the header.
		for _, n in ipairs({ "FriendsTabHeaderSoRButton", "FriendsTabHeaderRecruitAFriendButton" }) do
			local b = _G[n]
			if b then
				local icon = b.icon or b.Icon or _G[n .. "Icon"]
				WSkin.SquareIcon(icon, b)
			end
		end
	end

	local function SkinIgnoreAndPending()
		if IgnoreListFrame then
			WSkin.FadeRegions(IgnoreListFrame)
			H.Fade(IgnoreListFrameTop, IgnoreListFrameBottom, IgnoreListFrameMiddle)
		end
		for _, n in ipairs({ "FriendsFrameIgnoredHeader", "FriendsFrameBlockedInviteHeader", "FriendsFrameBlockedToonHeader", "FriendsFrameMutedHeader" }) do
			local h = _G[n]
			if h then
				WSkin.FadeRegions(h)
				local d = GetFFD(h)
				if not d.bg then
					d.bg = WSkin.SolidTex(h, "BACKGROUND", 1, 1, 1, 0.04)
					d.bg:SetAllPoints(h)
				end
			end
		end
		for i = 1, (IGNORES_TO_DISPLAY or 20) do
			local b = _G["FriendsFrameIgnoreButton" .. i]
			if not b then
				break
			end
			H.Row(b, { "name" })
		end
		H.Buttons("FriendsFrameIgnorePlayerButton", "FriendsFrameUnsquelchButton", "FriendsFrameMutePlayerButton")
		if FriendsFrameIgnoreScrollFrame then
			WSkin.ScrollBarsIn(FriendsFrameIgnoreScrollFrame)
		end
		if PendingListFrame then
			WSkin.FadeRegions(PendingListFrame)
			H.Fade(PendingListFrameTop, PendingListFrameBottom, PendingListFrameMiddle)
		end
		if PendingListInfoFrame then
			WSkin.FadeRegions(PendingListInfoFrame)
			H.Button(PendingListInfoFrameContinueButton)
		end
		for i = 1, (PENDING_INVITES_TO_DISPLAY or 4) do
			local b = _G["FriendsFramePendingButton" .. i]
			if b then
				H.Row(b, { "name", "sent", "message", "RIDTag" })
				H.Button(_G["FriendsFramePendingButton" .. i .. "AcceptButton"])
				H.Button(_G["FriendsFramePendingButton" .. i .. "DeclineButton"])
			end
		end
		if FriendsFramePendingScrollFrameScrollBar then
			WSkin.ScrollBar(FriendsFramePendingScrollFrameScrollBar)
		end
	end

	local function SkinWho()
		if not WhoFrame then
			return
		end
		WSkin.FadeRegions(WhoFrame)
		if WhoFrameListInset then
			WSkin.Inset(WhoFrameListInset)
		end
		if WhoFrameEditBoxInset then
			WSkin.Inset(WhoFrameEditBoxInset)
			H.Well(WhoFrameEditBoxInset, -2)
		end
		for i = 1, 5 do
			H.ColumnHeader(_G["WhoFrameColumnHeader" .. i])
		end
		if WhoFrameDropDown then
			WSkin.Dropdown(WhoFrameDropDown)
		end
		for i = 1, (WHOS_TO_DISPLAY or 17) do
			local b = _G["WhoFrameButton" .. i]
			if not b then
				break
			end
			H.Row(b, { "Name", "Level", "Class", "Variable" })
		end
		H.Buttons("WhoFrameGroupInviteButton", "WhoFrameAddFriendButton", "WhoFrameWhoButton")
		if WhoListScrollFrame then
			WSkin.ScrollBarsIn(WhoListScrollFrame)
		end
	end

	-- Chat tab (ChannelFrame): insets, channel rows, roster, new channel dialog.
	local function SkinChannelRows()
		for i = 1, (MAX_DISPLAY_CHANNEL_BUTTONS or 20) do
			local b = _G["ChannelButton" .. i]
			if b then
				local nt = _G["ChannelButton" .. i .. "NormalTexture"]
				if nt then
					nt:SetAlpha(0)
				end
				if not GetFFD(b).row then
					GetFFD(b).row = true
					local bg = WSkin.SolidTex(b, "BACKGROUND", 1, 1, 1, 0.03)
					bg:SetAllPoints(b)
					H.Font(_G["ChannelButton" .. i .. "Text"])
					local hl = b:GetHighlightTexture()
					if hl then
						hl:SetTexture(1, 1, 1, 0.08)
						hl:SetAllPoints(b)
					end
				end
			end
		end
	end

	local function SkinChannels()
		local cf = ChannelFrame
		if not cf then
			return
		end
		WSkin.FadeRegions(cf)
		if ChannelFrameLeftInset then WSkin.Inset(ChannelFrameLeftInset) end
		if ChannelFrameRightInset then WSkin.Inset(ChannelFrameRightInset) end
		if ChannelRoster then
			WSkin.FadeRegions(ChannelRoster)
			WSkin.ScrollBarsIn(ChannelRoster)
		end
		if ChannelListScrollFrameScrollBar then
			WSkin.ScrollBar(ChannelListScrollFrameScrollBar)
		end
		H.Fade(ChannelListScrollFrameTop, ChannelListScrollFrameBottom, ChannelRosterScrollFrameTop, ChannelRosterScrollFrameBottom)
		for _, n in ipairs({ "ChannelFrameAutoJoinParty", "ChannelFrameAutoJoinBattleground" }) do
			if _G[n] then
				WSkin.Checkbox(_G[n])
			end
		end
		H.Buttons("ChannelFrameNewButton", "ChannelFrameJoinButton")
		for i = 1, (MAX_CHANNEL_MEMBER_BUTTONS or 22) do
			local b = _G["ChannelMemberButton" .. i]
			if b then
				H.Row(b, { "Name" })
			end
		end
		SkinChannelRows()
		if ChannelList_Update then
			hooksecurefunc("ChannelList_Update", SkinChannelRows)
		end
		-- New channel dialog.
		local dd = ChannelFrameDaughterFrame
		if dd then
			H.Dialog(dd)
			H.Fade(ChannelFrameDaughterFrameTitlebar, ChannelFrameDaughterFrameCorner)
			for _, n in ipairs({ "ChannelFrameDaughterFrameChannelName", "ChannelFrameDaughterFrameChannelPassword" }) do
				if _G[n] then
					WSkin.EditBox(_G[n])
				end
			end
			if ChannelFrameDaughterFrameVoiceChat then
				WSkin.Checkbox(ChannelFrameDaughterFrameVoiceChat)
			end
			if ChannelFrameDaughterFrameDetailCloseButton then
				WSkin.CloseButton(ChannelFrameDaughterFrameDetailCloseButton)
			end
			H.Buttons("ChannelFrameDaughterFrameOkayButton", "ChannelFrameDaughterFrameCancelButton")
		end
	end

	-- Raid tab (RaidFrame, docked in the friends window) and the raid info window.
	local function SkinRaid()
		local rf = RaidFrame
		if rf then
			WSkin.FadeRegions(rf)
			if RaidFrameAllAssistCheckButton then
				WSkin.Checkbox(RaidFrameAllAssistCheckButton)
			end
			H.Buttons("RaidFrameConvertToRaidButton", "RaidFrameRaidBrowserButton", "RaidFrameRaidInfoButton")
			if RaidFrameRaidDescription then
				H.Font(RaidFrameRaidDescription)
			end
		end
		local ri = RaidInfoFrame
		if ri then
			H.Dialog(ri)
			H.Fade(RaidInfoDetailHeader, RaidInfoDetailFooter, RaidInfoDetailCorner, RaidInfoFrameHeader)
			for _, n in ipairs({ "RaidInfoInstanceLabel", "RaidInfoIDLabel" }) do
				local l = _G[n]
				if l then
					H.Fade(_G[n .. "Left"], _G[n .. "Right"], _G[n .. "Middle"])
					if l.text then
						H.Font(l.text)
					end
				end
			end
			if RaidInfoCloseButton then
				WSkin.CloseButton(RaidInfoCloseButton)
			end
			if RaidInfoScrollFrameScrollBar then
				WSkin.ScrollBar(RaidInfoScrollFrameScrollBar)
			end
			H.Buttons("RaidInfoExtendButton", "RaidInfoCancelButton")
		end
	end

	-- Add Friend, Friends of Friends, BattleTag invite.
	local function SkinDialogs()
		if AddFriendFrame then
			H.Dialog(AddFriendFrame)
			if AddFriendNameEditBox then
				WSkin.EditBox(AddFriendNameEditBox)
			end
			H.Well(AddFriendNoteFrame, 0)
			if AddFriendNoteFrameScrollFrameScrollBar then
				WSkin.ScrollBar(AddFriendNoteFrameScrollFrameScrollBar)
			end
			H.Buttons("AddFriendEntryFrameAcceptButton", "AddFriendEntryFrameCancelButton", "AddFriendInfoFrameContinueButton")
		end
		local ff = FriendsFriendsFrame
		if ff then
			H.Dialog(ff)
			if FriendsFriendsFrameDropDown then
				WSkin.Dropdown(FriendsFriendsFrameDropDown)
			end
			H.Well(FriendsFriendsList, 0)
			H.Well(FriendsFriendsNoteFrame, 0)
			if FriendsFriendsScrollFrame then
				WSkin.ScrollBarsIn(FriendsFriendsScrollFrame)
			end
			if FriendsFriendsNoteFrameScrollFrameScrollBar then
				WSkin.ScrollBar(FriendsFriendsNoteFrameScrollFrameScrollBar)
			end
			for i = 1, (FRIENDS_FRIENDS_TO_DISPLAY or 11) do
				local b = _G["FriendsFriendsButton" .. i]
				if b then
					H.Row(b, { "name" })
				end
			end
			H.Buttons("FriendsFriendsSendRequestButton", "FriendsFriendsCloseButton")
		end
		local bt = BattleTagInviteFrame
		if bt then
			H.Dialog(bt)
			WSkin.ButtonsIn(bt)
			if bt.NoteFrame then
				H.Well(bt.NoteFrame, 0)
			end
		end
	end

	local function SkinFriends()
		local f = FriendsFrame
		if not f then
			return
		end
		WSkin.Shell(WIN, f)
		WSkin.RemovePortrait(f)
		H.Fade(FriendsFrameIcon)
		WSkin.CommonChrome(f, "FriendsFrame", true)
		if FriendsFrameInset then
			WSkin.Inset(FriendsFrameInset)
		end
		local title = FriendsFrameTitleText or f.TitleText
		if title then
			H.Font(title)
			WSkin.White(title)
		end

		SkinFriendsTab()
		SkinIgnoreAndPending()
		SkinWho()
		SkinChannels()
		SkinRaid()
		SkinDialogs()

		-- Bottom tabs: Friends / Who / Chat / Raid.
		local tabs = H.Tabs("FriendsFrameTab", 4)
		WSkin.NormalizeTabRow(tabs)

		-- Blizzard repaints parts of the window on tab and list changes.
		local repaint = WSkin.Debounce(function()
			if f:IsVisible() then
				WSkin.Restrip(WIN)
				WSkin.UpdateAllTabs()
			end
		end)
		WSkin.HookShow(f, repaint)
		if FriendsFrame_ShowSubFrame then
			hooksecurefunc("FriendsFrame_ShowSubFrame", repaint)
		end
		if FriendsFrame_Update then
			hooksecurefunc("FriendsFrame_Update", repaint)
		end
	end

	WSkin.RegisterWindow({
		key = WIN,
		label = "Friends List",
		description = "The friends window: friends, ignore and pending lists, the Battle.net bar and broadcast, Who, chat channels and the raid tab, plus the Add Friend and Friends of Friends dialogs.",
		order = 410,
		elvui = "friends",
		apply = SkinFriends,
	})
end
