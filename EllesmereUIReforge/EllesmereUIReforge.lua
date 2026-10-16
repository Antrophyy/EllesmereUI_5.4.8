-- ReforgeLite v1.38 by d07.RiV (Iroared)
-- All rights reserved
--
-- EllesmereUIReforge: ReforgeLite moved into the EllesmereUI suite. The
-- reforge math is ReforgeLite's; the windows and widgets are EllesmereUI
-- style (GUI.lua). Settings: /eui > QoL Addons > Reforge. Window: /reforge.

local addonName = ...
local ns = EllesmereUI

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
local GUI = EUIReforgeGUI

local MOP = (GetNumTalentTabs == nil)

EUIReforge = CreateFrame ("Frame", "EUIReforgeFrame", UIParent)
EUIReforge:Hide ()
EUIReforge.initialized = false
EllesmereUIReforgeDB = nil
local DefaultDB = {
  itemSize = 24,
  windowWidth = 820,
  windowHeight = 600,

  reforgeCheat = 5,

  openOnReforge = true,
--  updateTooltip = true,

  customPresets = {
  },
  profiles = {
  },
}
local DefaultDBProfile = {
  targetLevel = 3,
  ilvlCap = 0,

  buffs = {
  },
  weights = {0, 0, 0, 0, 0, 0, 0, 0},
  caps = {
    {
      stat = 0,
      points = {
        {
          method = 1,
          value = 0,
          after = 0,
          preset = 1
        }
      }
    },
    {
      stat = 0,
      points = {
        {
          method = 1,
          value = 0,
          after = 0,
          preset = 1
        }
      }
    }
  },
  itemsLocked = {},
  customMethodPresets = {
  },
}
local function MergeTables (dst, src)
  for k, v in pairs (src) do
    if type (v) ~= "table" then
      if dst[k] == nil then
        dst[k] = v
      end
    else
      if type (dst[k]) ~= "table" then
        dst[k] = {}
      end
      MergeTables (dst[k], v)
    end
  end
end

EUIReforge.dbkey = UnitName ("player") .. " - " .. GetRealmName ()
local _, playerClass = UnitClass ("player")
local _, playerRace = UnitRace ("player")
playerRace = string.upper(playerRace)
local missChance = (playerRace == "NIGHTELF" and 7 or 5)

function EUIReforge:UpgradeDBCaps (caps)
  for i = 1, #caps do
    if caps[i].points == nil or caps[i].value or caps[i].method or caps[i].after then
      caps[i].points = {}
      caps[i].points[1] = {
        method = caps[i].method or 1,
        value = caps[i].value or 0,
        after = caps[i].after or 0
      }
      for j = 1, #caps[i].points do
        if not caps[i].points[j].preset then
          caps[i].points[j].preset = 1
        end
      end
      caps[i].method = nil
      caps[i].value = nil
      caps[i].after = nil
    end
  end
end
function EUIReforge:UpgradeDB ()
  if not EllesmereUIReforgeDB then
    EllesmereUIReforgeDB = DefaultDB
  else
    MergeTables (EllesmereUIReforgeDB, DefaultDB)
  end
  local db = EllesmereUIReforgeDB
  if db.profiles[self.dbkey] == nil then
    db.profiles[self.dbkey] = DefaultDBProfile
  else
    MergeTables (db.profiles[self.dbkey], DefaultDBProfile)
  end
  local pdb = db.profiles[self.dbkey]
  if pdb.method and pdb.method.items then
    pdb.method.items[17] = nil
  end
  pdb.storedMethod = nil
  for k, v in pairs (pdb) do
    if db[k] ~= nil then
      pdb[k] = db[k]
      db[k] = nil
    end
  end
  if db.statCaps then
    pdb.caps = db.statCaps
    db.statCaps = nil
  end
  if db.statWeights then
    pdb.weights = db.statWeights
    db.statWeights = nil
  end
  self:UpgradeDBCaps (pdb.caps)
  db.convertSpirit = nil
  -- ReforgeLite window border colors: the EllesmereUI windows use the accent.
  db.activeWindowTitle = nil
  db.inactiveWindowTitle = nil
  if pdb.method then
    pdb.method.caps = nil
    pdb.method.weights = nil
  end
  if pdb.prio then
    for i = 1, #pdb.prio do
      if pdb.prio[i] then
        pdb.prio[i].preset = pdb.prio[i].preset or 1
        pdb.prio[i].value = pdb.prio[i].value or 0
      else
        pdb.prio[i] = {stat = 0, capped = false, preset = 1, value = 0}
      end
    end
  end
end

-----------------------------------------------------------------

-- Save preset popups (EllesmereUI popup in place of the Blizzard StaticPopups).
function EUIReforge:ShowSavePresetPopup ()
  GUI:ShowPopup ({
    title = L["Save"],
    message = L["Enter the preset name"],
    maxLetters = 31,
    requireText = true,
    onAccept = function (name)
      self.db.customPresets[name] = {
        caps = DeepCopy (self.pdb.caps),
        weights = DeepCopy (self.pdb.weights),
        prio = DeepCopy (self.pdb.prio)
      }
      self.deletePresetButton:Enable ()
    end,
  })
end

function EUIReforge:ShowSaveMethodPresetPopup ()
  GUI:ShowPopup ({
    title = L["Save"],
    message = L["Enter the preset name"],
    maxLetters = 31,
    requireText = true,
    onAccept = function (name)
      self.pdb.customMethodPresets[name] = DeepCopy (self.pdb.method)
      self.methodPresetsButton:Enable ()
      self.deleteMethodPresetButton:Enable ()
    end,
  })
end

if MOP then
  EUIReforge.itemSlots = {
    "HeadSlot",
    "NeckSlot",
    "ShoulderSlot",
    "BackSlot",
    "ChestSlot",
    "WristSlot",
    "HandsSlot",
    "WaistSlot",
    "LegsSlot",
    "FeetSlot",
    "Finger0Slot",
    "Finger1Slot",
    "Trinket0Slot",
    "Trinket1Slot",
    "MainHandSlot",
    "SecondaryHandSlot"
  }
else
  EUIReforge.itemSlots = {
    "HeadSlot",
    "NeckSlot",
    "ShoulderSlot",
    "BackSlot",
    "ChestSlot",
    "WristSlot",
    "HandsSlot",
    "WaistSlot",
    "LegsSlot",
    "FeetSlot",
    "Finger0Slot",
    "Finger1Slot",
    "Trinket0Slot",
    "Trinket1Slot",
    "MainHandSlot",
    "SecondaryHandSlot",
    "RangedSlot"
  }
end

local function RatingStat (i, name_, tip_, id_, hid_)
  if hid_ then
    local _, class = UnitClass ("player")
    if class == "HUNTER" then
      id_ = hid_
    end
  end
  return {
    name = name_,
    tip = L[tip_],
    long = L[tip_ .. "Long"],
    getter = function ()
      return (GetCombatRating (id_))
    end,
    mgetter = function (method, orig)
      return (orig and method.orig_stats and method.orig_stats[i]) or method.stats[i]
    end
  }
