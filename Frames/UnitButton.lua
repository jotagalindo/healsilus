-- Cada barra de unidad: construcción visual (vale también para la vista previa) y actualización por eventos.
-- Lo que pueda ser secreto va directo a un widget; solo se ramifica sobre valores legibles.
local _, ns = ...
local L = ns.L

local UnitButton = { buttons = {}, alphaFromBooleanWorks = false }
ns.UnitButton = UnitButton

local UNIT_EVENTS = {
  "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_CONNECTION", "UNIT_FLAGS",
  "UNIT_THREAT_SITUATION_UPDATE", "UNIT_IN_RANGE_UPDATE", "UNIT_HEAL_PREDICTION",
  "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_AURA",
}

local AGGRO_COLOR = { 0.89, 0.29, 0.29 }
local MISSING_COLOR = { 0.94, 0.62, 0.15 }

local function Frames()
  return ns.Profiles.active.frames
end

local function CreateEdge(parent)
  local texture = parent:CreateTexture(nil, "OVERLAY")
  texture:SetColorTexture(AGGRO_COLOR[1], AGGRO_COLOR[2], AGGRO_COLOR[3], 1)
  return texture
end

-- Borde de aggro: cuatro líneas de 2 px por fuera del botón (el anillo interior es para el dispel).
local function BuildAggroFrame(frame)
  local aggroFrame = CreateFrame("Frame", nil, frame)
  aggroFrame:SetAllPoints(frame)
  aggroFrame:SetFrameLevel(frame:GetFrameLevel() + 6)
  local top = CreateEdge(aggroFrame)
  top:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", -2, 0)
  top:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 2, 0)
  top:SetHeight(2)
  local bottom = CreateEdge(aggroFrame)
  bottom:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -2, 0)
  bottom:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 2, 0)
  bottom:SetHeight(2)
  local left = CreateEdge(aggroFrame)
  left:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 0, 0)
  left:SetWidth(2)
  local right = CreateEdge(aggroFrame)
  right:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0)
  right:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 0, 0)
  right:SetWidth(2)
  aggroFrame:Hide()
  return aggroFrame
end

function UnitButton:BuildVisuals(frame)
  local visual = {}
  frame.healsilus = visual

  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(frame)
  background:SetColorTexture(0.06, 0.06, 0.06, 0.9)
  visual.background = background

  local healthBar = CreateFrame("StatusBar", nil, frame)
  healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
  healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
  healthBar:SetFrameLevel(frame:GetFrameLevel() + 2)
  healthBar:SetMinMaxValues(0, 1)
  healthBar:SetValue(1)
  visual.healthBar = healthBar

  local textFrame = CreateFrame("Frame", nil, frame)
  textFrame:SetAllPoints(healthBar)
  textFrame:SetFrameLevel(frame:GetFrameLevel() + 5)
  visual.textFrame = textFrame

  local nameText = textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  nameText:SetPoint("TOPLEFT", healthBar, "TOPLEFT", 4, -3)
  nameText:SetPoint("TOPRIGHT", healthBar, "TOPRIGHT", -4, -3)
  nameText:SetJustifyH("LEFT")
  nameText:SetWordWrap(false)
  visual.nameText = nameText

  local healthText = textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  healthText:SetPoint("BOTTOMLEFT", healthBar, "BOTTOMLEFT", 4, 3)
  healthText:SetJustifyH("LEFT")
  visual.healthText = healthText

  local statusText = textFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  statusText:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", -4, 3)
  visual.statusText = statusText

  local missingMark = textFrame:CreateTexture(nil, "OVERLAY")
  missingMark:SetSize(7, 7)
  missingMark:SetPoint("TOPLEFT", healthBar, "TOPLEFT", 0, 0)
  missingMark:SetColorTexture(MISSING_COLOR[1], MISSING_COLOR[2], MISSING_COLOR[3], 1)
  missingMark:Hide()
  visual.missingMark = missingMark

  visual.aggroFrame = BuildAggroFrame(frame)
  self:ApplyStyle(frame)
  return visual
end

function UnitButton:ApplyStyle(frame)
  frame.healsilus.healthBar:SetStatusBarTexture(ns.Media.Texture(Frames().texture))
end

-- SecureActionButtonTemplate (SecureTemplates.lua:810-811 en Forever) solo actúa en el flanco que dice
-- useOnKeyDown, que por defecto sigue la opción del juego "lanzar al pulsar". Se registran los dos
-- flancos y se fija useOnKeyDown para que el hechizo salga una sola vez, en el momento elegido.
function UnitButton:ApplyClickRegistration(button)
  ns.CombatQueue:Run("clicks:" .. tostring(button), function()
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetAttribute("useOnKeyDown", Frames().castOnDown == true)
  end)
end

