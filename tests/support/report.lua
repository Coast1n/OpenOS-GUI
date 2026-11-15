-- Test-only JSON output. No files are opened until write() is called.
local report = {}
local function quote(value)
  return '"' .. value:gsub('[%z\1-\31\\"]', function(char)
    if char == '"' then return '\\"' end
    if char == '\\' then return '\\\\' end
    return string.format('\\u%04x', string.byte(char))
  end) .. '"'
end
function report.json(value)
  local kind = type(value)
  if kind == "nil" then return "null" end
  if kind == "string" then return quote(value) end
  if kind == "boolean" then return tostring(value) end
  if kind == "number" then
    if value ~= value or value == math.huge or value == -math.huge then return quote(tostring(value)) end
    return tostring(value)
  end
  assert(kind == "table", "unsupported report value: " .. kind)
  local count, array = 0, true
  for key in pairs(value) do
    count = count + 1
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then array = false end
  end
  array = array and count > 0 and count == #value
  local parts = {}
  if array then
    for i = 1, count do parts[i] = report.json(value[i]) end
    return "[" .. table.concat(parts, ",") .. "]"
  end
  local keys = {}
  for key in pairs(value) do assert(type(key) == "string", "report key must be a string"); keys[#keys + 1] = key end
  table.sort(keys)
  for _, key in ipairs(keys) do parts[#parts + 1] = quote(key) .. ":" .. report.json(value[key]) end
  return "{" .. table.concat(parts, ",") .. "}"
end
function report.close(file)
  local flushed, flushReason = file:flush()
  local ok, result, closeReason = pcall(file.close, file)
  assert(flushed, flushReason)
  assert(ok, result)
  assert(result ~= false and not (result == nil and closeReason ~= nil), closeReason)
end
function report.write(path, contents)
  local file, reason = io.open(path, "w")
  assert(file, reason)
  local ok, err = file:write(contents)
  report.close(file)
  assert(ok, err)
end
return report
