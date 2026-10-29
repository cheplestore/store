-- name: Marble
-- icon: Mb
-- color: #F2994A

-- Tip the phone to roll the marble into the stars. 45 seconds - how many can you get?
-- Uses sys.tilt() (cOS 4.6).

local X0, Y0, X1, Y1 = 4, 92, 236, 316   -- the table
local R = 9
local mx, my, vx, vy = 120, 200, 0, 0
local sx, sy = 60, 140
local score, best = 0, sys.load("best", 0)
local endsAt, playing, over = 0, false, false
local lastSec = -1
local seed = 7

local function rnd(a, b)
  seed = (seed * 1103515245 + 12345) % 2147483648
  return a + seed % (b - a + 1)
end

local function newStar()
  repeat
    sx, sy = rnd(X0 + 16, X1 - 16), rnd(Y0 + 16, Y1 - 16)
  until (sx - mx) ^ 2 + (sy - my) ^ 2 > 60 * 60
end

local function drawStar(x, y, col)
  screen.triangle(x, y - 9, x - 8, y + 5, x + 8, y + 5, col)
  screen.triangle(x, y + 9, x - 8, y - 4, x + 8, y - 4, col)
end

local function bar()
  screen.fill(0, 64, 240, 26, color.bg)
  screen.text("Stars " .. score, 8, 70, 2, color.yellow, -1)
  local left = playing and math.max(0, (endsAt - sys.millis()) // 1000) or 45
  screen.text(left .. "s", 196, 70, 2, color.white, -1)
end

local function table_()
  screen.fill(0, 90, 240, 230, color.bg)
  screen.round(X0 - 2, Y0 - 2, X1 - X0 + 4, Y1 - Y0 + 4, 8, screen.rgb(30, 60, 40))
end

local function draw()
  screen.clear()
  bar()
  table_()
  if playing then
    drawStar(sx, sy, color.yellow)
    screen.circle(mx, my, R, color.white)
  else
    screen.center(over and ("You got " .. score .. "!") or "Marble", 150, 3, color.white, -1)
    screen.center("Best: " .. best, 190, 2, color.grey, -1)
    screen.button(60, 230, 120, 40, over and "Again" or "Start", color.app, 2)
    screen.center("Tip the phone to roll", 290, 1, color.grey, -1)
  end
end

local function start()
  score, mx, my, vx, vy = 0, 120, 200, 0, 0
  seed = sys.millis() % 100000 + 1
  newStar()
  playing, over = true, false
  endsAt = sys.millis() + 45000
  draw()
end

function app.open() draw() end
function app.draw() draw() end

function app.touch(x, y)
  if not playing and x >= 60 and x < 180 and y >= 230 and y < 270 then start() end
end

function app.update()
  if not playing then return end
  local tx, ty = sys.tilt()
  vx = (vx + tx * 0.03) * 0.97
  vy = (vy + ty * 0.03) * 0.97
  local ox, oy = mx, my
  mx, my = mx + vx, my + vy
  if mx < X0 + R then mx, vx = X0 + R, -vx * 0.5 end
  if mx > X1 - R then mx, vx = X1 - R, -vx * 0.5 end
  if my < Y0 + R then my, vy = Y0 + R, -vy * 0.5 end
  if my > Y1 - R then my, vy = Y1 - R, -vy * 0.5 end
  local ix, iy, iox, ioy = math.floor(mx), math.floor(my), math.floor(ox), math.floor(oy)
  if ix ~= iox or iy ~= ioy then
    screen.circle(iox, ioy, R + 1, screen.rgb(30, 60, 40))
    drawStar(sx, sy, color.yellow)
    screen.circle(ix, iy, R, color.white)
  end
  if (mx - sx) ^ 2 + (my - sy) ^ 2 < (R + 9) ^ 2 then
    score = score + 1
    sys.sound("pop")
    screen.circle(sx, sy, 11, screen.rgb(30, 60, 40))
    newStar()
    drawStar(sx, sy, color.yellow)
    bar()
  end
  local s = (endsAt - sys.millis()) // 1000
  if s ~= lastSec then lastSec = s bar() end
  if sys.millis() >= endsAt then
    playing, over = false, true
    if score > best then best = score sys.save("best", best) end
    sys.sound("notify")
    draw()
  end
end
