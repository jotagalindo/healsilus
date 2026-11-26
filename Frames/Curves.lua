-- Curvas de C_CurveUtil: el cliente las evalúa con la vida secreta, el addon nunca ve el número.
local _, ns = ...

local Curves = { healthColors = {} }
ns.Curves = Curves

function Curves.IsSupported()
  return C_CurveUtil ~= nil and C_CurveUtil.CreateColorCurve ~= nil and C_CurveUtil.CreateCurve ~= nil
    and UnitHealthPercent ~= nil and Enum.LuaCurveType ~= nil and CreateColor ~= nil
end

local function ColorKey(color)
  return string.format("%.3f,%.3f,%.3f", color.r, color.g, color.b)
end

-- Curva de color de la vida según el estilo: crítico hasta criticalAt, herido en injuredAt y sano al 100 %.
-- Se guarda por combinación de colores y umbrales para no crear curvas nuevas en cada actualización.
function Curves:HealthColor(bar)
  local key = table.concat({
    ColorKey(bar.critical), ColorKey(bar.injured), ColorKey(bar.healthy),
    string.format("%.3f", bar.criticalAt), string.format("%.3f", bar.injuredAt),
  }, "|")
  local cached = self.healthColors[key]
  if cached then
    return cached
  end
  local curve = C_CurveUtil.CreateColorCurve()
  curve:SetType(Enum.LuaCurveType.Linear)
  local points = {
    { 0, bar.critical },
    { bar.criticalAt, bar.critical },
    { bar.injuredAt, bar.injured },
    { 1, bar.healthy },
  }
  for _, point in ipairs(points) do
    local color = point[2]
    curve:AddPoint(point[1], CreateColor(color.r, color.g, color.b, 1))
  end
  self.healthColors[key] = curve
  return curve
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
