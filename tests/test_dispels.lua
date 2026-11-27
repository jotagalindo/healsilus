local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals = Harness.assertEquals

local function LoadDispels()
  local environment = Stubs.NewEnvironment({
    spells = {
      [2782] = { name = "Quitar maldición" },
      [2893] = { name = "Suprimir veneno" },
      [8946] = { name = "Curar envenenamiento" },
      [774] = { name = "Rejuvenecimiento" },
      [4987] = { name = "Limpiar" },
    },
  })
  local ns = Loader.Load(environment, {
    "Core/Init.lua", "Locales/enUS.lua", "Core/Database.lua", "Core/StyleData.lua", "Data/Spells.lua", "Data/Druid.lua", "Data/Dispels.lua",
  })
  return ns
end

describe("Dispels", function()
  it("finds which click removes each debuff type in the druid profile", function()
    local ns = LoadDispels()
    local clicks = ns.Dispels.ClicksFor(ns.ClassDefaults.DRUID().bindings)
    assertEquals(clicks, { Magic = {}, Curse = { "shift-2" }, Poison = { "ctrl-1" }, Disease = {} })
  end)

  it("counts a spell that removes several types once per type, in canonical click order", function()
    local ns = LoadDispels()
    local clicks = ns.Dispels.ClicksFor({
      ["shift-1"] = { kind = "spell", spellID = 4987 },
      ["1"] = { kind = "spell", spellID = 4987 },
      ["2"] = { kind = "spell", spellID = 774 },
      ["3"] = { kind = "macro", text = "/cast Limpiar" },
    })
    assertEquals(clicks, { Magic = { "1", "shift-1" }, Curse = {}, Poison = { "1", "shift-1" }, Disease = { "1", "shift-1" } })
  end)

  it("recognises a dispel bound through its fallback spell", function()
    local ns = LoadDispels()
    local clicks = ns.Dispels.ClicksFor({ ["4"] = { kind = "spell", spellID = 424242, fallbackSpellID = 8946 } })
    assertEquals(clicks.Poison, { "4" })
  end)
end)

describe("Dispels for the Debuffs tab", function()
  local function LoadKnown()
    local environment = Stubs.NewEnvironment({
      spells = {
        [2782] = { name = "Quitar maldición" },
        [2893] = { name = "Suprimir veneno" },
        [8946] = { name = "Curar envenenamiento" },
      },
      spellbook = {
        { spellID = 2782, name = "Quitar maldición", subName = "" },
        { spellID = 8946, name = "Curar envenenamiento", subName = "" },
        { spellID = 2893, name = "Suprimir veneno", subName = "" },
      },
    })
    local ns = Loader.Load(environment, {
      "Core/Init.lua", "Locales/enUS.lua", "Core/Database.lua", "Core/StyleData.lua", "Data/Spells.lua", "Data/Druid.lua", "Data/Dispels.lua",
    })
    ns.Spells:Scan()
    return ns
  end

  local function Names(spells)
    local names = {}
    for _, spell in ipairs(spells) do
      names[#names + 1] = spell.name
    end
    return names
  end

  it("lists the learned spells that remove each type", function()
    local ns = LoadKnown()
    assertEquals(Names(ns.Dispels.KnownSpellsFor("Poison")), { "Curar envenenamiento", "Suprimir veneno" })
    assertEquals(Names(ns.Dispels.KnownSpellsFor("Curse")), { "Quitar maldición" })
    assertEquals(ns.Dispels.KnownSpellsFor("Magic"), {})
  end)

  it("suggests the first free click, preferring modified right and left clicks", function()
    local ns = LoadKnown()
    assertEquals(ns.Dispels.SuggestKey({}), "shift-2")
    assertEquals(ns.Dispels.SuggestKey(ns.ClassDefaults.DRUID().bindings), "alt-2")
  end)

  it("assigns a cure spell to a click", function()
    local ns = LoadKnown()
    local bindings = ns.ClassDefaults.DRUID().bindings
    ns.Dispels.Assign(bindings, "alt-2", 2782)
    assertEquals(bindings["alt-2"], { kind = "spell", spellID = 2782 })
    assertEquals(ns.Dispels.ClicksFor(bindings).Curse, { "alt-2", "shift-2" })
  end)
end)
