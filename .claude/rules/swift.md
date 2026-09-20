---
paths:
  - "**/*.swift"
  - "build.sh"
---

# Swift rules for Trace

The project brief in `CLAUDE.md` has priority when a rule conflicts with it.
The sources are at the end of this file.

## Style

- Name a symbol for clarity at the call site. Name it by its role, not by its type.
- Write Boolean names as assertions: `isEmpty`, `hasMarks`.
- Use `UpperCamelCase` for types. Use `lowerCamelCase` for all other names. Do not use a `k` prefix.
- Give each declaration the strictest access level that compiles. Use `private` before `fileprivate`.
- Mark each class `final`.
- Let the compiler infer types. Write a type annotation only when there is no initial value, or for an empty collection.
- Use the short forms `[T]`, `[K: V]` and `T?`. Do not write `get` in a read-only computed property. Do not write `-> Void`.
- Put `guard` at the top of a scope for early exits. Keep the main path at the left margin.
- Use the short unwrap form: `if let window`, `guard let self`.
- A body that has one statement can stay on one line: `guard let f = field else { return }`.
- Do not use semicolons. Write one statement per line.
- Use trailing-closure syntax only when the call has one closure.
- Omit `self.` unless the compiler requires it.
- Divide the file with `// MARK: - Name`. Use `//` comments only, not `/* */`.
- In a `switch` over a project enum, list all cases. Do not add `default`.
- Put constants in a caseless `enum` as `static let`. Use the Carbon `kVK_*` constants for key codes, not raw numbers.
- Keep lines at 120 columns or less, the SwiftLint default. Indent with 4 spaces.
- Write comments in English. Write a comment only for a reason, a constraint or a gotcha.

## Safety

- Do not use `!`, `as!` or `try!`. Exception: the adjacent code makes the invariant obvious, or a comment states it.
- Use `var x: T!` only for a UI object that a lifecycle method creates after `init`.
- Mark an unused `required init?(coder:)` with `@available(*, unavailable)`. Keep `fatalError` in its body.
- For an unexpected state that the app can survive: call `assertionFailure`, then return.
- Use `fatalError("message")` only when the app cannot continue.
- Capture `[weak self]` in each closure that can outlive `self`. Do not use `unowned`.
- Declare a singleton as `static let shared = T()` and nothing more. Keep global mutable state to the minimum.

## Concurrency

- The module compiles in Swift 6 mode with `-default-isolation MainActor`. Do not add `@MainActor` annotations.
- Keep the top-level code of `main.swift` as the entry point. Do not use `@main`.
- Use `MainActor.assumeIsolated` only at a boundary that the compiler cannot see: a C callback, a `Timer` block.
- Write `DispatchQueue.main.async` with this exact spelling. The compiler then treats the closure as main-actor code.
- Do not use `nonisolated(unsafe)`.

## Carbon and C interop

- Compare each `OSStatus` with `noErr` in a `guard` directly after the call. Return the failure to the caller.
- Pass a closure with zero captures as a C callback. Get to the app state through the singleton.
- In the Carbon handler, return `noErr` when the event is handled. Return `OSStatus(eventNotHandledErr)` when it is not.
- Unregister the old hot key before you register the new one. Then set the stored reference to `nil`.
- Call the Carbon hot key functions from the main thread only.
- Call `takeRetainedValue()` on the result of a `Copy` or `Create` function. Call `takeUnretainedValue()` on a `Get` result.

## Shortcut and UserDefaults

- Call `register(defaults:)` at each launch, before the first read.
- `integer(forKey:)` returns 0 for a missing key, and key code 0 is the A key. Do not read 0 as "missing".
- For the global hot key, store the virtual key code and the Carbon modifier mask as integers. Do not store the character.
- The overlay keys (tools, fade) are matched on `charactersIgnoringModifiers`. Store them as characters, so that they follow the key labels of the keyboard layout.
- A tool name is also its key in `UserDefaults`. Do not rename a `Tool` raw value without a migration.
- Define each defaults key one time, as a constant.
- Keep only Command, Option, Control and Shift in a stored modifier mask.
- Validate the stored values on read. Use the default shortcut when they are invalid or when registration fails.
- Accept a shortcut only when it contains Command or Control. macOS 15.0 and 15.1 refuse Option-only hot keys.
- Build a shortcut from `event.keyCode` and `event.modifierFlags`, not from `characters`.
- Compute the key label from the active keyboard layout with `UCKeyTranslate`. A key code is a physical position: `kVK_ANSI_A` is the key labelled Q on AZERTY.
- Unregister the global hot key while the recorder listens. Carbon consumes the key press before the view gets it.
- Command combinations do not get to `keyDown(with:)`. Capture them in `performKeyEquivalent(with:)`.

