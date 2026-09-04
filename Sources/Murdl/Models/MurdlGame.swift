import Foundation
import Combine
import AppKit
import MurdlCore

/// The Mac session around a `MurdlMatch`: typing, timers, helper, layout, persistence.
/// Everything about the rules lives in MurdlCore; this class only drives it.
@MainActor
final class MurdlGame: ObservableObject {
    nonisolated static let wordLength = MurdlMatch.wordLength
    nonisolated static let boardCountOptions = MurdlMatch.boardCountOptions
    nonisolated static let defaultBoardCount = MurdlMatch.defaultBoardCount
    nonisolated static let extraGuesses = MurdlMatch.extraGuesses

    private let dictionary: WordDictionary
    private static let keyboardFontDefaultsKey = "MurdlKeyboardFontStyle"
    private static let boardCountDefaultsKey = "MurdlBoardCount"
    private static let boardLayoutDefaultsKey = "MurdlBoardLayout"
    private static let gameModeDefaultsKey = "MurdlGameMode"

    @Published private(set) var match: MurdlMatch
    @Published private(set) var currentGuess = ""
    @Published private(set) var statusText = ""
    @Published private(set) var isShowingHelp = false
    @Published private(set) var isHelperMode = false
    /// Set by the last helper step; cleared whenever the player submits a guess themselves.
    @Published private(set) var helperMessage = ""
    @Published private(set) var keyboardFontStyle: KeyboardFontStyle
    @Published private(set) var boardLayout: BoardLayout
    @Published private(set) var mode: GameMode
    @Published private(set) var records: [GameRecord] = ScoreStore.load()
    @Published private(set) var clock = GameClock()
    /// Advances a few times a second while the clock runs so time labels refresh.
    @Published private(set) var clockNow = Date()
    /// Extra Sprint seconds earned by solving boards.
    @Published private(set) var bonusSeconds: TimeInterval = 0
    @Published private(set) var timedOut = false
    /// Board highlighted by arrow-key navigation; the grid scrolls to keep it visible.
    @Published private(set) var focusedBoardID: Int?
    private(set) var assisted = false
    /// Boards per row in the current layout, reported by the grid view so up/down can move by a row.
    var layoutColumns = 1
    private var ticker: Timer?
    private var pausedForHelp = false
    private var pausedForBackground = false
    private var lifecycleTokens: [NSObjectProtocol] = []

    init(dictionary: WordDictionary = .bundled) {
        self.dictionary = dictionary
        let defaults = UserDefaults.standard
        keyboardFontStyle = defaults.string(forKey: Self.keyboardFontDefaultsKey).flatMap(KeyboardFontStyle.init) ?? .monospaced
        boardLayout = defaults.string(forKey: Self.boardLayoutDefaultsKey).flatMap(BoardLayout.init) ?? .grid
        mode = defaults.string(forKey: Self.gameModeDefaultsKey).flatMap(GameMode.init) ?? .classic
        let savedCount = defaults.integer(forKey: Self.boardCountDefaultsKey)
        let boardCount = Self.boardCountOptions.contains(savedCount) ? savedCount : Self.defaultBoardCount
        match = MurdlMatch(boardCount: boardCount, dictionary: dictionary)
        startNewGame()
        observeAppActivity()
    }

    // MARK: Forwarded match state

    var boards: [MurdlBoard] { match.boards }
    var boardCount: Int { match.boardCount }
    var maxGuesses: Int { match.maxGuesses }
    var currentRow: Int { match.currentRow }
    var keyMarks: [String: TileMark] { match.keyMarks }
    var isOver: Bool { match.isOver }
    var didWin: Bool { match.didWin }
    var guessesRemaining: Int { match.guessesRemaining }
    var solvedCount: Int { match.solvedCount }
    var scoreText: String { match.scoreText }

    func visibleTiles(for board: MurdlBoard, row: Int) -> [Tile] {
        match.visibleTiles(for: board, row: row, typing: currentGuess)
    }

    func visibleRows(for board: MurdlBoard) -> [[Tile]] {
        (0..<maxGuesses).map { visibleTiles(for: board, row: $0) }
    }

    func status(for board: MurdlBoard) -> String {
        match.status(for: board)
    }

    var scoreSummary: ScoreSummary {
        ScoreSummary(records: records, boardCount: boardCount)
    }

    // MARK: Game flow

    func startNewGame() {
        match = MurdlMatch(boardCount: boardCount, dictionary: dictionary)
        currentGuess = ""
        statusText = "Ready"
        helperMessage = ""
        focusedBoardID = nil
        clock = GameClock()
        clockNow = Date()
        bonusSeconds = 0
        timedOut = false
        assisted = false
        updateTicker()
    }

