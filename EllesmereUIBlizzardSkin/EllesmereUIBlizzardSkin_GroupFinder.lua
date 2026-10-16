-------------------------------------------------------------------------------
--  EllesmereUIBlizzardSkin_GroupFinder.lua (5.4.8 port)
--  Dark, minimal reskin of the 5.4.8 Group Finder (PVEFrame) in the house
--  style: shell, bottom tabs, the left category rail, the Dungeon Finder,
--  Scenarios, Raid Finder and Flex Raid panels, the Challenges tab
--  (Blizzard_ChallengesUI), the PvP window (PVPUIFrame, Blizzard_PVPUI) and
--  the Raid Browser (RaidBrowserFrame). One card: "LFG Menu" (key "lfg").
--
--  Retail parts with no 5.4.8 counterpart are skipped: Premade Groups
--  (LFGList: category / search / entry / applicant panels, Remember Sign-Up
--  Roles), Mythic+ keystone and dungeon icons, Training Grounds, and the
--  character-sheet docking (5.4.8's panel manager places the windows).
--
--  Safety: visual only (SetAlpha on Blizzard art, our own textures under it),
--  HookScript / hooksecurefunc only, state in WSkin.GetFFD, never
--  Show/Hide/SetParent on Blizzard frames.
-------------------------------------------------------------------------------
local addonName = ...
local ns = EllesmereUI
local BS = ns.BlizzSkin
local WSkin = ns.WSkin
local PP = BS.PP

local WIN = "lfg"
local GetFFD = WSkin.GetFFD
local FFD = WSkin.FFD

-------------------------------------------------------------------------------
--  Shared helpers
-------------------------------------------------------------------------------
local H = {}

-- Bottom tabs: WSkin.Tab plus a transparent font for Blizzard's label (in
-- 5.4.8 PanelTemplates set a new font object, with its color, on every tab
-- change, so an alpha-0 label comes back).
do
	local hiddenFont
	local ours = setmetatable({}, { __mode = "k" })
	local hooked = false
	local function Hide(tab)
		if not ours[tab] then
			return
		end
		if not hiddenFont then
			hiddenFont = CreateFont("EUI_GroupFinderHiddenTabFont")
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
	function H.Tabs(frame, prefix, count)
		local tabs = {}
		for i = 1, count do
			local tab = _G[prefix .. i]
			if tab then
				WSkin.Tab(tab)
				ours[tab] = true
				Hide(tab)
				tabs[#tabs + 1] = tab
			end
		end
		WSkin.NormalizeTabRow(tabs)
		if not hooked then
			hooked = true
			hooksecurefunc("PanelTemplates_SelectTab", Hide)
			hooksecurefunc("PanelTemplates_DeselectTab", Hide)
			local function ByIndex(owner, id)
				local tab = owner and owner.GetName and owner:GetName() and _G[owner:GetName() .. "Tab" .. tostring(id)]
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

-- A content panel: its own art gone (the shell shows through), its insets
-- stripped, named art keys and path-keyword art faded, and its stock buttons,
-- dropdowns, edit boxes and scroll bars in the house look.
function H.Content(frame)
	if not frame or BS.Forbidden(frame) then
		return
	end
	WSkin.Panel(frame, { noBg = true, noBorder = true })
	WSkin.FadeKeyedArt(frame)
	WSkin.FadeArtIn(frame)
	WSkin.ButtonsIn(frame)
	WSkin.ControlsIn(frame)
	WSkin.ScrollBarsIn(frame)
	local name = frame:GetName()
	for _, k in ipairs({ "Inset", "RoleInset", "BottomInset", "ListInset", "CommentInset", "LeftInset", "RightInset" }) do
		local inset = frame[k] or (name and _G[name .. k])
		if inset and inset.GetRegions then
			WSkin.Inset(inset)
		end
	end
end

function H.Button(btn)
	if type(btn) == "table" then
		WSkin.Button(btn)
		WSkin.StateButtonLabel(btn)
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

-- Left rail card (GroupFinder / PvP category buttons): icon and ring kept,
-- the blue menu art gone, a dark card with a hover wash and a held wash on
-- the selected category.
function H.RailButton(btn)
	if not btn or BS.Forbidden(btn) then
		return
	end
	local d = GetFFD(btn)
	if d.rail then
		return
	end
	d.rail = true
	local keep = {}
	local icon = btn.icon or btn.Icon
	local ring = btn.ring or btn.Ring
	if icon then keep[icon] = true end
	if ring then keep[ring] = true end
	WSkin.FadeRegions(btn, keep)
	local hl = btn.GetHighlightTexture and btn:GetHighlightTexture()
	if hl then
		hl:SetAlpha(0)
	end
	-- Icon and ring 10 px smaller, 3 px right (retail).
	if icon and ring then
		local w, h = ring:GetSize()
		if w and w > 10 then
			ring:SetSize(w - 10, h - 10)
		end
		local iw, ih = icon:GetSize()
		if iw and iw > 10 then
			icon:SetSize(iw - 10, ih - 10)
		end
	end
	local card = WSkin.SolidTex(btn, "BACKGROUND", 0, 0, 0, 0.3, -6)
	card:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, -2)
	card:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 2)
	d.bg = card
	local hover = WSkin.SolidTex(btn, "HIGHLIGHT", 1, 1, 1, 0.05)
	hover:SetAllPoints(card)
	d.hover = hover
	local sel = WSkin.SolidTex(btn, "ARTWORK", 1, 1, 1, 0.05, -7)
	sel:SetAllPoints(card)
	sel:Hide()
	d.selWash = sel
	local bar = WSkin.SolidTex(btn, "ARTWORK", 1, 1, 1, 1, 7)
	bar:SetWidth(2)
	bar:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
	bar:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 0, 0)
	bar:Hide()
	d.selBar = bar
	WSkin.Register(btn, keep)
