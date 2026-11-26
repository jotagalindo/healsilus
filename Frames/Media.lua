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
