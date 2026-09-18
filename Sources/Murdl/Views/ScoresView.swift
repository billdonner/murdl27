import MurdlCore
import SwiftUI

struct ScoresView: View {
    @ObservedObject var game: MurdlGame
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    /// A phone is too narrow for the table; it gets a list of two-line rows instead.
    private var isCompact: Bool {
        #if os(iOS)
        return sizeClass == .compact
        #else
        return false
        #endif
    }

    var body: some View {
        let summary = game.scoreSummary
        VStack(alignment: .leading, spacing: 12) {
            let stats = [
                ("Played", "\(summary.played)"),
                ("Won", "\(summary.won)"),
                ("Win %", "\(summary.winPercent)"),
                ("Streak", "\(summary.currentStreak)"),
                ("Best Streak", "\(summary.bestStreak)"),
                ("Best Score", summary.bestScore ?? "–"),
                ("Best Time (\(game.boardCount))", summary.bestTime.map { GameClock.format(TimeInterval($0)) } ?? "–"),
                ("Daily Streak (\(game.boardCount))", "\(summary.dailyStreak)"),
                ("Dailies Won (\(game.boardCount))", "\(summary.dailyWon)/\(summary.dailyPlayed)"),
            ]
            if isCompact {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), alignment: .leading)], alignment: .leading, spacing: 10) {
                    ForEach(stats, id: \.0) { stat in
                        Stat(title: stat.0, value: stat.1)
                    }
                }
                Button("Clear", role: .destructive) {
                    game.clearRecords()
                }
                .disabled(game.records.isEmpty)
            } else {
                HStack(spacing: 18) {
                    ForEach(stats, id: \.0) { stat in
                        Stat(title: stat.0, value: stat.1)
                    }
                    Spacer()
                    Button("Clear", role: .destructive) {
                        game.clearRecords()
                    }
                    .disabled(game.records.isEmpty)
                }
            }

            GuessDistributionView(distribution: summary.distribution, maxGuesses: game.maxGuesses, boardCount: game.boardCount)

            if isCompact {
                List(game.records) { record in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(record.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                            Spacer()
                            Text(record.resultText)
                                .foregroundStyle(record.isHonestWin ? MurdlPalette.correct : .secondary)
                        }
                        .font(.body.weight(.semibold))
                        HStack {
                            Text("\(record.daily.map { "Daily #\($0)  " } ?? "")\(record.boardCount) \(record.boardCount == 1 ? "board" : "boards")  \(record.mode.title)\(record.variant == .standard ? "" : "  \(record.variant.title)")")
                            Spacer()
                            Text("\(record.score)  \(record.guessesUsed)/\(record.maxGuesses)  \(record.timeText)")
                                .font(.system(.subheadline, design: .monospaced))
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .listRowBackground(MurdlPalette.panel)
                }
                .scrollContentBackground(.hidden)
                .overlay {
                    if game.records.isEmpty {
                        Text("Finish a game to record a score.")
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                scoreTable
            }
        }
        .padding(16)
        #if os(macOS)
        .frame(minWidth: 720, minHeight: 320)
        #endif
    }

    private var scoreTable: some View {
            Table(game.records) {
                TableColumn("Date") { record in
                    Text(record.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                }
                .width(min: 120, ideal: 140)
                TableColumn("Boards") { record in
                    Text("\(record.boardCount)")
                }
                .width(50)
                TableColumn("Daily") { record in
                    Text(record.daily.map { "#\($0)" } ?? "")
                }
                .width(60)
                TableColumn("Mode") { record in
                    Text(record.variant == .standard ? record.mode.title : "\(record.mode.title), \(record.variant.title)")
                }
                .width(min: 70, ideal: 120)
                TableColumn("Result") { record in
                    Text(record.resultText)
                        .foregroundStyle(record.isHonestWin ? MurdlPalette.correct : .secondary)
                }
                .width(min: 90, ideal: 110)
                TableColumn("Score") { record in
                    Text(record.score)
                        .font(.system(.body, design: .monospaced))
                }
                .width(min: 90, ideal: 150)
                TableColumn("Guesses") { record in
                    Text("\(record.guessesUsed)/\(record.maxGuesses)")
                }
                .width(60)
                TableColumn("Time") { record in
                    Text(record.timeText)
                }
                .width(60)
            }
            .overlay {
                if game.records.isEmpty {
                    Text("Finish a game to record a score.")
                        .foregroundStyle(.secondary)
                }
            }
    }
}

/// Wins at the current board count by guesses used, Wordle-style. Empty rows stay so the shape reads.
private struct GuessDistributionView: View {
    let distribution: [Int: Int]
    let maxGuesses: Int
    let boardCount: Int

    var body: some View {
        let peak = max(1, distribution.values.max() ?? 1)
        let rows = Array(1...maxGuesses)
        VStack(alignment: .leading, spacing: 4) {
            Text("Guess distribution (\(boardCount) \(boardCount == 1 ? "board" : "boards"))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(rows, id: \.self) { guesses in
                let count = distribution[guesses] ?? 0
                HStack(spacing: 6) {
                    Text("\(guesses)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .frame(width: 22, alignment: .trailing)
                        .foregroundStyle(.secondary)
                    GeometryReader { proxy in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(count == 0 ? MurdlPalette.divider : MurdlPalette.correct)
                            .frame(width: max(count == 0 ? 6 : 22, proxy.size.width * CGFloat(count) / CGFloat(peak)))
                            .overlay(alignment: .trailing) {
                                if count > 0 {
                                    Text("\(count)")
                                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                                        .foregroundStyle(.white)
                                        .padding(.trailing, 5)
                                }
                            }
                    }
                    .frame(height: 14)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rows.map { "\($0) guesses: \(distribution[$0] ?? 0)" }.joined(separator: ", "))
    }
}

private struct Stat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded).monospacedDigit())
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}
