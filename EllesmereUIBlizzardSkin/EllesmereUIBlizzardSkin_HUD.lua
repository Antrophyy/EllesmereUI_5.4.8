-------------------------------------------------------------------------------
--  EllesmereUIBlizzardSkin_HUD.lua (5.4.8 port)
--  Blizzard HUD reskins: tooltip status bars, on-screen progress bars
--  ("Reskin Widget Bars") and the extra action button.
--
--  Retail -> 5.4.8 map:
--    Tooltip progress / status bars -> <Tooltip>StatusBarN (GameTooltip_ShowStatusBar)
--    UI widget status bar covers     -> MirrorTimer1-3 (breath / fatigue / feign)
--                                       and WorldStateCaptureBarN (PvP capture bars).
--                                       5.4.8 has no UI widgets and no secret values,
--                                       so the bars are restyled in place (textures only).
--    Extra action button             -> ExtraActionButton1
--    Zone ability button              -> skipped (no ZoneAbilityFrame in 5.4.8)
--    Widget bar minimum size (cog)    -> skipped (it only scaled nameplate widget bars)
--
--  Settings (EllesmereUIBlizzardSkinDB):
--    reskinWidgetBars        nil/true = on (reload-bound, like retail)
--    reskinExtraActionButton true = on (default off, live)
-------------------------------------------------------------------------------
local addonName = ...
local ns = EllesmereUI
local BS = ns.BlizzSkin
local WSkin = ns.WSkin
local GetFFD = WSkin.GetFFD

local FLAT = BS.WHITE

local function ElvPrivate()
	local E = ElvUI and ElvUI[1]
	return E and E.private
end

-- House font on a FontString (Blizzard Skins module font), size kept.
local function HouseFont(fs, white)
	if not fs or not fs.GetFont then
		return
	end
	local path, size, flags = fs:GetFont()
	if type(size) ~= "number" or size <= 0 then
		fs:SetFont(path or STANDARD_TEXT_FONT, 11, flags or "")
	end
	WSkin.Font(fs)
	if white then
		WSkin.White(fs)
	end
end

-- Tiny 1px black outline (not the themed border: heavy on a thin bar).
local function ThinBorder(frame)
	if not frame then
		return
	end
	local d = GetFFD(frame)
	if d.thinBorder then
		return
	end
	d.thinBorder = BS.PP.CreateBorder(frame, 0, 0, 0, 1, 1, "OVERLAY", 7)
end

local function BarFill(bar)
	WSkin.ApplyBarFill(bar)
end

-- Clear every texture of a bar except its fill and our own.
local function StripBarArt(bar, keepFill)
	local owned = GetFFD(bar).owned
	local regions = { bar:GetRegions() }
	for i = 1, #regions do
		local r = regions[i]
		if r and r ~= keepFill and not (owned and owned[r]) and r.IsObjectType
			and r:IsObjectType("Texture") and r:GetDrawLayer() ~= "HIGHLIGHT" then
			r:SetTexture(nil)
			r:SetAlpha(0)
		end
	end
end

-- Trough + thin border + accent fill on a StatusBar.
local function SkinBarCommon(bar, troughR)
	if not bar or BS.Forbidden(bar) or not bar.SetStatusBarTexture then
		return
	end
	bar:SetStatusBarTexture(FLAT)
	local fill = bar:GetStatusBarTexture()
	StripBarArt(bar, fill)
	local d = GetFFD(bar)
	if not d.hudTrough then
		local v = troughR or 0.22
		local trough = BS.SolidTex(bar, "BACKGROUND", v, v, v, 1, -1)
		trough:SetAllPoints(bar)
		d.hudTrough = trough
		d.owned = d.owned or {}
		d.owned[trough] = true
		ThinBorder(bar)
	end
	BarFill(bar)
end

-------------------------------------------------------------------------------
--  Tooltip status bars (TooltipStatusBarTemplate, <Tooltip>StatusBarN).
--  Stands down while ElvUI skins tooltips.
-------------------------------------------------------------------------------
local function ElvTooltips()
	local p = ElvPrivate()
	if not p then
		return false
	end
	if p.tooltip and p.tooltip.enable then
		return true
	end
	return BS.ElvUISkins("tooltip")
