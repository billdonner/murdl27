import MurdlCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var game: MurdlGame
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 10) {
            HeaderView(
                game: game,
                showKeyboard: { openWindow(id: MurdlApp.keyboardWindowID) },
                showScores: { openWindow(id: MurdlApp.scoresWindowID) }
            )

            if game.isHelperMode {
                HelperBarView(game: game)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            BoardGridView(game: game)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            StatusStripView(game: game)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MurdlPalette.background.ignoresSafeArea())
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: game.isHelperMode)
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: game.helperFocusBoardID)
        .sheet(
            isPresented: Binding(
                get: { game.isShowingHelp },
                set: { isPresented in
                    if isPresented {
                        game.showHelp()
                    } else {
                        game.hideHelp()
                    }
                }
            )
        ) {
            HelpView(dismiss: game.hideHelp)
                .frame(minWidth: 680, minHeight: 560)
        }
    }
}

// Keyboard shortcuts are declared once, in the app's menus. The buttons below mirror them.
private struct HeaderView: View {
    @ObservedObject var game: MurdlGame
    let showKeyboard: () -> Void
    let showScores: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            MurdlLogo(size: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text("MURDL")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(MurdlPalette.titleGradient)
                Text("\(game.boardCount) boards  \(game.maxGuesses) guesses")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(game.solvedCount)/\(game.boardCount)")
                    .font(.system(size: 24, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(MurdlPalette.letter)
                Text(game.scoreText.isEmpty ? "\(game.guessesRemaining) left" : game.scoreText)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .help("Solved boards and remaining guesses")

            if let clockText = game.clockText {
                ClockView(text: clockText, mode: game.mode, remaining: game.sprintRemaining, isRunning: game.clock.isRunning, hasStarted: game.clock.hasStarted, isOver: game.isOver)
            }

            VStack(spacing: 4) {
                Picker("Boards", selection: Binding(
                    get: { game.boardCount },
                    set: { game.setBoardCount($0) }
                )) {
                    ForEach(MurdlGame.boardCountOptions, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("Number of boards")
                .help("Number of boards. Changing it starts a new game.")

                Picker("Mode", selection: Binding(
                    get: { game.mode },
                    set: { game.setMode($0) }
                )) {
                    ForEach(GameMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("Game mode")
                .help("Classic, Stopwatch, or Sprint. Changing it starts a new game.")
            }
            .frame(width: 236)

            HeaderButton(systemImage: "sparkles",
                         label: game.isHelperMode ? "Turn off helper mode" : "Turn on helper mode",
                         help: game.isHelperMode ? "Turn off Helper Mode (Command-Shift-H)" : "Turn on Helper Mode (Command-Shift-H)") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    game.toggleHelperMode()
                }
            }

            HeaderButton(systemImage: game.boardLayout == .grid ? "rectangle.split.2x2" : "rectangle.split.3x1",
                         label: "Board layout: \(game.boardLayout.title)",
                         help: "Switch to \((game.boardLayout == .grid ? BoardLayout.strip : .grid).title) layout (Command-L)") {
                withAnimation(.easeInOut(duration: 0.25)) {
                    game.toggleBoardLayout()
                }
            }

            HeaderButton(systemImage: "list.number",
                         label: "Scores",
                         help: "Show scores (Command-Shift-S)") {
                showScores()
            }

            HeaderButton(systemImage: "keyboard",
                         label: "Show keyboard",
                         help: "Show the floating letter keyboard (Command-K)") {
                showKeyboard()
            }

            HeaderButton(systemImage: "textformat",
                         label: "Change keyboard font",
                         help: "Next keyboard font: \(game.keyboardFontStyle.title) (Command-Shift-F)") {
                game.cycleKeyboardFontStyle()
            }

            HeaderButton(systemImage: "questionmark.circle",
                         label: "MURDL help",
                         help: "Show MURDL Help (Command-/)") {
                game.showHelp()
            }

            HeaderButton(systemImage: "arrow.clockwise",
                         label: "New game",
                         help: "Start a new game (Command-N)") {
                game.startNewGame()
            }
        }
        .frame(maxWidth: 1380)
    }
}

/// Elapsed time for Stopwatch, time remaining for Sprint. Amber under 30 seconds, red under 10.
private struct ClockView: View {
    let text: String
    let mode: GameMode
    let remaining: TimeInterval
    let isRunning: Bool
    let hasStarted: Bool
    let isOver: Bool

    private var caption: String {
        if isOver { return "Final" }
        if !hasStarted { return "Type to start" }
        return isRunning ? mode.title : "Paused"
    }

    private var color: Color {
        guard mode == .sprint, hasStarted else { return MurdlPalette.letter }
        if remaining <= 10 { return Color(red: 0.90, green: 0.22, blue: 0.22) }
        if remaining <= 30 { return Color(red: 0.95, green: 0.60, blue: 0.10) }
        return MurdlPalette.letter
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(text)
                .font(.system(size: 24, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(color)
            Text(caption)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 72, alignment: .trailing)
        .accessibilityLabel(mode == .sprint ? "Time remaining \(text)" : "Elapsed time \(text)")
        .help(mode == .sprint ? "Sprint: time remaining. Solving a board adds \(Int(GameMode.sprintBonusPerSolve)) seconds." : "Stopwatch: elapsed time since your first keystroke.")
    }
}

private struct HeaderButton: View {
    let systemImage: String
    let label: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .bold))
                .frame(width: 42, height: 42)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 8))
        .accessibilityLabel(label)
        .help(help)
    }
}

