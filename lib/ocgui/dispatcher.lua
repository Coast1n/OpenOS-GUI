-- Pure routing only; interaction owns focus, capture and built-in defaults.
local widget = require("ocgui.widget")
local input = require("ocgui.input")
local dispatcher = {}
local Dispatcher = {}
Dispatcher.__index = Dispatcher

function dispatcher.new(root)
  if not widget.is(root) or type(root._children) ~= "table" or root:getParent() ~= nil then
    error("dispatcher requires a root container", 2)
  end
  return setmetatable({_root = root, _dispatching = false}, Dispatcher)
end

function Dispatcher:cancel()
  if self._dispatching then self._cancelled = true end
end

function Dispatcher:dispatch(target, normalized)
  if self._dispatching then error("event dispatch cannot be reentered", 2) end
  if type(normalized) ~= "table" or type(normalized.type) ~= "string" then error("event must have a type", 2) end
  if target == nil then return false end
  if not widget.is(target) then error("target must be a widget", 2) end
  if target:_root() ~= self._root or not target:isVisible() or not target:isEnabled() then return false end
  local path, current = {}, target
  while current do
    path[#path + 1] = {node = current, parent = current:getParent(),
      version = current._attachmentVersion, handlers = current:_snapshotHandlers(normalized.type)}
    current = current:getParent()
  end
  local event = {}
  for key, value in pairs(normalized) do event[key] = value end
  local function valid(index)
    if self._cancelled then return false end
    for i = index, #path do
      local part, node = path[i], path[i].node
      if node:getParent() ~= part.parent or node._attachmentVersion ~= part.version
          or not node:isVisible() or not node:isEnabled() then return false end
    end
    return target ~= nil and path[#path].node == self._root and self._root:getParent() == nil
  end
  self._dispatching, self._cancelled = true, false
  local ok, result = pcall(function()
    local limit = (event.type == "focus" or event.type == "blur") and 1 or #path
    for index = 1, limit do
      if valid(index) then
        local node = path[index].node
        event.target, event.currentTarget = target, node
        event.x, event.y = nil, nil
        if input.isPointer(event.type) then
          local x, y = node:getAbsoluteBounds()
          event.x, event.y = event.screenX - x + 1, event.screenY - y + 1
        end
        if node:_emit(event, path[index].handlers, function() return valid(index) end) then return true end
      end
    end
    return false
  end)
  local cancelled = self._cancelled
  self._dispatching, self._cancelled = false, false
  if not ok then error(result, 0) end
  return result, cancelled
end

function Dispatcher:dispatchPointer(event)
  if self._dispatching then error("event dispatch cannot be reentered", 2) end
  if type(event) ~= "table" or not input.isPointer(event.type) then error("expected a pointer event", 2) end
  return self:dispatch(self._root:hitTest(event.screenX, event.screenY), event)
end

return dispatcher
