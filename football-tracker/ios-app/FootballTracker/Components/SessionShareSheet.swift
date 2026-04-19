import SwiftUI
import UIKit
import Photos

// MARK: - Static Speed Chart for Poster (no .task dependency)

/// A speed chart that pre-computes samples synchronously, suitable for ImageRenderer.
private struct PosterSpeedChartView: View {
    let points: [TrackPointRecord]

    private let samples: [(t: Double, v: Double)]
    private let rawMax: Double
    private let rawMin: Double

    init(points: [TrackPointRecord]) {
        self.points = points

        guard let start = points.first?.timestamp else {
            samples = []; rawMax = 0; rawMin = 0
            return
        }

        let raw: [(t: Double, v: Double)] = points.compactMap { p in
            let v = p.speed * 3.6
            return (t: p.timestamp - start, v: v)
        }

        rawMax = raw.map(\.v).max() ?? 0
        rawMin = raw.map(\.v).min() ?? 0

        guard raw.count > 2 else {
            samples = raw; return
        }

        // Aggregate
        let targetCount = min(140, max(36, raw.count / 3))
        guard raw.count > targetCount, targetCount > 1 else {
            samples = raw; return
        }

        var agg: [(t: Double, v: Double)] = []
        agg.reserveCapacity(targetCount)
        let bucketSpan = Double(raw.count - 1) / Double(targetCount - 1)
        for bucket in 0..<targetCount {
            let s = min(max(0, Int((Double(bucket) * bucketSpan).rounded(.down))), raw.count - 1)
            let e = min(max(s + 1, Int((Double(bucket + 1) * bucketSpan).rounded(.down))), raw.count)
            let slice = raw[s..<e]
            let avgT = slice.map(\.t).reduce(0, +) / Double(slice.count)
            let avgV = slice.map(\.v).reduce(0, +) / Double(slice.count)
            agg.append((t: avgT, v: avgV))
        }
        agg.sort { $0.t < $1.t }

        // Match average and preserve extremes
        let rawAvg = raw.map(\.v).reduce(0, +) / Double(raw.count)
        let aggAvg = agg.map(\.v).reduce(0, +) / Double(agg.count)
        let delta = rawAvg - aggAvg
        var adjusted = agg.map { (t: $0.t, v: max(0, $0.v + delta)) }
        if let minIdx = adjusted.indices.min(by: { adjusted[$0].v < adjusted[$1].v }) {
            adjusted[minIdx] = (t: adjusted[minIdx].t, v: rawMin)
        }
        if let maxIdx = adjusted.indices.max(by: { adjusted[$0].v < adjusted[$1].v }) {
            adjusted[maxIdx] = (t: adjusted[maxIdx].t, v: rawMax)
        }

        samples = adjusted
    }

