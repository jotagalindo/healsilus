local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertFalse = Harness.assertEquals, Harness.assertTrue, Harness.assertFalse

local FILES = {
  "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/CombatQueue.lua", "Core/Database.lua", "Core/StyleData.lua",
  "Frames/Media.lua", "Frames/Snapping.lua", "Frames/Headers.lua", "Frames/Preview.lua", "UI/Widgets.lua", "UI/MoveMode.lua",
}

local function FakeShown()
  local frame = { shown = false }
  function frame:SetShown(shown)
    self.shown = shown and true or false
  end
  return frame
end

-- Healsilus cargado con cabeceras falsas: lo justo para ApplyProfile, la vista previa y el modo mover.
local function LoadMoveMode()
  local environment = Stubs.NewEnvironment()
  environment.StaticPopupDialogs = {}
  environment.RegisterStateDriver = function(frame, _, value)
    frame.visibility = value
  end
  local ns = Loader.Load(environment, FILES)
  -- La barra y la rejilla se construyen con marcos permisivos sobre una pantalla de 1920 × 1080.
  environment.CreateFrame = function()
    return Stubs.NewMock()
  end
  environment.UIParent = {
    GetWidth = function()
      return 1920
    end,
    GetHeight = function()
      return 1080
    end,
  }
  ns.Database:Initialize()
  ns.Profiles = { active = ns.Database.NormalizeProfile(ns.Database.DefaultProfile(), {}) }
  ns.Styles = { active = ns.StyleData.DefaultStyle() }
  ns.ClickCast = { Apply = function() end }
  ns.UnitButton = { buttons = {}, UpdateAllButtons = function() end }
  ns.Config = { built = false }
  local headers = ns.Headers
  headers.initialized = true
  for _, kind in ipairs({ "party", "tanks", "pets" }) do
    headers.byKind[kind] = FakeShown()
  end
  headers.singles.target = { healsilusVisibility = "[@target,help,exists] show; hide", SetSize = function() end }
  headers.ApplyHeaderLayout = function() end
  headers.SetLocked = function(_, locked)
    headers.lockedState = locked
  end
  local previews = {}
  ns.Preview.Show = function(_, count)
    previews[#previews + 1] = count
    ns.Preview.count = count
  end
  ns.Preview.Hide = function()
    previews[#previews + 1] = "hide"
    ns.Preview.count = 0
  end
  return ns, environment, previews
end

describe("Snapping.ToGrid", function()
  it("moves the top left corner of a block onto the nearest grid line", function()
    local ns = LoadMoveMode()
    local rect = { left = 113, right = 223, top = 500, bottom = 466 }
    -- 113 está a 13 de la línea 100 y a 19 de la 132; 500 está a 16 de la 516.
    assertEquals({ ns.Snapping.ToGrid(rect, 100, 100, 32) }, { -13, 16 })
    assertEquals({ ns.Snapping.ToGrid({ left = 100, right = 150, top = 132, bottom = 100 }, 100, 100, 32) }, { 0, 0 })
    assertEquals({ ns.Snapping.ToGrid(rect, 100, 100, 0) }, { 0, 0 })
  end)
end)

describe("MoveMode helpers", function()
  it("cycles grid sizes and sample counts", function()
    local ns = LoadMoveMode()
    assertEquals(ns.MoveMode.NextValue({ 16, 32, 64 }, 32), 64)
    assertEquals(ns.MoveMode.NextValue({ 16, 32, 64 }, 64), 16)
    assertEquals(ns.MoveMode.NextValue({ 5, 10 }, 7), 5)
  end)

  it("draws grid lines from the screen center out to the edges", function()
    local ns = LoadMoveMode()
    local lines = ns.MoveMode.GridLines(200, 100, 32)
    assertEquals(lines.vertical, { 0, 32, -32, 64, -64, 96, -96 })
    assertEquals(lines.horizontal, { 0, 32, -32 })
  end)
end)

describe("Preview blocks", function()
  it("fills every block the profile shows, with the main one at the chosen size", function()
    local ns = LoadMoveMode()
    local frames = ns.Profiles.active.frames
    local kinds = {}
    for _, block in ipairs(ns.Preview.Blocks(frames, 10)) do
      kinds[#kinds + 1] = block.kind .. ":" .. #block.members
    end
    assertEquals(kinds, { "party:10", "tanks:2", "target:1", "focus:1" })
    frames.showPets, frames.showMain, frames.showFocus = true, false, false
    kinds = {}
    for _, block in ipairs(ns.Preview.Blocks(frames, 5)) do
      kinds[#kinds + 1] = block.kind
    end
    assertEquals(kinds, { "tanks", "pets", "target" })
  end)

  it("lays tanks, target and focus out in one column like their real headers", function()
    local ns = LoadMoveMode()
    local layout = ns.StyleData.DefaultStyle().layout
    assertEquals(ns.Preview.BlockLayout("tanks", layout).unitsPerColumn, 40)
    assertEquals(ns.Preview.BlockLayout("party", layout).unitsPerColumn, layout.unitsPerColumn)
    assertEquals(layout.unitsPerColumn, 5)
  end)
end)

describe("MoveMode", function()
  it("unlocks, fills the blocks and shows the toolbar, then locks everything when done", function()
    local ns, _, previews = LoadMoveMode()
    assertTrue(ns.MoveMode:Start())
    assertTrue(ns.MoveMode.active)
    assertFalse(ns.Profiles.active.frames.locked)
    assertEquals(previews, { 5 })
    assertTrue(ns.MoveMode:SnapsToGrid())
    assertEquals(ns.MoveMode:GridSize(), 32)
    ns.MoveMode:Stop()
    assertFalse(ns.MoveMode.active)
    assertTrue(ns.Profiles.active.frames.locked)
    assertEquals(previews, { 5, "hide" })
    assertFalse(ns.MoveMode:SnapsToGrid())
  end)

  it("does not snap to the grid when the grid or snapping is off", function()
    local ns = LoadMoveMode()
    ns.MoveMode:Start()
    ns.Database.db.moveMode.snapToGrid = false
    assertFalse(ns.MoveMode:SnapsToGrid())
    ns.Database.db.moveMode.snapToGrid = true
    ns.Database.db.moveMode.grid = false
    assertFalse(ns.MoveMode:SnapsToGrid())
  end)

  it("refuses to start in combat and closes itself when combat starts", function()
    local ns, environment = LoadMoveMode()
    environment.__state.inCombat = true
    assertFalse(ns.MoveMode:Start())
    environment.__state.inCombat = false
    ns.MoveMode:Start()
    environment.__fireEvent("PLAYER_REGEN_DISABLED")
    assertFalse(ns.MoveMode.active)
    assertTrue(ns.Profiles.active.frames.locked)
  end)

  it("refuses to start while Healsilus is off for this character", function()
    local ns = LoadMoveMode()
    ns.Headers:SetEnabled(false)
    assertFalse(ns.MoveMode:Start())
    assertFalse(ns.MoveMode.active)
  end)
end)

describe("Turning Healsilus off and on", function()
  it("hides every block, gives Blizzard frames back and remembers it per character", function()
    local ns, environment = LoadMoveMode()
    local party = {}
    function party:GetParent()
      return self.parent
    end
    function party:SetParent(parent)
      self.parent = parent
    end
    local original = {}
    party.parent = original
    environment.CompactPartyFrame = party
    ns.Headers:ApplyProfile(ns.Profiles.active)
    assertTrue(ns.Headers.byKind.party.shown)
    assertTrue(party.parent ~= original)
    assertEquals(ns.Headers.singles.target.visibility, "[@target,help,exists] show; hide")

    ns.MoveMode:Start()
    ns.Headers:SetEnabled(false)
    assertFalse(ns.Headers.IsEnabled())
    assertTrue(ns.Database.db.disabledCharacters[ns.CharacterKey()])
    assertFalse(ns.MoveMode.active)
    assertFalse(ns.Headers.byKind.party.shown)
    assertFalse(ns.Headers.byKind.tanks.shown)
    assertEquals(ns.Headers.singles.target.visibility, "hide")
    assertTrue(party.parent == original)
    assertTrue(ns.Headers.lockedState)

    ns.Headers:SetEnabled(true)
    assertTrue(ns.Headers.IsEnabled())
    assertEquals(ns.Database.db.disabledCharacters[ns.CharacterKey()], nil)
    assertTrue(ns.Headers.byKind.party.shown)
    assertTrue(party.parent ~= original)
  end)

  it("keeps the saved switch and move mode settings valid", function()
    local ns, environment = LoadMoveMode()
    environment.HealsilusDB.disabledCharacters = { ["Arsilus-Bah"] = true, ["Other-Realm"] = "yes" }
    environment.HealsilusDB.moveMode = { grid = "on", gridSize = 50, snapToGrid = false, fill = 10 }
    local db = ns.Database:Initialize()
    assertEquals(db.disabledCharacters, { ["Arsilus-Bah"] = true })
    assertEquals(db.moveMode, { grid = true, gridSize = 32, snapToGrid = false, fill = 10 })
    environment.HealsilusDB.moveMode = 3
    assertEquals(ns.Database:Initialize().moveMode, ns.Database.DefaultMoveMode())
  end)
end)

describe("Dropping a block in move mode", function()
  local function FakeAnchor(left, bottom)
    local anchor = { left = left, bottom = bottom }
    function anchor:GetLeft()
      return self.left
    end
    function anchor:GetBottom()
      return self.bottom
    end
    function anchor:ClearAllPoints() end
    function anchor:SetPoint(_, _, _, x, y)
      self.left, self.bottom = x, y
    end
    function anchor:StopMovingOrSizing() end
    function anchor:SetScript() end
    return anchor
  end

  -- Un miembro de ejemplo de 110 × 34 colgando del ancla, como en la vista previa.
  local function FakeSample(anchor)
    local sample = {}
    function sample:GetLeft()
      return anchor.left
    end
    function sample:GetRight()
      return anchor.left + 110
    end
    function sample:GetTop()
      return anchor.bottom - 2
    end
    function sample:GetBottom()
      return anchor.bottom - 36
    end
    return sample
  end

  it("snaps the top left corner of the dropped block to the grid and saves it", function()
    local ns = LoadMoveMode()
    ns.Profiles.active.frames.snapDistance = 0
    local anchor = FakeAnchor(975, 600)
    ns.Headers.anchors.party = anchor
    ns.MoveMode:Start()
    ns.Headers.previewActive = true
    ns.Preview.byKind = { party = { FakeSample(anchor) } }
    ns.Headers:EndDrag("party")
    -- Centro de la pantalla en (960, 540), líneas cada 32 px: 975 → 960 y la parte de arriba 598 → 604.
    assertEquals({ anchor.left, anchor.bottom }, { 960, 606 })
    assertEquals(ns.Database.db.framePositions.party, { "BOTTOMLEFT", 960, 606 })
  end)

  it("leaves the block where it was dropped outside move mode", function()
    local ns = LoadMoveMode()
    ns.Profiles.active.frames.snapDistance = 0
    local anchor = FakeAnchor(975, 600)
    ns.Headers.anchors.party = anchor
    ns.Headers.previewActive = true
    ns.Preview.byKind = { party = { FakeSample(anchor) } }
    ns.Headers:EndDrag("party")
    assertEquals({ anchor.left, anchor.bottom }, { 975, 600 })
  end)

  it("sticks the block to its neighbour while it is still being dragged", function()
    local ns, environment = LoadMoveMode()
    ns.Database.db.moveMode.snapToGrid = false
    local tanks, party = FakeAnchor(330, 640), FakeAnchor(560, 640)
    function tanks:SetScript(kind, handler)
      self[kind] = handler
    end
    ns.Headers.anchors.tanks, ns.Headers.anchors.party = tanks, party
    ns.Headers.previewActive = true
    ns.Preview.byKind = { tanks = { FakeSample(tanks) }, party = { FakeSample(party) } }
    local cursor = { 340, 650 }
    environment.GetCursorPosition = function()
      return cursor[1], cursor[2]
    end
    environment.UIParent.GetEffectiveScale = function()
      return 1
    end
    ns.Headers:BeginDrag("tanks")
    -- 112 px a la derecha y 3 arriba: el borde derecho (552) queda a 6 px del hueco junto al grupo.
    cursor = { 452, 653 }
    tanks.OnUpdate(tanks)
    assertEquals({ tanks.left, tanks.bottom }, { 448, 640 })
    -- Con Mayús pulsada el bloque va donde esté el cursor.
    environment.IsShiftKeyDown = function()
      return true
    end
    tanks.OnUpdate(tanks)
    assertEquals({ tanks.left, tanks.bottom }, { 442, 643 })
    environment.IsShiftKeyDown = function()
      return false
    end
    ns.Headers:EndDrag("tanks")
    assertEquals(ns.Database.db.framePositions.tanks, { "BOTTOMLEFT", 448, 640 })
  end)
end)

