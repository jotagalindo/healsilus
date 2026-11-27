local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertFalse, assertNil = Harness.assertEquals, Harness.assertTrue, Harness.assertFalse, Harness.assertNil

local FILES = {
  "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/CombatQueue.lua", "Core/Database.lua",
  "Core/StyleData.lua", "Data/Spells.lua", "Data/Druid.lua", "Data/Dispels.lua", "Frames/ClickCast.lua",
  "Auras/MissingBuffs.lua", "Auras/DispelOverride.lua",
}

local function LoadOverride()
  local environment = Stubs.NewEnvironment({
    spells = {
      [5185] = { name = "Toque de sanación" },
      [2782] = { name = "Quitar maldición" },
      [2893] = { name = "Suprimir veneno" },
      [8946] = { name = "Curar envenenamiento" },
      [774] = { name = "Rejuvenecimiento" },
      [1126] = { name = "Marca de lo Salvaje" },
      [21849] = { name = "Don de lo Salvaje" },
    },
    spellbook = {
      { spellID = 5185, name = "Toque de sanación", subName = "" },
      { spellID = 2782, name = "Quitar maldición", subName = "" },
      { spellID = 8946, name = "Curar envenenamiento", subName = "" },
    },
  })
  local debuffs = { party1 = {} }
  local buffs = { party1 = {} }
  environment.C_UnitAuras = {
    GetAuraDataByIndex = function(unit, position)
      local dispelName = debuffs[unit] and debuffs[unit][position]
      return dispelName and { dispelName = dispelName } or nil
    end,
    GetAuraDataBySpellName = function(unit, name)
      return buffs[unit] and buffs[unit][name] and { name = name, expirationTime = 0 } or nil
    end,
  }
  environment.UnitExists = function()
    return true
  end
  environment.UnitIsConnected = function()
    return true
  end
  environment.UnitIsDeadOrGhost = function()
    return false
  end
  environment.UnitGroupRolesAssigned = function()
    return "DAMAGER"
  end
  environment.UnitIsUnit = function(unit, other)
    return unit == other
  end
  local ns = Loader.Load(environment, FILES)
  ns.Spells:Scan()
  ns.Profiles = { active = ns.Database.NormalizeProfile(ns.ClassDefaults.DRUID(), {}) }
  -- El clic de buff viene activado de serie; cada prueba lo enciende cuando lo necesita.
  ns.Profiles.active.clicks.buffOverride = false
  ns.UnitButton = { buttons = {} }
  ns.Headers = { list = {} }
  -- Solo vigila Marca de lo Salvaje (con Don de lo Salvaje como versión de grupo) para todos.
  ns.Profiles.active.buffs.watched = { { spellID = 1126, groupSpellID = 21849, targets = "ALL" } }
  ns.MissingBuffs:Resolve()
  return ns, environment, debuffs, buffs
end

local function FakeSecureButton(unit)
  local mark = { shown = false }
  function mark:SetShown(shown)
    self.shown = shown
  end
  local button = { unit = unit, attributes = {}, healsilus = { missingMark = mark } }
  function button:SetAttribute(name, value)
    self.attributes[name] = value
  end
  function button:GetAttribute(name)
    return self.attributes[name]
  end
  return button
end

describe("DispelOverride.CureFor", function()
  it("uses the spell assigned to the type, or the first known cure", function()
    local ns = LoadOverride()
    local bindings = ns.Profiles.active.bindings
    assertEquals(ns.DispelOverride.CureFor({ Curse = true }, bindings), "Quitar maldición")
    -- Veneno: el clic asignado es Suprimir veneno (no aprendido) con Curar envenenamiento de reserva.
    assertEquals(ns.DispelOverride.CureFor({ Poison = true }, bindings), "Curar envenenamiento")
    bindings["shift-2"] = nil
    assertEquals(ns.DispelOverride.CureFor({ Curse = true }, bindings), "Quitar maldición")
    assertNil(ns.DispelOverride.CureFor({ Magic = true }, bindings))
    assertNil(ns.DispelOverride.CureFor({}, bindings))
  end)
end)

