import SwiftUI

struct RadarChartView: View {
    let axes: [(label: String, value: Double)]
    var size: CGFloat = 200

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let radius = min(canvasSize.width, canvasSize.height) / 2 - 30
            let count = axes.count
            guard count >= 3 else { return }

            let angleStep = (2 * .pi) / Double(count)
            // Start from top (-π/2)
            let startAngle = -Double.pi / 2

            // Adaptive scaling: scale up so the max value fills ~80% of the chart
            let maxVal = axes.map(\.value).max() ?? 0
            let scaleFactor: Double = maxVal > 0 ? 0.8 / maxVal : 1.0

            func point(index: Int, scale: Double) -> CGPoint {
                let angle = startAngle + angleStep * Double(index)
                return CGPoint(
                    x: center.x + CGFloat(cos(angle) * scale * radius),
                    y: center.y + CGFloat(sin(angle) * scale * radius)
                )
            }

            // Draw grid rings at 20%, 40%, 60%, 80%, 100%
            for level in 1...5 {
                let scale = Double(level) / 5.0
                var gridPath = Path()
                for i in 0..<count {
                    let pt = point(index: i, scale: scale)
                    if i == 0 {
                        gridPath.move(to: pt)
                    } else {
                        gridPath.addLine(to: pt)
                    }
                }
                gridPath.closeSubpath()
                context.stroke(gridPath, with: .color(.white.opacity(0.15)), lineWidth: 1)
            }

            // Draw axis lines from center to each vertex
            for i in 0..<count {
                let pt = point(index: i, scale: 1.0)
                var axisPath = Path()
                axisPath.move(to: center)
                axisPath.addLine(to: pt)
                context.stroke(axisPath, with: .color(.white.opacity(0.2)), lineWidth: 1)
            }

            // Draw filled data polygon (skip when all values are effectively zero)
            let hasData = axes.contains { $0.value > 0.01 }
            if hasData {
                // Ensure each value has a minimum display scale so shape is visible
                let minDisplay = 0.08
                var dataPath = Path()
                for i in 0..<count {
                    let raw = min(max(axes[i].value, 0), 1) * scaleFactor
                    let val = axes[i].value > 0 ? max(raw, minDisplay) : 0
                    let pt = point(index: i, scale: min(val, 1.0))
                    if i == 0 {
                        dataPath.move(to: pt)
                    } else {
                        dataPath.addLine(to: pt)
                    }
                }
                dataPath.closeSubpath()
                context.fill(dataPath, with: .color(AppColors.neonBlue.opacity(0.3)))
                context.stroke(dataPath, with: .color(AppColors.neonBlue), lineWidth: 2)

                // Draw data points
                for i in 0..<count {
                    let raw = min(max(axes[i].value, 0), 1) * scaleFactor
                    let val = axes[i].value > 0 ? max(raw, minDisplay) : 0
                    let pt = point(index: i, scale: min(val, 1.0))
                    let dotRect = CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6)
                    context.fill(Path(ellipseIn: dotRect), with: .color(AppColors.neonBlue))
                }
            } else {
                // Show single center dot when no meaningful data
                let dotRect = CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)
                context.fill(Path(ellipseIn: dotRect), with: .color(AppColors.neonBlue))
            }

            // Draw axis labels with score
            for i in 0..<count {
                let angle = startAngle + angleStep * Double(i)
                let labelRadius = radius + 20
                let labelPoint = CGPoint(
                    x: center.x + CGFloat(cos(angle)) * labelRadius,
                    y: center.y + CGFloat(sin(angle)) * labelRadius
                )
                let score = Int(round(axes[i].value * 100))
                let labelStr = hasData ? "\(axes[i].label) \(score)" : axes[i].label
                let text = Text(labelStr)
                    .font(.system(size: 9))
                    .foregroundColor(.white)
                let resolved = context.resolve(text)
                context.draw(resolved, at: labelPoint, anchor: .center)
            }
        }
        .frame(width: size, height: size)
    }
}
