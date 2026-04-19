import Foundation
import CoreLocation
import HealthKit
import Combine

struct SyncTrackPoint: Codable {
    let timestamp: Double
    let latitude: Double
    let longitude: Double
    let speed: Double
    let heartRate: Int
    let accuracy: Double
}

/// Data for a single half/period of a match
struct HalfData {
    var startTime: Date
    var endTime: Date?
    var trackPoints: [(timestamp: Date, lat: Double, lon: Double, speed: Double, accuracy: Double)] = []
    var heartRateData: [(timestamp: Date, bpm: Int)] = []
    var goals: Int = 0
    var assists: Int = 0
    var distanceMeters: Double = 0
    var elapsedSeconds: Int = 0
    var swappedSides: Bool = false
}

enum GameState: Equatable {
    case idle
    case countdown(Int)  // countdown number
    case playing
    case paused
    case halftime        // between halves
    case finished
}

/// Manages GPS tracking, heart rate monitoring, multi-half match, and data sync for watchOS.
@MainActor
class TrackingManager: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var gameState: GameState = .idle
    @Published var elapsedSeconds: Int = 0          // current half elapsed
    @Published var totalElapsedSeconds: Int = 0     // total across all halves
    @Published var totalDistanceMeters: Double = 0.0
    @Published var currentSpeedMs: Double = 0.0
    @Published var currentHeartRate: Int = 0
    @Published var goals: Int = 0
    @Published var assists: Int = 0
    @Published var currentHalf: Int = 1
    @Published var swappedSides: Bool = false

    // Summary data
    @Published var summaryDistanceMeters: Double = 0.0
    @Published var summaryDurationSeconds: Int = 0
    @Published var summaryCalories: Double = 0.0
    @Published var summaryGoals: Int = 0
    @Published var summaryAssists: Int = 0

    // MARK: - Private

    private var locationManager: CLLocationManager?
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var timer: Timer?
    private var countdownTimer: Timer?

    private var currentTrackPoints: [(timestamp: Date, lat: Double, lon: Double, speed: Double, accuracy: Double)] = []
    private var currentHeartRateData: [(timestamp: Date, bpm: Int)] = []
    private var matchStartTime: Date?
    private var halfStartTime: Date?
    private var lastLocation: CLLocation?
    private var halfDistanceMeters: Double = 0.0

    /// Completed halves data
    private var completedHalves: [HalfData] = []

    // MARK: - Init

    override init() {
        locationManager = nil
        super.init()
    }

    // MARK: - Game Flow

    func startGame() {
        guard gameState == .idle else { return }

        // Reset everything
        goals = 0
        assists = 0
        currentHalf = 1
        elapsedSeconds = 0
        totalElapsedSeconds = 0
        totalDistanceMeters = 0
        halfDistanceMeters = 0
        currentSpeedMs = 0
        currentHeartRate = 0
        currentTrackPoints = []
        currentHeartRateData = []
        completedHalves = []
        lastLocation = nil
        matchStartTime = Date()
        halfStartTime = Date()

        // Start countdown 3, 2, 1
        gameState = .countdown(3)
        startCountdown()
    }

    private func startCountdown() {
        var count = 3
        gameState = .countdown(count)
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self else { timer.invalidate(); return }
                count -= 1
                if count > 0 {
                    self.gameState = .countdown(count)
                } else {
                    timer.invalidate()
                    self.countdownTimer = nil
                    self.beginPlaying()
                }
            }
        }
    }

    private func beginPlaying() {
        gameState = .playing
        halfStartTime = Date()

        if workoutSession == nil {
            // First half — start tracking infrastructure
            requestHealthKitAuth { [weak self] in
                Task { @MainActor in
                    self?.setupLocationManager()
                    self?.startWorkout()
                    self?.startTimer()
                }
            }
        } else {
            // Resuming for next half — location & workout already running
            startTimer()
        }
    }

    func pauseGame() {
        guard gameState == .playing else { return }
        gameState = .paused
        timer?.invalidate()
        timer = nil
    }

    func resumeGame() {
        guard gameState == .paused else { return }
        gameState = .playing
        startTimer()
    }

    func endHalf() {
        guard gameState == .playing || gameState == .paused else { return }
        timer?.invalidate()
        timer = nil

        // Save current half data
        let half = HalfData(
            startTime: halfStartTime ?? Date(),
            endTime: Date(),
            trackPoints: currentTrackPoints,
            heartRateData: currentHeartRateData,
            goals: goals,
            assists: assists,
            distanceMeters: halfDistanceMeters,
            elapsedSeconds: elapsedSeconds,
            swappedSides: swappedSides
        )
        completedHalves.append(half)

        // Always go to halftime — user decides to continue or end
        gameState = .halftime
    }

    func startNextHalf(swapSides: Bool = false) {
        guard gameState == .halftime else { return }
        currentHalf += 1

        // Reset per-half tracking including goals/assists
        currentTrackPoints = []
        currentHeartRateData = []
        elapsedSeconds = 0
        halfDistanceMeters = 0
        lastLocation = nil
        goals = 0
        assists = 0
        swappedSides = swapSides

        // Start countdown for next half
        gameState = .countdown(3)
        startCountdown()
    }

    func endMatchFromHalftime() {
        guard gameState == .halftime else { return }
        endMatch()
    }

    private func endMatch() {
        timer?.invalidate()
        timer = nil

        print("[TrackingManager] endMatch called, completedHalves=\(completedHalves.count)")

        // Stop location & workout
        locationManager?.stopUpdatingLocation()
        locationManager = nil

        // Get HealthKit calories
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
        workoutSession = nil
        workoutBuilder = nil

        // Compute summary
        summaryDurationSeconds = totalElapsedSeconds
        summaryDistanceMeters = totalDistanceMeters
        summaryGoals = completedHalves.reduce(0) { $0 + $1.goals }
        summaryAssists = completedHalves.reduce(0) { $0 + $1.assists }

        // Sync all halves to iPhone
        syncToPhone()

        gameState = .finished
    }

    func startNewGame() {
        gameState = .idle
    }

    func incrementGoals() {
        goals += 1
    }

    func decrementGoals() {
        if goals > 0 { goals -= 1 }
    }

    func incrementAssists() {
        assists += 1
    }

    func decrementAssists() {
        if assists > 0 { assists -= 1 }
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.elapsedSeconds += 1
                self?.totalElapsedSeconds += 1
            }
        }
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
                print("[TrackingManager] HealthKit auth error: \(error)")
            }
            print("[TrackingManager] HealthKit auth result: success=\(success)")
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

            let startDate = Date()
            workoutSession?.startActivity(with: startDate)
            workoutBuilder?.beginCollection(withStart: startDate) { success, error in
                if let error = error {
                    print("[TrackingManager] Workout beginCollection error: \(error)")
                }
                print("[TrackingManager] Workout beginCollection success=\(success)")
            }
        } catch {
            print("[TrackingManager] Failed to start workout: \(error)")
        }
    }

    // MARK: - Analysis

    private func estimateCalories() -> Double {
        let weightKg = 70.0
        var total = 0.0
        let allPoints = completedHalves.flatMap { $0.trackPoints } + currentTrackPoints
        for i in 1..<allPoints.count {
            let dt = allPoints[i].timestamp.timeIntervalSince(allPoints[i-1].timestamp) / 60.0
            guard dt > 0, dt < 5 else { continue }
            let speedKmh = allPoints[i].speed * 3.6
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

    // MARK: - Sync

    private func syncToPhone() {
        let sessionId = UUID().uuidString
        let startTs = matchStartTime?.timeIntervalSince1970 ?? 0
        let endTs = Date().timeIntervalSince1970

        // Build halves data for sync
        var halvesPayload: [[String: Any]] = []
        for (index, half) in completedHalves.enumerated() {
            let halfPayload = buildHalfPayload(half: half, halfNumber: index + 1)
            halvesPayload.append(halfPayload)
        }

        // Merge all track points and HR for the combined session
        let allTrackPoints = completedHalves.flatMap { $0.trackPoints }
        let allHeartRate = completedHalves.flatMap { $0.heartRateData }

        let latitudes = allTrackPoints.map { $0.lat }
        let longitudes = allTrackPoints.map { $0.lon }
        let timestamps = allTrackPoints.map { $0.timestamp.timeIntervalSince1970 }
        let speeds = allTrackPoints.map { $0.speed }

        let hrEntries: [[String: Any]] = allHeartRate
            .filter { $0.bpm > 0 }
            .map { ["ts": $0.timestamp.timeIntervalSince1970, "bpm": $0.bpm] }

        let payload: [String: Any] = [
            "session_id": sessionId,
            "start_time": startTs,
            "end_time": endTs,
            "latitudes": latitudes,
            "longitudes": longitudes,
            "timestamps": timestamps,
            "speeds": speeds,
            "heart_rates": hrEntries,
            "goals": completedHalves.reduce(0) { $0 + $1.goals },
            "assists": completedHalves.reduce(0) { $0 + $1.assists },
            "halves_count": completedHalves.count,
            "halves": halvesPayload
        ]

        PhoneSync.shared.sendSessionData(payload)
        print("[TrackingManager] Session with \(completedHalves.count) halves sent to iPhone")
    }

    private func buildHalfPayload(half: HalfData, halfNumber: Int) -> [String: Any] {
        let hrEntries: [[String: Any]] = half.heartRateData
            .filter { $0.bpm > 0 }
            .map { ["ts": $0.timestamp.timeIntervalSince1970, "bpm": $0.bpm] }

        return [
            "half_number": halfNumber,
            "start_time": half.startTime.timeIntervalSince1970,
            "end_time": (half.endTime ?? Date()).timeIntervalSince1970,
            "goals": half.goals,
            "assists": half.assists,
            "distance_meters": half.distanceMeters,
            "elapsed_seconds": half.elapsedSeconds,
            "swapped_sides": half.swappedSides,
            "latitudes": half.trackPoints.map { $0.lat },
            "longitudes": half.trackPoints.map { $0.lon },
            "timestamps": half.trackPoints.map { $0.timestamp.timeIntervalSince1970 },
            "speeds": half.trackPoints.map { $0.speed },
            "heart_rates": hrEntries
        ]
    }

    // MARK: - Helpers

    func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
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
            guard gameState == .playing else { return }
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
                    let dist = location.distance(from: last)
                    totalDistanceMeters += dist
                    halfDistanceMeters += dist
                }

                currentSpeedMs = max(0, location.speed)
                currentTrackPoints.append(point)
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
                                    date: Date) {
        print("[TrackingManager] Workout state: \(fromState.rawValue) → \(toState.rawValue)")
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didFailWithError error: Error) {
        print("[TrackingManager] Workout error: \(error)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension TrackingManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                                    didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType,
                  quantityType == HKQuantityType.quantityType(forIdentifier: .heartRate) else { continue }

            if let stats = workoutBuilder.statistics(for: quantityType),
               let quantity = stats.mostRecentQuantity() {
                let bpm = Int(quantity.doubleValue(for: .count().unitDivided(by: .minute())))
                guard bpm > 0 else { continue }
                Task { @MainActor in
                    self.currentHeartRate = bpm
                    self.currentHeartRateData.append((timestamp: Date(), bpm: bpm))
                    print("[TrackingManager] Heart rate: \(bpm) bpm")
                }
            }
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
