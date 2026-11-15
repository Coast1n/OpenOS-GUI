-- Real GPU test. Run: lua tests/stage6-screen.lua . [fail]
local root, mode, options = ...
root = root or "."
options = options or {}
assert(type(options) == "table", "internal options must be a table")
local holdSeconds = options.holdSeconds or 60
assert(type(holdSeconds) == "number" and holdSeconds >= 0, "invalid hold time")
assert(mode == nil or mode == "fail", "mode must be omitted or fail")
assert(_VERSION == "Lua 5.3", "BLOCKED: Lua 5.3 required")
local import = assert(loadfile(root .. "/tests/support/loader.lua"))()(root)
local platform, renderer = import("ocgui.platform.openos"), import("ocgui.renderer")
local container, label = import("ocgui.container"), import("ocgui.label")
local painter = import("ocgui.painter")
local term = require("term")
local gpu = assert(term.gpu(), "BLOCKED: no terminal GPU")
print("TEST SUITE: STAGE6-SCREEN-001 / " .. (mode or "normal"))
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
local report = {suite = "STAGE6-SCREEN-001", mode = mode or "normal", before = before,
  lua = _VERSION, openos = _OSVERSION or "unknown", checks = {},
  visual = {status = "not_recorded", note = "Human appearance review is separate from automatic readback."}}
local ok, reason = pcall(function()
  local opened, err = device:open()
  if not opened then error(err, 0) end
  local width, height = device:getSize()
  assert(width >= 50 and height >= 18, "BLOCKED: viewport must be at least 50 x 18")
  local tree = container.new {width = width, height = height, style = {background = 0x101820}}
  tree:add(label.new {x = 3, y = 2, width = 44, text = "STAGE6 / 标签与控件树", style = {foreground = 0xFFFFFF}})
  tree:add(label.new {x = 3, y = 4, width = 24, text = "ASCII: abc 123"})
  tree:add(label.new {x = 3, y = 6, width = 24, text = "中文：中文测试", style = {foreground = 0xFFD060}})
  local left = tree:add(container.new {x = 3, y = 8, width = 4, height = 1, style = {background = 0x204060}})
  left:add(label.new {x = 0, width = 4, text = "中AB", style = {background = 0x204060}})
  local right = tree:add(container.new {x = 13, y = 8, width = 2, height = 1, style = {background = 0x204060}})
  right:add(label.new {width = 4, text = "A中B", style = {background = 0x204060}})
  tree:add(label.new {x = 3, y = 10, width = 20, text = "Disabled label", enabled = false})
  tree:add(label.new {x = 3, y = 12, width = 8, text = "AAAAAAAA"})
  tree:add(label.new {x = 5, y = 12, width = 3, text = "BBB", style = {background = 0x305030}})
  local moved = tree:add(label.new {x = 3, y = 14, width = 3, text = "OLD"})
  tree:add(label.new {x = 3, y = 16, width = 46, text = "观察中文/裁剪/遮挡；按键结束（60s）"})
  local draw = painter.new(tree, renderer.new(device, device.unicode), {label = {background = 0x101820}})
  draw:render()
  moved:setBounds(10, 14, 3, 1); moved:setText("NEW")
  draw:render()
  local columns, rows = math.min(width, 40), math.min(height, 16)
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
  checkLine("title", 3, 2, "STAGE6 / 标签与控件树")
  checkLine("ASCII", 3, 4, "ASCII: abc 123")
  checkLine("Chinese", 3, 6, "中文：中文测试")
  checkLine("left wide clip", 3, 8, " AB ")
  checkLine("right wide clip", 13, 8, "A ")
  checkLine("disabled text", 3, 10, "Disabled label")
  checkLine("overlap order", 3, 12, "AABBBAAA")
  checkLine("old position cleared", 3, 14, "   ")
  checkLine("new position", 10, 14, "NEW")
  report.checks[#report.checks + 1] = {name = "background matches outside clip",
    passed = cells[8][2][3] == cells[1][1][3] and cells[8][7][3] == cells[1][1][3]}
  local colorDistinct = cells[12][5][3] ~= cells[12][3][3]
  report.checks[#report.checks + 1] = {name = "overlay background differs",
    passed = colorDistinct or before.depth == 1, skipped = before.depth == 1,
    note = "monochrome cannot guarantee distinct colors"}
  local disabledDistinct = cells[10][3][2] ~= cells[4][3][2]
  report.checks[#report.checks + 1] = {name = "disabled foreground differs",
    passed = disabledDistinct or before.depth == 1, skipped = before.depth == 1,
    note = "monochrome cannot guarantee distinct colors"}
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
  if mode == "fail" then error("STAGE6_INTENTIONAL_FAILURE", 0) end
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
local expected = mode == "fail" and not ok and reason == "STAGE6_INTENTIONAL_FAILURE"
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
assert(readback and executionOK and closed and restored, "STAGE6 SCREEN FAILED: return complete output")
print("STAGE6 SCREEN PASS / " .. (mode or "normal"))
print("Screen characters, colors and state changes are available in the automatic report.")
return report
