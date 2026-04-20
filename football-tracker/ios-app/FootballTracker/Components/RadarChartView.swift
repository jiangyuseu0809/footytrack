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

            // Draw filled data polygon (skip when all values are zero)
            let hasData = axes.contains { $0.value > 0 }
            if hasData {
                var dataPath = Path()
                for i in 0..<count {
                    let val = min(max(axes[i].value, 0), 1)
                    let pt = point(index: i, scale: val)
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
                    let val = min(max(axes[i].value, 0), 1)
                    let pt = point(index: i, scale: val)
                    let dotRect = CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6)
                    context.fill(Path(ellipseIn: dotRect), with: .color(AppColors.neonBlue))
                }
            }

            // Draw axis labels
            for i in 0..<count {
                let angle = startAngle + angleStep * Double(i)
                let labelRadius = radius + 20
                let labelPoint = CGPoint(
                    x: center.x + CGFloat(cos(angle)) * labelRadius,
                    y: center.y + CGFloat(sin(angle)) * labelRadius
                )
                let text = Text(axes[i].label)
                    .font(.caption)
                    .foregroundColor(.white)
                let resolved = context.resolve(text)
                context.draw(resolved, at: labelPoint, anchor: .center)
            }
        }
        .frame(width: size, height: size)
    }
}
