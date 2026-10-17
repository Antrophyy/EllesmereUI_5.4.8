-- Global Settings > Glows (EllesmereUI EUI_Glows_Options.lua and the site
-- registry of EllesmereUI_GlowOptions.lua). Registers no settings module:
-- EUI__General_Options.lua adds the tab and calls ns.GSO_BuildGlowsPage(p).
--
-- A glow template (style, color, Pixel Glow parameters) applied once to
-- every active custom glow, plus one section per module with every
-- registered glow site mirrored (style + color mode). Sites register through
-- EllesmereUI.GlowOptions.RegisterSite (retail API): this file loads first in
-- the options, so module option files can register theirs; it registers the
-- Mists sites itself (Action Bars Custom Proc Glow).
--
-- Left out: the retail sites of modules this port does not have (Cooldown
-- Manager, Raid Frames, Mythic+, AuraBuff Reminders, Nameplates dispel /
-- important cast glows and Unit Frames purge glows: the Mists modules draw
-- those as fixed borders, not glow styles), per-row status dots, Hide
-- Inactive Glows and the card layout (Mists settings pages use sections).

local ns = EllesmereUI
local G = ns and ns.Glows
if not G then
	return
end

---------------------------------------------------------------------------
-- Site registry (retail EllesmereUI.GlowOptions, the parts the page uses)
---------------------------------------------------------------------------
local GO = ns.GlowOptions or { sites = {} }
ns.GlowOptions = GO
GO.sites = GO.sites or {}

local function NoneValue(desc)
	if desc.noneValue ~= nil then return desc.noneValue end
	return 0
end

function GO.ToShared(desc, v)
	if v == nil or v == NoneValue(desc) then return nil end
	if desc.toShared then return desc.toShared(v) end
	if desc.view then return desc.view.toShared[v] end
	if type(v) == "number" and v >= 1 and v <= #G.STYLES then return v end
	return nil
end

function GO.FromShared(desc, idx)
	if desc.fromShared then return desc.fromShared(idx) end
	if desc.view then return desc.view.fromShared[idx] end
	return idx
end

function GO.Resolve(desc, idx)
	local ex = desc._resolveEx
	if not ex then
		ex = {}
		for i = 1, #G.STYLES do
			if (desc.excludes and desc.excludes[i]) or GO.FromShared(desc, i) == nil then ex[i] = true end
		end
		desc._resolveEx = ex
	end
	return G.ResolveStyle(idx, desc.host, ex)
end

local function StyleOffered(desc, idx)
	local caps = G.HOSTS[desc.host or "icon"]
	return caps and caps[idx] and not (desc.excludes and desc.excludes[idx])
end

