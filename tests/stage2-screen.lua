-- Real GPU test. Run: lua tests/stage2-screen.lua . [fail]
local root, mode, options = ...
root = root or "."
options = options or {}
assert(type(options) == "table", "internal options must be a table")
local holdSeconds = options.holdSeconds or 30
assert(type(holdSeconds) == "number" and holdSeconds >= 0, "invalid hold time")
assert(mode == nil or mode == "fail", "mode must be omitted or fail")
assert(_VERSION == "Lua 5.3", "BLOCKED: Lua 5.3 required")
local import = assert(loadfile(root .. "/tests/support/loader.lua"))()(root)
local platform, renderer = import("ocgui.platform.openos"), import("ocgui.renderer")
local term = require("term")
local gpu = assert(term.gpu(), "BLOCKED: no terminal GPU")
print("TEST SUITE: STAGE2-SCREEN-002 / " .. (mode or "normal"))
print("Card hold time: " .. holdSeconds .. " seconds; automatic GPU readback enabled.")
print("The test clears the display on exit; terminal text is not preserved.")

local function snapshot()
  local s = {}
  s.screen = gpu.getScreen()
  if gpu.getActiveBuffer then s.buffer = gpu.getActiveBuffer() end
  s.foreground, s.foregroundPalette = gpu.getForeground()
  s.background, s.backgroundPalette = gpu.getBackground()
  s.width, s.height = gpu.getResolution()
  s.viewportWidth, s.viewportHeight = gpu.getViewport()
  s.depth = gpu.getDepth()
  s.x, s.y = term.getCursor()
  s.blink = term.getCursorBlink()
  return s
end
local before = snapshot()
local device = platform.new()
local readback = false
local report = {suite = "STAGE2-SCREEN-002", mode = mode or "normal", before = before,
  lua = _VERSION, openos = _OSVERSION or "unknown", checks = {}}
