-- Generated OpenOS online installer. Requires an internet card.
-- Download with wget, then execute with lua. No shell command evaluation.
local fs, internet = require("filesystem"), require("internet")
local repository, ref = ...
repository, ref = repository or "Coast1n/OpenOS-GUI", ref or "main"
assert(repository:match("^[%w_.-]+/[%w_.-]+$"), "invalid repository")
assert(ref:match("^[%w_.-]+$"), "invalid revision")
local payloads = {
  {name="ocgui.lua", bytes=71024, checksum=3120501473},
  {name="edit.lua", bytes=18296, checksum=1195042198}
}
local stage, index = "/tmp/ocgui-install", 0
while fs.exists(stage) do index = index + 1; stage = "/tmp/ocgui-install-" .. index end
assert(fs.makeDirectory(stage .. "/dist"), "cannot create download directory")
local function cleanup()
  for _, item in ipairs(payloads) do fs.remove(stage .. "/dist/" .. item.name) end
  fs.remove(stage .. "/dist"); fs.remove(stage)
end
local function checksum(data)
  local a, b = 1, 0
  for i = 1, #data do a = (a + data:byte(i)) % 65521; b = (b + a) % 65521 end
  return b * 65536 + a
end
local ok, reason = pcall(function()
  for _, item in ipairs(payloads) do
    local url = "https://raw.githubusercontent.com/" .. repository .. "/" .. ref .. "/dist/" .. item.name
    print("Downloading " .. item.name)
    local request = internet.request(url)
    local downloaded, data = pcall(function()
      local parts, size = {}, 0
      for chunk in request do
        size = size + #chunk; assert(size <= item.bytes, "unexpected download size")
        parts[#parts + 1] = chunk
      end
      return table.concat(parts)
    end)
    pcall(function() request.close() end)
    assert(downloaded, data)
    assert(#data == item.bytes and checksum(data) == item.checksum, "download corrupted or installer outdated; download installer again")
    assert(load(data, "=" .. item.name, "t", {}), "download is not valid Lua")
    local file, err = io.open(stage .. "/dist/" .. item.name, "wb"); assert(file, err)
    local written, writeErr = pcall(function() assert(file:write(data)); assert(file:flush()) end)
    local closed, result, closeErr = pcall(file.close, file)
    assert(written and closed and result ~= false and not (result == nil and closeErr), writeErr or closeErr or result)
  end
  -- The same transactional installer is used by offline and online deployment.
  -- Run inside OpenOS after preview tests. Back up replaced files, never overwrite backups.
local fs, shell = require("filesystem"), require("shell")
local root = stage
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

end)
cleanup()
if not ok then error(tostring(reason), 0) end
