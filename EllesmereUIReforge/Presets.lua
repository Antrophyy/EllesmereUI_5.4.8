-- Part of ReforgeLite by d07.RiV (Iroared)
-- All rights reserved

local L = EUIReforgeLocale
local MOP = (GetNumTalentTabs == nil)

----------------------------------------- CAP PRESETS ---------------------------------

function EUIReforge:RatingPerPoint (stat, level)
  level = level or UnitLevel("player")
  if stat == self.STATS.SPELLHIT then
    stat = self.STATS.HIT
  end
  return EUIReforgeScalingTable[stat][level] or 0
end
function EUIReforge:GetMeleeHitBonus ()
  return GetHitModifier () or 0
end
function EUIReforge:GetSpellHitBonus ()
  return GetSpellHitModifier () or 0
end
function EUIReforge:GetExpertiseBonus ()
  local _, class = UnitClass ("player")
  if class == "HUNTER" then
    return select(3, GetExpertise()) - GetCombatRatingBonus(CR_EXPERTISE)
  else
    return GetExpertise() - GetCombatRatingBonus(CR_EXPERTISE)
  end
end
function EUIReforge:GetNeededMeleeHit ()
  local diff = self.pdb.targetLevel
  if MOP then
    return math.max(0, 3 + 1.5 * diff)
  else
    if diff <= 2 then
      return math.max (0, 5 + 0.5 * diff)
    else
      return 2 + 2 * diff
    end
  end
end
function EUIReforge:GetNeededSpellHit ()
  local diff = self.pdb.targetLevel
  if diff <= 3 then
    return math.max(0, 6 + 3 * diff)
  else
    return 11 * diff - 18
  end
end
function EUIReforge:GetNeededExpertiseSoft ()
  local diff = self.pdb.targetLevel
  if MOP then
    return math.max(0, 3 + 1.5 * diff)
  else
    return math.ceil (math.max (0, 5 + 0.5 * diff) / 0.25)
  end
end
function EUIReforge:GetNeededExpertiseHard ()
  local diff = self.pdb.targetLevel
  if MOP then
    return math.max(0, 6 + 3 * diff)
  else
    if diff <= 2 then
      return math.ceil (math.max (0, 5 + 0.5 * diff) / 0.25)
    else
      return math.ceil (14 / 0.25)
    end
  end
end

EUIReforge.capPresets = {
  {
    value = 1,
    name = L["Manual"],
    getter = nil
  },
  {
    value = 2,
    name = L["Melee hit cap"],
    getter = function ()
      return EUIReforge:RatingPerPoint (EUIReforge.STATS.HIT) * (EUIReforge:GetNeededMeleeHit () - EUIReforge:GetMeleeHitBonus ())
    end
  },
  {
    value = 3,
    name = L["Spell hit cap"],
    getter = function ()
      local conv = EUIReforge:GetConversion()
      local result = EUIReforge:RatingPerPoint (EUIReforge.STATS.SPELLHIT) * (EUIReforge:GetNeededSpellHit () - EUIReforge:GetSpellHitBonus ())
      if conv[EUIReforge.STATS.EXP] and conv[EUIReforge.STATS.EXP][EUIReforge.STATS.HIT] then
        result = result + math.floor(GetCombatRating(CR_EXPERTISE) * conv[EUIReforge.STATS.EXP][EUIReforge.STATS.HIT])
      end
      return result
    end
  },
  {
    value = 4,
    name = L["Melee DW hit cap"],
    getter = function ()
      return EUIReforge:RatingPerPoint (EUIReforge.STATS.HIT) * (EUIReforge:GetNeededMeleeHit () + 19 - EUIReforge:GetMeleeHitBonus ())
    end
  },
  {
    value = 5,
    name = L["Expertise soft cap"],
    getter = function ()
      return EUIReforge:RatingPerPoint (EUIReforge.STATS.EXP) * (EUIReforge:GetNeededExpertiseSoft () - EUIReforge:GetExpertiseBonus ())
    end
  },
  {
    value = 6,
    name = L["Expertise hard cap"],
    getter = function ()
      return EUIReforge:RatingPerPoint (EUIReforge.STATS.EXP) * (EUIReforge:GetNeededExpertiseHard () - EUIReforge:GetExpertiseBonus ())
    end
  },
}

