-- Public constructors and the standalone run loop on the real terminal.
local root, mode, options = ...
root, options = root or ".", options or {}
assert(mode == nil or mode == "fail", "invalid mode")
assert(_VERSION == "Lua 5.3", "Lua 5.3 required")
local import = assert(loadfile(root .. "/tests/support/loader.lua"))()(root)
local gui, input = import("ocgui"), import("ocgui.input")
local term = require("term")
local gpu = assert(term.gpu(), "no terminal GPU")
local hold = options.holdSeconds or 120
assert(type(hold) == "number" and hold >= 0, "invalid test deadline")
local card = {title = "STAGE10 / 整体验收", activate = "PRESS KEYS", finish = "FINISH"}
print("TEST SUITE: STAGE10-SCREEN-001 / " .. (mode or "normal"))
print("Use Enter and Space, then Tab and Enter to finish. The display clears on exit.")
local function snapshot()
  local s = {screen = gpu.getScreen(), depth = gpu.getDepth()}
  if gpu.getActiveBuffer then s.buffer = gpu.getActiveBuffer() end
  s.foreground, s.foregroundPalette = gpu.getForeground()
  s.background, s.backgroundPalette = gpu.getBackground()
  s.width, s.height = gpu.getResolution()
  s.viewportWidth, s.viewportHeight = gpu.getViewport()
  s.x, s.y = term.getCursor(); s.blink = term.getCursorBlink()
  return s
end
local report = {suite = "STAGE10-SCREEN-001", mode = mode or "normal", before = snapshot(), checks = {},
  lua = _VERSION, openos = _OSVERSION or "unknown", version = gui.version,
  visual = {status = "not_recorded", note = "Human appearance review is separate."},
  interaction = {clicks = 0, completed = false, enter = false, space = false, events = {}}}
