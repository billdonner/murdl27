import XCTest
@testable import MurdlCore

final class VariantTests: XCTestCase {
    private let dictionary = WordDictionary(allowedWords: ["crane", "sloth", "chimp", "robed", "slant", "storm"], answerWords: ["crane", "slate"])

    func testSequenceWidensTheBudget() {
        XCTAssertEqual(GameVariant.sequence.extraGuesses(boards: 1), 6)
        XCTAssertEqual(GameVariant.sequence.extraGuesses(boards: 4), 6)
        XCTAssertEqual(GameVariant.sequence.extraGuesses(boards: 8), 7)
        XCTAssertEqual(GameVariant.sequence.extraGuesses(boards: 16), 9)
        XCTAssertEqual(GameVariant.rescue.extraGuesses(boards: 16), 5)
        let match = MurdlMatch(answers: ["crane", "slate"], extraGuesses: 6, dictionary: dictionary)
        XCTAssertEqual(match.maxGuesses, 8)
        XCTAssertEqual(match.boards[0].rows.count, 8)
    }

    func testRescueOpenersAreValidGuesses() {
        for boards in MurdlMatch.boardCountOptions {
            for word in GameVariant.rescue.openers(boards: boards) {
                XCTAssertTrue(dictionary.contains(word), word)
            }
        }
        XCTAssertEqual(GameVariant.rescue.openers(boards: 2).count, 2)
        XCTAssertEqual(GameVariant.rescue.openers(boards: 8).count, 3)
        XCTAssertTrue(GameVariant.sequence.openers(boards: 8).isEmpty)
    }

    func testRecordDecodesWithoutVariantAndKeepsBudget() throws {
        let json = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","date":0,"boardCount":8,"solvedCount":8,"guessesUsed":9,"didWin":true,"score":"12345678","seconds":10}"#
        let record = try JSONDecoder().decode(GameRecord.self, from: Data(json.utf8))
        XCTAssertEqual(record.variant, .standard)
        XCTAssertEqual(record.maxGuesses, 13)
    }
}

final class ScoreStoreTests: XCTestCase {
    private func rec(_ day: Double, id: UUID = UUID(), guesses: Int = 5) -> GameRecord {
        GameRecord(date: Date(timeIntervalSince1970: day * 86_400), boardCount: 4, solvedCount: 4, guessesUsed: guesses,
                   didWin: true, score: "2345", seconds: 30, mode: .classic, assisted: false, timedOut: false)
    }

    func testMergeUnionsByIDNewestFirstAndHonorsClear() {
        let shared = rec(5)
        let local = [shared, rec(3)]
        let remote = [rec(7), shared, rec(1)]
        let merged = ScoreStore.merge(local, remote, clearedAt: Date(timeIntervalSince1970: 2 * 86_400))
        XCTAssertEqual(merged.map { Int($0.date.timeIntervalSince1970 / 86_400) }, [7, 5, 3])
        XCTAssertEqual(merged.filter { $0.id == shared.id }.count, 1)
    }

    func testDistributionCountsHonestWinsByGuesses() {
        let records = [rec(1, guesses: 5), rec(2, guesses: 5), rec(3, guesses: 7)]
        let summary = ScoreSummary(records: records, boardCount: 4)
        XCTAssertEqual(summary.distribution, [5: 2, 7: 1])
        XCTAssertTrue(ScoreSummary(records: records, boardCount: 8).distribution.isEmpty)
    }

    func testEncodeCapsAtSyncLimit() throws {
        let many = (0..<(ScoreStore.syncLimit + 10)).map { rec(Double($0)) }
        let decoded = ScoreStore.decode(ScoreStore.encode(many))
        XCTAssertEqual(decoded.count, ScoreStore.syncLimit)
    }
}
