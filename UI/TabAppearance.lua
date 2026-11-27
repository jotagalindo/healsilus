-- Pestaña Aspecto: fuente, fondo y colores de vida de la barra y la barra de maná/energía; tamaño,
-- contorno y posición de cada texto (nombre, vida, estado); icono de rol y aviso de aggro. Edita el
-- estilo activo, que la cabecera de la ventana indica.
local _, ns = ...
local L = ns.L
local Widgets = ns.Widgets

local TabAppearance = { selected = "name", stacks = {}, swatches = {} }
ns.TabAppearance = TabAppearance

TabAppearance.TEXT_ELEMENTS = {
  { key = "name", label = L.TEXT_ELEMENT_NAME },
  { key = "health", label = L.TEXT_ELEMENT_HEALTH },
  { key = "status", label = L.TEXT_ELEMENT_STATUS, shortLabel = L.TEXT_ELEMENT_STATUS_SHORT },
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
  { value = "CURRENT", label = L.TEXT_CURRENT },
  { value = "CURRENT_MAX", label = L.TEXT_CURRENT_MAX },
  { value = "CURRENT_PERCENT", label = L.TEXT_CURRENT_PERCENT },
}

local HEALTH_COLORS = {
  { key = "healthy", label = L.APPEARANCE_HEALTHY },
  { key = "injured", label = L.APPEARANCE_INJURED },
  { key = "critical", label = L.APPEARANCE_CRITICAL },
}

-- Icono de rol y aggro: casillas, posición y tamaño de cada uno (style.role y style.aggro).
TabAppearance.INDICATORS = {
  {
    key = "role", title = L.APPEARANCE_ROLE_TITLE, pointLabel = L.APPEARANCE_ROLE_POINT, sizeLabel = L.APPEARANCE_ROLE_SIZE,
    checks = {
      { key = "show", label = L.APPEARANCE_ROLE_SHOW },
      { key = "showDamager", label = L.APPEARANCE_ROLE_DAMAGER },
    },
  },
  {
    key = "aggro", title = L.APPEARANCE_AGGRO_TITLE, pointLabel = L.APPEARANCE_AGGRO_POINT, sizeLabel = L.APPEARANCE_AGGRO_SIZE,
    checks = {
      { key = "border", label = L.APPEARANCE_AGGRO_BORDER },
      { key = "blink", label = L.APPEARANCE_AGGRO_BLINK },
      { key = "dots", label = L.APPEARANCE_AGGRO_DOTS },
    },
  },
}

-- Subpáginas de la pestaña (botones de arriba).
TabAppearance.PAGES = {
  { value = "bar", label = L.APPEARANCE_PAGE_BAR },
  { value = "text", label = L.APPEARANCE_PAGE_TEXT },
  { value = "icons", label = L.APPEARANCE_PAGE_ICONS },
  { value = "auras", label = L.APPEARANCE_PAGE_AURAS },
}

-- Grupos de iconos que se colocan en la página Auras (style.auras.<key>).
TabAppearance.AURA_GROUPS = {
  { value = "hots", label = L.APPEARANCE_AURA_HOTS },
  { value = "debuffs", label = L.APPEARANCE_AURA_DEBUFFS },
  { value = "buffs", label = L.APPEARANCE_AURA_BUFFS },
}
TabAppearance.auraGroup = "hots"

