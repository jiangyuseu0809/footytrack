import SwiftUI

struct ProSubscriptionView: View {
    @State private var selectedPlanId: String = "lifetime"
    @State private var plans: [PlanResponse] = []
    @State private var trialDays: Int = 7
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    private struct Feature {
        let icon: String
        let title: String
        let description: String
        let details: String
        let colors: [Color]
    }

    private struct ComparisonItem {
        let name: String
        let free: Bool
        let pro: Bool
    }

    private let features: [Feature] = [
        Feature(
            icon: "icloud.fill",
            title: "云端自动同步",
            description: "数据实时备份，永不丢失",
            details: "所有比赛数据、个人统计、圈子记录都会自动同步到云端，换设备也能无缝衔接",
            colors: [Color.blue, Color.cyan]
        ),
        Feature(
            icon: "brain.head.profile",
            title: "AI 智能总结",
            description: "每场比赛专业分析",
            details: "AI深度分析每场比赛表现，提供个性化建议和整体球员评估报告",
            colors: [Color.purple, Color.pink]
        ),
        Feature(
            icon: "person.3.fill",
            title: "团队数据对比",
            description: "横向综合对比分析",
            details: "支持球队成员之间的多维度数据对比，找出优势和提升空间",
            colors: [Color.orange, Color.red]
        ),
        Feature(
            icon: "doc.text.fill",
            title: "专业数据报告",
            description: "更全面的比赛分析",
            details: "包含热力图、跑动轨迹、冲刺区间、体能分布等20+项专业数据指标",
            colors: [Color.green, Color.mint]
        ),
    ]

    private let comparisonItems: [ComparisonItem] = [
        ComparisonItem(name: "基础数据记录", free: true, pro: true),
        ComparisonItem(name: "本地数据存储", free: true, pro: true),
        ComparisonItem(name: "基础统计图表", free: true, pro: true),
        ComparisonItem(name: "云端自动同步", free: false, pro: true),
        ComparisonItem(name: "AI 比赛总结", free: false, pro: true),
        ComparisonItem(name: "AI 球员评估", free: false, pro: true),
        ComparisonItem(name: "团队数据对比", free: false, pro: true),
        ComparisonItem(name: "专业数据报告", free: false, pro: true),
        ComparisonItem(name: "高级数据可视化", free: false, pro: true),
        ComparisonItem(name: "数据导出分享", free: false, pro: true),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColors.darkBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    heroSection
                    trialBanner
                    featureCards
                    comparisonTable
                    planSelection
                    trustBadges
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }

