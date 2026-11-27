-- Imán entre bloques (como los marcos pegajosos de HealBot): mientras arrastras un bloque, en cuanto
-- uno de sus bordes o su centro queda cerca del de otro bloque (o del centro de la pantalla) se pega a
-- él, y Snapping.Solve dice dónde dibujar la guía de alineación. Cálculo puro, sin APIs de WoW.
local _, ns = ...

local Snapping = {}
ns.Snapping = Snapping

local function HasSize(rect)
  return rect.right > rect.left and rect.top > rect.bottom
end

local function CenterX(rect)
  return (rect.left + rect.right) / 2
end

local function CenterY(rect)
  return (rect.top + rect.bottom) / 2
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

-- Candidatos de un eje: { delta, línea de la guía }. Bordes iguales, centros iguales y "pegado"
-- (borde contra borde con la separación gap).
local function AxisCandidates(moving, other, gap, horizontal)
  if horizontal then
    return {
      { other.left - moving.left, other.left },
      { other.right - moving.right, other.right },
      { CenterX(other) - CenterX(moving), CenterX(other) },
      { other.right + gap - moving.left, other.right },
      { other.left - gap - moving.right, other.left },
    }
  end
  return {
    { other.top - moving.top, other.top },
    { other.bottom - moving.bottom, other.bottom },
    { CenterY(other) - CenterY(moving), CenterY(other) },
    { other.bottom - gap - moving.top, other.bottom },
    { other.top + gap - moving.bottom, other.top },
  }
end

local function Better(best, candidate, threshold)
  local size = math.abs(candidate[1])
  if size > threshold then
    return best
  end
  if not best or size < math.abs(best[1]) then
    return candidate
  end
  return best
end

-- moving y others: { left, right, top, bottom } en las mismas coordenadas (y crece hacia arriba).
-- options: threshold (px), gap (px entre bloques pegados), screen = { width, height } para alinear con
-- el centro de la pantalla y grid = { originX, originY, size } para los ejes que el imán no mueva.
-- Devuelve dx, dy y las guías { x = línea vertical o nil, y = línea horizontal o nil }.
function Snapping.Solve(moving, others, options)
  local threshold, gap = options.threshold or 0, options.gap or 0
  local bestX, bestY
  if threshold > 0 then
    for _, other in ipairs(others) do
      if HasSize(other) then
        for _, candidate in ipairs(AxisCandidates(moving, other, gap, true)) do
          bestX = Better(bestX, candidate, threshold)
        end
        for _, candidate in ipairs(AxisCandidates(moving, other, gap, false)) do
          bestY = Better(bestY, candidate, threshold)
        end
      end
    end
    local screen = options.screen
    if screen then
      bestX = bestX or Better(nil, { screen.width / 2 - CenterX(moving), screen.width / 2 }, threshold)
      bestY = bestY or Better(nil, { screen.height / 2 - CenterY(moving), screen.height / 2 }, threshold)
    end
  end
  local dx, dy = bestX and bestX[1] or 0, bestY and bestY[1] or 0
  local guides = { x = bestX and bestX[2], y = bestY and bestY[2] }
  local grid = options.grid
  if grid and grid.size > 0 then
    local gridX, gridY = Snapping.ToGrid(moving, grid.originX, grid.originY, grid.size)
    if not bestX then
      dx = gridX
    end
    if not bestY then
      dy = gridY
    end
  end
  return dx, dy, guides
end

-- Forma corta (solo bloques): dx, dy que pegan o alinean el bloque; 0, 0 si nada está a menos de threshold.
function Snapping.Snap(moving, others, threshold, gap)
  local dx, dy = Snapping.Solve(moving, others, { threshold = threshold, gap = gap })
  return dx, dy
end
