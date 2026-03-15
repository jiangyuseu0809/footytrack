import SwiftUI

/// Renders speed or heart rate over time as a line chart using Canvas.
struct SpeedChartView: View {
    let points: [TrackPointRecord]
    let showHeartRate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(showHeartRate ? "心率曲线 (bpm)" : "速度曲线 (km/h)")
                .font(.subheadline.weight(.medium))

            let startTime = points.first?.timestamp ?? 0
            let values: [(Double, Double)] = points.map { p in
                let t = p.timestamp - startTime
                let v = showHeartRate ? Double(p.heartRate) : p.speed * 3.6
                return (t, v)
            }

            let maxTime = max(1, values.map(\.0).max() ?? 1)
            let maxVal = max(1, values.map(\.1).max() ?? 1)

            Canvas { context, size in
                let w = size.width
                let h = size.height

                // Draw speed zone backgrounds (speed chart only)
                if !showHeartRate {
                    let zones: [(Double, Double, Color)] = [
                        (0, 6, Color.green.opacity(0.1)),
                        (6, 12, Color.yellow.opacity(0.1)),
                        (12, 18, Color.orange.opacity(0.1)),
                        (18, maxVal, Color.red.opacity(0.1))
                    ]
                    for (low, high, color) in zones {
                        let y1 = h - (high / maxVal * h)
                        let y2 = h - (low / maxVal * h)
                        let rect = CGRect(x: 0, y: max(0, y1), width: w, height: max(0, y2 - y1))
                        context.fill(Path(rect), with: .color(color))
                    }
                }

                // Draw line
                let lineColor: Color = showHeartRate ? .red : .blue
                let step = max(1, values.count / Int(w / 2))
                var path = Path()
                var first = true

                for i in stride(from: 0, to: values.count, by: step) {
                    let (t, v) = values[i]
                    let x = t / maxTime * Double(w)
                    let y = Double(h) - (v / maxVal * Double(h))
                    if first {
                        path.move(to: CGPoint(x: x, y: y))
                        first = false
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                context.stroke(path, with: .color(lineColor), lineWidth: 1.5)
            }
            .frame(height: 160)
            .background(Color(.systemGray6))
            .cornerRadius(8)

            HStack {
                Text("0 min")
                    .font(.caption2)
                    .foregroundColor(.gray)
                Spacer()
                Text("\(Int(maxTime / 60)) min")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
    }
}

/// Fatigue analysis bar chart — distance per 5-minute segment.
struct FatigueChartView: View {
    let segments: [FatigueSegmentData]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("疲劳分析 (每5分钟跑动距离)")
                .font(.subheadline.weight(.medium))

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
                    .foregroundColor(.gray)
                Spacer()
                Text("\(segments.last?.endMinute ?? 0)'")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
    }
}