            bottomCTA
        }
        .navigationTitle("FootyTrack Pro")
        .navigationBarTitleDisplayMode(.inline)
        .hideTabBar()
        .task {
            await loadPricing()
        }
    }

    // MARK: - Load Pricing

    private func loadPricing() async {
        do {
            let response = try await ApiClient.shared.getPricing()
            plans = response.plans
            trialDays = response.trialDays
            if let first = plans.first(where: { $0.popular }) ?? plans.first {
                selectedPlanId = first.id
            }
        } catch {
            // Fallback defaults
            plans = [
                PlanResponse(id: "lifetime", name: "永久订阅", price: 128, originalPrice: nil, period: "永久", discount: nil, popular: true),
                PlanResponse(id: "yearly", name: "年度订阅", price: 66, originalPrice: nil, period: "/年", discount: nil, popular: false),
                PlanResponse(id: "monthly", name: "月度订阅", price: 9.9, originalPrice: nil, period: "/月", discount: nil, popular: false),
            ]
        }
        isLoading = false
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.8, blue: 0.2),
                                Color(red: 1.0, green: 0.5, blue: 0.2),
                                Color(red: 0.9, green: 0.3, blue: 0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                    .shadow(color: Color.orange.opacity(0.4), radius: 20, y: 10)

                Image(systemName: "crown.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.white)
            }

            Text("升级到 Pro")
                .font(.largeTitle.weight(.bold))
                .foregroundColor(.white)

            Text("解锁专业球员数据分析")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)

            HStack(spacing: 8) {
                tagPill(icon: "sparkles", text: "AI 驱动", colors: [.blue, .purple])
                tagPill(icon: "shield.fill", text: "数据安全", colors: [.green, .mint])
            }
        }
        .padding(.top, 16)
    }

    // MARK: - Trial Banner

    private var trialBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "gift.fill")
                .font(.title2)
                .foregroundColor(.yellow)

            VStack(alignment: .leading, spacing: 2) {
                Text("所有计划包含 \(trialDays) 天免费试用")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                Text("试用期内随时取消，不收取任何费用")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(colors: [Color.orange.opacity(0.2), Color.yellow.opacity(0.1)], startPoint: .leading, endPoint: .trailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.orange.opacity(0.4), lineWidth: 1)
                )
        )
    }

    private func tagPill(icon: String, text: String, colors: [Color]) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2.weight(.semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
        .cornerRadius(20)
    }

    // MARK: - Feature Cards

    private var featureCards: some View {
        VStack(spacing: 12) {
            ForEach(Array(features.enumerated()), id: \.offset) { _, feature in
                featureCard(feature)
            }
        }
    }

    private func featureCard(_ feature: Feature) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: feature.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 52, height: 52)
                    .shadow(color: feature.colors.first?.opacity(0.3) ?? .clear, radius: 8, y: 4)
                Image(systemName: feature.icon)
                    .font(.system(size: 22))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)
                Text(feature.description)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                Text(feature.details)
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.5))
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColors.cardBg)
        .cornerRadius(16)
    }

    // MARK: - Comparison Table

    private var comparisonTable: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("功能对比")
                .font(.title3.weight(.bold))
                .foregroundColor(.white)

            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Text("免费版")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 60)
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10))
                        Text("Pro")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(8)
                    .frame(width: 60)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppColors.cardBgLight)

                ForEach(Array(comparisonItems.enumerated()), id: \.offset) { index, item in
                    HStack {
                        Text(item.name)
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Spacer()
                        checkMark(active: item.free)
                            .frame(width: 60)
                        checkMark(active: item.pro)
                            .frame(width: 60)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    if index < comparisonItems.count - 1 {
                        Divider().background(AppColors.cardBgLight)
                    }
                }
            }
            .background(AppColors.cardBg)
            .cornerRadius(16)
        }
    }

    private func checkMark(active: Bool) -> some View {
        Group {
            if active {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.green)
            } else {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundColor(Color.white.opacity(0.2))
            }
        }
    }

    // MARK: - Plan Selection

    private var planSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择订阅计划")
                .font(.title3.weight(.bold))
                .foregroundColor(.white)

            if isLoading {
                ProgressView()
                    .tint(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                ForEach(plans, id: \.id) { plan in
                    planCard(plan)
                }
            }

            // Trial reminder under plans
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
                Text("所有计划均含 \(trialDays) 天免费试用，随时可取消")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.top, 4)
        }
    }

    private func planCard(_ plan: PlanResponse) -> some View {
        let isSelected = selectedPlanId == plan.id
        return Button {
            selectedPlanId = plan.id
        } label: {
            HStack {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .stroke(isSelected ? Color.blue : Color.white.opacity(0.3), lineWidth: 2)
                            .frame(width: 22, height: 22)
                        if isSelected {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 14, height: 14)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(plan.name)
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(.white)
                            if plan.popular {
                                Text("推荐")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                                    .cornerRadius(6)
                            }
                            if let discount = plan.discount {
                                Text("\(discount)折")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .cornerRadius(6)
                            }
                        }
                        Text("含 \(trialDays) 天免费试用")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 0) {
                    if let original = plan.originalPrice {
                        Text(formatPrice(original))
                            .font(.caption2)
                            .strikethrough()
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Text(formatPrice(plan.price))
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                    Text(plan.period)
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.blue : Color.white.opacity(0.15), lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isSelected ? Color.blue.opacity(0.1) : AppColors.cardBg)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func formatPrice(_ price: Double) -> String {
        if price == price.rounded() {
            return "¥\(Int(price))"
        }
        return "¥\(String(format: "%.1f", price))"
    }

    // MARK: - Trust Badges

    private var trustBadges: some View {
        HStack(spacing: 20) {
            trustItem(icon: "shield.fill", text: "安全加密", color: .green)
            trustItem(icon: "bolt.fill", text: "即时生效", color: .yellow)
            trustItem(icon: "checkmark.circle.fill", text: "随时取消", color: .blue)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(AppColors.cardBg)
        .cornerRadius(14)
    }

    private func trustItem(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            Text(text)
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: - Bottom CTA

    private var bottomCTA: some View {
        VStack(spacing: 8) {
            Button {
                // TODO: Trigger StoreKit purchase
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.subheadline)
                    Text("免费试用 \(trialDays) 天，立即开始")
                        .font(.headline.weight(.bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(28)
                .shadow(color: .purple.opacity(0.3), radius: 10, y: 5)
            }

            Text("试用期内随时取消，不收取任何费用")
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            AppColors.darkBg
                .overlay(
                    LinearGradient(colors: [AppColors.darkBg.opacity(0), AppColors.darkBg], startPoint: .top, endPoint: .center)
                )
        )
    }
}
