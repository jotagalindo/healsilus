local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertFalse, assertNil = Harness.assertEquals, Harness.assertTrue, Harness.assertFalse, Harness.assertNil

local FILES = {
  "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/CombatQueue.lua", "Core/Database.lua", "Core/StyleData.lua",
  "Frames/Media.lua", "Frames/Curves.lua", "Frames/UnitButton.lua",
}

local function LoadUnitButton()
  local environment = Stubs.NewEnvironment()
  local world = { inRange = true, checked = true, threat = nil, missing = 0, connected = true, dead = false }
  environment.UnitIsUnit = function(unit, other)
    return unit == other
  end
  environment.UnitInRange = function()
    return world.inRange, world.checked
  end
  environment.UnitThreatSituation = function()
    return world.threat
  end
  environment.UnitHealthMissing = function()
    return world.missing
  end
  environment.UnitIsConnected = function()
    return world.connected
  end
  environment.UnitIsDeadOrGhost = function()
    return world.dead
  end
  environment.AbbreviateLargeNumbers = function(value)
    if Stubs.IsSecret(value) then
      error("AbbreviateLargeNumbers does not accept secrets")
    end
    return tostring(value)
  end
  local ns = Loader.Load(environment, FILES)
  ns.Profiles = { active = ns.Database.DefaultProfile() }
  ns.Styles = { active = ns.StyleData.DefaultStyle() }
  return ns, environment, world
end

-- Con la opción del juego "lanzar al pulsar", SecureActionButtonTemplate solo actúa al pulsar:
-- hay que registrar pulsar y soltar y decidir con useOnKeyDown cuál de los dos lanza.
describe("UnitButton click registration", function()
  local function FakeSecureButton()
    local button = { attributes = {} }
    function button:RegisterForClicks(...)
      self.clicks = { ... }
    end
    function button:SetAttribute(name, value)
      self.attributes[name] = value
    end
    return button
  end

  it("listens to press and release and casts on release by default", function()
    local ns = LoadUnitButton()
    local button = FakeSecureButton()
    ns.UnitButton:ApplyClickRegistration(button)
    assertEquals(button.clicks, { "AnyUp", "AnyDown" })
    assertEquals(button.attributes.useOnKeyDown, false)
  end)

  it("casts on press when the profile asks for it", function()
    local ns = LoadUnitButton()
    ns.Profiles.active.frames.castOnDown = true
    local button = FakeSecureButton()
    ns.UnitButton:ApplyClickRegistration(button)
    assertEquals(button.attributes.useOnKeyDown, true)
  end)
end)

local function InstallCurves(environment)
  local function Factory()
    local curve = {}
    function curve:SetType() end
    function curve:AddPoint() end
    return curve
  end
  environment.C_CurveUtil = { CreateCurve = Factory, CreateColorCurve = Factory }
  environment.Enum.LuaCurveType = { Linear = 0 }
  environment.CreateColor = function()
    return {}
  end
  environment.UnitHealthPercent = function()
    return 75
  end
end

local function FakeRegion()
  local region = { shown = true }
  function region:SetText(text)
    self.text = text
  end
  function region:SetShown(shown)
    self.shown = shown and true or false
  end
  function region:Hide()
    self.shown = false
  end
  function region:Show()
    self.shown = true
  end
  function region:SetAtlas(atlas)
    self.atlas = atlas
  end
  function region:SetTextColor(red, green, blue, alpha)
    self.textColor = { red, green, blue, alpha }
  end
  return region
end

local function ShownDots(button)
  local shown = 0
  for _, dot in ipairs(button.healsilus.aggroDots) do
    if dot.shown then
      shown = shown + 1
    end
  end
  return shown
end

local function FakeButton(unit)
  local button = {
    unit = unit,
    healsilus = {
      healthText = FakeRegion(), statusText = FakeRegion(), aggroFrame = FakeRegion(), roleIcon = FakeRegion(),
      aggroDots = { FakeRegion(), FakeRegion(), FakeRegion() },
    },
  }
  function button:SetAlpha(alpha)
    self.alpha = alpha
  end
  function button:SetAlphaFromBoolean(value, whenTrue, whenFalse)
    self.fromBoolean = { value, whenTrue, whenFalse }
  end
  return button
