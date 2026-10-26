import Foundation

/// How one player did on a challenge game.
public struct ChallengeResult: Codable, Equatable, Sendable {
    public var solved: Int
    public var guesses: Int
    public var seconds: Int
    /// Helper Mode was used: an assisted result loses to any unassisted one.
    public var assisted: Bool
    public var timedOut: Bool

    public init(solved: Int, guesses: Int, seconds: Int, assisted: Bool = false, timedOut: Bool = false) {
        self.solved = solved
        self.guesses = guesses
        self.seconds = seconds
        self.assisted = assisted
        self.timedOut = timedOut
    }

    /// "16/16 in 19 guesses", with the time for timed modes and a Helper mark.
    public func summary(boardCount: Int, mode: GameMode) -> String {
        var text = "\(solved)/\(boardCount) in \(guesses) \(guesses == 1 ? "guess" : "guesses")"
        if mode.isTimed { text += ", \(GameClock.format(TimeInterval(seconds)))" }
        if timedOut { text += ", time up" }
        if assisted { text += ", Helper" }
        return text
    }
}

public enum ChallengeOutcome: Equatable, Sendable {
    case won, lost, tied
}

/// One player's side of a challenge.
public struct ChallengeEntry: Codable, Equatable, Sendable {
    public var name: String
    public var result: ChallengeResult

    public init(name: String, result: ChallengeResult) {
        self.name = name
        self.result = result
    }
}

/// A game sent between friends with no server: the link carries the boards and the sender's
/// result, and the reply link carries the friend's result back. The payload is scrambled so a
/// glance at the URL does not give the answers away, and checksummed so a truncated or mangled
/// link is refused rather than played wrong. Neither is security: a friendly game needs neither.
public struct Challenge: Equatable, Sendable, Identifiable {
    public static let linkBase = "https://1041soft.com/murdl/c/#"
    public static let scheme = "murdl"
    public static let maxNameLength = 24
    static let version = "1"

    /// Eight hex digits shared by a challenge and every reply to it.
    public var id: String
    public var boardCount: Int
    public var variant: GameVariant
    public var mode: GameMode
    /// The boards. Empty in a reply: the challenger already has them.
    public var answers: [String]
    public var challenger: ChallengeEntry
    /// The friend's result; set only in a reply.
    public var reply: ChallengeEntry?

    public init(id: String = Challenge.newID(), answers: [String], variant: GameVariant, mode: GameMode, challenger: ChallengeEntry) {
        self.id = id
        self.boardCount = answers.count
        self.variant = variant
        self.mode = mode
        self.answers = answers.map { $0.lowercased() }
        self.challenger = challenger
        self.reply = nil
    }

    public static func newID() -> String {
        String(format: "%08x", UInt32.random(in: 0...UInt32.max))
    }

    public var isReply: Bool { reply != nil }
    public var maxGuesses: Int { boardCount + variant.extraGuesses(boards: boardCount) }

    /// The reply a friend sends back after playing this challenge.
    public func replying(as name: String, result: ChallengeResult) -> Challenge {
        var reply = self
        reply.answers = []
        reply.reply = ChallengeEntry(name: Self.cleanName(name), result: result)
        return reply
    }

    /// `mine` against `theirs`. Unassisted beats assisted, then more boards solved, then fewer
    /// guesses, then, in a timed mode, less time.
    public static func outcome(_ mine: ChallengeResult, vs theirs: ChallengeResult, mode: GameMode) -> ChallengeOutcome {
        func compare<T: Comparable>(_ a: T, _ b: T, lowerWins: Bool) -> ChallengeOutcome? {
            guard a != b else { return nil }
            return (a < b) == lowerWins ? .won : .lost
        }
        return compare(mine.assisted ? 1 : 0, theirs.assisted ? 1 : 0, lowerWins: true)
            ?? compare(mine.solved, theirs.solved, lowerWins: false)
            ?? compare(mine.guesses, theirs.guesses, lowerWins: true)
            ?? (mode.isTimed ? compare(mine.seconds, theirs.seconds, lowerWins: true) : nil)
            ?? .tied
    }

