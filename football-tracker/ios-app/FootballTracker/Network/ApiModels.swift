import Foundation

// MARK: - Auth

struct LoginRequest: Encodable {
    let username: String
    let password: String
}

struct RegisterRequest: Encodable {
    let username: String
    let password: String
}

struct AuthResponse: Decodable {
    let token: String
    let uid: String
    let isNewUser: Bool
}

// MARK: - User

struct UserProfileResponse: Decodable {
    let uid: String
    let phone: String?
    let wechatOpenId: String?
    let username: String?
    let nickname: String
    let weightKg: Double
    let age: Int
    let authProvider: String
    let createdAt: Int64
}

struct UpdateProfileRequest: Encodable {
    let nickname: String?
    let weightKg: Double?
    let age: Int?
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

// MARK: - Teams

struct CreateTeamRequest: Encodable {
    let name: String
}

struct JoinTeamRequest: Encodable {
    let inviteCode: String
}

struct TeamResponse: Decodable {
    let id: String
    let name: String
    let inviteCode: String
    let createdBy: String
    let createdAt: Int64
}

struct TeamListResponse: Decodable {
    let teams: [TeamResponse]
}

struct TeamMemberResponse: Decodable {
    let userUid: String
    let nickname: String
    let role: String
    let joinedAt: Int64
    let sessionCount: Int64
    let totalDistanceMeters: Double
}

struct TeamDetailResponse: Decodable {
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
