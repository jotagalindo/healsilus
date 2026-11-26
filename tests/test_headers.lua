local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue = Harness.assertEquals, Harness.assertTrue

local FILES = {
  "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/CombatQueue.lua", "Core/Database.lua", "Core/StyleData.lua",
  "Frames/Media.lua", "Frames/Headers.lua",
}

local function LoadHeaders()
  local environment = Stubs.NewEnvironment()
  local ns = Loader.Load(environment, FILES)
  return ns, environment
end

local function FakeHeader(kind)
  local header = { healsilusKind = kind, attributes = {}, history = {}, shown = false }
  function header:SetAttribute(name, value)
    self.attributes[name] = value
    self.history[#self.history + 1] = name .. "=" .. tostring(value)
  end
  function header:GetAttribute(name)
    return self.attributes[name]
  end
  function header:Show()
    self.shown = true
    self.history[#self.history + 1] = "Show"
  end
  return header
end

local function FakeChild()
  local child = {}
  function child:SetSize(width, height)
    self.size = { width, height }
  end
  return child
end

describe("Headers layout", function()
  it("lays out the party header downwards, sorted by group", function()
    local ns = LoadHeaders()
    local header = FakeHeader("party")
    ns.Headers:ApplyHeaderLayout(header, ns.StyleData.DefaultStyle().layout, ns.Database.DefaultProfile().frames)
    local attributes = header.attributes
    assertEquals(attributes["hs-width"], 110)
    assertEquals(attributes["hs-height"], 34)
    assertEquals(attributes.point, "TOP")
    assertEquals(attributes.xOffset, 0)
    assertEquals(attributes.yOffset, -2)
    assertEquals(attributes.columnAnchorPoint, "LEFT")
    assertEquals(attributes.columnSpacing, 2)
    assertEquals(attributes.groupBy, "GROUP")
    assertEquals(attributes.groupingOrder, "1,2,3,4,5,6,7,8")
    assertEquals(attributes.groupFilter, "1,2,3,4,5,6,7,8")
    assertEquals(attributes.unitsPerColumn, 5)
    assertEquals(attributes.maxColumns, 8)
    assertEquals(attributes["hs-use-on-key-down"], false)
    assertTrue(attributes.showSolo)
    assertTrue(attributes.showRaid and attributes.showParty and attributes.showPlayer)
  end)

  it("grows to the right and sorts by class when asked", function()
    local ns = LoadHeaders()
    local layout = ns.StyleData.DefaultStyle().layout
    layout.growth = "RIGHT"
    layout.sortBy = "CLASS"
    local header = FakeHeader("party")
    ns.Headers:ApplyHeaderLayout(header, layout, ns.Database.DefaultProfile().frames)
    assertEquals(header.attributes.point, "LEFT")
    assertEquals(header.attributes.xOffset, 2)
    assertEquals(header.attributes.yOffset, 0)
    assertEquals(header.attributes.columnAnchorPoint, "TOP")
    assertEquals(header.attributes.groupBy, "CLASS")
  end)

  it("shows each header only in the situations chosen (solo, party, raid)", function()
    local ns = LoadHeaders()
    local frames = ns.Database.DefaultProfile().frames
    frames.showSolo, frames.showInParty, frames.showInRaid = false, false, true
    for _, kind in ipairs({ "party", "tanks", "pets" }) do
      local header = FakeHeader(kind)
      ns.Headers:ApplyHeaderLayout(header, ns.StyleData.DefaultStyle().layout, frames)
      assertEquals(header.attributes.showSolo, false, kind)
      assertEquals(header.attributes.showParty, false, kind)
      assertEquals(header.attributes.showRaid, true, kind)
    end
  end)

  it("filters the tanks header by role in a single column", function()
    local ns = LoadHeaders()
    local header = FakeHeader("tanks")
    ns.Headers:ApplyHeaderLayout(header, ns.StyleData.DefaultStyle().layout, ns.Database.DefaultProfile().frames)
    assertEquals(header.attributes.roleFilter, "MAINTANK,TANK")
    assertEquals(header.attributes.showSolo, false)
    assertEquals(header.attributes.unitsPerColumn, 8)
    assertEquals(header.attributes.maxColumns, 1)
  end)

  it("resizes buttons the header already created", function()
    local ns = LoadHeaders()
    local header = FakeHeader("party")
    header.attributes.child1, header.attributes.child2 = FakeChild(), FakeChild()
    local layout = ns.StyleData.DefaultStyle().layout
    layout.width, layout.height = 90, 30
    ns.Headers:ApplyHeaderLayout(header, layout, ns.Database.DefaultProfile().frames)
    assertEquals(header.attributes.child1.size, { 90, 30 })
    assertEquals(header.attributes.child2.size, { 90, 30 })
    assertEquals(ns.Headers:CountButtons(header), 2)
  end)

  -- La initialConfigFunction lee hs-width/hs-height: sin ellos el primer botón falla y la cabecera
  -- deja de crear el resto (en el juego salían "1 botones" en /hs diag).
  it("sets the button size before showing, then precreates with a negative starting index", function()
    local ns = LoadHeaders()
    local header = FakeHeader("party")
    ns.Headers:Precreate(header, ns.StyleData.DefaultStyle().layout)
    assertEquals(header.history, {
      "hs-width=110", "hs-height=34", "unitsPerColumn=40", "maxColumns=1", "startingIndex=-39", "Show", "startingIndex=1",
    })
  end)
end)

describe("Headers and Blizzard frames", function()
  it("moves Blizzard party and raid frames to a hidden parent and restores them", function()
    local ns, environment = LoadHeaders()
    local original = {}
    local party = {}
    function party:GetParent()
      return self.parent
    end
    function party:SetParent(parent)
      self.parent = parent
    end
    party.parent = original
    environment.CompactPartyFrame = party
    ns.Headers:ApplyBlizzardVisibility(true)
    assertTrue(party.parent ~= original)
    ns.Headers:ApplyBlizzardVisibility(true)
    ns.Headers:ApplyBlizzardVisibility(false)
    assertTrue(party.parent == original)
  end)
end)
