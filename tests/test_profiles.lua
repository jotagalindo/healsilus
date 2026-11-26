local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertFalse = Harness.assertEquals, Harness.assertTrue, Harness.assertFalse

local FILES = {
  "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/Database.lua",
  "Data/Spells.lua", "Data/Druid.lua", "Core/Profiles.lua",
}

local function LoadProfiles(classToken)
  local environment = Stubs.NewEnvironment({ classToken = classToken })
  local ns = Loader.Load(environment, FILES)
  local db = ns.Database:Initialize()
  return ns, environment, db
end

describe("Profiles.Resolve", function()
  it("creates and stores the druid class profile the first time", function()
    local ns, _, db = LoadProfiles()
    local profile, source = ns.Profiles.Resolve(db, "Arsilus-Bah", "DRUID", 1)
    assertEquals(source, "class")
    assertEquals(profile.bindings["2"], { kind = "spell", spellID = 774 })
    assertTrue(db.classProfiles.DRUID == profile)
    local again = ns.Profiles.Resolve(db, "Arsilus-Bah", "DRUID", 1)
    assertTrue(again == profile)
  end)

  it("gives classes without built-in defaults an empty click table", function()
    local ns, _, db = LoadProfiles("PRIEST")
    local profile = ns.Profiles.Resolve(db, "Sacer-Bah", "PRIEST", 1)
    assertEquals(profile.bindings, {})
    assertEquals(profile.frames.width, 110)
  end)

  it("uses the character profile only when the class profile is switched off", function()
    local ns, _, db = LoadProfiles()
    local own = ns.Database.NormalizeProfile({}, {})
    db.characters["Arsilus-Bah"] = { class = "DRUID", useClassProfile = true, useSpecProfiles = false, specs = {}, own = own }
    local _, source = ns.Profiles.Resolve(db, "Arsilus-Bah", "DRUID", 1)
    assertEquals(source, "class")
    db.characters["Arsilus-Bah"].useClassProfile = false
    local profile
    profile, source = ns.Profiles.Resolve(db, "Arsilus-Bah", "DRUID", 1)
    assertEquals(source, "character")
    assertTrue(profile == own)
  end)

  it("uses a spec profile only when enabled and present for that spec", function()
    local ns, _, db = LoadProfiles()
    local second = ns.Database.NormalizeProfile({}, {})
    db.characters["Arsilus-Bah"] = { class = "DRUID", useClassProfile = true, useSpecProfiles = true, specs = { [2] = second } }
    local _, source = ns.Profiles.Resolve(db, "Arsilus-Bah", "DRUID", 1)
    assertEquals(source, "class")
    local profile
    profile, source = ns.Profiles.Resolve(db, "Arsilus-Bah", "DRUID", 2)
    assertEquals(source, "spec")
    assertTrue(profile == second)
    db.characters["Arsilus-Bah"].useSpecProfiles = false
    _, source = ns.Profiles.Resolve(db, "Arsilus-Bah", "DRUID", 2)
    assertEquals(source, "class")
  end)
end)

