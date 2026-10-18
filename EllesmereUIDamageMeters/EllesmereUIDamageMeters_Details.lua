-- Compatibility with the original 5.4.8 Details (r236) and newer Details APIs.
-- Details remains a separate dependency and owns its combat data and settings.
local ns = EllesmereUI
local Bridge = {}
ns.EDMDetails = Bridge

function Bridge.GetAddon()
	local d = _G.Details
	if type(d) == "table" and type(d.GetCombat) == "function" then return d end
	d = _G._detalhes
	if type(d) == "table" and type(d.GetCombat) == "function" then return d end
end

local function Fail(message)
	ns.Print("Damage Meters: " .. message)
	return false
end

local function Ready()
	local d = Bridge.GetAddon()
	if not d then
		Fail("enable a 5.4.8-compatible Details! addon and reload.")
	elseif d.initializing then
		Fail("Details! is still initializing. Please try again shortly.")
	else
		return d
	end
end

function Bridge.GetActor(container, name)
	if type(container) ~= "table" then return nil end
	if type(container.GetActor) == "function" then return container:GetActor(name) end
	local index = container._NameIndexTable and container._NameIndexTable[name]
	return index and container._ActorTable and container._ActorTable[index] or nil
end

local LEGACY_SPELL_KEYS = {
	spells = "spell_tables",
	interrupt_spells = "interrupt_spell_tables",
	dispell_spells = "dispell_spell_tables",
}

function Bridge.GetSpells(actor, key)
	if not actor then return nil end
	return actor[key] or actor[LEGACY_SPELL_KEYS[key]]
end

function Bridge.TargetAmount(actor, name)
	local targets = actor and actor.targets
	if type(targets) ~= "table" then return 0 end
	if type(targets.GetAmount) == "function" then return targets:GetAmount(name) end
	return type(targets[name]) == "number" and targets[name] or 0
end

function Bridge.IsEnemy(actor)
	if type(actor.IsNeutralOrEnemy) == "function" then return actor:IsNeutralOrEnemy() end
	if actor.flag_original then return bit.band(actor.flag_original, 0x60) ~= 0 end
	return actor.monster == true
end

function Bridge.IsLocalPlayer(actor)
	if actor.serial and actor.serial == UnitGUID("player") then return true end
	local d = Bridge.GetAddon()
	return actor.nome == (d and d.playername or UnitName("player"))
end

function Bridge.ActorDuration(actor, duration, capture)
	local d = Bridge.GetAddon()
	if d and d.time_type == 1 and type(actor.Tempo) == "function"
		and (type(d.CaptureGet) ~= "function" or d:CaptureGet(capture)) then
		return actor:Tempo()
	end
	return duration
end

local SETTINGS = {
	time_type = { min = 1, max = 2, method = "AtualizaGumpPrincipal" },
	segments_amount = { min = 1, max = 25 },
	segments_auto_erase = { min = 1, max = 3 },
	update_speed = { min = 0.05, max = 3, fractional = true, method = "SetWindowUpdateSpeed" },
	use_row_animations = { boolean = true, method = "SetUseAnimations" },
	overall_clear_newboss = { boolean = true, method = "OverallOptions" },
	overall_clear_newchallenge = { boolean = true, method = "OverallOptions" },
	cloud_capture = { boolean = true },
}

function Bridge.HasSetting(key)
	local d, spec = Bridge.GetAddon(), SETTINGS[key]
	if not d or not spec then return false end
	local expected = spec.boolean and "boolean" or "number"
	return type(d[key]) == expected and (not spec.method or type(d[spec.method]) == "function")
end

function Bridge.GetSetting(key)
	local d = Bridge.GetAddon()
	if d and Bridge.HasSetting(key) then return d[key] end
end

local function RefreshMeters()
	if ns.EDM then ns.EDM.MarkDirty() end
end

function Bridge.SetSetting(key, value)
	local d = Ready()
	if not d then return false end
	if not Bridge.HasSetting(key) then return Fail("this Details! version does not support " .. tostring(key) .. ".") end
	local spec = SETTINGS[key]
	if spec.boolean then
		if type(value) ~= "boolean" then return Fail("invalid value for " .. key .. ".") end
	elseif type(value) ~= "number" or value ~= value or value < spec.min or value > spec.max
		or (not spec.fractional and value ~= math.floor(value)) then
		return Fail("invalid value for " .. key .. ".")
	end
	if key == "update_speed" then
		d:SetWindowUpdateSpeed(value)
	elseif key == "use_row_animations" then
		d:SetUseAnimations(value)
	elseif key == "overall_clear_newboss" then
		d:OverallOptions(value, nil)
	elseif key == "overall_clear_newchallenge" then
		d:OverallOptions(nil, value)
	else
		d[key] = value
		if key == "time_type" then d:AtualizaGumpPrincipal(-1, true) end
	end
	RefreshMeters()
	return true
