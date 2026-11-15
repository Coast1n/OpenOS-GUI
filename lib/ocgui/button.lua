-- Button data and pointer primitive; interaction owns keyboard activation.
local label = require("ocgui.label")
local button = {}
local Button = setmetatable({}, {__index = label.methods})
Button.__index = Button

function button.new(options)
  if options ~= nil and type(options) ~= "table" then error("options must be a table", 2) end
  local copy = {}
  for key, value in pairs(options or {}) do copy[key] = value end
  if copy.focusable == nil then copy.focusable = true end
  local node = label.new(copy)
  node._kind, node._pointerEvents, node._pressed = "button", true, false
  return setmetatable(node, Button)
end

function Button:isPressed() return self._pressed end

function Button:_setPressed(value)
  if self._pressed == value then return end
  self:_assertMutable()
  self._pressed = value
  self:invalidate()
end

function Button:_pointerDown(manager, event)
  if event.button ~= 0 or self._pointerPress then return end
  local press = {}
  if manager:capturePointer(self, event, function()
    if self._pointerPress == press then
      self._pointerPress = nil
      self:_setPressed(false)
    end
  end) then
    self._pointerPress = press
    self:_setPressed(true)
  end
end

return button
