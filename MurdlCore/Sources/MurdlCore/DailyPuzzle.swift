import Foundation

/// The shared puzzle of the day: everyone who plays MURDL Daily #N at a given board count gets
/// the same answers, derived from the day number and the board count, never from the clock.
public enum DailyPuzzle {
    /// Daily #1 is 2026-09-18 in the player's local calendar.
    public static let epoch = DateComponents(year: 2026, month: 9, day: 18)

    public static func number(for date: Date = Date(), calendar: Calendar = .current) -> Int {
        let start = calendar.date(from: epoch) ?? date
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: date)).day ?? 0
        return max(1, days + 1)
    }

    public static func answers(number: Int, boardCount: Int, from dictionary: WordDictionary) -> [String] {
        dictionary.answers(seed: UInt64(number) &* 1_000_003 &+ UInt64(boardCount), count: boardCount)
    }
}

/// SplitMix64: tiny, fast, and identical on every platform, which `SystemRandomNumberGenerator` is not.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