    private var maxTime: Double { max(1, samples.last?.t ?? 1) }
    private var yMax: Double {
        guard !samples.isEmpty else { return 30 }
        return max(8, ceil(max(samples.map(\.v).max() ?? 1, rawMax) * 1.15))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("速度曲线 (km/h)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)

            if samples.count < 2 {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.02))
                    .frame(height: 130)
                    .overlay(
                        Text("暂无有效速度数据")
                            .font(.caption)
                            .foregroundColor(Color(hex: 0x8B949E))
                    )
            } else {
                Canvas { context, size in
                    let leftPad: CGFloat = 8
                    let topPad: CGFloat = 6
                    let bottomPad: CGFloat = 6
                    let plotRect = CGRect(x: leftPad, y: topPad,
                                          width: max(1, size.width - leftPad - 2),
                                          height: max(1, size.height - topPad - bottomPad))

                    // Grid
                    let tickCount = 4
                    let step = yMax / Double(max(1, tickCount - 1))
                    for i in 0..<tickCount {
                        let tick = yMax - Double(i) * step
                        let ratio = tick / max(0.0001, yMax)
                        let y = plotRect.maxY - CGFloat(ratio) * plotRect.height
                        var grid = Path()
                        grid.move(to: CGPoint(x: leftPad, y: y))
                        grid.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(grid, with: .color(Color.white.opacity(0.06)), lineWidth: 0.5)

                        let label = context.resolve(
                            Text(String(format: "%.0f", tick))
                                .font(.system(size: 9))
                                .foregroundColor(Color(hex: 0x8B949E))
                        )
                        context.draw(label, at: CGPoint(x: 1, y: y), anchor: .leading)
                    }

                    // Ensure line starts from t=0
                    var normalized = samples
                    if let first = normalized.first, first.t > 0.0001 {
                        normalized.insert((t: 0, v: first.v), at: 0)
                    }

                    let chartPoints = normalized.map { item in
                        let x = plotRect.minX + CGFloat(item.t / maxTime) * plotRect.width
                        let ratio = item.v / max(0.0001, yMax)
                        let y = plotRect.maxY - CGFloat(ratio) * plotRect.height
                        return CGPoint(
                            x: min(max(x, plotRect.minX), plotRect.maxX),
                            y: min(max(y, plotRect.minY), plotRect.maxY)
                        )
                    }

                    guard chartPoints.count >= 2 else { return }

                    var linePath = Path()
                    linePath.move(to: chartPoints[0])
                    for i in 1..<chartPoints.count {
                        linePath.addLine(to: chartPoints[i])
                    }

                    // Fill
                    var areaPath = linePath
                    areaPath.addLine(to: CGPoint(x: chartPoints.last!.x, y: plotRect.maxY))
                    areaPath.addLine(to: CGPoint(x: chartPoints.first!.x, y: plotRect.maxY))
                    areaPath.closeSubpath()
                    let lineColor = Color(hex: 0x3B82F6)
                    context.fill(areaPath, with: .linearGradient(
                        Gradient(colors: [lineColor.opacity(0.25), lineColor.opacity(0.03)]),
                        startPoint: CGPoint(x: plotRect.midX, y: plotRect.minY),
                        endPoint: CGPoint(x: plotRect.midX, y: plotRect.maxY)
                    ))

                    context.stroke(linePath, with: .color(lineColor), lineWidth: 1.5)
                }
                .frame(height: 130)
                .cornerRadius(8)

                // Legend
                HStack(spacing: 20) {
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: 0x3B82F6).opacity(0.85)).frame(width: 6, height: 6)
                        Text("平均 \(Int(samples.map(\.v).reduce(0, +) / Double(max(samples.count, 1))))")
                            .font(.system(size: 10)).foregroundColor(Color(hex: 0x8B949E))
                    }
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: 0xF59E0B)).frame(width: 6, height: 6)
                        Text("峰值 \(Int(rawMax))")
                            .font(.system(size: 10)).foregroundColor(Color(hex: 0x8B949E))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Static Heart Rate Chart for Poster

private struct PosterHeartRateChartView: View {
    let points: [TrackPointRecord]

    private let samples: [(t: Double, v: Double)]
    private let rawMax: Double
    private let rawMin: Double

    init(points: [TrackPointRecord]) {
        self.points = points

        guard let start = points.first?.timestamp else {
            samples = []; rawMax = 0; rawMin = 0; return
        }

        let raw: [(t: Double, v: Double)] = points.compactMap { p in
            let v = Double(p.heartRate)
            guard v > 0 else { return nil }
            return (t: p.timestamp - start, v: v)
        }

        rawMax = raw.map(\.v).max() ?? 0
        rawMin = raw.map(\.v).min() ?? 0

        guard raw.count > 2 else { samples = raw; return }

        let targetCount = min(120, max(28, raw.count / 4))
        guard raw.count > targetCount, targetCount > 1 else { samples = raw; return }

        var agg: [(t: Double, v: Double)] = []
        agg.reserveCapacity(targetCount)
        let bucketSpan = Double(raw.count - 1) / Double(targetCount - 1)
        for bucket in 0..<targetCount {
            let s = min(max(0, Int((Double(bucket) * bucketSpan).rounded(.down))), raw.count - 1)
            let e = min(max(s + 1, Int((Double(bucket + 1) * bucketSpan).rounded(.down))), raw.count)
            let slice = raw[s..<e]
            let avgT = slice.map(\.t).reduce(0, +) / Double(slice.count)
            let avgV = slice.map(\.v).reduce(0, +) / Double(slice.count)
            let peakV = slice.map(\.v).max() ?? avgV
            agg.append((t: avgT, v: avgV * 0.85 + peakV * 0.15))
        }
        agg.sort { $0.t < $1.t }

        // Exponential smoothing
        var smoothed = agg
        var prev = agg[0].v
        for i in 1..<smoothed.count {
            prev = 0.30 * smoothed[i].v + 0.70 * prev
            smoothed[i] = (t: smoothed[i].t, v: prev)
        }
        samples = smoothed
    }

