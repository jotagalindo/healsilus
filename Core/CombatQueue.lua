-- Cola de combate: todo lo que toca marcos o atributos seguros pasa por aquí.
-- Fuera de combate se ejecuta ya; en combate se guarda por clave y se ejecuta al salir.
local _, ns = ...

local CombatQueue = { pending = {}, order = {} }
ns.CombatQueue = CombatQueue

function CombatQueue:Run(key, action)
  if not InCombatLockdown() then
    action()
    return true
  end
  if not self.pending[key] then
    self.order[#self.order + 1] = key
  end
  self.pending[key] = action
  ns.Events:Fire("COMBAT_QUEUE_CHANGED", #self.order)
  return false
end

function CombatQueue:Count()
  return #self.order
end

function CombatQueue:Flush()
  local order, pending = self.order, self.pending
  self.order, self.pending = {}, {}
  for _, key in ipairs(order) do
    local ok, failure = pcall(pending[key])
    if not ok then
      ns.RecordError("CombatQueue:" .. key, failure)
    end
  end
  ns.Events:Fire("COMBAT_QUEUE_CHANGED", #self.order)
end

ns.Events:RegisterGameEvent("PLAYER_REGEN_ENABLED", function()
  CombatQueue:Flush()
  ns.Events:Fire("COMBAT_ENDED")
end)

-- Se dispara justo antes de que empiece el bloqueo: aún se pueden hacer cambios seguros.
ns.Events:RegisterGameEvent("PLAYER_REGEN_DISABLED", function()
  ns.Events:Fire("COMBAT_STARTED")
end)
