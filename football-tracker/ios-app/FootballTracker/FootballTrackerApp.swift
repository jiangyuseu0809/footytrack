import SwiftUI

@main
struct FootballTrackerApp: App {
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var authManager = AuthManager()

    init() {
        // Activate WCSession early so watch state is available
        _ = WatchSync.shared
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isLoggedIn {
                    MainTabView(store: sessionStore, authManager: authManager)
                } else {
                    AuthFlowView(authManager: authManager, store: sessionStore)
                }
            }
            .preferredColorScheme(.dark)
            .onReceive(NotificationCenter.default.publisher(for: WatchSync.didReceiveDataNotification)) { notification in
                if let data = notification.userInfo as? [String: Any] {
                    Task { @MainActor in
                        WatchSync.parseWatchData(data, store: sessionStore)
                    }
                }
            }
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var authManager: AuthManager

    var body: some View {
        TabView {
            NavigationStack {
                HomeView(store: store)
            }
            .tabItem {
                Image(systemName: "sportscourt.fill")
                Text("首页")
            }

            NavigationStack {
                StatsView(store: store)
            }
            .tabItem {
                Image(systemName: "chart.bar.fill")
                Text("统计")
            }

            NavigationStack {
                ProfileView(store: store)
            }
            .tabItem {
                Image(systemName: "person.fill")
                Text("我的")
            }

            NavigationStack {
                SettingsView(store: store, authManager: authManager)
            }
            .tabItem {
                Image(systemName: "gearshape.fill")
                Text("设置")
            }
        }
        .tint(AppColors.neonBlue)
    }
}

// MARK: - Auth Flow

struct AuthFlowView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var store: SessionStore

    var body: some View {
        NavigationStack {
            LoginView(authManager: authManager)
        }
    }
}
