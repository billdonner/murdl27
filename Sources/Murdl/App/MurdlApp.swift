import SwiftUI

@main
struct MurdlApp: App {
    static let keyboardWindowID = "keyboard"
    static let scoresWindowID = "scores"

    @StateObject private var game = MurdlGame()
    @State private var keyCapture = KeyCapture()
    @Environment(\.openWindow) private var openWindow

    /// Game commands stay off while the Help sheet is up so its keys cannot reach the board behind it.
    private var gameLocked: Bool {
        game.isOver || game.isShowingHelp
    }

    var body: some Scene {
        WindowGroup {
            ContentView(game: game)
                .frame(minWidth: 1160, minHeight: 640)
                .onAppear {
                    keyCapture.attach(to: game)
                    KeyboardWindowState.trackUntilQuit()
                    // With restoration enabled SwiftUI reopens the keyboard itself when there is saved
                    // state. On a first launch there is none, so open it once restoration has settled.
                    if KeyboardWindowState.isOpen {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            openWindow(id: Self.keyboardWindowID)
                        }
                    }
                }
        }
        .defaultSize(width: 1380, height: 820)
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(.presented)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Game") {
                    game.startNewGame()
                }
                .keyboardShortcut("n", modifiers: [.command])
                .disabled(game.isShowingHelp)

                Menu("Boards") {
                    ForEach(Array(MurdlGame.boardCountOptions.enumerated()), id: \.element) { index, count in
                        Toggle("\(count) Boards, \(count + MurdlGame.extraGuesses) Guesses", isOn: Binding(
                            get: { game.boardCount == count },
                            set: { if $0 { game.setBoardCount(count) } }
                        ))
                        .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [.command])
                    }
                }
                .disabled(game.isShowingHelp)

                Menu("Mode") {
                    ForEach(Array(GameMode.allCases.enumerated()), id: \.element) { index, mode in
                        Toggle(mode.title, isOn: Binding(
                            get: { game.mode == mode },
                            set: { if $0 { game.setMode(mode) } }
                        ))
                        .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [.command, .option])
                    }
                }
                .disabled(game.isShowingHelp)
            }

            CommandMenu("Game") {
                // Return and Delete are handled app-wide by KeyCapture; the shortcuts here document them.
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

                Button("Previous Board") { game.moveFocus(.left) }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                Button("Next Board") { game.moveFocus(.right) }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                Button("Board Above") { game.moveFocus(.up) }
                    .keyboardShortcut(.upArrow, modifiers: [])
                Button("Board Below") { game.moveFocus(.down) }
                    .keyboardShortcut(.downArrow, modifiers: [])
            }

            CommandGroup(after: .toolbar) {
                Menu("Board Layout") {
                    Toggle("Grid", isOn: Binding(
                        get: { game.boardLayout == .grid },
                        set: { if $0 { game.setBoardLayout(.grid) } }
                    ))
                    .keyboardShortcut("g", modifiers: [.command, .option])

                    Toggle("Horizontal Strip", isOn: Binding(
                        get: { game.boardLayout == .strip },
                        set: { if $0 { game.setBoardLayout(.strip) } }
                    ))
                    .keyboardShortcut("t", modifiers: [.command, .option])
                }

                Button("Toggle Board Layout") {
                    game.toggleBoardLayout()
                }
                .keyboardShortcut("l", modifiers: [.command])

                Menu("Keyboard Font") {
                    ForEach(Array(KeyboardFontStyle.allCases.enumerated()), id: \.element) { index, style in
                        Toggle(style.title, isOn: Binding(
                            get: { game.keyboardFontStyle == style },
                            set: { if $0 { game.setKeyboardFontStyle(style) } }
                        ))
                        .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [.command, .control])
                    }
                }

                Button("Next Keyboard Font") {
                    game.cycleKeyboardFontStyle()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }

            CommandGroup(after: .windowArrangement) {
                OpenWindowCommand(title: "Show Keyboard", windowID: Self.keyboardWindowID, key: "k", modifiers: [.command])
                OpenWindowCommand(title: "Show Scores", windowID: Self.scoresWindowID, key: "s", modifiers: [.command, .shift])
                Button("Clear Scores") {
                    game.clearRecords()
                }
                .disabled(game.records.isEmpty)
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

        Window("Scores", id: Self.scoresWindowID) {
            ScoresView(game: game)
        }
        .defaultSize(width: 760, height: 400)
        .defaultLaunchBehavior(.suppressed)
    }
}

private struct OpenWindowCommand: View {
    let title: String
    let windowID: String
    let key: KeyEquivalent
    let modifiers: EventModifiers
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(title) {
            openWindow(id: windowID)
        }
        .keyboardShortcut(key, modifiers: modifiers)
    }
}

/// Whether the floating keyboard was open when the app last quit, so it comes back the same way.
/// Recorded at termination rather than on window close, because quitting also closes windows.
@MainActor
enum KeyboardWindowState {
    private static let key = "MurdlKeyboardWindowOpen"
    private static var terminationToken: NSObjectProtocol?

    static var isOpen: Bool {
        get { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    static func trackUntilQuit() {
        guard terminationToken == nil else { return }
        terminationToken = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                isOpen = NSApp.windows.contains { $0.isVisible && $0.title == "Keyboard" }
            }
        }
    }
}
