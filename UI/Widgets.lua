-- Controles del panel hechos con piezas básicas (Button, CheckButton, Slider, EditBox) y MenuUtil para menús.
-- Cada control expone :Refresh() para releer el valor del perfil activo.
local _, ns = ...
local L = ns.L

local Widgets = {}
ns.Widgets = Widgets

local DIALOG_BACKDROP = {
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true, tileSize = 32, edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 },
}
Widgets.DIALOG_BACKDROP = DIALOG_BACKDROP

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

function Widgets.Label(parent, text, template)
  local label = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
  label:SetText(text)
  label:SetJustifyH("LEFT")
  return label
end

function Widgets.Button(parent, text, width, onClick)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetSize(width, 22)
  button:SetText(text)
  button:SetScript("OnClick", onClick)
  return button
end

function Widgets.Checkbox(parent, text, getValue, setValue)
  local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  checkbox:SetSize(24, 24)
  local label = Widgets.Label(parent, text)
  label:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
  checkbox.label = label
  checkbox:SetScript("OnClick", function(self)
    setValue(self:GetChecked() == true)
  end)
  checkbox.Refresh = function(self)
    self:SetChecked(getValue() == true)
  end
  return checkbox
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
  local slider = CreateFrame("Slider", nil, container)
  slider:SetOrientation("HORIZONTAL")
  slider:SetSize(220, 16)
  slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
  local track = slider:CreateTexture(nil, "BACKGROUND")
  track:SetColorTexture(0.2, 0.2, 0.2, 0.9)
  track:SetPoint("LEFT", slider, "LEFT", 0, 0)
  track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
  track:SetHeight(4)
  slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
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
  swatch:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  swatch:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)
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
  dialog:SetBackdrop(DIALOG_BACKDROP)
  dialog:EnableMouse(true)
  dialog:Hide()
  dialog.title = Widgets.Label(dialog, "", "GameFontNormal")
  dialog.title:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, -18)
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
  dialog.accept:SetPoint("BOTTOMRIGHT", dialog, "BOTTOM", -4, 18)
  local close = Widgets.Button(dialog, L.CLOSE, 120, function()
    dialog:Hide()
  end)
  close:SetPoint("BOTTOMLEFT", dialog, "BOTTOM", 4, 18)
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
