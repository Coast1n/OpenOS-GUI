-- Smoke-test the actual distribution files against injected OpenOS services.
local root = require("shell").resolve((...) or ".")
local fs = require("filesystem")
local output = assert(loadfile(root .. "/tests/support/report.lua"))()
local fake = assert(loadfile(root .. "/tests/support/fake_openos.lua"))()
local unicode = require("unicode")
local index, directory = 1
repeat
  directory = root .. string.format("/tests/results/bundle-run-%03d", index)
  index = index + 1
until not fs.exists(directory)
assert(fs.makeDirectory(directory))
local report = {suite = "BUNDLE-001", passed = 0, failed = 0, cases = {}, lua = _VERSION}
local function eq(a, b) assert(a == b, "expected " .. tostring(b) .. ", got " .. tostring(a)) end
local function check(name, fn)
  local ok, err = pcall(fn)
  report[ok and "passed" or "failed"] = report[ok and "passed" or "failed"] + 1
  report.cases[#report.cases + 1] = {name = name, passed = ok, error = not ok and tostring(err) or nil}
  print((ok and "PASS " or "FAIL ") .. name .. (ok and "" or ": " .. tostring(err)))
end
local function fixture(file, queue)
  local services, gpu, state = fake(unicode)
  state.width, state.height = 50, 18
  local count, requested = 0, {}
  services.event.pull = function()
    count = count + 1
    local event = queue and queue[count]
    assert(event and count <= 20, "bundle event queue exhausted")
    return table.unpack(event, 1, event.n)
  end
  local env = setmetatable({require = function(name)
    requested[#requested + 1] = name
    assert(services[name], "unexpected external dependency: " .. tostring(name))
    return services[name]
  end}, {__index = _G})
  local chunk, err = loadfile(root .. "/dist/" .. file, "t", env)
  assert(chunk, err)
  return chunk, state, requested
end
local function mouse(name, x)
  return table.pack(name, "screen-test", x or 3, 5, 0, "p")
end
local function restored(state)
  eq(state.buffer, 3); eq(state.blink, true)
  eq(state.colors[0].fg, 2); eq(state.colors[0].bg, 5)
end

check("B01 single-file library loads lazily", function()
  local chunk, _, requested = fixture("ocgui.lua")
  local gui = chunk(); eq(gui.version, "0.1.0-dev"); eq(#requested, 0)
  local app = gui.application(); assert(app:close()); eq(#requested, 0)
end)
check("B02 bundled mouse activation and run restore state", function()
  local chunk, state = fixture("ocgui.lua", {mouse("touch"), mouse("drop")})
  local gui = chunk(); local app = gui.application(); local count = 0
  local b = app.root:add(gui.button {x = 3, y = 5, width = 16, text = "OK"})
  b:on("click", function() count = count + 1; app:stop() end)
  local ok, err = app:run(); assert(ok, err and err.message); eq(count, 1); restored(state)
end)
check("B03 bundled keyboard activation works", function()
  local events = {}
  for _, code in ipairs({15, 28}) do
    events[#events + 1] = table.pack("key_down", "keyboard-test", 0, code, "p")
    events[#events + 1] = table.pack("key_up", "keyboard-test", 0, code, "p")
  end
  local chunk, state = fixture("ocgui.lua", events)
  local gui = chunk(); local app = gui.application(); local count = 0
  local b = app.root:add(gui.button {width = 10, text = "OK"})
  b:on("click", function() count = count + 1; app:stop() end)
  local ok, err = app:run(); assert(ok, err and err.message); eq(count, 1); restored(state)
end)
check("B04 bundled callback errors preserve cleanup", function()
  local chunk, state = fixture("ocgui.lua", {mouse("touch"), mouse("drop")})
  local gui = chunk(); local app = gui.application()
  local b = app.root:add(gui.button {x = 3, y = 5, width = 16})
  b:on("click", function() error("bundle callback failure", 0) end)
  local ok, err = app:run(); eq(ok, nil); eq(err.code, "callback_failed")
  eq(err.message, "bundle callback failure"); restored(state)
end)
check("B05 bundled basic runs without an external ocgui library", function()
  local chunk, state = fixture("basic.lua", {mouse("touch"), mouse("drop"), mouse("touch", 23), mouse("drop", 23)})
  chunk()
  local updated = false
  for _, call in ipairs(state.calls) do
    if call.name == "set" and call.args[3]:find("已激活 1 次", 1, true) then updated = true end
  end
  eq(updated, true); restored(state)
end)
check("B06 bundled loader preserves global require and package state", function()
  local oldRequire, oldPath, oldLoaded = require, package.path, package.loaded.ocgui
  local chunk = fixture("ocgui.lua"); local gui = chunk(); assert(gui.application():close())
  eq(require, oldRequire); eq(package.path, oldPath); eq(package.loaded.ocgui, oldLoaded)
end)

report.total = report.passed + report.failed
report.ok = report.failed == 0
output.write(directory .. "/report.json", output.json(report) .. "\n")
output.write(directory .. "/summary.txt", string.format("BUNDLE: %d passed, %d failed, %d total\n", report.passed, report.failed, report.total))
print("FILES SAVED TO: " .. directory)
assert(report.ok, "bundle smoke tests failed; return result directory")
return report
