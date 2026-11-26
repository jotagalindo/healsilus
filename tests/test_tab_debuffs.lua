local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue = Harness.assertEquals, Harness.assertTrue

local function LoadTabDebuffs()
  local environment = Stubs.NewEnvironment({
    spells = {
      [2782] = { name = "Quitar maldición" },
      [2893] = { name = "Suprimir veneno" },
      [8946] = { name = "Curar envenenamiento" },
    },
  })
  environment.StaticPopupDialogs = {}
  local ns = Loader.Load(environment, {
    "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/CombatQueue.lua", "Core/Database.lua", "Core/StyleData.lua",
    "Data/Spells.lua", "Data/Druid.lua", "Data/Dispels.lua", "Frames/ClickCast.lua", "UI/Widgets.lua",
    "UI/Config.lua", "UI/TabClicks.lua", "UI/TabDebuffs.lua",
  })
  ns.Profiles = { active = ns.Database.NormalizeProfile(ns.ClassDefaults.DRUID(), {}) }
  ns.Styles = { active = ns.StyleData.DefaultStyle() }
  return ns
end

describe("TabClicks.KeyLabel", function()
  it("names a click by its modifiers and mouse button", function()
    local ns = LoadTabDebuffs()
    assertEquals(ns.TabClicks.KeyLabel("1"), "Left")
    assertEquals(ns.TabClicks.KeyLabel("shift-2"), "Shift + Right")
    assertEquals(ns.TabClicks.KeyLabel("alt-ctrl-3"), "Alt+Ctrl + Middle")
  end)
end)

describe("TabDebuffs", function()
  it("binds every control to a debuff setting of the right type", function()
    local ns = LoadTabDebuffs()
    local defaults = ns.Database.DefaultProfile().auras
    for _, spec in ipairs(ns.TabDebuffs.CHECKBOXES) do
      assertEquals(type(defaults[spec.key]), "boolean", spec.key)
    end
    for _, spec in ipairs(ns.TabDebuffs.SLIDERS) do
      assertTrue(ns.Database.RANGES[spec.key] ~= nil, spec.key)
    end
  end)

  it("describes each debuff type with its color and the click that removes it", function()
    local ns = LoadTabDebuffs()
    local rows = ns.TabDebuffs.Rows()
    assertEquals(#rows, 4)
    assertEquals(rows[2].dispelType, "Curse")
    assertEquals(rows[2].label, "Curse")
    assertEquals(rows[2].color, { r = 0.6, g = 0, b = 1 })
    assertEquals(rows[2].clicks, "Shift + Right · Quitar maldición")
    assertEquals(rows[3].clicks, "Ctrl + Left · Suprimir veneno")
    assertEquals(rows[1].clicks, "No click removes it (assign one in the Clicks tab)")
  end)

  it("stores a picked color and can restore the defaults", function()
    local ns = LoadTabDebuffs()
    local sections = {}
    ns.Events:Register("SETTINGS_CHANGED", function(section)
      sections[#sections + 1] = section
    end)
    ns.TabDebuffs.SetColor("Curse", 1, 0.5, 0)
    assertEquals(ns.Styles.active.auras.dispelColors.Curse, { r = 1, g = 0.5, b = 0 })
    ns.TabDebuffs.ResetColors()
    assertEquals(ns.Styles.active.auras.dispelColors.Curse, { r = 0.6, g = 0, b = 1 })
    assertEquals(sections, { "style", "style" })
  end)
end)
