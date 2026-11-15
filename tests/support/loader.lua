-- Project-local require without changing package.path or package.loaded.
return function(projectRoot)
  local cache = {}
  local nativeRequire = require
  local function import(name)
    if name ~= "ocgui" and not name:match("^ocgui%.[%w_%.]+$") then return nativeRequire(name) end
    if cache[name] ~= nil then return cache[name] end
    local path = projectRoot .. "/lib/" .. name:gsub("%.", "/") .. ".lua"
    local env = setmetatable({require = import}, {__index = _G})
    local chunk, reason = loadfile(path, "t", env)
    assert(chunk, tostring(reason))
    local result = chunk()
    cache[name] = result
    return result
  end
  return import
end
