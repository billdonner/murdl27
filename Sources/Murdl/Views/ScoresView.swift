import SwiftUI

struct ScoresView: View {
    @ObservedObject var game: MurdlGame

    var body: some View {
        let summary = game.scoreSummary
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 18) {
                Stat(title: "Played", value: "\(summary.played)")
                Stat(title: "Won", value: "\(summary.won)")
                Stat(title: "Win %", value: "\(summary.winPercent)")
                Stat(title: "Streak", value: "\(summary.currentStreak)")
                Stat(title: "Best Streak", value: "\(summary.bestStreak)")
                Stat(title: "Best Score", value: summary.bestScore ?? "–")
                Spacer()
                Button("Clear", role: .destructive) {
                    game.clearRecords()
                }
                .disabled(game.records.isEmpty)
            }

            Table(game.records) {
                TableColumn("Date") { record in
                    Text(record.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                }
                .width(min: 120, ideal: 140)
                TableColumn("Boards") { record in
                    Text("\(record.boardCount)")
                }
                .width(50)
                TableColumn("Result") { record in
                    Text(record.resultText)
                        .foregroundStyle(record.didWin ? MurdlPalette.correct : .secondary)
                }
                .width(min: 70, ideal: 90)
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
        .padding(16)
        .frame(minWidth: 560, minHeight: 320)
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
