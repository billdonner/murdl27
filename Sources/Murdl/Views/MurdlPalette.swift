import SwiftUI

enum MurdlTypography {
    static func keyboardLetterFont(_ style: KeyboardFontStyle) -> Font {
        switch style {
        case .system:
            return .system(size: 18, weight: .heavy, design: .default)
        case .rounded:
            return .system(size: 18, weight: .heavy, design: .rounded)
        case .monospaced:
            return .system(size: 18, weight: .heavy, design: .monospaced)
        case .serif:
            return .system(size: 18, weight: .heavy, design: .serif)
        }
    }
}

enum MurdlPalette {
    static let background = Color("GameBackGroundColor")
    static let panel = background.opacity(0.78)
    static let divider = Color.secondary.opacity(0.22)
    static let brand = Color("AccentColor")
    static let letter = Color("LetterForeGround")
    static let status = Color("BonusRowBackGround")
    static let correct = Color("MatchExactApple")
    static let present = Color("MatchWrongPosApple")
    static let absent = Color("NoMatchApple")
    static let commandKey = Color("KeyCapBackGround")
    static let keyForeground = Color("KeyCapForeGround")
    static let titleGradient = LinearGradient(
        colors: [boardAccent(0), boardAccent(1), boardAccent(2)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static func boardAccent(_ index: Int) -> Color {
        boardAccents[index % boardAccents.count]
    }

    static func idleTile(_ boardID: Int) -> Color {
        boardAccent(boardID).opacity(0.24)
    }

    static func editingTile(_ boardID: Int) -> Color {
        boardAccent(boardID).opacity(0.44)
    }

    /// Keys use the same three result colors as the tiles.
    static func keyFill(for mark: TileMark) -> Color {
        switch mark {
        case .empty, .editing:
            return commandKey
        case .absent:
            return absent
        case .present:
            return present
        case .correct:
            return correct
        }
    }

    static func keyText(for mark: TileMark) -> Color {
        switch mark {
        case .empty, .editing:
            return keyForeground
        default:
            return Color.white
        }
    }

    private static let boardAccents: [Color] = [
        Color(red: 0.10, green: 0.70, blue: 0.32),
        Color(red: 0.95, green: 0.55, blue: 0.08),
        Color(red: 0.10, green: 0.49, blue: 0.92),
        Color(red: 0.86, green: 0.22, blue: 0.32),
        Color(red: 0.56, green: 0.36, blue: 0.90),
        Color(red: 0.00, green: 0.63, blue: 0.67),
        Color(red: 0.83, green: 0.67, blue: 0.12),
        Color(red: 0.88, green: 0.32, blue: 0.62),
        Color(red: 0.36, green: 0.55, blue: 0.20),
        Color(red: 0.80, green: 0.36, blue: 0.10),
        Color(red: 0.24, green: 0.32, blue: 0.78),
        Color(red: 0.62, green: 0.14, blue: 0.20),
        Color(red: 0.40, green: 0.20, blue: 0.62),
        Color(red: 0.10, green: 0.45, blue: 0.48),
        Color(red: 0.60, green: 0.48, blue: 0.08),
        Color(red: 0.62, green: 0.22, blue: 0.44)
    ]
}
