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
