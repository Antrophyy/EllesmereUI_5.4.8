-------------------------------------------------------------------------------
--  EllesmereUIBlizzardSkin_WindowPacks1.lua (5.4.8 port)
--  Window skin packs, part 1: Adventure Guide, Collections, Talents &
--  Spellbook, Professions (book + Archaeology), Profession Crafting,
--  Map & Quest Log, Guild, Calendar, Achievements, Mail.
--  Port of the matching retail packs in EllesmereUIBlizzardSkin_WindowPacks.lua
--  on the Mists of Pandaria windows: style-aware shell, flat tabs with an
--  accent underline, flat buttons, flat accent bars, squared icons, white text.
--
--  LOCAL LIMIT: Lua 5.1 allows 200 active locals per function. Each pack
--  lives in its own do ... end block; only the few shared helpers below sit
--  outside a block.
-------------------------------------------------------------------------------
local addonName = ...
local ns = EllesmereUI
local BS = ns and ns.BlizzSkin
local WSkin = ns and ns.WSkin
if not (BS and WSkin) then
	return
end

local _G = _G
local Theme = WSkin.Theme
local GetFFD = WSkin.GetFFD
local FFD = WSkin.FFD
local SolidTex = WSkin.SolidTex
local WHITE = BS.WHITE
local Forbidden = BS.Forbidden

-------------------------------------------------------------------------------
--  Shared helpers (used by more than one pack)
-------------------------------------------------------------------------------
-- Alpha a texture / art-only frame out (visual only).
local function Fade(t)
	if t and t.SetAlpha then
		t:SetAlpha(0)
	end
end

-- Alpha out textures named in a list of globals.
local function FadeG(list)
	for i = 1, #list do
		local t = _G[list[i]]
		if t and t.IsObjectType and t:IsObjectType("Texture") then
			t:SetAlpha(0)
		end
	end
end

-- hooksecurefunc on a global function / a method, only when it exists.
local function HookFn(name, fn)
	if type(_G[name]) == "function" then
		hooksecurefunc(name, fn)
	end
end
local function HookM(obj, method, fn)
	if obj and type(obj[method]) == "function" then
		hooksecurefunc(obj, method, fn)
	end
end

-- Keep a texture invisible against Blizzard re-raising its alpha.
local function KillTex(t)
	if not t or not t.SetAlpha then
		return
	end
	t:SetAlpha(0)
	local d = GetFFD(t)
	if d.killed then
		return
	end
	d.killed = true
	hooksecurefunc(t, "SetAlpha", function(self)
		if d.inKill then
			return
		end
		d.inKill = true
		self:SetAlpha(0)
		d.inKill = false
	end)
end

-- Lock a font string to a color (colorFn(fs) or white) when Blizzard recolors it.
local function LockColor(fs, colorFn)
	if not fs or not fs.SetTextColor then
		return
	end
	local d = GetFFD(fs)
	d.colorFn = colorFn
	local function apply()
		if d.inLock then
			return
		end
		d.inLock = true
		if d.colorFn then
			d.colorFn(fs)
		else
			fs:SetTextColor(1, 1, 1)
		end
		d.inLock = false
	end
	apply()
	if not d.colorLocked then
		d.colorLocked = true
		hooksecurefunc(fs, "SetTextColor", apply)
	end
end

-- Dark parchment ink (black / brown / dark grey) -> light text.
local function LightenDark(fs, r, g, b)
	if not fs or not fs.GetTextColor then
		return
	end
	local cr, cg, cb = fs:GetTextColor()
	if type(cr) == "number" and type(cg) == "number" and type(cb) == "number" and (cr + cg + cb) < 1.2 then
		fs:SetTextColor(r or 0.82, g or 0.82, b or 0.82)
	end
end

-- Gold label (NORMAL_FONT_COLOR) -> white.
local function GoldToWhite(fs)
	if not fs or not fs.GetTextColor then
		return
	end
	local r, g, b = fs:GetTextColor()
	if type(r) == "number" and r > 0.9 and g > 0.7 and g < 0.9 and b < 0.25 then
		fs:SetTextColor(1, 1, 1)
	end
end

-- Flat accent progress bar: trough + border, Blizzard art gone, white text.
-- keepColor leaves Blizzard's fill color (health bars).
local BAR_PIECES = { "Left", "Right", "Middle", "BGLeft", "BGMiddle", "BGRight", "Background", "Border", "BG", "Bg",
	"LeftCap", "RightCap", "BorderLeft", "BorderRight", "BorderMid", "BarBG", "BarBorder" }
local function FlatBar(bar, keepColor)
	if not bar or Forbidden(bar) or not bar.GetRegions then
		return
	end
	local d = GetFFD(bar)
	local fill = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
	local keep = {}
	if fill then keep[fill] = true end
	if d.bg then keep[d.bg] = true end
	WSkin.FadeRegions(bar, keep)
	WSkin.FadeNamed(bar, BAR_PIECES)
	if bar.SetStatusBarTexture then
		if keepColor then
			bar:SetStatusBarTexture(WHITE)
		else
			WSkin.ApplyBarFill(bar)
		end
	end
	if not d.bg then
		local bg = SolidTex(bar, "BACKGROUND", 0.12, 0.12, 0.12, 0.85, -1)
		bg:SetAllPoints(bar)
		d.bg = bg
		WSkin.AddBorder(bar)
	end
	local regions = { bar:GetRegions() }
	for i = 1, #regions do
		local r = regions[i]
		if r and r.IsObjectType and r:IsObjectType("FontString") then
			WSkin.White(r)
		end
	end
	local n = bar.GetName and bar:GetName()
	for _, k in ipairs({ "Text", "Label", "Title", "text", "rankText", "Rank" }) do
		local fs = bar[k] or (n and _G[n .. k])
		if fs and fs.IsObjectType and fs:IsObjectType("FontString") then
			WSkin.White(fs)
		end
	end
end

-- Flat row block: dark fill (optionally inset), 1px border, white hover.
-- opts.inset = { l, t, r, b }, opts.noBorder, opts.hover (alpha), opts.color {r,g,b,a}.
local function RowBlock(btn, opts)
	if not btn or Forbidden(btn) then
		return
	end
	local d = GetFFD(btn)
	if d.bg then
		return d
	end
	opts = opts or {}
	local c = opts.color
	local bg = SolidTex(btn, "BACKGROUND", c and c[1] or (Theme.bgR + 0.015), c and c[2] or (Theme.bgG + 0.015),
		c and c[3] or (Theme.bgB + 0.015), c and c[4] or Theme.bgA, -3)
	local ins = opts.inset
	if ins then
		bg:SetPoint("TOPLEFT", btn, "TOPLEFT", ins[1], -ins[2])
		bg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -ins[3], ins[4])
	else
		bg:SetAllPoints(btn)
	end
	d.bg = bg
	if not opts.noBorder then
		if ins then
			local host = CreateFrame("Frame", nil, btn)
			host:SetAllPoints(bg)
			host:SetFrameLevel(btn:GetFrameLevel())
			WSkin.AddBorder(host)
			d.borderHost = host
		else
			WSkin.AddBorder(btn)
		end
	end
	if opts.hover ~= false then
		local hov = SolidTex(btn, "HIGHLIGHT", 1, 1, 1, opts.hover or 0.08)
		hov:SetAllPoints(bg)
		d.hover = hov
	end
	return d
end

-- Hyperlink color codes -> the Global Options link color (|H payload untouched).
local function RecolorLinks(fs)
	local txt = fs.GetText and fs:GetText()
	if type(txt) ~= "string" or txt == "" or not txt:find("|H", 1, true) then
		return
	end
	local new, n = txt:gsub("|c%x%x%x%x%x%x%x%x|H", "|cff" .. WSkin.LinkColorHex() .. "|H")
	if n > 0 and new ~= txt then
		fs:SetText(new)
	end
end

-- Every font string under a frame -> white (links recolored). skip = set of
-- frames whose subtree keeps its colors (loot lists with quality colors).
local function WhitenTextIn(frame, depth, skip)
	depth = depth or 0
	if not frame or depth > 9 or Forbidden(frame) then
		return
	end
	if skip and skip[frame] then
		return
	end
	if frame.GetRegions then
		local regions = { frame:GetRegions() }
		for i = 1, #regions do
			local r = regions[i]
			if r and r.IsObjectType and r:IsObjectType("FontString") then
				r:SetTextColor(1, 1, 1)
				RecolorLinks(r)
			end
		end
	end
	if frame.GetChildren then
		local children = { frame:GetChildren() }
		for i = 1, #children do
			local c = children[i]
			if c and not WSkin.IsForeignFrame(c, frame) then
				if c.GetObjectType and c:GetObjectType() == "SimpleHTML" and c.SetTextColor then
					for _, el in ipairs({ "P", "H1", "H2", "H3" }) do
						pcall(c.SetTextColor, c, el, 1, 1, 1)
					end
				end
				WhitenTextIn(c, depth + 1, skip)
			end
		end
	end
end

-- Popup / secondary window on the window's style: shell + common controls.
local function PopupShell(winKey, f, opts)
	if not f or Forbidden(f) then
		return
	end
	WSkin.Shell(winKey, f, opts)
	WSkin.RemovePortrait(f)
	WSkin.CommonChrome(f)
	WSkin.ButtonsIn(f)
end

-- Clear a frame's backdrop colors (visual only).
local function ClearBackdrop(f)
	if f and f.SetBackdropColor then
		f:SetBackdropColor(0, 0, 0, 0)
		if f.SetBackdropBorderColor then
			f:SetBackdropBorderColor(0, 0, 0, 0)
		end
	end
end

-- Tab rows Blizzard re-anchors: re-chain on every SetPoint (guarded).
local function KeepTabRow(owner, tabs)
	local od = GetFFD(owner)
	WSkin.NormalizeTabRow(tabs)
	if od.tabRowHook then
		return
	end
	od.tabRowHook = true
	local guard = false
	local function ReNorm()
		if guard then
			return
		end
		guard = true
		WSkin.NormalizeTabRow(tabs)
		guard = false
	end
	for _, t in ipairs(tabs) do
		hooksecurefunc(t, "SetPoint", ReNorm)
		t:HookScript("OnShow", ReNorm)
		t:HookScript("OnHide", ReNorm)
	end
end

-- Named tabs $prefix..1..n -> skinned list.
local function TabsNamed(prefix, n, opts)
	local tabs = {}
	for i = 1, n do
		local t = _G[prefix .. i]
		if t then
			WSkin.Tab(t, opts)
			tabs[#tabs + 1] = t
		end
	end
	return tabs
end

-------------------------------------------------------------------------------
--  Adventure Guide (EncounterJournal)
-------------------------------------------------------------------------------
do
local EJ_ART_MATCH = { "journalbg", "abilitytextbg", "paperoverlay", "ui-ej-cataclysm", "ui-ej-bookpage" }
local function EJKeep(hay)
	if WSkin.TexIsIcon(hay) then return true end
	if hay:find("ui-ej-lorebg", 1, true) then return true end
	if hay:find("ui-ej-boss", 1, true) then return true end
	if hay:find("ui-ej-icons", 1, true) then return true end
	return false
end
local function FadeEJArt(frame, depth)
	depth = depth or 0
	if not frame or depth > 11 or not frame.GetRegions or Forbidden(frame) then return end
	if WSkin.IsArtExempt(frame) then return end
	if depth > 0 and WSkin.IsForeignFrame(frame) then return end
	local mybg = FFD[frame] and FFD[frame].bg
	local regions = { frame:GetRegions() }
	for i = 1, #regions do
		local r = regions[i]
		if r and r ~= mybg and r.IsObjectType and r:IsObjectType("Texture") then
			local hay = WSkin.TexHay(r)
			if hay and not EJKeep(hay) then
				for _, m in ipairs(EJ_ART_MATCH) do
					if hay:find(m, 1, true) then r:SetAlpha(0) break end
				end
			end
		end
	end
	local children = { frame:GetChildren() }
	for i = 1, #children do
		FadeEJArt(children[i], depth + 1)
	end
end

-- Breadcrumb button: art gone, white text, 1px divider, house subnav arrow.
local function SkinNavButton(btn)
	if not btn or Forbidden(btn) then return end
	local d = GetFFD(btn)
	if not d.navskin then
		d.navskin = true
		for _, g in ipairs({ "GetNormalTexture", "GetHighlightTexture", "GetPushedTexture", "GetDisabledTexture" }) do
			local t = btn[g] and btn[g](btn)
			if t and t.SetAlpha then t:SetAlpha(0) end
		end
		WSkin.FadeRegions(btn)
		local hov = SolidTex(btn, "HIGHLIGHT", 1, 1, 1, 0.1)
		hov:SetPoint("TOPLEFT", 2, -3)
		hov:SetPoint("BOTTOMRIGHT", -2, 3)
		d.hover = hov
		local div = SolidTex(btn, "OVERLAY", 1, 1, 1, 0.15)
		div:SetWidth(1)
		div:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, -5)
		div:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 5)
		d.strip = div
		WSkin.Register(btn, true)
	end
	local text = btn.text or btn.Text or (btn.GetFontString and btn:GetFontString())
	if text then WSkin.White(text) end
	local ma = btn.MenuArrowButton
	if ma then
		local md = GetFFD(ma)
		if not md.arrow then
			local arrow = ma:CreateTexture(nil, "OVERLAY")
			arrow:SetTexture(WSkin.ARROW_DOWN_TEX)
			arrow:SetSize(10, 10)
			arrow:SetPoint("CENTER")
			md.arrow = arrow
		end
		local function FadeArrowArt()
			WSkin.FadeRegions(ma, { [md.arrow] = true })
			for _, g in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
				local t = ma[g] and ma[g](ma)
				if t and t ~= md.arrow and t.SetAlpha then t:SetAlpha(0) end
			end
			if ma.Art then Fade(ma.Art) end
		end
		FadeArrowArt()
		if not md.hoverHooked then
			md.hoverHooked = true
			ma:HookScript("OnEnter", FadeArrowArt)
			ma:HookScript("OnLeave", FadeArrowArt)
		end
	end
end

local function RestyleNav(nav)
	if not nav then return end
	local nd = GetFFD(nav)
	if not nd.bg then
		local wash = SolidTex(nav, "BACKGROUND", 1, 1, 1, 0.05, -6)
		wash:SetAllPoints(nav)
		nd.bg = wash
	end
	WSkin.FadeRegions(nav, { [nd.bg] = true })
	WSkin.FadeNamed(nav, { "InsetBorderBottomLeft", "InsetBorderBottomRight", "InsetBorderBottom", "InsetBorderLeft", "InsetBorderRight" })
	WSkin.Register(nav, true)
	if nav.overlay then
		WSkin.FadeRegions(nav.overlay)
		WSkin.Register(nav.overlay, true)
	end
	if nav.home then SkinNavButton(nav.home) end
	if nav.navList then
		local n = #nav.navList
		for i = 1, n do
			local b = nav.navList[i]
			if b then
				SkinNavButton(b)
				local bd = FFD[b]
				if bd and bd.strip then bd.strip:SetShown(i < n) end
			end
		end
	end
end

-- Boss list row: creature render kept, 10% white block, white name; the
-- active boss full, the rest at half.
local function SkinBossButton(btn)
	if not btn or Forbidden(btn) then return end
	local d = GetFFD(btn)
	if not d.bossbtn then
		d.bossbtn = true
		for _, g in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
			local t = btn[g] and btn[g](btn)
			if t and t.SetAlpha then t:SetAlpha(0) end
		end
		local hl = btn.GetHighlightTexture and btn:GetHighlightTexture()
		if hl then hl:SetTexture(1, 1, 1, 0.08) end
		local fill = SolidTex(btn, "BACKGROUND", 1, 1, 1, 0.1, -2)
		fill:SetPoint("TOPLEFT", 1, -1)
		fill:SetPoint("BOTTOMRIGHT", -1, 1)
		d.bg = fill
	end
	local text = btn.text or (btn.GetFontString and btn:GetFontString())
	if text then WSkin.White(text) end
	local ej = _G.EncounterJournal
	local ejID = ej and ej.encounterID
	local active = not ejID or (btn.encounterID and btn.encounterID == ejID)
	d.bg:SetAlpha(active and 1 or 0.5)
end

local function SkinBossButtons()
	for i = 1, 30 do
		local b = _G["EncounterJournalBossButton" .. i]
		if not b then break end
		SkinBossButton(b)
	end
end

