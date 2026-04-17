import Foundation
import WatchConnectivity
import CoreLocation
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

        var trackPoints: [TrackPointRecord] = []
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
            trackPointsData: pointsData
        )
        session.ownerUid = ownerUid

        store.saveSession(session)

        // Post to refresh UI (notification + unread already tracked in didReceiveUserInfo)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .sessionRecorded, object: nil)
        }

        // Reverse geocode the first GPS point to get location name
        if let firstPoint = trackPoints.first {
            let location = CLLocation(latitude: firstPoint.latitude, longitude: firstPoint.longitude)
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

        return true
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
}
