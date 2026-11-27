-- Ventana de configuración: cabecera con el perfil activo, aviso de cambios pendientes y pestañas.
-- Las pestañas se registran desde UI/Tab*.lua en el orden de carga del TOC.
local _, ns = ...
local L = ns.L
local Widgets = ns.Widgets

local Config = { tabs = {}, tabOrder = {}, built = false, selected = nil }
ns.Config = Config

local WIDTH, HEIGHT = 820, 560
-- Ocho pestañas caben en el ancho de la ventana: 20 + 8 × (94 + 4) = 804.
local TAB_WIDTH = 94

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

function Config:Build()
  local frame = CreateFrame("Frame", "HealsilusConfigFrame", UIParent, "BackdropTemplate")
  frame:SetSize(WIDTH, HEIGHT)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetBackdrop(Widgets.DIALOG_BACKDROP)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:Hide()
  table.insert(UISpecialFrames, "HealsilusConfigFrame")

  local title = Widgets.Label(frame, L.CONFIG_TITLE, "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -18)
  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
  local sourceText = Widgets.Label(frame, "", "GameFontHighlight")
  sourceText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  local pendingText = Widgets.Label(frame, L.CONFIG_PENDING, "GameFontRed")
  pendingText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -40, -22)
  pendingText:Hide()
  -- Atajos siempre a mano: modo mover (rejilla y relleno de ejemplo) y activar/desactivar Healsilus.
  local toggleButton = Widgets.Button(frame, "", 150, function()
    ns.Headers:SetEnabled(not ns.Headers.IsEnabled())
  end)
  toggleButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -36)
  local moveButton = Widgets.Button(frame, L.CONFIG_MOVE_FRAMES, 130, function()
    ns.MoveMode:Start()
  end)
  moveButton:SetPoint("RIGHT", toggleButton, "LEFT", -6, 0)
  sourceText:SetPoint("RIGHT", moveButton, "LEFT", -10, 0)
  sourceText:SetWordWrap(false)
  self.toggleButton = toggleButton

  local content = CreateFrame("Frame", nil, frame)
  content:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -96)
  content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 20)
  for position, key in ipairs(self.tabOrder) do
    local tab = self.tabs[key]
    tab.button = Widgets.Button(frame, tab.label, TAB_WIDTH, function()
      Config:SelectTab(key)
    end)
    tab.button:SetPoint("TOPLEFT", frame, "TOPLEFT", 20 + (position - 1) * (TAB_WIDTH + 4), -62)
    tab.panel = CreateFrame("Frame", nil, content)
    tab.panel:SetAllPoints(content)
    tab.panel:Hide()
    tab.build(tab.panel)
  end

  self.frame, self.sourceText, self.pendingText = frame, sourceText, pendingText
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
    if tabKey == key then
      tab.button:LockHighlight()
    else
      tab.button:UnlockHighlight()
    end
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
  self.toggleButton:SetText(ns.Headers.IsEnabled() and L.CONFIG_DISABLE or L.CONFIG_ENABLE)
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
