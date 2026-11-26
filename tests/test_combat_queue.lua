local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertFalse = Harness.assertEquals, Harness.assertTrue, Harness.assertFalse

local function LoadQueue()
  local environment = Stubs.NewEnvironment()
  local ns = Loader.Load(environment, { "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/CombatQueue.lua" })
  return ns, environment
end

describe("CombatQueue", function()
  it("runs immediately outside combat", function()
    local ns = LoadQueue()
    local ran = false
    assertTrue(ns.CombatQueue:Run("layout", function()
      ran = true
    end))
    assertTrue(ran)
    assertEquals(ns.CombatQueue:Count(), 0)
  end)

  it("defers in combat, keeps the latest action per key and the first arrival order", function()
    local ns, environment = LoadQueue()
    environment.__state.inCombat = true
    local order = {}
    assertFalse(ns.CombatQueue:Run("layout", function()
      order[#order + 1] = "layout-old"
    end))
    ns.CombatQueue:Run("clicks", function()
      order[#order + 1] = "clicks"
    end)
    ns.CombatQueue:Run("layout", function()
      order[#order + 1] = "layout-new"
    end)
    assertEquals(ns.CombatQueue:Count(), 2)
    assertEquals(order, {})
    environment.__state.inCombat = false
    environment.__fireEvent("PLAYER_REGEN_ENABLED")
    assertEquals(order, { "layout-new", "clicks" })
    assertEquals(ns.CombatQueue:Count(), 0)
  end)

  it("announces queue changes and combat transitions", function()
    local ns, environment = LoadQueue()
    local counts, transitions = {}, {}
    ns.Events:Register("COMBAT_QUEUE_CHANGED", function(count)
      counts[#counts + 1] = count
    end)
    ns.Events:Register("COMBAT_STARTED", function()
      transitions[#transitions + 1] = "started"
    end)
    ns.Events:Register("COMBAT_ENDED", function()
      transitions[#transitions + 1] = "ended"
    end)
    environment.__fireEvent("PLAYER_REGEN_DISABLED")
    environment.__state.inCombat = true
    ns.CombatQueue:Run("a", function() end)
    environment.__state.inCombat = false
    environment.__fireEvent("PLAYER_REGEN_ENABLED")
    assertEquals(counts, { 1, 0 })
    assertEquals(transitions, { "started", "ended" })
  end)

  it("keeps running the remaining actions when one fails and records the failure", function()
    local ns, environment = LoadQueue()
    environment.__state.inCombat = true
    local ran = false
    ns.CombatQueue:Run("broken", function()
      error("boom")
    end)
    ns.CombatQueue:Run("fine", function()
      ran = true
    end)
    environment.__state.inCombat = false
    environment.__fireEvent("PLAYER_REGEN_ENABLED")
    assertTrue(ran)
    assertEquals(#ns.Diagnostics.errors, 1)
    assertEquals(ns.Diagnostics.errors[1].context, "CombatQueue:broken")
  end)
end)
