import Foundation
import SwiftUI

private let kTokenKey = "auth_token"
private let kUidKey = "auth_uid"
private let kMatchesCacheKey = "cached_upcoming_matches"
private let kTeamsCacheKey = "cached_teams"
private let kTeamDetailCacheKey = "cached_team_detail"

@MainActor
class AuthManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentUid: String?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var userProfile: UserProfileResponse?
    @Published var teams: [TeamResponse] = []
    @Published var earnedBadges: EarnedBadgesResponse?
    @Published var upcomingMatches: [MatchResponse] = []

    private var profileLoadedAt: Date?
    private var teamsLoadedAt: Date?
    private var badgesLoadedAt: Date?
    private var matchesLoadedAt: Date?
    private var teamDetailsById: [String: TeamDetailResponse] = [:]
    private var teamDetailsLoadedAt: [String: Date] = [:]
    private let cacheTTL: TimeInterval = 300

    init() {
        let token = UserDefaults.standard.string(forKey: kTokenKey)
        let uid = UserDefaults.standard.string(forKey: kUidKey)
        if let token = token, !token.isEmpty {
            ApiClient.shared.token = token
            currentUid = uid
            isLoggedIn = true
        }
        // Restore cached matches so HomeView renders instantly
        if let data = UserDefaults.standard.data(forKey: kMatchesCacheKey),
           let cached = try? JSONDecoder().decode([MatchResponse].self, from: data) {
            upcomingMatches = cached
        }
        // Restore cached teams so TeamHubView renders instantly
        if let data = UserDefaults.standard.data(forKey: kTeamsCacheKey),
           let cached = try? JSONDecoder().decode([TeamResponse].self, from: data) {
            teams = cached
        }
        if let data = UserDefaults.standard.data(forKey: kTeamDetailCacheKey),
           let cached = try? JSONDecoder().decode([String: TeamDetailResponse].self, from: data) {
            teamDetailsById = cached
        }
    }

    func login(username: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await loginWithRetry(username: username, password: password)
            saveAuth(token: response.token, uid: response.uid)
            await preloadData()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func register(username: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await registerWithRetry(username: username, password: password)
            saveAuth(token: response.token, uid: response.uid)
            await preloadData()
            isLoading = false
            return response.isNewUser
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    private func loginWithRetry(username: String, password: String) async throws -> AuthResponse {
        do {
            return try await ApiClient.shared.login(username: username, password: password)
        } catch let ApiError.networkError(_) {
            // First install may fail due to iOS network permission prompt; retry once
            try await Task.sleep(nanoseconds: 1_500_000_000)
            return try await ApiClient.shared.login(username: username, password: password)
        }
    }

    private func registerWithRetry(username: String, password: String) async throws -> AuthResponse {
        do {
            return try await ApiClient.shared.register(username: username, password: password)
        } catch let ApiError.networkError(_) {
            try await Task.sleep(nanoseconds: 1_500_000_000)
            return try await ApiClient.shared.register(username: username, password: password)
        }
    }

    /// Preload profile, teams, badges, matches so views render instantly
    func preloadData() async {
        async let p: () = loadProfileIfNeeded()
        async let t: () = loadTeamsIfNeeded()
        async let b: () = loadBadgesIfNeeded()
        async let m: () = loadMatchesIfNeeded()
        _ = await (p, t, b, m)
    }

    func logout() {
        UserDefaults.standard.removeObject(forKey: kTokenKey)
        UserDefaults.standard.removeObject(forKey: kUidKey)
        ApiClient.shared.token = nil
        currentUid = nil
        userProfile = nil
        teams = []
        earnedBadges = nil
        upcomingMatches = []
        profileLoadedAt = nil
        teamsLoadedAt = nil
        badgesLoadedAt = nil
        matchesLoadedAt = nil
        teamDetailsById = [:]
        teamDetailsLoadedAt = [:]
        withAnimation(.easeInOut(duration: 0.35)) {
            isLoggedIn = false
        }
        UserDefaults.standard.removeObject(forKey: kMatchesCacheKey)
        UserDefaults.standard.removeObject(forKey: kTeamsCacheKey)
        UserDefaults.standard.removeObject(forKey: kTeamDetailCacheKey)
    }

    func loadProfile() async {
        do {
            userProfile = try await ApiClient.shared.getProfile()
            profileLoadedAt = Date()
        } catch {
            // Silently handle — views show placeholder
        }
    }

    func loadProfileIfNeeded() async {
        if let loadedAt = profileLoadedAt, Date().timeIntervalSince(loadedAt) < cacheTTL, userProfile != nil {
            return
        }
        await loadProfile()
    }

    func loadTeamsIfNeeded(forceRefresh: Bool = false) async {
        if !forceRefresh,
           let loadedAt = teamsLoadedAt,
           Date().timeIntervalSince(loadedAt) < cacheTTL {
            return
        }
        do {
            let resp = try await ApiClient.shared.getTeams()
            teams = resp.teams.sorted { $0.createdAt > $1.createdAt }
            teamsLoadedAt = Date()
            persistTeams()
        } catch {
            // Silently handle
        }
    }

    func loadBadgesIfNeeded() async {
        if let loadedAt = badgesLoadedAt, Date().timeIntervalSince(loadedAt) < cacheTTL, earnedBadges != nil {
            return
        }
        do {
            earnedBadges = try await ApiClient.shared.getEarnedBadges()
            badgesLoadedAt = Date()
        } catch {
            // Silently handle
        }
    }

    func invalidateTeams() {
        teamsLoadedAt = nil
        invalidateAllTeamDetails()
    }

    func invalidateBadges() {
        badgesLoadedAt = nil
    }

    func loadMatchesIfNeeded(forceRefresh: Bool = false) async {
        if !forceRefresh,
           let loadedAt = matchesLoadedAt,
           Date().timeIntervalSince(loadedAt) < cacheTTL {
            return
        }
        do {
            let resp = try await ApiClient.shared.getUpcomingMatches()
            upcomingMatches = resp.matches
            matchesLoadedAt = Date()
            persistMatches()
        } catch {
            // Silently handle
        }
    }

    func invalidateMatches() {
        matchesLoadedAt = nil
    }

    private func persistMatches() {
        if let data = try? JSONEncoder().encode(upcomingMatches) {
            UserDefaults.standard.set(data, forKey: kMatchesCacheKey)
        }
    }

    private func persistTeams() {
        if let data = try? JSONEncoder().encode(teams) {
            UserDefaults.standard.set(data, forKey: kTeamsCacheKey)
        }
    }

    private func persistTeamDetails() {
        if let data = try? JSONEncoder().encode(teamDetailsById) {
            UserDefaults.standard.set(data, forKey: kTeamDetailCacheKey)
        }
    }

    func loadTeamDetailIfNeeded(teamId: String, forceRefresh: Bool = false) async -> TeamDetailResponse? {
        if !forceRefresh,
           let loadedAt = teamDetailsLoadedAt[teamId],
           Date().timeIntervalSince(loadedAt) < cacheTTL,
           let cached = teamDetailsById[teamId] {
            return cached
        }

        do {
            let detail = try await ApiClient.shared.getTeamDetail(teamId: teamId)
            teamDetailsById[teamId] = detail
            teamDetailsLoadedAt[teamId] = Date()
            persistTeamDetails()
            return detail
        } catch {
            return teamDetailsById[teamId]
        }
    }

    func invalidateTeamDetail(teamId: String) {
        teamDetailsLoadedAt[teamId] = nil
    }

    func getCachedTeamDetail(teamId: String) -> TeamDetailResponse? {
        teamDetailsById[teamId]
    }

    func invalidateAllTeamDetails() {
        teamDetailsById = [:]
        teamDetailsLoadedAt = [:]
    }

    func refreshProfileTimestamp() {
        profileLoadedAt = Date()
    }

    private func saveAuth(token: String, uid: String) {
        UserDefaults.standard.set(token, forKey: kTokenKey)
        UserDefaults.standard.set(uid, forKey: kUidKey)
        ApiClient.shared.token = token
        currentUid = uid
        withAnimation(.easeInOut(duration: 0.35)) {
            isLoggedIn = true
        }
    }
}
