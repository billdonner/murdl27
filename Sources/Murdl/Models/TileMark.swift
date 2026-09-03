import Foundation

enum TileMark: Int, Comparable {
    case empty = 0
    case editing = 1
    case absent = 2
    case present = 3
    case correct = 4

    static func < (lhs: TileMark, rhs: TileMark) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A single board cell. Identity is positional (board, row, column); tiles carry no id of their own.
struct Tile: Equatable {
    var letter: String
    var mark: TileMark

    static let empty = Tile(letter: "", mark: .empty)
}

struct GuessRow: Equatable {
    var tiles: [Tile]

    static func empty(wordLength: Int) -> GuessRow {
        GuessRow(tiles: Array(repeating: .empty, count: wordLength))
    }
}

struct MurdlBoard: Identifiable, Equatable {
    let id: Int
    let answer: String
    var rows: [GuessRow]
    var solvedRow: Int?
    var isLost = false

    var isSolved: Bool {
        solvedRow != nil
    }

    var isFinished: Bool {
        isSolved || isLost
    }
}
