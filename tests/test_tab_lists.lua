local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue = Harness.assertEquals, Harness.assertTrue

local function LoadTabs()
  local environment = Stubs.NewEnvironment({
    spells = {
      [774] = { name = "Rejuvenecimiento", icon = 136081 },
      [8936] = { name = "Recrecimiento", icon = 136085 },
      [1126] = { name = "Marca de lo Salvaje", icon = 136078 },
      [21849] = { name = "Don de lo Salvaje", icon = 136038 },
    },
  })
  environment.StaticPopupDialogs = {}
  local ns = Loader.Load(environment, {
    "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/CombatQueue.lua", "Core/Database.lua", "Core/StyleData.lua",
    "Data/Spells.lua", "Data/Druid.lua", "UI/Widgets.lua", "UI/Config.lua", "UI/TabAuras.lua", "UI/TabBuffs.lua",
  })
  ns.Profiles = { active = ns.Database.NormalizeProfile(ns.ClassDefaults.DRUID(), {}) }
  return ns
end

describe("TabAuras", function()
  it("lists tracked HoTs sorted by name, naming unknown IDs by number", function()
    local ns = LoadTabs()
    ns.Profiles.active.auras.hotSpellIDs[99] = true
    local names = {}
    for _, item in ipairs(ns.TabAuras.HotItems()) do
      names[#names + 1] = item.name
    end
    assertEquals(names, { "#99", "Recrecimiento", "Rejuvenecimiento" })
  end)

  it("binds every control to a setting of the right type", function()
    local ns = LoadTabs()
    local defaults = ns.Database.DefaultProfile().auras
    for _, spec in ipairs(ns.TabAuras.CHECKBOXES) do
      assertEquals(type(defaults[spec.key]), "boolean", spec.key)
    end
    for _, spec in ipairs(ns.TabAuras.SLIDERS) do
      assertTrue(ns.Database.RANGES[spec.key] ~= nil, spec.key)
    end
  end)
end)

describe("TabBuffs", function()
  it("describes watched buffs with their group version and targets", function()
    local ns = LoadTabs()
    local items = ns.TabBuffs.Items()
    assertEquals(items[1].name, "Marca de lo Salvaje")
    assertEquals(items[1].groupName, "Don de lo Salvaje")
    assertEquals(items[1].position, 1)
    assertEquals(items[2].groupName, nil)
    assertEquals(ns.TabBuffs.TARGET_LABELS[items[2].entry.targets], "Tanks only")
  end)

  it("cycles targets between everyone and tanks", function()
    local ns = LoadTabs()
    assertEquals(ns.TabBuffs.NextTargets("ALL"), "TANKS")
    assertEquals(ns.TabBuffs.NextTargets("TANKS"), "ALL")
  end)
end)
