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

-- Vista previa
L.PREVIEW_COMBAT = "La vista previa no está disponible en combate."

-- Ventana de configuración
L.CONFIG_TITLE = "Healsilus"
L.CONFIG_PENDING = "Pendiente: se aplicará al salir de combate"
L.PROFILES_ACTIVE = "Perfil activo: %s"
L.SOURCE_SPEC = "%s · especialización %d"
L.SOURCE_CHARACTER = "%s · perfil propio"
L.SOURCE_CLASS = "%s · perfil de clase"
L.SETTINGS_DESCRIPTION = "Marcos de curación con click-casting para WoW Forever. Escribe /hs para abrir la configuración cuando quieras."
L.SETTINGS_OPEN = "Abrir la configuración de Healsilus"
L.ACCEPT = "Aceptar"
L.CLOSE = "Cerrar"
L.MENU_UNAVAILABLE = "Los menús no están disponibles en este cliente (consulta /hs diag)."
L.REMOVE = "Quitar"
L.ADD_SPELL = "Añadir hechizo"
L.LIST_FULL = "La lista está llena (12)."
L.NONE = "Ninguna"
