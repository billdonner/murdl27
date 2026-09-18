import Foundation

extension MurdlMatch {
    /// A plain-text picture of the match for pasting into a message. Small games get the full
    /// emoji grid of every board; bigger games get one line per board so the text stays short.
    /// `note` is an extra line under the headline, such as the mode and clock.
    public var shareText: String { shareText(note: nil) }

    public func shareText(note: String?) -> String {
        var lines: [String] = []
        let noun = boardCount == 1 ? "board" : "boards"
        if isOver {
            let outcome = didWin ? "Solved all \(boardCount)" : "Solved \(solvedCount) of \(boardCount)"
            lines.append("MURDL \(boardCount) \(noun): \(outcome) in \(currentRow)/\(maxGuesses) guesses")
            if !scoreText.isEmpty {
                lines.append("Score \(scoreText)")
            }
        } else {
            lines.append("MURDL \(boardCount) \(noun): \(solvedCount) solved, \(guessesRemaining) of \(maxGuesses) guesses left")
        }
        if let note, !note.isEmpty {
            lines.append(note)
        }
        lines.append("")
        if boardCount <= 4 {
            for board in boards {
                lines.append("Board \(board.id + 1) \(Self.summary(of: board))")
                lines.append(contentsOf: board.rows.prefix(Self.playedRows(of: board)).map { Self.emoji(for: $0) })
                lines.append("")
            }
        } else {
            for board in boards {
                lines.append("\(board.id + 1). \(Self.summary(of: board))")
            }
            lines.append("")
        }
        lines.append("billdonner.com/apps/murdl")
        return lines.joined(separator: "\n")
    }

    private static func summary(of board: MurdlBoard) -> String {
        if let row = board.solvedRow { return "✅ row \(row + 1)" }
        if board.isLost { return "❌ \(board.answer.uppercased())" }
        return "⏳"
    }

    /// Rows that hold a played guess: a solved board stops at its solved row, a lost board keeps
    /// every row, an open board keeps the rows with letters on them.
    private static func playedRows(of board: MurdlBoard) -> Int {
        if let row = board.solvedRow { return row + 1 }
        return board.rows.filter { row in row.tiles.contains { $0.mark != .empty && $0.mark != .editing } }.count
    }

    private static func emoji(for row: GuessRow) -> String {
        row.tiles.map { tile in
            switch tile.mark {
            case .correct: return "🟩"
            case .present: return "🟧"
            case .absent: return "⬜"
            case .empty, .editing: return "▫️"
            }
        }.joined()
    }
}
