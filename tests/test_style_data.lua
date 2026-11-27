local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertFalse = Harness.assertEquals, Harness.assertTrue, Harness.assertFalse

local function LoadStyleData()
  local environment = Stubs.NewEnvironment()
  local ns = Loader.Load(environment, { "Core/Init.lua", "Locales/enUS.lua", "Core/Database.lua", "Core/StyleData.lua" })
  return ns, environment
end

describe("StyleData defaults and presets", function()
  it("describes layout, bar, text and auras in the default style", function()
    local ns = LoadStyleData()
    local style = ns.StyleData.DefaultStyle()
    assertEquals(style.layout, { width = 110, height = 34, spacing = 2, columns = 8, unitsPerColumn = 5, growth = "DOWN", sortBy = "GROUP" })
    assertEquals(style.bar.texture, "BLIZZARD")
    assertEquals(style.bar.criticalAt, 0.3)
    assertEquals(style.text.name, { size = 11, outline = "NONE", point = "TOPLEFT", x = 4, y = -3 })
    assertEquals(style.text.health.mode, "DEFICIT")
    assertEquals(style.auras.dispelMode, "RING")
    assertEquals(style.auras.dispelColors.Curse, { r = 0.6, g = 0, b = 1 })
  end)

  it("gives styles saved before role icons and aggro dots the new defaults", function()
    local ns = LoadStyleData()
    local saved = ns.StyleData.DefaultStyle()
    saved.role = nil
    saved.aggro = nil
    saved.auras.hotsPoint = "BELOW"
    assertTrue(ns.StyleData.ValidateStyle(saved))
    local normalized = ns.StyleData.NormalizeStyle(saved, {})
    assertEquals(normalized.role, { show = false, showDamager = true, size = 12, point = "LEFT", x = 3, y = 0 })
    assertEquals(normalized.aggro, { border = true, dots = true, size = 8, point = "RIGHT", x = -3, y = 0 })
    assertEquals(normalized.auras.hotsPoint, "BELOW")
    saved.auras.hotsPoint = "SOMEWHERE"
    assertFalse(ns.StyleData.ValidateStyle(saved))
  end)

  it("ships four presets that all pass strict validation", function()
    local ns = LoadStyleData()
    local names = {}
    for _, preset in ipairs(ns.StyleData.PRESETS) do
      names[#names + 1] = preset.name
      assertTrue(ns.StyleData.ValidateStyle(preset.build()), preset.name)
    end
    assertEquals(names, { "Healsilus", "Compact raid", "Large party", "Classic" })
  end)
end)

describe("StyleData normalization and validation", function()
  it("fills missing parts, clamps values and drops unknown keys", function()
    local ns = LoadStyleData()
    local fixes = {}
    local style = ns.StyleData.NormalizeStyle({
      layout = { width = 9000, shape = "round" },
      text = { name = { size = 99, point = "NOWHERE" } },
      auras = { dispelColors = { Bleed = { r = 1, g = 0, b = 0 } } },
    }, fixes)
    assertEquals(style.layout.width, 300)
    assertEquals(style.layout.shape, nil)
    assertEquals(style.text.name.size, 24)
    assertEquals(style.text.name.point, "TOPLEFT")
    assertEquals(style.auras.dispelColors.Bleed, nil)
    assertEquals(style.bar, ns.StyleData.DefaultStyle().bar)
    table.sort(fixes)
    assertEquals(fixes, {
      "style.auras.dispelColors.Bleed", "style.layout.shape", "style.layout.width", "style.text.name.point", "style.text.name.size",
    })
  end)

  it("keeps the health thresholds in order", function()
    local ns = LoadStyleData()
    local style = ns.StyleData.NormalizeStyle({ bar = { criticalAt = 0.7, injuredAt = 0.4 } }, {})
    assertTrue(style.bar.injuredAt > style.bar.criticalAt)
  end)

  it("rejects unknown fields, wrong types and bad values and names them", function()
    local ns = LoadStyleData()
    local cases = {
      { { layout = { width = "wide" } }, "style.layout.width" },
      { { layout = { growth = "UP" } }, "style.layout.growth" },
      { { text = { name = { outline = "GLOW" } } }, "style.text.name.outline" },
      { { auras = { dispelColors = { Bleed = { r = 1, g = 0, b = 0 } } } }, "style.auras.dispelColors.Bleed" },
      { { bar = { background = { r = 1, g = 1, b = 1, a = 3 } } }, "style.bar.background.a" },
      { { sounds = {} }, "style.sounds" },
      { "nope", "style" },
    }
    for _, case in ipairs(cases) do
      local valid, field = ns.StyleData.ValidateStyle(case[1])
      assertFalse(valid, case[2])
      assertEquals(field, case[2])
    end
    assertTrue(ns.StyleData.ValidateStyle({ bar = { texture = "Some LibSharedMedia texture" } }))
  end)

  it("accepts sensible style names only", function()
    local ns = LoadStyleData()
    assertTrue(ns.StyleData.IsValidName("Raid 40"))
    assertFalse(ns.StyleData.IsValidName(""))
    assertFalse(ns.StyleData.IsValidName("   "))
    assertFalse(ns.StyleData.IsValidName(string.rep("x", 41)))
    assertFalse(ns.StyleData.IsValidName(7))
  end)
end)

describe("Database version 2", function()
  it("starts new saved data with the four presets and default style rules", function()
    local ns = LoadStyleData()
    local db = ns.Database:Initialize()
    assertEquals(db.version, ns.Database.CURRENT_VERSION)
    assertTrue(db.styles["Healsilus"] ~= nil and db.styles["Compact raid"] ~= nil)
    assertTrue(db.styles["Large party"] ~= nil and db.styles["Classic"] ~= nil)
    assertEquals(ns.Database.DefaultProfile().styleRules, {
      solo = "Healsilus", party = "Healsilus", raid10 = "Healsilus", raid20 = "Healsilus", raid40 = "Compact raid",
    })
  end)

  it("does not reinstall presets the user deleted", function()
    local ns, environment = LoadStyleData()
    local db = ns.Database:Initialize()
    db.styles["Classic"] = nil
    environment.HealsilusDB = db
    ns.Database:Initialize()
    assertEquals(db.styles["Classic"], nil)
  end)

  it("moves version 1 appearance into styles, sharing identical ones", function()
    local ns, environment = LoadStyleData()
    environment.HealsilusDB = {
      version = 1,
      classProfiles = {
        DRUID = {
          frames = { width = 90, texture = "RAID", healthText = "PERCENT", showTanks = false, outOfRangeAlpha = 0.5 },
          auras = { iconSize = 18, hotsMax = 3, dispelColors = { Curse = { r = 1, g = 0, b = 0 } } },
        },
      },
      characters = {
        ["Arsilus-Bah"] = {
          class = "DRUID",
          own = {
            frames = { width = 90, texture = "RAID", healthText = "PERCENT", outOfRangeAlpha = 0.5 },
            auras = { iconSize = 18, dispelColors = { Curse = { r = 1, g = 0, b = 0 } } },
          },
          specs = { [2] = { frames = { width = 70 } } },
        },
      },
    }
    local db = ns.Database:Initialize()
    assertEquals(db.version, ns.Database.CURRENT_VERSION)
    local migrated = db.styles["My style"]
    assertEquals(migrated.layout.width, 90)
    assertEquals(migrated.bar.texture, "RAID")
    assertEquals(migrated.bar.outOfRangeAlpha, 0.5)
    assertEquals(migrated.text.health.mode, "PERCENT")
    assertEquals(migrated.auras.iconSize, 18)
    assertEquals(migrated.auras.dispelColors.Curse, { r = 1, g = 0, b = 0 })
    assertEquals(db.styles["My style 2"].layout.width, 70)
    local druid = db.classProfiles.DRUID
    assertEquals(druid.styleRules.raid40, "My style")
    assertEquals(druid.frames.width, nil)
    assertEquals(druid.frames.showTanks, false)
    assertEquals(druid.auras.hotsMax, 3)
    assertEquals(druid.auras.iconSize, nil)
    assertEquals(db.characters["Arsilus-Bah"].own.styleRules.solo, "My style")
    assertEquals(db.characters["Arsilus-Bah"].specs[2].styleRules.party, "My style 2")
  end)

  it("rejects imported profiles with unknown style contexts", function()
    local ns = LoadStyleData()
    local valid, field = ns.Database.ValidateProfile({ styleRules = { arena = "Healsilus" } })
    assertFalse(valid)
    assertEquals(field, "styleRules.arena")
  end)
end)

describe("Text positions", function()
  it("keeps texts off the edges and exactly on the centered axis", function()
    local ns = LoadStyleData()
    assertEquals({ ns.StyleData.DefaultOffset("TOPLEFT") }, { 4, -3 })
    assertEquals({ ns.StyleData.DefaultOffset("CENTER") }, { 0, 0 })
    assertEquals({ ns.StyleData.DefaultOffset("TOP") }, { 0, -3 })
    assertEquals({ ns.StyleData.DefaultOffset("RIGHT") }, { -4, 0 })
    assertEquals({ ns.StyleData.DefaultOffset("BOTTOMRIGHT") }, { -4, 3 })
  end)

  it("re-centers texts left off-center by version 4 when moved to the center", function()
    local ns, environment = LoadStyleData()
    local style = ns.StyleData.DefaultStyle()
    style.text.name.point = "CENTER"
    style.text.status = { size = 10, outline = "NONE", point = "TOP", x = 15, y = -3 }
    environment.HealsilusDB = { version = 4, styles = { Mine = style } }
    local db = ns.Database:Initialize()
    assertEquals(db.version, ns.Database.CURRENT_VERSION)
    local name, status = db.styles.Mine.text.name, db.styles.Mine.text.status
    assertEquals({ name.x, name.y }, { 0, 0 })
    -- Un desplazamiento grande es una elección del usuario y se respeta; el eje de arriba no se toca.
    assertEquals({ status.x, status.y }, { 15, -3 })
    assertEquals({ db.styles.Mine.text.health.x, db.styles.Mine.text.health.y }, { 4, 3 })
  end)

  it("starts every style fully opaque at full health", function()
    local ns = LoadStyleData()
    assertEquals(ns.StyleData.DefaultStyle().bar.fullHealthAlpha, 1)
    local style = ns.StyleData.DefaultStyle()
    style.bar.fullHealthAlpha = 0
    ns.StyleData.NormalizeStyle(style, {})
    assertEquals(style.bar.fullHealthAlpha, 0.05)
  end)
end)
