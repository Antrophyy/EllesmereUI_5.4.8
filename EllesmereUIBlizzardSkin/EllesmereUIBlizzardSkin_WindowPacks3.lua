-------------------------------------------------------------------------------
--  EllesmereUIBlizzardSkin_WindowPacks3.lua (5.4.8 port)
--  Window packs: loot window, loot toasts, Battle.net toast, loot roll
--  popups, loot rolls window, group invite popups, ready check, micro menu,
--  bag bar and the queue status panel. Port of the matching retail packs in
--  EllesmereUIBlizzardSkin_WindowPacks.lua / _BagBarForever.lua, rebuilt on
--  the 5.4.8 frames (named regions, backdrops, LootWonAlertFrame pools).
--
--  Every pack lives in its own do ... end block. Visual changes only: no
--  SetScript on Blizzard frames, no keys written onto Blizzard frames (state
--  lives in WSkin.GetFFD), no Show/Hide/SetParent of Blizzard frames.
-------------------------------------------------------------------------------
local addonName = ...
local ns = EllesmereUI
local BS = ns.BlizzSkin
local WSkin = ns.WSkin
if not (BS and WSkin and WSkin.RegisterWindow) then
	return
end

-- Shared helpers for the packs below (one table keeps the local count low).
local K = {}
K.GetFFD = WSkin.GetFFD
K.Theme = WSkin.Theme
K.PP = BS.PP
K.WHITE = BS.WHITE

-- A Blizzard parentKey child (frame or region), nil when absent.
function K.F(owner, key)
	local v = owner and owner[key]
	if type(v) == "table" then
		return v
	end
	return nil
end

-- ElvUI private toggles outside skins.blizzard (E.private.<group>.<key>).
function K.ElvPrivate(group, key)
	local E = ElvUI and ElvUI[1]
	local p = E and E.private
	local g = p and p[group]
	return (type(g) == "table" and g[key]) and true or false
end

-- 5.4.8 frames draw their art as a backdrop (not regions): make it clear.
function K.KillBackdrop(f)
	if f and f.GetBackdrop and f.SetBackdropColor and f:GetBackdrop() then
		f:SetBackdropColor(0, 0, 0, 0)
		f:SetBackdropBorderColor(0, 0, 0, 0)
	end
end

-- Clear a texture outright: alpha animations (toast glow / shine) drive the
-- alpha every frame, so SetAlpha(0) alone loses to them.
function K.ClearTex(t)
	if t and t.IsObjectType and t:IsObjectType("Texture") then
		t:SetTexture("")
		t:SetAlpha(0)
	end
end

-- Alpha a list of named art pieces (parentKey or $parent<key>), textures only.
function K.FadeKeys(frame, keys)
	if not frame then
		return
	end
	local name = frame.GetName and frame:GetName()
	for i = 1, #keys do
		local t = K.F(frame, keys[i]) or (name and _G[name .. keys[i]])
		if t and t.IsObjectType and t:IsObjectType("Texture") then
			t:SetAlpha(0)
		end
	end
end

-- Re-font a frame's own FontStrings, colors kept (quality colors are content).
function K.FontRegions(frame, skip)
	if not frame or not frame.GetRegions then
		return
	end
	local regions = { frame:GetRegions() }
	for i = 1, #regions do
		local r = regions[i]
		if r and r ~= skip and r.IsObjectType and r:IsObjectType("FontString") then
			WSkin.Font(r)
		end
	end
end

-- Style-aware shell on a frame of OURS one level under `frame`: the shell
-- swaps eui / modern live like any window, and Blizzard's own regions (icon,
-- text) stay untouched above it. Used where the Blizzard frame keeps content
-- textures we must not fade (toasts, popups shared with other dialogs).
function K.Host(winKey, frame, opts)
	local d = K.GetFFD(frame)
	local host = d.skinHost
	if not host then
		host = CreateFrame("Frame", nil, frame)
		host:SetAllPoints(frame)
		d.skinHost = host
	end
	host:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
	WSkin.Shell(winKey, host, opts)
	return host
end

-- Quality color for uncommon and up (common / poor -> nil, like retail's
-- chroma rule on the quality ring).
function K.QualityRGB(quality)
	if type(quality) ~= "number" or quality < 2 or not GetItemQualityColor then
		return nil
	end
	local r, g, b = GetItemQualityColor(quality)
	if type(r) ~= "number" then
		return nil
	end
	if (math.max(r, g, b) - math.min(r, g, b)) <= 0.1 then
		return nil
	end
	return r, g, b
end

-- Any StatusBar -> flat fill in the bar-fill color over a near-black trough.
function K.Bar(bar)
	if not bar or not bar.SetStatusBarTexture then
		return
	end
	local d = K.GetFFD(bar)
	bar:SetStatusBarTexture(K.WHITE)
	local fill = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
	if fill and fill ~= d.fill then
		d.fill = fill
		WSkin.FadeRegions(bar, { [fill] = true })
		WSkin.Register(bar, { [fill] = true })
	end
	if not d.bg then
		local bg = BS.SolidTex(bar, "BACKGROUND", 0, 0, 0, 0.55, -8)
		bg:SetAllPoints(bar)
		d.bg = bg
	end
	WSkin.ApplyBarFill(bar)
end

-- One physical pixel in a frame's units.
function K.OnePx(frame)
	local es = frame and frame.GetEffectiveScale and frame:GetEffectiveScale()
	local perfect = K.PP.perfect
	if es and es > 0 and perfect then
		return perfect / es
	end
	return 1
end

