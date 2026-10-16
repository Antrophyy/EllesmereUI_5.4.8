-------------------------------------------------------------------------------
--  EllesmereUIBlizzardSkin_WindowPacks2.lua (5.4.8 port)
--  Window Skins for the "shop and talk" windows, ported from retail
--  EllesmereUIBlizzardSkin_WindowPacks.lua onto the Mists of Pandaria frames:
--    merchant (+ stack split popup, + item level overlay), auctionhouse,
--    macros, settings (Interface / System options + key bindings), trainer,
--    gossip (+ book / letter text window), quest, trade, dressup, transmog,
--    itemupgrade.
--  Look: house shell, flat tabs with the accent underline, flat buttons,
--  squared item icons with a rarity border, white text.
--
--  5.4.8 notes:
--   - Frame names come from the 5.4.8 FrameXML (ElvUI MoP skins as a map).
--   - Item buttons have no IconBorder ring: the rarity border is painted from
--     the item link (or from the name color Blizzard sets).
--   - Visual only: textures, alpha, fonts, colors. No SetScript on Blizzard
--     frames, no Show/Hide of Blizzard frames, no keys written on them.
--   - Every pack lives in its own do ... end block (Lua 5.1 local limit).
-------------------------------------------------------------------------------
local addonName = ...
local ns = EllesmereUI
local BS = ns.BlizzSkin
local WSkin = ns.WSkin
if not (BS and WSkin) then
	return
end

local GetFFD = WSkin.GetFFD
local Theme = WSkin.Theme
local PP = BS.PP

-------------------------------------------------------------------------------
--  Shared helpers (one table, so the chunk keeps few locals).
-------------------------------------------------------------------------------
local H = {}

-- Bottom tabs (CharacterFrameTabButtonTemplate) keep transparent art margins.
H.BOTTOM_TAB = { inset = { 10, 3, 10, 3 } }

function H.Btn(b)
	if b then
		WSkin.Button(b)
		WSkin.WhiteButtonLabel(b)
	end
end

-- Action button whose label mirrors the enabled state (gray when disabled).
function H.StateBtn(b)
	if b then
		WSkin.Button(b)
		WSkin.StateButtonLabel(b)
	end
end

-- Alpha out textures, given as objects or global names.
function H.Fade(...)
	for i = 1, select("#", ...) do
		local t = (select(i, ...))
		if type(t) == "string" then
			t = _G[t]
		end
		if t and t.SetAlpha then
			t:SetAlpha(0)
		end
	end
end

-- Alpha out parentKey / $parent<key> textures of a frame.
function H.FadeKeys(frame, keys)
	if not frame then
		return
	end
	local name = frame.GetName and frame:GetName()
	for i = 1, #keys do
		local k = keys[i]
		local t = frame[k] or (name and _G[name .. k])
		if t and t.SetAlpha and t.IsObjectType and t:IsObjectType("Texture") then
			t:SetAlpha(0)
		end
	end
end

-- House font + white.
function H.White(fs)
	if fs and fs.SetTextColor then
		WSkin.Font(fs)
		WSkin.White(fs)
	end
end

-- Seat a header text in the middle of the shell's top bar.
function H.CenterTitle(frame, fs)
	if not (frame and fs and fs.ClearAllPoints) then
		return
	end
	local d = GetFFD(frame)
	local fd = GetFFD(fs)
	if d.topBar and not fd.centered then
		fd.centered = true
		fs:ClearAllPoints()
		fs:SetPoint("CENTER", d.topBar, "CENTER", 0, 0)
	end
	H.White(fs)
end

-- Strip scroll frame track art (FauxScrollFrame textures have no names).
function H.ScrollArt(sf)
	if type(sf) == "string" then
		sf = _G[sf]
	end
	if sf and not BS.Forbidden(sf) then
		WSkin.FadeRegions(sf)
		WSkin.Register(sf, true)
		local n = sf.GetName and sf:GetName()
		local sb = sf.ScrollBar or (n and _G[n .. "ScrollBar"])
		if sb then
			WSkin.ScrollBar(sb)
		end
	end
end

-- Rarity color only when it has a hue (no white / gray borders).
function H.QualityRGB(r, g, b)
	if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then
		return
	end
	if (math.max(r, g, b) - math.min(r, g, b)) <= 0.1 then
		return
	end
	return r, g, b
end

-- Paint the square border of a tile (made by WSkin.QualityBorder).
function H.PaintBorder(owner, r, g, b)
	local d = WSkin.FFD[owner]
	local host = d and d.qBorder
	if not host then
		return
	end
	local qr, qg, qb = H.QualityRGB(r, g, b)
	PP.SetBorderColor(host, qr or 0, qg or 0, qb or 0, 1)
end

-- Same, from an item quality number.
function H.PaintQuality(owner, quality)
	if quality and quality >= 2 and GetItemQualityColor then
		local r, g, b = GetItemQualityColor(quality)
		H.PaintBorder(owner, r, g, b)
	else
		H.PaintBorder(owner, 0, 0, 0)
	end
end

-- An item slot button: art gone, square icon, rarity border (painted later).
function H.ItemTile(btn)
	if btn and not BS.Forbidden(btn) then
		WSkin.ItemButton(btn, { quality = true })
	end
end

-- Flat dark box with a 1px black edge on `owner`, sized to `region`.
function H.Box(owner, region, inset)
	if not owner or not region or BS.Forbidden(owner) then
		return
	end
	local d = GetFFD(owner)
	if not d.box then
		local bg = owner:CreateTexture(nil, "BACKGROUND", nil, -6)
		bg:SetTexture(0.04, 0.04, 0.04, 0.9)
		d.box = bg
		d.bg = d.bg or bg
	end
	local i = inset or 0
	d.box:ClearAllPoints()
	d.box:SetPoint("TOPLEFT", region, "TOPLEFT", i, -i)
	d.box:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", -i, i)
	WSkin.QualityBorder(owner, d.box, 0, 0, 0)
end

-- Dark well + square border behind a slot whose icon Blizzard swaps in
-- (normal texture icons, upgrade / sell slots).
function H.Well(btn, inset)
	if not btn or BS.Forbidden(btn) then
		return
	end
	local d = GetFFD(btn)
	if d.well then
		return
	end
	local well = btn:CreateTexture(nil, "BACKGROUND", nil, -7)
	well:SetTexture(0.02, 0.02, 0.02, 0.9)
	local i = inset or 0
	well:SetPoint("TOPLEFT", btn, "TOPLEFT", i, -i)
	well:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -i, i)
	d.well = well
	d.bg = d.bg or well
	WSkin.QualityBorder(btn, well, 0, 0, 0)
end

-- Move a frame by dx, dy once (every anchor kept).
function H.Shift(el, dx, dy)
	if not el or not el.GetNumPoints then
		return
	end
	local d = GetFFD(el)
	if d.shifted then
		return
	end
	local np = el:GetNumPoints() or 0
	if np == 0 then
		return
	end
	local pts = {}
	for i = 1, np do
		local p, rel, rp, x, y = el:GetPoint(i)
		if not p then
			return
		end
		pts[i] = { p, rel, rp, (x or 0) + dx, (y or 0) + dy }
	end
	d.shifted = true
	el:ClearAllPoints()
	for i = 1, #pts do
		local t = pts[i]
		el:SetPoint(t[1], t[2], t[3], t[4], t[5])
	end
end

-- Prev / Next page button with a text label: flat block + house arrow, the
-- label and the plate art gone.
function H.LabeledPage(btn, ch)
	if not btn or BS.Forbidden(btn) then
		return
	end
	WSkin.PageButton(btn, ch, 13)
	local d = GetFFD(btn)
	local regions = { btn:GetRegions() }
	for i = 1, #regions do
		local r = regions[i]
		if r and r ~= d.arrow and r ~= d.bg and r ~= d.hover and r.IsObjectType
			and (r:IsObjectType("FontString") or r:IsObjectType("Texture")) then
			r:SetAlpha(0)
		end
	end
	if not d.shrunk then
		local w, h = btn:GetSize()
		if w and h and w > 8 and h > 8 then
			d.shrunk = true
			btn:SetSize(w - 6, h - 6)
		end
	end
end

-- Icon grid slot art at 50% (keeps the icon, hover and checked glow).
function H.DimSlot(btn)
	if not btn or BS.Forbidden(btn) then
		return
	end
	local n = btn.GetName and btn:GetName()
	local icon = btn.Icon or btn.icon or (n and _G[n .. "Icon"])
	local hl = btn.GetHighlightTexture and btn:GetHighlightTexture()
	local ct = btn.GetCheckedTexture and btn:GetCheckedTexture()
	local regions = { btn:GetRegions() }
	for i = 1, #regions do
		local r = regions[i]
		if r and r ~= icon and r ~= hl and r ~= ct and r.IsObjectType and r:IsObjectType("Texture") then
			r:SetAlpha(0.5)
		end
	end
end

-- Blizzard bakes |cff000000 black / |cff414141 grey runs into some strings
-- (quest titles); SetTextColor cannot lighten those. Rewrite in place.
H.DARK_TEXT = { ["000000"] = "ffffff", ["414141"] = "b0b8bc" }
function H.RecolorDarkText(fs)
	if not fs or not fs.GetText then
		return
	end
	local txt = fs:GetText()
	if type(txt) ~= "string" or txt == "" or not txt:find("|c", 1, true) then
		return
	end
	local new, n = txt:gsub("|c[fF][fF](%x%x%x%x%x%x)", function(hex)
		local repl = H.DARK_TEXT[hex:lower()]
		if repl then
			return "|cff" .. repl
		end
	end)
	if n > 0 and new ~= txt then
		fs:SetText(new)
	end
end

