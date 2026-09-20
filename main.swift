import AppKit
import Carbon.HIToolbox

// MARK: - Model

enum Tool: String {
    case select = "Sélection", pen = "Main levée", highlighter = "Surligneur", arrow = "Flèche", line = "Ligne"
    case rect = "Rectangle", ellipse = "Cercle", text = "Texte"
}

struct Mark {
    var tool: Tool
    var color: NSColor
    var width: CGFloat
    var points: [CGPoint]
    var text = ""
    var born: Date?                // end of the stroke: the fade delay starts here
    var angle: CGFloat = 0         // rect, ellipse and text only: the other tools rotate their points
}

extension CGPoint {
    static func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
    static func * (a: CGPoint, k: CGFloat) -> CGPoint { CGPoint(x: a.x * k, y: a.y * k) }
    var length: CGFloat { hypot(x, y) }

    func rotated(by angle: CGFloat) -> CGPoint {
        CGPoint(x: x * cos(angle) - y * sin(angle), y: x * sin(angle) + y * cos(angle))
    }

    func pivoted(around c: CGPoint, by angle: CGFloat) -> CGPoint { c + (self - c).rotated(by: angle) }
}

final class Settings {
    static let shared = Settings()
    var tool: Tool = .pen
    var color: NSColor = .systemRed
    var highlightColor: NSColor = .systemYellow
    var activeColor: NSColor {
        get { tool == .highlighter ? highlightColor : color }
        set { if tool == .highlighter { highlightColor = newValue } else { color = newValue } }
    }
    var width: CGFloat = 4
    var fade = false
    let fadeDelay: TimeInterval = 3
    let fadeDuration: TimeInterval = 0.6
    let palette: [NSColor] = [.systemRed, .systemBlue, .systemGreen, .systemYellow, .systemPurple]
    let paletteNames = ["Rouge", "Bleu", "Vert", "Jaune", "Violet"]

    static let colorCodes = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5]
    private static let reservedCodes = colorCodes + [kVK_ANSI_LeftBracket, kVK_ANSI_RightBracket]

    static let deleteName = "Supprimer la sélection"
    // The names are the raw values of Tool, then the two names that are not tools: the delete key and the fade toggle.
    static let defaultKeys: KeyValuePairs = [
        "Sélection": "v", "Main levée": "t", "Surligneur": "h", "Flèche": "a", "Ligne": "l", "Rectangle": "r",
        "Cercle": "o", "Texte": "e", deleteName: "q", "Effacement auto": "f"]
    private static let defaults = Dictionary(uniqueKeysWithValues: defaultKeys.map { ($0.key, $0.value) })

    private(set) var keys: [String: String] = {
        let stored = UserDefaults.standard.dictionary(forKey: "keys") as? [String: String] ?? [:]
        return defaults.merging(stored.filter { defaults[$0.key] != nil }) { $1 }
    }()

    func setKey(_ e: NSEvent, for name: String) -> Bool {
        let k = e.charactersIgnoringModifiers?.lowercased() ?? ""
        guard k.count == 1, let c = k.first, c.isLetter || c.isNumber || c.isPunctuation || c.isSymbol,
              e.modifierFlags.isDisjoint(with: [.command, .control, .option]),
              !Settings.reservedCodes.contains(Int(e.keyCode)),
              !keys.contains(where: { $0.key != name && $0.value == k }) else { return false }
        keys[name] = k
        // Only the changed keys are stored, so that a later change of a default does not collide with them.
        UserDefaults.standard.set(keys.filter { Settings.defaults[$0.key] != $0.value }, forKey: "keys")
        return true
    }
}

func rectFrom(_ a: CGPoint, _ b: CGPoint) -> NSRect {
    NSRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
}

func distance(from p: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
    let d = b - a
    let squared = d.x * d.x + d.y * d.y
    let t = squared == 0 ? 0 : max(0, min(1, ((p.x - a.x) * d.x + (p.y - a.y) * d.y) / squared))
    return (p - a - d * t).length
}

func snapped(_ p: CGPoint, from a: CGPoint) -> CGPoint {
    let step = CGFloat.pi / 4
    let angle = (atan2(p.y - a.y, p.x - a.x) / step).rounded() * step
    let length = hypot(p.x - a.x, p.y - a.y)
    return CGPoint(x: a.x + length * cos(angle), y: a.y + length * sin(angle))
}

func constrained(_ p: CGPoint, from a: CGPoint, square: Bool) -> CGPoint {
    guard square else { return snapped(p, from: a) }
    let side = max(abs(p.x - a.x), abs(p.y - a.y))
    return CGPoint(x: a.x + (p.x < a.x ? -side : side), y: a.y + (p.y < a.y ? -side : side))
}

let splineSteps = 16

