-- Mini framework de pruebas: describe/it y aserciones. Sin dependencias externas.
local Harness = { passed = 0, failed = 0, failures = {}, suite = "" }

local function Describe(value)
  if type(value) == "string" then
    return string.format("%q", value)
  end
  if type(value) ~= "table" then
    return tostring(value)
  end
  local keys = {}
  for key in pairs(value) do
    keys[#keys + 1] = key
  end
  table.sort(keys, function(left, right)
    return tostring(left) < tostring(right)
  end)
  local parts = {}
  for _, key in ipairs(keys) do
    parts[#parts + 1] = tostring(key) .. "=" .. Describe(value[key])
  end
  return "{" .. table.concat(parts, ", ") .. "}"
end
Harness.Describe = Describe

function Harness.DeepEqual(left, right)
  if type(left) ~= type(right) then
    return false
  end
  if type(left) ~= "table" then
    return left == right
  end
  for key, value in pairs(left) do
    if not Harness.DeepEqual(value, right[key]) then
      return false
    end
  end
  for key in pairs(right) do
    if left[key] == nil then
      return false
    end
  end
  return true
end

function Harness.describe(name, body)
  local previous = Harness.suite
  Harness.suite = previous == "" and name or (previous .. " > " .. name)
  body()
  Harness.suite = previous
end

function Harness.it(name, body)
  local ok, failure = xpcall(body, debug.traceback)
  if ok then
    Harness.passed = Harness.passed + 1
  else
    Harness.failed = Harness.failed + 1
    Harness.failures[#Harness.failures + 1] = Harness.suite .. " > " .. name .. "\n" .. tostring(failure)
  end
end

function Harness.assertEquals(actual, expected, message)
  if not Harness.DeepEqual(actual, expected) then
    error((message or "values differ") .. "\n  expected: " .. Describe(expected) .. "\n  actual:   " .. Describe(actual), 2)
  end
end

function Harness.assertTrue(value, message)
  if value ~= true then
    error((message or "expected true") .. ", got " .. Describe(value), 2)
  end
end

function Harness.assertFalse(value, message)
  if value ~= false then
    error((message or "expected false") .. ", got " .. Describe(value), 2)
  end
end

function Harness.assertNil(value, message)
  if value ~= nil then
    error((message or "expected nil") .. ", got " .. Describe(value), 2)
  end
end

function Harness.assertError(body, pattern, message)
  local ok, failure = pcall(body)
  if ok then
    error((message or "expected an error") .. " (none raised)", 2)
  end
  if pattern and not string.find(tostring(failure), pattern) then
    error((message or "error text mismatch") .. "\n  pattern: " .. pattern .. "\n  error:   " .. tostring(failure), 2)
  end
end

function Harness.Report()
  for _, failure in ipairs(Harness.failures) do
    io.stderr:write("FAIL: " .. failure .. "\n\n")
  end
  print(string.format("%d passed, %d failed", Harness.passed, Harness.failed))
  return Harness.failed == 0
end

return Harness