## Performance and memory

- Mutate in place. Do not copy a struct that holds an array, change it, and assign it back while the first copy is alive: each append then copies the full buffer.
- Model annotations as structs. Keep the number of reference-type fields low.
- Call `setNeedsDisplay(_:)` with the smallest changed rectangle. Do not call the `display` family.
- In `draw(_:)`, skip each mark that does not intersect `dirtyRect`.
- Compute the padded bounds of a finished mark one time and store them.
- Invalidate a repeating timer as soon as nothing is left to animate. Then set its reference to `nil`.
- Set `tolerance` to 10 % of the interval or more on each repeating timer.
- Do not let a timer tick during a wait. Schedule one non-repeating timer for the end of the wait.
- Set `isReleasedWhenClosed = false` on each window made in code. Destroy the window on close and release all references to it.
- Do not set `wantsLayer = true`.
- Declare nothing `public`. Public symbols are not removed by dead-code stripping.

## Build

- Compile with this command:
  `swiftc -Osize -swift-version 6 -default-isolation MainActor -target "$(uname -m)-apple-macos12" -Xlinker -dead_strip -Xlinker -x main.swift -o Trace`
- Always pass an explicit `-target`. Without it, swiftc builds for the host OS and the binary does not start on macOS 12.
- Do not add `-wmo` or `-lto`. Measured on this project: no gain.
- Do not add `-runtime-compatibility-version none`. The compatibility libraries fix runtime bugs of old macOS versions.
- The build must give zero warnings.

## Measure

- Measure before and after each optimization. Keep the change only if the number moves.
- Memory: `footprint -p Trace`, `vmmap --summary Trace`, `heap Trace | grep -E "OverlayWindow|Canvas"`, `leaks Trace`.
- Measure memory in four states: overlay closed, open, open after strokes across the full screen, closed again.
- Binary: `stat -f%z Trace.app/Contents/MacOS/Trace` after `codesign`. The size moves in 16 KB steps, so a smaller difference is noise.

## Rules that were examined and rejected

- A `///` comment on each declaration: the app has no public API.
- 2-space indentation: the file uses 4 spaces, the Xcode default.
- A 400-line file limit: the brief sets the limit at about 600 lines.
- `throw NSError(domain: NSOSStatusErrorDomain, …)`: there is one call site, a `Bool` result is sufficient.
- A check against `CopySymbolicHotKeys`: about 15 lines for a personal app.
- `NSApp.activate()` behind `#available(macOS 14, *)`: `activate(ignoringOtherApps:)` gives no warning with the macOS 26 SDK.

## Sources

- Swift API Design Guidelines: https://www.swift.org/documentation/api-design-guidelines/
- Google Swift Style Guide: https://google.github.io/swift/
- Airbnb Swift Style Guide: https://github.com/airbnb/swift
- Kodeco Swift Style Guide: https://github.com/kodecocodes/swift-style-guide
- SwiftLint rule directory: https://realm.github.io/SwiftLint/rule-directory.html
- swift-format rules: https://github.com/swiftlang/swift-format/blob/main/Documentation/RuleDocumentation.md
- Writing High-Performance Swift Code: https://github.com/swiftlang/swift/blob/main/docs/OptimizationTips.rst
- Swift 6 migration guide: https://github.com/swiftlang/swift-migration-guide
- SE-0466, default actor isolation: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0466-control-default-actor-isolation.md
- Apple energy guide, timers: https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/Timers.html
- Apple Cocoa Drawing Guide, paths: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CocoaDrawingGuide/Paths/Paths.html
- `NSWindow.isReleasedWhenClosed`: https://developer.apple.com/documentation/appkit/nswindow/isreleasedwhenclosed
- KeyboardShortcuts (recorder, hot key, storage): https://github.com/sindresorhus/KeyboardShortcuts
- MASShortcut (validator, label): https://github.com/cocoabits/MASShortcut
- Hot key registration on macOS 15: https://developer.apple.com/forums/thread/763878
