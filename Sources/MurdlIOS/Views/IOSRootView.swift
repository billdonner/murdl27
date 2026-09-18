import MurdlCore
import SwiftUI

/// The one iOS screen: header, boards, status, docked keyboard. Help and Scores are sheets.
/// A hardware keyboard on iPad types straight into the game; the docked keys do the same by touch.
struct IOSRootView: View {
    @ObservedObject var game: MurdlGame
    @State private var isShowingScores = false
    /// Tapping outside the game-over card hides it so the boards can be studied; New Game resets it.
    @State private var gameOverDismissed = false
    /// iPhone: swipe the keyboard down to see more board; swipe or tap the handle to bring it back.
    @State private var keyboardHidden = false
    @FocusState private var boardFocused: Bool
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// iPhone: one board per page. iPad: the grid.
    private var isCompact: Bool { sizeClass == .compact }

    private var gameLocked: Bool {
        game.isOver || game.isShowingHelp
    }

    var body: some View {
        GeometryReader { proxy in
            content(width: proxy.size.width - (isCompact ? 24 : 32))
        }
    }

    private func content(width: CGFloat) -> some View {
        VStack(spacing: 10) {
            IOSHeaderView(game: game, showScores: { isShowingScores = true })

            if game.isHelperMode {
                HelperBarView(game: game, showsChips: !isCompact)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Group {
                if isCompact {
                    PagedBoardsView(game: game)
                } else {
                    BoardGridView(game: game)
                }
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    if game.isOver, !gameOverDismissed {
                        GameOverView(game: game) {
                            withAnimation(.easeOut(duration: 0.2)) { gameOverDismissed = true }
                        }
                    }
                }
                .animation(.spring(response: 0.45, dampingFraction: 0.72), value: game.isOver)
                .animation(.spring(response: 0.45, dampingFraction: 0.72), value: gameOverDismissed)
                .onChange(of: game.isOver) { _, over in
                    if !over { gameOverDismissed = false }
                }
                .sensoryFeedback(game.didWin ? .success : .warning, trigger: game.isOver) { _, over in over }

            StatusStripView(game: game)

            if isCompact && keyboardHidden {
                keyboardHandle
            } else {
                BottomKeyboardView(game: game, width: width)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 30).onEnded { value in
                            if isCompact, value.translation.height > 40 {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { keyboardHidden = true }
                            }
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Text(AppVersion.label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, isCompact ? 12 : 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MurdlPalette.background.ignoresSafeArea())
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: game.isHelperMode)
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: game.helperFocusBoardID)
        .focusable()
        .focusEffectDisabled()
        .focused($boardFocused)
        .onAppear {
            boardFocused = true
            #if DEBUG
            Demo.run(game: game, showScores: { isShowingScores = true })
            #endif
        }
        .onKeyPress(characters: .letters, phases: .down) { press in
            guard !gameLocked, press.modifiers.subtracting([.shift, .capsLock]).isEmpty else { return .ignored }
            game.enter(String(press.characters))
            return .handled
        }
        .onKeyPress(.return) { submit() }
        .onKeyPress(.delete) { deleteLetter() }
        .onKeyPress(.escape) { escape() }
        .onKeyPress(.leftArrow) { move(.left) }
        .onKeyPress(.rightArrow) { move(.right) }
        .onKeyPress(.upArrow) { move(.up) }
        .onKeyPress(.downArrow) { move(.down) }
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
            ),
            onDismiss: { boardFocused = true }
        ) {
            HelpView(dismiss: game.hideHelp)
        }
        .sheet(isPresented: $isShowingScores, onDismiss: { boardFocused = true }) {
            NavigationStack {
                ScoresView(game: game)
                    .background(MurdlPalette.background.ignoresSafeArea())
                    .navigationTitle("Scores")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { isShowingScores = false }
                        }
                    }
            }
        }
    }

    private var keyboardHandle: some View {
        Label("Show keyboard", systemImage: "keyboard.chevron.compact.up")
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(MurdlPalette.letter)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(MurdlPalette.status, in: Capsule())
            .contentShape(Capsule())
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { keyboardHidden = false }
            }
            .gesture(
                DragGesture(minimumDistance: 20).onEnded { value in
                    if value.translation.height < -20 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { keyboardHidden = false }
                    }
                }
            )
            .accessibilityAddTraits(.isButton)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func submit() -> KeyPress.Result {
        guard !gameLocked else { return .ignored }
        game.submitGuess()
        return .handled
    }

    private func deleteLetter() -> KeyPress.Result {
        guard !gameLocked else { return .ignored }
        game.deleteLetter()
        return .handled
    }

    private func escape() -> KeyPress.Result {
        if game.isShowingHelp {
            game.hideHelp()
        } else {
            game.clearGuess()
        }
        return .handled
    }

    private func move(_ direction: BoardDirection) -> KeyPress.Result {
        guard !game.isShowingHelp else { return .ignored }
        game.moveFocus(direction)
        return .handled
    }
}