-------------------------------------------------------------------------------
--  Loot window (LootFrame, ButtonFrameTemplate). Rows (LootButton1..4) keep
--  their item quality colors: names are re-fonted, never re-colored. Icons
--  squared with the action bar zoom and a quality colored 1px border.
-------------------------------------------------------------------------------
do
	local LT = { ZOOM = 0.135, ROW_W = 100 }

	function LT.SkinRow(index)
		local n = "LootButton" .. index
		local btn = _G[n]
		if not btn then
			return
		end
		local icon = _G[n .. "IconTexture"] or K.F(btn, "icon")
		if icon and icon.SetTexCoord then
			icon:SetTexCoord(LT.ZOOM, 1 - LT.ZOOM, LT.ZOOM, 1 - LT.ZOOM)
		end
		local d = K.GetFFD(btn)
		if d.lootRow then
			return
		end
		d.lootRow = true
		local nt = btn.GetNormalTexture and btn:GetNormalTexture()
		if nt and nt ~= icon then
			nt:SetAlpha(0)
		end
		K.FadeKeys(btn, { "NameFrame" })
		if icon then
			local bg = BS.SolidTex(btn, "BACKGROUND", 0.02, 0.02, 0.02, 0.6, -1)
			bg:SetAllPoints(icon)
			d.bg = bg
			WSkin.QualityBorder(btn, icon, 0, 0, 0)
			local pt = btn.GetPushedTexture and btn:GetPushedTexture()
			if pt then
				pt:SetTexture(1, 1, 1, 0.12)
				pt:SetAllPoints(icon)
			end
		end
		-- Flat hover wash over the whole row (icon + name), not the ring.
		local hl = btn.GetHighlightTexture and btn:GetHighlightTexture()
		if hl then
			hl:SetTexture(1, 1, 1, 0.08)
			hl:SetTexCoord(0, 1, 0, 1)
			hl:SetBlendMode("BLEND")
			hl:ClearAllPoints()
			hl:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
			hl:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", LT.ROW_W, 0)
		end
		-- Stack count keeps Blizzard's outlined number font.
		local text = _G[n .. "Text"]
		if text then
			WSkin.Font(text)
		end
	end

	-- Quality border of one row, from the loot slot it shows.
	function LT.PaintRow(index)
		local btn = _G["LootButton" .. index]
		local f = _G.LootFrame
		if not (btn and f) then
			return
		end
		LT.SkinRow(index)
		local icon = _G["LootButton" .. index .. "IconTexture"] or K.F(btn, "icon")
		if not icon then
			return
		end
		local r, g, b = 0, 0, 0
		local numItems = f.numLootItems or 0
		local numToShow = LOOTFRAME_NUMBUTTONS or 4
		if numItems > numToShow then
			numToShow = numToShow - 1
		end
		local slot = numToShow * ((f.page or 1) - 1) + index
		if slot <= numItems and LootSlotHasItem and LootSlotHasItem(slot) and GetLootSlotInfo then
			local _, _, _, quality = GetLootSlotInfo(slot)
			local qr, qg, qb = K.QualityRGB(quality)
			if qr then
				r, g, b = qr, qg, qb
			end
		end
		WSkin.QualityBorder(btn, icon, r, g, b)
	end

	function LT.Apply()
		local f = _G.LootFrame
		if not f then
			return
		end
		-- ElvUI's own loot frame replaces Blizzard's.
		if K.ElvPrivate("general", "loot") then
			return
		end
		WSkin.Shell("loot", f)
		WSkin.RemovePortrait(f)
		if _G.LootFramePortraitOverlay then
			_G.LootFramePortraitOverlay:SetAlpha(0)
		end
		if _G.LootFrameInset then
			WSkin.Inset(_G.LootFrameInset)
		end
		WSkin.FadeKeyedArt(f)
		WSkin.CommonChrome(f, "LootFrame")

		local d = K.GetFFD(f)
		if not d.lootTitle then
			d.lootTitle = true
			-- The "Items" title is an anonymous FontString on the frame.
			local regions = { f:GetRegions() }
			for i = 1, #regions do
				local r = regions[i]
				if r and r.IsObjectType and r:IsObjectType("FontString") then
					WSkin.Font(r)
					WSkin.White(r)
					local txt = r.GetText and r:GetText()
					if txt and txt == ITEMS and d.topBar then
						r:ClearAllPoints()
						r:SetPoint("CENTER", d.topBar, "CENTER", 0, 0)
					end
				end
			end
			for _, k in ipairs({ "LootFramePrev", "LootFrameNext" }) do
				local fs = _G[k]
				if fs then
					WSkin.Font(fs)
					WSkin.White(fs)
				end
			end
			if _G.LootFrameUpButton then
				WSkin.PageButton(_G.LootFrameUpButton, "<", 12)
				_G.LootFrameUpButton:SetSize(22, 22)
			end
			if _G.LootFrameDownButton then
				WSkin.PageButton(_G.LootFrameDownButton, ">", 12)
				_G.LootFrameDownButton:SetSize(22, 22)
			end
		end

		for i = 1, (LOOTFRAME_NUMBUTTONS or 4) do
			LT.PaintRow(i)
		end

		if not LT.hooked then
			LT.hooked = true
			if type(_G.LootFrame_UpdateButton) == "function" then
				hooksecurefunc("LootFrame_UpdateButton", WSkin.WindowCallback("loot", LT.PaintRow))
			end
			WSkin.HookShow(f, WSkin.Debounce(function()
				if f:IsVisible() then
					LT.Apply()
					WSkin.Restrip("loot")
				end
			end))
		end
	end

	WSkin.RegisterWindow({
		key = "loot",
		label = "Loot Window",
		description = "The loot window: item rows with squared icons, kept item quality colors.",
		order = 180,
		elvui = "loot",
		apply = LT.Apply,
	})
end