-- Dropdown items: None (unless noNone), extras, then the offered styles.
function GO.StyleItems(desc)
	local items = {}
	if not desc.noNone then
		items[#items + 1] = { value = NoneValue(desc), name = "None" }
	end
	for _, x in ipairs(desc.extras or {}) do
		items[#items + 1] = { value = x.value, name = x.label }
	end
	if desc.order then
		for _, v in ipairs(desc.order) do
			local idx = GO.ToShared(desc, v)
			if idx and StyleOffered(desc, idx) then
				items[#items + 1] = { value = v, name = G.STYLES[idx].name }
			end
		end
	else
		for i = 1, #G.STYLES do
			if StyleOffered(desc, i) then
				local v = GO.FromShared(desc, i)
				if v ~= nil then items[#items + 1] = { value = v, name = G.STYLES[i].name } end
			end
		end
	end
	return items
end

function GO.IsOff(desc)
	if desc.isOff and desc.isOff() then return true end
	local v = desc.get("style")
	return v == nil or v == NoneValue(desc)
end

function GO.StyleLocked(desc)
	if desc.disabled and desc.disabled() then return true end
	return (desc.styleDisabled and desc.styleDisabled()) and true or false
end

function GO.IsCustomGlow(desc)
	if desc.paramsOnly then return true end
	if GO.IsOff(desc) then return false end
	return GO.ToShared(desc, desc.get("style")) ~= nil
end

function GO.IsPixel(desc)
	if desc.paramsOnly then return true end
	return GO.IsCustomGlow(desc) and GO.ToShared(desc, desc.get("style")) == 1
end

function GO.RegisterSite(entry)
	for i = 1, #GO.sites do
		if GO.sites[i].id == entry.id then GO.sites[i] = entry; return end
	end
	GO.sites[#GO.sites + 1] = entry
end

function GO.TemplateValue(desc, t)
	if desc.paramsOnly then return nil, false end
	local idx, converted = GO.Resolve(desc, t.style or 1)
	return GO.FromShared(desc, idx), converted, idx
end

function GO.ApplyTemplate(desc, t, anyState)
	if not anyState and not GO.IsCustomGlow(desc) then return false, false end
	if GO.StyleLocked(desc) then return false, false end
	local v, converted, idx = GO.TemplateValue(desc, t)
	if v == nil then return false, false end
	local caps = desc.caps or {}
	desc.set("style", v)
	local tm = t.mode or "custom"
	if caps.mode then desc.set("mode", tm) end
	if tm == "custom" and t.r then desc.set("color", t.r, t.g, t.b) end
	if caps.params and idx == 1 then
		desc.set("lines", t.lines or 8)
		desc.set("thickness", t.thickness or 2)
		desc.set("speed", t.speed or 4)
	end
	if caps.bg and idx == 1 then
		desc.set("bg", t.bg and true or nil)
		if t.bg then desc.set("bgColor", t.bgR or 0, t.bgG or 0, t.bgB or 0) end
	end
	return true, converted
end

function GO.MatchesTemplate(desc, t)
	if desc.paramsOnly or not GO.IsCustomGlow(desc) then return false end
	local caps = desc.caps or {}
	local idx = GO.Resolve(desc, t.style or 1)
	if GO.ToShared(desc, desc.get("style")) ~= idx then return false end
	local mode = caps.mode and desc.get("mode") or "custom"
	if mode ~= (t.mode or "custom") then return false end
	if mode == "custom" and t.r then
		local r, g, b = desc.get("color")
		if r ~= t.r or g ~= t.g or b ~= t.b then return false end
	end
	if caps.params and idx == 1 then
		if (desc.get("lines") or 8) ~= (t.lines or 8) then return false end
		if (desc.get("thickness") or 2) ~= (t.thickness or 2) then return false end
		if (desc.get("speed") or 4) ~= (t.speed or 4) then return false end
	end
	if caps.bg and idx == 1 then
		if (desc.get("bg") == true) ~= (t.bg == true) then return false end
		if t.bg then
			local br, bgg, bb = desc.get("bgColor")
			if (br or 0) ~= (t.bgR or 0) or (bgg or 0) ~= (t.bgG or 0) or (bb or 0) ~= (t.bgB or 0) then
				return false
			end
		end
	end
	return true
end

---------------------------------------------------------------------------
-- Mists sites
---------------------------------------------------------------------------
-- Action Bars > Custom Proc Glow: procGlowEnabled + procGlowType (1 Pixel,
-- 2 Action Button Glow, 3 Auto-Cast = shared 1-3), procGlowColorMode /
-- procGlowUseClassColor, procGlowColor.
local function RegisterMistsSites()
	local EAB = ns.EAB
	if EAB and EAB.db and not GO._mistsAB then
		GO._mistsAB = true
		local function DB() return EAB.db.profile end
		GO.RegisterSite({ id = "ab_proc", label = "Custom Proc Glow", module = "EllesmereUIActionBars",
			moduleName = "Action Bars", settingsKey = "actionBars",
			desc = {
				host = "icon", excludes = { [4] = true, [5] = true, [6] = true, [7] = true },
				caps = { mode = true },
				defaultColor = { r = 1, g = 0.776, b = 0.376 },
				get = function(f)
					local d = DB()
					if f == "style" then
						if not d.procGlowEnabled then return 0 end
						return d.procGlowType or 1
					elseif f == "mode" then
						if d.procGlowColorMode then return d.procGlowColorMode end
						return d.procGlowUseClassColor and "class" or "custom"
					elseif f == "color" then
						local c = d.procGlowColor
						if c then return c.r, c.g, c.b end
					end
				end,
				set = function(f, a, b, c)
					local d = DB()
					if f == "style" then
						if a == 0 then
							d.procGlowEnabled = false
						else
							d.procGlowEnabled = true
							d.procGlowType = a
						end
					elseif f == "mode" then
						d.procGlowColorMode = a
						d.procGlowUseClassColor = (a == "class")
					elseif f == "color" then
						d.procGlowColor = { r = a, g = b, b = c }
					end
				end,
			} })
	end
end

---------------------------------------------------------------------------
-- Template (account-wide EllesmereUIDB.glowTemplate; only ever a pattern)
---------------------------------------------------------------------------
local TEMPLATE_DEFAULTS = { style = 1, mode = "default", lines = 8, thickness = 2, speed = 4 }

local function Template()
	return (type(EllesmereUIDB) == "table" and EllesmereUIDB.glowTemplate) or TEMPLATE_DEFAULTS
end

local function TemplateW()
	if type(EllesmereUIDB) ~= "table" then EllesmereUIDB = {} end
	local t = EllesmereUIDB.glowTemplate
	if not t then
		t = {}
		for k, v in pairs(TEMPLATE_DEFAULTS) do t[k] = v end
		EllesmereUIDB.glowTemplate = t
	end
	return t
end

-- Template styles: every style but Shape Glow (needs an icon shape) and
-- Blackout (Cooldown Manager only).
local function TemplateStyleItems()
	local items = {}
	for i = 1, #G.STYLES do
		if i ~= 4 and not G.STYLES[i].solidFill then
			items[#items + 1] = { value = i, name = G.STYLES[i].name }
		end
	end
	return items
end

local function ModeColor(mode, r, g, b, dc)
	if mode == "default" then
		local c = G.DEFAULT_COLOR
		return c.r, c.g, c.b
	end
	local rr, gg, bb = G.ResolveColor(mode, r, g, b, dc and dc.r or 1, dc and dc.g or 1, dc and dc.b or 1)
	return rr or 1, gg or 1, bb or 1
end

---------------------------------------------------------------------------
-- Apply
---------------------------------------------------------------------------
local function Sites()
	RegisterMistsSites()
	local out = {}
	for _, entry in ipairs(GO.sites) do
		if entry.desc and (not entry.module or IsAddOnLoaded(entry.module)) then
			out[#out + 1] = entry
		end
	end
	return out
end

local function Eligible(site, t, anyState)
	local desc = site.desc
	if desc.paramsOnly or GO.StyleLocked(desc) then return false end
	if not anyState and not GO.IsCustomGlow(desc) then return false end
	return not GO.MatchesTemplate(desc, t)
end

local function ConfirmApply(sites, anyState)
	local t = Template()
	local n, conv, turnOn = 0, 0, 0
	for _, site in ipairs(sites) do
		if Eligible(site, t, anyState) then
			n = n + 1
			local _, c = GO.TemplateValue(site.desc, t)
			if c then conv = conv + 1 end
			if not GO.IsCustomGlow(site.desc) then turnOn = turnOn + 1 end
		end
	end
	if n == 0 then
		ns.ShowInfoPopup({
			title = "Apply Glow Template",
			content = anyState and "Nothing to change: every glow here already matches the template."
				or "Nothing to change: no active custom glow differs from the template.",
		})
		return
	end
	local msg = anyState and format("Apply the template to %d glow(s)?", n)
		or format("Apply the template to the %d active custom glow(s) listed here?", n)
	if turnOn > 0 then
		msg = msg .. "\n\n" .. format("%d of them are off or use a Blizzard style and switch to the template glow.", turnOn)
	end
	if conv > 0 then
		msg = msg .. "\n\n" .. format("%d of them can't show the chosen style and use the closest one.", conv)
	end
	ns.ShowConfirmPopup({
		title = "Apply Glow Template",
		message = msg,
		confirmText = "Apply",
		cancelText = "Cancel",
		onConfirm = function()
			for _, site in ipairs(sites) do
				if Eligible(site, t, anyState) then
					GO.ApplyTemplate(site.desc, t, anyState)
				end
			end
			-- Store only; every module's apply hook repaints.
			for _, fn in ipairs(ns.applyHooks or {}) do pcall(fn) end
			if ns.RebuildSettingsPage then ns.RebuildSettingsPage() end
		end,
	})
end

---------------------------------------------------------------------------
-- Live preview (a small icon with the template glow on it)
---------------------------------------------------------------------------
local PREVIEW_ICON = "Interface\\Icons\\Spell_Holy_HolyBolt"

local function BuildPreview(cell, getSpec)
	local f = CreateFrame("Frame", nil, cell)
	f:SetSize(30, 30)
	f:SetPoint("RIGHT", cell, "RIGHT", -24, 0)
	f:SetFrameLevel(cell:GetFrameLevel() + 5)
	local icon = f:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexture(PREVIEW_ICON)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	local host = CreateFrame("Frame", nil, f)
	host:SetAllPoints()
	host:SetFrameLevel(f:GetFrameLevel() + 2)
	local function Refresh()
		local spec = getSpec()
		G.StartSpecGlow(host, spec, 30, 30, "icon")
	end
	Refresh()
	return Refresh
end

---------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------
local _tplSpec = {}

function ns.GSO_BuildGlowsPage(p)
	local sites = Sites()

	p:Paragraph("Set a glow once. Apply to All changes the active custom glows listed below.\n"
		.. "Module and row buttons also replace off glows and Blizzard's own glow.\n"
		.. "Glows set per icon, indicator or filter keep their own settings.")

	-- GLOW TEMPLATE
	p:Section("Glow Template")
	p:Dropdown("Glow Style", "The glow the template applies.",
		TemplateStyleItems,
		function() return Template().style or 1 end,
		function()
			local s = G.STYLES[Template().style or 1]
			return s and s.name or "Pixel Glow"
		end,
		function(v) TemplateW().style = v end)
	-- Color: Default / Custom Color / Class Colored (retail swatch trio).
	local function Mode() return Template().mode or "default" end
	p:Swatch("Class Colored",
		function()
			local c = ns.GetClassColor and ns.GetClassColor(ns._playerClass) or ns._COLOR_WHITE
			return c.r, c.g, c.b, 1
		end,
		function() end,
		{ readonly = true, active = function() return Mode() == "class" end,
		  onClick = function() TemplateW().mode = "class"; return true end })
	p:Swatch("Custom Color",
		function()
			local t = Template()
			local d = G.DEFAULT_COLOR
			return t.r or d.r, t.g or d.g, t.b or d.b, 1
		end,
		function(r, g, b)
			local t = TemplateW()
			t.r, t.g, t.b = r, g, b
			t.mode = "custom"
		end,
		{ active = function() return Mode() == "custom" end,
		  onClick = function()
			if Mode() ~= "custom" then
				local t = TemplateW()
				t.mode = "custom"
				if t.r == nil then
					local d = G.DEFAULT_COLOR
					t.r, t.g, t.b = d.r, d.g, d.b
				end
				return true
			end
		  end })
	p:Swatch("Default",
		function()
			local c = G.DEFAULT_COLOR
			return c.r, c.g, c.b, 1
		end,
		function() end,
		{ readonly = true, active = function() return Mode() == "default" end,
		  onClick = function() TemplateW().mode = "default"; return true end })
	local function NotPixel() return (Template().style or 1) ~= 1 end
	p:Cog("Pixel Glow", {
		{ type = "slider", label = "Lines", min = 2, max = 16, step = 1,
		  get = function() return Template().lines or 8 end,
		  set = function(v) TemplateW().lines = v end, disabled = NotPixel },
		{ type = "slider", label = "Thickness", min = 1, max = 4, step = 1,
		  get = function() return Template().thickness or 2 end,
		  set = function(v) TemplateW().thickness = v end, disabled = NotPixel },
		{ type = "slider", label = "Speed", min = 1, max = 8, step = 1,
		  get = function() return G.SpeedToUI(Template().speed) end,
		  set = function(v) TemplateW().speed = G.SpeedFromUI(v) end, disabled = NotPixel },
		{ type = "toggle", label = "Background",
		  get = function() return Template().bg == true end,
		  set = function(v) TemplateW().bg = v and true or nil end, disabled = NotPixel },
		{ type = "color", label = "Background Color",
		  get = function()
			local t = Template()
			return t.bgR or 0, t.bgG or 0, t.bgB or 0, 1
		  end,
		  set = function(r, g, b)
			local t = TemplateW()
			t.bgR, t.bgG, t.bgB = r, g, b
		  end,
		  disabled = function() return NotPixel() or Template().bg ~= true end },
	}, { disabled = NotPixel, disabledTip = "This option requires Pixel Glow to be selected" })

	p:Label("Preview", "The template glow on an icon.")
	-- The search index builds pages on a recorder: no real cell there.
	local cell = rawget(p, "lastCell")
	local refreshPreview = type(cell) == "table" and BuildPreview(cell, function()
		local t = Template()
		local s = _tplSpec
		s.style = t.style or 1
		if (t.mode or "default") == "default" then
			s.r, s.g, s.b = nil, nil, nil
		else
			s.r, s.g, s.b = ModeColor(t.mode, t.r, t.g, t.b)
		end
		s.lines, s.thickness, s.speed = t.lines, t.thickness, t.speed
		if t.bg then
			s.bg, s.bgR, s.bgG, s.bgB = true, t.bgR or 0, t.bgG or 0, t.bgB or 0
		else
			s.bg, s.bgR, s.bgG, s.bgB = nil, nil, nil, nil
		end
		return s
	end)
	if refreshPreview then p:OnRefresh(refreshPreview) end

	p:Button("Apply to All Active Glows", "Applies the template to every active custom glow listed below.",
		"Apply to All", function() ConfirmApply(sites) end)
	p:Blank()

	-- PER-ENTRY GLOWS (retail ENTRY_GLOW_INFOS): glows set per indicator,
	-- filter or tile on their own pages; listed here with a way there.
	local ENTRY_GLOWS = {
		{ addon = "EllesmereUIRaidFrames", label = "Buff Manager Icon Glows", key = "raidFrames",
		  text = "Set per indicator on the Buff Manager page. The template never changes it." },
		{ addon = "EllesmereUIRaidFrames", label = "Debuff Manager Glows", key = "raidFrames",
		  text = "Icon Effects glows are set per filter and Frame Glow per tile on the Debuff Manager page. The template never changes them." },
		{ addon = "EllesmereUIUnitFrames", label = "Player Aura Bars Icon Glows", key = "unitFrames",
		  text = "Icon Effects glows are set per filter on each bar of the Player Aura Bars page. The template never changes them." },
	}
	local anyEntry = false
	for _, e in ipairs(ENTRY_GLOWS) do
		if IsAddOnLoaded(e.addon) then
			if not anyEntry then
				p:Section("Per-Entry Glows")
				anyEntry = true
			end
			p:Button(e.label, e.text, "Open Settings", function()
				if ns.OpenSettingsModule then ns.OpenSettingsModule(e.key) end
			end)
		end
	end
	if anyEntry then p:Blank() end

	-- MODULE GLOWS: one section per module, one style row per site.
	local byModule, order = {}, {}
	for _, site in ipairs(sites) do
		local key = site.moduleName or site.module or "Other"
		if not byModule[key] then
			byModule[key] = {}
			order[#order + 1] = key
		end
		local list = byModule[key]
		list[#list + 1] = site
	end
	if #order == 0 then
		p:Section("Module Glows")
		p:Paragraph("No module with a glow setting is loaded.")
		return
	end
	for _, key in ipairs(order) do
		local list = byModule[key]
		p:Section(key .. " Glows")
		for _, site in ipairs(list) do
			local desc = site.desc
			p:Dropdown(site.label, site.tip,
				function() return GO.StyleItems(desc) end,
				function()
					local v = desc.get("style")
					if v == nil then return NoneValue(desc) end
					return v
				end,
				function()
					local v = desc.get("style")
					for _, it in ipairs(GO.StyleItems(desc)) do
						if it.value == v then return it.name end
					end
					return "None"
				end,
				function(v) desc.set("style", v) end,
				nil,
				function() return GO.StyleLocked(desc) end)
			if desc.caps and desc.caps.mode then
				local dc = desc.defaultColor
				local function M() return desc.get("mode") or "custom" end
				local function off() return not GO.IsCustomGlow(desc) end
				p:Swatch("Class Colored",
					function()
						local c = ns.GetClassColor and ns.GetClassColor(ns._playerClass) or ns._COLOR_WHITE
						return c.r, c.g, c.b, 1
					end,
					function() end,
					{ readonly = true, disabled = off, active = function() return M() == "class" end,
					  onClick = function() desc.set("mode", "class"); return true end })
				p:Swatch("Glow Color",
					function()
						local r, g, b = desc.get("color")
						return r or (dc and dc.r) or 1, g or (dc and dc.g) or 1, b or (dc and dc.b) or 1, 1
					end,
					function(r, g, b) desc.set("color", r, g, b); desc.set("mode", "custom") end,
					{ disabled = off, active = function() return M() == "custom" end,
					  onClick = function()
						if M() ~= "custom" then desc.set("mode", "custom"); return true end
					  end })
			end
			p:Button("", nil, "Apply Template", function() ConfirmApply({ site }, true) end)
		end
		if list[1].settingsKey then
			p:Button("Apply Template to This Module", "Applies the template to every glow of this module, off glows included.",
				"Apply", function() ConfirmApply(list, true) end)
			p:Button("Open Settings", nil, "Open", function()
				if ns.OpenSettingsModule then ns.OpenSettingsModule(list[1].settingsKey) end
			end)
		end
	end
end
