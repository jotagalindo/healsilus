local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals = Harness.assertEquals

local function LoadPreview()
  local environment = Stubs.NewEnvironment()
  local ns = Loader.Load(environment, {
    "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/Database.lua", "Frames/Preview.lua",
  })
  return ns, environment
end

describe("Preview", function()
  it("places fake members in columns when growing down", function()
    local ns = LoadPreview()
    local frames = ns.Database.DefaultProfile().frames
    assertEquals({ ns.Preview.Offset(1, frames) }, { 0, 0 })
    assertEquals({ ns.Preview.Offset(2, frames) }, { 0, -36 })
    assertEquals({ ns.Preview.Offset(6, frames) }, { 112, 0 })
  end)

  it("places fake members in rows when growing right", function()
    local ns = LoadPreview()
    local frames = ns.Database.DefaultProfile().frames
    frames.growth = "RIGHT"
    assertEquals({ ns.Preview.Offset(2, frames) }, { 112, 0 })
    assertEquals({ ns.Preview.Offset(6, frames) }, { 0, -36 })
  end)

  it("colors fake health from red through yellow to green", function()
    local ns = LoadPreview()
    assertEquals({ ns.Preview.HealthColor(0) }, { 1, 0, 0 })
    assertEquals({ ns.Preview.HealthColor(0.5) }, { 1, 1, 0 })
    assertEquals({ ns.Preview.HealthColor(1) }, { 0, 1, 0 })
  end)

  it("refuses to open in combat", function()
    local ns, environment = LoadPreview()
    environment.__state.inCombat = true
    ns.Preview:Show(5)
    assertEquals(ns.Preview.count, 0)
    assertEquals(environment.__state.printed[1], "|cff33ff99Healsilus:|r Preview is not available in combat.")
  end)
end)
