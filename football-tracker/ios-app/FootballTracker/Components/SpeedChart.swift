import SwiftUI

/// Renders speed or heart rate over time as an aggregated and smoothed chart using Canvas.
struct SpeedChartView: View {
    let points: [TrackPointRecord]
    let showHeartRate: Bool

    @State private var cachedSamples: [SamplePoint] = []
    @State private var cachedRawMaxValue: Double = 0
    @State private var cachedRawMinValue: Double = 0

    private struct SamplePoint {
        let t: Double
        let v: Double
    }

    private var pointsSignature: String {
        let firstTs = points.first?.timestamp ?? 0
        let lastTs = points.last?.timestamp ?? 0
        return "\(showHeartRate)-\(points.count)-\(firstTs)-\(lastTs)"
    }

    private var samples: [SamplePoint] {
        cachedSamples
    }

    private func preprocessSamples() {
        guard let start = points.first?.timestamp else {
            cachedSamples = []
            cachedRawMaxValue = 0
            cachedRawMinValue = 0
            return
        }

        let raw: [SamplePoint] = points.compactMap { p in
            let value = showHeartRate ? Double(p.heartRate) : p.speed * 3.6
            if showHeartRate && value <= 0 { return nil }
            return SamplePoint(t: p.timestamp - start, v: value)
        }

        cachedRawMaxValue = raw.map(\.v).max() ?? 0
        cachedRawMinValue = raw.map(\.v).min() ?? 0

        guard raw.count > 2 else {
            cachedSamples = raw
            return
        }

        if showHeartRate {
            let targetCount = min(120, max(28, raw.count / 4))
            let aggregated = aggregateAndPreservePeaks(raw, targetCount: targetCount)
            cachedSamples = exponentialSmoothing(aggregated, alpha: 0.30)
        } else {
            let targetCount = min(140, max(36, raw.count / 3))
            let aggregated = aggregateByTime(raw, targetCount: targetCount)
            cachedSamples = preserveExtremesAndMatchAverage(aggregated: aggregated, raw: raw)
        }
    }

    private var maxTime: Double {
        max(1, samples.last?.t ?? 1)
    }

    private var displayPeakValue: Double {
        showHeartRate ? (samples.map(\.v).max() ?? 0) : cachedRawMaxValue
    }

    private var yMin: Double {
        guard !samples.isEmpty else { return showHeartRate ? 60 : 0 }
        let minV = showHeartRate ? (samples.map(\.v).min() ?? 0) : min(samples.map(\.v).min() ?? 0, cachedRawMinValue)
        if showHeartRate {
            return max(40, floor(minV * 0.9 / 10) * 10)
        }
        return 0
    }

    private var yMax: Double {
        guard !samples.isEmpty else { return showHeartRate ? 180 : 30 }
        let maxV = max(samples.map(\.v).max() ?? 1, cachedRawMaxValue)
        if showHeartRate {
            return max(yMin + 20, ceil(maxV * 1.1 / 10) * 10)
        }
        return max(8, ceil(maxV * 1.15))
    }

    private var yTicks: [Double] {
        let tickCount = 5
        let step = (yMax - yMin) / Double(max(1, tickCount - 1))
        return (0..<tickCount).map { yMax - Double($0) * step }
    }

    private var lineColor: Color {
        showHeartRate ? Color(hex: 0xEF4444) : Color(hex: 0x3B82F6)
    }

    private var glowColor: Color {
        showHeartRate ? Color(hex: 0xF87171) : Color(hex: 0x60A5FA)
    }

