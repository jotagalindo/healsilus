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

-- Pestaña Clics
L.TAB_CLICKS = "Clics"
L.CLICKS_HELP = "Arrastra un hechizo del libro a una casilla o haz clic izquierdo para elegirlo. El clic derecho la vacía. En rojo: hechizos que no has aprendido."
L.MODIFIER_NONE = "Sin modificador"
L.BUTTON_LEFT = "Izquierdo"
L.BUTTON_RIGHT = "Derecho"
L.BUTTON_MIDDLE = "Central"
L.BUTTON_4 = "Botón 4"
L.BUTTON_5 = "Botón 5"
L.BINDING_EMPTY = "-"
L.BINDING_DEFAULT_TARGET = "Objetivo (por defecto)"
L.BINDING_DEFAULT_MENU = "Menú (por defecto)"
L.BINDING_RANK = "%s (rango %d)"
L.BINDING_MACRO = "Macro"
L.BINDING_TARGET = "Objetivo"
L.BINDING_MENU = "Menú de unidad"
L.MENU_SPELL = "Hechizo"
L.MENU_MAX_RANK = "Rango máximo"
L.MENU_MACRO = "Macro..."
L.MENU_CLEAR = "Vaciar"
L.MACRO_TITLE = "Macro para este clic (usa [@mouseover] para apuntar a la barra)"
L.MACRO_TOO_LONG = "La macro es demasiado larga (máximo 1023 caracteres)."

-- Pestaña Marcos
L.TAB_FRAMES = "Marcos"
L.FRAMES_WIDTH = "Ancho"
L.FRAMES_HEIGHT = "Alto"
L.FRAMES_SPACING = "Separación"
L.FRAMES_COLUMNS = "Columnas"
L.FRAMES_UNITS_PER_COLUMN = "Unidades por columna"
L.FRAMES_RANGE_ALPHA = "Opacidad fuera de rango"
L.FRAMES_SORT = "Ordenar por"
L.SORT_GROUP = "Grupo"
L.SORT_CLASS = "Clase"
L.SORT_ROLE = "Rol"
L.FRAMES_GROWTH = "Crecimiento"
L.GROWTH_DOWN = "Hacia abajo"
L.GROWTH_RIGHT = "Hacia la derecha"
L.FRAMES_COLOR = "Color de la barra"
L.COLOR_CLASS = "Clase"
L.COLOR_HEALTH = "Según la vida"
L.FRAMES_HEALTH_TEXT = "Texto de vida"
L.TEXT_NONE = "Ninguno"
L.TEXT_DEFICIT = "Déficit"
L.TEXT_PERCENT = "Porcentaje"
L.FRAMES_TEXTURE = "Textura"
L.TEXTURE_BLIZZARD = "Blizzard"
L.TEXTURE_RAID = "Banda"
L.TEXTURE_FLAT = "Plana"
L.FRAMES_SHOW_SOLO = "Mostrar en solitario"
L.FRAMES_SHOW_TANKS = "Bloque de tanques"
L.FRAMES_SHOW_PETS = "Mascotas"
L.FRAMES_SHOW_TARGET = "Objetivo amistoso"
L.FRAMES_SHOW_FOCUS = "Foco amistoso"
L.FRAMES_HIDE_BLIZZARD = "Ocultar marcos de grupo/banda de Blizzard"
L.FRAMES_LOCKED = "Bloquear marcos"
L.FRAMES_CAST_ON_DOWN = "Lanzar al pulsar"
L.PREVIEW_LABEL = "Vista previa:"
L.PREVIEW_HIDE = "Ocultar"
L.RELOAD_TO_RESTORE = "Escribe /reload para restaurar del todo los marcos de Blizzard."

-- Pestañas Auras y Buffs
L.TAB_AURAS = "Auras"
L.AURAS_HOTS = "Mostrar mis HoTs"
L.AURAS_HOTS_MAX = "Máximo de HoTs"
L.AURAS_DEBUFFS = "Mostrar debuffs"
L.AURAS_DEBUFFS_MAX = "Máximo de debuffs"
L.AURAS_DISPELLABLE = "Solo debuffs que puedo quitar"
L.AURAS_ICON_SIZE = "Tamaño de icono"
L.AURAS_HOT_LIST = "HoTs vigilados"
L.TAB_BUFFS = "Buffs"
L.BUFFS_ENABLED = "Avisar de buffs que faltan (fuera de combate)"
L.BUFFS_LIST = "Buffs vigilados"
L.TARGETS_ALL = "Todos"
L.TARGETS_TANKS = "Solo tanques"
L.BUFFS_GROUP_VARIANT = "grupo: %s"
L.BUFFS_SET_GROUP = "Versión de grupo"
