-- name: Breakout
-- icon: Bk
-- color: #9B51E0
-- input: raw

-- Slide your finger to move the paddle. Break all the bricks!
-- Shows app.update() for a game that moves 30 times a second.

local W = 240
local ROWS, COLS = 5, 8
local BW, BH, BRICK_TOP = 30, 12, 84
local PAD_W, PAD_H, PAD_Y = 50, 6, 296
local BALL = 5
local rowColors = {color.red, color.orange, color.yellow, color.green, color.cyan}

local bricks = {}
local left = 0
local padX = 95
local bx, by, vx, vy = 0, 0, 0, 0
local score, lives, state = 0, 3, "new"
local best = sys.load("best", 0)

local function brickRect(r, c)
  return (c - 1) * BW + 1, BRICK_TOP + (r - 1) * (BH + 2), BW - 2, BH
end

local function drawBrick(r, c)
  local x, y, w, h = brickRect(r, c)
  screen.fill(x, y, w, h, bricks[r][c] and rowColors[r] or color.black)
end

local function hud()
  screen.fill(0, 64, 240, 16, color.black)
  screen.text("Score " .. score, 4, 68, 1, color.white, color.black)
  screen.text("Best " .. best, 100, 68, 1, color.grey, color.black)
  screen.text("Lives " .. lives, 190, 68, 1, color.white, color.black)
end

local function drawPaddle()
  screen.fill(0, PAD_Y, W, PAD_H, color.black)
  screen.fill(padX, PAD_Y, PAD_W, PAD_H, color.white)
end

local function message(a, b)
  screen.center(a, 190, 2, color.white, color.black)
  screen.center(b, 214, 1, color.grey, color.black)
end

local function clearMessage()
  screen.fill(0, 186, 240, 40, color.black)
end

local function ballOnPaddle()
  bx, by = padX + PAD_W / 2 - BALL / 2, PAD_Y - BALL - 1
  vx, vy = 2.5, -4
end

local function drawAll()
  screen.clear(color.black)
  hud()
  for r = 1, ROWS do
    for c = 1, COLS do drawBrick(r, c) end
  end
  drawPaddle()
  screen.fill(bx, by, BALL, BALL, color.white)
  if state == "ready" then message("Tap to launch", "Slide your finger to move")
  elseif state == "over" then message("Game over", "Tap to play again")
  elseif state == "win" then message("You win!", "Tap to play again") end
end

local function newGame()
  score, lives, state = 0, 3, "ready"
  left = ROWS * COLS
  for r = 1, ROWS do
    bricks[r] = {}
    for c = 1, COLS do bricks[r][c] = true end
  end
  ballOnPaddle()
  drawAll()
end

-- Which brick is at a point (or nil)
local function brickAt(x, y)
  local c = math.floor(x / BW) + 1
  local r = math.floor((y - BRICK_TOP) / (BH + 2)) + 1
  if r >= 1 and r <= ROWS and c >= 1 and c <= COLS and bricks[r][c] then return r, c end
end

local function finish(newState)
  state = newState
  if score > best then
    best = score
    sys.save("best", best)
  end
  hud()
  if newState == "win" then message("You win!", "Tap to play again")
  else message("Game over", "Tap to play again") end
end

function app.open()
  if state == "new" then newGame() else drawAll() end
end

function app.draw() drawAll() end

function app.touch(x, y)
  if state == "ready" and y >= 80 then
    state = "play"
    clearMessage()
  elseif state == "over" or state == "win" then
    newGame()
  end
end

function app.update()
  -- Paddle follows your finger
  local tx = sys.touch()
  if tx then
    local nx = math.max(0, math.min(W - PAD_W, tx - PAD_W // 2))
    if nx ~= padX then
      padX = nx
      drawPaddle()
    end
  end

  if state == "ready" then
    screen.fill(bx, by, BALL, BALL, color.black)
    ballOnPaddle()
    screen.fill(bx, by, BALL, BALL, color.white)
    return
  end
  if state ~= "play" then return end

  -- Move the ball
  local ox, oy = bx, by
  bx, by = bx + vx, by + vy
  if bx < 0 then bx = 0; vx = -vx end
  if bx > W - BALL then bx = W - BALL; vx = -vx end
  if by < 81 then by = 81; vy = -vy end

  -- Paddle bounce (where it hits changes the angle)
  if vy > 0 and by + BALL >= PAD_Y and by + BALL <= PAD_Y + PAD_H + 4 and
     bx + BALL >= padX and bx <= padX + PAD_W then
    local hit = ((bx + BALL / 2) - (padX + PAD_W / 2)) / (PAD_W / 2)
    vx = hit * 4
    if math.abs(vx) < 1 then vx = (vx < 0) and -1 or 1 end
    vy = -math.abs(vy)
    by = PAD_Y - BALL
  end

  -- Bricks
  local r, c = brickAt(bx + BALL / 2, by + BALL / 2)
  if r then
    bricks[r][c] = false
    drawBrick(r, c)
    vy = -vy
    score = score + (ROWS - r + 1) * 10
    left = left - 1
    if left % 10 == 0 then vy = vy * 1.08 end   -- speeds up a little
    hud()
  end

  -- Erase the old ball (fix any brick it was touching), draw the new one
  screen.fill(ox, oy, BALL, BALL, color.black)
  for _, p in ipairs({{ox, oy}, {ox + BALL, oy}, {ox, oy + BALL}, {ox + BALL, oy + BALL}}) do
    local rr, cc = brickAt(p[1], p[2])
    if rr then drawBrick(rr, cc) end
  end
  if oy + BALL >= PAD_Y then drawPaddle() end

  if left == 0 then
    finish("win")
    return
  end

  -- Missed the ball
  if by > 320 then
    lives = lives - 1
    if lives <= 0 then
      finish("over")
      return
    end
    state = "ready"
    ballOnPaddle()
    hud()
    message("Tap to launch", lives .. (lives == 1 and " life" or " lives") .. " left")
    return
  end
  screen.fill(bx, by, BALL, BALL, color.white)
end
