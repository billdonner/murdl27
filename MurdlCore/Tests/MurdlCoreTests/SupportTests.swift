import XCTest
@testable import MurdlCore

final class SupportTests: XCTestCase {
    func testBundledDictionaryLoads() {
        let dictionary = WordDictionary.bundled
        XCTAssertGreaterThan(dictionary.answerCount, 2000)
        XCTAssertTrue(dictionary.contains("crane"))
        XCTAssertTrue(dictionary.contains("AALII")) // allowed but not an answer
        XCTAssertFalse(dictionary.contains("zzzzz"))
    }

    func testDictionaryNormalizesAndFallsBack() {
        let dictionary = WordDictionary(allowedWords: [" Crane\n", "toolong", "ab1de"], answerWords: [])
        XCTAssertTrue(dictionary.contains("crane"))
        XCTAssertFalse(dictionary.contains("toolong"))
        XCTAssertEqual(dictionary.answerCount, 8) // built-in fallback answers
        XCTAssertTrue(dictionary.contains("adieu"))
    }

    func testClockStartsOnceAndSurvivesPauses() {
        var clock = GameClock()
        let t0 = Date(timeIntervalSince1970: 1000)
        XCTAssertEqual(clock.elapsed(at: t0), 0)
        clock.start(at: t0)
        clock.pause(at: t0.addingTimeInterval(5))
        XCTAssertEqual(clock.elapsed(at: t0.addingTimeInterval(100)), 5)
        clock.resume(at: t0.addingTimeInterval(100))
        XCTAssertEqual(clock.elapsed(at: t0.addingTimeInterval(103)), 8)
        clock.start(at: t0.addingTimeInterval(200)) // no-op once started
        XCTAssertEqual(clock.elapsed(at: t0.addingTimeInterval(103)), 8)
    }

    func testClockFormat() {
        XCTAssertEqual(GameClock.format(0), "0:00")
        XCTAssertEqual(GameClock.format(65.9), "1:05")
        XCTAssertEqual(GameClock.format(-3), "0:00")
    }

    func testSprintBudget() {
        XCTAssertEqual(GameMode.sprintBudget(boards: 8), 360)
        XCTAssertTrue(GameMode.sprint.isTimed)
        XCTAssertFalse(GameMode.classic.isTimed)
    }

    private func record(win: Bool, assisted: Bool = false, mode: GameMode = .classic, boards: Int = 8, seconds: Int = 60, score: String = "12345678") -> GameRecord {
        GameRecord(date: Date(), boardCount: boards, solvedCount: win ? boards : boards - 1, guessesUsed: 10,
                   didWin: win, score: score, seconds: seconds, mode: mode, assisted: assisted, timedOut: false)
    }

    func testSummaryExcludesAssistedGamesFromWinsAndStreaks() {
        // Newest first.
        let records = [
            record(win: true, mode: .stopwatch, seconds: 90),
            record(win: true, assisted: true),
            record(win: true, mode: .stopwatch, seconds: 70),
            record(win: false),
        ]
        let summary = ScoreSummary(records: records, boardCount: 8)
        XCTAssertEqual(summary.played, 4)
        XCTAssertEqual(summary.won, 2)
        XCTAssertEqual(summary.winPercent, 50)
        XCTAssertEqual(summary.currentStreak, 1) // the helper game broke the streak
        XCTAssertEqual(summary.bestStreak, 1)
        XCTAssertEqual(summary.bestTime, 70)
        XCTAssertEqual(ScoreSummary(records: records, boardCount: 4).bestTime, nil)
    }

    func testOldRecordsDecodeWithDefaults() throws {
        let json = """
        [{"id":"7B0E7B4E-1E3B-4F2E-9B6C-0C6B3E0B7C11","date":0,"boardCount":8,"solvedCount":8,"guessesUsed":9,"didWin":true,"score":"12345679","seconds":42}]
        """
        let records = try JSONDecoder().decode([GameRecord].self, from: Data(json.utf8))
        XCTAssertEqual(records[0].mode, .classic)
        XCTAssertFalse(records[0].assisted)
        XCTAssertTrue(records[0].isHonestWin)
    }

    func testScoreStoreRoundTrip() {
        let defaults = UserDefaults(suiteName: "MurdlCoreTests.\(UUID().uuidString)")!
        let records = [record(win: true)]
        ScoreStore.save(records, to: defaults)
        XCTAssertEqual(ScoreStore.load(from: defaults), records)
    }
}
