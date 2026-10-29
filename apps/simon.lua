-- name: Simon
-- icon: Sm
-- color: #27AE60

-- Watch the colours light up, then tap them in the same order. Each round adds one more.

local pads = {
  {x = 12,  y = 76,  c = screen.rgb(0, 140, 60),  lit = screen.rgb(80, 255, 140)},   -- green
  {x = 124, y = 76,  c = screen.rgb(160, 20, 20), lit = screen.rgb(255, 90, 90)},    -- red
  {x = 12,  y = 188, c = screen.rgb(170, 150, 0), lit = screen.rgb(255, 240, 80)},   -- yellow
  {x = 124, y = 188, c = screen.rgb(20, 60, 170), lit = screen.rgb(90, 160, 255)},   -- blue
}
local PW, PH = 104, 104
local seq, pos = {}, 1
local state = "start"        -- start, show, play, over
local showAt, showIdx, showOn = 0, 1, false
local best = sys.load("best", 0)

local function pad(i, on)
  local p = pads[i]
  screen.round(p.x, p.y, PW, PH, 14, on and p.lit or p.c)
end

local function status(t, col)
  screen.fill(0, 296, 240, 24, color.bg)
  screen.center(t, 302, 1, col or color.grey)
end

local function drawAll()
  screen.clear()
  for i = 1, 4 do pad(i, false) end
  if state == "start" then status("Tap to start   (best: " .. best .. ")", color.white)
  elseif state == "over" then status("Wrong! Score " .. (#seq - 1) .. "  Best " .. best .. "  - tap", color.red)
  elseif state == "play" then status("Your turn: " .. (pos - 1) .. " / " .. #seq, color.white)
  else status("Watch...", color.grey) end
end

local function nextRound()
  seq[#seq + 1] = math.random(4)
  pos = 1
  state = "show"
  showIdx, showOn = 1, false
  showAt = sys.millis() + 600
  drawAll()
end

local function newGame()
  seq = {}
  nextRound()
end

function app.open() drawAll() end
function app.draw() drawAll() end

local function padAt(x, y)
  for i = 1, 4 do
    local p = pads[i]
    if x >= p.x and x < p.x + PW and y >= p.y and y < p.y + PH then return i end
  end
  return nil
end

function app.touch(x, y)
  if state == "start" or state == "over" then newGame() return end
  if state ~= "play" then return end
  local i = padAt(x, y)
  if not i then return end
  pad(i, true)
  sys.wait(150)
  pad(i, false)
  if i == seq[pos] then
    sys.sound("tap")
    pos = pos + 1
    if pos > #seq then
      if #seq > best then best = #seq; sys.save("best", best) end
      status("Nice! " .. #seq .. " in a row", color.green)
      showAt = sys.millis() + 700
      state = "wait"
    else
      status("Your turn: " .. (pos - 1) .. " / " .. #seq, color.white)
    end
  else
    sys.sound("error")
    state = "over"
    drawAll()
  end
end

function app.update()
  local now = sys.millis()
  if state == "wait" and now >= showAt then nextRound() return end
  if state ~= "show" or now < showAt then return end
  if showOn then
    pad(seq[showIdx], false)
    showOn = false
    showIdx = showIdx + 1
    showAt = now + 200
    if showIdx > #seq then
      state = "play"
      status("Your turn: 0 / " .. #seq, color.white)
    end
  else
    pad(seq[showIdx], true)
    sys.sound("pop")
    showOn = true
    showAt = now + math.max(250, 520 - #seq * 15)   -- faster as it gets longer
  end
end
