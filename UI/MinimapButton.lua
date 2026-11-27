-- Botón del minimapa (como el de HealBot): clic izquierdo abre la configuración, clic derecho
-- desactiva o vuelve a activar Healsilus en este personaje y arrastrándolo se mueve alrededor del
-- minimapa. Con Healsilus desactivado, el icono sale en gris.
-- También responde al desplegable de addons del minimapa (AddonCompartmentFunc en el TOC).
local _, ns = ...
local L = ns.L

local MinimapButton = {}
ns.MinimapButton = MinimapButton

local ICON = "Interface\\Icons\\Spell_Nature_HealingTouch"
local EDGE_OFFSET = 10
local SQUARE_FACTOR = math.sqrt(2)

local function Settings()
  return HealsilusDB.minimap
end

-- Posición del centro del botón respecto al centro del minimapa para un ángulo en grados.
-- En un minimapa cuadrado el botón se empuja hacia las esquinas sin salirse del borde.
function MinimapButton.Offset(angle, radius, square)
  local radians = math.rad(angle)
  local x, y = math.cos(radians) * radius, math.sin(radians) * radius
  if square then
    x = math.max(-radius, math.min(radius, x * SQUARE_FACTOR))
    y = math.max(-radius, math.min(radius, y * SQUARE_FACTOR))
  end
  return x, y
end

function MinimapButton.AngleFromOffset(x, y)
  local angle = math.deg(math.atan2(y, x))
  if angle < 0 then
    angle = angle + 360
  end
  return angle
end

function MinimapButton.OnClick(mouseButton)
  if mouseButton == "RightButton" then
    ns.Headers:SetEnabled(not ns.Headers.IsEnabled())
  else
    ns.Config:Toggle()
  end
end

function MinimapButton.ShowTooltip(owner)
  GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
  GameTooltip:SetText("Healsilus")
  if ns.Headers.IsEnabled() then
    GameTooltip:AddLine(L.MINIMAP_STATE_ON, 0.2, 1, 0.2)
  else
    GameTooltip:AddLine(L.MINIMAP_STATE_OFF, 1, 0.3, 0.3)
  end
  GameTooltip:AddLine(L.MINIMAP_TOOLTIP_LEFT, 1, 1, 1)
  GameTooltip:AddLine(L.MINIMAP_TOOLTIP_RIGHT, 1, 1, 1)
  GameTooltip:AddLine(L.MINIMAP_TOOLTIP_DRAG, 1, 1, 1)
  GameTooltip:Show()
end

local function IsSquareMinimap()
  return GetMinimapShape ~= nil and GetMinimapShape() == "SQUARE"
end

function MinimapButton:UpdatePosition()
  local radius = Minimap:GetWidth() / 2 + EDGE_OFFSET
  local x, y = MinimapButton.Offset(Settings().angle, radius, IsSquareMinimap())
  self.button:ClearAllPoints()
  self.button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function FollowCursor()
  local centerX, centerY = Minimap:GetCenter()
  local scale = Minimap:GetEffectiveScale()
  local cursorX, cursorY = GetCursorPosition()
  Settings().angle = MinimapButton.AngleFromOffset(cursorX / scale - centerX, cursorY / scale - centerY)
  MinimapButton:UpdatePosition()
end

-- Medidas clásicas de los botones de minimapa (las mismas que usa LibDBIcon).
function MinimapButton:Create()
  local button = CreateFrame("Button", "HealsilusMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local background = button:CreateTexture(nil, "BACKGROUND")
  background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  background:SetSize(20, 20)
  background:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -5)
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetTexture(ICON)
  icon:SetSize(17, 17)
  icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -6)
  icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
  self.icon = icon
  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
  button:SetScript("OnClick", function(_, mouseButton)
    MinimapButton.OnClick(mouseButton)
  end)
  button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", FollowCursor)
  end)
  button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
  end)
  button:SetScript("OnEnter", function(self)
    MinimapButton.ShowTooltip(self)
  end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  self.button = button
end

function MinimapButton:Refresh()
  self.button:SetShown(not Settings().hide)
  self.icon:SetDesaturated(not ns.Headers.IsEnabled())
  self:UpdatePosition()
end

function MinimapButton:SetHidden(hidden)
  Settings().hide = hidden
  self:Refresh()
  ns.Print(hidden and L.MINIMAP_HIDDEN or L.MINIMAP_SHOWN)
end

function MinimapButton:Initialize()
  self:Create()
  self:Refresh()
end

ns.Events:Register("ADDON_TOGGLED", function()
  if MinimapButton.button then
    MinimapButton:Refresh()
  end
end)

-- Desplegable de addons del minimapa: el cliente llama a estas funciones globales por su nombre en el TOC.
function Healsilus_OnAddonCompartmentClick(_, mouseButton)
  MinimapButton.OnClick(mouseButton)
end

function Healsilus_OnAddonCompartmentEnter(_, menuButton)
  MinimapButton.ShowTooltip(menuButton)
end

function Healsilus_OnAddonCompartmentLeave()
  GameTooltip:Hide()
end
