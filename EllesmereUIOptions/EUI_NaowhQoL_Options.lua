-- Settings page of the NaowhUI QoL features (retail NaowhUI "QoL" page,
-- NaowhUI_QoL.lua BuildPorts: the "NAOWHUI QOL" section). Part of
-- EllesmereUIOptions (load on demand); skipped when EllesmereUITopBar is not
-- loaded. Setters only store: the runtime's ns.applyHooks entry applies
-- every change.
--
-- 5.4.8 changes: the text boxes retail keeps in the cog popups are rows of
-- their own ("Reminder Text"); "Hide Proc Overlays" is a checkbox dropdown
-- of every Mists spec (retail: EllesmereUI's spec picker popup). The
-- Boiling Point echo bar (retail Blood DK) and the proxy views of
-- EllesmereUI's own QoL settings are not here.

local ns = EllesmereUI
if not IsAddOnLoaded("EllesmereUITopBar") then
	return
end

local Q = ns.NaowhQoL
if not Q then
	return
end

local floor = math.floor

local function death() return Q.DB("deathRelease") end
local function tank() return Q.DB("coTank") end
local function hide() return Q.DB("stealth") end

local function Items(values, order)
	local items = {}
	for i, k in ipairs(order) do
		items[i] = { name = values[k], value = k }
	end
	return function() return items end
end

local NAME_FORMAT = Items({ full = "Full", abbreviated = "Abbreviated" }, { "full", "abbreviated" })
local DEBUFF_FILTER = Items({
	important = "Boss & Important",
	all = "All Debuffs",
	dispellable = "Dispellable by You",
}, { "important", "all", "dispellable" })
local DEBUFF_POS = Items({
	top = "Above", bottom = "Below", left = "Left", right = "Right",
	topleft = "Top Left", topright = "Top Right",
	bottomleft = "Bottom Left", bottomright = "Bottom Right", center = "Centre",
}, { "top", "bottom", "left", "right", "topleft", "topright", "bottomleft", "bottomright", "center" })
local DEBUFF_GROW = Items({ CENTER = "Centred", RIGHT = "Right", LEFT = "Left", UP = "Up", DOWN = "Down" },
	{ "CENTER", "RIGHT", "LEFT", "UP", "DOWN" })

local TANK_GROW = Items({ DOWN = "Down", UP = "Up" }, { "DOWN", "UP" })

local function FontItems() return Q.FontItems() end
local function SoundItems() return Q.SoundItems() end

-- Hide Proc Overlays: every spec of every class, class names as headers.
local function SpecItems()
	local items = {
		{ name = "Check All", action = function()
			local set = {}
			for _, cls in ipairs(Q.SpecList()) do
				for _, s in ipairs(cls.specs) do set[s.id] = true end
			end
			Q.SetHiddenSpecSet(set)
		end },
		{ name = "Uncheck All", action = function() Q.SetHiddenSpecSet({}) end },
	}
	for _, cls in ipairs(Q.SpecList()) do
		items[#items + 1] = { header = true, name = cls.name }
		for _, s in ipairs(cls.specs) do
			items[#items + 1] = { name = s.name, value = s.id }
		end
	end
	return items
end

local function SpecLabel()
	local on, all = 0, 0
	for _, cls in ipairs(Q.SpecList()) do
		for _, s in ipairs(cls.specs) do
			all = all + 1
			if Q.IsSpecHidden(s.id) then on = on + 1 end
		end
	end
	if on == 0 then return "None" end
	if on == all then return "All (" .. on .. ")" end
	return on .. " of " .. all
end

local PAGES = {
	{
		key = "naowhqol",
		name = "QoL",
		description = "Death release guard, co-tank frame, stealth and stance reminders, and spell alert settings.",
		build = function(p)
			local function deathOff() return not death().enabled end
			local function tankOff() return not tank().enabled end
			local function tankDebuffOff() return tankOff() or not tank().debuffEnabled end
			local function stealthOff() return not hide().enabled end
			local function stanceOff() return not hide().stanceEnabled end

			p:Section("NaowhUI QoL")

			-- Death release | Co-tank frame
			p:Toggle("Death Release Protection",
				"Covers the release button when you die in a dungeon or raid, so a panic click cannot release you. Hold ALT to release.",
				function() return death().enabled end, function(v) death().enabled = v end)
			p:Cog("Death Release Settings", {
				{ type = "slider", label = "Hold Time (s)", min = 0.5, max = 3, step = 0.1,
					get = function() return death().holdTime end,
					set = function(v) death().holdTime = v end },
			}, { disabled = deathOff, disabledTip = "Turn Death Release Protection on first." })

			p:Toggle("Co-Tank Frame",
				"Shows the health of every other tank (role Tank or Main Tank) while you are tanking a raid, one bar each. Click a bar to target that tank. Move and resize it in EllesmereUI's Unlock Mode.",
				function() return tank().enabled end, function(v) tank().enabled = v end)
			p:Swatch("Health Bar Colour",
				function() local c = tank(); return c.healthColorR, c.healthColorG, c.healthColorB end,
				function(r, g, b)
					local c = tank()
					c.healthColorR, c.healthColorG, c.healthColorB = r, g, b
				end,
				{ disabled = function() return tankOff() or tank().useClassColor end })
			p:Cog("Co-Tank Frame Settings", {
				{ type = "toggle", label = "Health Bar Class Colour",
					get = function() return tank().useClassColor end,
					set = function(v) tank().useClassColor = v end },
				{ type = "slider", label = "Background Opacity", min = 0, max = 100, step = 5,
					get = function() return floor((tank().bgAlpha or 0.6) * 100 + 0.5) end,
					set = function(v) tank().bgAlpha = v / 100 end },
				{ type = "dropdown", label = "Font", items = FontItems,
					get = function() return tank().font end,
					set = function(v) tank().font = v end },
				{ type = "toggle", label = "Show Name",
					get = function() return tank().showName end,
					set = function(v) tank().showName = v end },
				{ type = "dropdown", label = "Name Format", items = NAME_FORMAT,
					get = function() return tank().nameFormat end,
					set = function(v) tank().nameFormat = v end },
				{ type = "slider", label = "Name Length", min = 3, max = 12, step = 1,
					get = function() return tank().nameLength end,
					set = function(v) tank().nameLength = v end },
				{ type = "slider", label = "Name Font Size", min = 8, max = 24, step = 1,
					get = function() return tank().nameFontSize end,
					set = function(v) tank().nameFontSize = v end },
				{ type = "toggle", label = "Name Class Colour",
					get = function() return tank().nameColorUseClassColor end,
					set = function(v) tank().nameColorUseClassColor = v end },
				{ type = "color", label = "Name Colour",
					tip = "Turn Name Class Colour off to pick a custom colour.",
					disabled = function() return tank().nameColorUseClassColor end,
					get = function() local c = tank(); return c.nameColorR, c.nameColorG, c.nameColorB, 1 end,
					set = function(r, g, b)
						local c = tank()
						c.nameColorR, c.nameColorG, c.nameColorB = r, g, b
					end },
				{ type = "slider", label = "Width", min = 50, max = 400, step = 5,
					get = function() return tank().width end,
					set = function(v) tank().width = v end },
				{ type = "slider", label = "Height", min = 10, max = 80, step = 1,
					get = function() return tank().height end,
					set = function(v) tank().height = v end },
				{ type = "slider", label = "Bar Spacing", min = 0, max = 40, step = 1,
					tip = "Space between the bars when there is more than one other tank. Debuffs on the top or bottom edge get extra room.",
					get = function() return tank().tankSpacing end,
					set = function(v) tank().tankSpacing = v end },
				{ type = "dropdown", label = "Stack Direction", items = TANK_GROW,
					get = function() return tank().tankGrow end,
					set = function(v) tank().tankGrow = v end },
				{ type = "toggle", label = "Preview Outside Raid",
					tip = "Shows a stand-in bar so the frame can be placed and sized anywhere. The real co-tank replaces it as soon as there is one.",
					get = function() return tank().preview end,
					set = function(v) tank().preview = v end },
			}, { disabled = tankOff, disabledTip = "Turn the Co-Tank Frame on first." })

			-- Co-tank debuffs
			p:Toggle("Co-Tank Debuffs",
				"Shows the other tank's debuffs above their health bar -- tank-buster stacks, boss debuffs and anything you can dispel.",
				function() return tank().debuffEnabled end, function(v) tank().debuffEnabled = v end, tankOff)
			p:Cog("Co-Tank Debuff Settings", {
				{ type = "dropdown", label = "Filter", items = DEBUFF_FILTER,
					get = function() return tank().debuffFilter end,
					set = function(v) tank().debuffFilter = v end },
				{ type = "slider", label = "Max Icons", min = 1, max = 8, step = 1,
					get = function() return tank().debuffCap end,
					set = function(v) tank().debuffCap = v end },
				{ type = "slider", label = "Icon Size", min = 10, max = 48, step = 1,
					get = function() return tank().debuffSize end,
					set = function(v) tank().debuffSize = v end },
				{ type = "slider", label = "Spacing", min = 0, max = 12, step = 1,
					get = function() return tank().debuffSpacing end,
					set = function(v) tank().debuffSpacing = v end },
				{ type = "dropdown", label = "Position", items = DEBUFF_POS,
					get = function() return tank().debuffPosition end,
					set = function(v) tank().debuffPosition = v end },
				{ type = "dropdown", label = "Grow", items = DEBUFF_GROW,
					get = function() return tank().debuffGrow end,
					set = function(v) tank().debuffGrow = v end },
				{ type = "slider", label = "Offset X", min = -200, max = 200, step = 1,
					get = function() return tank().debuffOffsetX end,
					set = function(v) tank().debuffOffsetX = v end },
				{ type = "slider", label = "Offset Y", min = -200, max = 200, step = 1,
					get = function() return tank().debuffOffsetY end,
					set = function(v) tank().debuffOffsetY = v end },
				{ type = "toggle", label = "Show Time Left",
					get = function() return tank().debuffShowDuration end,
					set = function(v) tank().debuffShowDuration = v end },
				{ type = "slider", label = "Time Left Size", min = 6, max = 20, step = 1,
					disabled = function() return not tank().debuffShowDuration end,
					get = function() return tank().debuffDurSize end,
					set = function(v) tank().debuffDurSize = v end },
				{ type = "toggle", label = "Show Stacks",
					get = function() return tank().debuffShowStacks end,
					set = function(v) tank().debuffShowStacks = v end },
				{ type = "slider", label = "Stacks Size", min = 6, max = 20, step = 1,
					disabled = function() return not tank().debuffShowStacks end,
					get = function() return tank().debuffStackSize end,
					set = function(v) tank().debuffStackSize = v end },
				{ type = "toggle", label = "Show Tooltips",
					get = function() return tank().debuffTooltips end,
					set = function(v) tank().debuffTooltips = v end },
			}, { disabled = tankDebuffOff, disabledTip = "Turn the Co-Tank Frame and Co-Tank Debuffs on first." })
			p:Blank()

			-- Stealth reminder | Stance reminder
			p:Toggle("Stealth Reminder",
				"A big on-screen reminder when you are not stealthed. Rogues always, druids for the specs you pick in the gear. Move and resize it in EllesmereUI's Unlock Mode.",
				function() return hide().enabled end, function(v) hide().enabled = v end)
			p:Swatch("Not Stealthed Colour",
				function() local c = hide(); return c.warningR, c.warningG, c.warningB end,
				function(r, g, b)
					local c = hide()
					c.warningR, c.warningG, c.warningB = r, g, b
				end,
				{ disabled = function() return stealthOff() or hide().warningUseClassColor end })
			local stealthRows = {
				{ type = "toggle", label = "Not Stealthed Class Colour",
					get = function() return hide().warningUseClassColor end,
					set = function(v) hide().warningUseClassColor = v end },
				{ type = "color", label = "Stealthed Colour",
					tip = "Turn Stealthed Class Colour off to pick a custom colour.",
					disabled = function() return hide().stealthUseClassColor end,
					get = function() local c = hide(); return c.stealthR, c.stealthG, c.stealthB, 1 end,
					set = function(r, g, b)
						local c = hide()
						c.stealthR, c.stealthG, c.stealthB = r, g, b
					end },
				{ type = "toggle", label = "Stealthed Class Colour",
					get = function() return hide().stealthUseClassColor end,
					set = function(v) hide().stealthUseClassColor = v end },
				{ type = "toggle", label = "Show While Stealthed",
					get = function() return hide().showStealthed end,
					set = function(v) hide().showStealthed = v end },
				{ type = "toggle", label = "Show While Not Stealthed",
					get = function() return hide().showNotStealthed end,
					set = function(v) hide().showNotStealthed = v end },
				{ type = "toggle", label = "Hide While Rested",
					get = function() return hide().disableWhenRested end,
					set = function(v) hide().disableWhenRested = v end },
				{ type = "toggle", label = "Only In a Group",
					get = function() return hide().groupOnly end,
					set = function(v) hide().groupOnly = v end },
				{ type = "dropdown", label = "Font", items = FontItems,
					get = function() return hide().font end,
					set = function(v) hide().font = v end },
				{ type = "slider", label = "Text Scale", min = 50, max = 200, step = 5,
					get = function() return floor((hide().textScale or 1) * 100 + 0.5) end,
					set = function(v) hide().textScale = v / 100 end },
			}
			-- Feral is always on; the other three druid specs are an opt-in.
			if Q.ClassFile() == "DRUID" then
				stealthRows[#stealthRows + 1] = { type = "toggle", label = "Also Warn on Balance",
					get = function() return hide().enableBalance end,
					set = function(v) hide().enableBalance = v end }
				stealthRows[#stealthRows + 1] = { type = "toggle", label = "Also Warn on Guardian",
					get = function() return hide().enableGuardian end,
					set = function(v) hide().enableGuardian = v end }
				stealthRows[#stealthRows + 1] = { type = "toggle", label = "Also Warn on Restoration",
					get = function() return hide().enableResto end,
					set = function(v) hide().enableResto = v end }
			end
			p:Cog("Stealth Reminder Settings", stealthRows,
				{ disabled = stealthOff, disabledTip = "Turn the Stealth Reminder on first." })

			p:Toggle("Stance / Form Reminder",
				"Warns when you are in the wrong form or stance, without a Seal (and Righteous Fury as Protection), or out of Shadowform. Move and resize it in EllesmereUI's Unlock Mode.",
				function() return hide().stanceEnabled end, function(v) hide().stanceEnabled = v end)
			p:Swatch("Warning Colour",
				function() local c = hide(); return c.stanceWarnR, c.stanceWarnG, c.stanceWarnB end,
				function(r, g, b)
					local c = hide()
					c.stanceWarnR, c.stanceWarnG, c.stanceWarnB = r, g, b
				end,
				{ disabled = function() return stanceOff() or hide().stanceWarnUseClassColor end })
			p:Cog("Stance Reminder Settings", {
				{ type = "toggle", label = "Warning Class Colour",
					get = function() return hide().stanceWarnUseClassColor end,
					set = function(v) hide().stanceWarnUseClassColor = v end },
				{ type = "dropdown", label = "Font", items = FontItems,
					get = function() return hide().stanceFont end,
					set = function(v) hide().stanceFont = v end },
				{ type = "slider", label = "Text Scale", min = 50, max = 200, step = 5,
					get = function() return floor((hide().stanceTextScale or 1) * 100 + 0.5) end,
					set = function(v) hide().stanceTextScale = v / 100 end },
				{ type = "toggle", label = "Only In Combat",
					get = function() return hide().stanceCombatOnly end,
					set = function(v) hide().stanceCombatOnly = v end },
				{ type = "toggle", label = "Only In Dungeons & Raids",
					get = function() return hide().stanceInstanceOnly end,
					set = function(v) hide().stanceInstanceOnly = v end },
				{ type = "toggle", label = "Hide While Rested",
					get = function() return hide().stanceDisableWhenRested end,
					set = function(v) hide().stanceDisableWhenRested = v end },
				{ type = "toggle", label = "Play a Sound",
					get = function() return hide().stanceSoundEnabled end,
					set = function(v) hide().stanceSoundEnabled = v end },
				{ type = "dropdown", label = "Sound", items = SoundItems,
					disabled = function() return not hide().stanceSoundEnabled end,
					get = function() return hide().stanceSound or Q.SOUND_NONE end,
					set = function(v)
						hide().stanceSound = v
						Q.PlaySound(v)
					end },
				{ type = "slider", label = "Repeat Every (s)", min = 0, max = 15, step = 1,
					disabled = function() return not hide().stanceSoundEnabled end,
					get = function() return hide().stanceSoundInterval end,
					set = function(v) hide().stanceSoundInterval = v end },
			}, { disabled = stanceOff, disabledTip = "Turn the Stance / Form Reminder on first." })

			-- Spell alerts
			p:Slider("Spell Alert Opacity", "How bright the glow is when one of your spells procs.", 0, 100, 5,
				function() return floor(Q.GetAlertOpacity() * 100 + 0.5) end,
				function(v) Q.SetAlertOpacity(v / 100) end)
			p:MultiSelect("Hide Proc Overlays",
				"Choose which specs have their proc glows switched off. Covers every class and spec, not just the one you are playing.",
				SpecItems,
				function(v) return v ~= nil and Q.IsSpecHidden(v) end,
				function(v) if v then Q.ToggleHiddenSpec(v) end end,
				SpecLabel)

			-- Retail keeps these text boxes in the cog popups.
			p:Section("Reminder Text")
			p:TextInput("Not Stealthed Text", "Text of the Stealth Reminder while you are not stealthed.",
				function() return hide().warningText or "" end,
				function(v) hide().warningText = v or ""; Q.Refresh("stealth") end, "RESTEALTH")
			p:TextInput("Stealthed Text", "Text of the Stealth Reminder while you are stealthed.",
				function() return hide().stealthText or "" end,
				function(v) hide().stealthText = v or ""; Q.Refresh("stealth") end, "STEALTH")
			p:TextInput("Stance Warning Text", "Text of the Stance / Form Reminder. Empty uses the class default (CHECK FORM, CHECK STANCE, SHADOWFORM, CHECK SEAL).",
				function() return hide().stanceWarnText or "" end,
				function(v) hide().stanceWarnText = v or ""; Q.Refresh("stealth") end, "Class default")
		end,
	},
}

ns.RegisterSettingsModule({
	key = "naowhQoL",
	name = "NaowhUI QoL",
	group = "QoL Addons",
	tabs = PAGES,
	reset = function() Q.ResetAll() end,
	resetTip = "Set all NaowhUI QoL settings back to default.",
})