-------------------------------------------------------------------------------
--  Loot toasts: the "You Won" / "You received" alert popups. 5.4.8 keeps them
--  in two pools of anonymous frames (LOOT_WON_ALERT_FRAMES,
--  MONEY_WON_ALERT_FRAMES), set up by LootWonAlertFrame_SetUp and
--  MoneyWonAlertFrame_SetUp: both are post-hooked, so a pooled frame is
--  re-skinned every time it is reused. Item toasts take the money toast's
--  tighter size; a quality strip carries the rarity the icon ring had.
-------------------------------------------------------------------------------
do
	local TS = {
		W = 249, H = 71,      -- the money toast template's size
		ICON = 38,            -- its coin size
		ITEM_ART = { "Background", "IconBorder", "glow", "shine", "SpecRing" },
		MONEY_ART = { "Background", "IconBorder" },
	}

	function TS.Scale()
		local v = BS.DB().lootToastScale
		if type(v) ~= "number" or v <= 0 then
			return 1
		end
		return v
	end

	-- The left-edge rarity strip on its own frame above the shell border.
	function TS.Strip(t, d, on, r, g, b)
		if not d.stripHost then
			local host = CreateFrame("Frame", nil, t)
			host:SetAllPoints(t)
			d.stripHost = host
			local s = host:CreateTexture(nil, "OVERLAY", nil, 7)
			s:SetPoint("TOPLEFT", t, "TOPLEFT", 0, 0)
			s:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 0, 0)
			d.stripTex = s
		end
		d.stripHost:SetFrameLevel(t:GetFrameLevel() + 3)
		d.stripTex:SetWidth(2 * K.OnePx(t))
		if on and r then
			d.stripTex:SetTexture(r, g, b, 0.9)
			d.stripTex:Show()
		else
			d.stripTex:Hide()
		end
	end

	-- Quality color of what an item toast shows (item or currency link).
	function TS.LinkColor(link, isCurrency)
		if not link then
			return nil
		end
		local quality = nil
		if isCurrency then
			if GetCurrencyInfo then
				quality = select(8, GetCurrencyInfo(link))
			end
		elseif GetItemInfo then
			quality = select(3, GetItemInfo(link))
		end
		if type(quality) == "number" and quality >= 1 and GetItemQualityColor then
			return GetItemQualityColor(quality)
		end
		return nil
	end

	function TS.SkinItem(t, itemLink, isCurrency)
		if not t or BS.Forbidden(t) then
			return
		end
		local d = K.GetFFD(t)
		if itemLink then
			d.link, d.isCurrency = itemLink, isCurrency and true or false
		end
		K.Host("loottoast", t, { noTopBar = true })
		for _, k in ipairs(TS.ITEM_ART) do
			K.ClearTex(K.F(t, k))
		end
		t:SetScale(TS.Scale())
		t:SetSize(TS.W, TS.H)

		local icon = K.F(t, "Icon")
		if icon then
			icon:SetSize(TS.ICON, TS.ICON)
			icon:ClearAllPoints()
			icon:SetPoint("LEFT", t, "LEFT", 10, 0)
			WSkin.SquareIcon(icon, t)
		end
		local label, nameFS = K.F(t, "Label"), K.F(t, "ItemName")
		if label and icon then
			label:ClearAllPoints()
			label:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 1)
		end
		if nameFS and label then
			nameFS:ClearAllPoints()
			nameFS:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -1)
			nameFS:SetWidth(TS.W - 10 - TS.ICON - 8 - 8)
			nameFS:SetHeight(26)
			nameFS:SetJustifyH("LEFT")
		end
		-- Roll result in the top right corner, spec badge in the bottom right.
		if K.F(t, "RollTypeIcon") then
			K.F(t, "RollTypeIcon"):ClearAllPoints()
			K.F(t, "RollTypeIcon"):SetPoint("TOPRIGHT", t, "TOPRIGHT", -6, -5)
		end
		local spec = K.F(t, "SpecIcon")
		if spec then
			spec:SetSize(18, 18)
			spec:ClearAllPoints()
			spec:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -6, 6)
			spec:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end
		for _, k in ipairs({ "Label", "ItemName", "RollValue" }) do
			if K.F(t, k) then
				WSkin.Font(K.F(t, k))
			end
		end
		local on = BS.DB().lootToastQualityStrip ~= false
		local r, g, b = TS.LinkColor(d.link, d.isCurrency)
		TS.Strip(t, d, on, r or 1, g or 1, b or 1)
	end

	function TS.SkinMoney(t)
		if not t or BS.Forbidden(t) then
			return
		end
		local d = K.GetFFD(t)
		K.Host("loottoast", t, { noTopBar = true })
		for _, k in ipairs(TS.MONEY_ART) do
			K.ClearTex(K.F(t, k))
		end
		t:SetScale(TS.Scale())
		if K.F(t, "Icon") then
			WSkin.SquareIcon(K.F(t, "Icon"), t)
		end
		-- "You received" header 2px down, like the item toast nudge.
		local hdr = K.F(t, "Label")
		if hdr then
			if not d.hdrPt then
				local p, rel, rp, x, y = hdr:GetPoint(1)
				if p then
					d.hdrPt = { p, rel, rp, x or 0, y or 0 }
				end
			end
			if d.hdrPt then
				hdr:ClearAllPoints()
				hdr:SetPoint(d.hdrPt[1], d.hdrPt[2], d.hdrPt[3], d.hdrPt[4], d.hdrPt[5] - 2)
			end
		end
		for _, k in ipairs({ "Label", "Amount" }) do
			if K.F(t, k) then
				WSkin.Font(K.F(t, k))
			end
		end
		local on = BS.DB().lootToastQualityStripMoney == true
		TS.Strip(t, d, on, 1, 0.82, 0)
	end

	-- Re-skin every pooled toast (settings changed: strip, scale).
	function TS.Refresh()
		if type(LOOT_WON_ALERT_FRAMES) == "table" then
			for _, t in ipairs(LOOT_WON_ALERT_FRAMES) do
				pcall(TS.SkinItem, t)
			end
		end
		if type(MONEY_WON_ALERT_FRAMES) == "table" then
			for _, t in ipairs(MONEY_WON_ALERT_FRAMES) do
				pcall(TS.SkinMoney, t)
			end
		end
	end

	function TS.Apply()
		if TS.applied then
			return
		end
		TS.applied = true
		if type(_G.LootWonAlertFrame_SetUp) == "function" then
			hooksecurefunc("LootWonAlertFrame_SetUp", WSkin.WindowCallback("loottoast",
				function(frame, itemLink, _, _, _, _, isCurrency)
					TS.SkinItem(frame, itemLink, isCurrency)
				end))
		end
		if type(_G.MoneyWonAlertFrame_SetUp) == "function" then
			hooksecurefunc("MoneyWonAlertFrame_SetUp", WSkin.WindowCallback("loottoast", TS.SkinMoney))
		end
		BS.OnApply(function()
			if BS.GetWindowStyle("loottoast") ~= "off" then
				TS.Refresh()
			end
		end)
		TS.Refresh()
	end

	local function Off()
		return BS.GetWindowStyle("loottoast") == "off"
	end

	WSkin.RegisterWindow({
		key = "loottoast",
		label = "Loot Toasts",
		description = "The \"You received\" popups for loot, currency, and upgrades.",
		order = 190,
		elvui = "alertframes",
		apply = TS.Apply,
		options = function(p)
			p:Toggle("Quality Strip",
				"Adds a strip down the left edge of a loot toast in the item's quality color. The flat skin drops Blizzard's quality ring around the icon, so this puts that rarity cue back.",
				function() return BS.DB().lootToastQualityStrip ~= false end,
				function(v) BS.DB().lootToastQualityStrip = v and true or false end,
				Off)
			p:Toggle("Gold Toast Strip",
				"Also show the strip on gold toasts, in the header's gold color. Gold has no rarity to signal, so this is off by default.",
				function() return BS.DB().lootToastQualityStripMoney == true end,
				function(v) BS.DB().lootToastQualityStripMoney = v and true or false end,
				Off)
			p:Slider("Toast Scale", "Scales the loot and gold toasts (percent).", 50, 150, 5,
				function() return math.floor(TS.Scale() * 100 + 0.5) end,
				function(v) BS.DB().lootToastScale = v / 100 end,
				Off)
		end,
	})
end

