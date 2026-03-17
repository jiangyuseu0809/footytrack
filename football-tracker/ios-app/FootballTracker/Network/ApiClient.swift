import Foundation

enum ApiError: LocalizedError {
    case invalidURL
    case httpError(Int, String)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的请求地址"
        case .httpError(let code, let msg):
            return "服务器错误(\(code)): \(msg)"
        case .decodingError:
            return "数据解析失败"
        case .networkError(let err):
            return "网络错误: \(err.localizedDescription)"
        }
    }
}

@MainActor
final class ApiClient {
    static let shared = ApiClient()

    private let baseURL = "http://footytrack.cn"
    private let session: URLSession
    var token: String?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        session = URLSession(configuration: config)
    }

    // MARK: - Generic Request

    private func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: (any Encodable)? = nil
    ) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw ApiError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            req.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw ApiError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ApiError.networkError(URLError(.badServerResponse))
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let msg = (try? JSONDecoder().decode(MessageResponse.self, from: data))?.error
                ?? String(data: data, encoding: .utf8)
                ?? "Unknown error"
            throw ApiError.httpError(httpResponse.statusCode, msg)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ApiError.decodingError(error)
        }
    }

    // MARK: - Auth

    func login(username: String, password: String) async throws -> AuthResponse {
        try await request(
            endpoint: "/api/auth/login",
            method: "POST",
            body: LoginRequest(username: username, password: password)
        )
    }

    func register(username: String, password: String) async throws -> AuthResponse {
        try await request(
            endpoint: "/api/auth/register",
            method: "POST",
            body: RegisterRequest(username: username, password: password)
        )
    }

    // MARK: - User Profile

    func getProfile() async throws -> UserProfileResponse {
        try await request(endpoint: "/api/user/profile")
    }

    func updateProfile(_ profile: UpdateProfileRequest) async throws -> UserProfileResponse {
        try await request(
            endpoint: "/api/user/profile",
            method: "PUT",
            body: profile
        )
    }

    // MARK: - Sessions

    func syncSessions(_ syncReq: SyncRequest) async throws -> SyncResponse {
        try await request(
            endpoint: "/api/sessions/sync",
            method: "POST",
            body: syncReq
        )
    }

    func getSessions() async throws -> SessionListResponse {
        try await request(endpoint: "/api/sessions")
    }

    // MARK: - Teams

    func createTeam(name: String) async throws -> TeamResponse {
        try await request(
            endpoint: "/api/teams",
            method: "POST",
            body: CreateTeamRequest(name: name)
        )
    }

    func getTeams() async throws -> TeamListResponse {
        try await request(endpoint: "/api/teams")
    }

    func getTeamDetail(teamId: String) async throws -> TeamDetailResponse {
        try await request(endpoint: "/api/teams/\(teamId)")
    }

    func joinTeam(inviteCode: String) async throws -> TeamResponse {
        try await request(
            endpoint: "/api/teams/join",
            method: "POST",
            body: JoinTeamRequest(inviteCode: inviteCode)
        )
    }

    func leaveTeam(teamId: String) async throws -> MessageResponse {
        try await request(
            endpoint: "/api/teams/\(teamId)/leave",
            method: "POST"
        )
    }

    // MARK: - Badges

    func getEarnedBadges() async throws -> EarnedBadgesResponse {
        try await request(endpoint: "/api/badges/earned")
    }

    func checkBadges() async throws -> CheckBadgesResponse {
        try await request(endpoint: "/api/badges/check", method: "POST")
    }
}
