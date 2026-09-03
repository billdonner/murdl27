import SwiftUI

@main
struct MurdlApp: App {
    @StateObject private var game = MurdlGame()

    /// Game commands stay off while the Help sheet is up so its keys cannot reach the board behind it.
    private var gameLocked: Bool {
        game.isOver || game.isShowingHelp
    }

    var body: some Scene {
        WindowGroup {
            ContentView(game: game)
                .frame(minWidth: 1160, minHeight: 760)
        }
        .defaultSize(width: 1380, height: 820)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Game") {
                    game.startNewGame()
                }
                .keyboardShortcut("n", modifiers: [.command])
                .disabled(game.isShowingHelp)

                Picker("Boards", selection: Binding(
                    get: { game.boardCount },
                    set: { game.setBoardCount($0) }
                )) {
                    ForEach(MurdlGame.boardCountOptions, id: \.self) { count in
                        Text("\(count) Boards, \(count + MurdlGame.extraGuesses) Guesses").tag(count)
                    }
                }
                .disabled(game.isShowingHelp)
            }

            CommandMenu("Game") {
                Button("Submit Guess") {
                    game.submitGuess()
                }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(gameLocked)

                Button("Delete Letter") {
                    game.deleteLetter()
                }
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(gameLocked || game.currentGuess.isEmpty)

                Divider()

                Button(game.isHelperMode ? "Turn Off Helper Mode" : "Turn On Helper Mode") {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                        game.toggleHelperMode()
                    }
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
                .disabled(game.isShowingHelp)

                Button(game.helperStepTitle) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                        game.playHelperStep()
                    }
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(gameLocked)

                Divider()

                Button("Keyboard Font: \(game.keyboardFontStyle.title)") {
                    game.cycleKeyboardFontStyle()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .help) {
                Button("MURDL Help") {
                    game.showHelp()
                }
                .keyboardShortcut("/", modifiers: [.command])
            }
        }
    }
}
