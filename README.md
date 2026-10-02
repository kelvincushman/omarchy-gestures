# Gestures for Omarchy

A bar widget for [Omarchy](https://omarchy.org) that sets up touchpad gestures
without editing config files. Pick a finger count, a direction and an action;
changes apply the moment you make them.

It uses Hyprland's built-in gestures (`hl.gesture`, Hyprland 0.55+), so there
is no extra daemon.

## Install

```bash
omarchy plugin add https://github.com/kelvincushman/omarchy-gestures.git --enable
omarchy restart shell
```

Click the hand icon in the bar, then flip the switch to turn gestures on.
**Use iOS-like preset** gives you:

| Gesture | Action |
| --- | --- |
| 3 fingers left / right | Slide between workspaces |
| 3 fingers up | Open the app launcher |
| 3 fingers down | Close the launcher / menu |
| 4 fingers left / right | Focus the window on that side |
| 2-finger pinch out | Toggle zoom |

## What you can map

- **Fingers:** 2 to 5. Two-finger swipes always reach apps as scrolling on
  Linux, so two fingers can only pinch.
- **Directions:** left, right, up, down, left-or-right, up-or-down, any swipe,
  pinch in, pinch out, any pinch.
- **Actions:**
  - workspaces: slide between, next, previous, last used
  - Omarchy: app launcher, Omarchy menu, close the launcher or menu
  - windows: focus a neighbour, move, resize, close, float, fullscreen, maximize
  - scratchpad, zoom
  - volume, brightness, screenshot

**Slide through empty workspaces** (on by default) lets a workspace swipe
reach 3, 4, 5 and so on, like Super+number, even when they have no windows.
Hyprland has no upper limit for this, so it can continue past 10.
Hyprland's own behaviour, which you get by turning it off, stops at the last
workspace that has windows.

The panel flags gestures that would clash, for example "left" on the same
fingers as "left or right". It also warns when three-finger drag (`drag_3fg`)
is on, because that captures 3-finger swipes.

## How it works

- Gestures are stored as plain data in `~/.config/omarchy/gestures.conf`, one
  per line: `<fingers> <direction> <action>`.
- `hypr/gestures.lua` reads that file and accepts only actions from its fixed
  list, so the file can never run code in your compositor.
- Turning gestures on appends four lines to `~/.config/hypr/hyprland.lua` that
  load the reader if it exists. A timestamped backup is saved first.
- Turning gestures off removes those lines.

The helper `bin/gestures` (`status`, `save`, `enable`, `disable`) does the work
for the panel and can be run by hand.

## Uninstall

Turn gestures off in the panel, then:

```bash
omarchy plugin remove kelvincushman.gestures
```

If you remove the plugin first, the loader lines stay in `hyprland.lua` but do
nothing, because they check that the plugin is there before loading it.

## Tested on

- Dell Latitude 3520 (ELAN touchpad), Omarchy 4.0.4, Hyprland 0.56.2

Reports from other laptops are welcome.

## License

MIT
