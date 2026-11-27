-- Cada barra de unidad: construcción visual (vale también para la vista previa) y actualización por eventos.
-- Lo que pueda ser secreto va directo a un widget; solo se ramifica sobre valores legibles.
local _, ns = ...
local L = ns.L

local UnitButton = { buttons = {}, alphaFromBooleanWorks = false, inCombat = false }
ns.UnitButton = UnitButton

local UNIT_EVENTS = {
  "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_CONNECTION", "UNIT_FLAGS",
  "UNIT_THREAT_SITUATION_UPDATE", "UNIT_THREAT_LIST_UPDATE", "UNIT_IN_RANGE_UPDATE", "UNIT_HEAL_PREDICTION",
  "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_AURA",
}

local AGGRO_COLOR = { 0.89, 0.29, 0.29 }
local MISSING_COLOR = { 0.94, 0.62, 0.15 }

-- Puntos de aggro: tantos como el nivel de amenaza (1 = mucha amenaza, 2 = tanquea sin seguridad,
-- 3 = tanquea). Textura redonda roja de Blizzard.
local AGGRO_DOTS = 3
local AGGRO_DOT_TEXTURE = "Interface\\COMMON\\Indicator-Red"
local AGGRO_DOT_GAP = 1
-- A partir de este nivel la unidad tiene el aggro: se pinta el borde rojo.
local AGGRO_BORDER_LEVEL = 2

-- Iconos de rol del buscador de grupo (los mismos que usa Blizzard en sus marcos, TextureUtil.lua).
UnitButton.ROLE_ATLASES = {
  TANK = "UI-LFG-RoleIcon-Tank-Micro-GroupFinder",
  HEALER = "UI-LFG-RoleIcon-Healer-Micro-GroupFinder",
  DAMAGER = "UI-LFG-RoleIcon-DPS-Micro-GroupFinder",
}

local function Frames()
  return ns.Profiles.active.frames
end

-- Todo lo visual (textura, fondo, textos, colores, opacidad) sale del estilo activo.
local function Style()
  return ns.Styles.active
end

local JUSTIFY = {
  TOPLEFT = "LEFT", LEFT = "LEFT", BOTTOMLEFT = "LEFT",
  TOP = "CENTER", CENTER = "CENTER", BOTTOM = "CENTER",
  TOPRIGHT = "RIGHT", RIGHT = "RIGHT", BOTTOMRIGHT = "RIGHT",
}

local function PlaceText(fontString, anchor, fontPath, element)
  local flags = element.outline == "NONE" and "" or element.outline
  fontString:ClearAllPoints()
  fontString:SetPoint(element.point, anchor, element.point, element.x, element.y)
  if not fontString:SetFont(fontPath, element.size, flags) then
    fontString:SetFont(ns.Media.DEFAULT_FONT, element.size, flags)
  end
  fontString:SetJustifyH(JUSTIFY[element.point])
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

  -- Posición, fuente y tamaño de los textos los pone ApplyStyle según el estilo activo.
  local nameText = textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  nameText:SetWordWrap(false)
  visual.nameText = nameText

  local healthText = textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  visual.healthText = healthText

  local statusText = textFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  visual.statusText = statusText

  local missingMark = textFrame:CreateTexture(nil, "OVERLAY")
  missingMark:SetSize(7, 7)
  missingMark:SetPoint("TOPLEFT", healthBar, "TOPLEFT", 0, 0)
  missingMark:SetColorTexture(MISSING_COLOR[1], MISSING_COLOR[2], MISSING_COLOR[3], 1)
  missingMark:Hide()
  visual.missingMark = missingMark

  local roleIcon = textFrame:CreateTexture(nil, "OVERLAY")
  roleIcon:Hide()
  visual.roleIcon = roleIcon

  visual.aggroFrame = BuildAggroFrame(frame)
  local aggroDots = {}
  for position = 1, AGGRO_DOTS do
    local dot = textFrame:CreateTexture(nil, "OVERLAY")
    dot:SetTexture(AGGRO_DOT_TEXTURE)
    dot:Hide()
    aggroDots[position] = dot
  end
  visual.aggroDots = aggroDots
  self:ApplyStyle(frame)
  return visual
