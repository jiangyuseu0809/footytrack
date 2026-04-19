import SwiftUI

/// Legacy summary view — no longer used. Finished state is now in WatchTrackingView.
struct WatchSummaryView: View {
    @ObservedObject var manager: TrackingManager

    var body: some View {
        EmptyView()
    }
}
