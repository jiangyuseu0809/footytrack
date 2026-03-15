import SwiftUI

/// Detailed view of a single football session with all stats, charts, and heatmap.
struct SessionDetailView: View {
    let session: FootballSession
    @ObservedObject var store: SessionStore

    private var trackPoints: [TrackPointRecord] {
        store.getTrackPoints(for: session)
    }

    private var stats: SessionAnalysisResult {
        store.computeStats(from: trackPoints)
    }

    private var dateStr: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd EEE HH:mm"
        return formatter.string(from: session.startTime)
    }

    private var endStr: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: session.endTime)
    }

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                // Location name
                if !session.locationName.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(AppColors.neonBlue)
                        Text(session.locationName)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                    }
                    .padding(12)
                    .background(AppColors.cardBg)
                    .cornerRadius(12)
                }

                // Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCardView(label: "总距离", value: String(format: "%.1f", stats.totalDistanceMeters / 1000), unit: "km", color: .blue)
                    StatCardView(label: "最高速度", value: String(format: "%.1f", stats.maxSpeedKmh), unit: "km/h", color: .red)
                    StatCardView(label: "平均速度", value: String(format: "%.1f", stats.avgSpeedKmh), unit: "km/h", color: .teal)
                    StatCardView(label: "冲刺次数", value: "\(stats.sprintCount)", unit: "次", color: .orange)
                    StatCardView(label: "高强度距离", value: String(format: "%.1f", stats.highIntensityDistanceMeters / 1000), unit: "km", color: .red)
                    StatCardView(label: "卡路里", value: "\(Int(stats.caloriesBurned))", unit: "kcal", color: .orange)
                    StatCardView(label: "平均心率", value: "\(stats.avgHeartRate)", unit: "bpm", color: .pink)
                    StatCardView(label: "最高心率", value: "\(stats.maxHeartRate)", unit: "bpm", color: .red)
                }

                // Slack Index
                HStack {
                    VStack(alignment: .leading) {
                        Text("摸鱼指数")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                        Text("\(stats.slackIndex)/100")
                            .font(.title.weight(.bold))
                            .foregroundColor(AppColors.textPrimary)
                    }
                    Spacer()
                    SlackBadge(index: stats.slackIndex, label: stats.slackLabel)
                }
                .padding()
                .background(AppColors.cardBg)
                .cornerRadius(12)

                StatCardView(label: "覆盖率", value: String(format: "%.0f", stats.coveragePercent), unit: "%", color: AppColors.neonPurple)

                Divider().overlay(AppColors.dividerColor)

                // Speed Chart
                if !trackPoints.isEmpty {
                    SpeedChartView(points: trackPoints, showHeartRate: false)
                }

                // Heart Rate Chart
                if trackPoints.contains(where: { $0.heartRate > 0 }) {
                    SpeedChartView(points: trackPoints, showHeartRate: true)
                }

                // Fatigue Chart
                if !stats.fatigueSegments.isEmpty {
                    FatigueChartView(segments: stats.fatigueSegments)
                }

                // Heatmap on map
                if !trackPoints.isEmpty {
                    let lats = trackPoints.map(\.latitude)
                    let lons = trackPoints.map(\.longitude)
                    HeatmapOverlayView(
                        grid: stats.heatmapGrid,
                        minLat: lats.min()!,
                        maxLat: lats.max()!,
                        minLon: lons.min()!,
                        maxLon: lons.max()!
                    )
                }
                }
                .padding()
            }
        }
        .navigationTitle("\(dateStr) - \(endStr)")
        .navigationBarTitleDisplayMode(.inline)
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
