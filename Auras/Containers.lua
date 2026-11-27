-- Auras con contenedores nativos (AuraContainer): Blizzard pinta los datos secretos; el addon nunca los lee.
-- Reglas (técnica de HealBot/DandersFrames probada en 12.1):
--   * crear y activar (SetEnabled) solo fuera de combate: en combate es un error del cliente que pcall no captura;
--   * orden: CreateFrame → anclar → SetUnit → AddAuraGroup → SetEnabled al final;
--   * Show/Hide y SetUnit sí se permiten en combate (tras Show se llama a UpdateAllAuras);
--   * nunca se lee nada de los botones de aura ni se ramifica con su contenido.
local _, ns = ...

local Containers = { supported = nil, pending = {} }
ns.Containers = Containers

local function Layout(size)
  return {
    elementWidth = size, elementHeight = size, elementSpacing = 1, lineSpacing = 1, groupSpacing = 0,
    elementSpacingX = 1, elementSpacingY = 1, gapX = 0,
  }
end

local function DispelOptions()
  local options = { customDispelColorMap = ns.Media.DispelColorMap(ns.Styles.active.auras.dispelColors) }
  if Enum.CustomAuraButtonDispelTypeTextureStyle then
    options.style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset
  end
  return options
end

local function AddDispelTexture(auraButton, texture)
  if auraButton.AddDispelTypeTexture then
    auraButton:AddDispelTypeTexture(texture, DispelOptions())
  elseif auraButton.SetAuraBorder then
    auraButton:SetAuraBorder(texture, DispelOptions())
  end
end

local function DisableMouse(frame)
  if frame.SetMouseClickEnabled then
    frame:SetMouseClickEnabled(false)
  end
  if frame.SetMouseMotionEnabled then
    frame:SetMouseMotionEnabled(false)
  end
end

-- Icono + cuenta atrás + acumulaciones; los debuffs llevan además un borde con el color del tipo de dispel.
local function MakeIconInitializer(size, withDispelBorder)
  return function(auraButton)
    if auraButton.healsilusReady then
      return
    end
    local ok, failure = pcall(function()
      auraButton:SetSize(size, size)
      DisableMouse(auraButton)
      local icon = auraButton:CreateTexture(nil, "ARTWORK")
      icon:SetAllPoints(auraButton)
      icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      auraButton:SetIcon(icon)
      if auraButton.SetDurationCooldown then
        local cooldown = CreateFrame("Cooldown", nil, auraButton, "CooldownFrameTemplate")
        cooldown:SetAllPoints(auraButton)
        cooldown:SetReverse(true)
        cooldown:SetDrawEdge(false)
        if cooldown.SetHideCountdownNumbers then
          cooldown:SetHideCountdownNumbers(false)
        end
        local countdown = cooldown.GetCountdownFontString and cooldown:GetCountdownFontString()
        if countdown then
          countdown:SetFont(STANDARD_TEXT_FONT, math.max(8, math.floor(size * 0.6)), "OUTLINE")
        end
        auraButton:SetDurationCooldown(cooldown)
      end
      if auraButton.SetApplicationCount then
        local count = auraButton:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        count:SetPoint("BOTTOMRIGHT", auraButton, "BOTTOMRIGHT", 1, -1)
        auraButton:SetApplicationCount(count, {})
      end
      if withDispelBorder then
        local border = auraButton:CreateTexture(nil, "BACKGROUND")
        border:SetPoint("TOPLEFT", auraButton, "TOPLEFT", -1, 1)
        border:SetPoint("BOTTOMRIGHT", auraButton, "BOTTOMRIGHT", 1, -1)
        border:SetColorTexture(1, 1, 1, 1)
        AddDispelTexture(auraButton, border)
      end
      auraButton.healsilusReady = true
    end)
    if not ok then
      ns.RecordError("Containers:InitializeIcon", failure)
    end
  end
end

-- Un único "aura" de 1x1 cuya textura cubre todo el botón de unidad: la barra de vida tapa el centro
-- y queda visible un anillo de 2 px con el color del debuff que puedes quitar.
local function MakeHighlightInitializer(unitButton)
  return function(auraButton)
    if auraButton.healsilusReady then
      return
    end
    local ok, failure = pcall(function()
      auraButton:SetSize(1, 1)
      DisableMouse(auraButton)
      local ring = auraButton:CreateTexture(nil, "ARTWORK")
      ring:SetAllPoints(unitButton)
      ring:SetColorTexture(1, 1, 1, 1)
      AddDispelTexture(auraButton, ring)
      auraButton.healsilusReady = true
    end)
    if not ok then
      ns.RecordError("Containers:InitializeHighlight", failure)
    end
  end
