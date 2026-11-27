-- Controles del panel hechos con piezas básicas (Button, CheckButton, Slider, EditBox) y MenuUtil para menús.
-- Cada control expone :Refresh() para releer el valor del perfil activo.
-- Todos comparten un tema plano y oscuro con un acento verde: superficies con borde de 1 px, botones
-- que se iluminan al pasar el ratón, casillas cuadradas y deslizadores con la parte llena en color.
local _, ns = ...
local L = ns.L

local Widgets = {}
ns.Widgets = Widgets

local THEME = {
  window = { 0.055, 0.06, 0.075, 0.97 },
  sidebar = { 0.075, 0.082, 0.1, 1 },
  card = { 0.095, 0.103, 0.125, 0.96 },
  control = { 0.13, 0.14, 0.17, 1 },
  controlHover = { 0.17, 0.185, 0.22, 1 },
  border = { 0.2, 0.22, 0.27, 1 },
  accent = { 0.27, 0.84, 0.56, 1 },
  accentSoft = { 0.27, 0.84, 0.56, 0.16 },
  hover = { 1, 1, 1, 0.05 },
  danger = { 0.92, 0.36, 0.36, 1 },
  badge = { 1, 0.6, 0, 1 },
  text = { 0.93, 0.94, 0.96, 1 },
  heading = { 0.45, 0.9, 0.66, 1 },
  muted = { 0.62, 0.66, 0.72, 1 },
  dim = { 0.45, 0.48, 0.53, 1 },
  section = { 1, 1, 1, 0.025 },
  sectionBorder = { 0.2, 0.22, 0.27, 0.7 },
}
Widgets.THEME = THEME

local WHITE = "Interface\\Buttons\\WHITE8X8"
local FLAT_BACKDROP = {
  bgFile = WHITE, edgeFile = WHITE, edgeSize = 1,
  insets = { left = 1, right = 1, top = 1, bottom = 1 },
}
Widgets.FLAT_BACKDROP = FLAT_BACKDROP

-- Color del tema como cuatro números, para SetColorTexture, SetTextColor y compañía.
function Widgets.ColorValues(color)
  return color[1], color[2], color[3], color[4]
end
local ColorValues = Widgets.ColorValues

-- Superficie plana: fondo y borde de 1 px. El marco debe heredar de BackdropTemplate.
function Widgets.Surface(frame, fill, border)
  frame:SetBackdrop(FLAT_BACKDROP)
  frame:SetBackdropColor(ColorValues(fill or THEME.window))
  frame:SetBackdropBorderColor(ColorValues(border or THEME.border))
end

-- Línea de color sólido (separadores y la franja de acento de las ventanas).
function Widgets.Line(parent, color, layer)
  local line = parent:CreateTexture(nil, layer or "BORDER")
  line:SetColorTexture(ColorValues(color or THEME.border))
  return line
end

-- Franja de acento de 2 px pegada al borde de arriba de una ventana.
function Widgets.AccentStrip(frame)
  local strip = Widgets.Line(frame, THEME.accent, "ARTWORK")
  strip:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
  strip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
  strip:SetHeight(2)
  return strip
end

Widgets.MAX_LIST_ROWS = 12