    /// "16 boards, Sprint, Rescue": the game, without anyone's result.
    public var gameDescription: String {
        var parts = ["\(boardCount) \(boardCount == 1 ? "board" : "boards")"]
        if mode != .classic { parts.append(mode.title) }
        if variant != .standard { parts.append(variant.title) }
        return parts.joined(separator: ", ")
    }

    // MARK: Links

    public var link: URL { URL(string: Self.linkBase + code)! }

    /// The text that goes with the link in a message.
    public var message: String {
        let challengerText = challenger.result.summary(boardCount: boardCount, mode: mode)
        if let reply {
            let theirs = reply.result.summary(boardCount: boardCount, mode: mode)
            let verdict: String
            switch Self.outcome(reply.result, vs: challenger.result, mode: mode) {
            case .won: verdict = "\(reply.name) wins"
            case .lost: verdict = "\(challenger.name) wins"
            case .tied: verdict = "It's a tie"
            }
            return "MURDL challenge, \(gameDescription): \(reply.name) \(theirs), \(challenger.name) \(challengerText). \(verdict)!\n\(link.absoluteString)"
        }
        return "\(challenger.name) challenges you to MURDL, \(gameDescription). \(challenger.name) got \(challengerText). Can you beat it?\n\(link.absoluteString)"
    }

    /// Accepts the web link, the `murdl://c/` link, or the bare code.
    public init?(link: URL) {
        let text = link.absoluteString
        if let fragment = link.fragment, !fragment.isEmpty {
            self.init(code: fragment)
        } else if link.scheme == Self.scheme {
            self.init(code: link.lastPathComponent)
        } else {
            self.init(code: text)
        }
    }

    public var code: String {
        var fields = [Self.version, isReply ? "r" : "c", id, String(boardCount), variant.rawValue, mode.rawValue,
                      answers.joined()]
        fields += Self.fields(challenger)
        if let reply { fields += Self.fields(reply) }
        let plain = Array(fields.joined(separator: "|").utf8)
        return Self.base64URL(Self.scramble(plain) + Self.checksum(plain))
    }

    public init?(code: String) {
        guard let data = Self.data(base64URL: code.trimmingCharacters(in: .whitespacesAndNewlines)),
              data.count > Self.checksumLength else { return nil }
        let bytes = Array(data)
        let plain = Self.scramble(Array(bytes.dropLast(Self.checksumLength)))
        guard Array(bytes.suffix(Self.checksumLength)) == Self.checksum(plain),
              let text = String(bytes: plain, encoding: .utf8) else { return nil }
        let fields = text.components(separatedBy: "|")
        guard fields.count == 12 || fields.count == 17, fields[0] == Self.version,
              let boardCount = Int(fields[3]), MurdlMatch.boardCountOptions.contains(boardCount),
              let variant = GameVariant(rawValue: fields[4]), let mode = GameMode(rawValue: fields[5]),
              let challenger = Self.entry(fields[7..<12]) else { return nil }
        let isReply = fields[1] == "r"
        let letters = Array(fields[6])
        let answers = stride(from: 0, to: letters.count, by: MurdlMatch.wordLength).map {
            String(letters[$0..<min($0 + MurdlMatch.wordLength, letters.count)])
        }
        if isReply {
            guard fields.count == 17, answers.isEmpty else { return nil }
        } else {
            guard fields[1] == "c", fields.count == 12, answers.count == boardCount,
                  answers.allSatisfy({ $0.count == MurdlMatch.wordLength && $0.unicodeScalars.allSatisfy { $0.value >= 97 && $0.value <= 122 } })
            else { return nil }
        }
        self.id = fields[2]
        self.boardCount = boardCount
        self.variant = variant
        self.mode = mode
        self.answers = answers
        self.challenger = challenger
        self.reply = isReply ? Self.entry(fields[12..<17]) : nil
        if isReply && reply == nil { return nil }
    }

    /// No separators or line breaks, and short enough for a scoreboard.
    public static func cleanName(_ name: String) -> String {
        let cleaned = name.replacingOccurrences(of: "|", with: "")
            .components(separatedBy: .newlines).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        return String(cleaned.prefix(maxNameLength))
    }