    /// Starts a new game with a different number of boards.
    func setBoardCount(_ count: Int) {
        guard Self.boardCountOptions.contains(count), count != boardCount else { return }
        UserDefaults.standard.set(count, forKey: Self.boardCountDefaultsKey)
        match = MurdlMatch(boardCount: count, dictionary: dictionary)
        startNewGame()
    }

    func setMode(_ newMode: GameMode) {
        guard newMode != mode else { return }
        mode = newMode
        UserDefaults.standard.set(newMode.rawValue, forKey: Self.gameModeDefaultsKey)
        startNewGame()
    }

    func enter(_ rawLetter: String) {
        guard !isOver, currentGuess.count < Self.wordLength else { return }
        let letter = rawLetter.uppercased()
        guard letter.count == 1, let scalar = letter.unicodeScalars.first else { return }
        guard scalar.value >= 65 && scalar.value <= 90 else { return }

        startClockIfNeeded()
        currentGuess.append(letter)
        statusText = ""
    }

    func deleteLetter() {
        guard !isOver, !currentGuess.isEmpty else { return }
        currentGuess.removeLast()
        statusText = ""
    }

    /// Escape: drop every typed letter of the current guess.
    func clearGuess() {
        guard !isOver, !currentGuess.isEmpty else { return }
        currentGuess = ""
        statusText = ""
    }

    func submitGuess() {
        switch match.validate(currentGuess) {
        case .gameOver?:
            return
        case .wrongLength?:
            statusText = "Enter 5 letters"
            return
        case .notInDictionary?:
            statusText = "\(currentGuess.uppercased()) is not in the dictionary"
            return
        case nil:
            break
        }

        let guess = currentGuess
        currentGuess = ""
        helperMessage = ""
        play(word: guess)
    }

    /// Plays a word on the match and reacts: Sprint bonus, status line, recording. Leaves `currentGuess` alone.
    private func play(word: String) {
        startClockIfNeeded()
        let result = match.play(word: word)

        if mode == .sprint {
            bonusSeconds += GameMode.sprintBonusPerSolve * TimeInterval(result.solvedBoardIDs.count)
        }

        if didWin {
            statusText = "Won MURDL \(scoreText)"
        } else if isOver {
            statusText = "Lost MURDL \(scoreText)"
        } else {
            statusText = "\(solvedCount) of \(boardCount) solved"
        }

        if isOver {
            stopClock()
            recordFinishedGame()
        }
    }

    private func recordFinishedGame() {
        let record = GameRecord(
            date: Date(),
            boardCount: boardCount,
            solvedCount: solvedCount,
            guessesUsed: currentRow,
            didWin: didWin,
            score: scoreText,
            seconds: Int(clock.elapsed().rounded()),
            mode: mode,
            assisted: assisted,
            timedOut: timedOut
        )
        records.insert(record, at: 0)
        ScoreStore.save(records)
    }

    func clearRecords() {
        records = []
        ScoreStore.save(records)
    }

    // MARK: Help

    func showHelp() {
        isShowingHelp = true
        setPaused(help: true)
    }

    func hideHelp() {
        isShowingHelp = false
        setPaused(help: false)
    }

    func toggleHelp() {
        isShowingHelp ? hideHelp() : showHelp()
    }

    // MARK: Helper Mode

    var helperTargetBoard: MurdlBoard? {
        guard isHelperMode else { return nil }
        return match.nextUnfinishedBoard
    }

    var helperFocusBoardID: Int? {
        helperTargetBoard?.id
    }

    var helperStepTitle: String {
        guard !isOver else { return "Helper Complete" }
        guard isHelperMode else { return "Play Helper Step" }
        guard let target = helperTargetBoard else { return "Helper Complete" }
        return "Play \(target.answer.uppercased())"
    }

    var helperSummary: String {
        guard isHelperMode else { return "Helper mode is off" }
        guard !isOver else { return helperFinishText }
        guard let target = helperTargetBoard else { return "No unfinished boards" }
        return "Next: Board \(target.id + 1) uses \(target.answer.uppercased())"
    }

    /// The headline shown in the helper bar: the last helper action if there is one, else the live summary.
    var helperHeadline: String {
        helperMessage.isEmpty ? helperSummary : helperMessage
    }

    private var helperFinishText: String {
        didWin ? "Helper finished MURDL \(scoreText)" : "Game over \(scoreText)"
    }

    func toggleHelperMode() {
        setHelperMode(!isHelperMode)
    }

