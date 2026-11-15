-- Memory-screen checks, using OpenOS unicode but no real GPU or input.
local root = (...) or "."
assert(_VERSION == "Lua 5.3", "BLOCKED: Lua 5.3 required")
local import = assert(loadfile(root .. "/tests/support/loader.lua"))()(root)
local widget, container, label = import("ocgui.widget"), import("ocgui.container"), import("ocgui.label")
local theme, painter, renderer = import("ocgui.theme"), import("ocgui.painter"), import("ocgui.renderer")
local dispatcher, interaction = import("ocgui.dispatcher"), import("ocgui.interaction")
local unicode = require("unicode")
local report = {suite = "STAGE6-PAINT-001", lua = _VERSION, passed = 0, failed = 0, cases = {}}
local function eq(a, b) assert(a == b, "expected " .. tostring(b) .. ", got " .. tostring(a)) end
local function rejects(fn) local ok = pcall(fn); eq(ok, false) end
local function test(name, fn)
  local ok, err = pcall(fn)
  report[ok and "passed" or "failed"] = report[ok and "passed" or "failed"] + 1
  report.cases[#report.cases + 1] = {name = name, passed = ok, error = not ok and tostring(err) or nil}
  print((ok and "PASS " or "FAIL ") .. name .. (ok and "" or ": " .. tostring(err)))
end

local function screen(options)
  local r = container.new {width = 20, height = 8}
  local b = {cells = {}, calls = {}, fg = 0, bg = 0}
  local function call(name)
    b.calls[#b.calls + 1] = name
    if b.hook then b.hook(name) end
    if b.fail == name then error(b.sentinel or "injected device failure", 0) end
  end
  function b:getSize() call("size"); return 20, 8 end
  function b:setForeground(value) call("foreground"); self.fg = value end
  function b:setBackground(value) call("background"); self.bg = value end
  local function put(x, y, char)
    assert(x >= 1 and x <= 20 and y >= 1 and y <= 8, "out-of-screen write")
    b.cells[y * 100 + x] = {char = char, fg = b.fg, bg = b.bg}
  end
  function b:fill(x, y, width, height, char)
    call("fill")
    for yy = y, y + height - 1 do for xx = x, x + width - 1 do put(xx, yy, char) end end
  end
  function b:set(x, y, value)
    call("set")
    for i = 1, unicode.len(value) do
      local char = unicode.sub(value, i, i)
      local width = math.max(1, unicode.charWidth(char))
      put(x, y, char)
      for offset = 1, width - 1 do put(x + offset, y, "") end
      x = x + width
    end
  end
  function b:pixel(x, y) return assert(self.cells[y * 100 + x], "missing pixel") end
  local p = painter.new(r, renderer.new(b, unicode), options)
  return r, p, b
end

test("T01 defaults provide independent RGB styles", function()
  local s = theme.new():resolve("label")
  eq(s.foreground, 0xFFFFFF); eq(s.background, 0); eq(s.alignment, "left")
end)
test("T02 constructor validates theme kinds and RGB values", function()
  for _, value in ipairs({false, {bad = {}}, {label = {foreground = -1}},
      {label = {background = 0x1000000}}, {label = {foreground = 1.5}}}) do
    rejects(function() theme.new(value) end)
  end
end)
test("T03 theme construction copies nested data", function()
  local options = {label = {foreground = 3, disabled = {foreground = 4}}}
  local t = theme.new(options)
  options.label.foreground = 8; options.label.disabled.foreground = 9
  eq(t:resolve("label").foreground, 3); eq(t:resolve("label", nil, "disabled").foreground, 4)
end)
test("T04 kind styles override shared widget styles field by field", function()
  local t = theme.new {widget = {foreground = 1, background = 2}, label = {foreground = 3}}
  local s = t:resolve("label"); eq(s.foreground, 3); eq(s.background, 2)
end)
test("T05 local style overrides theme including zero RGB", function()
  local s = theme.new {label = {foreground = 4}}:resolve("label", {foreground = 0, alignment = "right"})
  eq(s.foreground, 0); eq(s.alignment, "right")
end)
test("T06 state overrides apply within each successive layer", function()
  local t = theme.new {widget = {disabled = {foreground = 2}}, label = {foreground = 3}}
  eq(t:resolve("label", {}, "disabled").foreground, 3)
  eq(t:resolve("label", {disabled = {foreground = 4}}, "disabled").foreground, 4)
  eq(t:resolve("label", {focused = {background = 5}}, "focused").background, 5)
  eq(t:resolve("button", {pressed = {background = 6}}, "pressed").background, 6)
end)
test("T07 resolved styles cannot mutate defaults or their source", function()
  local t = theme.new(); local s = t:resolve("widget"); s.background = 7
  eq(t:resolve("widget").background, 0); eq(theme.new():resolve("widget").background, 0)
end)
test("T08 unknown fields alignment states and nested states are rejected", function()
  local t = theme.new()
  rejects(function() t:resolve("other") end)
  rejects(function() t:resolve("label", {}, "other") end)
  rejects(function() t:resolve("label", false) end)
  rejects(function() t:resolve("label", {alignment = "middle"}) end)
  rejects(function() t:resolve("label", {unknown = true}) end)
  rejects(function() theme.new {label = {disabled = {pressed = {}}}} end)
end)

test("L01 label is a non-pointer widget with empty text by default", function()
  local a = label.new(); eq(widget.is(a), true); eq(a:getText(), ""); eq(a:isFocusable(), false)
  eq(a:hitTest(1, 1), nil); eq(a._kind, "label")
end)
test("L02 label constructor delegates bounds validation and rejects nontext", function()
  for _, value in ipairs({false, {text = false}, {text = 2}, {width = 0}}) do
    rejects(function() label.new(value) end)
  end
end)
test("L03 same-text setter is chainable and does not invalidate", function()
  local a = label.new {text = "中"}; a._dirty = false
  eq(a:setText("中"), a); eq(a._dirty, false)
end)
test("L04 invalid text setter is atomic", function()
  local a = label.new {text = "old"}
  rejects(function() a:setText(nil) end); eq(a:getText(), "old")
end)
test("L05 changing attached label text invalidates its ancestors", function()
  local r = container.new(); local a = r:add(label.new())
  r._dirty, a._dirty = false, false
  eq(a:setText("new"), a); eq(r._dirty, true); eq(a._dirty, true)
end)
test("L06 text mutation respects the root guard before changing data", function()
  local r = container.new(); local a = r:add(label.new {text = "old"})
  r._mutationGuard = function() error("guard") end
  rejects(function() a:setText("new") end); eq(a:getText(), "old")
end)

test("P01 full frame clears viewport and idle renders skip work", function()
  local r, p, b = screen()
  rejects(function() painter.new({}, {}) end)
  rejects(function() painter.new(r, {}) end)
  local parent = container.new()
  local attached = parent:add(container.new())
  rejects(function() painter.new(attached, renderer.new(b, unicode)) end)
  eq(p:render(), true); eq(b:pixel(20, 8).char, " "); eq(r._dirty, false)
  local count = #b.calls; eq(p:render(), false); eq(#b.calls, count)
  eq(p:render(true), true); rejects(function() p:render(1) end)
end)
test("P02 label fills its rectangle and sanitizes the first text row", function()
  local r, p, b = screen()
  r:add(label.new {x = 2, y = 2, width = 4, height = 2, text = "A\nB", style = {background = 7}})
  p:render(); eq(b:pixel(2, 2).char, "A"); eq(b:pixel(3, 2).char, " ")
  eq(b:pixel(4, 2).char, "B"); eq(b:pixel(2, 3).bg, 7); eq(b:pixel(2, 3).char, " ")
end)
test("P03 insertion order determines overlapping pixels", function()
  local r, p, b = screen()
  r:add(label.new {width = 4, text = "AAAA"})
  r:add(label.new {x = 2, width = 2, text = "BB", style = {background = 5}})
  p:render(); eq(b:pixel(1, 1).char, "A"); eq(b:pixel(2, 1).char, "B")
  eq(b:pixel(3, 1).bg, 5); eq(b:pixel(4, 1).char, "A")
end)
test("P04 nested coordinates are relative to the parent", function()
  local r, p, b = screen()
  local c = r:add(container.new {x = 4, y = 3, width = 8, height = 4})
  c:add(label.new {x = 2, y = 2, text = "X"})
  p:render(); eq(b:pixel(5, 4).char, "X"); eq(b:pixel(2, 2).char, " ")
end)
test("P05 ancestor clipping prevents right-edge text from escaping", function()
  local r, p, b = screen()
  local c = r:add(container.new {x = 3, width = 3, height = 2})
  c:add(label.new {x = 2, width = 4, text = "abcd"})
  c:add(label.new {x = 6, text = "X", style = {foreground = -1}})
  p:render(); eq(b:pixel(4, 1).char, "a"); eq(b:pixel(5, 1).char, "b")
  eq(b:pixel(6, 1).char, " ")
end)
test("P06 a clipped half of a wide Chinese character becomes blank", function()
  local r, p, b = screen()
  local c = r:add(container.new {x = 3, width = 4, height = 2})
  c:add(label.new {x = 0, width = 4, text = "中A"})
  p:render(); eq(b:pixel(3, 1).char, " "); eq(b:pixel(4, 1).char, "A")
end)
test("P07 invisible subtrees do not draw and become clean after success", function()
  local r, p, b = screen()
  local c = r:add(container.new {visible = false})
  local a = c:add(label.new {text = "X"})
  p:render(); eq(b:pixel(1, 1).char, " "); eq(c._dirty, false); eq(a._dirty, false)
  for _, call in ipairs(b.calls) do assert(call ~= "set") end
end)
test("P08 disabled containers still paint with inherited disabled state", function()
  local r, p, b = screen()
  local c = r:add(container.new {width = 4, enabled = false})
  c:add(label.new {text = "X"}); p:render()
  eq(b:pixel(1, 1).char, "X"); eq(b:pixel(1, 1).fg, 0x777777)
end)
test("P09 movement and removal erase pixels from earlier frames", function()
  local r, p, b = screen()
  local a = r:add(label.new {text = "X"}); p:render()
  a:setBounds(5, 2, 1, 1); p:render()
  eq(b:pixel(1, 1).char, " "); eq(b:pixel(5, 2).char, "X")
  r:remove(a); p:render(); eq(b:pixel(5, 2).char, " ")
end)
test("P10 local colors and alignment override application theme", function()
  local r, p, b = screen {label = {foreground = 2, background = 3, alignment = "center"}}
  r:add(label.new {width = 4, text = "X", style = {foreground = 4, alignment = "right"}})
  p:render(); eq(b:pixel(4, 1).char, "X"); eq(b:pixel(4, 1).fg, 4); eq(b:pixel(4, 1).bg, 3)
end)
test("P11 invalid visible style fails before any painting and stays dirty", function()
  local r, p, b = screen()
  local a = r:add(label.new {text = "X", style = {foreground = -1}})
  rejects(function() p:render() end); eq(r._dirty, true); eq(r._mutationGuard, nil)
  eq(#b.calls, 1); eq(b.calls[1], "size")
  a:setStyle {}; eq(p:render(), true)
end)
test("P12 device errors preserve their identity and allow retry", function()
  local r, p, b = screen(); local sentinel = {}
  r:add(label.new {text = "X"}); b.fail, b.sentinel = "set", sentinel
  local ok, err = pcall(p.render, p); eq(ok, false); eq(err, sentinel)
  eq(r._dirty, true); eq(r._mutationGuard, nil)
  b.fail = nil; eq(p:render(), true); eq(b:pixel(1, 1).char, "X")
end)
test("P13 drawing blocks setters and restores the prior mutation guard", function()
  local r, p, b = screen(); local calls = 0
  local oldGuard = function() calls = calls + 1 end
  r._mutationGuard = oldGuard
  local a = r:add(label.new {text = "old", width = 3})
  b.hook = function(name) if name == "fill" then a:setText("new") end end
  rejects(function() p:render() end); eq(a:getText(), "old"); eq(r._mutationGuard, oldGuard)
  b.hook = nil; eq(p:render(), true); assert(calls > 0)
end)
test("P14 recursive painting is rejected and later frames recover", function()
  local r, p, b = screen()
  b.hook = function(name) if name == "fill" then p:render(true) end end
  rejects(function() p:render() end); eq(r._dirty, true)
  b.hook = nil; eq(p:render(), true)
end)
test("P15 theme replacement copies data and validates before mutation", function()
  local r, p, b = screen(); r:add(label.new {text = "X"}); p:render()
  local options = {label = {foreground = 9}}
  eq(p:setTheme(options), p); options.label.foreground = 12
  p:render(); eq(b:pixel(1, 1).fg, 9)
  rejects(function() p:setTheme {label = {foreground = -1}} end)
  eq(r._dirty, false); p:render(true); eq(b:pixel(1, 1).fg, 9)
end)
test("P16 focus state integrates with the accepted interaction manager", function()
  local r, p, b = screen {label = {focused = {foreground = 8}}}
  local a = r:add(label.new {text = "X", focusable = true})
  local m = interaction.new(r, dispatcher.new(r), function() return 0 end)
  local ok, err = pcall(function()
    m:setFocus(a); p:render(); eq(b:pixel(1, 1).fg, 8)
    m:setFocus(nil); p:render(); eq(b:pixel(1, 1).fg, 0xFFFFFF)
  end)
  m:close(); if not ok then error(err, 0) end
end)

report.total = report.passed + report.failed
report.ok = report.failed == 0
print(string.format("SUMMARY: %d passed, %d failed, %d total", report.passed, report.failed, report.total))
return report
