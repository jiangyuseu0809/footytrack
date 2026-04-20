import SwiftUI
import Charts

/// Weekly summary page showing aggregated stats, trends, comparisons, highlights, and radar chart.
struct WeeklySummaryView: View {
    @ObservedObject var store: SessionStore
    @State private var selectedTrend: TrendTab = .distance
    /// 0 = real data, 2 = mock 2 weeks, 5 = mock 5 weeks
    @State private var previewWeekCount: Int = 0

    // MARK: - Week Sessions

    private var thisWeekSessions: [FootballSession] {
        let cal = Calendar.current
        let nowComps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return store.sessions.filter { session in
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: session.startTime)
            return comps.yearForWeekOfYear == nowComps.yearForWeekOfYear
                && comps.weekOfYear == nowComps.weekOfYear
        }.sorted { $0.startTime < $1.startTime }
    }

    private var lastWeekSessions: [FootballSession] {
        let cal = Calendar.current
        guard let lastWeekDate = cal.date(byAdding: .weekOfYear, value: -1, to: Date()) else { return [] }
        let lwComps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: lastWeekDate)
        return store.sessions.filter { session in
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: session.startTime)
            return comps.yearForWeekOfYear == lwComps.yearForWeekOfYear
                && comps.weekOfYear == lwComps.weekOfYear
        }
    }

    // MARK: - Summary Stats

    private var weekMatchCount: Int { thisWeekSessions.count }

    private var weekTotalDistanceKm: Double {
        thisWeekSessions.reduce(0.0) { $0 + $1.totalDistanceMeters } / 1000.0
    }

    private var weekTotalCalories: Double {
        thisWeekSessions.reduce(0.0) { $0 + $1.caloriesBurned }
    }

    private var weekTotalMinutes: Int {
        thisWeekSessions.reduce(0) { result, session in
            result + Int(session.endTime.timeIntervalSince(session.startTime) / 60)
        }
    }

    // MARK: - Last Week Stats

    private var lastWeekMatchCount: Int { lastWeekSessions.count }

    private var lastWeekTotalDistanceKm: Double {
        lastWeekSessions.reduce(0.0) { $0 + $1.totalDistanceMeters } / 1000.0
    }

    private var lastWeekTotalCalories: Double {
        lastWeekSessions.reduce(0.0) { $0 + $1.caloriesBurned }
    }

    private var lastWeekAvgSlack: Double {
        guard !lastWeekSessions.isEmpty else { return 0 }
        return Double(lastWeekSessions.reduce(0) { $0 + $1.slackIndex }) / Double(lastWeekSessions.count)
    }

    private var thisWeekAvgSlack: Double {
        guard !thisWeekSessions.isEmpty else { return 0 }
        return Double(thisWeekSessions.reduce(0) { $0 + $1.slackIndex }) / Double(thisWeekSessions.count)
    }

    // MARK: - Date Range

    private var weekDateRangeStr: String {
        let cal = Calendar.current
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: Date())?.start else { return "" }
        let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart)!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
    }

    // MARK: - Best & Worst

    private var bestMatch: FootballSession? {
        thisWeekSessions.max(by: { $0.totalDistanceMeters < $1.totalDistanceMeters })
    }

    private var worstMatch: FootballSession? {
        thisWeekSessions.max(by: { $0.slackIndex < $1.slackIndex })
    }

    // MARK: - Radar

    private var radarAxes: [(label: String, value: Double)] {
        guard !thisWeekSessions.isEmpty else {
            return [("速度", 0), ("爆发", 0), ("耐力", 0), ("强度", 0), ("专注", 0)]
        }

        let avgMaxSpeed = thisWeekSessions.reduce(0.0) { $0 + $1.maxSpeedKmh } / Double(thisWeekSessions.count)
        let avgSprints = Double(thisWeekSessions.reduce(0) { $0 + $1.sprintCount }) / Double(thisWeekSessions.count)
        let avgDuration = Double(weekTotalMinutes) / Double(thisWeekSessions.count)
        let avgDistance = weekTotalDistanceKm / Double(thisWeekSessions.count)
        let avgSlack = thisWeekAvgSlack

        // Normalize to 0-1 scale
        let speedScore = min(avgMaxSpeed / 35.0, 1.0)
        let burstScore = min(avgSprints / 50.0, 1.0)
        let staminaScore = min(avgDuration / 120.0, 1.0)
        let intensityScore = min(avgDistance / 12.0, 1.0)
        let focusScore = max(1.0 - avgSlack / 100.0, 0)

        return [
            ("速度", speedScore),
            ("爆发", burstScore),
            ("耐力", staminaScore),
            ("强度", intensityScore),
            ("专注", focusScore),
        ]
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Date range
                    HStack {
                        Text(weekDateRangeStr)
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                    }

                    // DEBUG: Preview mock data picker
                    HStack(spacing: 8) {
                        Text("趋势预览")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                        ForEach([0, 2, 5], id: \.self) { count in
                            Button {
                                withAnimation { previewWeekCount = count }
                            } label: {
                                Text(count == 0 ? "真实" : "\(count)周")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(previewWeekCount == count ? .white : AppColors.textSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(previewWeekCount == count ? Color(hex: 0x3B82F6) : AppColors.cardBgLight)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }

                    // Week Summary Cards
                    weekSummarySection

                    // Trend Chart
                    trendChartSection

                    // Week Comparison
                    weekComparisonSection

                    // Best & Worst
                    highlightsSection

                    // Radar Chart
                    radarSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("本周总结")
        .navigationBarTitleDisplayMode(.inline)
        .hideTabBar()
    }

    // MARK: - Week Summary Cards (2x2)

    private var weekSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("周度总览")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                summaryCard(
                    icon: "calendar",
                    label: "比赛场次",
                    value: "\(weekMatchCount)",
                    unit: "场",
                    gradient: [Color(hex: 0x3B82F6), Color(hex: 0x06B6D4)]
                )
                summaryCard(
                    icon: "figure.run",
                    label: "总距离",
                    value: String(format: "%.1f", weekTotalDistanceKm),
                    unit: "km",
                    gradient: [Color(hex: 0xA855F7), Color(hex: 0xEC4899)]
                )
                summaryCard(
                    icon: "flame.fill",
                    label: "总热量",
                    value: "\(Int(weekTotalCalories))",
                    unit: "kcal",
                    gradient: [Color(hex: 0xEF4444), Color(hex: 0xF97316)]
                )
                summaryCard(
                    icon: "clock.fill",
                    label: "总时长",
                    value: "\(weekTotalMinutes)",
                    unit: "min",
                    gradient: [Color(hex: 0x10B981), Color(hex: 0x34D399)]
                )
            }
        }
    }

    private func summaryCard(icon: String, label: String, value: String, unit: String, gradient: [Color]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                )

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(AppColors.textSecondary)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                Text(unit)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppColors.cardBg)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    // MARK: - Trend Chart (per-week)

    private enum TrendTab: String, CaseIterable {
        case distance = "总距离"
        case calories = "总卡路里"
        case duration = "总时间"
        case sprints = "总冲刺"
    }

    private struct TrendDataPoint: Identifiable {
        let id = UUID()
        let index: Int
        let value: Double
    }

    /// Group all sessions by week and return up to the last 8 weeks of data.
    private var weeklyTrendData: [TrendDataPoint] {
        // Mock data for preview
        if previewWeekCount > 0 {
            return mockTrendData(weeks: previewWeekCount)
        }

        let cal = Calendar.current
        let now = Date()

        var results: [TrendDataPoint] = []
        var idx = 0

        for weeksAgo in stride(from: 7, through: 0, by: -1) {
            guard let weekDate = cal.date(byAdding: .weekOfYear, value: -weeksAgo, to: now),
                  let weekInterval = cal.dateInterval(of: .weekOfYear, for: weekDate) else { continue }

            let weekSessions = store.sessions.filter {
                $0.startTime >= weekInterval.start && $0.startTime < weekInterval.end
            }

            guard !weekSessions.isEmpty else { continue }

            let value: Double
            switch selectedTrend {
            case .distance:
                value = weekSessions.reduce(0.0) { $0 + $1.totalDistanceMeters } / 1000.0
            case .calories:
                value = weekSessions.reduce(0.0) { $0 + $1.caloriesBurned }
            case .duration:
                value = Double(weekSessions.reduce(0) { result, s in
                    result + Int(s.endTime.timeIntervalSince(s.startTime) / 60)
                })
            case .sprints:
                value = Double(weekSessions.reduce(0) { $0 + $1.sprintCount })
            }
            results.append(TrendDataPoint(index: idx, value: value))
            idx += 1
        }
        return results
    }

    private func mockTrendData(weeks: Int) -> [TrendDataPoint] {
        let mockValues: [TrendTab: [[Double]]] = [
            .distance: [
                [32.5, 41.2],
                [28.3, 35.6, 42.1, 38.9, 45.2],
            ],
            .calories: [
                [4200, 5800],
                [3800, 4500, 5200, 4900, 6100],
            ],
            .duration: [
                [280, 390],
                [240, 310, 360, 330, 420],
            ],
            .sprints: [
                [85, 120],
                [72, 95, 110, 88, 130],
            ],
        ]

        let idx = weeks == 2 ? 0 : 1
        let values = mockValues[selectedTrend]![idx]
        return values.enumerated().map { TrendDataPoint(index: $0.offset, value: $0.element) }
    }

    private var trendUnit: String {
        switch selectedTrend {
        case .distance: return "km"
        case .calories: return "kcal"
        case .duration: return "min"
        case .sprints: return "次"
        }
    }

    private var trendColor: Color {
        switch selectedTrend {
        case .distance: return Color(hex: 0x8B5CF6)
        case .calories: return Color(hex: 0xEF4444)
        case .duration: return Color(hex: 0x10B981)
        case .sprints: return Color(hex: 0xF59E0B)
        }
    }

    private var trendChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("周趋势变化")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

            VStack(spacing: 14) {
                // Tab buttons
                HStack(spacing: 0) {
                    ForEach(TrendTab.allCases, id: \.self) { tab in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTrend = tab
                            }
                        } label: {
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(selectedTrend == tab ? AppColors.textPrimary : AppColors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    selectedTrend == tab
                                    ? AppColors.cardBgLight
                                    : Color.clear
                                )
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Color.white.opacity(0.06))
                .cornerRadius(10)

                // Chart
                if weeklyTrendData.isEmpty {
                    Text("暂无周数据")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    trendChartContent
                }
            }
            .padding(16)
            .background(AppColors.cardBg)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
    }

    /// Compute nice Y-axis tick values that always include 0 and a rounded upper bound ≥ maxValue.
    private func niceYTicks(maxValue: Double, defaultUpper: Double, tickCount: Int = 5) -> [Double] {
        let raw = maxValue > 0 ? maxValue : defaultUpper
        // Round up to a "nice" step (1, 2, 5, 10, 20, 50, …)
        let roughStep = raw / Double(tickCount - 1)
        let mag = pow(10, floor(log10(max(roughStep, 1e-9))))
        let residual = roughStep / mag
        let niceStep: Double
        if residual <= 1.0 { niceStep = 1.0 * mag }
        else if residual <= 2.0 { niceStep = 2.0 * mag }
        else if residual <= 5.0 { niceStep = 5.0 * mag }
        else { niceStep = 10.0 * mag }

        let upper = niceStep * ceil(raw / niceStep)
        var ticks: [Double] = []
        var v = 0.0
        while v <= upper + niceStep * 0.01 {
            ticks.append(v)
            v += niceStep
        }
        return ticks
    }

    private var trendChartContent: some View {
        let data = weeklyTrendData
        let maxIndex = max(data.last?.index ?? 0, 1)
        let unit = trendUnit
        let color = trendColor
        let gradient = LinearGradient(
            colors: [color.opacity(0.3), color.opacity(0.01)],
            startPoint: .top,
            endPoint: .bottom
        )

        let maxValue = data.map(\.value).max() ?? 0
        let defaultUpper: Double = {
            switch selectedTrend {
            case .distance: return 10.0
            case .calories: return 1000.0
            case .duration: return 60.0
            case .sprints: return 20.0
            }
        }()
        let ticks = niceYTicks(maxValue: maxValue, defaultUpper: defaultUpper)
        let yUpperBound = ticks.last ?? defaultUpper

        return HStack(alignment: .top, spacing: 4) {
            Chart(data) { point in
                AreaMark(
                    x: .value("Index", point.index),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(gradient)
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Index", point.index),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Index", point.index),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(color)
                .symbolSize(30)
            }
            .chartXScale(domain: 0...maxIndex)
            .chartYScale(domain: 0...yUpperBound)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(values: ticks) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        .foregroundStyle(Color.white.opacity(0.1))
                }
            }
            .frame(height: 200)

            // Right-side Y-axis labels
            VStack(spacing: 0) {
                ForEach(ticks.reversed(), id: \.self) { tick in
                    if tick == ticks.last {
                        tickLabel(tick, unit: unit)
                    } else {
                        Spacer(minLength: 0)
                        tickLabel(tick, unit: unit)
                    }
                }
            }
            .frame(height: 200)
            .frame(width: 36)
        }
    }

    private func tickLabel(_ value: Double, unit: String) -> some View {
        let text: String
        if value == 0 {
            text = "0" + unit
        } else if value == floor(value) {
            text = String(format: "%.0f", value)
        } else {
            text = String(format: "%g", value)
        }
        return Text(text)
            .font(.system(size: 10))
            .foregroundColor(AppColors.textSecondary)
            .lineLimit(1)
            .fixedSize()
    }

    // MARK: - Week Comparison

    private var weekComparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("周对比")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

            VStack(spacing: 16) {
                comparisonRow(
                    label: "比赛场次",
                    thisWeek: Double(weekMatchCount),
                    lastWeek: Double(lastWeekMatchCount),
                    unit: "",
                    lowerIsBetter: false
                )
                comparisonRow(
                    label: "总距离",
                    thisWeek: weekTotalDistanceKm,
                    lastWeek: lastWeekTotalDistanceKm,
                    unit: "km",
                    lowerIsBetter: false
                )
                comparisonRow(
                    label: "总热量",
                    thisWeek: weekTotalCalories,
                    lastWeek: lastWeekTotalCalories,
                    unit: "kcal",
                    lowerIsBetter: false
                )
                comparisonRow(
                    label: "平均摸鱼",
                    thisWeek: thisWeekAvgSlack,
                    lastWeek: lastWeekAvgSlack,
                    unit: "%",
                    lowerIsBetter: true
                )
            }
            .padding(16)
            .background(AppColors.cardBg)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
    }

    private func comparisonRow(label: String, thisWeek: Double, lastWeek: Double, unit: String, lowerIsBetter: Bool) -> some View {
        let percentage: Double = lastWeek != 0 ? ((thisWeek - lastWeek) / lastWeek) * 100 : 0
        let isPositive = lowerIsBetter ? (percentage <= 0) : (percentage >= 0)
        let maxVal = max(thisWeek, lastWeek, 1)

        return VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                HStack(spacing: 6) {
                    Text(formatComparisonValue(thisWeek, unit: unit))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    if lastWeek != 0 {
                        HStack(spacing: 2) {
                            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 9, weight: .bold))
                            Text(String(format: "%.1f%%", abs(percentage)))
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(isPositive ? Color(hex: 0x22C55E) : Color(hex: 0xEF4444))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            (isPositive ? Color(hex: 0x22C55E) : Color(hex: 0xEF4444))
                                .opacity(0.15)
                        )
                        .cornerRadius(8)
                    }
                }
            }

            // Progress bars: last week + this week
            HStack(spacing: 4) {
                // Last week bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.06))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: 0x6B7280))
                            .frame(width: max(0, geo.size.width * CGFloat(lastWeek / maxVal)))
                    }
                }
                .frame(height: 6)

                // This week bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.06))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isPositive ? Color(hex: 0x22C55E) : Color(hex: 0xEF4444))
                            .frame(width: max(0, geo.size.width * CGFloat(thisWeek / maxVal)))
                    }
                }
                .frame(height: 6)
            }

            HStack {
                Text("上周: \(formatComparisonValue(lastWeek, unit: unit))")
                    .font(.system(size: 10))
                    .foregroundColor(Color.white.opacity(0.35))
                Spacer()
                Text("本周: \(formatComparisonValue(thisWeek, unit: unit))")
                    .font(.system(size: 10))
                    .foregroundColor(Color.white.opacity(0.35))
            }
        }
    }

    private func formatComparisonValue(_ val: Double, unit: String) -> String {
        if val == floor(val) && val < 10000 {
            return "\(Int(val))\(unit)"
        }
        return String(format: "%.1f\(unit)", val)
    }

    // MARK: - Highlights (Best & Worst)

    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本周亮点")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

            if let best = bestMatch {
                NavigationLink(destination: SessionDetailView(session: best, store: store)) {
                    highlightCard(
                        session: best,
                        badge: "最远距离",
                        icon: "trophy.fill",
                        gradientColors: [Color(hex: 0x166534).opacity(0.5), Color(hex: 0x14532D).opacity(0.3)],
                        borderColor: Color(hex: 0x166534),
                        badgeColor: Color(hex: 0x22C55E)
                    )
                }
                .buttonStyle(.plain)
            }

            if let worst = worstMatch, worst.id != bestMatch?.id {
                NavigationLink(destination: SessionDetailView(session: worst, store: store)) {
                    highlightCard(
                        session: worst,
                        badge: "待提升",
                        icon: "exclamationmark.triangle.fill",
                        gradientColors: [Color(hex: 0x7C2D12).opacity(0.3), Color(hex: 0x713F12).opacity(0.2)],
                        borderColor: Color(hex: 0x7C2D12),
                        badgeColor: Color(hex: 0xF97316)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func highlightCard(session: FootballSession, badge: String, icon: String, gradientColors: [Color], borderColor: Color, badgeColor: Color) -> some View {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "zh_CN")
        dateFormatter.dateFormat = "M月d日 EEEE"
        let dateStr = dateFormatter.string(from: session.startTime)
        let distKm = session.totalDistanceMeters / 1000.0

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(colors: [badgeColor, badgeColor.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(badge)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(badgeColor)
                        Text(session.locationName.isEmpty ? "球场训练" : session.locationName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
                Spacer()
                Text(dateStr)
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textSecondary)
            }

            HStack(spacing: 8) {
                highlightStat(label: "距离", value: String(format: "%.1f km", distKm))
                highlightStat(label: "摸鱼指数", value: "\(session.slackIndex)%")
            }
        }
        .padding(14)
        .background(
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor.opacity(0.5), lineWidth: 0.5)
        )
    }

    private func highlightStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(AppColors.textSecondary)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.06))
        .cornerRadius(10)
    }

    // MARK: - Radar Chart

    private var radarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("周均表现")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

            VStack {
                RadarChartView(axes: radarAxes, size: 240)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .padding(16)
            .background(AppColors.cardBg)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
    }
}
