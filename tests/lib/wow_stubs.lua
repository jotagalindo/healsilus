-- Entorno falso de WoW para las pruebas: solo lo que usa la lógica del addon.
-- Los secretos falsos lanzan error si se operan, comparan o indexan, como en el cliente real.
local Stubs = {}

local SecretMeta = {}
local function Forbidden()
  error("secret value misuse", 2)
end
for _, event in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm", "__concat",
  "__len", "__lt", "__le", "__eq", "__call", "__index", "__newindex" }) do
  SecretMeta[event] = Forbidden
end

function Stubs.MakeSecret()
  return setmetatable({}, SecretMeta)
end

function Stubs.IsSecret(value)
  return type(value) == "table" and getmetatable(value) == SecretMeta
end

-- Objeto permisivo: cualquier método existe y devuelve otro objeto permisivo.
local MockMeta = {}
MockMeta.__index = function(mock, key)
  local method = function()
    return Stubs.NewMock()
  end
  rawset(mock, key, method)
  return method
end
MockMeta.__call = function()
  return Stubs.NewMock()
end

function Stubs.NewMock()
  return setmetatable({}, MockMeta)
end

local FrameFallback = {
  __index = function()
    return function()
      return nil
    end
  end,
}

local function NewFrame(state, frameType, name, parent)
  local frame = {
    frameType = frameType, name = name, parent = parent, events = {}, scripts = {},
    attributes = {}, shown = true, alpha = 1,
  }
  function frame:RegisterEvent(event)
    self.events[event] = true
  end
  function frame:RegisterUnitEvent(event, ...)
    self.events[event] = { ... }
  end
  function frame:UnregisterEvent(event)
    self.events[event] = nil
  end
  function frame:UnregisterAllEvents()
    self.events = {}
  end
  function frame:SetScript(kind, handler)
    self.scripts[kind] = handler
  end
  function frame:GetScript(kind)
    return self.scripts[kind]
  end
  function frame:HookScript(kind, handler)
    local previous = self.scripts[kind]
    self.scripts[kind] = function(...)
      if previous then
        previous(...)
      end
      handler(...)
    end
  end
  function frame:SetAttribute(key, value)
    self.attributes[key] = value
  end
  function frame:GetAttribute(key)
    return self.attributes[key]
  end
  function frame:Show()
    self.shown = true
  end
  function frame:Hide()
    self.shown = false
  end
  function frame:SetShown(shown)
    self.shown = shown and true or false
  end
  function frame:IsShown()
    return self.shown
  end
  function frame:SetAlpha(alpha)
    self.alpha = alpha
  end
  function frame:GetAlpha()
    return self.alpha
  end
  function frame:GetName()
    return self.name
  end
  state.frames[#state.frames + 1] = frame
  if name then
    state.environment[name] = frame
  end
  return setmetatable(frame, FrameFallback)
end

local STANDARD_GLOBALS = {
  "assert", "error", "ipairs", "next", "pairs", "pcall", "select", "tonumber", "tostring", "type",
  "unpack", "xpcall", "setmetatable", "getmetatable", "rawget", "rawset", "rawequal",
  "string", "table", "math",
}

-- options: locale, classToken, spells ({[id] = {name=, icon=}}), spellbook ({ {spellID=, name=, subName=} }), permissive
function Stubs.NewEnvironment(options)
  options = options or {}
  local environment = {}
  local state = {
    inCombat = false, locale = options.locale or "enUS", playerName = "Arsilus", realm = "Bah",
    classToken = options.classToken or "DRUID", specGroup = 1, spells = options.spells or {},
    spellbook = options.spellbook or {}, printed = {}, frames = {}, timers = {}, environment = environment,
  }
  for _, name in ipairs(STANDARD_GLOBALS) do
    environment[name] = _G[name]
  end
  environment._G = environment
  environment.print = function(...)
    local parts = {}
    for position = 1, select("#", ...) do
      parts[position] = tostring((select(position, ...)))
    end
    state.printed[#state.printed + 1] = table.concat(parts, " ")
  end
  environment.wipe = function(target)
    for key in pairs(target) do
      target[key] = nil
    end
    return target
  end
  environment.tinsert = table.insert
  environment.tremove = table.remove
  environment.strtrim = function(text)
    return (string.gsub(text, "^%s*(.-)%s*$", "%1"))
  end
  environment.GetLocale = function()
    return state.locale
  end
  environment.InCombatLockdown = function()
    return state.inCombat
  end
  environment.UnitName = function(unit)
    if unit == "player" then
      return state.playerName
    end
    return nil
  end
  environment.GetRealmName = function()
    return state.realm
  end
  environment.GetNormalizedRealmName = function()
    return state.realm
  end
  environment.UnitClass = function(unit)
    if unit == "player" then
      return "Druid", state.classToken, 11
    end
    return nil
  end
  environment.issecretvalue = Stubs.IsSecret
  environment.CreateFrame = function(frameType, name, parent)
    return NewFrame(state, frameType, name, parent)
  end
  environment.UIParent = NewFrame(state, "Frame", "UIParent")
  environment.C_Timer = {
    After = function(delay, callback)
      state.timers[#state.timers + 1] = { delay = delay, callback = callback }
    end,
  }
  environment.C_Spell = {
    GetSpellInfo = function(spellID)
      local spell = state.spells[spellID]
      if not spell then
        return nil
      end
      return { name = spell.name, spellID = spellID, iconID = spell.icon or 136041 }
    end,
  }
  environment.Enum = {
    SpellBookSpellBank = { Player = 0, Pet = 1 },
    SpellBookItemType = { Spell = 1, FutureSpell = 2, Flyout = 4 },
  }
  environment.C_SpellBook = {
    GetNumSpellBookSkillLines = function()
      return 1
    end,
    GetSpellBookSkillLineInfo = function()
      return { name = "General", itemIndexOffset = 0, numSpellBookItems = #state.spellbook }
    end,
    GetSpellBookItemInfo = function(slot)
      local entry = state.spellbook[slot]
      if not entry then
        return nil
      end
      return {
        spellID = entry.spellID, name = entry.name, subName = entry.subName or "",
        itemType = entry.itemType or 1, isPassive = entry.isPassive or false, iconID = 136041,
      }
    end,
  }
  environment.C_SpecializationInfo = {
    GetActiveSpecGroup = function()
      return state.specGroup
    end,
  }
  environment.__state = state
  environment.__fireEvent = function(event, ...)
    for _, frame in ipairs(state.frames) do
      if frame.events[event] and frame.scripts.OnEvent then
        frame.scripts.OnEvent(frame, event, ...)
      end
    end
  end
  environment.__runTimers = function()
    local timers = state.timers
    state.timers = {}
    for _, timer in ipairs(timers) do
      timer.callback()
    end
  end
  if options.permissive then
    setmetatable(environment, {
      __index = function()
        return Stubs.NewMock()
      end,
    })
  end
  return environment
end

return Stubs