-------------------------------------------------------------------------------
--  Battle.net toast (BNToastFrame): a friend online / offline, broadcasts and
--  invites. Its art is a backdrop: cleared, the shell sits under the frame so
--  the toast-type icon (a crop of one sheet) stays exactly as Blizzard sets it.
-------------------------------------------------------------------------------
do
	local BN = {}

	function BN.Skin()
		local f = _G.BNToastFrame
		if not f or BS.Forbidden(f) then
			return
		end
		K.KillBackdrop(f)
		K.Host("bnettoast", f, { noTopBar = true })
		K.ClearTex(_G.BNToastFrameGlow)
		for _, k in ipairs({ "TopLine", "MiddleLine", "BottomLine", "DoubleLine" }) do
			local fs = _G["BNToastFrame" .. k]
			if fs then
				WSkin.Font(fs)
			end
		end
		if _G.BNToastFrameCloseButton then
			WSkin.CloseButton(_G.BNToastFrameCloseButton)
		end
		-- Hover panel for a truncated broadcast (tooltip backdrop).
		local tip = K.F(f, "TooltipFrame")
		if tip then
			K.KillBackdrop(tip)
			WSkin.Panel(tip)
			if K.F(tip, "Text") then
				WSkin.Font(K.F(tip, "Text"))
			end
		end
	end

	WSkin.RegisterWindow({
		key = "bnettoast",
		label = "Friend Notifications",
		description = "The Battle.net popup when a friend comes online or goes offline, plus broadcasts and invites.",
		order = 200,
		elvui = "misc",
		apply = function()
			local f = _G.BNToastFrame
			if not f then
				return
			end
			BN.Skin()
			WSkin.HookShow(f, WSkin.Debounce(BN.Skin))
		end,
	})
end

-------------------------------------------------------------------------------
--  Loot roll popups (GroupLootFrame1..4, plus the bonus roll prompt). Squared
--  item icon with a rarity border, flat roll timer. The roll buttons keep
--  Blizzard's dice / coin / shard glyphs (the popup's identity).
-------------------------------------------------------------------------------
do
	local LR = {}

	function LR.SkinRollFrame(f)
		if not f or BS.Forbidden(f) then
			return
		end
		WSkin.Shell("lootroll", f, { noTopBar = true })
		K.FadeKeys(f, { "Background", "Border" })

		local host = K.F(f, "IconFrame")
		local icon = host and K.F(host, "Icon")
		if host then
			K.FadeKeys(host, { "Border" })
			local nt = host.GetNormalTexture and host:GetNormalTexture()
			if nt and nt ~= icon then
				nt:SetAlpha(0)
			end
		end
		if icon and icon.SetTexCoord then
			WSkin.SquareIcon(icon)
			local r, g, b = 0, 0, 0
			if f.rollID and GetLootRollItemInfo then
				local _, _, _, quality = GetLootRollItemInfo(f.rollID)
				local qr, qg, qb = K.QualityRGB(quality)
				if qr then
					r, g, b = qr, qg, qb
				end
			end
			WSkin.QualityBorder(host, icon, r, g, b)
		end

		local timer = K.F(f, "Timer")
		if timer then
			K.Bar(timer)
			if timer:GetFrameLevel() <= f:GetFrameLevel() then
				timer:SetFrameLevel(f:GetFrameLevel() + 1)
			end
		end
		if K.F(f, "Name") then
			WSkin.Font(K.F(f, "Name"))
		end
	end

	-- Bonus roll: shell, squared item icon, flat timer above the shell.
	function LR.SkinBonusRoll()
		local f = _G.BonusRollFrame
		if not f or BS.Forbidden(f) then
			return
		end
		local d = K.GetFFD(f)
		-- The spec badge is a region of the frame: keep it out of the fade.
		if K.F(f, "SpecIcon") and not d.caret then
			d.caret = K.F(f, "SpecIcon")
		end
		WSkin.Shell("lootroll", f, { noTopBar = true })
		if K.F(f, "SpecRing") then
			K.ClearTex(K.F(f, "SpecRing"))
		end
		if K.F(f, "SpecIcon") then
			K.F(f, "SpecIcon"):SetTexCoord(0.08, 0.92, 0.08, 0.92)
		end
		local hoist = K.F(f, "BlackBackgroundHoist")
		if hoist and K.F(hoist, "Background") then
			K.F(hoist, "Background"):SetAlpha(0)
		end
		local prompt = K.F(f, "PromptFrame")
		if prompt then
			if K.F(prompt, "Icon") then
				WSkin.SquareIcon(K.F(prompt, "Icon"), prompt)
			end
			K.FadeKeys(prompt, { "IconBorder" })
			local ptimer = K.F(prompt, "Timer")
			if ptimer then
				K.Bar(ptimer)
				ptimer:SetFrameLevel(f:GetFrameLevel() + 2)
			end
			K.FontRegions(prompt)
			if K.F(prompt, "InfoFrame") then
				K.FontRegions(K.F(prompt, "InfoFrame"))
			end
		end
		if K.F(f, "CurrentCountFrame") then
			K.FontRegions(K.F(f, "CurrentCountFrame"))
		end
	end

	function LR.SkinAll()
		for i = 1, (NUM_GROUP_LOOT_FRAMES or 4) do
			LR.SkinRollFrame(_G["GroupLootFrame" .. i])
		end
	end

	function LR.Apply()
		-- ElvUI's own roll bars replace Blizzard's popups.
		if K.ElvPrivate("general", "lootRoll") then
			return
		end
		for i = 1, (NUM_GROUP_LOOT_FRAMES or 4) do
			local f = _G["GroupLootFrame" .. i]
			if f then
				WSkin.HookShow(f, function()
					LR.SkinRollFrame(f)
				end)
			end
		end
		local resweep = WSkin.Debounce(LR.SkinAll)
		if type(_G.GroupLootFrame_OpenNewFrame) == "function" then
			hooksecurefunc("GroupLootFrame_OpenNewFrame", resweep)
		end
		local ev = CreateFrame("Frame")
		ev:RegisterEvent("START_LOOT_ROLL")
		ev:SetScript("OnEvent", resweep)
		LR.SkinAll()

		local bonus = _G.BonusRollFrame
		if bonus then
			LR.SkinBonusRoll()
			WSkin.HookShow(bonus, WSkin.Debounce(LR.SkinBonusRoll))
		end
	end

	WSkin.RegisterWindow({
		key = "lootroll",
		label = "Loot Roll Popups",
		description = "The need / greed / pass roll popups, with a squared icon and a flat roll timer.",
		order = 210,
		elvui = "lootRoll",
		apply = LR.Apply,
	})
end

