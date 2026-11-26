local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertFalse, assertNil = Harness.assertEquals, Harness.assertTrue, Harness.assertFalse, Harness.assertNil

local FILES = {
  "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/CombatQueue.lua", "Core/Database.lua",
  "Core/StyleData.lua", "Data/Spells.lua", "Data/Druid.lua", "Data/Dispels.lua", "Frames/ClickCast.lua",
  "Auras/DispelOverride.lua",
}

local function LoadOverride()
  local environment = Stubs.NewEnvironment({
    spells = {
      [5185] = { name = "Toque de sanación" },
      [2782] = { name = "Quitar maldición" },
      [2893] = { name = "Suprimir veneno" },
      [8946] = { name = "Curar envenenamiento" },
      [774] = { name = "Rejuvenecimiento" },
    },
    spellbook = {
      { spellID = 5185, name = "Toque de sanación", subName = "" },
      { spellID = 2782, name = "Quitar maldición", subName = "" },
      { spellID = 8946, name = "Curar envenenamiento", subName = "" },
    },
  })
  local debuffs = { party1 = {} }
  environment.C_UnitAuras = {
    GetAuraDataByIndex = function(unit, position)
      local dispelName = debuffs[unit] and debuffs[unit][position]
      return dispelName and { dispelName = dispelName } or nil
    end,
  }
  local ns = Loader.Load(environment, FILES)
  ns.Spells:Scan()
  ns.Profiles = { active = ns.Database.NormalizeProfile(ns.ClassDefaults.DRUID(), {}) }
  ns.UnitButton = { buttons = {} }
  ns.Headers = { list = {} }
  return ns, environment, debuffs
end

local function FakeSecureButton(unit)
  local button = { unit = unit, attributes = {} }
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
