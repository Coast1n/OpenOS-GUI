-- Preview without installing or replacing the system edit command.
local root, file = ...
root = require("shell").resolve(root or "/home/OpenOS-GUI")
assert(file, "Usage: lua editor/preview.lua <project-root> <file>")
local native = require
local loaded
local env = setmetatable({require = function(name)
  if name == "ocgui" then
    if not loaded then loaded = assert(loadfile(root .. "/dist/ocgui.lua"))() end
    return loaded
  end
  return native(name)
end}, {__index = _G})
assert(loadfile(root .. "/dist/edit.lua", "t", env))(file)