-- MoneyInputFrameTemplate: three edit boxes.
function H.MoneyInput(name)
	for _, suf in ipairs({ "Gold", "Silver", "Copper" }) do
		local eb = _G[name .. suf]
		if eb then
			WSkin.EditBox(eb)
		end
	end
end

-- OptionsSliderTemplate: backdrop gone, slim dark track, small accent thumb.
function H.Slider(sl)
	if not sl or BS.Forbidden(sl) then
		return
	end
	local d = GetFFD(sl)
	if d.sliderSkinned then
		return
	end
	d.sliderSkinned = true
	if sl.SetBackdropColor then
		sl:SetBackdropColor(0, 0, 0, 0)
		sl:SetBackdropBorderColor(0, 0, 0, 0)
	end
	-- The track sits on a frame BELOW the slider so the thumb draws on top.
	local track = CreateFrame("Frame", nil, sl)
	track:SetPoint("LEFT", sl, "LEFT", 2, 0)
	track:SetPoint("RIGHT", sl, "RIGHT", -2, 0)
	track:SetHeight(6)
	track:SetFrameLevel(math.max(0, sl:GetFrameLevel() - 1))
	local fill = track:CreateTexture(nil, "BACKGROUND")
	fill:SetTexture(0.02, 0.02, 0.02, 1)
	fill:SetAllPoints(track)
	WSkin.AddBorder(track, 0.25, 0.25, 0.25, 1)
	d.track = track
	local thumb = sl.GetThumbTexture and sl:GetThumbTexture()
	if thumb then
		thumb:SetTexture(Theme.accR or 1, Theme.accG or 1, Theme.accB or 1, 1)
		thumb:SetSize(8, 14)
		d.thumb = thumb
	end
end
WSkin.OnLooksChanged(function()
	for sl, d in pairs(WSkin.FFD) do
		if type(d) == "table" and d.thumb and d.thumb.SetTexture then
			d.thumb:SetTexture(Theme.accR or 1, Theme.accG or 1, Theme.accB or 1, 1)
		end
	end
end)

-- True for a named, Blizzard-owned (secure) frame. Unnamed or addon frames
-- (addon option panels share the same container) are left alone.
function H.IsBlizzardFrame(f)
	local name = f and f.GetName and f:GetName()
	if not name or _G[name] ~= f then
		return false
	end
	return issecurevariable(name) and true or false
end

-- Options controls under a Blizzard options panel: checkboxes, sliders,
-- dropdowns, edit boxes, buttons, and the boxed groups.
function H.OptionControls(frame, depth)
	depth = depth or 0
	if not frame or depth > 8 or BS.Forbidden(frame) or not frame.GetChildren then
		return
	end
	local children = { frame:GetChildren() }
	for i = 1, #children do
		local c = children[i]
		if c and not WSkin.IsForeignFrame(c, frame) then
			local kind = c.GetObjectType and c:GetObjectType()
			if kind == "CheckButton" then
				local nt = c.GetNormalTexture and c:GetNormalTexture()
				local hay = nt and WSkin.TexHay(nt)
				if hay and hay:find("checkbox", 1, true) then
					WSkin.Checkbox(c)
				end
			elseif kind == "Slider" then
				if WSkin.IsScrollBar(c) then
					WSkin.ScrollBar(c)
				else
					H.Slider(c)
				end
			elseif kind == "EditBox" then
				local n = c.GetName and c:GetName()
				if c.Left or (n and _G[n .. "Left"]) then
					WSkin.EditBox(c)
				end
			elseif kind == "Button" then
				if WSkin.IsPanelButton(c) then
					H.Btn(c)
				end
			elseif WSkin.IsDropDown(c) then
				WSkin.Dropdown(c)
			elseif kind == "Frame" and c.GetBackdrop then
				local bd = c:GetBackdrop()
				if type(bd) == "table" and bd.edgeFile and not GetFFD(c).optBox then
					-- OptionsBoxTemplate group: tooltip edge -> house 1px edge.
					GetFFD(c).optBox = true
					c:SetBackdropBorderColor(0, 0, 0, 0)
					c:SetBackdropColor(0, 0, 0, 0)
					WSkin.Panel(c, { shade = true })
				end
			end
			H.OptionControls(c, depth + 1)
		end
	end
end

-------------------------------------------------------------------------------
--  Merchant (MerchantFrame). Shell + tabs + item tiles as flat cards with a
--  squared rarity-bordered icon; repair icon buttons keep their pictures.
--  Retail "Show As List" is NOT ported (see the report / options note).
-------------------------------------------------------------------------------
do
local M = {}

-- Paint one tile's rarity border + name color from its item link.
function M.Paint(i)
	local f = _G.MerchantFrame
	local btn = _G["MerchantItem" .. i .. "ItemButton"]
	if not (f and btn) then
		return
	end
	local id = btn.GetID and btn:GetID() or 0
	local link = nil
	if btn:IsShown() and id > 0 then
		if (f.selectedTab or 1) == 1 then
			link = GetMerchantItemLink and GetMerchantItemLink(id)
		else
			link = GetBuybackItemLink and GetBuybackItemLink(id)
		end
	end
	WSkin.SetQualityColor(btn, link)
	local nameFS = _G["MerchantItem" .. i .. "Name"]
	if nameFS then
		local q = link and select(3, GetItemInfo(link))
		if q and GetItemQualityColor then
			nameFS:SetTextColor(GetItemQualityColor(q))
		else
			nameFS:SetTextColor(1, 1, 1)
		end
	end
end

function M.PaintAll()
	for i = 1, 12 do
		M.Paint(i)
	end
	local bb = _G.MerchantBuyBackItemItemButton
	if bb and GetNumBuybackItems then
		local n = GetNumBuybackItems() or 0
		local link = n > 0 and GetBuybackItemLink and GetBuybackItemLink(n) or nil
		WSkin.SetQualityColor(bb, link)
		local nameFS = _G.MerchantBuyBackItemName
		if nameFS then
			local q = link and select(3, GetItemInfo(link))
			if q and GetItemQualityColor then
				nameFS:SetTextColor(GetItemQualityColor(q))
			else
				nameFS:SetTextColor(1, 1, 1)
			end
		end
	end
end

-- Vendor tile: slot / name plate art gone, flat card, squared icon centered
-- on the card's left edge.
function M.Tile(item)
	if not item or BS.Forbidden(item) then
		return
	end
	local d = GetFFD(item)
	local name = item.GetName and item:GetName()
	if not d.bg then
		local bg = item:CreateTexture(nil, "BACKGROUND", nil, -7)
		bg:SetTexture(Theme.bgR, Theme.bgG, Theme.bgB, Theme.bgA)
		bg:SetPoint("TOPLEFT", 0, 0)
		bg:SetPoint("BOTTOMRIGHT", 0, 0)
		d.bg = bg
		WSkin.AddBorder(item)
	end
	WSkin.FadeRegions(item, { [d.bg] = true })
	local nameFS = name and _G[name .. "Name"]
	if nameFS then
		WSkin.Font(nameFS)
	end
	local btn = name and _G[name .. "ItemButton"]
	if btn then
		H.ItemTile(btn)
		local bd = GetFFD(btn)
		if not bd.rowCentred then
			bd.rowCentred = true
			btn:ClearAllPoints()
			btn:SetPoint("LEFT", item, "LEFT", 3, 0)
		end
	end
end

-- Repair / guild repair icon buttons: the picture is cropped from a shared
-- sheet, so its texcoords stay. Box art gone, flat fill, white hover.
function M.IconButton(btn)
	if not btn or BS.Forbidden(btn) then
		return
	end
	local d = GetFFD(btn)
	local n = btn.GetName and btn:GetName()
	local icon = (n and (_G[n .. "Icon"] or (n == "MerchantRepairAllButton" and _G.MerchantRepairAllIcon))) or nil
	local regions = { btn:GetRegions() }
	if not icon then
		for i = 1, #regions do
			local r = regions[i]
			local hay = r and r.IsObjectType and r:IsObjectType("Texture") and WSkin.TexHay(r)
			if hay and hay:find("repairicons", 1, true) then
				icon = r
				break
			end
		end
	end
	if not d.bg then
		local fill = btn:CreateTexture(nil, "BACKGROUND", nil, -8)
		fill:SetTexture(Theme.bgR, Theme.bgG, Theme.bgB, Theme.bgA)
		fill:SetAllPoints(btn)
		d.bg = fill
		local hover = btn:CreateTexture(nil, "HIGHLIGHT")
		hover:SetTexture(1, 1, 1, 0.1)
		hover:SetAllPoints(btn)
		d.hover = hover
		WSkin.AddBorder(btn)
		if icon and icon.ClearAllPoints then
			icon:ClearAllPoints()
			icon:SetPoint("TOPLEFT", 2, -2)
			icon:SetPoint("BOTTOMRIGHT", -2, 2)
		end
	end
	for _, g in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
		local t = btn[g] and btn[g](btn)
		if t and t ~= icon and t ~= d.hover and t.SetAlpha then
			t:SetAlpha(0)
		end
	end
	for i = 1, #regions do
		local r = regions[i]
		if r and r ~= icon and r ~= d.bg and r ~= d.hover and r.IsObjectType and r:IsObjectType("Texture") then
			r:SetAlpha(0)
		end
	end
end

