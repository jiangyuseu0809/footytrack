import SwiftUI

/// Overall statistics screen aggregating data across all sessions.
struct StatsView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var authManager: AuthManager
    @State private var selectedAchievement: StatsAchievementItem?
    @State private var playerAnalysis: PlayerAnalysisResponse?
    @State private var isLoadingAnalysis = false

    private static let analysisCacheKey = "cached_player_analysis"
    private static let analysisCacheCountKey = "cached_player_analysis_session_count"

    private var sessions: [FootballSession] {
        store.sessions
    }

    private var totalSessions: Int {
        sessions.count
    }

    private var totalDistanceKm: Double {
        sessions.map(\.totalDistanceMeters).reduce(0, +) / 1000
    }

    private var totalCalories: Double {
        sessions.map(\.caloriesBurned).reduce(0, +)
    }

    private var maxSpeed: Double {
        sessions.map(\.maxSpeedKmh).max() ?? 0
    }

    private var avgSprints: Double {
        guard !sessions.isEmpty else { return 0 }
        return Double(sessions.map(\.sprintCount).reduce(0, +)) / Double(sessions.count)
    }

    private var avgSlack: Double {
        guard !sessions.isEmpty else { return 0 }
        return Double(sessions.map(\.slackIndex).reduce(0, +)) / Double(sessions.count)
    }

    private var abilityMetrics: [AbilityMetric] {
        let speedScore = min(100, maxSpeed / 35 * 100)
        let sprintScore = min(100, avgSprints / 50 * 100)
        let staminaScore = min(100, (totalDistanceKm / Double(max(totalSessions, 1))) / 10 * 100)
        let disciplineScore = max(0, 100 - avgSlack)
        let coverageScore = min(100, sessions.map(\.coveragePercent).reduce(0, +) / Double(max(totalSessions, 1)))

        return [
            AbilityMetric(name: "速度", value: speedScore),
            AbilityMetric(name: "冲刺", value: sprintScore),
            AbilityMetric(name: "体能", value: staminaScore),
            AbilityMetric(name: "专注", value: disciplineScore),
            AbilityMetric(name: "覆盖", value: coverageScore)
        ]
    }

    private var trendData: [TrendPoint] {
        let recent = Array(sessions.prefix(7).reversed())
        return recent.enumerated().map { index, session in
            let score = performanceScore(for: session)
            return TrendPoint(index: index + 1, score: score)
        }
    }

    private var recentMatches: [FootballSession] {
        Array(sessions.prefix(3))
    }

    private var achievementItems: [StatsAchievementItem] {
        let palette: [(Color, Color)] = [
            (Color(hex: 0xF59E0B), Color(hex: 0xF97316)),
            (Color(hex: 0x3B82F6), Color(hex: 0x06B6D4)),
            (Color(hex: 0xA855F7), Color(hex: 0xEC4899)),
            (Color(hex: 0xEF4444), Color(hex: 0xF43F5E)),
            (Color(hex: 0x22C55E), Color(hex: 0x10B981)),
            (Color(hex: 0x6366F1), Color(hex: 0x3B82F6))
        ]

        let all = authManager.earnedBadges?.allBadges ?? []
        let earnedIds = Set(authManager.earnedBadges?.earnedBadges.map { $0.badge.id } ?? [])

        let mapped = all.prefix(6).enumerated().map { idx, badge in
            let colors = palette[idx % palette.count]
            return StatsAchievementItem(
                icon: badgeIcon(badge.iconName),
                title: badge.name,
                description: badge.description,
                unlocked: earnedIds.contains(badge.id),
                start: colors.0,
                end: colors.1
            )
        }

        if mapped.count >= 6 { return Array(mapped) }

        let placeholders = [
            StatsAchievementItem(icon: "heart.fill", title: "铁肺", description: "敬请期待", unlocked: false, start: Color(hex: 0xEF4444), end: Color(hex: 0xF43F5E)),
            StatsAchievementItem(icon: "medal.fill", title: "最有价值球员", description: "敬请期待", unlocked: false, start: Color(hex: 0x22C55E), end: Color(hex: 0x10B981)),
            StatsAchievementItem(icon: "trophy.fill", title: "冠军", description: "敬请期待", unlocked: false, start: Color(hex: 0x6366F1), end: Color(hex: 0x3B82F6))
        ]

        return Array(mapped) + Array(placeholders.prefix(max(0, 6 - mapped.count)))
    }

    private var unlockedCount: Int {
        achievementItems.filter(\.unlocked).count
    }

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if sessions.isEmpty {
                        emptySection
                    } else {
                        styleSection
                        overviewSection
                        abilitiesSection
                        trendSection
                        achievementsSection
                        historySection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("统计")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleDisplayMode(.inline)
        .task {
            guard !sessions.isEmpty else { return }
            loadCachedAnalysis()
            let cachedCount = UserDefaults.standard.integer(forKey: Self.analysisCacheCountKey)
            let currentCount = sessions.count
            // First analysis at 4 sessions, then every 10 sessions
            let shouldAnalyze: Bool
            if playerAnalysis == nil {
                shouldAnalyze = currentCount >= 4
            } else {
                shouldAnalyze = currentCount - cachedCount >= 10
            }
            guard shouldAnalyze else { return }
            isLoadingAnalysis = true
            do {
                let result = try await ApiClient.shared.getPlayerAnalysis()
                playerAnalysis = result
                saveAnalysisCache(result, sessionCount: currentCount)
            } catch {
                // Keep cached result if available
            }
            isLoadingAnalysis = false
        }
    }

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI 类型")
                        .font(.caption)
                        .foregroundColor(Color.white.opacity(0.75))
                    if isLoadingAnalysis {
                        HStack(spacing: 6) {
                            ProgressView()
                                .tint(.white)
                            Text("分析中...")
                                .font(.title2.weight(.bold))
                                .foregroundColor(.white)
                        }
                    } else if let analysis = playerAnalysis {
                        Text(analysis.type)
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                    } else {
                        Text("待分析")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                Spacer()
            }

            if let analysis = playerAnalysis {
                Text(analysis.description)
                    .font(.subheadline)
                    .foregroundColor(Color.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)

                if !analysis.strengths.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("优势")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color.white.opacity(0.75))
                        ForEach(analysis.strengths, id: \.self) { strength in
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                Text(strength)
                                    .font(.caption)
                            }
                            .foregroundColor(Color.white.opacity(0.92))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("建议")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color.white.opacity(0.75))
                    Text(analysis.advice)
                        .font(.caption)
                        .foregroundColor(Color.white.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x4F46E5), Color(hex: 0x7C3AED)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.6)
        )
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "生涯总览", icon: "chart.bar.fill", showShare: true)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                StatsMetricCard(label: "总场次", value: "\(totalSessions)", icon: "calendar", color: Color(hex: 0x22C55E))
                StatsMetricCard(label: "总距离(km)", value: String(format: "%.1f", totalDistanceKm), icon: "figure.run", color: Color(hex: 0x3B82F6))
                StatsMetricCard(label: "总卡路里", value: String(format: "%.0f", totalCalories), icon: "flame.fill", color: Color(hex: 0xF97316))
                StatsMetricCard(label: "最高速度", value: String(format: "%.1f", maxSpeed), icon: "gauge.with.dots.needle.67percent", color: Color(hex: 0x06B6D4))
                StatsMetricCard(label: "场均冲刺", value: String(format: "%.0f", avgSprints), icon: "bolt.fill", color: Color(hex: 0xF59E0B))
                StatsMetricCard(label: "平均摸鱼", value: String(format: "%.0f", avgSlack), icon: "zzz", color: Color(hex: 0xA855F7))
            }
        }
        .padding(14)
        .background(AppColors.cardBg)
        .cornerRadius(16)
    }

    private var abilitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "球员能力", icon: "scope", showShare: true)
            StatsRadarView(metrics: abilityMetrics)
                .frame(height: 260)
        }
        .padding(14)
        .background(AppColors.cardBg)
        .cornerRadius(16)
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(title: "表现趋势", icon: "chart.line.uptrend.xyaxis", showShare: false)
                Spacer()
                if let delta = trendDelta {
                    HStack(spacing: 4) {
                        Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text(String(format: "%.1f", abs(delta)))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(delta >= 0 ? AppColors.speedGreen : AppColors.heartRed)
                }
            }

            StatsTrendChart(points: trendData)
                .frame(height: 170)
                .padding(10)
                .background(AppColors.cardBgLight)
                .cornerRadius(12)
        }
        .padding(14)
        .background(AppColors.cardBg)
        .cornerRadius(16)
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.neonBlue.opacity(0.16))
                    .frame(width: 26, height: 26)
                    .overlay(
                        Image(systemName: "medal.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppColors.neonBlue)
                    )

                Text("成就")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)

                Spacer()
                Text("\(unlockedCount)/\(achievementItems.count)")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 14) {
                ForEach(achievementItems) { item in
                    Button {
                        selectedAchievement = item
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(item.unlocked ? LinearGradient(colors: [item.start, item.end], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [AppColors.cardBgLight, AppColors.cardBgLight], startPoint: .top, endPoint: .bottom))
                                .frame(height: 44)
                                .overlay(
                                    Image(systemName: item.icon)
                                        .font(.title3.weight(.semibold))
                                        .foregroundColor(item.unlocked ? .white : AppColors.textSecondary.opacity(0.55))
                                )

                            Text(item.title)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(item.unlocked ? AppColors.textPrimary : AppColors.textSecondary.opacity(0.7))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, minHeight: 26, alignment: .topLeading)
                        }
                        .padding(10)
                        .background(
                            item.unlocked
                                ? LinearGradient(
                                    colors: [item.start.opacity(0.28), item.end.opacity(0.18)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [AppColors.cardBg, AppColors.cardBg],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                        )
                        .shadow(color: item.unlocked ? item.end.opacity(0.20) : Color.black.opacity(0.08), radius: item.unlocked ? 6 : 3, x: 0, y: item.unlocked ? 3 : 2)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(AppColors.cardBg)
        .cornerRadius(16)
        .alert(selectedAchievement?.title ?? "", isPresented: Binding<Bool>(
            get: { selectedAchievement != nil },
            set: { if !$0 { selectedAchievement = nil } }
        )) {
            Button("知道了", role: .cancel) { selectedAchievement = nil }
        } message: {
            if let item = selectedAchievement {
                Text(item.unlocked ? "已解锁\n\n\(item.description)" : "如何获取：\(item.description)")
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(title: "比赛记录", icon: "clock.arrow.circlepath", showShare: false)
                Spacer()
                NavigationLink(destination: AllMatchesView(sessions: sessions, store: store)) {
                    HStack(spacing: 4) {
                        Text("查看全部")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.neonBlue)
                }
                .buttonStyle(.plain)
            }

            ForEach(recentMatches, id: \.id) { session in
                NavigationLink(destination: SessionDetailView(session: session, store: store)) {
                    MatchHistoryRow(session: session)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(AppColors.cardBg)
        .cornerRadius(16)
    }

    private var emptySection: some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 20)
                .fill(AppColors.cardBg)
                .frame(width: 92, height: 92)
                .overlay(
                    Image(systemName: "applewatch")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                )

            Text("暂无统计数据")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)

            Text("连接 Apple Watch 并完成一场比赛后，这里会展示你的能力雷达和趋势变化。")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            VStack(spacing: 10) {
                EmptyPreviewCard(icon: "scope", title: "球员能力", subtitle: "分析速度、冲刺、体能和覆盖")
                EmptyPreviewCard(icon: "chart.line.uptrend.xyaxis", title: "表现趋势", subtitle: "追踪你的持续提升")
                EmptyPreviewCard(icon: "list.bullet.rectangle", title: "比赛记录", subtitle: "查看每场关键数据")
            }
            .padding(.top, 8)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(AppColors.cardBg)
        .cornerRadius(16)
    }

    private var trendDelta: Double? {
        guard trendData.count >= 2 else { return nil }
        return trendData.last!.score - trendData.first!.score
    }

    private func badgeIcon(_ iconName: String) -> String {
        switch iconName {
        case "first_match": return "sportscourt.fill"
        case "iron_man": return "figure.strengthtraining.traditional"
        case "century_legend": return "star.fill"
        case "speed_star": return "bolt.fill"
        case "marathon_runner": return "figure.run"
        case "calorie_burner": return "flame.fill"
        case "perfect_month": return "calendar.badge.checkmark"
        case "sprint_king": return "hare.fill"
        default: return "medal.fill"
        }
    }

    private func sectionHeader(title: String, icon: String, showShare: Bool) -> some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColors.neonBlue.opacity(0.16))
                .frame(width: 26, height: 26)
                .overlay(
                    Image(systemName: icon)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.neonBlue)
                )

            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            if showShare {
                Circle()
                    .fill(Color(hex: 0x07C160))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white)
                    )
            }
        }
    }

    private func performanceScore(for session: FootballSession) -> Double {
        let speed = min(1, session.maxSpeedKmh / 30)
        let sprint = min(1, Double(session.sprintCount) / 45)
        let distance = min(1, session.totalDistanceMeters / 9000)
        let discipline = max(0, 1 - Double(session.slackIndex) / 100)
        let weighted = speed * 0.3 + sprint * 0.25 + distance * 0.25 + discipline * 0.2
        return min(10, max(6, 6 + weighted * 4))
    }

    private func loadCachedAnalysis() {
        guard let data = UserDefaults.standard.data(forKey: Self.analysisCacheKey),
              let cached = try? JSONDecoder().decode(PlayerAnalysisResponse.self, from: data) else { return }
        playerAnalysis = cached
    }

    private func saveAnalysisCache(_ analysis: PlayerAnalysisResponse, sessionCount: Int) {
        if let data = try? JSONEncoder().encode(analysis) {
            UserDefaults.standard.set(data, forKey: Self.analysisCacheKey)
            UserDefaults.standard.set(sessionCount, forKey: Self.analysisCacheCountKey)
        }
    }
}

