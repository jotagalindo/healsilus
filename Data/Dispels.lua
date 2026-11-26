-- Hechizos que quitan debuffs y qué tipos quita cada uno (IDs de vanilla, rango 1).
-- Sirve para decirte en la pestaña Debuffs con qué clic quitas cada tipo; nunca para decidir qué lanzar.
local _, ns = ...

local Dispels = {}
ns.Dispels = Dispels

Dispels.SPELLS = {
  [2782] = { "Curse" },                       -- Druida: Quitar maldición
  [8946] = { "Poison" },                      -- Druida: Curar envenenamiento
  [2893] = { "Poison" },                      -- Druida: Suprimir veneno
  [527] = { "Magic" },                        -- Sacerdote: Disipar magia
  [528] = { "Disease" },                      -- Sacerdote: Curar enfermedad
  [552] = { "Disease" },                      -- Sacerdote: Suprimir enfermedad
  [1152] = { "Poison", "Disease" },           -- Paladín: Purificar
  [4987] = { "Magic", "Poison", "Disease" },  -- Paladín: Limpiar
  [526] = { "Poison" },                       -- Chamán: Curar envenenamiento
  [2870] = { "Disease" },                     -- Chamán: Curar enfermedad
  [475] = { "Curse" },                        -- Mago: Quitar maldición menor
}

-- Tipos que quita cada nombre de hechizo (los rangos comparten nombre).
local function TypesByName()
  local byName = {}
  for spellID, dispelTypes in pairs(Dispels.SPELLS) do
    local name = ns.Spells:GetName(spellID)
    if name then
      local types = byName[name] or {}
      for _, dispelType in ipairs(dispelTypes) do
        types[dispelType] = true
      end
      byName[name] = types
    end
  end
  return byName
end

-- Hechizos aprendidos que quitan un tipo (como los "Cure spells" de HealBot), ordenados por nombre.
-- Los rangos comparten nombre: se devuelve uno por nombre.
function Dispels.KnownSpellsFor(dispelType)
  local spells, seen = {}, {}
  for spellID, dispelTypes in pairs(Dispels.SPELLS) do
    for _, removed in ipairs(dispelTypes) do
      local name = removed == dispelType and ns.Spells:GetName(spellID)
      if name and not seen[name] and ns.Spells:IsKnown(spellID) then
        seen[name] = true
        spells[#spells + 1] = { spellID = spellID, name = name }
      end
    end
  end
  table.sort(spells, function(left, right)
    return left.name < right.name
  end)
  return spells
end

-- Orden en que se proponen clics libres para quitar debuffs: primero derecho e izquierdo con modificador.
local SUGGESTED_KEYS = {
  "shift-2", "ctrl-2", "alt-2", "shift-1", "ctrl-1", "alt-1", "shift-3", "ctrl-3", "alt-3", "4", "5",
}

function Dispels.SuggestKey(bindings)
  for _, key in ipairs(SUGGESTED_KEYS) do
    if not bindings[key] then
      return key
    end
  end
  return nil
end

function Dispels.Assign(bindings, key, spellID)
  bindings[key] = { kind = "spell", spellID = spellID }
end

-- Devuelve { Magic = { clave, ... }, Curse = {...}, ... } con las claves de clic en orden canónico.
function Dispels.ClicksFor(bindings)
  local byName = TypesByName()
  local clicks = {}
  for _, dispelType in ipairs(ns.Database.DISPEL_TYPES) do
    clicks[dispelType] = {}
  end
  for _, prefix in ipairs(ns.BINDING_PREFIXES) do
    for _, button in ipairs(ns.MOUSE_BUTTONS) do
      local key = prefix .. button
      local binding = bindings[key]
      if binding and binding.kind == "spell" then
        local covered = {}
        for _, spellID in ipairs({ binding.spellID, binding.fallbackSpellID }) do
          local name = ns.Spells:GetName(spellID)
          for dispelType in pairs(name and byName[name] or {}) do
            covered[dispelType] = true
          end
        end
        for _, dispelType in ipairs(ns.Database.DISPEL_TYPES) do
          if covered[dispelType] then
            local list = clicks[dispelType]
            list[#list + 1] = key
          end
        end
      end
    end
  end
  return clicks
end
