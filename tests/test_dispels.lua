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
