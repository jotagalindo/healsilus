-- /hs diag: qué APIs existen en este cliente, autopruebas, IDs de hechizo sin resolver y errores guardados.
-- Sirve para comprobar en el juego los puntos del diseño que no se pueden verificar fuera de él.
local _, ns = ...
local L = ns.L

local Diagnostics = ns.Diagnostics

local API_CHECKS = {
  { "CreateUnitHealPredictionCalculator", function() return CreateUnitHealPredictionCalculator end },
  { "UnitGetDetailedHealPrediction", function() return UnitGetDetailedHealPrediction end },
  { "UnitHealthPercent", function() return UnitHealthPercent end },
  { "UnitHealthMissing", function() return UnitHealthMissing end },
  { "AbbreviateLargeNumbers", function() return AbbreviateLargeNumbers end },
  { "C_CurveUtil.CreateColorCurve", function() return C_CurveUtil and C_CurveUtil.CreateColorCurve end },
  { "issecretvalue", function() return issecretvalue end },
  { "C_UnitAuras.GetAuraDataBySpellName", function() return C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName end },
  { "C_Secrets.HasSecretRestrictions", function() return C_Secrets and C_Secrets.HasSecretRestrictions end },
  { "C_SpellBook.GetSpellBookItemInfo", function() return C_SpellBook and C_SpellBook.GetSpellBookItemInfo end },
  { "C_SpecializationInfo.GetActiveSpecGroup", function() return C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup end },
  { "GetActiveTalentGroup", function() return GetActiveTalentGroup end },
  { "MenuUtil.CreateContextMenu", function() return MenuUtil and MenuUtil.CreateContextMenu end },
  { "Settings.RegisterCanvasLayoutCategory", function() return Settings and Settings.RegisterCanvasLayoutCategory end },
  { "C_EventUtils.IsEventValid", function() return C_EventUtils and C_EventUtils.IsEventValid end },
  { "RegisterStateDriver", function() return RegisterStateDriver end },
}

local EVENT_CHECKS = {
  "PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED", "UNIT_IN_RANGE_UPDATE",
  "UNIT_HEAL_PREDICTION", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_THREAT_SITUATION_UPDATE",
}

local function Status(present)
  return present and L.DIAG_OK or L.DIAG_MISSING
end

-- IDs usados por el perfil (y por el perfil de serie del druida) que el cliente no reconoce.
function Diagnostics.UnresolvedSpells(profile)
  local spellIDs = {}
  for _, spellID in pairs(ns.DRUID_SPELLS) do
    spellIDs[spellID] = true
  end
  for _, binding in pairs(profile.bindings) do
    if binding.kind == "spell" then
      spellIDs[binding.spellID] = true
      if binding.fallbackSpellID then
        spellIDs[binding.fallbackSpellID] = true
      end
    end
  end
  for spellID in pairs(profile.auras.hotSpellIDs) do
    spellIDs[spellID] = true
  end
  for _, entry in ipairs(profile.buffs.watched) do
    spellIDs[entry.spellID] = true
    if entry.groupSpellID then
      spellIDs[entry.groupSpellID] = true
    end
  end
  local missing = {}
  for spellID in pairs(spellIDs) do
    if not ns.Spells:GetName(spellID) then
      missing[#missing + 1] = tostring(spellID)
    end
  end
  table.sort(missing)
  return missing
end

function Diagnostics:Run()
  local version, build, _, interface = GetBuildInfo()
  ns.Print(string.format(L.DIAG_HEADER, ns.version, tostring(version), tostring(build), tostring(interface)))
  for _, check in ipairs(API_CHECKS) do
    ns.Print(check[1] .. ": " .. Status(check[2]() ~= nil))
  end
  for _, event in ipairs(EVENT_CHECKS) do
    ns.Print(string.format(L.DIAG_EVENT, event, Status(ns.IsEventValid(event))))
  end
  ns.Print(string.format(L.DIAG_AURA_CONTAINER, Status(ns.Containers:IsSupported())))
  ns.Print(string.format(L.DIAG_ALPHA_BOOLEAN, Status(ns.UnitButton.alphaFromBooleanWorks)))
  local missing = Diagnostics.UnresolvedSpells(ns.Profiles.active)
  if #missing == 0 then
    ns.Print(L.DIAG_SPELLS_OK)
  else
    ns.Print(string.format(L.DIAG_SPELLS_MISSING, table.concat(missing, ", ")))
  end
  for _, header in ipairs(ns.Headers.list) do
    ns.Print(string.format(L.DIAG_HEADER_BUTTONS, header.healsilusKind, ns.Headers:CountButtons(header)))
  end
  ns.Print(string.format(L.DIAG_PROFILE, tostring(ns.Profiles.source), ns.CombatQueue:Count()))
  if #ns.Database.fixes > 0 then
    ns.Print(string.format(L.DIAG_FIXES, table.concat(ns.Database.fixes, ", ")))
  end
  if #self.errors == 0 then
    ns.Print(L.DIAG_NO_ERRORS)
    return
  end
  for position, entry in ipairs(self.errors) do
    ns.Print(string.format("%d. %s: %s", position, entry.context, entry.message))
  end
end
