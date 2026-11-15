-- Real GPU test. Run: lua tests/stage8-screen.lua . [fail]
local root, mode, options = ...
root = root or "."
options = options or {}
assert(type(options) == "table", "internal options must be a table")
local holdSeconds = options.holdSeconds or 120
assert(type(holdSeconds) == "number" and holdSeconds >= 0, "invalid hold time")
assert(mode == nil or mode == "fail", "mode must be omitted or fail")
assert(_VERSION == "Lua 5.3", "BLOCKED: Lua 5.3 required")
local import = assert(loadfile(root .. "/tests/support/loader.lua"))()(root)
local platform, renderer = import("ocgui.platform.openos"), import("ocgui.renderer")
local container, label = import("ocgui.container"), import("ocgui.label")
local painter = import("ocgui.painter")
local button, input = import("ocgui.button"), import("ocgui.input")
local interaction, dispatcher = import("ocgui.interaction"), import("ocgui.dispatcher")
local term = require("term")
local gpu = assert(term.gpu(), "BLOCKED: no terminal GPU")
local card = {title = "STAGE8 / 键盘按钮", activate = "PRESS KEYS", finish = "FINISH"}
print("TEST SUITE: STAGE8-SCREEN-002 / " .. (mode or "normal"))
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
local readback, manager = false, nil
local report = {suite = "STAGE8-SCREEN-002", mode = mode or "normal", before = before,
  lua = _VERSION, openos = _OSVERSION or "unknown", checks = {},
  visual = {status = "not_recorded", note = "Human appearance review is separate from automatic readback."}}
local ok, reason = pcall(function()
  local opened, err = device:open()
  if not opened then error(err, 0) end
  local width, height = device:getSize()
  assert(width >= 50 and height >= 18, "BLOCKED: viewport must be at least 50 x 18")
  local tree = container.new {width = width, height = height, style = {background = 0x101820}}
  tree:add(label.new {x = 3, y = 2, width = 44, text = card.title})
  local activate = tree:add(button.new {x = 3, y = 5, width = 16, height = 3, text = card.activate})
  local finish = tree:add(button.new {x = 24, y = 5, width = 14, height = 3, text = card.finish})
  local status = tree:add(label.new {x = 3, y = 10, width = 40, text = "Clicks: 0"})
  tree:add(label.new {x = 3, y = 12, width = 46, text = "Enter 和空格各一次，再 Tab + Enter 结束"})
  tree:add(label.new {x = 3, y = 14, width = 46, text = "按住按键不应连续触发；观察按下和焦点颜色"})
  local clicks, done, enterSeen, spaceSeen = 0, false, false, false
  activate:on("click", function(_, event)
    if event.code == 28 or event.code == 57 then
      enterSeen = enterSeen or event.code == 28
      spaceSeen = spaceSeen or event.code == 57
      clicks = clicks + 1; status:setText("Clicks: " .. clicks)
    end
  end)
  finish:on("click", function(_, event)
    if enterSeen and spaceSeen and (event.code == 28 or event.code == 57) then done = true end
  end)
  manager = interaction.new(tree, dispatcher.new(tree), function() return device:now() end)
  manager:setFocus(activate)
  local normalize = input.new(device.screen, device:getKeyboards())
  local draw = painter.new(tree, renderer.new(device, device.unicode), {label = {background = 0x101820}})
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
  checkLine("title", 3, 2, card.title)
  checkLine("activate button", 6, 5, card.activate)
  checkLine("finish button", 28, 5, card.finish)
  readback = true
  for _, check in ipairs(report.checks) do if not check.passed then readback = false end end
  assert(readback, "automatic screen readback mismatch; inspect saved cells and checks")
  if mode == "fail" then error("STAGE8_INTENTIONAL_FAILURE", 0) end
  report.interaction = {clicks = 0, completed = false, events = {}}
  local deadline = device:now() + holdSeconds
  while not done and device:now() < deadline do
    local raw = table.pack(device:pull(manager:nextTimeout(math.max(0, deadline - device:now()))))
    local event = normalize:normalize(table.unpack(raw, 1, raw.n))
    if event and (event.type == "interrupted" or event.type == "screen_resized") then
      error("interactive test interrupted or resized", 0)
    end
    if event and #report.interaction.events < 80 then
      local saved = {}
      for key, value in pairs(event) do if key ~= "raw" then saved[key] = value end end
      report.interaction.events[#report.interaction.events + 1] = saved
    end
    manager:route(event)
    draw:render()
  end
  report.interaction.clicks, report.interaction.completed = clicks, done
  report.interaction.enter, report.interaction.space = enterSeen, spaceSeen
  assert(done and enterSeen and spaceSeen, "keyboard test timed out; use Enter and Space, then Tab and Enter")
  assert(manager:getCapture() == nil and not activate:isPressed() and not finish:isPressed(), "stale button state")
  local finalStatus = {}
  for x = 3, 20 do finalStatus[#finalStatus + 1] = gpu.get(x, 10) end
  report.interaction.finalStatus = table.concat(finalStatus)
  local expectedText = "Clicks: " .. clicks
  assert(report.interaction.finalStatus:sub(1, #expectedText) == expectedText, "final click-count readback mismatch")

end)
-- Cleanup before printing or propagating a test failure.
local managerOK, managerError = pcall(function() if manager then manager:close() end end)
local closed, cleanup = device:close()
report.managerCleanup = managerOK
report.managerError = not managerOK and tostring(managerError) or nil
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
local expected = mode == "fail" and not ok and reason == "STAGE8_INTENTIONAL_FAILURE"
local executionOK = (mode == nil and ok) or expected
report.readback, report.execution, report.cleanup, report.restored = readback, executionOK, closed == true, restored
report.after = afterOK and after or nil
report.differences, report.cleanupErrors = differences, cleanup and cleanup.cleanupErrors or nil
report.error = not executionOK and (type(reason) == "table" and reason.message or tostring(reason)) or nil
report.passed = readback and executionOK and closed == true and restored and managerOK
if options.saveReport then options.saveReport(report) end
print("READBACK: " .. (readback and "PASS" or "FAIL"))
print("EXECUTION: " .. (executionOK and "PASS" or "FAIL"))
print("CLEANUP: " .. (closed and managerOK and "PASS" or "FAIL"))
print("STATE RESTORE: " .. (restored and "PASS" or "FAIL"))
for _, difference in ipairs(differences) do print("DIFFERENCE: " .. difference) end
if not executionOK then
  print("ERROR: " .. tostring(type(reason) == "table" and reason.message or reason))
end
if cleanup then
  for _, detail in ipairs(cleanup.cleanupErrors or {}) do print("CLEANUP ERROR: " .. detail) end
end
assert(report.passed, "STAGE8 SCREEN FAILED: return complete output")
print("STAGE8 SCREEN PASS / " .. (mode or "normal"))
print("Screen characters, colors and state changes are available in the automatic report.")
return report
