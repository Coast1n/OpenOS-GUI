-- Pure focus and pointer ownership. Callers supply normalized input and a clock.
local widget = require("ocgui.widget")
local input = require("ocgui.input")
local interaction = {}
local Interaction = {}
Interaction.__index = Interaction

function interaction.new(root, dispatch, clock)
  if not widget.is(root) or root:getParent() or type(root._children) ~= "table"
      or type(dispatch) ~= "table" or dispatch._root ~= root then
    error("interaction requires a root and its dispatcher", 2)
  end
  if type(clock) ~= "function" then error("clock must be a function", 2) end
  if root._interactionOwner then error("root already has an interaction manager", 2) end
  local self = setmetatable({_root = root, _dispatcher = dispatch, _clock = clock,
    _keys = {}, _notificationVersion = 0, _oldHook = root._onTreeChanged}, Interaction)
  self._hook = function(node, kind)
    if self._oldHook then self._oldHook(node, kind) end
    self:reconcile()
  end
  root._interactionOwner, root._onTreeChanged = self, self._hook
  return self
end

function Interaction:_open()
  if self._closed then error("interaction manager is closed", 3) end
end

function Interaction:_eligible(node, focusable)
  return widget.is(node) and node:_root() == self._root and node:isVisible()
    and node:isEnabled() and (not focusable or node:isFocusable())
end

function Interaction:_now()
  local now = self._clock()
  if type(now) ~= "number" or now ~= now or now < 0 or now == math.huge
      or (self._lastNow and now < self._lastNow) then error("clock must be finite and monotonic", 3) end
  self._lastNow = now
  return now
end

function Interaction:getFocus() return self._focus end
function Interaction:getCapture() return self._capture and self._capture.node end

function Interaction:_notify(node, kind, related)
  local version = self._notificationVersion
  local event = {type = kind, target = node, currentTarget = node, relatedTarget = related, raw = table.pack()}
  node:_emit(event, node:_snapshotHandlers(kind), function()
    return not self._closed and version == self._notificationVersion
      and (kind == "blur" or (self._focus == node and self:_eligible(node, true)))
  end)
end

function Interaction:setFocus(node)
  self:_open(); self._root:_assertMutable()
  if self._cancelling and node ~= nil then return false end
  if node ~= nil and not self:_eligible(node, true) then error("focus target is not eligible", 2) end
  self._pendingFocus = {node = node}
  if self._changingFocus then return end
  self._changingFocus = true
  local ok, err = pcall(function()
    local transitions = 0
    while self._pendingFocus do
      transitions = transitions + 1
      if transitions > 32 then error("focus transition cycle", 0) end
      local nextFocus = self._pendingFocus.node
      self._pendingFocus = nil
      if nextFocus and not self:_eligible(nextFocus, true) then nextFocus = nil end
      local old = self._focus
      if old ~= nextFocus then
        local version = self._notificationVersion
        self:_cancelActivation()
        self._focus = nil
        if old then old:invalidate(); self:_notify(old, "blur", nextFocus) end
        if not self._closed and version == self._notificationVersion and not self._pendingFocus
            and nextFocus and self:_eligible(nextFocus, true) then
          self._focus = nextFocus
          nextFocus:invalidate(); self:_notify(nextFocus, "focus", old)
        end
        if self._focus and not self:_eligible(self._focus, true) then
          self._pendingFocus = self._pendingFocus or {node = nil}
        end
      end
    end
  end)
  self._changingFocus, self._pendingFocus = false, nil
  if not ok then self._focus = nil; error(err, 0) end
end