private struct StatsMetricCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.2))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: icon)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(color)
                )

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .padding(10)
        .background(AppColors.cardBgLight)
        .cornerRadius(12)
    }
}

private struct StatsAchievementItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let unlocked: Bool
    let start: Color
    let end: Color
}

private struct AbilityMetric: Identifiable {
    let id: String
    let name: String
    let value: Double

    init(name: String, value: Double) {
        self.id = name
        self.name = name
        self.value = value
    }
}

private struct StatsRadarView: View {
    let metrics: [AbilityMetric]

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = size * 0.34

            ZStack {
                ForEach(1...4, id: \.self) { level in
                    RadarPolygon(points: points(radius: radius * CGFloat(level) / 4, center: center, count: metrics.count))
                        .stroke(AppColors.dividerColor, lineWidth: 0.8)
                }

                ForEach(0..<metrics.count, id: \.self) { idx in
                    let axisPoint = pointAt(index: idx, count: metrics.count, radius: radius, center: center)
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: axisPoint)
                    }
                    .stroke(AppColors.dividerColor.opacity(0.7), lineWidth: 0.8)

                    Text(metrics[idx].name)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .position(pointAt(index: idx, count: metrics.count, radius: radius + 18, center: center))
                }

                RadarPolygon(points: valuePoints(radius: radius, center: center))
                    .fill(AppColors.neonBlue.opacity(0.22))

                RadarPolygon(points: valuePoints(radius: radius, center: center))
                    .stroke(AppColors.neonBlue, lineWidth: 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func valuePoints(radius: CGFloat, center: CGPoint) -> [CGPoint] {
        metrics.enumerated().map { idx, metric in
            pointAt(index: idx, count: metrics.count, radius: radius * CGFloat(metric.value / 100), center: center)
        }
    }

    private func points(radius: CGFloat, center: CGPoint, count: Int) -> [CGPoint] {
        (0..<count).map { idx in
            pointAt(index: idx, count: count, radius: radius, center: center)
        }
    }

    private func pointAt(index: Int, count: Int, radius: CGFloat, center: CGPoint) -> CGPoint {
        let angle = -Double.pi / 2 + Double(index) * 2 * Double.pi / Double(max(count, 1))
        return CGPoint(
            x: center.x + CGFloat(cos(angle)) * radius,
            y: center.y + CGFloat(sin(angle)) * radius
        )
    }
}

