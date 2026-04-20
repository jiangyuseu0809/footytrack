import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

private enum TeamEntryMode {
    case select
    case create
    case join
    case success
}

struct TeamListView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var mode: TeamEntryMode = .select
    @State private var teamName = ""
    @State private var inviteCode = ""
    @State private var createdTeam: TeamResponse?
    @State private var copied = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var joinSuccessMessage: String?

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    contentView
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }

            if isLoading {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                ProgressView()
                    .tint(AppColors.neonBlue)
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .alert("提示", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("加入成功", isPresented: Binding(
            get: { joinSuccessMessage != nil },
            set: { if !$0 { joinSuccessMessage = nil } }
        )) {
            Button("完成") {
                dismiss()
            }
        } message: {
            Text(joinSuccessMessage ?? "")
        }
        .animation(.easeInOut(duration: 0.25), value: mode)
    }

    private var navigationTitle: String {
        switch mode {
        case .select: return "球队管理"
        case .create: return "创建球队"
        case .join: return "加入球队"
        case .success: return "创建成功"
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch mode {
        case .select:
            selectView.transition(.move(edge: .trailing).combined(with: .opacity))
        case .create:
            createView.transition(.move(edge: .trailing).combined(with: .opacity))
        case .join:
            joinView.transition(.move(edge: .trailing).combined(with: .opacity))
        case .success:
            successView.transition(.scale.combined(with: .opacity))
        }
    }

    private var selectView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 72, height: 72)
                    .overlay(Image(systemName: "shield.lefthalf.filled").font(.system(size: 30)).foregroundColor(.white))

                Text("开始组建你的球队")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)

                Text("创建新球队或输入邀请码加入已有球队")
                    .font(.subheadline)
                    .foregroundColor(Color.white.opacity(0.88))
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

            actionCard(
                icon: "person.3.fill",
                iconColors: [Color(hex: 0x22C55E), Color(hex: 0x10B981)],
                title: "创建新球队",
                subtitle: "组建自己的球队，邀请好友加入"
            ) {
                mode = .create
            }

            actionCard(
                icon: "arrow.right.square.fill",
                iconColors: [Color(hex: 0x3B82F6), Color(hex: 0x4F46E5)],
                title: "加入球队",
                subtitle: "输入6位邀请码，快速加入球队"
            ) {
                mode = .join
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("球队功能")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                Text("• 统计成员表现与出勤")
                Text("• 查看排行榜与活跃度")
                Text("• 与队友共享比赛数据")
            }
            .font(.caption)
            .foregroundColor(AppColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(AppColors.cardBg)
            .cornerRadius(12)
        }
    }

    private var createView: some View {
        VStack(spacing: 14) {
            inputCard(title: "球队名称 *") {
                VStack(alignment: .trailing, spacing: 6) {
                    TextField("输入你的球队名称", text: $teamName)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(AppColors.cardBgLight)
                        .cornerRadius(10)

                    Text("\(teamName.count)/20")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(AppColors.neonBlue)
                    Text("创建后可分享")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.neonBlue)
                }
                Text("球队创建成功后会生成专属邀请码，可复制并发送给队友加入。")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(AppColors.neonBlue.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.neonBlue.opacity(0.28), lineWidth: 1)
            )
            .cornerRadius(12)

            Button {
                Task { await createTeam() }
            } label: {
                Text("创建球队")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        teamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? AnyShapeStyle(Color.gray.opacity(0.45))
                        : AnyShapeStyle(LinearGradient(colors: [Color(hex: 0x3B82F6), Color(hex: 0x4F46E5)], startPoint: .leading, endPoint: .trailing))
                    )
                    .cornerRadius(12)
            }
            .disabled(teamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
    }

    private var joinView: some View {
        VStack(spacing: 14) {
            VStack(spacing: 10) {
                Text("输入邀请码")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)

                TextField("6位邀请码", text: Binding(
                    get: { inviteCode },
                    set: { inviteCode = String($0.uppercased().prefix(6)) }
                ))
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .kerning(4)
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.textPrimary)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(AppColors.cardBgLight)
                .cornerRadius(12)

                Text("请输入队长分享的6位邀请码")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(16)
            .background(AppColors.cardBg)
            .cornerRadius(14)

            VStack(alignment: .leading, spacing: 6) {
                Text("如何获取邀请码？")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                Text("1. 向球队队长或成员索取邀请码")
                Text("2. 在上方输入框输入6位邀请码")
                Text("3. 点击下方加入按钮")
            }
            .font(.caption)
            .foregroundColor(AppColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(AppColors.cardBg)
            .cornerRadius(12)

            Button {
                Task { await joinTeam() }
            } label: {
                Text("加入球队")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        inviteCode.count == 6
                        ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xA855F7), Color(hex: 0xEC4899)], startPoint: .leading, endPoint: .trailing))
                        : AnyShapeStyle(Color.gray.opacity(0.45))
                    )
                    .cornerRadius(12)
            }
            .disabled(inviteCode.count != 6 || isLoading)
        }
    }

    private var successView: some View {
        VStack(spacing: 14) {
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0x22C55E), Color(hex: 0x10B981)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 92, height: 92)
                .overlay(Image(systemName: "checkmark").font(.system(size: 40, weight: .bold)).foregroundColor(.white))
                .padding(.top, 12)

            Text("球队创建成功！")
                .font(.title3.weight(.bold))
                .foregroundColor(AppColors.textPrimary)

            Text(createdTeam?.name ?? "")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)

            VStack(alignment: .leading, spacing: 10) {
                Text("专属邀请码")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)

                Text(createdTeam?.inviteCode ?? "------")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .kerning(4)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LinearGradient(colors: [Color(hex: 0x3B82F6), Color(hex: 0x4F46E5)], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white)
                    .cornerRadius(12)

                Button {
                    copyInviteCode()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "已复制邀请码" : "复制邀请码")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(copied ? Color(hex: 0x22C55E) : AppColors.neonBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background((copied ? Color(hex: 0x22C55E) : AppColors.neonBlue).opacity(0.12))
                    .cornerRadius(10)
                }
            }
            .padding(16)
            .background(AppColors.cardBg)
            .cornerRadius(14)

            Button {
                dismiss()
            } label: {
                Text("完成")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LinearGradient(colors: [Color(hex: 0x3B82F6), Color(hex: 0x4F46E5)], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(12)
            }
        }
    }

    private func actionCard(icon: String, iconColors: [Color], title: String, subtitle: String, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: iconColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: icon)
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(14)
            .background(AppColors.cardBg)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
    }

    private func inputCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColors.cardBg)
        .cornerRadius(14)
    }

    private func createTeam() async {
        let trimmedName = teamName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        isLoading = true
        do {
            let team = try await ApiClient.shared.createTeam(name: trimmedName)
            createdTeam = team
            teamName = ""
            await refreshTeams()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                mode = .success
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func joinTeam() async {
        guard inviteCode.count == 6 else { return }

        isLoading = true
        do {
            let team = try await ApiClient.shared.joinTeam(inviteCode: inviteCode)
            inviteCode = ""
            await refreshTeams()
            joinSuccessMessage = "已成功加入 \(team.name)"
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func refreshTeams() async {
        authManager.invalidateTeams()
        await authManager.loadTeamsIfNeeded()
    }

    private func copyInviteCode() {
        guard let code = createdTeam?.inviteCode, !code.isEmpty else { return }
        UIPasteboard.general.string = code
        copied = true
    }
}