end

function UnitButton:ApplyStyle(frame)
  local style = Style()
  local visual = frame.healsilus
  visual.healthBar:SetStatusBarTexture(ns.Media.Texture(style.bar.texture))
  local background = style.bar.background
  visual.background:SetColorTexture(background.r, background.g, background.b, background.a)
  local fontPath = ns.Media.Font(style.text.font)
  PlaceText(visual.nameText, visual.healthBar, fontPath, style.text.name)
  visual.nameText:SetWidth(math.max(10, style.layout.width - 12))
  PlaceText(visual.healthText, visual.healthBar, fontPath, style.text.health)
  PlaceText(visual.statusText, visual.healthBar, fontPath, style.text.status)
  local role = style.role
  visual.roleIcon:ClearAllPoints()
  visual.roleIcon:SetSize(role.size, role.size)
  visual.roleIcon:SetPoint(role.point, visual.healthBar, role.point, role.x, role.y)
  UnitButton.PlaceAggroDots(visual, style.aggro)
end

-- El primer punto va en el punto elegido; los demás crecen hacia dentro de la barra.
function UnitButton.PlaceAggroDots(visual, aggro)
  local towardsLeft = string.find(aggro.point, "RIGHT") ~= nil
  local step = (aggro.size + AGGRO_DOT_GAP) * (towardsLeft and -1 or 1)
  for position, dot in ipairs(visual.aggroDots) do
    dot:ClearAllPoints()
    dot:SetSize(aggro.size, aggro.size)
    dot:SetPoint(aggro.point, visual.healthBar, aggro.point, aggro.x + (position - 1) * step, aggro.y)
  end
end

-- role: "TANK", "HEALER", "DAMAGER" o nil. Lo usan las barras reales y la vista previa.
function UnitButton.ShowRole(visual, role, style)
  local atlas = role and UnitButton.ROLE_ATLASES[role]
  if not style.role.show or not atlas or (role == "DAMAGER" and not style.role.showDamager) then
    visual.roleIcon:Hide()
    return
  end
  visual.roleIcon:SetAtlas(atlas)
  visual.roleIcon:Show()
end

-- status: nivel de amenaza legible (0-3) o nil. Lo usan las barras reales y la vista previa.
function UnitButton.ShowThreat(visual, status, style)
  local level = status or 0
  visual.aggroFrame:SetShown(style.aggro.border and level >= AGGRO_BORDER_LEVEL)
  for position, dot in ipairs(visual.aggroDots) do
    dot:SetShown(style.aggro.dots and level >= position)
  end
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
  ns.DispelOverride:MarkDirty(button)
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
  self:UpdateRole(button)
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

-- Si el cliente no deja escribir un número de vida (secreto que AbbreviateLargeNumbers rechaza), esa
-- barra pasa a porcentaje hasta el próximo cambio de estilo y el error queda en /hs diag.
function UnitButton:FallBackToPercent(button, context, message)
  button.healsilusTextMode = "PERCENT"
  ns.RecordError(context, message)
  self:UpdateHealthText(button)
end

-- Modos: NONE, DEFICIT (-2,5 mil; vacío con la vida llena), PERCENT (75%), CURRENT (7,5 mil),
-- CURRENT_MAX (7,5 mil / 10 mil) y CURRENT_PERCENT (7,5 mil · 75%). Los números pueden ser secretos
-- en combate: solo se abrevian y se unen en texto, nunca se comparan ni se opera con ellos.
function UnitButton:UpdateHealthText(button)
  local text = button.healsilus.healthText
  local mode = button.healsilusTextMode or Style().text.health.mode
  local curvesSupported = ns.Curves.IsSupported()
  if mode == "DEFICIT" and not UnitHealthMissing then
    mode = "PERCENT"
  end
  if mode == "CURRENT_PERCENT" and not curvesSupported then
    mode = "CURRENT"
  end
  if mode == "PERCENT" and not curvesSupported then
    mode = "NONE"
  end
  if mode == "NONE" then
    text:SetText("")
    return
  end
  local unit = button.unit
  local percentText
  if mode == "PERCENT" or mode == "CURRENT_PERCENT" then
    percentText = string.format("%.0f%%", UnitHealthPercent(unit, true, ns.Curves:Percent()))
  end
  if mode == "PERCENT" then
    text:SetText(percentText)
    return
  end
  if mode == "DEFICIT" then
    local missing = UnitHealthMissing(unit)
    if not ns.IsSecret(missing) and missing <= 0 then
      text:SetText("")
      return
    end
    local ok, abbreviated = pcall(AbbreviateLargeNumbers, missing)
    if not ok then
      self:FallBackToPercent(button, "UnitButton:DeficitText", abbreviated)
      return
    end
    text:SetText("-" .. abbreviated)
    return
  end
  -- Abreviar y unir textos secretos va protegido: si el cliente lo rechaza, la barra pasa a porcentaje.
  local ok, result = pcall(UnitButton.HealthNumberText, mode, unit, percentText)
  if not ok then
    self:FallBackToPercent(button, "UnitButton:HealthNumberText", result)
    return
  end
  text:SetText(result)
