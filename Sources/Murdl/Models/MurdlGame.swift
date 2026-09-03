import Foundation
import Combine

final class MurdlGame: ObservableObject {
    static let boardCount = 8
    static let wordLength = 5
    static let maxGuesses = 13

    private let dictionary: WordDictionary
    private static let keyboardFontDefaultsKey = "MurdlKeyboardFontStyle"

    @Published private(set) var boards: [MurdlBoard] = []
    @Published private(set) var currentGuess = ""
    @Published private(set) var currentRow = 0
    @Published private(set) var statusText = ""
    @Published private(set) var keyMarks: [String: TileMark] = [:]
    @Published private(set) var isShowingHelp = false
    @Published private(set) var isHelperMode = false
    /// Set by the last helper step; cleared whenever the player submits a guess themselves.
    @Published private(set) var helperMessage = ""
    @Published private(set) var keyboardFontStyle: KeyboardFontStyle

    init(dictionary: WordDictionary = .bundled) {
        self.dictionary = dictionary
        if let rawStyle = UserDefaults.standard.string(forKey: Self.keyboardFontDefaultsKey),
           let savedStyle = KeyboardFontStyle(rawValue: rawStyle) {
            keyboardFontStyle = savedStyle
        } else {
            keyboardFontStyle = .monospaced
        }
        startNewGame()
    }

    var isOver: Bool {
        boards.allSatisfy(\.isFinished)
    }

    var didWin: Bool {
        boards.allSatisfy(\.isSolved)
    }

    var guessesRemaining: Int {
        max(0, Self.maxGuesses - currentRow)
    }

    var solvedCount: Int {
        boards.filter(\.isSolved).count
    }

    /// One hex digit per board: the row it was solved on, or `maxGuesses + 1` if missed.
    var scoreText: String {
        guard isOver else { return "" }

        let rawScores = boards.map { board in
            if let solvedRow = board.solvedRow {
                return solvedRow + 1
            }
            return Self.maxGuesses + 1
        }

        let sortedScores = didWin ? rawScores.sorted() : rawScores.sorted(by: >)
        return sortedScores.map { String($0, radix: 16).uppercased() }.joined()
    }

    var helperTargetBoard: MurdlBoard? {
        guard isHelperMode else { return nil }
        return nextHelperBoard()
    }

    var helperFocusBoardID: Int? {
        helperTargetBoard?.id
    }

    var helperStepTitle: String {
        guard !isOver else { return "Helper Complete" }
        guard isHelperMode else { return "Play Helper Step" }
        guard let target = helperTargetBoard else { return "Helper Complete" }
        return "Play \(target.answer.uppercased())"
    }

    var helperSummary: String {
        guard isHelperMode else { return "Helper mode is off" }
        guard !isOver else { return helperFinishText }
        guard let target = helperTargetBoard else { return "No unfinished boards" }
        return "Next: Board \(target.id + 1) uses \(target.answer.uppercased())"
    }

    /// The headline shown in the helper bar: the last helper action if there is one, else the live summary.
    var helperHeadline: String {
        helperMessage.isEmpty ? helperSummary : helperMessage
    }

    private var helperFinishText: String {
        didWin ? "Helper finished MURDL \(scoreText)" : "Game over \(scoreText)"
    }

    func startNewGame() {
        let answers = dictionary.randomAnswers(count: Self.boardCount)
        boards = answers.enumerated().map { index, answer in
            MurdlBoard(
                id: index,
                answer: answer,
                rows: Array(repeating: .empty(wordLength: Self.wordLength), count: Self.maxGuesses)
            )
        }
        currentGuess = ""
        currentRow = 0
        statusText = "Ready"
        keyMarks = [:]
        helperMessage = ""
    }

    func showHelp() {
        isShowingHelp = true
    }

    func hideHelp() {
        isShowingHelp = false
    }

    func toggleHelperMode() {
        setHelperMode(!isHelperMode)
    }

    func setHelperMode(_ enabled: Bool) {
        isHelperMode = enabled
        helperMessage = ""

        if enabled {
            statusText = helperSummary
        } else if !isOver {
            statusText = "Helper mode off"
        }
    }

    /// Plays the next unfinished board's answer as a guess. Letters the player has typed are left in place.
    func playHelperStep() {
        if !isHelperMode {
            setHelperMode(true)
        }

        guard !isOver else {
            helperMessage = helperFinishText
            statusText = helperMessage
            return
        }

        guard let target = nextHelperBoard() else {
            helperMessage = "No unfinished boards"
            statusText = helperMessage
            return
        }

        let boardNumber = target.id + 1
        let answer = target.answer.uppercased()
        play(word: target.answer)

        if isOver {
            helperMessage = helperFinishText
        } else if let next = helperTargetBoard {
            helperMessage = "Solved Board \(boardNumber) with \(answer). Next: Board \(next.id + 1)."
        } else {
            helperMessage = "Solved Board \(boardNumber) with \(answer)."
        }

        statusText = helperMessage
    }

