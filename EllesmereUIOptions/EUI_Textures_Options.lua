-- Global Settings > Textures (EllesmereUI EUI_Textures_Options.lua).
-- Registers nothing: EUI__General_Options.lua adds the tab and calls
-- ns.GSO_BuildTexturesPage(p).
--
-- Like retail, every control is a WRITE-THROUGH MIRROR of a module's own
-- texture row: same saved key, same value format, same side writes (absorb
-- opacity re-seeds). There is no separate texture setting. Settings that
-- live per bar / per element elsewhere are link rows (Open Settings).
-- One section per loaded module (retail cards, roster order).
--
-- Left out: modules this port does not have or whose texture rows retail
-- only (Cooldown Manager tracking bars, Mythic+ timer bars, Quality of Life
-- movement alert / cursor rings, Dragonriding bar, Damage Meters, Raid
-- Frames while it is being ported), the Unit Frames Cast Bar Texture row
-- (5.4.8 unit frame cast bars use the unit's bar texture), and the retail
-- "Blizzard" cast bar atlas entry.

local ns = EllesmereUI

local function Loaded(folder)
	return IsAddOnLoaded(folder) and true or false
end

local function LabelOf(items, value)
	for _, it in ipairs(items) do
		if it.value == value then
			return it.name
		end
	end
	if type(value) == "string" and value:sub(1, 3) == "sm:" then
		return value:sub(4)
	end
	return tostring(value or "")
end

local function LSM()
	return LibStub and LibStub("LibSharedMedia-3.0", true)
end

-- Link row: opens the module page that holds the per-element setting.
local function LinkRow(p, label, moduleKey)
	p:Button(label, "These settings are kept per element on the module's own page.", "Open Settings", function()
		if ns.OpenSettingsModule then
			ns.OpenSettingsModule(moduleKey)
		end
	end)
end

---------------------------------------------------------------------------
-- Unit Frames
---------------------------------------------------------------------------
local function SectionUnitFrames(p)
	local UF = ns.UF
	if not (UF and UF.db and UF.BarTextureItems) then return end
	p:Section("Unit Frames")
	local TEX_OPTS = { texturePreview = true, previewPath = function(v) return UF.BarTexturePath(v) end }
	local ABS_OPTS = { texturePreview = true, previewPath = function(v) return UF.AbsorbTexture(v) end }
	local UNIT_LABEL = { player = "Player", target = "Target", focus = "Focus" }
	local function S(u) return UF.db[u] end
	local function BarTex(u)
		p:Dropdown(UNIT_LABEL[u] .. " Bar Texture", "Texture of the health, power and cast bars.",
			function() return UF.BarTextureItems(false) end,
			function() return (S(u) and S(u).healthBarTexture) or UF.db.healthBarTexture or "none" end,
			function() return UF.BarTextureLabel((S(u) and S(u).healthBarTexture) or UF.db.healthBarTexture or "none") end,
			function(v) if S(u) then S(u).healthBarTexture = v end end,
			TEX_OPTS)
	end
	local function Absorb(u)
		p:Dropdown(UNIT_LABEL[u] .. " Absorb Style", nil,
			function() return UF.AbsorbItems(UF.ABSORB_STYLE_ORDER) end,
			function() return (S(u) and S(u).showPlayerAbsorb) or "none" end,
			function()
				local v = (S(u) and S(u).showPlayerAbsorb) or "none"
				return UF.ABSORB_STYLE_NAMES[v] or v:gsub("^sm:", "")
			end,
			function(v)
				local s = S(u); if not s then return end
				s.absorbOpacity = (v == "clean") and 30 or 90
				s.showPlayerAbsorb = v
			end, ABS_OPTS)
	end
	local function HealAbsorb(u)
		p:Dropdown(UNIT_LABEL[u] .. " Heal Absorb Style", nil,
			function() return UF.AbsorbItems(UF.HEAL_ABSORB_STYLE_ORDER) end,
			function() return (S(u) and S(u).healAbsorbStyle) or "clean" end,
			function()
				local v = (S(u) and S(u).healAbsorbStyle) or "clean"
				return UF.ABSORB_STYLE_NAMES[v] or v:gsub("^sm:", "")
			end,
			function(v)
				local s = S(u); if not s then return end
				s.healAbsorbOpacity = (v == "clean") and 50 or 75
				s.healAbsorbStyle = v
			end, ABS_OPTS)
	end
	BarTex("player"); BarTex("target")
	BarTex("focus"); Absorb("player")
	Absorb("target"); Absorb("focus")
	HealAbsorb("player"); HealAbsorb("target")
	HealAbsorb("focus"); p:Blank()
	LinkRow(p, "Pet, Target-of-Target & Boss Bar Textures", "unitFrames")
	LinkRow(p, "Frame, Power & Aura Border Styles", "unitFrames")
end

---------------------------------------------------------------------------
-- Nameplates
---------------------------------------------------------------------------
local function SectionNameplates(p)
	local ENP = ns.ENP
	if not (ENP and ENP.db and ENP.TextureItems) then return end
	p:Section("Nameplates")
	local MEDIA = "Interface\\AddOns\\EllesmereUINameplates\\media\\"
	local WHITE = "Interface\\Buttons\\WHITE8X8"
	local defaults = ENP.defaults or {}
	local function DB() return ENP.db.profile end
	local function Val(key)
		local v = DB()[key]
		if v == nil then v = defaults[key] end
		return v
	end
	local function TexPath(key)
		if not key or key == "none" or key == "" then return nil end
		if ENP.OVERLAY_STRIPE_KEYS and ENP.OVERLAY_STRIPE_KEYS[key] then return MEDIA .. key end
		if key:sub(1, 3) == "sm:" then
			local lsm = LSM()
			return (lsm and lsm:Fetch("statusbar", key:sub(4), true)) or WHITE
		end
		if ENP.BAR_TEXTURE_NAMES and ENP.BAR_TEXTURE_NAMES[key] then
			return MEDIA .. "textures\\" .. key
		end
		return WHITE
	end
	local TEX_OPTS = { texturePreview = true, previewPath = TexPath }
	local function TexDrop(label, key, getItems)
		p:Dropdown(label, nil, getItems,
			function() return Val(key) or "none" end,
			function() return LabelOf(getItems(), Val(key) or "none") end,
			function(v) DB()[key] = v end,
			TEX_OPTS)
	end
	-- Target / Focus: the stripes, ---, then the bar textures (retail order).
	local function OverlayItems()
		local out = {}
		for _, k in ipairs(ENP.OVERLAY_STRIPE_ORDER or {}) do
			out[#out + 1] = { value = k, name = ENP.OVERLAY_STRIPE_NAMES[k] or k }
		end
		out[#out + 1] = { separator = true, name = "" }
		for _, it in ipairs(ENP.TextureItems()) do out[#out + 1] = it end
		return out
	end
	-- Hover: None, ---, the stripes, ---, the bar textures.
	local function HoverItems()
		local out = { { value = "none", name = "None" }, { separator = true, name = "" } }
		for _, k in ipairs(ENP.OVERLAY_STRIPE_ORDER or {}) do
			out[#out + 1] = { value = k, name = ENP.OVERLAY_STRIPE_NAMES[k] or k }
		end
		out[#out + 1] = { separator = true, name = "" }
		for _, it in ipairs(ENP.TextureItems()) do
			if it.value ~= "none" then out[#out + 1] = it end
		end
		return out
	end
	local ABSORB_STYLES = {
		{ value = "blizzard", name = "Blizzard" }, { value = "striped", name = "Striped" },
		{ value = "clean", name = "Clean (Flat)" }, { value = "pixelsShield", name = "Pixels Shield" },
		{ value = "pixelsShieldEdge", name = "Pixels Shield Edge" }, { value = "pixelsShieldFill", name = "Pixels Shield Fill" },
	}
	TexDrop("Bar Texture", "healthBarTexture", ENP.TextureItems)
	TexDrop("Cast Bar Texture", "castBarTexture", ENP.TextureItems)
	p:Dropdown("Absorb Style", nil,
		function() return ABSORB_STYLES end,
		function() return Val("absorbStyle") or "blizzard" end,
		function() return LabelOf(ABSORB_STYLES, Val("absorbStyle") or "blizzard") end,
		-- (Retail also re-seeds absorbAlpha; the Mists module reads the
		-- opacity from ENP.ABSORB_STYLE_ALPHA, so there is no key to write.)
		function(v) DB().absorbStyle = v end,
		{ texturePreview = true, previewPath = function(v) return ENP.ABSORB_STYLE_TEX and ENP.ABSORB_STYLE_TEX[v] end })
	TexDrop("Hover Texture", "hoverOverlayTexture", HoverItems)
	TexDrop("Target Texture", "targetOverlayTexture", OverlayItems)
	TexDrop("Focus Texture", "focusOverlayTexture", OverlayItems)
	LinkRow(p, "Custom Border Style", "nameplates")
end

---------------------------------------------------------------------------
-- Resource Bars
---------------------------------------------------------------------------
local function SectionResourceBars(p)
	local ERB = ns.ERB
	if not (ERB and ERB.db and ERB.TextureItems) then return end
	p:Section("Resource Bars")
	local function P() return ERB.db.profile end
	local TEX_OPTS = { texturePreview = true, previewPath = function(v) return ERB.TexturePath(v) end }
	local split = P().splitTex == true
	p:Dropdown("Bar Texture",
		split and "Texture for the class resource bar and any bar set to Match Main Texture."
			or "Texture for the health, power and class resource bars.",
		ERB.TextureItems,
		function() return (P().general and P().general.barTexture) or "none" end,
		function() return ERB.TextureLabel(P().general and P().general.barTexture) end,
		function(v) if P().general then P().general.barTexture = v end end,
		TEX_OPTS)
	p:Dropdown("Cast Bar Texture", nil, ERB.TextureItems,
		function() return (P().castBar and P().castBar.texture) or "none" end,
		function() return ERB.TextureLabel(P().castBar and P().castBar.texture) end,
		function(v) if P().castBar then P().castBar.texture = v end end,
		TEX_OPTS)
	-- Health / power rows only while one of them has its own texture.
	if split and ERB.BarTexture and ERB.SetBarTexture then
		local function MatchItems()
			local items = { { value = "__match", name = "Match Main Texture" }, { separator = true, name = "" } }
			for _, it in ipairs(ERB.TextureItems()) do items[#items + 1] = it end
			return items
		end
		local function BarRow(text, barKey)
			p:Dropdown(text, nil, MatchItems,
				function()
					local x = P()
					return (x.splitTex and x[barKey] and x[barKey].barTexture) or "__match"
				end,
				function()
					local x = P()
					local v = x.splitTex and x[barKey] and x[barKey].barTexture
					return v and ERB.TextureLabel(v) or "Match Main Texture"
				end,
				function(v)
					ERB.SetBarTexture(P(), barKey, v ~= "__match" and v or nil)
					-- Neither bar has its own texture any more: the rows go.
					if P().splitTex ~= true and ns.RebuildSettingsPage then ns.RebuildSettingsPage() end
				end,
				TEX_OPTS)
		end
		BarRow("Health Bar Texture", "health")
		BarRow("Power Bar Texture", "primary")
	end
	p:Dropdown("GCD Bar Texture", nil, ERB.TextureItems,
		function() return (P().gcdBar and P().gcdBar.texture) or "none" end,
		function() return ERB.TextureLabel(P().gcdBar and P().gcdBar.texture) end,
		function(v) if P().gcdBar then P().gcdBar.texture = v end end,
		TEX_OPTS)
	p:Blank()
	LinkRow(p, "Border Styles (per bar)", "resourceBars")
end

---------------------------------------------------------------------------
-- Link-only sections (retail cards whose rows are per element)
---------------------------------------------------------------------------
local LINK_SECTIONS = {
	{ folder = "EllesmereUIActionBars", name = "Action Bars", key = "actionBars", rows = { "Bar & Button Border Styles" } },
	{ folder = "EllesmereUIDamageMeters", name = "Damage Meters", key = "damageMeters", rows = { "Bar, Breakdown and Spell History Textures" } },
	{ folder = "EllesmereUIDataBars", name = "DataBars", key = "dataBars", rows = { "Bar Texture (per data bar)" } },
	{ folder = "EllesmereUIMinimap", name = "Minimap", key = "minimap", rows = { "Minimap Border Style" } },
}

local function SectionLinks(p, def)
	if not Loaded(def.folder) then return end
	p:Section(def.name)
	for _, label in ipairs(def.rows) do
		LinkRow(p, label, def.key)
	end
end

---------------------------------------------------------------------------
-- Chat, Quality of Life, Damage Meters (retail module texture rows)
---------------------------------------------------------------------------
local function BarTexItems()
	local items = { { name = "None", value = "none" } }
	for _, t in ipairs(ns.GetBarTextures and ns.GetBarTextures() or {}) do
		items[#items + 1] = { name = t.name, value = t.path }
	end
	return items
end
local function BarTexLabel(v)
	if v == nil or v == "none" then return "None" end
	return ns.GetBarTextureLabel and ns.GetBarTextureLabel(v) or tostring(v)
end
local function TexMirror(p, label, tip, db, key)
	p:Dropdown(label, tip, BarTexItems,
		function() return db()[key] or "none" end,
		function() return BarTexLabel(db()[key]) end,
		function(v) db()[key] = v end,
		{ texturePreview = true, previewPath = function(v) return (v == "none") and "" or v end })
end

local function SectionChat(p)
	local EC = ns.ECHAT
	if not (EC and EC.DB) then return end
	p:Section("Chat")
	TexMirror(p, "Background Texture", "Texture drawn over the chat background color.", EC.DB, "bgTexture")
	TexMirror(p, "Tab Texture", "Texture drawn over the tab background colors.", EC.DB, "tabBackgroundTexture")
	LinkRow(p, "Panel & Tab Border Styles", "chat")
end

local function SectionQoL(p)
	p:Section("Quality of Life")
	if ns.GetMovementAlertDB and ns.GetMovementAlertDB() then
		TexMirror(p, "Movement Alert Bar Texture", "Texture of the Movement Alert bar (Bar display mode).",
			ns.GetMovementAlertDB, "barTexture")
	end
	LinkRow(p, "Cursor, GCD and Cast Ring Textures", "qol")
end

function ns.GSO_BuildTexturesPage(p)
	p:Paragraph("A quick view of every texture setting in one place.\n"
		.. "These are the same settings found on each module's own pages, not separate ones.")
	-- Retail roster order: Action Bars, Nameplates, Unit Frames, (Raid
	-- Frames, Cooldown Manager), Resource Bars, ..., Minimap, Chat, DataBars.
	SectionLinks(p, LINK_SECTIONS[1])
	if Loaded("EllesmereUINameplates") then SectionNameplates(p) end
	if Loaded("EllesmereUIUnitFrames") then SectionUnitFrames(p) end
	if Loaded("EllesmereUIResourceBars") then SectionResourceBars(p) end
	SectionLinks(p, LINK_SECTIONS[4])
	if Loaded("EllesmereUIChat") then SectionChat(p) end
	if Loaded("EllesmereUIQoL") then SectionQoL(p) end
	SectionLinks(p, LINK_SECTIONS[2])
	SectionLinks(p, LINK_SECTIONS[3])
end
