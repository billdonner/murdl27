import XCTest
@testable import MurdlCore

final class ShareTextTests: XCTestCase {
    private let dictionary = WordDictionary(allowedWords: ["crane", "slate", "storm"], answerWords: ["crane", "slate"])

    func testSmallGameShowsEmojiRowsAndOutcome() {
        var match = MurdlMatch(answers: ["slate", "crane"], dictionary: dictionary)
        match.play(word: "crane")
        match.play(word: "slate")
        let text = match.shareText(note: "Stopwatch 0:42")
        XCTAssertTrue(text.hasPrefix("MURDL 2 boards: Solved all 2 in 2/7 guesses\nScore 12\nStopwatch 0:42\n\n"), text)
        XCTAssertTrue(text.contains("Board 1 ✅ row 2\n⬜⬜🟩⬜🟩\n🟩🟩🟩🟩🟩\n"), text)
        XCTAssertTrue(text.contains("Board 2 ✅ row 1\n🟩🟩🟩🟩🟩\n"), text)
        XCTAssertTrue(text.hasSuffix("billdonner.com/apps/murdl"))
    }

    func testBigGameListsOneLinePerBoardWhileOpen() {
        var match = MurdlMatch(answers: ["crane", "slate", "crane", "slate", "crane", "slate", "crane", "slate"], dictionary: dictionary)
        match.play(word: "storm")
        let text = match.shareText
        XCTAssertTrue(text.hasPrefix("MURDL 8 boards: 0 solved, 12 of 13 guesses left\n\n1. ⏳\n2. ⏳\n"), text)
        XCTAssertFalse(text.contains("🟩"))
    }

    func testLostBoardShowsItsAnswer() {
        var match = MurdlMatch(answers: ["crane"], dictionary: dictionary)
        for _ in 0..<6 { match.play(word: "storm") }
        let text = match.shareText
        XCTAssertTrue(text.hasPrefix("MURDL 1 board: Solved 0 of 1 in 6/6 guesses\n"), text)
        XCTAssertTrue(text.contains("Board 1 ❌ CRANE\n"), text)
    }
}
