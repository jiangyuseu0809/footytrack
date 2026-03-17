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
        VStack(alignment: .leading, spacing: 8) {
            Text("球场热力图")
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppColors.textPrimary)

            PitchHeatmapCanvas(grid: grid)
                .aspectRatio(0.65, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(AppColors.cardBg)
        .cornerRadius(16)
    }
}

/// Canvas that draws a football pitch with heat overlay.
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

    // MARK: - Pitch Drawing

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

        // Center line
        let centerY = pitchY + pitchH / 2
        var centerLine = Path()
        centerLine.move(to: CGPoint(x: pitchX, y: centerY))
        centerLine.addLine(to: CGPoint(x: pitchX + pitchW, y: centerY))
        context.stroke(centerLine, with: .color(.white.opacity(0.5)), lineWidth: 1)

        // Center circle
        let circleR = pitchW * 0.16
        let circlePath = Path(ellipseIn: CGRect(
            x: pitchX + pitchW / 2 - circleR,
            y: centerY - circleR,
            width: circleR * 2,
            height: circleR * 2
        ))
        context.stroke(circlePath, with: .color(.white.opacity(0.5)), lineWidth: 1)

        // Center dot
        let dotR: CGFloat = 3
        let dotPath = Path(ellipseIn: CGRect(
            x: pitchX + pitchW / 2 - dotR,
            y: centerY - dotR,
            width: dotR * 2,
            height: dotR * 2
        ))
        context.fill(dotPath, with: .color(.white.opacity(0.6)))

        // Penalty areas (top & bottom)
        let penaltyW = pitchW * 0.6
        let penaltyH = pitchH * 0.14
        let penaltyX = pitchX + (pitchW - penaltyW) / 2

        // Top penalty area
        let topPenalty = CGRect(x: penaltyX, y: pitchY, width: penaltyW, height: penaltyH)
        context.stroke(Path(topPenalty), with: .color(.white.opacity(0.5)), lineWidth: 1)

        // Bottom penalty area
        let botPenalty = CGRect(x: penaltyX, y: pitchY + pitchH - penaltyH, width: penaltyW, height: penaltyH)
        context.stroke(Path(botPenalty), with: .color(.white.opacity(0.5)), lineWidth: 1)

        // Goal areas (top & bottom)
        let goalW = pitchW * 0.3
        let goalH = pitchH * 0.055
        let goalX = pitchX + (pitchW - goalW) / 2

        let topGoal = CGRect(x: goalX, y: pitchY, width: goalW, height: goalH)
        context.stroke(Path(topGoal), with: .color(.white.opacity(0.5)), lineWidth: 1)

        let botGoal = CGRect(x: goalX, y: pitchY + pitchH - goalH, width: goalW, height: goalH)
        context.stroke(Path(botGoal), with: .color(.white.opacity(0.5)), lineWidth: 1)

        // Penalty arcs (top & bottom)
        let arcR = pitchW * 0.10
        let penaltyDotTopY = pitchY + penaltyH * 0.85
        var topArc = Path()
        topArc.addArc(
            center: CGPoint(x: pitchX + pitchW / 2, y: penaltyDotTopY),
            radius: arcR,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: false
        )
        context.stroke(topArc, with: .color(.white.opacity(0.4)), lineWidth: 1)

        let penaltyDotBotY = pitchY + pitchH - penaltyH * 0.85
        var botArc = Path()
        botArc.addArc(
            center: CGPoint(x: pitchX + pitchW / 2, y: penaltyDotBotY),
            radius: arcR,
            startAngle: .degrees(180),
            endAngle: .degrees(360),
            clockwise: false
        )
        context.stroke(botArc, with: .color(.white.opacity(0.4)), lineWidth: 1)

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

        for r in 0..<rows {
            for c in 0..<cols {
                let intensity = grid[r][c]
                guard intensity > 0.02 else { continue }
                let color = heatColor(intensity)
                let rect = CGRect(
                    x: pitchX + CGFloat(c) * cellW,
                    y: pitchY + CGFloat(rows - 1 - r) * cellH,
                    width: cellW,
                    height: cellH
                )
                context.fill(Path(rect), with: .color(color))
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