end

function H.SetRailSelected(btn, on)
	local d = btn and FFD[btn]
	if not d or not d.selWash then
		return
	end
	d.selWash:SetShown(on and true or false)
	local r, g, b = WSkin.AccentBarColor()
	d.selBar:SetTexture(r, g, b, 1)
	d.selBar:SetShown((on and WSkin.AccentBarShown()) and true or false)
end

-- LFG reward tile (LFGRewardsLootTemplate): name plate gone, square icon
-- with the reward's rarity edge (shortage rewards in epic purple).
function H.RewardTile(btn)
	if not btn then
		return
	end
	local name = btn:GetName()
	H.Fade(btn.NameFrame or (name and _G[name .. "NameFrame"]), btn.shortageBorder)
	local label = btn.name or (name and _G[name .. "Name"])
	if label then
		WSkin.White(label)
	end
	local icon = btn.icon or (name and _G[name .. "IconTexture"])
	if not icon then
		return
	end
	WSkin.SquareIcon(icon)
	local r, g, b
	if btn.shortageIndex then
		local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[4]
		if c then r, g, b = c.r, c.g, c.b end
	elseif btn.dungeonID and GetLFGDungeonRewardLink then
		local ok, link = pcall(GetLFGDungeonRewardLink, btn.dungeonID, btn:GetID())
		if ok and link then
			r, g, b = WSkin.LinkQuality(link)
		end
	end
	WSkin.QualityBorder(btn, icon, r or 0, g or 0, b or 0)
end

function H.RewardsFrame(parentFrame)
	if not parentFrame or not parentFrame.GetName then
		return
	end
	local name = parentFrame:GetName()
	local n = parentFrame.numRewardFrames
	if name and type(n) == "number" then
		for i = 1, n do
			H.RewardTile(_G[name .. "Item" .. i])
		end
	end
	local bv = parentFrame.BonusValor
	if bv then
		if bv.Border then bv.Border:SetAlpha(0) end
		if bv.Icon then
			WSkin.SquareIcon(bv.Icon, bv)
		end
	end
end

-- LFGSpecificChoiceTemplate row: house checkbox.
function H.ChoiceRow(row)
	if row and row.enableButton then
		WSkin.Checkbox(row.enableButton, { fillInset = 5 })
	end
end

