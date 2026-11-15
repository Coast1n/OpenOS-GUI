-- Run from any directory: lua /home/OpenOS-GUI/tests/run-stage7.lua /home/OpenOS-GUI
local filesystem, shell = require("filesystem"), require("shell")
local root = shell.resolve((...) or ".")
local output = assert(loadfile(root .. "/tests/support/report.lua"))()
local base, index, directory = filesystem.concat(root, "tests/results"), 1
repeat
  directory = filesystem.concat(base, string.format("stage7-run-%03d", index))
  index = index + 1
until not filesystem.exists(directory)
assert(filesystem.makeDirectory(directory), "cannot create result directory: " .. directory)
print("RESULT DIRECTORY: " .. directory)
local report = {suite = "STAGE7-AUTO-001", status = "running", lua = _VERSION,
  openos = _OSVERSION or "unknown", gtnh = "unknown", opencomputers = "unknown",
  directory = directory, phases = {}}
local function checkpoint()
  output.write(filesystem.concat(directory, "report.json"), output.json(report) .. "\n")
end
checkpoint()
local function phase(name, filename, expected, mode, hold)
  local log, reason = io.open(filesystem.concat(directory, name .. ".log"), "w")
  assert(log, reason)
  local function capture(...)
    local values = table.pack(...)
    for i = 1, values.n do values[i] = tostring(values[i]) end
    local line = table.concat(values, "\t", 1, values.n)
    assert(log:write(line .. "\n")); assert(log:flush()); print(line)
  end
  local env = setmetatable({print = capture}, {__index = _G})
  local detail
  local ok, tests = xpcall(function()
    local chunk, err = loadfile(root .. "/tests/" .. filename, "t", env)
    assert(chunk, err)
    return chunk(root, mode, {holdSeconds = hold or 0, saveReport = function(data)
      detail = data
      output.write(filesystem.concat(directory, name .. "-screen.json"), output.json(data) .. "\n")
    end})
  end, function(err) return debug.traceback(tostring(err), 2) end)
  if not ok then capture("TEST ERROR: " .. tostring(tests)) end
  output.close(log)
  local result = {name = name, log = name .. ".log", expected = expected}
  if not ok then result.error = tostring(tests) end
  if expected then
    if ok then result.tests = tests end
    result.passed = ok and type(tests) == "table" and tests.ok == true
      and tests.passed == expected and tests.failed == 0 and tests.total == expected
  else
    result.screenReport = detail and (name .. "-screen.json") or nil
    result.passed = ok and detail ~= nil and detail.passed == true and #detail.checks == 3
    result.visual = "pending user observation; automatic pass does not certify appearance"
  end
  report.phases[#report.phases + 1] = result
  checkpoint()
  return result.passed
end
local ok, result = xpcall(function()
  if not phase("tree-regression", "stage3.lua", 35) then return false end
  if not phase("events-regression", "stage4.lua", 36) then return false end
  if not phase("interaction-regression", "stage5.lua", 40) then return false end
  if not phase("painting", "stage6.lua", 30) then return false end
  if not phase("buttons", "stage7.lua", 24) then return false end
  if not phase("normal", "stage7-screen.lua", nil, nil, 120) then return false end
  return phase("exception", "stage7-screen.lua", nil, "fail", 0)
end, function(err) return debug.traceback(tostring(err), 2) end)
report.passed = ok and result == true
report.status = report.passed and "passed" or "failed"
if not ok then report.error = tostring(result) end
checkpoint()
output.write(filesystem.concat(directory, "summary.txt"), "STAGE7-AUTO-001: " .. report.status:upper()
  .. "\nExpected: 35 tree + 36 event + 40 interaction regressions + 30 painting regressions + 24 pointer-button cases.\nResult directory: " .. directory
  .. "\nAlso requires normal + intentional-exception real-screen modes, each with 3 initial readback checks and state restoration."
  .. "\nSee report.json, phase logs and *-screen.json. Human appearance review remains separate.\n")
print("STAGE7 AUTOMATIC RESULT: " .. report.status:upper())
print("FILES SAVED TO: " .. directory)
assert(report.passed, "tests failed; return the result directory")
