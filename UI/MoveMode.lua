-- Modo mover: desbloquea los bloques, rellena cada uno con miembros de ejemplo (Frames/Preview.lua),
-- dibuja una rejilla en pantalla para alinearlos y, si se quiere, pega cada bloque soltado a ella.
-- Una barra arriba de la pantalla deja cambiar la rejilla y el relleno, y "Terminar" lo bloquea todo.
-- Solo fuera de combate: al entrar en combate se cierra solo.
local _, ns = ...
local L = ns.L
local Widgets = ns.Widgets

local MoveMode = { active = false, built = false, lineTextures = {} }
ns.MoveMode = MoveMode

local GRID_COLOR = { 1, 1, 1, 0.12 }
local CENTER_COLOR = { 1, 0.35, 0.35, 0.55 }
local TOOLBAR_WIDTH, TOOLBAR_HEIGHT = 650, 72

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

function MoveMode:Build()
  local grid = CreateFrame("Frame", nil, UIParent)
  grid:SetAllPoints(UIParent)
  grid:SetFrameStrata("BACKGROUND")
  grid:EnableMouse(false)
  grid:Hide()
  self.grid = grid

  local toolbar = CreateFrame("Frame", "HealsilusMoveToolbar", UIParent, "BackdropTemplate")
  toolbar:SetSize(TOOLBAR_WIDTH, TOOLBAR_HEIGHT)
  toolbar:SetPoint("TOP", UIParent, "TOP", 0, -40)
  toolbar:SetFrameStrata("DIALOG")
  toolbar:SetBackdrop(Widgets.DIALOG_BACKDROP)
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

  local gridCheckbox = Widgets.Checkbox(toolbar, L.MOVE_GRID, function()
    return Settings().grid
  end, function(value)
    Settings().grid = value
    MoveMode:Refresh()
  end)
  gridCheckbox:SetPoint("TOPLEFT", toolbar, "TOPLEFT", 14, -36)
  local snapCheckbox = Widgets.Checkbox(toolbar, L.MOVE_SNAP, function()
    return Settings().snapToGrid
  end, function(value)
    Settings().snapToGrid = value
    MoveMode:Refresh()
  end)
  snapCheckbox:SetPoint("TOPLEFT", toolbar, "TOPLEFT", 110, -36)
  local sizeButton = Widgets.Button(toolbar, SizeText(), 120, function()
    Settings().gridSize = MoveMode.NextValue(ns.Database.GRID_SIZES, Settings().gridSize)
    MoveMode:Refresh()
  end)
  sizeButton:SetPoint("TOPLEFT", toolbar, "TOPLEFT", 270, -36)
  local fillButton = Widgets.Button(toolbar, FillText(), 120, function()
    Settings().fill = MoveMode.NextValue(ns.Database.FILL_COUNTS, Settings().fill)
    ns.Preview:Show(Settings().fill)
    MoveMode:Refresh()
  end)
  fillButton:SetPoint("TOPLEFT", toolbar, "TOPLEFT", 396, -36)
  local doneButton = Widgets.Button(toolbar, L.MOVE_DONE, 110, function()
    MoveMode:Stop()
  end)
  doneButton:SetPoint("TOPLEFT", toolbar, "TOPLEFT", 522, -36)

  self.controls = { gridCheckbox = gridCheckbox, snapCheckbox = snapCheckbox, sizeButton = sizeButton, fillButton = fillButton }
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
