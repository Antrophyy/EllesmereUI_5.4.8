-------------------------------------------------------------------------------
--  EllesmereUIResourceBars.lua  (5.4.8 port of the EllesmereUI Resource Bars,
--  retail 9.3.8)
--
--  The defaults (the retail keys and values), the saved settings
--  (EllesmereUIResourceBarsDB.profile, like the retail profile), the first-run
--  seed with the retail "Naowh" look, the Mists of Pandaria resource map and
--  the helpers the other files share: timers (5.4.8 has no C_Timer), pixel
--  borders, fonts, bar textures, colors and the Visibility checklist.
--
--  Files: this one, EUI_ResourceBars_Bars.lua (health, power and class
--  resource bars), EUI_ResourceBars_CastBar.lua (player cast bar and GCD bar)
--  and EUI_ResourceBars_TotemBar.lua (totem bar).
--
--  Not in 5.4.8, left out: Blizzard / Classic styles, textured borders,
--  Blizzard class art and atlases, the Cooldown Manager anchors, Evoker and
--  Demon Hunter resources, the retail-only trackers (Ironfur, Ignore Pain,
--  Icicles, Tip of the Spear, Whirlwind, Sweeping Strikes), buff / spender
--  colors (they need the Cooldown Viewer), empowered casts, housing and
--  dragonriding conditions, the WoW Forever extras (swing timer, druid mana,
--  call totems, mana spark).
--  Mists resources: Holy Power, combo points (on the target), Chi, Shadow
--  Orbs, Soul Shards, Burning Embers (partial pips), Demonic Fury and Eclipse
--  (bars), Arcane Charges, Maelstrom Weapon and Lightning Shield charges
--  (aura stacks), Death Knight runes (with rune type colors), Focus for
--  Beast Mastery / Marksmanship hunters.
-------------------------------------------------------------------------------
local addonName, P = ...
local ns = EllesmereUI

local ERB = {}
ns.ERB = ERB
P.ERB = ERB
P.ns = ns

local floor, abs, max, min = math.floor, math.abs, math.max, math.min
local format = string.format

P.MEDIA = "Interface\\AddOns\\" .. addonName .. "\\media\\"
P.WHITE = "Interface\\Buttons\\WHITE8X8"

-------------------------------------------------------------------------------
--  Defaults (EllesmereUI 9.3.8 Resource Bars defaults, same keys; keys of
--  features 5.4.8 cannot do are left out)
-------------------------------------------------------------------------------
local CUSTOM_FILL_DEFAULT = { 1, 1, 1 }

local function BarDefaults(extra)
	local t = {
		smoothBars = false,
		borderSize = 1,
		borderR = 0, borderG = 0, borderB = 0, borderA = 1,
		borderTexture = "solid",
		darkTheme = false,
		customColored = false,
		fillR = CUSTOM_FILL_DEFAULT[1], fillG = CUSTOM_FILL_DEFAULT[2], fillB = CUSTOM_FILL_DEFAULT[3], fillA = 1,
		fillOpacity = 100,
		bgR = 0x11 / 255, bgG = 0x11 / 255, bgB = 0x11 / 255, bgA = 0.75,
		textXOffset = 0,
		textYOffset = 0,
		textAnchor = "CENTER",
		textCustomColored = true,
		textFillR = 1, textFillG = 1, textFillB = 1, textFillA = 1,
		gradientEnabled = false,
		gradientR = 0.20, gradientG = 0.20, gradientB = 0.80, gradientA = 1,
		gradientDir = "HORIZONTAL",
		offsetX = 0,
		barAlpha = 1.0,
		oocFadeEnabled = false,
		oocAlpha = 0.5,
		visibility = "always",
		visOnlyInstances = false,
		visHideMounted = false,
		visHideNoTarget = false,
		visHideNoEnemy = false,
		orientation = "HORIZONTAL",
		thresholdEnabled = false,
		thresholdPct = 30,
		thresholdR = 1.0, thresholdG = 0.2, thresholdB = 0.2, thresholdA = 1,
		thresholdSpecs = {},
		thresholdTextInstead = false,
		multiBandEnabled = false,
		bandMode = "percent",
		bandReverse = false,
		bands = {},
		hashEnabled = false,
		hashValues = "",
		hashMode = "percent",
		hashWidth = 1,
		hashColorR = 1, hashColorG = 1, hashColorB = 1, hashColorA = 0.7,
	}
	for k, v in pairs(extra) do
		t[k] = v
	end
	return t
end

