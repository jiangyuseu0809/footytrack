import SwiftUI

/// Overall statistics screen aggregating data across all sessions.
struct StatsView: View {
    @ObservedObject var store: SessionStore

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            if store.sessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "sportscourt")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.textSecondary)
                    Text("暂无数据")
                        .font(.headline)
                        .foregroundColor(AppColors.textSecondary)
                    Text("在手表上开始记录踢球数据")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    let sessions = store.sessions
                    let totalSessions = sessions.count
                    let totalDistance = sessions.map(\.totalDistanceMeters).reduce(0, +)
                    let totalTimeSeconds = sessions.map { $0.endTime.timeIntervalSince($0.startTime) }.reduce(0, +)
                    let totalCalories = sessions.map(\.caloriesBurned).reduce(0, +)
                    let avgSlack = Int(Double(sessions.map(\.slackIndex).reduce(0, +)) / Double(totalSessions))
                    let maxSpeed = sessions.map(\.maxSpeedKmh).max() ?? 0
                    let avgDistance = totalDistance / Double(totalSessions)

                    VStack(spacing: 16) {
                        Text("总览")
                            .font(.title2.weight(.bold))
                            .foregroundColor(AppColors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            StatCardView(label: "总场次", value: "\(totalSessions)", unit: "场", color: AppColors.neonBlue)
                            StatCardView(label: "总距离", value: String(format: "%.1f", totalDistance / 1000), unit: "km", color: AppColors.neonBlue)
                            StatCardView(label: "总时长", value: "\(Int(totalTimeSeconds / 3600))", unit: "小时", color: AppColors.neonPurple)
                            StatCardView(label: "总卡路里", value: "\(Int(totalCalories))", unit: "kcal", color: AppColors.calorieOrange)
                            StatCardView(label: "场均距离", value: String(format: "%.1f", avgDistance / 1000), unit: "km", color: AppColors.neonPurple)
                            StatCardView(label: "最高速度", value: String(format: "%.1f", maxSpeed), unit: "km/h", color: AppColors.heartRed)
                        }

                        StatCardView(label: "平均摸鱼指数", value: "\(avgSlack)", unit: "/100", color: AppColors.speedGreen)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("统计")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleDisplayMode(.inline)
    }
}
