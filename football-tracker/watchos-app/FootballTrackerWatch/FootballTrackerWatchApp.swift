import SwiftUI

/// Entry point for the watchOS Football Tracker app.
@main
struct FootballTrackerWatchApp: App {
    @StateObject private var trackingManager = TrackingManager()

    var body: some Scene {
        WindowGroup {
            if trackingManager.showSummary {
                WatchSummaryView(manager: trackingManager)
            } else {
                WatchTrackingView(manager: trackingManager)
            }
        }
    }
}
