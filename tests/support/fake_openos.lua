-- Stateful fake device. No native device calls are made here.
return function(unicode)
  local state = {screen = "screen-test", buffer = 3, width = 20, height = 10,
    x = 2, y = 3, blink = true, calls = {}, fail = {},
    colors = {[0] = {fg = 2, fp = true, bg = 5, bp = true},
              [3] = {fg = 0xABCDEF, fp = false, bg = 0x123456, bp = false}}}
  local gpu = {address = "gpu-test-" .. tostring(state)}
  local function method(name, callback)
    gpu[name] = function(...)
      state.calls[#state.calls + 1] = {name = name, args = table.pack(...)}
      local mode = state.fail[name]
      if mode then
        if mode == "once" then state.fail[name] = nil end
        if mode == "nil" then return nil, "injected refusal" end
        error("injected " .. name)
      end
      return callback(...)
    end
  end
  method("getScreen", function() return state.screen end)
  method("getActiveBuffer", function() return state.buffer end)
  method("setActiveBuffer", function(index)
    if not state.colors[index] then return nil, "invalid buffer" end
    local old = state.buffer; state.buffer = index; return old
  end)
  method("getForeground", function()
    local c = state.colors[state.buffer]; return c.fg, c.fp
  end)
  method("getBackground", function()
    local c = state.colors[state.buffer]; return c.bg, c.bp
  end)
  method("setForeground", function(value, palette)
    local c = state.colors[state.buffer]; local old = c.fg
    c.fg, c.fp = value, palette; return old
  end)
  method("setBackground", function(value, palette)
    local c = state.colors[state.buffer]; local old = c.bg
    c.bg, c.bp = value, palette; return old
  end)
  method("getViewport", function() return state.width, state.height end)
  method("getResolution", function() return state.width, state.height end)
  method("fill", function() return true end)
  method("set", function() return true end)
  local term = {
    gpu = function() return gpu end,
    getViewport = function() return state.width, state.height, 0, 0 end,
    getCursor = function() return state.x, state.y end,
    setCursor = function(x, y) state.x, state.y = x, y end,
    getCursorBlink = function() return state.blink end,
    setCursorBlink = function(value) state.blink = value end
  }
  local services = {term = term, unicode = unicode,
    component = {invoke = function(address, methodName)
      assert(address == state.screen and methodName == "getKeyboards")
      return {"keyboard-test"}
    end},
    event = {pull = function(timeout) state.timeout = timeout; return "test_signal", nil, 7 end},
    computer = {uptime = function() return 123.5 end}}
  return services, gpu, state
end
