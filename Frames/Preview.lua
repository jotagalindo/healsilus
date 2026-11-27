-- Vista previa: marcos NO seguros con miembros falsos para ver el diseño sin estar en grupo.
-- Rellena cada bloque activo (grupo/banda, tanques, mascotas, objetivo y foco) para alinearlos como
-- quedarán de verdad. Mientras está abierta, los bloques reales se ocultan; en combate se cierra sola.
local _, ns = ...
local L = ns.L

local Preview = { frames = {}, count = 0, byKind = {} }
ns.Preview = Preview

-- threat: nivel de amenaza falso (3 = tanquea, 1 = mucha amenaza) para ver el borde y los puntos.
-- power: fracción de maná/ira/energía y powerToken, su tipo (decide el color de la barra).
-- hots: cuántos HoTs tuyos lleva; debuff: tipo de un debuff que puedes quitar.
local FAKE_MEMBERS = {
  { name = "Gromash", class = "WARRIOR", role = "TANK", health = 0.62, threat = 3, power = 0.45, powerToken = "RAGE", hots = 2 },
  { name = "Arsilus", class = "DRUID", role = "HEALER", health = 1, power = 0.82, powerToken = "MANA" },
  { name = "Velenna", class = "PRIEST", role = "HEALER", health = 0.48, power = 0.31, powerToken = "MANA", hots = 1, debuff = "Magic" },
  { name = "Thrall", class = "SHAMAN", role = "DAMAGER", health = 0.85, missing = true, power = 0.9, powerToken = "MANA" },
  { name = "Lejana", class = "MAGE", role = "DAMAGER", health = 0.7, outOfRange = true, power = 0.6, powerToken = "MANA" },
  { name = "Korgan", class = "ROGUE", role = "DAMAGER", health = 0, dead = true, power = 0, powerToken = "ENERGY" },
  { name = "Sylvara", class = "HUNTER", role = "DAMAGER", health = 0.93, threat = 1, power = 0.74, powerToken = "MANA" },
  { name = "Morvath", class = "WARLOCK", role = "DAMAGER", health = 0.35, power = 0.55, powerToken = "MANA" },
  { name = "Brannoc", class = "PALADIN", role = "TANK", health = 0.77, power = 0.66, powerToken = "MANA" },
}

local FAKE_PETS = {
  { name = "Lobo", pet = true, health = 0.8, power = 0.7, powerToken = "FOCUS" },
  { name = "Diablillo", pet = true, health = 0.55, power = 0.9, powerToken = "ENERGY" },
  { name = "Tigre", pet = true, health = 1, power = 0.4, powerToken = "FOCUS" },
}

local FAKE_MAX_HEALTH = 8000

-- Iconos de ejemplo: Rejuvenecimiento y Recrecimiento, Palabra de las Sombras: dolor y Marca de lo Salvaje.
local FAKE_HOT_ICONS = { "Interface\\Icons\\Spell_Nature_Rejuvenation", "Interface\\Icons\\Spell_Nature_ResistNature" }
local FAKE_DEBUFF_ICON = "Interface\\Icons\\Spell_Shadow_ShadowWordPain"
local FAKE_BUFF_ICON = "Interface\\Icons\\Spell_Nature_Regeneration"
local AURA_LEVEL = 8

-- Miembros de ejemplo de los bloques secundarios: tanques, mascotas y un objetivo y un foco amistosos.
local SAMPLE_TANKS = { FAKE_MEMBERS[1], FAKE_MEMBERS[9] }
-- Barras de la vista de ejemplo de la pestaña Aspecto: tanque con aggro, vida llena, herida con un
-- debuff, sin un buff y muerto.
Preview.SAMPLE_MEMBERS = { FAKE_MEMBERS[1], FAKE_MEMBERS[2], FAKE_MEMBERS[3], FAKE_MEMBERS[4], FAKE_MEMBERS[6] }
local SAMPLE_TARGET = { FAKE_MEMBERS[3] }
local SAMPLE_FOCUS = { FAKE_MEMBERS[7] }