local DEFAULTS = {
	profile = {
		health = BarDefaults({
			enabled = false,
			width = 214,
			height = 16,
			borderSize = 0,
			textFormat = "none",
			textSize = 11,
			offsetY = -64,
		}),
		primary = BarDefaults({
			enabled = true,
			width = 214,
			height = 14,
			textFormat = "perpp",
			showPercent = true,
			textSize = 10,
			offsetY = -54,
			thresholdPartialOnly = false,
			expandIfNoResource = false,
			shiftElementsIfNoPower = "None",
		}),
		secondary = {
			enabled = true,
			smoothBars = false,
			pipWidth = 214,
			pipHeight = 20,
			pipSpacing = 1,
			pipOrientation = "HORIZONTAL",
			borderSize = 1,
			borderR = 0, borderG = 0, borderB = 0, borderA = 1,
			borderTexture = "solid",
			pipBgOnPips = false,
			raiseLevel = false,
			darkTheme = false,
			classColored = true,
			resourceColored = false,
			fillR = 0.95, fillG = 0.90, fillB = 0.60, fillA = 1,
			fillOpacity = 100,
			darkenPartialPips = true,
			bgR = 1, bgG = 1, bgB = 1, bgA = 0.1,
			showText = true,
			showTextOnlyIfNoPower = false,
			showPercent = false,
			showMaxStacks = true,
			textSize = 11,
			textR = 1, textG = 1, textB = 1,
			textXOffset = 0,
			textYOffset = 0,
			textAnchor = "CENTER",
			barBgR = 0, barBgG = 0, barBgB = 0, barBgA = 0.5,
			gapColorEnabled = false,
			gapR = 0, gapG = 0, gapB = 0, gapA = 1,
			barAlpha = 1.0,
			thresholdEnabled = false,
			thresholdCount = 3,
			thresholdPartialOnly = false,
			thresholdReverse = false,
			thresholdR = 0x0c / 255, thresholdG = 0xd2 / 255, thresholdB = 0x9d / 255, thresholdA = 1,
			tickValues = "",
			thresholdSpecs = {},
			thresholdTextInstead = false,
			multiBandEnabled = false,
			bandMode = "percent",
			bandReverse = false,
			bands = {},
			runesSimple = false,
			runesCustomRecharge = false,
			runesRechargeR = 0.5, runesRechargeG = 0.5, runesRechargeB = 0.5, runesRechargeA = 1,
			-- 5.4.8: Blood / Unholy / Frost / Death runes in their own colors.
			runesByType = true,
			hunterFocusAsPower = false,
			hidePowerIfResource = false,
			visibility = "always",
			visOnlyInstances = false,
			visHideMounted = false,
			visHideNoTarget = false,
			visHideNoEnemy = false,
			oocFadeEnabled = false,
			oocAlpha = 0.5,
			offsetX = 0,
			offsetY = -38,
			shiftElementsIfNoResource = "None",
		},
		castBar = {
			enabled = true,
			alwaysShow = false,
			showIcon = true,
			iconOnRight = false,
			showIconDivider = false,
			iconSize = 0,
			iconOffsetX = 0,
			iconOffsetY = 0,
			width = 220,
			height = 20,
			anchorX = 0,
			anchorY = -54,
			classColored = false,
			fillR = 0.898, fillG = 0.729, fillB = 0.267, fillA = 1,
			fillOpacity = 100,
			gradientEnabled = false,
			gradientR = 0.20, gradientG = 0.20, gradientB = 0.80, gradientA = 1,
			gradientDir = "HORIZONTAL",
			texture = "none",
			showSpark = true,
			borderSize = 1,
			borderR = 0, borderG = 0, borderB = 0, borderA = 1,
			borderTexture = "solid",
			bgR = 0, bgG = 0, bgB = 0, bgA = 0.7,
			showTimer = true,
			timerSize = 11,
			timerX = 0,
			timerY = 0,
			timerSide = "right",
			timerR = 1, timerG = 1, timerB = 1, timerA = 1,
			showSpellText = true,
			spellTextSize = 11,
			spellTextX = 0,
			spellTextY = 0,
			spellTextSide = "left",
			spellTextR = 1, spellTextG = 1, spellTextB = 1, spellTextA = 1,
			showChannelTicks = true,
			showTickMarks = true,
			tickMarksR = 1.0, tickMarksG = 1.0, tickMarksB = 1.0, tickMarksA = 0.7,
			showLastTick = false,
			lastTickR = 1.0, lastTickG = 0.82, lastTickB = 0.0, lastTickA = 0.95,
			showGCDBoundary = false,
			gcdBoundaryR = 1.0, gcdBoundaryG = 0.82, gcdBoundaryB = 0.0, gcdBoundaryA = 0.95,
			outOfRangeGray = false,
			showTotalDuration = false,
			latencyEnabled = false,
			latencyShowText = false,
			latencyR = 0.835, latencyG = 0.290, latencyB = 0.290, latencyA = 1.0,
		},
		gcdBar = {
			enabled = false,
			width = 220,
			height = 12,
			anchorX = 0,
			anchorY = -78,
			orientation = "HORIZONTAL",
			classColored = false,
			fillR = 0.267, fillG = 0.729, fillB = 0.898, fillA = 1,
			gradientEnabled = false,
			gradientR = 0.20, gradientG = 0.20, gradientB = 0.80, gradientA = 1,
			gradientDir = "HORIZONTAL",
			texture = "none",
			showSpark = false,
			depleteFill = false,
			borderSize = 1,
			borderR = 0, borderG = 0, borderB = 0, borderA = 1,
			borderTexture = "solid",
			bgR = 0, bgG = 0, bgB = 0, bgA = 0.7,
			frameStrata = "MEDIUM",
			instanceOnly = false,
			instantOnly = false,
			alwaysShow = false,
		},
		totemBar = {
			iconSize = 30,
			spacing = 2,
			showTimer = true,
			timerSize = 11,
			orientation = "HORIZONTAL",
			borderSize = 1,
			borderR = 0, borderG = 0, borderB = 0, borderA = 1,
			borderTexture = "solid",
			enabledClasses = nil,
		},
		general = {
			anchorX = 0,
			anchorY = -100,
			orientation = "HORIZONTAL",
			barTexture = "none",
			frameStrata = "MEDIUM",
		},
	},
}
ERB.DEFAULTS = DEFAULTS

