import SwiftUI

struct JoinTeamSheet: View {
    let inviteCode: String
    let authManager: AuthManager
    let onDismiss: () -> Void

    @State private var preview: TeamPreviewResponse?
    @State private var isLoading = true
    @State private var isJoining = false
    @State private var errorMessage: String?
    @State private var joinSuccess = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.darkBg.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(AppColors.neonBlue)
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Color(hex: 0xF59E0B))
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                } else if joinSuccess {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: 0x10B981))
                        Text("已成功加入球队！")
                            .font(.title3.weight(.bold))
                            .foregroundColor(.white)
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            onDismiss()
                        }
                    }
                } else if let preview {
                    VStack(spacing: 24) {
                        // Team info card
                        VStack(spacing: 16) {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 74, height: 74)
                                .overlay(Text("⚽️").font(.system(size: 36)))

                            Text(preview.teamName)
                                .font(.title2.weight(.bold))
                                .foregroundColor(.white)

                            HStack(spacing: 20) {
                                VStack(spacing: 4) {
                                    Text("\(preview.memberCount)")
                                        .font(.headline.weight(.bold))
                                        .foregroundColor(.white)
                                    Text("成员")
                                        .font(.caption)
                                        .foregroundColor(Color.white.opacity(0.8))
                                }
                                VStack(spacing: 4) {
                                    Text(preview.ownerNickname)
                                        .font(.headline.weight(.bold))
                                        .foregroundColor(.white)
                                    Text("队长")
                                        .font(.caption)
                                        .foregroundColor(Color.white.opacity(0.8))
                                }
                            }
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: 0x3B82F6), Color(hex: 0x4F46E5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(18)

                        // Join button
                        Button {
                            Task { await joinTeam() }
                        } label: {
                            HStack {
                                if isJoining {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("加入球队")
                                        .font(.headline.weight(.semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: 0x3B82F6), Color(hex: 0x4F46E5)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        .disabled(isJoining)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("邀请加入球队")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { onDismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .task {
            await loadPreview()
        }
    }

    private func loadPreview() async {
        do {
            preview = try await ApiClient.shared.getTeamPreview(inviteCode: inviteCode)
        } catch {
            errorMessage = "无法获取球队信息，请稍后再试"
        }
        isLoading = false
    }

    private func joinTeam() async {
        isJoining = true
        do {
            _ = try await ApiClient.shared.joinTeam(inviteCode: inviteCode)
            authManager.invalidateTeams()
            await authManager.loadTeamsIfNeeded(forceRefresh: true)
            joinSuccess = true
        } catch let ApiError.httpError(_, msg) {
            errorMessage = msg
        } catch {
            errorMessage = "加入失败，请稍后再试"
        }
        isJoining = false
    }
}