describe("ClickCast dispel override", function()
  it("makes every click cast the cure and restores the normal clicks afterwards", function()
    local ns = LoadOverride()
    local button = FakeSecureButton("party1")
    ns.UnitButton.buttons[button] = true
    ns.ClickCast:Apply(ns.Profiles.active)
    assertEquals(button.attributes.spell1, "Toque de sanación")
    assertTrue(ns.ClickCast:SetDispelOverride(button, "Quitar maldición"))
    for _, prefix in ipairs(ns.BINDING_PREFIXES) do
      for _, mouseButton in ipairs(ns.MOUSE_BUTTONS) do
        assertEquals(button.attributes[prefix .. "type" .. mouseButton], "spell")
        assertEquals(button.attributes[prefix .. "spell" .. mouseButton], "Quitar maldición")
      end
    end
    assertTrue(ns.ClickCast:SetDispelOverride(button, nil))
    assertEquals(button.attributes.spell1, "Toque de sanación")
    assertEquals(button.attributes.type3, "target")
    assertNil(button.attributes["alt-spell4"])
    assertNil(button.healsilusOverride)
  end)

  it("uses the click options macro when targeting or the blue cursor option is on", function()
    local ns = LoadOverride()
    local button = FakeSecureButton("party1")
    ns.UnitButton.buttons[button] = true
    ns.Profiles.active.clicks.avoidBlueCursor = true
    ns.ClickCast:Apply(ns.Profiles.active)
    ns.ClickCast:SetDispelOverride(button, "Quitar maldición")
    assertEquals(button.attributes.type1, "macro")
    assertEquals(button.attributes.macrotext1, "/cast [@mouseover] Quitar maldición\n/stopspelltarget")
  end)

  it("never touches clicks in combat", function()
    local ns, environment = LoadOverride()
    local button = FakeSecureButton("party1")
    ns.ClickCast:Apply(ns.Profiles.active)
    environment.__state.inCombat = true
    assertFalse(ns.ClickCast:SetDispelOverride(button, "Quitar maldición"))
    assertNil(button.attributes.spell1)
  end)
end)

describe("DispelOverride", function()
  it("does nothing unless the option is on", function()
    local ns, _, debuffs = LoadOverride()
    local button = FakeSecureButton("party1")
    ns.ClickCast:Apply(ns.Profiles.active)
    debuffs.party1 = { "Curse" }
    ns.DispelOverride:Evaluate(button)
    assertNil(button.healsilusOverride)
  end)

  it("overrides the clicks of a bar while it has a debuff you can remove", function()
    local ns, _, debuffs = LoadOverride()
    ns.Profiles.active.clicks.dispelOverride = true
    local button = FakeSecureButton("party1")
    ns.UnitButton.buttons[button] = true
    ns.ClickCast:Apply(ns.Profiles.active)
    debuffs.party1 = { "Magic", "Curse" }
    ns.DispelOverride:Evaluate(button)
    assertEquals(button.healsilusOverride, "Quitar maldición")
    assertEquals(button.attributes.spell1, "Quitar maldición")
    debuffs.party1 = {}
    ns.DispelOverride:Evaluate(button)
    assertNil(button.healsilusOverride)
    assertEquals(button.attributes.spell1, "Toque de sanación")
  end)

  it("gives every bar its normal clicks back when combat starts", function()
    local ns, environment, debuffs = LoadOverride()
    ns.Profiles.active.clicks.dispelOverride = true
    local button = FakeSecureButton("party1")
    ns.UnitButton.buttons[button] = true
    ns.ClickCast:Apply(ns.Profiles.active)
    debuffs.party1 = { "Curse" }
    ns.DispelOverride:Evaluate(button)
    assertEquals(button.attributes.spell1, "Quitar maldición")
    environment.__fireEvent("PLAYER_REGEN_DISABLED")
    assertNil(button.healsilusOverride)
    assertEquals(button.attributes.spell1, "Toque de sanación")
    environment.__state.inCombat = true
    debuffs.party1 = { "Curse" }
    ns.DispelOverride:Evaluate(button)
    assertNil(button.healsilusOverride)
  end)
end)

