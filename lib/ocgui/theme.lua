-- Private copied style data. No device state or shared mutable defaults.
local theme = {}
local Theme = {}
Theme.__index = Theme
local kinds = {widget = true, container = true, label = true, button = true}
local states = {disabled = true, focused = true, pressed = true}
local defaults = {foreground = 0xFFFFFF, background = 0x000000, alignment = "left",
  disabled = {foreground = 0x777777}, focused = {}, pressed = {}}

local function fields(value, nested)
  if type(value) ~= "table" then error("style must be a table", 3) end
  local copy = {}
  for key, member in pairs(value) do
    if key == "foreground" or key == "background" then
      if type(member) ~= "number" or not math.tointeger(member) or member < 0 or member > 0xFFFFFF then
        error("style colors must be RGB integers", 3)
      end
      copy[key] = member
    elseif key == "alignment" then
      if member ~= "left" and member ~= "center" and member ~= "right" then error("invalid alignment", 3) end
      copy[key] = member
    elseif not nested and states[key] then
      copy[key] = fields(member, true)
    else
      error("unsupported style field: " .. tostring(key), 3)
    end
  end
  return copy
end

function theme.new(options)
  if options == nil then options = {} end
  if type(options) ~= "table" then error("theme must be a table", 2) end
  local copy = {}
  for kind, value in pairs(options) do
    if not kinds[kind] then error("unsupported theme kind: " .. tostring(kind), 2) end
    copy[kind] = fields(value, false)
  end
  return setmetatable({_styles = copy}, Theme)
end

local function apply(result, layer, state)
  if not layer then return end
  for _, key in ipairs({"foreground", "background", "alignment"}) do
    if layer[key] ~= nil then result[key] = layer[key] end
    if state and layer[state] and layer[state][key] ~= nil then result[key] = layer[state][key] end
  end
end

function Theme:resolve(kind, style, state)
  if not kinds[kind] then error("unsupported widget kind", 2) end
  if state ~= nil and not states[state] then error("unsupported widget state", 2) end
  if style == nil then style = {} end
  local localStyle = fields(style, false)
  local result = {}
  apply(result, defaults, state)
  if kind == "button" then
    apply(result, {background = 0x333333, alignment = "center",
      focused = {background = 0x335577}, pressed = {background = 0x557799}}, state)
  end
  apply(result, self._styles.widget, state)
  if kind ~= "widget" then apply(result, self._styles[kind], state) end
  apply(result, localStyle, state)
  return result
end

return theme