-- Instance tile: splash kept, frame art gone, 1px border + white hover.
local function SkinInstanceButton(btn)
	if not btn or Forbidden(btn) then return end
	local d = GetFFD(btn)
	if not d.instbtn then
		d.instbtn = true
		for _, g in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
			local t = btn[g] and btn[g](btn)
			if t and t ~= btn.bgImage and t.SetAlpha then t:SetAlpha(0) end
		end
		local hl = btn.GetHighlightTexture and btn:GetHighlightTexture()
		if hl and hl ~= btn.bgImage then
			hl:SetTexture(1, 1, 1, 0.1)
			if btn.bgImage then hl:SetAllPoints(btn.bgImage) end
		end
		local host = CreateFrame("Frame", nil, btn)
		if btn.bgImage then host:SetAllPoints(btn.bgImage) else host:SetAllPoints(btn) end
		host:SetFrameLevel(btn:GetFrameLevel() + 1)
		WSkin.AddBorder(host, 0, 0, 0, 1)
		d.borderHost = host
	end
	if btn.name then WSkin.White(btn.name) end
end

local function SkinInstanceButtons()
	SkinInstanceButton(_G.EncounterJournalInstanceSelectScrollFrameScrollChildInstanceButton1)
	for i = 2, 40 do
		local b = _G["EncounterJournalInstanceSelectScrollFrameinstance" .. i]
		if not b then break end
		SkinInstanceButton(b)
	end
end

-- Side tabs (boss / loot / model): dark box + black border, glyph only.
local SIDE_GLYPH = {
	EncounterJournalEncounterFrameInfoBossTab = { 0.902, 0.996, 0.269, 0.311 },
	EncounterJournalEncounterFrameInfoLootTab = { 0.632, 0.726, 0.618, 0.660 },
	EncounterJournalEncounterFrameInfoModelTab = { 0.804, 0.900, 0.662, 0.705 },
}
local EJ_TEX = "Interface\\EncounterJournal\\UI-EncounterJournalTextures"
local function SkinSideTab(tab, coords)
	if not tab or Forbidden(tab) then return end
	local d = GetFFD(tab)
	if d.sidetab then return end
	d.sidetab = true
	WSkin.FadeRegions(tab)
	local box = CreateFrame("Frame", nil, tab)
	box:SetPoint("TOPLEFT", 3, -3)
	box:SetPoint("BOTTOMRIGHT", -3, 3)
	box:SetFrameLevel(math.max(0, tab:GetFrameLevel() - 1))
	local fill = SolidTex(box, "BACKGROUND", Theme.bgR, Theme.bgG, Theme.bgB, Theme.bgA)
	fill:SetAllPoints(box)
	WSkin.AddBorder(box, 0, 0, 0, 1)
	d.box = box
	for _, g in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
		local t = tab[g] and tab[g](tab)
		if t then
			if coords then
				t:SetTexture(EJ_TEX)
				t:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
				t:ClearAllPoints()
				t:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -4)
				t:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -4, 4)
				t:SetAlpha(1)
			end
		end
	end
	local hl = tab.GetHighlightTexture and tab:GetHighlightTexture()
	if hl then
		hl:SetTexture(1, 1, 1, 0.1)
		hl:ClearAllPoints()
		hl:SetAllPoints(box)
		hl:SetAlpha(1)
	end
end

-- Loot row: art gone, flat block, squared icon with a rarity border.
local function SkinLootRow(btn)
	if not btn or Forbidden(btn) then return end
	Fade(btn.bossTexture)
	Fade(btn.bosslessTexture)
	local d = GetFFD(btn)
	if not d.lootrow then
		d.lootrow = true
		RowBlock(btn, { inset = { 0, 4, 2, 1 } })
		if btn.icon then WSkin.SquareIcon(btn.icon, btn, true) end
	end
	for _, k in ipairs({ "slot", "armorType", "boss" }) do
		local fs = btn[k]
		if fs then WSkin.White(fs, 0.82, 0.82, 0.82) end
	end
	if btn.icon and d.qBorder then
		WSkin.SetQualityColor(btn, btn.link or btn.itemID)
	end
end

local function SkinLootRows()
	local ej = _G.EncounterJournal
	local ls = ej and ej.encounter and ej.encounter.info and ej.encounter.info.lootScroll
	if not (ls and ls.buttons) then return end
	for i = 1, #ls.buttons do
		SkinLootRow(ls.buttons[i])
	end
end

-- Ability / overview headers: paper art gone, flat block, white title.
local function SkinHeaders()
	for i = 1, 60 do
		local h = _G["EncounterJournalInfoHeader" .. i]
		if not h then break end
		Fade(h.descriptionBG)
		Fade(h.descriptionBGBottom)
		if h.description then WSkin.White(h.description); RecolorLinks(h.description) end
		local b = h.button
		if b and not Forbidden(b) then
			local d = GetFFD(b)
			if not d.abilrow then
				d.abilrow = true
				local fill = SolidTex(b, "BACKGROUND", Theme.bgR + 0.02, Theme.bgG + 0.02, Theme.bgB + 0.02, Theme.bgA, -2)
				fill:SetPoint("TOPLEFT", 0, -1)
				fill:SetPoint("BOTTOMRIGHT", 0, 1)
				d.bg = fill
				WSkin.AddBorder(b)
				local hov = SolidTex(b, "HIGHLIGHT", 1, 1, 1, 0.05)
				hov:SetAllPoints(fill)
				d.hover = hov
				if b.abilityIcon then WSkin.SquareIcon(b.abilityIcon, b) end
			end
			local keep = { [d.bg] = true, [d.hover] = true }
			if b.abilityIcon then keep[b.abilityIcon] = true end
			WSkin.FadeRegions(b, keep)
			local hl = b.GetHighlightTexture and b:GetHighlightTexture()
			if hl and not keep[hl] then hl:SetAlpha(0) end
			if b.title then WSkin.White(b.title) end
			if b.expandedIcon and b.expandedIcon.SetTextColor then b.expandedIcon:SetTextColor(1, 1, 1) end
		end
	end
end

-- Search preview / result buttons: art gone, hover, squared icon, white text.
local function SkinSearchButton(btn, framed)
	if not btn or Forbidden(btn) then return end
	local d = GetFFD(btn)
	if not d.ejSearch then
		d.ejSearch = true
		local icon = btn.icon or btn.Icon
		local keep = icon and { [icon] = true } or nil
		WSkin.FadeRegions(btn, keep)
		if framed then
			local bg = SolidTex(btn, "BACKGROUND", 0.05, 0.05, 0.05, 0.95, -6)
			bg:SetAllPoints(btn)
			d.bg = bg
			WSkin.AddBorder(btn)
		end
		local hov = SolidTex(btn, "HIGHLIGHT", 1, 1, 1, 0.1)
		hov:SetAllPoints(btn)
		d.hover = hov
		if icon then WSkin.SquareIcon(icon, btn) end
	end
	for _, k in ipairs({ "name", "text", "resultType", "path" }) do
		local fs = btn[k]
		if fs and fs.SetTextColor then WSkin.White(fs) end
	end
end

local function Skin_EncounterJournal()
	local f = _G.EncounterJournal
	if not f then return end
	WSkin.Shell("adventureguide", f)
	WSkin.RemovePortrait(f)
	WSkin.CommonChrome(f, "EncounterJournal")
	for _, k in ipairs({ "inset", "Inset" }) do
		if f[k] then WSkin.Inset(f[k]) end
	end
	FadeG({ "EncounterJournalBg", "EncounterJournalInsetBg" })

	local nav = f.navBar
	local function RefreshNav() RestyleNav(nav) end
	RefreshNav()

	-- Search box + preview popout + full results window.
	local sbox = f.searchBox
	if sbox then WSkin.EditBox(sbox) end
	for i = 1, 5 do SkinSearchButton(_G["EncounterJournalSearchBoxSearchButton" .. i], true) end
	if _G.EncounterJournalSearchBoxShowALL then
		WSkin.Button(_G.EncounterJournalSearchBoxShowALL)
		WSkin.WhiteButtonLabel(_G.EncounterJournalSearchBoxShowALL)
	end
	local sr = _G.EncounterJournalSearchResults
	if sr then
		WSkin.Panel(sr)
		if _G.EncounterJournalSearchResultsCloseButton then WSkin.CloseButton(_G.EncounterJournalSearchResultsCloseButton) end
		if _G.EncounterJournalSearchResultsScrollFrame then
			WSkin.FadeRegions(_G.EncounterJournalSearchResultsScrollFrame)
		end
		WSkin.ScrollBarsIn(sr)
		for i = 1, 9 do SkinSearchButton(_G["EncounterJournalSearchResultsScrollFrameButton" .. i]) end
	end

	-- Instance select: scene dimmed (it is the content), dungeon / raid tabs, tiles.
	local isel = f.instanceSelect
	if isel then
		WSkin.ExemptArt(isel)
		local regions = { isel:GetRegions() }
		for i = 1, #regions do
			local r = regions[i]
			if r and r.IsObjectType and r:IsObjectType("Texture") and r:GetDrawLayer() == "BACKGROUND" then
				if (r:GetAlpha() or 1) > 0.5 then r:SetAlpha(0.25) end
			end
		end
		local function TabSel(t) return t.IsEnabled and not t:IsEnabled() end
		for _, k in ipairs({ "dungeonsTab", "raidsTab" }) do
			local t = isel[k]
			if t then
				if t.grayBox then WSkin.FadeRegions(t.grayBox) end
				WSkin.Tab(t, { isSelected = TabSel })
			end
		end
		if isel.scroll then WSkin.FadeRegions(isel.scroll) end
		if _G.EncounterJournalInstanceSelectScrollDownButton then
			WSkin.PageButton(_G.EncounterJournalInstanceSelectScrollDownButton, "v", 12)
		end
		SkinInstanceButtons()
	end

	-- Encounter detail.
	local e = f.encounter
	local info = e and e.info
	if info then
		WSkin.FadeRegions(info)
		WSkin.Register(info, true)
		Fade(_G.EncounterJournalEncounterFrameInfoBG)
		Fade(_G.EncounterJournalEncounterFrameInfoModelFrameShadow)
		if info.model then Fade(info.model.dungeonBG) end
		for name, coords in pairs(SIDE_GLYPH) do
			SkinSideTab(_G[name], coords)
		end
		if info.difficulty then
			WSkin.Button(info.difficulty)
			WSkin.WhiteButtonLabel(info.difficulty)
		end
		if info.reset then
			WSkin.Button(info.reset)
			local rt = _G.EncounterJournalEncounterFrameInfoResetButtonTexture
			if rt then rt:SetAlpha(1) end
		end
		local ls = info.lootScroll
		if ls then
			if ls.filter then
				WSkin.Button(ls.filter)
				WSkin.WhiteButtonLabel(ls.filter)
			end
			local cf = ls.classClearFilter
			if cf then
				local cd = GetFFD(cf)
				if not cd.bg then
					WSkin.FadeRegions(cf)
					cd.bg = SolidTex(cf, "BACKGROUND", 1, 1, 1, 0.05)
					cd.bg:SetAllPoints(cf)
				end
				if cf.text then WSkin.White(cf.text) end
			end
			if _G.EncounterJournalEncounterFrameInfoLootScrollFrameClassFilterClearFrameExitButton then
				WSkin.CloseButton(_G.EncounterJournalEncounterFrameInfoLootScrollFrameClassFilterClearFrameExitButton)
			end
			SkinLootRows()
			HookM(ls, "update", SkinLootRows)
		end
		-- Vertical divider down the center of the detail view.
		local ed = GetFFD(info)
		if info.bossesScroll and not ed.strip then
			local div = SolidTex(info, "ARTWORK", 1, 1, 1, 0.15)
			div:SetWidth(1)
			div:SetPoint("TOPLEFT", info.bossesScroll, "TOPRIGHT", 22, 0)
			div:SetPoint("BOTTOMLEFT", info.bossesScroll, "BOTTOMRIGHT", 22, 0)
			ed.strip = div
		end
		if info.bossesScroll and info.bossesScroll.child and info.bossesScroll.child.description then
			WSkin.White(info.bossesScroll.child.description)
		end
	end
	local inst = e and e.instance
	if inst then
		Fade(inst.titleBG)
		-- Show Map: keep Blizzard's map icon (a block over the 48x32 icon hid
		-- it), drop only the dark shadow plate behind it.
		local mb = _G.EncounterJournalEncounterFrameInstanceFrameMapButton
		if mb then
			Fade(_G.EncounterJournalEncounterFrameInstanceFrameMapButtonShadow)
			local t = _G.EncounterJournalEncounterFrameInstanceFrameMapButtonText
			if t then
				if (t:GetText() or "") == "" and _G.SHOW_MAP then t:SetText(_G.SHOW_MAP) end
				WSkin.White(t)
			end
		end
	end

	local skip = {}
	if info and info.lootScroll then skip[info.lootScroll] = true end
	local function RefreshDetail()
		if not e then return end
		Fade(_G.EncounterJournalEncounterFrameInfoBG)
		if inst then Fade(inst.titleBG) end
		SkinHeaders()
		SkinBossButtons()
		SkinLootRows()
		FadeEJArt(e)
		WhitenTextIn(e, 0, skip)
		-- The dungeon lore picture is content: FadeKeyedArt matches its
		-- global name (InstanceFrame + "BG"), so bring it back.
		if inst and inst.loreBG then inst.loreBG:SetAlpha(1) end
	end
	RefreshDetail()

	FadeEJArt(f)
	WSkin.ButtonsIn(f)
	WSkin.ScrollBarsIn(f)
	WSkin.FadeKeyedArt(f)
	if inst and inst.loreBG then inst.loreBG:SetAlpha(1) end

	local fd = GetFFD(f)
	if not fd.ejHooked then
		fd.ejHooked = true
		local refresh = WSkin.Debounce(function()
			if not f:IsVisible() then return end
			RefreshDetail()
			RefreshNav()
			SkinInstanceButtons()
			WSkin.Restrip("adventureguide")
			WSkin.UpdateAllTabs()
		end)
		for _, fn in ipairs({ "EncounterJournal_DisplayInstance", "EncounterJournal_DisplayEncounter",
			"EncounterJournal_ToggleHeaders", "EncounterJournal_SetTab", "EncounterJournal_ListInstances",
			"EncounterJournal_LootUpdate", "EncounterJournal_SearchUpdate", "EncounterJournal_TierDropDown_Select" }) do
			HookFn(fn, refresh)
		end
		HookFn("NavBar_AddButton", function(bar)
			if bar == nav then RefreshNav() end
		end)
		WSkin.OnLooksChanged(function()
			if f:IsVisible() then refresh() end
		end)
		WSkin.HookShow(f, refresh)
	end
end

WSkin.RegisterWindow({
	key = "adventureguide",
	label = "Adventure Guide",
	description = "Encounter Journal: instance select, boss details, loot lists, and the bottom nav tabs.",
	order = 50,
	addons = { Blizzard_EncounterJournal = true },
	elvui = "encounterjournal",
	apply = Skin_EncounterJournal,
})
end

-------------------------------------------------------------------------------
--  Collections (PetJournalParent: Mount Journal + Pet Journal)
-------------------------------------------------------------------------------
do
-- List row (mount / pet): background art gone, flat block, squared icon.
-- Pets keep their quality: the square edge reads Blizzard's ring color.
local function SkinListRow(btn, isPet)
	if not btn or Forbidden(btn) then return end
	local d = GetFFD(btn)
	if not d.listrow then
		d.listrow = true
		Fade(btn.background)
		local hl = btn.GetHighlightTexture and btn:GetHighlightTexture()
		if hl then hl:SetTexture(1, 1, 1, 0.08) end
		RowBlock(btn, { inset = { 1, 1, 1, 1 }, hover = false })
		if btn.icon then
			btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			WSkin.QualityBorder(btn, btn.icon, 0, 0, 0)
		end
	end
	Fade(btn.background)
	if btn.iconBorder then btn.iconBorder:SetAlpha(0) end
	if btn.selectedTexture then
		local r, g, b = WSkin.AccentBarColor()
		btn.selectedTexture:SetTexture(r, g, b, 0.15)
	end
	if isPet then
		local r, g, b = WSkin.RingQuality(btn.iconBorder)
		WSkin.QualityBorder(btn, btn.icon, r or 0, g or 0, b or 0)
		if btn.dragButton and btn.dragButton.levelBG then btn.dragButton.levelBG:SetAlpha(0.6) end
	elseif btn.name then
		WSkin.White(btn.name)
	end
end

local function SkinMountRows()
	local mj = _G.MountJournal
	local sf = mj and mj.ListScrollFrame
	if not (sf and sf.buttons) then return end
	for i = 1, #sf.buttons do SkinListRow(sf.buttons[i], false) end
end

local function SkinPetRows()
	local pj = _G.PetJournal
	local sf = pj and pj.listScroll
	if not (sf and sf.buttons) then return end
	for i = 1, #sf.buttons do SkinListRow(sf.buttons[i], true) end
end

