.pragma library

// Mirrors hypr/gestures.lua. The Lua loader is the safety boundary; these lists
// only drive the panel, so keep the two in step when adding an action.

var fingerOptions = [
  { value: "2", label: "2 fingers" },
  { value: "3", label: "3 fingers" },
  { value: "4", label: "4 fingers" },
  { value: "5", label: "5 fingers" }
]

var directionOptions = [
  { value: "left", label: "Left" },
  { value: "right", label: "Right" },
  { value: "up", label: "Up" },
  { value: "down", label: "Down" },
  { value: "horizontal", label: "Left or right" },
  { value: "vertical", label: "Up or down" },
  { value: "swipe", label: "Any swipe" },
  { value: "pinchin", label: "Pinch in" },
  { value: "pinchout", label: "Pinch out" },
  { value: "pinch", label: "Any pinch" }
]

var axes = ["horizontal", "vertical"]
var pinches = ["pinch", "pinchin", "pinchout"]

// `dirs` limits an action to particular directions.
var actionOptions = [
  { value: "workspace", label: "Slide between workspaces", dirs: axes },
  { value: "workspace_next", label: "Next workspace" },
  { value: "workspace_prev", label: "Previous workspace" },
  { value: "workspace_former", label: "Last used workspace" },
  { value: "apps", label: "Open app launcher" },
  { value: "menu", label: "Open Omarchy menu" },
  { value: "menu_close", label: "Close launcher / menu" },
  { value: "focus_left", label: "Focus window left" },
  { value: "focus_right", label: "Focus window right" },
  { value: "focus_up", label: "Focus window above" },
  { value: "focus_down", label: "Focus window below" },
  { value: "move", label: "Move window (drag)" },
  { value: "resize", label: "Resize window (drag)" },
  { value: "close", label: "Close window" },
  { value: "float", label: "Toggle floating" },
  { value: "fullscreen", label: "Toggle fullscreen" },
  { value: "maximize", label: "Toggle maximize" },
  { value: "scratchpad", label: "Toggle scratchpad" },
  { value: "zoom", label: "Toggle zoom", dirs: pinches },
  { value: "volume_up", label: "Volume up" },
  { value: "volume_down", label: "Volume down" },
  { value: "brightness_up", label: "Brightness up" },
  { value: "brightness_down", label: "Brightness down" },
  { value: "screenshot", label: "Screenshot" }
]

var covers = {
  swipe: ["left", "right", "up", "down"],
  horizontal: ["left", "right"],
  vertical: ["up", "down"],
  left: ["left"], right: ["right"], up: ["up"], down: ["down"],
  pinch: ["pinchin", "pinchout"],
  pinchin: ["pinchin"], pinchout: ["pinchout"]
}

var presets = {
  ios: [
    { fingers: "3", direction: "horizontal", action: "workspace" },
    { fingers: "3", direction: "up", action: "apps" },
    { fingers: "3", direction: "down", action: "menu_close" },
    { fingers: "4", direction: "left", action: "focus_left" },
    { fingers: "4", direction: "right", action: "focus_right" },
    { fingers: "2", direction: "pinchout", action: "zoom" }
  ]
}

function find(list, value) {
  for (var i = 0; i < list.length; i++) if (list[i].value === value) return list[i]
  return null
}

function isPinch(direction) {
  return pinches.indexOf(direction) !== -1
}

function parse(lines) {
  var rules = []
  for (var i = 0; i < lines.length; i++) {
    var parts = String(lines[i]).trim().split(/\s+/)
    if (parts.length === 3) rules.push({ fingers: parts[0], direction: parts[1], action: parts[2] })
  }
  return rules
}

function serialize(rules) {
  return rules.map(function(r) { return r.fingers + " " + r.direction + " " + r.action })
}

// Directions that make sense for a finger count and action. Two-finger swipes
// reach apps as scrolling, never as gestures, so two fingers can only pinch.
function directionsFor(fingers, action) {
  var act = find(actionOptions, action)
  return directionOptions.filter(function(d) {
    if (fingers === "2" && !isPinch(d.value)) return false
    return !act || !act.dirs || act.dirs.indexOf(d.value) !== -1
  })
}

// The reason a rule will not load, or "" when the loader accepts it.
// `earlier` is the list of rules above this one.
function problem(rule, earlier) {
  var act = find(actionOptions, rule.action)
  if (!act) return "Unknown action"
  if (!covers[rule.direction]) return "Unknown direction"
  if (rule.fingers === "2" && !isPinch(rule.direction)) return "Two fingers can only pinch; two-finger swipes are scrolling"
  if (act.dirs && act.dirs.indexOf(rule.direction) === -1) return "\"" + act.label + "\" needs " + (act.dirs === axes ? "a left/right or up/down swipe" : "a pinch")
  for (var i = 0; i < earlier.length; i++) {
    var other = earlier[i]
    if (other.fingers !== rule.fingers || !covers[other.direction] || problem(other, earlier.slice(0, i)) !== "") continue
    var overlap = covers[rule.direction].some(function(m) { return covers[other.direction].indexOf(m) !== -1 })
    if (overlap) return "Overlaps gesture " + (i + 1) + "; it will be ignored"
  }
  return ""
}
