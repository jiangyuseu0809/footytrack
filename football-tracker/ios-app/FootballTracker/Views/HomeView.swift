import SwiftUI
import WatchConnectivity
import UIKit

/// Home screen dashboard with monthly overview and session timeline.
struct HomeView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject private var watchSync = WatchSync.shared
    @State private var showWatchAlert = false
    @State private var isWeeklyCardFlipped = false
    @AppStorage("home_has_shown_card_flip_hint") private var hasShownCardFlipHint = false

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

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x0A1016), AppColors.darkBg],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    topActionCards
                    overviewHeroCard

                    if store.sessions.isEmpty {
                        emptyStateCard
                    } else {
                        heatmapEntryCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
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
        .task {
            guard !hasShownCardFlipHint else { return }
            hasShownCardFlipHint = true
            try? await Task.sleep(nanoseconds: 700_000_000)
            withAnimation(.easeInOut(duration: 0.45)) {
                isWeeklyCardFlipped = true
            }
        }
    }

    private var watchButton: some View {
        Button {
            if !watchSync.isWatchAppInstalled {
                showWatchAlert = true
            }
        } label: {
            Image(systemName: watchSync.isWatchAppInstalled
                  ? "applewatch.radiowaves.left.and.right"
                  : "applewatch")
                .font(.body.weight(.medium))
                .foregroundColor(watchSync.isWatchAppInstalled
                                 ? AppColors.neonBlue
                                 : AppColors.textSecondary)
        }
    }

    private func openWatchApp() {
        if let url = URL(string: "itms-watchs://") {
            UIApplication.shared.open(url)
        }
    }

    private var topActionCards: some View {
        HStack(spacing: 6) {
            FlippableTopActionCard(
                frontTitle: "本周训练",
                frontSubtitle: "\(thisWeekSessionsCount) 场",
                backTitle: "今日训练",
                backSubtitle: "\(todaySessionsCount) 场",
                icon: "calendar",
                iconBg: AppColors.neonBlue.opacity(0.18),
                iconColor: AppColors.neonBlue,
                cardBg: AppColors.cardBg,
                borderColor: AppColors.neonBlue.opacity(0.2),
                isFlipped: $isWeeklyCardFlipped
            )

            TopActionCard(
                title: "加入比赛",
                subtitle: "点击加入",
                icon: "figure.soccer",
                iconBg: AppColors.neonPurple.opacity(0.18),
                iconColor: AppColors.neonPurple
            )
        }
    }

    private var overviewHeroCard: some View {
        ZStack {
            overviewCardFace(title: "本周训练总览", subtitle: "本周 \(thisWeekSessionsCount) 场训练", sessions: thisWeekSessions, rotation: 0, opacity: isWeeklyCardFlipped ? 0 : 1)
            overviewCardFace(title: "今日训练总览", subtitle: "今日 \(todaySessionsCount) 场训练", sessions: todaySessions, rotation: 180, opacity: isWeeklyCardFlipped ? 1 : 0)
        }
        .rotation3DEffect(
            .degrees(isWeeklyCardFlipped ? 180 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.7
        )
        .animation(.easeInOut(duration: 0.45), value: isWeeklyCardFlipped)
    }

    private func overviewCardFace(title: String, subtitle: String, sessions: [FootballSession], rotation: Double, opacity: Double) -> some View {
        let totalDistanceKm = sessions.reduce(0.0) { $0 + $1.totalDistanceMeters } / 1000.0
        let totalCalories = sessions.reduce(0.0) { $0 + $1.caloriesBurned }
        let totalDurationMinutes = sessions.reduce(0) { result, session in
            result + Int(session.endTime.timeIntervalSince(session.startTime) / 60)
        }

        let progressTarget = title == "今日训练总览" ? 1 : weekTargetSessions
        let progress = progressTarget > 0 ? min(Double(sessions.count) / Double(progressTarget), 1.0) : 0
        let progressPercent = Int(progress * 100)
        let remaining = max(progressTarget - sessions.count, 0)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Text(String(format: "%.1f km", totalDistanceKm))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(AppColors.cardBgLight)
                    .clipShape(Capsule())
            }

            progressBar(progress: progress, progressPercent: progressPercent, remainingSessions: remaining, targetSessions: progressTarget)

            HStack(spacing: 8) {
                HeroMetricChip(value: String(format: "%.0f", totalCalories), label: "总热量", icon: "flame.fill", tint: AppColors.calorieOrange)
                HeroMetricChip(value: "\(totalDurationMinutes) 分", label: "总时长", icon: "clock.fill", tint: AppColors.neonBlue)
                HeroMetricChip(value: "\(sessions.count)", label: "场次", icon: "sportscourt.fill", tint: AppColors.speedGreen)
            }

            HStack(spacing: 8) {
                HeroMetricChip(value: String(format: "%.1f km", totalDistanceKm), label: "跑动距离", icon: "figure.run", tint: AppColors.neonBlue)
                HeroMetricChip(value: String(format: "%.1f km/h", sessions.map(\.maxSpeedKmh).max() ?? 0), label: "最高速度", icon: "speedometer", tint: AppColors.speedGreen)
                HeroMetricChip(value: "\(sessions.isEmpty ? 0 : Int(Double(sessions.map(\.slackIndex).reduce(0, +)) / Double(sessions.count)))", label: "摸鱼指数", icon: "bolt.fill", tint: AppColors.slackYellow)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [AppColors.cardBgLight, AppColors.cardBg],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
        .opacity(opacity)
    }

    private func progressBar(progress: Double, progressPercent: Int, remainingSessions: Int, targetSessions: Int) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("目标 \(targetSessions) 场")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Text("\(progressPercent)%")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundColor(AppColors.textPrimary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 7)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppColors.neonGradient)
                        .frame(
                            width: progress == 0 ? 0 : max(18, proxy.size.width * progress),
                            height: 7
                        )
                }
            }
            .frame(height: 7)

            HStack {
                Text(remainingSessions == 0
                     ? "目标已达成"
                     : "还差 \(remainingSessions) 场达标")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()
            }
        }
    }


    private var currentModeTitle: String {
        isWeeklyCardFlipped ? "今日数据分析" : "本周数据分析"
    }

    private var currentModeSubtitle: String {
        if isWeeklyCardFlipped {
            return "聚合今日 \(todaySessionsCount) 场训练轨迹"
        }
        return "聚合本周 \(thisWeekSessionsCount) 场训练轨迹"
    }

    private var currentModeSessions: [FootballSession] {
        isWeeklyCardFlipped ? todaySessions : thisWeekSessions
    }

    private var currentModeTrackPoints: [TrackPointRecord] {
        currentModeSessions.flatMap { store.getTrackPoints(for: $0) }
    }

    private var heatmapEntryCard: some View {
        NavigationLink(
            destination: HomeAnalysisDetailView(
                title: currentModeTitle,
                sessions: currentModeSessions,
                isWeeklyMode: !isWeeklyCardFlipped,
                store: store
            )
        ) {
            ZStack {
                heatmapEntryFace(
                    title: "本周数据分析",
                    subtitle: "查看本周 \(thisWeekSessionsCount) 场训练分析",
                    sessions: thisWeekSessions,
                    rotation: 0,
                    opacity: isWeeklyCardFlipped ? 0 : 1
                )

                heatmapEntryFace(
                    title: "今日数据分析",
                    subtitle: "查看今日 \(todaySessionsCount) 场训练分析",
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
        }
        .buttonStyle(.plain)
    }

    private func heatmapEntryFace(title: String, subtitle: String, sessions: [FootballSession], rotation: Double, opacity: Double) -> some View {
        let points = sessions.flatMap { store.getTrackPoints(for: $0) }

        return ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x1B8E5F), Color(hex: 0x11573A)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.9))
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.92))

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
        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
        .opacity(opacity)
    }

    private var emptyStateCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "sportscourt")
                .font(.system(size: 34))
                .foregroundColor(AppColors.neonBlue)

            Text("还没有训练记录")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)

            Text("请在 Apple Watch 上开始一场训练")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(AppColors.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
            formatter.dateFormat = "MM/dd HH:mm"
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
                            StatCardView(label: "总时长", value: "\(weeklyTotalDurationMinutes)", unit: "min", color: .teal)
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
                                        Text("\(item.durationMinutes) min")
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
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 2)

            RoundedRectangle(cornerRadius: 8)
                .fill(iconBg)
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(iconColor)
                )
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppColors.cardBg)
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }
}

