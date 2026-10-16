-- Conditional Overrides engine (retail EllesmereUI_Conditions.lua): the
-- condition list, the active-group resolver, events and the keybind toggle.
-- The value work is in EllesmereUI_SpecOverrides.lua
-- (ns.SpecOverrides_CondTransition); this file only decides WHICH
-- conditional group is active.
--
-- Resolution ladder:
--   1. keybind  -- a group whose keybind toggle is on (creation order)
--   2. instance -- dungeon / raid / arena / battleground
--   3. solo     -- not in a group (never inside an instance)
-- One conditional group is active at a time, or none. Nothing flips in
-- combat: the state is resolved again at PLAYER_REGEN_ENABLED.
--
-- Left out: the Dark Mode condition (retail per-module Dark Mode) and Druid
-- Form (retail "coming soon" as well; listed disabled in the picker).

local ns = EllesmereUI
if not ns or not ns.SpecOverrides_Root then
	return
end

ns.CONDITIONS = {
	{ id = "keybind", label = "Keybind (out of combat)" },
	{ id = "dungeon", label = "Dungeon" },
	{ id = "raid", label = "Raid" },
	{ id = "arena", label = "Arena" },
	{ id = "battleground", label = "Battleground" },
	{ id = "solo", label = "Solo (not in a group)" },
	{ id = "druid_form", label = "Druid Form (out of combat)", comingSoon = true },
}

local INSTANCE_COND = {
	party = "dungeon",
	raid = "raid",
	arena = "arena",
	pvp = "battleground",
}

---------------------------------------------------------------------------
-- Group store: overrides.condOverrideGroups (creation order = priority):
-- { id, name, icon = { kind, key }, conds = { [condID] = true },
--   key = "ALT-X" | nil, keyOn = true | nil }
---------------------------------------------------------------------------
function ns.Conditions_GetGroups(create)
	local r = ns.SpecOverrides_Root(create)
	if not r then
		return nil
	end
	if type(r.condOverrideGroups) ~= "table" then
		if not create then
			return nil
		end
		r.condOverrideGroups = {}
	end
	return r.condOverrideGroups
end

function ns.Conditions_GroupById(gid)
	for _, g in ipairs(ns.Conditions_GetGroups() or {}) do
		if g.id == gid then
			return g
		end
	end
	return nil
end

-- Persisted counter, never reused.
function ns.Conditions_NewGroupId()
	local r = ns.SpecOverrides_Root(true)
	local maxId = 0
	for _, g in ipairs(ns.Conditions_GetGroups(true) or {}) do
		if type(g.id) == "number" and g.id > maxId then
			maxId = g.id
		end
	end
	local id = r.condOverrideNextId or 0
	if id < maxId then
		id = maxId
	end
	id = id + 1
	r.condOverrideNextId = id
	return id
end

---------------------------------------------------------------------------
-- Resolver
---------------------------------------------------------------------------
function ns.Conditions_ActiveGroup()
	local groups = ns.Conditions_GetGroups()
	if not groups or #groups == 0 then
		return nil
	end
	for _, g in ipairs(groups) do
		if g.conds and g.conds.keybind and g.keyOn then
			return g
		end
	end
	local _, instanceType = IsInInstance()
	local cond = instanceType and INSTANCE_COND[instanceType]
	if cond then
		for _, g in ipairs(groups) do
			if g.conds and g.conds[cond] then
				return g
			end
		end
		return nil
	end
	if instanceType and instanceType ~= "none" then
		-- Scenario and other instance types: no condition.
		return nil
	end
	if not IsInGroup() then
		for _, g in ipairs(groups) do
			if g.conds and g.conds.solo then
				return g
			end
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- Applied group: runtime pointer + a copy in the store (the applied values
-- are in the saved module settings, so the pointer must survive a reload).
---------------------------------------------------------------------------
local _appliedGid
local _flipPending = false
local _establish = true

local function PersistAppliedGid(gid)
	local r = ns.SpecOverrides_Root(gid ~= nil)
	if r then
		r.condAppliedGid = gid
	end
end

function ns.Conditions_AppliedGid()
	if _appliedGid ~= nil then
		return _appliedGid
	end
	local r = ns.SpecOverrides_Root()
	local gid = r and r.condAppliedGid
	if gid and ns.Conditions_GroupById(gid) then
		return gid
	end
	return nil
end

-- establish: first resolve after login, apply only (nothing is banked).
function ns.Conditions_Recheck(establish)
	if establish then
		_establish = true
	end
	if InCombatLockdown() then
		_flipPending = true
		return
	end
	local g = ns.Conditions_ActiveGroup()
	local gid = g and g.id or nil
	local applied = ns.Conditions_AppliedGid()
	if gid == applied and not _establish then
		_appliedGid = applied
		return
	end
	local handler = ns.SpecOverrides_CondTransition
	if not handler then
		return
	end
	local est = _establish
	_establish = false
	if handler(applied, gid, est) then
		_appliedGid = gid
		PersistAppliedGid(gid)
	else
		-- Busy (editing session, combat): retry on the next signal.
		_establish = est or _establish
		_flipPending = true
	end
end

---------------------------------------------------------------------------
-- Keybind toggle: hidden buttons + SetOverrideBindingClick, rebuilt out of
-- combat. Presses in combat are ignored ("out of combat").
---------------------------------------------------------------------------
local keyButtons = {}
local bindPending = false

function ns.Conditions_ToggleKey(gid)
	if InCombatLockdown() then
		return
	end
	local g = ns.Conditions_GroupById(gid)
	if not g or not (g.conds and g.conds.keybind) then
		return
	end
	g.keyOn = not g.keyOn or nil
	ns.Conditions_Recheck()
	if ns.SO and ns.SO.Notify then
		ns.SO.Notify("store")
	end
end

function ns.Conditions_RebuildKeyBindings()
	if InCombatLockdown() then
		bindPending = true
		return
	end
	bindPending = false
	for _, btn in ipairs(keyButtons) do
		ClearOverrideBindings(btn)
	end
	local i = 0
	for _, g in ipairs(ns.Conditions_GetGroups() or {}) do
		if g.conds and g.conds.keybind and g.key and g.key ~= "" then
			i = i + 1
			local btn = keyButtons[i]
			if not btn then
				btn = CreateFrame("Button", "EUICondKeyBtn" .. i, UIParent)
				btn:Hide()
				keyButtons[i] = btn
			end
			local gid = g.id
			btn:SetScript("OnClick", function()
				ns.Conditions_ToggleKey(gid)
			end)
			SetOverrideBindingClick(btn, true, g.key, btn:GetName())
		end
	end
end

---------------------------------------------------------------------------
-- Events (this file loads after EllesmereUI_SpecOverrides.lua, so its
-- regen handler runs first and this recompute sees the settled spec).
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_ENABLED" then
		if bindPending then
			ns.Conditions_RebuildKeyBindings()
		end
		if _flipPending then
			_flipPending = false
			ns.Conditions_Recheck()
		end
		return
	end
	if event == "PLAYER_ENTERING_WORLD" then
		ns.Conditions_RebuildKeyBindings()
	end
	-- Before the spec is known the spec engine has not applied yet; it calls
	-- the first (establish) recheck itself.
	if ns.SO and not ns.SO.ActiveSpec() then
		return
	end
	ns.Conditions_Recheck()
end)
