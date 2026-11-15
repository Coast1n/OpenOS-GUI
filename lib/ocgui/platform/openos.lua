-- All native modules are loaded lazily. services is an internal test seam.
local platform = {}
local Backend = {}
Backend.__index = Backend
local owners = {}

local function fault(code, message)
  error({code = code, message = tostring(message)}, 0)
end

-- OC component proxies expose methods as tables with a __call metamethod.
-- Injected devices may instead use ordinary Lua functions.
local function isCallable(value)
  if type(value) == "function" then return true end
  if type(value) ~= "table" then return false end
  local meta = getmetatable(value)
  return type(meta) == "table" and type(meta.__call) == "function"
end

local function checked(gpu, name, ...)
  if not isCallable(gpu[name]) then fault("device_unavailable", "missing GPU method: " .. name) end
  local result = table.pack(gpu[name](...))
  if result[1] == nil or result[1] == false then
    fault("device_error", name .. ": " .. tostring(result[2] or "operation failed"))
  end
  return table.unpack(result, 1, result.n)
end

local function message(reason)
  return type(reason) == "table" and tostring(reason.message) or tostring(reason)
end

local function sameGPU(a, b)
  return a == b or (type(a) == "table" and type(b) == "table"
    and type(a.address) == "string" and a.address == b.address)
end

function platform.new(options, services)
  if options ~= nil and type(options) ~= "table" then error("options must be a table", 2) end
  options = options or {}
  if options.gpu ~= nil and type(options.gpu) ~= "table" then error("gpu must be a proxy table", 2) end
  if services ~= nil and type(services) ~= "table" then error("services must be a table", 2) end
  return setmetatable({_requestedGPU = options.gpu, _services = services,
    _loaded = {}, _state = "created"}, Backend)
end

function Backend:_service(name)
  if self._loaded[name] == nil then
    if self._services then
      self._loaded[name] = assert(self._services[name], "missing test service: " .. name)
    else
      self._loaded[name] = require(name)
    end
  end
  return self._loaded[name]
end

local function size(gpu)
  local width, height
  if isCallable(gpu.getViewport) then
    width, height = checked(gpu, "getViewport")
  else
    width, height = checked(gpu, "getResolution")
  end
  if type(width) ~= "number" or type(height) ~= "number"
      or not math.tointeger(width) or not math.tointeger(height)
      or width < 1 or height < 1 then
    fault("device_error", "invalid viewport dimensions")
  end
  return width, height
end

function Backend:_ready()
  if self._state ~= "open" then fault("invalid_state", "backend is not open") end
end

function Backend:open()
  if self._state ~= "created" then return nil, {code = "invalid_state", message = "backend cannot reopen"} end
  local ok, reason = pcall(function()
    local term = self:_service("term")
    local terminalGPU = term.gpu()
    local gpu = self._requestedGPU or terminalGPU
    if type(gpu) ~= "table" then fault("device_unavailable", "no GPU available") end
    self._gpu = gpu
    self.screen = checked(gpu, "getScreen")
    if type(self.screen) ~= "string" or self.screen == "" then fault("device_unavailable", "GPU has no screen") end
    local key = gpu.address or gpu
    if owners[key] then fault("device_busy", "GPU is already in use by this library") end
    owners[key], self._key, self._snapshot = self, key, {}
    local snap = self._snapshot
    local getBuffer, setBuffer = isCallable(gpu.getActiveBuffer), isCallable(gpu.setActiveBuffer)
    if getBuffer ~= setBuffer then fault("device_unavailable", "incomplete active buffer API") end
    if getBuffer then
      snap.buffer = checked(gpu, "getActiveBuffer")
      checked(gpu, "setActiveBuffer", 0)
    end
    snap.foreground = table.pack(checked(gpu, "getForeground"))
    snap.background = table.pack(checked(gpu, "getBackground"))
    self._width, self._height = size(gpu)
    snap.width, snap.height = self._width, self._height
    if sameGPU(gpu, terminalGPU) then
      if type(term.getViewport) == "function" then
        local w, h, dx, dy = term.getViewport()
        if w ~= self._width or h ~= self._height or (dx or 0) ~= 0 or (dy or 0) ~= 0 then
          fault("device_unavailable", "only full-screen local terminals are supported")
        end
      end
      snap.cursorX, snap.cursorY = term.getCursor()
      snap.blink = term.getCursorBlink()
      snap.cursor = true
      term.setCursorBlink(false)
    end
    self.unicode = self:_service("unicode")
    self._state = "open"
  end)
  if ok then return true end
  local _, cleanup = self:_cleanup(false)
  local err = type(reason) == "table" and reason or {code = "device_unavailable", message = tostring(reason)}
  if cleanup then err.cleanupErrors = cleanup.cleanupErrors end
  return nil, err
