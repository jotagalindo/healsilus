-- Ventana de configuración: barra lateral con el logo y las pestañas, cabecera con el perfil activo,
-- el aviso de cambios pendientes y los atajos, y una tarjeta con el contenido de la pestaña elegida.
-- Las pestañas se registran desde UI/Tab*.lua en el orden de carga del TOC.
local _, ns = ...
local L = ns.L
local Widgets = ns.Widgets
local THEME = Widgets.THEME
local ColorValues = Widgets.ColorValues

local Config = { tabs = {}, tabOrder = {}, built = false, selected = nil }
ns.Config = Config

-- Las pestañas se diseñaron para un área de 780 × 444; la tarjeta la rodea con su margen interior.
local CONTENT_WIDTH, CONTENT_HEIGHT = 780, 444
local SIDEBAR_WIDTH, HEADER_HEIGHT, MARGIN = 168, 60, 14
local CARD_PADDING, CARD_TITLE_HEIGHT = 16, 34
local CARD_WIDTH = CONTENT_WIDTH + 2 * CARD_PADDING
local CARD_HEIGHT = CONTENT_HEIGHT + CARD_TITLE_HEIGHT + 2 * CARD_PADDING
local WIDTH = SIDEBAR_WIDTH + MARGIN + CARD_WIDTH + MARGIN
local HEIGHT = HEADER_HEIGHT + CARD_HEIGHT + MARGIN
local TAB_HEIGHT, TAB_GAP, TABS_TOP = 32, 4, -70
Config.SIZE = { width = WIDTH, height = HEIGHT, content = { CONTENT_WIDTH, CONTENT_HEIGHT } }

local LOGO = "Interface\\Icons\\Spell_Nature_HealingTouch"
-- Icono de cada pestaña en la barra lateral; una pestaña sin icono propio lleva el logo.
Config.TAB_ICONS = {
  clicks = "Interface\\Icons\\Spell_Holy_FlashHeal",
  frames = "Interface\\Icons\\Spell_Holy_PrayerOfHealing02",
  appearance = "Interface\\Icons\\INV_Misc_Gem_Variety_01",
  auras = "Interface\\Icons\\Spell_Nature_Rejuvenation",
  debuffs = "Interface\\Icons\\Spell_Nature_NullifyPoison",
  buffs = "Interface\\Icons\\Spell_Nature_Regeneration",
  styles = "Interface\\Icons\\INV_Scroll_03",
  profiles = "Interface\\Icons\\INV_Misc_Head_Human_01",
}

local function ClassName(classToken)
  return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classToken]) or tostring(classToken)
end

function Config.DescribeSource()
  local profiles = ns.Profiles
  if profiles.source == "spec" then
    return string.format(L.SOURCE_SPEC, profiles.characterKey, ns.Profiles.ActiveSpecGroup())
  end
  if profiles.source == "character" then
    return string.format(L.SOURCE_CHARACTER, profiles.characterKey)
  end
  return string.format(L.SOURCE_CLASS, ClassName(profiles.classToken))
end

function Config.DescribeCopySource(source)
  if source.kind == "class" then
    return string.format(L.SOURCE_CLASS, ClassName(source.classToken))
  end
  if source.kind == "character" then
    return string.format(L.SOURCE_CHARACTER, source.characterKey)
  end
  return string.format(L.SOURCE_SPEC, source.characterKey, source.specIndex)
end

