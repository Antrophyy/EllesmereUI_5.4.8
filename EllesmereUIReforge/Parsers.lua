-- Part of ReforgeLite by d07.RiV (Iroared)
-- All rights reserved

local L = EUIReforgeLocale
local MOP = (GetNumTalentTabs == nil)

----------------------------------------------------------------

local wrItems = {
  ["Head"] = 1,
  ["Neck"] = 2,
  ["Shoulders"] = 3,
  ["Back"] = 4,
  ["Chest"] = 5,
  ["Wrists"] = 6,
  ["Hands"] = 7,
  ["Waist"] = 8,
  ["Legs"] = 9,
  ["Feet"] = 10,
  ["Ring1"] = 11,
  ["Ring2"] = 12,
  ["Trinket1"] = 13,
  ["Trinket2"] = 14,
  ["MainHand"] = 15,
  ["OffHand"] = 16,
}
local wrStats = {
  ["Spirit"] = 1,
  ["DodgeRating"] = 2,
  ["ParryRating"] = 3,
  ["HitRating"] = 4,
  ["CritRating"] = 5,
  ["HasteRating"] = 6,
  ["ExpertiseRating"] = 7,
  ["MasteryRating"] = 8,
}

EUIReforge.ParseWowReforge = function(text)
  local method = {items = {}}
  for itemRaw, srcRaw, dstRaw in string.gmatch(text, "([%a%d]+) : ([%a%d]+) %-> ([%a%d]+)") do
    if itemRaw and srcRaw and dstRaw and wrItems[itemRaw] and wrStats[srcRaw] and wrStats[dstRaw] then
      method.items[wrItems[itemRaw]] = {
        src = wrStats[srcRaw],
        dst = wrStats[dstRaw],
      }
    end
  end
  return method
end

----------------------------------------------------------------

-- Import box (EllesmereUI popup with a multi-line text box).
function EUIReforge:RunImport(func)
  EUIReforgeGUI:ShowPopup({
    title = L["Import"],
    message = "wowreforge.com",
    multiLine = true,
    width = 360,
    height = 260,
    onAccept = function(text)
      local method = func(text)
      if method and self:IsMethodValid(method) then
        self:UpdateMethodStats(method)
        self.pdb.method = method
        self:UpdateMethodCategory()
      end
    end,
  })
end
