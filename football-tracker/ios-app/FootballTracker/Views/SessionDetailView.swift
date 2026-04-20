import SwiftUI
import MapKit
import CoreLocation

/// Detailed view of a single football session with all stats, charts, and heatmap.
struct SessionDetailView: View {
    let session: FootballSession
    @ObservedObject var store: SessionStore

    @State private var cachedTrackPoints: [TrackPointRecord] = []
    @State private var cachedContinuousPoints: [TrackPointRecord] = []
    @State private var cachedStats: SessionAnalysisResult?

    @State private var cachedLatRange: (min: Double, max: Double)?
    @State private var cachedLonRange: (min: Double, max: Double)?
    @State private var showShareSheet = false
    @State private var posterImage: UIImage?
    @State private var isGeneratingPoster = false
    @State private var showLocationEditor = false
    @State private var showAttackEnd = true
    @State private var sessionSummary: String?
    @State private var isLoadingSummary = false
    @State private var isSummaryExpanded = false

    private var trackPoints: [TrackPointRecord] {
        cachedTrackPoints
    }

    private var stats: SessionAnalysisResult {
        cachedStats ?? store.computeStats(from: trackPoints)
    }

    private var dateStr: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 EEEE"
        return formatter.string(from: session.startTime)
    }

    private var timeRangeStr: String {
        let start = DateFormatter()
        start.dateFormat = "HH:mm"
        let end = DateFormatter()
        end.dateFormat = "HH:mm"
        return "\(start.string(from: session.startTime)) - \(end.string(from: session.endTime))"
    }

    private var durationMin: Int {
        Int(session.endTime.timeIntervalSince(session.startTime) / 60)
    }

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 16) {
                    // Venue & Time Card
                    venueTimeCard

                    // Key Stats Grid
                    keyStatsSection

                    // Halves Breakdown
                    halvesSection

                    // Speed Chart
                    if !cachedContinuousPoints.isEmpty {
                        chartSection(title: "速度", icon: "bolt.fill", iconColor: Color(hex: 0x3B82F6)) {
                            SpeedChartView(points: cachedContinuousPoints, showHeartRate: false)
                        }
                    }

                    // Heart Rate Chart
                    chartSection(title: "心率", icon: "heart.fill", iconColor: Color(hex: 0xEF4444)) {
                        SpeedChartView(
                            points: cachedContinuousPoints.isEmpty ? trackPoints : cachedContinuousPoints,
                            showHeartRate: true
                        )
                    }

                    // Fatigue Chart
                    if !stats.fatigueSegments.isEmpty {
                        chartSection(title: "体力曲线", icon: "flame.fill", iconColor: Color(hex: 0xF59E0B)) {
                            FatigueChartView(segments: stats.fatigueSegments)
                        }
                    }

                    // Radar Chart
                    chartSection(title: "能力雷达", icon: "pentagon.fill", iconColor: Color(hex: 0xA855F7)) {
                        RadarChartView(axes: radarAxes, size: 240)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }

                    // Heatmap
                    if let latRange = cachedLatRange, let lonRange = cachedLonRange {
                        chartSection(title: "活动热图", icon: "map.fill", iconColor: Color(hex: 0x10B981), trailing: {
                            HStack(spacing: 6) {
                                Text("进攻方向")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.textSecondary)
                                Button {
                                    showAttackEnd.toggle()
                                } label: {
                                    Image(systemName: "arrow.left.arrow.right")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(6)
                                        .background(Color.white.opacity(0.10))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }) {
                            HeatmapOverlayView(
                                grid: showAttackEnd ? stats.heatmapGrid : flipGridHorizontally(stats.heatmapGrid),
                                minLat: latRange.min,
                                maxLat: latRange.max,
                                minLon: lonRange.min,
                                maxLon: lonRange.max,
                                attackEndToggle: $showAttackEnd
                            )
                        }
                    }

                    // Match Summary (AI)
                    matchSummarySection
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("比赛详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isGeneratingPoster = true
                    posterImage = nil
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            SessionShareSheetWrapper(
                session: session,
                stats: stats,
                trackPoints: trackPoints,
                posterImage: $posterImage,
                isGenerating: $isGeneratingPoster,
                onDismiss: { showShareSheet = false }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
            .presentationBackground(Color(hex: 0x1C2333))
        }
        .sheet(isPresented: $showLocationEditor) {
            LocationEditorView(session: session, store: store, trackPoints: cachedTrackPoints)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(hex: 0x1C2333))
        }
        .task(id: session.id) {
            let points = store.getTrackPoints(for: session)
            let computedStats = store.computeStats(from: points)
            cachedTrackPoints = points
            cachedStats = computedStats
            cachedContinuousPoints = buildContinuousPoints(points: points)
            if let minLat = points.map(\.latitude).min(),
               let maxLat = points.map(\.latitude).max(),
               let minLon = points.map(\.longitude).min(),
               let maxLon = points.map(\.longitude).max() {
                cachedLatRange = (min: minLat, max: maxLat)
                cachedLonRange = (min: minLon, max: maxLon)
            } else {
                cachedLatRange = nil
                cachedLonRange = nil
            }
            Self.markAsRead(sessionId: session.id)

            // Load session summary from cache or fetch
            let cacheKey = "session_summary_\(session.id)"
            if let cached = UserDefaults.standard.string(forKey: cacheKey) {
                sessionSummary = cached
            } else {
                isLoadingSummary = true
                do {
                    let result = try await ApiClient.shared.getSessionSummary(sessionId: session.id)
                    sessionSummary = result.summary
                    UserDefaults.standard.set(result.summary, forKey: cacheKey)
                } catch {
                    // Leave nil on failure
                }
                isLoadingSummary = false
            }
        }
    }

    static func markAsRead(sessionId: String) {
        let ud = UserDefaults.standard
        var unreadIds = ud.stringArray(forKey: "unread_session_ids") ?? []
        guard unreadIds.contains(sessionId) else { return }
        unreadIds.removeAll { $0 == sessionId }
        ud.set(unreadIds, forKey: "unread_session_ids")
        ud.set(unreadIds.count, forKey: "unread_session_count")

        var readIds = ud.stringArray(forKey: "read_session_ids") ?? []
        if !readIds.contains(sessionId) {
            readIds.append(sessionId)
        }
        ud.set(readIds, forKey: "read_session_ids")

        NotificationCenter.default.post(name: .sessionRecorded, object: nil)
    }

    // MARK: - Match Summary

    private var matchSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [Color(hex: 0x4F46E5), Color(hex: 0x7C3AED)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("比赛总结")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("根据本场比赛数据由AI分析总结")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
            }

            if isLoadingSummary {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(AppColors.textSecondary)
                    Text("AI 分析中...")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.top, 4)
            } else if let summary = sessionSummary {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isSummaryExpanded.toggle()
                    }
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Text(summary)
                            .font(.subheadline)
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(isSummaryExpanded ? nil : 3)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Image(systemName: isSummaryExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.top, 2)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Text("暂无分析结果")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.top, 4)
            }
        }
        .padding(14)
        .background(AppColors.cardBg)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    // MARK: - Venue & Time Card

    private var venueTimeCard: some View {
        VStack(spacing: 12) {
            // Venue (tappable to edit)
            Button {
                showLocationEditor = true
            } label: {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [Color(hex: 0xA855F7), Color(hex: 0xEC4899)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("场地")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.textSecondary)
                        Text(session.locationName.isEmpty ? "球场训练" : session.locationName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .buttonStyle(.plain)

            // Time
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [Color(hex: 0x3B82F6), Color(hex: 0x06B6D4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "clock.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("时间")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
                    Text("\(dateStr) • \(timeRangeStr)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                }
                Spacer()
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

    // MARK: - Key Stats

    private var keyStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("核心数据")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

            VStack(spacing: 8) {
                // Row 1: Goals + Assists (2 columns)
                HStack(spacing: 8) {
                    keyStatCard(icon: "soccerball", label: "进球", value: "\(session.goals)", unit: "", color: Color(hex: 0x10B981))
                    keyStatCard(icon: "hand.point.up.fill", label: "助攻", value: "\(session.assists)", unit: "", color: Color(hex: 0x3B82F6))
                }

                // Row 2: Duration + Distance + Calories (3 columns)
                HStack(spacing: 8) {
                    keyStatCard(icon: "clock.fill", label: "时长", value: "\(durationMin)", unit: "min", color: Color(hex: 0x3B82F6))
                    keyStatCard(icon: "location.fill", label: "距离", value: String(format: "%.1f", session.totalDistanceMeters / 1000), unit: "km", color: Color(hex: 0xA855F7))
                    keyStatCard(icon: "flame.fill", label: "卡路里", value: "\(Int(session.caloriesBurned))", unit: "kcal", color: Color(hex: 0xEF4444))
                }

                // Row 3: Sprints + Max speed + Avg speed (3 columns)
                HStack(spacing: 8) {
                    keyStatCard(icon: "bolt.fill", label: "冲刺", value: "\(session.sprintCount)", unit: "次", color: Color(hex: 0xF59E0B))
                    keyStatCard(icon: "speedometer", label: "最高速度", value: String(format: "%.1f", session.maxSpeedKmh), unit: "km/h", color: Color(hex: 0xEF4444))
                    keyStatCard(icon: "gauge.with.dots.needle.33percent", label: "均速", value: String(format: "%.1f", session.avgSpeedKmh), unit: "km/h", color: Color(hex: 0x10B981))
                }

                // Row 4: Avg HR + Max HR + Coverage (3 columns)
                HStack(spacing: 8) {
                    keyStatCard(icon: "heart.fill", label: "均心率", value: "\(session.avgHeartRate > 0 ? session.avgHeartRate : stats.avgHeartRate)", unit: "bpm", color: Color(hex: 0xEF4444))
                    keyStatCard(icon: "heart.circle.fill", label: "最高心率", value: "\(session.maxHeartRate > 0 ? session.maxHeartRate : stats.maxHeartRate)", unit: "bpm", color: Color(hex: 0xDC2626))
                    keyStatCard(icon: "circle.hexagongrid.fill", label: "覆盖率", value: String(format: "%.0f", session.coveragePercent), unit: "%", color: Color(hex: 0x8B5CF6))
                }
            }
            .padding(10)
            .background(AppColors.cardBg)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
    }

    private func keyStatCard(icon: String, label: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
        .cornerRadius(10)
    }

    // MARK: - Halves Breakdown

    private var cachedHalves: [SessionHalfData] {
        guard let data = session.halvesData else { return [] }
        return (try? JSONDecoder().decode([SessionHalfData].self, from: data)) ?? []
    }

    @ViewBuilder
    private var halvesSection: some View {
        let halves = cachedHalves
        if halves.count > 1 {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "list.number")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: 0xF59E0B))
                    Text("分节数据")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                }

                ForEach(halves, id: \.halfNumber) { half in
                    HStack(spacing: 0) {
                        // Half number
                        Text("第\(half.halfNumber)节")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            .frame(width: 50, alignment: .leading)

                        Spacer()

                        // Duration
                        halfDetailItem(icon: "clock", value: "\(half.elapsedSeconds / 60)'")

                        // Distance
                        halfDetailItem(icon: "figure.run", value: String(format: "%.1fkm", half.distanceMeters / 1000))

                        // Goals
                        halfDetailItem(icon: "soccerball", value: "\(half.goals)")

                        // Assists
                        halfDetailItem(icon: "hand.point.up.fill", value: "\(half.assists)")
                    }
                    .padding(12)
                    .background(AppColors.cardBg)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    )
                }
            }
        }
    }

    private func halfDetailItem(icon: String, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(AppColors.textSecondary)
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(AppColors.textPrimary)
        }
        .frame(width: 58)
    }

    // MARK: - Chart Section

    private func chartSection<Content: View>(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> Content) -> some View {
        chartSection(title: title, icon: icon, iconColor: iconColor, trailing: { EmptyView() }, content: content)
    }

    private func chartSection<Content: View, Trailing: View>(title: String, icon: String, iconColor: Color, @ViewBuilder trailing: () -> Trailing, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                trailing()
            }

            content()
                .padding(16)
                .background(AppColors.cardBg)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        }
    }

    // MARK: - Radar Chart Axes

    private var radarAxes: [(label: String, value: Double)] {
        let speed = min(1.0, stats.maxSpeedKmh / 30.0)
        let distance = min(1.0, session.totalDistanceMeters / 10000.0)
        let stamina = min(1.0, session.endTime.timeIntervalSince(session.startTime) / 5400.0) // 90 min
        let sprint = min(1.0, Double(session.sprintCount) / 30.0)
        let coverage = min(1.0, session.coveragePercent / 100.0)
        let intensity = min(1.0, stats.highIntensityDistanceMeters / 3000.0)
        return [
            (label: "速度", value: speed),
            (label: "跑量", value: distance),
            (label: "体力", value: stamina),
            (label: "冲刺", value: sprint),
            (label: "覆盖", value: coverage),
            (label: "强度", value: intensity),
        ]
    }

    // MARK: - Continuous Points (remove halftime gaps)

    /// Rebuilds track points with continuous elapsed timestamps,
    /// removing halftime gaps so charts show uninterrupted playing time.
    private func buildContinuousPoints(points: [TrackPointRecord]) -> [TrackPointRecord] {
        let halves = cachedHalves
        guard halves.count > 1 else { return points }

        // Build time ranges for each half
        var halfRanges: [(start: TimeInterval, end: TimeInterval)] = []
        for h in halves {
            halfRanges.append((start: h.startTime, end: h.endTime))
        }

        var result: [TrackPointRecord] = []
        var cumulativeOffset: TimeInterval = 0

        for (idx, range) in halfRanges.enumerated() {
            let halfPoints = points.filter { $0.timestamp >= range.start && $0.timestamp <= range.end }
            for p in halfPoints {
                let adjustedTs = (p.timestamp - range.start) + cumulativeOffset
                result.append(TrackPointRecord(
                    timestamp: adjustedTs,
                    latitude: p.latitude,
                    longitude: p.longitude,
                    speed: p.speed,
                    heartRate: p.heartRate,
                    accuracy: p.accuracy
                ))
            }
            if idx < halfRanges.count - 1 {
                cumulativeOffset += (range.end - range.start)
            }
        }

        return result.isEmpty ? points : result
    }

    // MARK: - Heatmap Flip

    private func flipGridHorizontally(_ grid: [[Double]]) -> [[Double]] {
        grid.map { $0.reversed() }
    }
}

struct StatCardView: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundColor(color)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(AppColors.cardBg)
        .cornerRadius(12)
    }
}