-------------------------------------------------------------------------------
--  Loot Rolls window (LootHistoryFrame): shell, centered title, flat scroll
--  bar, a slim grip for the resize button, item rows with squared icons and a
--  quality border, player rows re-fonted (class / quality colors kept).
-------------------------------------------------------------------------------
do
	local LH = { ROW_ART = { "Divider", "NameBorderLeft", "NameBorderRight", "NameBorderMid" } }

	function LH.SkinItemRow(row)
		if not row or BS.Forbidden(row) then
			return
		end
		local d = K.GetFFD(row)
		local icon = K.F(row, "Icon")
		local ring = K.F(row, "IconBorder")
		-- Rarity from Blizzard's own ring color, read every pass (rows are reused).
		local r, g, b = WSkin.RingQuality(ring)
		if ring then
			ring:SetAlpha(0)
		end
		if not d.lhRow then
			d.lhRow = true
			K.FadeKeys(row, LH.ROW_ART)
			local wash = BS.SolidTex(row, "BACKGROUND", 1, 1, 1, 0.03, -2)
			wash:SetPoint("TOPLEFT", row, "TOPLEFT", 20, -2)
			wash:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 2)
			d.bg = wash
			for _, k in ipairs({ "ItemName", "WinnerName", "WinnerRoll" }) do
				if K.F(row, k) then
					WSkin.Font(K.F(row, k))
				end
			end
		end
		if icon and icon.SetTexCoord then
			WSkin.SquareIcon(icon)
			WSkin.QualityBorder(row, icon, r or 0, g or 0, b or 0)
		end
	end

	function LH.SkinPlayerRow(row)
		if not row or BS.Forbidden(row) then
			return
		end
		local d = K.GetFFD(row)
		if d.lhPlayer then
			return
		end
		d.lhPlayer = true
		for _, k in ipairs({ "PlayerName", "RollText" }) do
			if K.F(row, k) then
				WSkin.Font(K.F(row, k))
			end
		end
	end

	function LH.SkinRows(f)
		if type(f.itemFrames) == "table" then
			for _, row in pairs(f.itemFrames) do
				LH.SkinItemRow(row)
			end
		end
		if type(f.usedPlayerFrames) == "table" then
			for _, row in pairs(f.usedPlayerFrames) do
				LH.SkinPlayerRow(row)
			end
		end
	end

	-- The resize grab: Blizzard's arrow gone, three thin centered lines.
	function LH.SkinResizeGrip(rb, f)
		if not rb then
			return
		end
		local d = K.GetFFD(rb)
		if d.grip then
			return
		end
		d.grip = true
		rb:ClearAllPoints()
		rb:SetPoint("BOTTOM", f, "BOTTOM", 0, 2)
		for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture" }) do
			local fn = rb[getter]
			local t = fn and fn(rb)
			if t then
				t:SetAlpha(0)
			end
		end
		WSkin.FadeRegions(rb)
		local px = K.OnePx(rb)
		local lines = {}
		local w = 18
		for i = 1, 3 do
			local line = BS.SolidTex(rb, "OVERLAY", 1, 1, 1, 1)
			line:SetAlpha(0.3)
			line:SetSize(w, px)
			line:SetPoint("CENTER", rb, "CENTER", 0, px * 4 * (2 - i))
			lines[i] = line
			w = w - 3
		end
		d.lines = lines
		rb:HookScript("OnEnter", function()
			for i = 1, #lines do lines[i]:SetAlpha(0.8) end
		end)
		rb:HookScript("OnLeave", function()
			for i = 1, #lines do lines[i]:SetAlpha(0.3) end
		end)
	end

	function LH.Skin()
		local f = _G.LootHistoryFrame
		if not f or BS.Forbidden(f) then
			return
		end
		K.KillBackdrop(f)
		WSkin.Shell("loothistory", f, { topBar = 20 })
		local d = K.GetFFD(f)
		if not d.lhSkinned then
			d.lhSkinned = true
			WSkin.FadeKeyedArt(f)
			if K.F(f, "CloseButton") then
				WSkin.CloseButton(K.F(f, "CloseButton"))
			end
			local title = K.F(f, "Label")
			if title then
				WSkin.Font(title)
				WSkin.White(title)
				if d.topBar then
					title:ClearAllPoints()
					title:SetPoint("CENTER", d.topBar, "CENTER", 0, 0)
				end
			end
			local sf = K.F(f, "ScrollFrame") or _G.LootHistoryFrameScrollFrame
			if sf then
				WSkin.FadeRegions(sf)
				WSkin.Register(sf, true)
			end
			local sb = _G.LootHistoryFrameScrollFrameScrollBar
			if sb then
				WSkin.ScrollBar(sb)
			end
			LH.SkinResizeGrip(K.F(f, "ResizeButton"), f)
		end
		LH.SkinRows(f)
	end

	WSkin.RegisterWindow({
		key = "loothistory",
		label = "Loot Rolls Window",
		description = "The pending-rolls window: encounter picker, roll timer, and the result rows.",
		order = 220,
		elvui = "lootHistory",
		apply = function()
			local f = _G.LootHistoryFrame
			if not f then
				return
			end
			WSkin.HookShow(f, LH.Skin)
			if f:IsShown() then
				LH.Skin()
			end
			local rows = WSkin.WindowCallback("loothistory", function(_, row) LH.SkinItemRow(row) end)
			local players = WSkin.WindowCallback("loothistory", function(_, row) LH.SkinPlayerRow(row) end)
			if type(_G.LootHistoryFrame_UpdateItemFrame) == "function" then
				hooksecurefunc("LootHistoryFrame_UpdateItemFrame", rows)
			end
			if type(_G.LootHistoryFrame_UpdatePlayerFrame) == "function" then
				hooksecurefunc("LootHistoryFrame_UpdatePlayerFrame", players)
			end
			if type(_G.LootHistoryFrame_FullUpdate) == "function" then
				hooksecurefunc("LootHistoryFrame_FullUpdate", WSkin.Debounce(function()
					if f:IsShown() then LH.SkinRows(f) end
				end))
			end
		end,
	})
end

