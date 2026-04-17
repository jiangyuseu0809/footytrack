import Foundation
import WatchConnectivity

/// Manages WatchConnectivity session for sending data from watchOS to iPhone.
class PhoneSync: NSObject, ObservableObject, WCSessionDelegate {

    static let shared = PhoneSync()

    override init() {
        super.init()
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

    // MARK: - Send Session Data to iPhone

    func sendSessionData(_ data: [String: Any]) {
        guard WCSession.default.activationState == .activated else {
            print("[PhoneSync] WCSession not activated")
            return
        }

        // transferUserInfo is queued and delivered reliably in background
        WCSession.default.transferUserInfo(data)
    }
}
