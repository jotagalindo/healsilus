-- Plantillas de disposición: dónde va cada cosa dentro de la barra (nombre, vida, estado, rol, aggro,
-- HoTs, debuffs y buff que falta), sus tamaños, el tamaño de la barra y cuántos iconos caben. Se aplican
-- al estilo activo sin tocar colores, texturas ni fuentes. Las guardadas son de toda la cuenta
-- (HealsilusDB.barLayouts). Sin APIs de WoW: se prueba fuera del juego.
local _, ns = ...
local L = ns.L

local BarLayouts = {}
ns.BarLayouts = BarLayouts

local MAX_SAVED = 12

-- Rutas del estilo que forman una disposición.
BarLayouts.STYLE_PATHS = {
  "layout.width", "layout.height", "layout.spacing", "power.thickness",
  "text.name.size", "text.name.point", "text.name.x", "text.name.y", "text.name.widthPct",
  "text.health.size", "text.health.point", "text.health.x", "text.health.y", "text.health.mode",
  "text.status.size", "text.status.point", "text.status.x", "text.status.y",
  "role.show", "role.size", "role.point", "role.x", "role.y",
  "aggro.dots", "aggro.size", "aggro.point", "aggro.x", "aggro.y",
}
for _, group in ipairs({ "hots", "debuffs", "buffs" }) do
  for _, key in ipairs({ "position", "x", "y", "iconSize", "grow" }) do
    BarLayouts.STYLE_PATHS[#BarLayouts.STYLE_PATHS + 1] = "auras." .. group .. "." .. key
  end
end

-- Del perfil: cuántos HoTs y debuffs se dibujan (el sitio que ocupan depende de ello).
BarLayouts.PROFILE_PATHS = { "auras.hotsMax", "auras.debuffsMax" }

local function Split(path)
  local parts = {}
  for part in string.gmatch(path, "[^%.]+") do
    parts[#parts + 1] = part
  end
  return parts
end

local function Read(root, path)
  local current = root
  for _, part in ipairs(Split(path)) do
    if type(current) ~= "table" then
      return nil
    end
    current = current[part]
  end
  return current
end

local function Write(root, path, value)
  local parts = Split(path)
  local current = root
  for position = 1, #parts - 1 do
    current = current[parts[position]]
  end
  current[parts[#parts]] = value
end

-- Disposición del estilo y el perfil dados: { style = { [ruta] = valor }, profile = { ... } }.
function BarLayouts.Capture(style, profile)
  local data = { style = {}, profile = {} }
  for _, path in ipairs(BarLayouts.STYLE_PATHS) do
    data.style[path] = Read(style, path)
  end
  for _, path in ipairs(BarLayouts.PROFILE_PATHS) do
    data.profile[path] = Read(profile, path)
  end
  return data
end

local function ValidValue(path, value, defaultValue)
  if type(value) ~= type(defaultValue) then
    return false
  end
  local key = string.match(path, "([^%.]+)$")
  local enum = ns.Database.ENUMS[key]
  if enum and not enum[value] then
    return false
  end
  local range = ns.Database.RANGES[key]
  if range and (value < range[1] or value > range[2]) then
    return false
  end
  return true
end

-- Validación estricta (datos guardados o importados): solo rutas conocidas, con tipo y valores válidos.
function BarLayouts.IsValid(data)
  if type(data) ~= "table" or type(data.style) ~= "table" or type(data.profile) ~= "table" then
    return false
  end
  local style, profile = ns.StyleData.DefaultStyle(), ns.Database.DefaultProfile()
  local known = {}
  for _, path in ipairs(BarLayouts.STYLE_PATHS) do
    known[path] = true
  end
  for path, value in pairs(data.style) do
    if not known[path] or not ValidValue(path, value, Read(style, path)) then
      return false
    end
  end
  local knownProfile = {}
  for _, path in ipairs(BarLayouts.PROFILE_PATHS) do
    knownProfile[path] = true
  end
  for path, value in pairs(data.profile) do
    if not knownProfile[path] or not ValidValue(path, value, Read(profile, path)) then
      return false
    end
  end
  return true
end

-- Aplica la disposición al estilo y al perfil (solo lo que trae; el resto se queda como estaba).
function BarLayouts.Apply(data, style, profile)
  for path, value in pairs(data.style) do
    Write(style, path, value)
  end
  for path, value in pairs(data.profile) do
    Write(profile, path, value)
  end
  ns.StyleData.NormalizeStyle(style, {})
end

-- Propuestas de serie, pensadas por filas para que nada se pise (lo comprueba tests/test_bar_layouts.lua).
-- Separación de 4 px entre barras: el borde de aggro (2 px por fuera) de dos vecinas no se toca.
--
-- "Sanador": barra 140 × 52, zona de vida 136 × 43.
--   Arriba: nombre (corta antes de los debuffs) · debuffs a la derecha (2 de 16 px).
--   Centro: puntos de aggro pequeños a la izquierda.
--   Abajo: rol · vida (o estado) · buff que falta · HoTs a la derecha (3 de 14 px).
-- "Banda compacta": barra 90 × 36, zona de vida 86 × 28, para bandas de 20 a 40.
--   Arriba: rol pequeño · nombre centrado.
--   Abajo: debuffs a la izquierda (2) · buff que falta en el centro · HoTs a la derecha (3).
--   Sin número de vida ni puntos de aggro (queda el borde rojo); el estado va abajo, en el centro.
local function Group(position, x, iconSize, grow)
  return { position = position, x = x, y = 0, iconSize = iconSize, grow = grow }
end

local PRESET_SHAPES = {
  healer = {
    style = {
      layout = { width = 140, height = 52, spacing = 4 },
      power = { thickness = 4 },
      text = {
        name = { size = 12, point = "TOPLEFT", x = 4, y = -3, widthPct = 0.73 },
        health = { size = 11, point = "BOTTOMLEFT", x = 19, y = 3, mode = "DEFICIT" },
        status = { size = 10, point = "BOTTOMLEFT", x = 19, y = 3 },
      },
      role = { show = true, size = 12, point = "BOTTOMLEFT", x = 3, y = 3 },
      aggro = { dots = true, size = 6, point = "LEFT", x = 3, y = 0 },
      auras = {
        hots = Group("BOTTOMRIGHT", 0, 14, "LEFT"),
        debuffs = Group("TOPRIGHT", 0, 16, "LEFT"),
        buffs = Group("BOTTOMRIGHT", -46, 13, "LEFT"),
      },
    },
    profile = { auras = { hotsMax = 3, debuffsMax = 2 } },
  },
  raid = {
    style = {
      layout = { width = 90, height = 36, spacing = 4 },
      power = { thickness = 3 },
      text = {
        name = { size = 10, point = "TOP", x = 0, y = -2, widthPct = 0.8 },
        health = { size = 9, point = "BOTTOM", x = 0, y = 3, mode = "NONE" },
        status = { size = 9, point = "BOTTOM", x = 0, y = 3 },
      },
      role = { show = true, size = 8, point = "TOPLEFT", x = 2, y = -2 },
      aggro = { dots = false, size = 6, point = "TOPRIGHT", x = -2, y = -2 },
      auras = {
        hots = Group("BOTTOMRIGHT", 0, 10, "LEFT"),
        debuffs = Group("BOTTOMLEFT", 0, 12, "RIGHT"),
        buffs = Group("BOTTOM", 0, 10, "RIGHT"),
      },
    },
    profile = { auras = { hotsMax = 3, debuffsMax = 2 } },
  },
}

BarLayouts.PRESETS = {
  { key = "healer", name = L.BAR_LAYOUT_HEALER, description = L.BAR_LAYOUT_HEALER_DESC },
  { key = "raid", name = L.BAR_LAYOUT_RAID, description = L.BAR_LAYOUT_RAID_DESC },
}

function BarLayouts.Preset(key)
  local shape = PRESET_SHAPES[key]
  if not shape then
    return nil
  end
  return BarLayouts.Capture(shape.style, shape.profile)
end

local function Store()
  return ns.Database.db.barLayouts
end

function BarLayouts.SavedNames()
  local names = {}
  for name in pairs(Store()) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

-- Guarda la disposición actual con un nombre. Devuelve el nombre limpio, o nil y el motivo.
function BarLayouts.Save(name, style, profile)
  if not ns.StyleData.IsValidName(name) then
    return nil, "bad name"
  end
  local clean = string.match(name, "^%s*(.-)%s*$")
  if Store()[clean] then
    return nil, "name taken"
  end
  if #BarLayouts.SavedNames() >= MAX_SAVED then
    return nil, "full"
  end
  Store()[clean] = BarLayouts.Capture(style, profile)
  return clean
end

function BarLayouts.Delete(name)
  Store()[name] = nil
end

-- Al cargar: se quitan las guardadas que no sean válidas (y se anota en fixes).
function BarLayouts.Normalize(saved, fixes)
  for name, data in pairs(saved) do
    if type(name) ~= "string" or not BarLayouts.IsValid(data) then
      saved[name] = nil
      fixes[#fixes + 1] = "barLayouts." .. tostring(name)
    end
  end
end
