-- Retail profile migrations for imported retail strings.
--
-- Old retail strings can predate some retail "profile" migrations. Retail
-- fixes such data after import by running every migration whose flag is
-- missing in profile._migrations. This file holds those bodies (copied from
-- retail EllesmereUI_Migration.lua, same order) so R.Convert can bring an old
-- string to the current retail shape first.
--
-- Not here: Cooldown Manager (cdm_*, own converter), spec / global scope,
-- spec overrides, Dragon Riding, WoW Forever, no-op bodies, and bodies that
-- need live game API.

local ns = EllesmereUI
local R = ns.ProfileRetail

-- Self-contained deep copy (retail used EllesmereUI.Lite.DeepCopy).
local function DCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in pairs(t) do
		c[k] = DCopy(v)
	end
	return c
end

-- Retail reads EllesmereUIDB.unlockAnchors, which holds the imported layout
-- by the time it runs. In a string that is data.unlockLayout.anchors.
local function ImportAnchors(prof)
	local ul = prof.unlockLayout
	return type(ul) == "table" and type(ul.anchors) == "table" and ul.anchors or nil
end

R.MIGRATIONS = {
	{
		id = "rf_targeted_spells_bool_to_mode_v1",
		body = function(ctx)
			local rf = ctx.profile.addons and ctx.profile.addons.EllesmereUIRaidFrames
			if type(rf) ~= "table" then return end
			if rf.tsMode == nil then
				if rf.tsEnabled == false then rf.tsMode = "never"
				elseif rf.tsEnabled == true then rf.tsMode = "whenHealing" end
			end
		end,
	},
	{
		id = "nameplates_miniboss_boss_color_split_v1",
		body = function(ctx)
			local np = ctx.profile.addons and ctx.profile.addons.EllesmereUINameplates
			if type(np) ~= "table" then return end
			if np.boss == nil and type(np.miniboss) == "table" then
				np.boss = { r = np.miniboss.r, g = np.miniboss.g, b = np.miniboss.b }
			end
		end,
	},
	{
		id = "uf_power_border_size_zero_v1",
		body = function(ctx)
			local uf = ctx.profile.addons and ctx.profile.addons.EllesmereUIUnitFrames
			if type(uf) ~= "table" then return end
			local UNIT_KEYS = { "player", "target", "focus", "targettarget", "focustarget", "pet", "boss" }
			for _, unitKey in ipairs(UNIT_KEYS) do
				local u = uf[unitKey]
				if type(u) == "table" and type(u.powerBorderSize) == "number" and u.powerBorderSize ~= 0 then
					u.powerBorderSize = 0
				end
			end
		end,
	},
	{
		id = "v67_bar_texture_global",
		body = function(ctx)
			local uf = ctx.profile.addons and ctx.profile.addons.EllesmereUIUnitFrames
			if type(uf) ~= "table" then return end
			local winner
			for _, unit in ipairs({ "player", "target", "focus" }) do
				local s = uf[unit]
				local v = type(s) == "table" and s.healthBarTexture
				if type(v) == "string" and v ~= "" and v ~= "none" then
					winner = v; break
				end
			end
			if winner and (uf.healthBarTexture == nil or uf.healthBarTexture == "none") then
				uf.healthBarTexture = winner
			end
			for _, unit in ipairs({ "player", "target", "focus", "pet", "totPet", "boss" }) do
				local s = uf[unit]
				if type(s) == "table" then s.healthBarTexture = nil end
			end
		end,
	},
	{
		id = "qt_minimap_ensure_enabled_v2",
		body = function(ctx)
			local addons = ctx.profile.addons
			if type(addons) ~= "table" then return end
			local qt = addons.EllesmereUIQuestTracker
				and addons.EllesmereUIQuestTracker.questTracker
			if type(qt) == "table" then
				if not qt.enabled then qt.enabled = true end
				if not qt.visibility then qt.visibility = "always" end
			end
			local mm = addons.EllesmereUIMinimap
				and addons.EllesmereUIMinimap.minimap
			if type(mm) == "table" then
				if not mm.enabled then mm.enabled = true end
				if not mm.visibility then mm.visibility = "always" end
			end
		end,
	},
	{
		id = "chat_bubbles_to_blizzskin_v1",
		body = function(ctx)
			local chat = ctx.profile.addons and ctx.profile.addons.EllesmereUIChat
			if not chat or type(chat.chatBubbles) ~= "table" then return end
			if ctx.profile.chatBubbles == nil then
				ctx.profile.chatBubbles = chat.chatBubbles
			end
			chat.chatBubbles = nil
		end,
	},
	{
		id = "np_border_v5",
		body = function(ctx)
			local np = ctx.profile.addons and ctx.profile.addons.EllesmereUINameplates
			if not np then return end
			local oldStyle = np.borderStyle
			if oldStyle == "none" then
				np.showBorder = false
			else
				np.showBorder = true
			end
			np.borderSize = 1
			np.borderStyle = nil
			np.simpleBorderSize = nil
		end,
	},
	{
		id = "uf_absorb_style_dropdown_v1",
		body = function(ctx)
			local uf = ctx.profile.addons and ctx.profile.addons.EllesmereUIUnitFrames
			if not uf then return end
			for _, unitKey in ipairs({ "player", "target", "playerTarget", "focus" }) do
				local unitCfg = uf[unitKey]
				if unitCfg then
					local v = unitCfg.showPlayerAbsorb
					if v == true then
						unitCfg.showPlayerAbsorb = "striped"
					elseif v == false or v == nil then
						unitCfg.showPlayerAbsorb = "none"
					end
				end
			end
		end,
	},
	{
		id = "uf_absorb_style_boolean_sweep_v1",
		body = function(ctx)
			local uf = ctx.profile.addons and ctx.profile.addons.EllesmereUIUnitFrames
			if type(uf) ~= "table" then return end
			for _, unitCfg in pairs(uf) do
				if type(unitCfg) == "table" then
					local v = unitCfg.showPlayerAbsorb
					if v == true then
						unitCfg.showPlayerAbsorb = "striped"
					elseif v ~= nil and type(v) ~= "string" then
						unitCfg.showPlayerAbsorb = "none"
					end
				end
			end
		end,
	},
	{
		id = "rf_split_absorb_edge_mode_v1",
		body = function(ctx)
			local rf = ctx.profile.addons and ctx.profile.addons.EllesmereUIRaidFrames
			if type(rf) ~= "table" then return end
			local function split(oldKey, absKey, healKey)
				local old = rf[oldKey]
				if old == nil then return end
				local mode = (old == true) and "right" or "overlay"
				if rf[absKey] == nil then rf[absKey] = mode end
				if rf[healKey] == nil then rf[healKey] = mode end
			end
			split("absorbFromRightEdge", "absorbEdgeMode", "healAbsorbEdgeMode")
			split("party_absorbFromRightEdge", "party_absorbEdgeMode", "party_healAbsorbEdgeMode")
		end,
	},
	{
		id = "uf_castbar_standalone_v1",
		body = function(ctx)
			local uf = ctx.profile.addons and ctx.profile.addons.EllesmereUIUnitFrames
			if not uf then return end
			local positions = uf.positions or uf.unlockPositions
			local anchors = ImportAnchors(ctx.profile)

			local playerS = uf.player
			if playerS then
				local pw = playerS.playerCastbarWidth or 0
				if pw == 0 then
					playerS.playerCastbarWidth = playerS.frameWidth or 181
				end
				local ph = playerS.playerCastbarHeight or 0
				if ph == 0 then
					playerS.playerCastbarHeight = playerS.castbarHeight or 14
				end
			end

			for _, unitKey in ipairs({ "target", "focus" }) do
				local s = uf[unitKey]
				if s then
					local cw = s.castbarWidth or 0
					if cw == 0 then
						s.castbarWidth = s.frameWidth or 181
					end
				end
			end

			if anchors then
				local CASTBAR_DEFAULTS = {
					{ key = "playerCastbar", target = "player" },
					{ key = "targetCastbar", target = "target" },
					{ key = "focusCastbar", target = "focus" },
				}
				for _, def in ipairs(CASTBAR_DEFAULTS) do
					local hasPos = positions and positions[def.key]
					local hasAnchor = anchors[def.key]
					if not hasPos and not hasAnchor then
						anchors[def.key] = {
							target = def.target,
							side = "BOTTOM",
							offsetX = 0,
							offsetY = 0,
						}
					end
				end
			end
		end,
	},
	{
		id = "mythic_timer_default_pos_to_otf_v2",
		body = function(ctx)
			local emt = ctx.profile.addons and ctx.profile.addons.EllesmereUIMythicTimer
			if not emt then return end
			local pos = emt.standalonePos
			if not pos then return end
			if pos.centerX and pos.centerY
				and math.abs(pos.centerX) < 3 and math.abs(pos.centerY) < 3 then
				emt.standalonePos = nil
			end
		end,
	},
	{
		id = "np_stacking_spacing_50_to_75_v2",
		body = function(ctx)
			-- Retail creates the Nameplates table when missing; an import must not
			-- gain a module the string did not carry.
			local np = ctx.profile.addons and ctx.profile.addons.EllesmereUINameplates
			if type(np) ~= "table" then return end
			local cur = np.stackSpacingScale
			if not cur or cur == 50 then
				np.stackSpacingScale = 90
			end
		end,
	},
	{
		id = "ab_queuestatus_reset_visibility_v1",
		body = function(ctx)
			local ab = ctx.profile.addons and ctx.profile.addons.EllesmereUIActionBars
			local qs = ab and ab.bars and ab.bars.QueueStatus
			if type(qs) ~= "table" then return end
			qs.barVisibility = "always"
			qs.alwaysHidden = false
			qs.mouseoverEnabled = false
			qs.mouseoverAlpha = 1
			qs._savedBarAlpha = nil
			qs.combatHideEnabled = false
			qs.combatShowEnabled = false
			qs.housingHideEnabled = false
			qs.visHideHousing = false
			qs.visOnlyInstances = false
		end,
	},
	{
		id = "uf_per_unit_portrait_style_v1",
		body = function(ctx)
			local uf = ctx.profile.addons and ctx.profile.addons.EllesmereUIUnitFrames
			if not uf then return end
			local global = uf.portraitStyle or "attached"
			for _, unitKey in ipairs({ "player", "target", "focus" }) do
				local s = uf[unitKey]
				if s and s.portraitStyle == nil then
					s.portraitStyle = global
				end
			end
		end,
	},
	{
		id = "uf_split_totpet_into_tot_focus_v1",
		body = function(ctx)
			local uf = ctx.profile.addons and ctx.profile.addons.EllesmereUIUnitFrames
			if type(uf) ~= "table" then return end
			local tp = uf.totPet
			if type(tp) ~= "table" then return end
			uf.targettarget = DCopy(tp)
			uf.focustarget = DCopy(tp)
			uf.totPet = nil
		end,
	},
	{
		id = "uf_boss_simple_text_seed_v1",
		body = function(ctx)
			local uf = ctx.profile.addons and ctx.profile.addons.EllesmereUIUnitFrames
			local b = type(uf) == "table" and uf.boss
			if type(b) ~= "table" then return end
			if b.simpleDebuffCooldownTextSize == nil
				and type(b.debuffCooldownTextSize) == "number" and b.debuffCooldownTextSize ~= 10 then
				b.simpleDebuffCooldownTextSize = b.debuffCooldownTextSize
			end
			if b.simpleDebuffShowCooldownText == nil and b.debuffShowCooldownText == true then
				b.simpleDebuffShowCooldownText = true
			end
			if b.simpleBuffCooldownTextSize == nil
				and type(b.buffCooldownTextSize) == "number" and b.buffCooldownTextSize ~= 10 then
				b.simpleBuffCooldownTextSize = b.buffCooldownTextSize
			end
			if b.simpleBuffShowCooldownText == nil and b.buffShowCooldownText == true then
				b.simpleBuffShowCooldownText = true
			end
		end,
	},
	{
		id = "unlock_grow_independent_v1",
		body = function(ctx)
			local anchors = ImportAnchors(ctx.profile)
			if not anchors then return end

			local HORIZ_MAP = { LEFT = "LEFT", RIGHT = "RIGHT", TOP = "CENTER", BOTTOM = "CENTER" }
			local VERT_MAP = { TOP = "UP", BOTTOM = "DOWN", LEFT = "CENTER", RIGHT = "CENTER" }

			local cdm = ctx.profile.addons and ctx.profile.addons.EllesmereUICooldownManager
			local cdmBars = cdm and cdm.cdmBars and cdm.cdmBars.bars
			if cdmBars then
				for _, bar in ipairs(cdmBars) do
					local anchorKey = "CDM_" .. bar.key
					local ai = anchors[anchorKey]
					if ai and ai.side and not bar.growDirection then
						bar.growDirection = "CENTER"
					end
				end
			end

			local ab = ctx.profile.addons and ctx.profile.addons.EllesmereUIActionBars
			local abBars = ab and ab.bars
			if abBars then
				local AB_KEYS = {
					MainBar = true, Bar2 = true, Bar3 = true, Bar4 = true,
					Bar5 = true, Bar6 = true, Bar7 = true, Bar8 = true,
				}
				for barKey, cfg in pairs(abBars) do
					if AB_KEYS[barKey] then
						local ai = anchors[barKey]
						if ai and ai.side then
							local cur = cfg.growDirection
							if not cur or cur == "up" then
								local isVert = (cfg.orientation == "vertical")
								local map = isVert and VERT_MAP or HORIZ_MAP
								cfg.growDirection = (map[ai.side] or "CENTER"):lower()
							end
						end
					end
				end
			end
		end,
	},
	{
		id = "resource_bars_threshold_specs_v1",
		body = function(ctx)
			local erb = ctx.profile.addons and ctx.profile.addons.EllesmereUIResourceBars
			local sec = erb and erb.secondary
			if not sec then return end
			if sec.thresholdSpecs then return end
			if sec.thresholdEnabled then
				sec.thresholdSpecs = {
					{
						specIDs = { 0 },
						hashValues = sec.tickValues or "",
						thresholdCount = sec.thresholdCount or 3,
						thresholdPartialOnly = sec.thresholdPartialOnly or false,
					},
				}
			else
				sec.thresholdSpecs = {}
			end
		end,
	},
	{
		id = "resource_bars_power_threshold_specs_v1",
		body = function(ctx)
			local erb = ctx.profile.addons and ctx.profile.addons.EllesmereUIResourceBars
			local pri = erb and erb.primary
			if not pri then return end
			if pri.thresholdSpecs then return end
			if pri.thresholdEnabled then
				pri.thresholdSpecs = {
					{
						specIDs = { 0 },
						thresholdEnabled = true,
						thresholdPct = pri.thresholdPct or 30,
						thresholdPartialOnly = pri.thresholdPartialOnly or false,
						thresholdR = pri.thresholdR or 1.0,
						thresholdG = pri.thresholdG or 0.2,
						thresholdB = pri.thresholdB or 0.2,
						thresholdA = pri.thresholdA or 1,
					},
				}
			else
				pri.thresholdSpecs = {}
			end
		end,
	},
	{
		id = "resource_bars_health_threshold_specs_v1",
		body = function(ctx)
			local erb = ctx.profile.addons and ctx.profile.addons.EllesmereUIResourceBars
			local hp = erb and erb.health
			if not hp then return end
			if hp.thresholdSpecs then return end
			if hp.thresholdEnabled then
				hp.thresholdSpecs = {
					{
						specIDs = { 0 },
						thresholdEnabled = true,
						thresholdPct = hp.thresholdPct or 30,
						thresholdR = hp.thresholdR or 1.0,
						thresholdG = hp.thresholdG or 0.2,
						thresholdB = hp.thresholdB or 0.2,
						thresholdA = hp.thresholdA or 1,
					},
				}
			else
				hp.thresholdSpecs = {}
			end
		end,
	},
	{
		id = "ab_default_grow_to_center_v1",
		body = function(ctx)
			local ab = ctx.profile.addons and ctx.profile.addons.EllesmereUIActionBars
			local abBars = ab and ab.bars
			if not abBars then return end
			for _, cfg in pairs(abBars) do
				if type(cfg) == "table" and (not cfg.growDirection or cfg.growDirection == "up") then
					cfg.growDirection = "center"
				end
			end
		end,
	},
	{
		id = "enhance_five_bar_off_existing_v1",
		body = function(ctx)
			local erb = ctx.profile.addons and ctx.profile.addons.EllesmereUIResourceBars
			local sec = erb and erb.secondary
			if sec and sec.enhanceFiveBar == nil then
				sec.enhanceFiveBar = false
			end
		end,
	},
	{
		id = "bags_default_bag_type_v1",
		body = function(ctx)
			local bags = ctx.profile.addons and ctx.profile.addons.EllesmereUIBags
			if not bags then return end
			if bags.bagDefaultBagType ~= nil then return end
			bags.bagDefaultBagType = (bags.bagDefaultOneBag == true) and "onebag" or "all"
			bags.bagDefaultOneBag = nil
		end,
	},
	{
		id = "qol_tertiary_stats_checklist_v1",
		body = function(ctx)
			-- Retail creates the QoL table when missing; an import must not gain
			-- a module the string did not carry.
			local qol = ctx.profile.addons and ctx.profile.addons.EllesmereUIQoL
			if type(qol) ~= "table" then return end

			local enabled = qol.showTertiaryStats
			if enabled == nil then
				enabled = EllesmereUIDB and EllesmereUIDB.showTertiaryStats
			end
			if type(qol.secondaryStatsHidden) ~= "table" then
				qol.secondaryStatsHidden = {}
			end
			local hidden = enabled ~= true
			qol.secondaryStatsHidden.leech = hidden
			qol.secondaryStatsHidden.avoidance = hidden
			qol.secondaryStatsHidden.speed = hidden
			qol.showTertiaryStats = nil
		end,
	},
	{
		id = "texture_kringel_diamonds_to_blinkii_v1",
		body = function(ctx)
			local addons = ctx.profile.addons
			if type(addons) ~= "table" then return end
			local function swap(t, depth)
				if type(t) ~= "table" or depth > 8 then return end
				for k, v in pairs(t) do
					if v == "kringel-diamonds" then
						t[k] = "blinkii-diamonds"
					elseif type(v) == "table" then
						swap(v, depth + 1)
					end
				end
			end
			local MODULES = {
				"EllesmereUIUnitFrames", "EllesmereUIRaidFrames", "EllesmereUINameplates",
				"EllesmereUIResourceBars", "EllesmereUIDamageMeters",
			}
			for _, name in ipairs(MODULES) do
				swap(addons[name], 1)
			end
		end,
	},
	{
		id = "minimap_coords_mode_position_v1",
		body = function(ctx)
			local emm = ctx.profile.addons and ctx.profile.addons.EllesmereUIMinimap
			if type(emm) ~= "table" then return end
			local mm = emm.minimap
			if type(mm) ~= "table" then
				mm = {}
				emm.minimap = mm
			end
			if mm.coordsMode ~= nil then return end
			if mm.coordsBelow then
				mm.coordsMode = "always"
				mm.coordsPosition = "belowMap"
			else
				mm.coordsMode = "hover"
				mm.coordsPosition = "topLeft"
				mm.coordsBelowOffsetX = nil
				mm.coordsBelowOffsetY = nil
			end
		end,
	},
	{
		id = "minimap_clock_location_mode_v2",
		body = function(ctx)
			local emm = ctx.profile.addons and ctx.profile.addons.EllesmereUIMinimap
			if type(emm) ~= "table" then return end
			local mm = emm.minimap
			if type(mm) ~= "table" then
				mm = {}
				emm.minimap = mm
			end
			if mm.showClock == false then
				mm.clockMode = "none"
			elseif mm.clockMode == nil then
				mm.clockMode = (mm.clockInside == false) and "edge" or "inside"
			end
			if mm.hideZoneText == true then
				mm.locationMode = "none"
			elseif mm.locationMode == nil then
				mm.locationMode = mm.zoneInside and "inside" or "edge"
			end
		end,
	},
	{
		id = "minimap_omnium_folio_mode_v1",
		body = function(ctx)
			local emm = ctx.profile.addons and ctx.profile.addons.EllesmereUIMinimap
			if type(emm) ~= "table" then return end
			local mm = emm.minimap
			if type(mm) ~= "table" then
				mm = {}
				emm.minimap = mm
			end
			if mm.omniumFolioMode == nil then
				mm.omniumFolioMode = (mm.showOmniumFolio == false) and "never" or "always"
			end
		end,
	},
	{
		id = "uf_clear_stale_attached_power_border_v1",
		body = function(ctx)
			local uf = ctx.profile.addons and ctx.profile.addons.EllesmereUIUnitFrames
			if type(uf) ~= "table" then return end
			local attachedDefault = { player = true, target = true, focus = true, boss = true }
			for unitKey, s in pairs(uf) do
				if type(s) == "table"
					and type(s.powerBorderSize) == "number" and s.powerBorderSize > 0 then
					local pos = s.powerPosition
					if pos == nil and attachedDefault[unitKey] then pos = "below" end
					if pos == "above" or pos == "below" then
						s.powerBorderSize = nil
					end
				end
			end
		end,
	},
	{
		id = "qol_movement_alert_precision_normalize_v2",
		body = function(ctx)
			local qol = ctx.profile.addons and ctx.profile.addons.EllesmereUIQoL
			local ma = qol and qol.movementAlert
			if type(ma) ~= "table" or ma.precision == nil then return end
			ma.precision = (tonumber(ma.precision) or 1) > 0 and 1 or 0
		end,
	},
	{
		id = "uf_player_cast_target_none_v1",
		body = function(ctx)
			local uf = ctx.profile.addons and ctx.profile.addons.EllesmereUIUnitFrames
			local p = uf and uf.player
			if type(p) == "table" then p.showCastTarget = false end
		end,
	},
	{
		id = "rf_dispellable_debuff_party_section_v1",
		body = function(ctx)
			local rf = ctx.profile.addons and ctx.profile.addons.EllesmereUIRaidFrames
			if type(rf) ~= "table" then return end
			local ss = type(rf.partySyncSections) == "table" and rf.partySyncSections or nil
			local wasLive = (ss and ss.debuffDisplay == false) and true or false
			local willBeLive = (ss and ss.dispels == false) and true or false
			if wasLive == willBeLive then return end
			rf.party_dispellableDebuffLocation = nil
			rf.party_dispellableDebuffGrowDirection = nil
			rf.party_dispellableDebuffOffsetX = nil
			rf.party_dispellableDebuffOffsetY = nil
			rf.party_dispellableDebuffSize = nil
		end,
	},
	{
		id = "rf_threat_border_party_section_v2",
		body = function(ctx)
			local rf = ctx.profile.addons and ctx.profile.addons.EllesmereUIRaidFrames
			if type(rf) ~= "table" then return end
			if rf.party_showThreat ~= nil then
				if rf.party_showThreat == false then rf.party_threatBorderSize = 0 end
				rf.party_showThreat = nil
			end
			if rf.party_threatBorderSize == nil then return end
			local ss = type(rf.partySyncSections) == "table" and rf.partySyncSections or nil
			local wasLive = (ss and ss.indicators == false) and true or false
			local willBeLive = (ss and ss.healthBar == false) and true or false
			if wasLive ~= willBeLive then
				rf.party_threatBorderSize = nil
			end
		end,
	},
	{
		id = "erb_power_form_mode_moonkin_bucket_v1",
		body = function(ctx)
			local erb = ctx.profile.addons and ctx.profile.addons.EllesmereUIResourceBars
			local pri = erb and erb.primary
			if not pri or not pri.thresholdFormMode then return end
			local entries = pri.thresholdSpecs
			if type(entries) ~= "table" or #entries == 0 then return end
			local manaEntry
			for _, entry in ipairs(entries) do
				if type(entry) == "table" then
					if entry.formKey == "moonkin" then return end
					if entry.formKey == "mana" then manaEntry = entry end
				end
			end
			if not manaEntry then return end
			local moonkinEntry = DCopy(manaEntry)
			moonkinEntry.formKey = "moonkin"
			entries[#entries + 1] = moonkinEntry
		end,
	},
	{
		id = "erb_moonkin_form_bucket_v1",
		body = function(ctx)
			local erb = ctx.profile.addons and ctx.profile.addons.EllesmereUIResourceBars
			if not erb then return end
			local function SeedMoonkin(sectionKey)
				local sec = erb[sectionKey]
				if not sec then return end
				for _, field in ipairs({ "textDisabledForms", "barDisabledForms" }) do
					local df = sec[field]
					if type(df) == "table" and df.mana and df.moonkin == nil then
						df.moonkin = true
					end
				end
			end
			SeedMoonkin("health")
			SeedMoonkin("primary")
		end,
	},
	{
		id = "rf_merge_groups_growth_axis_v1",
		body = function(ctx)
			local rf = ctx.profile.addons and ctx.profile.addons.EllesmereUIRaidFrames
			if type(rf) ~= "table" then return end
			if not rf.mergeGroups then return end
			local function isVert(g) return g == "UP" or g == "DOWN" end
			local gg, ug = rf.groupGrowth or "RIGHT", rf.unitGrowth or "DOWN"
			if isVert(gg) == isVert(ug) then
				ug = isVert(gg) and "RIGHT" or "DOWN"
				rf.unitGrowth = ug
			end
			local overrides = rf.raidSizeOverrides
			if type(overrides) ~= "table" then return end
			for _, ov in pairs(overrides) do
				if type(ov) == "table" then
					local ogg = ov.groupGrowth or gg
					local oug = ov.unitGrowth or ug
					if isVert(ogg) == isVert(oug) then
						ov.unitGrowth = isVert(ogg) and "RIGHT" or "DOWN"
					end
				end
			end
		end,
	},
	{
		id = "np_important_cast_glow_style_reindex_v1",
		body = function(ctx)
			local np = ctx.profile.addons and ctx.profile.addons.EllesmereUINameplates
			if type(np) ~= "table" then return end
			if np.importantCastGlowStyle == 4 then
				np.importantCastGlowStyle = 3
			end
		end,
	},
	{
		id = "uf_debuff_filter_tracked_only_v1",
		body = function(ctx)
			local uf = ctx.profile.addons and ctx.profile.addons.EllesmereUIUnitFrames
			if type(uf) ~= "table" then return end
			for _, unitKey in ipairs({ "target", "focus", "boss" }) do
				local s = uf[unitKey]
				if type(s) == "table" and s.debuffFilterMode == nil
					and s.onlyPlayerDebuffs ~= true and s.debuffPriorityAura ~= true
					and type(s.debuffInclude) == "table" then
					for _, on in pairs(s.debuffInclude) do
						if on then
							s.debuffFilterMode = "tracked"
							break
						end
					end
				end
			end
		end,
	},
	{
		id = "uf_visibility_never_keeps_frame_v1",
		body = function(ctx)
			local UNITS = { "player", "target", "focus" }
			local uf = ctx.profile.addons and ctx.profile.addons.EllesmereUIUnitFrames
			local ef = uf and uf.enabledFrames
			if type(ef) == "table" then
				for _, unitKey in ipairs(UNITS) do
					if ef[unitKey] == false then ef[unitKey] = nil end
				end
			end
			local stale = {}
			for _, unitKey in ipairs(UNITS) do
				stale["EllesmereUIUnitFrames\31enabledFrames\30" .. unitKey] = true
			end
			local function strip(store)
				if type(store) ~= "table" then return end
				for i = #store, 1, -1 do
					local e = store[i]
					local vals = type(e) == "table" and e.values
					if type(vals) == "table" then
						for _, m in pairs(vals) do
							if type(m) == "table" then
								for fkey in pairs(m) do
									if stale[fkey] then m[fkey] = nil end
								end
							end
						end
						if type(vals.default) ~= "table" or next(vals.default) == nil then
							table.remove(store, i)
						end
					end
				end
			end
			strip(ctx.profile.specOverrides)
			strip(ctx.profile.condOverrides)
		end,
	},
}

-- Runs every migration the profile has not stamped yet, in retail order.
-- Returns the number run and a list of failed ids.
function R.Migrate(data, name)
	local ran, failed = 0, {}
	if type(data) ~= "table" then
		return ran, failed
	end
	for _, m in ipairs(R.MIGRATIONS) do
		if type(data._migrations) ~= "table" or not data._migrations[m.id] then
			local ok = pcall(m.body, { profile = data, profileName = name or "Default" })
			if ok then
				if type(data._migrations) ~= "table" then
					data._migrations = {}
				end
				data._migrations[m.id] = true
				ran = ran + 1
			else
				failed[#failed + 1] = m.id
			end
		end
	end
	return ran, failed
end
