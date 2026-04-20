import Foundation
#if canImport(UIKit)
import UIKit
#endif

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

    private let baseURL = "https://footytrack.cn"
    private let session: URLSession
    var token: String?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 30
        config.urlCache = URLCache(
            memoryCapacity: 32 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024,
            diskPath: "footytrack-url-cache"
        )
        config.requestCachePolicy = .useProtocolCachePolicy
        session = URLSession(configuration: config)
    }

    // MARK: - Generic Request

    private func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        body: (any Encodable)? = nil,
        cachePolicy: URLRequest.CachePolicy? = nil
    ) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw ApiError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let cachePolicy {
            req.cachePolicy = cachePolicy
        }

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

    private func requestWithFallback<T: Decodable>(
        endpoints: [String],
        method: String = "GET",
        body: (any Encodable)? = nil
    ) async throws -> T {
        precondition(!endpoints.isEmpty)

        var lastError: Error?
        for endpoint in endpoints {
            do {
                let result: T = try await request(endpoint: endpoint, method: method, body: body)
                return result
            } catch let ApiError.httpError(code, _) where code == 404 {
                lastError = ApiError.httpError(code, "接口不存在")
                continue
            } catch {
                throw error
            }
        }

        throw (lastError ?? ApiError.httpError(404, "接口不存在"))
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

    /// WeChat OAuth login for iOS app. Sends the auth code from WXApi to backend.
    func wechatAppLogin(code: String) async throws -> AuthResponse {
        try await request(
            endpoint: "/api/auth/wechat",
            method: "POST",
            body: WeChatAppLoginRequest(code: code)
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

    #if canImport(UIKit)
    func updateAvatar(_ image: UIImage) async throws -> AvatarUploadResponse {
        guard let compressed = compressAvatar(image) else {
            throw ApiError.decodingError(NSError(domain: "avatar", code: -1))
        }

        let endpoints = ["/api/user/avatar", "/user/avatar"]
        var lastError: Error?

        for endpoint in endpoints {
            guard let url = URL(string: baseURL + endpoint) else {
                throw ApiError.invalidURL
            }

            var req = URLRequest(url: url)
            req.httpMethod = "PUT"
            req.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
            if let token = token {
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            req.httpBody = compressed

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

                if httpResponse.statusCode == 404 {
                    lastError = ApiError.httpError(httpResponse.statusCode, msg)
                    continue
                }
                throw ApiError.httpError(httpResponse.statusCode, msg)
            }

            do {
                return try JSONDecoder().decode(AvatarUploadResponse.self, from: data)
            } catch {
                throw ApiError.decodingError(error)
            }
        }

        throw (lastError ?? ApiError.httpError(404, "接口不存在"))
    }

    private func compressAvatar(_ image: UIImage) -> Data? {
        let maxBytes = 500 * 1024
        let targetSize: CGFloat = 512
        let longSide = max(image.size.width, image.size.height)
        let scaleRatio = min(1.0, targetSize / max(1, longSide))
        let drawSize = CGSize(width: image.size.width * scaleRatio, height: image.size.height * scaleRatio)

        let renderer = UIGraphicsImageRenderer(size: drawSize)
        let scaled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: drawSize))
        }

        var quality: CGFloat = 0.86
        while quality >= 0.4 {
            if let data = scaled.jpegData(compressionQuality: quality), data.count <= maxBytes {
                return data
            }
            quality -= 0.08
        }

        return scaled.jpegData(compressionQuality: 0.35)
    }
    #endif

    // MARK: - Sessions

    func syncSessions(_ syncReq: SyncRequest) async throws -> SyncResponse {
        try await request(
            endpoint: "/api/sessions/sync",
            method: "POST",
            body: syncReq
        )
    }

    func getSessions(forceRefresh: Bool = false) async throws -> SessionListResponse {
        try await request(
            endpoint: "/api/sessions",
            cachePolicy: forceRefresh ? .reloadIgnoringLocalCacheData : nil
        )
    }

    func deleteSession(id: String) async throws -> MessageResponse {
        try await request(
            endpoint: "/api/sessions/\(id)",
            method: "DELETE"
        )
    }

    func getPlayerAnalysis() async throws -> PlayerAnalysisResponse {
        try await request(endpoint: "/api/sessions/analysis")
    }

    func getSessionSummary(sessionId: String) async throws -> MatchSummaryResponse {
        try await request(endpoint: "/api/sessions/\(sessionId)/summary")
    }

    // MARK: - Teams

    func createTeam(name: String) async throws -> TeamResponse {
        try await requestWithFallback(
            endpoints: ["/api/teams", "/teams"],
            method: "POST",
            body: CreateTeamRequest(name: name)
        )
    }

    func getTeams() async throws -> TeamListResponse {
        try await requestWithFallback(endpoints: ["/api/teams", "/teams"])
    }

    func getTeamDetail(teamId: String) async throws -> TeamDetailResponse {
        try await requestWithFallback(endpoints: ["/api/teams/\(teamId)", "/teams/\(teamId)"])
    }

    func joinTeam(inviteCode: String) async throws -> TeamResponse {
        try await requestWithFallback(
            endpoints: ["/api/teams/join", "/teams/join"],
            method: "POST",
            body: JoinTeamRequest(inviteCode: inviteCode)
        )
    }

    func leaveTeam(teamId: String) async throws -> MessageResponse {
        try await requestWithFallback(
            endpoints: ["/api/teams/\(teamId)/leave", "/teams/\(teamId)/leave"],
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

    // MARK: - Matches

    func createMatch(_ req: CreateMatchRequest) async throws -> MatchResponse {
        try await request(
            endpoint: "/api/matches",
            method: "POST",
            body: req
        )
    }

    func getUpcomingMatches() async throws -> MatchListResponse {
        try await request(endpoint: "/api/matches")
    }

    func getMatchDetail(matchId: String) async throws -> MatchDetailResponse {
        try await request(endpoint: "/api/matches/\(matchId)")
    }

    func registerForMatch(matchId: String, groupColor: String = "") async throws -> MessageResponse {
        try await request(
            endpoint: "/api/matches/\(matchId)/register",
            method: "POST",
            body: RegisterMatchBody(groupColor: groupColor)
        )
    }

    func cancelMatchRegistration(matchId: String) async throws -> MessageResponse {
        try await request(
            endpoint: "/api/matches/\(matchId)/cancel",
            method: "POST"
        )
    }

    func deleteMatch(matchId: String) async throws -> MessageResponse {
        try await request(
            endpoint: "/api/matches/\(matchId)",
            method: "DELETE"
        )
    }

    func getMatchRankings(matchId: String) async throws -> MatchRankingsResponse {
        try await request(endpoint: "/api/matches/\(matchId)/rankings")
    }

    func getMatchSummary(matchId: String) async throws -> MatchSummaryResponse {
        try await request(endpoint: "/api/matches/\(matchId)/summary")
    }
}