// Catmull-Rom: the curve goes through each point, so a bend handle stays on the arrow.
func splined(_ pts: [CGPoint]) -> [CGPoint] {
    guard pts.count > 2 else { return pts }
    var out: [CGPoint] = []
    for i in 0..<pts.count - 1 {
        let p0 = pts[max(i - 1, 0)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[min(i + 2, pts.count - 1)]
        for step in 0..<splineSteps {
            let t = CGFloat(step) / CGFloat(splineSteps)
            let a = p1 * 2 + (p2 - p0) * t
            let b = (p0 * 2 - p1 * 5 + p2 * 4 - p3) * (t * t)
            let c = (p1 * 3 - p0 - p2 * 3 + p3) * (t * t * t)
            out.append((a + b + c) * 0.5)
        }
    }
    return out + [pts[pts.count - 1]]
}

func arrowPath(through points: [CGPoint], width: CGFloat) -> NSBezierPath {
    let p = NSBezierPath()
    let line = splined(points)
    guard let tail = line.first, let tip = line.last else { return p }
    p.move(to: tail)
    var lengths: [CGFloat] = [0]
    for (a, b) in zip(line, line.dropFirst()) { lengths.append(lengths[lengths.count - 1] + (b - a).length) }
    let total = lengths[lengths.count - 1]
    guard total > 0 else {
        p.line(to: tail)
        return p
    }
    func point(at s: CGFloat) -> CGPoint {
        let j = max(1, lengths.firstIndex { $0 >= s } ?? line.count - 1)
        let span = lengths[j] - lengths[j - 1]
        return line[j - 1] + (line[j] - line[j - 1]) * (span == 0 ? 0 : (s - lengths[j - 1]) / span)
    }
    func normal(from a: CGPoint, to b: CGPoint) -> CGPoint {
        let d = b - a
        return d.length == 0 ? .zero : CGPoint(x: -d.y, y: d.x) * (1 / d.length)
    }
    let head = min(14 + width * 3.5, total * 0.6)
    let bodyEnd = total - head * 0.85
    let body = zip(line, lengths).filter { $0.1 < bodyEnd }.map(\.0) + [point(at: bodyEnd)]
    let bodyLengths = lengths.filter { $0 < bodyEnd } + [bodyEnd]
    var right: [CGPoint] = []
    for k in 1..<body.count {
        let half = head * 0.15 * bodyLengths[k] / bodyEnd
        let offset = normal(from: body[k - 1], to: body[min(k + 1, body.count - 1)]) * half
        p.line(to: body[k] + offset)
        right.append(body[k] - offset)
    }
    let back = point(at: total - head)
    let barb = normal(from: back, to: tip) * (head * 0.5)
    p.line(to: back + barb)
    p.line(to: tip)
    p.line(to: back - barb)
    right.reversed().forEach { p.line(to: $0) }
    p.close()
    return p
}

// MARK: - Global shortcut

struct Shortcut {
    var keyCode: UInt32
    var carbonMods: UInt32

    static let fallback = Shortcut(keyCode: UInt32(kVK_ANSI_A), carbonMods: UInt32(controlKey | optionKey))

    private enum Keys {
        static let code = "hotKeyCode"
        static let mods = "hotKeyMods"
    }

    private static let modifiers: [(flag: NSEvent.ModifierFlags, carbon: Int, symbol: String)] = [
        (.control, controlKey, "⌃"), (.option, optionKey, "⌥"), (.shift, shiftKey, "⇧"),
        (.command, cmdKey, "⌘")]

    private static let specialKeys = [
        kVK_Space: "Espace", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_Escape: "⎋",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12"]

    static var stored: Shortcut {
        let d = UserDefaults.standard
        let s = Shortcut(keyCode: UInt32(clamping: d.integer(forKey: Keys.code)),
                         carbonMods: UInt32(clamping: d.integer(forKey: Keys.mods)))
        return s.isValid ? s : fallback
    }

    var defaults: [String: Any] { [Keys.code: Int(keyCode), Keys.mods: Int(carbonMods)] }

    // macOS 15.0 and 15.1 refuse hot keys that have neither Command nor Control.
    var isValid: Bool { carbonMods & UInt32(cmdKey | controlKey) != 0 }

    var label: String {
        Shortcut.modifiers.filter { carbonMods & UInt32($0.carbon) != 0 }.map(\.symbol).joined() + keyLabel
    }

    // A key code is a physical position: the label comes from the active keyboard layout.
    private var keyLabel: String {
        if let special = Shortcut.specialKeys[Int(keyCode)] { return special }
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return "?" }
        let layout = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
        var deadKeys: UInt32 = 0
        var length = 0
        var chars = [UniChar](repeating: 0, count: 4)
        let status = layout.withUnsafeBytes {
            UCKeyTranslate($0.bindMemory(to: UCKeyboardLayout.self).baseAddress, UInt16(keyCode),
                           UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                           OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKeys, chars.count, &length, &chars)
        }
        guard status == noErr, length > 0 else { return "?" }
        return String(utf16CodeUnits: chars, count: length).uppercased()
    }

    func save() {
        defaults.forEach { UserDefaults.standard.set($1, forKey: $0) }
    }
}

extension Shortcut {
    init?(event e: NSEvent) {
        let mods = Shortcut.modifiers.filter { e.modifierFlags.contains($0.flag) }.reduce(0) { $0 | $1.carbon }
        self.init(keyCode: UInt32(e.keyCode), carbonMods: UInt32(mods))
        guard isValid else { return nil }
    }
}

// MARK: - Canvas

final class Canvas: NSView, NSTextFieldDelegate {
    private var marks: [Mark] = []
    private var current: Mark?
    // The selected mark is out of `marks`, so the fade and the undo cannot take it.
    private var selection: Mark?
    private enum Grab { case move, handle(Int), rotate }
    private var grab = Grab.move
    private var dragFrom = CGPoint.zero
    private var original: Mark?
    private var lastDirty = NSRect.zero
    private var fadeTimer: Timer?
    private var hud: (text: NSAttributedString, rect: NSRect)?
    private var hudTimer: Timer?
    private var field: NSTextField?
    private var fieldWidth: CGFloat = 4
    private var fieldAngle: CGFloat = 0
    private let s = Settings.shared

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    override func draw(_ dirtyRect: NSRect) {
        let now = Date()
        for m in marks where extent(of: m).intersects(dirtyRect) {
            render(m, alpha: alpha(of: m, now: now))
        }
        if let c = current { render(c, alpha: 1) }
        if let selection { drawSelection(selection) }
        if let hud, hud.rect.intersects(dirtyRect) {
            NSColor.black.withAlphaComponent(0.8).setFill()
            NSBezierPath(roundedRect: hud.rect, xRadius: 8, yRadius: 8).fill()
            (selection?.color ?? s.activeColor).setFill()
            NSBezierPath(ovalIn: NSRect(x: hud.rect.minX + 10, y: hud.rect.midY - 5, width: 10, height: 10)).fill()
            hud.text.draw(at: CGPoint(x: hud.rect.minX + 28, y: hud.rect.minY + 5))
        }
    }

    // MARK: Shortcut feedback

    func flash(_ message: String, under anchor: NSRect) {
        clearHUD()
        let text = NSAttributedString(string: message, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: NSColor.white])
        let size = text.size()
        let width = size.width + 40
        let x = min(max(anchor.midX - width / 2, 8), bounds.width - width - 8)
        let rect = NSRect(x: x, y: anchor.minY - size.height - 16, width: width, height: size.height + 10)
        hud = (text, rect)
        setNeedsDisplay(rect)
        let t = Timer(timeInterval: 1, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.clearHUD() }
        }
        // The common mode lets the timer fire during a drag.
        RunLoop.main.add(t, forMode: .common)
        hudTimer = t
    }

    private func clearHUD() {
        hudTimer?.invalidate()
        hudTimer = nil
        if let hud { setNeedsDisplay(hud.rect) }
        hud = nil
    }

    private func drawSelection(_ m: Mark) {
        render(m, alpha: 1)
        NSColor.controlAccentColor.setStroke()
        rotating(m) {
            let outline = NSBezierPath(rect: localExtent(of: m).insetBy(dx: 1, dy: 1))
            outline.setLineDash([4, 3], count: 2, phase: 0)
            outline.stroke()
        }
        NSColor.white.setFill()
        func dot(_ h: CGPoint, _ radius: CGFloat) {
            let box = NSRect(x: h.x - radius, y: h.y - radius, width: radius * 2, height: radius * 2)
            let circle = NSBezierPath(ovalIn: box)
            circle.fill()
            circle.stroke()
        }
        func knob(_ at: CGPoint, _ symbol: String, _ color: NSColor) {
            dot(at, 8)
            NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(paletteColors: [color]))?
                .draw(in: NSRect(x: at.x - 5, y: at.y - 5, width: 10, height: 10))
        }
        let all = handles(of: m)
        all.main.forEach { dot($0, 4) }
        all.bends.forEach { dot($0, 3) }
        knob(rotateKnob(of: m), "arrow.clockwise", .controlAccentColor)
        knob(trashKnob(of: m), "trash", .systemRed)
    }

    private func rotating(_ m: Mark, _ draw: () -> Void) {
        guard m.angle != 0 else { return draw() }
        let c = center(of: m)
        let t = NSAffineTransform()
        t.translateX(by: c.x, yBy: c.y)
        t.rotate(byRadians: m.angle)
        t.translateX(by: -c.x, yBy: -c.y)
        NSGraphicsContext.saveGraphicsState()
        t.concat()
        draw()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func render(_ m: Mark, alpha: CGFloat) {
        guard alpha > 0 else { return }
        rotating(m) {
            if m.tool == .text {
                NSAttributedString(string: m.text, attributes: textAttrs(m.width, m.color, alpha)).draw(at: m.points[0])
                return
            }
            let hl = m.tool == .highlighter
            m.color.withAlphaComponent((hl ? 0.35 : 1) * alpha).set()
            let p = path(for: m)
            p.lineCapStyle = .round
            p.lineJoinStyle = .round
            let arrow = m.tool == .arrow
            p.lineWidth = hl ? m.width * 5 : arrow ? 3 : m.width
            if arrow { p.fill() }
            p.stroke()
        }
    }

    private func path(for m: Mark) -> NSBezierPath {
        let p = NSBezierPath()
        guard let a = m.points.first, let b = m.points.last else { return p }
        switch m.tool {
        case .pen, .highlighter:
            p.move(to: a)
            m.points.dropFirst().forEach { p.line(to: $0) }
            // A click without a drag: a zero-length line with round caps draws a dot.
            if m.points.count == 1 { p.line(to: a) }
        case .arrow: return arrowPath(through: m.points, width: m.width)
        case .line:
            p.move(to: a)
            p.line(to: b)
        case .rect: p.appendRect(rectFrom(a, b))
        case .ellipse: p.appendOval(in: rectFrom(a, b))
        case .text, .select: break
        }
        return p
    }

    private func bounds(of m: Mark) -> NSRect {
        guard m.tool == .text else { return path(for: m).bounds }
        let size = NSAttributedString(string: m.text, attributes: textAttrs(m.width, m.color, 1)).size()
        return NSRect(origin: m.points[0], size: size)
    }

    private func center(of m: Mark) -> CGPoint {
        let r = bounds(of: m)
        return CGPoint(x: r.midX, y: r.midY)
    }

    private func localCorners(of r: NSRect) -> [CGPoint] {
        [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.maxX, y: r.maxY),
         CGPoint(x: r.minX, y: r.maxY)]
    }

    private func corners(of r: NSRect, in m: Mark) -> [CGPoint] {
        localCorners(of: r).map { $0.pivoted(around: center(of: m), by: m.angle) }
    }

    private func localExtent(of m: Mark) -> NSRect {
        let pad = m.tool == .text ? 4 : (m.tool == .highlighter ? m.width * 5 : m.width) + 2
        return bounds(of: m).insetBy(dx: -pad, dy: -pad)
    }

    private func extent(of m: Mark) -> NSRect {
        guard m.angle != 0 else { return localExtent(of: m) }
        let c = corners(of: localExtent(of: m), in: m)
        return c.dropFirst().reduce(NSRect(origin: c[0], size: .zero)) { $0.union(NSRect(origin: $1, size: .zero)) }
    }

    private func textAttrs(_ width: CGFloat, _ color: NSColor, _ alpha: CGFloat) -> [NSAttributedString.Key: Any] {
        [.font: NSFont.boldSystemFont(ofSize: 14 + width * 3),
         .foregroundColor: color.withAlphaComponent(alpha)]
    }

    // MARK: Mouse

    override func mouseDown(with e: NSEvent) {
        let p = convert(e.locationInWindow, from: nil)
        commitText()
        guard s.tool != .select else { return pick(at: p, clicks: e.clickCount) }
        deselect()
        guard s.tool != .text else { return beginText(at: p) }
        let m = Mark(tool: s.tool, color: s.activeColor, width: s.width, points: [p])
        current = m
        lastDirty = extent(of: m)
        setNeedsDisplay(lastDirty)
    }

    override func mouseDragged(with e: NSEvent) {
        var p = convert(e.locationInWindow, from: nil)
        let shift = e.modifierFlags.contains(.shift)
        if var moved = selection, let original {
            let before = selectionRect(moved)
            switch grab {
            case .move:
                let d = p - dragFrom
                let locked = abs(d.x) > abs(d.y) ? CGPoint(x: d.x, y: 0) : CGPoint(x: 0, y: d.y)
                moved.points = original.points.map { $0 + (shift ? locked : d) }
            case .handle(let i): resize(&moved, from: original, handle: i, to: p, shift: shift)
            case .rotate: rotate(&moved, from: original, to: p, shift: shift)
            }
            selection = moved
            return setNeedsDisplay(before.union(selectionRect(moved)))
        }
        guard var c = current else { return }
        // Drops the second reference to the points buffer. Without this, each append copies all the points.
        current = nil
        let freehand = c.tool == .pen || c.tool == .highlighter
        if shift { p = constrained(p, from: c.points[0], square: c.tool == .rect || c.tool == .ellipse) }
        let r: NSRect
        if freehand && !shift {
            let prev = c.points[c.points.count - 1]
            c.points.append(p)
            let pad = c.width * 5 + 2
            r = rectFrom(prev, p).insetBy(dx: -pad, dy: -pad)
        } else {
            // A freehand stroke that becomes straight: lastDirty covers only its last segment.
            if freehand { lastDirty = lastDirty.union(extent(of: c)) }
            c.points = [c.points[0], p]
            r = extent(of: c)
        }
        current = c
        setNeedsDisplay(r.union(lastDirty))
        lastDirty = r
    }

    override func mouseUp(with e: NSEvent) {
        guard var c = current else { return }
        c.born = Date()
        marks.append(c)
        current = nil
        startFadeIfNeeded()
    }

    // MARK: Selection

    private func pick(at p: CGPoint, clicks: Int) {
        dragFrom = p
        grab = .move
        if var held = selection {
            original = held
            let all = handles(of: held)
            if (rotateKnob(of: held) - p).length <= 10 {
                grab = .rotate
                return
            }
            if (trashKnob(of: held) - p).length <= 10 {
                _ = removeSelection()
                return
            }
            if let i = all.main.firstIndex(where: { ($0 - p).length <= 8 }) {
                let bend = held.tool == .arrow && i > 0 && i < held.points.count - 1
                guard clicks == 2, bend else { return grabHandle(i) }
                held.points.remove(at: i)
                return replaceSelection(with: held)
            }
            if let k = all.bends.firstIndex(where: { ($0 - p).length <= 8 }) {
                held.points.insert(all.bends[k], at: k + 1)
                replaceSelection(with: held)
                return grabHandle(k + 1)
            }
            if hit(held, at: p) {
                guard clicks == 2, held.tool == .text else { return }
                selection = nil
                setNeedsDisplay(selectionRect(held))
                return beginText(at: held.points[0], editing: held)
            }
        }
        deselect()
        guard let i = marks.lastIndex(where: { hit($0, at: p) }) else { return }
        let picked = marks.remove(at: i)
        original = picked
        selection = picked
        setNeedsDisplay(selectionRect(picked))
    }

    private func replaceSelection(with m: Mark) {
        let before = selection.map(selectionRect) ?? .zero
        original = m
        selection = m
        setNeedsDisplay(before.union(selectionRect(m)))
    }

    // The two knobs are outside the extent, up to 20 points from its corner.
    private func selectionRect(_ m: Mark) -> NSRect { extent(of: m).insetBy(dx: -30, dy: -30) }

    private func knob(of m: Mark, dx: CGFloat) -> CGPoint {
        let r = localExtent(of: m)
        return CGPoint(x: r.maxX + dx, y: r.minY - 14).pivoted(around: center(of: m), by: m.angle)
    }

    private func rotateKnob(of m: Mark) -> CGPoint { knob(of: m, dx: 14) }

    private func trashKnob(of m: Mark) -> CGPoint { knob(of: m, dx: -8) }

    private func isBoxed(_ m: Mark) -> Bool {
        switch m.tool {
        case .rect, .ellipse: return m.points.count == 2
        case .pen, .highlighter: return m.points.count > 2
        case .arrow, .line, .text, .select: return false
        }
    }

    private func handles(of m: Mark) -> (main: [CGPoint], bends: [CGPoint]) {
        if m.tool == .text { return ([corners(of: bounds(of: m), in: m)[2]], []) }
        if isBoxed(m) { return (corners(of: bounds(of: m), in: m), []) }
        guard m.tool == .arrow, m.points.count > 1 else { return (m.points, []) }
        let line = splined(m.points)
        let bends = m.points.count == 2 ? [(m.points[0] + m.points[1]) * 0.5]
                                        : (0..<m.points.count - 1).map { line[$0 * splineSteps + splineSteps / 2] }
        return (m.points, bends)
    }

    private func grabHandle(_ i: Int) {
        grab = .handle(i)
        guard var held = selection, held.tool == .rect || held.tool == .ellipse, held.points.count == 2 else { return }
        // A rectangle keeps its opposite corner in points[0], so the drag only moves points[1].
        let local = localCorners(of: bounds(of: held))
        held.points = [local[(i + 2) % 4], local[i]]
        original = held
        selection = held
        grab = .handle(1)
    }

    // A rotated mark turns around its centre, and a resize moves that centre.
    // `fixed` is the screen position of the corner that must not move: the local points are rebuilt from it.
    private func resize(_ m: inout Mark, from original: Mark, handle: Int, to p: CGPoint, shift: Bool) {
        let angle = original.angle
        if m.tool == .text {
            let base = bounds(of: original)
            let fixed = base.origin.pivoted(around: center(of: original), by: angle)
            let font = (14 + original.width * 3) * (p - fixed).rotated(by: -angle).y / base.height
            m.width = (min(300, max(8, font)) - 14) / 3
            let size = bounds(of: m).size
            let half = CGPoint(x: size.width / 2, y: size.height / 2)
            m.points = [fixed - half + half.rotated(by: angle)]
        } else if m.tool == .rect || m.tool == .ellipse, original.points.count == 2 {
            let fixed = original.points[0].pivoted(around: center(of: original), by: angle)
            let raw = (p - fixed).rotated(by: -angle)
            let half = (shift ? constrained(raw, from: .zero, square: true) : raw) * 0.5
            let anchor = fixed - half + half.rotated(by: angle)
            m.points = [anchor, anchor + half * 2]
        } else if isBoxed(original) {
            let all = handles(of: original).main
            let from = all[handle]
            let anchor = all[(handle + 2) % 4]
            let sx = from.x == anchor.x ? 1 : (p.x - anchor.x) / (from.x - anchor.x)
            let sy = from.y == anchor.y ? 1 : (p.y - anchor.y) / (from.y - anchor.y)
            m.points = original.points.map {
                CGPoint(x: anchor.x + ($0.x - anchor.x) * sx, y: anchor.y + ($0.y - anchor.y) * sy)
            }
        } else if m.points.indices.contains(handle) {
            let fixed = m.points[handle == 0 ? m.points.count - 1 : handle - 1]
            m.points[handle] = shift ? snapped(p, from: fixed) : p
        }
    }

    private func rotate(_ m: inout Mark, from original: Mark, to p: CGPoint, shift: Bool) {
        let c = center(of: original)
        let step = CGFloat.pi / 12
        let raw = atan2(p.y - c.y, p.x - c.x) - atan2(dragFrom.y - c.y, dragFrom.x - c.x)
        let delta = shift ? (raw / step).rounded() * step : raw
        guard m.tool == .rect || m.tool == .ellipse || m.tool == .text else {
            m.points = original.points.map { $0.pivoted(around: c, by: delta) }
            return
        }
        m.angle = original.angle + delta
    }

    private func hit(_ m: Mark, at p: CGPoint) -> Bool {
        let q = p.pivoted(around: center(of: m), by: -m.angle)
        guard localExtent(of: m).contains(q) else { return false }
        let polyline = [Tool.pen, .highlighter, .line, .arrow].contains(m.tool)
        let line = m.tool == .arrow ? splined(m.points) : m.points
        guard polyline, line.count > 1 else { return true }
        let reach = max(8, m.tool == .highlighter ? m.width * 2.5 : m.width)
        return zip(line, line.dropFirst()).contains { distance(from: q, toSegment: $0, $1) <= reach }
    }

    private func deselect() {
        guard var restored = selection else { return }
        selection = nil
        restored.born = Date()
        marks.append(restored)
        setNeedsDisplay(selectionRect(restored))
        startFadeIfNeeded()
    }

    private func removeSelection() -> Bool {
        guard let removed = selection else { return false }
        selection = nil
        setNeedsDisplay(selectionRect(removed))
        return true
    }

    private func restyle(_ change: (inout Mark) -> Void) -> Mark? {
        guard var styled = selection else { return nil }
        let before = selectionRect(styled)
        change(&styled)
        selection = styled
        setNeedsDisplay(before.union(selectionRect(styled)))
        return styled
    }

    // MARK: Keyboard

    override func keyDown(with e: NSEvent) {
        let cmd = e.modifierFlags.contains(.command)
        let k = e.charactersIgnoringModifiers?.lowercased() ?? ""
        switch (Int(e.keyCode), k) {
        case (kVK_Escape, _): App.shared.hide()
        case (kVK_Delete, _) where e.modifierFlags.contains(.option): clear()
        case (kVK_Delete, _):
            if !removeSelection() { undo() }
        case (_, "z") where cmd: undo()
        case (_, "q") where cmd: NSApp.terminate(nil)
        // Physical key codes: on AZERTY, [ ] and 1-5 need Option or Shift, so their characters never match.
        case (kVK_ANSI_LeftBracket, _): changeWidth(by: -1)
        case (kVK_ANSI_RightBracket, _): changeWidth(by: 1)
        default:
            if let i = Settings.colorCodes.firstIndex(of: Int(e.keyCode)) {
                if restyle({ $0.color = s.palette[i] }) == nil { s.activeColor = s.palette[i] }
                App.shared.flash(s.paletteNames[i])
            } else if let name = s.keys.first(where: { $0.value == k })?.key {
                if let tool = Tool(rawValue: name) {
                    select(tool)
                } else if name == Settings.deleteName {
                    _ = removeSelection()
                } else {
                    App.shared.toggleFade()
                }
            } else {
                super.keyDown(with: e)
            }
        }
    }

    private func select(_ tool: Tool) {
        deselect()
        s.tool = tool
        App.shared.flash(tool.rawValue)
    }

    private func changeWidth(by delta: CGFloat) {
        let styled = restyle { $0.width = min(24, max(1, $0.width + delta)) }
        if styled == nil { s.width = min(24, max(1, s.width + delta)) }
        App.shared.flash("Épaisseur \(Int(styled?.width ?? s.width))")
    }

    private func undo() {
        guard let m = marks.popLast() else { return }
        setNeedsDisplay(extent(of: m))
    }

    private func clear() {
        selection = nil
        marks.removeAll()
        needsDisplay = true
    }

    // MARK: Text

    private func beginText(at p: CGPoint, editing m: Mark? = nil) {
        let f = NSTextField(string: m?.text ?? "")
        f.isBordered = false
        f.drawsBackground = false
        f.focusRingType = .none
        fieldWidth = m?.width ?? s.width
        fieldAngle = m?.angle ?? 0
        f.font = NSFont.boldSystemFont(ofSize: 14 + fieldWidth * 3)
        f.textColor = m?.color ?? s.activeColor
        f.delegate = self
        f.sizeToFit()
        let h = f.frame.height
        // An edited text goes back where commitText() took its origin: 2 points left of the text.
        f.frame = m == nil ? NSRect(x: p.x, y: p.y - h / 2, width: 60, height: h)
                           : NSRect(x: p.x - 2, y: p.y, width: f.frame.width + 20, height: h)
        addSubview(f)
        window?.makeFirstResponder(f)
        field = f
    }

    func controlTextDidChange(_ n: Notification) {
        guard let f = field else { return }
        f.frame.size.width = max(60, f.attributedStringValue.size().width + 20)
    }

    // Return and Escape both commit the text.
    func control(_ control: NSControl, textView: NSTextView, doCommandBy sel: Selector) -> Bool {
        if sel == #selector(NSResponder.insertNewline(_:)) || sel == #selector(NSResponder.cancelOperation(_:)) {
            commitText()
            return true
        }
        return false
    }

    private func commitText() {
        guard let f = field else { return }
        field = nil
        let txt = f.stringValue
        let origin = CGPoint(x: f.frame.minX + 2, y: f.frame.minY)
        let color = f.textColor ?? s.color
        f.removeFromSuperview()
        window?.makeFirstResponder(self)
        guard !txt.isEmpty else { return }
        var m = Mark(tool: .text, color: color, width: fieldWidth, points: [origin], text: txt)
        m.angle = fieldAngle
        m.born = Date()
        marks.append(m)
        setNeedsDisplay(extent(of: m))
        startFadeIfNeeded()
    }

    // MARK: Auto fade

    func restartFade() {
        let now = Date()
        for i in marks.indices { marks[i].born = now }
        startFadeIfNeeded()
    }

    private func alpha(of m: Mark, now: Date) -> CGFloat {
        guard s.fade, let born = m.born else { return 1 }
        let t = now.timeIntervalSince(born) - s.fadeDelay
        return t <= 0 ? 1 : max(0, 1 - CGFloat(t / s.fadeDuration))
    }

    private func startFadeIfNeeded() {
        guard s.fade, fadeTimer == nil, !marks.isEmpty else { return }
        let t = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tickFade() }
        }
        t.tolerance = t.timeInterval / 10
        RunLoop.main.add(t, forMode: .common)
        fadeTimer = t
    }

    private func tickFade() {
        let now = Date()
        var dirty = NSRect.null
        marks.removeAll { m in
            let a = alpha(of: m, now: now)
            if a < 1 { dirty = dirty.union(extent(of: m)) }
            return a <= 0
        }
        if !dirty.isNull { setNeedsDisplay(dirty) }
        if marks.isEmpty || !s.fade { stopTimer() }
    }

    private func stopTimer() {
        fadeTimer?.invalidate()
        fadeTimer = nil
    }

    func teardown() {
        stopTimer()
        clearHUD()
    }
}

