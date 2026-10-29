-- name: Magic 8
-- icon: 8
-- color: #3D3D9E

-- Ask a yes-or-no question out loud, then tap the ball (or shake your finger across it).

local answers = {
  "It is certain.", "Without a doubt.", "Yes, definitely.", "You may rely on it.",
  "As I see it, yes.", "Most likely.", "Outlook good.", "Yes.", "Signs point to yes.",
  "Reply hazy, try again.", "Ask again later.", "Better not tell you now.",
  "Cannot predict now.", "Concentrate and ask again.",
  "Don't count on it.", "My reply is no.", "My sources say no.", "Outlook not so good.", "Very doubtful.",
}
local answer = nil
local shaking, shakeUntil, shakeStep = false, 0, 0
local asked = sys.load("asked", 0)

local function ball(dx, dy)
  screen.fill(0, 64, 240, 220, color.bg)
  screen.circle(120 + dx, 170 + dy, 90, color.black)
  screen.circle(120 + dx, 170 + dy, 90, color.darkgrey, true)
  screen.circle(120 + dx, 170 + dy, 44, screen.rgb(30, 40, 140))
  if answer and not shaking then
    screen.triangle(120 + dx - 30, 152 + dy, 120 + dx + 30, 152 + dy, 120 + dx, 200 + dy, screen.rgb(40, 60, 200))
    screen.wrap(answer, 120 + dx - 34, 150 + dy, 11, 1, color.white)
  else
    screen.center("8", 156 + dy, 4, color.white, -1)
  end
end

local function draw()
  screen.clear()
  ball(0, 0)
  screen.fill(0, 284, 240, 36, color.bg)
  screen.center(answer and "Tap to ask again" or "Ask a question, then tap", 290, 1, color.grey)
  screen.center("Questions asked: " .. asked, 304, 1, color.darkgrey)
end

function app.open() draw() end
function app.draw() draw() end

local function shake()
  if shaking then return end
  shaking = true
  shakeUntil = sys.millis() + 900
  shakeStep = 0
  sys.sound("tap")
end

function app.touch(x, y) shake() end
function app.swipe(dir) shake() end

function app.update()
  if not shaking then return end
  shakeStep = shakeStep + 1
  local dx = (shakeStep % 2 == 0) and 8 or -8
  ball(dx, (shakeStep % 3) - 1)
  if sys.millis() > shakeUntil then
    shaking = false
    answer = answers[math.random(#answers)]
    asked = asked + 1
    sys.save("asked", asked)
    sys.sound("pop")
    draw()
  end
end
