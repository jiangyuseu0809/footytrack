import SwiftUI

/// Football pitch heatmap card — draws a green pitch with white markings
/// and overlays heat data from the session.
struct HeatmapOverlayView: View {
    let grid: [[Double]]
    let minLat: Double
    let maxLat: Double
    let minLon: Double
    let maxLon: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("球场热力图")
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppColors.textPrimary)

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

        // Background — dark green
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

        let cellW = pitchW / CGFloat(cols)
        let cellH = pitchH / CGFloat(rows)
        // Use square blocks — pick the smaller dimension, then scale up 4×
        let cellSize = min(cellW, cellH) * 4

        // Clip heat blocks to pitch boundary so they don't overflow the white lines
        var clippedContext = context
        let pitchRect = CGRect(x: pitchX, y: pitchY, width: pitchW, height: pitchH)
        clippedContext.clip(to: Path(pitchRect))

        for r in 0..<rows {
            for c in 0..<cols {
                let intensity = grid[r][c]
                guard intensity > 0.02 else { continue }
                let color = heatColor(intensity)
                // Center the square within each grid cell
                let cx = pitchX + CGFloat(c) * cellW + cellW / 2
                let cy = pitchY + CGFloat(rows - 1 - r) * cellH + cellH / 2
                let rect = CGRect(
                    x: cx - cellSize / 2,
                    y: cy - cellSize / 2,
                    width: cellSize,
                    height: cellSize
                )
                clippedContext.fill(Path(rect), with: .color(color))
            }
        }
    }

    private func heatColor(_ intensity: Double) -> Color {
        let i = max(0, min(1, intensity))
        switch i {
        case ..<0.2:
            let t = i / 0.2
            return Color(red: 1.0, green: 1.0, blue: 0.3).opacity(0.15 + t * 0.15)
        case ..<0.4:
            let t = (i - 0.2) / 0.2
            return Color(red: 1.0, green: 0.8 - t * 0.2, blue: 0.0).opacity(0.35 + t * 0.1)
        case ..<0.6:
            let t = (i - 0.4) / 0.2
            return Color(red: 1.0, green: 0.5 - t * 0.2, blue: 0.0).opacity(0.45 + t * 0.1)
        case ..<0.8:
            let t = (i - 0.6) / 0.2
            return Color(red: 0.95, green: 0.25 - t * 0.1, blue: 0.0).opacity(0.55 + t * 0.1)
        default:
            let t = (i - 0.8) / 0.2
            return Color(red: 0.85 + t * 0.05, green: 0.1 - t * 0.05, blue: 0.0).opacity(0.65 + t * 0.15)
        }
    }
}
