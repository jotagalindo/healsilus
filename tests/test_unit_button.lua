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
  return region
end

local function FakeButton(unit)
  local button = {
    unit = unit,
    healsilus = { healthText = FakeRegion(), statusText = FakeRegion(), aggroFrame = FakeRegion() },
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

  it("hides percent text when curves are unavailable", function()
    local ns = LoadUnitButton()
    ns.Styles.active.text.health.mode = "PERCENT"
    local party = FakeButton("party1")
    ns.UnitButton:UpdateHealthText(party)
    assertEquals(party.healsilus.healthText.text, "")
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
