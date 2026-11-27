-- Base de datos guardada (HealsilusDB): valores por defecto, normalización, validación estricta y migraciones.
-- Sin APIs de WoW: todo se prueba fuera del juego.
local _, ns = ...

local Database = { CURRENT_VERSION = 3, MIGRATIONS = {}, fixes = {} }
ns.Database = Database

-- Colecciones cuyo contenido decide el usuario: nunca se mezclan con los valores por defecto.
Database.OPAQUE_KEYS = { bindings = true, hotSpellIDs = true, watched = true }

local ANCHOR_POINTS = {
  TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true,
  RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true,
}
-- Iconos de auras: una esquina dentro de la barra o un lado por fuera de ella (ver Auras/Containers.lua).
local AURA_POSITIONS = {
  TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true,
  ABOVE = true, BELOW = true, OUTSIDE_LEFT = true, OUTSIDE_RIGHT = true,
}

-- Valores permitidos por nombre de campo (perfil y estilos, ver Core/StyleData.lua).
Database.ENUMS = {
  sortBy = { GROUP = true, CLASS = true, ROLE = true },
  growth = { DOWN = true, RIGHT = true },
  colorMode = { CLASS = true, HEALTH = true },
  mode = { NONE = true, DEFICIT = true, PERCENT = true, CURRENT = true, CURRENT_MAX = true, CURRENT_PERCENT = true },
  outline = { NONE = true, OUTLINE = true, THICKOUTLINE = true },
  point = ANCHOR_POINTS,
  hotsPoint = AURA_POSITIONS,
  debuffsPoint = AURA_POSITIONS,
  dispelMode = { RING = true, BAR = true, BOTH = true },
}

Database.WATCH_TARGETS = { ALL = true, TANKS = true, HEALERS = true, SELF = true }

Database.RANGES = {
  width = { 40, 300 },
  height = { 16, 80 },
  spacing = { 0, 20 },
  columns = { 1, 8 },
  unitsPerColumn = { 1, 40 },
  outOfRangeAlpha = { 0.1, 1 },
  hotsMax = { 0, 8 },
  debuffsMax = { 0, 6 },
  iconSize = { 8, 32 },
  -- Minutos restantes por debajo de los cuales un buff vigilado cuenta como que falta (0 = no avisar).
  refreshBelow = { 0, 60 },
  -- Distancia (px) a la que un bloque soltado se pega a otro (0 = sin imán).
  snapDistance = { 0, 40 },
  -- Canales de color (dispel, fondo y curva de vida de los estilos).
  r = { 0, 1 },
  g = { 0, 1 },
  b = { 0, 1 },
  a = { 0, 1 },
  -- Textos de los estilos.
  size = { 6, 24 },
  x = { -60, 60 },
  y = { -60, 60 },
  -- Umbrales de la curva de vida (fracción de vida).
  injuredAt = { 0.02, 1 },
  criticalAt = { 0, 0.98 },
}

-- Tipos de debuff que se pueden quitar, en el orden en que se muestran en la pestaña Debuffs.
Database.DISPEL_TYPES = { "Magic", "Curse", "Poison", "Disease" }

local COLOR_FIELDS = { r = true, g = true, b = true }

function Database.DefaultDispelColors()
  return {
    Magic = { r = 0.2, g = 0.6, b = 1 },
    Curse = { r = 0.6, g = 0, b = 1 },
    Poison = { r = 0, g = 0.6, b = 0 },
    Disease = { r = 0.6, g = 0.4, b = 0 },
  }
end

local BINDING_FIELDS = {
  spell = { kind = true, spellID = true, rank = true, fallbackSpellID = true },
  macro = { kind = true, text = true },
  target = { kind = true },
  menu = { kind = true },
  -- Lanza sobre esa barra el primer buff vigilado que le falta (se decide fuera de combate).
  buff = { kind = true },
}

local WATCHED_FIELDS = { spellID = true, groupSpellID = true, targets = true }

local MAX_MACRO_LENGTH = 1023

Database.DEFAULT_MINIMAP_ANGLE = 225

