import SwiftUI
import UserNotifications

// MARK: - AppDelegate for foreground notifications + WeChat SDK

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        WeChatManager.shared.register()
        return true
    }

    /// Show notification banner even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    /// Handle URL Scheme callback from WeChat
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return WeChatManager.shared.handleOpenURL(url)
    }

    /// Handle Universal Link callback from WeChat
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        return WeChatManager.shared.handleOpenUniversalLink(userActivity)
    }
}

@main
struct FootballTrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var authManager = AuthManager()

    init() {
        // Activate WCSession early so watch state is available
        _ = WatchSync.shared
    }

    var body: some Scene {
        WindowGroup {
            MainTabView(store: sessionStore, authManager: authManager)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    print("[WeChat] onOpenURL: \(url)")
                    _ = WeChatManager.shared.handleOpenURL(url)
                }
                .onReceive(NotificationCenter.default.publisher(for: WatchSync.didReceiveDataNotification)) { notification in
                    if let data = notification.userInfo as? [String: Any] {
                        Task { @MainActor in
                            if WatchSync.parseWatchData(data, store: sessionStore, ownerUid: authManager.effectiveUid),
                               let sessionId = data["session_id"] as? String {
                                WatchSync.shared.removePendingUserInfo(sessionId: sessionId)
                            }
                        }
                    }
                }
                .task {
                    await MainActor.run {
                        WatchSync.shared.flushPendingUserInfo(to: sessionStore, ownerUid: authManager.effectiveUid)
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
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(store: store, authManager: authManager)
            }
            .tabItem {
                Image(systemName: "sportscourt.fill")
                Text("首页")
            }
            .tag(0)

            NavigationStack {
                TeamHubView(authManager: authManager, store: store)
            }
            .tabItem {
                Image(systemName: "flag.fill")
                Text("球队")
            }
            .tag(1)

            NavigationStack {
                StatsView(store: store, authManager: authManager)
            }
            .tabItem {
                Image(systemName: "chart.bar.fill")
                Text("统计")
            }
            .tag(2)

            NavigationStack {
                ProfileView(store: store, authManager: authManager)
            }
            .tabItem {
                Image(systemName: "person.fill")
                Text("我的")
            }
            .badge(unreadCount > 0 ? unreadCount : 0)
            .tag(3)
        }
        .tint(AppColors.neonBlue)
        .task {
            if authManager.isLoggedIn {
                // First install: pull cloud data if local is empty
                if store.sessions.isEmpty {
                    _ = try? await CloudSync.pullFromCloud(store: store, authManager: authManager)
                }
                _ = try? await CloudSync.uploadPendingSessions(store: store, authManager: authManager)
                await authManager.preloadData()
            }
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
    @State private var showLeaveAlert = false
    @State private var isLeaving = false
    @State private var showMemberList = false
    @State private var isEditingTeamName = false
    @State private var editedTeamName = ""

    private var team: TeamResponse? {
        teamDetail?.team ?? authManager.teams.first
    }

    private var teamMembers: [TeamMemberResponse] {
        teamDetail?.members ?? []
    }

    private var hasTeam: Bool {
        team != nil
    }

    private var isOwner: Bool {
        team?.createdBy == authManager.currentUid
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

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            if !authManager.isLoggedIn {
                loginRequiredState
            } else if isLoading {
                ProgressView()
                    .tint(AppColors.neonBlue)
            } else if hasTeam {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        teamInfoCard
                        TeamLeaderboardSection(
                            members: teamMembers,
                            currentUserUid: authManager.currentUid,
                            currentUserAvatarUrl: authManager.userProfile?.avatarUrl,
                            localGoals: Int64(store.sessions.reduce(0) { $0 + $1.goals }),
                            localAssists: Int64(store.sessions.reduce(0) { $0 + $1.assists })
                        )
                        leaveTeamSection
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
        .navigationDestination(isPresented: $showMemberList) {
            TeamMemberListView(
                members: teamMembers,
                currentUserUid: authManager.currentUid,
                currentUserAvatarUrl: authManager.userProfile?.avatarUrl,
                localGoals: Int64(store.sessions.reduce(0) { $0 + $1.goals }),
                localAssists: Int64(store.sessions.reduce(0) { $0 + $1.assists })
            )
        }
        .task {
            await loadTeamData()
        }
        .alert(isOwner ? "解散球队" : "退出球队", isPresented: $showLeaveAlert) {
            Button("取消", role: .cancel) {}
            Button(isOwner ? "解散" : "退出", role: .destructive) {
                Task { await performLeaveTeam() }
            }
        } message: {
            Text(isOwner ? "解散后所有成员将被移除，且无法恢复。确定解散球队吗？" : "退出后可通过邀请码重新加入。确定退出球队吗？")
        }
    }

    // MARK: - Team Info Card

    private var teamInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    if isEditingTeamName {
                        HStack(spacing: 6) {
                            TextField("球队名称", text: $editedTeamName)
                                .font(.title3.weight(.bold))
                                .foregroundColor(.white)
                                .textFieldStyle(.plain)
                            Button {
                                Task { await saveTeamName() }
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppColors.neonBlue)
                            }
                            Button {
                                isEditingTeamName = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color.white.opacity(0.5))
                            }
                        }
                    } else {
                        HStack(spacing: 6) {
                            Text(team?.name ?? "我的球队")
                                .font(.title3.weight(.bold))
                                .foregroundColor(.white)
                            if isOwner {
                                Button {
                                    editedTeamName = team?.name ?? ""
                                    isEditingTeamName = true
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.caption)
                                        .foregroundColor(Color.white.opacity(0.6))
                                }
                            }
                        }
                    }
                    Text("成立于 \(teamCreatedDateText)")
                        .font(.caption)
                        .foregroundColor(Color.white.opacity(0.85))
                }

                Spacer()

                Button {
                    showMemberList = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                        Text("成员")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                ShareLink(item: "来加入我的球队「\(team?.name ?? "")」！\n在 FootyTrack App 中输入邀请码：\(team?.inviteCode ?? "")") {
                    HStack(spacing: 4) {
                        Image(systemName: "person.badge.plus")
                        Text("邀请")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
                }
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

    // MARK: - Leave Team

    private var leaveTeamSection: some View {
        Button(role: .destructive) {
            showLeaveAlert = true
        } label: {
            HStack {
                Spacer()
                if isLeaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(isOwner ? "解散球队" : "退出球队")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                }
                Spacer()
            }
            .padding(.vertical, 14)
            .background(Color.red)
            .cornerRadius(12)
        }
        .disabled(isLeaving)
    }

    private func performLeaveTeam() async {
        guard let teamId = team?.id else { return }
        isLeaving = true
        do {
            _ = try await ApiClient.shared.leaveTeam(teamId: teamId)
            authManager.invalidateTeams()
            authManager.teams = []
            teamDetail = nil
        } catch {
            // leave failed silently
        }
        isLeaving = false
    }

    // MARK: - Helpers

    @State private var showTeamLoginSheet = false

    private var loginRequiredState: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 12) {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 74, height: 74)
                        .overlay(Text("⚽️").font(.system(size: 36)))

                    Text("登录后查看球队")
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)

                    Text("登录后即可创建球队、加入球队，查看成员表现与排行榜。")
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

                Button {
                    showTeamLoginSheet = true
                } label: {
                    Text("登录 / 注册")
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
        .sheet(isPresented: $showTeamLoginSheet) {
            NavigationStack {
                LoginView(authManager: authManager, store: store)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("关闭") { showTeamLoginSheet = false }
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
            }
        }
        .onChange(of: authManager.isLoggedIn) { _, loggedIn in
            if loggedIn {
                showTeamLoginSheet = false
            }
        }
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

    private func saveTeamName() async {
        let name = editedTeamName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let teamId = team?.id else { return }
        do {
            let updated = try await ApiClient.shared.updateTeamName(teamId: teamId, name: name)
            if let detail = teamDetail {
                teamDetail = TeamDetailResponse(team: updated, members: detail.members)
            }
            isEditingTeamName = false
        } catch {}
    }

    private func loadTeamData() async {
        guard authManager.isLoggedIn else {
            isLoading = false
            return
        }
        if let firstTeam = authManager.teams.first {
            if let cachedDetail = authManager.getCachedTeamDetail(teamId: firstTeam.id) {
                teamDetail = cachedDetail
                isLoading = false
            }
        }

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

// MARK: - Team Leaderboard Section (isolated state)

private enum TeamLeaderTab: String, CaseIterable {
    case goals = "射手榜"
    case assists = "助攻榜"
    case attendance = "出勤率"
    case distance = "跑动榜"

    var icon: String {
        switch self {
        case .goals: return "soccerball"
        case .assists: return "hands.clap.fill"
        case .attendance: return "calendar"
        case .distance: return "figure.run"
        }
    }

    var colors: [Color] {
        switch self {
        case .goals: return [Color(hex: 0xEF4444), Color(hex: 0xF97316)]
        case .assists: return [Color(hex: 0x8B5CF6), Color(hex: 0xA855F7)]
        case .attendance: return [Color(hex: 0xF59E0B), Color(hex: 0xF97316)]
        case .distance: return [Color(hex: 0x10B981), Color(hex: 0x06B6D4)]
        }
    }
}

private struct TeamLeaderboardSection: View {
    let members: [TeamMemberResponse]
    var currentUserUid: String? = nil
    var currentUserAvatarUrl: String? = nil
    var localGoals: Int64 = 0
    var localAssists: Int64 = 0
    @State private var selectedTab: TeamLeaderTab = .goals

    /// Members with current user's goals/assists overridden from local data
    private var enrichedMembers: [TeamMemberResponse] {
        members.map { m in
            guard let uid = currentUserUid, m.userUid == uid else { return m }
            var copy = m
            copy.totalGoals = localGoals
            copy.totalAssists = localAssists
            return copy
        }
    }

    private func displayName(_ member: TeamMemberResponse) -> String {
        member.nickname.isEmpty ? "球员" : member.nickname
    }

    private var sortedMembers: [(member: TeamMemberResponse, value: String)] {
        let all = enrichedMembers
        let sorted: [TeamMemberResponse]
        switch selectedTab {
        case .goals:
            sorted = all.sorted { ($0.totalGoals ?? 0) > ($1.totalGoals ?? 0) }
        case .assists:
            sorted = all.sorted { ($0.totalAssists ?? 0) > ($1.totalAssists ?? 0) }
        case .attendance:
            sorted = all.sorted { $0.sessionCount > $1.sessionCount }
        case .distance:
            sorted = all.sorted { $0.totalDistanceMeters > $1.totalDistanceMeters }
        }

        return sorted.map { m in
            let value: String
            switch selectedTab {
            case .goals:
                value = "\(m.totalGoals ?? 0) 球"
            case .assists:
                value = "\(m.totalAssists ?? 0) 次"
            case .attendance:
                value = "\(m.sessionCount) 场"
            case .distance:
                value = String(format: "%.1f km", m.totalDistanceMeters / 1000)
            }
            return (member: m, value: value)
        }
    }

    private func rankEmoji(_ rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(rank)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("排行榜")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                Text("仅统计 Pro 会员的训练数据")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            // Tab buttons
            HStack(spacing: 0) {
                ForEach(TeamLeaderTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(selectedTab == tab ? AppColors.textPrimary : AppColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                selectedTab == tab
                                ? AppColors.cardBgLight
                                : Color.clear
                            )
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Color.white.opacity(0.06))
            .cornerRadius(10)

            // Leaderboard list
            VStack(spacing: 0) {
                if sortedMembers.isEmpty {
                    Text("暂无数据")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else {
                    ForEach(Array(sortedMembers.enumerated()), id: \.element.member.userUid) { index, item in
                        HStack(spacing: 10) {
                            Text(rankEmoji(index + 1))
                                .font(index < 3 ? .body : .caption.weight(.medium))
                                .frame(width: 28)

                            MemberAvatarView(member: item.member, size: 36, currentUserUid: currentUserUid, currentUserAvatarUrl: currentUserAvatarUrl)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(displayName(item.member))
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(AppColors.textPrimary)
                                    if item.member.role == "owner" {
                                        Text("队长")
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundColor(Color(hex: 0xFBBF24))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color(hex: 0xFBBF24).opacity(0.15))
                                            .cornerRadius(4)
                                    }
                                }
                            }

                            Spacer()

                            Text(item.value)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(selectedTab.colors.first ?? AppColors.neonBlue)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)

                        if index < sortedMembers.count - 1 {
                            Divider().overlay(AppColors.dividerColor.opacity(0.6))
                        }
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
}

// MARK: - Member Avatar View

private struct MemberAvatarView: View {
    let member: TeamMemberResponse
    var size: CGFloat = 44
    var currentUserUid: String? = nil
    var currentUserAvatarUrl: String? = nil

    private var resolvedAvatarUrl: String? {
        // Use member's own avatarUrl if available
        if let url = member.avatarUrl, !url.isEmpty { return url }
        // Fall back to current user's profile avatar if this member is the current user
        if let uid = currentUserUid, uid == member.userUid,
           let url = currentUserAvatarUrl, !url.isEmpty { return url }
        return nil
    }

    var body: some View {
        if let urlStr = resolvedAvatarUrl, let url = URL(string: urlStr) {
            AvatarCircleView(url: url)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(AppColors.cardBgLight)
                .frame(width: size, height: size)
                .overlay(Text("⚽️").font(.system(size: size * 0.45)))
        }
    }
}

// MARK: - Team Member List Page

struct TeamMemberListView: View {
    let members: [TeamMemberResponse]
    var currentUserUid: String? = nil
    var currentUserAvatarUrl: String? = nil
    var localGoals: Int64 = 0
    var localAssists: Int64 = 0

    private var enrichedMembers: [TeamMemberResponse] {
        members.map { m in
            guard let uid = currentUserUid, m.userUid == uid else { return m }
            var copy = m
            copy.totalGoals = localGoals
            copy.totalAssists = localAssists
            return copy
        }
    }

    private func displayName(_ member: TeamMemberResponse) -> String {
        member.nickname.isEmpty ? "球员" : member.nickname
    }

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(enrichedMembers.enumerated()), id: \.element.userUid) { index, member in
                        HStack(spacing: 12) {
                            MemberAvatarView(member: member, size: 44, currentUserUid: currentUserUid, currentUserAvatarUrl: currentUserAvatarUrl)

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 5) {
                                    Text(displayName(member))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(AppColors.textPrimary)
                                    if member.role == "owner" {
                                        Text("队长")
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundColor(Color(hex: 0xFBBF24))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color(hex: 0xFBBF24).opacity(0.15))
                                            .cornerRadius(4)
                                    }
                                }

                                HStack(spacing: 12) {
                                    Label("\(member.sessionCount) 场", systemImage: "calendar")
                                    Label(String(format: "%.1f km", member.totalDistanceMeters / 1000), systemImage: "figure.run")
                                }
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                HStack(spacing: 3) {
                                    Image(systemName: "soccerball")
                                        .font(.system(size: 10))
                                    Text("\(member.totalGoals ?? 0)")
                                        .font(.caption.weight(.semibold))
                                }
                                .foregroundColor(Color(hex: 0xEF4444))

                                HStack(spacing: 3) {
                                    Image(systemName: "hands.clap.fill")
                                        .font(.system(size: 10))
                                    Text("\(member.totalAssists ?? 0)")
                                        .font(.caption.weight(.semibold))
                                }
                                .foregroundColor(Color(hex: 0x8B5CF6))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)

                        if index < enrichedMembers.count - 1 {
                            Divider()
                                .overlay(AppColors.dividerColor.opacity(0.6))
                                .padding(.leading, 70)
                        }
                    }
                }
                .background(AppColors.cardBg)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("球队成员")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

// MARK: - Auth Flow (kept for profile login sheet)

struct AuthFlowView: View {
    @ObservedObject var authManager: AuthManager
    @ObservedObject var store: SessionStore

    var body: some View {
        NavigationStack {
            LoginView(authManager: authManager, store: store)
        }
    }
}