local _hooked = false
local function Skin_Merchant()
	local f = _G.MerchantFrame
	if not f then
		return
	end
	WSkin.Shell("merchant", f)
	WSkin.RemovePortrait(f)
	WSkin.CommonChrome(f, "MerchantFrame") -- close + loot filter dropdown
	if _G.MerchantFrameInset then
		WSkin.Inset(_G.MerchantFrameInset)
	end
	H.White(_G.MerchantNameText)
	H.White(_G.MerchantPageText)
	H.White(_G.MerchantRepairText)

	-- Money / alt-currency wells along the bottom.
	for _, n in ipairs({ "MerchantMoneyInset", "MerchantExtraCurrencyInset" }) do
		if _G[n] then
			WSkin.Inset(_G[n])
		end
	end
	for _, n in ipairs({ "MerchantMoneyBg", "MerchantExtraCurrencyBg" }) do
		local el = _G[n]
		if el then
			WSkin.FadeRegions(el)
			WSkin.Register(el, true)
		end
	end

	-- Item tiles (10 on the merchant page, 12 on buyback) + last buyback.
	for i = 1, 12 do
		M.Tile(_G["MerchantItem" .. i])
	end
	M.Tile(_G.MerchantBuyBackItem)
	M.PaintAll()

	H.LabeledPage(_G.MerchantPrevPageButton, "<")
	H.LabeledPage(_G.MerchantNextPageButton, ">")
	for _, n in ipairs({ "MerchantRepairItemButton", "MerchantRepairAllButton", "MerchantGuildBankRepairButton" }) do
		M.IconButton(_G[n])
	end

	for i = 1, 2 do
		local tab = _G["MerchantFrameTab" .. i]
		if tab then
			WSkin.Tab(tab, H.BOTTOM_TAB)
		end
	end

	if not _hooked then
		_hooked = true
		-- Blizzard repaints the tiles on every page flip / tab swap.
		local repaint = WSkin.Debounce(function()
			if f:IsVisible() then
				for i = 1, 12 do
					M.Tile(_G["MerchantItem" .. i])
				end
				M.PaintAll()
			end
		end)
		for _, fn in ipairs({ "MerchantFrame_UpdateMerchantInfo", "MerchantFrame_UpdateBuybackInfo" }) do
			if type(_G[fn]) == "function" then
				hooksecurefunc(fn, repaint)
			end
		end
		WSkin.HookShow(f, WSkin.Debounce(function()
			if f:IsVisible() then
				Skin_Merchant()
			end
		end))
	end
end

WSkin.RegisterWindow({
	key = "merchant",
	label = "Merchant",
	description = "The vendor window: item list, buyback, and bottom money bar.",
	order = 300,
	elvui = "merchant",
	apply = Skin_Merchant,
	options = function(p, U)
		p:Toggle("Show Item Level", "Shows the item level on weapons and armor a vendor sells.",
			function() return BS.DB().merchantShowItemLevel == true end,
			function(v)
				BS.DB().merchantShowItemLevel = v and true or false
				if ns._Merchant_RefreshItemLevels then
					ns._Merchant_RefreshItemLevels()
				end
			end)
	end,
})
end

-------------------------------------------------------------------------------
--  Stack split popup (StackSplitFrame): the quantity box that opens over the
--  merchant window on a shift-click. Registered under the merchant key, as
--  in retail.
-------------------------------------------------------------------------------
do
local function Skin_StackSplit()
	local f = _G.StackSplitFrame
	if not f or BS.Forbidden(f) then
		return
	end
	local function Pass()
		WSkin.Shell("merchant", f, { noTopBar = true })
		local d = GetFFD(f)
		local left, right = _G.StackSplitLeftButton, _G.StackSplitRightButton
		local text = _G.StackSplitText
		-- The count is a FontString (no EditBox): give it a field look again.
		if text and left and right and not d.splitField then
			local bg = f:CreateTexture(nil, "BACKGROUND", nil, -4)
			bg:SetTexture(0.02, 0.02, 0.02, 1)
			bg:SetPoint("LEFT", left, "RIGHT", 5, 0)
			bg:SetPoint("RIGHT", right, "LEFT", -5, 0)
			bg:SetHeight(22)
			d.splitField = bg
			d.fill = bg
			WSkin.QualityBorder(f, bg, Theme.brdR or 0.2, Theme.brdG or 0.2, Theme.brdB or 0.2)
			text:ClearAllPoints()
			text:SetPoint("CENTER", bg, "CENTER", 0, 0)
			if text.SetJustifyH then
				text:SetJustifyH("CENTER")
			end
		end
		if text then
			WSkin.White(text)
		end
		H.Btn(_G.StackSplitOkayButton)
		H.Btn(_G.StackSplitCancelButton)
		-- The arrows are plain buttons with money-frame art: tint white,
		-- dimmed when disabled.
		for _, b in ipairs({ left, right }) do
			if b then
				for _, g in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture" }) do
					local t = b[g] and b[g](b)
					if t and t.SetVertexColor then
						t:SetVertexColor(1, 1, 1)
					end
				end
				local dis = b.GetDisabledTexture and b:GetDisabledTexture()
				if dis and dis.SetVertexColor then
					dis:SetVertexColor(0.4, 0.4, 0.4)
				end
			end
		end
	end
	Pass()
	WSkin.HookShow(f, WSkin.Debounce(function()
		if f:IsVisible() then
			Pass()
		end
	end))
end

WSkin.RegisterWindow({
	key = "merchant",
	apply = Skin_StackSplit,
})
end

-------------------------------------------------------------------------------
--  Merchant item level (QoL, works with or without the Merchant skin): item
--  level top-left of each vendor tile for weapons and armor when
--  merchantShowItemLevel is on. Buttons carry their merchant slot as ID.
-------------------------------------------------------------------------------
do
local IL = {}
IL.open = false
IL.ev = CreateFrame("Frame")

-- Localized "Weapon" / "Armor" class names (first two auction classes).
function IL.IsGear(itemType, equipLoc)
	if IL.weapon == nil then
		IL.weapon, IL.armor = false, false
		if GetAuctionItemClasses then
			local w, a = GetAuctionItemClasses()
			IL.weapon, IL.armor = w or false, a or false
		end
	end
	if IL.weapon then
		return itemType == IL.weapon or itemType == IL.armor
	end
	return type(equipLoc) == "string" and equipLoc ~= "" and equipLoc ~= "INVTYPE_BAG"
end

function IL.Update()
	local f = _G.MerchantFrame
	local show = BS.DB().merchantShowItemLevel == true
	local render = show and f and f:IsShown() and (f.selectedTab or 1) == 1
	for i = 1, 12 do
		local btn = _G["MerchantItem" .. i .. "ItemButton"]
		if btn then
			local fd = WSkin.FFD[btn]
			local fs = fd and fd.merchantILvl
			if not render then
				if fs then
					fs:SetText("")
				end
			else
				if not fs then
					fs = btn:CreateFontString(nil, "OVERLAY", nil, 7)
					fs:SetFont(BS.FontPath(), 12, "OUTLINE")
					fs:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
					GetFFD(btn).merchantILvl = fs
				end
				fs:SetText("")
				local id = btn.GetID and btn:GetID() or 0
				local link = btn:IsShown() and id > 0 and GetMerchantItemLink and GetMerchantItemLink(id)
				if link then
					local _, _, quality, ilvl, _, itemType, _, _, equipLoc = GetItemInfo(link)
					if ilvl and ilvl > 0 and IL.IsGear(itemType, equipLoc) then
						fs:SetText(ilvl)
						if quality and GetItemQualityColor then
							local r, g, b = GetItemQualityColor(quality)
							fs:SetTextColor(r or 1, g or 1, b or 1, 1)
						else
							fs:SetTextColor(1, 1, 1, 1)
						end
					end
				end
			end
		end
	end
end

-- GET_ITEM_INFO_RECEIVED only while a merchant is open and the option is on.
function IL.Sync()
	if BS.DB().merchantShowItemLevel == true and IL.open then
		IL.ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	else
		IL.ev:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
	end
end

ns._Merchant_RefreshItemLevels = function()
	IL.Sync()
	IL.Update()
end

IL.debounced = WSkin.Debounce(IL.Update)
for _, fn in ipairs({ "MerchantFrame_UpdateMerchantInfo", "MerchantFrame_UpdateBuybackInfo" }) do
	if type(_G[fn]) == "function" then
		hooksecurefunc(fn, IL.debounced)
	end
end
IL.ev:RegisterEvent("MERCHANT_SHOW")
IL.ev:RegisterEvent("MERCHANT_CLOSED")
IL.ev:SetScript("OnEvent", function(_, event)
	if event == "MERCHANT_SHOW" then
		IL.open = true
		IL.Sync()
		IL.debounced()
	elseif event == "MERCHANT_CLOSED" then
		IL.open = false
		IL.Sync()
	else
		IL.debounced()
	end
end)
end

-------------------------------------------------------------------------------
--  Auction House (AuctionFrame, Blizzard_AuctionUI): shell, bottom tabs,
--  category rail, column headers, result rows with squared rarity icons,
--  search inputs, money inputs, sell slot, action buttons, post progress bar.
--  Visual only: the commerce paths are never touched.
-------------------------------------------------------------------------------
do
local AH = {}
AH.SORTS = {
	"BrowseQualitySort", "BrowseLevelSort", "BrowseDurationSort", "BrowseHighBidderSort", "BrowseCurrentBidSort",
	"BidQualitySort", "BidLevelSort", "BidDurationSort", "BidBuyoutSort", "BidStatusSort", "BidBidSort",
	"AuctionsQualitySort", "AuctionsDurationSort", "AuctionsHighBidderSort", "AuctionsBidSort",
}
AH.STATE_BUTTONS = {
	"BrowseSearchButton", "BrowseResetButton", "BrowseBidButton", "BrowseBuyoutButton", "BrowseCloseButton",
	"BidBidButton", "BidBuyoutButton", "BidCloseButton",
	"AuctionsCreateAuctionButton", "AuctionsCancelAuctionButton", "AuctionsCloseButton",
	"AuctionsStackSizeMaxButton", "AuctionsNumStacksMaxButton",
}
AH.TITLES = { "BrowseTitle", "BidTitle", "AuctionsTitle" }
AH.LISTS = { Browse = "BrowseButton", Bid = "BidButton", Auctions = "AuctionsButton" }

