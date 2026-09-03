import SwiftUI

/// Compact letter-status keyboard shown in its own floating window. Typing is handled
/// app-wide by `KeyCapture`; these keys are clickable for mouse-only play.
struct KeyboardView: View {
    @ObservedObject var game: MurdlGame
    private static let rows = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]

    static let unit: CGFloat = 28
    static let keyHeight: CGFloat = 30
    static let gap: CGFloat = 4

    var body: some View {
        let gap = Self.gap
        let unit = Self.unit
        let font = MurdlTypography.keyboardLetterFont(game.keyboardFontStyle)

        VStack(spacing: gap) {
            HStack(spacing: gap) {
                letterButtons(Self.rows[0], unit: unit, font: font)
            }
            HStack(spacing: gap) {
                letterButtons(Self.rows[1], unit: unit, font: font)
            }
            HStack(spacing: gap) {
                KeyboardCommandButton(title: "ENTER", systemImage: "return", width: unit * 1.45) {
                    game.submitGuess()
                }

                letterButtons(Self.rows[2], unit: unit, font: font)

                KeyboardCommandButton(title: "DELETE", systemImage: "delete.left", width: unit * 1.45) {
                    game.deleteLetter()
                }
            }
        }
        .padding(10)
        .background(MurdlPalette.background)
        .disabled(game.isOver || game.isShowingHelp)
        .opacity(game.isOver ? 0.55 : 1)
        .help("Letter status. Type on your real keyboard or click a key.")
    }

    private func letterButtons(_ letters: String, unit: CGFloat, font: Font) -> some View {
        ForEach(Array(letters).map(String.init), id: \.self) { letter in
            KeyboardLetterButton(
                letter: letter,
                mark: game.keyMarks[letter] ?? .empty,
                font: font,
                fontTitle: game.keyboardFontStyle.title,
                width: unit
            ) {
                game.enter(letter)
            }
        }
    }
}

private struct KeyboardLetterButton: View {
    let letter: String
    let mark: TileMark
    let font: Font
    let fontTitle: String
    let width: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(letter)
                .font(font)
                .frame(width: width, height: KeyboardView.keyHeight)
        }
        .buttonStyle(.plain)
        .foregroundStyle(MurdlPalette.keyText(for: mark))
        .background(MurdlPalette.keyFill(for: mark), in: RoundedRectangle(cornerRadius: 5))
        .accessibilityLabel("Letter \(letter)")
        .help("Type \(letter). Keyboard font: \(fontTitle)")
    }
}

private struct KeyboardCommandButton: View {
    let title: String
    let systemImage: String
    let width: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .heavy))
                .frame(width: width, height: KeyboardView.keyHeight)
        }
        .buttonStyle(.plain)
        .foregroundStyle(MurdlPalette.keyText(for: .empty))
        .background(MurdlPalette.commandKey, in: RoundedRectangle(cornerRadius: 5))
        .accessibilityLabel(title)
        .help(title)
    }
}