StaticPopupDialogs.HEALSILUS_CONFIRM = {
  text = "%s",
  button1 = YES,
  button2 = NO,
  OnAccept = function(_, action)
    action()
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

function Widgets.SectionGetter(section, key)
  return function()
    return ns.Profiles.active[section][key]
  end
end

function Widgets.SectionSetter(section, key, afterChange)
  return function(value)
    ns.Profiles.active[section][key] = value
    if afterChange then
      afterChange(value)
    end
    ns.Config:Changed(section)
  end
end

-- Controles que editan el estilo activo: StyleGetter("text", "name", "size") lee style.text.name.size.
local function StyleTable(path, depth)
  local current = ns.Styles.active
  for position = 1, depth do
    current = current[path[position]]
  end
  return current
end

function Widgets.StyleGetter(...)
  local path = { ... }
  return function()
    return StyleTable(path, #path - 1)[path[#path]]
  end
end

function Widgets.StyleSetter(...)
  local path = { ... }
  return function(value)
    StyleTable(path, #path - 1)[path[#path]] = value
    ns.Config:Changed("style")
  end
end

-- Cada plantilla de texto tiene su papel en el tema: GameFontNormal son los títulos de sección (acento),
-- las pequeñas son etiquetas y ayudas (gris), GameFontDisableSmall son notas (gris oscuro).
local LABEL_COLORS = {
  GameFontNormal = THEME.heading,
  GameFontNormalSmall = THEME.muted,
  GameFontHighlightSmall = THEME.muted,
  GameFontDisableSmall = THEME.dim,
  GameFontHighlight = THEME.text,
  GameFontNormalLarge = THEME.text,
}

function Widgets.Label(parent, text, template)
  local chosen = template or "GameFontHighlight"
  local label = parent:CreateFontString(nil, "OVERLAY", chosen)
  label:SetText(text)
  label:SetJustifyH("LEFT")
  local color = LABEL_COLORS[chosen]
  if color then
    label:SetTextColor(ColorValues(color))
  end
  return label
end

-- Variantes de botón: normal (gris), primary (verde, la acción principal) y danger (rojo).
local BUTTON_VARIANTS = {
  normal = { fill = THEME.control, hover = THEME.controlHover, border = THEME.border, hoverBorder = THEME.accent },
  primary = {
    fill = { 0.13, 0.38, 0.26, 1 }, hover = { 0.17, 0.48, 0.33, 1 },
    border = THEME.accent, hoverBorder = { 0.6, 1, 0.78, 1 },
  },
  danger = {
    fill = { 0.36, 0.12, 0.12, 1 }, hover = { 0.48, 0.16, 0.16, 1 },
    border = THEME.danger, hoverBorder = { 1, 0.6, 0.6, 1 },
  },
}
Widgets.BUTTON_VARIANTS = BUTTON_VARIANTS

local function PaintButton(button)
  local colors = BUTTON_VARIANTS[button.variant] or BUTTON_VARIANTS.normal
  local lit = button.hovered == true
  button:SetBackdropColor(ColorValues(lit and colors.hover or colors.fill))
  button:SetBackdropBorderColor(ColorValues(lit and colors.hoverBorder or colors.border))
end

-- Pinta de nuevo el borde y el fondo cuando el ratón entra o sale.
local function TrackHover(frame, paint)
  frame:HookScript("OnEnter", function(self)
    self.hovered = true
    paint(self)
  end)
  frame:HookScript("OnLeave", function(self)
    self.hovered = false
    paint(self)
  end)
end

function Widgets.Button(parent, text, width, onClick)
  local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
  button:SetSize(width, 22)
  button:SetBackdrop(FLAT_BACKDROP)
  local caption = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  caption:SetPoint("LEFT", button, "LEFT", 6, 0)
  caption:SetPoint("RIGHT", button, "RIGHT", -6, 0)
  caption:SetWordWrap(false)
  button:SetFontString(caption)
  button:SetNormalFontObject("GameFontHighlightSmall")
  button:SetHighlightFontObject("GameFontHighlightSmall")
  button:SetDisabledFontObject("GameFontDisableSmall")
  button:SetPushedTextOffset(0, -1)
  button:SetText(text)
  button.caption = caption
  button.variant = "normal"
  function button:SetVariant(variant)
    self.variant = variant
    PaintButton(self)
  end
  TrackHover(button, PaintButton)
  button:SetScript("OnClick", onClick)
  PaintButton(button)
  return button
end

local function PaintCheckbox(checkbox)
  checkbox:SetBackdropBorderColor(ColorValues(checkbox.hovered and THEME.accent or THEME.border))
end

-- Casilla cuadrada con un relleno de acento cuando está marcada; pulsar el texto también la cambia.
function Widgets.Checkbox(parent, text, getValue, setValue)
  local checkbox = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
  checkbox:SetSize(18, 18)
  Widgets.Surface(checkbox, THEME.control, THEME.border)
  local mark = checkbox:CreateTexture(nil, "ARTWORK")
  mark:SetPoint("TOPLEFT", checkbox, "TOPLEFT", 4, -4)
  mark:SetPoint("BOTTOMRIGHT", checkbox, "BOTTOMRIGHT", -4, 4)
  mark:SetColorTexture(ColorValues(THEME.accent))
  checkbox:SetCheckedTexture(mark)
  local label = Widgets.Label(parent, text)
  label:SetPoint("LEFT", checkbox, "RIGHT", 8, 0)
  checkbox.label = label
  local labelWidth = label:GetStringWidth()
  if type(labelWidth) == "number" then
    checkbox:SetHitRectInsets(0, -(labelWidth + 8), 0, 0)
  end
  TrackHover(checkbox, PaintCheckbox)
  checkbox:SetScript("OnClick", function(self)
    setValue(self:GetChecked() == true)
  end)
  checkbox.Refresh = function(self)
    self:SetChecked(getValue() == true)
  end
  return checkbox
end

local function PaintSidebarTab(tab)
  local background = THEME.hover
  if tab.selected then
    background = THEME.accentSoft
  end
  tab.background:SetColorTexture(ColorValues(background))
  tab.background:SetShown(tab.selected == true or tab.hovered == true)
  tab.marker:SetShown(tab.selected == true)
  tab.text:SetTextColor(ColorValues((tab.selected or tab.hovered) and THEME.text or THEME.muted))
  local iconColor = THEME.muted
  if tab.selected then
    iconColor = THEME.accent
  elseif tab.hovered then
    iconColor = THEME.text
  end
  tab.icon:SetVertexColor(ColorValues(iconColor))
end

-- Pestaña de la barra lateral: icono (blanco, de Media/Icons, que se tiñe) y nombre; la elegida lleva
-- fondo verde suave, una raya de acento y el icono en verde.
function Widgets.SidebarTab(parent, text, icon, width, onClick)
  local tab = CreateFrame("Button", nil, parent)
  tab:SetSize(width, 32)
  tab.background = tab:CreateTexture(nil, "BACKGROUND")
  tab.background:SetAllPoints(tab)
  tab.marker = Widgets.Line(tab, THEME.accent, "ARTWORK")
  tab.marker:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, 0)
  tab.marker:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 0)
  tab.marker:SetWidth(3)
  tab.icon = tab:CreateTexture(nil, "ARTWORK")
  tab.icon:SetSize(18, 18)
  tab.icon:SetPoint("LEFT", tab, "LEFT", 12, 0)
  tab.icon:SetTexture(icon)
  tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  tab.text:SetPoint("LEFT", tab.icon, "RIGHT", 10, 0)
  tab.text:SetPoint("RIGHT", tab, "RIGHT", -6, 0)
  tab.text:SetJustifyH("LEFT")
  tab.text:SetWordWrap(false)
  tab.text:SetText(text)
  tab.selected = false
  function tab:SetSelected(selected)
    self.selected = selected == true
    PaintSidebarTab(self)
  end
  TrackHover(tab, PaintSidebarTab)
  tab:SetScript("OnClick", onClick)
  PaintSidebarTab(tab)
  return tab
end

local function RoundToStep(value, step)
  return tonumber(string.format("%.2f", math.floor(value / step + 0.5) * step))
end

function Widgets.Slider(parent, text, minimum, maximum, step, getValue, setValue, format)
  local container = CreateFrame("Frame", nil, parent)
  container:SetSize(220, 40)
  local label = Widgets.Label(container, text, "GameFontNormalSmall")
  label:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
  local valueText = Widgets.Label(container, "", "GameFontHighlightSmall")
  valueText:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
  valueText:SetTextColor(ColorValues(THEME.heading))
  local slider = CreateFrame("Slider", nil, container)
  slider:SetOrientation("HORIZONTAL")
  slider:SetSize(220, 16)
  slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
  -- Riel gris, tramo lleno en acento hasta el tirador y tirador claro.
  local track = slider:CreateTexture(nil, "BACKGROUND")
  track:SetColorTexture(ColorValues(THEME.control))
  track:SetPoint("LEFT", slider, "LEFT", 0, 0)
  track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
  track:SetHeight(4)
  local thumb = slider:CreateTexture(nil, "OVERLAY")
  thumb:SetColorTexture(ColorValues(THEME.text))
  thumb:SetSize(8, 14)
  slider:SetThumbTexture(thumb)
  local filled = slider:CreateTexture(nil, "ARTWORK")
  filled:SetColorTexture(ColorValues(THEME.accent))
  filled:SetPoint("LEFT", track, "LEFT", 0, 0)
  filled:SetPoint("RIGHT", thumb, "CENTER", 0, 0)
  filled:SetHeight(4)
  slider:SetMinMaxValues(minimum, maximum)
  slider:SetValueStep(step)
  slider:SetObeyStepOnDrag(true)
  slider:EnableMouseWheel(true)
  local updating = false
  local shownFormat = format or "%d"
  slider:SetScript("OnValueChanged", function(_, value)
    if updating then
      return
    end
    local rounded = RoundToStep(value, step)
    valueText:SetText(string.format(shownFormat, rounded))
    setValue(rounded)
  end)
  slider:SetScript("OnMouseWheel", function(self, delta)
    self:SetValue(self:GetValue() + delta * step)
  end)
  container.Refresh = function()
    updating = true
    local current = getValue()
    slider:SetValue(current)
    valueText:SetText(string.format(shownFormat, current))
    updating = false
  end
  container.slider = slider
  return container
end

-- Abre un menú contextual; devuelve false (y avisa) si el cliente no tiene MenuUtil.
function Widgets.OpenMenu(owner, build)
  if not MenuUtil or not MenuUtil.CreateContextMenu then
    ns.Print(L.MENU_UNAVAILABLE)
    return false
  end
  MenuUtil.CreateContextMenu(owner, function(_, root)
    build(root)
  end)
  return true
end

function Widgets.OpenSpellMenu(owner, onPick)
  Widgets.OpenMenu(owner, function(root)
    if root.SetScrollMode then
      root:SetScrollMode(400)
    end
    for _, entry in ipairs(ns.Spells:KnownList()) do
      root:CreateButton(entry.name, function()
        onPick(entry)
      end)
    end
  end)
end

-- options: { { value = ..., label = ... } }. Sin MenuUtil, cada clic pasa a la opción siguiente.
function Widgets.Dropdown(parent, text, width, getOptions, getValue, setValue)
  local container = CreateFrame("Frame", nil, parent)
  container:SetSize(width, 44)
  local label = Widgets.Label(container, text, "GameFontNormalSmall")
  label:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
  local button = Widgets.Button(container, "", width, function(self)
    local options = getOptions()
    if MenuUtil and MenuUtil.CreateContextMenu then
      MenuUtil.CreateContextMenu(self, function(_, root)
        for _, option in ipairs(options) do
          root:CreateRadio(option.label, function()
            return getValue() == option.value
          end, function()
            setValue(option.value)
            container:Refresh()
          end)
        end
      end)
      return
    end
    local current = getValue()
    local nextOption = options[1]
    for position, option in ipairs(options) do
      if option.value == current then
        nextOption = options[position % #options + 1]
      end
    end
    if nextOption then
      setValue(nextOption.value)
      container:Refresh()
    end
  end)
  button:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
  -- Texto a la izquierda y una flecha hacia abajo a la derecha, como un desplegable.
  button.caption:ClearAllPoints()
  button.caption:SetPoint("LEFT", button, "LEFT", 8, 0)
  button.caption:SetPoint("RIGHT", button, "RIGHT", -22, 0)
  button.caption:SetJustifyH("LEFT")
  local arrow = button:CreateTexture(nil, "OVERLAY")
  arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
  arrow:SetSize(12, 12)
  arrow:SetPoint("RIGHT", button, "RIGHT", -6, 0)
  arrow:SetRotation(-math.pi / 2)
  arrow:SetVertexColor(ColorValues(THEME.muted))
  container.Refresh = function()
    local current = getValue()
    local shown = tostring(current)
    for _, option in ipairs(getOptions()) do
      if option.value == current then
        shown = option.label
      end
    end
    button:SetText(shown)
  end
  return container
end

-- Columna de controles: cada Add coloca el control debajo del anterior.
function Widgets.Stack(parent, x, y)
  local stack = { parent = parent, x = x, y = y, controls = {} }
  function stack:Add(control, height)
    control:SetPoint("TOPLEFT", self.parent, "TOPLEFT", self.x, self.y)
    self.y = self.y - height
    self.controls[#self.controls + 1] = control
    return control
  end
  function stack:Refresh()
    for _, control in ipairs(self.controls) do
      if control.Refresh then
        control:Refresh()
      end
    end
  end
  return stack
end

-- Grupo de opciones con título: un recuadro suave que crece con lo que se le añade. Los controles se
-- crean con section.frame como padre y se colocan uno debajo de otro con section:Add(control, alto).
Widgets.SECTION_WIDTH = 240
Widgets.SECTION_PADDING = 10
local SECTION_TITLE_HEIGHT = 30

function Widgets.Section(parent, title, width)
  local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  frame:SetSize(width or Widgets.SECTION_WIDTH, SECTION_TITLE_HEIGHT)
  Widgets.Surface(frame, THEME.section, THEME.sectionBorder)
  local heading = Widgets.Label(frame, title, "GameFontNormal")
  heading:SetPoint("TOPLEFT", frame, "TOPLEFT", Widgets.SECTION_PADDING, -10)
  local section = { frame = frame, heading = heading, y = -SECTION_TITLE_HEIGHT, controls = {} }
  function section:Add(control, height, indent)
    control:SetPoint("TOPLEFT", self.frame, "TOPLEFT", Widgets.SECTION_PADDING + (indent or 0), self.y)
    self.y = self.y - height
    self.frame:SetHeight(-self.y + 4)
    self.controls[#self.controls + 1] = control
    return control
  end
  function section:Refresh()
    for _, control in ipairs(self.controls) do
      if control.Refresh then
        control:Refresh()
      end
    end
  end
  return section
end

-- Columna de secciones: cada Add coloca la sección debajo de la anterior con gap de separación.
function Widgets.Column(parent, x, y, gap)
  local column = { parent = parent, x = x, y = y, gap = gap or 12, sections = {} }
  function column:Add(section)
    section.frame:SetPoint("TOPLEFT", self.parent, "TOPLEFT", self.x, self.y)
    self.sections[#self.sections + 1] = section
    self.last = section
    return section
  end
  -- Coloca la sección siguiente debajo de la última (las alturas crecen al añadir controles).
  function column:Next(section)
    if self.last then
      section.frame:SetPoint("TOPLEFT", self.last.frame, "BOTTOMLEFT", 0, -self.gap)
      self.sections[#self.sections + 1] = section
      self.last = section
      return section
    end
    return self:Add(section)
  end
  function column:Refresh()
    for _, section in ipairs(self.sections) do
      section:Refresh()
    end
  end
  return column
end

-- Botones unidos para elegir una opción (subpáginas o el texto a editar). options: { { value, label } }.
function Widgets.Segmented(parent, options, width, getValue, setValue)
  local container = CreateFrame("Frame", nil, parent)
  local count = #options
  local buttonWidth = math.floor((width - (count - 1) * 4) / count)
  container:SetSize(width, 24)
  container.buttons = {}
  for position, option in ipairs(options) do
    local button = Widgets.Button(container, option.label, buttonWidth, function()
      setValue(option.value)
      container:Refresh()
    end)
    button:SetHeight(24)
    button:SetPoint("TOPLEFT", container, "TOPLEFT", (position - 1) * (buttonWidth + 4), 0)
    button.value = option.value
    container.buttons[position] = button
  end
  container.Refresh = function(self)
    local current = getValue()
    for _, button in ipairs(self.buttons) do
      button:SetVariant(button.value == current and "primary" or "normal")
    end
  end
  return container
end

-- Selector de posición: una barra en miniatura con nueve puntos (esquinas, lados y centro). Pulsar uno
-- lo elige; a la derecha se lee su nombre. options: { { value = "TOPLEFT", label = ... }, ... } en orden
-- de lectura (fila de arriba, centro y abajo).
local PICKER_COLUMNS = { LEFT = 0, CENTER = 1, RIGHT = 2 }
local PICKER_ROWS = { TOP = 0, CENTER = 1, BOTTOM = 2 }
local PICKER_WIDTH, PICKER_HEIGHT, PICKER_CELL = 96, 42, 10

local function PickerCell(point)
  local column = string.find(point, "LEFT") and "LEFT" or string.find(point, "RIGHT") and "RIGHT" or "CENTER"
  local row = string.find(point, "TOP") and "TOP" or string.find(point, "BOTTOM") and "BOTTOM" or "CENTER"
  return PICKER_COLUMNS[column], PICKER_ROWS[row]
end

local function PaintPickerCell(cell)
  local color = THEME.control
  if cell.selected then
    color = THEME.accent
  elseif cell.hovered then
    color = THEME.muted
  end
  cell:SetBackdropColor(ColorValues(color))
  cell:SetBackdropBorderColor(ColorValues(cell.selected and THEME.accent or THEME.border))
end

function Widgets.PointPicker(parent, text, options, getValue, setValue)
  local container = CreateFrame("Frame", nil, parent)
  container:SetSize(220, PICKER_HEIGHT + 18)
  local label = Widgets.Label(container, text, "GameFontNormalSmall")
  label:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
  local board = CreateFrame("Frame", nil, container, "BackdropTemplate")
  board:SetSize(PICKER_WIDTH, PICKER_HEIGHT)
  board:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
  Widgets.Surface(board, { 0.2, 0.42, 0.3, 0.55 }, THEME.border)
  local chosen = Widgets.Label(container, "", "GameFontHighlight")
  chosen:SetPoint("LEFT", board, "RIGHT", 12, 0)
  container.cells = {}
  local stepX = (PICKER_WIDTH - PICKER_CELL - 8) / 2
  local stepY = (PICKER_HEIGHT - PICKER_CELL - 8) / 2
  for _, option in ipairs(options) do
    local cell = CreateFrame("Button", nil, board, "BackdropTemplate")
    cell:SetSize(PICKER_CELL, PICKER_CELL)
    cell:SetBackdrop(FLAT_BACKDROP)
    local column, row = PickerCell(option.value)
    cell:SetPoint("TOPLEFT", board, "TOPLEFT", 4 + column * stepX, -(4 + row * stepY))
    cell.value, cell.label = option.value, option.label
    TrackHover(cell, PaintPickerCell)
    cell:SetScript("OnClick", function()
      setValue(option.value)
      container:Refresh()
    end)
    container.cells[#container.cells + 1] = cell
  end
  container.Refresh = function(self)
    local current = getValue()
    for _, cell in ipairs(self.cells) do
      cell.selected = cell.value == current
      PaintPickerCell(cell)
      if cell.selected then
        chosen:SetText(cell.label)
      end
    end
  end
  return container
end

function Widgets.SpellRow(parent, width)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(width, 24)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(18, 18)
  row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
  row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.text:SetJustifyH("LEFT")
  row.remove = Widgets.Button(row, L.REMOVE, 70, function()
    if row.onRemove then
      row.onRemove()
    end
  end)
  row.remove:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  return row
end

-- Reutiliza filas: Render(items, pintar, x, y, alto de fila) muestra tantas filas como elementos.
function Widgets.RowPool(parent, createRow)
  local pool = { rows = {} }
  function pool:Render(items, paintRow, x, top, rowHeight)
    for position, item in ipairs(items) do
      local row = self.rows[position]
      if not row then
        row = createRow(parent)
        self.rows[position] = row
      end
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", parent, "TOPLEFT", x, top - (position - 1) * rowHeight)
      paintRow(row, item)
      row:Show()
    end
    for position = #items + 1, #self.rows do
      self.rows[position]:Hide()
    end
  end
  return pool
end

-- Agrupa cambios rápidos (selector de color, deslizadores) en uno solo, para no reconstruir marcos
-- y auras en cada movimiento. La última acción de cada clave gana.
local DEBOUNCE_DELAY = 0.3
local pendingActions = {}
local debounceScheduled = false

function Widgets.Debounce(key, action)
  pendingActions[key] = action
  if debounceScheduled then
    return
  end
  debounceScheduled = true
  C_Timer.After(DEBOUNCE_DELAY, function()
    debounceScheduled = false
    local actions = pendingActions
    pendingActions = {}
    for _, run in pairs(actions) do
      run()
    end
  end)
end

-- Abre el selector de color del juego; Cancelar devuelve el color que había.
function Widgets.OpenColorPicker(color, setColor)
  if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then
    ns.Print(L.COLOR_PICKER_UNAVAILABLE)
    return
  end
  local previous = { r = color.r, g = color.g, b = color.b }
  ColorPickerFrame:SetupColorPickerAndShow({
    r = color.r, g = color.g, b = color.b, hasOpacity = false,
    swatchFunc = function()
      local red, green, blue = ColorPickerFrame:GetColorRGB()
      setColor(red, green, blue)
    end,
    cancelFunc = function()
      setColor(previous.r, previous.g, previous.b)
    end,
  })
end

-- Cuadrado de color: muestra el color actual y al pulsarlo abre el selector.
function Widgets.ColorSwatch(parent, getColor, setColor)
  local swatch = CreateFrame("Button", nil, parent, "BackdropTemplate")
  swatch:SetSize(22, 22)
  swatch:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 })
  local function PaintSwatch(self)
    self:SetBackdropBorderColor(ColorValues(self.hovered and THEME.accent or THEME.muted))
  end
  PaintSwatch(swatch)
  TrackHover(swatch, PaintSwatch)
  swatch.fill = swatch:CreateTexture(nil, "ARTWORK")
  swatch.fill:SetPoint("TOPLEFT", swatch, "TOPLEFT", 2, -2)
  swatch.fill:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -2, 2)
  swatch.Refresh = function(self)
    local color = getColor()
    self.fill:SetColorTexture(color.r, color.g, color.b, 1)
  end
  swatch:SetScript("OnClick", function(self)
    Widgets.OpenColorPicker(getColor(), function(red, green, blue)
      self.fill:SetColorTexture(red, green, blue, 1)
      setColor(red, green, blue)
    end)
  end)
  return swatch
end

local function BuildTextDialog()
  local dialog = CreateFrame("Frame", "HealsilusTextDialog", UIParent, "BackdropTemplate")
  dialog:SetSize(480, 320)
  dialog:SetPoint("CENTER")
  dialog:SetFrameStrata("FULLSCREEN_DIALOG")
  Widgets.Surface(dialog, THEME.window, THEME.border)
  Widgets.AccentStrip(dialog)
  dialog:EnableMouse(true)
  dialog:Hide()
  dialog.title = Widgets.Label(dialog, "", "GameFontNormal")
  dialog.title:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, -18)
  -- Fondo más claro detrás del texto: una textura del propio diálogo, siempre por debajo del cuadro de texto.
  local field = Widgets.Line(dialog, THEME.card, "BORDER")
  field:SetPoint("TOPLEFT", dialog, "TOPLEFT", 14, -36)
  field:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -14, 46)
  local scroll = CreateFrame("ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, -42)
  scroll:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -38, 52)
  local editBox = CreateFrame("EditBox", nil, scroll)
  editBox:SetMultiLine(true)
  editBox:SetAutoFocus(false)
  editBox:SetFontObject(ChatFontNormal)
  editBox:SetWidth(410)
  editBox:SetScript("OnEscapePressed", function()
    dialog:Hide()
  end)
  scroll:SetScrollChild(editBox)
  dialog.editBox = editBox
  dialog.accept = Widgets.Button(dialog, L.ACCEPT, 120, function()
    local handler = dialog.onAccept
    dialog:Hide()
    if handler then
      handler(editBox:GetText())
    end
  end)
  dialog.accept:SetPoint("BOTTOMRIGHT", dialog, "BOTTOM", -4, 14)
  dialog.accept:SetVariant("primary")
  local close = Widgets.Button(dialog, L.CLOSE, 120, function()
    dialog:Hide()
  end)
  close:SetPoint("BOTTOMLEFT", dialog, "BOTTOM", 4, 14)
  table.insert(UISpecialFrames, "HealsilusTextDialog")
  return dialog
end

-- Ventana de texto multilínea: macros, exportar (solo copiar) e importar.
function Widgets.TextDialog(title, initialText, acceptLabel, onAccept)
  local dialog = Widgets.textDialog
  if not dialog then
    dialog = BuildTextDialog()
    Widgets.textDialog = dialog
  end
  dialog.title:SetText(title)
  dialog.editBox:SetText(initialText or "")
  dialog.onAccept = onAccept
  dialog.accept:SetText(acceptLabel or L.ACCEPT)
  dialog.accept:SetShown(onAccept ~= nil)
  dialog:Show()
  dialog.editBox:SetFocus()
  dialog.editBox:HighlightText()
end

function Widgets.Confirm(message, onAccept)
  StaticPopup_Show("HEALSILUS_CONFIRM", message, nil, onAccept)
end
