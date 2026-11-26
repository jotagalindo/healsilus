-- Pestaña Marcos: tamaño, orden, colores, bloques visibles, bloqueo y vista previa.
-- Los controles se describen en tablas para poder comprobar en las pruebas que encajan con el esquema.
local _, ns = ...
local L = ns.L
local Widgets = ns.Widgets

local TabFrames = { stacks = {} }
ns.TabFrames = TabFrames

TabFrames.SLIDERS = {
  { key = "width", label = L.FRAMES_WIDTH, step = 1 },
  { key = "height", label = L.FRAMES_HEIGHT, step = 1 },
  { key = "spacing", label = L.FRAMES_SPACING, step = 1 },
  { key = "columns", label = L.FRAMES_COLUMNS, step = 1 },
  { key = "unitsPerColumn", label = L.FRAMES_UNITS_PER_COLUMN, step = 1 },
  { key = "outOfRangeAlpha", label = L.FRAMES_RANGE_ALPHA, step = 0.05, format = "%.2f" },
}

local TEXTURE_LABELS = { BLIZZARD = L.TEXTURE_BLIZZARD, RAID = L.TEXTURE_RAID, FLAT = L.TEXTURE_FLAT }
local textureOptions = {}
for _, key in ipairs(ns.Media.TEXTURE_ORDER) do
  textureOptions[#textureOptions + 1] = { value = key, label = TEXTURE_LABELS[key] }
end

TabFrames.DROPDOWNS = {
  { key = "sortBy", label = L.FRAMES_SORT, options = {
    { value = "GROUP", label = L.SORT_GROUP }, { value = "CLASS", label = L.SORT_CLASS }, { value = "ROLE", label = L.SORT_ROLE },
  } },
  { key = "growth", label = L.FRAMES_GROWTH, options = {
    { value = "DOWN", label = L.GROWTH_DOWN }, { value = "RIGHT", label = L.GROWTH_RIGHT },
  } },
  { key = "colorMode", label = L.FRAMES_COLOR, options = {
    { value = "CLASS", label = L.COLOR_CLASS }, { value = "HEALTH", label = L.COLOR_HEALTH },
  } },
  { key = "healthText", label = L.FRAMES_HEALTH_TEXT, options = {
    { value = "NONE", label = L.TEXT_NONE }, { value = "DEFICIT", label = L.TEXT_DEFICIT }, { value = "PERCENT", label = L.TEXT_PERCENT },
  } },
  { key = "texture", label = L.FRAMES_TEXTURE, options = textureOptions },
}

local function WarnBlizzardRestore(hidden)
  if not hidden then
    ns.Print(L.RELOAD_TO_RESTORE)
  end
end

TabFrames.CHECKBOXES = {
  { key = "showSolo", label = L.FRAMES_SHOW_SOLO },
  { key = "showInParty", label = L.FRAMES_SHOW_IN_PARTY },
  { key = "showInRaid", label = L.FRAMES_SHOW_IN_RAID },
  { key = "showTanks", label = L.FRAMES_SHOW_TANKS },
  { key = "showPets", label = L.FRAMES_SHOW_PETS },
  { key = "showTarget", label = L.FRAMES_SHOW_TARGET },
  { key = "showFocus", label = L.FRAMES_SHOW_FOCUS },
  { key = "hideBlizzard", label = L.FRAMES_HIDE_BLIZZARD, afterChange = WarnBlizzardRestore },
  { key = "locked", label = L.FRAMES_LOCKED },
  { key = "castOnDown", label = L.FRAMES_CAST_ON_DOWN },
}

local PREVIEW_COUNTS = { 5, 10, 20, 40 }

function TabFrames.Build(panel)
  local sliders = Widgets.Stack(panel, 0, 0)
  for _, spec in ipairs(TabFrames.SLIDERS) do
    local range = ns.Database.RANGES[spec.key]
    sliders:Add(Widgets.Slider(panel, spec.label, range[1], range[2], spec.step,
      Widgets.SectionGetter("frames", spec.key), Widgets.SectionSetter("frames", spec.key), spec.format), 48)
  end
  local dropdowns = Widgets.Stack(panel, 250, 0)
  for _, spec in ipairs(TabFrames.DROPDOWNS) do
    dropdowns:Add(Widgets.Dropdown(panel, spec.label, 200, function()
      return spec.options
    end, Widgets.SectionGetter("frames", spec.key), Widgets.SectionSetter("frames", spec.key)), 50)
  end
  local checkboxes = Widgets.Stack(panel, 470, 0)
  for _, spec in ipairs(TabFrames.CHECKBOXES) do
    checkboxes:Add(Widgets.Checkbox(panel, spec.label, Widgets.SectionGetter("frames", spec.key),
      Widgets.SectionSetter("frames", spec.key, spec.afterChange)), 28)
  end
  -- El botón del minimapa es de toda la cuenta, no del perfil.
  checkboxes:Add(Widgets.Checkbox(panel, L.MINIMAP_SHOW, function()
    return not HealsilusDB.minimap.hide
  end, function(shown)
    ns.MinimapButton:SetHidden(not shown)
  end), 28)
  TabFrames.stacks = { sliders, dropdowns, checkboxes }

  local previewLabel = Widgets.Label(panel, L.PREVIEW_LABEL, "GameFontNormal")
  previewLabel:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 6)
  local previous = previewLabel
  for _, count in ipairs(PREVIEW_COUNTS) do
    local button = Widgets.Button(panel, tostring(count), 50, function()
      ns.Preview:Show(count)
    end)
    button:SetPoint("LEFT", previous, "RIGHT", 8, 0)
    previous = button
  end
  local hide = Widgets.Button(panel, L.PREVIEW_HIDE, 90, function()
    ns.Preview:Hide()
  end)
  hide:SetPoint("LEFT", previous, "RIGHT", 8, 0)
end

function TabFrames.Refresh()
  for _, stack in ipairs(TabFrames.stacks) do
    stack:Refresh()
  end
end

ns.Config:RegisterTab("frames", L.TAB_FRAMES, TabFrames.Build, TabFrames.Refresh)
