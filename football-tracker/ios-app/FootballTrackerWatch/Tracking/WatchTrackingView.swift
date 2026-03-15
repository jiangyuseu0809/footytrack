import SwiftUI

/// Main tracking view for watchOS - shows real-time stats during a football session.
struct WatchTrackingView: View {
    @ObservedObject var manager: TrackingManager

    var body: some View {
        VStack(spacing: 6) {
            Text(manager.isTracking ? "⚽ 踢球中" : "⚽ 准备开始")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)

            if manager.isTracking {
                // Timer
                Text("⏱ \(formatTime(manager.elapsedSeconds))")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)

                // Distance
                HStack {
                    Text("🏃")
                    Text(String(format: "%.1f km", manager.totalDistanceMeters / 1000.0))
                        .foregroundColor(.green)
                }
                .font(.system(size: 14))

                // Heart Rate
                HStack {
                    Text("❤️")
                    Text("\(manager.currentHeartRate) bpm")
                        .foregroundColor(.red)
                }
                .font(.system(size: 14))

                // Speed
                HStack {
                    Text("⚡")
                    Text(String(format: "%.1f km/h", manager.currentSpeedMs * 3.6))
                        .foregroundColor(.orange)
                }
                .font(.system(size: 14))
            }

            Spacer()

            Button(action: {
                if manager.isTracking {
                    manager.stopTracking()
                } else {
                    manager.startTracking()
                }
            }) {
                Text(manager.isTracking ? "结束记录" : "开始记录")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(manager.isTracking ? .red : .green)
        }
        .padding(8)
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
