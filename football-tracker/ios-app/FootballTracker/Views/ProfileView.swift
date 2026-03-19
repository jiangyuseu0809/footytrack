import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct ProfileView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var authManager: AuthManager
    @State private var isLoading = true
    @State private var showEditSheet = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false

    private var totalMatches: Int {
        store.sessions.count
    }

    private var totalSprints: Int {
        store.sessions.reduce(0) { $0 + $1.sprintCount }
    }

    private var totalDistanceKm: Double {
        store.sessions.reduce(0) { $0 + $1.totalDistanceMeters } / 1000
    }

    private var avgSlack: Double {
        guard !store.sessions.isEmpty else { return 0 }
        return Double(store.sessions.reduce(0) { $0 + $1.slackIndex }) / Double(store.sessions.count)
    }

    private var playerLevel: Int {
        min(30, max(1, totalMatches / 2 + 1))
    }

    private var playStyle: String {
        if avgSlack <= 35 { return "进攻组织" }
        if avgSlack <= 55 { return "全能中场" }
        return "稳健控场"
    }

    private var seasonRating: Double {
        guard !store.sessions.isEmpty else { return 0 }
        let maxSpeed = store.sessions.map(\.maxSpeedKmh).max() ?? 0
        let speedScore = min(1, maxSpeed / 30)
        let sprintScore = min(1, Double(totalSprints) / Double(max(1, totalMatches * 40)))
        let distanceScore = min(1, totalDistanceKm / Double(max(1, totalMatches)) / 10)
        let disciplineScore = max(0, 1 - avgSlack / 100)
        return (speedScore * 0.3 + sprintScore * 0.25 + distanceScore * 0.25 + disciplineScore * 0.2) * 10
    }

    private var achievementItems: [ProfileAchievementItem] {
        let palette: [(Color, Color)] = [
            (Color(hex: 0xF59E0B), Color(hex: 0xF97316)),
            (Color(hex: 0x3B82F6), Color(hex: 0x06B6D4)),
            (Color(hex: 0xA855F7), Color(hex: 0xEC4899)),
            (Color(hex: 0xEF4444), Color(hex: 0xF43F5E)),
            (Color(hex: 0x22C55E), Color(hex: 0x10B981)),
            (Color(hex: 0x6366F1), Color(hex: 0x3B82F6))
        ]

        let all = authManager.earnedBadges?.allBadges ?? []
        let earnedIds = Set(authManager.earnedBadges?.earnedBadges.map { $0.badge.id } ?? [])

        let mapped = all.prefix(6).enumerated().map { idx, badge in
            let colors = palette[idx % palette.count]
            return ProfileAchievementItem(
                icon: badgeIcon(badge.iconName),
                title: badge.name,
                unlocked: earnedIds.contains(badge.id),
                start: colors.0,
                end: colors.1
            )
        }

        if mapped.count >= 6 { return Array(mapped) }

        let placeholders = [
            ProfileAchievementItem(icon: "heart.fill", title: "铁肺", unlocked: false, start: Color(hex: 0xEF4444), end: Color(hex: 0xF43F5E)),
            ProfileAchievementItem(icon: "medal.fill", title: "最有价值球员", unlocked: false, start: Color(hex: 0x22C55E), end: Color(hex: 0x10B981)),
            ProfileAchievementItem(icon: "trophy.fill", title: "冠军", unlocked: false, start: Color(hex: 0x6366F1), end: Color(hex: 0x3B82F6))
        ]

        return Array(mapped) + Array(placeholders.prefix(max(0, 6 - mapped.count)))
    }

    private var unlockedCount: Int {
        achievementItems.filter(\.unlocked).count
    }

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    profileCard
                    achievementsSection
                    summarySection
                    menuSection(title: "外观", items: appearanceItems)
                    menuSection(title: "账号", items: accountItems)
                    menuSection(title: "设备", items: deviceItems)
                    signOutButton
                    versionText
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
        .sheet(isPresented: $showEditSheet) {
            EditProfileSheet(profile: authManager.userProfile) { updated in
                authManager.userProfile = updated
                authManager.refreshProfileTimestamp()
            }
        }
        .task(id: pickerItem) {
            await uploadAvatarIfNeeded()
        }
    }

    private var profileCard: some View {
        let nickname = authManager.userProfile?.nickname ?? "球员"

        return VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let avatar = authManager.userProfile?.avatarUrl,
                           let url = URL(string: avatar) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                default:
                                    Color.white.overlay(Text("⚽️").font(.system(size: 34)))
                                }
                            }
                        } else {
                            Color.white.overlay(Text("⚽️").font(.system(size: 34)))
                        }
                    }
                    .frame(width: 76, height: 76)
                    .clipShape(Circle())

                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        ZStack {
                            Circle().fill(Color.white)
                            Image(systemName: isUploadingAvatar ? "hourglass" : "camera.fill")
                                .font(.caption.weight(.bold))
                                .foregroundColor(AppColors.neonBlue)
                        }
                        .frame(width: 24, height: 24)
                    }
                    .disabled(isUploadingAvatar)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(nickname)
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)

                    Text("\(playStyle) • 等级 \(playerLevel)")
                        .font(.subheadline)
                        .foregroundColor(Color.white.opacity(0.85))

                    Text("高级会员")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(999)
                }

                Spacer()
            }

            HStack(spacing: 0) {
                profileStat(value: "\(totalMatches)", label: "比赛场次")
                profileStat(value: playStyle, label: "球风")
                profileStat(value: "\(totalSprints)", label: "冲刺次数")
            }
            .padding(.top, 12)
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

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("成就")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text("\(unlockedCount)/\(achievementItems.count)")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                ForEach(achievementItems) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(item.unlocked ? LinearGradient(colors: [item.start, item.end], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [AppColors.cardBgLight, AppColors.cardBgLight], startPoint: .top, endPoint: .bottom))
                            .frame(height: 44)
                            .overlay(
                                Image(systemName: item.icon)
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(item.unlocked ? .white : AppColors.textSecondary.opacity(0.55))
                            )

                        Text(item.title)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(item.unlocked ? AppColors.textPrimary : AppColors.textSecondary.opacity(0.7))
                            .lineLimit(1)
                    }
                    .padding(10)
                    .background(item.unlocked ? AppColors.cardBgLight.opacity(0.6) : AppColors.cardBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                    .cornerRadius(12)
                }
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("赛季总结")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)

            summaryBar(title: "综合评分", valueText: String(format: "%.1f", seasonRating), progress: seasonRating / 10, start: Color(hex: 0x60A5FA), end: Color(hex: 0x2563EB))
            summaryBar(title: "跑动距离", valueText: String(format: "%.1f km", totalDistanceKm), progress: min(1, totalDistanceKm / 200), start: Color(hex: 0x4ADE80), end: Color(hex: 0x16A34A))
            summaryBar(title: "进攻贡献", valueText: "\(Int(Double(totalSprints) * 0.35))", progress: min(1, Double(totalSprints) / 120), start: Color(hex: 0xC084FC), end: Color(hex: 0x9333EA))
        }
        .padding(14)
        .background(AppColors.cardBg)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .cornerRadius(16)
    }

    private var appearanceItems: [ProfileMenuItem] {
        [
            ProfileMenuItem(icon: "moon.fill", title: "主题", action: .theme, trailingValue: "深色", isToggle: true)
        ]
    }

    private var accountItems: [ProfileMenuItem] {
        [
            ProfileMenuItem(icon: "person.fill", title: "编辑资料", action: .editProfile),
            ProfileMenuItem(icon: "bell.fill", title: "通知", action: .notifications, badge: "3"),
            ProfileMenuItem(icon: "square.and.arrow.up", title: "分享主页", action: .share)
        ]
    }

    private var deviceItems: [ProfileMenuItem] {
        [
            ProfileMenuItem(icon: "applewatch", title: "Apple Watch", action: .watch, status: "已连接")
        ]
    }

    private var supportItems: [ProfileMenuItem] {
        [
            ProfileMenuItem(icon: "gearshape.fill", title: "设置", action: .settings),
            ProfileMenuItem(icon: "shield.fill", title: "隐私与安全", action: .privacy),
            ProfileMenuItem(icon: "questionmark.circle.fill", title: "帮助与支持", action: .help)
        ]
    }

    private func menuSection(title: String, items: [ProfileMenuItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    menuRow(item: item)

                    if index < items.count - 1 {
                        Divider().overlay(AppColors.dividerColor.opacity(0.6))
                    }
                }
            }
            .background(AppColors.cardBg)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            .cornerRadius(16)
        }
    }

    @ViewBuilder
    private func menuRow(item: ProfileMenuItem) -> some View {
        if item.action == .settings {
            NavigationLink(destination: SettingsView(store: store, authManager: authManager)) {
                menuRowContent(item: item)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        } else {
            Button {
                handleMenuAction(item.action)
            } label: {
                menuRowContent(item: item)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
    }

    private func menuRowContent(item: ProfileMenuItem) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 9)
                .fill(AppColors.cardBgLight)
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: item.icon)
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                )

            Text(item.title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            if let badge = item.badge {
                Text(badge)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.white)
                    .frame(width: 18, height: 18)
                    .background(AppColors.heartRed)
                    .clipShape(Circle())
            }

            if let status = item.status {
                Text(status)
                    .font(.caption.weight(.medium))
                    .foregroundColor(AppColors.speedGreen)
            }

            if let trailingValue = item.trailingValue {
                Text(trailingValue)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            if item.isToggle {
                Capsule()
                    .fill(Color(hex: 0x2563EB))
                    .frame(width: 42, height: 24)
                    .overlay(alignment: .trailing) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 18, height: 18)
                            .padding(.trailing, 3)
                    }
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.textSecondary.opacity(0.7))
            }
        }
    }

    private var signOutButton: some View {
        Button {
            authManager.logout()
        } label: {
            Text("退出登录")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.heartRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
    }

    private var versionText: some View {
        Text("版本 \(appVersion)")
            .font(.caption)
            .foregroundColor(AppColors.textSecondary.opacity(0.7))
            .frame(maxWidth: .infinity)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.1.0"
    }

    private func profileStat(value: String, label: String) -> some View {
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

    private func summaryBar(title: String, valueText: String, progress: Double, start: Color, end: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text(valueText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
            }

            GeometryReader { proxy in
                let width = max(0, min(1, progress)) * proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.cardBgLight)
                    Capsule()
                        .fill(LinearGradient(colors: [start, end], startPoint: .leading, endPoint: .trailing))
                        .frame(width: width)
                }
            }
            .frame(height: 8)
        }
    }

    private func badgeIcon(_ iconName: String) -> String {
        switch iconName {
        case "first_match": return "sportscourt.fill"
        case "iron_man": return "figure.strengthtraining.traditional"
        case "century_legend": return "star.fill"
        case "speed_star": return "bolt.fill"
        case "marathon_runner": return "figure.run"
        case "calorie_burner": return "flame.fill"
        case "perfect_month": return "calendar.badge.checkmark"
        case "sprint_king": return "hare.fill"
        default: return "medal.fill"
        }
    }

    private func handleMenuAction(_ action: ProfileMenuAction) {
        switch action {
        case .theme:
            return
        case .editProfile:
            showEditSheet = true
        case .notifications:
            return
        case .share:
            return
        case .watch:
            return
        case .privacy:
            return
        case .help:
            return
        case .settings:
            return
        }
    }

    private func loadData() async {
        async let profileLoad: () = authManager.loadProfileIfNeeded()
        async let teamsLoad: () = authManager.loadTeamsIfNeeded()
        async let badgesLoad: () = authManager.loadBadgesIfNeeded()
        _ = await (profileLoad, teamsLoad, badgesLoad)
        isLoading = false
    }

    private func uploadAvatarIfNeeded() async {
        guard let item = pickerItem, !isUploadingAvatar else { return }
        isUploadingAvatar = true
        defer {
            isUploadingAvatar = false
            pickerItem = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { return }
            let resp = try await ApiClient.shared.updateAvatar(image)
            if var profile = authManager.userProfile {
                profile = UserProfileResponse(
                    uid: profile.uid,
                    phone: profile.phone,
                    wechatOpenId: profile.wechatOpenId,
                    username: profile.username,
                    nickname: profile.nickname,
                    weightKg: profile.weightKg,
                    age: profile.age,
                    avatarUrl: resp.avatarUrl,
                    authProvider: profile.authProvider,
                    createdAt: profile.createdAt
                )
                authManager.userProfile = profile
                authManager.refreshProfileTimestamp()
                NotificationCenter.default.post(
                    name: Notification.Name("GlobalToast"),
                    object: nil,
                    userInfo: ["message": "头像更新成功"]
                )
            }
        } catch {
            NotificationCenter.default.post(
                name: Notification.Name("GlobalToast"),
                object: nil,
                userInfo: ["message": "头像上传失败，请重试"]
            )
            return
        }
    }
}

private struct ProfileAchievementItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let unlocked: Bool
    let start: Color
    let end: Color
}

private struct ProfileMenuItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let action: ProfileMenuAction
    var trailingValue: String? = nil
    var badge: String? = nil
    var status: String? = nil
    var isToggle: Bool = false
}

private enum ProfileMenuAction {
    case theme
    case editProfile
    case notifications
    case share
    case watch
    case settings
    case privacy
    case help
}

