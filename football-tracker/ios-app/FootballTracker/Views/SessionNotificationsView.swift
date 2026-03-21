import SwiftUI

struct SessionNotificationsView: View {
    @ObservedObject var store: SessionStore
    @State private var selectedSession: FootballSession?
    @State private var navigateToDetail = false
    @State private var unreadIds: Set<String> = []

    private var unreadSessions: [FootballSession] {
        guard !unreadIds.isEmpty else { return [] }
        return store.sessions
            .filter { unreadIds.contains($0.id) }
            .sorted { $0.startTime > $1.startTime }
    }

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            if unreadSessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 40))
                        .foregroundColor(AppColors.textSecondary)
                    Text("暂无新通知")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                    Text("Watch 完成比赛记录后，通知会出现在这里。")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(unreadSessions) { session in
                            notificationCard(session: session)
                                .onTapGesture {
                                    selectedSession = session
                                    navigateToDetail = true
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("通知")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToDetail) {
            if let session = selectedSession {
                SessionDetailView(session: session, store: store)
                    .onAppear {
                        markAsRead(sessionId: session.id)
                    }
            }
        }
        .onAppear {
            unreadIds = Set(UserDefaults.standard.stringArray(forKey: "unread_session_ids") ?? [])
        }
    }

    private func markAsRead(sessionId: String) {
        unreadIds.remove(sessionId)
        let remaining = Array(unreadIds)
        UserDefaults.standard.set(remaining, forKey: "unread_session_ids")
        UserDefaults.standard.set(remaining.count, forKey: "unread_session_count")
        NotificationCenter.default.post(name: .sessionRecorded, object: nil)
    }

    private func notificationCard(session: FootballSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(AppColors.neonBlue.opacity(0.15))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "applewatch.radiowaves.left.and.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.neonBlue)
                    )

                Text(timeAgoText(session.startTime))
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Circle()
                    .fill(AppColors.neonBlue)
                    .frame(width: 8, height: 8)
            }

            Text("比赛记录完成")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)

            HStack(spacing: 16) {
                statPill(icon: "figure.run", value: String(format: "%.1f km", session.totalDistanceMeters / 1000))
                statPill(icon: "clock", value: durationText(session))
                if session.avgHeartRate > 0 {
                    statPill(icon: "heart.fill", value: "\(session.avgHeartRate) bpm")
                }
            }

            HStack {
                Text("点击查看详细比赛数据")
                    .font(.caption)
                    .foregroundColor(AppColors.neonBlue)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(AppColors.neonBlue)
            }
        }
        .padding(14)
        .background(AppColors.cardBg)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
    }

    private func statPill(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary)
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundColor(AppColors.textPrimary)
        }
    }

    private func durationText(_ session: FootballSession) -> String {
        let minutes = Int(session.endTime.timeIntervalSince(session.startTime)) / 60
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)min"
        }
        return "\(minutes) min"
    }

    private func timeAgoText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")

        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "今天 HH:mm"
        } else if Calendar.current.isDateInYesterday(date) {
            formatter.dateFormat = "'昨天' HH:mm"
        } else {
            formatter.dateFormat = "MM月dd日 HH:mm"
        }
        return formatter.string(from: date)
    }
}