local function SkinLoadout()
	for i = 1, 3 do
		local bg = _G["PetJournalLoadoutPet" .. i .. "BG"]
		if bg and bg.SetAlpha then bg:SetAlpha(0.25) end
		local fr = _G["PetJournalLoadoutPet" .. i]
		if fr then
			if fr.healthFrame and fr.healthFrame.healthBar then FlatBar(fr.healthFrame.healthBar, true) end
			if fr.xpBar then FlatBar(fr.xpBar) end
			if fr.icon then WSkin.SquareIcon(fr.icon, fr) end
			for j = 1, 3 do
				local sp = fr["spell" .. j]
				if sp then WSkin.ItemButton(sp) end
			end
		end
	end
	local border = _G.PetJournalLoadoutBorder
	if border and border.GetRegions then
		local regions = { border:GetRegions() }
		for i = 1, #regions do
			local r = regions[i]
			if r and r.IsObjectType and r:IsObjectType("Texture") then r:SetAlpha(0.25) end
		end
	end
end

local function Skin_Collections()
	local f = _G.PetJournalParent
	if not f then return end
	WSkin.Shell("collections", f)
	WSkin.RemovePortrait(f)
	WSkin.CommonChrome(f, "PetJournalParent")
	FadeG({ "PetJournalParentPortrait", "PetJournalParentBg" })
	local tabs = TabsNamed("PetJournalParentTab", 4)
	KeepTabRow(f, tabs)

	local mj = _G.MountJournal
	if mj then
		WSkin.FadeRegions(mj)
		WSkin.Register(mj, true)
		for _, k in ipairs({ "LeftInset", "RightInset", "Inset" }) do
			if mj[k] then WSkin.Inset(mj[k]) end
		end
		if mj.MountCount then WSkin.Panel(mj.MountCount, { shade = true }) end
		local md = mj.MountDisplay
		if md then
			Fade(md.ShadowOverlay)
			Fade(md.YesMountsTex)
			Fade(md.NoMountsTex)
			local mdd = GetFFD(md)
			if not mdd.bg then
				local fill = SolidTex(md, "BACKGROUND", 1, 1, 1, 0.03)
				fill:SetAllPoints(md.ModelFrame or md)
				mdd.bg = fill
			end
			if md.Name then WSkin.White(md.Name) end
		end
		if _G.MountJournalListScrollFrame then WSkin.FadeRegions(_G.MountJournalListScrollFrame) end
		SkinMountRows()
		WSkin.FadeKeyedArt(mj)
	end

	local pj = _G.PetJournal
	if pj then
		WSkin.FadeRegions(pj)
		WSkin.Register(pj, true)
		for _, n in ipairs({ "PetJournalLeftInset", "PetJournalRightInset", "PetJournalPetCardInset" }) do
			if _G[n] then WSkin.Inset(_G[n]) end
		end
		if pj.PetCount then WSkin.Panel(pj.PetCount, { shade = true }) end
		if _G.PetJournalListScrollFrame then WSkin.FadeRegions(_G.PetJournalListScrollFrame) end
		if _G.PetJournalAchievementStatus then WSkin.FadeRegions(_G.PetJournalAchievementStatus) end
		if _G.PetJournalFilterButton then
			WSkin.Button(_G.PetJournalFilterButton)
			WSkin.WhiteButtonLabel(_G.PetJournalFilterButton)
		end
		if _G.PetJournalHealPetButton then WSkin.ItemButton(_G.PetJournalHealPetButton) end
		local card = _G.PetJournalPetCard
		if card then
			WSkin.Panel(card, { shade = true })
			local pi = _G.PetJournalPetCardPetInfo
			if pi then
				Fade(pi.levelBG)
				if pi.icon then WSkin.SquareIcon(pi.icon, pi) end
			end
			if _G.PetJournalPetCardHealthFrame and _G.PetJournalPetCardHealthFrame.healthBar then
				FlatBar(_G.PetJournalPetCardHealthFrame.healthBar, true)
			end
			FlatBar(_G.PetJournalPetCardXPBar)
			for i = 1, 6 do
				local sp = _G["PetJournalPetCardSpell" .. i]
				if sp then WSkin.ItemButton(sp) end
			end
		end
		if _G.PetJournalSpellSelect then WSkin.FadeRegions(_G.PetJournalSpellSelect) end
		for i = 1, 2 do
			local sp = _G["PetJournalSpellSelectSpell" .. i]
			if sp then WSkin.ItemButton(sp) end
		end
		SkinPetRows()
		WSkin.FadeKeyedArt(pj)
	end

	WSkin.ButtonsIn(f)
	WSkin.FadeArtIn(f)
	SkinLoadout()
	-- Bottom action buttons: white labels (re-enabling resets the gold font).
	for _, bn in ipairs({ "MountJournalMountButton", "PetJournalSummonButton", "PetJournalFindBattle" }) do
		if _G[bn] then WSkin.WhiteButtonLabel(_G[bn]) end
	end

	local fd = GetFFD(f)
	if not fd.colHooked then
		fd.colHooked = true
		HookFn("MountJournal_UpdateMountList", SkinMountRows)
		HookFn("PetJournal_UpdatePetList", SkinPetRows)
		if mj then HookM(mj.ListScrollFrame, "update", SkinMountRows) end
		if pj then HookM(pj.listScroll, "update", SkinPetRows) end
		HookFn("PetJournal_UpdatePetLoadOut", WSkin.Debounce(SkinLoadout))
		WSkin.HookShow(f, WSkin.Debounce(function()
			if f:IsVisible() then
				SkinMountRows()
				SkinPetRows()
				SkinLoadout()
				WSkin.Restrip("collections")
				WSkin.UpdateAllTabs()
			end
		end))
	end
end

WSkin.RegisterWindow({
	key = "collections",
	label = "Collections",
	description = "Mounts, pets, toys, heirlooms, appearances, and campsites.",
	order = 60,
	addons = { Blizzard_PetJournal = true },
	elvui = "mounts",
	apply = Skin_Collections,
})
end

-------------------------------------------------------------------------------
--  Talents & Spellbook: SpellBookFrame (base UI), PlayerTalentFrame
--  (Blizzard_TalentUI) and its Glyphs tab (Blizzard_GlyphUI).
-------------------------------------------------------------------------------
do
local SPELL_KEEP = { IconTexture = true, AutoCastable = true, Highlight = true, FlyoutArrow = true, GlyphIcon = true,
	SpellHighlightTexture = true }

-- Spell slot: parchment slot / text plates gone, squared icon, light text.
local function SkinSpellButton(btn)
	if not btn or Forbidden(btn) then return end
	local d = GetFFD(btn)
	local name = btn:GetName()
	local icon = name and _G[name .. "IconTexture"]
	local keep = {}
	if btn.highlightTexture then keep[btn.highlightTexture] = true end
	for k in pairs(SPELL_KEEP) do
		local t = btn[k] or (name and _G[name .. k])
		if t then keep[t] = true end
	end
	local regions = { btn:GetRegions() }
	for i = 1, #regions do
		local r = regions[i]
		if r and not keep[r] and r.IsObjectType and r:IsObjectType("Texture") then
			local hay = WSkin.TexHay(r)
			if not (hay and (hay:find("flyout", 1, true) or hay:find("autocast", 1, true) or hay:find("glyph", 1, true))) then
				r:SetAlpha(0)
			end
		end
	end
	if not d.spellSkinned then
		d.spellSkinned = true
		if icon then WSkin.SquareIcon(icon, btn) end
		local hl = btn.highlightTexture or (name and _G[name .. "Highlight"])
		if hl and hl.SetTexture then
			hl:SetTexture(1, 1, 1, 0.15)
			if icon then hl:SetAllPoints(icon) end
			hooksecurefunc(hl, "SetTexture", function(self, tex)
				if type(tex) == "string" and not GetFFD(self).inTex then
					GetFFD(self).inTex = true
					self:SetTexture(1, 1, 1, 0.15)
					GetFFD(self).inTex = false
				end
			end)
		end
	end
	GoldToWhite(btn.SpellName)
	LightenDark(btn.SpellName, 0.6, 0.6, 0.6)
	LightenDark(btn.SpellSubName)
	LightenDark(btn.RequiredLevelString)
	LightenDark(btn.SeeTrainerString)
end

local function SkinSpellButtons()
	for i = 1, (_G.SPELLS_PER_PAGE or 12) do
		SkinSpellButton(_G["SpellButton" .. i])
	end
end

local function SpellTabSelected(t)
	local sb = _G.SpellBookFrame
	if t.bookType and sb and sb.bookType then
		return t.bookType == sb.bookType
	end
	return t.IsEnabled and not t:IsEnabled()
end

local function SkinCoreAbilities()
	local ca = _G.SpellBookCoreAbilitiesFrame
	if not ca then return end
	if ca.SpecName then WSkin.White(ca.SpecName) end
	local buttons = ca.Abilities
	if buttons then
		for i = 1, #buttons do
			local b = buttons[i]
			if b then
				Fade(b.EmptySlot)
				Fade(b.ActiveTexture)
				Fade(b.FutureTexture)
				if b.iconTexture then WSkin.SquareIcon(b.iconTexture, b) end
				local future = b.FutureTexture and b.FutureTexture.IsShown and b.FutureTexture:IsShown()
				if b.Name then
					if future then b.Name:SetTextColor(0.6, 0.6, 0.6) else b.Name:SetTextColor(1, 1, 1) end
				end
				if b.InfoText then
					if future then b.InfoText:SetTextColor(0.6, 0.6, 0.6) else b.InfoText:SetTextColor(0.82, 0.82, 0.82) end
				end
				LightenDark(b.RequiredLevel)
			end
		end
	end
	local tabs = ca.SpecTabs
	if tabs then
		for i = 1, #tabs do
			if tabs[i] then WSkin.SideTab(tabs[i]) end
		end
	end
end

local function SkinWhatChanged()
	local wc = _G.SpellBookWhatHasChanged
	if not wc then return end
	if wc.ClassName then WSkin.White(wc.ClassName) end
	if type(_G.SpellBook_GetWhatChangedItem) ~= "function" then return end
	for i = 1, 20 do
		local ok, item = pcall(_G.SpellBook_GetWhatChangedItem, i)
		if not ok or not item then break end
		if not GetFFD(item).wc then
			GetFFD(item).wc = true
			WSkin.FadeRegions(item)
		end
		if item.SetTextColor then item:SetTextColor(1, 1, 1) end
		if item.Title then WSkin.White(item.Title) end
	end
end

