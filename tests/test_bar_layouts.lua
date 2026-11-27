local Harness = require("harness")
local Stubs = require("wow_stubs")
local Loader = require("loader")
local describe, it = Harness.describe, Harness.it
local assertEquals, assertTrue, assertFalse = Harness.assertEquals, Harness.assertTrue, Harness.assertFalse

local function LoadBarLayouts()
  local environment = Stubs.NewEnvironment({ locale = "esES" })
  local ns = Loader.Load(environment, {
    "Core/Init.lua", "Locales/enUS.lua", "Locales/esES.lua", "Core/Database.lua", "Core/StyleData.lua", "Core/BarLayouts.lua",
  })
  ns.Database:Initialize()
  return ns, environment
end

-- Geometría de una barra fuera del juego: rectángulos en la zona de vida (x a la derecha, y hacia abajo).
-- Medidas prudentes de texto: alto 1,15 × tamaño; ancho 0,62 × tamaño por carácter.
local GAP = 1
local CHAR, LINE = 0.62, 1.15

local function Area(style)
  local power = style.power
  local height = style.layout.height - 4 - (power.show and (power.thickness + 1) or 0)
  return style.layout.width - 4, height
end

-- Rectángulo de algo de w × h anclado por su punto "point" al mismo punto de la zona, desplazado x, y
-- (y positiva hacia arriba, como en WoW).
local function Place(point, x, y, w, h, areaW, areaH)
  local anchorX = string.find(point, "LEFT") and 0 or string.find(point, "RIGHT") and areaW or areaW / 2
  local anchorY = string.find(point, "TOP") and 0 or string.find(point, "BOTTOM") and areaH or areaH / 2
  local left = anchorX + x - (string.find(point, "LEFT") and 0 or string.find(point, "RIGHT") and w or w / 2)
  local top = anchorY - y - (string.find(point, "TOP") and 0 or string.find(point, "BOTTOM") and h or h / 2)
  return { left = left, top = top, right = left + w, bottom = top + h }
end

local function TextRect(element, width, areaW, areaH)
  return Place(element.point, element.x, element.y, width, element.size * LINE, areaW, areaH)
end

local function Icons(ns, group, count, areaW, areaH)
  local anchor = ns.StyleData.AuraAnchor(group)
  assertEquals(anchor.relativeTo, "BAR", "las propuestas no ponen iconos fuera")
  local step = (group.iconSize + 1) * (anchor.horizontal == "Left" and -1 or 1)
  local rects = {}
  for position = 1, count do
    rects[position] = Place(anchor.point, anchor.x + (position - 1) * step, anchor.y, group.iconSize, group.iconSize, areaW, areaH)
  end
  return rects
end