-- Column header: 3-slice art gone, dark plate, white label, sort arrow kept.
function AH.Header(col)
	if not col or BS.Forbidden(col) then
		return
	end
	local d = GetFFD(col)
	if d.bg then
		return
	end
	H.FadeKeys(col, { "Left", "Middle", "Right" })
	local bg = col:CreateTexture(nil, "BACKGROUND", nil, -6)
	bg:SetTexture(0.02, 0.02, 0.02, 0.5)
	bg:SetPoint("TOPLEFT", 1, -1)
	bg:SetPoint("BOTTOMRIGHT", -1, 1)
	d.bg = bg
	d.skinned = true -- keeps WSkin.ButtonsIn off the header (its arrow is content)
	local hl = col.GetHighlightTexture and col:GetHighlightTexture()
	if hl then
		hl:SetTexture(1, 1, 1, 0.08)
		hl:ClearAllPoints()
		hl:SetAllPoints(bg)
	end
	local n = col:GetName()
	local fs = (n and _G[n .. "Text"]) or (col.GetFontString and col:GetFontString())
	if fs then
		H.White(fs)
	end
end

-- Result row: name plate art gone, faint plate, squared icon with a rarity
-- border that follows the name color Blizzard sets.
function AH.Row(row)
	if not row or BS.Forbidden(row) then
		return
	end
	local d = GetFFD(row)
	if d.ahRow then
		return
	end
	d.ahRow = true
	local n = row:GetName()
	local hl = (n and _G[n .. "Highlight"]) or (row.GetHighlightTexture and row:GetHighlightTexture())
	if hl then
		hl:SetTexture(1, 1, 1, 0.08)
		local plate = row:CreateTexture(nil, "BACKGROUND", nil, -7)
		plate:SetTexture(0, 0, 0, 0.3)
		plate:SetAllPoints(hl)
		d.bg = plate
	end
	local keep = {}
	if hl then keep[hl] = true end
	if d.bg then keep[d.bg] = true end
	WSkin.FadeRegions(row, keep)
	local item = n and _G[n .. "Item"]
	if item then
		H.ItemTile(item)
		local nameFS = _G[n .. "Name"]
		if nameFS then
			hooksecurefunc(nameFS, "SetVertexColor", function(_, r, g, b)
				H.PaintBorder(item, r, g, b)
			end)
		end
	end
end

-- Category rail button: lines dimmed, filter plate as a faint wash (Blizzard
-- sets its alpha per depth), flat hover.
function AH.Filter(btn)
	if not btn or BS.Forbidden(btn) then
		return
	end
	local d = GetFFD(btn)
	if d.ahFilter then
		return
	end
	d.ahFilter = true
	local n = btn:GetName()
	local nt = (n and _G[n .. "NormalTexture"]) or (btn.GetNormalTexture and btn:GetNormalTexture())
	if nt then
		nt:SetTexture(1, 1, 1, 0.05)
	end
	local lines = n and _G[n .. "Lines"]
	if lines and lines.SetVertexColor then
		lines:SetVertexColor(0.5, 0.5, 0.5)
	end
	local hl = btn.GetHighlightTexture and btn:GetHighlightTexture()
	if hl then
		hl:SetTexture(1, 1, 1, 0.1)
	end
end

-- Sell slot: the item icon is the button's normal texture.
function AH.SellSlot()
	local b = _G.AuctionsItemButton
	if not b or BS.Forbidden(b) then
		return
	end
	local d = GetFFD(b)
	if d.ahSell then
		return
	end
	d.ahSell = true
	local regions = { b:GetRegions() }
	local nt = b.GetNormalTexture and b:GetNormalTexture()
	local hl = b.GetHighlightTexture and b:GetHighlightTexture()
	for i = 1, #regions do
		local r = regions[i]
		if r and r ~= nt and r ~= hl and r.IsObjectType and r:IsObjectType("Texture") then
			r:SetAlpha(0)
		end
	end
	if hl then
		hl:SetTexture(1, 1, 1, 0.12)
	end
	H.Well(b)
	H.White(_G.AuctionsItemButtonName)
	local function Paint()
		local tex = b.GetNormalTexture and b:GetNormalTexture()
		if tex then
			tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			tex:ClearAllPoints()
			tex:SetPoint("TOPLEFT", 1, -1)
			tex:SetPoint("BOTTOMRIGHT", -1, 1)
		end
		local quality = GetAuctionSellItemInfo and select(4, GetAuctionSellItemInfo())
		H.PaintQuality(b, quality)
	end
	b:HookScript("OnEvent", Paint)
	Paint()
end

-- Post progress popup (multi-stack posting).
function AH.Progress()
	local p = _G.AuctionProgressFrame
	if not p or BS.Forbidden(p) then
		return
	end
	WSkin.Panel(p)
	local bar = _G.AuctionProgressBar
	if bar then
		H.Fade("AuctionProgressBarBorder", "AuctionProgressBarFlash")
		WSkin.ApplyBarFill(bar)
		local bd = GetFFD(bar)
		if not bd.bg then
			local bg = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
			bg:SetTexture(0.02, 0.02, 0.02, 1)
			bg:SetAllPoints(bar)
			bd.bg = bg
			WSkin.AddBorder(bar)
		end
		H.White(_G.AuctionProgressBarText)
	end
	if _G.AuctionProgressBarIcon then
		WSkin.SquareIcon(_G.AuctionProgressBarIcon, p)
	end
	if _G.AuctionProgressFrameCancelButton then
		WSkin.CloseButton(_G.AuctionProgressFrameCancelButton)
	end
end

local _hooked = false
local function Skin_AuctionHouse()
	local f = _G.AuctionFrame
	if not f then
		return
	end
	-- The 832 x 447 rect carries transparent art margins.
	WSkin.Shell("auctionhouse", f, { inset = { 12, 10, 0, 8 }, topBar = 28 })
	H.Fade("AuctionPortraitTexture")
	WSkin.CommonChrome(f, "AuctionFrame") -- close, inputs, dropdowns, scroll bars
	for i = 1, #AH.TITLES do
		H.White(_G[AH.TITLES[i]])
	end

	for i = 1, (f.numTabs or 3) do
		local tab = _G["AuctionFrameTab" .. i]
		if tab then
			WSkin.Tab(tab, H.BOTTOM_TAB)
		end
	end

	for _, n in ipairs({ "BrowseFilterScrollFrame", "BrowseScrollFrame", "BidScrollFrame", "AuctionsScrollFrame" }) do
		H.ScrollArt(n)
	end
	for i = 1, #AH.SORTS do
		AH.Header(_G[AH.SORTS[i]])
	end
	for _, prefix in pairs(AH.LISTS) do
		local i = 1
		while _G[prefix .. i] do
			AH.Row(_G[prefix .. i])
			i = i + 1
		end
	end
	local fi = 1
	while _G["AuctionFilterButton" .. fi] do
		AH.Filter(_G["AuctionFilterButton" .. fi])
		fi = fi + 1
	end

	for _, n in ipairs({ "IsUsableCheckButton", "ShowOnPlayerCheckButton" }) do
		if _G[n] then
			WSkin.Checkbox(_G[n])
			H.White(_G[n .. "Text"])
		end
	end
	for _, n in ipairs({ "BrowseBidPrice", "BidBidPrice", "StartPrice", "BuyoutPrice" }) do
		H.MoneyInput(n)
	end
	for _, n in ipairs({ "AuctionsStackSizeEntry", "AuctionsNumStacksEntry" }) do
		if _G[n] then
			WSkin.EditBox(_G[n])
		end
	end
	for i = 1, #AH.STATE_BUTTONS do
		H.StateBtn(_G[AH.STATE_BUTTONS[i]])
	end
	WSkin.ButtonsIn(f) -- any other 3-slice button, flattened
	H.LabeledPage(_G.BrowsePrevPageButton, "<")
	H.LabeledPage(_G.BrowseNextPageButton, ">")
	AH.SellSlot()
	AH.Progress()

	if not _hooked then
		_hooked = true
		WSkin.HookShow(f, WSkin.Debounce(function()
			if f:IsVisible() then
				Skin_AuctionHouse()
			end
		end))
	end
end

WSkin.RegisterWindow({
	key = "auctionhouse",
	label = "Auction House",
	description = "The auction house: browse, bids, and auctions views.",
	order = 310,
	addons = { Blizzard_AuctionUI = true },
	elvui = "auctionhouse",
	apply = Skin_AuctionHouse,
})
end

-------------------------------------------------------------------------------
--  Macros (MacroFrame + MacroPopupFrame, Blizzard_MacroUI). Shell, top tabs,
--  action buttons, text well; icon grid slot art at 50%.
-------------------------------------------------------------------------------
do
local MC = {}

function MC.Grid(prefix)
	local i = 1
	while _G[prefix .. i] do
		H.DimSlot(_G[prefix .. i])
		i = i + 1
	end
end

-- Name-and-icon picker popup.
function MC.Popup()
	local p = _G.MacroPopupFrame
	if not p or BS.Forbidden(p) then
		return
	end
	WSkin.Panel(p)
	local eb = _G.MacroPopupEditBox
	if eb then
		H.Fade("MacroPopupNameLeft", "MacroPopupNameMiddle", "MacroPopupNameRight")
		WSkin.EditBox(eb, { inset = { -6, -2, 0, -2 } })
	end
	H.Btn(_G.MacroPopupOkayButton)
	H.Btn(_G.MacroPopupCancelButton)
	H.ScrollArt("MacroPopupScrollFrame")
	local regions = { p:GetRegions() }
	for i = 1, #regions do
		local r = regions[i]
		if r and r.IsObjectType and r:IsObjectType("FontString") then
			H.White(r)
		end
	end
	MC.Grid("MacroPopupButton")
end