function Interaction:focusNext(reverse)
  self:_open()
  if reverse ~= nil and type(reverse) ~= "boolean" then error("reverse must be a boolean", 2) end
  local candidates = {}
  local function visit(node)
    if not node:isVisible() or not node:isEnabled() then return end
    if node:isFocusable() then candidates[#candidates + 1] = node end
    for _, child in ipairs(node._children or {}) do visit(child) end
  end
  visit(self._root)
  local index
  for i, node in ipairs(candidates) do if node == self._focus then index = i; break end end
  local nextFocus
  if #candidates > 0 then
    if not index then index = reverse and #candidates or 1
    else index = ((index - 1 + (reverse and -1 or 1)) % #candidates) + 1 end
    nextFocus = candidates[index]
  end
  self:setFocus(nextFocus)
  return self._focus
end

function Interaction:_captureValid(capture)
  if not self:_eligible(capture.node, false) then return false end
  for _, part in ipairs(capture.path) do
    if part.node:getParent() ~= part.parent or part.node._attachmentVersion ~= part.version then return false end
  end
  return true
end

function Interaction:capturePointer(node, event, onFinish)
  self:_open(); self._root:_assertMutable()
  if self._cancelling or self._finishingCapture then return false end
  if not self:_eligible(node, false) then error("capture target is not eligible", 2) end
  if type(event) ~= "table" or event.type ~= "pointer_down" or type(event.source) ~= "string"
      or event.source == "" or type(event.button) ~= "number" or not math.tointeger(event.button)
      or event.button < 0 or (event.player ~= nil and type(event.player) ~= "string") then
    error("capture requires a normalized pointer-down event", 2)
  end
  if onFinish ~= nil and type(onFinish) ~= "function" then error("onFinish must be a function", 2) end
  self:expire()
  self:_open()
  if not self:_eligible(node, false) then error("capture target is no longer eligible", 2) end
  if self._capture or self._activation then return false end
  local path, current = {}, node
  while current do
    path[#path + 1] = {node = current, parent = current:getParent(), version = current._attachmentVersion}
    current = current:getParent()
  end
  self._capture = {node = node, source = event.source, button = event.button, player = event.player,
    deadline = self:_now() + 5, path = path, onFinish = onFinish}
  return true
end

function Interaction:cancelCapture(reason)
  local capture = self._capture
  self._capture = nil
  if capture and capture.onFinish then
    self._finishingCapture = true
    local ok, err = pcall(capture.onFinish, capture.node, reason or "cancelled")
    self._finishingCapture = false
    if not ok then error(err, 0) end
  end
end

function Interaction:_cancelActivation()
  local activation = self._activation
  self._activation = nil
  if activation then activation.node:_setPressed(false) end
end

function Interaction:reconcile()
  if self._closed or self._reconciling then return end
  self._reconciling = true
  local ok, err = pcall(function()
    if self._focus and not self:_eligible(self._focus, true) then self:setFocus(nil) end
    if self._capture and not self:_captureValid(self._capture) then self:cancelCapture("invalidated") end
    if self._activation and (self._focus ~= self._activation.node or not self:_captureValid(self._activation)) then
      self:_cancelActivation()
    end
  end)
  self._reconciling = false
  if not ok then error(err, 0) end
end

function Interaction:expire()
  self:_open(); self:reconcile()
  local expired = false
  if self._capture or self._activation then
    local now = self:_now()
    if self._capture and now >= self._capture.deadline then self:cancelCapture("timeout"); expired = true end
    if self._activation and now >= self._activation.deadline then self:_cancelActivation(); expired = true end
  end
  return expired
end

function Interaction:nextTimeout(maxWait)
  self:_open()
  if maxWait ~= nil and (type(maxWait) ~= "number" or maxWait ~= maxWait
      or maxWait < 0 or maxWait == math.huge) then error("maxWait must be finite and non-negative", 2) end
  self:expire()
  local pending = self._capture or self._activation
  if not pending then return maxWait end
  local remaining = math.max(0, pending.deadline - self._lastNow)
  return maxWait and math.min(maxWait, remaining) or remaining
end

function Interaction:cancelAll(reason)
  self._dispatcher:cancel()
  self._notificationVersion = self._notificationVersion + 1
  self._cancelling, self._keys, self._pendingFocus = true, {}, nil
  local old = self._focus
  self._focus = nil
  local ok, err = pcall(function() self:cancelCapture(reason or "cancelled") end)
  local keyOK, keyErr = pcall(self._cancelActivation, self)
  local invalidated, invalidateErr = pcall(function() if old then old:invalidate() end end)
  self._cancelling = false
  if not ok then error(err, 0) end
  if not keyOK then error(keyErr, 0) end
  if not invalidated then error(invalidateErr, 0) end
end

function Interaction:close()
  if self._closed then return true end
  local ok, err = pcall(function() self:cancelAll("closed") end)
  if self._root._onTreeChanged == self._hook then self._root._onTreeChanged = self._oldHook end
  if self._root._interactionOwner == self then self._root._interactionOwner = nil end
  self._closed, self._focus, self._capture, self._keys = true, nil, nil, {}
  self._activation = nil
  if not ok then error(err, 0) end
  return true
end

local function matches(capture, event)
  return event.source == capture.source and event.player == capture.player and event.button == capture.button
end

-- Built-in pointer defaults run before user callbacks; click is a later dispatch.
function Interaction:_pointerSend(target, event, capture)
  local isButton = target and target._kind == "button"
  local press, version = isButton and target._pointerPress, self._notificationVersion
  local inside = isButton and self._root:hitTest(event.screenX, event.screenY) == target
  local clicked = capture and isButton and press and event.type == "pointer_up" and inside
  local ok, consumed, cancelled = pcall(function()
    if isButton then
      if event.type == "pointer_down" then target:_pointerDown(self, event)
      elseif press and event.type == "pointer_drag" then target:_setPressed(inside)
      elseif press and event.type == "pointer_up" then target:_setPressed(false) end
    end
    return self._dispatcher:dispatch(target, event)
  end)
  local active = capture and self._capture == capture and self:_captureValid(capture)
  local released, releaseErr = true, nil
  if event.type == "pointer_up" and capture and self._capture == capture then
    released, releaseErr = pcall(self.cancelCapture, self, "released")
  elseif not ok and isButton and self._capture and self._capture.node == target then
    -- Do not leave an invisible held button after a failing input callback.
    pcall(self.cancelCapture, self, "callback_failed")
  end
  if not ok then error(consumed, 0) end
  if not released then error(releaseErr, 0) end
  if clicked and active and not cancelled and not self._closed
      and version == self._notificationVersion and self:_eligible(target, false)
      and self._root:hitTest(event.screenX, event.screenY) == target then
    local click = {}
    for key, value in pairs(event) do click[key] = value end
    click.type = "click"
    return self._dispatcher:dispatch(target, click) or consumed
  end
  return consumed
end

function Interaction:_keySend(target, event)
  local activation = self._activation
  local release = activation and event.type == "key_up" and event.source == activation.source
    and event.player == activation.player and event.code == activation.code
  local version = self._notificationVersion
  local ok, consumed, cancelled = pcall(function()
    if event.type == "key_down" and not event.repeated and (event.code == 28 or event.code == 57)
        and target and target._kind == "button" and not self._capture and not activation then
      local path, current = {}, target
      while current do
        path[#path + 1] = {node = current, parent = current:getParent(), version = current._attachmentVersion}
        current = current:getParent()
      end
      self._activation = {node = target, source = event.source, player = event.player, code = event.code,
        deadline = self:_now() + 5, path = path}
      target:_setPressed(true)
    elseif release then
      activation.node:_setPressed(false)
    end
    return self._dispatcher:dispatch(target, event)
  end)
  local active = release and self._activation == activation and self._focus == activation.node
    and self:_captureValid(activation)
  if release or not ok then
    local cleaned, cleanErr = pcall(self._cancelActivation, self)
    if not ok then error(consumed, 0) end
    if not cleaned then error(cleanErr, 0) end
  end
  if active and not cancelled and not self._closed and version == self._notificationVersion
      and self._focus == activation.node and self:_captureValid(activation) then
    local click = {}
    for key, value in pairs(event) do click[key] = value end
    click.type = "click"
    return self._dispatcher:dispatch(activation.node, click) or consumed
  end
  return consumed
end

function Interaction:route(event)
  self:_open()
  if self._routing then error("interaction routing cannot be reentered", 2) end
  if event ~= nil and (type(event) ~= "table" or type(event.type) ~= "string") then error("expected normalized event", 2) end
  self._routing = true
  local ok, result = pcall(function()
    self:expire()
    if self._closed then return false end
    if event == nil then return false end
    if event.type == "interrupted" or event.type == "screen_resized" then
      self:cancelAll(event.type); return false
    end
    if input.isPointer(event.type) then
      local capture = self._capture
      if capture then
        if not matches(capture, event) or (event.type ~= "pointer_drag" and event.type ~= "pointer_up") then return false end
        if event.type == "pointer_up" then
          return self:_pointerSend(capture.node, event, capture)
        end
        capture.deadline = self:_now() + 5
        return self:_pointerSend(capture.node, event, capture)
      end
      if event.type == "pointer_down" then
        local target = self._root:hitTest(event.screenX, event.screenY)
        if not self:_eligible(target, false) then return false end
        if event.button == 0 then
          self:_cancelActivation()
          self:setFocus(target:isFocusable() and target or nil)
        end
        if self._closed then return false end
        if self._root:hitTest(event.screenX, event.screenY) ~= target then return false end
        return self:_pointerSend(target, event)
      end
      return self._dispatcher:dispatchPointer(event)
    end
    if event.type == "key_down" or event.type == "key_up" then
      local keys = self._keys[event.source] or {}
      self._keys[event.source] = keys
      local repeated = keys[event.code] == true
      keys[event.code] = event.type == "key_down" and true or nil
      if event.code == 15 then
        if event.type == "key_down" and not repeated then
          self:_cancelActivation()
          self:focusNext(keys[42] or keys[54] or false)
        end
        return true
      end
      local routed = {}
      for key, value in pairs(event) do routed[key] = value end
      routed.repeated = event.type == "key_down" and repeated or false
      return self:_keySend(self._focus, routed)
    end
    if event.type == "text_paste" then return self._dispatcher:dispatch(self._focus, event) end
    return false
  end)
  self._routing = false
  if not ok then error(result, 0) end
  return result
end

return interaction