-- Se llama desde la initialConfigFunction de una cabecera o al crear objetivo/foco.
function UnitButton:Init(button, kind)
  if button.healsilus then
    return
  end
  self:BuildVisuals(button)
  button.healsilusKind = kind
  local eventFrame = CreateFrame("Frame", nil, button)
  eventFrame:SetScript("OnEvent", function(_, event)
    UnitButton:OnUnitEvent(button, event)
  end)
  button.healsilusEvents = eventFrame
  button:HookScript("OnAttributeChanged", function(self, name, value)
    if name == "unit" then
      UnitButton:SetUnit(self, value)
    end
  end)
  button:HookScript("OnEnter", function(self)
    UnitButton:ShowTooltip(self)
  end)
  button:HookScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  self.buttons[button] = true
  ns.ClickCast:AdoptButton(button)
  self:ApplyClickRegistration(button)
  ns.Prediction:Attach(button)
  self:SetUnit(button, button:GetAttribute("unit"))
end

function UnitButton:SetUnit(button, unit)
  button.unit = unit
  local eventFrame = button.healsilusEvents
  eventFrame:UnregisterAllEvents()
  if unit then
    for _, event in ipairs(UNIT_EVENTS) do
      if ns.IsEventValid(event) then
        eventFrame:RegisterUnitEvent(event, unit)
      end
    end
  end
  ns.Containers:SetUnit(button, unit)
  self:UpdateAll(button)
end

function UnitButton:UpdateAll(button)
  local unit = button.unit
  if not unit or not UnitExists(unit) then
    ns.Prediction:Hide(button)
    return
  end
  self:UpdateName(button)
  self:UpdateStatus(button)
  self:UpdateHealth(button)
  self:UpdateColor(button)
  self:UpdateRange(button)
  self:UpdateThreat(button)
  ns.Prediction:Update(button)
  ns.MissingBuffs:Evaluate(button)
end

function UnitButton:UpdateName(button)
  local name = UnitName(button.unit)
  button.healsilus.nameText:SetText(name)
end

function UnitButton:UpdateHealth(button)
  local unit = button.unit
  local healthBar = button.healsilus.healthBar
  healthBar:SetMinMaxValues(0, UnitHealthMax(unit))
  healthBar:SetValue(UnitHealth(unit))
  self:UpdateHealthText(button)
end

function UnitButton:UpdateHealthText(button)
  local text = button.healsilus.healthText
  local mode = button.healsilusTextMode or Frames().healthText
  if mode == "DEFICIT" and not UnitHealthMissing then
    mode = "PERCENT"
  end
  if mode == "PERCENT" and not ns.Curves.IsSupported() then
    mode = "NONE"
  end
  if mode == "NONE" then
    text:SetText("")
    return
  end
  local unit = button.unit
  if mode == "PERCENT" then
    text:SetText(string.format("%.0f%%", UnitHealthPercent(unit, true, ns.Curves:Percent())))
    return
  end
  local missing = UnitHealthMissing(unit)
  if not ns.IsSecret(missing) and missing <= 0 then
    text:SetText("")
    return
  end
  local ok, abbreviated = pcall(AbbreviateLargeNumbers, missing)
  if not ok then
    button.healsilusTextMode = "PERCENT"
    ns.RecordError("UnitButton:DeficitText", abbreviated)
    self:UpdateHealthText(button)
    return
  end
  text:SetText("-" .. abbreviated)
end

function UnitButton:UpdateStatus(button)
  local unit = button.unit
  local statusText = button.healsilus.statusText
  local connected = UnitIsConnected(unit)
  local dead = UnitIsDeadOrGhost(unit)
  if ns.IsSecret(connected) or ns.IsSecret(dead) then
    button.healsilusState = nil
    statusText:SetText("")
    return
  end
  if not connected then
    button.healsilusState = "OFFLINE"
    statusText:SetText(L.STATUS_OFFLINE)
  elseif dead then
    button.healsilusState = "DEAD"
    statusText:SetText(L.STATUS_DEAD)
  else
    button.healsilusState = nil
    statusText:SetText("")
  end
end

function UnitButton:UpdateColor(button)
  local texture = button.healsilus.healthBar:GetStatusBarTexture()
  if button.healsilusState then
    local color = ns.Media.OFFLINE_COLOR
    texture:SetVertexColor(color.r, color.g, color.b)
    return
  end
  if Frames().colorMode == "HEALTH" and ns.Curves.IsSupported() then
    local color = UnitHealthPercent(button.unit, true, ns.Curves:HealthColor())
    texture:SetVertexColor(color:GetRGB())
    return
  end
  if button.healsilusKind == "pets" then
    local color = ns.Media.PET_COLOR
    texture:SetVertexColor(color.r, color.g, color.b)
    return
  end
  local _, classToken = UnitClass(button.unit)
  texture:SetVertexColor(ns.Media.ClassColor(classToken))
end

function UnitButton:UpdateRange(button)
  local unit = button.unit
  local fadedAlpha = Frames().outOfRangeAlpha
  local isPlayer = UnitIsUnit(unit, "player")
  if not ns.IsSecret(isPlayer) and isPlayer then
    button:SetAlpha(1)
    return
  end
  local inRange, checked = UnitInRange(unit)
  if not ns.IsSecret(checked) and not checked then
    button:SetAlpha(1)
    return
  end
  if ns.IsSecret(inRange) then
    if self.alphaFromBooleanWorks then
      button:SetAlphaFromBoolean(inRange, 1, fadedAlpha)
    else
      button:SetAlpha(1)
    end
    return
  end
  button:SetAlpha(inRange and 1 or fadedAlpha)
