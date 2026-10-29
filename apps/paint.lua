-- name: Paint
-- icon: Pt
-- color: #EB5757
-- input: raw

-- Draw with your finger. "input: raw" means touches arrive right away,
-- and sys.touch() says where the finger is while it's down.

local colors = {color.white, color.red, color.orange, color.yellow,
                color.green, color.cyan, color.blue, color.purple}
local cur = 1
local sizes = {2, 4, 8}
local sizeIdx = 2
local lastX, lastY = nil, nil
local CANVAS_TOP, CANVAS_BOTTOM = 64, 284

local function palette()
  screen.fill(0, 284, 240, 36, color.bar)
  for i, c in ipairs(colors) do
    local x = (i - 1) * 24 + 4
    screen.round(x, 290, 20, 26, 5, c)
    if i == cur then screen.round(x - 2, 288, 24, 30, 6, color.white, true) end
  end
  screen.button(198, 290, 38, 26, "Clear", color.darkgrey, 1)
end

local function draw()
  screen.header("Size " .. sizeIdx)
  screen.clear(color.black)
  palette()
end

function app.open() draw() end
function app.draw() draw() end

local function dot(x, y)
  local r = sizes[sizeIdx]
  if y - r < CANVAS_TOP or y + r >= CANVAS_BOTTOM then return end
  screen.circle(x, y, r, colors[cur])
end

-- A finger just landed
function app.touch(x, y)
  lastX = nil
  if y >= 24 and y < 64 then          -- header button: brush size
    sizeIdx = sizeIdx % #sizes + 1
    screen.header("Size " .. sizeIdx)
  elseif y >= 286 then                -- palette
    if x >= 196 then
      screen.fill(0, CANVAS_TOP, 240, CANVAS_BOTTOM - CANVAS_TOP, color.black)
    else
      local i = x // 24 + 1
      if i >= 1 and i <= #colors then cur = i; palette() end
    end
  else
    dot(x, y)
    lastX, lastY = x, y
  end
end

function app.release()
  lastX = nil
end

-- About 30 times a second: connect the dots while the finger moves
function app.update()
  if not lastX then return end
  local x, y = sys.touch()
  if not x then return end
  local dx, dy = x - lastX, y - lastY
  local steps = math.max(math.abs(dx), math.abs(dy)) // 2 + 1
  for i = 1, steps do
    dot(lastX + dx * i // steps, lastY + dy * i // steps)
  end
  lastX, lastY = x, y
end
