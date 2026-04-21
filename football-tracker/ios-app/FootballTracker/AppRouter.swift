import SwiftUI

/// Centralized navigation router. Secondary pages are pushed onto the root
/// NavigationStack that wraps the TabView, so they naturally cover the tab bar.
final class AppRouter: ObservableObject {
    @Published var path = NavigationPath()
    @Published var pendingInviteCode: String? = nil

    func push<V: Hashable>(_ route: V) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }
}

/// All secondary-page routes in the app.
enum AppRoute: Hashable {
    // From HomeView
    case sessionDetail(sessionId: String)
    case matchDetail(matchId: String)
    case weeklySummary
    case todaySessionsList(sessionIds: [String])

    // From TeamHubView
    case teamMemberList
    case teamList
    case teamDetail(teamId: String)

    // From StatsView
    case allMatches
    case daySummary(daySectionId: String)

    // From ProfileView
    case proSubscription
    case settings
    case sessionNotifications
}
