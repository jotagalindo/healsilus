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
    ns.Styles.active.auras.hotsPoint = "TOPLEFT"
    ns.Styles.active.auras.debuffsPoint = "BOTTOMRIGHT"
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
