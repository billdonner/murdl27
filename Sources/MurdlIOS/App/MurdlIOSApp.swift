import MurdlCore
import SwiftUI

@main
struct MurdlIOSApp: App {
    @StateObject private var game = MurdlGame()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            IOSRootView(game: game)
        }
        .onChange(of: scenePhase) { _, phase in
            // The app switcher and Control Center count as away: a timed game should not run there.
            game.setBackgrounded(phase != .active)
        }
    }
}
