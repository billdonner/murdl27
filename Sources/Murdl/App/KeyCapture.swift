import AppKit

/// Routes unmodified letter, Return, and Delete key presses to the game from any of the app's
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
        guard !game.isShowingHelp else { return false }
        let modifiers = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.shift, .capsLock])
        guard modifiers.isEmpty else { return false }

        switch event.keyCode {
        case 36, 76: // Return, keypad Enter
            game.submitGuess()
            return true
        case 51: // Delete
            game.deleteLetter()
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
