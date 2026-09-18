import AppKit

extension Theme {
    static let markers = ["\u{2610} ", "\u{2611} ", "\u{2192} "]
    static let rule = "\u{2015}"

    static let paragraph: NSParagraphStyle = {
        let p = NSMutableParagraphStyle()
        p.lineSpacing = 4
        p.paragraphSpacing = 6
        return p
    }()

    static let centered: NSParagraphStyle = {
        let p = NSMutableParagraphStyle()
        p.setParagraphStyle(paragraph)
        p.alignment = .center
        return p
    }()

    static var body: [NSAttributedString.Key: Any] {
        [.font: bodyFont, .foregroundColor: NSColor.textColor, .paragraphStyle: paragraph]
    }

    static var header: [NSAttributedString.Key: Any] {
        [.font: headerFont, .foregroundColor: NSColor.textColor, .paragraphStyle: paragraph]
    }

    // name only: after a scale change the stored fonts carry the old point size
    static func matches(_ f: NSFont?, _ g: NSFont) -> Bool { f?.fontName == g.fontName }
}

extension Note {
    func markdown() -> String {
        var out: [String] = []
        var i = 0
        let head = Theme.headerFont
        for (n, p) in storage.string.components(separatedBy: "\n").enumerated() {
            let len = (p as NSString).length
            if p == Theme.rule {
                out.append("---")
            } else if n == 0 {
                out.append(p.isEmpty ? "" : "# " + p)
            } else if len > 0, i < storage.length,
                      Theme.matches(storage.attribute(.font, at: i, effectiveRange: nil) as? NSFont, head) {
                out.append("# " + p)
            } else if p.hasPrefix("\u{2610} ") {
                out.append("- [ ] " + String(p.dropFirst(2)))
            } else if p.hasPrefix("\u{2611} ") {
                out.append("- [x] " + String(p.dropFirst(2)))
            } else if p.hasPrefix("\u{2192} ") {
                out.append("- " + String(p.dropFirst(2)))
            } else {
                out.append(p)
            }
            i += len + 1
        }
        return out.joined(separator: "\n") + "\n"
    }

    func load(markdown: String) {
        var text = markdown
        if text.hasSuffix("\n") { text.removeLast() }
        let lines = text.components(separatedBy: "\n")
        let bullets = [("- [ ] ", "\u{2610} "), ("* [ ] ", "\u{2610} "),
                       ("- [x] ", "\u{2611} "), ("- [X] ", "\u{2611} "),
                       ("* [x] ", "\u{2611} "), ("* [X] ", "\u{2611} "),
                       ("- ", "\u{2192} "), ("* ", "\u{2192} ")]
        let out = NSMutableAttributedString()
        for (n, raw) in lines.enumerated() {
            var line = raw
            var attrs = n == 0 ? Theme.header : Theme.body
            if ["---", "***", "___"].contains(line) {
                line = Theme.rule
            } else if n == 0 {
                if line.hasPrefix("# ") { line = String(line.dropFirst(2)) }
            } else if let h = ["### ", "## ", "# "].first(where: { line.hasPrefix($0) }) {
                line = String(line.dropFirst(h.count))
                attrs = Theme.header
            } else if let b = bullets.first(where: { line.hasPrefix($0.0) }) {
                line = b.1 + String(line.dropFirst(b.0.count))
            }
            out.append(NSAttributedString(string: n == lines.count - 1 ? line : line + "\n", attributes: attrs))
        }
        storage.setAttributedString(out)
        NoteLayoutManager.restyle(storage)
        retitle()
        if isDirty { isDirty = false }
    }

    func retitle() {
        let first = storage.string.components(separatedBy: "\n")[0].trimmingCharacters(in: .whitespaces)
        let t = first.isEmpty || first == Theme.rule ? "Untitled" : String(first.prefix(30))
        if title != t { title = t }
    }
}
