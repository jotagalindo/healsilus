-- Pestaña Aspecto: fuente, fondo y colores de vida de la barra, y tamaño, contorno y posición de cada
-- texto (nombre, vida, estado). Edita el estilo activo, que la cabecera de la ventana indica.
local _, ns = ...
local L = ns.L
local Widgets = ns.Widgets

local TabAppearance = { selected = "name", stacks = {}, swatches = {} }
ns.TabAppearance = TabAppearance

TabAppearance.TEXT_ELEMENTS = {
  { key = "name", label = L.TEXT_ELEMENT_NAME },
  { key = "health", label = L.TEXT_ELEMENT_HEALTH },
  { key = "status", label = L.TEXT_ELEMENT_STATUS },
}

TabAppearance.OUTLINE_OPTIONS = {
  { value = "NONE", label = L.OUTLINE_NONE },
  { value = "OUTLINE", label = L.OUTLINE_THIN },
  { value = "THICKOUTLINE", label = L.OUTLINE_THICK },
}

TabAppearance.POINT_OPTIONS = {
  { value = "TOPLEFT", label = L.POINT_TOPLEFT },
  { value = "TOP", label = L.POINT_TOP },
  { value = "TOPRIGHT", label = L.POINT_TOPRIGHT },
  { value = "LEFT", label = L.POINT_LEFT },
  { value = "CENTER", label = L.POINT_CENTER },
  { value = "RIGHT", label = L.POINT_RIGHT },
  { value = "BOTTOMLEFT", label = L.POINT_BOTTOMLEFT },
  { value = "BOTTOM", label = L.POINT_BOTTOM },
  { value = "BOTTOMRIGHT", label = L.POINT_BOTTOMRIGHT },
}

TabAppearance.HEALTH_MODE_OPTIONS = {
  { value = "NONE", label = L.TEXT_NONE },
  { value = "DEFICIT", label = L.TEXT_DEFICIT },
  { value = "PERCENT", label = L.TEXT_PERCENT },
}

local HEALTH_COLORS = {
  { key = "healthy", label = L.APPEARANCE_HEALTHY },
  { key = "injured", label = L.APPEARANCE_INJURED },
  { key = "critical", label = L.APPEARANCE_CRITICAL },
}

local function Style()
  return ns.Styles.active
end

-- Los controles de texto editan el elemento elegido en "Texto a editar".
function TabAppearance.TextGetter(key)
  return function()
    return Style().text[TabAppearance.selected][key]
  end
end

function TabAppearance.TextSetter(key)
  return function(value)
    Style().text[TabAppearance.selected][key] = value
    ns.Config:Changed("style")
  end
end

local function BarColorSetter(key)
  return function(red, green, blue)
    Widgets.Debounce("appearance:" .. key, function()
      local color = { r = red, g = green, b = blue }
      if key == "background" then
        color.a = Style().bar.background.a
      end
      Style().bar[key] = color
      ns.Config:Changed("style")
    end)
  end
end

local function AddColorRow(panel, stack, label, key)
  local swatch = Widgets.ColorSwatch(panel, function()
    return Style().bar[key]
  end, BarColorSetter(key))
  local text = Widgets.Label(panel, label)
  text:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
  stack:Add(swatch, 30)
  TabAppearance.swatches[#TabAppearance.swatches + 1] = swatch
end

local function RangeSlider(panel, label, key, getter, setter, step, format)
  local range = ns.Database.RANGES[key]
  return Widgets.Slider(panel, label, range[1], range[2], step, getter, setter, format)
end

function TabAppearance.Build(panel)
  local bar = Widgets.Stack(panel, 0, 0)
  bar:Add(Widgets.Dropdown(panel, L.APPEARANCE_FONT, 220, ns.Media.FontOptions,
    Widgets.StyleGetter("text", "font"), Widgets.StyleSetter("text", "font")), 50)
  AddColorRow(panel, bar, L.APPEARANCE_BACKGROUND, "background")
  bar:Add(RangeSlider(panel, L.APPEARANCE_BACKGROUND_ALPHA, "a",
    Widgets.StyleGetter("bar", "background", "a"), Widgets.StyleSetter("bar", "background", "a"), 0.05, "%.2f"), 48)
  bar:Add(Widgets.Label(panel, L.APPEARANCE_HEALTH_COLORS, "GameFontNormal"), 22)
  for _, entry in ipairs(HEALTH_COLORS) do
    AddColorRow(panel, bar, entry.label, entry.key)
  end
  bar:Add(RangeSlider(panel, L.APPEARANCE_INJURED_AT, "injuredAt",
    Widgets.StyleGetter("bar", "injuredAt"), Widgets.StyleSetter("bar", "injuredAt"), 0.05, "%.2f"), 48)
  bar:Add(RangeSlider(panel, L.APPEARANCE_CRITICAL_AT, "criticalAt",
    Widgets.StyleGetter("bar", "criticalAt"), Widgets.StyleSetter("bar", "criticalAt"), 0.05, "%.2f"), 48)

  local texts = Widgets.Stack(panel, 320, 0)
  local elementOptions = {}
  for _, element in ipairs(TabAppearance.TEXT_ELEMENTS) do
    elementOptions[#elementOptions + 1] = { value = element.key, label = element.label }
  end
  texts:Add(Widgets.Dropdown(panel, L.APPEARANCE_TEXT, 220, function()
    return elementOptions
  end, function()
    return TabAppearance.selected
  end, function(key)
    TabAppearance.selected = key
    ns.Config:Refresh()
  end), 50)
  texts:Add(RangeSlider(panel, L.APPEARANCE_SIZE, "size", TabAppearance.TextGetter("size"), TabAppearance.TextSetter("size"), 1), 48)
  texts:Add(Widgets.Dropdown(panel, L.APPEARANCE_OUTLINE, 220, function()
    return TabAppearance.OUTLINE_OPTIONS
  end, TabAppearance.TextGetter("outline"), TabAppearance.TextSetter("outline")), 50)
  texts:Add(Widgets.Dropdown(panel, L.APPEARANCE_POINT, 220, function()
    return TabAppearance.POINT_OPTIONS
  end, TabAppearance.TextGetter("point"), TabAppearance.TextSetter("point")), 50)
  texts:Add(RangeSlider(panel, L.APPEARANCE_OFFSET_X, "x", TabAppearance.TextGetter("x"), TabAppearance.TextSetter("x"), 1), 48)
  texts:Add(RangeSlider(panel, L.APPEARANCE_OFFSET_Y, "y", TabAppearance.TextGetter("y"), TabAppearance.TextSetter("y"), 1), 48)
  texts:Add(Widgets.Dropdown(panel, L.FRAMES_HEALTH_TEXT, 220, function()
    return TabAppearance.HEALTH_MODE_OPTIONS
  end, Widgets.StyleGetter("text", "health", "mode"), Widgets.StyleSetter("text", "health", "mode")), 50)
  TabAppearance.stacks = { bar, texts }
end

function TabAppearance.Refresh()
  for _, stack in ipairs(TabAppearance.stacks) do
    stack:Refresh()
  end
end

ns.Config:RegisterTab("appearance", L.TAB_APPEARANCE, TabAppearance.Build, TabAppearance.Refresh)