end
EUIReforge.itemStats = {
  {
    name = "ITEM_MOD_SPIRIT_SHORT",
    tip = L["Spirit"],
    long = L["SpiritLong"],
    getter = function ()
      return (select (2, UnitStat ("player", 5)))
    end,
    mgetter = function (method, orig)
      return (orig and method.orig_stats and method.orig_stats[1]) or method.stats[1]
    end
  },
  RatingStat (2, "ITEM_MOD_DODGE_RATING_SHORT", "Dodge", CR_DODGE),
  RatingStat (3, "ITEM_MOD_PARRY_RATING_SHORT", "Parry", CR_PARRY),
  {
    name = "ITEM_MOD_HIT_RATING_SHORT",
    tip = L["Hit"],
    long = L["HitLong"],
    getter = function()
      local result = GetCombatRating(class == "HUNTER" and CR_HIT_RANGED or CR_HIT_SPELL)
      local conv = EUIReforge:GetConversion()
      if conv[EUIReforge.STATS.EXP] and conv[EUIReforge.STATS.EXP][EUIReforge.STATS.HIT] then
        result = result + math.floor(GetCombatRating(CR_EXPERTISE) * conv[EUIReforge.STATS.EXP][EUIReforge.STATS.HIT])
      end
      return result
    end,
    mgetter = function (method, orig)
      return (orig and method.orig_stats and method.orig_stats[4]) or method.stats[4]
    end
  },
  RatingStat (5, "ITEM_MOD_CRIT_RATING_SHORT", "Crit", CR_CRIT_SPELL, CR_CRIT_RANGED),
  {
    name = "ITEM_MOD_HASTE_RATING_SHORT",
    tip = L["Haste"],
    long = L["HasteLong"],
    getter = function()
      local result = GetCombatRating(class == "HUNTER" and CR_HASTE_RANGED or CR_HASTE_SPELL)
      if class == "MONK" and GetShapeshiftFormID() == 20 then
        result = math.floor(result / 1.5 + 0.5)
      end
      return result
    end,
    mgetter = function (method, orig)
      return (orig and method.orig_stats and method.orig_stats[6]) or method.stats[6]
    end
  },
  RatingStat (7, "ITEM_MOD_EXPERTISE_RATING_SHORT", "Exp", CR_EXPERTISE),
  RatingStat (8, "ITEM_MOD_MASTERY_RATING_SHORT", "Mastery", CR_MASTERY)
}
EUIReforge.STATS = {
  SPIRIT = 1, DODGE = 2, PARRY = 3, HIT = 4, CRIT = 5, HASTE = 6, EXP = 7, MASTERY = 8, SPELLHIT = 9, BLOCK = 10, CRITBLOCK = 11
}

EUIReforge.REFORGE_TABLE_BASE = 112
EUIReforge.reforgeTable = {
  {1, 2}, {1, 3}, {1, 4}, {1, 5}, {1, 6}, {1, 7}, {1, 8},
  {2, 1}, {2, 3}, {2, 4}, {2, 5}, {2, 6}, {2, 7}, {2, 8},
  {3, 1}, {3, 2}, {3, 4}, {3, 5}, {3, 6}, {3, 7}, {3, 8},
  {4, 1}, {4, 2}, {4, 3}, {4, 5}, {4, 6}, {4, 7}, {4, 8},
  {5, 1}, {5, 2}, {5, 3}, {5, 4}, {5, 6}, {5, 7}, {5, 8},
  {6, 1}, {6, 2}, {6, 3}, {6, 4}, {6, 5}, {6, 7}, {6, 8},
  {7, 1}, {7, 2}, {7, 3}, {7, 4}, {7, 5}, {7, 6}, {7, 8},
  {8, 1}, {8, 2}, {8, 3}, {8, 4}, {8, 5}, {8, 6}, {8, 7},
}

local REFORGE_COEFF = 0.4

function EUIReforge:UpdateWindowSize ()
  self.db.windowWidth = self:GetWidth ()
  self.db.windowHeight = self:GetHeight ()
end

function EUIReforge:GetCapScore (cap, value)
  local score = 0
  for i = #cap.points, 1, -1 do
    if value > cap.points[i].value then
      score = score + cap.points[i].after * (value - cap.points[i].value)
      value = cap.points[i].value
    end
  end
  score = score + self.pdb.weights[cap.stat] * value
  return score
end
function EUIReforge:GetStatScore (stat, value)
  if stat == self.pdb.caps[1].stat then
    return self:GetCapScore (self.pdb.caps[1], value)
  elseif stat == self.pdb.caps[2].stat then
    return self:GetCapScore (self.pdb.caps[2], value)
  else
    return self.pdb.weights[stat] * value
  end
end

function EUIReforge:ParsePawnString (pawn)
  local pos, _, version, name, values = strfind (pawn, "^%s*%(%s*Pawn%s*:%s*v(%d+)%s*:%s*\"([^\"]+)\"%s*:%s*(.+)%s*%)%s*$")
  version = tonumber (version)
  if not (pos and version and name and values) or name == "" or values == "" or version > 1 then
    return
  end

  local raw = {}
  local average = 0
  local total = 0
  gsub (values .. ",", "[^,]*,", function (pair)
    local pos, _, stat, value = strfind (pair, "^%s*([%a%d]+)%s*=%s*(%-?[%d%.]+)%s*,$")
    value = tonumber (value)
    if pos and stat and stat ~= "" and value then
      raw[stat] = value
      average = average + value
      total = total + 1
    end
  end)
  local factor = 1
  if average / total < 10 then
    factor = 100
  end
  for k, v in pairs (raw) do
    raw[k] = math.floor (v * factor + 0.5)
  end

  local weights = {}
  weights[self.STATS.SPIRIT] = raw["Spirit"] or 0
  weights[self.STATS.DODGE] = raw["DodgeRating"] or 0
  weights[self.STATS.PARRY] = raw["ParryRating"] or 0
  weights[self.STATS.HIT] = raw["HitRating"] or 0
  weights[self.STATS.CRIT] = raw["CritRating"] or 0
  weights[self.STATS.HASTE] = raw["HasteRating"] or 0
  weights[self.STATS.EXP] = raw["ExpertiseRating"] or 0
  weights[self.STATS.MASTERY] = raw["MasteryRating"] or 0

  self:SetStatWeights (weights)
end

function EUIReforge:ShowPawnPopup ()
  GUI:ShowPopup ({
    title = L["Import"] .. " Pawn",
    message = L["Enter pawn string"],
    width = 420,
    maxLetters = 1024,
    requireText = true,
    onAccept = function (pawn)
      self:ParsePawnString (pawn)
    end,
  })
end

------------------------------------------------------------------------

