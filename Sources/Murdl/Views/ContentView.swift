import SwiftUI

struct ContentView: View {
    @ObservedObject var game: MurdlGame
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 10) {
            HeaderView(game: game, showKeyboard: { openWindow(id: MurdlApp.keyboardWindowID) })

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
            .frame(width: 168)
            .accessibilityLabel("Number of boards")
            .help("Number of boards. Changing it starts a new game.")

            HeaderButton(systemImage: "sparkles",
                         label: game.isHelperMode ? "Turn off helper mode" : "Turn on helper mode",
                         help: game.isHelperMode ? "Turn off Helper Mode (Command-Shift-H)" : "Turn on Helper Mode (Command-Shift-H)") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    game.toggleHelperMode()
                }
            }

            HeaderButton(systemImage: "keyboard",
                         label: "Show keyboard",
                         help: "Show the floating letter keyboard (Command-K)") {
                showKeyboard()
            }

            HeaderButton(systemImage: "textformat",
                         label: "Change keyboard font",
                         help: "Change keyboard font: \(game.keyboardFontStyle.title) (Command-Shift-F)") {
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

    /// Columns are whatever fits at the minimum tile size, capped at eight. On a narrow
    /// window (or an iPad) this wraps eight boards into two rows of four.
    private static func columns(forBoards count: Int, width: CGFloat) -> Int {
        let minBoardWidth = boardWidth(tile: minTile)
        let fit = Int((width + boardSpacing) / (minBoardWidth + boardSpacing))
        return max(1, min(count, maxColumns, fit))
    }

    var body: some View {
        GeometryReader { proxy in
            let columns = Self.columns(forBoards: game.boardCount, width: proxy.size.width)
            let boardRows = Int((Double(game.boardCount) / Double(columns)).rounded(.up))
            let boardWidthLimit = (proxy.size.width - (Self.boardSpacing * CGFloat(columns - 1))) / CGFloat(columns)
            let tileFromWidth = (boardWidthLimit - (Self.boardPadding * 2) - (Self.tileSpacing * CGFloat(MurdlGame.wordLength - 1))) / CGFloat(MurdlGame.wordLength)
            let boardHeightLimit = (proxy.size.height - (Self.boardSpacing * CGFloat(boardRows - 1))) / CGFloat(boardRows)
            let tileFromHeight = (boardHeightLimit - Self.headerAndPadding - (Self.tileSpacing * CGFloat(game.maxGuesses - 1))) / CGFloat(game.maxGuesses)
            let tileSize = floor(max(Self.minTile, min(Self.maxTile(forBoards: game.boardCount), tileFromWidth, tileFromHeight)))
            let needsScroll = tileFromHeight < Self.minTile && boardRows > 1
            // When scrolling, shrink the tiles just enough that the next row peeks above the fold.
            let peekTile = needsScroll
                ? floor(max(Self.minTile, (proxy.size.height - Self.peek - Self.boardSpacing - Self.headerAndPadding - Self.tileSpacing * CGFloat(game.maxGuesses - 1)) / CGFloat(game.maxGuesses)))
                : tileSize
            let finalTile = min(tileSize, peekTile)
            let chunks = stride(from: 0, to: game.boards.count, by: columns).map { start in
                Array(game.boards[start..<min(start + columns, game.boards.count)])
            }

            ScrollView(.vertical, showsIndicators: needsScroll) {
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
                                    tileSize: finalTile
                                )
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: needsScroll ? nil : proxy.size.height, alignment: .center)
            }
            .scrollDisabled(!needsScroll)
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
                            Text("Eight boards. One guess. Thirteen rows.")
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