-------------------------------------------------------------------------------
--  Group invite popups. 5.4.8 has two: LFGInvitePopup (an invite carrying
--  roles) and the StaticPopup dialogs PARTY_INVITE / PARTY_INVITE_XREALM. The
--  static popup frames are shared with every other dialog, so their skin is
--  reversible: it is on only while the dialog shows an invite.
-------------------------------------------------------------------------------
do
	local GI = { WHICH = { PARTY_INVITE = true, PARTY_INVITE_XREALM = true } }

	-- Accept / Decline label: pinned to the button so it can never wrap.
	function GI.PinLabel(b)
		local fs = b and (b.GetFontString and b:GetFontString())
		if not fs then
			return
		end
		local d = K.GetFFD(fs)
		if d.labelPinned then
			return
		end
		d.labelPinned = true
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", b, "LEFT", 2, 0)
		fs:SetPoint("RIGHT", b, "RIGHT", -2, 0)
		if fs.SetWordWrap then
			fs:SetWordWrap(false)
		end
	end

	function GI.SkinLFGPopup()
		local fr = _G.LFGInvitePopup
		if not fr or BS.Forbidden(fr) then
			return
		end
		local d = K.GetFFD(fr)
		-- Role / icon glyphs that are regions of the dialog stay out of the fade.
		if not d.giScan then
			d.giScan = true
			local regions = { fr:GetRegions() }
			for i = 1, #regions do
				local r = regions[i]
				if r and r.IsObjectType and r:IsObjectType("Texture") then
					local hay = WSkin.TexHay(r)
					if hay and (WSkin.TexIsIcon(hay) or hay:find("role", 1, true) or hay:find("icon", 1, true)) then
						if not d.caret then
							d.caret = r
						elseif not d.arrow then
							d.arrow = r
						end
					end
				end
			end
		end
		K.KillBackdrop(fr)
		WSkin.Shell("groupinvite", fr, { noTopBar = true })
		for _, k in ipairs({ "AcceptButton", "DeclineButton" }) do
			local b = _G["LFGInvitePopup" .. k] or fr[k]
			if b then
				WSkin.Button(b)
				WSkin.StateButtonLabel(b)
				GI.PinLabel(b)
			end
		end
		for _, role in ipairs({ "Tank", "Healer", "DPS" }) do
			local rb = _G["LFGInvitePopupRoleButton" .. role]
			local cb = rb and (K.F(rb, "checkButton") or _G["LFGInvitePopupRoleButton" .. role .. "CheckButton"])
			if cb then
				WSkin.Checkbox(cb)
			end
		end
		K.FontRegions(fr)
		if _G.LFGInvitePopupText then
			WSkin.Font(_G.LFGInvitePopupText)
			WSkin.White(_G.LFGInvitePopupText)
		end
	end

	-- Reversible flat look on a StaticPopup button.
	function GI.ButtonMode(btn, on)
		local d = K.GetFFD(btn)
		if on and not d.giBg then
			local bg = BS.SolidTex(btn, "BACKGROUND", K.Theme.bgR, K.Theme.bgG, K.Theme.bgB, K.Theme.bgA, -8)
			bg:SetAllPoints(btn)
			d.giBg = bg
			local bh = CreateFrame("Frame", nil, btn)
			bh:SetAllPoints(btn)
			K.PP.CreateBorder(bh, K.Theme.brdR, K.Theme.brdG, K.Theme.brdB, K.Theme.brdA, 1, "BORDER", -7)
			d.giBorder = bh
			local hover = BS.SolidTex(btn, "HIGHLIGHT", 1, 1, 1, 0.1)
			hover:SetAllPoints(btn)
			d.giHover = hover
			local fs = btn.GetFontString and btn:GetFontString()
			if fs then
				d.giFS = fs
				d.giTextColor = { fs:GetTextColor() }
			end
		end
		if not d.giBg then
			return
		end
		for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
			local fn = btn[getter]
			local t = fn and fn(btn)
			if t then
				t:SetAlpha(on and 0 or 1)
			end
		end
		d.giBg:SetShown(on)
		d.giBorder:SetShown(on)
		d.giHover:SetAlpha(on and 1 or 0)
		if d.giFS then
			if on then
				WSkin.White(d.giFS)
			elseif d.giTextColor and d.giTextColor[1] then
				d.giFS:SetTextColor(d.giTextColor[1], d.giTextColor[2], d.giTextColor[3])
			end
		end
	end

	function GI.UpdateStatic(dialog)
		if not dialog or BS.Forbidden(dialog) then
			return
		end
		local d = K.GetFFD(dialog)
		local on = (dialog:IsShown() and GI.WHICH[dialog.which or ""]) and true or false
		if not on and not d.giOn then
			return
		end
		local name = dialog:GetName()
		if on then
			if not d.giOn then
				if dialog.GetBackdropColor then
					d.giBd = { dialog:GetBackdropColor() }
					d.giBdBorder = { dialog:GetBackdropBorderColor() }
				end
				K.KillBackdrop(dialog)
			end
			local host = K.Host("groupinvite", dialog, { noTopBar = true })
			host:Show()
		else
			if d.skinHost then
				d.skinHost:Hide()
			end
			if dialog.SetBackdropColor and d.giBd and d.giBd[1] then
				dialog:SetBackdropColor(d.giBd[1], d.giBd[2], d.giBd[3], d.giBd[4] or 1)
			end
			if dialog.SetBackdropBorderColor and d.giBdBorder and d.giBdBorder[1] then
				dialog:SetBackdropBorderColor(d.giBdBorder[1], d.giBdBorder[2], d.giBdBorder[3], d.giBdBorder[4] or 1)
			end
		end
		d.giOn = on
		if name then
			for i = 1, 2 do
				local b = _G[name .. "Button" .. i]
				if b then
					GI.ButtonMode(b, on)
				end
			end
		end
	end

	function GI.UpdateAllStatic()
		for i = 1, (STATICPOPUP_NUMDIALOGS or 4) do
			GI.UpdateStatic(_G["StaticPopup" .. i])
		end
	end

	WSkin.RegisterWindow({
		key = "groupinvite",
		label = "Group Invite Popup",
		description = "The \"you have been invited to a group\" dialogs, with your role and Accept / Decline.",
		order = 230,
		elvui = "lfg",
		apply = function()
			local fr = _G.LFGInvitePopup
			if fr then
				WSkin.HookShow(fr, GI.SkinLFGPopup)
				if fr:IsShown() then
					GI.SkinLFGPopup()
				end
			end
			-- The static popups are ElvUI's "misc" skin: stand down for them only.
			if BS.ElvUISkins("misc") then
				return
			end
			for i = 1, (STATICPOPUP_NUMDIALOGS or 4) do
				local dialog = _G["StaticPopup" .. i]
				if dialog then
					local function update() GI.UpdateStatic(dialog) end
					dialog:HookScript("OnShow", update)
					dialog:HookScript("OnHide", update)
				end
			end
			if type(_G.StaticPopup_Show) == "function" then
				hooksecurefunc("StaticPopup_Show", WSkin.WindowCallback("groupinvite", GI.UpdateAllStatic))
			end
			GI.UpdateAllStatic()
		end,
	})
end

