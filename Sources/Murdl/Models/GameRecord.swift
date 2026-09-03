import Foundation

/// One finished game. Abandoned games (New Game mid-play) are not recorded.
struct GameRecord: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var boardCount: Int
    var solvedCount: Int
    var guessesUsed: Int
    var didWin: Bool
    var score: String
    var seconds: Int

    var maxGuesses: Int { boardCount + MurdlGame.extraGuesses }

    var resultText: String {
        didWin ? "Won" : "Lost \(solvedCount)/\(boardCount)"
    }

    var timeText: String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return minutes > 0 ? "\(minutes)m \(remainder)s" : "\(remainder)s"
    }
}

/// Aggregate stats over a set of records.
struct ScoreSummary {
    let played: Int
    let won: Int
    let currentStreak: Int
    let bestStreak: Int
    let bestScore: String?

    var winPercent: Int {
        played == 0 ? 0 : Int((Double(won) / Double(played) * 100).rounded())
    }

    init(records: [GameRecord]) {
        played = records.count
        won = records.filter(\.didWin).count

        var current = 0
        for record in records {
            guard record.didWin else { break }
            current += 1
        }
        currentStreak = current

        var best = 0
        var run = 0
        for record in records.reversed() {
            run = record.didWin ? run + 1 : 0
            best = max(best, run)
        }
        bestStreak = best

        bestScore = records.filter(\.didWin).map(\.score).min()
    }
}

enum ScoreStore {
    private static let key = "MurdlGameRecords"

    static func load() -> [GameRecord] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let records = try? JSONDecoder().decode([GameRecord].self, from: data) else {
            return []
        }
        return records
    }

    static func save(_ records: [GameRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
