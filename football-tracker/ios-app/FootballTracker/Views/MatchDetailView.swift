import SwiftUI

struct MatchDetailView: View {
    let matchId: String
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var detail: MatchDetailResponse?
    @State private var isLoading = true
    @State private var isActionLoading = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?

    private var match: MatchResponse? { detail?.match }
    private var registrations: [MatchRegistrationResponse] { detail?.registrations ?? [] }
    private var isRegistered: Bool { detail?.isRegistered ?? false }
    private var isCreator: Bool { match?.creatorUid == authManager.currentUid }

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(AppColors.neonBlue)
            } else if let match = match {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        matchInfoCard(match)
                        registrationSection
                        actionSection(match)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
                .refreshable {
                    await loadDetail(forceRefresh: true)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(AppColors.textSecondary)
                    Text("加载失败")
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .navigationTitle("比赛详情")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDetail()
        }
        .alert("确认删除", isPresented: $showDeleteConfirm) {
            Button("删除", role: .destructive) { Task { await deleteMatch() } }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后无法恢复，所有报名信息将被清除。")
        }
    }

    private func matchInfoCard(_ match: MatchResponse) -> some View {
        let matchDate = Date(timeIntervalSince1970: TimeInterval(match.matchDate) / 1000.0)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE HH:mm"
        let dateText = formatter.string(from: matchDate)
        let colors = match.groupColors.split(separator: ",").map(String.init)
        let totalPlayers = match.groups * match.playersPerGroup

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(match.title)
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)
                Spacer()
                Text(statusLabel(match.status))
                    .font(.caption.weight(.bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: 0xFACC15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            VStack(alignment: .leading, spacing: 8) {
                Label(dateText, systemImage: "calendar")
                Label(match.location, systemImage: "mappin")
                Label("\(match.groups) 组 x \(match.playersPerGroup) 人 = \(totalPlayers) 人", systemImage: "person.3.fill")
                if !colors.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "tshirt.fill")
                            .font(.caption)
                        ForEach(colors, id: \.self) { colorName in
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(teamColorFromName(colorName))
                                    .frame(width: 12, height: 12)
                                Text(teamColorLabel(colorName))
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.85))
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x16803B), Color(hex: 0x166534)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var registrationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("报名列表")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                if let match = match {
                    let total = match.groups * match.playersPerGroup
                    Text("\(registrations.count)/\(total)")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            if registrations.isEmpty {
                Text("暂无人报名")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(AppColors.cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(registrations.enumerated()), id: \.element.userUid) { index, reg in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(AppColors.cardBgLight)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text(reg.userUid == match?.creatorUid ? "👑" : "⚽️")
                                        .font(.body)
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(reg.nickname.isEmpty ? "球员" : reg.nickname)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(AppColors.textPrimary)
                                Text(formatRegistrationTime(reg.registeredAt))
                                    .font(.caption2)
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            Spacer()

                            Text("#\(index + 1)")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)

                        if index < registrations.count - 1 {
                            Divider().overlay(Color.white.opacity(0.06))
                        }
                    }
                }
                .background(AppColors.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
            }
        }
    }

    private func actionSection(_ match: MatchResponse) -> some View {
        VStack(spacing: 10) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(Color(hex: 0xEF4444))
            }

            if !isCreator {
                if isRegistered {
                    Button {
                        Task { await cancelRegistration() }
                    } label: {
                        HStack {
                            if isActionLoading {
                                ProgressView().tint(.white)
                            }
                            Text("取消报名")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: 0xEF4444))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isActionLoading)
                } else {
                    Button {
                        Task { await register() }
                    } label: {
                        HStack {
                            if isActionLoading {
                                ProgressView().tint(.white)
                            }
                            Text("立即报名")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: 0x3B82F6), Color(hex: 0x4F46E5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isActionLoading)
                }
            }

            if isCreator {
                Button {
                    showDeleteConfirm = true
                } label: {
                    Text("删除比赛")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color(hex: 0xEF4444))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: 0xEF4444).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Actions

    private func loadDetail(forceRefresh: Bool = false) async {
        do {
            detail = try await ApiClient.shared.getMatchDetail(matchId: matchId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func register() async {
        isActionLoading = true
        errorMessage = nil
        do {
            _ = try await ApiClient.shared.registerForMatch(matchId: matchId)
            await loadDetail(forceRefresh: true)
            authManager.invalidateMatches()
            await authManager.loadMatchesIfNeeded(forceRefresh: true)
        } catch {
            errorMessage = error.localizedDescription
        }
        isActionLoading = false
    }

    private func cancelRegistration() async {
        isActionLoading = true
        errorMessage = nil
        do {
            _ = try await ApiClient.shared.cancelMatchRegistration(matchId: matchId)
            await loadDetail(forceRefresh: true)
            authManager.invalidateMatches()
            await authManager.loadMatchesIfNeeded(forceRefresh: true)
        } catch {
            errorMessage = error.localizedDescription
        }
        isActionLoading = false
    }

    private func deleteMatch() async {
        isActionLoading = true
        errorMessage = nil
        do {
            _ = try await ApiClient.shared.deleteMatch(matchId: matchId)
            authManager.invalidateMatches()
            await authManager.loadMatchesIfNeeded(forceRefresh: true)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isActionLoading = false
    }

    // MARK: - Helpers

    private func statusLabel(_ status: String) -> String {
        switch status {
        case "upcoming": return "即将开赛"
        case "completed": return "已结束"
        case "cancelled": return "已取消"
        default: return status
        }
    }

    private func formatRegistrationTime(_ millis: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000.0)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM-dd HH:mm"
        return "报名于 \(formatter.string(from: date))"
    }

    private func teamColorFromName(_ name: String) -> Color {
        switch name.trimmingCharacters(in: .whitespaces).lowercased() {
        case "red": return Color(hex: 0xEF4444)
        case "blue": return Color(hex: 0x3B82F6)
        case "green": return Color(hex: 0x22C55E)
        case "orange": return Color(hex: 0xF97316)
        case "yellow": return Color(hex: 0xFACC15)
        case "white": return Color.white
        default: return Color.gray
        }
    }

    private func teamColorLabel(_ name: String) -> String {
        switch name.trimmingCharacters(in: .whitespaces).lowercased() {
        case "red": return "红"
        case "blue": return "蓝"
        case "green": return "绿"
        case "orange": return "橙"
        case "yellow": return "黄"
        case "white": return "白"
        default: return name
        }
    }
}