private struct RadarPolygon: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

private struct TrendPoint: Identifiable {
    let id: Int
    let index: Int
    let score: Double

    init(index: Int, score: Double) {
        self.id = index
        self.index = index
        self.score = score
    }
}

private struct StatsTrendChart: View {
    let points: [TrendPoint]

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            let minY = 6.0
            let maxY = 10.0

            ZStack {
                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { idx in
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: h / 4)
                            .overlay(alignment: .top) {
                                Divider().overlay(AppColors.dividerColor.opacity(0.5))
                            }
                    }
                }

                Path { path in
                    guard !points.isEmpty else { return }
                    for (idx, point) in points.enumerated() {
                        let x = xPosition(for: idx, total: points.count, width: w)
                        let y = yPosition(value: point.score, minY: minY, maxY: maxY, height: h)
                        if idx == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(AppColors.neonBlue, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                ForEach(Array(points.enumerated()), id: \.element.id) { idx, point in
                    Circle()
                        .fill(AppColors.neonBlue)
                        .frame(width: 8, height: 8)
                        .position(
                            x: xPosition(for: idx, total: points.count, width: w),
                            y: yPosition(value: point.score, minY: minY, maxY: maxY, height: h)
                        )
                }
            }
        }
    }

    private func xPosition(for index: Int, total: Int, width: CGFloat) -> CGFloat {
        guard total > 1 else { return width / 2 }
        let step = width / CGFloat(total - 1)
        return CGFloat(index) * step
    }

    private func yPosition(value: Double, minY: Double, maxY: Double, height: CGFloat) -> CGFloat {
        let normalized = (value - minY) / (maxY - minY)
        return height * CGFloat(1 - normalized)
    }
}

