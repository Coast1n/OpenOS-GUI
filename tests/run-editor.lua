local root = require("shell").resolve((...) or ".")
local fs = require("filesystem")
local output = assert(loadfile(root .. "/tests/support/report.lua"))()
local Buffer = assert(loadfile(root .. "/lib/ocedit/buffer.lua"))()
local report = {suite = "EDITOR-001", passed = 0, failed = 0, cases = {}}
local function eq(a, b) assert(a == b, "expected " .. tostring(b) .. ", got " .. tostring(a)) end
local function rejects(fn) eq(pcall(fn), false) end
local function test(name, fn)
  local ok, err = pcall(fn)
  report[ok and "passed" or "failed"] = report[ok and "passed" or "failed"] + 1
  report.cases[#report.cases + 1] = {name = name, passed = ok, error = not ok and tostring(err) or nil}
  print((ok and "PASS " or "FAIL ") .. name .. (ok and "" or ": " .. tostring(err)))
end
test("E01 empty buffer", function() local b = Buffer.new(""); eq(#b.lines, 1); eq(b:dirty(), false) end)
test("E02 Unicode insertion", function()
  local b = Buffer.new("ab"); b.col = 1; b:insert("中文"); eq(b:text(), "a中文b"); eq(b.col, 3)
end)
test("E03 trailing newline preserved", function() eq(Buffer.new("a\nb\n"):serialize(), "a\nb\n") end)
test("E04 CRLF preserved", function() local b = Buffer.new("a\r\nb"); b:insert("x\ny"); eq(b:serialize(), "x\r\nya\r\nb") end)
test("E05 backspace joins lines", function()
  local b = Buffer.new("ab\n中"); b.row, b.col = 2, 0; b:backspace(); eq(b:text(), "ab中"); eq(b.col, 2)
end)
test("E06 delete joins lines", function()
  local b = Buffer.new("ab\n中"); b.col = 2; b:delete(); eq(b:text(), "ab中")
end)
test("E07 Unicode deletion", function()
  local b = Buffer.new("中ab"); b.col = 1; b:backspace(); eq(b:text(), "ab"); b:delete(); eq(b:text(), "b")
end)
test("E08 undo redo and saved state", function()
  local b = Buffer.new(""); b:insert("x"); b:markSaved(); eq(b:dirty(), false)
  b:undo(); eq(b:dirty(), true); b:redo(); eq(b:dirty(), false)
end)
test("E09 new edit clears redo", function()
  local b = Buffer.new(""); b:insert("x"); b:undo(); b:insert("y"); b:redo(); eq(b:text(), "y")
end)
test("E10 wide text and tabs use display columns", function()
  local b = Buffer.new("中\tX"); b.col = 2; eq(b:column(), 4); b:place(1, 3); eq(b.col, 1)
end)
test("E11 clipped wide character becomes blank", function()
  local b = Buffer.new("中AB"); eq(b:display(1, 1, 3), " AB")
end)
test("E12 vertical motion retains desired column", function()
  local b = Buffer.new("abcdef\nx\nabcdef"); b.col = 5; b:move("down"); eq(b.col, 1)
  b:move("down"); eq(b.col, 5)
end)
test("E13 size refusal is atomic", function()
  local b = Buffer.new(string.rep("a", 65536)); rejects(function() b:insert("x") end); eq(#b:text(), 65536)
end)
test("E14 binary input rejected", function() rejects(function() Buffer.new("a\0b") end) end)
test("E15 multiline insertion positions", function()
  local b = Buffer.new("ab"); b.col = 1; b:insert("X\nY"); eq(b:text(), "aX\nYb"); eq(b.row, 2); eq(b.col, 1)
end)
test("E16 line limit refusal is atomic", function()
  local b = Buffer.new(string.rep("\n", 4095)); rejects(function() b:insert("\n") end)
  eq(#b.lines, 4096); eq(#b.undoStack, 0)
end)
local function disk()
  local files, control = {["/file"] = "old"}, {}
  local mockFS = {
    exists = function(p) return files[p] ~= nil end,
    isDirectory = function() return false end,
    remove = function(p) files[p] = nil; return true end,
    rename = function(a, b)
      if control.commitFail and a:find(".ocedit-tmp", 1, true) and b == "/file" then return nil, "commit failed" end
      if files[a] == nil or files[b] ~= nil then return nil, "rename refused" end
      files[b], files[a] = files[a], nil; return true
    end
  }
  local mockIO = {open = function(p, mode)
    if mode == "wb" then files[p] = "" elseif files[p] == nil then return nil, "missing" end
    return {
      read = function(_, count) return files[p]:sub(1, count) end,
      write = function(self, data) files[p] = files[p] .. data; return self end,
      flush = function() if control.flushFail then return nil, "flush failed" end; return true end,
      close = function() return true end
    }
  end}
  local env = setmetatable({io = mockIO, require = function(name) eq(name, "filesystem"); return mockFS end}, {__index = _G})
  return assert(loadfile(root .. "/lib/ocedit/storage.lua", "t", env))(), files, control
end
test("S01 save keeps original backup", function()
  local s, files = disk(); local backup = s.write("/file", "new"); eq(files["/file"], "new"); eq(files[backup], "old")
end)
test("S02 failed flush leaves original untouched", function()
  local s, files, c = disk(); c.flushFail = true; rejects(function() s.write("/file", "new") end); eq(files["/file"], "old")
end)
test("S03 failed commit restores original", function()
  local s, files, c = disk(); c.commitFail = true; rejects(function() s.write("/file", "new") end); eq(files["/file"], "old")
end)
test("S04 repeated saves keep distinct backups", function()
  local s, files = disk(); local a = s.write("/file", "new"); local b = s.write("/file", "newer")
  assert(a ~= b); eq(files[a], "old"); eq(files[b], "new"); eq(files["/file"], "newer")
end)
report.total = report.passed + report.failed; report.ok = report.failed == 0
local index, directory = 1
repeat directory = root .. string.format("/tests/results/editor-run-%03d", index); index = index + 1 until not fs.exists(directory)
assert(fs.makeDirectory(directory))
output.write(directory .. "/report.json", output.json(report) .. "\n")
output.write(directory .. "/summary.txt", string.format("EDITOR: %d passed, %d failed, %d total\n", report.passed, report.failed, report.total))
print("FILES SAVED TO: " .. directory)
assert(report.ok, "editor tests failed; return result directory")
return report
