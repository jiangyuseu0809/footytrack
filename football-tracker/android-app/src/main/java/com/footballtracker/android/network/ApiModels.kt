package com.footballtracker.android.network

import kotlinx.serialization.Serializable

// ── Auth ──

@Serializable
data class SmsSendRequest(val phone: String)

@Serializable
data class SmsVerifyRequest(val phone: String, val code: String)

@Serializable
data class WeChatAuthRequest(val code: String)

@Serializable
data class RegisterRequest(val username: String, val password: String)

@Serializable
data class LoginRequest(val username: String, val password: String)

@Serializable
data class AuthResponse(val token: String, val uid: String, val isNewUser: Boolean)

// ── User ──

@Serializable
data class UserProfileResponse(
    val uid: String,
    val phone: String? = null,
    val wechatOpenId: String? = null,
    val username: String? = null,
    val nickname: String,
    val weightKg: Double,
    val age: Int,
    val authProvider: String,
    val createdAt: Long
)

@Serializable
data class UpdateProfileRequest(
    val nickname: String? = null,
    val weightKg: Double? = null,
    val age: Int? = null
)

// ── Sessions ──

@Serializable
data class SessionDto(
    val id: String,
    val startTime: Long,
    val endTime: Long,
    val playerWeightKg: Double? = null,
    val playerAge: Int? = null,
    val totalDistanceMeters: Double? = null,
    val avgSpeedKmh: Double? = null,
    val maxSpeedKmh: Double? = null,
    val sprintCount: Int? = null,
    val highIntensityDistanceMeters: Double? = null,
    val avgHeartRate: Int? = null,
    val maxHeartRate: Int? = null,
    val caloriesBurned: Double? = null,
    val slackIndex: Int? = null,
    val slackLabel: String? = null,
    val coveragePercent: Double? = null
)

@Serializable
data class SyncRequest(val sessions: List<SessionDto>)

@Serializable
data class SyncResponse(val synced: Int)

@Serializable
data class SessionListResponse(val sessions: List<SessionDto>)

// ── Generic ──

@Serializable
data class MessageResponse(val message: String? = null, val error: String? = null)

// ── Teams ──

@Serializable
data class CreateTeamRequest(val name: String)

@Serializable
data class JoinTeamRequest(val inviteCode: String)

@Serializable
data class TeamResponse(
    val id: String,
    val name: String,
    val inviteCode: String,
    val createdBy: String,
    val createdAt: Long
)

@Serializable
data class TeamListResponse(val teams: List<TeamResponse>)

@Serializable
data class TeamMemberResponse(
    val userUid: String,
    val nickname: String,
    val role: String,
    val joinedAt: Long,
    val sessionCount: Long,
    val totalDistanceMeters: Double
)

@Serializable
data class TeamDetailResponse(
    val team: TeamResponse,
    val members: List<TeamMemberResponse>
)

// ── Badges ──

@Serializable
data class BadgeResponse(
    val id: String,
    val name: String,
    val description: String,
    val iconName: String,
    val criteriaType: String,
    val criteriaValue: Double
)

@Serializable
data class UserBadgeResponse(
    val badge: BadgeResponse,
    val earnedAt: Long
)

@Serializable
data class EarnedBadgesResponse(
    val allBadges: List<BadgeResponse>,
    val earnedBadges: List<UserBadgeResponse>
)

@Serializable
data class CheckBadgesResponse(
    val newBadges: List<BadgeResponse>
)
