import Foundation

public struct WordDictionary: Sendable {
    private let allowedWords: Set<String>
    private let answerWords: [String]

    /// The word lists shipped inside MurdlCore.
    public static let bundled = WordDictionary(
        allowedWords: WordDictionary.loadWords(named: "wordl5"),
        answerWords: WordDictionary.loadWords(named: "friendlies")
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

    public var answerCount: Int { answerWords.count }

    public func contains(_ word: String) -> Bool {
        allowedWords.contains(Self.normalize(word))
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
