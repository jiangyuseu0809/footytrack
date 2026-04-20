import SwiftUI

/// Football pitch heatmap card — draws a green pitch with white markings
/// and overlays heat data from the session.
struct HeatmapOverlayView: View {
    let grid: [[Double]]
    let minLat: Double
    let maxLat: Double
    let minLon: Double
    let maxLon: Double
    @Binding var attackEndToggle: Bool
    var showToggle: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PitchHeatmapCanvas(grid: grid)
                .aspectRatio(1.55, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            // Zone percentages
            zoneBar
        }
        .padding()
        .background(AppColors.cardBg)
        .cornerRadius(12)
    }

    // MARK: - Zone Percentages

    private var zonePercentages: (attack: Double, midfield: Double, defense: Double) {
        guard !grid.isEmpty else { return (0, 0, 0) }
        let rows = grid.count
        let cols = grid.first?.count ?? 0
        guard cols > 0 else { return (0, 0, 0) }

        // Grid columns map to pitch left→right (defense→attack in horizontal layout)
        // Split into 3 zones by columns
        let thirdCols = cols / 3
        let remainder = cols % 3

        var defenseSum = 0.0
        var midfieldSum = 0.0
        var attackSum = 0.0

        for r in 0..<rows {
            for c in 0..<cols {
                let val = grid[r][c]
                if c < thirdCols {
                    defenseSum += val
                } else if c < thirdCols * 2 + remainder {
                    midfieldSum += val
                } else {
                    attackSum += val
                }
            }
        }

        let total = defenseSum + midfieldSum + attackSum
        guard total > 0 else { return (33, 34, 33) }

        return (
            attack: (attackSum / total) * 100,
            midfield: (midfieldSum / total) * 100,
            defense: (defenseSum / total) * 100
        )
    }

    private var zoneBar: some View {
        let zones = zonePercentages
        return HStack(spacing: 0) {
            zoneItem(label: "后场", percent: zones.defense, color: Color(red: 0.2, green: 0.7, blue: 0.4))
            Spacer()
            zoneItem(label: "中场", percent: zones.midfield, color: Color(red: 1.0, green: 0.75, blue: 0.2))
            Spacer()
            zoneItem(label: "前场", percent: zones.attack, color: Color(red: 1.0, green: 0.35, blue: 0.25))
        }
        .padding(.horizontal, 4)
    }

    private func zoneItem(label: String, percent: Double, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
            Text(String(format: "%.0f%%", percent))
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)
        }
    }
}

/// Canvas that draws a horizontal football pitch with heat overlay.
struct PitchHeatmapCanvas: View {
    let grid: [[Double]]

    private static let downsampleScale: CGFloat = 2

    var body: some View {
        if grid.isEmpty {
            EmptyView()
        } else {
            Canvas { context, size in
                drawPitch(context: context, size: size)
                drawHeatmap(context: context, size: size)
            }
        }
    }

    // MARK: - Pitch Drawing (horizontal layout)