local function Skin_SpellBook()
	local f = _G.SpellBookFrame
	if not f then return end
	WSkin.Shell("playerspells", f)
	WSkin.RemovePortrait(f)
	WSkin.CommonChrome(f, "SpellBookFrame")
	if _G.SpellBookFrameInset then WSkin.Inset(_G.SpellBookFrameInset) end
	-- Book page art returns faint (it is the spellbook's page).
	for _, n in ipairs({ "SpellBookPage1", "SpellBookPage2" }) do
		local p = _G[n]
		if p and p.SetAlpha then p:SetAlpha(0.1) end
	end
	if _G.SpellBookPageText then WSkin.White(_G.SpellBookPageText) end
	if _G.SpellBookPrevPageButton then WSkin.PageButton(_G.SpellBookPrevPageButton, "<") end
	if _G.SpellBookNextPageButton then WSkin.PageButton(_G.SpellBookNextPageButton, ">") end

	local tabs = TabsNamed("SpellBookFrameTabButton", 5, { isSelected = SpellTabSelected })
	KeepTabRow(f, tabs)

	for i = 1, (_G.MAX_SKILLLINE_TABS or 8) do
		local t = _G["SpellBookSkillLineTab" .. i]
		if t then
			WSkin.SideTab(t)
			Fade(_G["SpellBookSkillLineTab" .. i .. "Flash"])
		end
	end
	SkinSpellButtons()
	SkinCoreAbilities()
	SkinWhatChanged()
	WSkin.ButtonsIn(f)

	local fd = GetFFD(f)
	if not fd.sbHooked then
		fd.sbHooked = true
		HookFn("SpellButton_UpdateButton", function(btn) SkinSpellButton(btn) end)
		HookFn("SpellBook_UpdateCoreAbilitiesTab", SkinCoreAbilities)
		HookFn("SpellBook_UpdateWhatHasChangedTab", SkinWhatChanged)
		HookFn("SpellBookFrame_Update", function()
			WSkin.UpdateAllTabs()
			WSkin.NormalizeTabRow(tabs)
		end)
		WSkin.HookShow(f, WSkin.Debounce(function()
			if f:IsVisible() then
				SkinSpellButtons()
				for i = 1, (_G.MAX_SKILLLINE_TABS or 8) do
					local t = _G["SpellBookSkillLineTab" .. i]
					local td = t and FFD[t]
					if td and td.reflect then td.reflect() end
				end
				WSkin.UpdateAllTabs()
			end
		end))
	end
end

WSkin.RegisterWindow({
	key = "playerspells",
	label = "Talents & Spellbook",
	description = "The Player Spells window: talents, spec selection, and the spellbook.",
	order = 70,
	elvui = "spellbook",
	apply = Skin_SpellBook,
})

-- Spec button: art gone, flat block, squared spec icon, accent edge when selected.
local function SkinSpecButton(b)
	if not b or Forbidden(b) then return end
	local d = GetFFD(b)
	if not d.spec then
		d.spec = true
		for _, k in ipairs({ "bg", "learnedTex", "selectedTex", "ring" }) do Fade(b[k]) end
		local n = b:GetName()
		if n then Fade(_G[n .. "Glow"]) end
		RowBlock(b, { hover = 0.06 })
		if b.specIcon then WSkin.SquareIcon(b.specIcon, b) end
		if b.roleName then b.roleName:SetTextColor(0.75, 0.75, 0.75) end
	end
	if b.specName then WSkin.White(b.specName) end
	local r, g, bl = 0.2, 0.2, 0.2
	if b.selected then r, g, bl = WSkin.AccentBarColor() end
	BS.PP.SetBorderColor(b, r, g, bl, 1)
end

local function SkinSpecFrame(sf)
	if not sf then return end
	local d = GetFFD(sf)
	if not d.specFrame then
		d.specFrame = true
		-- Unnamed decoration children (corner art) first, before our own frames exist.
		local children = { sf:GetChildren() }
		for i = 1, #children do
			local c = children[i]
			if c and not c:GetName() and not WSkin.IsForeignFrame(c, sf) then
				WSkin.FadeRegions(c)
			end
		end
		WSkin.FadeRegions(sf)
		WSkin.Register(sf, true)
		WSkin.ExemptArt(sf)
	end
	for i = 1, 4 do
		SkinSpecButton(sf["specButton" .. i])
	end
	local child = sf.spellsScroll and sf.spellsScroll.child
	if child then
		local keep = {}
		for _, k in ipairs({ "specIcon", "roleIcon", "Seperator", "gradient" }) do
			if child[k] then keep[child[k]] = true end
		end
		WSkin.FadeRegions(child, keep)
		Fade(child.ring)
		if child.Seperator then child.Seperator:SetTexture(1, 1, 1, 0.2) end
		if child.specIcon then WSkin.SquareIcon(child.specIcon, child) end
		for _, k in ipairs({ "specName", "description", "roleName" }) do
			if child[k] then WSkin.White(child[k]) end
		end
		for i = 1, 12 do
			local ab = child["abilityButton" .. i]
			if not ab then break end
			Fade(ab.ring)
			if ab.icon then WSkin.SquareIcon(ab.icon, ab) end
			if ab.name then WSkin.White(ab.name) end
			if ab.subText then ab.subText:SetTextColor(0.82, 0.82, 0.82) end
		end
	end
end

local function SkinTalentRows()
	for i = 1, (_G.MAX_NUM_TALENT_TIERS or 6) do
		local row = _G["PlayerTalentFrameTalentsTalentRow" .. i]
		if row then
			local rd = GetFFD(row)
			if not rd.trow then
				rd.trow = true
				Fade(_G["PlayerTalentFrameTalentsTalentRow" .. i .. "Bg"])
				WSkin.FadeRegions(row, { [row.TopLine or false] = true, [row.BottomLine or false] = true })
				if row.TopLine then row.TopLine:SetTexture(1, 1, 1, 0.1) end
				if row.BottomLine then row.BottomLine:SetTexture(1, 1, 1, 0.1) end
			end
			local level = _G["PlayerTalentFrameTalentsTalentRow" .. i .. "Level"]
			if level then WSkin.White(level) end
			for j = 1, (_G.NUM_TALENT_COLUMNS or 3) do
				local b = _G["PlayerTalentFrameTalentsTalentRow" .. i .. "Talent" .. j]
				if b and not Forbidden(b) then
					local d = GetFFD(b)
					if not d.talent then
						d.talent = true
						local keep = {}
						for _, k in ipairs({ "icon", "knownSelection", "learnSelection", "Cover" }) do
							if b[k] then keep[b[k]] = true end
						end
						WSkin.FadeRegions(b, keep)
						RowBlock(b, { inset = { 14, 1, 9, 1 }, hover = 0.06 })
						if b.icon then WSkin.SquareIcon(b.icon, b) end
						local ar, ag, ab = WSkin.AccentBarColor()
						if b.knownSelection then
							b.knownSelection:SetTexture(ar, ag, ab, 0.2)
							b.knownSelection:SetAllPoints(d.bg)
						end
						if b.learnSelection then
							b.learnSelection:SetTexture(1, 1, 1, 0.15)
							b.learnSelection:SetAllPoints(d.bg)
						end
						local hl = b.GetHighlightTexture and b:GetHighlightTexture()
						if hl then hl:SetAlpha(0) end
					end
					if b.name then WSkin.White(b.name) end
				end
			end
		end
	end
end

local function Skin_Talents()
	local f = _G.PlayerTalentFrame
	if not f then return end
	WSkin.Shell("playerspells", f)
	WSkin.RemovePortrait(f)
	WSkin.CommonChrome(f, "PlayerTalentFrame")
	if _G.PlayerTalentFrameInset then WSkin.Inset(_G.PlayerTalentFrameInset) end
	if _G.PlayerTalentFrameTalents then
		WSkin.FadeRegions(_G.PlayerTalentFrameTalents)
		WSkin.Register(_G.PlayerTalentFrameTalents, true)
	end
	local tabs = TabsNamed("PlayerTalentFrameTab", 4)
	KeepTabRow(f, tabs)
	for i = 1, 2 do
		local t = _G["PlayerSpecTab" .. i]
		if t then
			Fade(_G["PlayerSpecTab" .. i .. "Background"])
			WSkin.SideTab(t)
		end
	end
	SkinSpecFrame(_G.PlayerTalentFrameSpecialization)
	SkinSpecFrame(_G.PlayerTalentFramePetSpecialization)
	SkinTalentRows()
	local ci = _G.PlayerTalentFrameTalentsClearInfoFrame
	if ci and ci.icon then WSkin.SquareIcon(ci.icon, ci) end
	WSkin.ButtonsIn(f)
	for _, n in ipairs({ "PlayerTalentFrameActivateButton", "PlayerTalentFrameSpecializationLearnButton",
		"PlayerTalentFrameTalentsLearnButton", "PlayerTalentFramePetSpecializationLearnButton" }) do
		local b = _G[n]
		if b then
			WSkin.Button(b)
			WSkin.StateButtonLabel(b)
		end
	end

	local fd = GetFFD(f)
	if not fd.talHooked then
		fd.talHooked = true
		HookFn("PlayerTalentFrame_UpdateTabs", function()
			WSkin.NormalizeTabRow(tabs)
			WSkin.UpdateAllTabs()
		end)
		HookFn("PlayerTalentFrame_UpdateSpecFrame", function(self)
			if self then SkinSpecFrame(self) end
		end)
		HookFn("TalentFrame_Update", SkinTalentRows)
		HookFn("PlayerTalentFrame_UpdateSpecs", function()
			for i = 1, 2 do
				local td = _G["PlayerSpecTab" .. i] and FFD[_G["PlayerSpecTab" .. i]]
				if td and td.reflect then td.reflect() end
			end
		end)
		WSkin.HookShow(f, WSkin.Debounce(function()
			if f:IsVisible() then
				WSkin.Restrip("playerspells")
				WSkin.UpdateAllTabs()
			end
		end))
	end
end

WSkin.RegisterWindow({
	key = "playerspells",
	addons = { Blizzard_TalentUI = true },
	elvui = "talent",
	apply = Skin_Talents,
})

-- Glyphs tab: glyph art dimmed (content), flat list rows, search + filter.
local function SkinGlyphRows()
	for i = 1, 12 do
		local b = _G["GlyphFrameScrollFrameButton" .. i]
		if not b then break end
		local d = GetFFD(b)
		if not d.glyphRow then
			d.glyphRow = true
			local keep = {}
			for _, k in ipairs({ "icon", "selectedTex" }) do
				if b[k] then keep[b[k]] = true end
			end
			WSkin.FadeRegions(b, keep)
			RowBlock(b, { inset = { 0, 1, 2, 1 } })
			if b.icon then WSkin.SquareIcon(b.icon, b) end
			local hl = b.GetHighlightTexture and b:GetHighlightTexture()
			if hl then hl:SetAlpha(0) end
		end
		if b.selectedTex then
			local r, g, bl = WSkin.AccentBarColor()
			b.selectedTex:SetTexture(r, g, bl, 0.2)
			if d.bg then b.selectedTex:SetAllPoints(d.bg) end
		end
		if b.name then GoldToWhite(b.name) end
	end
	for i = 1, 2 do
		local h = _G["GlyphFrameHeader" .. i]
		if h then
			local hd = GetFFD(h)
			if not hd.bg then
				WSkin.FadeRegions(h)
				hd.bg = SolidTex(h, "BACKGROUND", 1, 1, 1, 0.05)
				hd.bg:SetAllPoints(h)
				hd.hover = SolidTex(h, "HIGHLIGHT", 1, 1, 1, 0.05)
				hd.hover:SetAllPoints(h)
			end
			local n = h:GetName()
			local fs = (n and _G[n .. "Name"]) or h.name or (h.GetFontString and h:GetFontString())
			if fs then WSkin.White(fs) end
		end
	end
end

local function Skin_Glyphs()
	local g = _G.GlyphFrame
	if not g then return end
	local keep = {}
	if g.background then keep[g.background] = true end
	if g.specIcon then keep[g.specIcon] = true end
	WSkin.FadeRegions(g, keep)
	if g.background then g.background:SetAlpha(0.5) end
	if g.specIcon then WSkin.SquareIcon(g.specIcon, g) end
	if g.sideInset then WSkin.Inset(g.sideInset) end
	if _G.GlyphFrameSearchBox then WSkin.EditBox(_G.GlyphFrameSearchBox) end
	if _G.GlyphFrameFilterDropDown then WSkin.Dropdown(_G.GlyphFrameFilterDropDown) end
	if _G.GlyphFrameScrollFrame then WSkin.FadeRegions(_G.GlyphFrameScrollFrame) end
	if _G.GlyphFrameScrollFrameScrollChild then WSkin.FadeRegions(_G.GlyphFrameScrollFrameScrollChild) end
	WSkin.ScrollBarsIn(g)
	if g.clearInfo and g.clearInfo.icon then WSkin.SquareIcon(g.clearInfo.icon, g.clearInfo) end
	if g.levelOverlayText1 then WSkin.White(g.levelOverlayText1) end
	if g.levelOverlayText2 then WSkin.White(g.levelOverlayText2) end
	SkinGlyphRows()
	local gd = GetFFD(g)
	if not gd.glyphHooked then
		gd.glyphHooked = true
		HookFn("GlyphFrame_UpdateGlyphList", SkinGlyphRows)
		HookFn("GlyphFrame_Update", function()
			if g.levelOverlayText1 then WSkin.White(g.levelOverlayText1) end
			if g.levelOverlayText2 then WSkin.White(g.levelOverlayText2) end
		end)
		HookM(_G.GlyphFrameScrollFrame, "update", SkinGlyphRows)
	end
end

WSkin.RegisterWindow({
	key = "playerspells",
	addons = { Blizzard_GlyphUI = true },
	elvui = "talent",
	apply = Skin_Glyphs,
})
end

-------------------------------------------------------------------------------
--  Professions: the spellbook Professions tab + ArchaeologyFrame.
-------------------------------------------------------------------------------
do
local PROF_FRAMES = { "PrimaryProfession1", "PrimaryProfession2",
	"SecondaryProfession1", "SecondaryProfession2", "SecondaryProfession3", "SecondaryProfession4" }

local function SkinProfSpellButton(b)
	if not b or Forbidden(b) then return end
	local bn = b:GetName()
	if bn then Fade(_G[bn .. "NameFrame"]) end
	for _, k in ipairs({ "Border", "FlyoutBorder", "FlyoutBorderShadow", "Background", "Flash" }) do Fade(b[k]) end
	local nt = b.GetNormalTexture and b:GetNormalTexture()
	if nt then nt:SetAlpha(0) end
	local icon = b.iconTexture or b.IconTexture or (bn and _G[bn .. "IconTexture"])
	if icon then WSkin.SquareIcon(icon, b) end
	local d = GetFFD(b)
	if b.highlightTexture and not d.hlHook then
		d.hlHook = true
		b.highlightTexture:SetTexture(1, 1, 1, 0.15)
		hooksecurefunc(b.highlightTexture, "SetTexture", function(self, tex)
			if type(tex) == "string" and not d.inTex then
				d.inTex = true
				self:SetTexture(1, 1, 1, 0.15)
				d.inTex = false
			end
		end)
	end
	if b.spellString then WSkin.White(b.spellString) end
	if b.subSpellString then WSkin.White(b.subSpellString, 0.8, 0.8, 0.8) end
end

local function SkinProfessions()
	for _, n in ipairs(PROF_FRAMES) do
		local fr = _G[n]
		if fr and not Forbidden(fr) then
			local d = GetFFD(fr)
			if not d.prof then
				d.prof = true
				local keep = {}
				if fr.icon then keep[fr.icon] = true end
				WSkin.FadeRegions(fr, keep)
				Fade(_G[n .. "IconBorder"])
				-- Tile backdrop, padded past the frame.
				local bg = SolidTex(fr, "BACKGROUND", 0, 0, 0, 0.3, -6)
				bg:SetPoint("TOPLEFT", fr, "TOPLEFT", -4, 4)
				bg:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", 4, -4)
				d.bg = bg
				local host = CreateFrame("Frame", nil, fr)
				host:SetAllPoints(bg)
				host:SetFrameLevel(fr:GetFrameLevel())
				WSkin.AddBorder(host)
				d.borderHost = host
				if fr.icon then WSkin.SquareIcon(fr.icon, fr) end
				if fr.statusBar then
					FlatBar(fr.statusBar)
					Fade(fr.statusBar.capRight)
				end
			end
			for _, k in ipairs({ "professionName", "missingHeader", "rank", "missingText" }) do
				if fr[k] then WSkin.White(fr[k]) end
			end
			SkinProfSpellButton(fr.button1)
			SkinProfSpellButton(fr.button2)
		end
	end
end

local function Skin_ProfessionsBook()
	SkinProfessions()
	-- Icons already painted as round portraits: square them now (same order as GetProfessions).
	if type(_G.GetProfessions) == "function" and type(_G.GetProfessionInfo) == "function" then
		local p1, p2, p3, p4, p5, p6 = _G.GetProfessions()
		local idx = { p1, p2, p3, p4, p5, p6 }
		for i, n in ipairs(PROF_FRAMES) do
			local fr = _G[n]
			local index = idx[i]
			if fr and fr.icon and index then
				local _, tex = _G.GetProfessionInfo(index)
				if tex then
					fr.icon:SetTexture(tex)
					fr.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
				end
			end
		end
	end
	local pf = _G.SpellBookProfessionFrame
	if pf and not GetFFD(pf).profHooked then
		GetFFD(pf).profHooked = true
		-- Blizzard paints the icon as a round portrait: square texture instead.
		HookFn("FormatProfession", function(frame, index)
			if frame and frame.icon and index and FFD[frame] and type(_G.GetProfessionInfo) == "function" then
				local _, tex = _G.GetProfessionInfo(index)
				if tex then
					frame.icon:SetTexture(tex)
					frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
				end
			end
		end)
		HookFn("FormatProfession", WSkin.Debounce(SkinProfessions))
		HookFn("SpellBook_UpdateProfTab", WSkin.Debounce(SkinProfessions))
		HookFn("UpdateProfessionButton", function(btn)
			if btn and FFD[btn] then
				if btn.spellString then WSkin.White(btn.spellString) end
				if btn.subSpellString then WSkin.White(btn.subSpellString, 0.8, 0.8, 0.8) end
			end
		end)
		pf:HookScript("OnShow", WSkin.Debounce(SkinProfessions))
	end
end

WSkin.RegisterWindow({
	key = "professionsbook",
	label = "Professions",
	description = "The professions overview book with squared icons and flat progress bars.",
	order = 80,
	elvui = "spellbook",
	apply = Skin_ProfessionsBook,
})

-- Archaeology (opened from the professions book: same style key).
local function Skin_Archaeology()
	local f = _G.ArchaeologyFrame
	if not f then return end
	WSkin.Shell("professionsbook", f)
	WSkin.RemovePortrait(f)
	WSkin.CommonChrome(f, "ArchaeologyFrame")
	if _G.ArchaeologyFrameInset then WSkin.Inset(_G.ArchaeologyFrameInset) end
	FadeG({ "ArchaeologyFrameBg", "ArchaeologyFrameBgLeft", "ArchaeologyFrameBgRight" })
	-- Page parchments; the race / artifact pictures and the dig art stay.
	local keepPage = {}
	for _, n in ipairs({ "ArchaeologyFrameArtifactPageIcon", "ArchaeologyFrameArtifactPageRaceBG",
		"ArchaeologyFrameArtifactPageArtifactBG", "ArchaeologyFrameHelpPageDigTex" }) do
		if _G[n] then keepPage[_G[n]] = true end
	end
	for _, n in ipairs({ "ArchaeologyFrameSummaryPage", "ArchaeologyFrameCompletedPage",
		"ArchaeologyFrameArtifactPage", "ArchaeologyFrameHelpPage" }) do
		local pg = _G[n]
		if pg then
			WSkin.FadeRegions(pg, keepPage)
			WSkin.Register(pg, keepPage)
		end
	end
	if f.ArtifactPage and f.ArtifactPage.glow then Fade(f.ArtifactPage.glow) end
	Fade(_G.ArchaeologyFrameArtifactPageHistoryTitle)
	WSkin.FadeKeyedArt(f)
	WSkin.FadeArtIn(f)
	WhitenTextIn(f)

	FlatBar(_G.ArchaeologyFrameRankBar)
	FlatBar(_G.ArchaeologyFrameArtifactPageSolveFrameStatusBar)
	if _G.ArchaeologyFrameRaceFilter then WSkin.Dropdown(_G.ArchaeologyFrameRaceFilter) end
	local icon = _G.ArchaeologyFrameArtifactPageIcon
	if icon and _G.ArchaeologyFrameArtifactPage then WSkin.SquareIcon(icon, _G.ArchaeologyFrameArtifactPage) end
	for _, base in ipairs({ "ArchaeologyFrameSummaryPage", "ArchaeologyFrameCompletedPage" }) do
		for suffix, ch in pairs({ PrevPageButton = "<", NextPageButton = ">" }) do
			local pb = _G[base .. suffix]
			if pb then
				WSkin.PageButton(pb, ch)
				KillTex(_G[base .. suffix .. "Icon"])
			end
		end
	end
	for i = 1, (_G.ARCHAEOLOGY_MAX_COMPLETED_SHOWN or 12) do
		local a = _G["ArchaeologyFrameCompletedPageArtifact" .. i]
		if a then
			Fade(a.border)
			if a.icon then WSkin.SquareIcon(a.icon, a) end
			if a.artifactSubText then a.artifactSubText:SetTextColor(0.65, 0.65, 0.65) end
		end
	end
	WSkin.ButtonsIn(f)
	WSkin.ScrollBarsIn(f)
	WSkin.HookShow(f, WSkin.Debounce(function()
		if f:IsVisible() then
			WhitenTextIn(f)
			WSkin.Restrip("professionsbook")
		end
	end))
end

WSkin.RegisterWindow({
	key = "professionsbook",
	addons = { Blizzard_ArchaeologyUI = true },
	elvui = "archaeology",
	apply = Skin_Archaeology,
})
end

-------------------------------------------------------------------------------
--  Profession Crafting (TradeSkillFrame)
-------------------------------------------------------------------------------
do
local function SkinRows()
	for i = 1, 40 do
		local b = _G["TradeSkillSkill" .. i]
		if not b then break end
		if b.SubSkillRankBar then FlatBar(b.SubSkillRankBar) end
	end
end

local function SkinSelection(id)
	local icon = _G.TradeSkillSkillIcon
	if icon then
		local nt = icon:GetNormalTexture()
		if nt then
			nt:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			WSkin.QualityBorder(icon, nt, 0, 0, 0)
			if id and type(_G.GetTradeSkillItemLink) == "function" then
				WSkin.SetQualityColor(icon, _G.GetTradeSkillItemLink(id))
			end
		end
	end
	local nameFS = _G.TradeSkillSkillName
	if nameFS then
		local link = id and type(_G.GetTradeSkillItemLink) == "function" and _G.GetTradeSkillItemLink(id)
		local r, g, b = WSkin.LinkQuality(link)
		if r then nameFS:SetTextColor(r, g, b) else nameFS:SetTextColor(1, 1, 1) end
	end
	for _, n in ipairs({ "TradeSkillReagentLabel", "TradeSkillRequirementLabel", "TradeSkillDescription" }) do
		if _G[n] then WSkin.White(_G[n]) end
	end
	for i = 1, (_G.MAX_TRADE_SKILL_REAGENTS or 8) do
		local rb = _G["TradeSkillReagent" .. i]
		if rb then
			local ricon = _G["TradeSkillReagent" .. i .. "IconTexture"]
			Fade(_G["TradeSkillReagent" .. i .. "NameFrame"])
			if ricon then
				local rd = GetFFD(rb)
				if not rd.reagent then
					rd.reagent = true
					RowBlock(rb, { hover = 0.05 })
					WSkin.SquareIcon(ricon, rb, true)
				end
				if id and type(_G.GetTradeSkillReagentItemLink) == "function" then
					WSkin.SetQualityColor(rb, _G.GetTradeSkillReagentItemLink(id, i))
				end
			end
		end
	end
end

local function Skin_TradeSkill()
	local f = _G.TradeSkillFrame
	if not f then return end
	WSkin.Shell("professions", f)
	WSkin.RemovePortrait(f)
	WSkin.CommonChrome(f, "TradeSkillFrame")
	if _G.TradeSkillFrameInset then WSkin.Inset(_G.TradeSkillFrameInset) end
	FadeG({ "TradeSkillFrameBg" })
	FlatBar(_G.TradeSkillRankFrame)
	for _, n in ipairs({ "TradeSkillListScrollFrame", "TradeSkillDetailScrollFrame", "TradeSkillDetailScrollChildFrame",
		"TradeSkillExpandButtonFrame" }) do
		if _G[n] then WSkin.FadeRegions(_G[n]) end
	end
	-- Detail pane: faint shade behind the schematic.
	local det = _G.TradeSkillDetailScrollFrame
	if det then
		local dd = GetFFD(det)
		if not dd.bg then
			dd.bg = SolidTex(det, "BACKGROUND", 0, 0, 0, 0.25, -6)
			dd.bg:SetAllPoints(det)
		end
	end
	if _G.TradeSkillHighlight then
		_G.TradeSkillHighlight:SetTexture(WHITE)
		_G.TradeSkillHighlight:SetAlpha(0.2)
	end
	if _G.TradeSkillFilterButton then
		WSkin.Button(_G.TradeSkillFilterButton)
		WSkin.WhiteButtonLabel(_G.TradeSkillFilterButton)
	end
	local fb = _G.TradeSkillFilterBar
	if fb then
		local fbd = GetFFD(fb)
		if not fbd.bg then
			WSkin.FadeRegions(fb)
			fbd.bg = SolidTex(fb, "BACKGROUND", 1, 1, 1, 0.05)
			fbd.bg:SetAllPoints(fb)
		end
		if _G.TradeSkillFilterBarExitButton then WSkin.CloseButton(_G.TradeSkillFilterBarExitButton) end
	end
	if _G.TradeSkillDecrementButton then WSkin.PageButton(_G.TradeSkillDecrementButton, "<", 12) end
	if _G.TradeSkillIncrementButton then WSkin.PageButton(_G.TradeSkillIncrementButton, ">", 12) end
	if _G.TradeSkillInputBox then WSkin.EditBox(_G.TradeSkillInputBox) end
	local gf = _G.TradeSkillGuildFrame
	if gf then
		PopupShell("professions", gf)
		if _G.TradeSkillGuildFrameContainer then WSkin.Panel(_G.TradeSkillGuildFrameContainer, { inset = true }) end
	end
	WSkin.ButtonsIn(f)
	for _, n in ipairs({ "TradeSkillCreateButton", "TradeSkillCreateAllButton", "TradeSkillCancelButton", "TradeSkillViewGuildCraftersButton" }) do
		if _G[n] then WSkin.StateButtonLabel(_G[n]) end
	end
	SkinRows()
	SkinSelection(type(_G.GetTradeSkillSelectionIndex) == "function" and _G.GetTradeSkillSelectionIndex() or nil)

	local fd = GetFFD(f)
	if not fd.tsHooked then
		fd.tsHooked = true
		HookFn("TradeSkillFrame_SetSelection", SkinSelection)
		-- Blizzard re-colors the rank bars on every update: re-apply the fill.
		HookFn("TradeSkillFrame_Update", function()
			if _G.TradeSkillRankFrame then WSkin.ApplyBarFill(_G.TradeSkillRankFrame) end
			for i = 1, 40 do
				local b = _G["TradeSkillSkill" .. i]
				if not b then break end
				if b.SubSkillRankBar then WSkin.ApplyBarFill(b.SubSkillRankBar) end
			end
		end)
		WSkin.HookShow(f, WSkin.Debounce(function()
			if f:IsVisible() then SkinRows(); WSkin.Restrip("professions") end
		end))
	end
end

WSkin.RegisterWindow({
	key = "professions",
	label = "Profession Crafting",
	description = "The profession crafting window: recipe list, schematic, specializations, and crafting orders.",
	order = 90,
	addons = { Blizzard_TradeSkillUI = true },
	elvui = "tradeskill",
	apply = Skin_TradeSkill,
})
end

-------------------------------------------------------------------------------
--  Map & Quest Log: WorldMapFrame chrome + QuestLogFrame / QuestLogDetailFrame
-------------------------------------------------------------------------------
do
local _mapHost

-- The 5.4.8 map frame is screen sized: the shell rides an own frame seated
-- around the map (and the quest panel) per map size.
local function SeatMapHost()
	local host = _mapHost
	local f = _G.WorldMapFrame
	local det = _G.WorldMapDetailFrame
	if not (host and f and det) then return end
	host:ClearAllPoints()
	local s = _G.WORLDMAP_SETTINGS and _G.WORLDMAP_SETTINGS.size
	if s ~= nil and s == _G.WORLDMAP_WINDOWED_SIZE then
		host:SetPoint("TOPLEFT", f, "TOPLEFT", 5, 0)
		host:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 4)
	elseif s ~= nil and s == _G.WORLDMAP_QUESTLIST_SIZE then
		host:SetPoint("TOPLEFT", det, "TOPLEFT", -10, 69)
		host:SetPoint("BOTTOMRIGHT", det, "BOTTOMRIGHT", 321, -237)
	else
		host:SetPoint("TOPLEFT", det, "TOPLEFT", -10, 70)
		host:SetPoint("BOTTOMRIGHT", det, "BOTTOMRIGHT", 12, -30)
	end
