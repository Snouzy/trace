<div align="center">
  <h1>Trace</h1>
</div>

<p align="center">
  <strong>A tiny, keyboard-driven screen annotation tool for macOS. Draw over anything on your screen, from an app of about 200 KB that asks for no permission.</strong>
</p>

## ❓ Why?

[Annotate](https://github.com/epilande/Annotate) showed how good a keyboard-driven annotation overlay can be. Trace takes the same idea and puts weight first: one Swift file, AppKit only, no dependency, no Xcode project. It is made for screen recordings, live demos and teaching, where you want to point at something and then get out of the way.

|                              | Trace                           | Annotate 1.6.0                               |
| ---------------------------- | ------------------------------- | -------------------------------------------- |
| App bundle                   | 216 KB (440 KB as universal)    | 5.6 MB (universal)                           |
| Memory (RAM) after launch    | 12 MB                           | 38 MB                                        |
| CPU at rest                  | 0 %                             | 1 to 3 % while the mouse moves               |
| Permissions                  | none                            | none                                         |
| Dependencies                 | none                            | Sparkle, KeyboardShortcuts                   |
| Minimum macOS                | 12                              | 14                                           |
| Source                       | one Swift file, no Xcode project | Xcode project                               |

Annotate does more: counter, eraser, whiteboard, cursor highlight, floating toolbar, sounds, redo, copy and paste, automatic updates. Trace trades those for weight.

<details>
<summary>How these numbers were measured</summary>

- Apple M1 Pro, macOS 26.4, both apps measured at the same moment, right after launch, overlay never opened.
- Memory is the RAM footprint that `footprint -p <pid>` reports. It grows with use: after a drawing session, Trace settled at 27 MB with the overlay closed.
- CPU is a 4-second sample of `top`. Annotate keeps global mouse monitors for its cursor highlight, so it does a little work each time the mouse moves. Neither app wakes the CPU on a timer at rest.
- Bundle size is `du -sh` on the app. Annotate ships as a universal binary with the Sparkle framework inside. `build.sh` builds Trace for the architecture of your Mac only; the universal figure comes from a build of both slices joined with `lipo`.
- Dependencies come from Annotate's `Package.resolved`. Permissions come from its code signature (no entitlements), its `Info.plist` (no usage descriptions) and its source (mouse-only global monitors, which need no permission).

</details>

## ✨ Features

- 🎨 **Drawing Tools**:
  - ✒️ **Pen** for freehand drawing.
  - ➡️ **Arrow** with a tapered tail and a solid head, in the style of the CleanShot "Standard" arrow. It can be **curved**.
  - 📏 **Line** for straight lines.
  - 🟨 **Highlighter** with its own colour, yellow by default.
  - 🔲 **Rectangle** and ⭕ **Circle** shapes.
  - 📝 **Text** annotations.
  - 👆 **Select** tool: move, resize, rotate, recolour, edit and delete any annotation.
- ✨ **Auto Fade:** annotations fade out 3 seconds after you draw them. A selected annotation never fades.
- 📐 **Shift Constraints:** straight strokes at 45° steps, perfect squares and circles, axis-locked moves, 15° rotation steps.
- 💬 **Shortcut Feedback:** a one-second label under the menu bar icon confirms each shortcut, with the active colour.
- ⌨️ **Custom Shortcuts:** every tool key and the global hotkey can be changed in Settings.
- 🌍 **Keyboard Layout Aware:** shortcut labels follow your layout, and the colour and size keys work by physical position, so AZERTY works out of the box.
- ⚡ **Global Hotkey:** toggle the overlay from any app. It uses the Carbon hot key API, so macOS asks for no permission.
- 🖥️ **Multi-Display:** one overlay per display, set up to show over fullscreen apps. The keyboard follows the display you click.
- 🎛️ **Menu Bar Only:** no Dock icon, no window at rest.
- 🪶 **Light by Design:** overlay windows are destroyed when you close the overlay, not hidden, so their full-screen buffers are given back. Only the changed rectangle is redrawn.

## 📦 Installation

### Build from Source

Trace has no release build yet. It compiles in about two seconds.

1. **Install the Command Line Tools** (Xcode is not needed):

   ```sh
   xcode-select --install
   ```

2. **Clone the Repository:**

   ```sh
   git clone https://github.com/Snouzy/trace
   cd trace
   ```

3. **Build and Run:**

   ```sh
   bash build.sh && open Trace.app
   ```

> [!NOTE]
> The build targets macOS 12 (Monterey) or later, for the architecture of the Mac that builds it.
>
> The app is signed ad hoc by `build.sh`. It is not notarized, so build it on the Mac that runs it.

## 🚀 Quick Start

1. Launch Trace. A pencil icon appears in the menu bar.
2. Press <kbd>Control</kbd> + <kbd>Option</kbd> + <kbd>A</kbd> to toggle the overlay.
3. Draw. Press a tool key to change tool, <kbd>1</kbd> to <kbd>5</kbd> to change colour.
4. Press <kbd>Esc</kbd> to close the overlay. The focus goes back to the app you were in.

> [!TIP]
> The default hotkey is the physical position of <kbd>A</kbd> on a QWERTY keyboard. On AZERTY that key is labelled <kbd>Q</kbd>. The menu shows the right label for your layout, and you can record another hotkey in **Paramètres…** (Settings).

> [!NOTE]
> The interface is in French: **Annoter** (Annotate), **Effacement automatique** (Auto Fade), **Paramètres…** (Settings), **Quitter Trace** (Quit).

## 🎮 Usage

### Keyboard Shortcuts

> [!TIP]
> All tool shortcuts and the global hotkey can be changed in Settings.

#### 🎨 Drawing Tools

| Key          | Tool            | Description                                   |
| ------------ | --------------- | --------------------------------------------- |
| <kbd>T</kbd> | **Pen**         | Freehand drawing ("tracé")                    |
| <kbd>H</kbd> | **Highlighter** | Thick, semi-transparent strokes               |
| <kbd>A</kbd> | **Arrow**       | Tapered arrows, straight or curved            |
| <kbd>L</kbd> | **Line**        | Straight lines                                |
| <kbd>R</kbd> | **Rectangle**   | Rectangles (<kbd>Shift</kbd>: square)         |
| <kbd>O</kbd> | **Circle**      | Ellipses (<kbd>Shift</kbd>: perfect circle)   |
| <kbd>E</kbd> | **Text**        | Text annotations                              |
| <kbd>V</kbd> | **Select**      | Select, move, resize, rotate, edit and delete |

#### 🎯 Colour & Size

| Key                          | Action            | Description                                                                                   |
| ---------------------------- | ----------------- | --------------------------------------------------------------------------------------------- |
| <kbd>1</kbd> to <kbd>5</kbd> | **Colour**        | Red, blue, green, yellow, purple. Changes the active tool, or the selected annotation         |
| <kbd>[</kbd>                 | **Decrease Size** | Stroke width or text size. Changes the next strokes, or the selected annotation               |
| <kbd>]</kbd>                 | **Increase Size** | Same, one step up                                                                             |

These keys work by physical position. On AZERTY, the colour keys are the top row without <kbd>Shift</kbd>, and the size keys are <kbd>^</kbd> and <kbd>$</kbd>.

#### ⚡ Quick Actions

| Shortcut                              | Action               | Description                                                                 |
| ------------------------------------- | -------------------- | --------------------------------------------------------------------------- |
| <kbd>F</kbd>                          | **Toggle Auto Fade** | Annotations fade 3 seconds after they are drawn                             |
| <kbd>Q</kbd>                          | **Delete Selection** | Remove the selected annotation                                              |
| <kbd>Delete</kbd>                     | **Delete**           | Remove the selected annotation, or the most recent one                      |
| <kbd>Option</kbd> + <kbd>Delete</kbd> | **Clear All**        | Remove all annotations                                                      |
| <kbd>Command</kbd> + <kbd>Z</kbd>     | **Undo**             | Remove the most recent annotation                                           |
| <kbd>Shift</kbd> (while drawing)      | **Constrain**        | Pen, Highlighter, Line, Arrow: straight at 45° steps. Shapes: square/circle |

#### 🪟 Overlay Controls

| Shortcut                   | Action             | Description                           |
| -------------------------- | ------------------ | ------------------------------------- |
| Custom (Settings)          | **Toggle Overlay** | Show or hide the annotation overlay   |
| <kbd>Esc</kbd>             | **Close**          | Close the overlay                     |
| <kbd>Enter</kbd> (in text) | **Commit Text**    | Place the text                        |
| <kbd>Esc</kbd> (in text)   | **Commit Text**    | Place the text, same as Enter         |

### Drawing Tools

#### Pen & Highlighter

- Click and drag to draw freehand.
- The highlighter draws thicker, semi-transparent strokes and keeps its own colour.
- Hold <kbd>Shift</kbd> to turn the stroke into a straight line at 45° steps.

#### Arrow & Line

- Click and drag from the tail to the tip.
- Hold <kbd>Shift</kbd> to snap to 45° steps.
- The arrow head scales with the stroke width.

#### Shapes (Rectangle, Circle)

- Click and drag to create a shape.
- Hold <kbd>Shift</kbd> for a square or a perfect circle.

#### Text Annotations

- Click to place a text field, type, then press <kbd>Enter</kbd> or <kbd>Esc</kbd>.
- The text size follows the current stroke size.

#### Select Tool

Press <kbd>V</kbd>, then click an annotation. The cursor changes from a crosshair to an arrow (and to an I-beam with the Text tool), so you can see which mode you are in. Strokes, lines and arrows must be clicked within 8 px of the stroke. Shapes and text can be clicked anywhere inside their box.

- **Move:** drag the annotation. Hold <kbd>Shift</kbd> to stay on one axis.
- **Resize:** drag a handle. Lines and arrows have one handle per point, shapes and freehand strokes have four corners, text has one handle that sets the font size. Hold <kbd>Shift</kbd> to keep a square or a circle.
- **Curve an arrow:** each arrow segment shows a small bend point at its middle. Drag it and the arrow curves through it. New bend points appear on both sides, so you can add as many as you want. Double-click a bend point to remove it.
- **Rotate:** drag the ↻ knob at the bottom right. Hold <kbd>Shift</kbd> for 15° steps.
- **Edit text:** double-click a text annotation.
- **Restyle:** <kbd>1</kbd> to <kbd>5</kbd> and <kbd>[</kbd> <kbd>]</kbd> change the selected annotation.
- **Delete:** press <kbd>Q</kbd> or <kbd>Delete</kbd>, or click the trash knob next to the ↻ knob.
- Click an empty area, or change tool, to deselect.

### ⚙️ Settings

Open **Paramètres…** from the menu bar icon. Each row has a button: click it, then press the new key. <kbd>Esc</kbd> cancels.

- The **global hotkey** must contain <kbd>Control</kbd> or <kbd>Command</kbd>.
- A **tool key** is a single key. Trace refuses a key that another tool uses, and the colour and size keys.

Shortcuts are stored in `UserDefaults` under the `com.snouzy.trace` domain.

## 🪶 How It Stays Light

- **Swift and AppKit only.** No SwiftUI, no package, no Xcode project. `build.sh` calls `swiftc -Osize` and strips local symbols.
- **No permission.** The global hotkey goes through Carbon `RegisterEventHotKey`, not through an event monitor.
- **Windows are destroyed, not hidden.** A full-screen transparent window holds a large buffer. Closing the overlay gives it back.
- **Partial redraw.** Only the changed rectangle is invalidated. While you draw freehand, that is the last segment.
- **Vectors, not bitmaps.** Annotations are stored as points.
- **No timer at rest.** The fade timer stops as soon as nothing is left to fade.

Measure it yourself:

```sh
footprint -p Trace
vmmap --summary Trace
```

## 🛠️ Development

Swift compiles, so there is no hot reload. This loop rebuilds and relaunches on each save:

```sh
o=; while sleep 1; do
  n=$(stat -f%m main.swift)
  if [[ $n != $o ]]; then o=$n; pkill -x Trace; bash build.sh && open -g Trace.app; fi
done
```

The project brief is in [`CLAUDE.md`](CLAUDE.md) and the Swift rules are in [`.claude/rules/swift.md`](.claude/rules/swift.md).

`bash release.sh <version>` makes a universal, notarized DMG and publishes it as a GitHub release. It needs a Developer ID Application certificate and a `notarytool` profile; the top of the script says how to set them up.

## 📄 License

[MIT](LICENSE)

## 🙏 Acknowledgements

- [Annotate](https://github.com/epilande/Annotate) by Emmanuel Pilande, for the idea and the keyboard-driven workflow.
- [CleanShot X](https://cleanshot.com), for the look of the arrow and the select tool.