-------------------------------------------------------------------------------
--  First run: the retail EllesmereUI "Naowh" profile (EllesmereUIDB.profiles.
--  Naowh.addons.EllesmereUIResourceBars on the retail client; retail keeps
--  only the values that differ from the defaults). Retail places the bars with
--  Unlock Mode anchors on the Cooldown Manager, which 5.4.8 does not have: the
--  same stack (cast bar on the class resource on the power bar) is placed
--  between the player and target frames instead.
-------------------------------------------------------------------------------
local NAOWH_SEED = {
	general = { barTexture = "sm:NaowhGradient", frameStrata = "MEDIUM" },
	health = { bgR = 0, bgG = 0, bgB = 0, bgA = 0.7, fillR = 0, fillB = 0.6 },
	primary = {
		shiftElementsIfNoPower = "Down",
		textFormat = "smart",
		bgR = 0, bgG = 0, bgB = 0, bgA = 0.7,
		gradientR = 0.32500136792653, gradientG = 0.79749742050896, gradientB = 1,
		textYOffset = 4,
		showPercent = false,
		textSize = 14,
		height = 8,
		width = 386,
		smoothBars = true,
		unlockPos = { point = "CENTER", relPoint = "CENTER", x = 0, y = -262 },
		thresholdSpecs = {
			{ thresholdEnabled = false, thresholdR = 1, thresholdG = 0.2, thresholdB = 0.2, thresholdA = 1,
			  thresholdPct = 30, specIDs = { 262 } },
			{ thresholdEnabled = true, thresholdR = 1, thresholdG = 0.2, thresholdB = 0.2, thresholdA = 1,
			  thresholdPct = 28, specIDs = { 250 }, multiBandEnabled = true, bandMode = "value", bandReverse = false,
			  bands = { { to = 34, r = 1, g = 0.36470588235294, b = 0.36470588235294, a = 1 } },
			  thresholdPartialOnly = true, thresholdTextInstead = true },
			{ thresholdEnabled = true, thresholdR = 1, thresholdG = 0.2, thresholdB = 0.2, thresholdA = 1,
			  thresholdPct = 34, specIDs = { 251 }, multiBandEnabled = true,
			  bands = { { to = 34, r = 1, g = 0.36470588235294, b = 0.36470588235294, a = 1 } },
			  thresholdPartialOnly = true, thresholdTextInstead = true },
			{ thresholdEnabled = true, thresholdR = 1, thresholdG = 0.2, thresholdB = 0.2, thresholdA = 1,
			  thresholdPct = 29, specIDs = { 252 }, multiBandEnabled = true,
			  bands = { { to = 29, r = 1, g = 0.36470588235294, b = 0.36470588235294, a = 1 } },
			  thresholdPartialOnly = true, thresholdTextInstead = true },
			{ thresholdEnabled = true, thresholdR = 1, thresholdG = 0.36470588235294, thresholdB = 0.36470588235294,
			  thresholdA = 1, thresholdPct = 20, specIDs = { 270, 257, 105, 65, 264, 256 }, thresholdPartialOnly = true },
			{ thresholdEnabled = true, thresholdR = 1, thresholdG = 0.2, thresholdB = 0.2, thresholdA = 1,
			  thresholdPct = 30, specIDs = { 103 }, multiBandEnabled = true,
			  bands = { { to = 49, r = 1, g = 0.36470588235294, b = 0.36470588235294, a = 1 } },
			  thresholdPartialOnly = true },
		},
	},
	secondary = {
		thresholdR = 0.047058823529412, thresholdG = 0.82352941176471, thresholdB = 0.6156862745098,
		runesRechargeR = 0.85000008165838, runesRechargeG = 0.85000008165838, runesRechargeB = 0.85000008165838,
		runesCustomRecharge = true,
		pipSpacing = 0,
		hunterFocusAsPower = true,
		pipHeight = 8,
		pipWidth = 386,
		barBgA = 0.7,
		bgA = 0,
		shiftElementsIfNoResource = "Down",
		showText = false,
		resourceColored = true,
		smoothBars = true,
		unlockPos = { point = "CENTER", relPoint = "CENTER", x = 0, y = -255 },
		thresholdSpecs = {
			{ thresholdEnabled = false, specIDs = { 258 }, thresholdR = 0.047058823529412, thresholdG = 0.82352941176471,
			  thresholdB = 0.6156862745098, thresholdA = 1, thresholdCount = 3, hashValues = "44", hashWidth = 2,
			  hashColorR = 1, hashColorG = 1, hashColorB = 1, hashColorA = 1, thresholdPartialOnly = false },
			{ thresholdEnabled = true, specIDs = { 251 }, thresholdR = 0.31372549019608, thresholdG = 0.78823529411765,
			  thresholdB = 1, thresholdA = 1, thresholdCount = 1, hashValues = "", hashWidth = 4,
			  hashColorR = 1, hashColorG = 1, hashColorB = 1, hashColorA = 0.7, thresholdPartialOnly = false },
			{ thresholdEnabled = true, specIDs = { 252 }, thresholdR = 0.53630957548096, thresholdG = 1,
			  thresholdB = 0.26500134836875, thresholdA = 1, thresholdCount = 1, hashValues = "", hashWidth = 1,
			  hashColorR = 1, hashColorG = 1, hashColorB = 1, hashColorA = 0.7, thresholdPartialOnly = false },
			{ thresholdEnabled = true, specIDs = { 269 }, thresholdR = 0.52075159388466, thresholdG = 1,
			  thresholdB = 0.32500136792653, thresholdA = 1, thresholdCount = 6, hashValues = "", hashWidth = 1,
			  hashColorR = 1, hashColorG = 1, hashColorB = 1, hashColorA = 0.7, thresholdPartialOnly = false },
			{ thresholdEnabled = true, specIDs = { 259 }, thresholdR = 1, thresholdG = 0.60392156862745,
			  thresholdB = 0.18823529411765, thresholdA = 1, thresholdCount = 5, hashValues = "", hashWidth = 1,
			  hashColorR = 1, hashColorG = 1, hashColorB = 1, hashColorA = 0.7, thresholdPartialOnly = false },
			{ thresholdEnabled = true, specIDs = { 260 }, thresholdR = 1, thresholdG = 0.60392156862745,
			  thresholdB = 0.18823529411765, thresholdA = 1, thresholdCount = 6, hashValues = "", hashWidth = 1,
			  hashColorR = 1, hashColorG = 1, hashColorB = 1, hashColorA = 0.7, thresholdPartialOnly = false,
			  multiBandEnabled = false,
			  bands = { { to = 3, r = 0.047058823529412, g = 0.82352941176471, b = 0.6156862745098, a = 1 } } },
			{ thresholdEnabled = true, specIDs = { 261 }, thresholdR = 1, thresholdG = 0.60392156862745,
			  thresholdB = 0.18823529411765, thresholdA = 1, thresholdCount = 6, hashValues = "", hashWidth = 1,
			  hashColorR = 1, hashColorG = 1, hashColorB = 1, hashColorA = 0.7, thresholdPartialOnly = false },
			{ thresholdEnabled = true, specIDs = { 263 }, thresholdR = 0.58110101504507, thresholdG = 1,
			  thresholdB = 0.41000006649643, thresholdA = 1, thresholdCount = 8, hashValues = "", hashWidth = 1,
			  hashColorR = 1, hashColorG = 1, hashColorB = 1, hashColorA = 0.7, thresholdPartialOnly = false },
		},
	},
	castBar = {
		gradientEnabled = true,
		gradientR = 1, gradientG = 0.92330164780809, gradientB = 0.41000050235537,
		showSpark = false,
		timerY = 5,
		timerX = 2,
		texture = "sm:NaowhGradient",
		fillR = 1, fillG = 0.58399912003526, fillB = 0.19999935038385,
		timerSize = 14,
		showIcon = false,
		spellTextSize = 14,
		height = 12,
		spellTextX = -2,
		spellTextY = 5,
		width = 386,
		unlockPos = { point = "CENTER", relPoint = "CENTER", x = 0, y = -244 },
	},
	totemBar = {
		iconSize = 42,
		spacing = 1,
		orientation = "VERTICAL",
		timerSize = 14,
		unlockPos = { point = "CENTER", relPoint = "CENTER", x = -727, y = -501 },
		enabledClasses = {
			HUNTER = true, WARRIOR = true, PALADIN = true, MAGE = true, PRIEST = true, DEATHKNIGHT = true,
			WARLOCK = true, ROGUE = true, DRUID = true, MONK = true, SHAMAN = true,
		},
	},
}
ERB.NAOWH_SEED = NAOWH_SEED

-------------------------------------------------------------------------------
--  Saved settings
-------------------------------------------------------------------------------
local function DeepCopy(v)
	if type(v) ~= "table" then
		return v
	end
	local t = {}
	for k, x in pairs(v) do
		t[k] = DeepCopy(x)
	end
	return t
end
P.DeepCopy = DeepCopy