// MARK: - Transparent full-screen window

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        // An explicit false makes the window take the clicks on its transparent pixels too.
        ignoresMouseEvents = false
        isReleasedWhenClosed = false
        setFrame(screen.frame, display: false)
        contentView = Canvas(frame: NSRect(origin: .zero, size: screen.frame.size))
    }
}

// MARK: - Shortcut recorder

final class RecorderButton: NSButton {
    private let label: () -> String
    private let accept: (NSEvent) -> Bool
    private var recording = false {
        didSet {
            guard recording != oldValue else { return }
            title = recording ? "Tapez…" : label()
            // Carbon consumes the key press while the hot key is registered: the button would not get it.
            if recording { App.shared.pauseHotKey() } else { App.shared.resumeHotKey() }
        }
    }

    override var acceptsFirstResponder: Bool { true }

    init(label: @escaping () -> String, accept: @escaping (NSEvent) -> Bool) {
        self.label = label
        self.accept = accept
        super.init(frame: .zero)
        bezelStyle = .rounded
        title = label()
        target = self
        action = #selector(toggleRecording)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    @objc private func toggleRecording() {
        window?.makeFirstResponder(self)
        recording.toggle()
    }

    override func resignFirstResponder() -> Bool {
        recording = false
        return super.resignFirstResponder()
    }

