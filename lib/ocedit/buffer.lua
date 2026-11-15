local unicode = require("unicode")
local buffer = {}
local Buffer = {}
Buffer.__index = Buffer
local function copy(lines)
  local result = {}
  for i, line in ipairs(lines) do result[i] = line end
  return result
end
local function split(text)
  local lines = {}
  for line in (text .. "\n"):gmatch("(.-)\n") do
    assert(#lines < 4096, "文件超过 4096 行")
    lines[#lines + 1] = line
  end
  return lines
end
local function history(stack, item)
  stack[#stack + 1] = item
  local bytes = 0
  for _, state in ipairs(stack) do bytes = bytes + #state.text end
  while #stack > 16 or (bytes > 131072 and #stack > 1) do
    bytes = bytes - #stack[1].text; table.remove(stack, 1)
  end
end
function buffer.new(text)
  assert(type(text) == "string" and not text:find("%z"), "只支持文本文件")
  assert(#text <= 65536, "文件超过 64 KiB")
  local eol = text:find("\r\n", 1, true) and "\r\n" or "\n"
  text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
  return setmetatable({lines = split(text), row = 1, col = 0, saved = text,
    eol = eol, undoStack = {}, redoStack = {}}, Buffer)
end
function Buffer:text() return table.concat(self.lines, "\n") end
function Buffer:serialize() return (self:text():gsub("\n", self.eol)) end
function Buffer:dirty() return self:text() ~= self.saved end
function Buffer:markSaved() self.saved = self:text() end
function Buffer:_state() return {text = self:text(), row = self.row, col = self.col} end
function Buffer:_restore(state)
  self.lines, self.row, self.col = split(state.text), state.row, state.col
  self.goal = nil
end
function Buffer:_commit(text, row, col)
  local _, newlines = text:gsub("\n", "")
  assert(newlines < 4096, "内容超过 4096 行")
  assert(#text + (self.eol == "\r\n" and newlines or 0) <= 65536, "内容超过 64 KiB")
  if text == self:text() then return end
  history(self.undoStack, self:_state()); self.redoStack = {}
  self:_restore {text = text, row = row, col = col}
end
function Buffer:insert(value)
  assert(type(value) == "string" and not value:find("%z"), "不能插入二进制内容")
  value = value:gsub("\r\n", "\n"):gsub("\r", "\n")
  local line = self.lines[self.row]
  local before, after = unicode.sub(line, 1, self.col), unicode.sub(line, self.col + 1)
  local parts = split(value)
  local row, col = self.row + #parts - 1, unicode.len(parts[#parts])
  if #parts == 1 then col = self.col + col end
  local lines = {}
  for i = 1, self.row - 1 do lines[#lines + 1] = self.lines[i] end
  if #parts == 1 then lines[#lines + 1] = before .. value .. after
  else
    lines[#lines + 1] = before .. parts[1]
    for i = 2, #parts - 1 do lines[#lines + 1] = parts[i] end
    lines[#lines + 1] = parts[#parts] .. after
  end
  for i = self.row + 1, #self.lines do lines[#lines + 1] = self.lines[i] end
  self:_commit(table.concat(lines, "\n"), row, col)
end
function Buffer:backspace()
  local lines, row, col = copy(self.lines), self.row, self.col
  if col > 0 then
    local line = lines[row]
    lines[row] = unicode.sub(line, 1, col - 1) .. unicode.sub(line, col + 1); col = col - 1
  elseif row > 1 then
    col = unicode.len(lines[row - 1]); lines[row - 1] = lines[row - 1] .. lines[row]
    table.remove(lines, row); row = row - 1
  else return end
  self:_commit(table.concat(lines, "\n"), row, col)
end
function Buffer:delete()
  local lines, row, col = copy(self.lines), self.row, self.col
  local line = lines[row]
  if col < unicode.len(line) then lines[row] = unicode.sub(line, 1, col) .. unicode.sub(line, col + 2)
  elseif row < #lines then lines[row] = line .. lines[row + 1]; table.remove(lines, row + 1)
  else return end
  self:_commit(table.concat(lines, "\n"), row, col)
end
function Buffer:undo()
  if #self.undoStack == 0 then return end
  history(self.redoStack, self:_state()); self:_restore(table.remove(self.undoStack))
end
function Buffer:redo()
  if #self.redoStack == 0 then return end
  history(self.undoStack, self:_state()); self:_restore(table.remove(self.redoStack))
end
local function width(char, column)
  return char == "\t" and (4 - column % 4) or math.max(1, unicode.charWidth(char))
end
function Buffer:column(row, col)
  local result, line = 0, self.lines[row or self.row]
  for i = 1, col or self.col do result = result + width(unicode.sub(line, i, i), result) end
  return result
end
function Buffer:place(row, column)
  self.goal = nil
  self.row = math.max(1, math.min(row, #self.lines)); self.col = 0
  local line, x = self.lines[self.row], 0
  for i = 1, unicode.len(line) do
    local size = width(unicode.sub(line, i, i), x)
    if x + size > column then break end
    x = x + size; self.col = i
  end
end
function Buffer:move(direction, amount)
  local row, col = self.row, self.col
  if direction == "up" or direction == "down" then
    local goal = self.goal or self:column()
    self:place(row + (direction == "up" and -1 or 1) * (amount or 1), goal); self.goal = goal
  elseif direction == "home" then self.col = 0
  elseif direction == "end" then self.col = unicode.len(self.lines[row])
  elseif direction == "left" then
    if col > 0 then self.col = col - 1 elseif row > 1 then self.row = row - 1; self.col = unicode.len(self.lines[self.row]) end
  elseif direction == "right" then
    if col < unicode.len(self.lines[row]) then self.col = col + 1 elseif row < #self.lines then self.row, self.col = row + 1, 0 end
  end
  if direction ~= "up" and direction ~= "down" then self.goal = nil end
end
function Buffer:display(row, left, count)
  local line, parts, x = self.lines[row] or "", {}, 0
  for i = 1, unicode.len(line) do
    local char = unicode.sub(line, i, i); local size = width(char, x)
    local a, b = math.max(x, left), math.min(x + size, left + count)
    if b > a then
      if char == "\t" or size ~= b - a or char:find("[%z\1-\31\127]") then
        parts[#parts + 1] = string.rep(" ", b - a)
      else parts[#parts + 1] = char end
    end
    x = x + size
    if x >= left + count then break end
  end
  return table.concat(parts)
end
return buffer
