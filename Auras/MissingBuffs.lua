-- Buffs que faltan: las auras solo se leen cuando el cliente lo permite (fuera de combate y sin restricciones).
-- En combate o en zonas restringidas el último resultado se queda congelado.
local _, ns = ...

local MissingBuffs = { dirty = {}, flushScheduled = false, resolved = {} }
ns.MissingBuffs = MissingBuffs

local FLUSH_DELAY = 0.5

-- watched: { { label, names = {...}, targets = "ALL"|"TANKS" } }; auraPresent(name) → boolean.
function MissingBuffs.Compute(watched, auraPresent, isTank)
  local missing = {}
  for _, entry in ipairs(watched) do
    if entry.targets == "ALL" or (entry.targets == "TANKS" and isTank) then
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
  if InCombatLockdown() then
    return false
  end
  if C_Secrets and C_Secrets.HasSecretRestrictions and C_Secrets.HasSecretRestrictions() then
    return false
  end
  return C_UnitAuras ~= nil and C_UnitAuras.GetAuraDataBySpellName ~= nil
end

local function IsTank(unit)
  if UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) == "TANK" then
    return true
  end
  if GetPartyAssignment and GetPartyAssignment("MAINTANK", unit) then
    return true
  end
  return false
end

function MissingBuffs:Render(button)
  local missing = button.healsilusMissing
  button.healsilus.missingMark:SetShown(missing ~= nil and #missing > 0)
end

function MissingBuffs:Clear(button)
  button.healsilusMissing = nil
  self:Render(button)
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
  button.healsilusMissing = MissingBuffs.Compute(self.resolved, function(name)
    return C_UnitAuras.GetAuraDataBySpellName(unit, name, "HELPFUL") ~= nil
  end, IsTank(unit))
  self:Render(button)
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
ns.Events:Register("SETTINGS_CHANGED", function(section)
  if section == "buffs" then
    RefreshAll()
  end
end)
ns.Events:RegisterGameEvent("GROUP_ROSTER_UPDATE", function()
  C_Timer.After(FLUSH_DELAY, function()
    if ns.Profiles.active then
      MissingBuffs:RefreshAll()
    end
  end)
end)