end

-- Retail quest log panel: list and details sit on the shell with no plate,
-- the rewards box gets a solid #050505 base (retail's card art is an atlas).
local function ShadePanel(sf, solid)
	if not sf then return end
	local d = GetFFD(sf)
	if d.bg ~= nil then return end
	WSkin.FadeRegions(sf)
	WSkin.Register(sf, true)
	d.bg = false
	if solid then
		d.bg = SolidTex(sf, "BACKGROUND", 0.0196, 0.0196, 0.0196, 1, -7)
		d.bg:SetAllPoints(sf)
	end
end

-- Retail max/min buttons: Blizzard art gone, a desaturated white glyph
-- (75% alpha, full on hover). 5.4.8 has no quest tracker atlas: -/+ drawn.
local function SizeButton(btn, plus)
	if not btn or Forbidden(btn) then return end
	local d = GetFFD(btn)
	if d.glyph then return end
	if btn.SetNormalTexture then btn:SetNormalTexture("") end
	if btn.SetPushedTexture then btn:SetPushedTexture("") end
	if btn.SetHighlightTexture then btn:SetHighlightTexture("") end
	WSkin.FadeRegions(btn)
	local h = SolidTex(btn, "OVERLAY", 1, 1, 1, 1)
	h:SetSize(10, 2)
	h:SetPoint("CENTER", btn, "CENTER", -2, 0)
	local parts = { h }
	if plus then
		local v = SolidTex(btn, "OVERLAY", 1, 1, 1, 1)
		v:SetSize(2, 10)
		v:SetPoint("CENTER", btn, "CENTER", -2, 0)
		parts[2] = v
	end
	d.glyph = parts
	local function Tint(a)
		for i = 1, #parts do parts[i]:SetVertexColor(1, 1, 1, a) end
	end
	Tint(0.75)
	btn:HookScript("OnEnter", function() Tint(1) end)
	btn:HookScript("OnLeave", function() Tint(0.75) end)
end

-- Retail nav bar: one 20% black band behind the breadcrumbs. The 5.4.8 map
-- has the continent / zone dropdown row there instead (big map only).
local function SeatNavBand()
	local host = _mapHost
	local zone = _G.WorldMapZoneDropDown
	if not (host and zone) then return end
	local d = GetFFD(host)
	if not d.navBand then
		d.navBand = SolidTex(host, "BORDER", 0, 0, 0, 0.2, -6)
	end
	local band = d.navBand
	local s = _G.WORLDMAP_SETTINGS and _G.WORLDMAP_SETTINGS.size
	if (s ~= nil and s == _G.WORLDMAP_WINDOWED_SIZE) or not zone:IsShown() then
		band:Hide()
		return
	end
	band:ClearAllPoints()
	band:SetPoint("LEFT", host, "LEFT", 1, 0)
	band:SetPoint("RIGHT", host, "RIGHT", -1, 0)
	band:SetPoint("TOP", zone, "TOP", 0, 2)
	band:SetPoint("BOTTOM", zone, "BOTTOM", 0, 4)
	band:Show()
end

local function Skin_WorldMap()
	local f = _G.WorldMapFrame
	if not f then return end
	WSkin.FadeRegions(f)
	WSkin.Register(f, true)
	if not _mapHost then
		_mapHost = CreateFrame("Frame", nil, f)
		_mapHost:SetFrameLevel(math.max(0, f:GetFrameLevel()))
		WSkin.Shell("worldmap", _mapHost)
	end
	SeatMapHost()
	SeatNavBand()
	if _G.WorldMapFrameTitle then
		WSkin.Font(_G.WorldMapFrameTitle)
		WSkin.White(_G.WorldMapFrameTitle)
	end
	if _G.WorldMapFrameCloseButton then WSkin.CloseButton(_G.WorldMapFrameCloseButton) end
	SizeButton(_G.WorldMapFrameSizeDownButton, false)
	SizeButton(_G.WorldMapFrameSizeUpButton, true)
	for _, n in ipairs({ "WorldMapLevelDropDown", "WorldMapZoneMinimapDropDown", "WorldMapContinentDropDown",
		"WorldMapZoneDropDown", "WorldMapShowDropDown" }) do
		if _G[n] then WSkin.Dropdown(_G[n]) end
	end
	if _G.WorldMapZoomOutButton then
		WSkin.Button(_G.WorldMapZoomOutButton)
		WSkin.StateButtonLabel(_G.WorldMapZoomOutButton)
	end
	if _G.WorldMapLevelUpButton then WSkin.PageButton(_G.WorldMapLevelUpButton, "^", 10) end
	if _G.WorldMapLevelDownButton then WSkin.PageButton(_G.WorldMapLevelDownButton, "v", 10) end
	for _, n in ipairs({ "WorldMapTrackQuest", "WorldMapQuestShowObjectives", "WorldMapShowDigSites" }) do
		local cb = _G[n]
		if cb then
			WSkin.Checkbox(cb)
			local t = _G[n .. "Text"]
			if t then WSkin.White(t) end
		end
	end
	for _, n in ipairs({ "WorldMapQuestScrollFrame", "WorldMapQuestDetailScrollFrame", "WorldMapQuestRewardScrollFrame" }) do
		ShadePanel(_G[n], n == "WorldMapQuestRewardScrollFrame")
		local sb = _G[n .. "ScrollBar"]
		if sb then WSkin.ScrollBar(sb) end
	end
	for _, n in ipairs({ "WorldMapQuestHighlightBar", "WorldMapQuestSelectBar" }) do
		local t = _G[n]
		if t then
			t:SetTexture(WHITE)
			t:SetAlpha(0.2)
		end
	end
	local md = GetFFD(f)
	if not md.mapHooked then
		md.mapHooked = true
		for _, fn in ipairs({ "WorldMapFrame_SetQuestMapView", "WorldMapFrame_SetFullMapView", "WorldMap_ToggleSizeDown",
			"WorldMap_ToggleSizeUp", "WorldMapFrame_ToggleWindowSize" }) do
			HookFn(fn, SeatMapHost)
			HookFn(fn, SeatNavBand)
		end
		WSkin.HookShow(f, function()
			SeatMapHost()
			SeatNavBand()
			WSkin.FadeRegions(f)
		end)
	end
end

WSkin.RegisterWindow({
	key = "worldmap",
	label = "Map & Quest Log",
	description = "The world map window chrome and the quest log side panel.",
	order = 100,
	elvui = "worldmap",
	apply = Skin_WorldMap,
})

-- Quest log text: white on the shell while the quest info sits in the log;
-- back to Blizzard's ink in the NPC quest window when no quest skin runs there.
local QUEST_TEXT = { "QuestInfoTitleHeader", "QuestInfoDescriptionHeader", "QuestInfoObjectivesHeader",
	"QuestInfoRewardsHeader", "QuestInfoDescriptionText", "QuestInfoObjectivesText", "QuestInfoGroupSize",
	"QuestInfoRewardText", "QuestInfoItemChooseText", "QuestInfoItemReceiveText", "QuestInfoSpellLearnText",
	"QuestInfoXPFrameReceiveText", "QuestInfoHonorFrameReceiveText", "QuestInfoTalentFrameReceiveText",
	"QuestInfoReputationText", "QuestInfoSpellObjectiveLearnLabel", "QuestInfoRequiredMoneyText", "QuestInfoTimerText" }
local _origColor = setmetatable({}, { __mode = "k" })
-- Retail map quest panel: section headers quest yellow, body white.
local QUEST_HEADERS = { QuestInfoTitleHeader = true, QuestInfoDescriptionHeader = true,
	QuestInfoObjectivesHeader = true, QuestInfoRewardsHeader = true }

local function QuestPackActive()
	for _, e in ipairs(WSkin.windows) do
		if e.key == "quest" and e.applied then return true end
	end
	return false
end

local function Remember(fs)
	if fs and not _origColor[fs] and fs.GetTextColor then
		local r, g, b = fs:GetTextColor()
		_origColor[fs] = { r or 0, g or 0, b or 0 }
	end
end

