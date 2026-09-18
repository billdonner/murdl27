import Foundation

/// One finished game. Abandoned games (New Game mid-play) are not recorded.
public struct GameRecord: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var date: Date
    public var boardCount: Int
    public var solvedCount: Int
    public var guessesUsed: Int
    public var didWin: Bool
    public var score: String
    public var seconds: Int
    public var mode: GameMode = .classic
    /// Helper Mode was used at some point; excluded from streaks and best times.
    public var assisted = false
    public var timedOut = false
    /// Daily puzzle number when this was a Daily; nil for practice.
    public var daily: Int? = nil

    public var maxGuesses: Int { boardCount + MurdlMatch.extraGuesses }

    /// Counts toward wins, streaks, and best times.
    public var isHonestWin: Bool { didWin && !assisted }

    public var resultText: String {
        if assisted { return didWin ? "Helper" : "Helper, lost" }
        if timedOut { return "Time up \(solvedCount)/\(boardCount)" }
        return didWin ? "Won" : "Lost \(solvedCount)/\(boardCount)"
    }

    public var timeText: String {
        GameClock.format(TimeInterval(seconds))
    }

    private enum CodingKeys: String, CodingKey {
        case id, date, boardCount, solvedCount, guessesUsed, didWin, score, seconds, mode, assisted, timedOut, daily
    }

    public init(date: Date, boardCount: Int, solvedCount: Int, guessesUsed: Int, didWin: Bool,
                score: String, seconds: Int, mode: GameMode, assisted: Bool, timedOut: Bool, daily: Int? = nil) {
        self.date = date
        self.boardCount = boardCount
        self.solvedCount = solvedCount
        self.guessesUsed = guessesUsed
        self.didWin = didWin
        self.score = score
        self.seconds = seconds
        self.mode = mode
        self.assisted = assisted
        self.timedOut = timedOut
        self.daily = daily
    }

    /// Older records predate `mode`, `assisted`, `timedOut`, and `daily`.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        boardCount = try c.decode(Int.self, forKey: .boardCount)
        solvedCount = try c.decode(Int.self, forKey: .solvedCount)
        guessesUsed = try c.decode(Int.self, forKey: .guessesUsed)
        didWin = try c.decode(Bool.self, forKey: .didWin)
        score = try c.decode(String.self, forKey: .score)
        seconds = try c.decode(Int.self, forKey: .seconds)
        mode = try c.decodeIfPresent(GameMode.self, forKey: .mode) ?? .classic
        assisted = try c.decodeIfPresent(Bool.self, forKey: .assisted) ?? false
        timedOut = try c.decodeIfPresent(Bool.self, forKey: .timedOut) ?? false
        daily = try c.decodeIfPresent(Int.self, forKey: .daily)
    }
}

/// Aggregate stats over a set of records, newest first.
public struct ScoreSummary: Sendable {
    public let played: Int
    public let won: Int
    public let currentStreak: Int
    public let bestStreak: Int
    public let bestScore: String?
    /// Fastest unassisted timed win at the given board count.
    public let bestTime: Int?
    /// Daily puzzles at the given board count: played, won, and the run of consecutive daily
    /// numbers won ending at the most recent one.
    public let dailyPlayed: Int
    public let dailyWon: Int
    public let dailyStreak: Int
    public let dailyBestStreak: Int

    public var winPercent: Int {
        played == 0 ? 0 : Int((Double(won) / Double(played) * 100).rounded())
    }

    /// Helper games count as played but never as wins, and they break a streak.
    public init(records: [GameRecord], boardCount: Int) {
        played = records.count
        won = records.filter(\.isHonestWin).count

        var current = 0
        for record in records {
            guard record.isHonestWin else { break }
            current += 1
        }
        currentStreak = current

        var best = 0
        var run = 0
        for record in records.reversed() {
            run = record.isHonestWin ? run + 1 : 0
            best = max(best, run)
        }
        bestStreak = best

        bestScore = records.filter(\.isHonestWin).map(\.score).min()
        bestTime = records
            .filter { $0.isHonestWin && $0.mode.isTimed && $0.boardCount == boardCount }
            .map(\.seconds)
            .min()

        // One entry per daily number, newest first, first result only (a replay never counts).
        var seen = Set<Int>()
        let dailies = records
            .filter { $0.daily != nil && $0.boardCount == boardCount }
            .sorted { $0.date < $1.date }
            .filter { seen.insert($0.daily!).inserted }
            .sorted { $0.daily! > $1.daily! }
        dailyPlayed = dailies.count
        dailyWon = dailies.filter(\.isHonestWin).count

        var streak = 0
        var expected: Int?
        for record in dailies {
            guard record.isHonestWin, expected == nil || record.daily == expected else { break }
            streak += 1
            expected = record.daily! - 1
        }
        dailyStreak = streak

        var bestDaily = 0
        var dailyRun = 0
        var previous: Int?
        for record in dailies.reversed() {
            if record.isHonestWin, previous == nil || record.daily == previous! + 1 {
                dailyRun += 1
            } else {
                dailyRun = record.isHonestWin ? 1 : 0
            }
            bestDaily = max(bestDaily, dailyRun)
            previous = record.daily
        }
        dailyBestStreak = bestDaily
    }
}

public enum ScoreStore {
    private static let key = "MurdlGameRecords"

    public static func load(from defaults: UserDefaults = .standard) -> [GameRecord] {
        guard let data = defaults.data(forKey: key),
              let records = try? JSONDecoder().decode([GameRecord].self, from: data) else {
            return []
        }
        return records
    }

    public static func save(_ records: [GameRecord], to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: key)
        }
    }
}
