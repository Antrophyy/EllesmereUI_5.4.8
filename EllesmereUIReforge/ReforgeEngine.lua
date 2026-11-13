-- Part of ReforgeLite by d07.RiV (Iroared)
-- All rights reserved

local REFORGE_COEFF = 0.4
local NUM_CAPS = 3 -- stat caps the user can set (ReforgeLite had 2)
-- Step size with 3+ caps: statsSum / STEP_DIV rating.
local STEP_DIV = {[3] = 200}

local _, playerClass = UnitClass ("player")
local _, playerRace = UnitRace ("player")
playerRace = string.upper(playerRace)
local missChance = (playerRace == "NIGHTELF" and 7 or 5)
local foodFactor = (playerRace == "PANDAREN" and 2 or 1)

local function DeepCopy (t, cache)
  if type (t) ~= "table" then
    return t
  end
  local copy = {}
  for i, v in pairs (t) do
    if type (v) ~= "table" then
      copy[i] = v
    else
      cache = cache or {}
      cache[t] = copy
      if cache[v] then
        copy[i] = cache[v]
      else
        copy[i] = DeepCopy (v, cache)
      end
    end
  end
  return copy
end

local L = EUIReforgeLocale

---------------------------------------------------------------------------------------

function EUIReforge:GetConversion()
  local _, class = UnitClass ("player")
  local level = UnitLevel("player")
  local spec = GetSpecialization() or 0
  local result = {}
  if class == "PRIEST" then
    result[self.STATS.EXP] = {[self.STATS.HIT] = 1}
    if spec == 3 and level >= 20 then
      result[self.STATS.SPIRIT] = {[self.STATS.HIT] = 1}
    end
  elseif class == "MAGE" then
   result[self.STATS.EXP] = {[self.STATS.HIT] = 1}
  elseif class == "WARLOCK" then
    result[self.STATS.EXP] = {[self.STATS.HIT] = 1}
  elseif class == "DRUID" then
    if spec == 1 then
      if level >= 64 then
        result[self.STATS.SPIRIT] = {[self.STATS.HIT] = 1}
      end
      result[self.STATS.EXP] = {[self.STATS.HIT] = 1}
    elseif spec == 4 then
      result[self.STATS.EXP] = {[self.STATS.HIT] = 1}
    end
  elseif class == "SHAMAN" then
    if spec == 1 then
      result[self.STATS.SPIRIT] = {[self.STATS.HIT] = 1}
      result[self.STATS.EXP] = {[self.STATS.HIT] = 1}
    elseif spec == 3 then
      result[self.STATS.EXP] = {[self.STATS.HIT] = 1}
    end
  elseif class == "MONK" then
    if spec == 2 then
      result[self.STATS.SPIRIT] = {[self.STATS.HIT] = 0.5, [self.STATS.EXP] = 0.5}
    end
  elseif class == "PALADIN" then
    if spec == 1 then
      result[self.STATS.EXP] = {[self.STATS.HIT] = 1}
    end
  end
  return result
