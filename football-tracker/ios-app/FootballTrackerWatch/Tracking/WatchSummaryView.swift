import SwiftUI

/// Summary view shown after a football session ends on watchOS.
struct WatchSummaryView: View {
    @ObservedObject var manager: TrackingManager

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("✅ 已完成")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.green)

                SummaryRow(label: "时长", value: formatTime(manager.summaryDurationSeconds))
                SummaryRow(label: "距离", value: String(format: "%.1fkm", manager.summaryDistanceMeters / 1000.0))
                SummaryRow(label: "卡路里", value: "\(Int(manager.summaryCalories))")
                SummaryRow(label: "摸鱼", value: "\(manager.summarySlackIndex)%")

                if WatchApiClient.shared.isAuthenticated {
                    Text("数据已上传到云端")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                } else {
                    Text("数据已缓存，登录后自动上传")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }

                Button("完成") {
                    manager.dismissSummary()
                }
                .buttonStyle(.bordered)
            }
            .padding(8)
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
        }
    }
}