describe("Buff override", function()
  it("makes every click cast the missing buff out of combat and gives the clicks back once it is on", function()
    local ns, _, _, buffs = LoadOverride()
    ns.Profiles.active.clicks.buffOverride = true
    local button = FakeSecureButton("party1")
    ns.UnitButton.buttons[button] = true
    ns.ClickCast:Apply(ns.Profiles.active)
    ns.MissingBuffs:Evaluate(button)
    assertEquals(button.healsilusMissing, { "Marca de lo Salvaje" })
    assertEquals(button.healsilusOverride, "Marca de lo Salvaje")
    assertEquals(button.attributes.spell1, "Marca de lo Salvaje")
    assertEquals(button.attributes["ctrl-spell2"], "Marca de lo Salvaje")
    buffs.party1 = { ["Don de lo Salvaje"] = true }
    ns.MissingBuffs:Evaluate(button)
    assertEquals(button.healsilusMissing, {})
    assertNil(button.healsilusOverride)
    assertEquals(button.attributes.spell1, "Toque de sanación")
  end)

  it("is on by default in new profiles", function()
    local ns = LoadOverride()
    assertTrue(ns.Database.DefaultProfile().clicks.buffOverride)
    assertTrue(ns.Database.NormalizeProfile(ns.ClassDefaults.DRUID(), {}).clicks.buffOverride)
  end)

  it("does nothing while the option is off", function()
    local ns = LoadOverride()
    local button = FakeSecureButton("party1")
    ns.UnitButton.buttons[button] = true
    ns.ClickCast:Apply(ns.Profiles.active)
    ns.MissingBuffs:Evaluate(button)
    assertEquals(button.healsilusMissing, { "Marca de lo Salvaje" })
    assertNil(button.healsilusOverride)
    assertEquals(button.attributes.spell1, "Toque de sanación")
  end)

  it("lets the dispel win when the bar also has a debuff you can remove", function()
    local ns, _, debuffs = LoadOverride()
    ns.Profiles.active.clicks.buffOverride = true
    ns.Profiles.active.clicks.dispelOverride = true
    local button = FakeSecureButton("party1")
    ns.UnitButton.buttons[button] = true
    ns.ClickCast:Apply(ns.Profiles.active)
    debuffs.party1 = { "Curse" }
    ns.MissingBuffs:Evaluate(button)
    assertEquals(button.healsilusOverride, "Quitar maldición")
    debuffs.party1 = {}
    ns.DispelOverride:Evaluate(button)
    assertEquals(button.healsilusOverride, "Marca de lo Salvaje")
  end)

  it("restores the normal clicks when combat starts and never casts buffs in combat", function()
    local ns, environment = LoadOverride()
    ns.Profiles.active.clicks.buffOverride = true
    local button = FakeSecureButton("party1")
    ns.UnitButton.buttons[button] = true
    ns.ClickCast:Apply(ns.Profiles.active)
    ns.MissingBuffs:Evaluate(button)
    assertEquals(button.attributes.spell1, "Marca de lo Salvaje")
    environment.__fireEvent("PLAYER_REGEN_DISABLED")
    environment.__state.inCombat = true
    assertNil(button.healsilusOverride)
    assertEquals(button.attributes.spell1, "Toque de sanación")
    ns.DispelOverride:Evaluate(button)
    assertNil(button.healsilusOverride)
  end)

  it("works on a client build with secret restrictions while auras are readable", function()
    local ns, environment = LoadOverride()
    environment.C_Secrets = {
      HasSecretRestrictions = function()
        return true
      end,
      ShouldAurasBeSecret = function()
        return false
      end,
    }
    ns.Profiles.active.clicks.buffOverride = true
    local button = FakeSecureButton("party1")
    ns.UnitButton.buttons[button] = true
    ns.ClickCast:Apply(ns.Profiles.active)
    ns.MissingBuffs:Evaluate(button)
    assertEquals(button.healsilusOverride, "Marca de lo Salvaje")
  end)
end)

describe("DispelOverride with secret auras", function()
  it("keeps the current clicks when the debuff list comes back secret", function()
    local ns, environment, debuffs = LoadOverride()
    ns.Profiles.active.clicks.dispelOverride = true
    local button = FakeSecureButton("party1")
    ns.UnitButton.buttons[button] = true
    ns.ClickCast:Apply(ns.Profiles.active)
    debuffs.party1 = { "Curse" }
    ns.DispelOverride:Evaluate(button)
    assertEquals(button.healsilusOverride, "Quitar maldición")
    environment.C_UnitAuras.GetAuraDataByIndex = function()
      return Stubs.MakeSecret()
    end
    assertNil(ns.DispelOverride.DebuffTypes("party1"))
    ns.DispelOverride:Evaluate(button)
    assertEquals(button.healsilusOverride, "Quitar maldición")
  end)

  it("stops reading auras while the client says they are secret", function()
    local ns, environment = LoadOverride()
    assertTrue(ns.DispelOverride.CanRead())
    environment.C_Secrets = {
      ShouldAurasBeSecret = function()
        return true
      end,
    }
    assertFalse(ns.DispelOverride.CanRead())
  end)
end)
