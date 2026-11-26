-- Perfiles: elige el activo (especialización → PJ → clase → serie) y gestiona copiar, restablecer y sustituir.
-- El perfil activo es una tabla de HealsilusDB: la configuración la edita directamente.
local _, ns = ...

local Profiles = { active = nil, source = nil, characterKey = nil, classToken = nil }
ns.Profiles = Profiles

function Profiles.ActiveSpecGroup()
  if C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup then
    return C_SpecializationInfo.GetActiveSpecGroup() or 1
  end
  if GetActiveSpecGroup then
    return GetActiveSpecGroup() or 1
  end
  if GetActiveTalentGroup then
    return GetActiveTalentGroup() or 1
  end
  return 1
end

function Profiles.CreateClassDefault(classToken)
  local factory = ns.ClassDefaults and ns.ClassDefaults[classToken]
  local profile = factory and factory() or ns.Database.DefaultProfile()
  return ns.Database.NormalizeProfile(profile, {})
end

function Profiles.Resolve(db, characterKey, classToken, specIndex)
  local character = db.characters[characterKey]
  if character then
    if character.useSpecProfiles and character.specs[specIndex] then
      return character.specs[specIndex], "spec"
    end
    if character.useClassProfile == false and character.own then
      return character.own, "character"
    end
  end
  local classProfile = db.classProfiles[classToken]
  if not classProfile then
    classProfile = Profiles.CreateClassDefault(classToken)
    db.classProfiles[classToken] = classProfile
  end
  return classProfile, "class"
end

function Profiles:Initialize()
  local db = ns.Database.db
  self.characterKey = ns.CharacterKey()
  local _, classToken = UnitClass("player")
  self.classToken = classToken
  local character = db.characters[self.characterKey]
  if not character then
    character = { class = classToken, useClassProfile = true, useSpecProfiles = false, specs = {} }
    db.characters[self.characterKey] = character
  end
  character.class = classToken
  self:Refresh(true)
end

function Profiles:Character()
  return ns.Database.db.characters[self.characterKey]
end

function Profiles:Refresh(force)
  local profile, source = Profiles.Resolve(ns.Database.db, self.characterKey, self.classToken, Profiles.ActiveSpecGroup())
  if force or profile ~= self.active or source ~= self.source then
    self.active, self.source = profile, source
    ns.Events:Fire("PROFILE_CHANGED", profile, source)
  end
  return profile, source
end

-- Sustituye el perfil guardado en el hueco activo (especialización, PJ o clase).
function Profiles:ReplaceActive(profile)
  local character = self:Character()
  if self.source == "spec" then
    character.specs[Profiles.ActiveSpecGroup()] = profile
  elseif self.source == "character" then
    character.own = profile
  else
    ns.Database.db.classProfiles[self.classToken] = profile
  end
  self:Refresh(true)
end

function Profiles:ResetActive()
  self:ReplaceActive(Profiles.CreateClassDefault(self.classToken))
end

function Profiles:CopyFrom(sourceProfile)
  self:ReplaceActive(ns.DeepCopy(sourceProfile))
end

function Profiles:SetUseClassProfile(enabled)
  local character = self:Character()
  character.useClassProfile = enabled
  if not enabled and not character.own then
    local classProfile = ns.Database.db.classProfiles[self.classToken] or Profiles.CreateClassDefault(self.classToken)
    character.own = ns.DeepCopy(classProfile)
  end
  self:Refresh()
end

function Profiles:SetUseSpecProfiles(enabled)
  local character = self:Character()
  character.useSpecProfiles = enabled
  if enabled then
    local group = Profiles.ActiveSpecGroup()
    if not character.specs[group] then
      character.specs[group] = ns.DeepCopy(self.active)
    end
  end
  self:Refresh()
end

local function SourceSortKey(source)
  return source.kind .. ":" .. (source.classToken or source.characterKey or "") .. ":" .. tostring(source.specIndex or 0)
end

-- Todos los perfiles guardados salvo el activo: sirven de origen para "Copiar desde…".
function Profiles:ListCopySources()
  local db = ns.Database.db
  local sources = {}
  for classToken, profile in pairs(db.classProfiles) do
    if profile ~= self.active then
      sources[#sources + 1] = { kind = "class", classToken = classToken, profile = profile }
    end
  end
  for characterKey, character in pairs(db.characters) do
    if character.own and character.own ~= self.active then
      sources[#sources + 1] = { kind = "character", characterKey = characterKey, profile = character.own }
    end
    for specIndex, profile in pairs(character.specs) do
      if profile ~= self.active then
        sources[#sources + 1] = { kind = "spec", characterKey = characterKey, specIndex = specIndex, profile = profile }
      end
    end
  end
  table.sort(sources, function(left, right)
    return SourceSortKey(left) < SourceSortKey(right)
  end)
  return sources
end
