-- Texturas, fuentes y colores compartidos por las barras, la vista previa y las auras.
-- Si otro addon cargó LibSharedMedia (HealBot lo trae), sus texturas y fuentes también se pueden elegir.
local _, ns = ...
local L = ns.L

local Media = {}
ns.Media = Media

Media.TEXTURES = {
  BLIZZARD = "Interface\\TargetingFrame\\UI-StatusBar",
  RAID = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
  FLAT = "Interface\\Buttons\\WHITE8X8",
}
Media.TEXTURE_ORDER = { "BLIZZARD", "RAID", "FLAT" }

Media.DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"
Media.FONTS = {
  FRIZQT = "Fonts\\FRIZQT__.TTF",
  ARIALN = "Fonts\\ARIALN.TTF",
  MORPHEUS = "Fonts\\MORPHEUS.TTF",
  SKURRI = "Fonts\\SKURRI.TTF",
}
Media.FONT_ORDER = { "FRIZQT", "ARIALN", "MORPHEUS", "SKURRI" }

Media.PET_COLOR = { r = 0.2, g = 0.8, b = 0.2 }
Media.OFFLINE_COLOR = { r = 0.5, g = 0.5, b = 0.5 }
Media.FALLBACK_COLOR = { r = 0.3, g = 0.7, b = 0.3 }

local function SharedMedia()
  if not LibStub then
    return nil
  end
  return LibStub("LibSharedMedia-3.0", true)
end

local function FromSharedMedia(kind, key)
  local shared = SharedMedia()
  return shared and shared:Fetch(kind, key, true) or nil
end

function Media.Texture(key)
  return Media.TEXTURES[key] or FromSharedMedia("statusbar", key) or Media.TEXTURES.BLIZZARD
end

function Media.Font(key)
  return Media.FONTS[key] or FromSharedMedia("font", key) or Media.DEFAULT_FONT
end

-- Opciones para los desplegables: primero las propias (con nombre traducido) y luego las de LibSharedMedia.
local function Options(order, labels, kind)
  local options, seen = {}, {}
  for _, key in ipairs(order) do
    options[#options + 1] = { value = key, label = labels[key] }
    seen[key] = true
  end
  local shared = SharedMedia()
  if shared then
    local names = shared:List(kind)
    table.sort(names)
    for _, name in ipairs(names) do
      if not seen[name] then
        options[#options + 1] = { value = name, label = name }
      end
    end
  end
  return options
end

function Media.TextureOptions()
  return Options(Media.TEXTURE_ORDER, { BLIZZARD = L.TEXTURE_BLIZZARD, RAID = L.TEXTURE_RAID, FLAT = L.TEXTURE_FLAT }, "statusbar")
end

function Media.FontOptions()
  return Options(Media.FONT_ORDER, { FRIZQT = L.FONT_FRIZQT, ARIALN = L.FONT_ARIALN, MORPHEUS = L.FONT_MORPHEUS, SKURRI = L.FONT_SKURRI }, "font")
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
-- Usa los colores del perfil (pestaña Debuffs); un tipo que falte toma su color de serie.
function Media.DispelColorMap(colors)
  local defaults = ns.Database.DefaultDispelColors()
  local map = {}
  for _, dispelType in ipairs(ns.Database.DISPEL_TYPES) do
    local color = (colors and colors[dispelType]) or defaults[dispelType]
    map[dispelType] = CreateColor(color.r, color.g, color.b, 1)
  end
  return map
end
