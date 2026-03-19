import SwiftUI

struct BadgeWallView: View {
    let allBadges: [BadgeResponse]
    let earnedBadges: [UserBadgeResponse]

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    private var earnedIds: Set<String> {
        Set(earnedBadges.map { $0.badge.id })
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(allBadges, id: \.id) { badge in
                let isEarned = earnedIds.contains(badge.id)
                badgeItem(badge: badge, isEarned: isEarned)
            }
        }
    }

    private func badgeItem(badge: BadgeResponse, isEarned: Bool) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isEarned ? AppColors.neonBlue.opacity(0.2) : AppColors.cardBgLight)
                    .frame(width: 52, height: 52)

                if isEarned {
                    Circle()
                        .stroke(AppColors.neonBlue, lineWidth: 2)
                        .frame(width: 52, height: 52)
                }

                Image(systemName: badgeIcon(badge.iconName))
                    .font(.title3)
                    .foregroundColor(isEarned ? AppColors.neonBlue : AppColors.textSecondary.opacity(0.5))
            }

            Text(badge.name)
                .font(.caption2)
                .foregroundColor(isEarned ? AppColors.textPrimary : AppColors.textSecondary.opacity(0.5))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .frame(minHeight: 24, alignment: .top)
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
}
