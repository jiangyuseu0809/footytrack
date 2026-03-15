import SwiftUI

struct ProfileView: View {
    @ObservedObject var store: SessionStore
    @State private var earnedBadgesResponse: EarnedBadgesResponse?
    @State private var teams: [TeamResponse] = []
    @State private var isLoading = true

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    recentSessionsSection
                    teamsSection
                    badgeSection
                }
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
    }

    // MARK: - Recent Sessions

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近比赛")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text("\(store.sessions.count) 场")
                    .font(.subheadline)
                    .foregroundColor(AppColors.neonBlue)
            }

            if store.sessions.isEmpty {
                Text("暂无比赛记录")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(store.sessions.prefix(3), id: \.id) { session in
                    NavigationLink(destination: SessionDetailView(session: session, store: store)) {
                        SessionRow(session: session)
                    }
                }
            }
        }
        .padding(16)
        .background(AppColors.cardBg)
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }

    // MARK: - Teams

    private var teamsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("我的球队")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                NavigationLink(destination: TeamListView()) {
                    HStack(spacing: 4) {
                        Text("管理")
                            .font(.subheadline)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(AppColors.neonBlue)
                }
            }

            if teams.isEmpty {
                Text("还没有加入球队")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(teams, id: \.id) { team in
                    NavigationLink(destination: TeamDetailView(teamId: team.id)) {
                        HStack {
                            Image(systemName: "person.3.fill")
                                .foregroundColor(AppColors.neonBlue)
                            Text(team.name)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(12)
                        .background(AppColors.cardBgLight)
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding(16)
        .background(AppColors.cardBg)
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }

    // MARK: - Badges

    private var badgeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("勋章墙")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                if let resp = earnedBadgesResponse {
                    Text("\(resp.earnedBadges.count)/\(resp.allBadges.count)")
                        .font(.subheadline)
                        .foregroundColor(AppColors.neonBlue)
                }
            }

            if let resp = earnedBadgesResponse {
                BadgeWallView(
                    allBadges: resp.allBadges,
                    earnedBadges: resp.earnedBadges
                )
            }
        }
        .padding(16)
        .background(AppColors.cardBg)
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }

    private func loadData() async {
        do {
            async let teamsTask = ApiClient.shared.getTeams()
            async let badgesTask = ApiClient.shared.getEarnedBadges()

            let (teamsResp, badgesResp) = try await (teamsTask, badgesTask)
            teams = teamsResp.teams
            earnedBadgesResponse = badgesResp
        } catch {
            // Silently handle errors — data will show empty state
        }
        isLoading = false
    }
}
