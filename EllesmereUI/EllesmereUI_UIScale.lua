-- UI Scale (EllesmereUI Global Settings > General > UI Scale, from
-- EllesmereUI_Startup.lua and EllesmereUI_PixelPerfect.lua): the whole game UI
-- uses the scale saved in EllesmereUIDB.ppUIScale (UIParent:SetScale), so it
-- can go below Blizzard's 0.64 minimum, e.g. the pixel-perfect 0.7111 at 1080p.
-- 5.4.8: no GetPhysicalScreenSize (the resolution CVar is used) and no
-- C_Timer. With ElvUI loaded, ElvUI keeps control of the scale.

local addonName, ns = ...

local min, max, abs = math.min, math.max, math.abs

local MIN_SCALE, MAX_SCALE = 0.40, 1.15
local pendingScale

local function DB()
	if type(EllesmereUIDB) ~= "table" then
		EllesmereUIDB = {}
	end
	return EllesmereUIDB
end

local function PhysicalHeight()
	return ns.PhysicalHeight()
end

-- Pixel-perfect scale: 1 UI unit = 1 screen pixel (768 / screen height).
local function PixelBestSize()
	return max(MIN_SCALE, min(768 / PhysicalHeight(), MAX_SCALE))
end

-- Another addon that owns the UI scale (nil = we do).
local function Blocker()
	if IsAddOnLoaded("ElvUI") then
		return "ElvUI"
	end
	return nil
end

local function ApplyNow(scale)
	if InCombatLockdown() then
		-- UIParent cannot be rescaled safely in combat: apply when it ends.
		pendingScale = scale
		return false
	end
	pendingScale = nil
	if abs(UIParent:GetScale() - scale) > 0.0001 then
		UIParent:SetScale(scale)
		-- Pixel sizes (unit frame borders and such) follow the new scale.
		for _, fn in ipairs(ns.applyHooks or {}) do
			pcall(fn)
		end
	end
	return true
end

local function ApplySaved()
	local scale = DB().ppUIScale
	if type(scale) == "number" and not Blocker() then
		ApplyNow(scale)
	end
end

local driver = CreateFrame("Frame")
driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("PLAYER_REGEN_ENABLED")
driver:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= addonName then
			return
		end
		self:UnregisterEvent("ADDON_LOADED")
		local db = DB()
		-- Old saves rounded the pixel-perfect values.
		if db.ppUIScale == 0.53 then
			db.ppUIScale = 0.5333333333
		elseif db.ppUIScale == 0.71 then
			db.ppUIScale = 0.7111111111
		end
		-- Earliest point the saved value exists.
		ApplySaved()
	elseif event == "PLAYER_LOGIN" then
		self:UnregisterEvent("PLAYER_LOGIN")
		ApplySaved()
		-- Blizzard re-applies its CVar scale on these; put ours back.
		self:RegisterEvent("UI_SCALE_CHANGED")
		self:RegisterEvent("DISPLAY_SIZE_CHANGED")
	elseif event == "PLAYER_ENTERING_WORLD" then
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
		local db = DB()
		if db.ppUIScale == nil and not Blocker() then
			-- First run: keep the scale the player already uses.
			db.ppUIScale = max(MIN_SCALE, min(UIParent:GetScale(), MAX_SCALE))
			db.ppUIScaleAuto = false
		end
		ApplySaved()
	elseif event == "UI_SCALE_CHANGED" then
		ApplySaved()
	elseif event == "DISPLAY_SIZE_CHANGED" then
		local db = DB()
		if db.ppUIScaleAuto == true and not Blocker() then
			db.ppUIScale = PixelBestSize()
		end
		ApplySaved()
	elseif event == "PLAYER_REGEN_ENABLED" then
		if pendingScale then
			ApplyNow(DB().ppUIScale or pendingScale)
		end
	end
end)

---------------------------------------------------------------------------
-- API for the settings window
---------------------------------------------------------------------------
ns.UIScaleBlocker = Blocker
ns.UIScalePixelBest = PixelBestSize

ns.GetUIScale = function()
	return DB().ppUIScale or PixelBestSize()
end

-- Stores and applies a new scale. 0.53 and 0.71 snap to the exact
-- pixel-perfect values of 1440p and 1080p (768/1440, 768/1080).
ns.SetUIScale = function(value)
	if abs(value - 0.53) < 0.005 then
		value = 0.5333333333
	elseif abs(value - 0.71) < 0.005 then
		value = 0.7111111111
	end
	value = max(MIN_SCALE, min(value, MAX_SCALE))
	local db = DB()
	db.ppUIScale = value
	db.ppUIScaleAuto = false
	if Blocker() then
		return false
	end
	return ApplyNow(value)
end
