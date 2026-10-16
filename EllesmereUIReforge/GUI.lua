-- Part of ReforgeLite by d07.RiV (Iroared)
-- All rights reserved
--
-- EllesmereUIReforge: the ReforgeLite widgets rebuilt in the EllesmereUI style
-- (flat dark boxes, 1 pixel borders, accent color, EllesmereUI font and
-- icons), with the 5.4.8 API only (solid color textures, no backdrops).
-- Same functions as the ReforgeLite GUI, plus windows, flat buttons, icon
-- buttons, a menu with sub menus, a scroll bar, a tooltip and popups.

local ns = EllesmereUI
local floor, min, max = math.floor, math.min, math.max

local GUI = {}

local MEDIA = ns.MEDIA .. "ui\\"
local FONT_KEY = "reforge"

---------------------------------------------------------------------------
-- Style
---------------------------------------------------------------------------
-- UI accent color (Global Settings > General). Changed in place when the
-- accent changes, so code that reads it when it paints follows it.
local ACCENT = { 12 / 255, 210 / 255, 157 / 255 }
if ns.ResolveAccent then
  ACCENT[1], ACCENT[2], ACCENT[3] = ns.ResolveAccent()
end
GUI.ACCENT = ACCENT

local WINDOW_BG = { 0.02, 0.02, 0.02, 0.95 }
local PANEL_BG = { 0.069, 0.058, 0.047 }
local DROPDOWN_BG = { 0.103, 0.095, 0.088 }
local BOX_BG = { 0.030, 0.023, 0.018 }
GUI.GRID_COLOR = { 1, 1, 1, 0.06 }

local function Solid (parent, layer, r, g, b, a)
  local tex = parent:CreateTexture (nil, layer or "BACKGROUND")
  tex:SetTexture (r, g, b, a)
  return tex
end
GUI.Solid = Solid

