import Foundation

/// How the boards are dealt, independent of the clock (`GameMode`).
public enum GameVariant: String, CaseIterable, Identifiable, Codable, Sendable {
    /// Every board visible from the start; guesses = boards + 5.
    case standard
    /// Boards are revealed one at a time: only the first unsolved board shows, the rest wait.
    /// Every guess still plays on every board, and the extra guesses make up for playing blind.
    case sequence
    /// The first few guesses are played for you with strong openers; you take over mid-game.
    case rescue

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .standard: return "Standard"
        case .sequence: return "Sequence"
        case .rescue: return "Rescue"
        }
    }

    public var summary: String {
        switch self {
        case .standard: return "All boards visible, guesses = boards + 5."
        case .sequence: return "One board at a time; extra guesses for playing blind."
        case .rescue: return "Strong openers are played for you; finish the job."
        }
    }

    /// Guesses beyond the board count. Sequence earns one more per four boards, at least one.
    public func extraGuesses(boards: Int) -> Int {
        switch self {
        case .standard, .rescue: return MurdlMatch.extraGuesses
        case .sequence: return MurdlMatch.extraGuesses + max(1, (boards + 3) / 4)
        }
    }

    /// Words Rescue plays before handing over: the starter sequences from Help.
    public func openers(boards: Int) -> [String] {
        guard self == .rescue else { return [] }
        return boards <= 2 ? ["crane", "sloth"] : ["chimp", "robed", "slant"]
    }
}
