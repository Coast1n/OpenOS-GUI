-- STAGE1-FOUNDATION-001. Run in OpenOS: lua tests/stage1.lua .
-- Loads only the two foundation files. Does not alter package.path or GPU state.
local projectRoot = (...) or "."
assert(type(projectRoot) == "string", "project directory must be a string")
print("TEST SUITE: STAGE1-FOUNDATION-001")
print("LUA: " .. tostring(_VERSION))
assert(_VERSION == "Lua 5.3", "BLOCKED: select Lua 5.3 before testing")

local function loadModule(name)
  local path = projectRoot .. "/lib/ocgui/" .. name .. ".lua"
  local chunk, reason = loadfile(path)
  assert(chunk, "BLOCKED: " .. path .. ": " .. tostring(reason))
  return chunk()
end

local globals = {}
for key, value in pairs(_G) do globals[key] = value end
local oldPath, oldCPath = package.path, package.cpath
local geometry, textModule = loadModule("geometry"), loadModule("text")
local unchanged = package.path == oldPath and package.cpath == oldCPath
for key, value in pairs(_G) do
  if globals[key] ~= value then unchanged = false end
end
for key, value in pairs(globals) do
  if _G[key] ~= value then unchanged = false end
end

local okUnicode, unicode = pcall(require, "unicode")
assert(okUnicode, "BLOCKED: real OpenComputers unicode module required: " .. tostring(unicode))
local text = textModule.new(unicode)
local passed, failed = 0, 0

local function equal(actual, expected)
  if actual ~= expected then
    error("expected " .. string.format("%q", tostring(expected))
      .. ", got " .. string.format("%q", tostring(actual)), 2)
  end
end

local function sameRect(actual, x, y, width, height)
  assert(type(actual) == "table", "expected rectangle")
  equal(actual.x, x); equal(actual.y, y)
  equal(actual.width, width); equal(actual.height, height)
end

local function rejects(callback)
  local ok = pcall(callback)
  equal(ok, false)
end

local function test(id, callback)
  local ok, reason = pcall(callback)
  if ok then
    passed = passed + 1
    print("PASS " .. id)
  else
    failed = failed + 1
    print("FAIL " .. id .. ": " .. tostring(reason))
  end
end

