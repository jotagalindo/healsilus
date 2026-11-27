local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue = Harness.assertEquals, Harness.assertTrue

local function LoadTabs()
  local environment = Stubs.NewEnvironment()
  environment.StaticPopupDialogs = {}
  local ns = Loader.Load(environment, {
    "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/CombatQueue.lua", "Core/Database.lua",
    "Core/StyleData.lua", "Data/Spells.lua", "Data/Druid.lua", "Core/Profiles.lua", "Core/Styles.lua",
    "Frames/Media.lua", "Core/Serializer.lua", "UI/Widgets.lua", "UI/Config.lua", "UI/TabAppearance.lua", "UI/TabStyles.lua",
  })
  ns.Database:Initialize()
  ns.Profiles:Initialize()
  return ns, environment
end

local function Values(options)
  local values = {}
  for _, option in ipairs(options) do
    values[option.value] = true
  end
  return values
end

describe("TabAppearance controls", function()
  it("offers exactly the allowed outlines, positions and health text modes", function()
    local ns = LoadTabs()
    assertEquals(Values(ns.TabAppearance.OUTLINE_OPTIONS), ns.Database.ENUMS.outline)
    assertEquals(Values(ns.TabAppearance.POINT_OPTIONS), ns.Database.ENUMS.point)
    assertEquals(Values(ns.TabAppearance.HEALTH_MODE_OPTIONS), ns.Database.ENUMS.mode)
  end)

  it("offers role icon and aggro options that exist in every style", function()
    local ns = LoadTabs()
    local defaults = ns.StyleData.DefaultStyle()
    for _, section in ipairs(ns.TabAppearance.INDICATORS) do
      local values = defaults[section.key]
      assertTrue(values ~= nil, section.key)
      assertTrue(ns.Database.ENUMS.point[values.point] == true, section.key)
      assertTrue(type(values.size) == "number", section.key)
      for _, check in ipairs(section.checks) do
        assertEquals(type(values[check.key]), "boolean", section.key .. "." .. check.key)
      end
    end
  end)

  it("edits name, health and status texts of the active style", function()
    local ns = LoadTabs()
    local keys = {}
    for _, element in ipairs(ns.TabAppearance.TEXT_ELEMENTS) do
      keys[#keys + 1] = element.key
      assertTrue(ns.Styles.active.text[element.key] ~= nil, element.key)
    end
    assertEquals(keys, { "name", "health", "status" })
    ns.TabAppearance.selected = "status"
    ns.TabAppearance.TextSetter("size")(14)
    assertEquals(ns.Styles.active.text.status.size, 14)
    assertEquals(ns.TabAppearance.TextGetter("size")(), 14)
  end)
end)

describe("TabAppearance positions", function()
  it("puts a text exactly in the middle of the bar when Center is picked", function()
    local ns = LoadTabs()
    ns.TabAppearance.selected = "name"
    ns.TabAppearance.PointSetter()("CENTER")
    local name = ns.Styles.active.text.name
    assertEquals({ name.point, name.x, name.y }, { "CENTER", 0, 0 })
    ns.TabAppearance.PointSetter("health")("RIGHT")
    local health = ns.Styles.active.text.health
    assertEquals({ health.point, health.x, health.y }, { "RIGHT", -4, 0 })
    ns.TabAppearance.PointSetter("role")("TOPLEFT")
    assertEquals({ ns.Styles.active.role.x, ns.Styles.active.role.y }, { 4, -3 })
  end)

  it("splits the tab into bar, text and icon pages", function()
    local ns = LoadTabs()
    local pages = {}
    for _, page in ipairs(ns.TabAppearance.PAGES) do
      pages[#pages + 1] = page.value
    end
    assertEquals(pages, { "bar", "text", "icons" })
  end)
end)

describe("TabStyles", function()
  it("names every situation and every failure in the user's language", function()
    local ns = LoadTabs()
    for _, context in ipairs(ns.StyleData.CONTEXTS) do
      assertTrue(ns.TabStyles.CONTEXT_LABELS[context] ~= nil, context)
    end
    assertEquals(ns.TabStyles.ErrorText("name taken"), "A style with that name already exists.")
    assertEquals(ns.TabStyles.ErrorText("last style"), "You can't delete your only style.")
  end)

  it("lists styles marking the one in use", function()
    local ns = LoadTabs()
    local rows = ns.TabStyles.Rows()
    assertEquals(#rows, 4)
    local inUse = {}
    for _, row in ipairs(rows) do
      if row.active then
        inUse[#inUse + 1] = row.name
      end
    end
    assertEquals(inUse, { "Healsilus" })
  end)

  it("imports a shared style under a free name", function()
    local ns = LoadTabs()
    local text = ns.Serializer.ExportStyle(ns.Database.db.styles["Classic"])
    assertEquals(ns.TabStyles.ImportText(text), "Imported style")
    assertEquals(ns.TabStyles.ImportText(text), "Imported style 2")
    assertEquals(ns.Database.db.styles["Imported style"], ns.Database.db.styles["Classic"])
  end)
end)
