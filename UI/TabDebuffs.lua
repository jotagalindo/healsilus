-- Pestaña Debuffs: qué debuffs se ven, el color de cada tipo (anillo de la barra y borde del icono)
-- y con qué clic quitas cada tipo. Quitar un debuff siempre es un clic tuyo con una asignación fija.
local _, ns = ...
local L = ns.L
local Widgets = ns.Widgets

local TabDebuffs = { stack = nil, rows = {} }
ns.TabDebuffs = TabDebuffs

local ROWS_TOP, ROW_HEIGHT, COLOR_APPLY_DELAY = -150, 56, 0.4

-- Hechizo y clic elegidos en cada fila antes de pulsar "Asignar".
TabDebuffs.choices = {}

TabDebuffs.CHECKBOXES = {
  { key = "debuffsEnabled", label = L.AURAS_DEBUFFS },
  { key = "debuffsDispellableOnly", label = L.AURAS_DISPELLABLE },
}

TabDebuffs.SLIDERS = {
  { key = "debuffsMax", label = L.AURAS_DEBUFFS_MAX },
}

local TYPE_LABELS = {
  Magic = L.DISPEL_MAGIC,
  Curse = L.DISPEL_CURSE,
  Poison = L.DISPEL_POISON,
  Disease = L.DISPEL_DISEASE,
}

-- Colores, forma del aviso y esquina de los iconos: del estilo activo.
local function Look()
  return ns.Styles.active.auras
end

TabDebuffs.MODE_OPTIONS = {
  { value = "RING", label = L.DISPEL_MODE_RING },
  { value = "BAR", label = L.DISPEL_MODE_BAR },
  { value = "BOTH", label = L.DISPEL_MODE_BOTH },
}

local function DescribeClicks(keys, bindings)
  if #keys == 0 then
    return L.DEBUFFS_NO_CLICK
  end
  local parts = {}
  for _, key in ipairs(keys) do
    local spellName = ns.ClickCast.ResolveSpell(bindings[key]) or ns.Spells:GetName(bindings[key].spellID) or "?"
    parts[#parts + 1] = ns.TabClicks.KeyLabel(key) .. " · " .. spellName
  end
  return table.concat(parts, ", ")
end

-- Una fila por tipo, en el orden de Database.DISPEL_TYPES.
function TabDebuffs.Rows()
  local bindings = ns.Profiles.active.bindings
  local clicks = ns.Dispels.ClicksFor(bindings)
  local rows = {}
  for _, dispelType in ipairs(ns.Database.DISPEL_TYPES) do
    rows[#rows + 1] = {
      dispelType = dispelType,
      label = TYPE_LABELS[dispelType],
      color = Look().dispelColors[dispelType],
      clicks = DescribeClicks(clicks[dispelType], bindings),
      spells = ns.Dispels.KnownSpellsFor(dispelType),
      suggestedKey = clicks[dispelType][1] or ns.Dispels.SuggestKey(bindings),
    }
  end
  return rows
end

-- Pone el hechizo elegido en el clic elegido (como los "Cure spells" de HealBot). Devuelve true si lo hizo.
function TabDebuffs.Assign(spellID, key)
  if not spellID or not key then
    ns.Print(L.DEBUFFS_PICK_FIRST)
    return false
  end
  ns.Dispels.Assign(ns.Profiles.active.bindings, key, spellID)
  ns.Config:Changed("bindings")
  ns.Print(string.format(L.DEBUFFS_ASSIGNED, ns.Spells:GetName(spellID) or "?", ns.TabClicks.KeyLabel(key)))
  return true
end

function TabDebuffs.SetColor(dispelType, red, green, blue)
  Look().dispelColors[dispelType] = { r = red, g = green, b = blue }
  ns.Config:Changed("style")
end

function TabDebuffs.ResetColors()
  Look().dispelColors = ns.Database.DefaultDispelColors()
  ns.Config:Changed("style")
end

-- El selector avisa en cada movimiento: se espera a que pare para no reconstruir las auras sin parar.
local pendingColors = {}
local applyScheduled = false
local function ScheduleColor(dispelType, red, green, blue)
  pendingColors[dispelType] = { red, green, blue }
  if applyScheduled then
    return
  end
  applyScheduled = true
  C_Timer.After(COLOR_APPLY_DELAY, function()
    applyScheduled = false
    local colors = pendingColors
    pendingColors = {}
    for pendingType, color in pairs(colors) do
      TabDebuffs.SetColor(pendingType, color[1], color[2], color[3])
    end
  end)
end

local function Choice(dispelType)
  local choice = TabDebuffs.choices[dispelType]
  if not choice then
    choice = {}
    TabDebuffs.choices[dispelType] = choice
  end
  return choice
end

local function OpenSpellChoices(owner, dispelType, spells)
  Widgets.OpenMenu(owner, function(root)
    if #spells == 0 then
      root:CreateTitle(L.DEBUFFS_NO_SPELL)
      return
    end
    for _, spell in ipairs(spells) do
      root:CreateButton(spell.name, function()
        Choice(dispelType).spellID = spell.spellID
        ns.Config:Refresh()
      end)
    end
  end)
end

local function OpenKeyChoices(owner, dispelType)
  local bindings = ns.Profiles.active.bindings
  Widgets.OpenMenu(owner, function(root)
    if root.SetScrollMode then
      root:SetScrollMode(400)
    end
    for _, prefix in ipairs(ns.BINDING_PREFIXES) do
      for _, button in ipairs(ns.MOUSE_BUTTONS) do
        local key = prefix .. button
        local label = ns.TabClicks.KeyLabel(key)
        if bindings[key] then
          label = label .. " · " .. (ns.TabClicks.Describe(bindings[key], key))
        end
        root:CreateButton(label, function()
          Choice(dispelType).key = key
          ns.Config:Refresh()
        end)
      end
    end
  end)
end

local function CreateTypeRow(panel, dispelType, position)
  local top = ROWS_TOP - (position - 1) * ROW_HEIGHT
  local swatch = Widgets.ColorSwatch(panel, function()
    return Look().dispelColors[dispelType]
  end, function(red, green, blue)
    ScheduleColor(dispelType, red, green, blue)
  end)
  swatch:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, top)
  local name = Widgets.Label(panel, "", "GameFontNormal")
  name:SetPoint("LEFT", swatch, "RIGHT", 10, 0)
  name:SetWidth(95)
  local row = { swatch = swatch, name = name, spells = {} }
  row.spellButton = Widgets.Button(panel, "", 180, function(self)
    OpenSpellChoices(self, dispelType, row.spells)
  end)
  row.spellButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 130, top + 1)
  row.keyButton = Widgets.Button(panel, "", 180, function(self)
    OpenKeyChoices(self, dispelType)
  end)
  row.keyButton:SetPoint("LEFT", row.spellButton, "RIGHT", 6, 0)
  row.assign = Widgets.Button(panel, L.DEBUFFS_ASSIGN, 100, function()
    local choice = Choice(dispelType)
    TabDebuffs.Assign(choice.spellID, choice.key)
  end)
  row.assign:SetPoint("LEFT", row.keyButton, "RIGHT", 6, 0)
  row.clicks = Widgets.Label(panel, "", "GameFontHighlightSmall")
  row.clicks:SetPoint("TOPLEFT", panel, "TOPLEFT", 130, top - 26)
  row.clicks:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
  row.clicks:SetWordWrap(false)
  return row
