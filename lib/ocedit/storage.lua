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