-- Collapsible section (EllesmereUI section header: arrow, upper case label, thin line).
function EUIReforge:CreateCategory (name)
  local c = CreateFrame ("Frame", nil, self.content)
  c:ClearAllPoints ()
  c:SetWidth (16)
  c:SetHeight (16)
  c.expanded = true

  c.name = GUI:Text (c, "EUIReforgeFont", 0.5)
  c.catname = c.name
  c.name:SetPoint ("LEFT", c, "LEFT", 20, 0)
  c.name:SetText (name:upper ())

  c.line = GUI.Solid (c, "ARTWORK", 1, 1, 1, 0.06)
  c.line:SetHeight (1)
  c.line:SetPoint ("LEFT", c.name, "RIGHT", 10, 0)
  c.line:SetPoint ("RIGHT", self.content, "RIGHT", -12, 0)

  c.button = CreateFrame ("Button", nil, c)
  c.button:ClearAllPoints ()
  c.button:SetWidth (16)
  c.button:SetHeight (16)
  c.button:SetPoint ("TOPLEFT", c, "TOPLEFT", 0, 0)
  c.button.icon = c.button:CreateTexture (nil, "ARTWORK")
  c.button.icon:SetSize (18, 18)
  c.button.icon:SetPoint ("CENTER")
  c.button.icon:SetVertexColor (1, 1, 1, 0.5)
  c.button.UpdateTexture = function (self)
    if self:GetParent ().expanded then
      self.icon:SetTexture (ns.MEDIA .. "ui\\eui-arrow")
    else
      self.icon:SetTexture (ns.MEDIA .. "ui\\eui-arrow-right")
    end
    self.icon:SetTexCoord (0, 30 / 32, 0, 30 / 32)
  end
  c.button:UpdateTexture ()
  c.button:SetScript ("OnClick", function (self)
    self:GetParent ():Toggle ()
  end)
  c.button:SetScript ("OnEnter", function (self)
    self.icon:SetVertexColor (1, 1, 1, 0.9)
    c.name:SetTextColor (1, 1, 1, 0.8)
  end)
  c.button:SetScript ("OnLeave", function (self)
    self.icon:SetVertexColor (1, 1, 1, 0.5)
    c.name:SetTextColor (1, 1, 1, 0.5)
  end)
  -- The label toggles the section too.
  c:EnableMouse (true)
  c:SetHitRectInsets (0, -(c.name:GetStringWidth () + 24), 0, 0)
  c:SetScript ("OnMouseUp", function (self, button)
    if button == "LeftButton" then
      self:Toggle ()
    end
  end)
  c:SetScript ("OnEnter", function () c.button:GetScript ("OnEnter") (c.button) end)
  c:SetScript ("OnLeave", function () c.button:GetScript ("OnLeave") (c.button) end)
  c.button.anchor = {point = "TOPLEFT", rel = c, relPoint = "TOPLEFT", x = 0, y = 0}

  c.frames = {}
  c.anchors = {}
  c.AddFrame = function (self, frame)
    table.insert (self.frames, frame)
    frame.Show2 = function (self)
      if self.category.expanded then
        self:Show ()
      end
      self.chidden = nil
    end
    frame.Hide2 = function (self)
      self:Hide ()
      self.chidden = true
    end
    frame.category = self
  end

  c.Toggle = function (self)
    self.expanded = not self.expanded
    if c.expanded then
      for k, v in pairs (self.frames) do
        if not v.chidden then
          v:Show ()
        end
      end
      for k, v in pairs (self.anchors) do
        v.frame:SetPoint (v.point, v.rel, v.relPoint, v.x, v.y)
      end
    else
      for k, v in pairs (self.frames) do
        v:Hide ()
      end
      for k, v in pairs (self.anchors) do
        v.frame:SetPoint (v.point, self.button, v.relPoint, v.x, v.y)
      end
    end
    self.button:UpdateTexture ()
    EUIReforge:UpdateContentSize ()
  end

  return c
end

function EUIReforge:SetAnchor (frame_, point_, rel_, relPoint_, offsX, offsY)
  if rel_ and rel_.catname and rel_.button then
    rel_ = rel_.button
  end
  if rel_.category then
    table.insert (rel_.category.anchors, {frame = frame_, point = point_, rel = rel_, relPoint = relPoint_, x = offsX, y = offsY})
    if rel_.category.expanded then
      frame_:SetPoint (point_, rel_, relPoint_, offsX, offsY)
    else
      frame_:SetPoint (point_, rel_.category.button, relPoint_, offsX, offsY)
    end
  else
    frame_:SetPoint (point_, rel_, relPoint_, offsX, offsY)
  end
  frame_.anchor = {point = point_, rel = rel_, relPoint = relPoint_, x = offsX, y = offsY}
end
function EUIReforge:GetFrameY (frame)
  local cur = frame
  local offs = 0
  while cur and cur ~= self.content do
    if cur.anchor == nil then
      return offs
    end
    if cur.anchor.point:find ("BOTTOM") then
      offs = offs + cur:GetHeight ()
    end
    local rel = cur.anchor.rel
    if rel.category and not rel.category.expanded then
      rel = rel.category.button
    end
    if cur.anchor.relPoint:find ("BOTTOM") then
      offs = offs - rel:GetHeight ()
    end
    offs = offs + cur.anchor.y
    cur = rel
  end
  return offs
end

local function SetTextDelta (text, value, cur, override, percent)
  override = override or (value - cur)
  if override == 0 then
    text:SetTextColor (1, 1, 1, 0.4)
  elseif override > 0 then
    text:SetTextColor (0.4, 0.9, 0.5)
  else
    text:SetTextColor (0.95, 0.35, 0.35)
  end
  if percent then
    text:SetText (string.format ("%+.2f%%", value - cur))
  else
    text:SetText (string.format ("%+d", value - cur))
  end
end

------------------------------------------------------------------------

function EUIReforge:SetScroll (value)
  local viewheight = self.scrollFrame:GetHeight ()
  local height = self.content:GetHeight ()
  local offset

  if viewheight > height then
    offset = 0
  else
    offset = math.floor ((height - viewheight) / 1000 * value)
  end
  self.content:ClearAllPoints ()
  self.content:SetPoint ("TOPLEFT", 0, offset)
  self.content:SetPoint ("TOPRIGHT", 0, offset)
  self.scrollOffset = offset
  self.scrollValue = value
end
function EUIReforge:MoveScroll (value)
  local viewheight = self.scrollFrame:GetHeight ()
  local height = self.content:GetHeight ()
  if self.scrollBarShown then
    local diff = height - viewheight
    local delta = (value > 0 and -1 or 1)
    self.scrollBar:SetValue (min (max (self.scrollValue + delta * (1000 / (diff / 45)), 0), 1000))
  end
end
function EUIReforge:FixScroll ()
  self:SetScript ("OnUpdate", nil)

  local offset = self.scrollOffset
  local viewheight = self.scrollFrame:GetHeight ()
  local height = self.content:GetHeight ()
  if height < viewheight + 2 then
    if self.scrollBarShown then
      self.scrollBarShown = false
      self.scrollBar:Hide ()
      self.scrollBar:SetValue (0)
    end
  else
    if not self.scrollBarShown then
      self.scrollBarShown = true
      self.scrollBar:Show ()
    end
    self.scrollBar:SetRatio (viewheight / height)
    local value = (offset / (height - viewheight) * 1000)
    if value > 1000 then value = 1000 end
    self.scrollBar:SetValue (value)
    self:SetScroll (value)
    if value < 1000 then
      self.content:ClearAllPoints ()
      self.content:SetPoint ("TOPLEFT", 0, offset)
      self.content:SetPoint ("TOPRIGHT", 0, offset)
    end
  end
end

local PAD = 14

function EUIReforge:CreateFrame ()
  self.initialized = true
  self:ClearAllPoints ()
  self:SetWidth (self.db.windowWidth)
  self:SetHeight (self.db.windowHeight)
  self:SetMinResize (780, 500)
  self:SetMaxResize (1200, 900)
  if self.db.windowX and self.db.windowY then
    self:SetPoint ("TOPLEFT", UIParent, "BOTTOMLEFT", self.db.windowX, self.db.windowY)
  else
    self:SetPoint ("CENTER")
  end
  GUI:StyleWindow (self, "Reforge")

  self:EnableMouse (true)
  self:SetMovable (true)
  self:SetResizable (true)
  self:SetScript ("OnMouseDown", function (self, arg)
    if arg == "LeftButton" then
      self:StartMoving ()
      self.moving = true
    end
  end)
  self:SetScript ("OnMouseUp", function (self)
    if self.moving then
      self:StopMovingOrSizing ()
      self.moving = false
      self.db.windowX = self:GetLeft ()
      self.db.windowY = self:GetTop ()
    end
  end)
  self.grip = GUI:CreateResizeGrip (self, function ()
    self:UpdateWindowSize ()
    self.db.windowX = self:GetLeft ()
    self.db.windowY = self:GetTop ()
  end)

  self:CreateItemTable ()

  self.scrollValue = 0
  self.scrollOffset = 0
  self.scrollBarShown = false

  -- Thin line between the item table and the options.
  local divider = GUI.Solid (self, "ARTWORK", 1, 1, 1, 0.06)
  divider:SetWidth (1)
  divider:SetPoint ("TOP", self, "TOP", 0, -(GUI.HEADER_H + PAD))
  divider:SetPoint ("BOTTOM", self, "BOTTOM", 0, PAD)
  divider:SetPoint ("LEFT", self.itemTable, "RIGHT", PAD, 0)

  self.scrollFrame = CreateFrame ("ScrollFrame", nil, self)
  self.scrollFrame:ClearAllPoints ()
  self.scrollFrame:SetPoint ("LEFT", self.itemTable, "RIGHT", PAD * 2, 0)
  self.scrollFrame:SetPoint ("TOP", self, "TOP", 0, -(GUI.HEADER_H + PAD))
  self.scrollFrame:SetPoint ("BOTTOMRIGHT", self, "BOTTOMRIGHT", -22, PAD + 8)
  self.scrollFrame:EnableMouseWheel (true)
  self.scrollFrame:SetScript ("OnMouseWheel", function (self, value)
    EUIReforge:MoveScroll (value)
  end)
  self.scrollFrame:SetScript ("OnSizeChanged", function (self)
    EUIReforge:SetScript ("OnUpdate", EUIReforge.FixScroll)
  end)

  self.scrollBar = GUI:CreateScrollBar (self)
  self.scrollBar:SetPoint ("TOPLEFT", self.scrollFrame, "TOPRIGHT", 8, 0)
  self.scrollBar:SetPoint ("BOTTOMLEFT", self.scrollFrame, "BOTTOMRIGHT", 8, 0)
  self.scrollBar.onValueChanged = function (value)
    EUIReforge:SetScroll (value)
  end
  self.scrollBar:Hide ()

  self.content = CreateFrame ("Frame", nil, self.scrollFrame)
  self.scrollFrame:SetScrollChild (self.content)
  self.content:ClearAllPoints ()
  self.content:SetPoint ("TOPLEFT")
  self.content:SetPoint ("TOPRIGHT")
  self.content:SetHeight (1000)
  -- A scroll child gets no width from TOPLEFT / TOPRIGHT: follow the view.
  self.content:SetWidth (self.scrollFrame:GetWidth ())
  self.scrollFrame:HookScript ("OnSizeChanged", function (frame, w)
    EUIReforge.content:SetWidth (w)
  end)

  GUI.defaultParent = self.content

  self:CreateOptionList ()

  self:SetScript ("OnUpdate", self.FixScroll)
