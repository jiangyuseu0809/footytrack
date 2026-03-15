import SwiftUI

/// Renders a heatmap grid as a colored canvas.
struct HeatmapView: View {
    let grid: [[Double]]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("热力图")
                .font(.subheadline.weight(.medium))

            if !grid.isEmpty {
                let rows = grid.count
                let cols = grid[0].count

                Canvas { context, size in
                    let cellW = size.width / CGFloat(cols)
                    let cellH = size.height / CGFloat(rows)

                    for r in 0..<rows {
                        for c in 0..<cols {
                            let intensity = grid[r][c]
                            guard intensity > 0.01 else { continue }
                            let color = heatColor(intensity)
                            let rect = CGRect(
                                x: CGFloat(c) * cellW,
                                y: CGFloat(rows - 1 - r) * cellH,
                                width: cellW,
                                height: cellH
                            )
                            context.fill(Path(rect), with: .color(color))
                        }
                    }
                }
                .frame(height: CGFloat(rows) / CGFloat(cols) * UIScreen.main.bounds.width * 0.85)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }

    private func heatColor(_ intensity: Double) -> Color {
        let i = max(0, min(1, intensity))
        switch i {
        case ..<0.25:
            let t = i / 0.25
            return Color(red: 0, green: t, blue: 1).opacity(0.6)
        case ..<0.5:
            let t = (i - 0.25) / 0.25
            return Color(red: 0, green: 1, blue: 1 - t).opacity(0.7)
        case ..<0.75:
            let t = (i - 0.5) / 0.25
            return Color(red: t, green: 1, blue: 0).opacity(0.8)
        default:
            let t = (i - 0.75) / 0.25
            return Color(red: 1, green: 1 - t, blue: 0).opacity(0.9)
        }
    }
}
