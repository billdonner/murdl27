import MurdlCore
import SwiftUI

/// Two rows instead of the Mac's single wide strip: identity and score on top, controls below.
/// Rarely used actions live in a menu so the row fits an iPad in portrait.
struct IOSHeaderView: View {
    @ObservedObject var game: MurdlGame
    let showScores: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                MurdlLogo(size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text("MURDL")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(MurdlPalette.titleGradient)
                    Text("\(game.boardCount) boards  \(game.maxGuesses) guesses")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(game.solvedCount)/\(game.boardCount)")
                        .font(.system(size: 24, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(MurdlPalette.letter)
                    Text(game.scoreText.isEmpty ? "\(game.guessesRemaining) left" : game.scoreText)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Solved \(game.solvedCount) of \(game.boardCount), \(game.guessesRemaining) guesses left")

                if let clockText = game.clockText {
                    ClockView(text: clockText, mode: game.mode, remaining: game.sprintRemaining, isRunning: game.clock.isRunning, hasStarted: game.clock.hasStarted, isOver: game.isOver)
                }

                Menu {
                    Button(game.isHelperMode ? "Turn Off Helper Mode" : "Turn On Helper Mode", systemImage: "sparkles") {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                            game.toggleHelperMode()
                        }
                    }

                    Menu("Keyboard Font") {
                        ForEach(KeyboardFontStyle.allCases) { style in
                            Toggle(style.title, isOn: Binding(
                                get: { game.keyboardFontStyle == style },
                                set: { if $0 { game.setKeyboardFontStyle(style) } }
                            ))
                        }
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

            HStack(spacing: 12) {
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
                .frame(maxWidth: 220)
                .accessibilityLabel("Number of boards")

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
                .frame(maxWidth: 280)
                .accessibilityLabel("Game mode")

                Spacer(minLength: 8)

                HeaderButton(systemImage: game.boardLayout == .grid ? "rectangle.split.2x2" : "rectangle.split.3x1",
                             label: "Board layout: \(game.boardLayout.title)",
                             help: "Switch to \((game.boardLayout == .grid ? BoardLayout.strip : .grid).title) layout") {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        game.toggleBoardLayout()
                    }
                }

                HeaderButton(systemImage: "arrow.clockwise",
                             label: "New game",
                             help: "Start a new game") {
                    game.startNewGame()
                }
            }
        }
        .disabled(game.isShowingHelp)
    }
}
