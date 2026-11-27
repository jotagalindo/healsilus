-- Imán entre bloques (como los marcos pegajosos de HealBot): al soltar un bloque cerca de otro,
-- se pega a su borde (con una pequeña separación) o se alinea con él. Cálculo puro, sin APIs de WoW.
local _, ns = ...

local Snapping = {}
ns.Snapping = Snapping

local function HasSize(rect)
  return rect.right > rect.left and rect.top > rect.bottom
end

local function Closest(best, delta, threshold)
  local size = math.abs(delta)
  if size <= threshold and (best == nil or size < math.abs(best)) then
    return delta
  end
  return best
end

-- Rejilla del modo mover: líneas cada size píxeles a partir de origin (el centro de la pantalla).
-- Devuelve dx, dy para que la esquina superior izquierda del rectángulo caiga en la línea más cercana.
local function NearestLine(value, origin, size)
  return origin + math.floor((value - origin) / size + 0.5) * size
end

function Snapping.ToGrid(rect, originX, originY, size)
  if size <= 0 then
    return 0, 0
  end
  return NearestLine(rect.left, originX, size) - rect.left, NearestLine(rect.top, originY, size) - rect.top
end

-- moving y others: { left, right, top, bottom } en las mismas coordenadas (y crece hacia arriba).
-- Devuelve el desplazamiento dx, dy que pega o alinea el bloque; 0, 0 si nada está a menos de threshold.
function Snapping.Snap(moving, others, threshold, gap)
  if threshold <= 0 then
    return 0, 0
  end
  local bestX, bestY
  for _, other in ipairs(others) do
    if HasSize(other) then
      bestX = Closest(bestX, other.left - moving.left, threshold)
      bestX = Closest(bestX, other.right - moving.right, threshold)
      bestX = Closest(bestX, other.right + gap - moving.left, threshold)
      bestX = Closest(bestX, other.left - gap - moving.right, threshold)
      bestY = Closest(bestY, other.top - moving.top, threshold)
      bestY = Closest(bestY, other.bottom - moving.bottom, threshold)
      bestY = Closest(bestY, other.bottom - gap - moving.top, threshold)
      bestY = Closest(bestY, other.top + gap - moving.bottom, threshold)
    end
  end
  return bestX or 0, bestY or 0
end