-- 1 pixel border made of 4 textures.
local function AddBorder (frame, r, g, b, a, layer)
  local border = {}
  local function Edge ()
    local tex = frame:CreateTexture (nil, layer or "BORDER")
    tex:SetTexture (r, g, b, a)
    border[#border + 1] = tex
    return tex
  end
  local top = Edge ()
  top:SetPoint ("TOPLEFT")
  top:SetPoint ("TOPRIGHT")
  top:SetHeight (1)
  local bottom = Edge ()
  bottom:SetPoint ("BOTTOMLEFT")
  bottom:SetPoint ("BOTTOMRIGHT")
  bottom:SetHeight (1)
  local left = Edge ()
  left:SetPoint ("TOPLEFT", 0, -1)
  left:SetPoint ("BOTTOMLEFT", 0, 1)
  left:SetWidth (1)
  local right = Edge ()
  right:SetPoint ("TOPRIGHT", 0, -1)
  right:SetPoint ("BOTTOMRIGHT", 0, 1)
  right:SetWidth (1)
  function border:SetColor (nr, ng, nb, na)
    for i = 1, #self do
      self[i]:SetTexture (nr, ng, nb, na)
    end
  end
  return border
end
GUI.AddBorder = AddBorder

-- Accent colored parts, painted again when the accent changes.
local accentParts = {}
local function AccentSolid (parent, layer, a)
  local tex = Solid (parent, layer, ACCENT[1], ACCENT[2], ACCENT[3], a)
  accentParts[#accentParts + 1] = {tex = tex, a = a}
  return tex
end
GUI.AccentSolid = AccentSolid

-- fn () is called again when the accent changes.
function GUI:OnAccent (fn)
  accentParts[#accentParts + 1] = {fn = fn}
end

if ns.accentListeners then
  tinsert (ns.accentListeners, function (r, g, b)
    ACCENT[1], ACCENT[2], ACCENT[3] = r, g, b
    for i = 1, #accentParts do
      local part = accentParts[i]
      if part.tex then
        part.tex:SetTexture (r, g, b, part.a)
      elseif part.fn then
        part.fn ()
      end
    end
  end)
end

---------------------------------------------------------------------------
-- Fonts (Global Settings > Fonts, module "Reforge")
---------------------------------------------------------------------------
local fonts = {}
local function MakeFont (name, size)
  local font = CreateFont (name)
  fonts[#fonts + 1] = {obj = font, size = size}
  return font
end
MakeFont ("EUIReforgeFontSmall", 11)
MakeFont ("EUIReforgeFont", 12)
MakeFont ("EUIReforgeFontLarge", 14)

function GUI:ApplyFonts ()
  local path = (ns.GetFontPath and ns.GetFontPath (FONT_KEY)) or ns.FONT
  local flag = (ns.GetFontOutlineFlag and ns.GetFontOutlineFlag (FONT_KEY)) or ""
  for _, f in ipairs (fonts) do
    f.obj:SetFont (path, f.size, flag)
    if not f.obj:GetFont () then
      f.obj:SetFont ("Fonts\\ARIALN.TTF", f.size, flag)
    end
    if flag == "" then
      f.obj:SetShadowOffset (1, -1)
      f.obj:SetShadowColor (0, 0, 0, 1)
    else
      f.obj:SetShadowOffset (0, 0)
    end
    f.obj:SetTextColor (1, 1, 1)
  end
end
GUI:ApplyFonts ()

-- Old font object names of ReforgeLite -> the EllesmereUI ones.
local FONT_MAP = {
  GameFontNormalSmall = "EUIReforgeFontSmall",
  GameFontHighlightSmall = "EUIReforgeFontSmall",
  GameFontNormal = "EUIReforgeFont",
  GameFontHighlight = "EUIReforgeFont",
  GameFontNormalLarge = "EUIReforgeFontLarge",
}
local function FontObject (font)
  return FONT_MAP[font] or font or "EUIReforgeFont"
end

function GUI:Text (parent, font, alpha, layer)
  local fs = parent:CreateFontString (nil, layer or "OVERLAY", FontObject (font))
  fs:SetTextColor (1, 1, 1, alpha or 1)
  return fs
end

---------------------------------------------------------------------------

GUI.widgetCount = 0
function GUI:GenerateWidgetName ()
  self.widgetCount = self.widgetCount + 1
  return "EUIReforgeWidget" .. self.widgetCount
end
GUI.defaultParent = nil

---------------------------------------------------------------------------
-- Tooltip (EllesmereUI widget tooltip)
---------------------------------------------------------------------------
local tip
local function ShowTip (owner, text)
  if not text or text == "" then
    return
  end
  if not tip then
    tip = CreateFrame ("Frame", nil, UIParent)
    tip:SetFrameStrata ("TOOLTIP")
    Solid (tip, "BACKGROUND", 0.067, 0.067, 0.067, 0.94):SetAllPoints ()
    AddBorder (tip, 1, 1, 1, 0.15)
    tip.text = GUI:Text (tip, "EUIReforgeFont", 0.85)
    tip.text:SetPoint ("TOPLEFT", 9, -8)
    tip.text:SetJustifyH ("LEFT")
    tip.text:SetSpacing (3)
  end
  tip.text:SetWidth (0)
  tip.text:SetText (text)
  local width = min (250, tip.text:GetStringWidth () + 2)
  tip.text:SetWidth (width)
  tip:SetSize (width + 18, tip.text:GetStringHeight () + 16)
  tip:ClearAllPoints ()
  tip:SetPoint ("BOTTOMLEFT", owner, "TOPLEFT", 10, 4)
  tip:Show ()
end
local function HideTip ()
  if tip then
    tip:Hide ()
  end
end
GUI.ShowTip = ShowTip
GUI.HideTip = HideTip

-- Widgets of this file read widget.tooltip in their own OnEnter; other
-- frames get OnEnter / OnLeave scripts.
function GUI:SetTooltip (widget, text)
  if widget.euiWidget then
    widget.tooltip = text
  elseif text then
    widget:SetScript ("OnEnter", function (self) ShowTip (self, text) end)
    widget:SetScript ("OnLeave", HideTip)
  else
    widget:SetScript ("OnEnter", nil)
    widget:SetScript ("OnLeave", nil)
  end
end

---------------------------------------------------------------------------
-- Flat button (EllesmereUI footer button). accent = accent colored.
---------------------------------------------------------------------------
local function ButtonVisual (self)
  local hover = self.isHover
  if not self:IsEnabled () then
    self.border:SetColor (1, 1, 1, 0.12)
    self.label:SetTextColor (1, 1, 1, 0.25)
  elseif self.accent then
    local alpha = hover and 1 or 0.75
    self.border:SetColor (ACCENT[1], ACCENT[2], ACCENT[3], alpha)
    self.label:SetTextColor (ACCENT[1], ACCENT[2], ACCENT[3], alpha)
  else
    self.border:SetColor (1, 1, 1, hover and 0.6 or 0.35)
    self.label:SetTextColor (1, 1, 1, hover and 0.85 or 0.6)
  end
end

function GUI:CreateButton (parent, width, height, text, accent)
  local button = CreateFrame ("Button", nil, parent)
  button.euiWidget = true
  button:SetSize (width or 114, height or 24)
  button.bg = Solid (button, "BACKGROUND", PANEL_BG[1], PANEL_BG[2], PANEL_BG[3], 0.92)
  button.bg:SetAllPoints ()
  button.hoverTex = Solid (button, "BORDER", 1, 1, 1, 0.04)
  button.hoverTex:SetAllPoints ()
  button.hoverTex:Hide ()
  button.border = AddBorder (button, 1, 1, 1, 0.35, "ARTWORK")
  button.label = GUI:Text (button, "EUIReforgeFont")
  button.label:SetPoint ("LEFT", 6, 0)
  button.label:SetPoint ("RIGHT", -6, 0)
  button.label:SetJustifyH ("CENTER")
  button.label:SetWordWrap (false)
  button.accent = accent

  button.SetText = function (self, value) self.label:SetText (value) end
  button.GetText = function (self) return self.label:GetText () end
  button.SetVisual = ButtonVisual
  local enable, disable = button.Enable, button.Disable
  button.Enable = function (self) enable (self) self:SetVisual () end
  button.Disable = function (self) disable (self) self:SetVisual () end

  button:SetScript ("OnEnter", function (self)
    self.isHover = true
    if self:IsEnabled () then
      self.hoverTex:Show ()
    end
    self:SetVisual ()
    ShowTip (self, self.tooltip)
  end)
  button:SetScript ("OnLeave", function (self)
    self.isHover = false
    self.hoverTex:Hide ()
    self:SetVisual ()
    HideTip ()
  end)
  GUI:OnAccent (function () button:SetVisual () end)
  button:SetText (text or "")
  button:SetVisual ()
  return button
end

-- Flat button with a down arrow, opens a menu.
function GUI:CreateMenuButton (parent, width, height, text)
  local button = self:CreateButton (parent, width, height, text)
  button.label:ClearAllPoints ()
  button.label:SetPoint ("LEFT", 8, 0)
  button.label:SetPoint ("RIGHT", -20, 0)
  button.arrow = button:CreateTexture (nil, "OVERLAY")
  button.arrow:SetTexture (MEDIA .. "eui-arrow")
  button.arrow:SetTexCoord (0, 30 / 32, 0, 30 / 32)
  button.arrow:SetSize (18, 18)
  button.arrow:SetPoint ("CENTER", button, "RIGHT", -11, 0)
  local visual = button.SetVisual
  button.SetVisual = function (self)
    visual (self)
    self.arrow:SetVertexColor (1, 1, 1, (not self:IsEnabled ()) and 0.2 or (self.isHover and 0.9 or 0.55))
  end
  button:SetVisual ()
  return button
end

---------------------------------------------------------------------------
-- Icon buttons: "close" (remove), "up", "down", "plus", "arrow" (menu)
---------------------------------------------------------------------------
local ARROW_CUT = 30 / 32 -- eui-arrow is 30 x 30 in a 32 x 32 TGA (points down)
local ICONS = {
  close = {file = MEDIA .. "eui-close", coords = {0, 1, 0, 1}, scale = 0.5},
  down = {file = MEDIA .. "eui-arrow", coords = {0, ARROW_CUT, 0, ARROW_CUT}, scale = 1},
  up = {file = MEDIA .. "eui-arrow", coords = {0, ARROW_CUT, ARROW_CUT, 0}, scale = 1},
  right = {file = MEDIA .. "eui-arrow-right", coords = {0, ARROW_CUT, 0, ARROW_CUT}, scale = 1},
}

GUI.imgButtons = {}
function GUI:CreateIconButton (parent, size, icon, handler)
  local btn
  if #self.imgButtons > 0 then
    btn = table.remove (self.imgButtons, 1)
    btn:SetParent (parent)
    btn:Show ()
  else
    btn = CreateFrame ("Button", nil, parent)
    btn.euiWidget = true
    btn.icon = btn:CreateTexture (nil, "ARTWORK")
    btn.icon:SetPoint ("CENTER")
    -- "plus": two bars
    btn.plusH = Solid (btn, "ARTWORK", 1, 1, 1, 1)
    btn.plusH:SetPoint ("CENTER")
    btn.plusV = Solid (btn, "ARTWORK", 1, 1, 1, 1)
    btn.plusV:SetPoint ("CENTER")
    btn.SetIconAlpha = function (self, alpha)
      self.icon:SetVertexColor (1, 1, 1, alpha)
      self.plusH:SetTexture (ACCENT[1], ACCENT[2], ACCENT[3], alpha)
      self.plusV:SetTexture (ACCENT[1], ACCENT[2], ACCENT[3], alpha)
    end
    btn:SetScript ("OnEnter", function (self)
      self:SetIconAlpha (0.95)
      ShowTip (self, self.tooltip)
    end)
    btn:SetScript ("OnLeave", function (self)
      self:SetIconAlpha (0.55)
      HideTip ()
    end)
    btn.Recycle = function (btn)
      btn:Hide ()
      btn.tooltip = nil
      btn:SetScript ("OnClick", nil)
      table.insert (self.imgButtons, btn)
    end
  end
  btn:SetSize (size, size)
  local def = ICONS[icon]
  if def then
    btn.icon:SetTexture (def.file)
    btn.icon:SetTexCoord (unpack (def.coords))
    btn.icon:SetSize (size * def.scale, size * def.scale)
    btn.icon:Show ()
    btn.plusH:Hide ()
    btn.plusV:Hide ()
  else
    local bar = max (8, floor (size * 0.5))
    btn.icon:Hide ()
    btn.plusH:SetSize (bar, 2)
    btn.plusV:SetSize (2, bar)
    btn.plusH:Show ()
    btn.plusV:Show ()
  end
  btn:SetIconAlpha (0.55)
  if handler then
    btn:SetScript ("OnClick", handler)
  end
  return btn
end

-- ReforgeLite name, kept for the callers: the icon is picked from the old path.
function GUI:CreateImageButton (parent, width, height, img, pus, hlt, handler)
  local icon = "close"
  if img and img:find ("ScrollUp") then
    icon = "up"
  elseif img and img:find ("ScrollDown") then
    icon = "down"
  elseif img and img:find ("PlusButton") then
    icon = "plus"
  end
  return self:CreateIconButton (parent, width, icon, handler)
end

---------------------------------------------------------------------------
-- Edit box (numbers)
---------------------------------------------------------------------------
GUI.editBoxes = {}
function GUI:CreateEditBox (parent, width, height, default, setter)
  local box
  if #self.editBoxes > 0 then
    box = table.remove (self.editBoxes, 1)
    box:SetParent (parent)
    box:Show ()
    box:SetTextColor (1, 1, 1)
    box:EnableMouse (true)
  else
    box = CreateFrame ("EditBox", self:GenerateWidgetName (), parent)
    box.euiWidget = true
    box:SetAutoFocus (false)
    box:SetFontObject (EUIReforgeFont)
    box:SetJustifyH ("CENTER")
    box:SetTextInsets (4, 4, 0, 0)
    box:SetMaxLetters (8)
    Solid (box, "BACKGROUND", BOX_BG[1], BOX_BG[2], BOX_BG[3], 0.6):SetAllPoints ()
    box.border = AddBorder (box, 1, 1, 1, 0.12)
    box.SetVisual = function (self)
      if self:HasFocus () then
        self.border:SetColor (ACCENT[1], ACCENT[2], ACCENT[3], 0.8)
      elseif self.isHover then
        self.border:SetColor (1, 1, 1, 0.3)
      else
        self.border:SetColor (1, 1, 1, 0.12)
      end
    end
    box:SetScript ("OnEnterPressed", function (box)
      box:ClearFocus ()
    end)
    box:SetScript ("OnEscapePressed", function (box)
      box:ClearFocus ()
    end)
    box:SetScript ("OnEditFocusGained", function (box)
      box:HighlightText ()
      box:SetVisual ()
    end)
    box:SetScript ("OnEnter", function (self)
      self.isHover = true
      self:SetVisual ()
      ShowTip (self, self.tooltip)
    end)
    box:SetScript ("OnLeave", function (self)
      self.isHover = false
      self:SetVisual ()
      HideTip ()
    end)
    box.Recycle = function (box)
      box:Hide ()
      box:SetScript ("OnEditFocusLost", nil)
      box.tooltip = nil
      table.insert (self.editBoxes, box)
    end
  end
  box:SetWidth (width or 40)
  box:SetHeight (min (height or 22, 22))
  box:SetText (default)
  box:SetScript ("OnEditFocusLost", function (box)
    local value = tonumber (box:GetText ()) or 0
    box:SetText (value)
    box:HighlightText (0, 0)
    box:SetVisual ()
    if setter then
      setter (value)
    end
  end)
  box:SetVisual ()
  return box
end

---------------------------------------------------------------------------
-- Menu with sub menus (EllesmereUI dropdown menu). items: list of
-- {text, func, checked, children (list or function), disabled, tip, keepOpen}
---------------------------------------------------------------------------
local MENU_ITEM_H = 22
local MENU_MAX_ITEMS = 18
local menuLevels = {}
local menuCatcher

function GUI:CloseMenu (fromLevel)
  fromLevel = fromLevel or 1
  for i = fromLevel, #menuLevels do
    menuLevels[i]:Hide ()
    menuLevels[i].anchor = nil
  end
  if fromLevel <= 1 and menuCatcher then
    menuCatcher:Hide ()
  end
end

function GUI:IsMenuOpenFor (anchor)
  return menuLevels[1] and menuLevels[1]:IsShown () and menuLevels[1].anchor == anchor
end

local UpdateMenu

local function MenuButton (menu, index)
  local button = CreateFrame ("Button", nil, menu)
  button:SetHeight (MENU_ITEM_H)
  button.hover = Solid (button, "ARTWORK", 1, 1, 1, 0.08)
  button.hover:SetAllPoints ()
  button.hover:Hide ()
  button.mark = AccentSolid (button, "ARTWORK", 1)
  button.mark:SetPoint ("TOPLEFT")
  button.mark:SetPoint ("BOTTOMLEFT")
  button.mark:SetWidth (2)
  button.text = GUI:Text (button, "EUIReforgeFont", 0.6)
  button.text:SetPoint ("LEFT", 10, 0)
  button.text:SetJustifyH ("LEFT")
  button.text:SetWordWrap (false)
  button.arrow = button:CreateTexture (nil, "ARTWORK")
  button.arrow:SetTexture (ICONS.right.file)
  button.arrow:SetTexCoord (unpack (ICONS.right.coords))
  button.arrow:SetSize (18, 18)
  button.arrow:SetPoint ("RIGHT", -4, 0)
  button.arrow:SetVertexColor (1, 1, 1, 0.5)

  button:SetScript ("OnEnter", function (self)
    local item = self.item
    if not item then
      return
    end
    if not item.disabled then
      self.hover:Show ()
      self.text:SetTextColor (1, 1, 1, 1)
    end
    if item.children and not item.disabled then
      GUI:OpenMenu (self, item.children, menu.level + 1)
    else
      GUI:CloseMenu (menu.level + 1)
    end
    ShowTip (self, item.tip)
  end)
  button:SetScript ("OnLeave", function (self)
    self.hover:Hide ()
    self.text:SetTextColor (1, 1, 1, self.baseAlpha or 0.6)
    HideTip ()
  end)
  button:SetScript ("OnClick", function (self)
    local item = self.item
    if not item or item.disabled then
      return
    end
    if item.children then
      GUI:OpenMenu (self, item.children, menu.level + 1)
      return
    end
    if not item.keepOpen then
      GUI:CloseMenu ()
    end
    if item.func then
      item.func ()
    end
    if item.keepOpen then
      UpdateMenu (menu)
    end
  end)
  button:EnableMouseWheel (true)
  button:SetScript ("OnMouseWheel", function (_, delta) menu:Scroll (delta) end)
  menu.buttons[index] = button
  return button
end

function UpdateMenu (menu)
  local items = menu.items
  local visible = min (#items, MENU_MAX_ITEMS)
  local width = menu.minWidth or 0
  for i = 1, visible do
    local button = menu.buttons[i] or MenuButton (menu, i)
    local item = items[i + menu.offset]
    button.item = item
    button.text:SetText (item.text or "")
    button.baseAlpha = item.disabled and 0.25 or (item.checked and 1 or 0.6)
    button.text:SetTextColor (1, 1, 1, button.baseAlpha)
    button.mark:SetShown (item.checked and true or false)
    button.arrow:SetShown (item.children and true or false)
    button:SetPoint ("TOPLEFT", menu, "TOPLEFT", 1, -1 - (i - 1) * MENU_ITEM_H)
    button:SetPoint ("TOPRIGHT", menu, "TOPRIGHT", (#items > MENU_MAX_ITEMS) and -6 or -1, -1 - (i - 1) * MENU_ITEM_H)
    button:Show ()
    width = max (width, button.text:GetStringWidth () + (item.children and 44 or 26))
  end
  for i = visible + 1, #menu.buttons do
    menu.buttons[i]:Hide ()
  end
  menu:SetSize (max (60, floor (width + 0.5)), visible * MENU_ITEM_H + 2)
  if #items > MENU_MAX_ITEMS then
    local track = visible * MENU_ITEM_H
    local size = max (16, track * visible / #items)
    local pos = (track - size) * menu.offset / (#items - visible)
    menu.thumb:SetHeight (size)
    menu.thumb:ClearAllPoints ()
    menu.thumb:SetPoint ("TOPRIGHT", menu, "TOPRIGHT", -2, -1 - pos)
    menu.thumb:Show ()
  else
    menu.thumb:Hide ()
  end
end

local function MenuLevel (level)
  if menuLevels[level] then
    return menuLevels[level]
  end
  if not menuCatcher then
    menuCatcher = CreateFrame ("Button", nil, UIParent)
    menuCatcher:SetAllPoints (UIParent)
    menuCatcher:SetFrameStrata ("FULLSCREEN_DIALOG")
    menuCatcher:SetFrameLevel (1)
    menuCatcher:RegisterForClicks ("AnyUp")
    menuCatcher:SetScript ("OnClick", function () GUI:CloseMenu () end)
    menuCatcher:Hide ()
  end
  local menu = CreateFrame ("Frame", nil, UIParent)
  menu.level = level
  menu:SetFrameStrata ("FULLSCREEN_DIALOG")
  menu:SetFrameLevel (5 + level * 5)
  menu:SetClampedToScreen (true)
  menu:EnableMouse (true)
  menu:EnableMouseWheel (true)
  Solid (menu, "BACKGROUND", DROPDOWN_BG[1], DROPDOWN_BG[2], DROPDOWN_BG[3], 0.98):SetAllPoints ()
  AddBorder (menu, 1, 1, 1, 0.2)
  menu.thumb = AccentSolid (menu, "OVERLAY", 0.5)
  menu.thumb:SetWidth (3)
  menu.buttons = {}
  menu.offset = 0
  menu.items = {}
  menu.Scroll = function (self, delta)
    local maxOffset = max (0, #self.items - MENU_MAX_ITEMS)
    self.offset = min (maxOffset, max (0, self.offset - delta * 3))
    UpdateMenu (self)
  end
  menu:SetScript ("OnMouseWheel", function (self, delta) self:Scroll (delta) end)
  menu:Hide ()
  menuLevels[level] = menu
  return menu
end

-- Opens a menu at anchor. items: list or function returning the list.
function GUI:OpenMenu (anchor, items, level)
  level = level or 1
  if type (items) == "function" then
    items = items ()
  end
  self:CloseMenu (level)
  if not items or #items == 0 then
    return
  end
  local menu = MenuLevel (level)
  menu.items = items
  menu.offset = 0
  menu.anchor = anchor
  menu.minWidth = (level == 1) and anchor:GetWidth () or 0
  UpdateMenu (menu)
  menu:ClearAllPoints ()
  if level == 1 then
    local scale = anchor:GetEffectiveScale () / UIParent:GetEffectiveScale ()
    if (anchor:GetBottom () or 0) * scale - menu:GetHeight () < 20 then
      menu:SetPoint ("BOTTOMLEFT", anchor, "TOPLEFT", 0, 2)
    else
      menu:SetPoint ("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    end
    menuCatcher:Show ()
  else
    menu:SetPoint ("TOPLEFT", anchor, "TOPRIGHT", 2, 1)
  end
  menu:Show ()
end

---------------------------------------------------------------------------
-- Dropdown (EllesmereUI dropdown). values: list of {value, name}.
---------------------------------------------------------------------------
GUI.dropdowns = {}
function GUI:CreateDropdown (parent, values, default, setter, width)
  local sel
  if #self.dropdowns > 0 then
    sel = table.remove (self.dropdowns, 1)
    sel:SetParent (parent)
    sel:Show ()
  else
    sel = CreateFrame ("Button", self:GenerateWidgetName (), parent)
    sel.euiWidget = true
    sel:SetHeight (22)
    sel.bg = Solid (sel, "BACKGROUND", DROPDOWN_BG[1], DROPDOWN_BG[2], DROPDOWN_BG[3], 0.9)
    sel.bg:SetAllPoints ()
    sel.border = AddBorder (sel, 1, 1, 1, 0.2)
    sel.text = GUI:Text (sel, "EUIReforgeFont", 0.6)
    sel.text:SetPoint ("LEFT", 8, 0)
    sel.text:SetPoint ("RIGHT", -20, 0)
    sel.text:SetJustifyH ("LEFT")
    sel.text:SetWordWrap (false)
    sel.arrow = sel:CreateTexture (nil, "ARTWORK")
    sel.arrow:SetTexture (ICONS.down.file)
    sel.arrow:SetTexCoord (unpack (ICONS.down.coords))
    sel.arrow:SetSize (20, 20)
    sel.arrow:SetPoint ("CENTER", sel, "RIGHT", -11, 0)
    sel.arrow:SetVertexColor (1, 1, 1, 0.6)
    local function SetVisual (hover)
      sel.bg:SetTexture (DROPDOWN_BG[1], DROPDOWN_BG[2], DROPDOWN_BG[3], hover and 0.98 or 0.9)
      sel.border:SetColor (1, 1, 1, hover and 0.3 or 0.2)
      sel.text:SetTextColor (1, 1, 1, hover and 0.85 or 0.6)
    end
    sel:SetScript ("OnEnter", function (self)
      SetVisual (true)
      ShowTip (self, self.tooltip)
    end)
    sel:SetScript ("OnLeave", function ()
      SetVisual (false)
      HideTip ()
    end)
    sel:SetScript ("OnClick", function (self)
      if GUI:IsMenuOpenFor (self) then
        GUI:CloseMenu ()
        return
      end
      local items = {}
      for i = 1, #self.values do
        local v = self.values[i]
        items[i] = {
          text = (v.name ~= "" and v.name) or " ",
          checked = (self.value == v.value),
          func = function ()
            self:SetValue (v.value)
            if self.setter then self.setter (v.value) end
          end,
        }
      end
      GUI:OpenMenu (self, items)
    end)
    sel.SetValue = function (self, value)
      self.value = value
      for i = 1, #self.values do
        if self.values[i].value == value then
          self.text:SetText (self.values[i].name)
          return
        end
      end
      self.text:SetText ("")
    end
    sel.SetDropWidth = function (self, w)
      self:SetWidth (max (40, w))
    end
    sel.Recycle = function (sel)
      sel:Hide ()
      sel.tooltip = nil
      sel.setter = nil
      table.insert (self.dropdowns, sel)
    end
  end
  sel.values = values
  sel.setter = setter
  sel:SetValue (default)
  sel:SetDropWidth ((width or 120) + 10)
  return sel
end

---------------------------------------------------------------------------
-- Check box (EllesmereUI style: dark box, accent square when checked)
---------------------------------------------------------------------------
GUI.checkButtons = {}
function GUI:CreateCheckButton (parent, text, default, setter)
  local btn
  if #self.checkButtons > 0 then
    btn = table.remove (self.checkButtons, 1)
    btn:SetParent (parent)
    btn:Show ()
  else
    btn = CreateFrame ("CheckButton", self:GenerateWidgetName (), parent)
    btn.euiWidget = true
    btn:SetSize (16, 16)
    Solid (btn, "BACKGROUND", 0.114, 0.106, 0.099, 1):SetAllPoints ()
    btn.border = AddBorder (btn, 1, 1, 1, 0.15)
    btn.check = AccentSolid (btn, "ARTWORK", 1)
    btn.check:SetPoint ("TOPLEFT", 3, -3)
    btn.check:SetPoint ("BOTTOMRIGHT", -3, 3)
    btn.text = GUI:Text (btn, "EUIReforgeFont", 0.85)
    btn.text:SetPoint ("LEFT", btn, "RIGHT", 6, 0)
    local setChecked = btn.SetChecked
    btn.SetChecked = function (self, value)
      setChecked (self, value and true or false)
      self.check:SetShown (value and true or false)
    end
    btn:SetScript ("PostClick", function (self)
      self.check:SetShown (self:GetChecked () and true or false)
    end)
    btn:SetScript ("OnEnter", function (self)
      self.border:SetColor (1, 1, 1, 0.35)
      ShowTip (self, self.tooltip)
    end)
    btn:SetScript ("OnLeave", function (self)
      self.border:SetColor (1, 1, 1, 0.15)
      HideTip ()
    end)
    btn.Recycle = function (btn)
      btn:Hide ()
      btn.tooltip = nil
      btn:SetScript ("OnClick", nil)
      table.insert (self.checkButtons, btn)
    end
  end
  btn.text:SetText (text or "")
  -- The label is clickable too.
  local labelWidth = (text and text ~= "") and (btn.text:GetStringWidth () + 6) or 0
  btn:SetHitRectInsets (0, -labelWidth, 0, 0)
  btn:SetChecked (default)
  if setter then
    btn:SetScript ("OnClick", function (self)
      setter (self:GetChecked () and true or false)
    end)
  end
  return btn
end

-------------------------------------------------------------------------------

function GUI:CreateHLine (x1, x2, y, w, color, parent)
  parent = parent or self.defaultParent
  local line = parent:CreateTexture (nil, "ARTWORK")
  line:SetDrawLayer ("ARTWORK")
  line:SetTexture (color[1], color[2], color[3], color[4])
  if x1 > x2 then
    x1, x2 = x2, x1
  end
  line:ClearAllPoints ()
  line.width = w
  line:SetPoint ("BOTTOMLEFT", parent, "TOPLEFT", x1, y - w / 2)
  line:SetPoint ("TOPRIGHT", parent, "TOPLEFT", x2, y + w / 2)
  line:Show ()
  line.SetPos = function (self, x1, x2, y)
    if x1 > x2 then
      x1, x2 = x2, x1
    end
    self:ClearAllPoints ()
    self:SetPoint ("BOTTOMLEFT", parent, "TOPLEFT", x1, y - self.width / 2)
    self:SetPoint ("TOPRIGHT", parent, "TOPLEFT", x2, y + self.width / 2)
  end
  return line
end

function GUI:CreateVLine (x, y1, y2, w, color, parent)
  parent = parent or self.defaultParent
  local line = parent:CreateTexture (nil, "ARTWORK")
  line:SetDrawLayer ("ARTWORK")
  line:SetTexture (color[1], color[2], color[3], color[4])
  if y1 > y2 then
    y1, y2 = y2, y1
  end
  line:ClearAllPoints ()
  line.width = w
  line:SetPoint ("BOTTOMLEFT", parent, "TOPLEFT", x - w / 2, y1)
  line:SetPoint ("TOPRIGHT", parent, "TOPLEFT", x + w / 2, y2)
  line:Show ()
  line.SetPos = function (self, x, y1, y2)
    if y1 > y2 then
      y1, y2 = y2, y1
    end
    self:ClearAllPoints ()
    self:SetPoint ("BOTTOMLEFT", parent, "TOPLEFT", x - self.width / 2, y1)
    self:SetPoint ("TOPRIGHT", parent, "TOPLEFT", x + self.width / 2, y2)
  end
  return line
end

--------------------------------------------------------------------------------

function GUI:CreateTable (rows, cols, firstRow, firstColumn, gridColor, parent)
  parent = parent or self.defaultParent
  firstRow = firstRow or 0
  firstColumn = firstColumn or 0

  local t = CreateFrame ("Frame", nil, parent)
  t:ClearAllPoints ()
  t:SetWidth (400)
  t:SetHeight (400)
  t:SetPoint ("TOPLEFT")

  t.rows = rows
  t.cols = cols
  t.gridColor = gridColor
  t.rowPos = {}
  t.colPos = {}
  t.rowHeight = {}
  t.colWidth = {}
  t.rowPos[-1] = 0
  t.rowPos[0] = firstRow
  t.colPos[-1] = 0
  t.colPos[0] = firstColumn
  t.rowHeight[0] = firstRow
  t.colWidth[0] = firstColumn

  t.SetRowHeight = function (self, n, h)
    if h then
      if n < 0 or n > self.rows then
        return
      end
      self.rowHeight[n] = h
      if n == 0 and self.hlines then
        if h == 0 then
          self.hlines[-1]:Hide ()
        else
          self.hlines[-1]:Show ()
        end
      end
    else
      for i = 1, self.rows do
        self.rowHeight[i] = n
      end
    end
    self:OnUpdateFix ()
  end
  t.SetColumnWidth = function (self, n, w)
    if w then
      if n < 0 or n > self.cols then
        return
      end
      self.colWidth[n] = w
      if n == 0 and self.vlines then
        if w == 0 then
          self.vlines[-1]:Hide ()
        else
          self.vlines[-1]:Show ()
        end
      end
    else
      for i = 1, self.cols do
        self.colWidth[i] = n
      end
    end
    self:OnUpdateFix ()
  end
  t.AddRow = function (self, i, n)
    i = i or (self.rows + 1)
    n = n or 1
    local height = ((i == self.rows + 1) and self.rowHeight[i - 1] or self.rowHeight[i])
    for r = self.rows, i, -1 do
      self.cells[r + n] = self.cells[r]
      self.rowHeight[r + n] = self.rowHeight[r]
    end
    for r = i, i + n - 1 do
      self.cells[r] = {}
      self.rowHeight[r] = height
      self.rows = self.rows + 1
      if self.gridColor then
        if self.hlines[self.rows] then
          self.hlines[self.rows]:Show ()
        else
          self.hlines[self.rows] = GUI:CreateHLine (0, 0, 0, 1, self.gridColor, self)
        end
      end
    end
    self:OnUpdateFix ()
  end
  t.MoveRow = function (self, i, to)
    local height = self.row[i] - self.rowPos[i - 1]
    local cells = self.cells[i]
    if to > i then
      for r = i + 1, to do
        self.cells[r - 1] = self.cells[r]
        self.rowHeight[r - 1] = self.rowHeight[r]
      end
    elseif to < i then
      for r = i - 1, to, -1 do
        self.cells[r + 1] = self.cells[r]
        self.rowHeight[r + 1] = self.rowHeight[r]
      end
    end
    self.cells[to] = cells
    self.rowHeight[to] = height
    self:OnUpdateFix ()
  end
  t.DeleteRow = function (self, i)
    for j = 0, self.cols do
      if self.cells[i][j] then
        if type (self.cells[i][j].Recycle) == "function" then
          self.cells[i][j]:Recycle ()
        else
          self.cells[i][j]:Hide ()
        end
      end
    end
    for r = i + 1, self.rows do
      self.cells[r - 1] = self.cells[r]
      self.rowHeight[r - 1] = self.rowHeight[r]
    end
    if self.hlines and self.hlines[self.rows] then
      self.hlines[self.rows]:Hide ()
    end
    self.rows = self.rows - 1
    self:OnUpdateFix ()
  end
  t.ClearCells = function (self)
    for i = 0, self.rows do
      for j = 0, self.cols do
        if self.cells[i][j] then
          if type (self.cells[i][j].Recycle) == "function" then
            self.cells[i][j]:Recycle ()
          else
            self.cells[i][j]:Hide ()
          end
        end
      end
      self.cells[i] = {}
    end
  end

  t.GetCellY = function (self, i)
    local n = math.ceil (i)
    if n < 0 then n = 0 end
    if n > self.rows then n = self.rows end
    return - (self.rowPos[n] + (self.rowPos[n - 1] - self.rowPos[n]) * (n - i))
  end
  t.GetCellX = function (self, j)
    local n = math.ceil (j)
    if n < 0 then n = 0 end
    if n > self.cols then n = self.cols end
    return self.colPos[n] + (self.colPos[n - 1] - self.colPos[n]) * (n - j)
  end
  t.GetRowHeight = function (self, i)
    return self.rowPos[i] - self.rowPos[i - 1]
  end
  t.GetColumnWidth = function (self, j)
    return self.colPos[j] - self.colPos[j - 1]
  end
  t.AlignCell = function (self, i, j)
    local cell = self.cells[i][j]
    local x = cell.offsX
    local y = cell.offsY
    cell:ClearAllPoints ()
    if cell.align == "FILL" then
      cell:SetPoint ("TOPLEFT", self, "TOPLEFT", self:GetCellX (j - 1) + x, self:GetCellY (i - 1) + y)
      cell:SetPoint ("BOTTOMRIGHT", self, "TOPLEFT", self:GetCellX (j) + x, self:GetCellY (i) + y)

    elseif cell.align == "TOPLEFT" then
      cell:SetPoint ("TOPLEFT", self, "TOPLEFT", self:GetCellX (j - 1) + 2 + x, self:GetCellY (i - 1) - 2 + y)
    elseif cell.align == "LEFT" then
      cell:SetPoint ("LEFT", self, "TOPLEFT", self:GetCellX (j - 1) + 4 + x, self:GetCellY (i - 0.5) + y)
    elseif cell.align == "BOTTOMLEFT" then
      cell:SetPoint ("BOTTOMLEFT", self, "TOPLEFT", self:GetCellX (j - 1) + 2 + x, self:GetCellY (i) + 2 + y)

    elseif cell.align == "TOP" then
      cell:SetPoint ("TOP", self, "TOPLEFT", self:GetCellX (j - 0.5) + x, self:GetCellY (i - 1) - 2 + y)
    elseif cell.align == "CENTER" then
      cell:SetPoint ("CENTER", self, "TOPLEFT", self:GetCellX (j - 0.5) + x, self:GetCellY (i - 0.5) + y)
    elseif cell.align == "BOTTOM" then
      cell:SetPoint ("BOTTOM", self, "TOPLEFT", self:GetCellX (j - 0.5) + x, self:GetCellY (i) + 2 + y)

    elseif cell.align == "TOPRIGHT" then
      cell:SetPoint ("TOPRIGHT", self, "TOPLEFT", self:GetCellX (j) - 2 + x, self:GetCellY (i - 1) - 2 + y)
    elseif cell.align == "RIGHT" then
      cell:SetPoint ("RIGHT", self, "TOPLEFT", self:GetCellX (j) - 4 + x, self:GetCellY (i - 0.5) + y)
    elseif cell.align == "BOTTOMRIGHT" then
      cell:SetPoint ("BOTTOMRIGHT", self, "TOPLEFT", self:GetCellX (j) - 2 + x, self:GetCellY (i) + 2 + y)
    end
  end
  t.OnUpdateFix = function (self)
    self:SetScript ("OnUpdate", nil)
    self:SetScript ("OnSizeChanged", nil)

    local numAutoRows = 0
    local totalHeight = 0
    for i = 0, self.rows do
      if self.rowHeight[i] == "AUTO" then
        numAutoRows = numAutoRows + 1
      else
        totalHeight = totalHeight + self.rowHeight[i]
      end
    end
    if numAutoRows == 0 then
      self:SetHeight (totalHeight)
    end
    local remHeight = self:GetHeight () - totalHeight
    for i = 0, self.rows do
      if self.rowHeight[i] == "AUTO" then
        self.rowPos[i] = self.rowPos[i - 1] + remHeight / numAutoRows
      else
        self.rowPos[i] = self.rowPos[i - 1] + self.rowHeight[i]
      end
    end
    local numAutoCols = 0
    local totalWidth = 0
    for i = 0, self.cols do
      if self.colWidth[i] == "AUTO" then
        numAutoCols = numAutoCols + 1
      else
        totalWidth = totalWidth + self.colWidth[i]
      end
    end
    if numAutoCols == 0 then
      self:SetWidth (totalWidth)
    end
    local remWidth = self:GetWidth () - totalWidth
    for i = 0, self.cols do
      if self.colWidth[i] == "AUTO" then
        self.colPos[i] = self.colPos[i - 1] + remWidth / numAutoCols
      else
        self.colPos[i] = self.colPos[i - 1] + self.colWidth[i]
      end
    end

    if self.gridColor then
      for i = -1, self.rows do
        self.hlines[i]:SetPos (0, self.colPos[self.cols], -self.rowPos[i])
      end
      for i = -1, self.cols do
        self.vlines[i]:SetPos (self.colPos[i], 0, -self.rowPos[self.rows])
      end
    end
    if self.headerBg then
      self.headerBg:SetPoint ("BOTTOMRIGHT", self, "TOPLEFT", self.colPos[self.cols], -self.rowPos[0])
    end
    for i = -1, self.rows do
      for j = -1, self.cols do
        if self.cells[i][j] then
          self:AlignCell (i, j)
        end
      end
    end

    self:SetScript ("OnSizeChanged", function (self)
      self:SetScript ("OnUpdate", self.OnUpdateFix)
    end)

    if self.onUpdate then
      self.onUpdate ()
    end
  end

  if gridColor then
    t.hlines = {}
    t.vlines = {}
    for i = -1, rows do
      t.hlines[i] = self:CreateHLine (0, 0, 0, 1, gridColor, t)
    end
    for i = -1, cols do
      t.vlines[i] = self:CreateVLine (0, 0, 0, 1, gridColor, t)
    end
    if firstRow == 0 then
      t.hlines[-1]:Hide ()
    end
    if firstColumn == 0 then
      t.vlines[-1]:Hide ()
    end
    -- Header row band, like the EllesmereUI table headers.
    if firstRow > 0 then
      t.headerBg = Solid (t, "BACKGROUND", 1, 1, 1, 0.04)
      t.headerBg:SetPoint ("TOPLEFT")
    end
  end
  t.cells = {}
  for i = -1, rows do
    t.cells[i] = {}
  end

  for i = 1, t.rows do
    t.rowHeight[i] = "AUTO"
  end
  for j = 1, t.cols do
    t.colWidth[j] = "AUTO"
  end
  t:OnUpdateFix ()

  t:SetScript ("OnSizeChanged", function (self)
    self:SetScript ("OnUpdate", self.OnUpdateFix)
  end)

  t.SetCell = function (self, i, j, value, align, offsX, offsY)
    align = align or "CENTER"
    offsX = offsX or 0
    offsY = offsY or 0
    self.cells[i][j] = value
    self.cells[i][j].align = align
    self.cells[i][j].offsX = offsX
    self.cells[i][j].offsY = offsY
    self:AlignCell (i, j)
  end
  t.textTagPool = {}
  t.SetCellText = function (self, i, j, text, align, color, font)
    align = align or "CENTER"
    color = color or {1, 1, 1, 0.85}
    font = FontObject (font or "EUIReforgeFontSmall")

    if self.cells[i][j] and not self.cells[i][j].istag then
      if type (self.cells[i][j].Recycle) == "function" then
        self.cells[i][j]:Recycle ()
      else
        self.cells[i][j]:Hide ()
      end
      self.cells[i][j] = nil
    end

    if self.cells[i][j] then
      self.cells[i][j]:SetFontObject (font)
      self.cells[i][j]:Show ()
    elseif #self.textTagPool > 0 then
      self.cells[i][j] = table.remove (self.textTagPool, 1)
      self.cells[i][j]:SetFontObject (font)
      self.cells[i][j]:Show ()
    else
      self.cells[i][j] = self:CreateFontString (nil, "OVERLAY", font)
      self.cells[i][j].Recycle = function (tag)
        tag:Hide ()
        table.insert (self.textTagPool, tag)
      end
    end
    self.cells[i][j].istag = true
    self.cells[i][j]:SetTextColor (color[1], color[2], color[3], color[4] or 1)
    self.cells[i][j]:SetText (text)
    self.cells[i][j].align = align
    self.cells[i][j].offsX = 0
    self.cells[i][j].offsY = 0
    self:AlignCell (i, j)
  end

  return t
end

---------------------------------------------------------------------------
-- Scroll bar: thin track with an accent thumb. Same calls as the Slider
-- ReforgeLite used (SetValue / GetValue 0..1000), onValueChanged (value).
---------------------------------------------------------------------------
function GUI:CreateScrollBar (parent)
  local bar = CreateFrame ("Frame", nil, parent)
  bar:SetWidth (6)
  bar:EnableMouse (true)
  Solid (bar, "BACKGROUND", 1, 1, 1, 0.05):SetAllPoints ()
  bar.thumb = CreateFrame ("Frame", nil, bar)
  bar.thumb:SetWidth (6)
  bar.thumb:EnableMouse (true)
  bar.thumbTex = AccentSolid (bar.thumb, "ARTWORK", 0.5)
  bar.thumbTex:SetAllPoints ()
  bar.value = 0
  bar.ratio = 0.5

  bar.Place = function (self)
    local track = self:GetHeight () or 0
    local size = max (20, track * min (1, self.ratio))
    self.thumb:SetHeight (size)
    self.thumb:ClearAllPoints ()
    self.thumb:SetPoint ("TOP", self, "TOP", 0, -(track - size) * self.value / 1000)
  end
  -- visible part of the content (0..1), sets the thumb size.
  bar.SetRatio = function (self, ratio)
    self.ratio = ratio
    self:Place ()
  end
  bar.SetValue = function (self, value)
    value = min (1000, max (0, value))
    self.value = value
    self:Place ()
    if self.onValueChanged then
      self.onValueChanged (value)
    end
  end
  bar.GetValue = function (self)
    return self.value
  end
  bar:SetScript ("OnSizeChanged", bar.Place)

  local function FromCursor ()
    local track = bar:GetHeight ()
    local size = bar.thumb:GetHeight ()
    local y = select (2, GetCursorPosition ()) / bar:GetEffectiveScale ()
    local top = bar:GetTop () or 0
    local pos = top - y - (bar.grab or size / 2)
    if track > size then
      bar:SetValue (pos / (track - size) * 1000)
    end
  end
  bar.thumb:SetScript ("OnMouseDown", function (self, button)
    if button == "LeftButton" then
      local y = select (2, GetCursorPosition ()) / bar:GetEffectiveScale ()
      bar.grab = (self:GetTop () or 0) - y
      bar.dragging = true
    end
  end)
  bar.thumb:SetScript ("OnMouseUp", function () bar.dragging = false end)
  bar.thumb:SetScript ("OnEnter", function () bar.thumbTex:SetTexture (ACCENT[1], ACCENT[2], ACCENT[3], 0.85) end)
  bar.thumb:SetScript ("OnLeave", function () bar.thumbTex:SetTexture (ACCENT[1], ACCENT[2], ACCENT[3], 0.5) end)
  bar:SetScript ("OnMouseDown", function (self, button)
    if button == "LeftButton" then
      self.grab = nil
      FromCursor ()
      self.grab = self.thumb:GetHeight () / 2
      self.dragging = true
    end
  end)
  bar:SetScript ("OnMouseUp", function (self) self.dragging = false end)
  bar:SetScript ("OnUpdate", function (self)
    if self.dragging then
      if IsMouseButtonDown ("LeftButton") then
        FromCursor ()
      else
        self.dragging = false
      end
    end
  end)
  return bar
end

---------------------------------------------------------------------------
-- Window: dark panel, 1 pixel border, header with the title, an accent line
-- and the EllesmereUI close icon (EllesmereUI Bags window style).
---------------------------------------------------------------------------
GUI.HEADER_H = 32

function GUI:StyleWindow (frame, title)
  frame:SetFrameStrata ("DIALOG")
  frame:SetToplevel (true)
  frame:SetClampedToScreen (true)
  frame.bg = Solid (frame, "BACKGROUND", WINDOW_BG[1], WINDOW_BG[2], WINDOW_BG[3], WINDOW_BG[4])
  frame.bg:SetAllPoints ()
  frame.border = AddBorder (frame, 0.1, 0.1, 0.1, 1, "OVERLAY")

  local header = CreateFrame ("Frame", nil, frame)
  header:SetPoint ("TOPLEFT", 1, -1)
  header:SetPoint ("TOPRIGHT", -1, -1)
  header:SetHeight (self.HEADER_H)
  Solid (header, "BACKGROUND", 0, 0, 0, 0.5):SetAllPoints ()
  local line = AccentSolid (header, "ARTWORK", 0.7)
  line:SetHeight (1)
  line:SetPoint ("BOTTOMLEFT")
  line:SetPoint ("BOTTOMRIGHT")
  frame.header = header

  frame.title = GUI:Text (header, "EUIReforgeFontLarge")
  frame.title:SetPoint ("LEFT", 12, 0)
  frame.title:SetText (title)

  local close = CreateFrame ("Button", nil, header)
  close:SetSize (12, 12)
  close:SetPoint ("RIGHT", -10, 0)
  close:SetHitRectInsets (-6, -6, -6, -6)
  close.icon = close:CreateTexture (nil, "OVERLAY")
  close.icon:SetAllPoints ()
  close.icon:SetTexture (MEDIA .. "eui-close")
  close.icon:SetAlpha (0.7)
  close:SetScript ("OnEnter", function () close.icon:SetAlpha (1) end)
  close:SetScript ("OnLeave", function () close.icon:SetAlpha (0.7) end)
  close:SetScript ("OnClick", function () frame:Hide () end)
  frame.close = close

  frame:HookScript ("OnHide", function ()
    GUI:CloseMenu ()
    HideTip ()
  end)
  -- Escape closes the window (UISpecialFrames needs a global name).
  if frame:GetName () then
    tinsert (UISpecialFrames, frame:GetName ())
  end
  return frame
end

-- Resize grip at the bottom right (EllesmereUI resize icon).
function GUI:CreateResizeGrip (frame, onDone)
  local grip = CreateFrame ("Button", nil, frame)
  grip:SetSize (16, 16)
  grip:SetPoint ("BOTTOMRIGHT", -2, 2)
  grip:SetFrameLevel (frame:GetFrameLevel () + 20)
  grip.icon = grip:CreateTexture (nil, "OVERLAY")
  grip.icon:SetAllPoints ()
  grip.icon:SetTexture (MEDIA .. "eui-resize-5")
  grip.icon:SetAlpha (0.35)
  grip:SetScript ("OnEnter", function () grip.icon:SetAlpha (0.8) end)
  grip:SetScript ("OnLeave", function () grip.icon:SetAlpha (0.35) end)
  grip:SetScript ("OnMouseDown", function (self, button)
    if button == "LeftButton" then
      frame:StartSizing ("BOTTOMRIGHT")
      frame.sizing = true
    end
  end)
  grip:SetScript ("OnMouseUp", function ()
    if frame.sizing then
      frame:StopMovingOrSizing ()
      frame.sizing = false
      if onDone then
        onDone ()
      end
    end
  end)
  return grip
end

---------------------------------------------------------------------------
-- Popup (EllesmereUI popup): dark box over a dim screen, with a text box.
-- opts: title, message, text (start text), multiLine, readOnly, width,
-- height, acceptText, cancelText, hideCancel, onAccept (text)
---------------------------------------------------------------------------
local popup

local function BuildPopup ()
  popup = CreateFrame ("Frame", "EUIReforgePopup", UIParent)
  popup:SetAllPoints (UIParent)
  popup:SetFrameStrata ("FULLSCREEN_DIALOG")
  popup:SetFrameLevel (40)
  popup:EnableMouse (true)
  Solid (popup, "BACKGROUND", 0, 0, 0, 0.55):SetAllPoints ()

  local box = CreateFrame ("Frame", nil, popup)
  popup.box = box
  box:SetPoint ("CENTER", 0, 60)
  box:EnableMouse (true)
  Solid (box, "BACKGROUND", PANEL_BG[1], PANEL_BG[2], PANEL_BG[3], 0.98):SetAllPoints ()
  AddBorder (box, 1, 1, 1, 0.15)
  local accent = AccentSolid (box, "ARTWORK", 0.7)
  accent:SetHeight (2)
  accent:SetPoint ("TOPLEFT", 1, -1)
  accent:SetPoint ("TOPRIGHT", -1, -1)

  popup.title = GUI:Text (box, "EUIReforgeFontLarge")
  popup.title:SetPoint ("TOP", 0, -18)
  popup.message = GUI:Text (box, "EUIReforgeFont", 0.75)
  popup.message:SetPoint ("TOP", popup.title, "BOTTOM", 0, -10)
  popup.message:SetJustifyH ("CENTER")
  popup.message:SetSpacing (3)

  -- Text area: one line box, or a scrolling multi-line box.
  popup.area = CreateFrame ("Frame", nil, box)
  Solid (popup.area, "BACKGROUND", BOX_BG[1], BOX_BG[2], BOX_BG[3], 0.6):SetAllPoints ()
  popup.areaBorder = AddBorder (popup.area, 1, 1, 1, 0.15)
  local scroll = CreateFrame ("ScrollFrame", nil, popup.area)
  popup.scroll = scroll
  scroll:SetPoint ("TOPLEFT", 6, -6)
  scroll:SetPoint ("BOTTOMRIGHT", -14, 6)
  local edit = CreateFrame ("EditBox", nil, scroll)
  popup.edit = edit
  scroll:SetScrollChild (edit)
  edit:SetAutoFocus (false)
  edit:SetFontObject (EUIReforgeFont)
  edit:SetTextColor (1, 1, 1, 0.9)
  scroll.bar = GUI:CreateScrollBar (popup.area)
  scroll.bar:SetPoint ("TOPRIGHT", -4, -4)
  scroll.bar:SetPoint ("BOTTOMRIGHT", -4, 4)
  scroll.bar:SetWidth (4)
  scroll.bar.thumb:SetWidth (4)
  scroll.bar.onValueChanged = function (value)
    local range = scroll:GetVerticalScrollRange ()
    scroll:SetVerticalScroll (range * value / 1000)
  end
  local function UpdateBar ()
    local range = scroll:GetVerticalScrollRange ()
    if range > 0 and popup.multi then
      scroll.bar:Show ()
      scroll.bar.ratio = scroll:GetHeight () / (scroll:GetHeight () + range)
      scroll.bar.value = min (1000, scroll:GetVerticalScroll () / range * 1000)
      scroll.bar:Place ()
    else
      scroll.bar:Hide ()
    end
  end
  scroll:SetScript ("OnScrollRangeChanged", UpdateBar)
  scroll:SetScript ("OnVerticalScroll", UpdateBar)
  scroll:EnableMouseWheel (true)
  scroll:SetScript ("OnMouseWheel", function (self, delta)
    local range = self:GetVerticalScrollRange ()
    self:SetVerticalScroll (min (range, max (0, self:GetVerticalScroll () - delta * 40)))
  end)
  edit:SetScript ("OnCursorChanged", function (self, x, y, w, h)
    if not popup.multi then
      return
    end
    local top = scroll:GetVerticalScroll ()
    local view = scroll:GetHeight ()
    y = -y
    if y < top then
      scroll:SetVerticalScroll (y)
    elseif y + h > top + view then
      scroll:SetVerticalScroll (y + h - view)
    end
  end)
  edit:SetScript ("OnEditFocusGained", function () popup.areaBorder:SetColor (ACCENT[1], ACCENT[2], ACCENT[3], 0.8) end)
  edit:SetScript ("OnEditFocusLost", function () popup.areaBorder:SetColor (1, 1, 1, 0.15) end)
  -- The whole box focuses the text.
  popup.area:EnableMouse (true)
  popup.area:SetScript ("OnMouseDown", function () edit:SetFocus () end)

  popup.accept = GUI:CreateButton (box, 140, 30, ACCEPT, true)
  popup.cancel = GUI:CreateButton (box, 140, 30, CANCEL)

  local function Close ()
    popup:Hide ()
    edit:ClearFocus ()
  end
  popup.Close = Close
  popup.cancel:SetScript ("OnClick", Close)
  popup.accept:SetScript ("OnClick", function ()
    local opts = popup.opts
    local text = edit:GetText () or ""
    if opts and opts.requireText and text == "" then
      return
    end
    Close ()
    if opts and opts.onAccept then
      opts.onAccept (text)
    end
  end)
  edit:SetScript ("OnTextChanged", function (self)
    local opts = popup.opts
    if opts and opts.readOnly then
      if self:GetText () ~= opts.text then
        self:SetText (opts.text or "")
        self:HighlightText ()
      end
    end
    local ok = not (opts and opts.requireText) or (self:GetText () or "") ~= ""
    if ok then popup.accept:Enable () else popup.accept:Disable () end
    UpdateBar ()
  end)
  edit:SetScript ("OnEnterPressed", function (self)
    if popup.multi then
      self:Insert ("\n")
    else
      popup.accept:Click ()
    end
  end)
  edit:SetScript ("OnEscapePressed", Close)
  popup:EnableKeyboard (true)
  popup:SetScript ("OnKeyDown", function (self, key)
    if key == "ESCAPE" then
      self:SetPropagateKeyboardInput (false)
      Close ()
    else
      self:SetPropagateKeyboardInput (true)
    end
  end)
  popup:Hide ()
end

function GUI:ShowPopup (opts)
  if not popup then
    BuildPopup ()
  end
  popup.opts = opts
  popup.multi = opts.multiLine and true or false
  local width = opts.width or 380
  popup.box:SetWidth (width)
  popup.title:SetText (opts.title or "")
  popup.message:SetWidth (width - 40)
  popup.message:SetText (opts.message or "")
  local y = 18 + popup.title:GetStringHeight () + 10
  if (opts.message or "") ~= "" then
    y = y + popup.message:GetStringHeight () + 12
  end

  local areaH = popup.multi and (opts.height or 220) or 28
  popup.area:ClearAllPoints ()
  popup.area:SetPoint ("TOPLEFT", popup.box, "TOPLEFT", 20, -y)
  popup.area:SetPoint ("TOPRIGHT", popup.box, "TOPRIGHT", -20, -y)
  popup.area:SetHeight (areaH)
  popup.edit:SetMultiLine (popup.multi)
  popup.edit:SetWidth (width - 40 - 20)
  popup.edit:SetHeight (popup.multi and areaH or 16)
  popup.edit:SetJustifyH (popup.multi and "LEFT" or "CENTER")
  popup.edit:SetMaxLetters (opts.maxLetters or 0)
  popup.scroll:ClearAllPoints ()
  if popup.multi then
    popup.scroll:SetPoint ("TOPLEFT", 6, -6)
    popup.scroll:SetPoint ("BOTTOMRIGHT", -14, 6)
  else
    popup.scroll:SetPoint ("TOPLEFT", 6, -6)
    popup.scroll:SetPoint ("BOTTOMRIGHT", -6, 6)
  end
  popup.scroll:SetVerticalScroll (0)
  y = y + areaH + 18

  popup.accept:SetText (opts.acceptText or ACCEPT)
  popup.cancel:SetText (opts.cancelText or CANCEL)
  popup.accept:ClearAllPoints ()
  popup.cancel:ClearAllPoints ()
  if opts.hideCancel then
    popup.cancel:Hide ()
    popup.accept:SetPoint ("TOP", popup.box, "TOP", 0, -y)
  else
    popup.cancel:Show ()
    popup.accept:SetPoint ("TOPRIGHT", popup.box, "TOP", -6, -y)
    popup.cancel:SetPoint ("TOPLEFT", popup.box, "TOP", 6, -y)
  end
  popup.box:SetHeight (y + 30 + 18)

  popup:Show ()
  popup.edit:SetText (opts.text or "")
  if opts.readOnly then
    popup.edit:SetFocus ()
    popup.edit:HighlightText ()
  else
    popup.edit:SetFocus ()
  end
end

function GUI:HidePopup ()
  if popup then
    popup.Close ()
  end
end

------------------------------------------------------------------------------

EUIReforgeGUI = GUI
