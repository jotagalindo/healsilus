local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertNil = Harness.assertEquals, Harness.assertTrue, Harness.assertNil

local function LoadSerializer()
  local environment = Stubs.NewEnvironment()
  return Loader.Load(environment, {
    "Core/Init.lua", "Locales/enUS.lua", "Core/Database.lua", "Data/Druid.lua", "Core/Serializer.lua",
  })
end

describe("Serializer Base64", function()
  it("encodes the RFC 4648 test vectors", function()
    local ns = LoadSerializer()
    local vectors = { [""] = "", f = "Zg==", fo = "Zm8=", foo = "Zm9v", foob = "Zm9vYg==", fooba = "Zm9vYmE=", foobar = "Zm9vYmFy" }
    for plain, encoded in pairs(vectors) do
      assertEquals(ns.Serializer.EncodeBase64(plain), encoded)
      assertEquals(ns.Serializer.DecodeBase64(encoded), plain)
    end
  end)

  it("round-trips every byte value", function()
    local ns = LoadSerializer()
    local bytes = {}
    for code = 0, 255 do
      bytes[#bytes + 1] = string.char(code)
    end
    local data = table.concat(bytes)
    assertEquals(ns.Serializer.DecodeBase64(ns.Serializer.EncodeBase64(data)), data)
  end)

  it("rejects invalid characters, lengths and padding", function()
    local ns = LoadSerializer()
    assertNil(ns.Serializer.DecodeBase64("Zm9*"))
    assertNil(ns.Serializer.DecodeBase64("Zm9"))
    assertNil(ns.Serializer.DecodeBase64("Z=9v"))
    assertNil(ns.Serializer.DecodeBase64("Zg==Zm9v"))
  end)
end)

describe("Serializer profiles", function()
  it("round-trips the druid profile exactly", function()
    local ns = LoadSerializer()
    local profile = ns.Database.NormalizeProfile(ns.ClassDefaults.DRUID(), {})
    local text = ns.Serializer.Export(profile)
    assertEquals(string.sub(text, 1, 4), "HS1:")
    local imported = ns.Serializer.Import(text)
    assertEquals(imported, profile)
  end)

  it("exports deterministically and keeps decimals", function()
    local ns = LoadSerializer()
    local profile = ns.Database.NormalizeProfile({ frames = { outOfRangeAlpha = 0.35 } }, {})
    assertEquals(ns.Serializer.Export(profile), ns.Serializer.Export(ns.DeepCopy(profile)))
    assertEquals(ns.Serializer.Import(ns.Serializer.Export(profile)).frames.outOfRangeAlpha, 0.35)
  end)

  it("ignores whitespace and line breaks pasted with the text", function()
    local ns = LoadSerializer()
    local text = ns.Serializer.Export(ns.Database.DefaultProfile())
    local spaced = string.sub(text, 1, 10) .. "\n  " .. string.sub(text, 11)
    assertTrue(ns.Serializer.Import(spaced) ~= nil)
  end)

  it("rejects text that is not a Healsilus profile", function()
    local ns = LoadSerializer()
    local cases = {
      { "", "empty" },
      { "hello", "not a Healsilus profile" },
      { "HS1:****", "corrupted text" },
      { "HS1:" .. ns.Serializer.EncodeBase64("s5:ab"), "corrupted data" },
      { "HS1:" .. ns.Serializer.EncodeBase64("{}t"), "trailing data" },
    }
    for _, case in ipairs(cases) do
      local profile, failure = ns.Serializer.Import(case[1])
      assertNil(profile, case[2])
      assertTrue(string.find(failure, case[2], 1, true) ~= nil, "expected '" .. case[2] .. "', got '" .. tostring(failure) .. "'")
    end
  end)

  it("names the offending field of an invalid profile", function()
    local ns = LoadSerializer()
    local bad = ns.Database.DefaultProfile()
    bad.bindings["1"] = { kind = "spell", spellID = 774, script = "/run" }
    local profile, failure = ns.Serializer.Import(ns.Serializer.Export(bad))
    assertNil(profile)
    assertEquals(failure, "invalid field: bindings.1")
  end)

  it("refuses values it cannot represent", function()
    local ns = LoadSerializer()
    Harness.assertError(function()
      ns.Serializer.Export({ callback = function() end })
    end, "unsupported value type")
    Harness.assertError(function()
      ns.Serializer.Export({ value = math.huge })
    end, "non%-finite")
  end)

  it("limits nesting depth on import", function()
    local ns = LoadSerializer()
    local deep = string.rep("{s1:a", 30) .. string.rep("}", 30)
    local profile, failure = ns.Serializer.Import("HS1:" .. ns.Serializer.EncodeBase64(deep))
    assertNil(profile)
    assertTrue(string.find(failure, "too deep", 1, true) ~= nil)
  end)
end)
