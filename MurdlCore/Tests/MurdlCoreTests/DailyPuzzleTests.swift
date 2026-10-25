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
        // Pinned: if this changes, everyone's daily changes. Recompute only for a deliberate reset
        // (last reset 2026-10-25: Dailies walk quarter-blocked passes of all 2,647 answers).
        let picks = DailyPuzzle.answers(number: 1, boardCount: 2, from: dictionary)
        XCTAssertEqual(picks, ["storm", "point"])
    }

    func testNoDailyAnswerRepeatsUntilTheListIsUsed() {
        for boards in MurdlMatch.boardCountOptions {
            let days = DailyPuzzle.daysWithoutRepeat(boardCount: boards, in: .bundled)
            XCTAssertEqual(days, WordDictionary.bundled.answerCount / boards)
            let dealt = (1...days).flatMap { DailyPuzzle.answers(number: $0, boardCount: boards, from: .bundled) }
            XCTAssertEqual(Set(dealt).count, dealt.count, "\(boards) boards repeated a word within \(days) days")
        }
    }

    func testAWordNeverReturnsSoonAcrossAReshuffle() {
        let boards = 16
        let days = DailyPuzzle.daysWithoutRepeat(boardCount: boards, in: .bundled)
        var lastDay: [String: Int] = [:]
        var shortest = Int.max
        for day in 1...(days * 3) {
            for word in DailyPuzzle.answers(number: day, boardCount: boards, from: .bundled) {
                if let last = lastDay[word] { shortest = min(shortest, day - last) }
                lastDay[word] = day
            }
        }
        XCTAssertGreaterThanOrEqual(shortest, days * 3 / 4 - 2, "a word came back after \(shortest) days")
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
