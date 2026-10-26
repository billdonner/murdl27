import Foundation
import StoreKit

/// The one paid unlock: MURDL Multiplayer, a non-consumable that covers sending and playing
/// challenges on every device on the Apple Account. The last known answer is cached so the app
/// opens unlocked offline; StoreKit corrects it as soon as it can.
@MainActor
final class MultiplayerStore: ObservableObject {
    nonisolated static let productID = "com.billdonner.murdl27.multiplayer"
    private static let cacheKey = "MurdlMultiplayerUnlocked"

    @Published private(set) var isUnlocked: Bool
    @Published private(set) var product: Product?
    @Published private(set) var isBusy = false
    @Published private(set) var message: String?
    private var updates: Task<Void, Never>?

    /// Debug builds launched with `MURDL_MULTIPLAYER=1` act unlocked, for the simulator, where
    /// the StoreKit test configuration only applies to runs started from Xcode.
    private static var debugUnlocked: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["MURDL_MULTIPLAYER"] == "1"
        #else
        return false
        #endif
    }

    init() {
        isUnlocked = UserDefaults.standard.bool(forKey: Self.cacheKey) || Self.debugUnlocked
        updates = Task.detached { [weak self] in
            for await update in Transaction.updates {
                await self?.apply(update)
            }
        }
        Task { await refresh() }
    }

    /// Loads the product for its price and rechecks what this Apple Account owns.
    func refresh() async {
        if product == nil {
            product = try? await Product.products(for: [Self.productID]).first
        }
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        setUnlocked(owned)
    }

    func purchase() async {
        guard let product, !isBusy else { return }
        isBusy = true
        message = nil
        defer { isBusy = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                await apply(result)
            case .pending:
                message = "Waiting for approval. Multiplayer unlocks as soon as it's approved."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = "The purchase didn't go through: \(error.localizedDescription)"
        }
    }

    func restore() async {
        guard !isBusy else { return }
        isBusy = true
        message = nil
        defer { isBusy = false }
        try? await AppStore.sync()
        await refresh()
        if !isUnlocked { message = "No Multiplayer purchase found for this Apple Account." }
    }

    private func apply(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result, transaction.productID == Self.productID else { return }
        setUnlocked(transaction.revocationDate == nil)
        await transaction.finish()
    }

    private func setUnlocked(_ unlocked: Bool) {
        isUnlocked = unlocked || Self.debugUnlocked
        UserDefaults.standard.set(unlocked, forKey: Self.cacheKey)
    }
}
