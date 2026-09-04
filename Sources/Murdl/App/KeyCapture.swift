import AppKit

/// Routes unmodified letter, arrow, Return, and Delete key presses to the game from any of the app's
/// windows, so the player can type whether the board or the floating keyboard is in front.
@MainActor
final class KeyCapture {
    private var monitor: Any?

    func attach(to game: MurdlGame) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak game] event in
            guard let game, Self.handle(event, game: game) else { return event }
            return nil
        }
    }

    private static func handle(_ event: NSEvent, game: MurdlGame) -> Bool {
        let modifiers = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.shift, .capsLock, .function, .numericPad])
        guard modifiers.isEmpty else { return false }

        if game.isShowingHelp {
            // Escape closes Help; every other key stays with the sheet.
            guard event.keyCode == 53 else { return false }
            game.hideHelp()
            return true
        }

        switch event.keyCode {
        case 53: // Escape
            game.clearGuess()
            return true
        case 36, 76: // Return, keypad Enter
            game.submitGuess()
            return true
        case 51: // Delete
            game.deleteLetter()
            return true
        case 123:
            game.moveFocus(.left)
            return true
        case 124:
            game.moveFocus(.right)
            return true
        case 125:
            game.moveFocus(.down)
            return true
        case 126:
            game.moveFocus(.up)
            return true
        default:
            break
        }

        guard let characters = event.charactersIgnoringModifiers,
              characters.count == 1,
              let character = characters.first,
              character.isASCII, character.isLetter else { return false }
        game.enter(String(character))
        return true
    }
}