end

-- Equipped item icon: cropped, 1 pixel border, hover glow, lock overlay.
local function StyleItemIcon (frame)
  frame.texture = frame:CreateTexture (nil, "ARTWORK")
  frame.texture:SetPoint ("TOPLEFT", 1, -1)
  frame.texture:SetPoint ("BOTTOMRIGHT", -1, 1)
  frame.texture:SetTexCoord (0.08, 0.92, 0.08, 0.92)
  GUI.Solid (frame, "BACKGROUND", 0, 0, 0, 1):SetAllPoints ()
  frame.glow = GUI.Solid (frame, "OVERLAY", 1, 1, 1, 0.15)
  frame.glow:SetPoint ("TOPLEFT", 1, -1)
  frame.glow:SetPoint ("BOTTOMRIGHT", -1, 1)
  frame.glow:Hide ()
end

function EUIReforge:CreateItemTable ()
  local lockTip = GUI:Text (self, "EUIReforgeFontSmall", 0.45)
  lockTip:SetPoint ("TOPLEFT", self, "TOPLEFT", PAD, -(GUI.HEADER_H + PAD))
  lockTip:SetText (L["Click an item to lock it"])

  self.itemTable = GUI:CreateTable (#self.itemSlots + 1, #self.itemStats, self.db.itemSize, self.db.itemSize + 6, GUI.GRID_COLOR, self)
  self.itemTable:SetPoint ("TOPLEFT", lockTip, "BOTTOMLEFT", 0, -8)
  self.itemTable:SetPoint ("BOTTOM", self, "BOTTOM", 0, PAD)
  self.itemTable:SetWidth (400)

  for i, v in ipairs (self.itemStats) do
    self.itemTable:SetCellText (0, i, v.tip, "CENTER", {1, 1, 1, 0.5})
  end
  self.itemData = {}
  for i, v in ipairs (self.itemSlots) do
    self.itemData[i] = CreateFrame ("Frame", nil, self.itemTable)
    self.itemData[i].slot = v
    self.itemData[i]:ClearAllPoints ()
    self.itemData[i]:SetWidth (self.db.itemSize - 2)
    self.itemData[i]:SetHeight (self.db.itemSize - 2)
    self.itemTable:SetCell (i, 0, self.itemData[i])
    self.itemData[i]:EnableMouse (true)
    StyleItemIcon (self.itemData[i])
    self.itemData[i]:SetScript ("OnEnter", function (self)
      self.glow:Show ()
      GameTooltip:SetOwner (self, "ANCHOR_LEFT")
      local hasItem, hasCooldown, repairCost = GameTooltip:SetInventoryItem ("player", self.slotId)
      if not hasItem then
        local text = _G[strupper (self.slot)]
        if self.checkRelic then
          text = _G["RELICSLOT"]
        end
        GameTooltip:SetText (text)
      end
      GameTooltip:Show ()
    end)
    self.itemData[i]:SetScript ("OnLeave", function (self)
      self.glow:Hide ()
      GameTooltip:Hide ()
    end)
    self.itemData[i]:SetScript ("OnMouseDown", function ()
      self.pdb.itemsLocked[i] = not self.pdb.itemsLocked[i]
      if self.pdb.itemsLocked[i] then
        self.itemData[i].locked:Show ()
      else
        self.itemData[i].locked:Hide ()
      end
    end)
    self.itemData[i].slotId, self.itemData[i].slotTexture, self.itemData[i].checkRelic = GetInventorySlotInfo (v)
    self.itemData[i].checkRelic = self.itemData[i].checkRelic and UnitHasRelicSlot ("player")
    if self.itemData[i].checkRelic then
      self.itemData[i].slotTexture = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Relic.blp"
    end
    self.itemData[i].texture:SetTexture (self.itemData[i].slotTexture)
    -- Locked: dark overlay with a red cross.
    local locked = CreateFrame ("Frame", nil, self.itemData[i])
    locked:SetAllPoints ()
    locked:SetFrameLevel (self.itemData[i]:GetFrameLevel () + 2)
    GUI.Solid (locked, "ARTWORK", 0, 0, 0, 0.65):SetAllPoints ()
    locked.icon = locked:CreateTexture (nil, "OVERLAY")
    locked.icon:SetTexture (ns.MEDIA .. "ui\\eui-close")
    locked.icon:SetSize (12, 12)
    locked.icon:SetPoint ("CENTER")
    locked.icon:SetVertexColor (0.95, 0.3, 0.3, 1)
    self.itemData[i].locked = locked
    if not self.pdb.itemsLocked[i] then
      self.itemData[i].locked:Hide ()
    end

    self.itemData[i].stats = {}
    for j, s in ipairs (self.itemStats) do
      self.itemData[i].stats[j] = self.itemTable:CreateFontString (nil, "OVERLAY", "EUIReforgeFontSmall")
      self.itemTable:SetCell (i, j, self.itemData[i].stats[j])
      self.itemData[i].stats[j]:SetTextColor (1, 1, 1, 0.3)
      self.itemData[i].stats[j]:SetText ("-")
    end
  end
  self.statTotals = {}
  local accent = GUI.ACCENT
  self.itemTable:SetCellText (#self.itemSlots + 1, 0, L["Sum"], "CENTER", accent)
  for i, v in ipairs (self.itemStats) do
    self.statTotals[i] = self.itemTable:CreateFontString (nil, "OVERLAY", "EUIReforgeFontSmall")
    self.itemTable:SetCell (#self.itemSlots + 1, i, self.statTotals[i])
    self.statTotals[i]:SetTextColor (accent[1], accent[2], accent[3])
    self.statTotals[i]:SetText ("0")
  end
  GUI:OnAccent (function ()
    self.itemTable.cells[#self.itemSlots + 1][0]:SetTextColor (accent[1], accent[2], accent[3])
    for i = 1, #self.statTotals do
      self.statTotals[i]:SetTextColor (accent[1], accent[2], accent[3])
    end
  end)
end

function EUIReforge:CreateOptionList ()
  self:CreateTaskUI()

  self.computeButton = GUI:CreateButton (self.content, 140, 28, L["Compute"], true)
  self.computeButton:SetScript ("OnClick", function ()
    local method = self:Compute ()
    local curScore = (method and (self:GetMethodScore(method) - self:GetMethodPenalty(method)) or -500000)
    local oldScore = (self.pdb.method and (self:GetMethodScore(self.pdb.method) - self:GetMethodPenalty(self.pdb.method)) or -500000)
    if self.pdb.method and not self:IsMethodValid(self.pdb.method) then
      oldScore = -1000000
    end
    if curScore > oldScore then
      self.pdb.method = method
      self:UpdateMethodCategory()
      self.methodOverride = {}
      for i = 1, #self.itemSlots do
        self.methodOverride[i] = 0
      end
      self:UpdateMethodChecks()
    end
  end)

  self:UpdateTask ()

  self.lastElement = CreateFrame ("Frame", nil, self.content)
  self.lastElement:ClearAllPoints ()
  self.lastElement:SetWidth (0)
  self.lastElement:SetHeight (0)
  self:SetAnchor (self.lastElement, "TOPLEFT", self.computeButton, "BOTTOMLEFT", 0, -10)
  self:UpdateContentSize ()

  if not self.pdb.method then
    EUIReforge:ResetMethod()
  end
  if self.pdb.method then
    EUIReforge:UpdateMethodCategory ()
  end
end
function EUIReforge:GetCurrentScore ()
  local score = 0
  for i = 1, #self.itemStats do
    score = score + self:GetStatScore (i, self.itemStats[i].getter ())
  end
  return score
end
function EUIReforge:UpdateMethodCategory ()
  if self.methodCategory == nil then
    self.methodCategory = self:CreateCategory (L["Result"])
    self:SetAnchor (self.methodCategory, "TOPLEFT", self.computeButton, "BOTTOMLEFT", 0, -18)

    self.methodPresetsButton = GUI:CreateMenuButton (self.content, 114, 24, L["Presets"])
    self.methodPresetsButton:SetScript ("OnClick", function (btn)
      if GUI:IsMenuOpenFor (btn) then
        GUI:CloseMenu ()
      elseif next (self.pdb.customMethodPresets) then
        GUI:OpenMenu (btn, function () return self:GetMethodPresetMenu () end)
      end
    end)
    self.methodCategory:AddFrame (self.methodPresetsButton)
    self:SetAnchor (self.methodPresetsButton, "TOPLEFT", self.methodCategory, "BOTTOMLEFT", 0, -8)
    if next (self.pdb.customMethodPresets) == nil then
      self.methodPresetsButton:Disable ()
    end

    self.saveMethodPresetButton = GUI:CreateButton (self.content, 114, 24, L["Save"])
    self.methodCategory:AddFrame (self.saveMethodPresetButton)
    self.saveMethodPresetButton:SetScript ("OnClick", function ()
      self:ShowSaveMethodPresetPopup ()
    end)
    self:SetAnchor (self.saveMethodPresetButton, "LEFT", self.methodPresetsButton, "RIGHT", 6, 0)

    self.deleteMethodPresetButton = GUI:CreateMenuButton (self.content, 114, 24, L["Delete"])
    self.methodCategory:AddFrame (self.deleteMethodPresetButton)
    self.deleteMethodPresetButton:SetScript ("OnClick", function (btn)
      if GUI:IsMenuOpenFor (btn) then
        GUI:CloseMenu ()
      elseif next (self.pdb.customMethodPresets) then
        GUI:OpenMenu (btn, function () return self:GetMethodPresetDeleteMenu () end)
      end
    end)
    self:SetAnchor (self.deleteMethodPresetButton, "LEFT", self.saveMethodPresetButton, "RIGHT", 6, 0)
    if next (self.pdb.customMethodPresets) == nil then
      self.deleteMethodPresetButton:Disable ()
    end

    self.methodImportButton = GUI:CreateButton (self.content, 114, 24, L["Import"])
    self.methodImportButton.tooltip = "wowreforge.com"
    self.methodCategory:AddFrame (self.methodImportButton)
    self.methodImportButton:SetScript ("OnClick", function ()
      self:RunImport (self.ParseWowReforge)
    end)
    self:SetAnchor (self.methodImportButton, "LEFT", self.deleteMethodPresetButton, "RIGHT", 6, 0)

    self.methodStats = GUI:CreateTable (#self.itemStats, 2, self.db.itemSize, 70, GUI.GRID_COLOR)
    self.methodCategory:AddFrame (self.methodStats)
    self:SetAnchor (self.methodStats, "TOPLEFT", self.methodPresetsButton, "BOTTOMLEFT", 0, -10)
    self.methodStats:SetRowHeight (self.db.itemSize)
    self.methodStats:SetColumnWidth (70)

    local accent = GUI.ACCENT
    self.methodStats:SetCellText (0, 0, L["Score"], "LEFT", accent)
    self.methodStats.score = self.methodStats:CreateFontString (nil, "OVERLAY", "EUIReforgeFontSmall")
    self.methodStats:SetCell (0, 1, self.methodStats.score)
    self.methodStats.score:SetTextColor (accent[1], accent[2], accent[3])
    self.methodStats.score:SetText ("0")
    self.methodStats.scoreDelta = self.methodStats:CreateFontString (nil, "OVERLAY", "EUIReforgeFontSmall")
    self.methodStats:SetCell (0, 2, self.methodStats.scoreDelta)
    self.methodStats.scoreDelta:SetTextColor (1, 1, 1, 0.4)
    self.methodStats.scoreDelta:SetText ("+0")
    GUI:OnAccent (function ()
      self.methodStats.cells[0][0]:SetTextColor (accent[1], accent[2], accent[3])
      self.methodStats.score:SetTextColor (accent[1], accent[2], accent[3])
    end)

    for i, v in ipairs (self.itemStats) do
      self.methodStats:SetCellText (i, 0, v.tip, "LEFT", {1, 1, 1, 0.6})

      self.methodStats[i] = {}

      self.methodStats[i].value = self.methodStats:CreateFontString (nil, "OVERLAY", "EUIReforgeFontSmall")
      self.methodStats:SetCell (i, 1, self.methodStats[i].value)
      self.methodStats[i].value:SetTextColor (1, 1, 1, 0.9)
      self.methodStats[i].value:SetText ("0")

      self.methodStats[i].delta = self.methodStats:CreateFontString (nil, "OVERLAY", "EUIReforgeFontSmall")
      self.methodStats:SetCell (i, 2, self.methodStats[i].delta)
      self.methodStats[i].delta:SetTextColor (1, 1, 1, 0.4)
      self.methodStats[i].delta:SetText ("+0")
    end

    self.methodShow = GUI:CreateButton (self.content, 114, 24, L["Show"], true)
    self.methodShow:SetScript ("OnClick", function ()
      EUIReforge:ShowMethodWindow ()
    end)
    self.methodCategory:AddFrame (self.methodShow)
    self:SetAnchor (self.methodShow, "TOPLEFT", self.methodStats, "BOTTOMLEFT", 0, -10)

    self.methodReset = GUI:CreateButton (self.content, 114, 24, L["Reset"])
    self.methodReset:SetScript ("OnClick", function ()
      EUIReforge:ResetMethod ()
    end)
    self.methodCategory:AddFrame (self.methodReset)
    self:SetAnchor (self.methodReset, "BOTTOMLEFT", self.methodShow, "BOTTOMRIGHT", 6, 0)

    self:SetAnchor (self.lastElement, "TOPLEFT", self.methodShow, "BOTTOMLEFT", 0, -10)
  end

  self:RefreshMethodStats (true)

  self:UpdateContentSize ()
end
function EUIReforge:RefreshMethodStats (relax)
  local score = 0
  if self.pdb.method then
    self:UpdateMethodStats (self.pdb.method)
    score = self:GetMethodScore (self.pdb.method)
  end
  if self.pdb.method then
    if self.methodStats then
      local stats = self.itemStats

      self.methodStats.score:SetText (math.floor (score + 0.5))
      SetTextDelta (self.methodStats.scoreDelta, score, self:GetCurrentScore ())
      for i, v in ipairs (stats) do

        local mvalue = v.mgetter (self.pdb.method)
        if v.percent then
          self.methodStats[i].value:SetText (string.format ("%.2f%%", mvalue))
        else
          self.methodStats[i].value:SetText (string.format ("%d", mvalue))
        end
        local override = nil
        mvalue = v.mgetter (self.pdb.method, true)
        local value = v.getter ()
        if self:GetStatScore (i, mvalue) == self:GetStatScore (i, value) then
          override = 0
        end
        SetTextDelta (self.methodStats[i].delta, mvalue, value, override, v.percent)
      end
    end
  end
end
function EUIReforge:UpdateContentSize ()
  self.content:SetHeight (-self:GetFrameY (self.lastElement))
  self:SetScript ("OnUpdate", self.FixScroll)
end

function EUIReforge:GetReforgeID (item)
  local id = tonumber (item:match ("item:%d+:%d+:%d+:%d+:%d+:%d+:%-?%d+:%-?%d+:%d+:(%d+)"))
  return (id and id ~= 0 and (id - self.REFORGE_TABLE_BASE) or nil)
end

function EUIReforge:UpdateItems ()
  for i, v in ipairs (self.itemData) do
    local item = GetInventoryItemLink ("player", v.slotId)
    local texture = GetInventoryItemTexture ("player", v.slotId)
    local stats = {}
    local reforgeSrc, reforgeDst = nil, nil
    if item and texture then
      v.item = item
      v.texture:SetTexture (texture)
      stats = EUIReforge_GetItemStatsUp(item, self.pdb.ilvlCap) or {}
      local reforge = self:GetReforgeID (item)
      if reforge then
        reforgeSrc, reforgeDst = self.itemStats[self.reforgeTable[reforge][1]].name, self.itemStats[self.reforgeTable[reforge][2]].name
        local amount = math.floor ((stats[reforgeSrc] or 0) * 0.4)
        stats[reforgeSrc] = (stats[reforgeSrc] or 0) - amount
        stats[reforgeDst] = (stats[reforgeDst] or 0) + amount
      end
    else
      v.item = nil
      v.texture:SetTexture (v.slotTexture)
    end
    for j, s in ipairs (self.itemStats) do
      if stats[s.name] and stats[s.name] ~= 0 then
        self.itemData[i].stats[j]:SetText (stats[s.name])
        if s.name == reforgeSrc then
          self.itemData[i].stats[j]:SetTextColor (0.95, 0.35, 0.35)
        elseif s.name == reforgeDst then
          self.itemData[i].stats[j]:SetTextColor (0.4, 0.9, 0.5)
        else
          self.itemData[i].stats[j]:SetTextColor (1, 1, 1, 0.85)
        end
      else
        self.itemData[i].stats[j]:SetText ("-")
        self.itemData[i].stats[j]:SetTextColor (1, 1, 1, 0.3)
      end
    end
  end
  for i, v in ipairs (self.itemStats) do
    self.statTotals[i]:SetText (v.getter ())
  end
  self:UpdateTask()

  self:RefreshMethodStats ()
end
function EUIReforge:QueueUpdate ()
  if not self.initialized then
    return
  end
  self:SetScript ("OnUpdate", function (self)
    self:SetScript ("OnUpdate", nil)
    self:UpdateItems ()
  end)
  if self.methodWindow then
    self.methodWindow:SetScript ("OnUpdate", function (self)
      self:SetScript ("OnUpdate", nil)
      EUIReforge:UpdateMethodChecks ()
    end)
  end
end

--------------------------------------------------------------------------

function EUIReforge:ShowMethodWindow ()
  if self.methodWindow == nil then
    self.methodWindow = CreateFrame ("Frame", "EUIReforgeMethodWindow", UIParent)
    self.methodWindow:ClearAllPoints ()
    self.methodWindow:SetWidth (320)
    self.methodWindow:SetHeight (GUI.HEADER_H + 14 + (#self.itemSlots) * 26 + 14 + 28 + 14)
    if self.db.methodWindowX and self.db.methodWindowY then
      self.methodWindow:SetPoint ("TOPLEFT", UIParent, "BOTTOMLEFT", self.db.methodWindowX, self.db.methodWindowY)
    else
      self.methodWindow:SetPoint ("CENTER")
    end
    GUI:StyleWindow (self.methodWindow, L["Result"])

    self.methodWindow:EnableMouse (true)
    self.methodWindow:SetMovable (true)
    self.methodWindow:SetScript ("OnMouseDown", function (self, arg)
      if arg == "LeftButton" then
        self:StartMoving ()
        self.moving = true
      end
    end)
    self.methodWindow:SetScript ("OnMouseUp", function (self)
      if self.moving then
        self:StopMovingOrSizing ()
        self.moving = false
        EUIReforge.db.methodWindowX = self:GetLeft ()
        EUIReforge.db.methodWindowY = self:GetTop ()
      end
    end)

    self.methodWindow.itemTable = GUI:CreateTable (#self.itemSlots, 3, 0, 0, nil, self.methodWindow)
    self.methodWindow.itemTable:SetPoint ("TOPLEFT", self.methodWindow, "TOPLEFT", 14, -(GUI.HEADER_H + 14))
    self.methodWindow.itemTable:SetRowHeight (26)
    self.methodWindow.itemTable:SetColumnWidth (1, self.db.itemSize)
    self.methodWindow.itemTable:SetColumnWidth (2, self.db.itemSize + 6)
    self.methodWindow.itemTable:SetColumnWidth (3, 292 - self.db.itemSize * 2 - 6)

    self.methodOverride = {}
    for i = 1, #self.itemSlots do
      self.methodOverride[i] = 0
    end

    self.methodWindow.items = {}
    for i, v in ipairs (self.itemSlots) do
      self.methodWindow.items[i] = CreateFrame ("Frame", nil, self.methodWindow.itemTable)
      self.methodWindow.items[i].slot = v
      self.methodWindow.items[i]:ClearAllPoints ()
      self.methodWindow.items[i]:SetWidth (self.db.itemSize - 2)
      self.methodWindow.items[i]:SetHeight (self.db.itemSize - 2)
      self.methodWindow.itemTable:SetCell (i, 2, self.methodWindow.items[i])
      self.methodWindow.items[i]:EnableMouse (true)
      StyleItemIcon (self.methodWindow.items[i])
      self.methodWindow.items[i]:SetScript ("OnEnter", function (self)
        self.glow:Show ()
        GameTooltip:SetOwner (self, "ANCHOR_LEFT")
        if self.item then
          GameTooltip:SetHyperlink (self.item)
        else
          local text = _G[strupper (self.slot)]
          if self.checkRelic then
            text = _G["RELICSLOT"]
          end
          GameTooltip:SetText (text)
        end
        GameTooltip:Show ()
      end)
      self.methodWindow.items[i]:SetScript ("OnLeave", function (self)
        self.glow:Hide ()
        GameTooltip:Hide ()
      end)
      self.methodWindow.items[i].slotId, self.methodWindow.items[i].slotTexture, self.methodWindow.items[i].checkRelic = GetInventorySlotInfo (v)
      self.methodWindow.items[i].checkRelic = self.methodWindow.items[i].checkRelic and UnitHasRelicSlot ("player")
      if self.methodWindow.items[i].checkRelic then
        self.methodWindow.items[i].slotTexture = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Relic.blp"
      end
      self.methodWindow.items[i].texture:SetTexture (self.methodWindow.items[i].slotTexture)

      self.methodWindow.items[i].reforge = self.methodWindow.itemTable:CreateFontString (nil, "OVERLAY", "EUIReforgeFont")
      self.methodWindow.itemTable:SetCell (i, 3, self.methodWindow.items[i].reforge, "LEFT")
      self.methodWindow.items[i].reforge:SetTextColor (1, 1, 1, 0.85)
      self.methodWindow.items[i].reforge:SetText ("")

      self.methodWindow.items[i].check = GUI:CreateCheckButton (self.methodWindow.itemTable, "", false,
        function (val) self.methodOverride[i] = (val and 1 or -1) self:UpdateMethodChecks () end)
      self.methodWindow.itemTable:SetCell (i, 1, self.methodWindow.items[i].check)
    end
    self.methodWindow.reforge = GUI:CreateButton (self.methodWindow, 120, 28, L["Reforge"], true)
    self.methodWindow.reforge:SetPoint ("BOTTOMLEFT", self.methodWindow, "BOTTOMLEFT", 14, 14)
    self.methodWindow.reforge:SetScript ("OnClick", function ()
      EUIReforge:DoReforge ()
    end)
    self.methodWindow.reforgeTip = CreateFrame ("Frame", nil, self.methodWindow)
    self.methodWindow.reforgeTip:SetAllPoints (self.methodWindow.reforge)
    self.methodWindow.reforgeTip:EnableMouse (true)
    GUI:SetTooltip (self.methodWindow.reforgeTip, L["Reforging window must be open"])
    self.methodWindow.reforgeTip:SetFrameLevel (self.methodWindow.reforge:GetFrameLevel () + 5)
    self.methodWindow.reforgeTip:Hide ()

    self.methodWindow.costTip = GUI:Text (self.methodWindow, "EUIReforgeFont", 0.5)
    self.methodWindow.costTip:SetPoint ("LEFT", self.methodWindow.reforge, "RIGHT", 12, 0)
    self.methodWindow.costTip:SetText (L["Cost"] .. ":")
    self.methodWindow.cost = GUI:Text (self.methodWindow, "EUIReforgeFont", 0.9)
    self.methodWindow.cost:SetPoint ("LEFT", self.methodWindow.costTip, "RIGHT", 6, 0)
  end

  for i = 1, #self.itemSlots do
    self.methodOverride[i] = 0
  end

  for i, v in ipairs (self.methodWindow.items) do
    local item = GetInventoryItemLink ("player", v.slotId)
    local texture = GetInventoryItemTexture ("player", v.slotId)
    if texture then
      v.item = item
      v.texture:SetTexture (texture)
    else
      v.item = nil
      v.texture:SetTexture (v.slotTexture)
    end
    if self.pdb.method.items[i].reforge then
      v.reforge:SetText (string.format ("%d %s > %s", self.pdb.method.items[i].amount,
        self.itemStats[self.pdb.method.items[i].src].long, self.itemStats[self.pdb.method.items[i].dst].long))
      v.reforge:SetTextColor (1, 1, 1, 0.85)
    else
      v.reforge:SetText (L["No reforge"])
      v.reforge:SetTextColor (1, 1, 1, 0.3)
    end
  end
  self:UpdateMethodChecks ()
  self.methodWindow:Show ()
  self.methodWindow:Raise ()
end
function EUIReforge:IsReforgeMatching (item, reforge, override)
  if override == 1 then
    return true
  end

  local oreforge = self:GetReforgeID (item)

  if override == -1 then
    return reforge == oreforge
  end

  local stats = EUIReforge_GetItemStatsUp(item, self.pdb.ilvlCap)

  local deltas = {}
  for i = 1, #self.itemStats do
    deltas[i] = 0
  end

  if oreforge then
    local osrc = self.reforgeTable[oreforge][1]
    local odst = self.reforgeTable[oreforge][2]
    local oamount = math.floor ((stats[self.itemStats[osrc].name] or 0) * REFORGE_COEFF)
    deltas[osrc] = deltas[osrc] + oamount
    deltas[odst] = deltas[odst] - oamount
  end

  if reforge then
    local src = self.reforgeTable[reforge][1]
    local dst = self.reforgeTable[reforge][2]
    local amount = math.floor ((stats[self.itemStats[src].name] or 0) * REFORGE_COEFF)
    deltas[src] = deltas[src] - amount
    deltas[dst] = deltas[dst] + amount
  end

  local conv = self:GetConversion()
  local mult = self:GetStatMultipliers()
  for i = 1, #self.itemStats do
    deltas[i] = math.floor(deltas[i] * (mult[i] or 1) + 0.5)
  end
  for src, c in pairs(conv) do
    for dst, factor in pairs(c) do
      deltas[dst] = deltas[dst] + math.floor(deltas[src] * factor + 0.5)
    end
  end

  for i = 1, #self.itemStats do
    if self:GetStatScore (i, self.pdb.method.stats[i]) ~= self:GetStatScore (i, self.pdb.method.stats[i] - deltas[i]) then
      return false
    end
  end
  return true
end
function EUIReforge:UpdateMethodChecks ()
  if self.methodWindow and self.pdb.method then
    local cost = 0
    local anyDiffer = false
    for i, v in ipairs (self.methodWindow.items) do
      local item = GetInventoryItemLink ("player", v.slotId)
      v.item = item
      local texture = GetInventoryItemTexture ("player", v.slotId)
      v.texture:SetTexture (texture or v.slotTexture)
      if item == nil or self:IsReforgeMatching (item, self.pdb.method.items[i].reforge, self.methodOverride[i]) then
        v.check:SetChecked (true)
      else
        if item then
          anyDiffer = true
        end
        v.check:SetChecked (false)
        if self.pdb.method.items[i].reforge then
          cost = cost + (item and select (11, GetItemInfo (item)) or 0)
        end
      end
    end
    if anyDiffer then
      if ReforgingFrame and ReforgingFrame:IsShown () and self:IsMethodValid(self.pdb.method) then
        self.methodWindow.reforge:Enable ()
        self.methodWindow.reforgeTip:Hide ()
      else
        self.methodWindow.reforge:Disable ()
        self.methodWindow.reforgeTip:Show ()
        if self:IsMethodValid(self.pdb.method) then
          GUI:SetTooltip (self.methodWindow.reforgeTip, L["Reforging window must be open"])
        else
          GUI:SetTooltip (self.methodWindow.reforgeTip, L["Please press Compute button to update the reforge."])
        end
      end
      self.methodWindow.costTip:Show ()
      self.methodWindow.cost:Show ()
    else
      self.methodWindow.reforge:Disable ()
      self.methodWindow.reforgeTip:Hide ()
      self.methodWindow.costTip:Hide ()
      self.methodWindow.cost:Hide ()
    end
    self.methodWindow.cost:SetText (GetCoinTextureString (cost))
  end
end

--------------------------------------------------------------------------

function EUIReforge:DoReforgeUpdate ()
  if self.curReforgeItem and self.pdb.method and self.methodWindow.reforge:IsShown () and ReforgingFrame and ReforgingFrame:IsShown () and self:IsMethodValid(self.pdb.method) then
    while self.curReforgeItem <= #self.methodWindow.items do
      local i = self.curReforgeItem
      if i ~= 0 then
        local slot = self.methodWindow.items[i].slotId
        local item = GetInventoryItemLink ("player", slot)
        if item and not self:IsReforgeMatching (item, self.pdb.method.items[i].reforge, self.methodOverride[i]) then
          if self.reforgingNow ~= i then
            PickupInventoryItem (slot)
            SetReforgeFromCursorItem ()
            self.reforgingNow = i
          end
          if self:GetReforgeID (item) then
            ReforgeItem (0)
          elseif self.pdb.method.items[i].reforge then
            local id = 0
            local stats = EUIReforge_GetItemStatsUp(item, self.pdb.ilvlCap)
            for s = 1, #self.reforgeTable do
              if (stats[self.itemStats[self.reforgeTable[s][1]].name] or 0) ~= 0 and (stats[self.itemStats[self.reforgeTable[s][2]].name] or 0) == 0 then
                id = id + 1
              end
              if self.reforgeTable[s][1] == self.pdb.method.items[i].src and self.reforgeTable[s][2] == self.pdb.method.items[i].dst then
                ReforgeItem (id)
                return
              end
            end
            self.curReforgeItem = nil
            self.methodWindow.reforge:SetScript ("OnUpdate", nil)
            self.methodWindow.reforge:SetText (L["Reforge"])
          end
          return
        end
      end
      self.curReforgeItem = i + 1
    end
  end
  self.curReforgeItem = nil
  self.methodWindow.reforge:SetScript ("OnUpdate", nil)
  self.methodWindow.reforge:SetText (L["Reforge"])
end
function EUIReforge:DoReforge ()
  if self.pdb.method and self.methodWindow and ReforgingFrame and ReforgingFrame:IsShown () then
    if self.curReforgeItem then
      self.curReforgeItem = nil
      ClearCursor ()
      SetReforgeFromCursorItem ()
      ClearCursor ()
      self.reforgingNow = nil
      self.methodWindow.reforge:SetScript ("OnUpdate", nil)
      self.methodWindow.reforge:SetText (L["Reforge"])
    else
      self.curReforgeItem = 0
      self.methodWindow.reforge:SetScript ("OnUpdate", function (self) EUIReforge:DoReforgeUpdate () end)
      self.methodWindow.reforge:SetText (L["Cancel"])
    end
  end
end

--------------------------------------------------------------------------
--[=[ OBSOLETE
function EUIReforge.OnTooltipSetItem (tip)
  if not EUIReforge.db.updateTooltip then return end
  local _, item = tip:GetItem ()
  if item and GetItemInfo (item) then
    local reforge = EUIReforge:GetReforgeID (item)
    if reforge then
      local regions = {tip:GetRegions ()}
      for _, region in pairs (regions) do
        if region:GetObjectType () == "FontString" then
          if region:GetText () == REFORGED then
            local src = EUIReforge.itemStats[EUIReforge.reforgeTable[reforge][1]].long
            local dst = EUIReforge.itemStats[EUIReforge.reforgeTable[reforge][2]].long
            region:SetText (string.format ("%s (%s > %s)", REFORGED, src, dst))
          end
        end
      end
    end
  end
end
function EUIReforge:SetUpHooks ()
  GameTooltip:HookScript ("OnTooltipSetItem", self.OnTooltipSetItem)
  ItemRefTooltip:HookScript ("OnTooltipSetItem", self.OnTooltipSetItem)
  hooksecurefunc (ShoppingTooltip1, "SetHyperlinkCompareItem", self.OnTooltipSetItem)
  hooksecurefunc (ShoppingTooltip2, "SetHyperlinkCompareItem", self.OnTooltipSetItem)
  hooksecurefunc (ShoppingTooltip3, "SetHyperlinkCompareItem", self.OnTooltipSetItem)
  hooksecurefunc (ItemRefShoppingTooltip1, "SetHyperlinkCompareItem", self.OnTooltipSetItem)
  hooksecurefunc (ItemRefShoppingTooltip2, "SetHyperlinkCompareItem", self.OnTooltipSetItem)
  hooksecurefunc (ItemRefShoppingTooltip3, "SetHyperlinkCompareItem", self.OnTooltipSetItem)
end
]=]
--------------------------------------------------------------------------

function EUIReforge:OnEvent (event, ...)
  if self[event] then
    self[event] (self, ...)
  end
  if event == "UNIT_STATS" or event == "COMBAT_RATING_UPDATE" or event == "MASTERY_UPDATE" or event == "PLAYER_EQUIPMENT_CHANGED" then
    self:QueueUpdate ()
  end
  if event == "FORGE_MASTER_OPENED" and self.db.openOnReforge and (self.methodWindow == nil or not self.methodWindow:IsShown ()) then
    if not self.initialized then
      self:CreateFrame()
    end
    self:UpdateItems ()
    self:Show ()
  end
  if event == "FORGE_MASTER_CLOSED" and self.db.openOnReforge then
    self:Hide ()
    if self.methodWindow then
      self.methodWindow:Hide ()
    end
  end
  if event == "FORGE_MASTER_OPENED" or event == "FORGE_MASTER_CLOSED" then
    self:QueueUpdate ()
  end
end
--[[
local EUIReforgeTimer = CreateFrame ("Frame")
function EUIReforgeTimer:OnUpdate (epsilon)
  self.elapsed = (self.elapsed or 0) + epsilon
  if self.elapsed > 3 then
    self:SetScript ("OnUpdate", nil)
    self:Hide ()
--    ReforgeLite:SetUpHooks ()
  end
end
]]
function EUIReforge:ADDON_LOADED (addon)
  if addon == addonName then
    self:UnregisterEvent ("ADDON_LOADED")
    self:UpgradeDB ()
    self.db = EllesmereUIReforgeDB
    self.pdb = EllesmereUIReforgeDB.profiles[self.dbkey]

    self:InitPresets ()
    GUI:ApplyFonts ()

    self:RegisterEvent ("UNIT_STATS")
    self:RegisterEvent ("COMBAT_RATING_UPDATE")
    self:RegisterEvent ("MASTERY_UPDATE")
    self:RegisterEvent ("PLAYER_EQUIPMENT_CHANGED")
    self:RegisterEvent ("FORGE_MASTER_OPENED")
    self:RegisterEvent ("FORGE_MASTER_CLOSED")

    SlashCmdList["EUIREFORGE"] = function (cmd) EUIReforge:OnCommand (cmd) end
    SLASH_EUIREFORGE1 = "/reforge"
  end
end

EUIReforge:SetScript ("OnEvent", EUIReforge.OnEvent)
EUIReforge:RegisterEvent ("ADDON_LOADED")

function EUIReforge:OnCommand (cmd)
  if self:IsShown () then
    self:Hide ()
    return
  end
  if not self.initialized then
    self:CreateFrame()
  end
  self:UpdateItems ()
  self:Show ()
end

---------------------------------------------------------------------------
-- EllesmereUI hooks (settings page: EllesmereUIOptions\EUI_Reforge_Options.lua)
---------------------------------------------------------------------------
function ns.GetReforgeDB ()
  return EUIReforge.db or EllesmereUIReforgeDB or {}
end

function ns.ToggleReforgeWindow ()
  EUIReforge:OnCommand ("")
end

function ns.ShowReforgeDebug ()
  EUIReforge:DebugMethod ()
end

function ns.ResetReforgeWindow ()
  local db = EUIReforge.db
  if not db then
    return
  end
  db.windowX, db.windowY, db.methodWindowX, db.methodWindowY = nil, nil, nil, nil
  db.windowWidth, db.windowHeight = DefaultDB.windowWidth, DefaultDB.windowHeight
  if EUIReforge.initialized then
    EUIReforge:ClearAllPoints ()
    EUIReforge:SetPoint ("CENTER")
    EUIReforge:SetSize (db.windowWidth, db.windowHeight)
  end
  if EUIReforge.methodWindow then
    EUIReforge.methodWindow:ClearAllPoints ()
    EUIReforge.methodWindow:SetPoint ("CENTER")
  end
end

function ns.ResetReforgeSettings ()
  local db = EUIReforge.db
  if not db then
    return
  end
  db.openOnReforge = DefaultDB.openOnReforge
  ns.ResetReforgeWindow ()
end

-- Global Settings > Fonts changed: new font on the Reforge windows.
ns.applyHooks = ns.applyHooks or {}
tinsert (ns.applyHooks, function ()
  GUI:ApplyFonts ()
end)