end

function TabDebuffs.Build(panel)
  local stack = Widgets.Stack(panel, 0, 0)
  for _, spec in ipairs(TabDebuffs.CHECKBOXES) do
    stack:Add(Widgets.Checkbox(panel, spec.label, Widgets.SectionGetter("auras", spec.key), Widgets.SectionSetter("auras", spec.key)), 30)
  end
  stack:Add(Widgets.Checkbox(panel, L.CLICKS_DISPEL_OVERRIDE, Widgets.SectionGetter("clicks", "dispelOverride"),
    Widgets.SectionSetter("clicks", "dispelOverride")), 30)
  for _, spec in ipairs(TabDebuffs.SLIDERS) do
    local range = ns.Database.RANGES[spec.key]
    stack:Add(Widgets.Slider(panel, spec.label, range[1], range[2], 1,
      Widgets.SectionGetter("auras", spec.key), Widgets.SectionSetter("auras", spec.key)), 48)
  end
  TabDebuffs.stack = stack
  local appearance = Widgets.Stack(panel, 300, 0)
  appearance:Add(Widgets.Dropdown(panel, L.DISPEL_MODE, 200, function()
    return TabDebuffs.MODE_OPTIONS
  end, Widgets.StyleGetter("auras", "dispelMode"), Widgets.StyleSetter("auras", "dispelMode")), 50)
  appearance:Add(Widgets.Dropdown(panel, L.AURAS_DEBUFFS_CORNER, 200, function()
    return ns.TabAuras.CORNER_OPTIONS
  end, Widgets.StyleGetter("auras", "debuffsPoint"), Widgets.StyleSetter("auras", "debuffsPoint")), 50)
  TabDebuffs.appearance = appearance

  local title = Widgets.Label(panel, L.DEBUFFS_COLORS_TITLE, "GameFontNormal")
  title:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, ROWS_TOP + 26)
  local reset = Widgets.Button(panel, L.DEBUFFS_RESET_COLORS, 160, function()
    TabDebuffs.ResetColors()
  end)
  reset:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, ROWS_TOP + 30)
  for position, dispelType in ipairs(ns.Database.DISPEL_TYPES) do
    TabDebuffs.rows[dispelType] = CreateTypeRow(panel, dispelType, position)
  end
  local help = Widgets.Label(panel, L.DEBUFFS_HELP, "GameFontDisableSmall")
  help:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, ROWS_TOP - #ns.Database.DISPEL_TYPES * ROW_HEIGHT - 10)
  help:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
end

function TabDebuffs.Refresh()
  TabDebuffs.stack:Refresh()
  TabDebuffs.appearance:Refresh()
  for _, row in ipairs(TabDebuffs.Rows()) do
    local widgets = TabDebuffs.rows[row.dispelType]
    local choice = Choice(row.dispelType)
    -- Por defecto: el primer hechizo que conoces para ese tipo y su clic actual (o uno libre).
    local knows = false
    for _, spell in ipairs(row.spells) do
      knows = knows or spell.spellID == choice.spellID
    end
    if not knows then
      choice.spellID = row.spells[1] and row.spells[1].spellID or nil
    end
    choice.key = choice.key or row.suggestedKey
    widgets.spells = row.spells
    widgets.swatch:Refresh()
    widgets.name:SetText(row.label)
    widgets.spellButton:SetText(choice.spellID and ns.Spells:GetName(choice.spellID) or L.DEBUFFS_NO_SPELL)
    widgets.keyButton:SetText(choice.key and ns.TabClicks.KeyLabel(choice.key) or "-")
    widgets.clicks:SetText(row.clicks)
  end
end

ns.Config:RegisterTab("debuffs", L.TAB_DEBUFFS, TabDebuffs.Build, TabDebuffs.Refresh)
