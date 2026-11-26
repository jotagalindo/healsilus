-- Base de datos guardada (HealsilusDB): valores por defecto, normalización, validación estricta y migraciones.
-- Sin APIs de WoW: todo se prueba fuera del juego.
local _, ns = ...

local Database = { CURRENT_VERSION = 1, MIGRATIONS = {}, fixes = {} }
ns.Database = Database

-- Colecciones cuyo contenido decide el usuario: nunca se mezclan con los valores por defecto.
Database.OPAQUE_KEYS = { bindings = true, hotSpellIDs = true, watched = true }

Database.ENUMS = {
  sortBy = { GROUP = true, CLASS = true, ROLE = true },
  growth = { DOWN = true, RIGHT = true },
  texture = { BLIZZARD = true, RAID = true, FLAT = true },
  colorMode = { CLASS = true, HEALTH = true },
  healthText = { NONE = true, DEFICIT = true, PERCENT = true },
}

Database.WATCH_TARGETS = { ALL = true, TANKS = true }

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
}

local BINDING_FIELDS = {
  spell = { kind = true, spellID = true, rank = true, fallbackSpellID = true },
  macro = { kind = true, text = true },
  target = { kind = true },
  menu = { kind = true },
}

local WATCHED_FIELDS = { spellID = true, groupSpellID = true, targets = true }

local MAX_MACRO_LENGTH = 1023

Database.DEFAULT_MINIMAP_ANGLE = 225

function Database.DefaultProfile()
  return {
    bindings = {},
    frames = {
      width = 110, height = 34, spacing = 2, columns = 8, unitsPerColumn = 5,
      sortBy = "GROUP", growth = "DOWN",
      showSolo = true, showInParty = true, showInRaid = true,
      showTanks = true, showPets = false, showTarget = true, showFocus = true,
      hideBlizzard = true, locked = true, castOnDown = false,
      texture = "BLIZZARD", colorMode = "CLASS", healthText = "DEFICIT", outOfRangeAlpha = 0.4,
    },
    auras = {
      hotsEnabled = true, hotsMax = 4, hotSpellIDs = {},
      debuffsEnabled = true, debuffsMax = 2, debuffsDispellableOnly = true, iconSize = 14,
    },
    buffs = { enabled = true, watched = {} },
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
-- Cada campo corregido se añade a 'fixes' con su ruta (p. ej. "frames.width").
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
  return profile
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
  for _, section in ipairs({ "frames", "auras", "buffs" }) do
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