    // Command combinations do not get to keyDown(with:).
    override func performKeyEquivalent(with e: NSEvent) -> Bool {
        guard recording else { return super.performKeyEquivalent(with: e) }
        record(e)
        return true
    }

    override func keyDown(with e: NSEvent) {
        if recording { record(e) } else { super.keyDown(with: e) }
    }

    private func record(_ e: NSEvent) {
        if accept(e) || Int(e.keyCode) == kVK_Escape { recording = false } else { NSSound.beep() }
    }
}

// MARK: - Application (menu bar, global shortcut, settings)

final class App: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static let shared = App()
    private(set) var shortcut = Shortcut.fallback
    private var windows: [OverlayWindow] = []
    private var settings: NSWindow?
    private var statusItem: NSStatusItem!
    private var toggleItem: NSMenuItem!
    private var fadeItem: NSMenuItem!
    private var hotKey: EventHotKeyRef?

    var canvases: [Canvas] { windows.compactMap { $0.contentView as? Canvas } }

    func applicationDidFinishLaunching(_ n: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "pencil.tip", accessibilityDescription: "Trace")

        let menu = NSMenu()
        toggleItem = menu.addItem(withTitle: "Annoter", action: #selector(toggle), keyEquivalent: "")
        toggleItem.target = self
        fadeItem = menu.addItem(withTitle: "Effacement automatique", action: #selector(toggleFade), keyEquivalent: "")
        fadeItem.target = self
        menu.addItem(withTitle: "Paramètres…", action: #selector(showSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quitter Trace", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        installHotKeyHandler()
        UserDefaults.standard.register(defaults: Shortcut.fallback.defaults)
        if !setShortcut(.stored, save: false) { _ = setShortcut(.fallback, save: false) }
    }

    @objc func toggle() {
        if windows.isEmpty { show() } else { hide() }
    }

    func show() {
        windows = NSScreen.screens.map { OverlayWindow(screen: $0) }
        NSApp.activate(ignoringOtherApps: true)
        for w in windows {
            w.orderFrontRegardless()
            w.makeFirstResponder(w.contentView)
        }
        let mouse = NSEvent.mouseLocation
        (windows.first { $0.frame.contains(mouse) } ?? windows.first)?.makeKey()
    }

    func hide() {
        canvases.forEach { $0.teardown() }
        windows.forEach { $0.orderOut(nil) }
        windows = []            // releases the windows and their full-screen backing stores
        NSApp.hide(nil)         // gives the focus back to the previous app
    }

    @objc func toggleFade() {
        Settings.shared.fade.toggle()
        fadeItem.state = Settings.shared.fade ? .on : .off
        canvases.forEach { $0.restartFade() }
        flash(Settings.shared.fade ? "Effacement auto activé" : "Effacement auto désactivé")
    }

    func flash(_ message: String) {
        let icon = statusItem?.button?.window?.frame ?? .zero
        // The icon can be off screen: hidden by the notch or by a menu bar manager.
        let host = windows.first { $0.frame.intersects(icon) }
        guard let w = host ?? windows.first(where: \.isKeyWindow), let canvas = w.contentView as? Canvas else { return }
        let top = NSRect(x: w.frame.midX, y: w.frame.maxY - NSStatusBar.system.thickness, width: 0, height: 0)
        canvas.flash(message, under: w.convertFromScreen(host == nil ? top : icon))
    }

    // MARK: Settings window

    @objc private func showSettings() {
        if settings == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 80),
                             styleMask: [.titled, .closable], backing: .buffered, defer: true)
            w.title = "Paramètres"
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.contentView = settingsView()
            w.center()
            settings = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settings?.makeKeyAndOrderFront(nil)
    }

    private func settingsView() -> NSView {
        let global = RecorderButton(label: { App.shared.shortcut.label },
                                    accept: { Shortcut(event: $0).map { App.shared.setShortcut($0) } ?? false })
        var rows: [[NSView]] = [[NSTextField(labelWithString: "Afficher / masquer (global)"), global]]
        for (name, _) in Settings.defaultKeys {
            let button = RecorderButton(label: { Settings.shared.keys[name]?.uppercased() ?? "" },
                                        accept: { Settings.shared.setKey($0, for: name) })
            rows.append([NSTextField(labelWithString: name), button])
        }
        let grid = NSGridView(views: rows)
        grid.column(at: 0).xPlacement = .trailing
        grid.translatesAutoresizingMaskIntoConstraints = false
        let box = NSView()
        box.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: box.topAnchor, constant: 24),
            grid.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -24),
            grid.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 24),
            grid.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -24)])
        return box
    }

    func windowDidResignKey(_ n: Notification) {
        settings?.makeFirstResponder(nil)
    }

    func windowWillClose(_ n: Notification) {
        settings?.makeFirstResponder(nil)
        // Released after close() returns: the window must not die inside its own close.
        DispatchQueue.main.async { self.settings = nil }
    }

    // MARK: Hot key

    // Carbon hot key: needs no Accessibility permission, unlike a global NSEvent monitor.
    private func installHotKeyHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { App.shared.toggle() }
            return noErr
        }, 1, &spec, nil, nil)
    }

    private func register(_ s: Shortcut) -> Bool {
        pauseHotKey()
        let id = EventHotKeyID(signature: OSType(0x5452_4345), id: 1)   // 'TRCE'
        let status = RegisterEventHotKey(s.keyCode, s.carbonMods, id, GetApplicationEventTarget(), 0, &hotKey)
        return status == noErr && hotKey != nil
    }

    func setShortcut(_ s: Shortcut, save: Bool = true) -> Bool {
        guard register(s) else { return false }
        shortcut = s
        toggleItem.title = "Annoter  (\(s.label))"
        if save { s.save() }
        return true
    }

    func pauseHotKey() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
    }

    func resumeHotKey() {
        if hotKey == nil { _ = register(shortcut) }
    }
}

// MARK: - Entry point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.delegate = App.shared
app.run()
