import SwiftUI
import MapKit
import CoreLocation

/// Detailed view of a single football session with all stats, charts, and heatmap.
struct SessionDetailView: View {
    let session: FootballSession
    @ObservedObject var store: SessionStore

    @State private var cachedTrackPoints: [TrackPointRecord] = []
    @State private var cachedStats: SessionAnalysisResult?
    @State private var cachedHasHeartRate = false
    @State private var cachedLatRange: (min: Double, max: Double)?
    @State private var cachedLonRange: (min: Double, max: Double)?
    @State private var showShareSheet = false
    @State private var posterImage: UIImage?
    @State private var isGeneratingPoster = false
    @State private var showLocationEditor = false

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
                    if !trackPoints.isEmpty {
                        chartSection(title: "速度", icon: "bolt.fill", iconColor: Color(hex: 0x3B82F6)) {
                            SpeedChartView(points: trackPoints, showHeartRate: false)
                        }
                    }

                    // Heart Rate Chart
                    if cachedHasHeartRate {
                        chartSection(title: "心率", icon: "heart.fill", iconColor: Color(hex: 0xEF4444)) {
                            SpeedChartView(points: trackPoints, showHeartRate: true)
                        }
                    }

                    // Fatigue Chart
                    if !stats.fatigueSegments.isEmpty {
                        chartSection(title: "体力曲线", icon: "flame.fill", iconColor: Color(hex: 0xF59E0B)) {
                            FatigueChartView(segments: stats.fatigueSegments)
                        }
                    }

                    // Heatmap
                    if let latRange = cachedLatRange, let lonRange = cachedLonRange {
                        chartSection(title: "活动热图", icon: "map.fill", iconColor: Color(hex: 0x10B981)) {
                            HeatmapOverlayView(
                                grid: stats.heatmapGrid,
                                minLat: latRange.min,
                                maxLat: latRange.max,
                                minLon: lonRange.min,
                                maxLon: lonRange.max
                            )
                        }
                    }
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
            cachedHasHeartRate = points.contains { $0.heartRate > 0 }
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

            // Goals & assists row (if any)
            if session.goals > 0 || session.assists > 0 {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                    keyStatCard(icon: "soccerball", label: "进球", value: "\(session.goals)", unit: "个",
                                gradient: [Color(hex: 0x10B981), Color(hex: 0x059669)])
                    keyStatCard(icon: "hand.point.up.fill", label: "助攻", value: "\(session.assists)", unit: "次",
                                gradient: [Color(hex: 0x3B82F6), Color(hex: 0x2563EB)])
                    keyStatCard(icon: "clock.fill", label: "运动时长", value: "\(durationMin)", unit: "min",
                                gradient: [Color(hex: 0x3B82F6), Color(hex: 0x06B6D4)])
                }
            } else {
                // No goals row, show duration in first row
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                    keyStatCard(icon: "clock.fill", label: "运动时长", value: "\(durationMin)", unit: "min",
                                gradient: [Color(hex: 0x3B82F6), Color(hex: 0x06B6D4)])
                    keyStatCard(icon: "figure.run", label: "总距离", value: String(format: "%.1f", session.totalDistanceMeters / 1000), unit: "km",
                                gradient: [Color(hex: 0xA855F7), Color(hex: 0xEC4899)])
                    keyStatCard(icon: "bolt.fill", label: "冲刺次数", value: "\(session.sprintCount)", unit: "次",
                                gradient: [Color(hex: 0xF59E0B), Color(hex: 0xF97316)])
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                if session.goals > 0 || session.assists > 0 {
                    keyStatCard(icon: "figure.run", label: "总距离", value: String(format: "%.1f", session.totalDistanceMeters / 1000), unit: "km",
                                gradient: [Color(hex: 0xA855F7), Color(hex: 0xEC4899)])
                    keyStatCard(icon: "bolt.fill", label: "冲刺次数", value: "\(session.sprintCount)", unit: "次",
                                gradient: [Color(hex: 0xF59E0B), Color(hex: 0xF97316)])
                }
                keyStatCard(icon: "speedometer", label: "最高速度", value: String(format: "%.1f", session.maxSpeedKmh), unit: "km/h",
                            gradient: [Color(hex: 0xEF4444), Color(hex: 0xF97316)])
                if !(session.goals > 0 || session.assists > 0) {
                    keyStatCard(icon: "gauge.with.dots.needle.33percent", label: "平均速度", value: String(format: "%.1f", session.avgSpeedKmh), unit: "km/h",
                                gradient: [Color(hex: 0x10B981), Color(hex: 0x34D399)])
                    keyStatCard(icon: "flame.fill", label: "卡路里", value: "\(Int(session.caloriesBurned))", unit: "kcal",
                                gradient: [Color(hex: 0xF59E0B), Color(hex: 0xEF4444)])
                }
            }

            if session.goals > 0 || session.assists > 0 {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                    keyStatCard(icon: "gauge.with.dots.needle.33percent", label: "平均速度", value: String(format: "%.1f", session.avgSpeedKmh), unit: "km/h",
                                gradient: [Color(hex: 0x10B981), Color(hex: 0x34D399)])
                    keyStatCard(icon: "flame.fill", label: "卡路里", value: "\(Int(session.caloriesBurned))", unit: "kcal",
                                gradient: [Color(hex: 0xF59E0B), Color(hex: 0xEF4444)])
                    keyStatCard(icon: "circle.hexagongrid.fill", label: "覆盖率", value: String(format: "%.0f", session.coveragePercent), unit: "%",
                                gradient: [Color(hex: 0x8B5CF6), Color(hex: 0xA855F7)])
                }
            }

            // Heart rate row
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                keyStatCard(icon: "heart.fill", label: "平均心率", value: "\(session.avgHeartRate > 0 ? session.avgHeartRate : stats.avgHeartRate)", unit: "bpm",
                            gradient: [Color(hex: 0xEF4444), Color(hex: 0xEC4899)])
                keyStatCard(icon: "heart.circle.fill", label: "最高心率", value: "\(session.maxHeartRate > 0 ? session.maxHeartRate : stats.maxHeartRate)", unit: "bpm",
                            gradient: [Color(hex: 0xDC2626), Color(hex: 0xEF4444)])
                if !(session.goals > 0 || session.assists > 0) {
                    keyStatCard(icon: "circle.hexagongrid.fill", label: "覆盖率", value: String(format: "%.0f", session.coveragePercent), unit: "%",
                                gradient: [Color(hex: 0x8B5CF6), Color(hex: 0xA855F7)])
                }
            }
        }
    }

    private func keyStatCard(icon: String, label: String, value: String, unit: String, gradient: [Color]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 10)
                .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                )

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(AppColors.textSecondary)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                Text(unit)
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppColors.cardBg)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
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
