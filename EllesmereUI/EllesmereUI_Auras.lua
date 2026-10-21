-- Some 5.4.8 clients attribute multiple DK disease applications to the same
-- caster. Consolidate their icons, not the underlying auras or combat data.
local ns = EllesmereUI

-- Return a display list without mutating the input or its pooled records.
-- Keep the latest expiry (and its real UnitAura index) in the first copy's slot.
function ns.FilterDuplicateDiseases(list, count)
	count = count or #list
	local seen, out
	local n = 0
	for i = 1, count do
		local aura = list[i]
		local id = aura.spellId or aura.id
		local key
		if id == 55078 or id == 55095 then
			local source = aura.casterGUID or (aura.caster and (UnitGUID(aura.caster) or aura.caster))
			if source and source ~= "" then key = id .. ":" .. source end
		end
		local slot = key and seen and seen[key]
		if slot then
			if not out then
				out = {}
				for j = 1, n do out[j] = list[j] end
			end
			if (aura.expires or 0) > (out[slot].expires or 0) then out[slot] = aura end
		else
			n = n + 1
			if out then out[n] = aura end
			if key then
				seen = seen or {}
				seen[key] = n
			end
		end
	end
	return out or list, n
end
