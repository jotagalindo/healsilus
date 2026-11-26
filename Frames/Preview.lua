-- Vista previa: marcos NO seguros con miembros falsos para ver el diseño sin estar en grupo.
-- Mientras está abierta, la cabecera de grupo se oculta; al entrar en combate se cierra sola.
local _, ns = ...
local L = ns.L

local Preview = { frames = {}, count = 0 }
ns.Preview = Preview

local FAKE_MEMBERS = {
  { name = "Gromash", class = "WARRIOR", health = 0.62, aggro = true },
  { name = "Arsilus", class = "DRUID", health = 1 },
  { name = "Velenna", class = "PRIEST", health = 0.48 },
  { name = "Thrall", class = "SHAMAN", health = 0.85, missing = true },
  { name = "Lejana", class = "MAGE", health = 0.7, outOfRange = true },
  { name = "Korgan", class = "ROGUE", health = 0, dead = true },
  { name = "Sylvara", class = "HUNTER", health = 0.93 },
  { name = "Morvath", class = "WARLOCK", health = 0.35 },
  { name = "Brannoc", class = "PALADIN", health = 0.77 },
}

local FAKE_MAX_HEALTH = 8000

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

local function HealthText(mode, fraction)
  if mode == "PERCENT" then
    return string.format("%d%%", math.floor(fraction * 100 + 0.5))
  end
  if mode == "DEFICIT" and fraction < 1 then
    return "-" .. AbbreviateLargeNumbers(math.floor((1 - fraction) * FAKE_MAX_HEALTH))
  end
  return ""
end

function Preview:Paint(frame, member, style)
  local visual = frame.healsilus
  frame:SetSize(style.layout.width, style.layout.height)
  ns.UnitButton:ApplyStyle(frame)
  visual.healthBar:SetMinMaxValues(0, 1)
  visual.healthBar:SetValue(member.health)
  visual.nameText:SetText(member.name)
  visual.healthText:SetText(member.dead and "" or HealthText(style.text.health.mode, member.health))
  visual.statusText:SetText(member.dead and L.STATUS_DEAD or "")
  local texture = visual.healthBar:GetStatusBarTexture()
  if style.bar.colorMode == "HEALTH" then
    texture:SetVertexColor(Preview.HealthColor(member.health))
  else
    texture:SetVertexColor(ns.Media.ClassColor(member.class))
  end
  visual.missingMark:SetShown(member.missing == true)
  visual.aggroFrame:SetShown(member.aggro == true)
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
  local anchor = ns.Headers.anchors.party
  for position = 1, count do
    local frame = self.frames[position]
    if not frame then
      frame = CreateFrame("Frame", nil, UIParent)
      ns.UnitButton:BuildVisuals(frame)
      self.frames[position] = frame
    end
    local x, y = Preview.Offset(position, style.layout)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x, y - 2)
    self:Paint(frame, FAKE_MEMBERS[(position - 1) % #FAKE_MEMBERS + 1], style)
    frame:Show()
  end
  self.count = count
end

function Preview:HideFrames()
  for _, frame in ipairs(self.frames) do
    frame:Hide()
  end
end

function Preview:Hide()
  self:HideFrames()
  self.count = 0
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
