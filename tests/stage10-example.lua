-- Execute the actual example through a local public entry, without installation.
local root, _, options = ...
root, options = root or ".", options or {}
local import = assert(loadfile(root .. "/tests/support/loader.lua"))()(root)
local gui = import("ocgui")
local term = require("term")
local gpu = assert(term.gpu(), "no terminal GPU")
print("EXAMPLE TEST: activate 更新计数 at least once, then use 退出.")
local function snapshot()
  local s = {screen = gpu.getScreen(), depth = gpu.getDepth()}
  if gpu.getActiveBuffer then s.buffer = gpu.getActiveBuffer() end
  s.fg, s.fp = gpu.getForeground(); s.bg, s.bp = gpu.getBackground()
  s.width, s.height = gpu.getResolution(); s.vw, s.vh = gpu.getViewport()
  s.x, s.y = term.getCursor(); s.blink = term.getCursorBlink()
  return s
end
local report = {suite = "STAGE10-EXAMPLE-001", before = snapshot(), checks = {},
  visual = {status = "not_recorded"}, updates = 0}
local app, deadline
local public = {}
for key, value in pairs(gui) do public[key] = value end
public.application = function(options)
  app = gui.application(options)
  app.root:on("click", function() report.updates = report.updates + 1 end)
  local device = app._device
  local pull = device.pull
  device.pull = function(self, timeout)
    deadline = deadline or self:now() + 120
    local remaining = deadline - self:now()
    assert(remaining > 0, "example test timed out")
    return pull(self, timeout and math.min(timeout, remaining) or remaining)
  end
  return app
end
local env = setmetatable({require = function(name)
  if name == "ocgui" then return public end
  return import(name)
end}, {__index = _G})
local ok, reason = pcall(function()
  local chunk, err = loadfile(root .. "/examples/basic.lua", "t", env)
  assert(chunk, err); chunk()
end)
local closed, cleanup = true, nil
if app then closed, cleanup = app:close() end
local afterOK, after = pcall(snapshot)
local restored = afterOK
report.after, report.differences = afterOK and after or nil, {}
if afterOK then
  for key, value in pairs(report.before) do
    if after[key] ~= value then
      restored = false
      report.differences[#report.differences + 1] = key .. ": " .. tostring(value) .. " -> " .. tostring(after[key])
    end
  end
else report.differences[1] = tostring(after) end
local released = app ~= nil and app._state == "closed" and app.root._interactionOwner == nil
report.checks = {
  {name = "actual example executed and update activated", passed = ok and report.updates > 0},
  {name = "application closed and released", passed = closed == true and released},
  {name = "device state restored", passed = restored}
}
report.passed = true
for _, check in ipairs(report.checks) do if not check.passed then report.passed = false end end
report.error = not ok and tostring(reason) or nil
report.cleanupErrors = cleanup and cleanup.cleanupErrors or nil
if options.saveReport then options.saveReport(report) end
print("EXAMPLE UPDATES: " .. report.updates)
print("EXAMPLE RESULT: " .. (report.passed and "PASS" or "FAIL"))
assert(report.passed, "STAGE10 EXAMPLE FAILED: return result directory")
return report