struct MatchHistoryRow: View {
    let session: FootballSession

    private var resultTag: String {
        let name = session.locationName.isEmpty ? "球场训练" : session.locationName
        let first = name.first ?? "F"
        // Convert Chinese character to its pinyin initial
        let mutable = NSMutableString(string: String(first))
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        let initial = (mutable as String).first?.uppercased() ?? "F"
        return initial
    }

    private var resultColor: Color {
        session.slackIndex < 45 ? AppColors.speedGreen : AppColors.heartRed
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: session.startTime)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Circle()
                    .fill(Color(hex: 0x3B82F6).opacity(0.2))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text(resultTag)
                            .font(.caption.weight(.bold))
                            .foregroundColor(Color(hex: 0x3B82F6))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.locationName.isEmpty ? "球场训练" : session.locationName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.textPrimary)

                    Text("\(dateText) • \(String(format: "%.1fkm", session.totalDistanceMeters / 1000))")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Text(String(format: "%.1f", score))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.neonBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColors.neonBlue.opacity(0.14))
                    .cornerRadius(10)
            }

            HStack(spacing: 8) {
                miniItem(title: "冲刺", value: "\(session.sprintCount)")
                miniItem(title: "最高速", value: String(format: "%.1f", session.maxSpeedKmh))
                miniItem(title: "摸鱼", value: "\(session.slackIndex)")
            }
        }
        .padding(12)
        .background(AppColors.cardBgLight)
        .cornerRadius(12)
    }

    private var score: Double {
        let speed = min(1, session.maxSpeedKmh / 30)
        let sprint = min(1, Double(session.sprintCount) / 45)
        let distance = min(1, session.totalDistanceMeters / 9000)
        let discipline = max(0, 1 - Double(session.slackIndex) / 100)
        let weighted = speed * 0.3 + sprint * 0.25 + distance * 0.25 + discipline * 0.2
        return min(10, max(6, 6 + weighted * 4))
    }

    private func miniItem(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundColor(AppColors.textPrimary)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(AppColors.cardBg)
        .cornerRadius(8)
    }
}

