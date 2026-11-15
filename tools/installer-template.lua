-- Generated OpenOS online installer. Requires an internet card.
-- Download with wget, then execute with lua. No shell command evaluation.
local fs, internet = require("filesystem"), require("internet")
local repository, ref = ...
repository, ref = repository or "Coast1n/OpenOS-GUI", ref or "main"
assert(repository:match("^[%w_.-]+/[%w_.-]+$"), "invalid repository")
assert(ref:match("^[%w_.-]+$"), "invalid revision")
local payloads = {
  @@PAYLOADS@@
}
-- OpenComputers tmpfs defaults to 64 KiB; the GUI alone exceeds that.
-- Keep downloaded payloads on the writable home filesystem instead.
local home = assert(fs.get("/home"), "cannot locate home filesystem")
assert(not home.isReadOnly(), "/home is read-only; use a writable OpenOS installation")
local required = 8192
for _, item in ipairs(payloads) do required = required + item.bytes * 2 end
assert(home.spaceTotal() - home.spaceUsed() >= required,
  "/home needs at least " .. required .. " free bytes for download and installation staging")
local stage, index = "/home/.ocgui-install", 0
while fs.exists(stage) do index = index + 1; stage = "/home/.ocgui-install-" .. index end
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
  @@INSTALL@@
end)
cleanup()
if not ok then error(tostring(reason), 0) end
