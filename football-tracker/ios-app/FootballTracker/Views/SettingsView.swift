import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var authManager: AuthManager
    @State private var profile: UserProfileResponse?
    @State private var isLoadingProfile = false
    @State private var showEditSheet = false
    @State private var syncStatus: String?
    @State private var isSyncing = false

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Profile Card
                    profileCard

                    // Cloud Sync Section
                    syncSection

                    // Logout
                    Button {
                        authManager.logout()
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("退出登录")
                        }
                        .font(.headline)
                        .foregroundColor(AppColors.heartRed)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppColors.cardBg)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadProfile() }
        .sheet(isPresented: $showEditSheet) {
            EditProfileSheet(profile: profile) { updated in
                profile = updated
            }
        }
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Avatar (first letter)
                let initial = String((profile?.nickname ?? "U").prefix(1)).uppercased()
                ZStack {
                    Circle()
                        .fill(AppColors.neonGradient)
                        .frame(width: 56, height: 56)
                    Text(initial)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile?.nickname ?? "加载中...")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)

                    if let p = profile {
                        Text("\(String(format: "%.0f", p.weightKg))kg · \(p.age)岁")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()

                Button { showEditSheet = true } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundColor(AppColors.neonBlue)
                }
            }
        }
        .padding(16)
        .background(AppColors.cardBg)
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }

    // MARK: - Sync Section

    private var syncSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "cloud.fill")
                    .foregroundColor(AppColors.neonBlue)
                Text("云同步")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
            }

            // Status
            if let status = syncStatus {
                Text(status)
                    .font(.caption)
                    .foregroundColor(AppColors.neonBlue)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 12) {
                Button {
                    uploadData()
                } label: {
                    HStack {
                        Image(systemName: "icloud.and.arrow.up")
                        Text("立即同步")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppColors.neonBlue)
                    .cornerRadius(10)
                }
                .disabled(isSyncing)

                Button {
                    restoreData()
                } label: {
                    HStack {
                        Image(systemName: "icloud.and.arrow.down")
                        Text("恢复数据")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColors.neonBlue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppColors.cardBgLight)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppColors.neonBlue, lineWidth: 1)
                    )
                }
                .disabled(isSyncing)
            }

            if isSyncing {
                ProgressView()
                    .tint(AppColors.neonBlue)
            }
        }
        .padding(16)
        .background(AppColors.cardBg)
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private func loadProfile() async {
        isLoadingProfile = true
        do {
            profile = try await ApiClient.shared.getProfile()
        } catch {
            // Silently handle — profile card shows "加载中..."
        }
        isLoadingProfile = false
    }

    private func uploadData() {
        isSyncing = true
        syncStatus = "正在上传..."
        Task {
            do {
                let count = try await CloudSync.uploadPendingSessions(store: store, authManager: authManager)
                syncStatus = "已同步 \(count) 场记录"
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

// MARK: - Edit Profile Sheet

struct EditProfileSheet: View {
    let profile: UserProfileResponse?
    let onUpdated: (UserProfileResponse) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var nickname: String = ""
    @State private var weightText: String = ""
    @State private var ageText: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.darkBg.ignoresSafeArea()

                VStack(spacing: 20) {
                    VStack(spacing: 16) {
                        inputField(icon: "person.fill", placeholder: "昵称", text: $nickname)
                        inputField(icon: "scalemass.fill", placeholder: "体重 (kg)", text: $weightText, keyboard: .decimalPad)
                        inputField(icon: "calendar", placeholder: "年龄", text: $ageText, keyboard: .numberPad)
                    }
                    .padding(.horizontal, 16)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(AppColors.heartRed)
                    }

                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .foregroundColor(AppColors.neonBlue)
                        .disabled(isSaving)
                }
            }
        }
        .onAppear {
            nickname = profile?.nickname ?? ""
            weightText = profile.map { String(format: "%.0f", $0.weightKg) } ?? "70"
            ageText = profile.map { String($0.age) } ?? "25"
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                let updated = try await ApiClient.shared.updateProfile(
                    UpdateProfileRequest(
                        nickname: nickname.isEmpty ? nil : nickname,
                        weightKg: Double(weightText),
                        age: Int(ageText)
                    )
                )
                onUpdated(updated)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }

    @ViewBuilder
    private func inputField(icon: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(AppColors.textSecondary)
            TextField("", text: text, prompt: Text(placeholder).foregroundColor(AppColors.textSecondary))
                .foregroundColor(AppColors.textPrimary)
                .keyboardType(keyboard)
                .autocapitalization(.none)
        }
        .padding()
        .background(AppColors.cardBg)
        .cornerRadius(12)
    }
}
