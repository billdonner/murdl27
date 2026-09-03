import SwiftUI

@main
struct MurdlApp: App {
    static let keyboardWindowID = "keyboard"

    @StateObject private var game = MurdlGame()
    @State private var keyCapture = KeyCapture()

    /// Game commands stay off while the Help sheet is up so its keys cannot reach the board behind it.
    private var gameLocked: Bool {
        game.isOver || game.isShowingHelp
    }

    var body: some Scene {
        WindowGroup {
            ContentView(game: game)
                .frame(minWidth: 1160, minHeight: 640)
                .onAppear { keyCapture.attach(to: game) }
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
                .disabled(gameLocked)

                Button("Delete Letter") {
                    game.deleteLetter()
                }
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

            CommandGroup(after: .windowArrangement) {
                ShowKeyboardCommand()
            }

            CommandGroup(replacing: .help) {
                Button("MURDL Help") {
                    game.showHelp()
                }
                .keyboardShortcut("/", modifiers: [.command])
            }
        }

        Window("Keyboard", id: Self.keyboardWindowID) {
            KeyboardView(game: game)
        }
        .windowResizability(.contentSize)
        .windowLevel(.floating)
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
        .defaultPosition(.bottomTrailing)
        .defaultLaunchBehavior(.presented)
        .restorationBehavior(.disabled)
    }
}

private struct ShowKeyboardCommand: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Show Keyboard") {
            openWindow(id: MurdlApp.keyboardWindowID)
        }
        .keyboardShortcut("k", modifiers: [.command])
    }
}