end

local function SkinTooltipStatusBar(bar)
	SkinBarCommon(bar)
	local name = bar.GetName and bar:GetName()
	HouseFont(bar.Text or (name and _G[name .. "Text"]), true)
end

if type(_G.GameTooltip_ShowStatusBar) == "function" then
	hooksecurefunc("GameTooltip_ShowStatusBar", function(tt)
		if not tt or not tt.GetName or ElvTooltips() then
			return
		end
		local name = tt:GetName()
		local n = tt.shownStatusBars or 0
		if not name then
			return
		end
		for i = 1, n do
			local bar = _G[name .. "StatusBar" .. i]
			if bar then
				pcall(SkinTooltipStatusBar, bar)
			end
		end
	end)
end

-------------------------------------------------------------------------------
--  On-screen progress bars ("Reskin Widget Bars").
-------------------------------------------------------------------------------
local function WidgetBarsOn()
	return BS.Get("reskinWidgetBars") ~= false
end

-- Mirror timers (breath, fatigue, feign death): MirrorTimerN + Border / Text /
-- StatusBar, and one unnamed BACKGROUND texture behind the bar.
local function SkinMirrorTimer(i)
	local timer = _G["MirrorTimer" .. i]
	local bar = _G["MirrorTimer" .. i .. "StatusBar"]
	if not timer or not bar then
		return
	end
	local d = GetFFD(timer)
	if d.hudSkinned then
		return
	end
	d.hudSkinned = true
	local border = _G["MirrorTimer" .. i .. "Border"]
	if border then
		border:SetTexture(nil)
		border:SetAlpha(0)
	end
	local regions = { timer:GetRegions() }
	for n = 1, #regions do
		local r = regions[n]
		if r and r ~= border and r.IsObjectType and r:IsObjectType("Texture") then
			r:SetAlpha(0)
		end
	end
	SkinBarCommon(bar, 0.10)
	local text = _G["MirrorTimer" .. i .. "Text"]
	if text then
		HouseFont(text, true)
		-- The bar is a child frame and draws above its parent's regions, so
		-- the text moves onto a holder above the bar, centered on it.
		local holder = CreateFrame("Frame", nil, timer)
		holder:SetAllPoints(bar)
		holder:SetFrameLevel(bar:GetFrameLevel() + 3)
		text:SetParent(holder)
		text:ClearAllPoints()
		text:SetPoint("CENTER", bar, "CENTER", 0, 0)
		d.textHolder = holder
	end
end

