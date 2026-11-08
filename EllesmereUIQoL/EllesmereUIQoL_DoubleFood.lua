-------------------------------------------------------------------------------
--  EllesmereUIQoL_DoubleFood.lua -- Double Food Announce, part of Raid Tools
--
--  Announces in chat when a group member uses a second food item while they
--  are still eating the first one (the usual double click on "eat"): the
--  second item replaces the first, so one food is wasted.
--
--  Detection (buffs, not the combat log: Twinstar does not log the eating
--  aura): on UNIT_AURA the eating aura ("Food", "Food & Drink",
--  "Refreshment") of a group member is read with UnitBuff. A second item
--  restarts the aura, so its expiration time jumps forward while it is still
--  up (or it vanishes and comes straight back). Eating at a feast is skipped:
--  a banquet cast ("... Banquet", "... Feast") by the same player marks them
--  for a while.
--
--  Settings live in the Raid Tools slice (EllesmereUIQoLDB.raidTools):
--  doubleFood (off by default), doubleFoodChannel (auto | say | self).
-------------------------------------------------------------------------------
local ns = EllesmereUI
if not ns then return end

local GetTime, UnitBuff, UnitGUID = GetTime, UnitBuff, UnitGUID

local JUMP = 0.1          -- seconds the food aura's expiration must move forward to count as a new item
local FEAST_MARK = 60     -- seconds a banquet cast keeps its caster out of the check
local THROTTLE = 10       -- one announcement per player per this many seconds
local RESTART = 1         -- gone and back within this = a second item used
local WELL_FED_AFTER = 10 -- seconds of eating before Well Fed; a restart before that wastes food

-- Eating aura names (localized where a spell gives the name).
local FOOD_NAMES = {}
local function AddName(n) if n and n ~= "" then FOOD_NAMES[n] = true end end
AddName("Food"); AddName("Food & Drink"); AddName("Refreshment")
AddName(GetSpellInfo(433))      -- Food
AddName(GetSpellInfo(104934))   -- Mists Food aura (name source)

local function IsFeast(name)
	return name and (name:find("Banquet") or name:find("Feast")) and true or false
end

local eating = {}         -- [guid] = { exp = aura expiration, start = GetTime() }
local stoppedAt = {}      -- [guid] = { removed time, eating start }
local feastAt = {}        -- [guid] = GetTime() of their last banquet cast
local lastSaid = {}       -- [guid] = GetTime() of the last announcement
local debugOn = false

local function Debug(...)
	if debugOn then print("|cff0cd29dEUI food|r", ...) end
end

local function CDB()
	return ns.GetRaidToolsDB and ns.GetRaidToolsDB()
end

local function Channel()
	local c = CDB()
	local v = c and c.doubleFoodChannel or "auto"
	if v == "self" then return nil end
	if v == "say" then return "SAY" end
	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and not IsInGroup(LE_PARTY_CATEGORY_HOME) then
		return "INSTANCE_CHAT"
	end
	if IsInRaid() then return "RAID" end
	if IsInGroup() then return "PARTY" end
	return nil
end

local function Announce(guid, name)
	local now = GetTime()
	if lastSaid[guid] and now - lastSaid[guid] < THROTTLE then return end
	if feastAt[guid] and now - feastAt[guid] < FEAST_MARK then return end
	lastSaid[guid] = now
	name = name and (Ambiguate and Ambiguate(name, "none") or name:match("^[^-]+")) or "?"
	local text = name .. " ate two foods at once - the first one was wasted."
	local ch = Channel()
	if ch then
		SendChatMessage(text, ch)
	else
		local say = ns.Print or print
		say("|cff0cd29dEllesmereUI:|r " .. text)
	end
end

local function IsGroupUnit(unit)
	return unit == "player" or (unit and (unit:find("^party%d") or unit:find("^raid%d"))) and true or false
end

-- Latest expiration of any eating aura on the unit (0 = no end time), or nil.
local function FoodExpires(unit)
	local best
	for i = 1, 40 do
		local name, _, _, _, _, _, expires = UnitBuff(unit, i)
		if not name then break end
		if FOOD_NAMES[name] then
			expires = expires or 0
			if not best or expires > best then best = expires end
		end
	end
	return best
end

local function CheckUnit(unit)
	local guid = UnitGUID(unit)
	if not guid then return end
	local now = GetTime()
	local exp = FoodExpires(unit)
	local st = eating[guid]
	if not exp then
		if st then
			Debug(("%.2f food gone on %s"):format(now, unit))
			stoppedAt[guid] = { now, st.start }
			eating[guid] = nil
		end
		return
	end
	if not st then
		Debug(("%.2f food on %s, expires %.2f"):format(now, unit, exp))
		local old = stoppedAt[guid]
		stoppedAt[guid] = nil
		eating[guid] = { exp = exp, start = now }
		if old and now - old[1] <= RESTART and now - old[2] < WELL_FED_AFTER then
			Announce(guid, UnitName(unit))
		end
		return
	end
	if exp > st.exp + JUMP then
		Debug(("%.2f food on %s renewed, expires %.2f (was %.2f)"):format(now, unit, exp, st.exp))
		st.exp = exp
		Announce(guid, UnitName(unit))
	end
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(self, event, unit, spellName)
	if event == "UNIT_AURA" then
		if IsGroupUnit(unit) then CheckUnit(unit) end
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		if not IsGroupUnit(unit) then return end
		if unit == "player" then Debug(("%.2f cast %s"):format(GetTime(), tostring(spellName))) end
		if IsFeast(spellName) then
			local guid = UnitGUID(unit)
			if guid then feastAt[guid] = GetTime() end
		end
	else
		-- Zoned: forget who is eating.
		wipe(eating); wipe(stoppedAt)
	end
end)

local function Apply()
	local c = CDB()
	if debugOn or (c and c.doubleFood == true) then
		ev:RegisterEvent("UNIT_AURA")
		ev:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		ev:RegisterEvent("PLAYER_ENTERING_WORLD")
	else
		ev:UnregisterAllEvents()
		wipe(eating); wipe(stoppedAt); wipe(feastAt); wipe(lastSaid)
	end
end
ns.DoubleFoodApply = Apply

ns.applyHooks = ns.applyHooks or {}
tinsert(ns.applyHooks, function() if IsLoggedIn() then Apply() end end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
	self:UnregisterAllEvents()
	Apply()
end)

-- /euifood: prints how your own eating shows up (aura times and casts).
SLASH_EUIDOUBLEFOOD1 = "/euifood"
SlashCmdList["EUIDOUBLEFOOD"] = function()
	debugOn = not debugOn
	Apply()
	print("|cff0cd29dEUI food|r debug " .. (debugOn and "on" or "off") .. ", Double Food Announce is " .. ((CDB() or {}).doubleFood == true and "enabled" or "DISABLED"))
end