-- Bloques que se rellenan según el perfil, con sus miembros de ejemplo. count = miembros del principal.
function Preview.Blocks(frames, count)
  local blocks = {}
  local function Add(kind, wanted, members)
    if wanted then
      blocks[#blocks + 1] = { kind = kind, members = members }
    end
  end
  local party = {}
  for position = 1, count do
    party[position] = FAKE_MEMBERS[(position - 1) % #FAKE_MEMBERS + 1]
  end
  Add("party", frames.showMain, party)
  Add("tanks", frames.showTanks, SAMPLE_TANKS)
  Add("pets", frames.showPets, FAKE_PETS)
  Add("target", frames.showTarget, SAMPLE_TARGET)
  Add("focus", frames.showFocus, SAMPLE_FOCUS)
  return blocks
end

-- Disposición de cada bloque como la cabecera real: tanques en una sola columna (o fila), objetivo
-- y foco un único botón; grupo y mascotas usan las columnas del estilo.
function Preview.BlockLayout(kind, layout)
  if kind == "tanks" or kind == "target" or kind == "focus" then
    local single = {}
    for key, value in pairs(layout) do
      single[key] = value
    end
    single.unitsPerColumn = 40
    return single
  end
  return layout
end

function Preview.Offset(position, layout)
  local column = math.floor((position - 1) / layout.unitsPerColumn)
  local row = (position - 1) % layout.unitsPerColumn
  local stepX, stepY = layout.width + layout.spacing, layout.height + layout.spacing
  if layout.growth == "DOWN" then
    return column * stepX, -row * stepY
  end
  return row * stepX, -column * stepY
end

-- Valores falsos y legibles: aquí sí se puede calcular el color en Lua.
function Preview.HealthColor(fraction)
  if fraction < 0.5 then
    return 1, fraction * 2, 0
  end
  return (1 - fraction) * 2, 1, 0
end

function Preview.HealthText(mode, fraction)
  local percent = string.format("%d%%", math.floor(fraction * 100 + 0.5))
  local current = AbbreviateLargeNumbers(math.floor(fraction * FAKE_MAX_HEALTH))
  if mode == "PERCENT" then
    return percent
  end
  if mode == "DEFICIT" and fraction < 1 then
    return "-" .. AbbreviateLargeNumbers(math.floor((1 - fraction) * FAKE_MAX_HEALTH))
  end
  if mode == "CURRENT" then
    return current
  end
  if mode == "CURRENT_MAX" then
    return current .. " / " .. AbbreviateLargeNumbers(FAKE_MAX_HEALTH)
  end
  if mode == "CURRENT_PERCENT" then
    return current .. " · " .. percent
  end
  return ""
end

-- Iconos falsos de un grupo (HoTs o debuffs) colocados como los pondría su contenedor real.
-- border: color del marco del icono (tipo de dispel) o nil.
function Preview.PaintAuraIcons(frame, key, group, icons, border)
  local visual = frame.healsilus
  visual.fakeAuras = visual.fakeAuras or {}
  local pool = visual.fakeAuras[key]
  if not pool then
    pool = {}
    visual.fakeAuras[key] = pool
  end
  if not visual.fakeAuraFrame then
    visual.fakeAuraFrame = CreateFrame("Frame", nil, frame)
    visual.fakeAuraFrame:SetAllPoints(frame)
    visual.fakeAuraFrame:SetFrameLevel(frame:GetFrameLevel() + AURA_LEVEL)
  end
  local anchor = ns.StyleData.AuraAnchor(group)
  local relative = anchor.relativeTo == "BUTTON" and frame or visual.healthBar
  local step = (group.iconSize + 1) * (anchor.horizontal == "Left" and -1 or 1)
  for position = 1, math.max(#icons, #pool) do
    local entry = pool[position]
    if not entry and icons[position] then
      entry = { edge = visual.fakeAuraFrame:CreateTexture(nil, "ARTWORK", nil, 1) }
      entry.icon = visual.fakeAuraFrame:CreateTexture(nil, "ARTWORK", nil, 2)
      entry.icon:SetPoint("TOPLEFT", entry.edge, "TOPLEFT", 1, -1)
      entry.icon:SetPoint("BOTTOMRIGHT", entry.edge, "BOTTOMRIGHT", -1, 1)
      entry.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      pool[position] = entry
    end
    if entry then
      local shown = icons[position] ~= nil
      entry.edge:SetShown(shown)
      entry.icon:SetShown(shown)
      if shown then
        entry.edge:ClearAllPoints()
        entry.edge:SetSize(group.iconSize, group.iconSize)
        entry.edge:SetPoint(anchor.point, relative, anchor.relativePoint, anchor.x + (position - 1) * step, anchor.y)
        local color = border or { r = 0, g = 0, b = 0 }
        entry.edge:SetColorTexture(color.r, color.g, color.b, 1)
        entry.icon:SetTexture(icons[position])
      end
    end
  end
end

function Preview:PaintAuras(frame, member, style)
  local auras = ns.Profiles.active.auras
  local hots = {}
  if auras.hotsEnabled and not member.dead then
    for position = 1, math.min(member.hots or 0, auras.hotsMax) do
      hots[position] = FAKE_HOT_ICONS[(position - 1) % #FAKE_HOT_ICONS + 1]
    end
  end
  Preview.PaintAuraIcons(frame, "hots", style.auras.hots, hots)
  local debuffs = {}
  if auras.debuffsEnabled and member.debuff and not member.dead then
    for position = 1, math.min(member.debuffCount or 1, auras.debuffsMax) do
      debuffs[position] = FAKE_DEBUFF_ICON
    end
  end
  Preview.PaintAuraIcons(frame, "debuffs", style.auras.debuffs, debuffs,
    member.debuff and style.auras.dispelColors[member.debuff] or nil)
  ns.UnitButton.ShowMissing(frame.healsilus, member.missing == true, FAKE_BUFF_ICON)
end

function Preview:Paint(frame, member, style)
  local visual = frame.healsilus
  frame:SetSize(style.layout.width, style.layout.height)
  ns.UnitButton:ApplyStyle(frame)
  visual.healthBar:SetMinMaxValues(0, 1)
  visual.healthBar:SetValue(member.health)
  visual.nameText:SetText(member.name)
  visual.healthText:SetText(member.dead and "" or Preview.HealthText(style.text.health.mode, member.health))
  visual.statusText:SetText(member.dead and L.STATUS_DEAD or "")
  local full = member.health >= 1 and not member.dead
  ns.UnitButton.PaintFade(visual, full and style.bar.fullHealthAlpha or 1)
  if member.pet then
    local color = ns.Media.PET_COLOR
    ns.UnitButton.PaintFill(visual, color.r, color.g, color.b)
  elseif style.bar.colorMode == "HEALTH" then
    ns.UnitButton.PaintFill(visual, Preview.HealthColor(member.health))
  else
    ns.UnitButton.PaintFill(visual, ns.Media.ClassColor(member.class))
  end
  local showPower = ns.UnitButton.WantsPower(style, member.role)
    and ns.UnitButton.WantsPowerType(style, member.powerToken)
  ns.UnitButton.ShowPowerBar(visual, showPower, style.power.thickness)
  if showPower then
    ns.UnitButton.PaintPower(visual, member.powerToken)
    visual.powerBar:SetMinMaxValues(0, 1)
    visual.powerBar:SetValue(member.power)
  end
  self:PaintAuras(frame, member, style)
  ns.UnitButton.ShowThreat(visual, member.threat, style)
  ns.UnitButton.ShowRole(visual, member.role, style)
  frame:SetAlpha(member.outOfRange and style.bar.outOfRangeAlpha or 1)
end

function Preview:Show(count)
  if InCombatLockdown() then
    ns.Print(L.PREVIEW_COMBAT)
    return
  end
  self:HideFrames()
  ns.Headers.previewActive = true
  ns.Headers:ApplyProfile(ns.Profiles.active)
  local style = ns.Styles.active
  local used = 0
  self.byKind = {}
  for _, block in ipairs(Preview.Blocks(ns.Profiles.active.frames, count)) do
    local anchor = ns.Headers.anchors[block.kind]
    local layout = Preview.BlockLayout(block.kind, style.layout)
    local shown = {}
    for position, member in ipairs(block.members) do
      used = used + 1
      local frame = self.frames[used]
      if not frame then
        frame = CreateFrame("Frame", nil, UIParent)
        ns.UnitButton:BuildVisuals(frame)
        self.frames[used] = frame
      end
      local x, y = Preview.Offset(position, layout)
      frame:ClearAllPoints()
      frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x, y - 2)
      self:Paint(frame, member, style)
      frame:Show()
      shown[#shown + 1] = frame
    end
    self.byKind[block.kind] = shown
  end
  self.count = count
  if ns.MoveMode and ns.MoveMode.active then
    ns.MoveMode:LayoutMovers()
  end
end

-- Rectángulo que ocupan los miembros de ejemplo de un bloque (para el imán), o nil si no tiene.
function Preview:BlockRect(kind)
  local frames = self.byKind and self.byKind[kind]
  if not frames or #frames == 0 then
    return nil
  end
  local rect
  for _, frame in ipairs(frames) do
    local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    if not left or not right or not top or not bottom then
      return nil
    end
    if not rect then
      rect = { left = left, right = right, top = top, bottom = bottom }
    else
      rect.left, rect.right = math.min(rect.left, left), math.max(rect.right, right)
      rect.top, rect.bottom = math.max(rect.top, top), math.min(rect.bottom, bottom)
    end
  end
  return rect
end

function Preview:HideFrames()
  for _, frame in ipairs(self.frames) do
    frame:Hide()
  end
end

function Preview:Hide()
  self:HideFrames()
  self.count = 0
  self.byKind = {}
  if ns.Headers.previewActive then
    ns.Headers.previewActive = false
    ns.Headers:ApplyProfile(ns.Profiles.active)
  end
end

-- PLAYER_REGEN_DISABLED llega justo antes del bloqueo: aún se puede volver a mostrar la cabecera.
ns.Events:Register("COMBAT_STARTED", function()
  if Preview.count > 0 then
    Preview:Hide()
  end
end)

ns.Events:Register("SETTINGS_CHANGED", function(section)
  if (section == "frames" or section == "style") and Preview.count > 0 then
    Preview:Show(Preview.count)
  end
end)

ns.Events:Register("STYLE_CHANGED", function()
  if Preview.count > 0 then
    Preview:Show(Preview.count)
  end
end)
