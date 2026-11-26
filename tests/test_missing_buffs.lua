local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertFalse, assertNil = Harness.assertEquals, Harness.assertTrue, Harness.assertFalse, Harness.assertNil

local FILES = {
  "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/CombatQueue.lua", "Core/Database.lua",
  "Data/Spells.lua", "Data/Druid.lua", "Auras/MissingBuffs.lua",
}

local SPELLS = {
  [1126] = { name = "Marca de lo Salvaje" },
  [21849] = { name = "Don de lo Salvaje" },
  [467] = { name = "Espinas" },
}

local function LoadMissingBuffs()
  local environment = Stubs.NewEnvironment({ spells = SPELLS })
  local units = {
    party1 = { role = "TANK", auras = {} },
    party2 = { role = "DAMAGER", auras = { ["Don de lo Salvaje"] = true } },
  }
  environment.UnitExists = function(unit)
    return units[unit] ~= nil
  end
  environment.UnitIsConnected = function()
    return true
  end
  environment.UnitIsDeadOrGhost = function(unit)
    return units[unit].dead == true
  end
  environment.UnitGroupRolesAssigned = function(unit)
    return units[unit].role
  end
  environment.C_UnitAuras = {
    GetAuraDataBySpellName = function(unit, name)
      return units[unit].auras[name] and { name = name } or nil
    end,
  }
  local ns = Loader.Load(environment, FILES)
  ns.Profiles = { active = ns.Database.NormalizeProfile(ns.ClassDefaults.DRUID(), {}) }
  ns.UnitButton = { buttons = {} }
  ns.MissingBuffs:Resolve()
  return ns, environment, units
end

local function FakeButton(unit)
  local mark = { shown = false }
  function mark:SetShown(shown)
    self.shown = shown
  end
  return { unit = unit, healsilus = { missingMark = mark } }
end

describe("MissingBuffs.Compute", function()
  it("checks everyone for ALL entries and only tanks for TANKS entries", function()
    local ns = LoadMissingBuffs()
    local watched = {
      { label = "Marca", names = { "Marca", "Don" }, targets = "ALL" },
      { label = "Espinas", names = { "Espinas" }, targets = "TANKS" },
    }
    local function Nothing()
      return false
    end
    assertEquals(ns.MissingBuffs.Compute(watched, Nothing, true), { "Marca", "Espinas" })
    assertEquals(ns.MissingBuffs.Compute(watched, Nothing, false), { "Marca" })
    local function HasGift(name)
      return name == "Don"
    end
    assertEquals(ns.MissingBuffs.Compute(watched, HasGift, false), {})
  end)
end)

describe("MissingBuffs", function()
  it("resolves watched spells to localized names, including the group version", function()
    local ns = LoadMissingBuffs()
    assertEquals(ns.MissingBuffs.resolved, {
      { label = "Marca de lo Salvaje", names = { "Marca de lo Salvaje", "Don de lo Salvaje" }, targets = "ALL" },
      { label = "Espinas", names = { "Espinas" }, targets = "TANKS" },
    })
  end)

  it("drops watched spells the client does not know", function()
    local ns = LoadMissingBuffs()
    ns.Profiles.active.buffs.watched = { { spellID = 424242, targets = "ALL" } }
    assertEquals(ns.MissingBuffs:Resolve(), {})
  end)

  it("marks a tank missing Mark and Thorns, and accepts the group buff for others", function()
    local ns = LoadMissingBuffs()
    local tank, damager = FakeButton("party1"), FakeButton("party2")
    ns.MissingBuffs:Evaluate(tank)
    ns.MissingBuffs:Evaluate(damager)
    assertEquals(tank.healsilusMissing, { "Marca de lo Salvaje", "Espinas" })
    assertTrue(tank.healsilus.missingMark.shown)
    assertEquals(damager.healsilusMissing, {})
    assertFalse(damager.healsilus.missingMark.shown)
  end)

  it("freezes the last result in combat and under secret restrictions", function()
    local ns, environment, units = LoadMissingBuffs()
    local tank = FakeButton("party1")
    ns.MissingBuffs:Evaluate(tank)
    units.party1.auras = { ["Marca de lo Salvaje"] = true, ["Espinas"] = true }
    environment.__state.inCombat = true
    ns.MissingBuffs:Evaluate(tank)
    assertEquals(tank.healsilusMissing, { "Marca de lo Salvaje", "Espinas" })
    environment.__state.inCombat = false
    environment.C_Secrets = {
      HasSecretRestrictions = function()
        return true
      end,
    }
    ns.MissingBuffs:Evaluate(tank)
    assertEquals(tank.healsilusMissing, { "Marca de lo Salvaje", "Espinas" })
    environment.C_Secrets = nil
    ns.MissingBuffs:Evaluate(tank)
    assertEquals(tank.healsilusMissing, {})
  end)

  it("clears the mark for dead units and when the feature is off", function()
    local ns, _, units = LoadMissingBuffs()
    local tank = FakeButton("party1")
    ns.MissingBuffs:Evaluate(tank)
    units.party1.dead = true
    ns.MissingBuffs:Evaluate(tank)
    assertNil(tank.healsilusMissing)
    assertFalse(tank.healsilus.missingMark.shown)
    units.party1.dead = false
    ns.Profiles.active.buffs.enabled = false
    ns.MissingBuffs:Resolve()
    ns.MissingBuffs:Evaluate(tank)
    assertNil(tank.healsilusMissing)
  end)

  it("groups aura changes into one delayed evaluation", function()
    local ns, environment = LoadMissingBuffs()
    local tank = FakeButton("party1")
    ns.MissingBuffs:MarkDirty(tank)
    ns.MissingBuffs:MarkDirty(tank)
    assertEquals(#environment.__state.timers, 1)
    assertNil(tank.healsilusMissing)
    environment.__runTimers()
    assertEquals(tank.healsilusMissing, { "Marca de lo Salvaje", "Espinas" })
  end)
end)
