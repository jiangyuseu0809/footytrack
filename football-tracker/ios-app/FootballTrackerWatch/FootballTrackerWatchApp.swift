import SwiftUI

/// Entry point for the watchOS Football Tracker app.
@main
struct FootballTrackerWatchApp: App {
    @StateObject private var trackingManager = TrackingManager()
    @StateObject private var phoneSync = PhoneSync.shared

    init() {
        // Activate WCSession early so token transfer works reliably
        _ = PhoneSync.shared
    }

    var body: some Scene {
        WindowGroup {
            if !phoneSync.isAuthenticated {
                WatchBindView()
            } else if trackingManager.showSummary {
                WatchSummaryView(manager: trackingManager)
            } else {
                WatchTrackingView(manager: trackingManager)
            }
        }
    }
}
