-------------------------------------------------------------------------------
--  EUI_RaidFrames_Init.lua  (5.4.8 port of retail EUI_RaidFrames_Lifecycle
--  OnEnable)
--
--  PLAYER_LOGIN: builds the raid headers, the party header and their buttons
--  (all out of combat, in the login window so a /reload in combat has them
--  too), sets ERF.started and runs ERF:ApplyAll(). The settings window calls
--  ERF:ApplyAll() after every change; the order-10 refresh here re-lays the
--  frames, then every button re-runs RF.RelayoutButton. /erf opens the
--  settings at Raid Frames.
-------------------------------------------------------------------------------
local addonName, RF = ...
local ns = EllesmereUI
local ERF = RF.ERF

local function SafeCall(fn, ...)
	if not fn then
		return
	end
	local ok, err = pcall(fn, ...)
	if not ok then
		geterrorhandler()(err)
	end
end

-- Order 10: headers / layout / sizes, then every button's layout.
RF.OnApply(function()
	if not RF._containerFrame then
		return
	end
	SafeCall(RF.ApplyFrameStrata)
	if InCombatLockdown() then
		-- Scales follow now (texts and icons are not protected); the secure
		-- part waits for combat end.
		SafeCall(RF.ReloadRaidFrames)
		SafeCall(RF.ReloadPartyFrames)
	else
		SafeCall(RF.FullLayout)
	end
	if RF.ForEachButton and RF.RelayoutButton then
		RF.ForEachButton(function(btn)
			SafeCall(RF.RelayoutButton, btn)
		end)
	end
	if RF.IsPreviewActive and RF.IsPreviewActive() and RF.RefreshPreview then
		SafeCall(RF.RefreshPreview)
	end
end, 10)

-- First-install positions (retail OnEnable capture): raid at 200 px from the
-- left edge, party at 400 px, both vertically centered.
local function DefaultPositions(p)
	if not p.unlockPos then
		p.unlockPos = { point = "LEFT", relPoint = "LEFT", x = 200, y = 0 }
	end
	if not p.partyUnlockPos then
		p.partyUnlockPos = { point = "LEFT", relPoint = "LEFT", x = 400, y = 0 }
	end
end

local function Start()
	if ERF.started then
		return
	end
	if not ERF.db then
		ERF:InitDB()
	end
	local p = RF.Profile()
	if not p then
		return
	end
	DefaultPositions(p)
	RF._NormalizePartySyncSections()
	SafeCall(RF._NormalizeTierOffsetAnchors)
	if RF.CC_Init then
		SafeCall(RF.CC_Init)
	end
	-- Headers + buttons (out of combat: the login window allows secure
	-- creation even after a /reload in combat).
	SafeCall(RF.CreateHeaders)
	SafeCall(RF._CreatePartyHeader)
	SafeCall(RF.ApplyFrameStrata)
	SafeCall(RF._RFSyncVisDrivers)
	SafeCall(RF._SuppressBlizzRaid)
	ERF.started = true
	ERF:ApplyAll()
	-- Unlock mode elements after the first layout (container sizes known).
	RF.After(0, function()
		SafeCall(RF.RegisterWithUnlockMode)
	end)
end
RF.Start = Start

do
	local f = CreateFrame("Frame")
	f:RegisterEvent("PLAYER_LOGIN")
	f:SetScript("OnEvent", function(self)
		self:UnregisterEvent("PLAYER_LOGIN")
		Start()
	end)
end

-------------------------------------------------------------------------------
--  Preview life cycle: the preview hides whenever the settings window
--  closes (hooked on EllesmereUI._mainFrame's OnHide once it exists; the
--  options module's onLeave may also call RF.HidePreview).
-------------------------------------------------------------------------------
local function HookOptionsWindow()
	local mf = ns and ns._mainFrame
	if not mf or RF._optionsHooked then
		return mf ~= nil
	end
	RF._optionsHooked = true
	mf:HookScript("OnHide", function()
		if RF.HidePreview then
			SafeCall(RF.HidePreview)
		end
		if RF.HidePartyPreview then
			SafeCall(RF.HidePartyPreview)
		end
		if RF.HideSizePreview then
			SafeCall(RF.HideSizePreview)
		end
	end)
	return true
end
RF._HookOptionsWindow = HookOptionsWindow

do
	local f = CreateFrame("Frame")
	f:RegisterEvent("ADDON_LOADED")
	f:SetScript("OnEvent", function(self, _, name)
		if name == "EllesmereUIOptions" or HookOptionsWindow() then
			HookOptionsWindow()
		end
		if RF._optionsHooked then
			self:UnregisterEvent("ADDON_LOADED")
		end
	end)
end

-------------------------------------------------------------------------------
--  /erf
-------------------------------------------------------------------------------
SLASH_EUIRAIDFRAMES1 = "/erf"
if SlashCmdList then
	SlashCmdList.EUIRAIDFRAMES = function()
		if InCombatLockdown() then
			if ns.Print then
				ns.Print("Cannot open settings during combat.")
			end
			return
		end
		if ns.OpenSettingsModule then
			ns.OpenSettingsModule("raidFrames")
		elseif ns.LoadOptions then
			ns.LoadOptions()
			if ns.OpenSettingsModule then
				ns.OpenSettingsModule("raidFrames")
			end
		end
		HookOptionsWindow()
	end
end
