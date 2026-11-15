-- Mock device tests only. Run: lua tests/stage2.lua .
local root = (...) or "."
print("TEST SUITE: STAGE2-RENDER-002")
print("LUA: " .. tostring(_VERSION))
assert(_VERSION == "Lua 5.3", "BLOCKED: Lua 5.3 required")
local import = assert(loadfile(root .. "/tests/support/loader.lua"))()(root)
local fake = assert(loadfile(root .. "/tests/support/fake_openos.lua"))()
local unicode = require("unicode")
local renderer = import("ocgui.renderer")
local platform = import("ocgui.platform.openos")
local passed, failed = 0, 0
local function eq(a, b)
  if a ~= b then error("expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end
local function rejects(callback)
  local ok = pcall(callback); eq(ok, false)
end
local function test(name, callback)
  local ok, reason = pcall(callback)
  if ok then passed = passed + 1; print("PASS " .. name)
  else
    failed = failed + 1
    print("FAIL " .. name .. ": " .. tostring(type(reason) == "table" and reason.message or reason))
  end
end
local function recording()
  local calls, device = {}, {}
  function device:getSize() return 20, 10 end
  for _, name in ipairs({"fill", "set", "setForeground", "setBackground"}) do
    local methodName = name
    device[name] = function(_, ...)
      calls[#calls + 1] = {name = methodName, args = table.pack(...)}
      return true
    end
  end
  return renderer.new(device, unicode), calls
end
local function count(calls, name)
  local total = 0
  for _, call in ipairs(calls) do if call.name == name then total = total + 1 end end
  return total
end
local function last(calls, name)
  for index = #calls, 1, -1 do if calls[index].name == name then return calls[index].args end end
  error("missing call: " .. name)
end

test("R01 empty frame performs no drawing", function()
  local r, calls = recording(); r:frame(function() end); eq(#calls, 0)
end)
test("R02 fill is clipped", function()
  local r, calls = recording()
  r:frame(function(c) c:pushClip(3, 2, 4, 3); c:fillRect(-1, 1, 8, 6, 0); c:popClip() end)
  local a = last(calls, "fill")
  eq(a[1], 3); eq(a[2], 2); eq(a[3], 4); eq(a[4], 3); eq(a[5], " ")
end)
test("R03 nested empty clip remains empty", function()
  local r, calls = recording()
  r:frame(function(c)
    c:pushClip(30, 30, 1, 1); c:pushClip(1, 1, 20, 10)
    c:fillRect(1, 1, 20, 10, 0); c:popClip(); c:popClip()
  end)
  eq(#calls, 0)
end)
test("R04 wide text right clipping", function()
  local r, calls = recording()
  r:frame(function(c) c:pushClip(1, 1, 2, 1); c:drawText(1, 1, "A中B", 1, 0); c:popClip() end)
  eq(last(calls, "set")[3], "A ")
end)
test("R05 wide text left clipping", function()
  local r, calls = recording()
  r:frame(function(c) c:pushClip(3, 1, 2, 1); c:drawText(1, 1, "A中B", 1, 0); c:popClip() end)
  local a = last(calls, "set"); eq(a[1], 3); eq(a[3], " B")
end)
test("R06 offscreen drawing has no device calls", function()
  local r, calls = recording()
  r:frame(function(c) c:drawText(30, 1, "text", 1, 0); c:fillRect(1, 11, 3, 2, 0) end)
  eq(#calls, 0)
end)
test("R07 colors cached within frame", function()
  local r, calls = recording()
  r:frame(function(c) c:drawText(1, 1, "a", 1, 0); c:drawText(2, 1, "b", 1, 0) end)
  eq(count(calls, "setForeground"), 1); eq(count(calls, "setBackground"), 1)
end)
test("R08 color cache resets between frames", function()
  local r, calls = recording()
  for _ = 1, 2 do r:frame(function(c) c:drawText(1, 1, "a", 1, 0) end) end
  eq(count(calls, "setForeground"), 2); eq(count(calls, "setBackground"), 2)
end)
test("R09 context expires after frame", function()
  local r = recording(); local saved
  r:frame(function(c) saved = c end)
  rejects(function() saved:fillRect(1, 1, 1, 1, 0) end)
end)
test("R10 error expires context and permits next frame", function()
  local r = recording(); local saved
  rejects(function() r:frame(function(c) saved = c; error("intentional") end) end)
  rejects(function() saved:popClip() end)
  eq(r:frame(function() end), true)
end)
test("R11 stack and reentry guards", function()
  local r = recording()
  rejects(function() r:frame(function(c) c:popClip() end) end)
  rejects(function() r:frame(function(c) c:pushClip(1, 1, 1, 1) end) end)
  rejects(function() r:frame(function() r:frame(function() end) end) end)
  eq(r:frame(function() end), true)
end)
test("R12 alignment and invalid color", function()
  local r, calls = recording()
  r:frame(function(c) c:drawText(1, 1, "a", 1, 0, 4, "right") end)
  eq(last(calls, "set")[3], "   a")
  rejects(function() r:frame(function(c) c:fillRect(1, 1, 1, 1, -1) end) end)
end)

local function withDevice(callback)
  local services, gpu, state = fake(unicode)
  local device = platform.new({}, services)
  local ok, reason = pcall(callback, device, services, gpu, state)
  local closed, cleanup = device:close()
  if not ok then error(reason, 0) end
  assert(closed, cleanup and cleanup.message)
end
test("B01 construct does not access device", function()
  withDevice(function(_, _, _, s) eq(#s.calls, 0) end)
end)
test("B02 open selects screen and disables cursor", function()
  withDevice(function(b, _, _, s)
    assert(b:open()); eq(s.buffer, 0); eq(s.blink, false)
    eq(count(s.calls, "fill"), 0)
  end)
end)
test("B03 close restores palette flags buffer and cursor", function()
  withDevice(function(b, _, _, s)
    assert(b:open()); b:setForeground(0xFFFFFF); b:setBackground(0)
    assert(b:close()); eq(s.buffer, 3); eq(s.blink, true); eq(s.x, 2); eq(s.y, 3)
    eq(s.colors[0].fg, 2); eq(s.colors[0].fp, true)
    eq(s.colors[0].bg, 5); eq(s.colors[0].bp, true)
    eq(s.colors[3].fg, 0xABCDEF)
  end)
end)
test("B04 duplicate owner rejected without disturbing first", function()
  withDevice(function(b, services, _, s)
    assert(b:open())
    local other = platform.new({}, services)
    local ok, err = other:open(); eq(ok, nil); eq(err.code, "device_busy")
    eq(s.buffer, 0); eq(s.blink, false); assert(other:close())
  end)
end)
test("B05 startup failure rolls back", function()
  withDevice(function(b, _, _, s)
    s.fail.getBackground = "once"
    local ok = b:open(); eq(ok, nil); eq(s.buffer, 3); eq(s.blink, true)
    eq(count(s.calls, "fill"), 0)
  end)
end)
test("B06 cleanup failure still restores other state", function()
  withDevice(function(b, _, _, s)
    assert(b:open()); s.fail.setForeground = "once"
    local ok, err = b:close(); eq(ok, nil); eq(err.code, "cleanup_failed")
    assert(#err.cleanupErrors > 0); eq(s.buffer, 3); eq(s.blink, true)
    eq(s.colors[0].bg, 5); eq(s.colors[0].bp, true)
  end)
end)
test("B07 close idempotence and reopen rejection", function()
  withDevice(function(b)
    assert(b:open()); assert(b:close()); assert(b:close())
    local ok, err = b:open(); eq(ok, nil); eq(err.code, "invalid_state")
  end)
end)
test("B08 buffer and viewport fallback", function()
  withDevice(function(b, _, gpu, s)
    gpu.getActiveBuffer, gpu.setActiveBuffer, gpu.getViewport = nil, nil, nil
    s.buffer = 0; assert(b:open()); local w, h = b:getSize(); eq(w, 20); eq(h, 10)
  end)
end)
test("B09 binding change does not clear foreign screen", function()
  withDevice(function(b, _, _, s)
    assert(b:open()); s.screen = "foreign-screen"
    rejects(function() b:getSize() end)
    local ok, err = b:close(); eq(ok, nil); eq(err.code, "cleanup_failed")
    eq(count(s.calls, "fill"), 0); eq(s.buffer, 3); eq(s.blink, true)
  end)
end)
test("B10 silent GPU refusal propagates", function()
  withDevice(function(b, _, _, s)
    assert(b:open()); s.fail.set = "nil"
    local ok, err = pcall(function() b:set(1, 1, "x") end)
    eq(ok, false); eq(err.code, "device_error")
  end)
end)
test("B11 event tuple clock and keyboards", function()
  withDevice(function(b, _, _, s)
    assert(b:open()); local a, empty, c = b:pull(0.25)
    eq(a, "test_signal"); eq(empty, nil); eq(c, 7); eq(s.timeout, 0.25)
    eq(b:now(), 123.5); eq(b:getKeyboards()[1], "keyboard-test")
  end)
end)
test("B12 missing GPU fails before drawing", function()
  withDevice(function(b, services, _, s)
    services.term.gpu = function() return nil end
    local ok = b:open(); eq(ok, nil); eq(count(s.calls, "fill"), 0)
  end)
end)
test("B13 resized viewport updates clear area and clamps cursor", function()
  withDevice(function(b, _, _, s)
    s.x, s.y = 18, 9
    assert(b:open()); s.width, s.height = 12, 6
    local w, h = b:getSize(); eq(w, 12); eq(h, 6)
    assert(b:close()); eq(s.x, 12); eq(s.y, 6)
    local a = last(s.calls, "fill"); eq(a[3], 12); eq(a[4], 6)
  end)
end)

test("B14 callable GPU proxy methods preserve full device lifecycle", function()
  withDevice(function(b, _, gpu, s)
    for name, member in pairs(gpu) do
      if type(member) == "function" then
        local callback = member
        gpu[name] = setmetatable({}, {__call = function(_, ...) return callback(...) end})
      end
    end
    -- A callable viewport must be selected without falling back to resolution.
    gpu.getResolution = nil
    eq(type(gpu.getScreen), "table")
    assert(b:open()); eq(s.buffer, 0); eq(s.blink, false)
    local w, h = b:getSize(); eq(w, 20); eq(h, 10)
    b:setForeground(0xFFFFFF); b:setBackground(0)
    assert(b:fill(1, 1, 1, 1, " ")); assert(b:set(1, 1, "x"))
    eq(b:getKeyboards()[1], "keyboard-test")
    assert(b:close()); eq(s.buffer, 3); eq(s.blink, true)
    eq(s.colors[0].fg, 2); eq(s.colors[0].fp, true)
    eq(s.colors[0].bg, 5); eq(s.colors[0].bp, true)
  end)
end)

test("B15 non-callable GPU method is rejected before drawing", function()
  withDevice(function(b, _, gpu, s)
    gpu.getScreen = {}
    local ok, err = b:open(); eq(ok, nil); eq(err.code, "device_unavailable")
    eq(s.buffer, 3); eq(s.blink, true); eq(count(s.calls, "fill"), 0)
  end)
end)

test("B16 incomplete callable buffer API fails without changing state", function()
  withDevice(function(b, _, gpu, s)
    local getBuffer = gpu.getActiveBuffer
    gpu.getActiveBuffer = setmetatable({}, {__call = function() return getBuffer() end})
    gpu.setActiveBuffer = nil
    local ok, err = b:open(); eq(ok, nil); eq(err.code, "device_unavailable")
    eq(err.message, "incomplete active buffer API")
    eq(s.buffer, 3); eq(s.blink, true); eq(count(s.calls, "fill"), 0)
  end)
end)

print(string.format("SUMMARY: %d passed, %d failed, %d total", passed, failed, passed + failed))
if failed > 0 then error("STAGE2 MOCK FAILED: return complete output", 0) end
print("STAGE2 MOCK PASS: real screen test is still required")
