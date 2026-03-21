import SwiftUI
import UserNotifications

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
                        if WatchSync.parseWatchData(data, store: sessionStore),
                           let sessionId = data["session_id"] as? String {
                            WatchSync.shared.removePendingUserInfo(sessionId: sessionId)
                        }
                    }
                }
            }
            .task {
                await MainActor.run {
                    WatchSync.shared.flushPendingUserInfo(to: sessionStore)
                }
            }
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var authManager: AuthManager
    @State private var unreadCount = UserDefaults.standard.integer(forKey: "unread_session_count")

    var body: some View {
        TabView {
            NavigationStack {
                HomeView(store: store, authManager: authManager)
            }
            .tabItem {
                Image(systemName: "sportscourt.fill")
                Text("首页")
            }

            NavigationStack {
                TeamHubView(authManager: authManager, store: store)
            }
            .tabItem {
                Image(systemName: "flag.fill")
                Text("球队")
            }

            NavigationStack {
                StatsView(store: store, authManager: authManager)
            }
            .tabItem {
                Image(systemName: "chart.bar.fill")
                Text("统计")
            }

            NavigationStack {
                ProfileView(store: store, authManager: authManager)
            }
            .tabItem {
                Image(systemName: "person.fill")
                Text("我的")
            }
            .badge(unreadCount > 0 ? unreadCount : 0)
        }
        .tint(AppColors.neonBlue)
        .task {
            if authManager.isLoggedIn {
                _ = try? await CloudSync.uploadPendingSessions(store: store, authManager: authManager)
            }
            await authManager.preloadData()
            // Request notification permission
            let center = UNUserNotificationCenter.current()
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionRecorded)) { _ in
            unreadCount = UserDefaults.standard.integer(forKey: "unread_session_count")
        }
    }
}

// MARK: - Team Hub

