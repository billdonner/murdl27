import Foundation

public enum TileMark: Int, Comparable, Sendable {
    case empty = 0
    case editing = 1
    case absent = 2
    case present = 3
    case correct = 4

    public static func < (lhs: TileMark, rhs: TileMark) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A single board cell. Identity is positional (board, row, column); tiles carry no id of their own.
public struct Tile: Equatable, Sendable {
    public var letter: String
    public var mark: TileMark

    public init(letter: String, mark: TileMark) {
        self.letter = letter
        self.mark = mark
    }

    public static let empty = Tile(letter: "", mark: .empty)
}

public struct GuessRow: Equatable, Sendable {
    public var tiles: [Tile]

    public static func empty(wordLength: Int) -> GuessRow {
        GuessRow(tiles: Array(repeating: .empty, count: wordLength))
    }
}

public struct MurdlBoard: Identifiable, Equatable, Sendable {
    public let id: Int
    public let answer: String
    public var rows: [GuessRow]
    public var solvedRow: Int?
    public var isLost = false

    public var isSolved: Bool {
        solvedRow != nil
    }

    public var isFinished: Bool {
        isSolved || isLost
    }
}
