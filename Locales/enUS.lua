-- Textos en inglés: se cargan siempre y sirven de respaldo para cualquier idioma.
local _, ns = ...
local L = ns.L

L.ERROR_RECORDED = "error in %s: %s (see /hs diag)"

-- Barras
L.STATUS_OFFLINE = "Offline"
L.STATUS_DEAD = "Dead"
L.TOOLTIP_MISSING_BUFFS = "Missing: %s"

-- Anclas
L.ANCHOR_PARTY = "Healsilus: party/raid"
L.ANCHOR_TANKS = "Healsilus: tanks"
L.ANCHOR_PETS = "Healsilus: pets"
L.ANCHOR_TARGET = "Healsilus: target"
L.ANCHOR_FOCUS = "Healsilus: focus"

-- Vista previa
L.PREVIEW_COMBAT = "Preview is not available in combat."

-- Ventana de configuración
L.CONFIG_TITLE = "Healsilus"
L.CONFIG_PENDING = "Pending: applies when combat ends"
L.PROFILES_ACTIVE = "Active profile: %s"
L.SOURCE_SPEC = "%s · specialization %d"
L.SOURCE_CHARACTER = "%s · own profile"
L.SOURCE_CLASS = "%s · class profile"
L.SETTINGS_DESCRIPTION = "Click-casting healing frames for WoW Forever. Type /hs to open the settings at any time."
L.SETTINGS_OPEN = "Open Healsilus settings"
L.ACCEPT = "Accept"
L.CLOSE = "Close"
L.MENU_UNAVAILABLE = "Menus are not available in this client (see /hs diag)."
L.REMOVE = "Remove"
L.ADD_SPELL = "Add spell"
L.LIST_FULL = "The list is full (12)."
L.NONE = "None"

-- Pestaña Clics
L.TAB_CLICKS = "Clicks"
L.CLICKS_HELP = "Drag a spell from your spellbook onto a cell, or left-click it to choose. Right-click clears it. Red cells use a spell you have not learned."
L.MODIFIER_NONE = "No modifier"
L.BUTTON_LEFT = "Left"
L.BUTTON_RIGHT = "Right"
L.BUTTON_MIDDLE = "Middle"
L.BUTTON_4 = "Button 4"
L.BUTTON_5 = "Button 5"
L.BINDING_EMPTY = "-"
L.BINDING_DEFAULT_TARGET = "Target (default)"
L.BINDING_DEFAULT_MENU = "Menu (default)"
L.BINDING_RANK = "%s (rank %d)"
L.BINDING_MACRO = "Macro"
L.BINDING_TARGET = "Target"
L.BINDING_MENU = "Unit menu"
L.MENU_SPELL = "Spell"
L.MENU_MAX_RANK = "Highest rank"
L.MENU_MACRO = "Macro..."
L.MENU_CLEAR = "Clear"
L.MACRO_TITLE = "Macro for this click (use [@mouseover] to target the bar)"
L.MACRO_TOO_LONG = "The macro is too long (1023 characters maximum)."
