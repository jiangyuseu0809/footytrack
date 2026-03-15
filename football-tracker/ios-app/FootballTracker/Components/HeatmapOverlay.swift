import SwiftUI
import MapKit

/// Heatmap overlay rendered on an Apple MapKit map.
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

            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            let latDelta = (maxLat - minLat) * 1.3
            let lonDelta = (maxLon - minLon) * 1.3
            let region = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: max(0.001, latDelta), longitudeDelta: max(0.001, lonDelta))
            )

            Map(initialPosition: .region(region)) {
            }
            .frame(height: 300)
            .cornerRadius(12)
            .overlay(
                HeatmapCanvasOverlay(grid: grid)
                    .allowsHitTesting(false)
            )
        }
    }
}

/// Canvas-based heatmap overlay that draws on top of the map.
struct HeatmapCanvasOverlay: View {
    let grid: [[Double]]

    @ViewBuilder
    var body: some View {
        if grid.isEmpty {
            EmptyView()
        } else {
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
        }
    }

    private func heatColor(_ intensity: Double) -> Color {
        let i = max(0, min(1, intensity))
        switch i {
        case ..<0.25:
            let t = i / 0.25
            return Color(red: 0, green: t, blue: 1).opacity(0.5)
        case ..<0.5:
            let t = (i - 0.25) / 0.25
            return Color(red: 0, green: 1, blue: 1 - t).opacity(0.6)
        case ..<0.75:
            let t = (i - 0.5) / 0.25
            return Color(red: t, green: 1, blue: 0).opacity(0.7)
        default:
            let t = (i - 0.75) / 0.25
            return Color(red: 1, green: 1 - t, blue: 0).opacity(0.8)
        }
    }
}
