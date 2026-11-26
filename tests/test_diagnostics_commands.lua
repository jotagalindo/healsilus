local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue = Harness.assertEquals, Harness.assertTrue

local FILES = {
  "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/CombatQueue.lua", "Core/Database.lua",
  "Data/Spells.lua", "Data/Druid.lua", "Core/Diagnostics.lua", "Core/Commands.lua",
}

local KNOWN = {
  [5185] = { name = "Toque de sanación" }, [774] = { name = "Rejuvenecimiento" }, [8936] = { name = "Recrecimiento" },
  [2782] = { name = "Quitar maldición" }, [2893] = { name = "Suprimir veneno" }, [8946] = { name = "Curar envenenamiento" },
  [20484] = { name = "Renacer" }, [1126] = { name = "Marca de lo Salvaje" }, [21849] = { name = "Don de lo Salvaje" },
}

local function LoadTools()
  local environment = Stubs.NewEnvironment({ spells = KNOWN })
  environment.SlashCmdList = {}
  environment.HealsilusDB = { debug = false, minimap = { angle = 225, hide = false } }
  local ns = Loader.Load(environment, FILES)
  local calls = {}
  ns.Profiles = { active = ns.Database.NormalizeProfile(ns.ClassDefaults.DRUID(), {}), source = "class" }
  ns.Config = {
    Toggle = function()
      calls[#calls + 1] = "toggle"
    end,
  }
  ns.Preview = {
    Show = function(_, count)
      calls[#calls + 1] = "preview:" .. count
    end,
    Hide = function()
      calls[#calls + 1] = "preview:hide"
    end,
  }
  return ns, environment, calls
end

describe("Diagnostics", function()
  it("lists spell IDs used by the profile that the client cannot resolve", function()
    local ns = LoadTools()
    assertEquals(ns.Diagnostics.UnresolvedSpells(ns.Profiles.active), { "467" })
  end)

  it("prints the client header first and the error summary last", function()
    local ns, environment = LoadTools()
    environment.GetBuildInfo = function()
      return "1.60.1", "71139", "Nov 2026", 16001
    end
    ns.Containers = {
      IsSupported = function()
        return true
      end,
    }
    ns.UnitButton = { alphaFromBooleanWorks = false }
    ns.Headers = { list = {} }
    ns.Diagnostics:Run()
    local printed = environment.__state.printed
    assertTrue(string.find(printed[1], "Interface 16001", 1, true) ~= nil)
    assertTrue(string.find(printed[#printed], "No errors recorded.", 1, true) ~= nil)
  end)
end)

describe("Commands", function()
  it("registers /hs and /healsilus", function()
    local _, environment = LoadTools()
    assertEquals(environment.SLASH_HEALSILUS1, "/hs")
    assertEquals(environment.SLASH_HEALSILUS2, "/healsilus")
    assertTrue(type(environment.SlashCmdList.HEALSILUS) == "function")
  end)

  it("opens the settings with no argument and runs diag", function()
    local ns, environment, calls = LoadTools()
    local ran = false
    ns.Diagnostics.Run = function()
      ran = true
    end
    environment.SlashCmdList.HEALSILUS("")
    environment.SlashCmdList.HEALSILUS("  CONFIG ")
    environment.SlashCmdList.HEALSILUS("diag")
    assertEquals(calls, { "toggle", "toggle" })
    assertTrue(ran)
  end)

  it("toggles debug output and frame locking", function()
    local ns, environment = LoadTools()
    local sections = {}
    ns.Events:Register("SETTINGS_CHANGED", function(section)
      sections[#sections + 1] = section
    end)
    environment.SlashCmdList.HEALSILUS("debug")
    assertTrue(environment.HealsilusDB.debug)
    environment.SlashCmdList.HEALSILUS("lock")
    assertEquals(ns.Profiles.active.frames.locked, false)
    assertEquals(sections, { "frames" })
  end)

  it("opens the preview with a clamped size and hides it without a size", function()
    local _, environment, calls = LoadTools()
    environment.SlashCmdList.HEALSILUS("preview 10")
    environment.SlashCmdList.HEALSILUS("preview 99")
    environment.SlashCmdList.HEALSILUS("preview")
    assertEquals(calls, { "preview:10", "preview:40", "preview:hide" })
  end)

  it("toggles the minimap button", function()
    local ns, environment = LoadTools()
    local requested = {}
    ns.MinimapButton = {
      SetHidden = function(_, hidden)
        requested[#requested + 1] = hidden
        environment.HealsilusDB.minimap.hide = hidden
      end,
    }
    environment.SlashCmdList.HEALSILUS("minimap")
    environment.SlashCmdList.HEALSILUS("minimap")
    assertEquals(requested, { true, false })
  end)

  it("prints the help for unknown commands", function()
    local _, environment = LoadTools()
    environment.SlashCmdList.HEALSILUS("bogus")
    assertTrue(string.find(environment.__state.printed[1], "/hs diag", 1, true) ~= nil)
  end)
end)
