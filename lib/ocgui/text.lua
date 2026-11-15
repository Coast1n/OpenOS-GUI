-- Unicode is injected: loading this module never acquires OpenOS devices.
local text = {}
local methods = {}
methods.__index = methods

local function integer(value, name, minimum)
  local result = type(value) == "number" and math.tointeger(value)
  if not result or result < minimum then
    error(name .. " must be an integer >= " .. minimum, 3)
  end
  return result
end

local function clean(value)
  if type(value) ~= "string" then
    error("text must be a string", 3)
  end
  -- Replace ASCII controls individually, including CR, LF, TAB and NUL.
  return (value:gsub("[%z\1-\31\127]", " "))
end

local function charWidth(unicode, char)
  local width = unicode.charWidth(char)
  if type(width) ~= "number" or not math.tointeger(width) then
    error("unicode.charWidth must return an integer", 3)
  end
  -- Match the locked native OC wlen implementation's minimum width of 1.
  return math.max(1, width)
end

function text.new(unicode)
  if type(unicode) ~= "table" then
    error("unicode interface must be a table", 2)
  end
  for _, name in ipairs({"len", "sub", "charWidth"}) do
    if type(unicode[name]) ~= "function" then
      error("unicode." .. name .. " must be a function", 2)
    end
  end
  return setmetatable({_unicode = unicode}, methods)
end

function methods:sanitize(value)
  return clean(value)
end

function methods:width(value)
  value = clean(value)
  local unicode, width = self._unicode, 0
  for index = 1, unicode.len(value) do
    width = width + charWidth(unicode, unicode.sub(value, index, index))
  end
  return width
end

---Return exactly count display cells starting at firstCell (one-based).
---Partial wide characters and space beyond the text become ASCII spaces.
function methods:clip(value, firstCell, count)
  value = clean(value)
  firstCell = integer(firstCell, "firstCell", 1)
  count = integer(count, "count", 0)
  if count == 0 then return "" end
  if firstCell > math.maxinteger - count then
    error("clip interval overflow", 2)
  end
  local limit = firstCell + count
  local unicode, parts, written, position = self._unicode, {}, 0, 1
  for index = 1, unicode.len(value) do
    local char = unicode.sub(value, index, index)
    local nextPosition = position + charWidth(unicode, char)
    local left = math.max(position, firstCell)
    local right = math.min(nextPosition, limit)
    if left < right then
      local cells = right - left
      if position >= firstCell and nextPosition <= limit then
        parts[#parts + 1] = char
      else
        parts[#parts + 1] = string.rep(" ", cells)
      end
      written = written + cells
    end
    position = nextPosition
    if position >= limit then break end
  end
  parts[#parts + 1] = string.rep(" ", count - written)
  return table.concat(parts)
end

---Overflow truncates on the right regardless of alignment.
function methods:fit(value, count, alignment)
  value = clean(value)
  count = integer(count, "count", 0)
  if alignment == nil then alignment = "left" end
  if alignment ~= "left" and alignment ~= "center" and alignment ~= "right" then
    error("alignment must be left, center or right", 2)
  end
  local width = self:width(value)
  if width >= count then
    return self:clip(value, 1, count)
  end
  local spare, left = count - width, 0
  if alignment == "right" then
    left = spare
  elseif alignment == "center" then
    left = math.floor(spare / 2)
  end
  return string.rep(" ", left) .. value .. string.rep(" ", spare - left)
end

return text