end

-- Variante "barra": la textura cubre la parte llena de la barra de vida y la tiñe del color del debuff,
-- como hace HealBot en Forever (HealBot_ForeverFrames.lua:113).
local BAR_TINT_ALPHA = 0.75

local function MakeBarTintInitializer(unitButton)
  return function(auraButton)
    if auraButton.healsilusReady then
      return
    end
    local ok, failure = pcall(function()
      auraButton:SetSize(1, 1)
      DisableMouse(auraButton)
      local tint = auraButton:CreateTexture(nil, "ARTWORK")
      tint:SetAllPoints(unitButton.healsilus.healthBar:GetStatusBarTexture())
      tint:SetColorTexture(1, 1, 1, 1)
      tint:SetAlpha(BAR_TINT_ALPHA)
      AddDispelTexture(auraButton, tint)
      auraButton.healsilusReady = true
    end)
    if not ok then
      ns.RecordError("Containers:InitializeBarTint", failure)
    end
  end
end

-- Lados por fuera de la barra: se anclan al botón entero (con su borde) y crecen alejándose de él.
local OUTSIDE_GAP = 3
local OUTSIDE = {
  ABOVE = { point = "BOTTOMLEFT", relativePoint = "TOPLEFT", x = 0, y = OUTSIDE_GAP, horizontal = "Right", vertical = "Up" },
  BELOW = { point = "TOPLEFT", relativePoint = "BOTTOMLEFT", x = 0, y = -OUTSIDE_GAP, horizontal = "Right", vertical = "Down" },
  OUTSIDE_LEFT = { point = "TOPRIGHT", relativePoint = "TOPLEFT", x = -OUTSIDE_GAP, y = 0, horizontal = "Left", vertical = "Down" },
  OUTSIDE_RIGHT = { point = "TOPLEFT", relativePoint = "TOPRIGHT", x = OUTSIDE_GAP, y = 0, horizontal = "Right", vertical = "Down" },
}

-- Cómo anclar un contenedor según la posición del estilo: una esquina dentro de la barra de vida
-- (1 px hacia dentro, crece hacia el centro) o un lado por fuera del botón.
-- relativeTo: "BAR" (barra de vida) o "BUTTON" (botón entero).
function Containers.Anchor(position)
  local outside = OUTSIDE[position]
  if outside then
    return {
      relativeTo = "BUTTON", point = outside.point, relativePoint = outside.relativePoint,
      x = outside.x, y = outside.y, horizontal = outside.horizontal, vertical = outside.vertical,
    }
  end
  local right = string.find(position, "RIGHT") ~= nil
  local top = string.find(position, "TOP") ~= nil
  return {
    relativeTo = "BAR", point = position, relativePoint = position,
    x = right and -1 or 1, y = top and -1 or 1,
    horizontal = right and "Left" or "Right", vertical = top and "Down" or "Up",
  }
end

local function BuildContainer(unitButton, spec)
  local anchor = Containers.Anchor(spec.position)
  local relativeFrame = anchor.relativeTo == "BUTTON" and unitButton or unitButton.healsilus.healthBar
  local container = CreateFrame("AuraContainer", nil, unitButton, "CustomAuraContainerTemplate")
  container:Hide()
  container:ClearAllPoints()
  container:SetPoint(anchor.point, relativeFrame, anchor.relativePoint, anchor.x, anchor.y)
  if container.SetFlowLayoutAnchorPoint then
    container:SetFlowLayoutAnchorPoint(anchor.point)
  end
  if container.SetFlowLayoutGrowthDirection and AnchorUtil and AnchorUtil.FlowDirection then
    local horizontal = AnchorUtil.FlowDirection[anchor.horizontal]
    local vertical = AnchorUtil.FlowDirection[anchor.vertical]
    if horizontal ~= nil and vertical ~= nil then
      container:SetFlowLayoutGrowthDirection(horizontal, vertical)
    end
  end
  container:SetFrameLevel(unitButton:GetFrameLevel() + spec.levelOffset)
  DisableMouse(container)
  container:SetUnit(unitButton.unit)
  local options = {
    maxFrameCount = spec.maxCount,
    initializeFrame = spec.initializer,
    layout = Layout(spec.size),
    candidateFilters = spec.candidateFilters,
    sortMethod = spec.sortMethod,
  }
  container:AddAuraGroup(spec.key, spec.filter, options)
  container:SetEnabled(true)
  return container
end

