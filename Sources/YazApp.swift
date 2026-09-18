import SwiftUI
import UniformTypeIdentifiers

final class AppState: ObservableObject {
    @Published var notes = [Note()]
    @Published var selectedID = UUID()

    init() { selectedID = notes[0].id }

    var selected: Note? { notes.first { $0.id == selectedID } }

    func newTab() {
        let note = Note()
        notes.append(note)
        selectedID = note.id
    }

    func closeTab() {
        guard let i = notes.firstIndex(where: { $0.id == selectedID }) else { return }
        notes.remove(at: i)
        if !notes.isEmpty { selectedID = notes[min(i, notes.count - 1)].id }
    }

    func save() {
        guard let note = selected else { return }
        if note.fileURL == nil {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [UTType(filenameExtension: "md")!]
            panel.nameFieldStringValue = note.title + ".md"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            note.fileURL = url
        }
        try? note.markdown().write(to: note.fileURL!, atomically: true, encoding: .utf8)
        note.isDirty = false
    }

    func saveAs() {
        selected?.fileURL = nil
        save()
    }

    func open() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md")!, .plainText]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let existing = notes.first(where: { $0.fileURL == url }) {
                selectedID = existing.id
                continue
            }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let note = Note()
            note.fileURL = url
            note.load(markdown: text)
            notes.append(note)
            selectedID = note.id
        }
    }

    func zoom(_ step: CGFloat) {
        Theme.scale = min(2.5, max(0.6, Theme.scale + step))
        NotificationCenter.default.post(name: .yazScaleChanged, object: nil)
    }

    func select(offset: Int) {
        guard let i = notes.firstIndex(where: { $0.id == selectedID }) else { return }
        selectedID = notes[(i + offset + notes.count) % notes.count].id
    }

    func select(index: Int) {
        if notes.indices.contains(index) { selectedID = notes[index].id }
    }
}

@main
struct YazApp: App {
    @StateObject var state = AppState()

    var body: some Scene {
        Window("yaz", id: "main") {
            ContentView().environmentObject(state)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Tab") { state.newTab() }.keyboardShortcut("t")
                Button("Open…") { state.open() }.keyboardShortcut("o")
                Button("Close Tab") { state.closeTab() }.keyboardShortcut("w")
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save") { state.save() }.keyboardShortcut("s")
                Button("Save As…") { state.saveAs() }.keyboardShortcut("s", modifiers: [.command, .shift])
            }
            CommandMenu("View") {
                Button("Bigger") { state.zoom(0.1) }.keyboardShortcut("=")
                Button("Bigger") { state.zoom(0.1) }.keyboardShortcut("+", modifiers: .command)
                Button("Smaller") { state.zoom(-0.1) }.keyboardShortcut("-")
                Button("Actual Size") { state.zoom(1 - Theme.scale) }.keyboardShortcut("0")
            }
            CommandMenu("Tabs") {
                Button("Next Tab") { state.select(offset: 1) }.keyboardShortcut("]", modifiers: [.command, .shift])
                Button("Previous Tab") { state.select(offset: -1) }.keyboardShortcut("[", modifiers: [.command, .shift])
                Divider()
                ForEach(1..<10) { i in
                    Button("Tab \(i)") { state.select(index: i - 1) }
                        .keyboardShortcut(KeyEquivalent(Character(String(i))), modifiers: .command)
                }
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            TabBar()
            if let note = state.selected {
                Editor(note: note).id(note.id)
            } else {
                VStack(spacing: 6) {
                    Text("Nothing open")
                    HStack(spacing: 16) {
                        Button("New note  ⌘T") { state.newTab() }
                        Button("Open  ⌘O") { state.open() }
                    }
                    .buttonStyle(.plain)
                }
                .font(Font(Theme.uiFont))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .ignoresSafeArea(edges: .top)
    }
}
