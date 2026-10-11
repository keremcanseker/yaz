import AppKit
import SwiftUI

struct Editor: NSViewRepresentable {
    @ObservedObject var note: Note

    func makeCoordinator() -> EditorCoordinator { EditorCoordinator(note) }

    func makeNSView(context: Context) -> NSScrollView {
        let container = NSTextContainer(size: NSSize(width: 680, height: CGFloat.greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        container.widthTracksTextView = true
        let layout = NoteLayoutManager()
        layout.addTextContainer(container)
        note.storage.addLayoutManager(layout)

        let tv = NoteTextView(frame: NSRect(x: 0, y: 0, width: 744, height: 0), textContainer: container)
        tv.delegate = context.coordinator
        tv.isRichText = true
        tv.allowsUndo = true
        tv.usesFontPanel = false
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.isAutomaticLinkDetectionEnabled = false
        tv.isContinuousSpellCheckingEnabled = false
        tv.isAutomaticTextCompletionEnabled = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isGrammarCheckingEnabled = false
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = .width
        tv.minSize = .zero
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.textContainerInset = NSSize(width: 32, height: 24)
        tv.drawsBackground = true
        tv.backgroundColor = .textBackgroundColor
        tv.insertionPointColor = .textColor
        tv.focusRingType = .none
        tv.defaultParagraphStyle = Theme.paragraph
        tv.typingAttributes = Theme.body

        let sv = NSScrollView()
        sv.borderType = .noBorder
        sv.focusRingType = .none
        sv.hasVerticalScroller = true
        sv.autohidesScrollers = true
        sv.scrollerStyle = .overlay
        sv.drawsBackground = true
        sv.backgroundColor = .textBackgroundColor
        sv.documentView = tv
        context.coordinator.zoom = NotificationCenter.default.addObserver(
            forName: .yazScaleChanged, object: nil, queue: .main) { [weak tv, weak coordinator = context.coordinator] _ in
            guard let tv, let coordinator else { return }
            NoteLayoutManager.restyle(coordinator.note.storage)
            tv.typingAttributes = coordinator.typing(coordinator.note.storage, tv.selectedRange().location)
            tv.needsDisplay = true
        }
        return sv
    }

    func updateNSView(_ sv: NSScrollView, context: Context) {
        NoteLayoutManager.restyle(note.storage)
        guard !context.coordinator.focused, let tv = sv.documentView as? NSTextView else { return }
        context.coordinator.focused = true
        DispatchQueue.main.async { tv.window?.makeFirstResponder(tv) }
    }

    static func dismantleNSView(_ sv: NSScrollView, coordinator: EditorCoordinator) {
        if let zoom = coordinator.zoom { NotificationCenter.default.removeObserver(zoom) }
        guard let tv = sv.documentView as? NSTextView, let layout = tv.layoutManager else { return }
        tv.delegate = nil
        layout.textStorage?.removeLayoutManager(layout)
    }
}

final class NoteTextView: NSTextView {
    override func paste(_ sender: Any?) { pasteAsPlainText(sender) }
    override func keyDown(with event: NSEvent) {
        if !event.modifierFlags.contains(.command) { KeySound.play() }
        super.keyDown(with: event)
    }

    override func setFrameSize(_ newSize: NSSize) {
        let inset = max(32, (newSize.width - 680) / 2)
        if textContainerInset.width != inset { textContainerInset.width = inset }
        super.setFrameSize(newSize)
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let i = characterIndexForInsertion(at: p)
        guard let storage = textStorage else { return super.mouseDown(with: event) }
        let s = storage.string as NSString
        let box: (Int, String)? = [i, i - 1].lazy.compactMap { j -> (Int, String)? in
            guard j >= 0, j < s.length else { return nil }
            let c = s.substring(with: NSRange(location: j, length: 1))
            return c == "\u{2610}" ? (j, "\u{2611}") : (c == "\u{2611}" ? (j, "\u{2610}") : nil)
        }.first
        guard let (index, flipped) = box else { return super.mouseDown(with: event) }
        let r = NSRange(location: index, length: 1)
        guard shouldChangeText(in: r, replacementString: flipped) else { return }
        storage.replaceCharacters(in: r, with: flipped)
        didChangeText()
    }
}

final class EditorCoordinator: NSObject, NSTextViewDelegate {
    let note: Note
    var focused = false
    var zoom: NSObjectProtocol?
    private var busy = false

    init(_ note: Note) { self.note = note }

    func textDidChange(_ notification: Notification) {
        guard !busy, let tv = notification.object as? NSTextView, let storage = tv.textStorage else { return }
        busy = true
        defer { busy = false }

        let ns = storage.string as NSString
        let line = ns.paragraphRange(for: NSRange(location: min(tv.selectedRange().location, ns.length), length: 0))
        let s = ns.substring(with: line)
        var madeHeader = false

        if s.hasPrefix("// ") {
            replace(tv, NSRange(location: line.location, length: 3), "")
            let header = (tv.string as NSString).paragraphRange(for: NSRange(location: line.location, length: 0))
            storage.beginEditing()
            storage.addAttributes(Theme.header, range: header)
            storage.endEditing()
            madeHeader = true
        } else if s.hasPrefix("[] ") {
            replace(tv, NSRange(location: line.location, length: 3), "\u{2610} ")
        } else if s.hasPrefix("+ ") {
            replace(tv, NSRange(location: line.location, length: 2), "\u{2192} ")
        } else if line.location > 0, line.length > 0, s == "\n", isHeader(storage, line.location) {
            storage.beginEditing()
            storage.addAttributes(Theme.body, range: line)
            storage.endEditing()
        }

        NoteLayoutManager.restyle(storage)
        tv.typingAttributes = madeHeader ? Theme.header : typing(storage, tv.selectedRange().location)
        if !note.isDirty { note.isDirty = true }
        note.retitle()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard !busy, let tv = notification.object as? NSTextView, let storage = tv.textStorage else { return }
        tv.typingAttributes = typing(storage, tv.selectedRange().location)
    }

    func textView(_ tv: NSTextView, doCommandBy command: Selector) -> Bool {
        guard let storage = tv.textStorage else { return false }
        let ns = storage.string as NSString
        let caret = tv.selectedRange()
        let line = ns.paragraphRange(for: caret)
        let s = ns.substring(with: line)
        let text = s.hasSuffix("\n") ? String(s.dropLast()) : s

        if command == #selector(NSResponder.insertNewline(_:)), text == "--" || text == "---" {
            replace(tv, NSRange(location: line.location, length: (text as NSString).length), Theme.rule + "\n")
            return true
        }
        guard let m = Theme.markers.first(where: { s.hasPrefix($0) }) else { return false }

        if command == #selector(NSResponder.insertNewline(_:)) {
            if text == m {
                replace(tv, NSRange(location: line.location, length: 2), "")
            } else {
                replace(tv, caret, "\n" + (m == "\u{2611} " ? "\u{2610} " : m))
            }
            return true
        }
        if command == #selector(NSResponder.deleteBackward(_:)), caret.length == 0, caret.location == line.location + 2 {
            replace(tv, NSRange(location: line.location, length: 2), "")
            return true
        }
        return false
    }

    private func replace(_ tv: NSTextView, _ r: NSRange, _ s: String) {
        guard tv.shouldChangeText(in: r, replacementString: s) else { return }
        tv.textStorage?.replaceCharacters(in: r, with: s)
        tv.didChangeText()
    }

    private func isHeader(_ storage: NSTextStorage, _ location: Int) -> Bool {
        let ns = storage.string as NSString
        let line = ns.paragraphRange(for: NSRange(location: min(location, ns.length), length: 0))
        guard line.length > 0, line.location < storage.length else { return false }
        return Theme.matches(storage.attribute(.font, at: line.location, effectiveRange: nil) as? NSFont, Theme.headerFont)
    }

    func typing(_ storage: NSTextStorage, _ location: Int) -> [NSAttributedString.Key: Any] {
        let ns = storage.string as NSString
        let line = ns.paragraphRange(for: NSRange(location: min(location, ns.length), length: 0))
        var a = line.location == 0 || isHeader(storage, location) ? Theme.header : Theme.body
        if line.location == 0, ns.range(of: "\n").location != NSNotFound { a[.paragraphStyle] = Theme.centered }
        return a
    }
}

