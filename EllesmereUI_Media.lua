-- Bar textures and fonts for the settings dropdowns (Blizzard, ExRT media if
-- ExRT is installed, LibSharedMedia). Shared by all modules.

local ns = EllesmereUI

local tsort, wipe = table.sort, table.wipe

local discoveredBarTextures = {}
local discoveredBarTextureNames = {}
local discoveredFonts = {}
local discoveredFontNames = {}
local EXRT_MEDIA_TEXTURES = {}
for i = 1, 33 do
	EXRT_MEDIA_TEXTURES[i] = "Interface\\AddOns\\ExRT\\media\\bar" .. i .. ".tga"
end
local BLIZZARD_TEXTURES = {
	"Interface\\TargetingFrame\\UI-StatusBar",
	"Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar",
	"Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
}
local EXRT_MEDIA_FONTS = {
	"Interface\\AddOns\\ExRT\\media\\skurri.ttf",
	"Interface\\AddOns\\ExRT\\media\\TaurusNormal.ttf",
	"Interface\\AddOns\\ExRT\\media\\UbuntuMedium.ttf",
	"Interface\\AddOns\\ExRT\\media\\TelluralAlt.ttf",
	"Interface\\AddOns\\ExRT\\media\\Glametrix.otf",
	"Interface\\AddOns\\ExRT\\media\\FiraSansMedium.ttf",
	"Interface\\AddOns\\ExRT\\media\\alphapixels.ttf",
}
local BLIZZARD_FONTS = {
	"Fonts\\ARIALN.TTF",
	"Fonts\\FRIZQT__.TTF",
	"Fonts\\MORPHEUS.TTF",
	"Fonts\\NIM_____.ttf",
	"Fonts\\SKURRI.TTF",
	"Fonts\\FRIZQT___CYR.TTF",
}

local function IsAddOnPresent(name)
	local ok, addonInfoName, _, _, _, _, reason = pcall(GetAddOnInfo, name)
	return ok and addonInfoName and reason ~= "MISSING"
end

-- LibStub is a table with a __call metamethod, not a function.
local function GetLSM()
	if type(LibStub) ~= "table" or type(LibStub.GetLibrary) ~= "function" then
		return nil
	end
	local ok, LSM = pcall(LibStub.GetLibrary, LibStub, "LibSharedMedia-3.0", true)
	if ok and LSM and type(LSM.HashTable) == "function" then
		return LSM
	end
	return nil
end

-- Same file can be written with / or \ and in any case.
local function MediaKey(path)
	return (path:lower():gsub("/", "\\"))
end

local BLIZZARD_FONT_NAMES = {
	["fonts\\arialn.ttf"] = "Arial Narrow",
	["fonts\\frizqt__.ttf"] = "Friz Quadrata",
	["fonts\\morpheus.ttf"] = "Morpheus",
	["fonts\\nim_____.ttf"] = "Nimrod MT",
	["fonts\\skurri.ttf"] = "Skurri",
	["fonts\\frizqt___cyr.ttf"] = "Friz Quadrata (Cyrillic)",
}

local function SortByName(a, b)
	return a.name:lower() < b.name:lower()
end

local function BuildBarTextureList()
	wipe(discoveredBarTextures)
	wipe(discoveredBarTextureNames)

	local function GetFriendlyTextureName(path)
		local exrtBarNum = path:match("Interface\\AddOns\\ExRT\\media\\bar(%d+)%.tga")
		if exrtBarNum then
			return "ExRT Bar " .. exrtBarNum
		end
		if path == "Interface\\TargetingFrame\\UI-StatusBar" then
			return "Blizzard StatusBar"
		elseif path == "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" then
			return "Character Skills Bar"
		elseif path == "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" then
			return "Raid HP Fill"
		end
		return path:match("[^\\/]+$") or path
	end

	local seen = {}
	local function AddTexture(path, name)
		if type(path) ~= "string" or path == "" or seen[MediaKey(path)] then
			return
		end
		seen[MediaKey(path)] = true
		local displayName = name or GetFriendlyTextureName(path)
		discoveredBarTextures[#discoveredBarTextures + 1] = { path = path, name = displayName }
		discoveredBarTextureNames[path] = displayName
	end

	for i = 1, #BLIZZARD_TEXTURES do
		AddTexture(BLIZZARD_TEXTURES[i])
	end
	if IsAddOnPresent("ExRT") then
		for i = 1, #EXRT_MEDIA_TEXTURES do
			AddTexture(EXRT_MEDIA_TEXTURES[i])
		end
	end

	local LSM = GetLSM()
	if LSM then
		local media = LSM:HashTable("statusbar")
		if media then
			local extra = {}
			for key, texture in pairs(media) do
				extra[#extra + 1] = { path = texture, name = key }
			end
			tsort(extra, SortByName)
			for i = 1, #extra do
				AddTexture(extra[i].path, extra[i].name)
			end
		end
	end
end

local function BuildFontList()
	wipe(discoveredFonts)
	wipe(discoveredFontNames)

	local seen = {}
	local function AddFont(path, name)
		if type(path) ~= "string" or path == "" or seen[MediaKey(path)] then
			return
		end
		seen[MediaKey(path)] = true
		local displayName = name or BLIZZARD_FONT_NAMES[MediaKey(path)] or path:match("[^\\/]+$") or path
		discoveredFonts[#discoveredFonts + 1] = { path = path, name = displayName }
		discoveredFontNames[path] = displayName
	end

	AddFont(STANDARD_TEXT_FONT, "Standard")
	for i = 1, #BLIZZARD_FONTS do
		AddFont(BLIZZARD_FONTS[i])
	end
	if IsAddOnPresent("ExRT") then
		for i = 1, #EXRT_MEDIA_FONTS do
			AddFont(EXRT_MEDIA_FONTS[i], "ExRT " .. (EXRT_MEDIA_FONTS[i]:match("[^\\/]+$") or ""))
		end
	end

	local LSM = GetLSM()
	if LSM then
		local media = LSM:HashTable("font")
		if media then
			local extra = {}
			for key, font in pairs(media) do
				extra[#extra + 1] = { path = font, name = key }
			end
			tsort(extra, SortByName)
			for i = 1, #extra do
				AddFont(extra[i].path, extra[i].name)
			end
		end
	end
end

---------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------
ns.GetLSM = GetLSM

ns.GetBarTextures = function()
	BuildBarTextureList()
	return discoveredBarTextures
end

ns.GetFonts = function()
	BuildFontList()
	return discoveredFonts
end

ns.GetBarTextureLabel = function(path)
	return discoveredBarTextureNames[path] or (path and path:match("[^\\/]+$")) or "?"
end

ns.GetFontLabel = function(path)
	return discoveredFontNames[path] or (path and path:match("[^\\/]+$")) or "?"
end

local driver = CreateFrame("Frame")
driver:RegisterEvent("PLAYER_LOGIN")
driver:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_LOGIN")
	-- All addons are loaded now, so all LibSharedMedia media is registered.
	BuildBarTextureList()
	BuildFontList()
	local LSM = GetLSM()
	if LSM and LSM.RegisterCallback then
		-- Media registered later (load on demand addons) is added to the lists too.
		LSM.RegisterCallback(driver, "LibSharedMedia_Registered", function(_, mediaType)
			if mediaType == "statusbar" then
				BuildBarTextureList()
			elseif mediaType == "font" then
				BuildFontList()
			end
			if ns.RefreshSettings then
				ns.RefreshSettings()
			end
		end)
	end
end)
