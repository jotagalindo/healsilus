local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertFalse = Harness.assertEquals, Harness.assertTrue, Harness.assertFalse

local function LoadMedia()
  local environment = Stubs.NewEnvironment()
  environment.CreateColor = function(red, green, blue, alpha)
    return { r = red, g = green, b = blue, a = alpha }
  end
  local ns = Loader.Load(environment, { "Core/Init.lua", "Locales/enUS.lua", "Core/Database.lua", "Core/StyleData.lua", "Frames/Media.lua", "Frames/Curves.lua" })
  return ns, environment
end

local function InstallCurveApi(environment)
  local created = {}
  local function Factory()
    local curve = { points = {} }
    function curve:SetType(kind)
      self.kind = kind
    end
    function curve:AddPoint(position, value)
      self.points[#self.points + 1] = { position, value }
    end
    created[#created + 1] = curve
    return curve
  end
  environment.C_CurveUtil = { CreateCurve = Factory, CreateColorCurve = Factory }
  environment.Enum.LuaCurveType = { Linear = 0, Step = 1 }
  environment.UnitHealthPercent = function()
    return 1
  end
  return created
end

describe("Media", function()
  it("maps texture keys to paths and falls back to the Blizzard bar", function()
    local ns = LoadMedia()
    assertEquals(ns.Media.Texture("FLAT"), "Interface\\Buttons\\WHITE8X8")
    assertEquals(ns.Media.Texture("UNKNOWN"), "Interface\\TargetingFrame\\UI-StatusBar")
  end)

  it("reads class colors from C_ClassColor, then RAID_CLASS_COLORS, then a fallback", function()
    local ns, environment = LoadMedia()
    environment.RAID_CLASS_COLORS = { DRUID = { r = 1, g = 0.49, b = 0.04 } }
    assertEquals({ ns.Media.ClassColor("DRUID") }, { 1, 0.49, 0.04 })
    environment.C_ClassColor = {
      GetClassColor = function()
        return { r = 0.5, g = 0.5, b = 0.5 }
      end,
    }
    assertEquals({ ns.Media.ClassColor("DRUID") }, { 0.5, 0.5, 0.5 })
    environment.C_ClassColor = nil
    assertEquals({ ns.Media.ClassColor(nil) }, { 0.3, 0.7, 0.3 })
  end)

  it("builds the dispel color map from the profile colors, with defaults for missing types", function()
    local ns = LoadMedia()
    local map = ns.Media.DispelColorMap({ Magic = { r = 0.1, g = 0.2, b = 0.3 } })
    assertEquals(map.Magic, { r = 0.1, g = 0.2, b = 0.3, a = 1 })
    assertEquals(map.Poison, { r = 0, g = 0.6, b = 0, a = 1 })
    assertEquals(map.Curse, { r = 0.6, g = 0, b = 1, a = 1 })
  end)
end)

describe("Media fonts and shared media", function()
  it("resolves built-in fonts and falls back to the default font", function()
    local ns = LoadMedia()
    assertEquals(ns.Media.Font("ARIALN"), "Fonts\\ARIALN.TTF")
    assertEquals(ns.Media.Font("Unknown"), "Fonts\\FRIZQT__.TTF")
  end)

  it("uses LibSharedMedia textures and fonts when another addon loaded it", function()
    local ns, environment = LoadMedia()
    local media = {
      statusbar = { ["Smooth"] = "Interface\\AddOns\\Shared\\Smooth" },
      font = { ["Expressway"] = "Interface\\AddOns\\Shared\\Expressway.ttf" },
    }
    environment.LibStub = function(name, silent)
      assertEquals(name, "LibSharedMedia-3.0")
      assertTrue(silent)
      return {
        Fetch = function(_, kind, key)
          return media[kind][key]
        end,
        List = function(_, kind)
          local names = {}
          for key in pairs(media[kind]) do
            names[#names + 1] = key
          end
          return names
        end,
      }
    end
    assertEquals(ns.Media.Texture("Smooth"), "Interface\\AddOns\\Shared\\Smooth")
    assertEquals(ns.Media.Font("Expressway"), "Interface\\AddOns\\Shared\\Expressway.ttf")
    local values = {}
    for _, option in ipairs(ns.Media.TextureOptions()) do
      values[#values + 1] = option.value
    end
    assertEquals(values, { "BLIZZARD", "RAID", "FLAT", "Smooth" })
  end)
end)

describe("Curves", function()
  it("reports support only when every curve API exists", function()
    local ns, environment = LoadMedia()
    assertFalse(ns.Curves.IsSupported())
    InstallCurveApi(environment)
    assertTrue(ns.Curves.IsSupported())
  end)

  it("builds the health color curve from the style's colors and thresholds and reuses it", function()
    local ns, environment = LoadMedia()
    local created = InstallCurveApi(environment)
    local bar = ns.StyleData.DefaultStyle().bar
    local curve = ns.Curves:HealthColor(bar)
    assertTrue(ns.Curves:HealthColor(ns.DeepCopy(bar)) == curve)
    assertEquals(#created, 1)
    assertEquals(curve.points, {
      { 0, { r = 1, g = 0, b = 0, a = 1 } },
      { 0.3, { r = 1, g = 0, b = 0, a = 1 } },
      { 0.65, { r = 1, g = 1, b = 0, a = 1 } },
      { 1, { r = 0, g = 1, b = 0, a = 1 } },
    })
    bar.critical = { r = 0.5, g = 0, b = 0.5 }
    assertTrue(ns.Curves:HealthColor(bar) ~= curve)
    assertEquals(#created, 2)
  end)

  it("maps health fraction to 0-100 for the percent text", function()
    local ns, environment = LoadMedia()
    InstallCurveApi(environment)
    assertEquals(ns.Curves:Percent().points, { { 0, 0 }, { 1, 100 } })
  end)
end)
