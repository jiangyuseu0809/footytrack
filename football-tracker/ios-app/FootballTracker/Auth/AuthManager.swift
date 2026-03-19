import Foundation

private let kTokenKey = "auth_token"
private let kUidKey = "auth_uid"

@MainActor
class AuthManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentUid: String?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var userProfile: UserProfileResponse?
    @Published var teams: [TeamResponse] = []
    @Published var earnedBadges: EarnedBadgesResponse?

    private var profileLoadedAt: Date?
    private var teamsLoadedAt: Date?
    private var badgesLoadedAt: Date?
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
    }

    func login(username: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await ApiClient.shared.login(username: username, password: password)
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
            let response = try await ApiClient.shared.register(username: username, password: password)
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

    /// Preload profile, teams, badges so views render instantly
    func preloadData() async {
        async let p: () = loadProfileIfNeeded()
        async let t: () = loadTeamsIfNeeded()
        async let b: () = loadBadgesIfNeeded()
        _ = await (p, t, b)
    }

    func logout() {
        UserDefaults.standard.removeObject(forKey: kTokenKey)
        UserDefaults.standard.removeObject(forKey: kUidKey)
        ApiClient.shared.token = nil
        currentUid = nil
        userProfile = nil
        teams = []
        earnedBadges = nil
        profileLoadedAt = nil
        teamsLoadedAt = nil
        badgesLoadedAt = nil
        teamDetailsById = [:]
        teamDetailsLoadedAt = [:]
        isLoggedIn = false
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
            teams = resp.teams
            teamsLoadedAt = Date()
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
            return detail
        } catch {
            return teamDetailsById[teamId]
        }
    }

    func invalidateTeamDetail(teamId: String) {
        teamDetailsLoadedAt[teamId] = nil
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
        isLoggedIn = true
    }
}