end

function UnitButton:UpdateThreat(button)
  local status = UnitThreatSituation(button.unit)
  local aggroFrame = button.healsilus.aggroFrame
  if ns.IsSecret(status) then
    aggroFrame:Hide()
    return
  end
  aggroFrame:SetShown(status ~= nil and status >= 2)
end

-- Comprueba en un marco de prueba que SetAlphaFromBoolean existe y aplica los dos valores.
function UnitButton:ProbeAlphaFromBoolean()
  local probe = CreateFrame("Frame", nil, UIParent)
  local ok, works = pcall(function()
    probe:SetAlphaFromBoolean(false, 1, 0.25)
    if math.abs(probe:GetAlpha() - 0.25) > 0.01 then
      return false
    end
    probe:SetAlphaFromBoolean(true, 1, 0.25)
    return math.abs(probe:GetAlpha() - 1) <= 0.01
  end)
  probe:Hide()
  if not ok then
    ns.RecordError("UnitButton:ProbeAlphaFromBoolean", works)
  end
  self.alphaFromBooleanWorks = ok and works == true
  return self.alphaFromBooleanWorks
end

function UnitButton:ShowTooltip(button)
  if not button.unit then
    return
  end
  GameTooltip_SetDefaultAnchor(GameTooltip, button)
  GameTooltip:SetUnit(button.unit)
  local missing = button.healsilusMissing
  if missing and #missing > 0 then
    GameTooltip:AddLine(string.format(L.TOOLTIP_MISSING_BUFFS, table.concat(missing, ", ")),
      MISSING_COLOR[1], MISSING_COLOR[2], MISSING_COLOR[3])
  end
  GameTooltip:Show()
end

local function UpdateHealthEvent(button)
  UnitButton:UpdateStatus(button)
  UnitButton:UpdateHealth(button)
  UnitButton:UpdateColor(button)
  ns.Prediction:Update(button)
end

local function UpdateStatusEvent(button)
  UnitButton:UpdateStatus(button)
  UnitButton:UpdateColor(button)
end

local HANDLERS = {
  UNIT_HEALTH = UpdateHealthEvent,
  UNIT_MAXHEALTH = UpdateHealthEvent,
  UNIT_NAME_UPDATE = function(button)
    UnitButton:UpdateName(button)
  end,
  UNIT_CONNECTION = UpdateStatusEvent,
  UNIT_FLAGS = UpdateStatusEvent,
  UNIT_THREAT_SITUATION_UPDATE = function(button)
    UnitButton:UpdateThreat(button)
  end,
  UNIT_IN_RANGE_UPDATE = function(button)
    UnitButton:UpdateRange(button)
  end,
  UNIT_HEAL_PREDICTION = function(button)
    ns.Prediction:Update(button)
  end,
  UNIT_ABSORB_AMOUNT_CHANGED = function(button)
    ns.Prediction:Update(button)
  end,
  UNIT_AURA = function(button)
    ns.MissingBuffs:MarkDirty(button)
  end,
}

function UnitButton:OnUnitEvent(button, event)
  local handler = HANDLERS[event]
  if handler and button.unit then
    handler(button)
  end
end

function UnitButton:UpdateAllButtons()
  for button in pairs(self.buttons) do
    self:UpdateAll(button)
  end
end

-- Objetivo y foco cambian de entidad sin cambiar de token.
function UnitButton:UpdateUnitToken(token)
  for button in pairs(self.buttons) do
    if button.unit == token then
      ns.Containers:SetUnit(button, token)
      self:UpdateAll(button)
    end
  end
end

function UnitButton:ApplyVisualSettings()
  for button in pairs(self.buttons) do
    button.healsilusTextMode = nil
    self:ApplyStyle(button)
    self:ApplyClickRegistration(button)
    self:UpdateAll(button)
  end
end

function UnitButton:Initialize()
  self:ProbeAlphaFromBoolean()
  ns.Events:RegisterGameEvent("GROUP_ROSTER_UPDATE", function()
    UnitButton:UpdateAllButtons()
  end)
  ns.Events:RegisterGameEvent("PLAYER_ENTERING_WORLD", function()
    UnitButton:UpdateAllButtons()
  end)
  ns.Events:RegisterGameEvent("PLAYER_TARGET_CHANGED", function()
    UnitButton:UpdateUnitToken("target")
  end)
  ns.Events:RegisterGameEvent("PLAYER_FOCUS_CHANGED", function()
    UnitButton:UpdateUnitToken("focus")
  end)
end

ns.Events:Register("PROFILE_CHANGED", function()
  UnitButton:ApplyVisualSettings()
end)

ns.Events:Register("SETTINGS_CHANGED", function(section)
  if section == "frames" then
    UnitButton:ApplyVisualSettings()
  end
end)
