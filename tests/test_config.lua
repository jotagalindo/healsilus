local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue = Harness.assertEquals, Harness.assertTrue

local FILES = {
  "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/CombatQueue.lua", "Core/Database.lua", "Core/StyleData.lua",
  "UI/Widgets.lua", "UI/Config.lua",
}

local function LoadConfig()
  local environment = Stubs.NewEnvironment()
  environment.StaticPopupDialogs = {}
  environment.LOCALIZED_CLASS_NAMES_MALE = { DRUID = "Druid" }
  local ns = Loader.Load(environment, FILES)
  ns.Profiles = {
    source = "class", characterKey = "Arsilus-Bah", classToken = "DRUID", active = ns.Database.DefaultProfile(),
    ActiveSpecGroup = function()
      return 2
    end,
  }
  return ns, environment
end

describe("Config", function()
  it("describes the active profile source", function()
    local ns = LoadConfig()
    assertEquals(ns.Config.DescribeSource(), "Druid · class profile")
    ns.Profiles.source = "character"
    assertEquals(ns.Config.DescribeSource(), "Arsilus-Bah · own profile")
    ns.Profiles.source = "spec"
    assertEquals(ns.Config.DescribeSource(), "Arsilus-Bah · specialization 2")
  end)

  it("describes copy sources", function()
    local ns = LoadConfig()
    assertEquals(ns.Config.DescribeCopySource({ kind = "class", classToken = "PRIEST" }), "PRIEST · class profile")
    assertEquals(ns.Config.DescribeCopySource({ kind = "character", characterKey = "Otro-Bah" }), "Otro-Bah · own profile")
    assertEquals(ns.Config.DescribeCopySource({ kind = "spec", characterKey = "Otro-Bah", specIndex = 1 }), "Otro-Bah · specialization 1")
  end)

  it("keeps tabs in registration order", function()
    local ns = LoadConfig()
    ns.Config:RegisterTab("clicks", "Clicks", function() end)
    ns.Config:RegisterTab("frames", "Frames", function() end)
    assertEquals(ns.Config.tabOrder, { "clicks", "frames" })
  end)

  it("writes section settings into the active profile and announces the section", function()
    local ns = LoadConfig()
    local announced = {}
    ns.Events:Register("SETTINGS_CHANGED", function(section)
      announced[#announced + 1] = section
    end)
    ns.Widgets.SectionSetter("frames", "width")(90)
    assertEquals(ns.Profiles.active.frames.width, 90)
    assertEquals(ns.Widgets.SectionGetter("frames", "width")(), 90)
    assertEquals(announced, { "frames" })
  end)

  it("registers a confirmation dialog that runs the accepted action", function()
    local ns, environment = LoadConfig()
    local ran = false
    environment.StaticPopupDialogs.HEALSILUS_CONFIRM.OnAccept(nil, function()
      ran = true
    end)
    assertTrue(ran)
  end)
end)