struct FlippableTopActionCard: View {
    let frontTitle: String
    let frontSubtitle: String
    let backTitle: String
    let backSubtitle: String
    let icon: String
    let iconBg: Color
    let iconColor: Color
    let cardBg: Color
    let borderColor: Color
    @Binding var isFlipped: Bool

    var body: some View {
        ZStack {
            cardFace(title: frontTitle, subtitle: frontSubtitle, rotation: 0, opacity: isFlipped ? 0 : 1)
            cardFace(title: backTitle, subtitle: backSubtitle, rotation: 180, opacity: isFlipped ? 1 : 0)
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

    private func cardFace(title: String, subtitle: String, rotation: Double, opacity: Double) -> some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(AppColors.neonBlue.opacity(0.88))
                    .lineLimit(1)
            }

            Spacer(minLength: 2)

            VStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppColors.neonBlue.opacity(0.9))
                    .frame(width: 16, height: 16)

                RoundedRectangle(cornerRadius: 8)
                    .fill(iconBg)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(iconColor)
                    )
            }
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(cardBg)
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
        .opacity(opacity)
    }
}

struct DashboardStatTile: View {
    let title: String
    let value: String
    let icon: String
    let iconColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundColor(iconColor)

            Text(title)
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppColors.cardBg)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
                Text("\(distKm) km · \(durationMin) 分钟")
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
