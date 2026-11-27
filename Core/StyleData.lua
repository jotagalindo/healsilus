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

-- Dirección de crecimiento por defecto: hacia el centro de la barra (desde la derecha, a la izquierda).
function StyleData.DefaultGrow(position)
  if string.find(position, "RIGHT") then
    return "LEFT"
  end
  return "RIGHT"
end

function StyleData.AuraGroup(position, iconSize)
  return { position = position, x = 0, y = 0, iconSize = iconSize, grow = StyleData.DefaultGrow(position) }
end

-- Estilos guardados o exportados antes de la versión 6: hotsPoint, debuffsPoint e iconSize sueltos.
function StyleData.UpgradeAuras(style)
  local auras = type(style) == "table" and style.auras
  if type(auras) ~= "table" then
    return
  end
  local size = type(auras.iconSize) == "number" and auras.iconSize or nil
  local function Upgrade(key, oldKey, fallback)
    if type(auras[key]) ~= "table" then
      local position = type(auras[oldKey]) == "string" and auras[oldKey] or fallback
      auras[key] = StyleData.AuraGroup(position, size or 14)
    end
  end
  if auras.hotsPoint ~= nil or auras.debuffsPoint ~= nil or size then
    Upgrade("hots", "hotsPoint", "BOTTOMRIGHT")
    Upgrade("debuffs", "debuffsPoint", "TOPRIGHT")
  end
  auras.hotsPoint, auras.debuffsPoint, auras.iconSize = nil, nil, nil
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
      -- Con la vida llena la barra (relleno, fondo, maná y textos) se ve con esta opacidad.
      fullHealthAlpha = 1,
    },
    text = {
      font = "FRIZQT",
      name = TextElement(11, "TOPLEFT", 4, -3),
      health = health,
      status = TextElement(10, "BOTTOMRIGHT", -4, 3),
    },
    -- Icono del rol elegido en el grupo (tanque, sanador, DPS); showDamager también pinta el de DPS.
    role = { show = false, showDamager = true, size = 12, point = "LEFT", x = 3, y = 0 },
    -- Aggro: borde rojo alrededor de quien tanquea y/o puntos rojos, uno por nivel de amenaza (como HealBot).
    aggro = { border = true, dots = true, blink = false, size = 8, point = "RIGHT", x = -3, y = 0 },
    -- Barra de maná, ira, energía… (el recurso que use cada unidad) debajo de la de vida.
    -- healersOnly la deja solo en quien tiene el rol de sanador; thickness es su alto en píxeles.
    -- types: qué recursos se ven (maná, ira, energía, foco de mascotas, poder rúnico y el resto).
    power = {
      show = true, healersOnly = false, thickness = 4,
      types = { MANA = true, RAGE = true, ENERGY = true, FOCUS = true, RUNIC_POWER = true, OTHER = true },
    },
    -- Grupos de iconos sobre la barra: posición (dentro o fuera), desplazamiento, tamaño y hacia dónde
    -- crecen. buffs es el aviso de buff tuyo que falta (un icono).
    auras = {
      hots = StyleData.AuraGroup("BOTTOMRIGHT", 14),
      debuffs = StyleData.AuraGroup("TOPRIGHT", 14),
      buffs = StyleData.AuraGroup("TOPLEFT", 10),
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
  style.auras.hots.iconSize, style.auras.debuffs.iconSize, style.auras.buffs.iconSize = 10, 10, 8
  return style
end

local function LargeParty()
  local style = StyleData.DefaultStyle()
  style.layout.width, style.layout.height, style.layout.spacing = 170, 46, 4
  style.layout.columns, style.layout.unitsPerColumn = 1, 40
  style.text.name = TextElement(13, "TOPLEFT", 6, -4)
  style.text.health.size, style.text.health.x, style.text.health.y = 12, 6, 4
  style.text.status = TextElement(12, "BOTTOMRIGHT", -6, 4)
  style.auras.hots.iconSize, style.auras.debuffs.iconSize, style.auras.buffs.iconSize = 18, 18, 12
  return style
end

local function Classic()
  local style = StyleData.DefaultStyle()
  style.layout.width, style.layout.height = 120, 24
  style.bar.colorMode = "HEALTH"
  style.text.name = TextElement(10, "LEFT", 4, 0)
  style.text.health.point, style.text.health.x, style.text.health.y = "RIGHT", -4, 0
  style.text.status = TextElement(10, "CENTER", 0, 0)
  style.auras.hots.iconSize, style.auras.debuffs.iconSize = 12, 12
  style.auras.dispelMode = "BAR"
  return style
end

StyleData.PRESETS = {
  { name = L.STYLE_DEFAULT_NAME, build = StyleData.DefaultStyle },
  { name = L.STYLE_COMPACT_NAME, build = CompactRaid },
  { name = L.STYLE_LARGE_NAME, build = LargeParty },
  { name = L.STYLE_CLASSIC_NAME, build = Classic },
}

-- Margen hacia dentro de la barra para cada posición: 4 px desde un lado, 3 px desde arriba o abajo,
-- y 0 en el eje en que el texto va centrado. Se aplica al elegir una posición nueva.
StyleData.EDGE_PADDING_X, StyleData.EDGE_PADDING_Y = 4, 3

function StyleData.DefaultOffset(point)
  local x, y = 0, 0
  if string.find(point, "LEFT") then
    x = StyleData.EDGE_PADDING_X
  elseif string.find(point, "RIGHT") then
    x = -StyleData.EDGE_PADDING_X
  end
  if string.find(point, "TOP") then
    y = -StyleData.EDGE_PADDING_Y
  elseif string.find(point, "BOTTOM") then
    y = StyleData.EDGE_PADDING_Y
  end
  return x, y
end

-- Quita el margen de esquina que quedó en el eje centrado (|x| ≤ 6, |y| ≤ 4: los márgenes de serie).
function StyleData.RecenterLeftovers(element)
  if type(element) ~= "table" or type(element.point) ~= "string" then
    return
  end
  local point = element.point
  local centeredX = not string.find(point, "LEFT") and not string.find(point, "RIGHT")
  local centeredY = not string.find(point, "TOP") and not string.find(point, "BOTTOM")
  if centeredX and type(element.x) == "number" and math.abs(element.x) <= 6 then
    element.x = 0
  end
  if centeredY and type(element.y) == "number" and math.abs(element.y) <= 4 then
    element.y = 0
  end
end

-- Lados por fuera de la barra: se anclan al botón entero (con su borde) y crecen alejándose de él.
-- Encima y debajo crecen hacia la izquierda o la derecha según el grupo; a los lados, siempre hacia fuera.
local OUTSIDE_GAP = 3
local OUTSIDE = {
  ABOVE = { vertical = "Up" },
  BELOW = { vertical = "Down" },
  OUTSIDE_LEFT = { point = "TOPRIGHT", relativePoint = "TOPLEFT", x = -OUTSIDE_GAP, y = 0, horizontal = "Left", vertical = "Down" },
  OUTSIDE_RIGHT = { point = "TOPLEFT", relativePoint = "TOPRIGHT", x = OUTSIDE_GAP, y = 0, horizontal = "Right", vertical = "Down" },
}

-- Cómo anclar un grupo de iconos ({ position, x, y, grow } del estilo): uno de los nueve puntos dentro
-- de la barra de vida (1 px hacia dentro desde los bordes) o un lado por fuera del botón, más el
-- desplazamiento del usuario. relativeTo: "BAR" (barra de vida) o "BUTTON" (botón entero).
function StyleData.AuraAnchor(group)
  local position = group.position
  local towardsLeft = group.grow == "LEFT"
  local horizontal = towardsLeft and "Left" or "Right"
  local x, y = group.x or 0, group.y or 0
  local outside = OUTSIDE[position]
  if outside and outside.point then
    return {
      relativeTo = "BUTTON", point = outside.point, relativePoint = outside.relativePoint,
      x = outside.x + x, y = outside.y + y, horizontal = outside.horizontal, vertical = outside.vertical,
    }
  end
  if outside then
    -- Encima o debajo: empieza en la esquina del lado desde el que crece.
    local above = position == "ABOVE"
    local side = towardsLeft and "RIGHT" or "LEFT"
    return {
      relativeTo = "BUTTON",
      point = (above and "BOTTOM" or "TOP") .. side, relativePoint = (above and "TOP" or "BOTTOM") .. side,
      x = x, y = (above and OUTSIDE_GAP or -OUTSIDE_GAP) + y, horizontal = horizontal, vertical = outside.vertical,
    }
  end
  local insetX = string.find(position, "LEFT") and 1 or string.find(position, "RIGHT") and -1 or 0
  local insetY = string.find(position, "TOP") and -1 or string.find(position, "BOTTOM") and 1 or 0
  return {
    relativeTo = "BAR", point = position, relativePoint = position,
    x = insetX + x, y = insetY + y,
    horizontal = horizontal, vertical = string.find(position, "BOTTOM") and "Up" or "Down",
  }
end

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
  StyleData.UpgradeAuras(style)
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
  if type(auras.iconSize) == "number" then
    style.auras.hots.iconSize, style.auras.debuffs.iconSize = auras.iconSize, auras.iconSize
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