end

-- Texto de los modos con número de vida (CURRENT, CURRENT_MAX, CURRENT_PERCENT).
function UnitButton.HealthNumberText(mode, unit, percentText)
  local current = AbbreviateLargeNumbers(UnitHealth(unit))
  if mode == "CURRENT_MAX" then
    return current .. " / " .. AbbreviateLargeNumbers(UnitHealthMax(unit))
  end
  if mode == "CURRENT_PERCENT" then
    return current .. " · " .. percentText
  end
  return current
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
  -- Le falta un buff tuyo: solo fuera de combate, como HealBot (en combate manda la vida).
  local buffs = ns.Profiles.active.buffs
  local missing = button.healsilusMissing
  if buffs.colorBar and missing and #missing > 0 and not UnitButton.inCombat and not InCombatLockdown() then
    local color = buffs.barColor
    texture:SetVertexColor(color.r, color.g, color.b)
    return
  end
  if Style().bar.colorMode == "HEALTH" and ns.Curves.IsSupported() then
    local color = UnitHealthPercent(button.unit, true, ns.Curves:HealthColor(Style().bar))
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
  local fadedAlpha = Style().bar.outOfRangeAlpha
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

-- En zonas o combates restringidos la amenaza llega como secreto: no se puede comparar ni convertir
-- en puntos, así que se oculta (lo mismo hace HealBot en Forever). /hs diag dice si se puede leer.
function UnitButton:UpdateThreat(button)
  local status = UnitThreatSituation(button.unit)
  if ns.IsSecret(status) then
    status = nil
  end
  UnitButton.ShowThreat(button.healsilus, status, Style())
end

-- El rol también puede ser secreto (identidad restringida): entonces no se muestra.
function UnitButton:UpdateRole(button)
  local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(button.unit)
  if ns.IsSecret(role) then
    role = nil
  end
  UnitButton.ShowRole(button.healsilus, role, Style())
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
  if missing and #missing > 0 and not UnitButton.inCombat and not InCombatLockdown() then
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
  UNIT_THREAT_LIST_UPDATE = function(button)
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
    ns.DispelOverride:MarkDirty(button)
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
  ns.Events:RegisterGameEvent("PLAYER_ROLES_ASSIGNED", function()
    for button in pairs(UnitButton.buttons) do
      if button.unit then
        UnitButton:UpdateRole(button)
      end
    end
  end)
end

ns.Events:Register("PROFILE_CHANGED", function()
  UnitButton:ApplyVisualSettings()
end)

ns.Events:Register("STYLE_CHANGED", function()
  UnitButton:ApplyVisualSettings()
end)

local function RecolorAll()
  for button in pairs(UnitButton.buttons) do
    if button.unit then
      UnitButton:UpdateColor(button)
    end
  end
end

ns.Events:Register("COMBAT_STARTED", function()
  UnitButton.inCombat = true
  RecolorAll()
end)

ns.Events:Register("COMBAT_ENDED", function()
  UnitButton.inCombat = false
  RecolorAll()
end)

ns.Events:Register("SETTINGS_CHANGED", function(section)
  if section == "frames" or section == "style" then
    UnitButton:ApplyVisualSettings()
  end
end)
