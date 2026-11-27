local Harness = require("harness")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue = Harness.assertEquals, Harness.assertTrue

-- tools/package.sh necesita sh, zip y unzip (los trae la imagen de tools/Dockerfile). Sin ellos (p. ej. LuaJIT
-- solo en Windows) estas pruebas no hacen nada.
local function Run(command)
  local handle = io.popen(command .. " 2>&1; echo \"exit:$?\"")
  local output = handle:read("*a")
  handle:close()
  local status = tonumber(string.match(output, "exit:(%d+)%s*$"))
  return status, (string.gsub(output, "exit:%d+%s*$", ""))
end

local function ToolsAvailable()
  local status = Run("command -v sh && command -v zip && command -v unzip")
  return status == 0
end

local function TocVersion()
  local handle = assert(io.open("Healsilus.toc", "rb"))
  local version = string.match(handle:read("*a"), "## Version:%s*([^%s]+)")
  handle:close()
  return version
end

describe("tools/package.sh", function()
  it("builds Healsilus-<version>.zip with the TOC, the code and the Media folder", function()
    if not ToolsAvailable() then
      return
    end
    local status, temporary = Run("mktemp -d")
    assertEquals(status, 0)
    temporary = string.match(temporary, "^%s*(.-)%s*$")
    local version = TocVersion()
    local built, output = Run("DIST_DIRECTORY=" .. temporary .. " sh tools/package.sh v" .. version)
    assertEquals(built, 0, output)
    local archive = temporary .. "/Healsilus-" .. version .. ".zip"
    local _, listing = Run("unzip -Z1 " .. archive)
    for _, expected in ipairs({ "Healsilus/Healsilus.toc", "Healsilus/README.md", "Healsilus/Core/Init.lua",
      "Healsilus/Core/BarLayouts.lua", "Healsilus/Media/Logo.tga", "Healsilus/Media/Icons/clicks.tga" }) do
      assertTrue(string.find(listing, expected, 1, true) ~= nil, expected)
    end
    assertTrue(string.find(listing, "Healsilus/tests/", 1, true) == nil, "no tests in the package")
    assertTrue(string.find(listing, "Healsilus/tools/", 1, true) == nil, "no tools in the package")
    Run("rm -rf " .. temporary)
  end)

  it("refuses a tag that does not match the TOC version", function()
    if not ToolsAvailable() then
      return
    end
    local status, output = Run("DIST_DIRECTORY=dist/mismatch-check sh tools/package.sh v99.0.0")
    assertTrue(status ~= 0)
    assertTrue(string.find(output, "does not match the TOC version", 1, true) ~= nil, output)
  end)
end)
