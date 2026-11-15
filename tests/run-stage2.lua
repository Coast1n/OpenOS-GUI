-- Run all stage2 phases and save artifacts without screenshots or redirection.
-- OpenOS: lua tests/run-stage2.lua .
local filesystem = require("filesystem")
local shell = require("shell")
-- filesystem paths are root-relative; io.open resolves against the shell cwd.
-- Resolve once so directory creation, file writes and phase loading agree.
local root = shell.resolve((...) or ".")
local base = filesystem.concat(root, "tests/results")
local index, directory = 1
repeat
  directory = filesystem.concat(base, string.format("stage2-run-%03d", index))
  index = index + 1
until not filesystem.exists(directory)
assert(filesystem.makeDirectory(directory), "cannot create result directory: " .. directory)
print("RESULT DIRECTORY: " .. directory)

local function quote(value)
  return '"' .. value:gsub('[%z\1-\31\\"]', function(char)
    if char == '"' then return '\\"' end
    if char == '\\' then return '\\\\' end
    return string.format('\\u%04x', string.byte(char))
  end) .. '"'
end
local function json(value)
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
    for i = 1, count do parts[i] = json(value[i]) end
    return "[" .. table.concat(parts, ",") .. "]"
  end
  local keys = {}
  for key in pairs(value) do assert(type(key) == "string", "report object key must be a string"); keys[#keys + 1] = key end
  table.sort(keys)
  for _, key in ipairs(keys) do parts[#parts + 1] = quote(key) .. ":" .. json(value[key]) end
  return "{" .. table.concat(parts, ",") .. "}"
end
local function closeFile(file)
  local flushed, flushReason = file:flush()
  local ok, result, closeReason = pcall(file.close, file)
  assert(flushed, flushReason)
  assert(ok, result)
  -- OC filesystem.close may succeed without returning a value.
  assert(result ~= false and not (result == nil and closeReason ~= nil), closeReason)
end
local function save(name, contents)
  local file, reason = io.open(filesystem.concat(directory, name), "w")
  assert(file, reason)
  local ok, err = file:write(contents)
  closeFile(file)
  assert(ok, err)
end
local report = {suite = "STAGE2-AUTO-004", status = "running", lua = _VERSION,
  openos = _OSVERSION or "unknown", gtnh = "unknown", opencomputers = "unknown",
  directory = directory, phases = {}}
local function checkpoint()
  save("report.json", json(report) .. "\n")
end
checkpoint()

local function phase(name, script, mode)
  local log, reason = io.open(filesystem.concat(directory, name .. ".log"), "w")
  assert(log, reason)
  local lines, detail = {}, nil
  local function capture(...)
    local values = table.pack(...)
    for i = 1, values.n do values[i] = tostring(values[i]) end
    local line = table.concat(values, "\t", 1, values.n)
    lines[#lines + 1] = line
    assert(log:write(line .. "\n")); assert(log:flush())
    print(line)
  end
  local env = setmetatable({print = capture}, {__index = _G})
  local ok, err = xpcall(function()
    local chunk, loadErr = loadfile(root .. "/tests/" .. script, "t", env)
    assert(chunk, loadErr)
    return chunk(root, mode, {holdSeconds = 0, saveReport = function(data)
      detail = data
      save(name .. "-screen.json", json(data) .. "\n")
    end})
  end, function(reasonValue)
    local message = type(reasonValue) == "table" and tostring(reasonValue.message) or tostring(reasonValue)
    return debug.traceback(message, 2)
  end)
  if not ok then
    -- The screen script has already attempted cleanup before reporting errors.
    capture("PHASE ERROR: " .. tostring(err))
  end
  closeFile(log)
  local result = {name = name, passed = ok, log = name .. ".log"}
  if detail then
    result.screenReport = name .. "-screen.json"
    result.passed = ok and detail.passed == true
  end
  if name == "mock" then
    local output = table.concat(lines, "\n")
    local passed, failed, total = output:match("SUMMARY: (%d+) passed, (%d+) failed, (%d+) total")
    result.caseCounts = {passed = tonumber(passed), failed = tonumber(failed), total = tonumber(total)}
    result.passed = ok and passed == "28" and failed == "0" and total == "28"
  elseif not detail then
    result.passed = false
  end
  if not ok then result.error = tostring(err) end
  report.phases[#report.phases + 1] = result
  checkpoint()
  return result.passed
end

local ok, reason = xpcall(function()
  if not phase("mock", "stage2.lua") then return false end
  -- OC's user environment does not guarantee collectgarbage is available.
  -- Explicit collection is not required to advance between test phases.
  if not phase("normal", "stage2-screen.lua") then return false end
  if not phase("exception", "stage2-screen.lua", "fail") then return false end
  return true
end, function(value) return debug.traceback(tostring(value), 2) end)
report.passed = ok and reason == true
report.status = report.passed and "passed" or "failed"
if not ok then report.runnerError = tostring(reason) end
checkpoint()
save("summary.txt", "STAGE2-AUTO-004: " .. report.status:upper() .. "\n"
  .. "Lua: " .. tostring(report.lua) .. "\nOpenOS: " .. tostring(report.openos) .. "\n"
  .. "Result directory: " .. directory .. "\n"
  .. "See report.json, phase logs and *-screen.json for details.\n"
  .. "Client font appearance and interactive shell input are not automatically certified.\n")
print("STAGE2 AUTOMATIC RESULT: " .. report.status:upper())
print("FILES SAVED TO: " .. directory)
assert(report.passed, "tests failed; return the result directory; screenshots are not required")
