import SwiftUI
import WatchConnectivity

/// Home screen showing a list of recorded football sessions grouped by month.
struct HomeView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject private var watchSync = WatchSync.shared
    @State private var showWatchAlert = false

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            Group {
                if store.sessions.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }
        }
        .navigationTitle("野球记")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                watchButton
            }
        }
        .alert("安装 Apple Watch App", isPresented: $showWatchAlert) {
            Button("前往安装") {
                openWatchApp()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("在 Apple Watch 上安装野球记，即可记录踢球数据并自动同步到手机。")
        }
    }

    // MARK: - Watch Button

    private var watchButton: some View {
        Button {
            if !watchSync.isWatchAppInstalled {
                showWatchAlert = true
            }
        } label: {
            Image(systemName: watchSync.isWatchAppInstalled
                  ? "applewatch.radiowaves.left.and.right"
                  : "applewatch")
                .font(.body)
                .foregroundColor(watchSync.isWatchAppInstalled
                                 ? AppColors.neonBlue
                                 : AppColors.textSecondary)
        }
    }

    private func openWatchApp() {
        // Deep link to the Watch app on iPhone to install companion app
        if let url = URL(string: "itms-watchs://") {
            UIApplication.shared.open(url)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sportscourt")
                .font(.system(size: 48))
                .foregroundColor(AppColors.textSecondary)
            Text("还没有记录")
                .font(.headline)
                .foregroundColor(AppColors.textSecondary)
            Text("在手表上开始记录踢球数据")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sessionList: some View {
        let grouped = Dictionary(grouping: store.sessions) { session -> String in
            let cal = Calendar.current
            let comps = cal.dateComponents([.year, .month], from: session.startTime)
            return "\(comps.year!)年\(comps.month!)月"
        }
        let sortedKeys = grouped.keys.sorted().reversed()

        return ScrollView {
            VStack(spacing: 16) {
                // Monthly summary card for current month
                monthlySummaryCard

                ForEach(Array(sortedKeys), id: \.self) { month in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(month)
                            .font(.headline)
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.horizontal, 16)

                        ForEach(grouped[month]!, id: \.id) { session in
                            NavigationLink(destination: SessionDetailView(session: session, store: store)) {
                                SessionRow(session: session)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: - Monthly Summary Card

    private var monthlySummaryCard: some View {
        let cal = Calendar.current
        let now = Date()
        let currentMonth = cal.component(.month, from: now)
        let currentYear = cal.component(.year, from: now)
        let thisMonthSessions = store.sessions.filter { session in
            let comps = cal.dateComponents([.year, .month], from: session.startTime)
            return comps.year == currentYear && comps.month == currentMonth
        }

        let totalDistance = thisMonthSessions.reduce(0.0) { $0 + $1.totalDistanceMeters } / 1000.0
        let totalCalories = thisMonthSessions.reduce(0.0) { $0 + $1.caloriesBurned }
        let sessionCount = thisMonthSessions.count

        return VStack(spacing: 12) {
            HStack {
                Text("\(currentMonth)月训练概况")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text("\(sessionCount) 场")
                    .font(.subheadline)
                    .foregroundColor(AppColors.neonBlue)
            }

            HStack(spacing: 16) {
                SummaryItem(
                    icon: "figure.run",
                    value: String(format: "%.1f", totalDistance),
                    unit: "km",
                    color: AppColors.neonBlue
                )
                SummaryItem(
                    icon: "flame.fill",
                    value: String(format: "%.0f", totalCalories),
                    unit: "kcal",
                    color: AppColors.calorieOrange
                )
                SummaryItem(
                    icon: "sportscourt.fill",
                    value: "\(sessionCount)",
                    unit: "场次",
                    color: AppColors.speedGreen
                )
            }
        }
        .padding(16)
        .background(AppColors.cardBg)
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }
}

// MARK: - Summary Item

struct SummaryItem: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.title3.bold())
                .foregroundColor(AppColors.textPrimary)
            Text(unit)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: FootballSession

    private var dateStr: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM/dd EEE HH:mm"
        return formatter.string(from: session.startTime)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateStr)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColors.textPrimary)
                if !session.locationName.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                            .foregroundColor(AppColors.neonBlue)
                        Text(session.locationName)
                            .font(.caption)
                            .foregroundColor(AppColors.neonBlue)
                    }
                }
                let distKm = String(format: "%.1f", session.totalDistanceMeters / 1000.0)
                let durationMin = Int(session.endTime.timeIntervalSince(session.startTime) / 60)
                Text("\(distKm)km · \(durationMin)分钟")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            SlackBadge(index: session.slackIndex, label: session.slackLabel)
        }
        .padding(12)
        .background(AppColors.cardBg)
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
}

// MARK: - Slack Badge

struct SlackBadge: View {
    let index: Int
    let label: String

    private var bgColor: Color {
        switch index {
        case 0...30: return AppColors.slackGreen
        case 31...50: return Color(red: 0.33, green: 0.55, blue: 0.18)
        case 51...70: return AppColors.slackYellow
        default: return AppColors.slackRed
        }
    }

    var body: some View {
        Text("摸鱼指数 \(index)")
            .font(.caption2.weight(.medium))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