local function ColorQuestInfo()
	local qi = _G.QuestInfoFrame
	if not qi then return end
	local inLog = qi.questLog and true or false
	if not inLog and QuestPackActive() then return end
	local list = {}
	for _, n in ipairs(QUEST_TEXT) do
		if _G[n] then list[#list + 1] = _G[n] end
	end
	for i = 1, 20 do
		local o = _G["QuestInfoObjective" .. i]
		if not o then break end
		list[#list + 1] = o
	end
	for _, fs in ipairs(list) do
		Remember(fs)
		if inLog then
			local r, g, b = fs:GetTextColor()
			-- Finished objectives come in grey: keep them a lighter grey.
			if fs:GetName() and QUEST_HEADERS[fs:GetName()] then
				fs:SetTextColor(1, 0.82, 0)
			elseif fs:GetName() and fs:GetName():find("QuestInfoObjective%d") and type(r) == "number" and r > 0.15 and r < 0.4 and math.abs(r - g) < 0.05 then
				fs:SetTextColor(0.6, 0.6, 0.6)
			else
				fs:SetTextColor(1, 1, 1)
			end
			RecolorLinks(fs)
		else
			local c = _origColor[fs]
			if c then fs:SetTextColor(c[1], c[2], c[3]) end
		end
	end
end

-- Retail quest log section headers: white 5% plate behind the row, white text.
-- Rows are recycled (HybridScrollFrame), so every update re-asserts.
local function SkinQuestLogHeaders()
	local sf = _G.QuestLogScrollFrame
	local buttons = sf and sf.buttons
	if not buttons then return end
	for i = 1, #buttons do
		local btn = buttons[i]
		local d = GetFFD(btn)
		if not d.plate then
			d.plate = SolidTex(btn, "BACKGROUND", 1, 1, 1, 0.05, -2)
			d.plate:SetAllPoints(btn)
		end
		local isHeader = btn.isHeader and btn:IsShown()
		d.plate:SetShown(isHeader and true or false)
		if isHeader then
			local fs = btn.normalText or (btn.GetFontString and btn:GetFontString())
			if fs and fs.SetTextColor then WSkin.White(fs) end
		end
	end
end

local function Skin_QuestLog()
	local f = _G.QuestLogFrame
	if not f then return end
	WSkin.Shell("worldmap", f)
	WSkin.RemovePortrait(f)
	WSkin.CommonChrome(f, "QuestLogFrame")
	if _G.QuestLogFrameInset then WSkin.Inset(_G.QuestLogFrameInset) end
	if _G.EmptyQuestLogFrame then WSkin.FadeRegions(_G.EmptyQuestLogFrame) end
	if _G.QuestLogCount then WSkin.Panel(_G.QuestLogCount, { shade = true }) end
	for _, n in ipairs({ "QuestLogScrollFrame", "QuestLogDetailScrollFrame", "QuestLogDetailScrollChildFrame" }) do
		if _G[n] then WSkin.FadeRegions(_G[n]) end
	end
	if _G.QuestLogSkillHighlight then
		_G.QuestLogSkillHighlight:SetTexture(WHITE)
		_G.QuestLogSkillHighlight:SetAlpha(0.2)
	end
	WSkin.ButtonsIn(f)
	if _G.QuestLogFrameShowMapButton then
		local t = _G.QuestLogFrameShowMapButton.text or _G.QuestLogFrameShowMapButtonText
		if t then WSkin.White(t) end
	end
	local df = _G.QuestLogDetailFrame
	if df then
		PopupShell("worldmap", df)
		if _G.QuestLogDetailFrameInset then WSkin.Inset(_G.QuestLogDetailFrameInset) end
	end
	ColorQuestInfo()
	SkinQuestLogHeaders()
	local fd = GetFFD(f)
	if not fd.qlHooked then
		fd.qlHooked = true
		HookFn("QuestInfo_Display", ColorQuestInfo)
		HookFn("QuestLog_Update", WSkin.WindowCallback("worldmap", SkinQuestLogHeaders))
		WSkin.OnLooksChanged(ColorQuestInfo)
		WSkin.HookShow(f, WSkin.Debounce(function()
			if f:IsVisible() then WSkin.Restrip("worldmap"); ColorQuestInfo() end
		end))
	end
end

WSkin.RegisterWindow({
	key = "worldmap",
	elvui = "quest",
	apply = Skin_QuestLog,
})
end

-------------------------------------------------------------------------------
--  Guild: GuildFrame, LookingForGuildFrame, GuildBankFrame
-------------------------------------------------------------------------------
do
-- Guild XP / reputation bar (plain textures, not a StatusBar).
local _xpBars = {}
local function TintXPBars()
	local r, g, b, a = WSkin.BarFillColor()
	for bar in pairs(_xpBars) do
		if bar.progress then bar.progress:SetVertexColor(r, g, b, a) end
	end
end

local function SkinTextureBar(bar)
	if not bar or Forbidden(bar) then return end
	local d = GetFFD(bar)
	local n = bar:GetName()
	local cap = n and _G[n .. "Cap"]
	local marker = n and _G[n .. "CapMarker"]
	local keep = {}
	if bar.progress then keep[bar.progress] = true end
	if cap then keep[cap] = true end
	if marker then keep[marker] = true end
	if d.bg then keep[d.bg] = true end
	WSkin.FadeRegions(bar, keep)
	if bar.progress then bar.progress:SetTexture(WHITE) end
	if cap then
		cap:SetTexture(WHITE)
		cap:SetVertexColor(1, 1, 1, 0.25)
	end
	if marker then marker:SetTexture(1, 1, 1, 0.4) end
	if not d.bg then
		d.bg = SolidTex(bar, "BACKGROUND", 0.12, 0.12, 0.12, 0.85, -1)
		d.bg:SetAllPoints(bar)
		WSkin.AddBorder(bar)
	end
	local label = n and _G[n .. "Label"]
	if label then WSkin.White(label) end
	_xpBars[bar] = true
	TintXPBars()
end

local function SkinGuildRows()
	for i = 1, 20 do
		local b = _G["GuildRosterContainerButton" .. i]
		if not b then break end
		local d = GetFFD(b)
		if not d.groster then
			d.groster = true
			local hl = b.GetHighlightTexture and b:GetHighlightTexture()
			if hl then hl:SetTexture(1, 1, 1, 0.08) end
			local bt = _G["GuildRosterContainerButton" .. i .. "BarTexture"]
			if bt then bt:SetTexture(WHITE) end
			local hb = _G["GuildRosterContainerButton" .. i .. "HeaderButton"]
			if hb then WSkin.Button(hb); WSkin.WhiteButtonLabel(hb) end
		end
	end
	for _, obj in ipairs({ "Rewards", "Perks" }) do
		for i = 1, 10 do
			local b = _G["Guild" .. obj .. "ContainerButton" .. i]
			if not b then break end
			local d = GetFFD(b)
			if not d.greward then
				d.greward = true
				local keep = {}
				if b.icon then keep[b.icon] = true end
				WSkin.FadeRegions(b, keep)
				RowBlock(b, { inset = { 0, 1, 0, 1 } })
				if b.icon then WSkin.SquareIcon(b.icon, b) end
				local hl = b.GetHighlightTexture and b:GetHighlightTexture()
				if hl then hl:SetAlpha(0) end
			end
			if obj == "Perks" and b.name then WSkin.White(b.name) end
			if b.subText then b.subText:SetTextColor(0.82, 0.82, 0.82) end
		end
	end
	for i = 1, 20 do
		local b = _G["GuildNewsContainerButton" .. i]
		if not b then break end
		Fade(b.header)
	end
end

local GUILD_CHECKS = { "GuildRosterShowOfflineButton", "GuildRecruitmentQuestButton", "GuildRecruitmentDungeonButton",
	"GuildRecruitmentRaidButton", "GuildRecruitmentPvPButton", "GuildRecruitmentRPButton", "GuildRecruitmentWeekdaysButton",
	"GuildRecruitmentWeekendsButton", "GuildRecruitmentLevelAnyButton", "GuildRecruitmentLevelMaxButton" }

local function Skin_Guild()
	local f = _G.GuildFrame
	if not f then return end
	WSkin.Shell("guild", f)
	WSkin.RemovePortrait(f)
	for _, n in ipairs({ "GuildFrameInset", "GuildFrameBottomInset" }) do
		if _G[n] then WSkin.Inset(_G[n]) end
	end
	if _G.GuildLevelFrame then WSkin.FadeRegions(_G.GuildLevelFrame) end
	-- Sub-panels first (their art), then the common sweeps.
	for _, n in ipairs({ "GuildNewPerksFrame", "GuildAllPerksFrame", "GuildRewardsFrame", "GuildNewsFrame", "GuildInfoFrameInfo",
		"GuildRecruitmentRolesFrame", "GuildRecruitmentLevelFrame", "GuildRecruitmentCommentFrame", "GuildRecruitmentInterestFrame",
		"GuildRecruitmentAvailabilityFrame", "GuildInfoFrameApplicants", "GuildInfoFrameApplicantsContainer", "GuildPerksToggleButton",
		"GuildLatestPerkButton", "GuildNextPerkButton", "GuildInfoFrame" }) do
		local fr = _G[n]
		if fr then
			local keep = nil
			local icon = _G[n .. "IconTexture"]
			if icon then keep = { [icon] = true } end
			WSkin.FadeRegions(fr, keep)
			if icon then WSkin.SquareIcon(icon, fr) end
		end
	end
	WSkin.CommonChrome(f, "GuildFrame")
	if _G.GuildPerksToggleButton then WSkin.Button(_G.GuildPerksToggleButton); WSkin.WhiteButtonLabel(_G.GuildPerksToggleButton) end
	local tabs = TabsNamed("GuildFrameTab", 5)
	KeepTabRow(f, tabs)
	TabsNamed("GuildInfoFrameTab", 3)

	SkinTextureBar(_G.GuildXPBar)
	SkinTextureBar(_G.GuildFactionBar)
	if _G.GuildFactionFrame then WSkin.FadeRegions(_G.GuildFactionFrame) end
	SkinGuildRows()
	for _, n in ipairs(GUILD_CHECKS) do
		local cb = _G[n]
		if cb then WSkin.Checkbox(cb) end
	end
	for _, n in ipairs({ "GuildRecruitmentCommentInputFrame", "GuildMemberNoteBackground", "GuildMemberOfficerNoteBackground" }) do
		local fr = _G[n]
		if fr then
			ClearBackdrop(fr)
			WSkin.Panel(fr, { inset = true })
		end
	end
	-- Side popups: member detail, news filters, boss model, text editor, log.
	for _, n in ipairs({ "GuildMemberDetailFrame", "GuildNewsFiltersFrame", "GuildTextEditFrame", "GuildLogFrame" }) do
		PopupShell("guild", _G[n])
	end
	for i = 1, 7 do
		local cb = _G["GuildNewsFilterButton" .. i]
		if cb then WSkin.Checkbox(cb) end
	end
	for _, n in ipairs({ "GuildTextEditContainer", "GuildLogContainer" }) do
		if _G[n] then WSkin.Panel(_G[n], { inset = true }) end
	end
	local bm = _G.GuildNewsBossModel
	if bm then
		WSkin.Panel(bm)
		if _G.GuildNewsBossModelTextFrame then WSkin.Panel(_G.GuildNewsBossModelTextFrame) end
	end
	WSkin.ButtonsIn(f)
	WSkin.ScrollBarsIn(f)

	local fd = GetFFD(f)
	if not fd.guildHooked then
		fd.guildHooked = true
		local re = WSkin.Debounce(function()
			if f:IsVisible() then SkinGuildRows(); WSkin.Restrip("guild") end
		end)
		HookFn("GuildRoster_Update", re)
		HookFn("GuildRewards_Update", re)
		HookFn("GuildPerks_Update", re)
		HookFn("GuildNewsFrame_Update", re)
		WSkin.OnLooksChanged(TintXPBars)
		WSkin.HookShow(f, WSkin.Debounce(function()
			if f:IsVisible() then
				SkinGuildRows()
				WSkin.Restrip("guild")
				WSkin.UpdateAllTabs()
			end
		end))
	end
end

WSkin.RegisterWindow({
	key = "guild",
	label = "Guild & Communities",
	description = "The Guild & Communities window: roster, chat, and the community list.",
	order = 110,
	addons = { Blizzard_GuildUI = true },
	elvui = "guild",
	apply = Skin_Guild,
})

local LFG_CHECKS = { "LookingForGuildPvPButton", "LookingForGuildWeekendsButton", "LookingForGuildWeekdaysButton",
	"LookingForGuildRPButton", "LookingForGuildRaidButton", "LookingForGuildQuestButton", "LookingForGuildDungeonButton" }

local function Skin_LookingForGuild()
	local f = _G.LookingForGuildFrame
	if not f then return end
	WSkin.Shell("guild", f)
	WSkin.RemovePortrait(f)
	if _G.LookingForGuildFrameInset then WSkin.Inset(_G.LookingForGuildFrameInset) end
	WSkin.CommonChrome(f, "LookingForGuildFrame")
	TabsNamed("LookingForGuildFrameTab", 3)
	for _, n in ipairs(LFG_CHECKS) do
		if _G[n] then WSkin.Checkbox(_G[n]) end
	end
	local ci = _G.LookingForGuildCommentInputFrame
	if ci then
		ClearBackdrop(ci)
		WSkin.Panel(ci, { inset = true })
	end
	if _G.LookingForGuildBrowseFrameContainer then
		WSkin.Panel(_G.LookingForGuildBrowseFrameContainer, { shade = true, noBorder = true })
	end
	if _G.LookingForGuildAppsFrameContainer then
		WSkin.Panel(_G.LookingForGuildAppsFrameContainer, { shade = true, noBorder = true })
	end
	local ar, ag, ab = WSkin.AccentBarColor()
	for i = 1, 5 do
		local b = _G["LookingForGuildBrowseFrameContainerButton" .. i]
		if b then
			ClearBackdrop(b)
			Fade(b.PointsSpentBgGold)
			Fade(b.border)
			Fade(_G["LookingForGuildBrowseFrameContainerButton" .. i .. "Ring"])
			local hl = b.GetHighlightTexture and b:GetHighlightTexture()
			if hl then hl:SetTexture(1, 1, 1, 0.08) end
			if b.selectedTex then b.selectedTex:SetTexture(ar, ag, ab, 0.15) end
		end
	end
	for i = 1, 10 do
		local b = _G["LookingForGuildAppsFrameContainerButton" .. i]
		if b then
			local hl = _G["LookingForGuildAppsFrameContainerButton" .. i .. "Highlight"]
			if hl then hl:SetTexture(1, 1, 1, 0.08) end
			if b.removeButton then WSkin.CloseButton(b.removeButton) end
		end
	end
	local rf = _G.GuildFinderRequestMembershipFrame
	if rf then
		PopupShell("guild", rf)
		local inp = _G.GuildFinderRequestMembershipFrameInputFrame
		if inp then
			ClearBackdrop(inp)
			WSkin.Panel(inp, { inset = true })
		end
	end
	WSkin.ButtonsIn(f)
	WSkin.HookShow(f, WSkin.Debounce(function()
		if f:IsVisible() then WSkin.Restrip("guild"); WSkin.UpdateAllTabs() end
	end))
end

WSkin.RegisterWindow({
	key = "guild",
	addons = { Blizzard_LookingForGuildUI = true },
	elvui = "lfguild",
	apply = Skin_LookingForGuild,
})

-- Guild bank: slots squared with rarity borders, side tabs, bottom tabs.
local function PaintBankSlots()
	local gb = _G.GuildBankFrame
	if not gb or gb.mode ~= "bank" then return end
	if type(_G.GetCurrentGuildBankTab) ~= "function" or type(_G.GetGuildBankItemLink) ~= "function" then return end
	local tab = _G.GetCurrentGuildBankTab()
	local per = _G.NUM_SLOTS_PER_GUILDBANK_GROUP or 14
	for i = 1, (_G.MAX_GUILDBANK_SLOTS_PER_TAB or 98) do
		local index = math.fmod(i, per)
		if index == 0 then index = per end
		local column = math.ceil((i - 0.5) / per)
		local b = _G["GuildBankColumn" .. column .. "Button" .. index]
		if b then WSkin.SetQualityColor(b, _G.GetGuildBankItemLink(tab, i)) end
	end
end

local function Skin_GuildBank()
	local f = _G.GuildBankFrame
	if not f then return end
	WSkin.Shell("guild", f, { inset = { 2, 20, 2, 20 } })
	WSkin.CommonChrome(f, "GuildBankFrame")
	if _G.GuildBankMoneyFrameBackground then WSkin.FadeRegions(_G.GuildBankMoneyFrameBackground) end
	FadeG({ "GuildBankTabTitleBackground", "GuildBankTabTitleBackgroundLeft", "GuildBankTabTitleBackgroundRight",
		"GuildBankTabLimitBackground", "GuildBankTabLimitBackgroundLeft", "GuildBankTabLimitBackgroundRight" })
	for _, n in ipairs({ "GuildBankTabTitle", "GuildBankLimitLabel" }) do
		if _G[n] then WSkin.White(_G[n]) end
	end
	-- Close button of the frame template (unnamed in some builds).
	local children = { f:GetChildren() }
	for i = 1, #children do
		local c = children[i]
		if c and c.GetObjectType and c:GetObjectType() == "Button" and not c:GetName() and c.GetPushedTexture then
			local pt = c:GetPushedTexture()
			local hay = pt and WSkin.TexHay(pt)
			if hay and hay:find("minimizebutton", 1, true) then WSkin.CloseButton(c) end
		end
	end
	for i = 1, (_G.NUM_GUILDBANK_COLUMNS or 7) do
		local col = _G["GuildBankColumn" .. i]
		if col then WSkin.FadeRegions(col) end
		for x = 1, (_G.NUM_SLOTS_PER_GUILDBANK_GROUP or 14) do
			local b = _G["GuildBankColumn" .. i .. "Button" .. x]
			if b then WSkin.ItemButton(b, { quality = true }) end
		end
	end
	for i = 1, 8 do
		local tab = _G["GuildBankTab" .. i]
		if tab then WSkin.FadeRegions(tab) end
		local tb = _G["GuildBankTab" .. i .. "Button"]
		if tb then WSkin.SideTab(tb) end
	end
	local tabs = TabsNamed("GuildBankFrameTab", 4)
	KeepTabRow(f, tabs)
	if _G.GuildBankMessageFrame then WSkin.Panel(_G.GuildBankMessageFrame, { shade = true }) end
	if _G.GuildBankInfoScrollFrame then
		WSkin.FadeRegions(_G.GuildBankInfoScrollFrame)
		WSkin.Panel(_G.GuildBankInfoScrollFrame, { shade = true })
	end
	if _G.GuildBankTransactionsScrollFrame then WSkin.FadeRegions(_G.GuildBankTransactionsScrollFrame) end
	local pop = _G.GuildBankPopupFrame
	if pop then
		PopupShell("guild", pop)
		for i = 1, (_G.NUM_GUILDBANK_ICONS_SHOWN or 20) do
			local b = _G["GuildBankPopupButton" .. i]
			if b then WSkin.ItemButton(b) end
		end
	end
	WSkin.ButtonsIn(f)
	PaintBankSlots()
	local fd = GetFFD(f)
	if not fd.gbHooked then
		fd.gbHooked = true
		HookFn("GuildBankFrame_Update", PaintBankSlots)
		WSkin.HookShow(f, WSkin.Debounce(function()
			if f:IsVisible() then
				PaintBankSlots()
				WSkin.Restrip("guild")
				WSkin.UpdateAllTabs()
			end
		end))
	end
end

WSkin.RegisterWindow({
	key = "guild",
	addons = { Blizzard_GuildBankUI = true },
	elvui = "gbank",
	apply = Skin_GuildBank,
})
end

-------------------------------------------------------------------------------
--  Calendar (CalendarFrame + its event dialogs)
-------------------------------------------------------------------------------
do
local function SkinCalendarDays()
	for i = 1, 42 do
		local day = _G["CalendarDayButton" .. i]
		if day then
			local d = GetFFD(day)
			-- Blizzard re-coords the day art each update: alpha only, never removed.
			local nt = day.GetNormalTexture and day:GetNormalTexture()
			if nt then nt:SetAlpha(0) end
			if not d.bg then
				local bg = SolidTex(day, "BACKGROUND", Theme.bgR, Theme.bgG, Theme.bgB, Theme.bgA, -8)
				bg:SetAllPoints(day)
				d.bg = bg
				WSkin.AddBorder(day)
				local hl = day.GetHighlightTexture and day:GetHighlightTexture()
				if hl then
					hl:SetTexture(1, 1, 1, 0.08)
					hl:SetAllPoints(day)
				end
				for j = 1, 4 do
					local eb = _G["CalendarDayButton" .. i .. "EventButton" .. j]
					if eb then
						local ehl = eb.GetHighlightTexture and eb:GetHighlightTexture()
						if ehl then ehl:SetTexture(1, 1, 1, 0.1) end
					end
				end
				local more = _G["CalendarDayButton" .. i .. "MoreEventsButton"]
				if more then WSkin.PageButton(more, "v", 10) end
			end
		end
	end
end

-- Calendar dialog on the calendar's style.
local function SkinDialog(name)
	local f = _G[name]
	if not f or Forbidden(f) then return end
	for _, suffix in ipairs({ "TitleFrame", "InviteListSection", "Header" }) do
		local tf = _G[name .. suffix] or f[suffix]
		if tf and tf.GetRegions then WSkin.FadeRegions(tf) end
	end
	PopupShell("calendar", f)
	for _, suffix in ipairs({ "DescriptionContainer", "InviteList" }) do
		local c = _G[name .. suffix]
		if c then
			ClearBackdrop(c)
			WSkin.Panel(c, { inset = true })
		end
	end
	local title = _G[name .. "Title"] or _G[name .. "TitleFrameText"]
	if title and title.SetTextColor then WSkin.White(title) end
end

local CAL_DIALOGS = { "CalendarViewHolidayFrame", "CalendarViewRaidFrame", "CalendarViewEventFrame", "CalendarCreateEventFrame",
	"CalendarEventPickerFrame", "CalendarTexturePickerFrame", "CalendarMassInviteFrame" }
local CAL_DIALOG_PREFIX = { CalendarViewHolidayFrame = "CalendarViewHoliday", CalendarViewRaidFrame = "CalendarViewRaid",
	CalendarViewEventFrame = "CalendarViewEvent", CalendarCreateEventFrame = "CalendarCreateEvent",
	CalendarEventPickerFrame = "CalendarEventPicker", CalendarTexturePickerFrame = "CalendarTexturePicker",
	CalendarMassInviteFrame = "CalendarMassInvite" }

local function Skin_Calendar()
	local f = _G.CalendarFrame
	if not f then return end
	WSkin.Shell("calendar", f, { inset = { 9, 2, 8, 2 } })
	-- The month header row sits where the top strip would be.
	local ed = FFD[f]
	if ed and ed.topBar then ed.topBar:SetAlpha(0) end
	WSkin.CommonChrome(f, "Calendar", true)
	if _G.CalendarCloseButton then WSkin.CloseButton(_G.CalendarCloseButton) end
	if _G.CalendarPrevMonthButton then WSkin.PageButton(_G.CalendarPrevMonthButton, "<", 16) end
	if _G.CalendarNextMonthButton then WSkin.PageButton(_G.CalendarNextMonthButton, ">", 16) end
	for _, n in ipairs({ "CalendarMonthName", "CalendarYearName" }) do
		if _G[n] then WSkin.White(_G[n]) end
	end
	-- Filter: flat block from the label to the arrow button.
	local ff = _G.CalendarFilterFrame
	local fbtn = _G.CalendarFilterButton
	if ff then
		local fd = GetFFD(ff)
		if not fd.bg then
			WSkin.FadeRegions(ff)
			local host = CreateFrame("Frame", nil, ff)
			host:SetPoint("TOPLEFT", ff, "TOPLEFT", 20, 4)
			if fbtn then
				host:SetPoint("BOTTOMRIGHT", fbtn, "BOTTOMRIGHT", 2, -2)
			else
				host:SetPoint("BOTTOMRIGHT", ff, "BOTTOMRIGHT", -16, 2)
			end
			host:SetFrameLevel(math.max(0, ff:GetFrameLevel()))
			fd.bg = SolidTex(host, "BACKGROUND", Theme.bgR, Theme.bgG, Theme.bgB, Theme.bgA)
			fd.bg:SetAllPoints(host)
			WSkin.AddBorder(host, 0.25, 0.25, 0.25, 1)
			fd.host = host
		end
		if _G.CalendarFilterFrameText then WSkin.White(_G.CalendarFilterFrameText) end
	end
	if fbtn then
		local bd = GetFFD(fbtn)
		if not bd.arrow then
			for _, g in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
				local t = fbtn[g] and fbtn[g](fbtn)
				if t then t:SetAlpha(0) end
			end
			local hl = fbtn.GetHighlightTexture and fbtn:GetHighlightTexture()
			if hl then hl:SetTexture(1, 1, 1, 0.05) end
			local arrow = fbtn:CreateTexture(nil, "OVERLAY")
			arrow:SetTexture(WSkin.ARROW_DOWN_TEX)
			arrow:SetSize(12, 12)
			arrow:SetPoint("CENTER")
			bd.arrow = arrow
		end
	end
	-- Today: glow art gone (its pulse re-raises it), accent edge instead.
	KillTex(_G.CalendarTodayTexture)
	KillTex(_G.CalendarTodayTextureGlow)
	local today = _G.CalendarTodayFrame
	if today and not GetFFD(today).edge then
		GetFFD(today).edge = true
		local r, g, b = WSkin.AccentBarColor()
		BS.PP.CreateBorder(today, r, g, b, 1, 2, "OVERLAY", 7)
		WSkin.OnLooksChanged(function()
			local ar, ag, ab = WSkin.AccentBarColor()
			BS.PP.SetBorderColor(today, ar, ag, ab, 1)
		end)
	end
	SkinCalendarDays()
	for i = 1, (_G.CLASS_SORT_ORDER and #_G.CLASS_SORT_ORDER or 11) do
		local cb = _G["CalendarClassButton" .. i]
		if cb then
			local nt = cb.GetNormalTexture and cb:GetNormalTexture()
			local keep = nt and { [nt] = true } or nil
			WSkin.FadeRegions(cb, keep)
			WSkin.AddBorder(cb, 0, 0, 0, 1)
		end
	end
	for _, n in ipairs(CAL_DIALOGS) do
		SkinDialog(n)
		local prefix = CAL_DIALOG_PREFIX[n]
		local cb = prefix and _G[prefix .. "CloseButton"]
		if cb then
			if n == "CalendarEventPickerFrame" then
				WSkin.Button(cb)
				WSkin.WhiteButtonLabel(cb)
			else
				WSkin.CloseButton(cb)
			end
		end
	end
	if _G.CalendarCreateEventLockEventCheck then WSkin.Checkbox(_G.CalendarCreateEventLockEventCheck) end
	if _G.CalendarCreateEventIcon then WSkin.SquareIcon(_G.CalendarCreateEventIcon, _G.CalendarCreateEventFrame) end
	FadeG({ "CalendarCreateEventDivider", "CalendarEventPickerFrameButtonBackground", "CalendarEventPickerCloseButtonBorder" })
	WSkin.ControlsIn(f)
	WSkin.ButtonsIn(f)
	WSkin.ScrollBarsIn(f)

	local fd = GetFFD(f)
	if not fd.calHooked then
		fd.calHooked = true
		HookFn("CalendarFrame_Update", WSkin.Debounce(function()
			if f:IsVisible() then SkinCalendarDays(); WSkin.Restrip("calendar") end
		end))
		WSkin.HookShow(f, WSkin.Debounce(function()
			if f:IsVisible() then SkinCalendarDays(); WSkin.Restrip("calendar") end
		end))
	end
end

WSkin.RegisterWindow({
	key = "calendar",
	label = "Calendar",
	description = "The monthly calendar grid, event dialogs, and navigation arrows.",
	order = 120,
	addons = { Blizzard_Calendar = true },
	elvui = "calendar",
	apply = Skin_Calendar,
})
end

-------------------------------------------------------------------------------
--  Achievements (AchievementFrame)
-------------------------------------------------------------------------------
do
local function AchWhiteTexts(host)
	if not host or not host.GetRegions then return end
	local regions = { host:GetRegions() }
	for i = 1, #regions do
		local r = regions[i]
		if r and r.IsObjectType and r:IsObjectType("FontString") then WSkin.White(r) end
	end
end

local function AchWhiteTextsIn(host, depth)
	depth = depth or 0
	if not host or depth > 5 or Forbidden(host) then return end
	if depth > 0 and WSkin.IsForeignFrame(host) then return end
	AchWhiteTexts(host)
	if not host.GetChildren then return end
	local children = { host:GetChildren() }
	for i = 1, #children do AchWhiteTextsIn(children[i], depth + 1) end
end

-- Title tint like the stripped row art: account-wide blue, character gold;
-- not completed = the dimmed take on the same hue.
local function AchTitleColor(row)
	local fs = row.label
	if not fs then return end
	local done = row.completed
	if row.accountWide then
		if done then fs:SetTextColor(0.35, 0.75, 1) else fs:SetTextColor(0.24, 0.46, 0.6) end
	else
		if done then fs:SetTextColor(1, 0.85, 0.35) else fs:SetTextColor(0.64, 0.56, 0.3) end
	end
end

local function KillRowArt(row, d)
	local regions = { row:GetRegions() }
	for i = 1, #regions do
		local r = regions[i]
		if r and r ~= d.bg and r ~= d.hover and r.IsObjectType and r:IsObjectType("Texture") then
			KillTex(r)
		end
	end
	if row.icon then
		KillTex(row.icon.frame)
		KillTex(row.icon.bling)
	end
	if row.highlight and row.highlight.GetRegions then WSkin.FadeRegions(row.highlight) end
	if row.shield and row.shield.GetRegions then
		local keep = {}
		if row.shield.icon then keep[row.shield.icon] = true end
		WSkin.FadeRegions(row.shield, keep)
	end
end

-- Achievement row: parchment gone, flat block + hover, squared icon, white text.
local function SkinAchRow(row)
	if not row or Forbidden(row) then return end
	local d = GetFFD(row)
	if not d.bg then
		local bg = SolidTex(row, "BACKGROUND", Theme.bgR, Theme.bgG, Theme.bgB, Theme.bgA, -3)
		bg:SetPoint("TOPLEFT", 1, -1)
		bg:SetPoint("BOTTOMRIGHT", -1, 1)
		d.bg = bg
		WSkin.AddBorder(row)
		local hov = SolidTex(row, "HIGHLIGHT", 1, 1, 1, 0.08)
		hov:SetAllPoints(row)
		d.hover = hov
		if row.icon and row.icon.texture then WSkin.SquareIcon(row.icon.texture, row.icon) end
		LockColor(row.label, function() AchTitleColor(row) end)
		LockColor(row.description, nil)
		LockColor(row.hiddenDescription, nil)
		LockColor(row.dateCompleted, nil)
		LockColor(row.reward, nil)
		if row.shield and row.shield.points then LockColor(row.shield.points, nil) end
		if row.tracked then WSkin.Checkbox(row.tracked) end
		local n = row:GetName()
		local tt = n and _G[n .. "TrackedText"]
		if tt then WSkin.White(tt) end
		local function reassert(self)
			local rd = GetFFD(self)
			KillRowArt(self, rd)
			AchTitleColor(self)
		end
		HookM(row, "Saturate", reassert)
		HookM(row, "Desaturate", reassert)
	end
	KillRowArt(row, d)
	AchTitleColor(row)
end

local function SkinCategoryRow(btn)
	if not btn or Forbidden(btn) then return end
	local d = GetFFD(btn)
	if not d.bg then
		local bg = SolidTex(btn, "BACKGROUND", Theme.bgR + 0.015, Theme.bgG + 0.015, Theme.bgB + 0.015, Theme.bgA, -3)
		bg:SetPoint("TOPLEFT", 1, -1)
		bg:SetPoint("BOTTOMRIGHT", -1, 1)
		d.bg = bg
		WSkin.AddBorder(btn)
		local hov = SolidTex(btn, "HIGHLIGHT", 1, 1, 1, 0.1)
		hov:SetAllPoints(btn)
		d.hover = hov
		WSkin.Register(btn, true)
	end
	WSkin.FadeRegions(btn, { [d.bg] = true, [d.hover] = true })
	local hl = btn.GetHighlightTexture and btn:GetHighlightTexture()
	if hl and hl ~= d.hover then hl:SetAlpha(0) end
	if btn.label then WSkin.White(btn.label) end
end

local function SkinStatRow(b)
	if not b or Forbidden(b) then return end
	local d = GetFFD(b)
	if not d.stat then
		d.stat = true
		WSkin.FadeRegions(b)
		local hov = SolidTex(b, "HIGHLIGHT", 1, 1, 1, 0.08)
		hov:SetAllPoints(b)
		d.hover = hov
		if b.background then
			b.background:SetTexture(1, 1, 1, 0.04)
			b.background:SetAlpha(1)
		end
		local hl = b.GetHighlightTexture and b:GetHighlightTexture()
		if hl and hl ~= hov then hl:SetAlpha(0) end
	end
	AchWhiteTexts(b)
end

local function EachButton(container, fn)
	local c = _G[container]
	if not (c and c.buttons) then return end
	for i = 1, #c.buttons do fn(c.buttons[i]) end
end

local function SkinComparisonRow(b)
	if not b then return end
	SkinAchRow(b.player)
	SkinAchRow(b.friend)
end

local function SkinAllRows()
	EachButton("AchievementFrameCategoriesContainer", SkinCategoryRow)
	EachButton("AchievementFrameAchievementsContainer", SkinAchRow)
	EachButton("AchievementFrameStatsContainer", SkinStatRow)
	EachButton("AchievementFrameComparisonContainer", SkinComparisonRow)
	EachButton("AchievementFrameComparisonStatsContainer", SkinStatRow)
	for i = 1, (_G.ACHIEVEMENTUI_MAX_SUMMARY_ACHIEVEMENTS or 4) do
		SkinAchRow(_G["AchievementFrameSummaryAchievement" .. i])
	end
end

local function Skin_Achievements()
	local f = _G.AchievementFrame
	if not f then return end
	-- Frame art spills 15px past the right edge and the header sits above it.
	WSkin.Shell("achievements", f, { inset = { 0, -6, 15, 0 } })
	WSkin.CommonChrome(f, "AchievementFrame", true)
	if _G.AchievementFrameCloseButton then WSkin.CloseButton(_G.AchievementFrameCloseButton) end

	-- Header: art gone, title + points on a flat plate.
	local host = _G.AchievementFrameHeader
	if host then
		WSkin.FadeRegions(host)
		WSkin.Register(host, true)
		local title = _G.AchievementFrameHeaderTitle
		local points = _G.AchievementFrameHeaderPoints
		if title then WSkin.White(title) end
		if points then WSkin.White(points) end
		local hd = GetFFD(host)
		if not hd.plate and title then
			local plate = CreateFrame("Frame", nil, host)
			plate:SetFrameLevel(math.max(0, host:GetFrameLevel() - 1))
			plate:SetPoint("TOP", title, "TOP", 0, 7)
			plate:SetPoint("BOTTOM", title, "BOTTOM", 0, -7)
			plate:SetPoint("LEFT", title, "LEFT", -16, 0)
			plate:SetPoint("RIGHT", points or title, "RIGHT", 16, 0)
			local fill = SolidTex(plate, "BACKGROUND", 0.0275, 0.0235, 0.0157, 1)
			fill:SetAllPoints(plate)
			hd.plateFill = fill
			WSkin.AddBorder(plate)
			hd.plate = plate
		end
	end
	local function RetintPlate()
		local hd = host and FFD[host]
		if not (hd and hd.plateFill) then return end
		if WSkin.GetStyle("achievements") == "modern" then
			local _, _, _, ma = WSkin.GetModernBG()
			hd.plateFill:SetTexture(0.0196, 0.0196, 0.0196, ma or 1)
		else
			hd.plateFill:SetTexture(0.0275, 0.0235, 0.0157, 1)
		end
	end
	RetintPlate()

	for _, n in ipairs({ "AchievementFrameCategories", "AchievementFrameSummary", "AchievementFrameSummaryCategoriesHeader",
		"AchievementFrameSummaryAchievementsHeader", "AchievementFrameAchievements", "AchievementFrameStats",
		"AchievementFrameComparison", "AchievementFrameComparisonHeader", "AchievementFrameComparisonSummaryPlayer",
		"AchievementFrameComparisonSummaryFriend", "AchievementFrameCategoriesContainer", "AchievementFrameAchievementsContainer" }) do
		local sub = _G[n]
		if sub then
			WSkin.FadeRegions(sub)
			WSkin.Register(sub, true)
		end
	end
	FadeG({ "AchievementFrameStatsBG", "AchievementFrameWaterMark", "AchievementFrameSummaryBackground" })
	-- Unnamed box children carry the art as a backdrop.
	for _, n in ipairs({ "AchievementFrameStats", "AchievementFrameSummary", "AchievementFrameAchievements", "AchievementFrameComparison" }) do
		local sub = _G[n]
		if sub then
			local children = { sub:GetChildren() }
			for i = 1, #children do
				local c = children[i]
				if c and not c:GetName() and not WSkin.IsForeignFrame(c, sub) then ClearBackdrop(c) end
			end
		end
	end
	for _, tn in ipairs({ "AchievementFrameSummaryAchievementsHeaderHeader", "AchievementFrameSummaryCategoriesHeaderTexture" }) do
		local t = _G[tn]
		if t and t.SetVertexColor then
			t:SetAlpha(1)
			t:SetVertexColor(1, 1, 1, 0.25)
		end
	end
	if _G.AchievementFrameFilterDropDown then WSkin.Dropdown(_G.AchievementFrameFilterDropDown) end
	local tabs = TabsNamed("AchievementFrameTab", 3)
	KeepTabRow(f, tabs)
	WSkin.ScrollBarsIn(f)

	-- Summary + comparison bars -> flat accent bars.
	for i = 1, 12 do
		local bar = _G["AchievementFrameSummaryCategoriesCategory" .. i]
		if bar then
			FlatBar(bar)
			local hl = _G["AchievementFrameSummaryCategoriesCategory" .. i .. "ButtonHighlight"]
			if hl then WSkin.FadeRegions(hl) end
		end
	end
	FlatBar(_G.AchievementFrameSummaryCategoriesStatusBar)
	FlatBar(_G.AchievementFrameComparisonSummaryPlayerStatusBar)
	FlatBar(_G.AchievementFrameComparisonSummaryFriendStatusBar)
	if _G.AchievementFrameSummary then AchWhiteTextsIn(_G.AchievementFrameSummary) end
	if _G.AchievementFrameComparisonHeader then AchWhiteTexts(_G.AchievementFrameComparisonHeader) end
	local compPts = _G.AchievementFrameComparisonHeaderPoints
	if compPts and not GetFFD(compPts).tinted then
		GetFFD(compPts).tinted = true
		LockColor(compPts, function(fs)
			local lr, lg, lb = WSkin.LinkColor()
			fs:SetTextColor(lr, lg, lb)
		end)
	end
	SkinAllRows()

	local fd = GetFFD(f)
	if not fd.achHooked then
		fd.achHooked = true
		HookFn("AchievementButton_DisplayAchievement", function(button) SkinAchRow(button) end)
		HookFn("AchievementFrameSummary_UpdateAchievements", WSkin.Debounce(function()
			for i = 1, (_G.ACHIEVEMENTUI_MAX_SUMMARY_ACHIEVEMENTS or 4) do
				SkinAchRow(_G["AchievementFrameSummaryAchievement" .. i])
			end
		end))
		HookFn("AchievementFrameCategories_Update", function() EachButton("AchievementFrameCategoriesContainer", SkinCategoryRow) end)
		HookFn("AchievementFrameStats_Update", function() EachButton("AchievementFrameStatsContainer", SkinStatRow) end)
		HookFn("HybridScrollFrame_CreateButtons", function(frame, template)
			if not (frame and frame.buttons) then return end
			if template == "AchievementCategoryTemplate" then
				for _, b in ipairs(frame.buttons) do SkinCategoryRow(b) end
			elseif template == "AchievementTemplate" then
				for _, b in ipairs(frame.buttons) do SkinAchRow(b) end
			elseif template == "ComparisonTemplate" then
				for _, b in ipairs(frame.buttons) do SkinComparisonRow(b) end
			elseif template == "StatTemplate" or template == "ComparisonStatTemplate" then
				for _, b in ipairs(frame.buttons) do SkinStatRow(b) end
			end
		end)
		HookFn("AchievementButton_GetProgressBar", function(index)
			FlatBar(_G["AchievementFrameProgressBar" .. tostring(index)])
		end)
		-- Criteria lines: completed white, the rest grey.
		HookFn("AchievementObjectives_DisplayCriteria", function(of, id)
			if not id or type(_G.GetAchievementNumCriteria) ~= "function" then return end
			local num = _G.GetAchievementNumCriteria(id) or 0
			local texts, metas = 0, 0
			for i = 1, num do
				local _, cType, completed, _, _, _, _, assetID = _G.GetAchievementCriteriaInfo(id, i)
				local fs = nil
				if assetID and cType == _G.CRITERIA_TYPE_ACHIEVEMENT then
					metas = metas + 1
					local ok, m = pcall(_G.AchievementButton_GetMeta, metas)
					if ok and m then
						fs = m.label
						if m.icon then WSkin.SquareIcon(m.icon, m) end
						Fade(m.border)
					end
				elseif cType ~= 1 then
					texts = texts + 1
					local ok, c = pcall(_G.AchievementButton_GetCriteria, texts)
					fs = ok and c and c.name
				end
				if fs and fs.SetTextColor then
					if completed then fs:SetTextColor(1, 1, 1) else fs:SetTextColor(0.65, 0.65, 0.65) end
				end
			end
		end)
		HookFn("AchievementObjectives_DisplayProgressiveAchievement", function()
			for i = 1, 18 do
				local mini = _G["AchievementFrameMiniAchievement" .. i]
				if not mini then break end
				Fade(_G["AchievementFrameMiniAchievement" .. i .. "Border"])
				Fade(_G["AchievementFrameMiniAchievement" .. i .. "Shield"])
				local icon = _G["AchievementFrameMiniAchievement" .. i .. "Icon"]
				if icon then WSkin.SquareIcon(icon, mini) end
			end
		end)
		WSkin.HookShow(f, WSkin.Debounce(function()
			if f:IsVisible() then
				SkinAllRows()
				if _G.AchievementFrameSummary then AchWhiteTextsIn(_G.AchievementFrameSummary) end
				RetintPlate()
				WSkin.Restrip("achievements")
				WSkin.UpdateAllTabs()
			end
		end))
	end
end

WSkin.RegisterWindow({
	key = "achievements",
	label = "Achievements",
	description = "The achievement window: categories, rows, progress bars, and search.",
	order = 130,
	addons = { Blizzard_AchievementUI = true },
	elvui = "achievement",
	apply = Skin_Achievements,
})
end

-------------------------------------------------------------------------------
--  Mail (MailFrame + OpenMailFrame)
-------------------------------------------------------------------------------
do
-- Item slot of a mail row / letter: slot art gone, squared icon (no rarity
-- ring, as on retail mail).
local function SkinMailItemButton(b)
	if not b or Forbidden(b) then return end
	local nt = b.GetNormalTexture and b:GetNormalTexture()
	if nt and nt ~= b.Icon then nt:SetAlpha(0) end
	local bn = b:GetName()
	if bn then Fade(_G[bn .. "Slot"]) end
	local icon = b.Icon or b.icon or (bn and (_G[bn .. "IconTexture"] or _G[bn .. "Icon"]))
	if icon then WSkin.SquareIcon(icon, b) end
end

-- Labeled prev / next page button: house arrow block, labels hidden.
local function SkinLabeledPageButton(btn, ch)
	if not btn then return end
	WSkin.PageButton(btn, ch, 13)
	local pd = GetFFD(btn)
	local regions = { btn:GetRegions() }
	for i = 1, #regions do
		local r = regions[i]
		if r and r ~= pd.arrow and r ~= pd.bg and r ~= pd.hover and r.IsObjectType
			and (r:IsObjectType("FontString") or r:IsObjectType("Texture")) then
			r:SetAlpha(0)
		end
	end
end

local function SkinMailRow(i)
	local row = _G["MailItem" .. i]
	if not row or Forbidden(row) then return end
	local d = GetFFD(row)
	if not d.bg then
		WSkin.FadeRegions(row)
		RowBlock(row, { inset = { 0, 2, 0, 7 }, hover = false, color = { Theme.bgR, Theme.bgG, Theme.bgB, Theme.bgA } })
	end
	local sender = _G["MailItem" .. i .. "Sender"]
	if sender then WSkin.White(sender) end
	SkinMailItemButton(_G["MailItem" .. i .. "Button"])
end

local INVOICE_TEXT = { "OpenMailInvoiceItemLabel", "OpenMailInvoicePurchaser", "OpenMailInvoiceSalePrice",
	"OpenMailInvoiceDeposit", "OpenMailInvoiceHouseCut", "OpenMailInvoiceAmountReceived",
	"OpenMailInvoiceNotYetSent", "OpenMailInvoiceMoneyDelay" }

local function WhitenMailText()
	local html = _G.OpenMailBodyText
	if html and html.SetTextColor then
		if html.GetObjectType and html:GetObjectType() == "SimpleHTML" then
			for _, el in ipairs({ "P", "H1", "H2", "H3" }) do pcall(html.SetTextColor, html, el, 1, 1, 1) end
		else
			html:SetTextColor(1, 1, 1)
		end
	end
	for _, n in ipairs({ "OpenMailSubject", "OpenMailSender", "OpenMailSenderName" }) do
		local fs = _G[n]
		if fs and fs.SetTextColor and fs.IsObjectType and fs:IsObjectType("FontString") then WSkin.White(fs) end
	end
	for _, n in ipairs(INVOICE_TEXT) do
		if _G[n] then WSkin.White(_G[n]) end
	end
	local art = _G.OpenMailArithmeticLine
	if art then
		art:SetAlpha(0)
		local d = GetFFD(art)
		if not d.rule and art:GetParent() then
			d.rule = SolidTex(art:GetParent(), "OVERLAY", Theme.brdR, Theme.brdG, Theme.brdB, Theme.brdA)
			d.rule:SetHeight(1)
			d.rule:SetPoint("LEFT", art, "LEFT", 0, 0)
			d.rule:SetPoint("RIGHT", art, "RIGHT", 0, 0)
		end
	end
end

local function SkinOpenMailItems()
	SkinMailItemButton(_G.OpenMailLetterButton)
	SkinMailItemButton(_G.OpenMailMoneyButton)
	for i = 1, 16 do SkinMailItemButton(_G["OpenMailAttachmentButton" .. i]) end
end

local function Skin_OpenMail()
	local f = _G.OpenMailFrame
	if not f then return end
	WSkin.Shell("mail", f)
	WSkin.RemovePortrait(f)
	WSkin.CommonChrome(f, "OpenMailFrame")
	if _G.OpenMailFrameInset then WSkin.Inset(_G.OpenMailFrameInset) end
	FadeG({ "OpenMailFrameBg", "OpenStationeryBackgroundLeft", "OpenStationeryBackgroundRight", "OpenMailHorizontalBarLeft",
		"OpenMailHorizontalBarRight" })
	if _G.OpenMailScrollFrame then
		WSkin.FadeRegions(_G.OpenMailScrollFrame)
		WSkin.Panel(_G.OpenMailScrollFrame, { shade = true })
	end
	WSkin.ButtonsIn(f)
	SkinOpenMailItems()
	WhitenMailText()
end

-- Send-mail attachment: empty-slot art gone, dark slot + border, the item
-- icon (its normal texture) squared on show.
local function SkinSendAttachments()
	for i = 1, (_G.ATTACHMENTS_MAX_SEND or 12) do
		local a = _G["SendMailAttachment" .. i]
		if a and not Forbidden(a) then
			local d = GetFFD(a)
			if not d.sock then
				d.sock = true
				local nt0 = a:GetNormalTexture()
				local keep = nt0 and { [nt0] = true } or nil
				WSkin.FadeRegions(a, keep)
				local bg = SolidTex(a, "BACKGROUND", Theme.bgR, Theme.bgG, Theme.bgB, Theme.bgA, -8)
				bg:SetAllPoints(a)
				d.bg = bg
				WSkin.AddBorder(a)
				local hl = a.GetHighlightTexture and a:GetHighlightTexture()
				if hl then hl:SetTexture(1, 1, 1, 0.1) end
			end
			local nt = a:GetNormalTexture()
			if nt then
				nt:SetAlpha(1)
				nt:SetTexCoord(0.08, 0.92, 0.08, 0.92)
				nt:ClearAllPoints()
				nt:SetPoint("TOPLEFT", 1, -1)
				nt:SetPoint("BOTTOMRIGHT", -1, 1)
			end
		end
	end
end

local function Skin_Mail()
	local f = _G.MailFrame
	if not f then return end
	WSkin.Shell("mail", f)
	WSkin.RemovePortrait(f)
	WSkin.CommonChrome(f, "MailFrame")
	if _G.MailFrameInset then WSkin.Inset(_G.MailFrameInset) end
	FadeG({ "MailFrameBg", "InboxFrameBg" })
	if _G.InboxFrame then
		WSkin.FadeRegions(_G.InboxFrame)
		WSkin.Register(_G.InboxFrame, true)
	end
	for i = 1, (_G.INBOXITEMS_TO_DISPLAY or 7) do SkinMailRow(i) end
	if _G.OpenAllMail then
		WSkin.Button(_G.OpenAllMail)
		WSkin.WhiteButtonLabel(_G.OpenAllMail)
	end
	SkinLabeledPageButton(_G.InboxPrevPageButton, "<")
	SkinLabeledPageButton(_G.InboxNextPageButton, ">")
	for _, n in ipairs({ "InboxCurrentPage", "InboxTitleText", "SendMailTitleText" }) do
		if _G[n] then WSkin.White(_G[n]) end
	end

	-- Send Mail
	local sf = _G.SendMailFrame
	if sf then
		WSkin.FadeRegions(sf)
		WSkin.Register(sf, true)
	end
	FadeG({ "SendStationeryBackgroundLeft", "SendStationeryBackgroundRight", "SendMailHorizontalBarLeft",
		"SendMailHorizontalBarLeft2" })
	for _, n in ipairs({ "SendMailNameEditBox", "SendMailSubjectEditBox", "SendMailMoneyGold", "SendMailMoneySilver", "SendMailMoneyCopper" }) do
		if _G[n] then WSkin.EditBox(_G[n]) end
	end
	if _G.SendMailMoneyInset then WSkin.Inset(_G.SendMailMoneyInset) end
	if _G.SendMailMoneyBg then WSkin.FadeRegions(_G.SendMailMoneyBg) end
	if _G.SendMailScrollFrame then
		WSkin.FadeRegions(_G.SendMailScrollFrame)
		WSkin.Panel(_G.SendMailScrollFrame, { shade = true })
	end
	if _G.SendMailBodyEditBox and _G.SendMailBodyEditBox.SetTextColor then _G.SendMailBodyEditBox:SetTextColor(1, 1, 1) end
	SkinSendAttachments()

	local tabs = TabsNamed("MailFrameTab", 2)
	KeepTabRow(f, tabs)
	WSkin.ButtonsIn(f)
	WSkin.ScrollBarsIn(f)
	Skin_OpenMail()

	local fd = GetFFD(f)
	if not fd.mailHooked then
		fd.mailHooked = true
		HookFn("InboxFrame_Update", function()
			for i = 1, (_G.INBOXITEMS_TO_DISPLAY or 7) do SkinMailRow(i) end
		end)
		HookFn("SendMailFrame_Update", SkinSendAttachments)
		HookFn("OpenMail_Update", function()
			SkinOpenMailItems()
			WhitenMailText()
		end)
		HookFn("OpenMailFrame_UpdateButtonPositions", SkinOpenMailItems)
		WSkin.HookShow(f, WSkin.Debounce(function()
			if f:IsVisible() then
				WSkin.Restrip("mail")
				WSkin.UpdateAllTabs()
			end
		end))
	end
end

WSkin.RegisterWindow({
	key = "mail",
	label = "Mail",
	description = "The mailbox: inbox rows, send mail, open mail, and attachment slots.",
	order = 140,
	elvui = "mail",
	apply = Skin_Mail,
})
end
