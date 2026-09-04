import Foundation
import MurdlCore

// C ABI over MurdlCore for non-Swift front ends (see murdl.h). Every function is safe to call
// from a single thread; a match handle must be freed with murdl_match_free.

private final class MatchBox {
    var match: MurdlMatch
    var typing = ""
    init(_ match: MurdlMatch) { self.match = match }
}

private func box(_ handle: UnsafeMutableRawPointer?) -> MatchBox? {
    handle.map { Unmanaged<MatchBox>.fromOpaque($0).takeUnretainedValue() }
}

private func cString(_ string: String) -> UnsafeMutablePointer<CChar> {
    let utf8 = Array(string.utf8CString)
    let pointer = UnsafeMutablePointer<CChar>.allocate(capacity: utf8.count)
    pointer.initialize(from: utf8, count: utf8.count)
    return pointer
}

private func string(_ pointer: UnsafePointer<CChar>?) -> String {
    pointer.map { String(cString: $0) } ?? ""
}

/// Library version, for the caller to check at load time.
@_cdecl("murdl_version")
public func murdl_version() -> Int32 { 1 }

/// Creates a match with `boardCount` boards (2, 4, 8, or 16) and random answers. Returns NULL for other counts.
@_cdecl("murdl_match_new")
public func murdl_match_new(_ boardCount: Int32) -> UnsafeMutableRawPointer? {
    guard MurdlMatch.boardCountOptions.contains(Int(boardCount)) else { return nil }
    let handle = MatchBox(MurdlMatch(boardCount: Int(boardCount)))
    return Unmanaged.passRetained(handle).toOpaque()
}

/// Creates a match with fixed answers given as a comma-separated list of five-letter words.
@_cdecl("murdl_match_new_with_answers")
public func murdl_match_new_with_answers(_ answers: UnsafePointer<CChar>?) -> UnsafeMutableRawPointer? {
    let words = string(answers).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
    guard !words.isEmpty, words.allSatisfy({ $0.count == MurdlMatch.wordLength }) else { return nil }
    let handle = MatchBox(MurdlMatch(answers: words))
    return Unmanaged.passRetained(handle).toOpaque()
}

@_cdecl("murdl_match_free")
public func murdl_match_free(_ handle: UnsafeMutableRawPointer?) {
    guard let handle else { return }
    Unmanaged<MatchBox>.fromOpaque(handle).release()
}

/// Replaces the letters being typed (shown as editing tiles in the snapshot). Non-letters are dropped.
@_cdecl("murdl_match_set_typing")
public func murdl_match_set_typing(_ handle: UnsafeMutableRawPointer?, _ letters: UnsafePointer<CChar>?) {
    guard let box = box(handle) else { return }
    box.typing = String(string(letters).uppercased().filter { $0.isASCII && $0.isLetter }.prefix(MurdlMatch.wordLength))
}

/// 0 = playable, 1 = game over, 2 = wrong length, 3 = not in dictionary.
@_cdecl("murdl_match_validate")
public func murdl_match_validate(_ handle: UnsafeMutableRawPointer?, _ word: UnsafePointer<CChar>?) -> Int32 {
    guard let box = box(handle) else { return -1 }
    switch box.match.validate(string(word)) {
    case nil: return 0
    case .gameOver?: return 1
    case .wrongLength?: return 2
    case .notInDictionary?: return 3
    }
}

/// Plays a word on every unfinished board. Returns the number of boards it solved, or -1 if the
/// word was refused (validate first, or pass an answer word).
@_cdecl("murdl_match_play")
public func murdl_match_play(_ handle: UnsafeMutableRawPointer?, _ word: UnsafePointer<CChar>?) -> Int32 {
    guard let box = box(handle) else { return -1 }
    let guess = string(word)
    if box.match.validate(guess) != nil { return -1 }
    box.typing = ""
    return Int32(box.match.play(word: guess).solvedBoardIDs.count)
}

/// Sprint ran out: every unfinished board is lost.
@_cdecl("murdl_match_lose_unfinished")
public func murdl_match_lose_unfinished(_ handle: UnsafeMutableRawPointer?) {
    box(handle)?.match.loseUnfinishedBoards()
}

/// The whole match as JSON (see MatchSnapshot). Free the result with murdl_string_free.
@_cdecl("murdl_match_state_json")
public func murdl_match_state_json(_ handle: UnsafeMutableRawPointer?) -> UnsafeMutablePointer<CChar>? {
    guard let box = box(handle), let json = try? MatchSnapshot(box.match, typing: box.typing).json() else { return nil }
    return cString(json)
}

/// Scores one word against one answer as five characters: A absent, P present, C correct.
/// Free the result with murdl_string_free.
@_cdecl("murdl_score")
public func murdl_score(_ guess: UnsafePointer<CChar>?, _ answer: UnsafePointer<CChar>?) -> UnsafeMutablePointer<CChar>? {
    let g = string(guess), a = string(answer)
    guard g.count == MurdlMatch.wordLength, a.count == MurdlMatch.wordLength else { return nil }
    let marks = MurdlMatch.score(guess: g, answer: a).map { tile -> String in
        switch tile.mark {
        case .correct: return "C"
        case .present: return "P"
        default: return "A"
        }
    }
    return cString(marks.joined())
}

/// Whether a word may be guessed at all, independent of any match.
@_cdecl("murdl_dictionary_contains")
public func murdl_dictionary_contains(_ word: UnsafePointer<CChar>?) -> Int32 {
    WordDictionary.bundled.contains(string(word)) ? 1 : 0
}

@_cdecl("murdl_string_free")
public func murdl_string_free(_ pointer: UnsafeMutablePointer<CChar>?) {
    pointer?.deallocate()
}
