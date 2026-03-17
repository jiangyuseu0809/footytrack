import SwiftUI

struct TeamListView: View {
    @ObservedObject var authManager: AuthManager
    @State private var showCreateSheet = false
    @State private var showJoinSheet = false
    @State private var newTeamName = ""
    @State private var inviteCode = ""
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            AppColors.darkBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    if authManager.teams.isEmpty && !isLoading {
                        VStack(spacing: 12) {
                            Image(systemName: "person.3")
                                .font(.system(size: 48))
                                .foregroundColor(AppColors.textSecondary)
                            Text("还没有球队")
                                .font(.title3)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.top, 60)
                    } else {
                        ForEach(authManager.teams, id: \.id) { team in
                            NavigationLink(destination: TeamDetailView(teamId: team.id)) {
                                teamCard(team)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("我的球队")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("创建球队") { showCreateSheet = true }
                    Button("加入球队") { showJoinSheet = true }
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(AppColors.neonBlue)
                }
            }
        }
        .alert("创建球队", isPresented: $showCreateSheet) {
            TextField("球队名称", text: $newTeamName)
            Button("创建") { Task { await createTeam() } }
            Button("取消", role: .cancel) { newTeamName = "" }
        }
        .alert("加入球队", isPresented: $showJoinSheet) {
            TextField("邀请码", text: $inviteCode)
            Button("加入") { Task { await joinTeam() } }
            Button("取消", role: .cancel) { inviteCode = "" }
        }
        .task {
            await loadTeams()
        }
    }

    private func teamCard(_ team: TeamResponse) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(team.name)
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                Text("邀请码: \(team.inviteCode)")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(16)
        .background(AppColors.cardBg)
        .cornerRadius(12)
    }

    private func loadTeams() async {
        await authManager.loadTeamsIfNeeded()
        isLoading = false
    }

    private func createTeam() async {
        guard !newTeamName.isEmpty else { return }
        do {
            let team = try await ApiClient.shared.createTeam(name: newTeamName)
            authManager.teams.append(team)
            authManager.invalidateTeams()
            newTeamName = ""
        } catch {}
    }

    private func joinTeam() async {
        guard !inviteCode.isEmpty else { return }
        do {
            let team = try await ApiClient.shared.joinTeam(inviteCode: inviteCode)
            authManager.teams.append(team)
            authManager.invalidateTeams()
            inviteCode = ""
        } catch {}
    }
}