end

describe("UnitButton range", function()
  it("keeps the player and units without range data fully visible", function()
    local ns, _, world = LoadUnitButton()
    local player = FakeButton("player")
    ns.UnitButton:UpdateRange(player)
    assertEquals(player.alpha, 1)
    world.checked = false
    world.inRange = false
    local party = FakeButton("party1")
    ns.UnitButton:UpdateRange(party)
    assertEquals(party.alpha, 1)
  end)

  it("fades readable out-of-range units", function()
    local ns, _, world = LoadUnitButton()
    local party = FakeButton("party1")
    ns.UnitButton:UpdateRange(party)
    assertEquals(party.alpha, 1)
    world.inRange = false
    ns.UnitButton:UpdateRange(party)
    assertEquals(party.alpha, 0.4)
  end)

  it("hands a secret range flag to SetAlphaFromBoolean only when the probe confirmed it works", function()
    local ns, _, world = LoadUnitButton()
    local secret = Stubs.MakeSecret()
    world.inRange = secret
    local party = FakeButton("party1")
    ns.UnitButton.alphaFromBooleanWorks = true
    ns.UnitButton:UpdateRange(party)
    assertTrue(rawequal(party.fromBoolean[1], secret))
    assertEquals(party.fromBoolean[2], 1)
    assertEquals(party.fromBoolean[3], 0.4)
    ns.UnitButton.alphaFromBooleanWorks = false
    party.fromBoolean = nil
    ns.UnitButton:UpdateRange(party)
    assertNil(party.fromBoolean)
    assertEquals(party.alpha, 1)
  end)

  it("probes SetAlphaFromBoolean on a scratch frame", function()
    local ns, environment = LoadUnitButton()
    assertFalse(ns.UnitButton:ProbeAlphaFromBoolean())
    local baseCreateFrame = environment.CreateFrame
    environment.CreateFrame = function(...)
      local frame = baseCreateFrame(...)
      function frame:SetAlphaFromBoolean(value, whenTrue, whenFalse)
        self.alpha = value and whenTrue or whenFalse
      end
      return frame
    end
    assertTrue(ns.UnitButton:ProbeAlphaFromBoolean())
  end)
end)

describe("UnitButton threat", function()
  it("shows the aggro border for readable high threat and hides it otherwise", function()
    local ns, _, world = LoadUnitButton()
    local party = FakeButton("party1")
    world.threat = 3
    ns.UnitButton:UpdateThreat(party)
    assertTrue(party.healsilus.aggroFrame.shown)
    world.threat = 1
    ns.UnitButton:UpdateThreat(party)
    assertFalse(party.healsilus.aggroFrame.shown)
    world.threat = nil
    ns.UnitButton:UpdateThreat(party)
    assertFalse(party.healsilus.aggroFrame.shown)
    world.threat = Stubs.MakeSecret()
    party.healsilus.aggroFrame:Show()
    ns.UnitButton:UpdateThreat(party)
    assertFalse(party.healsilus.aggroFrame.shown)
  end)

  it("shows one red dot per threat level, like HealBot", function()
    local ns, _, world = LoadUnitButton()
    local party = FakeButton("party1")
    for level = 0, 3 do
      world.threat = level
      ns.UnitButton:UpdateThreat(party)
      assertEquals(ShownDots(party), level)
    end
    world.threat = Stubs.MakeSecret()
    ns.UnitButton:UpdateThreat(party)
    assertEquals(ShownDots(party), 0)
  end)

  it("lets the style turn the border and the dots off separately", function()
    local ns, _, world = LoadUnitButton()
    local party = FakeButton("party1")
    world.threat = 3
    ns.Styles.active.aggro.dots = false
    ns.UnitButton:UpdateThreat(party)
    assertTrue(party.healsilus.aggroFrame.shown)
    assertEquals(ShownDots(party), 0)
    ns.Styles.active.aggro.dots = true
    ns.Styles.active.aggro.border = false
    ns.UnitButton:UpdateThreat(party)
    assertFalse(party.healsilus.aggroFrame.shown)
    assertEquals(ShownDots(party), 3)
  end)
end)

