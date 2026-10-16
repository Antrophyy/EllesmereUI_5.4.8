-------------------------------------------------------------------------------
--  EllesmereUIBlizzardSkin_SocketPanel.lua (5.4.8 port)
--  Two parts, like retail:
--   1) The "Gem Socketing" window skin (ItemSocketingFrame,
--      Blizzard_ItemSocketingUI): house shell, flat Socket button, slim
--      scroll bar, the socket flourishes gone (retail WindowPacks "socket").
--   2) The character sheet socket panel (retail SocketPanel): a row of the
--      sockets of the equipped gear at the bottom right of the sheet. Filled
--      sockets show the gem, empty ones the empty socket. Hovering an empty
--      socket (or clicking any socket) opens a list of the gems in the bags;
--      clicking a gem sockets it into that exact socket.
--
--  5.4.8 notes:
--   - socket counts come from GetItemStats (EMPTY_SOCKET_*) and the gem IDs in
--     the item link (no C_Item.GetItemNumSockets);
--   - the gem goes in through Blizzard's own socketing window
--     (SocketInventoryItem -> ClickSocketButton -> AcceptSockets). When the
--     socket already holds a gem (it would be destroyed) or the item is
--     refundable / trade-bound, the window stays open with the gem placed
--     and the player confirms with Blizzard's Socket button and dialogs;
--   - no proc glow library: the hovered socket's gear slot gets a pulsing
--     accent edge instead; no Great Vault / Midnight folio shortcuts.
-------------------------------------------------------------------------------
local addonName = ...
local ns = EllesmereUI
local BS = ns.BlizzSkin
local WSkin = ns.WSkin
local PP = BS.PP

BS.defaults.charSheetSocketPanel = true

-------------------------------------------------------------------------------
--  1) Gem Socketing window
-------------------------------------------------------------------------------
do
	local WIN = "socket"

	-- One socket: Blizzard's socket art (ring, color, brackets, shine) stays;
	-- the side flourishes and the big metal plate around it fade.
	local function SkinSocket(btn)
		if not btn then
			return
		end
		local name = btn:GetName()
		for _, k in ipairs({ "Left", "Right" }) do
			local t = name and _G[name .. k]
			if t and t.SetAlpha then
				t:SetAlpha(0)
			end
		end
		local w = btn:GetWidth() or 40
		local regions = { btn:GetRegions() }
		for i = 1, #regions do
			local r = regions[i]
			if r and r.IsObjectType and r:IsObjectType("Texture") and r ~= btn.icon then
				local rw = r:GetWidth() or 0
				if rw > w + 12 then
					r:SetAlpha(0)
				end
			end
		end
		local d = WSkin.GetFFD(btn)
		if not d.sockBg then
			-- A dark square behind the gem so it reads on the flat backdrop.
			local bg = WSkin.SolidTex(btn, "BACKGROUND", 0.02, 0.02, 0.02, 0.6, -2)
			bg:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
			bg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
			d.sockBg = bg
		end
	end

	local function SkinSockets()
		for i = 1, (MAX_NUM_SOCKETS or 3) do
			SkinSocket(_G["ItemSocketingSocket" .. i])
		end
	end

	-- The item description is a tooltip: its box goes, the text stays.
	local function ClearDescriptionBox()
		local tip = ItemSocketingDescription
		if tip and tip.SetBackdropColor then
			tip:SetBackdropColor(0, 0, 0, 0)
			tip:SetBackdropBorderColor(0, 0, 0, 0)
		end
	end

	local function Skin_Socket()
		local f = ItemSocketingFrame
		if not f then
			return
		end
		WSkin.Shell(WIN, f)
		WSkin.RemovePortrait(f)
		if ItemSocketingFrameInset then
			WSkin.Inset(ItemSocketingFrameInset)
		end
		WSkin.FadeKeyedArt(f)
		WSkin.FadeArtIn(f)
		WSkin.CommonChrome(f, "ItemSocketingFrame")
		-- Scroll frame gold track (named pieces on the scroll frame).
		WSkin.FadeNamed(ItemSocketingScrollFrame, { "Top", "Bottom", "Middle" })
		if ItemSocketingScrollFrameScrollBar then
			WSkin.ScrollBar(ItemSocketingScrollFrameScrollBar)
		end
		if ItemSocketingSocketButton then
			WSkin.Button(ItemSocketingSocketButton)
			WSkin.StateButtonLabel(ItemSocketingSocketButton)
		end
		SkinSockets()
		ClearDescriptionBox()

		-- Blizzard re-lays the sockets and repaints the button on every update.
		local deferred = WSkin.Debounce(function()
			if f:IsVisible() then
				SkinSockets()
				ClearDescriptionBox()
				WSkin.Restrip(WIN)
			end
		end)
		if ItemSocketingFrame_Update then
			hooksecurefunc("ItemSocketingFrame_Update", deferred)
		end
		WSkin.HookShow(f, deferred)
	end

	WSkin.RegisterWindow({
		key = WIN,
		label = "Gem Socketing",
		description = "The gem socketing window with squared gem slots.",
		order = 160,
		addons = { Blizzard_ItemSocketingUI = true },
		elvui = "socket",
		apply = Skin_Socket,
	})