end
local AmplificationItems = {
  [104976] = 528, -- Prismatic Prison of Pride, Raid Finder
  [104727] = 540, -- Prismatic Prison of Pride, Flexible
  [102299] = 553, -- Prismatic Prison of Pride
  [105225] = 559, -- Prismatic Prison of Pride, Warforged
  [104478] = 566, -- Prismatic Prison of Pride, Heroic
  [105474] = 572, -- Prismatic Prison of Pride, Heroic Warforged

  [104924] = 528, -- Purified Bindings of Immerseus, Raid Finder
  [104675] = 540, -- Purified Bindings of Immerseus, Flexible
  [102293] = 553, -- Purified Bindings of Immerseus
  [105173] = 559, -- Purified Bindings of Immerseus, Warforged
  [104426] = 566, -- Purified Bindings of Immerseus, Heroic
  [105422] = 572, -- Purified Bindings of Immerseus, Heroic Warforged

  [105111] = 528, -- Thok's Tail Tip, Raid Finder
  [104862] = 540, -- Thok's Tail Tip, Flexible
  [102305] = 553, -- Thok's Tail Tip
  [105360] = 559, -- Thok's Tail Tip, Warforged
  [104613] = 566, -- Thok's Tail Tip, Heroic
  [105609] = 572, -- Thok's Tail Tip, Heroic Warforged
}
function EUIReforge:GetStatMultipliers()
  local result = {}
  if playerRace == "HUMAN" then
    result[self.STATS.SPIRIT] = (result[self.STATS.SPIRIT] or 1) * 1.03
  end
  for i, v in ipairs (self.itemData) do
    local item = GetInventoryItemLink("player", v.slotId)
    if item then
      local id, iLvl = GetItemInfoUp(item)
      if id and AmplificationItems[id] then
        local factor = 1 + 0.01 * math.floor(GetRandPropPoints(iLvl, 2) / 420 + 0.5)
        result[self.STATS.HASTE] = (result[self.STATS.HASTE] or 1) * factor
        result[self.STATS.MASTERY] = (result[self.STATS.MASTERY] or 1) * factor
        result[self.STATS.SPIRIT] = (result[self.STATS.SPIRIT] or 1) * factor
      end
    end
  end
  return result
end

function EUIReforge:GetMethodScore (method)
  local score = 0
  for i = 1, #self.itemStats do
    score = score + self:GetStatScore (i, method.stats[i])
  end
  return score
end
function EUIReforge:GetMethodPenalty(method)
  for i = 1, #method.items do
    if self:IsItemLocked(i) then
      local link = GetInventoryItemLink("player", self.itemData[i].slotId)
      local src, dst = nil, nil
      if link then
        local reforge = self:GetReforgeID (link)
        if reforge then
          src = self.reforgeTable[reforge][1]
          dst = self.reforgeTable[reforge][2]
        end
      end
      if method.items[i].src ~= src or method.items[i].dst ~= dst then
        return 200000
      end
    end
  end
  for c = 1, NUM_CAPS do
    local cap = self.pdb.caps[c]
    if cap and cap.stat ~= 0 and not self:CapAllows(cap, method.stats[cap.stat]) then
      return 100000
    end
  end
  return 0
end

function EUIReforge:IsMethodValid(method)
  if not method.items then
    return true
  end
  for i = 1, #self.itemData do
    local item = GetInventoryItemLink ("player", self.itemData[i].slotId)
    local stats = (item and EUIReforge_GetItemStatsUp(item, self.pdb.ilvlCap) or {})
    if method.items[i] and method.items[i].src and method.items[i].dst then
      if (stats[self.itemStats[method.items[i].src].name] or 0) == 0 then
        return false
      end
      if (stats[self.itemStats[method.items[i].dst].name] or 0) ~= 0 then
        return false
      end
    end
  end
  return true
end

function EUIReforge:UpdateMethodStats (method)
  local conv = self:GetConversion()
  local mult = self:GetStatMultipliers()
  local oldstats = {}
  method.stats = {}
  for i = 1, #self.itemStats do
    oldstats[i] = self.itemStats[i].getter ()
    method.stats[i] = oldstats[i] / (mult[i] or 1)
  end
  method.items = method.items or {}
  for i = 1, #self.itemData do
    local item = GetInventoryItemLink ("player", self.itemData[i].slotId)
    local orgstats = (item and EUIReforge_GetItemStatsUp(item) or {})
    local stats = (item and EUIReforge_GetItemStatsUp(item, self.pdb.ilvlCap) or {})
    local reforge = (item and self:GetReforgeID(item))

    method.items[i] = method.items[i] or {}

    method.items[i].stats = nil
    method.items[i].reforge = nil
    method.items[i].amount = nil

    for s, v in ipairs(self.itemStats) do
      method.stats[s] = method.stats[s] - (orgstats[v.name] or 0) + (stats[v.name] or 0)
    end
    if reforge then
      local src, dst = self.reforgeTable[reforge][1], self.reforgeTable[reforge][2]
      local amount = math.floor ((orgstats[self.itemStats[src].name] or 0) * REFORGE_COEFF)
      method.stats[src] = method.stats[src] + amount
      method.stats[dst] = method.stats[dst] - amount
    end
    if method.items[i].src and method.items[i].dst then
      for j = 1, #self.reforgeTable do
        if self.reforgeTable[j][1] == method.items[i].src and self.reforgeTable[j][2] == method.items[i].dst then
          method.items[i].reforge = j
          break
        end
      end
      method.items[i].amount = math.floor ((stats[self.itemStats[method.items[i].src].name] or 0) * REFORGE_COEFF)
      method.stats[method.items[i].src] = method.stats[method.items[i].src] - method.items[i].amount
      method.stats[method.items[i].dst] = method.stats[method.items[i].dst] + method.items[i].amount
    end
  end
  for s, f in pairs(mult) do
    method.stats[s] = math.floor(method.stats[s] * f + 0.5)
  end
  -- assume we don't have 2 conversions
  for src, c in pairs(conv) do
    for dst, f in pairs(c) do
      method.stats[dst] = method.stats[dst] + math.floor((method.stats[src] - oldstats[src]) * f + 0.5)
    end
  end
