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
