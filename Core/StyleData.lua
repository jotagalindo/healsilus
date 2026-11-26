-- Estilos (skins): todo lo visual de los marcos, con nombre y compartido por toda la cuenta.
-- Aquí están el esquema, los valores por defecto, los estilos de serie y la validación. Sin APIs de WoW.
local _, ns = ...
local L = ns.L
local Database = ns.Database

local StyleData = {}
ns.StyleData = StyleData

-- Situaciones en las que el perfil elige estilo, en el orden de la pestaña Estilos.
StyleData.CONTEXTS = { "solo", "party", "raid10", "raid20", "raid40" }

local MAX_NAME_LENGTH = 40
local MIN_THRESHOLD_GAP = 0.02

local function TextElement(size, point, x, y)
  return { size = size, outline = "NONE", point = point, x = x, y = y }
end

function StyleData.DefaultStyle()
  local health = TextElement(10, "BOTTOMLEFT", 4, 3)
  health.mode = "DEFICIT"
  return {
    layout = { width = 110, height = 34, spacing = 2, columns = 8, unitsPerColumn = 5, growth = "DOWN", sortBy = "GROUP" },
    bar = {
      texture = "BLIZZARD",
      colorMode = "CLASS",
      outOfRangeAlpha = 0.4,
      background = { r = 0.06, g = 0.06, b = 0.06, a = 0.9 },
      healthy = { r = 0, g = 1, b = 0 },
      injured = { r = 1, g = 1, b = 0 },
      critical = { r = 1, g = 0, b = 0 },
      injuredAt = 0.65,
      criticalAt = 0.3,
    },
    text = {
      font = "FRIZQT",
      name = TextElement(11, "TOPLEFT", 4, -3),
      health = health,
      status = TextElement(10, "BOTTOMRIGHT", -4, 3),
    },
    auras = {
      iconSize = 14,
      hotsPoint = "BOTTOMRIGHT",
      debuffsPoint = "TOPRIGHT",
      dispelMode = "RING",
      dispelColors = Database.DefaultDispelColors(),
    },
  }
end

local function CompactRaid()
  local style = StyleData.DefaultStyle()
  style.layout.width, style.layout.height, style.layout.spacing = 72, 28, 1
  style.bar.texture = "RAID"
  style.text.name = TextElement(9, "TOP", 0, -3)
  style.text.health.mode = "NONE"
  style.text.status = TextElement(9, "BOTTOM", 0, 3)
  style.auras.iconSize = 10
  return style
end

local function LargeParty()
  local style = StyleData.DefaultStyle()
  style.layout.width, style.layout.height, style.layout.spacing = 170, 46, 4
  style.layout.columns, style.layout.unitsPerColumn = 1, 40
  style.text.name = TextElement(13, "TOPLEFT", 6, -4)
  style.text.health.size, style.text.health.x, style.text.health.y = 12, 6, 4
  style.text.status = TextElement(12, "BOTTOMRIGHT", -6, 4)
  style.auras.iconSize = 18
  return style
end

local function Classic()
  local style = StyleData.DefaultStyle()
  style.layout.width, style.layout.height = 120, 24
  style.bar.colorMode = "HEALTH"
  style.text.name = TextElement(10, "LEFT", 4, 0)
  style.text.health.point, style.text.health.x, style.text.health.y = "RIGHT", -4, 0
  style.text.status = TextElement(10, "CENTER", 0, 0)
  style.auras.iconSize = 12
  style.auras.dispelMode = "BAR"
  return style
end

StyleData.PRESETS = {
  { name = L.STYLE_DEFAULT_NAME, build = StyleData.DefaultStyle },
  { name = L.STYLE_COMPACT_NAME, build = CompactRaid },
  { name = L.STYLE_LARGE_NAME, build = LargeParty },
  { name = L.STYLE_CLASSIC_NAME, build = Classic },
}

function StyleData.IsValidName(name)
  if type(name) ~= "string" then
    return false
  end
  local trimmed = string.match(name, "^%s*(.-)%s*$")
  return trimmed ~= "" and #trimmed <= MAX_NAME_LENGTH
