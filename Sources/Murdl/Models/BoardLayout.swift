import Foundation

/// How boards are arranged in the main window.
enum BoardLayout: String, CaseIterable, Identifiable {
    /// Rows of up to eight boards; scrolls vertically when they do not fit.
    case grid
    /// A single row of boards; scrolls horizontally when they do not fit.
    case strip

    var id: String { rawValue }

    var title: String {
        switch self {
        case .grid: return "Grid"
        case .strip: return "Horizontal Strip"
        }
    }
}

enum BoardDirection {
    case left, right, up, down
}