-------------------------------------------------------------------------------
--  PVEFrame: shell, tabs, category rail, the four Group Finder panels
-------------------------------------------------------------------------------
do
	local GROUP_FRAMES = { "LFDParentFrame", "ScenarioFinderFrame", "RaidFinderFrame", "FlexRaidFrame" }

	local function RailButton(i)
		return GroupFinderFrame and (GroupFinderFrame["groupButton" .. i] or _G["GroupFinderFrameGroupButton" .. i])
	end

	local function UpdateRailSelection(index)
		if type(index) ~= "number" then
			local sel = GroupFinderFrame and GroupFinderFrame.selection
			for i, n in ipairs(GROUP_FRAMES) do
				if sel and _G[n] == sel then
					index = i
				end
			end
		end
		for i = 1, 4 do
			H.SetRailSelected(RailButton(i), i == index)
		end
	end

	-- Rail zone: 10% black wash over the left column + a 1 px divider.
	local function RailZone(pve)
		local d = GetFFD(pve)
		if d.leftWash then
			return
		end
		local inset = pve.Inset or PVEFrameLeftInset
		local wash = WSkin.SolidTex(pve, "BACKGROUND", 0, 0, 0, 0.1, -4)
		if inset then
			wash:SetAllPoints(inset)
		else
			wash:SetPoint("TOPLEFT", pve, "TOPLEFT", 4, -60)
			wash:SetPoint("BOTTOMRIGHT", pve, "BOTTOMLEFT", 224, 26)
		end
		d.leftWash = wash
		local sep = WSkin.SolidTex(pve, "ARTWORK", 0.15, 0.15, 0.15, 1)
		sep:SetWidth(PP.mult or 1)
		sep:SetPoint("TOPLEFT", wash, "TOPRIGHT", 0, 0)
		sep:SetPoint("BOTTOMLEFT", wash, "BOTTOMRIGHT", 0, 0)
		d.leftSep = sep
	end

	local function UpdateRailZone()
		local d = PVEFrame and FFD[PVEFrame]
		if not d or not d.leftWash then
			return
		end
		local show = GroupFinderFrame and GroupFinderFrame:IsShown() and true or false
		d.leftWash:SetShown(show)
		d.leftSep:SetShown(show)
	end

	local function SkinDungeonFinder()
		if not LFDParentFrame then
			return
		end
		H.Content(LFDParentFrame)
		H.Fade(LFDParentFrameRoleBackground, LFDQueueFrameBackground)
		H.Content(LFDQueueFrame)
		H.Button(LFDQueueFrameFindGroupButton)
		for i = 1, (NUM_LFD_CHOICE_BUTTONS or 15) do
			H.ChoiceRow(_G["LFDQueueFrameSpecificListButton" .. i])
		end
		local bonus = LFDQueueFrameRandomScrollFrameChildFrameBonusRepFrame
		if bonus and bonus.ChooseButton then
			H.Button(bonus.ChooseButton)
		end
	end

	local function SkinScenarios()
		if not ScenarioFinderFrame then
			return
		end
		H.Content(ScenarioFinderFrame)
		if ScenarioQueueFrame then
			H.Fade(ScenarioQueueFrame.Bg)
			H.Content(ScenarioQueueFrame)
		end
		H.Button(ScenarioQueueFrameFindGroupButton)
		for i = 1, (NUM_SCENARIO_CHOICE_BUTTONS or 10) do
			H.ChoiceRow(_G["ScenarioQueueFrameSpecificButton" .. i])
		end
		local bonus = ScenarioQueueFrameRandomScrollFrameChildFrameBonusRepFrame
		if bonus and bonus.ChooseButton then
			H.Button(bonus.ChooseButton)
		end
	end

	local function FadeRaidFinderArt()
		H.Fade(RaidFinderFrameRoleBackground, RaidFinderQueueFrameBackground)
		if RaidFinderFrameRoleInset then WSkin.Inset(RaidFinderFrameRoleInset) end
		if RaidFinderFrameBottomInset then WSkin.Inset(RaidFinderFrameBottomInset) end
	end

	local function SkinRaidFinder()
		if not RaidFinderFrame then
			return
		end
		H.Content(RaidFinderFrame)
		H.Content(RaidFinderQueueFrame)
		FadeRaidFinderArt()
		RaidFinderFrame:HookScript("OnShow", FadeRaidFinderArt)
		H.Button(RaidFinderFrameFindRaidButton)
	end

	local function SkinFlexRaid()
		if not FlexRaidFrame then
			return
		end
		H.Content(FlexRaidFrame)
		H.Fade(FlexRaidFrameScrollFrameBackground, FlexRaidFrameScrollFrameBackgroundCover)
		H.Button(FlexRaidFrameStartRaidButton)
	end

	local function Skin_PVE()
		local pve = PVEFrame
		if not pve then
			return
		end
		WSkin.Shell(WIN, pve)
		WSkin.RemovePortrait(pve)
		if pve.shadows then
			WSkin.FadeRegions(pve.shadows)
			WSkin.Register(pve.shadows, true)
		end
		WSkin.CommonChrome(pve, "PVEFrame", true)
		local inset = pve.Inset or PVEFrameLeftInset
		if inset then
			WSkin.Inset(inset)
		end
		RailZone(pve)
		H.Tabs(pve, "PVEFrameTab", 2)

		for i = 1, 4 do
			H.RailButton(RailButton(i))
		end
		UpdateRailSelection()

		SkinDungeonFinder()
		SkinScenarios()
		SkinRaidFinder()
		SkinFlexRaid()

		-- Blizzard repaints on tab / category changes and reward updates.
		local restrip = WSkin.Debounce(function()
			WSkin.Restrip(WIN)
			UpdateRailZone()
			UpdateRailSelection()
		end)
		if GroupFinderFrame_SelectGroupButton then
			hooksecurefunc("GroupFinderFrame_SelectGroupButton", function(index)
				UpdateRailSelection(index)
				restrip()
			end)
		end
		if PVEFrame_ShowFrame then
			hooksecurefunc("PVEFrame_ShowFrame", restrip)
		end
		if LFGRewardsFrame_UpdateFrame then
			hooksecurefunc("LFGRewardsFrame_UpdateFrame", function(parentFrame, _, background)
				if WSkin.GetStyle(WIN) == "off" then
					return
				end
				if background and background.SetAlpha then
					background:SetAlpha(0)
				end
				H.RewardsFrame(parentFrame)
			end)
		end
		if ScenarioQueueFrameSpecific_Update then
			hooksecurefunc("ScenarioQueueFrameSpecific_Update", function()
				for i = 1, (NUM_SCENARIO_CHOICE_BUTTONS or 10) do
					H.ChoiceRow(_G["ScenarioQueueFrameSpecificButton" .. i])
				end
			end)
		end
		WSkin.HookShow(pve, restrip)
		if GroupFinderFrame then
			GroupFinderFrame:HookScript("OnShow", UpdateRailZone)
			GroupFinderFrame:HookScript("OnHide", UpdateRailZone)
		end
		WSkin.OnLooksChanged(function() UpdateRailSelection() end)
	end

	-- Raid Browser (LFRParentFrame in RaidBrowserFrame): queue + browse views.
	local function Skin_RaidBrowser()
		local f = RaidBrowserFrame
		if not f then
			return
		end
		WSkin.Shell(WIN, f)
		WSkin.RemovePortrait(f)
		WSkin.CommonChrome(f, "RaidBrowserFrame", true)
		for i = 1, 2 do
			local tab = _G["LFRParentFrameSideTab" .. i]
			if tab then
				WSkin.SideTab(tab)
			end
		end
		H.Content(LFRParentFrame)
		H.Content(LFRQueueFrame)
		H.Content(LFRBrowseFrame)
		H.Fade(LFRBrowseFrameTop, LFRBrowseFrameBottom, LFRBrowseFrameMiddle)
		for i = 1, (NUM_LFR_CHOICE_BUTTONS or 14) do
			H.ChoiceRow(_G["LFRQueueFrameSpecificListButton" .. i])
		end
		-- Column headers: flat strips with a hover wash.
		for i = 1, 7 do
			local hdr = _G["LFRBrowseFrameColumnHeader" .. i]
			if hdr then
				local n = hdr:GetName()
				H.Fade(_G[n .. "Left"], _G[n .. "Middle"], _G[n .. "Right"])
				local d = GetFFD(hdr)
				if not d.bg then
					d.bg = WSkin.SolidTex(hdr, "BACKGROUND", 0, 0, 0, 0.3, -6)
					d.bg:SetPoint("TOPLEFT", 1, -1)
					d.bg:SetPoint("BOTTOMRIGHT", -1, 1)
					local hl = hdr.GetHighlightTexture and hdr:GetHighlightTexture()
					if hl then
						hl:SetTexture(1, 1, 1, 0.05)
						hl:SetAllPoints(d.bg)
					end
				end
			end
		end
		-- The comment box: a dark well.
		local comment = LFRQueueFrameCommentScrollFrame
		if comment and not GetFFD(comment).bg then
			local bg = WSkin.SolidTex(comment, "BACKGROUND", 0.02, 0.02, 0.02, 1)
			bg:SetPoint("TOPLEFT", -4, 4)
			bg:SetPoint("BOTTOMRIGHT", 4, -4)
			GetFFD(comment).bg = bg
		end
		for _, n in ipairs({ "LFRQueueFrameFindGroupButton", "LFRQueueFrameAcceptCommentButton",
			"LFRBrowseFrameSendMessageButton", "LFRBrowseFrameInviteButton", "LFRBrowseFrameRefreshButton" }) do
			H.Button(_G[n])
		end
		WSkin.HookShow(f, WSkin.Debounce(function() WSkin.Restrip(WIN) end))
	end

	WSkin.RegisterWindow({
		key = WIN,
		label = "LFG Menu",
		description = "Group Finder window: Dungeon Finder, Scenarios, Raid Finder, Flex Raid and Challenges, plus the PvP window and the Raid Browser.",
		order = 20,
		elvui = "lfg",
		apply = function()
			Skin_PVE()
			Skin_RaidBrowser()
		end,
	})
