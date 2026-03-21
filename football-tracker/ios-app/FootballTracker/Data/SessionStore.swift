import Foundation
import SwiftData

/// A recorded football session.
@Model
final class FootballSession {
    @Attribute(.unique) var id: String
    var startTime: Date
    var endTime: Date
    var playerWeightKg: Double
    var playerAge: Int

    // Aggregated stats
    var totalDistanceMeters: Double
    var avgSpeedKmh: Double
    var maxSpeedKmh: Double
    var sprintCount: Int
    var highIntensityDistanceMeters: Double
    var avgHeartRate: Int
    var maxHeartRate: Int
    var caloriesBurned: Double
    var slackIndex: Int
    var slackLabel: String
    var coveragePercent: Double
    var locationName: String
    var syncedToCloud: Bool
    var ownerUid: String

    // Raw data stored as JSON-encoded Data
    var trackPointsData: Data?

    init(
        id: String,
        startTime: Date,
        endTime: Date,
        playerWeightKg: Double = 70.0,
        playerAge: Int = 25,
        totalDistanceMeters: Double = 0,
        avgSpeedKmh: Double = 0,
        maxSpeedKmh: Double = 0,
        sprintCount: Int = 0,
        highIntensityDistanceMeters: Double = 0,
        avgHeartRate: Int = 0,
        maxHeartRate: Int = 0,
        caloriesBurned: Double = 0,
        slackIndex: Int = 0,
        slackLabel: String = "",
        coveragePercent: Double = 0,
        locationName: String = "",
        syncedToCloud: Bool = false,
        ownerUid: String = "",
        trackPointsData: Data? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.playerWeightKg = playerWeightKg
        self.playerAge = playerAge
        self.totalDistanceMeters = totalDistanceMeters
        self.avgSpeedKmh = avgSpeedKmh
        self.maxSpeedKmh = maxSpeedKmh
        self.sprintCount = sprintCount
        self.highIntensityDistanceMeters = highIntensityDistanceMeters
        self.avgHeartRate = avgHeartRate
        self.maxHeartRate = maxHeartRate
        self.caloriesBurned = caloriesBurned
        self.slackIndex = slackIndex
        self.slackLabel = slackLabel
        self.coveragePercent = coveragePercent
        self.locationName = locationName
        self.syncedToCloud = syncedToCloud
        self.ownerUid = ownerUid
        self.trackPointsData = trackPointsData
    }
}

/// A single GPS track point (Codable for JSON serialization).
struct TrackPointRecord: Codable {
    let timestamp: TimeInterval
    let latitude: Double
    let longitude: Double
    let speed: Double
    let heartRate: Int
    let accuracy: Double
}

/// Manages session persistence using SwiftData.
@MainActor
class SessionStore: ObservableObject {

    let container: ModelContainer
    let context: ModelContext

    @Published var sessions: [FootballSession] = []

