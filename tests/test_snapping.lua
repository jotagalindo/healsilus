local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals = Harness.assertEquals

local function LoadSnapping()
  local environment = Stubs.NewEnvironment()
  return Loader.Load(environment, { "Core/Init.lua", "Locales/enUS.lua", "Frames/Snapping.lua" })
end

local function Rect(left, top, width, height)
  return { left = left, right = left + width, top = top, bottom = top - height }
end

describe("Snapping", function()
  it("sticks a block under another one and aligns their left edges", function()
    local ns = LoadSnapping()
    local fixed = Rect(100, 500, 200, 100)
    local moving = Rect(106, 393, 150, 80)
    assertEquals({ ns.Snapping.Snap(moving, { fixed }, 12, 2) }, { -6, 5 })
  end)

  it("sticks a block to the right of another one and aligns their tops", function()
    local ns = LoadSnapping()
    local fixed = Rect(100, 500, 200, 100)
    local moving = Rect(309, 495, 120, 60)
    assertEquals({ ns.Snapping.Snap(moving, { fixed }, 12, 2) }, { -7, 5 })
  end)

  it("leaves a block alone when nothing is close enough or the magnet is off", function()
    local ns = LoadSnapping()
    local fixed = Rect(100, 500, 200, 100)
    local far = Rect(500, 100, 50, 50)
    assertEquals({ ns.Snapping.Snap(far, { fixed }, 12, 2) }, { 0, 0 })
    local near = Rect(106, 393, 150, 80)
    assertEquals({ ns.Snapping.Snap(near, { fixed }, 0, 2) }, { 0, 0 })
  end)

  it("picks the closest edge among several blocks", function()
    local ns = LoadSnapping()
    local left = Rect(0, 500, 100, 100)
    local right = Rect(300, 500, 100, 100)
    local moving = Rect(104, 500, 100, 100)
    assertEquals({ ns.Snapping.Snap(moving, { left, right }, 12, 2) }, { -2, 0 })
  end)

  it("ignores blocks that are not shown or have no size", function()
    local ns = LoadSnapping()
    local moving = Rect(104, 500, 100, 100)
    assertEquals({ ns.Snapping.Snap(moving, { Rect(0, 500, 0, 0) }, 12, 2) }, { 0, 0 })
  end)
end)

describe("Snapping.Solve", function()
  it("lines up block centers and says where to draw the guides", function()
    local ns = LoadSnapping()
    local fixed = Rect(100, 500, 200, 100)
    local moving = Rect(146, 300, 100, 50)
    local dx, dy, guides = ns.Snapping.Solve(moving, { fixed }, { threshold = 12, gap = 2 })
    assertEquals({ dx, dy }, { 4, 0 })
    assertEquals(guides, { x = 200 })
  end)

  it("sticks a block next to another and marks the shared edges", function()
    local ns = LoadSnapping()
    local fixed = Rect(560, 640, 110, 100)
    local moving = Rect(442, 645, 110, 70)
    local dx, dy, guides = ns.Snapping.Solve(moving, { fixed }, { threshold = 12, gap = 2 })
    assertEquals({ dx, dy }, { 6, -5 })
    assertEquals(guides, { x = 560, y = 640 })
  end)

  it("uses the screen center and the grid only where no block is close", function()
    local ns = LoadSnapping()
    local moving = Rect(906, 300, 100, 50)
    local options = { threshold = 12, gap = 2, screen = { width = 1920, height = 1080 },
      grid = { originX = 960, originY = 540, size = 32 } }
    local dx, dy, guides = ns.Snapping.Solve(moving, {}, options)
    -- Centro del bloque 956 → 960 (centro de pantalla); la parte de arriba 300 → 316 (rejilla).
    assertEquals({ dx, dy }, { 4, 16 })
    assertEquals(guides, { x = 960 })
  end)

  it("does nothing with the magnet off and no grid", function()
    local ns = LoadSnapping()
    local dx, dy, guides = ns.Snapping.Solve(Rect(106, 393, 150, 80), { Rect(100, 500, 200, 100) }, { threshold = 0, gap = 2 })
    assertEquals({ dx, dy }, { 0, 0 })
    assertEquals(guides, {})
  end)
end)