end

---Cleanup each independent item even when a prior operation fails.
function Backend:_cleanup(clear)
  local errors, snap, gpu = {}, self._snapshot, self._gpu
  local function attempt(label, callback)
    local ok, reason = pcall(callback)
    if not ok then errors[#errors + 1] = label .. ": " .. message(reason) end
    return ok
  end
  if snap then
    local screenOK = attempt("screen", function()
      if checked(gpu, "getScreen") ~= self.screen then fault("device_lost", "screen binding changed") end
    end)
    if screenOK and snap.buffer ~= nil then
      screenOK = attempt("select screen buffer", function() checked(gpu, "setActiveBuffer", 0) end)
    end
    if screenOK then
      local fgOK, bgOK = true, true
      if snap.foreground then
        fgOK = attempt("foreground", function()
          checked(gpu, "setForeground", snap.foreground[1], snap.foreground[2] == true)
        end)
      end
      if snap.background then
        bgOK = attempt("background", function()
          checked(gpu, "setBackground", snap.background[1], snap.background[2] == true)
        end)
      end
      if clear and fgOK and bgOK then
        attempt("clear", function()
          local w, h = size(gpu)
          checked(gpu, "fill", 1, 1, math.min(w, self._width), math.min(h, self._height), " ")
        end)
      end
    end
    if snap.buffer ~= nil then
      attempt("active buffer", function() checked(gpu, "setActiveBuffer", snap.buffer) end)
    end
    if snap.cursor then
      local term = self._loaded.term
      local terminalOK = attempt("terminal", function()
        if not sameGPU(gpu, term.gpu()) then fault("device_lost", "terminal GPU changed") end
      end)
      if terminalOK then
        attempt("cursor", function()
          local x, y = snap.cursorX, snap.cursorY
          if term.getViewport then
            local w, h = term.getViewport()
            -- A terminal may have a pending cursor just beyond its last row.
            -- Preserve it exactly unless the viewport actually changed.
            if w ~= snap.width or h ~= snap.height then
              x, y = math.max(1, math.min(x, w)), math.max(1, math.min(y, h))
            end
          end
          term.setCursor(x, y)
        end)
        attempt("blink", function() term.setCursorBlink(snap.blink) end)
      end
    end
  end
  if self._key and owners[self._key] == self then owners[self._key] = nil end
  self._snapshot, self._state = nil, "closed"
  if #errors > 0 then
    return nil, {code = "cleanup_failed", message = "device cleanup incomplete", cleanupErrors = errors}
  end
  return true
end

function Backend:close()
  if self._state == "closed" then return true end
  return self:_cleanup(self._state == "open")
end

function Backend:getSize()
  self:_ready()
  if checked(self._gpu, "getScreen") ~= self.screen then fault("device_lost", "screen binding changed") end
  if self._snapshot.buffer ~= nil and checked(self._gpu, "getActiveBuffer") ~= 0 then
    fault("device_lost", "active buffer changed outside application")
  end
  self._width, self._height = size(self._gpu)
  return self._width, self._height
end

function Backend:getKeyboards()
  self:_ready()
  local addresses, reason = self:_service("component").invoke(self.screen, "getKeyboards")
  if type(addresses) ~= "table" then fault("device_error", reason or "cannot read screen keyboards") end
  local result = {}
  for index, address in ipairs(addresses) do result[index] = address end
  return result
end

function Backend:setForeground(value)
  self:_ready(); return checked(self._gpu, "setForeground", value, false)
end
function Backend:setBackground(value)
  self:_ready(); return checked(self._gpu, "setBackground", value, false)
end
function Backend:fill(x, y, width, height, char)
  self:_ready(); return checked(self._gpu, "fill", x, y, width, height, char)
end
function Backend:set(x, y, value)
  self:_ready(); return checked(self._gpu, "set", x, y, value)
end
function Backend:pull(timeout)
  self:_ready(); return self:_service("event").pull(timeout)
end
function Backend:now()
  self:_ready(); return self:_service("computer").uptime()
end

return platform