describe("UnitButton role icon", function()
  it("shows the role the player picked only when the style asks for it", function()
    local ns, environment = LoadUnitButton()
    local role = "TANK"
    environment.UnitGroupRolesAssigned = function()
      return role
    end
    local party = FakeButton("party1")
    ns.UnitButton:UpdateRole(party)
    assertFalse(party.healsilus.roleIcon.shown)
    ns.Styles.active.role.show = true
    ns.UnitButton:UpdateRole(party)
    assertTrue(party.healsilus.roleIcon.shown)
    assertEquals(party.healsilus.roleIcon.atlas, "UI-LFG-RoleIcon-Tank-Micro-GroupFinder")
    role = "HEALER"
    ns.UnitButton:UpdateRole(party)
    assertEquals(party.healsilus.roleIcon.atlas, "UI-LFG-RoleIcon-Healer-Micro-GroupFinder")
    role = "DAMAGER"
    ns.UnitButton:UpdateRole(party)
    assertTrue(party.healsilus.roleIcon.shown)
    ns.Styles.active.role.showDamager = false
    ns.UnitButton:UpdateRole(party)
    assertFalse(party.healsilus.roleIcon.shown)
    role = "NONE"
    ns.Styles.active.role.showDamager = true
    ns.UnitButton:UpdateRole(party)
    assertFalse(party.healsilus.roleIcon.shown)
    role = Stubs.MakeSecret()
    ns.UnitButton:UpdateRole(party)
    assertFalse(party.healsilus.roleIcon.shown)
  end)
end)

