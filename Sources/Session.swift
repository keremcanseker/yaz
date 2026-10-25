import AppKit

// Snapshot of every open tab, written every 2s and on quit, restored on launch.
// whole-session rewrite each tick; fine for a handful of notes.
extension AppState {
    private struct Saved: Codable { var text: String; var path: String?; var selected: Bool; var dirty: Bool? }

    private static var sessionURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("yaz")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("session.json")
    }

    func restoreSession() {
        let url = Self.sessionURL
        guard let data = try? Data(contentsOf: url) else { return }
        guard let saved = try? JSONDecoder().decode([Saved].self, from: data) else {
            // Unreadable: move it aside so the next autosave doesn't overwrite it.
            let bad = url.appendingPathExtension("bad")
            try? FileManager.default.removeItem(at: bad)
            try? FileManager.default.moveItem(at: url, to: bad)
            return
        }
        guard !saved.isEmpty else { return }
        notes = saved.map { s in
            let n = Note()
            n.fileURL = s.path.map { URL(fileURLWithPath: $0) }
            // Clean file tab: the file may have changed while yaz was closed, so disk wins.
            let dirty = s.dirty ?? true
            let disk = dirty ? nil : n.fileURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) }
            n.load(markdown: disk ?? s.text)
            n.isDirty = dirty
            return n
        }
        selectedID = notes[saved.firstIndex { $0.selected } ?? 0].id
    }

    func persistSession() {
        let saved = notes.map { Saved(text: $0.markdown(), path: $0.fileURL?.path, selected: $0.id == selectedID, dirty: $0.isDirty) }
        guard let data = try? JSONEncoder().encode(saved), data != lastSession else { return }
        try? data.write(to: Self.sessionURL, options: .atomic)
        lastSession = data
    }

    func startSessionAutosave() {
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.persistSession() }
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: nil) { [weak self] _ in self?.persistSession() }
    }
}
