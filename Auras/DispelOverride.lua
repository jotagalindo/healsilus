-- Override de clics (como el SmartCast de HealBot, opcional), fuera de combate:
--  · dispel: si una barra tiene un debuff que puedes quitar, cualquier clic lanza el hechizo que lo quita.
--  · buff: si a una barra le falta uno de tus buffs vigilados, cualquier clic se lo pone.
-- Si se cumplen los dos, manda el dispel. En combate no se pueden leer auras ni cambiar clics: al
-- empezar el combate todos los clics vuelven a lo normal.
local _, ns = ...

local DispelOverride = { dirty = {}, flushScheduled = false }
ns.DispelOverride = DispelOverride

local FLUSH_DELAY = 0.3
local MAX_DEBUFFS = 40

function DispelOverride.CanRead()
  return ns.CanReadAuras() and C_UnitAuras.GetAuraDataByIndex ~= nil
end

-- Tipos de todos los debuffs de la unidad, como conjunto { Curse = true, ... }. Se leen todos ("HARMFUL")
-- en vez de fiarse del filtro "RAID", que en el cliente de Forever no siempre deja solo los que puedes
-- quitar: CureFor ya descarta los tipos para los que no conoces ningún hechizo.
-- nil si el cliente devuelve las auras como secretos: entonces no se sabe nada.
function DispelOverride.DebuffTypes(unit)
  local types = {}
  for position = 1, MAX_DEBUFFS do
    local aura = C_UnitAuras.GetAuraDataByIndex(unit, position, "HARMFUL")
    if ns.IsSecret(aura) then
      return nil
    end
    if not aura then
      break
    end
    local dispelName = aura.dispelName
    if dispelName and not ns.IsSecret(dispelName) then
      types[dispelName] = true
    end
  end
  return types
end

-- Hechizo para quitar el primer tipo presente (orden de la pestaña Debuffs): el asignado a ese tipo
-- o, si no hay clic para él, el primero que conoces. nil si no puedes quitar ninguno.
function DispelOverride.CureFor(types, bindings)
  local clicks = ns.Dispels.ClicksFor(bindings)
  for _, dispelType in ipairs(ns.Database.DISPEL_TYPES) do
    if types[dispelType] then
      local key = clicks[dispelType][1]
      local cure = key and ns.ClickCast.ResolveSpell(bindings[key])
      if not cure then
        local known = ns.Dispels.KnownSpellsFor(dispelType)[1]
        cure = known and (ns.Spells:CastString(known.spellID))
      end
      if cure then
        return cure
      end
    end
  end
  return nil
end

-- Buff que pone el override de buff: el primero que le falta a la barra (Auras/MissingBuffs.lua).
function DispelOverride.BuffFor(missing)
  return missing and missing[1] or nil
end

function DispelOverride:Evaluate(button)
  local profile = ns.Profiles.active
  local clicks = profile and profile.clicks
  if not clicks or not (clicks.dispelOverride or clicks.buffOverride) or not button.unit then
    if button.healsilusOverride then
      ns.ClickCast:SetDispelOverride(button, nil)
    end
    return
  end
  if not DispelOverride.CanRead() then
    return
  end
  local castString
  if clicks.dispelOverride then
    local types = DispelOverride.DebuffTypes(button.unit)
    if not types then
      return
    end
    castString = DispelOverride.CureFor(types, profile.bindings)
  end
  if not castString and clicks.buffOverride then
    castString = DispelOverride.BuffFor(button.healsilusMissing)
  end
  if castString ~= button.healsilusOverride then
    ns.ClickCast:SetDispelOverride(button, castString)
  end
end

function DispelOverride:Flush()
  self.flushScheduled = false
  local dirty = self.dirty
  self.dirty = {}
  for button in pairs(dirty) do
    self:Evaluate(button)
  end
end

function DispelOverride:MarkDirty(button)
  if not DispelOverride.CanRead() then
    return
  end
  self.dirty[button] = true
  if self.flushScheduled then
    return
  end
  self.flushScheduled = true
  C_Timer.After(FLUSH_DELAY, function()
    DispelOverride:Flush()
  end)
end

function DispelOverride:RefreshAll()
  if not ns.UnitButton then
    return
  end
  for button in pairs(ns.UnitButton.buttons) do
    self:Evaluate(button)
  end
end

-- PLAYER_REGEN_DISABLED llega justo antes del bloqueo de combate: aún se pueden devolver los clics.
function DispelOverride:RestoreAll()
  if not ns.UnitButton then
    return
  end
  for button in pairs(ns.UnitButton.buttons) do
    if button.healsilusOverride then
      ns.ClickCast:SetDispelOverride(button, nil)
    end
  end
end

ns.Events:Register("COMBAT_STARTED", function()
  DispelOverride:RestoreAll()
end)

local function RefreshAll()
  DispelOverride:RefreshAll()
end
ns.Events:Register("COMBAT_ENDED", RefreshAll)
ns.Events:Register("CLICKS_APPLIED", RefreshAll)
ns.Events:Register("SPELLBOOK_UPDATED", RefreshAll)
ns.Events:Register("SETTINGS_CHANGED", function(section)
  if section == "clicks" or section == "bindings" then
    RefreshAll()
  end
end)