end
function EUIReforge:FinalizeReforge (data)
  self:UpdateMethodStats(data.method)
end
function EUIReforge:ResetMethod ()
  local method = {}
  method.items = {}
  for i = 1, #self.itemData do
    method.items[i] = {}
    local item = GetInventoryItemLink ("player", self.itemData[i].slotId)
    local stats = (item and EUIReforge_GetItemStatsUp(item, self.pdb.ilvlCap) or {})
    local reforge = (item and self:GetReforgeID(item))
    if reforge then
      method.items[i].reforge = reforge
      method.items[i].src = self.reforgeTable[reforge][1]
      method.items[i].dst = self.reforgeTable[reforge][2]
    end
  end
  self:UpdateMethodStats(method)
  self.pdb.method = method
  self:UpdateMethodCategory()
end

function EUIReforge:CapAllows(cap, value)
  for i = 1, #cap.points do
    if cap.points[i].method == 1 and value < cap.points[i].value then
      return false
    elseif cap.points[i].method == 2 and value > cap.points[i].value then
      return false
    end
  end
  return true
end

function EUIReforge:IsItemLocked(slot)
  if self.pdb.itemsLocked[slot] then return true end
  local item = GetInventoryItemLink ("player", self.itemData[slot].slotId)
  if not item then return true end
  local ilvl = select (4, GetItemInfo (item)) or 0
  return ilvl < 200
end

------------------------------------- CLASSIC REFORGE ------------------------------

-- When the compute runs in a coroutine, give the game a frame now and then.
-- Outside a coroutine (sync compute) this does nothing.
local YIELD_STEPS = 4000
local function MaybeYield (progress)
  if coroutine.running () then
    coroutine.yield (progress)
  end
end

-- Adds amount to the delta of the cap that uses stat, or to the score.
local function AddStatDelta(data, d, stat, amount)
  for c = 1, NUM_CAPS do
    if data.caps[c].stat == stat then
      d[c] = d[c] + amount
      return 0
    end
  end
  return data.weights[stat] * amount
end
function EUIReforge:MakeReforgeOption(item, data, src, dst)
  local d = {}
  for c = 1, NUM_CAPS do
    d[c] = 0
  end
  local dscore = 0
  if src and dst then
    local amountRaw = math.floor(item.stats[src] * REFORGE_COEFF)
    local amount = math.floor(amountRaw * (data.mult[src] or 1) + math.random())
    dscore = dscore + AddStatDelta(data, d, src, -amount)
    if data.conv[src] then
      for to, factor in pairs(data.conv[src]) do
        local conv = math.floor(amount * factor + math.random())
        dscore = dscore + AddStatDelta(data, d, to, -conv)
      end
    end
    amount = math.floor(amountRaw * (data.mult[dst] or 1) + math.random())
    dscore = dscore + AddStatDelta(data, d, dst, amount)
    if data.conv[dst] then
      for to, factor in pairs(data.conv[dst]) do
        local conv = math.floor(amount * factor + math.random())
        dscore = dscore + AddStatDelta(data, d, to, conv)
      end
    end
  end
  return {d = d, ["src"] = src, ["dst"] = dst, score = dscore}
