import Foundation
import Combine
import AppKit

@MainActor
final class MurdlGame: ObservableObject {
    nonisolated static let wordLength = 5
    nonisolated static let boardCountOptions = [2, 4, 8, 16]
    nonisolated static let defaultBoardCount = 8
    /// Classic MURDL gives five more guesses than boards: 8 boards, 13 guesses.
    nonisolated static let extraGuesses = 5

    private let dictionary: WordDictionary
    private static let keyboardFontDefaultsKey = "MurdlKeyboardFontStyle"
    private static let boardCountDefaultsKey = "MurdlBoardCount"
    private static let boardLayoutDefaultsKey = "MurdlBoardLayout"
    private static let gameModeDefaultsKey = "MurdlGameMode"

    @Published private(set) var boardCount: Int
    @Published private(set) var boards: [MurdlBoard] = []
    @Published private(set) var currentGuess = ""
    @Published private(set) var currentRow = 0
    @Published private(set) var statusText = ""
    @Published private(set) var keyMarks: [String: TileMark] = [:]
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
    private(set) var assisted = false
    private var ticker: Timer?
    private var pausedForHelp = false
    private var pausedForBackground = false
    private var lifecycleTokens: [NSObjectProtocol] = []
    /// Board highlighted by arrow-key navigation; the grid scrolls to keep it visible.
    @Published private(set) var focusedBoardID: Int?
    /// Boards per row in the current layout, reported by the grid view so up/down can move by a row.
    var layoutColumns = 1

    init(dictionary: WordDictionary = .bundled) {
        self.dictionary = dictionary
        if let rawStyle = UserDefaults.standard.string(forKey: Self.keyboardFontDefaultsKey),
           let savedStyle = KeyboardFontStyle(rawValue: rawStyle) {
            keyboardFontStyle = savedStyle
        } else {
            keyboardFontStyle = .monospaced
        }
        let savedCount = UserDefaults.standard.integer(forKey: Self.boardCountDefaultsKey)
        boardCount = Self.boardCountOptions.contains(savedCount) ? savedCount : Self.defaultBoardCount
        if let rawLayout = UserDefaults.standard.string(forKey: Self.boardLayoutDefaultsKey),
           let savedLayout = BoardLayout(rawValue: rawLayout) {
            boardLayout = savedLayout
        } else {
            boardLayout = .grid
        }
        if let rawMode = UserDefaults.standard.string(forKey: Self.gameModeDefaultsKey),
           let savedMode = GameMode(rawValue: rawMode) {
            mode = savedMode
        } else {
            mode = .classic
        }
        startNewGame()
        observeAppActivity()
    }

