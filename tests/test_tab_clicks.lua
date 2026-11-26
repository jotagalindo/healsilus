local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertFalse, assertNil = Harness.assertEquals, Harness.assertTrue, Harness.assertFalse, Harness.assertNil

local FILES = {
  "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/CombatQueue.lua", "Core/Database.lua", "Core/StyleData.lua",
  "Data/Spells.lua", "Frames/ClickCast.lua", "UI/Widgets.lua", "UI/Config.lua", "UI/TabClicks.lua",
}

local function LoadTabClicks()
  local environment = Stubs.NewEnvironment({
    spells = {
      [5185] = { name = "Toque de sanación", icon = 136041 },
      [2893] = { name = "Suprimir veneno" },
      [8946] = { name = "Curar envenenamiento" },
      [424242] = { name = "Nunca aprendido" },
    },
    spellbook = {
      { spellID = 5185, name = "Toque de sanación", subName = "Rango 1" },
      { spellID = 8946, name = "Curar envenenamiento", subName = "" },
    },
  })
  environment.StaticPopupDialogs = {}
  local ns = Loader.Load(environment, FILES)
  ns.Spells:Scan()
  return ns
end

describe("TabClicks.Describe", function()
  it("explains the defaults of empty left and right clicks", function()
    local ns = LoadTabClicks()
    assertEquals({ ns.TabClicks.Describe(nil, "1") }, { "Target (default)", nil, true })
    assertEquals({ ns.TabClicks.Describe(nil, "2") }, { "Menu (default)", nil, true })
    assertEquals({ ns.TabClicks.Describe(nil, "shift-3") }, { "-", nil, true })
  end)

  it("shows a learned spell with its icon as valid", function()
    local ns = LoadTabClicks()
    local text, icon, valid = ns.TabClicks.Describe({ kind = "spell", spellID = 5185 }, "1")
    assertEquals(text, "Toque de sanación")
    assertEquals(icon, 136041)
    assertTrue(valid)
  end)

  it("marks spells and ranks that are not learned", function()
    local ns = LoadTabClicks()
    local _, _, valid = ns.TabClicks.Describe({ kind = "spell", spellID = 424242 }, "1")
    assertFalse(valid)
    local text
    text, _, valid = ns.TabClicks.Describe({ kind = "spell", spellID = 5185, rank = 4 }, "1")
    assertEquals(text, "Toque de sanación (rank 4)")
    assertFalse(valid)
  end)

  it("accepts a binding whose fallback spell is learned", function()
    local ns = LoadTabClicks()
    local _, _, valid = ns.TabClicks.Describe({ kind = "spell", spellID = 2893, fallbackSpellID = 8946 }, "ctrl-1")
    assertTrue(valid)
  end)

  it("labels macros, targeting and the unit menu", function()
    local ns = LoadTabClicks()
    assertEquals((ns.TabClicks.Describe({ kind = "macro", text = "/cast X" }, "4")), "Macro")
    assertEquals((ns.TabClicks.Describe({ kind = "target" }, "4")), "Target")
    local text, icon = ns.TabClicks.Describe({ kind = "menu" }, "4")
    assertEquals(text, "Unit menu")
    assertNil(icon)
  end)
end)