end
function EUIReforge:GetItemReforgeOptions (item, data, slot)
  if self:IsItemLocked (slot) then
    local link = GetInventoryItemLink ("player", self.itemData[slot].slotId)
    local src, dst = nil, nil
    if link then
      local reforge = self:GetReforgeID (link)
      if reforge then
        src = self.reforgeTable[reforge][1]
        dst = self.reforgeTable[reforge][2]
      end
    end
    return { self:MakeReforgeOption (item, data, src, dst) }
  end
  local aopt = {}
  aopt[0] = self:MakeReforgeOption (item, data)
  for src = 1, #self.itemStats do
    if item.stats[src] > 0 then
      for dst = 1, #self.itemStats do
        if item.stats[dst] == 0 then
          local o = self:MakeReforgeOption (item, data, src, dst)
          local pos = table.concat (o.d, ":")
          if not aopt[pos] or aopt[pos].score < o.score then
            aopt[pos] = o
          end
        end
      end
    end
  end
  local opt = {}
  for _, v in pairs (aopt) do
    table.insert (opt, v)
  end
  return opt
end
function EUIReforge:InitReforgeClassic ()
  local method = {}
  method.items = {}
  local orgitems = {}
  local statsSum = 0
  for i = 1, #self.itemData do
    method.items[i] = {}
    method.items[i].stats = {}
    orgitems[i] = {}
    local item = GetInventoryItemLink ("player", self.itemData[i].slotId)
    local stats = (item and EUIReforge_GetItemStatsUp(item, self.pdb.ilvlCap) or {})
    local orgstats = (item and EUIReforge_GetItemStatsUp(item) or {})
    for j, v in ipairs(self.itemStats) do
      method.items[i].stats[j] = (stats[v.name] or 0)
      orgitems[i][j] = (orgstats[v.name] or 0)
      statsSum = statsSum + method.items[i].stats[j]
    end
  end

  if self.pdb.prio then
    self:PrioToWeights(self.pdb)
  end
  local data = {}
  data.method = method
  data.weights = DeepCopy (self.pdb.weights)
  data.caps = DeepCopy (self.pdb.caps)
  for c = 1, NUM_CAPS do
    data.caps[c] = data.caps[c] or {stat = 0, points = {}}
    data.caps[c].init = 0
  end
  data.initial = {}

  data.mult = self:GetStatMultipliers()
  data.conv = self:GetConversion()

  for i = 1, NUM_CAPS do
    for point = 1, #data.caps[i].points do
      local preset = data.caps[i].points[point].preset
      if self.capPresets[preset] == nil then
        preset = 1
      end
      if self.capPresets[preset].getter then
        data.caps[i].points[point].value = math.ceil(self.capPresets[preset].getter())
      end
    end
  end

  data.cheat = math.ceil(statsSum / 1000)
  if data.cheat < 1 then
    data.cheat = 1
  end

  for i = 1, #self.itemStats do
    data.initial[i] = self.itemStats[i].getter() / (data.mult[i] or 1)
    for j = 1, #orgitems do
      data.initial[i] = data.initial[i] - orgitems[j][i]
    end
  end
  local reforged = {}
  for i = 1, #self.itemStats do
    reforged[i] = 0
  end
  for i = 1, #data.method.items do
    local item = GetInventoryItemLink ("player", self.itemData[i].slotId)
    local reforge = (item and self:GetReforgeID (item))
    if reforge then
      local src, dst = self.reforgeTable[reforge][1], self.reforgeTable[reforge][2]
      local amount = math.floor(orgitems[i][src] * REFORGE_COEFF)
      data.initial[src] = data.initial[src] + amount
      data.initial[dst] = data.initial[dst] - amount
      reforged[src] = reforged[src] - amount
      reforged[dst] = reforged[dst] + amount
    end
  end
  for src, c in pairs(data.conv) do
    for dst, f in pairs(c) do
      data.initial[dst] = data.initial[dst] - math.floor(reforged[src] * (data.mult[src] or 1) * f + 0.5)
    end
  end
  -- Keep only the caps that have a stat, without duplicates, in order.
  local active, used = {}, {}
  for c = 1, NUM_CAPS do
    local cap = data.caps[c]
    if cap.stat > 0 and not used[cap.stat] then
      used[cap.stat] = true
      cap.init = data.initial[cap.stat]
      for i = 1, #data.method.items do
        cap.init = cap.init + data.method.items[i].stats[cap.stat]
      end
      active[#active + 1] = cap
    end
  end
  data.numCaps = #active
  for c = #active + 1, NUM_CAPS do
    active[c] = {stat = 0, init = 0, points = {}}
  end
  data.caps = active
  if data.numCaps <= 1 then
    data.cheat = 1
  elseif data.numCaps >= 3 then
    -- More caps make the search space much larger: use coarser steps
    -- so that the compute stays near one second.
    data.cheat = math.max(1, math.ceil(statsSum / (STEP_DIV[data.numCaps] or 200)))
  end

  for src, conv in pairs(data.conv) do
    if data.weights[src] == 0 then
      local capped = false
      for c = 1, NUM_CAPS do
        if conv[data.caps[c].stat] then
          capped = true
        end
      end
      if capped then
        if src == self.STATS.EXP then
          data.weights[src] = -1
        else
          data.weights[src] = 1
        end
      end
    end
  end

  return data
end

function EUIReforge:ChooseReforgeClassic (data, reforgeOptions, scores, codes)
  -- Rank: all caps met first; cap 1 is more important than cap 2, and so on.
  -- Sums and scores are computed again from the codes, so they are exact.
  local bestCode, bestScore = {}, {}
  local steps = 0
  local sums = {}
  for k in pairs (scores) do
    steps = steps + 1
    if steps >= YIELD_STEPS then
      steps = 0
      MaybeYield (1)
    end
    for c = 1, data.numCaps do
      sums[c] = data.caps[c].init
    end
    local score = 0
    local code = codes[k]
    for i = 1, #code do
      local o = reforgeOptions[i][code:byte (i)]
      score = score + o.score
      for c = 1, data.numCaps do
        sums[c] = sums[c] + o.d[c]
      end
    end
    local allow = 1
    for c = 1, data.numCaps do
      local cap = data.caps[c]
      if not self:CapAllows (cap, sums[c]) then
        allow = allow + 2 ^ (NUM_CAPS - c)
      end
      score = score + self:GetCapScore (cap, sums[c])
    end
    if bestCode[allow] == nil or score > bestScore[allow] then
      bestCode[allow] = code
      bestScore[allow] = score
    end
  end
  for allow = 1, 2 ^ NUM_CAPS do
    if bestCode[allow] then
      return bestCode[allow]
    end
  end
end

local function FormatValue (value, prefix)
  if type (value) == "table" then
    local result = "{\n"
    prefix = prefix or ""
    local newprefix = prefix .. "  "
    for k, v in pairs (value) do
      result = result .. newprefix .. tostring (k) .. " = " .. FormatValue (v, newprefix) .. "\n"
    end
    return result .. prefix .. "}"
  else
    return tostring (value)
  end
end

-- Dynamic programming over the items. A state is the sum of each capped stat,
-- in steps of data.cheat rating, packed into one number key. For each state
-- we keep the best score of the uncapped stats and the reforge code.
--
-- Merge above the cap: when a capped stat is so high that it stays above its
-- highest cap point even if all later items reforge it away, more of it only
-- adds "weight after cap" per point. Then we cut the sum at that limit and
-- add the rest to the score, so these states merge. ChooseReforgeClassic
-- computes the exact sums and scores again from the codes.
function EUIReforge:ComputeReforgeCore (data, reforgeOptions)
  local n = data.numCaps
  local T = (n >= 4) and 8192 or 100000
  local T2, T3 = T * T, T * T * T
  local mfloor = math.floor
  local mrandom = math.random
  local schar = string.char
  local cheat = data.cheat
  local nitems = #self.itemData

  local limit = {{}, {}, {}, {}}
  local afterW = {0, 0, 0, 0}
  for c = 1, n do
    local top, after
    for _, p in ipairs (data.caps[c].points) do
      if top == nil or p.value >= top then
        top, after = p.value, p.after
      end
    end
    if top then
      afterW[c] = (after or 0) * cheat
      local rem = 0
      for i = nitems, 1, -1 do
        -- Margin: the random rounding moves the sum by up to one step per
        -- item (earlier and later items), so add one step per item.
        limit[c][i] = mfloor ((top + rem) / cheat) + nitems + 2
        local maxdec = 0
        for _, o in ipairs (reforgeOptions[i]) do
          if -o.d[c] > maxdec then
            maxdec = -o.d[c]
          end
        end
        rem = rem + maxdec
      end
    end
  end

  local function Init (c)
    return (c <= n) and mfloor (data.caps[c].init / cheat + mrandom ()) or 0
  end
  local linit = Init (1) + Init (2) * T + Init (3) * T2 + Init (4) * T3
  local scores, codes = {[linit] = 0}, {[linit] = ""}
  local steps = 0
  for i = 1, nitems do
    local newscores, newcodes = {}, {}
    local opt = reforgeOptions[i]
    local l1, l2, l3, l4 = limit[1][i], limit[2][i], limit[3][i], limit[4][i]
    local a1, a2, a3, a4 = afterW[1], afterW[2], afterW[3], afterW[4]
    for k, score in pairs (scores) do
      steps = steps + #opt
      if steps >= YIELD_STEPS then
        steps = 0
        MaybeYield ((i - 1) / nitems)
      end
      local code = codes[k]
      local c1 = k % T
      local r = (k - c1) / T
      local c2 = r % T
      r = (r - c2) / T
      local c3 = r % T
      local c4 = (r - c3) / T
      for j = 1, #opt do
        local o = opt[j]
        local od = o.d
        local nscore = score + o.score
        local x1 = c1 + mfloor (od[1] / cheat + mrandom ())
        if l1 and x1 > l1 then
          nscore = nscore + a1 * (x1 - l1)
          x1 = l1
        end
        local nk = x1
        if n >= 2 then
          local x2 = c2 + mfloor (od[2] / cheat + mrandom ())
          if l2 and x2 > l2 then
            nscore = nscore + a2 * (x2 - l2)
            x2 = l2
          end
          nk = nk + x2 * T
          if n >= 3 then
            local x3 = c3 + mfloor (od[3] / cheat + mrandom ())
            if l3 and x3 > l3 then
              nscore = nscore + a3 * (x3 - l3)
              x3 = l3
            end
            nk = nk + x3 * T2
            if n >= 4 then
              local x4 = c4 + mfloor (od[4] / cheat + mrandom ())
              if l4 and x4 > l4 then
                nscore = nscore + a4 * (x4 - l4)
                x4 = l4
              end
              nk = nk + x4 * T3
            end
          end
        end
        local old = newscores[nk]
        if old == nil or nscore > old then
          newscores[nk] = nscore
          newcodes[nk] = code .. schar (j)
        end
      end
    end
    scores, codes = newscores, newcodes
  end
  return scores, codes
end
function EUIReforge:ComputePrepare (initFunc, optionFunc)
  local data = self[initFunc] (self)
  local reforgeOptions = {}
  for i = 1, #self.itemData do
    reforgeOptions[i] = self[optionFunc] (self, data.method.items[i], data, i)
  end
  return data, reforgeOptions
end
function EUIReforge:ComputeSearch (data, reforgeOptions, chooseFunc)
  local scores, codes = self:ComputeReforgeCore (data, reforgeOptions)
  return self[chooseFunc] (self, data, reforgeOptions, scores, codes)
end
function EUIReforge:ComputeFinish (data, reforgeOptions, code)
  collectgarbage ("collect")
  self.methodDebug = "version = 1.38\n\n"
  self.methodDebug = self.methodDebug .. "data = " .. FormatValue (data) .. "\n\n"
  for i = 1, #data.method.items do
    local opt = reforgeOptions[i][code:byte (i)]
    if data.conv[self.STATS.SPIRIT] and data.conv[self.STATS.SPIRIT][self.STATS.HIT] == 1 then
      if opt.dst == self.STATS.HIT and data.method.items[i].stats[self.STATS.SPIRIT] == 0 then
        opt.dst = self.STATS.SPIRIT
      end
    end
    data.method.items[i].src = opt.src
    data.method.items[i].dst = opt.dst
  end
  self:FinalizeReforge (data)
  self.methodDebug = self.methodDebug .. "method = " .. FormatValue (data.method)
  return data.method
end
function EUIReforge:ComputeFailed (data, err)
  collectgarbage ("collect")
  self.methodDebug = "data = " .. FormatValue (data)
  EUIReforgeGUI:ShowPopup ({
    title = "Reforge",
    message = string.format (L["Reforge failed to compute your optimal reforge. Try increasing the speed by moving the speed slider.\nError message: %s"], tostring (err)),
    text = tostring (err),
    readOnly = true,
    acceptText = OKAY,
    hideCancel = true,
  })
end
function EUIReforge:ComputeReforge (initFunc, optionFunc, chooseFunc)
  local data, reforgeOptions = self:ComputePrepare (initFunc, optionFunc)
  self.methodDebug = "<no data>"
  local success, code = pcall (self.ComputeSearch, self, data, reforgeOptions, chooseFunc)
  if success then
    return self:ComputeFinish (data, reforgeOptions, code)
  end
  self:ComputeFailed (data, code)
  return nil
end

function EUIReforge:Compute ()
  return self:ComputeReforge ("InitReforgeClassic", "GetItemReforgeOptions", "ChooseReforgeClassic")
end

-- Background compute: the search runs in a coroutine for a few ms per frame,
-- so the game does not freeze. onProgress (0..1) is called each frame;
-- onDone (method or nil) is called once at the end.
local FRAME_BUDGET_MS = 12
function EUIReforge:IsComputing ()
  return self.computeCo ~= nil
end
function EUIReforge:ComputeAsync (onDone, onProgress)
  if self.computeCo then
    return
  end
  local ok, data, reforgeOptions = pcall (self.ComputePrepare, self, "InitReforgeClassic", "GetItemReforgeOptions")
  if not ok then
    self:ComputeFailed ({}, data)
    onDone (nil)
    return
  end
  self.methodDebug = "<no data>"
  local co = coroutine.create (function ()
    return self:ComputeSearch (data, reforgeOptions, "ChooseReforgeClassic")
  end)
  self.computeCo = co
  self.computeDriver = self.computeDriver or CreateFrame ("Frame")
  local driver = self.computeDriver
  local function Stop ()
    driver:SetScript ("OnUpdate", nil)
    self.computeCo = nil
  end
  driver:SetScript ("OnUpdate", function ()
    local start = debugprofilestop ()
    local progress = 0
    repeat
      local success, result = coroutine.resume (co)
      if not success then
        Stop ()
        self:ComputeFailed (data, result)
        onDone (nil)
        return
      end
      if coroutine.status (co) == "dead" then
        Stop ()
        local fin, method = pcall (self.ComputeFinish, self, data, reforgeOptions, result)
        if not fin then
          self:ComputeFailed (data, method)
          method = nil
        end
        onDone (method)
        return
      end
      progress = result or progress
    until debugprofilestop () - start > FRAME_BUDGET_MS
    if onProgress then
      onProgress (progress)
    end
  end)
end

-- Debug data (EllesmereUI popup, read only, selected for Ctrl+C).
function EUIReforge:DebugMethod ()
  EUIReforgeGUI:ShowPopup ({
    title = L["Debug"],
    message = "E-mail: d07.riv@gmail.com",
    text = self.methodDebug or "<no data>",
    multiLine = true,
    readOnly = true,
    width = 420,
    height = 320,
    acceptText = OKAY,
    hideCancel = true,
  })
end