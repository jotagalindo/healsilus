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
