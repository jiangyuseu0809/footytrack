import SwiftUI

/// Entry point for the watchOS Football Tracker app.
@main
struct FootballTrackerWatchApp: App {
    @StateObject private var trackingManager = TrackingManager()

    init() {
        // Activate WCSession early so transfer works reliably
        _ = PhoneSync.shared
    }

    var body: some Scene {
        WindowGroup {
            WatchTrackingView(manager: trackingManager)
        }
    }
}