----------------------------------------- WEIGHT PRESETS ------------------------------

local StatSpirit = 1
local StatDodge = 2
local StatParry = 3
local StatHit = 4
local StatCrit = 5
local StatHaste = 6
local StatExp = 7
local StatMastery = 8
local MeleeHitCap = 2
local SpellHitCap = 3
local MeleeDWHitCap = 4
local ExpSoftCap = 5
local ExpHardCap = 6
local AtLeast = 1
local AtMost = 2

local MeleeCaps = {
  {
    stat = StatHit,
    points = {
      {
        method = AtLeast,
        preset = MeleeHitCap
      }
    }
  },
  {
    stat = StatExp,
    points = {
      {
        method = AtLeast,
        preset = ExpSoftCap
      }
    }
  }
}
local CasterCaps = {
  {
    stat = StatHit,
    points = {
      {
        method = AtLeast,
        preset = SpellHitCap
      }
    }
  }
}

EUIReforge.presets = {
  ["DEATHKNIGHT"] = {
    ["<Blood>"] = {
      prio = {
        {stat = StatMastery},
        {stat = StatHit, preset = MeleeHitCap},
        {stat = StatExp, preset = ExpSoftCap},
        {stat = StatParry},
        {stat = StatDodge},
        {stat = StatHaste},
      },
    },
    ["<Frost> - <2H Weapon>"] = {
      prio = {
        {stat = StatExp, preset = ExpSoftCap},
        {stat = StatHit, preset = MeleeHitCap},
        {stat = StatCrit},
        {stat = StatMastery},
        {stat = StatHaste},
      },
    },
    ["<Frost> - <Dual Wielding>"] = {
      prio = {
        {stat = StatHit, preset = MeleeHitCap},
        {stat = StatExp, preset = ExpSoftCap},
        {stat = StatMastery},
        {stat = StatCrit},
        {stat = StatHaste},
        {stat = StatHit, preset = MeleeDWHitCap},
      },
    },
    ["<Unholy>"] = {
      prio = {
        {stat = StatExp, preset = ExpSoftCap},
        {stat = StatHit, preset = MeleeHitCap},
        {stat = StatCrit},
        {stat = StatMastery},
        {stat = StatHaste},
      },
    },
  },
  ["DRUID"] = {
    ["<Balance> - 5273 <HasteLong>"] = {
      prio = {
        {stat = StatHit, preset = SpellHitCap},
        {stat = StatHaste, value = 5273},
        {stat = StatCrit},
        {stat = StatMastery},
        {stat = StatHaste},
      },
    },
    ["<Balance> - 10289 <HasteLong>"] = {
      prio = {
        {stat = StatHit, preset = SpellHitCap},
        {stat = StatHaste, value = 10289},
        {stat = StatCrit},
        {stat = StatMastery},
        {stat = StatHaste},
      },
    },
    ["<Feral>"] = {
      prio = {
        {stat = StatExp, preset = ExpSoftCap},
        {stat = StatHit, preset = MeleeHitCap},
        {stat = StatMastery},
        {stat = StatCrit},
        {stat = StatHaste},
      },
    },
    ["<Guardian>"] = {
      prio = {
        {stat = StatHit, preset = MeleeHitCap},
        {stat = StatExp, preset = ExpHardCap},
        {stat = StatCrit},
        {stat = StatHaste},
        {stat = StatMastery},
        {stat = StatDodge},
      },
    },
    ["<Restoration> - 3043 <HasteLong>"] = {
      prio = {
        {stat = StatSpirit},
        {stat = StatHaste, value = 3043},
        {stat = StatMastery},
        {stat = StatCrit},
        {stat = StatHaste},
      },
    },
    ["<Restoration> - 6652 <HasteLong>"] = {
      prio = {
        {stat = StatSpirit},
        {stat = StatHaste, value = 6652},
        {stat = StatMastery},
        {stat = StatCrit},
        {stat = StatHaste},
      },
    },
  },
  ["HUNTER"] = {
    ["<Beast Mastery>"] = {
      prio = {
        {stat = StatExp, preset = ExpSoftCap},
        {stat = StatHit, preset = MeleeHitCap},
        {stat = StatCrit},
        {stat = StatHaste},
        {stat = StatMastery},
      },
    },
    ["<Marksmanship>"] = {
      prio = {
        {stat = StatExp, preset = ExpSoftCap},
        {stat = StatHit, preset = MeleeHitCap},
        {stat = StatCrit},
        {stat = StatHaste},
        {stat = StatMastery},
      },
    },
    ["<Survival>"] = {
      prio = {
        {stat = StatExp, preset = ExpSoftCap},
        {stat = StatHit, preset = MeleeHitCap},
        {stat = StatCrit},
        {stat = StatHaste},
        {stat = StatMastery},
      },
    },
  },
  ["MAGE"] = {
    ["<Arcane>"] = {
      prio = {
        {stat = StatHit, preset = SpellHitCap},
        {stat = StatMastery},
        {stat = StatHaste},
        {stat = StatCrit},
      },
    },
    ["<Fire>"] = {
      prio = {
        {stat = StatHit, preset = SpellHitCap},
        {stat = StatCrit},
        {stat = StatHaste},
        {stat = StatMastery},
      },
    },
    ["<Frost>"] = {
      prio = {
        {stat = StatHit, preset = SpellHitCap},
        {stat = StatHaste},
        {stat = StatMastery},
        {stat = StatCrit},
      },
    },
  },
  ["MONK"] = {
    ["<Brewmaster>"] = {
      prio = {
        {stat = StatExp, preset = ExpHardCap},
        {stat = StatHit, preset = MeleeHitCap},
        {stat = StatMastery},
        {stat = StatCrit},
        {stat = StatHaste},
        {stat = StatParry},
        {stat = StatDodge},
      },
    },
    ["<Mistweaver>"] = {
      prio = {
        {stat = StatSpirit},
        {stat = StatHaste, value = 3145},
        {stat = StatCrit},
        {stat = StatMastery},
        {stat = StatHaste},
      },
    },
    ["<Windwalker>"] = {
      prio = {
        {stat = StatHit, preset = MeleeHitCap},
        {stat = StatExp, preset = ExpSoftCap},
        {stat = StatCrit},
        {stat = StatHaste},
        {stat = StatMastery},
      },
    },
  },
  ["PALADIN"] = {
    ["<Holy>"] = {
      prio = {
        {stat = StatSpirit},
        {stat = StatMastery},
        {stat = StatHaste},
        {stat = StatCrit},
      },
    },
    ["<Protection>"] = {
      prio = {
        {stat = StatHit, preset = MeleeHitCap},
        {stat = StatExp, preset = ExpHardCap},
        {stat = StatHaste},
        {stat = StatMastery},
        {stat = StatParry},
        {stat = StatDodge},
      },
    },
    ["<Retribution>"] = {
      prio = {
        {stat = StatHit, preset = MeleeHitCap},
        {stat = StatExp, preset = ExpSoftCap},
        {stat = StatHaste},
        {stat = StatMastery},
        {stat = StatCrit},
      },
    },
  },
  ["PRIEST"] = {
    ["<Discipline>"] = {
      prio = {
        {stat = StatSpirit},
        {stat = StatCrit},
        {stat = StatMastery},
        {stat = StatHaste},
      },
    },
    ["<Holy> - 3039 <HasteLong>"] = {
      prio = {
        {stat = StatSpirit},
        {stat = StatHaste, value = 3039},
        {stat = StatMastery},
        {stat = StatCrit},
        {stat = StatHaste},
      },
    },
    ["<Holy> - 4721 <HasteLong>"] = {
      prio = {
        {stat = StatSpirit},
        {stat = StatHaste, value = 4721},
        {stat = StatMastery},
        {stat = StatCrit},
        {stat = StatHaste},
      },
    },
    ["<Shadow> - 8085 <HasteLong>"] = {
      prio = {
        {stat = StatHit, preset = SpellHitCap},
        {stat = StatHaste, value = 8085},
        {stat = StatCrit},
        {stat = StatMastery},
        {stat = StatHaste},
      },
    },
    ["<Shadow> - 10124 <HasteLong>"] = {
      prio = {
        {stat = StatHit, preset = SpellHitCap},
        {stat = StatHaste, value = 10124},
        {stat = StatCrit},
        {stat = StatMastery},
        {stat = StatHaste},
      },
    },
  },
  ["ROGUE"] = {
    ["<Assassination>"] = {
      prio = {
        {stat = StatHit, preset = MeleeHitCap},
        {stat = StatExp, preset = ExpSoftCap},
        {stat = StatMastery},
        {stat = StatHaste},
        {stat = StatCrit},
        {stat = StatHit, preset = MeleeDWHitCap},
      },
    },
    ["<Combat>"] = {
      prio = {
        {stat = StatExp, preset = ExpSoftCap},
        {stat = StatHit, preset = MeleeHitCap},
        {stat = StatHaste},
        {stat = StatMastery},
        {stat = StatCrit},
        {stat = StatHit, preset = MeleeDWHitCap},
      },
    },
    ["<Subtlety>"] = {
      prio = {
        {stat = StatHit, preset = MeleeHitCap},
        {stat = StatExp, preset = ExpSoftCap},
        {stat = StatHaste},
        {stat = StatCrit},
        {stat = StatMastery},
        {stat = StatHit, preset = MeleeDWHitCap},
      },
    },
  },
  ["SHAMAN"] = {
    ["<Elemental>"] = {
      prio = {
        {stat = StatHit, preset = SpellHitCap},
        {stat = StatMastery},
        {stat = StatHaste},
        {stat = StatCrit},
      },
    },
    ["<Enhancement>"] = {
      prio = {
        {stat = StatHit, preset = MeleeHitCap},
        {stat = StatExp, preset = ExpSoftCap},
        {stat = StatMastery},
        {stat = StatHaste},
        {stat = StatCrit},
      },
    },
    ["<Restoration> - 871 <HasteLong>"] = {
      prio = {
        {stat = StatSpirit},
        {stat = StatHaste, value = 871},
        {stat = StatMastery, value = 5400},
        {stat = StatCrit},
        {stat = StatHaste},
      },
    },
    ["<Restoration> - 3764 <HasteLong>"] = {
      prio = {
        {stat = StatSpirit},
        {stat = StatHaste, value = 3764},
        {stat = StatMastery, value = 5400},
        {stat = StatCrit},
        {stat = StatHaste},
      },
    },
    ["<Restoration> - 5676 <HasteLong>"] = {
      prio = {
        {stat = StatSpirit},
        {stat = StatHaste, value = 5676},
        {stat = StatMastery, value = 5400},
        {stat = StatCrit},
        {stat = StatHaste},
      },
    },
  },
  ["WARLOCK"] = {
    ["<Affliction> - 9778 <HasteLong>"] = {
      prio = {
        {stat = StatHit, preset = SpellHitCap},
        {stat = StatHaste, value = 9778},
        {stat = StatMastery},
        {stat = StatHaste},
        {stat = StatCrit},
      },
    },
    ["<Affliction> - 13737 <HasteLong>"] = {
      prio = {
        {stat = StatHit, preset = SpellHitCap},
        {stat = StatHaste, value = 13737},
        {stat = StatMastery},
        {stat = StatHaste},
        {stat = StatCrit},
      },
    },
    ["<Demonology>"] = {
      prio = {
        {stat = StatHit, preset = SpellHitCap},
        {stat = StatHaste, value = 4717},
        {stat = StatCrit},
        {stat = StatMastery},
        {stat = StatHaste},
      },
    },
    ["<Destruction>"] = {
      prio = {
        {stat = StatHit, preset = SpellHitCap},
        {stat = StatMastery},
        {stat = StatHaste},
        {stat = StatCrit},
      },
    },
  },
  ["WARRIOR"] = {
    ["<Arms>"] = {
      prio = {
        {stat = StatHit, preset = MeleeHitCap},
        {stat = StatExp, preset = ExpSoftCap},
        {stat = StatCrit},
        {stat = StatMastery},
        {stat = StatHaste},
      },
    },
    ["<Fury>"] = {
      prio = {
        {stat = StatHit, preset = MeleeHitCap},
        {stat = StatExp, preset = ExpSoftCap},
        {stat = StatCrit},
        {stat = StatMastery},
        {stat = StatHaste},
      },
    },
    ["<Protection>"] = {
      prio = {
        {stat = StatHit, preset = MeleeHitCap},
        {stat = StatExp, preset = ExpHardCap},
        {stat = StatMastery},
        {stat = StatParry},
        {stat = StatDodge},
      },
    },
  },
}
EUIReforge.importFuncs = {
  ["wowreforge.com"] = EUIReforge.ParseWowReforge,
}