private struct MurdlLogo: View {
    let size: CGFloat

    var body: some View {
        Image("MURDLImage")
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .accessibilityHidden(true)
    }
}

private struct HelperBarView: View {
    @ObservedObject var game: MurdlGame

    private var accent: Color {
        MurdlPalette.boardAccent(game.helperFocusBoardID ?? 0)
    }

    var body: some View {
        HStack(spacing: 14) {
            Label("Helper", systemImage: "sparkles")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(accent, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(game.helperHeadline)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
                    .foregroundStyle(MurdlPalette.letter)

                if let target = game.helperTargetBoard {
                    Text("Board \(target.id + 1) answer: \(target.answer.uppercased())")
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .foregroundStyle(accent)
                } else {
                    Text(game.didWin ? "Solved" : "No active helper target")
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 10)

            HelperChipGrid(game: game)

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    game.playHelperStep()
                }
            } label: {
                Label(game.helperStepTitle, systemImage: "play.fill")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .frame(minWidth: 132)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 8))
            .tint(accent)
            .disabled(game.isOver)
            .help("Play the next helper step (Command-Shift-G)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: 1380)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.28), MurdlPalette.status.opacity(0.94)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(accent.opacity(0.65), lineWidth: 1)
        }
    }
}

private struct HelperChipGrid: View {
    @ObservedObject var game: MurdlGame
    private static let chipsPerRow = 8

