local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertFalse = Harness.assertEquals, Harness.assertTrue, Harness.assertFalse

local function LoadEvents()
  local environment = Stubs.NewEnvironment()
  local ns = Loader.Load(environment, { "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua" })
  return ns, environment
end

describe("Events", function()
  it("delivers internal events to every callback in registration order", function()
    local ns = LoadEvents()
    local received = {}
    ns.Events:Register("PROFILE_CHANGED", function(first, second)
      received[#received + 1] = "a:" .. first .. second
    end)
    ns.Events:Register("PROFILE_CHANGED", function(first)
      received[#received + 1] = "b:" .. first
    end)
    ns.Events:Fire("PROFILE_CHANGED", "x", "y")
    assertEquals(received, { "a:xy", "b:x" })
  end)

  it("ignores internal events without listeners", function()
    local ns = LoadEvents()
    ns.Events:Fire("NOBODY_LISTENS", 1)
  end)

  it("registers each game event once and passes the event name first", function()
    local ns, environment = LoadEvents()
    local received = {}
    assertTrue(ns.Events:RegisterGameEvent("UNIT_HEALTH", function(event, unit)
      received[#received + 1] = event .. ":" .. unit
    end))
    ns.Events:RegisterGameEvent("UNIT_HEALTH", function(_, unit)
      received[#received + 1] = "second:" .. unit
    end)
    assertTrue(ns.Events.frame.events.UNIT_HEALTH)
    environment.__fireEvent("UNIT_HEALTH", "party1")
    assertEquals(received, { "UNIT_HEALTH:party1", "second:party1" })
  end)

  it("refuses events the client does not know", function()
    local ns, environment = LoadEvents()
    environment.C_EventUtils = {
      IsEventValid = function(event)
        return event ~= "FAKE_EVENT"
      end,
    }
    assertFalse(ns.Events:RegisterGameEvent("FAKE_EVENT", function() end))
    assertEquals(ns.Events.frame.events.FAKE_EVENT, nil)
  end)
end)
