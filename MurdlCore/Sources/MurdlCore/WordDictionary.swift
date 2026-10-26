import Foundation

public struct WordDictionary: Sendable {
    private let allowedWords: Set<String>
    private let answerWords: [String]

    /// The word lists shipped inside MurdlCore: the original answers plus the `practice.txt` additions.
    public static let bundled = WordDictionary(
        allowedWords: WordDictionary.loadWords(named: "wordl5"),
        answerWords: WordDictionary.loadWords(named: "friendlies") + WordDictionary.loadWords(named: "practice")
    )

    public init(allowedWords: [String], answerWords: [String]) {
        let normalizedAllowed = WordDictionary.normalized(words: allowedWords)
        let normalizedAnswers = WordDictionary.normalized(words: answerWords)
        let fallbackAnswers = [
            "adieu", "storm", "timer", "crane",
            "plant", "fable", "score", "light"
        ]

        if normalizedAnswers.isEmpty {
            Self.report("No answer words loaded; falling back to \(fallbackAnswers.count) built-in answers")
        }

        let finalAnswers = normalizedAnswers.isEmpty ? fallbackAnswers : normalizedAnswers
        // Every answer is always an allowed guess, so the helper can play answers directly.
        self.allowedWords = Set(normalizedAllowed).union(finalAnswers)
        self.answerWords = finalAnswers
    }

    /// `base` with extra allowed guesses; see `allowing(_:)`.
    init(adding words: [String], to base: WordDictionary) {
        allowedWords = base.allowedWords.union(words)
        answerWords = base.answerWords
    }

    public var answerCount: Int { answerWords.count }

    public func contains(_ word: String) -> Bool {
        allowedWords.contains(Self.normalize(word))
    }

    /// Quarters a pass through the answers is split into; see `shuffledAnswers(seed:)`.
    static let passBlocks = 4

    /// Every answer once, in an order fixed by the seed: the same on every device, because the
    /// answers are sorted first (file order does not matter) and the generator is SplitMix64.
    /// Each word belongs to one fixed quarter of the pass and only the order within a quarter
    /// changes, so a word dealt late in one pass cannot open the next: it returns at least three
    /// quarters of a pass later, even across a reshuffle.
    func shuffledAnswers(seed: UInt64) -> [String] {
        var fixed = SeededGenerator(seed: 0x4D55_5244_4C21)
        let words = answerWords.sorted().shuffled(using: &fixed)
        let size = max(1, (words.count + Self.passBlocks - 1) / Self.passBlocks)
        var generator = SeededGenerator(seed: seed)
        return stride(from: 0, to: words.count, by: size).flatMap { start in
            words[start..<min(start + size, words.count)].shuffled(using: &generator)
        }
    }

    public func randomAnswers(count: Int) -> [String] {
        let shuffled = answerWords.shuffled()
        if shuffled.count >= count {
            return Array(shuffled.prefix(count))
        }

        var answers = shuffled
        while answers.count < count {
            answers.append(answerWords.randomElement() ?? "adieu")
        }
        return answers
    }

    private static func loadWords(named name: String) -> [String] {
        guard let url = Bundle.module.url(forResource: name, withExtension: "txt", subdirectory: "Dictionaries") else {
            report("Dictionary resource \(name).txt is missing from MurdlCore")
            return []
        }

        do {
            return try String(contentsOf: url, encoding: .utf8).components(separatedBy: .newlines)
        } catch {
            report("Dictionary resource \(name).txt could not be read: \(error)")
            return []
        }
    }

    private static func report(_ message: String) {
        FileHandle.standardError.write(Data("MurdlCore: \(message)\n".utf8))
    }

    private static func normalized(words: [String]) -> [String] {
        words.map(Self.normalize).filter(Self.isFiveLetterASCIIWord)
    }

    private static func normalize(_ word: String) -> String {
        word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func isFiveLetterASCIIWord(_ word: String) -> Bool {
        guard word.count == 5 else { return false }
        return word.unicodeScalars.allSatisfy { scalar in
            scalar.value >= 97 && scalar.value <= 122
        }
    }
}