local _, unitClass = UnitClass ("player")
EUIReforge.presets = EUIReforge.presets[unitClass]

function EUIReforge:InitPresets ()
  self.presets["<Custom>"] = self.db.customPresets
  
  if PawnVersion then
    local PawnMap = {
      Spirit = true,
      DodgeRating = true,
      ParryRating
    }
    self.presets["Pawn scales"] = function ()
      if PawnCommon == nil or PawnCommon.Scales == nil then return {} end
      local result = {}
      for k, v in pairs (PawnCommon.Scales) do
        local preset = {leaf = "import"}
        preset.weights = {}
        local raw = v.Values or {}
        preset.weights[self.STATS.SPIRIT] = raw["Spirit"] or 0
        preset.weights[self.STATS.DODGE] = raw["DodgeRating"] or 0
        preset.weights[self.STATS.PARRY] = raw["ParryRating"] or 0
        preset.weights[self.STATS.HIT] = raw["HitRating"] or 0
        preset.weights[self.STATS.CRIT] = raw["CritRating"] or 0
        preset.weights[self.STATS.HASTE] = raw["HasteRating"] or 0
        preset.weights[self.STATS.EXP] = raw["ExpertiseRating"] or 0
        preset.weights[self.STATS.MASTERY] = raw["MasteryRating"] or 0
        local total = 0
        local average = 0
        for i = 1, #self.itemStats do
          if preset.weights[i] ~= 0 then
            total = total + 1
            average = average + preset.weights[i]
          end
        end
        if total > 0 and average > 0 then
          local factor = 1
          while factor * average / total < 10 do
            factor = factor * 100
          end
          while factor * average / total > 1000 do
            factor = factor / 10
          end
          for i = 1, #self.itemStats do
            preset.weights[i] = preset.weights[i] * factor
          end
          result[v.LocalizedName or k] = preset
        end
      end
      return result
    end
  end

  -- Menus (EllesmereUI menu, GUI:OpenMenu) in place of the UIDropDownMenus.
