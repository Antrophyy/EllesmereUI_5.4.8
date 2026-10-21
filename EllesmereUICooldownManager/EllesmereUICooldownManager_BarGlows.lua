-------------------------------------------------------------------------------
--  EllesmereUICooldownManager_BarGlows.lua
--  Bar Glows (retail EllesmereUICdmBarGlows.lua + EllesmereUICdmBarGlowConditions
--  .lua): glow an action bar button or a CDM icon while a buff is up (ACTIVE)
--  or missing (MISSING).
--    specProfiles[spec].barGlows.assignments["<bar>_<button>"] = { entries }
--    specProfiles[spec].barGlows.assignments["cdms_<spellID>"] = { entries }
--      (retail keys CDM icons by Blizzard cooldownID, "cdm_<id>": that viewer
--       ID does not exist here, so this port keys them by the icon's spell)
--    profile.spec[spec].mappings  (the older per-button list, still honoured)
--  Entry (retail keys): spellID, mode, glowStyle, colorMode ("default" /
--  "class" / "custom"), glowColor {r,g,b}, glowAlpha (Blackout opacity),
--  onlyInCombat, stackEnabled / stackThreshold / stackOperator (At Stacks),
--  andMode = "and" + conditions[1] = { spellID, state = nil | "missing" }
--  (a second buff), collapsed (options only).
--  5.4.8: no hero talents (entry.heroTree is ignored, like retail on WoW
--  Forever); aura stacks are plain numbers here, so At Stacks compares in Lua.
-------------------------------------------------------------------------------
local addonName, P = ...
local ns = EllesmereUI
local CDM = P.CDM

local floor = math.floor

local BG = {}
CDM.BarGlows = BG

-- Action bars: retail bar index -> first action slot - 1 (retail BAR_OFFSETS).
-- Retail bars 6-8 do not exist here; Action Bar 9 (page 2) and 10 (page 10)
-- are the 5.4.8 EllesmereUIActionBars extras.
local BAR_OFFSETS = { [1] = 0, [2] = 60, [3] = 48, [4] = 24, [5] = 36, [9] = 12, [10] = 108 }
local BAR_KEYS = { [1] = "MainBar", [2] = "Bar2", [3] = "Bar3", [4] = "Bar4", [5] = "Bar5", [9] = "Bar9", [10] = "Bar10" }
local BLIZZ_PREFIXES = {
	"ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
	"MultiBarRightButton", "MultiBarLeftButton",
}
BG.BAR_ORDER = { 1, 2, 3, 4, 5, 9, 10 }
BG.BAR_KEYS = BAR_KEYS

-- Default glow colour: the CDM icon glows' default (Icons.lua buff glow), so
-- a Bar Glow left on Default looks like every other CDM glow.
BG.DEFAULT_R, BG.DEFAULT_G, BG.DEFAULT_B = 1, 0.82, 0.1
local BLACKOUT = 8

function BG.ActionButton(barIdx, btnIdx)
	local off = BAR_OFFSETS[barIdx]
	if not off then return nil end
	local btn = _G["EABButton" .. (off + btnIdx)]
	if btn then return btn end
	local pre = BLIZZ_PREFIXES[barIdx]
	return pre and _G[pre .. btnIdx] or nil
end

-- Whether an action bar is there to glow on (EllesmereUIActionBars bar, or
-- Blizzard's bars 1-5).
function BG.HasBar(barIdx)
	return BG.ActionButton(barIdx, 1) ~= nil
end

function BG.Data(specKey)
	local sp = CDM.SpecProfile(specKey)
	if type(sp.barGlows) ~= "table" or next(sp.barGlows) == nil then
		sp.barGlows = { enabled = true, selectedBar = "cooldowns", assignments = {} }
	end
	local bg = sp.barGlows
	if type(bg.assignments) ~= "table" then bg.assignments = {} end
	-- Retail live migration: colorMode replaced classColor + "glowColor set".
	if not bg._colorModeMigrated then
		bg._colorModeMigrated = true
		for _, list in pairs(bg.assignments) do
			if type(list) == "table" then
				for _, e in ipairs(list) do
					if not e.colorMode then
						if e.classColor then e.colorMode = "class"
						elseif e.glowColor then e.colorMode = "custom"
						else e.colorMode = "default" end
					end
				end
			end
		end
	end
	return bg
end

-- The CDM icon of a spell (any bar), and its bar.
local function CDMIconBySpell(sid)
	for _, f in pairs(CDM.barFrames) do
		for i = 1, #(f.entries or {}) do
			local icon = f.icons[i]
			local e = icon and icon._entry
			if e and (e.spellID == sid or e.id == sid) then return icon, f.bd end
		end
	end
end
BG.CDMIconBySpell = CDMIconBySpell

-------------------------------------------------------------------------------
--  Buff list for the options pickers (retail GetAllCDMBuffSpells +
--  GetTrackedBarSpells): the buffs of the CDM buff bars (current spec), then
--  the Tracking Bars buffs. { spellID, name, icon, source = "cdm" | "tbb" }
-------------------------------------------------------------------------------
function BG.BuffSpells()
	local cdm, tbb, seen = {}, {}, {}
	for _, bd in ipairs(CDM.Bars()) do
		if CDM.IsPortedBar(bd) and bd.key and CDM.IsBuffBar(bd) then
			local sd = CDM.BarSpellData(bd.key)
			for _, id in ipairs(sd.assignedSpells) do
				local e = CDM.ResolveEntry(bd, id, sd)
				local sid = e and e.spellID
				if sid and sid > 0 and not seen[sid] then
					seen[sid] = true
					cdm[#cdm + 1] = { spellID = sid, name = e.name, icon = e.icon, source = "cdm" }
				end
			end
		end
	end
	local t = CDM.TBB and CDM.TBB.Data and CDM.TBB.Data()
	for _, cfg in ipairs((t and t.bars) or {}) do
		local sid = tonumber(cfg.spellID)
		if sid and sid > 0 and not seen[sid] then
			local name, _, icon = GetSpellInfo(sid)
			if name then
				seen[sid] = true
				tbb[#tbb + 1] = { spellID = sid, name = name, icon = icon, source = "tbb" }
			end
		end
	end
	return cdm, tbb
end

-------------------------------------------------------------------------------
--  Glow colour / start (shared with the options preview)
-------------------------------------------------------------------------------
-- Colour of an entry for a style; nil = the style's own default (Blackout:
-- black fill).
function BG.EntryColor(entry, style)
	if entry.colorMode == "class" or (entry.colorMode == nil and entry.classColor) then
		local _, class = UnitClass("player")
		local c = class and RAID_CLASS_COLORS[class]
		if c then return c.r, c.g, c.b end
	elseif (entry.colorMode == "custom" or entry.colorMode == nil) and type(entry.glowColor) == "table" then
		local c = entry.glowColor
		return c.r or BG.DEFAULT_R, c.g or BG.DEFAULT_G, c.b or BG.DEFAULT_B
	end
	if style == BLACKOUT then return nil end
	return BG.DEFAULT_R, BG.DEFAULT_G, BG.DEFAULT_B
end

-- Pixel Glow thickness: the target's CDM bar, else (action buttons, options
-- previews) the first CDM bar's, so the glow matches the CDM icon glows.
function BG.Thickness(bd)
	if bd and bd.pixelGlowThickness then return bd.pixelGlowThickness end
	for _, b in ipairs(CDM.Bars()) do
		if CDM.IsPortedBar(b) and b.pixelGlowThickness then return b.pixelGlowThickness end
	end
	return 1
end

-- Starts entry's glow on frame o (w x h). bd = the CDM bar for an icon target,
-- nil on action buttons.
function BG.StartOn(o, entry, w, h, bd)
	local style = tonumber(entry.glowStyle) or 1
	local r, g, b = BG.EntryColor(entry, style)
	local G = ns.Glows
	if G and G.StartGlow then
		local opts
		if style == BLACKOUT then
			opts = { alpha = entry.glowAlpha }
		else
			opts = { th = BG.Thickness(bd) }
		end
		G.StartGlow(o, CDM.GlowShared(style), w, r, g, b, opts, h)
	else
		ActionButton_ShowOverlayGlow(o)
	end
end

function BG.StopOn(o)
	local G = ns.Glows
	if G and G.StopGlow then G.StopGlow(o) else ActionButton_HideOverlayGlow(o) end
end

-------------------------------------------------------------------------------
--  Overlays
-------------------------------------------------------------------------------
local overlays = {}   -- [key] = frame
local active = {}     -- [key] = { btn, entry, bd }

local function Overlay(key, a)
	local btn = a.btn
	local o = overlays[key]
	if not o then
		o = CreateFrame("Frame", nil, btn)
		overlays[key] = o
	end
	if o:GetParent() ~= btn then o:SetParent(btn) end
	o:ClearAllPoints()
	o:SetAllPoints(btn)
	local level
	if a.bd and btn.glow then
		-- CDM icon: its glow layer, above the swipe and under the text. Blackout
		-- sits under the swipe (retail: icon+12, under the cooldown widget), so
		-- the cooldown and its text stay readable on the fill.
		local style = tonumber(a.entry.glowStyle) or 1
		if style == BLACKOUT and btn.cd then
			level = btn:GetFrameLevel()
		else
			level = btn.glow:GetFrameLevel()
		end
	else
		-- Action button: under its text host (EAB textHost = +7).
		level = btn:GetFrameLevel() + 5
	end
	o:SetFrameLevel(level)
	o:Show()
	return o
end

local function StopOverlay(o)
	if not o or not o._on then return end
	o._on = nil
	BG.StopOn(o)
end

local function StartOverlay(o, a)
	local entry = a.entry
	local style = tonumber(entry.glowStyle) or 1
	local r, g, b = BG.EntryColor(entry, style)
	local w, h = o:GetWidth(), o:GetHeight()
	local sig = table.concat({ style, tostring(r), tostring(g), tostring(b),
		tostring(entry.glowAlpha), floor(w + 0.5), floor(h + 0.5) }, ":")
	if o._on == sig then return end
	StopOverlay(o)
	o._on = sig
	BG.StartOn(o, entry, w, h, a.bd)
end

-- Rebuilds the overlay list from the saved assignments.
function BG.Refresh()
	if not CDM.ready then return end
	wipe(active)
	local data = BG.Data()
	if data.enabled ~= false and CDM.DB().cdmBars.enabled ~= false then
		for key, list in pairs(data.assignments) do
			local btn, bd
			local sid = key:match("^cdms_(%d+)$")
			if sid then
				btn, bd = CDMIconBySpell(tonumber(sid))
			else
				local b, i = key:match("^(%d+)_(%d+)$")
				if b then btn = BG.ActionButton(tonumber(b), tonumber(i)) end
			end
			if btn and type(list) == "table" then
				for n, entry in ipairs(list) do
					active[key .. "_" .. n] = { btn = btn, entry = entry, bd = bd }
				end
			end
		end
	end
	-- Older per-button mappings (profile.spec[spec].mappings): buff by name.
	local spec = CDM.DB().spec and CDM.DB().spec[CDM.SpecKey()]
	if spec and type(spec.mappings) == "table" then
		for n, m in ipairs(spec.mappings) do
			if m.enabled and m.name and m.name ~= "" and m.name ~= ns.CDM_DEFAULT_MAPPING_NAME then
				local btn = BG.ActionButton(m.actionBar or 1, m.actionButton or 1)
				if btn then
					active["map_" .. n] = { btn = btn, entry = {
						name = m.name, mode = m.mode, glowStyle = m.glowStyle,
						colorMode = "custom", glowColor = m.glowColor,
					} }
				end
			end
		end
	end
	for key, o in pairs(overlays) do
		if not active[key] then
			StopOverlay(o)
			o:Hide()
		end
	end
	BG.Update()
end
ns.CDM_DEFAULT_MAPPING_NAME = "Buff Name (eg: Divine Purpose)"

-- The aura of a spell ID (player buff, else the player's debuff on the
-- target), or of a name for the old mappings.
local function AuraOf(sid, name)
	sid = tonumber(sid)
	if sid and sid > 0 then
		return CDM.FindAura({ spellID = sid, name = GetSpellInfo(sid) })
	end
	if name then
		return CDM.FindAura({ spellID = -1, name = name })
	end
end

local function StackMatch(value, op, threshold)
	if op == "lt" then return value < threshold end
	if op == "lte" then return value <= threshold end
	if op == "eq" then return value == threshold end
	if op == "gt" then return value > threshold end
	return value >= threshold
end

-- The final glow state of an entry (retail UpdateOverlayVisuals +
-- BarGlowCombine, without the hero tree check).
function BG.ShouldGlow(entry, inCombat)
	local aura = AuraOf(entry.spellID, entry.name)
	local missing = (entry.mode or "ACTIVE") == "MISSING"
	local on
	if missing then on = aura == nil else on = aura ~= nil end
	-- And: a second buff active (or missing). Not chosen yet = no condition.
	if on and entry.andMode == "and" then
		local c = type(entry.conditions) == "table" and entry.conditions[1]
		local csid = type(c) == "table" and tonumber(c.spellID)
		if csid and csid > 0 then
			local up = AuraOf(csid) ~= nil
			if c.state == "missing" then on = not up else on = up end
		end
	end
	-- At Stacks (Active mode only). A buff without stacks counts as 1.
	if on and not missing and entry.stackEnabled and aura then
		local n = tonumber(aura.count) or 0
		if n < 1 then n = 1 end
		on = StackMatch(n, entry.stackOperator or "gte", tonumber(entry.stackThreshold) or 2)
	end
	if on and entry.onlyInCombat and not inCombat then on = false end
	return on
end

function BG.Update()
	local inCombat = InCombatLockdown() or UnitAffectingCombat("player")
	-- Global "Show Glows Only in Combat" (retail ns._cdmGlowOOCGate).
	local gated = CDM.DB().cdmBars.glowsOnlyInCombat and not inCombat
	for key, a in pairs(active) do
		local o = Overlay(key, a)
		local on = not gated and BG.ShouldGlow(a.entry, inCombat)
		if on and a.btn:IsVisible() then StartOverlay(o, a) else StopOverlay(o) end
	end
end

-- Rides on the CDM driver (10 / s).
local orig = CDM.UpdateAll
CDM.UpdateAll = function(relayout)
	orig(relayout)
	if CDM.ready and next(active) then BG.Update() end
end
