-------------------------------------------------------------------------------
--  EUI_ResourceBars_Init.lua: saved settings at ADDON_LOADED, the bars at
--  PLAYER_LOGIN, Unlock Mode elements, /erb (opens the settings page).
-------------------------------------------------------------------------------
local addonName, P = ...
local ns = P.ns
local ERB = P.ERB

local init = CreateFrame("Frame")
init:RegisterEvent("ADDON_LOADED")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= addonName then
			return
		end
		ERB:InitDB()
		ERB.RegisterUnlock()
		ERB.RegisterCastUnlock()
		ERB.RegisterTotemUnlock()
	elseif event == "PLAYER_LOGIN" then
		ERB.RegisterBarEvents()
		ERB.RegisterCastEvents()
		ERB:ApplyAll()
	end
end)

SLASH_ERB1 = "/erb"
SlashCmdList.ERB = function()
	if InCombatLockdown() then
		return
	end
	if ns.LoadOptions and ns.LoadOptions() and ns.OpenSettingsModule then
		ns.OpenSettingsModule("resourceBars")
	end
end