    var body: some View {
        let rows = stride(from: 0, to: game.boards.count, by: Self.chipsPerRow).map { start in
            Array(game.boards[start..<min(start + Self.chipsPerRow, game.boards.count)])
        }
        HStack(spacing: 10) {
            if game.boardCount > Self.chipsPerRow {
                Text("\(game.solvedCount)/\(game.boardCount)")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .help("Boards solved")
            }
            VStack(spacing: 4) {
                ForEach(rows.indices, id: \.self) { rowIndex in
                    HStack(spacing: 4) {
                        ForEach(rows[rowIndex]) { board in
                            HelperBoardChip(
                                board: board,
                                isTarget: game.helperFocusBoardID == board.id,
                                size: game.boardCount > Self.chipsPerRow ? 20 : 26
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct HelperBoardChip: View {
    let board: MurdlBoard
    let isTarget: Bool
    var size: CGFloat = 26

    private var accent: Color {
        MurdlPalette.boardAccent(board.id)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(fill)

            if board.isSolved {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.5, weight: .heavy))
                    .foregroundStyle(.white)
            } else if board.isLost {
                Image(systemName: "xmark")
                    .font(.system(size: size * 0.46, weight: .heavy))
                    .foregroundStyle(.white)
            } else {
                Text("\(board.id + 1)")
                    .font(.system(size: size * 0.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(isTarget ? .white : accent)
            }
        }
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(accent.opacity(isTarget ? 1 : 0.42), lineWidth: isTarget ? 2 : 1)
        }
        .shadow(color: isTarget ? accent.opacity(0.45) : .clear, radius: 7, y: 2)
        .help(helpText)
    }

    private var fill: Color {
        if board.isSolved {
            return MurdlPalette.correct
        }
        if board.isLost {
            return MurdlPalette.absent
        }
        return isTarget ? accent : accent.opacity(0.16)
    }

    private var helpText: String {
        if let solvedRow = board.solvedRow {
            return "Board \(board.id + 1) solved on row \(solvedRow + 1)"
        }
        if board.isLost {
            return "Board \(board.id + 1) lost: \(board.answer.uppercased())"
        }
        return isTarget ? "Board \(board.id + 1) is the next helper target" : "Board \(board.id + 1)"
    }
}

private struct BoardGridView: View {
    @ObservedObject var game: MurdlGame

    private static let maxColumns = 8
    private static let minTile: CGFloat = 18
    private static let boardSpacing: CGFloat = 6
    private static let boardPadding: CGFloat = 7
    private static let tileSpacing: CGFloat = 3
    private static let headerAndPadding: CGFloat = 50
    /// How much of the next row of boards stays visible when the grid has to scroll.
    private static let peek: CGFloat = 72

    private struct Layout {
        var columns: Int
        var tile: CGFloat
        var axes: Axis.Set
        var scrolls: Bool
    }

    /// Small games get bigger tiles so two boards do not float in an empty window.
    private static func maxTile(forBoards count: Int) -> CGFloat {
        switch count {
        case ...2: return 76
        case ...4: return 64
        default: return 56
        }
    }

    private static func boardWidth(tile: CGFloat) -> CGFloat {
        tile * CGFloat(MurdlGame.wordLength) + tileSpacing * CGFloat(MurdlGame.wordLength - 1) + boardPadding * 2
    }

    private static func tileFromHeight(_ height: CGFloat, guesses: Int) -> CGFloat {
        (height - headerAndPadding - tileSpacing * CGFloat(guesses - 1)) / CGFloat(guesses)
    }

    /// Grid: columns are whatever fits at the minimum tile size, capped at eight. On a narrow
    /// window (or an iPad) this wraps eight boards into two rows of four.
    private static func gridLayout(boards: Int, guesses: Int, size: CGSize) -> Layout {
        let minBoardWidth = boardWidth(tile: minTile)
        let fit = Int((size.width + boardSpacing) / (minBoardWidth + boardSpacing))
        let columns = max(1, min(boards, maxColumns, fit))
        let rows = Int((Double(boards) / Double(columns)).rounded(.up))
        let boardWidthLimit = (size.width - boardSpacing * CGFloat(columns - 1)) / CGFloat(columns)
        let fromWidth = (boardWidthLimit - boardPadding * 2 - tileSpacing * CGFloat(MurdlGame.wordLength - 1)) / CGFloat(MurdlGame.wordLength)
        let boardHeightLimit = (size.height - boardSpacing * CGFloat(rows - 1)) / CGFloat(rows)
        let fromHeight = tileFromHeight(boardHeightLimit, guesses: guesses)
        var tile = floor(max(minTile, min(maxTile(forBoards: boards), fromWidth, fromHeight)))
        let scrolls = fromHeight < minTile && rows > 1
        if scrolls {
            // Shrink just enough that the next row peeks above the fold.
            let peekTile = floor(max(minTile, tileFromHeight(size.height - peek - boardSpacing, guesses: guesses)))
            tile = min(tile, peekTile)
        }
        return Layout(columns: columns, tile: tile, axes: .vertical, scrolls: scrolls)
    }

    /// Strip: one row sized by height alone; scrolls sideways when the boards outrun the window.
    private static func stripLayout(boards: Int, guesses: Int, size: CGSize) -> Layout {
        let fromHeight = tileFromHeight(size.height, guesses: guesses)
        let tile = floor(max(minTile, min(maxTile(forBoards: boards), fromHeight)))
        let totalWidth = boardWidth(tile: tile) * CGFloat(boards) + boardSpacing * CGFloat(boards - 1)
        return Layout(columns: boards, tile: tile, axes: .horizontal, scrolls: totalWidth > size.width)
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = game.boardLayout == .strip
                ? Self.stripLayout(boards: game.boardCount, guesses: game.maxGuesses, size: proxy.size)
                : Self.gridLayout(boards: game.boardCount, guesses: game.maxGuesses, size: proxy.size)
            let chunks = stride(from: 0, to: game.boards.count, by: layout.columns).map { start in
                Array(game.boards[start..<min(start + layout.columns, game.boards.count)])
            }

            ScrollViewReader { scroller in
                ScrollView(layout.axes, showsIndicators: layout.scrolls) {
                    VStack(spacing: Self.boardSpacing) {
                        ForEach(chunks.indices, id: \.self) { rowIndex in
                            HStack(alignment: .top, spacing: Self.boardSpacing) {
                                ForEach(chunks[rowIndex]) { board in
                                    GameBoardView(
                                        boardID: board.id,
                                        rows: game.visibleRows(for: board),
                                        status: game.status(for: board),
                                        isFinished: board.isFinished,
                                        isHelperTarget: game.helperFocusBoardID == board.id,
                                        isFocused: game.focusedBoardID == board.id,
                                        tileSize: layout.tile
                                    )
                                    .id(board.id)
                                    .onTapGesture { game.focusBoard(board.id) }
                                }
                            }
                        }
                    }
                    .frame(
                        minWidth: layout.axes == .horizontal ? proxy.size.width : nil,
                        minHeight: layout.axes == .vertical && layout.scrolls ? nil : proxy.size.height,
                        alignment: .center
                    )
                }
                .scrollDisabled(!layout.scrolls)
                .onChange(of: game.focusedBoardID) { _, id in
                    guard let id else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        scroller.scrollTo(id, anchor: .center)
                    }
                }
                .onChange(of: layout.columns, initial: true) { _, columns in
                    game.layoutColumns = columns
                }
            }
        }
    }
}

/// Renders one board from plain values so SwiftUI can skip boards whose inputs did not change.
private struct GameBoardView: View {
    let boardID: Int
    let rows: [[Tile]]
    let status: String
    let isFinished: Bool
    let isHelperTarget: Bool
    let isFocused: Bool
    let tileSize: CGFloat
    private var accent: Color { MurdlPalette.boardAccent(boardID) }
    private var boardWidth: CGFloat {
        tileSize * CGFloat(MurdlGame.wordLength) + 3 * CGFloat(MurdlGame.wordLength - 1)
    }
    private var isCompact: Bool { tileSize < 26 }
    private var headerFont: CGFloat { isCompact ? 10 : 13 }

    var body: some View {
        VStack(spacing: isCompact ? 4 : 6) {
            HStack(spacing: 4) {
                Text(isCompact ? "\(boardID + 1)" : "#\(boardID + 1)")
                    .font(.system(size: headerFont, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, isCompact ? 5 : 7)
                    .padding(.vertical, isCompact ? 2 : 3)
                    .background(accent, in: Capsule())
                Spacer(minLength: 2)
                Text(isCompact ? compactStatus : status)
                    .font(.system(size: headerFont - 1, weight: .bold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(isFinished ? accent : .secondary)
            }

            VStack(spacing: 3) {
                ForEach(rows.indices, id: \.self) { row in
                    HStack(spacing: 3) {
                        ForEach(rows[row].indices, id: \.self) { column in
                            TileView(tile: rows[row][column], boardID: boardID, tileSize: tileSize)
                        }
                    }
                }
            }
        }
        .frame(width: boardWidth)
        .padding(7)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(isHelperTarget ? 0.34 : 0.23), MurdlPalette.panel],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(accent.opacity(isHelperTarget || isFinished ? 0.95 : 0.58), lineWidth: isHelperTarget ? 3 : (isFinished ? 2 : 1))
        }
        .overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(MurdlPalette.letter.opacity(0.9), lineWidth: 2)
                    .padding(-3)
            }
        }
        .shadow(color: isHelperTarget ? accent.opacity(0.38) : .clear, radius: 10, y: 3)
        .scaleEffect(isHelperTarget ? 1.012 : 1)
        .help("Board \(boardID + 1): \(status)")
    }

    /// "Ready 3/21" becomes "3/21"; "Won 2/21" becomes "Won 2"; "Lost WORD" stays.
    private var compactStatus: String {
        if status.hasPrefix("Ready ") {
            return String(status.dropFirst(6))
        }
        if status.hasPrefix("Won "), let slash = status.firstIndex(of: "/") {
            return String(status[..<slash])
        }
        return status
    }
}

private struct TileView: View {
    let tile: Tile
    let boardID: Int
    let tileSize: CGFloat

    var body: some View {
        Text(tile.letter)
            .font(.system(size: tileSize * 0.56, weight: .heavy, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .foregroundStyle(tile.mark == .empty ? .secondary : MurdlPalette.letter)
            .frame(width: tileSize, height: tileSize)
            .background(fill, in: RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(border, lineWidth: tile.mark == .editing ? 2 : 1)
            )
    }

    private var fill: Color {
        switch tile.mark {
        case .empty:
            return MurdlPalette.idleTile(boardID)
        case .editing:
            return MurdlPalette.editingTile(boardID)
        case .absent:
            return MurdlPalette.absent
        case .present:
            return MurdlPalette.present
        case .correct:
            return MurdlPalette.correct
        }
    }

    private var border: Color {
        switch tile.mark {
        case .editing:
            return MurdlPalette.brand
        default:
            return MurdlPalette.divider
        }
    }
}

private struct StatusStripView: View {
    @ObservedObject var game: MurdlGame

    var body: some View {
        Text(game.statusText.isEmpty ? "\(game.guessesRemaining) guesses left" : game.statusText)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(MurdlPalette.letter)
            .frame(maxWidth: 790)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(MurdlPalette.status, in: RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel("Game status")
            .help("Current game status")
    }
}

private struct HelpView: View {
    let dismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        MurdlLogo(size: 56)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("MURDL")
                                .font(.system(.largeTitle, design: .rounded, weight: .black))
                                .foregroundStyle(MurdlPalette.titleGradient)
                            Text("Every guess plays on every board.")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    ForEach(HelpDocument.bundled.blocks.indices, id: \.self) { index in
                        HelpBlockView(block: HelpDocument.bundled.blocks[index])
                    }

                    ColorStrip()
                }
                .padding(24)
                .frame(maxWidth: 680, alignment: .leading)
            }
            .background(MurdlPalette.background.ignoresSafeArea())
            .navigationTitle("Help")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Done", systemImage: "checkmark")
                    }
                    .keyboardShortcut(.cancelAction)
                    .help("Close Help (Escape or Command-/)")
                }
            }
        }
    }
}