-- Modo mover (UI/MoveMode.lua): rejilla, su tamaño en píxeles, pegar a ella y miembros de ejemplo.
Database.GRID_SIZES = { 16, 32, 64 }
Database.FILL_COUNTS = { 5, 10, 20, 40 }

function Database.DefaultMoveMode()
  return { grid = true, gridSize = 32, snapToGrid = true, fill = 5 }
end

local function IsListed(list, value)
  for _, entry in ipairs(list) do
    if entry == value then
      return true
    end
  end
  return false
end

-- Qué estilo usa el perfil en cada situación (los nombres son los de los estilos de serie).
function Database.DefaultStyleRules()
  local L = ns.L
  return {
    solo = L.STYLE_DEFAULT_NAME,
    party = L.STYLE_DEFAULT_NAME,
    raid10 = L.STYLE_DEFAULT_NAME,
    raid20 = L.STYLE_DEFAULT_NAME,
    raid40 = L.STYLE_COMPACT_NAME,
  }
end

function Database.DefaultProfile()
  return {
    bindings = {},
    -- targetOnClick: además de lanzar, selecciona la unidad. avoidBlueCursor: cancela el cursor azul
    -- si el hechizo no se puede lanzar sobre ella. Ambas convierten el hechizo en una macro [@mouseover].
    -- dispelOverride: fuera de combate, cualquier clic sobre una barra con un debuff que puedes quitar lo quita.
    -- buffOverride (activado de serie): fuera de combate, cualquier clic sobre una barra a la que le falta
    -- un buff vigilado se lo pone. En combate los clics hacen lo de siempre.
    clicks = { targetOnClick = false, avoidBlueCursor = false, dispelOverride = false, buffOverride = true },
    -- Lo visual (tamaño, textura, textos, iconos, colores) vive en los estilos (Core/StyleData.lua);
    -- el perfil decide cuándo se ven los marcos y qué estilo usar en cada situación.
    frames = {
      showMain = true, showSolo = true, showInParty = true, showInRaid = true,
      moveTogether = false, snapDistance = 12,
      showTanks = true, showPets = false, showTarget = true, showFocus = true,
      hideBlizzard = true, locked = true, castOnDown = false,
    },
    auras = {
      hotsEnabled = true, hotsMax = 4, hotSpellIDs = {},
      debuffsEnabled = true, debuffsMax = 2, debuffsDispellableOnly = true,
    },
    buffs = {
      enabled = true, watched = {},
      colorBar = true, barColor = { r = 0.94, g = 0.62, b = 0.15 }, refreshBelow = 0,
    },
    styleRules = Database.DefaultStyleRules(),
  }
end

local function IsPositiveInteger(value)
  return type(value) == "number" and value > 0 and value % 1 == 0
end
Database.IsPositiveInteger = IsPositiveInteger

local function HasOnlyFields(record, allowed)
  for key in pairs(record) do
    if not allowed[key] then
      return false
    end
  end
  return true
end

local BINDING_KEYS = {}
for _, prefix in ipairs(ns.BINDING_PREFIXES) do
  for _, button in ipairs(ns.MOUSE_BUTTONS) do
    BINDING_KEYS[prefix .. button] = true
  end
end

function Database.IsValidBindingKey(key)
  return BINDING_KEYS[key] == true
end

function Database.IsValidBinding(binding)
  if type(binding) ~= "table" then
    return false
  end
  local allowed = BINDING_FIELDS[binding.kind]
  if not allowed or not HasOnlyFields(binding, allowed) then
    return false
  end
  if binding.kind == "spell" then
    return IsPositiveInteger(binding.spellID)
      and (binding.rank == nil or IsPositiveInteger(binding.rank))
      and (binding.fallbackSpellID == nil or IsPositiveInteger(binding.fallbackSpellID))
  elseif binding.kind == "macro" then
    return type(binding.text) == "string" and #binding.text > 0 and #binding.text <= MAX_MACRO_LENGTH
  end
  return true
end

