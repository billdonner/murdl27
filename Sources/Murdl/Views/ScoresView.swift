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
                            Text("\(record.boardCount) \(record.boardCount == 1 ? "board" : "boards")  \(record.mode.title)")
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
                TableColumn("Mode") { record in
                    Text(record.mode.title)
                }
                .width(min: 70, ideal: 80)
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
