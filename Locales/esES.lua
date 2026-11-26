-- Textos en español (clientes esES y esMX).
local _, ns = ...

local locale = GetLocale()
if locale ~= "esES" and locale ~= "esMX" then
  return
end

local L = ns.L

L.ERROR_RECORDED = "error en %s: %s (consulta /hs diag)"

-- Barras
L.STATUS_OFFLINE = "Desconectado"
L.STATUS_DEAD = "Muerto"
L.TOOLTIP_MISSING_BUFFS = "Le falta: %s"

-- Anclas
L.ANCHOR_PARTY = "Healsilus: grupo/banda"
L.ANCHOR_TANKS = "Healsilus: tanques"
L.ANCHOR_PETS = "Healsilus: mascotas"
L.ANCHOR_TARGET = "Healsilus: objetivo"
L.ANCHOR_FOCUS = "Healsilus: foco"
