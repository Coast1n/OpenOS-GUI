-- Run inside OpenOS after preview tests. Back up replaced files, never overwrite backups.
local fs, shell = require("filesystem"), require("shell")
local root = shell.resolve((...) or "/home/OpenOS-GUI")
local targets = {{source = root .. "/dist/ocgui.lua", target = "/lib/ocgui.lua"},
  {source = root .. "/dist/edit.lua", target = "/bin/edit.lua"}}
local function read(file)
  local f, err = io.open(file, "rb"); assert(f, err)
  local data = assert(f:read("*a")); f:close(); return data
end
local function unused(base)
  local file, index = base, 0
  while fs.exists(file) do index = index + 1; file = base .. "-" .. index end
  return file
end
local staged, installed = {}, {}
local ok, reason = pcall(function()
  for _, item in ipairs(targets) do
    local data = read(item.source)
    assert(not fs.isDirectory(item.target), "目标是目录: " .. item.target)
    item.temp = unused(item.target .. ".ocedit-install")
    staged[#staged + 1] = item
    local f, err = io.open(item.temp, "wb"); assert(f, err)
    local written, writeErr = pcall(function() assert(f:write(data)); assert(f:flush()) end)
    local closed, result, closeErr = pcall(f.close, f)
    assert(written and closed and result ~= false and not (result == nil and closeErr), writeErr or closeErr or result)
    assert(read(item.temp) == data, "复制校验失败")
  end
  for _, item in ipairs(staged) do
    if fs.exists(item.target) then
      item.backup = unused(item.target .. ".before-ocedit")
      assert(fs.rename(item.target, item.backup))
    end
    installed[#installed + 1] = item
    assert(fs.rename(item.temp, item.target))
  end
end)
if not ok then
  for i = #installed, 1, -1 do
    local item = installed[i]
    if fs.exists(item.target) then fs.remove(item.target) end
    if item.backup then
      local restored, err = fs.rename(item.backup, item.target)
      if not restored then io.stderr:write("恢复失败，原文件保留在 " .. item.backup .. ": " .. tostring(err) .. "\n") end
    end
  end
  for _, item in ipairs(staged) do if fs.exists(item.temp) then fs.remove(item.temp) end end
  error(tostring(reason), 0)
end
print("安装完成。重启游戏内电脑后使用: edit <file>")
for _, item in ipairs(installed) do
  print("已安装: " .. item.target)
  if item.backup then print("原文件备份: " .. item.backup) end
end
