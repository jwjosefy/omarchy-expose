# Exposé Switch

Exposé for Omarchy with an Alt-Tab chord. Tap Alt+Tab and the overview stays open. Keep pressing Tab while Alt is held to move through the grid, then release Alt to switch to that window. Shift+Tab moves backwards. Search, arrows, Quick Look, and the hot corner still work after a tap.

This is a fork of [Exposé](https://github.com/kristofferR/omarchy-expose) by Kristoffer Risanger (`@kristofferR`). The grid is Exposé. Alt+Tab follows [OmaSwitch](https://github.com/piyush97/omaswitch) by piyush97: tap to keep the overview open, keep pressing Tab to move, release Alt to switch.

![Exposé demo](https://github.com/kristofferR/omarchy-expose/releases/download/v4.0.0/demo.gif)

## Highlights

- **Live previews.** Cards are real screencopy views, so videos keep playing and terminals keep scrolling. The Omarchy desktop behind the grid stays live too.
- **Quick Look.** Space enlarges any preview and restores it again. Shift+Space does it in slow motion, like the classic macOS Easter egg.
- **Most recent first.** Cards are laid out in reading order from the most recently used window, so Alt+Tab+Tab goes back to the previous window. Exposé's original width-balanced packing is still available.
- **Search.** Just start typing to filter windows by title or application.
- **Workspace scope.** Press Tab to switch between every window and windows on the current workspace. Per-monitor mode evaluates the current workspace of the selected display.
- **Multi-monitor layouts.** The overview opens only on the focused display (or the display whose hot corner was used). Same overview shows every window there; per monitor keeps that display's own windows.
- **Built for Omarchy.** Runs inside Omarchy Shell, follows the active theme, and adds no packages, services, or daemons.
- **Hot corner.** Toggle the overview by flinging the pointer into a corner (on by default, any corner, can be disabled).

Everything is tunable from the built-in Settings panel and over IPC, and changes apply instantly.

## ❤️ Support Exposé

The grid comes from Kristoffer Risanger's Exposé. Sponsoring that project is a way to thank him for it.

[![Sponsor on GitHub](https://img.shields.io/badge/Sponsor_on_GitHub-%E2%99%A1-ec6cb9?style=for-the-badge)](https://github.com/sponsors/kristofferR)

## Requirements

- Omarchy Quattro with the native shell plugin system
- `jq`

The underlying Quickshell, Hyprland, Bash, and coreutils support ships with Omarchy, so no separate compositor setup is needed.

## Install

Disable `expose.window-overview` first if it is enabled. The two plugins are both full-screen overlays and will fight over the keyboard.

```sh
omarchy plugin disable expose.window-overview
omarchy plugin add https://github.com/jwjosefy/omarchy-expose.git --enable
~/.config/omarchy/plugins/expose.switch/install-bindings && hyprctl reload
```

`install-bindings` appends one `dofile` line to `~/.config/hypr/bindings.lua` and saves a `bindings.lua.bak.<epoch>` copy first. If that file already imports Exposé Switch, or already binds Alt+Tab to something else, the script stops and leaves it unchanged. The hot corner works without this command. The Alt+Tab behavior does not.

Alt+Tab opens the overview and leaves it up. Another Tab while Alt is still held moves to the next card in reading order. Shift+Tab moves back. Releasing Alt switches to the selected window only after one of those moves. Typing, the arrow keys, a click, or Escape cancels the confirmation, so releasing Alt then leaves the overview open. Tab without Alt still toggles all windows against the current workspace.

To open and close without the chord, bind any unused key:

```lua
o.bind("SUPER + A", "Exposé Switch", hl.dsp.event("expose.switch:toggle"))
```

Avoid modifier-only bindings such as standalone Super; Hyprland cannot reliably distinguish them from the start of normal Super shortcuts.

### Update

```sh
omarchy plugin update expose.switch --yes
```

### Remove

Delete the `dofile` line from `~/.config/hypr/bindings.lua`, then:

```sh
hyprctl reload
omarchy plugin remove expose.switch --yes
```

The next reload restores Omarchy's Alt+Tab bindings. Removal leaves nothing behind outside the plugin directory and its entry in `~/.config/omarchy/shell.json`.

## Controls

| Key | Action |
| --- | --- |
| Arrow keys | Move selection |
| Any character | Search by title or application |
| Space | Quick Look the hovered or selected preview (enlarge or restore) |
| Shift+Space | Quick Look in slow motion |
| Tab | Toggle all windows or the current workspace |
| Shift+Q | Close the selected window |
| Enter | Activate the selected window |
| Escape | Restore an enlarged preview; press again to close |

Clicking a card activates it; middle-clicking closes it. Activation moves the pointer to the chosen window by default; this is a setting, not a change to Hyprland's global cursor behavior.

The overlay is created on one display only. With **Same overview**, that display shows every window. With **Per monitor**, it shows only windows that already belong to that display; after pressing Tab, the current workspace is the one active on that display.

## Settings

Open **Settings** from the footer while the overview is open. It is fully keyboard driven: 1-4 jump to a section, Up/Down move between controls, Left/Right adjust sliders and choices, Space or Enter flip toggles and press buttons, Escape closes. Changes apply immediately:

- Opening animation: Original (default), Fade, Zoom, or Slide
- Animation speed saved per mode, linked for in/out by default or expandable to separate timings
- Slide direction: left (default), right, up, or down. Splitting in/out splits both speed and direction
- Background blur (0–20) and dim (0–90)
- Preview placement: in-place or centered
- Window footer style: floating, integrated, overlay, or centered
- Multiple displays: Same overview (all windows together on the selected display) or Per monitor (only that display's windows)
- Bottom text visibility. Hiding it requires confirmation and removes the Settings link
- Hot corner on/off, position (disable the same corner in other hot-corner plugins to avoid overlap), and activation delay (0–1000 ms of pointer dwell before it fires; 0 is instant)
- Move cursor to the activated window on/off
- Window order (IPC only): most recent first (default) or Exposé's packed layout

Every reversible setting is also scriptable:

```sh
omarchy-shell expose-switch toggle                      # also: open, close
omarchy-shell expose-switch settings toggle             # also: open, close
omarchy-shell expose-switch animationStyle original     # original | fade | zoom | slide
omarchy-shell expose-switch animationDuration original 190    # linked in/out, 100-800 ms
omarchy-shell expose-switch animationDurationIn original 190  # separate opening speed
omarchy-shell expose-switch animationDurationOut original 190 # separate closing speed
omarchy-shell expose-switch slideDirection left         # left | right | up | down, both halves
omarchy-shell expose-switch slideDirectionIn left       # separate opening side, also splits slide timing
omarchy-shell expose-switch slideDirectionOut right     # separate closing side, also splits slide timing
omarchy-shell expose-switch backgroundBlur 4            # 0-20
omarchy-shell expose-switch backgroundDim 6             # 0-90
omarchy-shell expose-switch previewPlacement in-place   # in-place | centered
omarchy-shell expose-switch windowFooterStyle floating  # floating | integrated | overlay | centered
omarchy-shell expose-switch multiMonitorMode mirrored   # mirrored | per-monitor
omarchy-shell expose-switch windowOrder recent          # recent | packed
omarchy-shell expose-switch hotCorner on                # on | off
omarchy-shell expose-switch hotCornerPosition top-left  # top-left | top-right | bottom-left | bottom-right
omarchy-shell expose-switch hotCornerDelay 0            # 0-1000 ms of dwell before it fires
omarchy-shell expose-switch moveCursorToWindow on       # on | off
```

To trace window order and the Alt+Tab chord while debugging, set `"debugLogging": true` in the `expose.switch` entry of `~/.config/omarchy/shell.json` and read `journalctl --user | grep expose-switch`. It is off by default.

After hiding the bottom text, you can restore it while Settings remains open. If you close Settings first, edit `~/.config/omarchy/shell.json` and set `"showFooter": true` in the `expose.switch` plugin entry.

## Security and system changes

Exposé runs unsandboxed inside Omarchy Shell with your user's permissions.

- Its helpers are plain Bash calling `hyprctl`, `jq`, `sleep`, and `timeout`.
- It reads window, workspace, and monitor state from Quickshell's native Hyprland model, activates or closes the windows you select, and temporarily raises Hyprland's blur while open, restoring the previous value on close.
- Settings writes touch only the plugin's entry in `~/.config/omarchy/shell.json`.
- `install-bindings` edits `~/.config/hypr/bindings.lua` only when you run it. Enabling the plugin does not.
- No network, no privilege escalation, no package installs, no services.

## Troubleshooting

- **No thumbnails:** verify Hyprland exposes toplevel-export support and no screen-capture policy blocks Quickshell. Cards stay usable with fallback labels.
- **Workspace says “—”:** the native Hyprland model has not associated that Wayland toplevel yet. Very short-lived windows can briefly appear this way; restart Omarchy Shell if a normal window remains unassociated.
- **Plugin not listed:** run `omarchy plugin validate .`, then `omarchy-shell shell rescanPlugins`.
- **Shortcut does nothing:** run `hyprctl reload`, check `hyprctl configerrors`, and test `hyprctl dispatch 'hl.dsp.event("expose.switch:toggle")'` directly.

## Credits

The window grid and most of this repository are [Exposé](https://github.com/kristofferR/omarchy-expose) by Kristoffer Risanger (`@kristofferR`), MIT. Exposé is based on [Bird's Eye](https://github.com/harel/omarchy-birdseye) by Harel Malka. Those copyright notices stay in `LICENSE`.

Alt+Tab — tap to keep the overview open, Tab and Shift+Tab to move, release Alt to switch — follows [OmaSwitch](https://github.com/piyush97/omaswitch) by piyush97 (`piyush.omaswitch`), MIT. This repository does not copy OmaSwitch's code.

## License

MIT
