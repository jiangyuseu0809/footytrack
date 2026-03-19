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
                TeamHubView(authManager: authManager)
            }
            .tabItem {
                Image(systemName: "flag.fill")
                Text("球队")
            }

            NavigationStack {
                StatsView(store: store)
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
        }
        .tint(AppColors.neonBlue)
        .task {
            await authManager.preloadData()
        }
    }
}

// MARK: - Team Hub

struct TeamHubView: View {
    @ObservedObject var authManager: AuthManager
    @State private var teamDetail: TeamDetailResponse?
    @State private var isLoading = true

    private var team: TeamResponse? {
        teamDetail?.team ?? authManager.teams.first
    }

    private var teamMembers: [TeamMemberResponse] {
        teamDetail?.members ?? []
    }

    private var attendanceRanking: [TeamMemberResponse] {
        teamMembers.sorted { $0.sessionCount > $1.sessionCount }
    }

    private var runningRanking: [TeamMemberResponse] {
        teamMembers.sorted { $0.totalDistanceMeters > $1.totalDistanceMeters }
    }

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(AppColors.neonBlue)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        teamIntroCard
                        memberSection
                        rankingSection(title: "出勤排行", members: attendanceRanking, valueText: { "\($0.sessionCount) 场" })
                        rankingSection(title: "跑动排行", members: runningRanking, valueText: {
                            String(format: "%.1f km", $0.totalDistanceMeters / 1000.0)
                        })
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                }
            }
        }
        .navigationTitle("球队")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleDisplayMode(.inline)
        .task {
            await loadTeamData()
        }
    }

    private var teamIntroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(team?.name ?? "我的球队")
                        .font(.title3.bold())
                        .foregroundColor(AppColors.textPrimary)

                    Text("球队简介")
                        .font(.caption)
                        .foregroundColor(AppColors.neonBlue)
                }

                Spacer()

                Image(systemName: "sportscourt.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppColors.neonBlue)
            }

            Text("固定比赛日：每周二/周五晚场。坚持出勤，保持跑动强度，和队友一起稳步提升。")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let inviteCode = team?.inviteCode {
                HStack(spacing: 8) {
                    Text("邀请码")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Text(inviteCode)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.neonBlue)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(AppColors.cardBgLight)
                .cornerRadius(10)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [AppColors.cardBgLight, AppColors.cardBg],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var memberSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.neonBlue.opacity(0.16))
                    .frame(width: 26, height: 26)
                    .overlay(
                        Image(systemName: "person.2.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppColors.neonBlue)
                    )

                Text("成员列表")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
            }

            if teamMembers.isEmpty {
                Text("暂无成员数据")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                ForEach(teamMembers, id: \.userUid) { member in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(AppColors.cardBgLight)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(String(member.nickname.prefix(1)))
                                    .font(.caption.bold())
                                    .foregroundColor(AppColors.textPrimary)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.nickname.isEmpty ? "球员" : member.nickname)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(AppColors.textPrimary)

                            Text(member.role == "owner" ? "队长" : "成员")
                                .font(.caption2)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        Text("\(member.sessionCount) 场")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppColors.neonBlue)
                    }
                    .padding(10)
                    .background(AppColors.cardBgLight)
                    .cornerRadius(10)
                }
            }
        }
        .padding(16)
        .background(AppColors.cardBg)
        .cornerRadius(16)
    }

    private func rankingSection(
        title: String,
        members: [TeamMemberResponse],
        valueText: @escaping (TeamMemberResponse) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.neonBlue.opacity(0.16))
                    .frame(width: 26, height: 26)
                    .overlay(
                        Image(systemName: title == "出勤排行" ? "calendar.badge.clock" : "figure.run")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppColors.neonBlue)
                    )

                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
            }

            if members.isEmpty {
                Text("暂无排行数据")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(members.enumerated()), id: \.element.userUid) { index, member in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(rankBadgeBackground(index + 1))
                                    .frame(width: 30, height: 30)

                                Text("\(index + 1)")
                                    .font(.caption.bold())
                                    .foregroundColor(rankColor(index + 1))
                            }

                            Text(member.nickname.isEmpty ? "球员" : member.nickname)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            Text(valueText(member))
                                .font(.caption.weight(.semibold))
                                .foregroundColor(AppColors.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(valuePillBackground(index + 1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(rankColor(index + 1).opacity(0.22), lineWidth: 0.6)
                                )
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(rowBackground(index + 1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(rowBorderColor(index + 1), lineWidth: 0.6)
                        )
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [AppColors.cardBg, AppColors.cardBgLight.opacity(0.68)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(hex: 0xF9A825)
        case 2: return Color(hex: 0xB0BEC5)
        case 3: return Color(hex: 0xFF8F00)
        default: return AppColors.textSecondary
        }
    }

    private func rankBadgeBackground(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(hex: 0xF9A825).opacity(0.18)
        case 2: return Color(hex: 0xB0BEC5).opacity(0.18)
        case 3: return Color(hex: 0xFF8F00).opacity(0.18)
        default: return AppColors.cardBgLight
        }
    }

    private func rowBackground(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(hex: 0xF9A825).opacity(0.10)
        case 2: return Color(hex: 0xB0BEC5).opacity(0.10)
        case 3: return Color(hex: 0xFF8F00).opacity(0.10)
        default: return AppColors.cardBgLight
        }
    }

    private func valuePillBackground(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(hex: 0xF9A825).opacity(0.18)
        case 2: return Color(hex: 0xB0BEC5).opacity(0.18)
        case 3: return Color(hex: 0xFF8F00).opacity(0.18)
        default: return AppColors.neonBlue.opacity(0.15)
        }
    }

    private func rowBorderColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(hex: 0xF9A825).opacity(0.28)
        case 2: return Color(hex: 0xB0BEC5).opacity(0.26)
        case 3: return Color(hex: 0xFF8F00).opacity(0.26)
        default: return Color.white.opacity(0.06)
        }
    }

    private func loadTeamData() async {
        await authManager.loadTeamsIfNeeded()

        if let firstTeam = authManager.teams.first {
            do {
                teamDetail = try await ApiClient.shared.getTeamDetail(teamId: firstTeam.id)
            } catch {
                teamDetail = nil
            }
        }

        isLoading = false
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