end

-- Quita claves que el esquema no conoce (en cualquier nivel) y las anota en fixes.
local function RemoveUnknown(target, defaults, path, fixes)
  for key, value in pairs(target) do
    local fieldPath = path .. "." .. tostring(key)
    local defaultValue = defaults[key]
    if defaultValue == nil then
      target[key] = nil
      fixes[#fixes + 1] = fieldPath
    elseif type(value) == "table" and type(defaultValue) == "table" then
      RemoveUnknown(value, defaultValue, fieldPath, fixes)
    end
  end
end

function StyleData.NormalizeStyle(style, fixes)
  fixes = fixes or Database.fixes
  local defaults = StyleData.DefaultStyle()
  -- Las texturas y fuentes pueden venir de LibSharedMedia: cualquier nombre de texto vale.
  RemoveUnknown(style, defaults, "style", fixes)
  Database.FillDefaults(style, defaults, "style", fixes)
  local bar = style.bar
  if bar.injuredAt < bar.criticalAt + MIN_THRESHOLD_GAP then
    bar.injuredAt = math.min(1, bar.criticalAt + MIN_THRESHOLD_GAP)
    bar.criticalAt = math.min(bar.criticalAt, bar.injuredAt - MIN_THRESHOLD_GAP)
  end
  return style
end

-- Validación estricta, para estilos importados. Devuelve true, o false y la ruta del primer fallo.
local function ValidateAgainst(value, defaultValue, path)
  if type(value) ~= type(defaultValue) then
    return false, path
  end
  if type(defaultValue) ~= "table" then
    local key = string.match(path, "([^%.]+)$")
    if Database.ENUMS[key] and not Database.ENUMS[key][value] then
      return false, path
    end
    local range = Database.RANGES[key]
    if range and (value < range[1] or value > range[2]) then
      return false, path
    end
    if type(value) == "string" and value == "" then
      return false, path
    end
    return true
  end
  for key, entry in pairs(value) do
    local fieldPath = path .. "." .. tostring(key)
    if defaultValue[key] == nil then
      return false, fieldPath
    end
    local valid, failedPath = ValidateAgainst(entry, defaultValue[key], fieldPath)
    if not valid then
      return false, failedPath
    end
  end
  return true
end

function StyleData.ValidateStyle(style)
  return ValidateAgainst(style, StyleData.DefaultStyle(), "style")
end

-- Copias que se instalan la primera vez que se usa el addon (o al pasar a la versión 2).
function StyleData.InstallPresets(styles)
  for _, preset in ipairs(StyleData.PRESETS) do
    if not styles[preset.name] then
      styles[preset.name] = preset.build()
    end
  end
end

-- Convierte la parte visual de un perfil de la versión 1 en un estilo y la quita del perfil.
local MOVED_TO_LAYOUT = { "width", "height", "spacing", "columns", "unitsPerColumn", "growth", "sortBy" }
local MOVED_TO_BAR = { "texture", "colorMode", "outOfRangeAlpha" }

function StyleData.ExtractVersion1Style(profile)
  local style = StyleData.DefaultStyle()
  local frames = type(profile.frames) == "table" and profile.frames or {}
  local auras = type(profile.auras) == "table" and profile.auras or {}
  for _, key in ipairs(MOVED_TO_LAYOUT) do
    if frames[key] ~= nil then
      style.layout[key] = frames[key]
    end
    frames[key] = nil
  end
  for _, key in ipairs(MOVED_TO_BAR) do
    if frames[key] ~= nil then
      style.bar[key] = frames[key]
    end
    frames[key] = nil
  end
  if frames.healthText ~= nil then
    style.text.health.mode = frames.healthText
  end
  frames.healthText = nil
  if auras.iconSize ~= nil then
    style.auras.iconSize = auras.iconSize
  end
  auras.iconSize = nil
  if type(auras.dispelColors) == "table" then
    for dispelType, color in pairs(auras.dispelColors) do
      style.auras.dispelColors[dispelType] = color
    end
  end
  auras.dispelColors = nil
  return StyleData.NormalizeStyle(style, {})
end
