-- Modo mover: desbloquea los bloques, rellena cada uno con miembros de ejemplo (Frames/Preview.lua) y
-- pone encima de cada uno un recuadro que se arrastra entero. Mientras arrastras, el imán lo pega a los
-- bordes y centros de los demás bloques y al centro de la pantalla, con una guía que lo marca; la
-- rejilla es opcional. Una barra arriba deja cambiar rejilla, imán y relleno; "Terminar" lo bloquea todo.
-- Solo fuera de combate: al entrar en combate se cierra solo.
local _, ns = ...
local L = ns.L
local Widgets = ns.Widgets

local MoveMode = { active = false, built = false, lineTextures = {}, movers = {} }
ns.MoveMode = MoveMode

local GRID_COLOR = { 1, 1, 1, 0.12 }
local CENTER_COLOR = { 1, 0.35, 0.35, 0.55 }
local TOOLBAR_WIDTH, TOOLBAR_HEIGHT = 860, 72
local GUIDE_COLOR = { 0.27, 0.84, 0.56, 0.95 }
-- Distancias del imán que ofrece la barra (0 = sin imán).
MoveMode.SNAP_DISTANCES = { 0, 6, 12, 20, 30 }

local function Settings()
  return ns.Database.db.moveMode
end

-- Siguiente valor de una lista cíclica (tamaños de rejilla, número de miembros de ejemplo).
function MoveMode.NextValue(list, current)
  for position, value in ipairs(list) do
    if value == current then
      return list[position % #list + 1]
    end
  end
  return list[1]
end

-- Desplazamientos de las líneas respecto al centro de la pantalla: 0, ±size, ±2·size… hasta el borde.
function MoveMode.GridLines(width, height, size)
  local function Offsets(length)
    local offsets = { 0 }
    local step = size
    while step <= length / 2 do
      offsets[#offsets + 1] = step
      offsets[#offsets + 1] = -step
      step = step + size
    end
    return offsets
  end
  return { vertical = Offsets(width), horizontal = Offsets(height) }
end

function MoveMode:SnapsToGrid()
  return self.active and Settings().grid and Settings().snapToGrid
end

function MoveMode:GridSize()
  return Settings().gridSize
end

-- Origen de la rejilla en coordenadas de UIParent: el centro de la pantalla.
function MoveMode:GridOrigin()
  return UIParent:GetWidth() / 2, UIParent:GetHeight() / 2
end

local function LineTexture(position)
  local texture = MoveMode.lineTextures[position]
  if not texture then
    texture = MoveMode.grid:CreateTexture(nil, "BACKGROUND")
    MoveMode.lineTextures[position] = texture
  end
  return texture
end

function MoveMode:DrawGrid()
  for _, texture in ipairs(self.lineTextures) do
    texture:Hide()
  end
  if not Settings().grid then
    self.grid:Hide()
    return
  end
  local lines = MoveMode.GridLines(UIParent:GetWidth(), UIParent:GetHeight(), Settings().gridSize)
  local used = 0
  local function Paint(texture, offset)
    local color = offset == 0 and CENTER_COLOR or GRID_COLOR
    texture:SetColorTexture(color[1], color[2], color[3], color[4])
    texture:Show()
  end
  for _, offset in ipairs(lines.vertical) do
    used = used + 1
    local texture = LineTexture(used)
    texture:ClearAllPoints()
    texture:SetPoint("TOP", self.grid, "TOP", offset, 0)
    texture:SetPoint("BOTTOM", self.grid, "BOTTOM", offset, 0)
    texture:SetWidth(1)
    Paint(texture, offset)
  end
  for _, offset in ipairs(lines.horizontal) do
    used = used + 1
    local texture = LineTexture(used)
    texture:ClearAllPoints()
    texture:SetPoint("LEFT", self.grid, "LEFT", 0, offset)
    texture:SetPoint("RIGHT", self.grid, "RIGHT", 0, offset)
    texture:SetHeight(1)
    Paint(texture, offset)
  end
  self.grid:Show()
end

local function SizeText()
  return string.format(L.MOVE_GRID_SIZE, Settings().gridSize)
end

local function FillText()
  return string.format(L.MOVE_FILL, Settings().fill)
end

local function SnapText()
  local distance = ns.Profiles.active.frames.snapDistance
  if distance <= 0 then
    return L.MOVE_MAGNET_OFF
  end
  return string.format(L.MOVE_MAGNET, distance)
end

local function PaintMover(mover)
  local lit = mover.hovered or mover.dragging
  mover:SetBackdropColor(GUIDE_COLOR[1], GUIDE_COLOR[2], GUIDE_COLOR[3], lit and 0.22 or 0.1)
  mover:SetBackdropBorderColor(GUIDE_COLOR[1], GUIDE_COLOR[2], GUIDE_COLOR[3], lit and 1 or 0.8)
end

-- Recuadro que cubre un bloque y lo arrastra entero (sustituye al cuadrado azul del ancla).
local function CreateMover(kind)
  local mover = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  mover:SetFrameStrata("HIGH")
  mover:SetBackdrop(Widgets.FLAT_BACKDROP)
  mover:EnableMouse(true)
  mover:RegisterForDrag("LeftButton")
  local label = Widgets.Label(mover, ns.Headers.ANCHOR_LABELS[kind], "GameFontHighlightSmall")
  label:SetPoint("BOTTOMLEFT", mover, "TOPLEFT", 1, 3)
  label:SetTextColor(GUIDE_COLOR[1], GUIDE_COLOR[2], GUIDE_COLOR[3], 1)
  mover.label = label
  mover:SetScript("OnEnter", function(self)
    self.hovered = true
    PaintMover(self)
  end)
  mover:SetScript("OnLeave", function(self)
    self.hovered = false
    PaintMover(self)
  end)
  mover:SetScript("OnDragStart", function(self)
    self.dragging = true
    PaintMover(self)
    ns.Headers:BeginDrag(kind)
  end)
  mover:SetScript("OnDragStop", function(self)
    self.dragging = false
    PaintMover(self)
    ns.Headers:EndDrag(kind)
  end)
  PaintMover(mover)
  MoveMode.movers[kind] = mover
  return mover
end

-- Un recuadro por bloque con miembros de ejemplo, pegado a su ancla para seguirlo al arrastrar.
function MoveMode:LayoutMovers()
  for _, mover in pairs(self.movers) do
    mover:Hide()
  end
  if not self.active then
    return
  end
  for _, kind in ipairs(ns.Headers.BLOCK_KINDS) do
    local rect = ns.Preview:BlockRect(kind)
    local anchor = ns.Headers.anchors[kind]
    if rect and anchor and anchor:GetLeft() then
      local mover = self.movers[kind] or CreateMover(kind)
      mover:ClearAllPoints()
      mover:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", rect.left - anchor:GetLeft(), rect.top - anchor:GetBottom())
      mover:SetSize(rect.right - rect.left, rect.top - rect.bottom)
      mover:Show()
    end
  end
end

-- Guías de alineación mientras se arrastra: guides = { x = línea vertical, y = línea horizontal } o nil.
function MoveMode:ShowGuides(guides)
  if not self.built then
    return
  end
  local x, y = guides and guides.x, guides and guides.y
  self.guideX:SetShown(x ~= nil)
  self.guideY:SetShown(y ~= nil)
  if x then
    self.guideX:ClearAllPoints()
    self.guideX:SetPoint("TOP", UIParent, "TOPLEFT", x, 0)
    self.guideX:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", x, 0)
  end
  if y then
    self.guideY:ClearAllPoints()
    self.guideY:SetPoint("LEFT", UIParent, "BOTTOMLEFT", 0, y)
    self.guideY:SetPoint("RIGHT", UIParent, "BOTTOMRIGHT", 0, y)
  end
end

function MoveMode:Build()
  local grid = CreateFrame("Frame", nil, UIParent)
  grid:SetAllPoints(UIParent)
  grid:SetFrameStrata("BACKGROUND")
  grid:EnableMouse(false)
  grid:Hide()
  self.grid = grid

  -- Guías del imán por encima de los bloques.
  local guides = CreateFrame("Frame", nil, UIParent)
  guides:SetAllPoints(UIParent)
  guides:SetFrameStrata("HIGH")
  guides:SetFrameLevel(50)
  guides:EnableMouse(false)
  self.guideX = Widgets.Line(guides, GUIDE_COLOR, "OVERLAY")
  self.guideX:SetWidth(1)
  self.guideX:Hide()
  self.guideY = Widgets.Line(guides, GUIDE_COLOR, "OVERLAY")
  self.guideY:SetHeight(1)
  self.guideY:Hide()

  local toolbar = CreateFrame("Frame", "HealsilusMoveToolbar", UIParent, "BackdropTemplate")
  toolbar:SetSize(TOOLBAR_WIDTH, TOOLBAR_HEIGHT)
  toolbar:SetPoint("TOP", UIParent, "TOP", 0, -40)
  toolbar:SetFrameStrata("DIALOG")
  Widgets.Surface(toolbar, Widgets.THEME.window, Widgets.THEME.border)
  Widgets.AccentStrip(toolbar)
  toolbar:EnableMouse(true)
  toolbar:SetMovable(true)
  toolbar:SetClampedToScreen(true)
  toolbar:RegisterForDrag("LeftButton")
  toolbar:SetScript("OnDragStart", toolbar.StartMoving)
  toolbar:SetScript("OnDragStop", toolbar.StopMovingOrSizing)
  toolbar:Hide()
  self.toolbar = toolbar

  local title = Widgets.Label(toolbar, L.MOVE_TITLE, "GameFontNormal")
  title:SetPoint("TOPLEFT", toolbar, "TOPLEFT", 16, -12)
  local help = Widgets.Label(toolbar, L.MOVE_HELP, "GameFontHighlightSmall")
  help:SetPoint("LEFT", title, "RIGHT", 10, 0)

  -- Fila de controles: imán y "mover juntos" | rejilla | relleno | terminar.
  local snapButton = Widgets.Button(toolbar, SnapText(), 104, function()
    local frames = ns.Profiles.active.frames
    frames.snapDistance = MoveMode.NextValue(MoveMode.SNAP_DISTANCES, frames.snapDistance)
    MoveMode:Refresh()
  end)
  snapButton:SetPoint("TOPLEFT", toolbar, "TOPLEFT", 14, -38)
  local togetherCheckbox = Widgets.Checkbox(toolbar, L.MOVE_TOGETHER, function()
    return ns.Profiles.active.frames.moveTogether
  end, function(value)
    ns.Profiles.active.frames.moveTogether = value
    MoveMode:Refresh()
  end)
  togetherCheckbox:SetPoint("LEFT", snapButton, "RIGHT", 12, 0)
  local gridCheckbox = Widgets.Checkbox(toolbar, L.MOVE_GRID, function()
    return Settings().grid
  end, function(value)
    Settings().grid = value
    MoveMode:Refresh()
  end)
  gridCheckbox:SetPoint("TOPLEFT", toolbar, "TOPLEFT", 270, -40)
  local snapCheckbox = Widgets.Checkbox(toolbar, L.MOVE_SNAP, function()
    return Settings().snapToGrid
  end, function(value)
    Settings().snapToGrid = value
    MoveMode:Refresh()
  end)
  snapCheckbox:SetPoint("LEFT", gridCheckbox, "RIGHT", 76, 0)
  local sizeButton = Widgets.Button(toolbar, SizeText(), 100, function()
    Settings().gridSize = MoveMode.NextValue(ns.Database.GRID_SIZES, Settings().gridSize)
    MoveMode:Refresh()
  end)
  sizeButton:SetPoint("TOPLEFT", toolbar, "TOPLEFT", 506, -38)
  local fillButton = Widgets.Button(toolbar, FillText(), 96, function()
    Settings().fill = MoveMode.NextValue(ns.Database.FILL_COUNTS, Settings().fill)
    ns.Preview:Show(Settings().fill)
    MoveMode:Refresh()
  end)
  fillButton:SetPoint("LEFT", sizeButton, "RIGHT", 8, 0)
  local doneButton = Widgets.Button(toolbar, L.MOVE_DONE, 110, function()
    MoveMode:Stop()
  end)
  doneButton:SetPoint("TOPRIGHT", toolbar, "TOPRIGHT", -14, -38)
  doneButton:SetVariant("primary")

  self.controls = {
    gridCheckbox = gridCheckbox, snapCheckbox = snapCheckbox, sizeButton = sizeButton, fillButton = fillButton,
    snapButton = snapButton, togetherCheckbox = togetherCheckbox,
  }
  self.built = true
end

function MoveMode:Refresh()
  if not self.built then
    return
  end
  local controls = self.controls
  controls.gridCheckbox:Refresh()
  controls.snapCheckbox:Refresh()
  controls.sizeButton:SetText(SizeText())
  controls.fillButton:SetText(FillText())
  controls.snapButton:SetText(SnapText())
  controls.togetherCheckbox:Refresh()
  if self.active then
    self:DrawGrid()
  end
end

local function SetLocked(locked)
  ns.Profiles.active.frames.locked = locked
  ns.Events:Fire("SETTINGS_CHANGED", "frames")
end

function MoveMode:Start()
  if InCombatLockdown() then
    ns.Print(L.MOVE_COMBAT)
    return false
  end
  if not ns.Headers.IsEnabled() then
    ns.Print(L.MOVE_DISABLED)
    return false
  end
  if not self.built then
    self:Build()
  end
  self.active = true
  SetLocked(false)
  ns.Preview:Show(Settings().fill)
  self:LayoutMovers()
  self.toolbar:Show()
  self:Refresh()
  if ns.Config.built and ns.Config.frame:IsShown() then
    ns.Config.frame:Hide()
  end
  ns.Events:Fire("MOVE_MODE_CHANGED", true)
  return true
end

function MoveMode:Stop()
  if not self.active then
    return
  end
  self.active = false
  self.toolbar:Hide()
  self.grid:Hide()
  self:ShowGuides(nil)
  self:LayoutMovers()
  ns.Preview:Hide()
  SetLocked(true)
  ns.Print(L.LOCKED)
  ns.Events:Fire("MOVE_MODE_CHANGED", false)
end

function MoveMode:Toggle()
  if self.active then
    self:Stop()
  else
    self:Start()
  end
end

-- PLAYER_REGEN_DISABLED llega antes del bloqueo de combate: aún se pueden ocultar y bloquear los bloques.
ns.Events:Register("COMBAT_STARTED", function()
  MoveMode:Stop()
end)