    var body: some View {
        let axisLabelX: CGFloat = 2

        VStack(alignment: .leading, spacing: 10) {
            Text(showHeartRate ? "心率曲线 (bpm)" : "速度曲线 (km/h)")
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppColors.textPrimary)

            if samples.count < 2 {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.02))
                    .frame(height: 170)
                    .overlay(
                        Text(showHeartRate ? "暂无有效心率数据" : "暂无有效速度数据")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    )
            } else {
                Canvas { context, size in
                    let chartLeftPad: CGFloat = 10
                    let rightPad: CGFloat = 2
                    let topPad: CGFloat = 8
                    let bottomPad: CGFloat = 10
                    let plotRect = CGRect(
                        x: chartLeftPad,
                        y: topPad,
                        width: max(1, size.width - chartLeftPad - rightPad),
                        height: max(1, size.height - topPad - bottomPad)
                    )

                    let bgPath = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 10)
                    context.fill(bgPath, with: .color(Color.white.opacity(0.02)))

                    for tick in yTicks {
                        let ratio = (tick - yMin) / max(0.0001, (yMax - yMin))
                        let y = plotRect.maxY - CGFloat(ratio) * plotRect.height

                        var grid = Path()
                        grid.move(to: CGPoint(x: chartLeftPad, y: y))
                        grid.addLine(to: CGPoint(x: size.width, y: y))
                        context.stroke(grid, with: .color(Color.white.opacity(0.08)), lineWidth: 0.8)

                        let text = context.resolve(
                            Text(yAxisLabel(tick))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                        )
                        context.draw(text, at: CGPoint(x: axisLabelX, y: y), anchor: .leading)
                    }

                    let normalizedSamples: [SamplePoint] = {
                        guard let first = samples.first else { return samples }
                        if first.t <= 0.0001 { return samples }
                        return [SamplePoint(t: 0, v: first.v)] + samples
                    }()

                    let chartPoints = normalizedSamples.map { item in
                        let x = plotRect.minX + CGFloat(item.t / maxTime) * plotRect.width
                        let ratio = (item.v - yMin) / max(0.0001, (yMax - yMin))
                        let y = plotRect.maxY - CGFloat(ratio) * plotRect.height
                        return CGPoint(x: min(max(x, plotRect.minX), plotRect.maxX), y: min(max(y, plotRect.minY), plotRect.maxY))
                    }

                    guard chartPoints.count >= 2 else { return }
                    let linePath = smoothPath(chartPoints)

                    var areaPath = linePath
                    areaPath.addLine(to: CGPoint(x: chartPoints.last!.x, y: plotRect.maxY))
                    areaPath.addLine(to: CGPoint(x: chartPoints.first!.x, y: plotRect.maxY))
                    areaPath.closeSubpath()
                    context.fill(
                        areaPath,
                        with: .linearGradient(
                            Gradient(colors: [lineColor.opacity(0.30), lineColor.opacity(0.05)]),
                            startPoint: CGPoint(x: plotRect.midX, y: plotRect.minY),
                            endPoint: CGPoint(x: plotRect.midX, y: plotRect.maxY)
                        )
                    )

                    context.stroke(linePath, with: .color(glowColor.opacity(0.08)), lineWidth: 2.2)
                    context.stroke(linePath, with: .color(lineColor), lineWidth: 2.0)
                }
                .frame(height: 170)
                .cornerRadius(10)

                HStack {
                    Text("0 min")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer()
                    Text("\(Int(maxTime / 60)) min")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.leading, axisLabelX)

                HStack(spacing: 24) {
                    legendStatItem(
                        label: "平均 \(Int(samples.map(\.v).reduce(0, +) / Double(max(samples.count, 1))))",
                        dotColor: lineColor.opacity(0.85)
                    )
                    legendStatItem(
                        label: "峰值 \(Int(displayPeakValue))",
                        dotColor: Color(hex: 0xF59E0B)
                    )
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding()
        .background(AppColors.cardBg)
        .cornerRadius(12)
        .task(id: pointsSignature) {
            preprocessSamples()
        }
    }

    private func yAxisLabel(_ value: Double) -> String {
        if showHeartRate {
            return "\(Int(value.rounded()))"
        }
        return String(format: "%.0f", value)
    }

    private func aggregateAndPreservePeaks(_ input: [SamplePoint], targetCount: Int) -> [SamplePoint] {
        guard input.count > targetCount, targetCount > 1 else { return input }

        var result: [SamplePoint] = []
        result.reserveCapacity(targetCount)

        let bucketSpan = Double(input.count - 1) / Double(targetCount - 1)

        for bucket in 0..<targetCount {
            let startIndex = Int((Double(bucket) * bucketSpan).rounded(.down))
            let endIndex = Int((Double(bucket + 1) * bucketSpan).rounded(.down))
            let safeStart = min(max(0, startIndex), input.count - 1)
            let safeEnd = min(max(safeStart + 1, endIndex), input.count)
            let slice = input[safeStart..<safeEnd]

            let avgT = slice.map(\.t).reduce(0, +) / Double(slice.count)
            let avgV = slice.map(\.v).reduce(0, +) / Double(slice.count)
            let peakV = slice.map(\.v).max() ?? avgV
            let blended = avgV * 0.85 + peakV * 0.15

            result.append(SamplePoint(t: avgT, v: blended))
        }

        return result.sorted { $0.t < $1.t }
    }

    private func aggregateByTime(_ input: [SamplePoint], targetCount: Int) -> [SamplePoint] {
        guard input.count > targetCount, targetCount > 1 else { return input }

        var result: [SamplePoint] = []
        result.reserveCapacity(targetCount)

        let bucketSpan = Double(input.count - 1) / Double(targetCount - 1)
        for bucket in 0..<targetCount {
            let startIndex = Int((Double(bucket) * bucketSpan).rounded(.down))
            let endIndex = Int((Double(bucket + 1) * bucketSpan).rounded(.down))
            let safeStart = min(max(0, startIndex), input.count - 1)
            let safeEnd = min(max(safeStart + 1, endIndex), input.count)
            let slice = input[safeStart..<safeEnd]

            let avgT = slice.map(\.t).reduce(0, +) / Double(slice.count)
            let avgV = slice.map(\.v).reduce(0, +) / Double(slice.count)
            result.append(SamplePoint(t: avgT, v: avgV))
        }

        return result.sorted { $0.t < $1.t }
    }

    private func preserveExtremesAndMatchAverage(aggregated: [SamplePoint], raw: [SamplePoint]) -> [SamplePoint] {
        guard !aggregated.isEmpty, !raw.isEmpty else { return aggregated }

        var adjusted = aggregated
        let rawAvg = raw.map(\.v).reduce(0, +) / Double(raw.count)
        let aggAvg = aggregated.map(\.v).reduce(0, +) / Double(aggregated.count)
        let delta = rawAvg - aggAvg

        for i in adjusted.indices {
            adjusted[i] = SamplePoint(t: adjusted[i].t, v: max(0, adjusted[i].v + delta))
        }

        if let minIdx = adjusted.indices.min(by: { adjusted[$0].v < adjusted[$1].v }) {
            adjusted[minIdx] = SamplePoint(t: adjusted[minIdx].t, v: cachedRawMinValue)
        }
        if let maxIdx = adjusted.indices.max(by: { adjusted[$0].v < adjusted[$1].v }) {
            adjusted[maxIdx] = SamplePoint(t: adjusted[maxIdx].t, v: cachedRawMaxValue)
        }

        return adjusted
    }

    private func exponentialSmoothing(_ input: [SamplePoint], alpha: Double) -> [SamplePoint] {
        guard input.count > 1 else { return input }

        var output: [SamplePoint] = []
        output.reserveCapacity(input.count)

        var smoothed = input[0].v
        output.append(input[0])

        for i in 1..<input.count {
            smoothed = alpha * input[i].v + (1 - alpha) * smoothed
            output.append(SamplePoint(t: input[i].t, v: smoothed))
        }

        return output
    }

    private func legendStatItem(label: String, dotColor: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    private func smoothPath(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        guard points.count > 1 else { return path }

        if !showHeartRate {
            for i in 1..<points.count {
                path.addLine(to: points[i])
            }
            return path
        }

        for i in 1..<points.count {
            let mid = CGPoint(
                x: (points[i - 1].x + points[i].x) / 2,
                y: (points[i - 1].y + points[i].y) / 2
            )
            path.addQuadCurve(to: mid, control: points[i - 1])
            if i == points.count - 1 {
                path.addQuadCurve(to: points[i], control: points[i])
            }
        }
        return path
    }
}

/// Fatigue analysis bar chart — distance per 5-minute segment.
struct FatigueChartView: View {
    let segments: [FatigueSegmentData]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("疲劳分析 (每5分钟跑动距离)")
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppColors.textPrimary)

            let maxDist = max(1, segments.map(\.distanceMeters).max() ?? 1)

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(segments.indices, id: \.self) { i in
                    let seg = segments[i]
                    let fraction = CGFloat(seg.distanceMeters / maxDist)
                    let barColor: Color = fraction > 0.7 ? .green : (fraction > 0.4 ? .orange : .red)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor)
                        .frame(height: max(4, 120 * fraction))
                }
            }
            .frame(height: 120)

            HStack {
                Text("0'")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text("\(segments.last?.endMinute ?? 0)'")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding()
        .background(AppColors.cardBg)
        .cornerRadius(12)
    }
}