function Containers:IsSupported()
  if self.supported ~= nil then
    return self.supported
  end
  if InCombatLockdown() then
    return false
  end
  local ok, probe = pcall(CreateFrame, "AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
  if not ok then
    ns.RecordError("AuraContainer", probe)
    self.supported = false
    return false
  end
  self.supported = probe ~= nil and type(probe.AddAuraGroup) == "function"
  if probe then
    probe:Hide()
  end
  return self.supported
end

function Containers:Detach(button)
  local built = button.healsilusAuras
  if not built then
    return
  end
  for _, container in pairs(built) do
    container:Hide()
    container:SetEnabled(false)
  end
  button.healsilusAuras = nil
end

function Containers:Attach(button)
  if not button.unit then
    return
  end
  if InCombatLockdown() then
    self.pending[button] = true
    return
  end
  self.pending[button] = nil
  if not self:IsSupported() then
    return
  end
  self:Detach(button)
  -- Qué se vigila sale del perfil; tamaño, esquinas, colores y forma del aviso, del estilo activo.
  local auras = ns.Profiles.active.auras
  local look = ns.Styles.active.auras
  local sortMethod = AuraContainerSortMethod and AuraContainerSortMethod.UnitFrameDebuff
  local built = {}
  local ok, failure = pcall(function()
    if auras.hotsEnabled and auras.hotsMax > 0 then
      local spellIDs = ns.Spells:ExpandRanks(auras.hotSpellIDs)
      if next(spellIDs) then
        built.hots = BuildContainer(button, {
          key = "healsilusHots", filter = "HELPFUL|PLAYER", maxCount = auras.hotsMax, size = look.iconSize,
          initializer = MakeIconInitializer(look.iconSize, false), position = look.hotsPoint,
          levelOffset = 8, candidateFilters = { includeSpellIDs = spellIDs },
        })
      end
    end
    if auras.debuffsEnabled and auras.debuffsMax > 0 then
      built.debuffs = BuildContainer(button, {
        key = "healsilusDebuffs", filter = auras.debuffsDispellableOnly and "HARMFUL|RAID" or "HARMFUL",
        maxCount = auras.debuffsMax, size = look.iconSize, initializer = MakeIconInitializer(look.iconSize, true),
        position = look.debuffsPoint, levelOffset = 8, sortMethod = sortMethod,
      })
      if look.dispelMode ~= "BAR" then
        built.highlight = BuildContainer(button, {
          key = "healsilusDispel", filter = "HARMFUL|RAID", maxCount = 1, size = 1,
          initializer = MakeHighlightInitializer(button), position = "TOPLEFT",
          levelOffset = 1, sortMethod = sortMethod,
        })
      end
      if look.dispelMode ~= "RING" then
        built.tint = BuildContainer(button, {
          key = "healsilusDispelTint", filter = "HARMFUL|RAID", maxCount = 1, size = 1,
          initializer = MakeBarTintInitializer(button), position = "TOPLEFT",
          levelOffset = 3, sortMethod = sortMethod,
        })
      end
    end
  end)
  if not ok then
    for _, container in pairs(built) do
      container:Hide()
    end
    ns.RecordError("Containers:Attach", failure)
    return
  end
  button.healsilusAuras = built
  self:UpdateVisibility(button)
end

function Containers:UpdateVisibility(button)
  local built = button.healsilusAuras
  if not built then
    return
  end
  for _, container in pairs(built) do
    if button.unit then
      container:Show()
      container:UpdateAllAuras()
    else
      container:Hide()
    end
  end
end

function Containers:SetUnit(button, unit)
  local built = button.healsilusAuras
  if not built then
    if unit then
      self:Attach(button)
    end
    return
  end
  if unit then
    for key, container in pairs(built) do
      local ok, failure = pcall(container.SetUnit, container, unit)
      if not ok then
        container:Hide()
        built[key] = nil
        ns.RecordError("Containers:SetUnit", failure)
      end
    end
  end
  self:UpdateVisibility(button)
end

function Containers:RebuildAll()
  ns.CombatQueue:Run("auras", function()
    if not ns.UnitButton then
      return
    end
    for button in pairs(ns.UnitButton.buttons) do
      Containers:Attach(button)
    end
  end)
end

ns.Events:Register("COMBAT_ENDED", function()
  local pending = Containers.pending
  Containers.pending = {}
  for button in pairs(pending) do
    Containers:Attach(button)
  end
end)

local function Rebuild()
  Containers:RebuildAll()
end
ns.Events:Register("PROFILE_CHANGED", Rebuild)
ns.Events:Register("STYLE_CHANGED", Rebuild)
ns.Events:Register("SPELLBOOK_UPDATED", Rebuild)
ns.Events:Register("SETTINGS_CHANGED", function(section)
  if section == "auras" or section == "style" then
    Rebuild()
  end
end)