-- PvP capture bars (WorldStateCaptureBarN): left = Alliance, right = Horde,
-- middle = neutral zone, Indicator = the moving marker. Flat colors, art off.
local CAPTURE_ART = { "LeftLine", "RightLine", "LeftIconHighlight", "RightIconHighlight" }
local function SkinCaptureBar(id)
	local bar = _G["WorldStateCaptureBar" .. id]
	if not bar then
		return
	end
	local d = GetFFD(bar)
	if d.hudSkinned then
		return
	end
	d.hudSkinned = true
	local left = _G["WorldStateCaptureBar" .. id .. "LeftBar"]
	local right = _G["WorldStateCaptureBar" .. id .. "RightBar"]
	local middle = _G["WorldStateCaptureBar" .. id .. "MiddleBar"]
	-- The unnamed full-size frame art (border and faction icons).
	local regions = { bar:GetRegions() }
	for n = 1, #regions do
		local r = regions[n]
		if r and r ~= left and r ~= right and r ~= middle and r.IsObjectType and r:IsObjectType("Texture") then
			r:SetTexture(nil)
			r:SetAlpha(0)
		end
	end
	for _, k in ipairs(CAPTURE_ART) do
		local t = _G["WorldStateCaptureBar" .. id .. k]
		if t then
			t:SetTexture(nil)
			t:SetAlpha(0)
		end
	end
	if left then
		left:SetTexture(FLAT)
		left:SetTexCoord(0, 1, 0, 1)
		left:SetVertexColor(0.0, 0.44, 0.87, 1)
	end
	if right then
		right:SetTexture(FLAT)
		right:SetTexCoord(0, 1, 0, 1)
		right:SetVertexColor(0.77, 0.12, 0.23, 1)
	end
	if middle then
		middle:SetTexture(FLAT)
		middle:SetTexCoord(0, 1, 0, 1)
		middle:SetVertexColor(0.85, 0.85, 0.85, 1)
	end
	-- Trough + thin border around the bar track (LeftBar .. RightBar).
	if left and right then
		local track = CreateFrame("Frame", nil, bar)
		track:SetPoint("TOPLEFT", left, "TOPLEFT", -1, 1)
		track:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 1, -1)
		track:SetFrameLevel(math.max(0, bar:GetFrameLevel()))
		local trough = BS.SolidTex(bar, "BACKGROUND", 0.10, 0.10, 0.10, 1, -1)
		trough:SetAllPoints(track)
		BS.PP.CreateBorder(track, 0, 0, 0, 1, 1, "OVERLAY", 7)
		d.track = track
	end
	-- Indicator: a thin white marker.
	local ind = _G["WorldStateCaptureBar" .. id .. "Indicator"]
	if ind then
		local iregs = { ind:GetRegions() }
		local center = nil
		for n = 1, #iregs do
			local r = iregs[n]
			if r and r.IsObjectType and r:IsObjectType("Texture") then
				local rn = r.GetName and r:GetName()
				if rn then
					-- IndicatorLeft / IndicatorRight arrows.
					r:SetTexture(nil)
					r:SetAlpha(0)
				elseif not center then
					center = r
				end
			end
		end
		if center then
			center:SetTexture(FLAT)
			center:SetTexCoord(0, 1, 0, 1)
			center:SetVertexColor(1, 1, 1, 1)
			center:ClearAllPoints()
			center:SetPoint("TOP", ind, "TOP", 0, -2)
			center:SetPoint("BOTTOM", ind, "BOTTOM", 0, 2)
			center:SetWidth(2)
		end
	end
end

local function SkinAllCaptureBars()
	for id = 1, 10 do
		if _G["WorldStateCaptureBar" .. id] then
			SkinCaptureBar(id)
		end
	end
end

local function MirrorTimersOn()
	if not WidgetBarsOn() then
		return false
	end
	return not BS.ElvUISkins("mirrorTimers")
end

local function CaptureBarsOn()
	if not WidgetBarsOn() then
		return false
	end
	return not BS.ElvUISkins("WorldStateFrame")
end

-- The setting is read once at login (retail: reload-bound); off = nothing installed.
BS.OnLogin(function()
	if MirrorTimersOn() then
		for i = 1, (MIRRORTIMER_NUMTIMERS or 3) do
			pcall(SkinMirrorTimer, i)
		end
	end
	if CaptureBarsOn() then
		pcall(SkinAllCaptureBars)
		local cp = type(ExtendedUI) == "table" and ExtendedUI["CAPTUREPOINT"]
		if type(cp) == "table" and type(cp.create) == "function" then
			hooksecurefunc(cp, "create", function(id)
				pcall(SkinCaptureBar, id)
			end)
		end
	end
end)

-- Bar fill follows the accent / Global Options bar fill color (ApplyBarFill
-- keeps a list of bars it painted; re-apply when settings change).
BS.OnApply(function()
	if MirrorTimersOn() then
		for i = 1, (MIRRORTIMER_NUMTIMERS or 3) do
			local bar = _G["MirrorTimer" .. i .. "StatusBar"]
			local timer = _G["MirrorTimer" .. i]
			if bar and timer and GetFFD(timer).hudSkinned then
				BarFill(bar)
			end
		end
	end
end)

-- Mirror timers recolor their bar per timer type (MirrorTimer_Show sets
-- MirrorTimerColors); keep the accent fill.
if type(_G.MirrorTimer_Show) == "function" then
	hooksecurefunc("MirrorTimer_Show", function()
		if not MirrorTimersOn() then
			return
		end
		for i = 1, (MIRRORTIMER_NUMTIMERS or 3) do
			local timer = _G["MirrorTimer" .. i]
			local bar = _G["MirrorTimer" .. i .. "StatusBar"]
			if timer and bar and GetFFD(timer).hudSkinned then
				BarFill(bar)
			end
		end
	end)
