-- Host-driven or standalone lifecycle. Native services are acquired by open().
local container = require("ocgui.container")
local platform = require("ocgui.platform.openos")
local renderer = require("ocgui.renderer")
local input = require("ocgui.input")
local dispatcher = require("ocgui.dispatcher")
local interaction = require("ocgui.interaction")
local painter = require("ocgui.painter")
local theme = require("ocgui.theme")
local geometry = require("ocgui.geometry")
local application = {}
local Application = {}
local meta = {__index = function(self, key)
  if key == "root" then return self._root end
  return Application[key]
end, __newindex = function(self, key, value)
  if key == "root" then error("application root is read-only", 2) end
  rawset(self, key, value)
end}

local function fault(reason, code)
  local structured = type(reason) == "table" and type(reason.code) == "string"
  return {code = structured and reason.code or code,
    message = structured and tostring(reason.message) or tostring(reason),
    traceback = debug.traceback("", 3), cleanupErrors = structured and reason.cleanupErrors or nil}
end

local function addCleanup(err, label, reason)
  err.cleanupErrors = err.cleanupErrors or {}
  err.cleanupErrors[#err.cleanupErrors + 1] = label .. ": "
    .. (type(reason) == "table" and tostring(reason.message) or tostring(reason))
  if type(reason) == "table" then
    for _, detail in ipairs(reason.cleanupErrors or {}) do err.cleanupErrors[#err.cleanupErrors + 1] = detail end
  end
end

local function maximum(value)
  if value ~= nil and (type(value) ~= "number" or value ~= value or value < 0 or value == math.huge) then
    error("maximum wait must be finite and non-negative", 3)
  end
end

function application.new(options, services)
  if options == nil then options = {} end
  if type(options) ~= "table" then error("application options must be a table", 2) end
  for key in pairs(options) do
    if key ~= "gpu" and key ~= "theme" then error("unsupported application option: " .. tostring(key), 2) end
  end
  local root = container.new()
  root._isApplicationRoot = true
  return setmetatable({_root = root, _state = "created", _stopped = false,
    _theme = theme.new(options.theme), _device = platform.new({gpu = options.gpu}, services)}, meta)
end

function Application:isActive() return self._state == "open" and not self._stopped end

function Application:_resize(width, height)
  local _, _, oldWidth, oldHeight = self._root:getBounds()
  if width == oldWidth and height == oldHeight then return end
  if self._interaction then self._interaction:cancelAll("screen_resized") end
  self._root._bounds = geometry.rect(1, 1, width, height)
  self._root:invalidate()
end

function Application:_cleanup()
  local err = {code = "cleanup_failed", message = "application cleanup incomplete"}
  if self._interaction then
    local ok, reason = pcall(self._interaction.close, self._interaction)
    if not ok then addCleanup(err, "interaction", reason) end
  end
  local ok, closed, reason = pcall(self._device.close, self._device)
  if not ok or not closed then addCleanup(err, "device", ok and reason or closed) end
  self._state, self._stopped = "closed", true
  if err.cleanupErrors then return nil, err end
  return true
end

function Application:open()
  if self._state ~= "created" or self._busy then return nil, fault("application cannot open", "invalid_state") end
  self._busy = "open"
  local ok, reason = pcall(function()
    local opened, err = self._device:open()
    if not opened then error(err, 0) end
    self:_resize(self._device:getSize())
    self._input = input.new(self._device.screen, self._device:getKeyboards())
    self._dispatcher = dispatcher.new(self._root)
    self._interaction = interaction.new(self._root, self._dispatcher, function() return self._device:now() end)
    self._painter = painter.new(self._root, renderer.new(self._device, self._device.unicode), self._theme._styles)
  end)
  if ok then self._state, self._busy = "open", nil; return true end
  local err = fault(reason, "device_unavailable")
  local cleaned, cleanup = self:_cleanup()
  self._busy = nil
  if not cleaned then addCleanup(err, "open rollback", cleanup) end
  return nil, err
end

function Application:_call(code, fn)
  if self._state ~= "open" or self._busy then return nil, fault("application is not available for this operation", "invalid_state") end
  if self._error then return nil, self._error end
  self._busy = code
  local ok, value = pcall(fn)
  self._busy = nil
  if ok then return value end
  return self:_fail(value, code)
end

function Application:_fail(reason, code)
  local err = fault(reason, code)
  self._stopped = true
  local cancelled, reason = pcall(self._interaction.cancelAll, self._interaction, "operation_failed")
  if not cancelled then addCleanup(err, "interaction cancellation", reason) end
  self._error = err
  return nil, err
end

function Application:step(timeout)
  maximum(timeout)
  if self._state ~= "open" or self._busy or self._stepping then
    return nil, fault("application cannot step during this operation", "invalid_state")
  end
  self._stepping = true
  local ok, active, err = pcall(function()
    if self._error then return nil, self._error end
    if not self:isActive() then return false end
    -- Expire old interactions without consuming a signal before deciding to wait.
    local _, dispatchErr = self:dispatch()
    if dispatchErr then return nil, dispatchErr end
    if not self:isActive() then return false end
    if self._root._dirty then
      local drawn, drawErr = self:render()
      if not drawn then return nil, drawErr end
      return self:isActive()
    end
    local wait, waitErr = self:nextTimeout(timeout)
    if waitErr then return nil, waitErr end
    local raw, pullErr = self:_call("event_failed", function() return table.pack(self._device:pull(wait)) end)
    if not raw then return nil, pullErr end
    if not self:isActive() then return false end
    local _, inputErr = self:dispatch(table.unpack(raw, 1, raw.n))
    if inputErr then return nil, inputErr end
    if not self:isActive() then return false end
    local drawn, drawErr = self:render()
    if not drawn then return nil, drawErr end
    return self:isActive()
  end)
  self._stepping = false
  if not ok then return self:_fail(active, "event_failed") end
  return active, err
end

function Application:run()
  if self._state ~= "created" or self._busy or self._looping or self._stepping then
    return nil, fault("run requires a newly created application", "invalid_state")
  end
  self._looping = true
  local ok, success, err = pcall(function()
    local opened, openErr = self:open()
    if not opened then return nil, openErr end
    while self:isActive() do
      local active, stepErr = self:step()
      if active == nil then return nil, stepErr end
      if not active then break end
    end
    return true
  end)
  self._looping = false
  local primary = not ok and fault(success, "event_failed") or (not success and err or nil)
  local closed, closeErr = self:close()
  if not closed then
    if primary then addCleanup(primary, "run close", closeErr) else primary = closeErr end
  end
  if primary then return nil, primary end
  return true
end

function Application:render()
  return self:_call("render_failed", function()
    if self._stopped then return true end
    self:_resize(self._device:getSize())
    self._painter:render()
    return true
  end)
end

function Application:dispatch(...)
  local raw = table.pack(...)
  return self:_call("callback_failed", function()
    if self._stopped then return false end
    local width, height = self._device:getSize()
    self:_resize(width, height)
    local name = raw[1]
    if name == "component_removed" and type(raw[2]) == "string"
        and (raw[2] == self._device.screen or raw[2] == self._device._gpu.address) then
      error({code = "device_lost", message = "application display device removed"}, 0)
    end
    if name == "component_added" or name == "component_removed" then
      if raw[3] == "keyboard" or self._input._keyboards[raw[2]] then
        self._interaction:cancelAll("keyboards_changed")
      end
      self._input:setKeyboards(self._device:getKeyboards())
    end
    local event = self._input:normalize(table.unpack(raw, 1, raw.n))
    if event and event.type == "interrupted" then self:stop(); return false end
    return self._interaction:route(event)
  end)
end

function Application:nextTimeout(maxWait)
  maximum(maxWait)
  if self._state ~= "open" or self._stopped then return 0 end
  return self:_call("device_error", function()
    if self._root._dirty then return 0 end
    local pending = self._interaction._capture or self._interaction._activation
    if not pending then return maxWait end
    local remaining = math.max(0, pending.deadline - self._interaction:_now())
    return maxWait and math.min(maxWait, remaining) or remaining
  end)
end

function Application:stop()
  if self._state ~= "open" then error("application is not open", 2) end
  self._root:_assertMutable()
  if self._stopped then return end
  self._stopped = true
  self._interaction:cancelAll("stopped")
end

function Application:setFocus(node)
  if not self:isActive() then error("focus requires an active application", 2) end
  self._interaction:setFocus(node)
end

function Application:setTheme(options)
  if self._state == "closed" then error("application is closed", 2) end
  local nextTheme = theme.new(options)
  self._root:_assertMutable()
  if self._painter then self._painter:setTheme(nextTheme._styles) else self._root:invalidate() end
  self._theme = nextTheme
end

function Application:close()
  if self._busy or self._stepping then return nil, fault("cannot close during an application operation; use stop in callbacks", "invalid_state") end
  if self._state == "closed" then return true end
  self._busy = "close"
  local ok, err = self:_cleanup()
  self._busy = nil
  return ok, err
end

return application
