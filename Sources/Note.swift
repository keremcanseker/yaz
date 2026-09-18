import AppKit
import Combine

final class Note: ObservableObject, Identifiable {
    let id = UUID()
    let storage = NSTextStorage()
    @Published var fileURL: URL?
    @Published var isDirty = false
    @Published var title = "Untitled"
}

enum Theme {
    static var scale: CGFloat = (UserDefaults.standard.object(forKey: "fontScale") as? CGFloat) ?? 1 {
        didSet { UserDefaults.standard.set(scale, forKey: "fontScale") }
    }
    static var bodyFont: NSFont { NSFont(name: "Geist-Regular", size: 15 * scale) ?? .systemFont(ofSize: 15 * scale) }
    static var headerFont: NSFont { NSFont(name: "Geist-Medium", size: 22 * scale) ?? .systemFont(ofSize: 22 * scale, weight: .medium) }
    static let uiFont = NSFont(name: "Geist-Regular", size: 13) ?? .systemFont(ofSize: 13)
}

extension Notification.Name {
    static let yazScaleChanged = Notification.Name("yazScaleChanged")
}