    var scoreSummary: ScoreSummary {
        ScoreSummary(records: records, boardCount: boardCount)
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

    func setMode(_ newMode: GameMode) {
        guard newMode != mode else { return }
        mode = newMode
        UserDefaults.standard.set(newMode.rawValue, forKey: Self.gameModeDefaultsKey)
        startNewGame()
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
        for index in boards.indices where !boards[index].isFinished {
            boards[index].isLost = true
        }
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

    func setBoardLayout(_ layout: BoardLayout) {
        boardLayout = layout
        UserDefaults.standard.set(layout.rawValue, forKey: Self.boardLayoutDefaultsKey)
    }

    func toggleBoardLayout() {
        setBoardLayout(boardLayout == .grid ? .strip : .grid)
    }

    func clearRecords() {
        records = []
        ScoreStore.save(records)
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

    var maxGuesses: Int {
        boardCount + Self.extraGuesses
    }

    /// Starts a new game with a different number of boards.
    func setBoardCount(_ count: Int) {
        guard Self.boardCountOptions.contains(count), count != boardCount else { return }
        boardCount = count
        UserDefaults.standard.set(count, forKey: Self.boardCountDefaultsKey)
        startNewGame()
    }

    var isOver: Bool {
        boards.allSatisfy(\.isFinished)
    }

    var didWin: Bool {
        boards.allSatisfy(\.isSolved)
    }

    var guessesRemaining: Int {
        max(0, maxGuesses - currentRow)
    }

    var solvedCount: Int {
        boards.filter(\.isSolved).count
    }

    /// One character per board: the row it was solved on, or `maxGuesses + 1` if missed.
    /// Rows 10 and up are written as letters starting at A so the score stays one character per board.
    var scoreText: String {
        guard isOver else { return "" }

        let rawScores = boards.map { board in
            if let solvedRow = board.solvedRow {
                return solvedRow + 1
            }
            return maxGuesses + 1
        }

        let sortedScores = didWin ? rawScores.sorted() : rawScores.sorted(by: >)
        return sortedScores.map { String($0, radix: 36).uppercased() }.joined()
    }

    var helperTargetBoard: MurdlBoard? {
        guard isHelperMode else { return nil }
        return nextHelperBoard()
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

    func startNewGame() {
        let answers = dictionary.randomAnswers(count: boardCount)
        boards = answers.enumerated().map { index, answer in
            MurdlBoard(
                id: index,
                answer: answer,
                rows: Array(repeating: .empty(wordLength: Self.wordLength), count: maxGuesses)
            )
        }
        currentGuess = ""
        currentRow = 0
        statusText = "Ready"
        keyMarks = [:]
        helperMessage = ""
        focusedBoardID = nil
        clock = GameClock()
        clockNow = Date()
        bonusSeconds = 0
        timedOut = false
        assisted = false
        updateTicker()
    }

    func showHelp() {
        isShowingHelp = true
        setPaused(help: true)
    }

    func hideHelp() {
        isShowingHelp = false
        setPaused(help: false)
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

        guard let target = nextHelperBoard() else {
            helperMessage = "No unfinished boards"
            statusText = helperMessage
            return
        }

        let boardNumber = target.id + 1
        let answer = target.answer.uppercased()
        assisted = true
        startClockIfNeeded()
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

    func setKeyboardFontStyle(_ style: KeyboardFontStyle) {
        keyboardFontStyle = style
        UserDefaults.standard.set(style.rawValue, forKey: Self.keyboardFontDefaultsKey)
    }

    func cycleKeyboardFontStyle() {
        let styles = KeyboardFontStyle.allCases
        let currentIndex = styles.firstIndex(of: keyboardFontStyle) ?? 0
        setKeyboardFontStyle(styles[(currentIndex + 1) % styles.count])
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

    func submitGuess() {
        guard !isOver else { return }
        guard currentGuess.count == Self.wordLength else {
            statusText = "Enter 5 letters"
            return
        }

        let guess = currentGuess.lowercased()
        guard dictionary.contains(guess) else {
            statusText = "\(currentGuess.uppercased()) is not in the dictionary"
            return
        }

        currentGuess = ""
        helperMessage = ""
        play(word: guess)
    }

    /// Scores `word` against every unfinished board and advances the row. Does not touch `currentGuess`.
    private func play(word: String) {
        startClockIfNeeded()
        for boardIndex in boards.indices {
            guard !boards[boardIndex].isFinished else { continue }

            let scoredTiles = Self.score(guess: word, answer: boards[boardIndex].answer)
            boards[boardIndex].rows[currentRow].tiles = scoredTiles
            mergeKeyMarks(scoredTiles)

            if scoredTiles.allSatisfy({ $0.mark == .correct }) {
                boards[boardIndex].solvedRow = currentRow
                if mode == .sprint {
                    bonusSeconds += GameMode.sprintBonusPerSolve
                }
            } else if currentRow == maxGuesses - 1 {
                boards[boardIndex].isLost = true
            }
        }

        currentRow += 1

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

    func visibleTiles(for board: MurdlBoard, row: Int) -> [Tile] {
        guard row == currentRow, !board.isFinished, !isOver else {
            return board.rows[row].tiles
        }

        var tiles = board.rows[row].tiles
        for (index, letter) in currentGuess.enumerated() where index < tiles.count {
            tiles[index] = Tile(letter: String(letter), mark: .editing)
        }
        return tiles
    }

    func visibleRows(for board: MurdlBoard) -> [[Tile]] {
        (0..<maxGuesses).map { visibleTiles(for: board, row: $0) }
    }

    func status(for board: MurdlBoard) -> String {
        if let solvedRow = board.solvedRow {
            return "Won \(solvedRow + 1)/\(maxGuesses)"
        }
        if board.isLost {
            return "Lost \(board.answer.uppercased())"
        }
        return "Ready \(min(currentRow + 1, maxGuesses))/\(maxGuesses)"
    }

    private func mergeKeyMarks(_ tiles: [Tile]) {
        for tile in tiles {
            guard !tile.letter.isEmpty else { continue }
            let existing = keyMarks[tile.letter] ?? .empty
            if tile.mark > existing {
                keyMarks[tile.letter] = tile.mark
            }
        }
    }

    private func nextHelperBoard() -> MurdlBoard? {
        boards.first { !$0.isFinished }
    }

    private static func score(guess: String, answer: String) -> [Tile] {
        let guessLetters = Array(guess.uppercased())
        let answerLetters = Array(answer.uppercased())
        var marks = Array(repeating: TileMark.absent, count: wordLength)
        var remaining: [Character: Int] = [:]

        for index in 0..<wordLength {
            if guessLetters[index] == answerLetters[index] {
                marks[index] = .correct
            } else {
                remaining[answerLetters[index], default: 0] += 1
            }
        }

        for index in 0..<wordLength where marks[index] != .correct {
            let letter = guessLetters[index]
            if let count = remaining[letter], count > 0 {
                marks[index] = .present
                remaining[letter] = count - 1
            }
        }

        return zip(guessLetters, marks).map { letter, mark in
            Tile(letter: String(letter), mark: mark)
        }
    }
}