    private var maxTime: Double { max(1, samples.last?.t ?? 1) }
    private var yMin: Double {
        guard !samples.isEmpty else { return 60 }
        let minV = samples.map(\.v).min() ?? 0
        return max(40, floor(minV * 0.9 / 10) * 10)
    }
    private var yMax: Double {
        guard !samples.isEmpty else { return 180 }
        let maxV = max(samples.map(\.v).max() ?? 1, rawMax)
        return max(yMin + 20, ceil(maxV * 1.1 / 10) * 10)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("心率曲线 (bpm)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)

            if samples.count < 2 {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.02))
                    .frame(height: 130)
                    .overlay(
                        Text("暂无有效心率数据")
                            .font(.caption)
                            .foregroundColor(Color(hex: 0x8B949E))
                    )
            } else {
                Canvas { context, size in
                    let leftPad: CGFloat = 8
                    let topPad: CGFloat = 6
                    let bottomPad: CGFloat = 6
                    let plotRect = CGRect(x: leftPad, y: topPad,
                                          width: max(1, size.width - leftPad - 2),
                                          height: max(1, size.height - topPad - bottomPad))

                    let tickCount = 4
                    let step = (yMax - yMin) / Double(max(1, tickCount - 1))
                    for i in 0..<tickCount {
                        let tick = yMax - Double(i) * step
                        let ratio = (tick - yMin) / max(0.0001, yMax - yMin)
                        let y = plotRect.maxY - CGFloat(ratio) * plotRect.height
                        var grid = Path()
                        grid.move(to: CGPoint(x: leftPad, y: y))
                        grid.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(grid, with: .color(Color.white.opacity(0.06)), lineWidth: 0.5)
                        let label = context.resolve(
                            Text("\(Int(tick.rounded()))")
                                .font(.system(size: 9))
                                .foregroundColor(Color(hex: 0x8B949E))
                        )
                        context.draw(label, at: CGPoint(x: 1, y: y), anchor: .leading)
                    }

                    var normalized = samples
                    if let first = normalized.first, first.t > 0.0001 {
                        normalized.insert((t: 0, v: first.v), at: 0)
                    }

                    let chartPoints = normalized.map { item in
                        let x = plotRect.minX + CGFloat(item.t / maxTime) * plotRect.width
                        let ratio = (item.v - yMin) / max(0.0001, yMax - yMin)
                        let y = plotRect.maxY - CGFloat(ratio) * plotRect.height
                        return CGPoint(
                            x: min(max(x, plotRect.minX), plotRect.maxX),
                            y: min(max(y, plotRect.minY), plotRect.maxY)
                        )
                    }

                    guard chartPoints.count >= 2 else { return }

                    // Smooth curve
                    var linePath = Path()
                    linePath.move(to: chartPoints[0])
                    for i in 1..<chartPoints.count {
                        let mid = CGPoint(
                            x: (chartPoints[i - 1].x + chartPoints[i].x) / 2,
                            y: (chartPoints[i - 1].y + chartPoints[i].y) / 2
                        )
                        linePath.addQuadCurve(to: mid, control: chartPoints[i - 1])
                        if i == chartPoints.count - 1 {
                            linePath.addQuadCurve(to: chartPoints[i], control: chartPoints[i])
                        }
                    }

                    var areaPath = linePath
                    areaPath.addLine(to: CGPoint(x: chartPoints.last!.x, y: plotRect.maxY))
                    areaPath.addLine(to: CGPoint(x: chartPoints.first!.x, y: plotRect.maxY))
                    areaPath.closeSubpath()
                    let lineColor = Color(hex: 0xEF4444)
                    context.fill(areaPath, with: .linearGradient(
                        Gradient(colors: [lineColor.opacity(0.25), lineColor.opacity(0.03)]),
                        startPoint: CGPoint(x: plotRect.midX, y: plotRect.minY),
                        endPoint: CGPoint(x: plotRect.midX, y: plotRect.maxY)
                    ))
                    context.stroke(linePath, with: .color(lineColor), lineWidth: 1.5)
                }
                .frame(height: 130)
                .cornerRadius(8)

                HStack(spacing: 20) {
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: 0xEF4444).opacity(0.85)).frame(width: 6, height: 6)
                        Text("平均 \(Int(samples.map(\.v).reduce(0, +) / Double(max(samples.count, 1))))")
                            .font(.system(size: 10)).foregroundColor(Color(hex: 0x8B949E))
                    }
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: 0xF59E0B)).frame(width: 6, height: 6)
                        Text("峰值 \(Int(rawMax))")
                            .font(.system(size: 10)).foregroundColor(Color(hex: 0x8B949E))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Share Poster View (rendered to image)

