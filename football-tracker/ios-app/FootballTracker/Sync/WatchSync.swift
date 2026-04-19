import Foundation
import WatchConnectivity
import CoreLocation
import MapKit
import UserNotifications

/// Receives session data from the paired Apple Watch via WatchConnectivity.
class WatchSync: NSObject, ObservableObject, WCSessionDelegate {

    static let shared = WatchSync()
    private let pendingKey = "watch_pending_user_info_v1"

    /// Notification posted when watch data arrives. The userInfo contains the raw watch data.
    static let didReceiveDataNotification = Notification.Name("WatchSyncDidReceiveData")

    @Published var isWatchAppInstalled: Bool = false
    @Published var isPaired: Bool = false
    @Published var isReachable: Bool = false

    /// True when a Watch is paired AND our Watch app is installed.
    var isWatchConnected: Bool {
        isPaired && isWatchAppInstalled
    }

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    private func updateWatchState() {
        guard WCSession.isSupported() else {
            print("[WatchSync] WCSession not supported")
            return
        }
        let session = WCSession.default
        guard session.activationState == .activated else {
            print("[WatchSync] WCSession not activated yet: \(session.activationState.rawValue)")
            return
        }
        let paired = session.isPaired
        let installed = session.isWatchAppInstalled
        let reachable = session.isReachable
        print("[WatchSync] updateWatchState — paired=\(paired) installed=\(installed) reachable=\(reachable)")
        DispatchQueue.main.async {
            self.isPaired = paired
            self.isWatchAppInstalled = installed
            self.isReachable = reachable
        }
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error = error {
            print("[WatchSync] WCSession activation error: \(error)")
        }
        print("[WatchSync] activationDidComplete — state=\(activationState.rawValue)")
        updateWatchState()
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        print("[WatchSync] sessionWatchStateDidChange")
        updateWatchState()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        updateWatchState()
    }

    // MARK: - Send Auth Token to Watch (no longer needed — Watch only syncs via WatchConnectivity)

    func sendAuthTokenToWatch(token: String, uid: String) {
        // No-op: Watch no longer uploads to server directly
    }

    func clearWatchAuthToken() {
        // No-op: Watch no longer needs auth token
    }

    /// Called when the watch sends data via transferUserInfo
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        print("[WatchSync] didReceiveUserInfo keys=\(userInfo.keys.sorted())")
        if let sid = userInfo["session_id"] as? String {
            print("[WatchSync] Received session_id=\(sid), halves_count=\(userInfo["halves_count"] ?? "nil")")
        }
        enqueuePendingUserInfo(userInfo)

        // Send local notification immediately (works even when app was terminated)
        if let sessionId = userInfo["session_id"] as? String,
           let startTime = userInfo["start_time"] as? TimeInterval,
           let endTime = userInfo["end_time"] as? TimeInterval {

            let durationMin = Int(endTime - startTime) / 60
            let notifContent = UNMutableNotificationContent()
            notifContent.title = "比赛记录完成"
            notifContent.body = String(format: "时长 %d 分钟，点击查看详细数据", durationMin)
            notifContent.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: "session_\(sessionId)", content: notifContent, trigger: trigger)
            Task { try? await UNUserNotificationCenter.current().add(request) }

