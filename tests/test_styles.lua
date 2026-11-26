local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertNil = Harness.assertEquals, Harness.assertTrue, Harness.assertNil

local FILES = {
  "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/CombatQueue.lua", "Core/Database.lua",
  "Core/StyleData.lua", "Data/Spells.lua", "Data/Druid.lua", "Core/Profiles.lua", "Core/Styles.lua",
}

local function LoadStyles()
  local environment = Stubs.NewEnvironment()
  local group = { raid = false, party = false, members = 0 }
  environment.IsInRaid = function()
    return group.raid
  end
  environment.IsInGroup = function()
    return group.party or group.raid
  end
  environment.GetNumGroupMembers = function()
    return group.members
  end
  local ns = Loader.Load(environment, FILES)
  ns.Database:Initialize()
  local changes = {}
  ns.Events:Register("STYLE_CHANGED", function(_, name)
    changes[#changes + 1] = name
  end)
  ns.Profiles:Initialize()
  return ns, environment, group, changes
end

describe("Styles context", function()
  it("tells solo, party and raid sizes apart", function()
    local ns, _, group = LoadStyles()
    assertEquals(ns.Styles.Context(), "solo")
    group.party, group.members = true, 4
    assertEquals(ns.Styles.Context(), "party")
    group.raid = true
    for members, context in pairs({ [8] = "raid10", [10] = "raid10", [15] = "raid20", [20] = "raid20", [25] = "raid40", [40] = "raid40" }) do
      group.members = members
      assertEquals(ns.Styles.Context(), context, tostring(members))
    end
  end)
end)

describe("Styles selection", function()
  it("picks the style of the profile rule for the current situation", function()
    local ns, environment, group, changes = LoadStyles()
    assertEquals(ns.Styles.activeName, "Healsilus")
    assertEquals(changes, { "Healsilus" })
    group.raid, group.members = true, 40
    environment.__fireEvent("GROUP_ROSTER_UPDATE")
    assertEquals(ns.Styles.activeName, "Compact raid")
    assertTrue(ns.Styles.active == ns.Database.db.styles["Compact raid"])
    assertEquals(changes, { "Healsilus", "Compact raid" })
  end)

  it("waits for the end of combat before switching after a roster change", function()
    local ns, environment, group = LoadStyles()
    environment.__state.inCombat = true
    group.raid, group.members = true, 40
    environment.__fireEvent("GROUP_ROSTER_UPDATE")
    assertEquals(ns.Styles.activeName, "Healsilus")
    environment.__state.inCombat = false
    environment.__fireEvent("PLAYER_REGEN_ENABLED")
    assertEquals(ns.Styles.activeName, "Compact raid")
  end)

  it("falls back to the default style when the rule names a missing one", function()
    local ns = LoadStyles()
    ns.Profiles.active.styleRules.solo = "Gone"
    ns.Database.db.styles["Healsilus"] = nil
    ns.Styles:Refresh()
    assertEquals(ns.Styles.activeName, "Healsilus")
    assertTrue(ns.Database.db.styles["Healsilus"] ~= nil)
  end)

  it("changes a rule of the active profile", function()
    local ns = LoadStyles()
    ns.Styles:SetRule("solo", "Classic")
    assertEquals(ns.Profiles.active.styleRules.solo, "Classic")
    assertEquals(ns.Styles.activeName, "Classic")
  end)
end)

describe("Styles management", function()
  it("creates a style as an independent copy and refuses bad or repeated names", function()
    local ns = LoadStyles()
    local source = ns.Database.db.styles["Classic"]
    assertEquals(ns.Styles:Create("  Mine  ", source), "Mine")
    local created = ns.Database.db.styles["Mine"]
    assertTrue(created ~= source)
    assertEquals(created, source)
    local name, failure = ns.Styles:Create("Mine", source)
    assertNil(name)
    assertEquals(failure, "name taken")
    name, failure = ns.Styles:Create("", source)
    assertNil(name)
    assertEquals(failure, "invalid name")
  end)

  it("renames a style everywhere it is used", function()
    local ns = LoadStyles()
    ns.Database.db.characters["Otro-Bah"] = { class = "DRUID", useClassProfile = false, useSpecProfiles = false, specs = {},
      own = ns.Database.NormalizeProfile({}, {}) }
    assertEquals(ns.Styles:Rename("Healsilus", "Main"), "Main")
    assertEquals(ns.Profiles.active.styleRules.solo, "Main")
    assertEquals(ns.Database.db.characters["Otro-Bah"].own.styleRules.party, "Main")
    assertEquals(ns.Styles.activeName, "Main")
    assertNil(ns.Database.db.styles["Healsilus"])
    local name, failure = ns.Styles:Rename("Main", "Classic")
    assertNil(name)
    assertEquals(failure, "name taken")
  end)

  it("deletes a style, moving its users to the default one, but never the last style", function()
    local ns = LoadStyles()
    ns.Styles:SetRule("solo", "Classic")
    assertTrue(ns.Styles:Delete("Classic"))
    assertEquals(ns.Profiles.active.styleRules.solo, "Healsilus")
    assertEquals(ns.Styles.activeName, "Healsilus")
    ns.Styles:Delete("Compact raid")
    ns.Styles:Delete("Large party")
    local deleted, failure = ns.Styles:Delete("Healsilus")
    assertNil(deleted)
    assertEquals(failure, "last style")
  end)

  it("finds a free name for copies and imports", function()
    local ns = LoadStyles()
    assertEquals(ns.Styles:UniqueName("Fresh"), "Fresh")
    assertEquals(ns.Styles:UniqueName("Classic"), "Classic 2")
    ns.Styles:Create("Classic 2", ns.Database.db.styles["Classic"])
    assertEquals(ns.Styles:UniqueName("Classic"), "Classic 3")
    local long = string.rep("x", 60)
    ns.Styles:Create(ns.Styles:UniqueName(long), ns.Database.db.styles["Classic"])
    assertTrue(#ns.Styles:UniqueName(long) <= 40)
    assertTrue(ns.StyleData.IsValidName(ns.Styles:UniqueName(long)))
  end)

  it("lists style names sorted", function()
    local ns = LoadStyles()
    assertEquals(ns.Styles:Names(), { "Classic", "Compact raid", "Healsilus", "Large party" })
  end)
end)