function Config:RegisterTab(key, label, build, refresh)
  self.tabs[key] = { key = key, label = label, build = build, refresh = refresh }
  self.tabOrder[#self.tabOrder + 1] = key
end

-- Columna izquierda: logo, nombre con la etiqueta beta, una pestaña por fila y la versión abajo.
local function BuildSidebar(frame)
  local sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  sidebar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -3)
  sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
  sidebar:SetWidth(SIDEBAR_WIDTH)
  sidebar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
  sidebar:SetBackdropColor(ColorValues(THEME.sidebar))
  local edge = Widgets.Line(sidebar, THEME.border)
  edge:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", 0, 0)
  edge:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", 0, 0)
  edge:SetWidth(1)

  local logo = sidebar:CreateTexture(nil, "ARTWORK")
  logo:SetSize(30, 30)
  logo:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 14, -16)
  logo:SetTexture(LOGO)
  logo:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local logoBorder = Widgets.Line(sidebar, THEME.accent, "BORDER")
  logoBorder:SetPoint("TOPLEFT", logo, "TOPLEFT", -1, 1)
  logoBorder:SetPoint("BOTTOMRIGHT", logo, "BOTTOMRIGHT", 1, -1)
  local title = Widgets.Label(sidebar, L.CONFIG_TITLE, "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, -1)
  local badge = Widgets.Label(sidebar, "BETA", "GameFontHighlightSmall")
  badge:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
  badge:SetTextColor(ColorValues(THEME.badge))

  local version = Widgets.Label(sidebar, "v" .. tostring(ns.version) .. "  ·  /hs", "GameFontDisableSmall")
  version:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMLEFT", 14, 12)
  return sidebar
end

-- Franja superior derecha: perfil y estilo activos, aviso de pendientes y los atajos.
function Config:BuildHeader(frame)
  local sourceText = Widgets.Label(frame, "", "GameFontHighlight")
  sourceText:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDEBAR_WIDTH + MARGIN + 2, -18)
  sourceText:SetWordWrap(false)
  local pendingText = Widgets.Label(frame, L.CONFIG_PENDING, "GameFontHighlightSmall")
  pendingText:SetPoint("TOPLEFT", sourceText, "BOTTOMLEFT", 0, -5)
  pendingText:SetTextColor(ColorValues(THEME.badge))
  pendingText:Hide()

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -10)
  -- Atajos siempre a mano: modo mover (rejilla y relleno de ejemplo) y activar/desactivar Healsilus.
  local toggleButton = Widgets.Button(frame, "", 150, function()
    ns.Headers:SetEnabled(not ns.Headers.IsEnabled())
  end)
  toggleButton:SetHeight(26)
  toggleButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -44, -17)
  local moveButton = Widgets.Button(frame, L.CONFIG_MOVE_FRAMES, 130, function()
    ns.MoveMode:Start()
  end)
  moveButton:SetHeight(26)
  moveButton:SetPoint("RIGHT", toggleButton, "LEFT", -8, 0)
  moveButton:SetVariant("primary")
  sourceText:SetPoint("RIGHT", moveButton, "LEFT", -12, 0)

  local divider = Widgets.Line(frame, THEME.border)
  divider:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDEBAR_WIDTH + 1, -HEADER_HEIGHT + 4)
  divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -HEADER_HEIGHT + 4)
  divider:SetHeight(1)
  self.sourceText, self.pendingText, self.toggleButton = sourceText, pendingText, toggleButton
end

-- Tarjeta con el título de la pestaña elegida y el área donde se dibuja su contenido.
function Config:BuildCard(frame)
  local card = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  card:SetSize(CARD_WIDTH, CARD_HEIGHT)
  card:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDEBAR_WIDTH + MARGIN, -(HEADER_HEIGHT + 4))
  Widgets.Surface(card, THEME.card, THEME.border)
  local cardTitle = Widgets.Label(card, "", "GameFontNormalLarge")
  cardTitle:SetPoint("TOPLEFT", card, "TOPLEFT", CARD_PADDING, -CARD_PADDING)
  local underline = Widgets.Line(card, THEME.accent, "ARTWORK")
  underline:SetPoint("TOPLEFT", cardTitle, "BOTTOMLEFT", 0, -6)
  underline:SetSize(36, 2)
  local content = CreateFrame("Frame", nil, card)
  content:SetSize(CONTENT_WIDTH, CONTENT_HEIGHT)
  content:SetPoint("TOPLEFT", card, "TOPLEFT", CARD_PADDING, -(CARD_PADDING + CARD_TITLE_HEIGHT))
  self.cardTitle = cardTitle
  return content
end