    private func drawPitch(context: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let margin: CGFloat = 12
        let pitchX = margin
        let pitchY = margin
        let pitchW = w - margin * 2
        let pitchH = h - margin * 2

        // Background — standard pitch green
        let bgRect = CGRect(origin: .zero, size: size)
        context.fill(Path(bgRect), with: .color(Color(red: 0.13, green: 0.42, blue: 0.20)))

        // Pitch outline
        let outlineRect = CGRect(x: pitchX, y: pitchY, width: pitchW, height: pitchH)
        context.stroke(Path(outlineRect), with: .color(.white.opacity(0.6)), lineWidth: 1.5)

        // Center line (vertical for horizontal pitch)
        let centerX = pitchX + pitchW / 2
        var centerLine = Path()
        centerLine.move(to: CGPoint(x: centerX, y: pitchY))
        centerLine.addLine(to: CGPoint(x: centerX, y: pitchY + pitchH))
        context.stroke(centerLine, with: .color(.white.opacity(0.5)), lineWidth: 1)

        // Center circle
        let circleR = pitchH * 0.18
        let circlePath = Path(ellipseIn: CGRect(
            x: centerX - circleR,
            y: pitchY + pitchH / 2 - circleR,
            width: circleR * 2,
            height: circleR * 2
        ))
        context.stroke(circlePath, with: .color(.white.opacity(0.5)), lineWidth: 1)

        // Center dot
        let dotR: CGFloat = 3
        let dotPath = Path(ellipseIn: CGRect(
            x: centerX - dotR,
            y: pitchY + pitchH / 2 - dotR,
            width: dotR * 2,
            height: dotR * 2
        ))
        context.fill(dotPath, with: .color(.white.opacity(0.6)))

        // Penalty areas (left & right)
        let penaltyH = pitchH * 0.6
        let penaltyW = pitchW * 0.14
        let penaltyY = pitchY + (pitchH - penaltyH) / 2

        // Left penalty area
        let leftPenalty = CGRect(x: pitchX, y: penaltyY, width: penaltyW, height: penaltyH)
        context.stroke(Path(leftPenalty), with: .color(.white.opacity(0.5)), lineWidth: 1)

        // Right penalty area
        let rightPenalty = CGRect(x: pitchX + pitchW - penaltyW, y: penaltyY, width: penaltyW, height: penaltyH)
        context.stroke(Path(rightPenalty), with: .color(.white.opacity(0.5)), lineWidth: 1)

        // Goal areas (left & right)
        let goalH = pitchH * 0.3
        let goalW = pitchW * 0.055
        let goalY = pitchY + (pitchH - goalH) / 2

        let leftGoal = CGRect(x: pitchX, y: goalY, width: goalW, height: goalH)
        context.stroke(Path(leftGoal), with: .color(.white.opacity(0.5)), lineWidth: 1)

        let rightGoal = CGRect(x: pitchX + pitchW - goalW, y: goalY, width: goalW, height: goalH)
        context.stroke(Path(rightGoal), with: .color(.white.opacity(0.5)), lineWidth: 1)

        // Penalty arcs (left & right)
        let arcR = pitchH * 0.10
        let penaltyDotLeftX = pitchX + penaltyW * 0.85
        var leftArc = Path()
        leftArc.addArc(
            center: CGPoint(x: penaltyDotLeftX, y: pitchY + pitchH / 2),
            radius: arcR,
            startAngle: .degrees(-90),
            endAngle: .degrees(90),
            clockwise: false
        )
        context.stroke(leftArc, with: .color(.white.opacity(0.4)), lineWidth: 1)

        let penaltyDotRightX = pitchX + pitchW - penaltyW * 0.85
        var rightArc = Path()
        rightArc.addArc(
            center: CGPoint(x: penaltyDotRightX, y: pitchY + pitchH / 2),
            radius: arcR,
            startAngle: .degrees(90),
            endAngle: .degrees(270),
            clockwise: false
        )
        context.stroke(rightArc, with: .color(.white.opacity(0.4)), lineWidth: 1)

        // Corner arcs
        let cornerR: CGFloat = 8
        for corner in cornerPoints(pitchX: pitchX, pitchY: pitchY, pitchW: pitchW, pitchH: pitchH) {
            var arc = Path()
            arc.addArc(
                center: corner.point,
                radius: cornerR,
                startAngle: corner.start,
                endAngle: corner.end,
                clockwise: false
            )
            context.stroke(arc, with: .color(.white.opacity(0.4)), lineWidth: 1)
        }
    }

    private struct CornerArc {
        let point: CGPoint
        let start: Angle
        let end: Angle
    }

    private func cornerPoints(pitchX: CGFloat, pitchY: CGFloat, pitchW: CGFloat, pitchH: CGFloat) -> [CornerArc] {
        [
            CornerArc(point: CGPoint(x: pitchX, y: pitchY), start: .degrees(0), end: .degrees(90)),
            CornerArc(point: CGPoint(x: pitchX + pitchW, y: pitchY), start: .degrees(90), end: .degrees(180)),
            CornerArc(point: CGPoint(x: pitchX + pitchW, y: pitchY + pitchH), start: .degrees(180), end: .degrees(270)),
            CornerArc(point: CGPoint(x: pitchX, y: pitchY + pitchH), start: .degrees(270), end: .degrees(360)),
        ]
    }

    // MARK: - Heatmap Drawing

