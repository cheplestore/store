-- name: Pong
-- icon: Pg
-- color: #EB5757
-- input: raw

-- Slide your finger along the bottom to move your paddle. First to 7 wins.

local W = 240
local TOP, BOT = 80, 318
local PW, PH = 46, 6
local you, cpu = 97, 97
local bx, by, vx, vy = 120, 200, 2, 3
local sYou, sCpu = 0, 0
local state = "ready"
local wins = sys.load("wins", 0)

local function score()
  screen.fill(0, 64, 240, 16, color.black)
  screen.text("CPU " .. sCpu, 6, 68, 1, color.grey, color.black)
  screen.text("You " .. sYou, 186, 68, 1, color.white, color.black)
  screen.text("Wins " .. wins, 98, 68, 1, color.darkgrey, color.black)
end

local function serve(dir)
  bx, by = 118, 196
  vx = (math.random(2) == 1) and 2 or -2
  vy = 3 * dir
end

local function drawAll()
  screen.clear(color.black)
  score()
  for y = TOP + 4, BOT, 12 do screen.fill(116, y, 8, 2, color.darkgrey) end
  screen.fill(cpu, TOP + 2, PW, PH, color.red)
  screen.fill(you, BOT - PH - 2, PW, PH, color.white)
  if state == "ready" then screen.center("Tap to serve", 190, 2, color.white, color.black) end
  if state == "over" then
    screen.center(sYou > sCpu and "You win!" or "CPU wins", 180, 2, color.white, color.black)
    screen.center("Tap to play again", 206, 1, color.grey, color.black)
  end
end

function app.open() drawAll() end
function app.draw() drawAll() end

function app.touch(x, y)
  if state == "ready" then
    state = "play"
    serve(1)
    drawAll()
  elseif state == "over" then
    sYou, sCpu = 0, 0
    state = "ready"
    drawAll()
  end
end

local function point(youScored)
  if youScored then sYou = sYou + 1 else sCpu = sCpu + 1 end
  sys.sound(youScored and "pop" or "error")
  if sYou >= 7 or sCpu >= 7 then
    state = "over"
    if sYou > sCpu then wins = wins + 1; sys.save("wins", wins) end
  else
    serve(youScored and -1 or 1)
  end
  drawAll()
end

function app.update()
  if state ~= "play" then return end
  -- your paddle follows your finger
  local tx = sys.touch()
  if tx then
    local nx = math.max(0, math.min(W - PW, tx - PW // 2))
    if nx ~= you then
      screen.fill(you, BOT - PH - 2, PW, PH, color.black)
      you = nx
      screen.fill(you, BOT - PH - 2, PW, PH, color.white)
    end
  end
  -- the CPU paddle chases the ball (not perfectly)
  local target = bx - PW // 2
  local step = 2 + math.min(sCpu + sYou, 6) // 3
  local nc = cpu
  if target > cpu + 3 then nc = cpu + step elseif target < cpu - 3 then nc = cpu - step end
  nc = math.max(0, math.min(W - PW, nc))
  if nc ~= cpu then
    screen.fill(cpu, TOP + 2, PW, PH, color.black)
    cpu = nc
    screen.fill(cpu, TOP + 2, PW, PH, color.red)
  end
  -- the ball
  screen.fill(bx, by, 6, 6, color.black)
  if bx > 108 and bx < 126 then screen.fill(116, by - (by - TOP - 4) % 12 + 0, 8, 2, color.darkgrey) end
  bx, by = bx + vx, by + vy
  if bx <= 0 then bx = 0; vx = -vx end
  if bx >= W - 6 then bx = W - 6; vx = -vx end
  if vy < 0 and by <= TOP + 2 + PH and bx + 6 >= cpu and bx <= cpu + PW then
    by = TOP + 2 + PH; vy = -vy
    vx = vx + ((bx + 3) - (cpu + PW / 2)) / 12
  elseif vy > 0 and by + 6 >= BOT - PH - 2 and bx + 6 >= you and bx <= you + PW then
    by = BOT - PH - 8; vy = -vy
    vx = vx + ((bx + 3) - (you + PW / 2)) / 10
    if math.abs(vy) < 7 then vy = vy - 0.25 end   -- a little faster each hit
    sys.sound("tap")
  end
  vx = math.max(-5, math.min(5, vx))
  if by < TOP - 4 then point(true) return end
  if by > BOT then point(false) return end
  screen.fill(bx, by, 6, 6, color.white)
end