end

local function PresetName (k)
  return (k:gsub ("<([^>]*)>", function (s) return EUIReforgeLocale[s] end))
end

local function SortItems (items)
  table.sort (items, function (a, b) return a.text < b.text end)
  return items
end

-- Stat weight presets: class > spec (and <Custom>, Pawn scales) tree.
function EUIReforge:GetPresetMenu (list)
  local items = {}
  list = list or self.presets
  for k, v in pairs (list) do
    if type (v) == "function" then
      v = v ()
    end
    local item = {text = PresetName (k)}
    if v.caps or v.weights or v.leaf or v.prio then
      local preset = v
      item.func = function ()
        if preset.leaf == "import" then
          self:SetStatWeights (preset.weights, preset.caps, preset.prio)
        else
          self:SetStatWeights (preset.weights, preset.caps or {}, preset.prio)
        end
      end
    elseif next (v) then
      local sub = v
      item.children = function () return self:GetPresetMenu (sub) end
    else
      item.disabled = true
    end
    items[#items + 1] = item
  end
  return SortItems (items)
end

function EUIReforge:GetPresetDeleteMenu ()
  local items = {}
  for k in pairs (self.db.customPresets) do
    items[#items + 1] = {text = k, func = function ()
      self.db.customPresets[k] = nil
      if next (self.db.customPresets) == nil then
        self.deletePresetButton:Disable ()
      end
    end}
  end
  return SortItems (items)
end

function EUIReforge:GetMethodPresetMenu ()
  local items = {}
  for k, v in pairs (self.pdb.customMethodPresets) do
    items[#items + 1] = {text = k, func = function ()
      self.pdb.method = v
      self:UpdateMethodCategory ()
    end}
  end
  return SortItems (items)
end

function EUIReforge:GetMethodPresetDeleteMenu ()
  local items = {}
  for k in pairs (self.pdb.customMethodPresets) do
    items[#items + 1] = {text = k, func = function ()
      self.pdb.customMethodPresets[k] = nil
      if next (self.pdb.customMethodPresets) == nil then
        self.methodPresetsButton:Disable ()
        self.deleteMethodPresetButton:Disable ()
      end
    end}
  end
  return SortItems (items)
end
