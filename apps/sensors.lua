-- name: Sensors
-- icon: Sn
-- color: #2D9CDB

-- Everything the phone can feel, live. Shows off the cOS 4.6 app sensors:
-- sys.tilt, sys.motion, sys.steps, sys.heart, sys.mic, sys.battery, sys.location, sys.speak.

local rows = {"Tilt", "Gravity", "Steps today", "Heart rate", "Sound", "Battery", "Location"}
local Y = 72

local function val(i)
  if i == 1 then
    local tx, ty = sys.tilt()
    return tx .. " / " .. ty .. " deg"
  elseif i == 2 then
    local x, y, z = sys.motion()
    return string.format("%.2f %.2f %.2f g", x, y, z)
  elseif i == 3 then
    return tostring(sys.steps())
  elseif i == 4 then
    local bpm, h, m = sys.heart()
    if bpm == 0 then return "no reading yet" end
    return string.format("%d bpm (%d:%02d)", bpm, h, m)
  elseif i == 5 then
    local lv, db = sys.mic()
    if not lv then return "no microphone" end
    return lv .. "%  (" .. db .. " dB)"
  elseif i == 6 then
    local p, ch = sys.battery()
    if p < 0 then return "USB power" end
    return p .. "%" .. (ch and " charging" or "")
  else
    local lat, lon, city = sys.location()
    return city
  end
end

local function row(i)
  local y = Y + (i - 1) * 30
  screen.fill(0, y, 240, 30, color.bg)
  screen.text(rows[i], 8, y + 4, 1, color.grey, -1)
  screen.text(val(i), 8, y + 15, 1, color.white, -1)
end

local function meter()
  local lv = sys.mic() or 0
  screen.fill(8, 286, 224, 6, color.bar)
  screen.fill(8, 286, math.floor(224 * lv / 100), 6, color.green)
end

local function draw()
  screen.clear()
  for i = 1, #rows do row(i) end
  screen.button(60, 296, 120, 22, "Say it", color.app, 1)
  meter()
end

function app.open() draw() end
function app.draw() draw() end

local n = 0
function app.update()
  n = n + 1
  if n % 6 == 0 then row(1) row(2) row(5) meter() end
end

function app.tick()
  row(3) row(4) row(6)
end

function app.touch(x, y)
  if y >= 296 then
    local tx, ty = sys.tilt()
    local p = sys.battery()
    local msg = "Battery " .. (p < 0 and "is on USB" or (p .. " percent")) .. ". " .. sys.steps() .. " steps today."
    sys.speak(msg)
  end
end