struct SessionPosterView: View {
    let session: FootballSession
    let stats: SessionAnalysisResult
    let trackPoints: [TrackPointRecord]

    private var dateStr: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日 EEEE"
        return f.string(from: session.startTime)
    }

    private var timeRangeStr: String {
        let sf = DateFormatter(); sf.dateFormat = "HH:mm"
        let ef = DateFormatter(); ef.dateFormat = "HH:mm"
        return "\(sf.string(from: session.startTime)) - \(ef.string(from: session.endTime))"
    }

    private var durationMin: Int {
        Int(session.endTime.timeIntervalSince(session.startTime) / 60)
    }

    private var radarAxes: [(label: String, value: Double)] {
        let speed = min(1.0, stats.maxSpeedKmh / 30.0)
        let distance = min(1.0, session.totalDistanceMeters / 10000.0)
        let stamina = min(1.0, session.endTime.timeIntervalSince(session.startTime) / 5400.0)
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

    var body: some View {
        VStack(spacing: 0) {
            // Header branding
            VStack(spacing: 6) {
                Image(systemName: "soccerball")
                    .font(.system(size: 28))
                    .foregroundColor(Color(hex: 0x00E676))
                Text("FootyTrack")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Text("比赛数据报告")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: 0x8B949E))
            }
            .padding(.top, 32)
            .padding(.bottom, 20)

            // Venue & Time
            VStack(spacing: 10) {
                posterInfoRow(icon: "mappin.and.ellipse", colors: [Color(hex: 0xA855F7), Color(hex: 0xEC4899)],
                              label: session.locationName.isEmpty ? "球场训练" : session.locationName)
                posterInfoRow(icon: "clock.fill", colors: [Color(hex: 0x3B82F6), Color(hex: 0x06B6D4)],
                              label: "\(dateStr) • \(timeRangeStr)")
            }
            .padding(16)
            .background(Color(hex: 0x1C2333))
            .cornerRadius(16)
            .padding(.horizontal, 20)

            // Key Stats — match detail page layout
            VStack(alignment: .leading, spacing: 10) {
                Text("核心数据")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)

                VStack(spacing: 6) {
                    // Row 1: Goals + Assists (2 columns)
                    HStack(spacing: 6) {
                        posterStatCard(icon: "soccerball", label: "进球", value: "\(session.goals)", unit: "", color: Color(hex: 0x10B981))
                        posterStatCard(icon: "hand.point.up.fill", label: "助攻", value: "\(session.assists)", unit: "", color: Color(hex: 0x3B82F6))
                    }
                    // Row 2: Duration + Distance + Calories (3 columns)
                    HStack(spacing: 6) {
                        posterStatCard(icon: "clock.fill", label: "时长", value: "\(durationMin)", unit: "min", color: Color(hex: 0x3B82F6))
                        posterStatCard(icon: "location.fill", label: "距离", value: String(format: "%.1f", session.totalDistanceMeters / 1000), unit: "km", color: Color(hex: 0xA855F7))
                        posterStatCard(icon: "flame.fill", label: "卡路里", value: "\(Int(session.caloriesBurned))", unit: "kcal", color: Color(hex: 0xEF4444))
                    }
                    // Row 3: Sprints + Max Speed + Avg Speed (3 columns)
                    HStack(spacing: 6) {
                        posterStatCard(icon: "bolt.fill", label: "冲刺", value: "\(session.sprintCount)", unit: "次", color: Color(hex: 0xF59E0B))
                        posterStatCard(icon: "speedometer", label: "最高速度", value: String(format: "%.1f", session.maxSpeedKmh), unit: "km/h", color: Color(hex: 0xEF4444))
                        posterStatCard(icon: "gauge.with.dots.needle.33percent", label: "均速", value: String(format: "%.1f", session.avgSpeedKmh), unit: "km/h", color: Color(hex: 0x10B981))
                    }
                    // Row 4: Avg HR + Max HR + Coverage (3 columns)
                    HStack(spacing: 6) {
                        posterStatCard(icon: "heart.fill", label: "均心率", value: "\(session.avgHeartRate > 0 ? session.avgHeartRate : stats.avgHeartRate)", unit: "bpm", color: Color(hex: 0xEF4444))
                        posterStatCard(icon: "heart.circle.fill", label: "最高心率", value: "\(session.maxHeartRate > 0 ? session.maxHeartRate : stats.maxHeartRate)", unit: "bpm", color: Color(hex: 0xDC2626))
                        posterStatCard(icon: "circle.hexagongrid.fill", label: "覆盖率", value: String(format: "%.0f", session.coveragePercent), unit: "%", color: Color(hex: 0x8B5CF6))
                    }
                }
                .padding(8)
                .background(Color(hex: 0x1C2333))
                .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Speed chart
            if !trackPoints.isEmpty {
                posterChartSection(icon: "bolt.fill", iconColor: Color(hex: 0x3B82F6), title: "速度") {
                    PosterSpeedChartView(points: trackPoints)
                }
            }

            // Heart Rate chart
            if !trackPoints.isEmpty {
                posterChartSection(icon: "heart.fill", iconColor: Color(hex: 0xEF4444), title: "心率") {
                    PosterHeartRateChartView(points: trackPoints)
                }
            }

            // Radar chart
            posterChartSection(icon: "pentagon.fill", iconColor: Color(hex: 0xA855F7), title: "能力雷达") {
                RadarChartView(axes: radarAxes, size: 200)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }

            // Heatmap
            if let latRange = latRange, let lonRange = lonRange {
                posterChartSection(icon: "map.fill", iconColor: Color(hex: 0x10B981), title: "活动热图") {
                    HeatmapOverlayView(
                        grid: stats.heatmapGrid,
                        minLat: latRange.min, maxLat: latRange.max,
                        minLon: lonRange.min, maxLon: lonRange.max,
                        attackEndToggle: .constant(true),
                        showToggle: false
                    )
                }
            }

            // Footer
            VStack(spacing: 4) {
                Rectangle()
                    .fill(Color(hex: 0x30363D))
                    .frame(height: 0.5)
                    .padding(.horizontal, 40)
                Text("— 来自 FootyTrack 足球数据助手 —")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: 0x8B949E))
                    .padding(.top, 12)
            }
            .padding(.bottom, 32)
        }
        .frame(width: 390)
        .background(Color(hex: 0x0D1117))
    }

    // MARK: - Helpers

    private func posterChartSection<Content: View>(icon: String, iconColor: Color, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            }
            content()
                .padding(12)
                .background(Color(hex: 0x1C2333))
                .cornerRadius(12)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var latRange: (min: Double, max: Double)? {
        guard let minLat = trackPoints.map(\.latitude).min(),
              let maxLat = trackPoints.map(\.latitude).max(),
              minLat != maxLat else { return nil }
        return (min: minLat, max: maxLat)
    }

    private var lonRange: (min: Double, max: Double)? {
        guard let minLon = trackPoints.map(\.longitude).min(),
              let maxLon = trackPoints.map(\.longitude).max(),
              minLon != maxLon else { return nil }
        return (min: minLon, max: maxLon)
    }

    private func posterInfoRow(icon: String, colors: [Color], label: String) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                )
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            Spacer()
        }
    }

    private func posterStatCard(icon: String, label: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: 0x8B949E))
                    .lineLimit(1)
            }
            HStack(alignment: .lastTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 9))
                        .foregroundColor(Color(hex: 0x8B949E))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.04))
        .cornerRadius(8)
    }
}