private struct HelpBlockView: View {
    let block: HelpDocument.Block

    var body: some View {
        switch block {
        case .heading(let text):
            Text(text)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
        case .subheading(let text):
            Text(text)
                .font(.headline.weight(.bold))
                .foregroundStyle(MurdlPalette.brand)
                .padding(.top, 6)
        case .paragraph(let text):
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
                .lineSpacing(5)
                .textSelection(.enabled)
        case .bullets(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items.indices, id: \.self) { index in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                        Text(items[index])
                            .textSelection(.enabled)
                    }
                    .font(.body)
                    .foregroundStyle(.primary)
                }
            }
        }
    }
}

/// Help.md parsed once into block-level structure. `AttributedString(markdown:)` alone would
/// flatten headings, paragraphs, and bullets into a single run, so blocks are split here and
/// only inline markdown is delegated to Foundation.
private struct HelpDocument {
    enum Block {
        case heading(String)
        case subheading(String)
        case paragraph(AttributedString)
        case bullets([AttributedString])
    }

    let blocks: [Block]

    static let bundled = HelpDocument(markdown: loadHelp())

    init(markdown: String) {
        blocks = markdown
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map(Self.block)
    }

    private static func block(from chunk: String) -> Block {
        if chunk.hasPrefix("## ") {
            return .subheading(String(chunk.dropFirst(3)))
        }
        if chunk.hasPrefix("# ") {
            return .heading(String(chunk.dropFirst(2)))
        }
        let lines = chunk.components(separatedBy: "\n")
        if lines.allSatisfy({ $0.hasPrefix("- ") }) {
            return .bullets(lines.map { inline(String($0.dropFirst(2))) })
        }
        return .paragraph(inline(lines.joined(separator: " ")))
    }

    private static func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }

    private static func loadHelp() -> String {
        guard let url = Bundle.main.url(forResource: "Help", withExtension: "md"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return "MURDL is the eight-board word game. You have 13 guesses to solve eight different five-letter words."
        }
        return contents
    }
}

private struct ColorStrip: View {
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<MurdlGame.boardCountOptions.max()!, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(MurdlPalette.boardAccent(index))
                    .frame(height: 10)
            }
        }
        .accessibilityHidden(true)
    }
}