final class NoteLayoutManager: NSLayoutManager {
    static func isBox(_ c: unichar) -> Bool { c == 0x2610 || c == 0x2611 }

    static let covered = Theme.bodyFont.coveredCharacterSet as NSCharacterSet

    // ponytail: 18 is the calibration knob — the advance a box needs, per marker, whatever font falls back.
    static func kerns(_ font: NSFont, _ scale: CGFloat) -> [unichar: CGFloat] {
        ([0x2610, 0x2611] as [unichar]).reduce(into: [:]) {
            let w = (String(UnicodeScalar($1)!) as NSString).size(withAttributes: [.font: font]).width
            $0[$1] = max(0, 18 * scale - w)
        }
    }

    // ponytail: rescans the whole document on each keystroke; fine for note-sized documents.
    static func restyle(_ storage: NSTextStorage) {
        let ns = storage.string as NSString
        let full = NSRange(location: 0, length: ns.length)
        guard full.length > 0 else { return }
        let body = Theme.bodyFont, header = Theme.headerFont
        let kern = kerns(body, Theme.scale)
        let title = ns.paragraphRange(for: NSRange(location: 0, length: 0))
        let titleStyle = ns.range(of: "\n").location == NSNotFound ? Theme.paragraph : Theme.centered
        var rules = Set<Int>()
        ns.enumerateSubstrings(in: full, options: .byParagraphs) { s, r, _, _ in
            if s == Theme.rule { rules.insert(r.location) }
        }

        var edits: [(NSRange, [NSAttributedString.Key: Any])] = []
        var i = 0
        while i < full.length {
            var run = NSRange()
            let now = storage.attributes(at: i, longestEffectiveRange: &run, in: full)
            let font = now[.font] as? NSFont
            for j in run.location..<run.upperBound {
                let c = ns.character(at: j)
                let inTitle = j < title.upperBound
                let base = inTitle ? header : body
                var want: [NSAttributedString.Key: Any] = [:]

                var wanted: NSFont? = base
                if !covered.characterIsMember(c) {
                    // a symbol the text font cannot draw keeps its substituted face, only the size follows
                    wanted = font.flatMap { NSFont(descriptor: $0.fontDescriptor, size: base.pointSize) }
                } else if !inTitle, Theme.matches(font, header) {
                    wanted = header
                }
                if let w = wanted, font?.fontName != w.fontName || font?.pointSize != w.pointSize { want[.font] = w }

                let color: NSColor = isBox(c) || rules.contains(j) ? .clear : .textColor
                if now[.foregroundColor] as? NSColor != color { want[.foregroundColor] = color }

                let k = kern[c] ?? 0
                if (now[.kern] as? NSNumber)?.doubleValue ?? 0 != Double(k) { want[.kern] = k }

                let style = inTitle ? titleStyle : Theme.paragraph
                if now[.paragraphStyle] as? NSParagraphStyle != style { want[.paragraphStyle] = style }

                if !want.isEmpty { edits.append((NSRange(location: j, length: 1), want)) }
            }
            i = run.upperBound
        }
        guard !edits.isEmpty else { return }
        storage.beginEditing()
        for (r, a) in edits { storage.addAttributes(a, range: r) }
        storage.endEditing()
    }

