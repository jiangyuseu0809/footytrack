import Foundation

// MARK: - Notification Names

extension Notification.Name {
    static let matchCreated = Notification.Name("matchCreated")
    static let sessionRecorded = Notification.Name("sessionRecorded")
}

// MARK: - Auth

struct LoginRequest: Encodable {
    let username: String
    let password: String
}

struct RegisterRequest: Encodable {
    let username: String
    let password: String
}

struct WeChatAppLoginRequest: Encodable {
    let code: String
}

struct AuthResponse: Decodable {
    let token: String
    let uid: String
    let isNewUser: Bool
}

// MARK: - User

struct UserProfileResponse: Codable {
    let uid: String
    let phone: String?
    let wechatOpenId: String?
    let username: String?
    let nickname: String
    let weightKg: Double
    let age: Int
    let avatarUrl: String?
    let authProvider: String
    let createdAt: Int64
}

struct UpdateProfileRequest: Encodable {
    let nickname: String?
    let weightKg: Double?
    let age: Int?
}

struct AvatarUploadResponse: Decodable {
    let avatarUrl: String
}

// MARK: - Sessions

struct SessionDto: Codable {
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
    var goals: Int?
    var assists: Int?
    var locationName: String?
}

struct SyncRequest: Encodable {
    let sessions: [SessionDto]
}

struct SyncResponse: Decodable {
    let synced: Int
}

struct SessionListResponse: Decodable {
    let sessions: [SessionDto]
}

// MARK: - Generic

struct MessageResponse: Decodable {
    let message: String?
    let error: String?
}

// MARK: - Player Analysis

struct PlayerAnalysisResponse: Codable {
    let type: String
    let description: String
    let strengths: [String]
    let advice: String
}

struct SessionSummaryRequest: Encodable {
    let sessionId: String
    let durationMinutes: Int
    let distanceKm: Double
    let maxSpeedKmh: Double
    let sprintCount: Int
    let caloriesBurned: Double
    let avgHeartRate: Int
    let goals: Int
    let assists: Int
    let coveragePercent: Double
}

// MARK: - Teams

struct CreateTeamRequest: Encodable {
    let name: String
}

struct JoinTeamRequest: Encodable {
    let inviteCode: String
}

struct UpdateTeamRequest: Encodable {
    let name: String
}

struct TeamPreviewResponse: Decodable {
    let teamName: String
    let memberCount: Int
    let ownerNickname: String
}

struct TeamResponse: Codable {
    let id: String
    let name: String
    let inviteCode: String
    let createdBy: String
    let createdAt: Int64
}

struct TeamListResponse: Codable {
    let teams: [TeamResponse]
}

struct TeamMemberResponse: Codable {
    let userUid: String
    let nickname: String
    let role: String
    let joinedAt: Int64
    let sessionCount: Int64
    let totalDistanceMeters: Double
    var totalGoals: Int64?
    var totalAssists: Int64?
    var avatarUrl: String?
}

struct TeamDetailResponse: Codable {
    let team: TeamResponse
    let members: [TeamMemberResponse]
}

// MARK: - Badges

struct BadgeResponse: Decodable {
    let id: String
    let name: String
    let description: String
    let iconName: String
    let criteriaType: String
    let criteriaValue: Double
}

struct UserBadgeResponse: Decodable {
    let badge: BadgeResponse
    let earnedAt: Int64
}

struct EarnedBadgesResponse: Decodable {
    let allBadges: [BadgeResponse]
    let earnedBadges: [UserBadgeResponse]
}

struct CheckBadgesResponse: Decodable {
    let newBadges: [BadgeResponse]
}

// MARK: - Matches

struct CreateMatchRequest: Encodable {
    let title: String
    let matchDate: Int64
    let location: String
    let groups: Int
    let playersPerGroup: Int
    let groupColors: String
}

struct MatchResponse: Codable, Identifiable {
    let id: String
    let creatorUid: String
    let title: String
    let matchDate: Int64
    let location: String
    let groups: Int
    let playersPerGroup: Int
    let groupColors: String
    let status: String
    let registrationCount: Int64
    let createdAt: Int64
}

struct MatchListResponse: Decodable {
    let matches: [MatchResponse]
}

struct MatchRegistrationResponse: Decodable, Identifiable {
    let userUid: String
    let nickname: String
    let groupColor: String
    let registeredAt: Int64

    var id: String { userUid }
}

struct MatchDetailResponse: Decodable {
    let match: MatchResponse
    let registrations: [MatchRegistrationResponse]
    let isRegistered: Bool
}

struct RegisterMatchBody: Encodable {
    let groupColor: String
}

struct PlayerRankItem: Decodable, Identifiable {
    let userUid: String
    let nickname: String
    let groupColor: String
    let value: Double

    var id: String { userUid }
}

struct MatchRankingsResponse: Decodable {
    let caloriesRanking: [PlayerRankItem]
    let distanceRanking: [PlayerRankItem]
}

struct MatchSummaryResponse: Decodable {
    let summary: String
}

struct SessionSummaryResponse: Codable {
    let summary: String
    let highlights: [String]
    let improvements: [String]
}

// MARK: - Pricing

struct PlanResponse: Decodable {
    let id: String
    let name: String
    let price: Double
    let originalPrice: Double?
    let period: String
    let discount: Int?
    let popular: Bool
}

struct PricingResponse: Decodable {
    let plans: [PlanResponse]
    let trialDays: Int
}
