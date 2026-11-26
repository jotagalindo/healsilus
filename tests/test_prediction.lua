local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertFalse = Harness.assertEquals, Harness.assertTrue, Harness.assertFalse

local function LoadPrediction()
  local environment = Stubs.NewEnvironment()
  local ns = Loader.Load(environment, { "Core/Init.lua", "Locales/enUS.lua", "Frames/Media.lua", "Frames/Prediction.lua" })
  return ns, environment
end

local function FakeBar()
  local bar = { calls = {}, shown = false }
  function bar:SetMinMaxValues(...)
    self.calls[#self.calls + 1] = { "SetMinMaxValues", ... }
  end
  function bar:SetValue(...)
    self.calls[#self.calls + 1] = { "SetValue", select("#", ...), ... }
  end
  function bar:Show()
    self.shown = true
  end
  function bar:Hide()
    self.shown = false
  end
  return bar
end

local function FakeButton()
  local calculator = {}
  function calculator:GetMaximumHealth()
    return 1000
  end
  function calculator:GetIncomingHeals()
    return 500
  end
  function calculator:GetDamageAbsorbs()
    return 300, true
  end
  return {
    unit = "party1",
    healsilus = { prediction = { calculator = calculator, incoming = FakeBar(), absorb = FakeBar() } },
  }
end

describe("Prediction", function()
  it("is supported only with the native calculator APIs", function()
    local ns, environment = LoadPrediction()
    assertFalse(ns.Prediction.IsSupported())
    environment.CreateUnitHealPredictionCalculator = function() end
    environment.UnitGetDetailedHealPrediction = function() end
    assertTrue(ns.Prediction.IsSupported())
  end)

  it("feeds the native amounts straight into the bars, one value each", function()
    local ns, environment = LoadPrediction()
    local requested
    environment.UnitGetDetailedHealPrediction = function(unit, healer, calculator)
      requested = { unit, healer, calculator }
    end
    local button = FakeButton()
    ns.Prediction:Update(button)
    local prediction = button.healsilus.prediction
    assertEquals(requested, { "party1", "player", prediction.calculator })
    assertEquals(prediction.incoming.calls, { { "SetMinMaxValues", 0, 1000 }, { "SetValue", 1, 500 } })
    assertEquals(prediction.absorb.calls, { { "SetMinMaxValues", 0, 1000 }, { "SetValue", 1, 300 } })
    assertTrue(prediction.incoming.shown)
    assertTrue(prediction.absorb.shown)
  end)

  it("does nothing for buttons without unit or prediction and hides on request", function()
    local ns, environment = LoadPrediction()
    environment.UnitGetDetailedHealPrediction = function()
      error("must not be called")
    end
    local button = FakeButton()
    button.unit = nil
    ns.Prediction:Update(button)
    ns.Prediction:Update({ unit = "party1", healsilus = {} })
    button.healsilus.prediction.incoming:Show()
    ns.Prediction:Hide(button)
    assertFalse(button.healsilus.prediction.incoming.shown)
    assertFalse(button.healsilus.prediction.absorb.shown)
  end)
end)
