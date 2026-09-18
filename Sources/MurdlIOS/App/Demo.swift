#if DEBUG
import Foundation
import MurdlCore

/// Screenshot scenarios for the simulator, where nothing can type. Launch the Debug build with
/// `SIMCTL_CHILD_MURDL_DEMO=<scenario>` and the app plays real guesses through the normal API.
/// Compiled only into Debug builds; App Store archives never carry it.
@MainActor
enum Demo {
    static let scenario = ProcessInfo.processInfo.environment["MURDL_DEMO"]

    static func run(game: MurdlGame, showScores: @escaping () -> Void) {
        guard let scenario else { return }
        switch scenario {
        case "eight":
            start(game, boards: 8, mode: .classic)
            play(game, words: ["CRANE", "SLATE", "POINT"], answersOf: [1, 4, 6], typing: "STO")
        case "sixteen":
            start(game, boards: 16, mode: .classic)
            play(game, words: ["CRANE", "SLATE", "POINT", "AUDIO"], answersOf: [0, 2, 5, 9, 13], typing: "HOU")
        case "sprint":
            start(game, boards: 4, mode: .sprint)
            play(game, words: ["CRANE", "SLATE"], answersOf: [2], typing: "PO")
        case "helper":
            start(game, boards: 4, mode: .classic)
            play(game, words: ["CRANE", "STORM"], answersOf: [], typing: "")
            game.setHelperMode(true)
            game.playHelperStep()
        case "scores":
            // Paced so the recorded times are real, not 0:00. About 40 seconds in total.
            Task {
                game.clearRecords()
                for boards in [2, 4, 8, 4, 2] {
                    start(game, boards: boards, mode: .stopwatch)
                    for word in (boards == 4 ? ["CRANE"] : []) + game.boards.map(\.answer) {
                        submit(game, word)
                        try? await Task.sleep(for: .seconds(boards == 8 ? 2.5 : 1.5))
                    }
                }
                start(game, boards: 8, mode: .classic)
                showScores()
            }
        default:
            break
        }
    }

    private static func start(_ game: MurdlGame, boards: Int, mode: GameMode) {
        game.setMode(mode)
        game.setBoardCount(boards)
        game.startNewGame()
    }

    /// Generic words first so solved boards show a few misses above the answer.
    private static func play(_ game: MurdlGame, words: [String], answersOf ids: [Int], typing: String) {
        for word in words {
            submit(game, word)
        }
        for id in ids where id < game.boards.count {
            submit(game, game.boards[id].answer)
        }
        game.clearGuess()
        for letter in typing {
            game.enter(String(letter))
        }
    }

    private static func submit(_ game: MurdlGame, _ word: String) {
        game.clearGuess()
        for letter in word {
            game.enter(String(letter))
        }
        game.submitGuess()
    }
}
#endif
