local widget = require("ocgui.widget")
local label = {}
local Label = setmetatable({}, {__index = widget.methods})
Label.__index = Label

local function stringValue(value)
  if type(value) ~= "string" then error("label text must be a string", 3) end
  return value
end

function label.new(options)
  if options ~= nil and type(options) ~= "table" then error("options must be a table", 2) end
  options = options or {}
  local value = options.text
  if value == nil then value = "" end
  stringValue(value)
  local object = widget.new(options)
  object._kind, object._text, object._pointerEvents = "label", value, false
  return setmetatable(object, Label)
end

function Label:getText() return self._text end

function Label:setText(value)
  stringValue(value)
  if value == self._text then return self end
  self:_assertMutable()
  self._text = value
  self:_changed("text")
  return self
end

label.methods = Label
return label
