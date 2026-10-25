import Foundation

/// Practice answers dealt without replacement: every answer comes up once before any repeats,
/// so a sixteen-board player goes about 144 games, not 5, before meeting a word again.
/// Only the seed and position are stored; the order is rebuilt from the seed.
public struct AnswerDeck: Codable, Equatable, Sendable {
    public private(set) var seed: UInt64
    public private(set) var position: Int

    public init(seed: UInt64 = .random(in: .min ... .max), position: Int = 0) {
        self.seed = seed
        self.position = position
    }

    /// The next `count` answers, all distinct. A spent deck is reshuffled from a seed derived
    /// from the old one; words this game already holds are passed over so boards never repeat.
    public mutating func deal(_ count: Int, from dictionary: WordDictionary) -> [String] {
        var order = dictionary.shuffledAnswers(seed: seed)
        guard !order.isEmpty else { return dictionary.randomAnswers(count: count) }
        // A pool smaller than the game cannot stay distinct.
        let distinct = count <= order.count
        var picks: [String] = []
        while picks.count < count {
            if position >= order.count {
                var generator = SeededGenerator(seed: seed)
                seed = generator.next()
                position = 0
                order = dictionary.shuffledAnswers(seed: seed)
            }
            let word = order[position]
            position += 1
            if !distinct || !picks.contains(word) {
                picks.append(word)
            }
        }
        return picks
    }
}