local _hooked = false
local function Skin_Macros()
	local f = _G.MacroFrame
	if not f then
		return
	end
	WSkin.Shell("macros", f)
	WSkin.RemovePortrait(f)
	WSkin.CommonChrome(f, "MacroFrame")
	if _G.MacroFrameInset then
		WSkin.Inset(_G.MacroFrameInset)
	end
	for _, n in ipairs({ "MacroSaveButton", "MacroCancelButton", "MacroDeleteButton",
		"MacroNewButton", "MacroExitButton", "MacroEditButton" }) do
		H.Btn(_G[n])
	end
	for i = 1, 2 do
		local t = _G["MacroFrameTab" .. i]
		if t then
			WSkin.Tab(t, { darkActive = true })
		end
	end
	H.ScrollArt("MacroButtonScrollFrame")
	H.ScrollArt("MacroFrameScrollFrame")
	MC.Grid("MacroButton")
	H.DimSlot(_G.MacroFrameSelectedMacroButton)

	-- Macro body text well: near-black fill + themed border.
	local tb = _G.MacroFrameTextBackground
	if tb then
		local td = GetFFD(tb)
		if not td.well then
			if tb.SetBackdropColor then
				tb:SetBackdropColor(0, 0, 0, 0)
				tb:SetBackdropBorderColor(0, 0, 0, 0)
			end
			local host = CreateFrame("Frame", nil, tb)
			host:SetPoint("TOPLEFT", tb, "TOPLEFT", 4, -4)
			host:SetPoint("BOTTOMRIGHT", tb, "BOTTOMRIGHT", -4, 4)
			host:SetFrameLevel(math.max(0, tb:GetFrameLevel()))
			local fill = host:CreateTexture(nil, "BACKGROUND", nil, -6)
			fill:SetTexture(0.02, 0.02, 0.02, 1)
			fill:SetAllPoints(host)
			WSkin.AddBorder(host)
			td.well = host
		end
	end
	H.White(_G.MacroFrameSelectedMacroName)
	H.White(_G.MacroFrameCharLimitText)
	H.White(_G.MacroFrameEnterMacroText)

	MC.Popup()

	if not _hooked then
		_hooked = true
		WSkin.HookShow(f, WSkin.Debounce(function()
			if f:IsVisible() then
				Skin_Macros()
			end
		end))
		if _G.MacroPopupFrame then
			WSkin.HookShow(_G.MacroPopupFrame, WSkin.Debounce(function()
				if _G.MacroPopupFrame:IsVisible() then
					MC.Popup()
				end
			end))
		end
	end
end

WSkin.RegisterWindow({
	key = "macros",
	label = "Macros",
	description = "The macro editor: tabs, icon grid, text well, and buttons.",
	order = 320,
	addons = { Blizzard_MacroUI = true },
	elvui = "macro",
	apply = Skin_Macros,
})
end

-------------------------------------------------------------------------------
--  Options Panel: Interface options, System options (video / sound) and the
--  key bindings window. Chrome (frame, tabs, category rail, buttons) plus the
--  controls on Blizzard's own panels (checkboxes, sliders, dropdowns). Addon
--  panels in the same window are left alone.
-------------------------------------------------------------------------------
do
local OP = {}
OP.FRAMES = { "InterfaceOptionsFrame", "VideoOptionsFrame", "AudioOptionsFrame" }
OP.LISTS = { "Categories", "AddOns", "CategoryFrame" }

-- One options window (OptionsFrameTemplate style).
function OP.Window(name)
	local f = _G[name]
	if not f or BS.Forbidden(f) then
		return
	end
	if f.SetBackdropColor then
		f:SetBackdropColor(0, 0, 0, 0)
		f:SetBackdropBorderColor(0, 0, 0, 0)
	end
	WSkin.Shell("settings", f)
	H.CenterTitle(f, _G[name .. "HeaderText"])
	for _, b in ipairs({ "Okay", "Cancel", "Defaults", "Apply" }) do
		H.Btn(_G[name .. b])
	end
	-- Category rails.
	for _, l in ipairs(OP.LISTS) do
		local list = _G[name .. l]
		if list then
			WSkin.Panel(list, { inset = true })
			local sb = _G[name .. l .. "ListScrollBar"]
			if sb then
				WSkin.ScrollBar(sb)
			end
			local i = 1
			while _G[name .. l .. "Button" .. i] do
				local b = _G[name .. l .. "Button" .. i]
				local hl = b.GetHighlightTexture and b:GetHighlightTexture()
				if hl and not GetFFD(b).railHL then
					GetFFD(b).railHL = true
					hl:SetTexture(1, 1, 1, 0.1)
				end
				i = i + 1
			end
		end
	end
	-- Panel container: tooltip edge -> house panel.
	local pc = _G[name .. "PanelContainer"]
	if pc then
		if pc.SetBackdropColor and not GetFFD(pc).opt then
			GetFFD(pc).opt = true
			pc:SetBackdropColor(0, 0, 0, 0)
			pc:SetBackdropBorderColor(0, 0, 0, 0)
		end
		WSkin.Panel(pc, { shade = true })
		-- Controls on Blizzard's own panels only.
		local children = { pc:GetChildren() }
		for i = 1, #children do
			local c = children[i]
			if c and H.IsBlizzardFrame(c) then
				H.OptionControls(c)
			end
		end
	end
	-- Game / AddOns tabs.
	local i = 1
	while _G[name .. "Tab" .. i] do
		WSkin.Tab(_G[name .. "Tab" .. i], { darkActive = true })
		i = i + 1
	end
end

local _hooked = false
local function Skin_Settings()
	for i = 1, #OP.FRAMES do
		OP.Window(OP.FRAMES[i])
	end
	if not _hooked then
		_hooked = true
		-- Panels and their controls appear late (CUF profiles, addon load):
		-- re-run on every open (idempotent).
		for i = 1, #OP.FRAMES do
			local f = _G[OP.FRAMES[i]]
			local fname = OP.FRAMES[i]
			if f and f.HookScript then
				WSkin.HookShow(f, WSkin.Debounce(function()
					if f:IsVisible() then
						OP.Window(fname)
					end
				end))
			end
		end
	end
end

WSkin.RegisterWindow({
	key = "settings",
	label = "Options Panel",
	description = "Blizzard's options windows (Interface, System and Key Bindings): frame, tabs, category rail, buttons and controls.",
	order = 330,
	elvui = "BlizzardOptions",
	apply = Skin_Settings,
})

-- Key Bindings (KeyBindingFrame, Blizzard_BindingUI): same look.
local _bindHooked = false
local function Skin_Bindings()
	local f = _G.KeyBindingFrame
	if not f or BS.Forbidden(f) then
		return
	end
	WSkin.Shell("settings", f, { inset = { 2, 0, 42, 12 } })
	H.CenterTitle(f, _G.KeyBindingFrameHeaderText)
	for _, n in ipairs({ "KeyBindingFrameCommandLabel", "KeyBindingFrameKey1Label", "KeyBindingFrameKey2Label" }) do
		H.White(_G[n])
	end
	local i = 1
	while _G["KeyBindingFrameBinding" .. i] do
		local row = "KeyBindingFrameBinding" .. i
		WSkin.Button(_G[row .. "Key1Button"])
		WSkin.Button(_G[row .. "Key2Button"])
		i = i + 1
	end
	H.ScrollArt("KeyBindingFrameScrollFrame")
	if _G.KeyBindingFrameCharacterButton then
		WSkin.Checkbox(_G.KeyBindingFrameCharacterButton)
	end
	for _, n in ipairs({ "KeyBindingFrameDefaultButton", "KeyBindingFrameCancelButton",
		"KeyBindingFrameOkayButton", "KeyBindingFrameUnbindButton" }) do
		H.StateBtn(_G[n])
	end
	if not _bindHooked then
		_bindHooked = true
		WSkin.HookShow(f, WSkin.Debounce(function()
			if f:IsVisible() then
				Skin_Bindings()
			end
		end))
	end
end

WSkin.RegisterWindow({
	key = "settings",
	addons = { Blizzard_BindingUI = true },
	elvui = "binding",
	apply = Skin_Bindings,
})
end

-------------------------------------------------------------------------------
--  Class / Profession Trainer (ClassTrainerFrame, Blizzard_TrainerUI). Flat
--  chrome, squared skill icons, flat train button. Blizzard's availability
--  text color is KEPT (green / red / gray), as in retail.
-------------------------------------------------------------------------------
do
local TR = {}

-- One skill row (UIServiceButtonTemplate).
function TR.Row(row)
	if not row or BS.Forbidden(row) then
		return
	end
	local d = GetFFD(row)
	if d.trainerRow then
		return
	end
	d.trainerRow = true
	local icon = row.icon or _G[(row:GetName() or "") .. "Icon"]
	if icon then
		WSkin.SquareIcon(icon, row)
	end
	if row.name then
		WSkin.Font(row.name)
	end
	if row.subText then
		WSkin.Font(row.subText)
	end
	local nt = row.GetNormalTexture and row:GetNormalTexture()
	if nt then
		nt:SetAlpha(0)
	end
	if row.disabledBG then
		row.disabledBG:SetAlpha(0)
	end
	if row.selectedTex then
		row.selectedTex:SetTexture(1, 1, 1, 0.15)
	end
	local hl = row.GetHighlightTexture and row:GetHighlightTexture()
	if hl then
		hl:SetTexture(1, 1, 1, 0.1)
	end
end

function TR.Rows()
	local sf = _G.ClassTrainerScrollFrame
	local buttons = sf and sf.buttons
	if type(buttons) == "table" then
		for i = 1, #buttons do
			TR.Row(buttons[i])
		end
	else
		local i = 1
		while _G["ClassTrainerScrollFrameButton" .. i] do
			TR.Row(_G["ClassTrainerScrollFrameButton" .. i])
			i = i + 1
		end
	end
end

