local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertFalse, assertNil = Harness.assertEquals, Harness.assertTrue, Harness.assertFalse, Harness.assertNil

local FILES = {
  "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/CombatQueue.lua", "Core/Database.lua", "Core/StyleData.lua",
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
      local aura = units[unit].auras[name]
      if not aura then
        return nil
      end
      return { name = name, expirationTime = type(aura) == "number" and aura or 0 }
    end,
  }
  environment.GetTime = function()
    return 1000
  end
  environment.UnitIsUnit = function(unit, other)
    return unit == other
  end
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
  it("checks each buff only on the targets chosen for it", function()
    local ns = LoadMissingBuffs()
    local watched = {
      { label = "Marca", names = { "Marca", "Don" }, targets = "ALL" },
      { label = "Espinas", names = { "Espinas" }, targets = "TANKS" },
      { label = "Espiritu", names = { "Espiritu" }, targets = "HEALERS" },
      { label = "Armadura", names = { "Armadura" }, targets = "SELF" },
    }
    local function Nothing()
      return false
    end
    assertEquals(ns.MissingBuffs.Compute(watched, Nothing, { tank = true }), { "Marca", "Espinas" })
    assertEquals(ns.MissingBuffs.Compute(watched, Nothing, {}), { "Marca" })
    assertEquals(ns.MissingBuffs.Compute(watched, Nothing, { healer = true }), { "Marca", "Espiritu" })
    assertEquals(ns.MissingBuffs.Compute(watched, Nothing, { self = true }), { "Marca", "Armadura" })
    local function HasGift(name)
      return name == "Don"
    end
    assertEquals(ns.MissingBuffs.Compute(watched, HasGift, {}), {})
  end)

  it("builds the macro that casts the first missing buff on the bar under the mouse", function()
    local ns = LoadMissingBuffs()
    assertEquals(ns.MissingBuffs.BuffMacro({ "Marca de lo Salvaje", "Espinas" }), "/cast [@mouseover] Marca de lo Salvaje")
    assertEquals(ns.MissingBuffs.BuffMacro({}), "")
    assertEquals(ns.MissingBuffs.BuffMacro(nil), "")
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

  it("freezes the last result in combat and while auras are secret", function()
    local ns, environment, units = LoadMissingBuffs()
    local tank = FakeButton("party1")
    ns.MissingBuffs:Evaluate(tank)
    units.party1.auras = { ["Marca de lo Salvaje"] = true, ["Espinas"] = true }
    environment.__state.inCombat = true
    ns.MissingBuffs:Evaluate(tank)
    assertEquals(tank.healsilusMissing, { "Marca de lo Salvaje", "Espinas" })
    environment.__state.inCombat = false
    local aurasSecret = true
    environment.C_Secrets = {
      ShouldAurasBeSecret = function()
        return aurasSecret
      end,
    }
    ns.MissingBuffs:Evaluate(tank)
    assertEquals(tank.healsilusMissing, { "Marca de lo Salvaje", "Espinas" })
    aurasSecret = false
    ns.MissingBuffs:Evaluate(tank)
    assertEquals(tank.healsilusMissing, {})
  end)

  -- WoW Forever es una versión con restricciones (HasSecretRestrictions siempre true), pero fuera de
  -- combate las auras se leen: eso no debe apagar el aviso de buffs.
  it("still reads auras on a client build that has secret restrictions", function()
    local ns, environment = LoadMissingBuffs()
    environment.C_Secrets = {
      HasSecretRestrictions = function()
        return true
      end,
      ShouldAurasBeSecret = function()
        return false
      end,
    }
    local tank = FakeButton("party1")
    assertTrue(ns.MissingBuffs.CanRead())
    ns.MissingBuffs:Evaluate(tank)
    assertEquals(tank.healsilusMissing, { "Marca de lo Salvaje", "Espinas" })
  end)

  it("keeps the last result when the client returns a secret aura", function()
    local ns, environment, units = LoadMissingBuffs()
    local tank = FakeButton("party1")
    ns.MissingBuffs:Evaluate(tank)
    units.party1.auras = { ["Marca de lo Salvaje"] = true, ["Espinas"] = true }
    environment.C_UnitAuras.GetAuraDataBySpellName = function()
      return Stubs.MakeSecret()
    end
    ns.MissingBuffs:Evaluate(tank)
    assertEquals(tank.healsilusMissing, { "Marca de lo Salvaje", "Espinas" })
  end)

  it("never compares secret roles or unit checks", function()
    local ns, environment = LoadMissingBuffs()
    environment.UnitGroupRolesAssigned = function()
      return Stubs.MakeSecret()
    end
    environment.UnitIsUnit = function()
      return Stubs.MakeSecret()
    end
    local tank = FakeButton("party1")
    ns.MissingBuffs:Evaluate(tank)
    assertEquals(tank.healsilusMissing, { "Marca de lo Salvaje" })
  end)

  it("treats a buff with a secret expiration time as present", function()
    local ns, environment = LoadMissingBuffs()
    ns.Profiles.active.buffs.refreshBelow = 5
    environment.C_UnitAuras.GetAuraDataBySpellName = function(_, name)
      if name == "Marca de lo Salvaje" then
        return { name = name, expirationTime = Stubs.MakeSecret() }
      end
      return nil
    end
    local damager = FakeButton("party2")
    ns.MissingBuffs:Evaluate(damager)
    assertEquals(damager.healsilusMissing, {})
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

  it("also warns when a buff has less time left than the chosen minutes", function()
    local ns, _, units = LoadMissingBuffs()
    units.party2.auras = { ["Marca de lo Salvaje"] = 1000 + 120 }
    local damager = FakeButton("party2")
    ns.MissingBuffs:Evaluate(damager)
    assertEquals(damager.healsilusMissing, {})
    ns.Profiles.active.buffs.refreshBelow = 5
    ns.MissingBuffs:Evaluate(damager)
    assertEquals(damager.healsilusMissing, { "Marca de lo Salvaje" })
    units.party2.auras = { ["Marca de lo Salvaje"] = 1000 + 600 }
    ns.MissingBuffs:Evaluate(damager)
    assertEquals(damager.healsilusMissing, {})
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