end

-------------------------------------------------------------------------------
--  Challenges tab (Blizzard_ChallengesUI)
-------------------------------------------------------------------------------
do
	local function SkinDungeonButton(btn)
		if not btn or GetFFD(btn).challenge then
			return
		end
		GetFFD(btn).challenge = true
		local keep = {}
		if btn.selectedTex then keep[btn.selectedTex] = true end
		if btn.MedalIcon then keep[btn.MedalIcon] = true end
		if btn.NoMedal then keep[btn.NoMedal] = true end
		WSkin.FadeRegions(btn, keep)
		local nt = btn.GetNormalTexture and btn:GetNormalTexture()
		if nt then nt:SetAlpha(0) end
		local bg = WSkin.SolidTex(btn, "BACKGROUND", 0, 0, 0, 0.3, -6)
		bg:SetAllPoints(btn)
		GetFFD(btn).bg = bg
		local hl = btn.GetHighlightTexture and btn:GetHighlightTexture()
		if hl then
			hl:SetTexture(1, 1, 1, 0.05)
			hl:SetAllPoints(btn)
		end
		if btn.selectedTex then
			btn.selectedTex:SetTexture(1, 1, 1, 0.08)
			btn.selectedTex:SetAllPoints(btn)
		end
		WSkin.Register(btn, keep)
	end

	local function Skin_Challenges()
		local cf = ChallengesFrame
		if not cf then
			return
		end
		H.Content(cf)
		if ChallengesFrameInset then
			WSkin.Inset(ChallengesFrameInset)
		end
		local det = ChallengesFrameDetails
		if det then
			WSkin.Panel(det, { shade = true })
			H.Fade(det.bg)
		end
		for i = 1, 9 do
			SkinDungeonButton(cf["button" .. i])
		end
		for i = 1, 3 do
			local row = cf["RewardRow" .. i]
			if row then
				if row.Bg then
					row.Bg:SetAlpha(0.35)
				end
				for j = 1, 2 do
					local rw = row["Reward" .. j]
					if rw and rw.Icon then
						WSkin.SquareIcon(rw.Icon, rw)
					end
				end
			end
		end
		H.Button(ChallengesFrameLeaderboard)
	end

	WSkin.RegisterWindow({
		key = WIN,
		addons = { Blizzard_ChallengesUI = true },
		elvui = "lfg",
		apply = Skin_Challenges,
	})
