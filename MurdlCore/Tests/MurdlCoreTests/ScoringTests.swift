import XCTest
@testable import MurdlCore

final class ScoringTests: XCTestCase {
    private func marks(_ guess: String, _ answer: String) -> [TileMark] {
        MurdlMatch.score(guess: guess, answer: answer).map(\.mark)
    }

    func testExactMatch() {
        XCTAssertEqual(marks("crane", "crane"), Array(repeating: .correct, count: 5))
    }

    func testNoMatch() {
        XCTAssertEqual(marks("crane", "-----"), Array(repeating: .absent, count: 5))
    }

    func testDuplicateLetterOnlyCountsOnce() {
        // THERE has two Es. EERIE: last E is exact, the first E is present, and the middle E is absent
        // because the answer has no third E. R is present, I absent.
        XCTAssertEqual(marks("eerie", "there"), [.present, .absent, .present, .absent, .correct])
    }

    func testExactMatchWinsOverPresent() {
        // Answer ABBEY: guess BABES. First B is present, second B is correct, E present.
        XCTAssertEqual(marks("babes", "abbey"), [.present, .present, .correct, .correct, .absent])
    }

    func testCaseInsensitive() {
        XCTAssertEqual(marks("CRANE", "crane"), Array(repeating: .correct, count: 5))
        XCTAssertEqual(MurdlMatch.score(guess: "crane", answer: "crane").map(\.letter), ["C", "R", "A", "N", "E"])
    }
}
