import Foundation
import CoreLocation
import HealthKit
import Combine

/// Manages GPS tracking, heart rate monitoring, and data sync for watchOS.
@MainActor
class TrackingManager: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var isTracking = false
    @Published var showSummary = false
    @Published var elapsedSeconds: Int = 0
    @Published var totalDistanceMeters: Double = 0.0
    @Published var currentSpeedMs: Double = 0.0
    @Published var currentHeartRate: Int = 0

    // Summary data
    @Published var summaryDistanceMeters: Double = 0.0
    @Published var summaryDurationSeconds: Int = 0
    @Published var summaryCalories: Double = 0.0
    @Published var summarySlackIndex: Int = 0

    // MARK: - Private

    private var locationManager: CLLocationManager?
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var timer: Timer?

    private var trackPoints: [(timestamp: Date, lat: Double, lon: Double, speed: Double, accuracy: Double)] = []
    private var heartRateData: [(timestamp: Date, bpm: Int)] = []
    private var sessionStartTime: Date?
    private var lastLocation: CLLocation?

    // MARK: - Init

    override init() {
        locationManager = nil
        super.init()
    }

    // MARK: - Start / Stop

    func startTracking() {
        guard !isTracking else { return }
        isTracking = true
        showSummary = false
        elapsedSeconds = 0
        totalDistanceMeters = 0.0
        currentSpeedMs = 0.0
        currentHeartRate = 0
        trackPoints = []
        heartRateData = []
        lastLocation = nil
        sessionStartTime = Date()

        // Request HealthKit authorization then start
        requestHealthKitAuth { [weak self] in
            Task { @MainActor in
                self?.setupLocationManager()
                self?.startWorkout()

                self?.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                    Task { @MainActor in
                        self?.elapsedSeconds += 1
                    }
                }
            }
        }
    }

    func stopTracking() {
        guard isTracking else { return }
        isTracking = false
        timer?.invalidate()
        timer = nil

        locationManager?.stopUpdatingLocation()
        locationManager = nil

        // End workout and collect HealthKit calories
        if let builder = workoutBuilder {
            let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
            if let stats = builder.statistics(for: calorieType),
               let sum = stats.sumQuantity() {
                summaryCalories = sum.doubleValue(for: .kilocalorie())
            } else {
                summaryCalories = estimateCalories()
            }
        } else {
            summaryCalories = estimateCalories()
        }

        workoutSession?.end()

        // Compute summary
        summaryDurationSeconds = elapsedSeconds
        summaryDistanceMeters = totalDistanceMeters
        summarySlackIndex = computeSlackIndex()

        // Sync directly to server (or queue if offline)
        syncToServer()

        showSummary = true
    }

    func dismissSummary() {
        showSummary = false
    }

    // MARK: - HealthKit Authorization

    private func requestHealthKitAuth(completion: @escaping () -> Void) {
        let typesToRead: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
        ]
        let typesToWrite: Set<HKSampleType> = [
            HKQuantityType.workoutType(),
        ]
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { success, error in
            if let error = error {
                print("HealthKit auth error: \(error)")
            }
            completion()
        }
    }

    // MARK: - Location

    private func setupLocationManager() {
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        locationManager = manager

        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.allowsBackgroundLocationUpdates = true
            manager.startUpdatingLocation()
        } else {
            manager.requestWhenInUseAuthorization()
        }
    }

    // MARK: - HealthKit Workout

    private func startWorkout() {
        let config = HKWorkoutConfiguration()
        config.activityType = .soccer
        config.locationType = .outdoor

        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
            workoutBuilder?.delegate = self
            workoutSession?.delegate = self

            workoutSession?.startActivity(with: Date())
            workoutBuilder?.beginCollection(withStart: Date()) { _, _ in }
        } catch {
            print("Failed to start workout: \(error)")
        }
    }

    // MARK: - Analysis (simplified — shared KMP via Swift bridge)

    private func estimateCalories() -> Double {
        // Simplified MET-based estimation (mirrors KMP CalorieEstimator)
        let weightKg = 70.0
        var total = 0.0
        for i in 1..<trackPoints.count {
            let dt = trackPoints[i].timestamp.timeIntervalSince(trackPoints[i-1].timestamp) / 60.0
            guard dt > 0, dt < 5 else { continue }
            let speedKmh = trackPoints[i].speed * 3.6
            let met: Double
            switch speedKmh {
            case ..<0.5: met = 1.5
            case ..<6.0: met = 3.5
            case ..<12.0: met = 7.0
            case ..<18.0: met = 10.0
            case ..<24.0: met = 13.0
            default: met = 15.0
            }
            total += met * weightKg * 3.5 / 200.0 * dt
        }
        return total
    }

    private func computeSlackIndex() -> Int {
        guard trackPoints.count > 1 else { return 100 }
        let totalTime = trackPoints.last!.timestamp.timeIntervalSince(trackPoints.first!.timestamp)
        guard totalTime > 0 else { return 100 }

        var standingTime = 0.0
        for i in 1..<trackPoints.count {
            let dt = trackPoints[i].timestamp.timeIntervalSince(trackPoints[i-1].timestamp)
            if trackPoints[i].speed * 3.6 < 0.5 {
                standingTime += dt
            }
        }
        let standingRatio = standingTime / totalTime
        return min(100, max(0, Int(standingRatio * 100)))
    }

    // MARK: - Sync

    private func syncToServer() {
        let sessionId = UUID().uuidString
        let startTs = sessionStartTime?.timeIntervalSince1970 ?? 0
        let endTs = Date().timeIntervalSince1970

        // Build analysis from track data
        let totalDist = totalDistanceMeters
        let duration = endTs - startTs
        let avgSpeed = duration > 0 ? (totalDist / 1000.0) / (duration / 3600.0) : 0
        let maxSpeed = trackPoints.map { $0.speed * 3.6 }.max() ?? 0

        // Sprint count: segments where speed > 18 km/h
        var sprintCount = 0
        var inSprint = false
        for pt in trackPoints {
            if pt.speed * 3.6 > 18.0 {
                if !inSprint { sprintCount += 1; inSprint = true }
            } else {
                inSprint = false
            }
        }

        // High-intensity distance (speed > 12 km/h)
        var highIntensityDist = 0.0
        for i in 1..<trackPoints.count {
            if trackPoints[i].speed * 3.6 > 12.0 {
                let loc1 = CLLocation(latitude: trackPoints[i-1].lat, longitude: trackPoints[i-1].lon)
                let loc2 = CLLocation(latitude: trackPoints[i].lat, longitude: trackPoints[i].lon)
                highIntensityDist += loc2.distance(from: loc1)
            }
        }

        // Heart rate stats
        let avgHr = heartRateData.isEmpty ? 0 : heartRateData.map(\.bpm).reduce(0, +) / heartRateData.count
        let maxHr = heartRateData.map(\.bpm).max() ?? 0

        // Encode track points as JSON then base64
        struct TrackPointRecord: Codable {
            let timestamp: Double
            let latitude: Double
            let longitude: Double
            let speed: Double
            let heartRate: Int
            let accuracy: Double
        }
        let records = trackPoints.map { pt -> TrackPointRecord in
            let closestHr = heartRateData.min(by: {
                abs($0.timestamp.timeIntervalSince(pt.timestamp)) < abs($1.timestamp.timeIntervalSince(pt.timestamp))
            })?.bpm ?? 0
            return TrackPointRecord(
                timestamp: pt.timestamp.timeIntervalSince1970,
                latitude: pt.lat,
                longitude: pt.lon,
                speed: pt.speed,
                heartRate: closestHr,
                accuracy: pt.accuracy
            )
        }
        let trackPointsBase64 = (try? JSONEncoder().encode(records))?.base64EncodedString()

        let slackLabel: String
        let slack = summarySlackIndex
        switch slack {
        case 0..<20: slackLabel = "全力以赴"
        case 20..<40: slackLabel = "积极参与"
        case 40..<60: slackLabel = "中规中矩"
        case 60..<80: slackLabel = "有点摸鱼"
        default: slackLabel = "躺平大师"
        }

        let dto = WatchApiClient.WatchSessionDto(
            id: sessionId,
            startTime: Int64(startTs * 1000),
            endTime: Int64(endTs * 1000),
            playerWeightKg: 70.0,
            playerAge: 25,
            totalDistanceMeters: totalDist,
            avgSpeedKmh: avgSpeed,
            maxSpeedKmh: maxSpeed,
            sprintCount: sprintCount,
            highIntensityDistanceMeters: highIntensityDist,
            avgHeartRate: avgHr,
            maxHeartRate: maxHr,
            caloriesBurned: summaryCalories,
            slackIndex: slack,
            slackLabel: slackLabel,
            coveragePercent: 0,
            trackPointsData: trackPointsBase64
        )

        // Try direct server upload; queue on failure
        Task {
            guard WatchApiClient.shared.isAuthenticated else {
                print("[Sync] No auth token, queuing session")
                WatchSessionQueue.shared.enqueue(dto)
                return
            }
            do {
                try await WatchApiClient.shared.syncSession(dto)
                print("[Sync] Session uploaded to server")
            } catch {
                print("[Sync] Upload failed: \(error), queuing session")
                WatchSessionQueue.shared.enqueue(dto)
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension TrackingManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.allowsBackgroundLocationUpdates = true
                manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            for location in locations {
                guard location.horizontalAccuracy < 15 else { continue }

                let point = (
                    timestamp: location.timestamp,
                    lat: location.coordinate.latitude,
                    lon: location.coordinate.longitude,
                    speed: max(0, location.speed),
                    accuracy: location.horizontalAccuracy
                )

                if let last = lastLocation {
                    totalDistanceMeters += location.distance(from: last)
                }

                currentSpeedMs = max(0, location.speed)
                trackPoints.append(point)
                lastLocation = location
            }
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension TrackingManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState,
                                    date: Date) {}

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didFailWithError error: Error) {
        print("Workout error: \(error)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension TrackingManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                                    didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType,
                  quantityType == HKQuantityType.quantityType(forIdentifier: .heartRate) else { continue }

            if let stats = workoutBuilder.statistics(for: quantityType) {
                let bpm = Int(stats.mostRecentQuantity()?.doubleValue(for: .count().unitDivided(by: .minute())) ?? 0)
                Task { @MainActor in
                    currentHeartRate = bpm
                    heartRateData.append((timestamp: Date(), bpm: bpm))
                }
            }
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
