import XCTest
import MurdlBridge

/// Exercises the C entry points the way a foreign caller would.
final class BridgeTests: XCTestCase {
    private func take(_ pointer: UnsafeMutablePointer<CChar>?) -> String {
        defer { murdl_string_free(pointer) }
        return pointer.map { String(cString: $0) } ?? ""
    }

    func testVersion() {
        XCTAssertEqual(murdl_version(), 1)
    }

    func testScore() {
        XCTAssertEqual(take(murdl_score("eerie", "there")), "PAPAC")
        XCTAssertNil(murdl_score("toolong", "there"))
    }

    func testDictionary() {
        XCTAssertEqual(murdl_dictionary_contains("crane"), 1)
        XCTAssertEqual(murdl_dictionary_contains("zzzzz"), 0)
    }

    func testMatchLifecycle() throws {
        let match = murdl_match_new_with_answers("crane,slate")
        defer { murdl_match_free(match) }
        XCTAssertNotNil(match)

        XCTAssertEqual(murdl_match_validate(match, "cran"), 2)
        XCTAssertEqual(murdl_match_validate(match, "zzzzz"), 3)
        XCTAssertEqual(murdl_match_validate(match, "crane"), 0)
        XCTAssertEqual(murdl_match_play(match, "zzzzz"), -1)

        murdl_match_set_typing(match, "cr1a")
        var json = take(murdl_match_state_json(match))
        var state = try JSONDecoder().decode(Snapshot.self, from: Data(json.utf8))
        XCTAssertEqual(state.boards[0].rows[0].prefix(3).map(\.letter), ["C", "R", "A"])
        XCTAssertEqual(state.boards[0].rows[0][0].mark, "editing")

        XCTAssertEqual(murdl_match_play(match, "crane"), 1)
        XCTAssertEqual(murdl_match_play(match, "slate"), 1)
        json = take(murdl_match_state_json(match))
        state = try JSONDecoder().decode(Snapshot.self, from: Data(json.utf8))
        XCTAssertTrue(state.isOver)
        XCTAssertTrue(state.didWin)
        XCTAssertEqual(state.score, "12")
        XCTAssertEqual(state.currentRow, 2)
        XCTAssertEqual(state.keyMarks["S"], "correct")
        XCTAssertEqual(murdl_match_validate(match, "crane"), 1)
    }

    func testRejectsBadBoardCount() {
        XCTAssertNil(murdl_match_new(3))
        let match = murdl_match_new(8)
        XCTAssertNotNil(match)
        murdl_match_free(match)
    }

    private struct Snapshot: Decodable {
        struct Cell: Decodable { var letter: String; var mark: String }
        struct Board: Decodable { var rows: [[Cell]] }
        var isOver: Bool
        var didWin: Bool
        var score: String
        var currentRow: Int
        var keyMarks: [String: String]
        var boards: [Board]
    }
}
