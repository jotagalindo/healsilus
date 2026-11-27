-- Gestor de estilos: elige el estilo activo según la regla del perfil y la situación (solo, grupo,
-- banda de 10/20/40) y crea, duplica, renombra y borra estilos. Avisa con STYLE_CHANGED.
local _, ns = ...
local L = ns.L

local Styles = { active = nil, activeName = nil, context = "solo" }
ns.Styles = Styles

function Styles.Context()
  if IsInRaid and IsInRaid() then
    local members = GetNumGroupMembers and GetNumGroupMembers() or 40
    if members <= 10 then
      return "raid10"
    end
    if members <= 20 then
      return "raid20"
    end
    return "raid40"
  end
  if IsInGroup and IsInGroup() then
    return "party"
  end
  return "solo"
end

local function Store()
  return ns.Database.db.styles
end

local function CleanName(name)
  return (string.match(name, "^%s*(.-)%s*$"))
end

local function ReplaceRuleName(oldName, newName)
  ns.Database.EachStoredProfile(ns.Database.db, function(profile)
    if type(profile) == "table" and type(profile.styleRules) == "table" then
      for context, ruleName in pairs(profile.styleRules) do
        if ruleName == oldName then
          profile.styleRules[context] = newName
        end
      end
    end
  end)
end

-- Si la regla apunta a un estilo que ya no existe se usa el de serie (y se recrea si lo borraste).
function Styles:Resolve(profile, context)
  local styles = Store()
  local name = profile.styleRules[context]
  if name and styles[name] then
    return styles[name], name
  end
  name = L.STYLE_DEFAULT_NAME
  if not styles[name] then
    styles[name] = ns.StyleData.DefaultStyle()
  end
  return styles[name], name
end

function Styles:Refresh(force)
  local profile = ns.Profiles.active
  if not profile then
    return
  end
  self.context = Styles.Context()
  local style, name = self:Resolve(profile, self.context)
  if force or style ~= self.active or name ~= self.activeName then
    self.active, self.activeName = style, name
    ns.Events:Fire("STYLE_CHANGED", style, name)
  end
end

function Styles:Names()
  local names = {}
  for name in pairs(Store()) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

-- Primer nombre libre a partir de base: "Base", "Base 2", "Base 3"... (siempre de 40 caracteres o menos).
local MAX_BASE_LENGTH = 36

function Styles:UniqueName(base)
  base = string.sub(CleanName(base), 1, MAX_BASE_LENGTH)
  local styles = Store()
  if not styles[base] then
    return base
  end
  local suffix = 2
  while styles[base .. " " .. suffix] do
    suffix = suffix + 1
  end
  return base .. " " .. suffix
end

-- Devuelve el nombre creado, o nil y el motivo: "invalid name" o "name taken".
function Styles:Create(name, source)
  if not ns.StyleData.IsValidName(name) then
    return nil, "invalid name"
  end
  name = CleanName(name)
  if Store()[name] then
    return nil, "name taken"
  end
  Store()[name] = ns.StyleData.NormalizeStyle(ns.DeepCopy(source), {})
  ns.Events:Fire("STYLES_LIST_CHANGED")
  return name
end

function Styles:Rename(oldName, newName)
  local styles = Store()
  if not styles[oldName] then
    return nil, "unknown style"
  end
  if not ns.StyleData.IsValidName(newName) then
    return nil, "invalid name"
  end
  newName = CleanName(newName)
  if newName == oldName then
    return newName
  end
  if styles[newName] then
    return nil, "name taken"
  end
  styles[newName], styles[oldName] = styles[oldName], nil
  ReplaceRuleName(oldName, newName)
  ns.Events:Fire("STYLES_LIST_CHANGED")
  self:Refresh()
  return newName
end

-- Devuelve true, o nil y el motivo: "unknown style" o "last style".
function Styles:Delete(name)
  local styles = Store()
  if not styles[name] then
    return nil, "unknown style"
  end
  if #self:Names() <= 1 then
    return nil, "last style"
  end
  styles[name] = nil
  local fallback = styles[L.STYLE_DEFAULT_NAME] and L.STYLE_DEFAULT_NAME or self:Names()[1]
  ReplaceRuleName(name, fallback)
  ns.Events:Fire("STYLES_LIST_CHANGED")
  self:Refresh()
  return true
end

function Styles:SetRule(context, name)
  ns.Profiles.active.styleRules[context] = name
  self:Refresh()
end

local function RefreshWhenSafe()
  ns.CombatQueue:Run("styles:context", function()
    Styles:Refresh()
  end)
end

ns.Events:Register("PROFILE_CHANGED", function()
  Styles:Refresh(true)
end)
ns.Events:RegisterGameEvent("GROUP_ROSTER_UPDATE", RefreshWhenSafe)
ns.Events:RegisterGameEvent("PLAYER_ENTERING_WORLD", RefreshWhenSafe)