    private static func fields(_ entry: ChallengeEntry) -> [String] {
        let r = entry.result
        return [cleanName(entry.name), String(r.solved), String(r.guesses), String(r.seconds),
                (r.assisted ? "a" : "") + (r.timedOut ? "t" : "")]
    }

    private static func entry(_ fields: ArraySlice<String>) -> ChallengeEntry? {
        let f = Array(fields)
        guard f.count >= 5, let solved = Int(f[1]), let guesses = Int(f[2]), let seconds = Int(f[3]) else { return nil }
        return ChallengeEntry(name: f[0], result: ChallengeResult(
            solved: solved, guesses: guesses, seconds: seconds,
            assisted: f[4].contains("a"), timedOut: f[4].contains("t")))
    }

    // MARK: Scrambling and checksum

    private static let checksumLength = 6
    private static let key: UInt64 = 0x4D55_5244_4C5F_4348

    /// XOR with a fixed SplitMix64 stream: its own inverse.
    private static func scramble(_ bytes: [UInt8]) -> [UInt8] {
        var generator = SeededGenerator(seed: key)
        var word: UInt64 = 0
        return bytes.enumerated().map { index, byte in
            if index % 8 == 0 { word = generator.next() }
            return byte ^ UInt8(truncatingIfNeeded: word >> (UInt64(index % 8) * 8))
        }
    }

    /// Keyed FNV-1a: catches corruption on every platform MurdlCore builds for, CryptoKit or not.
    private static func checksum(_ bytes: [UInt8]) -> [UInt8] {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in withUnsafeBytes(of: key.bigEndian, Array.init) + bytes {
            hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
        }
        return (0..<checksumLength).map { UInt8(truncatingIfNeeded: hash >> (UInt64($0) * 8)) }
    }

    private static func base64URL(_ bytes: [UInt8]) -> String {
        Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func data(base64URL text: String) -> Data? {
        var base64 = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        return Data(base64Encoded: base64)
    }
}

/// A challenge as the score book keeps it: one line per challenge sent or received, filled in as
/// results arrive.
public struct ChallengeRecord: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var date: Date
    /// True for a challenge this player sent.
    public var sent: Bool
    public var boardCount: Int
    public var variant: GameVariant
    public var mode: GameMode
    public var opponent: String?
    public var mine: ChallengeResult?
    public var theirs: ChallengeResult?

    public init(id: String, date: Date = Date(), sent: Bool, boardCount: Int, variant: GameVariant, mode: GameMode,
                opponent: String? = nil, mine: ChallengeResult? = nil, theirs: ChallengeResult? = nil) {
        self.id = id
        self.date = date
        self.sent = sent
        self.boardCount = boardCount
        self.variant = variant
        self.mode = mode
        self.opponent = opponent
        self.mine = mine
        self.theirs = theirs
    }

    public var outcome: ChallengeOutcome? {
        guard let mine, let theirs else { return nil }
        return Challenge.outcome(mine, vs: theirs, mode: mode)
    }

    /// Two devices' books in one, newest first: the same challenge keeps whatever either side knows.
    public static func merge(_ a: [ChallengeRecord], _ b: [ChallengeRecord]) -> [ChallengeRecord] {
        var byID: [String: ChallengeRecord] = [:]
        for record in a + b {
            guard var existing = byID[record.id] else { byID[record.id] = record; continue }
            existing.opponent = existing.opponent ?? record.opponent
            existing.mine = existing.mine ?? record.mine
            existing.theirs = existing.theirs ?? record.theirs
            existing.date = min(existing.date, record.date)
            byID[record.id] = existing
        }
        return byID.values.sorted { $0.date > $1.date }
    }
}

extension WordDictionary {
    /// This dictionary with `answers` also allowed as guesses, so a challenge made on a newer word
    /// list can still be typed in full on an older one.
    public func allowing(_ answers: [String]) -> WordDictionary {
        let missing = answers.map { $0.lowercased() }.filter { !contains($0) }
        return missing.isEmpty ? self : WordDictionary(adding: missing, to: self)
    }
}
