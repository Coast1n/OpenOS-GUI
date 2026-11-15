-- Normalize supplied signals; this module never consumes the event queue.
local input = {}
local Input = {}
Input.__index = Input
local pointerNames = {touch = "pointer_down", drag = "pointer_drag", drop = "pointer_up", scroll = "scroll"}
local pointerTypes = {pointer_down = true, pointer_drag = true, pointer_up = true, scroll = true}
local function integer(value, minimum)
  return type(value) == "number" and math.tointeger(value) ~= nil and value >= minimum
end
local function coordinate(value)
  if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return nil end
  return math.tointeger(math.ceil(value))
end
local function player(value) return value == nil or type(value) == "string" end

function input.isPointer(name) return pointerTypes[name] == true end

function input.new(screen, keyboards)
  if type(screen) ~= "string" or screen == "" then error("screen must be an address string", 2) end
  local object = setmetatable({_screen = screen}, Input)
  object:setKeyboards(keyboards == nil and {} or keyboards)
  return object
end

function Input:setKeyboards(addresses)
  if type(addresses) ~= "table" then error("keyboards must be an address array", 2) end
  local copy, count = {}, 0
  for index, address in pairs(addresses) do
    if not integer(index, 1) or type(address) ~= "string" or address == "" then
      error("keyboards must be an address array", 2)
    end
    count = count + 1
    copy[address] = true
  end
  for index = 1, count do
    if addresses[index] == nil then error("keyboards must not contain holes", 2) end
  end
  self._keyboards = copy
  return self
end

function Input:normalize(...)
  local raw = table.pack(...)
  local name, source = raw[1], raw[2]
  local kind = pointerNames[name]
  if kind then
    if source ~= self._screen or not player(raw[6]) then return nil end
    local x, y = coordinate(raw[3]), coordinate(raw[4])
    if not x or not y then return nil end
    local event = {type = kind, source = source, screenX = x, screenY = y, player = raw[6], raw = raw}
    if name == "scroll" then
      if not integer(raw[5], math.mininteger) then return nil end
      event.delta = raw[5]
    else
      if not integer(raw[5], 0) then return nil end
      event.button = raw[5]
    end
    return event
  elseif name == "key_down" or name == "key_up" then
    if not self._keyboards[source] or not integer(raw[3], 0) or not integer(raw[4], 0)
        or not player(raw[5]) then return nil end
    return {type = name, source = source, char = raw[3], code = raw[4], player = raw[5], raw = raw}
  elseif name == "clipboard" then
    if not self._keyboards[source] or type(raw[3]) ~= "string" or not player(raw[4]) then return nil end
    return {type = "text_paste", source = source, text = raw[3], player = raw[4], raw = raw}
  elseif name == "screen_resized" then
    if source ~= self._screen or not integer(raw[3], 1) or not integer(raw[4], 1) then return nil end
    return {type = name, source = source, width = raw[3], height = raw[4], raw = raw}
  elseif name == "interrupted" then
    return {type = name, raw = raw}
  end
  return nil
end

return input
