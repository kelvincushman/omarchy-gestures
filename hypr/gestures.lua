-- Touchpad gestures managed by the Gestures panel (kelvincushman.gestures).
--
-- Gestures are stored as data in ~/.config/omarchy/gestures.conf, one per line:
--   <fingers> <direction> <action>
-- Every field is checked against the fixed lists below, so the file can never
-- inject code into the compositor config. Unknown lines are skipped.

local home = os.getenv("HOME") or ""
local path = home .. "/.config/omarchy/gestures.conf"

local function exec(cmd)
  return function() hl.dispatch(hl.dsp.exec_cmd(cmd)) end
end

local function focus(target)
  return function() hl.dispatch(hl.dsp.focus(target)) end
end

local axes = { horizontal = true, vertical = true }
local pinches = { pinch = true, pinchin = true, pinchout = true }

-- The basic movements each direction covers. Hyprland rejects a gesture that
-- overlaps an earlier one with the same finger count ("horizontal" then "left").
local covers = {
  swipe = { "left", "right", "up", "down" },
  horizontal = { "left", "right" },
  vertical = { "up", "down" },
  left = { "left" }, right = { "right" }, up = { "up" }, down = { "down" },
  pinch = { "pinchin", "pinchout" },
  pinchin = { "pinchin" }, pinchout = { "pinchout" },
}

-- Each action is either a Hyprland built-in (string, with optional extra
-- fields) or a function run once when the gesture completes.
local actions = {
  workspace = { builtin = "workspace", dirs = axes },
  move = { builtin = "move" },
  resize = { builtin = "resize" },
  close = { builtin = "close" },
  float = { builtin = "float" },
  fullscreen = { builtin = "fullscreen" },
  maximize = { builtin = "fullscreen", extra = { mode = "maximize" } },
  scratchpad = { builtin = "special", extra = { workspace_name = "scratchpad" } },
  zoom = { builtin = "cursor_zoom", extra = { zoom_level = 2.0, mode = "mult" }, dirs = pinches },

  workspace_next = { fn = focus({ workspace = "e+1" }) },
  workspace_prev = { fn = focus({ workspace = "e-1" }) },
  workspace_former = { fn = focus({ workspace = "previous" }) },
  focus_left = { fn = focus({ direction = "l" }) },
  focus_right = { fn = focus({ direction = "r" }) },
  focus_up = { fn = focus({ direction = "u" }) },
  focus_down = { fn = focus({ direction = "d" }) },
  apps = { fn = exec("omarchy-menu summon apps") },
  menu = { fn = exec("omarchy-menu summon") },
  menu_close = { fn = exec("omarchy-menu close") },
  volume_up = { fn = exec("omarchy-audio-output-volume raise") },
  volume_down = { fn = exec("omarchy-audio-output-volume lower") },
  brightness_up = { fn = exec("omarchy-brightness-display +5%") },
  brightness_down = { fn = exec("omarchy-brightness-display 5%-") },
  screenshot = { fn = exec("omarchy-capture-screenshot") },
}

local file = io.open(path, "r")
if not file then
  return
end

local taken = {}

local function claim(fingers, direction)
  taken[fingers] = taken[fingers] or {}
  for _, move in ipairs(covers[direction]) do
    if taken[fingers][move] then
      return false
    end
  end
  for _, move in ipairs(covers[direction]) do
    taken[fingers][move] = true
  end
  return true
end

for line in file:lines() do
  local fingers, direction, name = line:match("^%s*(%d+)%s+(%a+)%s+([%w_]+)%s*$")
  fingers = tonumber(fingers)
  local action = name and actions[name]
  -- libinput reports two-finger swipes as scrolling, so two fingers can only pinch.
  local valid = fingers and fingers >= 2 and fingers <= 5 and action and covers[direction]
    and (fingers > 2 or pinches[direction])
    and (not action.dirs or action.dirs[direction])
  -- A gesture overlapping an earlier line is skipped; the panel flags it.
  if valid and claim(fingers, direction) then
    local gesture = { fingers = fingers, direction = direction, action = action.fn or action.builtin }
    for k, v in pairs(action.extra or {}) do
      gesture[k] = v
    end
    hl.gesture(gesture)
  end
end

file:close()
