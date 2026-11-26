-- Override de dispel (como el SmartCast de HealBot, opcional): fuera de combate, si una barra tiene un
-- debuff que puedes quitar, cualquier clic sobre ella lanza el hechizo que lo quita. En combate no se
-- puede leer los debuffs ni cambiar clics: al empezar el combate todos los clics vuelven a lo normal.
local _, ns = ...

local DispelOverride = { dirty = {}, flushScheduled = false }
ns.DispelOverride = DispelOverride

local FLUSH_DELAY = 0.3
local MAX_DEBUFFS = 40

function DispelOverride.CanRead()
  if InCombatLockdown() then
    return false
  end
  if C_Secrets and C_Secrets.HasSecretRestrictions and C_Secrets.HasSecretRestrictions() then
    return false
  end
  return C_UnitAuras ~= nil and C_UnitAuras.GetAuraDataByIndex ~= nil
end

-- Tipos de los debuffs que tú puedes quitar (filtro "RAID"), como conjunto { Curse = true, ... }.
function DispelOverride.DebuffTypes(unit)
  local types = {}
  for position = 1, MAX_DEBUFFS do
    local aura = C_UnitAuras.GetAuraDataByIndex(unit, position, "HARMFUL|RAID")
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

function DispelOverride:Evaluate(button)
  local profile = ns.Profiles.active
  if not profile or not profile.clicks.dispelOverride or not button.unit then
    if button.healsilusOverride then
      ns.ClickCast:SetDispelOverride(button, nil)
    end
    return
  end
  if not DispelOverride.CanRead() then
    return
  end
  local cure = DispelOverride.CureFor(DispelOverride.DebuffTypes(button.unit), profile.bindings)
  if cure ~= button.healsilusOverride then
    ns.ClickCast:SetDispelOverride(button, cure)
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
