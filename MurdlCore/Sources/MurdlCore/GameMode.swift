import Foundation

public enum GameMode: String, CaseIterable, Identifiable, Codable, Sendable {
    /// No visible clock. Time is still recorded.
    case classic
    /// Clock counts up from the first keystroke; best times are tracked per board count.
    case stopwatch
    /// Clock counts down from a budget; unfinished boards are lost when it reaches zero.
    case sprint

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .classic: return "Classic"
        case .stopwatch: return "Stopwatch"
        case .sprint: return "Sprint"
        }
    }

    public var isTimed: Bool { self != .classic }

    /// Sprint budget rule. Tune these two numbers after playing.
    public static let sprintSecondsPerBoard: TimeInterval = 45
    public static let sprintBonusPerSolve: TimeInterval = 10

    public static func sprintBudget(boards: Int) -> TimeInterval {
        sprintSecondsPerBoard * TimeInterval(boards)
    }
}

/// Elapsed-time bookkeeping that survives pauses. Stores instants, not ticks, so any view can
/// read it at whatever refresh rate it likes.
public struct GameClock: Equatable, Sendable {
    public private(set) var accumulated: TimeInterval = 0
    public private(set) var runningSince: Date?
    public private(set) var hasStarted = false

    public init() {}

    public var isRunning: Bool { runningSince != nil }

    public func elapsed(at now: Date = Date()) -> TimeInterval {
        accumulated + (runningSince.map { now.timeIntervalSince($0) } ?? 0)
    }

    public mutating func start(at now: Date = Date()) {
        guard !hasStarted else { return }
        hasStarted = true
        runningSince = now
    }

    public mutating func pause(at now: Date = Date()) {
        guard let since = runningSince else { return }
        accumulated += now.timeIntervalSince(since)
        runningSince = nil
    }

    public mutating func resume(at now: Date = Date()) {
        guard hasStarted, runningSince == nil else { return }
        runningSince = now
    }

    public static func format(_ seconds: TimeInterval) -> String {
        let whole = max(0, Int(seconds.rounded(.down)))
        let remainder = whole % 60
        return "\(whole / 60):" + (remainder < 10 ? "0" : "") + "\(remainder)"
    }
}
