-- name: Hello
-- icon: Hi
-- color: #2D9CDB

-- A tiny app to copy when you make your own.
-- app.open() runs when you open it, app.touch(x, y) when you tap.

local count = 0

local function drawCount()
  screen.fill(0, 124, 240, 64, color.bg)
  screen.center(tostring(count), 130, 6, color.white)
end

local function draw()
  screen.clear()
  screen.center("Hello from the SD card!", 90, 1, color.grey)
  drawCount()
  screen.button(40, 220, 160, 44, "Tap me", color.app, 2)
  screen.center("Swipe left: +10   Swipe right: -10", 290, 1, color.grey)
end

function app.open()
  draw()
end

function app.touch(x, y)
  if x >= 40 and x < 200 and y >= 220 and y < 264 then
    count = count + 1
    drawCount()
  end
end

function app.swipe(dir)
  if dir == "left" then
    count = count + 10
  elseif dir == "right" then
    count = math.max(0, count - 10)
  end
  drawCount()
end