-- Los nueve puntos de dentro de la barra y los cuatro lados de fuera.
TabAppearance.AURA_POSITION_OPTIONS = {}
for _, option in ipairs(TabAppearance.POINT_OPTIONS) do
  TabAppearance.AURA_POSITION_OPTIONS[#TabAppearance.AURA_POSITION_OPTIONS + 1] = option
end
for _, option in ipairs({
  { value = "ABOVE", label = L.AURA_POSITION_ABOVE },
  { value = "BELOW", label = L.AURA_POSITION_BELOW },
  { value = "OUTSIDE_LEFT", label = L.AURA_POSITION_OUTSIDE_LEFT },
  { value = "OUTSIDE_RIGHT", label = L.AURA_POSITION_OUTSIDE_RIGHT },
}) do
  TabAppearance.AURA_POSITION_OPTIONS[#TabAppearance.AURA_POSITION_OPTIONS + 1] = option
end

TabAppearance.GROW_OPTIONS = {
  { value = "LEFT", label = L.GROW_LEFT },
  { value = "RIGHT", label = L.GROW_RIGHT },
}
TabAppearance.page = "bar"

local SECTION_WIDTH = 240
local COLUMN_X = { 0, 252 }
local PAGE_TOP = -36
local SAMPLE_X, SAMPLE_WIDTH = 504, 276
local SAMPLE_GAP = 6
local SLIDER_HEIGHT, DROPDOWN_HEIGHT, CHECKBOX_HEIGHT, PICKER_HEIGHT = 46, 48, 26, 66

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

-- Elegir una posición nueva deja el texto o el icono a la distancia de serie del borde (y a 0 en el eje
-- centrado): "Centro" queda justo en el centro de la barra. target: "name", "health", "status" (textos),
-- "role" o "aggro"; nil = el texto elegido en "Texto a editar".
function TabAppearance.PointSetter(target)
  return function(point)
    local element
    if target == "role" or target == "aggro" then
      element = Style()[target]
    else
      element = Style().text[target or TabAppearance.selected]
    end
    element.point = point
    element.x, element.y = ns.StyleData.DefaultOffset(point)
    ns.Config:Changed("style")
  end
end

-- Controles de la página Auras: editan el grupo elegido (HoTs, debuffs o buff que falta).
function TabAppearance.AuraGetter(key)
  return function()
    return Style().auras[TabAppearance.auraGroup][key]
  end
end

function TabAppearance.AuraSetter(key)
  return function(value)
    Style().auras[TabAppearance.auraGroup][key] = value
    ns.Config:Changed("style")
  end
end

-- Una posición nueva empieza sin desplazamiento y creciendo hacia el centro de la barra.
function TabAppearance.AuraPositionSetter(value)
  local group = Style().auras[TabAppearance.auraGroup]
  group.position, group.x, group.y = value, 0, 0
  group.grow = ns.StyleData.DefaultGrow(value)
  ns.Config:Changed("style")
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

-- Fila con un cuadrado de color y su nombre.
local function AddColorRow(section, label, key)
  local swatch = Widgets.ColorSwatch(section.frame, function()
    return Style().bar[key]
  end, BarColorSetter(key))
  local text = Widgets.Label(section.frame, label)
  text:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
  section:Add(swatch, 28)
  TabAppearance.swatches[#TabAppearance.swatches + 1] = swatch
end

local function RangeSlider(parent, label, key, getter, setter, step, format)
  local range = ns.Database.RANGES[key]
  return Widgets.Slider(parent, label, range[1], range[2], step, getter, setter, format)
end

local function Dropdown(section, label, options, getter, setter)
  return section:Add(Widgets.Dropdown(section.frame, label, 220, function()
    return type(options) == "function" and options() or options
  end, getter, setter), DROPDOWN_HEIGHT)
end

local function Checkbox(section, label, getter, setter)
  return section:Add(Widgets.Checkbox(section.frame, label, getter, setter), CHECKBOX_HEIGHT)
end

local function Slider(section, label, key, getter, setter, step, format)
  return section:Add(RangeSlider(section.frame, label, key, getter, setter, step, format), SLIDER_HEIGHT)
end

local TEXTURE_OPTIONS = function()
  return ns.Media.TextureOptions()
end

local COLOR_MODE_OPTIONS = {
  { value = "CLASS", label = L.COLOR_CLASS }, { value = "HEALTH", label = L.COLOR_HEALTH },
}

-- Casillas de cada recurso en dos columnas (style.power.types).
TabAppearance.POWER_TYPES = {
  { key = "MANA", label = L.POWER_MANA },
  { key = "RAGE", label = L.POWER_RAGE },
  { key = "ENERGY", label = L.POWER_ENERGY },
  { key = "FOCUS", label = L.POWER_FOCUS },
  { key = "RUNIC_POWER", label = L.POWER_RUNIC },
  { key = "OTHER", label = L.POWER_OTHER },
}
local POWER_ROW_HEIGHT, POWER_COLUMN_WIDTH = 24, 110

function TabAppearance.PowerTypeGrid(parent)
  local grid = CreateFrame("Frame", nil, parent)
  grid:SetSize(2 * POWER_COLUMN_WIDTH, 3 * POWER_ROW_HEIGHT)
  grid.checks = {}
  for position, entry in ipairs(TabAppearance.POWER_TYPES) do
    local check = Widgets.Checkbox(grid, entry.label, Widgets.StyleGetter("power", "types", entry.key),
      Widgets.StyleSetter("power", "types", entry.key))
    local column, row = (position - 1) % 2, math.floor((position - 1) / 2)
    check:SetPoint("TOPLEFT", grid, "TOPLEFT", column * POWER_COLUMN_WIDTH, -row * POWER_ROW_HEIGHT)
    grid.checks[position] = check
  end
  grid.Refresh = function(self)
    for _, check in ipairs(self.checks) do
      check:Refresh()
    end
  end
  return grid
end

-- Página "Barra": textura y fondo, colores de vida, opacidades y barra de maná/energía.
local function BuildBarPage(page)
  local left, right = Widgets.Column(page, COLUMN_X[1], 0), Widgets.Column(page, COLUMN_X[2], 0)
  local look = left:Next(Widgets.Section(page, L.APPEARANCE_SECTION_BAR, SECTION_WIDTH))
  Dropdown(look, L.FRAMES_TEXTURE, TEXTURE_OPTIONS, Widgets.StyleGetter("bar", "texture"), Widgets.StyleSetter("bar", "texture"))
  Dropdown(look, L.FRAMES_COLOR, COLOR_MODE_OPTIONS, Widgets.StyleGetter("bar", "colorMode"), Widgets.StyleSetter("bar", "colorMode"))
  AddColorRow(look, L.APPEARANCE_BACKGROUND, "background")
  Slider(look, L.APPEARANCE_BACKGROUND_ALPHA, "a",
    Widgets.StyleGetter("bar", "background", "a"), Widgets.StyleSetter("bar", "background", "a"), 0.05, "%.2f")

  local opacity = left:Next(Widgets.Section(page, L.APPEARANCE_SECTION_OPACITY, SECTION_WIDTH))
  Slider(opacity, L.FRAMES_RANGE_ALPHA, "outOfRangeAlpha",
    Widgets.StyleGetter("bar", "outOfRangeAlpha"), Widgets.StyleSetter("bar", "outOfRangeAlpha"), 0.05, "%.2f")
  Slider(opacity, L.APPEARANCE_FULL_HEALTH_ALPHA, "fullHealthAlpha",
    Widgets.StyleGetter("bar", "fullHealthAlpha"), Widgets.StyleSetter("bar", "fullHealthAlpha"), 0.05, "%.2f")

  local colors = right:Next(Widgets.Section(page, L.APPEARANCE_HEALTH_COLORS, SECTION_WIDTH))
  for _, entry in ipairs(HEALTH_COLORS) do
    AddColorRow(colors, entry.label, entry.key)
  end
  Slider(colors, L.APPEARANCE_INJURED_AT, "injuredAt",
    Widgets.StyleGetter("bar", "injuredAt"), Widgets.StyleSetter("bar", "injuredAt"), 0.05, "%.2f")
  Slider(colors, L.APPEARANCE_CRITICAL_AT, "criticalAt",
    Widgets.StyleGetter("bar", "criticalAt"), Widgets.StyleSetter("bar", "criticalAt"), 0.05, "%.2f")

  local power = right:Next(Widgets.Section(page, L.APPEARANCE_POWER_TITLE, SECTION_WIDTH))
  Checkbox(power, L.APPEARANCE_POWER_SHOW, Widgets.StyleGetter("power", "show"), Widgets.StyleSetter("power", "show"))
  Checkbox(power, L.APPEARANCE_POWER_HEALERS, Widgets.StyleGetter("power", "healersOnly"),
    Widgets.StyleSetter("power", "healersOnly"))
  power:Add(Widgets.Label(power.frame, L.APPEARANCE_POWER_TYPES, "GameFontNormalSmall"), 18)
  power:Add(TabAppearance.PowerTypeGrid(power.frame), 3 * POWER_ROW_HEIGHT + 2)
  Slider(power, L.APPEARANCE_POWER_THICKNESS, "thickness", Widgets.StyleGetter("power", "thickness"),
    Widgets.StyleSetter("power", "thickness"), 1)
  return { left, right }
end

-- Página "Textos": qué número de vida y fuente; luego el texto elegido: tamaño, contorno y posición.
local function BuildTextPage(page)
  local left, right = Widgets.Column(page, COLUMN_X[1], 0), Widgets.Column(page, COLUMN_X[2], 0)
  local general = left:Next(Widgets.Section(page, L.APPEARANCE_SECTION_TEXTS, SECTION_WIDTH))
  Dropdown(general, L.FRAMES_HEALTH_TEXT, TabAppearance.HEALTH_MODE_OPTIONS,
    Widgets.StyleGetter("text", "health", "mode"), Widgets.StyleSetter("text", "health", "mode"))
  Dropdown(general, L.APPEARANCE_FONT, ns.Media.FontOptions, Widgets.StyleGetter("text", "font"), Widgets.StyleSetter("text", "font"))

  local elementOptions = {}
  for _, element in ipairs(TabAppearance.TEXT_ELEMENTS) do
    elementOptions[#elementOptions + 1] = { value = element.key, label = element.shortLabel or element.label }
  end
  local edit = left:Next(Widgets.Section(page, L.APPEARANCE_TEXT, SECTION_WIDTH))
  edit:Add(Widgets.Segmented(edit.frame, elementOptions, 220, function()
    return TabAppearance.selected
  end, function(key)
    TabAppearance.selected = key
    ns.Config:Refresh()
  end), 34)
  Slider(edit, L.APPEARANCE_SIZE, "size", TabAppearance.TextGetter("size"), TabAppearance.TextSetter("size"), 1)
  Dropdown(edit, L.APPEARANCE_OUTLINE, TabAppearance.OUTLINE_OPTIONS, TabAppearance.TextGetter("outline"),
    TabAppearance.TextSetter("outline"))

  local position = right:Next(Widgets.Section(page, L.APPEARANCE_SECTION_POSITION, SECTION_WIDTH))
  position:Add(Widgets.PointPicker(position.frame, L.APPEARANCE_POINT, TabAppearance.POINT_OPTIONS,
    TabAppearance.TextGetter("point"), TabAppearance.PointSetter()), PICKER_HEIGHT)
  Slider(position, L.APPEARANCE_OFFSET_X, "x", TabAppearance.TextGetter("x"), TabAppearance.TextSetter("x"), 1)
  Slider(position, L.APPEARANCE_OFFSET_Y, "y", TabAppearance.TextGetter("y"), TabAppearance.TextSetter("y"), 1)
  return { left, right }
end

-- Página "Rol y aggro": casillas, posición y tamaño del icono de rol y de los puntos de aggro.
local function BuildIconsPage(page)
  local columns = {}
  for position, indicator in ipairs(TabAppearance.INDICATORS) do
    local column = Widgets.Column(page, COLUMN_X[position], 0)
    local section = column:Next(Widgets.Section(page, indicator.title, SECTION_WIDTH))
    for _, check in ipairs(indicator.checks) do
      Checkbox(section, check.label, Widgets.StyleGetter(indicator.key, check.key), Widgets.StyleSetter(indicator.key, check.key))
    end
    section:Add(Widgets.PointPicker(section.frame, indicator.pointLabel, TabAppearance.POINT_OPTIONS,
      Widgets.StyleGetter(indicator.key, "point"), TabAppearance.PointSetter(indicator.key)), PICKER_HEIGHT)
    Slider(section, indicator.sizeLabel, "size", Widgets.StyleGetter(indicator.key, "size"),
      Widgets.StyleSetter(indicator.key, "size"), 1)
    columns[#columns + 1] = column
  end
  return columns
end

-- Página "Auras": dónde van los HoTs, los debuffs y el aviso de buff que falta, y cómo crecen.
local function BuildAurasPage(page)
  local left, right = Widgets.Column(page, COLUMN_X[1], 0), Widgets.Column(page, COLUMN_X[2], 0)
  local place = left:Next(Widgets.Section(page, L.APPEARANCE_AURA_PLACE, SECTION_WIDTH))
  place:Add(Widgets.Segmented(place.frame, TabAppearance.AURA_GROUPS, 220, function()
    return TabAppearance.auraGroup
  end, function(key)
    TabAppearance.auraGroup = key
    ns.Config:Refresh()
  end), 34)
  place:Add(Widgets.PointPicker(place.frame, L.APPEARANCE_POINT, TabAppearance.AURA_POSITION_OPTIONS,
    TabAppearance.AuraGetter("position"), TabAppearance.AuraPositionSetter), 96)
  local grow = Widgets.Label(place.frame, L.APPEARANCE_AURA_GROW, "GameFontNormalSmall")
  place:Add(grow, 16)
  place:Add(Widgets.Segmented(place.frame, TabAppearance.GROW_OPTIONS, 220, TabAppearance.AuraGetter("grow"),
    TabAppearance.AuraSetter("grow")), 32)

  local adjust = right:Next(Widgets.Section(page, L.APPEARANCE_AURA_ADJUST, SECTION_WIDTH))
  Slider(adjust, L.AURAS_ICON_SIZE, "iconSize", TabAppearance.AuraGetter("iconSize"), TabAppearance.AuraSetter("iconSize"), 1)
  Slider(adjust, L.APPEARANCE_OFFSET_X, "x", TabAppearance.AuraGetter("x"), TabAppearance.AuraSetter("x"), 1)
  Slider(adjust, L.APPEARANCE_OFFSET_Y, "y", TabAppearance.AuraGetter("y"), TabAppearance.AuraSetter("y"), 1)
  local note = Widgets.Label(adjust.frame, L.APPEARANCE_AURA_NOTE, "GameFontDisableSmall")
  note:SetWidth(220)
  note:SetWordWrap(true)
  adjust:Add(note, 44)
  return { left, right }
end

-- Vista de ejemplo a la derecha: unas barras falsas pintadas con el estilo activo, que cambian al momento.
local function BuildSample(panel)
  local section = Widgets.Section(panel, L.APPEARANCE_SAMPLE, SAMPLE_WIDTH)
  section.frame:SetPoint("TOPLEFT", panel, "TOPLEFT", SAMPLE_X, 0)
  section.frame:SetHeight(300)
  local holder = CreateFrame("Frame", nil, section.frame)
  holder:SetPoint("TOP", section.frame, "TOP", 0, -36)
  holder:SetSize(SAMPLE_WIDTH - 2 * Widgets.SECTION_PADDING, 240)
  local note = Widgets.Label(section.frame, L.APPEARANCE_SAMPLE_NOTE, "GameFontDisableSmall")
  note:SetPoint("BOTTOMLEFT", section.frame, "BOTTOMLEFT", Widgets.SECTION_PADDING, 10)
  note:SetPoint("RIGHT", section.frame, "RIGHT", -Widgets.SECTION_PADDING, 0)
  note:SetWordWrap(true)
  TabAppearance.sample = { section = section, holder = holder, frames = {} }
end

-- Repinta la vista de ejemplo; las barras anchas se encogen para caber en el recuadro.
function TabAppearance.PaintSample()
  local sample = TabAppearance.sample
  if not sample or not ns.Preview or not ns.UnitButton then
    return
  end
  local style = Style()
  local layout = style.layout
  local available = SAMPLE_WIDTH - 2 * Widgets.SECTION_PADDING - 8
  local scale = math.min(1, available / layout.width)
  sample.holder:SetScale(scale)
  local members = ns.Preview.SAMPLE_MEMBERS
  local total = #members * layout.height + (#members - 1) * SAMPLE_GAP
  sample.holder:SetSize(layout.width, total)
  for position, member in ipairs(members) do
    local frame = sample.frames[position]
    if not frame then
      frame = CreateFrame("Frame", nil, sample.holder)
      ns.UnitButton:BuildVisuals(frame)
      sample.frames[position] = frame
    end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", sample.holder, "TOPLEFT", 0, -(position - 1) * (layout.height + SAMPLE_GAP))
    ns.Preview:Paint(frame, member, style)
    frame:SetAlpha(1)
  end
  sample.section.frame:SetHeight(36 + total * scale + 50)
end

function TabAppearance.SelectPage(key)
  TabAppearance.page = key
  for pageKey, page in pairs(TabAppearance.pages) do
    page:SetShown(pageKey == key)
  end
  if TabAppearance.pageSelector then
    TabAppearance.pageSelector:Refresh()
  end
  TabAppearance.Refresh()
end

-- Abre esta pestaña en la página Auras con un grupo elegido (desde las pestañas Auras y Debuffs).
function TabAppearance.OpenAuras(group)
  TabAppearance.auraGroup = group or TabAppearance.auraGroup
  TabAppearance.page = "auras"
  ns.Config:SelectTab("appearance")
  TabAppearance.SelectPage("auras")
end

function TabAppearance.Build(panel)
  TabAppearance.pageSelector = Widgets.Segmented(panel, TabAppearance.PAGES, 492, function()
    return TabAppearance.page
  end, TabAppearance.SelectPage)
  TabAppearance.pageSelector:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
  local builders = { bar = BuildBarPage, text = BuildTextPage, icons = BuildIconsPage, auras = BuildAurasPage }
  TabAppearance.pages, TabAppearance.stacks = {}, {}
  for _, entry in ipairs(TabAppearance.PAGES) do
    local page = CreateFrame("Frame", nil, panel)
    page:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, PAGE_TOP)
    page:SetPoint("BOTTOMRIGHT", panel, "BOTTOMLEFT", SAMPLE_X - 8, 0)
    for _, column in ipairs(builders[entry.value](page)) do
      TabAppearance.stacks[#TabAppearance.stacks + 1] = column
    end
    TabAppearance.pages[entry.value] = page
  end
  BuildSample(panel)
  TabAppearance.SelectPage(TabAppearance.page)
end

function TabAppearance.Refresh()
  if TabAppearance.pageSelector then
    TabAppearance.pageSelector:Refresh()
  end
  for _, stack in ipairs(TabAppearance.stacks) do
    stack:Refresh()
  end
  TabAppearance.PaintSample()
end

ns.Config:RegisterTab("appearance", L.TAB_APPEARANCE, TabAppearance.Build, TabAppearance.Refresh)
