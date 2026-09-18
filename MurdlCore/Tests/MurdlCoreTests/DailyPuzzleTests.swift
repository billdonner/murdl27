import XCTest
@testable import MurdlCore

final class DailyPuzzleTests: XCTestCase {
    private let dictionary = WordDictionary(allowedWords: [], answerWords: ["crane", "slate", "storm", "plant", "audio", "house", "point", "bloom"])

    func testSameDayAndCountGiveSameAnswersEverywhere() {
        let a = DailyPuzzle.answers(number: 12, boardCount: 4, from: dictionary)
        let b = DailyPuzzle.answers(number: 12, boardCount: 4, from: dictionary)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, 4)
        XCTAssertEqual(Set(a).count, 4, "answers must be distinct")
        XCTAssertNotEqual(a, DailyPuzzle.answers(number: 13, boardCount: 4, from: dictionary))
        XCTAssertNotEqual(a.prefix(2), DailyPuzzle.answers(number: 12, boardCount: 2, from: dictionary).prefix(2))
    }

    func testSeedIsStableAcrossRuns() {
        // Pinned: if this changes, everyone's daily changes. Recompute only for a deliberate reset.
        let picks = DailyPuzzle.answers(number: 1, boardCount: 2, from: dictionary)
        XCTAssertEqual(picks, ["plant", "house"])
    }

    func testNumberCountsDaysFromEpoch() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        let epoch = calendar.date(from: DailyPuzzle.epoch)!
        XCTAssertEqual(DailyPuzzle.number(for: epoch, calendar: calendar), 1)
        XCTAssertEqual(DailyPuzzle.number(for: epoch.addingTimeInterval(86_400 * 9 + 3600), calendar: calendar), 10)
        XCTAssertEqual(DailyPuzzle.number(for: epoch.addingTimeInterval(-86_400 * 5), calendar: calendar), 1)
    }

    func testDailyStreakCountsConsecutiveNumbersOnce() {
        func rec(_ n: Int?, win: Bool, day: Double) -> GameRecord {
            GameRecord(date: Date(timeIntervalSince1970: day * 86_400), boardCount: 4, solvedCount: win ? 4 : 2,
                       guessesUsed: 6, didWin: win, score: win ? "2345" : "9999", seconds: 30, mode: .classic,
                       assisted: false, timedOut: false, daily: n)
        }
        let records = [rec(5, win: true, day: 5), rec(5, win: false, day: 5.5), rec(4, win: true, day: 4),
                       rec(3, win: false, day: 3), rec(nil, win: true, day: 2), rec(1, win: true, day: 1)]
        let summary = ScoreSummary(records: records, boardCount: 4)
        XCTAssertEqual(summary.dailyPlayed, 4)
        XCTAssertEqual(summary.dailyWon, 3)
        XCTAssertEqual(summary.dailyStreak, 2, "days 5 and 4; the replay of day 5 does not count")
        XCTAssertEqual(summary.dailyBestStreak, 2)
    }

    func testRecordDecodesWithoutDaily() throws {
        let json = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","date":0,"boardCount":2,"solvedCount":2,"guessesUsed":3,"didWin":true,"score":"23","seconds":10}"#
        let record = try JSONDecoder().decode(GameRecord.self, from: Data(json.utf8))
        XCTAssertNil(record.daily)
    }
}