local _hooked = false
local function Skin_Trainer()
	local f = _G.ClassTrainerFrame
	if not f then
		return
	end
	WSkin.Shell("trainer", f)
	WSkin.RemovePortrait(f)
	WSkin.CommonChrome(f, "ClassTrainerFrame") -- close, filter dropdown, scroll bar
	for _, n in ipairs({ "ClassTrainerFrameInset", "ClassTrainerFrameBottomInset" }) do
		if _G[n] then
			WSkin.Inset(_G[n])
		end
	end
	H.StateBtn(_G.ClassTrainerTrainButton)

	-- The current-step card on top: flat card + squared icon.
	local step = _G.ClassTrainerFrameSkillStepButton
	if step then
		TR.Row(step)
		local sd = GetFFD(step)
		if not sd.bg then
			local bg = step:CreateTexture(nil, "BACKGROUND", nil, -7)
			bg:SetTexture(Theme.bgR, Theme.bgG, Theme.bgB, Theme.bgA)
			bg:SetAllPoints(step)
			sd.bg = bg
			WSkin.AddBorder(step)
		end
	end
	TR.Rows()

	-- Profession skill rank bar: art gone, flat fill, white rank text.
	local bar = _G.ClassTrainerStatusBar
	if bar then
		H.FadeKeys(bar, { "Left", "Right", "Middle", "Background" })
		WSkin.ApplyBarFill(bar)
		local bd = GetFFD(bar)
		if not bd.bg then
			local bg = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
			bg:SetTexture(0.02, 0.02, 0.02, 1)
			bg:SetAllPoints(bar)
			bd.bg = bg
			WSkin.AddBorder(bar)
		end
		H.White(bar.rankText or _G.ClassTrainerStatusBarSkillRank)
	end

	if not _hooked then
		_hooked = true
		if type(_G.ClassTrainerFrame_Update) == "function" then
			hooksecurefunc("ClassTrainerFrame_Update", WSkin.Debounce(TR.Rows))
		end
		WSkin.HookShow(f, WSkin.Debounce(function()
			if f:IsVisible() then
				Skin_Trainer()
			end
		end))
	end
end

WSkin.RegisterWindow({
	key = "trainer",
	label = "Trainer",
	description = "The class and profession trainer window: skill list, train button, and cost display.",
	order = 360,
	addons = { Blizzard_TrainerUI = true },
	elvui = "trainer",
	apply = Skin_Trainer,
})
end

-------------------------------------------------------------------------------
--  Gossip (GossipFrame): NPC dialog window. Base UI. Parchment gone, white
--  greeting and option text, flat goodbye button. The book / letter reading
--  window (ItemTextFrame) gets the same treatment under this key.
-------------------------------------------------------------------------------
do
local GS = {}

function GS.Texts()
	local g = _G.GossipGreetingText
	if g then
		g:SetTextColor(1, 1, 1)
	end
	local i = 1
	while _G["GossipTitleButton" .. i] do
		local b = _G["GossipTitleButton" .. i]
		local fs = b.GetFontString and b:GetFontString()
		if fs then
			fs:SetTextColor(1, 1, 1)
			H.RecolorDarkText(fs)
		end
		i = i + 1
	end
end

local _hooked = false
local function Skin_Gossip()
	local f = _G.GossipFrame
	if not f then
		return
	end
	WSkin.Shell("gossip", f)
	WSkin.RemovePortrait(f)
	WSkin.CommonChrome(f, "GossipFrame") -- close + scroll bar
	if _G.GossipFrameInset then
		WSkin.Inset(_G.GossipFrameInset)
	end
	local gp = _G.GossipFrameGreetingPanel
	if gp then
		WSkin.FadeRegions(gp)
		WSkin.Register(gp, true)
	end
	H.ScrollArt("GossipGreetingScrollFrame")
	H.White(_G.GossipFrameNpcNameText)
	H.Btn(_G.GossipFrameGreetingGoodbyeButton)
	-- Friendship bar (some NPCs): thin black notches.
	for i = 1, 4 do
		local notch = _G["NPCFriendshipStatusBarNotch" .. i]
		if notch then
			notch:SetTexture(0, 0, 0, 1)
		end
	end
	GS.Texts()

	if not _hooked then
		_hooked = true
		if type(_G.GossipFrameUpdate) == "function" then
			hooksecurefunc("GossipFrameUpdate", GS.Texts)
		end
		WSkin.HookShow(f, WSkin.Debounce(function()
			if f:IsVisible() then
				Skin_Gossip()
			end
		end))
	end
end

WSkin.RegisterWindow({
	key = "gossip",
	label = "Gossip",
	description = "The NPC dialog window: greeting text, gossip and quest options, and goodbye button.",
	order = 370,
	elvui = "gossip",
	apply = Skin_Gossip,
})

-- Book / letter / plaque text (ItemTextFrame).
function GS.ItemTextColor()
	local t = _G.ItemTextPageText
	if not t or not t.SetTextColor then
		return
	end
	pcall(t.SetTextColor, t, 1, 1, 1)
	for _, el in ipairs({ "P", "H1", "H2", "H3" }) do
		pcall(t.SetTextColor, t, el, 1, 1, 1)
	end
end

local _itHooked = false
local function Skin_ItemText()
	local f = _G.ItemTextFrame
	if not f then
		return
	end
	WSkin.Shell("gossip", f)
	WSkin.RemovePortrait(f)
	WSkin.CommonChrome(f, "ItemTextFrame")
	if _G.ItemTextFrameInset then
		WSkin.Inset(_G.ItemTextFrameInset)
	end
	H.ScrollArt("ItemTextScrollFrame")
	H.White(_G.ItemTextTitleText)
	H.White(_G.ItemTextCurrentPage)
	H.LabeledPage(_G.ItemTextPrevPageButton, "<")
	H.LabeledPage(_G.ItemTextNextPageButton, ">")
	GS.ItemTextColor()
	if not _itHooked then
		_itHooked = true
		-- Blizzard re-colors the page per material on every page.
		f:HookScript("OnEvent", GS.ItemTextColor)
		WSkin.HookShow(f, WSkin.Debounce(function()
			if f:IsVisible() then
				Skin_ItemText()
			end
		end))
	end
end

WSkin.RegisterWindow({
	key = "gossip",
	elvui = "itemText",
	apply = Skin_ItemText,
})
end

-------------------------------------------------------------------------------
--  Quest (QuestFrame): NPC quest window, detail / progress / reward /
--  greeting panels. Parchment gone, gold headers + white body, flat action
--  buttons, reward tiles squared with a rarity border.
-------------------------------------------------------------------------------
do
local Q = {}
Q.PANELS = { "QuestFrameDetailPanel", "QuestFrameProgressPanel", "QuestFrameRewardPanel", "QuestFrameGreetingPanel" }
Q.SCROLLS = { "QuestDetailScrollFrame", "QuestProgressScrollFrame", "QuestRewardScrollFrame", "QuestGreetingScrollFrame" }
Q.BUTTONS = { "QuestFrameAcceptButton", "QuestFrameDeclineButton", "QuestFrameCompleteButton",
	"QuestFrameGoodbyeButton", "QuestFrameCompleteQuestButton", "QuestFrameGreetingGoodbyeButton" }
Q.HEADERS = { "QuestInfoTitleHeader", "QuestInfoDescriptionHeader", "QuestInfoObjectivesHeader", "QuestInfoRewardsHeader" }
Q.BODY = { "QuestInfoDescriptionText", "QuestInfoObjectivesText", "QuestInfoGroupSize", "QuestInfoRewardText",
	"QuestInfoItemChooseText", "QuestInfoItemReceiveText", "QuestInfoSpellLearnText", "QuestInfoXPFrameReceiveText",
	"QuestInfoReputationText", "QuestInfoTimerText", "QuestInfoAnchor" }
Q.TILES = { "QuestInfoRewardSpell", "QuestInfoSpellObjectiveFrame", "QuestInfoSkillPointFrame", "QuestInfoTalentFrame" }

-- True when a QuestInfo display lands inside the NPC quest window (the
-- QuestInfo frames are shared with the quest log).
function Q.InQuestFrame(frame)
	local qf = _G.QuestFrame
	local p = frame
	for _ = 1, 10 do
		if not p then
			return false
		end
		if p == qf then
			return true
		end
		p = p.GetParent and p:GetParent()
	end
	return false
end

-- Reward / required item tiles.
function Q.Tiles()
	local useLog = _G.QuestInfoFrame and _G.QuestInfoFrame.questLog
	local i = 1
	while _G["QuestInfoItem" .. i] do
		local item = _G["QuestInfoItem" .. i]
		WSkin.QuestRewardTile(item)
		local link = nil
		if item.type and item.GetID then
			local fn = useLog and GetQuestLogItemLink or GetQuestItemLink
			link = fn and fn(item.type, item:GetID())
		end
		WSkin.SetQualityColor(item, link)
		i = i + 1
	end
	for t = 1, #Q.TILES do
		local tile = _G[Q.TILES[t]]
		if tile then
			WSkin.QuestRewardTile(tile)
			H.FadeKeys(tile, { "SpellBorder" })
		end
	end
	local pt = _G.QuestInfoPlayerTitleFrame
	if pt then
		H.FadeKeys(pt, { "TitleFrameLeft", "TitleFrameCenter" })
		local icon = _G.QuestInfoPlayerTitleFrameIconTexture
		if icon then
			WSkin.SquareIcon(icon, pt)
		end
	end
end

