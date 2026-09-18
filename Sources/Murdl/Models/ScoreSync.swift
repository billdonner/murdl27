import Foundation
import MurdlCore

/// Keeps the score book the same on every device signed into the same iCloud account, using the
/// key-value store: no account of our own, no server, nothing to set up. Records merge by id, so
/// two devices playing offline both keep their games; Clear leaves a timestamp so cleared games
/// stay cleared everywhere.
@MainActor
final class ScoreSync {
    private static let recordsKey = "MurdlGameRecords"
    private static let clearedKey = "MurdlGameRecordsClearedAt"
    private let store = NSUbiquitousKeyValueStore.default
    private var token: NSObjectProtocol?
    private let onChange: ([GameRecord]) -> Void

    init(onChange: @escaping ([GameRecord]) -> Void) {
        self.onChange = onChange
        token = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: store, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.pull() }
        }
        store.synchronize()
    }

    /// Local records merged with whatever the cloud holds; also pushes the result back.
    func merged(with local: [GameRecord]) -> [GameRecord] {
        let cloudCleared = store.object(forKey: Self.clearedKey) as? Date
        let cleared = [ScoreStore.clearedAt(), cloudCleared].compactMap { $0 }.max()
        if let cleared, cleared != ScoreStore.clearedAt() { ScoreStore.markCleared(at: cleared) }
        let merged = ScoreStore.merge(local, ScoreStore.decode(store.data(forKey: Self.recordsKey)), clearedAt: cleared)
        push(merged)
        return merged
    }

    func push(_ records: [GameRecord]) {
        if let data = ScoreStore.encode(records) {
            store.set(data, forKey: Self.recordsKey)
        }
        if let cleared = ScoreStore.clearedAt() {
            store.set(cleared, forKey: Self.clearedKey)
        }
    }

    private func pull() {
        onChange(merged(with: ScoreStore.load()))
    }
}
