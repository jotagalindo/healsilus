local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertFalse, assertNil = Harness.assertEquals, Harness.assertTrue, Harness.assertFalse, Harness.assertNil

local SPELLS = {
  [774] = { name = "Rejuvenecimiento" },
  [1058] = { name = "Rejuvenecimiento" },
  [1430] = { name = "Rejuvenecimiento" },
  [5185] = { name = "Toque de sanación" },
  [8936] = { name = "Recrecimiento" },
}

local SPELLBOOK = {
  { spellID = 774, name = "Rejuvenecimiento", subName = "Rango 1" },
  { spellID = 1058, name = "Rejuvenecimiento", subName = "Rango 2" },
  { spellID = 5185, name = "Toque de sanación", subName = "Rango 1" },
  { spellID = 768, name = "Forma felina", subName = "" },
  { spellID = 99999, name = "Pasiva", subName = "", isPassive = true },
  { spellID = 88888, name = "Futuro", subName = "Rango 1", itemType = 2 },
}

local function LoadSpells()
  local environment = Stubs.NewEnvironment({ spells = SPELLS, spellbook = SPELLBOOK })
  local ns = Loader.Load(environment, { "Core/Init.lua", "Locales/enUS.lua", "Data/Spells.lua" })
  ns.Spells:Scan()
  return ns, environment
end

describe("Spells", function()
  it("parses the rank number from the spellbook subtext", function()
    local ns = LoadSpells()
    assertEquals(ns.Spells.ParseRank("Rango 3"), 3)
    assertEquals(ns.Spells.ParseRank("Rank 10"), 10)
    assertNil(ns.Spells.ParseRank(""))
    assertNil(ns.Spells.ParseRank(nil))
  end)

  it("groups learned ranks by name and skips passive and future spells", function()
    local ns = LoadSpells()
    local entry = ns.Spells.byName["Rejuvenecimiento"]
    assertEquals(entry.maxRank, 2)
    assertEquals(entry.spellIDs, { [774] = true, [1058] = true })
    assertEquals(entry.ranks[2], { spellID = 1058, subName = "Rango 2" })
    assertEquals(ns.Spells.byName["Forma felina"].maxRank, 0)
    assertNil(ns.Spells.byName["Pasiva"])
    assertNil(ns.Spells.byName["Futuro"])
  end)

  it("knows a spell by name, whatever rank ID is asked", function()
    local ns = LoadSpells()
    assertTrue(ns.Spells:IsKnown(774))
    assertTrue(ns.Spells:IsKnown(1430))
    assertFalse(ns.Spells:IsKnown(8936))
    assertFalse(ns.Spells:IsKnown(424242))
  end)

  it("builds the cast text for the highest or a fixed rank", function()
    local ns = LoadSpells()
    assertEquals(ns.Spells:CastString(774), "Rejuvenecimiento")
    assertEquals(ns.Spells:CastString(774, 2), "Rejuvenecimiento(Rango 2)")
    local text, reason = ns.Spells:CastString(774, 3)
    assertNil(text)
    assertEquals(reason, "rank not learned")
    text, reason = ns.Spells:CastString(424242)
    assertNil(text)
    assertEquals(reason, "unknown spell")
  end)

  it("expands a set of spell IDs with every learned rank of the same spell", function()
    local ns = LoadSpells()
    assertEquals(ns.Spells:ExpandRanks({ [1430] = true, [8936] = true }), { [1430] = true, [774] = true, [1058] = true, [8936] = true })
  end)

  it("lists known spells sorted by name", function()
    local ns = LoadSpells()
    local names = {}
    for _, entry in ipairs(ns.Spells:KnownList()) do
      names[#names + 1] = entry.name
    end
    assertEquals(names, { "Forma felina", "Rejuvenecimiento", "Toque de sanación" })
  end)

  it("records an error when the spellbook API is missing", function()
    local environment = Stubs.NewEnvironment()
    environment.C_SpellBook = nil
    local ns = Loader.Load(environment, { "Core/Init.lua", "Locales/enUS.lua", "Data/Spells.lua" })
    ns.Spells:Scan()
    assertEquals(ns.Diagnostics.errors[1].context, "Spells:Scan")
  end)
  it("prefers the highest learned rank ID", function()
    local ns = LoadSpells()
    assertEquals(ns.Spells.PreferredSpellID(ns.Spells.byName["Rejuvenecimiento"]), 1058)
    assertEquals(ns.Spells.PreferredSpellID(ns.Spells.byName["Forma felina"]), 768)
  end)
end)