-------------------------------------------------------------------------------
--  Ready check. ReadyCheckListenerFrame (a child set to all points of
--  ReadyCheckFrame) owns the art, the portrait, the message and both buttons,
--  so the shell goes there. The portrait is removed; message and buttons are
--  centered, and the panel grows so a long "<name>-<realm>" fits one line.
-------------------------------------------------------------------------------
do
	local RC = { PAD = 24, MAX_GROW = 2, TEXT_Y = -32, BTN_Y = -55, BTN_GAP = 12 }

	function RC.Fit()
		local fr = _G.ReadyCheckFrame
		local fs = _G.ReadyCheckFrameText
		if not (fr and fs) then
			return
		end
		local d = K.GetFFD(fr)
		if not d.rcBaseW then
			local w = fr:GetWidth()
			if not w or w <= 0 then
				return
			end
			d.rcBaseW = w
		end
		local need = fs.GetStringWidth and fs:GetStringWidth()
		if type(need) ~= "number" then
			return
		end
		local pad = RC.PAD * 2
		local want = math.max(d.rcBaseW, math.min(need + pad, d.rcBaseW * RC.MAX_GROW))
		fr:SetWidth(want)
		fs:SetWidth(want - pad)
		fs:ClearAllPoints()
		fs:SetPoint("CENTER", fr, "TOP", 0, RC.TEXT_Y)
		local yes, no = _G.ReadyCheckFrameYesButton, _G.ReadyCheckFrameNoButton
		if yes and no then
			local half = RC.BTN_GAP / 2
			yes:ClearAllPoints()
			yes:SetPoint("TOPRIGHT", fr, "TOP", -half, RC.BTN_Y)
			no:ClearAllPoints()
			no:SetPoint("TOPLEFT", fr, "TOP", half, RC.BTN_Y)
		end
	end

	function RC.SkinListener()
		local fr = _G.ReadyCheckListenerFrame
		if not fr or BS.Forbidden(fr) then
			return
		end
		WSkin.Shell("readycheck", fr, { noTopBar = true })
		if _G.ReadyCheckPortrait then
			_G.ReadyCheckPortrait:SetAlpha(0)
		end
		for _, k in ipairs({ "ReadyCheckFrameYesButton", "ReadyCheckFrameNoButton" }) do
			local b = _G[k]
			if b then
				WSkin.Button(b)
				WSkin.StateButtonLabel(b)
			end
		end
		local body = _G.ReadyCheckFrameText
		if body then
			WSkin.Font(body)
			WSkin.White(body)
			local d = K.GetFFD(body)
			if not d.rcHook then
				d.rcHook = true
				hooksecurefunc(body, "SetText", WSkin.WindowCallback("readycheck", RC.Fit))
				hooksecurefunc(body, "SetFormattedText", WSkin.WindowCallback("readycheck", RC.Fit))
			end
		end
		RC.Fit()
	end

	WSkin.RegisterWindow({
		key = "readycheck",
		label = "Ready Check",
		description = "The ready check prompt with its Yes / No buttons.",
		order = 240,
		elvui = "misc",
		apply = function()
			local fr = _G.ReadyCheckListenerFrame
			if not fr then
				return
			end
			WSkin.HookShow(fr, RC.SkinListener)
			if fr:IsShown() then
				RC.SkinListener()
			end
		end,
	})
end

-------------------------------------------------------------------------------
--  Micro Menu: the 5.4.8 micro buttons (28x58, emblem in the lower part of
--  the UI-MicroButton-*-Up file). The emblem stays: the raised plate around it
--  is cropped off and a flat box with a 1px border frames it. ElvUI's action
--  bars restyle the same buttons, so the pack stands down while they are on.
-------------------------------------------------------------------------------
do
	local MM = {
		FALLBACK = {
			"CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton",
			"AchievementMicroButton", "QuestLogMicroButton", "GuildMicroButton",
			"PVPMicroButton", "LFDMicroButton", "CompanionsMicroButton", "EJMicroButton",
			"StoreMicroButton", "MainMenuMicroButton", "HelpMicroButton",
		},
		-- Emblem crop of the 32x64 file (27 of 32 columns, lower 34 of 64 rows).
		L = 0.08, R = 0.92, T = 0.42, B = 0.95,
		BG_A = 0.45,
	}

	function MM.List()
		if type(MICRO_BUTTONS) == "table" and #MICRO_BUTTONS > 0 then
			return MICRO_BUTTONS
		end
		return MM.FALLBACK
	end

	function MM.Trim(tex, box, crop)
		if not tex or not tex.SetTexCoord then
			return
		end
		if crop then
			tex:SetTexCoord(MM.L, MM.R, MM.T, MM.B)
		end
		tex:ClearAllPoints()
		tex:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -1)
		tex:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1)
	end

	function MM.SkinButton(btn)
		if not btn or BS.Forbidden(btn) then
			return
		end
		local d = K.GetFFD(btn)
		if not d.box then
			-- The visible plate of the button: its lower part.
			local box = CreateFrame("Frame", nil, btn)
			box:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -23)
			box:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 2)
			box:EnableMouse(false)
			local bg = btn:CreateTexture(nil, "BACKGROUND", nil, -8)
			bg:SetTexture(K.Theme.bgR, K.Theme.bgG, K.Theme.bgB, MM.BG_A)
			bg:SetAllPoints(box)
			WSkin.AddBorder(box)
			d.box, d.bg = box, bg
			local hl = btn.GetHighlightTexture and btn:GetHighlightTexture()
			if hl then
				hl:SetTexture(1, 1, 1, 0.1)
				hl:SetTexCoord(0, 1, 0, 1)
				hl:ClearAllPoints()
				hl:SetAllPoints(box)
			end
		end
		MM.Trim(btn.GetNormalTexture and btn:GetNormalTexture(), d.box, true)
		MM.Trim(btn.GetPushedTexture and btn:GetPushedTexture(), d.box, true)
		MM.Trim(btn.GetDisabledTexture and btn:GetDisabledTexture(), d.box, true)
		if btn == _G.CharacterMicroButton and _G.MicroButtonPortrait then
			MM.Trim(_G.MicroButtonPortrait, d.box, false)
		end
	end

	function MM.SkinAll()
		if InCombatLockdown() then
			MM.pending = true
			return
		end
		for _, name in ipairs(MM.List()) do
			pcall(MM.SkinButton, _G[name])
		end
	end

	WSkin.RegisterWindow({
		key = "micromenu",
		label = "Micro Menu",
		description = "Flattens the micro menu buttons into the EllesmereUI style.",
		order = 260,
		apply = function()
			-- ElvUI's action bars restyle the micro buttons (ElvUI_MicroBar).
			if K.ElvPrivate("actionbar", "enable") then
				return
			end
			MM.SkinAll()
			local repaint = WSkin.Debounce(MM.SkinAll)
			if type(_G.UpdateMicroButtons) == "function" then
				hooksecurefunc("UpdateMicroButtons", repaint)
			end
			local ev = CreateFrame("Frame")
			ev:RegisterEvent("PLAYER_REGEN_ENABLED")
			ev:SetScript("OnEvent", function()
				if MM.pending then
					MM.pending = false
					repaint()
				end
			end)
		end,
	})
