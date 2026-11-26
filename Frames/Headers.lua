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

local SORT_ATTRIBUTES = {
  GROUP = { groupBy = "GROUP", groupingOrder = "1,2,3,4,5,6,7,8" },
  CLASS = { groupBy = "CLASS", groupingOrder = "WARRIOR,PALADIN,DRUID,PRIEST,SHAMAN,ROGUE,HUNTER,MAGE,WARLOCK" },
  ROLE = { groupBy = "ASSIGNEDROLE", groupingOrder = "TANK,HEALER,DAMAGER,NONE" },
}

-- Entorno restringido: cada botón nuevo toma tamaño y clics de su cabecera y pide su parte visual.
local INITIAL_CONFIG = [[
  local header = self:GetParent()
  self:SetWidth(header:GetAttribute("hs-width"))
  self:SetHeight(header:GetAttribute("hs-height"))
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

local function SavePosition(kind, anchor)
  local point, _, _, x, y = anchor:GetPoint(1)
  ns.Database.db.framePositions[kind] = { point, x, y }
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
  anchor:SetScript("OnDragStart", function(self)
    if not InCombatLockdown() then
      self:StartMoving()
    end
  end)
  anchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition(kind, self)
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
  local frames = ns.Profiles.active.frames
  button:SetSize(frames.width, frames.height)
  button:SetPoint("TOPLEFT", self.anchors[kind], "BOTTOMLEFT", 0, -2)
  button.healsilusVisibility = visibility
  self.singles[kind] = button
  ns.UnitButton:Init(button, kind)
  return button
end

function Headers:ApplyHeaderLayout(header, frames)
  local kind = header.healsilusKind
  local down = frames.growth == "DOWN"
  SetAttributes(header, {
    ["hs-width"] = frames.width,
    ["hs-height"] = frames.height,
    point = down and "TOP" or "LEFT",
    xOffset = down and 0 or frames.spacing,
    yOffset = down and -frames.spacing or 0,
    columnAnchorPoint = down and "LEFT" or "TOP",
    columnSpacing = frames.spacing,
    showRaid = true,
    showParty = true,
    showPlayer = true,
  })
  if kind == "tanks" then
    SetAttributes(header, { roleFilter = "MAINTANK,TANK", showSolo = false, unitsPerColumn = MAX_BUTTONS.tanks, maxColumns = 1 })
  elseif kind == "pets" then
    SetAttributes(header, { showSolo = frames.showSolo, unitsPerColumn = frames.unitsPerColumn, maxColumns = frames.columns })
  else
    local sort = SORT_ATTRIBUTES[frames.sortBy]
    SetAttributes(header, {
      showSolo = frames.showSolo, unitsPerColumn = frames.unitsPerColumn, maxColumns = frames.columns,
      groupBy = sort.groupBy, groupingOrder = sort.groupingOrder, groupFilter = "1,2,3,4,5,6,7,8",
    })
  end
  -- Los botones ya creados no vuelven a pasar por initialConfigFunction: se redimensionan aquí.
  local position = 1
  local child = header:GetAttribute("child1")
  while child do
    child:SetSize(frames.width, frames.height)
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
function Headers:Precreate(header)
  local maximum = MAX_BUTTONS[header.healsilusKind]
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

function Headers:SetLocked(locked)
  for _, anchor in pairs(self.anchors) do
    anchor.handle:SetShown(not locked)
    anchor.label:SetShown(not locked)
    anchor:EnableMouse(not locked)
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
  for _, kind in ipairs({ "party", "tanks", "pets", "target", "focus" }) do
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
    self:Precreate(header)
    self:ApplyHeaderLayout(header, frames)
  end
  self.initialized = true
  self:ApplyProfile(ns.Profiles.active)
end

function Headers:Initialize()
  ns.CombatQueue:Run("headers:create", function()
    Headers:Create()
  end)
end

function Headers:ApplyProfile(profile)
  if not self.initialized then
    return
  end
  ns.CombatQueue:Run("headers:apply", function()
    local frames = profile.frames
    for _, header in ipairs(Headers.list) do
      Headers:ApplyHeaderLayout(header, frames)
    end
    Headers:SetHeaderShown("party", not Headers.previewActive)
    Headers:SetHeaderShown("tanks", frames.showTanks and not Headers.previewActive)
    Headers:SetHeaderShown("pets", frames.showPets and not Headers.previewActive)
    for kind, button in pairs(Headers.singles) do
      button:SetSize(frames.width, frames.height)
      local enabled = (kind == "target" and frames.showTarget) or (kind == "focus" and frames.showFocus)
      RegisterStateDriver(button, "visibility", enabled and button.healsilusVisibility or "hide")
    end
    Headers:ApplyBlizzardVisibility(frames.hideBlizzard)
    Headers:SetLocked(frames.locked)
    ns.ClickCast:Apply(profile)
  end)
end

ns.Events:Register("PROFILE_CHANGED", function(profile)
  Headers:ApplyProfile(profile)
end)

ns.Events:Register("SETTINGS_CHANGED", function(section)
  if section == "frames" then
    Headers:ApplyProfile(ns.Profiles.active)
  end
end)