// MARK: - Share Action Sheet

struct SessionShareSheet: View {
    let posterImage: UIImage
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 12)

            // Poster preview
            ScrollView {
                Image(uiImage: posterImage)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(12)
                    .padding(20)
            }
            .frame(maxHeight: 400)

            // Action buttons
            HStack(spacing: 0) {
                shareActionButton(icon: "square.and.arrow.down.fill", label: "保存本地", color: Color(hex: 0x3B82F6)) {
                    saveToAlbum()
                }
                shareActionButton(icon: "message.fill", label: "微信好友", color: Color(hex: 0x07C160)) {
                    shareToWechatSession()
                }
                shareActionButton(icon: "circle.grid.2x2.fill", label: "朋友圈", color: Color(hex: 0xF59E0B)) {
                    shareToWechatTimeline()
                }
                shareActionButton(icon: "square.and.arrow.up.fill", label: "更多", color: Color(hex: 0xA855F7)) {
                    shareViaSystem()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Cancel button
            Button(action: onDismiss) {
                Text("取消")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: 0x8B949E))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .background(Color(hex: 0x1C2333))
        .cornerRadius(24)
    }

    private func shareActionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(color.opacity(0.15))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 22))
                            .foregroundColor(color)
                    )
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: 0x8B949E))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func saveToAlbum() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                guard status == .authorized || status == .limited else {
                    showToast("请在设置中允许访问相册")
                    return
                }
                UIImageWriteToSavedPhotosAlbum(posterImage, nil, nil, nil)
                showToast("已保存到相册")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { onDismiss() }
            }
        }
    }

    private func shareToWechatSession() {
        sendWechatImage(scene: Int32(WXSceneSession.rawValue))
    }

    private func shareToWechatTimeline() {
        sendWechatImage(scene: Int32(WXSceneTimeline.rawValue))
    }

    private func sendWechatImage(scene: Int32) {
        guard WXApi.isWXAppInstalled() else {
            showToast("未安装微信")
            return
        }

        let imageObject = WXImageObject()
        imageObject.imageData = posterImage.jpegData(compressionQuality: 0.85) ?? Data()

        let message = WXMediaMessage()
        message.mediaObject = imageObject
        // Thumbnail (WeChat requires ≤ 64KB)
        if let thumb = posterImage.thumbnailImage(maxSize: 200) {
            message.setThumbImage(thumb)
        }

        let req = SendMessageToWXReq()
        req.bText = false
        req.message = message
        req.scene = scene

        WXApi.send(req)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { onDismiss() }
    }

    private func shareViaSystem() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        let vc = UIActivityViewController(activityItems: [posterImage], applicationActivities: nil)
        var topVC = root
        while let presented = topVC.presentedViewController { topVC = presented }
        vc.popoverPresentationController?.sourceView = topVC.view
        topVC.present(vc, animated: true)
    }

    private func showToast(_ message: String) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else { return }
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.backgroundColor = UIColor(white: 0.2, alpha: 0.9)
        label.textAlignment = .center
        label.layer.cornerRadius = 20
        label.clipsToBounds = true
        label.sizeToFit()
        label.frame.size = CGSize(width: label.frame.width + 40, height: 40)
        label.center = CGPoint(x: window.bounds.midX, y: window.bounds.height - 120)
        window.addSubview(label)
        UIView.animate(withDuration: 0.3, delay: 1.5, options: [], animations: { label.alpha = 0 }) { _ in
            label.removeFromSuperview()
        }
    }
}