private struct EmptyPreviewCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.neonBlue.opacity(0.16))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.neonBlue)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(10)
        .background(AppColors.cardBgLight)
        .cornerRadius(10)
    }
}

struct AllMatchesView: View {
    let sessions: [FootballSession]
    @ObservedObject var store: SessionStore

    @State private var sessionToDelete: FootballSession?
    @State private var showLocalDeleteAlert = false
    @State private var showCloudDeleteAlert = false
    @State private var selectedSession: FootballSession?
    @State private var navigateToDetail = false
    @State private var expandedDays: Set<String> = []
    @State private var initializedExpansion = false

    private struct DaySection: Identifiable {
        let id: String           // "2026-03-22"
        let displayDate: String  // "3月22日 周六"
        let sessions: [FootballSession]

        var totalDistance: Double {
            sessions.reduce(0) { $0 + $1.totalDistanceMeters }
        }
        var totalMinutes: Int {
            sessions.reduce(0) { total, s in
                total + Int(s.endTime.timeIntervalSince(s.startTime) / 60)
            }
        }
        var totalSprints: Int {
            sessions.reduce(0) { $0 + $1.sprintCount }
        }
        var maxSpeed: Double {
            sessions.map(\.maxSpeedKmh).max() ?? 0
        }
        var sessionCount: Int { sessions.count }
    }

