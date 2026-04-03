import SwiftUI

/// Main tracking view for watchOS - shows real-time stats during a football session.
struct WatchTrackingView: View {
    @ObservedObject var manager: TrackingManager
    var isAuthenticated: Bool
    @State private var showBindView = false

    var body: some View {
        if manager.isTracking {
            trackingView
        } else {
            startView
        }
    }

    // MARK: - Start View (big circular button)

    private var startView: some View {
        VStack {
            if !isAuthenticated {
                Button(action: { showBindView = true }) {
                    Text("输入绑定码登录")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }

            Spacer()
            Button(action: { manager.startTracking() }) {
                Text("开始踢球")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 120, height: 120)
                    .background(
                        Circle().fill(isAuthenticated ? .green : .gray)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!isAuthenticated)
            Spacer()

            let pendingCount = WatchSessionQueue.shared.pendingCount
            if pendingCount > 0 {
                Text("\(pendingCount) 条数据待上传")
                    .font(.system(size: 10))
                    .foregroundColor(.yellow)
                    .padding(.bottom, 4)
            }
        }
        .sheet(isPresented: $showBindView) {
            WatchBindView()
        }
    }

    // MARK: - Tracking View (live stats + stop button)

    private var trackingView: some View {
        VStack(spacing: 6) {
            Text("⚽ 踢球中")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)

            Text(formatTime(manager.elapsedSeconds))
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)

            HStack {
                Text("🏃")
                Text(String(format: "%.1f km", manager.totalDistanceMeters / 1000.0))
                    .foregroundColor(.green)
            }
            .font(.system(size: 14))

            HStack {
                Text("❤️")
                Text("\(manager.currentHeartRate) bpm")
                    .foregroundColor(.red)
            }
            .font(.system(size: 14))

            HStack {
                Text("⚡")
                Text(String(format: "%.1f km/h", manager.currentSpeedMs * 3.6))
                    .foregroundColor(.orange)
            }
            .font(.system(size: 14))

            Spacer()

            Button(action: { manager.stopTracking() }) {
                Text("结束记录")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(8)
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