    override func drawGlyphs(forGlyphRange range: NSRange, at origin: NSPoint) {
        super.drawGlyphs(forGlyphRange: range, at: origin)
        guard let storage = textStorage else { return }
        let ns = storage.string as NSString
        let chars = characterRange(forGlyphRange: range, actualGlyphRange: nil)
        let side = 14 * Theme.scale
        for i in chars.location..<min(chars.upperBound, ns.length) {
            let c = ns.character(at: i)
            let rule = c == 0x2015 && ns.substring(with: ns.paragraphRange(for: NSRange(location: i, length: 1)))
                .trimmingCharacters(in: .newlines) == Theme.rule
            guard NoteLayoutManager.isBox(c) || rule else { continue }
            let g = glyphRange(forCharacterRange: NSRange(location: i, length: 1), actualCharacterRange: nil)
            guard g.length > 0 else { continue }
            // the marker itself carries a substituted symbol font, so take the metrics from the text next to it
            let near = storage.attribute(.font, at: min(i + 1, ns.length - 1), effectiveRange: nil) as? NSFont
            let font = Theme.matches(near, Theme.headerFont) ? Theme.headerFont : Theme.bodyFont
            let fragment = lineFragmentRect(forGlyphAt: g.location, effectiveRange: nil)
            let glyph = location(forGlyphAt: g.location)
            let middle = origin.y + fragment.origin.y + glyph.y - font.capHeight / 2

            if rule {
                let y = (middle).rounded() + 0.5
                let line = NSBezierPath()
                line.lineWidth = 1
                line.move(to: NSPoint(x: origin.x + fragment.minX, y: y))
                line.line(to: NSPoint(x: origin.x + fragment.maxX, y: y))
                NSColor.separatorColor.setStroke()
                line.stroke()
                continue
            }

            let box = NSRect(x: origin.x + fragment.minX + glyph.x, y: middle - side / 2, width: side, height: side)
            if c == 0x2611 {
                NSColor.controlAccentColor.setFill()
                NSBezierPath(roundedRect: box, xRadius: side / 3.5, yRadius: side / 3.5).fill()
                let check = NSBezierPath()
                check.lineWidth = 1.8 * Theme.scale
                check.lineCapStyle = .round
                check.lineJoinStyle = .round
                check.move(to: NSPoint(x: box.minX + side * 0.25, y: box.midY + side * 0.015))
                check.line(to: NSPoint(x: box.minX + side * 0.41, y: box.midY + side * 0.2))
                check.line(to: NSPoint(x: box.maxX - side * 0.235, y: box.midY - side * 0.207))
                NSColor.white.setStroke()
                check.stroke()
            } else {
                let path = NSBezierPath(roundedRect: box.insetBy(dx: 0.75, dy: 0.75),
                                        xRadius: side / 3.5, yRadius: side / 3.5)
                path.lineWidth = 1.5
                NSColor.secondaryLabelColor.withAlphaComponent(0.6).setStroke()
                path.stroke()
            }
        }
    }
}
