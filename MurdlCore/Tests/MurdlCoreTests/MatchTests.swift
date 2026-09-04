import XCTest
@testable import MurdlCore

final class MatchTests: XCTestCase {
    private let dictionary = WordDictionary(allowedWords: ["crane", "slate", "plant", "storm", "aaaaa"], answerWords: ["crane", "slate"])

    func testGuessBudgetIsBoardsPlusFive() {
        XCTAssertEqual(MurdlMatch(answers: ["crane", "slate"], dictionary: dictionary).maxGuesses, 7)
        XCTAssertEqual(MurdlMatch(boardCount: 16, dictionary: dictionary).maxGuesses, 21)
    }

    func testValidation() {
        let match = MurdlMatch(answers: ["crane"], dictionary: dictionary)
        XCTAssertEqual(match.validate("cran"), .wrongLength)
        XCTAssertEqual(match.validate("zzzzz"), .notInDictionary)
        XCTAssertNil(match.validate("SLATE"))
    }

    func testPlaySolvesOnlyMatchingBoards() {
        var match = MurdlMatch(answers: ["crane", "slate"], dictionary: dictionary)
        let result = match.play(word: "crane")
        XCTAssertEqual(result.solvedBoardIDs, [0])
        XCTAssertEqual(match.solvedCount, 1)
        XCTAssertEqual(match.currentRow, 1)
        XCTAssertFalse(match.isOver)
        XCTAssertEqual(match.status(for: match.boards[0]), "Won 1/7")
        XCTAssertEqual(match.status(for: match.boards[1]), "Ready 2/7")
    }

    func testSolvedBoardsIgnoreLaterGuesses() {
        var match = MurdlMatch(answers: ["crane", "slate"], dictionary: dictionary)
        match.play(word: "crane")
        match.play(word: "plant")
        XCTAssertEqual(match.boards[0].rows[1].tiles.map(\.letter), ["", "", "", "", ""])
        XCTAssertEqual(match.boards[1].rows[1].tiles.map(\.letter), ["P", "L", "A", "N", "T"])
    }

    func testWinScoreSortsLowestFirstInBase36() {
        var match = MurdlMatch(answers: ["slate", "crane"], dictionary: dictionary)
        match.play(word: "crane")
        match.play(word: "slate")
        XCTAssertTrue(match.didWin)
        XCTAssertEqual(match.scoreText, "12")
    }

    func testLossScoreMarksMissedBoardsAsOnePastLastRow() {
        var match = MurdlMatch(answers: ["slate", "crane"], dictionary: dictionary)
        match.play(word: "crane")
        for _ in 0..<6 { match.play(word: "storm") }
        XCTAssertTrue(match.isOver)
        XCTAssertFalse(match.didWin)
        XCTAssertTrue(match.boards[0].isLost)
        // Missed board scores 8, solved board scored 1; losses sort highest first.
        XCTAssertEqual(match.scoreText, "81")
    }

    func testLettersPastRow9UseLetters() {
        var match = MurdlMatch(boardCount: 8, dictionary: WordDictionary(allowedWords: [], answerWords: ["crane", "slate"]))
        XCTAssertEqual(match.maxGuesses, 13)
        for _ in 0..<13 { match.play(word: "storm") }
        XCTAssertEqual(match.scoreText, String(repeating: "E", count: 8))
    }

    func testKeyMarksKeepTheBestResultAcrossBoards() {
        var match = MurdlMatch(answers: ["crane", "storm"], dictionary: dictionary)
        match.play(word: "slate")
        XCTAssertEqual(match.keyMarks["S"], .correct) // correct on STORM beats absent on CRANE
        XCTAssertEqual(match.keyMarks["T"], .present) // present on STORM beats absent on CRANE
        XCTAssertEqual(match.keyMarks["L"], .absent)
    }

    func testTypedLettersOverlayOnlyTheCurrentRowOfOpenBoards() {
        var match = MurdlMatch(answers: ["crane", "slate"], dictionary: dictionary)
        match.play(word: "crane")
        let solved = match.visibleTiles(for: match.boards[0], row: 1, typing: "st")
        let open = match.visibleTiles(for: match.boards[1], row: 1, typing: "st")
        XCTAssertEqual(solved.map(\.letter), ["", "", "", "", ""])
        XCTAssertEqual(open.prefix(2).map(\.mark), [.editing, .editing])
        XCTAssertEqual(open.prefix(2).map(\.letter), ["S", "T"])
    }

    func testLoseUnfinishedBoards() {
        var match = MurdlMatch(answers: ["crane", "slate"], dictionary: dictionary)
        match.play(word: "crane")
        match.loseUnfinishedBoards()
        XCTAssertTrue(match.isOver)
        XCTAssertEqual(match.solvedCount, 1)
    }
}
