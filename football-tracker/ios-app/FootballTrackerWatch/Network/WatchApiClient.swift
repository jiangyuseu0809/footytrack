import Foundation

/// Lightweight API client for watchOS to upload sessions directly to the server.
/// Token is received from iPhone via WatchConnectivity and stored in UserDefaults.
class WatchApiClient {

    static let shared = WatchApiClient()

    private let baseURL = "https://footytrack.cn"
    private let session: URLSession
    private let tokenKey = "watch_auth_token"
    private let uidKey = "watch_auth_uid"

    var token: String? {
        get { UserDefaults.standard.string(forKey: tokenKey) }
        set { UserDefaults.standard.set(newValue, forKey: tokenKey) }
    }

    var uid: String? {
        get { UserDefaults.standard.string(forKey: uidKey) }
        set { UserDefaults.standard.set(newValue, forKey: uidKey) }
    }

    var isAuthenticated: Bool {
        token != nil && !(token?.isEmpty ?? true)
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
    }

    // MARK: - Session Sync

    struct WatchSyncRequest: Encodable {
        let sessions: [WatchSessionDto]
    }

    struct WatchSessionDto: Codable {
        let id: String
        let startTime: Int64
        let endTime: Int64
        let playerWeightKg: Double?
        let playerAge: Int?
        let totalDistanceMeters: Double?
        let avgSpeedKmh: Double?
        let maxSpeedKmh: Double?
        let sprintCount: Int?
        let highIntensityDistanceMeters: Double?
        let avgHeartRate: Int?
        let maxHeartRate: Int?
        let caloriesBurned: Double?
        let slackIndex: Int?
        let slackLabel: String?
        let coveragePercent: Double?
        let trackPointsData: String?
    }

    struct SyncResponse: Decodable {
        let synced: Int
    }

    /// Upload a session directly to the server.
    func syncSession(_ dto: WatchSessionDto) async throws {
        let body = WatchSyncRequest(sessions: [dto])
        let _: SyncResponse = try await post(endpoint: "/api/sessions/sync", body: body)
    }

    // MARK: - Generic POST

    private func post<T: Decodable>(endpoint: String, body: some Encodable) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw WatchApiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WatchApiError.networkError
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw WatchApiError.httpError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

enum WatchApiError: LocalizedError {
    case invalidURL
    case networkError
    case httpError(Int)
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效请求地址"
        case .networkError: return "网络错误"
        case .httpError(let code): return "服务器错误(\(code))"
        case .notAuthenticated: return "未登录，请在iPhone上配对"
        }
    }
}
