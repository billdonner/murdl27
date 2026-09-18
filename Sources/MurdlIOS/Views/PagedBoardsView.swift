import MurdlCore
import SwiftUI

/// iPhone: one board per page, swiped sideways, with a numbered strip to jump between boards.
/// The current page is the game's focused board, so hardware arrow keys page as well.
struct PagedBoardsView: View {
    @ObservedObject var game: MurdlGame
    /// Board being applauded before the page turns; nil the rest of the time.
    @State private var celebratingBoardID: Int?
    /// Pinch in: shrink the board until every row fits; pinch out: back to readable tiles.
    @State private var fitAll = false

    private static let tileSpacing: CGFloat = 3
    private static let boardChrome: CGFloat = 50 + 14   // header row plus the board's own padding
    private static let minFittedTile: CGFloat = 26
    private static let minSqueezedTile: CGFloat = 13
    private static let maxTile: CGFloat = 64
    /// Tile for a page that scrolls: big enough to read, small enough to show several rows.
    private static let scrollingTile: CGFloat = 46

    private var page: Binding<Int> {
        Binding(
            get: { game.focusedBoardID ?? 0 },
            set: { game.focusBoard($0) }
        )
    }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let fitted = Self.fittedTile(in: proxy.size, guesses: game.maxGuesses)
                let scrolls = fitted < Self.minFittedTile && !fitAll
                let tile = scrolls ? min(Self.scrollingTile, Self.widthTile(in: proxy.size)) : max(Self.minSqueezedTile, fitted)

                TabView(selection: page) {
                    ForEach(game.boards) { board in
                        Group {
                            if scrolls {
                                ScrollingBoardPage(game: game, board: board, tile: tile) {
                                    boardView(board, tile: tile)
                                }
                            } else {
                                boardView(board, tile: tile)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .tag(board.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .simultaneousGesture(
                    MagnifyGesture(minimumScaleDelta: 0.15).onEnded { value in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            fitAll = value.magnification < 1
                        }
                    }
                )
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: fitAll)
            }

            BoardSwitcherStrip(game: game)
        }
        .onAppear {
            game.layoutColumns = 1
            if game.focusedBoardID == nil { game.focusBoard(0) }
        }
        .onChange(of: game.focusedBoardID) { _, id in
            // New Game clears the focus; land on the first board again.
            if id == nil { game.focusBoard(0) }
        }
        .onChange(of: finishedCount) { _, _ in
            celebrateThenAdvance()
        }
        .sensoryFeedback(.success, trigger: celebratingBoardID) { _, id in id != nil }
    }

    private var finishedCount: Int {
        game.boards.filter(\.isFinished).count
    }

    private func boardView(_ board: MurdlBoard, tile: CGFloat) -> some View {
        let celebrating = celebratingBoardID == board.id
        return GameBoardView(
            boardID: board.id,
            rows: game.visibleRows(for: board),
            status: game.status(for: board),
            isFinished: board.isFinished,
            isHelperTarget: game.helperFocusBoardID == board.id,
            isFocused: false,
            tileSize: tile,
            highContrast: game.highContrast
        )
        .scaleEffect(celebrating ? 1.03 : 1)
        .overlay(alignment: .bottom) {
            // Low on the board, over rows that are still empty, so the winning word stays visible.
            if celebrating {
                BoardFinishedBadge(board: board)
                    .padding(.bottom, 14)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
        }
    }

    /// A guess just finished the board on screen: applaud it, then turn to the next open board.
    private func celebrateThenAdvance() {
        guard let current = game.focusedBoardID, game.boards[current].isFinished, celebratingBoardID == nil else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { celebratingBoardID = current }
        Task {
            try? await Task.sleep(for: .seconds(game.isOver ? 0.6 : 1.5))
            withAnimation(.easeOut(duration: 0.25)) { celebratingBoardID = nil }
            guard !game.isOver else { return }
            try? await Task.sleep(for: .milliseconds(150))
            let next = game.boards.first { !$0.isFinished && $0.id > current } ?? game.boards.first { !$0.isFinished }
            if let next {
                withAnimation(.easeInOut(duration: 0.45)) { game.focusBoard(next.id) }
            }
        }
    }

    private static func fittedTile(in size: CGSize, guesses: Int) -> CGFloat {
        let fromHeight = (size.height - boardChrome - tileSpacing * CGFloat(guesses - 1)) / CGFloat(guesses)
        return floor(min(maxTile, fromHeight, widthTile(in: size)))
    }

    private static func widthTile(in size: CGSize) -> CGFloat {
        floor(min(maxTile, (size.width - 14 - 24 - tileSpacing * CGFloat(MurdlGame.wordLength - 1)) / CGFloat(MurdlGame.wordLength)))
    }
}

/// The applause: a check (or the answer, for a lost board) that springs in over the board.
private struct BoardFinishedBadge: View {
    let board: MurdlBoard