test("G01 rectangle fields", function()
  sameRect(geometry.rect(1, 2, 3, 4), 1, 2, 3, 4)
end)
test("G02 negative origin", function()
  sameRect(geometry.rect(-3, -2, 4, 5), -3, -2, 4, 5)
end)
test("G03 half-open boundaries", function()
  local r = geometry.rect(2, 3, 4, 2)
  equal(geometry.contains(r, 2, 3), true)
  equal(geometry.contains(r, 5, 4), true)
  equal(geometry.contains(r, 6, 4), false)
  equal(geometry.contains(r, 5, 5), false)
  equal(geometry.contains(r, 1, 3), false)
end)
test("G04 empty rectangles", function()
  equal(geometry.contains(geometry.rect(1, 1, 0, 2), 1, 1), false)
  equal(geometry.intersect(geometry.rect(1, 1, 2, 0), geometry.rect(1, 1, 2, 2)), nil)
end)
test("G05 partial intersection", function()
  sameRect(geometry.intersect(geometry.rect(1, 1, 4, 3),
    geometry.rect(3, 2, 4, 4)), 3, 2, 2, 2)
end)
test("G06 disjoint rectangles", function()
  equal(geometry.intersect(geometry.rect(1, 1, 2, 2), geometry.rect(4, 4, 1, 1)), nil)
end)
test("G07 touching edges", function()
  local a = geometry.rect(1, 1, 2, 2)
  equal(geometry.intersect(a, geometry.rect(3, 1, 2, 2)), nil)
  equal(geometry.intersect(a, geometry.rect(1, 3, 2, 2)), nil)
end)
test("G08 contained rectangle", function()
  sameRect(geometry.intersect(geometry.rect(-2, -2, 8, 8),
    geometry.rect(1, 1, 2, 3)), 1, 1, 2, 3)
end)
test("G09 translation does not mutate", function()
  local a = geometry.rect(2, 3, 4, 5)
  sameRect(geometry.translate(a, -3, 2), -1, 5, 4, 5)
  sameRect(a, 2, 3, 4, 5)
end)
test("G10 invalid dimensions and coordinates", function()
  rejects(function() geometry.rect(1, 1, -1, 2) end)
  rejects(function() geometry.rect(1.5, 1, 2, 2) end)
  rejects(function() geometry.rect(1, 1, "2", 2) end)
  rejects(function() geometry.rect(0/0, 1, 2, 2) end)
  rejects(function() geometry.rect(math.huge, 1, 2, 2) end)
end)
test("G11 overflow is rejected", function()
  rejects(function() geometry.rect(math.maxinteger, 1, 1, 1) end)
  rejects(function() geometry.translate(geometry.rect(math.mininteger, 1, 0, 1), -1, 0) end)
end)
test("G12 intersection agrees with point membership", function()
  local a = geometry.rect(-1, 0, 3, 3)
  for bx = -3, 3 do
    local b = geometry.rect(bx, 1, 2, 3)
    local result = geometry.intersect(a, b)
    for x = -4, 5 do
      for y = -1, 5 do
        equal(result ~= nil and geometry.contains(result, x, y),
          geometry.contains(a, x, y) and geometry.contains(b, x, y))
      end
    end
  end
end)
test("L01 module load has no global changes", function() equal(unchanged, true) end)
test("T01 empty text", function() equal(text:width(""), 0) end)
test("T02 ASCII width", function() equal(text:width("hello"), 5) end)
test("T03 native Chinese width", function()
  equal(unicode.charWidth("中"), 2)
  equal(text:width("A中文"), 5)
end)
test("T04 width matches native wlen", function()
  for _, value in ipairs({"", "abc", "中文", "A中B", "é"}) do
    equal(text:width(value), unicode.wlen(value))
  end
end)
test("T05 controls become individual spaces", function()
  equal(text:sanitize("a\n\t\0b"), "a   b")
  equal(text:width("a\n\t\0b"), 5)
end)
test("T06 ASCII clipping", function() equal(text:clip("abcdef", 2, 3), "bcd") end)
test("T07 keep whole wide character", function() equal(text:clip("A中B", 2, 2), "中") end)
test("T08 cut left half to space", function() equal(text:clip("A中B", 3, 2), " B") end)
test("T09 cut right half to space", function() equal(text:clip("A中B", 1, 2), "A ") end)
test("T10 one cell of wide character", function() equal(text:clip("中", 2, 1), " ") end)
test("T11 beyond text pads spaces", function() equal(text:clip("abc", 6, 3), "   ") end)
test("T12 zero width", function()
  equal(text:clip("中", 1, 0), "")
  equal(text:fit("中", 0), "")
end)
test("T13 short text pads spaces", function() equal(text:clip("hi", 1, 4), "hi  ") end)
test("T14 left alignment", function() equal(text:fit("a", 4), "a   ") end)
test("T15 right alignment", function() equal(text:fit("a", 4, "right"), "   a") end)
test("T16 center alignment", function() equal(text:fit("a", 4, "center"), " a  ") end)
test("T17 overflow clips on right", function()
  equal(text:fit("A中B", 2, "right"), "A ")
end)
test("T18 invalid alignment", function()
  rejects(function() text:fit("a", 2, "invalid") end)
  rejects(function() text:fit("a", 2, false) end)
end)
test("T19 invalid text and widths", function()
  rejects(function() text:width(12) end)
  rejects(function() text:clip("a", 0, 1) end)
  rejects(function() text:clip("a", 1, -1) end)
  rejects(function() text:fit("a", 1.5) end)
  rejects(function() textModule.new({}) end)
end)
test("T20 clip always occupies requested cells", function()
  for _, value in ipairs({"", "abc", "中", "A中B文", "a\t中"}) do
    for first = 1, 8 do
      for count = 0, 6 do
        equal(unicode.wlen(text:clip(value, first, count)), count)
      end
    end
  end
end)

print(string.format("SUMMARY: %d passed, %d failed, %d total", passed, failed, passed + failed))
if failed > 0 then error("STAGE1 FAILED: return the complete output", 0) end
print("STAGE1 PASS: return this summary and your GTNH / OC / OpenOS versions")