    private func drawHeatmap(context: GraphicsContext, size: CGSize) {
        let rows = grid.count
        guard rows > 0, let cols = grid.first?.count, cols > 0 else { return }

        let margin: CGFloat = 12
        let pitchX = margin
        let pitchY = margin
        let pitchW = size.width - margin * 2
        let pitchH = size.height - margin * 2

        // Clip heat to pitch boundary
        var clippedContext = context
        let pitchRect = CGRect(x: pitchX, y: pitchY, width: pitchW, height: pitchH)
        clippedContext.clip(to: Path(pitchRect))

        // Downsampled render to reduce scroll-time rasterization cost.
        let renderScale = Self.downsampleScale
        let sampleCols = max(cols * Int(renderScale), 64)
        let sampleRows = max(rows * Int(renderScale), 40)
        let cellW = pitchW / CGFloat(sampleCols)
        let cellH = pitchH / CGFloat(sampleRows)
        let minVisible = 0.01

        clippedContext.drawLayer { layer in
            let blurRadius = max(cellW, cellH) * 1.8
            layer.addFilter(.blur(radius: blurRadius))

            for sr in 0..<sampleRows {
                let y = pitchY + CGFloat(sr) * cellH
                let gy = Double(sampleRows - 1 - sr) / Double(max(sampleRows - 1, 1)) * Double(rows - 1)

                for sc in 0..<sampleCols {
                    let x = pitchX + CGFloat(sc) * cellW
                    let gx = Double(sc) / Double(max(sampleCols - 1, 1)) * Double(cols - 1)

                    let raw = bilinearSample(grid: grid, row: gy, col: gx)
                    if raw <= minVisible { continue }

                    let normalized = (raw - minVisible) / (1 - minVisible)
                    let color = heatColor(normalized).opacity(0.95)
                    let rect = CGRect(x: x, y: y, width: cellW + 1.0, height: cellH + 1.0)
                    layer.fill(Path(rect), with: .color(color))
                }
            }
        }
    }

    private func bilinearSample(grid: [[Double]], row: Double, col: Double) -> Double {
        let rows = grid.count
        let cols = grid[0].count
        let r0 = max(0, min(rows - 1, Int(floor(row))))
        let r1 = max(0, min(rows - 1, r0 + 1))
        let c0 = max(0, min(cols - 1, Int(floor(col))))
        let c1 = max(0, min(cols - 1, c0 + 1))
        let fr = row - floor(row)
        let fc = col - floor(col)
        let v00 = grid[r0][c0]
        let v01 = grid[r0][c1]
        let v10 = grid[r1][c0]
        let v11 = grid[r1][c1]
        let top = v00 * (1 - fc) + v01 * fc
        let bot = v10 * (1 - fc) + v11 * fc
        return top * (1 - fr) + bot * fr
    }

    private func heatColor(_ intensity: Double) -> Color {
        let i = max(0, min(1, intensity))

        // Slight shaping so low-mid activity has enough visual presence.
        let shaped = pow(i, 0.84)

        // Color stops: light yellow -> yellow -> red -> deep red.
        let stops: [(pos: Double, r: Double, g: Double, b: Double, a: Double)] = [
            (0.00, 1.00, 0.96, 0.58, 0.16),  // light yellow
            (0.38, 1.00, 0.86, 0.18, 0.34),  // yellow
            (0.72, 0.98, 0.34, 0.14, 0.62),  // red
            (1.00, 0.62, 0.00, 0.00, 0.88),  // deep red
        ]

        var lo = stops[0]
        var hi = stops[stops.count - 1]
        for idx in 0..<(stops.count - 1) {
            if shaped >= stops[idx].pos && shaped <= stops[idx + 1].pos {
                lo = stops[idx]
                hi = stops[idx + 1]
                break
            }
        }

        let range = hi.pos - lo.pos
        let tLinear = range > 0 ? (shaped - lo.pos) / range : 0
        let t = tLinear * tLinear * (3 - 2 * tLinear) // smoothstep

        let r = lo.r + (hi.r - lo.r) * t
        let g = lo.g + (hi.g - lo.g) * t
        let b = lo.b + (hi.b - lo.b) * t
        let alpha = lo.a + (hi.a - lo.a) * t

        return Color(red: r, green: g, blue: b).opacity(alpha)
    }
}
