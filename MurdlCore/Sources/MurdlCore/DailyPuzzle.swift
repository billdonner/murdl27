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

    /// Dailies at one board count walk through a shuffled pass of the answers, `boardCount` words
    /// a day, so no word repeats within a pass and none returns sooner than three quarters of a
    /// pass later (see `WordDictionary.shuffledAnswers`). A pass holds whole days only: the few
    /// words that would not fill a day sit out, picked at random each pass so none sits out for
    /// good. A day never straddles two passes, so any day is computed directly.
    public static func answers(number: Int, boardCount: Int, from dictionary: WordDictionary) -> [String] {
        let daysPerCycle = daysWithoutRepeat(boardCount: boardCount, in: dictionary)
        let day = max(0, number - 1)
        let cycle = day / daysPerCycle, slot = day % daysPerCycle
        let seed = UInt64(cycle) &* 1_000_003 &+ UInt64(boardCount)
        var order = dictionary.shuffledAnswers(seed: seed)
        guard !order.isEmpty else { return Array(repeating: "adieu", count: boardCount) }
        let spare = order.count - daysPerCycle * boardCount
        if spare > 0 {
            var generator = SeededGenerator(seed: ~seed)
            let sitOut = Set(order.indices.shuffled(using: &generator).prefix(spare))
            order = order.indices.filter { !sitOut.contains($0) }.map { order[$0] }
        }
        return (0..<boardCount).map { order[(slot * boardCount + $0) % order.count] }
    }

    /// Days in a row, at one board count, before any Daily answer can repeat.
    public static func daysWithoutRepeat(boardCount: Int, in dictionary: WordDictionary) -> Int {
        max(1, dictionary.answerCount / boardCount)
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
