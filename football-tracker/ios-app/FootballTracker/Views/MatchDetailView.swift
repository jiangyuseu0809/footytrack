import SwiftUI

struct MatchDetailView: View {
    let matchId: String
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var detail: MatchDetailResponse?
    @State private var isLoading = true
    @State private var isActionLoading = false
    @State private var showDeleteConfirm = false
    @State private var showColorPicker = false
    @State private var selectedColor: String = ""
    @State private var errorMessage: String?
    @State private var rankings: MatchRankingsResponse?
    @State private var summaryText: String?
    @State private var isSummaryLoading = false

    private var match: MatchResponse? { detail?.match }
    private var registrations: [MatchRegistrationResponse] { detail?.registrations ?? [] }
    private var isRegistered: Bool { detail?.isRegistered ?? false }
    private var isCreator: Bool { match?.creatorUid == authManager.currentUid }

    private var matchDate: Date? {
        guard let match = match else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(match.matchDate) / 1000.0)
    }

    private var isMatchEnded: Bool {
        guard let matchDate = matchDate else { return false }
        return Date() >= matchDate.addingTimeInterval(3 * 3600)
    }

    private func matchStatusInfo() -> (text: String, color: Color) {
        guard let matchDate = matchDate else { return ("即将开赛", Color(hex: 0xFACC15)) }
        let now = Date()
        if now < matchDate {
            return ("即将开赛", Color(hex: 0xFACC15))
        } else if now < matchDate.addingTimeInterval(3 * 3600) {
            return ("比赛中", Color(hex: 0x22C55E))
        } else {
            return ("比赛结束", Color(hex: 0x6B7280))
        }
    }

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
                        if isMatchEnded {
                            rankingsSection
                            summarySection
                        }
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
        .sheet(isPresented: $showColorPicker) {
            colorPickerSheet
        }
    }

    // MARK: - Match Info Card

    private func matchInfoCard(_ match: MatchResponse) -> some View {
        let matchDate = Date(timeIntervalSince1970: TimeInterval(match.matchDate) / 1000.0)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE HH:mm"
        let dateText = formatter.string(from: matchDate)
        let colors = match.groupColors.split(separator: ",").map(String.init)
        let totalPlayers = match.groups * match.playersPerGroup
        let status = matchStatusInfo()

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(match.title)
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)
                Spacer()
                Text(status.text)
                    .font(.caption.weight(.bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(status.color)
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

    // MARK: - Registration Section (Grouped by Color)

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
                let grouped = groupedRegistrations()
                if grouped.count > 1 {
                    // Show grouped by color
                    ForEach(grouped, id: \.color) { group in
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(teamColorFromName(group.color))
                                    .frame(width: 14, height: 14)
                                Text("\(teamColorLabel(group.color))队")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(AppColors.textPrimary)
                                Text("(\(group.players.count)人)")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)

                            ForEach(Array(group.players.enumerated()), id: \.element.userUid) { index, reg in
                                playerRow(reg: reg, index: index)
                                if index < group.players.count - 1 {
                                    Divider().overlay(Color.white.opacity(0.06))
                                }
                            }
                        }
                        .background(AppColors.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(teamColorFromName(group.color).opacity(0.3), lineWidth: 0.5)
                        )
                    }
                } else {
                    // Flat list when no grouping
                    VStack(spacing: 0) {
                        ForEach(Array(registrations.enumerated()), id: \.element.userUid) { index, reg in
                            playerRow(reg: reg, index: index)
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
    }

    private struct GroupedPlayers {
        let color: String
        let players: [MatchRegistrationResponse]
    }

    private func groupedRegistrations() -> [GroupedPlayers] {
        let colors = match?.groupColors.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
        var groups: [String: [MatchRegistrationResponse]] = [:]

        for reg in registrations {
            let key = reg.groupColor.isEmpty ? "" : reg.groupColor
            groups[key, default: []].append(reg)
        }

        // Order by the match's groupColors order
        var result: [GroupedPlayers] = []
        for color in colors {
            if let players = groups.removeValue(forKey: color), !players.isEmpty {
                result.append(GroupedPlayers(color: color, players: players))
            }
        }
        // Append any remaining (unmatched or empty color)
        for (color, players) in groups.sorted(by: { $0.key < $1.key }) where !players.isEmpty {
            result.append(GroupedPlayers(color: color.isEmpty ? "未分组" : color, players: players))
        }

        return result
    }

    private func playerRow(reg: MatchRegistrationResponse, index: Int) -> some View {
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
    }

    // MARK: - Color Picker Sheet

    private var colorPickerSheet: some View {
        let colors = match?.groupColors.split(separator: ",").map(String.init) ?? []

        return NavigationView {
            VStack(spacing: 16) {
                Text("选择队服颜色")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.top, 20)

                ForEach(colors, id: \.self) { colorName in
                    let trimmed = colorName.trimmingCharacters(in: .whitespaces)
                    Button {
                        selectedColor = trimmed
                        showColorPicker = false
                        Task { await register(groupColor: trimmed) }
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(teamColorFromName(trimmed))
                                .frame(width: 24, height: 24)
                            Text("\(teamColorLabel(trimmed))队")
                                .font(.body.weight(.medium))
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            let count = registrations.filter { $0.groupColor == trimmed }.count
                            Text("\(count)人已报名")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(16)
                        .background(AppColors.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(teamColorFromName(trimmed).opacity(0.3), lineWidth: 1)
                        )
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .background(AppColors.darkBg.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showColorPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Rankings Section

    private var rankingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let rankings = rankings {
                rankingCard(
                    title: "热量排行",
                    icon: "flame.fill",
                    gradientColors: [Color(hex: 0xF97316), Color(hex: 0xEF4444)],
                    items: rankings.caloriesRanking,
                    unit: "kcal",
                    formatter: { String(format: "%.0f", $0) }
                )

                rankingCard(
                    title: "跑动排行",
                    icon: "figure.run",
                    gradientColors: [Color(hex: 0xA855F7), Color(hex: 0xEC4899)],
                    items: rankings.distanceRanking,
                    unit: "km",
                    formatter: { String(format: "%.1f", $0 / 1000.0) }
                )
            }
        }
        .task {
            await loadRankings()
        }
    }

    private func rankingCard(
        title: String,
        icon: String,
        gradientColors: [Color],
        items: [PlayerRankItem],
        unit: String,
        formatter: @escaping (Double) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(gradientColors.first ?? .orange)
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(
                        LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing)
                    )
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            if items.isEmpty {
                Text("暂无数据")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(items.prefix(10).enumerated()), id: \.element.userUid) { index, item in
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(rankColor(index + 1).opacity(0.2))
                                    .frame(width: 28, height: 28)
                                if index < 3 {
                                    Text(rankMedal(index + 1))
                                        .font(.system(size: 14))
                                } else {
                                    Text("\(index + 1)")
                                        .font(.caption2.bold())
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            }

                            Text(item.nickname.isEmpty ? "球员" : item.nickname)
                                .font(.subheadline)
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(1)

                            if !item.groupColor.isEmpty {
                                Circle()
                                    .fill(teamColorFromName(item.groupColor))
                                    .frame(width: 8, height: 8)
                            }

                            Spacer()

                            Text("\(formatter(item.value)) \(unit)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppColors.textPrimary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                        if index < min(items.count, 10) - 1 {
                            Divider().overlay(Color.white.opacity(0.06))
                        }
                    }
                }
            }
        }
        .padding(.bottom, 8)
        .background(AppColors.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(hex: 0xFFD700)
        case 2: return Color(hex: 0xC0C0C0)
        case 3: return Color(hex: 0xCD7F32)
        default: return AppColors.textSecondary
        }
    }

    private func rankMedal(_ rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(rank)"
        }
    }

    // MARK: - AI Summary Section

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(Color(hex: 0xA855F7))
                Text("AI 比赛总结")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: 0xA855F7), Color(hex: 0x3B82F6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }

            if isSummaryLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(Color(hex: 0xA855F7))
                    Text("正在生成比赛总结...")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(AppColors.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if let summaryText = summaryText {
                Text(summaryText)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textPrimary)
                    .lineSpacing(4)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: 0xA855F7).opacity(0.08), Color(hex: 0x3B82F6).opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: 0xA855F7).opacity(0.2), lineWidth: 0.5)
                    )
            }
        }
        .task {
            await loadSummary()
        }
    }

    // MARK: - Action Section

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
                        let colors = match.groupColors.split(separator: ",").map(String.init)
                        if colors.count >= 2 {
                            showColorPicker = true
                        } else {
                            Task { await register(groupColor: colors.first?.trimmingCharacters(in: .whitespaces) ?? "") }
                        }
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

    private func register(groupColor: String) async {
        isActionLoading = true
        errorMessage = nil
        do {
            _ = try await ApiClient.shared.registerForMatch(matchId: matchId, groupColor: groupColor)
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

    private func loadRankings() async {
        do {
            rankings = try await ApiClient.shared.getMatchRankings(matchId: matchId)
        } catch {
            // Silently fail - rankings are optional
        }
    }

    private func loadSummary() async {
        guard isMatchEnded else { return }
        isSummaryLoading = true
        do {
            let response = try await ApiClient.shared.getMatchSummary(matchId: matchId)
            summaryText = response.summary
        } catch {
            summaryText = "无法生成比赛总结"
        }
        isSummaryLoading = false
    }

    // MARK: - Helpers

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
        case "未分组": return "未分组"
        default: return name
        }
    }
}
