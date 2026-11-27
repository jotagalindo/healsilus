-- Comprobaciones estáticas del addon: luajit tools/check.lua (desde la raíz del repositorio).
-- 1) TOC y ficheros, 2) sintaxis, 3) globales, 4) patrones prohibidos y abreviaturas,
-- 5) traducciones (paridad y claves usadas), 6) lista de pruebas de tests/run.lua.
local interpreter = (arg and arg[-1]) or "luajit"
local problems = {}

local function Problem(message)
  problems[#problems + 1] = message
end

local function ReadFile(path)
  local handle = io.open(path, "rb")
  if not handle then
    return nil
  end
  local content = handle:read("*a")
  handle:close()
  return content
end

local function ListRepositoryFiles()
  local handle = io.popen("git ls-files --cached --others --exclude-standard")
  local files = {}
  for line in handle:lines() do
    if ReadFile(line) then
      files[#files + 1] = line
    end
  end
  handle:close()
  return files
end

local ADDON_FOLDERS = { "Core/", "Data/", "Frames/", "Auras/", "UI/", "Locales/" }

local function IsAddonFile(path)
  if not string.match(path, "%.lua$") then
    return false
  end
  for _, folder in ipairs(ADDON_FOLDERS) do
    if string.sub(path, 1, #folder) == folder then
      return true
    end
  end
  return false
end

local repositoryFiles = ListRepositoryFiles()

-- 1) TOC
local tocText = ReadFile("Healsilus.toc")
if not tocText then
  Problem("Healsilus.toc not found")
  tocText = ""
end
if not string.find(tocText, "## Interface: 16001", 1, true) then
  Problem("Healsilus.toc must declare ## Interface: 16001")
end
local tocSet = {}
for line in string.gmatch(tocText, "[^\r\n]+") do
  local trimmed = string.match(line, "^%s*(.-)%s*$")
  if trimmed ~= "" and string.sub(trimmed, 1, 1) ~= "#" then
    local normalized = string.gsub(trimmed, "\\", "/")
    if tocSet[normalized] then
      Problem("TOC lists a file twice: " .. normalized)
    end
    tocSet[normalized] = true
    if not ReadFile(normalized) then
      Problem("TOC lists a missing file: " .. normalized)
    end
  end
end
local addonFiles = {}
for _, path in ipairs(repositoryFiles) do
  if IsAddonFile(path) then
    addonFiles[#addonFiles + 1] = path
    if not tocSet[path] then
      Problem("file not listed in Healsilus.toc: " .. path)
    end
  end
end

-- 2) Sintaxis de todo el Lua del repositorio
local luaFiles = {}
for _, path in ipairs(repositoryFiles) do
  if string.match(path, "%.lua$") then
    luaFiles[#luaFiles + 1] = path
    local chunk, loadError = loadfile(path)
    if not chunk then
      Problem("syntax error: " .. tostring(loadError))
    end
  end
end

-- 3) Globales escritas por el addon (instrucción GSET del bytecode de LuaJIT)
-- Las tres funciones Healsilus_OnAddonCompartment* las busca el cliente por nombre (líneas AddonCompartmentFunc del TOC).
local ALLOWED_GLOBALS = {
  Healsilus = true, HealsilusDB = true, SLASH_HEALSILUS1 = true, SLASH_HEALSILUS2 = true,
  Healsilus_OnAddonCompartmentClick = true, Healsilus_OnAddonCompartmentEnter = true,
  Healsilus_OnAddonCompartmentLeave = true,
}
for _, path in ipairs(addonFiles) do
  local handle = io.popen(interpreter .. ' -bl "' .. path .. '"')
  local listing = handle:read("*a")
  handle:close()
  for name in string.gmatch(listing, 'GSET[^\n]-; "([^"]+)"') do
    if not ALLOWED_GLOBALS[name] then
      Problem(path .. ": writes global '" .. name .. "'")
    end
  end
end

-- 4) Patrones prohibidos en el addon y abreviaturas en todo el Lua
local FORBIDDEN = {
  { text = "COMBAT_LOG_EVENT", reason = "combat log events are blocked for addons" },
  { text = "loadstring", reason = "imported text must never be executed" },
  { text = "RunScript", reason = "arbitrary text must never be executed" },
  { text = "setfenv", reason = "no environment tricks in addon code" },
}
for _, path in ipairs(addonFiles) do
  local content = ReadFile(path)
  for _, rule in ipairs(FORBIDDEN) do
    if string.find(content, rule.text, 1, true) then
      Problem(path .. ": uses " .. rule.text .. " (" .. rule.reason .. ")")
    end
  end
end
-- Este fichero se excluye porque contiene la propia lista de nombres prohibidos.
local BANNED_NAMES = { "buf", "len", "cnt", "tmp", "val", "idx" }
for _, path in ipairs(luaFiles) do
  if path ~= "tools/check.lua" then
    local content = ReadFile(path)
    for _, name in ipairs(BANNED_NAMES) do
      if string.find(content, "%f[%w_]" .. name .. "%f[^%w_]") then
        Problem(path .. ": abbreviated identifier '" .. name .. "'")
      end
    end
  end
end

-- 5) Traducciones
local function LoadLocale(path, locale)
  local chunk = loadfile(path)
  if not chunk then
    return nil
  end
  local ns = { L = {} }
  setfenv(chunk, {
    GetLocale = function()
      return locale
    end,
  })
  chunk("Healsilus", ns)
  return ns.L
end
local english = LoadLocale("Locales/enUS.lua", "enUS") or {}
local spanish = LoadLocale("Locales/esES.lua", "esES") or {}
for key in pairs(english) do
  if spanish[key] == nil then
    Problem("Locales/esES.lua is missing key " .. key)
  end
end
for key in pairs(spanish) do
  if english[key] == nil then
    Problem("Locales/enUS.lua is missing key " .. key)
  end
end
for _, path in ipairs(addonFiles) do
  if string.sub(path, 1, 8) ~= "Locales/" then
    local content = ReadFile(path)
    for key in string.gmatch(content, "%f[%w_]L%.([%a_][%w_]*)") do
      if english[key] == nil then
        Problem(path .. ": uses undefined translation L." .. key)
      end
    end
  end
end

-- 6) Lista de pruebas
local runText = ReadFile("tests/run.lua") or ""
local listed = {}
for path in string.gmatch(runText, '"(tests/test_[%w_]+%.lua)"') do
  listed[path] = true
  if not ReadFile(path) then
    Problem("tests/run.lua lists a missing file: " .. path)
  end
end
for _, path in ipairs(repositoryFiles) do
  if string.match(path, "^tests/test_[%w_]+%.lua$") and not listed[path] then
    Problem("test file not listed in tests/run.lua: " .. path)
  end
end

if #problems > 0 then
  for _, message in ipairs(problems) do
    io.stderr:write("check: " .. message .. "\n")
  end
  print(string.format("check: %d problem(s)", #problems))
  os.exit(1)
end
print(string.format("check: OK (%d addon files, %d Lua files)", #addonFiles, #luaFiles))
