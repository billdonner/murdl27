import MurdlCore
import SwiftUI

/// The docked letter keyboard: the only way to type on a device without a hardware keyboard.
/// Keys size from the width the parent passes in, capped for big iPads, never under 44 points tall.
struct BottomKeyboardView: View {
    @ObservedObject var game: MurdlGame
    let width: CGFloat
    private static let rows = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]
    private static let gap: CGFloat = 6
    private static let maxUnit: CGFloat = 56

    /// Ten keys and nine gaps across; the shorter rows share the same unit.
    private var unit: CGFloat { max(20, min(Self.maxUnit, floor((width - Self.gap * 9) / 10))) }
    private var keyHeight: CGFloat { max(44, floor(unit * 1.15)) }

    var body: some View {
        let font = MurdlTypography.keyboardLetterFont(game.keyboardFontStyle)
        let gap = Self.gap
        let height = keyHeight
        let wide = unit * 1.45
        VStack(spacing: gap) {
            HStack(spacing: gap) {
                letterButtons(Self.rows[0], height: height, font: font)
            }
            HStack(spacing: gap) {
                letterButtons(Self.rows[1], height: height, font: font)
                KeyboardCommandButton(title: "Clear letters", systemImage: "xmark", width: unit, height: height, iconSize: 16) {
                    game.clearGuess()
                }
            }
            HStack(spacing: gap) {
                KeyboardCommandButton(title: "Submit guess", systemImage: "return", width: wide, height: height, iconSize: 16) {
                    game.submitGuess()
                }
                letterButtons(Self.rows[2], height: height, font: font)
                KeyboardCommandButton(title: "Delete letter", systemImage: "delete.left", width: wide, height: height, iconSize: 16) {
                    game.deleteLetter()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .disabled(game.isOver || game.isShowingHelp)
        .opacity(game.isOver ? 0.55 : 1)
    }

    private func letterButtons(_ letters: String, height: CGFloat, font: Font) -> some View {
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
