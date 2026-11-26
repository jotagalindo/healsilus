local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertFalse = Harness.assertEquals, Harness.assertTrue, Harness.assertFalse

local function LoadMinimapButton()
  local environment = Stubs.NewEnvironment()
  environment.HealsilusDB = { minimap = { angle = 225, hide = false } }
  environment.Minimap = {
    GetWidth = function()
      return 140
    end,
  }
  local ns = Loader.Load(environment, { "Core/Init.lua", "Locales/enUS.lua", "UI/MinimapButton.lua" })
  local calls = {}
  ns.Config = {
    Toggle = function()
      calls[#calls + 1] = "toggle"
    end,
  }
  ns.HandleCommand = function(message)
    calls[#calls + 1] = "command:" .. message
  end
  return ns, environment, calls
end

local function Near(actual, expected)
  return math.abs(actual - expected) < 0.001
end

local function FakeButton()
  local button = { shown = true }
  function button:SetShown(shown)
    self.shown = shown
  end
  function button:ClearAllPoints()
    self.point = nil
  end
  function button:SetPoint(...)
    self.point = { ... }
  end
  return button
end

describe("MinimapButton position", function()
  it("places the button on a circle around a round minimap", function()
    local ns = LoadMinimapButton()
    local x, y = ns.MinimapButton.Offset(0, 80, false)
    assertTrue(Near(x, 80) and Near(y, 0))
    x, y = ns.MinimapButton.Offset(90, 80, false)
    assertTrue(Near(x, 0) and Near(y, 80))
  end)

  it("pushes the button into the corners of a square minimap", function()
    local ns = LoadMinimapButton()
    local x, y = ns.MinimapButton.Offset(225, 80, true)
    assertTrue(Near(x, -80) and Near(y, -80))
  end)

  it("turns a drag offset into an angle between 0 and 360", function()
    local ns = LoadMinimapButton()
    assertTrue(Near(ns.MinimapButton.AngleFromOffset(10, 0), 0))
    assertTrue(Near(ns.MinimapButton.AngleFromOffset(0, 10), 90))
    assertTrue(Near(ns.MinimapButton.AngleFromOffset(-10, 0), 180))
    assertTrue(Near(ns.MinimapButton.AngleFromOffset(0, -10), 270))
  end)
end)

describe("MinimapButton behaviour", function()
  it("opens the settings on left click and toggles the frame lock on right click", function()
    local ns, _, calls = LoadMinimapButton()
    ns.MinimapButton.OnClick("LeftButton")
    ns.MinimapButton.OnClick("RightButton")
    assertEquals(calls, { "toggle", "command:lock" })
  end)

  it("hides and shows the button and remembers the choice", function()
    local ns, environment = LoadMinimapButton()
    local button = FakeButton()
    ns.MinimapButton.button = button
    ns.MinimapButton:SetHidden(true)
    assertTrue(environment.HealsilusDB.minimap.hide)
    assertFalse(button.shown)
    ns.MinimapButton:SetHidden(false)
    assertFalse(environment.HealsilusDB.minimap.hide)
    assertTrue(button.shown)
    assertEquals(button.point[1], "CENTER")
    assertTrue(button.point[2] == environment.Minimap)
  end)

  it("answers clicks from the minimap addon menu", function()
    local _, environment, calls = LoadMinimapButton()
    environment.Healsilus_OnAddonCompartmentClick("Healsilus", "LeftButton")
    assertEquals(calls, { "toggle" })
  end)
end)