describe("Profiles state", function()
  it("creates the character record on initialize and announces the profile", function()
    local ns, _, db = LoadProfiles()
    local announced = {}
    ns.Events:Register("PROFILE_CHANGED", function(profile, source)
      announced[#announced + 1] = source
    end)
    ns.Profiles:Initialize()
    assertEquals(db.characters["Arsilus-Bah"].class, "DRUID")
    assertTrue(db.characters["Arsilus-Bah"].useClassProfile)
    assertEquals(announced, { "class" })
    assertTrue(ns.Profiles.active == db.classProfiles.DRUID)
  end)

  it("only announces when the active profile changes", function()
    local ns, environment, db = LoadProfiles()
    ns.Profiles:Initialize()
    local count = 0
    ns.Events:Register("PROFILE_CHANGED", function()
      count = count + 1
    end)
    ns.Profiles:Refresh()
    assertEquals(count, 0)
    ns.Profiles:SetUseSpecProfiles(true)
    assertEquals(count, 1)
    environment.__state.specGroup = 2
    ns.Profiles:Refresh()
    assertEquals(count, 2, "spec 2 has no profile yet, so the class profile becomes active")
    assertEquals(ns.Profiles.source, "class")
    db.characters["Arsilus-Bah"].specs[2] = ns.Database.NormalizeProfile({}, {})
    ns.Profiles:Refresh()
    assertEquals(count, 3)
    assertEquals(ns.Profiles.source, "spec")
  end)

  it("copies the class profile when switching to a character profile", function()
    local ns, _, db = LoadProfiles()
    ns.Profiles:Initialize()
    ns.Profiles.active.frames.width = 77
    ns.Profiles:SetUseClassProfile(false)
    local character = db.characters["Arsilus-Bah"]
    assertEquals(ns.Profiles.source, "character")
    assertEquals(character.own.frames.width, 77)
    assertFalse(character.own == db.classProfiles.DRUID)
  end)

  it("copies the active profile into the current spec when spec profiles are enabled", function()
    local ns, _, db = LoadProfiles()
    ns.Profiles:Initialize()
    ns.Profiles.active.frames.height = 50
    ns.Profiles:SetUseSpecProfiles(true)
    local character = db.characters["Arsilus-Bah"]
    assertEquals(ns.Profiles.source, "spec")
    assertEquals(character.specs[1].frames.height, 50)
    assertFalse(character.specs[1] == db.classProfiles.DRUID)
  end)

  it("replaces the profile stored in the active slot", function()
    local ns, _, db = LoadProfiles()
    ns.Profiles:Initialize()
    local replacement = ns.Database.NormalizeProfile({ frames = { width = 60 } }, {})
    ns.Profiles:ReplaceActive(replacement)
    assertTrue(db.classProfiles.DRUID == replacement)
    ns.Profiles:SetUseClassProfile(false)
    local own = ns.Database.NormalizeProfile({ frames = { width = 61 } }, {})
    ns.Profiles:ReplaceActive(own)
    assertTrue(db.characters["Arsilus-Bah"].own == own)
    assertEquals(db.classProfiles.DRUID.frames.width, 60)
  end)

  it("resets the active profile to the class defaults", function()
    local ns, _, db = LoadProfiles()
    ns.Profiles:Initialize()
    ns.Profiles.active.frames.width = 200
    ns.Profiles.active.bindings = {}
    ns.Profiles:ResetActive()
    assertEquals(db.classProfiles.DRUID.frames.width, 110)
    assertEquals(db.classProfiles.DRUID.bindings["1"], { kind = "spell", spellID = 5185 })
  end)

  it("deep-copies another profile into the active slot", function()
    local ns, _, db = LoadProfiles()
    ns.Profiles:Initialize()
    local source = ns.Database.NormalizeProfile({ frames = { width = 99 } }, {})
    ns.Profiles:CopyFrom(source)
    assertEquals(db.classProfiles.DRUID.frames.width, 99)
    assertFalse(db.classProfiles.DRUID == source)
  end)

  it("lists every other stored profile as a copy source, sorted", function()
    local ns, _, db = LoadProfiles()
    ns.Profiles:Initialize()
    db.classProfiles.PRIEST = ns.Database.NormalizeProfile({}, {})
    db.characters["Otro-Bah"] = {
      class = "DRUID", useClassProfile = false, useSpecProfiles = true,
      own = ns.Database.NormalizeProfile({}, {}), specs = { [1] = ns.Database.NormalizeProfile({}, {}) },
    }
    local kinds = {}
    for _, source in ipairs(ns.Profiles:ListCopySources()) do
      kinds[#kinds + 1] = source.kind .. ":" .. (source.classToken or source.characterKey)
    end
    assertEquals(kinds, { "character:Otro-Bah", "class:PRIEST", "spec:Otro-Bah" })
  end)

  it("reads the active spec group from whichever API exists", function()
    local ns, environment = LoadProfiles()
    assertEquals(ns.Profiles.ActiveSpecGroup(), 1)
    environment.C_SpecializationInfo = nil
    environment.GetActiveTalentGroup = function()
      return 2
    end
    assertEquals(ns.Profiles.ActiveSpecGroup(), 2)
    environment.GetActiveTalentGroup = nil
    assertEquals(ns.Profiles.ActiveSpecGroup(), 1)
  end)
end)