function Q.ProgressTiles()
	local i = 1
	while _G["QuestProgressItem" .. i] do
		local item = _G["QuestProgressItem" .. i]
		WSkin.QuestRewardTile(item)
		local link = nil
		if item.type and item.GetID and GetQuestItemLink then
			link = GetQuestItemLink(item.type, item:GetID())
		end
		WSkin.SetQualityColor(item, link)
		i = i + 1
	end
	if _G.QuestProgressTitleText then
		_G.QuestProgressTitleText:SetTextColor(1, 0.82, 0)
	end
	if _G.QuestProgressText then
		_G.QuestProgressText:SetTextColor(1, 1, 1)
	end
	if _G.QuestProgressRequiredItemsText then
		_G.QuestProgressRequiredItemsText:SetTextColor(1, 0.82, 0)
	end
	local rm = _G.QuestProgressRequiredMoneyText
	if rm then
		-- Blizzard: black = enough money, dark gray = not enough.
		-- Runs twice per open (update hook + panel OnShow): only react to
		-- Blizzard's own dark colors.
		local r = rm:GetTextColor()
		if type(r) == "number" and r > 0.1 and r < 0.5 then
			rm:SetTextColor(0.6, 0.6, 0.6)
		elseif type(r) == "number" and r <= 0.1 then
			rm:SetTextColor(1, 1, 1)
		end
	end
end

-- Body text of the shared QuestInfo frames, inside the NPC window only.
function Q.InfoText()
	for i = 1, #Q.HEADERS do
		local fs = _G[Q.HEADERS[i]]
		if fs then
			fs:SetTextColor(1, 0.82, 0)
		end
	end
	for i = 1, #Q.BODY do
		local fs = _G[Q.BODY[i]]
		if fs then
			fs:SetTextColor(1, 1, 1)
		end
	end
	-- Objectives: Blizzard paints done ones dark gray, open ones black.
	local i = 1
	while _G["QuestInfoObjective" .. i] do
		local o = _G["QuestInfoObjective" .. i]
		local r = o:GetTextColor()
		if type(r) == "number" and r > 0.1 and r < 0.5 then
			o:SetTextColor(0.6, 0.6, 0.6)
		elseif type(r) == "number" and r <= 0.1 then
			o:SetTextColor(1, 1, 1)
		end
		i = i + 1
	end
	for _, n in ipairs({ "QuestInfoRequiredMoneyText", "QuestInfoSpellObjectiveLearnLabel" }) do
		local fs = _G[n]
		if fs then
			local r = fs:GetTextColor()
			if type(r) == "number" and r > 0.1 and r < 0.5 then
				fs:SetTextColor(0.6, 0.6, 0.6)
			elseif type(r) == "number" and r <= 0.1 then
				fs:SetTextColor(1, 1, 1)
			end
		end
	end
	local r = 1
	while _G["QuestInfoReputation" .. r .. "Faction"] do
		_G["QuestInfoReputation" .. r .. "Faction"]:SetTextColor(1, 1, 1)
		r = r + 1
	end
end

-- Greeting panel: text white, quest titles white (baked black rewritten).
function Q.Greeting()
	for _, n in ipairs({ "GreetingText", "CurrentQuestsText", "AvailableQuestsText" }) do
		local fs = _G[n]
		if fs then
			fs:SetTextColor(1, 1, 1)
		end
	end
	H.Fade("QuestGreetingFrameHorizontalBreak")
	local i = 1
	while _G["QuestTitleButton" .. i] do
		local b = _G["QuestTitleButton" .. i]
		local fs = b.GetFontString and b:GetFontString()
		if fs then
			fs:SetTextColor(1, 1, 1)
			H.RecolorDarkText(fs)
		end
		i = i + 1
	end
end

local _hooked = false
local function Skin_Quest()
	local f = _G.QuestFrame
	if not f then
		return
	end
	WSkin.Shell("quest", f)
	WSkin.RemovePortrait(f)
	WSkin.CommonChrome(f, "QuestFrame")
	if _G.QuestFrameInset then
		WSkin.Inset(_G.QuestFrameInset)
	end
	H.White(_G.QuestFrameNpcNameText)
	for i = 1, #Q.PANELS do
		local p = _G[Q.PANELS[i]]
		if p then
			WSkin.FadeRegions(p)
			WSkin.Register(p, true)
		end
	end
	for i = 1, #Q.SCROLLS do
		H.ScrollArt(Q.SCROLLS[i])
	end
	for i = 1, #Q.BUTTONS do
		H.StateBtn(_G[Q.BUTTONS[i]])
	end
	Q.Tiles()
	Q.Greeting()

	if not _hooked then
		_hooked = true
		if type(_G.QuestInfo_Display) == "function" then
			hooksecurefunc("QuestInfo_Display", function(_, parentFrame)
				pcall(Q.Tiles)
				if Q.InQuestFrame(parentFrame) then
					pcall(Q.InfoText)
				end
			end)
		end
		if type(_G.QuestFrameProgressItems_Update) == "function" then
			hooksecurefunc("QuestFrameProgressItems_Update", function()
				pcall(Q.ProgressTiles)
			end)
		end
		-- Panel OnShow scripts are XML function references: hook the panels.
		local gp = _G.QuestFrameGreetingPanel
		if gp then
			gp:HookScript("OnShow", Q.Greeting)
		end
		local pp = _G.QuestFrameProgressPanel
		if pp then
			pp:HookScript("OnShow", Q.ProgressTiles)
		end
		WSkin.HookShow(f, WSkin.Debounce(function()
			if f:IsVisible() then
				Skin_Quest()
			end
		end))
	end
end

WSkin.RegisterWindow({
	key = "quest",
	label = "Quest",
	description = "The NPC quest window: quest detail, progress, and reward panels plus the multi-quest greeting list.",
	order = 380,
	elvui = "quest",
	apply = Skin_Quest,
})
end

-------------------------------------------------------------------------------
--  Trade (TradeFrame): frame, both item columns, the enchant slots, money
--  rows and buttons. Item icons squared with a rarity border, name plates as
--  flat boxes. Both portraits removed.
-------------------------------------------------------------------------------
do
local TD = {}
TD.INSETS = { "TradeFrameInset", "TradeRecipientItemsInset", "TradeRecipientEnchantInset",
	"TradePlayerItemsInset", "TradePlayerEnchantInset", "TradePlayerInputMoneyInset", "TradeRecipientMoneyInset" }
TD.TEXTS = { "TradeFramePlayerNameText", "TradeFrameRecipientNameText",
	"TradeFramePlayerEnchantText", "TradeFrameRecipientEnchantText" }

-- One trade slot: socket + name plate + enchant glyph gone, flat name box,
-- squared item icon.
function TD.Slot(slot)
	if not slot or BS.Forbidden(slot) then
		return
	end
	local n = slot:GetName()
	local nameFrame = n and _G[n .. "NameFrame"]
	if nameFrame then
		H.Box(slot, nameFrame, 14)
	end
	local d = GetFFD(slot)
	WSkin.FadeRegions(slot, d.box and { [d.box] = true } or nil)
	local nameFS = n and _G[n .. "Name"]
	if nameFS then
		WSkin.Font(nameFS)
	end
	H.ItemTile(n and _G[n .. "ItemButton"])
end

function TD.Paint(side, id)
	local prefix = side == "player" and "TradePlayerItem" or "TradeRecipientItem"
	local btn = _G[prefix .. id .. "ItemButton"]
	if not btn then
		return
	end
	local fn = side == "player" and GetTradePlayerItemLink or GetTradeTargetItemLink
	WSkin.SetQualityColor(btn, fn and fn(id))
end

local _hooked = false
local function Skin_Trade()
	local f = _G.TradeFrame
	if not f or BS.Forbidden(f) then
		return
	end
	WSkin.Shell("trade", f)
	WSkin.RemovePortrait(f)
	H.Fade("TradeFramePlayerPortrait", "TradeFrameRecipientPortrait", "TradeRecipientPortraitFrame")
	WSkin.CommonChrome(f, "TradeFrame") -- close + money input boxes
	for i = 1, #TD.INSETS do
		local ins = _G[TD.INSETS[i]]
		if ins then
			WSkin.Inset(ins)
		end
	end
	local mb = _G.TradeRecipientMoneyBg
	if mb then
		WSkin.FadeRegions(mb)
		WSkin.Register(mb, true)
	end
	H.MoneyInput("TradePlayerInputMoneyFrame")
	for i = 1, 7 do
		TD.Slot(_G["TradePlayerItem" .. i])
		TD.Slot(_G["TradeRecipientItem" .. i])
		TD.Paint("player", i)
		TD.Paint("target", i)
	end
	for i = 1, #TD.TEXTS do
		H.White(_G[TD.TEXTS[i]])
	end
	H.StateBtn(_G.TradeFrameTradeButton)
	H.Btn(_G.TradeFrameCancelButton)

	if not _hooked then
		_hooked = true
		if type(_G.TradeFrame_UpdatePlayerItem) == "function" then
			hooksecurefunc("TradeFrame_UpdatePlayerItem", function(id)
				TD.Paint("player", id)
			end)
		end
		if type(_G.TradeFrame_UpdateTargetItem) == "function" then
			hooksecurefunc("TradeFrame_UpdateTargetItem", function(id)
				TD.Paint("target", id)
			end)
		end
		WSkin.HookShow(f, WSkin.Debounce(function()
			if f:IsVisible() then
				Skin_Trade()
			end
		end))
	end
end

WSkin.RegisterWindow({
	key = "trade",
	label = "Trade",
	description = "The player-to-player trade window: frame, both item columns, the enchant slots, money rows and buttons. Item icons are squared and carry a rarity border. Both portraits are removed, as on every other window.",
	order = 450,
	elvui = "trade",
	apply = Skin_Trade,
})
end

