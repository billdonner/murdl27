import XCTest
@testable import MurdlCore

final class AnswerDeckTests: XCTestCase {
    private let words = ["crane", "slate", "storm", "plant", "audio", "house", "point", "bloom", "chimp", "robed"]
    private var dictionary: WordDictionary { WordDictionary(allowedWords: [], answerWords: words) }

    func testEveryAnswerOnceBeforeAnyRepeat() {
        var deck = AnswerDeck(seed: 7)
        let dealt = (0..<5).flatMap { _ in deck.deal(2, from: dictionary) }
        XCTAssertEqual(dealt.sorted(), words.sorted())
    }

    func testGamesStayDistinctAcrossAReshuffle() {
        var deck = AnswerDeck(seed: 3)
        for _ in 0..<200 {
            let game = deck.deal(4, from: dictionary)
            XCTAssertEqual(Set(game).count, 4)
        }
    }

    func testStoredDeckContinuesWhereItLeftOff() throws {
        var deck = AnswerDeck(seed: 11)
        _ = deck.deal(3, from: dictionary)
        var restored = try JSONDecoder().decode(AnswerDeck.self, from: JSONEncoder().encode(deck))
        XCTAssertEqual(restored, deck)
        XCTAssertEqual(restored.deal(4, from: dictionary), deck.deal(4, from: dictionary))
    }

    func testBundledPoolLastsALongTimeAtSixteenBoards() {
        var deck = AnswerDeck(seed: 99)
        var seen = Set<String>()
        var games = 0
        while true {
            let game = deck.deal(16, from: .bundled)
            if !seen.isDisjoint(with: game) { break }
            seen.formUnion(game)
            games += 1
        }
        XCTAssertEqual(games, WordDictionary.bundled.answerCount / 16)
    }

    func testBundledAnswersAreTheOriginalsPlusPracticeAdditions() {
        let bundled = WordDictionary.bundled
        XCTAssertEqual(bundled.answerCount, 2_309 + 338)
        let practice = Set(bundled.shuffledAnswers(seed: 1))
        XCTAssertEqual(practice.count, bundled.answerCount, "practice words must not repeat the original answers")
        XCTAssertTrue(practice.allSatisfy(bundled.contains), "every answer must be an allowed guess")
    }

    func testAWordNeverReturnsSoonAcrossAReshuffle() {
        var deck = AnswerDeck(seed: 5)
        let perPass = WordDictionary.bundled.answerCount / 16
        var lastGame: [String: Int] = [:]
        var shortest = Int.max
        for game in 0..<(perPass * 3) {
            for word in deck.deal(16, from: .bundled) {
                if let last = lastGame[word] { shortest = min(shortest, game - last) }
                lastGame[word] = game
            }
        }
        XCTAssertGreaterThanOrEqual(shortest, perPass * 3 / 4 - 2, "a word came back after \(shortest) games")
    }

    func testPoolSmallerThanTheGameStillFillsEveryBoard() {
        var deck = AnswerDeck(seed: 1)
        XCTAssertEqual(deck.deal(16, from: dictionary).count, 16)
    }
}