end

local CAPTURES = { damage = true, heal = true, energy = true, miscdata = true, aura = true }

function Bridge.HasCapture(key)
	local d = Bridge.GetAddon()
	return CAPTURES[key] and d and type(d.capture_real) == "table"
		and type(d.capture_real[key]) == "boolean" and type(d.CaptureSet) == "function" or false
end

function Bridge.GetCapture(key)
	local d = Bridge.GetAddon()
	if d and Bridge.HasCapture(key) then return d.capture_real[key] end
end

function Bridge.SetCapture(key, enabled)
	local d = Ready()
	if not d then return false end
	if not Bridge.HasCapture(key) or type(enabled) ~= "boolean" then
		return Fail("unsupported capture setting: " .. tostring(key) .. ".")
	end
	d:CaptureSet(enabled, key, true)
	RefreshMeters()
	return true
end

local OVERALL_FLAGS = { [1] = true, [2] = true, [4] = true, [8] = true, [16] = true }

function Bridge.HasOverall()
	local d = Bridge.GetAddon()
	return d and type(d.overall_flag) == "number" or false
end

function Bridge.GetOverallFlag(flag)
	local d = Bridge.GetAddon()
	return OVERALL_FLAGS[flag] and Bridge.HasOverall() and bit.band(d.overall_flag, flag) ~= 0 or false
end

function Bridge.SetOverallFlag(flag, enabled)
	local d = Ready()
	if not d then return false end
	if not OVERALL_FLAGS[flag] or not Bridge.HasOverall() or type(enabled) ~= "boolean" then
		return Fail("unsupported overall-data setting.")
	end
	if Bridge.GetOverallFlag(flag) ~= enabled then
		d.overall_flag = d.overall_flag + (enabled and flag or -flag)
	end
	return true
end

function Bridge.ResetData()
	local d = Ready()
	if not d then return false end
	if InCombatLockdown() or (type(d.IsInCombat) == "function" and d:IsInCombat()) then
		return Fail("combat data cannot be reset during combat.")
	end
	if type(d.ResetSegmentData) == "function" then
		d:ResetSegmentData()
	elseif type(d.tabela_historico) == "table" and type(d.tabela_historico.resetar) == "function" then
		d.tabela_historico:resetar()
	else
		return Fail("this Details! version has no supported data-reset API.")
	end
	return true
end

function Bridge.OpenOptions()
	local d = Ready()
	if not d then return false end
	if type(d.OpenOptionsWindow) ~= "function" or type(d.GetInstance) ~= "function" then
		return Fail("this Details! version has no supported options-window API.")
	end
	local instance = d:GetInstance(1)
	if not instance then return Fail("create a Details! window with /details before opening its advanced options.") end
	d:OpenOptionsWindow(instance, true)
	return true
end

-- Native window visibility is per character, unlike EUI appearance settings.
-- Keep only the windows we closed, including across reloads, outside profiles.
function Bridge.SetWindowsHidden(hidden)
	local root = ns.ModuleDB("EllesmereUIDamageMetersDB")
	local records = root.detailsWindowRestore
	if not hidden and not records then return true end
	local guid = UnitGUID("player")
	if not guid then return nil end
	local restore = records and records[guid]
	if not hidden and not restore then return true end
	local d = Bridge.GetAddon()
	if not d then return Fail("enable Details! to change its native window visibility.") end
	if d.initializing then return nil end
	if type(d.tabela_instancias) ~= "table" then return Fail("Details! window controls are unavailable.") end
	if hidden then
		for id, instance in ipairs(d.tabela_instancias) do
			if type(instance.IsEnabled) ~= "function" or type(instance.ShutDown) ~= "function" then
				return Fail("Details! window " .. id .. " cannot be hidden through its API.")
			end
		end
		records, restore = records or {}, restore or {}
		records[guid] = restore
		root.detailsWindowRestore = records
		for id, instance in ipairs(d.tabela_instancias) do
			if instance:IsEnabled() then
				restore[id] = true
				instance:ShutDown()
			end
		end
	else
		for id in pairs(restore) do
			local instance = d.tabela_instancias[id]
			if instance then
				if type(instance.IsEnabled) ~= "function" or type(instance.EnableInstance) ~= "function" then
					return Fail("Details! window " .. id .. " cannot be restored through its API.")
				end
				if not instance:IsEnabled() then instance:EnableInstance() end
			end
			restore[id] = nil
		end
	end
	if not next(restore) then records[guid] = nil end
	if not next(records) then root.detailsWindowRestore = nil end
	return true
end