    private var accent: Color { MurdlPalette.boardAccent(board.id) }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: board.isSolved ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 72, weight: .bold))
                .foregroundStyle(.white, board.isSolved ? MurdlPalette.correct : MurdlPalette.absent)
                .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
            Text(board.isSolved ? "Board \(board.id + 1) solved!" : "Board \(board.id + 1): \(board.answer.uppercased())")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            if let row = board.solvedRow {
                Text("Row \(row + 1)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .background(accent.opacity(0.92), in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: accent.opacity(0.5), radius: 18, y: 6)
        .allowsHitTesting(false)
    }
}

/// A board taller than the page: scrolls, and keeps the row being typed in view.
private struct ScrollingBoardPage<Content: View>: View {
    @ObservedObject var game: MurdlGame
    let board: MurdlBoard
    let tile: CGFloat
    @ViewBuilder let content: () -> Content

    /// Where the current row sits inside the board: header row, then rows of tile plus spacing.
    private var cursorOffset: CGFloat {
        36 + CGFloat(min(game.currentRow, game.maxGuesses - 1)) * (tile + 3)
    }

    var body: some View {
        ScrollViewReader { scroller in
            ScrollView(.vertical, showsIndicators: false) {
                content()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .overlay(alignment: .top) {
                        // A real frame, not an offset, so the scroll reader can measure it.
                        VStack(spacing: 0) {
                            Color.clear.frame(height: cursorOffset)
                            Color.clear.frame(height: tile).id("cursor")
                        }
                        .allowsHitTesting(false)
                    }
            }
            .scrollBounceBehavior(.basedOnSize)
            .task {
                // Pages lay out lazily; give this one a beat before scrolling to the typing row.
                try? await Task.sleep(for: .milliseconds(150))
                scroller.scrollTo("cursor", anchor: .center)
            }
            .onChange(of: game.currentRow) { _, _ in
                withAnimation(.easeInOut(duration: 0.25)) { scroller.scrollTo("cursor", anchor: .center) }
            }
        }
    }
}

/// Numbered capsules, one per board: green when solved, gray when lost, ringed when current.
struct BoardSwitcherStrip: View {
    @ObservedObject var game: MurdlGame

    var body: some View {
        ScrollViewReader { scroller in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(game.boards) { board in
                        let accent = MurdlPalette.boardAccent(board.id)
                        let isCurrent = game.focusedBoardID == board.id
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) { game.focusBoard(board.id) }
                        } label: {
                            Text("\(board.id + 1)")
                                .font(.system(size: 15, weight: .heavy, design: .rounded).monospacedDigit())
                                .foregroundStyle(board.isFinished || isCurrent ? .white : accent)
                                .frame(minWidth: 36, minHeight: 36)
                                .background(fill(for: board, accent: accent, isCurrent: isCurrent), in: Capsule())
                                .overlay(Capsule().stroke(accent, lineWidth: isCurrent ? 2.5 : 1))
                        }
                        .buttonStyle(.plain)
                        .id(board.id)
                        .accessibilityLabel("Board \(board.id + 1), \(game.status(for: board))")
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
            }
            .scrollBounceBehavior(.basedOnSize)
            .onChange(of: game.focusedBoardID) { _, id in
                guard let id else { return }
                withAnimation(.easeInOut(duration: 0.25)) { scroller.scrollTo(id, anchor: .center) }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func fill(for board: MurdlBoard, accent: Color, isCurrent: Bool) -> Color {
        if board.isSolved { return MurdlPalette.correct }
        if board.isLost { return MurdlPalette.absent }
        return isCurrent ? accent : accent.opacity(0.16)
    }
}