local function NewProfile(seed)
	local profile = DeepCopy(DEFAULTS.profile)
	if seed then
		for section, values in pairs(seed) do
			profile[section] = profile[section] or {}
			for k, v in pairs(values) do
				profile[section][k] = DeepCopy(v)
			end
		end
		profile.seeded = "Naowh"
	end
	return profile
end

function ERB:InitDB()
	if type(EllesmereUIResourceBarsDB) ~= "table" then
		EllesmereUIResourceBarsDB = {}
	end
	local sv = EllesmereUIResourceBarsDB
	if type(sv.profile) ~= "table" then
		sv.profile = NewProfile(NAOWH_SEED)
	else
		ns.CopyDefaults(DEFAULTS.profile, sv.profile)
	end
	sv.version = 1
	self.db = {
		sv = sv,
		profile = sv.profile,
		ResetProfile = function(db)
			db.sv.profile = NewProfile(nil)
			db.profile = db.sv.profile
		end,
	}
end

function P.Profile()
	return ERB.db and ERB.db.profile
end

-------------------------------------------------------------------------------
--  Timers (5.4.8 has no C_Timer): After, NewTimer, NewTicker (handles with
--  :Cancel()), all on one OnUpdate.
-------------------------------------------------------------------------------
do
	local tasks = {}
	local driver = CreateFrame("Frame")
	driver:Hide()
	local handle = {}
	handle.__index = handle
	handle.Cancel = function(self)
		self.cancelled = true
	end
	driver:SetScript("OnUpdate", function(self)
		local now = GetTime()
		local i = 1
		while i <= #tasks do
			local t = tasks[i]
			if t.cancelled then
				table.remove(tasks, i)
			elseif now >= t.at then
				if t.interval then
					t.at = now + t.interval
					i = i + 1
				else
					table.remove(tasks, i)
				end
				local ok, err = pcall(t.fn, t)
				if not ok then
					geterrorhandler()(err)
				end
			else
				i = i + 1
			end
		end
		if #tasks == 0 then
			self:Hide()
		end
	end)
	local function Add(t)
		setmetatable(t, handle)
		tasks[#tasks + 1] = t
		driver:Show()
		return t
	end
	function P.After(delay, fn)
		Add({ at = GetTime() + (delay or 0), fn = fn })
	end
	function P.NewTicker(interval, fn)
		return Add({ at = GetTime() + interval, interval = interval, fn = fn })
	end
end

-- Run after combat (protected work requested in combat), keyed.
do
	local pending = {}
	local f = CreateFrame("Frame")
	f:RegisterEvent("PLAYER_REGEN_ENABLED")
	f:SetScript("OnEvent", function()
		local list = pending
		pending = {}
		for _, fn in pairs(list) do
			fn()
		end
	end)
	function P.AfterCombat(key, fn)
		pending[key] = fn
	end
end

-------------------------------------------------------------------------------
--  Pixels and borders
-------------------------------------------------------------------------------
-- One physical pixel in the units of `frame`.
function P.PixelFor(frame)
	local h = ns.PhysicalHeight and ns.PhysicalHeight() or 1080
	return 768 / h / ((frame and frame:GetEffectiveScale()) or UIParent:GetEffectiveScale())
end

function P.Snap(v, frame)
	local px = P.PixelFor(frame)
	return floor(v / px + 0.5) * px
end

-- Four edge textures (the EllesmereUI "solid" pixel border), drawn inside the host.
function P.CreateEdges(parent, host, layer, sub)
	local e = { host = host or parent }
	for i = 1, 4 do
		e[i] = parent:CreateTexture(nil, layer or "OVERLAY", nil, sub or 2)
		e[i]:SetTexture(1, 1, 1, 1)
	end
	return e
end

-- sizePx: border size in physical pixels (retail Border Size).
function P.LayoutEdges(e, sizePx, r, g, b, a)
	local host = e.host
	if not sizePx or sizePx <= 0 then
		for i = 1, 4 do e[i]:Hide() end
		e.size = 0
		return
	end
	local size = sizePx * P.PixelFor(host)
	e.size = size
	e[1]:ClearAllPoints()
	e[1]:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
	e[1]:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, 0)
	e[1]:SetHeight(size)
	e[2]:ClearAllPoints()
	e[2]:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 0, 0)
	e[2]:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
	e[2]:SetHeight(size)
	e[3]:ClearAllPoints()
	e[3]:SetPoint("TOPLEFT", e[1], "BOTTOMLEFT")
	e[3]:SetPoint("BOTTOMLEFT", e[2], "TOPLEFT")
	e[3]:SetWidth(size)
	e[4]:ClearAllPoints()
	e[4]:SetPoint("TOPRIGHT", e[1], "BOTTOMRIGHT")
	e[4]:SetPoint("BOTTOMRIGHT", e[2], "TOPRIGHT")
	e[4]:SetWidth(size)
	for i = 1, 4 do
		e[i]:SetVertexColor(r or 0, g or 0, b or 0, a or 1)
		e[i]:Show()
	end
end

-- Border frame over a host: its own level so the edges draw over the fill.
function P.CreateBorder(host, levelOffset)
	local f = CreateFrame("Frame", nil, host)
	f:SetAllPoints(host)
	f:SetFrameLevel(host:GetFrameLevel() + (levelOffset or 2))
	f.edges = P.CreateEdges(f, f, "OVERLAY", 7)
	f.Apply = function(self, sizePx, r, g, b, a)
		P.LayoutEdges(self.edges, sizePx, r, g, b, a)
	end
	return f
end

-------------------------------------------------------------------------------
--  Fonts (Global Settings > Fonts, module key "resourceBars")
-------------------------------------------------------------------------------
function P.FontPath()
	return (ns.GetFontPath and ns.GetFontPath("resourceBars")) or ns.FONT or "Fonts\\FRIZQT__.TTF"
end

function P.SetFont(fs, size)
	size = size or 11
	if ns.ApplyModuleFont then
		ns.ApplyModuleFont(fs, size, "resourceBars")
	else
		fs:SetFont(P.FontPath(), size, "OUTLINE")
	end
end

