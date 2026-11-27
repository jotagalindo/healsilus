local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue = Harness.assertEquals, Harness.assertTrue

local FILES = {
  "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/CombatQueue.lua",
  "Core/Database.lua", "Core/StyleData.lua", "Data/Spells.lua", "Frames/ClickCast.lua",
}

local SPELLS = {
  [2893] = { name = "Suprimir veneno" },
  [8946] = { name = "Curar envenenamiento" },
  [774] = { name = "Rejuvenecimiento" },
}

local function LoadClickCast(spellbook)
  local environment = Stubs.NewEnvironment({ spells = SPELLS, spellbook = spellbook or {} })
  local ns = Loader.Load(environment, FILES)
  ns.Spells:Scan()
  ns.UnitButton = { buttons = {} }
  ns.Headers = { list = {} }
  return ns, environment
end

local function FakeResolver(binding)
  if binding.spellID == 999 then
    return nil
  end
  return "Spell" .. binding.spellID .. (binding.rank and ("(" .. binding.rank .. ")") or "")
end

local function AsPairs(attributes)
  local result = {}
  for _, attribute in ipairs(attributes) do
    result[#result + 1] = attribute.name .. "=" .. attribute.value
  end
  return result
end

describe("ClickCast.BuildAttributes", function()
  it("defaults left click to target and right click to the unit menu", function()
    local ns = LoadClickCast()
    assertEquals(AsPairs(ns.ClickCast.BuildAttributes({}, FakeResolver)), { "type1=target", "type2=togglemenu" })
  end)

  it("maps every binding kind with its modifier prefix in canonical order", function()
    local ns = LoadClickCast()
    local attributes = ns.ClickCast.BuildAttributes({
      ["1"] = { kind = "spell", spellID = 774 },
      ["4"] = { kind = "menu" },
      ["alt-2"] = { kind = "target" },
      ["ctrl-3"] = { kind = "macro", text = "/cast [@mouseover] Innervate" },
      ["shift-1"] = { kind = "spell", spellID = 8936, rank = 2 },
    }, FakeResolver)
    assertEquals(AsPairs(attributes), {
      "type1=spell", "spell1=Spell774", "type2=togglemenu", "type4=togglemenu",
      "alt-type2=target",
      "ctrl-type3=macro", "ctrl-macrotext3=/cast [@mouseover] Innervate",
      "shift-type1=spell", "shift-spell1=Spell8936(2)",
    })
  end)

  it("leaves a slot empty when its spell cannot be resolved", function()
    local ns = LoadClickCast()
    assertEquals(AsPairs(ns.ClickCast.BuildAttributes({ ["1"] = { kind = "spell", spellID = 999 } }, FakeResolver)), { "type2=togglemenu" })
  end)

  it("turns spells into a mouseover macro that also targets and/or cancels the blue cursor", function()
    local ns = LoadClickCast()
    local bindings = { ["shift-2"] = { kind = "spell", spellID = 774 } }
    assertEquals(AsPairs(ns.ClickCast.BuildAttributes(bindings, FakeResolver, { targetOnClick = true, avoidBlueCursor = true })), {
      "type1=target", "type2=togglemenu",
      "shift-type2=macro", "shift-macrotext2=/target [@mouseover]\n/cast [@mouseover] Spell774\n/stopspelltarget",
    })
    assertEquals(AsPairs(ns.ClickCast.BuildAttributes(bindings, FakeResolver, { targetOnClick = false, avoidBlueCursor = true })), {
      "type1=target", "type2=togglemenu",
      "shift-type2=macro", "shift-macrotext2=/cast [@mouseover] Spell774\n/stopspelltarget",
    })
    assertEquals(AsPairs(ns.ClickCast.BuildAttributes(bindings, FakeResolver, { targetOnClick = false, avoidBlueCursor = false })), {
      "type1=target", "type2=togglemenu", "shift-type2=spell", "shift-spell2=Spell774",
    })
  end)
end)

describe("ClickCast.ResolveSpell", function()
  it("uses the fallback spell only when the main one is not learned", function()
    local binding = { kind = "spell", spellID = 2893, fallbackSpellID = 8946 }
    local ns = LoadClickCast({ { spellID = 8946, name = "Curar envenenamiento", subName = "" } })
    assertEquals(ns.ClickCast.ResolveSpell(binding), "Curar envenenamiento")
    ns = LoadClickCast({
      { spellID = 8946, name = "Curar envenenamiento", subName = "" },
      { spellID = 2893, name = "Suprimir veneno", subName = "" },
    })
    assertEquals(ns.ClickCast.ResolveSpell(binding), "Suprimir veneno")
    ns = LoadClickCast({})
    assertEquals(ns.ClickCast.ResolveSpell(binding), "Suprimir veneno")
  end)
end)

describe("ClickCast application", function()
  local function FakeSecureFrame()
    local frame = { attributes = {} }
    function frame:SetAttribute(name, value)
      self.attributes[name] = value
    end
    function frame:GetAttribute(name)
      return self.attributes[name]
    end
    return frame
  end

  it("clears attributes from the previous profile before writing the new ones", function()
    local ns = LoadClickCast()
    local button = FakeSecureFrame()
    button.attributes.type3 = "macro"
    button.healsilusAttributeNames = { "type3" }
    ns.ClickCast.ApplyToButton(button, { { name = "type1", value = "target" } })
    assertEquals(button.attributes, { type1 = "target" })
    assertEquals(button.healsilusAttributeNames, { "type1" })
  end)

  it("stores the attributes on headers so new buttons can copy them", function()
    local ns = LoadClickCast()
    local header = FakeSecureFrame()
    ns.ClickCast.StoreOnHeader(header, { { name = "type1", value = "target" }, { name = "type2", value = "togglemenu" } })
    ns.ClickCast.StoreOnHeader(header, { { name = "type1", value = "spell" } })
    assertEquals(header.attributes, { ["hs-attr-count"] = 1, ["hs-attr-name-1"] = "type1", ["hs-attr-value-1"] = "spell" })
  end)

  it("applies the profile to every button and header, refusing to run in combat", function()
    local ns, environment = LoadClickCast()
    local button, header = FakeSecureFrame(), FakeSecureFrame()
    ns.UnitButton.buttons[button] = true
    ns.Headers.list[1] = header
    local profile = ns.Database.DefaultProfile()
    ns.ClickCast:Apply(profile)
    assertEquals(button.attributes, { type1 = "target", type2 = "togglemenu" })
    assertEquals(header.attributes["hs-attr-count"], 2)
    environment.__state.inCombat = true
    Harness.assertError(function()
      ns.ClickCast:Apply(profile)
    end, "in combat")
  end)

  it("lets a button created by the header adopt the current attribute names", function()
    local ns = LoadClickCast()
    ns.ClickCast:Apply(ns.Database.DefaultProfile())
    local button = FakeSecureFrame()
    ns.ClickCast:AdoptButton(button)
    assertEquals(button.healsilusAttributeNames, { "type1", "type2" })
  end)

  it("queues a refresh requested in combat and applies it afterwards", function()
    local ns, environment = LoadClickCast()
    local button = FakeSecureFrame()
    ns.UnitButton.buttons[button] = true
    ns.Profiles = { active = ns.Database.DefaultProfile() }
    environment.__state.inCombat = true
    ns.Events:Fire("SETTINGS_CHANGED", "bindings")
    assertEquals(button.attributes, {})
    environment.__state.inCombat = false
    environment.__fireEvent("PLAYER_REGEN_ENABLED")
    assertTrue(button.attributes.type1 == "target")
  end)

  it("turns the 'missing buff' click into a per-bar macro filled only out of combat", function()
    local ns, environment = LoadClickCast()
    local button = FakeSecureFrame()
    ns.UnitButton.buttons[button] = true
    local profile = ns.Database.DefaultProfile()
    profile.bindings["shift-3"] = { kind = "buff" }
    ns.ClickCast:Apply(profile)
    assertEquals(button.attributes["shift-type3"], "macro")
    assertEquals(button.attributes["shift-macrotext3"], "")
    assertTrue(ns.ClickCast:SetBuffMacro(button, "/cast [@mouseover] Espinas"))
    assertEquals(button.attributes["shift-macrotext3"], "/cast [@mouseover] Espinas")
    environment.__state.inCombat = true
    assertEquals(ns.ClickCast:SetBuffMacro(button, ""), false)
    assertEquals(button.attributes["shift-macrotext3"], "/cast [@mouseover] Espinas")
  end)
end)
