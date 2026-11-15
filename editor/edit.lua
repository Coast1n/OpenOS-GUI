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