end

-------------------------------------------------------------------------------
--  Extra action button (ExtraActionButton1). A secure action button:
--  textures and texcoords only, no Show / Hide / SetPoint on the button.
--  Stands down while ElvUI action bars style it.
-------------------------------------------------------------------------------
local function ExtraOn()
	if BS.Get("reskinExtraActionButton") ~= true then
		return false
	end
	local p = ElvPrivate()
	if p and p.actionbar and p.actionbar.enable then
		return false
	end
	return true
end

local function StripExtraAction()
	local btn = _G.ExtraActionButton1
	if not btn or BS.Forbidden(btn) then
		return
	end
	if not ExtraOn() then
		return
	end
	local d = GetFFD(btn)
	local style = btn.style
	if style then
		-- Blizzard re-sets this texture per granted ability; remember it so
		-- turning the option off can put it back.
		local tex = style:GetTexture()
		if tex then
			d.styleTex = tex
		end
		style:SetTexture(nil)
		style:SetAlpha(0)
	end
	local icon = btn.icon or _G.ExtraActionButton1Icon
	if icon then
		if not d.iconPoints then
			local pts = {}
			for i = 1, icon:GetNumPoints() do
				pts[i] = { icon:GetPoint(i) }
			end
			d.iconPoints = pts
		end
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
		icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end
	if not d.qBorder then
		WSkin.QualityBorder(btn, icon or btn, 0, 0, 0)
	end
	if d.qBorder then
		d.qBorder:Show()
	end
	d.stripped = true
end

-- Off again (live): put Blizzard's art back.
local function RestoreExtraAction()
	local btn = _G.ExtraActionButton1
	if not btn then
		return
	end
	local d = GetFFD(btn)
	if not d.stripped then
		return
	end
	d.stripped = nil
	if btn.style then
		if d.styleTex then
			btn.style:SetTexture(d.styleTex)
		end
		btn.style:SetAlpha(1)
	end
	if d.qBorder then
		d.qBorder:Hide()
	end
	local icon = btn.icon or _G.ExtraActionButton1Icon
	if icon then
		icon:SetTexCoord(0, 1, 0, 1)
		if d.iconPoints and #d.iconPoints > 0 then
			icon:ClearAllPoints()
			for i = 1, #d.iconPoints do
				local p = d.iconPoints[i]
				icon:SetPoint(p[1], p[2], p[3], p[4], p[5])
			end
		end
	end
end

local eabEv = CreateFrame("Frame")
local eabHooked = false
eabEv:RegisterEvent("PLAYER_LOGIN")
eabEv:RegisterEvent("UPDATE_EXTRA_ACTIONBAR")
eabEv:SetScript("OnEvent", function()
	local btn = _G.ExtraActionButton1
	if btn and not GetFFD(btn).showHook then
		GetFFD(btn).showHook = true
		btn:HookScript("OnShow", StripExtraAction)
	end
	if not eabHooked and type(_G.ExtraActionBar_Update) == "function" then
		eabHooked = true
		hooksecurefunc("ExtraActionBar_Update", StripExtraAction)
	end
	if not ExtraOn() then
		return
	end
	StripExtraAction()
	BS.After(0, StripExtraAction)
	BS.After(0.3, StripExtraAction)
end)

BS.OnApply(function()
	if ExtraOn() then
		StripExtraAction()
	else
		RestoreExtraAction()
	end
end)

-- Defaults (nil = these).
BS.defaults.reskinWidgetBars = true
BS.defaults.reskinExtraActionButton = false

-- For tests / other files.
ns.BlizzSkinHUD = {
	SkinMirrorTimer = SkinMirrorTimer,
	SkinCaptureBar = SkinCaptureBar,
	SkinTooltipStatusBar = SkinTooltipStatusBar,
	StripExtraAction = StripExtraAction,
}