-------------------------------------------------------------------------------
--  Dressing Room (DressUpFrame + the auction house side preview,
--  SideDressUpFrame). Chrome + buttons; the 3D model stays stock content.
-------------------------------------------------------------------------------
do
local _hooked = false
local function Skin_DressUp()
	local f = _G.DressUpFrame
	if f then
		-- 384 x 512 rect, the visible panel sits inside it.
		WSkin.Shell("dressup", f, { inset = { 10, 12, 33, 73 } })
		WSkin.RemovePortrait(f)
		WSkin.CommonChrome(f, "DressUpFrame") -- close + centered title
		H.White(_G.DressUpFrameDescriptionText)
		H.Btn(_G.DressUpFrameResetButton)
		H.Btn(_G.DressUpFrameCancelButton)
	end
	local side = _G.SideDressUpFrame
	if side then
		WSkin.Shell("dressup", side, { noTopBar = true, inset = { 3, 11, 9, 9 } })
		H.Btn(_G.SideDressUpModelResetButton)
		if _G.SideDressUpModelCloseButton then
			WSkin.CloseButton(_G.SideDressUpModelCloseButton)
		end
	end
	if not _hooked then
		_hooked = true
		-- Blizzard re-textures the race backdrop on every open.
		if f then
			WSkin.HookShow(f, WSkin.Debounce(function()
				if f:IsVisible() then
					Skin_DressUp()
				end
			end))
		end
		if side then
			WSkin.HookShow(side, WSkin.Debounce(function()
				if side:IsVisible() then
					Skin_DressUp()
				end
			end))
		end
	end
end

WSkin.RegisterWindow({
	key = "dressup",
	label = "Dressing Room",
	description = "The item preview / transmog dressing room window.",
	order = 280,
	elvui = "dressingroom",
	apply = Skin_DressUp,
})
end

-------------------------------------------------------------------------------
--  Transmogrifier (TransmogrifyFrame, Blizzard_ItemAlterationUI). Chrome,
--  slot buttons squared, apply button, money strip, confirmation popup. The
--  model and the flyouts stay stock content.
-------------------------------------------------------------------------------
do
local TM = {}
TM.SLOTS = { "HeadSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "WristSlot", "HandsSlot",
	"WaistSlot", "LegsSlot", "FeetSlot", "MainHandSlot", "SecondaryHandSlot" }

function TM.Slot(btn)
	if not btn or BS.Forbidden(btn) then
		return
	end
	local d = GetFFD(btn)
	H.FadeKeys(btn, { "Border", "Grabber" })
	if d.tmSlot then
		return
	end
	d.tmSlot = true
	local icon = btn.icon or _G[(btn:GetName() or "") .. "IconTexture"]
	if icon then
		WSkin.SquareIcon(icon, btn)
		local well = btn:CreateTexture(nil, "BACKGROUND", nil, -7)
		well:SetTexture(0.02, 0.02, 0.02, 0.8)
		well:SetAllPoints(icon)
		d.bg = well
	end
	local hl = btn.GetHighlightTexture and btn:GetHighlightTexture()
	if hl then
		hl:SetTexture(1, 1, 1, 0.12)
		if icon then
			hl:ClearAllPoints()
			hl:SetAllPoints(icon)
		end
	end
end

function TM.Popup()
	local p = _G.TransmogrifyConfirmationPopup
	if not p or BS.Forbidden(p) then
		return
	end
	WSkin.Panel(p)
	H.Btn(p.Button1)
	H.Btn(p.Button2)
	H.White(p.Text)
	for i = 1, 2 do
		H.ItemTile(_G["TransmogrifyConfirmationPopupItemFrame" .. i])
	end
end

local _hooked = false
local function Skin_Transmog()
	local f = _G.TransmogrifyFrame
	if not f then
		return
	end
	WSkin.Shell("transmog", f)
	-- The visible chrome is the ethereal art frame on top.
	local art = _G.TransmogrifyArtFrame
	if art then
		WSkin.FadeRegions(art)
		WSkin.Register(art, true)
		WSkin.RemovePortrait(art)
		if _G.TransmogrifyArtFrameCloseButton then
			WSkin.CloseButton(_G.TransmogrifyArtFrameCloseButton)
		end
		H.CenterTitle(f, _G.TransmogrifyArtFrameTitleText)
	end
	local model = _G.TransmogrifyModelFrame
	if model then
		H.Fade("TransmogrifyModelFrameMarbleBg", "TransmogrifyModelFrameLines")
		local md = GetFFD(model)
		if not md.bg then
			local bg = model:CreateTexture(nil, "BACKGROUND", nil, -7)
			bg:SetTexture(0, 0, 0, 0.25)
			bg:SetAllPoints(model)
			md.bg = bg
			WSkin.AddBorder(model)
		end
	end
	for i = 1, #TM.SLOTS do
		TM.Slot(_G["TransmogrifyFrame" .. TM.SLOTS[i]])
	end
	local bf = _G.TransmogrifyFrameButtonFrame
	if bf then
		WSkin.FadeRegions(bf)
		WSkin.Register(bf, true)
	end
	H.StateBtn(_G.TransmogrifyApplyButton)
	TM.Popup()

	if not _hooked then
		_hooked = true
		if type(_G.TransmogrifyConfirmationPopup_SetItem) == "function" then
			hooksecurefunc("TransmogrifyConfirmationPopup_SetItem", function(itemFrame, link)
				WSkin.SetQualityColor(itemFrame, link)
			end)
		end
		WSkin.HookShow(f, WSkin.Debounce(function()
			if f:IsVisible() then
				Skin_Transmog()
			end
		end))
	end
end

WSkin.RegisterWindow({
	key = "transmog",
	label = "Transmogrifier",
	description = "The transmogrification window at the transmogrifier.",
	order = 290,
	addons = { Blizzard_ItemAlterationUI = true },
	elvui = "transmogrify",
	apply = Skin_Transmog,
})
end

-------------------------------------------------------------------------------
--  Item Upgrades (ItemUpgradeFrame, Blizzard_ItemUpgradeUI). Flat shell with
--  a bottom band, squared upgrade slot with a rarity border, flat upgrade
--  button, currency strip without its plate art.
-------------------------------------------------------------------------------
do
local IU = {}

function IU.Paint()
	local f = _G.ItemUpgradeFrame
	local ib = f and f.ItemButton
	if not ib then
		return
	end
	local icon = ib.IconTexture
	local tex, _, quality = nil, nil, nil
	if GetItemUpgradeItemInfo then
		tex, _, quality = GetItemUpgradeItemInfo()
	end
	if icon then
		icon:SetAlpha(tex and 1 or 0)
	end
	H.PaintQuality(ib, quality)
end

-- Stat / effect rows: keep the striping, as a faint white wash.
function IU.Rows(f)
	for _, list in ipairs({ f.LeftStat, f.RightStat }) do
		if type(list) == "table" then
			for i = 1, #list do
				local bg = list[i] and list[i].BG
				if bg then
					bg:SetTexture(1, 1, 1, 0.03)
				end
			end
		end
	end
	if type(f.EffectRow) == "table" then
		for i = 1, #f.EffectRow do
			local row = f.EffectRow[i]
			if row then
				if row.LeftBg then row.LeftBg:SetTexture(1, 1, 1, 0.03) end
				if row.RightBg then row.RightBg:SetTexture(1, 1, 1, 0.03) end
			end
		end
	end
end

local _hooked = false
local function Skin_ItemUpgrade()
	local f = _G.ItemUpgradeFrame
	if not f then
		return
	end
	WSkin.Shell("itemupgrade", f, { bottomBar = true })
	WSkin.RemovePortrait(f)
	WSkin.CommonChrome(f, "ItemUpgradeFrame") -- close + centered title
	IU.Rows(f)

	local ib = f.ItemButton
	if ib then
		H.FadeKeys(ib, { "Grabber", "TextFrame", "TextGrabber", "Frame" })
		local icon = ib.IconTexture
		if icon then
			icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			H.Well(ib)
			local d = GetFFD(ib)
			if d.qBorder and not d.reseated then
				-- The rarity border hugs the icon, not the whole button.
				d.reseated = true
				d.qBorder:ClearAllPoints()
				d.qBorder:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
				d.qBorder:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
				if d.well then
					d.well:ClearAllPoints()
					d.well:SetAllPoints(icon)
				end
			end
		end
		local hl = ib.GetHighlightTexture and ib:GetHighlightTexture()
		if hl then
			hl:SetTexture(1, 1, 1, 0.12)
			if icon then
				hl:ClearAllPoints()
				hl:SetAllPoints(icon)
			end
		end
		if ib.Cost and ib.Cost.Icon then
			WSkin.SquareIcon(ib.Cost.Icon)
		end
		H.White(ib.ItemName)
		if ib.MissingText then
			ib.MissingText:SetTextColor(1, 0.82, 0)
		end
	end
	for _, k in ipairs({ "MissingDescription", "NoMoreUpgrades", "UpgradeStatus" }) do
		if f[k] then
			WSkin.White(f[k])
		end
	end
	if f.ButtonFrame then
		WSkin.FadeRegions(f.ButtonFrame)
		WSkin.Register(f.ButtonFrame, true)
	end
	local money = _G.ItemUpgradeFrameMoneyFrame
	if money then
		WSkin.FadeRegions(money)
		WSkin.Register(money, true)
		local cur = money.Currency
		if cur and cur.icon then
			WSkin.SquareIcon(cur.icon)
		end
	end
	H.StateBtn(_G.ItemUpgradeFrameUpgradeButton)
	IU.Paint()

	if not _hooked then
		_hooked = true
		if type(_G.ItemUpgradeFrame_Update) == "function" then
			hooksecurefunc("ItemUpgradeFrame_Update", function()
				pcall(IU.Paint)
			end)
		end
		WSkin.HookShow(f, WSkin.Debounce(function()
			if f:IsVisible() then
				Skin_ItemUpgrade()
			end
		end))
	end
end

WSkin.RegisterWindow({
	key = "itemupgrade",
	label = "Item Upgrades",
	description = "The item upgrade window: upgrade slot, stat changes, cost, and the currency strip.",
	order = 170,
	addons = { Blizzard_ItemUpgradeUI = true },
	elvui = "itemUpgrade",
	apply = Skin_ItemUpgrade,
})
end