struct TeamHubView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var store: SessionStore
    @State private var teamDetail: TeamDetailResponse?
    @State private var isLoading = true

    private var team: TeamResponse? {
        teamDetail?.team ?? authManager.teams.first
    }

    private var teamMembers: [TeamMemberResponse] {
        teamDetail?.members ?? []
    }

    private var hasTeam: Bool {
        team != nil
    }

    private var teamCreatedDateText: String {
        guard let ts = team?.createdAt else { return "--" }
        let date = Date(timeIntervalSince1970: TimeInterval(ts) / 1000.0)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private var averageSessions: Double {
        guard !teamMembers.isEmpty else { return 0 }
        let sum = teamMembers.reduce(0) { $0 + $1.sessionCount }
        return Double(sum) / Double(teamMembers.count)
    }

    private var averageDistanceKm: Double {
        guard !teamMembers.isEmpty else { return 0 }
        return teamMembers.reduce(0) { $0 + $1.totalDistanceMeters } / Double(teamMembers.count) / 1000
    }

    private var attendanceBoard: [TeamLeaderItem] {
        teamMembers
            .sorted { $0.sessionCount > $1.sessionCount }
            .prefix(3)
            .enumerated()
            .map { idx, m in
                TeamLeaderItem(name: displayName(m), value: "\(m.sessionCount) 场", avatar: avatarText(m), rank: idx + 1)
            }
    }

    private var distanceBoard: [TeamLeaderItem] {
        teamMembers
            .sorted { $0.totalDistanceMeters > $1.totalDistanceMeters }
            .prefix(3)
            .enumerated()
            .map { idx, m in
                TeamLeaderItem(name: displayName(m), value: String(format: "%.1f km", m.totalDistanceMeters / 1000), avatar: avatarText(m), rank: idx + 1)
            }
    }


    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(AppColors.neonBlue)
            } else if hasTeam {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        teamInfoCard
                        squadSection
                        leaderboardsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
                .refreshable {
                    await refreshTeamData()
                }
            } else {
                noTeamState
            }
        }
        .navigationTitle("球队")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleDisplayMode(.inline)
        .task {
            await loadTeamData()
        }
    }

    private var teamInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(team?.name ?? "我的球队")
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)
                    Text("成立于 \(teamCreatedDateText)")
                        .font(.caption)
                        .foregroundColor(Color.white.opacity(0.85))
                }

                Spacer()

                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(Text("⚡").font(.title3))
            }

            HStack(spacing: 0) {
                teamStatItem(value: "\(teamMembers.count)", label: "成员")
                teamStatItem(value: String(format: "%.1f", averageSessions), label: "平均场次")
                teamStatItem(value: String(format: "%.1f", averageDistanceKm), label: "平均距离")
            }
            .padding(.top, 8)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 1)
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x3B82F6), Color(hex: 0x4F46E5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(18)
    }

    private var squadSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("阵容")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                NavigationLink(destination: TeamListView(authManager: authManager)) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("添加")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColors.neonBlue)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(teamMembers.enumerated()), id: \.element.userUid) { index, member in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(AppColors.cardBgLight)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Text(avatarText(member))
                                    .font(.title3)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayName(member))
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(AppColors.textPrimary)
                            Text(member.role == "owner" ? "队长" : "成员")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        HStack(spacing: 3) {
                            Text("★")
                                .foregroundColor(Color(hex: 0xFBBF24))
                            Text(String(format: "%.1f", memberRating(member)))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppColors.textPrimary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)

                    if index < teamMembers.count - 1 {
                        Divider().overlay(AppColors.dividerColor.opacity(0.6))
                    }
                }
            }
            .background(AppColors.cardBg)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
    }

    private var leaderboardsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("排行榜")
                .font(.title3.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)

            VStack(spacing: 12) {
                leaderboardCard(title: "出勤榜", icon: "calendar", colors: [Color(hex: 0xF59E0B), Color(hex: 0xF97316)], items: attendanceBoard)
                leaderboardCard(title: "跑动王者", icon: "bolt.fill", colors: [Color(hex: 0xA855F7), Color(hex: 0xEC4899)], items: distanceBoard)
            }
        }
    }

    private func leaderboardCard(title: String, icon: String, colors: [Color], items: [TeamLeaderItem]) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(12)
            .background(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))

            VStack(spacing: 0) {
                if items.isEmpty {
                    Text("暂无数据")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                } else {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 10) {
                            Text(rankEmoji(item.rank))
                                .frame(width: 28)
                            Circle()
                                .fill(AppColors.cardBgLight)
                                .frame(width: 34, height: 34)
                                .overlay(Text(item.avatar).font(.body))
                            Text(item.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Text(item.value)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)

                        if index < items.count - 1 {
                            Divider().overlay(AppColors.dividerColor.opacity(0.6))
                        }
                    }
                }
            }
            .background(AppColors.cardBg)
        }
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var noTeamState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 12) {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 74, height: 74)
                        .overlay(Text("⚽️").font(.system(size: 36)))

                    Text("暂无球队")
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)

                    Text("创建球队或加入已有球队，开始查看成员表现与排行榜。")
                        .font(.subheadline)
                        .foregroundColor(Color.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .padding(18)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [Color(hex: 0x3B82F6), Color(hex: 0x4F46E5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(18)

                featureRow(icon: "person.3.fill", title: "组建阵容", desc: "邀请队友并管理球队成员")
                featureRow(icon: "trophy.fill", title: "查看排行", desc: "统计出勤和跑动数据")
                featureRow(icon: "chart.line.uptrend.xyaxis", title: "一起进步", desc: "通过数据追踪团队表现")

                NavigationLink(destination: TeamListView(authManager: authManager)) {
                    Text("创建或加入球队")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LinearGradient(colors: [Color(hex: 0x3B82F6), Color(hex: 0x4F46E5)], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
    }

    private func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.neonBlue.opacity(0.18))
                .frame(width: 42, height: 42)
                .overlay(
                    Image(systemName: icon)
                        .foregroundColor(AppColors.neonBlue)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                Text(desc)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(AppColors.cardBg)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    private func displayName(_ member: TeamMemberResponse) -> String {
        member.nickname.isEmpty ? "球员" : member.nickname
    }

    private func avatarText(_ member: TeamMemberResponse) -> String {
        member.role == "owner" ? "👑" : "⚽️"
    }

    private func memberRating(_ member: TeamMemberResponse) -> Double {
        let distanceScore = min(1.0, (member.totalDistanceMeters / 1000.0) / 80.0)
        let attendanceScore = min(1.0, Double(member.sessionCount) / 30.0)
        return 6.8 + (distanceScore * 1.0 + attendanceScore * 0.7)
    }

    private func rankEmoji(_ rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(rank)"
        }
    }

    private func teamStatItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }

    private func loadTeamData() async {
        await authManager.loadTeamsIfNeeded()

        if let firstTeam = authManager.teams.first {
            teamDetail = await authManager.loadTeamDetailIfNeeded(teamId: firstTeam.id)
        } else {
            teamDetail = nil
        }

        isLoading = false
    }

    private func refreshTeamData() async {
        _ = try? await CloudSync.uploadPendingSessions(store: store, authManager: authManager)
        await authManager.loadTeamsIfNeeded(forceRefresh: true)

        if let firstTeam = authManager.teams.first {
            teamDetail = await authManager.loadTeamDetailIfNeeded(teamId: firstTeam.id, forceRefresh: true)
        } else {
            teamDetail = nil
        }
    }
}

private struct TeamLeaderItem: Identifiable {
    let id = UUID()
    let name: String
    let value: String
    let avatar: String
    let rank: Int
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