    func setHelperMode(_ enabled: Bool) {
        isHelperMode = enabled
        helperMessage = ""

        if enabled {
            statusText = helperSummary
        } else if !isOver {
            statusText = "Helper mode off"
        }
    }

    /// Plays the next unfinished board's answer as a guess. Letters the player has typed are left in place.
    func playHelperStep() {
        if !isHelperMode {
            setHelperMode(true)
        }

        guard !isOver else {
            helperMessage = helperFinishText
            statusText = helperMessage
            return
        }

        guard let target = match.nextUnfinishedBoard else {
            helperMessage = "No unfinished boards"
            statusText = helperMessage
            return
        }

        let boardNumber = target.id + 1
        let answer = target.answer.uppercased()
        assisted = true
        play(word: target.answer)

        if isOver {
            helperMessage = helperFinishText
        } else if let next = helperTargetBoard {
            helperMessage = "Solved Board \(boardNumber) with \(answer). Next: Board \(next.id + 1)."
        } else {
            helperMessage = "Solved Board \(boardNumber) with \(answer)."
        }

        statusText = helperMessage
    }

    // MARK: Layout, focus, font

    func setBoardLayout(_ layout: BoardLayout) {
        boardLayout = layout
        UserDefaults.standard.set(layout.rawValue, forKey: Self.boardLayoutDefaultsKey)
    }

    func toggleBoardLayout() {
        setBoardLayout(boardLayout == .grid ? .strip : .grid)
    }

    func focusBoard(_ id: Int?) {
        focusedBoardID = id
    }

    /// Moves the focused board with the arrow keys. Left and right step one board; up and down step one row.
    func moveFocus(_ direction: BoardDirection) {
        guard !boards.isEmpty else { return }
        let step: Int
        switch direction {
        case .left: step = -1
        case .right: step = 1
        case .up: step = -layoutColumns
        case .down: step = layoutColumns
        }
        let current = focusedBoardID ?? (step > 0 ? -1 : boards.count)
        let next = current + step
        guard boards.indices.contains(next) else { return }
        focusedBoardID = next
    }

    func setKeyboardFontStyle(_ style: KeyboardFontStyle) {
        keyboardFontStyle = style
        UserDefaults.standard.set(style.rawValue, forKey: Self.keyboardFontDefaultsKey)
    }

    func cycleKeyboardFontStyle() {
        let styles = KeyboardFontStyle.allCases
        let currentIndex = styles.firstIndex(of: keyboardFontStyle) ?? 0
        setKeyboardFontStyle(styles[(currentIndex + 1) % styles.count])
    }

    // MARK: Timing

    var elapsedSeconds: TimeInterval {
        clock.elapsed(at: clockNow)
    }

    var sprintBudget: TimeInterval {
        GameMode.sprintBudget(boards: boardCount) + bonusSeconds
    }

    var sprintRemaining: TimeInterval {
        max(0, sprintBudget - elapsedSeconds)
    }

    /// What the header clock shows: elapsed for Stopwatch, remaining for Sprint, nothing for Classic.
    var clockText: String? {
        switch mode {
        case .classic: return nil
        case .stopwatch: return GameClock.format(elapsedSeconds)
        case .sprint: return GameClock.format(sprintRemaining)
        }
    }

    /// The clock starts on the first keystroke, not on New Game.
    private func startClockIfNeeded() {
        guard !clock.hasStarted, !isOver else { return }
        clock.start()
        updateTicker()
    }

    private func stopClock() {
        clock.pause()
        updateTicker()
    }

    private func setPaused(help: Bool? = nil, background: Bool? = nil) {
        if let help { pausedForHelp = help }
        if let background { pausedForBackground = background }
        let shouldPause = pausedForHelp || pausedForBackground
        if shouldPause {
            clock.pause()
        } else if !isOver {
            clock.resume()
        }
        updateTicker()
    }

    private func updateTicker() {
        if clock.isRunning {
            guard ticker == nil else { return }
            ticker = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
        } else {
            ticker?.invalidate()
            ticker = nil
        }
    }

    private func tick() {
        clockNow = Date()
        if mode == .sprint, !isOver, sprintRemaining <= 0 {
            expireTime()
        }
    }

    /// Sprint ran out: every unfinished board is lost.
    private func expireTime() {
        match.loseUnfinishedBoards()
        timedOut = true
        stopClock()
        statusText = "Time's up. Lost MURDL \(scoreText)"
        recordFinishedGame()
    }

    private func observeAppActivity() {
        let center = NotificationCenter.default
        lifecycleTokens = [
            center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.setPaused(background: true) }
            },
            center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.setPaused(background: false) }
            }
        ]
    }
}