-- Todo lo que se dibuja a la vez en una barra viva (todos los iconos llenos) o muerta/desconectada.
local function Elements(ns, style, profile, dead)
  local areaW, areaH = Area(style)
  local list = {}
  local function Add(label, rect)
    list[#list + 1] = { label = label, rect = rect }
  end
  local text = style.text
  Add("name", TextRect(text.name, ns.StyleData.NameWidth(style), areaW, areaH))
  if style.role.show then
    Add("role", Place(style.role.point, style.role.x, style.role.y, style.role.size, style.role.size, areaW, areaH))
  end
  if dead then
    Add("status", TextRect(text.status, #"Desconectado" * CHAR * text.status.size, areaW, areaH))
    return list, areaW, areaH
  end
  if text.health.mode ~= "NONE" then
    Add("health", TextRect(text.health, #"-12.5K" * CHAR * text.health.size, areaW, areaH))
  end
  local aggro = style.aggro
  if aggro.dots then
    local towardsLeft = string.find(aggro.point, "RIGHT") ~= nil
    for position = 1, 3 do
      local x = aggro.x + (position - 1) * (aggro.size + 1) * (towardsLeft and -1 or 1)
      Add("aggro" .. position, Place(aggro.point, x, aggro.y, aggro.size, aggro.size, areaW, areaH))
    end
  end
  for position, rect in ipairs(Icons(ns, style.auras.hots, profile.auras.hotsMax, areaW, areaH)) do
    Add("hot" .. position, rect)
  end
  for position, rect in ipairs(Icons(ns, style.auras.debuffs, profile.auras.debuffsMax, areaW, areaH)) do
    Add("debuff" .. position, rect)
  end
  Add("buff", Icons(ns, style.auras.buffs, 1, areaW, areaH)[1])
  return list, areaW, areaH
end

local function Overlaps(a, b)
  return a.left < b.right + GAP and b.left < a.right + GAP and a.top < b.bottom + GAP and b.top < a.bottom + GAP
end

-- El borde de aggro sale 2 px por fuera del botón: dos vecinas con aggro no deben tocarse.
local AGGRO_BORDER = 2

local function CheckLayout(ns, key)
  local style, profile = ns.StyleData.DefaultStyle(), ns.Database.DefaultProfile()
  ns.BarLayouts.Apply(ns.BarLayouts.Preset(key), style, profile)
  assertTrue(style.layout.spacing >= 2 * AGGRO_BORDER, key .. ": los bordes de aggro de dos vecinas se pisan")
  for _, dead in ipairs({ false, true }) do
    local list, areaW, areaH = Elements(ns, style, profile, dead)
    for position, element in ipairs(list) do
      local rect = element.rect
      assertTrue(rect.left >= 0 and rect.top >= 0 and rect.right <= areaW and rect.bottom <= areaH,
        key .. ": " .. element.label .. " se sale de la barra")
      for other = position + 1, #list do
        assertFalse(Overlaps(rect, list[other].rect), key .. ": " .. element.label .. " pisa " .. list[other].label)
      end
    end
  end
  return style, profile
end

describe("Bar layout presets", function()
  it("never overlap anything, alive with every icon or dead, and stay inside the bar", function()
    local ns = LoadBarLayouts()
    for _, preset in ipairs(ns.BarLayouts.PRESETS) do
      CheckLayout(ns, preset.key)
    end
  end)

  it("would catch a name long enough to reach the debuffs", function()
    local ns = LoadBarLayouts()
    local style, profile = ns.StyleData.DefaultStyle(), ns.Database.DefaultProfile()
    ns.BarLayouts.Apply(ns.BarLayouts.Preset("healer"), style, profile)
    style.text.name.widthPct = 1
    local list = Elements(ns, style, profile, false)
    local found = false
    for position, element in ipairs(list) do
      for other = position + 1, #list do
        found = found or Overlaps(element.rect, list[other].rect)
      end
    end
    assertTrue(found)
  end)

  it("are valid and change only layout, never colors, textures or fonts", function()
    local ns = LoadBarLayouts()
    for _, preset in ipairs(ns.BarLayouts.PRESETS) do
      local data = ns.BarLayouts.Preset(preset.key)
      assertTrue(ns.BarLayouts.IsValid(data), preset.key)
      local style = ns.StyleData.DefaultStyle()
      style.bar.texture, style.text.font = "RAID", "ARIALN"
      ns.BarLayouts.Apply(data, style, ns.Database.DefaultProfile())
      assertEquals({ style.bar.texture, style.text.font, style.bar.colorMode }, { "RAID", "ARIALN", "CLASS" })
      assertTrue(ns.StyleData.ValidateStyle(style), preset.key)
    end
  end)
end)

describe("Saved bar layouts", function()
  it("saves the current layout under a free name and applies it back", function()
    local ns = LoadBarLayouts()
    local style, profile = ns.StyleData.DefaultStyle(), ns.Database.DefaultProfile()
    style.auras.hots.position, style.text.name.size = "TOP", 14
    assertEquals(ns.BarLayouts.Save("  Mía ", style, profile), "Mía")
    assertEquals({ ns.BarLayouts.Save("Mía", style, profile) }, { nil, "name taken" })
    assertEquals({ ns.BarLayouts.Save("   ", style, profile) }, { nil, "bad name" })
    assertEquals(ns.BarLayouts.SavedNames(), { "Mía" })
    local other = ns.StyleData.DefaultStyle()
    ns.BarLayouts.Apply(ns.Database.db.barLayouts["Mía"], other, ns.Database.DefaultProfile())
    assertEquals({ other.auras.hots.position, other.text.name.size }, { "TOP", 14 })
    ns.BarLayouts.Delete("Mía")
    assertEquals(ns.BarLayouts.SavedNames(), {})
  end)

  it("drops saved layouts with unknown fields or bad values when loading", function()
    local ns, environment = LoadBarLayouts()
    local good = ns.BarLayouts.Preset("raid")
    local bad = ns.BarLayouts.Preset("raid")
    bad.style["auras.hots.position"] = "NOWHERE"
    local extra = ns.BarLayouts.Preset("raid")
    extra.style["bar.texture"] = "RAID"
    environment.HealsilusDB.barLayouts = { Good = good, Bad = bad, Extra = extra, Broken = 4 }
    local db = ns.Database:Initialize()
    assertEquals(ns.BarLayouts.SavedNames(), { "Good" })
    assertTrue(db.barLayouts.Good ~= nil)
  end)
end)
