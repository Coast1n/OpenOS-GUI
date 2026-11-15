-- Run from any directory: lua /home/OpenOS-GUI/tests/run-stage3.lua /home/OpenOS-GUI
local filesystem = require("filesystem")
local shell = require("shell")
local root = shell.resolve((...) or ".")
local output = assert(loadfile(root .. "/tests/support/report.lua"))()
local base = filesystem.concat(root, "tests/results")
local index, directory = 1
repeat
  directory = filesystem.concat(base, string.format("stage3-run-%03d", index))
  index = index + 1
until not filesystem.exists(directory)
assert(filesystem.makeDirectory(directory), "cannot create result directory: " .. directory)
print("RESULT DIRECTORY: " .. directory)
local report = {suite = "STAGE3-AUTO-001", status = "running", lua = _VERSION,
  openos = _OSVERSION or "unknown", gtnh = "unknown", opencomputers = "unknown",
  directory = directory}
local function saveReport()
  output.write(filesystem.concat(directory, "report.json"), output.json(report) .. "\n")
end
saveReport()
local log, reason = io.open(filesystem.concat(directory, "tree.log"), "w")
assert(log, reason)
local function capture(...)
  local values = table.pack(...)
  for i = 1, values.n do values[i] = tostring(values[i]) end
  local line = table.concat(values, "\t", 1, values.n)
  assert(log:write(line .. "\n")); assert(log:flush())
  print(line)
end
local env = setmetatable({print = capture}, {__index = _G})
local ok, result = xpcall(function()
  local chunk, err = loadfile(root .. "/tests/stage3.lua", "t", env)
  assert(chunk, err)
  return chunk(root)
end, function(err) return debug.traceback(tostring(err), 2) end)
if not ok then capture("TEST ERROR: " .. tostring(result)) end
output.close(log)
if ok then report.tests = result else report.error = tostring(result) end
report.passed = ok and type(result) == "table" and result.ok == true
  and result.passed == 35 and result.failed == 0 and result.total == 35
report.status = report.passed and "passed" or "failed"
saveReport()
output.write(filesystem.concat(directory, "summary.txt"), "STAGE3-AUTO-001: " .. report.status:upper()
  .. "\nResult directory: " .. directory .. "\nSee report.json and tree.log.\n")
print("STAGE3 AUTOMATIC RESULT: " .. report.status:upper())
print("FILES SAVED TO: " .. directory)
assert(report.passed, "tests failed; return the result directory")
