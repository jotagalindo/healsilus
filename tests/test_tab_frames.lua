local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue = Harness.assertEquals, Harness.assertTrue

local function LoadTabFrames()
  local environment = Stubs.NewEnvironment()
  environment.StaticPopupDialogs = {}
  return Loader.Load(environment, {
    "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/CombatQueue.lua", "Core/Database.lua", "Core/StyleData.lua",
    "Frames/Media.lua", "UI/Widgets.lua", "UI/Config.lua", "UI/TabFrames.lua",
  })
end

describe("TabFrames controls", function()
  it("give every slider a stored range and a numeric default in the style", function()
    local ns = LoadTabFrames()
    local style = ns.StyleData.DefaultStyle()
    for _, spec in ipairs(ns.TabFrames.SLIDERS) do
      assertTrue(ns.Database.RANGES[spec.key] ~= nil, spec.key)
      assertEquals(type(style[spec.section][spec.key]), "number", spec.key)
    end
  end)

  it("offer exactly the allowed values in every dropdown, and every texture", function()
    local ns = LoadTabFrames()
    for _, spec in ipairs(ns.TabFrames.DROPDOWNS) do
      local offered = {}
      for _, option in ipairs(ns.TabFrames.OptionsOf(spec)) do
        offered[option.value] = true
      end
      local expected = ns.Database.ENUMS[spec.key] or { BLIZZARD = true, RAID = true, FLAT = true }
      assertEquals(offered, expected, spec.key)
    end
  end)

  it("give every profile slider a stored range and a numeric default", function()
    local ns = LoadTabFrames()
    local defaults = ns.Database.DefaultProfile().frames
    for _, spec in ipairs(ns.TabFrames.PROFILE_SLIDERS) do
      assertTrue(ns.Database.RANGES[spec.key] ~= nil, spec.key)
      assertEquals(type(defaults[spec.key]), "number", spec.key)
    end
  end)

  it("bind every checkbox to a boolean frame setting", function()
    local ns = LoadTabFrames()
    local defaults = ns.Database.DefaultProfile().frames
    for _, spec in ipairs(ns.TabFrames.CHECKBOXES) do
      assertEquals(type(defaults[spec.key]), "boolean", spec.key)
    end
  end)
end)
