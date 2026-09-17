import MurdlCore
import SwiftUI

/// The docked letter keyboard: the only way to type on a device without a hardware keyboard.
/// Keys size from the available width, capped for big iPads, and never drop under 44 points tall.
struct BottomKeyboardView: View {
    @ObservedObject var game: MurdlGame
    private static let rows = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]
    private static let gap: CGFloat = 6
    private static let maxUnit: CGFloat = 56

    var body: some View {
        let font = MurdlTypography.keyboardLetterFont(game.keyboardFontStyle)
        GeometryReader { proxy in
            // Ten keys and nine gaps across; the shorter rows share the same unit.
            let unit = min(Self.maxUnit, floor((proxy.size.width - Self.gap * 9) / 10))
            keyboard(unit: unit, font: font)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(height: Self.keyHeight(forUnit: Self.maxUnit) * 3 + Self.gap * 2)
        .disabled(game.isOver || game.isShowingHelp)
        .opacity(game.isOver ? 0.55 : 1)
    }

    private static func keyHeight(forUnit unit: CGFloat) -> CGFloat {
        max(44, floor(unit * 1.15))
    }

    private func keyboard(unit: CGFloat, font: Font) -> some View {
        let gap = Self.gap
        let height = Self.keyHeight(forUnit: unit)
        let wide = unit * 1.45
        return VStack(spacing: gap) {
            HStack(spacing: gap) {
                letterButtons(Self.rows[0], unit: unit, height: height, font: font)
            }
            HStack(spacing: gap) {
                letterButtons(Self.rows[1], unit: unit, height: height, font: font)
                KeyboardCommandButton(title: "Clear letters", systemImage: "xmark", width: unit, height: height, iconSize: 16) {
                    game.clearGuess()
                }
            }
            HStack(spacing: gap) {
                KeyboardCommandButton(title: "Submit guess", systemImage: "return", width: wide, height: height, iconSize: 16) {
                    game.submitGuess()
                }
                letterButtons(Self.rows[2], unit: unit, height: height, font: font)
                KeyboardCommandButton(title: "Delete letter", systemImage: "delete.left", width: wide, height: height, iconSize: 16) {
                    game.deleteLetter()
                }
            }
        }
    }

    private func letterButtons(_ letters: String, unit: CGFloat, height: CGFloat, font: Font) -> some View {
        ForEach(Array(letters).map(String.init), id: \.self) { letter in
            KeyboardLetterButton(
                letter: letter,
                mark: game.keyMarks[letter] ?? .empty,
                font: font,
                fontTitle: game.keyboardFontStyle.title,
                width: unit,
                height: height
            ) {
                game.enter(letter)
            }
        }
    }
}
