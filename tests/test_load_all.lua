local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue = Harness.assertEquals, Harness.assertTrue

describe("Full addon load", function()
  it("loads every TOC file in order without errors", function()
    local environment = Stubs.NewEnvironment({ permissive = true })
    local ns = Loader.Load(environment, Loader.TocFiles("Healsilus.toc"))
    for _, module in ipairs({ "Events", "CombatQueue", "Database", "Spells", "Profiles", "Serializer", "Media",
      "Curves", "ClickCast", "Prediction", "Containers", "MissingBuffs", "UnitButton", "Headers", "Preview",
      "Widgets", "Config", "Diagnostics" }) do
      assertTrue(type(ns[module]) == "table", module)
    end
  end)

  it("registers the settings tabs in the intended order", function()
    local environment = Stubs.NewEnvironment({ permissive = true })
    local ns = Loader.Load(environment, Loader.TocFiles("Healsilus.toc"))
    assertEquals(ns.Config.tabOrder, { "clicks", "frames", "appearance", "auras", "debuffs", "buffs", "styles", "profiles" })
  end)
end)
