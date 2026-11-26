-- Pestaña Debuffs: qué debuffs se ven, el color de cada tipo (anillo de la barra y borde del icono)
-- y con qué clic quitas cada tipo. Quitar un debuff siempre es un clic tuyo con una asignación fija.
local _, ns = ...
local L = ns.L
local Widgets = ns.Widgets

local TabDebuffs = { stack = nil, rows = {} }
ns.TabDebuffs = TabDebuffs

local ROWS_TOP, ROW_HEIGHT, COLOR_APPLY_DELAY = -150, 30, 0.4

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

local function Auras()
  return ns.Profiles.active.auras
end

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
      color = Auras().dispelColors[dispelType],
      clicks = DescribeClicks(clicks[dispelType], bindings),
    }
  end
  return rows
end

function TabDebuffs.SetColor(dispelType, red, green, blue)
  Auras().dispelColors[dispelType] = { r = red, g = green, b = blue }
  ns.Config:Changed("auras")
end

function TabDebuffs.ResetColors()
  Auras().dispelColors = ns.Database.DefaultDispelColors()
  ns.Config:Changed("auras")
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

local function CreateTypeRow(panel, dispelType, position)
  local top = ROWS_TOP - (position - 1) * ROW_HEIGHT
  local swatch = Widgets.ColorSwatch(panel, function()
    return Auras().dispelColors[dispelType]
  end, function(red, green, blue)
    ScheduleColor(dispelType, red, green, blue)
  end)
  swatch:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, top)
  local name = Widgets.Label(panel, "", "GameFontNormal")
  name:SetPoint("LEFT", swatch, "RIGHT", 10, 0)
  name:SetWidth(110)
  local clicks = Widgets.Label(panel, "", "GameFontHighlight")
  clicks:SetPoint("LEFT", name, "RIGHT", 10, 0)
  clicks:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
  clicks:SetWordWrap(false)
  return { swatch = swatch, name = name, clicks = clicks }
end

function TabDebuffs.Build(panel)
  local stack = Widgets.Stack(panel, 0, 0)
  for _, spec in ipairs(TabDebuffs.CHECKBOXES) do
    stack:Add(Widgets.Checkbox(panel, spec.label, Widgets.SectionGetter("auras", spec.key), Widgets.SectionSetter("auras", spec.key)), 30)
  end
  for _, spec in ipairs(TabDebuffs.SLIDERS) do
    local range = ns.Database.RANGES[spec.key]
    stack:Add(Widgets.Slider(panel, spec.label, range[1], range[2], 1,
      Widgets.SectionGetter("auras", spec.key), Widgets.SectionSetter("auras", spec.key)), 48)
  end
  TabDebuffs.stack = stack

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
  for _, row in ipairs(TabDebuffs.Rows()) do
    local widgets = TabDebuffs.rows[row.dispelType]
    widgets.swatch:Refresh()
    widgets.name:SetText(row.label)
    widgets.clicks:SetText(row.clicks)
  end
end

ns.Config:RegisterTab("debuffs", L.TAB_DEBUFFS, TabDebuffs.Build, TabDebuffs.Refresh)
