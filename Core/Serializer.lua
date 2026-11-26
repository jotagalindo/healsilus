-- Exportar/importar perfiles como texto: formato propio con claves ordenadas + Base64.
-- El texto importado nunca se ejecuta: se analiza a mano y se valida campo a campo.
local _, ns = ...

local Serializer = {}
ns.Serializer = Serializer

-- HS2: perfiles desde que lo visual vive en estilos (datos versión 2). HS1: perfiles de la v0.0.1.
local PROFILE_PREFIX = "HS2:"
local LEGACY_PROFILE_PREFIX = "HS1:"
local STYLE_PREFIX = "HSS1:"
local MAX_DEPTH = 20
local MAX_INPUT_LENGTH = 200000
local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local PADDING = 61

local DECODE = {}
for position = 1, 64 do
  DECODE[string.byte(ALPHABET, position)] = position - 1
end

local function AlphabetChar(sextet)
  return string.sub(ALPHABET, sextet + 1, sextet + 1)
end

function Serializer.EncodeBase64(data)
  local output = {}
  for position = 1, #data, 3 do
    local first, second, third = string.byte(data, position, position + 2)
    local combined = first * 65536 + (second or 0) * 256 + (third or 0)
    local block = AlphabetChar(math.floor(combined / 262144) % 64) .. AlphabetChar(math.floor(combined / 4096) % 64)
    block = block .. (second and AlphabetChar(math.floor(combined / 64) % 64) or "=")
    block = block .. (third and AlphabetChar(combined % 64) or "=")
    output[#output + 1] = block
  end
  return table.concat(output)
end

function Serializer.DecodeBase64(text)
  if #text % 4 ~= 0 then
    return nil
  end
  local output = {}
  for position = 1, #text, 4 do
    local firstCode, secondCode, thirdCode, fourthCode = string.byte(text, position, position + 3)
    local first, second = DECODE[firstCode], DECODE[secondCode]
    local thirdPadded, fourthPadded = thirdCode == PADDING, fourthCode == PADDING
    local third = thirdPadded and 0 or DECODE[thirdCode]
    local fourth = fourthPadded and 0 or DECODE[fourthCode]
    if first == nil or second == nil or third == nil or fourth == nil then
      return nil
    end
    if thirdPadded and not fourthPadded then
      return nil
    end
    if (thirdPadded or fourthPadded) and position + 3 ~= #text then
      return nil
    end
    local combined = first * 262144 + second * 4096 + third * 64 + fourth
    local block = string.char(math.floor(combined / 65536) % 256)
    if not thirdPadded then
      block = block .. string.char(math.floor(combined / 256) % 256)
    end
    if not fourthPadded then
      block = block .. string.char(combined % 256)
    end
    output[#output + 1] = block
  end
  return table.concat(output)
end

local function IsFinite(number)
  return number == number and number ~= math.huge and number ~= -math.huge
end

local function SortKeys(left, right)
  local leftType, rightType = type(left), type(right)
  if leftType ~= rightType then
    return leftType == "number"
  end
  return left < right
end

local function SerializeValue(value, parts, depth)
  local valueType = type(value)
  if valueType == "string" then
    parts[#parts + 1] = "s" .. #value .. ":" .. value
  elseif valueType == "number" then
    if not IsFinite(value) then
      error("cannot serialize non-finite number")
    end
    parts[#parts + 1] = "n" .. string.format("%.17g", value) .. ";"
  elseif valueType == "boolean" then
    parts[#parts + 1] = value and "t" or "f"
  elseif valueType == "table" then
    if depth >= MAX_DEPTH then
      error("table nesting too deep")
    end
    local keys = {}
    for key in pairs(value) do
      local keyType = type(key)
      if keyType ~= "string" and keyType ~= "number" then
        error("unsupported key type: " .. keyType)
      end
      keys[#keys + 1] = key
    end
    table.sort(keys, SortKeys)
    parts[#parts + 1] = "{"
    for _, key in ipairs(keys) do
      SerializeValue(key, parts, depth + 1)
      SerializeValue(value[key], parts, depth + 1)
    end
    parts[#parts + 1] = "}"
  else
    error("unsupported value type: " .. valueType)
  end
end

-- Devuelve valor, siguiente posición; o nil, mensaje de error.
local function ParseValue(text, position, depth)
  local marker = string.sub(text, position, position)
  if marker == "s" then
    local colon = string.find(text, ":", position + 1, true)
    if not colon then
      return nil, "string size"
    end
    local size = tonumber(string.sub(text, position + 1, colon - 1))
    if not size or size < 0 or size % 1 ~= 0 then
      return nil, "string size"
    end
    local finish = colon + size
    if finish > #text then
      return nil, "string truncated"
    end
    return string.sub(text, colon + 1, finish), finish + 1
  elseif marker == "n" then
    local semicolon = string.find(text, ";", position + 1, true)
    if not semicolon then
      return nil, "number"
    end
    local number = tonumber(string.sub(text, position + 1, semicolon - 1))
    if not number or not IsFinite(number) then
      return nil, "number"
    end
    return number, semicolon + 1
  elseif marker == "t" then
    return true, position + 1
  elseif marker == "f" then
    return false, position + 1
  elseif marker == "{" then
    if depth >= MAX_DEPTH then
      return nil, "too deep"
    end
    local result = {}
    local cursor = position + 1
    while true do
      local current = string.sub(text, cursor, cursor)
      if current == "}" then
        return result, cursor + 1
      end
      if current == "" then
        return nil, "unterminated table"
      end
      local key, afterKey = ParseValue(text, cursor, depth + 1)
      if key == nil then
        return nil, afterKey
      end
      if type(key) ~= "string" and type(key) ~= "number" then
        return nil, "invalid key"
      end
      local value, afterValue = ParseValue(text, afterKey, depth + 1)
      if value == nil then
        return nil, afterValue
      end
      result[key] = value
      cursor = afterValue
    end
  end
  return nil, "unexpected character at " .. position
end

local function Encode(prefix, value)
  local parts = {}
  SerializeValue(value, parts, 0)
  return prefix .. Serializer.EncodeBase64(table.concat(parts))
end

-- Devuelve la tabla leída, o nil y un motivo legible ("empty", "wrong kind", "corrupted text"...).
local function Decode(text, prefix)
  if type(text) ~= "string" then
    return nil, "empty"
  end
  local compact = string.gsub(text, "%s", "")
  if compact == "" then
    return nil, "empty"
  end
  if #compact > MAX_INPUT_LENGTH then
    return nil, "too long"
  end
  if string.sub(compact, 1, #prefix) ~= prefix then
    return nil, "wrong kind"
  end
  local data = Serializer.DecodeBase64(string.sub(compact, #prefix + 1))
  if not data then
    return nil, "corrupted text"
  end
  local value, position = ParseValue(data, 1, 0)
  if value == nil then
    return nil, "corrupted data (" .. tostring(position) .. ")"
  end
  if position ~= #data + 1 then
    return nil, "trailing data"
  end
  return value
end

function Serializer.Export(profile)
  return Encode(PROFILE_PREFIX, profile)
end

-- Devuelve el perfil normalizado, o nil y un motivo legible.
function Serializer.Import(text)
  if type(text) == "string" and string.sub(string.gsub(text, "%s", ""), 1, #LEGACY_PROFILE_PREFIX) == LEGACY_PROFILE_PREFIX then
    return nil, "profile from an older version"
  end
  local profile, failure = Decode(text, PROFILE_PREFIX)
  if failure == "wrong kind" then
    return nil, "not a Healsilus profile"
  end
  if profile == nil then
    return nil, failure
  end
  local valid, field = ns.Database.ValidateProfile(profile)
  if not valid then
    return nil, "invalid field: " .. field
  end
  return ns.Database.NormalizeProfile(profile, {})
end

function Serializer.ExportStyle(style)
  return Encode(STYLE_PREFIX, style)
end

-- Devuelve el estilo normalizado, o nil y un motivo legible.
function Serializer.ImportStyle(text)
  local style, failure = Decode(text, STYLE_PREFIX)
  if failure == "wrong kind" then
    return nil, "not a Healsilus style"
  end
  if style == nil then
    return nil, failure
  end
  local valid, field = ns.StyleData.ValidateStyle(style)
  if not valid then
    return nil, "invalid field: " .. field
  end
  return ns.StyleData.NormalizeStyle(style, {})
end