    init() {
        let schema = Schema([FootballSession.self])
        let config = ModelConfiguration("FootballTracker", schema: schema)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Schema migration failed — delete old store and recreate
            let url = config.url
            try? FileManager.default.removeItem(at: url)
            // Also remove WAL/SHM files
            try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("sqlite-wal"))
            try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("sqlite-shm"))
            do {
                container = try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }
        context = container.mainContext
        fetchSessions()
    }

    func fetchSessions() {
        let descriptor = FetchDescriptor<FootballSession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        do {
            sessions = try context.fetch(descriptor)
        } catch {
            print("Failed to fetch sessions: \(error)")
            sessions = []
        }
    }

    func saveSession(_ session: FootballSession) {
        context.insert(session)
        try? context.save()
        fetchSessions()
    }

    func deleteSession(_ session: FootballSession) {
        let sessionId = session.id
        context.delete(session)
        try? context.save()
        fetchSessions()

        // Remove from unread notifications
        var unreadIds = UserDefaults.standard.stringArray(forKey: "unread_session_ids") ?? []
        var changed = false
        if unreadIds.contains(sessionId) {
            unreadIds.removeAll { $0 == sessionId }
            UserDefaults.standard.set(unreadIds, forKey: "unread_session_ids")
            UserDefaults.standard.set(unreadIds.count, forKey: "unread_session_count")
            changed = true
        }

        // Remove from read notifications
        var readIds = UserDefaults.standard.stringArray(forKey: "read_session_ids") ?? []
        if readIds.contains(sessionId) {
            readIds.removeAll { $0 == sessionId }
            UserDefaults.standard.set(readIds, forKey: "read_session_ids")
            changed = true
        }

        if changed {
            NotificationCenter.default.post(name: .sessionRecorded, object: nil)
        }
    }

    func markSynced(session: FootballSession) {
        session.syncedToCloud = true
        try? context.save()
    }

    func getUnsyncedSessions() -> [FootballSession] {
        sessions.filter { !$0.syncedToCloud }
    }

    func getTrackPoints(for session: FootballSession) -> [TrackPointRecord] {
        guard let data = session.trackPointsData else { return [] }
        return (try? JSONDecoder().decode([TrackPointRecord].self, from: data)) ?? []
    }

    // MARK: - Analysis (mirrors KMP algorithms in Swift)

    func computeStats(from points: [TrackPointRecord]) -> SessionAnalysisResult {
        let totalDist = computeTotalDistance(points)
        let maxSpeed = points.map { $0.speed * 3.6 }.max() ?? 0
        let duration = points.isEmpty ? 0 : points.last!.timestamp - points.first!.timestamp
        let avgSpeed = duration > 0 ? (totalDist / duration) * 3.6 : 0

        let hrPoints = points.filter { $0.heartRate > 0 }
        let avgHr = hrPoints.isEmpty ? 0 : Int(Double(hrPoints.map(\.heartRate).reduce(0, +)) / Double(hrPoints.count))
        let maxHr = hrPoints.map(\.heartRate).max() ?? 0

        let calories = estimateCalories(points, weightKg: 70)
        let sprints = countSprints(points)
        let hiDist = highIntensityDistance(points)
        let slack = computeSlack(points)
        let heatmap = generateHeatmap(points)
        let fatigue = analyzeFatigue(points)

        // Coverage based on heatmap grid (matches visual heat overlay)
        let heatmapCoverage: Double = {
            let totalCells = heatmap.count * (heatmap.first?.count ?? 0)
            guard totalCells > 0 else { return 0 }
            let activeCells = heatmap.flatMap { $0 }.filter { $0 > 0.03 }.count
            return Double(activeCells) / Double(totalCells) * 100.0
        }()

        return SessionAnalysisResult(
            totalDistanceMeters: totalDist,
            avgSpeedKmh: avgSpeed,
            maxSpeedKmh: maxSpeed,
            sprintCount: sprints,
            highIntensityDistanceMeters: hiDist,
            avgHeartRate: avgHr,
            maxHeartRate: maxHr,
            caloriesBurned: calories,
            slackIndex: slack.index,
            slackLabel: slack.label,
            coveragePercent: heatmapCoverage,
            heatmapGrid: heatmap,
            fatigueSegments: fatigue
        )
    }

    // Haversine distance
    private func haversine(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let R = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat/2) * sin(dLat/2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                sin(dLon/2) * sin(dLon/2)
        return R * 2 * atan2(sqrt(a), sqrt(1-a))
    }

    private func computeTotalDistance(_ points: [TrackPointRecord]) -> Double {
        guard points.count >= 2 else { return 0 }
        var total = 0.0
        for i in 1..<points.count {
            total += haversine(points[i-1].latitude, points[i-1].longitude,
                             points[i].latitude, points[i].longitude)
        }
        return total
    }

    private func estimateCalories(_ points: [TrackPointRecord], weightKg: Double) -> Double {
        guard points.count >= 2 else { return 0 }
        var total = 0.0
        for i in 1..<points.count {
            let dtMin = (points[i].timestamp - points[i-1].timestamp) / 60.0
            guard dtMin > 0, dtMin < 5 else { continue }
            let hr = points[i].heartRate
            let kcalPerMin: Double
            if hr > 0 {
                kcalPerMin = max(0, (-55.0969 + 0.6309 * Double(hr) + 0.1988 * weightKg + 0.2017 * 25.0) / 4.184)
            } else {
                let speedKmh = points[i].speed * 3.6
                let met: Double
                switch speedKmh {
                case ..<0.5: met = 1.5
                case ..<6.0: met = 3.5
                case ..<12.0: met = 7.0
                case ..<18.0: met = 10.0
                case ..<24.0: met = 13.0
                default: met = 15.0
                }
                kcalPerMin = met * weightKg * 3.5 / 200.0
            }
            total += kcalPerMin * dtMin
        }
        return total
    }

    private func countSprints(_ points: [TrackPointRecord]) -> Int {
        var count = 0
        var inSprint = false
        for p in points {
            let kmh = p.speed * 3.6
            if kmh >= 18.0 {
                if !inSprint { count += 1; inSprint = true }
            } else {
                inSprint = false
            }
        }
        return count
    }

    private func highIntensityDistance(_ points: [TrackPointRecord]) -> Double {
        guard points.count >= 2 else { return 0 }
        var total = 0.0
        for i in 1..<points.count {
            if points[i].speed * 3.6 >= 12.0 {
                total += haversine(points[i-1].latitude, points[i-1].longitude,
                                 points[i].latitude, points[i].longitude)
            }
        }
        return total
    }

    private func computeSlack(_ points: [TrackPointRecord]) -> (index: Int, label: String, coverage: Double) {
        guard points.count >= 2 else { return (100, "无数据", 0) }
        let totalTime = points.last!.timestamp - points.first!.timestamp
        guard totalTime > 0 else { return (100, "无数据", 0) }

        var standingTime = 0.0
        var lowSpeedTime = 0.0
        var lowHrTime = 0.0
        var hrTotalTime = 0.0

        for i in 1..<points.count {
            let dt = points[i].timestamp - points[i-1].timestamp
            let kmh = points[i].speed * 3.6
            if kmh < 0.5 { standingTime += dt }
            if kmh < 6.0 { lowSpeedTime += dt }
            if points[i].heartRate > 0 {
                hrTotalTime += dt
                if points[i].heartRate < 100 { lowHrTime += dt }
            }
        }

        let standingRatio = standingTime / totalTime
        let lowSpeedRatio = lowSpeedTime / totalTime
        let lowHrRatio = hrTotalTime > 0 ? lowHrTime / hrTotalTime : 0.5

        // Simple coverage: count unique grid cells
        let rows = 50, cols = 30
        let lats = points.map(\.latitude)
        let lons = points.map(\.longitude)
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLon = lons.min()!, maxLon = lons.max()!
        let latR = maxLat - minLat, lonR = maxLon - minLon
        var visited = Set<String>()
        if latR > 0 && lonR > 0 {
            for p in points {
                let r = Int((p.latitude - minLat) / latR * Double(rows - 1))
                let c = Int((p.longitude - minLon) / lonR * Double(cols - 1))
                visited.insert("\(r),\(c)")
            }
        }
        let coverage = Double(visited.count) / Double(rows * cols) * 100.0

        let raw = 0.35 * standingRatio + 0.25 * lowSpeedRatio + 0.20 * (1.0 - coverage / 100.0) + 0.20 * lowHrRatio
        let index = min(100, max(0, Int(raw * 100)))
        let label: String
        switch index {
        case 0...30: label = "拼命三郎"
        case 31...50: label = "积极参与"
        case 51...70: label = "有点偷懒"
        default: label = "场上观光"
        }
        return (index, label, coverage)
    }

    private func generateHeatmap(_ points: [TrackPointRecord], rows: Int = 50, cols: Int = 30) -> [[Double]] {
        guard !points.isEmpty else { return Array(repeating: Array(repeating: 0.0, count: cols), count: rows) }
        let lats = points.map(\.latitude)
        let lons = points.map(\.longitude)
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLon = lons.min()!, maxLon = lons.max()!
        let latR = maxLat - minLat, lonR = maxLon - minLon
        var grid = Array(repeating: Array(repeating: 0.0, count: cols), count: rows)

        guard latR > 0, lonR > 0 else { return grid }

        for p in points {
            let r = min(rows-1, max(0, Int((p.latitude - minLat) / latR * Double(rows-1))))
            let c = min(cols-1, max(0, Int((p.longitude - minLon) / lonR * Double(cols-1))))
            grid[r][c] += 1
        }

        // Gaussian blur for smooth heatmap
        grid = gaussianBlur(grid, radius: 3)

        // Normalize
        let maxVal = grid.flatMap { $0 }.max() ?? 1.0
        if maxVal > 0 {
            for r in 0..<rows {
                for c in 0..<cols {
                    grid[r][c] /= maxVal
                }
            }
        }
        return grid
    }

    private func gaussianBlur(_ grid: [[Double]], radius: Int) -> [[Double]] {
        let rows = grid.count
        guard rows > 0 else { return grid }
        let cols = grid[0].count
        guard cols > 0 else { return grid }

        // Build 1D Gaussian kernel
        let sigma = Double(radius) / 2.0
        let size = radius * 2 + 1
        var kernel = [Double](repeating: 0, count: size)
        var sum = 0.0
        for i in 0..<size {
            let x = Double(i - radius)
            kernel[i] = exp(-(x * x) / (2.0 * sigma * sigma))
            sum += kernel[i]
        }
        for i in 0..<size { kernel[i] /= sum }

        // Horizontal pass
        var temp = Array(repeating: Array(repeating: 0.0, count: cols), count: rows)
        for r in 0..<rows {
            for c in 0..<cols {
                var val = 0.0
                for k in 0..<size {
                    let cc = c + k - radius
                    if cc >= 0 && cc < cols {
                        val += grid[r][cc] * kernel[k]
                    }
                }
                temp[r][c] = val
            }
        }

        // Vertical pass
        var result = Array(repeating: Array(repeating: 0.0, count: cols), count: rows)
        for r in 0..<rows {
            for c in 0..<cols {
                var val = 0.0
                for k in 0..<size {
                    let rr = r + k - radius
                    if rr >= 0 && rr < rows {
                        val += temp[rr][c] * kernel[k]
                    }
                }
                result[r][c] = val
            }
        }

        return result
    }

    private func analyzeFatigue(_ points: [TrackPointRecord], segMinutes: Int = 5) -> [FatigueSegmentData] {
        guard points.count >= 2 else { return [] }
        let startTs = points.first!.timestamp
        let endTs = points.last!.timestamp
        let segSec = Double(segMinutes * 60)
        var segments: [FatigueSegmentData] = []
        var segStart = startTs
        var minute = 0

        while segStart < endTs {
            let segEnd = min(segStart + segSec, endTs)
            let segPoints = points.filter { $0.timestamp >= segStart && $0.timestamp <= segEnd }
            if segPoints.count >= 2 {
                let dist = computeTotalDistance(segPoints)
                let dt = segEnd - segStart
                let avgSpeed = dt > 0 ? (dist / dt) * 3.6 : 0
                let hrPts = segPoints.filter { $0.heartRate > 0 }
                let avgHr = hrPts.isEmpty ? 0 : Int(Double(hrPts.map(\.heartRate).reduce(0, +)) / Double(hrPts.count))
                segments.append(FatigueSegmentData(
                    startMinute: minute, endMinute: minute + segMinutes,
                    distanceMeters: dist, avgSpeedKmh: avgSpeed, avgHeartRate: avgHr
                ))
            }
            segStart = segEnd
            minute += segMinutes
        }
        return segments
    }
}

struct SessionAnalysisResult {
    let totalDistanceMeters: Double
    let avgSpeedKmh: Double
    let maxSpeedKmh: Double
    let sprintCount: Int
    let highIntensityDistanceMeters: Double
    let avgHeartRate: Int
    let maxHeartRate: Int
    let caloriesBurned: Double
    let slackIndex: Int
    let slackLabel: String
    let coveragePercent: Double
    let heatmapGrid: [[Double]]
    let fatigueSegments: [FatigueSegmentData]
}

struct FatigueSegmentData {
    let startMinute: Int
    let endMinute: Int
    let distanceMeters: Double
    let avgSpeedKmh: Double
    let avgHeartRate: Int
}
