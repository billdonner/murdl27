import Foundation

/// A plain, serializable picture of a match for front ends that talk JSON, such as a Windows
/// shell calling the C bridge. Answers are included so a helper can be built on the other side.
public struct MatchSnapshot: Codable, Equatable, Sendable {
    public struct Cell: Codable, Equatable, Sendable {
        public var letter: String
        /// "empty", "editing", "absent", "present", or "correct".
        public var mark: String
    }

    public struct Board: Codable, Equatable, Sendable {
        public var id: Int
        public var answer: String
        public var solvedRow: Int?
        public var isLost: Bool
        public var status: String
        public var rows: [[Cell]]
    }

    public var boardCount: Int
    public var maxGuesses: Int
    public var currentRow: Int
    public var guessesRemaining: Int
    public var solvedCount: Int
    public var isOver: Bool
    public var didWin: Bool
    public var score: String
    public var keyMarks: [String: String]
    public var boards: [Board]

    public init(_ match: MurdlMatch, typing currentGuess: String = "") {
        boardCount = match.boardCount
        maxGuesses = match.maxGuesses
        currentRow = match.currentRow
        guessesRemaining = match.guessesRemaining
        solvedCount = match.solvedCount
        isOver = match.isOver
        didWin = match.didWin
        score = match.scoreText
        keyMarks = match.keyMarks.mapValues(Self.name)
        boards = match.boards.map { board in
            Board(
                id: board.id,
                answer: board.answer,
                solvedRow: board.solvedRow,
                isLost: board.isLost,
                status: match.status(for: board),
                rows: (0..<match.maxGuesses).map { row in
                    match.visibleTiles(for: board, row: row, typing: currentGuess)
                        .map { Cell(letter: $0.letter, mark: Self.name($0.mark)) }
                }
            )
        }
    }

    public static func name(_ mark: TileMark) -> String {
        switch mark {
        case .empty: return "empty"
        case .editing: return "editing"
        case .absent: return "absent"
        case .present: return "present"
        case .correct: return "correct"
        }
    }

    public func json() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(self), as: UTF8.self)
    }
}
