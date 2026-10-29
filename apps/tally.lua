-- name: Tally
-- icon: +1
-- color: #27AE60

-- Counts anything. Remembers the count and its name on the SD card.

local name = sys.load("name", "Counter")
local n = sys.load("count", 0)

local function drawCount()
  screen.fill(0, 110, 240, 80, color.bg)
  screen.center(tostring(n), 120, 7, color.white)
end

local function draw()
  screen.clear()
  screen.header("Name")
  screen.center(name, 78, 2, color.grey)
  drawCount()
  screen.button(16, 206, 100, 60, "-", color.bar, 4)
  screen.button(124, 206, 100, 60, "+", color.app, 4)
  screen.button(70, 278, 100, 30, "Reset", color.darkgrey, 1)
end

local function set(v)
  n = math.max(0, v)
  sys.save("count", n)
  drawCount()
end

function app.open() draw() end
function app.draw() draw() end   -- redraw after the lock screen or the keyboard

function app.touch(x, y)
  if y >= 24 and y < 64 and x >= 140 then
    sys.keyboard("Rename", "What are you counting?", 18)
  elseif y >= 206 and y < 266 then
    if x < 120 then set(n - 1) else set(n + 1) end
  elseif y >= 278 and y < 308 and x >= 70 and x < 170 then
    set(0)
  end
end

-- What you typed on the keyboard
function app.text(t)
  if #t > 0 then
    name = t
    sys.save("name", name)
  end
  draw()
end
