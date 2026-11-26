# Healsilus v1 — plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Addon de marcos de curación con click-casting (estilo HealBot) para WoW Forever (`## Interface: 16001`) que funciona con las restricciones de valores secretos.

**Architecture:** Lua 5.1 sin librerías externas. La lógica pura (perfiles, base de datos, asignaciones → atributos, serializador, buffs que faltan) se prueba offline con LuaJIT y stubs de la API. La parte visual usa solo vías permitidas con secretos: `SecureGroupHeaderTemplate` + `SecureActionButtonTemplate` para marcos y clics, `StatusBar:SetValue` con secretos, curvas `C_CurveUtil`, el calculador nativo de predicción y `AuraContainer` para auras. Todo cambio seguro pasa por una cola de combate.

**Tech Stack:** Lua 5.1 (WoW), LuaJIT 2.1 para pruebas y checks (`luajit tests/run.lua`, `luajit tools/check.lua`), PowerShell para enlazar el addon al cliente.

**Spec:** [docs/superpowers/specs/2026-11-26-healsilus-design.md](../specs/2026-11-26-healsilus-design.md)

---

## Convenciones obligatorias (léelas antes de cada tarea)

1. **Valores secretos**: nunca compares, operes, indexes, uses como clave ni concatenes en Lua puro un valor que pueda ser secreto, salvo para pasarlo a una API que lo acepta (`SetValue`, `SetMinMaxValues`, `SetText`, `string.format`, `..`, `SetVertexColor`, curvas, `SetAlphaFromBoolean`). Para elegir ruta usa `ns.IsSecret(value)` primero.
2. **Combate**: nada de crear marcos seguros, cambiar atributos, `SetSize`/`SetPoint` de marcos protegidos, `RegisterForClicks`, ni crear o activar `AuraContainer` con `InCombatLockdown()` verdadero. Usa `ns.CombatQueue:Run(key, action)`.
3. **Estilo** (igual que Richarsilus): 2 espacios de sangría, comentario de cabecera en español en cada fichero, comentarios en español, identificadores en inglés. **Sin abreviaturas** en nombres (`buf`, `len`, `cnt`, `tmp`, `val`, `idx` están prohibidos y `tools/check.lua` los rechaza). Cada fichero empieza con `local _, ns = ...` (o `local addonName, ns = ...`).
4. **Globales**: solo `Healsilus`, `HealsilusDB`, `SLASH_HEALSILUS1`, `SLASH_HEALSILUS2`. El check lo verifica con el bytecode.
5. **Traducciones**: toda clave `L.X` usada en código debe existir en `Locales/enUS.lua` y en `Locales/esES.lua` (mismo conjunto de claves). Cuando una tarea dice "añade al final de `Locales/enUS.lua`", añade también las mismas claves al final de `Locales/esES.lua` con el texto en español que se indica.
6. **TOC**: cada fichero nuevo del addon se añade **al final** de la lista de ficheros de `Healsilus.toc`, en el orden de las tareas.
7. **Pruebas**: cada fichero `tests/test_*.lua` nuevo se añade a la lista `TEST_FILES` de `tests/run.lua`.
8. **Verificación de cada tarea** (siempre antes del commit, desde la raíz del repo):
   ```powershell
   luajit tests/run.lua
   ```
   ```powershell
   luajit tools/check.lua
   ```
   Ambos deben terminar sin fallos (`N passed, 0 failed` y `check: OK`).
9. **Errores**: nunca `pcall` sin registrar el fallo con `ns.RecordError(context, message)`.
10. **Commits**: en la rama `feat/healsilus-v1`, mensaje en inglés estilo convencional, terminando con la línea `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Mapa de ficheros

| Fichero | Responsabilidad | Tarea |
|---|---|---|
| `Healsilus.toc` | Metadatos y orden de carga | 1 (y cada tarea añade su fichero) |
| `Core/Init.lua` | `ns`, constantes de clics, `IsSecret`, `DeepCopy`, `Print`, `RecordError`, `CharacterKey`, `IsEventValid` | 1 |
| `Locales/enUS.lua`, `Locales/esES.lua` | Textos | 1 (y cada tarea añade claves) |
| `tests/lib/harness.lua`, `tests/lib/wow_stubs.lua`, `tests/lib/loader.lua`, `tests/run.lua` | Framework de pruebas offline | 1 |
| `tools/check.lua` | Checks estáticos | 1 |
| `Core/Events.lua` | Bus de eventos interno y de WoW | 2 |
| `Core/CombatQueue.lua` | Cola de acciones hasta salir de combate | 3 |
| `Core/Database.lua` | Valores por defecto, normalización, validación, migraciones | 4 |
| `Data/Spells.lua` | Nombres por ID, rangos del libro, texto de lanzamiento | 5 |
| `Data/Druid.lua` | Perfil de serie del druida | 6 |
| `Core/Profiles.lua` | Resolución spec → PJ → clase, copiar, restablecer | 7 |
| `Core/Serializer.lua` | Exportar/importar perfiles (Base64, sin `loadstring`) | 8 |
| `Frames/Media.lua`, `Frames/Curves.lua` | Texturas, colores, curvas | 9 |
| `Frames/ClickCast.lua` | Asignaciones → atributos seguros | 10 |
| `Frames/Prediction.lua` | Curación entrante y escudos | 11 |
| `Auras/Containers.lua` | `AuraContainer` de HoTs, debuffs y borde de dispel | 12 |
| `Auras/MissingBuffs.lua` | Buffs que faltan | 13 |
| `Frames/UnitButton.lua` | Visual y actualización de cada barra | 14 |
| `Frames/Headers.lua` | Cabeceras seguras, anclas, objetivo/foco, ocultar Blizzard | 15 |
| `Frames/Preview.lua` | Vista previa | 16 |
| `UI/Widgets.lua`, `UI/Config.lua` | Controles y ventana de configuración | 17 |
| `UI/TabClicks.lua` | Pestaña Clics | 18 |
| `UI/TabFrames.lua` | Pestaña Marcos | 19 |
| `UI/TabAuras.lua`, `UI/TabBuffs.lua` | Pestañas Auras y Buffs | 20 |
| `UI/TabProfiles.lua` | Pestaña Perfiles | 21 |
| `Core/Diagnostics.lua`, `Core/Commands.lua` | `/hs diag` y comandos | 22 |
| `Core/Bootstrap.lua` | Arranque | 23 |
| `tools/link-addon.ps1`, `docs/testing/in-game-checklist.md`, `README.md` | Instalación de desarrollo y pruebas en el juego | 24 |

---

### Task 1: Andamiaje, framework de pruebas y checks

**Files:**
- Create: `.gitattributes`, `Healsilus.toc`, `Core/Init.lua`, `Locales/enUS.lua`, `Locales/esES.lua`
- Create: `tests/lib/harness.lua`, `tests/lib/wow_stubs.lua`, `tests/lib/loader.lua`, `tests/run.lua`, `tests/test_init.lua`
- Create: `tools/check.lua`

- [ ] **Step 1: Crea `.gitattributes`**

```
* text=auto
*.lua text eol=lf
*.toc text eol=lf
*.md text eol=lf
*.ps1 text eol=crlf
```

- [ ] **Step 2: Crea `tests/lib/harness.lua`**

```lua
-- Mini framework de pruebas: describe/it y aserciones. Sin dependencias externas.
local Harness = { passed = 0, failed = 0, failures = {}, suite = "" }

