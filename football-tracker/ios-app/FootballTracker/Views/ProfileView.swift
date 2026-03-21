import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct ProfileView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var authManager: AuthManager
    @ObservedObject private var watchSync = WatchSync.shared
    @State private var isLoading = true
    @State private var showEditSheet = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var syncStatus: String?
    @State private var isSyncing = false
    @State private var unreadSessionCount = UserDefaults.standard.integer(forKey: "unread_session_count")

    private var totalMatches: Int {
        store.sessions.count
    }

    private var totalSprints: Int {
        store.sessions.reduce(0) { $0 + $1.sprintCount }
    }

    private var totalDistanceKm: Double {
        store.sessions.reduce(0) { $0 + $1.totalDistanceMeters } / 1000
    }

    private var totalCalories: Double {
        store.sessions.reduce(0) { $0 + $1.caloriesBurned }
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


    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    profileCard
                    syncSection
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
        .onReceive(NotificationCenter.default.publisher(for: .sessionRecorded)) { _ in
            unreadSessionCount = UserDefaults.standard.integer(forKey: "unread_session_count")
        }
    }

    private var profileCard: some View {
        let nickname = authManager.userProfile?.nickname ?? "球员"

        return VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        Group {
                            if let avatar = authManager.userProfile?.avatarUrl,
                               let url = URL(string: avatar) {
                                AvatarCircleView(url: url)
                            } else {
                                Color.white.overlay(Text("⚽️").font(.system(size: 34)))
                            }
                        }
                        .frame(width: 76, height: 76)
                        .clipShape(Circle())

                        ZStack {
                            Circle().fill(Color.white)
                            Image(systemName: isUploadingAvatar ? "hourglass" : "camera.fill")
                                .font(.caption.weight(.bold))
                                .foregroundColor(AppColors.neonBlue)
                        }
                        .frame(width: 24, height: 24)
                    }
                }
                .disabled(isUploadingAvatar)

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
                profileStat(value: String(format: "%.1fkm", totalDistanceKm), label: "总距离")
                profileStat(value: String(format: "%.0f", totalCalories), label: "总卡路里")
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

    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("云同步")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

            // Two-column card buttons
            HStack(spacing: 12) {
                // Sync Now - primary blue card (blue-600)
                Button {
                    uploadData()
                } label: {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "icloud.and.arrow.up")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            )

                        Text("立即同步")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(hex: 0x2563EB))
                    .cornerRadius(14)
                }
                .disabled(isSyncing)

                // Restore Data - secondary card (gray-800 + gray-700 border)
                Button {
                    restoreData()
                } label: {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: 0x374151))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "icloud.and.arrow.down")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color(hex: 0x60A5FA))
                            )

                        Text("恢复数据")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(hex: 0x1F2937))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(hex: 0x374151), lineWidth: 2)
                    )
                }
                .disabled(isSyncing)
            }

            // Sync info bar
            if isSyncing || syncStatus != nil {
                HStack(spacing: 8) {
                    if isSyncing {
                        ProgressView()
                            .tint(Color(hex: 0x60A5FA))
                            .scaleEffect(0.7)
                    } else {
                        Circle()
                            .fill(AppColors.speedGreen)
                            .frame(width: 6, height: 6)
                    }

                    Text(syncStatus ?? "")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: 0x111827))
                .cornerRadius(14)
            }
        }
    }

    private var appearanceItems: [ProfileMenuItem] {
        [
            ProfileMenuItem(icon: "moon.fill", title: "主题", action: .theme, trailingValue: "深色", isToggle: true)
        ]
    }

    private var accountItems: [ProfileMenuItem] {
        [
            ProfileMenuItem(icon: "person.fill", title: "编辑资料", action: .editProfile),
            ProfileMenuItem(icon: "bell.fill", title: "通知", action: .notifications, badge: unreadSessionCount > 0 ? "\(unreadSessionCount)" : nil),
            ProfileMenuItem(icon: "square.and.arrow.up", title: "分享主页", action: .share)
        ]
    }

    private var deviceItems: [ProfileMenuItem] {
        let watchStatus = watchSync.isWatchConnected ? "已连接" : "未连接"
        return [
            ProfileMenuItem(icon: "applewatch", title: "Apple Watch", action: .watch, status: watchStatus)
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
                .font(.system(size: 20, weight: .semibold))
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
            NavigationLink {
                SettingsView(store: store, authManager: authManager)
            } label: {
                menuRowContent(item: item)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else if item.action == .notifications {
            NavigationLink {
                SessionNotificationsView(store: store)
            } label: {
                menuRowContent(item: item)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            Button {
                handleMenuAction(item.action)
            } label: {
                menuRowContent(item: item)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
                    .foregroundColor(status == "已连接" ? AppColors.speedGreen : AppColors.textSecondary)
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

    private func uploadData() {
        isSyncing = true
        syncStatus = "正在上传..."
        Task {
            do {
                let count = try await CloudSync.uploadPendingSessions(store: store, authManager: authManager)
                syncStatus = count > 0
                    ? "已同步 \(count) 场记录"
                    : "云端已是最新（无新增记录）"
            } catch {
                syncStatus = "同步失败: \(error.localizedDescription)"
            }
            isSyncing = false
        }
    }

    private func restoreData() {
        isSyncing = true
        syncStatus = "正在恢复..."
        Task {
            do {
                let count = try await CloudSync.pullFromCloud(store: store, authManager: authManager)
                syncStatus = "已恢复 \(count) 场记录"
            } catch {
                syncStatus = "恢复失败: \(error.localizedDescription)"
            }
            isSyncing = false
        }
    }
}

private struct AvatarCircleView: View {
    let url: URL
    @StateObject private var loader = AvatarImageLoader()

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.white.overlay(Text("⚽️").font(.system(size: 34)))
            }
        }
        .task(id: url) {
            await loader.load(from: url)
        }
    }
}

@MainActor
private final class AvatarImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?
    private static let memoryCache = NSCache<NSURL, UIImage>()

    func load(from url: URL) async {
        let key = url as NSURL

        if let memoryImage = Self.memoryCache.object(forKey: key) {
            image = memoryImage
            return
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 15

        if let cached = URLCache.shared.cachedResponse(for: request),
           let diskImage = UIImage(data: cached.data) {
            Self.memoryCache.setObject(diskImage, forKey: key)
            image = diskImage
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  200..<300 ~= http.statusCode,
                  let fetchedImage = UIImage(data: data) else {
                return
            }

            let cached = CachedURLResponse(response: response, data: data)
            URLCache.shared.storeCachedResponse(cached, for: request)
            Self.memoryCache.setObject(fetchedImage, forKey: key)
            image = fetchedImage
        } catch {
            return
        }
    }
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

