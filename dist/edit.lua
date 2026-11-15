-- OpenOS GUI editor; generated from editor/ and lib/ocedit/.
-- Copyright (c) 2020 Benjamin Dobell
-- 
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
-- 
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
-- 
local __ocedit_main = (function()
-- Bundled by luabundle {"rootModuleName":"__editor","version":"1.7.0"}
local __bundle_require, __bundle_loaded, __bundle_register, __bundle_modules = (function(superRequire)
	local loadingPlaceholder = {[{}] = true}

	local register
	local modules = {}

	local require
	local loaded = {}

	register = function(name, body)
		if not modules[name] then
			modules[name] = body
		end
	end

	require = function(name)
		local loadedModule = loaded[name]

		if loadedModule then
			if loadedModule == loadingPlaceholder then
				return nil
			end
		else
			if not modules[name] then
				if not superRequire then
					local identifier = type(name) == 'string' and '\"' .. name .. '\"' or tostring(name)
					error('Tried to require ' .. identifier .. ', but no such module has been registered')
				else
					return superRequire(name)
				end
			end

			loaded[name] = loadingPlaceholder
			loadedModule = modules[name](require, loaded, register, modules)
			loaded[name] = loadedModule
		end

		return loadedModule
	end

	return require, loaded, register, modules
end)(require)
__bundle_register("__editor", function(require, _LOADED, __bundle_register, __bundle_modules)
return function(...)
-- Installed as /bin/edit.lua; uses the external single-file /lib/ocgui.lua.
local gui = require("ocgui")
local Buffer = require("ocedit.buffer")
local storage = require("ocedit.storage")
local shell, unicode, event = require("shell"), require("unicode"), require("event")
local fs = require("filesystem")
local args, options = shell.parse(...)
if #args ~= 1 then print("Usage: edit [-r] <file>"); return end
local path = shell.resolve(args[1])
assert(fs.exists(fs.path(path)) and fs.isDirectory(fs.path(path)), "父目录不存在")
local original, existed = storage.read(path)
local model = Buffer.new(original)
local readonly = options.r == true
local app = gui.application {theme = {container = {background = 0x101820}, label = {background = 0x101820}}}
local title = app.root:add(gui.label {text = path})
local save = app.root:add(gui.button {x = 1, y = 2, width = 10, text = "保存"})
local quit = app.root:add(gui.button {x = 12, y = 2, width = 10, text = "退出"})
local cancel = app.root:add(gui.button {x = 23, y = 2, width = 10, text = "取消", visible = false})
local tab = app.root:add(gui.button {x = 34, y = 2, width = 10, text = "插入Tab"})
local pane = app.root:add(gui.container {y = 4, focusable = true})
local status = app.root:add(gui.label())
local rows, caret, width, height = {}, nil, 0, 0
local first, left, pending, message = 1, 0, false, "Ctrl+S 保存 | Ctrl+Q 退出 | Ctrl+Z/Y 撤销/重做"
local held = {}
local refresh
local function rebuild()
  local _, _, w, h = app.root:getBounds()
  if w == width and h == height then return end
  assert(w >= 44 and h >= 10, "编辑器需要至少 44×10 的屏幕")
  width, height = w, h
  title:setBounds(1, 1, w, 1); status:setBounds(1, h, w, 1)
  pane:setBounds(1, 4, w, h - 5)
  for _, child in ipairs(pane:getChildren()) do pane:remove(child) end
  rows = {}
  for y = 1, h - 5 do rows[y] = pane:add(gui.label {y = y, width = w}) end
  caret = pane:add(gui.label {style = {foreground = 0x000000, background = 0xFFD060}})
end
refresh = function(ensure)
  rebuild()
  local view = height - 5
  if ensure then
    first = math.max(1, math.min(first, model.row))
    if model.row >= first + view then first = model.row - view + 1 end
    local column = model:column()
    left = math.max(0, math.min(left, column))
    if column >= left + width - 6 then left = column - (width - 7) end
  end
  for y, label in ipairs(rows) do
    local row = first + y - 1
    label:setText(row <= #model.lines and (string.format("%5d ", row) .. model:display(row, left, width - 6)) or "")
  end
  local cx, cy = 7 + model:column() - left, model.row - first + 1
  local visible = not pending and cy >= 1 and cy <= view and cx >= 7 and cx <= width
  caret:setVisible(visible)
  if visible then
    local char = unicode.sub(model.lines[model.row], model.col + 1, model.col + 1)
    if char == "" or char:find("[%z\1-\31\127]") then char = " " end
    caret:setBounds(cx, cy, math.min(math.max(1, unicode.charWidth(char)), width - cx + 1), 1)
    caret:setText(char)
  end
  title:setText((model:dirty() and "* " or "") .. (readonly and "[只读] " or "") .. path)
  status:setText(string.format("%d:%d  %s  %s", model.row, model.col + 1, model.eol == "\r\n" and "CRLF" or "LF", message))
end
local function protect(fn)
  local ok, err = pcall(fn)
  if not ok then message = "错误: " .. tostring(err) end
  refresh(true)
end
local function resetQuit()
  pending = false; quit:setText("退出"); save:setText("保存"); cancel:setVisible(false)
  message = "已取消退出"; app:setFocus(pane)
end
local function requestQuit()
  if not model:dirty() then app:stop(); return end
  if pending then return end
  pending = true; save:setText("保存退出"); quit:setText("放弃退出"); cancel:setVisible(true)
  message = "未保存：选择保存退出、放弃退出或取消"; app:setFocus(cancel)
end
local function saveFile()
  assert(not readonly, "只读模式不能保存")
  local current, exists = storage.read(path)
  assert(exists == existed and current == original, "文件已在外部改变，请保留当前内容后重新打开")
  local data = model:serialize()
  local backup = storage.write(path, data)
  original, existed = data, true; model:markSaved()
  message = backup and ("已保存；备份: " .. backup) or "已保存"
  if pending then app:stop() else app:setFocus(pane) end
end
save:on("click", function() protect(saveFile) end)
quit:on("click", function() protect(function() if pending then app:stop() else requestQuit() end end) end)
cancel:on("click", function() protect(resetQuit) end)
tab:on("click", function() protect(function()
  assert(not readonly and not pending, "当前不能编辑"); model:insert("\t"); app:setFocus(pane)
end) end)
pane:on("pointer_down", function(_, e)
  if e.button == 0 and not pending then model:place(first + e.y - 1, left + math.max(0, e.x - 7)); refresh(true) end
end)
pane:on("scroll", function(_, e)
  first = math.max(1, math.min(math.max(1, #model.lines), first - e.delta * 3)); refresh(false)
end)
app.root:on("key_up", function(_, e)
  local keys = held[e.source]; if keys then keys[e.code] = nil end
end)
app.root:on("key_down", function(_, e)
  local keys = held[e.source] or {}; held[e.source] = keys; keys[e.code] = true
  local ctrl, alt = keys[29] or keys[157], keys[56] or keys[184]
  protect(function()
    if ctrl then
      if e.code == 31 and not e.repeated then saveFile()
      elseif e.code == 16 and not e.repeated then requestQuit()
      elseif not pending and not readonly then
        if e.code == 44 then model:undo() elseif e.code == 21 then model:redo()
        elseif e.code == 23 then model:insert("\t") end
      end
    elseif pending then
      if e.code == 1 then resetQuit() end
    elseif e.target == pane then
      local moves = {[200] = "up", [208] = "down", [203] = "left", [205] = "right", [199] = "home", [207] = "end"}
      if moves[e.code] then model:move(moves[e.code])
      elseif e.code == 201 then model:move("up", height - 5)
      elseif e.code == 209 then model:move("down", height - 5)
      elseif not readonly then
        if e.code == 14 then model:backspace() elseif e.code == 211 then model:delete()
        elseif e.code == 28 then model:insert("\n")
        elseif not alt and e.char >= 32 and e.char ~= 127 then model:insert(unicode.char(e.char)) end
      end
    end
  end)
  return true
end)
app.root:on("text_paste", function(_, e)
  if e.target == pane then protect(function()
    assert(not readonly and not pending, "当前不能粘贴"); model:insert(e.text)
  end); return true end
end)
local ok, reason = pcall(function()
  local opened, err = app:open(); if not opened then error(err.message, 0) end
  rebuild(); app:setFocus(pane); refresh(true)
  while app:isActive() do
    refresh(false)
    local drawn, drawErr = app:render(); if not drawn then error(drawErr.message, 0) end
    local wait, waitErr = app:nextTimeout(); if waitErr then error(waitErr.message, 0) end
    local raw = table.pack(event.pull(wait))
    if raw[1] == "interrupted" then requestQuit(); refresh(true)
    else
      if raw[1] == "component_added" or raw[1] == "component_removed" or raw[1] == "screen_resized" then held = {} end
      local handled, dispatchErr = app:dispatch(table.unpack(raw, 1, raw.n))
      if handled == nil then error(dispatchErr.message, 0) end
    end
  end
end)
local closed, cleanup = app:close()
if not ok then
  local recovery
  if model:dirty() then
    recovery = path .. ".ocedit-recovery"
    local n = 0
    while fs.exists(recovery) do n = n + 1; recovery = path .. ".ocedit-recovery-" .. n end
    local saved = pcall(storage.write, recovery, model:serialize())
    if saved then io.stderr:write("恢复文件: " .. recovery .. "\n") end
  end
  error(tostring(reason), 0)
end
if not closed then error(cleanup.message, 0) end

end
end)
__bundle_register("ocedit.storage", function(require, _LOADED, __bundle_register, __bundle_modules)
local fs = require("filesystem")
local storage = {}
function storage.read(path)
  assert(not fs.isDirectory(path), "目标是目录")
  if not fs.exists(path) then return "", false end
  local f, reason = io.open(path, "rb"); assert(f, reason)
  local data = f:read(65537) or ""; f:close()
  assert(#data <= 65536, "文件超过 64 KiB")
  return data, true
end
function storage.write(path, data)
  assert(not fs.isDirectory(path), "目标是目录")
  local temp, index = path .. ".ocedit-tmp", 0
  while fs.exists(temp) do index = index + 1; temp = path .. ".ocedit-tmp-" .. index end
  local f, reason = io.open(temp, "wb"); assert(f, reason)
  local ok, err = pcall(function()
    assert(f:write(data)); assert(f:flush())
  end)
  local closed, closeResult, closeReason = pcall(f.close, f)
  if not ok or not closed or closeResult == false or (closeResult == nil and closeReason ~= nil) then
    fs.remove(temp); error(err or closeResult or "关闭临时文件失败", 0)
  end
  local backup
  if fs.exists(path) then
    backup, index = path .. ".ocedit-backup", 0
    while fs.exists(backup) do index = index + 1; backup = path .. ".ocedit-backup-" .. index end
    local moved, moveErr = fs.rename(path, backup)
    if not moved then fs.remove(temp); error(moveErr or "备份失败", 0) end
  end
  local moved, moveErr = fs.rename(temp, path)
  if not moved then
    local restored, restoreErr = true, nil
    if backup then restored, restoreErr = fs.rename(backup, path) end
    fs.remove(temp)
    error(tostring(moveErr) .. (not restored and ("；恢复失败，原文件在 " .. backup .. ": " .. tostring(restoreErr)) or ""), 0)
  end
  -- Preserve the backup so an edited file remains recoverable.
  return backup
end
return storage

end)
__bundle_register("ocedit.buffer", function(require, _LOADED, __bundle_register, __bundle_modules)
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

end)
return __bundle_require("__editor")
end)()
return __ocedit_main(...)