-- New FontString with a font set (5.4.8 errors on SetText without one).
function P.NewText(parent, size, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	P.SetFont(fs, size or 11)
	fs:SetWordWrap(false)
	return fs
end

-------------------------------------------------------------------------------
--  Bar textures ("none" = flat, a retail EllesmereUI texture key, or
--  "sm:<name>" = a LibSharedMedia status bar)
-------------------------------------------------------------------------------
ERB.BAR_TEXTURE_ORDER = {
	"none", "melli", "atrocity", "fade", "fade-right", "thin-line-top", "thin-line-bottom",
	"beautiful", "plating", "divide", "glass", "gradient-lr", "gradient-rl", "gradient-bt", "gradient-tb",
	"matte", "sheer", "pixels-fill", "pixels-dark", "pixels-bg", "blinkii-diamonds", "kringel-window",
}
ERB.BAR_TEXTURE_NAMES = {
	none = "None", melli = "Melli (ElvUI)", beautiful = "Beautiful", plating = "Plating", atrocity = "Atrocity",
	divide = "Divide", glass = "Glass", ["fade-right"] = "Fade Right", ["thin-line-top"] = "Thin Line Top",
	["thin-line-bottom"] = "Thin Line Bottom", fade = "Fade", ["gradient-lr"] = "Gradient Right",
	["gradient-rl"] = "Gradient Left", ["gradient-bt"] = "Gradient Up", ["gradient-tb"] = "Gradient Down",
	matte = "Matte", sheer = "Sheer", ["pixels-fill"] = "Pixels Fill", ["pixels-dark"] = "Pixels Dark",
	["pixels-bg"] = "Pixels Background", ["blinkii-diamonds"] = "Blinkii Diamonds", ["kringel-window"] = "Kringel Window",
}

local function LSM()
	return LibStub and LibStub("LibSharedMedia-3.0", true)
end

function P.TexturePath(key)
	if not key or key == "none" or key == "" then
		return P.WHITE
	end
	if key:sub(1, 3) == "sm:" then
		local lsm = LSM()
		return (lsm and lsm:Fetch("statusbar", key:sub(4), true)) or P.WHITE
	end
	if ERB.BAR_TEXTURE_NAMES[key] then
		return P.MEDIA .. "textures\\" .. key
	end
	return P.WHITE
end
ERB.TexturePath = P.TexturePath

function ERB.TextureLabel(key)
	if key and key:sub(1, 3) == "sm:" then
		return key:sub(4)
	end
	return ERB.BAR_TEXTURE_NAMES[key or "none"] or "None"
end

function ERB.TextureItems()
	local items = {}
	for _, key in ipairs(ERB.BAR_TEXTURE_ORDER) do
		items[#items + 1] = { name = ERB.BAR_TEXTURE_NAMES[key], value = key }
	end
	local lsm = LSM()
	if lsm then
		local list = lsm:List("statusbar")
		for i = 1, #list do
			items[#items + 1] = { name = list[i], value = "sm:" .. list[i] }
		end
	end
	return items
end

-- Absorb overlay styles (retail ABSORB_STYLE_TEX, Health Bar Absorb Style).
ERB.ABSORB_STYLE_ORDER = {
	"none", "striped", "stripedReversed", "stripedThick", "stripedThickR", "clean", "blizzard",
	"largeStripes", "largeStripesR", "pixelsShield", "pixelsShieldEdge", "pixelsShieldFill",
}
ERB.HEAL_ABSORB_STYLE_ORDER = {
	"none", "striped", "stripedReversed", "stripedThick", "stripedThickR", "clean", "blizzard",
	"largeOutlinedStripes", "largeOutlinedStripesR", "largeStripes", "largeStripesR", "pixelsShield",
}
ERB.ABSORB_STYLE_NAMES = {
	none = "None", striped = "Striped", stripedReversed = "Striped Reversed", stripedThick = "Striped Thick",
	stripedThickR = "Striped Thick Reversed", clean = "Clean (Flat)", blizzard = "Blizzard",
	largeOutlinedStripes = "Large Outlined Stripes", largeOutlinedStripesR = "Large Outlined Stripes R",
	largeStripes = "Large Stripes", largeStripesR = "Large Stripes R", pixelsShield = "Pixels Shield",
	pixelsShieldEdge = "Pixels Shield Edge", pixelsShieldFill = "Pixels Shield Fill",
}
local ABSORB_FILES = {
	striped = "striped3", stripedReversed = "striped-5-reversed", stripedThick = "striped-thick",
	stripedThickR = "striped-thick-r", blizzard = "blizzard", largeOutlinedStripes = "large-habsorb-left",
	largeOutlinedStripesR = "large-habsorb-right", largeStripes = "large-absorb-left",
	largeStripesR = "large-absorb-right", pixelsShield = "pixels-shield", pixelsShieldEdge = "pixels-shield-edge",
	pixelsShieldFill = "pixels-shield-fill",
}
ERB.ABSORB_TILED = {
	stripedReversed = true, stripedThick = true, stripedThickR = true, largeStripes = true, largeStripesR = true,
	largeOutlinedStripes = true, largeOutlinedStripesR = true, pixelsShieldFill = true,
}

function ERB.AbsorbTexture(style)
	if style == "clean" then
		return P.WHITE
	end
	local file = style and ABSORB_FILES[style]
	if file then
		return P.MEDIA .. "shields\\" .. file
	end
	return P.TexturePath(style)
end

-------------------------------------------------------------------------------
--  Colors (EllesmereUI default palettes: Global Settings > Colors is not
--  ported, so the defaults are used)
-------------------------------------------------------------------------------
local DEFAULT_ACCENT = { 12 / 255, 210 / 255, 157 / 255 }

function P.Accent()
	if ns.ResolveAccent then
		local r, g, b = ns.ResolveAccent()
		if r then
			return r, g, b
		end
	end
	return DEFAULT_ACCENT[1], DEFAULT_ACCENT[2], DEFAULT_ACCENT[3]
end

ERB.CLASS_COLORS = {
	DEATHKNIGHT = { 0.77, 0.12, 0.23 }, DRUID = { 1.00, 0.49, 0.04 }, HUNTER = { 0.67, 0.83, 0.45 },
	MAGE = { 0.25, 0.78, 0.92 }, MONK = { 0.00, 1.00, 0.60 }, PALADIN = { 0.96, 0.55, 0.73 },
	PRIEST = { 1, 1, 1 }, ROGUE = { 1.00, 0.96, 0.41 }, SHAMAN = { 0.00, 0.44, 0.87 },
	WARLOCK = { 0.53, 0.53, 0.93 }, WARRIOR = { 0.78, 0.61, 0.43 },
}

-- Power colors by power token (retail DEFAULT_POWER_COLORS + the Mists powers).
ERB.POWER_COLORS = {
	MANA = { 0, 0.55, 1 }, RAGE = { 0.9, 0.15, 0.15 }, FOCUS = { 0xDD / 255, 0x92 / 255, 0x37 / 255 },
	ENERGY = { 1, 0.96, 0.41 }, RUNIC_POWER = { 0xC4 / 255, 0x1F / 255, 0x3B / 255 },
	DEMONIC_FURY = { 0xA3 / 255, 0x30 / 255, 0xC9 / 255 }, ECLIPSE = { 0xFF / 255, 0x7D / 255, 0x0A / 255 },
}

-- Class resource pip colors (retail DEFAULT_CLASS_RESOURCE_COLORS + the Mists resources).
ERB.RESOURCE_COLORS = {
	COMBO = { 1.0, 0.9608, 0.4118 },
	RUNES = { 0.0, 0.8196, 1.0 },
	SOUL_SHARDS = { 0.5059, 0.3412, 0.8431 },
	HOLY_POWER = { 0.949, 0.902, 0.6 },
	ARCANE_CHARGES = { 0.7176, 0.4902, 0.8118 },
	CHI = { 0.0, 1.0, 0.6 },
	MAELSTROM_WEAPON = { 0.0, 0.4392, 0.8706 },
	LIGHTNING_SHIELD = { 0.0, 0.4392, 0.8706 },
	SHADOW_ORBS = { 0.5, 0.2, 0.8 },
	BURNING_EMBERS = { 0.95, 0.45, 0.1 },
}

-- Death Knight rune types (GetRuneType: 1 blood, 2 unholy, 3 frost, 4 death).
ERB.RUNE_TYPE_COLORS = {
	{ 0.85, 0.15, 0.15 },
	{ 0.25, 0.75, 0.2 },
	{ 0.25, 0.65, 1 },
	{ 0.75, 0.35, 0.95 },
}

-- Eclipse sides (balance druid).
ERB.ECLIPSE_COLORS = { lunar = { 0.3, 0.52, 0.9 }, solar = { 0.95, 0.75, 0.25 } }

-- Dark Mode fill / background (retail Dark Mode palette defaults).
ERB.DARK_FILL = { 0x11 / 255, 0x11 / 255, 0x11 / 255 }
ERB.DARK_BG = { 0x4f / 255, 0x4f / 255, 0x4f / 255 }

function ERB.ClassColor(class)
	class = class or select(2, UnitClass("player"))
	-- Global Settings > Colors (EllesmereUI_Colors.lua): custom + darken.
	if ns.GetClassColor and class and ERB.CLASS_COLORS[class] then
		local cc = ns.GetClassColor(class)
		return cc.r, cc.g, cc.b
	end
	local c = class and ERB.CLASS_COLORS[class]
	if c then
		return c[1], c[2], c[3]
	end
	return 1, 1, 1
end

function ERB.PowerColor(token)
	-- Global Settings > Colors (EllesmereUI_Colors.lua): custom + darken.
	local pc = ns.GetPowerColor and token and ns.GetPowerColor(token)
	if pc then
		return pc.r, pc.g, pc.b
	end
	local c = token and ERB.POWER_COLORS[token]
	if c then
		return c[1], c[2], c[3]
	end
	local blizz = token and PowerBarColor and PowerBarColor[token]
	if blizz and blizz.r then
		return blizz.r, blizz.g, blizz.b
	end
	return ERB.ClassColor()
end

function P.Hex(r, g, b)
	return format("%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

-------------------------------------------------------------------------------
--  Numbers (Blizzard AbbreviateNumbers look: 950, 9.5K, 95K, 9.5M)
-------------------------------------------------------------------------------
function P.Abbrev(v)
	v = v or 0
	local a = abs(v)
	local s
	if a >= 1e9 then
		s = format("%.1fB", v / 1e9)
	elseif a >= 1e7 then
		s = format("%dM", floor(v / 1e6))
	elseif a >= 1e6 then
		s = format("%.1fM", v / 1e6)
	elseif a >= 1e4 then
		s = format("%dK", floor(v / 1e3))
	elseif a >= 1e3 then
		s = format("%.1fK", v / 1e3)
	else
		s = tostring(floor(v + 0.5))
	end
	return (s:gsub("%.0([KMB])", "%1"))
end

-------------------------------------------------------------------------------
--  Specializations (5.4.8 has the retail spec IDs)
-------------------------------------------------------------------------------
function P.SpecID()
	local idx = GetSpecialization and GetSpecialization()
	if not idx then
		return nil
	end
	return (GetSpecializationInfo(idx))
end

-- Smart power text: percent for healers / mana specs, numbers for the rest
-- (retail EUI_IsSmartPowerPercent, by the power the bar shows).
function ERB.IsSmartPowerPercent(powerType)
	local _, cls = UnitClass("player")
	if cls == "DRUID" or cls == "MONK" then
		return powerType == SPELL_POWER_MANA
	end
	if cls == "PRIEST" or cls == "SHAMAN" then
		return true
	end
	if cls == "PALADIN" then
		local spec = GetSpecialization()
		return spec == 1 or spec == 2
	end
	if cls == "MAGE" then
		return GetSpecialization() == 1
	end
	return false
end

-------------------------------------------------------------------------------
--  Mists of Pandaria resource map
-------------------------------------------------------------------------------
local POWER_TOKENS = {
	[0] = "MANA", [1] = "RAGE", [2] = "FOCUS", [3] = "ENERGY", [6] = "RUNIC_POWER",
}
ERB.POWER_TOKENS = POWER_TOKENS

local MOONKIN_FORM_ID = MOONKIN_FORM or 31
local CAT_FORM_ID = CAT_FORM or 1

-- Power type of the Power Bar, or nil (Beast Mastery / Marksmanship hunters
-- show Focus as the class resource unless "Focus as Power Bar" is on).
function ERB.GetPrimaryPowerType()
	local _, class = UnitClass("player")
	local p = P.Profile()
	if class == "HUNTER" then
		local spec = GetSpecialization()
		if (spec == 1 or spec == 2) and not (p and p.secondary and p.secondary.hunterFocusAsPower) then
			return nil
		end
		return SPELL_POWER_FOCUS
	end
	if class == "DRUID" then
		local ov = p and p.primary and p.primary.powerTypeOverride
		local sid = P.SpecID()
		if ov and sid and ov[sid] then
			return SPELL_POWER_MANA
		end
	end
	local pt = UnitPowerType("player")
	if pt == nil or not POWER_TOKENS[pt] then
		return SPELL_POWER_MANA
	end
	return pt
end

function ERB.PowerToken(pt)
	return POWER_TOKENS[pt] or "MANA"
end

local ARCANE_CHARGE_SPELL = 36032
local MAELSTROM_WEAPON_SPELL = 53817
local LIGHTNING_SHIELD_SPELL = 324

-- Class resource of the player right now: { power = key, max = n, type =
-- "points" | "bar" | "runes" | "custom", frac = partial pips }, or nil.
function ERB.GetSecondaryResource()
	local _, class = UnitClass("player")
	local spec = GetSpecialization()
	local form = GetShapeshiftFormID()
	if class == "PALADIN" then
		local mx = UnitPowerMax("player", SPELL_POWER_HOLY_POWER)
		return { power = "HOLY_POWER", pt = SPELL_POWER_HOLY_POWER, max = (mx and mx > 0) and mx or 3, type = "points" }
	elseif class == "ROGUE" or (class == "DRUID" and form == CAT_FORM_ID) then
		return { power = "COMBO", max = MAX_COMBO_POINTS or 5, type = "points", onTarget = true }
	elseif class == "DRUID" and spec == 1 and (form == nil or form == 0 or form == MOONKIN_FORM_ID) then
		return { power = "ECLIPSE", max = 100, type = "bar" }
	elseif class == "MONK" then
		local mx = UnitPowerMax("player", SPELL_POWER_CHI)
		return { power = "CHI", pt = SPELL_POWER_CHI, max = (mx and mx > 0) and mx or 4, type = "points" }
	elseif class == "PRIEST" and spec == 3 then
		local mx = UnitPowerMax("player", SPELL_POWER_SHADOW_ORBS)
		return { power = "SHADOW_ORBS", pt = SPELL_POWER_SHADOW_ORBS, max = (mx and mx > 0) and mx or 3, type = "points" }
	elseif class == "WARLOCK" and spec == 1 then
		local mx = UnitPowerMax("player", SPELL_POWER_SOUL_SHARDS)
		return { power = "SOUL_SHARDS", pt = SPELL_POWER_SOUL_SHARDS, max = (mx and mx > 0) and mx or 3, type = "points" }
	elseif class == "WARLOCK" and spec == 2 then
		local mx = UnitPowerMax("player", SPELL_POWER_DEMONIC_FURY)
		return { power = "DEMONIC_FURY", pt = SPELL_POWER_DEMONIC_FURY, max = (mx and mx > 0) and mx or 1000, type = "bar" }
	elseif class == "WARLOCK" and spec == 3 then
		local per = MAX_POWER_PER_EMBER or 10
		local mx = UnitPowerMax("player", SPELL_POWER_BURNING_EMBERS, true)
		return { power = "BURNING_EMBERS", pt = SPELL_POWER_BURNING_EMBERS, max = max(1, floor((mx or 30) / per)),
			type = "points", frac = true }
	elseif class == "DEATHKNIGHT" then
		return { power = "RUNES", max = 6, type = "runes" }
	elseif class == "MAGE" and spec == 1 then
		return { power = "ARCANE_CHARGES", max = 4, type = "custom", aura = ARCANE_CHARGE_SPELL, harmful = true }
	elseif class == "SHAMAN" and spec == 2 then
		return { power = "MAELSTROM_WEAPON", max = 5, type = "custom", aura = MAELSTROM_WEAPON_SPELL }
	elseif class == "SHAMAN" and spec == 1 then
		-- Lightning Shield charges (Fulmination at 7 with Rolling Thunder).
		return { power = "LIGHTNING_SHIELD", max = 7, type = "custom", aura = LIGHTNING_SHIELD_SPELL, minStacks = 1 }
	elseif class == "HUNTER" and (spec == 1 or spec == 2) then
		local p = P.Profile()
		if p and p.secondary and p.secondary.hunterFocusAsPower then
			return nil
		end
		local mx = UnitPowerMax("player", SPELL_POWER_FOCUS)
		return { power = "FOCUS_BAR", pt = SPELL_POWER_FOCUS, max = (mx and mx > 0) and mx or 100, type = "bar" }
	end
	return nil
end

-- Current value of a class resource (whole points; partial for frac resources).
function ERB.ReadSecondary(res)
	if not res then
		return 0
	end
	local key = res.power
	if key == "COMBO" then
		return GetComboPoints(UnitHasVehicleUI("player") and "vehicle" or "player", "target") or 0
	elseif res.aura then
		local name = GetSpellInfo(res.aura)
		if not name then
			return 0
		end
		local _, _, _, count = UnitAura("player", name, nil, res.harmful and "HARMFUL" or "HELPFUL")
		count = count or 0
		if res.minStacks and count > 0 and count < res.minStacks then
			count = res.minStacks
		end
		return min(count, res.max)
	elseif key == "BURNING_EMBERS" then
		local per = MAX_POWER_PER_EMBER or 10
		return (UnitPower("player", SPELL_POWER_BURNING_EMBERS, true) or 0) / per
	elseif key == "ECLIPSE" then
		return UnitPower("player", SPELL_POWER_ECLIPSE) or 0
	elseif res.pt then
		return UnitPower("player", res.pt) or 0
	end
	return 0
end

-- Fill color of a class resource with "Class Resource Color" on.
function ERB.ResolveSecondaryResourceColor(key)
	-- Global Settings > Colors (EllesmereUI_Colors.lua): custom + darken.
	local rc = ns.GetClassResourceColor and ns.MISTS_RESOURCE_KEYS and ns.MISTS_RESOURCE_KEYS[key]
		and ns.GetClassResourceColor(key)
	if rc then
		return rc.r, rc.g, rc.b
	end
	local c = ERB.RESOURCE_COLORS[key]
	if c then
		return c[1], c[2], c[3]
	end
	if key == "FOCUS_BAR" then
		return ERB.PowerColor("FOCUS")
	elseif key == "DEMONIC_FURY" or key == "ECLIPSE" then
		return ERB.PowerColor(key)
	end
	return nil
end

-- Bar-type class resources per spec (Focus, Demonic Fury, Eclipse): their
-- threshold entries use values and hash lines instead of counts.
ERB.BAR_TYPE_SPECS = { [253] = true, [254] = true, [266] = true, [102] = true }

-------------------------------------------------------------------------------
--  Per-spec threshold entries (retail ResolveThresholdSpecEntry): a spec
--  match wins over All Specs (specID 0); talent gates are not used on 5.4.8.
-------------------------------------------------------------------------------
function ERB.ResolveThresholdSpecEntry(cfg)
	local entries = cfg and cfg.thresholdSpecs
	if not entries or #entries == 0 then
		return nil
	end
	local specID = P.SpecID()
	local all
	for _, entry in ipairs(entries) do
		if entry.specIDs then
			for _, sid in ipairs(entry.specIDs) do
				if specID and sid == specID then
					return entry
				end
				if sid == 0 then
					all = all or entry
				end
			end
		end
	end
	return all
end

-- Bands of an entry (falls back to the bar's own): enabled, bands, mode, reverse.
function ERB.ResolveBandConfig(cfg, entry)
	local enabled, bands, mode, reverse
	if entry then
		enabled = entry.multiBandEnabled
		if enabled == nil then enabled = cfg.multiBandEnabled end
		bands = (entry.bands and #entry.bands > 0) and entry.bands or cfg.bands
		mode = entry.bandMode or cfg.bandMode or "percent"
		reverse = entry.bandReverse
		if reverse == nil then reverse = cfg.bandReverse end
	else
		enabled = cfg.multiBandEnabled
		bands = cfg.bands
		mode = cfg.bandMode or "percent"
		reverse = cfg.bandReverse
	end
	if not enabled or not bands or #bands == 0 then
		return false
	end
	return true, bands, mode, reverse and true or false
end

-- Band for a value: "up to" bands (value <= to) or "from" bands (value >= to).
-- Returns nil outside every band (the base color).
function ERB.FindBand(bands, value, reverse)
	if not bands or #bands == 0 then
		return nil
	end
	if reverse then
		for i = #bands, 1, -1 do
			if value >= (bands[i].to or 0) then
				return bands[i]
			end
		end
		return nil
	end
	for i = 1, #bands do
		if value <= (bands[i].to or 0) then
			return bands[i]
		end
	end
	return nil
end

-------------------------------------------------------------------------------
--  Visibility checklist (retail visibility key + visOnlyInstances ...): the
--  Never / Always / Mouseover base, Match All / Any, Show / Hide lanes (the
--  same lanes as the Minimap and Action Bars ports).
-------------------------------------------------------------------------------
local function InCombat()
	return (InCombatLockdown() or UnitAffectingCombat("player")) and true or false
end
P.InCombat = InCombat

ERB.VIS_AXES = {
	{ key = "in_combat", label = "In Combat", show = "in_combat", hide = "hide_in_combat", test = InCombat },
	{ key = "out_of_combat", label = "Out of Combat", show = "out_of_combat", hide = "hide_out_of_combat",
		test = function() return not InCombat() end },
	{ key = "in_raid", label = "In Raid Group", show = "in_raid", hide = "hide_in_raid",
		test = function() return IsInRaid() and true or false end },
	{ key = "in_party", label = "In Party", show = "in_party", hide = "hide_in_party",
		test = function() return (IsInGroup() and not IsInRaid()) and true or false end },
	{ key = "solo", label = "Solo", show = "solo", hide = "hide_solo",
		test = function() return not IsInGroup() end },
	{ key = "instances", label = "Instances", show = "visOnlyInstances", hide = "visHideInstances",
		test = function() local inside = IsInInstance() return inside and true or false end },
	{ key = "mounted", label = "Mounted", show = "visOnlyMounted", hide = "visHideMounted",
		test = function() return IsMounted() and true or false end },
	{ key = "target", label = "Target", show = "visHideNoTarget", hide = "visHideWithTarget",
		test = function() return UnitExists("target") and true or false end },
	{ key = "enemy", label = "Enemy Target", show = "visHideNoEnemy", hide = "visHideWithEnemy",
		test = function() return (UnitExists("target") and UnitCanAttack("player", "target")) and true or false end },
	{ key = "resting", label = "Resting", show = "visOnlyResting", hide = "visHideResting",
		test = function() return IsResting() and true or false end },
}

-- Retail single-mode values that are lanes here.
local LEGACY_VIS = {
	combat = "in_combat", in_combat = "in_combat", out_of_combat = "out_of_combat",
	in_raid = "in_raid", in_party = "in_party", solo = "solo",
}

function ERB.VisFlag(s, key)
	if key:match("^vis") then
		return s[key] and true or false
	end
	local modes = s.visibilityModes
	if modes and modes[key] then
		return true
	end
	local vis = s.visibility
	if vis and LEGACY_VIS[vis] == key then
		return true
	end
	return false
end

function ERB.SetVisFlag(s, key, on)
	if key:match("^vis") then
		s[key] = on and true or false
		return
	end
	s.visibilityModes = s.visibilityModes or {}
	s.visibilityModes[key] = on and true or nil
end

function ERB.VisBase(s)
	local vis = s and s.visibility or "always"
	if vis == "never" then
		return "never"
	elseif vis == "mouseover" then
		return "mouseover"
	end
	return "always"
end

function ERB.SetVisBase(s, mode)
	local old = s.visibility
	if old and LEGACY_VIS[old] then
		ERB.SetVisFlag(s, LEGACY_VIS[old], true)
	end
	s.visibility = mode
end

-- Retail "target" (hostile target) single mode.
local function LegacyTarget(s)
	return s.visibility == "target"
end

-- true = shown, false = hidden, "mouseover" = shown while hovered.
function ERB.EvalVisibility(s)
	if not s then
		return true
	end
	local base = ERB.VisBase(s)
	if base == "never" then
		return false
	end
	if LegacyTarget(s) and not (UnitExists("target") and UnitCanAttack("player", "target")) then
		return false
	end
	local anyShow, allOk, anyOk = false, true, false
	for _, axis in ipairs(ERB.VIS_AXES) do
		local hideOn = ERB.VisFlag(s, axis.hide)
		local showOn = ERB.VisFlag(s, axis.show)
		if hideOn or showOn then
			local now = axis.test()
			if hideOn and now then
				return false
			end
			if showOn then
				anyShow = true
				if now then
					anyOk = true
				else
					allOk = false
				end
			end
		end
	end
	if anyShow then
		if s.visibilityMatch == "any" then
			if not anyOk then
				return false
			end
		elseif not allOk then
			return false
		end
	end
	if base == "mouseover" then
		return "mouseover"
	end
	return true
end

-- Effective alpha: Fade Out of Combat, else the bar opacity.
function ERB.ResolveBarAlpha(cfg)
	if cfg and cfg.oocFadeEnabled and not InCombat() then
		return cfg.oocAlpha or 0.5
	end
	return (cfg and cfg.barAlpha) or 1
end

-------------------------------------------------------------------------------
--  Apply hooks: the settings and the UI scale changes re-apply everything.
-------------------------------------------------------------------------------
P.applyFns = {}
function P.OnApply(fn)
	P.applyFns[#P.applyFns + 1] = fn
end

function ERB:ApplyAll()
	if not self.db then
		return
	end
	for i = 1, #P.applyFns do
		local ok, err = pcall(P.applyFns[i])
		if not ok then
			geterrorhandler()(err)
		end
	end
end

function ERB:Reset()
	if not self.db then
		return
	end
	self.db:ResetProfile()
	self:ApplyAll()
end

tinsert(ns.applyHooks, function()
	ERB:ApplyAll()
end)
