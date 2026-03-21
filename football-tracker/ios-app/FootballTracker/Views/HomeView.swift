import SwiftUI
import WatchConnectivity
import UIKit

/// Home screen dashboard with monthly overview and session timeline.
struct HomeView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var authManager: AuthManager
    @ObservedObject private var watchSync = WatchSync.shared
    @State private var showWatchAlert = false
    @State private var isWeeklyCardFlipped = true
    @State private var navigateToTodayDetail = false
    @State private var navigateToTodayList = false
    @State private var navigateToWeeklyAnalysis = false
    @State private var isWatchPulseAnimating = false
    @State private var navigateToCreateMatch = false
    @State private var navigateToMatchDetail = false

    private struct MonthSection: Identifiable {
        let id: String
        let title: String
        let sessions: [FootballSession]
    }

    private var thisMonthSessions: [FootballSession] {
        let cal = Calendar.current
        let now = Date()
        let currentMonth = cal.component(.month, from: now)
        let currentYear = cal.component(.year, from: now)

        return store.sessions.filter { session in
            let comps = cal.dateComponents([.year, .month], from: session.startTime)
            return comps.year == currentYear && comps.month == currentMonth
        }
    }

    private var thisWeekSessions: [FootballSession] {
        let cal = Calendar.current
        let nowComps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())

        return store.sessions.filter { session in
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: session.startTime)
            return comps.yearForWeekOfYear == nowComps.yearForWeekOfYear
                && comps.weekOfYear == nowComps.weekOfYear
        }
    }

    private var todaySessions: [FootballSession] {
        let cal = Calendar.current
        return store.sessions.filter { cal.isDateInToday($0.startTime) }
    }

    private var monthSections: [MonthSection] {
        let grouped = Dictionary(grouping: store.sessions) { session -> String in
            let cal = Calendar.current
            let comps = cal.dateComponents([.year, .month], from: session.startTime)
            return "\(comps.year!)-\(comps.month!)"
        }

        return grouped
            .map { key, sessions in
                let parts = key.split(separator: "-")
                let year = Int(parts[0]) ?? 0
                let month = Int(parts[1]) ?? 0
                let title = "\(year)年\(month)月"
                let sorted = sessions.sorted { $0.startTime > $1.startTime }
                return MonthSection(id: key, title: title, sessions: sorted)
            }
            .sorted { $0.id > $1.id }
    }

    private var thisWeekSessionsCount: Int {
        thisWeekSessions.count
    }

    private var todaySessionsCount: Int {
        todaySessions.count
    }

    private var monthAverageDurationMinutes: Int {
        guard !thisMonthSessions.isEmpty else { return 0 }
        let monthTotalDurationMinutes = thisMonthSessions.reduce(0) { result, session in
            result + Int(session.endTime.timeIntervalSince(session.startTime) / 60)
        }
        return monthTotalDurationMinutes / thisMonthSessions.count
    }

    private var monthAverageDistanceKm: Double {
        guard !thisMonthSessions.isEmpty else { return 0 }
        let monthTotalDistanceKm = thisMonthSessions.reduce(0.0) { $0 + $1.totalDistanceMeters } / 1000.0
        return monthTotalDistanceKm / Double(thisMonthSessions.count)
    }

    private var monthBestSlack: Int {
        thisMonthSessions.map(\.slackIndex).min() ?? 0
    }

    private let weekTargetSessions = 5

    private var activeSessions: [FootballSession] {
        isWeeklyCardFlipped ? todaySessions : thisWeekSessions
    }

    private var activeTotalDistanceKm: Double {
        activeSessions.reduce(0.0) { $0 + $1.totalDistanceMeters } / 1000.0
    }

    private var activeTotalCalories: Double {
        activeSessions.reduce(0.0) { $0 + $1.caloriesBurned }
    }

    private var activeTotalSprints: Int {
        activeSessions.reduce(0) { $0 + $1.sprintCount }
    }

    private var activeTotalMinutes: Int {
        activeSessions.reduce(0) { result, session in
            result + Int(session.endTime.timeIntervalSince(session.startTime) / 60)
        }
    }

    private var activeMaxSpeed: Double {
        activeSessions.map(\.maxSpeedKmh).max() ?? 0
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x0A1016), AppColors.darkBg],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    topActionCards

                    if let nextMatch = authManager.upcomingMatches.first(where: { match in
                        let matchDate = Date(timeIntervalSince1970: TimeInterval(match.matchDate) / 1000.0)
                        return Date().timeIntervalSince(matchDate) < 4 * 3600
                    }) {
                        upcomingMatchCard(nextMatch)
                    }

                    if store.sessions.isEmpty {
                        emptyStateCard
                    } else {
                        keyStatsSection
                        heatmapSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("野球记")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                watchButton
            }
        }
        .alert("安装 Apple Watch 应用", isPresented: $showWatchAlert) {
            Button("前往安装") {
                openWatchApp()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("在 Apple Watch 上安装野球记，即可记录踢球数据并自动同步到手机。")
        }
        .onAppear {
            if watchSync.isWatchConnected {
                isWatchPulseAnimating = true
            }
        }
        .onChange(of: watchSync.isWatchConnected) { _, connected in
            if connected {
                isWatchPulseAnimating = true
            } else {
                isWatchPulseAnimating = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .matchCreated)) { _ in
            Task {
                await authManager.loadMatchesIfNeeded(forceRefresh: true)
            }
        }
    }

    private var watchButton: some View {
        Button {
            if !watchSync.isWatchConnected {
                showWatchAlert = true
            }
        } label: {
            ZStack {
                if watchSync.isWatchConnected {
                    Circle()
                        .fill(AppColors.neonBlue.opacity(0.26))
                        .frame(width: 28, height: 28)
                        .scaleEffect(isWatchPulseAnimating ? 1.25 : 0.75)
                        .opacity(isWatchPulseAnimating ? 0 : 0.9)
                        .animation(
                            .easeOut(duration: 1.2).repeatForever(autoreverses: false),
                            value: isWatchPulseAnimating
                        )
                }

                Image(systemName: watchSync.isWatchConnected
                      ? "applewatch.radiowaves.left.and.right"
                      : "applewatch")
                    .font(.body.weight(.medium))
                    .foregroundColor(watchSync.isWatchConnected
                                     ? AppColors.neonBlue
                                     : AppColors.textSecondary)
            }
            .frame(width: 30, height: 30)
        }
    }

    private func openWatchApp() {
        if let url = URL(string: "itms-watchs://") {
            UIApplication.shared.open(url)
        }
    }

    private func upcomingMatchCard(_ match: MatchResponse) -> some View {
        let matchDate = Date(timeIntervalSince1970: TimeInterval(match.matchDate) / 1000.0)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE HH:mm"
        let dateText = formatter.string(from: matchDate)
        let colors = match.groupColors.split(separator: ",").map(String.init)
        let totalPlayers = match.groups * match.playersPerGroup

        return Button {
            navigateToMatchDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("即将开赛")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: 0xFACC15))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white.opacity(0.7))
                }

                Text(match.title)
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 14) {
                    Label(dateText, systemImage: "calendar")
                    Label(match.location, systemImage: "mappin")
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.85))

                HStack(spacing: 14) {
                    Label("\(match.registrationCount)/\(totalPlayers)人", systemImage: "person.2.fill")

                    if colors.count >= 2 {
                        HStack(spacing: 4) {
                            ForEach(colors, id: \.self) { colorName in
                                Circle()
                                    .fill(teamColorFromName(colorName))
                                    .frame(width: 12, height: 12)
                            }
                        }
                    }
                }
                .font(.caption.weight(.medium))
                .foregroundColor(.white.opacity(0.9))
            }
            .padding(14)
            .background(
                LinearGradient(
                    colors: [Color(hex: 0x16803B), Color(hex: 0x166534)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: 0xFACC15).opacity(0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .navigationDestination(isPresented: $navigateToMatchDetail) {
            MatchDetailView(matchId: match.id, authManager: authManager)
        }
    }

    private func teamColorFromName(_ name: String) -> Color {
        switch name.trimmingCharacters(in: .whitespaces).lowercased() {
        case "red": return Color(hex: 0xEF4444)
        case "blue": return Color(hex: 0x3B82F6)
        case "green": return Color(hex: 0x22C55E)
        case "orange": return Color(hex: 0xF97316)
        case "yellow": return Color(hex: 0xFACC15)
        case "white": return Color.white
        default: return Color.gray
        }
    }

    private var topActionCards: some View {
        HStack(spacing: 12) {
            FlippableTopActionCard(
                frontTitle: "本周比赛",
                frontValue: "\(thisWeekSessionsCount)",
                frontUnit: "场",
                backTitle: "今日比赛",
                backValue: "\(todaySessionsCount)",
                backUnit: "场",
                icon: "calendar",
                iconBg: Color.white.opacity(0.2),
                iconColor: .white,
                cardBg: AppColors.cardBg,
                borderColor: AppColors.neonBlue.opacity(0.2),
                isFlipped: $isWeeklyCardFlipped
            )
            .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 150)

            Button {
                navigateToCreateMatch = true
            } label: {
                TopActionCard(
                    title: "发起比赛",
                    subtitle: "邀请球友参赛",
                    icon: "person.2.fill",
                    iconBg: AppColors.neonBlue.opacity(0.16),
                    iconColor: AppColors.neonBlue
                )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 150)
            .navigationDestination(isPresented: $navigateToCreateMatch) {
                CreateMatchView()
            }
        }
    }

    private var keyStatsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("关键数据")
                .font(.title3.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)

            ZStack {
                keyStatsFace(for: thisWeekSessions, modeTag: "+本周", rotation: 0, opacity: isWeeklyCardFlipped ? 0 : 1)
                keyStatsFace(for: todaySessions, modeTag: "+今日", rotation: 180, opacity: isWeeklyCardFlipped ? 1 : 0)
            }
            .rotation3DEffect(
                .degrees(isWeeklyCardFlipped ? 180 : 0),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.7
            )
            .animation(.easeInOut(duration: 0.45), value: isWeeklyCardFlipped)
        }
    }

    private func keyStatsFace(for sessions: [FootballSession], modeTag: String, rotation: Double, opacity: Double) -> some View {
        let totalDistanceKm = sessions.reduce(0.0) { $0 + $1.totalDistanceMeters } / 1000.0
        let totalCalories = sessions.reduce(0.0) { $0 + $1.caloriesBurned }
        let totalSprints = sessions.reduce(0) { $0 + $1.sprintCount }
        let totalMinutes = sessions.reduce(0) { result, session in
            result + Int(session.endTime.timeIntervalSince(session.startTime) / 60)
        }
        let maxSpeed = sessions.map(\.maxSpeedKmh).max() ?? 0

        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                DashboardStatTile(title: "跑动距离", value: String(format: "%.1f km", totalDistanceKm), icon: "figure.run", iconColor: Color(hex: 0xA855F7), changeText: modeTag)
                DashboardStatTile(title: "冲刺次数", value: "\(totalSprints)", icon: "bolt.fill", iconColor: Color(hex: 0xF97316), changeText: "+\(totalSprints)")
            }

            HStack(spacing: 12) {
                DashboardStatTile(title: "消耗热量", value: String(format: "%.0f", totalCalories), icon: "flame.fill", iconColor: Color(hex: 0xEF4444), changeText: "+\(Int(totalCalories))")
                DashboardStatTile(title: "训练时长", value: formatDuration(totalMinutes), icon: "clock.fill", iconColor: Color(hex: 0x22D3EE), changeText: String(format: "%.1f km/h", maxSpeed))
            }
        }
        .padding(14)
        .background(AppColors.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
        )
        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
        .opacity(opacity)
    }

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("活动热区")
                .font(.title3.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)

            heatmapEntryCard
        }
    }

    private var currentModeTitle: String {
        isWeeklyCardFlipped ? "今日分析" : "本周分析"
    }

    private var currentModeSubtitle: String {
        if isWeeklyCardFlipped {
            return "查看今日 \(todaySessionsCount) 场比赛分析"
        }
        return "查看本周 \(thisWeekSessionsCount) 场比赛分析"
    }

    private var currentModeSessions: [FootballSession] {
        isWeeklyCardFlipped ? todaySessions : thisWeekSessions
    }

    private func formatDuration(_ totalMinutes: Int) -> String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 {
            return "\(minutes)分"
        }
        return "\(hours)小时\(minutes)分"
    }

    private var heatmapEntryCard: some View {
        ZStack {
            heatmapEntryFace(
                title: "本周数据分析",
                subtitle: "查看本周 \(thisWeekSessionsCount) 场比赛分析",
                sessions: thisWeekSessions,
                rotation: 0,
                opacity: isWeeklyCardFlipped ? 0 : 1
            )

            heatmapEntryFace(
                title: "今日数据分析",
                subtitle: "查看今日 \(todaySessionsCount) 场比赛详情",
                sessions: todaySessions,
                rotation: 180,
                opacity: isWeeklyCardFlipped ? 1 : 0
            )
        }
        .rotation3DEffect(
            .degrees(isWeeklyCardFlipped ? 180 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.7
        )
        .animation(.easeInOut(duration: 0.45), value: isWeeklyCardFlipped)
        .frame(height: 132)
        .contentShape(Rectangle())
        .onTapGesture {
            if isWeeklyCardFlipped {
                guard !todaySessions.isEmpty else { return }
                if todaySessions.count == 1 {
                    navigateToTodayDetail = true
                } else {
                    navigateToTodayList = true
                }
            } else {
                guard !thisWeekSessions.isEmpty else { return }
                navigateToWeeklyAnalysis = true
            }
        }
        .navigationDestination(isPresented: $navigateToWeeklyAnalysis) {
            WeeklySummaryView(store: store)
        }
        .navigationDestination(isPresented: $navigateToTodayDetail) {
            if let session = todaySessions.first {
                SessionDetailView(session: session, store: store)
            }
        }
        .navigationDestination(isPresented: $navigateToTodayList) {
            AllMatchesView(sessions: todaySessions, store: store)
        }
    }

    private func heatmapEntryFace(title: String, subtitle: String, sessions: [FootballSession], rotation: Double, opacity: Double) -> some View {
        let points = sessions.flatMap { store.getTrackPoints(for: $0) }

        return ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    sessions.isEmpty
                    ? LinearGradient(
                        colors: [AppColors.cardBg, AppColors.cardBg],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(
                        colors: [Color(hex: 0x16803B), Color(hex: 0x166534)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            if sessions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "figure.soccer")
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.textSecondary)
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("暂无比赛数据，去踢球吧")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(title)
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white.opacity(0.9))
                    }

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))

                    HStack(spacing: 8) {
                        Label("\(sessions.count) 场", systemImage: "sportscourt")
                        Label("\(points.count) 点", systemImage: "point.3.connected.trianglepath.dotted")
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.top, 2)
                }
                .padding(.horizontal, 16)
                .frame(maxHeight: .infinity, alignment: .center)
            }
        }
        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
        .opacity(opacity)
    }

    private var emptyStateCard: some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: 0x1F2937))
                .frame(width: 94, height: 94)
                .overlay(
                    Image(systemName: "applewatch")
                        .font(.system(size: 42))
                        .foregroundColor(AppColors.textSecondary)
                )

            Text("暂无数据")
                .font(.title3.weight(.bold))
                .foregroundColor(AppColors.textPrimary)

            Text("连接 Apple Watch 后即可开始记录你的足球表现。")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Button {
                showWatchAlert = true
            } label: {
                Text("连接 Apple Watch")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: 0x3B82F6), Color(hex: 0x4F46E5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            VStack(spacing: 8) {
                emptyFeatureRow(icon: "bolt.fill", title: "实时表现", desc: "比赛中实时查看关键数据")
                emptyFeatureRow(icon: "scope", title: "热区图", desc: "查看你的跑动分布")
                emptyFeatureRow(icon: "chart.bar.fill", title: "高级分析", desc: "智能洞察你的训练表现")
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(AppColors.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func emptyFeatureRow(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.cardBgLight)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: icon)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.textSecondary)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                Text(desc)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(10)
        .background(AppColors.cardBgLight.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct HomeAnalysisDetailView: View {
    let title: String
    let sessions: [FootballSession]
    let isWeeklyMode: Bool
    @ObservedObject var store: SessionStore

    private struct SessionAnalysisItem: Identifiable {
        let id: String
        let session: FootballSession
        let points: [TrackPointRecord]
        let stats: SessionAnalysisResult

        var durationMinutes: Int {
            Int(session.endTime.timeIntervalSince(session.startTime) / 60)
        }

        var dateText: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd HH:mm"
            return formatter.string(from: session.startTime)
        }
    }

    private var perSessionItems: [SessionAnalysisItem] {
        sessions
            .sorted { $0.startTime < $1.startTime }
            .map { session in
                let sessionPoints = store.getTrackPoints(for: session)
                return SessionAnalysisItem(
                    id: session.id,
                    session: session,
                    points: sessionPoints,
                    stats: store.computeStats(from: sessionPoints)
                )
            }
    }

    private var points: [TrackPointRecord] {
        perSessionItems
            .flatMap(\.points)
            .sorted { $0.timestamp < $1.timestamp }
    }

    private var sessionsCount: Int {
        sessions.count
    }

    private var stats: SessionAnalysisResult {
        store.computeStats(from: points)
    }

    private var weeklyTotalDurationMinutes: Int {
        perSessionItems.reduce(0) { $0 + $1.durationMinutes }
    }

    private var weeklyAvgSpeed: Double {
        guard weeklyTotalDurationMinutes > 0 else { return 0 }
        return (stats.totalDistanceMeters / Double(weeklyTotalDurationMinutes * 60)) * 3.6
    }

    private var weeklyAvgHeartRate: Int {
        let hrSamples = points.filter { $0.heartRate > 0 }.map(\.heartRate)
        guard !hrSamples.isEmpty else { return 0 }
        return Int(Double(hrSamples.reduce(0, +)) / Double(hrSamples.count))
    }

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    HStack(spacing: 10) {
                        statPill(title: "场次", value: "\(sessionsCount)")
                        statPill(title: "轨迹点", value: "\(points.count)")
                        statPill(title: "覆盖率", value: String(format: "%.0f%%", stats.coveragePercent))
                    }

                    if points.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "figure.soccer")
                                .font(.system(size: 32))
                                .foregroundColor(AppColors.textSecondary)
                            Text("暂无轨迹数据")
                                .font(.headline)
                                .foregroundColor(AppColors.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .background(AppColors.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else if isWeeklyMode {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            StatCardView(label: "总距离", value: String(format: "%.1f", stats.totalDistanceMeters / 1000), unit: "km", color: .blue)
                            StatCardView(label: "总时长", value: "\(weeklyTotalDurationMinutes)", unit: "分", color: .teal)
                            StatCardView(label: "平均速度", value: String(format: "%.1f", weeklyAvgSpeed), unit: "km/h", color: .orange)
                            StatCardView(label: "最高速度", value: String(format: "%.1f", perSessionItems.map { $0.stats.maxSpeedKmh }.max() ?? 0), unit: "km/h", color: .red)
                            StatCardView(label: "平均心率", value: "\(weeklyAvgHeartRate)", unit: "bpm", color: .pink)
                            StatCardView(label: "冲刺次数", value: "\(perSessionItems.reduce(0) { $0 + $1.stats.sprintCount })", unit: "次", color: .yellow)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("按场次分析")
                                .font(.headline)
                                .foregroundColor(AppColors.textPrimary)

                            ForEach(perSessionItems) { item in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(item.dateText)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundColor(AppColors.textPrimary)
                                        Spacer()
                                        Text("\(item.durationMinutes) 分")
                                            .font(.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                    }

                                    HStack(spacing: 8) {
                                        miniMetric("距离", String(format: "%.1f km", item.stats.totalDistanceMeters / 1000))
                                        miniMetric("均速", String(format: "%.1f", item.stats.avgSpeedKmh))
                                        miniMetric("心率", "\(item.stats.avgHeartRate)")
                                        miniMetric("冲刺", "\(item.stats.sprintCount)")
                                    }

                                    SpeedChartView(points: item.points, showHeartRate: false)

                                    if item.points.contains(where: { $0.heartRate > 0 }) {
                                        SpeedChartView(points: item.points, showHeartRate: true)
                                    }

                                    if !item.stats.fatigueSegments.isEmpty {
                                        FatigueChartView(segments: item.stats.fatigueSegments)
                                    }
                                }
                                .padding(12)
                                .background(AppColors.cardBg)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    } else {
                        let lats = points.map(\.latitude)
                        let lons = points.map(\.longitude)
                        HeatmapOverlayView(
                            grid: stats.heatmapGrid,
                            minLat: lats.min() ?? 0,
                            maxLat: lats.max() ?? 0,
                            minLon: lons.min() ?? 0,
                            maxLon: lons.max() ?? 0
                        )

                        SpeedChartView(points: points, showHeartRate: false)

                        if points.contains(where: { $0.heartRate > 0 }) {
                            SpeedChartView(points: points, showHeartRate: true)
                        }

                        if !stats.fatigueSegments.isEmpty {
                            FatigueChartView(segments: stats.fatigueSegments)
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundColor(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppColors.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func miniMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(AppColors.cardBgLight)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct HeroMetricChip: View {
    let value: String
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundColor(tint)

            Text(value)
                .font(.subheadline.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .foregroundColor(AppColors.textPrimary)

            Text(label)
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .padding(10)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct TopActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconBg: Color
    let iconColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconBg)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(iconColor)
                    )
                Spacer()
            }

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .padding(14)
        .background(AppColors.cardBg)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct FlippableTopActionCard: View {
    let frontTitle: String
    let frontValue: String
    let frontUnit: String
    let backTitle: String
    let backValue: String
    let backUnit: String
    let icon: String
    let iconBg: Color
    let iconColor: Color
    let cardBg: Color
    let borderColor: Color
    @Binding var isFlipped: Bool

    var body: some View {
        ZStack {
            cardFace(title: frontTitle, value: frontValue, unit: frontUnit, rotation: 0, opacity: isFlipped ? 0 : 1)
            cardFace(title: backTitle, value: backValue, unit: backUnit, rotation: 180, opacity: isFlipped ? 1 : 0)
        }
        .rotation3DEffect(
            .degrees(isFlipped ? 180 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.7
        )
        .animation(.easeInOut(duration: 0.45), value: isFlipped)
        .contentShape(Rectangle())
        .onTapGesture {
            isFlipped.toggle()
        }
    }

    private func cardFace(title: String, value: String, unit: String, rotation: Double, opacity: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconBg)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(iconColor)
                    )

                Spacer()

                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.75))
            }

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)

            Spacer(minLength: 0)

            HStack(alignment: .bottom, spacing: 6) {
                Text(value)
                    .font(.system(size: 44, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer()

                Text(unit)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.bottom, 6)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x3B82F6), Color(hex: 0x4F46E5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
        .opacity(opacity)
    }
}

struct DashboardStatTile: View {
    let title: String
    let value: String
    let icon: String
    let iconColor: Color
    let changeText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundColor(iconColor)

                Spacer()

                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .bold))
                    Text(changeText)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundColor(Color(hex: 0x60A5FA))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
            }

            Text(title)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .monospacedDigit()
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppColors.cardBgLight.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SessionRow: View {
    let session: FootballSession

    private var dateStr: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM/dd EEE HH:mm"
        return formatter.string(from: session.startTime)
    }

    var body: some View {
        HStack(spacing: 11) {
            Circle()
                .fill(AppColors.neonBlue.opacity(0.16))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "figure.soccer")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.neonBlue)
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(dateStr)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)

                if !session.locationName.isEmpty {
                    Text(session.locationName)
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }

                let distKm = String(format: "%.1f", session.totalDistanceMeters / 1000.0)
                let durationMin = Int(session.endTime.timeIntervalSince(session.startTime) / 60)
                Text("\(distKm) 公里 · \(durationMin) 分钟")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 7) {
                SlackBadge(index: session.slackIndex)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(12)
        .background(AppColors.cardBgLight)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SlackBadge: View {
    let index: Int

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