end

-------------------------------------------------------------------------------
--  PvP window (PVPUIFrame, Blizzard_PVPUI): Honor, Conquest, War Games
-------------------------------------------------------------------------------
do
	local function CategoryButton(i)
		return PVPQueueFrame and (PVPQueueFrame["CategoryButton" .. i] or _G["PVPQueueFrameCategoryButton" .. i])
	end

	local function UpdateSelection(index)
		if type(index) ~= "number" then
			index = PVPQueueFrame and PVPQueueFrame.selection
			if type(index) ~= "number" then
				local frames = { HonorFrame, ConquestFrame, WarGamesFrame }
				for i, f in ipairs(frames) do
					if f and f:IsShown() then
						index = i
					end
				end
			end
		end
		for i = 1, 3 do
			H.SetRailSelected(CategoryButton(i), i == index)
		end
	end

	-- Bracket / battleground buttons: art gone, a flat card, Blizzard's
	-- selected texture as a white wash.
	local function ListButton(btn)
		if not btn or GetFFD(btn).pvpBtn then
			return
		end
		GetFFD(btn).pvpBtn = true
		local keep = {}
		for _, k in ipairs({ "Icon", "SelectedTexture" }) do
			if btn[k] then keep[btn[k]] = true end
		end
		WSkin.FadeRegions(btn, keep)
		local bg = WSkin.SolidTex(btn, "BACKGROUND", 0, 0, 0, 0.3, -6)
		bg:SetAllPoints(btn)
		GetFFD(btn).bg = bg
		local hl = btn.GetHighlightTexture and btn:GetHighlightTexture()
		if hl then
			hl:SetTexture(1, 1, 1, 0.05)
			hl:SetAllPoints(btn)
		end
		if btn.SelectedTexture then
			btn.SelectedTexture:SetTexture(1, 1, 1, 0.08)
			btn.SelectedTexture:SetTexCoord(0, 1, 0, 1)
			btn.SelectedTexture:SetAllPoints(btn)
		end
		if btn.Icon then
			WSkin.SquareIcon(btn.Icon, btn)
		end
		WSkin.Register(btn, keep)
	end

	local function Skin_PVP()
		local f = PVPUIFrame
		if not f then
			return
		end
		WSkin.Shell(WIN, f)
		WSkin.RemovePortrait(f)
		WSkin.CommonChrome(f, "PVPUIFrame", true)
		if f.Shadows then
			WSkin.FadeRegions(f.Shadows)
		end
		if f.LeftInset then
			WSkin.Inset(f.LeftInset)
		end
		for i = 1, 3 do
			local b = CategoryButton(i)
			H.RailButton(b)
			if b and b.CurrencyIcon then
				WSkin.SquareIcon(b.CurrencyIcon, b)
			end
		end
		UpdateSelection()

		-- Honor
		local hf = HonorFrame
		if hf then
			H.Content(hf)
			if hf.RoleInset then
				WSkin.Inset(hf.RoleInset)
				H.Fade(hf.RoleInset.Background)
			end
			local bf = hf.BonusFrame
			if bf then
				H.Fade(bf.WorldBattlesTexture, bf.BattlegroundTexture)
				if bf.ShadowOverlay then WSkin.FadeRegions(bf.ShadowOverlay) end
				for _, k in ipairs({ "RandomBGButton", "CallToArmsButton", "WorldPVP1Button", "WorldPVP2Button" }) do
					ListButton(bf[k])
				end
			end
			for i = 1, 9 do
				ListButton(_G["HonorFrameSpecificFrameButton" .. i])
			end
			H.Button(HonorFrameSoloQueueButton)
			H.Button(HonorFrameGroupQueueButton)
		end

		-- Conquest
		local cq = ConquestFrame
		if cq then
			H.Content(cq)
			H.Fade(cq.ArenaTexture, cq.RatedBGTexture)
			if cq.ShadowOverlay then WSkin.FadeRegions(cq.ShadowOverlay) end
			for _, k in ipairs({ "RatedBG", "Arena2v2", "Arena3v3", "Arena5v5" }) do
				ListButton(cq[k])
			end
			for _, k in ipairs({ "ArenaReward", "RatedBGReward" }) do
				local rw = cq[k]
				if rw and rw.Icon then
					WSkin.SquareIcon(rw.Icon, rw)
				end
			end
			local bar = ConquestPointsBar or cq.ConquestBar
			if bar then
				WSkin.FadeRegions(bar)
				if bar.progress then
					bar.progress:SetAlpha(1)
					bar.progress:SetTexture(BS.WHITE)
					local r, g, b, a = WSkin.BarFillColor()
					bar.progress:SetVertexColor(r, g, b, a)
				end
			end
			H.Button(ConquestJoinButton or cq.JoinButton)
		end

		-- War Games
		local wg = WarGamesFrame
		if wg then
			H.Content(wg)
			H.Fade(wg.InfoBG)
			if wg.HorizontalBar then WSkin.FadeRegions(wg.HorizontalBar) end
			for i = 1, 8 do
				local b = _G["WarGamesFrameScrollFrameButton" .. i]
				if b and b.Entry then
					ListButton(b.Entry)
				end
			end
			H.Button(WarGameStartButton)
		end

		local restrip = WSkin.Debounce(function()
			WSkin.Restrip(WIN)
			UpdateSelection()
		end)
		if PVPQueueFrame_SelectButton then
			hooksecurefunc("PVPQueueFrame_SelectButton", function(index)
				UpdateSelection(index)
				restrip()
			end)
		end
		WSkin.HookShow(f, restrip)
	end

	WSkin.RegisterWindow({
		key = WIN,
		addons = { Blizzard_PVPUI = true },
		elvui = "pvp",
		apply = Skin_PVP,
	})
end
