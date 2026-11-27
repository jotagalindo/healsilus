-- Healsilus: tabla compartida del addon y utilidades seguras ante valores secretos.
-- Este fichero solo usa APIs de WoW dentro de funciones, para poder probarse fuera del juego.
local addonName, ns = ...

ns.name = addonName
-- Debe coincidir con "## Version" de Healsilus.toc (lo comprueba tests/test_init.lua).
ns.version = "0.0.2"
-- Carpeta de las texturas propias (logo e iconos de la ventana), con el nombre real de la carpeta.
ns.MEDIA_PATH = "Interface\\AddOns\\" .. tostring(addonName) .. "\\Media\\"

-- Global del addon: acceso desde /run y desde los comandos de depuración. Los otros globales son
-- HealsilusDB, los SLASH_HEALSILUS* y las funciones del desplegable de addons (UI/MinimapButton.lua).
Healsilus = ns

-- Prefijos de modificador en orden canónico (alt, ctrl, shift) y botones del ratón admitidos.
-- La clave de una asignación es prefijo .. botón: "1", "shift-1", "alt-ctrl-2"...
ns.BINDING_PREFIXES = { "", "alt-", "ctrl-", "shift-", "alt-ctrl-", "alt-shift-", "ctrl-shift-", "alt-ctrl-shift-" }
ns.MOUSE_BUTTONS = { "1", "2", "3", "4", "5" }

-- Traducciones: los ficheros de Locales rellenan esta tabla. Si falta una clave, se muestra la clave.
ns.L = setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

-- Errores y correcciones registrados para /hs diag. Nunca se tragan en silencio.
ns.Diagnostics = { errors = {}, reported = {} }

-- Solo sirve para elegir ruta de dibujo; jamás para leer el contenido de un secreto.
function ns.IsSecret(value)
  if issecretvalue then
    return issecretvalue(value) == true
  end
  return false
end

-- ¿Se pueden leer ahora las auras? Solo fuera de combate y cuando el cliente no las devuelve secretas.
-- Ojo: C_Secrets.HasSecretRestrictions() no vale para esto: dice si la versión del juego tiene
-- restricciones (en Forever, siempre), no si en este momento las auras salen como secretos.
function ns.CanReadAuras()
  if InCombatLockdown() then
    return false
  end
  if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() == true then
    return false
  end
  return C_UnitAuras ~= nil
end

function ns.DeepCopy(value)
  if type(value) ~= "table" then
    return value
  end
  local copy = {}
  for key, entry in pairs(value) do
    copy[ns.DeepCopy(key)] = ns.DeepCopy(entry)
  end
  return copy
end

function ns.Print(message)
  print("|cff33ff99Healsilus:|r " .. tostring(message))
end

function ns.Debug(message)
  if HealsilusDB and HealsilusDB.debug then
    ns.Print("[debug] " .. tostring(message))
  end
end

-- Guarda el error con su contexto y lo muestra en el chat la primera vez que aparece ese contexto.
function ns.RecordError(context, message)
  local errors = ns.Diagnostics.errors
  errors[#errors + 1] = { context = context, message = tostring(message) }
  if not ns.Diagnostics.reported[context] then
    ns.Diagnostics.reported[context] = true
    ns.Print(string.format(ns.L.ERROR_RECORDED, context, tostring(message)))
  end
end

function ns.CharacterKey()
  local name = UnitName("player")
  local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or GetRealmName()
  return tostring(name) .. "-" .. tostring(realm)
end

-- Registrar un evento que el cliente no conoce da error: se comprueba antes cuando la API existe.
function ns.IsEventValid(event)
  if C_EventUtils and C_EventUtils.IsEventValid then
    return C_EventUtils.IsEventValid(event) == true
  end
  return true
end
