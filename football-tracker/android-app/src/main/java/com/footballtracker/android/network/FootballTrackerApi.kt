package com.footballtracker.android.network

import retrofit2.http.*

interface FootballTrackerApi {

    // ── Auth ──

    @POST("api/auth/sms/send")
    suspend fun sendSmsCode(@Body request: SmsSendRequest): MessageResponse

    @POST("api/auth/sms/verify")
    suspend fun verifySmsCode(@Body request: SmsVerifyRequest): AuthResponse

    @POST("api/auth/wechat")
    suspend fun wechatAuth(@Body request: WeChatAuthRequest): AuthResponse

    @POST("api/auth/register")
    suspend fun register(@Body request: RegisterRequest): AuthResponse

    @POST("api/auth/login")
    suspend fun login(@Body request: LoginRequest): AuthResponse

    // ── User ──

    @GET("api/user/profile")
    suspend fun getProfile(): UserProfileResponse

    @PUT("api/user/profile")
    suspend fun updateProfile(@Body request: UpdateProfileRequest): UserProfileResponse

    // ── Sessions ──

    @POST("api/sessions/sync")
    suspend fun syncSessions(@Body request: SyncRequest): SyncResponse

    @GET("api/sessions")
    suspend fun getSessions(): SessionListResponse

    // ── Teams ──

    @POST("api/teams")
    suspend fun createTeam(@Body request: CreateTeamRequest): TeamResponse

    @GET("api/teams")
    suspend fun getTeams(): TeamListResponse

    @GET("api/teams/{teamId}")
    suspend fun getTeamDetail(@Path("teamId") teamId: String): TeamDetailResponse

    @POST("api/teams/{teamId}/join")
    suspend fun joinTeamById(@Path("teamId") teamId: String): MessageResponse

    @POST("api/teams/join")
    suspend fun joinTeamByCode(@Body request: JoinTeamRequest): TeamResponse

    @POST("api/teams/{teamId}/leave")
    suspend fun leaveTeam(@Path("teamId") teamId: String): MessageResponse

    // ── Badges ──

    @GET("api/badges/earned")
    suspend fun getEarnedBadges(): EarnedBadgesResponse

    @POST("api/badges/check")
    suspend fun checkBadges(): CheckBadgesResponse

    // ── Matches ──

    @POST("api/matches")
    suspend fun createMatch(@Body request: CreateMatchRequest): MatchResponse

    @GET("api/matches")
    suspend fun getMatches(): MatchListResponse

    @GET("api/matches/{matchId}")
    suspend fun getMatchDetail(@Path("matchId") matchId: String): MatchDetailResponse

    @POST("api/matches/{matchId}/register")
    suspend fun registerForMatch(
        @Path("matchId") matchId: String,
        @Body body: RegisterMatchBody
    ): MessageResponse

    @POST("api/matches/{matchId}/cancel")
    suspend fun cancelMatchRegistration(@Path("matchId") matchId: String): MessageResponse

    @DELETE("api/matches/{matchId}")
    suspend fun deleteMatch(@Path("matchId") matchId: String): MessageResponse

    @GET("api/matches/{matchId}/rankings")
    suspend fun getMatchRankings(@Path("matchId") matchId: String): MatchRankingsResponse

    @GET("api/matches/{matchId}/summary")
    suspend fun getMatchSummary(@Path("matchId") matchId: String): MatchSummaryResponse

    // ── Player Analysis ──

    @GET("api/sessions/analysis")
    suspend fun getPlayerAnalysis(): PlayerAnalysisResponse
}