local function Describe(value)
  if type(value) == "string" then
    return string.format("%q", value)
  end
  if type(value) ~= "table" then
    return tostring(value)
  end
  local keys = {}
  for key in pairs(value) do
    keys[#keys + 1] = key
  end
  table.sort(keys, function(left, right)
    return tostring(left) < tostring(right)
  end)
  local parts = {}
  for _, key in ipairs(keys) do
    parts[#parts + 1] = tostring(key) .. "=" .. Describe(value[key])
  end
  return "{" .. table.concat(parts, ", ") .. "}"
end
Harness.Describe = Describe

function Harness.DeepEqual(left, right)
  if type(left) ~= type(right) then
    return false
  end
  if type(left) ~= "table" then
    return left == right
  end
  for key, value in pairs(left) do
    if not Harness.DeepEqual(value, right[key]) then
      return false
    end
  end
  for key in pairs(right) do
    if left[key] == nil then
      return false
    end
  end
  return true
end

function Harness.describe(name, body)
  local previous = Harness.suite
  Harness.suite = previous == "" and name or (previous .. " > " .. name)
  body()
  Harness.suite = previous
end

function Harness.it(name, body)
  local ok, failure = xpcall(body, debug.traceback)
  if ok then
    Harness.passed = Harness.passed + 1
  else
    Harness.failed = Harness.failed + 1
    Harness.failures[#Harness.failures + 1] = Harness.suite .. " > " .. name .. "\n" .. tostring(failure)
  end
end

function Harness.assertEquals(actual, expected, message)
  if not Harness.DeepEqual(actual, expected) then
    error((message or "values differ") .. "\n  expected: " .. Describe(expected) .. "\n  actual:   " .. Describe(actual), 2)
  end
end

function Harness.assertTrue(value, message)
  if value ~= true then
    error((message or "expected true") .. ", got " .. Describe(value), 2)
  end
end

function Harness.assertFalse(value, message)
  if value ~= false then
    error((message or "expected false") .. ", got " .. Describe(value), 2)
  end
end

function Harness.assertNil(value, message)
  if value ~= nil then
    error((message or "expected nil") .. ", got " .. Describe(value), 2)
  end
end

function Harness.assertError(body, pattern, message)
  local ok, failure = pcall(body)
  if ok then
    error((message or "expected an error") .. " (none raised)", 2)
  end
  if pattern and not string.find(tostring(failure), pattern) then
    error((message or "error text mismatch") .. "\n  pattern: " .. pattern .. "\n  error:   " .. tostring(failure), 2)
  end
end

function Harness.Report()
  for _, failure in ipairs(Harness.failures) do
    io.stderr:write("FAIL: " .. failure .. "\n\n")
  end
  print(string.format("%d passed, %d failed", Harness.passed, Harness.failed))
  return Harness.failed == 0
end

return Harness
```

- [ ] **Step 3: Crea `tests/lib/wow_stubs.lua`**

```lua
-- Entorno falso de WoW para las pruebas: solo lo que usa la lógica del addon.
-- Los secretos falsos lanzan error si se operan, comparan o indexan, como en el cliente real.
local Stubs = {}

local SecretMeta = {}
local function Forbidden()
  error("secret value misuse", 2)
end
for _, event in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm", "__concat",
  "__len", "__lt", "__le", "__eq", "__call", "__index", "__newindex" }) do
  SecretMeta[event] = Forbidden
end

function Stubs.MakeSecret()
  return setmetatable({}, SecretMeta)
end

function Stubs.IsSecret(value)
  return type(value) == "table" and getmetatable(value) == SecretMeta
end

-- Objeto permisivo: cualquier método existe y devuelve otro objeto permisivo.
local MockMeta = {}
MockMeta.__index = function(mock, key)
  local method = function()
    return Stubs.NewMock()
  end
  rawset(mock, key, method)
  return method
end
MockMeta.__call = function()
  return Stubs.NewMock()
end

function Stubs.NewMock()
  return setmetatable({}, MockMeta)
end

local FrameFallback = {
  __index = function()
    return function()
      return nil
    end
  end,
}

local function NewFrame(state, frameType, name, parent)
  local frame = {
    frameType = frameType, name = name, parent = parent, events = {}, scripts = {},
    attributes = {}, shown = true, alpha = 1,
  }
  function frame:RegisterEvent(event)
    self.events[event] = true
  end
  function frame:RegisterUnitEvent(event, ...)
    self.events[event] = { ... }
  end
  function frame:UnregisterEvent(event)
    self.events[event] = nil
  end
  function frame:UnregisterAllEvents()
    self.events = {}
  end
  function frame:SetScript(kind, handler)
    self.scripts[kind] = handler
  end
  function frame:GetScript(kind)
    return self.scripts[kind]
  end
  function frame:HookScript(kind, handler)
    local previous = self.scripts[kind]
    self.scripts[kind] = function(...)
      if previous then
        previous(...)
      end
      handler(...)
    end
  end
  function frame:SetAttribute(key, value)
    self.attributes[key] = value
  end
  function frame:GetAttribute(key)
    return self.attributes[key]
  end
  function frame:Show()
    self.shown = true
  end
  function frame:Hide()
    self.shown = false
  end
  function frame:SetShown(shown)
    self.shown = shown and true or false
  end
  function frame:IsShown()
    return self.shown
  end
  function frame:SetAlpha(alpha)
    self.alpha = alpha
  end
  function frame:GetAlpha()
    return self.alpha
  end
  function frame:GetName()
    return self.name
  end
  state.frames[#state.frames + 1] = frame
  if name then
    state.environment[name] = frame
  end
  return setmetatable(frame, FrameFallback)
end

local STANDARD_GLOBALS = {
  "assert", "error", "ipairs", "next", "pairs", "pcall", "select", "tonumber", "tostring", "type",
  "unpack", "xpcall", "setmetatable", "getmetatable", "rawget", "rawset", "rawequal",
  "string", "table", "math",
}

-- options: locale, classToken, spells ({[id] = {name=, icon=}}), spellbook ({ {spellID=, name=, subName=} }), permissive
function Stubs.NewEnvironment(options)
  options = options or {}
  local environment = {}
  local state = {
    inCombat = false, locale = options.locale or "enUS", playerName = "Arsilus", realm = "Bah",
    classToken = options.classToken or "DRUID", specGroup = 1, spells = options.spells or {},
    spellbook = options.spellbook or {}, printed = {}, frames = {}, timers = {}, environment = environment,
  }
  for _, name in ipairs(STANDARD_GLOBALS) do
    environment[name] = _G[name]
  end
  environment._G = environment
  environment.print = function(...)
    local parts = {}
    for position = 1, select("#", ...) do
      parts[position] = tostring((select(position, ...)))
    end
    state.printed[#state.printed + 1] = table.concat(parts, " ")
  end
  environment.wipe = function(target)
    for key in pairs(target) do
      target[key] = nil
    end
    return target
  end
  environment.tinsert = table.insert
  environment.tremove = table.remove
  environment.strtrim = function(text)
    return (string.gsub(text, "^%s*(.-)%s*$", "%1"))
  end
  environment.GetLocale = function()
    return state.locale
  end
  environment.InCombatLockdown = function()
    return state.inCombat
  end
  environment.UnitName = function(unit)
    if unit == "player" then
      return state.playerName
    end
    return nil
  end
  environment.GetRealmName = function()
    return state.realm
  end
  environment.GetNormalizedRealmName = function()
    return state.realm
  end
  environment.UnitClass = function(unit)
    if unit == "player" then
      return "Druid", state.classToken, 11
    end
    return nil
  end
  environment.issecretvalue = Stubs.IsSecret
  environment.CreateFrame = function(frameType, name, parent)
    return NewFrame(state, frameType, name, parent)
  end
  environment.UIParent = NewFrame(state, "Frame", "UIParent")
  environment.C_Timer = {
    After = function(delay, callback)
      state.timers[#state.timers + 1] = { delay = delay, callback = callback }
    end,
  }
  environment.C_Spell = {
    GetSpellInfo = function(spellID)
      local spell = state.spells[spellID]
      if not spell then
        return nil
      end
      return { name = spell.name, spellID = spellID, iconID = spell.icon or 136041 }
    end,
  }
  environment.Enum = {
    SpellBookSpellBank = { Player = 0, Pet = 1 },
    SpellBookItemType = { Spell = 1, FutureSpell = 2, Flyout = 4 },
  }
  environment.C_SpellBook = {
    GetNumSpellBookSkillLines = function()
      return 1
    end,
    GetSpellBookSkillLineInfo = function()
      return { name = "General", itemIndexOffset = 0, numSpellBookItems = #state.spellbook }
    end,
    GetSpellBookItemInfo = function(slot)
      local entry = state.spellbook[slot]
      if not entry then
        return nil
      end
      return {
        spellID = entry.spellID, name = entry.name, subName = entry.subName or "",
        itemType = entry.itemType or 1, isPassive = entry.isPassive or false, iconID = 136041,
      }
    end,
  }
  environment.C_SpecializationInfo = {
    GetActiveSpecGroup = function()
      return state.specGroup
    end,
  }
  environment.__state = state
  environment.__fireEvent = function(event, ...)
    for _, frame in ipairs(state.frames) do
      if frame.events[event] and frame.scripts.OnEvent then
        frame.scripts.OnEvent(frame, event, ...)
      end
    end
  end
  environment.__runTimers = function()
    local timers = state.timers
    state.timers = {}
    for _, timer in ipairs(timers) do
      timer.callback()
    end
  end
  if options.permissive then
    setmetatable(environment, {
      __index = function()
        return Stubs.NewMock()
      end,
    })
  end
  return environment
end

return Stubs
```

- [ ] **Step 4: Crea `tests/lib/loader.lua`**

```lua
-- Carga ficheros del addon en un entorno falso, pasando ("Healsilus", ns) como hace el cliente.
local Loader = {}

-- rawget: en un entorno permisivo cualquier global ausente devuelve un objeto falso.
function Loader.Load(environment, files, ns)
  ns = ns or rawget(environment, "__ns") or {}
  environment.__ns = ns
  for _, path in ipairs(files) do
    local chunk, loadError = loadfile(path)
    if not chunk then
      error(loadError, 2)
    end
    setfenv(chunk, environment)
    chunk("Healsilus", ns)
  end
  return ns
end

-- Lista de ficheros del TOC con barras normales, en orden de carga.
function Loader.TocFiles(tocPath)
  local handle = assert(io.open(tocPath or "Healsilus.toc", "rb"))
  local content = handle:read("*a")
  handle:close()
  local files = {}
  for line in string.gmatch(content, "[^\r\n]+") do
    local trimmed = string.match(line, "^%s*(.-)%s*$")
    if trimmed ~= "" and string.sub(trimmed, 1, 1) ~= "#" then
      files[#files + 1] = (string.gsub(trimmed, "\\", "/"))
    end
  end
  return files
end

return Loader
```

- [ ] **Step 5: Crea `tests/run.lua`**

```lua
-- Ejecuta todas las pruebas offline: luajit tests/run.lua (desde la raíz del repositorio).
package.path = "./tests/lib/?.lua;" .. package.path
local Harness = require("harness")

local TEST_FILES = {
  "tests/test_init.lua",
}

for _, path in ipairs(TEST_FILES) do
  local chunk, loadError = loadfile(path)
  if not chunk then
    Harness.failed = Harness.failed + 1
    Harness.failures[#Harness.failures + 1] = path .. "\n" .. tostring(loadError)
  else
    Harness.describe(path, chunk)
  end
end

if not Harness.Report() then
  os.exit(1)
end
```

- [ ] **Step 6: Escribe la prueba `tests/test_init.lua`**

```lua
local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertFalse = Harness.assertEquals, Harness.assertTrue, Harness.assertFalse

local function LoadInit()
  local environment = Stubs.NewEnvironment()
  local ns = Loader.Load(environment, { "Core/Init.lua", "Locales/enUS.lua" })
  return ns, environment
end

describe("Init", function()
  it("detects fake secret values", function()
    local ns = LoadInit()
    assertTrue(ns.IsSecret(Stubs.MakeSecret()))
    assertFalse(ns.IsSecret(42))
    assertFalse(ns.IsSecret(nil))
  end)

  it("treats every value as readable when issecretvalue does not exist", function()
    local environment = Stubs.NewEnvironment()
    environment.issecretvalue = nil
    local ns = Loader.Load(environment, { "Core/Init.lua" })
    assertFalse(ns.IsSecret(Stubs.MakeSecret()))
  end)

  it("deep-copies nested tables without sharing references", function()
    local ns = LoadInit()
    local original = { frames = { width = 110 }, list = { 1, 2 } }
    local copy = ns.DeepCopy(original)
    assertEquals(copy, original)
    copy.frames.width = 50
    assertEquals(original.frames.width, 110)
    assertEquals(ns.DeepCopy(7), 7)
  end)

  it("builds the character key from name and realm", function()
    local ns = LoadInit()
    assertEquals(ns.CharacterKey(), "Arsilus-Bah")
  end)

  it("records every error and prints only the first one per context", function()
    local ns, environment = LoadInit()
    ns.RecordError("auras", "boom")
    ns.RecordError("auras", "again")
    assertEquals(#ns.Diagnostics.errors, 2)
    assertEquals(#environment.__state.printed, 1)
  end)

  it("exposes the namespace as the Healsilus global", function()
    local ns, environment = LoadInit()
    assertTrue(environment.Healsilus == ns)
  end)

  it("falls back to the key for missing translations", function()
    local ns = LoadInit()
    assertEquals(ns.L.SOME_MISSING_KEY, "SOME_MISSING_KEY")
  end)

  it("lists every modifier prefix and mouse button", function()
    local ns = LoadInit()
    assertEquals(#ns.BINDING_PREFIXES, 8)
    assertEquals(ns.MOUSE_BUTTONS, { "1", "2", "3", "4", "5" })
  end)

  it("accepts unknown events only when C_EventUtils is missing", function()
    local ns, environment = LoadInit()
    assertTrue(ns.IsEventValid("ANYTHING"))
    environment.C_EventUtils = {
      IsEventValid = function(event)
        return event == "UNIT_HEALTH"
      end,
    }
    assertTrue(ns.IsEventValid("UNIT_HEALTH"))
    assertFalse(ns.IsEventValid("FAKE_EVENT"))
  end)
end)
```

- [ ] **Step 7: Ejecuta las pruebas y comprueba que fallan**

Run: `luajit tests/run.lua`
Expected: FAIL — `cannot open Core/Init.lua` y `1 failed` o más.

- [ ] **Step 8: Crea `Core/Init.lua`**

```lua
-- Healsilus: tabla compartida del addon y utilidades seguras ante valores secretos.
-- Este fichero solo usa APIs de WoW dentro de funciones, para poder probarse fuera del juego.
local addonName, ns = ...

ns.name = addonName
ns.version = "0.1.0"

-- Único global del addon: acceso desde /run y desde los comandos de depuración.
Healsilus = ns

-- Prefijos de modificador en orden canónico (alt, ctrl, shift) y botones del ratón admitidos.
-- La clave de una asignación es prefijo .. botón: "1", "shift-1", "alt-ctrl-2"...
ns.BINDING_PREFIXES = { "", "alt-", "ctrl-", "shift-", "alt-ctrl-", "alt-shift-", "ctrl-shift-", "alt-ctrl-shift-" }
ns.MOUSE_BUTTONS = { "1", "2", "3", "4", "5" }

-- Traducciones: los ficheros de Locales rellenan esta tabla. Si falta una clave, se muestra la clave.
ns.L = setmetatable({}, {
  __index = function(_, key)
    return key
  end,
})

-- Errores y correcciones registrados para /hs diag. Nunca se tragan en silencio.
ns.Diagnostics = { errors = {}, reported = {} }

-- Solo sirve para elegir ruta de dibujo; jamás para leer el contenido de un secreto.
function ns.IsSecret(value)
  if issecretvalue then
    return issecretvalue(value) == true
  end
  return false
end

function ns.DeepCopy(value)
  if type(value) ~= "table" then
    return value
  end
  local copy = {}
  for key, entry in pairs(value) do
    copy[ns.DeepCopy(key)] = ns.DeepCopy(entry)
  end
  return copy
end

function ns.Print(message)
  print("|cff33ff99Healsilus:|r " .. tostring(message))
end

function ns.Debug(message)
  if HealsilusDB and HealsilusDB.debug then
    ns.Print("[debug] " .. tostring(message))
  end
end

-- Guarda el error con su contexto y lo muestra en el chat la primera vez que aparece ese contexto.
function ns.RecordError(context, message)
  local errors = ns.Diagnostics.errors
  errors[#errors + 1] = { context = context, message = tostring(message) }
  if not ns.Diagnostics.reported[context] then
    ns.Diagnostics.reported[context] = true
    ns.Print(string.format(ns.L.ERROR_RECORDED, context, tostring(message)))
  end
end

function ns.CharacterKey()
  local name = UnitName("player")
  local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or GetRealmName()
  return tostring(name) .. "-" .. tostring(realm)
end

-- Registrar un evento que el cliente no conoce da error: se comprueba antes cuando la API existe.
function ns.IsEventValid(event)
  if C_EventUtils and C_EventUtils.IsEventValid then
    return C_EventUtils.IsEventValid(event) == true
  end
  return true
end
```

- [ ] **Step 9: Crea `Locales/enUS.lua`**

```lua
-- Textos en inglés: se cargan siempre y sirven de respaldo para cualquier idioma.
local _, ns = ...
local L = ns.L

L.ERROR_RECORDED = "error in %s: %s (see /hs diag)"
```

- [ ] **Step 10: Crea `Locales/esES.lua`**

```lua
-- Textos en español (clientes esES y esMX).
local _, ns = ...

local locale = GetLocale()
if locale ~= "esES" and locale ~= "esMX" then
  return
end

local L = ns.L

L.ERROR_RECORDED = "error en %s: %s (consulta /hs diag)"
```

- [ ] **Step 11: Crea `Healsilus.toc`**

```
## Interface: 16001
## Title: Healsilus
## Notes: Click-casting healing frames built for WoW Forever's addon restrictions.
## Notes-esES: Marcos de curación con click-casting hechos para las restricciones de addons de WoW Forever.
## Notes-esMX: Marcos de curación con click-casting hechos para las restricciones de addons de WoW Forever.
## Author: jotagalindo
## Version: 0.1.0
## SavedVariables: HealsilusDB
## IconTexture: Interface\Icons\Spell_Nature_HealingTouch

Core\Init.lua
Locales\enUS.lua
Locales\esES.lua
```

- [ ] **Step 12: Ejecuta las pruebas y comprueba que pasan**

Run: `luajit tests/run.lua`
Expected: `9 passed, 0 failed`

- [ ] **Step 13: Crea `tools/check.lua`**

```lua
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
local ALLOWED_GLOBALS = { Healsilus = true, HealsilusDB = true, SLASH_HEALSILUS1 = true, SLASH_HEALSILUS2 = true }
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
```

- [ ] **Step 14: Ejecuta el check**

Run: `luajit tools/check.lua`
Expected: `check: OK (3 addon files, 9 Lua files)`

- [ ] **Step 15: Commit**

```powershell
git add .gitattributes Healsilus.toc Core Locales tests tools
git commit -m @'
feat: scaffold addon, offline test harness and static checks

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
'@
```

### Task 2: Bus de eventos

**Files:**
- Create: `Core/Events.lua`, `tests/test_events.lua`
- Modify: `Healsilus.toc` (añade `Core\Events.lua` al final), `tests/run.lua` (añade `"tests/test_events.lua",`)

- [ ] **Step 1: Escribe la prueba `tests/test_events.lua`**

```lua
local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertFalse = Harness.assertEquals, Harness.assertTrue, Harness.assertFalse

local function LoadEvents()
  local environment = Stubs.NewEnvironment()
  local ns = Loader.Load(environment, { "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua" })
  return ns, environment
end

describe("Events", function()
  it("delivers internal events to every callback in registration order", function()
    local ns = LoadEvents()
    local received = {}
    ns.Events:Register("PROFILE_CHANGED", function(first, second)
      received[#received + 1] = "a:" .. first .. second
    end)
    ns.Events:Register("PROFILE_CHANGED", function(first)
      received[#received + 1] = "b:" .. first
    end)
    ns.Events:Fire("PROFILE_CHANGED", "x", "y")
    assertEquals(received, { "a:xy", "b:x" })
  end)

  it("ignores internal events without listeners", function()
    local ns = LoadEvents()
    ns.Events:Fire("NOBODY_LISTENS", 1)
  end)

  it("registers each game event once and passes the event name first", function()
    local ns, environment = LoadEvents()
    local received = {}
    assertTrue(ns.Events:RegisterGameEvent("UNIT_HEALTH", function(event, unit)
      received[#received + 1] = event .. ":" .. unit
    end))
    ns.Events:RegisterGameEvent("UNIT_HEALTH", function(_, unit)
      received[#received + 1] = "second:" .. unit
    end)
    assertTrue(ns.Events.frame.events.UNIT_HEALTH)
    environment.__fireEvent("UNIT_HEALTH", "party1")
    assertEquals(received, { "UNIT_HEALTH:party1", "second:party1" })
  end)

  it("refuses events the client does not know", function()
    local ns, environment = LoadEvents()
    environment.C_EventUtils = {
      IsEventValid = function(event)
        return event ~= "FAKE_EVENT"
      end,
    }
    assertFalse(ns.Events:RegisterGameEvent("FAKE_EVENT", function() end))
    assertEquals(ns.Events.frame.events.FAKE_EVENT, nil)
  end)
end)
```

- [ ] **Step 2: Añade el fichero a `tests/run.lua` y ejecuta**

Añade `"tests/test_events.lua",` debajo de `"tests/test_init.lua",` en `TEST_FILES`.
Run: `luajit tests/run.lua`
Expected: FAIL — `cannot open Core/Events.lua`.

- [ ] **Step 3: Crea `Core/Events.lua`**

```lua
-- Bus de eventos: internos del addon (Register/Fire) y del juego (RegisterGameEvent) en un único marco.
-- Los errores de un receptor no se capturan: el cliente los muestra con su traza.
local _, ns = ...

local Events = { callbacks = {}, gameHandlers = {} }
ns.Events = Events

local eventFrame = CreateFrame("Frame")
Events.frame = eventFrame

function Events:Register(name, callback)
  local list = self.callbacks[name]
  if not list then
    list = {}
    self.callbacks[name] = list
  end
  list[#list + 1] = callback
end

function Events:Fire(name, ...)
  local list = self.callbacks[name]
  if not list then
    return
  end
  for _, callback in ipairs(list) do
    callback(...)
  end
end

-- Devuelve false si el cliente no conoce el evento (algunos de Mainline no existen en Forever).
function Events:RegisterGameEvent(event, callback)
  if not ns.IsEventValid(event) then
    return false
  end
  local list = self.gameHandlers[event]
  if not list then
    list = {}
    self.gameHandlers[event] = list
    eventFrame:RegisterEvent(event)
  end
  list[#list + 1] = callback
  return true
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
  local list = Events.gameHandlers[event]
  if not list then
    return
  end
  for _, callback in ipairs(list) do
    callback(event, ...)
  end
end)
```

- [ ] **Step 4: Añade `Core\Events.lua` al final de la lista de `Healsilus.toc`**

- [ ] **Step 5: Verifica**

Run: `luajit tests/run.lua` → Expected: `13 passed, 0 failed`
Run: `luajit tools/check.lua` → Expected: `check: OK (4 addon files, 11 Lua files)`

- [ ] **Step 6: Commit**

```powershell
git add Core/Events.lua Healsilus.toc tests
git commit -m @'
feat: add internal and game event bus

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
'@
```

### Task 3: Cola de combate

**Files:**
- Create: `Core/CombatQueue.lua`, `tests/test_combat_queue.lua`
- Modify: `Healsilus.toc` (añade `Core\CombatQueue.lua` al final), `tests/run.lua` (añade `"tests/test_combat_queue.lua",`)

- [ ] **Step 1: Escribe la prueba `tests/test_combat_queue.lua`**

```lua
local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertFalse = Harness.assertEquals, Harness.assertTrue, Harness.assertFalse

local function LoadQueue()
  local environment = Stubs.NewEnvironment()
  local ns = Loader.Load(environment, { "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/CombatQueue.lua" })
  return ns, environment
end

describe("CombatQueue", function()
  it("runs immediately outside combat", function()
    local ns = LoadQueue()
    local ran = false
    assertTrue(ns.CombatQueue:Run("layout", function()
      ran = true
    end))
    assertTrue(ran)
    assertEquals(ns.CombatQueue:Count(), 0)
  end)

  it("defers in combat, keeps the latest action per key and the first arrival order", function()
    local ns, environment = LoadQueue()
    environment.__state.inCombat = true
    local order = {}
    assertFalse(ns.CombatQueue:Run("layout", function()
      order[#order + 1] = "layout-old"
    end))
    ns.CombatQueue:Run("clicks", function()
      order[#order + 1] = "clicks"
    end)
    ns.CombatQueue:Run("layout", function()
      order[#order + 1] = "layout-new"
    end)
    assertEquals(ns.CombatQueue:Count(), 2)
    assertEquals(order, {})
    environment.__state.inCombat = false
    environment.__fireEvent("PLAYER_REGEN_ENABLED")
    assertEquals(order, { "layout-new", "clicks" })
    assertEquals(ns.CombatQueue:Count(), 0)
  end)

  it("announces queue changes and combat transitions", function()
    local ns, environment = LoadQueue()
    local counts, transitions = {}, {}
    ns.Events:Register("COMBAT_QUEUE_CHANGED", function(count)
      counts[#counts + 1] = count
    end)
    ns.Events:Register("COMBAT_STARTED", function()
      transitions[#transitions + 1] = "started"
    end)
    ns.Events:Register("COMBAT_ENDED", function()
      transitions[#transitions + 1] = "ended"
    end)
    environment.__fireEvent("PLAYER_REGEN_DISABLED")
    environment.__state.inCombat = true
    ns.CombatQueue:Run("a", function() end)
    environment.__state.inCombat = false
    environment.__fireEvent("PLAYER_REGEN_ENABLED")
    assertEquals(counts, { 1, 0 })
    assertEquals(transitions, { "started", "ended" })
  end)

  it("keeps running the remaining actions when one fails and records the failure", function()
    local ns, environment = LoadQueue()
    environment.__state.inCombat = true
    local ran = false
    ns.CombatQueue:Run("broken", function()
      error("boom")
    end)
    ns.CombatQueue:Run("fine", function()
      ran = true
    end)
    environment.__state.inCombat = false
    environment.__fireEvent("PLAYER_REGEN_ENABLED")
    assertTrue(ran)
    assertEquals(#ns.Diagnostics.errors, 1)
    assertEquals(ns.Diagnostics.errors[1].context, "CombatQueue:broken")
  end)
end)
```

- [ ] **Step 2: Añade el fichero a `tests/run.lua` y ejecuta**

Run: `luajit tests/run.lua`
Expected: FAIL — `cannot open Core/CombatQueue.lua`.

- [ ] **Step 3: Crea `Core/CombatQueue.lua`**

```lua
-- Cola de combate: todo lo que toca marcos o atributos seguros pasa por aquí.
-- Fuera de combate se ejecuta ya; en combate se guarda por clave y se ejecuta al salir.
local _, ns = ...

local CombatQueue = { pending = {}, order = {} }
ns.CombatQueue = CombatQueue

function CombatQueue:Run(key, action)
  if not InCombatLockdown() then
    action()
    return true
  end
  if not self.pending[key] then
    self.order[#self.order + 1] = key
  end
  self.pending[key] = action
  ns.Events:Fire("COMBAT_QUEUE_CHANGED", #self.order)
  return false
end

function CombatQueue:Count()
  return #self.order
end

function CombatQueue:Flush()
  local order, pending = self.order, self.pending
  self.order, self.pending = {}, {}
  for _, key in ipairs(order) do
    local ok, failure = pcall(pending[key])
    if not ok then
      ns.RecordError("CombatQueue:" .. key, failure)
    end
  end
  ns.Events:Fire("COMBAT_QUEUE_CHANGED", #self.order)
end

ns.Events:RegisterGameEvent("PLAYER_REGEN_ENABLED", function()
  CombatQueue:Flush()
  ns.Events:Fire("COMBAT_ENDED")
end)

-- Se dispara justo antes de que empiece el bloqueo: aún se pueden hacer cambios seguros.
ns.Events:RegisterGameEvent("PLAYER_REGEN_DISABLED", function()
  ns.Events:Fire("COMBAT_STARTED")
end)
```

- [ ] **Step 4: Añade `Core\CombatQueue.lua` al final de la lista de `Healsilus.toc`**

- [ ] **Step 5: Verifica**

Run: `luajit tests/run.lua` → Expected: `17 passed, 0 failed`
Run: `luajit tools/check.lua` → Expected: `check: OK (5 addon files, 13 Lua files)`

- [ ] **Step 6: Commit**

```powershell
git add Core/CombatQueue.lua Healsilus.toc tests
git commit -m @'
feat: add combat queue for secure changes

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
'@
```

### Task 4: Base de datos (valores por defecto, normalización, validación, migraciones)

**Files:**
- Create: `Core/Database.lua`, `tests/test_database.lua`
- Modify: `Healsilus.toc` (añade `Core\Database.lua` al final), `tests/run.lua` (añade `"tests/test_database.lua",`)

- [ ] **Step 1: Escribe la prueba `tests/test_database.lua`**

```lua
local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertFalse = Harness.assertEquals, Harness.assertTrue, Harness.assertFalse

local function LoadDatabase()
  local environment = Stubs.NewEnvironment()
  local ns = Loader.Load(environment, { "Core/Init.lua", "Locales/enUS.lua", "Core/Database.lua" })
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
    local profile = ns.Database.NormalizeProfile({ frames = { width = "wide" } }, fixes)
    assertEquals(profile.frames.width, 110)
    assertEquals(fixes, { "frames.width" })
  end)

  it("replaces unknown enum values and clamps numbers to their range", function()
    local ns = LoadDatabase()
    local fixes = {}
    local profile = ns.Database.NormalizeProfile({ frames = { sortBy = "HEALTH", width = 5000, outOfRangeAlpha = 0 } }, fixes)
    assertEquals(profile.frames.sortBy, "GROUP")
    assertEquals(profile.frames.width, 300)
    assertEquals(profile.frames.outOfRangeAlpha, 0.1)
    table.sort(fixes)
    assertEquals(fixes, { "frames.outOfRangeAlpha", "frames.sortBy", "frames.width" })
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
end)

describe("Database.ValidateProfile", function()
  it("accepts the default profile and partial profiles", function()
    local ns = LoadDatabase()
    assertTrue(ns.Database.ValidateProfile(ns.Database.DefaultProfile()))
    assertTrue(ns.Database.ValidateProfile({ frames = { width = 90 } }))
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
      { { frames = { width = "x" } }, "frames.width" },
      { { frames = { growth = "UP" } }, "frames.growth" },
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
    assertEquals(db.version, 1)
    assertEquals(db.classProfiles, {})
    assertEquals(db.characters, {})
    assertEquals(db.framePositions, {})
    assertFalse(db.debug)
  end)

  it("normalizes stored class and character profiles", function()
    local ns, environment = LoadDatabase()
    environment.HealsilusDB = {
      version = 1,
      classProfiles = { DRUID = { frames = { width = 90 } }, BROKEN = "nope" },
      characters = {
        ["Arsilus-Bah"] = { class = "DRUID", own = { bindings = {} }, specs = { [2] = {}, x = {} } },
        ["Bad-Realm"] = 7,
      },
    }
    local db = ns.Database:Initialize()
    assertEquals(db.classProfiles.DRUID.frames.width, 90)
    assertEquals(db.classProfiles.DRUID.frames.height, 34)
    assertEquals(db.classProfiles.BROKEN, nil)
    local character = db.characters["Arsilus-Bah"]
    assertTrue(character.useClassProfile)
    assertFalse(character.useSpecProfiles)
    assertEquals(character.own.frames.width, 110)
    assertEquals(character.specs[2].frames.width, 110)
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
```

- [ ] **Step 2: Añade el fichero a `tests/run.lua` y ejecuta**

Run: `luajit tests/run.lua`
Expected: FAIL — `cannot open Core/Database.lua`.

- [ ] **Step 3: Crea `Core/Database.lua`**

```lua
-- Base de datos guardada (HealsilusDB): valores por defecto, normalización, validación estricta y migraciones.
-- Sin APIs de WoW: todo se prueba fuera del juego.
local _, ns = ...

local Database = { CURRENT_VERSION = 1, MIGRATIONS = {}, fixes = {} }
ns.Database = Database

-- Colecciones cuyo contenido decide el usuario: nunca se mezclan con los valores por defecto.
Database.OPAQUE_KEYS = { bindings = true, hotSpellIDs = true, watched = true }

Database.ENUMS = {
  sortBy = { GROUP = true, CLASS = true, ROLE = true },
  growth = { DOWN = true, RIGHT = true },
  texture = { BLIZZARD = true, RAID = true, FLAT = true },
  colorMode = { CLASS = true, HEALTH = true },
  healthText = { NONE = true, DEFICIT = true, PERCENT = true },
}

Database.WATCH_TARGETS = { ALL = true, TANKS = true }

Database.RANGES = {
  width = { 40, 300 },
  height = { 16, 80 },
  spacing = { 0, 20 },
  columns = { 1, 8 },
  unitsPerColumn = { 1, 40 },
  outOfRangeAlpha = { 0.1, 1 },
  hotsMax = { 0, 8 },
  debuffsMax = { 0, 6 },
  iconSize = { 8, 32 },
}

local BINDING_FIELDS = {
  spell = { kind = true, spellID = true, rank = true, fallbackSpellID = true },
  macro = { kind = true, text = true },
  target = { kind = true },
  menu = { kind = true },
}

local WATCHED_FIELDS = { spellID = true, groupSpellID = true, targets = true }

local MAX_MACRO_LENGTH = 1023

function Database.DefaultProfile()
  return {
    bindings = {},
    frames = {
      width = 110, height = 34, spacing = 2, columns = 8, unitsPerColumn = 5,
      sortBy = "GROUP", growth = "DOWN",
      showSolo = true, showTanks = true, showPets = false, showTarget = true, showFocus = true,
      hideBlizzard = true, locked = true, castOnDown = false,
      texture = "BLIZZARD", colorMode = "CLASS", healthText = "DEFICIT", outOfRangeAlpha = 0.4,
    },
    auras = {
      hotsEnabled = true, hotsMax = 4, hotSpellIDs = {},
      debuffsEnabled = true, debuffsMax = 2, debuffsDispellableOnly = true, iconSize = 14,
    },
    buffs = { enabled = true, watched = {} },
  }
end

local function IsPositiveInteger(value)
  return type(value) == "number" and value > 0 and value % 1 == 0
end
Database.IsPositiveInteger = IsPositiveInteger

local function HasOnlyFields(record, allowed)
  for key in pairs(record) do
    if not allowed[key] then
      return false
    end
  end
  return true
end

local BINDING_KEYS = {}
for _, prefix in ipairs(ns.BINDING_PREFIXES) do
  for _, button in ipairs(ns.MOUSE_BUTTONS) do
    BINDING_KEYS[prefix .. button] = true
  end
end

function Database.IsValidBindingKey(key)
  return BINDING_KEYS[key] == true
end

function Database.IsValidBinding(binding)
  if type(binding) ~= "table" then
    return false
  end
  local allowed = BINDING_FIELDS[binding.kind]
  if not allowed or not HasOnlyFields(binding, allowed) then
    return false
  end
  if binding.kind == "spell" then
    return IsPositiveInteger(binding.spellID)
      and (binding.rank == nil or IsPositiveInteger(binding.rank))
      and (binding.fallbackSpellID == nil or IsPositiveInteger(binding.fallbackSpellID))
  elseif binding.kind == "macro" then
    return type(binding.text) == "string" and #binding.text > 0 and #binding.text <= MAX_MACRO_LENGTH
  end
  return true
end

function Database.IsValidWatched(entry)
  return type(entry) == "table"
    and HasOnlyFields(entry, WATCHED_FIELDS)
    and IsPositiveInteger(entry.spellID)
    and (entry.groupSpellID == nil or IsPositiveInteger(entry.groupSpellID))
    and Database.WATCH_TARGETS[entry.targets] == true
end

-- Completa 'target' con 'defaults' sin tocar lo que el usuario ya tiene bien.
-- Cada campo corregido se añade a 'fixes' con su ruta (p. ej. "frames.width").
function Database.FillDefaults(target, defaults, path, fixes)
  for key, defaultValue in pairs(defaults) do
    local current = target[key]
    local fieldPath = path == "" and key or (path .. "." .. key)
    if current == nil then
      target[key] = ns.DeepCopy(defaultValue)
    elseif type(current) ~= type(defaultValue) then
      target[key] = ns.DeepCopy(defaultValue)
      fixes[#fixes + 1] = fieldPath
    elseif type(defaultValue) == "table" then
      if not Database.OPAQUE_KEYS[key] then
        Database.FillDefaults(current, defaultValue, fieldPath, fixes)
      end
    elseif Database.ENUMS[key] and not Database.ENUMS[key][current] then
      target[key] = defaultValue
      fixes[#fixes + 1] = fieldPath
    elseif Database.RANGES[key] then
      local range = Database.RANGES[key]
      local clamped = math.min(range[2], math.max(range[1], current))
      if clamped ~= current then
        target[key] = clamped
        fixes[#fixes + 1] = fieldPath
      end
    end
  end
end

function Database.NormalizeProfile(profile, fixes)
  fixes = fixes or Database.fixes
  Database.FillDefaults(profile, Database.DefaultProfile(), "", fixes)
  for key, binding in pairs(profile.bindings) do
    if not Database.IsValidBindingKey(key) or not Database.IsValidBinding(binding) then
      profile.bindings[key] = nil
      fixes[#fixes + 1] = "bindings." .. tostring(key)
    end
  end
  for spellID, enabled in pairs(profile.auras.hotSpellIDs) do
    if not IsPositiveInteger(spellID) or enabled ~= true then
      profile.auras.hotSpellIDs[spellID] = nil
      fixes[#fixes + 1] = "auras.hotSpellIDs." .. tostring(spellID)
    end
  end
  local watched = {}
  for position, entry in ipairs(profile.buffs.watched) do
    if Database.IsValidWatched(entry) then
      watched[#watched + 1] = entry
    else
      fixes[#fixes + 1] = "buffs.watched." .. position
    end
  end
  profile.buffs.watched = watched
  return profile
end

-- Validación estricta para perfiles importados: cualquier campo desconocido o mal tipado rechaza todo.
-- Devuelve true, o false y la ruta del primer campo que falla.
function Database.ValidateProfile(profile)
  if type(profile) ~= "table" then
    return false, "profile"
  end
  local defaults = Database.DefaultProfile()
  for key in pairs(profile) do
    if defaults[key] == nil then
      return false, tostring(key)
    end
  end
  if profile.bindings ~= nil then
    if type(profile.bindings) ~= "table" then
      return false, "bindings"
    end
    for key, binding in pairs(profile.bindings) do
      if not Database.IsValidBindingKey(key) or not Database.IsValidBinding(binding) then
        return false, "bindings." .. tostring(key)
      end
    end
  end
  for _, section in ipairs({ "frames", "auras", "buffs" }) do
    local values = profile[section]
    if values ~= nil then
      if type(values) ~= "table" then
        return false, section
      end
      for key, value in pairs(values) do
        local fieldPath = section .. "." .. tostring(key)
        local defaultValue = defaults[section][key]
        if defaultValue == nil or type(value) ~= type(defaultValue) then
          return false, fieldPath
        end
        if Database.ENUMS[key] and not Database.ENUMS[key][value] then
          return false, fieldPath
        end
      end
    end
  end
  if profile.auras and profile.auras.hotSpellIDs then
    for spellID, enabled in pairs(profile.auras.hotSpellIDs) do
      if not IsPositiveInteger(spellID) or enabled ~= true then
        return false, "auras.hotSpellIDs"
      end
    end
  end
  if profile.buffs and profile.buffs.watched then
    for position, entry in pairs(profile.buffs.watched) do
      if not IsPositiveInteger(position) or not Database.IsValidWatched(entry) then
        return false, "buffs.watched." .. tostring(position)
      end
    end
  end
  return true
end

function Database.NormalizeCharacter(character, fixes)
  if type(character.class) ~= "string" then
    character.class = nil
  end
  if type(character.useClassProfile) ~= "boolean" then
    character.useClassProfile = true
  end
  if type(character.useSpecProfiles) ~= "boolean" then
    character.useSpecProfiles = false
  end
  if character.own ~= nil then
    if type(character.own) == "table" then
      Database.NormalizeProfile(character.own, fixes)
    else
      character.own = nil
      fixes[#fixes + 1] = "characters.own"
    end
  end
  if type(character.specs) ~= "table" then
    character.specs = {}
  end
  for specIndex, profile in pairs(character.specs) do
    if IsPositiveInteger(specIndex) and type(profile) == "table" then
      Database.NormalizeProfile(profile, fixes)
    else
      character.specs[specIndex] = nil
      fixes[#fixes + 1] = "characters.specs." .. tostring(specIndex)
    end
  end
end

-- Cada migración convierte los datos de la versión N a la N+1. Una versión sin migración es un error.
function Database:Migrate(db)
  if type(db.version) ~= "number" then
    db.version = self.CURRENT_VERSION
    return
  end
  while db.version < self.CURRENT_VERSION do
    local migration = self.MIGRATIONS[db.version]
    if not migration then
      error("Healsilus: no migration from version " .. db.version)
    end
    migration(db)
    db.version = db.version + 1
  end
  if db.version > self.CURRENT_VERSION then
    self.fixes[#self.fixes + 1] = "version " .. db.version .. " is newer than this addon"
  end
end

function Database:Initialize()
  if type(HealsilusDB) ~= "table" then
    HealsilusDB = {}
  end
  local db = HealsilusDB
  self:Migrate(db)
  if type(db.classProfiles) ~= "table" then
    db.classProfiles = {}
  end
  if type(db.characters) ~= "table" then
    db.characters = {}
  end
  if type(db.framePositions) ~= "table" then
    db.framePositions = {}
  end
  if type(db.debug) ~= "boolean" then
    db.debug = false
  end
  for classToken, profile in pairs(db.classProfiles) do
    if type(profile) == "table" then
      Database.NormalizeProfile(profile, self.fixes)
    else
      db.classProfiles[classToken] = nil
      self.fixes[#self.fixes + 1] = "classProfiles." .. tostring(classToken)
    end
  end
  for characterKey, character in pairs(db.characters) do
    if type(character) == "table" then
      Database.NormalizeCharacter(character, self.fixes)
    else
      db.characters[characterKey] = nil
      self.fixes[#self.fixes + 1] = "characters." .. tostring(characterKey)
    end
  end
  self.db = db
  return db
end
```

- [ ] **Step 4: Añade `Core\Database.lua` al final de la lista de `Healsilus.toc`**

- [ ] **Step 5: Verifica**

Run: `luajit tests/run.lua` → Expected: `29 passed, 0 failed`
Run: `luajit tools/check.lua` → Expected: `check: OK (6 addon files, 15 Lua files)`

- [ ] **Step 6: Commit**

```powershell
git add Core/Database.lua Healsilus.toc tests
git commit -m @'
feat: add saved data defaults, validation and migrations

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
'@
```

### Task 5: Hechizos (nombres, rangos del libro, texto de lanzamiento)

**Files:**
- Create: `Data/Spells.lua`, `tests/test_spells.lua`
- Modify: `Healsilus.toc` (añade `Data\Spells.lua` al final), `tests/run.lua` (añade `"tests/test_spells.lua",`)

- [ ] **Step 1: Escribe la prueba `tests/test_spells.lua`**

```lua
local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertFalse, assertNil = Harness.assertEquals, Harness.assertTrue, Harness.assertFalse, Harness.assertNil

local SPELLS = {
  [774] = { name = "Rejuvenecimiento" },
  [1058] = { name = "Rejuvenecimiento" },
  [1430] = { name = "Rejuvenecimiento" },
  [5185] = { name = "Toque de sanación" },
  [8936] = { name = "Recrecimiento" },
}

local SPELLBOOK = {
  { spellID = 774, name = "Rejuvenecimiento", subName = "Rango 1" },
  { spellID = 1058, name = "Rejuvenecimiento", subName = "Rango 2" },
  { spellID = 5185, name = "Toque de sanación", subName = "Rango 1" },
  { spellID = 768, name = "Forma felina", subName = "" },
  { spellID = 99999, name = "Pasiva", subName = "", isPassive = true },
  { spellID = 88888, name = "Futuro", subName = "Rango 1", itemType = 2 },
}

local function LoadSpells()
  local environment = Stubs.NewEnvironment({ spells = SPELLS, spellbook = SPELLBOOK })
  local ns = Loader.Load(environment, { "Core/Init.lua", "Locales/enUS.lua", "Data/Spells.lua" })
  ns.Spells:Scan()
  return ns, environment
end

describe("Spells", function()
  it("parses the rank number from the spellbook subtext", function()
    local ns = LoadSpells()
    assertEquals(ns.Spells.ParseRank("Rango 3"), 3)
    assertEquals(ns.Spells.ParseRank("Rank 10"), 10)
    assertNil(ns.Spells.ParseRank(""))
    assertNil(ns.Spells.ParseRank(nil))
  end)

  it("groups learned ranks by name and skips passive and future spells", function()
    local ns = LoadSpells()
    local entry = ns.Spells.byName["Rejuvenecimiento"]
    assertEquals(entry.maxRank, 2)
    assertEquals(entry.spellIDs, { [774] = true, [1058] = true })
    assertEquals(entry.ranks[2], { spellID = 1058, subName = "Rango 2" })
    assertEquals(ns.Spells.byName["Forma felina"].maxRank, 0)
    assertNil(ns.Spells.byName["Pasiva"])
    assertNil(ns.Spells.byName["Futuro"])
  end)

  it("knows a spell by name, whatever rank ID is asked", function()
    local ns = LoadSpells()
    assertTrue(ns.Spells:IsKnown(774))
    assertTrue(ns.Spells:IsKnown(1430))
    assertFalse(ns.Spells:IsKnown(8936))
    assertFalse(ns.Spells:IsKnown(424242))
  end)

  it("builds the cast text for the highest or a fixed rank", function()
    local ns = LoadSpells()
    assertEquals(ns.Spells:CastString(774), "Rejuvenecimiento")
    assertEquals(ns.Spells:CastString(774, 2), "Rejuvenecimiento(Rango 2)")
    local text, reason = ns.Spells:CastString(774, 3)
    assertNil(text)
    assertEquals(reason, "rank not learned")
    text, reason = ns.Spells:CastString(424242)
    assertNil(text)
    assertEquals(reason, "unknown spell")
  end)

  it("expands a set of spell IDs with every learned rank of the same spell", function()
    local ns = LoadSpells()
    assertEquals(ns.Spells:ExpandRanks({ [1430] = true, [8936] = true }), { [1430] = true, [774] = true, [1058] = true, [8936] = true })
  end)

  it("lists known spells sorted by name", function()
    local ns = LoadSpells()
    local names = {}
    for _, entry in ipairs(ns.Spells:KnownList()) do
      names[#names + 1] = entry.name
    end
    assertEquals(names, { "Forma felina", "Rejuvenecimiento", "Toque de sanación" })
  end)

  it("records an error when the spellbook API is missing", function()
    local environment = Stubs.NewEnvironment()
    environment.C_SpellBook = nil
    local ns = Loader.Load(environment, { "Core/Init.lua", "Locales/enUS.lua", "Data/Spells.lua" })
    ns.Spells:Scan()
    assertEquals(ns.Diagnostics.errors[1].context, "Spells:Scan")
  end)
end)
```

- [ ] **Step 2: Añade el fichero a `tests/run.lua` y ejecuta**

Run: `luajit tests/run.lua`
Expected: FAIL — `cannot open Data/Spells.lua`.

- [ ] **Step 3: Crea `Data/Spells.lua`**

```lua
-- Hechizos: nombres localizados por ID y rangos aprendidos leídos del libro de hechizos.
-- El atributo "spell" usa el nombre (rango más alto) o "Nombre(subtexto del rango)" para un rango fijo.
local _, ns = ...

local Spells = { byName = {}, scanned = false }
ns.Spells = Spells

function Spells.ParseRank(subName)
  if type(subName) ~= "string" then
    return nil
  end
  local digits = string.match(subName, "(%d+)")
  return digits and tonumber(digits) or nil
end

local function SpellInfo(spellID)
  if not C_Spell or not C_Spell.GetSpellInfo then
    return nil
  end
  return C_Spell.GetSpellInfo(spellID)
end

function Spells:GetName(spellID)
  local info = SpellInfo(spellID)
  return info and info.name or nil
end

function Spells:GetIcon(spellID)
  local info = SpellInfo(spellID)
  return info and info.iconID or nil
end

function Spells:AddSpellbookEntry(name, spellID, subName, iconID)
  local entry = self.byName[name]
  if not entry then
    entry = { name = name, ranks = {}, maxRank = 0, spellIDs = {}, icon = iconID }
    self.byName[name] = entry
  end
  entry.spellIDs[spellID] = true
  local rank = Spells.ParseRank(subName)
  if rank then
    entry.ranks[rank] = { spellID = spellID, subName = subName }
    if rank > entry.maxRank then
      entry.maxRank = rank
    end
  end
end

function Spells:Scan()
  wipe(self.byName)
  if not C_SpellBook or not C_SpellBook.GetNumSpellBookSkillLines or not C_SpellBook.GetSpellBookItemInfo then
    ns.RecordError("Spells:Scan", "C_SpellBook API missing")
    return
  end
  local bank = Enum.SpellBookSpellBank.Player
  local spellType = Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
  for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
    local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(line)
    if lineInfo and not lineInfo.shouldHide then
      local first = lineInfo.itemIndexOffset + 1
      local last = lineInfo.itemIndexOffset + lineInfo.numSpellBookItems
      for slot = first, last do
        local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
        if item and item.spellID and item.name and not item.isPassive
          and (spellType == nil or item.itemType == spellType) then
          self:AddSpellbookEntry(item.name, item.spellID, item.subName, item.iconID)
        end
      end
    end
  end
  self.scanned = true
end

-- Conocido = algún rango con ese nombre está en el libro.
function Spells:IsKnown(spellID)
  local name = self:GetName(spellID)
  return name ~= nil and self.byName[name] ~= nil
end

function Spells:CastString(spellID, rank)
  local name = self:GetName(spellID)
  if not name then
    return nil, "unknown spell"
  end
  if rank == nil then
    return name
  end
  local entry = self.byName[name]
  local rankInfo = entry and entry.ranks[rank]
  if not rankInfo then
    return nil, "rank not learned"
  end
  return name .. "(" .. rankInfo.subName .. ")"
end

-- En vanilla cada rango tiene su ID; los filtros de auras necesitan todos.
function Spells:ExpandRanks(spellIDSet)
  local expanded = {}
  for spellID in pairs(spellIDSet) do
    expanded[spellID] = true
    local name = self:GetName(spellID)
    local entry = name and self.byName[name]
    if entry then
      for rankSpellID in pairs(entry.spellIDs) do
        expanded[rankSpellID] = true
      end
    end
  end
  return expanded
end

function Spells:KnownList()
  local list = {}
  for _, entry in pairs(self.byName) do
    list[#list + 1] = entry
  end
  table.sort(list, function(left, right)
    return left.name < right.name
  end)
  return list
end

-- El ID del rango más alto (o cualquiera si no hay rangos) para guardar una asignación.
function Spells.PreferredSpellID(entry)
  local best = entry.ranks[entry.maxRank]
  if best then
    return best.spellID
  end
  for spellID in pairs(entry.spellIDs) do
    return spellID
  end
  return nil
end
```

- [ ] **Step 4: Añade a la prueba el caso de `PreferredSpellID`**

Añade dentro del `describe("Spells", ...)` de `tests/test_spells.lua`:

```lua
  it("prefers the highest learned rank ID", function()
    local ns = LoadSpells()
    assertEquals(ns.Spells.PreferredSpellID(ns.Spells.byName["Rejuvenecimiento"]), 1058)
    assertEquals(ns.Spells.PreferredSpellID(ns.Spells.byName["Forma felina"]), 768)
  end)
```

- [ ] **Step 5: Añade `Data\Spells.lua` al final de la lista de `Healsilus.toc`**

- [ ] **Step 6: Verifica**

Run: `luajit tests/run.lua` → Expected: `37 passed, 0 failed`
Run: `luajit tools/check.lua` → Expected: `check: OK (7 addon files, 17 Lua files)`

- [ ] **Step 7: Commit**

```powershell
git add Data/Spells.lua Healsilus.toc tests
git commit -m @'
feat: resolve spell names and learned ranks from the spellbook

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
'@
```

### Task 6: Perfil de serie del druida

**Files:**
- Create: `Data/Druid.lua`, `tests/test_druid.lua`
- Modify: `Healsilus.toc` (añade `Data\Druid.lua` al final), `tests/run.lua` (añade `"tests/test_druid.lua",`)

- [ ] **Step 1: Escribe la prueba `tests/test_druid.lua`**

```lua
local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue = Harness.assertEquals, Harness.assertTrue

local function LoadDruid()
  local environment = Stubs.NewEnvironment()
  return Loader.Load(environment, { "Core/Init.lua", "Locales/enUS.lua", "Core/Database.lua", "Data/Druid.lua" })
end

describe("Druid defaults", function()
  it("produce a profile that passes strict validation", function()
    local ns = LoadDruid()
    assertTrue(ns.Database.ValidateProfile(ns.ClassDefaults.DRUID()))
  end)

  it("bind the agreed spells to each click", function()
    local ns = LoadDruid()
    assertEquals(ns.ClassDefaults.DRUID().bindings, {
      ["1"] = { kind = "spell", spellID = 5185 },
      ["2"] = { kind = "spell", spellID = 774 },
      ["shift-1"] = { kind = "spell", spellID = 8936 },
      ["shift-2"] = { kind = "spell", spellID = 2782 },
      ["ctrl-1"] = { kind = "spell", spellID = 2893, fallbackSpellID = 8946 },
      ["ctrl-2"] = { kind = "spell", spellID = 20484 },
      ["3"] = { kind = "target" },
    })
  end)

  it("track Rejuvenation and Regrowth and watch Mark and Thorns", function()
    local ns = LoadDruid()
    local profile = ns.ClassDefaults.DRUID()
    assertEquals(profile.auras.hotSpellIDs, { [774] = true, [8936] = true })
    assertEquals(profile.buffs.watched, {
      { spellID = 1126, groupSpellID = 21849, targets = "ALL" },
      { spellID = 467, targets = "TANKS" },
    })
  end)

  it("return a fresh table on every call", function()
    local ns = LoadDruid()
    local first = ns.ClassDefaults.DRUID()
    first.bindings["1"] = nil
    assertEquals(ns.ClassDefaults.DRUID().bindings["1"], { kind = "spell", spellID = 5185 })
  end)
end)
```

- [ ] **Step 2: Añade el fichero a `tests/run.lua` y ejecuta**

Run: `luajit tests/run.lua`
Expected: FAIL — `cannot open Data/Druid.lua`.

- [ ] **Step 3: Crea `Data/Druid.lua`**

```lua
-- Perfil de serie del druida. IDs de vanilla (rango 1): el atributo usa el nombre, así que se lanza
-- el rango más alto aprendido. /hs diag avisa si algún ID no existe en el cliente de Forever.
local _, ns = ...

ns.ClassDefaults = ns.ClassDefaults or {}

ns.DRUID_SPELLS = {
  HEALING_TOUCH = 5185,
  REJUVENATION = 774,
  REGROWTH = 8936,
  REMOVE_CURSE = 2782,
  ABOLISH_POISON = 2893,
  CURE_POISON = 8946,
  REBIRTH = 20484,
  MARK_OF_THE_WILD = 1126,
  GIFT_OF_THE_WILD = 21849,
  THORNS = 467,
}

local SPELLS = ns.DRUID_SPELLS

function ns.ClassDefaults.DRUID()
  local profile = ns.Database.DefaultProfile()
  profile.bindings = {
    ["1"] = { kind = "spell", spellID = SPELLS.HEALING_TOUCH },
    ["2"] = { kind = "spell", spellID = SPELLS.REJUVENATION },
    ["shift-1"] = { kind = "spell", spellID = SPELLS.REGROWTH },
    ["shift-2"] = { kind = "spell", spellID = SPELLS.REMOVE_CURSE },
    ["ctrl-1"] = { kind = "spell", spellID = SPELLS.ABOLISH_POISON, fallbackSpellID = SPELLS.CURE_POISON },
    ["ctrl-2"] = { kind = "spell", spellID = SPELLS.REBIRTH },
    ["3"] = { kind = "target" },
  }
  profile.auras.hotSpellIDs = { [SPELLS.REJUVENATION] = true, [SPELLS.REGROWTH] = true }
  profile.buffs.watched = {
    { spellID = SPELLS.MARK_OF_THE_WILD, groupSpellID = SPELLS.GIFT_OF_THE_WILD, targets = "ALL" },
    { spellID = SPELLS.THORNS, targets = "TANKS" },
  }
  return profile
end
```

- [ ] **Step 4: Añade `Data\Druid.lua` al final de la lista de `Healsilus.toc`**

- [ ] **Step 5: Verifica**

Run: `luajit tests/run.lua` → Expected: `41 passed, 0 failed`
Run: `luajit tools/check.lua` → Expected: `check: OK (8 addon files, 19 Lua files)`

- [ ] **Step 6: Commit**

```powershell
git add Data/Druid.lua Healsilus.toc tests
git commit -m @'
feat: add built-in druid profile

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
'@
```

### Task 7: Perfiles (especialización → PJ → clase)

**Files:**
- Create: `Core/Profiles.lua`, `tests/test_profiles.lua`
- Modify: `Healsilus.toc` (añade `Core\Profiles.lua` al final), `tests/run.lua` (añade `"tests/test_profiles.lua",`)

- [ ] **Step 1: Escribe la prueba `tests/test_profiles.lua`**

```lua
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
```

- [ ] **Step 2: Añade el fichero a `tests/run.lua` y ejecuta**

Run: `luajit tests/run.lua`
Expected: FAIL — `cannot open Core/Profiles.lua`.

- [ ] **Step 3: Crea `Core/Profiles.lua`**

```lua
-- Perfiles: elige el activo (especialización → PJ → clase → serie) y gestiona copiar, restablecer y sustituir.
-- El perfil activo es una tabla de HealsilusDB: la configuración la edita directamente.
local _, ns = ...

local Profiles = { active = nil, source = nil, characterKey = nil, classToken = nil }
ns.Profiles = Profiles

function Profiles.ActiveSpecGroup()
  if C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup then
    return C_SpecializationInfo.GetActiveSpecGroup() or 1
  end
  if GetActiveSpecGroup then
    return GetActiveSpecGroup() or 1
  end
  if GetActiveTalentGroup then
    return GetActiveTalentGroup() or 1
  end
  return 1
end

function Profiles.CreateClassDefault(classToken)
  local factory = ns.ClassDefaults and ns.ClassDefaults[classToken]
  local profile = factory and factory() or ns.Database.DefaultProfile()
  return ns.Database.NormalizeProfile(profile, {})
end

function Profiles.Resolve(db, characterKey, classToken, specIndex)
  local character = db.characters[characterKey]
  if character then
    if character.useSpecProfiles and character.specs[specIndex] then
      return character.specs[specIndex], "spec"
    end
    if character.useClassProfile == false and character.own then
      return character.own, "character"
    end
  end
  local classProfile = db.classProfiles[classToken]
  if not classProfile then
    classProfile = Profiles.CreateClassDefault(classToken)
    db.classProfiles[classToken] = classProfile
  end
  return classProfile, "class"
end

function Profiles:Initialize()
  local db = ns.Database.db
  self.characterKey = ns.CharacterKey()
  local _, classToken = UnitClass("player")
  self.classToken = classToken
  local character = db.characters[self.characterKey]
  if not character then
    character = { class = classToken, useClassProfile = true, useSpecProfiles = false, specs = {} }
    db.characters[self.characterKey] = character
  end
  character.class = classToken
  self:Refresh(true)
end

function Profiles:Character()
  return ns.Database.db.characters[self.characterKey]
end

function Profiles:Refresh(force)
  local profile, source = Profiles.Resolve(ns.Database.db, self.characterKey, self.classToken, Profiles.ActiveSpecGroup())
  if force or profile ~= self.active or source ~= self.source then
    self.active, self.source = profile, source
    ns.Events:Fire("PROFILE_CHANGED", profile, source)
  end
  return profile, source
end

-- Sustituye el perfil guardado en el hueco activo (especialización, PJ o clase).
function Profiles:ReplaceActive(profile)
  local character = self:Character()
  if self.source == "spec" then
    character.specs[Profiles.ActiveSpecGroup()] = profile
  elseif self.source == "character" then
    character.own = profile
  else
    ns.Database.db.classProfiles[self.classToken] = profile
  end
  self:Refresh(true)
end

function Profiles:ResetActive()
  self:ReplaceActive(Profiles.CreateClassDefault(self.classToken))
end

function Profiles:CopyFrom(sourceProfile)
  self:ReplaceActive(ns.DeepCopy(sourceProfile))
end

function Profiles:SetUseClassProfile(enabled)
  local character = self:Character()
  character.useClassProfile = enabled
  if not enabled and not character.own then
    local classProfile = ns.Database.db.classProfiles[self.classToken] or Profiles.CreateClassDefault(self.classToken)
    character.own = ns.DeepCopy(classProfile)
  end
  self:Refresh()
end

function Profiles:SetUseSpecProfiles(enabled)
  local character = self:Character()
  character.useSpecProfiles = enabled
  if enabled then
    local group = Profiles.ActiveSpecGroup()
    if not character.specs[group] then
      character.specs[group] = ns.DeepCopy(self.active)
    end
  end
  self:Refresh()
end

local function SourceSortKey(source)
  return source.kind .. ":" .. (source.classToken or source.characterKey or "") .. ":" .. tostring(source.specIndex or 0)
end

-- Todos los perfiles guardados salvo el activo: sirven de origen para "Copiar desde…".
function Profiles:ListCopySources()
  local db = ns.Database.db
  local sources = {}
  for classToken, profile in pairs(db.classProfiles) do
    if profile ~= self.active then
      sources[#sources + 1] = { kind = "class", classToken = classToken, profile = profile }
    end
  end
  for characterKey, character in pairs(db.characters) do
    if character.own and character.own ~= self.active then
      sources[#sources + 1] = { kind = "character", characterKey = characterKey, profile = character.own }
    end
    for specIndex, profile in pairs(character.specs) do
      if profile ~= self.active then
        sources[#sources + 1] = { kind = "spec", characterKey = characterKey, specIndex = specIndex, profile = profile }
      end
    end
  end
  table.sort(sources, function(left, right)
    return SourceSortKey(left) < SourceSortKey(right)
  end)
  return sources
end
```

- [ ] **Step 4: Añade `Core\Profiles.lua` al final de la lista de `Healsilus.toc`**

- [ ] **Step 5: Verifica**

Run: `luajit tests/run.lua` → Expected: `54 passed, 0 failed`
Run: `luajit tools/check.lua` → Expected: `check: OK (9 addon files, 21 Lua files)`

- [ ] **Step 6: Commit**

```powershell
git add Core/Profiles.lua Healsilus.toc tests
git commit -m @'
feat: resolve active profile by spec, character and class

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
'@
```

### Task 8: Exportar e importar perfiles

**Files:**
- Create: `Core/Serializer.lua`, `tests/test_serializer.lua`
- Modify: `Healsilus.toc` (añade `Core\Serializer.lua` al final), `tests/run.lua` (añade `"tests/test_serializer.lua",`)

- [ ] **Step 1: Escribe la prueba `tests/test_serializer.lua`**

```lua
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
```

- [ ] **Step 2: Añade el fichero a `tests/run.lua` y ejecuta**

Run: `luajit tests/run.lua`
Expected: FAIL — `cannot open Core/Serializer.lua`.

- [ ] **Step 3: Crea `Core/Serializer.lua`**

```lua
-- Exportar/importar perfiles como texto: formato propio con claves ordenadas + Base64.
-- El texto importado nunca se ejecuta: se analiza a mano y se valida campo a campo.
local _, ns = ...

local Serializer = {}
ns.Serializer = Serializer

local PREFIX = "HS1:"
local MAX_DEPTH = 20
local MAX_INPUT_LENGTH = 200000
local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local PADDING = 61

local DECODE = {}
for position = 1, 64 do
  DECODE[string.byte(ALPHABET, position)] = position - 1
end

local function AlphabetChar(sextet)
  return string.sub(ALPHABET, sextet + 1, sextet + 1)
end

function Serializer.EncodeBase64(data)
  local output = {}
  for position = 1, #data, 3 do
    local first, second, third = string.byte(data, position, position + 2)
    local combined = first * 65536 + (second or 0) * 256 + (third or 0)
    local block = AlphabetChar(math.floor(combined / 262144) % 64) .. AlphabetChar(math.floor(combined / 4096) % 64)
    block = block .. (second and AlphabetChar(math.floor(combined / 64) % 64) or "=")
    block = block .. (third and AlphabetChar(combined % 64) or "=")
    output[#output + 1] = block
  end
  return table.concat(output)
end

function Serializer.DecodeBase64(text)
  if #text % 4 ~= 0 then
    return nil
  end
  local output = {}
  for position = 1, #text, 4 do
    local firstCode, secondCode, thirdCode, fourthCode = string.byte(text, position, position + 3)
    local first, second = DECODE[firstCode], DECODE[secondCode]
    local thirdPadded, fourthPadded = thirdCode == PADDING, fourthCode == PADDING
    local third = thirdPadded and 0 or DECODE[thirdCode]
    local fourth = fourthPadded and 0 or DECODE[fourthCode]
    if first == nil or second == nil or third == nil or fourth == nil then
      return nil
    end
    if thirdPadded and not fourthPadded then
      return nil
    end
    if (thirdPadded or fourthPadded) and position + 3 ~= #text then
      return nil
    end
    local combined = first * 262144 + second * 4096 + third * 64 + fourth
    local block = string.char(math.floor(combined / 65536) % 256)
    if not thirdPadded then
      block = block .. string.char(math.floor(combined / 256) % 256)
    end
    if not fourthPadded then
      block = block .. string.char(combined % 256)
    end
    output[#output + 1] = block
  end
  return table.concat(output)
end

local function IsFinite(number)
  return number == number and number ~= math.huge and number ~= -math.huge
end

local function SortKeys(left, right)
  local leftType, rightType = type(left), type(right)
  if leftType ~= rightType then
    return leftType == "number"
  end
  return left < right
end

local function SerializeValue(value, parts, depth)
  local valueType = type(value)
  if valueType == "string" then
    parts[#parts + 1] = "s" .. #value .. ":" .. value
  elseif valueType == "number" then
    if not IsFinite(value) then
      error("cannot serialize non-finite number")
    end
    parts[#parts + 1] = "n" .. string.format("%.17g", value) .. ";"
  elseif valueType == "boolean" then
    parts[#parts + 1] = value and "t" or "f"
  elseif valueType == "table" then
    if depth >= MAX_DEPTH then
      error("table nesting too deep")
    end
    local keys = {}
    for key in pairs(value) do
      local keyType = type(key)
      if keyType ~= "string" and keyType ~= "number" then
        error("unsupported key type: " .. keyType)
      end
      keys[#keys + 1] = key
    end
    table.sort(keys, SortKeys)
    parts[#parts + 1] = "{"
    for _, key in ipairs(keys) do
      SerializeValue(key, parts, depth + 1)
      SerializeValue(value[key], parts, depth + 1)
    end
    parts[#parts + 1] = "}"
  else
    error("unsupported value type: " .. valueType)
  end
end

-- Devuelve valor, siguiente posición; o nil, mensaje de error.
local function ParseValue(text, position, depth)
  local marker = string.sub(text, position, position)
  if marker == "s" then
    local colon = string.find(text, ":", position + 1, true)
    if not colon then
      return nil, "string size"
    end
    local size = tonumber(string.sub(text, position + 1, colon - 1))
    if not size or size < 0 or size % 1 ~= 0 then
      return nil, "string size"
    end
    local finish = colon + size
    if finish > #text then
      return nil, "string truncated"
    end
    return string.sub(text, colon + 1, finish), finish + 1
  elseif marker == "n" then
    local semicolon = string.find(text, ";", position + 1, true)
    if not semicolon then
      return nil, "number"
    end
    local number = tonumber(string.sub(text, position + 1, semicolon - 1))
    if not number or not IsFinite(number) then
      return nil, "number"
    end
    return number, semicolon + 1
  elseif marker == "t" then
    return true, position + 1
  elseif marker == "f" then
    return false, position + 1
  elseif marker == "{" then
    if depth >= MAX_DEPTH then
      return nil, "too deep"
    end
    local result = {}
    local cursor = position + 1
    while true do
      local current = string.sub(text, cursor, cursor)
      if current == "}" then
        return result, cursor + 1
      end
      if current == "" then
        return nil, "unterminated table"
      end
      local key, afterKey = ParseValue(text, cursor, depth + 1)
      if key == nil then
        return nil, afterKey
      end
      if type(key) ~= "string" and type(key) ~= "number" then
        return nil, "invalid key"
      end
      local value, afterValue = ParseValue(text, afterKey, depth + 1)
      if value == nil then
        return nil, afterValue
      end
      result[key] = value
      cursor = afterValue
    end
  end
  return nil, "unexpected character at " .. position
end

function Serializer.Export(profile)
  local parts = {}
  SerializeValue(profile, parts, 0)
  return PREFIX .. Serializer.EncodeBase64(table.concat(parts))
end

-- Devuelve el perfil normalizado, o nil y un motivo legible.
function Serializer.Import(text)
  if type(text) ~= "string" then
    return nil, "empty"
  end
  local compact = string.gsub(text, "%s", "")
  if compact == "" then
    return nil, "empty"
  end
  if #compact > MAX_INPUT_LENGTH then
    return nil, "too long"
  end
  if string.sub(compact, 1, #PREFIX) ~= PREFIX then
    return nil, "not a Healsilus profile"
  end
  local data = Serializer.DecodeBase64(string.sub(compact, #PREFIX + 1))
  if not data then
    return nil, "corrupted text"
  end
  local profile, position = ParseValue(data, 1, 0)
  if profile == nil then
    return nil, "corrupted data (" .. tostring(position) .. ")"
  end
  if position ~= #data + 1 then
    return nil, "trailing data"
  end
  local valid, field = ns.Database.ValidateProfile(profile)
  if not valid then
    return nil, "invalid field: " .. field
  end
  return ns.Database.NormalizeProfile(profile, {})
end
```

- [ ] **Step 4: Añade `Core\Serializer.lua` al final de la lista de `Healsilus.toc`**

- [ ] **Step 5: Verifica**

Run: `luajit tests/run.lua` → Expected: `64 passed, 0 failed`
Run: `luajit tools/check.lua` → Expected: `check: OK (10 addon files, 23 Lua files)`

- [ ] **Step 6: Commit**

```powershell
git add Core/Serializer.lua Healsilus.toc tests
git commit -m @'
feat: export and import profiles without executing text

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
'@
```

### Task 9: Texturas, colores y curvas

**Files:**
- Create: `Frames/Media.lua`, `Frames/Curves.lua`, `tests/test_media_curves.lua`
- Modify: `Healsilus.toc` (añade `Frames\Media.lua` y `Frames\Curves.lua` al final, en ese orden), `tests/run.lua` (añade `"tests/test_media_curves.lua",`)

- [ ] **Step 1: Escribe la prueba `tests/test_media_curves.lua`**

```lua
local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertFalse = Harness.assertEquals, Harness.assertTrue, Harness.assertFalse

local function LoadMedia()
  local environment = Stubs.NewEnvironment()
  environment.CreateColor = function(red, green, blue, alpha)
    return { r = red, g = green, b = blue, a = alpha }
  end
  local ns = Loader.Load(environment, { "Core/Init.lua", "Locales/enUS.lua", "Frames/Media.lua", "Frames/Curves.lua" })
  return ns, environment
end

local function InstallCurveApi(environment)
  local created = {}
  local function Factory()
    local curve = { points = {} }
    function curve:SetType(kind)
      self.kind = kind
    end
    function curve:AddPoint(position, value)
      self.points[#self.points + 1] = { position, value }
    end
    created[#created + 1] = curve
    return curve
  end
  environment.C_CurveUtil = { CreateCurve = Factory, CreateColorCurve = Factory }
  environment.Enum.LuaCurveType = { Linear = 0, Step = 1 }
  environment.UnitHealthPercent = function()
    return 1
  end
  return created
end

describe("Media", function()
  it("maps texture keys to paths and falls back to the Blizzard bar", function()
    local ns = LoadMedia()
    assertEquals(ns.Media.Texture("FLAT"), "Interface\\Buttons\\WHITE8X8")
    assertEquals(ns.Media.Texture("UNKNOWN"), "Interface\\TargetingFrame\\UI-StatusBar")
  end)

  it("reads class colors from C_ClassColor, then RAID_CLASS_COLORS, then a fallback", function()
    local ns, environment = LoadMedia()
    environment.RAID_CLASS_COLORS = { DRUID = { r = 1, g = 0.49, b = 0.04 } }
    assertEquals({ ns.Media.ClassColor("DRUID") }, { 1, 0.49, 0.04 })
    environment.C_ClassColor = {
      GetClassColor = function()
        return { r = 0.5, g = 0.5, b = 0.5 }
      end,
    }
    assertEquals({ ns.Media.ClassColor("DRUID") }, { 0.5, 0.5, 0.5 })
    environment.C_ClassColor = nil
    assertEquals({ ns.Media.ClassColor(nil) }, { 0.3, 0.7, 0.3 })
  end)

  it("builds the dispel color map, preferring the client's debuff colors", function()
    local ns, environment = LoadMedia()
    environment.DebuffTypeColor = { Magic = { r = 0.1, g = 0.2, b = 0.3 } }
    local map = ns.Media.DispelColorMap()
    assertEquals(map.Magic, { r = 0.1, g = 0.2, b = 0.3, a = 1 })
    assertEquals(map.Poison, { r = 0, g = 0.6, b = 0, a = 1 })
  end)
end)

describe("Curves", function()
  it("reports support only when every curve API exists", function()
    local ns, environment = LoadMedia()
    assertFalse(ns.Curves.IsSupported())
    InstallCurveApi(environment)
    assertTrue(ns.Curves.IsSupported())
  end)

  it("builds the health color curve once and reuses it", function()
    local ns, environment = LoadMedia()
    local created = InstallCurveApi(environment)
    local curve = ns.Curves:HealthColor()
    assertTrue(ns.Curves:HealthColor() == curve)
    assertEquals(#created, 1)
    assertEquals(#curve.points, 5)
    assertEquals(curve.points[1][2], { r = 1, g = 0, b = 0, a = 1 })
    assertEquals(curve.points[5][2], { r = 0, g = 1, b = 0, a = 1 })
  end)

  it("maps health fraction to 0-100 for the percent text", function()
    local ns, environment = LoadMedia()
    InstallCurveApi(environment)
    assertEquals(ns.Curves:Percent().points, { { 0, 0 }, { 1, 100 } })
  end)
end)
```

- [ ] **Step 2: Añade el fichero a `tests/run.lua` y ejecuta**

Run: `luajit tests/run.lua`
Expected: FAIL — `cannot open Frames/Media.lua`.

- [ ] **Step 3: Crea `Frames/Media.lua`**

```lua
-- Texturas y colores compartidos por las barras, la vista previa y las auras.
local _, ns = ...

local Media = {}
ns.Media = Media

Media.TEXTURES = {
  BLIZZARD = "Interface\\TargetingFrame\\UI-StatusBar",
  RAID = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
  FLAT = "Interface\\Buttons\\WHITE8X8",
}
Media.TEXTURE_ORDER = { "BLIZZARD", "RAID", "FLAT" }

Media.PET_COLOR = { r = 0.2, g = 0.8, b = 0.2 }
Media.OFFLINE_COLOR = { r = 0.5, g = 0.5, b = 0.5 }
Media.FALLBACK_COLOR = { r = 0.3, g = 0.7, b = 0.3 }
Media.DISPEL_COLORS = {
  Magic = { 0.2, 0.6, 1 },
  Curse = { 0.6, 0, 1 },
  Disease = { 0.6, 0.4, 0 },
  Poison = { 0, 0.6, 0 },
}

function Media.Texture(key)
  return Media.TEXTURES[key] or Media.TEXTURES.BLIZZARD
end

function Media.ClassColor(classToken)
  if classToken then
    if C_ClassColor and C_ClassColor.GetClassColor then
      local color = C_ClassColor.GetClassColor(classToken)
      if color then
        return color.r, color.g, color.b
      end
    end
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
    if color then
      return color.r, color.g, color.b
    end
  end
  local fallback = Media.FALLBACK_COLOR
  return fallback.r, fallback.g, fallback.b
end

-- Mapa { Magic = color, ... } para AddDispelTypeTexture de los contenedores de auras.
function Media.DispelColorMap()
  local map = {}
  for name, rgb in pairs(Media.DISPEL_COLORS) do
    local red, green, blue = rgb[1], rgb[2], rgb[3]
    local clientColor = DebuffTypeColor and DebuffTypeColor[name]
    if clientColor then
      red, green, blue = clientColor.r, clientColor.g, clientColor.b
    end
    map[name] = CreateColor(red, green, blue, 1)
  end
  return map
end
```

- [ ] **Step 4: Crea `Frames/Curves.lua`**

```lua
-- Curvas de C_CurveUtil: el cliente las evalúa con la vida secreta, el addon nunca ve el número.
local _, ns = ...

local Curves = {}
ns.Curves = Curves

-- Rojo hasta el 30 %, amarillo al 65 %, verde desde el 98 %.
local HEALTH_POINTS = {
  { 0, 1, 0, 0 },
  { 0.3, 1, 0, 0 },
  { 0.65, 1, 1, 0 },
  { 0.98, 0, 1, 0 },
  { 1, 0, 1, 0 },
}

function Curves.IsSupported()
  return C_CurveUtil ~= nil and C_CurveUtil.CreateColorCurve ~= nil and C_CurveUtil.CreateCurve ~= nil
    and UnitHealthPercent ~= nil and Enum.LuaCurveType ~= nil and CreateColor ~= nil
end

function Curves:HealthColor()
  if not self.healthColor then
    local curve = C_CurveUtil.CreateColorCurve()
    curve:SetType(Enum.LuaCurveType.Linear)
    for _, point in ipairs(HEALTH_POINTS) do
      curve:AddPoint(point[1], CreateColor(point[2], point[3], point[4], 1))
    end
    self.healthColor = curve
  end
  return self.healthColor
end

function Curves:Percent()
  if not self.percent then
    local curve = C_CurveUtil.CreateCurve()
    curve:SetType(Enum.LuaCurveType.Linear)
    curve:AddPoint(0, 0)
    curve:AddPoint(1, 100)
    self.percent = curve
  end
  return self.percent
end
```

- [ ] **Step 5: Añade `Frames\Media.lua` y `Frames\Curves.lua` al final de la lista de `Healsilus.toc`**

- [ ] **Step 6: Verifica**

Run: `luajit tests/run.lua` → Expected: `70 passed, 0 failed`
Run: `luajit tools/check.lua` → Expected: `check: OK (12 addon files, 26 Lua files)`

- [ ] **Step 7: Commit**

```powershell
git add Frames Healsilus.toc tests
git commit -m @'
feat: add bar textures, colors and secret-safe curves

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
'@
```

### Task 10: Click-casting (asignaciones → atributos seguros)

**Files:**
- Create: `Frames/ClickCast.lua`, `tests/test_click_cast.lua`
- Modify: `Healsilus.toc` (añade `Frames\ClickCast.lua` al final), `tests/run.lua` (añade `"tests/test_click_cast.lua",`)

- [ ] **Step 1: Escribe la prueba `tests/test_click_cast.lua`**

```lua
local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue = Harness.assertEquals, Harness.assertTrue

local FILES = {
  "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/CombatQueue.lua",
  "Core/Database.lua", "Data/Spells.lua", "Frames/ClickCast.lua",
}

local SPELLS = {
  [2893] = { name = "Suprimir veneno" },
  [8946] = { name = "Curar envenenamiento" },
  [774] = { name = "Rejuvenecimiento" },
}

local function LoadClickCast(spellbook)
  local environment = Stubs.NewEnvironment({ spells = SPELLS, spellbook = spellbook or {} })
  local ns = Loader.Load(environment, FILES)
  ns.Spells:Scan()
  ns.UnitButton = { buttons = {} }
  ns.Headers = { list = {} }
  return ns, environment
end

local function FakeResolver(binding)
  if binding.spellID == 999 then
    return nil
  end
  return "Spell" .. binding.spellID .. (binding.rank and ("(" .. binding.rank .. ")") or "")
end

local function AsPairs(attributes)
  local result = {}
  for _, attribute in ipairs(attributes) do
    result[#result + 1] = attribute.name .. "=" .. attribute.value
  end
  return result
end

describe("ClickCast.BuildAttributes", function()
  it("defaults left click to target and right click to the unit menu", function()
    local ns = LoadClickCast()
    assertEquals(AsPairs(ns.ClickCast.BuildAttributes({}, FakeResolver)), { "type1=target", "type2=togglemenu" })
  end)

  it("maps every binding kind with its modifier prefix in canonical order", function()
    local ns = LoadClickCast()
    local attributes = ns.ClickCast.BuildAttributes({
      ["1"] = { kind = "spell", spellID = 774 },
      ["4"] = { kind = "menu" },
      ["alt-2"] = { kind = "target" },
      ["ctrl-3"] = { kind = "macro", text = "/cast [@mouseover] Innervate" },
      ["shift-1"] = { kind = "spell", spellID = 8936, rank = 2 },
    }, FakeResolver)
    assertEquals(AsPairs(attributes), {
      "type1=spell", "spell1=Spell774", "type2=togglemenu", "type4=togglemenu",
      "alt-type2=target",
      "ctrl-type3=macro", "ctrl-macrotext3=/cast [@mouseover] Innervate",
      "shift-type1=spell", "shift-spell1=Spell8936(2)",
    })
  end)

  it("leaves a slot empty when its spell cannot be resolved", function()
    local ns = LoadClickCast()
    assertEquals(AsPairs(ns.ClickCast.BuildAttributes({ ["1"] = { kind = "spell", spellID = 999 } }, FakeResolver)), { "type2=togglemenu" })
  end)
end)

describe("ClickCast.ResolveSpell", function()
  it("uses the fallback spell only when the main one is not learned", function()
    local binding = { kind = "spell", spellID = 2893, fallbackSpellID = 8946 }
    local ns = LoadClickCast({ { spellID = 8946, name = "Curar envenenamiento", subName = "" } })
    assertEquals(ns.ClickCast.ResolveSpell(binding), "Curar envenenamiento")
    ns = LoadClickCast({
      { spellID = 8946, name = "Curar envenenamiento", subName = "" },
      { spellID = 2893, name = "Suprimir veneno", subName = "" },
    })
    assertEquals(ns.ClickCast.ResolveSpell(binding), "Suprimir veneno")
    ns = LoadClickCast({})
    assertEquals(ns.ClickCast.ResolveSpell(binding), "Suprimir veneno")
  end)
end)

describe("ClickCast application", function()
  local function FakeSecureFrame()
    local frame = { attributes = {} }
    function frame:SetAttribute(name, value)
      self.attributes[name] = value
    end
    function frame:GetAttribute(name)
      return self.attributes[name]
    end
    return frame
  end

  it("clears attributes from the previous profile before writing the new ones", function()
    local ns = LoadClickCast()
    local button = FakeSecureFrame()
    button.attributes.type3 = "macro"
    button.healsilusAttributeNames = { "type3" }
    ns.ClickCast.ApplyToButton(button, { { name = "type1", value = "target" } })
    assertEquals(button.attributes, { type1 = "target" })
    assertEquals(button.healsilusAttributeNames, { "type1" })
  end)

  it("stores the attributes on headers so new buttons can copy them", function()
    local ns = LoadClickCast()
    local header = FakeSecureFrame()
    ns.ClickCast.StoreOnHeader(header, { { name = "type1", value = "target" }, { name = "type2", value = "togglemenu" } })
    ns.ClickCast.StoreOnHeader(header, { { name = "type1", value = "spell" } })
    assertEquals(header.attributes, { ["hs-attr-count"] = 1, ["hs-attr-name-1"] = "type1", ["hs-attr-value-1"] = "spell" })
  end)

  it("applies the profile to every button and header, refusing to run in combat", function()
    local ns, environment = LoadClickCast()
    local button, header = FakeSecureFrame(), FakeSecureFrame()
    ns.UnitButton.buttons[button] = true
    ns.Headers.list[1] = header
    local profile = ns.Database.DefaultProfile()
    ns.ClickCast:Apply(profile)
    assertEquals(button.attributes, { type1 = "target", type2 = "togglemenu" })
    assertEquals(header.attributes["hs-attr-count"], 2)
    environment.__state.inCombat = true
    Harness.assertError(function()
      ns.ClickCast:Apply(profile)
    end, "in combat")
  end)

  it("lets a button created by the header adopt the current attribute names", function()
    local ns = LoadClickCast()
    ns.ClickCast:Apply(ns.Database.DefaultProfile())
    local button = FakeSecureFrame()
    ns.ClickCast:AdoptButton(button)
    assertEquals(button.healsilusAttributeNames, { "type1", "type2" })
  end)

  it("queues a refresh requested in combat and applies it afterwards", function()
    local ns, environment = LoadClickCast()
    local button = FakeSecureFrame()
    ns.UnitButton.buttons[button] = true
    ns.Profiles = { active = ns.Database.DefaultProfile() }
    environment.__state.inCombat = true
    ns.Events:Fire("SETTINGS_CHANGED", "bindings")
    assertEquals(button.attributes, {})
    environment.__state.inCombat = false
    environment.__fireEvent("PLAYER_REGEN_ENABLED")
    assertTrue(button.attributes.type1 == "target")
  end)
end)
```

- [ ] **Step 2: Añade el fichero a `tests/run.lua` y ejecuta**

Run: `luajit tests/run.lua`
Expected: FAIL — `cannot open Frames/ClickCast.lua`.

- [ ] **Step 3: Crea `Frames/ClickCast.lua`**

```lua
-- Click-casting: asignaciones del perfil → atributos de SecureActionButtonTemplate.
-- Solo se escriben atributos fuera de combate; los botones creados por una cabecera los copian de ella.
local _, ns = ...

local ClickCast = { current = {} }
ns.ClickCast = ClickCast

-- Si el hechizo principal no está aprendido pero el alternativo sí, se usa el alternativo.
function ClickCast.ResolveSpell(binding)
  local spellID = binding.spellID
  if binding.fallbackSpellID and not ns.Spells:IsKnown(spellID) and ns.Spells:IsKnown(binding.fallbackSpellID) then
    spellID = binding.fallbackSpellID
  end
  return (ns.Spells:CastString(spellID, binding.rank))
end

-- Lista ordenada { name, value }: prefijos en orden canónico y botones 1..5.
-- Sin asignación propia, el clic izquierdo selecciona y el derecho abre el menú de unidad.
function ClickCast.BuildAttributes(bindings, resolveSpell)
  local attributes = {}
  local function Add(name, value)
    attributes[#attributes + 1] = { name = name, value = value }
  end
  for _, prefix in ipairs(ns.BINDING_PREFIXES) do
    for _, button in ipairs(ns.MOUSE_BUTTONS) do
      local binding = bindings[prefix .. button]
      if binding then
        if binding.kind == "spell" then
          local castString = resolveSpell(binding)
          if castString then
            Add(prefix .. "type" .. button, "spell")
            Add(prefix .. "spell" .. button, castString)
          end
        elseif binding.kind == "macro" then
          Add(prefix .. "type" .. button, "macro")
          Add(prefix .. "macrotext" .. button, binding.text)
        elseif binding.kind == "target" then
          Add(prefix .. "type" .. button, "target")
        elseif binding.kind == "menu" then
          Add(prefix .. "type" .. button, "togglemenu")
        end
      elseif prefix == "" and button == "1" then
        Add("type1", "target")
      elseif prefix == "" and button == "2" then
        Add("type2", "togglemenu")
      end
    end
  end
  return attributes
end

function ClickCast.ApplyToButton(button, attributes)
  for _, name in ipairs(button.healsilusAttributeNames or {}) do
    button:SetAttribute(name, nil)
  end
  local names = {}
  for _, attribute in ipairs(attributes) do
    button:SetAttribute(attribute.name, attribute.value)
    names[#names + 1] = attribute.name
  end
  button.healsilusAttributeNames = names
end

-- La cabecera guarda la lista para su initialConfigFunction (ver Frames/Headers.lua).
function ClickCast.StoreOnHeader(header, attributes)
  local previous = header:GetAttribute("hs-attr-count") or 0
  for position = 1, previous do
    header:SetAttribute("hs-attr-name-" .. position, nil)
    header:SetAttribute("hs-attr-value-" .. position, nil)
  end
  for position, attribute in ipairs(attributes) do
    header:SetAttribute("hs-attr-name-" .. position, attribute.name)
    header:SetAttribute("hs-attr-value-" .. position, attribute.value)
  end
  header:SetAttribute("hs-attr-count", #attributes)
end

function ClickCast:Apply(profile)
  if InCombatLockdown() then
    error("ClickCast:Apply called in combat")
  end
  local attributes = ClickCast.BuildAttributes(profile.bindings, ClickCast.ResolveSpell)
  for button in pairs(ns.UnitButton.buttons) do
    ClickCast.ApplyToButton(button, attributes)
  end
  for _, header in ipairs(ns.Headers.list) do
    ClickCast.StoreOnHeader(header, attributes)
  end
  self.current = attributes
end

-- Un botón recién creado por la cabecera ya copió los atributos en el entorno seguro:
-- solo hay que recordar sus nombres para poder limpiarlos en el próximo Apply.
function ClickCast:AdoptButton(button)
  local names = {}
  for position, attribute in ipairs(self.current) do
    names[position] = attribute.name
  end
  button.healsilusAttributeNames = names
end

function ClickCast:Refresh()
  ns.CombatQueue:Run("clickcast", function()
    if ns.Profiles and ns.Profiles.active then
      ClickCast:Apply(ns.Profiles.active)
    end
  end)
end

ns.Events:Register("SETTINGS_CHANGED", function(section)
  if section == "bindings" then
    ClickCast:Refresh()
  end
end)

ns.Events:Register("SPELLBOOK_UPDATED", function()
  ClickCast:Refresh()
end)
```

- [ ] **Step 4: Añade `Frames\ClickCast.lua` al final de la lista de `Healsilus.toc`**

- [ ] **Step 5: Verifica**

Run: `luajit tests/run.lua` → Expected: `79 passed, 0 failed`
Run: `luajit tools/check.lua` → Expected: `check: OK (13 addon files, 28 Lua files)`

- [ ] **Step 6: Commit**

```powershell
git add Frames/ClickCast.lua Healsilus.toc tests
git commit -m @'
feat: translate click bindings into secure button attributes

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
'@
```

### Task 11: Curación entrante y escudos

**Files:**
- Create: `Frames/Prediction.lua`, `tests/test_prediction.lua`
- Modify: `Healsilus.toc` (añade `Frames\Prediction.lua` al final), `tests/run.lua` (añade `"tests/test_prediction.lua",`)

- [ ] **Step 1: Escribe la prueba `tests/test_prediction.lua`**

```lua
local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertFalse = Harness.assertEquals, Harness.assertTrue, Harness.assertFalse

local function LoadPrediction()
  local environment = Stubs.NewEnvironment()
  local ns = Loader.Load(environment, { "Core/Init.lua", "Locales/enUS.lua", "Frames/Media.lua", "Frames/Prediction.lua" })
  return ns, environment
end

local function FakeBar()
  local bar = { calls = {}, shown = false }
  function bar:SetMinMaxValues(...)
    self.calls[#self.calls + 1] = { "SetMinMaxValues", ... }
  end
  function bar:SetValue(...)
    self.calls[#self.calls + 1] = { "SetValue", select("#", ...), ... }
  end
  function bar:Show()
    self.shown = true
  end
  function bar:Hide()
    self.shown = false
  end
  return bar
end

local function FakeButton()
  local calculator = {}
  function calculator:GetMaximumHealth()
    return 1000
  end
  function calculator:GetIncomingHeals()
    return 500
  end
  function calculator:GetDamageAbsorbs()
    return 300, true
  end
  return {
    unit = "party1",
    healsilus = { prediction = { calculator = calculator, incoming = FakeBar(), absorb = FakeBar() } },
  }
end

describe("Prediction", function()
  it("is supported only with the native calculator APIs", function()
    local ns, environment = LoadPrediction()
    assertFalse(ns.Prediction.IsSupported())
    environment.CreateUnitHealPredictionCalculator = function() end
    environment.UnitGetDetailedHealPrediction = function() end
    assertTrue(ns.Prediction.IsSupported())
  end)

  it("feeds the native amounts straight into the bars, one value each", function()
    local ns, environment = LoadPrediction()
    local requested
    environment.UnitGetDetailedHealPrediction = function(unit, healer, calculator)
      requested = { unit, healer, calculator }
    end
    local button = FakeButton()
    ns.Prediction:Update(button)
    local prediction = button.healsilus.prediction
    assertEquals(requested, { "party1", "player", prediction.calculator })
    assertEquals(prediction.incoming.calls, { { "SetMinMaxValues", 0, 1000 }, { "SetValue", 1, 500 } })
    assertEquals(prediction.absorb.calls, { { "SetMinMaxValues", 0, 1000 }, { "SetValue", 1, 300 } })
    assertTrue(prediction.incoming.shown)
    assertTrue(prediction.absorb.shown)
  end)

  it("does nothing for buttons without unit or prediction and hides on request", function()
    local ns, environment = LoadPrediction()
    environment.UnitGetDetailedHealPrediction = function()
      error("must not be called")
    end
    local button = FakeButton()
    button.unit = nil
    ns.Prediction:Update(button)
    ns.Prediction:Update({ unit = "party1", healsilus = {} })
    button.healsilus.prediction.incoming:Show()
    ns.Prediction:Hide(button)
    assertFalse(button.healsilus.prediction.incoming.shown)
    assertFalse(button.healsilus.prediction.absorb.shown)
  end)
end)
```

- [ ] **Step 2: Añade el fichero a `tests/run.lua` y ejecuta**

Run: `luajit tests/run.lua`
Expected: FAIL — `cannot open Frames/Prediction.lua`.

- [ ] **Step 3: Crea `Frames/Prediction.lua`**

```lua
-- Curación entrante y escudos con el calculador nativo: el cliente recorta las cantidades a la vida que falta,
-- así que no hace falta ninguna operación con valores secretos. Las barras se anclan al final de la vida.
local _, ns = ...

local Prediction = {}
ns.Prediction = Prediction

local INCOMING_COLOR = { 0.59, 0.77, 0.35, 0.6 }
local ABSORB_COLOR = { 0.52, 0.72, 0.92, 0.65 }

function Prediction.IsSupported()
  return CreateUnitHealPredictionCalculator ~= nil and UnitGetDetailedHealPrediction ~= nil
end

local function CreateOverlayBar(button, level, color)
  local bar = CreateFrame("StatusBar", nil, button)
  bar:SetFrameLevel(level)
  bar:SetStatusBarTexture(ns.Media.Texture("FLAT"))
  bar:GetStatusBarTexture():SetVertexColor(color[1], color[2], color[3], color[4])
  bar:Hide()
  return bar
end

function Prediction:Attach(button)
  local visual = button.healsilus
  if visual.prediction or not Prediction.IsSupported() then
    return
  end
  local calculator = CreateUnitHealPredictionCalculator()
  if calculator.SetIncomingHealClampMode and Enum.UnitIncomingHealClampMode then
    calculator:SetIncomingHealClampMode(Enum.UnitIncomingHealClampMode.MissingHealth)
  end
  if calculator.SetIncomingHealOverflowPercent then
    calculator:SetIncomingHealOverflowPercent(1)
  end
  if calculator.SetDamageAbsorbClampMode and Enum.UnitDamageAbsorbClampMode then
    calculator:SetDamageAbsorbClampMode(Enum.UnitDamageAbsorbClampMode.MissingHealth)
  end
  local level = visual.healthBar:GetFrameLevel() + 1
  visual.prediction = {
    calculator = calculator,
    incoming = CreateOverlayBar(button, level, INCOMING_COLOR),
    absorb = CreateOverlayBar(button, level, ABSORB_COLOR),
  }
  self:Layout(button)
  visual.healthBar:HookScript("OnSizeChanged", function()
    Prediction:Layout(button)
  end)
end

-- Cada barra mide lo mismo que la de vida y empieza donde acaba la textura anterior.
function Prediction:Layout(button)
  local visual = button.healsilus
  local prediction = visual.prediction
  if not prediction then
    return
  end
  local healthBar = visual.healthBar
  local width, height = healthBar:GetWidth(), healthBar:GetHeight()
  prediction.incoming:ClearAllPoints()
  prediction.incoming:SetSize(width, height)
  prediction.incoming:SetPoint("TOPLEFT", healthBar:GetStatusBarTexture(), "TOPRIGHT")
  prediction.absorb:ClearAllPoints()
  prediction.absorb:SetSize(width, height)
  prediction.absorb:SetPoint("TOPLEFT", prediction.incoming:GetStatusBarTexture(), "TOPRIGHT")
end

function Prediction:Update(button)
  local prediction = button.healsilus.prediction
  if not prediction or not button.unit then
    return
  end
  local calculator = prediction.calculator
  UnitGetDetailedHealPrediction(button.unit, "player", calculator)
  local maximum = calculator:GetMaximumHealth()
  local incomingAmount = calculator:GetIncomingHeals()
  -- GetDamageAbsorbs devuelve también un segundo valor: solo se pasa el primero a la barra.
  local absorbAmount = calculator:GetDamageAbsorbs()
  prediction.incoming:SetMinMaxValues(0, maximum)
  prediction.incoming:SetValue(incomingAmount)
  prediction.incoming:Show()
  prediction.absorb:SetMinMaxValues(0, maximum)
  prediction.absorb:SetValue(absorbAmount)
  prediction.absorb:Show()
end

function Prediction:Hide(button)
  local prediction = button.healsilus.prediction
  if not prediction then
    return
  end
  prediction.incoming:Hide()
  prediction.absorb:Hide()
end
```

- [ ] **Step 4: Añade `Frames\Prediction.lua` al final de la lista de `Healsilus.toc`**

- [ ] **Step 5: Verifica**

Run: `luajit tests/run.lua` → Expected: `82 passed, 0 failed`
Run: `luajit tools/check.lua` → Expected: `check: OK (14 addon files, 30 Lua files)`

- [ ] **Step 6: Commit**

```powershell
git add Frames/Prediction.lua Healsilus.toc tests
git commit -m @'
feat: show incoming heals and absorbs with the native calculator

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
'@
```

### Task 12: Contenedores nativos de auras (HoTs, debuffs, borde de dispel)

**Files:**
- Create: `Auras/Containers.lua`, `tests/test_containers.lua`
- Modify: `Healsilus.toc` (añade `Auras\Containers.lua` al final), `tests/run.lua` (añade `"tests/test_containers.lua",`)

- [ ] **Step 1: Escribe la prueba `tests/test_containers.lua`**

```lua
local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertNil = Harness.assertEquals, Harness.assertTrue, Harness.assertNil

local FILES = {
  "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/CombatQueue.lua", "Core/Database.lua",
  "Data/Spells.lua", "Frames/Media.lua", "Auras/Containers.lua",
}

local CONTAINER_METHODS = {
  "Hide", "Show", "ClearAllPoints", "SetPoint", "SetFrameLevel", "SetMouseClickEnabled",
  "SetMouseMotionEnabled", "SetUnit", "AddAuraGroup", "SetEnabled", "UpdateAllAuras",
}

local function LoadContainers(options)
  options = options or {}
  local environment = Stubs.NewEnvironment({ spells = { [774] = { name = "Rejuvenecimiento" } } })
  local containers = {}
  local baseCreateFrame = environment.CreateFrame
  environment.CreateFrame = function(frameType, name, parent, template)
    if frameType ~= "AuraContainer" then
      return baseCreateFrame(frameType, name, parent, template)
    end
    if options.unsupported then
      error("unknown frame type AuraContainer")
    end
    local container = { calls = {} }
    for _, method in ipairs(CONTAINER_METHODS) do
      container[method] = function(self, ...)
        if method == "SetUnit" and options.failingUnit and (...) == options.failingUnit then
          error("bad unit")
        end
        self.calls[#self.calls + 1] = { method, ... }
      end
    end
    containers[#containers + 1] = container
    return container
  end
  local ns = Loader.Load(environment, FILES)
  local profile = ns.Database.DefaultProfile()
  profile.auras.hotSpellIDs = { [774] = true }
  ns.Profiles = { active = profile }
  ns.UnitButton = { buttons = {} }
  return ns, environment, containers
end

local function FakeButton(unit)
  return {
    unit = unit,
    GetFrameLevel = function()
      return 5
    end,
    healsilus = { healthBar = {} },
  }
end

local function GroupCall(container)
  for _, call in ipairs(container.calls) do
    if call[1] == "AddAuraGroup" then
      return call
    end
  end
  return nil
end

local function MethodPosition(container, method)
  for position, call in ipairs(container.calls) do
    if call[1] == method then
      return position
    end
  end
  return nil
end

describe("Containers", function()
  it("builds HoT, debuff and dispel-highlight containers with the right filters", function()
    local ns = LoadContainers()
    local button = FakeButton("party1")
    ns.Containers:Attach(button)
    local built = button.healsilusAuras
    local hots = GroupCall(built.hots)
    assertEquals(hots[3], "HELPFUL|PLAYER")
    assertEquals(hots[4].maxFrameCount, 4)
    assertEquals(hots[4].candidateFilters.includeSpellIDs, { [774] = true })
    assertEquals(GroupCall(built.debuffs)[3], "HARMFUL|RAID")
    assertEquals(GroupCall(built.debuffs)[4].maxFrameCount, 2)
    assertEquals(GroupCall(built.highlight)[3], "HARMFUL|RAID")
    assertEquals(GroupCall(built.highlight)[4].maxFrameCount, 1)
  end)

  it("follows the order the client requires and shows the containers afterwards", function()
    local ns = LoadContainers()
    local button = FakeButton("party1")
    ns.Containers:Attach(button)
    for _, container in pairs(button.healsilusAuras) do
      local unitAt = MethodPosition(container, "SetUnit")
      local groupAt = MethodPosition(container, "AddAuraGroup")
      local enabledAt = MethodPosition(container, "SetEnabled")
      local shownAt = MethodPosition(container, "Show")
      assertTrue(unitAt < groupAt and groupAt < enabledAt and enabledAt < shownAt)
    end
  end)

  it("uses the plain harmful filter when every debuff should be shown", function()
    local ns = LoadContainers()
    ns.Profiles.active.auras.debuffsDispellableOnly = false
    local button = FakeButton("party1")
    ns.Containers:Attach(button)
    assertEquals(GroupCall(button.healsilusAuras.debuffs)[3], "HARMFUL")
  end)

  it("skips the HoT container when HoTs are off or the list is empty", function()
    local ns = LoadContainers()
    ns.Profiles.active.auras.hotSpellIDs = {}
    local button = FakeButton("party1")
    ns.Containers:Attach(button)
    assertNil(button.healsilusAuras.hots)
    ns.Profiles.active.auras.hotSpellIDs = { [774] = true }
    ns.Profiles.active.auras.hotsEnabled = false
    ns.Containers:Attach(button)
    assertNil(button.healsilusAuras.hots)
  end)

  it("never creates containers in combat and builds them when combat ends", function()
    local ns, environment, containers = LoadContainers()
    environment.__state.inCombat = true
    local button = FakeButton("party1")
    ns.Containers:Attach(button)
    assertEquals(#containers, 0)
    assertTrue(ns.Containers.pending[button])
    environment.__state.inCombat = false
    environment.__fireEvent("PLAYER_REGEN_ENABLED")
    assertTrue(button.healsilusAuras ~= nil)
    assertNil(ns.Containers.pending[button])
  end)

  it("hides a container whose unit change fails and records the error", function()
    local ns = LoadContainers({ failingUnit = "raid40" })
    local button = FakeButton("party1")
    ns.Containers:Attach(button)
    ns.Containers:SetUnit(button, "raid40")
    assertNil(button.healsilusAuras.hots)
    assertEquals(ns.Diagnostics.errors[1].context, "Containers:SetUnit")
  end)

  it("records an unsupported client and builds nothing", function()
    local ns = LoadContainers({ unsupported = true })
    local button = FakeButton("party1")
    ns.Containers:Attach(button)
    assertNil(button.healsilusAuras)
    assertEquals(ns.Diagnostics.errors[1].context, "AuraContainer")
  end)
end)
```

- [ ] **Step 2: Añade el fichero a `tests/run.lua` y ejecuta**

Run: `luajit tests/run.lua`
Expected: FAIL — `cannot open Auras/Containers.lua`.

- [ ] **Step 3: Crea `Auras/Containers.lua`**

```lua
-- Auras con contenedores nativos (AuraContainer): Blizzard pinta los datos secretos; el addon nunca los lee.
-- Reglas (técnica de HealBot/DandersFrames probada en 12.1):
--   * crear y activar (SetEnabled) solo fuera de combate: en combate es un error del cliente que pcall no captura;
--   * orden: CreateFrame → anclar → SetUnit → AddAuraGroup → SetEnabled al final;
--   * Show/Hide y SetUnit sí se permiten en combate (tras Show se llama a UpdateAllAuras);
--   * nunca se lee nada de los botones de aura ni se ramifica con su contenido.
local _, ns = ...

local Containers = { supported = nil, pending = {} }
ns.Containers = Containers

local function Layout(size)
  return {
    elementWidth = size, elementHeight = size, elementSpacing = 1, lineSpacing = 1, groupSpacing = 0,
    elementSpacingX = 1, elementSpacingY = 1, gapX = 0,
  }
end

local function DispelOptions()
  local options = { customDispelColorMap = ns.Media.DispelColorMap() }
  if Enum.CustomAuraButtonDispelTypeTextureStyle then
    options.style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset
  end
  return options
end

local function AddDispelTexture(auraButton, texture)
  if auraButton.AddDispelTypeTexture then
    auraButton:AddDispelTypeTexture(texture, DispelOptions())
  elseif auraButton.SetAuraBorder then
    auraButton:SetAuraBorder(texture, DispelOptions())
  end
end

local function DisableMouse(frame)
  if frame.SetMouseClickEnabled then
    frame:SetMouseClickEnabled(false)
  end
  if frame.SetMouseMotionEnabled then
    frame:SetMouseMotionEnabled(false)
  end
end

-- Icono + cuenta atrás + acumulaciones; los debuffs llevan además un borde con el color del tipo de dispel.
local function MakeIconInitializer(size, withDispelBorder)
  return function(auraButton)
    if auraButton.healsilusReady then
      return
    end
    local ok, failure = pcall(function()
      auraButton:SetSize(size, size)
      DisableMouse(auraButton)
      local icon = auraButton:CreateTexture(nil, "ARTWORK")
      icon:SetAllPoints(auraButton)
      icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      auraButton:SetIcon(icon)
      if auraButton.SetDurationCooldown then
        local cooldown = CreateFrame("Cooldown", nil, auraButton, "CooldownFrameTemplate")
        cooldown:SetAllPoints(auraButton)
        cooldown:SetReverse(true)
        cooldown:SetDrawEdge(false)
        if cooldown.SetHideCountdownNumbers then
          cooldown:SetHideCountdownNumbers(false)
        end
        local countdown = cooldown.GetCountdownFontString and cooldown:GetCountdownFontString()
        if countdown then
          countdown:SetFont(STANDARD_TEXT_FONT, math.max(8, math.floor(size * 0.6)), "OUTLINE")
        end
        auraButton:SetDurationCooldown(cooldown)
      end
      if auraButton.SetApplicationCount then
        local count = auraButton:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        count:SetPoint("BOTTOMRIGHT", auraButton, "BOTTOMRIGHT", 1, -1)
        auraButton:SetApplicationCount(count, {})
      end
      if withDispelBorder then
        local border = auraButton:CreateTexture(nil, "BACKGROUND")
        border:SetPoint("TOPLEFT", auraButton, "TOPLEFT", -1, 1)
        border:SetPoint("BOTTOMRIGHT", auraButton, "BOTTOMRIGHT", 1, -1)
        border:SetColorTexture(1, 1, 1, 1)
        AddDispelTexture(auraButton, border)
      end
      auraButton.healsilusReady = true
    end)
    if not ok then
      ns.RecordError("Containers:InitializeIcon", failure)
    end
  end
end

-- Un único "aura" de 1x1 cuya textura cubre todo el botón de unidad: la barra de vida tapa el centro
-- y queda visible un anillo de 2 px con el color del debuff que puedes quitar.
local function MakeHighlightInitializer(unitButton)
  return function(auraButton)
    if auraButton.healsilusReady then
      return
    end
    local ok, failure = pcall(function()
      auraButton:SetSize(1, 1)
      DisableMouse(auraButton)
      local ring = auraButton:CreateTexture(nil, "ARTWORK")
      ring:SetAllPoints(unitButton)
      ring:SetColorTexture(1, 1, 1, 1)
      AddDispelTexture(auraButton, ring)
      auraButton.healsilusReady = true
    end)
    if not ok then
      ns.RecordError("Containers:InitializeHighlight", failure)
    end
  end
end

local function BuildContainer(unitButton, spec)
  local container = CreateFrame("AuraContainer", nil, unitButton, "CustomAuraContainerTemplate")
  container:Hide()
  container:ClearAllPoints()
  container:SetPoint(spec.point, unitButton.healsilus.healthBar, spec.point, spec.x, spec.y)
  if container.SetFlowLayoutAnchorPoint then
    container:SetFlowLayoutAnchorPoint(spec.point)
  end
  if container.SetFlowLayoutGrowthDirection and AnchorUtil and AnchorUtil.FlowDirection then
    local horizontal = string.find(spec.point, "RIGHT") and AnchorUtil.FlowDirection.Left or AnchorUtil.FlowDirection.Right
    local vertical = string.find(spec.point, "BOTTOM") and AnchorUtil.FlowDirection.Up or AnchorUtil.FlowDirection.Down
    if horizontal ~= nil and vertical ~= nil then
      container:SetFlowLayoutGrowthDirection(horizontal, vertical)
    end
  end
  container:SetFrameLevel(unitButton:GetFrameLevel() + spec.levelOffset)
  DisableMouse(container)
  container:SetUnit(unitButton.unit)
  local options = {
    maxFrameCount = spec.maxCount,
    initializeFrame = spec.initializer,
    layout = Layout(spec.size),
    candidateFilters = spec.candidateFilters,
    sortMethod = spec.sortMethod,
  }
  container:AddAuraGroup(spec.key, spec.filter, options)
  container:SetEnabled(true)
  return container
end

function Containers:IsSupported()
  if self.supported ~= nil then
    return self.supported
  end
  if InCombatLockdown() then
    return false
  end
  local ok, probe = pcall(CreateFrame, "AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
  if not ok then
    ns.RecordError("AuraContainer", probe)
    self.supported = false
    return false
  end
  self.supported = probe ~= nil and type(probe.AddAuraGroup) == "function"
  if probe then
    probe:Hide()
  end
  return self.supported
end

function Containers:Detach(button)
  local built = button.healsilusAuras
  if not built then
    return
  end
  for _, container in pairs(built) do
    container:Hide()
    container:SetEnabled(false)
  end
  button.healsilusAuras = nil
end

function Containers:Attach(button)
  if not button.unit then
    return
  end
  if InCombatLockdown() then
    self.pending[button] = true
    return
  end
  self.pending[button] = nil
  if not self:IsSupported() then
    return
  end
  self:Detach(button)
  local auras = ns.Profiles.active.auras
  local sortMethod = AuraContainerSortMethod and AuraContainerSortMethod.UnitFrameDebuff
  local built = {}
  local ok, failure = pcall(function()
    if auras.hotsEnabled and auras.hotsMax > 0 then
      local spellIDs = ns.Spells:ExpandRanks(auras.hotSpellIDs)
      if next(spellIDs) then
        built.hots = BuildContainer(button, {
          key = "healsilusHots", filter = "HELPFUL|PLAYER", maxCount = auras.hotsMax, size = auras.iconSize,
          initializer = MakeIconInitializer(auras.iconSize, false), point = "BOTTOMRIGHT", x = -1, y = 1,
          levelOffset = 8, candidateFilters = { includeSpellIDs = spellIDs },
        })
      end
    end
    if auras.debuffsEnabled and auras.debuffsMax > 0 then
      built.debuffs = BuildContainer(button, {
        key = "healsilusDebuffs", filter = auras.debuffsDispellableOnly and "HARMFUL|RAID" or "HARMFUL",
        maxCount = auras.debuffsMax, size = auras.iconSize, initializer = MakeIconInitializer(auras.iconSize, true),
        point = "TOPRIGHT", x = -1, y = -1, levelOffset = 8, sortMethod = sortMethod,
      })
      built.highlight = BuildContainer(button, {
        key = "healsilusDispel", filter = "HARMFUL|RAID", maxCount = 1, size = 1,
        initializer = MakeHighlightInitializer(button), point = "TOPLEFT", x = 0, y = 0,
        levelOffset = 1, sortMethod = sortMethod,
      })
    end
  end)
  if not ok then
    for _, container in pairs(built) do
      container:Hide()
    end
    ns.RecordError("Containers:Attach", failure)
    return
  end
  button.healsilusAuras = built
  self:UpdateVisibility(button)
end

function Containers:UpdateVisibility(button)
  local built = button.healsilusAuras
  if not built then
    return
  end
  for _, container in pairs(built) do
    if button.unit then
      container:Show()
      container:UpdateAllAuras()
    else
      container:Hide()
    end
  end
end

function Containers:SetUnit(button, unit)
  local built = button.healsilusAuras
  if not built then
    if unit then
      self:Attach(button)
    end
    return
  end
  if unit then
    for key, container in pairs(built) do
      local ok, failure = pcall(container.SetUnit, container, unit)
      if not ok then
        container:Hide()
        built[key] = nil
        ns.RecordError("Containers:SetUnit", failure)
      end
    end
  end
  self:UpdateVisibility(button)
end

function Containers:RebuildAll()
  ns.CombatQueue:Run("auras", function()
    if not ns.UnitButton then
      return
    end
    for button in pairs(ns.UnitButton.buttons) do
      Containers:Attach(button)
    end
  end)
end

ns.Events:Register("COMBAT_ENDED", function()
  local pending = Containers.pending
  Containers.pending = {}
  for button in pairs(pending) do
    Containers:Attach(button)
  end
end)

local function Rebuild()
  Containers:RebuildAll()
end
ns.Events:Register("PROFILE_CHANGED", Rebuild)
ns.Events:Register("SPELLBOOK_UPDATED", Rebuild)
ns.Events:Register("SETTINGS_CHANGED", function(section)
  if section == "auras" then
    Rebuild()
  end
end)
```

- [ ] **Step 4: Añade `Auras\Containers.lua` al final de la lista de `Healsilus.toc`**

- [ ] **Step 5: Verifica**

Run: `luajit tests/run.lua` → Expected: `89 passed, 0 failed`
Run: `luajit tools/check.lua` → Expected: `check: OK (15 addon files, 32 Lua files)`

- [ ] **Step 6: Commit**

```powershell
git add Auras/Containers.lua Healsilus.toc tests
git commit -m @'
feat: draw HoTs, debuffs and dispel ring with native aura containers

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
'@
```

### Task 13: Buffs que faltan

**Files:**
- Create: `Auras/MissingBuffs.lua`, `tests/test_missing_buffs.lua`
- Modify: `Healsilus.toc` (añade `Auras\MissingBuffs.lua` al final), `tests/run.lua` (añade `"tests/test_missing_buffs.lua",`)

- [ ] **Step 1: Escribe la prueba `tests/test_missing_buffs.lua`**

```lua
local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertFalse, assertNil = Harness.assertEquals, Harness.assertTrue, Harness.assertFalse, Harness.assertNil

local FILES = {
  "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/CombatQueue.lua", "Core/Database.lua",
  "Data/Spells.lua", "Data/Druid.lua", "Auras/MissingBuffs.lua",
}

local SPELLS = {
  [1126] = { name = "Marca de lo Salvaje" },
  [21849] = { name = "Don de lo Salvaje" },
  [467] = { name = "Espinas" },
}

local function LoadMissingBuffs()
  local environment = Stubs.NewEnvironment({ spells = SPELLS })
  local units = {
    party1 = { role = "TANK", auras = {} },
    party2 = { role = "DAMAGER", auras = { ["Don de lo Salvaje"] = true } },
  }
  environment.UnitExists = function(unit)
    return units[unit] ~= nil
  end
  environment.UnitIsConnected = function()
    return true
  end
  environment.UnitIsDeadOrGhost = function(unit)
    return units[unit].dead == true
  end
  environment.UnitGroupRolesAssigned = function(unit)
    return units[unit].role
  end
  environment.C_UnitAuras = {
    GetAuraDataBySpellName = function(unit, name)
      return units[unit].auras[name] and { name = name } or nil
    end,
  }
  local ns = Loader.Load(environment, FILES)
  ns.Profiles = { active = ns.Database.NormalizeProfile(ns.ClassDefaults.DRUID(), {}) }
  ns.UnitButton = { buttons = {} }
  ns.MissingBuffs:Resolve()
  return ns, environment, units
end

local function FakeButton(unit)
  local mark = { shown = false }
  function mark:SetShown(shown)
    self.shown = shown
  end
  return { unit = unit, healsilus = { missingMark = mark } }
end

describe("MissingBuffs.Compute", function()
  it("checks everyone for ALL entries and only tanks for TANKS entries", function()
    local ns = LoadMissingBuffs()
    local watched = {
      { label = "Marca", names = { "Marca", "Don" }, targets = "ALL" },
      { label = "Espinas", names = { "Espinas" }, targets = "TANKS" },
    }
    local function Nothing()
      return false
    end
    assertEquals(ns.MissingBuffs.Compute(watched, Nothing, true), { "Marca", "Espinas" })
    assertEquals(ns.MissingBuffs.Compute(watched, Nothing, false), { "Marca" })
    local function HasGift(name)
      return name == "Don"
    end
    assertEquals(ns.MissingBuffs.Compute(watched, HasGift, false), {})
  end)
end)

describe("MissingBuffs", function()
  it("resolves watched spells to localized names, including the group version", function()
    local ns = LoadMissingBuffs()
    assertEquals(ns.MissingBuffs.resolved, {
      { label = "Marca de lo Salvaje", names = { "Marca de lo Salvaje", "Don de lo Salvaje" }, targets = "ALL" },
      { label = "Espinas", names = { "Espinas" }, targets = "TANKS" },
    })
  end)

  it("drops watched spells the client does not know", function()
    local ns = LoadMissingBuffs()
    ns.Profiles.active.buffs.watched = { { spellID = 424242, targets = "ALL" } }
    assertEquals(ns.MissingBuffs:Resolve(), {})
  end)

  it("marks a tank missing Mark and Thorns, and accepts the group buff for others", function()
    local ns = LoadMissingBuffs()
    local tank, damager = FakeButton("party1"), FakeButton("party2")
    ns.MissingBuffs:Evaluate(tank)
    ns.MissingBuffs:Evaluate(damager)
    assertEquals(tank.healsilusMissing, { "Marca de lo Salvaje", "Espinas" })
    assertTrue(tank.healsilus.missingMark.shown)
    assertEquals(damager.healsilusMissing, {})
    assertFalse(damager.healsilus.missingMark.shown)
  end)

  it("freezes the last result in combat and under secret restrictions", function()
    local ns, environment, units = LoadMissingBuffs()
    local tank = FakeButton("party1")
    ns.MissingBuffs:Evaluate(tank)
    units.party1.auras = { ["Marca de lo Salvaje"] = true, ["Espinas"] = true }
    environment.__state.inCombat = true
    ns.MissingBuffs:Evaluate(tank)
    assertEquals(tank.healsilusMissing, { "Marca de lo Salvaje", "Espinas" })
    environment.__state.inCombat = false
    environment.C_Secrets = {
      HasSecretRestrictions = function()
        return true
      end,
    }
    ns.MissingBuffs:Evaluate(tank)
    assertEquals(tank.healsilusMissing, { "Marca de lo Salvaje", "Espinas" })
    environment.C_Secrets = nil
    ns.MissingBuffs:Evaluate(tank)
    assertEquals(tank.healsilusMissing, {})
  end)

  it("clears the mark for dead units and when the feature is off", function()
    local ns, _, units = LoadMissingBuffs()
    local tank = FakeButton("party1")
    ns.MissingBuffs:Evaluate(tank)
    units.party1.dead = true
    ns.MissingBuffs:Evaluate(tank)
    assertNil(tank.healsilusMissing)
    assertFalse(tank.healsilus.missingMark.shown)
    units.party1.dead = false
    ns.Profiles.active.buffs.enabled = false
    ns.MissingBuffs:Resolve()
    ns.MissingBuffs:Evaluate(tank)
    assertNil(tank.healsilusMissing)
  end)

  it("groups aura changes into one delayed evaluation", function()
    local ns, environment = LoadMissingBuffs()
    local tank = FakeButton("party1")
    ns.MissingBuffs:MarkDirty(tank)
    ns.MissingBuffs:MarkDirty(tank)
    assertEquals(#environment.__state.timers, 1)
    assertNil(tank.healsilusMissing)
    environment.__runTimers()
    assertEquals(tank.healsilusMissing, { "Marca de lo Salvaje", "Espinas" })
  end)
end)
```

- [ ] **Step 2: Añade el fichero a `tests/run.lua` y ejecuta**

Run: `luajit tests/run.lua`
Expected: FAIL — `cannot open Auras/MissingBuffs.lua`.

- [ ] **Step 3: Crea `Auras/MissingBuffs.lua`**

```lua
-- Buffs que faltan: las auras solo se leen cuando el cliente lo permite (fuera de combate y sin restricciones).
-- En combate o en zonas restringidas el último resultado se queda congelado.
local _, ns = ...

local MissingBuffs = { dirty = {}, flushScheduled = false, resolved = {} }
ns.MissingBuffs = MissingBuffs

local FLUSH_DELAY = 0.5

-- watched: { { label, names = {...}, targets = "ALL"|"TANKS" } }; auraPresent(name) → boolean.
function MissingBuffs.Compute(watched, auraPresent, isTank)
  local missing = {}
  for _, entry in ipairs(watched) do
    if entry.targets == "ALL" or (entry.targets == "TANKS" and isTank) then
      local present = false
      for _, name in ipairs(entry.names) do
        if auraPresent(name) then
          present = true
          break
        end
      end
      if not present then
        missing[#missing + 1] = entry.label
      end
    end
  end
  return missing
end

function MissingBuffs:Resolve()
  local resolved = {}
  local buffs = ns.Profiles.active and ns.Profiles.active.buffs
  if buffs and buffs.enabled then
    for _, entry in ipairs(buffs.watched) do
      local name = ns.Spells:GetName(entry.spellID)
      if name then
        local names = { name }
        local groupName = entry.groupSpellID and ns.Spells:GetName(entry.groupSpellID)
        if groupName then
          names[#names + 1] = groupName
        end
        resolved[#resolved + 1] = { label = name, names = names, targets = entry.targets }
      end
    end
  end
  self.resolved = resolved
  return resolved
end

function MissingBuffs.CanRead()
  if InCombatLockdown() then
    return false
  end
  if C_Secrets and C_Secrets.HasSecretRestrictions and C_Secrets.HasSecretRestrictions() then
    return false
  end
  return C_UnitAuras ~= nil and C_UnitAuras.GetAuraDataBySpellName ~= nil
end

local function IsTank(unit)
  if UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) == "TANK" then
    return true
  end
  if GetPartyAssignment and GetPartyAssignment("MAINTANK", unit) then
    return true
  end
  return false
end

function MissingBuffs:Render(button)
  local missing = button.healsilusMissing
  button.healsilus.missingMark:SetShown(missing ~= nil and #missing > 0)
end

function MissingBuffs:Clear(button)
  button.healsilusMissing = nil
  self:Render(button)
end

function MissingBuffs:Evaluate(button)
  if not button.healsilus then
    return
  end
  local unit = button.unit
  if #self.resolved == 0 or not unit then
    self:Clear(button)
    return
  end
  if not MissingBuffs.CanRead() then
    return
  end
  local connected = UnitIsConnected(unit)
  local dead = UnitIsDeadOrGhost(unit)
  if ns.IsSecret(connected) or ns.IsSecret(dead) then
    return
  end
  if not UnitExists(unit) or not connected or dead then
    self:Clear(button)
    return
  end
  button.healsilusMissing = MissingBuffs.Compute(self.resolved, function(name)
    return C_UnitAuras.GetAuraDataBySpellName(unit, name, "HELPFUL") ~= nil
  end, IsTank(unit))
  self:Render(button)
end

function MissingBuffs:Flush()
  self.flushScheduled = false
  local dirty = self.dirty
  self.dirty = {}
  for button in pairs(dirty) do
    self:Evaluate(button)
  end
end

function MissingBuffs:MarkDirty(button)
  if not MissingBuffs.CanRead() then
    return
  end
  self.dirty[button] = true
  if self.flushScheduled then
    return
  end
  self.flushScheduled = true
  C_Timer.After(FLUSH_DELAY, function()
    MissingBuffs:Flush()
  end)
end

function MissingBuffs:RefreshAll()
  self:Resolve()
  if not ns.UnitButton then
    return
  end
  for button in pairs(ns.UnitButton.buttons) do
    self:Evaluate(button)
  end
end

local function RefreshAll()
  MissingBuffs:RefreshAll()
end
ns.Events:Register("PROFILE_CHANGED", RefreshAll)
ns.Events:Register("SPELLBOOK_UPDATED", RefreshAll)
ns.Events:Register("COMBAT_ENDED", RefreshAll)
ns.Events:Register("SETTINGS_CHANGED", function(section)
  if section == "buffs" then
    RefreshAll()
  end
end)
ns.Events:RegisterGameEvent("GROUP_ROSTER_UPDATE", function()
  C_Timer.After(FLUSH_DELAY, function()
    if ns.Profiles.active then
      MissingBuffs:RefreshAll()
    end
  end)
end)
```

- [ ] **Step 4: Añade `Auras\MissingBuffs.lua` al final de la lista de `Healsilus.toc`**

- [ ] **Step 5: Verifica**

Run: `luajit tests/run.lua` → Expected: `96 passed, 0 failed`
Run: `luajit tools/check.lua` → Expected: `check: OK (16 addon files, 34 Lua files)`

- [ ] **Step 6: Commit**

```powershell
git add Auras/MissingBuffs.lua Healsilus.toc tests
git commit -m @'
feat: flag missing buffs out of combat

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
'@
```

### Task 14: Barra de unidad

**Files:**
- Create: `Frames/UnitButton.lua`, `tests/test_unit_button.lua`
- Modify: `Healsilus.toc` (añade `Frames\UnitButton.lua` al final), `tests/run.lua` (añade `"tests/test_unit_button.lua",`), `Locales/enUS.lua`, `Locales/esES.lua`

- [ ] **Step 1: Añade las traducciones**

Al final de `Locales/enUS.lua`:

```lua

-- Barras
L.STATUS_OFFLINE = "Offline"
L.STATUS_DEAD = "Dead"
L.TOOLTIP_MISSING_BUFFS = "Missing: %s"
```

Al final de `Locales/esES.lua`:

```lua

-- Barras
L.STATUS_OFFLINE = "Desconectado"
L.STATUS_DEAD = "Muerto"
L.TOOLTIP_MISSING_BUFFS = "Le falta: %s"
```

- [ ] **Step 2: Escribe la prueba `tests/test_unit_button.lua`**

```lua
local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertFalse, assertNil = Harness.assertEquals, Harness.assertTrue, Harness.assertFalse, Harness.assertNil

local FILES = {
  "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/CombatQueue.lua", "Core/Database.lua",
  "Frames/Media.lua", "Frames/Curves.lua", "Frames/UnitButton.lua",
}

local function LoadUnitButton()
  local environment = Stubs.NewEnvironment()
  local world = { inRange = true, checked = true, threat = nil, missing = 0, connected = true, dead = false }
  environment.UnitIsUnit = function(unit, other)
    return unit == other
  end
  environment.UnitInRange = function()
    return world.inRange, world.checked
  end
  environment.UnitThreatSituation = function()
    return world.threat
  end
  environment.UnitHealthMissing = function()
    return world.missing
  end
  environment.UnitIsConnected = function()
    return world.connected
  end
  environment.UnitIsDeadOrGhost = function()
    return world.dead
  end
  environment.AbbreviateLargeNumbers = function(value)
    if Stubs.IsSecret(value) then
      error("AbbreviateLargeNumbers does not accept secrets")
    end
    return tostring(value)
  end
  local ns = Loader.Load(environment, FILES)
  ns.Profiles = { active = ns.Database.DefaultProfile() }
  return ns, environment, world
end

local function InstallCurves(environment)
  local function Factory()
    local curve = {}
    function curve:SetType() end
    function curve:AddPoint() end
    return curve
  end
  environment.C_CurveUtil = { CreateCurve = Factory, CreateColorCurve = Factory }
  environment.Enum.LuaCurveType = { Linear = 0 }
  environment.CreateColor = function()
    return {}
  end
  environment.UnitHealthPercent = function()
    return 75
  end
end

local function FakeRegion()
  local region = { shown = true }
  function region:SetText(text)
    self.text = text
  end
  function region:SetShown(shown)
    self.shown = shown and true or false
  end
  function region:Hide()
    self.shown = false
  end
  function region:Show()
    self.shown = true
  end
  return region
end

local function FakeButton(unit)
  local button = {
    unit = unit,
    healsilus = { healthText = FakeRegion(), statusText = FakeRegion(), aggroFrame = FakeRegion() },
  }
  function button:SetAlpha(alpha)
    self.alpha = alpha
  end
  function button:SetAlphaFromBoolean(value, whenTrue, whenFalse)
    self.fromBoolean = { value, whenTrue, whenFalse }
  end
  return button
end

describe("UnitButton range", function()
  it("keeps the player and units without range data fully visible", function()
    local ns, _, world = LoadUnitButton()
    local player = FakeButton("player")
    ns.UnitButton:UpdateRange(player)
    assertEquals(player.alpha, 1)
    world.checked = false
    world.inRange = false
    local party = FakeButton("party1")
    ns.UnitButton:UpdateRange(party)
    assertEquals(party.alpha, 1)
  end)

  it("fades readable out-of-range units", function()
    local ns, _, world = LoadUnitButton()
    local party = FakeButton("party1")
    ns.UnitButton:UpdateRange(party)
    assertEquals(party.alpha, 1)
    world.inRange = false
    ns.UnitButton:UpdateRange(party)
    assertEquals(party.alpha, 0.4)
  end)

  it("hands a secret range flag to SetAlphaFromBoolean only when the probe confirmed it works", function()
    local ns, _, world = LoadUnitButton()
    local secret = Stubs.MakeSecret()
    world.inRange = secret
    local party = FakeButton("party1")
    ns.UnitButton.alphaFromBooleanWorks = true
    ns.UnitButton:UpdateRange(party)
    assertTrue(rawequal(party.fromBoolean[1], secret))
    assertEquals(party.fromBoolean[2], 1)
    assertEquals(party.fromBoolean[3], 0.4)
    ns.UnitButton.alphaFromBooleanWorks = false
    party.fromBoolean = nil
    ns.UnitButton:UpdateRange(party)
    assertNil(party.fromBoolean)
    assertEquals(party.alpha, 1)
  end)

  it("probes SetAlphaFromBoolean on a scratch frame", function()
    local ns, environment = LoadUnitButton()
    assertFalse(ns.UnitButton:ProbeAlphaFromBoolean())
    local baseCreateFrame = environment.CreateFrame
    environment.CreateFrame = function(...)
      local frame = baseCreateFrame(...)
      function frame:SetAlphaFromBoolean(value, whenTrue, whenFalse)
        self.alpha = value and whenTrue or whenFalse
      end
      return frame
    end
    assertTrue(ns.UnitButton:ProbeAlphaFromBoolean())
  end)
end)

describe("UnitButton threat", function()
  it("shows the aggro border for readable high threat and hides it otherwise", function()
    local ns, _, world = LoadUnitButton()
    local party = FakeButton("party1")
    world.threat = 3
    ns.UnitButton:UpdateThreat(party)
    assertTrue(party.healsilus.aggroFrame.shown)
    world.threat = 1
    ns.UnitButton:UpdateThreat(party)
    assertFalse(party.healsilus.aggroFrame.shown)
    world.threat = nil
    ns.UnitButton:UpdateThreat(party)
    assertFalse(party.healsilus.aggroFrame.shown)
    world.threat = Stubs.MakeSecret()
    party.healsilus.aggroFrame:Show()
    ns.UnitButton:UpdateThreat(party)
    assertFalse(party.healsilus.aggroFrame.shown)
  end)
end)

describe("UnitButton health text", function()
  it("shows nothing, a deficit or nothing at full health", function()
    local ns, _, world = LoadUnitButton()
    local party = FakeButton("party1")
    ns.UnitButton:UpdateHealthText(party)
    assertEquals(party.healsilus.healthText.text, "")
    world.missing = 2500
    ns.UnitButton:UpdateHealthText(party)
    assertEquals(party.healsilus.healthText.text, "-2500")
    ns.Profiles.active.frames.healthText = "NONE"
    ns.UnitButton:UpdateHealthText(party)
    assertEquals(party.healsilus.healthText.text, "")
  end)

  it("switches a button to percent when the deficit cannot be abbreviated", function()
    local ns, environment, world = LoadUnitButton()
    InstallCurves(environment)
    world.missing = Stubs.MakeSecret()
    local party = FakeButton("party1")
    ns.UnitButton:UpdateHealthText(party)
    assertEquals(party.healsilus.healthText.text, "75%")
    assertEquals(party.healsilusTextMode, "PERCENT")
    assertEquals(ns.Diagnostics.errors[1].context, "UnitButton:DeficitText")
  end)

  it("hides percent text when curves are unavailable", function()
    local ns = LoadUnitButton()
    ns.Profiles.active.frames.healthText = "PERCENT"
    local party = FakeButton("party1")
    ns.UnitButton:UpdateHealthText(party)
    assertEquals(party.healsilus.healthText.text, "")
  end)
end)

describe("UnitButton status", function()
  it("labels offline and dead units and stays quiet with secret flags", function()
    local ns, _, world = LoadUnitButton()
    local party = FakeButton("party1")
    world.connected = false
    ns.UnitButton:UpdateStatus(party)
    assertEquals(party.healsilus.statusText.text, "Offline")
    assertEquals(party.healsilusState, "OFFLINE")
    world.connected = true
    world.dead = true
    ns.UnitButton:UpdateStatus(party)
    assertEquals(party.healsilus.statusText.text, "Dead")
    world.dead = Stubs.MakeSecret()
    ns.UnitButton:UpdateStatus(party)
    assertEquals(party.healsilus.statusText.text, "")
    assertNil(party.healsilusState)
  end)
end)
```

- [ ] **Step 3: Añade el fichero a `tests/run.lua` y ejecuta**

Run: `luajit tests/run.lua`
Expected: FAIL — `cannot open Frames/UnitButton.lua`.

- [ ] **Step 4: Crea `Frames/UnitButton.lua`**

```lua
-- Cada barra de unidad: construcción visual (vale también para la vista previa) y actualización por eventos.
-- Lo que pueda ser secreto va directo a un widget; solo se ramifica sobre valores legibles.
local _, ns = ...
local L = ns.L

local UnitButton = { buttons = {}, alphaFromBooleanWorks = false }
ns.UnitButton = UnitButton

local UNIT_EVENTS = {
  "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_NAME_UPDATE", "UNIT_CONNECTION", "UNIT_FLAGS",
  "UNIT_THREAT_SITUATION_UPDATE", "UNIT_IN_RANGE_UPDATE", "UNIT_HEAL_PREDICTION",
  "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_AURA",
}

local AGGRO_COLOR = { 0.89, 0.29, 0.29 }
local MISSING_COLOR = { 0.94, 0.62, 0.15 }

local function Frames()
  return ns.Profiles.active.frames
end

local function CreateEdge(parent)
  local texture = parent:CreateTexture(nil, "OVERLAY")
  texture:SetColorTexture(AGGRO_COLOR[1], AGGRO_COLOR[2], AGGRO_COLOR[3], 1)
  return texture
end

-- Borde de aggro: cuatro líneas de 2 px por fuera del botón (el anillo interior es para el dispel).
local function BuildAggroFrame(frame)
  local aggroFrame = CreateFrame("Frame", nil, frame)
  aggroFrame:SetAllPoints(frame)
  aggroFrame:SetFrameLevel(frame:GetFrameLevel() + 6)
  local top = CreateEdge(aggroFrame)
  top:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", -2, 0)
  top:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 2, 0)
  top:SetHeight(2)
  local bottom = CreateEdge(aggroFrame)
  bottom:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -2, 0)
  bottom:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 2, 0)
  bottom:SetHeight(2)
  local left = CreateEdge(aggroFrame)
  left:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 0, 0)
  left:SetWidth(2)
  local right = CreateEdge(aggroFrame)
  right:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0)
  right:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 0, 0)
  right:SetWidth(2)
  aggroFrame:Hide()
  return aggroFrame
end

function UnitButton:BuildVisuals(frame)
  local visual = {}
  frame.healsilus = visual

  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(frame)
  background:SetColorTexture(0.06, 0.06, 0.06, 0.9)
  visual.background = background

  local healthBar = CreateFrame("StatusBar", nil, frame)
  healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
  healthBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
  healthBar:SetFrameLevel(frame:GetFrameLevel() + 2)
  healthBar:SetMinMaxValues(0, 1)
  healthBar:SetValue(1)
  visual.healthBar = healthBar

  local textFrame = CreateFrame("Frame", nil, frame)
  textFrame:SetAllPoints(healthBar)
  textFrame:SetFrameLevel(frame:GetFrameLevel() + 5)
  visual.textFrame = textFrame

  local nameText = textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  nameText:SetPoint("TOPLEFT", healthBar, "TOPLEFT", 4, -3)
  nameText:SetPoint("TOPRIGHT", healthBar, "TOPRIGHT", -4, -3)
  nameText:SetJustifyH("LEFT")
  nameText:SetWordWrap(false)
  visual.nameText = nameText

  local healthText = textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  healthText:SetPoint("BOTTOMLEFT", healthBar, "BOTTOMLEFT", 4, 3)
  healthText:SetJustifyH("LEFT")
  visual.healthText = healthText

  local statusText = textFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  statusText:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", -4, 3)
  visual.statusText = statusText

  local missingMark = textFrame:CreateTexture(nil, "OVERLAY")
  missingMark:SetSize(7, 7)
  missingMark:SetPoint("TOPLEFT", healthBar, "TOPLEFT", 0, 0)
  missingMark:SetColorTexture(MISSING_COLOR[1], MISSING_COLOR[2], MISSING_COLOR[3], 1)
  missingMark:Hide()
  visual.missingMark = missingMark

  visual.aggroFrame = BuildAggroFrame(frame)
  self:ApplyStyle(frame)
  return visual
end

function UnitButton:ApplyStyle(frame)
  frame.healsilus.healthBar:SetStatusBarTexture(ns.Media.Texture(Frames().texture))
end

function UnitButton:ApplyClickRegistration(button)
  ns.CombatQueue:Run("clicks:" .. tostring(button), function()
    button:RegisterForClicks(Frames().castOnDown and "AnyDown" or "AnyUp")
  end)
end

-- Se llama desde la initialConfigFunction de una cabecera o al crear objetivo/foco.
function UnitButton:Init(button, kind)
  if button.healsilus then
    return
  end
  self:BuildVisuals(button)
  button.healsilusKind = kind
  local eventFrame = CreateFrame("Frame", nil, button)
  eventFrame:SetScript("OnEvent", function(_, event)
    UnitButton:OnUnitEvent(button, event)
  end)
  button.healsilusEvents = eventFrame
  button:HookScript("OnAttributeChanged", function(self, name, value)
    if name == "unit" then
      UnitButton:SetUnit(self, value)
    end
  end)
  button:HookScript("OnEnter", function(self)
    UnitButton:ShowTooltip(self)
  end)
  button:HookScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  self.buttons[button] = true
  ns.ClickCast:AdoptButton(button)
  self:ApplyClickRegistration(button)
  ns.Prediction:Attach(button)
  self:SetUnit(button, button:GetAttribute("unit"))
end

function UnitButton:SetUnit(button, unit)
  button.unit = unit
  local eventFrame = button.healsilusEvents
  eventFrame:UnregisterAllEvents()
  if unit then
    for _, event in ipairs(UNIT_EVENTS) do
      if ns.IsEventValid(event) then
        eventFrame:RegisterUnitEvent(event, unit)
      end
    end
  end
  ns.Containers:SetUnit(button, unit)
  self:UpdateAll(button)
end

function UnitButton:UpdateAll(button)
  local unit = button.unit
  if not unit or not UnitExists(unit) then
    ns.Prediction:Hide(button)
    return
  end
  self:UpdateName(button)
  self:UpdateStatus(button)
  self:UpdateHealth(button)
  self:UpdateColor(button)
  self:UpdateRange(button)
  self:UpdateThreat(button)
  ns.Prediction:Update(button)
  ns.MissingBuffs:Evaluate(button)
end

function UnitButton:UpdateName(button)
  local name = UnitName(button.unit)
  button.healsilus.nameText:SetText(name)
end

function UnitButton:UpdateHealth(button)
  local unit = button.unit
  local healthBar = button.healsilus.healthBar
  healthBar:SetMinMaxValues(0, UnitHealthMax(unit))
  healthBar:SetValue(UnitHealth(unit))
  self:UpdateHealthText(button)
end

function UnitButton:UpdateHealthText(button)
  local text = button.healsilus.healthText
  local mode = button.healsilusTextMode or Frames().healthText
  if mode == "DEFICIT" and not UnitHealthMissing then
    mode = "PERCENT"
  end
  if mode == "PERCENT" and not ns.Curves.IsSupported() then
    mode = "NONE"
  end
  if mode == "NONE" then
    text:SetText("")
    return
  end
  local unit = button.unit
  if mode == "PERCENT" then
    text:SetText(string.format("%.0f%%", UnitHealthPercent(unit, true, ns.Curves:Percent())))
    return
  end
  local missing = UnitHealthMissing(unit)
  if not ns.IsSecret(missing) and missing <= 0 then
    text:SetText("")
    return
  end
  local ok, abbreviated = pcall(AbbreviateLargeNumbers, missing)
  if not ok then
    button.healsilusTextMode = "PERCENT"
    ns.RecordError("UnitButton:DeficitText", abbreviated)
    self:UpdateHealthText(button)
    return
  end
  text:SetText("-" .. abbreviated)
end

function UnitButton:UpdateStatus(button)
  local unit = button.unit
  local statusText = button.healsilus.statusText
  local connected = UnitIsConnected(unit)
  local dead = UnitIsDeadOrGhost(unit)
  if ns.IsSecret(connected) or ns.IsSecret(dead) then
    button.healsilusState = nil
    statusText:SetText("")
    return
  end
  if not connected then
    button.healsilusState = "OFFLINE"
    statusText:SetText(L.STATUS_OFFLINE)
  elseif dead then
    button.healsilusState = "DEAD"
    statusText:SetText(L.STATUS_DEAD)
  else
    button.healsilusState = nil
    statusText:SetText("")
  end
end

function UnitButton:UpdateColor(button)
  local texture = button.healsilus.healthBar:GetStatusBarTexture()
  if button.healsilusState then
    local color = ns.Media.OFFLINE_COLOR
    texture:SetVertexColor(color.r, color.g, color.b)
    return
  end
  if Frames().colorMode == "HEALTH" and ns.Curves.IsSupported() then
    local color = UnitHealthPercent(button.unit, true, ns.Curves:HealthColor())
    texture:SetVertexColor(color:GetRGB())
    return
  end
  if button.healsilusKind == "pets" then
    local color = ns.Media.PET_COLOR
    texture:SetVertexColor(color.r, color.g, color.b)
    return
  end
  local _, classToken = UnitClass(button.unit)
  texture:SetVertexColor(ns.Media.ClassColor(classToken))
end

function UnitButton:UpdateRange(button)
  local unit = button.unit
  local fadedAlpha = Frames().outOfRangeAlpha
  local isPlayer = UnitIsUnit(unit, "player")
  if not ns.IsSecret(isPlayer) and isPlayer then
    button:SetAlpha(1)
    return
  end
  local inRange, checked = UnitInRange(unit)
  if not ns.IsSecret(checked) and not checked then
    button:SetAlpha(1)
    return
  end
  if ns.IsSecret(inRange) then
    if self.alphaFromBooleanWorks then
      button:SetAlphaFromBoolean(inRange, 1, fadedAlpha)
    else
      button:SetAlpha(1)
    end
    return
  end
  button:SetAlpha(inRange and 1 or fadedAlpha)
end

function UnitButton:UpdateThreat(button)
  local status = UnitThreatSituation(button.unit)
  local aggroFrame = button.healsilus.aggroFrame
  if ns.IsSecret(status) then
    aggroFrame:Hide()
    return
  end
  aggroFrame:SetShown(status ~= nil and status >= 2)
end

-- Comprueba en un marco de prueba que SetAlphaFromBoolean existe y aplica los dos valores.
function UnitButton:ProbeAlphaFromBoolean()
  local probe = CreateFrame("Frame", nil, UIParent)
  local ok, works = pcall(function()
    probe:SetAlphaFromBoolean(false, 1, 0.25)
    if math.abs(probe:GetAlpha() - 0.25) > 0.01 then
      return false
    end
    probe:SetAlphaFromBoolean(true, 1, 0.25)
    return math.abs(probe:GetAlpha() - 1) <= 0.01
  end)
  probe:Hide()
  if not ok then
    ns.RecordError("UnitButton:ProbeAlphaFromBoolean", works)
  end
  self.alphaFromBooleanWorks = ok and works == true
  return self.alphaFromBooleanWorks
end

function UnitButton:ShowTooltip(button)
  if not button.unit then
    return
  end
  GameTooltip_SetDefaultAnchor(GameTooltip, button)
  GameTooltip:SetUnit(button.unit)
  local missing = button.healsilusMissing
  if missing and #missing > 0 then
    GameTooltip:AddLine(string.format(L.TOOLTIP_MISSING_BUFFS, table.concat(missing, ", ")),
      MISSING_COLOR[1], MISSING_COLOR[2], MISSING_COLOR[3])
  end
  GameTooltip:Show()
end

local function UpdateHealthEvent(button)
  UnitButton:UpdateStatus(button)
  UnitButton:UpdateHealth(button)
  UnitButton:UpdateColor(button)
  ns.Prediction:Update(button)
end

local function UpdateStatusEvent(button)
  UnitButton:UpdateStatus(button)
  UnitButton:UpdateColor(button)
end

local HANDLERS = {
  UNIT_HEALTH = UpdateHealthEvent,
  UNIT_MAXHEALTH = UpdateHealthEvent,
  UNIT_NAME_UPDATE = function(button)
    UnitButton:UpdateName(button)
  end,
  UNIT_CONNECTION = UpdateStatusEvent,
  UNIT_FLAGS = UpdateStatusEvent,
  UNIT_THREAT_SITUATION_UPDATE = function(button)
    UnitButton:UpdateThreat(button)
  end,
  UNIT_IN_RANGE_UPDATE = function(button)
    UnitButton:UpdateRange(button)
  end,
  UNIT_HEAL_PREDICTION = function(button)
    ns.Prediction:Update(button)
  end,
  UNIT_ABSORB_AMOUNT_CHANGED = function(button)
    ns.Prediction:Update(button)
  end,
  UNIT_AURA = function(button)
    ns.MissingBuffs:MarkDirty(button)
  end,
}

function UnitButton:OnUnitEvent(button, event)
  local handler = HANDLERS[event]
  if handler and button.unit then
    handler(button)
  end
end

function UnitButton:UpdateAllButtons()
  for button in pairs(self.buttons) do
    self:UpdateAll(button)
  end
end

-- Objetivo y foco cambian de entidad sin cambiar de token.
function UnitButton:UpdateUnitToken(token)
  for button in pairs(self.buttons) do
    if button.unit == token then
      ns.Containers:SetUnit(button, token)
      self:UpdateAll(button)
    end
  end
end

function UnitButton:ApplyVisualSettings()
  for button in pairs(self.buttons) do
    button.healsilusTextMode = nil
    self:ApplyStyle(button)
    self:ApplyClickRegistration(button)
    self:UpdateAll(button)
  end
end

function UnitButton:Initialize()
  self:ProbeAlphaFromBoolean()
  ns.Events:RegisterGameEvent("GROUP_ROSTER_UPDATE", function()
    UnitButton:UpdateAllButtons()
  end)
  ns.Events:RegisterGameEvent("PLAYER_ENTERING_WORLD", function()
    UnitButton:UpdateAllButtons()
  end)
  ns.Events:RegisterGameEvent("PLAYER_TARGET_CHANGED", function()
    UnitButton:UpdateUnitToken("target")
  end)
  ns.Events:RegisterGameEvent("PLAYER_FOCUS_CHANGED", function()
    UnitButton:UpdateUnitToken("focus")
  end)
end

ns.Events:Register("PROFILE_CHANGED", function()
  UnitButton:ApplyVisualSettings()
end)

ns.Events:Register("SETTINGS_CHANGED", function(section)
  if section == "frames" then
    UnitButton:ApplyVisualSettings()
  end
end)
```

- [ ] **Step 5: Añade `Frames\UnitButton.lua` al final de la lista de `Healsilus.toc`**

- [ ] **Step 6: Verifica**

Run: `luajit tests/run.lua` → Expected: `105 passed, 0 failed`
Run: `luajit tools/check.lua` → Expected: `check: OK (17 addon files, 36 Lua files)`

- [ ] **Step 7: Commit**

```powershell
git add Frames/UnitButton.lua Locales Healsilus.toc tests
git commit -m @'
feat: build and update secret-safe unit bars

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
'@
```

### Task 15: Cabeceras seguras, anclas, objetivo/foco y marcos de Blizzard

**Files:**
- Create: `Frames/Headers.lua`, `tests/test_headers.lua`
- Modify: `Healsilus.toc` (añade `Frames\Headers.lua` al final), `tests/run.lua` (añade `"tests/test_headers.lua",`), `Locales/enUS.lua`, `Locales/esES.lua`

- [ ] **Step 1: Añade las traducciones**

Al final de `Locales/enUS.lua`:

```lua

-- Anclas
L.ANCHOR_PARTY = "Healsilus: party/raid"
L.ANCHOR_TANKS = "Healsilus: tanks"
L.ANCHOR_PETS = "Healsilus: pets"
L.ANCHOR_TARGET = "Healsilus: target"
L.ANCHOR_FOCUS = "Healsilus: focus"
```

Al final de `Locales/esES.lua`:

```lua

-- Anclas
L.ANCHOR_PARTY = "Healsilus: grupo/banda"
L.ANCHOR_TANKS = "Healsilus: tanques"
L.ANCHOR_PETS = "Healsilus: mascotas"
L.ANCHOR_TARGET = "Healsilus: objetivo"
L.ANCHOR_FOCUS = "Healsilus: foco"
```

- [ ] **Step 2: Escribe la prueba `tests/test_headers.lua`**

```lua
local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue = Harness.assertEquals, Harness.assertTrue

local FILES = {
  "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/CombatQueue.lua", "Core/Database.lua",
  "Frames/Media.lua", "Frames/Headers.lua",
}

local function LoadHeaders()
  local environment = Stubs.NewEnvironment()
  local ns = Loader.Load(environment, FILES)
  return ns, environment
end

local function FakeHeader(kind)
  local header = { healsilusKind = kind, attributes = {}, history = {}, shown = false }
  function header:SetAttribute(name, value)
    self.attributes[name] = value
    self.history[#self.history + 1] = name .. "=" .. tostring(value)
  end
  function header:GetAttribute(name)
    return self.attributes[name]
  end
  function header:Show()
    self.shown = true
    self.history[#self.history + 1] = "Show"
  end
  return header
end

local function FakeChild()
  local child = {}
  function child:SetSize(width, height)
    self.size = { width, height }
  end
  return child
end

describe("Headers layout", function()
  it("lays out the party header downwards, sorted by group", function()
    local ns = LoadHeaders()
    local header = FakeHeader("party")
    ns.Headers:ApplyHeaderLayout(header, ns.Database.DefaultProfile().frames)
    local attributes = header.attributes
    assertEquals(attributes["hs-width"], 110)
    assertEquals(attributes["hs-height"], 34)
    assertEquals(attributes.point, "TOP")
    assertEquals(attributes.xOffset, 0)
    assertEquals(attributes.yOffset, -2)
    assertEquals(attributes.columnAnchorPoint, "LEFT")
    assertEquals(attributes.columnSpacing, 2)
    assertEquals(attributes.groupBy, "GROUP")
    assertEquals(attributes.groupingOrder, "1,2,3,4,5,6,7,8")
    assertEquals(attributes.groupFilter, "1,2,3,4,5,6,7,8")
    assertEquals(attributes.unitsPerColumn, 5)
    assertEquals(attributes.maxColumns, 8)
    assertTrue(attributes.showSolo)
    assertTrue(attributes.showRaid and attributes.showParty and attributes.showPlayer)
  end)

  it("grows to the right and sorts by class when asked", function()
    local ns = LoadHeaders()
    local frames = ns.Database.DefaultProfile().frames
    frames.growth = "RIGHT"
    frames.sortBy = "CLASS"
    local header = FakeHeader("party")
    ns.Headers:ApplyHeaderLayout(header, frames)
    assertEquals(header.attributes.point, "LEFT")
    assertEquals(header.attributes.xOffset, 2)
    assertEquals(header.attributes.yOffset, 0)
    assertEquals(header.attributes.columnAnchorPoint, "TOP")
    assertEquals(header.attributes.groupBy, "CLASS")
  end)

  it("filters the tanks header by role in a single column", function()
    local ns = LoadHeaders()
    local header = FakeHeader("tanks")
    ns.Headers:ApplyHeaderLayout(header, ns.Database.DefaultProfile().frames)
    assertEquals(header.attributes.roleFilter, "MAINTANK,TANK")
    assertEquals(header.attributes.showSolo, false)
    assertEquals(header.attributes.unitsPerColumn, 8)
    assertEquals(header.attributes.maxColumns, 1)
  end)

  it("resizes buttons the header already created", function()
    local ns = LoadHeaders()
    local header = FakeHeader("party")
    header.attributes.child1, header.attributes.child2 = FakeChild(), FakeChild()
    local frames = ns.Database.DefaultProfile().frames
    frames.width, frames.height = 90, 30
    ns.Headers:ApplyHeaderLayout(header, frames)
    assertEquals(header.attributes.child1.size, { 90, 30 })
    assertEquals(header.attributes.child2.size, { 90, 30 })
    assertEquals(ns.Headers:CountButtons(header), 2)
  end)

  it("precreates every button by showing with a negative starting index", function()
    local ns = LoadHeaders()
    local header = FakeHeader("party")
    ns.Headers:Precreate(header)
    assertEquals(header.history, { "unitsPerColumn=40", "maxColumns=1", "startingIndex=-39", "Show", "startingIndex=1" })
  end)
end)

describe("Headers and Blizzard frames", function()
  it("moves Blizzard party and raid frames to a hidden parent and restores them", function()
    local ns, environment = LoadHeaders()
    local original = {}
    local party = {}
    function party:GetParent()
      return self.parent
    end
    function party:SetParent(parent)
      self.parent = parent
    end
    party.parent = original
    environment.CompactPartyFrame = party
    ns.Headers:ApplyBlizzardVisibility(true)
    assertTrue(party.parent ~= original)
    ns.Headers:ApplyBlizzardVisibility(true)
    ns.Headers:ApplyBlizzardVisibility(false)
    assertTrue(party.parent == original)
  end)
end)
```

- [ ] **Step 3: Añade el fichero a `tests/run.lua` y ejecuta**

Run: `luajit tests/run.lua`
Expected: FAIL — `cannot open Frames/Headers.lua`.

- [ ] **Step 4: Crea `Frames/Headers.lua`**

```lua
-- Cabeceras seguras (SecureGroupHeaderTemplate): ordenan y crean los botones sin taint, también en combate.
-- Botones sueltos para objetivo y foco amistosos, anclas movibles y ocultación de los marcos de Blizzard.
local _, ns = ...
local L = ns.L

local Headers = { list = {}, byKind = {}, anchors = {}, singles = {}, initialized = false, previewActive = false }
ns.Headers = Headers

local MAX_BUTTONS = { party = 40, tanks = 8, pets = 20 }

local DEFAULT_POSITIONS = {
  party = { "TOPLEFT", 30, -220 },
  tanks = { "TOPLEFT", 30, -130 },
  pets = { "TOPLEFT", 400, -220 },
  target = { "TOPLEFT", 30, -60 },
  focus = { "TOPLEFT", 160, -60 },
}

local ANCHOR_LABELS = {
  party = L.ANCHOR_PARTY,
  tanks = L.ANCHOR_TANKS,
  pets = L.ANCHOR_PETS,
  target = L.ANCHOR_TARGET,
  focus = L.ANCHOR_FOCUS,
}

local SORT_ATTRIBUTES = {
  GROUP = { groupBy = "GROUP", groupingOrder = "1,2,3,4,5,6,7,8" },
  CLASS = { groupBy = "CLASS", groupingOrder = "WARRIOR,PALADIN,DRUID,PRIEST,SHAMAN,ROGUE,HUNTER,MAGE,WARLOCK" },
  ROLE = { groupBy = "ASSIGNEDROLE", groupingOrder = "TANK,HEALER,DAMAGER,NONE" },
}

-- Entorno restringido: cada botón nuevo toma tamaño y clics de su cabecera y pide su parte visual.
local INITIAL_CONFIG = [[
  local header = self:GetParent()
  self:SetWidth(header:GetAttribute("hs-width"))
  self:SetHeight(header:GetAttribute("hs-height"))
  local count = header:GetAttribute("hs-attr-count") or 0
  for position = 1, count do
    self:SetAttribute(header:GetAttribute("hs-attr-name-" .. position), header:GetAttribute("hs-attr-value-" .. position))
  end
  header:CallMethod("InitButton", self:GetName())
]]

local BLIZZARD_FRAMES = { "CompactPartyFrame", "CompactRaidFrameContainer", "CompactRaidFrameManager", "PartyFrame" }

local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()
local originalParents = {}

local function SetAttributes(header, attributes)
  for name, value in pairs(attributes) do
    header:SetAttribute(name, value)
  end
end

local function SavePosition(kind, anchor)
  local point, _, _, x, y = anchor:GetPoint(1)
  ns.Database.db.framePositions[kind] = { point, x, y }
end

local function CreateAnchor(kind)
  local anchor = CreateFrame("Frame", "HealsilusAnchor_" .. kind, UIParent)
  anchor:SetSize(16, 16)
  anchor:SetMovable(true)
  anchor:SetClampedToScreen(true)
  local position = ns.Database.db.framePositions[kind] or DEFAULT_POSITIONS[kind]
  anchor:SetPoint(position[1], UIParent, position[1], position[2], position[3])
  local handle = anchor:CreateTexture(nil, "OVERLAY")
  handle:SetAllPoints(anchor)
  handle:SetColorTexture(0.2, 0.6, 1, 0.8)
  local label = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetPoint("LEFT", anchor, "RIGHT", 4, 0)
  label:SetText(ANCHOR_LABELS[kind])
  anchor.handle, anchor.label = handle, label
  anchor:RegisterForDrag("LeftButton")
  anchor:SetScript("OnDragStart", function(self)
    if not InCombatLockdown() then
      self:StartMoving()
    end
  end)
  anchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition(kind, self)
  end)
  Headers.anchors[kind] = anchor
  return anchor
end

local function CreateHeader(kind, template)
  local header = CreateFrame("Frame", "HealsilusHeader_" .. kind, UIParent, template)
  header.healsilusKind = kind
  header:SetAttribute("template", "SecureActionButtonTemplate")
  header:SetAttribute("initialConfigFunction", INITIAL_CONFIG)
  header.InitButton = function(_, buttonName)
    local button = _G[buttonName]
    if button then
      ns.UnitButton:Init(button, kind)
    end
  end
  header:SetPoint("TOPLEFT", Headers.anchors[kind], "BOTTOMLEFT", 0, -2)
  Headers.list[#Headers.list + 1] = header
  Headers.byKind[kind] = header
  return header
end

function Headers:CreateSingle(kind, visibility)
  local button = CreateFrame("Button", "HealsilusUnit_" .. kind, UIParent, "SecureActionButtonTemplate")
  button:SetAttribute("unit", kind)
  local frames = ns.Profiles.active.frames
  button:SetSize(frames.width, frames.height)
  button:SetPoint("TOPLEFT", self.anchors[kind], "BOTTOMLEFT", 0, -2)
  button.healsilusVisibility = visibility
  self.singles[kind] = button
  ns.UnitButton:Init(button, kind)
  return button
end

function Headers:ApplyHeaderLayout(header, frames)
  local kind = header.healsilusKind
  local down = frames.growth == "DOWN"
  SetAttributes(header, {
    ["hs-width"] = frames.width,
    ["hs-height"] = frames.height,
    point = down and "TOP" or "LEFT",
    xOffset = down and 0 or frames.spacing,
    yOffset = down and -frames.spacing or 0,
    columnAnchorPoint = down and "LEFT" or "TOP",
    columnSpacing = frames.spacing,
    showRaid = true,
    showParty = true,
    showPlayer = true,
  })
  if kind == "tanks" then
    SetAttributes(header, { roleFilter = "MAINTANK,TANK", showSolo = false, unitsPerColumn = MAX_BUTTONS.tanks, maxColumns = 1 })
  elseif kind == "pets" then
    SetAttributes(header, { showSolo = frames.showSolo, unitsPerColumn = frames.unitsPerColumn, maxColumns = frames.columns })
  else
    local sort = SORT_ATTRIBUTES[frames.sortBy]
    SetAttributes(header, {
      showSolo = frames.showSolo, unitsPerColumn = frames.unitsPerColumn, maxColumns = frames.columns,
      groupBy = sort.groupBy, groupingOrder = sort.groupingOrder, groupFilter = "1,2,3,4,5,6,7,8",
    })
  end
  -- Los botones ya creados no vuelven a pasar por initialConfigFunction: se redimensionan aquí.
  local position = 1
  local child = header:GetAttribute("child1")
  while child do
    child:SetSize(frames.width, frames.height)
    position = position + 1
    child = header:GetAttribute("child" .. position)
  end
end

function Headers:CountButtons(header)
  local count = 0
  while header:GetAttribute("child" .. (count + 1)) do
    count = count + 1
  end
  return count
end

-- Con startingIndex negativo la cabecera cree que hay más unidades y crea todos sus botones ya,
-- fuera de combate, para que nunca haga falta crear botones ni contenedores de auras en combate.
function Headers:Precreate(header)
  local maximum = MAX_BUTTONS[header.healsilusKind]
  header:SetAttribute("unitsPerColumn", maximum)
  header:SetAttribute("maxColumns", 1)
  header:SetAttribute("startingIndex", 1 - maximum)
  header:Show()
  header:SetAttribute("startingIndex", 1)
end

function Headers:ApplyBlizzardVisibility(hide)
  for _, name in ipairs(BLIZZARD_FRAMES) do
    local frame = _G[name]
    if frame then
      if hide then
        if not originalParents[name] then
          originalParents[name] = frame:GetParent()
        end
        frame:SetParent(hiddenParent)
      elseif originalParents[name] then
        frame:SetParent(originalParents[name])
        originalParents[name] = nil
      end
    end
  end
end

function Headers:SetLocked(locked)
  for _, anchor in pairs(self.anchors) do
    anchor.handle:SetShown(not locked)
    anchor.label:SetShown(not locked)
    anchor:EnableMouse(not locked)
  end
end

function Headers:SetHeaderShown(kind, shown)
  local header = self.byKind[kind]
  if header then
    header:SetShown(shown)
  end
end

function Headers:Create()
  if self.initialized then
    return
  end
  local frames = ns.Profiles.active.frames
  for _, kind in ipairs({ "party", "tanks", "pets", "target", "focus" }) do
    CreateAnchor(kind)
  end
  CreateHeader("party", "SecureGroupHeaderTemplate")
  CreateHeader("tanks", "SecureGroupHeaderTemplate")
  CreateHeader("pets", "SecureGroupPetHeaderTemplate")
  self:CreateSingle("target", "[@target,help,exists] show; hide")
  self:CreateSingle("focus", "[@focus,help,exists] show; hide")
  -- Los clics se guardan en las cabeceras antes de que existan sus botones.
  ns.ClickCast:Apply(ns.Profiles.active)
  for _, header in ipairs(self.list) do
    self:Precreate(header)
    self:ApplyHeaderLayout(header, frames)
  end
  self.initialized = true
  self:ApplyProfile(ns.Profiles.active)
end

function Headers:Initialize()
  ns.CombatQueue:Run("headers:create", function()
    Headers:Create()
  end)
end

function Headers:ApplyProfile(profile)
  if not self.initialized then
    return
  end
  ns.CombatQueue:Run("headers:apply", function()
    local frames = profile.frames
    for _, header in ipairs(Headers.list) do
      Headers:ApplyHeaderLayout(header, frames)
    end
    Headers:SetHeaderShown("party", not Headers.previewActive)
    Headers:SetHeaderShown("tanks", frames.showTanks and not Headers.previewActive)
    Headers:SetHeaderShown("pets", frames.showPets and not Headers.previewActive)
    for kind, button in pairs(Headers.singles) do
      button:SetSize(frames.width, frames.height)
      local enabled = (kind == "target" and frames.showTarget) or (kind == "focus" and frames.showFocus)
      RegisterStateDriver(button, "visibility", enabled and button.healsilusVisibility or "hide")
    end
    Headers:ApplyBlizzardVisibility(frames.hideBlizzard)
    Headers:SetLocked(frames.locked)
    ns.ClickCast:Apply(profile)
  end)
end

ns.Events:Register("PROFILE_CHANGED", function(profile)
  Headers:ApplyProfile(profile)
end)

ns.Events:Register("SETTINGS_CHANGED", function(section)
  if section == "frames" then
    Headers:ApplyProfile(ns.Profiles.active)
  end
end)
```

- [ ] **Step 5: Añade `Frames\Headers.lua` al final de la lista de `Healsilus.toc`**

- [ ] **Step 6: Verifica**

Run: `luajit tests/run.lua` → Expected: `111 passed, 0 failed`
Run: `luajit tools/check.lua` → Expected: `check: OK (18 addon files, 38 Lua files)`

- [ ] **Step 7: Commit**

```powershell
git add Frames/Headers.lua Locales Healsilus.toc tests
git commit -m @'
feat: add secure group headers, anchors and Blizzard frame hiding

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
'@
```

### Task 16: Vista previa con miembros falsos

**Files:**
- Create: `Frames/Preview.lua`, `tests/test_preview.lua`
- Modify: `Healsilus.toc` (añade `Frames\Preview.lua` al final), `tests/run.lua` (añade `"tests/test_preview.lua",`), `Locales/enUS.lua`, `Locales/esES.lua`

- [ ] **Step 1: Añade las traducciones**

Al final de `Locales/enUS.lua`:

```lua

-- Vista previa
L.PREVIEW_COMBAT = "Preview is not available in combat."
```

Al final de `Locales/esES.lua`:

```lua

-- Vista previa
L.PREVIEW_COMBAT = "La vista previa no está disponible en combate."
```

- [ ] **Step 2: Escribe la prueba `tests/test_preview.lua`**

```lua
local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals = Harness.assertEquals

local function LoadPreview()
  local environment = Stubs.NewEnvironment()
  local ns = Loader.Load(environment, {
    "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/Database.lua", "Frames/Preview.lua",
  })
  return ns, environment
end

describe("Preview", function()
  it("places fake members in columns when growing down", function()
    local ns = LoadPreview()
    local frames = ns.Database.DefaultProfile().frames
    assertEquals({ ns.Preview.Offset(1, frames) }, { 0, 0 })
    assertEquals({ ns.Preview.Offset(2, frames) }, { 0, -36 })
    assertEquals({ ns.Preview.Offset(6, frames) }, { 112, 0 })
  end)

  it("places fake members in rows when growing right", function()
    local ns = LoadPreview()
    local frames = ns.Database.DefaultProfile().frames
    frames.growth = "RIGHT"
    assertEquals({ ns.Preview.Offset(2, frames) }, { 112, 0 })
    assertEquals({ ns.Preview.Offset(6, frames) }, { 0, -36 })
  end)

  it("colors fake health from red through yellow to green", function()
    local ns = LoadPreview()
    assertEquals({ ns.Preview.HealthColor(0) }, { 1, 0, 0 })
    assertEquals({ ns.Preview.HealthColor(0.5) }, { 1, 1, 0 })
    assertEquals({ ns.Preview.HealthColor(1) }, { 0, 1, 0 })
  end)

  it("refuses to open in combat", function()
    local ns, environment = LoadPreview()
    environment.__state.inCombat = true
    ns.Preview:Show(5)
    assertEquals(ns.Preview.count, 0)
    assertEquals(environment.__state.printed[1], "|cff33ff99Healsilus:|r Preview is not available in combat.")
  end)
end)
```

- [ ] **Step 3: Añade el fichero a `tests/run.lua` y ejecuta**

Run: `luajit tests/run.lua`
Expected: FAIL — `cannot open Frames/Preview.lua`.

- [ ] **Step 4: Crea `Frames/Preview.lua`**

```lua
-- Vista previa: marcos NO seguros con miembros falsos para ver el diseño sin estar en grupo.
-- Mientras está abierta, la cabecera de grupo se oculta; al entrar en combate se cierra sola.
local _, ns = ...
local L = ns.L

local Preview = { frames = {}, count = 0 }
ns.Preview = Preview

local FAKE_MEMBERS = {
  { name = "Gromash", class = "WARRIOR", health = 0.62, aggro = true },
  { name = "Arsilus", class = "DRUID", health = 1 },
  { name = "Velenna", class = "PRIEST", health = 0.48 },
  { name = "Thrall", class = "SHAMAN", health = 0.85, missing = true },
  { name = "Lejana", class = "MAGE", health = 0.7, outOfRange = true },
  { name = "Korgan", class = "ROGUE", health = 0, dead = true },
  { name = "Sylvara", class = "HUNTER", health = 0.93 },
  { name = "Morvath", class = "WARLOCK", health = 0.35 },
  { name = "Brannoc", class = "PALADIN", health = 0.77 },
}

local FAKE_MAX_HEALTH = 8000

function Preview.Offset(position, frames)
  local column = math.floor((position - 1) / frames.unitsPerColumn)
  local row = (position - 1) % frames.unitsPerColumn
  local stepX, stepY = frames.width + frames.spacing, frames.height + frames.spacing
  if frames.growth == "DOWN" then
    return column * stepX, -row * stepY
  end
  return row * stepX, -column * stepY
end

-- Valores falsos y legibles: aquí sí se puede calcular el color en Lua.
function Preview.HealthColor(fraction)
  if fraction < 0.5 then
    return 1, fraction * 2, 0
  end
  return (1 - fraction) * 2, 1, 0
end

local function HealthText(mode, fraction)
  if mode == "PERCENT" then
    return string.format("%d%%", math.floor(fraction * 100 + 0.5))
  end
  if mode == "DEFICIT" and fraction < 1 then
    return "-" .. AbbreviateLargeNumbers(math.floor((1 - fraction) * FAKE_MAX_HEALTH))
  end
  return ""
end

function Preview:Paint(frame, member, frames)
  local visual = frame.healsilus
  frame:SetSize(frames.width, frames.height)
  ns.UnitButton:ApplyStyle(frame)
  visual.healthBar:SetMinMaxValues(0, 1)
  visual.healthBar:SetValue(member.health)
  visual.nameText:SetText(member.name)
  visual.healthText:SetText(member.dead and "" or HealthText(frames.healthText, member.health))
  visual.statusText:SetText(member.dead and L.STATUS_DEAD or "")
  local texture = visual.healthBar:GetStatusBarTexture()
  if frames.colorMode == "HEALTH" then
    texture:SetVertexColor(Preview.HealthColor(member.health))
  else
    texture:SetVertexColor(ns.Media.ClassColor(member.class))
  end
  visual.missingMark:SetShown(member.missing == true)
  visual.aggroFrame:SetShown(member.aggro == true)
  frame:SetAlpha(member.outOfRange and frames.outOfRangeAlpha or 1)
end

function Preview:Show(count)
  if InCombatLockdown() then
    ns.Print(L.PREVIEW_COMBAT)
    return
  end
  self:HideFrames()
  ns.Headers.previewActive = true
  ns.Headers:ApplyProfile(ns.Profiles.active)
  local frames = ns.Profiles.active.frames
  local anchor = ns.Headers.anchors.party
  for position = 1, count do
    local frame = self.frames[position]
    if not frame then
      frame = CreateFrame("Frame", nil, UIParent)
      ns.UnitButton:BuildVisuals(frame)
      self.frames[position] = frame
    end
    local x, y = Preview.Offset(position, frames)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x, y - 2)
    self:Paint(frame, FAKE_MEMBERS[(position - 1) % #FAKE_MEMBERS + 1], frames)
    frame:Show()
  end
  self.count = count
end

function Preview:HideFrames()
  for _, frame in ipairs(self.frames) do
    frame:Hide()
  end
end

function Preview:Hide()
  self:HideFrames()
  self.count = 0
  if ns.Headers.previewActive then
    ns.Headers.previewActive = false
    ns.Headers:ApplyProfile(ns.Profiles.active)
  end
end

-- PLAYER_REGEN_DISABLED llega justo antes del bloqueo: aún se puede volver a mostrar la cabecera.
ns.Events:Register("COMBAT_STARTED", function()
  if Preview.count > 0 then
    Preview:Hide()
  end
end)

ns.Events:Register("SETTINGS_CHANGED", function(section)
  if section == "frames" and Preview.count > 0 then
    Preview:Show(Preview.count)
  end
end)
```

- [ ] **Step 5: Añade `Frames\Preview.lua` al final de la lista de `Healsilus.toc`**

- [ ] **Step 6: Verifica**

Run: `luajit tests/run.lua` → Expected: `115 passed, 0 failed`
Run: `luajit tools/check.lua` → Expected: `check: OK (19 addon files, 40 Lua files)`

- [ ] **Step 7: Commit**

```powershell
git add Frames/Preview.lua Locales Healsilus.toc tests
git commit -m @'
feat: add frame preview with fake members

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
'@
```

### Task 17: Controles y ventana de configuración

**Files:**
- Create: `UI/Widgets.lua`, `UI/Config.lua`, `tests/test_config.lua`
- Modify: `Healsilus.toc` (añade `UI\Widgets.lua` y `UI\Config.lua` al final, en ese orden), `tests/run.lua` (añade `"tests/test_config.lua",`), `Locales/enUS.lua`, `Locales/esES.lua`

- [ ] **Step 1: Añade las traducciones**

Al final de `Locales/enUS.lua`:

```lua

-- Ventana de configuración
L.CONFIG_TITLE = "Healsilus"
L.CONFIG_PENDING = "Pending: applies when combat ends"
L.PROFILES_ACTIVE = "Active profile: %s"
L.SOURCE_SPEC = "%s · specialization %d"
L.SOURCE_CHARACTER = "%s · own profile"
L.SOURCE_CLASS = "%s · class profile"
L.SETTINGS_DESCRIPTION = "Click-casting healing frames for WoW Forever. Type /hs to open the settings at any time."
L.SETTINGS_OPEN = "Open Healsilus settings"
L.ACCEPT = "Accept"
L.CLOSE = "Close"
L.MENU_UNAVAILABLE = "Menus are not available in this client (see /hs diag)."
L.REMOVE = "Remove"
L.ADD_SPELL = "Add spell"
L.LIST_FULL = "The list is full (12)."
L.NONE = "None"
```

Al final de `Locales/esES.lua`:

```lua

-- Ventana de configuración
L.CONFIG_TITLE = "Healsilus"
L.CONFIG_PENDING = "Pendiente: se aplicará al salir de combate"
L.PROFILES_ACTIVE = "Perfil activo: %s"
L.SOURCE_SPEC = "%s · especialización %d"
L.SOURCE_CHARACTER = "%s · perfil propio"
L.SOURCE_CLASS = "%s · perfil de clase"
L.SETTINGS_DESCRIPTION = "Marcos de curación con click-casting para WoW Forever. Escribe /hs para abrir la configuración cuando quieras."
L.SETTINGS_OPEN = "Abrir la configuración de Healsilus"
L.ACCEPT = "Aceptar"
L.CLOSE = "Cerrar"
L.MENU_UNAVAILABLE = "Los menús no están disponibles en este cliente (consulta /hs diag)."
L.REMOVE = "Quitar"
L.ADD_SPELL = "Añadir hechizo"
L.LIST_FULL = "La lista está llena (12)."
L.NONE = "Ninguna"
```

- [ ] **Step 2: Escribe la prueba `tests/test_config.lua`**

```lua
local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue = Harness.assertEquals, Harness.assertTrue

local FILES = {
  "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/CombatQueue.lua", "Core/Database.lua",
  "UI/Widgets.lua", "UI/Config.lua",
}

local function LoadConfig()
  local environment = Stubs.NewEnvironment()
  environment.StaticPopupDialogs = {}
  environment.LOCALIZED_CLASS_NAMES_MALE = { DRUID = "Druid" }
  local ns = Loader.Load(environment, FILES)
  ns.Profiles = {
    source = "class", characterKey = "Arsilus-Bah", classToken = "DRUID", active = ns.Database.DefaultProfile(),
    ActiveSpecGroup = function()
      return 2
    end,
  }
  return ns, environment
end

describe("Config", function()
  it("describes the active profile source", function()
    local ns = LoadConfig()
    assertEquals(ns.Config.DescribeSource(), "Druid · class profile")
    ns.Profiles.source = "character"
    assertEquals(ns.Config.DescribeSource(), "Arsilus-Bah · own profile")
    ns.Profiles.source = "spec"
    assertEquals(ns.Config.DescribeSource(), "Arsilus-Bah · specialization 2")
  end)

  it("describes copy sources", function()
    local ns = LoadConfig()
    assertEquals(ns.Config.DescribeCopySource({ kind = "class", classToken = "PRIEST" }), "PRIEST · class profile")
    assertEquals(ns.Config.DescribeCopySource({ kind = "character", characterKey = "Otro-Bah" }), "Otro-Bah · own profile")
    assertEquals(ns.Config.DescribeCopySource({ kind = "spec", characterKey = "Otro-Bah", specIndex = 1 }), "Otro-Bah · specialization 1")
  end)

  it("keeps tabs in registration order", function()
    local ns = LoadConfig()
    ns.Config:RegisterTab("clicks", "Clicks", function() end)
    ns.Config:RegisterTab("frames", "Frames", function() end)
    assertEquals(ns.Config.tabOrder, { "clicks", "frames" })
  end)

  it("writes section settings into the active profile and announces the section", function()
    local ns = LoadConfig()
    local announced = {}
    ns.Events:Register("SETTINGS_CHANGED", function(section)
      announced[#announced + 1] = section
    end)
    ns.Widgets.SectionSetter("frames", "width")(90)
    assertEquals(ns.Profiles.active.frames.width, 90)
    assertEquals(ns.Widgets.SectionGetter("frames", "width")(), 90)
    assertEquals(announced, { "frames" })
  end)

  it("registers a confirmation dialog that runs the accepted action", function()
    local ns, environment = LoadConfig()
    local ran = false
    environment.StaticPopupDialogs.HEALSILUS_CONFIRM.OnAccept(nil, function()
      ran = true
    end)
    assertTrue(ran)
  end)
end)
```

- [ ] **Step 3: Añade el fichero a `tests/run.lua` y ejecuta**

Run: `luajit tests/run.lua`
Expected: FAIL — `cannot open UI/Widgets.lua`.

- [ ] **Step 4: Crea `UI/Widgets.lua`**

```lua
-- Controles del panel hechos con piezas básicas (Button, CheckButton, Slider, EditBox) y MenuUtil para menús.
-- Cada control expone :Refresh() para releer el valor del perfil activo.
local _, ns = ...
local L = ns.L

local Widgets = {}
ns.Widgets = Widgets

local DIALOG_BACKDROP = {
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true, tileSize = 32, edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 },
}
Widgets.DIALOG_BACKDROP = DIALOG_BACKDROP

Widgets.MAX_LIST_ROWS = 12

StaticPopupDialogs.HEALSILUS_CONFIRM = {
  text = "%s",
  button1 = YES,
  button2 = NO,
  OnAccept = function(_, action)
    action()
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

function Widgets.SectionGetter(section, key)
  return function()
    return ns.Profiles.active[section][key]
  end
end

function Widgets.SectionSetter(section, key, afterChange)
  return function(value)
    ns.Profiles.active[section][key] = value
    if afterChange then
      afterChange(value)
    end
    ns.Config:Changed(section)
  end
end

function Widgets.Label(parent, text, template)
  local label = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
  label:SetText(text)
  label:SetJustifyH("LEFT")
  return label
end

function Widgets.Button(parent, text, width, onClick)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetSize(width, 22)
  button:SetText(text)
  button:SetScript("OnClick", onClick)
  return button
end

function Widgets.Checkbox(parent, text, getValue, setValue)
  local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  checkbox:SetSize(24, 24)
  local label = Widgets.Label(parent, text)
  label:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
  checkbox.label = label
  checkbox:SetScript("OnClick", function(self)
    setValue(self:GetChecked() == true)
  end)
  checkbox.Refresh = function(self)
    self:SetChecked(getValue() == true)
  end
  return checkbox
end

local function RoundToStep(value, step)
  return tonumber(string.format("%.2f", math.floor(value / step + 0.5) * step))
end

function Widgets.Slider(parent, text, minimum, maximum, step, getValue, setValue, format)
  local container = CreateFrame("Frame", nil, parent)
  container:SetSize(220, 40)
  local label = Widgets.Label(container, text, "GameFontNormalSmall")
  label:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
  local valueText = Widgets.Label(container, "", "GameFontHighlightSmall")
  valueText:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 0)
  local slider = CreateFrame("Slider", nil, container)
  slider:SetOrientation("HORIZONTAL")
  slider:SetSize(220, 16)
  slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
  local track = slider:CreateTexture(nil, "BACKGROUND")
  track:SetColorTexture(0.2, 0.2, 0.2, 0.9)
  track:SetPoint("LEFT", slider, "LEFT", 0, 0)
  track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
  track:SetHeight(4)
  slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  slider:SetMinMaxValues(minimum, maximum)
  slider:SetValueStep(step)
  slider:SetObeyStepOnDrag(true)
  slider:EnableMouseWheel(true)
  local updating = false
  local shownFormat = format or "%d"
  slider:SetScript("OnValueChanged", function(_, value)
    if updating then
      return
    end
    local rounded = RoundToStep(value, step)
    valueText:SetText(string.format(shownFormat, rounded))
    setValue(rounded)
  end)
  slider:SetScript("OnMouseWheel", function(self, delta)
    self:SetValue(self:GetValue() + delta * step)
  end)
  container.Refresh = function()
    updating = true
    local current = getValue()
    slider:SetValue(current)
    valueText:SetText(string.format(shownFormat, current))
    updating = false
  end
  container.slider = slider
  return container
end

-- Abre un menú contextual; devuelve false (y avisa) si el cliente no tiene MenuUtil.
function Widgets.OpenMenu(owner, build)
  if not MenuUtil or not MenuUtil.CreateContextMenu then
    ns.Print(L.MENU_UNAVAILABLE)
    return false
  end
  MenuUtil.CreateContextMenu(owner, function(_, root)
    build(root)
  end)
  return true
end

function Widgets.OpenSpellMenu(owner, onPick)
  Widgets.OpenMenu(owner, function(root)
    if root.SetScrollMode then
      root:SetScrollMode(400)
    end
    for _, entry in ipairs(ns.Spells:KnownList()) do
      root:CreateButton(entry.name, function()
        onPick(entry)
      end)
    end
  end)
end

-- options: { { value = ..., label = ... } }. Sin MenuUtil, cada clic pasa a la opción siguiente.
function Widgets.Dropdown(parent, text, width, getOptions, getValue, setValue)
  local container = CreateFrame("Frame", nil, parent)
  container:SetSize(width, 44)
  local label = Widgets.Label(container, text, "GameFontNormalSmall")
  label:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
  local button = Widgets.Button(container, "", width, function(self)
    local options = getOptions()
    if MenuUtil and MenuUtil.CreateContextMenu then
      MenuUtil.CreateContextMenu(self, function(_, root)
        for _, option in ipairs(options) do
          root:CreateRadio(option.label, function()
            return getValue() == option.value
          end, function()
            setValue(option.value)
            container:Refresh()
          end)
        end
      end)
      return
    end
    local current = getValue()
    local nextOption = options[1]
    for position, option in ipairs(options) do
      if option.value == current then
        nextOption = options[position % #options + 1]
      end
    end
    if nextOption then
      setValue(nextOption.value)
      container:Refresh()
    end
  end)
  button:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
  container.Refresh = function()
    local current = getValue()
    local shown = tostring(current)
    for _, option in ipairs(getOptions()) do
      if option.value == current then
        shown = option.label
      end
    end
    button:SetText(shown)
  end
  return container
end

-- Columna de controles: cada Add coloca el control debajo del anterior.
function Widgets.Stack(parent, x, y)
  local stack = { parent = parent, x = x, y = y, controls = {} }
  function stack:Add(control, height)
    control:SetPoint("TOPLEFT", self.parent, "TOPLEFT", self.x, self.y)
    self.y = self.y - height
    self.controls[#self.controls + 1] = control
    return control
  end
  function stack:Refresh()
    for _, control in ipairs(self.controls) do
      if control.Refresh then
        control:Refresh()
      end
    end
  end
  return stack
end

function Widgets.SpellRow(parent, width)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(width, 24)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(18, 18)
  row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
  row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
  row.text:SetJustifyH("LEFT")
  row.remove = Widgets.Button(row, L.REMOVE, 70, function()
    if row.onRemove then
      row.onRemove()
    end
  end)
  row.remove:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  return row
end

-- Reutiliza filas: Render(items, pintar, x, y, alto de fila) muestra tantas filas como elementos.
function Widgets.RowPool(parent, createRow)
  local pool = { rows = {} }
  function pool:Render(items, paintRow, x, top, rowHeight)
    for position, item in ipairs(items) do
      local row = self.rows[position]
      if not row then
        row = createRow(parent)
        self.rows[position] = row
      end
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", parent, "TOPLEFT", x, top - (position - 1) * rowHeight)
      paintRow(row, item)
      row:Show()
    end
    for position = #items + 1, #self.rows do
      self.rows[position]:Hide()
    end
  end
  return pool
end

local function BuildTextDialog()
  local dialog = CreateFrame("Frame", "HealsilusTextDialog", UIParent, "BackdropTemplate")
  dialog:SetSize(480, 320)
  dialog:SetPoint("CENTER")
  dialog:SetFrameStrata("FULLSCREEN_DIALOG")
  dialog:SetBackdrop(DIALOG_BACKDROP)
  dialog:EnableMouse(true)
  dialog:Hide()
  dialog.title = Widgets.Label(dialog, "", "GameFontNormal")
  dialog.title:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, -18)
  local scroll = CreateFrame("ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, -42)
  scroll:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -38, 52)
  local editBox = CreateFrame("EditBox", nil, scroll)
  editBox:SetMultiLine(true)
  editBox:SetAutoFocus(false)
  editBox:SetFontObject(ChatFontNormal)
  editBox:SetWidth(410)
  editBox:SetScript("OnEscapePressed", function()
    dialog:Hide()
  end)
  scroll:SetScrollChild(editBox)
  dialog.editBox = editBox
  dialog.accept = Widgets.Button(dialog, L.ACCEPT, 120, function()
    local handler = dialog.onAccept
    dialog:Hide()
    if handler then
      handler(editBox:GetText())
    end
  end)
  dialog.accept:SetPoint("BOTTOMRIGHT", dialog, "BOTTOM", -4, 18)
  local close = Widgets.Button(dialog, L.CLOSE, 120, function()
    dialog:Hide()
  end)
  close:SetPoint("BOTTOMLEFT", dialog, "BOTTOM", 4, 18)
  table.insert(UISpecialFrames, "HealsilusTextDialog")
  return dialog
end

-- Ventana de texto multilínea: macros, exportar (solo copiar) e importar.
function Widgets.TextDialog(title, initialText, acceptLabel, onAccept)
  local dialog = Widgets.textDialog
  if not dialog then
    dialog = BuildTextDialog()
    Widgets.textDialog = dialog
  end
  dialog.title:SetText(title)
  dialog.editBox:SetText(initialText or "")
  dialog.onAccept = onAccept
  dialog.accept:SetText(acceptLabel or L.ACCEPT)
  dialog.accept:SetShown(onAccept ~= nil)
  dialog:Show()
  dialog.editBox:SetFocus()
  dialog.editBox:HighlightText()
end

function Widgets.Confirm(message, onAccept)
  StaticPopup_Show("HEALSILUS_CONFIRM", message, nil, onAccept)
end
```

- [ ] **Step 5: Crea `UI/Config.lua`**

```lua
-- Ventana de configuración: cabecera con el perfil activo, aviso de cambios pendientes y pestañas.
-- Las pestañas se registran desde UI/Tab*.lua en el orden de carga del TOC.
local _, ns = ...
local L = ns.L
local Widgets = ns.Widgets

local Config = { tabs = {}, tabOrder = {}, built = false, selected = nil }
ns.Config = Config

local WIDTH, HEIGHT = 760, 560

local function ClassName(classToken)
  return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classToken]) or tostring(classToken)
end

function Config.DescribeSource()
  local profiles = ns.Profiles
  if profiles.source == "spec" then
    return string.format(L.SOURCE_SPEC, profiles.characterKey, ns.Profiles.ActiveSpecGroup())
  end
  if profiles.source == "character" then
    return string.format(L.SOURCE_CHARACTER, profiles.characterKey)
  end
  return string.format(L.SOURCE_CLASS, ClassName(profiles.classToken))
end

function Config.DescribeCopySource(source)
  if source.kind == "class" then
    return string.format(L.SOURCE_CLASS, ClassName(source.classToken))
  end
  if source.kind == "character" then
    return string.format(L.SOURCE_CHARACTER, source.characterKey)
  end
  return string.format(L.SOURCE_SPEC, source.characterKey, source.specIndex)
end

function Config:RegisterTab(key, label, build, refresh)
  self.tabs[key] = { key = key, label = label, build = build, refresh = refresh }
  self.tabOrder[#self.tabOrder + 1] = key
end

function Config:Build()
  local frame = CreateFrame("Frame", "HealsilusConfigFrame", UIParent, "BackdropTemplate")
  frame:SetSize(WIDTH, HEIGHT)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetBackdrop(Widgets.DIALOG_BACKDROP)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:Hide()
  table.insert(UISpecialFrames, "HealsilusConfigFrame")

  local title = Widgets.Label(frame, L.CONFIG_TITLE, "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -18)
  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
  local sourceText = Widgets.Label(frame, "", "GameFontHighlight")
  sourceText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  local pendingText = Widgets.Label(frame, L.CONFIG_PENDING, "GameFontRed")
  pendingText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -40, -22)
  pendingText:Hide()

  local content = CreateFrame("Frame", nil, frame)
  content:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -96)
  content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 20)
  for position, key in ipairs(self.tabOrder) do
    local tab = self.tabs[key]
    tab.button = Widgets.Button(frame, tab.label, 120, function()
      Config:SelectTab(key)
    end)
    tab.button:SetPoint("TOPLEFT", frame, "TOPLEFT", 20 + (position - 1) * 124, -62)
    tab.panel = CreateFrame("Frame", nil, content)
    tab.panel:SetAllPoints(content)
    tab.panel:Hide()
    tab.build(tab.panel)
  end

  self.frame, self.sourceText, self.pendingText = frame, sourceText, pendingText
  self.built = true
  frame:SetScript("OnShow", function()
    Config:Refresh()
  end)
  self:SelectTab(self.tabOrder[1])
end

function Config:SelectTab(key)
  self.selected = key
  for tabKey, tab in pairs(self.tabs) do
    tab.panel:SetShown(tabKey == key)
    if tabKey == key then
      tab.button:LockHighlight()
    else
      tab.button:UnlockHighlight()
    end
  end
  self:Refresh()
end

function Config:Toggle()
  if not self.built then
    self:Build()
  end
  self.frame:SetShown(not self.frame:IsShown())
end

function Config:UpdatePending()
  if self.built then
    self.pendingText:SetShown(ns.CombatQueue:Count() > 0)
  end
end

function Config:Refresh()
  if not self.built or not self.frame:IsShown() or not ns.Profiles.active then
    return
  end
  self.sourceText:SetText(string.format(L.PROFILES_ACTIVE, Config.DescribeSource()))
  self:UpdatePending()
  local tab = self.tabs[self.selected]
  if tab and tab.refresh then
    tab.refresh(tab.panel)
  end
end

function Config:Changed(section)
  ns.Events:Fire("SETTINGS_CHANGED", section)
  self:Refresh()
end

-- Página en Opciones → AddOns con un botón que abre la ventana propia.
function Config:RegisterSettingsCategory()
  if not Settings or not Settings.RegisterCanvasLayoutCategory or not Settings.RegisterAddOnCategory then
    ns.RecordError("Config:Settings", "Settings API missing")
    return
  end
  local panel = CreateFrame("Frame")
  local description = Widgets.Label(panel, L.SETTINGS_DESCRIPTION, "GameFontHighlight")
  description:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
  description:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
  local open = Widgets.Button(panel, L.SETTINGS_OPEN, 240, function()
    if SettingsPanel and SettingsPanel:IsShown() then
      HideUIPanel(SettingsPanel)
    end
    if not Config.built then
      Config:Build()
    end
    Config.frame:Show()
  end)
  open:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -12)
  local category = Settings.RegisterCanvasLayoutCategory(panel, "Healsilus")
  Settings.RegisterAddOnCategory(category)
  self.settingsCategory = category
end

ns.Events:Register("PROFILE_CHANGED", function()
  Config:Refresh()
end)

ns.Events:Register("COMBAT_QUEUE_CHANGED", function()
  Config:UpdatePending()
end)
```

- [ ] **Step 6: Añade `UI\Widgets.lua` y `UI\Config.lua` al final de la lista de `Healsilus.toc`**

- [ ] **Step 7: Verifica**

Run: `luajit tests/run.lua` → Expected: `120 passed, 0 failed`
Run: `luajit tools/check.lua` → Expected: `check: OK (21 addon files, 43 Lua files)`

- [ ] **Step 8: Commit**

```powershell
git add UI Locales Healsilus.toc tests
git commit -m @'
feat: add settings window and reusable controls

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
'@
```

### Task 18: Pestaña Clics

**Files:**
- Create: `UI/TabClicks.lua`, `tests/test_tab_clicks.lua`
- Modify: `Healsilus.toc` (añade `UI\TabClicks.lua` al final), `tests/run.lua` (añade `"tests/test_tab_clicks.lua",`), `Locales/enUS.lua`, `Locales/esES.lua`

- [ ] **Step 1: Añade las traducciones**

Al final de `Locales/enUS.lua`:

```lua

-- Pestaña Clics
L.TAB_CLICKS = "Clicks"
L.CLICKS_HELP = "Drag a spell from your spellbook onto a cell, or left-click it to choose. Right-click clears it. Red cells use a spell you have not learned."
L.MODIFIER_NONE = "No modifier"
L.BUTTON_LEFT = "Left"
L.BUTTON_RIGHT = "Right"
L.BUTTON_MIDDLE = "Middle"
L.BUTTON_4 = "Button 4"
L.BUTTON_5 = "Button 5"
L.BINDING_EMPTY = "-"
L.BINDING_DEFAULT_TARGET = "Target (default)"
L.BINDING_DEFAULT_MENU = "Menu (default)"
L.BINDING_RANK = "%s (rank %d)"
L.BINDING_MACRO = "Macro"
L.BINDING_TARGET = "Target"
L.BINDING_MENU = "Unit menu"
L.MENU_SPELL = "Spell"
L.MENU_MAX_RANK = "Highest rank"
L.MENU_MACRO = "Macro..."
L.MENU_CLEAR = "Clear"
L.MACRO_TITLE = "Macro for this click (use [@mouseover] to target the bar)"
L.MACRO_TOO_LONG = "The macro is too long (1023 characters maximum)."
```

Al final de `Locales/esES.lua`:

```lua

-- Pestaña Clics
L.TAB_CLICKS = "Clics"
L.CLICKS_HELP = "Arrastra un hechizo del libro a una casilla o haz clic izquierdo para elegirlo. El clic derecho la vacía. En rojo: hechizos que no has aprendido."
L.MODIFIER_NONE = "Sin modificador"
L.BUTTON_LEFT = "Izquierdo"
L.BUTTON_RIGHT = "Derecho"
L.BUTTON_MIDDLE = "Central"
L.BUTTON_4 = "Botón 4"
L.BUTTON_5 = "Botón 5"
L.BINDING_EMPTY = "-"
L.BINDING_DEFAULT_TARGET = "Objetivo (por defecto)"
L.BINDING_DEFAULT_MENU = "Menú (por defecto)"
L.BINDING_RANK = "%s (rango %d)"
L.BINDING_MACRO = "Macro"
L.BINDING_TARGET = "Objetivo"
L.BINDING_MENU = "Menú de unidad"
L.MENU_SPELL = "Hechizo"
L.MENU_MAX_RANK = "Rango máximo"
L.MENU_MACRO = "Macro..."
L.MENU_CLEAR = "Vaciar"
L.MACRO_TITLE = "Macro para este clic (usa [@mouseover] para apuntar a la barra)"
L.MACRO_TOO_LONG = "La macro es demasiado larga (máximo 1023 caracteres)."
```

- [ ] **Step 2: Escribe la prueba `tests/test_tab_clicks.lua`**

```lua
local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertFalse, assertNil = Harness.assertEquals, Harness.assertTrue, Harness.assertFalse, Harness.assertNil

local FILES = {
  "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/CombatQueue.lua", "Core/Database.lua",
  "Data/Spells.lua", "Frames/ClickCast.lua", "UI/Widgets.lua", "UI/Config.lua", "UI/TabClicks.lua",
}

local function LoadTabClicks()
  local environment = Stubs.NewEnvironment({
    spells = {
      [5185] = { name = "Toque de sanación", icon = 136041 },
      [2893] = { name = "Suprimir veneno" },
      [8946] = { name = "Curar envenenamiento" },
      [424242] = { name = "Nunca aprendido" },
    },
    spellbook = {
      { spellID = 5185, name = "Toque de sanación", subName = "Rango 1" },
      { spellID = 8946, name = "Curar envenenamiento", subName = "" },
    },
  })
  environment.StaticPopupDialogs = {}
  local ns = Loader.Load(environment, FILES)
  ns.Spells:Scan()
  return ns
end

describe("TabClicks.Describe", function()
  it("explains the defaults of empty left and right clicks", function()
    local ns = LoadTabClicks()
    assertEquals({ ns.TabClicks.Describe(nil, "1") }, { "Target (default)", nil, true })
    assertEquals({ ns.TabClicks.Describe(nil, "2") }, { "Menu (default)", nil, true })
    assertEquals({ ns.TabClicks.Describe(nil, "shift-3") }, { "-", nil, true })
  end)

  it("shows a learned spell with its icon as valid", function()
    local ns = LoadTabClicks()
    local text, icon, valid = ns.TabClicks.Describe({ kind = "spell", spellID = 5185 }, "1")
    assertEquals(text, "Toque de sanación")
    assertEquals(icon, 136041)
    assertTrue(valid)
  end)

  it("marks spells and ranks that are not learned", function()
    local ns = LoadTabClicks()
    local _, _, valid = ns.TabClicks.Describe({ kind = "spell", spellID = 424242 }, "1")
    assertFalse(valid)
    local text
    text, _, valid = ns.TabClicks.Describe({ kind = "spell", spellID = 5185, rank = 4 }, "1")
    assertEquals(text, "Toque de sanación (rank 4)")
    assertFalse(valid)
  end)

  it("accepts a binding whose fallback spell is learned", function()
    local ns = LoadTabClicks()
    local _, _, valid = ns.TabClicks.Describe({ kind = "spell", spellID = 2893, fallbackSpellID = 8946 }, "ctrl-1")
    assertTrue(valid)
  end)

  it("labels macros, targeting and the unit menu", function()
    local ns = LoadTabClicks()
    assertEquals((ns.TabClicks.Describe({ kind = "macro", text = "/cast X" }, "4")), "Macro")
    assertEquals((ns.TabClicks.Describe({ kind = "target" }, "4")), "Target")
    local text, icon = ns.TabClicks.Describe({ kind = "menu" }, "4")
    assertEquals(text, "Unit menu")
    assertNil(icon)
  end)
end)
```

- [ ] **Step 3: Añade el fichero a `tests/run.lua` y ejecuta**

Run: `luajit tests/run.lua`
Expected: FAIL — `cannot open UI/TabClicks.lua`.

- [ ] **Step 4: Crea `UI/TabClicks.lua`**

```lua
-- Pestaña Clics: tabla de 8 combinaciones de modificadores × 5 botones del ratón.
-- Cada casilla acepta arrastrar un hechizo, elegirlo de un menú (con rango), escribir una macro, objetivo o menú.
local _, ns = ...
local L = ns.L
local Widgets = ns.Widgets

local TabClicks = { cells = {} }
ns.TabClicks = TabClicks

local MACRO_ICON = "Interface\\Icons\\INV_Misc_Note_01"
local CELL_WIDTH, CELL_HEIGHT, LABEL_WIDTH, GRID_TOP = 118, 24, 100, -48
local MAX_MACRO_LENGTH = 1023

local MODIFIER_LABELS = {
  [""] = L.MODIFIER_NONE,
  ["alt-"] = "Alt",
  ["ctrl-"] = "Ctrl",
  ["shift-"] = "Shift",
  ["alt-ctrl-"] = "Alt+Ctrl",
  ["alt-shift-"] = "Alt+Shift",
  ["ctrl-shift-"] = "Ctrl+Shift",
  ["alt-ctrl-shift-"] = "Alt+Ctrl+Shift",
}

local BUTTON_LABELS = {
  ["1"] = L.BUTTON_LEFT,
  ["2"] = L.BUTTON_RIGHT,
  ["3"] = L.BUTTON_MIDDLE,
  ["4"] = L.BUTTON_4,
  ["5"] = L.BUTTON_5,
}

local function Bindings()
  return ns.Profiles.active.bindings
end

local function SetBinding(key, binding)
  Bindings()[key] = binding
  ns.Config:Changed("bindings")
end

-- Devuelve texto, icono y si la casilla es válida (false = se pinta en rojo).
function TabClicks.Describe(binding, key)
  if not binding then
    if key == "1" then
      return L.BINDING_DEFAULT_TARGET, nil, true
    end
    if key == "2" then
      return L.BINDING_DEFAULT_MENU, nil, true
    end
    return L.BINDING_EMPTY, nil, true
  end
  if binding.kind == "spell" then
    local name = ns.Spells:GetName(binding.spellID) or ("#" .. binding.spellID)
    local text = binding.rank and string.format(L.BINDING_RANK, name, binding.rank) or name
    local known = ns.Spells:IsKnown(binding.spellID)
      or (binding.fallbackSpellID ~= nil and ns.Spells:IsKnown(binding.fallbackSpellID))
    local valid = known and ns.ClickCast.ResolveSpell(binding) ~= nil
    return text, ns.Spells:GetIcon(binding.spellID), valid
  elseif binding.kind == "macro" then
    return L.BINDING_MACRO, MACRO_ICON, true
  elseif binding.kind == "target" then
    return L.BINDING_TARGET, nil, true
  end
  return L.BINDING_MENU, nil, true
end

function TabClicks:ReceiveDrag(cell)
  local cursorType, _, _, spellID = GetCursorInfo()
  if cursorType ~= "spell" or not spellID then
    return
  end
  ClearCursor()
  SetBinding(cell.key, { kind = "spell", spellID = spellID })
end

local function EditMacro(cell)
  local current = Bindings()[cell.key]
  local initial = (current and current.kind == "macro") and current.text or "/cast [@mouseover] "
  Widgets.TextDialog(L.MACRO_TITLE, initial, L.ACCEPT, function(text)
    text = strtrim(text)
    if text == "" then
      SetBinding(cell.key, nil)
    elseif #text > MAX_MACRO_LENGTH then
      ns.Print(L.MACRO_TOO_LONG)
    else
      SetBinding(cell.key, { kind = "macro", text = text })
    end
  end)
end

function TabClicks:OpenMenu(cell)
  Widgets.OpenMenu(cell, function(root)
    root:CreateTitle(cell.title)
    local spellMenu = root:CreateButton(L.MENU_SPELL)
    if spellMenu.SetScrollMode then
      spellMenu:SetScrollMode(400)
    end
    for _, entry in ipairs(ns.Spells:KnownList()) do
      local preferred = ns.Spells.PreferredSpellID(entry)
      local spellItem = spellMenu:CreateButton(entry.name, function()
        SetBinding(cell.key, { kind = "spell", spellID = preferred })
      end)
      if entry.maxRank > 1 then
        spellItem:CreateButton(L.MENU_MAX_RANK, function()
          SetBinding(cell.key, { kind = "spell", spellID = preferred })
        end)
        for rank = entry.maxRank, 1, -1 do
          local rankInfo = entry.ranks[rank]
          if rankInfo then
            spellItem:CreateButton(rankInfo.subName, function()
              SetBinding(cell.key, { kind = "spell", spellID = rankInfo.spellID, rank = rank })
            end)
          end
        end
      end
    end
    root:CreateButton(L.MENU_MACRO, function()
      EditMacro(cell)
    end)
    root:CreateButton(L.BINDING_TARGET, function()
      SetBinding(cell.key, { kind = "target" })
    end)
    root:CreateButton(L.BINDING_MENU, function()
      SetBinding(cell.key, { kind = "menu" })
    end)
    root:CreateButton(L.MENU_CLEAR, function()
      SetBinding(cell.key, nil)
    end)
  end)
end

local CELL_BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }

local function CreateCell(panel, key, title)
  local cell = CreateFrame("Button", nil, panel, "BackdropTemplate")
  cell:SetSize(CELL_WIDTH - 4, CELL_HEIGHT - 2)
  cell:SetBackdrop(CELL_BACKDROP)
  cell.icon = cell:CreateTexture(nil, "ARTWORK")
  cell.icon:SetSize(18, 18)
  cell.icon:SetPoint("LEFT", cell, "LEFT", 3, 0)
  cell.text = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  cell.text:SetPoint("LEFT", cell.icon, "RIGHT", 4, 0)
  cell.text:SetPoint("RIGHT", cell, "RIGHT", -3, 0)
  cell.text:SetJustifyH("LEFT")
  cell.text:SetWordWrap(false)
  cell.key, cell.title = key, title
  cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  cell:SetScript("OnClick", function(self, mouseButton)
    if GetCursorInfo() then
      TabClicks:ReceiveDrag(self)
    elseif mouseButton == "RightButton" then
      SetBinding(self.key, nil)
    else
      TabClicks:OpenMenu(self)
    end
  end)
  cell:SetScript("OnReceiveDrag", function(self)
    TabClicks:ReceiveDrag(self)
  end)
  return cell
end

function TabClicks.Build(panel)
  local help = Widgets.Label(panel, L.CLICKS_HELP, "GameFontHighlightSmall")
  help:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
  help:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
  for column, button in ipairs(ns.MOUSE_BUTTONS) do
    local header = Widgets.Label(panel, BUTTON_LABELS[button], "GameFontNormalSmall")
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", LABEL_WIDTH + (column - 1) * CELL_WIDTH, GRID_TOP + 16)
  end
  for row, prefix in ipairs(ns.BINDING_PREFIXES) do
    local rowTop = GRID_TOP - (row - 1) * CELL_HEIGHT
    local rowLabel = Widgets.Label(panel, MODIFIER_LABELS[prefix], "GameFontNormalSmall")
    rowLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, rowTop - 5)
    for column, button in ipairs(ns.MOUSE_BUTTONS) do
      local key = prefix .. button
      local cell = CreateCell(panel, key, MODIFIER_LABELS[prefix] .. " + " .. BUTTON_LABELS[button])
      cell:SetPoint("TOPLEFT", panel, "TOPLEFT", LABEL_WIDTH + (column - 1) * CELL_WIDTH, rowTop)
      TabClicks.cells[key] = cell
    end
  end
end

function TabClicks.Refresh()
  for key, cell in pairs(TabClicks.cells) do
    local text, icon, valid = TabClicks.Describe(Bindings()[key], key)
    cell.text:SetText(text)
    cell.icon:SetTexture(icon)
    cell.icon:SetShown(icon ~= nil)
    if valid then
      cell:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
      cell:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    else
      cell:SetBackdropColor(0.35, 0.05, 0.05, 0.8)
      cell:SetBackdropBorderColor(0.9, 0.2, 0.2, 1)
    end
  end
end

ns.Config:RegisterTab("clicks", L.TAB_CLICKS, TabClicks.Build, TabClicks.Refresh)

ns.Events:Register("SPELLBOOK_UPDATED", function()
  ns.Config:Refresh()
end)
```

- [ ] **Step 5: Añade `UI\TabClicks.lua` al final de la lista de `Healsilus.toc`**

- [ ] **Step 6: Verifica**

Run: `luajit tests/run.lua` → Expected: `125 passed, 0 failed`
Run: `luajit tools/check.lua` → Expected: `check: OK (22 addon files, 45 Lua files)`

- [ ] **Step 7: Commit**

```powershell
git add UI/TabClicks.lua Locales Healsilus.toc tests
git commit -m @'
feat: add click binding grid tab

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
'@
```

### Task 19: Pestaña Marcos

**Files:**
- Create: `UI/TabFrames.lua`, `tests/test_tab_frames.lua`
- Modify: `Healsilus.toc` (añade `UI\TabFrames.lua` al final), `tests/run.lua` (añade `"tests/test_tab_frames.lua",`), `Locales/enUS.lua`, `Locales/esES.lua`

- [ ] **Step 1: Añade las traducciones**

Al final de `Locales/enUS.lua`:

```lua

-- Pestaña Marcos
L.TAB_FRAMES = "Frames"
L.FRAMES_WIDTH = "Width"
L.FRAMES_HEIGHT = "Height"
L.FRAMES_SPACING = "Spacing"
L.FRAMES_COLUMNS = "Columns"
L.FRAMES_UNITS_PER_COLUMN = "Units per column"
L.FRAMES_RANGE_ALPHA = "Out-of-range opacity"
L.FRAMES_SORT = "Sort by"
L.SORT_GROUP = "Group"
L.SORT_CLASS = "Class"
L.SORT_ROLE = "Role"
L.FRAMES_GROWTH = "Growth"
L.GROWTH_DOWN = "Down"
L.GROWTH_RIGHT = "Right"
L.FRAMES_COLOR = "Bar color"
L.COLOR_CLASS = "Class"
L.COLOR_HEALTH = "By health"
L.FRAMES_HEALTH_TEXT = "Health text"
L.TEXT_NONE = "None"
L.TEXT_DEFICIT = "Deficit"
L.TEXT_PERCENT = "Percent"
L.FRAMES_TEXTURE = "Texture"
L.TEXTURE_BLIZZARD = "Blizzard"
L.TEXTURE_RAID = "Raid"
L.TEXTURE_FLAT = "Flat"
L.FRAMES_SHOW_SOLO = "Show when solo"
L.FRAMES_SHOW_TANKS = "Tanks block"
L.FRAMES_SHOW_PETS = "Pets"
L.FRAMES_SHOW_TARGET = "Friendly target"
L.FRAMES_SHOW_FOCUS = "Friendly focus"
L.FRAMES_HIDE_BLIZZARD = "Hide Blizzard party/raid frames"
L.FRAMES_LOCKED = "Lock frames"
L.FRAMES_CAST_ON_DOWN = "Cast on mouse down"
L.PREVIEW_LABEL = "Preview:"
L.PREVIEW_HIDE = "Hide"
L.RELOAD_TO_RESTORE = "Type /reload to fully restore the Blizzard frames."
```

Al final de `Locales/esES.lua`:

```lua

-- Pestaña Marcos
L.TAB_FRAMES = "Marcos"
L.FRAMES_WIDTH = "Ancho"
L.FRAMES_HEIGHT = "Alto"
L.FRAMES_SPACING = "Separación"
L.FRAMES_COLUMNS = "Columnas"
L.FRAMES_UNITS_PER_COLUMN = "Unidades por columna"
L.FRAMES_RANGE_ALPHA = "Opacidad fuera de rango"
L.FRAMES_SORT = "Ordenar por"
L.SORT_GROUP = "Grupo"
L.SORT_CLASS = "Clase"
L.SORT_ROLE = "Rol"
L.FRAMES_GROWTH = "Crecimiento"
L.GROWTH_DOWN = "Hacia abajo"
L.GROWTH_RIGHT = "Hacia la derecha"
L.FRAMES_COLOR = "Color de la barra"
L.COLOR_CLASS = "Clase"
L.COLOR_HEALTH = "Según la vida"
L.FRAMES_HEALTH_TEXT = "Texto de vida"
L.TEXT_NONE = "Ninguno"
L.TEXT_DEFICIT = "Déficit"
L.TEXT_PERCENT = "Porcentaje"
L.FRAMES_TEXTURE = "Textura"
L.TEXTURE_BLIZZARD = "Blizzard"
L.TEXTURE_RAID = "Banda"
L.TEXTURE_FLAT = "Plana"
L.FRAMES_SHOW_SOLO = "Mostrar en solitario"
L.FRAMES_SHOW_TANKS = "Bloque de tanques"
L.FRAMES_SHOW_PETS = "Mascotas"
L.FRAMES_SHOW_TARGET = "Objetivo amistoso"
L.FRAMES_SHOW_FOCUS = "Foco amistoso"
L.FRAMES_HIDE_BLIZZARD = "Ocultar marcos de grupo/banda de Blizzard"
L.FRAMES_LOCKED = "Bloquear marcos"
L.FRAMES_CAST_ON_DOWN = "Lanzar al pulsar"
L.PREVIEW_LABEL = "Vista previa:"
L.PREVIEW_HIDE = "Ocultar"
L.RELOAD_TO_RESTORE = "Escribe /reload para restaurar del todo los marcos de Blizzard."
```

- [ ] **Step 2: Escribe la prueba `tests/test_tab_frames.lua`**

```lua
local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue = Harness.assertEquals, Harness.assertTrue

local function LoadTabFrames()
  local environment = Stubs.NewEnvironment()
  environment.StaticPopupDialogs = {}
  return Loader.Load(environment, {
    "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/CombatQueue.lua", "Core/Database.lua",
    "Frames/Media.lua", "UI/Widgets.lua", "UI/Config.lua", "UI/TabFrames.lua",
  })
end

describe("TabFrames controls", function()
  it("give every slider a stored range and a numeric default", function()
    local ns = LoadTabFrames()
    local defaults = ns.Database.DefaultProfile().frames
    for _, spec in ipairs(ns.TabFrames.SLIDERS) do
      assertTrue(ns.Database.RANGES[spec.key] ~= nil, spec.key)
      assertEquals(type(defaults[spec.key]), "number", spec.key)
    end
  end)

  it("offer exactly the allowed values in every dropdown", function()
    local ns = LoadTabFrames()
    for _, spec in ipairs(ns.TabFrames.DROPDOWNS) do
      local offered = {}
      for _, option in ipairs(spec.options) do
        offered[option.value] = true
      end
      assertEquals(offered, ns.Database.ENUMS[spec.key], spec.key)
    end
  end)

  it("bind every checkbox to a boolean frame setting", function()
    local ns = LoadTabFrames()
    local defaults = ns.Database.DefaultProfile().frames
    for _, spec in ipairs(ns.TabFrames.CHECKBOXES) do
      assertEquals(type(defaults[spec.key]), "boolean", spec.key)
    end
  end)
end)
```

- [ ] **Step 3: Añade el fichero a `tests/run.lua` y ejecuta**

Run: `luajit tests/run.lua`
Expected: FAIL — `cannot open UI/TabFrames.lua`.

- [ ] **Step 4: Crea `UI/TabFrames.lua`**

```lua
-- Pestaña Marcos: tamaño, orden, colores, bloques visibles, bloqueo y vista previa.
-- Los controles se describen en tablas para poder comprobar en las pruebas que encajan con el esquema.
local _, ns = ...
local L = ns.L
local Widgets = ns.Widgets

local TabFrames = { stacks = {} }
ns.TabFrames = TabFrames

TabFrames.SLIDERS = {
  { key = "width", label = L.FRAMES_WIDTH, step = 1 },
  { key = "height", label = L.FRAMES_HEIGHT, step = 1 },
  { key = "spacing", label = L.FRAMES_SPACING, step = 1 },
  { key = "columns", label = L.FRAMES_COLUMNS, step = 1 },
  { key = "unitsPerColumn", label = L.FRAMES_UNITS_PER_COLUMN, step = 1 },
  { key = "outOfRangeAlpha", label = L.FRAMES_RANGE_ALPHA, step = 0.05, format = "%.2f" },
}

local TEXTURE_LABELS = { BLIZZARD = L.TEXTURE_BLIZZARD, RAID = L.TEXTURE_RAID, FLAT = L.TEXTURE_FLAT }
local textureOptions = {}
for _, key in ipairs(ns.Media.TEXTURE_ORDER) do
  textureOptions[#textureOptions + 1] = { value = key, label = TEXTURE_LABELS[key] }
end

TabFrames.DROPDOWNS = {
  { key = "sortBy", label = L.FRAMES_SORT, options = {
    { value = "GROUP", label = L.SORT_GROUP }, { value = "CLASS", label = L.SORT_CLASS }, { value = "ROLE", label = L.SORT_ROLE },
  } },
  { key = "growth", label = L.FRAMES_GROWTH, options = {
    { value = "DOWN", label = L.GROWTH_DOWN }, { value = "RIGHT", label = L.GROWTH_RIGHT },
  } },
  { key = "colorMode", label = L.FRAMES_COLOR, options = {
    { value = "CLASS", label = L.COLOR_CLASS }, { value = "HEALTH", label = L.COLOR_HEALTH },
  } },
  { key = "healthText", label = L.FRAMES_HEALTH_TEXT, options = {
    { value = "NONE", label = L.TEXT_NONE }, { value = "DEFICIT", label = L.TEXT_DEFICIT }, { value = "PERCENT", label = L.TEXT_PERCENT },
  } },
  { key = "texture", label = L.FRAMES_TEXTURE, options = textureOptions },
}

local function WarnBlizzardRestore(hidden)
  if not hidden then
    ns.Print(L.RELOAD_TO_RESTORE)
  end
end

TabFrames.CHECKBOXES = {
  { key = "showSolo", label = L.FRAMES_SHOW_SOLO },
  { key = "showTanks", label = L.FRAMES_SHOW_TANKS },
  { key = "showPets", label = L.FRAMES_SHOW_PETS },
  { key = "showTarget", label = L.FRAMES_SHOW_TARGET },
  { key = "showFocus", label = L.FRAMES_SHOW_FOCUS },
  { key = "hideBlizzard", label = L.FRAMES_HIDE_BLIZZARD, afterChange = WarnBlizzardRestore },
  { key = "locked", label = L.FRAMES_LOCKED },
  { key = "castOnDown", label = L.FRAMES_CAST_ON_DOWN },
}

local PREVIEW_COUNTS = { 5, 10, 20, 40 }

function TabFrames.Build(panel)
  local sliders = Widgets.Stack(panel, 0, 0)
  for _, spec in ipairs(TabFrames.SLIDERS) do
    local range = ns.Database.RANGES[spec.key]
    sliders:Add(Widgets.Slider(panel, spec.label, range[1], range[2], spec.step,
      Widgets.SectionGetter("frames", spec.key), Widgets.SectionSetter("frames", spec.key), spec.format), 48)
  end
  local dropdowns = Widgets.Stack(panel, 250, 0)
  for _, spec in ipairs(TabFrames.DROPDOWNS) do
    dropdowns:Add(Widgets.Dropdown(panel, spec.label, 200, function()
      return spec.options
    end, Widgets.SectionGetter("frames", spec.key), Widgets.SectionSetter("frames", spec.key)), 50)
  end
  local checkboxes = Widgets.Stack(panel, 470, 0)
  for _, spec in ipairs(TabFrames.CHECKBOXES) do
    checkboxes:Add(Widgets.Checkbox(panel, spec.label, Widgets.SectionGetter("frames", spec.key),
      Widgets.SectionSetter("frames", spec.key, spec.afterChange)), 28)
  end
  TabFrames.stacks = { sliders, dropdowns, checkboxes }

  local previewLabel = Widgets.Label(panel, L.PREVIEW_LABEL, "GameFontNormal")
  previewLabel:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 6)
  local previous = previewLabel
  for _, count in ipairs(PREVIEW_COUNTS) do
    local button = Widgets.Button(panel, tostring(count), 50, function()
      ns.Preview:Show(count)
    end)
    button:SetPoint("LEFT", previous, "RIGHT", 8, 0)
    previous = button
  end
  local hide = Widgets.Button(panel, L.PREVIEW_HIDE, 90, function()
    ns.Preview:Hide()
  end)
  hide:SetPoint("LEFT", previous, "RIGHT", 8, 0)
end

function TabFrames.Refresh()
  for _, stack in ipairs(TabFrames.stacks) do
    stack:Refresh()
  end
end

ns.Config:RegisterTab("frames", L.TAB_FRAMES, TabFrames.Build, TabFrames.Refresh)
```

- [ ] **Step 5: Añade `UI\TabFrames.lua` al final de la lista de `Healsilus.toc`**

- [ ] **Step 6: Verifica**

Run: `luajit tests/run.lua` → Expected: `128 passed, 0 failed`
Run: `luajit tools/check.lua` → Expected: `check: OK (23 addon files, 47 Lua files)`

- [ ] **Step 7: Commit**

```powershell
git add UI/TabFrames.lua Locales Healsilus.toc tests
git commit -m @'
feat: add frames settings tab with preview buttons

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
'@
```

### Task 20: Pestañas Auras y Buffs

**Files:**
- Create: `UI/TabAuras.lua`, `UI/TabBuffs.lua`, `tests/test_tab_lists.lua`
- Modify: `Healsilus.toc` (añade `UI\TabAuras.lua` y `UI\TabBuffs.lua` al final, en ese orden), `tests/run.lua` (añade `"tests/test_tab_lists.lua",`), `Locales/enUS.lua`, `Locales/esES.lua`

- [ ] **Step 1: Añade las traducciones**

Al final de `Locales/enUS.lua`:

```lua

-- Pestañas Auras y Buffs
L.TAB_AURAS = "Auras"
L.AURAS_HOTS = "Show my HoTs"
L.AURAS_HOTS_MAX = "Maximum HoTs"
L.AURAS_DEBUFFS = "Show debuffs"
L.AURAS_DEBUFFS_MAX = "Maximum debuffs"
L.AURAS_DISPELLABLE = "Only debuffs I can dispel"
L.AURAS_ICON_SIZE = "Icon size"
L.AURAS_HOT_LIST = "Tracked HoTs"
L.TAB_BUFFS = "Buffs"
L.BUFFS_ENABLED = "Warn about missing buffs (out of combat)"
L.BUFFS_LIST = "Watched buffs"
L.TARGETS_ALL = "Everyone"
L.TARGETS_TANKS = "Tanks only"
L.BUFFS_GROUP_VARIANT = "group: %s"
L.BUFFS_SET_GROUP = "Group version"
```

Al final de `Locales/esES.lua`:

```lua

-- Pestañas Auras y Buffs
L.TAB_AURAS = "Auras"
L.AURAS_HOTS = "Mostrar mis HoTs"
L.AURAS_HOTS_MAX = "Máximo de HoTs"
L.AURAS_DEBUFFS = "Mostrar debuffs"
L.AURAS_DEBUFFS_MAX = "Máximo de debuffs"
L.AURAS_DISPELLABLE = "Solo debuffs que puedo quitar"
L.AURAS_ICON_SIZE = "Tamaño de icono"
L.AURAS_HOT_LIST = "HoTs vigilados"
L.TAB_BUFFS = "Buffs"
L.BUFFS_ENABLED = "Avisar de buffs que faltan (fuera de combate)"
L.BUFFS_LIST = "Buffs vigilados"
L.TARGETS_ALL = "Todos"
L.TARGETS_TANKS = "Solo tanques"
L.BUFFS_GROUP_VARIANT = "grupo: %s"
L.BUFFS_SET_GROUP = "Versión de grupo"
```

- [ ] **Step 2: Escribe la prueba `tests/test_tab_lists.lua`**

```lua
local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue = Harness.assertEquals, Harness.assertTrue

local function LoadTabs()
  local environment = Stubs.NewEnvironment({
    spells = {
      [774] = { name = "Rejuvenecimiento", icon = 136081 },
      [8936] = { name = "Recrecimiento", icon = 136085 },
      [1126] = { name = "Marca de lo Salvaje", icon = 136078 },
      [21849] = { name = "Don de lo Salvaje", icon = 136038 },
    },
  })
  environment.StaticPopupDialogs = {}
  local ns = Loader.Load(environment, {
    "Core/Init.lua", "Locales/enUS.lua", "Core/Events.lua", "Core/CombatQueue.lua", "Core/Database.lua",
    "Data/Spells.lua", "Data/Druid.lua", "UI/Widgets.lua", "UI/Config.lua", "UI/TabAuras.lua", "UI/TabBuffs.lua",
  })
  ns.Profiles = { active = ns.Database.NormalizeProfile(ns.ClassDefaults.DRUID(), {}) }
  return ns
end

describe("TabAuras", function()
  it("lists tracked HoTs sorted by name, naming unknown IDs by number", function()
    local ns = LoadTabs()
    ns.Profiles.active.auras.hotSpellIDs[99] = true
    local names = {}
    for _, item in ipairs(ns.TabAuras.HotItems()) do
      names[#names + 1] = item.name
    end
    assertEquals(names, { "#99", "Recrecimiento", "Rejuvenecimiento" })
  end)

  it("binds every control to a setting of the right type", function()
    local ns = LoadTabs()
    local defaults = ns.Database.DefaultProfile().auras
    for _, spec in ipairs(ns.TabAuras.CHECKBOXES) do
      assertEquals(type(defaults[spec.key]), "boolean", spec.key)
    end
    for _, spec in ipairs(ns.TabAuras.SLIDERS) do
      assertTrue(ns.Database.RANGES[spec.key] ~= nil, spec.key)
    end
  end)
end)

describe("TabBuffs", function()
  it("describes watched buffs with their group version and targets", function()
    local ns = LoadTabs()
    local items = ns.TabBuffs.Items()
    assertEquals(items[1].name, "Marca de lo Salvaje")
    assertEquals(items[1].groupName, "Don de lo Salvaje")
    assertEquals(items[1].position, 1)
    assertEquals(items[2].groupName, nil)
    assertEquals(ns.TabBuffs.TARGET_LABELS[items[2].entry.targets], "Tanks only")
  end)

  it("cycles targets between everyone and tanks", function()
    local ns = LoadTabs()
    assertEquals(ns.TabBuffs.NextTargets("ALL"), "TANKS")
    assertEquals(ns.TabBuffs.NextTargets("TANKS"), "ALL")
  end)
end)
```

- [ ] **Step 3: Añade el fichero a `tests/run.lua` y ejecuta**

Run: `luajit tests/run.lua`
Expected: FAIL — `cannot open UI/TabAuras.lua`.

- [ ] **Step 4: Crea `UI/TabAuras.lua`**

```lua
-- Pestaña Auras: HoTs propios (lista de hechizos vigilados) y debuffs.
local _, ns = ...
local L = ns.L
local Widgets = ns.Widgets

local TabAuras = { stack = nil, pool = nil }
ns.TabAuras = TabAuras

local LIST_X, LIST_TOP, ROW_HEIGHT = 300, -56, 26

TabAuras.CHECKBOXES = {
  { key = "hotsEnabled", label = L.AURAS_HOTS },
  { key = "debuffsEnabled", label = L.AURAS_DEBUFFS },
  { key = "debuffsDispellableOnly", label = L.AURAS_DISPELLABLE },
}

TabAuras.SLIDERS = {
  { key = "hotsMax", label = L.AURAS_HOTS_MAX },
  { key = "debuffsMax", label = L.AURAS_DEBUFFS_MAX },
  { key = "iconSize", label = L.AURAS_ICON_SIZE },
}

local function HotSpellIDs()
  return ns.Profiles.active.auras.hotSpellIDs
end

function TabAuras.HotItems()
  local items = {}
  for spellID in pairs(HotSpellIDs()) do
    items[#items + 1] = { spellID = spellID, name = ns.Spells:GetName(spellID) or ("#" .. spellID), icon = ns.Spells:GetIcon(spellID) }
  end
  table.sort(items, function(left, right)
    return left.name < right.name
  end)
  return items
end

local function PaintRow(row, item)
  row.icon:SetTexture(item.icon)
  row.text:SetText(item.name)
  row.onRemove = function()
    HotSpellIDs()[item.spellID] = nil
    ns.Config:Changed("auras")
  end
end

function TabAuras.Build(panel)
  local stack = Widgets.Stack(panel, 0, 0)
  for _, spec in ipairs(TabAuras.CHECKBOXES) do
    stack:Add(Widgets.Checkbox(panel, spec.label, Widgets.SectionGetter("auras", spec.key), Widgets.SectionSetter("auras", spec.key)), 30)
  end
  for _, spec in ipairs(TabAuras.SLIDERS) do
    local range = ns.Database.RANGES[spec.key]
    stack:Add(Widgets.Slider(panel, spec.label, range[1], range[2], 1,
      Widgets.SectionGetter("auras", spec.key), Widgets.SectionSetter("auras", spec.key)), 48)
  end
  TabAuras.stack = stack

  local title = Widgets.Label(panel, L.AURAS_HOT_LIST, "GameFontNormal")
  title:SetPoint("TOPLEFT", panel, "TOPLEFT", LIST_X, 0)
  local add = Widgets.Button(panel, L.ADD_SPELL, 140, function(self)
    if #TabAuras.HotItems() >= Widgets.MAX_LIST_ROWS then
      ns.Print(L.LIST_FULL)
      return
    end
    Widgets.OpenSpellMenu(self, function(entry)
      HotSpellIDs()[ns.Spells.PreferredSpellID(entry)] = true
      ns.Config:Changed("auras")
    end)
  end)
  add:SetPoint("TOPLEFT", panel, "TOPLEFT", LIST_X, -22)
  TabAuras.pool = Widgets.RowPool(panel, function(parent)
    return Widgets.SpellRow(parent, 380)
  end)
end

function TabAuras.Refresh()
  TabAuras.stack:Refresh()
  TabAuras.pool:Render(TabAuras.HotItems(), PaintRow, LIST_X, LIST_TOP, ROW_HEIGHT)
end

ns.Config:RegisterTab("auras", L.TAB_AURAS, TabAuras.Build, TabAuras.Refresh)
```

- [ ] **Step 5: Crea `UI/TabBuffs.lua`**

```lua
-- Pestaña Buffs: qué buffs tuyos vigilar, a quién (todos o tanques) y su versión de grupo.
local _, ns = ...
local L = ns.L
local Widgets = ns.Widgets

local TabBuffs = { checkbox = nil, pool = nil }
ns.TabBuffs = TabBuffs

local LIST_TOP, ROW_HEIGHT = -84, 26

TabBuffs.TARGET_LABELS = { ALL = L.TARGETS_ALL, TANKS = L.TARGETS_TANKS }

function TabBuffs.NextTargets(targets)
  return targets == "ALL" and "TANKS" or "ALL"
end

local function Watched()
  return ns.Profiles.active.buffs.watched
end

function TabBuffs.Items()
  local items = {}
  for position, entry in ipairs(Watched()) do
    local groupName = entry.groupSpellID and (ns.Spells:GetName(entry.groupSpellID) or ("#" .. entry.groupSpellID))
    items[#items + 1] = {
      position = position,
      entry = entry,
      name = ns.Spells:GetName(entry.spellID) or ("#" .. entry.spellID),
      groupName = groupName,
      icon = ns.Spells:GetIcon(entry.spellID),
    }
  end
  return items
end

local function CreateBuffRow(parent)
  local row = Widgets.SpellRow(parent, 700)
  row.targets = Widgets.Button(row, "", 110, function()
    if row.onTargets then
      row.onTargets()
    end
  end)
  row.targets:SetPoint("RIGHT", row.remove, "LEFT", -6, 0)
  row.group = Widgets.Button(row, L.BUFFS_SET_GROUP, 130, function(self)
    if row.onGroup then
      row.onGroup(self)
    end
  end)
  row.group:SetPoint("RIGHT", row.targets, "LEFT", -6, 0)
  return row
end

local function PaintRow(row, item)
  row.icon:SetTexture(item.icon)
  local suffix = item.groupName and (" · " .. string.format(L.BUFFS_GROUP_VARIANT, item.groupName)) or ""
  row.text:SetText(item.name .. suffix)
  row.targets:SetText(TabBuffs.TARGET_LABELS[item.entry.targets])
  row.onTargets = function()
    item.entry.targets = TabBuffs.NextTargets(item.entry.targets)
    ns.Config:Changed("buffs")
  end
  row.onGroup = function(owner)
    Widgets.OpenMenu(owner, function(root)
      root:CreateButton(L.NONE, function()
        item.entry.groupSpellID = nil
        ns.Config:Changed("buffs")
      end)
      for _, entry in ipairs(ns.Spells:KnownList()) do
        root:CreateButton(entry.name, function()
          item.entry.groupSpellID = ns.Spells.PreferredSpellID(entry)
          ns.Config:Changed("buffs")
        end)
      end
    end)
  end
  row.onRemove = function()
    table.remove(Watched(), item.position)
    ns.Config:Changed("buffs")
  end
end

function TabBuffs.Build(panel)
  TabBuffs.checkbox = Widgets.Checkbox(panel, L.BUFFS_ENABLED, Widgets.SectionGetter("buffs", "enabled"), Widgets.SectionSetter("buffs", "enabled"))
  TabBuffs.checkbox:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
  local title = Widgets.Label(panel, L.BUFFS_LIST, "GameFontNormal")
  title:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -36)
  local add = Widgets.Button(panel, L.ADD_SPELL, 140, function(self)
    if #Watched() >= Widgets.MAX_LIST_ROWS then
      ns.Print(L.LIST_FULL)
      return
    end
    Widgets.OpenSpellMenu(self, function(entry)
      local list = Watched()
      list[#list + 1] = { spellID = ns.Spells.PreferredSpellID(entry), targets = "ALL" }
      ns.Config:Changed("buffs")
    end)
  end)
  add:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -56)
  TabBuffs.pool = Widgets.RowPool(panel, CreateBuffRow)
end

function TabBuffs.Refresh()
  TabBuffs.checkbox:Refresh()
  TabBuffs.pool:Render(TabBuffs.Items(), PaintRow, 0, LIST_TOP, ROW_HEIGHT)
end

ns.Config:RegisterTab("buffs", L.TAB_BUFFS, TabBuffs.Build, TabBuffs.Refresh)
```

- [ ] **Step 6: Añade `UI\TabAuras.lua` y `UI\TabBuffs.lua` al final de la lista de `Healsilus.toc`**

- [ ] **Step 7: Verifica**

Run: `luajit tests/run.lua` → Expected: `132 passed, 0 failed`
Run: `luajit tools/check.lua` → Expected: `check: OK (25 addon files, 50 Lua files)`

- [ ] **Step 8: Commit**

```powershell
git add UI/TabAuras.lua UI/TabBuffs.lua Locales Healsilus.toc tests
git commit -m @'
feat: add aura and buff settings tabs

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
'@
```

### Task 21: Pestaña Perfiles

**Files:**
- Create: `UI/TabProfiles.lua`
- Modify: `Healsilus.toc` (añade `UI\TabProfiles.lua` al final), `Locales/enUS.lua`, `Locales/esES.lua`

La lógica que usa esta pestaña ya está probada (`Profiles`, `Serializer`, `Config.DescribeCopySource`). La carga del fichero la cubre la prueba de humo de la tarea 23.

- [ ] **Step 1: Añade las traducciones**

Al final de `Locales/enUS.lua`:

```lua

-- Pestaña Perfiles
L.TAB_PROFILES = "Profiles"
L.PROFILES_USE_CLASS = "Use the shared class profile"
L.PROFILES_USE_SPEC = "Separate profile per specialization"
L.PROFILES_SPEC_GROUP = "Active specialization: %d"
L.PROFILES_COPY = "Copy from..."
L.PROFILES_COPY_CONFIRM = "Replace the active profile with a copy of %s?"
L.PROFILES_RESET = "Reset"
L.PROFILES_RESET_CONFIRM = "Reset the active profile to its defaults?"
L.PROFILES_EXPORT = "Export"
L.PROFILES_EXPORT_TITLE = "Copy this text (Ctrl+C) to share the profile"
L.PROFILES_IMPORT = "Import"
L.PROFILES_IMPORT_TITLE = "Paste a Healsilus profile (Ctrl+V)"
L.IMPORT_FAILED = "Import failed: %s"
L.IMPORT_CONFIRM = "Replace the active profile with the imported one?"
L.PROFILES_NO_SOURCES = "No other profiles yet."
L.PROFILES_COMBAT_NOTE = "Changes made in combat apply when combat ends."
```

Al final de `Locales/esES.lua`:

```lua

-- Pestaña Perfiles
L.TAB_PROFILES = "Perfiles"
L.PROFILES_USE_CLASS = "Usar el perfil compartido de la clase"
L.PROFILES_USE_SPEC = "Perfil distinto por especialización"
L.PROFILES_SPEC_GROUP = "Especialización activa: %d"
L.PROFILES_COPY = "Copiar desde..."
L.PROFILES_COPY_CONFIRM = "¿Sustituir el perfil activo por una copia de %s?"
L.PROFILES_RESET = "Restablecer"
L.PROFILES_RESET_CONFIRM = "¿Restablecer el perfil activo a los valores de serie?"
L.PROFILES_EXPORT = "Exportar"
L.PROFILES_EXPORT_TITLE = "Copia este texto (Ctrl+C) para compartir el perfil"
L.PROFILES_IMPORT = "Importar"
L.PROFILES_IMPORT_TITLE = "Pega un perfil de Healsilus (Ctrl+V)"
L.IMPORT_FAILED = "No se pudo importar: %s"
L.IMPORT_CONFIRM = "¿Sustituir el perfil activo por el importado?"
L.PROFILES_NO_SOURCES = "Aún no hay otros perfiles."
L.PROFILES_COMBAT_NOTE = "Los cambios hechos en combate se aplican al salir de combate."
```

- [ ] **Step 2: Crea `UI/TabProfiles.lua`**

```lua
-- Pestaña Perfiles: perfil de clase o propio, perfiles por especialización, copiar, restablecer, exportar e importar.
local _, ns = ...
local L = ns.L
local Widgets = ns.Widgets

local TabProfiles = { stack = nil, specText = nil }
ns.TabProfiles = TabProfiles

local function Character()
  return ns.Profiles:Character()
end

local function OpenCopyMenu(owner)
  Widgets.OpenMenu(owner, function(root)
    local sources = ns.Profiles:ListCopySources()
    if #sources == 0 then
      root:CreateTitle(L.PROFILES_NO_SOURCES)
      return
    end
    for _, source in ipairs(sources) do
      local label = ns.Config.DescribeCopySource(source)
      root:CreateButton(label, function()
        Widgets.Confirm(string.format(L.PROFILES_COPY_CONFIRM, label), function()
          ns.Profiles:CopyFrom(source.profile)
        end)
      end)
    end
  end)
end

local function ImportText(text)
  local profile, failure = ns.Serializer.Import(text)
  if not profile then
    ns.Print(string.format(L.IMPORT_FAILED, failure))
    return
  end
  Widgets.Confirm(L.IMPORT_CONFIRM, function()
    ns.Profiles:ReplaceActive(profile)
  end)
end

function TabProfiles.Build(panel)
  local stack = Widgets.Stack(panel, 0, 0)
  stack:Add(Widgets.Checkbox(panel, L.PROFILES_USE_CLASS, function()
    return Character().useClassProfile
  end, function(enabled)
    ns.Profiles:SetUseClassProfile(enabled)
  end), 30)
  stack:Add(Widgets.Checkbox(panel, L.PROFILES_USE_SPEC, function()
    return Character().useSpecProfiles
  end, function(enabled)
    ns.Profiles:SetUseSpecProfiles(enabled)
  end), 30)
  TabProfiles.stack = stack

  local specText = Widgets.Label(panel, "", "GameFontHighlight")
  specText:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -70)
  TabProfiles.specText = specText

  local copy = Widgets.Button(panel, L.PROFILES_COPY, 150, function(self)
    OpenCopyMenu(self)
  end)
  copy:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -100)
  local reset = Widgets.Button(panel, L.PROFILES_RESET, 150, function()
    Widgets.Confirm(L.PROFILES_RESET_CONFIRM, function()
      ns.Profiles:ResetActive()
    end)
  end)
  reset:SetPoint("LEFT", copy, "RIGHT", 10, 0)
  local export = Widgets.Button(panel, L.PROFILES_EXPORT, 150, function()
    Widgets.TextDialog(L.PROFILES_EXPORT_TITLE, ns.Serializer.Export(ns.Profiles.active), nil, nil)
  end)
  export:SetPoint("TOPLEFT", copy, "BOTTOMLEFT", 0, -10)
  local import = Widgets.Button(panel, L.PROFILES_IMPORT, 150, function()
    Widgets.TextDialog(L.PROFILES_IMPORT_TITLE, "", L.PROFILES_IMPORT, ImportText)
  end)
  import:SetPoint("LEFT", export, "RIGHT", 10, 0)

  local note = Widgets.Label(panel, L.PROFILES_COMBAT_NOTE, "GameFontDisableSmall")
  note:SetPoint("TOPLEFT", export, "BOTTOMLEFT", 0, -16)
end

function TabProfiles.Refresh()
  TabProfiles.stack:Refresh()
  TabProfiles.specText:SetText(string.format(L.PROFILES_SPEC_GROUP, ns.Profiles.ActiveSpecGroup()))
end

ns.Config:RegisterTab("profiles", L.TAB_PROFILES, TabProfiles.Build, TabProfiles.Refresh)
```

- [ ] **Step 3: Añade `UI\TabProfiles.lua` al final de la lista de `Healsilus.toc`**

- [ ] **Step 4: Verifica**

Run: `luajit tests/run.lua` → Expected: `132 passed, 0 failed`
Run: `luajit tools/check.lua` → Expected: `check: OK (26 addon files, 51 Lua files)`

- [ ] **Step 5: Commit**

```powershell
git add UI/TabProfiles.lua Locales Healsilus.toc
git commit -m @'
feat: add profiles tab with copy, reset, export and import

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
'@
```

### Task 22: Diagnóstico y comandos

**Files:**
- Create: `Core/Diagnostics.lua`, `Core/Commands.lua`, `tests/test_diagnostics_commands.lua`
- Modify: `Healsilus.toc` (añade `Core\Diagnostics.lua` y `Core\Commands.lua` al final, en ese orden), `tests/run.lua` (añade `"tests/test_diagnostics_commands.lua",`), `Locales/enUS.lua`, `Locales/esES.lua`

- [ ] **Step 1: Añade las traducciones**

Al final de `Locales/enUS.lua`:

```lua

-- Diagnóstico y comandos
L.DIAG_HEADER = "Healsilus %s · client %s (%s) · Interface %s"
L.DIAG_OK = "OK"
L.DIAG_MISSING = "MISSING"
L.DIAG_EVENT = "event %s: %s"
L.DIAG_AURA_CONTAINER = "Native aura containers: %s"
L.DIAG_ALPHA_BOOLEAN = "SetAlphaFromBoolean: %s"
L.DIAG_SPELLS_OK = "Every spell ID in the profile exists."
L.DIAG_SPELLS_MISSING = "Unknown spell IDs: %s"
L.DIAG_HEADER_BUTTONS = "Header %s: %d buttons"
L.DIAG_PROFILE = "Profile source: %s · queued actions: %d"
L.DIAG_FIXES = "Saved data corrected: %s"
L.DIAG_NO_ERRORS = "No errors recorded."
L.DEBUG_ON = "Debug messages on."
L.DEBUG_OFF = "Debug messages off."
L.LOCKED = "Frames locked."
L.UNLOCKED = "Frames unlocked: drag the blue squares."
L.HELP = "Commands: /hs (settings), /hs diag, /hs debug, /hs lock, /hs preview 5|10|20|40, /hs preview (hide)"
```

Al final de `Locales/esES.lua`:

```lua

-- Diagnóstico y comandos
L.DIAG_HEADER = "Healsilus %s · cliente %s (%s) · Interface %s"
L.DIAG_OK = "OK"
L.DIAG_MISSING = "FALTA"
L.DIAG_EVENT = "evento %s: %s"
L.DIAG_AURA_CONTAINER = "Contenedores nativos de auras: %s"
L.DIAG_ALPHA_BOOLEAN = "SetAlphaFromBoolean: %s"
L.DIAG_SPELLS_OK = "Todos los IDs de hechizo del perfil existen."
L.DIAG_SPELLS_MISSING = "IDs de hechizo desconocidos: %s"
L.DIAG_HEADER_BUTTONS = "Cabecera %s: %d botones"
L.DIAG_PROFILE = "Origen del perfil: %s · acciones en cola: %d"
L.DIAG_FIXES = "Datos guardados corregidos: %s"
L.DIAG_NO_ERRORS = "Sin errores registrados."
L.DEBUG_ON = "Mensajes de depuración activados."
L.DEBUG_OFF = "Mensajes de depuración desactivados."
L.LOCKED = "Marcos bloqueados."
L.UNLOCKED = "Marcos desbloqueados: arrastra los cuadrados azules."
L.HELP = "Comandos: /hs (configuración), /hs diag, /hs debug, /hs lock, /hs preview 5|10|20|40, /hs preview (ocultar)"
```

- [ ] **Step 2: Escribe la prueba `tests/test_diagnostics_commands.lua`**

```lua
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
  environment.HealsilusDB = { debug = false }
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

  it("prints the help for unknown commands", function()
    local _, environment = LoadTools()
    environment.SlashCmdList.HEALSILUS("bogus")
    assertTrue(string.find(environment.__state.printed[1], "/hs diag", 1, true) ~= nil)
  end)
end)
```

- [ ] **Step 3: Añade el fichero a `tests/run.lua` y ejecuta**

Run: `luajit tests/run.lua`
Expected: FAIL — `cannot open Core/Diagnostics.lua`.

- [ ] **Step 4: Crea `Core/Diagnostics.lua`**

```lua
-- /hs diag: qué APIs existen en este cliente, autopruebas, IDs de hechizo sin resolver y errores guardados.
-- Sirve para comprobar en el juego los puntos del diseño que no se pueden verificar fuera de él.
local _, ns = ...
local L = ns.L

local Diagnostics = ns.Diagnostics

local API_CHECKS = {
  { "CreateUnitHealPredictionCalculator", function() return CreateUnitHealPredictionCalculator end },
  { "UnitGetDetailedHealPrediction", function() return UnitGetDetailedHealPrediction end },
  { "UnitHealthPercent", function() return UnitHealthPercent end },
  { "UnitHealthMissing", function() return UnitHealthMissing end },
  { "AbbreviateLargeNumbers", function() return AbbreviateLargeNumbers end },
  { "C_CurveUtil.CreateColorCurve", function() return C_CurveUtil and C_CurveUtil.CreateColorCurve end },
  { "issecretvalue", function() return issecretvalue end },
  { "C_UnitAuras.GetAuraDataBySpellName", function() return C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName end },
  { "C_Secrets.HasSecretRestrictions", function() return C_Secrets and C_Secrets.HasSecretRestrictions end },
  { "C_SpellBook.GetSpellBookItemInfo", function() return C_SpellBook and C_SpellBook.GetSpellBookItemInfo end },
  { "C_SpecializationInfo.GetActiveSpecGroup", function() return C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup end },
  { "GetActiveTalentGroup", function() return GetActiveTalentGroup end },
  { "MenuUtil.CreateContextMenu", function() return MenuUtil and MenuUtil.CreateContextMenu end },
  { "Settings.RegisterCanvasLayoutCategory", function() return Settings and Settings.RegisterCanvasLayoutCategory end },
  { "C_EventUtils.IsEventValid", function() return C_EventUtils and C_EventUtils.IsEventValid end },
  { "RegisterStateDriver", function() return RegisterStateDriver end },
}

local EVENT_CHECKS = {
  "PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED", "UNIT_IN_RANGE_UPDATE",
  "UNIT_HEAL_PREDICTION", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_THREAT_SITUATION_UPDATE",
}

local function Status(present)
  return present and L.DIAG_OK or L.DIAG_MISSING
end

-- IDs usados por el perfil (y por el perfil de serie del druida) que el cliente no reconoce.
function Diagnostics.UnresolvedSpells(profile)
  local spellIDs = {}
  for _, spellID in pairs(ns.DRUID_SPELLS) do
    spellIDs[spellID] = true
  end
  for _, binding in pairs(profile.bindings) do
    if binding.kind == "spell" then
      spellIDs[binding.spellID] = true
      if binding.fallbackSpellID then
        spellIDs[binding.fallbackSpellID] = true
      end
    end
  end
  for spellID in pairs(profile.auras.hotSpellIDs) do
    spellIDs[spellID] = true
  end
  for _, entry in ipairs(profile.buffs.watched) do
    spellIDs[entry.spellID] = true
    if entry.groupSpellID then
      spellIDs[entry.groupSpellID] = true
    end
  end
  local missing = {}
  for spellID in pairs(spellIDs) do
    if not ns.Spells:GetName(spellID) then
      missing[#missing + 1] = tostring(spellID)
    end
  end
  table.sort(missing)
  return missing
end

function Diagnostics:Run()
  local version, build, _, interface = GetBuildInfo()
  ns.Print(string.format(L.DIAG_HEADER, ns.version, tostring(version), tostring(build), tostring(interface)))
  for _, check in ipairs(API_CHECKS) do
    ns.Print(check[1] .. ": " .. Status(check[2]() ~= nil))
  end
  for _, event in ipairs(EVENT_CHECKS) do
    ns.Print(string.format(L.DIAG_EVENT, event, Status(ns.IsEventValid(event))))
  end
  ns.Print(string.format(L.DIAG_AURA_CONTAINER, Status(ns.Containers:IsSupported())))
  ns.Print(string.format(L.DIAG_ALPHA_BOOLEAN, Status(ns.UnitButton.alphaFromBooleanWorks)))
  local missing = Diagnostics.UnresolvedSpells(ns.Profiles.active)
  if #missing == 0 then
    ns.Print(L.DIAG_SPELLS_OK)
  else
    ns.Print(string.format(L.DIAG_SPELLS_MISSING, table.concat(missing, ", ")))
  end
  for _, header in ipairs(ns.Headers.list) do
    ns.Print(string.format(L.DIAG_HEADER_BUTTONS, header.healsilusKind, ns.Headers:CountButtons(header)))
  end
  ns.Print(string.format(L.DIAG_PROFILE, tostring(ns.Profiles.source), ns.CombatQueue:Count()))
  if #ns.Database.fixes > 0 then
    ns.Print(string.format(L.DIAG_FIXES, table.concat(ns.Database.fixes, ", ")))
  end
  if #self.errors == 0 then
    ns.Print(L.DIAG_NO_ERRORS)
    return
  end
  for position, entry in ipairs(self.errors) do
    ns.Print(string.format("%d. %s: %s", position, entry.context, entry.message))
  end
end
```

- [ ] **Step 5: Crea `Core/Commands.lua`**

```lua
-- Comandos: /hs (configuración), /hs diag, /hs debug, /hs lock, /hs preview N.
local _, ns = ...
local L = ns.L

local MAX_PREVIEW = 40

local function HandleCommand(message)
  local command, argument = string.match(strtrim(message or ""), "^(%S*)%s*(.-)$")
  command = string.lower(command or "")
  if command == "" or command == "config" then
    ns.Config:Toggle()
  elseif command == "diag" then
    ns.Diagnostics:Run()
  elseif command == "debug" then
    HealsilusDB.debug = not HealsilusDB.debug
    ns.Print(HealsilusDB.debug and L.DEBUG_ON or L.DEBUG_OFF)
  elseif command == "lock" then
    local frames = ns.Profiles.active.frames
    frames.locked = not frames.locked
    ns.Events:Fire("SETTINGS_CHANGED", "frames")
    ns.Print(frames.locked and L.LOCKED or L.UNLOCKED)
  elseif command == "preview" then
    local count = tonumber(argument)
    if count and count >= 1 then
      ns.Preview:Show(math.min(MAX_PREVIEW, math.floor(count)))
    else
      ns.Preview:Hide()
    end
  else
    ns.Print(L.HELP)
  end
end
ns.HandleCommand = HandleCommand

SLASH_HEALSILUS1 = "/hs"
SLASH_HEALSILUS2 = "/healsilus"
SlashCmdList.HEALSILUS = HandleCommand
```

- [ ] **Step 6: Añade `Core\Diagnostics.lua` y `Core\Commands.lua` al final de la lista de `Healsilus.toc`**

- [ ] **Step 7: Verifica**

Run: `luajit tests/run.lua` → Expected: `139 passed, 0 failed`
Run: `luajit tools/check.lua` → Expected: `check: OK (28 addon files, 54 Lua files)`

- [ ] **Step 8: Commit**

```powershell
git add Core/Diagnostics.lua Core/Commands.lua Locales Healsilus.toc tests
git commit -m @'
feat: add /hs commands and in-game diagnostics

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
'@
```

### Task 23: Arranque y prueba de carga completa

**Files:**
- Create: `Core/Bootstrap.lua`, `tests/test_bootstrap.lua`, `tests/test_load_all.lua`
- Modify: `Healsilus.toc` (añade `Core\Bootstrap.lua` al final), `tests/run.lua` (añade `"tests/test_bootstrap.lua",` y `"tests/test_load_all.lua",`)

- [ ] **Step 1: Escribe la prueba `tests/test_bootstrap.lua`**

```lua
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
```

- [ ] **Step 2: Escribe la prueba de humo `tests/test_load_all.lua`**

```lua
local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue = Harness.assertEquals, Harness.assertTrue

describe("Full addon load", function()
  it("loads every TOC file in order without errors", function()
    local environment = Stubs.NewEnvironment({ permissive = true })
    local ns = Loader.Load(environment, Loader.TocFiles("Healsilus.toc"))
    for _, module in ipairs({ "Events", "CombatQueue", "Database", "Spells", "Profiles", "Serializer", "Media",
      "Curves", "ClickCast", "Prediction", "Containers", "MissingBuffs", "UnitButton", "Headers", "Preview",
      "Widgets", "Config", "Diagnostics" }) do
      assertTrue(type(ns[module]) == "table", module)
    end
  end)

  it("registers the settings tabs in the intended order", function()
    local environment = Stubs.NewEnvironment({ permissive = true })
    local ns = Loader.Load(environment, Loader.TocFiles("Healsilus.toc"))
    assertEquals(ns.Config.tabOrder, { "clicks", "frames", "auras", "buffs", "profiles" })
  end)
end)
```

- [ ] **Step 3: Añade los dos ficheros a `tests/run.lua` y ejecuta**

Run: `luajit tests/run.lua`
Expected: FAIL — `cannot open Core/Bootstrap.lua` (la prueba de humo pasa ya; la de arranque falla).

- [ ] **Step 4: Crea `Core/Bootstrap.lua`**

```lua
-- Arranque: datos guardados al cargar el addon, todo lo demás al entrar al mundo.
-- También reacciona a cambios del libro de hechizos y de especialización.
local addonName, ns = ...

ns.Events:RegisterGameEvent("ADDON_LOADED", function(_, loadedName)
  if loadedName ~= addonName then
    return
  end
  ns.Database:Initialize()
end)

ns.Events:RegisterGameEvent("PLAYER_LOGIN", function()
  ns.Spells:Scan()
  ns.Profiles:Initialize()
  ns.UnitButton:Initialize()
  ns.Headers:Initialize()
  ns.Config:RegisterSettingsCategory()
  ns.Events:Fire("READY")
end)

ns.Events:RegisterGameEvent("SPELLS_CHANGED", function()
  if not ns.Profiles.active then
    return
  end
  ns.Spells:Scan()
  ns.Events:Fire("SPELLBOOK_UPDATED")
end)

local function OnSpecializationChanged(_, unit)
  if unit and unit ~= "player" then
    return
  end
  if ns.Profiles.active then
    ns.Profiles:Refresh()
  end
end

ns.Events:RegisterGameEvent("PLAYER_SPECIALIZATION_CHANGED", OnSpecializationChanged)
ns.Events:RegisterGameEvent("ACTIVE_TALENT_GROUP_CHANGED", OnSpecializationChanged)
```

- [ ] **Step 5: Añade `Core\Bootstrap.lua` al final de la lista de `Healsilus.toc`**

- [ ] **Step 6: Verifica**

Run: `luajit tests/run.lua` → Expected: `144 passed, 0 failed`
Run: `luajit tools/check.lua` → Expected: `check: OK (29 addon files, 57 Lua files)`

- [ ] **Step 7: Commit**

```powershell
git add Core/Bootstrap.lua Healsilus.toc tests
git commit -m @'
feat: wire addon startup, spellbook and spec changes

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
'@
```

### Task 24: Instalación de desarrollo, README y verificación en el juego

**Files:**
- Create: `tools/link-addon.ps1`, `README.md`, `docs/testing/in-game-checklist.md`

- [ ] **Step 1: Crea `tools/link-addon.ps1`**

```powershell
# Enlaza la carpeta del repositorio como addon de WoW Forever (junction: no copia ficheros).
param(
  [string]$AddOnsPath = "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns"
)
$ErrorActionPreference = "Stop"
$repository = Split-Path -Parent $PSScriptRoot
$target = Join-Path $AddOnsPath "Healsilus"
if (-not (Test-Path $AddOnsPath)) {
  throw "AddOns folder not found: $AddOnsPath"
}
if (Test-Path $target) {
  $item = Get-Item $target -Force
  if ($item.LinkType -eq "Junction") {
    Write-Output "Already linked: $target -> $($item.Target)"
    exit 0
  }
  throw "$target already exists and is not a junction. Move it away first."
}
New-Item -ItemType Junction -Path $target -Target $repository | Out-Null
Write-Output "Linked $target -> $repository"
```

- [ ] **Step 2: Crea `README.md`**

````markdown
# Healsilus

Marcos de curación con click-casting (estilo HealBot) para **World of Warcraft: Forever**, hechos desde cero para las restricciones de addons de la arquitectura Midnight (valores secretos).

## Qué hace

- Click-casting: botón del ratón + Alt/Ctrl/Shift → hechizo (con rango opcional), macro, objetivo o menú.
- Barras de grupo y banda (10/20/40), bloque de tanques, mascotas, objetivo y foco amistosos.
- Curación entrante y escudos, rango, aggro, muerto y desconectado.
- Tus HoTs con cuenta atrás, debuffs con el color del tipo de dispel y buffs tuyos que faltan.
- Perfiles por clase, por personaje y por especialización. Exportar e importar.
- Perfil de serie para druida.

## Normas de Blizzard

El addon nunca decide qué hechizo lanzar ni a quién: cada lanzamiento es un clic tuyo sobre una asignación fija. Los valores secretos solo se pasan a widgets nativos y nada seguro se toca en combate.

## Instalación (desarrollo)

```powershell
powershell -ExecutionPolicy Bypass -File tools/link-addon.ps1
```

Luego, en el juego, `/reload` y `/hs`.

## Comandos

| Comando | Qué hace |
|---|---|
| `/hs` | Abre la configuración |
| `/hs diag` | Diagnóstico del cliente y del addon |
| `/hs lock` | Bloquea o desbloquea los marcos para moverlos |
| `/hs preview 5` (10, 20, 40) | Vista previa con miembros falsos; `/hs preview` la cierra |
| `/hs debug` | Mensajes de depuración |

## Pruebas

Necesitas LuaJIT (`scoop install luajit`). Desde la raíz del repositorio:

```powershell
luajit tests/run.lua
```

```powershell
luajit tools/check.lua
```

La verificación en el juego está en [docs/testing/in-game-checklist.md](docs/testing/in-game-checklist.md).
````

- [ ] **Step 3: Crea `docs/testing/in-game-checklist.md`**

```markdown
# Verificación en el juego

Haz cada paso en un druida con Healsilus enlazado (`tools/link-addon.ps1`) y HealBot desactivado. Si algo falla, copia la salida de `/hs diag` y el error de Lua.

## 1. Diagnóstico
- [ ] `/reload` sin errores de Lua.
- [ ] `/hs diag`: la cabecera muestra `Interface 16001`.
- [ ] Todas las APIs salen `OK`. Anota las que salgan `FALTA`.
- [ ] `Contenedores nativos de auras: OK`.
- [ ] `SetAlphaFromBoolean: OK`. Si sale `FALTA`, el rango con secretos usa alfa fija (diseño §11).
- [ ] `Todos los IDs de hechizo del perfil existen.` Si no, corrige los IDs en `Data/Druid.lua`.
- [ ] `Cabecera party: 40 botones`, `tanks: 8`, `pets: 20`. Si sale menos, la precreación no funciona (diseño §11) y los botones nuevos recibirán auras al salir de combate.

## 2. Valores secretos forzados (fuera de combate)
- [ ] `/console secretCombatRestrictionsForced 1`, `/console secretEncounterRestrictionsForced 1` y `/console secretMapRestrictionsForced 1`.
- [ ] Las barras, la curación entrante, los HoTs y los debuffs siguen funcionando sin errores de Lua.
- [ ] El texto de vida en déficit funciona o cambia solo a porcentaje (queda anotado en `/hs diag`).
- [ ] Vuelve a poner los tres CVars a `0`.

## 3. Muñeco de entrenamiento
- [ ] Cada clic de la tabla lanza su hechizo sobre la barra (izquierdo Toque de sanación, derecho Rejuvenecer, Shift+izquierdo Recrecimiento...).
- [ ] Un rango fijo elegido en la pestaña Clics lanza ese rango.
- [ ] En combate, cambia una casilla: aparece "Pendiente" y se aplica al salir.
- [ ] `/hs preview 20` muestra 20 marcos falsos; al entrar en combate se cierran solos.

## 4. Grupo de mazmorra
- [ ] Las barras atenúan a quien está fuera de rango.
- [ ] Aparece borde rojo con aggro.
- [ ] Maldiciones y venenos pintan el anillo y el icono; Quitar maldición y Anular veneno funcionan con sus clics.
- [ ] Renacer funciona sobre un muerto.
- [ ] La esquina naranja marca a quien no tiene Marca; los tanques también sin Espinas. Fuera de combate se actualiza.

## 5. Banda (10/20/40)
- [ ] Alguien entra en combate y su barra tiene clics.
- [ ] Los tanques aparecen en su bloque (rol de tanque o Main Tank). Si no, revisa `roleFilter` (diseño §11).
- [ ] Mascotas visibles si están activadas.
- [ ] Los marcos de banda de Blizzard están ocultos.

## 6. Perfiles
- [ ] Activa "Perfil distinto por especialización", cambia de especialización y comprueba que el perfil cambia al salir de combate.
- [ ] Exporta el perfil en un PJ e impórtalo en otro.
- [ ] Copiar desde y Restablecer piden confirmación y funcionan.
```

- [ ] **Step 4: Ejecuta las pruebas y el check finales**

Run: `luajit tests/run.lua` → Expected: `144 passed, 0 failed`
Run: `luajit tools/check.lua` → Expected: `check: OK (29 addon files, 57 Lua files)`

- [ ] **Step 5: Enlaza el addon al cliente**

Run: `powershell -ExecutionPolicy Bypass -File tools/link-addon.ps1`
Expected: `Linked C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\Healsilus -> ...\healsilus`

- [ ] **Step 6: Commit**

```powershell
git add tools/link-addon.ps1 README.md docs/testing
git commit -m @'
docs: add dev install script, README and in-game checklist

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
'@
```

- [ ] **Step 7: Sube la rama**

```powershell
git push -u origin feat/healsilus-v1
```

- [ ] **Step 8: Pide al usuario que haga la verificación en el juego** con `docs/testing/in-game-checklist.md` y corrige lo que falle (cada corrección con su prueba si es lógica pura).

## Self-review del plan frente al diseño

| Sección del diseño | Tarea |
|---|---|
| §1.3 reglas de la plataforma | Convenciones + `tools/check.lua` (tarea 1), cola de combate (3), `IsSecret` (1) |
| §3 arquitectura y TOC | Tareas 1–23 (cada una añade su fichero al TOC) |
| §4.1 esquema y validación | Tarea 4 |
| §4.2 resolución de perfiles | Tarea 7; disparadores en tarea 23 |
| §4.3 exportar/importar | Tarea 8; interfaz en tarea 21 |
| §5.1 cabeceras y precreación | Tarea 15 |
| §5.2 ocultar Blizzard | Tarea 15 |
| §5.3 barra de unidad | Tareas 9 y 14 |
| §5.4 predicción | Tarea 11 |
| §6 click-casting y druida | Tareas 6 y 10; interfaz en tarea 18 |
| §7.1 auras nativas | Tarea 12 |
| §7.2 buffs que faltan | Tarea 13; interfaz en tarea 20 |
| §8 panel | Tareas 17–21 |
| §9 errores y diagnóstico | `RecordError` (1), diagnóstico (22) |
| §10 pruebas | Tareas 1–23 (offline) y 24 (en el juego) |
| §11 puntos a verificar | `docs/testing/in-game-checklist.md` (24) y `/hs diag` (22) |
