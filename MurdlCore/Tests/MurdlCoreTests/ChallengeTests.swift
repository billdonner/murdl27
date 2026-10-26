import XCTest
@testable import MurdlCore

final class ChallengeTests: XCTestCase {
    private let carol = ChallengeEntry(name: "Carol", result: ChallengeResult(solved: 16, guesses: 19, seconds: 312))

    private func sixteen() -> Challenge {
        let answers = Array(WordDictionary.bundled.shuffledAnswers(seed: 7).prefix(16))
        return Challenge(id: "0badcafe", answers: answers, variant: .rescue, mode: .sprint, challenger: carol)
    }

    func testChallengeSurvivesTheWebLinkTheAppLinkAndTheBareCode() throws {
        let challenge = sixteen()
        XCTAssertEqual(Challenge(link: challenge.link), challenge)
        XCTAssertEqual(Challenge(link: try XCTUnwrap(URL(string: "murdl://c/\(challenge.code)"))), challenge)
        XCTAssertEqual(Challenge(code: " \(challenge.code)\n"), challenge)
        XCTAssertTrue(challenge.link.absoluteString.hasPrefix("https://1041soft.com/murdl/c/#"))
    }

    func testTheLinkDoesNotSpellOutTheAnswers() {
        let challenge = sixteen()
        for answer in challenge.answers {
            XCTAssertFalse(challenge.code.lowercased().contains(answer), answer)
        }
        // Sixteen boards still fit comfortably in a message.
        XCTAssertLessThan(challenge.link.absoluteString.count, 240)
    }

    func testAMangledLinkIsRefused() {
        var code = Array(sixteen().code)
        code[10] = code[10] == "A" ? "B" : "A"
        XCTAssertNil(Challenge(code: String(code)))
        XCTAssertNil(Challenge(code: String(sixteen().code.dropLast(3))))
        XCTAssertNil(Challenge(code: "hello"))
    }

    func testReplyCarriesBothResultsButNotTheAnswers() {
        let mike = ChallengeResult(solved: 16, guesses: 18, seconds: 400)
        let reply = sixteen().replying(as: "Mike|\nO'Neil", result: mike)
        let decoded = Challenge(code: reply.code)
        XCTAssertEqual(decoded, reply)
        XCTAssertEqual(decoded?.answers, [])
        XCTAssertEqual(decoded?.reply?.name, "Mike O'Neil")
        XCTAssertEqual(decoded?.challenger, carol)
        XCTAssertEqual(decoded?.id, "0badcafe")
        XCTAssertTrue(reply.message.contains("Mike O'Neil wins"), reply.message)
    }

    func testOutcomeOrder() {
        func r(_ solved: Int, _ guesses: Int, _ seconds: Int = 60, assisted: Bool = false) -> ChallengeResult {
            ChallengeResult(solved: solved, guesses: guesses, seconds: seconds, assisted: assisted)
        }
        XCTAssertEqual(Challenge.outcome(r(8, 13), vs: r(7, 10), mode: .classic), .won)
        XCTAssertEqual(Challenge.outcome(r(8, 12), vs: r(8, 11), mode: .classic), .lost)
        XCTAssertEqual(Challenge.outcome(r(8, 12, 50), vs: r(8, 12, 90), mode: .classic), .tied)
        XCTAssertEqual(Challenge.outcome(r(8, 12, 50), vs: r(8, 12, 90), mode: .stopwatch), .won)
        XCTAssertEqual(Challenge.outcome(r(8, 9, assisted: true), vs: r(1, 13), mode: .classic), .lost)
    }

    func testAnswersMissingFromAnOlderListCanStillBeTyped() {
        let old = WordDictionary(allowedWords: ["crane"], answerWords: ["crane"])
        XCTAssertFalse(old.contains("modus"))
        let widened = old.allowing(["MODUS", "crane"])
        XCTAssertTrue(widened.contains("modus"))
        XCTAssertEqual(widened.answerCount, 1)
        XCTAssertNil(MurdlMatch(answers: ["modus"], dictionary: widened).validate("modus"))
    }

    func testRecordsMergeByIDKeepingWhatEitherSideKnows() {
        let date = Date(timeIntervalSince1970: 1_000)
        let sent = ChallengeRecord(id: "a", date: date, sent: true, boardCount: 8, variant: .standard, mode: .classic,
                                   mine: carol.result)
        var answered = sent
        answered.date = date.addingTimeInterval(60)
        answered.mine = nil
        answered.opponent = "Mike"
        answered.theirs = ChallengeResult(solved: 8, guesses: 20, seconds: 1)
        let merged = ChallengeRecord.merge([sent], [answered])
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].opponent, "Mike")
        XCTAssertEqual(merged[0].mine, carol.result)
        XCTAssertEqual(merged[0].date, date)
        XCTAssertEqual(merged[0].outcome, .won)
    }
}
