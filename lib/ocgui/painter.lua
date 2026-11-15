-- Full-frame traversal of built-in widgets. No event loop or native requires.
local widget = require("ocgui.widget")
local geometry = require("ocgui.geometry")
local theme = require("ocgui.theme")
local painter = {}
local Painter = {}
Painter.__index = Painter

function painter.new(root, renderer, options)
  if not widget.is(root) or root:getParent() or type(root._children) ~= "table" then
    error("painter requires an independent root container", 2)
  end
  if type(renderer) ~= "table" or type(renderer.frame) ~= "function" then error("renderer required", 2) end
  return setmetatable({_root = root, _renderer = renderer, _theme = theme.new(options)}, Painter)
end

function Painter:setTheme(options)
  local nextTheme = theme.new(options)
  self._root:_assertMutable()
  self._theme = nextTheme
  self._root:invalidate()
  return self
end

local function kind(node)
  return node._kind or (node._children and "container" or "widget")
end

function Painter:_style(node)
  local state
  if not node:isEnabled() then state = "disabled"
  elseif node._pressed then state = "pressed"
  elseif self._root._interactionOwner and self._root._interactionOwner:getFocus() == node then state = "focused" end
  return self._theme:resolve(kind(node), node._style, state)
end

function Painter:render(force)
  if force ~= nil and type(force) ~= "boolean" then error("force must be a boolean", 2) end
  if self._drawing then error("painting cannot be reentered", 2) end
  local root = self._root
  root:_assertMutable()
  if not force and not root._dirty then return false end
  local oldGuard = root._mutationGuard
  root._mutationGuard = function() error("widgets cannot be changed during painting", 2) end
  self._drawing = true
  local clean = {}
  local ok, err = pcall(function()
    self._renderer:frame(function(context)
      local plan = {}
      local function visit(node, parentClip)
        clean[#clean + 1] = node
        local clip, entry
        if parentClip and node._visible then
          local rect = geometry.rect(node:getAbsoluteBounds())
          clip = geometry.intersect(parentClip, rect)
          if clip then
            entry = {node = node, rect = rect, clip = clip, style = self:_style(node)}
            plan[#plan + 1] = entry
          end
        end
        for _, child in ipairs(node._children or {}) do visit(child, clip) end
      end
      visit(root, geometry.rect(1, 1, context.width, context.height))
      -- Validate the entire visible plan before the first pixel is changed.
      context:fillRect(1, 1, context.width, context.height, self:_style(root).background)
      for _, entry in ipairs(plan) do
        local node, rect, clip, style = entry.node, entry.rect, entry.clip, entry.style
        context:pushClip(clip.x, clip.y, clip.width, clip.height)
        if node ~= root then context:fillRect(rect.x, rect.y, rect.width, rect.height, style.background) end
        if node._kind == "label" or node._kind == "button" then
          context:drawText(rect.x, rect.y, node:getText(), style.foreground, style.background, rect.width, style.alignment)
        end
        context:popClip()
      end
    end)
  end)
  root._mutationGuard, self._drawing = oldGuard, false
  if not ok then root._dirty = true; error(err, 0) end
  for _, node in ipairs(clean) do node._dirty = false end
  return true
end

return painter