// MARK: - UIImage Thumbnail Helper

extension UIImage {
    func thumbnailImage(maxSize: CGFloat) -> UIImage? {
        let ratio = min(maxSize / size.width, maxSize / size.height, 1.0)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let thumb = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return thumb
    }
}

// MARK: - Image Renderer Helper

@MainActor
func renderSessionPoster(session: FootballSession, stats: SessionAnalysisResult, trackPoints: [TrackPointRecord]) -> UIImage? {
    let poster = SessionPosterView(session: session, stats: stats, trackPoints: trackPoints)
    let renderer = ImageRenderer(content: poster)
    renderer.scale = UIScreen.main.scale
    renderer.isOpaque = true
    return renderer.uiImage
}

// MARK: - Wrapper that handles async poster generation

struct SessionShareSheetWrapper: View {
    let session: FootballSession
    let stats: SessionAnalysisResult
    let trackPoints: [TrackPointRecord]
    @Binding var posterImage: UIImage?
    @Binding var isGenerating: Bool
    let onDismiss: () -> Void

    var body: some View {
        Group {
            if let img = posterImage {
                SessionShareSheet(posterImage: img, onDismiss: onDismiss)
            } else {
                VStack(spacing: 16) {
                    Capsule()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 36, height: 4)
                        .padding(.top, 12)
                    Spacer()
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                    Text("正在生成海报...")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: 0x8B949E))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: 0x1C2333))
            }
        }
        .task {
            guard isGenerating else { return }
            // Yield to allow the sheet to present and SwiftUI to settle
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            let img = renderSessionPoster(session: session, stats: stats, trackPoints: trackPoints)
            if img == nil {
                // Retry once after a longer delay if first attempt fails
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                posterImage = renderSessionPoster(session: session, stats: stats, trackPoints: trackPoints)
            } else {
                posterImage = img
            }
            isGenerating = false
        }
    }
}
