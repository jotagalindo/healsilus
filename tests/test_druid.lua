local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue = Harness.assertEquals, Harness.assertTrue

local function LoadDruid()
  local environment = Stubs.NewEnvironment()
  return Loader.Load(environment, { "Core/Init.lua", "Locales/enUS.lua", "Core/Database.lua", "Data/Druid.lua" })
end

describe("Druid defaults", function()
  it("produce a profile that passes strict validation", function()
    local ns = LoadDruid()
    assertTrue(ns.Database.ValidateProfile(ns.ClassDefaults.DRUID()))
  end)

  it("bind the agreed spells to each click", function()
    local ns = LoadDruid()
    assertEquals(ns.ClassDefaults.DRUID().bindings, {
      ["1"] = { kind = "spell", spellID = 5185 },
      ["2"] = { kind = "spell", spellID = 774 },
      ["shift-1"] = { kind = "spell", spellID = 8936 },
      ["shift-2"] = { kind = "spell", spellID = 2782 },
      ["ctrl-1"] = { kind = "spell", spellID = 2893, fallbackSpellID = 8946 },
      ["ctrl-2"] = { kind = "spell", spellID = 20484 },
      ["3"] = { kind = "target" },
    })
  end)

  it("track Rejuvenation and Regrowth and watch Mark and Thorns", function()
    local ns = LoadDruid()
    local profile = ns.ClassDefaults.DRUID()
    assertEquals(profile.auras.hotSpellIDs, { [774] = true, [8936] = true })
    assertEquals(profile.buffs.watched, {
      { spellID = 1126, groupSpellID = 21849, targets = "ALL" },
      { spellID = 467, targets = "TANKS" },
    })
  end)

  it("return a fresh table on every call", function()
    local ns = LoadDruid()
    local first = ns.ClassDefaults.DRUID()
    first.bindings["1"] = nil
    assertEquals(ns.ClassDefaults.DRUID().bindings["1"], { kind = "spell", spellID = 5185 })
  end)
end)
