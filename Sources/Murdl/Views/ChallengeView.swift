import MurdlCore
import SwiftUI

/// What the challenge sheet is showing.
enum ChallengeSheet: Identifiable {
    /// The player's finished game, ready to send.
    case send(Challenge)
    /// A friend's challenge, just opened from a link.
    case incoming(Challenge)
    /// A friend's challenge, just played: compare and send the result back.
    case finished(Challenge)
    /// A friend's answer to a challenge this player sent.
    case reply(Challenge)
    /// Change the name on challenges.
    case name

    var id: String {
        switch self {
        case .send(let c): return "send-\(c.id)"
        case .incoming(let c): return "in-\(c.id)"
        case .finished(let c): return "done-\(c.id)"
        case .reply(let c): return "reply-\(c.id)"
        case .name: return "name"
        }
    }
}

/// One sheet for every step of a challenge, on the Mac and on iOS. Sending and playing need the
/// Multiplayer unlock; reading a friend's reply does not.
struct ChallengeView: View {
    @ObservedObject var game: MurdlGame
    @ObservedObject var store: MultiplayerStore
    let sheet: ChallengeSheet
    @State private var name: String
    @Environment(\.dismiss) private var dismiss

    init(game: MurdlGame, sheet: ChallengeSheet) {
        self.game = game
        self.store = game.multiplayer
        self.sheet = sheet
        _name = State(initialValue: game.playerName)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    content
                }
                .padding(24)
                .frame(maxWidth: 520, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background(MurdlPalette.background.ignoresSafeArea())
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveName()
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 420)
        #endif
        .task { await store.refresh() }
    }

    private var title: String {
        switch sheet {
        case .send: return "Challenge a Friend"
        case .incoming(let c): return "\(c.challenger.name) Challenges You"
        case .finished: return "Challenge Result"
        case .reply: return "Challenge Answered"
        case .name: return "Your Name"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch sheet {
        case .name:
            nameField
            Text("Friends see this name on your challenges and results. Change it any time.")
                .foregroundStyle(.secondary)

        case .send(let challenge):
            if store.isUnlocked {
                headline("Same boards, your score to beat", detail: challenge.gameDescription)
                resultRow(label: "You", result: challenge.challenger.result, challenge: challenge, outcome: nil)
                nameField
                if trimmedName.isEmpty {
                    Text("Add your name so your friend knows who sent it.")
                        .foregroundStyle(.secondary)
                } else {
                    let ready = signed(challenge)
                    sendButtons(text: ready.message, label: "Send Challenge") { game.recordSent(ready) }
                }
            } else {
                UnlockView(store: store, reason: "Send this game to a friend: the same boards, with your score to beat.")
            }

        case .incoming(let challenge):
            if let record = game.challengeRecord(challenge.id), let mine = record.mine {
                comparison(challenge: challenge, mine: mine, theirs: challenge.challenger)
                replyButtons(challenge: challenge, mine: mine)
            } else if store.isUnlocked {
                headline("Beat \(challenge.challenger.name)", detail: challenge.gameDescription)
                resultRow(label: challenge.challenger.name, result: challenge.challenger.result, challenge: challenge, outcome: nil)
                Text("You play the same boards. Your first try is the one that counts.")
                    .foregroundStyle(.secondary)
                Button {
                    game.playChallenge(challenge)
                } label: {
                    Label("Play", systemImage: "play.fill")
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            } else {
                headline("Beat \(challenge.challenger.name)", detail: challenge.gameDescription)
                UnlockView(store: store, reason: "Play \(challenge.challenger.name)'s boards and send your result back.")
            }

        case .finished(let challenge):
            let mine = game.challengeRecord(challenge.id)?.mine ?? game.challengeResult
            comparison(challenge: challenge, mine: mine, theirs: challenge.challenger)
            replyButtons(challenge: challenge, mine: mine)

        case .reply(let challenge):
            if let reply = challenge.reply {
                comparison(challenge: challenge, mine: challenge.challenger.result, theirs: reply)
            }
        }
    }

    // MARK: Pieces

    private var trimmedName: String { Challenge.cleanName(name) }

    private var nameField: some View {
        TextField("Your name", text: $name)
            .textFieldStyle(.roundedBorder)
            .font(.title3)
            .onSubmit(saveName)
            .onChange(of: name) { _, _ in saveName() }
    }

    private func saveName() {
        if trimmedName != game.playerName { game.setPlayerName(trimmedName) }
    }

    private func signed(_ challenge: Challenge) -> Challenge {
        var signed = challenge
        signed.challenger.name = trimmedName
        return signed
    }

    private func headline(_ text: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(MurdlPalette.letter)
            Text(detail)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private func resultRow(label: String, result: ChallengeResult, challenge: Challenge, outcome: ChallengeOutcome?) -> some View {
        HStack {
            Text(label)
                .font(.headline)
            if outcome == .won {
                Image(systemName: "crown.fill")
                    .foregroundStyle(MurdlPalette.present)
                    .accessibilityLabel("Winner")
            }
            Spacer()
            Text(result.summary(boardCount: challenge.boardCount, mode: challenge.mode))
                .font(.system(.body, design: .monospaced))
        }
        .padding(12)
        .background(MurdlPalette.status, in: RoundedRectangle(cornerRadius: 10))
    }

    private func comparison(challenge: Challenge, mine: ChallengeResult, theirs: ChallengeEntry) -> some View {
        let outcome = Challenge.outcome(mine, vs: theirs.result, mode: challenge.mode)
        let verdict: String
        switch outcome {
        case .won: verdict = "You beat \(theirs.name)!"
        case .lost: verdict = "\(theirs.name) wins this one"
        case .tied: verdict = "A tie with \(theirs.name)"
        }
        return VStack(alignment: .leading, spacing: 10) {
            headline(verdict, detail: challenge.gameDescription)
            resultRow(label: "You", result: mine, challenge: challenge, outcome: outcome)
            resultRow(label: theirs.name, result: theirs.result, challenge: challenge,
                      outcome: outcome == .lost ? .won : nil)
        }
    }

    @ViewBuilder
    private func replyButtons(challenge: Challenge, mine: ChallengeResult) -> some View {
        nameField
        if trimmedName.isEmpty {
            Text("Add your name so \(challenge.challenger.name) knows who answered.")
                .foregroundStyle(.secondary)
        } else {
            let reply = challenge.replying(as: trimmedName, result: mine)
            sendButtons(text: reply.message, label: "Send Result to \(challenge.challenger.name)") {}
        }
    }

    private func sendButtons(text: String, label: String, onSend: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            ShareLink(item: text) {
                Label(label, systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .simultaneousGesture(TapGesture().onEnded(onSend))

            Button {
                Clipboard.copy(text)
                onSend()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
                    .frame(minHeight: 36)
            }
            .buttonStyle(.bordered)
        }
    }
}

/// The paywall: one non-consumable, with Restore for a new device.
private struct UnlockView: View {
    @ObservedObject var store: MultiplayerStore
    let reason: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("MURDL Multiplayer", systemImage: "person.2.fill")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(MurdlPalette.titleGradient)
            Text(reason)
            Text("Challenge friends to the exact same boards and trade results, on every device on your Apple Account. One purchase, no subscription.")
                .foregroundStyle(.secondary)

            Button {
                Task { await store.purchase() }
            } label: {
                Text(store.product.map { "Unlock for \($0.displayPrice)" } ?? "Unlock Multiplayer")
                    .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.product == nil || store.isBusy)

            Button("Restore Purchases") {
                Task { await store.restore() }
            }
            .disabled(store.isBusy)

            if store.product == nil && !store.isBusy {
                Text("The App Store isn't answering right now. Try again in a moment.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let message = store.message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(MurdlPalette.panel, in: RoundedRectangle(cornerRadius: 14))
    }
}

enum Clipboard {
    static func copy(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}
