import SwiftUI

struct TeamDetailView: View {
    let teamId: String
    @State private var detail: TeamDetailResponse?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            if let detail = detail {
                ScrollView {
                    VStack(spacing: 16) {
                        // Team info card
                        VStack(spacing: 8) {
                            Text(detail.team.name)
                                .font(.title2.bold())
                                .foregroundColor(AppColors.textPrimary)
                            HStack {
                                Text("邀请码:")
                                    .foregroundColor(AppColors.textSecondary)
                                Text(detail.team.inviteCode)
                                    .font(.headline)
                                    .foregroundColor(AppColors.neonBlue)
                                Button {
                                    UIPasteboard.general.string = detail.team.inviteCode
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.caption)
                                        .foregroundColor(AppColors.neonBlue)
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(AppColors.cardBg)
                        .cornerRadius(16)
                        .padding(.horizontal, 16)

                        // Leaderboard
                        VStack(alignment: .leading, spacing: 12) {
                            Text("排行榜")
                                .font(.headline)
                                .foregroundColor(AppColors.textPrimary)

                            ForEach(Array(detail.members.enumerated()), id: \.element.userUid) { index, member in
                                memberRow(rank: index + 1, member: member)
                            }
                        }
                        .padding(16)
                        .background(AppColors.cardBg)
                        .cornerRadius(16)
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 12)
                }
            } else if isLoading {
                ProgressView()
                    .tint(AppColors.neonBlue)
            }
        }
        .navigationTitle("球队详情")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDetail()
        }
    }

    private func memberRow(rank: Int, member: TeamMemberResponse) -> some View {
        HStack(spacing: 12) {
            // Rank
            ZStack {
                Circle()
                    .fill(rankColor(rank).opacity(0.2))
                    .frame(width: 32, height: 32)
                if rank <= 3 {
                    Text(rankMedal(rank))
                        .font(.system(size: 16))
                } else {
                    Text("\(rank)")
                        .font(.subheadline.bold())
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(member.nickname.isEmpty ? "球员" : member.nickname)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppColors.textPrimary)
                    if member.role == "owner" {
                        Text("队长")
                            .font(.caption2)
                            .foregroundColor(AppColors.calorieOrange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.calorieOrange.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                let distKm = String(format: "%.1f", member.totalDistanceMeters / 1000.0)
                Text("\(member.sessionCount) 场 · \(distKm) km")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Text("\(member.sessionCount) 场")
                .font(.subheadline.bold())
                .foregroundColor(AppColors.neonBlue)
        }
        .padding(12)
        .background(AppColors.cardBgLight)
        .cornerRadius(10)
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
        default: return ""
        }
    }

    private func loadDetail() async {
        do {
            detail = try await ApiClient.shared.getTeamDetail(teamId: teamId)
        } catch {}
        isLoading = false
    }
}

private extension Color {
    init(hex: UInt) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}