    func setKeyboardFontStyle(_ style: KeyboardFontStyle) {
        keyboardFontStyle = style
        UserDefaults.standard.set(style.rawValue, forKey: Self.keyboardFontDefaultsKey)
    }

    func cycleKeyboardFontStyle() {
        let styles = KeyboardFontStyle.allCases
        let currentIndex = styles.firstIndex(of: keyboardFontStyle) ?? 0
        setKeyboardFontStyle(styles[(currentIndex + 1) % styles.count])
    }

    func enter(_ rawLetter: String) {
        guard !isOver, currentGuess.count < Self.wordLength else { return }
        let letter = rawLetter.uppercased()
        guard letter.count == 1, let scalar = letter.unicodeScalars.first else { return }
        guard scalar.value >= 65 && scalar.value <= 90 else { return }

        currentGuess.append(letter)
        statusText = ""
    }

    func deleteLetter() {
        guard !isOver, !currentGuess.isEmpty else { return }
        currentGuess.removeLast()
        statusText = ""
    }

    func submitGuess() {
        guard !isOver else { return }
        guard currentGuess.count == Self.wordLength else {
            statusText = "Enter 5 letters"
            return
        }

        let guess = currentGuess.lowercased()
        guard dictionary.contains(guess) else {
            statusText = "\(currentGuess.uppercased()) is not in the dictionary"
            return
        }

        currentGuess = ""
        helperMessage = ""
        play(word: guess)
    }

    /// Scores `word` against every unfinished board and advances the row. Does not touch `currentGuess`.
    private func play(word: String) {
        for boardIndex in boards.indices {
            guard !boards[boardIndex].isFinished else { continue }

            let scoredTiles = Self.score(guess: word, answer: boards[boardIndex].answer)
            boards[boardIndex].rows[currentRow].tiles = scoredTiles
            mergeKeyMarks(scoredTiles)

            if scoredTiles.allSatisfy({ $0.mark == .correct }) {
                boards[boardIndex].solvedRow = currentRow
            } else if currentRow == Self.maxGuesses - 1 {
                boards[boardIndex].isLost = true
            }
        }

        currentRow += 1

        if didWin {
            statusText = "Won MURDL \(scoreText)"
        } else if isOver {
            statusText = "Lost MURDL \(scoreText)"
        } else {
            statusText = "\(solvedCount) of \(Self.boardCount) solved"
        }
    }

    func visibleTiles(for board: MurdlBoard, row: Int) -> [Tile] {
        guard row == currentRow, !board.isFinished, !isOver else {
            return board.rows[row].tiles
        }

        var tiles = board.rows[row].tiles
        for (index, letter) in currentGuess.enumerated() where index < tiles.count {
            tiles[index] = Tile(letter: String(letter), mark: .editing)
        }
        return tiles
    }

    func visibleRows(for board: MurdlBoard) -> [[Tile]] {
        (0..<Self.maxGuesses).map { visibleTiles(for: board, row: $0) }
    }

    func status(for board: MurdlBoard) -> String {
        if let solvedRow = board.solvedRow {
            return "Won \(solvedRow + 1)/\(Self.maxGuesses)"
        }
        if board.isLost {
            return "Lost \(board.answer.uppercased())"
        }
        return "Ready \(min(currentRow + 1, Self.maxGuesses))/\(Self.maxGuesses)"
    }

    private func mergeKeyMarks(_ tiles: [Tile]) {
        for tile in tiles {
            guard !tile.letter.isEmpty else { continue }
            let existing = keyMarks[tile.letter] ?? .empty
            if tile.mark > existing {
                keyMarks[tile.letter] = tile.mark
            }
        }
    }

    private func nextHelperBoard() -> MurdlBoard? {
        boards.first { !$0.isFinished }
    }

    private static func score(guess: String, answer: String) -> [Tile] {
        let guessLetters = Array(guess.uppercased())
        let answerLetters = Array(answer.uppercased())
        var marks = Array(repeating: TileMark.absent, count: wordLength)
        var remaining: [Character: Int] = [:]

        for index in 0..<wordLength {
            if guessLetters[index] == answerLetters[index] {
                marks[index] = .correct
            } else {
                remaining[answerLetters[index], default: 0] += 1
            }
        }

        for index in 0..<wordLength where marks[index] != .correct {
            let letter = guessLetters[index]
            if let count = remaining[letter], count > 0 {
                marks[index] = .present
                remaining[letter] = count - 1
            }
        }

        return zip(guessLetters, marks).map { letter, mark in
            Tile(letter: String(letter), mark: mark)
        }
    }
}
