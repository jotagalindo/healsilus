local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertFalse = Harness.assertEquals, Harness.assertTrue, Harness.assertFalse

local function LoadInit()
  local environment = Stubs.NewEnvironment()
  local ns = Loader.Load(environment, { "Core/Init.lua", "Locales/enUS.lua" })
  return ns, environment
end

describe("Init", function()
  it("detects fake secret values", function()
    local ns = LoadInit()
    assertTrue(ns.IsSecret(Stubs.MakeSecret()))
    assertFalse(ns.IsSecret(42))
    assertFalse(ns.IsSecret(nil))
  end)

  it("treats every value as readable when issecretvalue does not exist", function()
    local environment = Stubs.NewEnvironment()
    environment.issecretvalue = nil
    local ns = Loader.Load(environment, { "Core/Init.lua" })
    assertFalse(ns.IsSecret(Stubs.MakeSecret()))
  end)

  it("deep-copies nested tables without sharing references", function()
    local ns = LoadInit()
    local original = { frames = { width = 110 }, list = { 1, 2 } }
    local copy = ns.DeepCopy(original)
    assertEquals(copy, original)
    copy.frames.width = 50
    assertEquals(original.frames.width, 110)
    assertEquals(ns.DeepCopy(7), 7)
  end)

  it("builds the character key from name and realm", function()
    local ns = LoadInit()
    assertEquals(ns.CharacterKey(), "Arsilus-Bah")
  end)

  it("records every error and prints only the first one per context", function()
    local ns, environment = LoadInit()
    ns.RecordError("auras", "boom")
    ns.RecordError("auras", "again")
    assertEquals(#ns.Diagnostics.errors, 2)
    assertEquals(#environment.__state.printed, 1)
  end)

  it("exposes the namespace as the Healsilus global", function()
    local ns, environment = LoadInit()
    assertTrue(environment.Healsilus == ns)
  end)

  it("falls back to the key for missing translations", function()
    local ns = LoadInit()
    assertEquals(ns.L.SOME_MISSING_KEY, "SOME_MISSING_KEY")
  end)

  it("lists every modifier prefix and mouse button", function()
    local ns = LoadInit()
    assertEquals(#ns.BINDING_PREFIXES, 8)
    assertEquals(ns.MOUSE_BUTTONS, { "1", "2", "3", "4", "5" })
  end)

  it("accepts unknown events only when C_EventUtils is missing", function()
    local ns, environment = LoadInit()
    assertTrue(ns.IsEventValid("ANYTHING"))
    environment.C_EventUtils = {
      IsEventValid = function(event)
        return event == "UNIT_HEALTH"
      end,
    }
    assertTrue(ns.IsEventValid("UNIT_HEALTH"))
    assertFalse(ns.IsEventValid("FAKE_EVENT"))
  end)
end)
