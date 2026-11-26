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