            // Track unread session IDs immediately
            let ud = UserDefaults.standard
            var unreadIds = ud.stringArray(forKey: "unread_session_ids") ?? []
            if !unreadIds.contains(sessionId) {
                unreadIds.append(sessionId)
            }
            ud.set(unreadIds, forKey: "unread_session_ids")
            ud.set(unreadIds.count, forKey: "unread_session_count")
        }

        NotificationCenter.default.post(
            name: WatchSync.didReceiveDataNotification,
            object: nil,
            userInfo: userInfo
        )
    }

    @MainActor
    func flushPendingUserInfo(to store: SessionStore, ownerUid: String = "") {
        let pending = loadPendingUserInfo()
        guard !pending.isEmpty else { return }

        var remaining: [[String: Any]] = []
        for item in pending {
            let saved = WatchSync.parseWatchData(item, store: store, ownerUid: ownerUid)
            if !saved {
                remaining.append(item)
            }
        }
        UserDefaults.standard.set(remaining, forKey: pendingKey)
    }

    func removePendingUserInfo(sessionId: String) {
        var pending = loadPendingUserInfo()
        pending.removeAll { ($0["session_id"] as? String) == sessionId }
        UserDefaults.standard.set(pending, forKey: pendingKey)
    }

    private func enqueuePendingUserInfo(_ userInfo: [String: Any]) {
        guard let sessionId = userInfo["session_id"] as? String else { return }
        var pending = loadPendingUserInfo()
        if let idx = pending.firstIndex(where: { ($0["session_id"] as? String) == sessionId }) {
            pending[idx] = userInfo
        } else {
            pending.append(userInfo)
        }
        UserDefaults.standard.set(pending, forKey: pendingKey)
    }

    private func loadPendingUserInfo() -> [[String: Any]] {
        UserDefaults.standard.array(forKey: pendingKey) as? [[String: Any]] ?? []
    }

    /// Parse raw watch data into a FootballSession + TrackPoints
    @MainActor
    static func parseWatchData(_ data: [String: Any], store: SessionStore, ownerUid: String = "") -> Bool {
        guard let sessionId = data["session_id"] as? String,
              let startTime = data["start_time"] as? TimeInterval,
              let endTime = data["end_time"] as? TimeInterval,
              let latitudes = data["latitudes"] as? [Double],
              let longitudes = data["longitudes"] as? [Double],
              let timestamps = data["timestamps"] as? [TimeInterval],
              let speeds = data["speeds"] as? [Double]
        else { return false }

        if store.sessions.contains(where: { $0.id == sessionId }) {
            return true
        }

        let heartRates = data["heart_rates"] as? [[String: Any]] ?? []
        var hrMap: [(ts: TimeInterval, bpm: Int)] = []
        for hr in heartRates {
            if let ts = hr["ts"] as? TimeInterval, let bpm = hr["bpm"] as? Int {
                hrMap.append((ts, bpm))
            }
        }

        let count = min(latitudes.count, longitudes.count, timestamps.count, speeds.count)
        guard count > 0 else { return false }

        // Build track points — mirror longitude for swapped-sides halves
        var trackPoints: [TrackPointRecord] = []
        let halvesRaw = data["halves"] as? [[String: Any]] ?? []
        let hasHalvesGPS = !halvesRaw.isEmpty && halvesRaw.allSatisfy { ($0["latitudes"] as? [Double])?.isEmpty == false }

        if hasHalvesGPS {
            // Rebuild from per-half data, mirroring swapped halves
            // First pass: collect all lons from half 1 (non-swapped baseline) to find center
            var baselineLons: [Double] = []
            for h in halvesRaw {
                let swapped = h["swapped_sides"] as? Bool ?? false
                if !swapped, let lons = h["longitudes"] as? [Double] {
                    baselineLons.append(contentsOf: lons)
                }
            }
            // If all halves are swapped (unlikely), use all lons
            if baselineLons.isEmpty {
                baselineLons = longitudes
            }
            let centerLon = baselineLons.isEmpty ? 0 : (baselineLons.min()! + baselineLons.max()!) / 2.0

            for h in halvesRaw {
                let swapped = h["swapped_sides"] as? Bool ?? false
                guard let hLats = h["latitudes"] as? [Double],
                      let hLons = h["longitudes"] as? [Double],
                      let hTimestamps = h["timestamps"] as? [TimeInterval],
                      let hSpeeds = h["speeds"] as? [Double] else { continue }
                let hHrs = h["heart_rates"] as? [[String: Any]] ?? []
                var hHrMap: [(ts: TimeInterval, bpm: Int)] = []
                for hr in hHrs {
                    if let ts = hr["ts"] as? TimeInterval, let bpm = hr["bpm"] as? Int {
                        hHrMap.append((ts, bpm))
                    }
                }
                let hCount = min(hLats.count, hLons.count, hTimestamps.count, hSpeeds.count)
                for i in 0..<hCount {
                    let lon = swapped ? (2 * centerLon - hLons[i]) : hLons[i]
                    let closestHr = findClosestHr(targetTs: hTimestamps[i], hrData: hHrMap.isEmpty ? hrMap : hHrMap)
                    trackPoints.append(TrackPointRecord(
                        timestamp: hTimestamps[i],
                        latitude: hLats[i],
                        longitude: lon,
                        speed: hSpeeds[i],
                        heartRate: closestHr,
                        accuracy: 5.0
                    ))
                }
            }
        } else {
            // Fallback: use flat arrays (no swap info)
            trackPoints.reserveCapacity(count)
            for i in 0..<count {
                let ts = timestamps[i]
                let closestHr = findClosestHr(targetTs: ts, hrData: hrMap)
                trackPoints.append(TrackPointRecord(
                    timestamp: ts,
                    latitude: latitudes[i],
                    longitude: longitudes[i],
                    speed: speeds[i],
                    heartRate: closestHr,
                    accuracy: 5.0
                ))
            }
        }

        let stats = store.computeStats(from: trackPoints)
        let pointsData = try? JSONEncoder().encode(trackPoints)

        let session = FootballSession(
            id: sessionId,
            startTime: Date(timeIntervalSince1970: startTime),
            endTime: Date(timeIntervalSince1970: endTime),
            totalDistanceMeters: stats.totalDistanceMeters,
            avgSpeedKmh: stats.avgSpeedKmh,
            maxSpeedKmh: stats.maxSpeedKmh,
            sprintCount: stats.sprintCount,
            highIntensityDistanceMeters: stats.highIntensityDistanceMeters,
            avgHeartRate: stats.avgHeartRate,
            maxHeartRate: stats.maxHeartRate,
            caloriesBurned: stats.caloriesBurned,
            slackIndex: stats.slackIndex,
            slackLabel: stats.slackLabel,
            coveragePercent: stats.coveragePercent,
            trackPointsData: pointsData,
            goals: data["goals"] as? Int ?? 0,
            assists: data["assists"] as? Int ?? 0,
            halvesData: parseHalvesData(from: data)
        )
        session.ownerUid = ownerUid

        store.saveSession(session)

        // Post to refresh UI (notification + unread already tracked in didReceiveUserInfo)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .sessionRecorded, object: nil)
        }

        // Search for nearby football fields, fallback to reverse geocode
        if let firstPoint = trackPoints.first {
            let location = CLLocation(latitude: firstPoint.latitude, longitude: firstPoint.longitude)
            let coordinate = CLLocationCoordinate2D(latitude: firstPoint.latitude, longitude: firstPoint.longitude)

            // Store GPS coordinates
            Task { @MainActor in
                session.locationLatitude = firstPoint.latitude
                session.locationLongitude = firstPoint.longitude
                try? store.context.save()
            }

            // Search for nearby football/soccer fields within 500m
            Task {
                let fieldName = await Self.searchNearbyFootballField(coordinate: coordinate)
                if let fieldName = fieldName {
                    await MainActor.run {
                        session.locationName = fieldName
                        try? store.context.save()
                    }
                } else {
                    // Fallback to reverse geocoding
                    CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
                        guard let placemark = placemarks?.first, error == nil else { return }
                        let name = placemark.name
                            ?? placemark.thoroughfare
                            ?? placemark.subLocality
                            ?? placemark.locality
                            ?? ""
                        guard !name.isEmpty else { return }
                        Task { @MainActor in
                            session.locationName = name
                            try? store.context.save()
                        }
                    }
                }
            }
        }

        return true
    }

    private static func parseHalvesData(from data: [String: Any]) -> Data? {
        guard let halves = data["halves"] as? [[String: Any]], !halves.isEmpty else { return nil }
        let parsed: [SessionHalfData] = halves.compactMap { h in
            guard let halfNumber = h["half_number"] as? Int,
                  let startTime = h["start_time"] as? TimeInterval,
                  let endTime = h["end_time"] as? TimeInterval else { return nil }
            return SessionHalfData(
                halfNumber: halfNumber,
                startTime: startTime,
                endTime: endTime,
                goals: h["goals"] as? Int ?? 0,
                assists: h["assists"] as? Int ?? 0,
                distanceMeters: h["distance_meters"] as? Double ?? 0,
                elapsedSeconds: h["elapsed_seconds"] as? Int ?? 0,
                swappedSides: h["swapped_sides"] as? Bool
            )
        }
        return try? JSONEncoder().encode(parsed)
    }

    private static func findClosestHr(targetTs: TimeInterval, hrData: [(ts: TimeInterval, bpm: Int)]) -> Int {
        guard !hrData.isEmpty else { return 0 }
        var bestIdx = 0
        var bestDiff = Double.infinity
        for (i, hr) in hrData.enumerated() {
            let diff = abs(hr.ts - targetTs)
            if diff < bestDiff {
                bestDiff = diff
                bestIdx = i
            }
        }

        // HealthKit heart-rate cadence can be sparse. Keep a wider matching window.
        return bestDiff <= 45.0 ? hrData[bestIdx].bpm : 0
    }

    /// Search for nearby football/soccer fields using MKLocalSearch
    static func searchNearbyFootballField(coordinate: CLLocationCoordinate2D, radiusMeters: Double = 500) async -> String? {
        let queries = ["足球场", "足球", "soccer field", "football field"]
        let excludeKeywords = ["篮球", "网球", "羽毛球", "乒乓", "排球", "棒球", "高尔夫",
                               "游泳", "健身", "瑜伽", "拳击", "台球", "保龄球",
                               "basketball", "tennis", "badminton", "golf", "swimming", "gym"]
        let footballKeywords = ["足球", "soccer", "football", "球场"]

        for query in queries {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: radiusMeters * 2,
                longitudinalMeters: radiusMeters * 2
            )
            do {
                let search = MKLocalSearch(request: request)
                let response = try await search.start()
                let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let nearby = response.mapItems
                    .filter { item in
                        guard let itemLoc = item.placemark.location else { return false }
                        guard location.distance(from: itemLoc) <= radiusMeters else { return false }
                        let name = (item.name ?? "").lowercased()
                        // Exclude non-football venues
                        for kw in excludeKeywords where name.contains(kw.lowercased()) { return false }
                        // Must contain a football keyword
                        let combined = name + " " + (item.placemark.title ?? "").lowercased()
                        return footballKeywords.contains { combined.contains($0.lowercased()) }
                            || item.pointOfInterestCategory == .stadium
                    }
                    .sorted { a, b in
                        let distA = location.distance(from: a.placemark.location!)
                        let distB = location.distance(from: b.placemark.location!)
                        return distA < distB
                    }
                if let best = nearby.first, let name = best.name, !name.isEmpty {
                    return name
                }
            } catch {
                continue
            }
        }
        return nil
    }
}
