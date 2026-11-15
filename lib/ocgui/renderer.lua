local geometry = require("ocgui.geometry")
local text = require("ocgui.text")
local renderer = {}
local Renderer, Context = {}, {}
Renderer.__index, Context.__index = Renderer, Context

local function color(value)
  if type(value) ~= "number" or not math.tointeger(value)
      or value < 0 or value > 0xFFFFFF then
    error("color must be an RGB integer from 0 to 0xFFFFFF", 3)
  end
  return value
end

local function active(self)
  if not self._active then error("drawing context has expired", 3) end
end

local function colors(self, foreground, background)
  if foreground ~= nil and self._foreground ~= foreground then
    self._backend:setForeground(foreground)
    self._foreground = foreground
  end
  if self._background ~= background then
    self._backend:setBackground(background)
    self._background = background
  end
end

function renderer.new(backend, unicode)
  if type(backend) ~= "table" then error("backend must be a table", 2) end
  return setmetatable({_backend = backend, _text = text.new(unicode)}, Renderer)
end

---Run a frame and expire its context even if drawing throws.
function Renderer:frame(draw)
  if type(draw) ~= "function" then error("draw must be a function", 2) end
  if self._drawing then error("frame cannot be reentered", 2) end
  local width, height = self._backend:getSize()
  if width <= 0 or height <= 0 then error("invalid viewport size", 2) end
  local context = setmetatable({
    _active = true, _backend = self._backend, _text = self._text,
    _clips = {geometry.rect(1, 1, width, height)},
    width = width, height = height
  }, Context)
  self._drawing = true
  local ok, reason = pcall(draw, context)
  context._active, self._drawing = false, false
  if not ok then error(reason, 0) end
  if #context._clips ~= 1 then error("unbalanced clip stack", 2) end
  return true
end

---Clip coordinates are screen coordinates; empty clips remain on the stack.
function Context:pushClip(x, y, width, height)
  active(self)
  local rect = geometry.rect(x, y, width, height)
  local parent = self._clips[#self._clips]
  self._clips[#self._clips + 1] = (parent and geometry.intersect(parent, rect)) or false
end

function Context:popClip()
  active(self)
  if #self._clips == 1 then error("cannot pop viewport clip", 2) end
  self._clips[#self._clips] = nil
end

function Context:fillRect(x, y, width, height, background)
  active(self)
  background = color(background)
  local rect = geometry.rect(x, y, width, height)
  local clip = self._clips[#self._clips]
  rect = clip and geometry.intersect(clip, rect)
  if not rect then return end
  colors(self, nil, background)
  self._backend:fill(rect.x, rect.y, rect.width, rect.height, " ")
end

function Context:drawText(x, y, value, foreground, background, width, alignment)
  active(self)
  foreground, background = color(foreground), color(background)
  value = self._text:sanitize(value)
  if width == nil then width = self._text:width(value) end
  local bounds = geometry.rect(x, y, width, 1)
  local fitted = self._text:fit(value, bounds.width, alignment)
  local clip = self._clips[#self._clips]
  local rect = clip and geometry.intersect(clip, bounds)
  if not rect then return end
  local visible = self._text:clip(fitted, rect.x - x + 1, rect.width)
  colors(self, foreground, background)
  self._backend:set(rect.x, rect.y, visible)
end

return renderer
