-- Damage Meters combat engine (5.4.8). Retail reads Blizzard's built-in meter
-- (C_DamageMeter, 12.x); 5.4.8 has none, so this file records the combat log
-- itself: damage, healing (with shield absorbs), damage taken, enemy damage
-- taken, interrupts, dispels and death recaps, per fight and Overall.
--
-- Data model (read by EllesmereUIDamageMeters_Meter.lua):
--   segment = { name, start, finish, boss, try, result ("kill" | "wipe"), bossHP (lowest %),
--               actors = { [guid] = actor }, deaths = { death } }
--   actor   = { guid, name, class, spec, group, enemy,
--               damage, healing, taken, interrupts, dispels,
--               dmgActive, healActive (activity seconds),
--               dmgSpells, healSpells, intSpells, dispSpells = { [key] = { id, pet, amount } },
--               takenFrom = { [key] = { name, class, amount } } }
--   death   = { name, class, at, time, events = { { heal, id, amount, at, source, hp, overkill, absorbed, shield },
--               ... oldest first } } (hp = health % after the event, as Details records it)
-- Fights are saved per character at logout / reload (EllesmereUIDamageMetersFights)
-- and restored when the addon loads.

local addonName = ...
local ns = EllesmereUI
local E = {}
ns.EDMEngine = E

local band = bit.band
local GetTime, UnitGUID, UnitClass, UnitName = GetTime, UnitGUID, UnitClass, UnitName
local UnitAffectingCombat, UnitIsFeignDeath = UnitAffectingCombat, UnitIsFeignDeath
local tinsert, tremove, wipe, pairs, ipairs, type = table.insert, table.remove, wipe, pairs, ipairs, type
local min, floor = math.min, math.floor

-- Combat log object flags.
local AFFIL_GROUP = 0x00000007 -- mine, party, raid
local AFFIL_MINE = 0x00000001
local REACT_FRIENDLY = 0x00000010
local REACT_HOSTILE_OR_NEUTRAL = 0x00000060
local TYPE_PLAYER = 0x00000400

local ACTIVITY_GAP = 3.5 -- seconds between hits that still count as active
local DEATH_LOG_SIZE = 32 -- Details keeps the last 32 events
local MIN_FIGHT = 2 -- fights shorter than this (without a boss or a death) are dropped
local PHANTOM_PULL = 5 -- a boss "pull" this short (or with no damage) right after a wipe on that boss is dropped
local AFTER_WIPE = 60 -- seconds after a wipe that a short scuffle (the reset, dying ghosts) belongs to it

-- Damage-absorbing auras of 5.4.8 credited as healing to their caster
-- (from the Details! 5.4.8 absorb list, MoP class spells and consumables).
local ABSORBS = {
	[48707] = true, [51052] = true, [77535] = true, -- Anti-Magic Shell / Zone, Blood Shield
	[62606] = true, -- Savage Defense
	[11426] = true, [1463] = true, [543] = true, -- Ice Barrier, Mana Shield, Mage Ward
	[118604] = true, [115295] = true, [145411] = true, [116849] = true, -- Guard, Yu'lon's Barrier, Life Cocoon
	[86273] = true, [88063] = true, [96263] = true, -- Illuminated Healing, Guarded by the Light, Sacred Shield
	[17] = true, [47753] = true, [47509] = true, [47511] = true, [47515] = true, [54704] = true, -- PW:S, Divine Aegis
	[47788] = true, [62618] = true, [81781] = true, [114908] = true, -- Guardian Spirit, PW:Barrier, Spirit Shell
	[145379] = true, -- Nature's Barrier
	[108366] = true, [7812] = true, [6229] = true, -- Soul Leech, Sacrifice, Shadow Ward
	[112048] = true, -- Shield Barrier
}

