-- Buffs que faltan: las auras solo se leen cuando el cliente lo permite (fuera de combate y sin auras
-- secretas, ver ns.CanReadAuras). En combate o en zonas restringidas el último resultado se queda congelado.
local _, ns = ...

local MissingBuffs = { dirty = {}, flushScheduled = false, resolved = {} }
ns.MissingBuffs = MissingBuffs

local FLUSH_DELAY = 0.5

local function AppliesTo(targets, who)
  return targets == "ALL"
    or (targets == "TANKS" and who.tank == true)
    or (targets == "HEALERS" and who.healer == true)
    or (targets == "SELF" and who.self == true)
end

-- watched: { { label, names = {...}, targets } }; auraPresent(name) → boolean;
-- who: { tank = bool, healer = bool, self = bool } de la unidad que se revisa.
function MissingBuffs.Compute(watched, auraPresent, who)
  local missing = {}
  for _, entry in ipairs(watched) do
    if AppliesTo(entry.targets, who) then
      local present = false
      for _, name in ipairs(entry.names) do
        if auraPresent(name) then
          present = true
          break
        end
      end
      if not present then
        missing[#missing + 1] = entry.label
      end
    end
  end
  return missing
end

function MissingBuffs:Resolve()
  local resolved = {}
  local buffs = ns.Profiles.active and ns.Profiles.active.buffs
  if buffs and buffs.enabled then
    for _, entry in ipairs(buffs.watched) do
      local name = ns.Spells:GetName(entry.spellID)
      if name then
        local names = { name }
        local groupName = entry.groupSpellID and ns.Spells:GetName(entry.groupSpellID)
        if groupName then
          names[#names + 1] = groupName
        end
        resolved[#resolved + 1] = { label = name, names = names, targets = entry.targets }
      end
    end
  end
  self.resolved = resolved
  return resolved
end

function MissingBuffs.CanRead()
  return ns.CanReadAuras() and C_UnitAuras.GetAuraDataBySpellName ~= nil
end

-- Un valor secreto no se puede comparar: cuenta como "no".
local function IsSet(value)
  return not ns.IsSecret(value) and value ~= nil and value ~= false
end

local function Role(unit)
  if not UnitGroupRolesAssigned then
    return nil
  end
  local role = UnitGroupRolesAssigned(unit)
  if ns.IsSecret(role) then
    return nil
  end
  return role
end

local function IsTank(unit)
  if Role(unit) == "TANK" then
    return true
  end
  if GetPartyAssignment and IsSet(GetPartyAssignment("MAINTANK", unit)) then
    return true
  end
  return false
end

-- Tras cambiar lo que le falta a una barra, el override de clics decide si cualquier clic pone el buff.
local function UpdateOverride(button)
  if ns.DispelOverride then
    ns.DispelOverride:Evaluate(button)
  end
end

-- Macro del clic "Poner el buff que falta": el primer buff que le falta, sobre la barra pulsada.
function MissingBuffs.BuffMacro(missing)
  if missing and missing[1] then
    return "/cast [@mouseover] " .. missing[1]
  end
  return ""
end

function MissingBuffs:Render(button)
  local missing = button.healsilusMissing
  button.healsilus.missingMark:SetShown(missing ~= nil and #missing > 0)
  if ns.ClickCast and ns.ClickCast.SetBuffMacro then
    ns.ClickCast:SetBuffMacro(button, MissingBuffs.BuffMacro(missing))
  end
  if ns.UnitButton and ns.UnitButton.UpdateColor and button.unit then
    ns.UnitButton:UpdateColor(button)
  end
end

function MissingBuffs:Clear(button)
  button.healsilusMissing = nil
  self:Render(button)
  UpdateOverride(button)
end

function MissingBuffs:Evaluate(button)
  if not button.healsilus then
    return
  end
  local unit = button.unit
  if #self.resolved == 0 or not unit then
    self:Clear(button)
    return
  end
  if not MissingBuffs.CanRead() then
    return
  end
  local connected = UnitIsConnected(unit)
  local dead = UnitIsDeadOrGhost(unit)
  if ns.IsSecret(connected) or ns.IsSecret(dead) then
    return
  end
  if not UnitExists(unit) or not connected or dead then
    self:Clear(button)
    return
  end
  -- Fuera de combate los datos de auras suelen ser legibles: se puede mirar cuánto le queda al buff.
  -- Si el cliente aun así devuelve un secreto, el resultado anterior se queda como estaba.
  local refreshSeconds = ns.Profiles.active.buffs.refreshBelow * 60
  local unreadable = false
  local function AuraPresent(name)
    local aura = C_UnitAuras.GetAuraDataBySpellName(unit, name, "HELPFUL")
    if ns.IsSecret(aura) then
      unreadable = true
      return true
    end
    if not aura then
      return false
    end
    local expirationTime = aura.expirationTime
    if refreshSeconds <= 0 or ns.IsSecret(expirationTime) or not expirationTime or expirationTime == 0 then
      return true
    end
    return expirationTime - GetTime() > refreshSeconds
  end
  local who = {
    tank = IsTank(unit),
    healer = Role(unit) == "HEALER",
    self = UnitIsUnit ~= nil and IsSet(UnitIsUnit(unit, "player")),
  }
  local missing = MissingBuffs.Compute(self.resolved, AuraPresent, who)
  if unreadable then
    return
  end
  button.healsilusMissing = missing
  self:Render(button)
  UpdateOverride(button)
end

function MissingBuffs:Flush()
  self.flushScheduled = false
  local dirty = self.dirty
  self.dirty = {}
  for button in pairs(dirty) do
    self:Evaluate(button)
  end
end

function MissingBuffs:MarkDirty(button)
  if not MissingBuffs.CanRead() then
    return
  end
  self.dirty[button] = true
  if self.flushScheduled then
    return
  end
  self.flushScheduled = true
  C_Timer.After(FLUSH_DELAY, function()
    MissingBuffs:Flush()
  end)
end

function MissingBuffs:RefreshAll()
  self:Resolve()
  if not ns.UnitButton then
    return
  end
  for button in pairs(ns.UnitButton.buttons) do
    self:Evaluate(button)
  end
end

local function RefreshAll()
  MissingBuffs:RefreshAll()
end
ns.Events:Register("PROFILE_CHANGED", RefreshAll)
ns.Events:Register("SPELLBOOK_UPDATED", RefreshAll)
ns.Events:Register("COMBAT_ENDED", RefreshAll)
ns.Events:Register("CLICKS_APPLIED", RefreshAll)
ns.Events:Register("SETTINGS_CHANGED", function(section)
  if section == "buffs" then
    RefreshAll()
  end
end)
-- Cambios de grupo y de zona (al entrar o salir de una instancia cambia qué se puede leer).
local function RefreshSoon()
  C_Timer.After(FLUSH_DELAY, function()
    if ns.Profiles.active then
      MissingBuffs:RefreshAll()
    end
  end)
end
ns.Events:RegisterGameEvent("GROUP_ROSTER_UPDATE", RefreshSoon)
ns.Events:RegisterGameEvent("PLAYER_ENTERING_WORLD", RefreshSoon)
