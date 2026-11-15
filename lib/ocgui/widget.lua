-- Pure widget state. Application hooks are internal and are not installed here.
local geometry = require("ocgui.geometry")
local widget = {}
local Widget = {}
Widget.__index = Widget
local instances = setmetatable({}, {__mode = "k"})
local eventNames = {pointer_down = true, pointer_drag = true, pointer_up = true,
  scroll = true, key_down = true, key_up = true, text_paste = true,
  focus = true, blur = true, click = true}

local function boolean(value, name, default)
  if value == nil then return default end
  if type(value) ~= "boolean" then error(name .. " must be a boolean", 3) end
  return value
end

local function copyStyle(value, stack)
  if type(value) ~= "table" then error("style must be a table", 3) end
  stack = stack or {}
  if stack[value] then error("cyclic style table", 3) end
  stack[value] = true
  local result = {}
  for key, member in pairs(value) do
    if type(key) ~= "string" then error("style keys must be strings", 3) end
    local kind = type(member)
    if kind == "table" then
      result[key] = copyStyle(member, stack)
    elseif kind == "string" or kind == "boolean" or (kind == "number"
        and member == member and member ~= math.huge and member ~= -math.huge) then
      result[key] = member
    else
      error("unsupported style value", 3)
    end
  end
  stack[value] = nil
  return result
end

local function bounds(x, y, width, height)
  local rect = geometry.rect(x, y, width, height)
  if rect.width < 1 or rect.height < 1 then error("widget dimensions must be positive", 3) end
  return rect
end

function widget.is(value)
  return type(value) == "table" and instances[value] == true
end

function widget.new(options)
  if options ~= nil and type(options) ~= "table" then error("options must be a table", 2) end
  options = options or {}
  local function option(name, default)
    if options[name] == nil then return default end
    return options[name]
  end
  local object = setmetatable({
    _bounds = bounds(option("x", 1), option("y", 1), option("width", 1), option("height", 1)),
    _visible = boolean(options.visible, "visible", true),
    _enabled = boolean(options.enabled, "enabled", true),
    _focusable = boolean(options.focusable, "focusable", false),
    _style = copyStyle(option("style", {})),
    _dirty = true, _pointerEvents = true, _handlers = {}, _attachmentVersion = 0
  }, Widget)
  instances[object] = true
  return object
end

function Widget:_root()
  local current = self
  while current._parent do current = current._parent end
  return current
end

function Widget:_assertMutable()
  local root = self:_root()
  if root._mutationGuard then root._mutationGuard() end
end

function Widget:_changed(kind)
  self:invalidate()
  local root = self:_root()
  if root._onTreeChanged then root._onTreeChanged(self, kind) end
end

function Widget:invalidate()
  self:_assertMutable()
  local current = self
  while current do current._dirty = true; current = current._parent end
  local root = self:_root()
  if root._onInvalidate then root._onInvalidate() end
  return self
end

function Widget:getParent() return self._parent end

function Widget:on(name, handler)
  if not eventNames[name] then error("unsupported widget event: " .. tostring(name), 2) end
  if type(handler) ~= "function" then error("handler must be a function", 2) end
  self:_assertMutable()
  local list = self._handlers[name] or {}
  self._handlers[name] = list
  local entry = {callback = handler, active = true}
  list[#list + 1] = entry
  return function()
    if not entry.active then return end
    self:_assertMutable()
    entry.active = false
    for index, member in ipairs(list) do
      if member == entry then table.remove(list, index); break end
    end
  end
end

function Widget:_snapshotHandlers(name)
  local result = {}
  for index, entry in ipairs(self._handlers[name] or {}) do result[index] = entry end
  return result
end

function Widget:_emit(event, snapshot, valid)
  for _, entry in ipairs(snapshot or self:_snapshotHandlers(event.type)) do
    if valid and not valid() then break end
    if entry.active and entry.callback(self, event) == true then return true end
  end
  return false
end

function Widget:getBounds()
  local r = self._bounds
  return r.x, r.y, r.width, r.height
end

function Widget:setBounds(x, y, width, height)
  if self._isApplicationRoot then error("application root bounds are managed by the application", 2) end
  local rect = bounds(x, y, width, height)
  local old = self._bounds
  if rect.x == old.x and rect.y == old.y and rect.width == old.width and rect.height == old.height then return self end
  self:_assertMutable()
  self._bounds = rect
  self:_changed("bounds")
  return self
end

local function setFlag(self, name, value)
  if self._isApplicationRoot then error("application root flags are managed by the application", 3) end
  boolean(value, name, nil)
  if value == nil then error(name .. " must be a boolean", 3) end
  local field = "_" .. name
  if self[field] == value then return self end
  self:_assertMutable()
  self[field] = value
  self:_changed(name)
  return self
end

function Widget:setVisible(value) return setFlag(self, "visible", value) end
function Widget:setEnabled(value) return setFlag(self, "enabled", value) end
function Widget:setFocusable(value) return setFlag(self, "focusable", value) end
function Widget:isFocusable() return self._focusable end

function Widget:isVisible()
  local current = self
  while current do
    if not current._visible then return false end
    current = current._parent
  end
  return true
end

function Widget:isEnabled()
  local current = self
  while current do
    if not current._enabled then return false end
    current = current._parent
  end
  return true
end

function Widget:setStyle(value)
  local copy = copyStyle(value)
  self:_assertMutable()
  self._style = copy
  self:_changed("style")
  return self
end

function Widget:getStyle() return copyStyle(self._style) end

local function relative(origin, position)
  -- Avoid overflowing position - 1 at the smallest Lua integer.
  if position == math.mininteger then
    if origin <= 0 then error("coordinate overflow", 3) end
    return position + (origin - 1)
  end
  return geometry.translate(geometry.rect(origin, 0, 0, 0), position - 1, 0).x
end

function Widget:getAbsoluteBounds()
  local x, y, width, height = self:getBounds()
  local current = self._parent
  while current do
    local parent = current._bounds
    x, y = relative(parent.x, x), relative(parent.y, y)
    current = current._parent
  end
  local rect = geometry.rect(x, y, width, height)
  return rect.x, rect.y, rect.width, rect.height
end

function Widget:getClipBounds()
  if not self:isVisible() then return nil end
  local rect = geometry.rect(self:getAbsoluteBounds())
  local parent = self._parent
  while parent and rect do
    rect = geometry.intersect(rect, geometry.rect(parent:getAbsoluteBounds()))
    parent = parent._parent
  end
  return rect
end

function Widget:hitTest(x, y)
  local clip = self:getClipBounds()
  if self._pointerEvents and clip and geometry.contains(clip, x, y) then return self end
end

-- Internal method table shared by Container and future concrete widgets.
widget.methods = Widget
return widget
