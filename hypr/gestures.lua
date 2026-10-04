-- Touchpad gestures managed by the Gestures panel (kelvincushman.gestures).
--
-- Gestures are stored as data in ~/.config/omarchy/gestures.conf, one per line:
--   <fingers> <direction> <action>
-- plus optional settings lines:
--   option swipe_empty on|off   slide through workspaces 1-10, stopping at both ends (default on)
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

-- Zoom steps by whole levels like Omarchy's Super+Ctrl+Z, between 1x and 10x.
-- Hyprland's own cursor_zoom gesture only ever multiplies, so it can't undo itself.
local function zoom_by(step)
  return function()
    local zoom = hl.get_config("cursor.zoom_factor") or 1
    hl.config({ cursor = { zoom_factor = math.max(1, math.min(10, zoom + step)) } })
  end
end

local function zoom_reset()
  if (hl.get_config("cursor.zoom_factor") or 1) ~= 1 then
    hl.config({ cursor = { zoom_factor = 1 } })
  end
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
  zoom = { fn = zoom_by(1), dirs = pinches, zooms = true }, -- zoom in; name kept for older files
  zoom_out = { fn = zoom_by(-1), dirs = pinches, zooms = true },
  zoom_reset = { fn = zoom_reset, dirs = pinches, zooms = true },

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
local zooms = false

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

-- On by default: Omarchy treats workspaces 1-10 as fixed (Super+1...), but
-- Hyprland's swipe otherwise stops at the first empty workspace.
-- Off leaves Hyprland's own swipe behaviour untouched.
local swipe_empty = true

for line in file:lines() do
  local value = line:match("^%s*option%s+swipe_empty%s+(%a+)%s*$")
  if value then
    swipe_empty = value ~= "off"
  end
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
    zooms = zooms or action.zooms
  end
end

file:close()

-- With any zoom gesture in use, Escape always returns to 1x. The bind is
-- non-consuming, so apps still receive the Escape key as normal.
if zooms then
  hl.bind("Escape", zoom_reset, { non_consuming = true, description = "Reset zoom" })
end

-- Keep workspaces 1-10 alive so the swipe walks through empty ones and stops
-- at both ends, using only Hyprland settings. With "create new" off, the
-- neighbour past 10 wraps to 1 (and past 1 to 10), which Hyprland treats as a
-- wall. Never cap this by switching workspace from a "workspace.active"
-- handler: that runs mid-swipe and crashed Hyprland 0.56.2 at gesture end.
if swipe_empty then
  for id = 1, 10 do
    hl.workspace_rule({ workspace = tostring(id), persistent = true })
  end
  hl.config({ gestures = { workspace_swipe_use_r = false, workspace_swipe_create_new = false } })
end
