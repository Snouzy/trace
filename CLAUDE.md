# Trace — project brief

## Goal

Trace is a minimal and **very light** screen annotation app for macOS, inspired by [Annotate](https://github.com/epilande/Annotate). Main use: draw over the screen during a recording or a presentation, toggled by a global shortcut.

The first priority is **lightness** (RAM, CPU, binary size) and **simple code**. Each addition must be justified. When in doubt, do not add.

## Keep this file current

After each change to the project, update this file in the same change when the change makes a part of it false or incomplete: architecture, shortcuts, constraints, current state, out of scope. Do the same for `README.md` when the change is visible to a user. Do not touch this file when the change has no effect on what it says.

## Technical constraints (not negotiable)

- **Swift + AppKit only.** No SwiftUI, no dependencies, no Swift Package, no Xcode project.
- **One source file** (`main.swift`) as long as that is reasonable (< ~600 lines).
- **Build with `build.sh`** (`swiftc -Osize`, Swift 6 mode, macOS 12 target, local symbols stripped), which makes an ad hoc signed `Trace.app` bundle. Zero warnings.
- **Release with `release.sh <version>`**: it calls `build.sh` for both architectures with a Developer ID signature and the hardened runtime, makes a DMG with `hdiutil`, notarizes and staples it, then publishes it with `gh release create`. It stops when the certificate or the `notarytool` profile is missing, or when `HEAD` is not `origin/main`.
- **License**: MIT.
- **Swift code rules**: `.claude/rules/swift.md`.
- **No system permission.** The global shortcut uses Carbon `RegisterEventHotKey` (no Accessibility permission). Do not use `NSEvent.addGlobalMonitorForEvents`.
- **Agent app**: `LSUIElement` + `setActivationPolicy(.accessory)`, menu bar icon only.
- macOS 12 minimum.
- **The interface strings are in French.** Code, comments and documentation are in English.

## Current architecture

- `Settings`: global state (tool, colour, highlighter colour, width, fade mode, palette).
- `Settings.keys`: the key of each tool, of the delete-selection action and of the fade toggle, stored as characters in `UserDefaults`; refuses duplicates and reserved keys (1 to 5, [ ]).
- `Shortcut`: the global shortcut (physical key code + Carbon modifier mask), read from and written to `UserDefaults`, with a label computed from the active keyboard layout.
- `Mark`: one annotation (tool, colour, width, points, text, end date, angle).
- `Canvas` (NSView): holds the `Mark` values, draws with `NSBezierPath` in `draw(_:)`, handles mouse, keyboard, text field, fade timer and shortcut feedback label.
- Selection: the selected mark leaves the `marks` array (`selection` field), so the fade and the undo cannot take it; it goes back on top when it is deselected.
- Rotation: rectangle, circle and text keep an `angle` (drawn through a transform; clicks and handles are computed in the local frame); the other tools rotate their points directly.
- `arrowPath`: filled arrow with a tapered tail, in the style of the CleanShot "Standard" arrow, along a Catmull-Rom curve through all its points (`splined`). `snapped`: the 45° constraint of the Shift key.
- `OverlayWindow` (NSWindow): borderless, transparent, full-screen window at `.screenSaver` level, one per screen.
- `RecorderButton` (NSButton): records a combination (global shortcut) or a single key (tools, fade); pauses the global shortcut while it listens.
- `App`: status item, menu, Carbon shortcut, creation and destruction of the overlays, Settings window made on demand and released on close.

## Performance principles to keep

- **Overlays are destroyed on close** (not only hidden), to release the full-screen backing stores (about 59 MB per 5K screen).
- **Partial redraw**: `setNeedsDisplay(rect)` with the changed area only; with the pen, only the last segment.
- **Annotations are stored as points or paths**, never as bitmaps.
- **No active timer at rest.** The fade timer stops as soon as nothing is left to fade.

## Shortcuts

| Key | Action |
| --- | --- |
| ⌃⌥A (global, can be changed in Settings) | Show / hide the overlay. The default is the physical position of A on QWERTY: on AZERTY it is the key labelled Q |
| V / T / H / A / L / R / O / E (can be changed in Settings) | Select / freehand ("tracé") / highlighter / arrow / line / rectangle / circle / text |
| Select tool: click, drag | Selects a mark, moves it. A selected mark is not removed by the fade |
| Select tool: Q (can be changed in Settings), Delete, or the trash knob next to the ↻ knob | Deletes the selected mark. Q does nothing without a selection |
| Select tool: handles | Resize: end points (line, arrow), corners (rectangle, circle, freehand stroke), font size (text). Shift keeps a square or a circle |
| Select tool: Shift while moving | The move stays on one axis, horizontal or vertical |
| Select tool: arrow | One bend point at the middle of each segment: a drag curves the arrow and adds a point; a double-click on a point removes it |
| Select tool: ↻ knob at the bottom right | Rotates the mark around its centre; Shift: 15° steps |
| Select tool: double-click on a text | Opens the field again to edit the text (shown horizontal during the edit, the angle is kept) |
| Select tool: 1 to 5, [ / ] | Changes the colour and the width of the selected mark |
| Shift while drawing | Straight stroke at 45° steps (freehand, highlighter, line, arrow); perfect square and circle |
| 1 to 5 | Red, blue, green, yellow, purple. The highlighter keeps its own colour (yellow by default): 1 to 5 changes the colour of the active tool |
| [ / ] (the ^ and $ keys on AZERTY) | Width (and text size) |
| F (can be changed in Settings) | Auto fade after 3 s |
| ⌘Z or Delete | Undo the last stroke |
| ⌥Delete | Clear all |
| Esc | Close the overlay (or commit the text in progress) |

## Current state

The code **compiles with zero warnings** and the app starts (12 MB of RAM after launch, 200 KB bundle). After a drawing session the RAM settled at 27 MB with the overlay closed: it does not go back to its start level, mostly heap (`MALLOC_SMALL`). This is not explained yet. Annotate 1.6.0, measured at the same moment: 38 MB after launch, 5.6 MB bundle. Drawing, selection, resize, rotation and curved arrows were checked on offscreen renders. The behaviour **on a real screen is only partly checked by hand**: it can contain errors. Follow-up in `tasks/todo.md`.

`main.swift` has about 1,000 lines, above the limit of about 600. A split into several files is an open decision: without an Xcode project or a Package, SourceKit analyses each file alone and shows false errors in the editor.

## First step

1. ~~Run `./build.sh` and fix the compile errors, with the same architecture.~~ Done.
2. Check by hand:
   - the Settings window records a new shortcut, the menu shows it, it survives a restart;
   - the ⌃⌥A shortcut works from any app, a fullscreen app included;
   - clicks are caught on the transparent areas of the overlay;
   - each tool draws correctly, text included (typing, Enter, Esc);
   - multi-screen works (one overlay per screen, the keyboard follows the clicked screen);
   - Esc gives the focus back to the previous app;
   - the fade mode removes the strokes and the timer stops afterwards.
3. Measure the memory, overlay closed then open:
   ```bash
   footprint -p Trace
   vmmap --summary Trace
   ```
   Check that with the overlay closed, the footprint goes back to its start level.

## Possible improvements (only after the base is validated)

In priority order, one at a time, with a measure of the memory impact:

1. ~~Small temporary indicator of the active tool and colour.~~ Done: a one-second label under the menu bar icon, drawn in `draw(_:)`, on each shortcut.
2. ~~Shift while drawing: lines and arrows at 45°, perfect square and circle.~~ Done (freehand and highlighter too).
3. Option to keep the annotations between two openings (without keeping the windows in memory: keep only the `Mark` array).

## Out of scope

No SwiftUI, no setting other than the shortcuts in the Settings window, no Sparkle or automatic update, no sounds, no whiteboard, no copy-paste, no multiple selection, no spotlight or background dimming.
