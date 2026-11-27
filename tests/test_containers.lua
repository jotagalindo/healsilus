local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertNil = Harness.assertEquals, Harness.assertTrue, Harness.assertNil

local FILES = {
  "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/CombatQueue.lua", "Core/Database.lua", "Core/StyleData.lua",
  "Data/Spells.lua", "Frames/Media.lua", "Auras/Containers.lua",
}

local CONTAINER_METHODS = {
  "Hide", "Show", "ClearAllPoints", "SetPoint", "SetFrameLevel", "SetMouseClickEnabled",
  "SetMouseMotionEnabled", "SetUnit", "AddAuraGroup", "SetEnabled", "UpdateAllAuras",
}

local function LoadContainers(options)
  options = options or {}
  local environment = Stubs.NewEnvironment({ spells = { [774] = { name = "Rejuvenecimiento" } } })
  local containers = {}
  local baseCreateFrame = environment.CreateFrame
  environment.CreateFrame = function(frameType, name, parent, template)
    if frameType ~= "AuraContainer" then
      return baseCreateFrame(frameType, name, parent, template)
    end
    if options.unsupported then
      error("unknown frame type AuraContainer")
    end
    local container = { calls = {} }
    for _, method in ipairs(CONTAINER_METHODS) do
      container[method] = function(self, ...)
        if method == "SetUnit" and options.failingUnit and (...) == options.failingUnit then
          error("bad unit")
        end
        self.calls[#self.calls + 1] = { method, ... }
      end
    end
    containers[#containers + 1] = container
    return container
  end
  local ns = Loader.Load(environment, FILES)
  local profile = ns.Database.DefaultProfile()
  profile.auras.hotSpellIDs = { [774] = true }
  ns.Profiles = { active = profile }
  ns.Styles = { active = ns.StyleData.DefaultStyle() }
  ns.UnitButton = { buttons = {} }
  return ns, environment, containers
end

local function FakeButton(unit)
  return {
    unit = unit,
    GetFrameLevel = function()
      return 5
    end,
    healsilus = { healthBar = {} },
  }
end

local function GroupCall(container)
  for _, call in ipairs(container.calls) do
    if call[1] == "AddAuraGroup" then
      return call
    end
  end
  return nil
end

local function MethodPosition(container, method)
  for position, call in ipairs(container.calls) do
    if call[1] == method then
      return position
    end
  end
  return nil
end

describe("Containers", function()
  it("builds HoT, debuff and dispel-highlight containers with the right filters", function()
    local ns = LoadContainers()
    local button = FakeButton("party1")
    ns.Containers:Attach(button)
    local built = button.healsilusAuras
    local hots = GroupCall(built.hots)
    assertEquals(hots[3], "HELPFUL|PLAYER")
    assertEquals(hots[4].maxFrameCount, 4)
    assertEquals(hots[4].candidateFilters.includeSpellIDs, { [774] = true })
    assertEquals(GroupCall(built.debuffs)[3], "HARMFUL|RAID")
    assertEquals(GroupCall(built.debuffs)[4].maxFrameCount, 2)
    assertEquals(GroupCall(built.highlight)[3], "HARMFUL|RAID")
    assertEquals(GroupCall(built.highlight)[4].maxFrameCount, 1)
  end)

  it("follows the order the client requires and shows the containers afterwards", function()
    local ns = LoadContainers()
    local button = FakeButton("party1")
    ns.Containers:Attach(button)
    for _, container in pairs(button.healsilusAuras) do
      local unitAt = MethodPosition(container, "SetUnit")
      local groupAt = MethodPosition(container, "AddAuraGroup")
      local enabledAt = MethodPosition(container, "SetEnabled")
      local shownAt = MethodPosition(container, "Show")
      assertTrue(unitAt < groupAt and groupAt < enabledAt and enabledAt < shownAt)
    end
  end)

  it("marks dispellable debuffs with a ring, a tinted bar or both, as the style says", function()
    local ns = LoadContainers()
    local button = FakeButton("party1")
    ns.Containers:Attach(button)
    assertTrue(button.healsilusAuras.highlight ~= nil)
    assertNil(button.healsilusAuras.tint)
    ns.Styles.active.auras.dispelMode = "BAR"
    ns.Containers:Attach(button)
    assertNil(button.healsilusAuras.highlight)
    assertEquals(GroupCall(button.healsilusAuras.tint)[3], "HARMFUL|RAID")
    ns.Styles.active.auras.dispelMode = "BOTH"
    ns.Containers:Attach(button)
    assertTrue(button.healsilusAuras.highlight ~= nil and button.healsilusAuras.tint ~= nil)
  end)

  it("places HoT and debuff icons in the corners chosen by the style", function()
    local ns = LoadContainers()
    ns.Styles.active.auras.hots = ns.StyleData.AuraGroup("TOPLEFT", 14)
    ns.Styles.active.auras.debuffs = ns.StyleData.AuraGroup("BOTTOMRIGHT", 14)
    local button = FakeButton("party1")
    ns.Containers:Attach(button)
    local function PointCall(container)
      for _, call in ipairs(container.calls) do
        if call[1] == "SetPoint" then
          return { call[2], call[4], call[5], call[6] }
        end
      end
    end
    assertEquals(PointCall(button.healsilusAuras.hots), { "TOPLEFT", "TOPLEFT", 1, -1 })
    assertEquals(PointCall(button.healsilusAuras.debuffs), { "BOTTOMRIGHT", "BOTTOMRIGHT", -1, 1 })
  end)

  it("places icons outside the bar, anchored to the whole button, when the style asks for a side", function()
    local ns = LoadContainers()
    ns.Styles.active.auras.hots = ns.StyleData.AuraGroup("BELOW", 14)
    ns.Styles.active.auras.debuffs = ns.StyleData.AuraGroup("OUTSIDE_RIGHT", 14)
    local button = FakeButton("party1")
    ns.Containers:Attach(button)
    local function PointCall(container)
      for _, call in ipairs(container.calls) do
        if call[1] == "SetPoint" then
          return call
        end
      end
    end
    local hots = PointCall(button.healsilusAuras.hots)
    assertTrue(hots[3] == button)
    assertEquals({ hots[2], hots[4], hots[5], hots[6] }, { "TOPLEFT", "BOTTOMLEFT", 0, -3 })
    local debuffs = PointCall(button.healsilusAuras.debuffs)
    assertTrue(debuffs[3] == button)
    assertEquals({ debuffs[2], debuffs[4], debuffs[5], debuffs[6] }, { "TOPLEFT", "TOPRIGHT", 3, 0 })
  end)

  it("grows icons away from the bar on each side and towards the center in corners", function()
    local ns = LoadContainers()
    local function Growth(position)
      local anchor = ns.Containers.Anchor(ns.StyleData.AuraGroup(position, 14))
      return { anchor.relativeTo, anchor.horizontal, anchor.vertical }
    end
    assertEquals(Growth("ABOVE"), { "BUTTON", "Right", "Up" })
    assertEquals(Growth("BELOW"), { "BUTTON", "Right", "Down" })
    assertEquals(Growth("OUTSIDE_LEFT"), { "BUTTON", "Left", "Down" })
    assertEquals(Growth("OUTSIDE_RIGHT"), { "BUTTON", "Right", "Down" })
    assertEquals(Growth("TOPRIGHT"), { "BAR", "Left", "Down" })
    assertEquals(Growth("BOTTOMLEFT"), { "BAR", "Right", "Up" })
    for position in pairs(ns.Database.ENUMS.position) do
      assertTrue(ns.Containers.Anchor(ns.StyleData.AuraGroup(position, 14)).point ~= nil, position)
    end
  end)

  it("moves each group by the chosen offset and grows it the chosen way", function()
    local ns = LoadContainers()
    local group = { position = "CENTER", x = 5, y = -2, iconSize = 14, grow = "LEFT" }
    local anchor = ns.Containers.Anchor(group)
    assertEquals({ anchor.relativeTo, anchor.point, anchor.x, anchor.y, anchor.horizontal }, { "BAR", "CENTER", 5, -2, "Left" })
    group.position, group.x, group.y = "TOPLEFT", 2, 0
    anchor = ns.Containers.Anchor(group)
    assertEquals({ anchor.x, anchor.y, anchor.vertical }, { 3, -1, "Down" })
    -- Encima de la barra creciendo a la izquierda: empieza en la esquina derecha.
    group.position, group.x, group.y = "ABOVE", 0, 4
    anchor = ns.Containers.Anchor(group)
    assertEquals({ anchor.point, anchor.relativePoint, anchor.y, anchor.horizontal }, { "BOTTOMRIGHT", "TOPRIGHT", 7, "Left" })
  end)

  it("uses the plain harmful filter when every debuff should be shown", function()
    local ns = LoadContainers()
    ns.Profiles.active.auras.debuffsDispellableOnly = false
    local button = FakeButton("party1")
    ns.Containers:Attach(button)
    assertEquals(GroupCall(button.healsilusAuras.debuffs)[3], "HARMFUL")
  end)

  it("skips the HoT container when HoTs are off or the list is empty", function()
    local ns = LoadContainers()
    ns.Profiles.active.auras.hotSpellIDs = {}
    local button = FakeButton("party1")
    ns.Containers:Attach(button)
    assertNil(button.healsilusAuras.hots)
    ns.Profiles.active.auras.hotSpellIDs = { [774] = true }
    ns.Profiles.active.auras.hotsEnabled = false
    ns.Containers:Attach(button)
    assertNil(button.healsilusAuras.hots)
  end)

  it("never creates containers in combat and builds them when combat ends", function()
    local ns, environment, containers = LoadContainers()
    environment.__state.inCombat = true
    local button = FakeButton("party1")
    ns.Containers:Attach(button)
    assertEquals(#containers, 0)
    assertTrue(ns.Containers.pending[button])
    environment.__state.inCombat = false
    environment.__fireEvent("PLAYER_REGEN_ENABLED")
    assertTrue(button.healsilusAuras ~= nil)
    assertNil(ns.Containers.pending[button])
  end)

  it("hides a container whose unit change fails and records the error", function()
    local ns = LoadContainers({ failingUnit = "raid40" })
    local button = FakeButton("party1")
    ns.Containers:Attach(button)
    ns.Containers:SetUnit(button, "raid40")
    assertNil(button.healsilusAuras.hots)
    assertEquals(ns.Diagnostics.errors[1].context, "Containers:SetUnit")
  end)

  it("records an unsupported client and builds nothing", function()
    local ns = LoadContainers({ unsupported = true })
    local button = FakeButton("party1")
    ns.Containers:Attach(button)
    assertNil(button.healsilusAuras)
    assertEquals(ns.Diagnostics.errors[1].context, "AuraContainer")
  end)
end)
