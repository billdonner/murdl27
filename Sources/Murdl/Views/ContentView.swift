import SwiftUI

struct ContentView: View {
    @ObservedObject var game: MurdlGame

    var body: some View {
        VStack(spacing: 10) {
            HeaderView(game: game)

            if game.isHelperMode {
                HelperBarView(game: game)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            BoardGridView(game: game)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            StatusStripView(game: game)

            KeyboardView(game: game)
                .frame(maxWidth: 790)
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

            HStack(spacing: 5) {
                ForEach(game.boards) { board in
                    HelperBoardChip(
                        board: board,
                        isTarget: game.helperFocusBoardID == board.id
                    )
                }
            }

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

private struct HelperBoardChip: View {
    let board: MurdlBoard
    let isTarget: Bool

    private var accent: Color {
        MurdlPalette.boardAccent(board.id)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(fill)

            if board.isSolved {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(.white)
            } else if board.isLost {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.white)
            } else {
                Text("\(board.id + 1)")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(isTarget ? .white : accent)
            }
        }
        .frame(width: 26, height: 26)
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
    private static let maxTile: CGFloat = 56
    private static let boardSpacing: CGFloat = 6
    private static let boardPadding: CGFloat = 7
    private static let tileSpacing: CGFloat = 3
    private static let headerAndPadding: CGFloat = 50

    var body: some View {
        GeometryReader { proxy in
            let columns = min(game.boardCount, Self.maxColumns)
            let boardRows = Int((Double(game.boardCount) / Double(columns)).rounded(.up))
            let boardWidthLimit = (proxy.size.width - (Self.boardSpacing * CGFloat(columns - 1))) / CGFloat(columns)
            let tileFromWidth = (boardWidthLimit - (Self.boardPadding * 2) - (Self.tileSpacing * CGFloat(MurdlGame.wordLength - 1))) / CGFloat(MurdlGame.wordLength)
            let boardHeightLimit = (proxy.size.height - (Self.boardSpacing * CGFloat(boardRows - 1))) / CGFloat(boardRows)
            let tileFromHeight = (boardHeightLimit - Self.headerAndPadding - (Self.tileSpacing * CGFloat(game.maxGuesses - 1))) / CGFloat(game.maxGuesses)
            let tileSize = floor(max(Self.minTile, min(Self.maxTile, tileFromWidth, tileFromHeight)))
            let needsScroll = tileFromHeight < Self.minTile
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
                                    tileSize: tileSize
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

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text("#\(boardID + 1)")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(accent, in: Capsule())
                Spacer(minLength: 2)
                Text(status)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
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

private struct KeyboardView: View {
    @ObservedObject var game: MurdlGame
    private static let rows = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]

    var body: some View {
        GeometryReader { proxy in
            let gap: CGFloat = 5
            let unit = max(31, min(45, (proxy.size.width - (gap * 9)) / 10))
            let font = MurdlTypography.keyboardLetterFont(game.keyboardFontStyle)

            VStack(spacing: 6) {
                HStack(spacing: gap) {
                    letterButtons(Self.rows[0], unit: unit, font: font)
                }
                HStack(spacing: gap) {
                    letterButtons(Self.rows[1], unit: unit, font: font)
                }
                HStack(spacing: gap) {
                    KeyboardCommandButton(title: "ENTER", systemImage: "return", width: unit * 1.45) {
                        game.submitGuess()
                    }

                    letterButtons(Self.rows[2], unit: unit, font: font)

                    KeyboardCommandButton(title: "DELETE", systemImage: "delete.left", width: unit * 1.45) {
                        game.deleteLetter()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 136)
        .disabled(game.isOver || game.isShowingHelp)
        .opacity(game.isOver ? 0.55 : 1)
        .help("Click keys or type on the keyboard")
    }

    private func letterButtons(_ letters: String, unit: CGFloat, font: Font) -> some View {
        ForEach(Array(letters).map(String.init), id: \.self) { letter in
            KeyboardLetterButton(
                letter: letter,
                mark: game.keyMarks[letter] ?? .empty,
                font: font,
                fontTitle: game.keyboardFontStyle.title,
                width: unit
            ) {
                game.enter(letter)
            }
        }
    }
}

private struct KeyboardLetterButton: View {
    let letter: String
    let mark: TileMark
    let font: Font
    let fontTitle: String
    let width: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(letter)
                .font(font)
                .frame(width: width, height: 38)
        }
        .buttonStyle(.plain)
        .foregroundStyle(MurdlPalette.keyText(for: mark))
        .background(MurdlPalette.keyFill(for: mark), in: RoundedRectangle(cornerRadius: 6))
        .keyboardShortcut(KeyEquivalent(Character(letter.lowercased())), modifiers: [])
        .accessibilityLabel("Letter \(letter)")
        .help("Type \(letter). Keyboard font: \(fontTitle)")
    }
}

private struct KeyboardCommandButton: View {
    let title: String
    let systemImage: String
    let width: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .heavy))
                .frame(width: width, height: 38)
        }
        .buttonStyle(.plain)
        .foregroundStyle(MurdlPalette.keyText(for: .empty))
        .background(MurdlPalette.commandKey, in: RoundedRectangle(cornerRadius: 6))
        .accessibilityLabel(title)
        .help(title)
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

private enum MurdlTypography {
    static func keyboardLetterFont(_ style: KeyboardFontStyle) -> Font {
        switch style {
        case .system:
            return .system(size: 18, weight: .heavy, design: .default)
        case .rounded:
            return .system(size: 18, weight: .heavy, design: .rounded)
        case .monospaced:
            return .system(size: 18, weight: .heavy, design: .monospaced)
        case .serif:
            return .system(size: 18, weight: .heavy, design: .serif)
        }
    }
}

private enum MurdlPalette {
    static let background = Color("GameBackGroundColor")
    static let panel = background.opacity(0.78)
    static let divider = Color.secondary.opacity(0.22)
    static let brand = Color("AccentColor")
    static let letter = Color("LetterForeGround")
    static let status = Color("BonusRowBackGround")
    static let correct = Color("MatchExactApple")
    static let present = Color("MatchWrongPosApple")
    static let absent = Color("NoMatchApple")
    static let commandKey = Color("KeyCapBackGround")
    static let keyForeground = Color("KeyCapForeGround")
    static let titleGradient = LinearGradient(
        colors: [boardAccent(0), boardAccent(1), boardAccent(2)],
        startPoint: .leading,
        endPoint: .trailing
    )

    static func boardAccent(_ index: Int) -> Color {
        boardAccents[index % boardAccents.count]
    }

    static func idleTile(_ boardID: Int) -> Color {
        boardAccent(boardID).opacity(0.24)
    }

    static func editingTile(_ boardID: Int) -> Color {
        boardAccent(boardID).opacity(0.44)
    }

    /// Keys use the same three result colors as the tiles.
    static func keyFill(for mark: TileMark) -> Color {
        switch mark {
        case .empty, .editing:
            return commandKey
        case .absent:
            return absent
        case .present:
            return present
        case .correct:
            return correct
        }
    }

    static func keyText(for mark: TileMark) -> Color {
        switch mark {
        case .empty, .editing:
            return keyForeground
        default:
            return Color.white
        }
    }

    private static let boardAccents: [Color] = [
        Color(red: 0.10, green: 0.70, blue: 0.32),
        Color(red: 0.95, green: 0.55, blue: 0.08),
        Color(red: 0.10, green: 0.49, blue: 0.92),
        Color(red: 0.86, green: 0.22, blue: 0.32),
        Color(red: 0.56, green: 0.36, blue: 0.90),
        Color(red: 0.00, green: 0.63, blue: 0.67),
        Color(red: 0.83, green: 0.67, blue: 0.12),
        Color(red: 0.88, green: 0.32, blue: 0.62),
        Color(red: 0.36, green: 0.55, blue: 0.20),
        Color(red: 0.80, green: 0.36, blue: 0.10),
        Color(red: 0.24, green: 0.32, blue: 0.78),
        Color(red: 0.62, green: 0.14, blue: 0.20),
        Color(red: 0.40, green: 0.20, blue: 0.62),
        Color(red: 0.10, green: 0.45, blue: 0.48),
        Color(red: 0.60, green: 0.48, blue: 0.08),
        Color(red: 0.62, green: 0.22, blue: 0.44)
    ]
}
