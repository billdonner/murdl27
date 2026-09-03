import Foundation

enum KeyboardFontStyle: String, CaseIterable, Identifiable {
    case system
    case rounded
    case monospaced
    case serif

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .rounded:
            return "Rounded"
        case .monospaced:
            return "Monospaced"
        case .serif:
            return "Serif"
        }
    }
}
