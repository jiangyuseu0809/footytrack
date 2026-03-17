import SwiftUI

struct ProfileView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var authManager: AuthManager
    @State private var earnedBadgesResponse: EarnedBadgesResponse?
    @State private var teams: [TeamResponse] = []
    @State private var userProfile: UserProfileResponse?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    profileHeaderSection
                    careerStatsCard
                    radarChartCard
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

    // MARK: - Profile Header

    private var profileHeaderSection: some View {
        VStack(spacing: 12) {
            if let profile = userProfile {
                let initial = profile.nickname.prefix(1).uppercased()
                ZStack {
                    Circle()
                        .fill(AppColors.neonGradient)
                        .frame(width: 72, height: 72)
                    Text(initial)
                        .font(.title.bold())
                        .foregroundColor(.white)
                }

                Text(profile.nickname)
                    .font(.title3.bold())
                    .foregroundColor(AppColors.textPrimary)
            } else {
                ZStack {
                    Circle()
                        .fill(AppColors.cardBgLight)
                        .frame(width: 72, height: 72)
                    Image(systemName: "person.fill")
                        .font(.title)
                        .foregroundColor(AppColors.textSecondary)
                }

                Text("加载中...")
                    .font(.title3.bold())
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Career Stats

    private var careerStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("生涯数据")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                statItem(value: "\(store.sessions.count)", label: "总场次")
                statItem(value: formatDistance(totalDistance), label: "总跑动")
                statItem(value: formatCalories(totalCalories), label: "总卡路里")
                statItem(value: String(format: "%.1f", maxSpeed), label: "最高速度", unit: "km/h")
                statItem(value: "\(totalSprints)", label: "冲刺次数")
                statItem(value: formatDistance(avgDistance), label: "场均跑动")
            }
        }
        .padding(16)
        .background(AppColors.cardBg)
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }

    // MARK: - Radar Chart

    private var radarChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("能力雷达")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)

            RadarChartView(axes: radarAxes, size: 240)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(16)
        .background(AppColors.cardBg)
        .cornerRadius(16)
        .padding(.horizontal, 16)
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

    // MARK: - Stat Item Helper

    private func statItem(value: String, label: String, unit: String? = nil) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                    .foregroundColor(AppColors.textPrimary)
                if let unit = unit {
                    Text(unit)
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            Text(label)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: - Computed Stats

    private var totalDistance: Double {
        store.sessions.reduce(0) { $0 + $1.totalDistanceMeters }
    }

    private var totalCalories: Double {
        store.sessions.reduce(0) { $0 + $1.caloriesBurned }
    }

    private var maxSpeed: Double {
        store.sessions.map(\.maxSpeedKmh).max() ?? 0
    }

    private var totalSprints: Int {
        store.sessions.reduce(0) { $0 + $1.sprintCount }
    }

    private var avgDistance: Double {
        guard !store.sessions.isEmpty else { return 0 }
        return totalDistance / Double(store.sessions.count)
    }

    // MARK: - Radar Axes

    private var radarAxes: [(label: String, value: Double)] {
        guard !store.sessions.isEmpty else {
            return [
                (label: "速度", value: 0),
                (label: "耐力", value: 0),
                (label: "强度", value: 0),
                (label: "覆盖", value: 0),
                (label: "冲刺", value: 0)
            ]
        }

        let count = Double(store.sessions.count)

        let avgMaxSpeed = store.sessions.map(\.maxSpeedKmh).reduce(0, +) / count
        let speedVal = min(avgMaxSpeed / 30.0, 1.0)

        let avgDist = totalDistance / count
        let enduranceVal = min(avgDist / 10000.0, 1.0)

        let avgHighIntensityRatio: Double = {
            let ratios = store.sessions.map { s -> Double in
                guard s.totalDistanceMeters > 0 else { return 0 }
                return s.highIntensityDistanceMeters / s.totalDistanceMeters
            }
            return ratios.reduce(0, +) / count
        }()
        let intensityVal = min(avgHighIntensityRatio / 0.3, 1.0)

        let avgCoverage = store.sessions.map(\.coveragePercent).reduce(0, +) / count
        let coverageVal = min(avgCoverage / 100.0, 1.0)

        let avgSprints = Double(totalSprints) / count
        let sprintVal = min(avgSprints / 10.0, 1.0)

        return [
            (label: "速度", value: speedVal),
            (label: "耐力", value: enduranceVal),
            (label: "强度", value: intensityVal),
            (label: "覆盖", value: coverageVal),
            (label: "冲刺", value: sprintVal)
        ]
    }

    // MARK: - Formatting Helpers

    private func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1fkm", meters / 1000.0)
        }
        return String(format: "%.0fm", meters)
    }

    private func formatCalories(_ cal: Double) -> String {
        if cal >= 1000 {
            return String(format: "%.1fk", cal / 1000.0)
        }
        return String(format: "%.0f", cal)
    }

    // MARK: - Data Loading

    private func loadData() async {
        do {
            async let profileTask = ApiClient.shared.getProfile()
            async let teamsTask = ApiClient.shared.getTeams()
            async let badgesTask = ApiClient.shared.getEarnedBadges()

            let (profileResp, teamsResp, badgesResp) = try await (profileTask, teamsTask, badgesTask)
            userProfile = profileResp
            teams = teamsResp.teams
            earnedBadgesResponse = badgesResp
        } catch {
            // Silently handle errors — data will show empty state
        }
        isLoading = false
    }
}
