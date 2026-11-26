local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertFalse = Harness.assertEquals, Harness.assertTrue, Harness.assertFalse

local function LoadDatabase()
  local environment = Stubs.NewEnvironment()
  local ns = Loader.Load(environment, { "Core/Init.lua", "Locales/enUS.lua", "Core/Database.lua", "Core/StyleData.lua" })
  return ns, environment
end

describe("Database.NormalizeProfile", function()
  it("fills an empty table with the complete default profile", function()
    local ns = LoadDatabase()
    local profile = ns.Database.NormalizeProfile({}, {})
    assertEquals(profile, ns.Database.DefaultProfile())
  end)

  it("replaces values of the wrong type and records the field", function()
    local ns = LoadDatabase()
    local fixes = {}
    local profile = ns.Database.NormalizeProfile({ frames = { showTanks = "yes" } }, fixes)
    assertEquals(profile.frames.showTanks, true)
    assertEquals(fixes, { "frames.showTanks" })
  end)

  it("clamps numbers to their range", function()
    local ns = LoadDatabase()
    local fixes = {}
    local profile = ns.Database.NormalizeProfile({ auras = { hotsMax = 50, debuffsMax = -2 } }, fixes)
    assertEquals(profile.auras.hotsMax, 8)
    assertEquals(profile.auras.debuffsMax, 0)
    table.sort(fixes)
    assertEquals(fixes, { "auras.debuffsMax", "auras.hotsMax" })
  end)

  it("never merges defaults into user-owned collections", function()
    local ns = LoadDatabase()
    local profile = ns.Database.NormalizeProfile({ auras = { hotSpellIDs = {} }, buffs = { watched = {} } }, {})
    assertEquals(profile.auras.hotSpellIDs, {})
    assertEquals(profile.buffs.watched, {})
  end)

  it("drops invalid bindings, hot entries and watched buffs but keeps valid ones", function()
    local ns = LoadDatabase()
    local fixes = {}
    local profile = ns.Database.NormalizeProfile({
      bindings = {
        ["1"] = { kind = "spell", spellID = 774 },
        ["shift-2"] = { kind = "macro", text = "/cast [@mouseover] Innervate" },
        ["meta-1"] = { kind = "target" },
        ["2"] = { kind = "spell", spellID = -3 },
        ["3"] = { kind = "spell", spellID = 774, extra = true },
      },
      auras = { hotSpellIDs = { [774] = true, [1.5] = true } },
      buffs = { watched = { { spellID = 1126, targets = "ALL" }, { spellID = 467, targets = "PETS" } } },
    }, fixes)
    assertEquals(profile.bindings, {
      ["1"] = { kind = "spell", spellID = 774 },
      ["shift-2"] = { kind = "macro", text = "/cast [@mouseover] Innervate" },
    })
    assertEquals(profile.auras.hotSpellIDs, { [774] = true })
    assertEquals(profile.buffs.watched, { { spellID = 1126, targets = "ALL" } })
    assertEquals(#fixes, 5)
  end)

  it("defaults buff warnings to coloring the bar, without an expiry warning", function()
    local ns = LoadDatabase()
    local buffs = ns.Database.DefaultProfile().buffs
    assertEquals(buffs.colorBar, true)
    assertEquals(buffs.barColor, { r = 0.94, g = 0.62, b = 0.15 })
    assertEquals(buffs.refreshBelow, 0)
    assertTrue(ns.Database.IsValidBinding({ kind = "buff" }))
    assertFalse(ns.Database.IsValidBinding({ kind = "buff", spellID = 1 }))
    local valid, field = ns.Database.ValidateProfile({ buffs = { barColor = { r = 2, g = 0, b = 0 } } })
    assertFalse(valid)
    assertEquals(field, "buffs.barColor")
  end)

  it("defaults click options to plain casting", function()
    local ns = LoadDatabase()
    assertEquals(ns.Database.DefaultProfile().clicks, { targetOnClick = false, avoidBlueCursor = false, dispelOverride = false, buffOverride = false })
    local valid, field = ns.Database.ValidateProfile({ clicks = { targetOnClick = "yes" } })
    assertFalse(valid)
    assertEquals(field, "clicks.targetOnClick")
  end)

  it("gives every dispel type a default color", function()
    local ns = LoadDatabase()
    assertEquals(ns.Database.DefaultDispelColors(), {
      Magic = { r = 0.2, g = 0.6, b = 1 },
      Curse = { r = 0.6, g = 0, b = 1 },
      Poison = { r = 0, g = 0.6, b = 0 },
      Disease = { r = 0.6, g = 0.4, b = 0 },
    })
  end)

  it("repairs dispel colors: clamps channels, restores broken types and drops unknown ones", function()
    local ns = LoadDatabase()
    local fixes = {}
    local style = ns.StyleData.NormalizeStyle({
      auras = { dispelColors = { Curse = { r = 2, g = 0, b = 1, a = 1 }, Magic = "red", Bleed = { r = 1, g = 0, b = 0 } } },
    }, fixes)
    assertEquals(style.auras.dispelColors.Curse, { r = 1, g = 0, b = 1 })
    assertEquals(style.auras.dispelColors.Magic, { r = 0.2, g = 0.6, b = 1 })
    assertEquals(style.auras.dispelColors.Bleed, nil)
    table.sort(fixes)
    assertEquals(fixes, {
      "style.auras.dispelColors.Bleed", "style.auras.dispelColors.Curse.a", "style.auras.dispelColors.Curse.r",
      "style.auras.dispelColors.Magic",
    })
  end)
end)

describe("Database.ValidateProfile", function()
  it("rejects unknown dispel types and malformed colors", function()
    local ns = LoadDatabase()
    local cases = {
      { { auras = { dispelColors = { Bleed = { r = 1, g = 1, b = 1 } } } }, "style.auras.dispelColors.Bleed" },
      { { auras = { dispelColors = { Curse = { r = 1, g = 1, b = 3 } } } }, "style.auras.dispelColors.Curse.b" },
    }
    for _, case in ipairs(cases) do
      local valid, field = ns.StyleData.ValidateStyle(case[1])
      assertFalse(valid, case[2])
      assertEquals(field, case[2])
    end
    assertTrue(ns.StyleData.ValidateStyle({ auras = { dispelColors = { Poison = { r = 0, g = 1, b = 0 } } } }))
  end)

  it("accepts the default profile and partial profiles", function()
    local ns = LoadDatabase()
    assertTrue(ns.Database.ValidateProfile(ns.Database.DefaultProfile()))
    assertTrue(ns.Database.ValidateProfile({ frames = { showTanks = false } }))
  end)

  it("rejects unknown fields and names them", function()
    local ns = LoadDatabase()
    local valid, field = ns.Database.ValidateProfile({ frames = { colour = "red" } })
    assertFalse(valid)
    assertEquals(field, "frames.colour")
    valid, field = ns.Database.ValidateProfile({ scripts = {} })
    assertFalse(valid)
    assertEquals(field, "scripts")
  end)

  it("rejects wrong types, bad enums, bad bindings and bad buffs", function()
    local ns = LoadDatabase()
    local cases = {
      { { frames = { showTanks = "x" } }, "frames.showTanks" },
      { { frames = { width = 90 } }, "frames.width" },
      { { bindings = { ["1"] = { kind = "spell" } } }, "bindings.1" },
      { { bindings = { ["meta-1"] = { kind = "target" } } }, "bindings.meta-1" },
      { { auras = { hotSpellIDs = { [774] = "yes" } } }, "auras.hotSpellIDs" },
      { { buffs = { watched = { { spellID = 1126, targets = "PETS" } } } }, "buffs.watched.1" },
      { "not a table", "profile" },
    }
    for _, case in ipairs(cases) do
      local valid, field = ns.Database.ValidateProfile(case[1])
      assertFalse(valid, "case " .. case[2])
      assertEquals(field, case[2])
    end
  end)
end)

describe("Database:Initialize", function()
  it("creates the saved structure from nothing", function()
    local ns, environment = LoadDatabase()
    local db = ns.Database:Initialize()
    assertTrue(environment.HealsilusDB == db)
    assertEquals(db.version, 2)
    assertEquals(db.classProfiles, {})
    assertEquals(db.characters, {})
    assertEquals(db.framePositions, {})
    assertFalse(db.debug)
    assertEquals(db.minimap, { angle = 225, hide = false })
  end)

  it("repairs minimap button settings of the wrong type", function()
    local ns, environment = LoadDatabase()
    environment.HealsilusDB = { minimap = { angle = "left", hide = 1 } }
    assertEquals(ns.Database:Initialize().minimap, { angle = 225, hide = false })
    environment.HealsilusDB = { minimap = true }
    assertEquals(ns.Database:Initialize().minimap, { angle = 225, hide = false })
    environment.HealsilusDB = { minimap = { angle = 40, hide = true } }
    assertEquals(ns.Database:Initialize().minimap, { angle = 40, hide = true })
  end)

  it("normalizes stored class and character profiles", function()
    local ns, environment = LoadDatabase()
    environment.HealsilusDB = {
      version = 2,
      classProfiles = { DRUID = { frames = { showTanks = false } }, BROKEN = "nope" },
      characters = {
        ["Arsilus-Bah"] = { class = "DRUID", own = { bindings = {} }, specs = { [2] = {}, x = {} } },
        ["Bad-Realm"] = 7,
      },
    }
    local db = ns.Database:Initialize()
    assertEquals(db.classProfiles.DRUID.frames.showTanks, false)
    assertEquals(db.classProfiles.DRUID.frames.showFocus, true)
    assertEquals(db.classProfiles.BROKEN, nil)
    local character = db.characters["Arsilus-Bah"]
    assertTrue(character.useClassProfile)
    assertFalse(character.useSpecProfiles)
    assertEquals(character.own.frames.showTanks, true)
    assertEquals(character.specs[2].styleRules.solo, "Healsilus")
    assertEquals(character.specs.x, nil)
    assertEquals(db.characters["Bad-Realm"], nil)
  end)

  it("runs migrations in order and refuses missing ones", function()
    local ns, environment = LoadDatabase()
    ns.Database.CURRENT_VERSION = 3
    ns.Database.MIGRATIONS[1] = function(db)
      db.steps = { "1to2" }
    end
    ns.Database.MIGRATIONS[2] = function(db)
      db.steps[#db.steps + 1] = "2to3"
    end
    environment.HealsilusDB = { version = 1 }
    local db = ns.Database:Initialize()
    assertEquals(db.version, 3)
    assertEquals(db.steps, { "1to2", "2to3" })
    ns.Database.MIGRATIONS[2] = nil
    environment.HealsilusDB = { version = 2 }
    Harness.assertError(function()
      ns.Database:Initialize()
    end, "no migration from version 2")
  end)

  it("records data saved by a newer addon version without touching it", function()
    local ns, environment = LoadDatabase()
    environment.HealsilusDB = { version = 9 }
    local db = ns.Database:Initialize()
    assertEquals(db.version, 9)
    assertEquals(ns.Database.fixes[#ns.Database.fixes], "version 9 is newer than this addon")
  end)
end)
