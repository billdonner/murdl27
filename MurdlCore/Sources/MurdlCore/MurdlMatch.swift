import Foundation

/// Why a guess was refused.
public enum GuessError: Error, Equatable, Sendable {
    case gameOver
    case wrongLength
    case notInDictionary
}

/// What one played word did.
public struct PlayResult: Equatable, Sendable {
    public var solvedBoardIDs: [Int]
    public var lostBoardIDs: [Int]
}

/// The pure state of one multi-board game: boards, rows, key marks, and the rules that move
/// them. No timers, no persistence, no UI state. Front ends on any platform drive this.
public struct MurdlMatch: Equatable, Sendable {
    public static let wordLength = 5
    public static let boardCountOptions = [2, 4, 8, 16]
    public static let defaultBoardCount = 8
    /// Classic MURDL gives five more guesses than boards: 8 boards, 13 guesses.
    public static let extraGuesses = 5

    public let boardCount: Int
    public private(set) var boards: [MurdlBoard]
    public private(set) var currentRow = 0
    public private(set) var keyMarks: [String: TileMark] = [:]
    private let dictionary: WordDictionary

    public init(boardCount: Int, dictionary: WordDictionary = .bundled) {
        self.init(answers: dictionary.randomAnswers(count: boardCount), dictionary: dictionary)
    }

    /// Fixed answers, for tests and shared daily games.
    public init(answers: [String], dictionary: WordDictionary = .bundled) {
        self.boardCount = answers.count
        self.dictionary = dictionary
        let guesses = answers.count + Self.extraGuesses
        boards = answers.enumerated().map { index, answer in
            MurdlBoard(
                id: index,
                answer: answer.lowercased(),
                rows: Array(repeating: .empty(wordLength: Self.wordLength), count: guesses)
            )
        }
    }

    public var maxGuesses: Int { boardCount + Self.extraGuesses }
    public var isOver: Bool { boards.allSatisfy(\.isFinished) }
    public var didWin: Bool { boards.allSatisfy(\.isSolved) }
    public var guessesRemaining: Int { max(0, maxGuesses - currentRow) }
    public var solvedCount: Int { boards.filter(\.isSolved).count }
    public var nextUnfinishedBoard: MurdlBoard? { boards.first { !$0.isFinished } }

    /// One character per board: the row it was solved on, or `maxGuesses + 1` if missed.
    /// Rows 10 and up are written as letters starting at A so the score stays one character per board.
    /// Wins sort lowest first; losses sort highest first.
    public var scoreText: String {
        guard isOver else { return "" }
        let raw = boards.map { $0.solvedRow.map { $0 + 1 } ?? maxGuesses + 1 }
        let sorted = didWin ? raw.sorted() : raw.sorted(by: >)
        return sorted.map { String($0, radix: 36).uppercased() }.joined()
    }

    /// Checks a word without playing it.
    public func validate(_ word: String) -> GuessError? {
        if isOver { return .gameOver }
        if word.count != Self.wordLength { return .wrongLength }
        if !dictionary.contains(word) { return .notInDictionary }
        return nil
    }

    /// Scores `word` against every unfinished board and advances the row. Callers validate first;
    /// answers are always accepted so a helper can play them directly.
    @discardableResult
    public mutating func play(word: String) -> PlayResult {
        var result = PlayResult(solvedBoardIDs: [], lostBoardIDs: [])
        guard !isOver else { return result }
        let guess = word.lowercased()

        for index in boards.indices where !boards[index].isFinished {
            let scored = Self.score(guess: guess, answer: boards[index].answer)
            boards[index].rows[currentRow].tiles = scored
            mergeKeyMarks(scored)

            if scored.allSatisfy({ $0.mark == .correct }) {
                boards[index].solvedRow = currentRow
                result.solvedBoardIDs.append(index)
            } else if currentRow == maxGuesses - 1 {
                boards[index].isLost = true
                result.lostBoardIDs.append(index)
            }
        }

        currentRow += 1
        return result
    }

    /// Sprint ran out: every unfinished board is lost.
    public mutating func loseUnfinishedBoards() {
        for index in boards.indices where !boards[index].isFinished {
            boards[index].isLost = true
        }
    }

    /// The row as it should be drawn, with the letters being typed overlaid on the current row.
    public func visibleTiles(for board: MurdlBoard, row: Int, typing currentGuess: String) -> [Tile] {
        guard row == currentRow, !board.isFinished, !isOver else {
            return board.rows[row].tiles
        }
        var tiles = board.rows[row].tiles
        for (index, letter) in currentGuess.enumerated() where index < tiles.count {
            tiles[index] = Tile(letter: String(letter).uppercased(), mark: .editing)
        }
        return tiles
    }

    public func status(for board: MurdlBoard) -> String {
        if let solvedRow = board.solvedRow {
            return "Won \(solvedRow + 1)/\(maxGuesses)"
        }
        if board.isLost {
            return "Lost \(board.answer.uppercased())"
        }
        return "Ready \(min(currentRow + 1, maxGuesses))/\(maxGuesses)"
    }

    private mutating func mergeKeyMarks(_ tiles: [Tile]) {
        for tile in tiles where !tile.letter.isEmpty {
            let existing = keyMarks[tile.letter] ?? .empty
            if tile.mark > existing {
                keyMarks[tile.letter] = tile.mark
            }
        }
    }

    /// Wordle scoring: exact matches first, then leftover answer letters mark oranges left to right.
    public static func score(guess: String, answer: String) -> [Tile] {
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

        return zip(guessLetters, marks).map { Tile(letter: String($0), mark: $1) }
    }

    public static func == (lhs: MurdlMatch, rhs: MurdlMatch) -> Bool {
        lhs.boards == rhs.boards && lhs.currentRow == rhs.currentRow && lhs.keyMarks == rhs.keyMarks
    }
}