local ok, reason = pcall(function()
  local opened, err = device:open()
  if not opened then error(err, 0) end
  local width, height = device:getSize()
  assert(width >= 40 and height >= 14, "BLOCKED: viewport must be at least 40 x 14")
  renderer.new(device, device.unicode):frame(function(c)
    c:fillRect(1, 1, width, height, 0x101820)
    c:drawText(3, 2, "STAGE2 / 渲染测试", 0xFFFFFF, 0x101820)
    c:drawText(3, 4, "ASCII: abc 123", 0xFFFFFF, 0x101820)
    c:drawText(3, 6, "中文：中文测试", 0xFFD060, 0x101820)
    c:fillRect(3, 8, 8, 2, 0x204060)
    for y = 8, 9 do
      c:drawText(3, y, "[", 0xFFFFFF, 0x204060)
      c:drawText(6, y, "]", 0xFFFFFF, 0x204060)
    end
    c:pushClip(4, 8, 2, 1)
    c:drawText(4, 8, "A中B", 0xFFFFFF, 0x204060)
    c:popClip()
    c:pushClip(4, 9, 2, 1)
    c:drawText(2, 9, "A中B", 0xFFFFFF, 0x204060)
    c:popClip()
    c:drawText(13, 8, "right cut: [A ]", 0xFFFFFF, 0x101820)
    c:drawText(13, 9, "left cut:  [ B]", 0xFFFFFF, 0x101820)
    c:fillRect(-5, 11, 8, 1, 0x60A060)
    c:drawText(4, 11, "Only cells 1-2 are green", 0xFFFFFF, 0x101820)
    c:drawText(3, height - 1, "Automatic screen readback", 0xFFFFFF, 0x101820)
  end)
  local columns, rows = math.min(width, 40), math.min(height, 12)
  local cells = {}
  report.screen = {columns = columns, rows = rows,
    cellFormat = {"character", "foregroundRGB", "backgroundRGB", "foregroundPaletteOrFalse", "backgroundPaletteOrFalse"},
    cells = cells}
  for y = 1, rows do
    cells[y] = {}
    for x = 1, columns do
      local char, fg, bg, fp, bp = gpu.get(x, y)
      assert(type(char) == "string", "GPU readback failed")
      cells[y][x] = {char, fg, bg, fp or false, bp or false}
    end
  end
  local function checkLine(name, x, y, value)
    local matched, details = true, {}
    for index = 1, device.unicode.len(value) do
      local expectedChar = device.unicode.sub(value, index, index)
      local actual = cells[y][x][1]
      if actual ~= expectedChar then
        matched = false
        details[#details + 1] = {x = x, y = y, expected = expectedChar, actual = actual}
      end
      x = x + math.max(1, device.unicode.charWidth(expectedChar))
    end
    report.checks[#report.checks + 1] = {name = name, passed = matched, differences = details}
  end
  checkLine("title", 3, 2, "STAGE2 / 渲染测试")
  checkLine("ASCII", 3, 4, "ASCII: abc 123")
  checkLine("Chinese", 3, 6, "中文：中文测试")
  checkLine("right clip", 3, 8, "[A ]")
  checkLine("left clip", 3, 9, "[ B]")
  local base = cells[1][1][3]
  local boundaryOK = cells[11][1][3] == cells[11][2][3] and cells[11][3][3] == base
  local distinct = cells[11][1][3] ~= base
  report.checks[#report.checks + 1] = {name = "fill boundary", passed = boundaryOK}
  report.checks[#report.checks + 1] = {name = "fill color differs", passed = distinct or before.depth == 1,
    skipped = before.depth == 1, note = "monochrome depth cannot guarantee distinct colors"}
  readback = true
  for _, check in ipairs(report.checks) do if not check.passed then readback = false end end
  assert(readback, "automatic screen readback mismatch; inspect saved cells and checks")
  local keyboards = {}
  for _, address in ipairs(device:getKeyboards()) do keyboards[address] = true end
  local deadline = device:now() + holdSeconds
  while device:now() < deadline do
    local name, address = device:pull(math.max(0, deadline - device:now()))
    if (name == "key_down" and keyboards[address])
        or (name == "touch" and address == device.screen) or name == "interrupted" then break end
  end
  if mode == "fail" then error("STAGE2_INTENTIONAL_FAILURE", 0) end
end)
-- Cleanup before printing or propagating a test failure.
local closed, cleanup = device:close()
local afterOK, after = pcall(snapshot)
local restored, differences = afterOK, {}
if afterOK then
  for key, value in pairs(before) do
    if after[key] ~= value then
      restored = false
      differences[#differences + 1] = key .. ": " .. tostring(value) .. " -> " .. tostring(after[key])
    end
  end
else
  differences[1] = "snapshot failed: " .. tostring(after)
end
local expected = mode == "fail" and not ok and reason == "STAGE2_INTENTIONAL_FAILURE"
local executionOK = (mode == nil and ok) or expected
report.readback, report.execution, report.cleanup, report.restored = readback, executionOK, closed == true, restored
report.after = afterOK and after or nil
report.differences, report.cleanupErrors = differences, cleanup and cleanup.cleanupErrors or nil
report.error = not executionOK and (type(reason) == "table" and reason.message or tostring(reason)) or nil
report.passed = readback and executionOK and closed == true and restored
if options.saveReport then options.saveReport(report) end
print("READBACK: " .. (readback and "PASS" or "FAIL"))
print("EXECUTION: " .. (executionOK and "PASS" or "FAIL"))
print("CLEANUP: " .. (closed and "PASS" or "FAIL"))
print("STATE RESTORE: " .. (restored and "PASS" or "FAIL"))
for _, difference in ipairs(differences) do print("DIFFERENCE: " .. difference) end
if not executionOK then
  print("ERROR: " .. tostring(type(reason) == "table" and reason.message or reason))
end
if cleanup then
  for _, detail in ipairs(cleanup.cleanupErrors or {}) do print("CLEANUP ERROR: " .. detail) end
end
assert(readback and executionOK and closed and restored, "STAGE2 SCREEN FAILED: return complete output")
print("STAGE2 SCREEN PASS / " .. (mode or "normal"))
print("Screen characters, colors and state changes are available in the automatic report.")
return report