local app = gui.application {theme = {container = {background = 0x101820}, label = {background = 0x101820}}}
app.root:add(gui.label {x = 3, y = 2, width = 44, text = card.title})
local activate = app.root:add(gui.button {x = 3, y = 5, width = 16, height = 3, text = card.activate})
local finish = app.root:add(gui.button {x = 24, y = 5, width = 14, height = 3, text = card.finish})
local status = app.root:add(gui.label {x = 3, y = 10, width = 40, text = "Clicks: 0"})
app.root:add(gui.label {x = 3, y = 12, width = 46, text = "Enter 和空格各一次，再 Tab + Enter 结束"})
app.root:add(gui.label {x = 3, y = 14, width = 46, text = "统一入口与 run 循环；观察按下和焦点外观"})
activate:on("click", function(_, event)
  if mode == "fail" then error("STAGE10_INTENTIONAL_CALLBACK", 0) end
  if event.code == 28 or event.code == 57 then
    local result = report.interaction
    result.enter = result.enter or event.code == 28
    result.space = result.space or event.code == 57
    result.clicks = result.clicks + 1; status:setText("Clicks: " .. result.clicks)
  end
end)
finish:on("click", function(_, event)
  local result = report.interaction
  if result.enter and result.space and (event.code == 28 or event.code == 57) then
    local chars = {}
    for x = 3, 20 do chars[#chars + 1] = gpu.get(x, 10) end
    result.finalStatus = table.concat(chars)
    local expected = "Clicks: " .. result.clicks
    assert(result.finalStatus:sub(1, #expected) == expected, "final count readback mismatch")
    result.completed = true; app:stop()
  end
end)

-- Only the test wraps the backend wait to inspect the first frame and cap time.
-- Rendering, signal dispatch, expiration and closing remain owned by app:run().
local device, first, phase, deadline, normalize = app._device, true, 0
local originalPull = device.pull
device.pull = function(self, timeout)
  if first then
    first = false
    local width, height = self:getSize()
    assert(width >= 50 and height >= 18, "viewport must be at least 50 x 18")
    local cells = {}
    report.screen = {columns = 40, rows = 16, cells = cells,
      cellFormat = {"character", "foregroundRGB", "backgroundRGB", "foregroundPaletteOrFalse", "backgroundPaletteOrFalse"}}
    for y = 1, 16 do
      cells[y] = {}
      for x = 1, 40 do
        local char, fg, bg, fp, bp = gpu.get(x, y)
        cells[y][x] = {char, fg, bg, fp or false, bp or false}
      end
    end
    local function check(name, x, y, value)
      local differences = {}
      for i = 1, self.unicode.len(value) do
        local char = self.unicode.sub(value, i, i)
        if cells[y][x][1] ~= char then
          differences[#differences + 1] = {x = x, y = y, expected = char, actual = cells[y][x][1]}
        end
        x = x + math.max(1, self.unicode.charWidth(char))
      end
      report.checks[#report.checks + 1] = {name = name, passed = #differences == 0, differences = differences}
    end
    check("title", 3, 2, card.title)
    check("activate button", 6, 5, card.activate)
    check("finish button", 28, 5, card.finish)
    report.readback = true
    for _, item in ipairs(report.checks) do if not item.passed then report.readback = false end end
    assert(report.readback, "initial readback mismatch")
    normalize = input.new(self.screen, self:getKeyboards())
    deadline = self:now() + hold
    app:setFocus(activate)
    return nil -- Let the loop repaint the initial focus before waiting.
  end
  local raw
  if mode == "fail" then
    phase = phase + 1
    assert(phase <= 2, "expected callback did not fail")
    local keyboard = assert(self:getKeyboards()[1], "keyboard required")
    raw = table.pack(phase == 1 and "key_down" or "key_up", keyboard, 0, 28)
  else
    local remaining = deadline - self:now()
    assert(remaining > 0, "interactive test timed out")
    raw = table.pack(originalPull(self, timeout and math.min(timeout, remaining) or remaining))
  end
  local event = normalize:normalize(table.unpack(raw, 1, raw.n))
  if event and #report.interaction.events < 80 then
    local saved = {}
    for key, value in pairs(event) do if key ~= "raw" then saved[key] = value end end
    report.interaction.events[#report.interaction.events + 1] = saved
  end
  return table.unpack(raw, 1, raw.n)
end

local called, success, err = pcall(app.run, app)
if not called then err = {message = tostring(success)}; success = nil end
local closed, cleanup = app:close() -- Idempotent backup even on an unexpected throw.
local expected = mode == "fail" and err and err.code == "callback_failed"
  and err.message == "STAGE10_INTENTIONAL_CALLBACK"
report.execution = called and ((mode == nil and success == true and report.interaction.completed) or expected) or false
if expected then report.expectedCallbackError = {code = err.code, message = err.message} end
report.applicationCleanup = closed == true and app._state == "closed"
report.managerCleanup = app.root._interactionOwner == nil and not activate:isPressed() and not finish:isPressed()
report.cleanup = closed == true and not (err and (err.code == "cleanup_failed" or err.cleanupErrors ~= nil))
local afterOK, after = pcall(snapshot)
report.after = afterOK and after or nil
report.restored, report.differences = afterOK, {}
if afterOK then
  for key, value in pairs(report.before) do
    if after[key] ~= value then
      report.restored = false
      report.differences[#report.differences + 1] = key .. ": " .. tostring(value) .. " -> " .. tostring(after[key])
    end
  end
else report.differences[1] = tostring(after) end
report.error = not report.execution and (err and err.message or "interactive test incomplete") or nil
report.cleanupErrors = cleanup and cleanup.cleanupErrors or err and err.cleanupErrors or nil
report.passed = report.readback == true and report.execution and report.cleanup and report.restored
  and report.applicationCleanup and report.managerCleanup
if options.saveReport then options.saveReport(report) end
print("READBACK: " .. (report.readback and "PASS" or "FAIL"))
print("EXECUTION: " .. (report.execution and "PASS" or "FAIL"))
print("CLEANUP: " .. (report.cleanup and report.managerCleanup and "PASS" or "FAIL"))
print("STATE RESTORE: " .. (report.restored and "PASS" or "FAIL"))
if report.error then print("ERROR: " .. report.error) end
assert(report.passed, "STAGE10 SCREEN FAILED: return result directory")
return report