end

-------------------------------------------------------------------------------
--  2) Character sheet socket panel
-------------------------------------------------------------------------------
do
	local SIZE, PAD = 28, 4
	local MAX_SOCKET_ICONS = 6
	local PAGE_BUTTON_W = 12
	local ROW_H, FLYOUT_W, MAX_FLYOUT_ROWS = 20, 240, 12
	local FLY_PAD = 4
	local EMPTY_SOCKET_TEX = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Prismatic"
	local STOCK = false

	-- Character sheet order: left column, right column, then weapons.
	local SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17 }
	local SLOT_BUTTONS = {
		[1] = "CharacterHeadSlot", [2] = "CharacterNeckSlot", [3] = "CharacterShoulderSlot",
		[5] = "CharacterChestSlot", [6] = "CharacterWaistSlot", [7] = "CharacterLegsSlot",
		[8] = "CharacterFeetSlot", [9] = "CharacterWristSlot", [10] = "CharacterHandsSlot",
		[11] = "CharacterFinger0Slot", [12] = "CharacterFinger1Slot", [13] = "CharacterTrinket0Slot",
		[14] = "CharacterTrinket1Slot", [15] = "CharacterBackSlot", [16] = "CharacterMainHandSlot",
		[17] = "CharacterSecondaryHandSlot",
	}
	local EMPTY_SOCKET_TEXTURES = {
		EMPTY_SOCKET_META = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Meta",
		EMPTY_SOCKET_RED = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Red",
		EMPTY_SOCKET_YELLOW = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Yellow",
		EMPTY_SOCKET_BLUE = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Blue",
		EMPTY_SOCKET_PRISMATIC = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Prismatic",
		EMPTY_SOCKET_NO_COLOR = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Prismatic",
		EMPTY_SOCKET_COGWHEEL = "Interface\\ItemSocketingFrame\\UI-EmptySocket-CogWheel",
		EMPTY_SOCKET_HYDRAULIC = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Hydraulic",
	}

	local sockets = {}   -- { slot, socketIndex, gemLink, emptyName, emptyTex }
	local iconPool = {}
	local gemCache = {}  -- { itemID, link, tex }
	local gemRows = {}
	local pending        -- in-flight socket action
	local panel, flyout, catcher, evtFrame, slotGlow
	local built, shownEvents = false, false
	local gemDirty = true
	local activeIcon
	local socketPage = 0
	local prevPage, nextPage
	local flyoutScroll = 0
	local flyoutHoverMode = false
	local ourSession = false
	local GEM_CLASS

	local function FontPath()
		return BS.FontPath()
	end

	local function GemBorderColor(quality)
		if (quality or 0) >= 3 then
			return 1, 0.82, 0, 1
		end
		return 0.75, 0.75, 0.75, 1
	end

	local function GemClassName()
		if GEM_CLASS == nil then
			GEM_CLASS = false
			if GetAuctionItemClasses then
				local classes = { GetAuctionItemClasses() }
				GEM_CLASS = classes[8] or false
			end
		end
		return GEM_CLASS
	end

	local function GemIDFromLink(link, idx)
		local itemString = link:match("item:([%-%d:]+)")
		if not itemString then
			return nil
		end
		local gid = tonumber((select(idx + 2, strsplit(":", itemString))))
		if gid and gid > 0 then
			return gid
		end
		return nil
	end

	-- "+160 Critical Strike" style summary of a gem's stats.
	local function GemStatText(gemLink)
		if not gemLink then
			return ""
		end
		local parts
		local stats = GetItemStats(gemLink)
		if stats then
			for key, val in pairs(stats) do
				if type(key) == "string" and type(val) == "number" and val > 0 and key:find("^ITEM_MOD_") then
					local name = _G[key]
					if type(name) == "string" and name ~= "" then
						parts = parts or {}
						parts[#parts + 1] = "+" .. val .. " " .. name
					end
				end
			end
		end
		if parts and #parts > 0 then
			table.sort(parts)
			return table.concat(parts, " & ")
		end
		return (GetItemInfo(gemLink)) or "Gem"
	end

	local function FindBagSlotForItem(itemID)
		for bag = 0, (NUM_BAG_SLOTS or 4) do
			for slot = 1, (GetContainerNumSlots(bag) or 0) do
				if GetContainerItemID(bag, slot) == itemID then
					return bag, slot
				end
			end
		end
		return nil
	end

	local function ScanBagGems()
		wipe(gemCache)
		local gemType = GemClassName()
		local seen = {}
		for bag = 0, (NUM_BAG_SLOTS or 4) do
			for slot = 1, (GetContainerNumSlots(bag) or 0) do
				local itemID = GetContainerItemID(bag, slot)
				if itemID and not seen[itemID] then
					local _, link, _, _, _, itemType, _, _, _, tex = GetItemInfo(itemID)
					if itemType and gemType and itemType == gemType then
						seen[itemID] = true
						gemCache[#gemCache + 1] = {
							itemID = itemID,
							link = GetContainerItemLink(bag, slot) or link,
							tex = tex or (GetItemIcon and GetItemIcon(itemID)),
						}
					end
				end
			end
		end
		gemDirty = false
	end

	---------------------------------------------------------------------------
	--  Socket action (event driven)
	---------------------------------------------------------------------------
	local socketWindowSeated = false
	local function SeatSocketWindow()
		if socketWindowSeated then
			return true
		end
		if not (ItemSocketingFrame and SetUIPanelAttribute) then
			return false
		end
		socketWindowSeated = true
		-- Same rank as the sheet: the socketing window opens beside it.
		SetUIPanelAttribute(ItemSocketingFrame, "pushable", 3)
		return true
	end

	-- End a session the way the player does: hide the window.
	local function SafeCloseSession()
		local f = ItemSocketingFrame
		if f and f:IsShown() then
			if not InCombatLockdown() then
				HideUIPanel(f)
			end
		elseif CloseSocketInfo then
			CloseSocketInfo()
		end
	end

	local RebuildSockets, LayoutSockets, CloseFlyout, OpenFlyout, MaybeCloseHoverFlyout

	local function Notify(msg)
		if UIErrorsFrame then
			UIErrorsFrame:AddMessage(msg, 1, 0.1, 0.1)
		end
	end

	local function DoSocket(targetSlot, socketIndex, gemItemID)
		if InCombatLockdown() then
			Notify(ERR_NOT_IN_COMBAT or "Can't do that in combat.")
			return
		end
		if CursorHasItem() then
			return
		end
		if ItemSocketingFrame and ItemSocketingFrame:IsShown() then
			if pending then
				return
			end
			if ourSession then
				SafeCloseSession()
			end
			return -- a session the player opened: never hijack it
		end
		pending = { slot = targetSlot, socketIndex = socketIndex, gemItemID = gemItemID }
		ourSession = true
		SocketInventoryItem(targetSlot)
		CloseFlyout()
	end

	-- Accept once the session shows the gem in the socket, unless Blizzard's
	-- confirmations are needed (a gem would be destroyed, refundable items).
	local function AcceptPlacedGem()
		if not pending or pending.accepted then
			return
		end
		if GetNewSocketInfo(pending.socketIndex) then
			pending.accepted = true
			local destroys = GetExistingSocketInfo(pending.socketIndex)
			local confirm = destroys
				or (GetSocketItemRefundable and GetSocketItemRefundable())
				or (GetSocketItemBoundTradeable and GetSocketItemBoundTradeable())
				or (HasBoundGemProposed and HasBoundGemProposed())
			if confirm then
				-- The player confirms with the window's Socket button.
				pending = nil
				ourSession = false
				return
			end
			AcceptSockets()
		end
	end

	local function OnSocketInfoUpdate()
		if not pending then
			return
		end
		if pending.acted then
			AcceptPlacedGem()
			return
		end
		local nSock = GetNumSockets()
		if not nSock or pending.socketIndex > nSock then
			return
		end
		pending.acted = true
		local bag, slot = FindBagSlotForItem(pending.gemItemID)
		if not bag then
			pending = nil
			SafeCloseSession()
			return
		end
		PickupContainerItem(bag, slot)
		ClickSocketButton(pending.socketIndex)
		ClearCursor()
		AcceptPlacedGem()
	end

	---------------------------------------------------------------------------
	--  Hovered socket: its gear slot pulses with an accent edge
	---------------------------------------------------------------------------
	local function StopSlotGlow()
		if slotGlow then
			slotGlow:Hide()
		end
	end

	local function StartSlotGlow(slotID)
		local btn = _G[SLOT_BUTTONS[slotID] or ""]
		if not btn then
			return
		end
		if not slotGlow then
			slotGlow = CreateFrame("Frame", nil, CharacterFrame)
			PP.CreateBorder(slotGlow, 1, 1, 1, 1, 2, "OVERLAY", 7)
			slotGlow:SetScript("OnUpdate", function(self)
				self:SetAlpha(0.35 + 0.65 * (0.5 + 0.5 * math.sin(GetTime() * math.pi / 0.6)))
			end)
		end
		local r, g, b = BS.Accent()
		PP.SetBorderColor(slotGlow, r, g, b, 1)
		slotGlow:ClearAllPoints()
		slotGlow:SetPoint("TOPLEFT", btn, "TOPLEFT", -2, 2)
		slotGlow:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 2, -2)
		slotGlow:SetFrameLevel(btn:GetFrameLevel() + 6)
		slotGlow:Show()
	end

	---------------------------------------------------------------------------
	--  Socket icons
	---------------------------------------------------------------------------
	local function PaintIcon(btn, rec)
		local icon = btn.icon
		if rec.gemLink then
			local id = tonumber(rec.gemLink:match("item:(%d+)"))
			local tex = (GetItemIcon and id and GetItemIcon(id)) or select(10, GetItemInfo(rec.gemLink))
			icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
			btn:SetAlpha(1)
			local quality = select(3, GetItemInfo(rec.gemLink)) or 2
			if STOCK then
				btn:SetBackdropBorderColor(GemBorderColor(quality))
			else
				PP.SetBorderColor(btn, GemBorderColor(quality))
			end
		else
			icon:SetTexture(rec.emptyTex or EMPTY_SOCKET_TEX)
			if STOCK then
				btn:SetAlpha(1)
				btn:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
			else
				btn:SetAlpha(0.85)
				PP.SetBorderColor(btn, 1, 1, 1, 0.4)
			end
		end
	end

	local recOf = setmetatable({}, { __mode = "k" })

	local function CreatePanelIcon(parent)
		local btn = CreateFrame("Button", nil, parent)
		btn:SetSize(SIZE, SIZE)
		local icon = btn:CreateTexture(nil, "ARTWORK")
		btn.icon = icon
		if STOCK then
			-- Blizzard look: the icon inside a tooltip-style edge.
			btn:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
			icon:SetPoint("TOPLEFT", 3, -3)
			icon:SetPoint("BOTTOMRIGHT", -3, 3)
			local hov = btn:CreateTexture(nil, "HIGHLIGHT")
			hov:SetAllPoints(icon)
			hov:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
			hov:SetBlendMode("ADD")
		else
			icon:SetAllPoints(btn)
			icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
			PP.CreateBorder(btn, 1, 1, 1, 0.4, 1, "OVERLAY", 7)
			local hov = btn:CreateTexture(nil, "HIGHLIGHT")
			hov:SetAllPoints(btn)
			hov:SetTexture(1, 1, 1, 0.1)
		end
		return btn
	end

	local function AcquireIcon(i)
		local btn = iconPool[i]
		if btn then
			return btn
		end
		btn = CreatePanelIcon(panel)
		btn:SetScript("OnEnter", function(self)
			local rec = recOf[self]
			if not rec then
				return
			end
			StartSlotGlow(rec.slot)
			-- An empty socket suggests gems on hover; a filled one needs a
			-- click (the old gem would be destroyed).
			if not rec.gemLink and not InCombatLockdown() then
				local open = flyout and flyout:IsShown()
				if not (open and (activeIcon == self or not flyoutHoverMode)) then
					OpenFlyout(self, rec.slot, rec.socketIndex, true)
				end
			end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			if rec.gemLink then
				GameTooltip:SetHyperlink(rec.gemLink)
			else
				GameTooltip:SetText(rec.emptyName or "Empty Socket", 1, 1, 1)
				GameTooltip:AddLine("Pick a gem from the list to socket it.", 0.8, 0.8, 0.8, true)
			end
			GameTooltip:Show()
		end)
		btn:SetScript("OnLeave", function()
			StopSlotGlow()
			MaybeCloseHoverFlyout()
			GameTooltip:Hide()
		end)
		btn:SetScript("OnClick", function(self)
			local rec = recOf[self]
			if not rec then
				return
			end
			if InCombatLockdown() then
				Notify(ERR_NOT_IN_COMBAT or "Can't do that in combat.")
				return
			end
			if activeIcon == self and flyout and flyout:IsShown() then
				if flyoutHoverMode then
					flyoutHoverMode = false
					if catcher then catcher:Show() end
					return
				end
				CloseFlyout()
				return
			end
			OpenFlyout(self, rec.slot, rec.socketIndex)
		end)
		iconPool[i] = btn
		return btn
	end

	-- Every socket of the equipped gear, in sheet order.
	RebuildSockets = function()
		wipe(sockets)
		for _, slot in ipairs(SLOTS) do
			local link = GetInventoryItemLink("player", slot)
			if link then
				local stats = GetItemStats(link)
				local total, emptyName, emptyTex, types = 0, nil, nil, 0
				if stats then
					for key, count in pairs(stats) do
						if type(key) == "string" and EMPTY_SOCKET_TEXTURES[key] and count and count > 0 then
							total = total + count
							types = types + 1
							emptyName = _G[key] or "Empty Socket"
							emptyTex = EMPTY_SOCKET_TEXTURES[key]
						end
					end
				end
				if types > 1 then
					emptyName, emptyTex = "Empty Socket", EMPTY_SOCKET_TEX
				end
				-- Extra sockets (belt buckle, blacksmith) only show once filled.
				local last = total
				for idx = 1, 4 do
					if GemIDFromLink(link, idx) then
						last = math.max(last, idx)
					end
				end
				for idx = 1, last do
					local _, gemLink = GetItemGem(link, idx)
					if not gemLink then
						local gid = GemIDFromLink(link, idx)
						if gid then
							gemLink = "item:" .. gid
						end
					end
					sockets[#sockets + 1] = {
						slot = slot,
						socketIndex = idx,
						gemLink = gemLink,
						emptyName = emptyName or "Empty Socket",
						emptyTex = emptyTex,
					}
				end
			end
		end
		LayoutSockets()
	end

	local function ChangeSocketPage(delta)
		local last = math.max(0, math.ceil(#sockets / (MAX_SOCKET_ICONS - 1)) - 1)
		local page = math.max(0, math.min(last, socketPage + delta))
		if page == socketPage then
			return
		end
		CloseFlyout()
		StopSlotGlow()
		GameTooltip:Hide()
		socketPage = page
		LayoutSockets()
	end

	local function BuildPageButton(text, delta, tip)
		local btn = CreateFrame("Button", nil, panel)
		btn:SetSize(PAGE_BUTTON_W, SIZE)
		local label = btn:CreateFontString(nil, "OVERLAY")
		label:SetFont(FontPath(), 12, "")
		label:SetAllPoints(btn)
		label:SetText(text)
		if STOCK then
			label:SetTextColor(1, 0.82, 0)
		end
		btn:SetScript("OnClick", function() ChangeSocketPage(delta) end)
		btn:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(tip, 1, 1, 1)
			GameTooltip:Show()
		end)
		btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
		return btn
	end

	-- Room for the char sheet's footer durability text, right of the strip.
	local measure
	local function FooterDurabilityWidth()
		local db = ns.GetCharSheetDB and ns.GetCharSheetDB()
		if STOCK or not db or not db.showDurability or db.durabilityLocation ~= "footer" then
			return 0
		end
		if not measure then
			measure = (panel or CharacterFrame):CreateFontString(nil, "OVERLAY")
			BS.SetFont(measure, 12)
			measure:Hide()
		end
		local text = db.durabilityShowLabel and ((DURABILITY or "Durability") .. ": 100%") or "100%"
		measure:SetText(text)
		return (measure:GetStringWidth() or 60) + 10
	end

	LayoutSockets = function()
		if not panel then
			return
		end
		panel:ClearAllPoints()
		if STOCK then
			panel:SetPoint("TOPRIGHT", CharacterFrame, "BOTTOMRIGHT", -15, 2)
		else
			panel:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT", -10 - FooterDurabilityWidth(), 6)
		end
		local count = #sockets
		local paged = count > MAX_SOCKET_ICONS
		local perPage = paged and (MAX_SOCKET_ICONS - 1) or MAX_SOCKET_ICONS
		local last = math.max(0, math.ceil(count / perPage) - 1)
		socketPage = math.min(socketPage, last)
		local first = socketPage * perPage
		local visible = math.max(0, math.min(perPage, count - first))
		if activeIcon then
			local old = recOf[activeIcon]
			local keep = false
			for i = 1, visible do
				local rec = sockets[first + i]
				if activeIcon == iconPool[i] and old and old.slot == rec.slot and old.socketIndex == rec.socketIndex then
					keep = true
					break
				end
			end
			if not keep then
				CloseFlyout()
				StopSlotGlow()
			end
		end
		if paged and not prevPage then
			prevPage = BuildPageButton("<", -1, "Previous sockets")
			nextPage = BuildPageButton(">", 1, "Next sockets")
		end
		local edge = STOCK and 8 or 0
		if prevPage then
			prevPage:ClearAllPoints()
			prevPage:SetPoint("LEFT", panel, "LEFT", edge, 0)
			nextPage:ClearAllPoints()
			nextPage:SetPoint("RIGHT", panel, "RIGHT", -edge, 0)
			prevPage:SetShown(paged)
			nextPage:SetShown(paged)
			prevPage:SetEnabled(socketPage > 0)
			nextPage:SetEnabled(socketPage < last)
			prevPage:SetAlpha(socketPage > 0 and 1 or 0.3)
			nextPage:SetAlpha(socketPage < last and 1 or 0.3)
		end
		for _, btn in ipairs(iconPool) do
			btn:Hide()
			recOf[btn] = nil
		end
		if count == 0 then
			panel:Hide()
			return
		end
		local contentW = 2 * edge + (paged and 2 * (PAGE_BUTTON_W + PAD) or 0) + (paged and perPage or visible) * (SIZE + PAD) - PAD
		for i = 1, visible do
			local rec = sockets[first + i]
			local btn = AcquireIcon(i)
			recOf[btn] = rec
			PaintIcon(btn, rec)
			btn:ClearAllPoints()
			btn:SetPoint("LEFT", panel, "LEFT", edge + (paged and (PAGE_BUTTON_W + PAD) or 0) + (i - 1) * (SIZE + PAD), 0)
			btn:Show()
		end
		panel:SetWidth(contentW)
		panel:Show()
	end

	---------------------------------------------------------------------------
	--  Gem flyout
	---------------------------------------------------------------------------
	local function AcquireGemRow(i)
		local row = gemRows[i]
		if row then
			return row
		end
		row = CreateFrame("Button", nil, flyout)
		row:SetHeight(ROW_H)
		local icon = row:CreateTexture(nil, "ARTWORK")
		icon:SetSize(ROW_H - 2, ROW_H - 2)
		icon:SetPoint("LEFT", row, "LEFT", 2, 0)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		row.icon = icon
		local label = row:CreateFontString(nil, "OVERLAY")
		label:SetFont(FontPath(), 11, "")
		label:SetPoint("LEFT", icon, "RIGHT", 5, 0)
		label:SetPoint("RIGHT", row, "RIGHT", -34, 0)
		label:SetJustifyH("LEFT")
		label:SetWordWrap(false)
		row.label = label
		local count = row:CreateFontString(nil, "OVERLAY")
		count:SetFont(FontPath(), 11, "")
		count:SetPoint("RIGHT", row, "RIGHT", -6, 0)
		count:SetJustifyH("RIGHT")
		count:SetTextColor(0.7, 0.7, 0.7)
		row.count = count
		local hov = row:CreateTexture(nil, "HIGHLIGHT")
		hov:SetAllPoints(row)
		if STOCK then
			hov:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
			hov:SetBlendMode("ADD")
		else
			hov:SetTexture(1, 1, 1, 0.1)
		end
		row:SetScript("OnEnter", function(self)
			if not self.gemLink then
				return
			end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetHyperlink(self.gemLink)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", function()
			GameTooltip:Hide()
			MaybeCloseHoverFlyout()
		end)
		row:SetScript("OnClick", function(self)
			if self.gemItemID and flyout.targetSlot then
				DoSocket(flyout.targetSlot, flyout.targetSocketIndex, self.gemItemID)
			end
		end)
		gemRows[i] = row
		return row
	end

	local function PopulateFlyout()
		if gemDirty then
			ScanBagGems()
		end
		for _, row in ipairs(gemRows) do
			row:Hide()
			row.gemItemID, row.gemLink = nil, nil
		end
		local n = #gemCache
		local shown = 0
		if n == 0 then
			local row = AcquireGemRow(1)
			row.icon:SetTexture(nil)
			row.label:SetText("No gems in bags.")
			row.label:SetTextColor(0.5, 0.5, 0.5)
			row.count:SetText("")
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", flyout, "TOPLEFT", FLY_PAD, -FLY_PAD)
			row:SetPoint("TOPRIGHT", flyout, "TOPRIGHT", -FLY_PAD, -FLY_PAD)
			row:Show()
			shown = 1
		else
			local visible = math.min(n, MAX_FLYOUT_ROWS)
			flyoutScroll = math.max(0, math.min(n - visible, flyoutScroll))
			for vis = 1, visible do
				local g = gemCache[flyoutScroll + vis]
				local row = AcquireGemRow(vis)
				row.icon:SetTexture(g.tex)
				row.label:SetTextColor(1, 1, 1)
				row.label:SetText(g.link and GemStatText(g.link) or "Loading...")
				row.count:SetText((GetItemCount(g.itemID) or 1) .. "x")
				row.gemItemID, row.gemLink = g.itemID, g.link
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", flyout, "TOPLEFT", FLY_PAD, -FLY_PAD - (vis - 1) * ROW_H)
				row:SetPoint("TOPRIGHT", flyout, "TOPRIGHT", -FLY_PAD, -FLY_PAD - (vis - 1) * ROW_H)
				row:Show()
				shown = vis
			end
		end
		flyout:SetHeight(FLY_PAD * 2 + shown * ROW_H)
	end

	local function BuildFlyout()
		if flyout then
			return
		end
		catcher = CreateFrame("Button", nil, UIParent)
		catcher:SetAllPoints(UIParent)
		catcher:SetFrameStrata("FULLSCREEN")
		catcher:EnableMouse(true)
		catcher:RegisterForClicks("AnyUp")
		catcher:Hide()
		catcher:SetScript("OnClick", function() CloseFlyout() end)

		flyout = CreateFrame("Frame", "EUI_CharSheet_SocketFlyout", UIParent)
		flyout:SetWidth(FLYOUT_W)
		flyout:SetHeight(ROW_H + 8)
		flyout:SetFrameStrata("FULLSCREEN_DIALOG")
		flyout:Hide()
		if STOCK then
			flyout:SetBackdrop({
				bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
				edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
				tile = true, tileSize = 16, edgeSize = 16,
				insets = { left = 4, right = 4, top = 4, bottom = 4 },
			})
			flyout:SetBackdropColor(0, 0, 0, 0.92)
		else
			local bg = flyout:CreateTexture(nil, "BACKGROUND")
			bg:SetAllPoints(flyout)
			bg:SetTexture(0.06, 0.06, 0.06, 0.95)
			PP.CreateBorder(flyout, 0.2, 0.2, 0.2, 1, 1, "OVERLAY", 1)
		end
		flyout:EnableMouse(true)
		flyout:SetScript("OnLeave", function() MaybeCloseHoverFlyout() end)
		flyout:EnableMouseWheel(true)
		flyout:SetScript("OnMouseWheel", function(_, delta)
			if #gemCache <= MAX_FLYOUT_ROWS then
				return
			end
			flyoutScroll = flyoutScroll - delta
			PopulateFlyout()
		end)
		flyout:EnableKeyboard(true)
		flyout:SetScript("OnKeyDown", function(self, key)
			if InCombatLockdown() then
				return
			end
			if key == "ESCAPE" then
				self:SetPropagateKeyboardInput(false)
				CloseFlyout()
			else
				self:SetPropagateKeyboardInput(true)
			end
		end)
	end

	OpenFlyout = function(iconBtn, targetSlot, targetSocketIndex, hoverMode)
		BuildFlyout()
		CloseFlyout()
		flyoutHoverMode = hoverMode and true or false
		flyout.targetSlot = targetSlot
		flyout.targetSocketIndex = targetSocketIndex
		activeIcon = iconBtn
		flyoutScroll = 0
		PopulateFlyout()
		flyout:ClearAllPoints()
		local h = flyout:GetHeight() or 0
		local bottom = iconBtn:GetBottom() or 0
		if bottom - h - 6 < 0 then
			flyout:SetPoint("BOTTOMLEFT", iconBtn, "TOPLEFT", 0, 4)
		else
			flyout:SetPoint("TOPLEFT", iconBtn, "BOTTOMLEFT", 0, -4)
		end
		flyout:SetPropagateKeyboardInput(true)
		if not flyoutHoverMode then
			catcher:Show()
		end
		flyout:Show()
		if evtFrame then
			evtFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
		end
	end

	CloseFlyout = function()
		if flyout then flyout:Hide() end
		if catcher then catcher:Hide() end
		activeIcon = nil
		flyoutHoverMode = false
		if evtFrame then
			evtFrame:UnregisterEvent("PLAYER_REGEN_DISABLED")
		end
	end

	MaybeCloseHoverFlyout = function()
		if not flyoutHoverMode or not (flyout and flyout:IsShown()) then
			return
		end
		if flyout:IsMouseOver(8, -8, -8, 8) then
			return
		end
		if activeIcon and activeIcon:IsMouseOver() then
			return
		end
		CloseFlyout()
	end

	---------------------------------------------------------------------------
	--  Events (only while the Character tab shows)
	---------------------------------------------------------------------------
	local SHOWN_EVENTS = {
		"PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED", "SOCKET_INFO_UPDATE",
		"SOCKET_INFO_CLOSE", "SOCKET_INFO_SUCCESS", "SOCKET_INFO_FAILURE",
		"BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED",
	}

	local rebuildQueued = false
	local function QueueRebuild()
		if rebuildQueued then
			return
		end
		rebuildQueued = true
		BS.After(0.1, function()
			rebuildQueued = false
			if panel and PaperDollFrame and PaperDollFrame:IsVisible() then
				RebuildSockets()
			end
		end)
	end

	local function RegisterShownEvents()
		if shownEvents or not evtFrame then
			return
		end
		shownEvents = true
		for _, ev in ipairs(SHOWN_EVENTS) do
			pcall(evtFrame.RegisterEvent, evtFrame, ev)
		end
	end

	local function UnregisterShownEvents()
		if not (shownEvents and evtFrame) then
			return
		end
		shownEvents = false
		for _, ev in ipairs(SHOWN_EVENTS) do
			pcall(evtFrame.UnregisterEvent, evtFrame, ev)
		end
		evtFrame:UnregisterEvent("PLAYER_REGEN_DISABLED")
	end

	local function OnEvent(self, event, arg1)
		if event == "PLAYER_EQUIPMENT_CHANGED" then
			QueueRebuild()
		elseif event == "UNIT_INVENTORY_CHANGED" then
			if arg1 == "player" then
				QueueRebuild()
			end
		elseif event == "SOCKET_INFO_UPDATE" then
			OnSocketInfoUpdate()
		elseif event == "SOCKET_INFO_SUCCESS" or event == "SOCKET_INFO_FAILURE" then
			local ours = pending ~= nil
			pending = nil
			gemDirty = true
			if ours then
				SafeCloseSession()
			end
		elseif event == "SOCKET_INFO_CLOSE" then
			pending = nil
			ourSession = false
			gemDirty = true
			QueueRebuild()
		elseif event == "BAG_UPDATE_DELAYED" then
			gemDirty = true
			QueueRebuild()
			if flyout and flyout:IsShown() then
				PopulateFlyout()
			end
		elseif event == "GET_ITEM_INFO_RECEIVED" then
			gemDirty = true
			if flyout and flyout:IsShown() then
				PopulateFlyout()
			end
			QueueRebuild()
		elseif event == "PLAYER_REGEN_DISABLED" then
			CloseFlyout()
		elseif event == "ADDON_LOADED" then
			if arg1 == "Blizzard_ItemSocketingUI" then
				SeatSocketWindow()
				self:UnregisterEvent("ADDON_LOADED")
			end
		end
	end

	local function BuildPanel()
		if built then
			return
		end
		built = true
		panel = CreateFrame("Frame", "EUI_CharSheet_SocketPanel", CharacterFrame)
		if STOCK then
			-- Hangs below Blizzard's sheet, bottom right, like the tabs on the left.
			panel:SetHeight(SIZE + 12)
			panel:SetFrameLevel(CharacterFrame:GetFrameLevel() + 4)
			panel:EnableMouse(true)
			panel:SetBackdrop({
				bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
				edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
				tile = true, tileSize = 16, edgeSize = 12,
				insets = { left = 3, right = 3, top = 3, bottom = 3 },
			})
			panel:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
			panel:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
		else
			panel:SetHeight(SIZE)
			panel:SetFrameLevel(CharacterFrame:GetFrameLevel() + 20)
		end
		panel:SetWidth(SIZE)
		panel:Hide()
		if not evtFrame then
			evtFrame = CreateFrame("Frame")
			evtFrame:SetScript("OnEvent", OnEvent)
		end
		if not SeatSocketWindow() then
			evtFrame:RegisterEvent("ADDON_LOADED")
		end
	end

	local function PanelOn()
		local style = ns.CharSheetStyleActive and ns.CharSheetStyleActive()
		return style and style ~= "off" and BS.Get("charSheetSocketPanel") ~= false
	end

	local function OnPaperDollShow()
		if not PanelOn() then
			if panel then panel:Hide() end
			return
		end
		BuildPanel()
		RegisterShownEvents()
		gemDirty = true
		RebuildSockets()
	end

	local function OnHideAll()
		StopSlotGlow()
		CloseFlyout()
		UnregisterShownEvents()
		if panel then panel:Hide() end
	end

	-- Live apply from the settings toggle (and the durability footer).
	BS.OnApply(function()
		if not (PaperDollFrame and PaperDollFrame:IsVisible()) then
			return
		end
		if PanelOn() then
			OnPaperDollShow()
		else
			OnHideAll()
		end
	end)

	BS.OnLogin(function()
		if not (CharacterFrame and PaperDollFrame) then
			return
		end
		STOCK = (ns.CharSheetStyleActive and ns.CharSheetStyleActive()) == "blizzard"
		if STOCK then
			SIZE, PAD = 26, 4
		end
		PaperDollFrame:HookScript("OnShow", OnPaperDollShow)
		PaperDollFrame:HookScript("OnHide", OnHideAll)
		CharacterFrame:HookScript("OnHide", OnHideAll)
	end)

	-- Character Sheet page: the panel's on / off switch.
	ns.BlizzSkinCharSheetOptions = ns.BlizzSkinCharSheetOptions or {}
	table.insert(ns.BlizzSkinCharSheetOptions, function(p)
		p:Section("Socket Panel")
		p:Toggle("Socket Panel", "Show a panel of equipped-gear sockets on the character sheet; click a socket to gem it. Hover an empty socket to see the gems in your bags.",
			function() return BS.Get("charSheetSocketPanel") ~= false end,
			function(v) BS.Set("charSheetSocketPanel", v and true or false) end,
			function()
				local cs = ns.GetCharSheetDB and ns.GetCharSheetDB()
				return cs and cs.style == "off"
			end)
	end)
end
