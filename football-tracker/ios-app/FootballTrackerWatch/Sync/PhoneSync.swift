import Foundation
import WatchConnectivity

/// Manages WatchConnectivity session for syncing data from watchOS to iPhone.
/// Now also receives auth token from the iPhone app for direct server uploads.
class PhoneSync: NSObject, ObservableObject, WCSessionDelegate {

    static let shared = PhoneSync()

    @Published var isAuthenticated: Bool = false

    override init() {
        super.init()
        isAuthenticated = WatchApiClient.shared.isAuthenticated
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error = error {
            print("[PhoneSync] WCSession activation failed: \(error)")
        }
    }

    // MARK: - Receive auth token from iPhone

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleAuthPayload(applicationContext)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleAuthPayload(message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handleAuthPayload(userInfo)
    }

    private func handleAuthPayload(_ payload: [String: Any]) {
        guard let token = payload["auth_token"] as? String,
              let uid = payload["auth_uid"] as? String else { return }

        print("[PhoneSync] Received auth token from iPhone")
        WatchApiClient.shared.token = token
        WatchApiClient.shared.uid = uid

        DispatchQueue.main.async {
            self.isAuthenticated = true
        }

        // Flush any queued sessions now that we have auth
        Task {
            let synced = await WatchSessionQueue.shared.flushQueue()
            if synced > 0 {
                print("[PhoneSync] Flushed \(synced) queued sessions after auth")
            }
        }
    }

    // MARK: - Send Data (legacy — kept as fallback)

    func sendSessionData(_ data: [String: Any]) {
        guard WCSession.default.activationState == .activated else {
            print("[PhoneSync] WCSession not activated")
            return
        }

        // transferUserInfo is queued and delivered reliably in background
        WCSession.default.transferUserInfo(data)
    }
}
