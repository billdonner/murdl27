import MurdlCore
import SwiftUI

/// iPad: identity and score on top, pickers and buttons below. iPhone: one row, with the
/// board count and mode as submenus of the More menu so the row fits a portrait phone.
struct IOSHeaderView: View {
    @ObservedObject var game: MurdlGame
    let showScores: () -> Void
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isCompact: Bool { sizeClass == .compact }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: isCompact ? 8 : 12) {
                MurdlLogo(size: isCompact ? 36 : 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text("MURDL")
                        .font(.system(size: isCompact ? 22 : 30, weight: .black, design: .rounded))
                        .foregroundStyle(MurdlPalette.titleGradient)
                    Text(game.subtitle)
                        .font(.system(size: isCompact ? 11 : 13, weight: .semibold, design: .rounded))
                        .lineLimit(2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(game.solvedCount)/\(game.boardCount)")
                        .font(.system(size: isCompact ? 20 : 24, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(MurdlPalette.letter)
                    Text(game.scoreText.isEmpty ? "\(game.guessesRemaining) left" : game.scoreText)
                        .font(.system(size: isCompact ? 11 : 13, weight: .semibold, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Solved \(game.solvedCount) of \(game.boardCount), \(game.guessesRemaining) guesses left")

                if let clockText = game.clockText {
                    ClockView(text: clockText, mode: game.mode, remaining: game.sprintRemaining, isRunning: game.clock.isRunning, hasStarted: game.clock.hasStarted, isOver: game.isOver)
                }

                if isCompact {
                    newGameButton
                }

                Menu {
                    Button("Today's Daily #\(game.todaysDailyNumber)", systemImage: "calendar") {
                        game.startDailyGame()
                    }
                    Button("New Practice Game", systemImage: "arrow.clockwise") {
                        game.startNewGame()
                    }
                    Divider()
                    if isCompact {
                        boardsMenu
                        modeMenu
                        Divider()
                    }

                    Button(game.isHelperMode ? "Turn Off Helper Mode" : "Turn On Helper Mode", systemImage: "sparkles") {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                            game.toggleHelperMode()
                        }
                    }

                    Toggle("High Contrast Colors", systemImage: "circle.lefthalf.filled", isOn: Binding(
                        get: { game.highContrast },
                        set: { game.setHighContrast($0) }
                    ))

                    Menu("Keyboard Font") {
                        ForEach(KeyboardFontStyle.allCases) { style in
                            Toggle(style.title, isOn: Binding(
                                get: { game.keyboardFontStyle == style },
                                set: { if $0 { game.setKeyboardFontStyle(style) } }
                            ))
                        }
                    }

                    ShareLink(item: game.shareText) {
                        Label("Share Board", systemImage: "square.and.arrow.up")
                    }

                    Button("Scores", systemImage: "list.number", action: showScores)

                    Button("Help", systemImage: "questionmark.circle") {
                        game.showHelp()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 22, weight: .bold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 8))
                .accessibilityLabel("More")
            }

            if !isCompact {
                HStack(spacing: 12) {
                    boardsPicker
                        .frame(maxWidth: 220)
                    modePicker
                        .frame(maxWidth: 280)

                    Spacer(minLength: 8)

                    HeaderButton(systemImage: "calendar", label: "Today's daily puzzle", help: "Play today's Daily, the same boards for everyone") {
                        game.startDailyGame()
                    }

                    HeaderButton(systemImage: game.boardLayout == .grid ? "rectangle.split.2x2" : "rectangle.split.3x1",
                                 label: "Board layout: \(game.boardLayout.title)",
                                 help: "Switch to \((game.boardLayout == .grid ? BoardLayout.strip : .grid).title) layout") {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            game.toggleBoardLayout()
                        }
                    }

                    newGameButton
                }
            }
        }
        .disabled(game.isShowingHelp)
    }

    private var newGameButton: some View {
        HeaderButton(systemImage: "arrow.clockwise", label: "New game", help: "Start a new game") {
            game.startNewGame()
        }
    }

    private var boardsPicker: some View {
        Picker("Boards", selection: Binding(
            get: { game.boardCount },
            set: { game.setBoardCount($0) }
        )) {
            ForEach(MurdlGame.boardCountOptions, id: \.self) { count in
                Text("\(count)").tag(count)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityLabel("Number of boards")
    }

    private var modePicker: some View {
        Picker("Mode", selection: Binding(
            get: { game.mode },
            set: { game.setMode($0) }
        )) {
            ForEach(GameMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityLabel("Game mode")
    }

    private var boardsMenu: some View {
        Menu("Boards: \(game.boardCount)", systemImage: "square.grid.2x2") {
            ForEach(MurdlGame.boardCountOptions, id: \.self) { count in
                Toggle("\(count) \(count == 1 ? "Board" : "Boards"), \(count + MurdlGame.extraGuesses) Guesses", isOn: Binding(
                    get: { game.boardCount == count },
                    set: { if $0 { game.setBoardCount(count) } }
                ))
            }
        }
    }

    private var modeMenu: some View {
        Menu("Mode: \(game.mode.title)", systemImage: "timer") {
            ForEach(GameMode.allCases) { mode in
                Toggle(mode.title, isOn: Binding(
                    get: { game.mode == mode },
                    set: { if $0 { game.setMode(mode) } }
                ))
            }
        }
    }
}
