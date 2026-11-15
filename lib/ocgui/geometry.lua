-- Pure rectangle operations. Rectangles use half-open cell boundaries.
local geometry = {}

local function integer(value, name)
  local result = type(value) == "number" and math.tointeger(value)
  if not result then
    error(name .. " must be an integer", 3)
  end
  return result
end

local function add(a, b)
  if (b > 0 and a > math.maxinteger - b)
      or (b < 0 and a < math.mininteger - b) then
    error("coordinate overflow", 3)
  end
  return a + b
end

---Create an independent rectangle; empty internal rectangles are allowed.
function geometry.rect(x, y, width, height)
  x, y = integer(x, "x"), integer(y, "y")
  width, height = integer(width, "width"), integer(height, "height")
  if width < 0 or height < 0 then
    error("rectangle dimensions must be non-negative", 2)
  end
  add(x, width)
  add(y, height)
  return {x = x, y = y, width = width, height = height}
end

local function rectangle(value)
  if type(value) ~= "table" then
    error("rectangle must be a table", 3)
  end
  return geometry.rect(value.x, value.y, value.width, value.height)
end

function geometry.contains(rect, x, y)
  rect = rectangle(rect)
  x, y = integer(x, "x"), integer(y, "y")
  return x >= rect.x and x < rect.x + rect.width
      and y >= rect.y and y < rect.y + rect.height
end

---Return a new intersection or nil; touching edges have no area.
function geometry.intersect(a, b)
  a, b = rectangle(a), rectangle(b)
  local left, top = math.max(a.x, b.x), math.max(a.y, b.y)
  local right = math.min(a.x + a.width, b.x + b.width)
  local bottom = math.min(a.y + a.height, b.y + b.height)
  if left >= right or top >= bottom then
    return nil
  end
  return geometry.rect(left, top, right - left, bottom - top)
end

function geometry.translate(rect, dx, dy)
  rect = rectangle(rect)
  dx, dy = integer(dx, "dx"), integer(dy, "dy")
  return geometry.rect(add(rect.x, dx), add(rect.y, dy), rect.width, rect.height)
end

return geometry