describe("UnitButton health text", function()
  it("shows nothing, a deficit or nothing at full health", function()
    local ns, _, world = LoadUnitButton()
    local party = FakeButton("party1")
    ns.UnitButton:UpdateHealthText(party)
    assertEquals(party.healsilus.healthText.text, "")
    world.missing = 2500
    ns.UnitButton:UpdateHealthText(party)
    assertEquals(party.healsilus.healthText.text, "-2500")
    ns.Styles.active.text.health.mode = "NONE"
    ns.UnitButton:UpdateHealthText(party)
    assertEquals(party.healsilus.healthText.text, "")
  end)

  it("switches a button to percent when the deficit cannot be abbreviated", function()
    local ns, environment, world = LoadUnitButton()
    InstallCurves(environment)
    world.missing = Stubs.MakeSecret()
    local party = FakeButton("party1")
    ns.UnitButton:UpdateHealthText(party)
    assertEquals(party.healsilus.healthText.text, "75%")
    assertEquals(party.healsilusTextMode, "PERCENT")
    assertEquals(ns.Diagnostics.errors[1].context, "UnitButton:DeficitText")
  end)

  it("shows current health, current over maximum and current with percent", function()
    local ns, environment = LoadUnitButton()
    InstallCurves(environment)
    environment.UnitHealth = function()
      return 7500
    end
    environment.UnitHealthMax = function()
      return 10000
    end
    local party = FakeButton("party1")
    ns.Styles.active.text.health.mode = "CURRENT"
    ns.UnitButton:UpdateHealthText(party)
    assertEquals(party.healsilus.healthText.text, "7500")
    ns.Styles.active.text.health.mode = "CURRENT_MAX"
    ns.UnitButton:UpdateHealthText(party)
    assertEquals(party.healsilus.healthText.text, "7500 / 10000")
    ns.Styles.active.text.health.mode = "CURRENT_PERCENT"
    ns.UnitButton:UpdateHealthText(party)
    assertEquals(party.healsilus.healthText.text, "7500 · 75%")
  end)

  it("drops the percent part when curves are unavailable", function()
    local ns, environment = LoadUnitButton()
    environment.UnitHealth = function()
      return 7500
    end
    ns.Styles.active.text.health.mode = "CURRENT_PERCENT"
    local party = FakeButton("party1")
    ns.UnitButton:UpdateHealthText(party)
    assertEquals(party.healsilus.healthText.text, "7500")
  end)

  it("switches a button to percent when the health number cannot be abbreviated", function()
    local ns, environment = LoadUnitButton()
    InstallCurves(environment)
    environment.UnitHealth = function()
      return Stubs.MakeSecret()
    end
    ns.Styles.active.text.health.mode = "CURRENT_MAX"
    local party = FakeButton("party1")
    ns.UnitButton:UpdateHealthText(party)
    assertEquals(party.healsilus.healthText.text, "75%")
    assertEquals(party.healsilusTextMode, "PERCENT")
    assertEquals(ns.Diagnostics.errors[1].context, "UnitButton:HealthNumberText")
  end)

  it("lets the client hide a secret deficit at full health with a color curve", function()
    local ns, environment, world = LoadUnitButton()
    InstallCurves(environment)
    -- La curva de visibilidad devuelve un color con el alfa que tocaría a esa vida (aquí, llena).
    environment.UnitHealthPercent = function(_, usePredicted, curve)
      if curve == ns.Curves.deficitVisibility then
        assertEquals(usePredicted, false)
        return { GetRGBA = function()
          return 1, 1, 1, 0
        end }
      end
      return 100
    end
    environment.AbbreviateLargeNumbers = function()
      return "0"
    end
    world.missing = Stubs.MakeSecret()
    local party = FakeButton("party1")
    ns.UnitButton:UpdateHealthText(party)
    assertEquals(party.healsilus.healthText.text, "-0")
    assertEquals(party.healsilus.healthText.textColor, { 1, 1, 1, 0 })
    ns.Styles.active.text.health.mode = "PERCENT"
    ns.UnitButton:UpdateHealthText(party)
    assertEquals(party.healsilus.healthText.textColor, { 1, 1, 1, 1 })
  end)

  it("records once and keeps the text visible if the client refuses the fade", function()
    local ns, environment, world = LoadUnitButton()
    InstallCurves(environment)
    environment.AbbreviateLargeNumbers = function()
      return "0"
    end
    world.missing = Stubs.MakeSecret()
    local party = FakeButton("party1")
    ns.UnitButton:UpdateHealthText(party)
    ns.UnitButton:UpdateHealthText(party)
    assertEquals(party.healsilus.healthText.textColor, { 1, 1, 1, 1 })
    assertEquals(#ns.Diagnostics.errors, 1)
    assertEquals(ns.Diagnostics.errors[1].context, "UnitButton:DeficitFade")
  end)

  it("hides percent text when curves are unavailable", function()
    local ns = LoadUnitButton()
    ns.Styles.active.text.health.mode = "PERCENT"
    local party = FakeButton("party1")
    ns.UnitButton:UpdateHealthText(party)
    assertEquals(party.healsilus.healthText.text, "")
  end)
end)

describe("UnitButton color", function()
  local function ColoredButton(unit)
    local texture = {}
    function texture:SetVertexColor(red, green, blue)
      self.color = { red, green, blue }
    end
    local button = { unit = unit, healsilus = { healthBar = {} } }
    function button.healsilus.healthBar:GetStatusBarTexture()
      return texture
    end
    return button, texture
  end

  it("paints the bar with the missing-buff color only out of combat", function()
    local ns, environment = LoadUnitButton()
    environment.UnitClass = function()
      return "Warrior", "WARRIOR"
    end
    local button, texture = ColoredButton("party1")
    button.healsilusMissing = { "Espinas" }
    ns.UnitButton:UpdateColor(button)
    assertEquals(texture.color, { 0.94, 0.62, 0.15 })
    environment.__fireEvent("PLAYER_REGEN_DISABLED")
    ns.UnitButton:UpdateColor(button)
    assertEquals(texture.color, { 0.3, 0.7, 0.3 })
    environment.__fireEvent("PLAYER_REGEN_ENABLED")
    ns.Profiles.active.buffs.colorBar = false
    ns.UnitButton:UpdateColor(button)
    assertEquals(texture.color, { 0.3, 0.7, 0.3 })
  end)
end)

describe("UnitButton status", function()
  it("labels offline and dead units and stays quiet with secret flags", function()
    local ns, _, world = LoadUnitButton()
    local party = FakeButton("party1")
    world.connected = false
    ns.UnitButton:UpdateStatus(party)
    assertEquals(party.healsilus.statusText.text, "Offline")
    assertEquals(party.healsilusState, "OFFLINE")
    world.connected = true
    world.dead = true
    ns.UnitButton:UpdateStatus(party)
    assertEquals(party.healsilus.statusText.text, "Dead")
    world.dead = Stubs.MakeSecret()
    ns.UnitButton:UpdateStatus(party)
    assertEquals(party.healsilus.statusText.text, "")
    assertNil(party.healsilusState)
  end)
end)

describe("UnitButton power bar", function()
  local function FakeBar()
    local bar = FakeRegion()
    bar.texture = {}
    function bar.texture:SetVertexColor(red, green, blue)
      self.color = { red, green, blue }
    end
    function bar:GetStatusBarTexture()
      return self.texture
    end
    function bar:SetMinMaxValues(minimum, maximum)
      self.range = { minimum, maximum }
    end
    function bar:SetValue(value)
      self.value = value
    end
    function bar:SetHeight(height)
      self.height = height
    end
    function bar:ClearAllPoints()
      self.points = {}
    end
    function bar:SetPoint(point, relativeTo, relativePoint, x, y)
      self.points[point] = { x, y }
    end
    return bar
  end

  local function PowerButton(unit)
    local button = FakeButton(unit)
    local visual = button.healsilus
    visual.owner = button
    visual.healthBar, visual.powerBar = FakeBar(), FakeBar()
    visual.powerBackground = {}
    function visual.powerBackground:SetColorTexture(red, green, blue, alpha)
      self.color = { red, green, blue, alpha }
    end
    function visual.powerBackground:SetVertexColor(red, green, blue, alpha)
      self.vertex = { red, green, blue, alpha }
    end
    return button
  end

  local function LoadPower()
    local ns, environment, world = LoadUnitButton()
    world.powerToken, world.power, world.powerMax, world.role = "RAGE", 40, 100, "DAMAGER"
    environment.UnitPowerType = function()
      return 1, world.powerToken
    end
    environment.UnitPower = function()
      return world.power
    end
    environment.UnitPowerMax = function()
      return world.powerMax
    end
    environment.UnitGroupRolesAssigned = function()
      return world.role
    end
    return ns, environment, world
  end

  it("shows the unit's resource in its color below a shorter health bar", function()
    local ns = LoadPower()
    local party = PowerButton("party1")
    ns.UnitButton:UpdatePower(party)
    local visual = party.healsilus
    assertTrue(visual.powerBar.shown)
    assertEquals(visual.powerBar.range, { 0, 100 })
    assertEquals(visual.powerBar.value, 40)
    assertEquals(visual.powerBar.height, 4)
    assertEquals(visual.powerBar.texture.color, { 1, 0, 0 })
    assertEquals(visual.powerBackground.color, { 1, 0, 0, 0.25 })
    -- La barra de vida acaba 2 + 4 + 1 px por encima del borde de abajo.
    assertEquals(visual.healthBar.points.BOTTOMRIGHT, { -2, 7 })
    assertEquals(visual.healthBar.points.TOPLEFT, { 2, -2 })
  end)

  it("hands secret values straight to the bar and uses the mana color for a secret type", function()
    local ns, _, world = LoadPower()
    local party = PowerButton("party1")
    world.power, world.powerMax, world.powerToken = Stubs.MakeSecret(), Stubs.MakeSecret(), Stubs.MakeSecret()
    ns.UnitButton:UpdatePower(party)
    local visual = party.healsilus
    assertTrue(Stubs.IsSecret(visual.powerBar.value))
    assertTrue(Stubs.IsSecret(visual.powerBar.range[2]))
    assertEquals(visual.powerBar.texture.color, { 0, 0, 1 })
  end)

  it("keeps the bar to healers when the style asks and gives the room back otherwise", function()
    local ns, _, world = LoadPower()
    local party = PowerButton("party1")
    ns.Styles.active.power.healersOnly = true
    ns.UnitButton:UpdatePower(party)
    local visual = party.healsilus
    assertFalse(visual.powerBar.shown)
    assertEquals(visual.healthBar.points.BOTTOMRIGHT, { -2, 2 })
    world.role = "HEALER"
    ns.UnitButton:UpdatePower(party)
    assertTrue(visual.powerBar.shown)
    world.role = Stubs.MakeSecret()
    ns.UnitButton:UpdatePower(party)
    assertFalse(visual.powerBar.shown)
    ns.Styles.active.power.healersOnly = false
    ns.Styles.active.power.show = false
    world.role = "HEALER"
    ns.UnitButton:UpdatePower(party)
    assertFalse(visual.powerBar.shown)
    visual.powerBar.value = nil
    ns.UnitButton:OnUnitEvent(party, "UNIT_POWER_UPDATE")
    assertNil(visual.powerBar.value)
  end)

  it("follows power changes and a druid changing form", function()
    local ns, _, world = LoadPower()
    local party = PowerButton("party1")
    world.powerToken = "MANA"
    ns.UnitButton:UpdatePower(party)
    world.power = 75
    ns.UnitButton:OnUnitEvent(party, "UNIT_POWER_UPDATE")
    assertEquals(party.healsilus.powerBar.value, 75)
    world.powerToken, world.power = "ENERGY", 100
    ns.UnitButton:OnUnitEvent(party, "UNIT_DISPLAYPOWER")
    assertEquals(party.healsilus.powerBar.texture.color, { 1, 1, 0 })
    assertEquals(party.healsilus.powerBar.value, 100)
  end)

  it("hides the bar for the resource types the style turns off, also when a druid changes form", function()
    local ns, _, world = LoadPower()
    local party = PowerButton("party1")
    local types = ns.Styles.active.power.types
    types.RAGE = false
    ns.UnitButton:UpdatePower(party)
    assertFalse(party.healsilus.powerBar.shown)
    assertEquals(party.healsilus.healthBar.points.BOTTOMRIGHT, { -2, 2 })
    world.powerToken = "MANA"
    ns.UnitButton:OnUnitEvent(party, "UNIT_DISPLAYPOWER")
    assertTrue(party.healsilus.powerBar.shown)
    -- Tipos sin casilla propia siguen a "Otros"; un tipo secreto cuenta como maná.
    world.powerToken = "LUNAR_POWER"
    types.OTHER = false
    ns.UnitButton:OnUnitEvent(party, "UNIT_DISPLAYPOWER")
    assertFalse(party.healsilus.powerBar.shown)
    assertTrue(ns.UnitButton.WantsPowerType(ns.Styles.active, nil))
    types.MANA = false
    assertFalse(ns.UnitButton.WantsPowerType(ns.Styles.active, nil))
  end)

  it("lets a thicker bar push the health bar further up", function()
    local ns = LoadPower()
    local party = PowerButton("party1")
    ns.Styles.active.power.thickness = 8
    ns.UnitButton:UpdatePower(party)
    assertEquals(party.healsilus.powerBar.height, 8)
    assertEquals(party.healsilus.healthBar.points.BOTTOMRIGHT, { -2, 11 })
  end)
end)

describe("UnitButton opacity at full health", function()
  local function Colored()
    local region = {}
    function region:SetVertexColor(red, green, blue, alpha)
      self.vertex = { red, green, blue, alpha }
    end
    function region:SetTextColor(red, green, blue, alpha)
      self.text = { red, green, blue, alpha }
    end
    function region:SetColorTexture(red, green, blue, alpha)
      self.color = { red, green, blue, alpha }
    end
    return region
  end

  local function Bar()
    local fill = Colored()
    return { fill = fill, GetStatusBarTexture = function()
      return fill
    end }
  end

  local function FadeButton(unit)
    local button = { unit = unit, healsilus = {
      background = Colored(), nameText = Colored(), healthText = Colored(), healthBar = Bar(), powerBar = Bar(),
      powerBackground = Colored(),
    } }
    return button
  end

  local function LoadFade(health, maximum)
    local ns, environment = LoadUnitButton()
    environment.UnitHealth = function()
      return health()
    end
    environment.UnitHealthMax = function()
      return maximum()
    end
    return ns, environment
  end

  it("fades the bar, background, power and texts of a unit at full health only", function()
    local current = 100
    local ns = LoadFade(function()
      return current
    end, function()
      return 100
    end)
    ns.Styles.active.bar.fullHealthAlpha = 0.3
    local button = FadeButton("party1")
    ns.UnitButton.PaintFill(button.healsilus, 1, 0.5, 0)
    ns.UnitButton.PaintPower(button.healsilus, "MANA")
    ns.UnitButton:UpdateFade(button)
    local visual = button.healsilus
    assertEquals(visual.healthBar.fill.vertex, { 1, 0.5, 0, 0.3 })
    assertEquals(visual.background.vertex, { 1, 1, 1, 0.3 })
    assertEquals(visual.nameText.text, { 1, 1, 1, 0.3 })
    assertEquals(visual.powerBar.fill.vertex[4], 0.3)
    current = 99
    ns.UnitButton:UpdateFade(button)
    assertEquals(visual.healthBar.fill.vertex, { 1, 0.5, 0, 1 })
    assertEquals(visual.background.vertex, { 1, 1, 1, 1 })
  end)

  it("keeps dead and offline units and the default style fully opaque", function()
    local ns = LoadFade(function()
      return 100
    end, function()
      return 100
    end)
    local button = FadeButton("party1")
    ns.UnitButton:UpdateFade(button)
    assertEquals(button.healsilus.background.vertex, { 1, 1, 1, 1 })
    ns.Styles.active.bar.fullHealthAlpha = 0.3
    button.healsilusState = "DEAD"
    ns.UnitButton:UpdateFade(button)
    assertEquals(button.healsilus.background.vertex, { 1, 1, 1, 1 })
  end)

  it("lets the client decide with a curve when health is secret, and gives up cleanly if it refuses", function()
    local ns, environment = LoadFade(Stubs.MakeSecret, Stubs.MakeSecret)
    ns.Styles.active.bar.fullHealthAlpha = 0.3
    local secretAlpha = Stubs.MakeSecret()
    environment.C_CurveUtil = { CreateColorCurve = function()
      return { SetType = function() end, AddPoint = function() end }
    end, CreateCurve = function() end }
    environment.Enum = { LuaCurveType = { Linear = 0 } }
    environment.CreateColor = function()
      return {}
    end
    environment.UnitHealthPercent = function(_, predicted, curve)
      assertFalse(predicted)
      assertTrue(curve ~= nil)
      return { GetRGBA = function()
        return 1, 1, 1, secretAlpha
      end }
    end
    local button = FadeButton("party1")
    ns.UnitButton:UpdateFade(button)
    assertTrue(button.healsilus.background.vertex[4] == secretAlpha)
    -- Un cliente que no acepta el alfa secreto: se anota y las barras quedan opacas.
    button.healsilus.background.SetVertexColor = function(self, red, green, blue, alpha)
      if Stubs.IsSecret(alpha) then
        error("secret alpha refused")
      end
      self.vertex = { red, green, blue, alpha }
    end
    ns.UnitButton:UpdateFade(button)
    assertTrue(ns.UnitButton.fadeFailed)
    assertEquals(button.healsilus.background.vertex, { 1, 1, 1, 1 })
  end)
end)

describe("UnitButton aggro border blink", function()
  it("blinks the aggro border only when the style asks and the unit has aggro", function()
    local ns = LoadUnitButton()
    local button = FakeButton("party1")
    local pulse = { playing = false }
    function pulse:IsPlaying()
      return self.playing
    end
    function pulse:Play()
      self.playing = true
    end
    function pulse:Stop()
      self.playing = false
    end
    local frame = button.healsilus.aggroFrame
    frame.pulse = pulse
    function frame:SetAlpha(alpha)
      self.alpha = alpha
    end
    local style = ns.Styles.active
    ns.UnitButton.ShowThreat(button.healsilus, 3, style)
    assertFalse(pulse.playing)
    style.aggro.blink = true
    ns.UnitButton.ShowThreat(button.healsilus, 3, style)
    assertTrue(pulse.playing)
    ns.UnitButton.ShowThreat(button.healsilus, 1, style)
    assertFalse(pulse.playing)
    assertEquals(frame.alpha, 1)
  end)
end)
