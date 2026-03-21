import SwiftUI

struct SessionNotificationsView: View {
    @ObservedObject var store: SessionStore
    @State private var selectedSession: FootballSession?
    @State private var navigateToDetail = false

    private var unreadSessions: [FootballSession] {
        let unreadIds = UserDefaults.standard.stringArray(forKey: "unread_session_ids") ?? []
        guard !unreadIds.isEmpty else { return [] }
        let idSet = Set(unreadIds)
        return store.sessions
            .filter { idSet.contains($0.id) }
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
                List {
                    ForEach(unreadSessions) { session in
                        MatchHistoryRow(session: session)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedSession = session
                                navigateToDetail = true
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("通知")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToDetail) {
            if let session = selectedSession {
                SessionDetailView(session: session, store: store)
            }
        }
        .onAppear {
            UserDefaults.standard.set([], forKey: "unread_session_ids")
            UserDefaults.standard.set(0, forKey: "unread_session_count")
            NotificationCenter.default.post(name: .sessionRecorded, object: nil)
        }
    }
}