end

-------------------------------------------------------------------------------
--  Bag Bar: backpack + four bag slots in the micro menu's cell look. Bevel art
--  faded, icon squared, theme background and border, white hover wash, and a
--  quality colored border for an uncommon-or-better bag. ElvUI's bag bar
--  (E.private.bags.bagBar) owns the same buttons: the pack stands down then.
-------------------------------------------------------------------------------
do
	local BB = {
		BUTTONS = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot" },
		CROP = 0.08,
		BG_A = 0.45,
	}

	function BB.Chrome(btn)
		local d = K.GetFFD(btn)
		if d.box then
			return d
		end
		local box = CreateFrame("Frame", nil, btn)
		box:SetAllPoints(btn)
		box:EnableMouse(false)
		WSkin.AddBorder(box)
		d.box = box
		local bg = btn:CreateTexture(nil, "BACKGROUND", nil, -8)
		bg:SetTexture(K.Theme.bgR, K.Theme.bgG, K.Theme.bgB, BB.BG_A)
		bg:SetAllPoints(btn)
		d.bg = bg
		local hl = btn.GetHighlightTexture and btn:GetHighlightTexture()
		if hl then
			hl:SetTexture(1, 1, 1, 0.1)
			hl:SetTexCoord(0, 1, 0, 1)
			hl:ClearAllPoints()
			hl:SetAllPoints(btn)
		end
		return d
	end

	function BB.Paint(btn)
		local d = K.GetFFD(btn)
		if not d.box then
			return
		end
		local name = btn:GetName()
		local icon = K.F(btn, "icon") or (name and _G[name .. "IconTexture"])
		if icon and icon.SetTexCoord then
			icon:SetTexCoord(BB.CROP, 1 - BB.CROP, BB.CROP, 1 - BB.CROP)
			icon:ClearAllPoints()
			icon:SetAllPoints(btn)
		end
		local nt = btn.GetNormalTexture and btn:GetNormalTexture()
		if nt and nt ~= icon then
			nt:SetAlpha(0)
		end
		if K.F(btn, "IconBorder") then
			K.F(btn, "IconBorder"):SetAlpha(0)
		end
		local r, g, b = nil, nil, nil
		local id = btn.GetID and btn:GetID()
		if btn ~= _G.MainMenuBarBackpackButton and id and id > 0 and GetInventoryItemQuality then
			r, g, b = K.QualityRGB(GetInventoryItemQuality("player", id))
		end
		if r then
			K.PP.SetBorderColor(d.box, r, g, b, 1)
		else
			K.PP.SetBorderColor(d.box, K.Theme.brdR, K.Theme.brdG, K.Theme.brdB, K.Theme.brdA)
		end
	end

	function BB.PaintAll()
		for _, name in ipairs(BB.BUTTONS) do
			local btn = _G[name]
			if btn and not BS.Forbidden(btn) then
				BB.Chrome(btn)
				BB.Paint(btn)
			end
		end
	end

	WSkin.RegisterWindow({
		key = "bagbar",
		label = "Bag Bar",
		description = "Flattens the bag bar slot buttons into the EllesmereUI style.",
		order = 270,
		apply = function()
			if K.ElvPrivate("bags", "bagBar") then
				return
			end
			BB.PaintAll()
			local ev = CreateFrame("Frame")
			ev:RegisterEvent("BAG_UPDATE_DELAYED")
			ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
			ev:SetScript("OnEvent", WSkin.Debounce(BB.PaintAll))
		end,
	})
end

-------------------------------------------------------------------------------
--  Queue status panel (QueueStatusFrame): what the minimap LFG eye shows on
--  hover. Tooltip-style art, so the shell replaces a tooltip border. Entries
--  are re-skinned by the two entry setup functions. Role icons stay native.
-------------------------------------------------------------------------------
do
	local QS = {}

	function QS.SkinEntry(entry)
		if not entry or BS.Forbidden(entry) then
			return
		end
		-- Title keeps Blizzard's color; the rest reads as house white text.
		if K.F(entry, "Title") then
			WSkin.Font(K.F(entry, "Title"))
		end
		for _, k in ipairs({ "Status", "SubTitle", "TimeInQueue", "AverageWait", "ExtraText" }) do
			local fs = K.F(entry, k)
			if fs then
				WSkin.Font(fs)
				WSkin.White(fs)
			end
		end
		for _, k in ipairs({ "TanksFound", "HealersFound", "DamagersFound" }) do
			local rc = K.F(entry, k)
			if rc and K.F(rc, "Count") then
				WSkin.Font(K.F(rc, "Count"))
				WSkin.White(K.F(rc, "Count"))
			end
		end
		local sep = K.F(entry, "EntrySeparator")
		if sep and sep.SetTexture then
			sep:SetTexture(1, 1, 1, 0.12)
		end
	end

	function QS.Skin()
		local f = _G.QueueStatusFrame
		if not f or BS.Forbidden(f) then
			return
		end
		K.KillBackdrop(f)
		WSkin.Shell("queuestatus", f, { noTopBar = true })
		K.FadeKeys(f, { "Background", "Bg", "BG", "Border" })
		if type(f.statusEntries) == "table" then
			for _, entry in pairs(f.statusEntries) do
				QS.SkinEntry(entry)
			end
		end
	end

	WSkin.RegisterWindow({
		key = "queuestatus",
		label = "Queue Status",
		description = "The panel the minimap Group Finder eye shows on hover: queue titles, role icons and counts, and time in queue.",
		order = 420,
		elvui = "lfg",
		apply = function()
			local f = _G.QueueStatusFrame
			if not f then
				return
			end
			QS.Skin()
			WSkin.HookShow(f, QS.Skin)
			local entryHook = WSkin.WindowCallback("queuestatus", QS.SkinEntry)
			if type(_G.QueueStatusEntry_SetFullDisplay) == "function" then
				hooksecurefunc("QueueStatusEntry_SetFullDisplay", entryHook)
			end
			if type(_G.QueueStatusEntry_SetMinimalDisplay) == "function" then
				hooksecurefunc("QueueStatusEntry_SetMinimalDisplay", entryHook)
			end
		end,
	})
end
