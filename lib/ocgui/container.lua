local widget = require("ocgui.widget")
local container = {}
local Container = setmetatable({}, {__index = widget.methods})
Container.__index = Container

function container.new(options)
  local object = widget.new(options)
  object._children = {}
  return setmetatable(object, Container)
end

function Container:getChildren()
  local result = {}
  for i, child in ipairs(self._children) do result[i] = child end
  return result
end

function Container:add(child)
  if not widget.is(child) then error("child must be a widget", 2) end
  if child._parent then error("child already has a parent; remove it first", 2) end
  if child._isApplicationRoot then error("cannot attach an application root", 2) end
  local current = self
  while current do
    if current == child then error("widget tree cannot contain a cycle", 2) end
    current = current._parent
  end
  self:_assertMutable()
  child:_assertMutable()
  self._children[#self._children + 1] = child
  child._parent = self
  child._attachmentVersion = child._attachmentVersion + 1
  child:_changed("added")
  return child
end

function Container:remove(child)
  for index, member in ipairs(self._children) do
    if member == child then
      self:_assertMutable()
      local root = self:_root()
      table.remove(self._children, index)
      child._parent, child._dirty = nil, true
      child._attachmentVersion = child._attachmentVersion + 1
      self:invalidate()
      if root._onTreeChanged then root._onTreeChanged(child, "removed") end
      return child
    end
  end
  return nil
end

function Container:hitTest(x, y)
  -- The base check enforces all ancestor clips and visibility first.
  local candidate = widget.methods.hitTest(self, x, y)
  if not candidate then return nil end
  -- Disabled containers block the covered area without activating children.
  if self:isEnabled() then
    for index = #self._children, 1, -1 do
      local hit = self._children[index]:hitTest(x, y)
      if hit then return hit end
    end
  end
  return self
end

return container
