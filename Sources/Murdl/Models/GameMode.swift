import Foundation

enum GameMode: String, CaseIterable, Identifiable, Codable {
    /// No visible clock. Time is still recorded.
    case classic
    /// Clock counts up from the first keystroke; best times are tracked per board count.
    case stopwatch
    /// Clock counts down from a budget; unfinished boards are lost when it reaches zero.
    case sprint

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: return "Classic"
        case .stopwatch: return "Stopwatch"
        case .sprint: return "Sprint"
        }
    }

    var isTimed: Bool { self != .classic }

    /// Sprint budget rule. Tune these two numbers after playing.
    static let sprintSecondsPerBoard: TimeInterval = 45
    static let sprintBonusPerSolve: TimeInterval = 10

    static func sprintBudget(boards: Int) -> TimeInterval {
        sprintSecondsPerBoard * TimeInterval(boards)
    }
}

/// Elapsed-time bookkeeping that survives pauses. Stores instants, not ticks, so any view can
/// read it at whatever refresh rate it likes.
struct GameClock: Equatable {
    private(set) var accumulated: TimeInterval = 0
    private(set) var runningSince: Date?
    private(set) var hasStarted = false

    var isRunning: Bool { runningSince != nil }

    func elapsed(at now: Date = Date()) -> TimeInterval {
        accumulated + (runningSince.map { now.timeIntervalSince($0) } ?? 0)
    }

    mutating func start(at now: Date = Date()) {
        guard !hasStarted else { return }
        hasStarted = true
        runningSince = now
    }

    mutating func pause(at now: Date = Date()) {
        guard let since = runningSince else { return }
        accumulated += now.timeIntervalSince(since)
        runningSince = nil
    }

    mutating func resume(at now: Date = Date()) {
        guard hasStarted, runningSince == nil else { return }
        runningSince = now
    }

    static func format(_ seconds: TimeInterval) -> String {
        let whole = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }
}
