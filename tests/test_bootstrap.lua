local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals = Harness.assertEquals

local function LoadBootstrap()
  local environment = Stubs.NewEnvironment()
  local ns = Loader.Load(environment, { "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/Bootstrap.lua" })
  local calls = {}
  local function Spy(name)
    return function()
      calls[#calls + 1] = name
    end
  end
  ns.Database = { Initialize = Spy("Database:Initialize") }
  ns.Spells = { Scan = Spy("Spells:Scan") }
  ns.Profiles = { Initialize = Spy("Profiles:Initialize"), Refresh = Spy("Profiles:Refresh") }
  ns.UnitButton = { Initialize = Spy("UnitButton:Initialize") }
  ns.Headers = { Initialize = Spy("Headers:Initialize") }
  ns.Config = { RegisterSettingsCategory = Spy("Config:RegisterSettingsCategory") }
  ns.Events:Register("READY", Spy("READY"))
  ns.Events:Register("SPELLBOOK_UPDATED", Spy("SPELLBOOK_UPDATED"))
  return ns, environment, calls
end

describe("Bootstrap", function()
  it("initializes the saved data only for this addon, then everything else at login", function()
    local _, environment, calls = LoadBootstrap()
    environment.__fireEvent("ADDON_LOADED", "SomeOtherAddon")
    environment.__fireEvent("ADDON_LOADED", "Healsilus")
    environment.__fireEvent("PLAYER_LOGIN")
    assertEquals(calls, {
      "Database:Initialize", "Spells:Scan", "Profiles:Initialize", "UnitButton:Initialize",
      "Headers:Initialize", "Config:RegisterSettingsCategory", "READY",
    })
  end)

  it("rescans the spellbook after login only", function()
    local ns, environment, calls = LoadBootstrap()
    environment.__fireEvent("SPELLS_CHANGED")
    assertEquals(calls, {})
    ns.Profiles.active = {}
    environment.__fireEvent("SPELLS_CHANGED")
    assertEquals(calls, { "Spells:Scan", "SPELLBOOK_UPDATED" })
  end)

  it("refreshes the profile when the player's specialization changes", function()
    local ns, environment, calls = LoadBootstrap()
    ns.Profiles.active = {}
    environment.__fireEvent("PLAYER_SPECIALIZATION_CHANGED", "party1")
    environment.__fireEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
    environment.__fireEvent("ACTIVE_TALENT_GROUP_CHANGED")
    assertEquals(calls, { "Profiles:Refresh", "Profiles:Refresh" })
  end)
end)
