import SwiftUI

private struct FrameKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

private let reorderSpring = Animation.spring(response: 0.3, dampingFraction: 0.8)

struct TabBar: View {
    @EnvironmentObject var state: AppState
    @State private var frames: [UUID: CGRect] = [:]
    @State private var dragID: UUID?
    @State private var dragOffset: CGFloat = 0
    @State private var dragAdjust: CGFloat = 0

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(state.notes) { note in
                    TabPill(note: note,
                            selected: note.id == state.selectedID,
                            select: { state.selectedID = note.id },
                            close: { state.selectedID = note.id; state.closeTab() })
                        .background {
                            GeometryReader { geo in
                                Color.clear.preference(key: FrameKey.self,
                                                       value: [note.id: geo.frame(in: .named("tabs"))])
                            }
                        }
                        .offset(x: dragID == note.id ? dragOffset : 0)
                        .scaleEffect(dragID == note.id ? 1.03 : 1)
                        .shadow(color: .black.opacity(dragID == note.id ? 0.18 : 0), radius: 5, y: 2)
                        .zIndex(dragID == note.id ? 1 : 0)
                        .gesture(
                            DragGesture(minimumDistance: 4)
                                .onChanged { value in
                                    if dragID != note.id { dragID = note.id; dragAdjust = 0 }
                                    dragOffset = value.translation.width + dragAdjust
                                    reorder(note.id)
                                }
                                .onEnded { _ in
                                    withAnimation(reorderSpring) {
                                        dragOffset = 0
                                        dragID = nil
                                    }
                                    dragAdjust = 0
                                }
                        )
                }
                Button { state.newTab() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.leading, 78)
            .padding(.trailing, 10)
            .frame(height: 32)
            .coordinateSpace(name: "tabs")
            .onPreferenceChange(FrameKey.self) { frames = $0 }
        }
        .frame(height: 32)
        .background { WindowDragArea() }
    }

    private func reorder(_ id: UUID) {
        guard let from = state.notes.firstIndex(where: { $0.id == id }), let rect = frames[id] else { return }
        if from > 0, let prev = frames[state.notes[from - 1].id], rect.midX < prev.midX {
            move(from: from, to: from - 1, shift: prev.width + 6)
        } else if from < state.notes.count - 1, let next = frames[state.notes[from + 1].id], rect.midX > next.midX {
            move(from: from, to: from + 2, shift: -(next.width + 6))
        }
    }

    private func move(from: Int, to: Int, shift: CGFloat) {
        dragAdjust += shift
        dragOffset += shift
        withAnimation(reorderSpring) {
            state.notes.move(fromOffsets: IndexSet(integer: from), toOffset: to)
        }
    }
}

struct TabPill: View {
    @ObservedObject var note: Note
    let selected: Bool
    let select: () -> Void
    let close: () -> Void
    @State private var hover = false

    var body: some View {
        HStack(spacing: 5) {
            Text(note.title)
                .font(Font(Theme.uiFont))
                .lineLimit(1)
            if hover {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .onTapGesture(perform: close)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .foregroundStyle(selected ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
        .background {
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.primary.opacity(selected ? 0.08 : hover ? 0.04 : 0))
        }
        .onHover { hover = $0 }
        .onTapGesture(perform: select)
    }
}

struct WindowDragArea: NSViewRepresentable {
    final class DragView: NSView {
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
        override func viewDidMoveToWindow() {
            guard let w = window else { return }
            w.styleMask.insert(.fullSizeContentView)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
        }
    }

    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