function Config:Build()
  local frame = CreateFrame("Frame", "HealsilusConfigFrame", UIParent, "BackdropTemplate")
  frame:SetSize(WIDTH, HEIGHT)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  Widgets.Surface(frame, THEME.window, THEME.border)
  Widgets.AccentStrip(frame)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:Hide()
  table.insert(UISpecialFrames, "HealsilusConfigFrame")

  local sidebar = BuildSidebar(frame)
  self:BuildHeader(frame)
  local content = self:BuildCard(frame)
  for position, key in ipairs(self.tabOrder) do
    local tab = self.tabs[key]
    tab.button = Widgets.SidebarTab(sidebar, tab.label, self.TAB_ICONS[key] or LOGO, SIDEBAR_WIDTH - 16, function()
      Config:SelectTab(key)
    end)
    tab.button:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 8, TABS_TOP - (position - 1) * (TAB_HEIGHT + TAB_GAP))
    tab.panel = CreateFrame("Frame", nil, content)
    tab.panel:SetAllPoints(content)
    tab.panel:Hide()
    tab.build(tab.panel)
  end

  self.frame = frame
  self.built = true
  frame:SetScript("OnShow", function()
    Config:Refresh()
  end)
  self:SelectTab(self.tabOrder[1])
end

function Config:SelectTab(key)
  self.selected = key
  for tabKey, tab in pairs(self.tabs) do
    tab.panel:SetShown(tabKey == key)
    tab.button:SetSelected(tabKey == key)
  end
  if self.cardTitle and self.tabs[key] then
    self.cardTitle:SetText(self.tabs[key].label)
  end
  self:Refresh()
end

function Config:Toggle()
  if not self.built then
    self:Build()
  end
  self.frame:SetShown(not self.frame:IsShown())
end

function Config:UpdatePending()
  if self.built then
    self.pendingText:SetShown(ns.CombatQueue:Count() > 0)
  end
end

function Config:Refresh()
  if not self.built or not self.frame:IsShown() or not ns.Profiles.active then
    return
  end
  local header = string.format(L.PROFILES_ACTIVE, Config.DescribeSource())
  if ns.Styles and ns.Styles.activeName then
    header = header .. " · " .. string.format(L.CONFIG_STYLE, ns.Styles.activeName)
  end
  self.sourceText:SetText(header)
  local enabled = ns.Headers.IsEnabled()
  self.toggleButton:SetText(enabled and L.CONFIG_DISABLE or L.CONFIG_ENABLE)
  self.toggleButton:SetVariant(enabled and "danger" or "primary")
  self:UpdatePending()
  local tab = self.tabs[self.selected]
  if tab and tab.refresh then
    tab.refresh(tab.panel)
  end
end

function Config:Changed(section)
  ns.Events:Fire("SETTINGS_CHANGED", section)
  self:Refresh()
end

-- Página en Opciones → AddOns con un botón que abre la ventana propia.
function Config:RegisterSettingsCategory()
  if not Settings or not Settings.RegisterCanvasLayoutCategory or not Settings.RegisterAddOnCategory then
    ns.RecordError("Config:Settings", "Settings API missing")
    return
  end
  local panel = CreateFrame("Frame")
  local description = Widgets.Label(panel, L.SETTINGS_DESCRIPTION, "GameFontHighlight")
  description:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
  description:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
  local open = Widgets.Button(panel, L.SETTINGS_OPEN, 240, function()
    if SettingsPanel and SettingsPanel:IsShown() then
      HideUIPanel(SettingsPanel)
    end
    if not Config.built then
      Config:Build()
    end
    Config.frame:Show()
  end)
  open:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -12)
  local category = Settings.RegisterCanvasLayoutCategory(panel, "Healsilus")
  Settings.RegisterAddOnCategory(category)
  self.settingsCategory = category
end

ns.Events:Register("PROFILE_CHANGED", function()
  Config:Refresh()
end)

ns.Events:Register("COMBAT_QUEUE_CHANGED", function()
  Config:UpdatePending()
end)

ns.Events:Register("ADDON_TOGGLED", function()
  Config:Refresh()
end)