function Database.IsValidWatched(entry)
  return type(entry) == "table"
    and HasOnlyFields(entry, WATCHED_FIELDS)
    and IsPositiveInteger(entry.spellID)
    and (entry.groupSpellID == nil or IsPositiveInteger(entry.groupSpellID))
    and Database.WATCH_TARGETS[entry.targets] == true
end

-- Completa 'target' con 'defaults' sin tocar lo que el usuario ya tiene bien.
-- Cada campo corregido se añade a 'fixes' con su ruta (p. ej. "frames.showTanks").
function Database.FillDefaults(target, defaults, path, fixes)
  for key, defaultValue in pairs(defaults) do
    local current = target[key]
    local fieldPath = path == "" and key or (path .. "." .. key)
    if current == nil then
      target[key] = ns.DeepCopy(defaultValue)
    elseif type(current) ~= type(defaultValue) then
      target[key] = ns.DeepCopy(defaultValue)
      fixes[#fixes + 1] = fieldPath
    elseif type(defaultValue) == "table" then
      if not Database.OPAQUE_KEYS[key] then
        Database.FillDefaults(current, defaultValue, fieldPath, fixes)
      end
    elseif Database.ENUMS[key] and not Database.ENUMS[key][current] then
      target[key] = defaultValue
      fixes[#fixes + 1] = fieldPath
    elseif Database.RANGES[key] then
      local range = Database.RANGES[key]
      local clamped = math.min(range[2], math.max(range[1], current))
      if clamped ~= current then
        target[key] = clamped
        fixes[#fixes + 1] = fieldPath
      end
    end
  end
end

function Database.NormalizeProfile(profile, fixes)
  fixes = fixes or Database.fixes
  Database.FillDefaults(profile, Database.DefaultProfile(), "", fixes)
  for key, binding in pairs(profile.bindings) do
    if not Database.IsValidBindingKey(key) or not Database.IsValidBinding(binding) then
      profile.bindings[key] = nil
      fixes[#fixes + 1] = "bindings." .. tostring(key)
    end
  end
  for spellID, enabled in pairs(profile.auras.hotSpellIDs) do
    if not IsPositiveInteger(spellID) or enabled ~= true then
      profile.auras.hotSpellIDs[spellID] = nil
      fixes[#fixes + 1] = "auras.hotSpellIDs." .. tostring(spellID)
    end
  end
  local watched = {}
  for position, entry in ipairs(profile.buffs.watched) do
    if Database.IsValidWatched(entry) then
      watched[#watched + 1] = entry
    else
      fixes[#fixes + 1] = "buffs.watched." .. position
    end
  end
  profile.buffs.watched = watched
  for context in pairs(profile.styleRules) do
    if Database.DefaultStyleRules()[context] == nil then
      profile.styleRules[context] = nil
      fixes[#fixes + 1] = "styleRules." .. tostring(context)
    end
  end
  return profile
end

function Database.IsValidColor(color)
  if type(color) ~= "table" or not HasOnlyFields(color, COLOR_FIELDS) then
    return false
  end
  for field in pairs(COLOR_FIELDS) do
    local channel = color[field]
    if type(channel) ~= "number" or channel < 0 or channel > 1 then
      return false
    end
  end
  return true
end

-- Validación estricta para perfiles importados: cualquier campo desconocido o mal tipado rechaza todo.
-- Devuelve true, o false y la ruta del primer campo que falla.
function Database.ValidateProfile(profile)
  if type(profile) ~= "table" then
    return false, "profile"
  end
  local defaults = Database.DefaultProfile()
  for key in pairs(profile) do
    if defaults[key] == nil then
      return false, tostring(key)
    end
  end
  if profile.bindings ~= nil then
    if type(profile.bindings) ~= "table" then
      return false, "bindings"
    end
    for key, binding in pairs(profile.bindings) do
      if not Database.IsValidBindingKey(key) or not Database.IsValidBinding(binding) then
        return false, "bindings." .. tostring(key)
      end
    end
  end
  for _, section in ipairs({ "clicks", "frames", "auras", "buffs", "styleRules" }) do
    local values = profile[section]
    if values ~= nil then
      if type(values) ~= "table" then
        return false, section
      end
      for key, value in pairs(values) do
        local fieldPath = section .. "." .. tostring(key)
        local defaultValue = defaults[section][key]
        if defaultValue == nil or type(value) ~= type(defaultValue) then
          return false, fieldPath
        end
        if Database.ENUMS[key] and not Database.ENUMS[key][value] then
          return false, fieldPath
        end
      end
    end
  end
  if profile.auras and profile.auras.hotSpellIDs then
    for spellID, enabled in pairs(profile.auras.hotSpellIDs) do
      if not IsPositiveInteger(spellID) or enabled ~= true then
        return false, "auras.hotSpellIDs"
      end
    end
  end
  if profile.buffs and profile.buffs.barColor ~= nil and not Database.IsValidColor(profile.buffs.barColor) then
    return false, "buffs.barColor"
  end
  if profile.buffs and profile.buffs.watched then
    for position, entry in pairs(profile.buffs.watched) do
      if not IsPositiveInteger(position) or not Database.IsValidWatched(entry) then
        return false, "buffs.watched." .. tostring(position)
      end
    end
  end
  return true
end

function Database.NormalizeCharacter(character, fixes)
  if type(character.class) ~= "string" then
    character.class = nil
  end
  if type(character.useClassProfile) ~= "boolean" then
    character.useClassProfile = true
  end
  if type(character.useSpecProfiles) ~= "boolean" then
    character.useSpecProfiles = false
  end
  if character.own ~= nil then
    if type(character.own) == "table" then
      Database.NormalizeProfile(character.own, fixes)
    else
      character.own = nil
      fixes[#fixes + 1] = "characters.own"
    end
  end
  if type(character.specs) ~= "table" then
    character.specs = {}
  end
  for specIndex, profile in pairs(character.specs) do
    if IsPositiveInteger(specIndex) and type(profile) == "table" then
      Database.NormalizeProfile(profile, fixes)
    else
      character.specs[specIndex] = nil
      fixes[#fixes + 1] = "characters.specs." .. tostring(specIndex)
    end
  end
end

-- Versión 1 → 2: la parte visual de cada perfil pasa a un estilo con nombre ("My style", "My style 2"...).
-- Perfiles con el mismo aspecto comparten estilo; el perfil se queda con una regla que lo usa siempre.
local function SameValue(left, right)
  if type(left) ~= type(right) then
    return false
  end
  if type(left) ~= "table" then
    return left == right
  end
  for key, value in pairs(left) do
    if not SameValue(value, right[key]) then
      return false
    end
  end
  for key in pairs(right) do
    if left[key] == nil then
      return false
    end
  end
  return true
end

local function EachStoredProfile(db, visit)
  for _, profile in pairs(type(db.classProfiles) == "table" and db.classProfiles or {}) do
    visit(profile)
  end
  for _, character in pairs(type(db.characters) == "table" and db.characters or {}) do
    if type(character) == "table" then
      visit(character.own)
      for _, profile in pairs(type(character.specs) == "table" and character.specs or {}) do
        visit(profile)
      end
    end
  end
end
Database.EachStoredProfile = EachStoredProfile

Database.MIGRATIONS[1] = function(db)
  db.styles = type(db.styles) == "table" and db.styles or {}
  local migrated = {}
  EachStoredProfile(db, function(profile)
    if type(profile) ~= "table" then
      return
    end
    local style = ns.StyleData.ExtractVersion1Style(profile)
    local name
    for _, entry in ipairs(migrated) do
      if SameValue(entry.style, style) then
        name = entry.name
      end
    end
    if not name then
      name = #migrated == 0 and ns.L.STYLE_MIGRATED_NAME or (ns.L.STYLE_MIGRATED_NAME .. " " .. (#migrated + 1))
      migrated[#migrated + 1] = { name = name, style = style }
      db.styles[name] = style
    end
    local rules = {}
    for context in pairs(Database.DefaultStyleRules()) do
      rules[context] = name
    end
    profile.styleRules = rules
  end)
end

-- Versión 2 → 3: el clic que pone el buff que falta pasa a estar activado de serie. Los perfiles
-- guardados lo tenían a false solo porque era el valor por defecto anterior, así que se activa.
Database.MIGRATIONS[2] = function(db)
  EachStoredProfile(db, function(profile)
    if type(profile) == "table" and type(profile.clicks) == "table" then
      profile.clicks.buffOverride = true
    end
  end)
end

-- Cada migración convierte los datos de la versión N a la N+1. Una versión sin migración es un error.
function Database:Migrate(db)
  if type(db.version) ~= "number" then
    db.version = self.CURRENT_VERSION
    return
  end
  while db.version < self.CURRENT_VERSION do
    local migration = self.MIGRATIONS[db.version]
    if not migration then
      error("Healsilus: no migration from version " .. db.version)
    end
    migration(db)
    db.version = db.version + 1
  end
  if db.version > self.CURRENT_VERSION then
    self.fixes[#self.fixes + 1] = "version " .. db.version .. " is newer than this addon"
  end
end

function Database:Initialize()
  if type(HealsilusDB) ~= "table" then
    HealsilusDB = {}
  end
  local db = HealsilusDB
  self:Migrate(db)
  if type(db.classProfiles) ~= "table" then
    db.classProfiles = {}
  end
  if type(db.characters) ~= "table" then
    db.characters = {}
  end
  if type(db.framePositions) ~= "table" then
    db.framePositions = {}
  end
  if type(db.debug) ~= "boolean" then
    db.debug = false
  end
  -- Botón del minimapa: común a toda la cuenta, no depende del perfil.
  if type(db.minimap) ~= "table" then
    db.minimap = {}
  end
  if type(db.minimap.angle) ~= "number" then
    db.minimap.angle = Database.DEFAULT_MINIMAP_ANGLE
  end
  if type(db.minimap.hide) ~= "boolean" then
    db.minimap.hide = false
  end
  -- Personajes con Healsilus desactivado (clic derecho en el botón del minimapa): clave → true.
  if type(db.disabledCharacters) ~= "table" then
    db.disabledCharacters = {}
  end
  for characterKey, disabled in pairs(db.disabledCharacters) do
    if disabled ~= true then
      db.disabledCharacters[characterKey] = nil
    end
  end
  local moveDefaults = Database.DefaultMoveMode()
  if type(db.moveMode) ~= "table" then
    db.moveMode = moveDefaults
  end
  for _, key in ipairs({ "grid", "snapToGrid" }) do
    if type(db.moveMode[key]) ~= "boolean" then
      db.moveMode[key] = moveDefaults[key]
    end
  end
  if not IsListed(Database.GRID_SIZES, db.moveMode.gridSize) then
    db.moveMode.gridSize = moveDefaults.gridSize
  end
  if not IsListed(Database.FILL_COUNTS, db.moveMode.fill) then
    db.moveMode.fill = moveDefaults.fill
  end
  -- Estilos: comunes a toda la cuenta. Los de serie se instalan una sola vez (si luego borras uno, no vuelve).
  if type(db.styles) ~= "table" then
    db.styles = {}
  end
  if not db.presetsInstalled then
    ns.StyleData.InstallPresets(db.styles)
    db.presetsInstalled = true
  end
  for name, style in pairs(db.styles) do
    if type(style) == "table" and ns.StyleData.IsValidName(name) then
      ns.StyleData.NormalizeStyle(style, self.fixes)
    else
      db.styles[name] = nil
      self.fixes[#self.fixes + 1] = "styles." .. tostring(name)
    end
  end
  for classToken, profile in pairs(db.classProfiles) do
    if type(profile) == "table" then
      Database.NormalizeProfile(profile, self.fixes)
    else
      db.classProfiles[classToken] = nil
      self.fixes[#self.fixes + 1] = "classProfiles." .. tostring(classToken)
    end
  end
  for characterKey, character in pairs(db.characters) do
    if type(character) == "table" then
      Database.NormalizeCharacter(character, self.fixes)
    else
      db.characters[characterKey] = nil
      self.fixes[#self.fixes + 1] = "characters." .. tostring(characterKey)
    end
  end
  self.db = db
  return db
end
