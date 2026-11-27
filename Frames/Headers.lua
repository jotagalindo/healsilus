-- Cabeceras seguras (SecureGroupHeaderTemplate): ordenan y crean los botones sin taint, también en combate.
-- Botones sueltos para objetivo y foco amistosos, anclas movibles y ocultación de los marcos de Blizzard.
local _, ns = ...
local L = ns.L

local Headers = { list = {}, byKind = {}, anchors = {}, singles = {}, initialized = false, previewActive = false }
ns.Headers = Headers

local MAX_BUTTONS = { party = 40, tanks = 8, pets = 20 }

local DEFAULT_POSITIONS = {
  party = { "TOPLEFT", 30, -220 },
  tanks = { "TOPLEFT", 30, -130 },
  pets = { "TOPLEFT", 400, -220 },
  target = { "TOPLEFT", 30, -60 },
  focus = { "TOPLEFT", 160, -60 },
}

local ANCHOR_LABELS = {
  party = L.ANCHOR_PARTY,
  tanks = L.ANCHOR_TANKS,
  pets = L.ANCHOR_PETS,
  target = L.ANCHOR_TARGET,
  focus = L.ANCHOR_FOCUS,
}

Headers.ANCHOR_LABELS = ANCHOR_LABELS
Headers.BLOCK_KINDS = { "party", "tanks", "pets", "target", "focus" }

local SORT_ATTRIBUTES = {
  GROUP = { groupBy = "GROUP", groupingOrder = "1,2,3,4,5,6,7,8" },
  CLASS = { groupBy = "CLASS", groupingOrder = "WARRIOR,PALADIN,DRUID,PRIEST,SHAMAN,ROGUE,HUNTER,MAGE,WARLOCK" },
  ROLE = { groupBy = "ASSIGNEDROLE", groupingOrder = "TANK,HEALER,DAMAGER,NONE" },
}

-- Entorno restringido: cada botón nuevo toma tamaño y clics de su cabecera y pide su parte visual.
local INITIAL_CONFIG = [[
  local header = self:GetParent()
  self:SetWidth(header:GetAttribute("hs-width") or 110)
  self:SetHeight(header:GetAttribute("hs-height") or 34)
  self:SetAttribute("useOnKeyDown", header:GetAttribute("hs-use-on-key-down"))
  local count = header:GetAttribute("hs-attr-count") or 0
  for position = 1, count do
    self:SetAttribute(header:GetAttribute("hs-attr-name-" .. position), header:GetAttribute("hs-attr-value-" .. position))
  end
  header:CallMethod("InitButton", self:GetName())
]]

local BLIZZARD_FRAMES = { "CompactPartyFrame", "CompactRaidFrameContainer", "CompactRaidFrameManager", "PartyFrame" }

local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()
local originalParents = {}

local function SetAttributes(header, attributes)
  for name, value in pairs(attributes) do
    header:SetAttribute(name, value)
  end
end

-- Las anclas se guardan por su esquina inferior izquierda respecto a UIParent (vale para el imán).
local SNAP_GAP = 2
local BLOCK_KINDS = Headers.BLOCK_KINDS

local function PlaceAnchor(anchor, left, bottom)
  anchor:ClearAllPoints()
  anchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
end

local function SavePosition(kind, anchor)
  ns.Database.db.framePositions[kind] = { "BOTTOMLEFT", anchor:GetLeft(), anchor:GetBottom() }
end

-- Rectángulo del bloque en pantalla (cabecera o botón suelto), o nil si no se ve o no tiene tamaño.
-- Con la vista previa abierta, el bloque son sus miembros de ejemplo.
function Headers:BlockRect(kind)
  if self.previewActive and ns.Preview then
    return ns.Preview:BlockRect(kind)
  end
  local frame = self.byKind[kind] or self.singles[kind]
  if not frame or not frame:IsVisible() then
    return nil
  end
  local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
  if not left or not right or not top or not bottom then
    return nil
  end
  return { left = left, right = right, top = top, bottom = bottom }
end

-- Posición del cursor en coordenadas de UIParent.
local function CursorPosition()
  local x, y = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  return x / scale, y / scale
end

local function Shifted(rect, deltaX, deltaY)
  return { left = rect.left + deltaX, right = rect.right + deltaX, top = rect.top + deltaY, bottom = rect.bottom + deltaY }
end