    private var daySections: [DaySection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { session in
            calendar.startOfDay(for: session.startTime)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEE"

        return grouped.map { (day, sessions) in
            let sortedSessions = sessions.sorted { $0.startTime > $1.startTime }
            let isoFormatter = DateFormatter()
            isoFormatter.dateFormat = "yyyy-MM-dd"
            let dayId = isoFormatter.string(from: day)
            return DaySection(
                id: dayId,
                displayDate: formatter.string(from: day),
                sessions: sortedSessions
            )
        }
        .sorted { $0.id > $1.id }
    }

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            List {
                ForEach(daySections) { section in
                    Section {
                        // Summary bar
                        daySummaryBar(section: section)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 4, trailing: 16))
                            .listRowSeparator(.hidden)

                        // Expanded sessions
                        if expandedDays.contains(section.id) {
                            ForEach(section.sessions, id: \.id) { session in
                                MatchHistoryRow(session: session)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedSession = session
                                        navigateToDetail = true
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            sessionToDelete = session
                                            if session.syncedToCloud {
                                                showCloudDeleteAlert = true
                                            } else {
                                                showLocalDeleteAlert = true
                                            }
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                                    .listRowSeparator(.hidden)
                            }
                        }
                    } header: {
                        dayHeader(section: section)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .onAppear {
            if !initializedExpansion {
                expandedDays = Set(daySections.map(\.id))
                initializedExpansion = true
            }
        }
        .navigationTitle("全部比赛")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToDetail) {
            if let session = selectedSession {
                SessionDetailView(session: session, store: store)
            }
        }
        .alert("确认删除", isPresented: $showLocalDeleteAlert) {
            Button("取消", role: .cancel) { sessionToDelete = nil }
            Button("删除", role: .destructive) { deleteLocalOnly() }
        } message: {
            Text("该记录未同步到云端，删除后将无法恢复。")
        }
        .alert("确认删除", isPresented: $showCloudDeleteAlert) {
            Button("取消", role: .cancel) { sessionToDelete = nil }
            Button("仅删除本地", role: .destructive) { deleteLocalOnly() }
            Button("同时删除云端", role: .destructive) { deleteWithCloud() }
        } message: {
            Text("该记录已同步到云端，是否同时删除云端数据？")
        }
    }

    @ViewBuilder
    private func dayHeader(section: DaySection) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                if expandedDays.contains(section.id) {
                    expandedDays.remove(section.id)
                } else {
                    expandedDays.insert(section.id)
                }
            }
        } label: {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(AppColors.neonBlue)
                    .font(.system(size: 14))
                Text(section.displayDate)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text("\(section.sessionCount)场")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textSecondary)
                Image(systemName: expandedDays.contains(section.id) ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func daySummaryBar(section: DaySection) -> some View {
        HStack(spacing: 0) {
            summaryItem(
                title: "总距离",
                value: String(format: "%.1f", section.totalDistance / 1000),
                unit: "km",
                color: AppColors.neonBlue
            )
            Spacer()
            summaryItem(
                title: "总时长",
                value: "\(section.totalMinutes)",
                unit: "min",
                color: AppColors.calorieOrange
            )
            Spacer()
            summaryItem(
                title: "总冲刺",
                value: "\(section.totalSprints)",
                unit: "次",
                color: AppColors.heartRed
            )
            Spacer()
            summaryItem(
                title: "最高速",
                value: String(format: "%.1f", section.maxSpeed),
                unit: "km/h",
                color: AppColors.speedGreen
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppColors.cardBg.opacity(0.6))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func summaryItem(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(AppColors.textSecondary)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(unit)
                .font(.system(size: 10))
                .foregroundColor(AppColors.textSecondary)
        }
    }

    private func deleteLocalOnly() {
        guard let session = sessionToDelete else { return }
        store.deleteSession(session)
        sessionToDelete = nil
    }

    private func deleteWithCloud() {
        guard let session = sessionToDelete else { return }
        let sessionId = session.id
        store.deleteSession(session)
        sessionToDelete = nil

        Task {
            _ = try? await ApiClient.shared.deleteSession(id: sessionId)
        }
    }
}
