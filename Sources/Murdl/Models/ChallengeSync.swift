import Foundation
import MurdlCore

/// The challenge book, kept locally and in the iCloud key-value store beside the scores, so a
/// reply opened on the iPhone finds the challenge that was sent from the Mac.
@MainActor
final class ChallengeSync {
    private static let key = "MurdlChallenges"
    private let store = NSUbiquitousKeyValueStore.default
    private var token: NSObjectProtocol?
    private let onChange: ([ChallengeRecord]) -> Void

    init(onChange: @escaping ([ChallengeRecord]) -> Void) {
        self.onChange = onChange
        token = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: store, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.onChange(self.merged(with: Self.load()))
            }
        }
    }

    static func load() -> [ChallengeRecord] {
        decode(UserDefaults.standard.data(forKey: key))
    }

    /// Local records merged with the cloud's; saves and pushes the result.
    func merged(with local: [ChallengeRecord]) -> [ChallengeRecord] {
        // Newest 500: the key-value store holds a megabyte in all, shared with the scores.
        let merged = Array(ChallengeRecord.merge(local, Self.decode(store.data(forKey: Self.key))).prefix(500))
        save(merged)
        return merged
    }

    func save(_ records: [ChallengeRecord]) {
        let data = try? JSONEncoder().encode(records)
        UserDefaults.standard.set(data, forKey: Self.key)
        store.set(data, forKey: Self.key)
    }

    private static func decode(_ data: Data?) -> [ChallengeRecord] {
        data.flatMap { try? JSONDecoder().decode([ChallengeRecord].self, from: $0) } ?? []
    }
}
