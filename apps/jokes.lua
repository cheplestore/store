-- name: Jokes
-- icon: :)
-- color: #F2994A

-- Gets a random joke from the internet (needs Wi-Fi).
-- Shows sys.http() for downloading and sys.json() for reading the answer.

local setup, punch, shown = nil, nil, false

local function draw()
  screen.clear()
  if not setup then
    screen.center("Tap for a joke", 160, 2, color.grey)
    return
  end
  local y = screen.wrap(setup, 12, 80, 18, 2, color.white)
  if shown then
    screen.wrap(punch, 12, y + 14, 18, 2, color.yellow)
    screen.center("Tap for another one", 300, 1, color.grey)
  else
    screen.button(40, math.min(y + 20, 250), 160, 40, "Show answer", color.app, 2)
  end
end

local function fetch()
  screen.clear()
  screen.center("Loading...", 160, 2, color.grey)
  if not sys.wifi() then
    setup, punch, shown = "No Wi-Fi. Connect in Settings > Wi-Fi.", "", true
    draw()
    return
  end
  local body, err = sys.http("https://official-joke-api.appspot.com/random_joke")
  local j = body and sys.json(body)
  if j and j.setup then
    setup, punch, shown = j.setup, j.punchline or "", false
  else
    setup, punch, shown = "Couldn't get a joke (" .. tostring(err or "bad answer") .. ")", "", true
  end
  draw()
end

function app.open()
  if setup then draw() else fetch() end
end

function app.draw() draw() end

function app.touch(x, y)
  if not setup or shown then
    fetch()
  else
    shown = true
    sys.sound("pop")
    draw()
  end
end

function app.swipe(dir)
  if dir == "left" then fetch() end
end
