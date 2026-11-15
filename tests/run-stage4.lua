-- Run from any directory: lua /home/OpenOS-GUI/tests/run-stage4.lua /home/OpenOS-GUI
local filesystem, shell = require("filesystem"), require("shell")
local root = shell.resolve((...) or ".")
local output = assert(loadfile(root .. "/tests/support/report.lua"))()
local base, index, directory = filesystem.concat(root, "tests/results"), 1
repeat
  directory = filesystem.concat(base, string.format("stage4-run-%03d", index))
  index = index + 1
until not filesystem.exists(directory)
assert(filesystem.makeDirectory(directory), "cannot create result directory: " .. directory)
print("RESULT DIRECTORY: " .. directory)
local report = {suite = "STAGE4-AUTO-001", status = "running", lua = _VERSION,
  openos = _OSVERSION or "unknown", gtnh = "unknown", opencomputers = "unknown",
  directory = directory, phases = {}}
local function checkpoint()
  output.write(filesystem.concat(directory, "report.json"), output.json(report) .. "\n")
end
checkpoint()
local function phase(name, filename, expected)
  local log, reason = io.open(filesystem.concat(directory, name .. ".log"), "w")
  assert(log, reason)
  local function capture(...)
    local values = table.pack(...)
    for i = 1, values.n do values[i] = tostring(values[i]) end
    local line = table.concat(values, "\t", 1, values.n)
    assert(log:write(line .. "\n")); assert(log:flush()); print(line)
  end
  local env = setmetatable({print = capture}, {__index = _G})
  local ok, tests = xpcall(function()
    local chunk, err = loadfile(root .. "/tests/" .. filename, "t", env)
    assert(chunk, err); return chunk(root)
  end, function(err) return debug.traceback(tostring(err), 2) end)
  if not ok then capture("TEST ERROR: " .. tostring(tests)) end
  output.close(log)
  local result = {name = name, log = name .. ".log", expected = expected}
  if ok then result.tests = tests else result.error = tostring(tests) end
  result.passed = ok and type(tests) == "table" and tests.ok == true
    and tests.passed == expected and tests.failed == 0 and tests.total == expected
  report.phases[#report.phases + 1] = result
  checkpoint()
  return result.passed
end
local ok, result = xpcall(function()
  if not phase("tree-regression", "stage3.lua", 35) then return false end
  return phase("events", "stage4.lua", 36)
end, function(err) return debug.traceback(tostring(err), 2) end)
report.passed = ok and result == true
report.status = report.passed and "passed" or "failed"
if not ok then report.error = tostring(result) end
checkpoint()
output.write(filesystem.concat(directory, "summary.txt"), "STAGE4-AUTO-001: " .. report.status:upper()
  .. "\nExpected: 35 tree regression cases + 36 event cases.\nResult directory: " .. directory
  .. "\nSee report.json, tree-regression.log and events.log.\n")
print("STAGE4 AUTOMATIC RESULT: " .. report.status:upper())
print("FILES SAVED TO: " .. directory)
assert(report.passed, "tests failed; return the result directory")