---------------------------------------------------------------------------
-- Settings (EllesmereUIDamageMetersDB.dm, defaults in the meter's CreateDefaults)
---------------------------------------------------------------------------
local function Cfg(key, default)
	local c = ns.EDM and ns.EDM.DB and ns.EDM.DB()
	local v = c and c[key]
	if v == nil then return default end
	return v
end

---------------------------------------------------------------------------
-- Change notifications: E.Listen(fn) -> fn(what), what = "start" | "stop" |
-- "reset" (all data) | "overall" (Overall cleared) | "removed" (old fights dropped) |
-- "death" (a group player died) | "sync" (numbers raised by the group sync)
---------------------------------------------------------------------------
local listeners = {}
function E.Listen(fn) listeners[#listeners + 1] = fn end
local function Fire(what)
	for i = 1, #listeners do
		local ok, err = pcall(listeners[i], what)
		if not ok then geterrorhandler()(err) end
	end
end

---------------------------------------------------------------------------
-- Group roster: player GUID -> unit, pet / guardian GUID -> owner GUID
---------------------------------------------------------------------------
local unitOf, petOwner, specOf = {}, {}, {}
local playerGUID
local byShortGUID = {} -- group sync: GUID without "0x" and leading zeros -> GUID

local function ShortGUID(guid)
	return (guid:gsub("^0[xX]", ""):gsub("^0+", ""))
end

local function ScanUnit(unit)
	local guid = UnitGUID(unit)
	if not guid then return end
	unitOf[guid] = unit
	byShortGUID[ShortGUID(guid)] = guid
	local pet = UnitGUID(unit .. "pet")
	if pet then petOwner[pet] = guid end
	if unit == "player" then
		local idx = GetSpecialization and GetSpecialization()
		local id = idx and GetSpecializationInfo(idx)
		if id and id > 0 then specOf[guid] = id end
	elseif GetInspectSpecialization then
		local id = GetInspectSpecialization(unit)
		if id and id > 0 then specOf[guid] = id end
	end
end

local function ScanRoster()
	wipe(unitOf)
	wipe(byShortGUID)
	playerGUID = UnitGUID("player")
	ScanUnit("player")
	local n = GetNumGroupMembers and GetNumGroupMembers() or 0
	if IsInRaid and IsInRaid() then
		for i = 1, n do ScanUnit("raid" .. i) end
	else
		for i = 1, n - 1 do ScanUnit("party" .. i) end
	end
end
E.ScanRoster = ScanRoster

local function AnyoneInCombat()
	if UnitAffectingCombat("player") then return true end
	for _, unit in pairs(unitOf) do
		if UnitAffectingCombat(unit) then return true end
	end
	return false
end

---------------------------------------------------------------------------
-- Segments
---------------------------------------------------------------------------
local segments = {} -- finished fights, newest first
local current -- the fight in progress, or nil
local overall
local encounterName, lastBossName
local tries = {} -- boss name -> pulls this session (back to 0 after a kill)

local function NewSegment()
	return { start = GetTime(), actors = {}, deaths = {} }
end

local function ResetOverall()
	overall = NewSegment()
	overall.isOverall = true
	overall.duration = 0
end
ResetOverall()

local function NewActor(seg, guid, name, flags)
	local a = {
		guid = guid, name = name or "Unknown",
		damage = 0, healing = 0, taken = 0, interrupts = 0, dispels = 0,
		dmgActive = 0, healActive = 0,
		dmgSpells = {}, healSpells = {}, intSpells = {}, dispSpells = {}, takenFrom = {},
	}
	if band(flags or 0, AFFIL_GROUP) ~= 0 and band(flags or 0, TYPE_PLAYER) ~= 0 then
		a.group = true
		local unit = unitOf[guid]
		local _, class
		if unit then
			_, class = UnitClass(unit)
		elseif GetPlayerInfoByGUID then
			_, class = GetPlayerInfoByGUID(guid)
		end
		a.class = class
		a.spec = specOf[guid]
	elseif band(flags or 0, REACT_HOSTILE_OR_NEUTRAL) ~= 0 then
		a.enemy = true
	end
	seg.actors[guid] = a
	return a
end

local function Actor(seg, guid, name, flags)
	return seg.actors[guid] or NewActor(seg, guid, name, flags)
end

-- Duration in seconds (a fight in progress counts up to now).
function E.Duration(seg)
	if not seg then return 0 end
	if seg.isOverall then
		local d = seg.duration or 0
		if current then d = d + (GetTime() - current.start) end
		return d
	end
	return (seg.finish or GetTime()) - seg.start
end

local function BiggestEnemy(seg)
	local best, amount = nil, 0
	for _, a in pairs(seg.actors) do
		if a.enemy and a.taken > amount then best, amount = a.name, a.taken end
	end
	return best
end

-- A fight shows as Current once the group did damage or healing in it, or
-- it is a boss fight. Until then the last finished fight stays on screen:
-- after a kill a stray hit (a DoT tick, a leftover add or ground effect)
-- starts a fight that ends half a second later with nothing in it, and
-- showing it would blank the meter for that moment.
local function ShowFight(seg)
	if seg.shown then return end
	seg.shown = true
	Fire("shown")
end

local function StartFight()
	if current then return end
	current = NewSegment()
	Fire("start")
	if encounterName then
		current.boss = true
		current.name = encounterName
		current.try = tries[encounterName]
		ShowFight(current)
	end
end

local function HasData(seg)
	if #seg.deaths > 0 then return true end
	for _, a in pairs(seg.actors) do
		if a.group and (a.damage > 0 or a.healing > 0 or a.taken > 0) then return true end
	end
	return false
end

local function GroupDamage(seg)
	local n = 0
	for _, a in pairs(seg.actors) do
		if a.group then n = n + a.damage end
	end
	return n
end

local function GroupHealing(seg)
	local n = 0
	for _, a in pairs(seg.actors) do
		if a.group then n = n + a.healing end
	end
	return n
end

local shields -- forward (shield tracking below)

-- The fight that ended last, kept or not: a death that arrives just after
-- the fight ended (your own death drops you out of combat first) joins it.
local lastStopped

local function KeepSegment(seg)
	tinsert(segments, 1, seg)
	seg.kept = true
	local keep = Cfg("segmentsToKeep", 18)
	local removed = false
	while #segments > keep do
		tremove(segments)
		removed = true
	end
	if removed then Fire("removed") end
end

local function StopFight()
	if not current then return end
	local seg = current
	current = nil
	seg.finish = GetTime()
	-- Drop shields that were already removed.
	for guid, list in pairs(shields) do
		for i = #list, 1, -1 do
			if list[i].removed then tremove(list, i) end
		end
		if #list == 0 then shields[guid] = nil end
	end
	overall.duration = (overall.duration or 0) + (seg.finish - seg.start)
	if not seg.name then seg.name = BiggestEnemy(seg) or "Combat" end
	if seg.boss and not seg.result then
		seg.result = (seg.bossHP and seg.bossHP <= 0) and "kill" or "wipe"
	end
	lastStopped = seg
	-- Not real fights, dropped: after a wipe the server can start the
	-- encounter again for a moment (a few seconds, no damage, or the boss
	-- never touched), and the reset leaves short scuffles (players taking
	-- damage or dying, nothing done). Elsewhere a fight in which the group
	-- did no damage and no healing is dropped unless someone died. Deaths
	-- of a dropped fight go to the fight just before when it ended recently.
	local prev = segments[1]
	local short = seg.finish - seg.start < PHANTOM_PULL
	local idle = GroupDamage(seg) == 0 and GroupHealing(seg) == 0
	local afterWipe = prev and prev.boss and prev.result == "wipe" and seg.start - prev.finish < AFTER_WIPE
	local phantom
	if seg.boss then
		phantom = seg.result == "wipe" and prev and prev.boss and prev.result == "wipe" and prev.name == seg.name
			and (short or GroupDamage(seg) == 0 or (seg.bossHP and seg.bossHP >= 99.5))
	else
		phantom = (afterWipe and (short or idle)) or (idle and #seg.deaths == 0)
	end
	if phantom then
		if prev and seg.start - prev.finish < AFTER_WIPE then
			for _, death in ipairs(seg.deaths) do
				death.time = death.at - prev.start
				tinsert(prev.deaths, death)
			end
			lastStopped = prev
		end
		if seg.try and tries[seg.name] == seg.try then tries[seg.name] = seg.try - 1 end
		Fire("stop")
		return
	end
	if HasData(seg) and (seg.boss or #seg.deaths > 0 or seg.finish - seg.start >= MIN_FIGHT) then
		KeepSegment(seg)
	end
	Fire("stop")
end

-- The fight shown as "Current": the one in progress once it shows (see
-- ShowFight), else the last finished one.
function E.GetCurrent()
	if current and (current.shown or not segments[1]) then return current end
	return segments[1]
end
function E.GetOverall() return overall end
function E.GetSegments() return segments end
function E.InCombat() return current ~= nil end

function E.Reset()
	if current then return false end
	wipe(segments)
	wipe(tries)
	lastStopped = nil
	ResetOverall()
	Fire("reset")
	return true
end

---------------------------------------------------------------------------
-- Recording helpers
---------------------------------------------------------------------------
-- Owner GUID / name of a group-controlled source (player itself, or the
-- owner of a pet / guardian / totem). nil when not a group member.
local function OwnerOf(guid, flags)
	if band(flags, AFFIL_GROUP) == 0 then return nil end
	if band(flags, TYPE_PLAYER) ~= 0 then return guid, true end
	local owner = petOwner[guid]
	if owner then return owner, false end
	if band(flags, AFFIL_MINE) ~= 0 then return playerGUID, false end
	return nil
end

local function OwnerName(guid)
	local unit = unitOf[guid]
	return unit and UnitName(unit) or nil
end

local function AddSpell(list, id, pet, amount)
	local key = pet and (pet .. ":" .. id) or id
	local s = list[key]
	if not s then
		s = { id = id, pet = pet, amount = 0 }
		list[key] = s
	end
	s.amount = s.amount + amount
end

local function Activity(a, field, lastField, now)
	local last = a[lastField]
	if last then
		local gap = now - last
		if gap > 0 and gap <= ACTIVITY_GAP then a[field] = a[field] + gap end
	end
	a[lastField] = now
end

local function AddTaken(a, key, name, class, amount)
	local t = a.takenFrom[key]
	if not t then
		t = { name = name, class = class, amount = 0 }
		a.takenFrom[key] = t
	end
	t.amount = t.amount + amount
end

-- Death logs: the last events taken by each group player, with the
-- player's health right after each one (Details' death log).
local deathLog = {}
local function HealthPct(guid)
	local unit = unitOf[guid]
	if not unit or not UnitHealth or not UnitHealthMax then return nil end
	local max = UnitHealthMax(unit)
	if not max or max <= 0 then return nil end
	return min(100, floor(100 * (UnitHealth(unit) or 0) / max + 0.5))
end
local function LogEvent(guid, heal, id, amount, source, overkill, absorbed, shield, instakill)
	local log = deathLog[guid]
	if not log then
		log = {}
		deathLog[guid] = log
	end
	log[#log + 1] = {
		heal = heal, id = id, amount = amount, at = GetTime(), source = source, hp = HealthPct(guid),
		overkill = overkill and overkill > 0 and overkill or nil,
		absorbed = absorbed and absorbed > 0 and absorbed or nil,
		shield = shield or nil,
		instakill = instakill or nil,
	}
	if #log > DEATH_LOG_SIZE then tremove(log, 1) end
end

---------------------------------------------------------------------------
-- Damage / healing
---------------------------------------------------------------------------
local function RecordDamageToSeg(seg, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, id, amount, now)
	local owner, isPlayer = OwnerOf(srcGUID, srcFlags)
	-- Damage done by the group (not to friendly units).
	if owner and band(dstFlags, REACT_FRIENDLY) == 0 then
		local ownerName = isPlayer and srcName or OwnerName(owner) or srcName
		local a = Actor(seg, owner, ownerName, (srcFlags and isPlayer) and srcFlags or bit.bor(AFFIL_GROUP, TYPE_PLAYER))
		a.damage = a.damage + amount
		AddSpell(a.dmgSpells, id, not isPlayer and srcName or nil, amount)
		Activity(a, "dmgActive", "dmgLast", now)
		if seg == current then ShowFight(seg) end
		if band(dstFlags, REACT_HOSTILE_OR_NEUTRAL) ~= 0 then
			local enemy = Actor(seg, dstGUID, dstName, dstFlags)
			enemy.taken = enemy.taken + amount
			AddTaken(enemy, owner, ownerName, a.class, amount)
		end
	end
	-- Damage taken by group players.
	if band(dstFlags, AFFIL_GROUP) ~= 0 and band(dstFlags, TYPE_PLAYER) ~= 0 then
		local a = Actor(seg, dstGUID, dstName, dstFlags)
		a.taken = a.taken + amount
		local key, name, class = srcGUID or srcName or "?", srcName or "Unknown", nil
		if owner then
			local oa = seg.actors[owner]
			key, name, class = owner, oa and oa.name or OwnerName(owner) or srcName, oa and oa.class
		end
		AddTaken(a, key, name, class, amount)
	end
end

local function Damage(srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, id, amount, absorbed, school, overkill)
	if dstGUID and band(dstFlags, AFFIL_GROUP) ~= 0 and band(dstFlags, TYPE_PLAYER) ~= 0 and amount and amount > 0 then
		LogEvent(dstGUID, false, id, amount, srcName, overkill, absorbed)
	end
	if absorbed and absorbed > 0 then E.CreditAbsorb(dstGUID, dstName, dstFlags, absorbed) end
	if not amount or amount <= 0 then return end
	if not current then
		-- A fight starts on hostile damage done or taken by the group.
		local srcGroup = band(srcFlags, AFFIL_GROUP) ~= 0
		local dstGroup = band(dstFlags, AFFIL_GROUP) ~= 0
		if not (srcGroup or dstGroup) then return end
		if band(srcFlags, REACT_FRIENDLY) ~= 0 and band(dstFlags, REACT_FRIENDLY) ~= 0 then return end
		StartFight()
	end
	local now = GetTime()
	RecordDamageToSeg(current, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, id, amount, now)
	RecordDamageToSeg(overall, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, id, amount, now)
end

local function RecordHealToSeg(seg, owner, ownerName, isPlayer, srcName, srcFlags, id, amount, now)
	local a = Actor(seg, owner, ownerName, isPlayer and srcFlags or bit.bor(AFFIL_GROUP, TYPE_PLAYER))
	a.healing = a.healing + amount
	AddSpell(a.healSpells, id, not isPlayer and srcName or nil, amount)
	Activity(a, "healActive", "healLast", now)
	if seg == current then ShowFight(seg) end
end

local function Heal(srcGUID, srcName, srcFlags, dstGUID, dstFlags, id, amount, overheal, shield)
	local effective = (amount or 0) - (overheal or 0)
	if dstGUID and band(dstFlags, AFFIL_GROUP) ~= 0 and band(dstFlags, TYPE_PLAYER) ~= 0 and effective > 0 then
		LogEvent(dstGUID, true, id, effective, srcName, nil, nil, shield)
	end
	if not current or effective <= 0 then return end
	if band(dstFlags, REACT_FRIENDLY) == 0 then return end
	local owner, isPlayer = OwnerOf(srcGUID, srcFlags)
	if not owner then return end
	local ownerName = isPlayer and srcName or OwnerName(owner) or srcName
	local now = GetTime()
	RecordHealToSeg(current, owner, ownerName, isPlayer, srcName, srcFlags, id, effective, now)
	RecordHealToSeg(overall, owner, ownerName, isPlayer, srcName, srcFlags, id, effective, now)
end

---------------------------------------------------------------------------
-- Shields: damage absorbed on a target is credited to the oldest active
-- absorb aura on it, as healing by that aura's caster.
---------------------------------------------------------------------------
shields = {} -- [dstGUID] = { { src, srcName, srcFlags, id, at, removed }, ... }

local function ShieldApplied(srcGUID, srcName, srcFlags, dstGUID, id)
	local list = shields[dstGUID]
	if not list then
		list = {}
		shields[dstGUID] = list
	end
	for i = 1, #list do
		local s = list[i]
		if s.id == id and s.src == srcGUID then
			s.removed = nil
			return
		end
	end
	list[#list + 1] = { src = srcGUID, srcName = srcName, srcFlags = srcFlags, id = id, at = GetTime() }
end

local function ShieldRemoved(srcGUID, dstGUID, id)
	local list = shields[dstGUID]
	if not list then return end
	for i = 1, #list do
		local s = list[i]
		if s.id == id and s.src == srcGUID then
			-- The absorb that broke the shield is logged after the removal.
			s.removed = GetTime()
			return
		end
	end
end

function E.CreditAbsorb(dstGUID, dstName, dstFlags, absorbed)
	local list = dstGUID and shields[dstGUID]
	if not list then return end
	local now = GetTime()
	local i = 1
	while i <= #list do
		local s = list[i]
		if s.removed and now - s.removed > 0.3 then
			tremove(list, i)
		else
			i = i + 1
		end
	end
	local s = list[1]
	if s then Heal(s.src, s.srcName, s.srcFlags, dstGUID, dstFlags, s.id, absorbed, 0, true) end
end

---------------------------------------------------------------------------
-- Interrupts, dispels, deaths
---------------------------------------------------------------------------
local function Count(srcGUID, srcName, srcFlags, id, field, listField)
	if not current then return end
	local owner, isPlayer = OwnerOf(srcGUID, srcFlags)
	if not owner then return end
	local ownerName = isPlayer and srcName or OwnerName(owner) or srcName
	for _, seg in ipairs({ current, overall }) do
		local a = Actor(seg, owner, ownerName, isPlayer and srcFlags or bit.bor(AFFIL_GROUP, TYPE_PLAYER))
		a[field] = a[field] + 1
		AddSpell(a[listField], id, not isPlayer and srcName or nil, 1)
	end
end

local DEATH_JOIN = 5 -- seconds after a fight ended that a death still belongs to it
local diedAt = {} -- guid -> time of the last recorded death (UNIT_DIED and PLAYER_DEAD both report yours)
local lastDeath = {} -- guid -> that death
local SendDeath -- forward (group sync below)

-- Records a death of a group player. synced: reported by another EllesmereUI
-- user (events = their killing blow only); a death seen here afterwards
-- replaces those events with the full recap.
local function AddDeath(dstGUID, dstName, events, synced)
	local unit = unitOf[dstGUID]
	local now = GetTime()
	if diedAt[dstGUID] and now - diedAt[dstGUID] < DEATH_JOIN then
		local known = lastDeath[dstGUID]
		if not synced and known and known.synced then
			known.events, known.synced = events, nil
			Fire("death")
		end
		return
	end
	diedAt[dstGUID] = now
	local seg = current
	if not seg and lastStopped and now - lastStopped.finish <= DEATH_JOIN then
		seg = lastStopped
		if not seg.kept then KeepSegment(seg) end
	end
	seg = seg or segments[1]
	local class
	if unit then
		local _
		_, class = UnitClass(unit)
	end
	local death = { name = dstName, class = class, at = now, events = events, synced = synced or nil }
	lastDeath[dstGUID] = death
	if seg then
		death.time = now - seg.start
		tinsert(seg.deaths, death)
	end
	overall.deaths[#overall.deaths + 1] = death
	if not synced then SendDeath(dstGUID, events) end
	Fire("death")
	return true
end

local function Died(dstGUID, dstName, dstFlags)
	if not dstGUID or band(dstFlags, AFFIL_GROUP) == 0 or band(dstFlags, TYPE_PLAYER) == 0 then return end
	local unit = unitOf[dstGUID]
	if unit and UnitIsFeignDeath and UnitIsFeignDeath(unit) then return end
	local events = deathLog[dstGUID] or {}
	deathLog[dstGUID] = nil
	AddDeath(dstGUID, dstName, events)
end

---------------------------------------------------------------------------
-- Combat log dispatch (5.4.8 COMBAT_LOG_EVENT_UNFILTERED argument layout)
---------------------------------------------------------------------------
local H = {}
H.SWING_DAMAGE = function(sG, sN, sF, dG, dN, dF, amount, overkill, school, resisted, blocked, absorbed)
	Damage(sG, sN, sF, dG, dN, dF, 1, amount, absorbed, school, overkill)
end
local function SpellDamage(sG, sN, sF, dG, dN, dF, id, _, school, amount, overkill, _, resisted, blocked, absorbed)
	Damage(sG, sN, sF, dG, dN, dF, id, amount, absorbed, school, overkill)
end
H.SPELL_DAMAGE = SpellDamage
H.SPELL_PERIODIC_DAMAGE = SpellDamage
H.SPELL_BUILDING_DAMAGE = SpellDamage
H.RANGE_DAMAGE = SpellDamage
H.DAMAGE_SHIELD = SpellDamage
H.DAMAGE_SPLIT = SpellDamage
H.ENVIRONMENTAL_DAMAGE = function(sG, sN, sF, dG, dN, dF, envType, amount, overkill, school, resisted, blocked, absorbed)
	local name = envType and (envType:sub(1, 1) .. envType:sub(2):lower()) or "Environment"
	Damage(nil, name, 0, dG, dN, dF, 0, amount, absorbed, school, overkill)
end
H.SWING_MISSED = function(sG, sN, sF, dG, dN, dF, missType, offHand, amountMissed)
	if missType == "ABSORB" then E.CreditAbsorb(dG, dN, dF, amountMissed or 0) end
end
local function SpellMissed(sG, sN, sF, dG, dN, dF, id, _, _, missType, offHand, amountMissed)
	if missType == "ABSORB" then E.CreditAbsorb(dG, dN, dF, amountMissed or 0) end
end
H.SPELL_MISSED = SpellMissed
H.SPELL_PERIODIC_MISSED = SpellMissed
H.RANGE_MISSED = SpellMissed
H.DAMAGE_SHIELD_MISSED = SpellMissed
local function SpellHeal(sG, sN, sF, dG, dN, dF, id, _, _, amount, overheal)
	Heal(sG, sN, sF, dG, dF, id, amount, overheal)
end
H.SPELL_HEAL = SpellHeal
H.SPELL_PERIODIC_HEAL = SpellHeal
local function AuraOn(sG, sN, sF, dG, dN, dF, id)
	if ABSORBS[id] and sG then ShieldApplied(sG, sN, sF, dG, id) end
end
H.SPELL_AURA_APPLIED = AuraOn
H.SPELL_AURA_REFRESH = AuraOn
H.SPELL_AURA_REMOVED = function(sG, sN, sF, dG, dN, dF, id)
	if ABSORBS[id] then ShieldRemoved(sG, dG, id) end
end
-- Instant kills (no damage event): the cause of death, logged like Details.
H.SPELL_INSTAKILL = function(sG, sN, sF, dG, dN, dF, id)
	if dG and band(dF, AFFIL_GROUP) ~= 0 and band(dF, TYPE_PLAYER) ~= 0 then
		LogEvent(dG, false, id, 0, sN, nil, nil, nil, true)
	end
end
H.SPELL_INTERRUPT = function(sG, sN, sF, dG, dN, dF, id)
	Count(sG, sN, sF, id, "interrupts", "intSpells")
end
local function Dispel(sG, sN, sF, dG, dN, dF, id)
	Count(sG, sN, sF, id, "dispels", "dispSpells")
end
H.SPELL_DISPEL = Dispel
H.SPELL_STOLEN = Dispel
H.SPELL_SUMMON = function(sG, sN, sF, dG)
	local owner = OwnerOf(sG, sF)
	if owner and dG then petOwner[dG] = owner end
end
H.UNIT_DIED = function(sG, sN, sF, dG, dN, dF)
	Died(dG, dN, dF)
end

-- Your own death, in case the combat log does not report it.
function E.PlayerDied()
	Died(playerGUID or UnitGUID("player"), UnitName("player"), 0x00000511) -- mine, friendly, player
end

-- Entry point (also used by the tests): the CLEU payload after the timestamp.
function E.OnCombatLog(_, event, _, sG, sN, sF, _, dG, dN, dF, _, ...)
	local h = H[event]
	if h then h(sG, sN, sF or 0, dG, dN, dF or 0, ...) end
end

---------------------------------------------------------------------------
-- Group sync: EllesmereUI users in the group share their numbers of the
-- fight in progress about every 10 seconds, once when it ends and in full
-- when a boss encounter ends, so a
-- player teleported away or out of combat log range still sees everyone's
-- real damage, healing, damage taken, interrupts, dispels, active time
-- and the damage taken by each enemy.
-- For each player and number the higher value wins; what a sync adds shows
-- in the breakdown as "Synced from group". Deaths are shared as they
-- happen: one you missed is added with the killing blow as its recap, and
-- replaced by the full recap if you see the death yourself.
--   totals: "T\t<fight seconds>\t<guid>,<n1>,...,<n7>;<guid>,..." (base 36)
--   enemies: "E\t<fight seconds>\t<guid>,<taken>,<name>;<guid>,..."
--   hello:  "H\t1\t" when you join a group or someone joins yours, so installs
--           find each other before the first fight ("found" in chat); after a
--           /reload too. Everyone who hears it answers "R\t1\t".
--   death:  "D\t<guid>\t<spell>\t<amount>\t<overkill>\t<instakill 0/1>\t<source>"
-- Messages stay under 255 bytes and go out one per half second; only the
-- 10 enemies that took the most new damage go in a round, and a round waits
-- while the last one is still being sent.
---------------------------------------------------------------------------
local SYNC_PREFIX = "EUIDM"
local SYNC_INTERVAL = 10
local SYNC_MAX_LEN = 240
local SYNC_ALIGN = 15 -- fights whose lengths differ more than this are not the same fight
local SYNC_RECENT = 10 -- seconds after a fight ended that late totals still join it
local SYNC_ID = "Synced from group"
local SYNC_ENEMIES = 10 -- enemies per round
local SYNC_FIELDS = { "damage", "healing", "taken", "interrupts", "dispels", "dmgActive", "healActive" }
local SYNC_LIST = { damage = "dmgSpells", healing = "healSpells", interrupts = "intSpells", dispels = "dispSpells" }

local function SyncOn() return Cfg("groupSync", true) ~= false end

local function SyncChannel()
	if LE_PARTY_CATEGORY_INSTANCE and IsInGroup and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
		and not IsInGroup(LE_PARTY_CATEGORY_HOME) then
		return "INSTANCE_CHAT"
	end
	if IsInRaid and IsInRaid() then return "RAID" end
	if IsInGroup and IsInGroup() then return "PARTY" end
	return nil
end

local outbox = {} -- { text, channel, prio }, sent one per tick
local function Queue(text, prio)
	local channel = SyncChannel()
	if not channel then return end
	outbox[#outbox + 1] = { text, channel, prio }
end

-- Totals still waiting to go out.
local function Sending()
	for i = 1, #outbox do
		if outbox[i][3] == "BULK" then return true end
	end
	return false
end

local function Flush()
	local m = tremove(outbox, 1)
	if not m then return end
	local ctl = _G.ChatThrottleLib
	if ctl and ctl.SendAddonMessage then
		ctl:SendAddonMessage(m[3], SYNC_PREFIX, m[1], m[2])
	elseif SendAddonMessage then
		SendAddonMessage(SYNC_PREFIX, m[1], m[2])
	end
end

local function B36(n)
	n = floor(n or 0)
	if n <= 0 then return "" end
	local digits, out = "0123456789abcdefghijklmnopqrstuvwxyz", ""
	while n > 0 do
		local d = n % 36
		out = digits:sub(d + 1, d + 1) .. out
		n = (n - d) / 36
	end
	return out
end

-- Values of the current fight last sent or learnt from the group, per
-- player: only numbers that grew since are sent again.
local known = {}

-- Entries joined into messages of at most SYNC_MAX_LEN bytes.
local function Packer(head)
	local text, n = head, 0
	return function(entry)
		if not entry then
			if n > 0 then Queue(text, "BULK") end
			return
		end
		if n > 0 and #text + 1 + #entry > SYNC_MAX_LEN then
			Queue(text, "BULK")
			text, n = head, 0
		end
		text = text .. (n > 0 and ";" or "") .. entry
		n = n + 1
	end
end

-- Enemy GUIDs travel without "0x"; names lose the separators.
local function SendEnemies(seg, seconds, full)
	local grown = {}
	for guid, a in pairs(seg.actors) do
		if a.enemy and type(guid) == "string" and guid:find("^0x") then
			local k = not full and known[guid]
			local v = floor(a.taken or 0)
			if v > (k and k.taken or 0) then grown[#grown + 1] = { guid = guid, a = a, v = v, gain = v - (k and k.taken or 0) } end
		end
	end
	-- Big pulls: the enemies that took the most new damage; the rest go in a later round.
	table.sort(grown, function(x, y) return x.gain > y.gain end)
	local add = Packer("E\t" .. seconds .. "\t")
	for i = 1, min(#grown, SYNC_ENEMIES) do
		local e = grown[i]
		known[e.guid] = known[e.guid] or {}
		known[e.guid].taken = e.v
		add(e.guid:sub(3) .. "," .. B36(e.v) .. "," .. (e.a.name or ""):gsub("[,;\t|]", ""):sub(1, 40))
	end
	add()
end

-- full: every number, not only the ones that grew (boss encounter end, so a
-- lost message is made up for).
local function SendTotals(seg, full)
	if not seg or not SyncOn() or not SyncChannel() then return end
	local seconds = B36(E.Duration(seg))
	local add = Packer("T\t" .. seconds .. "\t")
	for guid, a in pairs(seg.actors) do
		if a.group and unitOf[guid] then
			local k = known[guid]
			if not k then
				k = {}
				known[guid] = k
			end
			local changed = false
			local parts = { ShortGUID(guid) }
			for i, f in ipairs(SYNC_FIELDS) do
				local v = floor(a[f] or 0)
				if v > (k[f] or 0) then
					changed = true
					k[f] = v
				end
				parts[i + 1] = B36(v)
			end
			if changed or (full and #table.concat(parts) > #parts[1]) then
				add((table.concat(parts, ","):gsub(",+$", "")))
			end
		end
	end
	add()
	SendEnemies(seg, seconds, full)
end

-- The fight synced totals belong to: the one in progress, or the one that
-- just ended (the sender's final totals can arrive after it ended here).
local function SyncTarget()
	if current and current.shown then return current end
	local seg = segments[1]
	if seg and seg == lastStopped and seg.finish and GetTime() - seg.finish <= SYNC_RECENT then return seg end
	return current
end

local function Raise(seg, a, f, delta)
	a[f] = (a[f] or 0) + delta
	local list = SYNC_LIST[f]
	if list then
		AddSpell(a[list], SYNC_ID, nil, delta)
	elseif f == "taken" then
		AddTaken(a, SYNC_ID, SYNC_ID, nil, delta)
	end
end

-- A chat line naming who a sync changed: "Synced from Bob: Casey (damage, healing), Boss (enemy damage taken)".
local SYNC_LABEL = { damage = "damage", healing = "healing", taken = "damage taken", interrupts = "interrupts", dispels = "dispels" }
local function Report(sender, lines)
	if #lines == 0 then return end
	local text = "Damage Meters: synced from " .. (sender or "?"):match("^[^%-]*") .. ": " .. table.concat(lines, ", ")
	if ns.Print then ns.Print(text) else print(text) end
end

local function MergeTotals(seconds, body, sender)
	local seg = SyncTarget()
	if not seg or math.abs(E.Duration(seg) - seconds) > SYNC_ALIGN then return end
	local changed, lines = false, {}
	for entry in body:gmatch("[^;]+") do
		local short, rest = entry:match("^([^,]+),?(.*)$")
		local guid = short and byShortGUID[short]
		if guid then
			local values, i = {}, 0
			for v in (rest .. ","):gmatch("([^,]*),") do
				i = i + 1
				values[i] = tonumber(v, 36) or 0
			end
			local flags = bit.bor(AFFIL_GROUP, TYPE_PLAYER)
			local a = seg.actors[guid]
			local k = known[guid]
			if not k then
				k = {}
				known[guid] = k
			end
			local raised = {}
			for j, f in ipairs(SYNC_FIELDS) do
				local v = values[j] or 0
				local have = a and a[f] or 0
				if v > have then
					local delta = v - have
					a = a or Actor(seg, guid, OwnerName(guid), flags)
					Raise(seg, a, f, delta)
					Raise(overall, Actor(overall, guid, OwnerName(guid), flags), f, delta)
					changed = true
					if SYNC_LABEL[f] then raised[#raised + 1] = SYNC_LABEL[f] end
				end
				if v > (k[f] or 0) then k[f] = v end
			end
			if #raised > 0 then lines[#lines + 1] = (a.name or "?") .. " (" .. table.concat(raised, ", ") .. ")" end
		end
	end
	if changed then
		if seg == current then ShowFight(seg) end
		Fire("sync")
	end
	Report(sender, lines)
end

local ENEMY_FLAGS = 0x00000a48 -- hostile NPC
local function MergeEnemies(seconds, body, sender)
	local seg = SyncTarget()
	if not seg or math.abs(E.Duration(seg) - seconds) > SYNC_ALIGN then return end
	local changed, lines = false, {}
	for entry in body:gmatch("[^;]+") do
		local hex, v, name = entry:match("^(%x+),([%w]*),(.*)$")
		v = v and tonumber(v, 36)
		if hex and v then
			local guid = "0x" .. hex
			local a = seg.actors[guid]
			if not a or a.enemy then
				local have = a and a.taken or 0
				if v > have then
					local delta = v - have
					if name == "" then name = nil end
					a = a or Actor(seg, guid, name, ENEMY_FLAGS)
					Raise(seg, a, "taken", delta)
					local o = overall.actors[guid]
					if not o or o.enemy then Raise(overall, o or Actor(overall, guid, name, ENEMY_FLAGS), "taken", delta) end
					changed = true
					lines[#lines + 1] = (a.name or "?") .. " (enemy damage taken)"
				end
				local k = known[guid]
				if not k then
					k = {}
					known[guid] = k
				end
				if v > (k.taken or 0) then k.taken = v end
			end
		end
	end
	if changed then Fire("sync") end
	Report(sender, lines)
end

local pendingDeaths = {} -- guid -> { at, text }: deaths of others are sent after a short random wait

SendDeath = function(guid, events)
	if not SyncOn() or not SyncChannel() or not unitOf[guid] then return end
	local blow
	for i = #events, 1, -1 do
		if not events[i].heal then
			blow = events[i]
			break
		end
	end
	local text = table.concat({
		"D", ShortGUID(guid), tostring(blow and blow.id or 0), tostring(floor(blow and blow.amount or 0)),
		tostring(floor(blow and blow.overkill or 0)), blow and blow.instakill and "1" or "0",
		(blow and blow.source or ""):sub(1, 60),
	}, "\t")
	-- Your own death is yours to report; someone else's is sent by whoever
	-- is first, the others drop theirs when it arrives.
	local wait = guid == playerGUID and 0 or 0.5 + math.random() * 1.5
	pendingDeaths[guid] = { at = GetTime() + wait, text = text }
end

local function MergeDeath(sender, short, id, amount, overkill, instakill, source)
	local guid = byShortGUID[short]
	if not guid then return end
	pendingDeaths[guid] = nil
	local name = OwnerName(guid)
	if not name then return end
	id, amount, overkill = tonumber(id) or 0, tonumber(amount) or 0, tonumber(overkill) or 0
	local events = {}
	if id ~= 0 or amount > 0 then
		events[1] = {
			heal = false, id = id, amount = amount, at = GetTime(), source = source ~= "" and source or nil,
			overkill = overkill > 0 and overkill or nil, instakill = instakill == "1" or nil,
		}
	end
	if AddDeath(guid, name, events, true) then Report(sender, { name .. " (death)" }) end
end

-- Other EllesmereUI users in the group, named in chat when first heard from.
local found = {}
local function Found(sender)
	local name = sender and sender:match("^[^%-]*")
	if not name or name == "" or found[name] then return end
	found[name] = true
	local text = "Damage Meters: group sync found " .. name .. " (EllesmereUI)"
	if ns.Print then ns.Print(text) else print(text) end
end

local syncNext, replyAt
function E.OnAddonMessage(prefix, text, _, sender)
	if prefix ~= SYNC_PREFIX or type(text) ~= "string" or not SyncOn() then return end
	if sender and sender:match("^[^%-]+") == UnitName("player") then return end
	local kind, a1, rest = text:match("^(%u)\t([^\t]*)\t(.*)$")
	if not kind then return end
	Found(sender)
	if kind == "H" then
		-- Answer after a short random wait, so a reloaded or new install
		-- finds everyone without all answers going at once.
		if not replyAt then replyAt = GetTime() + 1 + math.random() * 2 end
	elseif kind == "T" then
		MergeTotals(tonumber(a1, 36) or 0, rest, sender)
	elseif kind == "E" then
		MergeEnemies(tonumber(a1, 36) or 0, rest, sender)
	elseif kind == "D" then
		local id, amount, overkill, instakill, source = rest:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)$")
		if id then MergeDeath(sender, a1, id, amount, overkill, instakill, source) end
	end
end

-- Hello when the group grows (you joined one, or someone joined yours):
-- everyone with EllesmereUI says it, so all of them find each other. Two
-- seconds to let the roster settle, at most one per 30 seconds.
local groupSize, helloAt, lastHello = 1, nil, nil

local function WatchRoster(now)
	local n = 0
	for _ in pairs(unitOf) do n = n + 1 end
	if n > groupSize and n > 1 and SyncOn() then
		helloAt = math.max(now + 2, lastHello and lastHello + 30 or 0)
	elseif n <= 1 then
		wipe(found)
		helloAt = nil
	end
	groupSize = n
	if helloAt and now >= helloAt then
		helloAt, lastHello = nil, now
		Queue("H\t1\t", "NORMAL")
	end
	if replyAt and now >= replyAt then
		replyAt = nil
		Queue("R\t1\t", "NORMAL")
	end
end

-- Called every half second.
function E.SyncTick()
	local now = GetTime()
	WatchRoster(now)
	for guid, p in pairs(pendingDeaths) do
		if now >= p.at then
			pendingDeaths[guid] = nil
			Queue(p.text, "ALERT")
		end
	end
	if current and syncNext and now >= syncNext and not Sending() then
		syncNext = now + SYNC_INTERVAL
		SendTotals(current)
	end
	Flush()
end

E.Listen(function(what)
	if what == "start" then
		wipe(known)
		-- A little spread so the group's messages do not all go at once.
		syncNext = GetTime() + SYNC_INTERVAL + math.random() * 2
	elseif what == "stop" then
		syncNext = nil
		local seg = segments[1]
		if seg and seg == lastStopped and seg.finish == GetTime() then SendTotals(seg) end
	end
end)

---------------------------------------------------------------------------
-- Fights across a reload or relog: the stored fights and Overall are saved
-- per character at logout and restored when the addon loads. Only the
-- differences between times of one fight are read, so GetTime() starting
-- over after a game restart does not matter.
---------------------------------------------------------------------------
local SAVE_VERSION = 1

local function Restorable(seg)
	return type(seg) == "table" and type(seg.actors) == "table" and type(seg.deaths) == "table"
		and type(seg.start) == "number"
end

local function ClearActivity(seg)
	for _, a in pairs(seg.actors) do
		a.dmgLast, a.healLast = nil, nil
	end
end

local function RestoreFights()
	local saved = _G.EllesmereUIDamageMetersFights
	_G.EllesmereUIDamageMetersFights = nil
	if type(saved) ~= "table" or saved.version ~= SAVE_VERSION then return end
	if type(saved.segments) == "table" then
		local keep = Cfg("segmentsToKeep", 18)
		for _, seg in ipairs(saved.segments) do
			if #segments >= keep then break end
			if Restorable(seg) and type(seg.finish) == "number" then
				ClearActivity(seg)
				segments[#segments + 1] = seg
			end
		end
	end
	local o = saved.overall
	if type(saved.tries) == "table" then
		for name, n in pairs(saved.tries) do
			if type(name) == "string" and type(n) == "number" then tries[name] = n end
		end
	end
	if Restorable(o) and o.isOverall and type(o.duration) == "number" then
		ClearActivity(o)
		overall = o
	end
	if type(saved.lastBossName) == "string" then lastBossName = saved.lastBossName end
end

local function SaveFights()
	-- A reload during a fight keeps the fight so far.
	if current then StopFight() end
	_G.EllesmereUIDamageMetersFights = {
		version = SAVE_VERSION, segments = segments, overall = overall, lastBossName = lastBossName,
		tries = tries,
	}
end

---------------------------------------------------------------------------
-- Fight end: nobody in the group is in combat any more (a boss fight ends
-- on ENCOUNTER_END, with a fallback when the group has left combat).
---------------------------------------------------------------------------
local outSince
-- Lowest health of the encounter's bosses, for the boss % of a wipe.
local function TrackBossHP()
	if not current or not current.boss or not UnitExists then return end
	for i = 1, 5 do
		local unit = "boss" .. i
		if UnitExists(unit) then
			local max = UnitHealthMax(unit)
			if max and max > 0 then
				local pct = 100 * UnitHealth(unit) / max
				if not current.bossHP or pct < current.bossHP then current.bossHP = pct end
			end
		end
	end
end

function E.CheckEnd()
	TrackBossHP()
	if not current then
		outSince = nil
		return
	end
	if AnyoneInCombat() then
		outSince = nil
		return
	end
	local now = GetTime()
	outSince = outSince or now
	if not encounterName or now - outSince >= 10 then
		outSince = nil
		StopFight()
	end
end

local frame = CreateFrame("Frame")
local tick = 0
frame:SetScript("OnUpdate", function(_, elapsed)
	tick = tick + elapsed
	if tick < 0.5 then return end
	tick = 0
	E.CheckEnd()
	E.SyncTick()
end)
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("UNIT_PET")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterEvent("INSPECT_READY")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("WORLD_STATE_TIMER_START")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("CHAT_MSG_ADDON")
if RegisterAddonMessagePrefix then RegisterAddonMessagePrefix(SYNC_PREFIX) end

-- The 5.4.8 client's combat log can stall: no events reach addons for
-- minutes (damage, heals and deaths all go missing) until it is cleared.
-- Every cast you finish logs SPELL_CAST_SUCCESS, so a cast with no combat
-- log event shortly after means the log is stuck: clear it (CombatLogFix).
local LOG_STALL = 0.5
local lastLogAt, castAt = 0, nil
local fixer = CreateFrame("Frame")
fixer:SetScript("OnUpdate", function()
	if not castAt or GetTime() - castAt < LOG_STALL then return end
	if lastLogAt < castAt and CombatLogClearEntries then CombatLogClearEntries() end
	castAt = nil
end)

frame:SetScript("OnEvent", function(_, event, ...)
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		lastLogAt = GetTime()
		E.OnCombatLog(...)
	elseif event == "CHAT_MSG_ADDON" then
		E.OnAddonMessage(...)
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		if ... == "player" and not castAt then castAt = GetTime() end
	elseif event == "ADDON_LOADED" then
		if ... == addonName then RestoreFights() end
	elseif event == "PLAYER_LOGOUT" then
		SaveFights()
	elseif event == "PLAYER_REGEN_DISABLED" then
		StartFight()
	elseif event == "PLAYER_REGEN_ENABLED" then
		E.CheckEnd()
	elseif event == "PLAYER_DEAD" then
		E.PlayerDied()
	elseif event == "ENCOUNTER_START" then
		local _, name = ...
		encounterName = name or "Boss"
		if Cfg("overallClearNewBoss", true) and lastBossName and lastBossName ~= encounterName then
			ResetOverall()
			Fire("overall")
		end
		lastBossName = encounterName
		tries[encounterName] = (tries[encounterName] or 0) + 1
		if current then
			current.boss = true
			current.name = encounterName
			current.try = tries[encounterName]
			ShowFight(current)
		else
			StartFight()
		end
	elseif event == "ENCOUNTER_END" then
		local _, name, _, _, success = ...
		local seg = current or lastStopped
		if seg and seg.boss then
			seg.result = success == 1 and "kill" or "wipe"
			if success == 1 then seg.bossHP = 0 end
		end
		if success == 1 and name then tries[name] = nil end
		encounterName = nil
		-- The whole group's numbers of the boss fight, right away.
		if seg and seg.boss and (seg == current or (seg.finish and GetTime() - seg.finish <= SYNC_RECENT)) then
			SendTotals(seg, true)
		end
		E.CheckEnd()
	elseif event == "WORLD_STATE_TIMER_START" then
		local _, _, difficulty = GetInstanceInfo()
		if difficulty == 8 and Cfg("overallClearNewChallenge", true) then
			ResetOverall()
			Fire("overall")
		end
	else
		ScanRoster()
	end
end)