-- Arrastre manual (sin StartMoving): en cada fotograma el bloque sigue al cursor y, si un borde o su
-- centro pasa cerca del de otro bloque, del centro de la pantalla o de la rejilla, se pega ahí ya
-- mientras arrastras (el "imán"), con una guía que marca la alineación. Mayús suelta el imán.
function Headers:BeginDrag(kind)
  if InCombatLockdown() then
    return
  end
  local anchor = self.anchors[kind]
  local frames = ns.Profiles.active.frames
  local cursorX, cursorY = CursorPosition()
  local left, bottom = anchor:GetLeft(), anchor:GetBottom()
  local drag = {
    kind = kind, left = left, bottom = bottom, cursorX = cursorX, cursorY = cursorY, others = {},
    rect = self:BlockRect(kind), targets = {},
  }
  if frames.moveTogether then
    for _, other in ipairs(BLOCK_KINDS) do
      if other ~= kind then
        local otherAnchor = self.anchors[other]
        drag.others[other] = { left = otherAnchor:GetLeft(), bottom = otherAnchor:GetBottom() }
      end
    end
  else
    -- Los demás bloques no se mueven durante el arrastre: sus rectángulos se leen una vez.
    for _, other in ipairs(BLOCK_KINDS) do
      local rect = other ~= kind and self:BlockRect(other)
      if rect then
        drag.targets[#drag.targets + 1] = rect
      end
    end
  end
  self.drag = drag
  anchor:SetScript("OnUpdate", function()
    Headers:UpdateDrag()
  end)
end

-- Dónde quedaría el ancla con el desplazamiento crudo (deltaX, deltaY) tras el imán y la rejilla.
function Headers:SnapDrag(drag, deltaX, deltaY)
  local frames = ns.Profiles.active.frames
  if not drag.rect or (IsShiftKeyDown and IsShiftKeyDown()) then
    return deltaX, deltaY, {}
  end
  local moving = Shifted(drag.rect, deltaX, deltaY)
  local options = { threshold = frames.snapDistance, gap = SNAP_GAP }
  if ns.MoveMode and ns.MoveMode.active then
    options.screen = { width = UIParent:GetWidth(), height = UIParent:GetHeight() }
    if ns.MoveMode:SnapsToGrid() then
      local originX, originY = ns.MoveMode:GridOrigin()
      options.grid = { originX = originX, originY = originY, size = ns.MoveMode:GridSize() }
    end
  end
  local snapX, snapY, guides = ns.Snapping.Solve(moving, drag.targets, options)
  return deltaX + snapX, deltaY + snapY, guides
end

function Headers:UpdateDrag()
  local drag = self.drag
  if not drag then
    return
  end
  local cursorX, cursorY = CursorPosition()
  local deltaX, deltaY, guides = self:SnapDrag(drag, cursorX - drag.cursorX, cursorY - drag.cursorY)
  PlaceAnchor(self.anchors[drag.kind], drag.left + deltaX, drag.bottom + deltaY)
  for other, start in pairs(drag.others) do
    PlaceAnchor(self.anchors[other], start.left + deltaX, start.bottom + deltaY)
  end
  drag.deltaX, drag.deltaY = deltaX, deltaY
  if ns.MoveMode then
    ns.MoveMode:ShowGuides(guides)
  end
end

function Headers:EndDrag(kind)
  local anchor = self.anchors[kind]
  anchor:SetScript("OnUpdate", nil)
  local drag = self.drag
  if not drag then
    -- Soltar sin arrastre registrado (o un arrastre con StartMoving): solo se aplica el imán.
    drag = { kind = kind, left = anchor:GetLeft(), bottom = anchor:GetBottom(), others = {}, rect = self:BlockRect(kind), targets = {} }
    for _, other in ipairs(BLOCK_KINDS) do
      local rect = other ~= kind and self:BlockRect(other)
      if rect then
        drag.targets[#drag.targets + 1] = rect
      end
    end
    local deltaX, deltaY = self:SnapDrag(drag, 0, 0)
    drag.deltaX, drag.deltaY = deltaX, deltaY
  else
    self:UpdateDrag()
  end
  self.drag = nil
  PlaceAnchor(anchor, drag.left + (drag.deltaX or 0), drag.bottom + (drag.deltaY or 0))
  SavePosition(kind, anchor)
  for other, start in pairs(drag.others) do
    local otherAnchor = self.anchors[other]
    PlaceAnchor(otherAnchor, start.left + (drag.deltaX or 0), start.bottom + (drag.deltaY or 0))
    SavePosition(other, otherAnchor)
  end
  if ns.MoveMode then
    ns.MoveMode:ShowGuides(nil)
  end
end

local function CreateAnchor(kind)
  local anchor = CreateFrame("Frame", "HealsilusAnchor_" .. kind, UIParent)
  anchor:SetSize(16, 16)
  anchor:SetMovable(true)
  anchor:SetClampedToScreen(true)
  local position = ns.Database.db.framePositions[kind] or DEFAULT_POSITIONS[kind]
  anchor:SetPoint(position[1], UIParent, position[1], position[2], position[3])
  local handle = anchor:CreateTexture(nil, "OVERLAY")
  handle:SetAllPoints(anchor)
  handle:SetColorTexture(0.2, 0.6, 1, 0.8)
  local label = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetPoint("LEFT", anchor, "RIGHT", 4, 0)
  label:SetText(ANCHOR_LABELS[kind])
  anchor.handle, anchor.label = handle, label
  anchor:RegisterForDrag("LeftButton")
  anchor:SetScript("OnDragStart", function()
    Headers:BeginDrag(kind)
  end)
  anchor:SetScript("OnDragStop", function()
    Headers:EndDrag(kind)
  end)
  Headers.anchors[kind] = anchor
  return anchor
end

local function CreateHeader(kind, template)
  local header = CreateFrame("Frame", "HealsilusHeader_" .. kind, UIParent, template)
  header.healsilusKind = kind
  header:SetAttribute("template", "SecureActionButtonTemplate")
  header:SetAttribute("initialConfigFunction", INITIAL_CONFIG)
  header.InitButton = function(_, buttonName)
    local button = _G[buttonName]
    if button then
      ns.UnitButton:Init(button, kind)
    end
  end
  header:SetPoint("TOPLEFT", Headers.anchors[kind], "BOTTOMLEFT", 0, -2)
  Headers.list[#Headers.list + 1] = header
  Headers.byKind[kind] = header
  return header
end

function Headers:CreateSingle(kind, visibility)
  local button = CreateFrame("Button", "HealsilusUnit_" .. kind, UIParent, "SecureActionButtonTemplate")
  button:SetAttribute("unit", kind)
  local layout = ns.Styles.active.layout
  button:SetSize(layout.width, layout.height)
  button:SetPoint("TOPLEFT", self.anchors[kind], "BOTTOMLEFT", 0, -2)
  button.healsilusVisibility = visibility
  self.singles[kind] = button
  ns.UnitButton:Init(button, kind)
  return button
end

-- layout: tamaño y disposición del estilo activo; frames: cuándo se ve y cómo se lanza (perfil).
function Headers:ApplyHeaderLayout(header, layout, frames)
  local kind = header.healsilusKind
  local down = layout.growth == "DOWN"
  SetAttributes(header, {
    ["hs-width"] = layout.width,
    ["hs-height"] = layout.height,
    ["hs-use-on-key-down"] = frames.castOnDown == true,
    point = down and "TOP" or "LEFT",
    xOffset = down and 0 or layout.spacing,
    yOffset = down and -layout.spacing or 0,
    columnAnchorPoint = down and "LEFT" or "TOP",
    columnSpacing = layout.spacing,
    showRaid = frames.showInRaid,
    showParty = frames.showInParty,
    showPlayer = true,
  })
  if kind == "tanks" then
    SetAttributes(header, { roleFilter = "MAINTANK,TANK", showSolo = false, unitsPerColumn = MAX_BUTTONS.tanks, maxColumns = 1 })
  elseif kind == "pets" then
    SetAttributes(header, { showSolo = frames.showSolo, unitsPerColumn = layout.unitsPerColumn, maxColumns = layout.columns })
  else
    local sort = SORT_ATTRIBUTES[layout.sortBy]
    SetAttributes(header, {
      showSolo = frames.showSolo, unitsPerColumn = layout.unitsPerColumn, maxColumns = layout.columns,
      groupBy = sort.groupBy, groupingOrder = sort.groupingOrder, groupFilter = "1,2,3,4,5,6,7,8",
    })
  end
  -- Los botones ya creados no vuelven a pasar por initialConfigFunction: se redimensionan aquí.
  local position = 1
  local child = header:GetAttribute("child1")
  while child do
    child:SetSize(layout.width, layout.height)
    position = position + 1
    child = header:GetAttribute("child" .. position)
  end
end

function Headers:CountButtons(header)
  local count = 0
  while header:GetAttribute("child" .. (count + 1)) do
    count = count + 1
  end
  return count
end

-- Con startingIndex negativo la cabecera cree que hay más unidades y crea todos sus botones ya,
-- fuera de combate, para que nunca haga falta crear botones ni contenedores de auras en combate.
-- La plantilla nace oculta y se actualiza al mostrarse (OnShow), así que los atributos que lee
-- la initialConfigFunction (tamaño) tienen que estar puestos antes del Show.
function Headers:Precreate(header, layout)
  local maximum = MAX_BUTTONS[header.healsilusKind]
  header:SetAttribute("hs-width", layout.width)
  header:SetAttribute("hs-height", layout.height)
  header:SetAttribute("unitsPerColumn", maximum)
  header:SetAttribute("maxColumns", 1)
  header:SetAttribute("startingIndex", 1 - maximum)
  header:Show()
  header:SetAttribute("startingIndex", 1)
end

function Headers:ApplyBlizzardVisibility(hide)
  for _, name in ipairs(BLIZZARD_FRAMES) do
    local frame = _G[name]
    if frame then
      if hide then
        if not originalParents[name] then
          originalParents[name] = frame:GetParent()
        end
        frame:SetParent(hiddenParent)
      elseif originalParents[name] then
        frame:SetParent(originalParents[name])
        originalParents[name] = nil
      end
    end
  end
end

-- En el modo mover se arrastra el bloque entero (UI/MoveMode.lua): los cuadrados azules solo salen al
-- desbloquear sin él (/hs lock).
function Headers:SetLocked(locked)
  local handles = not locked and not (ns.MoveMode and ns.MoveMode.active)
  for _, anchor in pairs(self.anchors) do
    anchor.handle:SetShown(handles)
    anchor.label:SetShown(handles)
    anchor:EnableMouse(handles)
  end
end

function Headers:SetHeaderShown(kind, shown)
  local header = self.byKind[kind]
  if header then
    header:SetShown(shown)
  end
end

function Headers:Create()
  if self.initialized then
    return
  end
  local frames = ns.Profiles.active.frames
  local layout = ns.Styles.active.layout
  for _, kind in ipairs(BLOCK_KINDS) do
    CreateAnchor(kind)
  end
  CreateHeader("party", "SecureGroupHeaderTemplate")
  CreateHeader("tanks", "SecureGroupHeaderTemplate")
  CreateHeader("pets", "SecureGroupPetHeaderTemplate")
  self:CreateSingle("target", "[@target,help,exists] show; hide")
  self:CreateSingle("focus", "[@focus,help,exists] show; hide")
  -- Los clics se guardan en las cabeceras antes de que existan sus botones.
  ns.ClickCast:Apply(ns.Profiles.active)
  for _, header in ipairs(self.list) do
    self:Precreate(header, layout)
    self:ApplyHeaderLayout(header, layout, frames)
  end
  self.initialized = true
  self:ApplyProfile(ns.Profiles.active)
end

function Headers:Initialize()
  ns.CombatQueue:Run("headers:create", function()
    Headers:Create()
  end)
end

-- Healsilus apagado en este personaje (clic derecho en el botón del minimapa o /hs toggle): no se ve
-- ningún bloque y vuelven los marcos de Blizzard. Se guarda por personaje en disabledCharacters.
function Headers.IsEnabled()
  local db = ns.Database.db
  return not (db and db.disabledCharacters and db.disabledCharacters[ns.CharacterKey()])
end

function Headers:SetEnabled(enabled)
  ns.Database.db.disabledCharacters[ns.CharacterKey()] = (not enabled) or nil
  if not enabled then
    if ns.MoveMode then
      ns.MoveMode:Stop()
    end
    if ns.Preview then
      ns.Preview:Hide()
    end
  end
  self:ApplyProfile(ns.Profiles.active)
  if enabled and ns.UnitButton then
    ns.UnitButton:UpdateAllButtons()
  end
  ns.Print(enabled and L.ADDON_ENABLED or L.ADDON_DISABLED)
  if InCombatLockdown() then
    ns.Print(L.ADDON_TOGGLE_AFTER_COMBAT)
  end
  ns.Events:Fire("ADDON_TOGGLED", enabled)
end

function Headers:ApplyProfile(profile)
  if not self.initialized then
    return
  end
  ns.CombatQueue:Run("headers:apply", function()
    local frames = profile.frames
    local layout = ns.Styles.active.layout
    local enabled = Headers.IsEnabled()
    -- Con la vista previa abierta, sus miembros de ejemplo ocupan el sitio de los bloques reales.
    local showBlocks = enabled and not Headers.previewActive
    for _, header in ipairs(Headers.list) do
      Headers:ApplyHeaderLayout(header, layout, frames)
    end
    Headers:SetHeaderShown("party", frames.showMain and showBlocks)
    Headers:SetHeaderShown("tanks", frames.showTanks and showBlocks)
    Headers:SetHeaderShown("pets", frames.showPets and showBlocks)
    for kind, button in pairs(Headers.singles) do
      button:SetSize(layout.width, layout.height)
      local wanted = (kind == "target" and frames.showTarget) or (kind == "focus" and frames.showFocus)
      RegisterStateDriver(button, "visibility", (wanted and showBlocks) and button.healsilusVisibility or "hide")
    end
    Headers:ApplyBlizzardVisibility(enabled and frames.hideBlizzard)
    Headers:SetLocked(frames.locked or not enabled)
    ns.ClickCast:Apply(profile)
  end)
end

ns.Events:Register("PROFILE_CHANGED", function(profile)
  Headers:ApplyProfile(profile)
end)

ns.Events:Register("STYLE_CHANGED", function()
  Headers:ApplyProfile(ns.Profiles.active)
end)

ns.Events:Register("SETTINGS_CHANGED", function(section)
  if section == "frames" or section == "style" then
    Headers:ApplyProfile(ns.Profiles.active)
  end
end)
