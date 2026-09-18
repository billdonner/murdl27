import MurdlCore
import SwiftUI

/// The card that drops over the boards when a game ends. A win gets confetti in the board colors,
/// a loss gets a quieter card; both offer Share and New Game. Tap outside to look at the boards.
struct GameOverView: View {
    @ObservedObject var game: MurdlGame
    let dismiss: () -> Void

    private var headline: String {
        if game.didWin {
            switch game.boardCount {
            case 1: return "Solved!"
            case ...4: return "All \(game.boardCount) solved!"
            case ...8: return "All \(game.boardCount)! Brilliant!"
            default: return "All \(game.boardCount)! Legendary!"
            }
        }
        return game.timedOut ? "Time's up" : "Out of guesses"
    }

    private var detail: String {
        var parts = ["\(game.currentRow) of \(game.maxGuesses) guesses"]
        if game.mode == .stopwatch { parts.append(GameClock.format(game.elapsedSeconds)) }
        if !game.didWin { parts.append("\(game.solvedCount) of \(game.boardCount) solved") }
        return parts.joined(separator: "  ·  ")
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)

            if game.didWin {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 14) {
                Image(systemName: game.didWin ? "trophy.fill" : "flag.checkered")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(game.didWin ? MurdlPalette.titleGradient : LinearGradient(colors: [.secondary, .secondary], startPoint: .top, endPoint: .bottom))
                    .symbolEffect(.bounce, value: game.isOver)

                Text(headline)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(MurdlPalette.letter)
                    .multilineTextAlignment(.center)

                Text(detail)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                if !game.scoreText.isEmpty {
                    Text(game.scoreText)
                        .font(.system(size: 20, weight: .heavy, design: .monospaced))
                        .foregroundStyle(MurdlPalette.letter)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(MurdlPalette.status, in: RoundedRectangle(cornerRadius: 8))
                }

                HStack(spacing: 12) {
                    ShareLink(item: game.shareText) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .frame(minWidth: 130, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 10))

                    Button {
                        game.startNewGame()
                    } label: {
                        Label("New Game", systemImage: "arrow.clockwise")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .frame(minWidth: 130, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 10))
                }
                .padding(.top, 6)
            }
            .padding(28)
            .frame(maxWidth: 420)
            .background(MurdlPalette.background, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(MurdlPalette.divider, lineWidth: 1))
            .shadow(color: .black.opacity(0.25), radius: 30, y: 12)
            .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
    }
}

/// A burst of falling tiles in the board accent colors, drawn with a canvas so it costs nothing
/// once it settles. Deterministic per piece so the animation never re-seeds mid-flight.
private struct ConfettiView: View {
    private struct Piece {
        let x: Double
        let delay: Double
        let speed: Double
        let drift: Double
        let spin: Double
        let size: Double
        let color: Color
    }

    private static let pieces: [Piece] = {
        var generator = SystemRandomNumberGenerator()
        return (0..<90).map { index in
            Piece(
                x: Double.random(in: 0...1, using: &generator),
                delay: Double.random(in: 0...0.9, using: &generator),
                speed: Double.random(in: 0.28...0.55, using: &generator),
                drift: Double.random(in: -0.12...0.12, using: &generator),
                spin: Double.random(in: -6...6, using: &generator),
                size: Double.random(in: 9...16, using: &generator),
                color: MurdlPalette.boardAccent(index % 16)
            )
        }
    }()

    private let start = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: false)) { context in
            let t = context.date.timeIntervalSince(start)
            Canvas { canvas, size in
                for piece in Self.pieces {
                    let age = t - piece.delay
                    guard age > 0 else { continue }
                    let progress = age * piece.speed
                    guard progress < 1.25 else { continue }
                    let x = (piece.x + piece.drift * sin(age * 3)) * size.width
                    let y = (progress - 0.1) * size.height
                    let rect = CGRect(x: -piece.size / 2, y: -piece.size / 2, width: piece.size, height: piece.size * 0.7)
                    var transform = CGAffineTransform(translationX: x, y: y)
                    transform = transform.rotated(by: age * piece.spin)
                    let path = RoundedRectangle(cornerRadius: 2).path(in: rect).applying(transform)
                    canvas.opacity = progress > 1 ? max(0, 1.25 - progress) * 4 : 1
                    canvas.fill(path, with: .color(piece.color))
                }
            }
        }
    }
}
