-- Textos en español (clientes esES y esMX).
local _, ns = ...

local locale = GetLocale()
if locale ~= "esES" and locale ~= "esMX" then
  return
end

local L = ns.L

L.ERROR_RECORDED = "error en %s: %s (consulta /hs diag)"
