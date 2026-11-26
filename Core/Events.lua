-- Bus de eventos: internos del addon (Register/Fire) y del juego (RegisterGameEvent) en un único marco.
-- Los errores de un receptor no se capturan: el cliente los muestra con su traza.
local _, ns = ...

local Events = { callbacks = {}, gameHandlers = {} }
ns.Events = Events

local eventFrame = CreateFrame("Frame")
Events.frame = eventFrame

function Events:Register(name, callback)
  local list = self.callbacks[name]
  if not list then
    list = {}
    self.callbacks[name] = list
  end
  list[#list + 1] = callback
end

function Events:Fire(name, ...)
  local list = self.callbacks[name]
  if not list then
    return
  end
  for _, callback in ipairs(list) do
    callback(...)
  end
end

-- Devuelve false si el cliente no conoce el evento (algunos de Mainline no existen en Forever).
function Events:RegisterGameEvent(event, callback)
  if not ns.IsEventValid(event) then
    return false
  end
  local list = self.gameHandlers[event]
  if not list then
    list = {}
    self.gameHandlers[event] = list
    eventFrame:RegisterEvent(event)
  end
  list[#list + 1] = callback
  return true
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
  local list = Events.gameHandlers[event]
  if not list then
    return
  end
  for _, callback in ipairs(list) do
    callback(event, ...)
  end
end)
